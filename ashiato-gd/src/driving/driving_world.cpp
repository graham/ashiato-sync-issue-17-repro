// A networked driving world: ashiato ECS + ashiato-sync replication + a Box3D world we
// step ourselves.
//
// TRANSPORT IS NOT WIRED TO A SOCKET HERE, on purpose. Packets come out as
// PackedByteArrays and go back in the same way, so the same object works for a headless
// loopback test in one process and for SteamMultiplayerPeer in the real game. Baking
// Steam in would have made the pipeline untestable without two Steam accounts, which is
// the trap the voice chat work already fell into.
//
// The simulation is a sync SIMULATION JOB rather than a plain loop. That is what makes
// prediction work: on a server correction the client rewinds and RE-RUNS these jobs for
// the affected frames, so the sim must be something sync can replay, not something we
// call once per frame ourselves.

#include <algorithm>
#include <cmath>
#include <exception>
#include <stdexcept>
#include <cstdint>
#include <array>
#include <deque>
#include <memory>
#include <unordered_map>
#include <vector>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include "ashiato/ashiato.hpp"
#include "ashiato/sync/sync.hpp"
#include "core/input_truncation.hpp"
#include "box3d/box3d.h"
#include "../core/from_godot.hpp"
#include "driving/car_components.hpp"

#ifdef ASHIATO_GD_WITH_TRACING
#include "ashiato/sync/tracing.hpp"
#endif

using namespace godot;

namespace ashiato_gd {
namespace {

// sync throws std::exception subclasses for protocol and usage errors. An exception that
// escapes a GDExtension call terminates the process with no message at all -- which is
// exactly how the first version of this file "crashed" -- so every entry point that can
// reach sync reports instead.
#define DRIVING_TRY(expr, on_error)                                              \
    try {                                                                        \
        expr;                                                                    \
    } catch (const std::exception& error) {                                      \
        ERR_PRINT(godot::String("[driving] ") + godot::String(error.what()));     \
        on_error;                                                                \
    }


// Fixed, never frame-derived. A rollback replays steps, and a replay with a different dt
// is a different simulation.
constexpr float kFixedDt = 1.0f / 60.0f;
constexpr int kSubSteps = 4;

// The car is a 2.0 x 0.8 x 4.0 box at density 150, so it masses 960 kg and each tire
// carries about 2.35 kN standing still.
constexpr float kGravity = 9.81f;
// The car, 20% longer than it was: 4.8 m rather than 4.0, on a 3.12 m wheelbase rather
// than 2.6.
//
// Length is a stability knob, not decoration. A rear tire's slip angle is roughly
// (sideways speed - rear_axle * yaw_rate) / forward speed, so moving the rear axle back
// makes the same yaw rate cost the rear less slip -- the back end has further to travel to
// step out by the same angle, and more leverage against being made to. Widening the body
// would do nothing here; only the distance between the axles matters.
//
// It costs acceleration: same box, same density, 20% more of it, so 1152 kg instead of
// 960. Grip scales with load so cornering is unaffected, and top speed is set by drag, so
// this is paid for entirely off the line.
constexpr float kHalfWidth = 1.0f;
constexpr float kHalfHeight = 0.4f;
constexpr float kHalfLength = 2.4f;
constexpr float kWheelTrack = 0.85f;   // half the distance between left and right tires
constexpr float kFrontAxle = 1.56f;    // ahead of the centre of mass
constexpr float kRearAxle = 1.56f;     // behind it
// 150 kg/m^3 through the box above is 1152 kg, which is a hatchback with a driver in it.
constexpr float kDensity = 150.0f;
// Only used to size weight transfer, and lower than a real car's on purpose. Transfer
// unloads the front exactly when the throttle is open, which is when you are asking it to
// turn; at 0.55 the car put 61% of its weight on the rear under power and simply would not
// take a corner (it turned at a third of what the wheels asked for).
constexpr float kCgHeight = 0.40f;

// Power, not a constant force. A force that never falls off pulls just as hard at 75
// km/h as off the line, which is why the old model needed drag to do all the work of
// limiting top speed. F = P/v gives the shape a real car has: strong low down, tailing
// off as speed rises, and a top speed where power and drag meet.
constexpr float kEngineHp = 117.0f;
constexpr float kWattsPerHp = 745.7f;
// P/v goes to infinity as v goes to zero, so below a crossover speed the car is limited
// by gearing instead. That ceiling scales WITH the engine -- a fixed one would make power
// change nothing below the crossover, which at stock power is 17 m/s, i.e. almost the
// whole usable range on this track. Above the ceiling the friction circle takes over and
// a big engine simply spins its wheels, which is the correct answer.
constexpr float kDriveForcePerHp = 42.7f;  // newtons at the rear axle per hp
// What one press of the power key is worth, and how far it can be taken. Enforced by the
// SERVER, so a modified client cannot fit a 5000 hp engine.
constexpr float kHpStep = 10.0f;
constexpr float kMinHp = 40.0f;
constexpr float kMaxHp = 400.0f;
constexpr float kBrakeForce = 9000.0f;     // total, all four
constexpr float kReverseFraction = 0.4f;   // reverse is deliberately feeble
// Sized against the TRACK, not against realism: the lane is 38 m wide, the car corners
// at about 1.3 g, so anything above ~21 m/s cannot get round and the straights become a
// wait rather than a run.
constexpr float kDragCoefficient = 5.5f;   // F = -c*v*|v|, tops the car out near 23 m/s
constexpr float kRollingResistance = 30.0f;// F = -c*v

// Lateral force per radian of slip, per tire. Saturates against the friction circle at
// roughly 0.15 rad (8.5 deg), which is where a real tire peaks.
constexpr float kCorneringStiffness = 34000.0f;
// Braking is biased FORWARDS, like every real car, and for the same reason: brake force
// spends the rear tires' friction budget, and a rear tire with nothing left to give
// sideways lets the back of the car overtake the front. Equal braking on all four spun
// this car on corner entry.
constexpr float kBrakeBiasFront = 0.66f;
// The rear tires hold harder sideways than the fronts AT LOW SPEED. This is THE knob for
// stability: a car that runs out of front grip first washes wide and can be caught, one
// that runs out of rear grip first swaps ends.
//
// It fades towards parity as speed rises, and that is the whole point. Held at 1.10 the
// rear never lets go, so the front always saturates alone and every fast corner ends in
// the same dead push. Near parity both axles reach their limit together and the car
// slides on all four -- which is a thing you can steer with, unlike understeer, which
// only ever means "wait". Just under 1.0 so the rear goes a fraction after the front:
// balanced enough to slide, ordered enough not to spin.
constexpr float kRearGripBias = 1.10f;
constexpr float kRearGripBiasFast = 0.85f;
// Grip itself also falls off with speed. A car with no aerodynamic help really does hold
// on less at 70 km/h than at 30, and without this the car simply grips its way around
// fast corners at 1.6 g and there is no slide to balance in the first place.
constexpr float kGripSpeedLoss = 0.18f;
// Tire load sensitivity: mu FALLS as vertical load rises, so doubling the weight on a
// tire does not double its grip. This is real, well documented, and it is the piece that
// makes weight transfer interesting rather than merely annoying.
//
// Without it, grip is exactly proportional to load, so the axle that weight transfer
// leans on always wins: power loads the rear, the rear therefore out-grips the front, and
// the car pushes wide no matter what the tires are told to do. Worse, the only way to get
// the rear to let go under power was to weaken it everywhere -- which then made lift-off,
// where the rear is already light, a spin.
//
// With it, the heavily loaded axle gives some grip back and the light one keeps more. The
// loaded rear slides under power; the unloaded rear on a lift is protected. One
// coefficient, both problems, and it is what actually happens.
constexpr float kLoadSensitivity = 0.48f;
constexpr float kGrip = 2.3f;              // friction circle, mu
constexpr float kHandbrakeGrip = 0.32f;    // locked rears keep only this much sideways
constexpr float kMaxSteerAngle = 0.58f;    // 33 deg at the front wheels
// Full lock at speed spins the car; real cars have the same problem and solve it with a
// slower rack.
//
// But taper it too hard and the driver cannot ask the front tires for more than they can
// give, so the car can never slide -- it just grips until it runs out and pushes. At 0.66
// this was cutting lock to a third by 30 m/s and every fast corner was the same dead
// understeer. Leaving more lock available lets a fast corner be overdriven on purpose,
// and the rear bias fading over the same range is what makes that a four-wheel slide
// rather than a spin. It also leaves enough angle to catch one.
constexpr float kSteerSpeedFalloff = 0.42f;
constexpr float kSteerReferenceSpeed = 30.0f;
// Grip and the rear's share of it fade over a range matched to THIS car, not to the
// steering rack. The steering taper is measured against 30 m/s, which the car cannot
// reach -- its top speed is 21 -- so anything sharing that reference only ever gets two
// thirds of the way to its high-speed value, and a fast-cornering car sat at 17 m/s was
// still being given most of its low-speed rear grip. Fading over 18 m/s means the balance
// the fast numbers describe is the balance the car actually gets when cornering hard.
constexpr float kGripReferenceSpeed = 18.0f;
// atan2 is ill-conditioned as forward speed approaches zero: a millimetre of sideways
// drift becomes a huge slip angle and the tires fight it hard enough to shake the car.
// Softening the denominator makes a parked car simply not develop lateral force.
constexpr float kSlipSoftening = 1.5f;

// Steering commands a turn RATE, not a torque.
//
// Applying raw torque to the wheel means holding a direction keeps adding angular
// acceleration, so the car spins up without limit and the only cure is a torque small
// enough to feel dead at first. A real car has a maximum rate of turn for a given lock
// and speed, and the tyres hold it there. So the input picks a target yaw rate and the
// solver is asked for whatever torque closes the gap -- which is both far easier to
// drive and impossible to spin.

// ---- the tractor unit and its semi-trailer ---------------------------------------
//
// Real dimensions, not scaled-down ones. The track was derived from the car (see the
// README: a corner radius is v^2/16, and a lane is twice the tightest radius through
// it), so a vehicle that lies about its size would be tuned against a track that does
// not match it. A 74 m lane has room for a 22 m rig; the interesting part is that it
// only just has room for one going round a 34 m corner, which is the point.
//
// A US tractor with a 53 ft box trailer:
constexpr float kRigCabHalfWidth = 1.27f;    // 2.54 m across
constexpr float kRigCabHalfHeight = 0.85f;
constexpr float kRigCabHalfLength = 3.1f;    // 6.2 m of tractor
constexpr float kRigCabWheelTrack = 1.02f;
// Steer axle ahead of the tractor's centre of mass, drive tandem behind it. The tractor
// is nose-heavy without a trailer and this splits it roughly 60/40.
constexpr float kRigSteerAxle = 2.05f;
constexpr float kRigDriveAxle = 2.15f;
constexpr float kRigCabWheelbase = kRigSteerAxle + kRigDriveAxle;   // 4.2 m

constexpr float kRigTrailerHalfWidth = 1.3f;   // 2.6 m across
constexpr float kRigTrailerHalfHeight = 1.35f;
constexpr float kRigTrailerHalfLength = 8.08f; // 16.15 m: 53 ft

// THE NUMBER THIS WHOLE VEHICLE TURNS ON: where the fifth wheel sits on the tractor.
//
// Not at the back of the cab. The plate is mounted OVER the drive tandem, very slightly
// ahead of it -- real trucks quote a "fifth wheel offset" of 0 to about 600 mm forward
// of the tandem centreline, and this is 0.3 m of that. It is what makes a rig stable
// rather than a snaking caravan: the trailer pulls on the tractor essentially through
// the drive tires, so the coupling force has almost no lever arm about them and trailer
// sway cannot feed yaw back into the cab. Move this back to where a tow ball would be
// -- behind the rear axle -- and the same simulation becomes violently unstable, which
// is a real property of real vehicles and not a bug to be damped away.
//
// Measured from the tractor's centre of mass, negative being behind it.
constexpr float kRigFifthWheel = -(kRigDriveAxle - 0.3f);

// Kingpin to the trailer's tandem centre. This is the trailer's wheelbase and it is what
// sets off-tracking: in a steady corner of radius R the trailer's wheels track
// R - sqrt(R^2 - L^2) inside the tractor's, so 12.2 m of it through this track's 34 m
// corners cuts about 6 m across. That is the signature of a truck and it is not scripted
// anywhere -- it falls out of the joint.
constexpr float kRigKingpinToTandem = 12.2f;
// The kingpin sits 0.9 m back from the nose of the box, which is where the trailer's own
// centre of mass ends up relative to it once the tandem position is fixed.
constexpr float kRigKingpinFromNose = 0.9f;
// Trailer centre of mass behind the kingpin. Loaded trailers are loaded to sit roughly
// midway, and this keeps it there.
constexpr float kRigTrailerCentre = kRigTrailerHalfLength - kRigKingpinFromNose;
constexpr float kRigTrailerWheelTrack = 1.02f;

// How far the rig can fold before the trailer nose reaches the cab. Beyond this a real
// coupling is metal on metal, and the joint limit is what stops the trailer folding
// clean through the tractor -- without it the solver happily inverts the vehicle.
constexpr float kRigMaxFold = 1.31f;   // 75 degrees

// How high off the road the fifth wheel plate sits. It matters for more than looks: the
// two joint frames are offset to it, so the trailer's tall box rests on the ground
// instead of being dragged down to the cab's centre height.
constexpr float kRigPlateHeight = 1.25f;
// Where the trailer's centre sits relative to the cab's, once both are on their wheels.
constexpr float kRigTrailerRise = kRigTrailerHalfHeight - kRigCabHalfHeight;

// Static load shares, straight out of the geometry. A trailer is a beam on two supports:
// the kingpin at the front and the tandem at the back, with its centre of mass between
// them, so each carries the share the lever arms say it does.
constexpr float kRigTandemShare = kRigTrailerCentre / kRigKingpinToTandem;
constexpr float kRigKingpinShare = 1.0f - kRigTandemShare;
// And the cab is another beam: its own weight over its two axles, plus whatever the
// kingpin puts on it. Note how nearly all of the kingpin load lands on the drive tandem
// -- that is the fifth wheel being over the drive axle, and it is why a loaded rig has
// traction and an empty one does not.
constexpr float kRigDriveOwnShare = kRigSteerAxle / kRigCabWheelbase;
constexpr float kRigDriveKingpinShare =
    (kRigSteerAxle - kRigFifthWheel) / kRigCabWheelbase;

// Densities chosen to land on real masses: about 8 t of tractor and 28 t of loaded
// trailer, for the 36 t that a fully freighted 18-wheeler runs at.
constexpr float kRigCabDensity = 187.0f;
constexpr float kRigTrailerDensity = 198.0f;

// ---- the buggy -------------------------------------------------------------------
//
// The other end of the range from the rig, and the reason the tables below are tables.
//
// A buggy is not a fast car, it is a STEERABLE-WHILE-SIDEWAYS one, and the two halves of
// that belong together. Plenty of vehicles will step their back end out; what makes one
// worth driving rather than merely twitchy is having enough lock left to answer with,
// because catching a slide means pointing the front wheels where the car is actually
// going. A road car runs out of steering at about 33 degrees, so a slide wider than that
// cannot be caught at all -- only waited out. Give the same vehicle 50-odd degrees and
// the same slide becomes something held on purpose.
//
// So the geometry here is chosen to make it break away early and slowly -- short, light,
// wide-tracked, on soft tires -- and the handling below is chosen to leave the driver the
// steering to answer with.
constexpr float kBuggyHalfWidth = 0.85f;    // 1.7 m across
constexpr float kBuggyHalfHeight = 0.45f;
constexpr float kBuggyHalfLength = 1.6f;    // 3.2 m long, against the car's 4.8
// Wheels OUTSIDE the body, which a road car's are not. It widens the base that weight
// transfer works against without adding any length for the car to rotate about.
constexpr float kBuggyWheelTrack = 0.95f;
// 2.3 m between the axles against the car's 3.12, and this is the number that makes it
// rotate. A rear tire's slip angle goes as (sideways speed - rear_axle * yaw_rate) /
// forward speed, so a SHORT car's rear pays more slip for the same yaw rate: the back
// steps out sooner, and -- the part that matters -- at a speed low enough to be worth
// catching. It is exactly the lever the car was lengthened to pull the other way.
constexpr float kBuggyFrontAxle = 1.15f;
constexpr float kBuggyRearAxle = 1.15f;
// About 640 kg with a driver in it: a tube frame, an engine, and no bodywork.
constexpr float kBuggyDensity = 131.0f;

// Three kinds so far, and the wire format allows four.
constexpr int kVehicleKinds = 3;
constexpr std::uint8_t kKindCar = 0;
constexpr std::uint8_t kKindRig = 1;
constexpr std::uint8_t kKindBuggy = 2;

// The most tires any one vehicle reports. A car uses four, a rig uses six -- one entry
// per axle END, so a dualled tandem counts once per side.
constexpr int kMaxTires = 6;

// The SHAPE of a vehicle: the box the physics collides with, where its axles are, what it
// masses, and whether it tows anything. Per KIND, for exactly the reasons Handling is.
//
// These were file-scope constants read directly by ensure_body, by the geometry handed to
// the renderer and by the tire placement in push_to_physics. That was right while every
// vehicle was the car, and it became a scattering of `kind == kKindRig ? ... : ...` the
// moment there were two -- each one a place where a third vehicle would silently be
// treated as a car. As a table there is nothing to branch on: a new vehicle is one
// Chassis, one Handling and a name, and every consumer picks the row up by index.
struct Chassis {
    float half_width_ = kHalfWidth;
    float half_height_ = kHalfHeight;
    float half_length_ = kHalfLength;
    float wheel_track_ = kWheelTrack;   // half the distance between left and right tires
    float front_axle_ = kFrontAxle;     // ahead of the centre of mass
    float rear_axle_ = kRearAxle;       // behind it
    float density_ = kDensity;
    // Whether it tows on a fifth wheel, and the ONE genuinely structural difference
    // between vehicles: an articulated one is two bodies and a joint, carries RigState in
    // its archetype, reports six contact patches rather than four, and is stepped by
    // push_rig instead of by the car path. Everything else about a vehicle is numbers.
    bool articulated_ = false;

