#include "cockpit/ground_core.hpp"

#include <algorithm>

/// See ground_core.hpp for what this is and why it is integers. A change to any line of the function below is a change
/// of world and moves the hashes `cockpit/tests/ground_field.gd` records, in the same commit.

namespace ashiato_gd {
namespace ground {
namespace {

constexpr i64 ONE = 65536;
constexpr i64 M = 1024;
constexpr i64 POSITIVE = i64(1) << 20;
constexpr i64 SEABED = ashiato_gd::ground::kSeabedMetres * M;
constexpr i64 LOWLAND = 110 * M;
constexpr i64 HILLS = 85 * M;
constexpr i64 VALLEY = 75 * M;
constexpr i64 VALLEY_WIDTH = 4600;
/// How far from a valley's centre line its floor is rounded, in the valley noise's Q16: a quarter of its width.
constexpr i64 VALLEY_FLOOR = VALLEY_WIDTH / 4;
constexpr i64 WARP = 2600;
constexpr i64 GX[8] = {65536, 46341, 0, -46341, -65536, -46341, 0, 46341};
constexpr i64 GZ[8] = {0, 46341, 65536, 46341, 0, -46341, -65536, -46341};
constexpr int LAKE_SHIFT = 12;
constexpr int SITE_SHIFT = 12;
/// Seeds step the salt by this, so no two seeds share a salt and seed 0 is the recorded world.
constexpr i64 SEED_STEP = 65536;
/// The peak height, metres, above which the 1,024 m and 512 m ridges stop growing with it: phase 1's tuning, so every
/// world at or under it is the arithmetic phase 1 proved. See the ALPINE note in `base_and_range`.
constexpr i64 kDetailHeight = 1350;
/// How wide a ridge's rounded crest is at the most, as a share of the noise's range in Q16, reached as the peak height
/// grows past kDetailHeight. See the SUMMITS note in `base_and_range`.
constexpr i64 kCreaseSoftness = 26000;

inline i64 shr(i64 x, int s) { return x >> s; }
inline i64 clampi(i64 v, i64 lo, i64 hi) { return std::min(std::max(v, lo), hi); }
inline i64 absi(i64 v) { return v < 0 ? -v : v; }

/// The integer square root, floor, by Newton's method on integers: the same to the bit on every machine.
inline i64 isqrt(i64 v) {
    if (v <= 0) return 0;
    i64 x = v;
    i64 y = (x + 1) / 2;
    while (y < x) {
        x = y;
        y = (x + v / x) / 2;
    }
    return x;
}

inline i64 fade(i64 t) {
    i64 t3 = (((t * t) >> 16) * t) >> 16;
    i64 inner = shr(t * (6 * t - 15 * ONE), 16) + 10 * ONE;
    return (t3 * inner) >> 16;
}

inline i64 smooth(i64 edge0, i64 edge1, i64 x) {
    i64 t = clampi(((x - edge0) * ONE) / (edge1 - edge0), 0, ONE);
    return (((t * t) >> 16) * (3 * ONE - 2 * t)) >> 16;
}

inline i64 site_key(i64 i, i64 j) { return ((i + POSITIVE) << 21) | (j + POSITIVE); }

}  // namespace

Field::Field(const Tuning& tuning) : tuning_(tuning) {
    island_r_ = tuning_.world_half * tuning_.coast / 32;
    mountain_ = tuning_.peak_height * M;
    salt_base_ = tuning_.seed * SEED_STEP;
    pads_ = tuning_.pads;
    rivers_ = tuning_.rivers;
    level_the_pads();
    find_lakes();
    level_the_rivers();
    find_sites();
    file_the_sites();
}

i64 Field::hash3(i64 a, i64 b, i64 salt) const {
    salt += salt_base_;
    i64 h = ((a + POSITIVE) * 374761393 + (b + POSITIVE) * 668265263 + salt * 1103515245) & 0xFFFFFFFFLL;
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFFLL;
    return h ^ (h >> 16);
}

i64 Field::gradient(i64 x, i64 z, int shift, i64 salt) const {
    // EVERY OCTAVE ON ITS OWN LATTICE. Gradient noise is exactly zero at its lattice corners, and every power-of-two
    // lattice has a corner at the origin -- so there every ridged octave stood at its crest at once, the warp was zero,
    // and the highest ground in the alpine world was a 3,110 m needle on (0, 0), rising 8 to 12 m a metre on every side
    // (a probe across both axes, 2026-09-14). Each salt moves its lattice by an odd number of metres, which is never a
    // multiple of any period here.
    x += ((salt * 40503) & 0x3FFF) | 1;
    z += ((salt * 25229) & 0x3FFF) | 1;
    i64 cx = x >> shift;
    i64 cz = z >> shift;
    i64 fx = ((x - cx * (i64(1) << shift)) << 16) >> shift;
    i64 fz = ((z - cz * (i64(1) << shift)) << 16) >> shift;
    i64 gx = fx - ONE;
    i64 gz = fz - ONE;
    i64 g = (hash3(cx, cz, salt) >> 8) & 7;
    i64 n00 = shr(GX[g] * fx + GZ[g] * fz, 16);
    g = (hash3(cx + 1, cz, salt) >> 8) & 7;
    i64 n10 = shr(GX[g] * gx + GZ[g] * fz, 16);
    g = (hash3(cx, cz + 1, salt) >> 8) & 7;
    i64 n01 = shr(GX[g] * fx + GZ[g] * gz, 16);
    g = (hash3(cx + 1, cz + 1, salt) >> 8) & 7;
    i64 n11 = shr(GX[g] * gx + GZ[g] * gz, 16);
    i64 u = fade(fx);
    i64 v = fade(fz);
    i64 a = n00 + shr((n10 - n00) * u, 16);
    i64 b = n01 + shr((n11 - n01) * u, 16);
    return shr((a + shr((b - a) * v, 16)) * 92682, 16);
}

void Field::base_and_range(i64 x, i64 z, i64& height, i64& ranged) const {
    i64 wx = x + shr((gradient(x, z, 13, 11) + shr(gradient(x, z, 12, 13), 1)) * WARP, 16);
    i64 wz = z + shr((gradient(x, z, 13, 12) + shr(gradient(x, z, 12, 14), 1)) * WARP, 16);
    i64 land = ONE - ((wx * wx + wz * wz) * ONE) / (island_r_ * island_r_);
    land += shr(gradient(wx, wz, 14, 21) * 26000, 16);
    land += shr(gradient(wx, wz, 12, 22) * 9000, 16);
    land = clampi(land, -ONE, ONE);
    ranged = 0;
    if (land <= 0) {
        height = shr(land * SEABED, 16);
        return;
    }
    i64 inland = smooth(0, 13000, land);
    i64 h = (smooth(0, ONE, land) * LOWLAND) >> 16;
    // MOUNTAIN RANGES where a slow noise says so, and never on the coast: ridged noise, four octaves, squared.
    ranged = smooth(-6000, 26000, gradient(wx + 9000, wz - 5000, 13, 31) + shr(gradient(wx, wz, 14, 32), 1));
    ranged = (ranged * smooth(8000, 30000, land)) >> 16;
    if (ranged > 0) {
        // ALPINE RANGES KEEP THEIR SMALL RIDGES THE SIZE THEY WERE. The 1,024 m and 512 m ridges scaled with the peak, and
        // at 3,000 m they stood 450 and 260 m tall a kilometre apart: 10.4 % of the land steeper than 60 degrees and a step
        // of 205 m in 16 (alpine_probe, 2026-09-14). Above kDetailHeight they keep the height they have at it, the broad
        // ridges carry the rest, and the sum is renormalised so the tallest ridge still reaches peak_height. At or under
        // kDetailHeight `fine_share` is ONE and this is exactly the phase-1 arithmetic, so its hashes stand.
        const i64 fine_share = tuning_.peak_height <= kDetailHeight ? ONE : (kDetailHeight * ONE) / tuning_.peak_height;
        // AND THEIR SUMMITS ARE NOT NEEDLES. A ridge is ONE - |n|, and |n| has a V at zero, so every ridge top is a crease;
        // squared twice over, a 3,000 m range put spires 100 m across and 600 m tall on it (terrain_300m_plain, 2026-09-14,
        // and the user asked for them blunted). Above kDetailHeight the V is rounded over |n| < `soft`, where |n| becomes
        // (n^2 + soft^2) / (2 soft) -- equal to |n| and to its slope at the edge, so no new crease -- and `soft` grows with
        // how far the peak is above kDetailHeight. At or under it `soft` is 0 and every ridge is `absi`, bit for bit.
        const i64 soft = tuning_.peak_height <= kDetailHeight ? 0 : (kCreaseSoftness * (ONE - fine_share)) >> 16;
        auto crest = [soft](i64 n) -> i64 {
            const i64 a = absi(n);
            return soft <= 0 || a >= soft ? a : (n * n + soft * soft) / (2 * soft);
        };
        // Rounding the crest also lowered it, from ONE to ONE - soft / 2, and the first blunt world's highest ground fell
        // from 2,973 to 2,360 m (the staged probe, 2026-09-14). So a ridge is scaled back up to reach ONE again: a
        // multiply and a divide by the same ONE while `soft` is 0, which is exact.
        const i64 crest_top = ONE - soft / 2;
        auto ridge = [&crest, crest_top](i64 n) -> i64 { return ((ONE - crest(n)) * ONE) / crest_top; };
        i64 r = ridge(gradient(wx, wz, 12, 41));
        i64 broad = (((r * r) >> 16) * 32768) >> 16;
        r = ridge(gradient(wx, wz, 11, 42));
        broad += (((r * r) >> 16) * 17000) >> 16;
        r = ridge(gradient(x, z, 10, 43));
        i64 fine = (((r * r) >> 16) * 10000) >> 16;
        r = ridge(gradient(x, z, 9, 44));
        fine += (((r * r) >> 16) * 5768) >> 16;
        i64 ridges = broad + ((fine * fine_share) >> 16);
        if (fine_share != ONE) {
            ridges = (ridges * ONE) / (49768 + ((15768 * fine_share) >> 16));
        }
        i64 peaky = (ridges * ridges) >> 16;
        h += (((ranged * peaky) >> 16) * mountain_) >> 16;
    }
    // ROLLING LAND everywhere inland, weaker under the ranges.
    i64 hills = gradient(x, z, 11, 51) + shr(gradient(x, z, 10, 52), 1)
        + shr(gradient(x, z, 9, 53) * 9830, 16) + shr(gradient(x, z, 8, 54) * 6554, 16);
    hills = shr(hills * 36000, 16);
    h += shr(shr(hills * HILLS, 16) * ((inland * (ONE - ((ranged * 39000) >> 16))) >> 16), 16);
    // VALLEYS along the zero line of a warped noise, so they meander and cross the ranges as passes.
    //
    // A ROUND FLOOR, NOT A V. The carve is 75 m x (1 - |n|/w)^2, and |n| has a corner at zero, so every valley floor was
    // a crease whose walls stood at up to 73 degrees beside its centre line: too steep for a car or a landing, and
    // painted rock, which a coarse ring of the picture sampled into pale beads from 3 km (report, 8c). Within
    // VALLEY_FLOOR of the centre line |n| is a parabola meeting it with the same slope; beyond it every height is what
    // it was. Lowland under 500 m steeper than 30 degrees went from 10.81 to 10.00 % on the alpine world and from 9.59 to
    // 8.84 % on the 1,350 m one, and the alpine world kept its 7 towns and 13 lakes. Rejected: a smoothstep of the whole
    // profile, which reshaped every valley's sides for no measurable softening (10.81 to 10.85 %) and took 4 of the
    // 1,350 m world's 12 towns and 3 of its 14 lakes.
    const i64 across = gradient(wx - 3000, wz + 11000, 12, 61);
    i64 valley = absi(across);
    if (valley < VALLEY_FLOOR) {
        valley = (across * across + VALLEY_FLOOR * VALLEY_FLOOR) / (2 * VALLEY_FLOOR);
    }
    if (valley < VALLEY_WIDTH) {
        i64 t = ONE - (valley * ONE) / VALLEY_WIDTH;
        h -= (((((t * t) >> 16) * VALLEY) >> 16) * inland) >> 16;
    }
    // DETAIL, a few metres.
    h += shr(shr(gradient(x, z, 8, 71) * 5 * M, 16) * inland, 16);
    h += shr(shr(gradient(x, z, 6, 72) * M, 16) * inland, 16);
    // The land stays land: a valley floor near the coast is kept a metre and a half up.
    height = std::max(h, (smooth(0, 3000, land) * 3 * M) >> 17);
}

i64 Field::base(i64 x, i64 z) const {
    i64 h = 0, ranged = 0;
    base_and_range(x, z, h, ranged);
    return h;
}

// ---- lakes ---------------------------------------------------------------------------------------------------------

const Lake* Field::lake_in_cell(i64 i, i64 j) const {
    if (i < -lake_cells_ || i >= lake_cells_ || j < -lake_cells_ || j >= lake_cells_) {
        return nullptr;
    }
    const int index = lake_grid_[size_t((i + lake_cells_) * (2 * lake_cells_) + (j + lake_cells_))];
    return index < 0 ? nullptr : &lakes_[size_t(index)];
}

void Field::find_lakes() {
    lake_cells_ = (tuning_.world_half >> LAKE_SHIFT) + 1;
    lake_grid_.assign(size_t(4 * lake_cells_ * lake_cells_), -1);
    for (i64 i = -lake_cells_; i < lake_cells_; ++i) {
        for (i64 j = -lake_cells_; j < lake_cells_; ++j) {
            i64 h = hash3(i, j, 901);
            if ((h & 0xFFFF) > 44000) continue;
            i64 cx = i * 4096 + 2048 + ((h >> 16) & 2047) - 1024;
            i64 cz = j * 4096 + 2048 + (hash3(i, j, 902) & 2047) - 1024;
            i64 h0 = 0, ranged = 0;
            base_and_range(cx, cz, h0, ranged);
            if (h0 < 12 * M || h0 > 600 * M || ranged > 30000) continue;
            i64 radius = 300 + (hash3(i, j, 903) % 420);
            i64 low = h0, high = h0;
            const i64 dxs[8] = {radius, -radius, 0, 0, radius, -radius, radius, -radius};
            const i64 dzs[8] = {0, 0, radius, -radius, radius, radius, -radius, -radius};
            for (int k = 0; k < 8; ++k) {
                i64 at = base(cx + dxs[k], cz + dzs[k]);
                low = std::min(low, at);
                high = std::max(high, at);
            }
            if (high - low > 80 * M || low < 7 * M) continue;
            if (!may_place(cx, cz, radius + 180)) continue;
            // THE LEVEL a few metres under the lowest of its shore, on the tick grid, and never down at the sea's.
            i64 level = ((low - 3 * M) >> 5) << 5;
            lake_grid_[size_t((i + lake_cells_) * (2 * lake_cells_) + (j + lake_cells_))] = int(lakes_.size());
            lakes_.push_back(Lake{i, j, cx, cz, radius, (12 + hash3(i, j, 904) % 18) * M, level, 910 + (h & 1023)});
        }
    }
}

i64 Field::water_radius(const Lake& lake) {
    return ((lake.r * 75) >> 6) + 90;
}

i64 Field::apply_lakes(i64 x, i64 z, i64 h) const {
    i64 ci = shr(x, LAKE_SHIFT), cj = shr(z, LAKE_SHIFT);
    for (i64 di = -1; di <= 1; ++di) {
        for (i64 dj = -1; dj <= 1; ++dj) {
            const Lake* lake = lake_in_cell(ci + di, cj + dj);
            if (!lake) continue;
            i64 dx = x - lake->x, dz = z - lake->z;
            i64 d2 = dx * dx + dz * dz;
            i64 wobble = (lake->r * 75) >> 6;
            i64 rim = (wobble + 180) * (wobble + 180);
            if (d2 >= rim) continue;
            i64 r = lake->r;
            i64 level = lake->level;
            // The shore wanders with a 256 m noise, by up to a third of the area.
            i64 shore = (r * r * (ONE + shr(gradient(x, z, 8, lake->salt) * 22000, 16))) >> 16;
            if (d2 < shore) {
                i64 bed = level - ((lake->depth * (ONE - (d2 * ONE) / shore)) >> 16);
                h = std::min(h, bed);
            } else {
                // THE RIM: nothing between the shore and the edge of the drawn water may stand below the level.
                i64 rise = ONE - smooth(wobble * wobble, rim, d2);
                h = std::max(h, level + ((rise * 2 * M) >> 16) + (M >> 4));
            }
        }
    }
    return h;
}

bool Field::near_a_lake(i64 x, i64 z, i64 room) const {
    for (const Lake& lake : lakes_) {
        i64 dx = x - lake.x, dz = z - lake.z, reach = room + lake.r;
        if (dx * dx + dz * dz < reach * reach) return true;
    }
    return false;
}

bool Field::near_a_town(i64 x, i64 z, i64 room) const {
    for (const Town& t : towns_) {
        i64 dx = x - t.x, dz = z - t.z;
        if (dx * dx + dz * dz < room * room) return true;
    }
    return false;
}

// ---- towns and airfields -------------------------------------------------------------------------------------------

void Field::find_sites() {
    i64 cells = (tuning_.world_half >> 12) + 1;
    for (i64 i = -cells; i < cells; ++i) {
        for (i64 j = -cells; j < cells; ++j) {
            i64 cx = i * 4096 + 2048 + (hash3(i, j, 1001) & 2047) - 1024;
            i64 cz = j * 4096 + 2048 + (hash3(i, j, 1002) & 2047) - 1024;
            i64 radius = 380 + hash3(i, j, 1003) % 160;
            if (!may_place(cx, cz, radius + 420)) continue;
            i64 sum = 0, low = i64(1) << 40, high = -(i64(1) << 40);
            i64 in7 = 7 * radius / 10;
            const i64 dxs[9] = {0, radius, -radius, 0, 0, in7, -in7, in7, -in7};
            const i64 dzs[9] = {0, 0, 0, radius, -radius, in7, in7, -in7, -in7};
            for (int k = 0; k < 9; ++k) {
                i64 at = apply_lakes(cx + dxs[k], cz + dzs[k], base(cx + dxs[k], cz + dzs[k]));
                sum += at;
                low = std::min(low, at);
                high = std::max(high, at);
            }
            if (low < 6 * M || high > 450 * M || high - low > 70 * M || near_a_lake(cx, cz, 1200)
                || near_a_town(cx, cz, 6000)) continue;
            towns_.push_back(Town{cx, cz, radius, 420, ((sum / 9) >> 5) << 5});
        }
    }
    // AIRFIELDS: FOUR TO SIX, THE FLATTEST LOWLAND STRIPS THERE ARE, SPREAD OVER THE ISLAND. A strip is 1,800 m by 240 m,
    // along x or z. The first rule -- one candidate a cell of 8 km, taken if flat to 70 m -- found one airfield on the
    // user's alpine world, and they asked for four to six (2026-09-14).
    //
    // EVERY CANDIDATE, THEN THE BEST OF THEM. One per 2,048 m cell, moved up to half a kilometre by the hash, tried along
    // both axes, and sampled on three lines down the strip. It is dropped if any sample is water or below 6 m, or above
    // 450 m, or the strip is near a lake or a town. The rest are sorted flattest first, then lowest -- a metre of relief
    // weighing as twenty of height -- with the order they were found in breaking a tie, so every peer takes the same.
    //
    // TAKEN IN ROUNDS, each looser than the last and run only while fewer than four are taken: the first wants relief
    // under 50 m, 12 km between strips and one strip a region of the square's nine; the second 85 m, 10 km and one a
    // region; the third 120 m, 8 km and two. Each takes up to six. The flattening blend does the rest, so a strip on 120 m
    // of relief is a cutting and an embankment, and the probe says which strips needed one.
    // A LEVEL THAT LAYS ITS OWN AIRPORTS GETS NO STRIPS OF THE GROUND'S: its pads are its airfields.
    if (!pads_.empty()) return;
    struct Candidate {
        i64 x, z, level, relief, score;
        int index;
        bool along_x;
    };
    constexpr size_t kLeastAirfields = 4;
    constexpr size_t kMostAirfields = 6;
    constexpr i64 kCandidateStep = 2048;
    std::vector<Candidate> candidates;
    const i64 half = tuning_.world_half;
    const i64 airfield_cells = half / kCandidateStep + 1;
    int found = 0;
    for (i64 i = -airfield_cells; i < airfield_cells; ++i) {
        for (i64 j = -airfield_cells; j < airfield_cells; ++j) {
            const i64 h = hash3(i, j, 1101);
            const i64 cx = i * kCandidateStep + kCandidateStep / 2 + ((h >> 4) & 1023) - 512;
            const i64 cz = j * kCandidateStep + kCandidateStep / 2 + ((h >> 16) & 1023) - 512;
            if (absi(cx) > half - 2000 || absi(cz) > half - 2000) continue;
            if (near_a_lake(cx, cz, 2200) || near_a_town(cx, cz, 2600)) continue;
            if (!may_place(cx, cz, 900 + 380)) continue;
            for (int heading = 0; heading < 2; ++heading) {
                const bool along_x = heading == 0;
                i64 sum = 0, count = 0, low = i64(1) << 40, high = -(i64(1) << 40);
                for (i64 k = -5; k <= 5; ++k) {
                    for (i64 w = -1; w <= 1; ++w) {
                        const i64 ax = cx + (along_x ? k * 180 : w * 110);
                        const i64 az = cz + (along_x ? w * 110 : k * 180);
                        const i64 at = apply_lakes(ax, az, base(ax, az));
                        sum += at;
                        ++count;
                        low = std::min(low, at);
                        high = std::max(high, at);
                    }
                }
                const i64 relief = high - low;
                if (low < 6 * M || high > 450 * M || relief > 120 * M) continue;
                const i64 level = ((sum / count) >> 5) << 5;
                candidates.push_back(Candidate{cx, cz, level, relief, relief * 20 + level, found++, along_x});
            }
        }
    }
    std::sort(candidates.begin(), candidates.end(), [](const Candidate& a, const Candidate& b) {
        return a.score != b.score ? a.score < b.score : a.index < b.index;
    });
    // [most relief in metres, least spacing in metres, most strips a region]
    constexpr i64 kRounds[3][3] = {{50, 12000, 1}, {85, 10000, 1}, {120, 8000, 2}};
    std::vector<int> in_region(9, 0);
    for (int round = 0; round < 3; ++round) {
        if (round > 0 && airfields_.size() >= kLeastAirfields) break;
        for (const Candidate& c : candidates) {
            if (airfields_.size() >= kMostAirfields) break;
            if (c.relief > kRounds[round][0] * M) continue;
            const i64 rx = clampi((c.x + half) * 3 / (2 * half), 0, 2);
            const i64 rz = clampi((c.z + half) * 3 / (2 * half), 0, 2);
            const size_t region = size_t(rx + 3 * rz);
            if (in_region[region] >= kRounds[round][2]) continue;
            bool crowded = false;
            for (const Strip& other : airfields_) {
                const i64 ox = c.x - other.x, oz = c.z - other.z;
                crowded = crowded || ox * ox + oz * oz < kRounds[round][1] * kRounds[round][1];
            }
            if (crowded) continue;
            airfields_.push_back(Strip{c.x, c.z, c.along_x ? 900 : 120, c.along_x ? 120 : 900, 380, c.level, c.relief});
            ++in_region[region];
        }
    }
}

/// Every site filed in each 4,096 m cell its blend reaches, towns first and then airfields, each in catalogue order --
/// the order `apply_sites` blends them in.
void Field::file_the_sites() {
    auto file = [&](Site site, i64 x0, i64 x1, i64 z0, i64 z1) {
        for (i64 i = shr(x0, SITE_SHIFT); i < shr(x1, SITE_SHIFT) + 1; ++i) {
            for (i64 j = shr(z0, SITE_SHIFT); j < shr(z1, SITE_SHIFT) + 1; ++j) {
                site_cells_[site_key(i, j)].push_back(site);
            }
        }
    };
    for (int t = 0; t < int(towns_.size()); ++t) {
        i64 reach = towns_[t].r + towns_[t].margin;
        file({false, t}, towns_[t].x - reach, towns_[t].x + reach, towns_[t].z - reach, towns_[t].z + reach);
    }
    for (int s = 0; s < int(airfields_.size()); ++s) {
        i64 rx = airfields_[s].half_long + airfields_[s].margin;
        i64 rz = airfields_[s].half_wide + airfields_[s].margin;
        file({true, s}, airfields_[s].x - rx, airfields_[s].x + rx, airfields_[s].z - rz, airfields_[s].z + rz);
    }
}

/// Towns' blends in the order filed, then every airfield's in catalogue order, and nothing where no site reaches.
i64 Field::apply_sites(i64 x, i64 z, i64 h) const {
    auto found = site_cells_.find(site_key(shr(x, SITE_SHIFT), shr(z, SITE_SHIFT)));
    if (found == site_cells_.end()) return h;
    for (const Site& site : found->second) {
        if (site.strip) continue;
        const Town& t = towns_[size_t(site.index)];
        i64 dx = x - t.x, dz = z - t.z;
        i64 outer = t.r + t.margin;
        i64 d2 = dx * dx + dz * dz;
        if (d2 >= outer * outer) continue;
        i64 keep = ONE - smooth(t.r * t.r, outer * outer, d2);
        h += shr((t.level - h) * keep, 16);
    }
    for (const Strip& s : airfields_) {
        i64 ox = std::max(absi(x - s.x) - s.half_long, i64(0));
        i64 oz = std::max(absi(z - s.z) - s.half_wide, i64(0));
        i64 e2 = ox * ox + oz * oz;
        if (e2 >= s.margin * s.margin) continue;
        i64 keep = ONE - smooth(0, s.margin * s.margin, e2);
        h += shr((s.level - h) * keep, 16);
    }
    return h;
}

// ---- pads: the airports a level lays ------------------------------------------------------------------------------

namespace {

/// How far along a funnel and how far across it a point lies, metres.
void along_and_across(const Funnel& f, i64 x, i64 z, i64& along, i64& across) {
    switch (f.dir) {
        case 0: along = x - f.x; across = z - f.z; break;
        case 1: along = z - f.z; across = x - f.x; break;
        case 2: along = f.x - x; across = z - f.z; break;
        default: along = f.z - z; across = x - f.x; break;
    }
}

}  // namespace

/// EACH PAD'S LEVEL: the mean of the ground over it on a 9 by 9 lattice, corners included, before lakes -- which keep
/// clear of every pad -- and on the tick grid, as a strip's is.
void Field::level_the_pads() {
    for (Pad& pad : pads_) {
        i64 sum = 0;
        for (i64 a = 0; a <= 8; ++a) {
            for (i64 b = 0; b <= 8; ++b) {
                sum += base(pad.x0 + (pad.x1 - pad.x0) * a / 8, pad.z0 + (pad.z1 - pad.z0) * b / 8);
            }
        }
        pad.level = ((sum / 81) >> 5) << 5;
    }
}

bool Field::may_place(i64 x, i64 z, i64 room) const {
    const i64 within = tuning_.sites_within;
    if (within > 0 && x * x + z * z > within * within) return false;
    for (const Pad& pad : pads_) {
        const i64 reach = pad.margin + room;
        if (x > pad.x0 - reach && x < pad.x1 + reach && z > pad.z0 - reach && z < pad.z1 + reach) return false;
        for (const Funnel& f : pad.funnels) {
            i64 along = 0, across = 0;
            along_and_across(f, x, z, along, across);
            if (along > -room && along < f.length + kFunnelKeep + room
                && absi(across) < f.half_width + kFunnelKeep + room) {
                return false;
            }
        }
    }
    // AND CLEAR OF EVERY RIVER'S CORRIDOR. A town in a canyon would stand in the water, and an airfield laid across one
    // would flatten the ground the river runs in. A world with no rivers asks nothing here and is unchanged.
    for (const River& river : rivers_) {
        if (river.leg_levels.empty()) continue;
        if (x < river.x0 - room || x > river.x1 + room || z < river.z0 - room || z > river.z1 + room) continue;
        i64 away = 0, level = 0;
        if (nearest_river(x, z, away, level) == &river) return false;
        // The corridor's own edge is as near as `nearest_river` reports, so a site whose reach only just touches it is
        // caught by asking again from the point nearest the line.
        for (size_t k = 0; k + 1 < river.x.size(); ++k) {
            const i64 ax = river.x[k], az = river.z[k];
            const i64 vx = river.x[k + 1] - ax, vz = river.z[k + 1] - az;
            const i64 len2 = vx * vx + vz * vz;
            if (len2 == 0) continue;
            const i64 t = clampi(((x - ax) * vx + (z - az) * vz) * ONE / len2, 0, ONE);
            const i64 dx = x - (ax + shr(vx * t, 16)), dz = z - (az + shr(vz * t, 16));
            const i64 keep = river.corridor + room;
            if (dx * dx + dz * dz < keep * keep) return false;
        }
    }
    return true;
}

/// Every pad, in the order handed in: its level over its rectangle, and outside it the ground held within one metre in
/// kCutSlope of that level by the distance out -- the lower of the ground and a cone above, the higher of it and a cone
/// below. Then every funnel's cap, a cone too: its pad's level plus 1 in 34 along the final, rising 1 in kCutSlope with
/// the distance outside the final's strip. Each only ever takes the lower (or for a pad also the higher) of the ground and
/// a surface no steeper than 1 in 8, so no cut is steeper than the ground was or than that, which tests/ground_field.gd
/// holds on a 16 m grid.
i64 Field::apply_pads(i64 x, i64 z, i64 h) const {
    for (const Pad& pad : pads_) {
        const i64 ox = std::max(std::max(pad.x0 - x, x - pad.x1), i64(0));
        const i64 oz = std::max(std::max(pad.z0 - z, z - pad.z1), i64(0));
        // THE CHEAP BOUND FIRST: the distance out is at least the larger of the two, so ground within that of the level
        // is untouched without a square root -- nearly every sample of the world.
        if (absi(h - pad.level) <= std::max(ox, oz) * M / kCutSlope) continue;
        const i64 allowed = isqrt(ox * ox + oz * oz) * M / kCutSlope;
        h = clampi(h, pad.level - allowed, pad.level + allowed);
    }
    for (const Pad& pad : pads_) {
        if (h <= pad.level) continue;
        for (const Funnel& f : pad.funnels) {
            i64 along = 0, across = 0;
            along_and_across(f, x, z, along, across);
            // THE CONE RUNS BEHIND THE END TOO, so it meets the pad's own without a step where the final begins.
            const i64 on = std::clamp(along, i64(0), f.length);
            const i64 off = absi(along - on);
            const i64 aside = std::max(absi(across) - f.half_width, i64(0));
            const i64 floor = pad.level + on * M / kFunnelSlope;
            if (h <= floor + std::max(off, aside) * M / kCutSlope) continue;
            h = std::min(h, floor + isqrt(off * off + aside * aside) * M / kCutSlope);
        }
    }
    return h;
}

// ---- the answers ---------------------------------------------------------------------------------------------------

// ---- the rivers ------------------------------------------------------------------------------------------------

void Field::level_the_rivers() {
    for (River& river : rivers_) {
        river.leg_levels.clear();
        if (river.x.size() < 2) continue;
        // THE WATER RUNS DOWNHILL AND NEVER UP: the ground at every station along the line, held to the lowest reached
        // so far. A river laid across a rise cuts through it rather than climbing it, which is what a river does; a
        // surface that climbs is the one thing every eye reads as wrong at once.
        bool started = false;
        i64 running = 0;
        for (size_t k = 0; k + 1 < river.x.size(); ++k) {
            const i64 ax = river.x[k], az = river.z[k];
            const i64 bx = river.x[k + 1], bz = river.z[k + 1];
            const i64 span = isqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az));
            const i64 stations = std::max<i64>(span / kRiverStation, 1);
            std::vector<i64> levels;
            levels.reserve(size_t(stations) + 1);
            for (i64 s = 0; s <= stations; ++s) {
                const i64 t = (s * ONE) / stations;
                const i64 px = ax + shr((bx - ax) * t, 16);
                const i64 pz = az + shr((bz - az) * t, 16);
                const i64 ground = apply_sites(px, pz, apply_lakes(px, pz, base(px, pz)));
                running = started ? std::min(running, ground) : ground;
                started = true;
                levels.push_back(running);
            }
            river.leg_levels.push_back(std::move(levels));
        }
        const i64 reach = river.corridor + 1;
        river.x0 = river.x[0];
        river.x1 = river.x[0];
        river.z0 = river.z[0];
        river.z1 = river.z[0];
        for (size_t k = 1; k < river.x.size(); ++k) {
            river.x0 = std::min(river.x0, river.x[k]);
            river.x1 = std::max(river.x1, river.x[k]);
            river.z0 = std::min(river.z0, river.z[k]);
            river.z1 = std::max(river.z1, river.z[k]);
        }
        river.x0 -= reach;
        river.x1 += reach;
        river.z0 -= reach;
        river.z1 += reach;
    }
}

