#include "cockpit/range_core.hpp"

#include <algorithm>
#include <chrono>
#include <climits>
#include <cmath>
#include <map>
#include <set>

/// See range_core.hpp for what this is and why it is integers. A change to any line of the shape below is a change of
/// island and moves the hash `cockpit/tests/mountains.gd` records, in the same commit.

namespace ashiato_gd {
namespace ground {
namespace {

constexpr i64 ONE = 65536;
/// Samples of the spline between two control points.
constexpr i64 kSteps = 12;
/// The keep-outs' buckets, metres.
constexpr i64 kBucket = 256;
constexpr i64 kPositive = i64(1) << 20;

inline i64 clampi(i64 v, i64 lo, i64 hi) { return std::min(std::max(v, lo), hi); }
inline i64 absi(i64 v) { return v < 0 ? -v : v; }
/// Division rounding toward minus infinity, for grid and bucket indices either side of the origin.
inline i64 floor_div(i64 a, i64 b) { return a >= 0 ? a / b : -((-a + b - 1) / b); }

/// The integer square root, rounded down, by Newton's method from above: exact for every non-negative int64.
inline i64 isqrt(i64 n) {
    if (n <= 0) return 0;
    std::uint64_t x = static_cast<std::uint64_t>(std::sqrt(static_cast<double>(n)));
    // The double is only a starting guess; the two loops below make the answer exact whatever it rounded to.
    while (x * x > static_cast<std::uint64_t>(n)) --x;
    while ((x + 1) * (x + 1) <= static_cast<std::uint64_t>(n)) ++x;
    return static_cast<i64>(x);
}

/// The generated ground's hash (`ground_core.cpp`), with no seed: 32 bits from two integers and a salt.
inline i64 hash3(i64 a, i64 b, i64 salt) {
    i64 h = ((a + kPositive) * 374761393 + (b + kPositive) * 668265263 + salt * 1103515245) & 0xFFFFFFFFLL;
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFFLL;
    return h ^ (h >> 16);
}

/// 3t^2 - 2t^3 in Q16.
inline i64 smooth01(i64 t) { return (((t * t) >> 16) * (3 * ONE - 2 * t)) >> 16; }

/// VALUE NOISE ALONG A LINE, Q16 in [0, ONE): `t` in Q16 lattice units.
inline i64 noise1(i64 t, i64 salt) {
    const i64 i = t >> 16;
    const i64 f = smooth01(t - (i << 16));
    const i64 a = hash3(i, 0, salt) & 0xFFFF;
    const i64 b = hash3(i + 1, 0, salt) & 0xFFFF;
    return a + (((b - a) * f) >> 16);
}

/// VALUE NOISE OVER THE GROUND, Q16 in [0, ONE), on a lattice `cell` metres square.
inline i64 noise2(i64 x, i64 z, i64 cell, i64 salt) {
    const i64 i = floor_div(x, cell), j = floor_div(z, cell);
    const i64 fx = smooth01(((x - i * cell) * ONE) / cell);
    const i64 fz = smooth01(((z - j * cell) * ONE) / cell);
    const i64 a = hash3(i, j, salt) & 0xFFFF, b = hash3(i + 1, j, salt) & 0xFFFF;
    const i64 c = hash3(i, j + 1, salt) & 0xFFFF, d = hash3(i + 1, j + 1, salt) & 0xFFFF;
    const i64 top = a + (((b - a) * fx) >> 16);
    const i64 bottom = c + (((d - c) * fx) >> 16);
    return top + (((bottom - top) * fz) >> 16);
}

/// A COSINE WITHOUT A LIBM: `turns` in Q16, answer in [-ONE, ONE], ONE at whole turns and -ONE at half turns. Two
/// smoothsteps back to back: within 1% of cos(2 pi t), and every peer computes it to the bit.
inline i64 wave(i64 turns) {
    const i64 f = turns & 0xFFFF;
    const i64 tri = absi(2 * f - ONE);
    return 2 * smooth01(tri) - ONE;
}

/// THE BEARING FROM THE ORIGIN TO (dx, dz), in Q16 turns [0, ONE), without a libm: an octant and
/// atan(r) ~ r / 8 + 0.0434 r (1 - r) turns, within 0.0006 of a turn.
inline i64 bearing(i64 dx, i64 dz) {
    if (dx == 0 && dz == 0) return 0;
    const i64 ax = absi(dx), az = absi(dz);
    const bool steep = az > ax;
    const i64 r = steep ? (ax * ONE) / az : (az * ONE) / ax;
    i64 a = r / 8 + ((2844 * ((r * (ONE - r)) >> 16)) >> 16);
    if (steep) a = ONE / 4 - a;
    if (dx < 0) a = ONE / 2 - a;
    if (dz < 0) a = ONE - a;
    return a & 0xFFFF;
}

inline void mix(std::uint64_t& h, i64 v) {
    for (int b = 0; b < 8; ++b) {
        h = (h ^ static_cast<std::uint64_t>((v >> (8 * b)) & 0xFF)) * 1099511628211ull;
    }
}

}  // namespace

Mountains::Mountains(const MountainTuning& tuning, std::vector<RangeDef> ranges, std::vector<KeepOut> keepouts)
    : tuning_(tuning), ranges_(std::move(ranges)), keepouts_(std::move(keepouts)) {
    const auto began = std::chrono::steady_clock::now();
    const i64 S = tuning_.spacing;
    i64 tallest = 0;
    // THE RIDGES: every range's spline sampled, with its crest and foot there, and how far along it each sample is.
    for (const RangeDef& range : ranges_) {
        Ridge ridge;
        const std::vector<RangePoint>& p = range.points;
        const size_t n = p.size();
        if (n == 1) {
            ridge.x.push_back(p[0].x);
            ridge.z.push_back(p[0].z);
            ridge.crest.push_back(p[0].crest);
            ridge.foot.push_back(p[0].foot);
        }
        for (size_t i = 0; n > 1 && i + 1 < n; ++i) {
            const RangePoint& p0 = p[i == 0 ? 0 : i - 1];
            const RangePoint& p1 = p[i];
            const RangePoint& p2 = p[i + 1];
            const RangePoint& p3 = p[std::min(i + 2, n - 1)];
            for (i64 k = 0; k < kSteps; ++k) {
                const i64 t = (k * ONE) / kSteps;
                const i64 t2 = (t * t) >> 16;
                const i64 t3 = (t2 * t) >> 16;
                auto spline = [t, t2, t3](i64 a, i64 b, i64 c, i64 d) {
                    return (2 * b * ONE + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (3 * b - a - 3 * c + d) * t3)
                        / (2 * ONE);
                };
                ridge.x.push_back(spline(p0.x, p1.x, p2.x, p3.x));
                ridge.z.push_back(spline(p0.z, p1.z, p2.z, p3.z));
                ridge.crest.push_back(p1.crest + ((p2.crest - p1.crest) * t) / ONE);
                ridge.foot.push_back(p1.foot + ((p2.foot - p1.foot) * t) / ONE);
            }
            if (i + 2 == n) {
                ridge.x.push_back(p2.x);
                ridge.z.push_back(p2.z);
                ridge.crest.push_back(p2.crest);
                ridge.foot.push_back(p2.foot);
            }
        }
        i64 walked = 0;
        i64 widest = 0;
        ridge.x0 = ridge.x1 = ridge.x[0];
        ridge.z0 = ridge.z1 = ridge.z[0];
        for (size_t k = 0; k < ridge.x.size(); ++k) {
            if (k > 0) {
                const i64 dx = ridge.x[k] - ridge.x[k - 1], dz = ridge.z[k] - ridge.z[k - 1];
                walked += isqrt((dx * dx + dz * dz) * 256);
            }
            ridge.along.push_back(walked);
            widest = std::max(widest, ridge.foot[k]);
            ridge.x0 = std::min(ridge.x0, ridge.x[k]);
            ridge.x1 = std::max(ridge.x1, ridge.x[k]);
            ridge.z0 = std::min(ridge.z0, ridge.z[k]);
            ridge.z1 = std::max(ridge.z1, ridge.z[k]);
        }
        // THE FARTHEST THE ROCK REACHES: a spur's foot stands out at most 1.175 feet (see `range_height`).
        const i64 reach = widest * 5 / 4 + S;
        ridge.x0 -= reach;
        ridge.x1 += reach;
        ridge.z0 -= reach;
        ridge.z1 += reach;
        ridge.period = 420 + hash3(range.salt, 0, 77) % 181;
        tallest = std::max(tallest, range.peak);
        ridges_.push_back(std::move(ridge));
    }
    // THE KEEP-OUTS, grown by one triangle's reach and filed by bucket as far out as the talus round each could stand
    // below the tallest peak. GROWN because it is the DRAWN SURFACE that must stay out, not the function: a triangle
    // over a keep-out's edge interpolates from corners up to 2.25 spacings away (a jittered quad's diagonal), and the
    // first build, holding only the corners inside, drew rock 1.8 m into a keep-out whose floor was 0.
    const i64 reach_margin = (S * 9) / 4;
    std::map<i64, std::vector<int>> filed;
    for (size_t k = 0; k < keepouts_.size(); ++k) {
        KeepOut& keep = keepouts_[k];
        const i64 margin = keep.margin >= 0 ? keep.margin : reach_margin;
        keep.x0 -= margin;
        keep.z0 -= margin;
        keep.x1 += margin;
        keep.z1 += margin;
        keep.floor_ticks = std::max<i64>(keep.floor_ticks, 0);
        const i64 rise = tallest * kTicks - keep.floor_ticks;
        if (rise <= 0) continue;
        // FILED BY THE SHALLOWER of the default and this box's own rise: the shallower the slope the further out the ground can
        // still be held down by it, so the shallower is the widest reach and a bucket filed by it is never missed. Filing by a
        // steep rise alone would leave holes, not cliffs.
        const i64 filed_rise = std::min<i64>(keep.rise_fifths > 0 ? keep.rise_fifths : kClearRiseNum, kClearRiseNum);
        const i64 talus = (rise * kClearRiseDen) / (kTicks * filed_rise) + 1;
        for (i64 bz = floor_div(keep.z0 - talus, kBucket); bz <= floor_div(keep.z1 + talus, kBucket); ++bz) {
            for (i64 bx = floor_div(keep.x0 - talus, kBucket); bx <= floor_div(keep.x1 + talus, kBucket); ++bx) {
                filed[((bz + kPositive) << 24) | (bx + kPositive)].push_back(static_cast<int>(k));
            }
        }
    }
    buckets_.assign(filed.begin(), filed.end());
    // THE TILES any range reaches, in one order on every peer: along z, then along x.
    const i64 T = tuning_.tile_quads;
    std::set<std::pair<i64, i64>> wanted;
    for (const Ridge& ridge : ridges_) {
        for (i64 tz = floor_div(floor_div(ridge.z0, S) - 1, T); tz <= floor_div(floor_div(ridge.z1, S) + 1, T); ++tz) {
            for (i64 tx = floor_div(floor_div(ridge.x0, S) - 1, T); tx <= floor_div(floor_div(ridge.x1, S) + 1, T); ++tx) {
                wanted.insert({tz, tx});
            }
        }
    }
    for (const auto& [tz, tx] : wanted) {
        lay_tile(tx, tz);
    }
    if (!tiles_.empty()) {
        i64 tx0 = INT64_MAX, tx1 = INT64_MIN, tz0 = INT64_MAX, tz1 = INT64_MIN;
        for (const MountainTile& tile : tiles_) {
            tx0 = std::min(tx0, tile.tx);
            tx1 = std::max(tx1, tile.tx);
            tz0 = std::min(tz0, tile.tz);
            tz1 = std::max(tz1, tile.tz);
        }
        first_tx_ = tx0;
        first_tz_ = tz0;
        tiles_wide_ = tx1 - tx0 + 1;
        tiles_deep_ = tz1 - tz0 + 1;
        tile_at_.assign(static_cast<size_t>(tiles_wide_ * tiles_deep_), -1);
        for (size_t k = 0; k < tiles_.size(); ++k) {
            tile_at_[static_cast<size_t>((tiles_[k].tz - tz0) * tiles_wide_ + (tiles_[k].tx - tx0))] = static_cast<int>(k);
        }
    }
    // THE PYRAMID, from the triangles themselves: every square a triangle's bounds touch holds its highest corner,
    // rounded up to a whole metre, so it is never lower than the rock.
    if (!tiles_.empty()) {
        i64 lo = INT64_MAX, hi = INT64_MIN;
        for (const MountainTile& tile : tiles_) {
            lo = std::min({lo, tile.x0 - S, tile.z0 - S});
            hi = std::max({hi, tile.x0 + (T + 1) * S, tile.z0 + (T + 1) * S});
        }
        const i64 square = HeightPyramid::kSquare;
        const i64 origin = floor_div(lo, square) * square;
        const i64 side = floor_div(hi - origin, square) + 1;
        std::vector<std::int16_t> finest(static_cast<size_t>(side * side), HeightPyramid::kNothing);
        for (const MountainTile& tile : tiles_) {
            for (size_t t = 0; t + 2 < tile.indices.size(); t += 3) {
                i64 x0 = INT64_MAX, x1 = INT64_MIN, z0 = INT64_MAX, z1 = INT64_MIN, top = 0;
                for (int c = 0; c < 3; ++c) {
                    const size_t v = static_cast<size_t>(tile.indices[t + c]) * 3;
                    const i64 x = tile.x0 + tile.vertices[v], z = tile.z0 + tile.vertices[v + 2];
                    x0 = std::min(x0, x);
                    x1 = std::max(x1, x);
                    z0 = std::min(z0, z);
                    z1 = std::max(z1, z);
                    top = std::max<i64>(top, tile.vertices[v + 1]);
                }
                const std::int16_t metres = static_cast<std::int16_t>((top + kTicks - 1) / kTicks);
                for (i64 r = floor_div(z0 - origin, square); r <= floor_div(z1 - origin, square); ++r) {
                    for (i64 c = floor_div(x0 - origin, square); c <= floor_div(x1 - origin, square); ++c) {
                        std::int16_t& into = finest[static_cast<size_t>(r * side + c)];
                        into = std::max(into, metres);
                    }
                }
            }
        }
        pyramid_ = HeightPyramid(origin, side, std::move(finest));
    }
    build_usec_ = std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - began).count();
}

void Mountains::vertex_at(i64 i, i64 j, i64& x, i64& z) const {
    const i64 S = tuning_.spacing;
    // Up to a quarter of the spacing each way: a quad's corners can then never cross, so no triangle folds over.
    x = i * S + hash3(i, j, 901) % (S / 2 + 1) - S / 4;
    z = j * S + hash3(i, j, 902) % (S / 2 + 1) - S / 4;
}

i64 Mountains::range_height(size_t r, i64 x, i64 z, int& gully, int& down) const {
    const Ridge& R = ridges_[r];
    const RangeDef& range = ranges_[r];
    gully = 0;
    down = 0;
    if (x < R.x0 || x > R.x1 || z < R.z0 || z > R.z1) return 0;
    // THE NEAREST POINT OF THE RIDGE, in sixteenths of a metre: how far off it, how far along it, and which side.
    i64 d = 0, along = 0, side = 1, crest = 0, foot = 0, turns = -1;
    if (R.x.size() == 1) {
        const i64 dx = x - R.x[0], dz = z - R.z[0];
        const i64 spurs = 5 + hash3(range.salt, 1, 11) % 4;
        d = isqrt((dx * dx + dz * dz) * 256);
        crest = R.crest[0];
        foot = R.foot[0];
        // A LONE MOUNTAIN'S SPURS RADIATE: a whole number of them round it, so the pattern closes on itself.
        turns = bearing(dx, dz) * spurs + ((32768 * noise1((d * ONE) / (300 * 16), range.salt + 7)) >> 16);
    } else {
        i64 best = INT64_MAX;
        const size_t last = R.x.size() - 2;
        for (size_t k = 0; k + 1 < R.x.size(); ++k) {
            const i64 ax = R.x[k], az = R.z[k];
            const i64 dx = R.x[k + 1] - ax, dz = R.z[k + 1] - az;
            const i64 len2 = dx * dx + dz * dz;
            if (len2 == 0) continue;
            const i64 dot = (x - ax) * dx + (z - az) * dz;
            const i64 t = clampi((dot * ONE) / len2, 0, ONE);
            const i64 px = ax * 16 + ((dx * 16 * t) >> 16), pz = az * 16 + ((dz * 16 * t) >> 16);
            const i64 ex = x * 16 - px, ez = z * 16 - pz;
            const i64 dist2 = ex * ex + ez * ez;
            if (dist2 < best) {
                best = dist2;
                const i64 len = isqrt(len2 * 256);
                along = R.along[k] + ((len * t) >> 16);
                // PAST EITHER END the ridge runs on out, so the spur pattern carries round the end, rather than a dome.
                if ((k == 0 && dot < 0) || (k == last && dot > len2)) {
                    const i64 bx = k == 0 ? ax : R.x[k + 1], bz = k == 0 ? az : R.z[k + 1];
                    along += (((x - bx) * dx + (z - bz) * dz) * 256) / len;
                }
                side = dx * (z - az) - dz * (x - ax) > 0 ? 1 : -1;
                crest = R.crest[k] + (((R.crest[k + 1] - R.crest[k]) * t) >> 16);
                foot = R.foot[k] + (((R.foot[k + 1] - R.foot[k]) * t) >> 16);
            }
        }
        d = isqrt(best);
    }
    // THE CREST HERE: the control crest carried up to peaks and down to saddles by the noise along the ridge, and then
    // held inside the envelope. On the ridge line itself this is the height, exactly.
    const i64 n1 = noise1((along * ONE) / (1000 * 16), range.salt);
    const i64 n2 = noise1((along * ONE) / (330 * 16), range.salt + 1);
    // AND A THIRD, SHORTER NOISE, so a crest is a line of summits and notches rather than a smooth ridge (team-lead, the
    // first after pictures: "soft and rounded, like hills").
    const i64 n4 = noise1((along * ONE) / (150 * 16), range.salt + 11);
    const i64 factor = 29491 + ((19661 * n1) >> 16) + ((26214 * ((n1 * n1) >> 16)) >> 16) + ((13107 * n2) >> 16)
        + ((9830 * n4) >> 16);
    i64 c = (crest * kTicks * factor) >> 16;
    c = clampi(c, range.saddle * kTicks, range.peak * kTicks);
    // SPURS AND GULLIES: a wave along the ridge, leaning downhill so a spur runs obliquely off the crest and curving
    // further the lower it runs, its phase wandered by two noises so no two gullies are the same distance apart or run
    // straight, and the two flanks staggered, so a spur on one side faces a gully on the other rather than a mirror of
    // itself. The first build had none of the last three and read as a fishbone (2026-09-18 hillshade).
    const i64 foot16 = std::max<i64>(foot * 16, 1);
    if (turns < 0) {
        const i64 lean = along + side * (((d * 29491) >> 16) + (d * d) / (2 * foot16));
        turns = (lean * ONE) / (R.period * 16) + ((58982 * noise1((lean * ONE) / (800 * 16), range.salt + 2)) >> 16)
            + ((52429 * noise1((d * ONE) / (180 * 16) + (along * ONE) / (650 * 16), range.salt + 5)) >> 16)
            + (side > 0 ? 24248 : 0);
    }
    const i64 g = wave(turns);
    // EACH GULLY ITS OWN DEPTH, from a hash of which gully it is, and a slow noise along the ridge that leaves some flanks
    // nearly whole: a third to all of the full cut. Continuous, because a gully's depth changes only across the spur
    // between two gullies, where nothing is cut.
    const i64 which = hash3(turns >> 16, side, range.salt + 9) & 0xFFFF;
    const i64 flank = noise1((along * ONE) / (1500 * 16), range.salt + 10);
    const i64 depth = 21845 + ((((43691 * which) >> 16) * (32768 + flank / 2)) >> 16);
    // THE FOOT WANDERS: a spur reaches out and a gully bites in, and a slow noise moves both.
    const i64 n3 = noise1((along * ONE) / (500 * 16), range.salt + 6);
    const i64 reach = (foot * 16 * (55706 + g / 4 + ((9830 * (n3 - ONE / 2)) >> 16))) >> 16;
    if (reach <= 0) return 0;
    const i64 u = (d * ONE) / reach;
    if (u >= ONE) return 0;
    // HOW DEEP A GULLY IS CUT: nothing on the upper tenth of the flank, where a gully has not yet gathered enough water
    // to cut anything, then deepening to its most by 45% of the way down -- so the crest stays whole and a gully heads
    // below it rather than notching it.
    const i64 in_gully = (ONE - g) / 2;
    const i64 head = smooth01(clampi(((u - 6554) * ONE) / (29491 - 6554), 0, ONE));
    const i64 cut = (((((((19661 * head) >> 16) * in_gully) >> 16) * in_gully) >> 16) * depth) >> 16;
    // THE PROFILE, crest to foot: (1 - u)^1.5 (1 + 0.6 u) -- a sharp crest, falling at 1.5 crests a foot as it leaves the
    // ridge, and concave where it meets the valley. The first build's (1 - u)^2 (1 + 1.4 u) left the ridge at 0.6 and read
    // as rounded hills.
    const i64 v = ONE - u;
    const i64 v15 = (v * isqrt(v * ONE)) >> 16;
    const i64 profile = std::min(ONE, (v15 * (ONE + ((39322 * u) >> 16))) >> 16);
    // AND LUMPS, so a flank is not a plane: none on the crest, which holds the envelope exactly.
    const i64 lump = ONE + ((((7864 * (noise2(x, z, 160, range.salt + 3) - ONE / 2)) >> 16) * std::min(ONE, 4 * u)) >> 16);
    i64 h = (c * profile) >> 16;
    h = (h * (ONE - cut)) >> 16;
    h = (h * lump) >> 16;
    // CRAGS ON THE TALLEST SUMMITS: where the crest stands in the top quarter of its envelope, the rock near it is broken
    // by a short noise of up to a sixth of its height -- a summit of teeth, not a dome -- fading out by a third of the way
    // down the flank. Held under the peak like everything else by the clamp below.
    const i64 tall = smooth01(clampi(((c - (range.peak * kTicks * 3) / 4) * ONE) / std::max<i64>(range.peak * kTicks / 4, 1),
                                     0, ONE));
    if (tall > 0) {
        const i64 near_crest = smooth01(clampi(ONE - 3 * u, 0, ONE));
        const i64 crag = noise2(x, z, 70, range.salt + 12) - ONE / 2;
        h += (((((c * crag) >> 16) * 21845) >> 16) * ((tall * near_crest) >> 16)) >> 16;
    }
    h = clampi(h, 0, range.peak * kTicks);
    gully = static_cast<int>((((in_gully * std::min(ONE, (u * 5) / 2)) >> 16) * 255) >> 16);
    down = static_cast<int>((u * 255) >> 16);
    return h;
}

i64 Mountains::kept_under(i64 x, i64 z, i64 h) const {
    if (h <= 0 || buckets_.empty()) return h;
    const i64 key = ((floor_div(z, kBucket) + kPositive) << 24) | (floor_div(x, kBucket) + kPositive);
    const auto found = std::lower_bound(buckets_.begin(), buckets_.end(), key,
                                        [](const std::pair<i64, std::vector<int>>& a, i64 k) { return a.first < k; });
    if (found == buckets_.end() || found->first != key) return h;
    for (const int k : found->second) {
        const KeepOut& keep = keepouts_[static_cast<size_t>(k)];
        const i64 dx = std::max<i64>({keep.x0 - x, 0, x - keep.x1});
        const i64 dz = std::max<i64>({keep.z0 - z, 0, z - keep.z1});
        const i64 out = isqrt((dx * dx + dz * dz) * 256);
        const i64 rise_fifths = keep.rise_fifths > 0 ? keep.rise_fifths : kClearRiseNum;
        h = std::min(h, keep.floor_ticks + (out * kTicks * rise_fifths) / (16 * kClearRiseDen));
    }
    return std::max<i64>(h, 0);
}

i64 Mountains::height_ticks(i64 x, i64 z, int* gully, int* down) const {
    i64 best = 0;
    int best_gully = 0, best_down = 0;
    for (size_t r = 0; r < ridges_.size(); ++r) {
        int g = 0, d = 0;
        const i64 h = range_height(r, x, z, g, d);
        if (h > best) {
            best = h;
            best_gully = g;
            best_down = d;
        }
    }
    best = kept_under(x, z, best);
    if (gully) *gully = best_gully;
    if (down) *down = best_down;
    return best;
}

void Mountains::lay_tile(i64 tx, i64 tz) {
    const i64 S = tuning_.spacing;
    const i64 T = tuning_.tile_quads;
    const i64 n = T + 1;
    MountainTile tile;
    tile.tx = tx;
    tile.tz = tz;
    tile.x0 = tx * T * S;
    tile.z0 = tz * T * S;
    tile.grid.resize(static_cast<size_t>(n * n));
    std::vector<i64> xs(static_cast<size_t>(n * n)), zs(static_cast<size_t>(n * n));
    std::vector<int> gullies(static_cast<size_t>(n * n)), downs(static_cast<size_t>(n * n));
    for (i64 b = 0; b < n; ++b) {
        for (i64 a = 0; a < n; ++a) {
            const size_t k = static_cast<size_t>(b * n + a);
            vertex_at(tx * T + a, tz * T + b, xs[k], zs[k]);
            tile.grid[k] = static_cast<std::int32_t>(height_ticks(xs[k], zs[k], &gullies[k], &downs[k]));
        }
    }
    std::vector<std::int32_t> local(static_cast<size_t>(n * n), -1);
    auto use = [&](i64 a, i64 b) -> std::int32_t {
        const size_t k = static_cast<size_t>(b * n + a);
        if (local[k] < 0) {
            local[k] = static_cast<std::int32_t>(tile.vertices.size() / 3);
            tile.vertices.push_back(static_cast<std::int32_t>(xs[k] - tile.x0));
            tile.vertices.push_back(tile.grid[k]);
            tile.vertices.push_back(static_cast<std::int32_t>(zs[k] - tile.z0));
            tile.grit.push_back(static_cast<std::uint8_t>(gullies[k]));
            tile.grit.push_back(static_cast<std::uint8_t>(downs[k]));
        }
        return local[k];
    };
    for (i64 b = 0; b < T; ++b) {
        for (i64 a = 0; a < T; ++a) {
            const i64 ha = tile.grid[static_cast<size_t>(b * n + a)], hb = tile.grid[static_cast<size_t>(b * n + a + 1)];
            const i64 hc = tile.grid[static_cast<size_t>((b + 1) * n + a)];
            const i64 hd = tile.grid[static_cast<size_t>((b + 1) * n + a + 1)];
            if (std::max({ha, hb, hc, hd}) <= 0) continue;
            const std::int32_t va = use(a, b), vb = use(a + 1, b), vc = use(a, b + 1), vd = use(a + 1, b + 1);
            // THE DIAGONAL THAT FOLLOWS THE CREST: the one whose two ends are nearer in height, so a ridge is an edge
            // and not a notch. Clockwise from above, Godot's front face.
            if (absi(ha - hd) < absi(hb - hc)) {
                tile.indices.insert(tile.indices.end(), {va, vd, vc, va, vb, vd});
            } else {
                tile.indices.insert(tile.indices.end(), {va, vb, vc, vb, vd, vc});
            }
        }
    }
    if (tile.indices.empty()) return;
    triangles_ += static_cast<i64>(tile.indices.size() / 3);
    vertex_count_ += static_cast<i64>(tile.vertices.size() / 3);
    mix(hash_, tx);
    mix(hash_, tz);
    for (const std::int32_t v : tile.vertices) mix(hash_, v);
    for (const std::int32_t i : tile.indices) mix(hash_, i);
    tiles_.push_back(std::move(tile));
}

std::int32_t Mountains::grid_height(i64 i, i64 j) const {
    const i64 T = tuning_.tile_quads;
    const i64 tx = floor_div(i, T) - first_tx_, tz = floor_div(j, T) - first_tz_;
    if (tx < 0 || tz < 0 || tx >= tiles_wide_ || tz >= tiles_deep_) return 0;
    const int k = tile_at_[static_cast<size_t>(tz * tiles_wide_ + tx)];
    if (k < 0) return 0;
    const MountainTile& tile = tiles_[static_cast<size_t>(k)];
    return tile.grid[static_cast<size_t>((j - tile.tz * T) * (T + 1) + (i - tile.tx * T))];
}

double Mountains::surface_at(double x, double z) const {
    if (tiles_.empty()) return 0.0;
    const i64 S = tuning_.spacing;
    const i64 i0 = static_cast<i64>(std::floor(x / static_cast<double>(S)));
    const i64 j0 = static_cast<i64>(std::floor(z / static_cast<double>(S)));
    // THE TRIANGLE THE POINT IS IN, among the quads round it -- a vertex moves at most a quarter of the spacing, so the
    // point lies in one of these nine -- split exactly as `lay_tile` splits them, first found in this order.
    for (i64 j = j0 - 1; j <= j0 + 1; ++j) {
        for (i64 i = i0 - 1; i <= i0 + 1; ++i) {
            i64 x_[4], z_[4];
            double h[4];
            const i64 at[4][2] = {{i, j}, {i + 1, j}, {i, j + 1}, {i + 1, j + 1}};
            for (int c = 0; c < 4; ++c) {
                vertex_at(at[c][0], at[c][1], x_[c], z_[c]);
                h[c] = static_cast<double>(grid_height(at[c][0], at[c][1]));
            }
            const bool ad = std::fabs(h[0] - h[3]) < std::fabs(h[1] - h[2]);
            const int tris[2][3] = {{0, ad ? 3 : 1, 2}, {ad ? 0 : 1, ad ? 1 : 3, ad ? 3 : 2}};
            for (const auto& t : tris) {
                const double ax = static_cast<double>(x_[t[0]]), az = static_cast<double>(z_[t[0]]);
                const double bx = static_cast<double>(x_[t[1]]), bz = static_cast<double>(z_[t[1]]);
                const double cx = static_cast<double>(x_[t[2]]), cz = static_cast<double>(z_[t[2]]);
                const double area = (bx - ax) * (cz - az) - (cx - ax) * (bz - az);
                if (area == 0.0) continue;
                const double wb = ((x - ax) * (cz - az) - (cx - ax) * (z - az)) / area;
                const double wc = ((bx - ax) * (z - az) - (x - ax) * (bz - az)) / area;
                const double wa = 1.0 - wb - wc;
                constexpr double kEdge = -1e-9;
                if (wa >= kEdge && wb >= kEdge && wc >= kEdge) {
                    return (wa * h[t[0]] + wb * h[t[1]] + wc * h[t[2]]) / static_cast<double>(kTicks);
                }
            }
        }
    }
    return 0.0;
}

}  // namespace ground
}  // namespace ashiato_gd
