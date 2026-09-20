#pragma once
// The networked vocabulary for a VR playground, and the wire format for it.
//
// Same contract as src/driving/car_components.hpp: ashiato-sync wants an explicit
// SyncComponentTraits<T> per replicated component and never picks a wire format
// implicitly, so the replicated set is a small fixed vocabulary defined here.
//
// What makes this different from the driving vocabulary is that a VR player is not a
// simulation result. A car's pose is produced by stepping physics, so it is state and
// nothing else. A head and two hands are produced by a tracking system attached to a
// human being, so they are INPUT -- nobody, including the machine holding the headset,
// can predict where a head is about to be. That single fact decides the shape of
// everything below:
//
//   - the tracked poses travel client -> server as AvatarInput, on sync's own input
//     path, so they are frame-stamped, buffered and replayed during rollback;
//   - the server writes them into AvatarState, which is what everybody else sees;
//   - the owner's own avatar is predicted, which costs nothing, because predicting
//     input you already have is just applying it.
//
// The second decision is the seat, and it is the RigState lesson from the driving module
// applied to people: a seated player's world pose is NEVER replicated. It is derived from
// the vehicle's pose and the seat index. Two independently interpolated poses for a
// rigidly coupled pair have nothing forcing them to coincide, and in a car that shows up
// as a trailer parting from its cab. In VR it shows up as your own head leaving the
// cockpit and snapping back, which is not a cosmetic problem -- it is the difference
// between a flight sim and a reason to take the headset off.

#include <cmath>
#include <cstdint>

#include "ashiato/sync/sync.hpp"

namespace ashiato_gd::vr {

// ---- shared wire helpers ---------------------------------------------------------
//
// Free functions rather than members of one trait, because trait specialisations are
// separate types and none of them can see another's statics -- the driving module ended
// up with two copies of shortest_angle for exactly that reason.

namespace wire {

using ashiato::sync::serialization::QuantizedFloatConfig;
using ashiato::sync::serialization::read_quantized_float;
using ashiato::sync::serialization::serialize_quantized_float;

// A 1 km playground at 1 cm, and a much shorter vertical range: something 200 m up has
// left the playground.
inline constexpr QuantizedFloatConfig ground{-500.0f, 500.0f, 0.01f};
inline constexpr QuantizedFloatConfig height{-20.0f, 200.0f, 0.01f};
inline constexpr QuantizedFloatConfig angle{-3.14159274f, 3.14159274f, 0.001f};
inline constexpr QuantizedFloatConfig speed{-150.0f, 150.0f, 0.01f};
inline constexpr QuantizedFloatConfig spin{-30.0f, 30.0f, 0.005f};

// Body-local offsets: a head or a hand relative to the player's own origin. Arm's reach
// is about 1 m, so 2 m of range is generous, and 2 mm is under what anyone can hold a
// controller still to.
inline constexpr QuantizedFloatConfig reach{-2.0f, 2.0f, 0.002f};
// Walking pace and a bit. A player moving faster than this is being carried by
// something, and the thing carrying them is what supplies the motion.
inline constexpr QuantizedFloatConfig gait{-12.0f, 12.0f, 0.01f};
// A seated player can shuffle a little inside the seat; they cannot walk away from it.
inline constexpr QuantizedFloatConfig in_seat{-1.0f, 1.0f, 0.002f};
// Where a held object sits relative to the hand holding it. Bigger than anything a person
// can pick up one-handed, at 2 mm.
inline constexpr QuantizedFloatConfig grip_offset{-0.8f, 0.8f, 0.002f};
// Analog trigger / grip. 1/64 is finer than the hardware reports on most controllers.
inline constexpr QuantizedFloatConfig squeeze{0.0f, 1.0f, 1.0f / 64.0f};
// A stick axis. 1/128 is far finer than anyone can hold a thumbstick.
inline constexpr QuantizedFloatConfig axis{-1.0f, 1.0f, 1.0f / 128.0f};

// Smallest-three quaternion. The largest component is dropped and rebuilt from unit
// norm, which is what makes this 32 bits rather than four floats.
//
// The remaining three are each in [-1/sqrt(2), 1/sqrt(2)] -- that is forced, because the
// component that was dropped was the largest -- so the range is not a guess and clamping
// can never silently lose a rotation the way a naive per-component quantiser would.
inline constexpr QuantizedFloatConfig quat_part{-0.70710678f, 0.70710678f, 0.0014f};

struct Quat {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    float w = 1.0f;
};

inline Quat normalized(Quat q) {
    const float len = std::sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w);
    // A zero quaternion is not a rotation, and decoding one produces NaN that then
    // spreads through every pose derived from it. Identity is the only safe answer.
    if (!(len > 1e-6f)) {
        return Quat{0.0f, 0.0f, 0.0f, 1.0f};
    }
    return Quat{q.x / len, q.y / len, q.z / len, q.w / len};
}

inline void write_quat(ashiato::BitBuffer& out, const Quat& value) {
    const Quat q = normalized(value);
    const float c[4] = {q.x, q.y, q.z, q.w};
    int largest = 0;
    for (int i = 1; i < 4; ++i) {
        if (std::fabs(c[i]) > std::fabs(c[largest])) {
            largest = i;
        }
    }
    // q and -q are the same rotation, so flipping the whole quaternion to make the
    // dropped component positive costs nothing and removes its sign from the wire --
    // which is what lets the largest be rebuilt as a plain positive square root.
    const float sign = c[largest] < 0.0f ? -1.0f : 1.0f;
    out.write_unsigned_bits(static_cast<std::uint32_t>(largest), 2);
    for (int i = 0; i < 4; ++i) {
        if (i == largest) {
            continue;
        }
        serialize_quantized_float(out, c[i] * sign, quat_part);
    }
}

inline bool read_quat(ashiato::BitBuffer& in, Quat& out) {
    if (in.remaining_bits() < 2) {
        return false;
    }
    const int largest = static_cast<int>(in.read_unsigned_bits(2));
    float c[4] = {0.0f, 0.0f, 0.0f, 0.0f};
    float sum = 0.0f;
    for (int i = 0; i < 4; ++i) {
        if (i == largest) {
            continue;
        }
        if (!read_quantized_float(in, quat_part, c[i])) {
            return false;
        }
        sum += c[i] * c[i];
    }
    // fmax before the root: quantisation can push the sum a hair past 1, and sqrt of a
    // negative is a NaN that would then be normalised into every pose downstream.
    c[largest] = std::sqrt(std::fmax(0.0f, 1.0f - sum));
    out = Quat{c[0], c[1], c[2], c[3]};
    return true;
}

inline float dot(const Quat& a, const Quat& b) {
    return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
}

/// Shortest-arc interpolation. Falls back to a normalised lerp when the two are nearly
/// equal, where the slerp formula divides by a sine approaching zero.
inline Quat slerp(const Quat& from, Quat to, float alpha) {
    float cos_theta = dot(from, to);
    // Through the short way round. Without this a head that crossed the seam between q
    // and -q would spin the long way in one frame.
    if (cos_theta < 0.0f) {
        to = Quat{-to.x, -to.y, -to.z, -to.w};
        cos_theta = -cos_theta;
    }
    if (cos_theta > 0.9995f) {
        return normalized(Quat{from.x + (to.x - from.x) * alpha,
                               from.y + (to.y - from.y) * alpha,
                               from.z + (to.z - from.z) * alpha,
                               from.w + (to.w - from.w) * alpha});
    }
    const float theta = std::acos(std::fmin(1.0f, cos_theta));
    const float sin_theta = std::sin(theta);
    const float a = std::sin((1.0f - alpha) * theta) / sin_theta;
    const float b = std::sin(alpha * theta) / sin_theta;
    return normalized(Quat{from.x * a + to.x * b, from.y * a + to.y * b,
                           from.z * a + to.z * b, from.w * a + to.w * b});
}

inline Quat multiply(const Quat& a, const Quat& b) {
    return Quat{a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
                a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
                a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
                a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z};
}

inline Quat conjugate(const Quat& q) {
    return Quat{-q.x, -q.y, -q.z, q.w};
}

inline Quat identity() {
    return Quat{0.0f, 0.0f, 0.0f, 1.0f};
}

inline float lerp(float a, float b, float t) {
    return a + (b - a) * t;
}

/// Signed difference a-b wrapped into [-pi, pi].
inline float shortest_angle(float a, float b) {
    constexpr float two_pi = 6.28318548f;
    float delta = std::fmod(a - b + 3.14159274f, two_pi);
    if (delta < 0.0f) {
        delta += two_pi;
    }
    return delta - 3.14159274f;
}

}  // namespace wire

