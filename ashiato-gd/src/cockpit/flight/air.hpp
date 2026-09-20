#pragma once

/// THE AIR, AND HOW HARD A CONTROL BITES IN IT (lane/flightcore, step 1).
///
/// The smallest of the shared flight blocks, and the one everything else rests on: the two constants every model uses,
/// and the two functions that say how much of a control's authority the air is giving it at this speed.
///
/// WHY IT EXISTS. `9.81f` is typed 27 times in `cockpit_world.cpp`, and sea-level density three times over
/// (`aero::kSeaLevelDensity`, `rotor::kSeaLevelDensity`, `kAirDensity`). None of them has ever disagreed, and all of
/// them would have to be found on the day density stops being a constant (the review's section 5: density with height
/// is one multiply, and it is on the list). One place to change is the whole point.
///
/// PURE AND STATELESS, with no Box3D and no Godot, as `lifting_surfaces.hpp` and `rotor_disc.hpp` are: a prototype or a
/// test can include it.
///
/// THE EXPRESSIONS ARE UNCHANGED, to the order of their operations. Step 1 moves code and moves nothing else, and
/// `tests/flight_fingerprint.gd` prints every kind's motion bit for bit to prove it.

#include <cmath>

namespace ashiato_gd {
namespace cockpit {
namespace flight {

/// Metres a second squared. The world's, not a planet's: every weight, buoyancy and hover fraction in the game is
/// against this one number.
constexpr float kGravity = 9.81f;

/// Kilograms a cubic metre at sea level, in the standard atmosphere. The simulation has no density with height yet
/// (`../agents.md`, "The flight model, as found", gap 5), so this is the air everywhere.
constexpr float kSeaLevelDensity = 1.225f;

/// HOW HARD A WING'S CONTROL SURFACES BITE, 0 to 1: the dynamic pressure over them as a share of the pressure at
/// `control_reference`, and full above it.
///
/// A control surface is a small wing, and what it pushes with is the air going past it: at a standstill, nothing. That
/// is why the stick does nothing to a parked aeroplane, and why the wheels and the floor hold it level. Until
/// 2026-09-18 this was `speed / control_reference` with a 12 per cent FLOOR, which is 12 per cent of full authority at
/// 0 m/s -- and on a floor the terrain map does not know, a scripted stick stood a parked F-14 on its back
/// (lane/tomcat2, lane/groundroll). SQUARED, because that is what dynamic pressure does: at taxiing speed, 5 m/s, a
/// linear fade left a fifth of the authority and this leaves a twenty-third.
inline float surface_bite(float speed, float control_reference) {
    const float share = speed / std::fmax(control_reference, 0.001f);
    return std::fmin(1.0f, share * share);
}

/// AND A THRUSTER'S: a rotor or a pod pushes with its own thrust, not the air, so theirs keeps the old linear fade and
/// its 12 per cent floor. A helicopter's reference is 0.001 m/s, so it is always 1, and a pod's is 0.5. A helicopter's
/// cyclic works at a hover by design (`rotor_turn`, `rotor_hold`, `rotor_rates`).
inline float thruster_bite(float speed, float control_reference) {
    return std::fmin(1.0f, std::fmax(0.12f, speed / control_reference));
}

/// The dynamic pressure of an airflow, N per square metre. Not used by the lumped wing, which works in its own units
/// of newtons per (m/s)^2 per radian; the surfaces and the rotor use it.
inline float dynamic_pressure(float speed, float rho = kSeaLevelDensity) { return 0.5f * rho * speed * speed; }

}  // namespace flight
}  // namespace cockpit
}  // namespace ashiato_gd
