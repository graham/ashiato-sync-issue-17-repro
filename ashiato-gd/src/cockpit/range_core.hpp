#pragma once
/// THE ISLAND'S MOUNTAINS AS A FUNCTION OF INTEGERS, AND THE TRIANGLES THAT ARE BOTH THEIR PICTURE AND THEIR COLLISION.
///
/// A RANGE is a ridge line through a few control points on the ground -- a Catmull-Rom spline -- each point with a crest
/// height and a foot half-width. Along the ridge, peaks and saddles come from integer noise and are held inside the range's
/// ENVELOPE: never above its `peak`, never below its `saddle`. Across it, the ground falls from the crest to the valley floor
/// on one profile, with SPURS running down from the ridge and GULLIES between them. A single mountain is a range with one
/// point, whose spurs radiate. Every range's numbers are the game's, in `cockpit/world/mountain_ranges.gd`, and nowhere else.
///
/// THE TRIANGLES ARE THE PRODUCT, not the height. The function is sampled on a grid `spacing` metres apart whose every
/// vertex is moved by a hash up to a quarter of the spacing each way -- so the facets are irregular, the house's low-poly
/// look (modelling_here.md), and never fold -- and each quad is split on the diagonal that follows the crest. Those
/// triangles, cut into square TILES, are handed to Box3D as static meshes (`massif.hpp`) AND to the renderer
/// (`cockpit/world/mountain_view.gd`) as the same arrays, so what is drawn is what is hit, to the bit, at every distance:
/// there is no level of detail. A mountain drawn where the simulation has none looks exactly like a networking fault.
///
/// WHAT WAS REJECTED, and why (cockpit-mountains, 2026-09-18):
/// - STACKED BOXES, the island's mountains until now: every box was also collision, so the picture was stepped
///   pyramids, and a smooth surface drawn over them stood 18 to 38 m clear of the rock a shell burst on (RockTuning).
/// - HEIGHT FIELDS, as the generated ground uses (`bedrock.hpp`): a regular grid with a fixed diagonal reads as a grid,
///   not as faceted rock, and a height field cannot move a vertex sideways.
/// - A GENERATOR IN GDSCRIPT: floating point and a libm on every peer, and seconds of boot.
/// - LEVELS OF DETAIL: all the island's mountains are tens of thousands of triangles, which a GPU draws without noticing,
///   and a coarser far picture would be a surface the simulation does not have.
///
/// NO FLOATING POINT IN THE SHAPE. Positions are whole metres, heights ticks of 1/32 m, fractions Q16 on int64, square
/// roots integer; so the answer does not depend on the compiler, the platform or the engine's precision. A vertex is an
/// integer x and z and a height in ticks, all exact in a float32, so the mesh Box3D is handed is exactly these numbers.
/// `cockpit/tests/mountains.gd` holds the library to a recorded hash on both editors.
///
/// KEEP-OUTS. The level hands in rectangles, each with a floor: over a rectangle the rock stands no higher than its floor,
/// and round it no higher than the floor plus `kClearRise` a metre out -- a talus, not a cliff. That is how a runway's
/// approach, a spawn, a gate or the railway stays clear: nothing is generated into them, and a range is not deleted
/// whole for touching one, which was the old way and left flat cuts in mountainsides.
///
/// THREAD-SAFE TO READ. Built whole by its constructor, then every query is const.

#include <cstdint>
#include <vector>

#include "cockpit/height_pyramid.hpp"

