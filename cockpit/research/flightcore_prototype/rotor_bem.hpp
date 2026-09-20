#pragma once
/// ## A ROTOR DISC FROM ITS BLADES: the prototype of the shared rotor block (lane/flightcore, step 0).
///
/// What it is: blade-element momentum for one disc, pure and stateless. The collective is BLADE PITCH, so thrust comes
/// from the blades and the air through the disc and knows nothing of the helicopter's weight. The power is the one
/// momentum theory gives, T (Vc + vi) with Vc the air along the mast, which carries the climb AND, through a disc tilted
/// into its flight path, the power to push the fuselage along, so there is no parasite term to type. The engine limits
/// the power; with nothing from the engine the disc holds only what the descent pays for, which is autorotation.
///
/// The decision: replace `rotor_disc.hpp`'s weight fraction with this, because that disc (a) left the climb out of its
/// power, so the Little Bird climbed at 53 m/s held flat out against the book's 10.5, (b) jumped from 0.63 of the weight
/// to nothing at lever 0.08, and (c) sank at 11.9 m/s in autorotation whatever the forward speed
/// (`../flight_model_review.md`, section 7).
///
/// What went wrong before: every one of those was a formula typed to hit one figure (a weight share to hover, 1.2 vh to
/// autorotate, 18 per cent for translational lift) while the physics that would have given all of them was sitting in
/// the same file, only used for a power clip that never bound.
///
/// Sources: Leishman, Principles of Helicopter Aerodynamics (2nd ed.), ch. 2 (momentum theory, the vortex-ring empirical
/// inflow, ground effect after Cheeseman and Bennett), ch. 3 (blade-element momentum, CT = sigma a / 2 (theta (1/3 +
/// mu^2 / 2) - lambda / 2)) and ch. 5 (forward flight, Glauert's inflow, profile power 1 + 4.65 mu^2).

#include <cmath>

