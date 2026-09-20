#include "rotor_bem.hpp"
#include <cstdio>
#include <initializer_list>
using namespace flightcore::bem;
int main() {
    Rotor r;
    for (float th : {0.0f, 0.03f, 0.06f})
        for (float c : {0.0f, -5.0f, -10.0f, -15.0f, -20.0f, -25.0f}) {
            State s = at_pitch(r, th, c, 0.0f, 400.0f);
            std::printf("theta %.2f climb %5.1f: T %7.0f vi %6.2f P %7.1f kW\n", th, c, s.thrust, s.induced, s.power / 1000);
        }
}