const River* Field::nearest_river(i64 x, i64 z, i64& away, i64& level) const {
    const River* found = nullptr;
    i64 best2 = -1;
    for (const River& river : rivers_) {
        if (river.leg_levels.empty()) continue;
        if (x < river.x0 || x > river.x1 || z < river.z0 || z > river.z1) continue;
        for (size_t k = 0; k + 1 < river.x.size(); ++k) {
            const i64 ax = river.x[k], az = river.z[k];
            const i64 vx = river.x[k + 1] - ax, vz = river.z[k + 1] - az;
            const i64 len2 = vx * vx + vz * vz;
            if (len2 == 0) continue;
            // WHERE ALONG THIS LEG THE POINT FALLS, Q16, clamped to its ends so a point off the end of the line
            // measures to that end rather than to the line the leg lies on.
            i64 t = clampi(((x - ax) * vx + (z - az) * vz) * ONE / len2, 0, ONE);
            const i64 px = ax + shr(vx * t, 16);
            const i64 pz = az + shr(vz * t, 16);
            const i64 dx = x - px, dz = z - pz;
            const i64 d2 = dx * dx + dz * dz;
            if (d2 >= river.corridor * river.corridor) continue;
            if (best2 >= 0 && d2 >= best2) continue;
            best2 = d2;
            found = &river;
            // THE WATER'S LEVEL AT THIS POINT ALONG THIS LEG, off the leg's own stations: `t` picks the pair either
            // side and the level is read between them, so the surface follows the ground rather than the chord.
            const std::vector<i64>& levels = river.leg_levels[k];
            const i64 last = i64(levels.size()) - 1;
            const i64 along = (t * last) >> 16;
            const i64 s0 = clampi(along, 0, last);
            const i64 s1 = clampi(along + 1, 0, last);
            const i64 into = (t * last) - (s0 << 16);
            level = levels[size_t(s0)] + shr((levels[size_t(s1)] - levels[size_t(s0)]) * clampi(into, 0, ONE), 16);
        }
    }
    if (found) away = isqrt(best2);
    return found;
}

