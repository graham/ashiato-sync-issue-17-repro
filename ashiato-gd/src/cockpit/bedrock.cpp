#include "cockpit/bedrock.hpp"

#include <algorithm>
#include <chrono>
#include <climits>
#include <cmath>

/// See bedrock.hpp for what this is, and why a field's range is exactly 65,535 ticks.

namespace ashiato_gd {
namespace ground {
namespace {

inline i64 clamp_index(i64 v, i64 lo, i64 hi) { return std::min(std::max(v, lo), hi); }

/// Ticks to whole metres, rounded up, for a negative height as well as a positive one.
inline i64 metres_up(i64 ticks) {
    return ticks >= 0 ? (ticks + kTicksPerMetre - 1) / kTicksPerMetre : -((-ticks) / kTicksPerMetre);
}

}  // namespace

Bedrock::Bedrock(const Field& field, b3WorldId world) : field_(field), world_(world) {
    const auto began = std::chrono::steady_clock::now();
    cells_ = 2 * ((field_.tuning().world_half + kCell - 1) / kCell);
    origin_ = -(cells_ / 2) * kCell;
    const i64 per_cell = kCell / kSpacing;
    const i64 columns = cells_ * per_cell + 1;
    const i64 squares_a_cell = kCell / kPyramidSquare;
    const i64 squares = cells_ * squares_a_cell;
    std::vector<std::int16_t> finest(static_cast<size_t>(squares * squares), INT16_MIN);

    // A BAND OF ONE CELL ROW AT A TIME, its 65 sample rows: a megabyte, where the whole square's samples at once would
    // be sixty-seven. Every field of the row and every pyramid square in it is laid from the same samples.
    std::vector<std::int32_t> band(static_cast<size_t>((per_cell + 1) * columns));
    for (i64 row = 0; row < cells_; ++row) {
        const i64 z0 = origin_ + row * kCell;
        for (i64 r = 0; r <= per_cell; ++r) {
            for (i64 c = 0; c < columns; ++c) {
                band[static_cast<size_t>(r * columns + c)] =
                    static_cast<std::int32_t>(field_.height_ticks(origin_ + c * kSpacing, z0 + r * kSpacing));
            }
        }
        for (i64 column = 0; column < cells_; ++column) {
            lay_cell(band, columns, column * per_cell, origin_ + column * kCell, z0);
        }
        for (i64 sr = 0; sr < squares_a_cell; ++sr) {
            for (i64 sc = 0; sc < squares; ++sc) {
                std::int32_t top = INT32_MIN;
                for (i64 dr = 0; dr <= 2; ++dr) {
                    for (i64 dc = 0; dc <= 2; ++dc) {
                        top = std::max(top, band[static_cast<size_t>((2 * sr + dr) * columns + 2 * sc + dc)]);
                    }
                }
                finest[static_cast<size_t>((row * squares_a_cell + sr) * squares + sc)] =
                    static_cast<std::int16_t>(clamp_index(metres_up(top), INT16_MIN, INT16_MAX));
            }
        }
    }
    heights_.clear();
    heights_.shrink_to_fit();

    pyramid_ = HeightPyramid(origin_, squares, std::move(finest));
    build_usec_ = std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - began).count();
}

Bedrock::~Bedrock() {
    if (b3World_IsValid(world_)) {
        for (const b3BodyId body : bodies_) {
            b3DestroyBody(body);
        }
    }
    for (b3HeightFieldData* data : data_) {
        b3DestroyHeightField(data);
    }
}

void Bedrock::lay_cell(const std::vector<std::int32_t>& band, i64 columns, i64 first_column, i64 x0, i64 z0) {
    const i64 span = kCell / kSpacing;
    std::int32_t low = INT32_MAX, high = INT32_MIN;
    for (i64 r = 0; r <= span; ++r) {
        for (i64 c = 0; c <= span; ++c) {
            const std::int32_t at = band[static_cast<size_t>(r * columns + first_column + c)];
            low = std::min(low, at);
            high = std::max(high, at);
        }
    }
    if (high <= kSeaFloorTicks) {
        return;
    }
    ++land_cells_;
    const i64 before = fields();
    lay_region(band, columns, first_column, 0, span, x0, z0);
    split_cells_ += fields() - before > 1 ? 1 : 0;
}

void Bedrock::lay_region(const std::vector<std::int32_t>& band, i64 columns, i64 first_column, i64 first_row, i64 span,
                         i64 x0, i64 z0) {
    std::int32_t low = INT32_MAX, high = INT32_MIN;
    for (i64 r = 0; r <= span; ++r) {
        for (i64 c = 0; c <= span; ++c) {
            const std::int32_t at = band[static_cast<size_t>((first_row + r) * columns + first_column + c)];
            low = std::min(low, at);
            high = std::max(high, at);
        }
    }
    if (static_cast<i64>(high) - low <= kFieldRangeTicks || span <= kSmallestSpan) {
        lay_field(band, columns, first_column, first_row, span, x0, z0);
        return;
    }
    // FOUR OF HALF THE SIZE, along z then along x, the same order on every peer.
    const i64 half = span / 2;
    for (i64 qr = 0; qr < 2; ++qr) {
        for (i64 qc = 0; qc < 2; ++qc) {
            lay_region(band, columns, first_column + qc * half, first_row + qr * half, half,
                       x0 + qc * half * kSpacing, z0 + qr * half * kSpacing);
        }
    }
}

void Bedrock::lay_field(const std::vector<std::int32_t>& band, i64 columns, i64 first_column, i64 first_row, i64 span,
                        i64 x0, i64 z0) {
    const i64 count = span + 1;
    heights_.resize(static_cast<size_t>(count * count));
    std::int32_t low = INT32_MAX, high = INT32_MIN;
    for (i64 r = 0; r < count; ++r) {
        for (i64 c = 0; c < count; ++c) {
            const std::int32_t at = band[static_cast<size_t>((first_row + r) * columns + first_column + c)];
            low = std::min(low, at);
            high = std::max(high, at);
            // Row by row along z, each row along x: Box3D's `row * columnCount + column`.
            heights_[static_cast<size_t>(r * count + c)] = static_cast<float>(at) / static_cast<float>(kTicksPerMetre);
        }
    }
    if (static_cast<i64>(high) - low > kFieldRangeTicks) {
        ++unheld_fields_;
    }
    b3HeightFieldDef def{};
    def.heights = heights_.data();
    def.materialIndices = nullptr;
    def.scale = b3Vec3{static_cast<float>(kSpacing), 1.0f, static_cast<float>(kSpacing)};
    def.countX = static_cast<int>(count);
    def.countZ = static_cast<int>(count);
    def.globalMinimumHeight = static_cast<float>(low) / static_cast<float>(kTicksPerMetre);
    def.globalMaximumHeight = static_cast<float>(low + kFieldRangeTicks) / static_cast<float>(kTicksPerMetre);
    def.clockwiseWinding = false;
    b3HeightFieldData* data = b3CreateHeightField(&def);

    b3BodyDef body_def = b3DefaultBodyDef();
    body_def.type = b3_staticBody;
    body_def.position.x = static_cast<decltype(body_def.position.x)>(x0);
    body_def.position.y = 0;
    body_def.position.z = static_cast<decltype(body_def.position.z)>(z0);
    const b3BodyId body = b3CreateBody(world_, &body_def);
    b3ShapeDef shape = b3DefaultShapeDef();
    // NO SPECULATIVE CONTACT WITH THE GROUND'S TRIANGLES (lane/testfield, 2026-09-19). A field is one 1,024 m cell, and a
    // hull box taxiing across the edge two fields share met a ghost contact there, side-on: every craft that taxied on the
    // generated ground was destroyed "struck its nose first at 4.1 m/s" as its nose reached a multiple of 1,024 m, and
    // held still it lost nothing in 60 s. Box3D's own words for this switch: "Leave this true unless you care about
    // reducing ghost collision more than continuous collision under rotation."
    shape.enableSpeculativeContact = false;
    b3CreateHeightFieldShape(body, &shape, data);

    data_.push_back(data);
    bodies_.push_back(body);
    bytes_ += data->byteCount;
    hash_ = (hash_ ^ data->hash) * 1099511628211ull;
}

float Bedrock::height_at(double x, double z) const {
    const double gx = x / static_cast<double>(kSpacing);
    const double gz = z / static_cast<double>(kSpacing);
    const double fx = std::floor(gx);
    const double fz = std::floor(gz);
    const i64 i = static_cast<i64>(fx);
    const i64 j = static_cast<i64>(fz);
    const double u = gx - fx;
    const double v = gz - fz;
    const double h11 = static_cast<double>(field_.height_ticks(i * kSpacing, j * kSpacing));
    const double h12 = static_cast<double>(field_.height_ticks((i + 1) * kSpacing, j * kSpacing));
    const double h21 = static_cast<double>(field_.height_ticks(i * kSpacing, (j + 1) * kSpacing));
    const double h22 = static_cast<double>(field_.height_ticks((i + 1) * kSpacing, (j + 1) * kSpacing));
    // The first triangle is (x, z), (x, z + 16), (x + 16, z); the second the rest of the square.
    const double ticks = u + v <= 1.0 ? h11 + u * (h12 - h11) + v * (h21 - h11)
                                      : h22 + (1.0 - u) * (h21 - h22) + (1.0 - v) * (h12 - h22);
    return static_cast<float>(ticks / static_cast<double>(kTicksPerMetre));
}

bool Bedrock::water_at(double x, double z, float& level) const {
    const i64 ticks = field_.water_ticks(static_cast<i64>(std::llround(x)), static_cast<i64>(std::llround(z)));
    if (ticks <= kNoWater) {
        return false;
    }
    level = static_cast<float>(ticks) / static_cast<float>(kTicksPerMetre);
    return true;
}

float Bedrock::highest_over(double x0, double z0, double x1, double z1) const {
    return pyramid_.highest_over(x0, z0, x1, z1);
}

bool Bedrock::clear_between(const b3Vec3& a, const b3Vec3& b, float clearance, float overhead) const {
    return pyramid_.clear_between(a, b, clearance, overhead);
}

}  // namespace ground
}  // namespace ashiato_gd
