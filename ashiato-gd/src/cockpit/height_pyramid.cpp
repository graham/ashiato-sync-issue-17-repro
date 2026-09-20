#include "cockpit/height_pyramid.hpp"

#include <algorithm>
#include <climits>
#include <cmath>

/// See height_pyramid.hpp. Moved here from bedrock.cpp line for line (2026-09-18); the generated ground's leg tests ask
/// exactly what they asked before, and `cockpit/tests/ground_collision.gd` still holds them to the drawn surface.

namespace ashiato_gd {
namespace ground {
namespace {

/// How many times a leg is halved at most. A 70 km leg is 32 m after 12; the guard is for a leg nobody should ask.
constexpr int kDeepest = 24;

inline std::int64_t clamp_index(std::int64_t v, std::int64_t lo, std::int64_t hi) { return std::min(std::max(v, lo), hi); }

}  // namespace

HeightPyramid::HeightPyramid(std::int64_t origin, std::int64_t side, std::vector<std::int16_t> finest) : origin_(origin) {
    levels_.push_back(std::move(finest));
    sides_.push_back(side);
    while (sides_.back() > 1) {
        const std::int64_t below_side = sides_.back();
        const std::int64_t up = (below_side + 1) / 2;
        std::vector<std::int16_t> next(static_cast<size_t>(up * up), kNothing);
        const std::vector<std::int16_t>& below = levels_.back();
        for (std::int64_t r = 0; r < below_side; ++r) {
            for (std::int64_t c = 0; c < below_side; ++c) {
                std::int16_t& into = next[static_cast<size_t>((r / 2) * up + c / 2)];
                into = std::max(into, below[static_cast<size_t>(r * below_side + c)]);
            }
        }
        levels_.push_back(std::move(next));
        sides_.push_back(up);
    }
}

std::int64_t HeightPyramid::bytes() const {
    std::int64_t total = 0;
    for (const std::vector<std::int16_t>& level : levels_) {
        total += static_cast<std::int64_t>(level.size() * sizeof(std::int16_t));
    }
    return total;
}

float HeightPyramid::highest_over(double x0, double z0, double x1, double z1) const {
    if (levels_.empty()) {
        return static_cast<float>(kNothing);
    }
    const std::int64_t side = sides_[0];
    auto square = [this, side](double at) {
        return clamp_index(static_cast<std::int64_t>(std::floor((at - static_cast<double>(origin_)) / kSquare)), 0,
                           side - 1);
    };
    const std::int64_t c0 = square(std::min(x0, x1)), c1 = square(std::max(x0, x1));
    const std::int64_t r0 = square(std::min(z0, z1)), r1 = square(std::max(z0, z1));
    // The finest level at which the rectangle is at most two squares a side: four lookups whatever its size.
    size_t k = 0;
    while (k + 1 < levels_.size() && ((c1 >> k) - (c0 >> k) > 1 || (r1 >> k) - (r0 >> k) > 1)) {
        ++k;
    }
    const std::int64_t s = sides_[k];
    const std::vector<std::int16_t>& level = levels_[k];
    std::int16_t top = kNothing;
    for (std::int64_t r = r0 >> k; r <= (r1 >> k); ++r) {
        for (std::int64_t c = c0 >> k; c <= (c1 >> k); ++c) {
            top = std::max(top, level[static_cast<size_t>(r * s + c)]);
        }
    }
    return static_cast<float>(top);
}

float HeightPyramid::highest_within(double x0, double z0, double x1, double z1) const {
    if (levels_.empty()) {
        return static_cast<float>(kNothing);
    }
    const std::int64_t side = sides_[0];
    auto square = [this, side](double at) {
        return clamp_index(static_cast<std::int64_t>(std::floor((at - static_cast<double>(origin_)) / kSquare)), 0,
                           side - 1);
    };
    const std::int64_t c0 = square(std::min(x0, x1)), c1 = square(std::max(x0, x1));
    const std::int64_t r0 = square(std::min(z0, z1)), r1 = square(std::max(z0, z1));
    std::int16_t top = kNothing;
    for (std::int64_t r = r0; r <= r1; ++r) {
        for (std::int64_t c = c0; c <= c1; ++c) {
            top = std::max(top, levels_[0][static_cast<size_t>(r * side + c)]);
        }
    }
    return static_cast<float>(top);
}

bool HeightPyramid::clear_between(const b3Vec3& a, const b3Vec3& b, float clearance, float overhead) const {
    return levels_.empty() || piece_is_clear(a, b, clearance, std::min(overhead, clearance), 0);
}

bool HeightPyramid::piece_is_clear(const b3Vec3& a, const b3Vec3& b, float clearance, float lift, int depth) const {
    const float floor_of_leg = std::min(a.y, b.y);
    const float top = highest_over(static_cast<double>(std::min(a.x, b.x)) - clearance,
                                   static_cast<double>(std::min(a.z, b.z)) - clearance,
                                   static_cast<double>(std::max(a.x, b.x)) + clearance,
                                   static_cast<double>(std::max(a.z, b.z)) + clearance);
    if (top + lift < floor_of_leg) {
        return true;
    }
    const float dx = b.x - a.x;
    const float dz = b.z - a.z;
    const float finest = static_cast<float>(kSquare);
    if (dx * dx + dz * dz <= finest * finest || depth >= kDeepest) {
        return false;
    }
    const b3Vec3 mid{(a.x + b.x) * 0.5f, (a.y + b.y) * 0.5f, (a.z + b.z) * 0.5f};
    return piece_is_clear(a, mid, clearance, lift, depth + 1) && piece_is_clear(mid, b, clearance, lift, depth + 1);
}

}  // namespace ground
}  // namespace ashiato_gd
