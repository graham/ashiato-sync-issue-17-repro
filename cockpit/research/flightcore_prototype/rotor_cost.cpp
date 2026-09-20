// The price of one rotor::fly call, the Little Bird's disc, across a spread of states (median of 5 runs).
#include "../../../ashiato-gd/src/cockpit/rotor_disc.hpp"
#include <chrono>
#include <cstdio>
#include <algorithm>
#include <vector>
using namespace ashiato_gd::cockpit::rotor;
int main() {
    Disc d = littlebird();
    std::vector<double> runs;
    volatile float sink = 0;
    for (int r = 0; r < 5; ++r) {
        auto t0 = std::chrono::steady_clock::now();
        const int n = 2000000;
        float acc = 0;
        for (int i = 0; i < n; ++i) {
            float lever = 0.1f + 0.9f * float(i % 97) / 97.0f;
            float along = float(i % 83);
            float climb = -12.0f + float(i % 29);
            acc += fly(d, lever, along, climb, float(i % 50)).thrust;
        }
        auto t1 = std::chrono::steady_clock::now();
        sink = acc;
        runs.push_back(std::chrono::duration<double, std::nano>(t1 - t0).count() / n);
    }
    std::sort(runs.begin(), runs.end());
    std::printf("rotor::fly median %.1f ns a call (min %.1f, max %.1f)\n", runs[2], runs[0], runs[4]);
    return 0;
}
