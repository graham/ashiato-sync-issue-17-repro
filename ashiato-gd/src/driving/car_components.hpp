#pragma once
// The networked vocabulary for a car, and the wire format for it.
//
// This is the one place the "components cost zero C++" property stops. ashiato-sync
// requires an explicit SyncComponentTraits<T> per replicated component and deliberately
// never picks a wire format implicitly, so the replicated set is a small FIXED
// vocabulary defined here. Anything not replicated can still be declared from GDScript
// at runtime through AshiatoWorld.
//
// That is the right trade: quantisation is what makes replication cheap, and it can only
// be chosen with knowledge of the units. A car does not need 32 bits of float per axis;
// it needs a centimetre over a few hundred metres of track.

#include <cmath>
#include <cstdint>

#include "ashiato/sync/sync.hpp"

namespace ashiato_gd::driving {

// What the driver is asking for. Sent client -> server by sync itself once designated
// with set_client_input_component<CarInput>(); we never hand-roll input transport.
struct CarInput {
    float throttle = 0.0f;  // -1 full reverse .. +1 full forward
    float steer = 0.0f;     // -1 full left .. +1 full right
    std::uint8_t handbrake = 0;
    // -1, 0 or +1: the driver asked for less or more power this tick.
    //
    // It travels as INPUT rather than as its own message, which is what makes it work at
    // all. sync already carries input from the owning client to the server, stamps it with
    // a frame, buffers it and replays it during rollback -- so a power change lands on a
    // definite tick that both machines agree on, and the loopback used by solo play takes
    // exactly the same path as a real connection. A side-channel RPC would have neither
    // property and would need a special case for solo.
    std::int8_t hp_step = 0;
    // Not sent: the frame. sync stamps and buffers input frames itself.
};

// Per-car engine power, owned by the server and replicated to everyone.
//
// Per CAR, not per world: every player tunes their own engine, and every machine has to
// simulate every car with the right one. It is also what lets the number be drawn over
// somebody else's roof.
struct CarSetup {
    float hp = 117.0f;
};

// Where the car actually is, produced by stepping Box3D.
//
// Yaw only, not a full quaternion: this is a top-down driving game, so pitch and roll
// are cosmetic. Sending one angle instead of four components is a large saving on the
// hottest component in the game, and the renderer can keep its own visual tilt.
struct CarState {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    float yaw = 0.0f;
    float vx = 0.0f;
    float vy = 0.0f;
    float vz = 0.0f;
    float yaw_rate = 0.0f;
};

// Who drives this car, in OUR vocabulary.
//
// sync::NetworkOwner already records this server-side, but it is a sync-internal
// component with no SyncComponentTraits, so it has no wire format and cannot be put in
// an archetype -- trying crashes the process on the first serialize. The client still
// has to know which car is its own in order to predict it, so the fact is replicated as
// a component we define and can therefore serialize.
struct CarOwner {
    std::uint32_t client = 0;
};

// Which vehicle this is, and therefore which handling and which shape every machine
// must simulate it with.
//
// Replicated even though rigs get their own archetype, because the archetype is sync's
// business and the game layer never sees it. The renderer has to know whether to build a
// cab and a trailer or a car, and the simulation has to know which handling table to
// reach for -- and both run on machines that only ever learn about this vehicle from
// the wire.
struct VehicleKind {
    // 0 = car, 1 = tractor unit with a semi-trailer. Not an enum class: it is a wire
    // value, and the width below is what it actually costs.
    std::uint8_t kind = 0;
};

// The articulation at the fifth wheel: how far the trailer is folded relative to the
// tractor, and how fast that is changing.
//
// THIS IS THE WHOLE TRAILER, on the wire. A second CarState was the obvious way to
// replicate a trailer and it is the wrong one: two independently interpolated poses for
// a rigidly coupled pair have nothing forcing the kingpin to coincide, so on a remote
// machine the trailer visibly parts from the cab and snaps back whenever the two poses
// arrive out of step. Deriving the trailer instead makes that failure unrepresentable --
// there is no second pose to disagree with.
//
// It is sufficient, not merely cheaper. The kingpin is a fixed point on both bodies, so
// the tractor pose plus this angle determines the trailer pose exactly; and the kingpin
// has ONE velocity shared by both bodies, so the tractor's motion plus this rate
// determines the trailer's linear and angular velocity exactly. Nothing else about the
// trailer is independent state, which is why a rollback can restore it from these two
// numbers and get a bit-identical replay.
//
// 26 bits against 119 for a second CarState, for a stronger guarantee.
struct RigState {
    // Radians. Positive folds one way, negative the other; zero is straight. Signed
    // rather than absolute so it interpolates through zero without a special case.
    float hitch_yaw = 0.0f;
    // Radians per second, the rate of the same angle. Kept because the trailer's
    // velocity cannot be reconstructed without it -- and because a rig that is straight
    // right now but folding fast is a jackknife in progress, which is not the same state
    // as a rig that is straight and settled.
    float hitch_rate = 0.0f;
};

}  // namespace ashiato_gd::driving