namespace ashiato_gd {
namespace ground {

using i64 = std::int64_t;

struct RangePoint {
    /// Where the ridge passes, whole metres.
    i64 x = 0, z = 0;
    /// The crest's height here before the noise, and how far out the foot reaches either side, whole metres.
    i64 crest = 0, foot = 0;
};

struct RangeDef {
    std::vector<RangePoint> points;
    /// THE ENVELOPE, whole metres: the crest never rises above `peak` nor falls below `saddle`.
    i64 peak = 0, saddle = 0;
    i64 salt = 0;
};

/// Over [x0, x1] by [z0, z1], whole metres, the rock stands no higher than `floor_ticks`.
struct KeepOut {
    i64 x0 = 0, z0 = 0, x1 = 0, z1 = 0, floor_ticks = 0;
    /// HOW MUCH THE BOX IS GROWN before the floor and the talus are worked, whole metres; negative is the default, one
    /// triangle's reach. Only a keep-out whose own kind can bear rock DRAWN a little inside it asks for less (the railway:
    /// see `Terrain.RAIL_MARGIN`); everything an aeroplane flies over, or a person stands in, keeps the default.
    i64 margin = -1;
    /// HOW STEEPLY ROCK MAY CLIMB OUT OF THE BOX, in fifths of a metre a metre: 6 is `kClearRiseNum`/`kClearRiseDen`, 6/5 (fifty
    /// degrees), 15 is three to one. Zero or negative is that default. Only the railway asks for more (`Terrain.RAIL_RISE_FIFTHS`):
    /// beside a line in a cutting the mountain reads as near when the ground has risen enough to be one, and at 6/5 a 100 m wall
    /// needs 83 m of run. A kind that asks for LESS than the default is filed by the shallower of the two (`Mountains`'s
    /// constructor), so the rock a bucket must be checked for is never missed.
    i64 rise_fifths = 0;
};

struct MountainTuning {
    /// Metres between grid vertices before the jitter.
    i64 spacing = 48;
    /// Quads a side of a tile.
    i64 tile_quads = 40;
};

/// ONE TILE: its corner in whole metres, and its triangles in the tile's own frame -- vertices as (x, ticks, z) with x and
/// z metres from the corner, three indices a triangle, CLOCKWISE seen from above, which is Godot's front face, and Box3D is
/// told so. `grit` is two bytes a vertex for the rock shader: how deep in a gully it lies, and how far down the flank.
struct MountainTile {
    i64 tx = 0, tz = 0;
    i64 x0 = 0, z0 = 0;
    std::vector<std::int32_t> vertices;
    std::vector<std::int32_t> indices;
    std::vector<std::uint8_t> grit;
    /// Every grid vertex's height in ticks, (tile_quads + 1) a side, row by row along z, for `surface_at`.
    std::vector<std::int32_t> grid;
};

class Mountains {
public:
    /// How much the rock may rise a metre out from a keep-out: 6/5, fifty degrees.
    static constexpr i64 kClearRiseNum = 6, kClearRiseDen = 5;
    /// Ticks a metre, as the generated ground's (`ground_core.hpp`).
    static constexpr i64 kTicks = 32;

    Mountains(const MountainTuning& tuning, std::vector<RangeDef> ranges, std::vector<KeepOut> keepouts);

    /// THE FUNCTION at whole metres, ticks: the highest range there, after the keep-outs. Grit into `gully` and `down`.
    i64 height_ticks(i64 x, i64 z, int* gully = nullptr, int* down = nullptr) const;
    /// THE DRAWN SURFACE -- the triangle Box3D collides with -- at a point, metres; 0 where there is no rock.
    double surface_at(double x, double z) const;

    const std::vector<MountainTile>& tiles() const { return tiles_; }
    const MountainTuning& tuning() const { return tuning_; }
    const std::vector<RangeDef>& ranges() const { return ranges_; }
    const HeightPyramid& pyramid() const { return pyramid_; }
    std::uint64_t hash() const { return hash_; }
    i64 triangles() const { return triangles_; }
    i64 vertex_count() const { return vertex_count_; }
    i64 build_usec() const { return build_usec_; }

    /// Where grid vertex (i, j) stands, whole metres: the spacing and the jitter.
    void vertex_at(i64 i, i64 j, i64& x, i64& z) const;

private:
    struct Ridge {
        /// The spline sampled: metres, and the crest and foot there, metres.
        std::vector<i64> x, z, crest, foot;
        /// Distance along the ridge to each sample, in sixteenths of a metre.
        std::vector<i64> along;
        i64 period = 0;
        /// Bounds the rock can reach, whole metres.
        i64 x0 = 0, z0 = 0, x1 = 0, z1 = 0;
    };

    i64 range_height(size_t r, i64 x, i64 z, int& gully, int& down) const;
    i64 kept_under(i64 x, i64 z, i64 h) const;
    void lay_tile(i64 tx, i64 tz);
    std::int32_t grid_height(i64 i, i64 j) const;

    MountainTuning tuning_;
    std::vector<RangeDef> ranges_;
    std::vector<Ridge> ridges_;
    std::vector<KeepOut> keepouts_;
    /// Keep-outs by 256 m bucket, grown by how far their talus can reach: bucket key -> indices.
    std::vector<std::pair<i64, std::vector<int>>> buckets_;
    std::vector<MountainTile> tiles_;
    /// THE TILES BY PLACE, for `surface_at`, which a vehicle's deck test asks every tick: `tile_at_` is `tiles_wide_` by
    /// `tiles_deep_` from tile (`first_tx_`, `first_tz_`), each an index into `tiles_` or -1.
    i64 first_tx_ = 0, first_tz_ = 0, tiles_wide_ = 0, tiles_deep_ = 0;
    std::vector<int> tile_at_;
    HeightPyramid pyramid_;
    std::uint64_t hash_ = 1469598103934665603ull;
    i64 triangles_ = 0;
    i64 vertex_count_ = 0;
    i64 build_usec_ = 0;
};

}  // namespace ground
}  // namespace ashiato_gd
