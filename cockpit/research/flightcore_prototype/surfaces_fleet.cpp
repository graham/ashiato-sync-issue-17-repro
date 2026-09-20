// ## THREE AEROPLANES OUT OF ONE LIST OF PANELS: the Cessna (which must come out exactly as the game builds it today),
// ## the F/A-18F (two canted fins, stabilators that roll) and the P-38 (two booms, two fins, a tailplane between them).
// ##
// ## Every number is read off the kind's own airframe in `cockpit/objects/vehicles/`, in the units those files use
// ## (stations metres aft of the nose, heights metres over the ground at rest, spans metres from the centreline), so a
// ## suite could hold the two together later. The P-38's are from lane/warbirds2's `p38_airframe.gd`, which measures
// ## them off AN 01-75FF-2. Masses, cruises and CLmax are marked ESTIMATE where the repo has no published figure: they
// ## move the trim and the stall speed, not the shape of anything this is testing.
// ##
// ## THE CESSNA IS THE REGRESSION: the same numbers go through the game's own `build_wing` and through the panel list,
// ## and the two are printed side by side. A generalisation that changes the one aeroplane already flying on it is not
// ## a generalisation.
#include "panel_wing.hpp"
#include "../../../ashiato-gd/src/cockpit/lifting_surfaces.hpp"

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <initializer_list>
#include <vector>

using namespace flightcore::panels;
namespace game = ashiato_gd::cockpit::aero;

