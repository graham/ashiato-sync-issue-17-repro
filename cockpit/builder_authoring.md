# Craft and cockpit authoring

This is the durable authoring boundary for Cockpit. A craft is not a station scene with a
different mesh: its model frame, physical seats, simulation system schema and station
layouts must agree on every peer.

## The documents

An authored package has one immutable revision folder:

```text
<craft-id>/<version>/
  craft.json
  stations/seat0.json
  stations/seat1.json
  devices/<stable-device-id>.json       # next step, when a device has parameters beyond a control
```

`craft.json` owns presentation identity: a model reference, paint, model-origin units,
allowed device types, and a map from seat number to station document. It records the
native seat poses and simulation contract hash it was made against. Today those native
facts are copied read-only; the first custom flyable craft will be registered before a
session starts by C++ and will expose its own hash.

`station.json` owns only station-local presentation: stable device id, type, local
transform, label and declared binding. It never owns projectile mounts, collider geometry,
or a rider transform. Its coordinate frame is the seat anchor, with Godot's `-Z` forward.

`device.json` is reserved for data that is not geometry: configuration options and a
semantic binding. A physical button, MFD key and guarded switch can share a binding. Device
ids are never regenerated during a move, which makes undo, diff, collaboration and
telemetry meaningful.

### Checked-in baseline revision

`res://craft/<kind>/1/` now contains an immutable baseline for all 23 native craft kinds:
23 craft manifests and 79 seat documents. Each seat document records its normal editable
controls plus a census of the fitted controls, shell and furniture produced by the current
scene. `tests/stations.tscn` fits every seat through the real `CockpitStation.fit` path and
compares those values numerically, so a scene edit must be accompanied by a deliberate new
package revision or regeneration of revision 1 while it remains the baseline.

`AuthoredCraftPackages` is the strict read-only boundary. It rejects a missing, malformed,
wrong-kind, stale-contract or hash-mismatched revision as a whole. `VehicleView` builds
runtime stations directly from these documents and falls back to the matching legacy scene
only when the whole authored revision is refused. The generator is
`res://tools/generate_authored_packages.tscn`; run it only when deliberately updating the
baseline, with the production double-precision editor used by `tests/run_all.ps1`.

Every manifest carries an explicit `allowed_devices` list. `VehicleCatalogue.allowed`
exposes it with the complete legacy bin as an explicit fallback for an absent or malformed
manifest. The BUILD page, direct add path, saved-layout application and package save/load
all enforce that same list and the native fitted-channel schema. Generic unwired panel
devices remain available for experimentation; channel-specific controls appear only where
the craft fits their channel. BUILD uses two readable columns and scrolls vertically rather
than clipping long device names or shrinking headset targets.

## Authority and collaboration

Solo runs through the same host-authoritative revision path as a networked builder. A
client sends an operation only on release: add, delete, move, rotate or rebind. The host
checks the expected revision, seat ownership, bounds, allowed device type, stable id and
simulation schema, then increments the revision and relays the accepted operation. It
writes an atomic immutable revision only after validation.

Seat positions and simulation tuning are host-only and pre-session changes. They influence
the native rider and rollback state, so they cannot be live-edited in a running multiplayer
world. A peer compares `simulation_contract` and package manifest hashes before joining;
different files refuse instead of making two machines fly different aircraft.

Devices report a `CockpitCommand`: `{device_id, binding, value, phase, local_hit_pose}`.
`DeviceSignalRouter` resolves the stable device id and semantic `bus.<channel>` binding,
checks the fitted schema range, rejects forged/invalid/non-finite input, then quantizes to
the existing integer command bus and calls `VehicleView.propose` / `Sim.send_command`.
That is an input frame to the authoritative server, not a new RPC: it retains rollback,
server channel/seat validation, coalescing and replication. Hit XYZ is local interaction,
haptics and visual data; it is never put on the simulation wire. The router's contract is
held by `tests/device_router.gd`, including 100, 250 and 500 endpoint loads.

Many physical devices may mirror the current bounded channels. They must not mint channel
numbers from JSON: the native wire accepts the existing fitted channels only. Hundreds of
independent replicated functions require a pre-session `SignalRegistry` plus a versioned
native ECS component, wider sequence/ack state for edge actions, server rate limits and a
manifest join gate. Until that native extension exists, authoring rejects such a binding
instead of claiming it will network.

