// Ashiato Sync module -- compiled into the SAME extension as the ECS, against the SAME
// ashiato build. See the CMakeLists header for why that is not optional.
//
// This translation unit is deliberately thin for now. Its first job is to answer a
// question that had to be answered before any replication API could be designed: does
// ashiato-sync even compile against the ashiato revision this project has checked out?
// Sync pins its own, older ECS commit (see upstream.lock), so building it against ECS
// HEAD is a combination upstream has never tested.
//
// Including the headers and naming the types is what forces that check: sync is
// heavily templated, so a TU that only linked would prove nothing.

#include <ashiato/sync/client.hpp>
#include <ashiato/sync/registration.hpp>
#include <ashiato/sync/server.hpp>
#include <ashiato/sync/sync.hpp>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>

#include "ashiato/ashiato.hpp"

namespace ashiato_gd {

// Proves the sync types instantiate against the shared registry. Replaced by the real
// replication surface once the ECS binding has been used in anger; kept small on
// purpose while both upstreams are still moving.
class AshiatoSyncProbe : public godot::RefCounted {
    GDCLASS(AshiatoSyncProbe, godot::RefCounted)

public:
    bool is_available() const {
        return true;
    }

    // Sizes of the real sync types, which only compile if the headers agree with the
    // ECS they were built against. Cheap, but it is a genuine instantiation.
    int64_t server_footprint() const {
        return static_cast<int64_t>(sizeof(ashiato::sync::ReplicationServer));
    }

    int64_t client_footprint() const {
        return static_cast<int64_t>(sizeof(ashiato::sync::ReplicationClient));
    }

protected:
    static void _bind_methods() {
        godot::ClassDB::bind_method(godot::D_METHOD("is_available"),
                                    &AshiatoSyncProbe::is_available);
        godot::ClassDB::bind_method(godot::D_METHOD("server_footprint"),
                                    &AshiatoSyncProbe::server_footprint);
        godot::ClassDB::bind_method(godot::D_METHOD("client_footprint"),
                                    &AshiatoSyncProbe::client_footprint);
    }
};

void register_sync_classes() {
    GDREGISTER_CLASS(AshiatoSyncProbe);
}

}  // namespace ashiato_gd
