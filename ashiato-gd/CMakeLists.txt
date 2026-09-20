# ashiato-gd -- one Godot 4.x GDExtension exposing the Ashiato ECS, and
# (optionally) Ashiato Sync's replication on top of it.
#
#   cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
#   cmake --build build --target ashiato_gd
#
# ONE EXTENSION, NOT TWO, and that is the whole point of this file.
#
# ashiato-sync builds on the ECS and pulls its OWN copy of ashiato through
# FetchContent. Two separate GDExtensions would therefore each embed their own
# ashiato::Registry -- different types in different binaries -- and sync would have
# nothing to say about the entities the ECS extension owns. So both are compiled
# into one library against ONE ashiato, forced here via the source-dir override
# that ashiato-sync exposes for exactly this case.
#
# Both upstreams are checkouts, not fetches. A build that silently clones a moving
# branch is not reproducible, and these two libraries are moving fast and NOT in
# step (see upstream.lock). Making the checkouts explicit is what lets
# tools/update_upstream.ps1 say which revision produced a given binary.

cmake_minimum_required(VERSION 3.20)
project(ashiato_gd CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(ASHIATO_GD_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
set(ASHIATO_DIR      "${ASHIATO_GD_ROOT}/../ashiato"      CACHE PATH "Ashiato ECS checkout")
set(ASHIATO_SYNC_DIR "${ASHIATO_GD_ROOT}/../ashiato-sync" CACHE PATH "Ashiato Sync checkout")
# godot-cpp is looked for in several places rather than one, because the one it happened
# to live in here is OUTSIDE this tree -- a sibling of the whole godotgames directory --
# and anyone who cloned only this repository could not build at all. A checkout beside
# ashiato-gd, where the other three dependencies live, is tried first.
set(GODOT_CPP_DIR "" CACHE PATH "godot-cpp checkout")
if(NOT GODOT_CPP_DIR)
  foreach(candidate
      "${ASHIATO_GD_ROOT}/../godot-cpp"
      "${ASHIATO_GD_ROOT}/../_tools/godot-cpp"
      "${ASHIATO_GD_ROOT}/../../tanagra/godot-cpp")
    if(EXISTS "${candidate}/CMakeLists.txt")
      set(GODOT_CPP_DIR "${candidate}" CACHE PATH "godot-cpp checkout" FORCE)
      break()
    endif()
  endforeach()
endif()
if(NOT GODOT_CPP_DIR OR NOT EXISTS "${GODOT_CPP_DIR}/CMakeLists.txt")
  message(FATAL_ERROR
    "godot-cpp not found. Clone it beside ashiato-gd:
"
    "  git clone -b 4.4 https://github.com/godotengine/godot-cpp.git "
    "${ASHIATO_GD_ROOT}/../godot-cpp
"
    "or pass -DGODOT_CPP_DIR=<path>.")
endif()
message(STATUS "godot-cpp: ${GODOT_CPP_DIR}")

# Sync is heavier and moves independently of the ECS; the ECS binding stands on its
# own, so sync is opt-in rather than a hard dependency of getting anything working.
option(ASHIATO_GD_WITH_SYNC "Build the ashiato-sync replication module" OFF)
option(ASHIATO_GD_WITH_TRACING "Build ashiato-sync tracing support (runtime switchable)" ON)
# THE PACKET LIFECYCLE, for reporting a sync fault upstream. Off by default: it is a
# second trace stream (every packet, every ACK, every record decode and apply) and it
# costs a measurable amount of the thing it is measuring, so it is asked for per build.
#
# Turning it on ALSO turns component data OFF, which is not an oversight. ashiato-sync
# issue #17 asks for exactly that pair, to keep the trace small and the observer effect
# down. The component NAME survives it -- it is set outside the guard, ashiato-sync
# `src/client/tracing.cpp:102` and `:118-124` -- so `CockpitWorld::received_frames`,
# which filters on "VehicleState", still measures what it measured before.
option(ASHIATO_GD_TRACE_PACKET_LOGS "Build ashiato-sync packet lifecycle logs (issue #17 capture)" OFF)
option(ASHIATO_GD_WITH_PHYSICS "Build the Box3D physics module" OFF)
# Driving is the integration of the other two, so it turns them both on rather than
# failing later with a confusing missing-header error.
option(ASHIATO_GD_WITH_DRIVING "Build the networked driving module (implies sync + physics)" OFF)
if(ASHIATO_GD_WITH_DRIVING)
  set(ASHIATO_GD_WITH_SYNC ON CACHE BOOL "" FORCE)
  set(ASHIATO_GD_WITH_PHYSICS ON CACHE BOOL "" FORCE)
endif()
# The VR module is the same integration of the same three libraries as driving, with a
# different vocabulary: avatars, grabbable props and pilotable vehicles instead of cars.
# It turns sync and physics on for the same reason driving does -- so a wrong switch is a
# clear configure decision rather than a confusing missing-header error later.
option(ASHIATO_GD_WITH_VR "Build the networked VR module (implies sync + physics)" OFF)
if(ASHIATO_GD_WITH_VR)
  set(ASHIATO_GD_WITH_SYNC ON CACHE BOOL "" FORCE)
  set(ASHIATO_GD_WITH_PHYSICS ON CACHE BOOL "" FORCE)
endif()
# The cockpit module: every player flies something. Same three libraries as driving and
# vr, arranged around a pilot having no world pose -- see src/cockpit/.
option(ASHIATO_GD_WITH_COCKPIT "Build the networked cockpit module (implies sync + physics)" OFF)
if(ASHIATO_GD_WITH_COCKPIT)
  set(ASHIATO_GD_WITH_SYNC ON CACHE BOOL "" FORCE)
  set(ASHIATO_GD_WITH_PHYSICS ON CACHE BOOL "" FORCE)
endif()

set(BOX3D_DIR "${ASHIATO_GD_ROOT}/../box3d" CACHE PATH "Box3D checkout")

if(NOT EXISTS "${ASHIATO_DIR}/include/ashiato/ashiato.hpp")
  message(FATAL_ERROR
    "Ashiato ECS not found at '${ASHIATO_DIR}'.\n"
    "  git clone https://github.com/ErikGoldman/ashiato.git ${ASHIATO_DIR}\n"
    "or configure with -DASHIATO_DIR=/path/to/ashiato")
endif()

if(NOT EXISTS "${GODOT_CPP_DIR}/CMakeLists.txt")
  message(FATAL_ERROR
    "godot-cpp not found at '${GODOT_CPP_DIR}'.\n"
    "  git clone --depth 1 https://github.com/godotengine/godot-cpp.git ${GODOT_CPP_DIR}\n"
    "or configure with -DGODOT_CPP_DIR=/path/to/godot-cpp")
endif()

# ---- godot-cpp --------------------------------------------------------------
# Pinned HERE rather than inherited from whatever the checkout defaults to: there
# is no godot-4.7 tag upstream (newest release is 4.5), so the API version is the
# thing that has to be stated explicitly. Matches the editor in _tools/godot-4.7.2.
set(GODOTCPP_API_VERSION "4.7" CACHE STRING "Godot API version to bind against")
set(GODOTCPP_TARGET "template_release" CACHE STRING "")
set(GODOTCPP_USE_HOT_RELOAD OFF CACHE BOOL "" FORCE)

# ---- DOUBLE PRECISION, which is a different binary and not a different setting ----
#
# A world ten kilometres across drawn in float32 lands every position on a grid that grows
# with distance from the origin: a third of a millimetre at the runway, half a millimetre
# out by the carrier, which at arm's length is seven times what the eye can resolve. The
# cockpit is redrawn on that grid while your head moves smoothly, and it reads as jitter.
#
# A double-precision Godot fixes it at the source, and the whole toolchain has to agree:
# the method hashes of anything taking a real_t DIFFER between the two builds, so binding
# against the wrong extension_api.json produces a library that loads and then calls the
# wrong functions. Hence the custom API file, which must be dumped from the very editor
# this is going to run in.
#
# The output carries `.double` in its name for the same reason godot-cpp's does: the float
# and the double library are both installed, side by side, and the feature tags in the
# .gdextension decide which one an editor loads. A single-precision project sharing this
# addon is untouched.
option(ASHIATO_GD_DOUBLE "Build against a double-precision Godot" OFF)
if(ASHIATO_GD_DOUBLE)
  set(GODOTCPP_PRECISION "double" CACHE STRING "" FORCE)
  if(NOT GODOTCPP_CUSTOM_API_FILE)
    message(FATAL_ERROR
      "ASHIATO_GD_DOUBLE needs the API file from a double editor:
"
      "  godot.windows.editor.x86_64.double.exe --headless --dump-extension-api
"
      "then configure with -DGODOTCPP_CUSTOM_API_FILE=<path to extension_api.json>")
  endif()
  message(STATUS "precision: double, API ${GODOTCPP_CUSTOM_API_FILE}")
endif()
add_subdirectory("${GODOT_CPP_DIR}" "${CMAKE_BINARY_DIR}/godot-cpp" EXCLUDE_FROM_ALL)

# ---- ashiato, and optionally sync -------------------------------------------
#
# EXACTLY ONE of these adds ashiato. ashiato-sync's dependency helper calls
# add_subdirectory() on ashiato itself (from ASHIATO_SYNC_ASHIATO_SOURCE_DIR when
# set, FetchContent otherwise), so adding it here as well defines the target twice
# and CMake stops with "another target with the same name already exists".
#
# When sync is on, sync is therefore the one that brings ashiato in -- pointed at
# OUR checkout, which is what keeps it a single shared ECS rather than sync's own
# pinned copy alongside ours.
set(ASHIATO_BUILD_EXAMPLE OFF CACHE BOOL "" FORCE)
set(ASHIATO_BUILD_BENCHMARKS OFF CACHE BOOL "" FORCE)
set(ASHIATO_BUILD_PROFILING OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)

if(ASHIATO_GD_WITH_SYNC)
  if(NOT EXISTS "${ASHIATO_SYNC_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "ashiato-sync not found at '${ASHIATO_SYNC_DIR}'")
  endif()
  # Tracing is a BUILD-TIME capability with a RUN-TIME switch. sync's trace calls only
  # exist if this is on, so building without it makes DrivingWorld.set_tracing() a
  # no-op that can never be turned on -- which is the worst of both worlds when you are
  # trying to find out why a client disagrees with its server. Left on by default: with
  # no tracer attached the cost is a null check per event, and the moment you want it you
  # already have it. Enabling it also forces ASHIATO_ENABLE_SERIALIZATION_TRACING on in
  # ashiato itself, which sync requires and checks for with an #error.
  if(ASHIATO_GD_WITH_TRACING)
    set(ASHIATO_SYNC_ENABLE_TRACING ON CACHE BOOL "" FORCE)
    if(ASHIATO_GD_TRACE_PACKET_LOGS)
      set(ASHIATO_SYNC_TRACE_PACKET_LOGS ON CACHE BOOL "" FORCE)
      set(ASHIATO_SYNC_TRACE_COMPONENT_DATA OFF CACHE BOOL "" FORCE)
    else()
      set(ASHIATO_SYNC_TRACE_COMPONENT_DATA ON CACHE BOOL "" FORCE)
    endif()
  endif()
  set(ASHIATO_SYNC_ASHIATO_SOURCE_DIR "${ASHIATO_DIR}" CACHE PATH "" FORCE)
  set(ASHIATO_SYNC_BUILD_BENCHMARKS OFF CACHE BOOL "" FORCE)
  set(ASHIATO_SYNC_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
  set(ASHIATO_SYNC_BUILD_FUZZERS OFF CACHE BOOL "" FORCE)
  add_subdirectory("${ASHIATO_SYNC_DIR}" "${CMAKE_BINARY_DIR}/ashiato-sync" EXCLUDE_FROM_ALL)
else()
  add_subdirectory("${ASHIATO_DIR}" "${CMAKE_BINARY_DIR}/ashiato" EXCLUDE_FROM_ALL)
endif()

# ---- Box3D (optional) -------------------------------------------------------
#
# Box3D is linked DIRECTLY rather than going through the godot-box3d addon, and that
# distinction is the whole reason rollback is possible.
#
# godot-box3d installs Box3D as a PhysicsServer3D backend, which means GODOT decides
# when it steps -- once per physics frame, forward only. Prediction needs the opposite:
# to restore a past state and re-step N times inside a single frame. Box3D's own C API
# is manually stepped (b3World_Step(world, dt, subSteps)) and documented as
# deterministic, so owning the world here gives ashiato the rewind it needs.
if(ASHIATO_GD_WITH_PHYSICS)
  if(NOT EXISTS "${BOX3D_DIR}/CMakeLists.txt")
    message(FATAL_ERROR
      "Box3D not found at '${BOX3D_DIR}'.
"
      "  git clone https://github.com/erincatto/box3d.git ${BOX3D_DIR}")
  endif()
  set(BOX3D_SAMPLES OFF CACHE BOOL "" FORCE)
  set(BOX3D_BENCHMARKS OFF CACHE BOOL "" FORCE)
  set(BOX3D_UNIT_TESTS OFF CACHE BOOL "" FORCE)
  set(BOX3D_VALIDATE OFF CACHE BOOL "" FORCE)
  add_subdirectory("${BOX3D_DIR}" "${CMAKE_BINARY_DIR}/box3d" EXCLUDE_FROM_ALL)
endif()

# ---- the extension ----------------------------------------------------------
set(ASHIATO_GD_SOURCES
  src/register_types.cpp
  src/core/ashiato_world.cpp
  src/core/variant_bridge.cpp)

if(ASHIATO_GD_WITH_SYNC)
  list(APPEND ASHIATO_GD_SOURCES src/sync/ashiato_sync_node.cpp)
endif()

if(ASHIATO_GD_WITH_PHYSICS)
  list(APPEND ASHIATO_GD_SOURCES src/physics/box3d_world.cpp)
endif()

if(ASHIATO_GD_WITH_DRIVING)
  list(APPEND ASHIATO_GD_SOURCES src/driving/driving_world.cpp)
endif()

if(ASHIATO_GD_WITH_VR)
  list(APPEND ASHIATO_GD_SOURCES src/vr/vr_world.cpp)
endif()

if(ASHIATO_GD_WITH_COCKPIT)
  list(APPEND ASHIATO_GD_SOURCES src/cockpit/cockpit_world.cpp src/cockpit/ground_core.cpp src/cockpit/ground_field.cpp
       src/cockpit/bedrock.cpp src/cockpit/room_control_bank.cpp src/cockpit/height_pyramid.cpp
       src/cockpit/range_core.cpp src/cockpit/massif.cpp src/cockpit/mountain_range.cpp)
endif()

add_library(ashiato_gd SHARED ${ASHIATO_GD_SOURCES})
target_include_directories(ashiato_gd PRIVATE src "${ASHIATO_DIR}/include")

set(ASHIATO_GD_UPSTREAM_REV "unknown" CACHE STRING "ashiato revision being compiled")
target_compile_definitions(ashiato_gd PRIVATE
  ASHIATO_GD_UPSTREAM_REV="${ASHIATO_GD_UPSTREAM_REV}")
target_link_libraries(ashiato_gd PRIVATE godot-cpp)

# The ECS target name differs between upstream revisions; take whichever exists so
# a rename upstream is a clear configure error rather than a link failure.
if(TARGET ashiato::ashiato)
  target_link_libraries(ashiato_gd PRIVATE ashiato::ashiato)
elseif(TARGET ashiato)
  target_link_libraries(ashiato_gd PRIVATE ashiato)
else()
  message(FATAL_ERROR "No 'ashiato' target after add_subdirectory -- upstream renamed it?")
endif()

if(ASHIATO_GD_WITH_SYNC)
  target_compile_definitions(ashiato_gd PRIVATE ASHIATO_GD_WITH_SYNC=1)
  if(ASHIATO_GD_WITH_TRACING)
    target_compile_definitions(ashiato_gd PRIVATE ASHIATO_GD_WITH_TRACING=1)
  endif()
  target_include_directories(ashiato_gd PRIVATE "${ASHIATO_SYNC_DIR}/include")
  if(TARGET ashiato::sync)
    target_link_libraries(ashiato_gd PRIVATE ashiato::sync)
  elseif(TARGET ashiato_sync)
    target_link_libraries(ashiato_gd PRIVATE ashiato_sync)
  else()
    message(FATAL_ERROR "No 'ashiato_sync' target after add_subdirectory")
  endif()
endif()

if(ASHIATO_GD_WITH_PHYSICS)
  target_compile_definitions(ashiato_gd PRIVATE ASHIATO_GD_WITH_PHYSICS=1)
  target_link_libraries(ashiato_gd PRIVATE box3d)
endif()

if(ASHIATO_GD_WITH_DRIVING)
  target_compile_definitions(ashiato_gd PRIVATE ASHIATO_GD_WITH_DRIVING=1)
endif()

if(ASHIATO_GD_WITH_VR)
  target_compile_definitions(ashiato_gd PRIVATE ASHIATO_GD_WITH_VR=1)
endif()

if(ASHIATO_GD_WITH_COCKPIT)
  target_compile_definitions(ashiato_gd PRIVATE ASHIATO_GD_WITH_COCKPIT=1)
endif()

# /bigobj, AND IT IS NOT A TUNING KNOB: cockpit_world.cpp is a single 1.3 MB translation
# unit, and a build carrying debug info emits enough extra per-function sections to pass
# the COFF limit -- "fatal error C1128: number of sections exceeded object file format
# limit", 2026-09-20, on the RelWithDebInfo build upstream asked for on ashiato-sync
# issue #17. Release fits by luck. Without this, -BuildType RelWithDebInfo cannot compile
# this library at all, which is a poor thing to discover while a maintainer is waiting.
if(MSVC)
  target_compile_options(ashiato_gd PRIVATE /bigobj)
endif()

# Land straight in the addon so the demo project picks the build up with no copy step.
set_target_properties(ashiato_gd PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY "${ASHIATO_GD_ROOT}/addon/addons/ashiato/bin"
  RUNTIME_OUTPUT_DIRECTORY "${ASHIATO_GD_ROOT}/addon/addons/ashiato/bin"
  PREFIX "")
if(ASHIATO_GD_DOUBLE)
  set_target_properties(ashiato_gd PROPERTIES OUTPUT_NAME "ashiato_gd.double")
endif()
