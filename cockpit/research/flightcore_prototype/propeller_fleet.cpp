// ## WHAT A PROPELLER DOES TO A TAKE-OFF: the Cessna, the P-51 and the P-38's counter-rotating pair.
// ##
// ## Every number is the kind's own, from its airframe or its sources; masses and powers are marked ESTIMATE where the
// ## repo has none yet. What is being asked is not "how fast does it go" but "how hard does it pull off the heading",
// ## because that is the part the game has never had and the part a taildragger's take-off IS.
// ##
// ## The yaw and roll printed are what the aeroplane must be held straight against, so they are also what a take-off
// ## suite would hold: a rudder that can hold it, and a swing that is there at all.
#include "propeller.hpp"

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <initializer_list>
#include <vector>

using namespace flightcore::prop;

namespace {

constexpr float kDeg = 3.14159265f / 180.0f;

struct Aeroplane {
    const char* name;
    Propeller engine;
    int engines;
    float engine_out;   // each engine's distance from the centreline, metres (0 on a single)
    float mass;
    float fin_area;     // m^2, both fins together
    float fin_slope;    // per radian
    float fin_arm;      // metres from the centre of gravity to the fin
    float fin_height;   // metres above the propeller's axis
    float rudder_travel;
    float rudder_tau;
    float wing_span;
    const char* notes;
};

/// The yaw a full rudder can make at a speed, to hold the swing against: the fin as a panel, as `panel_wing.hpp` has
/// it, with the slipstream's own speed over it where there is one.
float rudder_yaw(const Aeroplane& a, float along, float slipstream) {
    const float over = std::fmax(along + slipstream, 0.0f);
    const float q = 0.5f * kRho * over * over;
    return q * a.fin_area * a.fin_slope * a.rudder_tau * a.rudder_travel * a.fin_arm;
}

void take_off_roll(const Aeroplane& a, float alpha) {
    std::printf("\n%s (%s)\n", a.name, a.notes);
    std::printf("  %d propeller(s) of %.2f m radius, %.0f kW each at %.0f rad/s, %.0f kg\n", a.engines,
                a.engine.radius, a.engine.power / 1000.0f, a.engine.omega, a.mass);
    std::printf("   speed   thrust    torque roll   P-factor yaw   swirl yaw   net yaw   full rudder   rudder needed\n");
    for (float along : {0.0f, 10.0f, 20.0f, 30.0f, 45.0f, 60.0f}) {
        float thrust = 0.0f;
        float roll = 0.0f;
        float yaw_p = 0.0f;
        float yaw_s = 0.0f;
        float slipstream = 0.0f;
        for (int e = 0; e < a.engines; ++e) {
            Propeller one = a.engine;
            // A COUNTER-ROTATING PAIR: the second turns the other way, as the P-38's does.
            one.handedness = a.engines == 2 && e == 1 ? -a.engine.handedness : a.engine.handedness;
            const Pull p = pull(one, 1.0f, along, alpha, a.fin_arm, a.fin_height);
            thrust += p.thrust;
            roll += p.roll;
            yaw_p += p.yaw;
            yaw_s += swirl_yaw(p, along, a.fin_area / float(a.engines), a.fin_slope, a.fin_arm);
            // EVERY FIN HERE SITS BEHIND A DISC: the Cessna's and the Mustang's behind their one, and the P-38's two
            // behind their booms' engines. So all three have a rudder at a standstill that airspeed alone would not
            // give them, which is most of why a propeller aeroplane can be steered before it is rolling.
            slipstream = std::fmax(slipstream, p.slipstream);
        }
        const float net = yaw_p + yaw_s;
        const float rudder = rudder_yaw(a, along, slipstream);
        std::printf("  %5.0f  %7.0f N  %8.0f N m  %10.0f N m  %8.0f N m  %8.0f N m  %9.0f N m   %5.0f%%\n", along,
                    thrust, roll, yaw_p, yaw_s, net, rudder, 100.0f * std::fabs(net) / std::fmax(rudder, 1.0f));
    }
    // What the torque alone would do if nothing held it: the roll acceleration on a wing-heavy inertia estimate.
    const float roll_inertia = 0.12f * a.mass * a.wing_span * a.wing_span / 12.0f * 4.0f;  // ESTIMATE, the plan's rule
    const Pull stat = pull(a.engine, 1.0f, 0.0f, alpha, a.fin_arm, a.fin_height);
    std::printf("  torque at a standstill: %.0f N m against about %.0f kg m^2 of roll inertia, %.2f rad/s^2%s\n",
                std::fabs(stat.roll), roll_inertia, std::fabs(stat.roll) / std::fmax(roll_inertia, 1.0f),
                a.engines == 2 ? " an engine, and the pair cancels it" : "");
}

}  // namespace

