// ## The prototype rotor block (rotor_bem.hpp) through the same tests rotor_audit.cpp put the game's disc through,
// ## with the Little Bird's body drags from drive_vehicle's disc path (drag_vertical 2.4, drag_forward 0.6), at 120 Hz,
// ## against the MD 530F's published figures: climb 2,070 ft/min (10.5 m/s), cruise 135 kt, Vne 152 kt, autorotation
// ## 1,500 to 2,500 ft/min. Headless and CPU only; nothing here is game code.
#include "rotor_bem.hpp"
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <initializer_list>
#include <vector>
using namespace flightcore::bem;

int main() {
    const Rotor r;
    const float m = 1406.0f, W = m * kG, dt = 1.0f / 120.0f;
    const float drag_vertical = 2.4f, drag_forward = 0.6f;
    std::printf("solidity %.4f, disc %.1f m^2, weight %.0f N, vh %.2f m/s\n", solidity(r), area(r), W,
                std::sqrt(W / (2.0f * kRho * area(r))));
    // 1. The hover lever and its power, in and out of ground effect.
    for (float h : {2.75f, 3.75f, 5.75f, 42.75f}) {
        float lo = 0.0f, hi = 1.0f;
        for (int i = 0; i < 40; ++i) { float mid = 0.5f * (lo + hi); (fly(r, mid, 0, 0, h).thrust > W ? hi : lo) = mid; }
        State s = fly(r, lo, 0, 0, h);
        std::printf("hover, hub %.2f m up: lever %.3f, pitch %.1f deg, power %.0f kW\n", h, lo, s.theta * 57.2958f, s.power / 1000);
    }
    // 2. Held full collective and 0.8 from a hover: where the climb settles.
    for (float lever : {1.0f, 0.8f, 0.65f}) {
        float vz = 0;
        for (int i = 0; i < 120 * 40; ++i) {
            State s = fly(r, lever, vz, 0, 100);
            vz += (s.thrust - W - vz * std::fabs(vz) * drag_vertical) / m * dt;
        }
        State s = fly(r, lever, vz, 0, 100);
        std::printf("lever %.2f held: climb %.1f m/s (%.0f ft/min), power %.0f kW%s\n", lever, vz, vz * 196.85f,
                    s.power / 1000, s.power_limited ? ", power limited" : "");
    }
    // 3. Level flight: nose down theta, a lever loop holding height. Where does it settle, and what power?
    for (float deg : {4.0f, 6.0f, 8.0f, 10.0f, 12.0f}) {
        float th = deg * kPi / 180.0f, vx = 0, vz = 0, lever = 0.5f;
        for (int i = 0; i < 120 * 150; ++i) {
            float along = vx * std::cos(th) - vz * std::sin(th);
            float mast = vx * std::sin(th) + vz * std::cos(th);
            State s = fly(r, lever, mast, along, 100);
            float fx = s.thrust * std::sin(th) - drag_forward * along * std::fabs(along) * std::cos(th);
            float fz = s.thrust * std::cos(th) - W - drag_vertical * mast * std::fabs(mast) * std::cos(th);
            vx += fx / m * dt; vz += fz / m * dt;
            lever = std::clamp(lever - vz * 0.02f * dt * 30.0f, 0.0f, 1.0f);
        }
        float along = vx * std::cos(th) - vz * std::sin(th), mast = vx * std::sin(th) + vz * std::cos(th);
        State s = fly(r, lever, mast, along, 100);
        std::printf("%4.0f deg nose down: %5.1f m/s (%3.0f kt), vz %+.2f, lever %.2f, power %.0f kW%s\n", deg, vx,
                    vx / 0.514444f, vz, lever, s.power / 1000, s.power_limited ? " (limit)" : "");
    }
    // 4. The bottom of the lever, continuous.
    for (float lever : {0.0f, 0.05f, 0.079f, 0.080f, 0.10f}) {
        std::printf("lever %.3f, hover, 40 m: T %.0f N\n", lever, fly(r, lever, 0, 0, 43).thrust);
    }
    // 5. Autorotation: engine at idle, lever held at the hover's, forward speed held; the steady sink.
    for (float fwd : {0.0f, 10.0f, 20.0f, 30.0f, 40.0f, 55.0f}) {
        float vz = 0;
        for (int i = 0; i < 120 * 60; ++i) {
            State s = fly(r, 0.50f, vz, fwd, 500, 0.0f);
            vz += (s.thrust - W - vz * std::fabs(vz) * drag_vertical) / m * dt;
        }
        // The fuselage's drag at this speed has to be paid for too: in a real autorotation the disc tilts into the path
        // and the descent pays it. Done here as the power: parasite / weight is the extra sink.
        const float extra = 0.5f * kRho * (drag_forward / (0.5f * kRho)) * fwd * fwd * fwd / W;
        std::printf("autorotation at %2.0f m/s forward: disc sink %.1f m/s, with the fuselage's drag %.1f m/s (%.0f ft/min)\n",
                    fwd, -vz, -vz + extra, (-vz + extra) * 196.85f);
    }
    // 6. Cost: one fly() call over a spread of states, median of five.
    std::vector<double> runs;
    volatile float sink = 0;
    for (int k = 0; k < 5; ++k) {
        auto t0 = std::chrono::steady_clock::now();
        const int n = 2000000;
        float acc = 0;
        for (int i = 0; i < n; ++i) {
            acc += fly(r, 0.1f + 0.9f * float(i % 97) / 97.0f, -12.0f + float(i % 29), float(i % 83), 3.0f + float(i % 50)).thrust;
        }
        auto t1 = std::chrono::steady_clock::now();
        sink = acc;
        runs.push_back(std::chrono::duration<double, std::nano>(t1 - t0).count() / n);
    }
    std::sort(runs.begin(), runs.end());
    std::printf("bem::fly, a spread of states (many power-limited or descending): median %.1f ns a call (min %.1f, max %.1f)\n",
                runs[2], runs[0], runs[4]);
    runs.clear();
    for (int k = 0; k < 5; ++k) {
        auto t0 = std::chrono::steady_clock::now();
        const int n = 2000000;
        float acc = 0;
        for (int i = 0; i < n; ++i) {
            acc += fly(r, 0.38f + 0.1f * float(i % 13) / 13.0f, 2.5f + 3.0f * float(i % 7) / 7.0f, 30.0f + float(i % 41), 80.0f).thrust;
        }
        auto t1 = std::chrono::steady_clock::now();
        sink = acc;
        runs.push_back(std::chrono::duration<double, std::nano>(t1 - t0).count() / n);
    }
    std::sort(runs.begin(), runs.end());
    std::printf("bem::fly, cruise (the common case): median %.1f ns a call (min %.1f, max %.1f)\n", runs[2], runs[0], runs[4]);
    // Each expensive situation on its own, jittered a little so nothing is hoisted out of the loop.
    struct Case { const char* name; float lever, climb, edge, engine; };
    const Case cases[] = {
        {"a climb at the power limit (full lever, 8 m/s up, 20 m/s along)", 1.0f, 8.0f, 20.0f, 1.0f},
        {"a slow vertical descent in the vortex ring (8 m/s down, 3 along)", 0.42f, -8.0f, 3.0f, 1.0f},
        {"an autorotation at 40 m/s (engine at idle, 11 m/s down)", 0.5f, -11.0f, 40.0f, 0.0f},
        {"a vertical autorotation (engine at idle, 19 m/s down)", 0.5f, -19.0f, 0.5f, 0.0f},
    };
    for (const Case& c : cases) {
        runs.clear();
        for (int k = 0; k < 5; ++k) {
            auto t0 = std::chrono::steady_clock::now();
            const int n = 1000000;
            float acc = 0;
            for (int i = 0; i < n; ++i) {
                const float jitter = 0.01f * float(i % 17);
                acc += fly(r, c.lever, c.climb + jitter, c.edge + jitter, 60.0f, c.engine).thrust;
            }
            auto t1 = std::chrono::steady_clock::now();
            sink = acc;
            runs.push_back(std::chrono::duration<double, std::nano>(t1 - t0).count() / n);
        }
        std::sort(runs.begin(), runs.end());
        std::printf("bem::fly, %s: median %.1f ns\n", c.name, runs[2]);
    }
    return 0;
}
