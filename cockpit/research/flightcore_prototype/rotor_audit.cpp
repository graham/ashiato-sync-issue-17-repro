// A headless audit of rotor_disc.hpp as the game uses it: the disc's thrust along the mast and the body drags
// drive_vehicle applies on the disc path (drag_vertical 2.4, drag_forward 0.6 for the Little Bird), integrated in
// one or two dimensions at 120 Hz. No Box3D; attitude is held, as a pilot holding a pitch would.
#include "../../../ashiato-gd/src/cockpit/rotor_disc.hpp"
#include <cstdio>
#include <initializer_list>
using namespace ashiato_gd::cockpit::rotor;

int main() {
    Disc d = littlebird();
    const float m = d.mass, W = m * kGravity, dt = 1.0f / 120.0f;
    const float drag_vertical = 2.4f, drag_forward = 0.6f;
    std::printf("weight %.0f N, vh(W) %.2f m/s, disc %.1f m^2\n", W, vh_at(d, W), disc_area(d));
    // 1. Hover collective OGE and IGE: bisection on the lever for T = W at 0 speed.
    for (float h : {0.0f, 1.0f, 3.0f, 40.0f}) {
        float lo = 0.08f, hi = 1.0f;
        for (int i = 0; i < 40; ++i) { float mid = 0.5f*(lo+hi); (fly(d, mid, 0, 0, h).thrust > W ? hi : lo) = mid; }
        Forces f = fly(d, lo, 0, 0, h);
        std::printf("hover lever at skids %.0f m: %.3f  power %.0f kW  phase %s\n", h, lo, f.power/1000, phase_name(f.phase));
    }
    // 2. Vertical climb at full collective from a hover at 40 m, level attitude.
    for (float lever : {1.0f, 0.8f, 0.6f}) {
        float vz = 0, y = 40;
        for (int i = 0; i < 120 * 30; ++i) {
            Forces f = fly(d, lever, 0, vz, y);
            float drag = -vz * std::fabs(vz) * drag_vertical;
            vz += (f.thrust - W + drag) / m * dt; y += vz * dt;
        }
        Forces f = fly(d, lever, 0, vz, y);
        std::printf("lever %.1f vertical climb after 30 s: %.1f m/s  thrust %.0f N  power %.0f kW (max %.0f)  honest power T(Vc+vi) %.0f kW\n",
                    lever, vz, f.thrust, f.power/1000, d.max_power/1000, f.thrust*(vz+f.induced)/1000 + (f.power - f.thrust*f.induced)/1000);
    }
    // 3. Level forward flight: disc tilted forward by theta, lever set to hold height, what speed settles?
    for (float deg : {5.0f, 10.0f, 15.0f, 20.0f}) {
        float th = deg * kPi / 180.0f, vx = 0, vz = 0;
        float lever = 0.5f;
        for (int i = 0; i < 120 * 90; ++i) {
            float along = vx * std::cos(th) - vz * std::sin(th);   // airspeed along the nose (nose down th)
            float climb = vx * std::sin(th) + vz * std::cos(th);   // along the mast
            Forces f = fly(d, lever, along, climb, 100.0f);
            float fx = f.thrust * std::sin(th) - drag_forward * along * std::fabs(along) * std::cos(th);
            float fz = f.thrust * std::cos(th) - W - drag_vertical * climb * std::fabs(climb) * std::cos(th);
            vx += fx / m * dt; vz += fz / m * dt;
            lever += (-vz * 0.02f) * dt * 10;  if (lever < 0.1f) lever = 0.1f; if (lever > 1) lever = 1;
        }
        float along = vx * std::cos(th) - vz * std::sin(th), climb = vx * std::sin(th) + vz * std::cos(th);
        Forces f = fly(d, lever, along, climb, 100.0f);
        std::printf("nose %.0f deg down, level: %.1f m/s (%.0f kt) vz %.2f lever %.2f power %.0f kW\n", deg, vx, vx/0.514444f, vz, lever, f.power/1000);
    }
    // 4. The lever's discontinuity at 0.08, and autorotation vs forward speed.
    for (float lever : {0.079f, 0.080f, 0.10f}) std::printf("lever %.3f hover at 40 m: T %.0f N\n", lever, fly(d, lever, 0, 0, 40).thrust);
    for (float fwd : {0.0f, 15.0f, 30.0f}) {
        float vz = 0;
        for (int i = 0; i < 120 * 30; ++i) { Forces f = fly(d, 0.0f, fwd, vz, 400); vz += (f.thrust - W - vz*std::fabs(vz)*drag_vertical)/m*dt; }
        std::printf("autorotation at %.0f m/s forward: steady sink %.1f m/s\n", fwd, -vz);
    }
    return 0;
}