int main() {
    // THE CESSNA 172S: a fixed-pitch propeller, which is NOT what this block's thrust is for (its thrust stays the
    // line through its two book points), but whose swing is worth having beside a warbird's to show the difference.
    Propeller cessna_prop;
    cessna_prop.radius = 0.965f;       // skyhawk_airframe.gd's PROP_RADIUS
    cessna_prop.power = 134000.0f;     // 180 hp, craft/cessna/sources.md
    cessna_prop.omega = 2400.0f * 2.0f * 3.14159265f / 60.0f;
    cessna_prop.handedness = 1.0f;
    const Aeroplane cessna{"THE CESSNA 172S", cessna_prop, 1, 0.0f, 1000.0f, 1.2f, 3.38f, 4.63f, 0.80f,
                           0.309523f, 0.6f, 11.0f, "180 hp on a 1.93 m propeller: the swing a trainer has"};

    // THE P-51D: the numbers in craft/p51/sources.md ([WP] and AN 01-60JE-1).
    Propeller mustang_prop;
    mustang_prop.radius = 3.404f * 0.5f;  // 11 ft 2 in
    mustang_prop.power = 1111000.0f;      // 1,490 hp at take-off, V-1650-7
    mustang_prop.omega = 1437.0f * 2.0f * 3.14159265f / 60.0f;  // 3,000 engine rpm through 0.479: ESTIMATE
    mustang_prop.handedness = 1.0f;       // clockwise from the cockpit, as a Merlin's is
    const Aeroplane mustang{"THE P-51D MUSTANG", mustang_prop, 1, 0.0f, 4175.0f, 1.9f, 3.2f, 5.2f, 1.10f,
                            30.0f * kDeg, 0.6f, 11.286f,
                            "1,490 hp on a 3.40 m propeller; fin area, arm and travel ESTIMATE until it has a kind"};

    // THE P-38L: two Allisons, counter-rotating, from p38_airframe.gd's printed numbers.
    Propeller lightning_prop;
    lightning_prop.radius = 3.505f * 0.5f;  // PRINTED_PROP, 11 ft 6 in
    lightning_prop.power = 1193000.0f;      // 1,600 hp each: ESTIMATE until craft/p38/sources.md exists
    lightning_prop.omega = 1500.0f * 2.0f * 3.14159265f / 60.0f;
    lightning_prop.handedness = 1.0f;
    const Aeroplane lightning{"THE P-38L LIGHTNING", lightning_prop, 2, 2.438f, 7940.0f, 5.03f, 2.72f, 5.87f, 0.60f,
                              25.0f * kDeg, 0.6f, 15.85f,
                              "two 1,600 hp engines turning opposite ways, 2.438 m out (PRINTED_BOOM_OUT)"};

    std::printf("THE TAKE-OFF ROLL, full power, the tail still down (12 degrees of angle at the disc)\n");
    take_off_roll(cessna, 12.0f * kDeg);
    take_off_roll(mustang, 12.0f * kDeg);
    take_off_roll(lightning, 12.0f * kDeg);

    // AND ONE ENGINE OUT on the twin: the asymmetric thrust a counter-rotating pair still leaves.
    std::printf("\nTHE P-38 WITH ONE ENGINE OUT, at 60 m/s\n");
    {
        const Pull live = pull(lightning_prop, 1.0f, 60.0f, 2.0f * kDeg, lightning.fin_arm, lightning.fin_height);
        const float asymmetric = live.thrust * lightning.engine_out;
        const float rudder = rudder_yaw(lightning, 60.0f, 0.0f);
        std::printf("  one engine pulling %.0f N at %.2f m out: %.0f N m of yaw, against %.0f N m of full rudder (%.0f%%)\n",
                    live.thrust, lightning.engine_out, asymmetric, rudder, 100.0f * asymmetric / rudder);
    }

    // WHAT IT COSTS.
    std::printf("\nwhat one propeller costs a tick (median of five runs of a million)\n");
    std::vector<double> runs;
    volatile float sink = 0.0f;
    for (int k = 0; k < 5; ++k) {
        const auto t0 = std::chrono::steady_clock::now();
        const int n = 1000000;
        float acc = 0.0f;
        for (int i = 0; i < n; ++i) {
            acc += pull(mustang_prop, 0.2f + 0.8f * float(i % 11) / 11.0f, float(i % 90), 0.05f, 5.2f, 1.1f).thrust;
        }
        const auto t1 = std::chrono::steady_clock::now();
        sink = acc;
        runs.push_back(std::chrono::duration<double, std::nano>(t1 - t0).count() / n);
    }
    std::sort(runs.begin(), runs.end());
    std::printf("  a constant-speed propeller with its three moments: %.1f ns\n", runs[2]);
    return 0;
}
