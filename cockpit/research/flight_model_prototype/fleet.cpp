// A PROTOTYPE, NOT GAME CODE (lane/flightmodel, 2026-09-18): the surface model built from a few measured numbers per
// kind, the tail's incidence DERIVED from trimming at cruise rather than typed, and the game's own AircraftMixer
// (autopilot.hpp, included unedited) flying both today's rate servo and the surface model on the same harness.
#include "model.hpp"
#include "../../../ashiato-gd/src/cockpit/autopilot.hpp"

namespace ai = ashiato_gd::cockpit::ai;

// ------------------------------------------------------------------------------------------------------------------
// A KIND, as the build would carry it: the airframe's measured numbers and nothing derived.
// ------------------------------------------------------------------------------------------------------------------
struct Spec {
    const char* name;
    float mass;
    float span, wing_area, wing_y, wing_z, dihedral_deg, clmax, flap_dcl, aileron;  // aileron: effective rad at full
    float tail_area, tail_arm, tail_y, elevator;
    float fin_area, fin_arm, fin_height, rudder;
    float hx, hy, hz;              // the hull box
    V3 stated;                     // stated inertia (pitch, yaw, roll); zero keeps the box plus the wing rule
    float wing_share;              // share of the mass in the wing, for the roll inertia the box does not have
    float thrust, drag_forward, drag_side, drag_vertical, angular_damping;
    float cruise;                  // m/s, where the tail is trimmed with the stick centred
};

static float lift_slope(float aspect) { return 6.2832f * aspect / (aspect + 2.0f) * 0.92f; }

static V3 inertia_of(const Spec& k) {
    if (k.stated.x > 0.0f) return k.stated;
    const float m = k.mass;
    V3 box{m / 3.0f * (k.hy * k.hy + k.hz * k.hz), m / 3.0f * (k.hx * k.hx + k.hz * k.hz),
           m / 3.0f * (k.hx * k.hx + k.hy * k.hy)};
    // THE WING'S SHARE, spread along the span: a uniform bar is b^2 / 12. Adds to roll and yaw, not to pitch.
    const float wing = k.wing_share * m * k.span * k.span / 12.0f;
    return {box.x, box.y + wing, box.z + wing};
}

static Airframe build(const Spec& k, float tail_incidence) {
    Airframe af{};
    af.rho = 1.225f;
    const float AR = k.span * k.span / k.wing_area;
    const float a = lift_slope(AR);
    const float dh = k.dihedral_deg * 3.14159f / 180.0f;
    for (int side = 0; side < 2; ++side) {
        const float sgn = side == 0 ? 1.0f : -1.0f;
        Surface s{};
        s.at = {sgn * 0.42f * k.span * 0.5f, k.wing_y, k.wing_z};
        s.normal = {-sgn * std::sin(dh), std::cos(dh), 0.0f};
        s.chord = {0, 0, -1};
        s.area = k.wing_area * 0.5f;
        s.slope = a;
        s.alpha0 = 0.05f;
        s.stall = k.clmax / a;
        s.cd0 = 0.007f;
        s.k = 1.0f / (3.14159f * 0.8f * AR);
        s.mix[kRoll] = -sgn * k.aileron;
        s.mix[kFlaps] = k.flap_dcl / a;
        af.s[side] = s;
    }
    const float tail_AR = 4.0f;
    Surface t{};
    t.at = {0.0f, k.tail_y, k.tail_arm};
    t.normal = {0, 1, 0};
    t.chord = {0, 0, -1};
    t.area = k.tail_area;
    t.slope = lift_slope(tail_AR);
    t.alpha0 = tail_incidence;
    t.stall = 0.30f;
    t.cd0 = 0.009f;
    t.k = 1.0f / (3.14159f * 0.8f * tail_AR);
    t.downwash = 2.0f * a / (3.14159f * AR);  // d(eps)/d(alpha) of an elliptic wing
    t.mix[kPitch] = -k.elevator;
    af.s[2] = t;
    Surface fin{};
    fin.at = {0.0f, k.fin_height, k.fin_arm};
    fin.normal = {-1, 0, 0};
    fin.chord = {0, 0, -1};
    fin.area = k.fin_area;
    fin.slope = lift_slope(1.6f);
    fin.stall = 0.35f;
    fin.cd0 = 0.009f;
    fin.k = 1.0f / (3.14159f * 0.8f * 1.6f);
    fin.mix[kYaw] = k.rudder;
    af.s[3] = fin;
    af.count = 4;
    return af;
}

