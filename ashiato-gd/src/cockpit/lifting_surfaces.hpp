#pragma once

/// AN AEROPLANE THAT FLIES ON ITS SURFACES (lane/flightmodel, 2026-09-18).
///
/// The wing, the tailplane and the fin, each a small flat wing with its own area, lift slope, stall and place, each
/// working out its own lift and drag from the airflow WHERE IT IS: the aeroplane's velocity through the air plus its
/// spin crossed with the surface's arm. The controls change a surface's lift. Stability, damping in all three axes,
/// adverse yaw, the dihedral effect, a wing that drops at the stall and a nose that rotates on the take-off roll are what
/// these do when the air at each surface differs, and nothing here types any of them.
///
/// WHAT IT REPLACES, per kind and behind `Handling::surfaces`: the lumped lift at the centre of mass and the rate servo
/// (`command_rate`) whose torque was tens to hundreds of times what a surface could make. That servo pushed a parked or
/// taxiing aeroplane over (lane/groundroll), buried a flying boat's float (lane/floats) and needed a pen round a parked
/// F-14 (lane/tomcat2). A surface's moment goes with the dynamic pressure, so at a standstill it is nothing.
///
/// THE PLAN AND ITS MEASUREMENTS are `cockpit/research/flight_model_plan.md`; the prototype that measured it is beside it.
/// Cost there: 70 ns per aircraft per tick for today's arithmetic, 113 ns for four surfaces and the control law.
///
/// PURE AND STATELESS, and that is a rollback decision: nothing here remembers a tick. The surfaces have no position (a
/// hand on a stick and an autopilot's PID are already rate-limited) and the control law has no integrator, so a replay
/// from a rewound `VehicleState` computes exactly what the first pass did. No Box3D and no Godot, so a prototype or a
/// test can include it as `autopilot.hpp` is included.
///
/// Body axes are the game's: +X right, +Y up, +Z aft (the nose is -Z). A pitch rate about +X is nose up; a yaw rate about
/// +Y is nose LEFT; a roll rate about -Z (forward) is right wing down.

#include <cmath>

