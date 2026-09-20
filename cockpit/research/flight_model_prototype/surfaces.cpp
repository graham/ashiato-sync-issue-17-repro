#include "model.hpp"
// ------------------------------------------------------------------------------------------------------------------
static Airframe cessna(float dihedral_deg = 1.7f) {
    Airframe af{};
    af.rho = 1.225f;
    const float span = 11.0f, S = 16.2f, AR = span * span / S;
    const float a_wing = 6.2832f * AR / (AR + 2.0f) * 0.92f;  // finite span, e = 0.92-ish
    const float dh = dihedral_deg * 3.14159f / 180.0f;
    for (int side = 0; side < 2; ++side) {
        const float sgn = side == 0 ? 1.0f : -1.0f;  // right, left
        Surface s{};
        s.at = {sgn * 0.42f * span * 0.5f, 1.0f, 0.10f};
        s.normal = {-sgn * std::sin(dh), std::cos(dh), 0.0f};
        s.chord = {0, 0, -1};
        s.area = S * 0.5f;
        s.slope = a_wing;
        s.alpha0 = 0.07f;          // incidence 1.5 deg + camber 2.5 deg: the wing lifts with the nose on the flow
        s.stall = 0.30f;           // effective: CLmax = slope * stall ~ 1.35 clean (plus alpha0 in the angle)
        s.cd0 = 0.008f;
        s.k = 1.0f / (3.14159f * 0.8f * AR);
        s.downwash = 0.0f;
        // Aileron: right stick (+1) puts the right aileron UP, which is less angle on the right panel.
        s.mix[kRoll] = -sgn * 0.075f;
        s.mix[kFlaps] = 0.12f;
        af.s[side] = s;
    }
    {
        Surface t{};
        t.at = {0.0f, 0.3f, 4.6f};
        t.normal = {0, 1, 0};
        t.chord = {0, 0, -1};
        t.area = 3.4f;
        t.slope = 4.0f;
        t.alpha0 = -0.035f;  // tail incidence: DERIVED in the build from the trim at cruise; typed here
        t.stall = 0.30f;
        t.cd0 = 0.010f;
        t.k = 0.09f;
        t.downwash = 0.40f;
        t.mix[kPitch] = -0.20f;  // back stick (+1) is tail-DOWN lift, nose up
        af.s[2] = t;
    }
    {
        Surface fin{};
        fin.at = {0.0f, 0.9f, 4.8f};
        fin.normal = {-1, 0, 0};   // a fin's "lift" is sideways: flow from the right (sideslip right) pushes it left
        fin.chord = {0, 0, -1};
        fin.area = 1.9f;
        fin.slope = 2.6f;
        fin.alpha0 = 0.0f;
        fin.stall = 0.35f;
        fin.cd0 = 0.010f;
        fin.k = 0.15f;
        fin.mix[kYaw] = 0.22f;     // right pedal (+1): the rudder pushes the tail left, the nose right
        af.s[3] = fin;
    }
    af.count = 4;
    return af;
}

static float bank_of(const Body& b) {
    const V3 right = rot(b.q, {1, 0, 0});
    const V3 up = rot(b.q, {0, 1, 0});
    return std::atan2(-right.y, up.y);
}
static float pitch_of(const Body& b) {
    const V3 fwd = rot(b.q, {0, 0, -1});
    return std::asin(clampf(fwd.y, -1, 1));
}
static float heading_of(const Body& b) {
    const V3 fwd = rot(b.q, {0, 0, -1});
    return std::atan2(fwd.x, -fwd.z);
}

static Body cessna_body(bool box_inertia) {
    Body b{};
    b.p = {0, 1000, 0};
    b.q = {1, 0, 0, 0};
    b.mass = 1000.0f;
    if (box_inertia) {
        // The game's hull box: 1.6 x 1.7 x 8.3 m.
        const float hx = 0.8f, hy = 0.85f, hz = 4.15f, m = 1000.0f;
        b.I = {m / 3.0f * (hy * hy + hz * hz), m / 3.0f * (hx * hx + hz * hz), m / 3.0f * (hx * hx + hy * hy)};
    } else {
        // ESTIMATE, a C172's order of magnitude scaled to a tonne.
        b.I = {1640.0f, 2400.0f, 1160.0f};
    }
    b.angular_damping = 1.2f;
    b.drag_forward = 1.55f;  // the game's 2.0 less what the surfaces' own profile drag now carries
    b.drag_side = 3.5f;
    b.drag_vertical = 1.0f;  // the wing is the vertical drag now
    b.thrust = 9000.0f;
    return b;
}

static void set_level(Body& b, float speed, float pitch) {
    b.q = {std::cos(pitch * 0.5f), std::sin(pitch * 0.5f), 0, 0};  // about +X, nose up
    b.v = {0, 0, -speed};
    b.w = {0, 0, 0};
}