The current native contract is four seats and 16 bus channels. Hundreds of physical
controls are valid when they mirror shared functions. Hundreds of independent replicated
functions need a new data-driven native systems component and wire format before authoring
them; a station file must not pretend otherwise.

## World control-bank seam

`device_yard` is the scale fixture for devices that are mounted in a level instead of a
cockpit. It declares `alpha` and `bravo`, each with the same configurable 1–500 endpoint
count, as hashed level content. The `DeviceYard` node gives each endpoint a stable
`room/index` address and draws it with one `MultiMesh` per bank.

The Godot bridge feature-detects three native methods on `Sim.client`:
`room_control_configure(room, revision, count)`, `room_control_state(room, revision)`,
and `room_control_submit(room, revision, index, value)`. State is a complete `0..255`
vector for one room and registry revision. The bridge rejects a short or malformed vector
as a whole, sends no optimistic visual update, and changes an indicator only after the
authoritative state comes back. An installed build without this API leaves the level
explicitly **OFFLINE**, so it can never impersonate synchronized control.

`tests/device_yard_bridge.gd` uses a fake native bank to prove registry identities,
room isolation, full-vector rejection and request-then-authoritative-echo behavior. The
native implementation still has to enforce room membership, revision, endpoint range,
rate limits, page sequence and replication scope; presentation validation cannot prove
those server properties.

### Player interaction

`DeviceYard` also exposes an authored world-pointer seam for its GPU-instanced endpoints.
The level hands that one target to `PilotRig`; on desktop the mouse ray and in VR the
pointing-hand ray ask the same `world_pointer_hit` method for the nearest stable
`{room_id,index}` address within Segway reach. A trigger or left-click press edge calls
`world_pointer_press`, which requests an off/on byte through `submit_endpoint`. It never
sets the panel state locally. A small yellow hover marker is local feedback only; the
panel changes only when `room_control_state` returns an authoritative page.

This is intentionally an explicit target list, not a scene-tree or physics query. The
yard uses `MultiMesh` and has no per-endpoint collision bodies, and explicit registration
prevents arbitrary world geometry or a different room's node from becoming a control.
`tests/device_yard_interaction.tscn` drives the real seated `PilotRig.force_hand` and
`force_input` path; it must show one native request followed by replicated state before
this interaction is claimed as working.

## Builder milestones

1. **Now:** versioned package save/load for an existing craft; package records the model
   frame, seats and native schema. The iPad has SAVE PACKAGE and LOAD PACKAGE beside the
   existing personal working-layout actions.
2. **Station library:** complete for the native fleet. Checked-in immutable JSON is the
   runtime source for 79 seats, numeric scene/package/runtime equality guards migration,
   malformed packages fall back as a whole, and the iPad plus every loading path enforce
   per-craft allowed devices.
3. **Builder room:** one parked preview craft at its actual model origin, seat ghosts and
   station selector; host-owned revisions and paced long-message transfer.
4. **Native custom craft:** `CustomCraftRegistry` loads a validated package before worlds
   start, with bounded airplane/helicopter/boat templates, model ref, seat poses and
   manifest join gate. No arbitrary runtime scripts or live physics edits.
5. **Scale test:** device farm at 100, 250 and 500 controls, including buttons, MFDs and
   axes. It measures routing correctness, duplicate command prevention, allocations,
   frame time, packet bytes and convergence.

## Device Yard completion gates

### Visual density gallery

`device_yard_gallery.bat` renders the actual `DeviceYard` node at **100, 250 and 500** endpoints per room and saves
one inside-the-room PNG for **alpha** and **bravo** at each density. The six images are visual evidence of density and
context only. They include a labelled **SEGWAY SEAT ORIGIN** marker because a Segway has deliberately no rendered hull;
they do not claim a made-up Segway model is in the game. Run `tests/device_yard_level.tscn` for the real level/seat
path and `tests/room_transport.tscn` for authoritative request and replication behaviour.

