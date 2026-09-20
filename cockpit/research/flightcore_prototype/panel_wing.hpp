#pragma once
/// ## AN AEROPLANE AS A LIST OF PANELS: the prototype of the generalised surfaces block (lane/flightcore, step 0).
///
/// What it is: the game's `lifting_surfaces.hpp` with its shape opened up. There, a `Planform` is one wing, one
/// tailplane and one fin, and `build_wing` fills four surfaces in a fixed order with the fin's normal hard to port and
/// the tailplane at index 2. Here an airframe is a LIST of panels, each with its own place, normal, area, aspect ratio,
/// incidence and controls, and everything else is derived from the list: the lift slopes, the downwash, the neutral
/// point, the centre of gravity, and the incidence that trims it.
///
/// The decision: a list, because the aeroplanes still to move do not fit four surfaces in a fixed order.
/// - The F/A-18F has TWO FINS, canted 20 degrees, and its tailplanes are STABILATORS that roll as well as pitch.
/// - The P-38 has TWO BOOMS: two fins 2.438 m out from the centreline, and a tailplane spanning between them.
/// - The F-16 rolls with its tailplanes too, and the F-14 with spoilers.
/// None of those can be said in the four-surface table, and each would otherwise become a branch in the builder.
///
/// What this keeps from the game's header, deliberately: the surface's own arithmetic (`coefficients`, the local
/// airflow, the stall's blend to a flat plate), the control law's interface, purity and statelessness. Only the shape
/// of the description changes.
///
/// Sources for the derivations: Perkins and Hage, Airplane Performance Stability and Control, ch. 5 (the neutral point
/// as the lift slopes' weighted station, the downwash behind a wing); Roskam, Airplane Design VI (end-plated
/// tailplanes, control surface effectiveness); the game's own `build_wing`, whose results this must reproduce exactly
/// for the Cessna.

#include <cmath>
#include <cstring>
#include <array>

