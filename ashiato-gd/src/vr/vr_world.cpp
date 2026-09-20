// A networked VR playground: avatars, grabbable props and pilotable vehicles, all
// predicted for their owner and interpolated for everyone else.
//
// The same three-piece arrangement as src/driving: Box3D does the simulation, ashiato
// owns the rewind, ashiato-sync owns the wire. What is different is who the player is.
//
// In the driving module a player is a car, and a car is entirely a simulation result. Here
// a player is a head and two hands attached to a human being, which is not a simulation
// result at all -- it is input, arriving from a tracking system that no amount of physics
// can predict. So the tracked poses ride sync's input path (frame-stamped, buffered,
// replayed during rollback), the server writes them into AvatarState, and everybody else
// receives them as replicated state. See vr_components.hpp, which is where that decision
// is argued.
//
// The other decision worth knowing before reading any of this: A SEATED PLAYER HAS NO
// WORLD POSE. Their pose is derived from the vehicle's pose and the seat index, in both
// the simulation and the renderer, from the same fractional tick. Replicating a second
// world pose for somebody bolted into a cockpit is the trailer-parting-from-the-cab
// failure the driving module already paid for, except that here the thing that parts and
// snaps back is the player's own head.

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <memory>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include "ashiato/sync/sync.hpp"
#include "core/input_truncation.hpp"
#include "box3d/box3d.h"
#include "../core/from_godot.hpp"
#include "vr/vr_components.hpp"

using namespace godot;

namespace ashiato_gd {

namespace {

namespace w = vr::wire;

// An escaping C++ exception terminates Godot silently -- no message, no stack, nothing in
// the log. sync throws for protocol and usage errors, so every entry point that can reach
// it is wrapped. This turns several "crashes" into readable errors, which is the whole
// reason the driving module has the same macro.
#define VR_TRY(expr, on_error)                                                        \
    do {                                                                              \
        try {                                                                         \
            expr;                                                                     \
        } catch (const std::exception& error) {                                       \
            UtilityFunctions::push_error(String("[VrWorld] ") + String(error.what())); \
            on_error;                                                                 \
        } catch (...) {                                                               \
            UtilityFunctions::push_error("[VrWorld] unknown error");                  \
            on_error;                                                                 \
        }                                                                             \
    } while (false)

// How often the world is simulated, and therefore how often it goes on the wire.
//
// FIXED for the life of a world and IDENTICAL on every peer: a rollback replays ticks, so
// the rate is part of the simulation's definition, and two peers on different rates are
// running two different games. set_tick_rate() therefore only takes effect at start().
//
// It is a setting rather than a constant because it is the bandwidth dial, and the number
// that is right depends on what is being tested. Bandwidth is very nearly linear in it:
// halving the rate halves the traffic.
//
// 60 by default. It was briefly 90, which was a workaround for the display sampling not
// interpolating -- with drawing paced properly (see set_render_time) the simulation no
// longer has to keep up with the headset, and 90 was simply paying for smoothness twice.
// The floor and ceiling are sanity limits, not tuning advice.
constexpr float kDefaultTickHz = 60.0f;
constexpr float kMinTickHz = 15.0f;
constexpr float kMaxTickHz = 120.0f;
constexpr int kSubSteps = 4;

// How long a just-released object goes on ignoring the person who let go of it.
//
// A hand is KINEMATIC, so it wins every contact absolutely: releasing an object your hand
// is inside hands the solver a deep overlap and it resolves it by firing the object away
// (measured: a crate went UP 3.6 m from a standing player). The grip offset means a hand
// usually rests on the surface rather than inside, but a player who reached dead centre
// still hits it -- and "usually" is not a guarantee.
//
// Twelve ticks is a fifth of a second: long enough for a hand to be withdrawn or an
// object to fall clear, short enough that you cannot walk through something you dropped.
constexpr int kReleaseGraceTicks = 12;

// How close a hand has to get to pick something up. Measured from the object's SURFACE,
// not its centre: a fixed centre distance means a big crate is harder to pick up than a
// small one, and with a 0.18 m crate and a 0.22 m reach the hand had to be inside the box
// before it counted.
constexpr float kGrabReach = 0.16f;
constexpr float kSeatReach = 1.6f;

// What a Box3D body in this world IS, hung off its user data so the contact filter can
// ask without touching the ECS.
//
// This exists for one specific artefact: a crate held in front of your chest overlaps
// your own collision capsule, so every step the solver pushed it away and every step the
// carry pulled it back, and the crate sat 30 cm from the hand holding it, buzzing. It is
// not a tuning problem -- the two are asking for incompatible things and one of them has
// to stop. A held object is part of the person holding it, so it stops colliding with
// them, and with nobody else.
constexpr std::uint8_t kRoleOther = 0;
constexpr std::uint8_t kRoleAvatar = 1;
constexpr std::uint8_t kRoleHand = 2;
constexpr std::uint8_t kRoleProp = 3;
constexpr std::uint8_t kRoleVehicle = 4;

struct BodyTag {
    std::uint8_t role = kRoleOther;
    /// For an avatar or hand, whose it is. For a prop, who is currently holding it.
    std::uint8_t owner = vr::kNoOccupant;
    /// Which entity this body belongs to. A sensor event hands back a shape, and the
    /// game asks its questions in entities.
    std::uint64_t entity = 0;
    /// For a hand, which one. kHandNone for everything else.
    std::uint8_t hand = vr::kHandNone;
};

/// True when `prop` is a HELD object and `person` is a person -- anybody, not only the
/// one holding it.
///
/// Suppressing it against the holder alone was the first version and it is not enough.
/// Reaching for a crate in somebody else's hand meant your kinematic hand -- which always
/// wins a contact -- shoved it away while their carry pulled it back, and the two settled
/// with the crate 34 cm from the hand trying to take it. You could never quite reach
/// anything anybody was holding, which is exactly the interaction a handoff is.
///
/// So: a held object is under someone's control, and control is a state change rather
/// than a physical struggle between two players' hands. It still collides with the world,
/// with vehicles, and with other props -- including crates other people are holding, so
/// two players CAN fence with them. FREE props keep colliding with hands, which is what
/// lets you bat a loose ball around.
inline bool held_prop_vs_person(const BodyTag& prop, const BodyTag& person) {
    return prop.role == kRoleProp && prop.owner != vr::kNoOccupant
        && (person.role == kRoleAvatar || person.role == kRoleHand);
}

/// True when these two are one person's own hand and their own body.
///
/// A hand is KINEMATIC, which means it wins every contact absolutely -- nothing can push
/// it away from where the player's real hand is, and everything it touches gets pushed
/// instead. That is right for a crate and completely wrong for the player's own capsule:
/// bringing your hands back to your chest shoved your own body backwards, so the reported
/// symptom was "my hands make me walk". Nothing in the game moved the player; their hands
/// were bulldozing them.
///
/// Suppressed only against their OWN body. Hands still collide with other players, which
/// is what makes shoving somebody work, and with free props, which is what lets you bat a
/// ball around.
inline bool own_hand_vs_own_body(const BodyTag& hand, const BodyTag& body) {
    return hand.role == kRoleHand && body.role == kRoleAvatar
        && hand.owner != vr::kNoOccupant && hand.owner == body.owner;
}

// Button bits in AvatarInput::buttons.
constexpr std::uint8_t kButtonGrabLeft = 1 << 0;
constexpr std::uint8_t kButtonGrabRight = 1 << 1;
constexpr std::uint8_t kButtonUse = 1 << 2;
constexpr std::uint8_t kButtonSeat = 1 << 3;
constexpr std::uint8_t kButtonMenu = 1 << 4;

// ---- what a thing can be ----------------------------------------------------------
//
// One table for props and vehicles together, because BodyKind is one field and the
// renderer, the simulation and the seat geometry all index it. A kind that only some of
// those three know about is how a crate ends up drawn as an aeroplane.

constexpr std::uint8_t kKindCrate = 0;
constexpr std::uint8_t kKindBall = 1;
constexpr std::uint8_t kKindCar = 2;
constexpr std::uint8_t kKindPlane = 3;
constexpr std::uint8_t kKindBoat = 4;

struct Seat {
    // Where the seat is in the body's own frame, and which way it faces. A seat is a
    // full pose rather than a point: a gunner facing backwards is a seat, not a mesh.
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    float yaw = 0.0f;
};

struct Shape {
    const char* name = "crate";
    bool vehicle = false;
    bool sphere = false;
    // Half extents for a box; hx is the radius for a sphere.
    float hx = 0.25f;
    float hy = 0.25f;
    float hz = 0.25f;
    float mass = 8.0f;
    int seats = 0;
    Seat seat[vr::kMaxSeats]{};
};

inline Shape crate_shape() {
    Shape s;
    s.name = "crate";
    s.hx = s.hy = s.hz = 0.18f;
    s.mass = 6.0f;
    return s;
}

inline Shape ball_shape() {
    Shape s;
    s.name = "ball";
    s.sphere = true;
    s.hx = 0.12f;
    s.hy = s.hz = 0.12f;
    s.mass = 1.2f;
    return s;
}

inline Shape car_shape() {
    Shape s;
    s.name = "car";
    s.vehicle = true;
    s.hx = 0.95f;
    s.hy = 0.55f;
    s.hz = 2.20f;
    s.mass = 1100.0f;
    s.seats = 4;
    // Driver front left, passenger front right, two behind. -Z is forward, matching
    // Godot's convention, so the front seats are the negative ones.
    s.seat[0] = Seat{-0.42f, 0.15f, -0.45f, 0.0f};
    s.seat[1] = Seat{0.42f, 0.15f, -0.45f, 0.0f};
    s.seat[2] = Seat{-0.42f, 0.15f, 0.70f, 0.0f};
    s.seat[3] = Seat{0.42f, 0.15f, 0.70f, 0.0f};
    return s;
}

inline Shape plane_shape() {
    Shape s;
    s.name = "plane";
    s.vehicle = true;
    // A light aircraft as a single box. The wing is not a shape here -- it is the lift
    // term in the simulation, applied at the centre of pressure -- because a box the
    // size of the wingspan would collide with things the aircraft flies past.
    s.hx = 0.70f;
    s.hy = 0.70f;
    s.hz = 3.20f;
    s.mass = 750.0f;
    s.seats = 2;
    s.seat[0] = Seat{-0.32f, 0.10f, -0.60f, 0.0f};
    s.seat[1] = Seat{0.32f, 0.10f, -0.60f, 0.0f};
    return s;
}

inline Shape boat_shape() {
    Shape s;
    s.name = "boat";
    s.vehicle = true;
    s.hx = 1.10f;
    s.hy = 0.55f;
    s.hz = 2.80f;
    s.mass = 900.0f;
    s.seats = 4;
    s.seat[0] = Seat{0.0f, 0.30f, -1.10f, 0.0f};
    s.seat[1] = Seat{-0.55f, 0.30f, 0.10f, 0.0f};
    s.seat[2] = Seat{0.55f, 0.30f, 0.10f, 0.0f};
    // A stern seat facing aft, which is what makes the yaw in a seat pose worth having.
    s.seat[3] = Seat{0.0f, 0.30f, 1.40f, 3.14159274f};
    return s;
}

constexpr std::size_t kKindCount = 5;

inline const char* kind_name_of(std::size_t index) {
    static const char* names[kKindCount] = {"crate", "ball", "car", "plane", "boat"};
    return names[index];
}

// ---- how each vehicle flies, drives or floats -------------------------------------
//
// Every knob that shapes the feel is a setting read from a Dictionary rather than a
// constant in this file, and that is a lesson taken straight from the driving module: a
// tuning constant in C++ is a tuning constant nobody tunes, because sweeping three values
// of two parameters is nine rebuilds instead of one script.

struct Handling {
    // Common
    float thrust = 6000.0f;        // N at full throttle
    float brake = 9000.0f;         // N opposing motion
    float drag = 3.0f;             // N per (m/s)^2, along the body's own axes
    float angular_damping = 0.9f;

    // Ground vehicles
    // Constant force opposing motion, which is what a wheel and a bearing actually
    // cost. Unlike drag it does NOT vanish at low speed, so it is the term that makes a
    // parked vehicle stay parked -- and a person leaning on one merely rock it.
    float rolling_resistance = 500.0f;
    float grip = 12000.0f;         // N of lateral hold before it slides
    float steer_rate = 0.9f;       // rad/s of yaw at full lock and reference speed
    float steer_reference = 14.0f; // m/s the lock is quoted at

    // Aircraft
    // N per (m/s)^2 per radian of angle of attack, times the 0.01 scaling in drive_plane.
    //
    // The first value here was 950 and the aircraft could not fly at all: at 30 m/s and
    // 0.1 rad it produced 855 N against 7360 N of weight, so full power simply dragged it
    // along the ground for ever. Sized instead from the condition it has to meet --
    // carry its own weight at a cruise it can actually reach.
    float lift = 8200.0f;
    float stall_angle = 0.28f;     // rad; past this the lift curve falls away
    // Radians per second at full stick deflection. A light aircraft rolls at about
    // 2 rad/s and pitches at about 1; these are a little brisker because it is a
    // playground.
    float pitch_rate = 1.3f;
    float roll_rate = 2.6f;
    float rudder_rate = 0.9f;
    // Newton-metres per radian per second of error. How hard the surfaces bite.
    float control_authority = 9000.0f;
    // How hard the airframe resists sideslip. This is the fin, and without it an
    // aircraft flies sideways as happily as forwards.
    float weathervane = 9000.0f;

    // Boats
    float water_level = 0.0f;
    float buoyancy = 26000.0f;     // N per metre of draught
    float water_drag = 1800.0f;    // N per m/s sideways; a hull does not slide
};

inline Handling default_handling(std::uint8_t kind) {
    Handling h;
    switch (kind) {
        case kKindCar:
            h.thrust = 9000.0f;
            h.brake = 14000.0f;
            h.rolling_resistance = 500.0f;
            h.drag = 2.6f;
            h.grip = 14000.0f;
            h.steer_rate = 1.1f;
            h.angular_damping = 1.6f;
            break;
        case kKindPlane:
            // Punchier than the 4200 N a 180 hp light aircraft actually makes. This is a
            // playground with a runway measured in tens of metres rather than hundreds,
            // and it is a Dictionary knob: set it back to 4200 for a longer field.
            h.thrust = 8000.0f;
            h.brake = 1200.0f;
            // A wheel, not a belly. 3% of weight, which is about what an aircraft tyre
            // costs; the first value here was 1500 N and it was most of the thrust.
            h.rolling_resistance = 220.0f;
            h.drag = 1.1f;
            h.lift = 950.0f;
            h.angular_damping = 1.2f;
            break;
        case kKindBoat:
            h.thrust = 7000.0f;
            h.brake = 2500.0f;
            // A hull has no wheels. Its resistance is water_drag, applied only while it
            // is actually in the water.
            h.rolling_resistance = 0.0f;
            h.drag = 2.0f;
            h.steer_rate = 0.6f;
            h.angular_damping = 1.4f;
            break;
        default:
            break;
    }
    return h;
}

inline float dict_get(const Dictionary& source, const char* key, float fallback) {
    return source.has(key) ? static_cast<float>(source[key]) : fallback;
}

// ---- small maths -------------------------------------------------------------------

inline b3Quat to_b3(const w::Quat& q) {
    return b3Quat{b3Vec3{q.x, q.y, q.z}, q.w};
}

inline w::Quat from_b3(const b3Quat& q) {
    return w::Quat{q.v.x, q.v.y, q.v.z, q.s};
}

inline b3Quat yaw_quat(float yaw) {
    return b3Quat{b3Vec3{0.0f, std::sin(yaw * 0.5f), 0.0f}, std::cos(yaw * 0.5f)};
}

inline b3Vec3 rotate(const b3Quat& q, const b3Vec3& v) {
    // v + 2 * cross(q.v, cross(q.v, v) + q.s * v). The standard form, written out rather
    // than reached for through Box3D's own helper so this file stays readable next to
    // the quaternion maths in vr_components.hpp.
    const b3Vec3 t{2.0f * (q.v.y * v.z - q.v.z * v.y), 2.0f * (q.v.z * v.x - q.v.x * v.z),
                   2.0f * (q.v.x * v.y - q.v.y * v.x)};
    return b3Vec3{v.x + q.s * t.x + (q.v.y * t.z - q.v.z * t.y),
                  v.y + q.s * t.y + (q.v.z * t.x - q.v.x * t.z),
                  v.z + q.s * t.z + (q.v.x * t.y - q.v.y * t.x)};
}

inline float length(const b3Vec3& v) {
    return std::sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
}

inline float dot3(const b3Vec3& a, const b3Vec3& b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

inline b3Vec3 scaled(const b3Vec3& v, float s) {
    return b3Vec3{v.x * s, v.y * s, v.z * s};
}

inline b3Vec3 added(const b3Vec3& a, const b3Vec3& b) {
    return b3Vec3{a.x + b.x, a.y + b.y, a.z + b.z};
}

inline b3Vec3 subbed(const b3Vec3& a, const b3Vec3& b) {
    return b3Vec3{a.x - b.x, a.y - b.y, a.z - b.z};
}

/// Clamp a vector to a maximum length, leaving its direction alone.
inline b3Vec3 clamp_length(const b3Vec3& v, float limit) {
    const float len = length(v);
    if (len <= limit || len < 1e-6f) {
        return v;
    }
    return scaled(v, limit / len);
}

/// The angular velocity that takes `from` to `to` in one step of `dt`.
///
/// Used to drive a held prop and a tracked hand: both are told where to be, and both
/// still have to be rigid bodies so the world can push back on them. Turning a target
/// pose into a velocity is what keeps them physical instead of teleporting through walls.
inline b3Vec3 angular_to(const b3Quat& from, const b3Quat& to, float dt) {
    w::Quat delta = w::multiply(w::normalized(from_b3(to)),
                                w::conjugate(w::normalized(from_b3(from))));
    // Shortest arc: q and -q are the same rotation but describe opposite paths.
    if (delta.w < 0.0f) {
        delta = w::Quat{-delta.x, -delta.y, -delta.z, -delta.w};
    }
    const float sin_half = std::sqrt(std::fmax(0.0f, 1.0f - delta.w * delta.w));
    if (sin_half < 1e-5f) {
        return b3Vec3{0.0f, 0.0f, 0.0f};
    }
    const float angle = 2.0f * std::atan2(sin_half, delta.w);
    const float scale = angle / (sin_half * dt);
    return b3Vec3{delta.x * scale, delta.y * scale, delta.z * scale};
}

}  // namespace

class VrWorld : public RefCounted {
    GDCLASS(VrWorld, RefCounted)

public:
    VrWorld() {
        for (std::size_t i = 0; i < kKindCount; ++i) {
            handling_[i] = default_handling(static_cast<std::uint8_t>(i));
        }
        shapes_[kKindCrate] = crate_shape();
        shapes_[kKindBall] = ball_shape();
        shapes_[kKindCar] = car_shape();
        shapes_[kKindPlane] = plane_shape();
        shapes_[kKindBoat] = boat_shape();
    }

