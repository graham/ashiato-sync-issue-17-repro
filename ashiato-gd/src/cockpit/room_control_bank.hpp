#pragma once

// A small, fixed state bank for world-mounted controls.  It deliberately is not part of
// CockpitWorld's 5-bit craft command bus: a room endpoint needs a room, revision,
// endpoint and sequence, and squeezing that into a flight command would make a forged
// or stale control indistinguishable from a real one.

#include <array>
#include <cstdint>
#include <unordered_map>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace ashiato_gd {

/// Authoritative, room-local state for the two-room device-yard experiment.
///
/// A page is exactly 32 quantized endpoint values. A replication bridge sends only pages
/// returned by take_dirty_pages(), and feeds them to apply_page() on clients. The class
/// owns no network transport so that it cannot bypass cockpit's one packet transport.
class RoomControlBank : public godot::RefCounted {
    GDCLASS(RoomControlBank, godot::RefCounted)

public:
    static constexpr int kRoomCount = 2;
    static constexpr int kMaxDevices = 500;
    static constexpr int kPageValues = 32;
    static constexpr int kMaxPages = (kMaxDevices + kPageValues - 1) / kPageValues;

    /// Requires integer keys revision, alpha_count and bravo_count. Counts are 1..500.
    /// A successful reconfigure resets all state and access grants.
    godot::PackedStringArray configure(const godot::Dictionary& values);
    bool is_configured() const { return configured_; }
    godot::Dictionary schema() const;

    /// Only the server may alter membership or accept a request. `room` is -1, 0 or 1.
    void set_server_authority(bool authoritative);
    bool is_server_authority() const { return server_authority_; }
    bool set_client_room(int64_t client, int64_t room);

    /// Applies a command after validating authority, membership, revision, endpoint,
    /// value and a per-client sequence. Values are deliberately byte-quantized.
    bool request(int64_t client, int64_t room, int64_t endpoint, int64_t value,
                 int64_t revision, int64_t sequence);

    int64_t state(int64_t room, int64_t endpoint) const;
    /// {room, page, revision, values}; values contains only live endpoints in that page.
    godot::Dictionary state_page(int64_t room, int64_t page) const;
    /// Returns each dirty page once and clears its dirty bit. Server transport calls this
    /// after a tick; a client must never call it to manufacture authoritative updates.
    godot::Array take_dirty_pages();
    /// Client-side counterpart. Refuses a wrong-schema page and malformed length. The
    /// transport must discard stale generations before calling this method.
    bool apply_page(int64_t room, int64_t page, int64_t revision,
                    const godot::PackedByteArray& values);
    godot::Dictionary metrics() const;

protected:
    static void _bind_methods();

private:
    struct Room {
        int count = 0;
        std::array<std::uint8_t, kMaxDevices> values{};
        std::array<bool, kMaxPages> dirty{};
        std::array<std::uint32_t, kMaxPages> generations{};
    };
    struct Client {
        int room = -1;
        std::uint32_t sequence = 0;
        bool has_sequence = false;
    };

    bool valid_room(int64_t room) const;
    bool valid_page(int64_t room, int64_t page) const;
    bool valid_endpoint(int64_t room, int64_t endpoint) const;
    int values_in_page(int room, int page) const;
    void warn(const godot::String& message) const;

    bool configured_ = false;
    bool server_authority_ = true;
    std::uint32_t revision_ = 0;
    std::array<Room, kRoomCount> rooms_{};
    std::unordered_map<std::int64_t, Client> clients_;
    std::uint64_t accepted_ = 0;
    std::uint64_t refused_ = 0;
};

void register_room_control_bank_class();

}  // namespace ashiato_gd
