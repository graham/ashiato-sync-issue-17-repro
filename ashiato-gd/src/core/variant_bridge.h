#pragma once
// Moving field values between Godot Variants and the raw bytes ashiato stores.
//
// Components declared from GDScript are plain structs the binding lays out itself:
// a run of fixed-size primitive fields. Nothing here knows what a "Position" is,
// which is the entire reason a new component type costs zero C++.

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

#include <godot_cpp/variant/variant.hpp>

namespace ashiato_gd {

// Mirrors ashiato::PrimitiveType, minus String.
//
// String is deliberately absent: these components are fixed-size byte blobs copied
// around by the ECS and, with sync, put on a wire. A std::string field would make
// the component non-trivially-copyable and give it a size that depends on its
// contents. Text belongs in a Godot-side table keyed by entity until upstream has a
// stable answer for it.
enum class FieldType : int {
    Bool = 0,
    U8,
    I32,
    U32,
    I64,
    U64,
    F32,
    F64,
};

struct FieldLayout {
    std::string name;
    std::size_t offset = 0;
    FieldType type = FieldType::I32;
};

struct ComponentLayout {
    std::vector<FieldLayout> fields;
    std::size_t size = 0;
    std::size_t alignment = 1;
    bool tag = false;
};

std::size_t field_size(FieldType type);
std::size_t field_alignment(FieldType type);
bool field_type_is_valid(int raw);

// Lays fields out in declaration order with natural alignment, and rounds the total
// up to the struct alignment -- the same rules a C compiler would use, so the bytes
// stay meaningful to anything that reads them as a struct.
ComponentLayout build_layout(const std::vector<std::pair<std::string, FieldType>>& fields);

// Both return false rather than throwing: values come from GDScript and being handed
// a String where a float belongs is a script bug to report, not a crash.
bool write_field(void* base, const FieldLayout& field, const godot::Variant& value);
godot::Variant read_field(const void* base, const FieldLayout& field);

}  // namespace ashiato_gd
