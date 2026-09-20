#pragma once
/// ## A PROPELLER, AND THE FOUR WAYS IT PULLS AN AEROPLANE OFF ITS HEADING (lane/flightcore, step 0).
///
/// What it is: the propulsion block's propeller half, pure and stateless. It makes a thrust along the nose, and three
/// moments that a big propeller in front of a light aeroplane makes with it, which is what a taildragger's take-off is
/// and what nothing in the game has ever had:
/// - TORQUE, the equal and opposite of what turns the blades, which rolls the aeroplane;
/// - P-FACTOR, the thrust's centre moving sideways when the disc meets the air at an angle, which yaws it;
/// - SLIPSTREAM, the air the disc has already worked on, faster and turning, arriving at the tail, which yaws it again
///   and gives the fin and the tailplane authority at a standstill that airspeed alone would not.
/// A COUNTER-ROTATING PAIR cancels all three: `handedness` is +1 or -1 an engine, and a P-38's two are opposite.
///
/// The decision: thrust from momentum theory for a CONSTANT-SPEED propeller (a warbird, a transport), and the game's
/// existing line through two book points for a FIXED-PITCH one (the Cessna). A fixed-pitch propeller at a standstill is
/// far off its design point, its blades part stalled, and momentum theory overstates it by two or three times; the
/// Cessna's `thrust = 2.5 kN x (throttle - v / 185)` already fits its book at both ends (lane/cessnafm) and is kept.
///
/// What went wrong before it: nothing, because none of it exists. Today an aeroplane's thrust is `throttle x thrust`
/// along the nose, the same at every speed and every angle, with no moment of any kind (`../agents.md`, "The flight
/// model, as found", gap 5). The P-51 and the P-47 land in the game with the take-off swing that defines them missing.
///
/// Sources: McCormick, Aerodynamics Aeronautics and Flight Mechanics, ch. 6 (the actuator disc, the slipstream's speed
/// and swirl); Phillips, Mechanics of Flight, sec. 2.5 (a propeller's figure of merit at a standstill); the FAA's
/// Airplane Flying Handbook ch. 5 (the four left-turning tendencies named as a pilot meets them).

#include <cmath>