    float wheelbase() const {
        return front_axle_ + rear_axle_;
    }
};

inline Chassis rig_chassis() {
    Chassis c;
    c.half_width_ = kRigCabHalfWidth;
    c.half_height_ = kRigCabHalfHeight;
    c.half_length_ = kRigCabHalfLength;
    c.wheel_track_ = kRigCabWheelTrack;
    c.front_axle_ = kRigSteerAxle;
    c.rear_axle_ = kRigDriveAxle;
    c.density_ = kRigCabDensity;
    c.articulated_ = true;
    return c;
}

inline Chassis buggy_chassis() {
    Chassis c;
    c.half_width_ = kBuggyHalfWidth;
    c.half_height_ = kBuggyHalfHeight;
    c.half_length_ = kBuggyHalfLength;
    c.wheel_track_ = kBuggyWheelTrack;
    c.front_axle_ = kBuggyFrontAxle;
    c.rear_axle_ = kBuggyRearAxle;
    c.density_ = kBuggyDensity;
    return c;
}

// What each kind is CALLED. Bound to GDScript so a menu entry, a command-line flag, a
// lobby row and a log line do not each keep their own spelling of the same list -- and so
// that adding a vehicle does not mean finding all four of them.
constexpr const char* kVehicleNames[kVehicleKinds] = {"car", "rig", "buggy"};
static_assert(kVehicleNames[kKindCar] != nullptr && kVehicleNames[kKindRig] != nullptr
                  && kVehicleNames[kKindBuggy] != nullptr,
              "every vehicle kind needs a name in kVehicleNames");

// Everything that shapes how a vehicle feels, as a set rather than as loose members.
//
// It was eighteen fields on the world, which was right while every vehicle was the same
// car. A 36 tonne rig is not a heavy car: it corners at a fraction of the g, its lock is
// a third, its power per tonne is a tenth, and its rear axle wants MORE grip bias than
// its front rather than less. Sharing one set would mean tuning a compromise nobody
// drives.
//
// Per KIND, not per vehicle, and given identically to every peer by the game -- the same
// discipline the track is built under. A per-vehicle table would have to be replicated
// or the client would be corrected on every tick; a per-kind one only has to be
// IDENTICAL, which a shared constant already guarantees. Engine power stays the
// exception it always was: it is per car, replicated, because players tune it.
struct Handling {
    float max_steer_ = kMaxSteerAngle;
    float steer_falloff_ = kSteerSpeedFalloff;
    float steer_reference_speed_ = kSteerReferenceSpeed;
    float cornering_stiffness_ = kCorneringStiffness;
    float engine_hp_ = kEngineHp;
    float drive_force_per_hp_ = kDriveForcePerHp;
    float brake_force_ = kBrakeForce;
    float brake_bias_front_ = kBrakeBiasFront;
    float grip_ = kGrip;
    float grip_speed_loss_ = kGripSpeedLoss;
    float grip_reference_speed_ = kGripReferenceSpeed;
    float rear_grip_bias_ = kRearGripBias;
    float rear_grip_bias_fast_ = kRearGripBiasFast;
    float load_sensitivity_ = kLoadSensitivity;
    float handbrake_grip_ = kHandbrakeGrip;
    float cg_height_ = kCgHeight;
    float drag_ = kDragCoefficient;
    float rolling_resistance_ = kRollingResistance;
    // What the +/- keys may wind this kind of engine to. Per kind because the ranges do
    // not overlap in any useful way: a 400 hp car is a monster and a 400 hp artic is
    // under-powered. Both must stay inside CarSetup's wire range or the figure the server
    // holds is not the figure anyone else can be told about.
    float min_hp_ = kMinHp;
    float max_hp_ = kMaxHp;
};

// What a loaded 18-wheeler drives like, and why each number moved.
//
// These are defaults in exactly the way the car's are: feel is found by driving, and
// set_vehicle_handling overrides any of them from GDScript without a rebuild.
inline Handling default_rig_handling() {
    Handling h;
    // A truck's wheel turns further than a car's at the rim but the ROAD wheels do not:
    // about 20 degrees of lock at the tire against the car's 33.
    h.max_steer_ = 0.35f;
    // And it holds more of that lock at speed, because it never gets to a speed where
    // the taper would matter.
    h.steer_falloff_ = 0.30f;
    // 450 hp, which is an ordinary long-haul figure. Against 36 tonnes it is a tenth of
    // the car's power-to-weight, and that is the whole character of the vehicle.
    h.engine_hp_ = 450.0f;
    // Geared for load, not for pace: far more force per hp off the line, and a top speed
    // set by drag well below the car's.
    h.drive_force_per_hp_ = 95.0f;
    // Air brakes on five axles, sized against 36 t rather than 1.2 t.
    h.brake_force_ = 190000.0f;
    // Less front bias than a car. A tractor brakes with the trailer pushing it from
    // behind, and biasing the front is how the drive axle gets light and jackknifes.
    h.brake_bias_front_ = 0.52f;
    // Truck tires are stiffer in absolute terms but far softer per tonne carried, which
    // is why a rig leans on its slip angles and takes a long time to change direction.
    h.cornering_stiffness_ = 210000.0f;
    // The number that stops it driving like a car: about 0.75 g against the car's 1.65.
    h.grip_ = 0.75f;
    h.grip_speed_loss_ = 0.10f;
    h.grip_reference_speed_ = 14.0f;
    // MORE grip at the drive axle than the steer axle, the opposite of the car's balance
    // at speed. A rig that oversteers is a rig that is jackknifing, and a real one is
    // built to plough straight on instead.
    h.rear_grip_bias_ = 1.15f;
    h.rear_grip_bias_fast_ = 1.05f;
    // Heavily load sensitive: this is why an EMPTY trailer skates and a loaded one grips.
    h.load_sensitivity_ = 0.62f;
    // There is no handbrake turn in a truck. The trailer brakes lock and it swings.
    h.handbrake_grip_ = 0.45f;
    // High and narrow. Weight transfer is what makes a rig feel top-heavy.
    h.cg_height_ = 1.35f;
    // A box trailer is a barn door: far more drag than a car, which is what caps it near
    // 29 m/s despite four times the power.
    h.drag_ = 40.0f;
    h.rolling_resistance_ = 900.0f;
    // 450 hp is an ordinary long-haul figure and 600 is the top of what is built. The
    // floor is high because a rig below about 260 hp cannot pull itself up to speed at
    // all, and an undrivable setting is not a tuning option.
    h.min_hp_ = 260.0f;
    h.max_hp_ = 600.0f;
    return h;
}

// What a buggy drives like: it oversteers on purpose, and it gives you the steering to
// deal with that.
//
// The two numbers that matter are the first two, and they are one idea. Everything else
// is here to make the slide arrive early enough and slowly enough to be worth catching.
inline Handling default_buggy_handling() {
    Handling h;
    // FORTY-TWO DEGREES of lock, against the car's 33 and the rig's 20. High-lock
    // steering knuckles are a real and popular modification for exactly one reason:
    // opposite lock only works while there is lock left to apply, so a car that stops at
    // 33 degrees can only catch slides narrower than 33 degrees.
    //
    // It was 54, and 54 was too much -- not as a matter of taste but arithmetically. A
    // steering angle asks for a radius of wheelbase/tan(angle), and on 2.3 m that is 1.6
    // metres at 54 degrees: six g at any speed worth driving, which no tire in this game
    // can deliver. So the front simply saturated and the vehicle ploughed, and because
    // the keyboard has no half-lock -- pressing D asks for ALL of it -- that happened in
    // every single corner. Measured against steering angle, the yaw rate this vehicle
    // achieves peaks at about 40 degrees and FALLS beyond it: past that, more lock is
    // less turn. The rack now stops where the tires stop, so all of it is usable, and
    // what is left after the speed taper is still 40 degrees against the car's 29.
    h.max_steer_ = 0.74f;
    // And it KEEPS that lock at speed. The car gives up 42% of its steering by 30 m/s,
    // which is right for a car -- full lock at speed is a spin -- but it is also the
    // reason a big slide cannot be caught at 20 m/s in one. Losing only 12% here is what
    // makes the extra angle available when it is actually wanted, which is fast and
    // sideways rather than parked.
    h.steer_falloff_ = 0.12f;
    // Measured against what this vehicle can actually reach, so the taper it describes is
    // the taper it gets. Referenced to 30 m/s it would never arrive at all.
    h.steer_reference_speed_ = 22.0f;
    // Stiff for its weight: 30 kN per radian on 640 kg is 47 kN/rad/tonne against the
    // car's 30, which is a light vehicle on wide tires and is what gives it a front end
    // that answers immediately.
    //
    // It was 17000, chosen as "soft knobbly tires", and lazy tires turned out to be the
    // wrong way to make the break-away progressive: a front that needs a lot of slip
    // before it makes any force is a front that has already washed wide by the time it
    // does. Progressive break-away comes from the load sensitivity and the friction
    // circle below, both of which act at the LIMIT; stiffness only decides how quickly
    // the tire gets there. Dropping it merely made the vehicle vague.
    h.cornering_stiffness_ = 30000.0f;
    // 130 hp in 640 kg. Twice the car's power to weight, and deliberately more than the
    // tires can put down: throttle is a steering input on this thing.
    h.engine_hp_ = 130.0f;
    h.drive_force_per_hp_ = 40.0f;
    // Sized against 640 kg rather than 1150. About 1.1 g, comfortably inside the grip
    // below, so the brakes modulate rather than simply locking.
    h.brake_force_ = 7000.0f;
    // Less front bias than the car's 0.66. Braking into a corner should rotate this
    // vehicle -- that is how you point it -- rather than push it straight on.
    h.brake_bias_front_ = 0.60f;
    // The SAME mu as the car, which is the honest answer for two vehicles on the same
    // tarmac -- what separates them is where the grip is spent, not how much there is.
    //
    // It was 1.9, sold as "a limit you can reach and play with". What that actually
    // bought was a front axle that could not hold the angles the steering offered, and
    // dropping the lock to match would have made a slow understeering car rather than a
    // playful one. The character comes from the bias below and from a 2.3 m wheelbase;
    // taking grip away as well only made it worse in both directions -- and at 1.9 with
    // the stiffness above the vehicle snapped into a spin at moderate lock rather than
    // sliding, which is measurably not the same thing.
    h.grip_ = 2.3f;
    h.grip_speed_loss_ = 0.10f;
    h.grip_reference_speed_ = 16.0f;
    // BELOW 1 at every speed, which is the opposite of the car and the opposite of the
    // rig. The rear runs out before the front, so the back steps out first and the
    // vehicle rotates instead of washing wide. On its own that would just be a car that
    // spins; with 54 degrees of lock to answer it, it is a car that drifts.
    h.rear_grip_bias_ = 0.86f;
    h.rear_grip_bias_fast_ = 0.78f;
    // MORE load sensitive than the car, and this is what makes the throttle rotate it.
    // Weight transfer under power leans on the rear tires, and a tire that gives grip
    // back as it is loaded therefore gives some back exactly when the power arrives. On a
    // 2.3 m wheelbase with a high centre of mass that transfer is three times the car's,
    // so without this the buggy would GAIN rear grip under throttle and push wide -- the
    // opposite of the vehicle, and what the first version of these numbers measured.
    h.load_sensitivity_ = 0.52f;
    // A handbrake that actually does something: locked rears with almost nothing left
    // sideways is how you break traction deliberately rather than waiting for a corner to
    // do it for you.
    h.handbrake_grip_ = 0.22f;
    // LOW, and lower than the car's 0.40 despite a buggy standing taller than one.
    //
    // This is a weight-transfer knob and nothing else -- the comment on the car's says so
    // too, and admits its own literal value was undrivable. Transfer scales as
    // cg_height/wheelbase, and on 2.3 m a literal figure would move nearly three times
    // the weight per g that the car does. All of that comes off the front axle exactly
    // when the throttle is open, which is exactly when you are asking it to turn: at 0.50
    // the buggy lost a tenth of its front load under power and ploughed. It still squats
    // and dives more than the car; it no longer steers with its nose in the air.
    h.cg_height_ = 0.26f;
    // No bodywork to speak of, so far more drag than the car per kilo. It tops out around
    // 22 m/s, near the car, having got there much faster.
    h.drag_ = 9.0f;
    h.rolling_resistance_ = 35.0f;
    // The car's floor, and a lower ceiling. 260 hp in 640 kg is already absurd, which is
    // the point of having the ceiling anywhere at all.
    h.min_hp_ = kMinHp;
    h.max_hp_ = 260.0f;
    return h;
}

}  // namespace

class DrivingWorld : public RefCounted {
    GDCLASS(DrivingWorld, RefCounted)

public:
    DrivingWorld() = default;

