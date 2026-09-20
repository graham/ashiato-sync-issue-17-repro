#pragma once
// A PROTOTYPE, NOT GAME CODE (lane/flightmodel, 2026-09-18).
//
// Two jobs. 1: time today's fly_airplane + apply_controls arithmetic against a surface-driven model, per aircraft per
// call, on the same compiler and flags the addon is built with (MSVC, /O2, /fp:precise). 2: fly the surface model in a
// small 6-DOF harness that steps like Box3D does here (forces held over a 120 Hz tick, four substeps, angular damping
// as a divisor), to see that it trims, rolls, yaws adversely, stalls and recovers, and that a control law on top of it
// tracks the rates the autopilot asks for.
//
// Body axes are the game's: +X right, +Y up, -Z forward. Pitch about +X is nose up, roll about -Z (forward) is right
// wing down, yaw about +Y is nose left.
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

struct V3 { float x, y, z; };
static inline V3 operator+(V3 a, V3 b) { return {a.x + b.x, a.y + b.y, a.z + b.z}; }
static inline V3 operator-(V3 a, V3 b) { return {a.x - b.x, a.y - b.y, a.z - b.z}; }
static inline V3 operator*(V3 a, float s) { return {a.x * s, a.y * s, a.z * s}; }
static inline float dot(V3 a, V3 b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
static inline V3 cross(V3 a, V3 b) { return {a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x}; }
static inline float len(V3 a) { return std::sqrt(dot(a, a)); }
static inline float clampf(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }

struct Q { float w, x, y, z; };
static inline V3 rot(Q q, V3 v) {
    V3 u{q.x, q.y, q.z};
    V3 t = cross(u, v) * 2.0f;
    return v + t * q.w + cross(u, t);
}
static inline Q qmul(Q a, Q b) {
    return {a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z, a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
            a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x, a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w};
}
static inline Q qnorm(Q q) {
    float n = std::sqrt(q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z);
    return {q.w / n, q.x / n, q.y / n, q.z / n};
}
static inline Q qconj(Q q) { return {q.w, -q.x, -q.y, -q.z}; }

// ------------------------------------------------------------------------------------------------------------------
// TODAY'S MODEL, transcribed from cockpit_world.cpp (fly_airplane, apply_controls, command_rate, pitch_demand,
// surface_bite) with the Box3D calls replaced by sums, so the arithmetic is timed and the ~14 API calls counted apart.
// ------------------------------------------------------------------------------------------------------------------
struct Handling {
    float lift, camber, stall_angle, induced_drag, side_lift, weathervane, yaw_damping, pitch_damping;
    float pitch_stability, flap_lift, flap_drag, gear_drag, control_authority, control_reference;
    float pitch_rate, roll_rate, yaw_rate, g_limit, thrust;
};
struct Frame {
    V3 forward, up, right, spin;  // world
    float along, sideways, vertical, speed, mass;
    float inv_inertia[9];         // world inverse inertia, row-major (Box3D caches it)
};
struct Controls { float pitch, roll, rudder, throttle, flaps; };
struct Out { V3 force, torque; int calls; };

static inline V3 mulm(const float* m, V3 v) {
    return {m[0] * v.x + m[1] * v.y + m[2] * v.z, m[3] * v.x + m[4] * v.y + m[5] * v.z,
            m[6] * v.x + m[7] * v.y + m[8] * v.z};
}

static constexpr float kRateSettle = 0.6f;

static inline void command_rate(Out& o, const Frame& f, V3 axis, float wanted, float gain, float dt) {
    const float error = wanted - dot(f.spin, axis);
    const float response = dot(axis, mulm(f.inv_inertia, axis));
    ++o.calls;  // GetWorldInverseRotationalInertia
    float torque = error * gain;
    if (response > 1e-9f) {
        const float most = kRateSettle * std::fabs(error) / (response * dt);
        torque = clampf(torque, -most, most);
    }
    o.torque = o.torque + axis * torque;
    ++o.calls;
}

static void today(const Handling& h, const Frame& f, const Controls& in, float dt, Out& o) {
    if (f.speed > 1.0f) {
        const float aoa = std::atan2(-f.vertical, std::fmax(f.along, 0.1f));
        float coefficient = aoa + h.camber + in.flaps * h.flap_lift;
        if (std::fabs(coefficient) > h.stall_angle) {
            const float over = std::fabs(coefficient) - h.stall_angle;
            coefficient = (coefficient > 0.0f ? 1.0f : -1.0f) * std::fmax(h.stall_angle * 0.25f, h.stall_angle - over * 1.4f);
        }
        const float airspeed = std::fmax(f.along, 0.0f);
        const float q = airspeed * airspeed;
        o.force = o.force + f.up * (coefficient * q * h.lift); ++o.calls;
        const float hanging = in.flaps * h.flap_drag + h.gear_drag;
        if (hanging > 0.0f) {
            float fo = q * hanging;
            float most = std::fabs(f.along) * f.mass / dt;  // resist()
            o.force = o.force + f.forward * -std::fmin(fo, most); ++o.calls;
        }
        o.force = o.force + f.forward * (-coefficient * coefficient * q * h.induced_drag); ++o.calls;
        {
            float fo = std::fabs(f.sideways) * airspeed * h.side_lift;
            float most = std::fabs(f.sideways) * f.mass / dt;
            o.force = o.force + f.right * (f.sideways > 0 ? -std::fmin(fo, most) : std::fmin(fo, most)); ++o.calls;
        }
        o.torque = o.torque + f.up * (-f.sideways * airspeed * h.weathervane); ++o.calls;
        o.torque = o.torque + f.right * (-aoa * q * h.pitch_stability); ++o.calls;
        o.torque = o.torque + f.up * (-dot(f.spin, f.up) * f.speed * h.yaw_damping); ++o.calls;
        o.torque = o.torque + f.right * (-dot(f.spin, f.right) * f.speed * h.pitch_damping); ++o.calls;
    }
    o.force = o.force + f.forward * (in.throttle * h.thrust); ++o.calls;
    const float share = f.speed / std::fmax(h.control_reference, 0.001f);
    const float bite = std::fmin(1.0f, share * share);
    const float gain = h.control_authority * bite;
    float wanted_pitch = in.pitch * h.pitch_rate;
    if (h.g_limit > 0.0f) {
        const float most = h.g_limit * 9.81f / std::fmax(f.along, 1.0f);
        wanted_pitch = clampf(wanted_pitch, -most, most);
    }
    command_rate(o, f, f.right, wanted_pitch, gain, dt);
    command_rate(o, f, f.forward, in.roll * h.roll_rate, gain, dt);
    command_rate(o, f, f.up, -in.rudder * h.yaw_rate, gain, dt);
}

// ------------------------------------------------------------------------------------------------------------------
// THE SURFACE MODEL.
//
// Each surface is a small wing: where its aerodynamic centre is (body, from the mass centre), which way its lift points
// when the flow is straight down its chord, its area, lift slope, zero-lift angle, stall, drags, and how much each
// control channel moves its zero-lift angle (a flap's effectiveness tau times the surface's travel, in radians of
// effective angle of attack per unit of input). Everything else -- stability, damping, adverse yaw, dihedral effect,
// wing drop -- is what these do when the local airflow at each one is different.
// ------------------------------------------------------------------------------------------------------------------
enum Channel { kPitch = 0, kRoll = 1, kYaw = 2, kFlaps = 3, kChannels = 4 };

struct Surface {
    V3 at;          // aerodynamic centre, body, metres from the mass centre
    V3 normal;      // lift direction with the flow straight down the chord (unit, body)
    V3 chord;       // leading edge direction (unit, body): -Z for everything here
    float area;     // m^2
    float slope;    // dCL/dalpha, per radian, finite-span
    float alpha0;   // radians of effective angle at zero geometric angle (incidence + camber)
    float stall;    // effective angle at CLmax, radians
    float cd0;      // profile drag
    float k;        // induced: CD += k CL^2
    float downwash; // share of the wing's own alpha the wake takes off this surface's (tail only), dEps/dAlpha
    float mix[kChannels];  // radians of effective angle per unit of each channel
};

struct Airframe {
    int count;
    Surface s[6];
    float rho;      // kg/m^3, sea level; a height lapse is one multiply later
};

struct SurfaceInput { float u[kChannels]; };

// Lift and drag coefficients at effective angle a, with the post-stall flat plate computed from the geometric flow
// (sin 2a and sin^2 a from the velocity components, so no trigonometry past the one atan2).
static inline void coefficients(const Surface& s, float a, float control, float sin2a, float sinsq, float& cl, float& cd,
                                float& dcl) {
    // THE STALL IS JUDGED ON THE SURFACE'S OWN ANGLE, and a control moves the whole curve up or down: a flap raises
    // CLmax, which shifting the angle alone would not. Past the stall a control keeps half its bite, fading to none.
    const float over = std::fabs(a) - s.stall;
    if (over <= 0.0f) {
        cl = s.slope * (a + control);
        dcl = s.slope;
    } else {
        // From CLmax down to the flat plate over 0.15 rad past the stall, then the flat plate (1.1 sin 2a).
        const float t = std::fmin(1.0f, over / 0.15f);
        const float peak = (a > 0.0f ? 1.0f : -1.0f) * s.slope * s.stall;
        const float plate = 1.1f * sin2a;
        dcl = s.slope * 0.5f * (1.0f - t);
        cl = peak + (plate - peak) * t + dcl * control;
    }
    cd = s.cd0 + s.k * cl * cl + 1.2f * sinsq * (over > 0.0f ? std::fmin(1.0f, over / 0.15f) : 0.0f);
}

struct SurfaceOut {
    V3 force, torque;          // body axes, aerodynamic only
    V3 per_unit[kChannels];    // torque per unit of each channel, linearised at this state (for the control law)
};

// v: airflow velocity of the mass centre in body axes (the craft's velocity through the air). w: body rates.
static void surfaces(const Airframe& af, V3 v, V3 w, const SurfaceInput& in, SurfaceOut& o, float wing_alpha) {
    o.force = {0, 0, 0};
    o.torque = {0, 0, 0};
    for (int c = 0; c < kChannels; ++c) o.per_unit[c] = {0, 0, 0};
    for (int i = 0; i < af.count; ++i) {
        const Surface& s = af.s[i];
        const V3 vl = v + cross(w, s.at);
        const float vn = dot(vl, s.normal);
        const float vc = dot(vl, s.chord);
        const float vv = vn * vn + vc * vc;
        if (vv < 1.0f) continue;
        const float inv = 1.0f / std::sqrt(vv);
        const float alpha = std::atan2(-vn, std::fmax(vc, 0.1f));
        float shift = s.alpha0 - s.downwash * wing_alpha;
        float control = 0.0f;
        for (int c = 0; c < kChannels; ++c) control += s.mix[c] * in.u[c];
        const float a = alpha + shift;
        const float sin2a = -2.0f * vn * vc * inv * inv;
        const float sinsq = vn * vn * inv * inv;
        float cl, cd, dcl;
        coefficients(s, a, control, sin2a, sinsq, cl, cd, dcl);
        const float qs = 0.5f * af.rho * vv * s.area;
        // Lift across the local flow, towards the normal's side; drag along it.
        const V3 lift_dir = (s.normal * vc - s.chord * vn) * inv;
        const V3 drag_dir = (s.normal * vn + s.chord * vc) * -inv;
        const V3 f = lift_dir * (qs * cl) + drag_dir * (qs * cd);
        o.force = o.force + f;
        o.torque = o.torque + cross(s.at, f);
        // Per unit of each channel: the lift it adds and the induced drag that comes with it (adverse yaw).
        const V3 df = lift_dir * (qs * dcl) + drag_dir * (qs * 2.0f * s.k * cl * dcl);
        const V3 dm = cross(s.at, df);
        for (int c = 0; c < kChannels; ++c) o.per_unit[c] = o.per_unit[c] + dm * s.mix[c];
    }
}

// ------------------------------------------------------------------------------------------------------------------
// A CONTROL LAW, stateless: the rate the stick (or the autopilot) asks for, achieved THROUGH the surfaces. It finds the
// deflection that makes the moment it needs from what the surfaces would make undeflected and what a unit of each
// channel adds (both linear below the stall), and clamps to full travel -- so it can never ask the air for more than
// the air will give. `authority` blends it with the raw stick: 1 is fly-by-wire, 0 is cables.
// ------------------------------------------------------------------------------------------------------------------
struct Law {
    float settle;   // seconds for the rate error to close: the answer's own time constant
    float slip_gain;// yaw rate asked per radian of sideslip, so the law turns into the airflow instead of fighting the fin
};

static void control_law(const Law& law, const V3 inertia_diag, const SurfaceOut& base, V3 w, V3 wanted,
                        float authority, SurfaceInput& in) {
    // Body axes: pitch is +X, roll is -Z, yaw is +Y. Rates asked: wanted.x pitch, wanted.y yaw, wanted.z roll (+ right).
    const float k = 1.0f / law.settle;
    // pitch
    {
        const float need = inertia_diag.x * k * (wanted.x - w.x) - base.torque.x;
        const float per = base.per_unit[kPitch].x;
        const float u = std::fabs(per) > 1e-3f ? need / per : 0.0f;
        in.u[kPitch] = clampf(authority * u + (1.0f - authority) * in.u[kPitch], -1.0f, 1.0f);
    }
    // roll, about -Z: a right roll is w.z negative
    {
        const float rate = -w.z;
        const float need = inertia_diag.z * k * (wanted.z - rate) + base.torque.z;  // moment about -Z is -torque.z
        const float per = -base.per_unit[kRoll].z;
        const float u = std::fabs(per) > 1e-3f ? need / per : 0.0f;
        in.u[kRoll] = clampf(authority * u + (1.0f - authority) * in.u[kRoll], -1.0f, 1.0f);
    }
    // yaw
    {
        const float need = inertia_diag.y * k * (wanted.y - w.y) - base.torque.y;
        const float per = base.per_unit[kYaw].y;
        const float u = std::fabs(per) > 1e-3f ? need / per : 0.0f;
        in.u[kYaw] = clampf(authority * u + (1.0f - authority) * in.u[kYaw], -1.0f, 1.0f);
    }
}

// ------------------------------------------------------------------------------------------------------------------
// A light high-wing monoplane, the game's Cessna (1,000 kg, 9 kN). Geometry from the C172's published envelope (11.0 m
// span, 16.2 m^2 wing: Wikipedia, "Cessna 172", specifications); the tail areas, arms and inertias are ESTIMATES for the
// prototype and would be measured off the drawn airframe in the build.
// ------------------------------------------------------------------------------------------------------------------
// 6-DOF HARNESS: the tick as the game does it. Forces are worked out once per 120 Hz tick in body axes and held over
// four substeps; Box3D's angular damping divides the spin each substep. Gravity, thrust along -Z, and the body's own
// quadratic drags (the game's drag_forward / side / vertical) stay as they are.
// ------------------------------------------------------------------------------------------------------------------
struct Body {
    V3 p, v;   // world
    Q q;       // body to world
    V3 w;      // body rates (body axes)
    float mass;
    V3 I;      // principal, body: x pitch, y yaw, z roll
    float angular_damping;
    float drag_forward, drag_side, drag_vertical, thrust;
};

struct Pilot {
    // RAW: the stick itself. LAW: rates asked for, as the autopilot or the rate stick does.
    bool law = false;
    float authority = 1.0f;
    V3 wanted{0, 0, 0};   // pitch, yaw, roll(+right) rad/s
    SurfaceInput stick{};
    float throttle = 0.0f;
};

struct Telemetry { float alpha, beta, speed, cl_wing; SurfaceInput used; };

static void tick(Body& b, const Airframe& af, Pilot& pilot, const Law& law, float dt, Telemetry* tel = nullptr) {
    const V3 vb = rot(qconj(b.q), b.v);  // velocity in body axes (still air)
    const float along = -vb.z;
    const float wing_alpha = std::atan2(-vb.y, std::fmax(along, 0.1f));
    SurfaceInput in = pilot.stick;
    SurfaceOut base{};
    SurfaceInput zero = in;
    if (pilot.law) {
        zero.u[kPitch] = zero.u[kRoll] = zero.u[kYaw] = 0.0f;
    }
    surfaces(af, vb, b.w, zero, base, wing_alpha);
    SurfaceOut out = base;
    if (pilot.law) {
        control_law(law, b.I, base, b.w, pilot.wanted, pilot.authority, in);
        // What the chosen deflection adds, linearised: the same numbers the law solved with.
        V3 dm = base.per_unit[kPitch] * in.u[kPitch] + base.per_unit[kRoll] * in.u[kRoll] + base.per_unit[kYaw] * in.u[kYaw];
        out.torque = out.torque + dm;
        // (the force the deflection adds is small beside the base and left out of the prototype's law path)
    }
    if (tel) {
        tel->alpha = wing_alpha;
        tel->beta = std::atan2(vb.x, std::fmax(along, 0.1f));
        tel->speed = len(vb);
        tel->used = in;
    }
    // Body drags, clamped like resist().
    auto resist = [&](float comp, float fo) {
        const float most = std::fabs(comp) * b.mass / dt;
        return comp > 0 ? -std::fmin(fo, most) : std::fmin(fo, most);
    };
    V3 fb = out.force;
    fb.x += resist(vb.x, vb.x * vb.x * b.drag_side);
    fb.y += resist(vb.y, vb.y * vb.y * b.drag_vertical);
    fb.z += -resist(along, along * along * b.drag_forward);  // along is -z
    fb.z += -pilot.throttle * b.thrust;
    const V3 fw = rot(b.q, fb);
    const V3 tb = out.torque;
    const int sub = 4;
    const float h = dt / sub;
    for (int i = 0; i < sub; ++i) {
        b.v = b.v + (fw * (1.0f / b.mass) + V3{0, -9.81f, 0}) * h;
        V3 Iw{b.I.x * b.w.x, b.I.y * b.w.y, b.I.z * b.w.z};
        V3 gyro = cross(b.w, Iw);
        b.w.x += h * (tb.x - gyro.x) / b.I.x;
        b.w.y += h * (tb.y - gyro.y) / b.I.y;
        b.w.z += h * (tb.z - gyro.z) / b.I.z;
        b.w = b.w * (1.0f / (1.0f + h * b.angular_damping));
        b.p = b.p + b.v * h;
        const V3 ww = rot(b.q, b.w);
        Q dq{0, ww.x * 0.5f * h, ww.y * 0.5f * h, ww.z * 0.5f * h};
        Q qq = qmul(dq, b.q);
        b.q = qnorm({b.q.w + qq.w, b.q.x + qq.x, b.q.y + qq.y, b.q.z + qq.z});
    }
}

