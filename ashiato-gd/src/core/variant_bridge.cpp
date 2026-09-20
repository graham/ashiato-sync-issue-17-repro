#include "core/variant_bridge.h"

#include <cstring>

using namespace godot;

namespace ashiato_gd {

std::size_t field_size(FieldType type) {
    switch (type) {
        case FieldType::Bool: return sizeof(bool);
        case FieldType::U8:   return sizeof(std::uint8_t);
        case FieldType::I32:  return sizeof(std::int32_t);
        case FieldType::U32:  return sizeof(std::uint32_t);
        case FieldType::I64:  return sizeof(std::int64_t);
        case FieldType::U64:  return sizeof(std::uint64_t);
        case FieldType::F32:  return sizeof(float);
        case FieldType::F64:  return sizeof(double);
    }
    return 0;
}

std::size_t field_alignment(FieldType type) {
    // Every type here is naturally aligned to its own width.
    return field_size(type);
}

bool field_type_is_valid(int raw) {
    return raw >= static_cast<int>(FieldType::Bool) && raw <= static_cast<int>(FieldType::F64);
}

ComponentLayout build_layout(const std::vector<std::pair<std::string, FieldType>>& fields) {
    ComponentLayout layout;
    std::size_t offset = 0;
    std::size_t max_align = 1;

    for (const auto& entry : fields) {
        const std::size_t align = field_alignment(entry.second);
        if (align > max_align) {
            max_align = align;
        }
        // Pad up to this field's alignment.
        if (offset % align != 0) {
            offset += align - (offset % align);
        }
        layout.fields.push_back(FieldLayout{entry.first, offset, entry.second});
        offset += field_size(entry.second);
    }

    // Tail padding, so an array of these would stay aligned.
    if (max_align > 1 && offset % max_align != 0) {
        offset += max_align - (offset % max_align);
    }

    layout.alignment = max_align;
    layout.size = offset;
    // No fields means a tag: ashiato treats a zero-size component as one, and it is
    // added and removed rather than read or written.
    layout.tag = fields.empty();
    return layout;
}

bool write_field(void* base, const FieldLayout& field, const Variant& value) {
    auto* bytes = static_cast<std::uint8_t*>(base) + field.offset;

    switch (field.type) {
        case FieldType::Bool: {
            const bool v = value;
            std::memcpy(bytes, &v, sizeof(v));
            return true;
        }
        case FieldType::U8: {
            const auto v = static_cast<std::uint8_t>(static_cast<int64_t>(value));
            std::memcpy(bytes, &v, sizeof(v));
            return true;
        }
        case FieldType::I32: {
            const auto v = static_cast<std::int32_t>(static_cast<int64_t>(value));
            std::memcpy(bytes, &v, sizeof(v));
            return true;
        }
        case FieldType::U32: {
            const auto v = static_cast<std::uint32_t>(static_cast<int64_t>(value));
            std::memcpy(bytes, &v, sizeof(v));
            return true;
        }
        case FieldType::I64: {
            const auto v = static_cast<std::int64_t>(value);
            std::memcpy(bytes, &v, sizeof(v));
            return true;
        }
        case FieldType::U64: {
            // Godot has no unsigned int Variant; the bit pattern round-trips even
            // though very large values read back negative on the script side.
            const auto v = static_cast<std::uint64_t>(static_cast<int64_t>(value));
            std::memcpy(bytes, &v, sizeof(v));
            return true;
        }
        case FieldType::F32: {
            const auto v = static_cast<float>(static_cast<double>(value));
            std::memcpy(bytes, &v, sizeof(v));
            return true;
        }
        case FieldType::F64: {
            const auto v = static_cast<double>(value);
            std::memcpy(bytes, &v, sizeof(v));
            return true;
        }
    }
    return false;
}

Variant read_field(const void* base, const FieldLayout& field) {
    const auto* bytes = static_cast<const std::uint8_t*>(base) + field.offset;

    switch (field.type) {
        case FieldType::Bool: {
            bool v = false;
            std::memcpy(&v, bytes, sizeof(v));
            return v;
        }
        case FieldType::U8: {
            std::uint8_t v = 0;
            std::memcpy(&v, bytes, sizeof(v));
            return static_cast<int64_t>(v);
        }
        case FieldType::I32: {
            std::int32_t v = 0;
            std::memcpy(&v, bytes, sizeof(v));
            return static_cast<int64_t>(v);
        }
        case FieldType::U32: {
            std::uint32_t v = 0;
            std::memcpy(&v, bytes, sizeof(v));
            return static_cast<int64_t>(v);
        }
        case FieldType::I64: {
            std::int64_t v = 0;
            std::memcpy(&v, bytes, sizeof(v));
            return v;
        }
        case FieldType::U64: {
            std::uint64_t v = 0;
            std::memcpy(&v, bytes, sizeof(v));
            return static_cast<int64_t>(v);
        }
        case FieldType::F32: {
            float v = 0.0f;
            std::memcpy(&v, bytes, sizeof(v));
            return static_cast<double>(v);
        }
        case FieldType::F64: {
            double v = 0.0;
            std::memcpy(&v, bytes, sizeof(v));
            return v;
        }
    }
    return Variant();
}

}  // namespace ashiato_gd
