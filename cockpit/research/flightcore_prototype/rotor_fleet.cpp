// ## ONE ROTOR BLOCK, FOUR HELICOPTERS, NOTHING BUT THEIR OWN NUMBERS.
// ##
// ## The architecture the review proposes says a kind's flight model is its own numbers through shared blocks. This is
// ## that claim, tested before any of it is built: `rotor_bem.hpp` exactly as the Little Bird's prototype left it, with
// ## each kind's radius, blade count and chord, tip speed, engine power, mass and flat-plate area, and nothing else per
// ## kind. What comes out is compared with published figures.
// ##
// ## WHERE THE NUMBERS COME FROM. The rotor sizes, blade counts, chords and masses are the ones the game's own airframes
// ## and shapes carry (`cockpit/craft/<kind>/sources.md`, `*_airframe.gd`, `*_shape()`), which cite their sources. The
// ## figures compared against are the ones the repo already quotes, and where it quotes none they are marked ESTIMATE
// ## here and would have to be put in the kind's `sources.md`, with a source, before any suite held them. Nothing here
// ## is tuned: every knob is a measurement or a marked estimate, and no number was moved to make an answer come out.
#include "rotor_bem.hpp"
#include <cstdio>
#include <initializer_list>
using namespace flightcore::bem;

namespace {

struct Kind {
    const char* name;
    Rotor rotor;
    int discs;          // two on a tandem, which share the weight
    float mass;         // kg, the game's
    float flat_plate;   // m^2 of equivalent flat plate, the fuselage's drag: ESTIMATE on every one of these
    float book_climb;   // m/s, or 0 where none is quoted
    float book_cruise;  // m/s
    float book_max;     // m/s
    const char* notes;
};

/// The power a disc may take, over `engine`: a tandem's transmission is shared, so each disc gets half.
State fly_one(const Kind& k, float lever, float climb, float edgewise, float height, float engine = 1.0f) {
    return fly(k.rotor, lever, climb, edgewise, height, engine);
}

/// THE LEVER THAT HOVERS IT, and the power that takes, out of ground effect.
void hover(const Kind& k) {
    const float share = k.mass * kG / float(k.discs);
    float lo = 0.0f;
    float hi = 1.0f;
    for (int i = 0; i < 40; ++i) {
        const float mid = 0.5f * (lo + hi);
        (fly_one(k, mid, 0.0f, 0.0f, 60.0f).thrust > share ? hi : lo) = mid;
    }
    const State s = fly_one(k, lo, 0.0f, 0.0f, 60.0f);
    std::printf("  hover out of ground effect: lever %.2f, blade pitch %.1f deg, %.0f kW a disc of %.0f available\n",
                lo, s.theta * 57.2958f, s.power / 1000.0f, k.rotor.max_power / 1000.0f);
}

/// FULL COLLECTIVE, HELD: where the climb settles once the engine's power binds.
void climb(const Kind& k) {
    const float weight = k.mass * kG;
    float vz = 0.0f;
    for (int i = 0; i < 120 * 60; ++i) {
        const State s = fly_one(k, 1.0f, vz, 0.0f, 200.0f);
        const float drag = 0.5f * kRho * k.flat_plate * vz * std::fabs(vz);  // the fuselage, climbing through the air
        vz += (float(k.discs) * s.thrust - weight - drag) / k.mass / 120.0f;
    }
    const State s = fly_one(k, 1.0f, vz, 0.0f, 200.0f);
    std::printf("  climb at full collective: %.1f m/s (%.0f ft/min)%s, %.0f kW a disc%s\n", vz, vz * 196.85f,
                k.book_climb > 0.0f ? "" : "", s.power / 1000.0f, s.power_limited ? ", power limited" : "");
    if (k.book_climb > 0.0f) {
        std::printf("      the book says %.1f m/s (%.0f ft/min): %.2f of it\n", k.book_climb, k.book_climb * 196.85f,
                    vz / k.book_climb);
    }
}

/// LEVEL FLIGHT, nose down by a swept angle, the lever holding height: the fastest it will go.
void fastest(const Kind& k) {
    const float weight = k.mass * kG;
    float best = 0.0f;
    float at_angle = 0.0f;
    for (float deg = 2.0f; deg <= 22.0f; deg += 1.0f) {
        const float th = deg * kPi / 180.0f;
        float vx = 0.0f;
        float vz = 0.0f;
        float lever = 0.5f;
        for (int i = 0; i < 120 * 120; ++i) {
            const float along = vx * std::cos(th) - vz * std::sin(th);
            const float mast = vx * std::sin(th) + vz * std::cos(th);
            const State s = fly_one(k, lever, mast, along, 200.0f);
            const float drag = 0.5f * kRho * k.flat_plate * along * std::fabs(along);
            const float thrust = float(k.discs) * s.thrust;
            vx += (thrust * std::sin(th) - drag * std::cos(th)) / k.mass / 120.0f;
            vz += (thrust * std::cos(th) - weight + drag * std::sin(th)) / k.mass / 120.0f;
            lever += -vz * 0.6f / 120.0f;
            lever = lever < 0.0f ? 0.0f : (lever > 1.0f ? 1.0f : lever);
        }
        if (std::fabs(vz) < 1.0f && vx > best) {
            best = vx;
            at_angle = deg;
        }
    }
    std::printf("  fastest it holds height: %.1f m/s (%.0f kt) at %.0f degrees nose down\n", best, best / 0.514444f,
                at_angle);
    if (k.book_cruise > 0.0f) {
        std::printf("      the book's cruise %.0f kt and maximum %.0f kt: %.2f of the cruise\n",
                    k.book_cruise / 0.514444f, k.book_max / 0.514444f, best / k.book_cruise);
    }
}

/// ENGINE AT IDLE: the steady sink at a spread of forward speeds, and the best of them.
void autorotate(const Kind& k) {
    const float weight = k.mass * kG;
    float least = 1e9f;
    float at_speed = 0.0f;
    for (float fwd = 0.0f; fwd <= 60.0f; fwd += 5.0f) {
        float vz = 0.0f;
        for (int i = 0; i < 120 * 60; ++i) {
            const State s = fly_one(k, 0.5f, vz, fwd, 800.0f, 0.0f);
            vz += (float(k.discs) * s.thrust - weight) / k.mass / 120.0f;
        }
        // The fuselage's drag is paid for out of height too: the disc tilts into the path to overcome it.
        const float sink = -vz + 0.5f * kRho * k.flat_plate * fwd * fwd * fwd / weight;
        if (sink < least) {
            least = sink;
            at_speed = fwd;
        }
    }
    std::printf("  autorotation, engine at idle: least sink %.1f m/s (%.0f ft/min) at %.0f m/s (%.0f kt) forward\n",
                least, least * 196.85f, at_speed, at_speed / 0.514444f);
}

}  // namespace