namespace {

constexpr float kDeg = kPi / 180.0f;

/// A TRAPEZOIDAL PANEL, integrated from its rows of [out, leading edge, trailing edge]: its area (both sides), the
/// spanwise centroid of one side, and the quarter chord's station there.
struct Plan {
    float area = 0.0f;       // both sides
    float centroid = 0.0f;   // metres from the centreline
    float quarter = 0.0f;    // station of the quarter chord at the centroid
    float mac = 0.0f;
};

Plan integrate(const std::vector<std::array<float, 3>>& rows) {
    Plan p;
    float moment = 0.0f;
    float mac_sum = 0.0f;
    for (std::size_t i = 1; i < rows.size(); ++i) {
        const float y0 = rows[i - 1][0];
        const float y1 = rows[i][0];
        const float c0 = rows[i - 1][2] - rows[i - 1][1];
        const float c1 = rows[i][2] - rows[i][1];
        const float strip = 0.5f * (c0 + c1) * (y1 - y0);
        p.area += strip;
        moment += strip * 0.5f * (y0 + y1);
        mac_sum += 0.5f * (c0 * c0 + c1 * c1) * (y1 - y0);
    }
    p.centroid = moment / std::fmax(p.area, 1e-6f);
    p.mac = mac_sum / std::fmax(p.area, 1e-6f);
    // The quarter chord at the centroid, by walking the rows to it.
    for (std::size_t i = 1; i < rows.size(); ++i) {
        if (rows[i][0] >= p.centroid || i + 1 == rows.size()) {
            const float t = (p.centroid - rows[i - 1][0]) / std::fmax(rows[i][0] - rows[i - 1][0], 1e-6f);
            const float le = rows[i - 1][1] + t * (rows[i][1] - rows[i - 1][1]);
            const float te = rows[i - 1][2] + t * (rows[i][2] - rows[i - 1][2]);
            p.quarter = le + 0.25f * (te - le);
            break;
        }
    }
    p.area *= 2.0f;  // both sides
    return p;
}

/// A polygon's area, for a fin drawn as an outline (the shoelace).
float polygon(const std::vector<std::array<float, 2>>& points) {
    float sum = 0.0f;
    for (std::size_t i = 0; i < points.size(); ++i) {
        const auto& a = points[i];
        const auto& b = points[(i + 1) % points.size()];
        sum += a[0] * b[1] - b[0] * a[1];
    }
    return std::fabs(sum) * 0.5f;
}

/// THE STEADY ROLL RATE at a speed with the stick hard over: the rate at which the panels' own damping cancels the
/// ailerons, found by bisection. It needs no inertia, which is the point of asking it this way.
float roll_rate(const Airframe& a, float speed, float aileron) {
    const float u[kChannels] = {0.0f, aileron, 0.0f, 0.0f};
    const auto moment = [&](float p) {
        // A roll to the right is about the nose, which is -Z.
        const Loads l = evaluate(a, Vec{0.0f, 0.0f, -speed}, Vec{0.0f, 0.0f, -p}, u, 0.0f);
        return -l.torque.z;
    };
    float lo = 0.0f;
    float hi = 12.0f;
    if (moment(lo) <= 0.0f) {
        return 0.0f;
    }
    for (int i = 0; i < 40; ++i) {
        const float mid = 0.5f * (lo + hi);
        (moment(mid) > 0.0f ? lo : hi) = mid;
    }
    return 0.5f * (lo + hi);
}

/// WHAT FULL RUDDER MAKES, at a speed, with the wings level and nothing turning: the yaw it is for, and the roll it
/// brings with it. On one fin on the centreline the roll is the fin's height above the centre of gravity; on two fins
/// out on booms there is the booms' arm as well, which is what this exists to show.
void rudder(const Airframe& a, float speed, float& yaw, float& roll) {
    const float u[kChannels] = {0.0f, 0.0f, 1.0f, 0.0f};
    const Loads l = evaluate(a, Vec{0.0f, 0.0f, -speed}, Vec{}, u, 0.0f);
    const float none[kChannels] = {0.0f, 0.0f, 0.0f, 0.0f};
    const Loads base = evaluate(a, Vec{0.0f, 0.0f, -speed}, Vec{}, none, 0.0f);
    yaw = l.torque.y - base.torque.y;
    roll = -(l.torque.z - base.torque.z);
}

void report(const char* name, Airframe& a, const Hull& h, float speed, const char* notes) {
    trim(a, h.mass, h.cruise);
    std::printf("\n%s (%s)\n", name, notes);
    std::printf("  %d panels, reference area %.2f m^2, mean chord %.2f m, %.0f kg\n", a.count, a.area, a.mac, h.mass);
    for (int i = 0; i < a.count; ++i) {
        const Panel& p = a.panel[i];
        std::printf("    %-16s at (%6.2f, %5.2f, %6.2f) m, %5.2f m^2, slope %.2f, normal (%5.2f, %5.2f), stall %.1f deg\n",
                    p.name, p.at.x, p.at.y, p.at.z, p.area, p.slope, p.normal.x, p.normal.y, p.stall / kDeg);
    }
    std::printf("  neutral point %.2f m aft of the nose, centre of gravity %.2f (%.0f%% of the mean chord ahead)\n",
                a.neutral, a.cg_station, a.static_margin * 100.0f);
    std::printf("  the trimming panel's incidence: %+.2f degrees at %.0f m/s\n", a.trim_incidence / kDeg, h.cruise);
    std::printf("  stall speed clean %.1f m/s, with flap %.1f m/s\n", stall_speed(a, h.mass, 0.0f),
                stall_speed(a, h.mass, 1.0f));
    std::printf("  full aileron at %.0f m/s: %.0f deg/s of roll (pb/2V %.3f)\n", speed, roll_rate(a, speed, 1.0f) / kDeg,
                roll_rate(a, speed, 1.0f) * (a.area / a.mac) * 0.5f / speed / 2.0f);
    float yaw = 0.0f;
    float roll = 0.0f;
    rudder(a, speed, yaw, roll);
    std::printf("  full rudder at %.0f m/s: %.0f kN m of yaw, %.0f kN m of roll with it (%.0f%% of the yaw)\n",
                speed, yaw / 1000.0f, roll / 1000.0f, 100.0f * roll / (std::fabs(yaw) + 1e-3f));
}

}  // namespace