// ------------------------------------------------------------------------------------------------------------------
// Flight checks. Each prints what the airframe did; none of them is given the answer.
// ------------------------------------------------------------------------------------------------------------------
static const float kDt = 1.0f / 120.0f;
static Law kLaw{0.12f, 0.0f};

// Hold height with the stick through the law (pitch rate from a climb-rate error), at a throttle; report the settled speed.
static void trim_speed(const Airframe& af, float throttle, float elevator_bias, bool law, const char* label) {
    Body b = cessna_body(false);
    set_level(b, 45.0f, 0.02f);
    Pilot p;
    p.throttle = throttle;
    p.stick.u[kPitch] = elevator_bias;
    float sum_speed = 0, sum_vs = 0; int n = 0;
    for (int i = 0; i < 120 * 90; ++i) {
        tick(b, af, p, kLaw, kDt);
        if (i > 120 * 60) { sum_speed += len(b.v); sum_vs += b.v.y; ++n; }
    }
    std::printf("  %-44s speed %6.2f m/s  climb %+6.2f m/s  pitch %+5.1f deg\n", label, sum_speed / n, sum_vs / n,
                pitch_of(b) * 57.3f);
}

// Power-off, height held by a simple climb-rate loop on the pitch rate through the law: slow down until it cannot hold.
static float stall_flown(const Airframe& af, float flaps) {
    Body b = cessna_body(false);
    set_level(b, 40.0f, 0.03f);
    Pilot p;
    p.law = true;
    p.stick.u[kFlaps] = flaps;
    float slowest_level = 999.0f;
    for (int i = 0; i < 120 * 60; ++i) {
        const float climb = b.v.y;
        p.wanted = {clampf(0.08f * (0.0f - climb), -0.3f, 0.3f), 0.0f, clampf(-2.0f * bank_of(b), -0.5f, 0.5f)};
        Telemetry t;
        tick(b, af, p, kLaw, kDt, &t);
        if (std::fabs(climb) < 0.5f && t.speed < slowest_level) slowest_level = t.speed;
        if (climb < -4.0f) break;  // it has gone
    }
    return slowest_level;
}

// Full stick right, rudder centred, from wings level at a speed: roll rate, and which way the nose went first.
static void roll_step(const Airframe& af, float speed, bool box_inertia, bool law, float wanted_roll, const char* label) {
    Body b = cessna_body(box_inertia);
    // trim first: fly level through the law with wings held for 3 s
    set_level(b, speed, 0.02f);
    Pilot p;
    p.throttle = 0.6f;
    p.law = true;
    for (int i = 0; i < 360; ++i) {
        p.wanted = {clampf(0.1f * -b.v.y, -0.2f, 0.2f), 0.0f, clampf(-2.0f * bank_of(b), -1.0f, 1.0f)};
        tick(b, af, p, kLaw, kDt);
    }
    const float h0 = heading_of(b);
    float peak = 0, first_yaw = 0, t63 = -1;
    float beta_min = 0, beta_max = 0;
    float rate_at_1s = 0;
    std::vector<float> rates;
    for (int i = 0; i < 240; ++i) {
        if (law) {
            p.law = true;
            p.wanted = {0.0f, 0.0f, wanted_roll};
        } else {
            p.law = false;
            p.stick.u[kRoll] = 1.0f;
            p.stick.u[kPitch] = 0.0f;
            p.stick.u[kYaw] = 0.0f;
        }
        Telemetry t;
        tick(b, af, p, kLaw, kDt, &t);
        const float rr = -b.w.z;
        rates.push_back(rr);
        if (rr > peak) peak = rr;
        if (i == 30) first_yaw = heading_of(b) - h0;
        if (i == 119) rate_at_1s = rr;
        if (t.beta < beta_min) beta_min = t.beta;
        if (t.beta > beta_max) beta_max = t.beta;
        if (std::fabs(bank_of(b)) > 1.4f) break;
    }
    float settled = rates.back();
    for (size_t i = 0; i < rates.size(); ++i) if (rates[i] >= 0.632f * peak) { t63 = i * kDt; break; }
    std::printf("  %-44s peak %5.1f deg/s  t63 %.3f s  at 1 s %5.1f  nose after 0.25 s %+5.2f deg  slip %+4.1f..%+4.1f deg\n",
                label, peak * 57.3f, t63, rate_at_1s * 57.3f, first_yaw * 57.3f, beta_min * 57.3f, beta_max * 57.3f);
    (void)settled;
}