namespace ashiato::sync {

template <>
struct SyncComponentTraits<ashiato_gd::driving::CarInput> {
    using Quantized = ashiato_gd::driving::CarInput;

    // A stick axis does not deserve more than a byte's worth of steps; 1/128 is far
    // finer than anyone can hold a trigger.
    static constexpr serialization::QuantizedFloatConfig axis{-1.0f, 1.0f, 1.0f / 128.0f};

    static void quantize(const ashiato_gd::driving::CarInput& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::driving::CarInput dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        serialization::serialize_quantized_float(out, current.throttle, axis);
        serialization::serialize_quantized_float(out, current.steer, axis);
        out.write_unsigned_bits(current.handbrake != 0 ? 1u : 0u, 1);
        // Two bits: 0 = leave it alone, 1 = more, 2 = less.
        out.write_unsigned_bits(
            current.hp_step > 0 ? 1u : (current.hp_step < 0 ? 2u : 0u), 2);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (!serialization::read_quantized_float(in, axis, out.throttle)) {
            return false;
        }
        if (!serialization::read_quantized_float(in, axis, out.steer)) {
            return false;
        }
        if (in.remaining_bits() < 1) {
            return false;
        }
        out.handbrake = static_cast<std::uint8_t>(in.read_unsigned_bits(1));
        if (in.remaining_bits() < 2) {
            return false;
        }
        const std::uint32_t step = in.read_unsigned_bits(2);
        out.hp_step = step == 1u ? 1 : (step == 2u ? -1 : 0);
        return true;
    }

    // Kept although CarInput is deliberately NOT in the archetype (see driving_world.cpp
    // -- replicating input back to its own owner is what made the car drive on a stale
    // copy of the wheel). sync still wants a full trait set for any registered component,
    // and if input is ever put in an archetype again the absence of this crashes on the
    // first prediction rather than saying anything. Input is authoritative from whoever
    // pressed the key, so a difference is never worth a rollback on its own.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }
};

template <>
struct SyncComponentTraits<ashiato_gd::driving::CarSetup> {
    using Quantized = ashiato_gd::driving::CarSetup;

    // Whole horsepower over the range the game allows. Nobody can feel a fraction of one.
    //
    // The ceiling was 400 and 9 bits, which was exactly the car's range -- and then a
    // 450 hp truck arrived and could not be REPRESENTED: the quantiser clamped it to 400
    // on the way to the wire, so the engine the server had and the engine every client
    // drew disagreed by 50 hp with nothing to say so. Raised to 600, which is the top of
    // what a long-haul tractor is actually built with. It costs one bit.
    static constexpr serialization::QuantizedFloatConfig power{40.0f, 600.0f, 1.0f};

    static void quantize(const ashiato_gd::driving::CarSetup& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::driving::CarSetup dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        serialization::serialize_quantized_float(out, current.hp, power);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        return serialization::read_quantized_float(in, power, out.hp);
    }

    // TRUE on any difference, unlike the other components here, and this is what makes a
    // power change visible at all.
    //
    // A predicted car runs on the client's own simulation and only adopts the server's
    // values when something forces a reconciliation. Power is never simulated by the
    // client -- only the server changes it -- so with this returning false the new figure
    // sat in the incoming update and was applied whenever the car happened to be
    // corrected for some unrelated reason. Pressing + did nothing visible until you drove
    // into something. Saying the difference is worth a rollback makes the client adopt it
    // on the frame it arrives, which costs one resimulation of a handful of ticks on an
    // event that happens when a key is pressed.
    static bool should_roll_back(const Quantized& current, const Quantized& previous) {
        return current.hp != previous.hp;
    }

    // Step, not blend: an engine is 120 hp or 130 hp, never 124.7 on the way between.
    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

template <>
struct SyncComponentTraits<ashiato_gd::driving::CarOwner> {
    using Quantized = ashiato_gd::driving::CarOwner;

