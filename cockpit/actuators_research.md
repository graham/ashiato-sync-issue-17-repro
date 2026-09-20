# Timed actuators: gear, nacelles, folds, hooks and doors that take seconds, seen alike by everybody

Research for the user's request of 2026-09-17: a control commands a part of the aircraft at once, the part takes
seconds to get there (gear about 5 s), and every player in the world sees the same thing. "Instant for now, timed
later" must be a change of numbers, not of architecture.

**The recommendation, in one paragraph.** Keep the command where it is, on `CraftControls`. Beside it, keep one small
**stamp** per timed actuator: where the part was when last commanded (a byte, 0..255) and the **simulation frame** it was
commanded on (32 bits, as `GunnerState::loaded_frame` already carries a frame). The part's position is then a pure
function of frame: `position_at(frame) = from`, moving toward the command at the kind's rate, arriving after
`travel_s`. The physics reads that function every tick (nacelle angle, gear drag, wheels), rollback restores the
stamp exactly, a late joiner computes the right pose from its first record, and a watching machine evaluates it at the
frame it draws the hull at, so the two cannot drift apart. The wire carries a stamp once per command and **nothing while
the part moves**. `travel_s` is a third field on the kind's `Fitted` row, where 0 is today's instant behaviour. The
drawing never keeps a timer: an airframe exposes `set_gear(amount)`-style methods that are pure functions of a
0..1 amount, implemented procedurally today and with `AnimationPlayer.seek` once airframes are imported with
authored clips.

Everything below either supports that or records what was rejected.

---

## Part 1: how other Godot projects and netcode stacks do it

### 1.1 What Godot itself offers (4.7 documentation)

**AnimationPlayer can be driven by a number instead of by time.**
- `seek(seconds: float, update: bool = false, update_only: bool = false)`: "Seeks the animation to the `seconds` point
  in time (in seconds). If `update` is `true`, the animation updates too, otherwise it updates at process time."
  <https://docs.godotengine.org/en/stable/classes/class_animationplayer.html>
- `AnimationMixer.callback_mode_process` has `ANIMATION_CALLBACK_MODE_PROCESS_MANUAL` = 2: "Do not process animation.
  Use advance() to process the animation manually", and `advance(delta: float)`: "Manually advance the animations by
  the specified time (in seconds)." <https://docs.godotengine.org/en/stable/classes/class_animationmixer.html>
- `assigned_animation`: "If playing, the current animation's key, otherwise, the animation last played. When set,
  this changes the animation, but will not play it unless already playing." `pause()` keeps
  `current_animation_position`. <https://docs.godotengine.org/en/4.7/classes/class_animationplayer.html>

So "put the gear clip at 40 %" is `assigned_animation = &"gear"` then `seek(0.4 * length, true)` on a player in MANUAL
mode. **UNVERIFIED on 4.7.2:** that `seek(..., true)` on a player that is not playing applies the pose on the same
call. What would confirm it: a headless check that seeks and reads a keyed node's transform before the next frame. The
snopek addon below calls `play()` before `seek()`, which suggests the author did not rely on it.

**AnimationTree takes parameters, including a seek.** `animation_tree.set("parameters/eye_blend/blend_amount", 1.0)`,
BlendSpace1D "works just like BlendSpace2D, but in one dimension", and a TimeSeek node is driven with
`animation_tree.set("parameters/TimeSeek/seek_request", 12.0)`.
<https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html>,
<https://docs.godotengine.org/en/stable/classes/class_animationnodetimeseek.html>

**Tween is the wrong tool for replicated state:** "Tweens are not designed to be reused and trying to do so results in
an undefined behavior", and "Tweens start immediately". `custom_step(delta)` exists but is "mostly useful for manual
control when the Tween is paused". <https://docs.godotengine.org/en/4.7/classes/class_tween.html>

**Imported models bring clips.** A glTF can be imported as an AnimationLibrary that "can then be referenced in an
AnimationPlayer node", and you can "import **only** animations from a glTF file".
<https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html>