// Level at `speed`: the angle of attack whose lift carries the weight, and the pitching moment there.
static void level_at(const Airframe& af, const Spec& k, float speed, float& alpha, float& moment) {
    float lo = -0.2f, hi = 0.4f;
    for (int i = 0; i < 40; ++i) {
        alpha = 0.5f * (lo + hi);
        V3 v{0.0f, -speed * std::sin(alpha), -speed * std::cos(alpha)};
        SurfaceOut o;
        SurfaceInput in{};
        surfaces(af, v, {0, 0, 0}, in, o, alpha);
        if (o.force.y < k.mass * 9.81f) lo = alpha; else hi = alpha;
        moment = o.torque.x;
    }
}

// THE TAIL'S INCIDENCE IS WHATEVER TRIMS THE AEROPLANE AT CRUISE with the stick centred. One number derived from the
// others, never typed beside them.
static float trim_tail(const Spec& k) {
    float lo = -0.2f, hi = 0.2f, inc = 0.0f;
    for (int i = 0; i < 40; ++i) {
        inc = 0.5f * (lo + hi);
        Airframe af = build(k, inc);
        float alpha, m;
        level_at(af, k, k.cruise, alpha, m);
        // More tail incidence is more tail lift, which is nose DOWN (negative torque about +X).
        if (m > 0.0f) lo = inc; else hi = inc;
    }
    return inc;
}

struct Craft {
    Spec k;
    Airframe af;
    V3 I;
};
static Craft make(const Spec& k) { return {k, build(k, trim_tail(k)), inertia_of(k)}; }

static Body body_of(const Craft& c) {
    Body b{};
    b.p = {0, 1000, 0};
    b.q = {1, 0, 0, 0};
    b.mass = c.k.mass;
    b.I = c.I;
    b.angular_damping = c.k.angular_damping;
    b.drag_forward = c.k.drag_forward;
    b.drag_side = c.k.drag_side;
    b.drag_vertical = c.k.drag_vertical;
    b.thrust = c.k.thrust;
    return b;
}

static float bank_of2(const Body& b) {
    const V3 right = rot(b.q, {1, 0, 0});
    const V3 up = rot(b.q, {0, 1, 0});
    return std::atan2(-right.y, std::fmax(up.y, 0.05f));
}
static float heading_of2(const Body& b) {
    const V3 fwd = rot(b.q, {0, 0, -1});
    return std::atan2(fwd.x, -fwd.z);
}
static float pitch_of2(const Body& b) {
    const V3 fwd = rot(b.q, {0, 0, -1});
    return std::asin(clampf(fwd.y, -1, 1));
}

static const float kDt = 1.0f / 120.0f;

