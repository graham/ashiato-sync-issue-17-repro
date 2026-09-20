#pragma once
/// THE ISLAND'S MOUNTAINS, FOR GDSCRIPT: the class the level, the picture and the suites ask for the ranges' triangles and
/// heights. The mountains themselves are `range_core.hpp` -- integers with no Godot in them -- and this is the binding
/// only: it checks what GDScript hands in, owns one `ground::Mountains`, and turns its answers into Packed arrays.
///
/// ONE SET OF TRIANGLES, TWO CUSTOMERS. `tile(i)` is what `cockpit/world/mountain_view.gd` draws, and `CockpitWorld.
/// set_mountains` hands the SAME `ground::Mountains` -- shared, not rebuilt -- to Box3D (`massif.hpp`). There is no second
/// description of a mountain anywhere to disagree with the first.
///
/// WHAT IT IS HANDED, all ints, every key required: `spacing` and `tile_quads`; `ranges`, an Array of Dictionaries each
/// with `salt`, `peak`, `saddle` and `points` (x, z, crest, foot, four ints a point); and `keepouts`, five ints each
/// (x0, z0, x1, z1, floor in ticks). The game's values are `cockpit/world/mountain_ranges.gd`'s.
///
/// THREAD-SAFE TO READ once configured, as `GroundField` is.

#include <cstdint>
#include <memory>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

#include "cockpit/range_core.hpp"

namespace ashiato_gd {

class MountainRange : public godot::RefCounted {
    GDCLASS(MountainRange, godot::RefCounted)

public:
    /// Returns what was wrong -- a missing or unknown key, a value that is not an int, a range with no points, a
    /// number held to its range -- and warns each. Anything but a clamp leaves the mountains unconfigured.
    godot::PackedStringArray configure(const godot::Dictionary& values);
    bool is_configured() const;

    int64_t tile_count() const;
    /// `{origin: Vector2i, vertices: PackedVector3Array, indices: PackedInt32Array, grit: PackedByteArray}`: see
    /// `ground::MountainTile`. Vertices in the tile's own frame, metres.
    godot::Dictionary tile(int64_t index) const;
    int64_t height_ticks_at(int64_t x, int64_t z) const;
    double surface_at(double x, double z) const;
    godot::PackedFloat32Array surfaces_at(const godot::PackedVector2Array& points) const;
    /// The highest rock over a rectangle, metres, never lower than the truth and never higher than the highest within one
    /// 32 m square of it (`HeightPyramid::highest_within`); 0 where there is none.
    double highest_over(double x0, double z0, double x1, double z1) const;
    /// `tiles, triangles, vertices, build_usec, hash`.
    godot::Dictionary report() const;
    int64_t hash() const;

    /// The mountains themselves, for the simulation's collision, which keeps a share of them; null until configured.
    std::shared_ptr<const ground::Mountains> core() const { return mountains_; }

protected:
    static void _bind_methods();

private:
    bool asked_unconfigured() const;
    std::shared_ptr<const ground::Mountains> mountains_;
};

void register_mountain_classes();

}  // namespace ashiato_gd