// Pull through the stall with the stick full back and power off; then let go. Report the break and the recovery.
static void stall_break(const Airframe& af, float asym) {
    Airframe a = af;
    // a real wing is never quite symmetric: one panel stalls a hair earlier (rigging, a gust, a yaw rate)
    a.s[0].stall -= asym;
    Body b = cessna_body(false);
    set_level(b, 35.0f, 0.05f);
    Pilot p;
    p.throttle = 0.0f;
    float max_alpha = 0, max_bank = 0, min_speed = 99, lost = 0;
    const float y0 = b.p.y;
    for (int i = 0; i < 120 * 12; ++i) {
        p.law = false;
        p.stick.u[kPitch] = i < 120 * 6 ? 1.0f : 0.0f;  // held back 6 s, then released
        p.stick.u[kRoll] = 0.0f;
        Telemetry t;
        tick(b, a, p, kLaw, kDt, &t);
        if (t.alpha > max_alpha) max_alpha = t.alpha;
        if (std::fabs(bank_of(b)) > max_bank) max_bank = std::fabs(bank_of(b));
        if (t.speed < min_speed) min_speed = t.speed;
    }
    lost = y0 - b.p.y;
    std::printf("  stall, stick held back 6 s then released, panel asymmetry %.3f rad: max alpha %4.1f deg, max bank %5.1f deg, "
                "min speed %4.1f m/s, height lost %5.1f m, flying again at %4.1f m/s pitch %+5.1f\n",
                asym, max_alpha * 57.3f, max_bank * 57.3f, min_speed, lost, len(b.v), pitch_of(b) * 57.3f);
}

// ------------------------------------------------------------------------------------------------------------------
// TIMING
// ------------------------------------------------------------------------------------------------------------------
static volatile float sink;

static double time_today(int aircraft, int iterations) {
    Handling h{136, 0.05f, 0.30f, 140, 45, 30, 110, 110, 4.0f, 0.10f, 3.0f, 1.0f, 30000, 24, 1.2f, 2.0f, 0.8f, 5.0f, 9000};
    std::vector<Frame> frames(aircraft);
    std::vector<Controls> ctl(aircraft);
    srand(7);
    for (int i = 0; i < aircraft; ++i) {
        Frame& f = frames[i];
        float a = (rand() % 1000) * 0.001f;
        f.forward = {std::sin(a) * 0.1f, 0.05f, -1.0f};
        f.up = {0.02f, 1.0f, 0.05f};
        f.right = {1.0f, -0.02f, std::sin(a) * 0.1f};
        f.spin = {0.1f * a, 0.05f, -0.2f * a};
        f.along = 40.0f + 30.0f * a;
        f.sideways = 1.0f - a;
        f.vertical = -2.0f * a;
        f.speed = f.along + 1.0f;
        f.mass = 1000.0f;
        float inv[9] = {1 / 1640.f, 0, 0, 0, 1 / 2400.f, 0, 0, 0, 1 / 1160.f};
        std::memcpy(f.inv_inertia, inv, sizeof inv);
        ctl[i] = {a - 0.5f, 0.5f - a, 0.1f, 0.7f, 0.0f};
    }
    auto t0 = std::chrono::high_resolution_clock::now();
    float acc = 0;
    int calls = 0;
    for (int it = 0; it < iterations; ++it) {
        for (int i = 0; i < aircraft; ++i) {
            Out o{{0, 0, 0}, {0, 0, 0}, 0};
            today(h, frames[i], ctl[i], 1.0f / 120.0f, o);
            acc += o.force.x + o.torque.y;
            calls = o.calls;
        }
    }
    auto t1 = std::chrono::high_resolution_clock::now();
    sink = acc;
    std::printf("  (today: %d Box3D calls per aircraft per tick, not timed here)\n", calls);
    return std::chrono::duration<double, std::nano>(t1 - t0).count() / (double(aircraft) * iterations);
}