    ~VrWorld() override {
        teardown();
    }

    // ---- setup ----

    // client_id 0 means "be the server". Everything else is symmetric: both sides build
    // the same components, archetypes and simulation jobs, because a client has to be
    // able to run the server's simulation in order to predict it.
    bool start(int64_t client_id) {
        teardown();
        is_server_ = client_id == 0;

        b3WorldDef world_def = b3DefaultWorldDef();
        world_def.gravity = b3Vec3{0.0f, -9.81f, 0.0f};
        physics_ = b3CreateWorld(&world_def);
        physics_alive_ = true;
        // Per-PAIR filtering, which category and mask bits cannot express: a held crate
        // has to keep colliding with the world, with other players and with their crates,
        // and stop colliding only with the one person holding it.
        b3World_SetCustomFilterCallback(physics_, &VrWorld::filter_contact, nullptr);

        avatar_state_ = ashiato::sync::register_sync_component<vr::AvatarState>(
            registry_, "AvatarState");
        avatar_input_ = ashiato::sync::register_sync_component<vr::AvatarInput>(
            registry_, "AvatarInput");
        avatar_owner_ = ashiato::sync::register_sync_component<vr::AvatarOwner>(
            registry_, "AvatarOwner");
        body_state_ = ashiato::sync::register_sync_component<vr::BodyState>(
            registry_, "BodyState");
        body_kind_ = ashiato::sync::register_sync_component<vr::BodyKind>(
            registry_, "BodyKind");
        seats_component_ = ashiato::sync::register_sync_component<vr::VehicleSeats>(
            registry_, "VehicleSeats");
        hold_component_ = ashiato::sync::register_sync_component<vr::HoldState>(
            registry_, "HoldState");
        ashiato::sync::set_client_input_component<vr::AvatarInput>(registry_);

        // Both poses sampled between ticks, and both for the same reason the driving
        // module samples the cab and the fold together: a seated player's world pose is
        // DERIVED from the vehicle's, so drawing the avatar from the sample buffer and
        // the vehicle from whatever is live in the ECS would place them at two different
        // instants and open the one gap this design exists to close.
        sampling_marked_ =
            ashiato::sync::set_fractional_tick_sampled<vr::AvatarState>(registry_);
        sampling_marked_ =
            ashiato::sync::set_fractional_tick_sampled<vr::BodyState>(registry_)
            && sampling_marked_;

        // AvatarInput is deliberately ABSENT from this archetype. Replicating input back
        // to its owner makes the server echo each client its own hands a round trip late,
        // and that echo lands on the predicted avatar and overwrites the live tracking it
        // should be predicting with -- so your own hands would lag your real ones by the
        // ping. The driving module established the same thing about a steering wheel
        // three separate times; it is not re-derived here.
        archetype_avatar_ = ashiato::sync::define_archetype(
            registry_, "Avatar",
            {ashiato::sync::replicate<vr::AvatarState>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Interpolate),
             // Everyone needs to know whose avatar this is: the client uses it to pick
             // its OWN for prediction, and without it every entity falls through to
             // interpolation and nothing is predicted at all.
             ashiato::sync::replicate<vr::AvatarOwner>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Step)});

