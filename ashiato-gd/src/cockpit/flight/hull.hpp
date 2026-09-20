#pragma once

/// WHAT THE WATER DOES TO A HULL (lane/flightcore, step 1).
///
/// The shared block for everything afloat: the keel, the bow wave, the rudder at the stern, a planing bottom's lift and
/// the lean it makes in a turn, and where a hull's float probes stand. Pure arithmetic, with no Box3D: each function
/// returns a SIZE, and the caller applies it where it belongs and through `resist`, which is the clamp every resistance
/// in this game goes through ("Nothing may reverse what it is resisting").
///
/// WHY IT EXISTS. Three hulls had their own copies of the same water: `sail_boat` (a launch, a patrol boat, a CB90, a
/// carrier, a battleship, a submarine), `alight` (a flying boat's hull, which is a boat for as long as it is wet) and
/// `sail_ship` (the brig, with lift from leeway on top). The keel was typed three times, the bow wave twice, the stern
/// rudder twice, and the probes' reach three times. A fix to any of them reached one.
///
/// THE EXPRESSIONS ARE UNCHANGED, to the order of their operations, so every boat floats, turns and stops exactly as it
/// did; `tests/flight_fingerprint.gd` prints it bit for bit, and `tests/seakeeping.gd` and `handling.gd`'s boat gates
/// hold what they always held.

#include <cmath>

#include "air.hpp"

namespace ashiato_gd {
namespace cockpit {
namespace flight {
namespace hull {

/// THE KEEL, and it is the aeroplane's side force in water: LINEAR in the slip, so it still bites at the small angles
/// where a quadratic term has given up, and CAPPED, because a hull slides when you ask too much of it and a boat that
/// corners at 1.4 g is a car.
///
/// `lift` is what a sailing hull's keel makes with the way on (`Rig::keel_lift`), zero on a motor boat, whose keel is
/// the standing `water_drag` alone.
inline float keel(float across, float along, float water_drag, float limit, float lift = 0.0f) {
    return std::fmin(std::fabs(across) * (lift * std::fabs(along) + water_drag), limit);
}

/// THE BOW WAVE: a displacement hull drags its own wave along with it, and the cost climbs steeply as the wave grows as
/// long as the boat, which is why a hull has a speed it cannot simply be powered past. `from` is the share of the hull
/// speed it begins at: 1 on a motor boat, `Rig::wave_from` (0.8) on the brig.
inline float bow_wave(float along, float hull_speed, float wave_drag, float from = 1.0f) {
    const float over = std::fabs(along) - hull_speed * from;
    if (over <= 0.0f || wave_drag <= 0.0f) {
        return 0.0f;
    }
    return over * over * wave_drag;
}

/// THE RUDDER, as a side force at the stern rather than a commanded yaw rate. That costs nothing and buys the two
/// things that make steering a boat feel like steering a boat: the stern swings wide through the turn, and the helm
/// reverses by itself when the boat goes astern, because the water is going past the blade the other way.
inline float stern_rudder(float steer, float along, float rudder_force) {
    return -steer * along * std::fabs(along) * rudder_force;
}

/// AND WHAT THE HELM COSTS: a deflected blade is a brake as well as a lever, which is why a boat scrubs speed off
/// through a turn.
inline float rudder_drag(float steer, float along, float rudder_force) {
    return std::fabs(steer) * along * along * rudder_force * 0.35f;
}

/// A HULL'S LENGTH ON THE WATER: the hull under the deck where the deck overhangs it, else the whole box.
inline float waterline_length(float afloat_half_length, float half_length) {
    return 2.0f * (afloat_half_length > 0.0f ? afloat_half_length : half_length);
}

/// HOW FAR OUT A FLOAT PROBE STANDS: as far as the hull is THERE. A carrier's deck is nearly twice as wide as the hull
/// it overhangs, and probes out under the deck edge would be pushing on air.
inline float probe_reach(float afloat_half, float half) {
    return (afloat_half > 0.0f ? afloat_half : half) * 0.75f;
}

/// A PLANING BOTTOM'S LIFT: a share of the weight, as the square of the speed through the water up to `plane_speed`,
/// and never more. Nothing but the float probes held a boat up at any speed before this, so a 5.6 m launch flat out sat
/// as deep as it floats at rest and ran its bow under a 28 m wave (lane/seakeep).
inline float planing_lift(float along, float plane_speed, float share_of_weight, float weight) {
    if (share_of_weight <= 0.0f || plane_speed <= 0.0f) {
        return 0.0f;
    }
    const float share = std::fabs(along) / plane_speed;
    const float up_to = share < 0.0f ? 0.0f : (share > 1.0f ? 1.0f : share);
    return share_of_weight * up_to * up_to * weight;
}

/// THE HUMP a hull climbs over on its way onto the plane: most at half the planing speed, and a quarter of it once it
/// is up and running.
inline float hump(float along, float plane_speed) {
    if (plane_speed <= 0.0f) {
        return 0.0f;
    }
    const float share = along / plane_speed;
    const float up_to = share < 0.0f ? 0.0f : (share > 1.0f ? 1.0f : share);
    return 0.75f * std::sin(3.14159265f * up_to) + 0.25f * up_to;
}

/// HOW FAR A FAST BOAT LEANS INTO ITS TURN: radians per g of the turn it is MAKING (the sideways acceleration, speed
/// times yaw rate), never more than one g's worth. Not the helm's: a boat sliding sideways at a standstill with the
/// wheel hard over does not lean at all, and this says so.
inline float lean(float along, float yaw_rate, float radians_per_g) {
    const float turn_g = -along * yaw_rate / kGravity;
    const float held = turn_g < -1.0f ? -1.0f : (turn_g > 1.0f ? 1.0f : turn_g);
    return radians_per_g * held;
}

}  // namespace hull
}  // namespace flight
}  // namespace cockpit
}  // namespace ashiato_gd
