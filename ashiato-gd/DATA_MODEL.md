# What is in the ECS, and what is not

> Two game modules use this data model: **driving** (`src/driving/`) and **VR**
> (`src/vr/`). Most of this file describes driving, because it came first and paid for
> the lessons. What the VR module does differently is at the bottom, and the short
> version is: a head is input, and a seated player has no world pose.

Three questions get confused with each other, so this splits them:

1. **Is it an ECS component?** — does it live in the ashiato registry at all.
2. **Is it replicated?** — is it in the archetype, i.e. does it go over the wire.
3. **Who writes it?** — because a component the server owns and a component the client
   predicts behave completely differently when they disagree.

Getting these mixed up has caused most of the hard bugs in this project. Replicating input
back to its own owner made a car drive on a stale copy of the wheel. Keeping ownership in
our own component while sync looked for its own meant `set_input()` applied to nothing.
Neither produced an error message.

## Replicated: on the wire, every tick

There are **two** archetypes, both defined in `driving_world.cpp`: `"Car"` and `"Rig"`.
Everything here is authored by the **server** and sent to clients.

| Component | Fields | Audience | Mode | Bits | Car | Rig |
|---|---|---|---|---|---|---|
| `CarState` | `x y z yaw vx vy vz yaw_rate` | All | Interpolate | **119** | ✓ | ✓ |
| `CarOwner` | `client` | All | Step | 16 | ✓ | ✓ |
| `CarSetup` | `hp` | All | Step | 10 | ✓ | ✓ |
| `VehicleKind` | `kind` | All | Step | 2 | ✓ | ✓ |
| `RigState` | `hitch_yaw hitch_rate` | All | Interpolate | **26** | — | ✓ |

Two archetypes rather than one with an unused `RigState` on every car: `Replicated{}`
carries the archetype per entity, so a second one is structurally free, and it means a car
does not spend 26 bits a tick saying it has no trailer.

`CarState` is the whole simulation result — pose and motion, nothing else. Its 119 bits are
the sum of its quantisations: position 17+13+17, heading 13, velocity 15×3, yaw rate 14.
(The trace viewer shows `119 bits` on every `component_sent`, which is a pleasant way to
confirm the wire format is what you think it is.)

`CarOwner` is ours rather than sync's `NetworkOwner`, because `NetworkOwner` has no
`SyncComponentTraits` and therefore no wire format — putting it in an archetype crashes on
the first serialize.

`VehicleKind` is two bits that every machine needs before it can simulate the vehicle at
all — it picks the handling table and the shape of the body. It cannot be inferred from
the archetype, because the archetype is sync's business and the game layer never sees it.

Two bits is **four** kinds and three are used: car, rig, buggy. Adding a fifth is a wire
format change, not a table edit, so `kVehicleKinds` and this field have to move together.

`RigState` **is the entire trailer**, and that is the interesting decision in this file.
A second `CarState` for the trailer is the obvious design and it is the wrong one: two
independently interpolated poses for a rigidly coupled pair have nothing forcing the
kingpin to coincide, so on a remote machine the trailer parts from the cab and snaps back
whenever the two arrive out of step. Deriving the trailer from the cab plus one angle
makes that failure *unrepresentable* — there is no second pose that could disagree.

It is sufficient, not merely cheaper. The kingpin is a fixed point on both bodies, so the
cab's pose and the fold determine the trailer's pose exactly; and the kingpin has ONE
velocity, shared, so the cab's motion and the fold rate determine the trailer's linear and
angular velocity exactly. Nothing about the trailer is independent state, which is why a
rollback that restores those two numbers has restored the trailer with nothing left to
drift. 26 bits against 119, for a stronger guarantee.

Its `should_roll_back` threshold is 0.02 rad where `CarState`'s heading threshold is 0.14,
and the difference is entirely lever arm: 1.1° of fold is a quarter of a metre at a tandem
12.2 m behind the kingpin, which is the same order as the 15 cm the cab is held to.

`CarSetup` grew from 9 bits to 10 when the truck arrived: its range stopped at 400 hp,
which is exactly the car's, and a 450 hp tractor could not be *represented* — the quantiser
clamped it on the way to the wire and the server and every client disagreed by 50 hp with
nothing to say so. The range is 40–600 now.

`CarSetup` is the only one whose `should_roll_back` returns **true on any difference**. A
predicted car only adopts the server's values when something forces a reconciliation, and
power is never simulated by the client, so without that a power change sat unapplied until
the car happened to be corrected for an unrelated reason.