// ---- the vocabulary ---------------------------------------------------------------

/// No seat. 3 is the widest a two-bit seat index goes, so it doubles as "not seated"
/// without spending a bit on a flag that the index can already express.
inline constexpr std::uint8_t kNoSeat = 3;
/// Seats per vehicle. Four is what fits in the two bits the wire spends on a seat index,
/// and widening it is a wire-format change rather than a table edit.
inline constexpr std::size_t kMaxSeats = 4;
/// sync's own "no client". Repeated here rather than reached for through sync, because
/// it is a WIRE value in VehicleSeats and has to keep its width whatever sync does.
inline constexpr std::uint8_t kNoOccupant = 255;

/// Which hand, where a component has to say. 0 and 1 are the hands; 2 is neither.
inline constexpr std::uint8_t kHandLeft = 0;
inline constexpr std::uint8_t kHandRight = 1;
inline constexpr std::uint8_t kHandNone = 2;

/// What the person in the headset is doing, this tick.
///
/// The tracked poses are in here rather than in AvatarState-written-by-the-client
/// because a head pose IS input: it originates outside the simulation, only the owning
/// machine knows it, and rollback has to replay it exactly as it replays a thumbstick.
/// Putting it on sync's input path gets all three properties for free -- frame stamping,
/// buffering and replay -- and none of them are things worth hand-rolling.
///
/// Deliberately ABSENT from every archetype. Replicating input back to its owner makes
/// the server echo each client its own input a round trip late, and that echo lands on
/// the predicted avatar and overwrites the live pose it should be predicting with. The
/// driving module established this three separate times; it is not re-litigated here.
struct AvatarInput {
    // Head and hands, in the player's own body frame. Body-local rather than world so
    // that a player seated in a banking aircraft sends the same small numbers they send
    // standing on the floor -- and so the pose stays meaningful when the frame it is
    // measured in is itself being corrected.
    float head_x = 0.0f;
    float head_y = 1.6f;
    float head_z = 0.0f;
    wire::Quat head_rot{};

    float left_x = -0.25f;
    float left_y = 1.2f;
    float left_z = -0.35f;
    wire::Quat left_rot{};

    float right_x = 0.25f;
    float right_y = 1.2f;
    float right_z = -0.35f;
    wire::Quat right_rot{};

