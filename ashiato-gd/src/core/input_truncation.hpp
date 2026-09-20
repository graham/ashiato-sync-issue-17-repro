#pragma once
/// HOW MANY INPUT FRAMES A PACKET MAY HOLD, AND HOW OFTEN THE MTU CUT ONE: counters for `timing()`, not an error.
///
/// Since ashiato-sync 8fa08cf the client sends the newest contiguous unacknowledged input frames every tick, up to the
/// protocol's input count (`protocol::max_input_count`, 31), and when the MTU cannot hold them all it drops the OLDEST.
/// Those are the frames the server most likely has already, so a cut is the ordinary state of a client whose round trip
/// is longer than a packet holds, and not a fault.
///
/// WHAT WENT BEFORE. Until 2026-09-18 this was `InputTruncationWatch`, which pushed an error at most once a second
/// whenever a packet was cut below `input_frames_per_packet` (8), our own cap from
/// tools/patches/ashiato-sync-send-newest-inputs-first.patch. Upstream took the newest-first half of that patch and
/// not the cap, and counts a cut below its 31-frame window, which at 120 Hz happens to any input past about 40 bytes a
/// frame on a long link. An error there would turn the run_all error gate red over a harmless trim. What would
/// actually be wrong -- the server stepping on stale input -- is `input_starved` on the server's trace, and
/// cockpit/tests/input_window.gd checks that at every link instead.

#include "ashiato/sync/sync.hpp"

#include <godot_cpp/variant/dictionary.hpp>

#include <cstdint>

namespace ashiato_gd {

struct InputPacketCounters {
    /// The three numbers `timing()` reports, so a test asks the library rather than keeping its own copy of the cap.
    static void describe(const ashiato::sync::ReplicationClient& client, godot::Dictionary& out) {
        const auto stats = client.observability_stats();
        out["input_frames_max"] = static_cast<int64_t>(ashiato::sync::protocol::max_input_count);
        out["input_packets_truncated"] = static_cast<int64_t>(stats.input_packets_truncated);
        out["input_frames_truncated"] = static_cast<int64_t>(stats.input_frames_truncated);
    }
};

}  // namespace ashiato_gd