## An ECS component, registered with sync, but NOT replicated

| Component | Fields | How it travels |
|---|---|---|
| `CarInput` | `throttle steer handbrake hp_step` | client → server only, 21 bits |

Registered with `register_sync_component` and marked with `set_client_input_component`,
which is the whole contract: sync carries it from the owning client to the server, stamps
it with a frame, buffers it, and replays it during rollback.

It is **deliberately absent from the archetype**. Replicating it as well makes the server
echo each client its own input back a round trip late, and that echo lands on the predicted
car and overwrites the live input it should be predicting with. sync's own FPS example
leaves its input component out for the same reason.

Consequence worth knowing: **nobody ever learns another player's input.** Anything the
renderer wants that depends on it — which way their front wheels point, whether their tires
are sliding — has to be *inferred* from replicated state. That is why the steering angle
shown on other cars is the bicycle relation inverted, and why `tire_slip` has an estimating
path for cars this machine does not simulate.

### Taking one off the wire

Removing a replicated entity is **removing its `Replicated` component**, not destroying the
entity. The server rediscovers what it replicates from the registry's dirty frame, and what
it watches for is `each_removed<Replicated>`. An entity destroyed outright disappears
locally while the server's slot lives on, and every client keeps the car parked on the
track. `despawn_car` therefore removes the component, lets the next tick carry the removal,
and destroys the entity a tick after that.

## sync's own components

Written by us or by sync, never by the game's archetype:

| Component | Who writes it | Note |
|---|---|---|
| `sync::NetworkOwner` | **us, on both sides** | sync only ever *reads* it. A client must set it itself or `set_input()` silently applies to nothing. |
| `sync::Replicated` | us, server only | marks an entity as belonging to an archetype |
| `sync::SyncSettings` | sync | registry-wide: role, input component, component ops |

## Per-entity state that is NOT in the ECS

Kept in plain maps in `DrivingWorld`, keyed by entity, because it is derived rather than
authoritative — it is recomputed every tick from things that are:

| What | Why not a component |
|---|---|
| `bodies_` — the Box3D body per car | a handle into another library; meaningless on another machine |
| `steer_of_` — the angle the front wheels were given | derived from input and speed; the renderer asks for it by name |
| `slip_of_` — how hard each of the four tires is working | recomputed every tick; a snapshot, not history |

None of it is replicated, and none of it needs to be: every machine that simulates a car
computes the same values from the same replicated state and the same handling settings.

## Not per-entity at all

- **Handling** — the eighteen settings in `set_handling`. Per *world*, not per car, and
  never replicated: every peer is given the same values by the game, and if they ever
  differed the client would be corrected on every tick. The one exception is engine power,
  which became per-car precisely so it could differ between players.
- **The track** — built identically on the server and every client from `track.gd`. Not
  replicated because it never moves; sending immovable geometry every frame would be
  absurd. The price is that both sides must build byte-identical collision.

## Not in the ECS at all: the game layer

Everything the player sees or hears lives in Godot, keyed by entity where it needs to be:

| What | Where |
|---|---|
| car bodies, wheels, name labels, talking marker | `race.gd`, `_cars[entity]` |
| skid marks | `skid_marks.gd`, one MultiMesh |
| peer names, and the peer ↔ sync-client mapping | `Network.peer_names`, `Network.drivers` |
| chat, voice, lobby membership | Steam, via `chat_panel` / `VoiceChat` |

That last mapping exists because **sync client ids and Godot peer ids are different
numbering schemes**. Nothing else can bridge them, and confusing the two has caused a bug
in this codebase three separate times.

---

## The VR module's vocabulary

Same three questions, answered for people rather than cars.

### Replicated

Three archetypes: `"Avatar"`, `"Vehicle"` and `"Prop"`.

| Component | Fields | Mode | Avatar | Vehicle | Prop |
|---|---|---|---|---|---|
| `AvatarState` | body pose, head, both hands, grip, gestures, seat flag | Interpolate | Yes | -- | -- |
| `AvatarOwner` | `client` | Step | Yes | -- | -- |
| `BodyState` | `x y z` + quaternion + linear + angular | Interpolate | -- | Yes | Yes |
| `BodyKind` | `kind` (5 bits) | Step | -- | Yes | Yes |
| `VehicleSeats` | `occupant[4]` | Step | -- | Yes | -- |
| `HoldState` | `holder hand` + grip pose | Step | -- | -- | Yes |

### Not replicated, but on the wire