    // Two sticks, because a VR controller has two sticks. What they MEAN is decided by
    // where the player is: on foot the left one walks and the right one turns; in a
    // driver's seat the left one is steering and throttle; in a pilot's seat the left is
    // pitch and roll and the right is rudder. Encoding the meaning here instead would
    // put the seat's business on the wire, and the seat can change while an input frame
    // is in flight.
    float stick_left_x = 0.0f;
    float stick_left_y = 0.0f;
    float stick_right_x = 0.0f;
    float stick_right_y = 0.0f;

    // Analog. Used as grab strength on foot and as throttle / brake in a vehicle.
    float trigger_left = 0.0f;
    float trigger_right = 0.0f;
    float grip_left = 0.0f;
    float grip_right = 0.0f;

    // Bit 0 left grab, bit 1 right grab, bit 2 use/interact, bit 3 seat toggle,
    // bit 4 menu. Edge detection is the server's job: an input frame is replayed during
    // rollback, so a "just pressed" computed on the client would fire again on every
    // replay of the frame that pressed it.
    std::uint8_t buttons = 0;

    // What the hands are DOING, as opposed to where they are: 0 none, 1 point,
    // 2 open palm / wave, 3 thumbs up, 4 fist. Per hand, four bits total.
    std::uint8_t gesture_left = 0;
    std::uint8_t gesture_right = 0;

    // Not sent: the frame. sync stamps and buffers input frames itself.
};

/// A player, as everybody else sees them.
///
/// The `seated` flag is on the wire and is not merely a convenience: it selects the
/// QUANTISER for the body pose. A standing player's origin is a point in a 1 km
/// playground; a seated player's is an offset inside a seat, and squeezing the second
/// through the first's 1 cm grid would make a head that is 4 mm off centre indistinguishable
/// from one that is not. Branching on a bit the packet carries also means deserialisation
/// never has to consult another entity -- which matters, because the vehicle carrying the
/// seat may not have arrived yet.
struct AvatarState {
    // World when standing, seat-local when seated. See above.
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    /// Heading of the body chassis. Yaw only, and that is a game rule rather than a
    /// saving: a player on foot stands upright, and their head is free to look anywhere
    /// without the body following. When seated this is yaw WITHIN the seat, and the
    /// seat's own orientation supplies the rest.
    float yaw = 0.0f;

    // Only meaningful standing; a seated player's motion belongs to the vehicle.
    float vx = 0.0f;
    float vy = 0.0f;
    float vz = 0.0f;

    float head_x = 0.0f;
    float head_y = 1.6f;
    float head_z = 0.0f;
    wire::Quat head_rot{};

    float left_x = -0.25f;
    float left_y = 1.2f;
    float left_z = -0.35f;
    wire::Quat left_rot{};

    float right_x = 0.25f;
    float right_y = 1.2f;
    float right_z = -0.35f;
    wire::Quat right_rot{};

    /// How hard each hand is closed. Replicated because an avatar whose fingers do not
    /// respond reads as a mannequin, and it is 12 bits.
    float grip_left = 0.0f;
    float grip_right = 0.0f;

    std::uint8_t gesture_left = 0;
    std::uint8_t gesture_right = 0;

    /// 1 while this player is bolted into a seat. The vehicle and the seat index come
    /// from VehicleSeats on the vehicle itself -- see the note there for why the seat
    /// map lives on the vehicle rather than a vehicle reference living here.
    std::uint8_t seated = 0;
    /// Which seat, when seated. kNoSeat otherwise.
    std::uint8_t seat = kNoSeat;
};

/// Who this avatar belongs to, in OUR vocabulary.
///
/// sync::NetworkOwner records the same fact server-side but has no SyncComponentTraits
/// and therefore no wire format; putting it in an archetype crashes on the first
/// serialize. The client still has to know which avatar is its own in order to predict
/// it, so the fact is replicated as a component we define.
struct AvatarOwner {
    std::uint32_t client = 0;
};

/// A rigid thing in the world: a vehicle, or a prop somebody can pick up.
///
/// One component type for both, deliberately. A crate and an aeroplane have exactly the
/// same replicated pose -- position, orientation, and both velocities -- and what tells
/// them apart is the OTHER components in their archetype: a vehicle carries seats, a prop
/// carries a hold. Splitting the pose into two identical types would double the trait
/// code and give the two different rollback thresholds for no reason anyone could state.
///
/// Full quaternion, unlike the driving module's yaw-only CarState, and this is the
/// difference between a top-down racer and a playground. An aircraft that cannot bank and
/// a boat that cannot pitch over a wave are not the same objects with the roll left out;
/// they are objects the wire format has made impossible.
struct BodyState {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    wire::Quat rot{};
    float vx = 0.0f;
    float vy = 0.0f;
    float vz = 0.0f;
    float wx = 0.0f;
    float wy = 0.0f;
    float wz = 0.0f;
};

/// What this body is, and therefore which shape and which simulation every machine must
/// give it.
///
/// Replicated even though vehicles and props have different archetypes, because the
/// archetype is sync's business and the game layer never sees it. Five bits: the
/// simulation and the renderer both index tables with this, and running out of room in a
/// wire field is a protocol change, so it is worth being generous once.
struct BodyKind {
    std::uint8_t kind = 0;
};