    static void quantize(const ashiato_gd::driving::CarOwner& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::driving::CarOwner dequantize(const Quantized& value) {
        return value;
    }

    // 16 bits: a lobby will not hold 65k drivers, and ownership never changes often
    // enough for the width to matter.
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

    // Same requirement as CarInput. Ownership does not change during a rollback window,
    // so a mismatch here is not something to resimulate over.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }
};

template <>
struct SyncComponentTraits<ashiato_gd::driving::CarState> {
    using Quantized = ashiato_gd::driving::CarState;

    // A 1 km track at 1 cm. Height gets a much smaller range: a car that is 40 m in the
    // air has bigger problems than wire precision.
    static constexpr serialization::QuantizedFloatConfig ground{-500.0f, 500.0f, 0.01f};
    static constexpr serialization::QuantizedFloatConfig height{-20.0f, 40.0f, 0.01f};
    static constexpr serialization::QuantizedFloatConfig angle{-3.14159274f, 3.14159274f, 0.001f};
    static constexpr serialization::QuantizedFloatConfig speed{-150.0f, 150.0f, 0.01f};
    static constexpr serialization::QuantizedFloatConfig spin{-30.0f, 30.0f, 0.005f};

    static void quantize(const ashiato_gd::driving::CarState& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::driving::CarState dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        serialization::serialize_quantized_float(out, current.x, ground);
        serialization::serialize_quantized_float(out, current.y, height);
        serialization::serialize_quantized_float(out, current.z, ground);
        serialization::serialize_quantized_float(out, current.yaw, angle);
        serialization::serialize_quantized_float(out, current.vx, speed);
        serialization::serialize_quantized_float(out, current.vy, speed);
        serialization::serialize_quantized_float(out, current.vz, speed);
        serialization::serialize_quantized_float(out, current.yaw_rate, spin);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        return serialization::read_quantized_float(in, ground, out.x)
            && serialization::read_quantized_float(in, height, out.y)
            && serialization::read_quantized_float(in, ground, out.z)
            && serialization::read_quantized_float(in, angle, out.yaw)
            && serialization::read_quantized_float(in, speed, out.vx)
            && serialization::read_quantized_float(in, speed, out.vy)
            && serialization::read_quantized_float(in, speed, out.vz)
            && serialization::read_quantized_float(in, spin, out.yaw_rate);
    }

    // How wrong the prediction has to be before it is worth rewinding for, and how long
    // the leftover error takes to melt away once it has been.
    //
    // These two are the smoothness of a correction, and they trade against each other.
    // Raise the thresholds and small disagreements are simply tolerated -- no rewind, no
    // resimulation, nothing to smooth -- at the cost of the car sitting slightly wrong for
    // longer. Lengthen the blend and a correction that does happen is spread over more
    // frames, so the car SLIDES into the right place instead of arriving there.
    //
    // Both are deliberately generous. Prediction is never bit-exact -- the quantised wire
    // value alone guarantees that -- and a car twitching into position every few frames
    // feels worse than one that is quietly 15 cm out and catching up.
    static constexpr float rollback_position = 0.15f;   // metres
    static constexpr float rollback_heading = 0.14f;    // radians, about 8 degrees
    // Time constant of the blend: the visible error decays to about a third of itself in
    // this long. Longer looks smoother and lies for longer about where the car is.
    static constexpr float error_blend_seconds = 0.30f;

    static bool should_roll_back(const Quantized& predicted, const Quantized& authoritative) {
        const float dx = predicted.x - authoritative.x;
        const float dy = predicted.y - authoritative.y;
        const float dz = predicted.z - authoritative.z;
        if ((dx * dx + dy * dy + dz * dz) > (rollback_position * rollback_position)) {
            return true;
        }
        // Heading matters more than position on a car: being 15 cm out is nothing, being
        // 8 degrees out points the whole vehicle somewhere else within a second.
        return std::fabs(shortest_angle(predicted.yaw, authoritative.yaw)) > rollback_heading;
    }

