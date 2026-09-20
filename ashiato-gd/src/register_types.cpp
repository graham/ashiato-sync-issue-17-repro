#include "register_types.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "core/ashiato_world.h"

#ifdef ASHIATO_GD_WITH_SYNC
namespace ashiato_gd {
void register_sync_classes();
}
#endif

#ifdef ASHIATO_GD_WITH_PHYSICS
namespace ashiato_gd {
void register_physics_classes();
}
#endif

#ifdef ASHIATO_GD_WITH_DRIVING
namespace ashiato_gd {
void register_driving_classes();
}
#endif

#ifdef ASHIATO_GD_WITH_VR
namespace ashiato_gd {
void register_vr_classes();
}
#endif

#ifdef ASHIATO_GD_WITH_COCKPIT
namespace ashiato_gd {
void register_cockpit_classes();
void register_room_control_bank_class();
// The ground as a function (src/cockpit/ground_field.cpp). Registered here rather than beside CockpitWorld so the two
// files do not have to change together.
void register_ground_classes();
// The island's mountains (src/cockpit/mountain_range.cpp), for the same reason.
void register_mountain_classes();
}
#endif

using namespace godot;

void initialize_ashiato_gd(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
    GDREGISTER_CLASS(ashiato_gd::AshiatoWorld);
#ifdef ASHIATO_GD_WITH_SYNC
    ashiato_gd::register_sync_classes();
#endif
#ifdef ASHIATO_GD_WITH_PHYSICS
    ashiato_gd::register_physics_classes();
#endif
#ifdef ASHIATO_GD_WITH_DRIVING
    ashiato_gd::register_driving_classes();
#endif
#ifdef ASHIATO_GD_WITH_VR
    ashiato_gd::register_vr_classes();
#endif
#ifdef ASHIATO_GD_WITH_COCKPIT
    ashiato_gd::register_cockpit_classes();
    ashiato_gd::register_room_control_bank_class();
    ashiato_gd::register_ground_classes();
    ashiato_gd::register_mountain_classes();
#endif
}

void uninitialize_ashiato_gd(ModuleInitializationLevel level) {
    (void)level;
}

extern "C" {
GDExtensionBool GDE_EXPORT ashiato_gd_library_init(
        GDExtensionInterfaceGetProcAddress get_proc_address,
        const GDExtensionClassLibraryPtr library,
        GDExtensionInitialization* initialization) {
    GDExtensionBinding::InitObject init_obj(get_proc_address, library, initialization);
    init_obj.register_initializer(initialize_ashiato_gd);
    init_obj.register_terminator(uninitialize_ashiato_gd);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init_obj.init();
}
}