/// Who is sitting in this vehicle, and where.
///
/// THE SEAT MAP LIVES ON THE VEHICLE, not as a vehicle reference on the player, and that
/// is the load-bearing decision in this file.
///
/// The obvious design is a `seat_of` component on the avatar naming a vehicle entity.
/// sync can carry an entity reference, so it would work -- and it would make two players
/// claiming the same seat REPRESENTABLE, which means it will eventually happen and there
/// will be nothing in the data model to say which of them is wrong. One client id per
/// seat cannot express a double occupancy at all: writing a second player into seat 0
/// removes the first, in one field, on the authoritative machine, in one place.
///
/// It also removes the entity reference, which is the part of sync's wire format with the
/// most moving pieces (a network id that has to resolve on a machine where the target
/// may not have arrived yet). A client id is eight bits and is already replicated
/// successfully by AvatarOwner.
///
/// The cost is that finding a player's seat means scanning vehicles rather than reading
/// one field. With a handful of vehicles and eight players that is nothing, and the
/// simulation caches the reverse map once per tick.
struct VehicleSeats {
    std::uint8_t occupant[kMaxSeats] = {kNoOccupant, kNoOccupant, kNoOccupant, kNoOccupant};
};

/// Who is holding this prop, if anyone.
///
/// Same shape and the same reason as VehicleSeats: one holder field on the prop makes
/// "two players holding the same crate" unrepresentable, where a `holding` component on
/// each player would let both believe it. Handing an object over is therefore a single
/// write on the server -- the holder changes -- and not a protocol between two clients.
struct HoldState {
    /// kNoOccupant when free.
    std::uint8_t holder = kNoOccupant;
    /// Which of the holder's hands. kHandNone when free.
    std::uint8_t hand = kHandNone;

    /// Where the object sits relative to the hand that took it, captured at the instant
    /// of the grab and held for as long as the grab lasts.
    ///
    /// Without it every object is carried at its own centre, which puts the hand INSIDE
    /// the object. That is wrong to look at -- you grabbed the corner of a crate and it
    /// snapped so its middle was in your fist -- and it is worse than cosmetic: letting
    /// go of something your hand is inside hands the solver a deep overlap to resolve,
    /// and it resolves it by firing the object away. Measured: a released crate went UP
    /// 3.6 m.
    ///
    /// It has to be REPLICATED rather than recomputed, even though both machines could
    /// in principle work it out. The client learns about a grab a round trip after it
    /// happened, by which time the hand and the object have both moved, so a client
    /// deriving its own offset would derive a different one -- and the object would sit
    /// in a visibly different place in your hand than in everyone else's.
    float grab_x = 0.0f;
    float grab_y = 0.0f;
    float grab_z = 0.0f;
    wire::Quat grab_rot{};
};

}  // namespace ashiato_gd::vr

namespace ashiato::sync {

// A namespace alias, not a member typedef: a namespace alias is illegal inside a class
// body, and every trait below needs the same set of quantiser configs and maths.
namespace w = ashiato_gd::vr::wire;

// ---- AvatarInput -----------------------------------------------------------------
//
// The most expensive input component in either module, and unavoidably so: three tracked
// poses is what a VR player's intent actually consists of. About 250 bits a tick, which
// at a 60 Hz simulation is under 2 KB/s upstream per player.

template <>
struct SyncComponentTraits<ashiato_gd::vr::AvatarInput> {
    using Quantized = ashiato_gd::vr::AvatarInput;

    static void quantize(const ashiato_gd::vr::AvatarInput& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::vr::AvatarInput dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        w::serialize_quantized_float(out, current.head_x, w::reach);
        w::serialize_quantized_float(out, current.head_y, w::reach);
        w::serialize_quantized_float(out, current.head_z, w::reach);
        w::write_quat(out, current.head_rot);
        w::serialize_quantized_float(out, current.left_x, w::reach);
        w::serialize_quantized_float(out, current.left_y, w::reach);
        w::serialize_quantized_float(out, current.left_z, w::reach);
        w::write_quat(out, current.left_rot);
        w::serialize_quantized_float(out, current.right_x, w::reach);
        w::serialize_quantized_float(out, current.right_y, w::reach);
        w::serialize_quantized_float(out, current.right_z, w::reach);
        w::write_quat(out, current.right_rot);
        w::serialize_quantized_float(out, current.stick_left_x, w::axis);
        w::serialize_quantized_float(out, current.stick_left_y, w::axis);
        w::serialize_quantized_float(out, current.stick_right_x, w::axis);
        w::serialize_quantized_float(out, current.stick_right_y, w::axis);
        w::serialize_quantized_float(out, current.trigger_left, w::squeeze);
        w::serialize_quantized_float(out, current.trigger_right, w::squeeze);
        w::serialize_quantized_float(out, current.grip_left, w::squeeze);
        w::serialize_quantized_float(out, current.grip_right, w::squeeze);
        out.write_unsigned_bits(current.buttons & 0x1Fu, 5);
        out.write_unsigned_bits(current.gesture_left & 0x7u, 3);
        out.write_unsigned_bits(current.gesture_right & 0x7u, 3);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (!w::read_quantized_float(in, w::reach, out.head_x)
            || !w::read_quantized_float(in, w::reach, out.head_y)
            || !w::read_quantized_float(in, w::reach, out.head_z)
            || !w::read_quat(in, out.head_rot)
            || !w::read_quantized_float(in, w::reach, out.left_x)
            || !w::read_quantized_float(in, w::reach, out.left_y)
            || !w::read_quantized_float(in, w::reach, out.left_z)
            || !w::read_quat(in, out.left_rot)
            || !w::read_quantized_float(in, w::reach, out.right_x)
            || !w::read_quantized_float(in, w::reach, out.right_y)
            || !w::read_quantized_float(in, w::reach, out.right_z)
            || !w::read_quat(in, out.right_rot)
            || !w::read_quantized_float(in, w::axis, out.stick_left_x)
            || !w::read_quantized_float(in, w::axis, out.stick_left_y)
            || !w::read_quantized_float(in, w::axis, out.stick_right_x)
            || !w::read_quantized_float(in, w::axis, out.stick_right_y)
            || !w::read_quantized_float(in, w::squeeze, out.trigger_left)
            || !w::read_quantized_float(in, w::squeeze, out.trigger_right)
            || !w::read_quantized_float(in, w::squeeze, out.grip_left)
            || !w::read_quantized_float(in, w::squeeze, out.grip_right)) {
            return false;
        }
        if (in.remaining_bits() < 11) {
            return false;
        }
        out.buttons = static_cast<std::uint8_t>(in.read_unsigned_bits(5));
        out.gesture_left = static_cast<std::uint8_t>(in.read_unsigned_bits(3));
        out.gesture_right = static_cast<std::uint8_t>(in.read_unsigned_bits(3));
        return true;
    }

