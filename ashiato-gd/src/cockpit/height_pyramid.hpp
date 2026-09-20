#pragma once
/// THE HIGHEST GROUND OVER ANY RECTANGLE, IN FOUR LOOKUPS: a max pyramid over 32 m squares, and the autopilots' leg test
/// built on it. Level 0 holds, for every square, a height no solid surface over that square rises above, in whole metres
/// rounded up; each level above holds the highest of four below it.
///
/// A LEG IS CLEAR when its lower end stands above the highest ground under its footprint widened by the clearance; if not,
/// it is halved and each half asked, down to one square, where a piece still not clear is blocked. So it may call a clear
/// leg blocked and never the other way. Phase 1 of the generated ground measured it at 0.7 to 0.8 us a 3 km leg, 12 to 130
/// times cheaper than asking Box3D (bedrock.hpp).
///
/// WHY IT IS ITS OWN FILE (cockpit-mountains, 2026-09-18): it was `Bedrock`'s alone until the island's mountains became a
/// triangle mesh (`massif.hpp`) that needs the same question answered the same way. Lifted out unchanged rather than copied,
/// so the two grounds cannot come to disagree about what "clear" means; `Bedrock` fills level 0 from its height-field
/// samples and `Massif` from its triangles, and everything above level 0 is this file's.

#include <cstdint>
#include <vector>

#include "box3d/box3d.h"

namespace ashiato_gd {
namespace ground {

class HeightPyramid {
public:
    /// The finest square's side, metres.
    static constexpr std::int64_t kSquare = 32;
    /// A square with nothing on it.
    static constexpr std::int16_t kNothing = INT16_MIN;

    HeightPyramid() = default;
    /// `finest` is `side` by `side` squares, row by row along z, each row along x, the first at (`origin`, `origin`).
    HeightPyramid(std::int64_t origin, std::int64_t side, std::vector<std::int16_t> finest);

    bool empty() const { return levels_.empty(); }
    /// The highest ground over a rectangle, whole metres rounded up, never lower than the truth; `kNothing` over squares
    /// with nothing. Outside the square it answers for the square's edge.
    float highest_over(double x0, double z0, double x1, double z1) const;
    /// THE SAME, SQUARE BY SQUARE at the finest level: never lower than the truth, and never higher than the highest
    /// ground within one square of the rectangle -- where `highest_over`'s four lookups at a coarser level can answer for
    /// ground a few hundred metres off. For the few thousand questions asked while a world is laid out (a fire, a wood, a
    /// road, a waypoint), not the autopilots' millions: a fire placed in a pass was refused for rock 330 m away when
    /// asked within 90 m (tests/fires.gd, 2026-09-18).
    float highest_within(double x0, double z0, double x1, double z1) const;
    /// Whether the leg from `a` to `b` clears the ground: see the top of this file. `overhead` is how far above the
    /// ground a leg must pass for the ground under it not to count, as for a box in `CockpitWorld::clear_between`; the
    /// ground counts from the lesser of that and `clearance`.
    bool clear_between(const b3Vec3& a, const b3Vec3& b, float clearance, float overhead) const;
    std::int64_t bytes() const;

private:
    bool piece_is_clear(const b3Vec3& a, const b3Vec3& b, float clearance, float lift, int depth) const;

    std::int64_t origin_ = 0;
    /// Level by level, finest first, each `sides_[k]` squares a side, row by row along z.
    std::vector<std::vector<std::int16_t>> levels_;
    std::vector<std::int64_t> sides_;
};

}  // namespace ground
}  // namespace ashiato_gd