namespace flightcore {
namespace bem {

#ifdef FLIGHTCORE_COUNT
inline int g_pitch_calls = 0;
inline int g_ring_steps = 0;
#define FC_COUNT(x) (++(x))
#else
#define FC_COUNT(x) ((void)0)
#endif

constexpr float kRho = 1.225f;
constexpr float kG = 9.81f;
constexpr float kPi = 3.14159265f;

/// ONE DISC, from what a drawing and a data sheet give.
struct Rotor {
    float radius = 4.176f;
    int blades = 6;
    float chord = 0.183f;       // m
    float tip_speed = 215.0f;   // m/s, Omega R
    float lift_slope = 5.73f;   // per radian, a blade section
    float cd0 = 0.0095f;        // a blade section's profile drag
    float kappa = 1.15f;        // induced power over ideal
    /// THE BLADES' OWN LIMIT: the most CT / sigma the disc holds before the retreating blade stalls, and the advance
    /// ratio at which it has fallen to nothing. A rotor's usable thrust falls as it goes faster, because the retreating
    /// side sees less and less airspeed and has to work at more and more angle (Leishman ch. 7's CT/sigma against mu
    /// boundary, taken as a parabola through it). Without it the disc has no top speed of its own: the prototype's
    /// Black Hawk and Apache held height at 210 kt against published figures near 155.
    float stall_limit = 0.15f;
    float stall_mu = 0.60f;
    float theta_low = 0.0f;      // blade pitch at the bottom of the lever, radians: flat pitch
    float theta_high = 0.28f;   // and at the top
    float max_power = 317000.0f;  // W at the rotor, with the engine running
    float hub_height = 2.75f;   // over the skids
};

inline float area(const Rotor& r) { return kPi * r.radius * r.radius; }
inline float solidity(const Rotor& r) { return r.blades * r.chord / (kPi * r.radius); }

struct State {
    float thrust = 0.0f;   // N along the mast
    float induced = 0.0f;  // m/s through the disc, down
    float power = 0.0f;    // W the disc absorbs (negative: the air drives it)
    float theta = 0.0f;    // the blade pitch it flew at
    bool power_limited = false;
    /// The retreating blade has stalled: the disc is holding all it can at this speed.
    bool blade_stalled = false;
};

/// The vortex-ring state's inflow, as a share of the hover's, from the descent as a share of it: Leishman's
/// empirical fit to flight and wind-tunnel data (eq. 2.126), valid from -2 to 0.
inline float ring_inflow(float x) {
    return 1.15f - 1.125f * x - 1.372f * x * x - 1.718f * x * x * x - 0.655f * x * x * x * x;
}

/// THE INDUCED INFLOW OUT OF GROUND EFFECT, u = vi / Omega R, where blade element and momentum agree:
/// f(u) = u - CT(lambda_c + g u) / (2 sqrt(mu^2 + (lambda_c + u)^2)) = 0, with the ground's factor g on the inflow the
/// blades feel, so a hover in ground effect needs (1 - (R/4z)^2) of the induced velocity, as Cheeseman and Bennett have
/// it. This is the working state, flow down through the disc; a slow axial descent is the vortex ring's and a fast one
/// the windmill's (`at_pitch`).
///
/// FROM A GOOD START, NOT A BRACKET'S END. The axial answer is a quadratic (2 u (lambda_c + u) = CT with CT linear in
/// u), and the edgewise flow only widens the root, so it starts within a few per cent everywhere; three Newton steps
/// with an analytic slope then hold the thrust to newtons. Kept inside [0, the bracket's bound], so it cannot run to the
/// roots that are not there: an unbracketed Newton from a fixed start gave a hovering disc -37 kN at lever 0.05, and a
/// bracketed one from its far end took five steps to be merely close (a hover lever 0.05 off).
inline float inflow(float theta_term, float half_sa, float mu, float lambda_c, float ground) {
    const float ct0 = half_sa * (theta_term - 0.5f * lambda_c);
    const float k = 0.5f * half_sa * ground;  // CT = ct0 - k u
    // The axial root of 2 u^2 + (2 lambda_c + k) u - ct0 = 0, on the side of ct0's sign.
    const float b = 2.0f * lambda_c + k;
    const float disc = std::sqrt(std::fmax(b * b + 8.0f * std::fabs(ct0), 0.0f));
    const float axial = ct0 >= 0.0f ? (-b + disc) * 0.25f : -((b + disc) * 0.25f);
    // And the edgewise flow's share of the root: the momentum root with the axial answer in it.
    const float l0 = lambda_c + axial;
    float u = (ct0) / (2.0f * std::sqrt(mu * mu + l0 * l0) + k + 1e-6f);
    const float lo = ct0 >= 0.0f ? 0.0f : -std::fabs(axial) * 2.0f - 0.05f;
    const float hi = ct0 >= 0.0f ? std::fabs(axial) * 2.0f + 0.05f : 0.0f;
    for (int i = 0; i < 3; ++i) {
        const float l = lambda_c + u;
        const float root = std::sqrt(mu * mu + l * l);
        const float d = root + 1e-5f;
        const float ct = ct0 - k * u;
        const float f = u - ct / (2.0f * d);
        const float slope = 1.0f - (-k * d - ct * (root > 1e-9f ? l / root : 0.0f)) / (2.0f * d * d);
        float next = std::fabs(slope) > 1e-6f ? u - f / slope : u;
        next = next < lo ? 0.5f * (u + lo) : (next > hi ? 0.5f * (u + hi) : next);
        u = next;
    }
    return u;
}

/// HOW FAR THE EDGEWISE FLOW REACHES INTO THE RING, as multiples of the hover's inflow: past it the ring is gone.
constexpr float kRingReach = 3.0f;

/// THE RING'S SHARE OF THE INFLOW at an edgewise flow of `e` hover inflows: all of it hovering, half at about 1.5, and
/// exactly none from `kRingReach` out, reached smoothly (1 / (1 + (e / 1.5)^4), less its value at the reach, rescaled).
inline float ring_share(float e) {
    const float x = e / 1.5f;
    const float reach = kRingReach / 1.5f;
    const float at_reach = 1.0f / (1.0f + reach * reach * reach * reach);
    const float raw = 1.0f / (1.0f + x * x * x * x);
    return std::fmax(raw - at_reach, 0.0f) / (1.0f - at_reach);
}

/// THE AXIAL DESCENT'S INDUCED VELOCITY as a share of the hover's, from the descent as a share of it: the vortex ring's
/// empirical curve down to twice the hover's inflow, and momentum theory's windmill-brake branch past it.
inline float descent_inflow(float x) {
    if (x > -2.0f) {
        return std::fmax(ring_inflow(x), 0.0f);
    }
    return -0.5f * x - std::sqrt(0.25f * x * x - 1.0f);
}

/// THE DISC AT A BLADE PITCH. `climb` is the air along the mast through the disc, m/s, positive when it flows down
/// through it (climbing, or a disc tilted into its flight path); `edgewise` the air across the disc's plane, any
/// direction; `height` the hub over what is under it.
inline State at_pitch(const Rotor& r, float theta, float climb, float edgewise, float height) {
    FC_COUNT(g_pitch_calls);
    const float omega_r = r.tip_speed;
    const float sigma = solidity(r);
    const float mu = edgewise / omega_r;
    const float lambda_c = climb / omega_r;
    // Ground effect: the induced velocity falls under about a diameter (Cheeseman and Bennett, 1 - (R / 4z)^2).
    const float z = std::fmax(height, 0.5f * r.radius);
    const float q = r.radius / (4.0f * z);
    const float ground = std::fmax(1.0f - q * q, 0.6f);
    const float half_sa = 0.5f * sigma * r.lift_slope;
    const float theta_term = theta * (1.0f / 3.0f + 0.5f * mu * mu);
    const float disc = area(r);
    const float scale = kRho * disc * omega_r * omega_r;
    float vi = ground * inflow(theta_term, half_sa, mu, lambda_c, ground) * omega_r;
    // IN AN AXIAL DESCENT momentum theory's working state is not the flow: the vortex ring's empirical curve, then the
    // windmill's, solved together with the thrust it makes by bisection on the induced velocity (a fixed point
    // oscillated between the two branches and settled on none), and blended out by the edgewise flow, which blows the
    // ring away (Leishman ch. 2).
    // Only where the ring can be: the blend below falls smoothly to exactly nothing at an edgewise flow of three times
    // the hover's inflow, so past that the bisection is skipped with nothing lost and no step. It was 4.5 times with a
    // blend that never quite reached zero, and an autorotation at 40 m/s paid for the ring four times a tick (920 ns).
    const float vh_now = std::sqrt(std::fmax(half_sa * (theta_term - 0.5f * (lambda_c + vi / omega_r)) * scale, 1.0f)
                                   / (2.0f * kRho * disc));
    if (climb < 0.0f && edgewise < kRingReach * vh_now) {
        const auto thrust_at = [&](float v) { return half_sa * (theta_term - 0.5f * (climb + v) / omega_r) * scale; };
        const auto g = [&](float v) {
            const float t = thrust_at(v);
            if (t <= 0.0f) {
                return v;  // no thrust, no induced flow: the root is below
            }
            const float vh = std::sqrt(t / (2.0f * kRho * disc));
            return v - ground * descent_inflow(climb / vh) * vh;
        };
        // ILLINOIS' REGULA FALSI inside the bracket [no induced flow, the flow that leaves no thrust]: the curve is smooth
        // there, and four steps hold the thrust to tens of newtons where eight halvings cost twice as much (each step is
        // a square root, a division and the ring's polynomial: about 20 ns).
        float lo = 0.0f;
        float hi = std::fmax(2.0f * theta_term * omega_r - climb, 0.0f);  // where the thrust reaches nothing
        float glo = g(lo);
        float ghi = g(hi);
        float v = lo;
        if (glo < 0.0f && ghi >= 0.0f) {
            int side = 0;
            for (int i = 0; i < 5; ++i) {
                const float c = (lo * ghi - hi * glo) / (ghi - glo);
                const float gc = g(c);
                FC_COUNT(g_ring_steps);
                if (gc < 0.0f) {
                    lo = c;
                    glo = gc;
                    if (side == -1) ghi *= 0.5f;
                    side = -1;
                } else {
                    hi = c;
                    ghi = gc;
                    if (side == 1) glo *= 0.5f;
                    side = 1;
                }
            }
            v = (lo * ghi - hi * glo) / (ghi - glo);
        }
        const float vh = std::sqrt(std::fmax(thrust_at(v), 1.0f) / (2.0f * kRho * disc));
        const float axial = ring_share(edgewise / std::fmax(vh, 0.1f));
        vi = vi + (v - vi) * axial;
    }
    float thrust = half_sa * (theta_term - 0.5f * (climb + vi) / omega_r) * scale;
    // AND WHAT THE BLADES WILL HOLD AT THIS SPEED: past the boundary the retreating blade is stalled and the extra pitch
    // buys nothing. A clamp, not a fade, because what it stands for is a blade that has run out of angle.
    const float most = r.stall_limit * std::fmax(1.0f - mu * mu / (r.stall_mu * r.stall_mu), 0.0f) * sigma * scale;
    bool stalled = false;
    if (thrust > most) {
        thrust = most;
        stalled = true;
    }
    State s;
    s.blade_stalled = stalled;
    s.thrust = thrust;
    s.induced = vi;
    s.theta = theta;
    const float profile = sigma * r.cd0 / 8.0f * (1.0f + 4.65f * mu * mu) * scale * omega_r;
    s.power = r.kappa * thrust * vi + thrust * climb + profile;
    return s;
}

/// THE DISC AT A LEVER, with the power the engine can give (`engine` 1 running, 0 at idle). Past it the blade pitch is
/// what the power holds (the rotor would droop): so the climb stops where the engine runs out, and with the engine at
/// idle the disc carries only what the descent pays for. Power is nearly straight in pitch, so two secant steps from
/// the lever's pitch and flat pitch find it.
inline State fly(const Rotor& r, float lever, float climb, float edgewise, float height, float engine = 1.0f) {
    const float pitch = r.theta_low + (r.theta_high - r.theta_low) * (lever < 0.0f ? 0.0f : (lever > 1.0f ? 1.0f : lever));
    const float available = r.max_power * engine;
    State hi = at_pitch(r, pitch, climb, edgewise, height);
    if (hi.power <= available) {
        return hi;
    }
    // THE THRUST THE POWER HOLDS, found with the inflow of the last pass: P = kappa T vi + climb T + profile.
    // - CLIMBING OR LEVEL (kappa vi + climb > 0): the power grows with thrust, so the thrust that meets the power
    //   available is (available - profile) / (kappa vi + climb), a linear step that settles in two or three passes.
    // - DESCENDING WITH THE AIR DRIVING THE DISC (kappa vi + climb <= 0, on the way into an autorotation): taking vi to
    //   grow with T, momentum theory's shape at speed, the power is a parabola in T, and the thrust the engine can hold
    //   is its larger root. Where there is none below the lever's thrust, a real rotor droops, and flat pitch stands in.
    // A linear step alone broke off in the second case and left the disc drawing power it had not got (6.3 m/s of sink
    // at 55 m/s forward against the 8.8 the power balance gives); the parabola alone overshot a climb (336 kW of 317).
    // Up to four passes, done when the power is within 1 per cent (or a kilowatt) of what is available.
    State best = hi;
    State at = hi;
    const float omega_r = r.tip_speed;
    const float mu = edgewise / omega_r;
    const float half_sa = 0.5f * solidity(r) * r.lift_slope;
    const float scale = kRho * area(r) * omega_r * omega_r;
    for (int i = 0; i < 4; ++i) {
        // WITHIN 5 kW (or 1 per cent of what the engine gives, whichever is more): 5 kW is 0.4 m/s of climb or sink on
        // a 1.4 tonne helicopter and less on a bigger one, and chasing it exactly cost two more passes of the blades.
        const float tolerance = std::fmax(5000.0f, 0.01f * available);
        if (at.power <= available + tolerance && i > 0) {
            // UNDER THE POWER AVAILABLE IS NOT A PROBLEM TO SOLVE: the engine is no longer the limit, and a pass spent
            // creeping back up to it cost more than the thrust it found (an autorotation at 40 m/s took five passes).
            break;
        }
        const float carry = r.kappa * at.induced + climb;
        const float profile = at.power - at.thrust * carry;
        float want = -1.0f;
        if (carry > 1e-3f) {
            want = (available - profile) / carry;
        } else {
            const float quad = r.kappa * std::fmax(at.induced, 0.0f) / std::fmax(at.thrust, 1.0f);
            const float c = profile - available;
            const float disc = climb * climb - 4.0f * quad * c;
            if (quad > 1e-9f && disc >= 0.0f) {
                want = (-climb + std::sqrt(disc)) / (2.0f * quad);
            }
        }
        float t = r.theta_low;
        if (want > 0.0f) {
            const float lambda = (climb + at.induced) / omega_r;
            t = (want / (scale * half_sa) + 0.5f * lambda) / (1.0f / 3.0f + 0.5f * mu * mu);
            t = t < r.theta_low ? r.theta_low : (t > pitch ? pitch : t);
        }
        const float was = at.power;
        at = at_pitch(r, t, climb, edgewise, height);
        best = at;
        // NOWHERE LEFT TO GO: flat pitch, or a pass that changed nothing because the retreating blade is stalled and
        // less pitch buys no less thrust. A real rotor droops from here; another pass would only cost time (an
        // autorotation at 40 m/s took five passes and 953 ns before this).
        if (t <= r.theta_low || std::fabs(at.power - was) < 0.02f * std::fabs(was)) {
            break;
        }
    }
    best.power_limited = true;
    return best;
}

}  // namespace bem
}  // namespace flightcore
