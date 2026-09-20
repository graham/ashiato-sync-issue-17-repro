#include "core/ashiato_world.h"

#include <stdexcept>
#include <vector>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace ashiato_gd {
namespace {

// Ashiato throws std::logic_error for misuse (reading a tag, touching an
// unregistered component, structural changes at the wrong time). None of that should
// take the game down: it is a script bug, so it is reported where the script author
// will see it and the call returns a failure value.
#define ASHIATO_GD_TRY(expr, on_error)                                     \
    try {                                                                  \
        expr;                                                              \
    } catch (const std::exception& error) {                                \
        ERR_PRINT(String("[ashiato] ") + String(error.what()));            \
        on_error;                                                          \
    }

ashiato::PrimitiveType to_primitive(FieldType type) {
    switch (type) {
        case FieldType::Bool: return ashiato::PrimitiveType::Bool;
        case FieldType::U8:   return ashiato::PrimitiveType::U8;
        case FieldType::I32:  return ashiato::PrimitiveType::I32;
        case FieldType::U32:  return ashiato::PrimitiveType::U32;
        case FieldType::I64:  return ashiato::PrimitiveType::I64;
        case FieldType::U64:  return ashiato::PrimitiveType::U64;
        case FieldType::F32:  return ashiato::PrimitiveType::F32;
        case FieldType::F64:  return ashiato::PrimitiveType::F64;
    }
    return ashiato::PrimitiveType::I32;
}

}  // namespace

AshiatoWorld::AshiatoWorld() = default;
AshiatoWorld::~AshiatoWorld() = default;

ashiato::Entity AshiatoWorld::to_entity(int64_t id) {
    // Entity is a struct around a uint64, not a bare integer. The bit pattern
    // round-trips through int64 even for ids with the high bit set.
    return ashiato::Entity{static_cast<std::uint64_t>(id)};
}

int64_t AshiatoWorld::from_entity(ashiato::Entity entity) {
    return static_cast<int64_t>(entity.value);
}

const AshiatoWorld::Registered* AshiatoWorld::layout_for(int64_t component) const {
    const auto found = registered_.find(static_cast<std::uint64_t>(component));
    return found == registered_.end() ? nullptr : &found->second;
}

// ---- entities --------------------------------------------------------------

int64_t AshiatoWorld::create_entity() {
    ASHIATO_GD_TRY(return from_entity(registry_.create()), return 0);
    return 0;
}

bool AshiatoWorld::destroy_entity(int64_t entity) {
    ASHIATO_GD_TRY(return registry_.destroy(to_entity(entity)), return false);
    return false;
}

bool AshiatoWorld::is_alive(int64_t entity) const {
    ASHIATO_GD_TRY(return registry_.alive(to_entity(entity)), return false);
    return false;
}

// ---- components ------------------------------------------------------------

int64_t AshiatoWorld::register_component(const String& name, const Dictionary& fields) {
    const Array keys = fields.keys();

    std::vector<std::pair<std::string, FieldType>> parsed;
    parsed.reserve(static_cast<std::size_t>(keys.size()));
    for (int i = 0; i < keys.size(); ++i) {
        const String key = keys[i];
        const int raw = static_cast<int>(fields[keys[i]]);
        if (!field_type_is_valid(raw)) {
            ERR_PRINT(String("[ashiato] field '") + key + "' has an unknown type; use AshiatoWorld.TYPE_*");
            return 0;
        }
        parsed.emplace_back(std::string(key.utf8().get_data()), static_cast<FieldType>(raw));
    }

    if (parsed.empty()) {
        // A component with no fields is a tag; say so rather than registering a
        // zero-size component that cannot be read.
        return register_tag(name);
    }

    const ComponentLayout layout = build_layout(parsed);

    ashiato::ComponentDesc desc;
    desc.name = std::string(name.utf8().get_data());
    desc.size = layout.size;
    desc.alignment = layout.alignment;
    for (const auto& field : layout.fields) {
        ashiato::ComponentField meta;
        meta.name = field.name;
        meta.offset = field.offset;
        meta.count = 1;
        // Hand the registry the real primitive entity so anything that reflects over
        // components -- the debugger, sync, a future editor inspector -- sees proper
        // types rather than an opaque blob.
        ASHIATO_GD_TRY(meta.type = registry_.primitive_type(to_primitive(field.type)), return 0);
        desc.fields.push_back(std::move(meta));
    }

    ashiato::Entity component{};
    ASHIATO_GD_TRY(component = registry_.register_component(std::move(desc)), return 0);

    Registered entry;
    entry.layout = layout;
    entry.name = std::string(name.utf8().get_data());
    registered_[component.value] = std::move(entry);
    return from_entity(component);
}