// ------------------------------------------------------------------------------------------------------------------
// TODAY'S MODEL IN THE SAME HARNESS: Frame built as drive_vehicle builds it, `today()` from model.hpp, the world
// torque taken into body axes for the integrator.
// ------------------------------------------------------------------------------------------------------------------
static void tick_today(Body& b, const Handling& h, const Controls& c) {
    Frame f{};
    f.forward = rot(b.q, {0, 0, -1});
    f.up = rot(b.q, {0, 1, 0});
    f.right = rot(b.q, {1, 0, 0});
    f.spin = rot(b.q, b.w);
    f.along = dot(b.v, f.forward);
    f.sideways = dot(b.v, f.right);
    f.vertical = dot(b.v, f.up);
    f.speed = len(b.v);
    f.mass = b.mass;
    // R diag(1/I) R^T, with the body's I as (pitch x, yaw y, roll z)
    V3 cols[3] = {f.right, f.up, rot(b.q, {0, 0, 1})};
    float inv[3] = {1.0f / b.I.x, 1.0f / b.I.y, 1.0f / b.I.z};
    for (int r = 0; r < 3; ++r)
        for (int cc = 0; cc < 3; ++cc) {
            float s = 0;
            for (int k = 0; k < 3; ++k) {
                const float* a = &cols[k].x;
                s += a[r] * inv[k] * a[cc];
            }
            f.inv_inertia[r * 3 + cc] = s;
        }
    Out o{{0, 0, 0}, {0, 0, 0}, 0};
    today(h, f, c, kDt, o);
    // the body drags, as drive_vehicle applies them to everything
    auto resist = [&](float comp, float fo) {
        const float most = std::fabs(comp) * b.mass / kDt;
        return comp > 0 ? -std::fmin(fo, most) : std::fmin(fo, most);
    };
    V3 fw = o.force;
    fw = fw + f.right * resist(f.sideways, f.sideways * f.sideways * b.drag_side);
    fw = fw + f.up * resist(f.vertical, f.vertical * f.vertical * b.drag_vertical);
    fw = fw + f.forward * resist(f.along, f.along * f.along * b.drag_forward);
    const V3 tb = rot(qconj(b.q), o.torque);
    const int sub = 4;
    const float hh = kDt / sub;
    for (int i = 0; i < sub; ++i) {
        b.v = b.v + (fw * (1.0f / b.mass) + V3{0, -9.81f, 0}) * hh;
        V3 Iw{b.I.x * b.w.x, b.I.y * b.w.y, b.I.z * b.w.z};
        V3 gyro = cross(b.w, Iw);
        b.w.x += hh * (tb.x - gyro.x) / b.I.x;
        b.w.y += hh * (tb.y - gyro.y) / b.I.y;
        b.w.z += hh * (tb.z - gyro.z) / b.I.z;
        b.w = b.w * (1.0f / (1.0f + hh * b.angular_damping));
        b.p = b.p + b.v * hh;
        const V3 ww = rot(b.q, b.w);
        Q dq{0, ww.x * 0.5f * hh, ww.y * 0.5f * hh, ww.z * 0.5f * hh};
        Q qq = qmul(dq, b.q);
        b.q = qnorm({b.q.w + qq.w, b.q.x + qq.x, b.q.y + qq.y, b.q.z + qq.z});
    }
}

// The rate stick of today, through the surfaces: stick x the kind's rates is what the law is asked for.
struct Rates { float pitch, roll, yaw, g_limit; };

static void tick_surfaces(Body& b, const Craft& c, const Controls& stick, const Rates& r, const Law& law, bool fbw,
                          float* alpha_out = nullptr) {
    Pilot p;
    p.throttle = stick.throttle;
    p.stick.u[kFlaps] = stick.flaps;
    if (fbw) {
        p.law = true;
        float along = len(b.v);
        float pitch = stick.pitch * r.pitch;
        if (r.g_limit > 0) pitch = clampf(pitch, -r.g_limit * 9.81f / std::fmax(along, 1.0f), r.g_limit * 9.81f / std::fmax(along, 1.0f));
        p.wanted = {pitch, stick.rudder * -r.yaw, stick.roll * r.roll};
    } else {
        p.stick.u[kPitch] = stick.pitch;
        p.stick.u[kRoll] = stick.roll;
        p.stick.u[kYaw] = stick.rudder;
    }
    Telemetry t;
    tick(b, c.af, p, law, kDt, &t);
    if (alpha_out) *alpha_out = t.alpha;
}

// ------------------------------------------------------------------------------------------------------------------
// THE AUTOPILOT A/B: the game's AircraftMixer, configured as fly_it_like_a configures it, flying a 90-degree turn and
// a 100 m climb at once, from level at cruise. Today's model gets its stick as a rate; the surface model gets the same
// stick through the law (a rate asked of the surfaces).
// ------------------------------------------------------------------------------------------------------------------
struct ApResult { float t_heading, overshoot_deg, alt_err_max, alt_err_end, reversals, max_bank_deg, min_speed; };

