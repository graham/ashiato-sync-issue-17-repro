#include "cockpit/ground_field.hpp"

#include <algorithm>
#include <vector>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector2i.hpp>

/// The binding only. The ground is `ground_core.cpp`; see `ground_field.hpp` for why the two are apart.

using namespace godot;

namespace ashiato_gd {
namespace {

/// The range each tuned number is held to. The half-width's top is the world's edge (`ground::kWorldEdgeMetres`), which
/// is the wire's `ground` range: it was 40,000 m, past the wire's +-32,768, where a craft over the ground would have been
/// clamped on every client. Its bottom is where the catalogue has room for a town. A peak past 1,535 m needs the collision's
/// height range widened, or its high cells split (godotgames-drafts/2026-09-14/cockpit-terrain/report.md, 8b).
struct Knob {
    const char* name;
    int64_t least;
    int64_t most;
};
constexpr Knob kKnobs[] = {
    {"world_half", 8192, ashiato_gd::ground::kWorldEdgeMetres},
    {"peak_height", 0, 3000},
    {"seed", 0, 65535},
};

/// THE OPTIONAL ONES (lane/testfield, 2026-09-19): absent, each is the value every recorded world was built with, so a
/// world that names none is the world it was to the bit. `coast` in 32nds of the half-width: from 16, a little inside
/// today's 21, to 128, four half-widths, which leaves no sea anywhere; `sites_within` in metres, 0 for anywhere.
constexpr Knob kOptional[] = {
    {"coast", 16, 128},
    {"sites_within", 0, ashiato_gd::ground::kWorldEdgeMetres * 2},
};
constexpr int64_t kDefaultCoast = 21;
/// At most this many pads, and funnels a pad: parallels' four ends and a crossing pair's four, with room.
constexpr int64_t kMostPads = 16;
constexpr int64_t kMostFunnels = 8;
/// At most this many rivers a world, and control points a river. A river is a hand-laid feature of a map, not a
/// generated one, and a level that wants a hundred of them wants a different mechanism.
constexpr int64_t kMostRivers = 8;
constexpr int64_t kMostRiverPoints = 64;
/// What a river's numbers may be, metres. The width is the water's; the corridor is half the clear floor either side
/// of the centre line and must hold the water with a bank to spare; the draught is how deep the water is over its bed.
constexpr int64_t kRiverWidthLeast = 4, kRiverWidthMost = 600;
constexpr int64_t kRiverCorridorMost = 4000;
constexpr int64_t kRiverDraughtLeast = 1, kRiverDraughtMost = 60;

/// An int list from an Array of ints or a PackedInt32Array, or false.
bool ints_of(const Variant& value, std::vector<int64_t>& out) {
    out.clear();
    if (value.get_type() == Variant::PACKED_INT32_ARRAY) {
        const PackedInt32Array packed = value;
        for (int64_t k = 0; k < packed.size(); ++k) out.push_back(packed[k]);
        return true;
    }
    if (value.get_type() != Variant::ARRAY) return false;
    const Array list = value;
    for (int64_t k = 0; k < list.size(); ++k) {
        if (list[k].get_type() != Variant::INT) return false;
        out.push_back(int64_t(list[k]));
    }
    return true;
}

/// THE RIVERS, read: an Array of `{points: [[x, z], ...], width, corridor, draught}`, all ints. `points` is the centre
/// line, two or more, inside the world; the three numbers are optional and each has a default in `ground::River`.
/// Anything malformed is a problem and no ground at all, as a half-read pad is: a river seats water by cutting the
/// ground, and a river read wrong is a trench across somebody's map.
///
/// THE CORRIDOR MUST HOLD THE WATER. A corridor narrower than the river's own half-width would put the bank inside the
/// water, and the carve would fold; it is checked here rather than clamped, because a level that asks for that has its
/// numbers the wrong way round and should be told so.
bool read_rivers(const Variant& value, int64_t half, std::vector<ground::River>& rivers, PackedStringArray& problems) {
    if (value.get_type() != Variant::ARRAY) {
        problems.push_back("rivers is not an Array");
        return false;
    }
    const Array list = value;
    if (list.size() > kMostRivers) {
        problems.push_back("rivers: " + String::num_int64(list.size()) + " is more than "
            + String::num_int64(kMostRivers));
        return false;
    }
    bool whole = true;
    std::vector<int64_t> ints;
    for (int64_t r = 0; r < list.size(); ++r) {
        String where = String("river ") + String::num_int64(r) + ": ";
        if (list[r].get_type() != Variant::DICTIONARY) {
            problems.push_back(where + String("not a Dictionary"));
            whole = false;
            continue;
        }
        const Dictionary d = list[r];
        const Array keys = d.keys();
        for (int64_t k = 0; k < keys.size(); ++k) {
            const String key = keys[k];
            if (key != "points" && key != "width" && key != "corridor" && key != "draught") {
                problems.push_back(where + String("unknown key ") + key);
                whole = false;
            }
        }
        ground::River river;
        if (!d.has("points") || d["points"].get_type() != Variant::ARRAY) {
            problems.push_back(where + String("points is not an Array of [x, z]"));
            whole = false;
            continue;
        }
        const Array points = d["points"];
        if (points.size() < 2 || points.size() > kMostRiverPoints) {
            problems.push_back(where + String("points is not 2 to ") + String::num_int64(kMostRiverPoints)
                + String(" control points"));
            whole = false;
            continue;
        }
        bool laid = true;
        for (int64_t k = 0; k < points.size(); ++k) {
            if (!ints_of(points[k], ints) || ints.size() != 2
                || std::max({-ints[0], ints[0], -ints[1], ints[1]}) > half) {
                problems.push_back(where + String("point ") + String::num_int64(k)
                    + String(" is not [x, z] as two ints inside the world"));
                whole = false;
                laid = false;
                break;
            }
            river.x.push_back(ints[0]);
            river.z.push_back(ints[1]);
        }
        if (!laid) continue;
        if (d.has("width")) {
            if (d["width"].get_type() != Variant::INT || int64_t(d["width"]) < kRiverWidthLeast
                || int64_t(d["width"]) > kRiverWidthMost) {
                problems.push_back(where + String("width is not an int from ") + String::num_int64(kRiverWidthLeast)
                    + String(" to ") + String::num_int64(kRiverWidthMost) + String(" m"));
                whole = false;
            } else {
                river.width = d["width"];
            }
        }
        if (d.has("corridor")) {
            if (d["corridor"].get_type() != Variant::INT || int64_t(d["corridor"]) < 1
                || int64_t(d["corridor"]) > kRiverCorridorMost) {
                problems.push_back(where + String("corridor is not an int from 1 to ")
                    + String::num_int64(kRiverCorridorMost) + String(" m"));
                whole = false;
            } else {
                river.corridor = d["corridor"];
            }
        }
        if (d.has("draught")) {
            if (d["draught"].get_type() != Variant::INT || int64_t(d["draught"]) < kRiverDraughtLeast
                || int64_t(d["draught"]) > kRiverDraughtMost) {
                problems.push_back(where + String("draught is not an int from ")
                    + String::num_int64(kRiverDraughtLeast) + String(" to ")
                    + String::num_int64(kRiverDraughtMost) + String(" m"));
                whole = false;
            } else {
                river.draught = d["draught"];
            }
        }
        if (river.corridor <= river.width / 2) {
            problems.push_back(where + String("corridor ") + String::num_int64(river.corridor)
                + String(" m does not reach past the river's own half-width ")
                + String::num_int64(river.width / 2) + String(" m"));
            whole = false;
        }
        rivers.push_back(river);
    }
    return whole;
}

/// THE PADS, read: an Array of `{rect: [x0, z0, x1, z1], margin, funnels: [[x, z, dir, length, half_width], ...]}`, all
/// ints, the rectangle's corners in order and inside the world. Anything malformed is a problem and no ground, since a
/// pad half-read is an airport on a hillside.
bool read_pads(const Variant& value, int64_t half, std::vector<ground::Pad>& pads, PackedStringArray& problems) {
    if (value.get_type() != Variant::ARRAY) {
        problems.push_back("pads is not an Array");
        return false;
    }
    const Array list = value;
    if (list.size() > kMostPads) {
        problems.push_back("pads: " + String::num_int64(list.size()) + " is more than " + String::num_int64(kMostPads));
        return false;
    }
    bool whole = true;
    std::vector<int64_t> ints;
    for (int64_t p = 0; p < list.size(); ++p) {
        String where = String("pad ") + String::num_int64(p) + ": ";
        if (list[p].get_type() != Variant::DICTIONARY) {
            problems.push_back(where + String("not a Dictionary"));
            whole = false;
            continue;
        }
        const Dictionary d = list[p];
        const Array keys = d.keys();
        for (int64_t k = 0; k < keys.size(); ++k) {
            const String key = keys[k];
            if (key != "rect" && key != "margin" && key != "funnels") {
                problems.push_back(where + String("unknown key ") + key);
                whole = false;
            }
        }
        ground::Pad pad;
        if (!d.has("rect") || !ints_of(d["rect"], ints) || ints.size() != 4) {
            problems.push_back(where + String("rect is not four ints"));
            whole = false;
            continue;
        }
        pad.x0 = ints[0];
        pad.z0 = ints[1];
        pad.x1 = ints[2];
        pad.z1 = ints[3];
        if (pad.x0 >= pad.x1 || pad.z0 >= pad.z1 || std::max({-pad.x0, pad.x1, -pad.z0, pad.z1}) > half) {
            problems.push_back(where + String("rect is not x0 < x1 and z0 < z1 inside the world"));
            whole = false;
        }
        if (!d.has("margin") || d["margin"].get_type() != Variant::INT || int64_t(d["margin"]) < 1
            || int64_t(d["margin"]) > 4000) {
            problems.push_back(where + String("margin is not an int from 1 to 4000"));
            whole = false;
        } else {
            pad.margin = d["margin"];
        }
        Array funnels;
        if (d.has("funnels")) {
            if (d["funnels"].get_type() != Variant::ARRAY) {
                problems.push_back(where + String("funnels is not an Array"));
                whole = false;
            } else {
                funnels = d["funnels"];
            }
        }
        if (funnels.size() > kMostFunnels) {
            problems.push_back(where + String("more than ") + String::num_int64(kMostFunnels) + " funnels");
            whole = false;
        }
        for (int64_t f = 0; f < funnels.size() && f < kMostFunnels; ++f) {
            if (!ints_of(funnels[f], ints) || ints.size() != 5 || ints[2] < 0 || ints[2] > 3 || ints[3] < 1
                || ints[3] > 2 * half || ints[4] < 0 || ints[4] > 4000) {
                problems.push_back(where + String("funnel ") + String::num_int64(f)
                                   + " is not [x, z, dir 0 to 3, length 1 to the world's width, half_width 0 to 4000]");
                whole = false;
                continue;
            }
            pad.funnels.push_back(ground::Funnel{ints[0], ints[1], int(ints[2]), ints[3], ints[4]});
        }
        pads.push_back(pad);
    }
    return whole;
}

}  // namespace

PackedStringArray GroundField::configure(const Dictionary& values) {
    PackedStringArray problems;
    ground::Tuning tuning;
    bool whole = true;
    Array keys = values.keys();
    for (int64_t k = 0; k < keys.size(); ++k) {
        const String key = keys[k];
        bool known = key == "pads" || key == "rivers";
        for (const Knob& knob : kKnobs) {
            known = known || key == String(knob.name);
        }
        for (const Knob& knob : kOptional) {
            known = known || key == String(knob.name);
        }
        if (!known) {
            problems.push_back("unknown key " + key);
        }
    }
    for (const Knob& knob : kKnobs) {
        if (!values.has(knob.name)) {
            problems.push_back(String("missing key ") + knob.name);
            whole = false;
            continue;
        }
        const Variant value = values[knob.name];
        if (value.get_type() != Variant::INT) {
            problems.push_back(String(knob.name) + " is not an int");
            whole = false;
            continue;
        }
        int64_t asked = value;
        int64_t held = std::min(std::max(asked, knob.least), knob.most);
        if (held != asked) {
            problems.push_back(String(knob.name) + " " + String::num_int64(asked) + " clamped to "
                               + String::num_int64(held));
        }
        if (String(knob.name) == "world_half") tuning.world_half = held;
        if (String(knob.name) == "peak_height") tuning.peak_height = held;
        if (String(knob.name) == "seed") tuning.seed = held;
    }
    tuning.coast = kDefaultCoast;
    for (const Knob& knob : kOptional) {
        if (!values.has(knob.name)) continue;
        const Variant value = values[knob.name];
        if (value.get_type() != Variant::INT) {
            problems.push_back(String(knob.name) + " is not an int");
            whole = false;
            continue;
        }
        int64_t asked = value;
        int64_t held = std::min(std::max(asked, knob.least), knob.most);
        if (held != asked) {
            problems.push_back(String(knob.name) + " " + String::num_int64(asked) + " clamped to "
                               + String::num_int64(held));
        }
        if (String(knob.name) == "coast") tuning.coast = held;
        if (String(knob.name) == "sites_within") tuning.sites_within = held;
    }
    if (values.has("pads") && !read_pads(values["pads"], tuning.world_half, tuning.pads, problems)) {
        whole = false;
    }
    if (values.has("rivers") && !read_rivers(values["rivers"], tuning.world_half, tuning.rivers, problems)) {
        whole = false;
    }
    for (int64_t p = 0; p < problems.size(); ++p) {
        UtilityFunctions::push_warning("[GroundField] ", problems[p]);
    }
    if (whole) {
        field_ = std::make_unique<ground::Field>(tuning);
    } else {
        field_.reset();
    }
    return problems;
}

bool GroundField::is_configured() const {
    return field_ != nullptr;
}

bool GroundField::asked_unconfigured() const {
    if (field_) return false;
    UtilityFunctions::push_error("[GroundField] asked about the ground before configure() succeeded");
    return true;
}

Dictionary GroundField::tuning() const {
    Dictionary out;
    if (field_) {
        out["world_half"] = field_->tuning().world_half;
        out["peak_height"] = field_->tuning().peak_height;
        out["seed"] = field_->tuning().seed;
        out["coast"] = field_->tuning().coast;
        out["sites_within"] = field_->tuning().sites_within;
        out["pads"] = int64_t(field_->pads().size());
        out["rivers"] = int64_t(field_->rivers().size());
    }
    return out;
}

int64_t GroundField::height_ticks_at(int64_t x, int64_t z) const {
    return asked_unconfigured() ? 0 : field_->height_ticks(x, z);
}

int64_t GroundField::water_ticks_at(int64_t x, int64_t z) const {
    return asked_unconfigured() ? ground::kNoWater : field_->water_ticks(x, z);
}

PackedInt32Array GroundField::heights(int64_t x0, int64_t z0, int64_t count_x, int64_t count_z,
                                     int64_t spacing) const {
    PackedInt32Array out;
    if (asked_unconfigured()) return out;
    if (count_x <= 0 || count_z <= 0 || spacing <= 0 || count_x * count_z > kMostSamples) {
        UtilityFunctions::push_warning("[GroundField] heights(): ", count_x, " by ", count_z, " at ", spacing,
                                       " m refused; at most ", kMostSamples, " samples, each count and the spacing "
                                       "above zero");
        return out;
    }
    out.resize(count_x * count_z);
    int32_t* write = out.ptrw();
    for (int64_t j = 0; j < count_z; ++j) {
        for (int64_t i = 0; i < count_x; ++i) {
            write[j * count_x + i] = int32_t(field_->height_ticks(x0 + i * spacing, z0 + j * spacing));
        }
    }
    return out;
}

PackedInt32Array GroundField::heights_at(const PackedInt32Array& points) const {
    PackedInt32Array out;
    if (asked_unconfigured()) return out;
    out.resize(points.size() / 2);
    for (int64_t k = 0; k + 1 < points.size(); k += 2) {
        out.set(k / 2, int32_t(field_->height_ticks(points[k], points[k + 1])));
    }
    return out;
}

PackedInt32Array GroundField::waters_at(const PackedInt32Array& points) const {
    PackedInt32Array out;
    if (asked_unconfigured()) return out;
    out.resize(points.size() / 2);
    for (int64_t k = 0; k + 1 < points.size(); k += 2) {
        out.set(k / 2, int32_t(field_->water_ticks(points[k], points[k + 1])));
    }
    return out;
}

Dictionary GroundField::catalogue() const {
    Dictionary out;
    if (asked_unconfigured()) return out;
    Array lakes, towns, airfields;
    for (const ground::Lake& l : field_->lakes()) {
        Dictionary d;
        d["cell"] = Vector2i(int32_t(l.cell_i), int32_t(l.cell_j));
        d["x"] = l.x;
        d["z"] = l.z;
        d["r"] = l.r;
        d["depth"] = l.depth;
        d["level"] = l.level;
        d["salt"] = l.salt;
        d["water_radius"] = ground::Field::water_radius(l);
        lakes.push_back(d);
    }
    for (const ground::Town& t : field_->towns()) {
        Dictionary d;
        d["x"] = t.x;
        d["z"] = t.z;
        d["r"] = t.r;
        d["margin"] = t.margin;
        d["level"] = t.level;
        towns.push_back(d);
    }
    for (const ground::Strip& s : field_->airfields()) {
        Dictionary d;
        d["x"] = s.x;
        d["z"] = s.z;
        d["half_long"] = s.half_long;
        d["half_wide"] = s.half_wide;
        d["margin"] = s.margin;
        d["level"] = s.level;
        airfields.push_back(d);
    }
    Array pads;
    for (const ground::Pad& p : field_->pads()) {
        Dictionary d;
        d["x0"] = p.x0;
        d["z0"] = p.z0;
        d["x1"] = p.x1;
        d["z1"] = p.z1;
        d["margin"] = p.margin;
        d["level"] = p.level;
        d["funnels"] = int64_t(p.funnels.size());
        pads.push_back(d);
    }
    out["lakes"] = lakes;
    out["towns"] = towns;
    out["airfields"] = airfields;
    out["pads"] = pads;
    return out;
}

PackedInt32Array GroundField::catalogue_ints() const {
    PackedInt32Array out;
    if (asked_unconfigured()) return out;
    for (const ground::Lake& l : field_->lakes()) {
        for (int64_t v : {l.cell_i, l.cell_j, l.x, l.z, l.r, l.depth, l.level, l.salt}) out.push_back(int32_t(v));
    }
    for (const ground::Town& t : field_->towns()) {
        for (int64_t v : {t.x, t.z, t.r, t.margin, t.level}) out.push_back(int32_t(v));
    }
    for (const ground::Strip& s : field_->airfields()) {
        for (int64_t v : {s.x, s.z, s.half_long, s.half_wide, s.margin, s.level}) out.push_back(int32_t(v));
    }
    for (const ground::Pad& p : field_->pads()) {
        for (int64_t v : {p.x0, p.z0, p.x1, p.z1, p.margin, p.level}) out.push_back(int32_t(v));
        for (const ground::Funnel& f : p.funnels) {
            for (int64_t v : {f.x, f.z, int64_t(f.dir), f.length, f.half_width}) out.push_back(int32_t(v));
        }
    }
    return out;
}

void GroundField::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure", "values"), &GroundField::configure);
    ClassDB::bind_method(D_METHOD("is_configured"), &GroundField::is_configured);
    ClassDB::bind_method(D_METHOD("tuning"), &GroundField::tuning);
    ClassDB::bind_method(D_METHOD("height_ticks_at", "x", "z"), &GroundField::height_ticks_at);
    ClassDB::bind_method(D_METHOD("water_ticks_at", "x", "z"), &GroundField::water_ticks_at);
    ClassDB::bind_method(D_METHOD("heights", "x0", "z0", "count_x", "count_z", "spacing"), &GroundField::heights);
    ClassDB::bind_method(D_METHOD("heights_at", "points"), &GroundField::heights_at);
    ClassDB::bind_method(D_METHOD("waters_at", "points"), &GroundField::waters_at);
    ClassDB::bind_method(D_METHOD("catalogue"), &GroundField::catalogue);
    ClassDB::bind_method(D_METHOD("catalogue_ints"), &GroundField::catalogue_ints);
    ClassDB::bind_integer_constant(get_class_static(), "", "TICKS_PER_METRE", ground::kTicksPerMetre);
    ClassDB::bind_integer_constant(get_class_static(), "", "NO_WATER", ground::kNoWater);
    ClassDB::bind_integer_constant(get_class_static(), "", "MOST_SAMPLES", kMostSamples);
}

void register_ground_classes() {
    GDREGISTER_CLASS(GroundField);
}

}  // namespace ashiato_gd
