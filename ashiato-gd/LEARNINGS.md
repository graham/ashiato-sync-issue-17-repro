# Integrating ashiato + ashiato-sync + Box3D into Godot

Written after building `ashiato-gd` and the `racer` slice, for whoever attempts this
again — probably me, probably having forgotten most of it.

The short version: **the architecture was never the hard part.** The three libraries fit
together well and the design settled in about an hour. Nearly all the time went on a
handful of failures that produce no error message, or a misleading one. Those are in
[Traps](#traps), which is the section worth reading first.

---

## What the three libraries are

| | what it is | how it is used here |
|---|---|---|
| **ashiato** | C++17 sparse-set ECS | the source of truth for game state |
| **ashiato-sync** | fixed-tick predictive networking on top of that ECS | replication, prediction, rollback, interpolation |
| **Box3D** | Erin Catto's C17 rigid-body engine | the actual car simulation |

They are not peers. `ashiato-sync` **depends on** `ashiato` and pins its own revision of
it. Box3D is independent of both.

---

## Decisions that held up

### One extension, not two

`ashiato-sync` pulls its own copy of `ashiato` through CMake `FetchContent`. Two separate
GDExtensions would each embed their own `ashiato::Registry` — different types in different
binaries — and sync would have nothing to say about the entities the ECS extension owns.

Both must compile into **one** library against **one** ashiato, forced with the
`ASHIATO_SYNC_ASHIATO_SOURCE_DIR` override sync exposes for exactly this.

Corollary: sync's dependency helper calls `add_subdirectory()` on ashiato **itself**, so
when sync is enabled it must be the thing that brings the ECS in. Adding it in both places
is a CMake error (`another target with the same name already exists`).

### Bind ashiato's runtime API, not its templates

Ashiato's ergonomic surface is compile-time: `register_component<Position>()`. Binding
that means a C++ change and a rebuild for **every component a game invents**.

It also has a runtime API — `ComponentDesc{name, size, alignment, fields}`,
`primitive_type()`, and `add`/`get`/`write` keyed by component entity. Binding *that* lets
GDScript declare components at runtime, and adding a component type costs zero C++.

**But this stops at the network boundary** — see below.

### Link Box3D directly, NOT through godot-box3d

This is the decision the whole driving idea rests on, and it looked impossible at first.

`godot-box3d` installs Box3D as a `PhysicsServer3D` backend, which means **Godot** owns
the step: once per physics frame, forward only. Prediction needs the opposite — restore a
past state and re-step N times inside a single frame.

Box3D's own C API is manually stepped (`b3World_Step(world, dt, subSteps)`) and documented
as deterministic. Owning the world inside the extension gives ashiato the rewind.

**Rollback fidelity, measured** (`addon/tests/physics_rewind.tscn`):

| | drift |
|---|---|
| two worlds, identical inputs, 180 steps | 0.000000000 m |
| rewind 60 frames, free flight | 0.000000000 m |
| rewind 60 frames **through live ground contact** | **0.000156 m** |

Box3D's public API restores a body's transform and velocities but **not** the solver's
warm-start/contact state, so a rewind through contact is very close rather than bit-exact.
0.16 mm over a full second of rollback is invisible on a 4 m car. **Measure this again if
the physics version changes** — the whole approach depends on it staying small.

Two things make it work: **sleeping must be disabled** on every predicted body (a sleeping
body stops integrating, so a replay diverges), and `dt` and sub-steps must be **fixed**,
never frame-derived (a replay with a different `dt` is a different simulation).

### Step the world ONCE per tick, not once per entity

The obvious shape — one job that, per car, pushes state in, applies forces, steps, and
reads back — is wrong. It advances the whole Box3D world once **per car**: N times the
physics work, and whichever car the job reaches first is simulated against neighbours
still sitting at last tick's positions.

That is not a rounding error. A symmetric head-on collision settled **3 m off centre**,
which in a racing game is an unfairness rather than an inaccuracy.

The fix is two ordered jobs over the same cars: push state and forces (order -1), then
step once and read back (order 0), with the step guarded by a flag the push half clears.
Both halves must be **simulation jobs**, because rollback replays them and the physics has
to advance exactly once per replayed frame too. A singleton "world" entity would be the
tidier idiom — it is how the FPS example does once-per-frame work — but that example
registers such jobs server-side only, and a client-side step has to be replayed.

### Smooth presentation needs THREE more trait hooks, and they gate each other

`set_fractional_tick_sampled()` is how render code samples a component between ticks
without mutating the ECS — sampling interpolated entities from the buffered timeline and
predicted ones from prediction history. It is much better than lerping the last two ECS
ticks in the renderer, because each entity is drawn from the timeline that actually
applies to it and a car whose next frame has not arrived holds its last good sample rather
than stuttering.

**It silently returns `false` unless the component's traits provide `compute_error`,
`apply_error` and `blend_out_error`** (plus a nested `Error` type). Nothing else reports
it: the mark just does not take, `fractional_tick_frame()` comes back empty, and the
renderer quietly has nothing to draw.

The gating is deliberate and worth understanding rather than working around. Those three
hooks are what turn a server correction from a **snap** into a pull-in: remember the
difference as a visual offset, put the simulation where the server says immediately, and
shrink the offset over the next few frames. Sampling a car between frames would be
pointless if a correction teleported it anyway.

`blend_out_error` must be **exponential in `dt`**, not a fixed fraction per frame, or the
correction fades at different speeds on different machines.

### The simulation must be an ashiato job

Rollback re-runs ECS jobs for the affected frames. So the sim cannot be something you call
once per frame yourself — it has to be a `ReplicationClient::simulation_job`, which tags it
`PredictiveSimulationJob`.

The job pushes the ECS component into the Box3D body, drives it, steps, and reads the
result back. **That round trip is what lets rollback rewind the physics too**: restoring
the component restores the body.

---

## Where "zero C++ per component" stops

`ashiato-sync` requires an explicit `SyncComponentTraits<T>` per replicated component:

- `Quantized` type, `quantize` / `dequantize`
- `serialize` / `deserialize`
- `should_roll_back(predicted, authoritative)` — **required for predicted components**
- `interpolate(from, to, alpha)` — **required for components marked `Interpolate`**

It deliberately never picks a wire format implicitly. So the **replicated vocabulary is a
small fixed C++ set**, while anything not replicated can still be declared from GDScript.

That is the right trade rather than a limitation: quantisation is what makes replication
cheap, and it can only be chosen with knowledge of the units. A car needs a centimetre over
a few hundred metres, not 32 bits of float per axis.

`should_roll_back` should be a **threshold, not equality**. Prediction is never bit-exact —
the quantised wire value alone guarantees that — and rolling back every frame feels worse
than not predicting at all.

---

## Building against ashiato-sync well

The sections above are what the integration IS. This one is how to work on it without
losing days, written after two rounds of lanes (2026-09-14 to -17) in which nearly every
expensive mistake was one of three shapes: believing a name, believing a count, or blaming
the library. [Traps](#traps) below is the catalogue; this is the method.

### What the library actually does, versus what its names suggest

**Revised for `8fa08cf` (2026-09-18).** Upstream renamed the prioritizer and changed what a
priority of zero means; the points below are as they stand at that revision, and each one that
changed says what it was. The names: `options.prioritizer` is `entity_replication_decider`,
`ReplicationPriorityObject` is `EntityReplicationDecisionContext`, `ReplicationPriorityDecision`
is `EntityReplicationDecision`, and `prioritizer_interval_frames` is
`entity_replication_decision_interval_frames`. `learnings/2026-09-18-upstream.md` has the move.

First confirmed in sync's own source at `90f50bf`, most of it by the throwaway Catch2 probe
`probe-priority-semantics.test.cpp` that `lane/upstream` wrote on 2026-09-17 and by the PRs
that came out of it. **`learnings/2026-09-17-upstream.md` has the full list with line
numbers; this is the part a game author trips over.**

**A positive priority is a send-rate WEIGHT, not a rank; zero or less is a filter.**
`UpdateScheduler::send_client` adds each candidate's `last_priority` to a per-client
accumulator every tick, sorts by the accumulator descending, and resets a sent entity's
accumulator to zero (`client_update_scheduler.cpp`). A candidate that does not fit the budget
is **skipped**, not the end of the tick -- until `max_budget_refusals_per_client_tick` records
have been refused, when the loop stops for that client. **Upstream's default for that is 2**;
it was unbounded before 8fa08cf. The cockpit sets it explicitly, to 2, by an A/B: half the host
tick at 200 craft for under 1% of the packing (`CockpitWorld::set_budget_refusals`).

- **Zero or less WITHHOLDS, since 8fa08cf** (`is_filtered_priority`, `!(p > 0)`). Before it,
  a priority-0 entity was still sent when budget was left over, and could starve for ever
  (one priority-0 entity among four at 1, a budget of one record a tick: sent 0 times in 60).
- **NaN THROWS `std::invalid_argument` in any build with asserts** (`!NDEBUG` or
  `ASHIATO_SYNC_ENABLE_ASSERT`), and in a Release build it reads as filtered because
  `!(NaN > 0)`. It was the only way to withhold before 8fa08cf; use `0.0f` now.
- **A withheld entity is NOT frozen while it still has unsent changes.** `send_client` skips a
  filtered entry before the entity is serialised or given that client a network id, and the
  decider is asked again **every** tick while it stays filtered, whatever
  `entity_replication_decision_interval_frames` says. So the entity goes out on the tick the
  decider returns a positive number, with no component change in between. What is never re-asked
  is a **quiet, acknowledged** entity — which is why a relevance or a mask that closes on a
  quiet entity is noticed only when that entity next changes, and why an audience should
  never change on a live entity. Give each audience its own entity and create or retire it.
  *(An earlier version of this file said NaN freezes the entity. The probe corrected it.)*
- **"Dirty" means UNACKNOWLEDGED, not changed.** An entity stays queued until the client acks
  (`server/server_client_replicator.cpp:399-402`), and on send the entry's `dirty_frame` is
  set to the frame that was *sent* (`client_update_scheduler.cpp:275`). Entities are resent
  until acked.
- **A default-constructed `EntityReplicationDecision` has priority 1.0**, as the built-in
  decider returns. Before 8fa08cf the struct said 0.0, so a custom prioritizer that forgot to
  set `priority` demoted every entity in the game, silently.
- **A component mask that GAINS a bit invalidates that client's baseline** (8fa08cf), so the
  next record is a full one, and a `baseline_epoch` stops a stale acknowledgement restoring the
  old baseline. A re-queued entity keeps its client's mask. Both were local patches here before.
- **`entity_replication_decision_interval_frames` is a per-SLOT bucket**, `slot % interval == frame % interval`
  (`client_update_scheduler.cpp:313`), not a per-entity countdown. 0 means every tick.
- **The reference boost is `float max / 2`** (`server/detail.hpp:14`) — "ahead of everything" —
  and it is set while serialising a record the budget may still refuse.

**Other names that mislead, each already paid for:**

- **`bandwidth_limit_bytes_per_tick` is charged BYTES**, including
  `transport_overhead_bytes_per_packet` (28 by default), not payload bytes — and it is per
  TICK, so the same number is half the bandwidth at 60 Hz as at 120. Keep one number in bytes
  a second and divide by the tick rate.
- **`should_roll_back` is a threshold, not equality.** Prediction is never bit-exact — the
  quantised wire value alone guarantees it — and rolling back every frame feels worse than not
  predicting at all.
- **`quantize` is the change detector.** A component is compared against the client's baseline
  as quantised bytes, so a trait whose `quantize` is `out = value` compares raw floats and
  float noise below the wire's step is a change on every tick: 24 parked craft cost 555 bytes
  a tick that way, and 38 through the wire round trip.
- **`EntityStartedSyncing` does not mean the client saw anything.** It fires when a network id
  is first assigned — including for a record the budget then refused, for an entity merely
  referenced by another, and from tracing helpers.
- **`ComponentSent`, `TagSent` and `CueSent` meant "serialised", not "sent"** until upstream
  #7. A trace counter is a claim about the code path it sits on, not about the wire.
- **`input_starved` names a symptom on the server, not a cause.** `lane/weapons` read six
  shells played and five withdrawn at a 16-tick link and blamed sync's `finish_resimulation`;
  the trace said every withdrawal was `server_mismatch`, and the real cause was the client's
  own input packet being truncated. **Read the reason on every withdrawal before naming a
  layer.**
- **A rollback-reason trace is EMPTY unless a trait gives a reason**, and the conflict event
  names the component by entity rather than by name. A check that counted rollbacks by the
  reason's component passed with no events at all.
- **`max_input_count` is not the cap that binds.** It is 31 — but `mtu_bytes` (1200, which
  CockpitWorld never sets) cuts cockpit's input packet at **29** frames first. A private build
  with a 6-bit count gave byte-identical results at every link. **Two caps in series hide each
  other: lift them one at a time AND together.**
- **`ClientId` is `std::uint8_t`** (`types.hpp:33`), so it streams as a character — a packet
  log printed client 1 as `\x01` — and there are at most 254 clients.
- **`ReplicationBandwidthParticipantOptions::priority`** (`types.hpp:834`) has nothing to do
  with replication priority. Name collision only.
- **Predicted spawn does not exist.** The server's entity id is meaningless on the client,
  replicated components arrive a frame or two after the entity, and an entity reference
  resolves before the entity is ready. Identify by a replicated property, re-check each frame,
  and ask the map you are promising ids from.
- **A cue emitted outside the step must carry the NEXT frame**, or an ack erases it unsent.
- **Retiring an entity drops what sync had not yet sent about it**, so a thing that ends must
  outlive its own last record.

### How to prove a networking claim

**Measure at the client's receipt, never at the server's count.** The server returning true,
sending a packet or counting a client says nothing. `set_input()` returns true while applying
to nothing. `add_client()` on a peer that has not handshaked is an access violation with no
Godot error. `client_count()` stays at 0 while a client with an empty `connect_token` sits
"Ready" receiving nothing. What has actually found bugs here is always a number the receiving
side produced: client speed beside server speed per tick (the input echo); a joiner's
`NET_SKY_HEARD n=2` with no `n=1` (a suite's own race); the count of craft the joiner's world
held itself in, on every tick (the baseline reference-counting bug, 184 of 2400 ticks).

**Starve it on purpose.** `lane/starve`'s whole result came from sweeping the link and
reading a law out of the table — frames behind = round-trip lead − 29 — rather than fixing
one delay. Its loss condition (1 % loss, a 5-tick outage every 2 s, 0–4 ticks of jitter, per
600 ticks) is the shape to copy, and it told two candidate fixes apart that a clean link had
scored identically.

**A flat green column across link delays is the proof; a fix at one delay is not.** Plan item
5's spinning guns were not a replication bug at all but a 56 ms control loop closed through
the link, and that was shown by the column being flat, not by anything getting better.

**Log the packet sizes before believing a cap**, and log the reason before believing a trace.
`lane/starve` reported the wrong cap to team-lead first and corrected it only after measuring
89 B at a lead of 2, 333 at 8, 985 at 24, then flat at 1,193 B.

**Re-measure the BEFORE on the base the AFTER will run on.** Identical probes on two
libraries, on a deterministic level, read line for line against each other is the whole proof
(`lane/carrier`: alpine legs over land 3 → 0, aground 229 s → 0). Re-measure even when the
change between them looks unrelated.

**A property that cannot be made red today may become checkable when the layer under it is
fixed.** A rollback across an on-time fire was impossible at a 16-tick link while the server
was input-starved; after that was fixed the same holds gave played 1, withdrawn 0, and it is
asserted now, with the pre-fix library as its red. Say "this cannot be shown today" and print
the number, rather than contriving a check.

### A local patch, or an upstream PR

**None today.** Three patches lived in `ashiato-gd/tools/patches/` from 2026-09-16 to -18:
`baseline-on-mask-open`, `retain-before-release` and `send-newest-inputs-first`. Upstream took
all three at `8fa08cf` (the first two rewritten more strictly, the third without its 8-frame
cap), the folder is gone, and `build.ps1` now refuses an `ashiato-sync` checkout that is not at
the `upstream.lock` revision or that carries uncommitted edits. **Adding a file to that folder
makes every build require it, so an upstream-only patch does not belong there**, and a new one
means the shared checkout is dirty again, which `build.ps1` will then have to allow.

**A library patch needs a customer in the game, not only a unit test.** On 2026-09-16 a
*correct* ashiato-sync cue fix, with unit tests that went red on the library and green with
the patch, was **parked** rather than shipped: a trace showed the symptom it was meant to cure
was input starvation, with identical numbers patched and unpatched. **Name the trace event
behind a symptom before blaming the library for it.** That patch is now upstream as #1, on its
own merits, saying nothing about the game symptom it did not fix — **a patch that is right but
whose motivating symptom evaporated is an upstream candidate, not a local one.**

**The four-part test for upstreaming** (`lane/upstream`, 2026-09-17). Send it only when **all
four** hold; if any one fails, keep it local and send a measurement instead.

1. **It reproduces in sync's own tests, with no game in the loop.** The author cannot run this
   game, so a downstream symptom is not evidence. Quote downstream numbers as context, never
   as the case.
2. **The diff is minimal and covers one issue.**
3. **It depends on no local patch.** Branch from `origin/main`, never from the shared
   checkout's working tree, which carries the game's patches as uncommitted changes.
4. **It needs no design decision from the author.** If the fix picks a policy the maintainer
   should pick, it is not ours to send. Measured case: the serialise-after-budget cost is real
   — 44–63 ms a tick against 5.2 ms when the loop breaks at the first refusal — and the only
   behaviour-preserving fix saved nothing (75.4 against 74.2 ms). Anything that does save the
   time changes which records are tried and the order network ids are assigned, so it went as a
   **measured note with no PR**. A PR that quietly changes observable behaviour is worse than
   no PR.

**How to make the case, and the bounce risk.** The full procedure — one issue per branch, one
commit per branch, failing test first with Catch2's expansion quoted verbatim, whole-suite
counts before and after, an explicit list of the author's gates that could not be run, and the
AI-disclosure lines — is in `learnings/2026-09-17-upstream.md`. Two things from it belong here
because they are about building, not about etiquette:

- **Green on MSVC is necessary, not sufficient, and nobody here has yet seen a review or a CI
  result on any of the ten PRs.** Upstream CI builds on GCC/Clang with `-Wall -Wextra
  -Wpedantic -Wshadow -Wconversion -Wsign-conversion -Werror` and checks out Ashiato `main`
  beside the repo rather than using the pin. MSVC's `/W4 /WX` is not a substitute, and
  `ashiato_sync_apply_strict_warnings` applies only to the library target, not to the tests.
  **Expect a Windows-only change to be bounced on `-Wconversion` or `-Wsign-conversion`.**
  Building here with llvm-mingw (already on this machine for the double Godot build) or WSL is
  the single biggest upgrade available, because it also makes `scripts/lint.sh` and the fuzzer
  reachable.
- **A flag that makes a build work is not a diagnosis.** The `-DCMAKE_CXX_STANDARD=20` plus
  `/DNOMINMAX` that this workshop carried for weeks was three unrelated problems wearing one
  flag: `CXX_STANDARD 17` is a property on the library rather than a usage requirement, so the
  tests compiled as C++14 (3,919 errors); one test includes `<winsock2.h>` without `NOMINMAX`;
  and MSVC's legacy lambda processor cannot capture a local used in a generic lambda passed to
  a simulation job, which C++20 fixes only as a side effect of `/Zc:lambda`. A whole build
  cycle also went into proving `/permissive-` was not the answer to an error that looked like a
  language-standard problem and was a stale Ashiato pin.

### Experimenting on the library without breaking the team

- **Experiment in a PRIVATE detached worktree of `ashiato-sync`** under the lane's temp
  folder, never in the shared checkout, and remove it at lane end.
- **The CMake cache is the only proof of which sync tree a build used** —
  `ASHIATO_SYNC_DIR` in `%LOCALAPPDATA%\ashiato-gd-build-<hash>[-double]\CMakeCache.txt`. The
  build log does not say.
- **`build.ps1` installs into the lane's TRACKED `cockpit/addons/ashiato/bin/`** as well as
  the ignored addon bin, leaves `~ashiato_gd.double.dll` behind, and rewrites racer's and
  vrplayground-2's tracked DLLs too. Restore a lane's DLLs from **its own commit**
  (`git show HEAD:path > path`), never by copying from main, and compare SHA-256 before any
  commit. Say which algorithm: a lane once quoted MD5 as "the hash".
- **ashiato-sync's sources are CRLF.** A Python edit matching `\n` finds nothing. Normalise,
  edit, write the file's own endings back, and prove the edit is in before building.
- A rebuild in a private sync tree takes about a minute once the object tree exists; the
  first one compiled 1,204 files.

---

## Traps

Every one of these cost real time. None produces a useful error.

### Networking

**An empty `connect_token` silently skips the handshake.** `ReplicationClient`'s
constructor does:

```cpp
if (options_.session.connect_token.empty()) { set_connection_state(Ready); }
```

The client declares itself connected, never introduces itself, and the server's
`client_count()` stays at **0** while the client sits there "Ready" receiving nothing.
Indistinguishable from a broken transport. Set a non-empty token.

**Removing a replicated entity means removing the `Replicated` COMPONENT, not destroying
the entity.** The server rediscovers what it should be replicating from the registry's
dirty frame, and what it looks for is `each_removed<Replicated>` — component removals.
Destroy the entity outright and it disappears locally while the server's replicated slot
lives on, so every client keeps the object exactly where it was, frozen and unowned, for
the rest of the session.

Calling `rediscover_all_replicated_entities()` by hand does not rescue it either: the tick
clears the destroyed-slot queue that call fills *before* broadcasting, so the destroy is
discarded. Remove the component, let the next tick carry the removal, and destroy the
entity a tick later — one frame of an object nobody can see, in exchange for clients
actually being told it went.

**And the server never learns a client left.** sync is handed packets and nothing else; it
has no idea a socket closed. Until `remove_client()` is called it keeps the departed client
in `client_ids()`, keeps sending updates into the void, and any game logic keyed off "who
is connected" goes on believing they are still here. The transport is the only thing that
knows, so the transport has to say.

**Ownership has TWO vocabularies, and sync only reads one of them.** This is the single
most expensive thing in this document, because the failure looks like a physics bug.

sync routes the local player's input like this:

```cpp
registry.view<const NetworkOwner>().each([&](Entity e, const NetworkOwner& owner) {
    if (owner.client == settings.local_client) { push_to_registry(registry, e, quantized); }
});
```

`NetworkOwner` is set by `set_owner()` on the **server**. The entire client tree only ever
*reads* it -- nothing in sync writes it client-side. So a replicated entity arrives on the
client carrying your own owner component (ours is `CarOwner`, because trap 4 above forces a
separate one) and **no `NetworkOwner` at all**. sync finds no locally owned entity and
`set_input()` applies to nothing. It still returns true.

Reconcile it every tick rather than at spawn: the entity and the assigned client id arrive
at different times, so there is no single moment at which "set it once" is correct.

**Do not put the input component in the archetype.** Registering it and marking it with
`set_client_input_component` is the whole contract -- sync carries it client->server
through the input path, records it per frame, and replays it during rollback. Replicating
it *as well* makes the server echo each client its own input back a round trip late, and
that echo lands on the predicted car and overwrites the live input it should be predicting
with. sync's own FPS example leaves `FpsInput` out of its archetype; that omission is the
documentation.

**Together these produce a bug that hides behind a plausible story.** With both wrong the
car still drives, because the echo supplies *an* input -- just one from ~16 ticks ago. Hold
a key and it is indistinguishable from correct, because stale input equals live input.
Release one and the car carries on accelerating for a full round trip, then snaps backwards
when the correction lands. Every instinct says "the interpolation is wrong" or "rollback is
broken", and both are innocent.

What actually found it was dumping client speed beside server speed per tick. The client
was still accelerating fifteen ticks after the key came up, which no amount of smoothing
explains -- it says the input never arrived. A correction that big is a symptom; smoothing
it is treating the symptom. `addon/tests/input_release.gd` now asserts the *cause*: that
deceleration begins within a tick or two of the release. "Never moves backwards" alone
passes trivially if the input is ignored altogether, which is exactly what was happening.

**`add_client()` on a peer that has not handshaked is an access violation.** The server
pushes updates at a session the client cannot decode. The process dies with no Godot error
at all. Let the client introduce itself; the server accepts by default.

**The server assigns the client id.** Do not preset `session.local_client` — that is the
preassigned-session mode and interacts with the above. Read it back with `client_id()`.

**`invalid_client_id` is 255**, which sails straight through an "assigned yet?" test
written as `> 0`. A car got spawned owned by a client that does not exist, so it was never
predicted and never coloured as ours. Wrap the accessor to return 0 when unassigned.

**`PeerId` is `uint64`; `ClientId` is `uint8`.** `TransportFn` takes a **PeerId**. Taking
it as `ClientId` truncates a Godot peer id — a random 32-bit number — to its low byte and
routes packets to the wrong machine. Invisible in a loopback test where the only peer id
is 1.

Usefully, `TransportFn` hands back whatever `PeerId` was passed to `receive_packet`, so
**Godot's peer ids can be used directly as sync PeerIds** and there is no mapping table.

**A predicted archetype needs `should_roll_back` on EVERY replicated component in it**, not
just the ones you expect to be corrected. The ones that never matter can return `false`.

**`sync::NetworkOwner` cannot go in an archetype.** It has no `SyncComponentTraits`, so it
has no wire format, and it crashes on the first serialize. Define your own owner component.
The client needs one: without it, nothing matches "my car" and *nothing is predicted*.

**Spawn order is a deadlock.** A client only reaches Ready once it receives an update, and
the server only sends updates about replicated entities. "Wait for the connection, then
spawn" therefore never connects. Spawn something first.

**Server and client entity ids are different registries.** The id `spawn_car()` returns is
meaningless on the client. Identify entities by a replicated property (ownership), not by id.

**Replicated components arrive a frame or two after the entity.** Deciding anything at
entity-creation time (colour, "is this mine") gets the wrong answer. Re-check each frame.

**An entity reference resolves before the entity is ready.** sync maps a referenced entity to
the local one as soon as it has made it, and that entity's components arrive a frame or two
later. A client joining mid-lock was handed a target id its own `vehicle_states()` did not list
yet. Ask the map you are promising ids from -- here the display -- not "does it have a
VehicleState", which was the first fix and was not enough.

**An interpolated entity's lateness is the buffered lag, and the link is already inside it.**
sync's estimate of the server's present has the link taken out, and draws at that estimate
minus the lag, so "latency plus lag" counts the link twice. It drew a watched missile ahead of
the server by the link: 3.16 ticks of travel off, against 1.12 for the lag alone. The lag only
grows while the client holds something interpolated, so a test with nothing but a predicted
pilot on the link will see it sit at its configured value.

**Two identical cues in one frame are one cue.** `equals_cue` makes them the same moment, so
emitting a cue twice is not a way to show a check can catch a duplicated cue -- the break has
to emit on different frames.

**A cue emitted outside the step must carry the NEXT frame, or an ack erases it unsent.** sync
drains the `CueDispatcher` during a step (server.cpp, `on_registry_dirty_frame`), and clears a
pending cue when the client acks any packet whose frame is at or after the cue's
(`acknowledge_cues`, from `server_client_replicator.cpp`). Every cockpit cue is emitted after
`server_->tick` returns, so `FrameInfo` names frame F, whose packet has already gone, and the
cue is captured on F+1. When the aeroplane is not in packet F+1, the ack for F clears the cue
before any packet has carried it. A test world with a few entities puts the aeroplane in every
packet and never sees it. A level does: in the flight level 308 marker cues on the pilot's
aeroplane gave 3 arrivals, and neither seat launch's cue reached the pilot. With 80 aeroplanes
flying alongside in a two-world probe, 48 of 72 markers and 1 of 2 launch cues arrived.
`emit_craft_cue` now stamps `FrameInfo.frame + 1`, the frame it is captured on. The same probe
gives 72 of 72 and 2 of 2, and the flight level 307 of 308 markers with both seat launches'
cues arriving, on the stock and the double editor alike. The cost is that `late` reads one tick later.

**Why that is a guarantee and not a better average**, in ashiato-sync. A tick runs every
fixed step before it writes a packet (`src/server.cpp:1960-1966`, then `push_frame_to_listeners`
at :1969). Step C drains the dispatcher (:2069) and the cue joins the entity's pending list
with its own frame (:2448, :2455). A record is serialised with every pending cue (:2868),
but the budget can still throw that record away (`src/server/client_update_scheduler.cpp:204`,
:220-221); only a record that joins the packet is remembered at the packet's frame (:284).
An ack reaches `acknowledge_cues` only for an entity with a remembered record at exactly the
acked frame (`src/server/server_client_replicator.cpp:382-383`, then :414), and clears every
pending cue with frame <= that frame (`src/server/quantized_frame.cpp:61`). Stamped with its
capture frame C, a cue can therefore only be cleared by a record committed at C or later,
which was serialised after the capture and so carried it. Stamped C-1, the record committed
at C-1 -- before the capture -- was enough to clear it. What can still drop a cue is its
relevance running out (`expire_pending_cues`, :106), which is sync's rule, not this bug.

Measured with sync instrumented to log every cue an ack clears that no committed record had
carried. On the old stamp the count equalled the loss exactly: 25 in the crowded suite (24
markers, 1 launch cue) and 35 in the probe's four skies. On the new stamp it was 0 in three
runs of each, with no expiries and every cue delivered, and 0 in the flight level too: no cue
cleared unsent and none expired, both seat launches' cues delivered, and 307 of 308 markers --
the 308th emitted on the last frame the probe watched, so still in flight rather than lost.
`addon/tests/cue_crowd.tscn` keeps it that way, listed in `cockpit/tests/suites.txt` so
`run_all` runs it; it fails on the old stamp with 48 of 72 markers and 1 of 2 launch cues. The rejected alternative was patching
sync to remember which packet first committed each cue: more general, but a change upstream
for a rule the one cockpit call site keeps.

**A client owed more than the budget does not lose updates, it draws late ones, and a late one
is a hold then a leap.** sync sends each client `bandwidth_limit_bytes_per_tick` (1024 by
default) and round-robins everything else by an accumulator
(`src/server/client_update_scheduler.cpp`). An interpolated entity whose next frame has not
arrived when the buffered clock reaches it is SKIPPED (`src/client/runtime/buffered_runtime.cpp`,
`apply_frame`): the registry keeps its old value, and the late record is applied the moment it
lands with no gap fill (`update_runtime.cpp`, `apply_buffered_upsert`). The flight level owed
one client 1,847 bytes a tick; a joined machine over the loopback drew 0.80 lone jumps per 1000
craft-ticks (worst 49 m) and a common step on 824 of 7,200 ticks, while the host's own truth had
none, and every jump followed a tick on which sync reported the craft starved. The automatic
buffer does not see it: it sizes from jitter, and an entity sent every eighth tick arrives
perfectly regularly. `addon/tests/crowd_sight` reproduces it in one process -- green with packets
carried the tick they are made, red over a 4-tick link (3,564 held-or-leaping steps), a lumpy
link (18,765) and a lumpy link under fire (19,482).

**Quantize is sync's change detector.** A component is compared against the client's baseline
as QUANTIZED bytes (`src/server.cpp`, the memcmp in `write_entity_record`), and one that compares
equal costs a bit. A trait whose `quantize` is `out = value` compares raw floats, so float noise
below the wire's step is a change on every tick: the 24 parked craft in the flight level cost
555 bytes a tick. The cockpit traits now quantize by writing the value through their own
serialize and reading it back (`quantize_through_the_wire`), which is what a client decodes:
parked craft 38 bytes a tick, the level 1,315.

That round trip is NOT always the identity, and the check caught it. A smallest-three
quaternion drops its largest component and rebuilds it; when two tie -- an aeroplane heading due
east is (0, -0.7071, 0, 0.7071) -- the rebuilt one comes back a step smaller and the re-encode
drops the other. Same rotation, different bits: 52,511 of 291,600 components in `crowd_sight`,
whose autopilots all fly one heading. So the decoded value is kept only if it re-encodes to the
same bits, and otherwise the raw value is. `wire_rounding_check` compares encode(value) with
encode(quantize(value)) for every craft every tick: 0 differ with the guard; a deliberate break
after the guard (x at twice the wire step) gives 48,255. The guard costs the craft sitting on a
tie their float noise: parked craft 16 bytes a tick without it, 38 with.

**Budget per second, sized from the peak.** sync's `bandwidth_limit_bytes_per_tick` is per TICK,
so the same number is half the bandwidth at 60 Hz. The cockpit keeps one number in bytes a second
(`set_send_budget`, divided by the tick rate at start, reported in `net_status`) and defaults it
to 245 kB/s: half again over the peak the flight level was measured to owe one client after the
rounding (1,359 bytes a tick at 120 Hz, p99 1,354). A first cut floored the per-tick figure at
sync's 1,200-byte MTU "because sync will not split a record" -- a record is tens of bytes and
sync's own default is below its MTU -- which turned 1,024 into 1,200 and made the rounding look
like it had saved bandwidth it had not; `wire_budget` printing "budget 1200" is how it was found.
Measured over the real loopback on 4e76324: at 1,024 a joined machine drew 0.63 lone jumps per
1000 craft-ticks and saw 1 of 3 missiles; at 245 kB/s 0.06 and 0.12 in two runs, 3 of 3 missiles
and 3 of 3 ends in both, two packets a tick of at most 1,200 bytes, and ENet's throttle at full on
48 of 49 samples.

**A dirty entity costs a record even when nothing in it changed.** `serialize_entity` writes the
header and a bit per component and returns a non-empty payload. A view that takes a component by
reference marks it dirty before the body runs, so it is not free on the wire: `fly_shots` read
every landed round that way.

**Retiring an entity drops what sync had not yet sent about it.** `enqueue_destroy` clears the
entity's pending state. A missile was retired three ticks after it ended; under a full budget its
end record waited seven to ten ticks for a slot, and a joined machine saw 3 of 3 missiles and 0
of 3 ends -- 1 of 3 in `crowd_sight` under fire. Spent rounds, missiles and fires now stay
`kSpentSeconds` (0.5 s: two waits for a slot at 120 Hz plus a slow round trip): 3 of 3 in every
sky, under fire included.

**An input frame carries one command, and sync may skip a frame.** `send_command` used to hold
one pending command and bump a two-bit sequence: a second send before the next frame overwrote
the first, and four wrapped the sequence back to where the server already was, so none arrived.
Resending did not save a command either. Every unacknowledged input frame goes in every client
packet, so nothing is lost, but when several arrive late together the server takes the newest
one due and skips the older ones (`ashiato-sync/src/server/input_buffer.cpp`,
`select_input_for_frame`), and a command that rode a single frame went with a skipped frame.
Measured in cockpit_loopback before the fix: five switches sent on one frame, only the last
landed; one command a frame with client A's frames handed over two at a time, 3 of 5 landed.
`send_command` now queues -- the latest value per channel, except a channel the server acts on
receipt of (today only the crew button, which flips its light), capped at 16 with a warning and a
false return -- and `ride_commands` keeps each command on the frames for `kCommandRideSeconds`
(2 frames at 60 Hz) with the sequence moving by one per command: 5 of 5 in order, 5 of 5 over
the bunched link, 16 kept of 20 with the gear and flaps among them.

**A button edge is a moment a skipped frame can hold; a number on every frame is not.** The cockpit's JOIN rode a
button's rising edge and went unanswered in 2 of 7 two-process runs; held until the answer, 1 in 34, because the rise
-- or the fall before a second press -- can itself be on a frame the server skips, or behind a stream that stalls and
lands in a lump. `ControlInput::menu_request` is three bits bumped per press and carried on every frame, acted on when
it changes, per client, as the command sequence is. `addon/tests/crew_join` holds it over a bunched link, a stalled
stream, a second press across a skipped stretch and a rejoin that presses at once; on the edge build each of those
sections answered 0 of 5. Any request a menu makes should ride the same way: a level that stays until it changes.

**A command sequence belongs to the client, not the pilot.** The server kept its last-applied
sequence per pilot entity, so a new pilot for the same client started at 0 and the client's last
command was applied again to a craft it had never touched: both of two respawns relit the new
aeroplane's lights. Seeding from a new pilot's first frame cannot fix it, because sync routes a
client's frames to its new pilot before the client has adopted it. Keyed by client, and erased
in `remove_client`, neither respawn relit.

**On a predicted vehicle, "the value arrives by rollback" is hard to test.** The vehicle is
corrected every few ticks for reasons of its own, even parked, and any rollback carries every
component across -- so a check that a value arrives passes with the rollback rule deleted.
Say so in the check rather than claim it proves the rule.

**Withholding a whole entity from a client is a priority of zero (NaN before 8fa08cf), and it cannot leak on the first
frame.** `send_client` skips a dirty entry whose `last_priority` is filtered before the entity is serialised or given that
client a network id (`src/server/client_update_scheduler.cpp`, `is_filtered_priority`), and the decider is asked again
every tick while it stays filtered (`refresh_replication_decision_if_due`). A new or reused slot starts NaN, which reads as
filtered, for every client -- `clear_client_entity_state` resets it
(`src/server/quantized_frame.cpp:54`), `upsert_replicated` clears then marks dirty (`src/server.cpp:3240-3248`) -- so the
first send is decided by the decider, not by a stale 1.0. And a client with no network id for an entity is sent no
destroy for it (`server_client_replicator.cpp`, `mark_pending_destroy(0)` fails). The cockpit's crew cabins are built on
this: `addon/tests/crew_cabin` counts 0 crew records on the server's trace to a client not aboard, where the vehicle's
`CraftSystems` had sent it 30.

**A relevance that closes sends nothing, so an audience should never change on a live entity.** A prioritizer or a mask
only withholds: the client keeps the last copy it had, forever, and sync asks about an entity only when it is dirty, so a
change of audience on a quiet entity is noticed when the entity next changes. Withheld by a mask, a crew that left kept
the cockpit's inside in 5 rounds of 5, and a boarder waited 8 ticks for a cockpit whose bound was 6. Give each audience
its own entity and create or retire it: one cabin per crew member is one create and one destroy per boarding, on that
member's machine only, and 0 records to anybody else.

**`component_sent` is what was written into a packet, since 8fa08cf -- and before it, what a client was owed.** Up to
90f50bf sync traced it inside `UpdateWriter::serialize_entity`, before the budget check, and `send_client` serialises
every dirty candidate every tick, then `continue`s past what does not fit: measured in the cockpit at 67 B a tick over 61
moving planes, 62 `component_sent` a tick on the server, 50 bytes a tick on the wire, and about one `component_received`
a tick on the client. Upstream now DEFERS the sent events (component, tag and cue) until the record is in a packet
(0541d04, 91e1fcf). A packet can still be lost, so a delivery is still counted where it lands:
`CockpitWorld::received_frames` keeps each craft's newest VehicleState frame and a count in the trace callback, without a
Dictionary per event. The CPU is unchanged by the trace: every candidate up to the refusal bound is still serialised.

**A priority ratio is not the rate ratio, until the ties and the whole ticks are counted.** With every entry dirty, an
entity at p is chosen every A/p ticks, so the continuous answer is k. But sends land on whole ticks, accumulators hold
whole multiples of p, and equal accumulators go in slot order. At 31 entities at 4 and 30 at 1:
- 20 sends a tick gives 3.33, and 22 gives 2.58.
- A replay of add, stable sort, send the top M and zero, over the run's own per-tick send counts in SERVER slot order,
  said 3.753 where the cockpit measured 3.749.
- In the client's arrival order it said 3.975.

Predict a priority effect by replaying the scheduler, not by dividing (`cockpit/tests/priority_sphere.gd`, `_rates`).

**A Step component on an interpolated entity waits for the buffered frame, and a long link hides the wait.** It is
written into the buffered ring and applied when the buffered clock reaches its frame (`buffered_runtime.cpp`,
`apply_frame`); sync's estimate of the server has the link taken out, so a record that lands later than the buffer is
deep is applied on arrival (`update_runtime.cpp`, `apply_buffered_upsert`). Measured: over a 4-tick link a copilot's
switch showed 2 ticks after its packet landed with a 7-frame buffer, and over a 1-tick link 3 ticks with a 5-frame one.
`ReplicationClientMode::Snap`, chosen per entity by the mode selector, applies it in the tick its packet is processed: 0.
Measure a lag over a link shorter than the buffer.

**sync's rollback-reason trace is empty unless a trait gives a reason**, and its conflict event names the component by
entity, not by name. A check that counted rollbacks by the reason's component passed with no events at all; the cockpit
asks instead whether the pilot's machine rolled back on the tick a switch appeared, over three switches.

**The server already knows which peer each client came in on.** `ReplicationServerOptions::connection_event_handler`
hands over `{type, peer, client}` on Accepted, Ready and Removed (`src/server.cpp:596-609, 985-990, 1628-1633`). The
cockpit used a reliable Godot RPC in which each machine told the host its own id, once, as it arrived -- game data on
Godot's multiplayer, taken on the joiner's word, and never heard by a machine that joined later. The server keeps the map
from the events and writes each client's peer on its pilot's replicated `PilotOwner`, so every machine resolves every peer.

**sync gave back quantized frames it never took, and a freed baseline copies another entity's components.** In
`client_update_scheduler.cpp` a record that did not fit the packet or the bandwidth left called
`release_server_quantized_frame` on a frame the loop had not retained. `serialize_entity` often returns a frame that
already exists -- the same-frame cache, or an identical frame for the slot -- which is then another client's pending entry
or baseline. `release_quantized_frame` frees at zero, the index goes to another slot, and `find_or_create_quantized_frame`
checks a baseline's archetype but not its slot, so every component whose dirty generation matches is copied from the
wrong entity. Components that change every tick are quantized again and hide it; the ones that barely change -- `Seats`,
`VehicleKind`, `Route`, `CraftSystems` -- stay wrong until they next change. Seen as `cockpit/tests/two_peers.gd` failing
one run in three under load: the host drew nobody in the joiner's craft. Measured in one process by `tests/crowd_join.gd`
(a joiner beside seventy moving craft over an 8-tick link): the joiner's own world held itself in exactly one craft on
184 of 2400 ticks and put itself in four at once, each of which it then predicted; with no crowd, nothing was lost. The
libraries from before cockpit-crewsync did the same (14 of 48 join timings against main's 13). Retaining the frame as
soon as `serialize_entity` returns it, and releasing only that reference, made it 0 of 2400 and 0 of 48 on both
precisions: `tools/patches/ashiato-sync-retain-before-release.patch`, upstream since 8fa08cf. A seat that moves between craft is not the
cockpit's to chase; count the claims on every tick, not at the end, because the wrong one moves as baselines are acked.

**A Godot peer id is 1 for the host and 2 to 2^31-1 for everybody else, over ENet and over Steam alike.**
`MultiplayerPeer::generate_unique_id` masks its hash to 0x7FFFFFFF and loops while it is 0 or 1; GodotSteam 4.21's
`SteamMultiplayerPeer` sets the server's to 1 and a client's from `generate_unique_id`, and sends it to the host in the
connection's user data (`godotsteam_multiplayer_peer.cpp:510, :528, :182`). So `PilotOwner.peer` is 32 bits, and
`cockpit_loopback` gives its late joiner peer 2147483647 and checks it resolves on every machine. A machine with no pilot
of its own answers 0 -- cannot say -- for itself, and every other machine answers 0 for it.

**Two presses decided inside a job are decided in entity order, which is an order nobody chose.** The cockpit's JOIN
was resolved in the pilots job as each pilot's frame was read, so two clients asking for one seat on one server tick were
settled by which pilot entity the registry had handed out first. The job also wrote `Seats`, which it does not declare.
It is now noted in the job and decided in `tick()` after the jobs, lowest client id first (`answer_the_joins`). Measured
in `addon/tests/crew_join`: both presses land on one server tick at the first try, read from the server's own
`join_log`, and the lower id wins. Any "first come" rule between clients on the server needs the same shape: the server
cannot see which of two frames simulated on one tick arrived first.

**A per-member answer rides the member's cabin.** A refusal is private and wants to be read on the tick it lands, and
the Cabin already is both: sent to one client, snapped (see "A Step component on an interpolated entity"). The server
keeps the answer per CLIENT, not per cabin, and copies it onto whichever cabin that client holds, so it follows a player
onto a new craft. A client with no craft holds no cabin and reads no answer.

### Transport

**`BitBuffer` is bit-addressed.** Carrying only bytes across a transport loses up to 7 bits
of length, and the reader then runs off the end of the packet — a hard crash. Carry
`bit_size` alongside and rebuild with `assign_bytes(bytes, bit_size)`.

**Use `unreliable_ordered`, not reliable.** sync already acks and resends what it cares
about; a reliable channel underneath adds head-of-line blocking and hides the packet loss
its bandwidth control is measuring.

### GDExtension

**An escaping C++ exception terminates Godot silently.** No message, no stack, nothing in
the log. sync throws for protocol and usage errors, so every entry point that can reach it
needs a try/catch that reports. Adding this turned several "crashes" into readable errors.

**New assets need an editor import pass** before anything can `preload()` them; a headless
run against unimported art *hangs* rather than failing.

**GDScript property names collide with built-ins.** Naming one `ready` clashes with
`Node`'s `ready` signal; the script fails to parse and Godot reports the thoroughly
misleading *"does not inherit from Node"*.

### Physics

**Where a force is applied matters more than how big it is.** The first car steered by
picking a target yaw rate and applying whatever torque closed the gap. It was stable, easy
to drive, impossible to spin, and it felt like a boat — because every force went through
the centre of mass, and nothing in it knew a wheel existed.

The fix was not a better torque curve. It was four tires: each one takes the velocity of
its own contact patch, converts the sideways part into a slip angle, turns that into a
force, and applies it **at the tire**. Yaw is then never commanded at all — it falls out of
where the grip happens to be. Understeer, lift-off rotation, and a handbrake that steps the
back out are consequences of that arrangement rather than features that had to be written.

The whole model is about forty lines, and the pieces that earn their keep are:

- **The friction circle.** One contact patch, one budget, shared between turning and
  driving. This is what stops a car accelerating hard out of a corner and holding the line.
- **A settling clamp.** Never let a tire push back harder than it would take to stop the
  sliding within this step (`|v_lat| * mass_share / dt`). Without it the lateral force
  overshoots at low speed, reverses next tick, and the car buzzes in place.
- **Softening the slip angle.** `atan2(v_lat, |v_long| + 1.5)` rather than the true ratio:
  as forward speed approaches zero the true slip angle is meaningless, and a parked car
  develops enormous forces from a millimetre of drift.
- **Speed-tapered lock.** Real cars have this problem too and solve it with a slower rack.

**Power is not force, and a knob that says "hp" should mean it.** Driving with a constant
force pulls as hard at 75 km/h as off the line; top speed then depends entirely on drag,
which is why the first version needed so much of it. `F = P/v` gives the shape a real car
has. Below a crossover the car is gearing-limited instead, since `P/v` diverges at rest —
and **that ceiling has to scale with power too**. Fixed, it made the hp knob do nothing
below 17 m/s, which was almost the entire usable range: the number moved and the car did
not. Above it, the friction circle takes over and a big engine simply spins its wheels,
which is the right answer rather than a workaround.

**Contact friction double-counts modelled grip, and the second copy wins.** Related, and
worth stating separately because it survived the rewrite. The car is a box sliding on its
belly; a 960 kg slab dragging on the floor resists yaw enormously. With realistic friction,
full lock gave **6 deg/s and a 180 m turning circle** no matter how hard the steering
pushed. Under the tire model it was still stealing **1.8 kN — a third of the engine**, and
applying it under the middle of the car where it can only ever resist yaw. If grip is
modelled by the game, the shape's contact friction must be **zero**, not merely small.

**And the cockpit learned it again.** Every CockpitWorld hull was
0.05, "near frictionless" — but Box3D mixes two frictions as their **geometric mean**
(`b3DefaultFrictionCallback`, `sqrtf(a * b)`), so against the ground's default 0.6 that is
**0.17 of weight**. Measured on 2026-09-13: a 780 kg aeroplane sat still at 880 N of thrust, a
nine-tonne airliner at 6 kN, and full rudder at a standstill yawed them at 0.01 and 0.00 rad/s
against 0.5 asked for, because the four corners of the hull box were resisting yaw with
about as much torque as the nosewheel had. On a carrier's deck it was 0.05 (hull on hull —
two vehicle hulls DO contact, whatever the comment beside the deck spring said), so the same
aeroplane rolled 28 m in ten seconds on the ship and none at all on the island. Aircraft
hulls are 0 now and the wheels are forces (`roll_on_wheels`). A small friction on a shape is
only small against another small friction.

**Grip proportional to load makes weight transfer a one-way street.** The obvious tire
model is `max force = mu * load`, and it quietly guarantees that whichever axle weight
transfer leans on wins every argument. Power loads the rear, so the rear out-grips the
front, so the car pushes wide — and no amount of tuning the *front* fixes it, because the
front is the axle being unloaded. The only lever left is weakening the rear everywhere,
which then turns lift-off (where the rear is already light) into a spin. Two failures,
opposite directions, one cause.

Real tires lose mu as load rises. Adding that — one coefficient, `mu * (1 - k*(load/nominal
- 1))` — fixed both at once: the loaded rear gives some grip back so it slides under power,
and the unloaded rear keeps more so a lift no longer swaps ends. Sideslip under power
doubled while lift-off oversteer *halved*, from the same change. When two symptoms pull in
opposite directions, the model is usually missing a term rather than needing a compromise.

**A tuning curve referenced to a speed the car cannot reach is a curve it never gets.**
Grip fade and the rear's grip bias were both blended against the steering rack's 30 m/s
reference. Top speed is 21. So a car cornering hard at 17 m/s was still being handed most
of its *low*-speed rear grip, and sweeping the high-speed value did visibly nothing —
three different values produced byte-identical output, which is what finally gave it away.
Fade against a range the thing actually operates in.

**"Feels like oversteer" and "is oversteering" are different claims.** Asked to cut
oversteer, the measurement said the car understeered in *every* condition — as low as 0.35
of the turn its wheels were asking for. What felt like the tail stepping out was sideslip:
the nose points into the corner while the car travels wide, which looks like oversteer from
the driver's seat while the trajectory does the opposite. The fix was therefore *more*
front grip, not less, plus the two stability aids every real car has (forward brake bias, a
slightly stickier rear axle). Measure the balance before touching it, or you tune the car
in the wrong direction with complete confidence.

**Measure the condition you mean, not the state you end in.** The first balance probe read
the car at the end of the run and reported 162° of sideslip — an apparent catastrophic
spin. Nothing was wrong: ten seconds of brake stops the car and then *reverses* it, and a
car reversing with its wheels turned pirouettes. Sampling only ticks where it is still
travelling forwards at a usable speed turned a fictional disaster into a flat "no spins
anywhere". Note the shape of that mistake is the same as the handling probe's: a number
that was never actually driven under the conditions it claims to describe.

**A tuning constant in C++ is a tuning constant you will not tune.** Every knob that
shapes the feel is now a setting read from a Dictionary, defaulted from the constant it
replaced. The point is not configurability for its own sake — it is that sweeping three
values of two parameters took one script and no rebuild, and printed a table that
separated the two effects immediately (one knob owned lift-off oversteer, the other owned
the power slide, and they barely interacted). The same sweep against a C++ constant is
nine rebuilds, so in practice it does not happen and the car keeps whatever number was
guessed first.

The cost is a new silent failure: `handling.get("key", current)` treats a **misspelled key
as absent**, so a typo leaves the setting at its default while the constant sits in the
game looking authoritative. With eighteen of them that is a matter of time. The game's
smoke test now reads `handling()` back and compares every key it sent — and includes a
deliberate typo to prove the check can actually fail.

**A limit clamped at one lets the whole ask through to the edge it was meant to guard.**
The cockpit autopilot scaled its climb allowance by airspeed over stall and clamped it at one,
which reads as "a slow wing may not climb" and means "a wing may ask for its full climb until
the instant it stalls". Measured on 2026-09-14, a seventeen-tonne tanker asked for thirty metres
a second held that ask from 52 m/s all the way down to 9, nose at sixty degrees, and fell. A
guard has to reach zero BEFORE the edge: the allowance now runs from all of it at cruise to none
at 1.1 times the stall, and goes negative below. The same fix bought "trade climb for speed"
without a second controller.

**A lookup by a shared property answers with the first thing that has it.** `kind_index_of_model`
found an autopilot's handling by its movement MODEL, and every aeroplane kind shares one, so
all six took off on the light aeroplane's stall, rotation speed and ground speed. Nothing
failed loudly; the tiltrotor simply never left the ground. Store the identity where it is
known -- at spawn -- rather than recovering it from something many things share.

**Tune against measurements, not adjectives.** The handling probe originally measured one
radius and divided it by other speeds, which quietly assumes yaw rate does not depend on
speed. It does. Every number that table printed for a speed it had not actually driven was
fiction, and it hid the fact that the car was cornering at a flat 1.1 g everywhere. Measure
each condition by driving it.

### AI work that runs now and then

**Periodic AI work goes on a rota served after the step, not in a countdown inside the job.** The cockpit
autopilots each kept two float countdowns inside `fly_itself`, which the simulation job runs: a look along the flight
path every half second and a leg re-check every three. Nothing bounded how many landed on one tick. `ChoreRota`
(`src/cockpit/chore_rota.hpp`) serves them from `CockpitWorld::tick`, after `server_->tick`. Three things about where it
runs decide whether it is correct:

- **Outside the job.** A job writes what a job declares, and a chore -- above all a script's -- can write anything.
  After the step every body stands where the next frame's `drive_vehicle` will read it, so the answer lands on the same
  tick it did in the job.
- **Once per simulated FRAME, read from `FrameInfo.frame`, not once per `tick` call.** `ReplicationServer::tick` runs as
  many fixed steps as its accumulator holds (`consume_server_fixed_steps`, `src/server.cpp`), so a call can simulate
  none or two. A call that advanced two frames serves two.
- **Server only.** The server never resimulates and a client registers nothing, so no rollback replays a chore.

**Budget in a count or a share, never in time.** A microsecond cap was rejected because it is not deterministic: it
serves different chores depending on the machine's load, so two identical worlds diverge, and on a workstation running
other suites they always do. A share, ceil(registered x share) held in integer millionths, is as deterministic as a count.
Time is measured and reported per kind (`chore_report`) and decides nothing. Jitter and first phase hash from (stream, kind, cycle); an autopilot's stream
is its position-derived seed, not its entity id, which moves when the spawn list changes.

**The suite that holds it passed on the library before it.** Each section threw on its first call to a method that
library lacks, the error ended the function, and there were no failures to count. `cockpit/tests/rota.gd` counts
finished sections. A deliberate break -- forcing at `waited > max` instead of `>=`, and a static counter in the jitter
shared by every world in the process -- fails three checks: a starved look's worst interval 121 against a limit of 120,
a leg check with no budget 721 against 720, and two worlds built alike with different digests.

**Urgency needs a nearer deadline, not only an earlier due tick.** The first cut of an urgent chore brought its next
due tick forward and left it in a queue served oldest first. On a contended rota it then waited behind every chore
older than it -- as long as it would have without the flag. The heap is keyed by deadline (last serve plus limit) and
an urgent chore's limit is its urgent target times the kind's own slack, so it is forced within that. With no chore
urgent every limit in a kind is equal and deadline order is oldest-first, so nothing measured before it moved. With
the urgent deadline broken back to the ordinary limit, `tests/rota.gd`'s urgent chore on a rota of 200 at 5 a tick
waited 40 ticks on every serve, as long as the crowd; with it, 2.

**A diagnostic in the game path is a spike nobody budgets.** `recheck_leg` called `what_blocks` on every dropped leg,
sampling it every ten metres against every box so a test could print the nearest box: 4,066 to 10,612 us for the one
tick that dropped a leg, in a sky of 100 to 1,000 wings over the island (`cockpit/tests/rota_probe.gd`). A rota bounds
how many chores a tick serves, not what one costs, so it showed the spike and could not remove it. The box is worked out
when `ai_destination` asks now, and the leg check's worst tick in the same probe is 79 us at 1,000 wings and 330 us at
5,000. Look for anything computed only so a test can read it, and compute it when read.

**Time the whole tick before tuning a part of it.** The rota was built to let a big fleet's AI run without loading every
tick, and its first scale table showed whole ticks the same on main and on the rota -- because the two chores it serves
are one per cent of a 5,000-wing tick (235 of 24,146 us). `CockpitWorld::set_tick_breakdown` times the tick into its parts
with a `Stopwatch` that reads no clock while off (7 to 8 per cent while on): the vehicles' own forces and the Box3D step
are sixty per cent, and display, after-the-step and forces grow faster than the fleet. A per-part number is what tells a
scheduler that works from a scheduler that is aimed at the wrong thing.

**A GDScript Callable from C++ is called by value.** `CockpitWorld::do_chore` copies the `Callable` out of its table
before `call()`, because the callback can call `teardown()`, which clears that table while the call is still running.

---

## Build and environment

- **The build tree cannot live on the SMB share.** CMake's `FetchContent` writes a swarm of
  small temp files into `_deps` subbuild directories; the share drops them and configure
  dies with `Cannot open file for write`. Build locally, write only the artifact across.
- **godot-cpp's API version must be pinned explicitly** (`GODOTCPP_API_VERSION "4.7"`).
  There is no `godot-4.7` tag upstream; its newest release is 4.5.
- **Kill stray Godot processes before rebuilding**, or the link fails with `LNK1104`
  because the previous run still holds the `.dll` open.
- **Nothing is fetched at configure time.** The three upstreams are explicit sibling
  checkouts. A build that silently clones a moving branch is not reproducible — and these
  libraries move fast.
- **A game keeps its own copy of the `.dll`, and a stale one fails silently.** Godot needs
  the binary inside the project, so `racer/addons/ashiato/bin/` is a *copy* of the build
  output. Copied by hand once, it then quietly went a day out of date: the extension still
  loads and every class still exists, so nothing looks wrong until a method whose signature
  moved is called. Passing a Dictionary to a binding that still expects two floats dies
  inside argument marshalling with `Index 4294967295 is out of bounds (count = 0)`, which
  names neither the method nor the project. `build.ps1` now copies the fresh binary into
  every sibling that already has the addon installed.
- **And that copy could fail while the build still said it succeeded.** A Godot holding a game's
  DLL open made `build.ps1` print `!!  could not update <game>\addons\ashiato\bin (is Godot
  running?)`, then `Build complete.`, and exit 0. On 2026-09-13 a -Double build during another
  session's run left cockpit on the previous double library; the suites that followed ran green
  on the OLD code, and only a hash of every copy against the build output showed it. **It now
  exits 1**, keeping the `!!` line and naming how many games still hold the old library.
  Measured the same day with racer's DLL held by `[IO.File]::Open(path,'Open','Read','None')`,
  which needs no Godot: before the fix `EXIT=0`, after it `EXIT=1`, and with the handle closed
  `EXIT=0` and every copy's SHA256 equal to the build output's. An exit code of 0 still says
  nothing about a game whose `.gdextension` does not name the file (`--` lines), so hash a copy
  when it matters.
- **A hash proves a copy, not a rebuild.** Relinking the same sources does not give the same
  bytes: a clean rebuild of 5e14119's sources hashed 69B036F2... against the committed
  EA1880EF.... Compare a game's DLL with the build output it was copied from, never with a
  commit after rebuilding.
- **Sources restored with `Copy-Item` rebuild nothing.** It keeps the backup's old
  modification time, so ninja finds every object newer than its source and links the old
  library again. On 2026-09-13 a "clean" rebuild after removing temporary instrumentation from
  ashiato-sync still printed the instrumentation's log line. Touch the restored files (set
  `LastWriteTime`) before building, and check the build log says it compiled them.

### The two versions are not in step

`ashiato-sync` pins its own ashiato revision, and that pin **lags** the ECS. At the time of
writing the checkout was 8 commits ahead of it, including *"big internal template
refactor"*. Building sync against ECS HEAD is a combination upstream has never tested.

It worked — compiled, linked, and instantiated. But `tools/update_upstream.ps1` exists to
keep that a visible decision: it pulls, rebuilds, runs the conformance test, and only
**then** records `upstream.lock`, so that file always names a combination known to work.

---

## What I would do differently

1. **Build the two-endpoint loopback test first**, before any game code. Every networking
   trap above was found through it, and the ones found late (peer id truncation) were the
   ones it could not reach.
2. **Instrument the connection before debugging it.** "The client sees no cars" is
   indistinguishable from "the client never connected". A `net_status()` returning client
   id, connection state, and the server's client count turned a day of guessing into one
   run. Build it on day one.
3. **Measure handling before tuning it.** Adjectives are useless; "6 deg/s, 180 m turning
   circle, on a track whose lane is 38 m" is actionable. The first correction over-shot
   into a 56 m circle the track could not accommodate, and only the probe caught it.
4. **Verify API shapes against the actual build**, never from memory or docs. `getVoice()`
   returns `{result, buffer, size}` with no `written` key; `getLobbyChatEntry` does not
   exist; `b3Quat` is `{v, s}` not `{x,y,z,w}`. Three separate wrong guesses, each caught
   only by looking.
5. **Do not gate a test on live user state.** Two tests broke because they read the
   player's saved settings rather than the shipped defaults, so they tested whoever last
   used the machine.

---

## What remains unproven

- **Two machines actually racing.** Hosting, joining and the local-client path are covered
  by `steam_host_smoke`, which creates a real Steam lobby. Packets surviving a real network
  to another player is not, and cannot be tested from one machine.
- **Rollback under real correction pressure.** The loopbacks (`driving_loopback`,
  `two_clients`, `vr_loopback`, `cockpit_loopback`) delay the link by a fixed number of
  ticks and never drop or reorder a packet. Nothing has yet exercised heavy packet loss or
  network jitter (`cockpit/tests/jitter.gd` measures float precision, not the link).
  **Reordering, loss and duplication have been measured since, for interpolated craft** (2026-09-14,
  `addon/tests/crowd_shuffled.gd`, crowd_sight's 80-autopilot sky over its 4-tick link). One packet in twenty
  swapped, dropped or delivered twice: 0 steps over a quarter tick in 95,920 craft-ticks, every missile and every
  missile end, the same as the plain link. Pathological links do hurt. Every other packet swapped gave 20,605 steps,
  against 3,840 on the same delays held in order. Every other packet dropped gave a 325-tick leap, one missile never
  seen and no missile end. Measured because cockpit's sync packets ride Steam's unreliable messages, which Valve
  documents as droppable, reorderable and duplicable. **Rollback of a PREDICTED craft under a lossy link has been
  measured since** (2026-09-16, `lane/starve`): a cockpit client over the exact two-world pump at a 16-tick link, with
  1 % loss, a 5-tick outage every 2 s and 0-4 ticks of jitter, per 600 ticks -- 70.8 rollbacks on the stock library
  against 13.0 with newest-first inputs, and 10.2 unordered. What is still unmeasured is a predicted craft over a REAL
  transport rather than a harness pump. A
  client whose prediction is badly wrong has been: predicting cars it has no input for
  measured 270 and then 300 rollbacks in 300 frames (the comment on `predict_all` in
  `racer/autoload/network.gd`), and `addon/tests/predict_all` measures how unevenly such a
  car then moves.
- **More than a handful of cars.** The stepping is now correct (see below), but nothing
  has been run with a full grid. `racer_smoke` checks that a full grid's start slots do not
  overlap; it does not simulate them.
- **The car model.** The chassis is a frictionless box, and every force that resists or
  drives it comes from four simulated tyres: grip, drive, braking and drag, tuned by the
  eighteen settings in `set_handling`, with `tire_slip` reporting how hard each works. It
  replaced the original heading-force-and-lateral-grip model in `af7ccaf`.
