#pragma once
/// THE GROUND, FOR GDSCRIPT: the class a level, a scenery layer or a suite asks for heights, water and the catalogue.
///
/// The ground itself is `ground_core.hpp` -- a function of integers with no Godot in it, so a scratch program can compile
/// it to measure a change or prove one leaves a world bit for bit where it was. This file is the binding and only the
/// binding: it checks a tuning handed in from GDScript, owns one `ground::Field`, and turns its answers into Packed
/// arrays and Dictionaries.
///
/// THE WORLD IS THREE TUNED NUMBERS, required rather than defaulted: `world_half`, `peak_height`, `seed`. The game's
/// values live in `cockpit/world/ground_tuning.gd` and nowhere else.
///
/// THREAD-SAFE TO READ. After `configure` every query is const over data that does not change, so the scenery's worker
/// threads may ask it while the main thread does. Configuring while a worker reads is the caller's bug.

#include <cstdint>
#include <memory>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

#include "cockpit/ground_core.hpp"

namespace ashiato_gd {

class GroundField : public godot::RefCounted {
    GDCLASS(GroundField, godot::RefCounted)

public:
    /// Every key required: `world_half`, `peak_height`, `seed`, as ints. Three more are optional, and absent each is
    /// what every recorded world was built with: `coast` and `sites_within` (ints) and `pads` (see `ground::Pad`,
    /// `read_pads`). Returns what was wrong -- an unknown key, a missing one, a value clamped to its range, a malformed
    /// pad -- and warns each. A missing key, a value of the wrong type or a malformed pad leaves the field unconfigured.
    godot::PackedStringArray configure(const godot::Dictionary& values);
    bool is_configured() const;
    godot::Dictionary tuning() const;

    int64_t height_ticks_at(int64_t x, int64_t z) const;
    int64_t water_ticks_at(int64_t x, int64_t z) const;
    /// `count_x` by `count_z` samples `spacing` metres apart from (x0, z0), row by row along z, each row along x.
    godot::PackedInt32Array heights(int64_t x0, int64_t z0, int64_t count_x, int64_t count_z, int64_t spacing) const;
    /// The height at each (x, z) pair of `points`.
    godot::PackedInt32Array heights_at(const godot::PackedInt32Array& points) const;
    godot::PackedInt32Array waters_at(const godot::PackedInt32Array& points) const;
    /// `{lakes, towns, airfields, pads}`, each an Array of Dictionaries, in the order the function found them; a pad's
    /// is its rectangle, margin, the level the function found and how many funnels it has.
    godot::Dictionary catalogue() const;
    /// The catalogue as ints in that order, for a hash: lakes (cell i, cell j, x, z, r, depth, level, salt), towns
    /// (x, z, r, margin, level), airfields (x, z, half_long, half_wide, margin, level), then each pad (x0, z0, x1, z1,
    /// margin, level) followed by its funnels (x, z, dir, length, half_width). A world with no pads adds none.
    godot::PackedInt32Array catalogue_ints() const;

    /// The ground itself, for the simulation's collision (`bedrock.hpp`), which takes a copy; null until `configure`
    /// has succeeded.
    const ground::Field* core() const { return field_.get(); }

    static constexpr int64_t kMostSamples = int64_t(1) << 22;

protected:
    static void _bind_methods();

private:
    bool asked_unconfigured() const;
    std::unique_ptr<ground::Field> field_;
};

void register_ground_classes();

}  // namespace ashiato_gd
