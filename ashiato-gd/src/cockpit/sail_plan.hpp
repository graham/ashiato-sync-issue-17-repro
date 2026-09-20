#pragma once

/// ## WHAT A SAIL DOES WITH THE WIND, in the ship's own flat frame, and nothing else.
///
/// A sail is a WING STOOD ON ITS END. It turns the air going past it into a force
/// square to that air, which is lift, and a force along it, which is drag. Whether the
/// ship goes forwards is how those two add up against the direction of the bow. Nothing
/// here says "a ship cannot sail into the wind". A ship pointed too close to it cannot
/// set its sails at an angle that makes lift point forwards. The lift it can make then
/// is smaller than the drag, and the drag points aft. That band is the no-go zone. It
/// falls out of three numbers: how far a yard can be braced round, how far a boom can
/// be hauled in, and the angle a sail's lift peaks at. The test that proves a no-go zone
/// exists breaks when any of the three is freed.
///
/// **A flat plate with camber, not a lookup table of polars.** A polar diagram is what a
/// ship DOES. Typing one in and reading it back is the tautology `testing_godot_headless.md`
/// is about. The coefficients here are what a sail does at an angle of attack, and the
/// polar is measured by sailing (`cockpit/tests/sailing.gd`).
///
/// **Two kinds of sail, one arithmetic.** A SQUARE sail hangs from a yard that is braced
/// round the mast. It is big, it pulls hard off the wind, and a yard can only come round
/// so far before it meets the rigging. A FORE-AND-AFT sail (a jib, a spanker) sets along
/// the centreline and is sheeted in and out. It is small, and it is what lets a ship
/// point higher than its square sails alone would. Both are a line through a pivot, set
/// at an angle from the centreline and swung to one side. The line is described the
/// same way for both, and only the limits and the curve differ.
///
/// Frame: every vector here is FLAT and in the ship's own axes as (right, forward):
/// +right is starboard, +forward is the bow. The simulation projects into this frame
/// and back out. The side a sail is set on is -1 for port and +1 for starboard.

#include <algorithm>
#include <cmath>