| Component | How it travels |
|---|---|
| `AvatarInput` | client -> server only, and never in an archetype |

`AvatarInput` carries the **tracked head and hand poses**, which is the decision the whole
module turns on. A car's pose is a simulation result; a head is not, so it enters the
system the way a thumbstick does. sync's input path then frame-stamps it, buffers it and
replays it during rollback, which is exactly the treatment a pose from outside the
simulation needs.

Consequence, same as driving's: **nobody ever learns another player's input.** Anything the
renderer wants that depends on it has to come from replicated state, which is why
`AvatarState` carries the hands as well.

### The cockpit module's third archetype: a round in the air

`"Shot"`, one component, `ShotState`: where the round left, how fast, which ammunition, and
-- once it is over -- where it stopped and on what. **Step**, to `All`.

One packet at the muzzle and one at the impact, and nothing in between. This is `RigState`
and `RailCar` again: a shell's whole future is its muzzle state, so sending a pose per tick
would be sending a second copy of something already determined. It is also what makes it
affordable at all -- a 25 mm cannon at 1800 rounds a minute has ninety rounds in the air.

The **server** integrates the flight and decides the impact with a ray cast along each
tick's step; clients draw the round from the record. There is nothing of anybody's input in
a shell, so there is nothing to predict and `should_roll_back` is always false.

### Guided missiles: two more archetypes, and neither is a birth record

| Component | Archetype | Mode | What it is |
|---|---|---|---|
| `SeekerState` | `Seeker` | Step | one seat's lock: whose (a client id), which missile, phase, progress, why a launch would be refused, and the TARGET as an entity reference |
| `MissileState` | `Missile` | Interpolate | a missile's pose, velocity and age, its rail and client, whether it is guided, what it ended on, and what it HIT as an entity reference |
| `CraftSystems.stores` | Vehicle | Step | a byte: which missile rails carry a missile; a launched rail's bit comes back `rearm_s` later, on the server |
| `ControlInput.buttons` bits 6 and 7 | none | client -> server | LOCK and LAUNCH, edge-detected on the server |

**A missile cannot be a birth record.** A shell's whole future is its muzzle state; a guided
missile's future depends on its target, which moves on somebody else's stick. So its pose goes
on the wire every tick it flies, ~120 bits, with a shell's velocity range because a missile at
burnout is past the 400 m/s `speed` holds. Like a shell, only the server flies it, outside
every job, and nobody predicts it.

**The lock is not on the vehicle.** On a predicted entity an authoritative value only arrives
on a rollback (see CraftSystems), and a lock changes every tick its progress moves, so on the
vehicle it would roll the pilot's world back every tick of a lock. `SeekerState` sits on an
entity nobody predicts, named by the seat's client id, which means the same on every machine.

**`stores` IS on the vehicle**, and rolls back on any difference: a launch is at most a
once-a-second event. The loopback check that the rail empties on the pilot's own machine
cannot prove that rule is needed -- the pilot's aeroplane is corrected every few ticks anyway,
even parked, and any rollback carries the whole of CraftSystems -- and its comment says so.