**Godot's own replication carries properties, never playback.** `MultiplayerSynchronizer` synchronises "configured
properties" from the authority; the page says nothing about animation or interpolation
(<https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html>). Each property is `NEVER`,
`ALWAYS` ("constantly sending updates using unreliable transfer mode") or `ON_CHANGE` ("reliable transfer mode when its
value changes"), and may also be sent on spawn
(<https://docs.godotengine.org/en/stable/classes/class_scenereplicationconfig.html>). To replicate an animation with
it you replicate a property that the animation is a function of. Cockpit does not use these nodes for craft (it uses
ashiato-sync), so this is background: every stack, Godot's included, makes you choose what number to send.

### 1.2 netfox (foxssake), the maintained rollback addon for Godot 4

State and input are separate lists on `RollbackSynchronizer`: state properties are "recorded for each tick and
restored during rollback", input properties are "gathered for each player and sent to the server". `_rollback_tick(delta,
tick, is_fresh)` gets `is_fresh` so that you can "trigger animations or sounds without them being repeated each rollback
event". Diff states send "only state properties that have changed".
<https://foxssake.github.io/netfox/latest/netfox/nodes/rollback-synchronizer/>

Its extras draw the gameplay/presentation line in so many words: "The `enter()`/`exit()` callbacks are intended for
implementing game logic. The `display_enter()`/`display_exit()` are intended for implementing presentation logic -
visuals, animations, sound effects", and "in the `enter()`, `exit()` callbacks and the `on_state_changed` signal, only
change game state". <https://foxssake.github.io/netfox/latest/netfox.extras/guides/rewindable-state-machine/>

`TickInterpolator` smooths listed properties between ticks and has `teleport()` for jumps; it says nothing about
animation. <https://foxssake.github.io/netfox/latest/netfox/nodes/tick-interpolator/>

**The example game shows both halves, and the half that matters here is the moving platform.** Forest Brawl, at
commit `3887ef96` (2026-09-13):

- **A moving part the simulation depends on is a function of the tick.**
  [`moving-platform.gd`](https://github.com/foxssake/netfox/blob/3887ef96d6515589267a29497e4b7fcefc044194/examples/forest-brawl/scripts/moving-platform.gd)
  connects `NetworkRollback.on_prepare_tick` (line 14) and places itself with `_get_position_for_tick(tick)`: seconds
  from the tick number, times speed, `pingpong`, `lerp` between two points (lines 22-27). It stores nothing. The
  brawler reads `platform.get_velocity()` inside `_rollback_tick` to stand on it
  ([`brawler-controller.gd`](https://github.com/foxssake/netfox/blob/3887ef96d6515589267a29497e4b7fcefc044194/examples/forest-brawl/scripts/brawler-controller.gd)
  lines 147-154). This is exactly "a timed actuator whose position is derived from a frame", with a start frame of 0.
- **A pose nobody's simulation reads is eased per machine.** The same controller's `_process` moves AnimationTree
  blend positions with `move_toward(..., delta / 0.2)` from the replicated velocity and floor state (lines 96-116),
  and fires a one-shot throw from `_after_tick_loop` once the action `has_confirmed()` (lines 118-121). This is
  cockpit's `_fold_drawn` pattern, and in netfox it is only used for things the simulation never reads.

A third-party .NET port records the same rule for IK: cosmetic IK is "not rollback state"; gameplay-driven IK should
"record the _inputs_ to the solver as state (aim vector, target point), never the resulting bone poses".
<https://github.com/matelq/netfox-net/issues/28> (opened 2026-09-12; a port's issue, not upstream netfox's).

### 1.3 Godot Rollback Netcode (Snopek Games): rollback of the playback itself

[`NetworkAnimationPlayer.gd`](https://gitlab.com/snopek-games/godot-rollback-netcode/-/blob/main/addons/godot-rollback-netcode/NetworkAnimationPlayer.gd)
subclasses AnimationPlayer, sets `callback_mode_process = ANIMATION_CALLBACK_MODE_PROCESS_MANUAL` (line 8) and calls
`advance(SyncManager.tick_time)` once per network tick (lines 11-13). `_save_state()` records `is_playing`,
`current_animation`, `current_animation_position` and `speed_scale` every tick (lines 15-29), and `_load_state()`
restores them with `play()` then `seek(position, true)` (lines 31-36). The README: it "will only move forward each
tick (rather than as time passes) and it supports rollback".
<https://gitlab.com/snopek-games/godot-rollback-netcode/-/raw/main/README.md>

This is the "store the position as state and step it" design (2.1 A below) applied to the animation clip itself. It
is sound for a peer-to-peer rollback where every peer simulates everything and nothing goes on the wire. It is the
wrong unit for cockpit, where the server decides and watchers interpolate, because the clip's playhead would become
simulation state and a GLB swap would change the simulation.

### 1.4 Open-source Godot aircraft: godot-simplified-flightsim

<https://github.com/fbcosentino/godot-simplified-flightsim>, commit `06cefe53` (2025-08-24), single player. It has
exactly the two treatments this request contrasts, side by side, and both files say so in their first line:

- **Flaps: position stepped per physics frame.**
  [`aircraft_modules/Flaps/Flaps.gd`](https://github.com/fbcosentino/godot-simplified-flightsim/blob/06cefe53b29e1e557530b277a1ad8c41dc915119/addons/simplified_flightsim/aircraft_modules/Flaps/Flaps.gd)
  "demonstrates how to deal with timed/animated features using delta in physics frames" (lines 1-2). A `MoveSpeed`
  in span per second (line 15) moves `flap_position` toward `target_flap_position` each physics frame (lines 58-68),
  and the lift and drag read the **travelled** position (lines 72-74), not the target.
- **Gear: a Timer and four booleans.**
  [`aircraft_modules/LandingGear/LandingGear.gd`](https://github.com/fbcosentino/godot-simplified-flightsim/blob/06cefe53b29e1e557530b277a1ad8c41dc915119/addons/simplified_flightsim/aircraft_modules/LandingGear/LandingGear.gd)
  "using states and Timer node callbacks" (lines 1-2). `DeployStowTime` (line 18). A reversal mid-travel restarts the
  timer at `DeployStowTime - move_timer.time_left` (lines 107-112, 146-152), which is the right physics. The gear's
  collision shape is enabled only when deployment **completes** (lines 128-133) and disabled the moment stowing
  **starts** (lines 165-166): the wheels bear weight only down and locked.
- **The drawing plays clips, and that is where it goes wrong.** The visual
  [`LandingGear.gd`](https://github.com/fbcosentino/godot-simplified-flightsim/blob/06cefe53b29e1e557530b277a1ad8c41dc915119/example/scenes/Airplane/visuals/LandingGear/LandingGear.gd)
  calls `$AnimationPlayer.play("Stow")` or `play("Deploy")` on each state message (lines 10-13). `play()` of the other
  clip starts it from its beginning, so a reversal at 40 % snaps the drawn legs to fully down (or up) and runs a full
  second. The clips are 1 s long
  ([`LandingGear.tscn`](https://github.com/fbcosentino/godot-simplified-flightsim/blob/06cefe53b29e1e557530b277a1ad8c41dc915119/example/scenes/Airplane/visuals/LandingGear/LandingGear.tscn)
  lines 33 and 72) while `DeployStowTime` is an export, which makes two numbers that must agree and nothing that makes
  them agree. The simulation got the reversal right and the drawing threw it away.

No networked open-source Godot aircraft with animated gear turned up. Searches for Godot flight sims found
[gd-flight](https://github.com/andrew-wilkes/gd-flight), [RivendellFS](https://github.com/ephraim71/RivendellFS)
and [SimiFlight](https://github.com/simisoad/SimiFlight), and none of those three was read for gear. **UNVERIFIED**
whether any of them animates gear. What would settle it: a code search of those repositories for `gear`.

### 1.5 Godot's multiplayer demo: send what the animation is a function of

[`networking/multiplayer_bomber/player.gd`](https://github.com/godotengine/godot-demo-projects/blob/520b4a787023e5c4172d448b46a16ecc707224f5/networking/multiplayer_bomber/player.gd)
replicates a position and the input's `motion` (the `SceneReplicationConfig`s in `player.tscn`, both
`replication_mode = 1`, ALWAYS). Every peer picks the walk animation from the motion it has (lines 47-64). The one-shot
`stunned` animation arrives by `@rpc` (lines 75-81), so a peer that joins after the explosion never plays it. That is
fine for a flash and wrong for a pose that persists, like gear.

### 1.6 The general patterns, as they apply

| pattern | what goes on the wire | example |
|---|---|---|
| **A. Step the position as state** | the position, every tick it changes | snopek `NetworkAnimationPlayer`; simplified-flightsim flaps (locally) |
| **B. Target plus start time; derive the phase** | the target and the moment it was commanded, once | netfox `MovingPlatform` (start 0); Unreal montage timestamp, below |
| **C. Replicate the command only; ease locally** | the command, once | netfox brawler blends; cockpit `_fold_drawn` today; bomber demo |

- **Unreal, state plus server time.** Steve Streeting's replicated montage struct carries `TimeRequested`, stamped
  with `GetServerWorldTimeSeconds()`. On receipt the client computes `PlayOffset = GetServerWorldTimeSeconds() -
  TimeRequested` and starts the montage that far in, skipping it entirely if `PlayOffset >= Duration`, because "network
  relevancy can delay replication for actors... suddenly have a play request from minutes ago". He rejects a multicast
  RPC for "not playing well with network relevance in the case of longer animations".
  <https://www.stevestreeting.com/2024/05/30/playing-animation-montages-in-multiplayer-games/>
  Skipping is right for a gesture. For gear it would leave a late joiner drawing the *old* configuration, so pattern B
  for a persistent pose must clamp to the end, not skip.
- **Watchers see the past, on purpose.** "Every player sees a slightly different rendering of the game world, because
  each player sees itself _in the present_ but sees the other entities _in the past_."
  <https://www.gabrielgambetta.com/entity-interpolation.html>. Unity's Netcode for Entities names the two timelines:
  "the predicted timeline which runs in your game's 'present', and the interpolated timeline, which shows late ...
  server values". <https://docs.unity3d.com/Packages/com.unity.netcode@1.4/manual/interpolation.html>. The
  consequence for B: a watcher must evaluate the phase at the frame it draws the hull at. Evaluating at its present
  would put the gear a buffer's depth ahead of the aeroplane carrying it.
- **Quantise on both sides.** "Before each simulation step you quantize the entire simulation state as if it had been
  transmitted over the network", so both ends extrapolate from the same numbers.
  <https://gafferongames.com/post/state_synchronization/>. This bears on the nacelle byte (2.4).
- **Rollback games keep presentation out of the rolled-back state.** "Game logic must be independent from everything
  else in your gameplay loop"; sounds "played in the predicted version often have to be cut short" and others "must now
  be played several milliseconds in". <https://words.infil.net/w02-netcode-p5.html>
- **Overwatch** (Tim Ford, GDC 2017, <https://www.gdcvault.com/play/1024001/-Overwatch-Gameplay-Architecture-and>):
  an ECS, server-authoritative, predicting and rolling back. **UNVERIFIED:** how it splits cosmetic from gameplay
  animation. The talk is video only and was not watched. **Rocket League** was not researched, and nothing here rests
  on it.

---

## Part 2: how this codebase does it today

### 2.1 The bus and its channels

- `enum class Channel` (`ashiato-gd/src/cockpit/cockpit_world.cpp:114-145`): Throttle 0, Flaps 1, Trim 2, Gear 3,
  Spoilers 4, **Tilt 5** ("latched because it is a configuration and not a demand", :120-123), Drop 6, **Fold 7** ("It
  changes nothing the physics knows -- the span is drawn only", :129-132), then the systems half from Weapon 8
  (`kFirstSystemChannel`, :147) to CrewToggle 14. Channel 15 is unused. The GDScript mirror is
  `cockpit/autoload/sim.gd:102-106`.
- Switch bits: `kGearBit` 1<<0, `kSpoilerBit` 1<<1, `kDropBit` 1<<2, `kFoldBit` 1<<3 (:149-154).
- `Fitted{name, range}` (:629-633), sixteen per kind in `Bus` (:635-637). Per kind (:1540-1680): the Hawkeye has
  `Fitted{"wing fold", 1}` (:1592), the Osprey `Fitted{"nacelles", 255}` (:1612) and `Fitted{"gear", 1}` (:1614).
  **The Gear channel means different things on different kinds**: the Chinook's "ramp" (:1621), a tank's "parking
  brake" (:1653) and a car's "handbrake" (:1657). A travel time must therefore be per kind *and* per channel.
- `apply_command` (:10502-10570) clamps to `range` and writes `CraftControls` for channels below 8 (:10513-10520).
  Tilt is `bus.tilt = clamped / 255.0f` (:10533-10535). Gear flips the bit and refuses gear-up with weight on the wheels,
  the squat switch (:10536-10546). Fold refuses folding without weight on the wheels (:10552-10562).
- **It runs on the server only.** The command sequence is edge-detected under `if (is_server_ && input.command_seq !=
  ...)` (:10424-10427). Compare the throttle, which every machine applies from its own input so that the pilot's
  machine predicts it (:10333-10351).

**How the values reach physics, and whether anything is rate-limited.**
- **Nacelles jump.** `fly_tiltrotor` reads `levers.tilt` the tick after it is written (:14132-14133) for the thrust
  direction (:14137-14138), the wing-to-rotor thrust blend (:14141-14145) and the control authority floor
  (:14148-14153). Nothing limits the rate in the simulation. The only limits are the pilot's hand on `TiltLever` and
  the command queue: `send_command` keeps the latest value per channel (:5494-5496), and each value rides the input
  frames for `kCommandRideSeconds` = 1/30 s (:3748).
- **Gear jumps.** `gear_down()` is the bit (:14091-14094). That same tick the undercarriage decides wheels or belly
  (:11187-11190, the belly at :13822-13830), and drag is `gear_drag` on or off (:13678-13680).
- **Autopilots write the bus directly:** nacelles forward at spawn (:5203-5210), gear stowed once clear of the ground
  (`publish_levers`, :13333-13361). **Spawning** sets gear down and wings folded on something solid (:4662-4684), and
  `launch_if_grounded` spreads folded wings (:10897-10902).

### 2.2 How it replicates and predicts

- `CraftControls` (`ashiato-gd/src/cockpit/cockpit_components.hpp:536-554`) is throttle, flaps, trim, tilt and
  switches. Its trait writes 7 + 7 + 9 + 7 + 8 = **38 bits** (:1682-1692). `unit` is 1/64 over 0..1, which is
  7 bits (:150), and `axis` is 1/128 over -1..1, which is 9 bits (:136). sync's `bits_for_max_value` (steps 64 → 7, 256 → 9) is
  `ashiato-sync/include/ashiato/sync/serialization.hpp:51-58, 80-82`.
- It is on the Vehicle archetype, audience All, **Step** (`cockpit_world.cpp:3964-3972`). Interpolation returns
  `from` (`cockpit_components.hpp:1726-1730`).
- `should_roll_back` is true on **any** switches difference, or when throttle, flaps or trim differ by more than
  0.06, or tilt by more than 0.03 (:1715-1724).
- **On the pilot's predicting machine a command arrives as a rollback.** "On a predicted entity an authoritative
  value only arrives ON A ROLLBACK" (`cockpit/agents.md:2289-2291`; also `ashiato-gd/DATA_MODEL.md:224-227`). Since
  `apply_command` is server-only, every gear, fold or tilt command costs the pilot's world one resimulation, and the
  pilot sees the change a round trip after pressing.
- **On a watching machine a Step record is applied when the buffered clock reaches its frame.** A record that lands
  later than the buffer is deep is applied on arrival (`cockpit/agents.md:1514-1517`).
- **A late joiner gets whole components.** "Every trait still writes its component in full ... a boarder's first
  cabin record is absolute values" (`cockpit/agents.md:1549-1551`). "Quantize is sync's change detector": a component
  whose quantised bytes are unchanged costs a bit (`ashiato-gd/LEARNINGS.md:339-345`).
- **Frames are shared, and the house already carries one.** `GunnerState::loaded_frame` is "A FRAME, not a time: a
  rolled-back reload is exactly the frame the replay reaches, and a clock in seconds would be one more thing that is not
  rolled back" (`cockpit_components.hpp:1026-1028`). It is 32 bits on the wire (:2308) and rolls back on difference
  (:2334). The simulation reads `registry_.get<ashiato::sync::FrameInfo>().frame` (`cockpit_world.cpp:10260`), and a
  client knows how far behind its drawn frame is with `client_->continuous_buffered_frame()` (:10272).
- **Birth records are the house's version of pattern B.** A shell is "sent -- ONCE -- and every machine draws the
  same flight from it" (`cockpit_components.hpp:725-736`); a train is one distance along a known track (:556-572).

### 2.3 The one timed animation: the Hawkeye's wing fold

`vehicle_view.gd` keeps `_fold_drawn` (`cockpit/objects/vehicles/vehicle_view.gd:64-65`). At setup it starts at the
bus's end state (:183-184). Each `draw()` it moves `_fold_drawn = move_toward(_fold_drawn, want,
get_process_delta_time() / HawkeyeAirframe.FOLD_SECONDS)`, where `want` is the bus bit
(:2898-2900). `FOLD_SECONDS` is 12.0, "an estimate" (`cockpit/objects/vehicles/hawkeye_airframe.gd:80`,
`cockpit/agents.md:8630-8631`). An honest assessment:

1. **It runs on frame time, per machine.** It advances by render delta, not by simulation frames. A hitch or a
   slow machine stretches it in wall time on that machine alone, and nothing brings it back in step.
2. **A late joiner snaps.** Setup starts at the end state of the bit (:183), so a player who joins at second 4 of
   the 12 sees the wings already folded.
3. **Two machines are out of phase by their link and buffer.** Each machine starts easing when the Step record is
   applied there, which is the buffered clock on a watcher and a rollback on the pilot's machine. They start at
   different instants and nothing corrects them. Over a link longer than the buffer, the record is applied on
   arrival (agents.md:1514-1517), so the offset is the link itself.
4. **It cannot tell a physics part from a cosmetic one.** The drawn value exists only in the view. Here that is
   harmless, because the physics never reads the fold (cockpit_world.cpp:129-132). The same pattern on gear would draw
   legs coming down while the simulation had already put the aircraft on its wheels, or on its belly, at the command.
5. **Its duration is typed in the view.** `hawkeye_shot.gd:107` waits `FOLD_SECONDS + 2.0` to photograph it, which
   is a second reader of a number the simulation has never heard of.
6. **Nothing else eases.** `move_toward` on gear or tilt appears nowhere in cockpit. The nacelles are set straight
   from the bus every draw, `pivot.rotation = Vector3(swing * TiltLever.SWING, 0, 0)` (vehicle_view.gd:2901-2904), so
   they snap. The Osprey's gear is "fixed visual" (:836-838). `TiltLever.SWING = 1.702` (`tilt_lever.gd:20-21`) and
   `kNacelleTravel = 1.702f` (`cockpit_world.cpp:14098`) are one number in two places.

### 2.4 Found while reading: the nacelle command is finer than its wire

`Fitted{"nacelles", 255}` and `bus.tilt = v / 255` on the server (`cockpit_world.cpp:1612, 10534`), but the wire
carries tilt as `unit`, which is 1/64 (`cockpit_components.hpp:1690`). The server's physics reads the registry float
(`fly_tiltrotor`, :14132). `quantize_through_the_wire` produces the decoded copy that sync compares and sends
(`cockpit_components.hpp:1197-1215`; `LEARNINGS.md:339-345`). So a client that adopts the authoritative value flies,
for example, 32/64 = 0.5000 while the server flies 128/255 = 0.5020: 0.2 % of 97.5 degrees, under the 0.03
rollback threshold, and never corrected. **UNVERIFIED:** that sync never writes the quantised value back into the
server's registry. What would confirm it: print `levers.tilt` inside `fly_tiltrotor` on the server and on a client
at one frame after a tilt command of 128. The recommendation below carries the nacelles as a byte, which ends this
either way.

### 2.5 Work in flight this touches: `lane/hornet`

On disk, `C:\gg-wt\hornet` is at `de67f2ee`, main's head, with a clean tree (checked 2026-09-17). Its gear and hook
work is therefore only in its brief: gear drawn through `set_gear(amount)` on the airframe and driven the Hawkeye way,
and a HOOK on channel 15, switches bit 4. **Channel 15 would not reach the switches.** `apply_command` treats
`channel < kFirstSystemChannel` (8) as physical (`cockpit_world.cpp:10513`). Channel 15 would take the systems branch
(:10571-10590), skip the flying-station check and never touch `CraftControls`. `craft_schema` would report it
`physical: false` (:6150). Physical channels 0-7 are all taken, and the bus has sixteen slots (:636), with 16 and up
refused (:10504). See 3.8 for what to do.

---

## Part 3: the recommendation for this game

### 3.1 Where the line is, per actuator

**The rule:** if the simulation reads a part's position, or a rule depends on it, the position is simulation state,
derived from a replicated stamp and identical on every peer. If it is only how a position *looks* (door panels
opening first, legs swinging on their own curves, a strut compressing), it is a function of that position inside the
airframe and never reaches the wire.

| actuator | kinds | what reads the position | treatment |
|---|---|---|---|
| **nacelle tilt** | Osprey | thrust direction, thrust blend, control floor (`fly_tiltrotor`) | simulated. Continuous: the nacelles chase the lever at a fixed rate |
| **gear** | winged kinds with a Gear channel | drag ∝ position; wheels bear weight only when fully down and locked; else belly | simulated. The squat switch stays on the **command** |
| **tailhook** | Hornet (new) | a future wire catch needs it fully down | simulated |
| **tank doors** (Drop) | water bomber | the water flows | simulated; travel 0 until asked |
| **flaps** | most winged | lift and drag (:13669, :13678) | simulated if ever timed; travel 0 now, since the lever has detents |
| **wing fold** | Hawkeye, Hornet | nothing today (:129-132) | **simulated anyway.** Outsiders see it, and pattern B costs a fold nothing extra. It also retires `_fold_drawn` and `FOLD_SECONDS` |
| **ramp** (Gear channel) | Chinook | nothing today (a helicopter's `winged()` is false) | simulated anyway, for boarding and cargo later |
| **handbrake, parking brake** (Gear channel) | car, tank | the brake | travel 0, which is today exactly |
| gear doors, leg sequencing, hook fairing, fold hinge covers | airframes | nobody | **drawn only**, from the simulated 0..1 |
| rotodome, propellers, rotor discs | airframes | nobody | unchanged: this machine's physics clock, out of phase by design (agents.md:8635-8636) |

Three points in that table are design decisions for the user (3.9, questions 2-4).

### 3.2 Where the travel lives, and what it costs

**Recommended: pattern B, in C++, as a stamp per timed actuator.**

```cpp
/// ONE TIMED PART: where it was when last told, and the frame it was told on. Its position is `position_at`, a pure
/// function of the frame -- so a rollback restores it exactly, a late joiner computes it, and a watcher evaluates it
/// at the frame it draws the hull at.
struct ActuatorStamp {
    std::uint8_t from = 0;     // 0..255, the channel's own scale
    std::uint32_t since = 0;   // FrameInfo::frame the command was applied on
};
struct Actuation {             // on the Vehicle archetype, Step, All
    ActuatorStamp part[kMaxTimedParts];   // in the kind's timed channels' channel order
};
```

- **The target is the command already on `CraftControls`** (a switch bit, or the tilt, carried as a byte; see 3.4).
- **`position_at(frame)`**: with `ticks = round(travel_s × tick_hz)` for the full 0-to-255 travel, the position moves
  from `from` toward the target at 255/`ticks` units a frame and stops there. `travel_s == 0` returns the target, which
  is today. Compute it from integers alone (the bytes and the frame difference) into a float, so every peer of the same
  build computes the same value. Box3D prediction already rests on that (`LEARNINGS.md`, "Rollback fidelity").
- **`apply_command`** sets the new target and re-stamps `from = position_at(now), since = now`. A reversal
  mid-travel therefore goes back from where the part is, taking the fraction of travel it has covered. That is the
  simplified-flightsim gear's `DeployStowTime - time_left` (LandingGear.gd:108-110) without a Timer.
- **Spawn, the autopilot's nacelles and `launch_if_grounded`** write a settled stamp (`from = target`), so a parked or
  teleported craft arrives in its configuration rather than moving into it (agents.md:8612-8619 keeps meaning what it
  says).
- **Its trait** writes 8 + 32 bits a part, rolls back on any difference (as `GunnerState` does,
  `cockpit_components.hpp:2334`) and interpolates by returning `from`.
- **Why not on `CraftControls` itself:** that component is written whole whenever any field changes
  (agents.md:1549), and the throttle changes on every tick a trigger moves (`cockpit_world.cpp:10342-10350`). Stamps
  folded in would ride every throttle record.
- **Why a frame and not seconds:** the reason `loaded_frame` gives (`cockpit_components.hpp:1026-1028`).

**Bandwidth, per client.** Record overhead is sync's own, the same for each design, and not counted here;
`cockpit/tests/wire_budget.tscn` measures it.

| design | while a part moves | per command | one 5 s gear cycle at 120 Hz | 200 craft cycling at once |
|---|---|---|---|---|
| **A1** position byte added to `CraftControls`, stepped | 46 bits **every tick** | 46 | 600 × 46 = 27,600 bits ≈ **3.45 kB** | ≈ 138 kB/s, 56 % of the 245 kB/s budget |
| **A2** positions in their own component, 4 × 8 bits | 32 bits every tick | 32 | 600 × 32 = 19,200 bits ≈ **2.4 kB** | ≈ 96 kB/s |
| **B** stamps, 4 × 40 bits | **0** | 160 | **160 bits = 20 B** | 4 kB, once |
| **C** command only, eased per machine (today's fold) | 0 | 0 extra | 0 | 0 |

Why the per-tick rows matter even though fleets rarely cycle gear together: the 200-aircraft ladder already sits at
the budget's plateau (245-248 kB/s down per client, `cockpit/agents.md:13415-13446`), and the budget is bytes a second
(:13557-13559). Every per-tick bit on a moving part is taken from pose freshness at exactly the load where freshness was
shown to hold (:13471-13477). Under starvation a stepped part also *holds and leaps* like the craft did
(:13543-13547), where a derived part is exact from whatever record it has. The nacelle lever dragged across its travel
re-stamps at most 30 times a second (`kCommandRideSeconds`), 600 B/s only while a hand is on it. Today's tilt float
changes at the same rate.

**Rejected, and why:**
- **A (step the position):** correct and simple, and it also handles motion that is not closed-form, such as a gear
  jammed by damage. It pays per tick for what B sends once, and it moves at 8-bit resolution on a watcher unless it
  also becomes Interpolate. If a non-closed-form actuator is ever needed, that actuator can be A without changing the
  others. Every change of rate becomes a re-stamp under B anyway.
- **C (today's fold):** the six faults in 2.3. It is also unusable for tilt and gear, whose position the physics reads.
- **Replicating the Godot AnimationPlayer's playhead** (snopek, 1.3): makes an imported clip's timeline part of the
  simulation. A re-authored clip would change the aircraft.
- **Predicting the command on the pilot's machine** (running `apply_command` in the replayed job): would remove the
  one-round-trip delay before the part starts. Not needed: 5 s of travel hides about 100 ms, and it is a separate
  change to how commands are edge-detected (:10413-10427). Rejected for now.

### 3.3 "Instant now, 5 s later" as data

- **One place:** the kind's `Fitted` row gains `travel_s`, e.g. `Fitted{"gear", 1, 5.0f}`, `Fitted{"nacelles", 255,
  12.0f}` and `Fitted{"wing fold", 1, 12.0f}`, with a default of 0. It is compiled into the library, so every peer has
  the same numbers. `set_handling` (`cockpit_world.cpp:6493`) is per world and would not be.
- **Exposed, never copied:** `craft_schema` (:6138-6158) adds `"travel_s"` beside `"range"`. `FOLD_SECONDS` is
  deleted, and `hawkeye_shot.gd:107` reads the schema.
- **Frames from seconds** use the world's tick rate (:6440-6443). **UNVERIFIED:** that server and clients are always
  started at the same tick rate. What would confirm it: a joiner started at 60 Hz against a 120 Hz host either refused
  or not. If they can differ, `travel_s` must be converted with the server's rate, sent at join.
- A timed channel gets a stamp slot by being fitted with `travel_s > 0`. `static_assert` or a start-up check keeps
  each kind at or under `kMaxTimedParts`, which is 4.

### 3.4 Quantise the position to the channel's own 0..255

Carry the tilt target as the byte that was commanded (8 bits in place of `unit`'s 7). Compute every position from
bytes and frames on every machine. That is Fiedler's quantise-both-sides rule, and it closes 2.4. A switch's target is
its bit, 0 or 255. The float the physics reads is `position_at / 255`, the same on the server and on a replaying client.

### 3.5 The drawing

- **C++ answers "where is it drawn".** A binding such as `actuators(entity) -> Dictionary` (`"gear": 0.43`, `"tilt":
  ...`) evaluates `position_at` at the frame this machine draws that entity at: the predicted frame for the craft it
  predicts, the continuous buffered frame for one it interpolates (the clock `cockpit_world.cpp:10272` already reads),
  and the server's frame on the host. **UNVERIFIED:** which exact client accessor matches the frame the pose in
  `vehicle_states()` comes from. Test 5 in 3.7 pins it. `Sim` then lerps it between `previous` and `current`, exactly as
  it does the pose (`cockpit/autoload/sim.gd:811-820`).
- **The airframe owns the look, as a pure function of an amount.** Standardise on methods named for the part:
  `set_gear(amount)`, `set_hook(amount)`, `fold(amount)` (already `hawkeye_airframe.gd:204`) and `tilt(amount)`. They
  are idempotent and hold no memory: `set_gear(0.3)` then `set_gear(0.5)` must equal `set_gear(0.5)`. Door-then-leg
  sequencing is inside, on the amount (doors 0-0.2, legs 0.2-0.8, doors 0.8-1.0).
- **Procedural airframes today** pose their nodes directly, as `fold` does.
- **Imported GLB airframes later** keep the same method and implement it with an `AnimationPlayer` in
  `ANIMATION_CALLBACK_MODE_PROCESS_MANUAL`: `assigned_animation = &"gear"; seek(amount * length, true)`. The clip's
  length is a *normalised timeline* for sequencing, not the real duration, so it never duplicates `travel_s`. An
  airframe that already needs an AnimationTree may use a TimeSeek node inside the method.
- **Rejected as the standard:** `play()` of clips (time-driven per machine, the reversal snap in 1.4); Tween (starts
  itself, not reusable); an AnimationTree BlendSpace1D as the *interface* (fine for two poses, but a multi-stage
  sequence is a timeline, and the method hides the choice anyway).
- **The controls show the command, the gauges show the position.** Rule 5 ("pressing a switch does not move it") is
  already the lever's contract. `flight_page.gd:189-190` gains an in-transit state. The MFD's tilt
  (`vehicle_view.gd:2648-2649`) shows the travelled angle.

### 3.6 Late joiners, rollback and interpolation, design by design

| | **B (recommended)** | A (stepped) | C (today) |
|---|---|---|---|
| **joiner at mid-travel** | first `Actuation` and `CraftControls` records are whole (agents.md:1549); `position_at(drawn frame)` is mid-travel on the first drawn frame | the first record holds the position: mid-travel, but it steps at record rate | snaps to the end (vehicle_view.gd:183) |
| **pilot's rollback across the command** | the command arrives as a rollback (2.2); the replay restores the stamp at frame S and every replayed frame computes `position_at(S+k)`: nothing restarts, nothing is skipped | the snapshot restores the position at S and the replay steps it the same way: equally correct | the drawn value is outside the rollback and starts when the rollback lands |
| **pilot's rollback for an unrelated reason** | the stamp is unchanged, so the position is a function of the replayed frame: no effect | restored and re-stepped: no effect | no effect |
| **watcher's phase** | the stamp is applied at the buffered clock (agents.md:1514); evaluated at the same buffered frame as the hull: **exactly in phase with the pose**, so a watcher is behind the server by its buffer and nothing else | in phase while records keep up; holds and leaps when starved (agents.md:13543-13547) | behind by link plus buffer, drifting with frame time |
| **a record later than the buffer** | applied on arrival and jumps to the **correct** phase, since `since` says when it began | the position jumps to the late value | starts late, and stays late |

### 3.7 Tests that would prove it

New `ashiato-gd/addon/tests/actuators` (loopback, a server and two clients over links shorter *and* longer than the
buffer, per agents.md:1517), plus changes in the cockpit suites. Named checks:

1. `gear_commanded_at_frame_T_is_down_and_locked_at_T_plus_travel_on_the_server`: the frame count equals
   `round(5.0 × 120)` = 600, neither 599 nor 601.
2. `travel_zero_is_today_exactly`: every kind with `travel_s = 0`, a 600-tick recording of pose, drag and wheel
   contact through gear, fold and tilt commands, byte-identical to the library before the change. Land the tilt byte
   (3.4) as its own measured step first, since it changes the tilt float.
3. `the_nacelles_thrust_follows_the_travelled_angle_not_the_lever`: tilt 0 → 255 with travel 12 s. At +6 s the thrust
   direction the world reports matches 0.5 × 97.5 degrees, not 97.5.
4. `gear_drag_follows_travel_and_the_wheels_take_weight_only_when_locked`: drag at half travel lies between the two
   ends, and touching down at 0.9 bellies.
5. `a_watcher_draws_the_same_phase_as_the_server_at_the_frame_it_draws_the_hull`: at each drawn frame F, the
   watcher's actuator value equals the server's `position_at(F)` to the byte, over a 1-tick and a 4-tick link.
6. `a_late_joiner_at_mid_travel_draws_mid_travel_on_its_first_drawn_frame`: join at +2.5 s; the first drawn value is
   within one tick of 0.5.
7. `a_rollback_across_the_command_neither_restarts_nor_skips`: the pilot's machine's per-frame series of drawn
   positions after the command is non-decreasing, never moves more than one tick of travel between frames, and equals
   the server's from the frame the rollback lands.
8. `reversing_mid_travel_goes_back_from_where_it_is`: up at 40 % reaches up 40 % of travel later.
9. `the_squat_switch_still_refuses_the_command`: the existing check, `cockpit_loopback.gd:2469-2472`, unchanged.
10. `a_moving_part_costs_nothing_on_the_wire_between_commands`: the traced server during a 5 s cycle writes exactly
    one `Actuation` record per command (`wire_budget.tscn` method).
11. `set_gear_is_a_function_of_its_amount` (GDScript, per airframe): 0.3 then 0.5 gives the same vertices as 0.5, and
    0 and 1 match the table's stance, measured from drawn vertices as `fleet_shapes.gd:371-388` does.
12. **Look at it:** two windows, one flying and one watching, photographed mid-fold and mid-gear; a probe beside
    `hawkeye_shot.gd`, not a suite.

### 3.8 Migration, in steps that each land green

1. **The tilt byte** (C++): tilt on the wire as 8 bits of the commanded byte. Measure the rollback count and the
   wire in `cockpit_loopback` and `wire_budget`. No behaviour change beyond 2.4.
2. **Stamps with every travel at 0** (C++): `Fitted::travel_s`, `Actuation` with its trait and archetype entry,
   `position_at`, and `apply_command`, spawn, autopilot and `launch_if_grounded` stamping. `gear_down`, the gear drag,
   the belly and `fly_tiltrotor` read positions. `craft_controls` keeps `"gear"` and `"fold"` as the **commands**
   (`cockpit_loopback.gd:2460-2522` and `fleet_shapes.gd:297-365` keep reading them). `craft_schema` gains
   `travel_s`. Gate: test 2, plus the full cockpit and addon suites.
3. **The drawing reads positions** (C++ binding, then GDScript): `actuators(entity)`, and `Sim` snapshots and lerps
   it. `vehicle_view.gd` swings nacelles and folds wings from it. Delete `_fold_drawn` and `FOLD_SECONDS`.
   `hawkeye_shot.gd` waits on the schema. Suites: `fleet_shapes`, `bench`, `smoke`.
4. **The numbers** (C++ data): the travel times the user settles (3.9, question 1). Checks that assert a physical
   effect right after a command learn to wait `travel_s`. Add the in-transit instruments. Tests 1 and 3-8, 10.
5. **The hook and the Hornet** (C++, GDScript): make "physical" a property of the channel rather than `channel < 8`,
   for example `constexpr bool is_physical(channel)` true for 0-7 and 15. It is used by `apply_command` (:10513),
   `craft_schema` (:6150) and the GDScript enum's readers. Add `HOOK = 15` and `kHookBit` 1<<4 (switches has 8 bits;
   no wire change). The alternative, renumbering the systems half, changes every saved layout and binding that stores a
   channel number, so it is rejected.

**What `lane/hornet` should do now:** build `set_gear(amount)` and `set_hook(amount)` exactly as 3.5 describes: pure
functions of 0..1, measured at 0, 0.5 and 1 from their vertices. **Do not add a `GEAR_SECONDS` or a second
`move_toward`.** Until step 3 lands, drive them the way the nacelles are driven today, straight from the command
(1.0 or 0.0), so there is nothing to delete later. Leave the HOOK channel to step 5, or build it on the predicate change
described there and not on channel 15 as a systems channel.

### 3.9 Questions for the user, each with a recommended answer

1. **Where do travel times come from?** *Recommended:* published figures for each type where one exists, otherwise an
   estimate marked as one beside the number (as `FOLD_SECONDS` is today). Gear defaults to 5 s both ways, as asked.
2. **While gear travels, what does the aircraft feel?** *Recommended:* drag in proportion to the travelled position;
   the wheels bear weight only when fully down and locked. Touching down before then is a belly, as a gear-up landing
   is today.
3. **Do the nacelles chase the lever?** *Recommended:* yes. The lever is where the hand put it, and the nacelles
   follow at one fixed rate (full travel in `travel_s`), so a small change is quick and a conversion takes the full time.
4. **Should a half-spread fold stop a take-off?** *Recommended:* not now. The fold stays physics-free, as it is
   today; timed, it only changes what everybody sees. Revisit with the carrier catapult.
5. **Controls or position on the instruments?** *Recommended:* the lever and switch show the command at once; the
   gauges show the position with an in-transit state, like a real gear indicator.
6. **A craft spawned, parked or taken over in the air:** *Recommended:* it arrives settled in its configuration, with
   no travel on the first frame.

### 3.10 The user's answers, 2026-09-17

These are binding for whichever lane builds this.

1. **Travel time is a number you can change, not a figure to research.** *"we should have a way to indicate that a
   change takes time, i chose 5 seconds arbirarity, the amount of time isn't important right now, we just need to be
   able to adjust it."* So the deliverable is the mechanism: a per-kind, per-channel `travel_s` in one place, where 0
   means instant. 5 s for gear is a placeholder, not a published figure; label it as one. **Don't spend a lane
   researching real travel times.** Make changing one easy (see §3.3), and ideally changeable without a rebuild, the
   way the priority sphere's values are (`Sim` constants passed to the world, plus a command-line flag).
2. **No curves for now.** *"yes, we should have curves for this, but that seems like a lot of work, we can ignore that
   for now."* Travel is linear in time, and whatever the physics reads from a position is the simplest honest mapping
   (§3.1): drag proportional to position, and wheels bearing weight only when locked. Response curves (ease-in/out
   travel, non-linear drag) are a later item. Keep `position_at(frame)` the one place a curve would go, so adding one
   changes no caller.
3. **Yes:** the nacelles chase the lever at one fixed rate.
4. **Yes, but skip it for now:** a half-spread fold should eventually stop a take-off. Not in this work; the fold stays
   physics-free. Note it as a follow-up.
5. **Build DISPLAY devices.** *"we'll need to start building "display" devices that just read content and show it.
   Gear position and flap position are good examples, (we need airspeed and altitude as well)."* This is broader than
   the gear indicator in §3.9. It asks for a class of cockpit part that **only reads and draws**: no control, no
   channel write, no grab. It reads a named quantity (gear position, flap position, airspeed, altitude to start) and
   shows it. It belongs with the builder's parts, so a station can be fitted with one. It's its own item: see
   `cockpit/plan.md`. The actuator work must expose gear and flap **position** (not only the command) in a form such a
   display can read.
6. **Yes, and it matters for spawning:** a craft loaded, spawned or taken over arrives settled, with no travel. *"that
   will lead to less spawn bounce."*

---

*Sources were read on 2026-09-17. GitHub links are pinned to the commits named. The snopek GitLab file is on
`main`, last commit `0b907fb8` (2026-06-06). Internal line numbers are for `main` at `de67f2ee`.*