int64_t AshiatoWorld::register_tag(const String& name) {
    ashiato::Entity tag{};
    ASHIATO_GD_TRY(tag = registry_.register_tag(std::string(name.utf8().get_data())), return 0);

    Registered entry;
    entry.layout.tag = true;
    entry.name = std::string(name.utf8().get_data());
    registered_[tag.value] = std::move(entry);
    return from_entity(tag);
}

bool AshiatoWorld::add(int64_t entity, int64_t component, const Dictionary& values) {
    const Registered* entry = layout_for(component);
    if (entry == nullptr) {
        ERR_PRINT("[ashiato] add(): component was not registered through this world");
        return false;
    }

    if (entry->layout.tag) {
        ASHIATO_GD_TRY(return registry_.add_tag(to_entity(entity), to_entity(component)),
                       return false);
        return false;
    }

    // Build the value locally and hand ashiato a complete component, rather than
    // adding an uninitialised one and patching it: a lifecycle hook or a sync
    // observer would otherwise see a half-built value first.
    std::vector<std::uint8_t> scratch(entry->layout.size, 0);
    for (const auto& field : entry->layout.fields) {
        if (values.has(String(field.name.c_str()))) {
            write_field(scratch.data(), field, values[String(field.name.c_str())]);
        }
    }

    void* stored = nullptr;
    ASHIATO_GD_TRY(stored = registry_.add(to_entity(entity), to_entity(component), scratch.data()),
                   return false);
    return stored != nullptr;
}

bool AshiatoWorld::remove(int64_t entity, int64_t component) {
    const Registered* entry = layout_for(component);
    if (entry != nullptr && entry->layout.tag) {
        ASHIATO_GD_TRY(return registry_.remove_tag(to_entity(entity), to_entity(component)),
                       return false);
        return false;
    }
    ASHIATO_GD_TRY(return registry_.remove(to_entity(entity), to_entity(component)),
                   return false);
    return false;
}

bool AshiatoWorld::has(int64_t entity, int64_t component) const {
    const Registered* entry = layout_for(component);

    // There is no contains(Entity, Entity) upstream. For a value component, get()
    // answers it directly; for a tag, get() throws by design, so the entity's own
    // component list is the only runtime way to ask.
    if (entry != nullptr && !entry->layout.tag) {
        ASHIATO_GD_TRY(return registry_.get(to_entity(entity), to_entity(component)) != nullptr,
                       return false);
        return false;
    }

    ASHIATO_GD_TRY({
        for (const auto& info : registry_.components(to_entity(entity))) {
            if (info.component.value == static_cast<std::uint64_t>(component)) {
                return true;
            }
        }
        return false;
    }, return false);
    return false;
}

Dictionary AshiatoWorld::get_component(int64_t entity, int64_t component) const {
    Dictionary out;
    const Registered* entry = layout_for(component);
    if (entry == nullptr || entry->layout.tag) {
        return out;
    }

    const void* stored = nullptr;
    ASHIATO_GD_TRY(stored = registry_.get(to_entity(entity), to_entity(component)), return out);
    if (stored == nullptr) {
        return out;
    }

    for (const auto& field : entry->layout.fields) {
        out[String(field.name.c_str())] = read_field(stored, field);
    }
    return out;
}

