#pragma once
/// THE ISLAND'S MOUNTAINS IN THE SIMULATION: every tile of `Mountains` as one static Box3D triangle mesh, and its pyramid for
/// the autopilots' leg tests.
///
/// THE SAME TRIANGLES THE PICTURE DRAWS. Each tile's vertices are whole metres and ticks of 1/32 m, exact in a float32, and
/// its indices are handed over as they are -- clockwise from above, and Box3D is told so -- so the mesh Box3D collides
/// with is the mesh `cockpit/world/mountain_view.gd` draws, to the bit. `cockpit/tests/mountains.gd` casts rays through
/// the physics at the drawn triangles and holds the two to a centimetre.
///
/// WHY A MESH AND NOT A HEIGHT FIELD, BOXES OR A GDSCRIPT GENERATOR: see `range_core.hpp`. Box3D makes contacts with a
/// mesh only on a static body, which a mountain is, and its BVH is built once at load (`useMedianSplit`, since the
/// triangles lie on a grid). Nothing here is in the rollback state: a static shape never moves, so it costs a rollback
/// nothing, and only what touches it pays for it.
///
/// BUILT ON EVERY PEER from the same integers in one order, and `hash` combines each mesh's own Box3D hash, so the hello
/// can say whether two peers built the same thing, as `Bedrock::hash` does for the generated ground.
///
/// IT OWNS THE MESHES' DATA: a mesh shape keeps a pointer to the data it was made from (box3d.h, `b3CreateMeshShape`),
/// so the data lives here until the bodies are gone. Destroyed after the world, it only frees; destroyed while the world
/// lives -- mountains set twice -- it takes its bodies out first.

#include <cstdint>
#include <memory>
#include <vector>

#include "box3d/box3d.h"
#include "cockpit/range_core.hpp"

namespace ashiato_gd {
namespace ground {

class Massif {
public:
    Massif(std::shared_ptr<const Mountains> mountains, b3WorldId world);
    ~Massif();
    Massif(const Massif&) = delete;
    Massif& operator=(const Massif&) = delete;

    /// The surface Box3D collides with at a point, metres; 0 off the rock.
    float height_at(double x, double z) const { return static_cast<float>(mountains_->surface_at(x, z)); }
    /// The highest rock over a rectangle, whole metres rounded up, never lower than the truth; very low with none.
    float highest_over(double x0, double z0, double x1, double z1) const {
        return mountains_->pyramid().highest_over(x0, z0, x1, z1);
    }
    bool clear_between(const b3Vec3& a, const b3Vec3& b, float clearance, float overhead) const {
        return mountains_->pyramid().clear_between(a, b, clearance, overhead);
    }

    std::int64_t meshes() const { return static_cast<std::int64_t>(data_.size()); }
    std::int64_t triangles() const { return mountains_->triangles(); }
    std::int64_t bytes() const { return bytes_; }
    std::int64_t pyramid_bytes() const { return mountains_->pyramid().bytes(); }
    std::int64_t build_usec() const { return build_usec_; }
    std::int64_t degenerate() const { return degenerate_; }
    /// Every mesh's Box3D hash, in the order they were built.
    std::uint64_t hash() const { return hash_; }

private:
    std::shared_ptr<const Mountains> mountains_;
    b3WorldId world_{};
    std::vector<b3MeshData*> data_;
    std::vector<b3BodyId> bodies_;
    std::int64_t bytes_ = 0;
    std::int64_t build_usec_ = 0;
    std::int64_t degenerate_ = 0;
    std::uint64_t hash_ = 1469598103934665603ull;
};

}  // namespace ground
}  // namespace ashiato_gd
