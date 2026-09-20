#include "cockpit/mountain_range.hpp"

#include <algorithm>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector2i.hpp>

/// The binding only. The mountains are `range_core.cpp`; see `mountain_range.hpp`.

using namespace godot;

namespace ashiato_gd {
namespace {

/// What each number is held to. Coordinates stay inside the wire's ground range; heights inside what a float32 holds
/// in ticks with room, and what the pyramid's int16 metres hold.
constexpr int64_t kEdge = 32768;
constexpr int64_t kTallest = 8000;

bool read_int(const Dictionary& from, const char* key, int64_t least, int64_t most, int64_t& into,
              PackedStringArray& problems, bool& whole, const String& where) {
    if (!from.has(key)) {
        problems.push_back(where + String("missing key ") + key);
        whole = false;
        return false;
    }
    const Variant value = from[key];
    if (value.get_type() != Variant::INT) {
        problems.push_back(where + String(key) + " is not an int");
        whole = false;
        return false;
    }
    const int64_t asked = value;
    into = std::min(std::max(asked, least), most);
    if (into != asked) {
        problems.push_back(where + String(key) + " " + String::num_int64(asked) + " clamped to " + String::num_int64(into));
    }
    return true;
}

}  // namespace

PackedStringArray MountainRange::configure(const Dictionary& values) {
    PackedStringArray problems;
    bool whole = true;
    const char* known[] = {"spacing", "tile_quads", "ranges", "keepouts", "keepout_margins", "keepout_rises"};
    Array keys = values.keys();
    for (int64_t k = 0; k < keys.size(); ++k) {
        const String key = keys[k];
        bool found = false;
        for (const char* name : known) found = found || key == String(name);
        if (!found) problems.push_back("unknown key " + key);
    }
    ground::MountainTuning tuning;
    read_int(values, "spacing", 16, 256, tuning.spacing, problems, whole, "");
    read_int(values, "tile_quads", 8, 128, tuning.tile_quads, problems, whole, "");
    std::vector<ground::RangeDef> ranges;
    if (!values.has("ranges") || values["ranges"].get_type() != Variant::ARRAY) {
        problems.push_back("ranges is missing or not an Array");
        whole = false;
    } else {
        const Array list = values["ranges"];
        for (int64_t r = 0; r < list.size(); ++r) {
            const String where = "range " + String::num_int64(r) + ": ";
            if (list[r].get_type() != Variant::DICTIONARY) {
                problems.push_back(where + String("not a Dictionary"));
                whole = false;
                continue;
            }
            const Dictionary one = list[r];
            ground::RangeDef range;
            read_int(one, "salt", 0, 1 << 20, range.salt, problems, whole, where);
            read_int(one, "peak", 1, kTallest, range.peak, problems, whole, where);
            read_int(one, "saddle", 0, kTallest, range.saddle, problems, whole, where);
            if (range.saddle > range.peak) {
                problems.push_back(where + String("saddle ") + String::num_int64(range.saddle) + " above peak "
                                   + String::num_int64(range.peak));
                whole = false;
            }
            if (!one.has("points") || one["points"].get_type() != Variant::PACKED_INT32_ARRAY) {
                problems.push_back(where + String("points is missing or not a PackedInt32Array"));
                whole = false;
                continue;
            }
            const PackedInt32Array points = one["points"];
            if (points.size() < 4 || points.size() % 4 != 0) {
                problems.push_back(where + String("points is not four ints a point"));
                whole = false;
                continue;
            }
            for (int64_t p = 0; p + 3 < points.size(); p += 4) {
                ground::RangePoint point;
                point.x = std::min<int64_t>(std::max<int64_t>(points[p], -kEdge), kEdge);
                point.z = std::min<int64_t>(std::max<int64_t>(points[p + 1], -kEdge), kEdge);
                point.crest = std::min<int64_t>(std::max<int64_t>(points[p + 2], 0), kTallest);
                point.foot = std::min<int64_t>(std::max<int64_t>(points[p + 3], 16), 8000);
                if (point.x != points[p] || point.z != points[p + 1] || point.crest != points[p + 2]
                    || point.foot != points[p + 3]) {
                    problems.push_back(where + String("point ") + String::num_int64(p / 4) + " clamped");
                }
                range.points.push_back(point);
            }
            ranges.push_back(std::move(range));
        }
    }
    std::vector<ground::KeepOut> keepouts;
    if (!values.has("keepouts") || values["keepouts"].get_type() != Variant::PACKED_INT32_ARRAY) {
        problems.push_back("keepouts is missing or not a PackedInt32Array");
        whole = false;
    } else {
        const PackedInt32Array list = values["keepouts"];
        if (list.size() % 5 != 0) {
            problems.push_back("keepouts is not five ints a keep-out");
            whole = false;
        }
        for (int64_t k = 0; k + 4 < list.size(); k += 5) {
            ground::KeepOut keep;
            keep.x0 = std::min(list[k], list[k + 2]);
            keep.x1 = std::max(list[k], list[k + 2]);
            keep.z0 = std::min(list[k + 1], list[k + 3]);
            keep.z1 = std::max(list[k + 1], list[k + 3]);
            keep.floor_ticks = list[k + 4];
            keepouts.push_back(keep);
        }
        // OPTIONAL: whole metres a keep-out is grown by, one per keep-out and the same number of them, a negative meaning the
        // default. The caller builds both lists in one loop; a length that differs is a bug in it, said so and not made good
        // by defaulting the tail, because a margin on the wrong keep-out is a runway approach given a railway's.
        if (values.has("keepout_margins")) {
            if (values["keepout_margins"].get_type() != Variant::PACKED_INT32_ARRAY) {
                problems.push_back("keepout_margins is not a PackedInt32Array");
                whole = false;
            } else {
                const PackedInt32Array margins = values["keepout_margins"];
                if (margins.size() != static_cast<int64_t>(keepouts.size())) {
                    problems.push_back("keepout_margins has " + String::num_int64(margins.size()) + " entries for "
                                       + String::num_int64(static_cast<int64_t>(keepouts.size())) + " keepouts");
                    whole = false;
                } else {
                    for (int64_t k = 0; k < margins.size(); ++k) keepouts[static_cast<size_t>(k)].margin = margins[k];
                }
            }
        }
        // OPTIONAL, the same shape: fifths of a metre a metre each keep-out lets rock climb, zero or less for the default (6, six fifths).
        if (values.has("keepout_rises")) {
            if (values["keepout_rises"].get_type() != Variant::PACKED_INT32_ARRAY) {
                problems.push_back("keepout_rises is not a PackedInt32Array");
                whole = false;
            } else {
                const PackedInt32Array rises = values["keepout_rises"];
                if (rises.size() != static_cast<int64_t>(keepouts.size())) {
                    problems.push_back("keepout_rises has " + String::num_int64(rises.size()) + " entries for "
                                       + String::num_int64(static_cast<int64_t>(keepouts.size())) + " keepouts");
                    whole = false;
                } else {
                    for (int64_t k = 0; k < rises.size(); ++k) keepouts[static_cast<size_t>(k)].rise_fifths = rises[k];
                }
            }
        }
    }
    for (int64_t p = 0; p < problems.size(); ++p) {
        UtilityFunctions::push_warning("[MountainRange] ", problems[p]);
    }
    if (whole) {
        mountains_ = std::make_shared<const ground::Mountains>(tuning, std::move(ranges), std::move(keepouts));
    } else {
        mountains_.reset();
    }
    return problems;
}

bool MountainRange::is_configured() const {
    return mountains_ != nullptr;
}

bool MountainRange::asked_unconfigured() const {
    if (mountains_) return false;
    UtilityFunctions::push_error("[MountainRange] asked about the mountains before configure() succeeded");
    return true;
}

int64_t MountainRange::tile_count() const {
    return asked_unconfigured() ? 0 : static_cast<int64_t>(mountains_->tiles().size());
}

Dictionary MountainRange::tile(int64_t index) const {
    Dictionary out;
    if (asked_unconfigured()) return out;
    if (index < 0 || index >= static_cast<int64_t>(mountains_->tiles().size())) {
        UtilityFunctions::push_error("[MountainRange] no tile ", index);
        return out;
    }
    const ground::MountainTile& tile = mountains_->tiles()[static_cast<size_t>(index)];
    const size_t count = tile.vertices.size() / 3;
    PackedVector3Array vertices;
    vertices.resize(static_cast<int64_t>(count));
    Vector3* write = vertices.ptrw();
    for (size_t v = 0; v < count; ++v) {
        // The same float32 arithmetic `Massif` hands Box3D: whole metres, and ticks over 32 -- exact.
        write[v] = Vector3(static_cast<float>(tile.vertices[3 * v]),
                           static_cast<float>(tile.vertices[3 * v + 1]) / static_cast<float>(ground::Mountains::kTicks),
                           static_cast<float>(tile.vertices[3 * v + 2]));
    }
    PackedInt32Array indices;
    indices.resize(static_cast<int64_t>(tile.indices.size()));
    std::copy(tile.indices.begin(), tile.indices.end(), indices.ptrw());
    PackedByteArray grit;
    grit.resize(static_cast<int64_t>(tile.grit.size()));
    std::copy(tile.grit.begin(), tile.grit.end(), grit.ptrw());
    out["origin"] = Vector2i(static_cast<int32_t>(tile.x0), static_cast<int32_t>(tile.z0));
    out["vertices"] = vertices;
    out["indices"] = indices;
    out["grit"] = grit;
    return out;
}

int64_t MountainRange::height_ticks_at(int64_t x, int64_t z) const {
    return asked_unconfigured() ? 0 : mountains_->height_ticks(x, z);
}

double MountainRange::surface_at(double x, double z) const {
    return asked_unconfigured() ? 0.0 : mountains_->surface_at(x, z);
}

PackedFloat32Array MountainRange::surfaces_at(const PackedVector2Array& points) const {
    PackedFloat32Array out;
    if (asked_unconfigured()) return out;
    out.resize(points.size());
    float* write = out.ptrw();
    for (int64_t k = 0; k < points.size(); ++k) {
        write[k] = static_cast<float>(mountains_->surface_at(points[k].x, points[k].y));
    }
    return out;
}

double MountainRange::highest_over(double x0, double z0, double x1, double z1) const {
    if (asked_unconfigured()) return 0.0;
    return std::max(0.0, static_cast<double>(mountains_->pyramid().highest_within(x0, z0, x1, z1)));
}

Dictionary MountainRange::report() const {
    Dictionary out;
    if (!mountains_) return out;
    out["tiles"] = static_cast<int64_t>(mountains_->tiles().size());
    out["triangles"] = mountains_->triangles();
    out["vertices"] = mountains_->vertex_count();
    out["build_usec"] = mountains_->build_usec();
    out["pyramid_bytes"] = mountains_->pyramid().bytes();
    out["hash"] = static_cast<int64_t>(mountains_->hash());
    return out;
}

int64_t MountainRange::hash() const {
    return asked_unconfigured() ? 0 : static_cast<int64_t>(mountains_->hash());
}

void MountainRange::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure", "values"), &MountainRange::configure);
    ClassDB::bind_method(D_METHOD("is_configured"), &MountainRange::is_configured);
    ClassDB::bind_method(D_METHOD("tile_count"), &MountainRange::tile_count);
    ClassDB::bind_method(D_METHOD("tile", "index"), &MountainRange::tile);
    ClassDB::bind_method(D_METHOD("height_ticks_at", "x", "z"), &MountainRange::height_ticks_at);
    ClassDB::bind_method(D_METHOD("surface_at", "x", "z"), &MountainRange::surface_at);
    ClassDB::bind_method(D_METHOD("surfaces_at", "points"), &MountainRange::surfaces_at);
    ClassDB::bind_method(D_METHOD("highest_over", "x0", "z0", "x1", "z1"), &MountainRange::highest_over);
    ClassDB::bind_method(D_METHOD("report"), &MountainRange::report);
    ClassDB::bind_method(D_METHOD("hash"), &MountainRange::hash);
    ClassDB::bind_integer_constant(get_class_static(), "", "TICKS_PER_METRE", ground::Mountains::kTicks);
    ClassDB::bind_integer_constant(get_class_static(), "", "CLEAR_RISE_NUM", ground::Mountains::kClearRiseNum);
    ClassDB::bind_integer_constant(get_class_static(), "", "CLEAR_RISE_DEN", ground::Mountains::kClearRiseDen);
}

void register_mountain_classes() {
    GDREGISTER_CLASS(MountainRange);
}

}  // namespace ashiato_gd