namespace ashiato_gd {
namespace cockpit {
namespace aero {

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

constexpr float kSeaLevelDensity = 1.225f;
constexpr float kGravity = 9.81f;

/// The four things a hand or an autopilot moves. Flaps are a lever, never inverted by the control law.
enum Channel { kPitch = 0, kRoll = 1, kYaw = 2, kFlaps = 3, kChannels = 4 };

constexpr int kMostSurfaces = 6;

/// MUTANTS, for `tests/surfaces.gd` and nothing else: each takes away one piece of physics the suite says the surfaces
/// produce, and the check that names it must then fail. Zero in the game. Set through `Handling::surface_mutant`, so a
/// mutant costs a `--set` and not a build.
enum Mutant {
    kNoInducedDrag = 1,  // the wing panels' induced drag: adverse yaw goes with it
    kNoDihedral = 2,     // the panels flat, and the wing at the mass centre's height
    kNoElevator = 4,     // the tailplane's control mix
    kUnclampedLaw = 8,   // the control law may ask for more than full travel
    kNoStallBreak = 16,  // past the stall the lift holds its peak instead of falling away
};

/// ONE LIFTING SURFACE.
struct Surface {
    /// Aerodynamic centre: metres from the mass centre, body axes.
    Vec at{};
    /// Which way it lifts with the flow straight down its chord (unit). Up on a wing panel, tilted in by its dihedral;
    /// sideways on a fin.
    Vec normal{0.0f, 1.0f, 0.0f};
    /// Which way its leading edge faces (unit): forward, -Z, for everything today.
    Vec chord{0.0f, 0.0f, -1.0f};
    float area = 0.0f;
    /// dCL/dalpha per radian, finite span: 2 pi AR / (AR + 2), times 0.92.
    float slope = 0.0f;
    /// Radians of angle the surface has with the flow straight down the body: incidence plus camber. A tailplane's is
    /// DERIVED, by trimming the aeroplane level at cruise (`trim_the_tail`).
    float alpha0 = 0.0f;
    /// The angle, from zero lift, at which it gives its most: CLmax / slope.
    float stall = 0.3f;
    float cd0 = 0.008f;
    /// Induced drag, CD = cd0 + k CL^2, with k = 1 / (pi e AR).
    float k = 0.05f;
    /// d(epsilon)/d(alpha) of the wing's wake on a tailplane: 2 a / (pi AR) of the wing. Zero elsewhere.
    float downwash = 0.0f;
    /// Radians of effective angle per unit of each channel, one number for a positive input and one for a negative:
    /// ailerons move further up than down (the Cessna's 20 and 15 degrees), and so does an elevator (28 and 23).
    float mix_up[kChannels] = {0.0f, 0.0f, 0.0f, 0.0f};
    float mix_down[kChannels] = {0.0f, 0.0f, 0.0f, 0.0f};
    /// How far past the stall the lift falls away, 1 as built; 0 only under `kNoStallBreak`.
    float stall_break = 1.0f;
    /// THE SHARE OF IT IN THE PROPELLER'S SLIPSTREAM, 0 to 1 (`evaluate`'s `wash`): the tailplane and the fin behind a
    /// single engine's disc. Zero on every surface of a planform with no disc.
    float wash_share = 0.0f;
};

/// AN AEROPLANE'S SURFACES, and what was derived while building them.
struct Wing {
    int count = 0;
    Surface s[kMostSurfaces]{};
    float rho = kSeaLevelDensity;
    /// The wing's reference area and CLmax clean and with full flap, for the stall speed.
    float area = 0.0f;
    float clmax = 0.0f;
    float flap_clmax = 0.0f;
    /// Where the mass centre is, body axes (the hull box's middle is the origin), so that the moments are taken about
    /// the aeroplane's centre of gravity and not the collision box's.
    Vec centre{};
    /// The inertia the body is given with it: pitch about x, yaw about y, roll about z.
    Vec inertia{};
    float angular_damping = 0.2f;
    /// The body's own drags once the surfaces carry theirs, so the aeroplane's totals do not move.
    float body_drag_forward = 0.0f;
    float body_drag_side = 0.0f;
    float body_drag_vertical = 0.0f;
    /// Reports: the tail's derived incidence.
    float tail_incidence = 0.0f;
    /// THE UNDERSIDE, body axes from the origin: where the main wheels stand (z) and how high the hull's underside is
    /// at the tail (y). The collision hull follows it, so the aeroplane rotates about its main wheels on the take-off
    /// roll and not about the back corner of a box (`CockpitWorld::ensure_body`). Zero on both is the box.
    float mains_z = 0.0f;
    float tail_underside_y = 0.0f;
    /// THE UNDERSIDE AT THE BOX'S FRONT, body y, on the line from the mains through the drawn nose; 0 keeps the box's flat
    /// front. And the pitch DOWN about the mains at which that nose meets level ground, radians (`Planform::nose_underside_*`).
    float nose_underside_y = 0.0f;
    float nose_over = 0.0f;
    /// A TAILDRAGGER: its centre of gravity AFT of its main wheels, so it rests back on a tail wheel. DERIVED, never typed
    /// (`build_wing`): the static margin places the centre of gravity, and the drawing places the mains. A tricycle, its
    /// centre of gravity ahead of them, keeps every wheel force at the mass centre as it always did.
    bool taildragger = false;
    /// Where a taildragger's wheels touch, body axes in the level-built frame: the mains' ground line (y) and half their
    /// track (x), and the tail wheel's tyre bottom. With the three-point RAKE this puts it at, radians nose up, and how far
    /// its tail wheel steers (`Planform::tailwheel_steer`).
    float mains_y = 0.0f;
    float half_track = 0.0f;
    float tail_wheel_z = 0.0f;
    float tail_wheel_y = 0.0f;
    float rest_pitch = 0.0f;
    float tailwheel_steer = 0.0f;
    /// Only under `kUnclampedLaw`.
    bool unclamped = false;
    /// THE CRUISE IT IS PUBLISHED AT, m/s, or 0 to derive one (`CockpitWorld::cruise_over`). The tailplane is trimmed
    /// there and the autopilot flies it.
    float cruise = 0.0f;
    /// THE PROPELLER, where the planform has one (`Planform::thrust`): full-throttle thrust at a standstill, newtons, and
    /// the airspeed at which it has fallen to nothing. Zero thrust is `Handling::thrust`, constant, as every lumped wing has.
    float thrust = 0.0f;
    float thrust_gone_at = 0.0f;
    /// WHAT FULL FLAP HANGS IN THE AIR, N per (m/s)^2, from `Planform::flap_cd`, or 0 for `Handling::flap_drag`.
    float flap_drag = 0.0f;
    /// THE PROPELLER'S DISC, m^2, whose slipstream washes the tail (`Planform::prop_disc`); 0 for none.
    float disc_area = 0.0f;
};

/// THE WHOLE AEROPLANE'S DRAG AT ZERO LIFT, N per (m/s)^2: what the body keeps plus every surface's own profile.
inline float zero_lift_drag(const Wing& w) {
    float sum = w.body_drag_forward;
    for (int i = 0; i < w.count; ++i) {
        sum += 0.5f * w.rho * w.s[i].area * w.s[i].cd0;
    }
    return sum;
}

/// WHAT THE ENGINE PULLS at a throttle and an airspeed along the nose, newtons. A FIXED-PITCH PROPELLER's thrust falls
/// about linearly with speed, T0 (throttle - v / v0): at full throttle from its static figure to nothing at v0, where the
/// blades no longer bite; and throttled back it bites at less, so a closed throttle WINDMILLS, and the propeller is drag
/// -- which is most of why a real light aeroplane glides at 9 to 1 and not the 12 its airframe alone would give.
/// `fallback` is a lumped wing's constant thrust, for a planform with no propeller: throttle times it.
inline float thrust_at(const Wing& w, float throttle, float along, float fallback) {
    if (w.thrust <= 0.0f) {
        return throttle * fallback;
    }
    return w.thrust * (throttle - std::fmax(along, 0.0f) / std::fmax(w.thrust_gone_at, 1.0f));
}

/// THE PROPELLER'S SLIPSTREAM for `evaluate`: 2 T / (rho A), m^2/s^2, for a pull of `thrust` newtons; 0 with no disc or no
/// pull (a windmilling propeller's wake is slower than the air, and is left out).
inline float slipstream(const Wing& w, float thrust) {
    if (w.disc_area <= 0.0f || thrust <= 0.0f) {
        return 0.0f;
    }
    return 2.0f * thrust / (w.rho * w.disc_area);
}

/// THE STALL SPEED, m/s, with a share of full flap: the speed at which CLmax carries the weight.
inline float stall_speed(const Wing& w, float mass, float flaps) {
    const float cl = std::fmax(w.clmax + flaps * w.flap_clmax, 0.05f);
    return std::sqrt(2.0f * mass * kGravity / (w.rho * std::fmax(w.area, 0.01f) * cl));
}

/// Lift and drag coefficients of one surface at angle `a` (its geometric angle plus alpha0, flaps excluded) with a
/// control lift `control` (radians of effective angle). THE STALL IS JUDGED ON THE SURFACE'S OWN ANGLE and a control
/// moves the whole curve, so a flap raises CLmax; shifting the angle alone would not. Past the stall the curve blends to
/// a flat plate over 0.15 rad, and the controls fade to nothing across the same band, continuously -- a stalled
/// surface's control goes limp. `sin2a` and `sinsq` come from the velocity components, not from more trigonometry.
///
/// `dcl` is dCL per radian of control at this state, which the control law inverts.
inline void coefficients(const Surface& s, float a, float control, float sin2a, float sinsq, float& cl, float& cd,
                         float& dcl) {
    const float over = std::fabs(a) - s.stall;
    if (over <= 0.0f) {
        dcl = s.slope;
        cl = s.slope * (a + control);
        cd = s.cd0 + s.k * cl * cl;
        return;
    }
    const float t = std::fmin(1.0f, over / 0.15f) * s.stall_break;
    const float peak = (a > 0.0f ? 1.0f : -1.0f) * s.slope * s.stall;
    const float plate = 1.1f * sin2a;
    dcl = s.slope * (1.0f - t);
    cl = peak + (plate - peak) * t + dcl * control;
    cd = s.cd0 + s.k * cl * cl + 1.2f * sinsq * t;
}

/// WHAT THE SURFACES MAKE THIS TICK, body axes, before the stick; and what the stick would add.
struct Loads {
    Vec force{};
    Vec torque{};
    /// Force per radian of effective angle at each surface: its lift slope at this state times q S, plus the induced
    /// drag that comes with it (which is adverse yaw).
    Vec per_radian[kMostSurfaces]{};
    /// Moment per unit of pitch, roll and yaw, linearised here with each surface's mean travel: what the law inverts.
    Vec per_unit[3]{};
};

/// THE SURFACES WITH THE FLAPS WHERE THEY ARE AND THE STICK CENTRED. `v` is the mass centre's velocity through the air
/// and `w` the body rates, both body axes. `wing_alpha` is the wing's angle, for the tailplane's downwash.
///
/// The flaps go in exactly, because they move CLmax; the stick goes in afterwards, linearised (`add_the_stick`), which is
/// exact below the stall and lets the law and a raw stick share one pass. Summed in table order, always.
///
/// `wash` IS THE PROPELLER'S SLIPSTREAM, m^2/s^2: 2 T / (rho A), what momentum theory adds to the square of the airspeed
/// in a propeller's fully developed wake (`slipstream`). A surface with a `wash_share` has that share of it added along its
/// chord. It is WHY A TAILDRAGGER CAN RAISE ITS TAIL at a walking pace's worth of airspeed, and why its rudder steers
/// before the air over the wing does: at full power on the ground a P-51's tail sits in 54 m/s of wash with the aeroplane
/// standing still. Without it the tail came up only at 56 m/s and the take-off ran 950 m against the book's 442
/// (tests/taildragger.gd, lane/warbirds2). Zero, as every planform with no `prop_disc` passes, changes nothing.
inline void evaluate(const Wing& wing, Vec v, Vec w, float flaps, float wing_alpha, Loads& out, float wash = 0.0f) {
    out = Loads{};
    for (int i = 0; i < wing.count; ++i) {
        const Surface& s = wing.s[i];
        const Vec local = v + cross(w, s.at);
        const float vn = dot(local, s.normal);
        const float along = dot(local, s.chord);
        const float vc = s.wash_share > 0.0f && wash > 0.0f && along > -1.0f
            ? std::sqrt(std::fmax(along, 0.0f) * std::fmax(along, 0.0f) + s.wash_share * wash)
            : along;
        const float vv = vn * vn + vc * vc;
        if (vv < 1.0f) {
            continue;
        }
        const float inv = 1.0f / std::sqrt(vv);
        const float alpha = std::atan2(-vn, std::fmax(vc, 0.1f));
        const float a = alpha + s.alpha0 - s.downwash * wing_alpha;
        const float flap = flaps * s.mix_up[kFlaps];
        const float sin2a = -2.0f * vn * vc * inv * inv;
        const float sinsq = vn * vn * inv * inv;
        float cl = 0.0f;
        float cd = 0.0f;
        float dcl = 0.0f;
        coefficients(s, a, flap, sin2a, sinsq, cl, cd, dcl);
        const float qs = 0.5f * wing.rho * vv * s.area;
        // Lift across the local flow towards the normal's side; drag along it, against it.
        const Vec lift_dir = (s.normal * vc - s.chord * vn) * inv;
        const Vec drag_dir = (s.normal * vn + s.chord * vc) * -inv;
        const Vec f = lift_dir * (qs * cl) + drag_dir * (qs * cd);
        out.force = out.force + f;
        out.torque = out.torque + cross(s.at, f);
        const Vec per = lift_dir * (qs * dcl) + drag_dir * (qs * 2.0f * s.k * cl * dcl);
        out.per_radian[i] = per;
        const Vec moment = cross(s.at, per);
        for (int c = 0; c < 3; ++c) {
            out.per_unit[c] = out.per_unit[c] + moment * (0.5f * (s.mix_up[c] + s.mix_down[c]));
        }
    }
}

/// AND THE STICK: pitch, roll and yaw in -1..1, added through each surface's own travel -- the up-going aileron's 20
/// degrees and the down-going one's 15, which is less adverse yaw than a symmetric aileron and is why real ones are rigged
/// that way.
inline void add_the_stick(const Wing& wing, const float u[3], Loads& loads) {
    for (int i = 0; i < wing.count; ++i) {
        const Surface& s = wing.s[i];
        float control = 0.0f;
        for (int c = 0; c < 3; ++c) {
            control += u[c] * (u[c] >= 0.0f ? s.mix_up[c] : s.mix_down[c]);
        }
        if (control == 0.0f) {
            continue;
        }
        const Vec f = loads.per_radian[i] * control;
        loads.force = loads.force + f;
        loads.torque = loads.torque + cross(s.at, f);
    }
}

/// THE RATES ASKED FOR: pitch about +X (nose up), yaw about +Y (nose left), roll about -Z (right wing down).
struct Rates {
    float pitch = 0.0f;
    float yaw = 0.0f;
    float roll = 0.0f;
};

/// THE CONTROL LAW: the stick that makes the moment these rates need, from what the surfaces make with it centred and
/// what a unit of each channel adds, CLAMPED TO FULL TRAVEL. Dynamic inversion through the model itself, so it can never
/// ask the air for more than the air will give: slow, a unit of stick is worth little and the clamp binds; stalled, it is
/// worth nothing (`coefficients`), and the law cannot fly through a stall.
///
/// STATELESS: `settle` is the time constant it closes a rate error in, and there is no integral term -- the inversion
/// already cancels the steady moment an integrator would have wound up against (the prototype's autopilot held height
/// within 0.3 m on the Cessna with none). `inertia` is the body's about pitch, yaw and roll; `out` is the stick, -1..1,
/// for pitch, roll and yaw.
inline void control_law(const Loads& base, Vec inertia, Vec w, const Rates& want, float settle, float out[3],
                        bool clamp = true) {
    const float k = 1.0f / std::fmax(settle, 1e-3f);
    const auto solve = [clamp](float need, float per) {
        if (std::fabs(per) <= 1e-3f) {
            return 0.0f;
        }
        const float u = need / per;
        if (!clamp) {
            return u;
        }
        return u < -1.0f ? -1.0f : (u > 1.0f ? 1.0f : u);
    };
    out[kPitch] = solve(inertia.x * k * (want.pitch - w.x) - base.torque.x, base.per_unit[kPitch].x);
    out[kYaw] = solve(inertia.y * k * (want.yaw - w.y) - base.torque.y, base.per_unit[kYaw].y);
    // Roll is about -Z: the rate is -w.z, the base moment about it is -torque.z, and so is a unit of aileron's.
    out[kRoll] = solve(inertia.z * k * (want.roll + w.z) + base.torque.z, -base.per_unit[kRoll].z);
}

/// WHAT THE ROLL DAMPING OF THE WING PANELS IS WORTH at an airspeed, N m per rad/s: each panel's lift slope times q S
/// times its arm squared over v. With the roll inertia it is the time constant the stiffness guard reads.
inline float roll_damping(const Wing& wing, float speed) {
    float sum = 0.0f;
    for (int i = 0; i < wing.count; ++i) {
        const Surface& s = wing.s[i];
        if (s.normal.y < 0.5f) {
            continue;  // a fin
        }
        sum += 0.5f * wing.rho * speed * s.area * s.slope * s.at.x * s.at.x;
    }
    return sum;
}

// ----------------------------------------------------------------------------------------------------------------------
// BUILDING ONE FROM A DRAWING.
// ----------------------------------------------------------------------------------------------------------------------

/// AN AIRFRAME'S SURFACES AS DRAWN: stations in metres aft of the nose and heights in metres over the ground at rest,
/// which is how the airframes in `cockpit/objects/vehicles/` are measured, so each number here can be read off one and a
/// suite can hold the two together. Travels are the drawn ones; `*_share` is the share of the surface the control spans
/// and `*_tau` its effectiveness for its chord (0.45 for a quarter chord, 0.6 for a half).
struct Planform {
    /// The hull: a station `s` is z = s - length / 2 and a height `h` is y = h - rest.
    float length = 0.0f;
    float rest = 0.0f;
    // The wing.
    float span = 0.0f;
    float area = 0.0f;
    float quarter_chord_station = 0.0f;  // at the panel's spanwise centroid
    float quarter_chord_height = 0.0f;
    float dihedral = 0.0f;               // radians
    float alpha0 = 0.0f;                 // incidence at the centroid plus the section's zero-lift angle, radians
    float aileron_up = 0.0f;             // radians of travel
    float aileron_down = 0.0f;
    float aileron_share = 0.0f;
    float aileron_tau = 0.45f;
    float wing_cd0 = 0.007f;
    float oswald = 0.8f;
    // The tailplane.
    float tail_area = 0.0f;
    float tail_span = 0.0f;
    float tail_station = 0.0f;
    float tail_height = 0.0f;
    float elevator_up = 0.0f;
    float elevator_down = 0.0f;
    float elevator_tau = 0.5f;
    float tail_cd0 = 0.009f;
    // The fin, with the fuselage as its end plate (so its aspect ratio is doubled).
    float fin_area = 0.0f;
    float fin_height = 0.0f;
    float fin_station = 0.0f;
    float fin_centroid_height = 0.0f;
    float rudder_travel = 0.0f;
    float rudder_tau = 0.6f;
    float fin_cd0 = 0.009f;
    /// THE CENTRE OF GRAVITY is placed this share of the mean chord ahead of the neutral point the surfaces make. One
    /// number for "how stable", in place of a station nobody here has measured.
    float static_margin = 0.15f;
    /// THE UNDERSIDE: the main axles' station, and the height of the fuselage's underside at the tail. A tricycle
    /// aeroplane rotates about its main wheels until the tail touches, and a box can only pivot about its back corner --
    /// on the Cessna 5.8 m behind the centre of gravity, which no tailplane can lift.
    float mains_station = 0.0f;
    float tail_underside_height = 0.0f;
    /// WHERE THAT HEIGHT IS, the station of the tail's lowest aft point, or 0 for the hull's end. The collision hull's
    /// ramp runs from the mains through it to the box's end, so the tail touches at the drawn angle: with the rudder's
    /// foot put at the box's end, 0.64 m aft of where it is drawn, the Cessna's tail touched at 7.6 degrees against the
    /// drawing's 8.55 (lane/cessnafm).
    float tail_underside_station = 0.0f;
    /// A TAILDRAGGER'S NOSE: the lowest point ahead of the main wheels, station and height -- its propeller disc's bottom
    /// with a blade straight down -- or 0 for the box's flat front, which a tricycle's nosewheel stands on. The collision
    /// hull's underside rises from the mains through it, so an aeroplane pitched forward on its mains meets the ground with
    /// its propeller at the drawn angle and not never (lane/warbirds2).
    float nose_underside_station = 0.0f;
    float nose_underside_height = 0.0f;
    /// THE MAIN WHEELS' TRACK, metres between the tyres' middles. A taildragger's wheels push where they are, and each main
    /// brakes on its own (`CockpitWorld::roll_a_taildragger`).
    float track = 0.0f;
    /// HOW FAR THE TAIL WHEEL STEERS EACH WAY WITH THE RUDDER, radians, while the stick is at or aft of neutral; pushed
    /// forward of neutral the wheel is unlocked and castors, as the P-51D's is. 0 is a tail wheel that only castors.
    float tailwheel_steer = 0.0f;
    /// THE PROPELLER'S SLIPSTREAM OVER THE TAIL (lane/warbirds2): the disc's area, m^2, and the share of the tailplane's
    /// and the fin's area inside its wash. 0 for no slipstream, as every planform before it. See `evaluate`'s `wash`.
    float prop_disc = 0.0f;
    float tail_in_wash = 0.0f;
    float fin_in_wash = 0.0f;
    /// THE PUBLISHED CRUISE, m/s, where there is one (see `Wing::cruise`).
    float cruise = 0.0f;
    /// THE WHOLE AEROPLANE'S ZERO-LIFT DRAG COEFFICIENT on the wing's area, or 0 to keep `Handling::drag_forward`. The
    /// body keeps what the surfaces' own profile drag does not account for (`build_wing`).
    float cd0 = 0.0f;
    /// THE PROPELLER (see `Wing::thrust`), or 0 for the constant thrust in `Handling`.
    float thrust = 0.0f;
    float thrust_gone_at = 0.0f;
    /// WHAT FULL FLAP ADDS TO THE ZERO-LIFT DRAG COEFFICIENT, or 0 for `Handling::flap_drag`.
    float flap_cd = 0.0f;
    /// The inertia and angular damping the body is given (see `Wing::inertia`).
    Vec inertia{};
    float angular_damping = 0.2f;
};

inline float finite_slope(float aspect) { return 6.2831853f * aspect / (aspect + 2.0f) * 0.92f; }

/// THE WING, TAILPLANE AND FIN OF A PLANFORM, with the centre of gravity placed by the static margin and the tailplane's
/// incidence left at zero for `trim_the_tail`. `drag_*` are the aeroplane's totals from `Handling`; the body keeps what
/// the surfaces do not now carry, so the top speed does not move.
inline Wing build_wing(const Planform& p, float clmax, float flap_clmax, float drag_forward, float drag_side,
                       float drag_vertical, int mutant = 0) {
    Wing w;
    w.unclamped = (mutant & kUnclampedLaw) != 0;
    w.area = p.area;
    w.clmax = clmax;
    w.flap_clmax = flap_clmax;
    const float aspect = p.span * p.span / p.area;
    const float a = finite_slope(aspect);
    const float tail_aspect = p.tail_span * p.tail_span / std::fmax(p.tail_area, 0.01f);
    const float a_tail = finite_slope(tail_aspect);
    const float fin_aspect = 2.0f * p.fin_height * p.fin_height / std::fmax(p.fin_area, 0.01f);
    const float a_fin = finite_slope(fin_aspect);
    const float downwash = 2.0f * a / (3.14159265f * aspect);

    // THE NEUTRAL POINT: where the wing's and the tail's lift slopes balance, the tail's taken through the downwash.
    const float wing_weight = a * p.area;
    const float tail_weight = a_tail * p.tail_area * (1.0f - downwash);
    const float neutral = (wing_weight * p.quarter_chord_station + tail_weight * p.tail_station)
        / (wing_weight + tail_weight);
    const float mean_chord = p.area / p.span;
    const float cg_station = neutral - p.static_margin * mean_chord;
    w.centre = {0.0f, 0.0f, cg_station - 0.5f * p.length};
    w.inertia = p.inertia;
    w.angular_damping = p.angular_damping;
    w.cruise = p.cruise;
    w.thrust = p.thrust;
    w.thrust_gone_at = p.thrust_gone_at;
    w.flap_drag = 0.5f * w.rho * p.flap_cd * p.area;
    w.disc_area = p.prop_disc;
    if (p.mains_station > 0.0f) {
        w.mains_z = p.mains_station - 0.5f * p.length;
        // The underside's height at the box's end, on the line from the mains' contact through the drawn tail.
        const float reach = p.tail_underside_station > p.mains_station
            ? (p.length - p.mains_station) / (p.tail_underside_station - p.mains_station)
            : 1.0f;
        w.tail_underside_y = p.tail_underside_height * reach - p.rest;
        w.mains_y = -p.rest;
        // THE NOSE: the underside's height at the box's front (station 0) on the line from the mains through the drawn
        // nose, and the pitch down at which it reaches the ground.
        if (p.nose_underside_station > 0.0f && p.nose_underside_station < p.mains_station) {
            const float lean = p.nose_underside_height / (p.mains_station - p.nose_underside_station);
            w.nose_underside_y = lean * p.mains_station - p.rest;
            w.nose_over = std::atan(lean);
        }
        // A TAILDRAGGER, DERIVED: the centre of gravity aft of the mains, and a tail wheel drawn aft of them.
        w.taildragger = cg_station > p.mains_station && p.tail_underside_station > p.mains_station;
        if (w.taildragger) {
            w.half_track = 0.5f * p.track;
            w.tail_wheel_z = p.tail_underside_station - 0.5f * p.length;
            w.tail_wheel_y = p.tail_underside_height - p.rest;
            w.rest_pitch = std::atan2(p.tail_underside_height, p.tail_underside_station - p.mains_station);
            w.tailwheel_steer = p.tailwheel_steer;
        }
    }

    const auto body = [&](float station, float height) {
        return Vec{0.0f, height - p.rest - w.centre.y, station - cg_station};
    };
    const float panel_out = 0.42f * p.span * 0.5f;
    for (int side = 0; side < 2; ++side) {
        const float sgn = side == 0 ? 1.0f : -1.0f;  // right, left
        Surface& s = w.s[side];
        s.at = body(p.quarter_chord_station, p.quarter_chord_height);
        s.at.x = sgn * panel_out;
        const float dihedral = (mutant & kNoDihedral) != 0 ? 0.0f : p.dihedral;
        if ((mutant & kNoDihedral) != 0) {
            s.at.y = 0.0f;
        }
        s.normal = {-sgn * std::sin(dihedral), std::cos(dihedral), 0.0f};
        s.area = 0.5f * p.area;
        s.slope = a;
        s.alpha0 = p.alpha0;
        s.stall = clmax / a;
        s.cd0 = p.wing_cd0;
        s.k = (mutant & kNoInducedDrag) != 0 ? 0.0f : 1.0f / (3.14159265f * p.oswald * aspect);
        s.stall_break = (mutant & kNoStallBreak) != 0 ? 0.0f : 1.0f;
        // RIGHT STICK (+1) puts the right aileron UP -- less angle on the right panel -- and the left one down.
        const float up = p.aileron_tau * p.aileron_up * p.aileron_share;
        const float down = p.aileron_tau * p.aileron_down * p.aileron_share;
        s.mix_up[kRoll] = side == 0 ? -up : down;
        s.mix_down[kRoll] = side == 0 ? -down : up;
        s.mix_up[kFlaps] = flap_clmax / a;
    }
    Surface& t = w.s[2];
    t.at = body(p.tail_station, p.tail_height);
    t.area = p.tail_area;
    t.slope = a_tail;
    t.stall = 0.30f;
    t.cd0 = p.tail_cd0;
    t.k = 1.0f / (3.14159265f * 0.8f * tail_aspect);
    t.downwash = downwash;
    t.wash_share = p.prop_disc > 0.0f ? p.tail_in_wash : 0.0f;
    // BACK STICK (+1) raises the elevator's trailing edge: tail DOWN, nose up.
    const float elevator = (mutant & kNoElevator) != 0 ? 0.0f : p.elevator_tau;
    t.mix_up[kPitch] = -elevator * p.elevator_up;
    t.mix_down[kPitch] = -elevator * p.elevator_down;
    Surface& fin = w.s[3];
    fin.at = body(p.fin_station, p.fin_centroid_height);
    // A fin's lift is sideways: slip to the right (flow from the right) pushes it LEFT, and the nose swings right.
    fin.normal = {-1.0f, 0.0f, 0.0f};
    fin.area = p.fin_area;
    fin.slope = a_fin;
    fin.stall = 0.35f;
    fin.cd0 = p.fin_cd0;
    fin.k = 1.0f / (3.14159265f * 0.8f * fin_aspect);
    fin.wash_share = p.prop_disc > 0.0f ? p.fin_in_wash : 0.0f;
    // RIGHT PEDAL (+1) pushes the tail left and the nose right.
    fin.mix_up[kYaw] = p.rudder_tau * p.rudder_travel;
    fin.mix_down[kYaw] = p.rudder_tau * p.rudder_travel;
    w.count = 4;

    // The body keeps what the surfaces do not carry: their profile drag forward, and their flat-plate drag across.
    const float half_rho = 0.5f * w.rho;
    const float profile = half_rho * (p.area * p.wing_cd0 + p.tail_area * p.tail_cd0 + p.fin_area * p.fin_cd0);
    const float total = p.cd0 > 0.0f ? half_rho * p.cd0 * p.area : drag_forward;
    w.body_drag_forward = std::fmax(total - profile, 0.0f);
    w.body_drag_side = std::fmax(drag_side - half_rho * 1.2f * p.fin_area, 0.0f);
    w.body_drag_vertical = std::fmax(drag_vertical - half_rho * 1.2f * (p.area + p.tail_area), 0.0f);
    return w;
}

/// Level at `speed`: the angle of attack whose lift carries `mass`, and the pitching moment there.
inline void level_at(const Wing& wing, float mass, float speed, float& alpha, float& moment) {
    float lo = -0.25f;
    float hi = 0.45f;
    alpha = 0.0f;
    moment = 0.0f;
    for (int i = 0; i < 48; ++i) {
        alpha = 0.5f * (lo + hi);
        Loads loads;
        evaluate(wing, Vec{0.0f, -speed * std::sin(alpha), -speed * std::cos(alpha)}, Vec{}, 0.0f, alpha, loads);
        // Lift is across the flow; weight is down. Resolve the force onto the world's up at this pitch.
        const float up = loads.force.y * std::cos(alpha) - loads.force.z * std::sin(alpha);
        if (up < mass * kGravity) {
            lo = alpha;
        } else {
            hi = alpha;
        }
        moment = loads.torque.x;
    }
}

/// THE TAILPLANE'S INCIDENCE IS WHATEVER TRIMS THE AEROPLANE LEVEL AT CRUISE with the stick centred. Derived, never
/// typed: a heavier aeroplane, a new wing or a new cruise re-trims it.
inline void trim_the_tail(Wing& wing, float mass, float cruise) {
    float lo = -0.25f;
    float hi = 0.25f;
    for (int i = 0; i < 48; ++i) {
        wing.s[2].alpha0 = 0.5f * (lo + hi);
        float alpha = 0.0f;
        float moment = 0.0f;
        level_at(wing, mass, cruise, alpha, moment);
        // More incidence is more tail lift, which is nose DOWN: a negative moment about +X.
        if (moment > 0.0f) {
            lo = wing.s[2].alpha0;
        } else {
            hi = wing.s[2].alpha0;
        }
    }
    wing.tail_incidence = wing.s[2].alpha0;
}

}  // namespace aero
}  // namespace cockpit
}  // namespace ashiato_gd