namespace flightcore {
namespace panels {

constexpr float kRho = 1.225f;
constexpr float kG = 9.81f;
constexpr float kPi = 3.14159265f;

/// THE CHANNELS A PANEL'S CONTROL CAN SIT ON. The same four the game has, in the same order.
enum Channel { kPitch = 0, kRoll = 1, kYaw = 2, kFlaps = 3, kChannels = 4 };

/// HOW MANY PANELS AN AEROPLANE MAY HAVE HERE. The game's `kMostSurfaces` is 6, which holds the F/A-18F exactly and
/// leaves nothing for a wing described in two pairs (an inner and an outer panel), a canard, or a B-17's four-engine
/// nacelle wash. Eight is what a build would raise it to; it costs four more slots in a table built once at load.
constexpr int kMostPanels = 10;

struct Vec {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
};
inline Vec operator+(Vec a, Vec b) { return {a.x + b.x, a.y + b.y, a.z + b.z}; }
inline Vec operator-(Vec a, Vec b) { return {a.x - b.x, a.y - b.y, a.z - b.z}; }
inline Vec operator*(Vec a, float s) { return {a.x * s, a.y * s, a.z * s}; }
inline float dot(Vec a, Vec b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
inline Vec cross(Vec a, Vec b) { return {a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x}; }

/// ONE PANEL, as the game's `Surface` has it, with what the builder needs to derive the rest kept beside it.
struct Panel {
    const char* name = "";
    /// Aerodynamic centre, metres from the mass centre, body axes (+X right, +Y up, +Z aft).
    Vec at{};
    Vec normal{0.0f, 1.0f, 0.0f};
    Vec chord{0.0f, 0.0f, -1.0f};
    float area = 0.0f;
    float slope = 0.0f;
    float alpha0 = 0.0f;
    float stall = 0.3f;
    float cd0 = 0.008f;
    float k = 0.05f;
    float downwash = 0.0f;
    float mix_up[kChannels] = {0.0f, 0.0f, 0.0f, 0.0f};
    float mix_down[kChannels] = {0.0f, 0.0f, 0.0f, 0.0f};
    float stall_break = 1.0f;
    /// What the builder needs and the tick does not: the panel's own span and how much of the wing's lift it counts
    /// toward the neutral point, plus which panel is trimmed to balance the aeroplane.
    float span = 0.0f;
    bool carries_the_weight = false;  // a wing panel: its area is the reference area
    bool trims = false;               // the panel whose incidence is derived (a tailplane, a stabilator, a canard)
};

struct Airframe {
    int count = 0;
    Panel panel[kMostPanels]{};
    float rho = kRho;
    float area = 0.0f;   // the reference area: the wing panels' sum
    float clmax = 1.4f;
    float flap_clmax = 0.0f;
    float mac = 1.0f;
    Vec centre{};        // the centre of gravity, from the hull box's middle
    Vec inertia{};
    float neutral = 0.0f;       // the neutral point's station, for the report
    float cg_station = 0.0f;
    float static_margin = 0.15f;
    float trim_incidence = 0.0f;
    float cruise = 0.0f;
};

/// A finite wing's lift slope from its aspect ratio, as the game has it.
inline float finite_slope(float aspect) { return 6.2831853f * aspect / (aspect + 2.0f) * 0.92f; }

/// ---------------------------------------------------------------------------------------------------------------
/// THE DESCRIPTION: what a kind's file says. Stations are metres aft of the nose and heights metres over the ground at
/// rest, as every airframe in `cockpit/objects/vehicles/` is measured, so each number can be read off a drawing.
/// ---------------------------------------------------------------------------------------------------------------

struct Hull {
    float length = 0.0f;
    float rest = 0.0f;
    float mass = 1.0f;
    float static_margin = 0.15f;
    float cruise = 0.0f;
    float clmax = 1.4f;
    float flap_clmax = 0.0f;
};

/// A PAIR OF WING PANELS, left and right, from the drawing: the span, the area of both together, the quarter chord's
/// station and height at each panel's own spanwise centroid, the dihedral, the incidence, and the aileron's travel.
struct WingPair {
    float span = 0.0f;
    float area = 0.0f;
    float quarter_chord_station = 0.0f;
    float quarter_chord_height = 0.0f;
    float centroid_out = 0.0f;  // where each panel's lift acts, metres from the centreline
    float dihedral = 0.0f;
    float alpha0 = 0.0f;
    float aileron_up = 0.0f;
    float aileron_down = 0.0f;
    float aileron_share = 0.0f;
    float aileron_tau = 0.45f;
    float flap_share = 0.0f;  // what full flap adds, as an angle: the game's flap_clmax / slope
    float cd0 = 0.007f;
    float oswald = 0.8f;
};

/// A TAILPLANE OR A STABILATOR: one pair or one surface, at a station and a height, with an elevator's travel or the
/// whole surface moving. `rolls` is a stabilator that also answers the roll channel (the F/A-18F, the F-16).
struct Tail {
    float area = 0.0f;
    float span = 0.0f;
    float station = 0.0f;
    float height = 0.0f;
    float out = 0.0f;        // each half's centroid from the centreline, or 0 for one surface on the centreline
    float elevator_up = 0.0f;
    float elevator_down = 0.0f;
    float tau = 0.5f;
    float roll_travel = 0.0f;  // a stabilator's differential travel, radians, or 0
    float anhedral = 0.0f;
    float cd0 = 0.009f;
    bool end_plated = false;   // between two booms: the fins act as end plates and its aspect ratio behaves as larger
};

/// A FIN: one on the centreline, or two out on booms, canted or upright.
struct Fin {
    float area = 0.0f;        // each fin's own area
    float height = 0.0f;      // each fin's height, for the aspect ratio
    float station = 0.0f;
    float centroid_height = 0.0f;
    float out = 0.0f;         // 0 for one fin on the centreline, else each fin's distance from it
    int count = 1;
    float cant = 0.0f;        // radians from upright, tops outboard (the F/A-18F's 20 degrees)
    float rudder_travel = 0.0f;
    float tau = 0.6f;
    float cd0 = 0.009f;
    bool end_plated_by_the_fuselage = true;  // a single fin's aspect ratio doubles; a boom fin's does not
};

inline Panel& add(Airframe& a) { return a.panel[a.count++]; }

inline void add_wing(Airframe& a, const Hull& h, const WingPair& w) {
    const float aspect = w.span * w.span / w.area;
    const float slope = finite_slope(aspect);
    for (int side = 0; side < 2; ++side) {
        const float sgn = side == 0 ? 1.0f : -1.0f;
        Panel& p = add(a);
        p.name = side == 0 ? "wing right" : "wing left";
        p.at = {sgn * w.centroid_out, w.quarter_chord_height - h.rest, w.quarter_chord_station - 0.5f * h.length};
        p.normal = {-sgn * std::sin(w.dihedral), std::cos(w.dihedral), 0.0f};
        p.area = 0.5f * w.area;
        p.span = 0.5f * w.span;
        p.slope = slope;
        p.alpha0 = w.alpha0;
        p.stall = h.clmax / slope;
        p.cd0 = w.cd0;
        p.k = 1.0f / (kPi * w.oswald * aspect);
        p.carries_the_weight = true;
        const float up = w.aileron_tau * w.aileron_up * w.aileron_share;
        const float down = w.aileron_tau * w.aileron_down * w.aileron_share;
        p.mix_up[kRoll] = side == 0 ? -up : down;
        p.mix_down[kRoll] = side == 0 ? -down : up;
        p.mix_up[kFlaps] = w.flap_share;
    }
    a.area += w.area;
    a.mac = w.area / w.span;
}

/// THE TAILPLANE, as one surface or as a pair. A PAIR IS NOT DECORATION: a stabilator that rolls has to be two panels,
/// because the two halves do different things, and a tailplane between two booms is end-plated by them.
inline void add_tail(Airframe& a, const Hull& h, const Tail& t) {
    const float geometric = t.span * t.span / t.area;
    // END PLATES raise the effective aspect ratio: a tailplane hung between two fins behaves as a longer one (Roskam
    // VI; taken as 1.3, the usual figure for plates of a tail's own height). The Cessna's is not end-plated and is
    // unaffected, which is what keeps its numbers where they are.
    const float aspect = t.end_plated ? geometric * 1.3f : geometric;
    const float slope = finite_slope(aspect);
    const int halves = t.out > 0.0f ? 2 : 1;
    for (int side = 0; side < halves; ++side) {
        const float sgn = side == 0 ? 1.0f : -1.0f;
        Panel& p = add(a);
        p.name = halves == 1 ? "tailplane" : (side == 0 ? "tailplane right" : "tailplane left");
        p.at = {halves == 1 ? 0.0f : sgn * t.out, t.height - h.rest, t.station - 0.5f * h.length};
        p.normal = {halves == 1 ? 0.0f : sgn * std::sin(t.anhedral), std::cos(t.anhedral), 0.0f};
        p.area = t.area / float(halves);
        p.span = t.span / float(halves);
        p.slope = slope;
        p.stall = 0.30f;
        p.cd0 = t.cd0;
        p.k = 1.0f / (kPi * 0.8f * aspect);
        p.trims = true;
        p.mix_up[kPitch] = -t.tau * t.elevator_up;
        p.mix_down[kPitch] = -t.tau * t.elevator_down;
        // A STABILATOR ALSO ROLLS, the halves moving differentially. THE SIGN IS THE AILERON'S: a roll to the right
        // wants LESS lift on the right, so the right half's angle goes negative, as the right aileron's does in
        // `add_wing`. Written the other way round first, and it cost the aeroplane roll instead of buying it: 98
        // degrees a second against the 127 the ailerons gave on their own.
        if (t.roll_travel > 0.0f && halves == 2) {
            p.mix_up[kRoll] = -sgn * t.tau * t.roll_travel;
            p.mix_down[kRoll] = -sgn * t.tau * t.roll_travel;
        }
    }
}

/// THE FINS. One on the centreline, or a pair out on booms; canted if the drawing says so.
inline void add_fins(Airframe& a, const Hull& h, const Fin& f) {
    const float plate = f.end_plated_by_the_fuselage ? 2.0f : 1.0f;
    const float aspect = plate * f.height * f.height / f.area;
    const float slope = finite_slope(aspect);
    for (int i = 0; i < f.count; ++i) {
        const float sgn = f.count == 2 ? (i == 0 ? 1.0f : -1.0f) : 0.0f;
        Panel& p = add(a);
        p.name = f.count == 2 ? (i == 0 ? "fin right" : "fin left") : "fin";
        p.at = {sgn * f.out, f.centroid_height - h.rest, f.station - 0.5f * h.length};
        // A fin lifts sideways: slip from the right pushes it left and the nose swings right. Canted, its normal tips
        // toward the vertical, so a canted pair makes lift in pitch as well, which is the F/A-18F's tails all over.
        p.normal = {-std::cos(f.cant), (f.count == 2 ? sgn : 1.0f) * std::sin(f.cant), 0.0f};
        p.area = f.area;
        p.span = f.height;
        p.slope = slope;
        p.stall = 0.35f;
        p.cd0 = f.cd0;
        p.k = 1.0f / (kPi * 0.8f * aspect);
        p.mix_up[kYaw] = f.tau * f.rudder_travel;
        p.mix_down[kYaw] = f.tau * f.rudder_travel;
    }
}

/// ---------------------------------------------------------------------------------------------------------------
/// WHAT IS DERIVED once the panels are listed: the downwash on anything behind the wing, the neutral point, the centre
/// of gravity, and where every panel sits relative to it. This is `build_wing`'s second half, over a list.
/// ---------------------------------------------------------------------------------------------------------------
inline void settle(Airframe& a, const Hull& h) {
    // The wing's own slope and aspect ratio, for the downwash it leaves behind.
    float wing_slope = 0.0f;
    float wing_area = 0.0f;
    float wing_span = 0.0f;
    for (int i = 0; i < a.count; ++i) {
        if (a.panel[i].carries_the_weight) {
            wing_slope = a.panel[i].slope;
            wing_area += a.panel[i].area;
            wing_span += a.panel[i].span;
        }
    }
    const float wing_aspect = wing_span * wing_span / std::fmax(wing_area, 0.01f);
    const float downwash = 2.0f * wing_slope / (kPi * wing_aspect);
    // THE NEUTRAL POINT: every lifting panel's station weighted by what it adds to the lift slope, with anything in the
    // wing's wake counted through the downwash, and a fin counted not at all (it lifts sideways).
    float weight = 0.0f;
    float moment = 0.0f;
    for (int i = 0; i < a.count; ++i) {
        Panel& p = a.panel[i];
        if (p.normal.y < 0.5f) {
            continue;  // a fin
        }
        if (!p.carries_the_weight) {
            p.downwash = downwash;
        }
        const float share = p.slope * p.area * (p.carries_the_weight ? 1.0f : 1.0f - downwash);
        weight += share;
        moment += share * (p.at.z + 0.5f * h.length);  // back to a station
    }
    a.neutral = moment / std::fmax(weight, 1e-6f);
    a.cg_station = a.neutral - h.static_margin * a.mac;
    a.static_margin = h.static_margin;
    a.centre = {0.0f, 0.0f, a.cg_station - 0.5f * h.length};
    a.clmax = h.clmax;
    a.flap_clmax = h.flap_clmax;
    a.cruise = h.cruise;
    // Every panel's arm is from the centre of gravity, not from the box's middle.
    for (int i = 0; i < a.count; ++i) {
        a.panel[i].at.y -= a.centre.y;
        a.panel[i].at.z -= a.centre.z;
    }
}

/// ---------------------------------------------------------------------------------------------------------------
/// THE TICK: the same arithmetic the game's `evaluate` does, over the list.
/// ---------------------------------------------------------------------------------------------------------------
inline void coefficients(const Panel& s, float angle, float control, float sin2a, float sinsq, float& cl, float& cd,
                         float& dcl) {
    const float over = std::fabs(angle) - s.stall;
    if (over <= 0.0f) {
        dcl = s.slope;
        cl = s.slope * (angle + control);
        cd = s.cd0 + s.k * cl * cl;
        return;
    }
    const float t = std::fmin(1.0f, over / 0.15f) * s.stall_break;
    const float peak = (angle > 0.0f ? 1.0f : -1.0f) * s.slope * s.stall;
    const float plate = 1.1f * sin2a;
    dcl = s.slope * (1.0f - t);
    cl = peak + (plate - peak) * t + dcl * control;
    cd = s.cd0 + s.k * cl * cl + 1.2f * sinsq * t;
}

struct Loads {
    Vec force{};
    Vec torque{};
};

/// `v` is the mass centre's velocity through the air and `w` the body rates, both body axes; `u` the stick.
inline Loads evaluate(const Airframe& a, Vec v, Vec w, const float u[kChannels], float wing_alpha) {
    Loads out;
    for (int i = 0; i < a.count; ++i) {
        const Panel& s = a.panel[i];
        const Vec local = v + cross(w, s.at);
        const float vn = dot(local, s.normal);
        const float vc = dot(local, s.chord);
        const float vv = vn * vn + vc * vc;
        if (vv < 1.0f) {
            continue;
        }
        const float inv = 1.0f / std::sqrt(vv);
        const float alpha = std::atan2(-vn, std::fmax(vc, 0.1f));
        const float angle = alpha + s.alpha0 - s.downwash * wing_alpha;
        float control = 0.0f;
        for (int c = 0; c < kChannels; ++c) {
            control += u[c] * (u[c] >= 0.0f ? s.mix_up[c] : s.mix_down[c]);
        }
        const float sin2a = -2.0f * vn * vc * inv * inv;
        const float sinsq = vn * vn * inv * inv;
        float cl = 0.0f;
        float cd = 0.0f;
        float dcl = 0.0f;
        coefficients(s, angle, control, sin2a, sinsq, cl, cd, dcl);
        const float qs = 0.5f * a.rho * vv * s.area;
        const Vec lift_dir = (s.normal * vc - s.chord * vn) * inv;
        const Vec drag_dir = (s.normal * vn + s.chord * vc) * -inv;
        const Vec f = lift_dir * (qs * cl) + drag_dir * (qs * cd);
        out.force = out.force + f;
        out.torque = out.torque + cross(s.at, f);
    }
    return out;
}

/// THE ANGLE OF ATTACK THAT CARRIES THE WEIGHT at a speed, and the pitching moment there.
inline void level_at(const Airframe& a, float mass, float speed, float& alpha, float& moment) {
    float lo = -0.25f;
    float hi = 0.45f;
    const float none[kChannels] = {0.0f, 0.0f, 0.0f, 0.0f};
    for (int i = 0; i < 48; ++i) {
        alpha = 0.5f * (lo + hi);
        const Loads l = evaluate(a, Vec{0.0f, -speed * std::sin(alpha), -speed * std::cos(alpha)}, Vec{}, none, alpha);
        const float up = l.force.y * std::cos(alpha) - l.force.z * std::sin(alpha);
        (up < mass * kG ? lo : hi) = alpha;
        moment = l.torque.x;
    }
}

/// THE TRIMMING PANEL'S INCIDENCE, derived: whatever balances the aeroplane at its cruise with the stick centred. Every
/// panel marked `trims` gets it, so a stabilator pair moves together.
inline void trim(Airframe& a, float mass, float cruise) {
    float lo = -0.25f;
    float hi = 0.25f;
    for (int i = 0; i < 48; ++i) {
        const float guess = 0.5f * (lo + hi);
        for (int p = 0; p < a.count; ++p) {
            if (a.panel[p].trims) {
                a.panel[p].alpha0 = guess;
            }
        }
        float alpha = 0.0f;
        float moment = 0.0f;
        level_at(a, mass, cruise, alpha, moment);
        (moment > 0.0f ? lo : hi) = guess;
    }
    a.trim_incidence = 0.5f * (lo + hi);
}

/// The stall speed, as the game has it.
inline float stall_speed(const Airframe& a, float mass, float flaps) {
    const float cl = std::fmax(a.clmax + flaps * a.flap_clmax, 0.05f);
    return std::sqrt(2.0f * mass * kG / (a.rho * std::fmax(a.area, 0.01f) * cl));
}

}  // namespace panels
}  // namespace flightcore
