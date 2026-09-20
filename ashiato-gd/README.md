# ashiato-gd

A Godot 4.7 GDExtension for the [Ashiato ECS](https://github.com/ErikGoldman/ashiato),
with [Ashiato Sync](https://github.com/ErikGoldman/ashiato-sync) replication as an
opt-in module in the same binary.

```powershell
powershell -File tools\build.ps1 -WithDriving -WithVr -WithCockpit          # what the games load
powershell -File tools\build.ps1 -WithDriving -WithVr -WithCockpit -Double  # the cockpit's double editor
```

**How long it takes, measured 2026-09-13 on this Windows machine:** 10 s for the stock
build and 8 s for `-Double` when one file changed. That was `cockpit_world.cpp` after an
edit to it and to `cockpit_components.hpp`, which only it includes, so ninja rebuilt one
object and relinked. The time includes CMake re-checking and the copy into the sibling games.
A clean build (new build directory, all of godot-cpp) was not measured; it is far longer.
Kill nothing to make room: the copy into a game fails while a Godot has that DLL open, so
check first that no cockpit, racer or vrplayground-2 is running.

**Build all three game modules every time.** `build.ps1` copies the result into every
sibling game whose `.gdextension` names the file, and cockpit, racer and vrplayground-2
all name `ashiato_gd.dll`. A build with fewer modules removes classes from all three: with
no flags it is the ECS alone, and `-WithSync -WithPhysics` leaves out `DrivingWorld`,
`VrWorld` and `CockpitWorld`. `bootstrap-windows.ps1` and `update_upstream.ps1` pass the
full set; `-WithDriving`, `-WithVr` and `-WithCockpit` each turn on sync and physics.

To use it in a new game, copy `addon/addons/ashiato/` into it, or open `addon/` directly —
a minimal Godot project that loads the extension straight from where the build writes it.

> **What is replicated and what is not** is written up in [DATA_MODEL.md](DATA_MODEL.md):
> which components exist, which go on the wire, who writes them, and what is deliberately
> kept out of the ECS. Most of the hard bugs here came from confusing those three
> questions.

> **Attempting this again?** Read [LEARNINGS.md](LEARNINGS.md) first. The architecture was
> never the hard part; nearly all the time went on a dozen failures that produce no error
> message or a misleading one, and they are all written down there.

## Using it

Components are declared **at runtime, from GDScript**. Nothing in the C++ knows what a
`Position` is:

```gdscript
var world := AshiatoWorld.new()

var Position := world.register_component("Position", {
    "x": AshiatoWorld.TYPE_F32,
    "y": AshiatoWorld.TYPE_F32,
})
var Frozen := world.register_tag("Frozen")

var e := world.create_entity()
world.add(e, Position, {"x": 1.5, "y": -2.25})
world.set_fields(e, Position, {"y": 9.0})   # partial write, marks the component dirty
print(world.get_component(e, Position))     # { "x": 1.5, "y": 9.0 }

world.add(e, Frozen, {})
world.has(e, Frozen)                        # true
world.remove(e, Frozen)
```

Field declaration order decides layout, and the layout matches what a C compiler would
produce for the equivalent struct — natural alignment, tail padding — so the bytes stay
meaningful to the ECS, to the debugger, and to sync.

## Two decisions that shape everything

### It binds the runtime API, not the templates

Ashiato's ergonomic API is compile-time: `register_component<Position>()`. Binding that
would mean a C++ change and a rebuild for **every component a game invents** — which, for
a library described as "continuing to grow", is exactly the wrong coupling.

It also has a runtime API — `ComponentDesc{name, size, alignment, fields}`,
`primitive_type()`, and `add`/`get`/`write` keyed by component entity — and that is what
is bound. The binding lays components out itself and hands the registry real primitive
type entities for each field, so anything reflecting over components sees proper types
rather than an opaque blob.

**Consequence: adding a component type costs zero C++.**

### One extension, not two

`ashiato-sync` builds *on* the ECS and pulls its own copy of ashiato through CMake
`FetchContent`. Two separate GDExtensions would each embed their own `ashiato::Registry`
— different types in different binaries — and sync would have nothing to say about the
entities the ECS extension owns.

So both compile into one library against **one** ashiato, forced via the
`ASHIATO_SYNC_ASHIATO_SOURCE_DIR` override sync exposes for this case. Note that sync's
dependency helper calls `add_subdirectory()` on ashiato itself, so when `-WithSync` is on
it is sync that brings the ECS in; adding it twice is a CMake error.

## Networked driving: how the three pieces fit

The goal is a top-down driving sim where every car is simulated by Box3D, replicated,
predicted for its own driver and interpolated for everyone else. That works, but only in
one particular arrangement.

### Box3D is linked directly, NOT through godot-box3d

`godot-box3d` installs Box3D as a `PhysicsServer3D` backend, which means **Godot** owns
the step: once per physics frame, forward only. Prediction needs the opposite — restore a
past state and re-step N times inside a single frame.

Box3D's own C API is manually stepped (`b3World_Step(world, dt, subSteps)`) and
documented as deterministic, so this extension owns the world and ashiato owns the
rewind. Sleeping is disabled on every body: a sleeping body stops integrating, and a
replay would then diverge from the original run.

**This was measured, not assumed** (`addon/tests/physics_rewind.tscn`):

| | drift |
|---|---|
| two worlds, identical inputs, 180 steps | 0.000000000 m |
| rewind 60 frames, free flight | 0.000000000 m |
| rewind 60 frames **through live ground contact** | **0.000156 m** |

Box3D's public API restores a body's transform and velocities but **not** the solver's
warm-start/contact state, so a rollback through contact is very close rather than
bit-exact. The cost is 0.16 mm over a full second of rollback — invisible on a 4 m car,
and the test fails if it ever exceeds 1 cm.

### Replicated components are C++; local ones are not

This is the one place the "zero C++ per component" property stops. `ashiato-sync`
requires an explicit `SyncComponentTraits<T>` per replicated component — a `Quantized`
type, `quantize`/`dequantize`, `serialize`/`deserialize`, plus `should_roll_back()` for
predicted components and `interpolate()` for interpolated ones. It deliberately never
picks a wire format implicitly.

So the networked set (car state, input) is a small fixed C++ vocabulary with tuned
quantisation — which is what makes it cheap on the wire — while anything **not**
replicated can still be declared from GDScript at runtime.

### Six things that will waste your day

All six cost real time to find, and none produce a useful error.

1. **An empty `connect_token` skips the handshake.** `ReplicationClient`'s constructor
   does `if (connect_token.empty()) { set_connection_state(Ready); }` — so the client
   declares itself connected, never introduces itself, and the server's `client_count()`
   stays at **0** while the client sits there "Ready" receiving nothing. Set a non-empty
   token and let the server assign the id.
2. **Never `add_client()` a peer that has not handshaked.** Registering a client by hand
   and then ticking makes the server push updates at a session the client cannot decode.
   That is an access violation, not an error message.
3. **A predicted archetype needs `should_roll_back` on EVERY replicated component in it**,
   not just the ones you expect to be corrected. `CarInput` and `CarOwner` return `false`;
   without them the archetype crashes when it starts predicting.
4. **`sync::NetworkOwner` cannot go in an archetype.** It has no `SyncComponentTraits`, so
   it has no wire format; use your own owner component (here `CarOwner`).
5. **You must set `NetworkOwner` on the client yourself.** sync routes the local player's
   input with `registry.view<const NetworkOwner>().each(...)`, and the entire client tree
   only ever *reads* that component -- nothing in sync writes it client-side. A replicated
   car therefore arrives carrying your own owner component but no `NetworkOwner`, sync
   finds no locally owned entity, and **`set_input()` silently applies to nothing**: the
   predicted car never sees the wheel. Reconcile it every tick, not at spawn -- the entity
   and the assigned client id arrive at different times.
6. **Do NOT put the input component in the archetype.** Registering it and marking it with
   `set_client_input_component` is enough: sync carries it client->server through the input
   path, records it per frame and replays it during rollback. Replicating it as well makes
   the server echo each client its *own* input back a round trip late, and that echo lands
   on the predicted car and overwrites the live input it should be predicting with. sync's
   own FPS example leaves `FpsInput` out of its archetype for this reason.

   These two compound into one symptom, which is why they are worth reading together: with
   both wrong the car still drives, because the echo supplies an input -- just a stale one.
   Holding a key looks perfect (stale == live). Releasing one shows the car carrying on for
   a full round trip and then **snapping backwards** when the correction lands.

A seventh, on the transport side: a `BitBuffer` is **bit**-addressed, so carrying only bytes
across a transport loses up to 7 bits of length and the reader runs off the end of the
packet. `take_outbound()` therefore hands back `bits` alongside `bytes`, and `deliver()`
wants both.

### The tick

```
input  ->  ashiato job steps Box3D at a fixed dt  ->  car state component
                              |                              |
                    server: authoritative                    +-> replicated
                    client: predicted, rolled back
                            on correction
```

- The sim must live in an **ashiato job**, because resimulation is what the client
  re-runs during rollback (`ReplicationClientRollbackPreparedEvent` names the frame
  window and the entities to replay).
- Fixed `dt` and fixed sub-steps, never frame-derived: a replay with a different `dt`
  is a different simulation.
- The car is four tires, not a body told how to turn: each computes a slip angle from the
  velocity of its own contact patch and applies the resulting force **at the tire**, so yaw
  is a consequence of where the grip is rather than something commanded. The shape's
  contact friction is therefore **zero** — otherwise the ground models grip a second time,
  under the middle of the car where it can only resist yaw.
- Your own car is `predict`; everyone else's is buffered interpolation, chosen per
  entity through `ReplicationClientOptions::entity_mode_selector`.
- Render sampling uses `set_fractional_tick_sampled` + `client.fractional_tick_frame()`
  so drawing between ticks does not mutate the ECS.

**Proven end to end** by `addon/tests/driving_loopback.tscn`, which runs a server and a
client in one process across a link with a 4-tick one-way delay (~133 ms round trip):

| | |
|---|---|
| client reacts to the wheel in 3 ticks | 0.214 m, before the 8-tick round trip could reply |
| client position vs server after a second of driving | **0.573 m** (the client leads by ~4 ticks) |
| steering through the replicated path | yaw −2.05 rad |
| correction while coasting | no teleport |

Transport is deliberately **not** wired to a socket: packets come out of `take_outbound()`
and go back in through `deliver()`, so the same object serves a headless test and
`SteamMultiplayerPeer` in the real game.

## Networked VR: people, not cars

`-WithVr` builds a second game module in the same shape as the driving one and against the
same three libraries. It replicates **avatars, grabbable props and pilotable vehicles**,
and the reason it is a separate module rather than more vehicle kinds is that a VR player
is not a simulation result.

### A head is input, not state

A car's pose is produced by stepping physics, so it is state and nothing else. A head and
two hands are produced by a tracking system attached to a human being. Nothing can predict
where a head is about to be, including the machine holding the headset.

So the tracked poses travel client -> server as `AvatarInput`, on sync's own input path,
which frame-stamps them, buffers them and replays them during rollback. The server writes
them into `AvatarState`, which is what everybody else receives. Your own avatar is
predicted, and predicting input you already have is simply applying it.

The Godot side never routes your own head back through the network: the rig places its
**origin** from the simulation and applies the tracker poses directly on top, every frame,
at the display rate. Head-tracking latency in VR is not a feel problem, it is a physical
one.

### A seated player has no world pose

This is the `RigState` lesson applied to people, and it is the load-bearing decision.

A seated player's pose is **derived** from the vehicle's pose and the seat index, in the
simulation and in the renderer, from the same fractional tick. Replicating a second world
pose for somebody bolted into a cockpit is the trailer-parting-from-the-cab failure the
driving module already paid for, except that what parts and snaps back is the player's own
head.

Occupancy lives on the **vehicle** (`VehicleSeats`, one client id per seat) rather than as
a vehicle reference on the player. One client id per seat makes a double occupancy
*unrepresentable*: writing a second player into seat 0 removes the first, in one field, on
the authoritative machine, in one place. It also avoids sync's entity references entirely.

Measured: over two seconds of powered flight with a pilot aboard, the offset between the
pilot and their seat moved **0.000000 m**.

### What is replicated

| Component | Archetype | Mode | What it is |
|---|---|---|---|
| `AvatarState` | Avatar | Interpolate | body pose, head and both hands, grip, gesture |
| `AvatarOwner` | Avatar | Step | whose avatar it is |
| `BodyState` | Vehicle, Prop | Interpolate | position, **full quaternion**, both velocities |
| `BodyKind` | Vehicle, Prop | Step | crate / ball / car / plane / boat |
| `VehicleSeats` | Vehicle | Step | one client id per seat |
| `HoldState` | Prop | Step | who holds it, in which hand, and the grip pose |
| `AvatarInput` | **none** | client -> server | tracked poses, two sticks, triggers, buttons |

`BodyState` carries a full quaternion where the driving module's `CarState` carries yaw
only, and that is the difference between a top-down racer and a playground: an aircraft
that cannot bank is not the same object with the roll left out, it is an object the wire
format has made impossible. Orientation is smallest-three at 32 bits.

`AvatarInput` is deliberately absent from every archetype, for the third time in this
codebase. Replicating input back to its owner makes the server echo each client its own
hands a round trip late, and your own hands then lag your real ones by the ping.

### What is predicted

Three things, and each for the same reason: this machine has the input that drives them.

- **your own avatar** -- your hands must answer your hands, not your ping
- **the vehicle you are flying** -- the stick is yours, and an aircraft that answers a
  round trip late is not flyable
- **a prop in your hand** -- it follows your hand, which is your input

Everything else is buffered interpolation. Nobody receives anybody else's input, so a
predicted entity you do not drive is a guess resimulation cannot correct; the driving
module measured that at 300 rollbacks per 300 frames.

### Interaction

Grabs, handoffs and seats are **server-authoritative structural changes**, replicated with
`should_roll_back` true on any difference so a client adopts them on the frame they arrive
rather than whenever something else happens to correct it. Taking a prop out of somebody
else's hand is allowed and is the whole handoff: one write on the server, not a protocol
between two clients.

Four things here were found by measurement and are worth knowing:

1. **A carried prop must not collide with the person carrying it.** A crate held in front
   of your chest overlaps your own capsule, so every step the solver pushed it away and
   every step the carry pulled it back; the crate sat 30 cm from the hand holding it,
   buzzing. Suppressed per-pair through Box3D's custom filter callback.
2. **A held prop must not collide with *anyone's* hands.** Suppressing it against only the
   holder was not enough: a kinematic hand always wins a contact, so reaching for a crate
   in somebody else's hand shoved it away while their carry pulled it back, and the two
   settled 34 cm apart. You could never quite reach anything anybody was holding -- which
   is exactly what a handoff is. Free props still collide with hands, so a loose ball can
   be batted around.
3. **Objects are held by a grip pose, not by their centre.** Otherwise the hand is inside
   the object: it looks wrong, and letting go hands the solver a deep overlap which it
   resolves by firing the object away. Measured: a released crate went **up 3.6 m**. The
   grip is captured at the grab and replicated, because a client learns about a grab a
   round trip late and would derive a different one.
4. **A released object ignores the person who let go of it for twelve ticks.** The grip
   usually leaves the hand on the surface, but a player who reached dead centre still
   overlaps. Driven off the replicated holder *changing*, not off the release call,
   because the release call only ever runs on the server.

### Vehicles

Cars, aircraft and boats, in one table indexed by `BodyKind`, with every tuning knob read
from a Dictionary rather than compiled in -- the driving module's lesson that a tuning
constant in C++ is a tuning constant nobody tunes.

The flight model is deliberately simple and structurally right, so a better one replaces
terms rather than the whole thing. What earns its place: lift proportional to airspeed
**squared**, a stall past which more elevator gives less lift rather than more, a fin that
resists sideslip, and controls that command a **rate** rather than a torque. The first
version applied raw torque and did not fly at all -- 24 kNm of elevator on 2700 kg m^2 of
pitch inertia turns a gentle pull into a backflip in under two seconds.

Two physics facts that cost real time:

- **A vehicle's contact friction must be near zero**, because the game models its grip
  itself and a hull dragging on its belly models it a second time. With realistic friction
  a 4200 N aeroplane on 7400 N of weight could not move at all.
- **But then a parked vehicle is on ice.** A player walking into a 750 kg aeroplane pushed
  it several metres and chased it across the field, never getting near enough to the seat
  to climb in. The answer is a parking hold that cancels residual velocity below walking
  pace whenever nobody is asking for power -- a handbrake and a wheel chock between them.

**Proven end to end** by `addon/tests/vr_loopback.gd`, which runs a server and **two**
clients in one process across a link with a 4-tick one-way delay (~133 ms round trip):

| | |
|---|---|
| own hand answers | in **1 tick**, before the link could carry it |
| the same hand on the other client | still at the old pose, then correct once packets land |
| server vs client after 1.5 s of walking | 0.17 m, the client leading by the link delay |
| pilot's offset from their seat, over 2 s of flight | **0.000000 m** |
| aircraft attitude from full aileron | 108 degrees, and 121 of them reached the other client |
| a crate taken out of another player's hand | the holder changes, and only one holder exists |
| rollbacks | **20 in 1317 ticks** |

## Keeping up with upstream

```powershell
powershell -File tools\update_upstream.ps1           # report only
powershell -File tools\update_upstream.ps1 -Pull     # pull, rebuild, verify
```

It pulls both, rebuilds, runs the conformance test, and **only then** records the
revisions in `upstream.lock` — so that file always names a combination known to work,
not merely one that happened to be checked out.

`addon/tests/conformance.gd` is the safety net: 35 checks driven entirely through the
public GDScript surface (entity lifecycle, generational handles, C-compatible layout,
every primitive width round-tripping, tags, removal, introspection, and that misuse is
reported rather than fatal). After an upstream pull the question is not "does it compile"
but "does it still behave", and that is what this answers.

For the DLL already committed with Cockpit, run the suite from a genuinely fresh addon
project with:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_conformance.ps1
```

The runner copies `addon/` without generated `.godot` state, stages the committed single
and double DLLs from `cockpit/addons/ashiato/bin/`, performs a bounded editor import, and
then runs the checks with another wall-clock deadline. Logs are preserved under the system
temporary directory. This is the clone/worktree gate; `update_upstream.ps1 -Pull` still
tests the just-built binaries before it updates `upstream.lock`.

### The two versions are not in step

`ashiato-sync` pins its own ashiato revision, and that pin lags the ECS. At the time of
writing the checkout is **8 commits ahead** of the pin — including *"big internal template
refactor"* and *"harden component metadata"* — so building sync against it is a
combination upstream has never tested.

It currently compiles, links and instantiates (`ReplicationServer`, `ReplicationClient`),
which is why sync is wired to our checkout rather than its pin. `update_upstream.ps1`
prints the gap and lists the commits sync has not seen, so this stays a visible decision
rather than a silent one.

## What is bound, and what is not

Two kinds of world come out of this library, and replication lives in only one of them.

**The game worlds replicate: `DrivingWorld`, `VrWorld` and `CockpitWorld`** (`src/driving/`,
`src/vr/`, `src/cockpit/`; built by `-WithDriving`, `-WithVr` and `-WithCockpit`, each of
which turns on sync and physics). Each one owns its own `ashiato::Registry`, its own Box3D
world and an `ashiato::sync::ReplicationServer` or `ReplicationClient` — `start(0)` makes
the server, any other id a client. Their components are C++ structs with a
`SyncComponentTraits<T>` each (`car_components.hpp`, `vr_components.hpp`,
`cockpit_components.hpp`), and the simulation is registered in C++ as sync simulation
jobs, which is what lets a client rewind and replay them on a correction. The socket is
the game's: `take_outbound()` hands out `{peer, bytes, bits}` dictionaries,
`deliver(from_peer, bytes, bits)` takes them back, and `add_client`/`remove_client` tell
the server who is there. racer drives a `DrivingWorld` (`world/race.gd`), vrplayground-2 a
`VrWorld` (`autoload/net_sim.gd`), and the cockpit a `CockpitWorld` (`autoload/sim.gd`),
each over ENet or Steam; `addon/tests/driving_loopback`, `two_clients`, `vr_loopback` and
`cockpit_loopback` run server and clients in one process.

**`AshiatoWorld` does not** (`src/core/`, always built). Bound: entities
(`create_entity`/`destroy_entity`/`is_alive`), components and tags declared from GDScript
(`register_component`, `register_tag`), `add`/`remove`/`has`, `get_component`,
`set_fields` — a partial write through the registry's `write()`, so dirty tracking
fires — and introspection (`describe_component`, `components_of`, `upstream_revision`).
Its registry has no sync attached and it has no `start`, `tick`, `take_outbound` or
`deliver`, so **a component declared here is never replicated, predicted or rolled back**.
No game in this checkout uses it; `addon/tests/conformance.gd` is its caller.

Two classes are test fixtures rather than surfaces. `AshiatoSyncProbe` (`src/sync/`) reports
the size of sync's server and client types, which only compiles if sync agrees with the
ECS it was built against, and conformance checks that it loaded. `Box3DWorld`
(`src/physics/`) is what `addon/tests/physics_rewind.gd` measures rewinding with.

**Not** bound, on either kind:

- **Replicated components from GDScript.** Sync needs a wire format, quantisation and a
  rollback threshold per replicated type, and it never picks one implicitly — see
  "Replicated components are C++; local ones are not" above. Replicated state is a C++
  struct in the game module that owns the world.
- **Views, iteration, jobs, groups, snapshots and lifecycle hooks.** The game worlds use
  views and jobs inside their C++; none of them is reachable from GDScript. Ashiato's
  views are compile-time templates, so there is no runtime "every entity with component
  X" keyed by component entity; the runtime route is `Registry::add_job` with
  `std::function` callbacks, which is a design job rather than a wrapper.
- **String fields.** Components are fixed-size blobs copied by the ECS and put on a wire
  by sync; a `std::string` field would make them non-trivially-copyable and give them a
  content-dependent size. Keep text in a Godot-side table keyed by entity.

To add to `AshiatoWorld`: bind it in `src/core/ashiato_world.cpp`, add a check to
`addon/tests/conformance.gd`, and keep the C++ ignorant of specific component types. To
add replicated state, add it to the module whose world owns it, and to that module's
loopback test.

## Layout

```
CMakeLists.txt              one extension, both modules
upstream.lock               revisions this was last verified against
src/core/                   the ECS binding
src/sync/                   replication module (-WithSync)
src/physics/                Box3D world we step ourselves (-WithPhysics)
src/driving/                networked car: components, wire format, sim job (-WithDriving)
src/vr/                     networked VR: avatars, props, seated vehicles (-WithVr)
src/cockpit/                networked multi-crew flight: vehicles, seats, guns (-WithCockpit)
addon/addons/ashiato/       the addon you copy into a game; build output lands in bin/
addon/tests/conformance.gd  the "did upstream break us" test
addon/tests/physics_rewind.gd   measures whether Box3D can actually be rewound
addon/tests/driving_loopback.gd server + client in one process, predicted and corrected
addon/tests/vr_loopback.gd      server + TWO clients: hands, seats, flight, handoff
addon/tests/cockpit_loopback.gd server + clients flying CockpitWorld in one process
addon/tests/cue_crowd.gd        every cue on an aeroplane crowded out of packets still arrives, once
addon/tests/handling_probe.gd   full-lock radius fits the RACER's lane (reads racer/world/track.gd)
tools/build.ps1             finds MSVC/cmake/ninja, stamps the revision, builds
tools/update_upstream.ps1   pull -> rebuild -> verify -> record
```

**One addon test depends on a game.** `addon/tests/handling_probe.gd` checks that a full-lock
turn fits within half the racer's lane, and takes the lane from racer's `world/track.gd`.
This project cannot load a racer script, so the probe reads that file as text, through the
path `../../racer/world/track.gd` (valid only inside this repository), and parses the line
`const LANE: float = <number>`. If racer renames, retypes or moves that constant, or moves
the file, the probe's `lane_width_is_known` check fails and names the cause. It never falls
back to a typed number, which is what keeps the limit following the track. Every other test
in `addon/tests` depends only on the extension.

Requires three upstream checkouts as siblings (`../ashiato`, `../ashiato-sync`, `../box3d`),
at the revisions in `upstream.lock`, and godot-cpp, which `CMakeLists.txt` looks for at
`../godot-cpp`, then `../_tools/godot-cpp`, then `../../tanagra/godot-cpp` (`-GodotCpp`
overrides it). None are fetched at configure time: a build that silently clones a moving
branch is not reproducible. `tools/bootstrap-windows.ps1` and `tools/bootstrap-linux.sh`
fetch them, check each out at its pin, and apply `tools/patches/` if it has anything in it (empty since ashiato-sync
8fa08cf, 2026-09-18). `build.ps1` refuses an ashiato-sync checkout that is not at its pin or has uncommitted edits.