    // Required for components marked Interpolate: fills the gap between received frames
    // for OTHER players' cars.
    static Quantized interpolate(const Quantized& from, const Quantized& to, float alpha) {
        Quantized out;
        out.x = lerp(from.x, to.x, alpha);
        out.y = lerp(from.y, to.y, alpha);
        out.z = lerp(from.z, to.z, alpha);
        // Through the short way round, or a car crossing the +/-pi seam spins a full
        // turn in one frame.
        out.yaw = from.yaw + shortest_angle(to.yaw, from.yaw) * alpha;
        out.vx = lerp(from.vx, to.vx, alpha);
        out.vy = lerp(from.vy, to.vy, alpha);
        out.vz = lerp(from.vz, to.vz, alpha);
        out.yaw_rate = lerp(from.yaw_rate, to.yaw_rate, alpha);
        return out;
    }

    // ---- error blending -------------------------------------------------------
    //
    // This is what turns a correction from a SNAP into a pull-in, and it is also the
    // gate on fractional-tick sampling: set_fractional_tick_sampled() refuses a
    // component that cannot compute, apply and blend out an error, because sampling a
    // car between frames is meaningless if a correction would teleport it anyway.
    //
    // The idea: when the server disagrees, do not move the car. Remember the DIFFERENCE
    // as a visual offset, put the car where the server says, and shrink the offset over
    // the next few frames. The simulation is authoritative immediately; the eye never
    // sees the jump.
    struct Error {
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
        float yaw = 0.0f;
    };

    /// How far the display should still be from the corrected truth.
    static Error compute_error(const Quantized& current, const Quantized& previous) {
        Error error;
        error.x = previous.x - current.x;
        error.y = previous.y - current.y;
        error.z = previous.z - current.z;
        error.yaw = shortest_angle(previous.yaw, current.yaw);
        return error;
    }

    /// Where to DRAW the car: the true state, offset by whatever error is left.
    static Quantized apply_error(const Quantized& current, const Error& error) {
        Quantized out = current;
        out.x += error.x;
        out.y += error.y;
        out.z += error.z;
        out.yaw += error.yaw;
        // Velocity is deliberately NOT offset. It is the truth from the server and is
        // what the next tick simulates from; only the visible pose is being smoothed.
        return out;
    }

    /// Shrink the offset. Exponential, so it is frame-rate independent -- a fixed
    /// fraction per frame would fade at different speeds on different machines.
    ///
    /// A ~120 ms time constant: fast enough that the drawn car is never meaningfully
    /// behind the simulation, slow enough that a correction reads as a nudge rather
    /// than a jump.
    static Error blend_out_error(const Error& error, float dt_seconds) {
        const float keep = std::exp(-dt_seconds / error_blend_seconds);
        Error out;
        out.x = error.x * keep;
        out.y = error.y * keep;
        out.z = error.z * keep;
        out.yaw = error.yaw * keep;
        return out;
    }

    static float lerp(float a, float b, float t) {
        return a + (b - a) * t;
    }

    // Signed difference a-b wrapped into [-pi, pi].
    static float shortest_angle(float a, float b) {
        constexpr float two_pi = 6.28318548f;
        float delta = std::fmod(a - b + 3.14159274f, two_pi);
        if (delta < 0.0f) {
            delta += two_pi;
        }
        return delta - 3.14159274f;
    }
};

template <>
struct SyncComponentTraits<ashiato_gd::driving::VehicleKind> {
    using Quantized = ashiato_gd::driving::VehicleKind;

    static void quantize(const ashiato_gd::driving::VehicleKind& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::driving::VehicleKind dequantize(const Quantized& value) {
        return value;
    }

    // Two bits: four kinds of vehicle is more than this game has, and widening it later
    // is a wire-format change either way.
    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        out.write_unsigned_bits(current.kind & 0x3u, 2);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        if (in.remaining_bits() < 2) {
            return false;
        }
        out.kind = static_cast<std::uint8_t>(in.read_unsigned_bits(2));
        return true;
    }

    // A vehicle does not turn into a different vehicle mid-race. If it ever did, the
    // body and the mesh would both have to be rebuilt, which is not something a
    // resimulation can do.
    static bool should_roll_back(const Quantized&, const Quantized&) {
        return false;
    }

    // Step, not blend: there is no halfway between a car and a truck.
    static Quantized interpolate(const Quantized& from, const Quantized&, float) {
        return from;
    }
};

template <>
struct SyncComponentTraits<ashiato_gd::driving::RigState> {
    using Quantized = ashiato_gd::driving::RigState;

