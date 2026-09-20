// ## THE P-51D's SWING AND ITS TAKE-OFF, ON LANE/WARBIRDS2'S OWN NUMBERS (asked for by warbirds2, 2026-09-19).
// ##
// ## Two questions, both theirs:
// ## 1. does the "28 per cent of full rudder" from the generic run hold with their fin, rudder, arm and propeller?
// ## 2. would a constant-speed propeller's thrust shorten their take-off, which is 692 m against a book 442?
// ##
// ## Their numbers, quoted from their message: fin and rudder 2.05 m^2 with the rudder 45 per cent of it, its quarter
// ## chord 8.95 m aft of the spinner and 2.84 m over the ground, rudder travel 30 degrees each way, tau 0.65, propeller
// ## 3.404 m at station 0.51, 1,490 bhp. What I do not have from them is the CENTRE OF GRAVITY's station and height,
// ## which set the fin's arm, so both are swept and the answer is given as a band.
#include "propeller.hpp"

#include <cstdio>
#include <initializer_list>

using namespace flightcore::prop;

namespace {

constexpr float kDeg = 3.14159265f / 180.0f;

// Their fin, as they describe it.
constexpr float kFinArea = 2.05f;       // fin and rudder together
constexpr float kFinQuarter = 8.95f;    // station, metres aft of the spinner
constexpr float kFinHeight = 2.84f;     // over the ground
constexpr float kRudderTravel = 30.0f * kDeg;
constexpr float kRudderTau = 0.65f;
constexpr float kPropStation = 0.51f;
constexpr float kPower = 1111000.0f;    // 1,490 bhp
constexpr float kMass = 4175.0f;        // 9,200 lb loaded: ESTIMATE, theirs if it differs

/// The fin's lift slope from its own height and area, with the fuselage as an end plate (the aspect ratio doubles), as
/// `lifting_surfaces.hpp` has it. A P-51's fin stands about 1.78 m over the thrust line (p51_airframe's FIN polygon).
float fin_slope(float height_over_thrust_line) {
    const float aspect = 2.0f * height_over_thrust_line * height_over_thrust_line / kFinArea;
    return 6.2831853f * aspect / (aspect + 2.0f) * 0.92f;
}

}  // namespace

int main() {
    Propeller merlin;
    merlin.radius = 3.404f * 0.5f;
    merlin.power = kPower;
    merlin.omega = 1437.0f * 2.0f * 3.14159265f / 60.0f;  // 3,000 engine rpm through 0.479: ESTIMATE
    merlin.handedness = 1.0f;

    const float slope = fin_slope(1.78f);
    std::printf("THE P-51D ON WARBIRDS2'S NUMBERS\n");
    std::printf("  fin and rudder %.2f m^2, lift slope %.2f per radian (end-plated by the fuselage), rudder %.0f deg at tau %.2f\n",
                kFinArea, slope, kRudderTravel / kDeg, kRudderTau);

    // THE ARM IS THE ONE THING I DO NOT HAVE: the centre of gravity's station and height. A taildragger's is a little
    // aft of its mains (2.747 m in p51_airframe.gd) and near the thrust line, so the two are swept around that.
    std::printf("\n  what full rudder holds, and what the propeller asks of it, at a standstill and at 20 m/s:\n");
    std::printf("    cg station   fin arm    rudder at rest   swing at rest   share      at 20 m/s\n");
    for (float cg : {2.85f, 3.00f, 3.15f, 3.30f}) {
        const float arm = kFinQuarter - cg;
        const float fin_up = 0.84f;  // the fin's centroid over the thrust line, which the centre of gravity is near
        float line[2] = {0.0f, 0.0f};
        float swing[2] = {0.0f, 0.0f};
        int i = 0;
        for (float along : {0.0f, 20.0f}) {
            const Pull p = pull(merlin, 1.0f, along, 12.0f * kDeg, arm, fin_up);
            const float yaw = p.yaw + swirl_yaw(p, along, kFinArea, slope, arm);
            const float over = along + p.slipstream;
            const float q = 0.5f * kRho * over * over;
            const float rudder = q * kFinArea * slope * kRudderTau * kRudderTravel * arm;
            line[i] = rudder;
            swing[i] = yaw;
            ++i;
        }
        std::printf("    %8.2f m  %6.2f m   %10.0f N m   %11.0f N m   %4.0f%%   %8.0f%%\n", cg, arm, line[0], swing[0],
                    100.0f * std::fabs(swing[0]) / line[0], 100.0f * std::fabs(swing[1]) / line[1]);
    }

    // AND THE TORQUE, which is the other half of a taildragger's start: it presses the left wheel and can roll it.
    const Pull start = pull(merlin, 1.0f, 0.0f, 12.0f * kDeg, 6.0f, 0.84f);
    std::printf("\n  torque at full power: %.0f N m, which on a 3.4 m track is %.1f kN of extra load on the left wheel\n",
                std::fabs(start.roll), std::fabs(start.roll) / 3.4f / 1000.0f);
    std::printf("  (the aeroplane weighs %.1f kN, so that is %.0f per cent of its weight moved across)\n",
                kMass * 9.81f / 1000.0f, 100.0f * (std::fabs(start.roll) / 3.4f) / (kMass * 9.81f));

    // ---------------------------------------------------------------------------------------------------------------
    // THE TAKE-OFF: their straight line against a constant-speed propeller's thrust.
    // ---------------------------------------------------------------------------------------------------------------
    std::printf("\nTHRUST THROUGH THE TAKE-OFF ROLL: their line against a constant-speed propeller\n");
    std::printf("  speed    their line (16.03 kN static)   constant-speed    difference\n");
    // Their line is the Cessna's shape, T0 (throttle - v / v0), with T0 = 16.03 kN. `v0` they did not give; the fit
    // that matches a 692 m run is what matters, so both are shown against the same static thrust.
    const float their_static = 16030.0f;
    for (float v : {0.0f, 10.0f, 20.0f, 30.0f, 40.0f, 50.0f, 60.0f}) {
        const float theirs = their_static * (1.0f - v / 185.0f);  // the Cessna's own v0, as they say they copied it
        const float mine = pull(merlin, 1.0f, v, 6.0f * kDeg, 6.0f, 0.84f).thrust;
        std::printf("  %5.0f      %11.0f N                %8.0f N      %+6.0f N\n", v, theirs, mine, mine - theirs);
    }
    // What that does to the run, on the simplest honest arithmetic: the distance to the lift-off speed at the average
    // net acceleration. Rolling resistance 0.02 of weight and a drag of 0.6 v^2 (a clean fighter, ESTIMATE).
    std::printf("\n  the run to 47 m/s (about 1.1 x a 105 mph stall), on 0.02 of weight in rolling resistance and 0.6 v^2 of drag:\n");
    for (int which = 0; which < 2; ++which) {
        float v = 0.0f;
        float x = 0.0f;
        const float dt = 0.01f;
        for (int i = 0; i < 20000 && v < 47.0f; ++i) {
            const float thrust = which == 0 ? their_static * (1.0f - v / 185.0f)
                                            : pull(merlin, 1.0f, v, 6.0f * kDeg, 6.0f, 0.84f).thrust;
            const float resist = 0.02f * kMass * 9.81f + 0.6f * v * v;
            v += (thrust - resist) / kMass * dt;
            x += v * dt;
        }
        std::printf("    %-16s %6.0f m\n", which == 0 ? "their line:" : "constant-speed:", x);
    }
    std::printf("  the book's run is 442 m; theirs flies 692.\n");
    return 0;
}
