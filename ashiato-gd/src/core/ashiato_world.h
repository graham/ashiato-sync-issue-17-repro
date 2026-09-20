#pragma once
// AshiatoWorld -- one ashiato::Registry, exposed to GDScript.
//
// GROWTH IS THE DESIGN CONSTRAINT. Ashiato's ergonomic API is compile-time
// (register_component<Position>()), and binding that would mean a C++ change and a
// rebuild for every component a game invents. It also has a RUNTIME API --
// ComponentDesc{name,size,alignment,fields} plus add/get/write by component entity --
// and that is what is bound here. GDScript declares components at runtime, so this
// file never learns what a "Position" is, and adding one costs nothing.
//
// The surface is deliberately small: entities, runtime components, fields. Jobs,
// views, groups, snapshots and lifecycle hooks are NOT bound yet. See README for why
// and for how to add one.

#include <cstdint>
#include <string>
#include <unordered_map>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include "ashiato/ashiato.hpp"
#include "core/variant_bridge.h"

namespace ashiato_gd {

class AshiatoWorld : public godot::RefCounted {
    GDCLASS(AshiatoWorld, godot::RefCounted)

public:
    // Mirrors variant_bridge::FieldType for GDScript. Bound as constants so a script
    // writes AshiatoWorld.F32 rather than a bare number.
    enum FieldTypeEnum {
        TYPE_BOOL = 0,
        TYPE_U8,
        TYPE_I32,
        TYPE_U32,
        TYPE_I64,
        TYPE_U64,
        TYPE_F32,
        TYPE_F64,
    };

    AshiatoWorld();
    ~AshiatoWorld() override;

    // ---- entities ----
    int64_t create_entity();
    bool destroy_entity(int64_t entity);
    bool is_alive(int64_t entity) const;

    // ---- components, declared at runtime ----
    // fields: { "x": AshiatoWorld.TYPE_F32, "y": AshiatoWorld.TYPE_F32 }
    // Declaration order decides layout, so a Dictionary's insertion order matters.
    // Returns the component's entity id, or 0 on failure.
    int64_t register_component(const godot::String& name, const godot::Dictionary& fields);
    int64_t register_tag(const godot::String& name);

    bool add(int64_t entity, int64_t component, const godot::Dictionary& values);
    bool remove(int64_t entity, int64_t component);
    bool has(int64_t entity, int64_t component) const;

    // Empty Dictionary if absent -- check has() to tell "missing" from "all zero".
    godot::Dictionary get_component(int64_t entity, int64_t component) const;
    // Partial update: only the named fields are touched.
    bool set_fields(int64_t entity, int64_t component, const godot::Dictionary& values);

    // ---- introspection ----
    godot::Dictionary describe_component(int64_t component) const;
    godot::PackedInt64Array components_of(int64_t entity) const;
    godot::String upstream_revision() const;

protected:
    static void _bind_methods();

private:
    struct Registered {
        ComponentLayout layout;
        std::string name;
    };

    const Registered* layout_for(int64_t component) const;
    static ashiato::Entity to_entity(int64_t id);
    static int64_t from_entity(ashiato::Entity entity);

    ashiato::Registry registry_;
    // Keyed by component entity value. The registry also stores field metadata, but
    // this keeps the offsets and the Variant conversion in one place and avoids
    // re-deriving them on every read.
    std::unordered_map<std::uint64_t, Registered> registered_;
};

}  // namespace ashiato_gd

VARIANT_ENUM_CAST(ashiato_gd::AshiatoWorld::FieldTypeEnum);