    // Required even though AvatarInput is deliberately never in an archetype: sync wants
    // a full trait set for any registered component, and its absence would crash on the
    // first prediction rather than say anything. Input is authoritative from whoever
    // moved their hand, so a difference is never worth a rollback on its own.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }
};

// ---- AvatarState -----------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::vr::AvatarState> {
    using Quantized = ashiato_gd::vr::AvatarState;

    static void quantize(const ashiato_gd::vr::AvatarState& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::vr::AvatarState dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        const bool seated = current.seated != 0;
        out.write_unsigned_bits(seated ? 1u : 0u, 1);
        out.write_unsigned_bits(current.seat & 0x3u, 2);
        // The branch the `seated` bit exists for. A seated player's origin is an offset
        // inside a seat measured in millimetres; a standing one's is a point in a
        // kilometre of playground. One grid cannot serve both without either wasting
        // most of the range or losing the precision that makes leaning in a cockpit
        // read as leaning rather than as jitter.
        if (seated) {
            w::serialize_quantized_float(out, current.x, w::in_seat);
            w::serialize_quantized_float(out, current.y, w::in_seat);
            w::serialize_quantized_float(out, current.z, w::in_seat);
        } else {
            w::serialize_quantized_float(out, current.x, w::ground);
            w::serialize_quantized_float(out, current.y, w::height);
            w::serialize_quantized_float(out, current.z, w::ground);
        }
        w::serialize_quantized_float(out, current.yaw, w::angle);
        // Velocity is not sent for a seated player: their motion is the vehicle's, and
        // the vehicle already sends it. Sending it twice invites the two to disagree.
        if (!seated) {
            w::serialize_quantized_float(out, current.vx, w::gait);
            w::serialize_quantized_float(out, current.vy, w::gait);
            w::serialize_quantized_float(out, current.vz, w::gait);
        }
        w::serialize_quantized_float(out, current.head_x, w::reach);
        w::serialize_quantized_float(out, current.head_y, w::reach);
        w::serialize_quantized_float(out, current.head_z, w::reach);
        w::write_quat(out, current.head_rot);
        w::serialize_quantized_float(out, current.left_x, w::reach);
        w::serialize_quantized_float(out, current.left_y, w::reach);
        w::serialize_quantized_float(out, current.left_z, w::reach);
        w::write_quat(out, current.left_rot);
        w::serialize_quantized_float(out, current.right_x, w::reach);
        w::serialize_quantized_float(out, current.right_y, w::reach);
        w::serialize_quantized_float(out, current.right_z, w::reach);
        w::write_quat(out, current.right_rot);
        w::serialize_quantized_float(out, current.grip_left, w::squeeze);
        w::serialize_quantized_float(out, current.grip_right, w::squeeze);
        out.write_unsigned_bits(current.gesture_left & 0x7u, 3);
        out.write_unsigned_bits(current.gesture_right & 0x7u, 3);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (in.remaining_bits() < 3) {
            return false;
        }
        const bool seated = in.read_unsigned_bits(1) != 0u;
        out.seated = seated ? 1u : 0u;
        out.seat = static_cast<std::uint8_t>(in.read_unsigned_bits(2));
        if (seated) {
            if (!w::read_quantized_float(in, w::in_seat, out.x)
                || !w::read_quantized_float(in, w::in_seat, out.y)
                || !w::read_quantized_float(in, w::in_seat, out.z)) {
                return false;
            }
        } else if (!w::read_quantized_float(in, w::ground, out.x)
                   || !w::read_quantized_float(in, w::height, out.y)
                   || !w::read_quantized_float(in, w::ground, out.z)) {
            return false;
        }
        if (!w::read_quantized_float(in, w::angle, out.yaw)) {
            return false;
        }
        if (seated) {
            out.vx = 0.0f;
            out.vy = 0.0f;
            out.vz = 0.0f;
        } else if (!w::read_quantized_float(in, w::gait, out.vx)
                   || !w::read_quantized_float(in, w::gait, out.vy)
                   || !w::read_quantized_float(in, w::gait, out.vz)) {
            return false;
        }
        if (!w::read_quantized_float(in, w::reach, out.head_x)
            || !w::read_quantized_float(in, w::reach, out.head_y)
            || !w::read_quantized_float(in, w::reach, out.head_z)
            || !w::read_quat(in, out.head_rot)
            || !w::read_quantized_float(in, w::reach, out.left_x)
            || !w::read_quantized_float(in, w::reach, out.left_y)
            || !w::read_quantized_float(in, w::reach, out.left_z)
            || !w::read_quat(in, out.left_rot)
            || !w::read_quantized_float(in, w::reach, out.right_x)
            || !w::read_quantized_float(in, w::reach, out.right_y)
            || !w::read_quantized_float(in, w::reach, out.right_z)
            || !w::read_quat(in, out.right_rot)
            || !w::read_quantized_float(in, w::squeeze, out.grip_left)
            || !w::read_quantized_float(in, w::squeeze, out.grip_right)) {
            return false;
        }
        if (in.remaining_bits() < 6) {
            return false;
        }
        out.gesture_left = static_cast<std::uint8_t>(in.read_unsigned_bits(3));
        out.gesture_right = static_cast<std::uint8_t>(in.read_unsigned_bits(3));
        return true;
    }