    ~DrivingWorld() override {
        teardown();
    }

    // ---- setup ----

    // client_id 0 means "be the server". Everything else is symmetric: both sides build
    // the same components, archetype and simulation job, because the client has to be
    // able to run the server's simulation in order to predict it.
    bool start(int64_t client_id) {
        teardown();
        is_server_ = client_id == 0;

        b3WorldDef world_def = b3DefaultWorldDef();
        world_def.gravity = b3Vec3{0.0f, -9.81f, 0.0f};
        physics_ = b3CreateWorld(&world_def);
        physics_alive_ = true;
        build_ground();

        state_component_ = ashiato::sync::register_sync_component<driving::CarState>(
            registry_, "CarState");
        input_component_ = ashiato::sync::register_sync_component<driving::CarInput>(
            registry_, "CarInput");
        owner_component_ =
            ashiato::sync::register_sync_component<driving::CarOwner>(registry_, "CarOwner");
        setup_component_ =
            ashiato::sync::register_sync_component<driving::CarSetup>(registry_, "CarSetup");
        kind_component_ = ashiato::sync::register_sync_component<driving::VehicleKind>(
            registry_, "VehicleKind");
        rig_component_ =
            ashiato::sync::register_sync_component<driving::RigState>(registry_, "RigState");
        ashiato::sync::set_client_input_component<driving::CarInput>(registry_);

        // Let the renderer sample CarState BETWEEN ticks without mutating the ECS. This
        // is what sampled_cars() reads: sync knows where a car was at frame 41.6, which
        // is a far better answer than lerping the last two ticks by hand, because it
        // draws from the buffered timeline rather than from whatever happens to be live.
        sampling_marked_ = ashiato::sync::set_fractional_tick_sampled<driving::CarState>(registry_);
        // The fold, sampled on the SAME fractional tick as the cab. This is not an
        // optimisation, it is the coupling: drawing the cab from the sample buffer and
        // the trailer from whatever is live in the ECS would put them on two different
        // timelines, and the kingpin -- the one point that must be common to both bodies
        // -- would visibly come apart. Deriving the trailer only guarantees the coupling
        // if both halves are derived from the same instant.
        sampling_marked_ =
            ashiato::sync::set_fractional_tick_sampled<driving::RigState>(registry_)
            && sampling_marked_;

        // Interpolate, not Step: another player's car between two received frames should
        // slide, not teleport. Our own car ignores this -- it is predicted.
        archetype_ = ashiato::sync::define_archetype(
            registry_, "Car",
            {ashiato::sync::replicate<driving::CarState>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Interpolate),
             // CarInput is deliberately ABSENT, and this is the third time that has
             // been established the hard way.
             //
             // Sent to the OWNER, the server echoes each client its own input back a round
             // trip late; that echo lands on the predicted car and overwrites the live
             // input it should be predicting with, so the car drives on the wheel from
             // sixteen ticks ago.
             //
             // Sent to EVERYONE EXCEPT the owner -- which looks like the fix, because it
             // would let a client simulate other cars and so make predicting them
             // converge -- the owner ends up never receiving a component its own archetype
             // says exists, and reconciliation churns on the gap. Measured: rollbacks went
             // from 3 per 300 frames to 300 per 300, for the interpolating case that was
             // previously healthy. Worse than the problem it was meant to solve.
             //
             // So input travels only by sync's own client->server input path, and the
             // consequence is accepted rather than worked around: nobody can simulate
             // anybody else's car, therefore nobody should predict one. See
             // entities.default_mode below.
             // Everyone needs to know who owns which car. The client uses it to pick its
             // OWN car for prediction -- without it every entity falls through to
             // interpolation, the simulation job never runs client-side, and nothing is
             // predicted at all. CarOwner rather than sync::NetworkOwner: the latter has
             // no SyncComponentTraits, so putting it in an archetype crashes on the first
             // serialize.
             ashiato::sync::replicate<driving::CarOwner>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Step),
             // Everyone, not just the owner: the whole point is that the other drivers
             // can see what engine you are running, and every machine has to simulate
             // your car with it.
             ashiato::sync::replicate<driving::CarSetup>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Step),
             // Two bits saying what this thing is. Every machine needs it before it can
             // simulate the vehicle at all -- it picks the handling table and the body
             // shape -- so it cannot be inferred from the archetype, which is sync's
             // business and invisible to the game layer.
             ashiato::sync::replicate<driving::VehicleKind>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Step)});

        // The same vehicle plus its fold. Everything a car has, because a tractor unit
        // IS a car as far as the replicated pose goes -- the trailer is the one thing
        // added, and it is added as an angle rather than as a second pose.
        archetype_rig_ = ashiato::sync::define_archetype(
            registry_, "Rig",
            {ashiato::sync::replicate<driving::CarState>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Interpolate),
             ashiato::sync::replicate<driving::CarOwner>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Step),
             ashiato::sync::replicate<driving::CarSetup>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Step),
             ashiato::sync::replicate<driving::VehicleKind>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Step),
             // Interpolate, like the pose it belongs to. A remote rig's fold has to move
             // smoothly between the frames that actually arrive for the same reason its
             // position does -- and interpolating ONE angle is far better behaved than
             // interpolating a second pose would be, because a single scalar through the
             // short way round cannot drift away from the cab it is attached to.
             ashiato::sync::replicate<driving::RigState>(
                 registry_,
                 ashiato::sync::invalid_sync_component_serializer_id,
                 ashiato::sync::ReplicationAudience::All,
                 ashiato::sync::ComponentInterpolation::Interpolate)});

        if (is_server_) {
            ashiato::sync::ReplicationServerOptions options;
            options.fixed_dt_seconds = kFixedDt;
            // PeerId, NOT ClientId. TransportFn hands back the same PeerId that was
            // passed to receive_packet, and PeerId is a uint64 while ClientId is a
            // uint8 -- taking the argument as ClientId truncates a Godot peer id (a
            // random 32-bit number) to its low byte and routes packets to the wrong
            // machine, or to none. Using the peer id straight through is also what
            // removes any need for a ClientId->peer mapping table.
            options.transport = [this](ashiato::sync::PeerId peer,
                                       const ashiato::BitBuffer& packet) {
                queue_outbound(static_cast<int64_t>(peer), packet);
            };
            server_ = std::make_unique<ashiato::sync::ReplicationServer>(registry_, options);
            attach_tracer([this](ashiato::sync::SyncTracer* t) { server_->set_tracer(t); });
        } else {
            ashiato::sync::ReplicationClientOptions options;
            options.clock.fixed_dt_seconds = kFixedDt;
            // A NON-EMPTY connect token is what makes the client actually handshake.
            // ReplicationClient's constructor reads:
            //
            //   if (options_.session.connect_token.empty()) { set_connection_state(Ready); }
            //
            // so an empty token is the preassigned-session mode: the client declares
            // itself Ready, never sends a connect packet, and the server's client_count()
            // stays at zero while the client sits there "connected" and receiving
            // nothing. That failure looks exactly like a broken transport, which is where
            // a long time went. session.local_client is likewise left alone -- the server
            // assigns the id during the handshake and client_id() reports it after.
            options.session.connect_token = "ashiato-gd-driving";
            // How far behind the server the interpolated cars are drawn. This is the
            // trade the whole feel rests on: MORE frames means smoother remote cars that
            // survive jitter and loss, at the cost of seeing them further in the past.
            // Auto-sizing from measured jitter is on by default and is usually right; the
            // floor is what stops it dropping so low that one late packet shows.
            options.buffered.buffered_frame_lag = buffered_frames_;
            options.buffered.auto_buffered_frame_lag = auto_buffer_;
            options.buffered.auto_buffered_frame_lag_min = buffered_frames_;

            options.entities.default_mode = predict_all_
                ? ashiato::sync::ReplicationClientMode::Predict
                : ashiato::sync::ReplicationClientMode::BufferedInterpolation;

            // THE line that makes this a driving game rather than a puppet show: your own
            // car is predicted so it answers the wheel immediately, everyone else's is
            // interpolated so it moves smoothly between the frames that actually arrive.
            // Compares against the ASSIGNED id, read from the client at selection time.
            // The id passed to start() is only a request: the server picks the real one
            // during the handshake, so capturing it here would predict the wrong car (or
            // none) whenever the two differ.
            options.entities.mode_selector =
                [this](const ashiato::sync::ReplicatedEntityUpdateView& view) {
                    driving::CarOwner owner;
                    const auto local = client_ != nullptr ? client_->client_id()
                                                          : ashiato::sync::invalid_client_id;
                    if (view.try_get<driving::CarOwner>(registry_, owner)
                            && owner.client == static_cast<std::uint32_t>(local)) {
                        return ashiato::sync::ReplicationClientMode::Predict;
                    }
                    // Everyone else. This has to consult predict_all_ rather than fall
                    // through to options.entities.default_mode: a selector that returns a
                    // mode for EVERY entity answers first, so the default is never
                    // reached and setting it does exactly nothing. Measured as byte-for-
                    // byte identical output with the switch on and off, which is the
                    // signature of a knob wired to nothing.
                    return predict_all_
                        ? ashiato::sync::ReplicationClientMode::Predict
                        : ashiato::sync::ReplicationClientMode::BufferedInterpolation;
                };

            // Told whenever the client has to rewind and replay. This is the single
            // most interesting thing that happens in a networked game and it is otherwise
            // completely invisible: the car simply is not quite where it was a moment ago.
            //
            // Counted per entity as well as in total, so a renderer can flash the car that
            // was actually corrected rather than every car on the grid.
            options.rollback_prepared_handler =
                [this](ashiato::Registry&,
                       const ashiato::sync::ReplicationClientRollbackPreparedEvent& event) {
                    ++resim_count_;
                    last_resim_frame_ = static_cast<int64_t>(event.rollback_frame);
                    last_resim_span_ = static_cast<int64_t>(event.resim_end_frame)
                        - static_cast<int64_t>(event.rollback_frame) + 1;
                    for (const ashiato::Entity entity : event.resimulated_entities) {
                        ++resims_of_[entity.value];
                    }
                };

            client_ = std::make_unique<ashiato::sync::ReplicationClient>(registry_, options);
            attach_tracer([this](ashiato::sync::SyncTracer* t) { client_->set_tracer(t); });
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
        trailers_.clear();
        fifth_wheels_.clear();
        outbound_.clear();
        started_ = false;
    }

    bool is_server() const {
        return is_server_;
    }

    // ---- cars ----

    // Server-side only: creates the authoritative entity and starts replicating it.
    int64_t spawn_car(int64_t owner_client, const Vector3& position, float yaw) {
        return spawn_vehicle(owner_client, position, yaw, kKindCar);
    }

    int64_t spawn_vehicle(int64_t owner_client, const Vector3& position, float yaw,
                          int64_t kind) {
        if (!started_ || !is_server_) {
            return 0;
        }
        const std::size_t index = kind_index(kind);
        const ashiato::Entity entity = registry_.create();
        registry_.add<driving::CarState>(
            entity,
            driving::CarState{from_godot(position.x), from_godot(position.y),
                              from_godot(position.z), from_godot(yaw), 0, 0, 0, 0});
        registry_.add<driving::CarInput>(entity, driving::CarInput{});
        registry_.add<driving::CarSetup>(entity,
                                         driving::CarSetup{handling_[index].engine_hp_});
        registry_.add<driving::VehicleKind>(
            entity, driving::VehicleKind{static_cast<std::uint8_t>(index)});
        ashiato::sync::set_owner(registry_, entity,
                                 static_cast<ashiato::sync::ClientId>(owner_client));
        registry_.add<driving::CarOwner>(
            entity, driving::CarOwner{static_cast<std::uint32_t>(owner_client)});
        // Straight and settled. A rig that spawned folded would be pushed apart by the
        // joint on its first step.
        if (chassis_[index].articulated_) {
            registry_.add<driving::RigState>(entity, driving::RigState{0.0f, 0.0f});
        }
        registry_.add<ashiato::sync::Replicated>(
            entity, ashiato::sync::Replicated{
                        chassis_[index].articulated_ ? archetype_rig_ : archetype_});
        ensure_body(entity);
        return static_cast<int64_t>(entity.value);
    }

    // Tell the server a client has gone.
    //
    // sync does not find this out on its own: it is handed packets and has no idea a
    // socket closed, so without this it keeps the departed client in client_ids(), keeps
    // trying to send it updates, and the game keeps thinking it still needs a car on the
    // grid. The transport is the only thing that knows, so the transport has to say.
    bool remove_client(int64_t client_id) {
        if (!started_ || server_ == nullptr) {
            return false;
        }
        bool removed = false;
        DRIVING_TRY(removed = server_->remove_client(
                        registry_, static_cast<ashiato::sync::ClientId>(client_id)),
                    return false);
        return removed;
    }

    // Take a car out of the world when its driver leaves. Server only: the clients are
    // told by replication, the same way they were told it appeared.
    void despawn_car(int64_t entity_id) {
        if (!started_ || !is_server_) {
            return;
        }
        const ashiato::Entity entity{static_cast<std::uint64_t>(entity_id)};
        release_bodies(entity);
        steer_of_.erase(entity.value);
        slip_of_.erase(entity.value);

        // REMOVE THE Replicated COMPONENT, and do it before destroying anything.
        //
        // Destroying the entity is not what tells the server. It watches the registry's
        // dirty frame for `each_removed<Replicated>` -- component removals, not dead
        // entities -- so an entity destroyed outright vanished locally while the server's
        // replicated slot lived on, and every client kept the car parked on the track with
        // nobody driving it.
        //
        // (Calling rediscover_all_replicated_entities by hand does not help either: the
        // tick clears the queue it fills before broadcasting, so the destroy is discarded.)
        registry_.remove<ashiato::sync::Replicated>(entity);
        pending_destroy_.push_back(entity);
    }

    // Static track collision. Called identically on the server and every client: the
    // track is not replicated, because both sides build it from the same scene data and
    // sending immovable geometry every frame would be absurd. If the two ever disagree
    // the client would predict itself through a wall the server can see, so this is one
    // place where "both sides run the same code" is load-bearing.
    void add_track_box(const Vector3& position, const Vector3& half_extents) {
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

    // Which client drives this car. The renderer needs it to know which car to follow and
    // to colour; -1 means the component has not arrived yet.
    int64_t car_owner(int64_t entity_id) {
        const ashiato::Entity entity{static_cast<std::uint64_t>(entity_id)};
        const auto* owner = static_cast<const driving::CarOwner*>(
            registry_.get(entity, owner_component_));
        return owner == nullptr ? -1 : static_cast<int64_t>(owner->client);
    }

    // The id the SERVER assigned us, so the renderer can match it against car_owner().
    //
    // Returns 0 while unassigned rather than sync's invalid_client_id, which is 255 --
    // a value that sails through an "is it assigned yet" test written as `> 0` and gets
    // a car spawned owned by a client that does not exist. It then never predicts,
    // because no connected client ever matches that owner.
    int64_t local_client_id() const {
        if (client_ == nullptr) {
            return 0;
        }
        const auto id = client_->client_id();
        return id == ashiato::sync::invalid_client_id ? 0 : static_cast<int64_t>(id);
    }

    void add_client(int64_t client_id) {
        if (server_) {
            server_->add_client(static_cast<ashiato::sync::ClientId>(client_id));
        }
    }

    // ---- per frame ----

    void set_input(float throttle, float steer, bool handbrake, int hp_step) {
        driving::CarInput input;
        input.throttle = throttle;
        input.steer = steer;
        input.handbrake = handbrake ? 1 : 0;
        input.hp_step = static_cast<std::int8_t>(hp_step > 0 ? 1 : (hp_step < 0 ? -1 : 0));
        if (client_) {
            DRIVING_TRY(adopt_local_cars(), return);
            DRIVING_TRY(client_->set_input<driving::CarInput>(registry_, input), return);
        } else if (server_) {
            DRIVING_TRY(server_->set_local_input<driving::CarInput>(registry_, input), return);
        }
    }

    // Drive one specific car, server-side. set_input() targets the LOCAL player's car
    // through sync's input path; this writes the component directly, which is what any
    // server-controlled car (an AI, a stand-in for an absent player) needs. Server only:
    // on a client this would be overwritten by the next authoritative update anyway.
    void set_car_input(int64_t entity_id, float throttle, float steer, bool handbrake) {
        if (!is_server_) {
            return;
        }
        const ashiato::Entity entity{static_cast<std::uint64_t>(entity_id)};
        auto* input = static_cast<driving::CarInput*>(
            registry_.write(entity, input_component_));
        if (input == nullptr) {
            return;
        }
        input->throttle = throttle;
        input->steer = steer;
        input->handbrake = handbrake ? 1 : 0;
    }

    // Build a tracer and hand it to whichever side we are, if tracing was asked for.
    //
    // The callback runs INSIDE sync, potentially deep in a serialization path, so it does
    // the least it can get away with: format the event and push it on a bounded queue for
    // the game to collect on its own time. Anything heavier here would change the timing
    // of the thing being measured.
    template <typename Install>
    void attach_tracer(Install install) {
#ifdef ASHIATO_GD_WITH_TRACING
        if (!tracing_) {
            return;
        }
        ashiato::sync::SyncTraceCallbacks callbacks;
        callbacks.on_event = [this](const ashiato::sync::SyncTraceEvent& event) {
            record_trace(event);
        };
        tracer_ = std::make_unique<ashiato::sync::SyncTracer>(callbacks);
        tracer_->set_frame_data_enabled(true);
        install(tracer_.get());
#else
        (void)install;
#endif
    }

#ifdef ASHIATO_GD_WITH_TRACING
    void record_trace(const ashiato::sync::SyncTraceEvent& event) {
        // Oldest goes overboard rather than the newest being dropped: when something is
        // going wrong you want the most recent events, and a count of what was missed is
        // more honest than a queue that silently stops recording.
        if (trace_events_.size() >= kMaxTraceEvents) {
            trace_events_.pop_front();
            ++trace_dropped_;
        }
        Dictionary out;
        out["type"] = trace_type_name(event.type);
        out["role"] = event.role == ashiato::sync::SyncTraceRole::Server ? "server" : "client";
        out["frame"] = static_cast<int64_t>(event.frame);
        out["client"] = static_cast<int64_t>(event.client);
        out["entity"] = static_cast<int64_t>(event.local_entity.value != 0
                                                 ? event.local_entity.value
                                                 : event.server_entity.value);
        out["component"] = String(event.component_name.c_str());
        out["bits"] = static_cast<int64_t>(event.wire_bits);
        out["detail"] = String(event.data.c_str());
        trace_events_.push_back(out);
    }

    static const char* trace_type_name(ashiato::sync::SyncTraceEventType type) {
        using T = ashiato::sync::SyncTraceEventType;
        switch (type) {
            case T::ClientConnected: return "client_connected";
            case T::ClientDisconnected: return "client_disconnected";
            case T::EntityStartedSyncing: return "entity_started_syncing";
            case T::EntityReceived: return "entity_received";
            case T::EntityDestroyed: return "entity_destroyed";
            case T::ComponentSent: return "component_sent";
            case T::ComponentReceived: return "component_received";
            case T::ComponentApplied: return "component_applied";
            case T::ComponentRemoved: return "component_removed";
            case T::ModeChanged: return "mode_changed";
            case T::BufferedStarved: return "buffered_starved";
            case T::PredictionRollbackConflict: return "rollback_conflict";
            case T::RollbackReason: return "rollback_reason";
            case T::InputStarved: return "input_starved";
            case T::FrameComponent: return "frame_component";
            case T::ResimulatedFrameComponent: return "resimulated_frame";
            default: return "other";
        }
    }
#endif

    static constexpr std::size_t kMaxTraceEvents = 4096;

    // Handling, adjustable without a rebuild. Feel is found by driving, and a C++ build
    // per tweak is a miserable loop. Both sides must be set the SAME: the client predicts
    // by running the server's simulation, so different handling means constant
    // corrections.
    // Handling, adjustable without a rebuild. Feel is found by driving, and a C++ build
    // per tweak is a miserable loop. Both sides must be set the SAME: the client predicts
    // by running the server's simulation, so different handling means constant
    // corrections.
    //
    // A Dictionary rather than a fixed argument list because a tire model has more knobs
    // than a torque servo did, and callers should not have to restate the ones they do
    // not care about.
    // A missing key keeps the current value rather than resetting it, so a caller can
    // send one knob without restating the other seventeen.
    static float get(const Dictionary& handling, const char* key, float fallback) {
        return static_cast<float>(handling.get(key, fallback));
    }

    // The car's set, so that every existing caller keeps meaning what it meant.
    void set_handling(Dictionary handling) {
        set_vehicle_handling(kKindCar, handling);
    }

    // One kind's set. Given identically by every peer -- a client whose numbers differ
    // from its server is corrected on every single tick, and it reads as a networking
    // fault rather than a tuning one.
    void set_vehicle_handling(int64_t kind, Dictionary handling) {
        Handling& h = handling_[kind_index(kind)];
        // Steering
        h.max_steer_ = get(handling, "max_steer", h.max_steer_);
        h.steer_falloff_ = get(handling, "steer_speed_falloff", h.steer_falloff_);
        h.steer_reference_speed_ =
            get(handling, "steer_reference_speed", h.steer_reference_speed_);
        // Engine and brakes
        h.engine_hp_ = get(handling, "engine_hp", h.engine_hp_);
        h.drive_force_per_hp_ = get(handling, "drive_force_per_hp", h.drive_force_per_hp_);
        h.brake_force_ = get(handling, "brake_force", h.brake_force_);
        h.brake_bias_front_ = get(handling, "brake_bias_front", h.brake_bias_front_);
        // Tires
        h.cornering_stiffness_ = get(handling, "cornering_stiffness", h.cornering_stiffness_);
        h.grip_ = get(handling, "grip", h.grip_);
        h.grip_speed_loss_ = get(handling, "grip_speed_loss", h.grip_speed_loss_);
        h.grip_reference_speed_ = get(handling, "grip_reference_speed", h.grip_reference_speed_);
        h.rear_grip_bias_ = get(handling, "rear_grip_bias", h.rear_grip_bias_);
        h.rear_grip_bias_fast_ = get(handling, "rear_grip_bias_fast", h.rear_grip_bias_fast_);
        h.load_sensitivity_ = get(handling, "load_sensitivity", h.load_sensitivity_);
        h.handbrake_grip_ = get(handling, "handbrake_grip", h.handbrake_grip_);
        // Chassis
        h.cg_height_ = get(handling, "cg_height", h.cg_height_);
        h.drag_ = get(handling, "drag", h.drag_);
        h.rolling_resistance_ = get(handling, "rolling_resistance", h.rolling_resistance_);
    }

    // Everything set_handling accepts, with the values in force. Two uses: printing the
    // car's whole setup while tuning, and checking that a client and its server actually
    // agree -- handling that differs between the two is corrected on every single tick,
    // and it looks like a networking fault rather than a tuning one.
    Dictionary handling() const {
        return vehicle_handling(kKindCar);
    }

    Dictionary vehicle_handling(int64_t kind) const {
        const Handling& h = handling_[kind_index(kind)];
        Dictionary out;
        out["max_steer"] = h.max_steer_;
        out["steer_speed_falloff"] = h.steer_falloff_;
        out["steer_reference_speed"] = h.steer_reference_speed_;
        out["engine_hp"] = h.engine_hp_;
        out["drive_force_per_hp"] = h.drive_force_per_hp_;
        out["brake_force"] = h.brake_force_;
        out["brake_bias_front"] = h.brake_bias_front_;
        out["cornering_stiffness"] = h.cornering_stiffness_;
        out["grip"] = h.grip_;
        out["grip_speed_loss"] = h.grip_speed_loss_;
        out["grip_reference_speed"] = h.grip_reference_speed_;
        out["rear_grip_bias"] = h.rear_grip_bias_;
        out["rear_grip_bias_fast"] = h.rear_grip_bias_fast_;
        out["load_sensitivity"] = h.load_sensitivity_;
        out["handbrake_grip"] = h.handbrake_grip_;
        out["cg_height"] = h.cg_height_;
        out["drag"] = h.drag_;
        out["rolling_resistance"] = h.rolling_resistance_;
        return out;
    }

    // The steer angle our own front wheels were last given, in radians. Renderers want
    // this rather than raw input: lock tapers with speed, so at 100 km/h the wheels are
    // nowhere near where the key suggests.
    float local_steer_angle() const {
        return local_steer_angle_;
    }

    float engine_hp() const {
        return handling_[kKindCar].engine_hp_;
    }

    // What engine a PARTICULAR car is running. Replicated, so this answers for other
    // players' cars too, which is what lets the figure be drawn over their roof.
    // Every sync client the server currently has, so the game can give each of them a
    // car. Server only -- a client knows about itself and nothing else.
    PackedInt64Array connected_clients() const {
        PackedInt64Array out;
        if (server_ == nullptr) {
            return out;
        }
        for (const auto id : server_->client_ids()) {
            out.push_back(static_cast<int64_t>(id));
        }
        return out;
    }

    // How hard each of a car's tires is working, as a fraction of what it has: at or
    // below 1 it is gripping, above 1 it is sliding. Order is front-left, front-right,
    // rear-left, rear-right.
    //
    // Answers for ANY car, including other players': it is computed from replicated state
    // and the same handling settings every machine runs, not from input. So a client can
    // see that somebody else's back end has stepped out without being told.
    /// How many contact patches this vehicle reports: four for a car, six for a rig
    /// (steer, drive, trailer tandem -- one per axle END, so a dualled tandem is one).
    /// The renderer asks rather than assuming, because assuming four is how skid marks
    /// end up missing from the axle carrying most of the weight.
    int64_t tire_count(int64_t entity_id) const {
        const ashiato::Entity entity{static_cast<std::uint64_t>(entity_id)};
        return chassis_of(entity).articulated_ ? 6 : 4;
    }

    PackedFloat32Array tire_slip(int64_t entity_id) const {
        PackedFloat32Array out;
        const std::size_t tires = static_cast<std::size_t>(tire_count(entity_id));
        const auto found = slip_of_.find(static_cast<std::uint64_t>(entity_id));
        if (found != slip_of_.end()) {
            for (std::size_t i = 0; i < tires; ++i) {
                out.push_back(found->second[i]);
            }
            return out;
        }
        return estimated_tire_slip(entity_id);
    }

    // Slip for a car this machine does not simulate.
    //
    // A client runs the simulation only for cars it predicts, and another player's car is
    // not one of them -- their input is never sent, so there is nothing to simulate it
    // from. Without this their tires would report no slip at all and their car would slide
    // around leaving no marks, which reads as a bug in the marks rather than an absence
    // of data.
    //
    // So it is worked out from the state that IS replicated: where the car is, how fast,
    // and how quickly it is rotating. That is enough to know how fast each contact patch
    // is sliding sideways, which is what slip means. What it cannot know is load transfer
    // or how much of the tire is being spent on braking, so it assumes a car sitting flat
    // -- close enough for something drawn on the floor, and every machine computes the
    // same answer from the same replicated numbers.
    PackedFloat32Array estimated_tire_slip(int64_t entity_id) const {
        PackedFloat32Array out;
        const ashiato::Entity entity{static_cast<std::uint64_t>(entity_id)};
        const auto* state =
            static_cast<const driving::CarState*>(registry_.get(entity, state_component_));
        const std::size_t index = kind_index(kind_of(entity));
        const Chassis& chassis = chassis_[index];
        if (state == nullptr) {
            for (int i = 0; i < (chassis.articulated_ ? 6 : 4); ++i) {
                out.push_back(0.0f);
            }
            return out;
        }
        // The vehicle's own handling, not the car's. This path exists for cars this
        // machine does not simulate, and estimating a 36 tonne rig against a hatchback's
        // grip would paint it sliding permanently.
        const Handling& h = handling_[index];

        const float sin_yaw = std::sin(state->yaw);
        const float cos_yaw = std::cos(state->yaw);
        const float forward_speed = state->vx * sin_yaw + state->vz * cos_yaw;
        const float speed = std::sqrt(state->vx * state->vx + state->vz * state->vz);
        const float grip_now = h.grip_ * (1.0f - h.grip_speed_loss_
            * std::fmin(speed / h.grip_reference_speed_, 1.0f));
        const float load = mass_ * kGravity * 0.25f;

        // The same inversion the renderer uses for their steering angle, and for the same
        // reason: it is the only way to know where their front wheels point.
        float steer = 0.0f;
        if (std::fabs(forward_speed) > 1.0f) {
            steer = std::atan(state->yaw_rate * chassis.wheelbase() / forward_speed);
            steer = std::fmax(-h.max_steer_, std::fmin(h.max_steer_, steer));
        }

        const float offsets[4][2] = {
            {-chassis.wheel_track_, chassis.front_axle_},
            {chassis.wheel_track_, chassis.front_axle_},
            {-chassis.wheel_track_, -chassis.rear_axle_},
            {chassis.wheel_track_, -chassis.rear_axle_}};
        for (int i = 0; i < 4; ++i) {
            // Velocity at the contact patch: the car's own, plus what its rotation adds
            // at that corner.
            const float rx = offsets[i][0] * cos_yaw + offsets[i][1] * sin_yaw;
            const float rz = -offsets[i][0] * sin_yaw + offsets[i][1] * cos_yaw;
            const float vx = state->vx + state->yaw_rate * rz;
            const float vz = state->vz - state->yaw_rate * rx;

            const float tire_yaw = state->yaw + (i < 2 ? steer : 0.0f);
            const float sin_t = std::sin(tire_yaw);
            const float cos_t = std::cos(tire_yaw);
            const float v_long = vx * sin_t + vz * cos_t;
            const float v_lat = vx * cos_t - vz * sin_t;

            const float slip = -std::atan2(v_lat, std::fabs(v_long) + kSlipSoftening);
            const float wanted = std::fabs(h.cornering_stiffness_ * slip);
            out.push_back(wanted / std::fmax(grip_now * load, 1.0f));
        }
        return out;
    }

    // How many times this machine has had to rewind and replay, and how far back the
    // last one went. A steady count with a small span is the system working; a large span,
    // or a count climbing every frame, is the client and server disagreeing constantly.
    Dictionary resim_stats() const {
        Dictionary out;
        out["count"] = static_cast<int64_t>(resim_count_);
        out["last_frame"] = last_resim_frame_;
        out["last_span"] = last_resim_span_;
        return out;
    }

    // How many times a PARTICULAR car has been replayed, so a renderer can show the one
    // that was actually corrected.
    int64_t car_resims(int64_t entity_id) const {
        const auto found = resims_of_.find(static_cast<std::uint64_t>(entity_id));
        return found == resims_of_.end() ? 0 : static_cast<int64_t>(found->second);
    }

    float car_hp(int64_t entity_id) const {
        const ashiato::Entity entity{static_cast<std::uint64_t>(entity_id)};
        const auto* setup =
            static_cast<const driving::CarSetup*>(registry_.get(entity, setup_component_));
        return setup == nullptr ? handling_[kind_index(kind_of(entity))].engine_hp_
                                : setup->hp;
    }

    // The steer angle ANY car's front wheels were last given. Needed to say whether a car
    // is understeering or oversteering, which is a comparison between the turn the wheels
    // asked for and the turn the car actually took -- you cannot judge it from the car's
    // motion alone.
    float steer_angle(int64_t entity_id) const {
        const auto found = steer_of_.find(static_cast<std::uint64_t>(entity_id));
        return found == steer_of_.end() ? 0.0f : found->second;
    }

    // Distance between the axles, so a caller can work out the neutral-steer turn rate
    // (v * tan(steer) / wheelbase) without hardcoding a number that lives in here.
    //
    // The CAR's, because that is what this has always answered. Anything that has to be
    // right for a rig or a buggy asks vehicle_geometry for the kind it is drawing -- a
    // wheelbase is per kind now and there is no single answer to give here.
    float wheelbase() const {
        return chassis_[kKindCar].wheelbase();
    }

    // The car's shape, so the renderer does not have to keep its own copy.
    //
    // It used to: the mesh size, the axle positions and the wheelbase were all written out
    // again in race.gd, "matches the collision box in driving_world.cpp" in a comment. That
    // holds right up until one of them changes -- and then the wheels are drawn somewhere
    // the car does not have any, and the steering angle inferred for other players is
    // computed against a wheelbase the simulation is not using.
    /// The shape of one KIND of vehicle, so the renderer does not keep its own copy.
    /// Same contract as car_geometry, which is now this for a car.
    Dictionary vehicle_geometry(int64_t kind) const {
        const std::size_t index = kind_index(kind);
        const Chassis& chassis = chassis_[index];
        Dictionary out;
        // What this kind is called, and whether it tows. Both are here rather than in a
        // second lookup because this dictionary is already the one thing a renderer asks
        // for per kind, and a renderer deciding what to build needs exactly these.
        out["name"] = String(kVehicleNames[index]);
        out["articulated"] = chassis.articulated_;
        out["size"] = Vector3(chassis.half_width_ * 2.0f, chassis.half_height_ * 2.0f,
                              chassis.half_length_ * 2.0f);
        out["front_axle"] = chassis.front_axle_;
        out["rear_axle"] = chassis.rear_axle_;
        out["wheel_track"] = chassis.wheel_track_;
        out["wheelbase"] = chassis.wheelbase();
        if (!chassis.articulated_) {
            return out;
        }
        // The trailer, and the coupling. A renderer that drew the trailer from its own
        // guess at these would put the wheels somewhere the simulation has none.
        out["trailer_size"] = Vector3(kRigTrailerHalfWidth * 2.0f,
                                      kRigTrailerHalfHeight * 2.0f,
                                      kRigTrailerHalfLength * 2.0f);
        out["fifth_wheel"] = kRigFifthWheel;
        out["plate_height"] = kRigPlateHeight;
        out["kingpin_to_centre"] = kRigTrailerCentre;
        out["kingpin_to_tandem"] = kRigKingpinToTandem;
        out["trailer_wheel_track"] = kRigTrailerWheelTrack;
        out["trailer_rise"] = kRigTrailerRise;
        out["max_fold"] = kRigMaxFold;
        return out;
    }

    Dictionary car_geometry() const {
        return vehicle_geometry(kKindCar);
    }

    /// How many kinds of vehicle this build has, so a menu, a test or a launcher can go
    /// through them all rather than keeping its own copy of the list and quietly missing
    /// whichever one was added last.
    int64_t vehicle_kinds() const {
        return kVehicleKinds;
    }

    /// What one kind is called: "car", "rig", "buggy". The single spelling of the name.
    String vehicle_name(int64_t kind) const {
        return String(kVehicleNames[kind_index(kind)]);
    }

    // Which handling and shape this vehicle uses. Defaults to a car, because a car is
    // what an entity is before its VehicleKind has arrived over the wire -- and drawing
    // one frame of a truck as a car is better than reading a component that is not there.
    std::uint8_t kind_of(ashiato::Entity entity) const {
        const auto* kind = static_cast<const driving::VehicleKind*>(
            registry_.get(entity, kind_component_));
        return kind == nullptr ? kKindCar : kind->kind;
    }

    // The shape this vehicle is built and simulated with.
    const Chassis& chassis_of(ashiato::Entity entity) const {
        return chassis_[kind_index(kind_of(entity))];
    }

    // Never index the handling table with a number off the wire without this. Two bits
    // of VehicleKind can carry a 3 that no build of this game has ever defined.
    static std::size_t kind_index(int64_t kind) {
        return (kind >= 0 && kind < kVehicleKinds) ? static_cast<std::size_t>(kind) : 0u;
    }

    // Is this the car the local player drives? Only meaningful on a client.
    bool is_local_car(ashiato::Entity entity) const {
        if (client_ == nullptr) {
            return false;
        }
        const auto local = client_->client_id();
        if (local == ashiato::sync::invalid_client_id) {
            return false;
        }
        const auto* owner = static_cast<const driving::CarOwner*>(
            registry_.get(entity, owner_component_));
        return owner != nullptr && owner->client == static_cast<std::uint32_t>(local);
    }

    // Predict every car rather than only our own. Must be set BEFORE start(): the
    // replication client reads its options when it is built.
    //
    // Read the warning in racer/world/race.gd before turning this on. Prediction means
    // "run the simulation forward from the last known state", and the simulation needs
    // INPUT -- which for somebody else's car this machine does not have and is never
    // sent. See predicts_without_input in the loopback test for what that costs.
    void set_predict_all(bool predict_all) {
        predict_all_ = predict_all;
    }

    // Turn the sync tracer on or off. Must be set BEFORE start(): the tracer is attached
    // to the replication client or server as it is built.
    //
    // Returns whether tracing is actually available -- it is a build-time capability
    // (ASHIATO_GD_WITH_TRACING), and asking for it in a binary that does not have it
    // should say so rather than silently record nothing.
    bool set_tracing(bool on) {
#ifdef ASHIATO_GD_WITH_TRACING
        tracing_ = on;
        return true;
#else
        (void)on;
        tracing_ = false;
        return false;
#endif
    }

    bool tracing_available() const {
#ifdef ASHIATO_GD_WITH_TRACING
        return true;
#else
        return false;
#endif
    }

    // Drain what the tracer has seen since the last call, oldest first.
    //
    // Drained rather than accumulated, and capped, because this is a stream: a race
    // generates thousands of events a second, and a viewer wants the recent past, not an
    // ever-growing log that eventually eats the process.
    Array take_trace_events() {
        Array out;
        for (auto& event : trace_events_) {
            out.push_back(event);
        }
        trace_events_.clear();
        return out;
    }

    int64_t trace_events_dropped() const {
        return trace_dropped_;
    }

    // Interpolation depth, in ticks behind the server. Must be set BEFORE start().
    // Higher is smoother and more forgiving of jitter; lower is more current.
    void set_interpolation(int buffered_frames, bool automatic) {
        buffered_frames_ = static_cast<ashiato::sync::SyncFrame>(std::max(buffered_frames, 1));
        auto_buffer_ = automatic;
    }

    // Every car sampled at the CURRENT fractional frame, ready to draw.
    //
    // Better than interpolating the last two ECS ticks in the renderer, which is what this
    // replaces. sync samples between BUFFERED frames for interpolated cars and between
    // PREDICTED history frames for your own, so each car is drawn from the timeline that
    // actually applies to it -- and a car whose next frame has not arrived holds its last
    // good sample instead of stuttering.
    Array sampled_cars() {
        Array out;
        // Not before the session is Ready. The sample buffer is built from the buffered
        // and predicted timelines, and asking for it while those are still empty takes
        // the process down with no error at all -- the renderer calls this every frame
        // from the moment the scene loads, which is well before the handshake finishes.
        if (client_ == nullptr
                || client_->connection_state()
                    != ashiato::sync::ReplicationClientConnectionState::Ready) {
            return out;
        }
        const ashiato::sync::FractionalTickSampleBuffer* frame_ptr = nullptr;
        DRIVING_TRY(frame_ptr = &client_->fractional_tick_frame(registry_), return out);
        if (frame_ptr == nullptr) {
            return out;
        }
        for (const auto& sample : frame_ptr->entities) {
            driving::CarState state;
            const bool have_value =
                sample.try_get_sampled_value<driving::CarState>(registry_, state);
            Dictionary car;
            car["sampled"] = have_value;
            car["entity"] = static_cast<int64_t>(sample.local_entity.value);
            car["position"] = Vector3(state.x, state.y, state.z);
            car["yaw"] = state.yaw;
            car["velocity"] = Vector3(state.vx, state.vy, state.vz);
            // predicted / buffered / live, so the renderer (and the HUD) can tell which
            // timeline a car is being drawn from.
            // The fold at the SAME fractional tick as the pose above it. This is the
            // whole reason RigState is fractional-tick sampled: a renderer that drew the
            // cab from here and the trailer from the live ECS would be drawing two
            // different instants, and the kingpin would visibly come apart -- which is
            // the failure deriving the trailer was supposed to make impossible.
            driving::RigState rig;
            car["folded"] =
                sample.try_get_sampled_value<driving::RigState>(registry_, rig);
            car["hitch_yaw"] = rig.hitch_yaw;
            car["hitch_rate"] = rig.hitch_rate;
            car["predicted"] = sample.mode == ashiato::sync::ReplicationClientMode::Predict;
            car["alpha"] = sample.alpha;
            car["frame"] = static_cast<int64_t>(sample.frame);
            out.push_back(car);
        }
        return out;
    }

    // What the timing actually looks like, so the latency-for-smoothness trade can be
    // seen rather than guessed at.
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
        out["time_dilation"] = stats.buffered_time_dilation;
        out["packets_received"] = static_cast<int64_t>(stats.server_update_packets_received);
        out["packets_missing"] = static_cast<int64_t>(stats.server_update_packets_missing);
        InputPacketCounters::describe(*client_, out);
        out["sampling_marked"] = sampling_marked_;
        return out;
    }

    // Tell sync which car is ours, in ITS vocabulary.
    //
    // sync routes the local player's input with
    //
    //     registry.view<const NetworkOwner>().each(... if (owner.client == local_client))
    //
    // and it never writes NetworkOwner on a client -- the whole client tree only ever
    // READS it. So a replicated car arrives carrying our CarOwner but no NetworkOwner,
    // sync finds no locally owned entity, and set_input() applies to nothing at all: the
    // predicted car never sees the wheel. Ownership is only known once the entity and the
    // client id have both arrived, which is why this is reconciled every tick rather than
    // set at spawn.
    void adopt_local_cars() {
        if (client_ == nullptr) {
            return;
        }
        const auto local = client_->client_id();
        if (local == ashiato::sync::invalid_client_id) {
            return;
        }
        registry_.view<const driving::CarOwner>().each(
            [&](ashiato::Entity entity, const driving::CarOwner& owner) {
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

    void tick(double dt) {
        // Entities whose Replicated component was removed last tick. Destroying them in
        // the same breath as the removal loses the removal: the dirty frame that carries
        // it is broadcast during the NEXT tick, and a dead entity has nothing left to
        // report. One tick of a car nobody can see is a cheap price for clients actually
        // being told it went.
        if (!pending_destroy_.empty() && is_server_) {
            for (const ashiato::Entity entity : pending_destroy_) {
                if (registry_.alive(entity)) {
                    registry_.destroy(entity);
                }
            }
            pending_destroy_.clear();
        }
        if (server_) {
            DRIVING_TRY(server_->tick(registry_, dt), return);
        } else if (client_) {
            DRIVING_TRY(adopt_local_cars(), return);
            DRIVING_TRY(client_->tick(registry_, dt), return);
        }
    }

    // ---- transport, owned by the caller ----

    // Packets waiting to go out, as [{ "peer": int, "bytes": PackedByteArray }, ...].
    // Drained by the caller, which decides whether that means a loopback array in a test
    // or a SteamMultiplayerPeer in the game.
    Array take_outbound() {
        Array out;
        for (auto& entry : outbound_) {
            Dictionary packet;
            packet["peer"] = entry.peer;
            packet["bytes"] = entry.bytes;
            // Carried with the payload because the transport has to hand it back; see
            // deliver().
            packet["bits"] = entry.bit_size;
            out.push_back(packet);
        }
        outbound_.clear();
        return out;
    }

    // bit_size is NOT optional. A BitBuffer is bit-addressed, and its last byte is
    // usually partial; rebuilding one from bytes alone leaves the reader believing there
    // are up to 7 bits of real data past the end of the packet, which it then decodes as
    // garbage. That read runs off the end and takes the process with it -- silently, with
    // no Godot error, which is exactly how this was found.
    void deliver(int64_t from_peer, const PackedByteArray& bytes, int64_t bit_size) {
        std::vector<std::uint8_t> raw(static_cast<std::size_t>(bytes.size()));
        if (!raw.empty()) {
            std::memcpy(raw.data(), bytes.ptr(), raw.size());
        }
        ashiato::BitBuffer buffer;
        buffer.assign_bytes(std::move(raw), static_cast<std::size_t>(bit_size));
        if (server_) {
            DRIVING_TRY(server_->receive_packet(
                            static_cast<ashiato::sync::PeerId>(from_peer), std::move(buffer)),
                        return);
        } else if (client_) {
            DRIVING_TRY(client_->receive(registry_, std::move(buffer)), return);
        }
    }

    // ---- reading state back ----

    /// What kind of vehicle this entity is, for a renderer deciding what to build.
    ///
    /// Put through kind_index on the way out, so this only ever answers with a kind this
    /// build actually has. VehicleKind is two bits and four kinds fit in it, so a packet
    /// can carry a 3 that nothing here defines -- and a renderer that indexes its own
    /// per-kind tables with the raw number would read off the end of them on a malformed
    /// or newer-version update. Clamping is the same policy the handling and chassis
    /// tables already use for the same value.
    int64_t vehicle_kind(int64_t entity_id) const {
        const ashiato::Entity entity{static_cast<std::uint64_t>(entity_id)};
        return static_cast<int64_t>(kind_index(kind_of(entity)));
    }

    /// Where the trailer is, derived from the cab and the fold exactly as the simulation
    /// derives it.
    ///
    /// DERIVED HERE TOO, on purpose, rather than read out of the Box3D body. The body is
    /// a local object that only exists on machines simulating this vehicle -- an
    /// interpolated rig on somebody else's screen has no trailer body at all, and its
    /// trailer still has to be drawn. Doing the same arithmetic in both places means
    /// there is one definition of where a trailer is, and it is this one.
    Dictionary trailer_state(int64_t entity_id) {
        Dictionary out;
        const ashiato::Entity entity{static_cast<std::uint64_t>(entity_id)};
        const auto* state =
            static_cast<const driving::CarState*>(registry_.get(entity, state_component_));
        if (state == nullptr || !chassis_of(entity).articulated_) {
            return out;
        }
        const auto* rig =
            static_cast<const driving::RigState*>(registry_.get(entity, rig_component_));
        const float fold = rig != nullptr ? rig->hitch_yaw : 0.0f;
        out = trailer_pose(state->x, state->y, state->z, state->yaw, fold);
        out["hitch_yaw"] = fold;
        out["hitch_rate"] = rig != nullptr ? rig->hitch_rate : 0.0f;
        return out;
    }

    /// The one piece of trailer arithmetic, shared by the simulation, by trailer_state,
    /// and by anything drawing a sampled rig.
    Dictionary trailer_pose(float x, float y, float z, float yaw, float fold) const {
        const float trailer_yaw = yaw + fold;
        const float kingpin_x = x + kRigFifthWheel * std::sin(yaw);
        const float kingpin_z = z + kRigFifthWheel * std::cos(yaw);
        Dictionary out;
        out["position"] = Vector3(kingpin_x - kRigTrailerCentre * std::sin(trailer_yaw),
                                  y + kRigTrailerRise,
                                  kingpin_z - kRigTrailerCentre * std::cos(trailer_yaw));
        out["yaw"] = trailer_yaw;
        out["kingpin"] = Vector3(kingpin_x, y + (kRigPlateHeight - kRigCabHalfHeight),
                                 kingpin_z);
        return out;
    }

    Dictionary car_state(int64_t entity_id) {
        Dictionary out;
        const ashiato::Entity entity{static_cast<std::uint64_t>(entity_id)};
        const auto* state = static_cast<const driving::CarState*>(
            registry_.get(entity, state_component_));
        if (state == nullptr) {
            return out;
        }
        out["position"] = Vector3(state->x, state->y, state->z);
        out["yaw"] = state->yaw;
        out["velocity"] = Vector3(state->vx, state->vy, state->vz);
        out["yaw_rate"] = state->yaw_rate;
        return out;
    }

    // What the connection is actually doing. Without this, "the client sees no cars" is
    // indistinguishable from "the client never connected", which is a bad place to debug
    // from -- and was, until this existed.
    Dictionary net_status() const {
        Dictionary out;
        out["is_server"] = is_server_;
        if (server_ != nullptr) {
            out["clients"] = static_cast<int64_t>(server_->client_count());
            out["replicated"] = static_cast<int64_t>(server_->replicated_count());
        } else if (client_ != nullptr) {
            // The SERVER assigns the client id; whatever we asked for is only a request,
            // so the mode selector has to compare against the assigned one.
            out["client_id"] = static_cast<int64_t>(client_->client_id());
            // Ready, not Accepted: Accepted only means the server said yes, while Ready
            // means the session is actually carrying frames.
            out["connected"] = client_->connection_state()
                == ashiato::sync::ReplicationClientConnectionState::Ready;
            out["state"] = static_cast<int64_t>(client_->connection_state());
        }
        return out;
    }

    // Every car this peer knows about, simulated or merely interpolated. Reads the ECS
    // rather than the physics-body map: a client holds bodies only for cars it predicts,
    // but it still has to render everyone else's.
    PackedInt64Array car_entities() {
        PackedInt64Array out;
        registry_.view<const driving::CarState>().each(
            [&out](ashiato::Entity entity, const driving::CarState&) {
                out.push_back(static_cast<int64_t>(entity.value));
            });
        return out;
    }

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("start", "client_id"), &DrivingWorld::start);
        ClassDB::bind_method(D_METHOD("teardown"), &DrivingWorld::teardown);
        ClassDB::bind_method(D_METHOD("is_server"), &DrivingWorld::is_server);
        ClassDB::bind_method(
            D_METHOD("spawn_vehicle", "owner_client", "position", "yaw", "kind"),
            &DrivingWorld::spawn_vehicle);
        ClassDB::bind_method(D_METHOD("set_vehicle_handling", "kind", "handling"),
                             &DrivingWorld::set_vehicle_handling);
        ClassDB::bind_method(D_METHOD("vehicle_handling", "kind"),
                             &DrivingWorld::vehicle_handling);
        ClassDB::bind_method(D_METHOD("vehicle_geometry", "kind"),
                             &DrivingWorld::vehicle_geometry);
        ClassDB::bind_method(D_METHOD("vehicle_kinds"), &DrivingWorld::vehicle_kinds);
        ClassDB::bind_method(D_METHOD("vehicle_name", "kind"),
                             &DrivingWorld::vehicle_name);
        ClassDB::bind_method(D_METHOD("vehicle_kind", "entity"), &DrivingWorld::vehicle_kind);
        ClassDB::bind_method(D_METHOD("tire_count", "entity"), &DrivingWorld::tire_count);
        ClassDB::bind_method(D_METHOD("trailer_state", "entity"),
                             &DrivingWorld::trailer_state);
        // Bound because a renderer drawing an INTERPOLATED rig has a sampled cab pose and
        // a sampled fold in hand and no trailer body to read -- so it needs the same
        // arithmetic the simulation uses, rather than a second copy of it in GDScript.
        ClassDB::bind_method(D_METHOD("trailer_pose", "x", "y", "z", "yaw", "fold"),
                             &DrivingWorld::trailer_pose);
        ClassDB::bind_method(D_METHOD("spawn_car", "owner_client", "position", "yaw"),
                             &DrivingWorld::spawn_car, DEFVAL(0.0f));
        ClassDB::bind_method(D_METHOD("add_client", "client_id"), &DrivingWorld::add_client);
        ClassDB::bind_method(
            D_METHOD("set_input", "throttle", "steer", "handbrake", "hp_step"),
            &DrivingWorld::set_input, DEFVAL(0));
        ClassDB::bind_method(
            D_METHOD("set_car_input", "entity", "throttle", "steer", "handbrake"),
            &DrivingWorld::set_car_input);
        ClassDB::bind_method(D_METHOD("tick", "dt"), &DrivingWorld::tick);
        ClassDB::bind_method(D_METHOD("take_outbound"), &DrivingWorld::take_outbound);
        ClassDB::bind_method(D_METHOD("deliver", "from_peer", "bytes", "bits"),
                             &DrivingWorld::deliver);
        ClassDB::bind_method(D_METHOD("car_state", "entity"), &DrivingWorld::car_state);
        ClassDB::bind_method(D_METHOD("car_entities"), &DrivingWorld::car_entities);
        ClassDB::bind_method(D_METHOD("net_status"), &DrivingWorld::net_status);
        ClassDB::bind_method(D_METHOD("add_track_box", "position", "half_extents"),
                             &DrivingWorld::add_track_box);
        ClassDB::bind_method(D_METHOD("car_owner", "entity"), &DrivingWorld::car_owner);
        ClassDB::bind_method(D_METHOD("local_client_id"), &DrivingWorld::local_client_id);
        ClassDB::bind_method(D_METHOD("set_handling", "handling"),
                             &DrivingWorld::set_handling);
        ClassDB::bind_method(D_METHOD("handling"), &DrivingWorld::handling);
        ClassDB::bind_method(D_METHOD("local_steer_angle"),
                             &DrivingWorld::local_steer_angle);
        ClassDB::bind_method(D_METHOD("engine_hp"), &DrivingWorld::engine_hp);
        ClassDB::bind_method(D_METHOD("car_hp", "entity"), &DrivingWorld::car_hp);
        ClassDB::bind_method(D_METHOD("tire_slip", "entity"), &DrivingWorld::tire_slip);
        ClassDB::bind_method(D_METHOD("resim_stats"), &DrivingWorld::resim_stats);
        ClassDB::bind_method(D_METHOD("car_resims", "entity"), &DrivingWorld::car_resims);
        ClassDB::bind_method(D_METHOD("connected_clients"),
                             &DrivingWorld::connected_clients);
        ClassDB::bind_method(D_METHOD("despawn_car", "entity"), &DrivingWorld::despawn_car);
        ClassDB::bind_method(D_METHOD("remove_client", "client_id"),
                             &DrivingWorld::remove_client);
        ClassDB::bind_method(D_METHOD("steer_angle", "entity"), &DrivingWorld::steer_angle);
        ClassDB::bind_method(D_METHOD("wheelbase"), &DrivingWorld::wheelbase);
        ClassDB::bind_method(D_METHOD("car_geometry"), &DrivingWorld::car_geometry);
        ClassDB::bind_method(D_METHOD("set_predict_all", "predict_all"),
                             &DrivingWorld::set_predict_all);
        ClassDB::bind_method(D_METHOD("set_tracing", "on"), &DrivingWorld::set_tracing);
        ClassDB::bind_method(D_METHOD("tracing_available"),
                             &DrivingWorld::tracing_available);
        ClassDB::bind_method(D_METHOD("take_trace_events"),
                             &DrivingWorld::take_trace_events);
        ClassDB::bind_method(D_METHOD("trace_events_dropped"),
                             &DrivingWorld::trace_events_dropped);
        ClassDB::bind_method(D_METHOD("set_interpolation", "buffered_frames", "automatic"),
                             &DrivingWorld::set_interpolation);
        ClassDB::bind_method(D_METHOD("sampled_cars"), &DrivingWorld::sampled_cars);
        ClassDB::bind_method(D_METHOD("timing"), &DrivingWorld::timing);
    }

private:
    void queue_outbound(int64_t peer, const ashiato::BitBuffer& packet) {
        PackedByteArray bytes;
        const std::vector<std::uint8_t>& raw = packet.bytes();
        const std::size_t size = packet.byte_size();
        bytes.resize(static_cast<int64_t>(size));
        if (size > 0) {
            std::memcpy(bytes.ptrw(), raw.data(), size);
        }
        outbound_.push_back(Outbound{peer, std::move(bytes),
                                     static_cast<int64_t>(packet.bit_size())});
    }

    void build_ground() {
        b3BodyDef def = b3DefaultBodyDef();
        def.type = b3_staticBody;
        def.position = b3Pos{0.0f, -1.0f, 0.0f};
        const b3BodyId ground = b3CreateBody(physics_, &def);
        b3BoxHull hull = b3MakeBoxHull(400.0f, 1.0f, 400.0f);
        b3ShapeDef shape = b3DefaultShapeDef();
        b3CreateHullShape(ground, &shape, &hull.base);
    }

    /// Drop a vehicle's bodies. The joint goes FIRST: Box3D holds it in both bodies'
    /// joint lists, and destroying a body that still has one attached leaves the world
    /// with a joint pointing at nothing.
    void release_bodies(ashiato::Entity entity) {
        const auto joint = fifth_wheels_.find(entity.value);
        if (joint != fifth_wheels_.end()) {
            b3DestroyJoint(joint->second, false);
            fifth_wheels_.erase(joint);
        }
        const auto trailer = trailers_.find(entity.value);
        if (trailer != trailers_.end()) {
            b3DestroyBody(trailer->second);
            trailers_.erase(trailer);
        }
        const auto body = bodies_.find(entity.value);
        if (body != bodies_.end()) {
            b3DestroyBody(body->second);
            bodies_.erase(body);
        }
    }

    b3BodyId ensure_body(ashiato::Entity entity) {
        const auto found = bodies_.find(entity.value);
        if (found != bodies_.end()) {
            return found->second;
        }
        b3BodyDef def = b3DefaultBodyDef();
        def.type = b3_dynamicBody;
        def.position = b3Pos{0.0f, 0.5f, 0.0f};
        // Never sleep: a sleeping body stops integrating, so a rollback that re-steps it
        // would take a different path than the original run.
        def.enableSleep = false;
        const b3BodyId body = b3CreateBody(physics_, &def);
        const Chassis& chassis = chassis_of(entity);
        b3BoxHull hull = b3MakeBoxHull(chassis.half_width_, chassis.half_height_,
                                       chassis.half_length_);
        b3ShapeDef shape = b3DefaultShapeDef();
        shape.density = chassis.density_;
        // FRICTIONLESS against the ground, which sounds wrong and is not.
        //
        // A car rolls on wheels; this box slides on its belly. Every force that should
        // resist the car now comes from the four tires -- grip, drive, braking, drag --
        // so contact friction here is a second, unwanted copy of all of it, applied at
        // the wrong place (the contact patch under the middle of the car, where it can
        // only resist yaw, never cause it). It measured 1.8 kN of pure parasitic drag,
        // a third of the engine.
        shape.baseMaterial.friction = 0.0f;
        b3CreateHullShape(body, &shape, &hull.base);
        bodies_[entity.value] = body;
        if (chassis.articulated_) {
            build_trailer(entity, body);
        }
        return body;
    }

    /// The trailer, and the fifth wheel that is the entire character of the vehicle.
    ///
    /// Two real bodies with a real joint, not a trailer drawn to follow. The two failures
    /// that make a truck a truck -- tractor jackknife when the drive axle lets go, and
    /// trailer swing when the trailer's does -- are the articulation angle running away
    /// under forces the two units put on each other. Nothing that merely draws a trailer
    /// behind a cab can produce either, and a rig that cannot jackknife is a bus.
    void build_trailer(ashiato::Entity entity, b3BodyId cab) {
        b3BodyDef def = b3DefaultBodyDef();
        def.type = b3_dynamicBody;
        // Placed roughly; the first push_to_physics puts it exactly where the fold says.
        def.position = b3Pos{0.0f, 0.5f, -kRigTrailerCentre};
        def.enableSleep = false;
        const b3BodyId trailer = b3CreateBody(physics_, &def);
        b3BoxHull hull = b3MakeBoxHull(kRigTrailerHalfWidth, kRigTrailerHalfHeight,
                                       kRigTrailerHalfLength);
        b3ShapeDef shape = b3DefaultShapeDef();
        shape.density = kRigTrailerDensity;
        // Frictionless against the ground for the same reason the cab is: this box
        // slides on its belly, and every force that should resist it comes from tires.
        shape.baseMaterial.friction = 0.0f;
        b3CreateHullShape(trailer, &shape, &hull.base);
        trailers_[entity.value] = trailer;

        b3RevoluteJointDef joint = b3DefaultRevoluteJointDef();
        joint.base.bodyIdA = cab;
        joint.base.bodyIdB = trailer;
        // The hinge axis is the local frame's Z, and this world is Y-up -- so both frames
        // are turned -90 degrees about X to stand the axis upright. Get this wrong and
        // the rig hinges about the direction of travel: the trailer rolls over instead of
        // following, which is a spectacular and completely silent failure.
        const b3Quat upright{b3Vec3{-0.70710678f, 0.0f, 0.0f}, 0.70710678f};
        // On the cab: the fifth wheel plate, over the drive tandem. On the trailer: the
        // kingpin, near its nose. These two points are the SAME point in the world
        // whenever the joint is satisfied, which is precisely the fact the replication
        // relies on to rebuild the trailer from an angle.
        joint.base.localFrameA = b3Transform{
            b3Pos{0.0f, kRigPlateHeight - kRigCabHalfHeight, kRigFifthWheel}, upright};
        joint.base.localFrameB = b3Transform{
            b3Pos{0.0f, kRigPlateHeight - kRigTrailerHalfHeight, kRigTrailerCentre},
            upright};
        // The cab and the trailer must not collide with each other. They overlap by
        // design at the plate, and letting them touch means the contact solver and the
        // joint fight over the same pair every step.
        joint.base.collideConnected = false;
        // Metal on metal at about 75 degrees, where the trailer nose reaches the cab.
        // Without this the solver folds the trailer clean through the tractor and the rig
        // turns itself inside out.
        joint.enableLimit = true;
        joint.lowerAngle = -kRigMaxFold;
        joint.upperAngle = kRigMaxFold;
        // No motor and no spring. A fifth wheel is a bearing: it does not centre itself,
        // and a rig only straightens because the trailer's tires drag it straight. A
        // centring spring here would hide every handling problem the vehicle has.
        joint.enableSpring = false;
        joint.enableMotor = false;
        fifth_wheels_[entity.value] = b3CreateRevoluteJoint(physics_, &joint);
    }

    // The simulation, as jobs sync can REPLAY, in two halves around ONE world step.
    //
    // The step used to live inside a single per-car job, which meant the Box3D world was
    // advanced once PER CAR: N times the physics work, and -- worse -- the car the job
    // happened to visit first was simulated against neighbours still sitting at last
    // tick's positions. A symmetric head-on collision drifted 3 m off centre because of
    // it, which in a racing game is an unfairness, not a rounding error.
    //
    // So: every car pushes its state and forces in (order -1), the world steps ONCE, and
    // every car reads its result back (order 0). Both halves are simulation jobs, because
    // rollback replays them and the physics has to advance exactly once per replayed
    // frame too.
    void register_simulation_jobs() {
        auto push = [this](ashiato::Entity entity, driving::CarState& state,
                           const driving::CarInput& input, driving::CarSetup& setup) {
            // A power change is applied ONLY by the server, even though this same body
            // runs on the client to predict. The client would otherwise apply the step
            // once when the key is pressed and then again on every rollback that replays
            // that frame, walking its own engine away from the server's. It learns the
            // new figure the same way everyone else does: replication.
            if (is_server_ && input.hp_step != 0) {
                const Handling& limits = handling_[kind_index(kind_of(entity))];
                setup.hp = std::fmax(limits.min_hp_, std::fmin(limits.max_hp_,
                    setup.hp + static_cast<float>(input.hp_step) * kHpStep));
            }
            push_to_physics(entity, state, input, setup.hp);
        };
        auto read = [this](ashiato::Entity entity, driving::CarState& state,
                           const driving::CarInput&, const driving::CarSetup&) {
            read_from_physics(entity, state);
        };

        if (client_) {
            client_->simulation_job<driving::CarState, const driving::CarInput,
                                    driving::CarSetup>(registry_, -1)
                .single_thread().each(push);
            client_->simulation_job<driving::CarState, const driving::CarInput,
                                    const driving::CarSetup>(registry_, 0)
                .single_thread().each(read);
        } else {
            // The server runs the identical bodies as plain jobs: it is authoritative and
            // never resimulates, but the two MUST compute the same thing or the client is
            // corrected every frame.
            registry_.job<driving::CarState, const driving::CarInput, driving::CarSetup>(-1)
                .single_thread().each(push);
            registry_.job<driving::CarState, const driving::CarInput,
                          const driving::CarSetup>(0)
                .single_thread().each(read);
        }
    }

    /// Put the car where the ECS says it is, then ask the engine for this tick's forces.
    /// On a replay the state is the rewound value, which is how the physics gets rewound
    /// along with it.
    // One tire: works out how fast its own contact patch is sliding, turns that into a
    // force, and applies it AT THE TIRE. Applying it at the tire rather than at the centre
    // of mass is the whole point -- yaw then falls out of where the grip is, which is what
    // makes the car rotate about its rear axle instead of pivoting like a boat.
    /// `nominal` is what this tire carries standing still and `share` is the fraction of
    /// the vehicle's mass it is responsible for settling. Both used to be "a quarter",
    /// which was true of every vehicle in the game right up until one of them had six
    /// tires and carried three quarters of its weight on two of them.
    void apply_tire(b3BodyId body, int tire, const b3Vec3& offset, float steer, float load,
                    float longitudinal, float grip, float nominal, float share) {
        const b3Vec3 velocity = b3Body_GetLocalPointVelocity(body, offset);

        // The tire's own heading: the car's, plus its steer angle. Rear tires pass 0.
        const float tire_yaw = current_yaw_ + steer;
        const float sin_t = std::sin(tire_yaw);
        const float cos_t = std::cos(tire_yaw);
        const b3Vec3 forward{sin_t, 0.0f, cos_t};
        const b3Vec3 lateral{cos_t, 0.0f, -sin_t};

        const float v_long = velocity.x * forward.x + velocity.z * forward.z;
        const float v_lat = velocity.x * lateral.x + velocity.z * lateral.z;

        // Slip angle, and the force that opposes it. Linear in the slip angle, which is
        // true of a real tire up to a few degrees and is the standard game approximation
        // (Monster); the friction circle below supplies the saturation past that.
        const float slip = -std::atan2(v_lat, std::fabs(v_long) + kSlipSoftening);
        float lat_force = hv_->cornering_stiffness_ * slip;

        // Never let a tire push back harder than it would take to stop the sliding this
        // step. Without this the force overshoots at low speed, reverses next tick, and
        // the car buzzes in place.
        // How much this tire's mu is worth at the load it is carrying right now.
        const float load_factor = std::fmax(
            0.70f, std::fmin(1.30f, 1.0f - hv_->load_sensitivity_ * (load / nominal - 1.0f)));

        const float settle = std::fabs(v_lat) * (mass_ * share) / kFixedDt;
        // `grip` is this tire's SIDEWAYS hold, which is not the same as its total
        // capability: a locked rear wheel still stops the car hard while barely resisting
        // sideways at all. The friction circle below therefore keeps using the tire's full
        // grip, and this limit expresses the difference between the two.
        const float limit = std::fmin(grip * load_factor * load, settle);
        lat_force = std::fmax(-limit, std::fmin(limit, lat_force));

        // Friction circle: one contact patch has one budget to spend on cornering and
        // driving together, which is why you cannot brake and turn at full effort.
        float long_force = longitudinal;
        const float budget = grip_now_ * load_factor * load;
        const float total = std::sqrt(long_force * long_force + lat_force * lat_force);
        if (total > budget && total > 0.0f) {
            const float scale = budget / total;
            long_force *= scale;
            lat_force *= scale;
        }

        // How hard this tire is being asked to work, as a fraction of what it has. Above
        // 1 it is sliding rather than gripping -- it is being asked for more than the
        // rubber can give, and the clamps above just took the difference away.
        //
        // Both limits count. A tire can slide because it is cornering harder than it can
        // hold (the lateral limit) or because braking and cornering together exceed the
        // one budget they share (the friction circle), and a locked front wheel washing
        // wide is as worth seeing as a rear stepping out.
        const float wanted_lateral = std::fabs(hv_->cornering_stiffness_ * slip);
        const float have_lateral = std::fmax(grip * load_factor * load, 1.0f);
        slip_of_[current_entity_][static_cast<std::size_t>(tire)] =
            std::fmax(wanted_lateral / have_lateral, total / std::fmax(budget, 1.0f));

        const b3Pos point = b3Body_GetWorldPoint(body, offset);
        b3Body_ApplyForce(body,
                          b3Vec3{forward.x * long_force + lateral.x * lat_force, 0.0f,
                                 forward.z * long_force + lateral.z * lat_force},
                          point, true);
    }

    /// A whole articulated rig, cab and trailer, put into the world from the cab's pose
    /// and one angle.
    ///
    /// The trailer is PLACED, not solved for. Given the cab and the fold, the trailer's
    /// pose is arithmetic: the kingpin is a fixed point on both bodies, so there is only
    /// one place the trailer can be. Its velocity is arithmetic too -- the kingpin has
    /// one velocity, shared, so the cab's motion plus the fold rate determines the
    /// trailer's linear and angular velocity completely.
    ///
    /// That is what makes the joint cheap and the replication exact. The solver is handed
    /// a constraint that is ALREADY satisfied to the last bit and only has to keep it
    /// that way through one step; and a rollback that restores the cab and the fold has
    /// restored the trailer too, with nothing left over to drift.
    void push_rig(ashiato::Entity entity, driving::CarState& state,
                  const driving::CarInput& input, float hp, b3BodyId cab) {
        const auto found = trailers_.find(entity.value);
        if (found == trailers_.end()) {
            return;
        }
        const b3BodyId trailer = found->second;
        const auto* rig = static_cast<const driving::RigState*>(
            registry_.get(entity, rig_component_));
        const float fold = rig != nullptr ? rig->hitch_yaw : 0.0f;
        const float fold_rate = rig != nullptr ? rig->hitch_rate : 0.0f;

        const float sin_yaw = std::sin(state.yaw);
        const float cos_yaw = std::cos(state.yaw);
        const float trailer_yaw = state.yaw + fold;
        const float sin_t = std::sin(trailer_yaw);
        const float cos_t = std::cos(trailer_yaw);

        // ---- where the trailer is, exactly ----
        const float kingpin_x = state.x + kRigFifthWheel * sin_yaw;
        const float kingpin_z = state.z + kRigFifthWheel * cos_yaw;
        const float trailer_x = kingpin_x - kRigTrailerCentre * sin_t;
        const float trailer_y = state.y + kRigTrailerRise;
        const float trailer_z = kingpin_z - kRigTrailerCentre * cos_t;
        const float half_t = trailer_yaw * 0.5f;
        b3Body_SetTransform(trailer, b3Pos{trailer_x, trailer_y, trailer_z},
                            b3Quat{b3Vec3{0.0f, std::sin(half_t), 0.0f}, std::cos(half_t)});

        // ---- and how fast it is going, exactly ----
        //
        // w x r for a yaw-only w = (0, w, 0) is (w*r.z, 0, -w*r.x). Written out rather
        // than called, because it is two multiplies and the general form hides which
        // components can possibly be non-zero.
        const float w_cab = state.yaw_rate;
        const float w_trailer = state.yaw_rate + fold_rate;
        const float rx = kingpin_x - state.x;
        const float rz = kingpin_z - state.z;
        const float kingpin_vx = state.vx + w_cab * rz;
        const float kingpin_vz = state.vz - w_cab * rx;
        const float r2x = trailer_x - kingpin_x;
        const float r2z = trailer_z - kingpin_z;
        b3Body_SetLinearVelocity(trailer, b3Vec3{kingpin_vx + w_trailer * r2z,
                                                 state.vy,
                                                 kingpin_vz - w_trailer * r2x});
        b3Body_SetAngularVelocity(trailer, b3Vec3{0.0f, w_trailer, 0.0f});

        // ---- what the driver is asking for ----
        const float cab_mass = b3Body_GetMass(cab);
        const float trailer_mass = b3Body_GetMass(trailer);
        const float total_mass = cab_mass + trailer_mass;
        const float speed = std::sqrt(state.vx * state.vx + state.vz * state.vz);
        const float forward_speed = state.vx * sin_yaw + state.vz * cos_yaw;

        const float taper =
            1.0f - hv_->steer_falloff_
                * std::fmin(speed / hv_->steer_reference_speed_, 1.0f);
        const float grip_factor = std::fmin(speed / hv_->grip_reference_speed_, 1.0f);
        grip_now_ = hv_->grip_ * (1.0f - hv_->grip_speed_loss_ * grip_factor);
        const float drive_bias =
            hv_->rear_grip_bias_
            + (hv_->rear_grip_bias_fast_ - hv_->rear_grip_bias_) * grip_factor;
        const float steer = -input.steer * hv_->max_steer_ * taper;
        steer_of_[entity.value] = steer;
        if (is_local_car(entity)) {
            local_steer_angle_ = steer;
        }

        const float drive_total =
            std::fmin(hp * hv_->drive_force_per_hp_,
                      hp * kWattsPerHp / std::fmax(std::fabs(forward_speed), 0.1f));
        float drive = 0.0f;
        float brake_total = 0.0f;
        if (input.throttle > 0.0f) {
            if (forward_speed < -0.5f) {
                brake_total = input.throttle * hv_->brake_force_;
            } else {
                drive = input.throttle * drive_total * 0.5f;
            }
        } else if (input.throttle < 0.0f) {
            if (forward_speed > 0.5f) {
                brake_total = input.throttle * hv_->brake_force_;
            } else {
                drive = input.throttle * drive_total * kReverseFraction * 0.5f;
            }
        }

        // ---- what each axle is carrying ----
        const float trailer_weight = trailer_mass * kGravity;
        const float kingpin_load = trailer_weight * kRigKingpinShare;
        const float tandem_load = trailer_weight * kRigTandemShare;
        const float cab_weight = cab_mass * kGravity;
        float drive_load =
            cab_weight * kRigDriveOwnShare + kingpin_load * kRigDriveKingpinShare;
        float steer_load = (cab_weight + kingpin_load) - drive_load;

        // Longitudinal transfer, across the CAB's wheelbase only. That is deliberate: the
        // transfer that matters on a rig is the one that unloads the drive axle under
        // braking, because a light drive axle is how a tractor jackknifes. The trailer's
        // own pitch goes into its kingpin load rather than being modelled separately.
        const float long_accel = (drive * 2.0f + brake_total) / total_mass;
        const float shift = std::fmax(-0.35f, std::fmin(0.35f,
            long_accel * hv_->cg_height_ / (kRigCabWheelbase * kGravity)));
        const float moved = (steer_load + drive_load) * shift;
        steer_load = std::fmax(1000.0f, steer_load - moved);
        drive_load = std::fmax(1000.0f, drive_load + moved);

        // Brakes by load share, which is what a load-sensing air system actually does,
        // nudged front-to-rear by brake_bias_front. All five axles brake; a truck that
        // braked only on the tractor would jackknife at every set of lights.
        const float all_load = std::fmax(steer_load + drive_load + tandem_load, 1.0f);
        const float steer_brake =
            brake_total * (steer_load / all_load) * hv_->brake_bias_front_;
        const float drive_brake =
            brake_total * (drive_load / all_load) * (1.0f - hv_->brake_bias_front_);
        float tandem_brake = brake_total * (tandem_load / all_load) * 0.5f;

        // The handbrake is the TRAILER brake hand valve, not a car's rear-wheel lever.
        // Applying trailer brakes on their own is exactly how a real driver induces
        // trailer swing -- and, unlike a car's handbrake, it does nothing whatever for
        // rotating the vehicle on purpose. It is here because the failure is worth being
        // able to see, which is the same reason the predict-every-car switch survives.
        const bool handbrake = input.handbrake != 0;
        float tandem_grip = grip_now_;
        if (handbrake) {
            tandem_grip = grip_now_ * hv_->handbrake_grip_;
            tandem_brake += -forward_speed * hv_->brake_force_ * 0.15f;
        }

        // ---- six tires ----
        //
        // One entry per axle END: a dualled tandem is eight wheels of rubber but one
        // contact patch as far as this model is concerned, lumped at the tandem centre.
        // Worth knowing what that costs -- a real tandem is spread over about 1.3 m and
        // resists yaw more than a single axle at its centre does, so this trailer turns
        // in slightly more willingly than a real one would.
        const float nominal_cab = (cab_weight + kingpin_load) * 0.25f;
        const float nominal_tandem = tandem_load * 0.5f;
        const float sides[2] = {-1.0f, 1.0f};
        mass_ = cab_mass;
        for (const float side : sides) {
            // Tire order is fixed and public, as it is for a car: 0/1 steer, 2/3 drive,
            // 4/5 trailer tandem. tire_slip() hands these straight to the renderer.
            const int steer_tire = side < 0.0f ? 0 : 1;
            const int drive_tire = side < 0.0f ? 2 : 3;
            apply_tire(cab, steer_tire,
                       b3Vec3{side * kRigCabWheelTrack, 0.0f, kRigSteerAxle}, steer,
                       steer_load * 0.5f, steer_brake, grip_now_, nominal_cab, 0.25f);
            apply_tire(cab, drive_tire,
                       b3Vec3{side * kRigCabWheelTrack, 0.0f, -kRigDriveAxle}, 0.0f,
                       drive_load * 0.5f, drive + drive_brake, grip_now_ * drive_bias,
                       nominal_cab, 0.25f);
        }
        // The trailer's tires answer to the TRAILER's heading, not the cab's. This is the
        // line that makes off-tracking real: they resist being dragged sideways along
        // their own axis, which is what pulls the trailer inside the cab's line through a
        // corner instead of letting it swing wide.
        current_yaw_ = trailer_yaw;
        mass_ = trailer_mass;
        for (const float side : sides) {
            const int tire = side < 0.0f ? 4 : 5;
            apply_tire(trailer, tire,
                       b3Vec3{side * kRigTrailerWheelTrack, 0.0f,
                              -(kRigKingpinToTandem - kRigTrailerCentre)},
                       0.0f, tandem_load * 0.5f, tandem_brake, tandem_grip,
                       nominal_tandem, 0.5f);
        }
        current_yaw_ = state.yaw;
        mass_ = total_mass;

        // Drag on each body at its own centre, so neither can contribute yaw. The trailer
        // is the barn door and carries most of it.
        const float resistance = hv_->drag_ * speed + hv_->rolling_resistance_;
        b3Body_ApplyForceToCenter(
            cab,
            b3Vec3{-state.vx * resistance * 0.25f, 0.0f, -state.vz * resistance * 0.25f},
            true);
        const b3Vec3 tv = b3Body_GetLinearVelocity(trailer);
        b3Body_ApplyForceToCenter(
            trailer, b3Vec3{-tv.x * resistance * 0.75f, 0.0f, -tv.z * resistance * 0.75f},
            true);
    }

    void push_to_physics(ashiato::Entity entity, driving::CarState& state,
                         const driving::CarInput& input, float hp) {
        // Cleared by every car in this half; the read half below steps on the first car
        // that finds it false. Ordering (-1 before 0) is what makes that reliable, and
        // single_thread() is what makes it safe.
        stepped_this_tick_ = false;

        const b3BodyId body = ensure_body(entity);
        const float half = state.yaw * 0.5f;
        b3Body_SetTransform(body, b3Pos{state.x, state.y, state.z},
                            b3Quat{b3Vec3{0.0f, std::sin(half), 0.0f}, std::cos(half)});
        b3Body_SetLinearVelocity(body, b3Vec3{state.vx, state.vy, state.vz});
        b3Body_SetAngularVelocity(body, b3Vec3{0.0f, state.yaw_rate, 0.0f});

        current_yaw_ = state.yaw;
        current_entity_ = entity.value;
        mass_ = b3Body_GetMass(body);
        // Which vehicle this is, decided ONCE per push and read by everything below --
        // including apply_tire, which cannot be handed it.
        const std::uint8_t kind = kind_of(entity);
        hv_ = &handling_[kind_index(kind)];
        cv_ = &chassis_[kind_index(kind)];
        if (cv_->articulated_) {
            push_rig(entity, state, input, hp, body);
            return;
        }
        const float nominal_quarter = mass_ * kGravity * 0.25f;

        const float sin_yaw = std::sin(state.yaw);
        const float cos_yaw = std::cos(state.yaw);
        const float speed = std::sqrt(state.vx * state.vx + state.vz * state.vz);
        // Signed: which way the car is actually travelling along its own nose, so that
        // "back" can mean braking when rolling forwards and reverse when nearly stopped.
        const float forward_speed = state.vx * sin_yaw + state.vz * cos_yaw;

        // Lock tapers off with speed. Sign matches the visual and the old model: pressing
        // right (positive steer) turns the car right, which is a NEGATIVE yaw here.
        const float taper =
            1.0f - hv_->steer_falloff_ * std::fmin(speed / hv_->steer_reference_speed_, 1.0f);
        // Grip, and the rear's share of it, both depend on how fast we are going.
        const float grip_factor = std::fmin(speed / hv_->grip_reference_speed_, 1.0f);
        grip_now_ = hv_->grip_ * (1.0f - hv_->grip_speed_loss_ * grip_factor);
        const float rear_bias =
            hv_->rear_grip_bias_ + (hv_->rear_grip_bias_fast_ - hv_->rear_grip_bias_) * grip_factor;
        const float steer = -input.steer * hv_->max_steer_ * taper;
        steer_of_[entity.value] = steer;
        if (is_local_car(entity)) {
            local_steer_angle_ = steer;
        }

        // Throttle: drive the rear axle, or brake, or reverse. Braking and reversing are
        // the same key, told apart by whether the car is still rolling forwards.
        const bool handbrake = input.handbrake != 0;

        // What the engine can put down right now: power divided by speed, capped by what
        // the gearing can deliver at a standstill.
        const float drive_total =
            std::fmin(hp * hv_->drive_force_per_hp_,
                      hp * kWattsPerHp / std::fmax(std::fabs(forward_speed), 0.1f));

        float rear_drive = 0.0f;
        float brake_total = 0.0f;
        if (input.throttle > 0.0f) {
            if (forward_speed < -0.5f) {
                brake_total = input.throttle * hv_->brake_force_;
            } else {
                rear_drive = input.throttle * drive_total * 0.5f;
            }
        } else if (input.throttle < 0.0f) {
            if (forward_speed > 0.5f) {
                brake_total = input.throttle * hv_->brake_force_;
            } else {
                rear_drive = input.throttle * drive_total * kReverseFraction * 0.5f;
            }
        }

        // Weight transfer. Accelerating leans on the rear tires and unloads the fronts,
        // which is why a car understeers under power and turns in when you lift.
        const float front_brake = brake_total * hv_->brake_bias_front_ * 0.5f;
        const float rear_brake = brake_total * (1.0f - hv_->brake_bias_front_) * 0.5f;

        const float long_accel = (rear_drive * 2.0f + brake_total) / mass_;
        const float shift =
            std::fmax(-0.35f, std::fmin(0.35f,
                long_accel * hv_->cg_height_ / (cv_->wheelbase() * kGravity)));
        const float axle_weight = mass_ * kGravity;
        const float front_load = axle_weight * (0.5f - shift) * 0.5f;
        const float rear_load = axle_weight * (0.5f + shift) * 0.5f;

        // A locked rear tire keeps its braking but loses most of its cornering, which is
        // exactly what steps the back end out.
        const float rear_grip =
            handbrake ? grip_now_ * hv_->handbrake_grip_ : grip_now_ * rear_bias;
        const float rear_long = handbrake ? -forward_speed * hv_->brake_force_ * 0.25f : rear_drive;

        const float sides[2] = {-1.0f, 1.0f};
        for (const float side : sides) {
            // Tire order is fixed and public: 0 front-left, 1 front-right, 2 rear-left,
            // 3 rear-right. tire_slip() hands these straight to the renderer.
            const int front = side < 0.0f ? 0 : 1;
            const int rear = side < 0.0f ? 2 : 3;
            apply_tire(body, front,
                       b3Vec3{side * cv_->wheel_track_, 0.0f, cv_->front_axle_}, steer,
                       front_load, front_brake, grip_now_, nominal_quarter, 0.25f);
            apply_tire(body, rear,
                       b3Vec3{side * cv_->wheel_track_, 0.0f, -cv_->rear_axle_}, 0.0f,
                       rear_load, rear_long + rear_brake, rear_grip, nominal_quarter, 0.25f);
        }

        // Air and rolling drag act on the car as a whole, so they go at the centre where
        // they cannot contribute yaw.
        const float resistance = hv_->drag_ * speed + hv_->rolling_resistance_;
        b3Body_ApplyForceToCenter(
            body, b3Vec3{-state.vx * resistance, 0.0f, -state.vz * resistance}, true);
    }

    /// Step the world once for the whole tick, then copy this car's result back out.
    void read_from_physics(ashiato::Entity entity, driving::CarState& state) {
        if (!stepped_this_tick_) {
            b3World_Step(physics_, kFixedDt, kSubSteps);
            stepped_this_tick_ = true;
        }

        const b3BodyId body = ensure_body(entity);
        const b3WorldTransform xform = b3Body_GetTransform(body);
        const b3Vec3 linear = b3Body_GetLinearVelocity(body);
        const b3Vec3 angular = b3Body_GetAngularVelocity(body);
        state.x = xform.p.x;
        state.y = xform.p.y;
        state.z = xform.p.z;
        state.yaw = std::atan2(2.0f * (xform.q.s * xform.q.v.y),
                               1.0f - 2.0f * (xform.q.v.y * xform.q.v.y));
        state.vx = linear.x;
        state.vy = linear.y;
        state.vz = linear.z;
        state.yaw_rate = angular.y;

        // A rig's trailer went into the step as arithmetic; it comes out as whatever the
        // joint and six tires made of it, and the fold is how that is carried back into
        // replicated state. Measured from the two bodies rather than integrated from the
        // rate, because integrating would let the stored angle drift away from where the
        // trailer actually is -- and then the next push would place the trailer somewhere
        // the solver did not put it.
        if (chassis_of(entity).articulated_) {
            const auto found = trailers_.find(entity.value);
            if (found != trailers_.end()) {
                const b3Quat tq = b3Body_GetRotation(found->second);
                const float trailer_yaw = std::atan2(2.0f * (tq.s * tq.v.y),
                                                     1.0f - 2.0f * (tq.v.y * tq.v.y));
                const b3Vec3 tw = b3Body_GetAngularVelocity(found->second);
                driving::RigState& rig = registry_.write<driving::RigState>(entity);
                rig.hitch_yaw = wrap_angle(trailer_yaw - state.yaw);
                rig.hitch_rate = tw.y - state.yaw_rate;
            }
        }
    }

    /// Wrap into [-pi, pi]. A fold is a difference of two headings, so it has to come
    /// back through the seam rather than out the other side as six-odd radians.
    static float wrap_angle(float a) {
        constexpr float two_pi = 6.28318548f;
        float delta = std::fmod(a + 3.14159274f, two_pi);
        if (delta < 0.0f) {
            delta += two_pi;
        }
        return delta - 3.14159274f;
    }

    ashiato::Registry registry_;
    std::unique_ptr<ashiato::sync::ReplicationServer> server_;
    std::unique_ptr<ashiato::sync::ReplicationClient> client_;

    b3WorldId physics_{};
    bool physics_alive_ = false;
    std::unordered_map<std::uint64_t, b3BodyId> bodies_;

    ashiato::Entity state_component_{};
    ashiato::Entity input_component_{};
    ashiato::Entity owner_component_{};
    ashiato::Entity setup_component_{};
    ashiato::Entity kind_component_{};
    ashiato::Entity rig_component_{};
    ashiato::sync::SyncArchetypeId archetype_{};
    // A SECOND archetype rather than one archetype with an unused RigState on every car.
    // Replicated{} carries the archetype per entity, so this costs nothing structurally,
    // and it means a car does not pay 26 bits a tick to say it has no trailer.
    ashiato::sync::SyncArchetypeId archetype_rig_{};
    // The trailer's body and the fifth wheel joining it to the cab, per rig entity.
    // Both are handles into Box3D and neither is replicated: every machine rebuilds them
    // from the same replicated state, exactly as bodies_ already does.
    std::unordered_map<std::uint64_t, b3BodyId> trailers_;
    std::unordered_map<std::uint64_t, b3JointId> fifth_wheels_;

    struct Outbound {
        int64_t peer = 0;
        PackedByteArray bytes;
        int64_t bit_size = 0;
    };
    std::vector<Outbound> outbound_;
    bool stepped_this_tick_ = false;
    ashiato::sync::SyncFrame buffered_frames_ = 2;
    bool auto_buffer_ = true;
    bool sampling_marked_ = false;
    // Everything that shapes how each KIND of vehicle feels, live. The constants above
    // are only the defaults: feel is found by driving, and a C++ rebuild per guess is a
    // miserable loop. See set_vehicle_handling for what each one does.
    Handling handling_[kVehicleKinds] = {
        Handling{}, default_rig_handling(), default_buggy_handling()};
    // The shape of each kind, read by everything that has to build a body, place a tire,
    // or tell a renderer how big a vehicle is. Not adjustable at runtime the way handling
    // is: changing a body's size means rebuilding it, and a rollback replays frames
    // rather than rebuilding bodies.
    Chassis chassis_[kVehicleKinds] = {Chassis{}, rig_chassis(), buggy_chassis()};
    // The set in force for the vehicle currently being pushed into the physics world.
    // Set once at the top of push_to_physics, in the same spirit as current_yaw_ and
    // mass_ below, so apply_tire does not have to be handed it.
    const Handling* hv_ = &handling_[kKindCar];
    // And its shape, set at the same moment and for the same reason.
    const Chassis* cv_ = &chassis_[kKindCar];
    // The steer angle the local car's front wheels were actually given last tick, so the
    // rendered wheels can show the real angle rather than raw input -- the two differ
    // because lock tapers with speed.
    float local_steer_angle_ = 0.0f;
    // Set once per car at the top of push_to_physics so apply_tire does not have to be
    // handed the whole state.
    float current_yaw_ = 0.0f;
    float mass_ = 960.0f;
    std::uint64_t current_entity_ = 0;
    // Per car, how hard each of its four tires is working. Rewritten every tick, so it is
    // a snapshot of NOW rather than a history -- which is what keeps it honest through a
    // rollback, where the same frames are simulated more than once.
    std::unordered_map<std::uint64_t, std::array<float, kMaxTires>> slip_of_;
    // Grip after the speed falloff, shared with apply_tire so the friction circle and the
    // sideways limit agree about how much the tire has today.
    float grip_now_ = kGrip;
    bool predict_all_ = false;
    bool tracing_ = false;
    std::deque<Dictionary> trace_events_;
    int64_t trace_dropped_ = 0;
#ifdef ASHIATO_GD_WITH_TRACING
    std::unique_ptr<ashiato::sync::SyncTracer> tracer_;
#endif
    std::unordered_map<std::uint64_t, float> steer_of_;
    std::vector<ashiato::Entity> pending_destroy_;
    std::uint64_t resim_count_ = 0;
    int64_t last_resim_frame_ = 0;
    int64_t last_resim_span_ = 0;
    std::unordered_map<std::uint64_t, std::uint64_t> resims_of_;
    bool is_server_ = true;
    bool started_ = false;
};

void register_driving_classes() {
    GDREGISTER_CLASS(DrivingWorld);
}

}  // namespace ashiato_gd