The Device Yard is the production testbed for large shared device banks. It has two rooms,
`alpha` and `bravo`, and players remain in Segways. A density is session content (`1..500`
endpoints per room; test presets 100, 250 and 500), never a local graphics knob.

1. Native paged `RoomControlBank`: 32 byte-valued endpoints per page, per-room revision,
   server membership/range validation and dirty-page extraction.
2. World endpoint bridge: stable `{room,index}` registry, authoritative-state-only drawing
   and no offline fake success.
3. Dedicated input-frame and sync record: room request plus paged state replication; no
   Godot RPC. It must survive rollback, loss, reordering, reconnect and late join.
4. Two-peer room proof: a change in Alpha converges for Alpha peers, Bravo stays unchanged,
   and a cross-room request is refused by the server.
5. Load proof: 100, 250 and 500 endpoints per room under sustained mixed changes; report
   accepted/deduplicated/refused requests, packet bytes, page count, convergence and tick cost.
6. Adversarial proof: malformed identities/ranges, stale revision, sequence replay,
   queue saturation, reconnect and late-join snapshot all refuse or recover predictably.
7. Human proof and release: exterior screenshots for both rooms at every density, desktop
   and VR interaction pass, native extension built, then the relevant full suite passes
   without engine errors.

Do not call the yard production-ready until all seven gates have evidence in the test logs.

## Visual device catalogue

Run `device_gallery.bat` on Windows or `device_gallery.sh` on Linux to render one dated
PNG for every placeable `ControlCatalogue` part. Each image uses the real setup/model path,
a useful visible state, a fitted three-quarter camera and a two-centimetre reference grid.
Use `--device=GuardedToggleSwitch` for one device or `--out=<folder>` to redirect the set.
The job ends with `RESULT=PASS <saved> of <scheduled>` only when every catalogue entry was
built, measured and saved.

### Gates 4--6 evidence (2026-09-16)

`res://tests/room_load_proof.tscn` is a three-world ashiato-sync loopback. It does not
write server room state: all changes enter `CockpitWorld.room_control_submit`, travel in
`ControlInput`, are admitted by the seated-Segway room check, then return as replicated
`RoomControlPage` state. It proves Alpha convergence for a peer seated in Bravo, preserves
an unchanged Bravo bank, rejects a cross-room request, rejects local stale/range requests,
replays real captured client packets after a newer request, saturates the bounded queue,
and verifies both late join and a removed/reused client id receive a normal page baseline.

The reference run on the double Windows build reported these complete two-room sweeps:

| endpoints / room | accepted | deduplicated | refused | pages | packets | payload bytes | convergence ticks |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 100 | 200 | 198 | 0 | 8 | 816 | 91,510 | 203 |
| 250 | 500 | 498 | 0 | 16 | 2,024 | 250,936 | 503 |
| 500 | 1,000 | 998 | 0 | 32 | 4,032 | 592,926 | 1,002 |

Those payload counters cover both directions and include ordinary session traffic; they
are a reproducible transport cost, not a claim about ENet/IP headers. The same run measured
13,642, 38,542 and 94,401 microseconds respectively for the complete loopback pump, so use
the emitted `convergence_ticks` and timing line for comparison on another machine.

## Fleet model backlog

The runtime vehicle scenes are procedural previews; C++ currently holds extents and seat
poses. Detailed procedural models already exist for the centre-console launch, patrol
gunboat, carrier, battleship, brig, Hawkeye and submarine. The following are useful first
reference-model upgrades because their station layouts matter: Cessna 172 high-wing,
AC-130-style gunship, V-22 Osprey and CH-47 Chinook. The tanker and generic plane need a
chosen real type before copying a silhouette or station geometry.

The audited type choices, stable model/station contract, asset layout, execution order and
acceptance evidence are in [`aircraft_model_fidelity_plan.md`](aircraft_model_fidelity_plan.md).
In particular, add the F/A-18F and E-6B as new craft kinds instead of silently changing the
physics and saved packages of an existing generic craft.

Reference sources for those upgrades are the U.S. Navy's E-2 and V-22 fact files,
the U.S. Air Force AC-130J fact file, and the U.S. Navy Virginia-class fact file. Use
licensed source material and record source, scale, model origin and collider fit beside
each imported model.