    // Tighter than the driving module's 15 cm, because the thing being corrected is
    // where the player believes their own body is. A car that arrives 15 cm from where
    // it was drawn is a car that shifted slightly; a head that does the same is the
    // world lurching, and the inner ear disagrees with the eyes about which one moved.
    static constexpr float rollback_position = 0.05f;   // metres
    static constexpr float rollback_heading = 0.05f;    // radians, about 3 degrees
    // Longer than the driving module's 0.30 s, and for the same reason the threshold is
    // tighter: in VR the smoothness of a correction matters more than its promptness.
    // A slow blend lies about where the body is for longer, and that is the better lie.
    static constexpr float error_blend_seconds = 0.40f;

    static bool should_roll_back(const Quantized& predicted, const Quantized& authoritative) {
        // Getting into or out of a seat changes the frame the pose is measured in, so
        // the two are not comparable and the numbers below would be meaningless. It is
        // also exactly the moment a client most needs to be corrected.
        if (predicted.seated != authoritative.seated || predicted.seat != authoritative.seat) {
            return true;
        }
        const float dx = predicted.x - authoritative.x;
        const float dy = predicted.y - authoritative.y;
        const float dz = predicted.z - authoritative.z;
        if ((dx * dx + dy * dy + dz * dz) > (rollback_position * rollback_position)) {
            return true;
        }
        return std::fabs(w::shortest_angle(predicted.yaw, authoritative.yaw)) > rollback_heading;
    }

    static Quantized interpolate(const Quantized& from, const Quantized& to, float alpha) {
        Quantized out = to;
        // A player who got into a seat between these two frames has two poses measured
        // in different frames, and blending them would slide the avatar through the
        // cockpit wall. Step to the newer one instead: the transition is one frame.
        if (from.seated != to.seated || from.seat != to.seat) {
            return out;
        }
        out.x = w::lerp(from.x, to.x, alpha);
        out.y = w::lerp(from.y, to.y, alpha);
        out.z = w::lerp(from.z, to.z, alpha);
        out.yaw = from.yaw + w::shortest_angle(to.yaw, from.yaw) * alpha;
        out.vx = w::lerp(from.vx, to.vx, alpha);
        out.vy = w::lerp(from.vy, to.vy, alpha);
        out.vz = w::lerp(from.vz, to.vz, alpha);
        out.head_x = w::lerp(from.head_x, to.head_x, alpha);
        out.head_y = w::lerp(from.head_y, to.head_y, alpha);
        out.head_z = w::lerp(from.head_z, to.head_z, alpha);
        out.head_rot = w::slerp(from.head_rot, to.head_rot, alpha);
        out.left_x = w::lerp(from.left_x, to.left_x, alpha);
        out.left_y = w::lerp(from.left_y, to.left_y, alpha);
        out.left_z = w::lerp(from.left_z, to.left_z, alpha);
        out.left_rot = w::slerp(from.left_rot, to.left_rot, alpha);
        out.right_x = w::lerp(from.right_x, to.right_x, alpha);
        out.right_y = w::lerp(from.right_y, to.right_y, alpha);
        out.right_z = w::lerp(from.right_z, to.right_z, alpha);
        out.right_rot = w::slerp(from.right_rot, to.right_rot, alpha);
        out.grip_left = w::lerp(from.grip_left, to.grip_left, alpha);
        out.grip_right = w::lerp(from.grip_right, to.grip_right, alpha);
        return out;
    }

    // ---- error blending -------------------------------------------------------
    //
    // Required, not optional: set_fractional_tick_sampled() silently refuses a component
    // that cannot compute, apply and blend out an error, and then fractional_tick_frame()
    // comes back empty with nothing anywhere saying why.
    //
    // Only the BODY carries an error. Head and hands are tracking data, and a tracked
    // pose that disagrees with the server is not a prediction that was wrong -- it is a
    // later reading of the same head. Blending it would show the player their own hand
    // lagging their real one, which is the one artefact VR has no tolerance for at all.
    struct Error {
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
        float yaw = 0.0f;
    };

    static Error compute_error(const Quantized& current, const Quantized& previous) {
        Error error;
        // Across a seat change there is no common frame to measure an offset in, so
        // there is no error to blend: the avatar simply is somewhere else now.
        if (current.seated != previous.seated || current.seat != previous.seat) {
            return error;
        }
        error.x = previous.x - current.x;
        error.y = previous.y - current.y;
        error.z = previous.z - current.z;
        error.yaw = w::shortest_angle(previous.yaw, current.yaw);
        return error;
    }