**Entity references work in components.** A trait that declares `references_entities = true`
is handed an `EntityReferenceContext` through `ComponentSerializationContext::userContext`
(sync's `examples/balls.cpp` does the same). The receiving machine gets ITS OWN entity id.
But the reference resolves as soon as sync has made the entity, a frame or two before that
entity's components arrive, so `drawable()` only reports a vehicle this machine's display
already holds -- the id `vehicle_states()` gives. A client joining mid-lock found that.

**Bearing and range are not on the wire.** Each machine works them out from where both
aircraft are drawn, so a lock diamond sits on the aircraft on the screen.

### A crew's cockpit: one Cabin per crew member, sent to that member alone

| Component | Archetype | Mode | What it is |
|---|---|---|---|
| `CabinOwner` | `Cabin` | Step, Snap on every client | whose (a client id), which seat, and the craft as an entity reference |
| `CabinSystems` | `Cabin` | Step, Snap | the crew's switches: four selectors, the master arm, the crew lamp |
| `CrewControls` | `Cabin` | Step, Snap | every seat's levers and the linkage they share |
| `CrewSwitches` | none: a plain ECS component on the vehicle | server only | the server's one copy of the crew's switches, which `apply_command` writes |
| `PilotOwner.peer` | `Pilot` | Step | the Godot peer that client came in on, so every machine can map peers to clients |

**Sent to its owner and nobody else**, by a decider that answers priority zero for every other client, which sync filters
before it serialises the entity (NaN until ashiato-sync 8fa08cf, where NaN began to throw in assert builds). **Snapped**, so a crew member sees a switch the tick its packet is processed, and **not
predicted**, so a switch is never a rollback of the pilot's world. See `cockpit/agents.md`, "Only the crew see into the
cockpit".

**`CrewSwitches` is deliberately not a sync component.** sync marks an entity's replicated slot dirty for any
sync-registered component that changes on it, archetype or not (`dirty_slots.hpp`), and a dirty entity costs a record.

**The heat seeker is all-aspect: a third as bright head-on as from behind, and an idle engine
is seen head-on to about 2.7 km.** Read "brighter from behind" in `cockpit_world.cpp` that way,
not as rear-aspect only. `seen_from` scores a target as heat · aspect / km², where heat is
0.15 + 0.85 · throttle on anything with thrust (0 on a glider, at any aspect) and aspect is
1 + (tail_bonus − 1) · max(0, dot(target nose, line of sight)). With the heat row's
tail_bonus 3.0 and heat_min 0.02, idle head-on is 0.15/km², seen to √7.5 km = 2739 m, and
full throttle is seen to the row's whole 3000 m. Kept that way on 2026-09-13, when the
cockpit's missile test locked an idle target head-on and it was asked whether that was
meant. Refusing head-on would take a new row key, a minimum tail dot. Neither heat_min nor
the idle term can do it, because aspect trades against range: a threshold that refuses idle
head-on at 1115 m (0.121) still accepts it at 800 m (0.234).

**The cone TAKES a lock and the gimbal HOLDS it.** A press designates the best target inside
the row's `cone` (0.07 rad for heat); every tick after that, while locking, locked and in
flight, the test is the wider `gimbal` (0.8 rad), and 0.25 s outside it is LOST. The axis is
the launcher hull's −Z. A lock that stays good at five cones off the nose is therefore
working, not leaking.

**`late` on a missile row is the buffered lag, not the lag plus the link.** sync draws an
interpolated entity at the estimated server frame minus the buffered lag
(`src/client_clock.cpp:106`), and that estimate already has the link taken out (`:208-226`).
Measured over a 4-tick link with a 5-frame lag: wound forward by the lag, a watched missile is
1.12 ticks of travel from the server's same-tick position, and 0.12 from the server's previous
tick -- the loopback ticks the server first; with the link added as well it was 3.16.

### Three decisions worth the words

**A seated player has no world pose.** `AvatarState`'s position fields mean *seat-local*
while the `seated` bit is set, and the world pose is derived from the vehicle's
`BodyState` plus the seat. This is `RigState` again: two independently interpolated poses
for a rigidly coupled pair have nothing forcing them to coincide. For a trailer that shows
up as the kingpin coming apart; for a person it is their own head leaving the cockpit.

The `seated` bit is on the wire and is not a convenience -- it selects the **quantiser**.
A standing player's origin is a point in a kilometre of playground; a seated one's is a
few millimetres of lean inside a seat. Branching on a bit the packet carries also means
deserialisation never has to consult another entity, which matters because the vehicle may
not have arrived yet.

**Occupancy lives on the vehicle.** `VehicleSeats` is one client id per seat, on the
vehicle, rather than a vehicle reference on the player. One field per seat makes a double
occupancy *unrepresentable*. The cost is that finding a player's seat is a scan; the sim
rebuilds that map once per simulated frame -- per frame, not per tick, because a rollback
replays frames without going back through `tick()`, and a seat change inside the rollback
window is precisely the case that matters.

**A held object carries a grip pose.** `HoldState` records where the object sat relative to
the palm at the instant of the grab. Without it everything is carried at its own centre,
which puts the hand inside the object -- and letting go of something your hand is inside
hands the solver a deep overlap that it resolves by firing the object away. It has to be
replicated rather than recomputed: a client learns about a grab a round trip after it
happened, so it would derive a different grip and the object would sit in a visibly
different place in your hand than in everybody else's.

### Per-entity state that is NOT in the ECS

| What | Why not a component |
|---|---|
| `bodies_`, `hands_` -- Box3D bodies per avatar, prop and vehicle | handles into another library; meaningless on another machine |
| `tags_` -- what each Box3D body is, for the contact filter | derived from `HoldState` and `AvatarOwner` every frame |
| `seat_of_`, `avatar_of_` -- reverse lookups | derived from replicated components every simulated frame |
| `release_grace_` -- how long a dropped object ignores the person who dropped it | derived from the replicated holder changing |
