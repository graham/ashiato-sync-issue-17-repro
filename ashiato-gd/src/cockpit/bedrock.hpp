#pragma once
/// THE GROUND THE SIMULATION STANDS ON: the ground function's surface as Box3D height fields, one a land cell, and a
/// pyramid of the highest ground for the autopilots' leg tests.
///
/// WHY IT IS BUILT HERE AND NOT SENT. Static collision is not replicated (cockpit/agents.md, RULES 8): every peer builds
/// it and the simulation never mentions it again, so a peer whose hillside is a tick elsewhere predicts itself into the
/// server's. This builds it from `ground::Field` -- integers, the same to the bit on every peer -- in one canonical
/// order, and `hash` over every field's own hash says whether two peers built the same thing.
///
/// A HEIGHT FIELD A CELL of `kCell` metres, `kCell / kSpacing + 1` samples a side, holding every tick of 1/32 m exactly.
/// Box3D quantises a field's heights over its range in 65,535 steps (box3d/src/height_field.c, `b3CreateHeightField`);
/// a range of exactly 65,535 ticks from a lowest sample on the tick grid makes each step exactly 1/32 m, and the
/// subtract, multiply by 32 and truncate exact in float32. So the collision holds the function's own numbers:
/// - A cell whose samples span more than that is four fields of half the size, each with its own range on the same
///   grid so shared edges agree, and a quarter that still spans more is four again. The alpine world had 15 such cells
///   before its summits were rounded and 24 after, since rounding kept the peaks' height on fuller shoulders; the first
///   version split once, and `tests/ground_collision.gd` found 3 of those quarters still holding a height rounded.
/// - A cell whose every sample is at or under `kSeaFloorTicks` is open sea and gets no field.
/// Rejected (godotgames-drafts/2026-09-14/cockpit-terrain/report.md, 2.3): one field for the whole square, 76 MB with
/// the sea in it and one range that rounds every height; a triangle mesh, seven times the memory on a regular grid;
/// boxes, a stepped surface under wheels.
///
/// THE PYRAMID answers what the physics engine would answer too slowly. Level 0 is the highest of the nine 16 m samples
/// round each 32 m square -- every vertex of every triangle over it -- rounded up to a whole metre; each level above is
/// the highest of four. A leg is clear when its lower end stands above the highest ground under its footprint widened
/// by the clearance; otherwise it is halved and each half asked, down to 32 m, where a piece still not clear is
/// blocked. So it may call a clear leg blocked and never the other way: `cockpit/tests/ground_collision.gd` holds it to
/// the drawn surface sampled every 2 m. Phase 1 measured it at 0.7 to 0.8 us a 3 km leg, 12 to 130 times cheaper than
/// asking Box3D.
///
/// THE DRAWN SURFACE, `height_at`, is exactly the triangle Box3D collides with: each 16 m square split on the diagonal
/// from (x + 16, z) to (x, z + 16), as `b3GetHeightFieldTriangle` splits it.
///
/// IT OWNS THE FIELDS' DATA. A height-field shape keeps a pointer to the data it was made from and copies nothing
/// (box3d/src/shape.c), so the data lives here until the bodies are gone. Destroyed after the world, it only frees;
/// destroyed while the world lives -- a ground set twice -- it takes its bodies out first.

#include <cstdint>
#include <vector>

#include "box3d/box3d.h"
#include "cockpit/ground_core.hpp"
#include "cockpit/height_pyramid.hpp"

namespace ashiato_gd {
namespace ground {

class Bedrock {
public:
    /// A cell's side, metres: `WorldMap.CELL`, so a field is a scenery cell.
    static constexpr i64 kCell = 1024;
    /// Metres between samples: the finest the memory allows (report, 2.3).
    static constexpr i64 kSpacing = 16;
    /// The pyramid's finest square, metres: two sample spacings.
    static constexpr i64 kPyramidSquare = 32;
    /// A cell whose every sample is at or under this, in ticks, is open sea: -40 m.
    static constexpr i64 kSeaFloorTicks = -40 * kTicksPerMetre;
    /// The most ticks one field's range holds exactly.
    static constexpr i64 kFieldRangeTicks = 65535;
    /// The fewest sample spacings a split field is cut down to: 32 m, where no ground rises 2,048 m.
    static constexpr i64 kSmallestSpan = 2;

    /// Builds every field into `world`, and the pyramid. `field` is copied: the ground a world stands on cannot change
    /// under it because somebody configured the `GroundField` it came from again.
    Bedrock(const Field& field, b3WorldId world);
    ~Bedrock();
    Bedrock(const Bedrock&) = delete;
    Bedrock& operator=(const Bedrock&) = delete;

    /// The surface Box3D collides with at a point, metres.
    float height_at(double x, double z) const;
    /// The water standing at the nearest whole metre -- a lake's level, or the sea's 0 over ground below it -- or false.
    bool water_at(double x, double z, float& level) const;
    /// The highest ground over a rectangle, whole metres rounded up, never lower than the truth. Outside the square it
    /// answers for the square's edge, which is open sea.
    float highest_over(double x0, double z0, double x1, double z1) const;
    /// Whether the leg from `a` to `b` clears the ground: see THE PYRAMID above. `overhead` is how far above the ground a
    /// leg must pass for the ground under it not to count, as it is for a box in `CockpitWorld::clear_between`; the
    /// ground counts from the lesser of that and `clearance`.
    bool clear_between(const b3Vec3& a, const b3Vec3& b, float clearance, float overhead) const;

    i64 fields() const { return static_cast<i64>(data_.size()); }
    i64 land_cells() const { return land_cells_; }
    i64 split_cells() const { return split_cells_; }
    /// Fields whose samples still spanned more than one range after the split; the suite requires none.
    i64 unheld_fields() const { return unheld_fields_; }
    i64 bytes() const { return bytes_; }
    i64 pyramid_bytes() const { return pyramid_.bytes(); }
    i64 build_usec() const { return build_usec_; }
    /// Every field's Box3D hash, in the order they were built.
    std::uint64_t hash() const { return hash_; }

private:
    void lay_cell(const std::vector<std::int32_t>& band, i64 columns, i64 first_column, i64 x0, i64 z0);
    void lay_region(const std::vector<std::int32_t>& band, i64 columns, i64 first_column, i64 first_row, i64 span,
                    i64 x0, i64 z0);
    void lay_field(const std::vector<std::int32_t>& band, i64 columns, i64 first_column, i64 first_row, i64 span,
                   i64 x0, i64 z0);

    Field field_;
    b3WorldId world_{};
    /// Where the square of cells starts, metres, on both axes.
    i64 origin_ = 0;
    /// Cells a side of the square.
    i64 cells_ = 0;
    std::vector<b3HeightFieldData*> data_;
    std::vector<b3BodyId> bodies_;
    /// THE PYRAMID, `height_pyramid.hpp`'s since 2026-09-18, when the island's mountains came to need it too.
    HeightPyramid pyramid_;
    std::vector<float> heights_;
    i64 land_cells_ = 0;
    i64 split_cells_ = 0;
    i64 unheld_fields_ = 0;
    i64 bytes_ = 0;
    i64 build_usec_ = 0;
    std::uint64_t hash_ = 1469598103934665603ull;
};

}  // namespace ground
}  // namespace ashiato_gd