        archetype_vehicle_ = ashiato::sync::define_archetype(
            registry_, "Vehicle",
            {ashiato::sync::replicate<vr::BodyState>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Interpolate),
             ashiato::sync::replicate<vr::BodyKind>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Step),
             // Step, and rolled back on any change: who is in which seat is never
             // simulated by a client, so without the rollback somebody climbing in
             // beside you would sit unapplied in the incoming update until the aircraft
             // happened to be corrected for an unrelated reason.
             ashiato::sync::replicate<vr::VehicleSeats>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Step)});

        archetype_prop_ = ashiato::sync::define_archetype(
            registry_, "Prop",
            {ashiato::sync::replicate<vr::BodyState>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Interpolate),
             ashiato::sync::replicate<vr::BodyKind>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Step),
             ashiato::sync::replicate<vr::HoldState>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Step)});

        if (is_server_) {
            ashiato::sync::ReplicationServerOptions options;
            options.fixed_dt_seconds = fixed_dt_;
            // PeerId, NOT ClientId: TransportFn hands back the same PeerId that was
            // given to receive_packet, and a Godot peer id truncated to sync's uint8
            // ClientId routes packets to the wrong machine or to none.
            options.transport = [this](ashiato::sync::PeerId peer,
                                       const ashiato::BitBuffer& packet) {
                queue_outbound(static_cast<int64_t>(peer), packet);
            };
            server_ = std::make_unique<ashiato::sync::ReplicationServer>(registry_, options);
        } else {
            ashiato::sync::ReplicationClientOptions options;
            options.clock.fixed_dt_seconds = fixed_dt_;
            // A NON-EMPTY connect token is what makes the client handshake at all. With
            // an empty one ReplicationClient declares itself Ready in its constructor,
            // never introduces itself, and the server's client_count() stays at zero
            // while the client sits there "connected" receiving nothing.
            options.session.connect_token = "ashiato-gd-vr";
            options.buffered.buffered_frame_lag = buffered_frames_;
            options.buffered.auto_buffered_frame_lag = auto_buffer_;
            options.buffered.auto_buffered_frame_lag_min = buffered_frames_;
            options.entities.default_mode = ashiato::sync::ReplicationClientMode::BufferedInterpolation;

            // THE line that decides what this feels like in a headset.
            //
            // Three things are predicted, and each for a reason that is really the same
            // reason: this machine has the input that drives them, so it can run the
            // simulation forward without guessing.
            //
            //   your own avatar   -- your hands must answer your hands, not your ping
            //   the vehicle you are flying -- the stick is yours, so the aircraft is
            //                        predictable, and an aircraft that answers a round
            //                        trip late is not flyable
            //   a prop in your hand -- it follows your hand, which is your input
            //
            // Everything else is interpolated, and that is not a compromise. Nobody
            // receives anybody else's input, so a predicted entity you do not drive is a
            // guess resimulation cannot correct: the client rewinds, replays with no
            // input, is wrong again immediately, and rolls back every single frame. The
            // driving module measured that at 300 rollbacks per 300 frames.
            options.entities.mode_selector =
                [this](const ashiato::sync::ReplicatedEntityUpdateView& view) {
                    const auto local = client_ != nullptr ? client_->client_id()
                                                          : ashiato::sync::invalid_client_id;
                    if (local == ashiato::sync::invalid_client_id) {
                        return predict_all_
                            ? ashiato::sync::ReplicationClientMode::Predict
                            : ashiato::sync::ReplicationClientMode::BufferedInterpolation;
                    }
                    vr::AvatarOwner owner;
                    if (view.try_get<vr::AvatarOwner>(registry_, owner)) {
                        if (owner.client == static_cast<std::uint32_t>(local)) {
                            return ashiato::sync::ReplicationClientMode::Predict;
                        }
                    }
                    vr::HoldState hold;
                    if (view.try_get<vr::HoldState>(registry_, hold)
                        && hold.holder == static_cast<std::uint8_t>(local)) {
                        return ashiato::sync::ReplicationClientMode::Predict;
                    }
                    vr::VehicleSeats seats;
                    if (view.try_get<vr::VehicleSeats>(registry_, seats)) {
                        // Seat 0 only. A passenger has no controls, so nothing about the
                        // vehicle depends on their input and predicting it would be the
                        // uncorrectable guess described above.
                        if (seats.occupant[0] == static_cast<std::uint8_t>(local)) {
                            return ashiato::sync::ReplicationClientMode::Predict;
                        }
                    }
                    // Consulted here rather than left to options.entities.default_mode: a
                    // selector that answers for EVERY entity answers first, so the
                    // default is never reached and setting it does nothing at all.
                    return predict_all_
                        ? ashiato::sync::ReplicationClientMode::Predict
                        : ashiato::sync::ReplicationClientMode::BufferedInterpolation;
                };

            options.rollback_prepared_handler =
                [this](ashiato::Registry&,
                       const ashiato::sync::ReplicationClientRollbackPreparedEvent& event) {
                    ++resim_count_;
                    last_resim_frame_ = static_cast<int64_t>(event.rollback_frame);
                    last_resim_span_ = static_cast<int64_t>(event.resim_end_frame)
                        - static_cast<int64_t>(event.rollback_frame) + 1;
                };

            client_ = std::make_unique<ashiato::sync::ReplicationClient>(registry_, options);
            client_->set_packet_sender([this](const ashiato::BitBuffer& packet) {
                queue_outbound(0, packet);
            });
        }

        register_simulation_jobs();
        started_ = true;
        return true;
    }

    void teardown() {
        server_.reset();
        client_.reset();
        if (physics_alive_) {
            b3DestroyWorld(physics_);
            physics_alive_ = false;
        }
        bodies_.clear();
        hands_.clear();
        tags_.clear();
        last_holder_.clear();
        release_grace_.clear();
        overlaps_.clear();
        outbound_.clear();
        pending_destroy_.clear();
        seat_of_.clear();
        avatar_of_.clear();
        last_buttons_.clear();
        frame_open_ = false;
        started_ = false;
    }

    bool is_server() const {
        return is_server_;
    }

    // ---- world ----

    /// Static collision. Called identically on the server and every client: the world is
    /// not replicated, because both sides build it from the same scene data and sending
    /// immovable geometry every frame would be absurd. The price is that both sides must
    /// build byte-identical collision, or a client predicts itself through a wall the
    /// server can see.
    void add_static_box(const Vector3& position, const Vector3& half_extents) {
        if (!started_) {
            return;
        }
        b3BodyDef def = b3DefaultBodyDef();
        def.type = b3_staticBody;
        def.position = b3_pos(position);
        const b3BodyId body = b3CreateBody(physics_, &def);
        b3BoxHull hull = b3MakeBoxHull(half_extents.x, half_extents.y, half_extents.z);
        b3ShapeDef shape = b3DefaultShapeDef();
        b3CreateHullShape(body, &shape, &hull.base);
    }

    // ---- spawning (server only) ----

    int64_t spawn_avatar(int64_t owner_client, const Vector3& position, float yaw) {
        if (!started_ || !is_server_) {
            return 0;
        }
        const ashiato::Entity entity = registry_.create();
        vr::AvatarState state;
        state.x = position.x;
        state.y = position.y;
        state.z = position.z;
        state.yaw = yaw;
        registry_.add<vr::AvatarState>(entity, state);
        registry_.add<vr::AvatarInput>(entity, vr::AvatarInput{});
        ashiato::sync::set_owner(registry_, entity,
                                 static_cast<ashiato::sync::ClientId>(owner_client));
        registry_.add<vr::AvatarOwner>(
            entity, vr::AvatarOwner{static_cast<std::uint32_t>(owner_client)});
        registry_.add<ashiato::sync::Replicated>(
            entity, ashiato::sync::Replicated{archetype_avatar_});
        ensure_body(entity);
        return static_cast<int64_t>(entity.value);
    }

    int64_t spawn_body(int64_t kind, const Vector3& position, float yaw) {
        if (!started_ || !is_server_) {
            return 0;
        }
        const std::size_t index = kind_index(kind);
        const ashiato::Entity entity = registry_.create();
        vr::BodyState state;
        state.x = position.x;
        state.y = position.y;
        state.z = position.z;
        state.rot = from_b3(yaw_quat(yaw));
        registry_.add<vr::BodyState>(entity, state);
        registry_.add<vr::BodyKind>(entity,
                                    vr::BodyKind{static_cast<std::uint8_t>(index)});
        if (shapes_[index].vehicle) {
            registry_.add<vr::VehicleSeats>(entity, vr::VehicleSeats{});
            registry_.add<ashiato::sync::Replicated>(
                entity, ashiato::sync::Replicated{archetype_vehicle_});
        } else {
            registry_.add<vr::HoldState>(entity, vr::HoldState{});
            registry_.add<ashiato::sync::Replicated>(
                entity, ashiato::sync::Replicated{archetype_prop_});
        }
        ensure_body(entity);
        return static_cast<int64_t>(entity.value);
    }

    /// Take something out of the world.
    ///
    /// Removes the Replicated COMPONENT and destroys the entity a tick later, which is
    /// not a nicety. The server watches the registry's dirty frame for
    /// `each_removed<Replicated>` -- component removals, not dead entities -- so an
    /// entity destroyed outright vanishes locally while the server's replicated slot
    /// lives on, and every client keeps drawing it for ever.
    void despawn(int64_t entity_id) {
        if (!started_ || !is_server_) {
            return;
        }
        const ashiato::Entity entity{static_cast<std::uint64_t>(entity_id)};
        vacate_all_seats_of(entity);
        release_props_held_by_entity(entity);
        release_bodies(entity);
        registry_.remove<ashiato::sync::Replicated>(entity);
        pending_destroy_.push_back(entity);
    }

    // ---- clients ----

    void add_client(int64_t client_id) {
        if (server_) {
            server_->add_client(static_cast<ashiato::sync::ClientId>(client_id));
        }
    }

    bool remove_client(int64_t client_id) {
        if (!started_ || server_ == nullptr) {
            return false;
        }
        bool removed = false;
        VR_TRY(removed = server_->remove_client(
                   registry_, static_cast<ashiato::sync::ClientId>(client_id)),
               return false);
        return removed;
    }

    PackedInt64Array connected_clients() {
        PackedInt64Array out;
        if (server_ == nullptr) {
            return out;
        }
        VR_TRY(
            {
                for (const auto id : server_->client_ids()) {
                    out.push_back(static_cast<int64_t>(id));
                }
            },
            return out);
        return out;
    }

    /// The id the SERVER assigned us. Returns 0 while unassigned rather than sync's
    /// invalid_client_id, which is 255 -- a value that sails through an "is it assigned
    /// yet" test written as `> 0` and names a client that does not exist.
    int64_t local_client_id() const {
        if (client_ == nullptr) {
            return 0;
        }
        const auto id = client_->client_id();
        return id == ashiato::sync::invalid_client_id ? 0 : static_cast<int64_t>(id);
    }

    // ---- per frame ----

    /// The local player's whole intent for this tick: where their head and hands are,
    /// what the sticks are doing, and which buttons are down.
    ///
    /// A Dictionary rather than twenty arguments because this is called once per tick
    /// from GDScript and the argument list would otherwise be unreadable and unstable.
    /// Missing keys keep their previous value, so a caller that only moves one hand does
    /// not have to resend the rest.
    void set_input(const Dictionary& input) {
        vr::AvatarInput& next = pending_input_;
        read_pose(input, "head", next.head_x, next.head_y, next.head_z, next.head_rot);
        read_pose(input, "left", next.left_x, next.left_y, next.left_z, next.left_rot);
        read_pose(input, "right", next.right_x, next.right_y, next.right_z, next.right_rot);
        if (input.has("stick_left")) {
            const Vector2 stick = input["stick_left"];
            next.stick_left_x = stick.x;
            next.stick_left_y = stick.y;
        }
        if (input.has("stick_right")) {
            const Vector2 stick = input["stick_right"];
            next.stick_right_x = stick.x;
            next.stick_right_y = stick.y;
        }
        if (input.has("trigger_left")) {
            next.trigger_left = static_cast<float>(input["trigger_left"]);
        }
        if (input.has("trigger_right")) {
            next.trigger_right = static_cast<float>(input["trigger_right"]);
        }
        if (input.has("grip_left")) {
            next.grip_left = static_cast<float>(input["grip_left"]);
        }
        if (input.has("grip_right")) {
            next.grip_right = static_cast<float>(input["grip_right"]);
        }
        if (input.has("buttons")) {
            next.buttons = static_cast<std::uint8_t>(static_cast<int64_t>(input["buttons"]));
        }
        if (input.has("gesture_left")) {
            next.gesture_left =
                static_cast<std::uint8_t>(static_cast<int64_t>(input["gesture_left"]));
        }
        if (input.has("gesture_right")) {
            next.gesture_right =
                static_cast<std::uint8_t>(static_cast<int64_t>(input["gesture_right"]));
        }

        if (client_) {
            VR_TRY(adopt_local_avatars(), return);
            VR_TRY(client_->set_input<vr::AvatarInput>(registry_, next), return);
        } else if (server_) {
            VR_TRY(server_->set_local_input<vr::AvatarInput>(registry_, next), return);
        }
    }

    void tick(double dt) {
        // Entities whose Replicated component was removed last tick. Destroying them in
        // the same breath as the removal loses the removal: the dirty frame that carries
        // it is broadcast during the NEXT tick, and a dead entity has nothing left to
        // report.
        if (!pending_destroy_.empty() && is_server_) {
            for (const ashiato::Entity entity : pending_destroy_) {
                if (registry_.alive(entity)) {
                    registry_.destroy(entity);
                }
            }
            pending_destroy_.clear();
        }
        rebuild_maps();
        // One second of SIMULATED time per sample, so the rate reported is per second of
        // game rather than per second of however fast this machine happened to run.
        window_seconds_ += dt;
        if (window_seconds_ >= 1.0) {
            sent_per_second_ = static_cast<double>(window_sent_) / window_seconds_;
            received_per_second_ = static_cast<double>(window_received_) / window_seconds_;
            window_sent_ = 0;
            window_received_ = 0;
            window_seconds_ = 0.0;
        }
        if (server_) {
            VR_TRY(server_->tick(registry_, dt), return);
        } else if (client_) {
            VR_TRY(adopt_local_avatars(), return);
            VR_TRY(client_->tick(registry_, dt), return);
        }
    }

    // ---- transport, owned by the caller ----

    Array take_outbound() {
        Array out;
        for (auto& entry : outbound_) {
            Dictionary packet;
            packet["peer"] = entry.peer;
            packet["bytes"] = entry.bytes;
            // Carried with the payload because the transport has to hand it back: a
            // BitBuffer is bit-addressed and its last byte is usually partial, so a
            // buffer rebuilt from bytes alone leaves the reader believing there are up
            // to 7 bits of real data past the end of the packet.
            packet["bits"] = entry.bit_size;
            out.push_back(packet);
        }
        outbound_.clear();
        return out;
    }

    void deliver(int64_t from_peer, const PackedByteArray& bytes, int64_t bit_size) {
        std::vector<std::uint8_t> raw(static_cast<std::size_t>(bytes.size()));
        if (!raw.empty()) {
            std::memcpy(raw.data(), bytes.ptr(), raw.size());
        }
        window_received_ += static_cast<std::size_t>(bytes.size());
        ashiato::BitBuffer buffer;
        buffer.assign_bytes(std::move(raw), static_cast<std::size_t>(bit_size));
        if (server_) {
            VR_TRY(server_->receive_packet(
                       static_cast<ashiato::sync::PeerId>(from_peer), std::move(buffer)),
                   return);
        } else if (client_) {
            VR_TRY(client_->receive(registry_, std::move(buffer)), return);
        }
    }

    // ---- reading state back ----

    /// Every avatar sampled at the current fractional frame, with seated players already
    /// composed onto the vehicle carrying them.
    ///
    /// The composition happens HERE rather than in the renderer, and from the same
    /// sample buffer, which is the whole point. A renderer that read the avatar from the
    /// buffer and the vehicle from the live ECS would be drawing two different instants,
    /// and the seat -- the one frame that must be common to the player and the aircraft
    /// -- would come apart. Doing the arithmetic once, here, means there is exactly one
    /// definition of where a seated player is.
    Array sampled_avatars() {
        Array out;
        const ashiato::sync::FractionalTickSampleBuffer* frame_ptr = display_frame();
        if (frame_ptr == nullptr) {
            return out;
        }

        // First pass: every body pose at this fractional frame, so a seated avatar can be
        // composed against the vehicle as it is being DRAWN rather than as it is live.
        std::unordered_map<std::uint64_t, vr::BodyState> poses;
        for (const auto& sample : frame_ptr->entities) {
            vr::BodyState body;
            if (sample.try_get_sampled_value<vr::BodyState>(registry_, body)) {
                poses[sample.local_entity.value] = body;
            }
        }

        for (const auto& sample : frame_ptr->entities) {
            vr::AvatarState state;
            const bool have_value =
                sample.try_get_sampled_value<vr::AvatarState>(registry_, state);
            if (!have_value) {
                continue;
            }
            Dictionary avatar;
            avatar["entity"] = static_cast<int64_t>(sample.local_entity.value);
            avatar["owner"] = avatar_owner(static_cast<int64_t>(sample.local_entity.value));
            avatar["seated"] = state.seated != 0;
            avatar["seat"] = static_cast<int64_t>(state.seat);
            avatar["predicted"] = sample.mode == ashiato::sync::ReplicationClientMode::Predict;
            avatar["alpha"] = sample.alpha;
            avatar["frame"] = static_cast<int64_t>(sample.frame);

            // While SEATED these fields are a small offset inside the seat, not a place
            // in the world -- so they are only a world pose once the vehicle has been
            // composed onto them. `composed` says whether that happened.
            //
            // It was not said before, and the silence was a bug: a seated avatar whose
            // vehicle had no sample this frame was published at its seat-local offset,
            // which is a few millimetres from the WORLD origin. The player was thrown
            // across the map and back for one frame, which does not read as "a missing
            // sample" -- it reads as violent jitter.
            bool composed = state.seated == 0;
            b3Pos origin{state.x, state.y, state.z};
            b3Quat basis = yaw_quat(state.yaw);
            int64_t vehicle_entity = 0;

            if (state.seated != 0) {
                const int64_t owner = avatar["owner"];
                const auto found = seat_of_.find(static_cast<std::uint8_t>(owner));
                if (found != seat_of_.end()) {
                    vehicle_entity = static_cast<int64_t>(found->second.vehicle.value);
                    const auto pose = poses.find(found->second.vehicle.value);
                    if (pose != poses.end()) {
                        composed = true;
                        const Seat& seat = shapes_[kind_index(body_kind(vehicle_entity))]
                                               .seat[found->second.seat];
                        const b3Quat vehicle_rot = to_b3(w::normalized(pose->second.rot));
                        const b3Vec3 seat_offset =
                            rotate(vehicle_rot, b3Vec3{seat.x, seat.y, seat.z});
                        // vehicle * seat * in-seat-shuffle, in that order. The shuffle is
                        // the small offset the avatar carries while seated, and it is
                        // measured in the SEAT's frame -- which is why it is rotated by
                        // both the vehicle and the seat before being added.
                        const b3Quat seat_rot =
                            to_b3(w::multiply(from_b3(vehicle_rot), from_b3(yaw_quat(seat.yaw))));
                        const b3Vec3 shuffle = rotate(seat_rot, b3Vec3{state.x, state.y, state.z});
                        origin = b3Pos{pose->second.x + seat_offset.x + shuffle.x,
                                       pose->second.y + seat_offset.y + shuffle.y,
                                       pose->second.z + seat_offset.z + shuffle.z};
                        basis = to_b3(w::multiply(from_b3(seat_rot),
                                                  from_b3(yaw_quat(state.yaw))));
                    }
                }
            }

            avatar["vehicle"] = vehicle_entity;
            // True when "position" and "basis" mean something in the world. False means
            // hold whatever you drew last frame; it does NOT mean draw them at the origin.
            avatar["composed"] = composed;
            // The in-seat offset on its own, in the SEAT's frame, so a caller that would
            // rather lock the player to the vehicle it can see -- rather than to a second
            // composition of the same numbers -- has the piece it needs. Meaningless
            // unless "seated".
            avatar["seat_offset"] = Vector3(state.x, state.y, state.z);
            avatar["seat_yaw"] = state.yaw;
            avatar["position"] = Vector3(origin.x, origin.y, origin.z);
            avatar["basis"] = Quaternion(basis.v.x, basis.v.y, basis.v.z, basis.s);
            avatar["velocity"] = Vector3(state.vx, state.vy, state.vz);
            // Head and hands come back in the avatar's own frame AND in world, because
            // the caller wants both: world to place a mesh, local to drive an IK rig.
            put_local(avatar, "head", state.head_x, state.head_y, state.head_z,
                      state.head_rot, origin, basis);
            put_local(avatar, "left", state.left_x, state.left_y, state.left_z,
                      state.left_rot, origin, basis);
            put_local(avatar, "right", state.right_x, state.right_y, state.right_z,
                      state.right_rot, origin, basis);
            avatar["grip_left"] = state.grip_left;
            avatar["grip_right"] = state.grip_right;
            avatar["gesture_left"] = static_cast<int64_t>(state.gesture_left);
            avatar["gesture_right"] = static_cast<int64_t>(state.gesture_right);
            out.push_back(avatar);
        }
        return out;
    }

    /// Every vehicle and prop at the current fractional frame.
    Array sampled_bodies() {
        Array out;
        const ashiato::sync::FractionalTickSampleBuffer* frame_ptr = display_frame();
        if (frame_ptr == nullptr) {
            return out;
        }
        for (const auto& sample : frame_ptr->entities) {
            vr::BodyState state;
            if (!sample.try_get_sampled_value<vr::BodyState>(registry_, state)) {
                continue;
            }
            const int64_t entity_id = static_cast<int64_t>(sample.local_entity.value);
            Dictionary body;
            body["entity"] = entity_id;
            body["kind"] = body_kind(entity_id);
            body["position"] = Vector3(state.x, state.y, state.z);
            const w::Quat rot = w::normalized(state.rot);
            body["basis"] = Quaternion(rot.x, rot.y, rot.z, rot.w);
            body["velocity"] = Vector3(state.vx, state.vy, state.vz);
            body["spin"] = Vector3(state.wx, state.wy, state.wz);
            body["predicted"] = sample.mode == ashiato::sync::ReplicationClientMode::Predict;
            body["alpha"] = sample.alpha;
            body["frame"] = static_cast<int64_t>(sample.frame);
            const auto* hold = registry_.try_get<vr::HoldState>(sample.local_entity);
            body["holder"] = hold_client(hold);
            body["hand"] = hold_hand(hold);
            out.push_back(body);
        }
        return out;
    }

    /// One avatar straight out of the ECS tick, uncomposed and unsampled.
    ///
    /// This is the GAMEPLAY answer, not the rendering one: it is the tick the simulation
    /// is actually on, which is what a question like "is this player inside the trigger
    /// volume" wants. Use sampled_avatars() to draw with -- that is the fractional frame,
    /// and it has seated players already composed onto their vehicles.
    Dictionary avatar_state(int64_t entity_id) {
        Dictionary out;
        const ashiato::Entity entity{static_cast<std::uint64_t>(entity_id)};
        const auto* state = registry_.try_get<vr::AvatarState>(entity);
        if (state == nullptr) {
            return out;
        }
        SeatRef seat;
        const auto* owner = registry_.try_get<vr::AvatarOwner>(entity);
        if (owner != nullptr) {
            const auto found = seat_of_.find(static_cast<std::uint8_t>(owner->client));
            if (found != seat_of_.end()) {
                seat = found->second;
            }
        }
        b3Pos origin{};
        b3Quat basis{};
        avatar_frame(*state, seat, origin, basis);
        out["entity"] = entity_id;
        out["owner"] = owner == nullptr ? -1 : static_cast<int64_t>(owner->client);
        out["seated"] = state->seated != 0;
        out["seat"] = static_cast<int64_t>(state->seat);
        out["vehicle"] = static_cast<int64_t>(seat.vehicle.value);
        out["position"] = Vector3(origin.x, origin.y, origin.z);
        out["basis"] = Quaternion(basis.v.x, basis.v.y, basis.v.z, basis.s);
        out["yaw"] = state->yaw;
        out["velocity"] = Vector3(state->vx, state->vy, state->vz);
        put_local(out, "head", state->head_x, state->head_y, state->head_z, state->head_rot,
                  origin, basis);
        put_local(out, "left", state->left_x, state->left_y, state->left_z, state->left_rot,
                  origin, basis);
        put_local(out, "right", state->right_x, state->right_y, state->right_z,
                  state->right_rot, origin, basis);
        out["grip_left"] = state->grip_left;
        out["grip_right"] = state->grip_right;
        out["gesture_left"] = static_cast<int64_t>(state->gesture_left);
        out["gesture_right"] = static_cast<int64_t>(state->gesture_right);
        return out;
    }

    /// One vehicle or prop straight out of the ECS tick. Same distinction as above.
    Dictionary body_state(int64_t entity_id) {
        Dictionary out;
        const ashiato::Entity entity{static_cast<std::uint64_t>(entity_id)};
        const auto* state = registry_.try_get<vr::BodyState>(entity);
        if (state == nullptr) {
            return out;
        }
        const w::Quat rot = w::normalized(state->rot);
        out["entity"] = entity_id;
        out["kind"] = body_kind(entity_id);
        out["position"] = Vector3(state->x, state->y, state->z);
        out["basis"] = Quaternion(rot.x, rot.y, rot.z, rot.w);
        out["velocity"] = Vector3(state->vx, state->vy, state->vz);
        out["spin"] = Vector3(state->wx, state->wy, state->wz);
        const auto* hold = registry_.try_get<vr::HoldState>(entity);
        out["holder"] = hold_client(hold);
        out["hand"] = hold_hand(hold);
        return out;
    }

    /// Every entity one hand is currently inside.
    ///
    /// A hand exerts no force, so this is the only way it knows it is touching anything --
    /// and it is what a drag, a button press or a lever needs: the thing under your hand
    /// when you closed it. Excludes the player's own body.
    PackedInt64Array hand_overlaps(int64_t avatar_entity, int64_t hand) const {
        PackedInt64Array out;
        const auto found = overlaps_.find(
            hand_key(ashiato::Entity{static_cast<std::uint64_t>(avatar_entity)},
                     static_cast<std::uint8_t>(hand)));
        if (found == overlaps_.end()) {
            return out;
        }
        for (const std::uint64_t entity : found->second) {
            out.push_back(static_cast<int64_t>(entity));
        }
        return out;
    }

    /// Everything, sampled at the instant being DRAWN rather than the last tick.
    ///
    /// Both halves matter and they are different calls. fractional_tick_frame() is what
    /// blends out correction errors and keeps sync's own buffer warm, so it is called
    /// every frame regardless. Then, if any real time has passed since the tick, the same
    /// frame is re-sampled a fraction further on -- which is exactly what the clock would
    /// report if it advanced between ticks, and it does not.
    const ashiato::sync::FractionalTickSampleBuffer* display_frame() {
        // Not before the session is Ready. The sample buffer is built from the buffered
        // and predicted timelines, and asking for it while those are empty takes the
        // process down with no error -- and the renderer calls this every frame from the
        // moment the scene loads, well before the handshake finishes.
        if (client_ == nullptr
            || client_->connection_state()
                != ashiato::sync::ReplicationClientConnectionState::Ready) {
            return nullptr;
        }
        const ashiato::sync::FractionalTickSampleBuffer* frame_ptr = nullptr;
        VR_TRY(frame_ptr = &client_->fractional_tick_frame(registry_), return nullptr);
        if (frame_ptr == nullptr || !render_paced_) {
            return frame_ptr;
        }
        // One tick behind, walked across by real time. Both ends of that interval have
        // already been simulated or received, which is what makes it smooth rather than
        // a guess that clamps.
        const double target = client_->fractional_tick_target_frame() - 1.0 + render_alpha_;
        bool sampled = false;
        VR_TRY(sampled = client_->sample_fractional_tick_frame(registry_, target,
                                                               render_frame_),
               return frame_ptr);
        return sampled ? &render_frame_ : frame_ptr;
    }

    int64_t avatar_owner(int64_t entity_id) const {
        const ashiato::Entity entity{static_cast<std::uint64_t>(entity_id)};
        const auto* owner = registry_.try_get<vr::AvatarOwner>(entity);
        return owner == nullptr ? -1 : static_cast<int64_t>(owner->client);
    }

    int64_t body_kind(int64_t entity_id) const {
        const ashiato::Entity entity{static_cast<std::uint64_t>(entity_id)};
        const auto* kind = registry_.try_get<vr::BodyKind>(entity);
        return kind == nullptr ? 0 : static_cast<int64_t>(kind_index(kind->kind));
    }

    PackedInt64Array body_seats(int64_t entity_id) const {
        PackedInt64Array out;
        const ashiato::Entity entity{static_cast<std::uint64_t>(entity_id)};
        const auto* seats = registry_.try_get<vr::VehicleSeats>(entity);
        if (seats == nullptr) {
            return out;
        }
        for (std::size_t i = 0; i < vr::kMaxSeats; ++i) {
            out.push_back(seats->occupant[i] == vr::kNoOccupant
                              ? -1
                              : static_cast<int64_t>(seats->occupant[i]));
        }
        return out;
    }

    /// Where a client is sitting: {"vehicle": entity, "seat": index}, or an empty
    /// dictionary when they are on foot.
    Dictionary seat_of_client(int64_t client_id) const {
        Dictionary out;
        const auto found = seat_of_.find(static_cast<std::uint8_t>(client_id));
        if (found == seat_of_.end()) {
            return out;
        }
        out["vehicle"] = static_cast<int64_t>(found->second.vehicle.value);
        out["seat"] = static_cast<int64_t>(found->second.seat);
        return out;
    }

    /// The world pose of a seat, derived from the LIVE vehicle pose.
    ///
    /// For a renderer, prefer the pose already composed into sampled_avatars(): this one
    /// reads the ECS tick rather than the fractional frame being drawn, which is the
    /// right answer for gameplay questions ("is this seat inside a wall") and the wrong
    /// one for placing a camera.
    Dictionary seat_pose(int64_t entity_id, int64_t seat_index) const {
        Dictionary out;
        const ashiato::Entity entity{static_cast<std::uint64_t>(entity_id)};
        const auto* state = registry_.try_get<vr::BodyState>(entity);
        if (state == nullptr || seat_index < 0
            || static_cast<std::size_t>(seat_index) >= vr::kMaxSeats) {
            return out;
        }
        const Shape& shape = shapes_[kind_index(body_kind(entity_id))];
        const Seat& seat = shape.seat[seat_index];
        const b3Quat rot = to_b3(w::normalized(state->rot));
        const b3Vec3 offset = rotate(rot, b3Vec3{seat.x, seat.y, seat.z});
        const w::Quat basis = w::multiply(from_b3(rot), from_b3(yaw_quat(seat.yaw)));
        out["position"] = Vector3(state->x + offset.x, state->y + offset.y,
                                  state->z + offset.z);
        out["basis"] = Quaternion(basis.x, basis.y, basis.z, basis.w);
        out["valid"] = seat_index < shape.seats;
        return out;
    }

    PackedInt64Array avatar_entities() {
        PackedInt64Array out;
        registry_.view<const vr::AvatarState>().each(
            [&](ashiato::Entity entity, const vr::AvatarState&) {
                out.push_back(static_cast<int64_t>(entity.value));
            });
        return out;
    }

    PackedInt64Array body_entities() {
        PackedInt64Array out;
        registry_.view<const vr::BodyState>().each(
            [&](ashiato::Entity entity, const vr::BodyState&) {
                out.push_back(static_cast<int64_t>(entity.value));
            });
        return out;
    }

    // ---- tuning and diagnostics ----

    int64_t kind_count() const {
        return static_cast<int64_t>(kKindCount);
    }

    String kind_name(int64_t kind) const {
        return String(kind_name_of(kind_index(kind)));
    }

    /// The shape of a kind, asked of the simulation rather than written down twice in
    /// the renderer. A constant here and a matching constant there holds until one of
    /// them changes, and then the mesh is drawn where the physics has nothing.
    Dictionary kind_geometry(int64_t kind) const {
        const Shape& shape = shapes_[kind_index(kind)];
        Dictionary out;
        out["name"] = String(shape.name);
        out["vehicle"] = shape.vehicle;
        out["sphere"] = shape.sphere;
        out["extents"] = Vector3(shape.hx, shape.hy, shape.hz);
        out["mass"] = shape.mass;
        out["seats"] = static_cast<int64_t>(shape.seats);
        Array seats;
        for (int i = 0; i < shape.seats; ++i) {
            Dictionary seat;
            seat["position"] = Vector3(shape.seat[i].x, shape.seat[i].y, shape.seat[i].z);
            seat["yaw"] = shape.seat[i].yaw;
            seats.push_back(seat);
        }
        out["seat_poses"] = seats;
        return out;
    }

    void set_handling(int64_t kind, const Dictionary& values) {
        Handling& h = handling_[kind_index(kind)];
        h.thrust = dict_get(values, "thrust", h.thrust);
        h.brake = dict_get(values, "brake", h.brake);
        h.drag = dict_get(values, "drag", h.drag);
        h.angular_damping = dict_get(values, "angular_damping", h.angular_damping);
        h.rolling_resistance = dict_get(values, "rolling_resistance", h.rolling_resistance);
        h.grip = dict_get(values, "grip", h.grip);
        h.steer_rate = dict_get(values, "steer_rate", h.steer_rate);
        h.steer_reference = dict_get(values, "steer_reference", h.steer_reference);
        h.lift = dict_get(values, "lift", h.lift);
        h.stall_angle = dict_get(values, "stall_angle", h.stall_angle);
        h.pitch_rate = dict_get(values, "pitch_rate", h.pitch_rate);
        h.roll_rate = dict_get(values, "roll_rate", h.roll_rate);
        h.rudder_rate = dict_get(values, "rudder_rate", h.rudder_rate);
        h.control_authority = dict_get(values, "control_authority", h.control_authority);
        h.weathervane = dict_get(values, "weathervane", h.weathervane);
        h.water_level = dict_get(values, "water_level", h.water_level);
        h.buoyancy = dict_get(values, "buoyancy", h.buoyancy);
        h.water_drag = dict_get(values, "water_drag", h.water_drag);
    }

    /// What a kind is ACTUALLY using. `set_handling` treats a misspelled key as absent,
    /// so a typo leaves the setting at its default while the game goes on believing it
    /// was applied; reading it back is the only way to catch that.
    Dictionary handling(int64_t kind) const {
        const Handling& h = handling_[kind_index(kind)];
        Dictionary out;
        out["thrust"] = h.thrust;
        out["brake"] = h.brake;
        out["drag"] = h.drag;
        out["angular_damping"] = h.angular_damping;
        out["rolling_resistance"] = h.rolling_resistance;
        out["grip"] = h.grip;
        out["steer_rate"] = h.steer_rate;
        out["steer_reference"] = h.steer_reference;
        out["lift"] = h.lift;
        out["stall_angle"] = h.stall_angle;
        out["pitch_rate"] = h.pitch_rate;
        out["roll_rate"] = h.roll_rate;
        out["rudder_rate"] = h.rudder_rate;
        out["control_authority"] = h.control_authority;
        out["weathervane"] = h.weathervane;
        out["water_level"] = h.water_level;
        out["buoyancy"] = h.buoyancy;
        out["water_drag"] = h.water_drag;
        return out;
    }

    /// How long ago the last tick() was, in seconds. Fed once per RENDER frame.
    ///
    /// Calling this at all switches drawing to RENDER PACING: the world is sampled a
    /// whole tick behind the simulation and walked across that tick by real time, instead
    /// of being sampled wherever the last tick happened to leave the clock.
    ///
    /// The one frame of lag is the price and it is not avoidable by being cleverer. sync
    /// advances its display clock only inside tick(), and its target rides at the newest
    /// frame the buffer holds -- measured, there is about a third of a frame of room in
    /// front of it before sampling clamps, and which third depends on where the last tick
    /// left the fraction. So there is nothing in front to interpolate towards, and the
    /// only interval that is reliably complete at both ends is the one just behind.
    ///
    /// Why it is needed even with the simulation at the display rate: Godot's physics
    /// step and its render frame are not locked to each other. Two ticks land in one
    /// drawn frame and none in the next, so the drawn pose advances by two frames' worth
    /// and then by nothing. Standing still that is invisible; in a moving vehicle it is
    /// the chair juddering underneath you.
    ///
    /// Head and hands do NOT pay this. They are tracker poses applied on top of the
    /// origin, so they lag exactly as much as the thing they are attached to and never
    /// swim relative to the cockpit around them.
    void set_render_time(double seconds_since_tick) {
        render_paced_ = true;
        const double alpha = seconds_since_tick / static_cast<double>(fixed_dt_);
        // Clamped rather than extrapolated. A frame that took longer than a tick holds at
        // the newest pose for a moment, which reads as a hitch; guessing past it reads as
        // the world lurching and then being pulled back.
        render_alpha_ = std::fmax(0.0, std::fmin(1.0, alpha));
    }

    void set_interpolation(int buffered_frames, bool automatic) {
        buffered_frames_ = static_cast<ashiato::sync::SyncFrame>(std::max(buffered_frames, 1));
        auto_buffer_ = automatic;
    }

    void set_predict_all(bool predict_all) {
        predict_all_ = predict_all;
    }

    Dictionary net_status() {
        Dictionary out;
        out["started"] = started_;
        out["server"] = is_server_;
        out["client_id"] = local_client_id();
        out["sampling"] = sampling_marked_;
        if (client_ != nullptr) {
            out["ready"] = client_->connection_state()
                == ashiato::sync::ReplicationClientConnectionState::Ready;
        } else {
            out["ready"] = server_ != nullptr;
        }
        if (server_ != nullptr) {
            out["clients"] = static_cast<int64_t>(server_->client_count());
        }
        // How many times anybody sat down, stood up, grabbed or let go. Structural
        // events are rare and server-only, so a running count is cheap -- and it is the
        // difference between "the seat did not work" and "the seat worked twice".
        out["seat_changes"] = seat_changes_;
        out["grab_changes"] = grab_changes_;
        out["tick_rate"] = tick_rate();
        out["buffer_frames"] = static_cast<int64_t>(buffered_frames_);
        out["bytes_out_per_second"] = sent_per_second_;
        out["bytes_in_per_second"] = received_per_second_;
        return out;
    }

    Dictionary timing() const {
        Dictionary out;
        if (client_ == nullptr) {
            return out;
        }
        const auto& stats = client_->timing_stats();
        out["latency_frames"] = stats.latency_frames;
        out["jitter_frames"] = stats.jitter_frames;
        out["buffer_frames"] = static_cast<int64_t>(stats.current_buffered_frame_lag);
        out["buffer_target"] = static_cast<int64_t>(stats.target_buffered_frame_lag);
        out["prediction_lead"] = static_cast<int64_t>(stats.current_prediction_lead_frames);
        out["packets_received"] = static_cast<int64_t>(stats.server_update_packets_received);
        out["packets_missing"] = static_cast<int64_t>(stats.server_update_packets_missing);
        InputPacketCounters::describe(*client_, out);
        return out;
    }

    Dictionary resim_stats() const {
        Dictionary out;
        out["count"] = resim_count_;
        out["last_frame"] = last_resim_frame_;
        out["last_span"] = last_resim_span_;
        return out;
    }

    /// The step this world is simulating at, in seconds.
    float fixed_dt() const {
        return fixed_dt_;
    }

    float tick_rate() const {
        return 1.0f / fixed_dt_;
    }

    /// Choose the tick rate. Takes effect at the next start(), never mid-session.
    ///
    /// Changing it under a running world would be changing the meaning of every frame
    /// number already in the buffers and in prediction history, so it is refused rather
    /// than half-applied. The game restarts the world instead, which is also the only
    /// honest way to change it in a session: every peer has to move together.
    bool set_tick_rate(float hz) {
        if (started_) {
            UtilityFunctions::push_warning(
                "[VrWorld] set_tick_rate ignored: takes effect at the next start()");
            return false;
        }
        if (!(hz >= kMinTickHz && hz <= kMaxTickHz)) {
            UtilityFunctions::push_error(
                String("[VrWorld] tick rate must be between ")
                + String::num(kMinTickHz, 0) + " and " + String::num(kMaxTickHz, 0));
            return false;
        }
        fixed_dt_ = 1.0f / hz;
        return true;
    }

    /// How many frames behind the server other people are drawn, changed LIVE.
    ///
    /// Unlike the tick rate this is per-machine and costs nobody else anything: it only
    /// decides how far into the past this client draws entities it is interpolating. More
    /// frames survive more jitter and loss; fewer show you the world sooner. It is the
    /// other half of the bandwidth trade, because a lower tick rate means each frame
    /// covers more time and a fixed frame count buys proportionally more slack.
    bool set_buffer_frames(int frames) {
        buffered_frames_ = static_cast<ashiato::sync::SyncFrame>(std::max(frames, 1));
        if (client_ == nullptr) {
            return false;
        }
        bool applied = false;
        VR_TRY(applied = client_->set_buffered_frame_lag(buffered_frames_), return false);
        return applied;
    }

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("start", "client_id"), &VrWorld::start);
        ClassDB::bind_method(D_METHOD("teardown"), &VrWorld::teardown);
        ClassDB::bind_method(D_METHOD("is_server"), &VrWorld::is_server);
        ClassDB::bind_method(D_METHOD("fixed_dt"), &VrWorld::fixed_dt);
        ClassDB::bind_method(D_METHOD("tick_rate"), &VrWorld::tick_rate);
        ClassDB::bind_method(D_METHOD("set_tick_rate", "hz"), &VrWorld::set_tick_rate);
        ClassDB::bind_method(D_METHOD("set_buffer_frames", "frames"),
                             &VrWorld::set_buffer_frames);
        ClassDB::bind_method(D_METHOD("add_static_box", "position", "half_extents"),
                             &VrWorld::add_static_box);
        ClassDB::bind_method(D_METHOD("spawn_avatar", "owner_client", "position", "yaw"),
                             &VrWorld::spawn_avatar);
        ClassDB::bind_method(D_METHOD("spawn_body", "kind", "position", "yaw"),
                             &VrWorld::spawn_body);
        ClassDB::bind_method(D_METHOD("despawn", "entity"), &VrWorld::despawn);
        ClassDB::bind_method(D_METHOD("add_client", "client_id"), &VrWorld::add_client);
        ClassDB::bind_method(D_METHOD("remove_client", "client_id"), &VrWorld::remove_client);
        ClassDB::bind_method(D_METHOD("connected_clients"), &VrWorld::connected_clients);
        ClassDB::bind_method(D_METHOD("local_client_id"), &VrWorld::local_client_id);
        ClassDB::bind_method(D_METHOD("set_input", "input"), &VrWorld::set_input);
        ClassDB::bind_method(D_METHOD("tick", "dt"), &VrWorld::tick);
        ClassDB::bind_method(D_METHOD("take_outbound"), &VrWorld::take_outbound);
        ClassDB::bind_method(D_METHOD("deliver", "from_peer", "bytes", "bits"),
                             &VrWorld::deliver);
        ClassDB::bind_method(D_METHOD("sampled_avatars"), &VrWorld::sampled_avatars);
        ClassDB::bind_method(D_METHOD("sampled_bodies"), &VrWorld::sampled_bodies);
        ClassDB::bind_method(D_METHOD("avatar_entities"), &VrWorld::avatar_entities);
        ClassDB::bind_method(D_METHOD("body_entities"), &VrWorld::body_entities);
        ClassDB::bind_method(D_METHOD("avatar_state", "entity"), &VrWorld::avatar_state);
        ClassDB::bind_method(D_METHOD("body_state", "entity"), &VrWorld::body_state);
        ClassDB::bind_method(D_METHOD("hand_overlaps", "avatar_entity", "hand"),
                             &VrWorld::hand_overlaps);
        ClassDB::bind_method(D_METHOD("avatar_owner", "entity"), &VrWorld::avatar_owner);
        ClassDB::bind_method(D_METHOD("body_kind", "entity"), &VrWorld::body_kind);
        ClassDB::bind_method(D_METHOD("body_seats", "entity"), &VrWorld::body_seats);
        ClassDB::bind_method(D_METHOD("seat_of_client", "client_id"),
                             &VrWorld::seat_of_client);
        ClassDB::bind_method(D_METHOD("seat_pose", "entity", "seat"), &VrWorld::seat_pose);
        ClassDB::bind_method(D_METHOD("kind_count"), &VrWorld::kind_count);
        ClassDB::bind_method(D_METHOD("kind_name", "kind"), &VrWorld::kind_name);
        ClassDB::bind_method(D_METHOD("kind_geometry", "kind"), &VrWorld::kind_geometry);
        ClassDB::bind_method(D_METHOD("set_handling", "kind", "values"),
                             &VrWorld::set_handling);
        ClassDB::bind_method(D_METHOD("handling", "kind"), &VrWorld::handling);
        ClassDB::bind_method(D_METHOD("set_render_time", "seconds_since_tick"),
                             &VrWorld::set_render_time);
        ClassDB::bind_method(D_METHOD("set_interpolation", "buffered_frames", "automatic"),
                             &VrWorld::set_interpolation);
        ClassDB::bind_method(D_METHOD("set_predict_all", "predict_all"),
                             &VrWorld::set_predict_all);
        ClassDB::bind_method(D_METHOD("net_status"), &VrWorld::net_status);
        ClassDB::bind_method(D_METHOD("timing"), &VrWorld::timing);
        ClassDB::bind_method(D_METHOD("resim_stats"), &VrWorld::resim_stats);
    }