i64 Field::apply_rivers(i64 x, i64 z, i64 h) const {
    i64 away = 0, level = 0;
    const River* river = nearest_river(x, z, away, level);
    if (!river) return h;
    const i64 bed = level - river->draught * M;
    const i64 half = river->width / 2;
    if (away <= half) return std::min(h, bed);
    // THE BANK, from the water's edge to the corridor's: the bed rises out of the water and kRiverBank metres over it,
    // so the water sits in something. Past the corridor nothing is cut -- the canyon's walls are the level's own
    // ranges, and cutting there too would fight them.
    const i64 t = ((away - half) * ONE) / std::max(river->corridor - half, i64(1));
    const i64 rise = shr(smooth(0, ONE, t) * (river->draught + kRiverBank) * M, 16);
    return std::min(h, bed + rise);
}

i64 Field::height_ticks(i64 x, i64 z) const {
    i64 h = apply_lakes(x, z, base(x, z));
    if (!rivers_.empty()) h = apply_rivers(x, z, h);
    h = apply_sites(x, z, h);
    return shr(pads_.empty() ? h : apply_pads(x, z, h), 5);
}

i64 Field::water_ticks(i64 x, i64 z) const {
    i64 ground = height_ticks(x, z);
    // A RIVER'S OWN SURFACE, over the bed it was cut into: the same search the carve used, so the water and the bed
    // cannot disagree about where the river is.
    if (!rivers_.empty()) {
        i64 away = 0, level = 0;
        const River* river = nearest_river(x, z, away, level);
        if (river && away <= river->width / 2 && ground < (level >> 5)) return level >> 5;
    }
    i64 ci = shr(x, LAKE_SHIFT), cj = shr(z, LAKE_SHIFT);
    for (i64 di = -1; di <= 1; ++di) {
        for (i64 dj = -1; dj <= 1; ++dj) {
            const Lake* lake = lake_in_cell(ci + di, cj + dj);
            if (!lake) continue;
            i64 dx = x - lake->x, dz = z - lake->z;
            i64 radius = water_radius(*lake);
            if (dx * dx + dz * dz < radius * radius && ground < (lake->level >> 5)) return lake->level >> 5;
        }
    }
    return ground < 0 ? 0 : kNoWater;
}

}  // namespace ground
}  // namespace ashiato_gd