    static Quantized apply_error(const Quantized& current, const Error& error) {
        Quantized out = current;
        out.x += error.x;
        out.y += error.y;
        out.z += error.z;
        out.yaw += error.yaw;
        // Velocity is deliberately not offset: it is the truth the next tick simulates
        // from, and only the visible pose is being smoothed.
        return out;
    }

    static Error blend_out_error(const Error& error, float dt_seconds) {
        const float keep = std::exp(-dt_seconds / error_blend_seconds);
        Error out;
        out.x = error.x * keep;
        out.y = error.y * keep;
        out.z = error.z * keep;
        out.yaw = error.yaw * keep;
        return out;
    }
};

// ---- AvatarOwner -----------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::vr::AvatarOwner> {
    using Quantized = ashiato_gd::vr::AvatarOwner;

    static void quantize(const ashiato_gd::vr::AvatarOwner& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::vr::AvatarOwner dequantize(const Quantized& value) {
        return value;
    }

    // 16 bits, matching the driving module. A lobby will not hold 65k players and
    // ownership never changes often enough for the width to matter.
    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        out.write_unsigned_bits(current.client & 0xFFFFu, 16);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (in.remaining_bits() < 16) {
            return false;
        }
        out.client = static_cast<std::uint32_t>(in.read_unsigned_bits(16));
        return true;
    }

    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }

    // Step, not blend: an avatar does not belong half to one player.
    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

// ---- BodyState -------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::vr::BodyState> {
    using Quantized = ashiato_gd::vr::BodyState;

    static void quantize(const ashiato_gd::vr::BodyState& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::vr::BodyState dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        w::serialize_quantized_float(out, current.x, w::ground);
        w::serialize_quantized_float(out, current.y, w::height);
        w::serialize_quantized_float(out, current.z, w::ground);
        w::write_quat(out, current.rot);
        w::serialize_quantized_float(out, current.vx, w::speed);
        w::serialize_quantized_float(out, current.vy, w::speed);
        w::serialize_quantized_float(out, current.vz, w::speed);
        w::serialize_quantized_float(out, current.wx, w::spin);
        w::serialize_quantized_float(out, current.wy, w::spin);
        w::serialize_quantized_float(out, current.wz, w::spin);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        return w::read_quantized_float(in, w::ground, out.x)
            && w::read_quantized_float(in, w::height, out.y)
            && w::read_quantized_float(in, w::ground, out.z)
            && w::read_quat(in, out.rot)
            && w::read_quantized_float(in, w::speed, out.vx)
            && w::read_quantized_float(in, w::speed, out.vy)
            && w::read_quantized_float(in, w::speed, out.vz)
            && w::read_quantized_float(in, w::spin, out.wx)
            && w::read_quantized_float(in, w::spin, out.wy)
            && w::read_quantized_float(in, w::spin, out.wz);
    }

    // 10 cm and about 4 degrees. Between the driving module's 15 cm / 8 degrees and the
    // avatar's 5 cm / 3 degrees, and the reason is the lever arm again: a vehicle you
    // are SITTING IN puts your head several metres from its centre of mass, so a few
    // degrees of body attitude is a large movement at the eyes -- and a prop you are
    // holding is 60 cm from them.
    static constexpr float rollback_position = 0.10f;
    static constexpr float rollback_angle = 0.07f;
    static constexpr float error_blend_seconds = 0.35f;

    static bool should_roll_back(const Quantized& predicted, const Quantized& authoritative) {
        const float dx = predicted.x - authoritative.x;
        const float dy = predicted.y - authoritative.y;
        const float dz = predicted.z - authoritative.z;
        if ((dx * dx + dy * dy + dz * dz) > (rollback_position * rollback_position)) {
            return true;
        }
        // Angle between two rotations, from the dot product. |dot| because q and -q are
        // the same rotation and a sign flip is not a disagreement.
        const float d = std::fabs(w::dot(w::normalized(predicted.rot),
                                         w::normalized(authoritative.rot)));
        const float angle = 2.0f * std::acos(std::fmin(1.0f, d));
        return angle > rollback_angle;
    }

    static Quantized interpolate(const Quantized& from, const Quantized& to, float alpha) {
        Quantized out;
        out.x = w::lerp(from.x, to.x, alpha);
        out.y = w::lerp(from.y, to.y, alpha);
        out.z = w::lerp(from.z, to.z, alpha);
        out.rot = w::slerp(from.rot, to.rot, alpha);
        out.vx = w::lerp(from.vx, to.vx, alpha);
        out.vy = w::lerp(from.vy, to.vy, alpha);
        out.vz = w::lerp(from.vz, to.vz, alpha);
        out.wx = w::lerp(from.wx, to.wx, alpha);
        out.wy = w::lerp(from.wy, to.wy, alpha);
        out.wz = w::lerp(from.wz, to.wz, alpha);
        return out;
    }

    // The rotational half of the error is a ROTATION, not three offsets: the difference
    // between where we drew the body and where the server says it is, kept as the
    // quaternion that takes one to the other, and blended toward identity. Storing it as
    // Euler offsets would gimbal, which is the whole reason the pose is a quaternion.
    struct Error {
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
        w::Quat rot{};
    };

    static Error compute_error(const Quantized& current, const Quantized& previous) {
        Error error;
        error.x = previous.x - current.x;
        error.y = previous.y - current.y;
        error.z = previous.z - current.z;
        // previous * current^-1: pre-multiplying this by the corrected rotation gives
        // back the one that was being drawn.
        error.rot = w::multiply(w::normalized(previous.rot),
                                w::conjugate(w::normalized(current.rot)));
        return error;
    }

    static Quantized apply_error(const Quantized& current, const Error& error) {
        Quantized out = current;
        out.x += error.x;
        out.y += error.y;
        out.z += error.z;
        out.rot = w::normalized(w::multiply(error.rot, current.rot));
        return out;
    }

    static Error blend_out_error(const Error& error, float dt_seconds) {
        const float keep = std::exp(-dt_seconds / error_blend_seconds);
        Error out;
        out.x = error.x * keep;
        out.y = error.y * keep;
        out.z = error.z * keep;
        // Toward identity by the same fraction. slerp's alpha runs from the error to
        // identity, so the amount to REMOVE is 1 - keep.
        out.rot = w::slerp(error.rot, w::identity(), 1.0f - keep);
        return out;
    }
};