    // +/- 2 rad is 115 degrees, comfortably past the ~75 degrees at which the trailer
    // nose reaches the cab and the joint limit stops it. 0.0005 rad is finer than it
    // looks: the trailer's tandem is 12.2 m behind the kingpin, so one step of angle is
    // 6 mm of tail movement. The tractor's own yaw gets away with 0.001 because nothing
    // on a car is 12 m from the centre of mass.
    static constexpr serialization::QuantizedFloatConfig fold{-2.0f, 2.0f, 0.0005f};
    // A hitch closing faster than 8 rad/s is a jackknife that has already happened.
    static constexpr serialization::QuantizedFloatConfig fold_rate{-8.0f, 8.0f, 0.002f};

    static void quantize(const ashiato_gd::driving::RigState& value, Quantized& out) {
        out = value;
    }

    static ashiato_gd::driving::RigState dequantize(const Quantized& value) {
        return value;
    }

    static void serialize(
        const Quantized*,
        const Quantized& current,
        ashiato::BitBuffer& out,
        ashiato::ComponentSerializationContext&) {
        serialization::serialize_quantized_float(out, current.hitch_yaw, fold);
        serialization::serialize_quantized_float(out, current.hitch_rate, fold_rate);
    }

    static bool deserialize(
        ashiato::BitBuffer& in,
        const Quantized*,
        Quantized& out,
        ashiato::ComponentSerializationContext&) {
        return serialization::read_quantized_float(in, fold, out.hitch_yaw)
            && serialization::read_quantized_float(in, fold_rate, out.hitch_rate);
    }

    // Tighter than CarState's 8 degrees, and for a reason that is entirely about the
    // lever arm. A rig whose cab agrees with the server to within 15 cm can still have
    // its trailer somewhere else entirely: 0.02 rad of fold is only 1.1 degrees, but
    // over 12.2 m of trailer it is a quarter of a metre at the tandem, which is the same
    // order as the position threshold the cab is held to. Matching the two means a
    // rollback is triggered by the trailer being visibly wrong, not by the angle being
    // arithmetically wrong.
    static constexpr float rollback_fold = 0.02f;
    // The same time constant as CarState, deliberately. The cab and the trailer must pay
    // off their leftover error together or the rig visibly bends while it settles.
    static constexpr float error_blend_seconds = 0.30f;

    static bool should_roll_back(const Quantized& predicted, const Quantized& authoritative) {
        return std::fabs(shortest_angle(predicted.hitch_yaw, authoritative.hitch_yaw))
             > rollback_fold;
    }

    static Quantized interpolate(const Quantized& from, const Quantized& to, float alpha) {
        Quantized out;
        // Through the short way round for the same reason CarState's yaw is: a rig
        // crossing the seam would otherwise unfold a full turn in one frame.
        out.hitch_yaw = from.hitch_yaw + shortest_angle(to.hitch_yaw, from.hitch_yaw) * alpha;
        out.hitch_rate = from.hitch_rate + (to.hitch_rate - from.hitch_rate) * alpha;
        return out;
    }

    // ---- error blending -------------------------------------------------------
    //
    // Required, not optional: set_fractional_tick_sampled() refuses a component that
    // cannot compute, apply and blend out an error, and the trailer HAS to be sampled on
    // the same fractional tick as the cab. Drawing the cab from the sample buffer and
    // the trailer from the live ECS would reintroduce exactly the visible parting at the
    // kingpin that deriving the trailer was meant to make impossible.
    struct Error {
        float hitch_yaw = 0.0f;
    };

    static Error compute_error(const Quantized& current, const Quantized& previous) {
        Error error;
        error.hitch_yaw = shortest_angle(previous.hitch_yaw, current.hitch_yaw);
        return error;
    }

    static Quantized apply_error(const Quantized& current, const Error& error) {
        Quantized out = current;
        out.hitch_yaw += error.hitch_yaw;
        // The rate is not offset, for the same reason CarState does not offset velocity:
        // it is the truth the next tick simulates from, and only the visible fold is
        // being smoothed.
        return out;
    }

    static Error blend_out_error(const Error& error, float dt_seconds) {
        Error out;
        out.hitch_yaw = error.hitch_yaw * std::exp(-dt_seconds / error_blend_seconds);
        return out;
    }

    // Signed difference a-b wrapped into [-pi, pi]. A copy of CarState's, because these
    // trait specialisations are separate types and neither can see the other's statics.
    static float shortest_angle(float a, float b) {
        constexpr float two_pi = 6.28318548f;
        float delta = std::fmod(a - b + 3.14159274f, two_pi);
        if (delta < 0.0f) {
            delta += two_pi;
        }
        return delta - 3.14159274f;
    }
};

}  // namespace ashiato::sync
