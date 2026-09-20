#pragma once
/// GODOT'S REAL IS NOT THE SIMULATION'S FLOAT, and this is the one place that says so.
///
/// `godot::real_t` is a float in an ordinary build and a DOUBLE in one compiled with
/// `precision=double` -- which this project is, because a world ten kilometres across
/// drawn in float32 lands every position on a grid that grows with distance from the
/// origin, and out by the carrier that grid is half a millimetre. See cockpit/agents.md.
///
/// Everything below the Godot boundary stays float32 and should. Box3D is a float32 solver
/// and always will be; the ECS components are float32 because they are quantised onto the
/// wire anyway; and a tick of travel at 150 m/s is 1.25 m, which is nowhere near the
/// precision floor of a float even at the far corner of the map. The problem was never the
/// simulation's arithmetic, it was DRAWING, and drawing is Godot's side of the line.
///
/// So the line is crossed on purpose, in one direction, through these. Written out rather
/// than left to an implicit conversion because in a double build the implicit one is a
/// narrowing conversion and brace-initialisation refuses it -- which is the compiler
/// pointing at exactly the boundary this header names, forty-five times.

#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include "box3d/box3d.h"

namespace ashiato_gd {

/// One Godot scalar, narrowed on purpose.
inline float from_godot(godot::real_t value) {
    return static_cast<float>(value);
}

/// A direction, an extent, a velocity: anything Box3D treats as a vector.
inline b3Vec3 b3_vec(const godot::Vector3& v) {
    return b3Vec3{from_godot(v.x), from_godot(v.y), from_godot(v.z)};
}

/// A POSITION, which Box3D keeps in its own type so that a point and a direction cannot be
/// confused for one another.
inline b3Pos b3_pos(const godot::Vector3& v) {
    return b3Pos{from_godot(v.x), from_godot(v.y), from_godot(v.z)};
}

/// An orientation. Box3D wants the vector part and the scalar part separately.
inline b3Quat b3_quat(const godot::Quaternion& q) {
    return b3Quat{b3Vec3{from_godot(q.x), from_godot(q.y), from_godot(q.z)},
                  from_godot(q.w)};
}

}  // namespace ashiato_gd