private:
    struct SeatRef {
        ashiato::Entity vehicle{};
        std::uint8_t seat = 0;
    };

    struct Outbound {
        int64_t peer = 0;
        PackedByteArray bytes;
        int64_t bit_size = 0;
    };

    struct Hands {
        b3BodyId left{};
        b3BodyId right{};
        bool alive = false;
    };

    /// -1 for "nobody", at every GDScript boundary. Inside, "nobody" is kNoOccupant
    /// (255) because that is what a sync ClientId reserves; letting 255 out would make
    /// `holder < 0` quietly false for every free prop in the world.
    static int64_t hold_client(const vr::HoldState* hold) {
        if (hold == nullptr || hold->holder == vr::kNoOccupant) {
            return -1;
        }
        return static_cast<int64_t>(hold->holder);
    }

    static int64_t hold_hand(const vr::HoldState* hold) {
        if (hold == nullptr || hold->hand == vr::kHandNone) {
            return -1;
        }
        return static_cast<int64_t>(hold->hand);
    }

    /// Called by Box3D from inside the step, possibly on a worker thread. It reads
    /// only body user data, which nothing writes while a step is running.
    static bool filter_contact(b3ShapeId a, b3ShapeId b, void*) {
        const auto* left = static_cast<const BodyTag*>(b3Body_GetUserData(b3Shape_GetBody(a)));
        const auto* right = static_cast<const BodyTag*>(b3Body_GetUserData(b3Shape_GetBody(b)));
        if (left == nullptr || right == nullptr) {
            return true;
        }
        return !held_prop_vs_person(*left, *right) && !held_prop_vs_person(*right, *left)
            && !own_hand_vs_own_body(*left, *right) && !own_hand_vs_own_body(*right, *left);
    }

    /// A stable place to keep a body's tag. unordered_map is node-based, so the address
    /// of a mapped value survives every insert -- which matters, because Box3D holds the
    /// pointer for the life of the body.
    BodyTag* tag_for(std::uint64_t key) {
        return &tags_[key];
    }

    static std::uint64_t hand_key(ashiato::Entity entity, std::uint8_t hand) {
        // Two more keyspaces above the entity ids, so a hand's tag cannot collide with
        // its owner's.
        return entity.value | (static_cast<std::uint64_t>(hand + 1) << 62U);
    }

    static std::size_t kind_index(int64_t kind) {
        // Clamped rather than trusted. BodyKind is five bits, so a packet can carry a
        // number this build does not define, and a renderer or a handling table indexed
        // with the raw value would read off the end of itself.
        if (kind < 0) {
            return 0;
        }
        return static_cast<std::size_t>(kind) < kKindCount ? static_cast<std::size_t>(kind)
                                                           : 0;
    }

    static void read_pose(const Dictionary& source, const char* key, float& x, float& y,
                          float& z, w::Quat& rot) {
        if (source.has(key)) {
            const Vector3 position = source[key];
            x = position.x;
            y = position.y;
            z = position.z;
        }
        const String rot_key = String(key) + "_basis";
        if (source.has(rot_key)) {
            const Quaternion q = source[rot_key];
            rot = w::normalized(w::Quat{static_cast<float>(q.x), static_cast<float>(q.y),
                                        static_cast<float>(q.z), static_cast<float>(q.w)});
        }
    }

    static void put_local(Dictionary& out, const char* key, float x, float y, float z,
                          const w::Quat& rot, const b3Pos& origin, const b3Quat& basis) {
        const b3Vec3 offset = rotate(basis, b3Vec3{x, y, z});
        const w::Quat world = w::multiply(from_b3(basis), w::normalized(rot));
        out[String(key)] =
            Vector3(origin.x + offset.x, origin.y + offset.y, origin.z + offset.z);
        out[String(key) + "_basis"] = Quaternion(world.x, world.y, world.z, world.w);
        out[String(key) + "_local"] = Vector3(x, y, z);
        out[String(key) + "_local_basis"] =
            Quaternion(rot.x, rot.y, rot.z, rot.w);
    }

    void queue_outbound(int64_t peer, const ashiato::BitBuffer& packet) {
        Outbound entry;
        entry.peer = peer;
        const std::vector<std::uint8_t>& raw = packet.bytes();
        // byte_size(), not raw.size(): the vector may carry slack past the packet.
        const std::size_t size = packet.byte_size();
        entry.bytes.resize(static_cast<int64_t>(size));
        if (size > 0) {
            std::memcpy(entry.bytes.ptrw(), raw.data(), size);
        }
        entry.bit_size = static_cast<int64_t>(packet.bit_size());
        window_sent_ += size;
        outbound_.push_back(std::move(entry));
    }

    /// Tell sync which avatar is ours, in ITS vocabulary.
    ///
    /// sync routes the local player's input with `view<const NetworkOwner>()` and never
    /// writes NetworkOwner on a client -- the whole client tree only READS it. So a
    /// replicated avatar arrives carrying our AvatarOwner but no NetworkOwner, sync finds
    /// no locally owned entity, and set_input() applies to nothing at all: the predicted
    /// avatar never sees the hands. Reconciled every tick rather than at spawn, because
    /// the entity and the assigned client id arrive at different times.
    void adopt_local_avatars() {
        if (client_ == nullptr) {
            return;
        }
        const auto local = client_->client_id();
        if (local == ashiato::sync::invalid_client_id) {
            return;
        }
        registry_.view<const vr::AvatarOwner>().each(
            [&](ashiato::Entity entity, const vr::AvatarOwner& owner) {
                if (owner.client != static_cast<std::uint32_t>(local)) {
                    return;
                }
                const auto* existing = registry_.try_get<ashiato::sync::NetworkOwner>(entity);
                if (existing != nullptr && existing->client == local) {
                    return;
                }
                ashiato::sync::set_owner(registry_, entity, local);
            });
    }

    /// client id -> where they are sitting, rebuilt once a tick.
    ///
    /// The seat map is authoritative ON THE VEHICLE (see VehicleSeats), which makes a
    /// double occupancy unrepresentable but means "where is this player sitting" is a
    /// scan. Doing it once a tick rather than per query is the whole cost.
    void rebuild_maps() {
        avatar_of_.clear();
        registry_.view<const vr::AvatarOwner>().each(
            [&](ashiato::Entity entity, const vr::AvatarOwner& owner) {
                avatar_of_[static_cast<std::uint8_t>(owner.client)] = entity;
            });
        seat_of_.clear();
        registry_.view<const vr::VehicleSeats>().each(
            [&](ashiato::Entity entity, const vr::VehicleSeats& seats) {
                for (std::size_t i = 0; i < vr::kMaxSeats; ++i) {
                    if (seats.occupant[i] == vr::kNoOccupant) {
                        continue;
                    }
                    SeatRef ref;
                    ref.vehicle = entity;
                    ref.seat = static_cast<std::uint8_t>(i);
                    seat_of_[seats.occupant[i]] = ref;
                }
            });
    }

    /// Nearest-avatar lookup, from the map rebuilt at the top of each simulated frame.
    ///
    /// A scan of every avatar, per vehicle, per tick was the obvious version and it is
    /// quadratic in a game whose whole point is that people share vehicles.
    ashiato::Entity avatar_of_client(std::uint8_t client) const {
        const auto found = avatar_of_.find(client);
        return found == avatar_of_.end() ? ashiato::Entity{} : found->second;
    }

    void vacate_all_seats_of(ashiato::Entity vehicle) {
        auto* seats = registry_.try_get<vr::VehicleSeats>(vehicle);
        if (seats == nullptr) {
            return;
        }
        vr::VehicleSeats& writable = registry_.write<vr::VehicleSeats>(vehicle);
        for (std::size_t i = 0; i < vr::kMaxSeats; ++i) {
            writable.occupant[i] = vr::kNoOccupant;
        }
    }

    void release_props_held_by_entity(ashiato::Entity avatar) {
        const auto* owner = registry_.try_get<vr::AvatarOwner>(avatar);
        if (owner == nullptr) {
            return;
        }
        const auto client = static_cast<std::uint8_t>(owner->client);
        // Collected first, written after: writing a component while iterating the view
        // that produced it is a mutation during traversal, and the registry is entitled
        // to move things underneath it.
        std::vector<ashiato::Entity> dropped;
        registry_.view<const vr::HoldState>().each(
            [&](ashiato::Entity entity, const vr::HoldState& hold) {
                if (hold.holder == client) {
                    dropped.push_back(entity);
                }
            });
        for (const ashiato::Entity entity : dropped) {
            vr::HoldState& writable = registry_.write<vr::HoldState>(entity);
            writable.holder = vr::kNoOccupant;
            writable.hand = vr::kHandNone;
            writable.grab_rot = w::identity();
            writable.grab_x = writable.grab_y = writable.grab_z = 0.0f;
        }
    }

    // ---- Box3D bodies, which are local objects and never replicated ----------------

    b3BodyId ensure_body(ashiato::Entity entity) {
        const auto found = bodies_.find(entity.value);
        if (found != bodies_.end()) {
            return found->second;
        }

        b3BodyDef def = b3DefaultBodyDef();
        def.type = b3_dynamicBody;
        // Sleeping is disabled on every body this world owns. A sleeping body stops
        // integrating, and a replay would then diverge from the original run -- which is
        // the one thing rollback cannot tolerate.
        def.enableSleep = false;

        const auto* avatar = registry_.try_get<vr::AvatarState>(entity);
        if (avatar != nullptr) {
            def.position = b3Pos{avatar->x, avatar->y, avatar->z};
            def.rotation = yaw_quat(avatar->yaw);
            const b3BodyId body = b3CreateBody(physics_, &def);
            // A capsule standing on the floor: 1.7 m tall with a 0.22 m radius.
            b3Capsule capsule;
            capsule.center1 = b3Vec3{0.0f, 0.30f, 0.0f};
            capsule.center2 = b3Vec3{0.0f, 1.45f, 0.0f};
            capsule.radius = 0.22f;
            b3ShapeDef shape = b3DefaultShapeDef();
            shape.density = 70.0f / (3.14159274f * 0.22f * 0.22f * 1.6f);
            // Almost frictionless on purpose. Locomotion is driven by a force toward a
            // target velocity, so ground friction here would fight it -- and the same
            // double-counting that made a car's belly resist its own tires.
            shape.baseMaterial.friction = 0.05f;
            // Visible to sensors. The flag applies to the visitor as much as to the
            // sensor and is off by default on both, so a hand sensing nothing at all is
            // the expected behaviour until every shape it should find opts in.
            shape.enableSensorEvents = true;
            // Asked for on BOTH sides of the hand-versus-own-body pair, not just on the
            // hand. Box3D documents the callback as running "only for awake dynamic
            // bodies", and a hand is kinematic -- so with the flag on the hand alone the
            // pair was never offered to the filter and the suppression did nothing.
            shape.enableCustomFiltering = true;
            b3CreateCapsuleShape(body, &shape, &capsule);
            // Upright, always. A person does not topple, and an avatar that could would
            // put the player's camera on the floor.
            b3MotionLocks locks{};
            locks.angularX = true;
            locks.angularZ = true;
            b3Body_SetMotionLocks(body, locks);
            b3Body_SetLinearDamping(body, 0.2f);
            // Swept collision. A player who steps out of an aircraft at altitude is
            // doing 40 m/s by the time they reach the ground, which is 0.7 m per step --
            // most of the way through a one-metre floor. Measured: an avatar that left a
            // climbing aeroplane ended up 300 m BELOW the world, and the client and the
            // server disagreed about it every frame after that (643 rollbacks in 1500
            // ticks, against 1 when nothing tunnels).
            b3Body_SetBullet(body, true);
            BodyTag* tag = tag_for(entity.value);
            tag->role = kRoleAvatar;
            tag->entity = entity.value;
            tag->owner = owner_client_of(entity);
            b3Body_SetUserData(body, tag);
            bodies_[entity.value] = body;
            ensure_hands(entity);
            return body;
        }

        const auto* state = registry_.try_get<vr::BodyState>(entity);
        const std::size_t index = kind_index(body_kind(static_cast<int64_t>(entity.value)));
        const Shape& shape_def = shapes_[index];
        if (state != nullptr) {
            def.position = b3Pos{state->x, state->y, state->z};
            def.rotation = to_b3(w::normalized(state->rot));
        }
        const b3BodyId body = b3CreateBody(physics_, &def);
        b3ShapeDef shape = b3DefaultShapeDef();
        // Findable by a hand. See the avatar capsule above.
        shape.enableSensorEvents = true;
        if (shape_def.vehicle) {
            // Near zero, exactly as the driving module sets its car shapes to zero: this
            // game models a vehicle's grip itself, and a hull dragging on its belly
            // models it a second time, under the middle of the vehicle where it can only
            // resist yaw. What keeps a parked vehicle parked is the hold in drive_vehicle,
            // not this.
            shape.baseMaterial.friction = 0.02f;
        } else {
            // Only one of a pair needs to ask for custom filtering, and a prop is the
            // only thing here that ever wants a contact suppressed.
            shape.enableCustomFiltering = true;
        }
        if (shape_def.sphere) {
            b3Sphere sphere;
            sphere.center = b3Vec3{0.0f, 0.0f, 0.0f};
            sphere.radius = shape_def.hx;
            shape.density = shape_def.mass
                / (4.18879032f * shape_def.hx * shape_def.hx * shape_def.hx);
            b3CreateSphereShape(body, &shape, &sphere);
        } else {
            b3BoxHull hull = b3MakeBoxHull(shape_def.hx, shape_def.hy, shape_def.hz);
            shape.density = shape_def.mass
                / (8.0f * shape_def.hx * shape_def.hy * shape_def.hz);
            b3CreateHullShape(body, &shape, &hull.base);
        }
        b3Body_SetAngularDamping(body, handling_[index].angular_damping);
        // Props too: a thrown crate is exactly the small fast object swept collision
        // exists for, and a crate that leaves the world never comes back.
        b3Body_SetBullet(body, !shape_def.vehicle);
        BodyTag* tag = tag_for(entity.value);
        tag->role = shape_def.vehicle ? kRoleVehicle : kRoleProp;
        tag->entity = entity.value;
        tag->owner = vr::kNoOccupant;
        b3Body_SetUserData(body, tag);
        bodies_[entity.value] = body;
        return body;
    }

    /// Two spheres per avatar, driven to the tracked hand poses.
    ///
    /// They are real bodies rather than markers because "touch and push each other" and
    /// "knock that crate off the table" are the same request: a hand has to be able to
    /// exert a force. They are NOT replicated -- they are derived every tick from
    /// AvatarState and AvatarInput, both of which a rollback restores, so the hands are
    /// restored with them and there is nothing extra for the wire to carry.
    void ensure_hands(ashiato::Entity entity) {
        if (hands_.find(entity.value) != hands_.end()) {
            return;
        }
        Hands pair;
        for (int i = 0; i < 2; ++i) {
            b3BodyDef def = b3DefaultBodyDef();
            // Kinematic: a hand is moved by a person, and no amount of world contact
            // should push it somewhere the person's real hand is not. The push therefore
            // travels one way, out of the hand into whatever it touches.
            def.type = b3_kinematicBody;
            def.enableSleep = false;
            const b3BodyId body = b3CreateBody(physics_, &def);
            b3Sphere sphere;
            sphere.center = b3Vec3{0.0f, 0.0f, 0.0f};
            sphere.radius = 0.07f;
            b3ShapeDef shape = b3DefaultShapeDef();
            shape.density = 1.0f;
            // A SENSOR. A hand reports what it is inside and pushes none of it.
            //
            // The hands were solid kinematic spheres, which meant they won every contact
            // absolutely: nothing could push them off the player's real hand, so
            // everything they touched got pushed instead. Suppressing that against the
            // player's own capsule fixed standing up but not sitting down -- seated, the
            // hands are inside the VEHICLE's hull, and waving them around shoved the
            // aircraft you were flying. Chasing that one pair at a time is a losing game:
            // a hand is inside something almost all the time, because a person's hands
            // live in the same volume as the rest of them.
            //
            // So a hand exerts no force on anything, ever. Pushing another player is the
            // capsule's job and still works. Nothing is lost from grabbing or carrying
            // either: both are distance queries and velocity targets, not contacts.
            shape.isSensor = true;
            shape.enableSensorEvents = true;
            shape.enableCustomFiltering = true;
            b3CreateSphereShape(body, &shape, &sphere);
            BodyTag* tag = tag_for(hand_key(entity, static_cast<std::uint8_t>(i)));
            tag->role = kRoleHand;
            tag->entity = entity.value;
            tag->hand = static_cast<std::uint8_t>(i);
            tag->owner = owner_client_of(entity);
            b3Body_SetUserData(body, tag);
            if (i == 0) {
                pair.left = body;
            } else {
                pair.right = body;
            }
        }
        pair.alive = true;
        hands_[entity.value] = pair;
    }

    std::uint8_t owner_client_of(ashiato::Entity entity) const {
        const auto* owner = registry_.try_get<vr::AvatarOwner>(entity);
        return owner == nullptr ? vr::kNoOccupant : static_cast<std::uint8_t>(owner->client);
    }

    void release_bodies(ashiato::Entity entity) {
        const auto found = bodies_.find(entity.value);
        if (found != bodies_.end()) {
            b3DestroyBody(found->second);
            bodies_.erase(found);
        }
        const auto hands = hands_.find(entity.value);
        if (hands != hands_.end()) {
            if (hands->second.alive) {
                b3DestroyBody(hands->second.left);
                b3DestroyBody(hands->second.right);
            }
            hands_.erase(hands);
        }
        // Erased after the bodies that pointed at them, never before: Box3D holds these
        // addresses until the body is destroyed.
        tags_.erase(entity.value);
        tags_.erase(hand_key(entity, 0));
        tags_.erase(hand_key(entity, 1));
        last_holder_.erase(entity.value);
        release_grace_.erase(entity.value);
        overlaps_.erase(hand_key(entity, 0));
        overlaps_.erase(hand_key(entity, 1));
    }

    // ---- the simulation ------------------------------------------------------------

    /// Two ordered passes over the same entities, and the physics stepped ONCE.
    ///
    /// The obvious shape -- one job that, per entity, pushes state in, applies forces,
    /// steps and reads back -- advances the whole Box3D world once PER ENTITY: N times
    /// the work, and whichever entity the job reaches first is simulated against
    /// neighbours still sitting at last tick's positions. The driving module measured a
    /// symmetric head-on collision settling three metres off centre that way.
    ///
    /// Both halves must be SIMULATION jobs, because rollback replays them and the physics
    /// has to advance exactly once per replayed frame too.
    void register_simulation_jobs() {
        auto push_avatar = [this](ashiato::Entity entity, vr::AvatarState& state,
                                  const vr::AvatarInput& input) {
            begin_frame();
            drive_avatar(entity, state, input);
        };
        auto read_avatar = [this](ashiato::Entity entity, vr::AvatarState& state,
                                  const vr::AvatarInput& input) {
            step_once();
            read_avatar_from_physics(entity, state, input);
        };
        auto push_body = [this](ashiato::Entity entity, vr::BodyState& state) {
            begin_frame();
            drive_body(entity, state);
        };
        auto read_body = [this](ashiato::Entity entity, vr::BodyState& state) {
            step_once();
            read_body_from_physics(entity, state);
        };

        if (client_) {
            client_->simulation_job<vr::AvatarState, const vr::AvatarInput>(registry_, -2)
                .single_thread().each(push_avatar);
            client_->simulation_job<vr::BodyState>(registry_, -1)
                .single_thread().each(push_body);
            client_->simulation_job<vr::BodyState>(registry_, 0)
                .single_thread().each(read_body);
            client_->simulation_job<vr::AvatarState, const vr::AvatarInput>(registry_, 1)
                .single_thread().each(read_avatar);
        } else {
            // The server runs the identical bodies as plain jobs: it is authoritative and
            // never resimulates, but the two MUST compute the same thing or the client is
            // corrected every frame.
            registry_.job<vr::AvatarState, const vr::AvatarInput>(-2)
                .single_thread().each(push_avatar);
            registry_.job<vr::BodyState>(-1).single_thread().each(push_body);
            registry_.job<vr::BodyState>(0).single_thread().each(read_body);
            registry_.job<vr::AvatarState, const vr::AvatarInput>(1)
                .single_thread().each(read_avatar);
        }
    }

    /// Opened by whichever push job runs first in a simulated frame, closed by the step.
    ///
    /// The derived maps have to be rebuilt PER SIMULATED FRAME, not per tick, and that
    /// distinction is entirely about rollback. A replay runs the jobs again for each of
    /// the frames it is redoing, without going back through tick() -- so maps built in
    /// tick() would be the ones from the live frame, and an avatar whose seat changed
    /// inside the rollback window would be simulated against the wrong vehicle for every
    /// replayed frame. Which is precisely the window in which a seat change is being
    /// corrected, so it is the case that matters.
    void begin_frame() {
        if (frame_open_) {
            return;
        }
        frame_open_ = true;
        stepped_this_tick_ = false;
        rebuild_maps();
    }

    void step_once() {
        if (!stepped_this_tick_) {
            b3World_Step(physics_, fixed_dt_, kSubSteps);
            collect_hand_overlaps();
            stepped_this_tick_ = true;
            // The frame is finished; the next push job opens a new one.
            frame_open_ = false;
        }
    }

    /// What each hand is currently inside, from the sensor events the step produced.
    ///
    /// Read by the game and NEVER by the simulation. It has to stay that way: these are
    /// begin/end deltas, and a rollback replays a frame several times and produces
    /// several of each, so the set is right for asking "what is my hand in right now" and
    /// wrong as an input to anything that has to replay identically. Grabbing therefore
    /// stays a distance query.
    void collect_hand_overlaps() {
        const b3SensorEvents events = b3World_GetSensorEvents(physics_);
        for (int i = 0; i < events.beginCount; ++i) {
            const auto* sensor = tag_of_shape(events.beginEvents[i].sensorShapeId);
            const auto* visitor = tag_of_shape(events.beginEvents[i].visitorShapeId);
            if (sensor == nullptr || visitor == nullptr || sensor->role != kRoleHand) {
                continue;
            }
            // Your own body is not something your hand has found.
            if (visitor->entity == sensor->entity) {
                continue;
            }
            overlaps_[hand_key(ashiato::Entity{sensor->entity}, sensor->hand)]
                .insert(visitor->entity);
        }
        for (int i = 0; i < events.endCount; ++i) {
            const auto* sensor = tag_of_shape(events.endEvents[i].sensorShapeId);
            const auto* visitor = tag_of_shape(events.endEvents[i].visitorShapeId);
            if (sensor == nullptr || visitor == nullptr || sensor->role != kRoleHand) {
                continue;
            }
            const auto found =
                overlaps_.find(hand_key(ashiato::Entity{sensor->entity}, sensor->hand));
            if (found != overlaps_.end()) {
                found->second.erase(visitor->entity);
            }
        }
    }

    static const BodyTag* tag_of_shape(b3ShapeId shape) {
        return static_cast<const BodyTag*>(b3Body_GetUserData(b3Shape_GetBody(shape)));
    }

    /// Put the avatar where the ECS says it is, then apply this tick's intent.
    ///
    /// On a replay the state is the rewound value, which is how the physics gets rewound
    /// along with it: restoring the component restores the body.
    void drive_avatar(ashiato::Entity entity, vr::AvatarState& state,
                      const vr::AvatarInput& input) {
        // Buttons are edge-detected HERE, against the state carried on the entity,
        // rather than on the client. An input frame is replayed during rollback, so a
        // "just pressed" computed where the key was pressed would fire again on every
        // replay of the frame that pressed it -- which for a seat toggle means climbing
        // in and back out several times from one press.
        const std::uint8_t was = last_buttons_[entity.value];
        const std::uint8_t pressed = static_cast<std::uint8_t>(input.buttons & ~was);
        const std::uint8_t released = static_cast<std::uint8_t>(was & ~input.buttons);
        last_buttons_[entity.value] = input.buttons;

        // Tracking data is copied straight through: it is not simulated, it is observed.
        state.head_x = input.head_x;
        state.head_y = input.head_y;
        state.head_z = input.head_z;
        state.head_rot = input.head_rot;
        state.left_x = input.left_x;
        state.left_y = input.left_y;
        state.left_z = input.left_z;
        state.left_rot = input.left_rot;
        state.right_x = input.right_x;
        state.right_y = input.right_y;
        state.right_z = input.right_z;
        state.right_rot = input.right_rot;
        state.grip_left = input.grip_left;
        state.grip_right = input.grip_right;
        state.gesture_left = input.gesture_left;
        state.gesture_right = input.gesture_right;

        const auto* owner = registry_.try_get<vr::AvatarOwner>(entity);
        // Same reason as the prop tag above: a client creates the capsule before the
        // AvatarOwner component has necessarily arrived.
        {
            const std::uint8_t who = owner_client_of(entity);
            tag_for(entity.value)->owner = who;
            tag_for(hand_key(entity, 0))->owner = who;
            tag_for(hand_key(entity, 1))->owner = who;
        }
        const auto client = owner == nullptr ? vr::kNoOccupant
                                             : static_cast<std::uint8_t>(owner->client);

        // Seats and grabs are decided by the SERVER only. They are structural changes --
        // who owns what, who is bolted to which vehicle -- and a client that made them
        // locally would be predicting a decision rather than a trajectory. Both are
        // replicated with should_roll_back true on any change, so the client learns about
        // them on the frame they arrive.
        if (is_server_ && client != vr::kNoOccupant) {
            // Grabs BEFORE the seat toggle, and both against the seat the player is in
            // as this frame begins. Doing them the other way round means a player who
            // presses both in one frame reaches for a crate from a cockpit they have
            // only just climbed into, which is a different place entirely.
            const auto before = seat_of_.find(client);
            update_grabs(state, before == seat_of_.end() ? SeatRef{} : before->second,
                         pressed, released, client);
            if ((pressed & kButtonSeat) != 0) {
                toggle_seat(entity, state, client);
            }
        }

        const auto seated = client == vr::kNoOccupant
            ? seat_of_.end()
            : seat_of_.find(client);
        if (seated != seat_of_.end()) {
            // Bolted in. The capsule is taken out of the world entirely rather than
            // being dragged along behind the vehicle: a body being teleported into a
            // moving cockpit every tick generates contacts with the vehicle it is riding
            // in, and those contacts are forces the vehicle then has to fight.
            state.seated = 1;
            state.seat = seated->second.seat;
            state.vx = state.vy = state.vz = 0.0f;
            // In-seat shuffle stays where it was; nothing here moves it. The pose the
            // renderer draws comes from the vehicle and the seat.
            park_capsule(entity);
            place_hands(entity, state, seated->second);
            return;
        }

        state.seated = 0;
        state.seat = vr::kNoSeat;
        const b3BodyId body = ensure_body(entity);
        b3Body_SetTransform(body, b3Pos{state.x, state.y, state.z}, yaw_quat(state.yaw));
        b3Body_SetLinearVelocity(body, b3Vec3{state.vx, state.vy, state.vz});
        b3Body_SetAngularVelocity(body, b3Vec3{0.0f, 0.0f, 0.0f});

        // Turn. Yaw only, applied to the state rather than to the body, because the body
        // has its angular axes locked and a person's facing is not something physics
        // should be arguing with.
        constexpr float kTurnRate = 2.2f;
        state.yaw -= input.stick_right_x * kTurnRate * fixed_dt_;

        // Walk. A FORCE toward the desired velocity rather than the velocity itself, and
        // that is what makes "push each other" work: setting the velocity every tick
        // would cancel any shove the moment it landed, so two players leaning on one
        // another would pass through each other's contact as if it were not there.
        const b3Quat facing = yaw_quat(state.yaw);
        const b3Vec3 forward = rotate(facing, b3Vec3{0.0f, 0.0f, -1.0f});
        const b3Vec3 right = rotate(facing, b3Vec3{1.0f, 0.0f, 0.0f});
        constexpr float kWalkSpeed = 2.4f;
        constexpr float kWalkForce = 900.0f;
        const b3Vec3 wanted = added(scaled(forward, input.stick_left_y * kWalkSpeed),
                                    scaled(right, input.stick_left_x * kWalkSpeed));
        const b3Vec3 have = b3Body_GetLinearVelocity(body);
        const b3Vec3 error{wanted.x - have.x, 0.0f, wanted.z - have.z};
        b3Body_ApplyForceToCenter(body, clamp_length(scaled(error, 400.0f), kWalkForce), true);

        place_hands(entity, state, SeatRef{});
    }

    /// Put the capsule somewhere it cannot interfere while its owner is seated.
    void park_capsule(ashiato::Entity entity) {
        const auto found = bodies_.find(entity.value);
        if (found == bodies_.end()) {
            return;
        }
        // Far below the world and stationary. Destroying and recreating the body on
        // every seat change would be tidier and is worse: body creation order affects
        // Box3D's internal ordering, and a rollback that recreated bodies in a different
        // order would not replay the same simulation.
        b3Body_SetTransform(found->second, b3Pos{0.0f, -5000.0f, 0.0f},
                            b3Quat{b3Vec3{0.0f, 0.0f, 0.0f}, 1.0f});
        b3Body_SetLinearVelocity(found->second, b3Vec3{0.0f, 0.0f, 0.0f});
        b3Body_SetAngularVelocity(found->second, b3Vec3{0.0f, 0.0f, 0.0f});
    }

    /// Where an avatar's origin is in the world this tick, seated or not.
    void avatar_frame(const vr::AvatarState& state, const SeatRef& seat, b3Pos& origin,
                      b3Quat& basis) {
        if (state.seated == 0 || !seat.vehicle) {
            origin = b3Pos{state.x, state.y, state.z};
            basis = yaw_quat(state.yaw);
            return;
        }
        const auto* vehicle = registry_.try_get<vr::BodyState>(seat.vehicle);
        if (vehicle == nullptr) {
            origin = b3Pos{state.x, state.y, state.z};
            basis = yaw_quat(state.yaw);
            return;
        }
        const Seat& seat_def =
            shapes_[kind_index(body_kind(static_cast<int64_t>(seat.vehicle.value)))]
                .seat[seat.seat];
        const b3Quat vehicle_rot = to_b3(w::normalized(vehicle->rot));
        const b3Vec3 offset = rotate(vehicle_rot, b3Vec3{seat_def.x, seat_def.y, seat_def.z});
        const b3Quat seat_rot =
            to_b3(w::multiply(from_b3(vehicle_rot), from_b3(yaw_quat(seat_def.yaw))));
        const b3Vec3 shuffle = rotate(seat_rot, b3Vec3{state.x, state.y, state.z});
        origin = b3Pos{vehicle->x + offset.x + shuffle.x, vehicle->y + offset.y + shuffle.y,
                       vehicle->z + offset.z + shuffle.z};
        basis = to_b3(w::multiply(from_b3(seat_rot), from_b3(yaw_quat(state.yaw))));
    }

    /// Where one hand is in the world this frame, without touching any physics body.
    ///
    /// The authority on a hand's pose is AvatarState plus the frame it is measured in --
    /// the physics body is a copy made later for the benefit of contact. Anything that
    /// asks a gameplay question about a hand should ask this, not the copy.
    b3WorldTransform hand_world(const vr::AvatarState& state, const SeatRef& seat,
                                std::uint8_t hand) {
        b3Pos origin{};
        b3Quat basis{};
        avatar_frame(state, seat, origin, basis);
        const bool left = hand == vr::kHandLeft;
        const b3Vec3 local = left ? b3Vec3{state.left_x, state.left_y, state.left_z}
                                  : b3Vec3{state.right_x, state.right_y, state.right_z};
        const w::Quat local_rot = left ? state.left_rot : state.right_rot;
        const b3Vec3 offset = rotate(basis, local);
        b3WorldTransform out;
        out.p = b3Pos{origin.x + offset.x, origin.y + offset.y, origin.z + offset.z};
        out.q = to_b3(w::multiply(from_b3(basis), w::normalized(local_rot)));
        return out;
    }

    void place_hands(ashiato::Entity entity, const vr::AvatarState& state,
                     const SeatRef& seat) {
        const auto found = hands_.find(entity.value);
        if (found == hands_.end() || !found->second.alive) {
            return;
        }
        b3Pos origin{};
        b3Quat basis{};
        avatar_frame(state, seat, origin, basis);

        const b3Vec3 left_offset = rotate(basis, b3Vec3{state.left_x, state.left_y, state.left_z});
        const b3Vec3 right_offset =
            rotate(basis, b3Vec3{state.right_x, state.right_y, state.right_z});
        set_hand(found->second.left,
                 b3Pos{origin.x + left_offset.x, origin.y + left_offset.y,
                       origin.z + left_offset.z},
                 to_b3(w::multiply(from_b3(basis), w::normalized(state.left_rot))));
        set_hand(found->second.right,
                 b3Pos{origin.x + right_offset.x, origin.y + right_offset.y,
                       origin.z + right_offset.z},
                 to_b3(w::multiply(from_b3(basis), w::normalized(state.right_rot))));
    }

    /// Move a kinematic hand, giving it the velocity that motion implies.
    ///
    /// The velocity is what makes contact work: a kinematic body teleported into a crate
    /// pushes it out with no momentum at all, so a swung hand would nudge things rather
    /// than bat them. Derived from the body's own previous pose, which a replay
    /// reproduces because the pose that set it was itself derived from restored state.
    void set_hand(b3BodyId body, const b3Pos& position, const b3Quat& rotation) {
        const b3WorldTransform current = b3Body_GetTransform(body);
        const b3Vec3 velocity{(position.x - current.p.x) / fixed_dt_,
                              (position.y - current.p.y) / fixed_dt_,
                              (position.z - current.p.z) / fixed_dt_};
        // A hand that has moved further than this in one tick has been teleported --
        // the player respawned, or got into a vehicle -- and reporting 300 m/s of
        // velocity would fire whatever it touched into orbit.
        constexpr float kMaxHandSpeed = 12.0f;
        b3Body_SetLinearVelocity(body, clamp_length(velocity, kMaxHandSpeed));
        b3Body_SetAngularVelocity(body, angular_to(current.q, rotation, fixed_dt_));
        b3Body_SetTransform(body, position, rotation);
    }

    void read_avatar_from_physics(ashiato::Entity entity, vr::AvatarState& state,
                                  const vr::AvatarInput&) {
        if (state.seated != 0) {
            return;
        }
        const auto found = bodies_.find(entity.value);
        if (found == bodies_.end()) {
            return;
        }
        const b3WorldTransform xform = b3Body_GetTransform(found->second);
        const b3Vec3 linear = b3Body_GetLinearVelocity(found->second);
        state.x = xform.p.x;
        state.y = xform.p.y;
        state.z = xform.p.z;
        state.vx = linear.x;
        state.vy = linear.y;
        state.vz = linear.z;
        // Yaw is NOT read back. The capsule's angular axes are locked and its facing is
        // whatever the last push set; reading it back would let solver noise walk the
        // player's heading around, and heading is the one thing they are steering.
    }

    /// A vehicle or a prop: put it where the ECS says it is, then apply this tick's forces.
    void drive_body(ashiato::Entity entity, vr::BodyState& state) {
        const b3BodyId body = ensure_body(entity);
        b3Body_SetTransform(body, b3Pos{state.x, state.y, state.z},
                            to_b3(w::normalized(state.rot)));
        b3Body_SetLinearVelocity(body, b3Vec3{state.vx, state.vy, state.vz});
        b3Body_SetAngularVelocity(body, b3Vec3{state.wx, state.wy, state.wz});

        const auto* hold = registry_.try_get<vr::HoldState>(entity);
        // Refreshed every frame rather than written when somebody grabs: on a client the
        // holder arrives by replication, and during a rollback it is restored to whatever
        // it was on the frame being replayed. A tag written once at grab time would be
        // the live value during a replay of a frame where it was different.
        if (BodyTag* tag = tag_for(entity.value); tag->role == kRoleProp) {
            update_hold_tag(entity, tag, hold);
        }
        if (hold != nullptr && hold->holder != vr::kNoOccupant) {
            drive_held_prop(body, *hold);
            return;
        }
        // Weight back on. Done HERE, from replicated state, rather than in try_release --
        // which only ever runs on the server, so a client's predicted prop had its
        // gravity turned off when it was picked up and nothing ever turned it back on.
        // It floated where it was dropped until a correction happened to arrive.
        b3Body_SetGravityScale(body, 1.0f);
        const auto* seats = registry_.try_get<vr::VehicleSeats>(entity);
        if (seats != nullptr) {
            drive_vehicle(entity, body, *seats);
        }
    }

    /// Who a prop should still be ignoring, which is not always who is holding it.
    ///
    /// Driven off the replicated holder CHANGING rather than off the grab and release
    /// calls, because those only run on the server: a client learns that somebody let go
    /// by receiving it, and needs the same grace period or its predicted copy is the one
    /// that gets fired across the room.
    void update_hold_tag(ashiato::Entity entity, BodyTag* tag, const vr::HoldState* hold) {
        const std::uint8_t now = hold == nullptr ? vr::kNoOccupant : hold->holder;
        std::uint8_t& previous = last_holder_[entity.value];
        if (now != vr::kNoOccupant) {
            tag->owner = now;
            release_grace_.erase(entity.value);
        } else if (previous != vr::kNoOccupant) {
            // The frame it was let go of. Keep ignoring that person for a moment.
            tag->owner = previous;
            release_grace_[entity.value] = kReleaseGraceTicks;
        } else {
            const auto grace = release_grace_.find(entity.value);
            if (grace != release_grace_.end() && grace->second > 0) {
                --grace->second;
            } else {
                tag->owner = vr::kNoOccupant;
                release_grace_.erase(entity.value);
            }
        }
        previous = now;
    }

    /// A prop follows the hand holding it, as a velocity rather than a teleport.
    ///
    /// Velocity, so it still collides: a held crate pushed into a wall stops at the wall
    /// and the hand slides out of it, which is what every VR game that feels good does.
    /// Teleporting it to the hand would put it through the wall and let the player carry
    /// it into geometry they cannot reach.
    void drive_held_prop(b3BodyId body, const vr::HoldState& hold) {
        const ashiato::Entity holder = avatar_of_client(hold.holder);
        if (!holder) {
            return;
        }
        const auto hands = hands_.find(holder.value);
        if (hands == hands_.end() || !hands->second.alive) {
            return;
        }
        const b3BodyId hand =
            hold.hand == vr::kHandLeft ? hands->second.left : hands->second.right;
        const b3WorldTransform palm = b3Body_GetTransform(hand);
        // The grip, applied. The object is carried where it was picked up, not at its
        // own centre -- so the hand stays on the surface it grabbed and letting go does
        // not hand the solver an overlap to fire the object out of.
        const w::Quat palm_rot = w::normalized(from_b3(palm.q));
        const b3Vec3 offset =
            rotate(palm.q, b3Vec3{hold.grab_x, hold.grab_y, hold.grab_z});
        b3WorldTransform target;
        target.p = b3Pos{palm.p.x + offset.x, palm.p.y + offset.y, palm.p.z + offset.z};
        target.q = to_b3(w::multiply(palm_rot, w::normalized(hold.grab_rot)));
        const b3WorldTransform current = b3Body_GetTransform(body);
        const b3Vec3 to_target{(target.p.x - current.p.x) / fixed_dt_,
                               (target.p.y - current.p.y) / fixed_dt_,
                               (target.p.z - current.p.z) / fixed_dt_};
        constexpr float kCarrySpeed = 14.0f;
        constexpr float kCarrySpin = 20.0f;
        b3Body_SetLinearVelocity(body, clamp_length(to_target, kCarrySpeed));
        b3Body_SetAngularVelocity(
            body, clamp_length(angular_to(current.q, target.q, fixed_dt_), kCarrySpin));
        // Gravity off while held, or the prop sags below the hand by however far it falls
        // in the fraction of a tick the velocity does not cover.
        b3Body_SetGravityScale(body, 0.0f);
    }

    void drive_vehicle(ashiato::Entity entity, b3BodyId body, const vr::VehicleSeats& seats) {
        const std::size_t index = kind_index(body_kind(static_cast<int64_t>(entity.value)));
        const Handling& h = handling_[index];

        // Only seat 0 has controls. A passenger's sticks do nothing, which is why only
        // the pilot's client predicts the vehicle.
        vr::AvatarInput controls{};
        bool piloted = false;
        if (seats.occupant[0] != vr::kNoOccupant) {
            const ashiato::Entity pilot = avatar_of_client(seats.occupant[0]);
            if (pilot) {
                const auto* input = registry_.try_get<vr::AvatarInput>(pilot);
                if (input != nullptr) {
                    controls = *input;
                    piloted = true;
                }
            }
        }

        const b3WorldTransform xform = b3Body_GetTransform(body);
        const b3Vec3 forward = rotate(xform.q, b3Vec3{0.0f, 0.0f, -1.0f});
        const b3Vec3 up = rotate(xform.q, b3Vec3{0.0f, 1.0f, 0.0f});
        const b3Vec3 right = rotate(xform.q, b3Vec3{1.0f, 0.0f, 0.0f});
        const b3Vec3 velocity = b3Body_GetLinearVelocity(body);
        const float speed = length(velocity);
        const float along = dot3(velocity, forward);

        // Aerodynamic / hydrodynamic drag, along the body's own axes rather than as one
        // isotropic term: a wing is cheap to push forwards and expensive to push
        // sideways, and a hull more so. One coefficient for all three directions is what
        // makes a simple flight model feel like a brick.
        const b3Vec3 body_drag{-dot3(velocity, right) * std::fabs(dot3(velocity, right))
                                   * h.drag * 3.0f,
                               -dot3(velocity, up) * std::fabs(dot3(velocity, up)) * h.drag
                                   * 4.0f,
                               -along * std::fabs(along) * h.drag};
        b3Body_ApplyForceToCenter(
            body,
            added(added(scaled(right, body_drag.x), scaled(up, body_drag.y)),
                  scaled(forward, body_drag.z)),
            true);

        // Rolling resistance, and only while something is under the wheels. Capped at
        // what it would take to STOP the vehicle this step, because a constant force that
        // does not know how slow the thing already is will reverse it -- the same
        // overshoot the driving module's tires needed a settling clamp for.
        const float mass = b3Body_GetMass(body);
        const bool grounded = on_ground(body, index);
        if (h.rolling_resistance > 0.0f && speed > 0.0001f && grounded) {
            const float stop = std::fabs(along) * mass / fixed_dt_;
            const float resist = std::fmin(h.rolling_resistance, stop);
            b3Body_ApplyForceToCenter(
                body, scaled(forward, -(along > 0.0f ? 1.0f : -1.0f) * resist), true);
        }

        // The parking brake, and it is not decoration.
        //
        // Vehicle shapes are almost frictionless on purpose (the game models grip
        // itself), which leaves a parked vehicle on ice: a player walking into a 750 kg
        // aeroplane pushed it several metres and then chased it across the field, never
        // getting near enough to the seat to climb in. Cancelling the residual horizontal
        // velocity below walking pace, whenever nobody is asking for power, is what a
        // handbrake and a wheel chock do between them -- and it means a person can rock a
        // parked vehicle but not walk off with it.
        const float demand = piloted
            ? std::fmax(controls.trigger_left, controls.trigger_right)
            : 0.0f;
        if (grounded && demand < 0.05f && speed < 0.9f) {
            const b3Vec3 drift = b3Body_GetLinearVelocity(body);
            b3Body_ApplyForceToCenter(
                body,
                b3Vec3{-drift.x * mass / fixed_dt_, 0.0f, -drift.z * mass / fixed_dt_},
                true);
        }

        switch (index) {
            case kKindCar:
                drive_car(body, h, controls, piloted, xform, forward, right, velocity, along);
                break;
            case kKindPlane:
                drive_plane(body, h, controls, piloted, forward, up, right, velocity, speed);
                break;
            case kKindBoat:
                drive_boat(body, h, controls, piloted, xform, forward, right, velocity, along);
                break;
            default:
                break;
        }
    }

    /// A car, simplified: drive along the nose, hold the line sideways, steer by yaw rate.
    ///
    /// Deliberately NOT the four-tire model the driving module uses. That model earns its
    /// complexity in a game about driving; here a car is one of several things to climb
    /// into, and what it has to be is predictable and stable under rollback. The
    /// arrangement below keeps the two properties that actually matter -- a friction
    /// budget shared between turning and driving, and a steering lock that tapers with
    /// speed -- and leaves the rest.
    /// Is this vehicle resting on something?
    ///
    /// Approximated by asking whether its underside is close to the ground plane, rather
    /// than by querying contacts. That is a real simplification and it is stated here
    /// rather than hidden: it is right for a playground with a flat floor and wrong the
    /// moment there is terrain, at which point this wants to become a contact query.
    bool on_ground(b3BodyId body, std::size_t index) const {
        const float bottom = b3Body_GetTransform(body).p.y - shapes_[index].hy;
        return bottom < 0.12f;
    }

    void drive_car(b3BodyId body, const Handling& h, const vr::AvatarInput& in, bool piloted,
                   const b3WorldTransform& xform, const b3Vec3& forward, const b3Vec3& right,
                   const b3Vec3& velocity, float along) {
        const float throttle = piloted ? (in.trigger_right - in.trigger_left) : 0.0f;
        const float steer = piloted ? in.stick_left_x : 0.0f;

        b3Body_ApplyForceToCenter(body, scaled(forward, throttle * h.thrust), true);
        // Brake when the throttle opposes travel, rather than driving backwards through
        // the same force: a car that reverses out of a braking input at 20 m/s is not
        // one anybody can park.
        if (throttle * along < 0.0f && std::fabs(along) > 0.5f) {
            b3Body_ApplyForceToCenter(
                body, scaled(forward, -(along > 0.0f ? 1.0f : -1.0f) * h.brake
                                          * std::fabs(throttle)),
                true);
        }

        // Lateral hold. Capped, so a hard enough corner slides instead of gripping for
        // ever -- the friction budget, expressed as one number.
        const float sideways = dot3(velocity, right);
        const float hold = std::fmin(std::fabs(sideways) * 2200.0f, h.grip);
        b3Body_ApplyForceToCenter(body, scaled(right, -(sideways > 0.0f ? 1.0f : -1.0f) * hold),
                                  true);

        // Steering as a target yaw rate, tapered with speed. A real rack does the same
        // thing with a slower ratio; without it a car at walking pace spins on the spot.
        const float taper = h.steer_reference
            / (h.steer_reference + std::fabs(along) * 0.6f);
        const float wanted_yaw = steer * -h.steer_rate * taper
            * std::fmin(1.0f, std::fabs(along) / 1.5f)
            * (along < 0.0f ? -1.0f : 1.0f);
        const b3Vec3 spin = b3Body_GetAngularVelocity(body);
        b3Body_ApplyTorque(body, b3Vec3{0.0f, (wanted_yaw - spin.y) * 9000.0f, 0.0f}, true);
        (void)xform;
    }

    /// An aircraft: thrust, lift with a stall, a fin that resists sideslip, and three
    /// control torques.
    ///
    /// Simple on purpose and structurally right, so a better model replaces terms rather
    /// than the whole thing. The pieces that earn their place are the ones a naive
    /// version leaves out: lift proportional to airspeed SQUARED (so slow flight is
    /// mushy and fast flight is not), a stall past which more elevator gives less lift
    /// rather than more, and a weathervane term -- without which an aeroplane flies
    /// sideways as happily as forwards and nothing about it reads as flight.
    void drive_plane(b3BodyId body, const Handling& h, const vr::AvatarInput& in, bool piloted,
                     const b3Vec3& forward, const b3Vec3& up, const b3Vec3& right,
                     const b3Vec3& velocity, float speed) {
        const float throttle = piloted ? in.trigger_right : 0.0f;
        b3Body_ApplyForceToCenter(body, scaled(forward, throttle * h.thrust), true);

        if (speed > 1.0f) {
            // Angle of attack: how far the airflow is below the nose.
            const float along = dot3(velocity, forward);
            const float vertical = dot3(velocity, up);
            const float aoa = std::atan2(-vertical, std::fmax(along, 0.1f));
            // Linear to the stall, then falling away. Past the stall a wing does not
            // simply stop lifting -- it lifts less the harder you pull, which is the
            // whole character of the thing and the reason it is worth modelling at all.
            float coefficient = aoa;
            if (std::fabs(aoa) > h.stall_angle) {
                const float over = std::fabs(aoa) - h.stall_angle;
                coefficient = (aoa > 0.0f ? 1.0f : -1.0f)
                    * std::fmax(h.stall_angle * 0.25f,
                                h.stall_angle - over * 1.4f);
            }
            const float airspeed = std::fmax(along, 0.0f);
            b3Body_ApplyForceToCenter(
                body, scaled(up, coefficient * airspeed * airspeed * h.lift * 0.01f), true);

            // The fin. Yaw torque proportional to sideslip, which is what points the
            // nose into the airflow.
            const float slip = dot3(velocity, right);
            b3Body_ApplyTorque(body, scaled(up, -slip * speed * h.weathervane * 0.01f), true);
        }

        if (!piloted) {
            return;
        }
        // Left stick is the control column: y pitches, x rolls. Right stick x is rudder.
        // The same two sticks that walk and turn on foot, which is deliberate -- the
        // hardware has two sticks, and what they mean is the seat's business.
        //
        // Each axis asks for a RATE and a proportional term supplies the torque, so the
        // aircraft settles at the commanded rate instead of accelerating for as long as
        // the stick is held. Control authority also falls away with airspeed, because
        // control surfaces are wings: an aeroplane hanging on its propeller has almost
        // none, which is what makes a stall recoverable rather than a spin.
        const float bite = std::fmin(1.0f, std::fmax(0.15f, speed / 22.0f));
        const b3Vec3 spin = b3Body_GetAngularVelocity(body);
        command_rate(body, right, in.stick_left_y * h.pitch_rate,
                     h.control_authority * bite, spin);
        command_rate(body, forward, -in.stick_left_x * h.roll_rate,
                     h.control_authority * bite, spin);
        command_rate(body, up, -in.stick_right_x * h.rudder_rate,
                     h.control_authority * bite, spin);
    }

    /// Torque about one body axis, proportional to how far the current rate is from the
    /// commanded one.
    static void command_rate(b3BodyId body, const b3Vec3& axis, float wanted, float gain,
                             const b3Vec3& spin) {
        const float current = dot3(spin, axis);
        b3Body_ApplyTorque(body, scaled(axis, (wanted - current) * gain), true);
    }

    /// A boat: floats, drives along the nose, and refuses to move sideways.
    void drive_boat(b3BodyId body, const Handling& h, const vr::AvatarInput& in, bool piloted,
                    const b3WorldTransform& xform, const b3Vec3& forward, const b3Vec3& right,
                    const b3Vec3& velocity, float along) {
        // Buoyancy proportional to draught, which is what makes a hull bob and settle
        // rather than sit at a fixed height: push it down and it pushes back harder.
        const float draught = h.water_level - xform.p.y;
        if (draught > 0.0f) {
            const float lift = std::fmin(draught, 1.0f) * h.buoyancy;
            b3Body_ApplyForceToCenter(body, b3Vec3{0.0f, lift, 0.0f}, true);
            // Vertical damping, or the hull oscillates on its own spring for ever.
            b3Body_ApplyForceToCenter(
                body, b3Vec3{0.0f, -b3Body_GetLinearVelocity(body).y * 4000.0f, 0.0f}, true);
            // Sideways resistance. A hull has a keel; this is it.
            const float sideways = dot3(velocity, right);
            b3Body_ApplyForceToCenter(body, scaled(right, -sideways * h.water_drag), true);
        }

        if (!piloted || draught <= 0.0f) {
            return;
        }
        const float throttle = in.trigger_right - in.trigger_left;
        b3Body_ApplyForceToCenter(body, scaled(forward, throttle * h.thrust), true);
        // Rudder authority scales with speed, because a rudder is a wing in water and a
        // stationary boat does not turn by moving its tiller.
        const float authority = std::fmin(1.0f, std::fabs(along) / 4.0f);
        b3Body_ApplyTorque(
            body, b3Vec3{0.0f, -in.stick_left_x * h.steer_rate * 26000.0f * authority, 0.0f},
            true);
    }

    void read_body_from_physics(ashiato::Entity entity, vr::BodyState& state) {
        const auto found = bodies_.find(entity.value);
        if (found == bodies_.end()) {
            return;
        }
        const b3WorldTransform xform = b3Body_GetTransform(found->second);
        const b3Vec3 linear = b3Body_GetLinearVelocity(found->second);
        const b3Vec3 angular = b3Body_GetAngularVelocity(found->second);
        state.x = xform.p.x;
        state.y = xform.p.y;
        state.z = xform.p.z;
        state.rot = w::normalized(from_b3(xform.q));
        state.vx = linear.x;
        state.vy = linear.y;
        state.vz = linear.z;
        state.wx = angular.x;
        state.wy = angular.y;
        state.wz = angular.z;
    }

    // ---- interaction, server side only ---------------------------------------------

    /// Sit down in the nearest free seat, or get out of the one we are in.
    void toggle_seat(ashiato::Entity avatar, vr::AvatarState& state, std::uint8_t client) {
        ++seat_changes_;
        const auto seated = seat_of_.find(client);
        if (seated != seat_of_.end()) {
            vr::VehicleSeats& seats = registry_.write<vr::VehicleSeats>(seated->second.vehicle);
            seats.occupant[seated->second.seat] = vr::kNoOccupant;
            // Put them beside the vehicle, on the world's terms again. Computed from the
            // seat they were in, so getting out of the far side of a car does not drop
            // the player through the near door.
            b3Pos origin{};
            b3Quat basis{};
            avatar_frame(state, seated->second, origin, basis);
            const b3Vec3 out = rotate(basis, b3Vec3{1.4f, 0.0f, 0.0f});
            state.seated = 0;
            state.seat = vr::kNoSeat;
            state.x = origin.x + out.x;
            state.y = origin.y;
            state.z = origin.z + out.z;
            state.vx = state.vy = state.vz = 0.0f;
            seat_of_.erase(seated);
            const auto found = bodies_.find(avatar.value);
            if (found != bodies_.end()) {
                b3Body_SetTransform(found->second, b3Pos{state.x, state.y, state.z},
                                    yaw_quat(state.yaw));
                b3Body_SetLinearVelocity(found->second, b3Vec3{0.0f, 0.0f, 0.0f});
            }
            return;
        }

        // Nearest free seat within reach of where the player is standing.
        float best = kSeatReach * kSeatReach;
        ashiato::Entity best_vehicle{};
        std::uint8_t best_seat = 0;
        registry_.view<const vr::VehicleSeats, const vr::BodyState>().each(
            [&](ashiato::Entity vehicle, const vr::VehicleSeats& seats,
                const vr::BodyState& body) {
                const Shape& shape =
                    shapes_[kind_index(body_kind(static_cast<int64_t>(vehicle.value)))];
                const b3Quat rot = to_b3(w::normalized(body.rot));
                for (int i = 0; i < shape.seats; ++i) {
                    if (seats.occupant[i] != vr::kNoOccupant) {
                        continue;
                    }
                    const b3Vec3 offset =
                        rotate(rot, b3Vec3{shape.seat[i].x, shape.seat[i].y, shape.seat[i].z});
                    const float dx = body.x + offset.x - state.x;
                    const float dy = body.y + offset.y - (state.y + 0.9f);
                    const float dz = body.z + offset.z - state.z;
                    const float distance = dx * dx + dy * dy + dz * dz;
                    if (distance < best) {
                        best = distance;
                        best_vehicle = vehicle;
                        best_seat = static_cast<std::uint8_t>(i);
                    }
                }
            });
        if (!best_vehicle) {
            return;
        }
        vr::VehicleSeats& seats = registry_.write<vr::VehicleSeats>(best_vehicle);
        seats.occupant[best_seat] = client;
        state.seated = 1;
        state.seat = best_seat;
        // The in-seat offset starts at nothing: the player is exactly in the seat, and
        // the pose fields switch meaning to seat-local on the same frame the flag does.
        state.x = state.y = state.z = 0.0f;
        state.yaw = 0.0f;
        state.vx = state.vy = state.vz = 0.0f;
        SeatRef ref;
        ref.vehicle = best_vehicle;
        ref.seat = best_seat;
        seat_of_[client] = ref;
        park_capsule(avatar);
    }

    /// Pick things up, hand them over, and let them go.
    ///
    /// Taking a prop somebody else is holding is ALLOWED, and that is the handoff: it is
    /// one write on the server, not a protocol between two clients. It only succeeds if
    /// the taker's hand is within grab reach of the prop, which in practice means the two
    /// hands are next to each other -- which is what a handoff looks like anyway.
    void update_grabs(const vr::AvatarState& state, const SeatRef& seat,
                      std::uint8_t pressed, std::uint8_t released, std::uint8_t client) {
        for (int hand = 0; hand < 2; ++hand) {
            const std::uint8_t bit = hand == 0 ? kButtonGrabLeft : kButtonGrabRight;
            const auto hand_id = static_cast<std::uint8_t>(hand);
            if ((pressed & bit) != 0) {
                try_grab(client, hand_id, hand_world(state, seat, hand_id));
            } else if ((released & bit) != 0) {
                try_release(client, hand_id);
            }
        }
    }

    void try_grab(std::uint8_t client, std::uint8_t hand, const b3WorldTransform& palm) {
        const b3Pos at = palm.p;

        // Ranked by how far the hand is from each prop's surface, so a big crate and a
        // small ball are equally grabbable and the nearest thing wins rather than the
        // smallest.
        float best = kGrabReach;
        ashiato::Entity best_prop{};
        registry_.view<const vr::HoldState, const vr::BodyState>().each(
            [&](ashiato::Entity prop, const vr::HoldState& hold, const vr::BodyState& body) {
                // Already in this very hand: nothing to do, and re-grabbing would reset
                // the carry velocity for a frame.
                if (hold.holder == client && hold.hand == hand) {
                    return;
                }
                const Shape& shape =
                    shapes_[kind_index(body_kind(static_cast<int64_t>(prop.value)))];
                const float radius =
                    std::fmax(shape.hx, std::fmax(shape.hy, shape.hz));
                const float dx = body.x - at.x;
                const float dy = body.y - at.y;
                const float dz = body.z - at.z;
                const float surface =
                    std::sqrt(dx * dx + dy * dy + dz * dz) - radius;
                if (surface < best) {
                    best = surface;
                    best_prop = prop;
                }
            });
        if (!best_prop) {
            return;
        }
        // Captured HERE, once, and then replicated: where the object was relative to
        // the palm at the instant the hand closed. Everything about how it is carried
        // afterwards follows from this, which is why it is a component and not a local.
        const auto* body = registry_.try_get<vr::BodyState>(best_prop);
        vr::HoldState& hold = registry_.write<vr::HoldState>(best_prop);
        hold.holder = client;
        hold.hand = hand;
        if (body != nullptr) {
            const w::Quat palm_rot = w::normalized(from_b3(palm.q));
            const w::Quat inverse_palm = w::conjugate(palm_rot);
            const b3Vec3 delta{body->x - palm.p.x, body->y - palm.p.y, body->z - palm.p.z};
            const b3Vec3 local = rotate(to_b3(inverse_palm), delta);
            // Clamped to what the wire can carry. A grab that somehow started further
            // out than this would otherwise be quantised into a different grip on every
            // other machine.
            hold.grab_x = std::fmax(-0.8f, std::fmin(0.8f, local.x));
            hold.grab_y = std::fmax(-0.8f, std::fmin(0.8f, local.y));
            hold.grab_z = std::fmax(-0.8f, std::fmin(0.8f, local.z));
            hold.grab_rot = w::multiply(inverse_palm, w::normalized(body->rot));
        }
        ++grab_changes_;
    }

    void try_release(std::uint8_t client, std::uint8_t hand) {
        std::vector<ashiato::Entity> dropped;
        registry_.view<const vr::HoldState>().each(
            [&](ashiato::Entity prop, const vr::HoldState& hold) {
                if (hold.holder == client && hold.hand == hand) {
                    dropped.push_back(prop);
                }
            });
        for (const ashiato::Entity prop : dropped) {
            vr::HoldState& writable = registry_.write<vr::HoldState>(prop);
            writable.holder = vr::kNoOccupant;
            writable.hand = vr::kHandNone;
            writable.grab_rot = w::identity();
            writable.grab_x = writable.grab_y = writable.grab_z = 0.0f;
            // Nothing else to do. Whatever velocity the carry left it with IS the
            // throw -- the prop has been tracking the hand for as long as it was held, so
            // it is already travelling at hand speed, and an impulse on top double-counts
            // it and sends it twice as far as it looked like it should. Gravity comes
            // back in drive_body, from the replicated state, so a client does it too.
        }
    }

    // ---- state ----

    ashiato::Registry registry_;
    std::unique_ptr<ashiato::sync::ReplicationServer> server_;
    std::unique_ptr<ashiato::sync::ReplicationClient> client_;

    b3WorldId physics_{};
    bool physics_alive_ = false;
    bool stepped_this_tick_ = false;
    bool frame_open_ = false;

    ashiato::Entity avatar_state_{};
    ashiato::Entity avatar_input_{};
    ashiato::Entity avatar_owner_{};
    ashiato::Entity body_state_{};
    ashiato::Entity body_kind_{};
    ashiato::Entity seats_component_{};
    ashiato::Entity hold_component_{};

    ashiato::sync::SyncArchetypeId archetype_avatar_{};
    ashiato::sync::SyncArchetypeId archetype_vehicle_{};
    ashiato::sync::SyncArchetypeId archetype_prop_{};

    bool started_ = false;
    bool is_server_ = false;
    bool sampling_marked_ = false;
    bool predict_all_ = false;
    bool auto_buffer_ = true;
    ashiato::sync::SyncFrame buffered_frames_ = 3;

    int64_t seat_changes_ = 0;
    int64_t grab_changes_ = 0;
    int64_t resim_count_ = 0;
    int64_t last_resim_frame_ = 0;
    int64_t last_resim_span_ = 0;

    vr::AvatarInput pending_input_{};
    float fixed_dt_ = 1.0f / kDefaultTickHz;
    std::size_t window_sent_ = 0;
    std::size_t window_received_ = 0;
    double window_seconds_ = 0.0;
    double sent_per_second_ = 0.0;
    double received_per_second_ = 0.0;
    bool render_paced_ = false;
    double render_alpha_ = 0.0;
    ashiato::sync::FractionalTickSampleBuffer render_frame_;

    // Local, derived, never replicated. Every machine that simulates an entity computes
    // these from the same replicated state, so putting them on the wire would be sending
    // an answer both sides already have.
    std::unordered_map<std::uint64_t, b3BodyId> bodies_;
    std::unordered_map<std::uint64_t, Hands> hands_;
    /// Body user data, addressed by Box3D for the life of each body.
    std::unordered_map<std::uint64_t, BodyTag> tags_;
    /// Who was holding each prop last frame, and how much longer a just-released one goes
    /// on ignoring them.
    std::unordered_map<std::uint64_t, std::uint8_t> last_holder_;
    std::unordered_map<std::uint64_t, int> release_grace_;
    /// hand key -> the entities that hand is inside. Presentation state, never simulation.
    std::unordered_map<std::uint64_t, std::unordered_set<std::uint64_t>> overlaps_;
    std::unordered_map<std::uint64_t, std::uint8_t> last_buttons_;
    std::unordered_map<std::uint8_t, SeatRef> seat_of_;
    std::unordered_map<std::uint8_t, ashiato::Entity> avatar_of_;

    std::vector<ashiato::Entity> pending_destroy_;
    std::vector<Outbound> outbound_;

    std::array<Handling, kKindCount> handling_{};
    std::array<Shape, kKindCount> shapes_{};
};

void register_vr_classes() {
    GDREGISTER_CLASS(VrWorld);
}

}  // namespace ashiato_gd
