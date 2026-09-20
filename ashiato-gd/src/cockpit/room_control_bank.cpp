#include "cockpit/room_control_bank.hpp"

#include <algorithm>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace ashiato_gd {
namespace {

constexpr const char* kNames[RoomControlBank::kRoomCount] = {"alpha", "bravo"};

// RFC-style serial arithmetic: the input transport is unordered, so a delayed request
// must not overwrite a newer endpoint value after it finally arrives.
bool is_newer_sequence(std::uint32_t asked, std::uint32_t previous) {
    const std::uint32_t distance = asked - previous;
    return distance != 0 && distance < 0x80000000u;
}

bool integer_key(const Dictionary& values, const char* key, int64_t& out,
                 PackedStringArray& problems) {
    if (!values.has(key)) {
        problems.push_back(String("missing key ") + key);
        return false;
    }
    const Variant value = values[key];
    if (value.get_type() != Variant::INT) {
        problems.push_back(String(key) + " is not an int");
        return false;
    }
    out = value;
    return true;
}

}  // namespace

PackedStringArray RoomControlBank::configure(const Dictionary& values) {
    PackedStringArray problems;
    const Array keys = values.keys();
    for (int64_t key_index = 0; key_index < keys.size(); ++key_index) {
        const Variant key = keys[key_index];
        if (key.get_type() != Variant::STRING) {
            problems.push_back("configuration keys must be strings");
            continue;
        }
        const String name = key;
        if (name != "revision" && name != "alpha_count" && name != "bravo_count") {
            problems.push_back(String("unknown key ") + name);
        }
    }
    int64_t revision = 0;
    int64_t counts[kRoomCount]{};
    bool whole = problems.size() == 0 && integer_key(values, "revision", revision, problems)
        && integer_key(values, "alpha_count", counts[0], problems)
        && integer_key(values, "bravo_count", counts[1], problems);
    if (revision < 1 || revision > 0x7fffffff) {
        problems.push_back("revision must be 1..2147483647");
        whole = false;
    }
    for (int room = 0; room < kRoomCount; ++room) {
        if (counts[room] < 1 || counts[room] > kMaxDevices) {
            problems.push_back(String(kNames[room]) + "_count must be 1..500");
            whole = false;
        }
    }
    for (int64_t problem_index = 0; problem_index < problems.size(); ++problem_index) {
        warn(problems[problem_index]);
    }
    if (!whole) return problems;

    configured_ = true;
    revision_ = static_cast<std::uint32_t>(revision);
    rooms_ = {};
    for (int room = 0; room < kRoomCount; ++room) {
        rooms_[room].count = static_cast<int>(counts[room]);
        const int pages = (rooms_[room].count + kPageValues - 1) / kPageValues;
        for (int page = 0; page < pages; ++page) rooms_[room].dirty[page] = true;
    }
    clients_.clear();
    accepted_ = 0;
    refused_ = 0;
    return problems;
}

Dictionary RoomControlBank::schema() const {
    Dictionary out;
    if (!configured_) return out;
    out["revision"] = static_cast<int64_t>(revision_);
    out["alpha_count"] = rooms_[0].count;
    out["bravo_count"] = rooms_[1].count;
    out["page_values"] = kPageValues;
    return out;
}

void RoomControlBank::set_server_authority(bool authoritative) {
    server_authority_ = authoritative;
}

bool RoomControlBank::set_client_room(int64_t client, int64_t room) {
    if (!server_authority_ || (room != -1 && !valid_room(room))) {
        ++refused_;
        return false;
    }
    clients_[client].room = static_cast<int>(room);
    return true;
}

bool RoomControlBank::request(int64_t client, int64_t room, int64_t endpoint, int64_t value,
                              int64_t revision, int64_t sequence) {
    if (!configured_ || !server_authority_ || !valid_endpoint(room, endpoint)
        || revision != revision_ || value < 0 || value > 255 || sequence < 0
        || sequence > 0xffffffffLL) {
        ++refused_;
        return false;
    }
    const auto found = clients_.find(client);
    if (found == clients_.end() || found->second.room != room) {
        ++refused_;
        return false;
    }
    Client& sender = found->second;
    const std::uint32_t asked_sequence = static_cast<std::uint32_t>(sequence);
    if (sender.has_sequence && !is_newer_sequence(asked_sequence, sender.sequence)) {
        ++refused_;
        return false;
    }
    sender.sequence = asked_sequence;
    sender.has_sequence = true;
    Room& target = rooms_[room];
    const int index = static_cast<int>(endpoint);
    const std::uint8_t byte_value = static_cast<std::uint8_t>(value);
    if (target.values[index] != byte_value) {
        target.values[index] = byte_value;
        const int page = index / kPageValues;
        target.dirty[page] = true;
        ++target.generations[page];
    }
    ++accepted_;
    return true;
}