int main() {
    // ---------------------------------------------------------------------------------------------------------------
    // THE CESSNA, both ways. The numbers are `planform_of`'s, unchanged.
    // ---------------------------------------------------------------------------------------------------------------
    Hull cessna_hull;
    cessna_hull.length = 8.28f;
    cessna_hull.rest = 0.8499f;
    cessna_hull.mass = 1000.0f;
    cessna_hull.static_margin = 0.15f;
    cessna_hull.cruise = 110.0f * 0.514444f;
    cessna_hull.clmax = 1.45f;
    cessna_hull.flap_clmax = 0.43f;
    const float cessna_slope = finite_slope(11.0f * 11.0f / 16.2f);
    WingPair cessna_wing;
    cessna_wing.span = 11.0f;
    cessna_wing.area = 16.2f;
    cessna_wing.quarter_chord_station = 2.32f;
    cessna_wing.quarter_chord_height = 1.93f;
    cessna_wing.centroid_out = 0.42f * 11.0f * 0.5f;  // the game's `panel_out`
    cessna_wing.dihedral = 0.030194f;
    cessna_wing.alpha0 = 0.0066f + 0.0367f;
    cessna_wing.aileron_up = 0.349066f;
    cessna_wing.aileron_down = 0.261799f;
    cessna_wing.aileron_share = 0.42f;
    cessna_wing.aileron_tau = 0.315f;
    cessna_wing.flap_share = 0.43f / cessna_slope;
    cessna_wing.cd0 = 0.007f;
    cessna_wing.oswald = 0.8f;
    Tail cessna_tail;
    cessna_tail.area = 2.9f;
    cessna_tail.span = 3.45f;
    cessna_tail.station = 6.69f;
    cessna_tail.height = 0.86f;
    cessna_tail.elevator_up = 0.488692f;
    cessna_tail.elevator_down = 0.401426f;
    cessna_tail.tau = 0.5f;
    Fin cessna_fin;
    cessna_fin.area = 1.2f;
    cessna_fin.height = 1.3f;
    cessna_fin.station = 7.1f;
    cessna_fin.centroid_height = 1.65f;
    cessna_fin.rudder_travel = 0.309523f;
    cessna_fin.tau = 0.6f;
    Airframe cessna;
    add_wing(cessna, cessna_hull, cessna_wing);
    add_tail(cessna, cessna_hull, cessna_tail);
    add_fins(cessna, cessna_hull, cessna_fin);
    settle(cessna, cessna_hull);
    trim(cessna, cessna_hull.mass, cessna_hull.cruise);

    // The same numbers through the game's builder.
    game::Planform p;
    p.length = 8.28f;
    p.rest = 0.8499f;
    p.span = 11.0f;
    p.area = 16.2f;
    p.quarter_chord_station = 2.32f;
    p.quarter_chord_height = 1.93f;
    p.dihedral = 0.030194f;
    p.alpha0 = 0.0066f + 0.0367f;
    p.aileron_up = 0.349066f;
    p.aileron_down = 0.261799f;
    p.aileron_share = 0.42f;
    p.aileron_tau = 0.315f;
    p.tail_area = 2.9f;
    p.tail_span = 3.45f;
    p.tail_station = 6.69f;
    p.tail_height = 0.86f;
    p.elevator_up = 0.488692f;
    p.elevator_down = 0.401426f;
    p.elevator_tau = 0.5f;
    p.fin_area = 1.2f;
    p.fin_height = 1.3f;
    p.fin_station = 7.1f;
    p.fin_centroid_height = 1.65f;
    p.rudder_travel = 0.309523f;
    p.rudder_tau = 0.6f;
    p.static_margin = 0.15f;
    p.cruise = cessna_hull.cruise;
    game::Wing built = game::build_wing(p, 1.45f, 0.43f, 2.0f, 3.5f, 8.0f);
    game::trim_the_tail(built, 1000.0f, cessna_hull.cruise);

    std::printf("THE CESSNA, the game's builder against the panel list (they must agree)\n");
    std::printf("  %-16s %-34s %s\n", "", "the game", "the panels");
    for (int i = 0; i < 4; ++i) {
        const game::Surface& g = built.s[i];
        const Panel& n = cessna.panel[i];
        std::printf("  %-16s (%6.2f,%5.2f,%6.2f) %5.2f m^2 %5.3f | (%6.2f,%5.2f,%6.2f) %5.2f m^2 %5.3f\n", n.name,
                    g.at.x, g.at.y, g.at.z, g.area, g.slope, n.at.x, n.at.y, n.at.z, n.area, n.slope);
    }
    std::printf("  centre of gravity aft of the nose: %.4f | %.4f\n", built.centre.z + 0.5f * p.length,
                cessna.centre.z + 0.5f * cessna_hull.length);
    std::printf("  the tail's derived incidence: %+.4f deg | %+.4f deg\n", built.tail_incidence / kDeg,
                cessna.trim_incidence / kDeg);
    std::printf("  stall speed clean: %.3f | %.3f m/s\n", game::stall_speed(built, 1000.0f, 0.0f),
                stall_speed(cessna, 1000.0f, 0.0f));
    report("THE CESSNA 172S", cessna, cessna_hull, 50.0f, "one fin, one tailplane: what the four-surface table holds");

    // ---------------------------------------------------------------------------------------------------------------
    // THE F/A-18F: `fighter_airframe.gd`, [NAVY] and [HARV].
    // ---------------------------------------------------------------------------------------------------------------
    Hull hornet;
    hornet.length = 18.38f;
    hornet.rest = 2.20f;  // fighter_airframe measures heights over the GROUND, and the hull's origin is its box's
                          // middle, `fighter_shape`'s hy: the panels' arms are about the centre of gravity, not the tarmac
    hornet.mass = 22000.0f;
    hornet.static_margin = 0.05f;  // a fighter is flown nearly neutral: ESTIMATE
    hornet.cruise = 150.0f;
    hornet.clmax = 1.20f;          // the plan's decision C: a game-sized maximum lift until the carrier has wires
    hornet.flap_clmax = 0.45f;
    const float root_le = 9.30f;
    const float root_out = 1.62f;
    const float tip_out = 6.66f;
    const float tip_le = root_le + (tip_out - root_out) * std::tan(26.5f * kDeg);
    const float tip_te = tip_le + 2.05f;
    const float root_te = tip_te + (tip_out - root_out) * std::tan(2.6f * kDeg);
    const Plan hornet_wing = integrate({{{root_out, root_le, root_te}}, {{tip_out, tip_le, tip_te}}});
    WingPair hw;
    hw.span = 13.68f;
    hw.area = 46.45f;  // [NAVY] through craft/fighter/sources.md: the reference area, more than the drawn panels
    hw.quarter_chord_station = hornet_wing.quarter;
    hw.quarter_chord_height = 2.05f;
    hw.centroid_out = hornet_wing.centroid;
    hw.dihedral = -3.0f * kDeg;  // anhedral
    hw.alpha0 = 0.0f;
    hw.aileron_up = 20.0f * kDeg;
    hw.aileron_down = 20.0f * kDeg;
    hw.aileron_share = 0.35f;  // the share of the panel the aileron SPANS (ESTIMATE); its chord's share is the tau below
    hw.aileron_tau = 0.55f;  // TEF_CHORD 0.28 of the chord, so rather more than a quarter chord's 0.45
    hw.flap_share = 0.45f / finite_slope(13.68f * 13.68f / 46.45f);
    hw.cd0 = 0.008f;
    hw.oswald = 0.75f;
    Tail stab;
    {
        const float r0 = 14.8f;
        const float r1 = 17.9f;
        const float t0 = 17.05f;
        const float t1 = 18.38f;
        const Plan plan = integrate({{{1.02f, r0, r1}}, {{3.65f, t0, t1}}});
        stab.area = plan.area;
        stab.span = 2.0f * 3.65f;
        stab.station = plan.quarter;
        stab.height = 1.95f;
        stab.out = plan.centroid;
        stab.elevator_up = 24.0f * kDeg;  // a stabilator: the whole surface moves. ESTIMATE of its travel
        stab.elevator_down = 10.0f * kDeg;
        stab.tau = 1.0f;                  // an all-moving surface has no flap effectiveness to lose
        stab.roll_travel = 6.0f * kDeg;   // differential, as tomcat2 records for the F-14's tail
        stab.anhedral = -2.0f * kDeg;
    }
    Fin hornet_fin;
    {
        const Plan plan = integrate({{{0.0f, 12.9f, 16.6f}}, {{2.47f, 15.3f, 16.65f}}});
        hornet_fin.area = 0.5f * plan.area;  // integrate() doubled it; each fin is one of them
        hornet_fin.height = 2.47f;           // root 2.40 m up to the aircraft's 4.87 m
        hornet_fin.station = plan.quarter;
        hornet_fin.centroid_height = 2.40f + 0.4f * 2.47f;
        hornet_fin.out = 0.90f;
        hornet_fin.count = 2;
        hornet_fin.cant = 20.0f * kDeg;
        hornet_fin.rudder_travel = 30.0f * kDeg;
        hornet_fin.tau = 0.5f;
        hornet_fin.end_plated_by_the_fuselage = false;  // a pair out on the shoulders is not
    }
    Airframe hornet_air;
    add_wing(hornet_air, hornet, hw);
    add_tail(hornet_air, hornet, stab);
    add_fins(hornet_air, hornet, hornet_fin);
    settle(hornet_air, hornet);
    report("THE F/A-18F SUPER HORNET", hornet_air, hornet, 150.0f,
           "two fins canted 20 degrees, stabilators that roll; mass, CLmax and travels ESTIMATE");
    // WHAT THE CANT AND THE STABILATOR CHANGE, measured: both are things a four-surface table cannot say at all.
    {
        Fin upright = hornet_fin;
        upright.cant = 0.0f;
        Airframe flat;
        add_wing(flat, hornet, hw);
        add_tail(flat, hornet, stab);
        add_fins(flat, hornet, upright);
        settle(flat, hornet);
        trim(flat, hornet.mass, hornet.cruise);
        float yaw_c = 0.0f;
        float roll_c = 0.0f;
        float yaw_f = 0.0f;
        float roll_f = 0.0f;
        rudder(hornet_air, 150.0f, yaw_c, roll_c);
        rudder(flat, 150.0f, yaw_f, roll_f);
        std::printf("\n  what the cant changes: canted 20 deg, %.0f kN m of yaw and %.0f of roll; upright, %.0f and %.0f\n",
                    yaw_c / 1000.0f, roll_c / 1000.0f, yaw_f / 1000.0f, roll_f / 1000.0f);
        Tail plain = stab;
        plain.roll_travel = 0.0f;
        Airframe no_stab_roll;
        add_wing(no_stab_roll, hornet, hw);
        add_tail(no_stab_roll, hornet, plain);
        add_fins(no_stab_roll, hornet, hornet_fin);
        settle(no_stab_roll, hornet);
        trim(no_stab_roll, hornet.mass, hornet.cruise);
        std::printf("  what the rolling stabilator is worth: %.0f deg/s of roll at 150 m/s against %.0f without it\n",
                    roll_rate(hornet_air, 150.0f, 1.0f) / kDeg, roll_rate(no_stab_roll, 150.0f, 1.0f) / kDeg);
    }

    // ---------------------------------------------------------------------------------------------------------------
    // THE P-38L: lane/warbirds2's `p38_airframe.gd`, measured off AN 01-75FF-2.
    // ---------------------------------------------------------------------------------------------------------------
    Hull lightning;
    lightning.length = 11.53f;
    lightning.rest = 0.0f;
    lightning.mass = 7940.0f;    // 17,500 lb loaded: ESTIMATE until it is in craft/p38/sources.md
    lightning.static_margin = 0.12f;
    lightning.cruise = 120.0f;   // ESTIMATE
    lightning.clmax = 1.45f;     // ESTIMATE
    lightning.flap_clmax = 0.50f;
    const std::vector<std::array<float, 3>> wing_rows = {
        {{0.45f, 2.99f, 5.66f}},   {{1.00f, 3.003f, 5.639f}}, {{1.50f, 3.030f, 5.549f}}, {{2.92f, 3.085f, 5.470f}},
        {{3.50f, 3.210f, 5.219f}}, {{4.00f, 3.258f, 5.134f}}, {{4.50f, 3.301f, 5.060f}}, {{5.00f, 3.349f, 4.975f}},
        {{5.50f, 3.391f, 4.890f}}, {{6.00f, 3.434f, 4.805f}}, {{6.50f, 3.476f, 4.725f}}, {{7.00f, 3.513f, 4.629f}},
        {{7.20f, 3.535f, 4.582f}}, {{7.40f, 3.556f, 4.481f}}, {{7.50f, 3.577f, 4.422f}}, {{7.60f, 3.598f, 4.364f}},
        {{7.70f, 3.614f, 4.284f}}, {{7.80f, 3.657f, 4.167f}}, {{7.90f, 3.758f, 3.859f}}, {{7.925f, 3.80f, 3.82f}}};
    const Plan p38_wing = integrate(wing_rows);
    WingPair lw;
    lw.span = 15.85f;
    lw.area = p38_wing.area;  // drawn, not published: 30.4 m^2 is the usual figure
    lw.quarter_chord_station = p38_wing.quarter;
    lw.quarter_chord_height = 0.30f;  // the wing on the reference line, roughly: ESTIMATE
    lw.centroid_out = p38_wing.centroid;
    lw.dihedral = (5.0f + 40.0f / 60.0f) * kDeg;
    lw.alpha0 = 0.03f;  // ESTIMATE
    lw.aileron_up = 20.0f * kDeg;
    lw.aileron_down = 15.0f * kDeg;
    lw.aileron_share = (7.341f - 4.623f) / (0.5f * 15.85f);  // AILERON_SPAN: 2.718 m of a 7.925 m half span
    lw.aileron_tau = 0.45f;  // hinged at 70 per cent of the chord (AILERON_HINGE_SHARE), a quarter chord's effectiveness
    lw.flap_share = 0.50f / finite_slope(15.85f * 15.85f / p38_wing.area);
    lw.cd0 = 0.008f;
    lw.oswald = 0.8f;
    Tail p38_tail;
    p38_tail.area = 6.629f * (10.800f - 9.684f);
    p38_tail.span = 6.629f;
    p38_tail.station = 9.684f + 0.25f * (10.800f - 9.684f);
    p38_tail.height = 0.407f;
    p38_tail.out = 1.60f;  // each half's centroid, between the boom and the tip
    p38_tail.elevator_up = 25.0f * kDeg;
    p38_tail.elevator_down = 20.0f * kDeg;
    p38_tail.tau = 0.5f;
    p38_tail.end_plated = true;  // THE BOOMS' FINS ARE ITS END PLATES
    Fin p38_fin;
    {
        const float fin_area = polygon({{{9.94f, 0.742f}},
                                        {{10.05f, 1.058f}},
                                        {{10.26f, 1.427f}},
                                        {{10.45f, 1.60f}},
                                        {{10.62f, 1.648f}},
                                        {{10.725f, 1.64f}},
                                        {{10.725f, -0.469f}},
                                        {{10.41f, -0.363f}},
                                        {{10.15f, 0.005f}},
                                        {{10.01f, 0.268f}}});
        const float rudder_area = polygon({{{10.735f, 1.64f}},
                                           {{11.05f, 1.585f}},
                                           {{11.36f, 1.269f}},
                                           {{11.53f, 0.742f}},
                                           {{11.53f, 0.426f}},
                                           {{11.41f, 0.005f}},
                                           {{11.15f, -0.311f}},
                                           {{10.735f, -0.469f}}});
        p38_fin.area = fin_area + rudder_area;
        p38_fin.height = 1.648f + 0.469f;
        p38_fin.station = 10.3f;
        p38_fin.centroid_height = 0.60f;
        p38_fin.out = 2.438f;  // PRINTED_BOOM_OUT
        p38_fin.count = 2;
        p38_fin.cant = 0.0f;
        p38_fin.rudder_travel = 25.0f * kDeg;
        p38_fin.tau = 0.6f;
        p38_fin.end_plated_by_the_fuselage = false;
    }
    Airframe p38;
    add_wing(p38, lightning, lw);
    add_tail(p38, lightning, p38_tail);
    add_fins(p38, lightning, p38_fin);
    settle(p38, lightning);
    report("THE P-38L LIGHTNING", p38, lightning, 100.0f,
           "two booms, two fins 2.438 m out, a tailplane end-plated between them; mass and CLmax ESTIMATE");

    // WHAT THE BOOMS ACTUALLY CHANGE, measured rather than asserted. Two of these are why a twin boom cannot be said as
    // one fin of the summed area and a plain tailplane, and the third is why the boom's own offset is NOT among them.
    {
        const float each = p38_fin.area;
        const float boom_aspect = p38_fin.height * p38_fin.height / each;               // no end plate
        const float single_aspect = 2.0f * p38_fin.height * p38_fin.height / (2.0f * each);  // one fin, fuselage plate
        std::printf("\n  what the booms change:\n");
        std::printf("    two fins of %.2f m^2 each: aspect %.2f, slope %.2f each, %.2f between them\n", each,
                    boom_aspect, finite_slope(boom_aspect), 2.0f * finite_slope(boom_aspect) * each);
        std::printf("    ONE fin of %.2f m^2 on a fuselage would be: aspect %.2f, slope %.2f, %.2f altogether\n",
                    2.0f * each, single_aspect, finite_slope(single_aspect), finite_slope(single_aspect) * 2.0f * each);
        const float plated = finite_slope(1.3f * p38_tail.span * p38_tail.span / p38_tail.area);
        const float bare = finite_slope(p38_tail.span * p38_tail.span / p38_tail.area);
        std::printf("    the tailplane between them: slope %.2f end-plated against %.2f bare, %+.0f%%\n", plated, bare,
                    100.0f * (plated / bare - 1.0f));
        float yaw_out = 0.0f;
        float roll_out = 0.0f;
        rudder(p38, 100.0f, yaw_out, roll_out);
        Airframe centred = p38;
        for (int i = 0; i < centred.count; ++i) {
            if (centred.panel[i].normal.y < 0.5f) {
                centred.panel[i].at.x = 0.0f;  // the same two fins, moved onto the centreline
            }
        }
        float yaw_in = 0.0f;
        float roll_in = 0.0f;
        rudder(centred, 100.0f, yaw_in, roll_in);
        std::printf("    the booms' own offset, with the fins moved to the centreline: yaw %.0f against %.0f kN m,\n"
                    "      roll %.0f against %.0f kN m -- a SIDE force at an arm out to the side makes neither, so the\n"
                    "      offset is not what a twin boom needs said; the fins' own aspect ratio and the end plate are\n",
                    yaw_in / 1000.0f, yaw_out / 1000.0f, roll_in / 1000.0f, roll_out / 1000.0f);
    }

    // ---------------------------------------------------------------------------------------------------------------
    // What it costs to evaluate each, per tick.
    // ---------------------------------------------------------------------------------------------------------------
    std::printf("\nwhat one evaluation costs (median of five runs of a million)\n");
    struct Timed { const char* name; const Airframe* a; };
    const Timed timed[] = {{"the Cessna, 4 panels", &cessna}, {"the F/A-18F, 6 panels", &hornet_air},
                           {"the P-38, 6 panels", &p38}};
    volatile float sink = 0.0f;
    for (const Timed& t : timed) {
        std::vector<double> runs;
        for (int k = 0; k < 5; ++k) {
            const auto t0 = std::chrono::steady_clock::now();
            const int n = 1000000;
            float acc = 0.0f;
            for (int i = 0; i < n; ++i) {
                const float stick[kChannels] = {0.2f * float(i % 7) - 0.6f, 0.3f, 0.1f, 0.0f};
                acc += evaluate(*t.a, Vec{2.0f, -4.0f, -120.0f - float(i % 11)}, Vec{0.1f, 0.05f, -0.2f}, stick, 0.04f)
                           .force.y;
            }
            const auto t1 = std::chrono::steady_clock::now();
            sink = acc;
            runs.push_back(std::chrono::duration<double, std::nano>(t1 - t0).count() / n);
        }
        std::sort(runs.begin(), runs.end());
        std::printf("  %-24s %.1f ns\n", t.name, runs[2]);
    }
    return 0;
}