template <typename Step>
static ApResult fly_autopilot(Body b, float cruise, float stall, float max_bank, Step step) {
    ai::AircraftMixer m;
    m.stall_speed = stall;
    m.cruise_speed = cruise;
    m.max_climb_rate = 5.0f;
    m.max_bank = max_bank;
    m.powered = true;
    ai::Bugs want;
    const float h0 = heading_of2(b), a0 = b.p.y;
    want.heading = h0;
    want.altitude = a0;
    want.airspeed = cruise;
    ApResult r{-1, 0, 0, 0, 0, 0, 999};
    float last_climb_sign = 0;
    for (int i = 0; i < 120 * 70; ++i) {
        if (i == 120 * 5) {
            want.heading = h0 + 1.5708f;
            want.altitude = a0 + 100.0f;
        }
        ai::Situation now;
        now.altitude = b.p.y;
        now.climb_rate = b.v.y;
        now.heading = heading_of2(b);
        now.bank = bank_of2(b);
        now.airspeed = len(b.v);
        const V3 right = rot(b.q, {1, 0, 0});
        now.sideslip = now.airspeed > 0.5f ? dot(b.v, right) / now.airspeed : 0.0f;
        ai::Levers lv = m.step(now, want, kDt);
        Controls c{clampf(lv.pitch, -1, 1), clampf(lv.roll, -1, 1), clampf(lv.rudder, -1, 1), clampf(lv.throttle, 0, 1), 0};
        step(b, c);
        const float t = i * kDt;
        if (t > 5.0f) {
            const float err = ai::angle_error(heading_of2(b), want.heading) * 57.3f;
            if (r.t_heading < 0 && std::fabs(err) < 5.0f) r.t_heading = t - 5.0f;
            if (r.t_heading >= 0 && -err > r.overshoot_deg) r.overshoot_deg = -err;
            r.max_bank_deg = std::fmax(r.max_bank_deg, std::fabs(now.bank) * 57.3f);
            r.min_speed = std::fmin(r.min_speed, now.airspeed);
        }
        if (t > 35.0f) {
            const float e = std::fabs(b.p.y - want.altitude);
            r.alt_err_max = std::fmax(r.alt_err_max, e);
            const float s = b.v.y > 0.05f ? 1.0f : (b.v.y < -0.05f ? -1.0f : 0.0f);
            if (s != 0 && last_climb_sign != 0 && s != last_climb_sign) r.reversals += 1;
            if (s != 0) last_climb_sign = s;
        }
        r.alt_err_end = b.p.y - want.altitude;
    }
    return r;
}

static void print_ap(const char* label, const ApResult& r) {
    std::printf("  %-34s heading within 5 deg in %5.1f s, overshoot %4.1f deg, max bank %4.1f, slowest %5.1f m/s | "
                "after 30 s: height within %5.1f m (%+.1f at 70 s), %2.0f climb reversals\n",
                label, r.t_heading, r.overshoot_deg, r.max_bank_deg, r.min_speed, r.alt_err_max, r.alt_err_end, r.reversals);
}

// ------------------------------------------------------------------------------------------------------------------
// Checks a pilot would feel, per kind.
// ------------------------------------------------------------------------------------------------------------------
static float flown_stall(const Craft& c, float flaps) {
    Body b = body_of(c);
    b.v = {0, 0, -c.k.cruise};
    Law law{0.12f, 0};
    float slowest = 999;
    for (int i = 0; i < 120 * 90; ++i) {
        Pilot p;
        p.law = true;
        p.stick.u[kFlaps] = flaps;
        p.throttle = 0.0f;
        p.wanted = {clampf(0.08f * -b.v.y, -0.3f, 0.3f), 0.0f, clampf(-2.0f * bank_of2(b), -0.5f, 0.5f)};
        Telemetry t;
        tick(b, c.af, p, law, kDt, &t);
        if (std::fabs(b.v.y) < 0.5f && t.speed < slowest) slowest = t.speed;
        if (b.v.y < -6.0f) break;
    }
    return slowest;
}

static float book_stall(const Craft& c, float flaps) {
    const Surface& w = c.af.s[0];
    const float clmax = w.slope * (w.stall + w.mix[kFlaps] * flaps);
    return std::sqrt(2.0f * c.k.mass * 9.81f / (1.225f * c.k.wing_area * clmax));
}

static void roll_rate(const Craft& c, float speed, bool fbw, float wanted, float settle, const char* label) {
    Body b = body_of(c);
    b.v = {0, 0, -speed};
    // level it first, with the law
    Law law{settle, 0};
    Rates r{1.5f, wanted, 0.9f, 0};
    for (int i = 0; i < 480; ++i) {
        Pilot p;
        p.law = true;
        p.throttle = 0.5f;
        p.wanted = {clampf(0.1f * -b.v.y, -0.2f, 0.2f), 0.0f, clampf(-2.0f * bank_of2(b), -1.0f, 1.0f)};
        tick(b, c.af, p, law, kDt);
    }
    float peak = 0, t63 = -1;
    std::vector<float> rr;
    for (int i = 0; i < 240; ++i) {
        Controls s{0, 1.0f, 0, 0.5f, 0};
        tick_surfaces(b, c, s, r, law, fbw);
        rr.push_back(-b.w.z);
        peak = std::fmax(peak, -b.w.z);
        if (std::fabs(bank_of2(b)) > 1.2f) break;
    }
    for (size_t i = 0; i < rr.size(); ++i) if (rr[i] >= 0.632f * peak) { t63 = i * kDt; break; }
    std::printf("    %-40s %6.1f deg/s  t63 %.3f s\n", label, peak * 57.3f, t63);
}