static double time_surfaces(int aircraft, int iterations, int surface_count, bool law) {
    Airframe af = cessna();
    if (surface_count > af.count) {
        // add a fuselage-as-a-surface or split the tailplane, whichever the count asks for
        for (int i = af.count; i < surface_count; ++i) af.s[i] = af.s[2], af.s[i].area *= 0.5f, af.s[i].at.x = (i % 2 ? 1.f : -1.f);
    }
    af.count = surface_count;
    std::vector<V3> vel(aircraft), spin(aircraft);
    std::vector<SurfaceInput> ins(aircraft);
    srand(7);
    for (int i = 0; i < aircraft; ++i) {
        float a = (rand() % 1000) * 0.001f;
        vel[i] = {1.0f - a, -2.0f * a, -(40.0f + 30.0f * a)};
        spin[i] = {0.1f * a, 0.05f, -0.2f * a};
        ins[i] = {{a - 0.5f, 0.5f - a, 0.1f, 0.0f}};
    }
    V3 I{1640, 2400, 1160};
    auto t0 = std::chrono::high_resolution_clock::now();
    float acc = 0;
    for (int it = 0; it < iterations; ++it) {
        for (int i = 0; i < aircraft; ++i) {
            SurfaceOut o;
            const float wa = std::atan2(-vel[i].y, -vel[i].z);
            SurfaceInput in = ins[i];
            surfaces(af, vel[i], spin[i], in, o, wa);
            if (law) {
                control_law(kLaw, I, o, spin[i], {0.1f, 0.0f, 0.5f}, 1.0f, in);
                o.torque = o.torque + o.per_unit[kPitch] * in.u[kPitch] + o.per_unit[kRoll] * in.u[kRoll]
                    + o.per_unit[kYaw] * in.u[kYaw];
            }
            // into world axes, as the game would before its two Box3D calls
            Q q{0.99f, 0.05f, 0.02f, 0.01f};
            V3 fw = rot(q, o.force), tw = rot(q, o.torque);
            acc += fw.x + tw.y;
        }
    }
    auto t1 = std::chrono::high_resolution_clock::now();
    sink = acc;
    return std::chrono::duration<double, std::nano>(t1 - t0).count() / (double(aircraft) * iterations);
}

int main(int argc, char** argv) {
    const bool timing_only = argc > 1 && std::strcmp(argv[1], "--timing") == 0;
    std::printf("TIMING, ns per aircraft per tick (1,000 aircraft x 2,000 ticks, median of 5)\n");
    auto median5 = [](auto fn) {
        double v[5];
        for (int i = 0; i < 5; ++i) v[i] = fn();
        for (int i = 0; i < 5; ++i) for (int j = i + 1; j < 5; ++j) if (v[j] < v[i]) { double t = v[i]; v[i] = v[j]; v[j] = t; }
        return v[2];
    };
    std::printf("  today's fly_airplane + apply_controls      %6.1f\n", median5([] { return time_today(1000, 2000); }));
    std::printf("  surfaces, 4 (wing L/R, tail, fin), raw     %6.1f\n", median5([] { return time_surfaces(1000, 2000, 4, false); }));
    std::printf("  surfaces, 4, with the control law          %6.1f\n", median5([] { return time_surfaces(1000, 2000, 4, true); }));
    std::printf("  surfaces, 6, with the control law          %6.1f\n", median5([] { return time_surfaces(1000, 2000, 6, true); }));
    if (timing_only) return 0;

    const Airframe af = cessna();
    std::printf("\nTRIM: hands off (raw stick), level entry at 45 m/s, settled over the last 30 s of 90\n");
    trim_speed(af, 0.35f, 0.0f, false, "throttle 0.35, elevator 0");
    trim_speed(af, 0.35f, 0.15f, false, "throttle 0.35, elevator +0.15 (back)");
    trim_speed(af, 0.35f, 0.30f, false, "throttle 0.35, elevator +0.30 (back)");
    trim_speed(af, 0.60f, 0.0f, false, "throttle 0.60, elevator 0");

    std::printf("\nSTALL, power off, height held through the law until it cannot be\n");
    std::printf("  clean: slowest level %.1f m/s   flaps full: %.1f m/s\n", stall_flown(af, 0.0f), stall_flown(af, 1.0f));

    std::printf("\nROLL, full stick right, rudder centred, from level\n");
    roll_step(af, 30.0f, false, false, 0, "raw, 30 m/s, stated inertia");
    roll_step(af, 50.0f, false, false, 0, "raw, 50 m/s, stated inertia");
    roll_step(af, 65.0f, false, false, 0, "raw, 65 m/s, stated inertia");
    roll_step(af, 50.0f, true, false, 0, "raw, 50 m/s, BOX inertia");
    roll_step(af, 50.0f, false, true, 2.0f, "law asks 2.0 rad/s (today's), 50 m/s");
    roll_step(af, 30.0f, false, true, 2.0f, "law asks 2.0 rad/s, 30 m/s");
    roll_step(af, 50.0f, true, true, 2.0f, "law asks 2.0 rad/s, 50 m/s, BOX inertia");
    {
        Airframe flat = cessna(0.0f);
        roll_step(flat, 50.0f, false, false, 0, "raw, 50 m/s, NO DIHEDRAL (mutant)");
        Airframe no_k = cessna();
        for (int i = 0; i < 2; ++i) no_k.s[i].k = 0.0f;
        roll_step(no_k, 50.0f, false, false, 0, "raw, 50 m/s, NO INDUCED DRAG (adverse-yaw mutant)");
    }

    std::printf("\nSTALL BREAK\n");
    stall_break(af, 0.0f);
    stall_break(af, 0.01f);
    return 0;
}