int64_t RoomControlBank::state(int64_t room, int64_t endpoint) const {
    return valid_endpoint(room, endpoint) ? rooms_[room].values[endpoint] : -1;
}

Dictionary RoomControlBank::state_page(int64_t room, int64_t page) const {
    Dictionary out;
    if (!valid_page(room, page)) return out;
    PackedByteArray values;
    values.resize(values_in_page(static_cast<int>(room), static_cast<int>(page)));
    const int first = static_cast<int>(page) * kPageValues;
    for (int i = 0; i < values.size(); ++i) values[i] = rooms_[room].values[first + i];
    out["room"] = room;
    out["page"] = page;
    out["revision"] = static_cast<int64_t>(revision_);
    out["generation"] = static_cast<int64_t>(rooms_[room].generations[page]);
    out["values"] = values;
    return out;
}

Array RoomControlBank::take_dirty_pages() {
    Array out;
    if (!configured_ || !server_authority_) return out;
    for (int room = 0; room < kRoomCount; ++room) {
        const int pages = (rooms_[room].count + kPageValues - 1) / kPageValues;
        for (int page = 0; page < pages; ++page) {
            if (!rooms_[room].dirty[page]) continue;
            out.push_back(state_page(room, page));
            rooms_[room].dirty[page] = false;
        }
    }
    return out;
}

bool RoomControlBank::apply_page(int64_t room, int64_t page, int64_t revision,
                                 const PackedByteArray& values) {
    if (!configured_ || server_authority_ || !valid_page(room, page) || revision != revision_
        || values.size() != values_in_page(static_cast<int>(room), static_cast<int>(page))) {
        ++refused_;
        return false;
    }
    const int first = static_cast<int>(page) * kPageValues;
    for (int i = 0; i < values.size(); ++i) rooms_[room].values[first + i] = values[i];
    ++rooms_[room].generations[page];
    return true;
}

Dictionary RoomControlBank::metrics() const {
    Dictionary out;
    out["accepted"] = static_cast<int64_t>(accepted_);
    out["refused"] = static_cast<int64_t>(refused_);
    out["configured"] = configured_;
    out["authority"] = server_authority_;
    return out;
}

bool RoomControlBank::valid_room(int64_t room) const {
    return configured_ && room >= 0 && room < kRoomCount;
}

bool RoomControlBank::valid_page(int64_t room, int64_t page) const {
    return valid_room(room) && page >= 0
        && page < (rooms_[room].count + kPageValues - 1) / kPageValues;
}

bool RoomControlBank::valid_endpoint(int64_t room, int64_t endpoint) const {
    return valid_room(room) && endpoint >= 0 && endpoint < rooms_[room].count;
}

int RoomControlBank::values_in_page(int room, int page) const {
    return std::min(kPageValues, rooms_[room].count - page * kPageValues);
}

void RoomControlBank::warn(const String& message) const {
    UtilityFunctions::push_warning(String("[RoomControlBank] ") + message);
}

void RoomControlBank::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure", "values"), &RoomControlBank::configure);
    ClassDB::bind_method(D_METHOD("is_configured"), &RoomControlBank::is_configured);
    ClassDB::bind_method(D_METHOD("schema"), &RoomControlBank::schema);
    ClassDB::bind_method(D_METHOD("set_server_authority", "authoritative"),
                         &RoomControlBank::set_server_authority);
    ClassDB::bind_method(D_METHOD("is_server_authority"), &RoomControlBank::is_server_authority);
    ClassDB::bind_method(D_METHOD("set_client_room", "client", "room"),
                         &RoomControlBank::set_client_room);
    ClassDB::bind_method(D_METHOD("request", "client", "room", "endpoint", "value", "revision", "sequence"),
                         &RoomControlBank::request);
    ClassDB::bind_method(D_METHOD("state", "room", "endpoint"), &RoomControlBank::state);
    ClassDB::bind_method(D_METHOD("state_page", "room", "page"), &RoomControlBank::state_page);
    ClassDB::bind_method(D_METHOD("take_dirty_pages"), &RoomControlBank::take_dirty_pages);
    ClassDB::bind_method(D_METHOD("apply_page", "room", "page", "revision", "values"),
                         &RoomControlBank::apply_page);
    ClassDB::bind_method(D_METHOD("metrics"), &RoomControlBank::metrics);
}

void register_room_control_bank_class() {
    GDREGISTER_CLASS(RoomControlBank);
}

}  // namespace ashiato_gd