// ---- BodyKind --------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::vr::BodyKind> {
    using Quantized = ashiato_gd::vr::BodyKind;

    static void quantize(const ashiato_gd::vr::BodyKind& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::vr::BodyKind dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        out.write_unsigned_bits(current.kind & 0x1Fu, 5);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (in.remaining_bits() < 5) {
            return false;
        }
        out.kind = static_cast<std::uint8_t>(in.read_unsigned_bits(5));
        return true;
    }

    // A crate does not turn into an aeroplane mid-session. If it ever did, the physics
    // body and the mesh would both have to be rebuilt, which is not something a
    // resimulation can do.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }

    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

// ---- VehicleSeats ----------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::vr::VehicleSeats> {
    using Quantized = ashiato_gd::vr::VehicleSeats;

    static void quantize(const ashiato_gd::vr::VehicleSeats& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::vr::VehicleSeats dequantize(const Quantized& value) {
        return value;
    }

    // Eight bits per seat, which is exactly a sync ClientId including its 255 "nobody".
    // Packing it tighter would mean a second encoding of client ids that has to be kept
    // in step with sync's, for four bytes on a component that changes when somebody sits
    // down.
    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        for (std::size_t i = 0; i < ashiato_gd::vr::kMaxSeats; ++i) {
            out.write_unsigned_bits(current.occupant[i], 8);
        }
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (in.remaining_bits() < 8 * ashiato_gd::vr::kMaxSeats) {
            return false;
        }
        for (std::size_t i = 0; i < ashiato_gd::vr::kMaxSeats; ++i) {
            out.occupant[i] = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        }
        return true;
    }

    // TRUE on any difference, and this is the one that makes seats work at all.
    //
    // A player predicting the vehicle they are flying only adopts the server's values
    // when something forces a reconciliation. Who is in which seat is never simulated by
    // the client -- only the server decides it -- so with this returning false, somebody
    // climbing into the gunner's seat beside you would sit in the incoming update
    // unapplied until the aircraft happened to be corrected for an unrelated reason. It
    // is the same argument that made CarSetup roll back on any change, and it costs one
    // resimulation on an event that happens when a person sits down.
    static bool should_roll_back(const Quantized& current, const Quantized& previous) {
        for (std::size_t i = 0; i < ashiato_gd::vr::kMaxSeats; ++i) {
            if (current.occupant[i] != previous.occupant[i]) {
                return true;
            }
        }
        return false;
    }

    // Step, not blend: nobody is half out of a seat.
    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

// ---- HoldState -------------------------------------------------------------------

template <>
struct SyncComponentTraits<ashiato_gd::vr::HoldState> {
    using Quantized = ashiato_gd::vr::HoldState;

    static void quantize(const ashiato_gd::vr::HoldState& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::vr::HoldState dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        out.write_unsigned_bits(current.holder, 8);
        out.write_unsigned_bits(current.hand & 0x3u, 2);
        // The grip is only meaningful while something is held, and this component is
        // Step -- it goes on the wire when it changes, and a free prop's stale offset
        // would be 62 bits of nothing on every one of those changes.
        if (current.holder == ashiato_gd::vr::kNoOccupant) {
            return;
        }
        w::serialize_quantized_float(out, current.grab_x, w::grip_offset);
        w::serialize_quantized_float(out, current.grab_y, w::grip_offset);
        w::serialize_quantized_float(out, current.grab_z, w::grip_offset);
        w::write_quat(out, current.grab_rot);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (in.remaining_bits() < 10) {
            return false;
        }
        out.holder = static_cast<std::uint8_t>(in.read_unsigned_bits(8));
        out.hand = static_cast<std::uint8_t>(in.read_unsigned_bits(2));
        if (out.holder == ashiato_gd::vr::kNoOccupant) {
            out.grab_x = out.grab_y = out.grab_z = 0.0f;
            out.grab_rot = w::identity();
            return true;
        }
        return w::read_quantized_float(in, w::grip_offset, out.grab_x)
            && w::read_quantized_float(in, w::grip_offset, out.grab_y)
            && w::read_quantized_float(in, w::grip_offset, out.grab_z)
            && w::read_quat(in, out.grab_rot);
    }

    // TRUE on any difference, for the same reason as VehicleSeats -- and here it does
    // more work, because the holder decides WHETHER THIS CLIENT PREDICTS THIS PROP AT
    // ALL. A prop handed to you that stayed unpredicted until something else corrected
    // it would lag your hand by a round trip on the one frame it most matters.
    static bool should_roll_back(const Quantized& current, const Quantized& previous) {
        return current.holder != previous.holder || current.hand != previous.hand;
    }

    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

}  // namespace ashiato::sync