// A full pull at speed: the most g, and whether the law holds its g limit.
static void yank(const Craft& c, float speed, bool fbw, const Rates& r, const char* label) {
    Body b = body_of(c);
    b.v = {0, 0, -speed};
    Law law{0.12f, 0};
    for (int i = 0; i < 360; ++i) {
        Pilot p;
        p.law = true;
        p.throttle = 0.8f;
        p.wanted = {clampf(0.1f * -b.v.y, -0.2f, 0.2f), 0.0f, 0.0f};
        tick(b, c.af, p, law, kDt);
    }
    float most_g = 0, most_alpha = 0;
    for (int i = 0; i < 240; ++i) {
        Controls s{1.0f, 0, 0, 0.8f, 0};
        const V3 v0 = b.v;
        float alpha;
        tick_surfaces(b, c, s, r, law, fbw, &alpha);
        const V3 acc = (b.v - v0) * (1.0f / kDt) + V3{0, 9.81f, 0};
        const V3 up = rot(b.q, {0, 1, 0});
        most_g = std::fmax(most_g, dot(acc, up) / 9.81f);
        most_alpha = std::fmax(most_alpha, alpha);
    }
    std::printf("    %-40s %5.1f g, alpha up to %4.1f deg\n", label, most_g, most_alpha * 57.3f);
}


// RUDDER ALONE, stick centred and raw: a sideslip, and the dihedral turning it into a roll. Bank after 3 s.
static void rudder_alone(const Craft& c, float speed, const char* label) {
    Body b = body_of(c);
    b.v = {0, 0, -speed};
    Law law{0.12f, 0};
    for (int i = 0; i < 480; ++i) {
        Pilot p;
        p.law = true;
        p.throttle = 0.5f;
        p.wanted = {clampf(0.1f * -b.v.y, -0.2f, 0.2f), 0.0f, clampf(-2.0f * bank_of2(b), -1.0f, 1.0f)};
        tick(b, c.af, p, law, kDt);
    }
    float most_beta = 0;
    for (int i = 0; i < 360; ++i) {
        Controls s{0, 0, 1.0f, 0.5f, 0};
        tick_surfaces(b, c, s, {1, 1, 1, 0}, law, false);
        const V3 right = rot(b.q, {1, 0, 0});
        most_beta = std::fmax(most_beta, std::fabs(dot(b.v, right) / len(b.v)));
    }
    std::printf("    %-40s bank after 3 s %+6.1f deg (right is +), most slip %4.1f deg\n", label, bank_of2(b) * 57.3f,
                most_beta * 57.3f);
}

// THE STICK ON THE GROUND: the roll moment a full stick makes at a taxi speed, against what tips a hull on its box.
static void stick_on_the_ground(const Craft& c, float speed) {
    SurfaceOut o;
    SurfaceInput in{};
    in.u[kRoll] = 1.0f;
    surfaces(c.af, {0, 0, -speed}, {0, 0, 0}, in, o, 0.0f);
    const float roll = -o.torque.z;
    const float tip = c.k.mass * 9.81f * c.k.hx;
    std::printf("    %-8s full stick at %4.1f m/s: %8.0f N m of roll, against %9.0f N m to lift the hull's edge (%.3f)\n",
                c.k.name, speed, roll, tip, roll / tip);
}