namespace flightcore {
namespace prop {

constexpr float kRho = 1.225f;
constexpr float kPi = 3.14159265f;

/// ONE PROPELLER, read off the kind: what a drawing and an engine's data plate give.
struct Propeller {
    float radius = 1.70f;
    /// Shaft power at full throttle, watts, and the speed the blades turn at, radians a second.
    float power = 1.1e6f;
    float omega = 150.0f;
    /// WHICH WAY IT TURNS, seen from the cockpit: +1 clockwise (a Merlin, a Continental), -1 anticlockwise. A
    /// counter-rotating pair is one of each, and every moment below changes sign with it.
    float handedness = 1.0f;
    /// HOW MUCH OF MOMENTUM THEORY'S IDEAL THRUST IT MAKES AT A STANDSTILL. A propeller at zero airspeed is far off its
    /// design point: the ideal is (2 rho A P^2)^(1/3), and a real one gives about half. ESTIMATE, and the one number a
    /// take-off distance would pin (as `thrust_gone_at` pins the Cessna's).
    float static_merit = 0.5f;
    /// And in flight, what is left after the blades' own drag: the usual 0.80 to 0.85.
    float efficiency = 0.85f;
    /// HOW FAR OUT THE THRUST MOVES per radian of the angle the disc meets the air at, as a share of the radius: the
    /// descending blade meets the air at a greater angle and pulls harder, so the thrust's centre moves toward it.
    /// ESTIMATE; 0.30 is the middle of what the handbooks' figures imply for a three-blade propeller.
    float p_factor = 0.30f;
    /// HOW MUCH OF THE SLIPSTREAM'S TURN REACHES THE FIN, 0 to 1: all of it if the fin sat in the middle of the tube,
    /// less because it is above the axis and the tube has spread. ESTIMATE.
    float swirl_share = 0.50f;
};

struct Pull {
    float thrust = 0.0f;      // N along the nose
    float induced = 0.0f;     // m/s the disc adds to the air going through it
    float roll = 0.0f;        // N m, positive rolling right
    float yaw = 0.0f;         // N m, positive yawing right (nose right)
    float slipstream = 0.0f;  // m/s of extra airspeed at the tail
    float swirl = 0.0f;       // m/s of sideways air at the fin, positive from the left
};

inline float area(const Propeller& p) { return kPi * p.radius * p.radius; }

/// THE INDUCED VELOCITY of a constant-speed propeller at this power and airspeed: eta P = 2 rho A (V + vi)^2 vi, solved
/// by Newton from the standstill answer. At a standstill it is the disc's own (P / 2 rho A)^(1/3).
inline float induced(const Propeller& p, float power, float along) {
    const float disc = 2.0f * kRho * area(p);
    const float v = std::fmax(along, 0.0f);
    const float useful = std::fmax(power, 0.0f) * (v < 1.0f ? p.static_merit : p.efficiency);
    if (useful <= 0.0f) {
        return 0.0f;
    }
    float vi = std::cbrt(useful / disc);
    for (int i = 0; i < 6; ++i) {
        const float f = disc * (v + vi) * (v + vi) * vi - useful;
        const float slope = disc * ((v + vi) * (v + vi) + 2.0f * (v + vi) * vi);
        if (std::fabs(slope) < 1e-6f) {
            break;
        }
        vi -= f / slope;
        if (vi < 0.0f) {
            vi = 0.0f;
        }
    }
    return vi;
}

/// WHAT THE PROPELLER PULLS AND TWISTS. `throttle` 0 to 1; `along` the airspeed along the nose; `alpha` the angle the
/// disc meets the air at (the aeroplane's angle of attack, plus any sideslip for the fin's sake); `tail_arm` the
/// distance from the propeller to the fin, and `fin_height` the fin's centre above the axis, both metres.
inline Pull pull(const Propeller& p, float throttle, float along, float alpha, float tail_arm, float fin_height) {
    Pull out;
    const float power = std::fmax(throttle, 0.0f) * p.power;
    const float vi = induced(p, power, along);
    out.induced = vi;
    const float v = std::fmax(along, 0.0f);
    out.thrust = 2.0f * kRho * area(p) * (v + vi) * vi;
    if (out.thrust <= 0.0f) {
        return out;
    }
    // TORQUE: the shaft's, which the aeroplane feels the other way round. A propeller turning clockwise from the
    // cockpit rolls the aeroplane anticlockwise, which is to the left.
    const float torque = power / std::fmax(p.omega, 1.0f);
    out.roll = -p.handedness * torque;
    // P-FACTOR: at an angle to the air the descending blade pulls harder, so the thrust acts that far out to one side.
    // Clockwise from the cockpit, the descending blade is on the right, and the yaw is to the LEFT.
    const float offset = p.p_factor * p.radius * std::sin(alpha);
    out.yaw = -p.handedness * out.thrust * offset;
    // THE SLIPSTREAM: far behind the disc the air it has worked on is going 2 vi faster, and it is turning. The turn
    // reaches the fin as a sideways wind; the fin answers it with a side force, which is a yaw. Both fall away as the
    // aeroplane's own speed grows, because the slipstream is then a smaller share of what the tail sees.
    out.slipstream = 2.0f * vi;
    const float tube = std::fmax(v + 2.0f * vi, 1.0f);
    // The swirl's own speed: the torque shared over the tube's momentum (McCormick 6.5), at the fin's own height.
    const float swirl = torque / std::fmax(kRho * area(p) * tube * std::fmax(p.radius, 0.1f), 1e-3f);
    out.swirl = p.handedness * p.swirl_share * swirl * std::fmin(1.0f, std::fabs(fin_height) / std::fmax(p.radius, 0.1f) + 0.5f);
    (void)tail_arm;
    return out;
}

/// THE YAW THE SLIPSTREAM'S TURN MAKES AT THE FIN, given the fin's area, lift slope and arm: the sideways wind is an
/// angle of attack on it, and the force is at the arm. Kept apart from `pull` because it is the FIN's number, not the
/// propeller's, and in the game the fin is a panel that would be handed the slipstream and work it out itself.
inline float swirl_yaw(const Pull& p, float along, float fin_area, float fin_slope, float fin_arm) {
    const float tube = std::fmax(along + p.slipstream, 1.0f);
    const float angle = std::atan2(p.swirl, tube);
    const float q = 0.5f * kRho * tube * tube;
    return -q * fin_area * fin_slope * angle * fin_arm;
}

}  // namespace prop
}  // namespace flightcore