int main() {
    Rotor little_bird;  // as rotor_bem_audit.cpp has it: 6 blades of 0.183 m on a 4.176 m radius, 425 shp
    Rotor black_hawk;
    black_hawk.radius = 16.36f * 0.5f;   // FM 3-04, through uh60_airframe.gd
    black_hawk.blades = 4;
    black_hawk.chord = 0.53f;            // uh60_airframe.gd's BLADE_CHORD
    black_hawk.tip_speed = 221.0f;       // ESTIMATE
    black_hawk.max_power = 2535000.0f;   // ESTIMATE: a twin's transmission limit, about 3,400 shp
    black_hawk.hub_height = 3.5f;   // ESTIMATE, the hub over the wheels
    Rotor apache = black_hawk;
    apache.radius = 14.63f * 0.5f;       // Jane's, through apache_airframe.gd
    apache.max_power = 2100000.0f;       // ESTIMATE, about 2,800 shp
    Rotor chinook;
    chinook.radius = 18.29f * 0.5f;      // Boeing's CH-47F sheet, through chinook_airframe.gd
    chinook.blades = 3;
    chinook.chord = 0.81f;               // chinook_airframe.gd's BLADE_CHORD
    chinook.tip_speed = 225.0f;          // ESTIMATE
    chinook.max_power = 2800000.0f;      // ESTIMATE a disc's share of a twin's transmission limit
    chinook.hub_height = 4.5f;      // ESTIMATE
    chinook.kappa = 1.30f;               // two discs overlapping cost more induced power than one: ESTIMATE

    const Kind fleet[] = {
        {"MH-6M Little Bird", little_bird, 1, 1406.0f, 0.9f, 10.5f, 69.5f, 78.2f,
         "MD 530F sheet: 2,070 ft/min, 135 kt cruise, 152 kt never-exceed"},
        {"UH-60M Black Hawk", black_hawk, 1, 9979.0f, 2.2f, 0.0f, 0.0f, 0.0f,
         "no performance figure in the repo's sources; flat plate an ESTIMATE"},
        {"AH-64D Apache", apache, 1, 7270.0f, 1.6f, 9.0f, 73.6f, 81.3f,
         "[W] through apache_flight.gd: 1,775 ft/min, 143 kt cruise, 158 kt maximum"},
        {"CH-47F Chinook", chinook, 2, 15000.0f, 5.0f, 0.0f, 0.0f, 0.0f,
         "no performance figure in the repo's sources; flat plate and overlap ESTIMATE"},
    };
    for (const Kind& k : fleet) {
        std::printf("%s: %d disc(s) of %.2f m radius, %d blades of %.2f m, %.0f kg, tip %.0f m/s\n", k.name, k.discs,
                    k.rotor.radius, k.rotor.blades, k.rotor.chord, k.mass, k.rotor.tip_speed);
        std::printf("  disc loading %.1f kg/m^2; %s\n", k.mass / (float(k.discs) * area(k.rotor)), k.notes);
        hover(k);
        climb(k);
        fastest(k);
        autorotate(k);
    }
    return 0;
}