int main() {
    // THE GAME'S CESSNA: 1,000 kg, 9 kN. Wing from Wikipedia ("Cessna 172": 11.00 m, 16.2 m^2). Tail and fin ESTIMATES.
    Spec cessna{"cessna", 1000, 11.0f, 16.2f, 1.0f, 0.10f, 1.7f, 1.45f, 0.55f, 0.075f,
                3.4f, 4.6f, 0.3f, 0.20f, 1.9f, 4.8f, 0.9f, 0.22f,
                0.80f, 0.85f, 4.15f, {0, 0, 0}, 0.10f, 9000, 1.6f, 3.5f, 1.0f, 1.2f, 45.0f};
    // THE GLIDER: 600 kg on a 20 m, 13.3 m^2 wing (AR 30), ESTIMATE tail.
    Spec glider{"glider", 600, 20.0f, 13.3f, 0.3f, 0.05f, 2.0f, 1.40f, 0.0f, 0.06f,
                1.5f, 5.5f, 0.6f, 0.20f, 1.0f, 5.8f, 0.8f, 0.22f,
                0.55f, 0.70f, 4.10f, {0, 0, 0}, 0.30f, 0, 0.10f, 3.2f, 1.0f, 1.1f, 30.0f};
    // THE F/A-18F, the game's 22 t: 13.68 m span (the game's), 46.45 m^2 (Wikipedia, "Boeing F/A-18E/F Super Hornet",
    // 500 sq ft). Stabilators and twin fins ESTIMATES. Stated inertia from the game's fighter_shape.
    Spec fighter{"fighter", 22000, 13.68f, 46.45f, 0.0f, 0.30f, -3.0f, 1.60f, 0.60f, 0.09f,
                 9.0f, 6.6f, 0.0f, 0.25f, 10.0f, 6.0f, 1.8f, 0.20f,
                 1.15f, 1.10f, 9.25f, {210000, 260000, 52000}, 0.0f, 196000, 3.9f, 27.0f, 5.0f, 0.34f, 150.0f};

    Craft c = make(cessna), g = make(glider), f = make(fighter);
    for (const Craft* k : {&c, &g, &f}) {
        std::printf("\n== %s: inertia pitch %.0f yaw %.0f roll %.0f kg m^2; tail incidence DERIVED %+.2f deg for cruise %.0f m/s\n",
                    k->k.name, k->I.x, k->I.y, k->I.z, k->af.s[2].alpha0 * 57.3f, k->k.cruise);
        std::printf("   stall: book clean %.1f, flown clean %.1f m/s; book flaps %.1f, flown flaps %.1f m/s\n",
                    book_stall(*k, 0), flown_stall(*k, 0), book_stall(*k, 1), flown_stall(*k, 1));
    }

    std::printf("\nROLL, full stick right, rudder centred\n");
    roll_rate(c, 30, false, 2.0f, 0.12f, "cessna raw 30 m/s");
    roll_rate(c, 50, false, 2.0f, 0.12f, "cessna raw 50 m/s");
    roll_rate(c, 50, true, 2.0f, 0.12f, "cessna law asks 2.0 rad/s, 50 m/s");
    roll_rate(g, 25, false, 1.0f, 0.12f, "glider raw 25 m/s");
    roll_rate(g, 35, false, 1.0f, 0.12f, "glider raw 35 m/s");
    {
        Craft gbox = g;
        gbox.I = {0, 0, 0};
        Spec s = glider;
        s.wing_share = 0.0f;
        gbox.I = inertia_of(s);
        std::printf("    (glider with the BOX inertia alone: roll %.0f kg m^2)\n", gbox.I.z);
        roll_rate(gbox, 35, false, 1.0f, 0.12f, "glider raw 35 m/s, BOX inertia");
    }
    roll_rate(f, 80, true, 2.25f, 0.08f, "fighter law asks 2.25, 80 m/s");
    roll_rate(f, 150, true, 2.25f, 0.08f, "fighter law asks 2.25, 150 m/s");
    roll_rate(f, 220, true, 2.25f, 0.08f, "fighter law asks 2.25, 220 m/s");
    roll_rate(f, 150, false, 2.25f, 0.08f, "fighter RAW, 150 m/s");

    std::printf("\nYANK, full back stick for two seconds\n");
    yank(c, 60, false, {1.2f, 2.0f, 0.8f, 5.0f}, "cessna raw, 60 m/s");
    yank(c, 60, true, {1.2f, 2.0f, 0.8f, 5.0f}, "cessna law (1.2 rad/s, 5 g), 60 m/s");
    yank(f, 200, true, {1.45f, 2.25f, 0.9f, 8.0f}, "fighter law (1.45 rad/s, 8 g), 200 m/s");
    yank(f, 200, false, {1.45f, 2.25f, 0.9f, 8.0f}, "fighter RAW, 200 m/s");

    std::printf("\nRUDDER ALONE (dihedral effect), raw, full right pedal\n");
    rudder_alone(c, 45, "cessna 45 m/s, 1.7 deg dihedral");
    {
        Spec flat = cessna;
        flat.dihedral_deg = 0.0f;
        flat.wing_y = 0.0f;
        rudder_alone(make(flat), 45, "cessna, NO DIHEDRAL, wing at the CG (mutant)");
    }
    std::printf("\nTHE STICK ON THE GROUND\n");
    stick_on_the_ground(c, 5.0f);
    stick_on_the_ground(f, 5.0f);
    stick_on_the_ground(c, 20.0f);
    stick_on_the_ground(f, 40.0f);

    std::printf("\nAUTOPILOT: the game's AircraftMixer, 90-degree turn and 100 m climb at once, from level at cruise\n");
    {
        // today's Cessna row (default_handling) and its box inertia, in the same harness
        Handling h{136, 0.05f, 0.30f, 140, 45, 30, 110, 110, 4.0f, 0.10f, 3.0f, 0.0f, 30000, 24, 1.2f, 2.0f, 0.8f, 5.0f, 9000};
        Spec box = cessna;
        box.wing_share = 0;
        Body b0 = body_of(c);
        b0.I = inertia_of(box);
        b0.drag_forward = 2.0f;
        b0.drag_vertical = 8.0f;
        b0.v = {0, 0, -55.1f};
        // today's stall_speed() and default_cruise(): sqrt(m g / (camber lift)) = 38.0, cruise max(min(0.55 x 67, 70), 1.45 x 38)
        const float today_stall = 38.0f, today_cruise = 55.1f;
        print_ap("today's cessna (rate servo)", fly_autopilot(b0, today_cruise, today_stall, 0.9f, [&](Body& b, const Controls& k) {
            tick_today(b, h, k);
        }));
        const float st = book_stall(c, 0);
        const float cr = std::fmax(std::fmin(0.55f * std::sqrt(9000.0f / 1.6f), 70.0f), st * 1.45f);
        Body b1 = body_of(c);
        b1.v = {0, 0, -cr};
        Rates r{1.2f, 2.0f, 0.8f, 5.0f};
        for (float settle : {0.12f, 0.06f, 0.03f}) {
            Law law{settle, 0};
            char label[80];
            std::snprintf(label, sizeof label, "surfaces + law, settle %.2f s", settle);
            print_ap(label, fly_autopilot(b1, cr, st, 0.9f, [&](Body& b, const Controls& k) {
                tick_surfaces(b, c, k, r, law, true);
            }));
        }
        std::printf("    (surface cessna: book stall %.1f, so the mixer's cruise is %.1f m/s)\n", st, cr);
    }
    {
        Handling h{2350, 0.072f, 0.30f, 1650, 820, 950, 1800, 1450, 4.5f, 0.25f, 13.0f, 0.0f, 4600000, 24, 1.45f, 2.25f, 0.9f, 8.0f, 196000};
        Body b0 = body_of(f);
        b0.drag_forward = 4.3f;
        b0.drag_vertical = 62.0f;
        b0.angular_damping = 0.34f;
        b0.v = {0, 0, -70.0f};
        print_ap("today's fighter (rate servo)", fly_autopilot(b0, 70.0f, 35.8f, 0.9f, [&](Body& b, const Controls& k) {
            tick_today(b, h, k);
        }));
        const float st = book_stall(f, 0);
        const float cr = std::fmax(std::fmin(0.55f * std::sqrt(196000.0f / 3.9f), 70.0f), st * 1.45f);
        Body b1 = body_of(f);
        b1.v = {0, 0, -cr};
        Rates r{1.45f, 2.25f, 0.9f, 8.0f};
        for (float settle : {0.12f, 0.06f}) {
            Law law{settle, 0};
            char label[80];
            std::snprintf(label, sizeof label, "surfaces + law, settle %.2f s", settle);
            print_ap(label, fly_autopilot(b1, cr, st, 0.9f, [&](Body& b, const Controls& k) {
                tick_surfaces(b, f, k, r, law, true);
            }));
        }
        std::printf("    (surface fighter: book stall %.1f, so the mixer's cruise is %.1f m/s)\n", st, cr);
    }
    return 0;
}
