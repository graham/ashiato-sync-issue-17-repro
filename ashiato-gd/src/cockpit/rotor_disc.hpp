#pragma once

/// A HELICOPTER THAT FLIES ON ITS ROTOR DISC (Little Bird, 2026-09-19).
///
/// Momentum theory with Glauert's forward-flight inflow, Cheeseman–Bennett ground effect,
/// a vortex-ring envelope, and a quasi-steady autorotation. Thrust still acts along the
/// mast (body up): pitching the body is how the cyclic translates. What this replaces is
/// the magnitude of that thrust, which was `mass * g * collective` in every phase, with
/// climb and cruise capped by typed body drags.
///
/// PURE AND STATELESS, and that is a rollback decision: nothing here remembers a tick.
/// There is no rotor RPM on the wire. Autorotation is the inflow at idle collective, not
/// stored blade energy. A flare that dumps RPM is WHAT IS NOT HERE YET.
///
/// Behind `Handling::rotors`. Default on for the Little Bird only. `--set=rotors=0` is
/// the old thruster. See `cockpit/research/littlebird_rotor_plan.md`.
///
/// Body axes are the game's: +X right, +Y up, +Z aft (the nose is -Z).

#include <cmath>

namespace ashiato_gd {
namespace cockpit {
namespace rotor {

constexpr float kSeaLevelDensity = 1.225f;
constexpr float kGravity = 9.81f;
constexpr float kPi = 3.14159265f;

enum Mutant {
    kNoGroundEffect = 1,
    kNoTranslationalLift = 2,
    kNoVortexRing = 4,
    kNoAutorotation = 8,
};

enum Phase {
    kGround = 0,
    kIgeHover = 1,
    kOgeHover = 2,
    kTranslating = 3,
    kForward = 4,
    kVortexRing = 5,
    kAutorotation = 6,
};

inline const char* phase_name(Phase p) {
    switch (p) {
        case kGround: return "ground";
        case kIgeHover: return "ige_hover";
        case kOgeHover: return "oge_hover";
        case kTranslating: return "translating";
        case kForward: return "forward";
        case kVortexRing: return "vortex_ring";
        case kAutorotation: return "autorotation";
        default: return "unknown";
    }
}

/// ONE DISC, read off the kind. Numbers a book can give; nothing typed twice.
struct Disc {
    float radius = 4.176f;
    float mass = 1406.0f;
    /// Watts at the rotor. 425 shp × 746.
    float max_power = 317000.0f;
    /// Parasite area, m^2, so cruise is a number the sheet published, not a drag fudge.
    float cda = 1.15f;
    /// Profile power as (solidity * blade Cd / 8), times rho A Vtip^3. ~0.000084 on this disc (~65 kW).
    float profile = 0.000084f;
    /// Rotor plane above the skids, metres.
    float hub_above_skids = 2.75f;
    /// Collective at which T = weight in OGE hover, as a fraction of the lever (the old `hover`).
    float hover = 0.55f;
    float collective_range = 0.95f;
    int mutant = 0;
};

struct Forces {
    /// Newtons along body up.
    float thrust = 0.0f;
    /// Induced velocity, m/s, positive down through the disc.
    float induced = 0.0f;
    float power = 0.0f;
    float ige = 0.0f;
    float etl = 0.0f;
    Phase phase = kOgeHover;
};

inline float clampf(float v, float lo, float hi) {
    return v < lo ? lo : (v > hi ? hi : v);
}

inline float disc_area(const Disc& d) { return kPi * d.radius * d.radius; }

/// Hover induced velocity at this thrust, no forward speed.
inline float vh_at(const Disc& d, float thrust) {
    const float two_rho_a = 2.0f * kSeaLevelDensity * disc_area(d);
    if (thrust <= 0.0f || two_rho_a <= 0.0f) {
        return 0.0f;
    }
    return std::sqrt(thrust / two_rho_a);
}

/// Cheeseman–Bennett: induced velocity falls near the ground. 1 at OGE, ~0.75 at h = R/2.
inline float ground_effect(const Disc& d, float height_rotor) {
    if ((d.mutant & kNoGroundEffect) != 0) {
        return 1.0f;
    }
    const float h = std::fmax(height_rotor, 0.15f * d.radius);
    const float ratio = d.radius / (4.0f * h);
    return clampf(1.0f - ratio * ratio, 0.55f, 1.0f);
}

/// Glauert inflow: vi * sqrt(Vh^2 + (Vc + vi)^2) = vh^2. Four Newton steps from vh.
inline float induced_glauert(float vh, float along, float climb) {
    if (vh <= 1e-4f) {
        return 0.0f;
    }
    const float horiz = std::fmax(along, 0.0f);
    float vi = vh;
    for (int i = 0; i < 6; ++i) {
        const float w = climb + vi;
        const float mag = std::sqrt(horiz * horiz + w * w);
        if (mag < 1e-4f) {
            break;
        }
        vi = vh * vh / mag;
    }
    return vi;
}

/// Power to hold this thrust in this air, Watts.
inline float power_required(const Disc& d, float thrust, float vi, float speed) {
    const float induced = std::fmax(thrust, 0.0f) * std::fmax(vi, 0.0f);
    const float tip = 210.0f;
    const float profile = d.profile * kSeaLevelDensity * disc_area(d) * tip * tip * tip;
    const float parasite = 0.5f * kSeaLevelDensity * d.cda * speed * speed * speed;
    return induced + profile + parasite;
}

/// Clip thrust so the disc does not ask for more than max_power.
inline float clip_to_power(const Disc& d, float thrust, float along, float climb, float ige) {
    float hi = std::fmax(thrust, 0.0f);
    const float vh0 = vh_at(d, hi) * ige;
    const float vi0 = induced_glauert(vh0, along, climb);
    if (power_required(d, hi, vi0, along) <= d.max_power) {
        return hi;
    }
    float lo = 0.0f;
    for (int i = 0; i < 14; ++i) {
        const float mid = 0.5f * (lo + hi);
        const float vh = vh_at(d, mid) * ige;
        const float vi = induced_glauert(vh, along, climb);
        if (power_required(d, mid, vi, along) > d.max_power) {
            hi = mid;
        } else {
            lo = mid;
        }
    }
    return lo;
}

/// Quasi-steady autorotation: idle collective, descending, T from the inflow.
/// Steady at T = weight around 1.2 vh (~12 m/s on this disc).
inline float autorotation_thrust(const Disc& d, float sink) {
    if ((d.mutant & kNoAutorotation) != 0) {
        return 0.0f;
    }
    const float weight = d.mass * kGravity;
    const float vh = vh_at(d, weight);
    const float down = std::fmax(-sink, 0.0f);
    if (down < 2.0f) {
        return 0.0f;
    }
    return weight * clampf(down / (1.20f * std::fmax(vh, 1.0f)), 0.0f, 1.15f);
}

/// Vortex-ring share, 0 outside, 1 in the worst of the envelope (Leishman: mu_d 0.5 to 1.5, slow).
inline float vortex_ring(const Disc& d, float vh, float along, float climb) {
    if ((d.mutant & kNoVortexRing) != 0) {
        return 0.0f;
    }
    if (vh < 1.0f) {
        return 0.0f;
    }
    const float mu_d = -climb / vh;
    const float down = clampf(1.0f - std::fabs(mu_d - 1.0f) / 0.55f, 0.0f, 1.0f);
    const float slow = clampf(1.0f - along / (0.6f * vh), 0.0f, 1.0f);
    return down * slow;
}

inline Phase classify(float skid_agl, float along, float climb, float collective, float vrs,
                      float auto_t, float radius) {
    if (skid_agl < 0.35f && collective < 0.50f) {
        return kGround;
    }
    if (auto_t > 100.0f && collective < 0.12f && climb < -2.0f) {
        return kAutorotation;
    }
    if (vrs > 0.35f && collective > 0.3f) {
        return kVortexRing;
    }
    if (along < 5.0f) {
        return skid_agl + 2.75f < 1.25f * radius ? kIgeHover : kOgeHover;
    }
    if (along < 16.0f) {
        return kTranslating;
    }
    return kForward;
}

/// THE THRUST THIS COLLECTIVE MAKES in this air, at this height.
///
/// `collective` is the lever 0..1 (throttle on the wire). `along` is airspeed along the
/// nose, m/s. `climb` is airspeed along body up (positive climbing). `skid_agl` is the
/// skids over the ground.
inline Forces fly(const Disc& d, float collective, float along, float climb, float skid_agl) {
    Forces out;
    const float weight = d.mass * kGravity;
    const float lever = clampf(collective, 0.0f, 1.0f);
    // The wire's throttle 0..1 is the lever. Full down is idle (autorotation), not the
    // old 0.55 of weight: a helicopter that cannot dump lift cannot autorotate.
    const float height_rotor = skid_agl + d.hub_above_skids;
    out.ige = ground_effect(d, height_rotor);
    float along_in = along;
    if ((d.mutant & kNoTranslationalLift) != 0) {
        along_in = 0.0f;
    }
    out.etl = clampf((along - 8.0f) / 8.0f, 0.0f, 1.0f);
    if ((d.mutant & kNoTranslationalLift) != 0) {
        out.etl = 0.0f;
    }

    float t = 0.0f;
    float auto_t = 0.0f;
    if (lever < 0.08f) {
        auto_t = autorotation_thrust(d, climb);
        t = auto_t;
    } else {
        t = weight * (d.hover + lever * d.collective_range);
        t *= 1.0f / std::fmax(out.ige, 0.55f);
        t *= 1.0f + 0.18f * out.etl;
        t = clip_to_power(d, t, along_in, climb, out.ige);
    }

    const float vh = vh_at(d, std::fmax(t, weight * 0.5f));
    out.induced = induced_glauert(vh * out.ige, along_in, climb);
    const float vrs = vortex_ring(d, vh, along, climb);
    if (lever >= 0.08f) {
        t *= 1.0f - 0.65f * vrs;
    }

    out.thrust = std::fmax(t, 0.0f);
    out.power = power_required(d, out.thrust, out.induced, along);
    out.phase = classify(skid_agl, along, climb, lever, vrs, auto_t, d.radius);
    return out;
}

/// Little Bird / MD 530F family. Diameter 8.352 m, 1,406 kg, 425 shp, 135 kt cruise.
inline Disc littlebird() {
    Disc d;
    d.radius = 8.352f * 0.5f;
    d.mass = 1406.0f;
    d.max_power = 425.0f * 746.0f;
    // Sized so 15 degrees nose-down levels near 69 m/s, not 90: CdA ≈ 2T sin(alpha) / (rho V^2)
    // is the wrong tool; 1.15 m^2 is the parasite that, with remaining induced, meets 135 kt.
    d.cda = 0.85f;
    d.profile = 0.000084f;
    d.hub_above_skids = 2.75f;
    d.hover = 0.55f;
    d.collective_range = 0.95f;
    return d;
}

}  // namespace rotor
}  // namespace cockpit
}  // namespace ashiato_gd