namespace ashiato_gd {
namespace cockpit {

/// A flat vector in the ship's frame: (right, forward).
struct Flat {
    float right = 0.0f;
    float forward = 0.0f;
};

/// How one sail makes force, by angle of attack.
struct SailCurve {
    /// The most lift it makes, and the angle of attack it makes it at, in radians.
    float lift_most = 1.0f;
    float lift_peak = 0.38f;
    /// How much lift it KEEPS past the peak: 1 is the cosine fall to nothing flat on to the
    /// air, a smaller power holds more of it longer. A square sail is bellied and keeps
    /// pulling well past its peak; a jib is flatter and lets go sooner.
    float stall_hold = 1.0f;
    /// Drag edge-on and the extra drag flat on to the air (sin^2 between).
    float drag_edge = 0.10f;
    float drag_flat = 1.15f;
    /// Drag that comes WITH lift, per lift coefficient squared: a sail pulling hard sideways
    /// pays for it, which is most of why a ship close-hauled is slow.
    float drag_induced = 0.10f;
};

/// One sail, or a group of sails that are trimmed together.
struct Sail {
    float area = 0.0f;
    /// Where its force acts, in the BODY frame of the simulation (x right, y up, z aft),
    /// metres from the centre of mass. Height is what heels a ship.
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    /// The closest to the centreline its line can be set, and the furthest, in radians.
    /// A yard braced round to 38 degrees from the keel is braced "sharp up"; athwartships
    /// is 90. A boom hauled in to 12 degrees is as close as its sheet will bring it.
    float closest = 0.66f;
    float furthest = 1.5708f;
    SailCurve curve;
};

/// What a sail made this tick, for the physics and for anybody drawing it.
struct SailPull {
    Flat force;
    /// Angle of attack, 0 to pi/2. Small is luffing.
    float attack = 0.0f;
    /// Lift and drag coefficients at that angle, before area and pressure.
    float lift = 0.0f;
    float drag = 0.0f;
    /// How full the sail is, 0 to 1: lift and drag against the most they could be, which is
    /// what a drawing bellies it by. Near 0 it hangs slack; ABACK is negative, when the air
    /// comes onto the face a sail is set to be pushed from behind.
    float fill = 0.0f;
};

/// Where the wind appears to come from, as a compass angle off the bow: 0 dead ahead,
/// +pi/2 on the starboard beam, ±pi from astern. `air` is where the air GOES relative to
/// the ship.
inline float apparent_angle(const Flat& air) {
    return std::atan2(-air.right, -air.forward);
}

/// The line a sail is set along, pointing aft from its pivot, for an angle off the
/// centreline and a side.
inline Flat sail_line(float from_centreline, float side) {
    return Flat{side * std::sin(from_centreline), -std::cos(from_centreline)};
}

/// How much lift and drag a curve makes at an angle of attack.
inline void coefficients(const SailCurve& c, float attack, float& lift, float& drag) {
    const float half_pi = 1.5707964f;
    const float peak = std::clamp(c.lift_peak, 0.02f, half_pi - 0.02f);
    if (attack <= peak) {
        lift = c.lift_most * std::sin(half_pi * attack / peak);
    } else {
        const float past = std::clamp((attack - peak) / (half_pi - peak), 0.0f, 1.0f);
        // FLOORED AT ZERO BEFORE THE POWER. cos(pi/2) in floats is -4.4e-8, and a fractional
        // power of a negative number is NaN: every ship running dead before the wind put NaN
        // into Box3D ("unstable: NULL", 17,590 times in one suite) on the first draft.
        lift = c.lift_most * std::pow(std::max(std::cos(half_pi * past), 0.0f),
                                      std::max(c.stall_hold, 0.05f));
    }
    const float s = std::sin(attack);
    drag = c.drag_edge + c.drag_flat * s * s + c.drag_induced * lift * lift;
}

/// THE FORCE ON ONE SAIL. `air` is where the air goes relative to the ship and `pressure` is
/// ½ρ|air|²; `set_angle` is the line's angle off the centreline, already held inside the
/// sail's limits, and `side` which way it is swung.
///
/// A flat plate: its normal, turned to face downwind, is what the air pushes on. The angle
/// of attack is how far the air is from running along the plate. Lift is square to the air
/// on the side the plate faces, and drag is along the air.
inline SailPull pull_of(const Sail& sail, const Flat& air, float pressure, float set_angle,
                        float side) {
    SailPull out;
    const float speed = std::sqrt(air.right * air.right + air.forward * air.forward);
    if (speed < 1e-4f || sail.area <= 0.0f) {
        return out;
    }
    const Flat along{air.right / speed, air.forward / speed};
    const Flat line = sail_line(set_angle, side);
    // Either perpendicular will do, as long as it is turned to face downwind.
    Flat normal{line.forward, -line.right};
    // WHICH FACE THE SAIL IS SET TO BE PUSHED FROM, before it is turned. A square sail on
    // the port tack with its yards braced for the starboard tack has the wind on the wrong
    // face: that is ABACK, and it pushes the ship astern. The unturned normal points to
    // the side opposite `side`, which is the face a sail swung to that side is filled from.
    const float facing = normal.right * along.right + normal.forward * along.forward;
    const bool aback = facing * side > 0.0f;
    if (facing < 0.0f) {
        normal = Flat{-normal.right, -normal.forward};
    }
    const float sine = std::min(std::fabs(facing), 1.0f);
    out.attack = std::asin(sine);
    coefficients(sail.curve, out.attack, out.lift, out.drag);
    // Lift is the part of the normal square to the air.
    Flat lift_way{normal.right - sine * along.right, normal.forward - sine * along.forward};
    const float lift_len = std::sqrt(lift_way.right * lift_way.right
                                     + lift_way.forward * lift_way.forward);
    if (lift_len > 1e-5f) {
        lift_way = Flat{lift_way.right / lift_len, lift_way.forward / lift_len};
    } else {
        lift_way = Flat{};
    }
    const float scale = pressure * sail.area;
    out.force.right = scale * (out.lift * lift_way.right + out.drag * along.right);
    out.force.forward = scale * (out.lift * lift_way.forward + out.drag * along.forward);
    const float most = std::sqrt(sail.curve.lift_most * sail.curve.lift_most
                                 + (sail.curve.drag_edge + sail.curve.drag_flat)
                                       * (sail.curve.drag_edge + sail.curve.drag_flat));
    const float total = std::sqrt(out.lift * out.lift + out.drag * out.drag);
    out.fill = std::clamp(total / std::max(most, 1e-3f), 0.0f, 1.0f) * (aback ? -1.0f : 1.0f);
    return out;
}

/// THE LEVER, TURNED INTO A LINE. A lever runs -1 to +1: its sign is the side the sail is
/// swung to, and how far it is from the middle is how HARD it is trimmed in -- a yard
/// braced sharp up, a boom hauled close. At 0 the sail is let right out to its furthest.
inline float set_angle_of(const Sail& sail, float lever) {
    const float in = std::clamp(std::fabs(lever), 0.0f, 1.0f);
    return sail.furthest - in * (sail.furthest - sail.closest);
}

inline float side_of(float lever) {
    return lever < 0.0f ? -1.0f : 1.0f;
}

/// THE TRIM A SAILOR WOULD SET for an apparent wind, as a lever: the sail's line at its
/// peak angle of attack off the air, swung to leeward, and held inside its limits. Off the
/// wind that asks for more than the furthest the sail goes, and it is let right out.
///
/// It is a law, not a search, because a search for the best trim is a search a ship
/// nobody is sailing does not need. It is what `fly_itself` holds a sail at every tick,
/// from the apparent wind the ship feels.
inline float lever_for(const Sail& sail, float apparent) {
    const float off = std::fabs(apparent);
    const float wanted = std::clamp(off - sail.curve.lift_peak, sail.closest, sail.furthest);
    const float span = std::max(sail.furthest - sail.closest, 1e-3f);
    const float in = std::clamp((sail.furthest - wanted) / span, 0.0f, 1.0f);
    // To LEEWARD: the wind on the starboard side (a positive angle) puts the sail to port.
    const float side = apparent > 0.0f ? -1.0f : 1.0f;
    // A lever of exactly 0 has no side; a sail let right out still has to be on one.
    return side * std::max(in, 1e-3f);
}

/// HULL SPEED, in metres a second, for a waterline length in metres: 1.34 knots per root
/// foot of waterline. It is where the bow wave grows as long as the hull and the ship starts
/// climbing its own wave. A soft wall and not a limit.
inline float hull_speed_for(float waterline_metres) {
    const float feet = waterline_metres * 3.28084f;
    return 1.34f * std::sqrt(std::max(feet, 0.0f)) * 0.514444f;
}

}  // namespace cockpit
}  // namespace ashiato_gd
