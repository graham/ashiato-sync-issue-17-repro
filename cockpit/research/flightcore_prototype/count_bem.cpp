// Counts the work one fly() does in each expensive situation: passes of at_pitch and the ring's regula falsi steps.
#define FLIGHTCORE_COUNT
#include "rotor_bem.hpp"
#include <cstdio>
using namespace flightcore::bem;
int main() {
    Rotor r;
    struct Case { const char* name; float lever, climb, edge, engine; };
    const Case cases[] = {{"climb at the limit", 1.0f, 8.0f, 20.0f, 1.0f}, {"vortex ring", 0.42f, -8.0f, 3.0f, 1.0f},
                          {"autorotation at 40", 0.5f, -11.0f, 40.0f, 0.0f}, {"vertical autorotation", 0.5f, -19.0f, 0.5f, 0.0f},
                          {"cruise", 0.43f, 3.0f, 50.0f, 1.0f}};
    for (const Case& c : cases) {
        g_pitch_calls = g_ring_steps = 0;
        State s = fly(r, c.lever, c.climb, c.edge, 60.0f, c.engine);
        std::printf("%-22s at_pitch %d, ring steps %d; T %.0f N, P %.1f kW\n", c.name, g_pitch_calls, g_ring_steps,
                    s.thrust, s.power / 1000);
    }
}