bool AshiatoWorld::set_fields(int64_t entity, int64_t component, const Dictionary& values) {
    const Registered* entry = layout_for(component);
    if (entry == nullptr || entry->layout.tag) {
        return false;
    }

    // write() rather than get(): it is what marks the component dirty, which is what
    // change detection and replication both key off.
    void* stored = nullptr;
    ASHIATO_GD_TRY(stored = registry_.write(to_entity(entity), to_entity(component)),
                   return false);
    if (stored == nullptr) {
        return false;
    }

    bool wrote_any = false;
    for (const auto& field : entry->layout.fields) {
        const String key(field.name.c_str());
        if (values.has(key)) {
            wrote_any = write_field(stored, field, values[key]) || wrote_any;
        }
    }
    return wrote_any;
}

// ---- introspection ---------------------------------------------------------

Dictionary AshiatoWorld::describe_component(int64_t component) const {
    Dictionary out;
    const Registered* entry = layout_for(component);
    if (entry == nullptr) {
        return out;
    }
    out["name"] = String(entry->name.c_str());
    out["tag"] = entry->layout.tag;
    out["size"] = static_cast<int64_t>(entry->layout.size);
    out["alignment"] = static_cast<int64_t>(entry->layout.alignment);

    Dictionary fields;
    for (const auto& field : entry->layout.fields) {
        Dictionary info;
        info["type"] = static_cast<int64_t>(field.type);
        info["offset"] = static_cast<int64_t>(field.offset);
        fields[String(field.name.c_str())] = info;
    }
    out["fields"] = fields;
    return out;
}

PackedInt64Array AshiatoWorld::components_of(int64_t entity) const {
    PackedInt64Array out;
    ASHIATO_GD_TRY({
        for (const auto& info : registry_.components(to_entity(entity))) {
            out.push_back(static_cast<int64_t>(info.component.value));
        }
    }, return out);
    return out;
}

String AshiatoWorld::upstream_revision() const {
    // Stamped by CMake so a running game can say which ashiato it was built against.
#ifdef ASHIATO_GD_UPSTREAM_REV
    return String(ASHIATO_GD_UPSTREAM_REV);
#else
    return String("unknown");
#endif
}

void AshiatoWorld::_bind_methods() {
    ClassDB::bind_method(D_METHOD("create_entity"), &AshiatoWorld::create_entity);
    ClassDB::bind_method(D_METHOD("destroy_entity", "entity"), &AshiatoWorld::destroy_entity);
    ClassDB::bind_method(D_METHOD("is_alive", "entity"), &AshiatoWorld::is_alive);

    ClassDB::bind_method(D_METHOD("register_component", "name", "fields"),
                         &AshiatoWorld::register_component);
    ClassDB::bind_method(D_METHOD("register_tag", "name"), &AshiatoWorld::register_tag);

    ClassDB::bind_method(D_METHOD("add", "entity", "component", "values"),
                         &AshiatoWorld::add, DEFVAL(Dictionary()));
    ClassDB::bind_method(D_METHOD("remove", "entity", "component"), &AshiatoWorld::remove);
    ClassDB::bind_method(D_METHOD("has", "entity", "component"), &AshiatoWorld::has);
    ClassDB::bind_method(D_METHOD("get_component", "entity", "component"),
                         &AshiatoWorld::get_component);
    ClassDB::bind_method(D_METHOD("set_fields", "entity", "component", "values"),
                         &AshiatoWorld::set_fields);

    ClassDB::bind_method(D_METHOD("describe_component", "component"),
                         &AshiatoWorld::describe_component);
    ClassDB::bind_method(D_METHOD("components_of", "entity"), &AshiatoWorld::components_of);
    ClassDB::bind_method(D_METHOD("upstream_revision"), &AshiatoWorld::upstream_revision);

    BIND_ENUM_CONSTANT(TYPE_BOOL);
    BIND_ENUM_CONSTANT(TYPE_U8);
    BIND_ENUM_CONSTANT(TYPE_I32);
    BIND_ENUM_CONSTANT(TYPE_U32);
    BIND_ENUM_CONSTANT(TYPE_I64);
    BIND_ENUM_CONSTANT(TYPE_U64);
    BIND_ENUM_CONSTANT(TYPE_F32);
    BIND_ENUM_CONSTANT(TYPE_F64);
}

}  // namespace ashiato_gd
