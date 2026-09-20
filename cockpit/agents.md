# AGENTS.md — cockpit

> Compressed on 2026-09-20. Rules, measurements, rejected alternatives and file
> references were kept; repetition, chronology and superseded entries were cut. The
> pre-compression text is archived outside the repository, in
> godotgames-context-archive/docs-2026-09-20.tar.gz on the workstation's Desktop.

Every player is flying something. There is no on-foot state, and adding one would undo
most of what makes this project work.

| Item | Value |
|------|-------|
| Engine | Godot **4.7**, **Mobile** renderer (Mobile until 2026-09-14, Forward+ for a day, Mobile again since: see "Back to Mobile on 2026-09-15"). The engine carries one patch of this workshop's own, `tools/godot-patches/`, without which Mobile cannot compile a shader on a double build |
| Precision | **double** (`_tools/godot-4.7.2-double`), which the headset plays: `tools/play.ps1`. Shaders take the eye from `EYE_POSITION_WORLD`, never `CAMERA_POSITION_WORLD` (minus the camera on double). Far out, meshes are steady and billboards (`skip_vertex_transform`) still step on float32's grid: see "What the double build does and does not steady" |
| Simulation | **ashiato** ECS + **ashiato-sync** replication + **Box3D**, all inside `addons/ashiato` |
| Godot physics | **not used for anything that moves.** The ECS owns every moving object |
| Main scene | `res://world/boot.tscn` (the router; `sky.tscn` is the flight world) |
| Set up from a clone | `../ashiato-gd/tools/bootstrap-linux.sh`, or `bootstrap-windows.ps1` on Windows |
| Build the extension | `../ashiato-gd/tools/build.ps1 -WithCockpit -WithDriving -WithVr` (copies the DLL here) |
| Networked | ENet, or Steam by a join code, a look round the open games, or an invite (see "A JOIN CODE, AND STEAM"); ashiato-sync packets over one `unreliable_ordered` RPC |

## WHICH FILE ANSWERS WHICH QUESTION

This file carries the decisions and rules that every other one assumes, the boot path, the test
suites and the queue. The rest is four files under `cockpit/docs/`, split so a session reads the
one it needs instead of all of it. **Section names are unchanged**, so anything that quotes one
still finds it.

| If you are asking | Read |
|---|---|
| What flies, how does it move, what is it flown from, and what does the pilot see out of it? | [`docs/craft.md`](docs/craft.md) |
| What is it flown over -- the ground, the sky, the scenery and its cost, the levels? | [`docs/world.md`](docs/world.md) |
| How do several people get into one aeroplane and one session, and how do they talk? | [`docs/crew.md`](docs/crew.md) |
| What is fired, dropped or sunk, and what are the craft built to do it? | [`docs/combat.md`](docs/combat.md) |
| Where does a new test belong, what tier does it get, and what is already covered? | [`docs/testing.md`](docs/testing.md) |
| What are the rules, where does the game start, how is it tested, what is still owed? | this file |

**`docs/world.md` is the next candidate to split**, at about a third of the whole document: the
seam is the scenery and the time of day against the terrain, the levels and the places built on
them. It is left whole on purpose — one cut at a time, and a file you only open for world work is
not yet costing anybody. `tests/docs.gd` holds this index to the files: a file no row names, a row
naming a file that is not there, and a section heading living in two files are all failures.

## THE ONE DECISION: A PILOT HAS NO WORLD POSE

A pilot's head and hands are replicated as offsets **inside their seat**, and never as a
position in the world. Nothing anywhere composes them into one — not for the wire, not for
the renderer, not for gameplay.

That is not a saving. It is what makes a cockpit steady at any speed:

- A hand held still has a **constant** seat-local transform whether the aircraft is parked
  or doing 200 knots. The vehicle's speed is not a term in the expression, so no amount of
  it can add jitter.
- There is no second pose that could disagree with the vehicle's. A pilot cannot drift out
  of their seat, arrive a frame late, or be published where the aircraft is not, because
  none of those states can be written down.
- The vehicle's pose is then the **only** thing whose smoothness has to be worked at,
  which reduces the whole problem to interpolating one transform per vehicle.

Measured, and these are the numbers to re-check if anything here changes:

| | |
|---|---|
| a still hand, in the seat, at 34 m/s | **0.000000000 m** |
| the view, likewise | **0.000000000 m** |
| the same, seen from another client across a 133 ms link | **0.00000 m** |
| drawn pose vs the segment between two simulated states, 580 frames | **0.000000 m** |
| eight equal slices of one tick | ratio **1.000** |

## RULES

1. **Never set a world transform on a rider.** The local rig and every remote pilot are
   CHILDREN of a seat anchor on the vehicle's node. `PilotRig` never writes one; if it
   ever needs to, something has gone wrong upstream of it.
2. **Never write a position into the simulation from a node.** Ask, and move the node. A
   node cannot disagree with the simulation because it is never consulted.
3. **ONE CLOCK.** The simulation ticks exactly once per Godot physics frame, and
   `Engine.physics_ticks_per_second` is set from the tick rate to make that true. The
   fraction between ticks is `Engine.get_physics_interpolation_fraction()`.

   Two clocks is the bug this project was restarted over: ticks scheduled on Godot's
   physics clock, the fraction between them measured with the render delta. Godot
   deliberately smooths one against the other, so they disagree by a wandering fraction of
   a frame, and that wander goes straight into the drawn position. A controller held
   perfectly still shakes, because the frame it is drawn in is moving.
4. **Vehicles are drawn by interpolating the last TWO simulated states**, captured once per
   tick in `Sim._capture_states`. Never by reading the live state, which holds for a frame
   and then jumps.
5. **The tick rate is part of the simulation's definition** and every peer must agree —
   a rollback replays ticks. It changes only between sessions, and `Sim.request_tick_rate`
   refuses while networked. It is the bandwidth dial: traffic is very nearly linear in it.
6. **The interpolation buffer is live and per-machine.** It only decides how far into the
   past this client draws the entities it is interpolating.
7. **Nothing may read state before `Sim.is_ready`.**
8. **Static collision must be built identically in every world**, through
   `Sim.add_static_box`. It is not replicated, so a peer whose ground is elsewhere predicts
   itself into it.
9. **Godot peer ids and sync client ids are different numbering schemes.** The server is the only
   bridge: `server.client_of_peer(peer)`, filled from sync's own connection events. It was a
   reliable Godot RPC in which each joiner told the host its own id, which was game data on
   Godot's multiplayer and a claim taken on the joiner's word. The one Godot RPC left is the
   packet transport, `Net._receive`, and `tests/lint.gd` fails on any other.
10. **Adding a replicated component or a vehicle kind costs C++**, in
    `../ashiato-gd/src/cockpit/`. That is the price of a tuned wire format.

## WHAT IS PREDICTED

Three things, each because this machine has the input that drives them: your own pilot,
and the vehicle you are in seat 0 of. Everything else is buffered interpolation — nobody
receives anybody else's input, so a predicted entity you do not fly is a guess
resimulation cannot correct, and it rolls back every frame for ever.

A rollback correction moves the simulation immediately, because the next tick runs from
it. The **picture** does not: `CockpitWorld` keeps a visual offset that absorbs the
correction and decays it out over `set_correction_blend` seconds.

## CONTROLS

Four axes, which is what goes on the wire: **throttle, pitch, roll, rudder**, plus a brake.
Each model reads the ones it has: a car ignores pitch and roll and steers on either stick's
horizontal axis, a helicopter's throttle is collective rather than forward thrust.

The brake is pure -- a constant force opposing travel plus extra drag that scales with the
square of speed, so it bites at 60 m/s as well as at 5. It brings a vehicle to an exact
stop and can never reverse it; see "Nothing may reverse what it is resisting" above.

WHAT A CONTROLLER DOES WITH AN EMPTY HAND. Every row below is one entry in
`PilotRig._global_bindings`, and every one of them can be overridden by whatever the hand
picks up -- see the next heading.

| | VR, empty hand | Flat |
|---|---|---|
| pitch / roll | left stick | W/S, arrows or A/D |
| rudder | right stick x | Q/E |
| throttle (a RATE, so the lever latches) | right stick y | Shift |
| brake (pure: opposes travel, stops at zero, never reverses) | left trigger | Ctrl |
| next craft | left **upper** button | G |
| next KIND of craft | left **lower** button | H, or F1-F8 |
| next seat in this craft | either right-hand button | F |
| fire the gun this hand is holding | trigger | Space |
| the clipboard | menu button | M |
| take hold of something | grip, or tap the grip to latch | — |
| headset on/off | — | V |

### The trigger fires the gun the hand is holding, and the thumb depends on what that is

**A hand controller has more on it than a grip**, and in a cockpit every input on it wants
to mean something different depending on what the hand is holding. The trigger fires the
gun you have hold of. The same thumb button trims the aeroplane on a control column and
works the flaps on a throttle, because a hand on a column and a hand on a throttle are
doing two different jobs and the pilot knows which one they are holding.

**So the binding is a property of the CONTROL and not of the rig.** `VehicleControl.bindings`
returns a table from an input to an action, each control class answers for itself, and
`PilotRig` does no more than look it up and carry it out. That is the rule the command bus
already follows -- a new lever is a class, not another branch in the rig -- extended from
"what does moving it do" to "what do the rest of your fingers do while you are moving it".
The vocabulary is `objects/controls/bind.gd`.

**An empty hand is one more table, not a different mechanism.** The rows above are
`_global_bindings`, and a held control's entries are laid over them, so a control speaks
only for the fingers it has something to say about. A throttle says nothing about the
trigger, so a hand on the throttle goes on braking with it. Taking an input AWAY is
`Bind.nothing()` and has to be said out loud: a gun grip must do that to the brake, or a
gunner brakes every time they fire.

**Two inputs may never be bound, and that is what makes them reliable.** GRIP is always
take-hold-of-this, on every control in the game; a grip that meant something else on one
lever would be a lever you cannot pick up, and no way to discover that except by failing.
MENU is always the clipboard. A menu button that opened the menu only sometimes is a menu
button people press twice.

**An action says WHEN it acts**, which is the part that is easy to get wrong:

| kind | when | for |
|---|---|---|
| `Bind.frame(bit)` | every frame the input is down | firing, browsing craft and seats |
| `Bind.axis(name)` | every frame | the brake, the thumbsticks |
| `Bind.command(ch, v)` / `Bind.step(ch, d)` | once, on the press | flaps, gear, trim, ammunition |
| `Bind.local(what)` | once, on the press | the clipboard |

A bit on the frame is a LEVEL, for the reason everything else in this file gives: an input
frame is replayed during a rollback, so a "just pressed" worked out on this machine fires a
magazine per replay. The seat, use, kind, join, lock and launch bits are edge-detected on the
server; THE FIRE BIT IS NOT -- the server fires the gun again every reload while it is held.
See "A HELD TRIGGER IS A GUN FIRING".

**A step reads where the channel IS from the craft**, through `VehicleView.channel_value`,
and clamps to the range that craft is fitted with. So one binding serves every aeroplane:
the same button gives four notches of flap on an airliner and one on a gunship, and does
nothing at all on a helicopter, which has none. Nothing is remembered locally, because a
number this machine kept would part company with the copilot's the moment they touched it.

### Tap the grip to latch it

Squeeze and hold works as it always did and lets go when the hand relaxes. **A quick tap
latches**, and a second tap lets go. Holding a lever at 300 kph for four minutes is a hand
cramp rather than a skill.

The latch is the RIG's and not the control's. Every control already knows how to be held by
a grip strength and the tests drive them by handing one in; a latch pushed down into
`offer_hand` would be a second way to be held that every subclass and every test would have
to know about. It is one number -- `PilotRig._grip_of` -- and everything downstream goes on
believing a finger. A tap with an empty hand does nothing, or a closed fist would go past
every lever in the cockpit grabbing them.

### AND THE HAND IS TOLD WHEN IT WORKS

Twenty-five control classes, a game whose entire interaction is closing a hand around a
lever, and **zero `trigger_haptic_pulse` calls anywhere in the project**. A grab with no
pulse is a grab you are not sure of: the lever is visibly held, but the one sense that says
"you have got it" in every real cockpit was silent, and the player checked by looking --
which is the thing `fit` and `station_shot` exist to stop them having to do in the visual
domain.

**It is on the INTERFACE, not on the controller.** `XRController3D` has no
`trigger_haptic_pulse`; measured against 4.7.2's own `ClassDB`, the only one in the engine is

    XRInterface.trigger_haptic_pulse(action_name, tracker_name, frequency,
                                     amplitude, duration_sec, delay_sec)

so the node is where the TRACKER NAME comes from and the interface is what is called. The
`haptic` action has been in `openxr_action_map.tres` since the project started, bound to
`/user/hand/{left,right}/output/haptic` on all three profiles, and nothing had ever asked it
for anything. **Frequency is 0.0 on purpose** -- that is `XR_FREQUENCY_UNSPECIFIED`, and the
runtime picks what its own motor does best; a number would be this file guessing at hardware
it has never met.

**One call into the runtime and six named feelings.** `PilotRig.pulse` is the choke point
and `PilotRig.FEEL` is the table: grab 0.65 for 60 ms, release 0.50 for 45, a detent 0.65 for
35, a round 0.85 for 55, and the edge of reach: 0.70 for 200 ms coming in and 0.55 for 180
going out. Named rather than typed at each site, so they can be compared with each other --
letting go is quieter than taking hold, and a detent is the shortest.

**The first table was too small to feel.** Grab 0.45 for 35 ms (0.38 at the motor after
`HAPTIC_MASTER` 0.85), release 0.20 for 20, detent 0.60 for 28: a player who played with them
on 2026-09-13 felt nothing at all, and they were likely below what a Quest Touch motor
renders. Raised the same day on the user's "yes": grab 0.5525 at the motor for 60 ms, release
0.425 for 45, detent 0.5525 for 35 -- the detent kept the shortest so a dial still clicks
rather than hums. **A first go took the detent DOWN**, to 0.425, while raising everything else,
and was caught before it landed; the suite now holds it at the old 0.51 or more. The trigger was left for the per-round kick to decide. Whether any of it is
enough is a headset's answer; `tests/feel.gd` holds a grab at 0.5 or more at the motor, read
off what `pulse` sent (`PilotRig.last_pulse`), and every one lighter and shorter than `reach`.

**A control ANNOUNCES a bump; the rig has the motor.** `VehicleControl.bump` /`take_bump` is
the seam, and it is drained by the reading exactly as `Sim.cues` is: left set, a detent would
be felt again on every frame the hand stayed on the knob, which at the display rate is a knob
that vibrates rather than clicks. A control that reached for `PilotRig` to pulse would be a
control that cannot be built in the hall, on a bench, in the editor or in a test.

**IT COUNTS EVEN WHERE THERE IS NO MOTOR**, and that is the seam the suite stands on.
`pulse` increments first and returns early when `using_xr` is false, so `pulses(&"detent")`
is a thing a headless run can assert. Counting only when a headset is attached would leave
this testable on exactly the machine nobody tests on.

Three call sites today. The grab and the release come from `_work_the_controls`, which is the
one place in the game where a hand takes hold of anything. A detent comes from
`DetentDial._turn`, on the change of `at_stop` and not on the angle -- one click is one thing
that happens on the aircraft, and a wrist rolling within one detent's width says nothing.
And a stop is not left until a tenth of a stop past halfway (`DetentDial.DETENT_HOLD`), or a wrist
resting on the edge clicks at the display rate: see THE TIME OF DAY, "A dial on the panel".
The trigger comes from `GunTrigger.hand_input`, on the pull and not the release.

**And a free hand feels the edge of what it could take hold of** (asked for on 2026-09-13, and
asked again the same day by a player who had felt nothing in a headset -- the first design
was approved and never built). `PilotRig._notice_reach` sits in the same loop, straight after
`_nearest_to`, and is told that loop's answer: the way in is exactly `VehicleControl.REACH`
(0.16 m) to the grip, in flight and in the builder alike, because it is the grab's own
function. **A second radius was the rejected alternative** -- a buzz at a radius the grip does
not use is a promise the next squeeze breaks. **Edges, not state:** `reach` once when the
answer goes from nothing to a control, `unreach` once when it goes back, and sliding from one
lever straight onto an overlapping one is one `reach` for the new one. **A hand holding
something is told nothing** -- `grab` and `release` already said it, and what it holds is what
is remembered, so letting go on the lever is not a buzz on top of `release`, and moving off it
afterwards is one `unreach`. A hand the snap board has taken is not asked.

**The edge is the strongest thing a hand feels on a control, on purpose.** 0.70 × 0.85 = 0.595
at the motor for 200 ms coming in, 0.4675 for 180 ms going out, against a grab's 0.5525 for 60.
The first design had it a hint under the grab (0.25 for 20 ms) and what came back was "a
couple of hundred milliseconds, and I should be able to feel when I'm in a place where I could
grab": a grab is a thump the hand knows it is making, the edge is the thing a player is
feeling FOR. Only the trigger's 0.72 is harder, and it is a gun.

**Two things stop it being a rumble.** The way out is `PilotRig.REACH_MARGIN` (1 cm) wider
than the way in, and a neighbour must be that much nearer to take over: a tracked hand held
still wanders a few millimetres, and one radius both ways buzzes at the display rate for as
long as the hand rests on it. Behind that, `PilotRig.REACH_GAP` (0.25 s) allows one edge per
hand per gap, and an edge inside it is **deferred, not dropped** -- the hand keeps its old
answer until the gap is over, so a hand that really did leave is still told. The gap runs on
the rig's own frame time (`_reach_clock`), not `Time.get_ticks_msec` like `_grip_of`: under
`--fixed-fps` a suite's timer counts sixtieths however fast the frames really go, and a
wall-clock gap was still open after the suite had waited it out. A 200 ms buzz can overlap
the next; OpenXR says a new `xrApplyHapticFeedback` "must interrupt that other event and
replace it", so nothing queues. **That 1 cm is one place the buzz and the grab can disagree
about WHICH control**: in the band where a neighbour is nearer but not yet 1 cm nearer, the
last buzz named the first lever while a squeeze takes the strictly nearest one. Accepted
because both were buzzed on the way in, the band is a centimetre wide, and the squeeze has its
own `grab` pulse.

**The path to the motor, checked end to end on 2026-09-13**, because a player who feels no
buzz at all might be feeling no call at all. `haptic` is action type 4 in the `godot` set,
bound to `/user/hand/{left,right}/output/haptic` on `khr/generic_controller`,
`oculus/touch_controller` (what a Quest is offered, over SteamVR too) and
`bytedance/pico4_controller`; `ext/hand_interaction_ext` has no haptic output, rightly.
**There is no `valve/index_controller` or `htc/vive_controller` profile, so Index and Vive
controllers rely on SteamVR's remapping, which nobody has measured.** 4.7.2-stable's
`OpenXRInterface::trigger_haptic_pulse` finds the action by name, maps `left_hand` to
`/user/hand/left`, multiplies seconds by 1e9 and ignores `delay_sec` (a TODO in the source). A
missing action or tracker is an `ERR_FAIL_NULL` in the log, which is the first place to look if
a headset still feels nothing.

`tests/feel.gd` walks a hand in a centimetre at a time and measured the buzz on the first step
inside reach (0.155 m) and the leaving one on the first step past the margin (0.175 m),
trembles it 3 mm either side of both edges and between two selectors 8 cm apart, sweeps a held
hand past the other selector, and flicks a hand across both edges every two frames for 0.6 s
(36 flips, 2 pulses, ending one reach and one unreach). **Every edge is waited past the gap
before the next is looked for**, or a check after one edge tests the gap and not the margin.
RED with the seams in and no `_notice_reach` or new table: 15 checks failed; GREEN: 9 of 9
sections.

**One pulse per PULL and not one per ROUND**, and that is honest rather than convenient.
What comes out of the barrel is the server's decision, and `ShotState` is a birth record that
does not say who fired it -- so this machine cannot tell its own cannon's thirty rounds a
second from a gunship's four kilometres away. A round-by-round kick wants one field on the
wire.

**And two seams shipped with it that every grab test in this project was missing.**
`force_grip(hand, strength)` closes a hand with no hand and `force_hand(hand, pose)` puts one
somewhere. Without them the only way to exercise a grab headless is to call
`VehicleControl.offer_hand`, which is the layer BELOW everything that decides anything -- the
latch, the nearest-control choice, the one-hand-one-control rule and now the pulse. Both were
needed because something else is always writing those: `read_controls` zeroes both grips
every physics frame and only fills them when `using_xr`, and `_place_desktop_rig` welds both
hands in front of the instrument panel. A test that simply wrote `grip_left` or
`left_hand.global_transform` had it taken away before `_process` could read it, which looks
exactly like a grab that did not work.

`tests/feel.gd` is the suite. It found one thing by failing: opening the hand quickly is a
LATCH and not a release -- `_grip_of`'s whole job -- so the release check needed a second tap.

**Two traps in every test that holds something, and both were walked into again on 2026-09-13** by the controller
labels' checks in `tests/missiles.gd`, with that sentence above already written:

- **A forced grip shorter than `PilotRig.TAP_SECONDS` (0.35 s) is a TAP, and a tap LATCHES.** `force_grip(hand, 1.0)`,
  six frames, `force_grip(hand, 0.0)` leaves the control held; a second tap is what lets go. **The tap is timed on the
  WALL clock** (`_grip_of` reads `Time.get_ticks_msec`), and a suite at `--fixed-fps 120` runs frames far faster than
  real time, so counting frames does not help: any grip opened a few frames later is a tap. Hold it for `TAP_SECONDS`
  of wall clock to make it a squeeze -- `tests/shared_controls.gd`'s `_let_go` does -- or take hold with a tap and let
  go with a second one, as `tests/missiles.gd` does. The stick stayed latched
  in the right hand after every "let go", so "letting go takes the labels away" failed, the next section's beam press
  happened with the stick still held, and the next grab's tap UNlatched it. A "let go" that is not checked is not one:
  `tests/missiles.gd`'s `_take_hold_of_the_stick` and `_let_go_of_the_stick` take hold with a tap and let go with a
  second one, and check. (No committed check had been passing because of the latch: with the release made real, every
  one of them still passed.)
- **A forced hand is a POSE IN THE WORLD, and a moving craft leaves it behind.** An aeroplane at 64 m/s is half a metre
  further on every tick at 120 Hz. A hand put on the stick once and held there for six frames is off the stick; a beam
  aimed at the clipboard once is a metre behind the glass by the time the trigger is pulled; and the first windowed
  screenshots of a hand on the stick were taken from 8 to 18 m away. Put the hand back -- and work out any aim again --
  every frame the test holds it. `tests/clipboard.gd` never saw this, because its rig stands still.

### The controller in your hand shows what your fingers are doing

Asked for on 2026-09-13: "pressing a button on the controller should have a visible change in the state of the
controller". **Every part a finger works moves and turns amber**: the trigger swings back 24 degrees about a hinge at the
top of its blade, the grip button goes 3 mm into the handle, a thumb button goes down 2.5 mm, the thumbstick leans up to
22 degrees the way it is pushed and sinks 3 mm when clicked. Rest is `BoardStyle.DIM` and worked is `BoardStyle.AMBER`,
so the controller and the clipboard are one set; the trigger blends between them with the pull. The numbers are named
constants at the top of `objects/hands/controller_model.gd`.

**The model draws and the rig reads.** `PilotRig._show_the_fingers`, every render frame, hands
`ControllerModel.show_input` the five readings through `_read_input` -- the read the bindings act on, a forced finger
included -- for every input whether bound or not, and the grip as `read_controls` left it, latch and all. The model
reaches for nothing: the grip's "closed" is `VehicleControl.GRAB_ON`, handed in by the rig when it fits the model. **The
stick gets no dead zone of its own**: `_stick` has already taken `DEADZONE` out and rescaled, so a second one in the
model would have been a stick that leant late.

**Written only on change**, because it is called every frame and a hand at rest is most frames. Analogue readings are
drawn when they move by more than `EASE` (2% of travel) or land on either end, so a released trigger is exactly at rest;
buttons when they flip. `ControllerModel.writes` counts every transform and material write. Measured in `tests/hands.gd`:
**0 writes in 60 idle frames against 26 while every finger was worked once**; with the gate removed, **180 in 60 idle
frames** (a trigger transform, its colour and the grip, every frame) and all four idle checks red. The glow is emission
switched on at build and black at rest, so a press changes a uniform and never compiles a shader variant.

**The parts are mirrored for the left hand and the stick's axes are not**: pushed right, both sticks lean to the
controller's +X. `tests/hands.gd` checks it on both hands, with nothing held and with the right hand latched on the
stick, entirely through `force_input` and `force_grip`. It is its own suite rather than a section of `tests/missiles.gd`
because pushing the stick of a held stick winds the aeroplane's trim, which the missile sections fly on. With
`show_input` returning at once it went RED on 35 checks, every movement, colour and idle check on both hands.
`tests/controller_shot.tscn` is the windowed look: both hands in front of the desk camera, every pose, held and turned
side-on, into `user://controller_shots/`.

**From the eye, with the controller held top face up, the trigger cannot be seen**: the head is between it and the eye,
on this model as on the real thing. The first pictures (2026-09-13) showed the thumb buttons and the stick cap turning
amber from the pilot's eye, and the trigger and grip button only side-on. The grip button's face was then moved past
the edge of the head, and from the eye it now shows amber beside it. Moving the trigger's blade a centimetre further
forward did not help; to be seen from above in that pose it would have to stand about 20 mm proud of the head, which
is not a controller any more. Turned a little, or looked at from the side, it swings and glows.

**The double-precision editor could not draw a window on this Windows machine either, on the Mobile renderer.**
`controller_shot` on it printed "Error compiling Vertex shader" and hung after its first frame until a 300 s deadline
killed it; the stock editor, which loads `ashiato_gd.dll` rather than the double one, drew all sixteen frames in 11 s with
no error. Since 2026-09-14 the game is on Forward+, where the double editor draws, and draws right once no shader reads
`CAMERA_POSITION_WORLD` -- see "And one thing about looking at it on this machine". Look with the double editor.

### Two controls, because they answer different questions

Every craft has **four seats**, and the two buttons split the two questions cleanly: the
left pair chooses the CRAFT, the right pair chooses the SEAT. Neither does any part of the
other's job. The version before this had one button that searched neighbouring vehicles for
a free seat within four metres, so it changed seat or changed aircraft depending on what
happened to be parked nearby.

**Next seat** walks forward through the seats of the vehicle you are already in, wrapping,
skipping the taken ones. The HUD says which seat you are in and what its stick is wired to.

**Next craft** ignores distance and cycles through every vehicle with a FREE SEAT -- not
every vehicle standing EMPTY, and that difference is the whole of multi-crew flight. It
takes the pilot's seat when it is free and the next station along when it is not, so a
second player presses it until they reach their friend's aeroplane and arrives aboard while
the first goes on flying. It exists because a reach-based control is not
enough:
the aeroplanes start a hundred metres away doing 58 m/s, so nobody could ever reach one,
and a player who spawned in the pod stayed in the pod. The pod is a `HOVER` model. It flies
like a spaceship because it IS one -- which is a hard thing to work out if you cannot get
out of it.

**Taking a parked aeroplane launches it.** Same heading, wings level, at flying speed, well
clear of the ground. An aeroplane cannot fly out of a standstill -- it stalls before it
accelerates -- and the spare aircraft, flown by nobody, glide down and stop within a minute
of the world starting. Without the launch this control hands you a wreck. Flying speed is
derived from the wing (`weight = camber * v^2 * lift`) rather than typed in, so retuning
the wing retunes it too.

## WHERE THINGS LIVE

```
objects/controls/   the things a hand takes hold of
objects/seats/      one crew position: its station scene, structure and instruments
objects/vehicles/   the craft, which HAS a number of seats
```

That is the whole hierarchy and it is the one the game already had in its head: a control
belongs to a seat, and a vehicle is a hull with several seats in it. They were in one folder
called `objects`, with the seat scenes in a subfolder called `cockpits` and the word
"station" used for a thing everybody says "seat" about.

### One table per craft, instead of six places

`VehicleCatalogue` is everything the game knows about a craft that is NOT physics: its seat
scene, how its body is drawn, what colour it is, whether its crew share a throttle.

The migration boundary beside it is `craft/<kind>/1/`: an immutable checked-in manifest
and one station JSON document per native seat. `AuthoredCraftPackages` validates identity,
the canonical native simulation-contract hash, station hashes and allowed device names.
Runtime station creation reads those documents through `AuthoredCraftPackages`, with the
legacy scene used only after the complete package is refused. `tests/stations.gd` fits all
81 source seats and holds both their JSON census and directly reconstructed runtime station
equal to revision 1. Regenerate that baseline only with
`tools/generate_authored_packages.tscn` on the production double editor.

An optional `visual` object in `craft.json` is the stable imported-model boundary. It names
a `PackedScene`/GLB, requires metre units, `-Z` forward and `+Y` up, declares
`dimensions_m`, offset/rotation and named craft-local sockets. `ModelAssetDefinition`
validates all of it and rejects a scene whose mesh bounds differ by more than two percent.
`VehicleView` builds the native procedural body first and replaces only that visible body
after validation; collision, native extents and seat anchors cannot come from the asset.
The builder's `ModelInspector` draws dimensions, origin axes, native collider, station eyes
and sockets, with separate exterior/interior/overlay switches.

Those four things lived in four different places -- a dictionary, a `match`, a chain of
`if kind ==` inside the model builder, and a fourth constant again -- so adding a craft meant
finding all of them and remembering all of them. A kind now gets an entry, and a kind
WITHOUT one gets the light aeroplane's, which is a working craft rather than an error.

**The body branches ask what SHAPE it is, not what KIND it is.** A tiltrotor and an
aeroplane both have a wing; a Chinook and a light helicopter both have rotors and only one of
them has two. So a craft drawn like an existing one adds no code to the model builder at all.

**What is NOT in the catalogue is anything the simulation already knows.** Hull size, seat
positions, span, mass, fitted bus channels -- all read from `kind_geometry` and
`craft_schema` at runtime, because a constant here and a matching constant in the C++ agree
until one of them changes, and then the thing you can see is a different size from the thing
you collide with.

## WHERE THE GAME STARTS

`world/boot.tscn` is the main scene, and the only thing it does is decide which level runs.

```powershell
Godot --path cockpit                                        # the desk, to choose a session
Godot --path cockpit -- --level=menu                        # the desk, said out loud
Godot --path cockpit -- --level=world                       # straight into the world
Godot --path cockpit -- --level=watch                       # the world with NOBODY in it
Godot --path cockpit -- --level=server --world=island       # the world SERVED and not played: no rig, no camera
Godot --path cockpit -- --level=seat --kind=cessna --seat=1 # one cockpit, physics on
Godot --path cockpit -- --level=crew --kind=tower           # every seat, no physics
Godot --path cockpit -- --level=build --kind=cessna         # one cockpit, the builder on, SAVE writes JSON
Godot --path cockpit -- --host=47970                        # host over ENet on that port, then the world
Godot --path cockpit -- --join=127.0.0.1:47970              # join over ENet, then the world
Godot --path cockpit -- --steam-host                        # host over Steam, print STEAM_CODE=, then the world
Godot --path cockpit -- --steam-join=K7M-Q2X                # join a Steam game by its code, then the world
Godot --path cockpit -- --host=47970 --world=alpine         # host a level; a joiner is told which (see LEVELS)
```

**A session on the command line comes before any door**, read by `LaunchOrder` (`net/launch_order.gd`), a pure parser
that owns `--host`, `--join`, `--steam` and `--port` and nothing else. It also reads `+connect_lobby ID`, which Steam
passes when an accepted invite starts the game. A spelling in that namespace that is not one of the above is a typo, and
a typo is what boots a harness into a lone solo game it waits on for ever. So the router prints `BOOT_ERROR=` with the
words and quits, and a bad code is refused in `JoinCode`'s words. Otherwise it starts the session, waits on `Net` (a Steam
session on its own stage deadlines, an ENet join on `DeskRoom.JOIN_TIMEOUT`), prints `SESSION=enet host` or the like
(and `STEAM_CODE=` for a Steam host), and goes to the world. Measured on 2026-09-14: a headless `--host=47990` printed
`SESSION=enet host` and flew until its `--quit-after`, and `--host_port=1` printed its `BOOT_ERROR=` and exited 1.
`tests/launch_order.gd` holds every spelling: nine taken, twelve refused with their exact words, and other people's flags
left alone. Against a stub that took nothing it failed 20 of its 22 checks.

**Every door is a row in a table, not an arm of a `match`.** `BootRouter.DOORS` and
`MarshallingLevel.DOORS` are the only two places a level name is written down, and they are
tables so that `tests/docs.gd` can ASK whether a `--level=` word in this file is one the
router answers to. A list nothing can read is a list that test would have to copy, and a copy
is what lets the two disagree. The desk is both the default and a word -- `--level=menu` --
because a level you can only reach by leaving a flag off is a level the docs test cannot see.

**`--level=watch` is the world with no player at all**: no rig, no seat, no XR, no hands,
just a camera that flies. N and P walk the world's vehicles in entity order, K narrows to
one KIND -- which with a hundred and sixty machines is the difference between finding the
one you want and pressing a key until it turns up -- F lets the camera go free, and
`--fire=N` has whatever it is watching fire its gun every N seconds. It runs headless with
`--quit-after` as well, which is what makes anything the AI does testable at all.

**`--level=server` is the world served and not played**: everything `watch` leaves out, and the camera as well.
No rig, no seat, no XR, no hands, no `Observer` -- a 2D console on a `CanvasLayer` instead, and with `--headless` the
same facts as a `SERVER_CONSOLE` line once a second. `cockpit\server.bat` and `tools/server.ps1` are the entry point,
`-Headless` is the switch between the user's two halves ("in 2d ... or headless"), and `--xr-mode off` is part of it
rather than tidiness: a headless host on a machine with a headset runtime attaches to it anyway. What that saves is
22.3 MB and 4.7 s of CPU against `--level=world`, five per cent of the memory -- the table, and where the other
ninety-five per cent went, are in `docs/crew.md`, "THE WORLD SERVED AND NOT PLAYED".

**A shareable craft reel uses the small fly bench, not the island.**
`tools/create_video_demo.ps1 -Kind cessna` spawns exactly one real AI-flown craft at the
bench's 520 m recovery height, adds a quiet 16 km visual landscape for parallax, and uses
the game's real procedural sky, LiftYard cumulus and ContrailYard wingtip trails. Godot's
deterministic MovieWriter makes a slow 24-second orbit and flyby AVI plus one PNG
from each shot. The orbit aims at the cabin (or the drawn centre for an uncrewed craft),
stands far enough off to keep the whole airframe in context, and receives most of the reel.
`-Shots orbit,flyby`, `-Seconds`, `-Finish` and `-Time` are the useful criteria. AVI needs no
external tool; an `.mp4` output requires `-Ffmpeg` or `ffmpeg` on PATH. The scene owns the
final `quit()` because an interrupted MovieWriter file is not finalized. Generated media
lives under ignored `videos/` by default.

**A PARKED CRAFT STANDS INSIDE A PEN, AND THE PEN IS A WALL TWO CENTIMETRES OFF IT.** `--parked=1` puts the craft on
the stage's floor with no autopilot, and `bench.gd` builds a pen round it so a gun reel's rounds do not fly off into
nothing. It is collision. **An aeroplane asked to roll under its own power drives straight into it**, and the reel
looks like a craft that will not move rather than a craft that is being stopped. `-NoPen` lifts it (as `-Fire` and
`-Launch` already did), and a six-field `-StickScript` -- `roll:pitch:pedals:throttle:brake`, four fields still being
the stick alone -- is what lets a script taxi and brake at all.

**AND THE STAGE'S GROUND IS A FLAT GREEN PLANE WITH NOTHING ON IT.** That is right for the job it was built for -- a
craft in the air, where the landscape is parallax 16 km away -- and **useless for anything that moves along the
ground**: a Cessna taxiing across it is pixel for pixel a Cessna standing still, with no mark, texture or edge to
read motion or yaw against (lane/flightcore, 2026-09-19, while preparing the tricycles' before-and-after). **A
ground-handling reel goes to a real airfield's apron and taxiway**, where there is something to see it against, and
draws the path if it can. A picture that proves nothing is worse than no picture, because somebody files it as
evidence.

`tools/create_all_video_demos.ps1` makes the whole flying catalogue. It asks the running
simulation for every drawn `airplane`, `helicopter` and `tiltrotor` kind, then invokes the
single-craft path once per kind and writes browser-ready H.264/AAC MP4s into one timestamped
directory. `-ListOnly` shows the live set without rendering; `-Kinds cessna,fighter` selects
a subset. One failed craft does not discard or prevent the remaining renders, and the final
summary names every pass and failure. On Windows the single-craft wrapper also discovers a
WinGet Gyan.FFmpeg installation when the current shell's PATH has not refreshed yet.

Everything else in this game puts a player in a seat, which is right for a game about
flying things and wrong for the other job a game has: looking at itself.

A router rather than four main scenes, because the alternative is remembering which `.tscn`
is which and because a level should not have to know it might have been launched directly.
Each of them still runs on its own if you open it in the editor.

`--level` and `--mode` are the same flag to the bench. Asking for the same thing twice on
one command line is how you get them disagreeing.

### The main menu is a room

You are sitting at a desk and the menu is on the desk, tilted up. A flat menu pasted over
both eyes is the one thing a headset does worse than a monitor, and sitting somewhere and
reaching for something is what the rest of the game is.

The rig SITS IN the chair -- the same `sit_in` an aeroplane's seat uses -- so every bit of
the head and hand handling on the desk is the code that runs in a cockpit.

`SessionMenu` ANNOUNCES rather than acts: pressing a button emits `chose`, and whoever put
the menu up decides what it means. The desk starts a session and loads the world; the same
menu pulled up mid-flight would mean something else. A menu that called `Net.host()` itself
could only ever be used in one place.

**The desk's screens are pointed at with the board's beam, and the clipboard up does not hide them (2026-09-14).**
"Make sure the monitor screens on the opening main menu level allow for pointing and clicking like the ipad." The right
hand's beam already reached both screens, but `PilotRig._point_a_hand` aimed a board ALONE while one was up, so with the
clipboard out the monitors could not be pointed at, and each board kept its own copy of the press-once state. The beam
is its own object now, `HandBeam` (`player/hand_beam.gd`). The rig still chooses which hand points and hands it every
glass that is up: the clipboard, the snap board, and the panels the level gave it (`pointer_panels`). The beam asks each
where its ray crosses (`TouchPanel.reach`), aims the FIRST along the ray and nothing else, and draws itself to there.
Nearest along the ray, not nearest the hand: with the hand 8 cm off the left monitor, aimed along its glass, and the
board 40 cm down the ray, the board takes the pull.

**One pull is one press, kept on the beam and not per glass.** A trigger already held when the beam arrives presses
nothing, and that has to hold when it arrives from ANOTHER glass, which two boards each keeping an edge could not know.
While the beam is on any glass, the clipboard's "press what is highlighted" is held off (`Clipboard.beam_on_glass`).
Otherwise one pull on a monitor with the board up pressed the monitor AND the board's highlighted craft.

**A button goes out when the beam leaves it.** A panel is only ever told where a pointer IS, so a beam that swung off the
pane sent nothing, and the door it left stayed lit. `TouchPanel.leave` sends one motion to (-1, -1). Read in Godot 4.7's
viewport.cpp, and measured with a probe on the level page: `push_input` runs `_update_mouse_over` for every mouse event
on a SubViewport with no container, so a pushed motion lights the door, the motion at (-1, -1) puts it out, and the
next motion lights it again. `notify_mouse_exited` also put it out, but it clears a `mouse_in_viewport` nothing here set,
and Godot warns when it is told twice.

`tests/desk_screens.gd` is the suite, and it took over the beam section `tests/session.gd` had. On 7fc1af3, before this,
three of its sixteen checks failed:
- the door stayed lit off the glass;
- with the clipboard to one side, the monitor got nothing and the beam stayed 0.6 m;
- the pull pressed the board's highlighted craft instead.

Rejected:
- A second pointer in `desk.gd`: a second ray sum and a second press state.
- Hiding the beam off the glass: a pointer that vanishes cannot find the page again, and the 0.6 m stub was already
  tested.
- No beam from a hand holding a control: no level hands panels to such a hand, and the snap board points from a hand
  that may carry a lever, on purpose.

The fingertip still presses every screen as before.

**And on a monitor the mouse clicks them (2026-09-14).** Without a headset nothing on the desk could be clicked: the rig
offered the mouse to the clipboard alone, and the monitors took only a headset hand's beam. It was found while building
the join code's keypad, which a desk types into. The choice of glass and the one-press-per-pull rule moved out of
`HandBeam` into `GlassPointer` (`player/glass_pointer.gd`), and the beam and the desk mouse each keep one. On a desk,
`PilotRig._point_the_mouse` hands the ray from the eye through the cursor every glass that is up: the clipboard, the
snap board, and the panels the level handed over. It releases the cursor while there is any, and captures it when there
is none. `tests/desk_screens.gd` clicks with real mouse events in window coordinates: the button's centre, through the
desk camera's `unproject_position`, through the viewport's final transform. Before the change both of its clicks pressed
nothing. With press-once taken out of `GlassPointer`, ten of its checks went red and every pull pressed twice.

**A way out of the program, pressed twice (2026-09-14).** "Make sure that we have a quit button on the main menu to
actually quit out of the game." Quit sits at the foot of the session screen: the WHO screen, not WHERE TO, whose every
button is a door somewhere. It is a `GuardedButton` (`ui/menus/guarded_button.gd`). The first press arms it and it reads
PRESS AGAIN TO QUIT, a second press inside `GuardedButton.MEANT_IT` (4 s, on the frame clock) quits, and leaving it
alone puts it back. That guard was the clipboard's MAIN MENU, kept as the page's own members and functions, and it is
now both buttons: one countdown, not two to keep in step. `ClipboardPage.MEANT_IT` stays, asked of the guard, so MAIN
MENU looks and behaves as it did and `tests/clipboard.gd` is unchanged.

`SessionMenu` announces `chose("quit")` and the desk decides. `DeskRoom._quit` calls `Net.leave("quit")` if a session is
up or a join is still knocking; that is the path every leave takes, closing the peer and stopping `Sim` on
`session_ended`. Then it calls `quit_the_game`, which is `get_tree().quit(0)` unless a test has swapped it for a counter.

**No XR teardown before the quit, on purpose.** Read in Godot 4.7's modules/openxr: `OpenXRInterface.uninitialize` does
not end the session (its own comment says the driver cleans itself up when Godot exits), and engine exit runs
`uninitialize_openxr_module`, then `OpenXRAPI::finish`, `destroy_session` and `xrEndSession`. An `uninitialize()` first
would add a few frames with no trackers and nothing else. NOT measured in a headset: there is none on this machine.

The last section of `tests/desk_screens.gd` hosts a session and presses Quit with the beam. One pull only arms it, left
alone it disarms, and two pulls quit exactly once and end the session. Written to parse before the button existed, it
failed on c7a2e4e exactly the two checks that ask whether there is anything to press.

**Armed is amber in every state a Button is drawn in, not only its plain one.** Found by looking, not by a suite. A
hovered Button draws its words in `font_hover_color`, and a beam always hovers what it points at. With only
`font_color` overridden, PRESS AGAIN TO QUIT came out in the theme's white (0.95, 0.95, 0.95) exactly while it was
aimed at, and the clipboard's MAIN MENU had the same gap. `GuardedButton` now paints the hover, pressed, hover-pressed
and focus colours too while armed, and takes them off again when it disarms. The check asks for the colour the button
would draw in hovered, not whether Godot has marked it hovered on that frame: straight after a press it reported not
hovered, one pointer move before it was again. A screenshot of a button pointed at needs the hand held to one side,
too; straight out along the glass's normal, the controller covered the words.

**Host over Steam makes a lobby with a join code on it**, and waits on `Net` rather than on the desk's clock: every
stage of a Steam session has its own deadline and its own sentence. A refused host stays at the desk with the reason on
the session screen: "Steam is not running. Start Steam and try again." with no Steam client, and "Steam is not in this
build." where the addon failed to load. See "A JOIN CODE, AND STEAM".

### AND THE WORLD HONOURS THE SESSION THE MENU STARTED

`world/sky.gd` called `Net.play_solo()` unconditionally in `_ready`, with a comment saying
nothing had asked for a session yet. A real menu asks now -- the desk calls `Net.host()` or
`Net.join()` and then changes scene -- and **`play_solo` BEGINS by closing whatever peer is
installed**. So pressing "Host a game" created the ENet server on port 7788, loaded the
world, and destroyed the listening socket one frame later with `transport` back to `"solo"`.

Nothing errored and nothing warned, which is the worst shape a failure can have: `Sim.start`
saw an un-networked peer, stood up a local server, and the game played on quite happily in a
session nobody could reach. **Both networked paths out of the only menu in the game were
dead**, and the whole multi-crew thesis -- four seats, dual controls, `seat_client`, the CREW
tab, `join_wanted` on the input frame -- was unreachable by a human.

The fix is one `if`, and three things go with it.

**A session that already exists has already announced itself.** `session_ready` is emitted
inside `Net.host()`, before this scene is built, so waiting for it here would wait for ever.
`sky.gd` builds directly when `Net.is_in_session` and calls `play_solo` only when nothing
has asked -- which is `--level=world`, the editor and every bench, and is the half that must
not regress.

**A join has to be WAITED for and a host does not.** That split is `Net`'s contract rather
than a preference: `play_solo` and `host` are in a session by the time they return, and
`join` only opens a socket -- `is_in_session` stays false until `connected_to_server`
arrives, which is what `session_ready` is for. `DeskRoom` flew immediately on a `join` and
tore the handshake down mid-flight. It waits now, with `JOIN_TIMEOUT` of ten seconds,
because there is no signal that would end the wait: measured on 4.7.2 and written down in
`working_with_godot.md`, `create_client` against a dead port returns OK,
`get_connection_status()` sits at CONNECTION_CONNECTING and `connection_failed` never fires.

**And `host` is no longer unconditional either.** A port already in use makes `Net.host()`
say so and leave `is_in_session` false, and flying anyway put the player in a world they
believed was public and nobody could reach.

`tests/session.gd` is the suite, and the shape of it is the point. No cockpit suite had ever
called `Net.host()` or `Net.join()`: `trim`, `clipboard` and `bench` all call
`Net.play_solo()`, which is the function the bug was IN, and the real two-peer coverage
lives in `ashiato-gd` and exercises the C++ replication layer directly, far below the
desk-to-sky scene transition. So this one starts at a BUTTON -- the real `Button` inside the
real `SessionMenu` on the real desk -- lets the desk change scene, and then asks the world
it lands in what it believes. Restore the old line and it goes red on three checks.

**A suite that changes scene has to survive doing it.** `change_scene_to_file` frees
`current_scene`, so a suite that IS the current scene is deleted by the first thing it asks
the game to do. The scene's root does nothing but hang a second copy of its own script on
`/root`, which is a sibling of the current scene and outlives every swap.

**And an ENet handshake is three-way, so a client that stops polling never arrives.** The
loopback guest reported CONNECTION_CONNECTED one frame after `create_client` while
`multiplayer.get_peers()` on the host was still empty thirty frames later. The two ends
finish at different times: the client dispatches its connect event when the server's
VERIFY_CONNECT arrives, and the server dispatches its own only when the client's
acknowledgement of that gets back. Stop polling the client the instant it says CONNECTED --
which is the obvious thing to write -- and that acknowledgement is never sent.

**And a second PLAYER arrives: two processes, over a real socket.** Only two processes with two `Sim`s can say that, and
the boot flags are what start them. `tests/two_peers.gd` starts a headless host (`--host=PORT`) and a headless joiner
(`--join=127.0.0.1:PORT`), each with `--report=1`, which has the world print a `SESSION_REPORT` line five times a second.
It reads those lines from the children's `--log-file`s. `clients` counts the machines whose sync client this one can
name: itself, and each Godot peer `Sim.client_of_peer` maps. It passes only when BOTH machines name two clients and each
world draws two pilots; a socket connecting is not enough. Measured on 2026-09-14:
- Before cockpit-crewsync, on 527935b, the host went from `clients=1 pilots=1` to `clients=2 pilots=2` within 5.8 s. The
  joiner stayed at `clients=1`, because the host's id had been announced to an empty room. So it was checked for pilots
  only.
- After crewsync, on 55b0ddf, both machines reported `clients=2 pilots=2` within 3.0 s, and the joiner's clients check
  was added.
- Against a world that printed no report, both children reached `SESSION=enet` and every check about a player failed.
- Against the rebase while the report still read the deleted `Sim.clients`, neither child reported and every check
  failed at the 60 s deadline.
- **One run in three on a busy machine, from 2026-09-14 until cockpit-joinfix, the host reported `clients=2 pilots=1`
  for the whole 60 s** while the joiner said `clients=2 pilots=2`. It was never the socket and never crewsync. The
  server had the joiner seated; the host's copy of the joiner's craft said nobody was in it, so the host's pilot row
  named vehicle 0 and `_draw_vehicles` skipped it. ashiato-sync's send loop gave back a quantized frame it had never
  retained whenever a record did not fit the budget, freed a frame another client still held as its baseline, and the
  recycled index handed that client another craft's `Seats`. Idle it passed 10 of 10; under 32 busy cores it failed
  1 of 10 and then 0 of 20; terrain's lane, beside other lanes' gates, failed 3 of 3. It needs a crowd arriving at once,
  which is why load found it. `../ashiato-gd/addon/tests/crowd_join.gd` makes it happen on every run in 5 s, and the
  libraries from before crewsync lost the seat as often as main's did (14 and 13 of 48 join timings). The fix is
  `../ashiato-gd/tools/patches/ashiato-sync-retain-before-release.patch`; see `../ashiato-gd/LEARNINGS.md`.

It uses ports 47980-47989 and moves to the next when a host cannot listen. It kills both children by pid, and runs in
about 4 s.

**And a crew, apart and then together**: `tests/crew_peers.gd`, the same shape on 47990-47999, has the joiner board the
host's craft through its own CREW page. See "WHO SITS WHERE IS THE SERVER'S".

**Why log files and not a pipe.** Measured on 4.7.2: `OS.execute_with_pipe` reads a RUNNING child's stdout without
blocking, but once that child has exited, asking the pipe how much is waiting prints `ERROR: Condition
"!PeekNamedPipe(...)" is true`. The runner fails any suite that prints an ERROR line, and a child that quits on
`BOOT_ERROR=` races it. A child started with `--log-file` had each printed line in the file within 50 ms, with no error.

**And `PilotRig._process` read `Sim.client` without asking whether there was one.** Leaving
a session with a world still up -- which nothing had ever done before this -- printed
"Nonexistent function 'vehicle_state' in base 'Nil'" on every render frame. Rule 7 at the
top of this file says it plainly and the line did not.

## TESTING

```powershell
..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 120 res://tests/smoke.tscn
..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 120 --path ..\ashiato-gd\addon res://tests/cockpit_loopback.tscn
```

Or through the runner, which is what to do nearly all the time. A lane gates on its own suites, lint and docs,
in one command and several at a time (lane/gate, 2026-09-19). A broad change adds the tiers it touches, and
the whole list belongs to the sweeper on main (running_a_team_here.md, section 4):

```powershell
powershell -File tests\run_all.ps1 -Only lint,docs,apache,apache_flight   # a lane's gate
powershell -File tests\run_all.ps1 -Tier core,net -Only crew_join            # a lane that touched the wire or C++
powershell -File tests\run_all.ps1 -Tier core -List                          # what that would run
powershell -File tests\run_all.ps1                                           # everything: the sweeper, on main
```

`-Only` is a comma list, `-Jobs` is how many at once (a quarter of the threads, at most 8), and the tiers are
explained at the top of `tests/suites.txt`. `tests/run_all_test.ps1` is the runner's own test.

**REDIRECT A GATE TO A FILE; DO NOT PIPE IT THROUGH `tail`.** The runner blocks while another lane holds a
MEASUREMENT slot, printing `waiting: a GPU measurement slot is on (MEASUREMENT <lane> <time>)` — which is correct and
is the slot rule working. But `| tail -6`, `| Select-Object -Last 5` and any `grep` show nothing until the command
finishes, so **that line never surfaces and a waiting run reads as a hang with no output at all**. Two lanes hit it on
2026-09-19 and one lost forty minutes, killed the run and started a second on the same worktree before working it out.
Use `> gate.txt 2>&1` and read the tail of the file; and before killing a silent run, read `C:\gg-wt\GPU_SLOT_HOLD` —
if there is a line in it, the run is obeying it. See `../running_a_team_here.md`, section 8.

**Build all three modules or half the suite hangs.** `build.ps1 -WithCockpit` on its own
produces an extension without the driving and VR modules in it, and the four suites that
need them do not fail -- they sit there until the deadline kills them, exactly like a parse
error. Four suites timing out at once almost always means a partial build. Use
`-WithCockpit -WithDriving -WithVr`.

**`--fixed-fps` is not optional, it is the difference between twelve seconds and two
minutes.** Headless still paces its main loop to real time otherwise, so a test that waits
4400 physics frames for the formations to settle spends thirty-seven seconds of wall clock
doing about two seconds of work. With a fixed step the loop runs as fast as the machine will
go and every `await get_tree().physics_frame` costs what the frame actually costs.

It does NOT make timing measurements meaningful -- see the note in `_test_the_world` and
`hitch_probe`, which tick the worlds by hand for exactly that reason.

**And a fixed-fps frame count is not patience for another process** (2026-09-17). A child
Godot, an ENet socket, a log file and a real-time timer still advance on the wall clock while
the parent can run thousands of frames in a second. The multiplayer/child-process harnesses
were audited: `no_vr_flight`, `sky_peers` and the visible `level_change_shot` were the remaining
ones using frame-count deadlines for those boundaries, and now use monotonic
`Time.get_ticks_msec()` deadlines. Frame counts remain where the condition itself is simulated
frames: settling physics, holding a key, and observing a fixed number of input ticks.

**The hitch verdict was already the robust version the backlog asked for.** It times hand-driven
simulation ticks, judges the deterministic median against its measured bound, still prints the
p99/worst tail, and separately holds missed real tick budgets and the visible correction invariants.
It does not turn scheduler noise into a wider simulation allowance. Re-audited three consecutive
runs on 2026-09-17: all passed in 3.6--3.8 s; the last measured 0.082/0.080 ms medians at 60/120 Hz,
0 of 1,800 ticks over either budget, 0.405 ms for the full 75-vehicle server+client tick, and
0.100 ms for the predicting client.

### A SUITE THAT KEEPS A FORMULA BESIDE THE MODEL (lane/flightcore, 2026-09-19)

**A test that types its own copy of what the model should say passes until the model is replaced, and then it is the
only thing left that still believes the old one.** It is the tautology trap's twin: not "the test builds its input with
the code's own function", but "the test carries the code's old arithmetic in its pocket". The cure is the same shape as
the workshop's *one number, one place*: **ask the model what it should be**, and let the check hold the thing it is
actually about.

Three of these landed in one merge, 851314da, which put the Little Bird on its rotor disc, and each is worth reading as
a shape:

1. **`rotor_hold` held the lever to the model the kind used to fly.** Its subject is the BUS -- that the collective the
   physics reads is the lever on the wire and on a client's copy -- and it worked out what should carry the weight as
   `(1 - hover) / collective_range`, the weight-fraction thruster's arithmetic. The check flies its helicopters at
   cruise, and a disc makes 18 per cent more thrust at the same collective once it is fast enough for translational
   lift, so the Little Bird holds its height on **0.32 of the lever where the formula said 0.47**, and main was red.
   It now bisects `probe_rotor` at the speed and height the craft is holding, and falls back to the thruster's
   arithmetic for the four kinds that still fly one. The fix is three lines of asking; the four thruster kinds read
   0.47, 0.45, 0.44 and 0.50, exactly as before.
2. **`littlebird_book` restates the disc's own formulas and calls them a book.** `probe_rotor` is asked for a thrust
   at a chosen collective, and the answer is held to a number the formula was written to give:
   "the climb matches the 530F" asks only that thrust exceeds 0.95 of the weight while climbing at the book's 10.5 m/s,
   which **a disc that climbs at 53 m/s passes**. Nothing in it flies.
3. **`littlebird_flight` has a floor with no ceiling.** `best_vy >= 6.0` against a published 10.5, so the same disc
   logs **23.3 m/s and passes**.

**What to write instead**, in order of how much it buys:
- **ask the model** (`probe_rotor`, `lifting_surfaces`, `handling`) for what a number ought to be, at the state the
  craft is actually in, rather than keeping a copy of its arithmetic;
- **hold the published figure**, from the kind's own `sources.md`, with a BAND and BOTH ENDS -- a floor without a
  ceiling is half a check;
- **fly it through the real path** (`set_pilot_input`, the bus, the autopilot) rather than probing a formula;
- **and give every claim a mutant that runs inside the suite**, so a check that has stopped measuring says so.

The rest of that merge's debt is `../todo/flightcore--helicopter-review-steps.md`, and the rule's short form is in
`../testing_godot_headless.md` beside the tautology trap.

### EVERY KIND'S MOTION, BIT FOR BIT: `tests/flight_fingerprint.gd` (lane/flightcore, 2026-09-19)

**"Every other kind is unchanged" is a printed fact, not a claim.** The suite flies every pilotable kind in a world of its
own, on a fixed script through `set_pilot_input` (in the air, from a hover, afloat or on a slab), on its autopilot steered
to a point 3 km off at its cruise, and, for every wing, at full power down a runway. Each flight prints one line: the kind,
the flight, and an MD5 of the final position, attitude, velocity and spin as 64-bit floats. 32 kinds, 80 lines, about
7 s. It holds on its own that each flight flown twice gives the same bits (rollback needs that), that every state is
finite, and that a retune of one part in ten thousand (the light twin's thrust) moves the light twin's line.

**How a lane uses it.** A flight suite's thresholds can be slipped under (`littlebird_flight` passed a climb of 23.3 m/s
against a book of 10.5 because its floor was 6); a fingerprint cannot. Before a change that should leave some kinds
alone, write main's fingerprints and hold the lane's to them:

```powershell
# in the main checkout, on main's library
<godot> --headless --fixed-fps 120 --path cockpit res://tests/flight_fingerprint.tscn -- --write=C:/gg-wt/<lane>-temp/fp_main.txt
# in the lane, on the lane's library
<godot> --headless --fixed-fps 120 --path cockpit res://tests/flight_fingerprint.tscn -- --expect=C:/gg-wt/<lane>-temp/fp_main.txt
```

The second names every line that moved, and only those. The READY says which moved and why each was meant to. Measured
when it landed: `--set=clmax*1.01 --kind=cessna,plane,heli` moved exactly one of eight lines, the Cessna's autopilot
leg (the only one of the eight that flies near its stall; the light twin and the helicopter do not read `clmax`).
`--kind=` narrows both the flying and the comparison. The crash rule is off inside it, because a wreck is frozen and
would print its stillness rather than its flight.

### HOW WELL A KIND IS FLOWN, NOT WHETHER IT ARRIVED: `tests/vehicle_gym.gd` (lane/flightcore, 2026-09-19)

**Every flight suite here asks whether the aircraft arrived. None of them asked what the journey was like, and that is
what the user was complaining about** ("very jerky and oscillate", 2026-09-19). `traffic_pattern` will pass a circuit
flown with the stick sawing stop to stop, because a circuit flown badly is still a circuit.

The gym gives every kind that flies, hovers or floats the same tasks -- level off from an established climb, make a
speed gate, turn ninety degrees onto a bearing, fly to a place at a height and a speed, and for a helicopter hover to a
point and climb from the hover -- and scores each on **overshoot, settling time, steady error, control activity and
envelope honesty**. 28 kinds, 118 scored flights, **19.6 s**.

**EVERY TASK IS SIZED FROM AN ENVELOPE THE SUITE MEASURED FIRST**, and that is the difference between a gym and a gate.
Before the tasks, each kind is flown to its limits four times: everything it has toward a point it can never reach, into
a climb it cannot finish, with the throttle closed, and round onto a bearing square to its own. Asked instead for a flat
300 m in a minute, a Cessna scores nothing at all -- it never gets there, so there is no overshoot to read and no settle
to time, and the same flat zero comes back for a fighter that would have made it in eight seconds. Asked for a third of
the climb it was measured to hold, every kind is worked equally hard and the scores compare.

**TWO TRAPS PAID FOR IN THE FIRST HOUR** (the third, and the sharpest, has a section of its own below):

- **A LIMIT MEASURED OVER A TICK IS NOT A LIMIT.** Tick by tick, the light twin's deceleration came back as
  19.96 m/s^2 and the glider's as **2,567** -- two g and two hundred and sixty g. The first version scored the 747's
  speed gate as the pilot's fault, because an envelope built out of spikes said every demand was possible.
- **A LEVEL-OFF FLOWN FROM LEVEL FLIGHT IS NOT A LEVEL-OFF.** The first run scored every kind 0.000 for overshoot
  because none of them was climbing when the task started. The task now spawns the craft already going up at the rate it
  was measured to hold.

**WHAT IT FOUND ON ITS FIRST FULL RUN, and it is the opposite of what the lane expected:**

| What | The number |
|---|---|
| **Nobody overshoots.** Flown from an established climb, every kind scores 0.000 to 0.008 on the level-off, and raising the climb it is allowed changes nothing: the mixers ramp the climb down long before the height, and the airframe is the limit anyway. **The pilots here are SLOW, not twitchy.** | 0.000-0.008 |
| **Eight flights never get there, and seven are a speed gate.** The five jets end the minute 5.6 to 5.8 m/s high, the Hawkeye 3.6 and the tanker 2.0; the airliner ends a waypoint leg 1,442 m short of a 2,186 m run. This is the user's jumbo-that-cannot-slow-down, on seven aeroplanes. | 2.0-5.8 m/s short |
| **AND THE CAUSE IS THE LAST FIVE PER CENT OF THROTTLE.** The jets' throttle ranges 0.00 to 0.06 and is SHUT for only 7 to 12 per cent of the flight, and at 0.05 they still make enough thrust to hold their speed: they shed **0.043 m/s^2** where the same aeroplane with the throttle actually closed sheds **0.435**. `AircraftMixer::step` adds the speed loop to a **typed `throttle_trim = 0.45`, the same constant for every aeroplane in the game**, and the loop's whole integral authority is `ki x integral_limit` = 0.008 x 20 = **0.16 of throttle**. Given four minutes instead of one, the tanker is still 17.2 m/s high and its throttle has not moved at all: it plateaus, it does not converge slowly. **`throttle_trim` is the envelope's first customer** -- what holds cruise is the aeroplane's own number, not a constant. `../todo/flightcore--throttle-trim-is-typed-for-every-aeroplane.md`. | 0.043 against 0.435 |
| **The jets fly past a waypoint by more than half the distance they were sent**, ending 850 m beyond after the closest approach. That is the missing braking distance in one number. | overshoot 0.54 |
| **The heavies barely turn.** The airliner holds 0.022 rad/s and the 747 0.054, against the 0.168 its 0.9 rad of bank should buy at cruise -- **0.32 of it**, which is `../todo/airport--747-turns-at-0.28.md` arrived at a second way, from a different flight, by a different measurement. | 0.32 of the bank's rate |
| **The glider sheds nothing at idle and climbs nothing**, and measured tick by tick it lost 51 m/s in a second: `../todo/gliderlevel--the-gliders-polar-is-backwards.md`. It flies only the turn here, so nothing is sized from it. | 0.00, and 51 m/s^2 a tick |
| **Five jets share one set of numbers to three decimals** -- top 214-216 m/s, climb 7.27, turn 0.067-0.075. The fighter, the Tomcat, the Falcon, the Prowler and the Lightning are one placeholder wearing five airframes. | identical |

**THE SCORES ARE HELD AGAINST `tests/vehicle_gym_baseline.txt`**, read by default on a full run, within a quarter of
each recorded value and a floor of 0.5. So a change that flies a kind worse fails -- and one that flies it BETTER fails
too, until somebody records the better number on purpose. That is deliberate: a scoreboard nobody has to update is a
scoreboard nobody reads. It is **not in the `core` tier** for the same reason: the bill for re-recording belongs to the
lane that changed a flight model, in its own gate, not to everybody's.

**NOT ARRIVING IS PRINTED AND HELD, NOT FAILED.** The eight flights above are real faults and they are shouted in a
block of their own (`DID NOT GET THERE AT ALL, 8 of them:`) with the start, end and closest numbers on each line; the
suite still goes green, because the baseline is what stops them getting worse and a suite left red on main stops other
lanes' gates for a fault none of them caused.

**WHAT IT CANNOT SEE YET: the stick.** An AI vehicle has no cabin, so `crew_controls` is empty for it, and
`craft_controls` carries the throttle but not the pitch, roll and rudder the mixer has just written. Throttle activity is
therefore read directly and the stick's work is read through **what it did** -- the reversals of the body rates it
commanded, counted with a 0.02 rad/s deadband so that noise about zero is not a hundred reversals a tick. A four-line
readback of the autopilot's last `ControlInput` would make it direct, and belongs with the envelope's C++ turn.

**AND THE MUTANTS, because a scoreboard that cannot move is not measuring.** Both run inside the suite:

- **Four times the demanded pitch rate** (`pitch_rate` x 4, which the control law multiplies the stick by) and the
  Cessna hunts: **2.0 reversals a minute become 406.0**. On the light twin, four times the demanded ROLL rate gives
  4,801.
- **A twentieth of the fin** (`weathervane` x 0.05) and the light twin will not hold a heading: its turn settles in
  **54.5 s instead of 23.9** and leaves 0.0915 rad of standing error against 0.0018.

### A DEADBAND KEEPS THE INTERESTING NOISE OUT TOO, AND A ZERO HAS TO BE PROVED ALIVE

Both rules are in `../testing_godot_headless.md` ("Thresholds"), with these measurements. What
they left behind here:

- **The gym's two reversal columns are a pair, and the coarse one cannot see taxi chatter.**
  `reversals_per_min` counts a sign change in a body rate past a **0.02 rad/s** deadband;
  lane/tracelog measured a taxiing Cessna's pitch rate crossing zero **fourteen times a second at
  0.01 to 0.02 rad/s**, every crossing inside that band, so it read 6.0 and could not have read
  anything else. `chatter_per_s` is the same count with a band a hundred times finer. Keep both.
- **And what the proved-alive zero then found.** `chatter_per_s` reads 0.0 for every aeroplane in
  the fleet on a slab taxi, and 6.8 a second against the `pitch_rate × 4` mutant, which is the
  406 a minute the coarse count reads on the same flight. So the zero is a finding: **today's
  tricycle, with its forces at the mass centre, does not chatter on flat ground** — which points
  lane/tracelog's fourteen a second at the test field's generated ground rather than at the wheel
  model.

### A LIMIT MEASURED AT ITS BEST MOMENT IS NOT A LIMIT

The rule and the fighter's three numbers are in `../testing_godot_headless.md` ("Assert the
envelope"). What it governs here: **the gym sizes every task from the envelope it has just
measured**, so peaks in the envelope are reported as pilot error. With them in, the 747's speed
gate looked easy, the aeroplane missed it, and the scoreboard blamed the control loop — **the
honesty score only tells `refused` from `FAILED` if the envelope is honest first.**
`world/braking_curve.gd` plans on three quarters of what it measured, and its mutant shows what
the other quarter buys: against a craft a fifth worse than assumed, three quarters arrives on the
number and the whole of it arrives 18.0 m/s fast.
### WHEN TO BEGIN SLOWING: `world/braking_curve.gd` (lane/flightcore, 2026-09-19)

**Every leg an autopilot is given here hands it a new speed at the moment the phase changes** -- `p.downwind_speed`,
then `p.final_speed` -- and a step into a proportional loop is a kick. Worse, the step arrives where the aeroplane
already is rather than where it could still have slowed down from, so the gym measured the jets flying **past** a
waypoint by more than half the distance they were sent.

**The workshop already owned the answer, in a train.** `../previous_projects/august-15-train/scripts/auto_driver.gd`:
*"the outer loop is a braking curve, `v = sqrt(2 a d)`: the speed from which the train could still stop on the marker at
a comfortable rate."* Three things it does matter as much as the formula: it plans on **less** deceleration than it
has, it aims a little **short** of the marker, and it evaluates the curve **every tick against the range now**, so the
setpoint slides instead of stepping. `../pid-control/docs/STRATEGY.md` names that file as the example it never ported.

`BrakingCurve` is that, as four static functions and no state: `speed_for(range, arrive, decel, cruise)`,
`begins_at(speed, arrive, decel)`, `turn_room(speed, bank)` and `level_off_lead(climb, vertical)`. It holds **no limits
of its own** -- the deceleration, the bank and the climb are the craft's, measured or asked of the model.

**WHAT IT IS WORTH, measured by the gym on sixteen aeroplanes.** `arrive_at_speed` and `arrive_planned` are the same
flight -- be at a place, at a speed -- flown by two hosts: one asks for the arrival speed once the point is inside
`kArrived` (a flat **220 m** for a Cessna and a 747 alike), which is what every host here does today; the other steers
the curve on the range now, re-steered every `AirportTraffic.THINK_TICKS`.

| kind | speed error on arrival, waiting | planning | flew past, waiting | planning |
|---|---|---|---|---|
| Cessna | 14.19 m/s | **0.41** | 0.018 | 0.095 |
| light twin | 3.89 | **1.67** | 0.320 | 0.277 |
| Savoia | 15.75 | **5.00** | 0.369 | **0.144** |
| fighter | 34.97 | **11.36** | 0.573 | **0.209** |
| airliner | 26.83 | **12.66** | 0.526 | **0.179** |
| 747 | 31.54 | **20.72** | 0.533 | **0.312** |
| Warthog | 39.95 | **23.84** | 0.531 | **0.281** |

**267.1 m/s of arrival error saved across sixteen kinds, and not one kind made worse** -- which the gym holds as a
check, so the curve has to keep earning its place.

**And it is quieter as well as nearer**, which was not the thing being aimed at: the fighter's reversals a minute fall
from **36 to 9** and its throttle movement from 0.0218 to 0.0017. A setpoint that slides does not kick a proportional
loop the way a setpoint that steps does, and that is the user's "jerky and oscillating" answered from the planner
rather than from the gains.

**One accident worth knowing.** The planned host has the throttle **shut for 84-97%** of the flight against 10-11% for
the waiting one. It is not closing it harder; it is asking early enough that the speed error stays big enough for long
enough to drive it shut -- which is a partial way round the typed `throttle_trim` (see
`../todo/flightcore--throttle-trim-is-typed-for-every-aeroplane.md`). It is a symptom being worked around, not a cure:
the heavies still arrive 20 m/s fast because their deceleration genuinely is not there.

### A `--set=` THAT CHANGES NOTHING LOOKS EXACTLY LIKE A SUITE THAT MEASURES NOTHING

**Read this before writing a mutant, a `--set=` or a retune A/B on any kind that is on lifting surfaces.** It is not a
footnote about the gym; it will silently void any suite that proves itself by retuning a number.

**Most of `Handling` does nothing to a kind on `fly_on_surfaces`.** Found on 2026-09-19 while choosing the gym's
mutants: `thrust`, `drag_forward`, `angular_damping`, `yaw_damping`, `control_authority` and `pitch_stability` **all
left the Cessna's scores bit-identical** — not nearly, exactly — because that model reads the surfaces and the control
law and never opens the lumped wing's table. `thrust` x 3 did not move its top speed by a metre a second.

Two of them did work, and they say which half of the file is live: **`pitch_rate` x 4** took the Cessna from 2.0
reversals a minute to **406.0**, and on the light twin four times the roll rate gave **4,801** — because
`fly_on_surfaces` builds `aero::Rates want` from `in.pitch * h.pitch_rate`, so the rate fields are the control law's and
are read. **`weathervane` x 0.05** moved the light twin, which is on the lumped model, where the whole table is live.

**AND A SECOND INSTANCE: `--set=cruise=120` DOES NOTHING ON THE KINDS ANYBODY WANTS TO TRY IT ON -- AND IT IS NOT
BECAUSE THE KNOB IS DISCONNECTED.** lane/warbirds2 hit this on 2026-09-19 testing a hypothesis about the formation
cap, and the first explanation written down here (that `handling()` reports a derived `cruise` while the card writes
`h.cruise`) **was wrong, and was corrected by measuring it**:

| pinned | Cessna reports | fighter reports |
|---|---|---|
| nothing | 56.59 | 70.00 |
| 45 | **45.00** | **51.79** |
| 65 | **65.00** | **65.00** |
| 120 | **70.00** | **70.00** |

`cruise_over` **does** honour `h.cruise` -- and then **clamps it at both ends**: down to the 70 m/s formation cap and
up to 1.45 times the stall. So the fighter pinned at 45 comes back as 51.79, which is its stall floor, and anything
pinned above 70 comes back as 70. **A kind already sitting against a clamp cannot be moved in that direction at all**,
which is every kind somebody would want to raise -- and it reads exactly like a disconnected knob. `stall_speed` is
derived too and cannot be set at all.

**AND A THIRD, WHICH IS THE GENERAL FORM AND SETTLES BOTH: AN A/B FROM OUTSIDE CANNOT TELL "NOT THE CAUSE" FROM
"COULD NOT REACH IT". READ THE CALL SITE, NOT THE SETTER.** lane/warbirds2 set `ground_speed` to 66 and to 90 and got
runs identical to the digit, which is consistent with the knob being irrelevant AND with the knob being unreachable --
and nothing outside the process separates the two. They wrote down both readings and proposed splitting the field the
way `cruise` is split. **That change would have been pure waste.** Two minutes of grep instead: `ground_speed`
round-trips perfectly (set 66, reads 66.00), and every call site of `short_of_flying` is `touching &&
short_of_flying(...)`, so on a leg flown at altitude it is **not read at all, however it is set**. The identical digits
are exactly what the code predicts.

**So: a knob that does nothing IN THE SITUATION YOU TESTED is not a broken knob.** Their own summary of it is the one
to keep -- *"I measured the OUTSIDE of a thing and reasoned about its inside. The measurement was honest and it could
not answer the question I was asking of it."* When an A/B moves nothing, the next step is the call site, not a bigger
A/B and certainly not a change to the setter.

**One lesson about the knob, and a larger one about how both of these were got wrong.** A `--set=` can fail to move a
number because the field is not read, *or* because what reads it CLAMPS it -- and only one of those is visible in the
code near the knob.

### A FIELD THAT CAN HOLD TWO DIFFERENT PHYSICAL QUANTITIES, WITH NOTHING IN ITS NAME TO SAY WHICH

**Five lanes hit this on 2026-09-19 and 2026-09-20. None of them was looking for it, and it is not about aeroplanes.**
**The last one was found by the lane that wrote this rule, hours after writing it**, which is the best evidence that
naming is the only defence: knowing the class by heart did not stop it.

| the field | quantity A | quantity B | what picks the wrong one up |
|---|---|---|---|
| a VTOL's **thrust** | wingborne installed thrust | **lift-mode** thrust, already net of splay loss (Harrier 105 kN, F-35B 186 kN) | the gym derives top speed and acceleration from thrust against drag: the Harrier would have become the slowest fast jet in the fleet |
| a wing's **area** | the wing's own span, **16.26 m²** -- the surface an integration walks | carried out over the tip tanks, **17.49 m²** | a lift slope taking the wrong one stalls the aeroplane somewhere the book does not |
| `handling()["cruise"]` | `default_cruise(...)`, derived and **clamped** | `h.cruise`, the pinned field (reported as `cruise_pinned`) | an A/B that appears to do nothing, and a lane nearly proposing a C++ change for it |
| a ship's **beam** | the hull's moulded beam | the beam over the **lashing bridges**, 58.6 m | 24 container rows drawn where the builder publishes 23 -- the difference is a walkway a hull's beam cannot tell you about |
| a hull's **depth** | depth (keel to deck) | **draught** (keel to waterline) | a boat modelled to a depth floats wherever somebody guessed |
| an aircraft's **height** | `Sim.current`, the **display** list -- the rebased pose the camera draws (352 m) | `vehicle_state()`, the pose an autopilot's altitude is compared against (673 m) | a probe checked an order against the DRAWN height and read a 323 m disagreement as a bug in the order |

**THE TELL IS THAT THE TWO ARE WITHIN A FEW PER CENT OF EACH OTHER.** 16.26 against 17.49. 23 rows against 24. A
lift-mode thrust against a wingborne one. **If they differed by a factor of ten somebody would catch it on sight** --
it is the *plausible* wrong number that survives review, gets committed, and is found a month later by a suite that
was measuring something else. **So checking does not save you here. Naming does.**

**THE NAME IS THE ENFORCEMENT, AND THE INTERFACE IS THE ONLY PLACE IT CAN BE APPLIED.** A block that takes `area` can
be handed either number silently and for ever; a block that takes `area_over_span` cannot. Two rules follow:

- **Name the quantity, not the concept**: `lift_mode_thrust` beside `installed_thrust`; `area_over_span` with the
  end-plate effect as its own separate term; `draught` never spelled `depth`; `beam_moulded` distinct from
  `beam_over_lashings`. Where a figure is derived rather than published, the name says that too (`cruise_pinned`
  already does this correctly, and the trap there is only that the *other* name is the plain one).
- **Publish both where both exist, and make the caller choose.** `Cessna310Airframe.planform()` returning both areas
  is the pattern: nothing downstream guesses, and nothing downstream keeps a copy that can go stale.

**And fix it at the INTERFACE, not at the call site**, which decides *when* as well as where. lane/flightcore put both
of its hand-overs onto step 1 (the blocks) rather than step 3 (the panel list) for this reason: the panel list is a
month away and the block that can be handed either number is this week. **A quantity ambiguity is dated by the
interface that admits it, not by the feature that first notices it.**

### A FIRST-DIFFERENCE METRIC CALLS A STEADY RAMP UNSTABLE

The rule is in `../testing_godot_headless.md` ("Anchor the check outside the thing it is
checking"). Here: **`agl_wander` was a mean absolute change of HEIGHT, which is the rate of
climb**, so nine transports descending at a flawless constant 7.6 m/s scored 8–13 "m/s of height
a second" and were reported as wandering, while lane/tracelog's trace showed the pitch stick at
**0.00 for a hundred seconds**. What the gym wants is the change in the RATE — a mean absolute
second difference. The finding survived because 7.6 m/s really is nearly twice what a
three-degree path wants, but the mechanism was backwards, and a wander is a loop hunting where a
step is a loop switching.

### A RATCHET MUST PRINT THE SET, NOT THE SIZE

The rule is in `../testing_godot_headless.md` ("Anchor the check outside the thing it is
checking"). Here: `exhaust.gd`'s `a_kind_with_thrust_owes_an_exhaust` went red on main minutes
after lane/harrier merged, **29 owed against a ratchet of 28**, and was answerable in seconds
only because the check prints every declaring kind by name — the declaring list was unchanged, so
the rise was an arrival: the **P-47D-30, kind 36**, with thrust and no ports, merged from a lane
branched before it existed. It asks the handling table who has thrust rather than keeping a
roster, which is why it knew the P-47 existed at all.
### READ THE CODE TO FORM THE HYPOTHESIS; RUN THE THING TO KEEP IT; CHECK THE WORLD THE RUN HAPPENED IN

Four of these happened on 2026-09-19, two in each of two lanes, inside an afternoon. Each was confident, each fitted
the evidence, and each was wrong.

| what was believed | what it really was |
|---|---|
| **A limit cycle in the taildragger's boolean tail contact** (lane/flightcore), written out step by step to explain 16.6 chatter a second | 16.6 was the **`waypoint`** row, not the taxi row. On the ground that aeroplane reads **0.1**, the quietest in the fleet. There was no fault to explain. |
| **The cruise knob is disconnected** (lane/flightcore), from reading where `handling()` gets its number | It is connected and **clamped** -- 70 m/s down, 1.45 x stall up. A Cessna pinned at 45 reports 45.00. |
| **A Thunderbolt is slow off the ground**, with a per-kind allowance and a paragraph to explain it (lane/warbirds2), from 106 and 132 seconds to height | The two warbirds were **running off the end of `climb.gd`'s ground slab** and being clamped at the world's floor. On ground they take **35.5 and 39.5**. |
| **`world_edge` needs a 300 s deadline** because of the thirty-seventh kind (lane/warbirds2) | A stopwatch: **65.3 s** against 68.7 for thirty-six kinds. |

**The first two are cured by running it. The second two are not** -- both were measurements, taken honestly, in a
world nobody had looked at. Hence the third clause, and it is the one that catches the expensive mistakes.

**AND THE SHARPEST FORM OF IT, which is worth more than the rest of this section.** On 2026-09-19 lane/warbirds2 was
offered a way to test their own hypothesis and **did not run it**, because on the unfixed gym the experiment would have
walked the asked speed down into the region where the mixer refuses the climb -- and the chatter would have risen
exactly as their theory predicted. *"That is a nastier version of the trap, because it would have CONFIRMED the thing
I wanted to believe."* **A measurement taken in a world with a known fault in it is not neutral: it is biased toward
whatever the fault resembles.** Before running the experiment that settles it, ask what the known faults in the world
would produce ON THEIR OWN -- and if the answer is "the result I am hoping for", fix the world first.

**AND THE RULE THAT ACTUALLY GENERALISES IS THE OTHER HALF OF THAT, which is theirs and is a correction of the first
way this paragraph was written.** It was written as a lesson about discipline -- about how hard it is to decline an
experiment you want to run. They say not: *"It was not hard, it was cheap. What made it possible was that you had told
me your suite was broken in a specific place BEFORE I got to the experiment."* So the rule is not be disciplined, it
is **say what is broken in your own thing early and in detail, to the person who is about to measure through it.**
Discipline is what the other person then needs none of. A known fault announced late is a trap; announced early and
specifically, it is an instrument -- the same broken floor that would have manufactured a false confirmation became
the thing to watch, because it was named before anybody ran anything.

**A corollary they also demonstrated:** when the cause you named turns out to be wrong, **rename the file**. They
renamed a todo from `...the-formation-cruise-cap-flies-a-fighter-at-its-stall.md` to `...the-warbirds-waypoint-leg.md`
the moment they stopped believing it, on the grounds that a filename naming a cause you no longer believe is a worse
lie than a paragraph, because it is what the next person reads first. **They then renamed it again**, to
`...the-p47-will-not-fly-the-waypoint-leg.md`, when the re-measure on the fixed gym cured the Mustang outright
(chatter 16.6 to 0.1, 70 reversals to 10) and left the Thunderbolt exactly where it was: a name that has become HALF
true wants the same treatment, and the file lists both old names in its own header so the history goes with it.

`tests/vehicle_gym.gd` was re-run on a slab eight times wider off the back of the third row above; **not one of its 166
lines moved**, which is why that constant is still small and why the check is written into its doc block rather than
assumed.


**The failure mode is silence.** A mutant that changes nothing prints a pass on a suite that has stopped measuring, and
goes on printing it. Before trusting a retune A/B, check the number actually moved something — and if it did not, the
first thing to suspect is not the suite but whether that field is read by the model this kind is on.

### A SUITE NAMES ITS LEVEL

**A suite that does not say which level it is flying inherits whatever the last thing left behind.** `Net.level` is an
autoload's field: it outlives a scene, it is deliberately kept between sessions so the desk remembers what a player
picked, and a child process started with no `--world=` takes whatever the day's default is. Until 2026-09-15 that was
always the island, so nothing ever noticed.

The rule found it. When hosting started defaulting to the LOBBY (`Net.suit_the_session`), three suites broke at once and
all three broke the same way:

| Suite | What it was really testing | What happened |
|---|---|---|
| `tests/crew_peers.gd` | boarding another player's craft | it was boarding in a briefing room, where a segway has one seat: red on three checks and 90 s of timeouts |
| `tests/steam_join.gd` | a refusal naming the level on a paper lobby | "The host's copy of **The lobby** is not the same as yours", against a sentence naming the island |
| `tests/two_peers.gd` | a second PLAYER arriving in the game's world | it PASSED, in the lobby -- so the island's two-peer path had quietly stopped being covered |

**THE THIRD ROW IS THE ARGUMENT, not the first two.** A suite that goes RED tells you something is wrong; a suite that
goes GREEN in the wrong place tells you nothing at all, and goes on telling you nothing for as long as you leave it.
`two_peers` did not break — it passed, in a briefing room, having stopped covering the thing it was written for, and it
would have gone on passing there for months. The two false reds cost an afternoon between them and announced
themselves. The green one announced nothing and would have been found, if at all, by somebody wondering why a two-peer
bug on the island had no suite.

That is why this is a rule and not three repairs: the repairs fix what was seen, and the rule is about what was not.

**So: a suite that cares what it is flying says so.** `Net.choose_level(...)` before its cases, or `--world=` on every
child it starts. A suite that genuinely does not care says THAT, in its doc block, with why —
`tests/desk_join.gd` does: its child hosts the lobby and this machine arrives with the island chosen, which is the
ordinary joiner's case and is the point.

**And the same shape has a second instance**, worth reading together: wait for the THING, not for a count of frames.
`tests/desk_join.gd` waited six process frames for the desk before pressing Join, where the desk wires its screen after
one. Measured before it was changed, three runs out of three: one frame, against the six waited — five frames of slack,
so it was never relying on luck. But six is a number nobody chose against the thing it has to outlast, and the next
`await` added to `DeskRoom._ready` spends it. It waits for `desk.get("_menu")` now, which cannot go stale and whose
failure says what it means.

**A test that dies silently PASSES.** A GDScript error aborts the function it is in and
carries on with the next, so every check below the error simply never happens -- and a suite
that counts only FAILURES then reports a cheerful pass over a section that fell over. That
is exactly what happened to the new-craft section, which threw on its second check and was
reported green. Each section of `smoke` now increments a counter at its end and the last
check of the run is that all of them did.

**A GDScript parse error does not fail, it HANGS.** The scene never loads, so `_ready` never
runs, so nothing ever calls `quit()`, and the run sits there until somebody notices. Every
suite that ever appeared to take minutes was this and not slowness. `run_all.ps1` gives each
one a deadline, kills it, and greps the log for the parse error that usually caused it.

`--check-only` is NOT a substitute: it does not load autoloads, so every script that
mentions `Sim` fails it whether or not there is anything wrong. **`lint` is**, and it runs
first in under a second. It is a scene rather than a shell loop for exactly that reason --
from inside a running project `Net` and `Sim` exist -- and it compiles every `.gd` in the
project from source, plus checks that every `.tscn` still points at files that are there.

It catches the half nobody sees, too: **a script nothing instantiates can be broken for
weeks.** Most of `objects/controls/` is only ever built by a station scene at runtime, and
a suite that never sits in that particular craft never touches it.

The obvious way to write it crashes the engine, which is worth knowing before rewriting it.
`ResourceLoader.load` with CACHE_MODE_IGNORE SEGFAULTS on any script carrying a
`class_name`; CACHE_MODE_REPLACE survives but hands back the cached script, so a good file
and a bad one look identical; and plain `load` never re-reads the file at all. `lint` reads
the source as TEXT and compiles it into a script of its own, with the `class_name` line
commented out in place so the line numbers in the errors still match.

**A SUITE THAT PRINTS ENGINE ERRORS FAILS**, whatever its own checks said. Every check in
`air` passed while the engine wrote four hundred copies of "Can't set instance color on a
Multimesh that isn't using colors" to a file nobody opened; `smoke` wrote two million of
them, six hundred megabytes, every run. The feature under them was dead -- the per-instance
fade on the lift columns had never once been applied, because `use_colors` was set AFTER
`instance_count` and a MultiMesh refuses that. No assertion caught it because no assertion
could: the evidence was never in the test's output, it was in the stream the test's output
is carefully kept separate from.

`run_all.sh` reads both streams for `ERROR` and `SCRIPT ERROR` and fails the suite on
anything not on a short allowlist. **The allowlist is of MESSAGES, not of suites** -- three
errors that `conformance` and `cockpit_loopback` provoke on purpose -- because exempting a
suite would exempt the next real error inside it. `lint` is the one suite exempt by name,
since printing parse errors is its job.

`--xr-mode off` goes with it: there is no headset on a build machine, and asking for one
writes eight lines of OpenXR failure before anything starts. The gate has to be able to say
"this suite printed nothing".

### AND THE DOCUMENT IS A SUITE

`tests/docs.gd`. This file is four thousand lines and is the primary interface for every
future session -- and its closing paragraph was stale for weeks in a way that HID A LIVE BUG:
it said a real menu would call `Net.host()`, when one already did and `sky.gd` was quietly
undoing it. A claim about the code that goes stale here is worse than no claim, because it is
read as true.

Four things are held, and every one is derived at run time rather than listed in the test:

- **Every `--level=` word here is a door the router opens**, and every level the router opens
  is written down at least once. By DESTINATION for the second, not by alias -- fifteen
  aliases documented is a document nobody reads.
- **Every `.tscn` under `tests/` and `marshalling/tests/` is in `suites.txt` or is a named
  probe with a reason.** That is the check that would have caught `hitch_probe` sitting
  outside the list for months, and adding a name to the probe list to quiet it is the one
  edit that defeats it.
- **Every path this file names in a backtick is a file that is there.** It found one on its
  first run: the station scenes were renamed from `objects/cockpits/station_*.tscn` to
  `objects/seats/seat_*.tscn` and two paragraphs still pointed at the old directory. A bare
  filename in a backtick is a NAME and not a path -- this file says "see `sky.gd`" a dozen
  times -- so a directory is what makes it checkable.
- **Every craft, bus channel and movement model is in the enum and is written about.** Both
  directions: a kind added in the C++ with nothing said about it is a craft nobody knows is
  there.

**It cannot tell you whether a sentence is TRUE.** That `world/sky.gd` is named here is not
the claim that the paragraph about it describes what it does. It catches ABSENCE and NAMES,
which is how this document has actually failed.

`tests/session.gd` is the multiplayer one and `tests/feel.gd` is haptics and sound; both are
described in their own sections above.

`cockpit_loopback` runs a server and two clients in one process across a 133 ms link and
proves the wire format. `smoke` proves the things that only exist in a scene tree.

**`fit` measures every cockpit in the game, built the way it is flown.** It is the answer to
a rule that was written down in three places and enforced in none of them: no two grips in a
craft may be within one hand -- `REACH * 2` -- of each other, or a hand reaching for one
takes the other. Each of the three checks measured a set that was missing the very things
most likely to collide. One instantiated the SEAT SCENE and walked `controls()` on it, and a
station built that way has never been `fit`, so no gun is on it. Nothing anywhere built the
CONSOLE, so the flap gate, the gear lever and the drop handle had never been measured at
all. The other two measured one control against one craft.

Twenty-three pairs were inside the rule the first time a whole cockpit was looked at, across
eleven craft, and fixing them is the layout the game has now: the console cluster spread
0.38 m instead of 0.30, its forward and downward offsets split out of that one number, the
crew button up onto the coaming, the drop handle aft to the pilots' hips, and the gunner's
trigger moved to where a turret seat's throttle used to be.

**That throttle is gone, and it should have been.** A gunner has no authority over where the
craft goes, so the lever in front of them did nothing -- a dead handle, which this project
already says is worse than no handle.

`fit` also asks the OTHER half of the question, which is not about spacing: is every one of
those grips something a hand is actually offered? What a hand may take hold of is
`PilotRig._reachable`, and that was built from a written list of roles -- throttle, stick,
button, extra, flaps, gear, drop -- which went stale the first time a control was added
without editing it. That control was the gunner's TRIGGER, so on every powered mount in the
game a gunner in a headset could traverse onto a target and not be able to shoot. The
desktop hid it, because a keyboard has no hands and asks the gun directly. The list is gone:
`PilotRig.grabbable_in` walks whatever the craft hands out, and `fit` is what says it stays
gone.

**And spacing is not the same question as VISIBILITY.** The first fix for the trigger cleared
every distance in the suite by dropping it 0.27 m onto the console face, which put the grip
under the desk. `tests/station_shot.gd` is what showed that, and it is why it exists.

**Headless cannot measure render-rate smoothness** — there is no independent render clock,
so a loop that steps physics and render together reports perfect smoothness whatever the
code does. Two earlier versions of that check were meaningless for exactly this reason
(one measured acceleration, one measured collisions). What IS measurable headless, and
what the tests now assert, is the *invariant*: the drawn pose is always a point on the
segment between two simulated states, and walking that segment gives equal slices.

**A MULTIMESH READS BACK NOTHING HEADLESS.** `MultiMesh.get_instance_transform` (and its colour and custom data)
answers from the dummy rendering server, which keeps no buffer: smoke's first check of the towns read all 377
buildings back at the origin with no size, and would have passed a count while failing every position. A test that
needs what an instance was given keeps it as it is set (`TownView.drawn_buildings`) and asks the simulation, not the
renderer, whether it is right.

## WHAT IS NOT HERE YET

**The sea drawn beside a long hull is not the sea it floats on (C1, cockpit-ocean, 2026-09-15).** The carrier and the
battleship float on the swell alone (`sea_under`: a waterline three wind waves long), while both seas' sheets draw the
swell and the wind-sea everywhere, so beside them the water drawn is up to 0.635 m (tests/sailing.gd's 64 points; the three
waves' heights sum to 0.65) above or below the water the hull floats in. Their waterlines are 12 m and more down a grey
side, and nobody has looked at one from a launch alongside; do that before calling it fine. A fix is a sheet that fades the
wind waves out under a long hull's footprint, handed each long hull's place.

**The wind-sea does not follow the live weather.** Its heights are fixed at the weather's middle wind, as the painted sea's
are. What blocks a per-world sea: `Sim.swell_shape` reads a bare CockpitWorld never told any weather, several suites sail in
still air or their own weather, tests/pirate_ai.gd cancels the sea against a still-air twin, and a height that follows a
veering wind must be the same on every peer under rollback.

**The wind waves are drawn only to 170 m from the eye** (faded from 110 m), where SeaSwell's growing cells stop holding a
26 m wave. Past there both seas draw the swell's shape and the wind-sea as a painted normal, so a hull watched from further
off rides waves the sheet does not show.

**LEVEL HORIZON carries the hands with the view.** The rig turns about the seat, and the hands are tracked in the rig's
space, so a control on a console rolling a degree moves a few centimetres under a held hand. Nobody has tried it in a headset.

**No wake and no bow wave.** A launch at 18 knots and the brig under sail leave the sea as they found it.

**No treeline on the generated ground.** The woods on alpine are limited by slope alone (35 degrees): on today's world a
treeline at 1,200, 1,500, 1,800 or 2,100 m changed nothing, every wood high enough to cross one being too steep already
(the B4 probe of 60 rectangles). A seed with high plateaus -- gentle ground above 1,800 m -- would grow woods on them, and would
want a treeline, proven by a hand-built case the way B3's column raise is.

**The painted sea is over its budget: +0.43 to +0.55 ms of a headset's two eyes on the open sea and +0.81 ms at the helm view
from a height, against +0.3 (2026-09-15, cockpit-ocean; "WHAT THE PAINTED SEA MAY COST").** The ripples are already two
texture fetches a map (the octaves of noise they replaced cost +0.56 to +1.09). What is left per pixel: four sines with their
bend and groups, the churn, the whitecap curvature, the footprint's derivatives, the per-pixel specular antialiasing and the
roughness hand-off. Time any cut the same way -- scale 2.0, x 3.18, interleaved against main in one slot -- and look at the
helm crop (2-6 m ripples), `sea_200` and `glitter_60` (no lattice, no tiling) and the dusk flicker (under 0.1 % a frame)
before calling it cheaper.
**An AI Hawkeye cruises at the shared 70 m/s formation cap; the real E-2D cruises at 259 kt (133 m/s).** `default_cruise` is
per movement model, and its 70 m/s is a formation decision every wing shares (cockpit-fleet, 2026-09-15).

**The Hawkeye's fifth crewman, the air control officer, has no seat:** the wire carries four.

**No catapult and no wire.** A parked Hawkeye taken from the pilot's seat is lifted to a launch altitude at flying speed by
`launch_if_grounded`, as every parked aeroplane is; a deck landing has wheel brakes alone. `CarrierPlan` draws the catapults
and the wires, and the simulation has neither. A joint step with cockpit-carrier.

**The submarine is surfaced only.** Periscope depth would need a depth channel moving the buoyancy probes up the hull, the
bridge seats refused below the surface and a mast view, and `Terrain.ship_depth` taking the deepest trim (18.3 + 8 m).

**A deck's edge seen from under it at night is a hard arc across the sky.** team-lead, off step2b-try12-look (`mist_deck`,
night, PLAIN): the stratus deck's far edge, seen from beneath, ends in a sharp curve. The compute mist runs the same maths, so it
does not soften it.

**The compute mist's lay-on against the cockpit frame is checked on a runway gate, not the cockpit.** No probe draws a seated
cockpit in the world level: station_shot.gd is a lit room with no sky, scenery_shot.gd and contrail_shot.gd need the watch level's
observer, and shots.gd and climb.gd are headless. The runway gate's frame close in `mist_lens` stands in (step2c-look2
edge-crops). Look for halos at the canopy edge in the headset.

**Street lights are built but switched off; turn on with `TownTuning.STREET_LIGHTS_ON` when their cost is paid down.** The
user switched them off for what they cost in a headset on 2026-09-15; the numbers are under "Street lights".

**When street lights are turned on, the towns' haze domes want the lamps' light in their glow too.** `MistLayer.town_glow`
is the windows' light alone and adds no `LIGHT_PER_CANDELA` share while `TownTuning.STREET_LIGHTS_ON` is false: a dome
glowing with lamps over dark streets would light a town the player sees unlit. tests/mist.gd
`and_the_glow_is_the_windows_light_and_none_by_day` fails on that flag alone, so turning the lights on points here.

**Summit caps were designed and not built: a thin cloud band hugging a peak's top at evening and night.** Step 4 shipped the
valley pools alone when the user asked to checkpoint (2026-09-15). The design is in godotgames-drafts/2026-09-15/cockpit-mist
(step4_design.md): the same relief channel, positive above CAP_RELIEF (~150 m), a band integral centred ~30 m over the ground
where the ground is near the stratus band, faded near level as the stratus is. Risks written there first: a hat on every rock, and
the bright horizon line step 2 paid for. `mist_summit` also has no subject on the alpine world (`_tallest_rock` reads rock boxes,
and the generated ground has none), so a cap's picture wants a summit view that asks the ground for its highest point.

**On the alpine world, scenery_shot's `grass`, `fields`, `forest_low` and `forest_high` do not look at what they name.** They pose off
island coordinates (`Terrain.RUNWAY_AT`, the island's first wood), so they see the sea under ribbons of generated ground or a slope
at arm's length, and time it (step4-views-alpine, 2026-09-15). `grass` fails "the ground is not black at night" there for that
reason: darker still with the mist off. cockpit-terrain's B4 seats the woods' views on the ground; the runway's are not yet.

**A helicopter past the soft edge is yawed to within sixty degrees of home and left there.** `turn_back_from_the_edge`
gives a helicopter or a pod rudder toward the middle and levels its wings, and gives it no pitch, so nothing flies it
home. The blend is also weighted by `pointing_out = clamp(1 - 2 cos(off))`, which is zero once the nose is within 60
degrees of home, so the rudder lets go there too. A Chinook held at a hover, flown out at 30 m/s through a band from
18,000 m and 2,598 m deep, coasted to a stop about 1.5 km past the start. It ended 61.7 degrees off home with its old
handling and 59.8 with the handling of 2026-09-15, and never came within ten degrees (`tests/rotor_rates.gd` with a
variant carrying `"edge": true`, cockpit-chinook). A person on the stick flies home from there. For a future edge lane:
a helicopter's turn home wants a pitch forward, and a weight that holds until the nose is on the middle.

**A far impostor for the generated scenery.** Past a mid ring of about 8 km, rock and buildings could be drawn as a
few merged boxes a cell. It was measured before it was built and not built (2026-09-14, "And nothing is built to draw
the far band"). On the island tiled to 72 km, windowed, everything from 8 to 24 km is 159 to 168 draw calls, about 0.02 ms
of GPU and 0.05 ms of render CPU. Build one only if a measurement in the level, with its sun, shadows and fog, shows the
band matters, or if terrain's far rings leave that rock and those buildings drawn at full detail where they cost
something. Whoever builds it: agree the swap with terrain's levels first, since the two overlap, and use the engine's
`visibility_parent` so the swap has no gap.

**The aircraft lights on `traffic` at night miss their contrast floor, and did before the clouds.** `tests/scenery_shot.gd --parade --time=night`, 110 lights 2.6 km off: contrast 2.42 PLAIN and 2.79 FINE against the gate's 3.0, on main with the detail pass and no mist (2026-09-14), and 2.50 and 2.75 with neither fog clouds nor cirrus; `grass`, `runway_base` and `town_approach` pass at night on both finishes. Pre-existing and not traced: whether it is the lights' size at that range, the night sky behind them, or the floor.

**Whether the production double editor is worth installing, measured on a quiet machine.** `tools/build_godot_double.ps1`
builds llvm-mingw with `production=yes` (thin LTO): the VM benchmark 31.5 / 44 ms against the plain build's 33 / 52 and
stock's 28 / 44, but on cockpit's frame no better -- 7.4-9.6 ms against 6.5-8.0, spreads up to 4 ms -- and every figure
was taken with other lanes timing on the same machine. The editor installed in the main checkout's `_tools` is the plain
llvm-mingw build. Interleave the three again, stock / plain / production, when nothing else is measuring, before
replacing it (drafts `cockpit-double/cost4`).

**The radio names the world's first runway, not the nearest.** `RadioPhrases.runway()` reads `Terrain.runways()[0]`: the
island's one runway, or the generated ground's flattest strip's (team-lead, 2026-09-15). A tower talking to a craft 17 km
from that strip names a runway it is not near; naming the runway nearest the speaker, and which end is in use, is a
radio lane's to build.

**The generated ground is built twice, on the main thread.** `CockpitWorld.set_ground` builds Bedrock's 1,880 height
fields in each world: 2,052 and 2,243 ms on the double editor, 2,012 and 2,223 ms on stock (2026-09-15, a headless
probe). A host freezes about 4.3 s while the level loads and a joiner 2.2 s. `Sim.set_ground` hands a frame between the
two worlds and the level shows "Loading the ground", but each world is still one long frame, which in a headset is the
compositor's grey. The follow-up is C++: compute the fields once, on a worker, and install them into both worlds, which
roughly halves the build and takes it off the frame. Sequenced by team-lead after the pirate and carrier lanes merge
their C++.
- WHAT A WINDOW DREW ACROSS IT, measured without a headset (2026-09-15, double editor, windowed at 1600x900,
  `--level=watch` on the alpine world, every drawn frame timed from the level being added until two seconds after the
  ground stood; only another lane's headless Godots were running). The level took 5,573 ms from being added to the
  ground standing in both worlds, and `ground_built_msec` read 3,728 ms. The longest gaps with no drawn frame were
  1,769 ms, starting 3,108 ms in, and 695 ms, starting 4,877 ms in, where the first ended: ONE frame was drawn between
  the two worlds' builds. Every other gap was 33 ms or less, 125 frames in all. NOT EXPLAINED: the two gaps come to
  2.46 s against a 3.73 s build, and the second is far shorter than the 2.2 s the headless probe measured for the
  client world, so the renderer drew something while part of the build ran.
- A HEADSET CHECK FOR THE USER, since no headset is attached to the workstation these were measured on: load the alpine
  world in the headset (`--world=alpine`, solo) and watch the 1.8 s and 0.7 s frames. Does the compositor show its grey,
  or hold the last frame? Is tracking lost? Does the one frame between the worlds come through? The answer decides whether
  the C++ follow-up above is needed before the alpine world is the default, or only nice to have.

**The gate passes a suite that prints a WARNING, which is not what rule 8 says.** `tests/run_all.ps1` fails a suite on
a line starting `ERROR:` or `SCRIPT ERROR:` and on nothing else, where the root CLAUDE.md's rule 8 says the harness fails
on any warning. A full gate on d35ce549 (2026-09-14, read from its own logs) printed 31 `WARNING:` lines in 9 of 73
suites: cockpit_loopback 5 (`send_command: 16 commands are already waiting; channel 16 refused`), forest 5 (`9 stands and
the ground can paint 8; 1 have trees and no floor`), rota 5 (`add_chore_kind: 'look_ahead' is already on the rota`), snap
4 (`snap position step 0.037 is not one of [...]; using 0.01`), ground_field 4 (`missing key seed`), authored_chunks 4
(`chunk.json is not a JSON object ...; it is not placed`), world_map 2 (`a box with no position or no half_extents ... is
not filed`), builder 1 (`no part called SteamWhistle`) and vr_loopback 1 (`set_tick_rate ignored: takes effect at the
next start()`). Most are a suite feeding a refusal on purpose. **forest's "1 have trees and no floor" is probably a real
fault** -- a stand drawn with no ground paint under it -- and was not traced. Failing on WARNING needs each deliberate one declared as expected first, the way `expect_wire_clamps` does
for the wire's clamp, which is an error for that reason.

**A link that delivers packets in lumps still steps the whole sky a tick at a time.**
`ashiato-gd/addon/tests/crowd_lumpy` (a probe) holds every packet until each third tick: on
4e76324 at 245 kB/s the crowd steps exactly one tick of travel together on 275 of 1,200 ticks
(18,856 steps; 19,523 with the gunships firing), and the same at 1,024 and 1,200 bytes a tick, so
it is not the budget. It is not the interpolation lag (it moved twice; 2 of 275 steps on a
change) and not the buffered clock (it advanced by exactly one frame on 1,197 of 1,199 ticks,
read from `timing()`'s `buffered_frame`; 3 of 275 steps near the other two). Those clock fields
-- `buffered_frame`, `continuous_buffered_frame`, `estimated_server_frame`,
`last_applied_buffered_frame` -- are DIAGNOSTICS: only probes read them, and nothing in the game
should decide anything from them. What is left is how
bunched records land against sync's gap fill -- a late record applied at once, or one frame of
the ring written from the wrong end of a gap. A plain 4-tick link, and the real loopback, do not
show it. If the fix is in ashiato-sync it is a patch under ashiato-gd/tools/patches, proposed
before it is built.
**It is not the freed-baseline bug cockpit-joinfix fixed** (2026-09-14, `ashiato-sync-retain-before-release.patch`),
though it has that bug's fingerprint. Measured on one machine, one after the other: main's library before the patch
(E491DF4E) and after it (0CD9FB0D) gave the same 275 whole-sky steps of 1,200 ticks, 18,856 steps (19,522 under fire),
2 on a lag change and 3 on an uneven clock tick, to the step. So it is still open, and the gap-fill question above is
still the question.

**THE WIRE'S RANGES ARE READ FROM THE GROUND'S OWN BOUNDS, AND EVERY CLAMP IS COUNTED AND REPORTED**
(the fix for a joined pilot past 16 km, or above 2,000 m, being teleported to the edge every tick;
2026-09-14). `ground` is +/-32,768 m and `height` -200 to 41,700 m, both at 0.01 m, from
`ground_core.hpp` (`kWorldEdgeMetres`, and `kSeabedMetres` less 50 m). Every position goes onto the
wire through `put_position`, which counts each clamped coordinate in an atomic counter;
`CockpitWorld` reports new clamps after its server's tick as an error, at most once a second, naming
the first position outside the range; a world that clamps on purpose says `expect_wire_clamps(true)`;
and `wire_clamps`, `wire_round_trip` and `wire_range` let a suite ask. Rounds and missiles are spent
where they cross the wire's range (`leaves_the_wire`), the end recorded at the crossing.

- **ONLY A JOINED MACHINE QUANTISES** -- the host's world never serialises its own state -- so a solo
  or host run flew 24 km out perfectly and showed nothing. The ranges were +/-16,000 m and -100 to
  2,000 m, and ashiato-sync's `quantize_float` clamps without a word, on every position on the wire:
  `VehicleState`, `Route`, `FireState`, `ShotState` (twice) and `MissileState`. Measured by
  `tests/far_out.gd`, 12 checks red: a remote craft past 16 km drawn 7.4 to 47.4 km from the server's
  path, a craft at 2,500 m drawn 573 m off, and a client flying its own aeroplane 24 km out rolled
  back on 360 of 360 ticks against 9 at the origin.
- **The error found two suites that had clamped in silence and passed.** Rounds fell through the
  floor and were sent 20 m under it (crowd_sight's 4,051 clamps, 372 impacts at -120.56 m), and on
  the 64 km world a round 16 km out or fired above 1,900 m was spent the tick it got there;
  cockpit_loopback's world is a 400 m box and counted 232,202 clamps in one run from 11 craft and 2
  missiles left in the air, and has a catch floor under the whole wire now. The floor itself was a
  typed -100 m over the open sea's floor at -150 m, and `GroundField`'s `world_half` could be tuned
  to 40,000 m, past the edge; both are read from `ground_core.hpp` now.
- **After**, `far_out` passes on both editors: craft at 24 and 32 km, and at 4,500 and 20,000 m,
  drawn within 6 to 7 mm of the server's path with no clamp; a client's own aeroplane rolled back 9
  times, as at the origin; the world's corners at the wire's floor and ceiling exact; a position past
  every edge back at the edge counting 3 clamps; and a craft flown 64 km out on purpose clamped with
  736 counted. RED: a library whose positions went onto the wire past the counter failed that last
  check alone, 0 clamps counted for the same flight, while the extremes still passed, because
  `wire_round_trip` counts on its own path.
- **What it cost**, by `tests/wire_budget.tscn` in the real sky: a `VehicleState` send went from 193
  to 199 bits and a `FireState` from 69 to 75; one client's demand went from 1,318 to 1,361 bytes a
  tick, against the 1,024 a send carries.
- Everything else `far_out` measures is steady to 64 km on float32 Box3D and components: 0.33 mm of
  noise flying, 0.19 mm taxiing, 0 parked, and a carrier deck no worse than at the origin.

**Every contrail and missile trail vanishes at once past 40 km on an axis.** `objects/vehicles/contrail_yard.gd` and
`objects/weapons/missile_yard.gd` each give their single trail MultiMesh a typed `custom_aabb` of +/-40 km, which culls the
whole yard when the camera's view no longer meets that box. Inside a +/-32 km map it holds; it should be worked out from the
world's size, one number in one place, rather than typed. Found reading the yards for `tests/far_out.gd`'s research; not
yet shown on screen.

**A claim about the code that goes stale in the one file every future session reads first is worse
than no claim**, which is why there is a docs suite. Half of what this paragraph used to say had
been wrong for weeks -- and the half that was still true was a live bug the wrong half hid.

What is genuinely not here:

- **Changing the level in the middle of a session.** The clipboard's CREW page says which level everybody is flying,
  and choosing another means MAIN MENU, the desk's level row, and a new session: `Net.choose_level` is refused while
  a session is up, because every machine in it stands on the level its host started with. Changing it in flight
  would mean every joiner building a new world and being admitted again. Found building levels, 2026-09-15; not
  built.
- **A clean base on a FINE cloud seen from under it.** Where FINE's frayed rim reaches a cloud's flat base seen nearly
  edge-on, the base shows a ragged dithered fringe (the clouds view, 2026-09-14). The fray is keyed to the lump's cells and
  the eye's midpoint on purpose -- see "A cloud has one base" -- and the fix is in `world/shaders/cumulus.gdshader`: take
  the base's faces out of the fray, or fade the fray by how level the face is. Numbers alone cannot do it.
- **A take-off that climbs out past a shoulder.** A take-off checks its ground roll for a clear run, not its climb-out,
  and `AiPilot`'s leg re-check (b0870c7) looks along legs, not along a take-off. So the airliner `tests/sinking_probe.gd`
  parks on a car waypoint beside a ring peak rotates, meets a massif shoulder about a kilometre out at 20 s (71 m up, 24 m
  above the rock), drops back onto the ground and never regains rotation speed -- 49.0 m/s at 180 s against a stall of 50.1
  -- where over the old steps it climbed away. No spawn in the game takes off from there; any take-off pointed at a
  mountain from close enough would. Numbers from 2026-09-14, on the massif, with and without the re-check: the same.
- **Steam, past making and finding a lobby.** GodotSteam is in cockpit on Windows, both precisions. A Steam session's
  sync packets travel unreliable, and the desk starts Steam so an invite can arrive. Not yet: a Linux build, and a
  two-machine run.
- **Any art.** No textures, no models, no audio files, by budget. Everything is generated.
- **A reason to keep playing.** Nothing counts, scores, times, ranks, fails or ends. The
  fires are the seed of an objective and nothing counts them; see "Fires do not spread".
- **Damage beyond hit points.** Built on 2026-09-18 (lane/combat, "A HULL, AND WHAT BREAKS IT"): hit points,
  smoke, destruction, the crash rule, the overview and respawn. Not yet: where a round hits (an engine, a wing, the
  cockpit) and handling that gets worse as a craft is hurt; a crewman's own injury; a scoreboard.
- **A job that needs two people in one hull.** Four seats, dual controls, three MFD pages, a
  command bus, three gun stations on the gunship -- and no task that wants a crew. The
  cheapest is a navigation page where the non-flying seat picks the next fire off a map and
  the pilot's beacon follows it; both halves already exist.
- **Your own shells start a little behind your own muzzle.** `Sim.drawing_late()` winds a
  birth record on by the interpolation lag, which is right for a round somebody else fired.
  A round YOU fired is born against your own aeroplane, and that is drawn predicted ahead by
  the prediction lead as well -- so on a real link your own tracers leave from behind the
  barrel by about lag plus lead. The row says whose round it is now (`shooter`, 2026-09-14,
  added for the per-round kick), and the lead is `timing()`'s `prediction_lead`; the drawing
  does not use either yet. Found while fixing the lag on 2026-09-13; not changed.
- **The muzzle sound per round is everybody's.** `ShotYard` reports every round it draws, and
  the kick is the only thing that asks whose it was.
- **The priority sphere's controls on the TRAFFIC page.** The sphere is built and ON (see "THE PRIORITY SPHERE"), and
  it changes from `Sim.PRIORITY_*`, the command line and `Sim.set_priority_sphere`. No button on the clipboard reaches
  it yet; team-lead offers it to the user as a follow-up (2026-09-17). The component mask that sat beside the old idea
  is gone: the crew's cockpit is on cabins (see "Only the crew see into the cockpit").
- **Whether 40 Hz a craft is enough in the headset.** Measured (see "200 CRAFT ARRIVE ONE TICK IN THREE"): the gap fits
  the buffer, and the sphere moves rate from far craft to near ones. Nobody has flown formation beside the stack to say
  whether it looks it.
- **A golden image.** `tests/station_shot.gd` renders a PNG nobody diffs, so a cockpit that
  regresses visually regresses silently.
- **A cockpit layout the crew share.** `CockpitLayout` files are per player, in `user://`, and every machine builds
  every station from its OWN files -- so the copilot's machine draws the pilot's controls where the copilot's saved
  layout for seat 0 puts them, and a remote hand, which is a pose in the seat, reaches for a lever that is somewhere
  else on that screen. The scope of a control travels with nothing either. Sharing it is a wire change or a file
  handed over at boarding; flagged 2026-09-13, not built.
- **A building you can tell you hit.** A round or a missile stopped by a building reports `ground`: the hit surface
  enum has no building, and adding one is a simulation change (WP6). Found building the towns, 2026-09-13; not done.
- **Streets on a slant.** `add_static_box` has no rotation, so every town is a north-south, east-west grid. Roads
  between towns are paint and run at any angle; nothing drives along them (the car waypoints are still scattered).
- **Bright bars on a tall tower's narrow side at night.** From 900 m the lit windows on a face seen nearly edge on draw
  as bright vertical bars (the left tower in 8054cd0's before-and-after). `building.gdshaderinc` picks the lit grid's
  `level` from a window's SMALLER side on screen -- the `min` over both axes of `fwidth` of the facade cell -- and one
  `level` coarsens both axes alike. At a grazing angle `fwidth` is anisotropic: a window is a fraction of a pixel across
  the face and several pixels up it, so the grid is coarsened for the narrow axis and each coarse cell stands 2^level
  storeys tall, which is a bar. Coarsening each axis by its own pixels is the coarser-grid lit-window LOD reworked,
  deferred on 2026-09-14 until that night's queue was through.
- **`town_approach` on FINE at night toggles 1.7 a frame, from 0.3 before 8054cd0** (2.5 km, past every window fade;
  PLAIN 1.2 in both). Small, and not traced.
- **Contrails from the engines.** An airliner's and a tanker's contrails should leave their engines, not their wingtips;
  neither the catalogue nor the simulation's shape table says where an engine is, so `ContrailYard` lays two from the
  wingtips `VehicleLights.wingtips` names. Engine positions in the catalogue would move them.
- **A contrail from close behind.** Seen from a hundred and sixty metres astern (`contrail_shot --views=contrail_behind`)
  the two trails are wide pale sheets, and on FINE they carry bands at about a segment's spacing that are not the fade
  (2026-09-14: strength and forming are both whole there, and PLAIN has none). Each segment faces the eye about its own
  direction and widens with age, so a trail seen nearly end-on is all width; a width that stops growing with distance
  along the view, or a tangent shared by neighbours at their join, are the two places to start.
- **A USB rudder pedal device.** The rudder pedals show the rudder; nothing reads real pedals yet. The seam is built:
  `PilotRig.rudder_demand` puts a device pushed off centre ahead of a twisted stick and the thumbstick, and
  `PilotRig._pedal_device_reading` answers null. What goes there is a `PedalDevice` reader: the joypad and axis named
  in a tuning file (device, axis, invert, dead zone, and the calibrated left stop, centre and right stop), read with
  `Input.get_joy_axis`, and null while nothing is mapped or connected. Nothing else changes -- the frame carries it and
  `RudderPedals` shows it. Asked for 2026-09-13; not built.
- **A voice on Linux, and calls that follow what aircraft do.** kokoro's Linux `.so` and `.double.so` need building on
  that machine (`../kokoro-gd/scripts/build.sh`, and again with `KOKORO_DOUBLE`); until then VOICE there says "No voice
  library". The tower answers a radio check and now talks with the traffic unprompted (see "THE FREQUENCY TALKS"), but
  nothing it says follows from anything an aircraft does: take-off and landing calls are next, then a second frequency.
  2026-09-13, updated 2026-09-14. (The first VOICE on costs no frame since 2026-09-17: the synchronous native-library
  load, 15 to 29 ms cold, happens during boot when the complete optional install is present, and the 325 MB model,
  server and worker stay absent until VOICE is selected -- held by `voice_thread` and `headphones`.)
- **A follower that looks where its slot goes.** A leader's legs are checked against the terrain as they are flown
  (`clear_as_flown`) and every wing looks at least twelve seconds ahead, but a follower's destination is a place beside its
  leader and nothing ever checks the path to it: a slot out on the wing can pass over a ridge the leader cleared. In the
  windy probe of 2026-09-14 two followers flew into a ridge at 434 and 442 m; with the wind gone, and the look-ahead in,
  none has since. Not built.
- **A descending leg tested as it is flown.** `clear_as_flown` tests a climb as a climb and then level, but a descent as
  the straight line -- and a gentle descent does not fly that line: it gets down to the waypoint's height within a
  kilometre and flies level from there, lower than the line for the rest of the leg. The one leg smoke's re-check
  dropped on 2026-09-14 passed 41 m over a 443 m rock box as a line, and would have passed it by 7 m as flown. The
  look-ahead is what stands between that and the rock today. Found at the wrap-up; not built.
- **A look-ahead that follows the turn.** The look is a straight line along the velocity, and a heavy wing in a hard
  bank curves off that line. Since 2026-09-14 it is the `look_ahead` chore on the rota (see "A ROTA FOR WHAT AN AUTOPILOT
  DOES NOW AND THEN"), served after the step from where the tick left the wing, and a second of that line is the
  longest wait for the next look; a curved look would be the same chore with a different line.
- **Five thousand autopilots in a 120 Hz tick.** A thousand fit (2,385 us a tick); five thousand are 22,260. The measured
  breakdown and the order of what would have to move are in "Five thousand autopilots in a 120 Hz tick" under the rota.
  The three that change no flight -- ask about the ground only near it (3,026 us at 5,000 wings), no display on a
  dedicated server (1,933), after-the-step on dirty lists -- would leave about 16 ms. Proposed 2026-09-14; not built.
- **The autopilot's guidance as a chore.** Guidance changes over seconds and costs 926 us a tick at 5,000 wings; as a
  chore every 12 ticks it would cost about a tenth, with the mixers kept every tick. A flight change, gated by smoke's
  formation checks. Proposed 2026-09-14; not built.
- **Nothing flags a chore urgent.** The rota serves an urgent chore sooner even when it is full (`set_chore_urgent`, held
  by `tests/rota.gd`), and nothing in the game asks yet: an escape climb, a missile lock or a formation near rock would be
  the callers. 2026-09-14.
- **A look that costs what the sky around it costs.** `clear_between` walks every box in the world, so a look is linear
  in the box count (lane/streaming measured a leg at 2.4 to 2.9 us on the island and 39 to 48 us on 25 tiles). The rota
  bounds how many run a tick, not what each costs; the spatial grid for it is a streaming increment of its own.
- **A budget that knows what a chore costs.** A count or a share bounds how many chores a tick serves; a leg check over
  many boxes is heavier than a look, and a script's chore may be heavier than either. A per-kind cost measured in advance
  and budgeted against would still be deterministic, where a live microsecond cap is not. Not built until a probe asks. In sinking_probe seed 0 on c438470, the gunship added on open ground was climbing at
  about 6 m/s in a 52-degree bank, re-picked lower legs at 77 and 80 s and started an escape climb (to 14.5 m/s), and at
  82 s struck the side of something standing above 436 m: 72 to 7 m/s. It stalled, fell about 140 m onto a ledge at
  300 m, recovered and was flying at 180 s. Seeds 1 and 2 touched nothing. Found at the wrap-up; not built.

**LOOK AT THE GAME WITH THE DOUBLE EDITOR ON WINDOWS** -- it is what the headset plays, and
`tools/play.ps1` starts it -- **and with the stock editor on the Linux machine.** Since 2026-09-15
the double editor renders on Mobile with zero shader errors and the game is back on Mobile:
`scene_forward_mobile.glsl` was passing a `vec4` into a parameter declared `in vec3`, so every
vertex shader failed to compile on any double build, on any backend. The patch is
`tools/godot-patches/0001-forward-mobile-double-precision.patch`, applied by the build scripts, and
the diagnosis is in the `.md` beside it, written to be sent upstream. Before it, the double editor
failed the same way on both machines (Linux/RADV 2026-09-11, 199 shader errors; Windows/D3D12
2026-09-14 on `--rendering-method mobile`, 594). **The Linux failure has the same signature and
almost certainly the same cause -- it is a GLSL type error, so no backend can have been accepting
it -- but has NOT been retested there.** If that machine still cannot draw, it is a second bug and
wants its own note.

**A SHADER ASKS `world/shaders/eye.gdshaderinc` WHERE THE EYE IS, NEVER THE ENGINE.** On a
`precision=double` build `CAMERA_POSITION_WORLD` is minus the camera, so every size, fade and facing
a shader works out from the eye goes wrong by twice the distance from the origin. The engine fact,
its measurement, the 96-picture sweep that closed it and the rejected `MODELVIEW_MATRIX` are in
`working_with_godot.md`, "On a double build, `CAMERA_POSITION_WORLD` is minus the camera". Here: the
include defines `EYE_POSITION_WORLD`, 22 of the 39 shaders read it, and `tests/lint.gd`'s
`and_no_shader_asks_the_engine_where_the_eye_is` went red on all 22 first and fails any shader that
asks the engine again. What it cost while it was wrong, in this game: the runway's approach and
threshold lights drew as cream domes a hundred pixels and more across, the sea lost its waves, the
low forest was not drawn at all, the grass lost its texture and PLAIN's lit windows were flat orange
blocks at evening and night -- every one of them a fade or a size worked from the eye.

**WHAT DOUBLE COSTS: NOTHING ON THE GPU, AND IT WAS THE COMPILER, NOT THE PRECISION, ON THE CPU.**
The compiler finding and its benchmark are in `working_with_godot.md`, "Build Godot for Windows with
MinGW or LLVM, not MSVC, if the game is GDScript": GDScript's VM uses computed-goto dispatch only under GCC or Clang, and
`tools/build_godot_double.ps1` builds with a pinned llvm-mingw and `production=yes` for that reason.
An editor built before 2026-09-14 should be rebuilt; `-Toolchain msvc` is the old build.

Cockpit's own numbers, interleaved A B A B, A stock and B double, `tests/scenery_shot.gd
--hold-fires`, six views, both finishes, 240 frames after 60 to settle, 3D scale 1.40, with other
lanes running, so only B minus A is read against A's own spread between its two launches (ms,
medians; drafts `cockpit-double/timing/`):

| view | finish | GPU B-A | wall A spread | wall B-A | physics scripts B-A | process scripts B-A | render CPU B-A |
|---|---|---|---|---|---|---|---|
| runway | plain | -0.00 | 5.06 | +3.11 | +0.82 | +1.98 | +0.26 |
| runway | fine | +0.00 | 6.19 | +3.99 | +0.78 | +2.16 | +0.34 |
| runway_base | plain | -0.00 | 4.92 | +5.77 | +1.18 | +2.60 | +1.31 |
| runway_base | fine | +0.00 | 0.17 | +8.71 | +1.96 | +3.92 | +2.26 |
| traffic | plain | +0.00 | 0.56 | +8.80 | +1.93 | +3.93 | +2.15 |
| traffic | fine | +0.00 | 0.04 | +9.29 | +2.02 | +4.47 | +1.99 |
| sea | plain | +0.00 | 5.49 | +4.17 | +0.93 | +2.36 | +0.47 |
| sea | fine | +0.01 | 3.72 | +4.89 | +0.95 | +2.64 | +0.76 |
| forest_low | plain | -0.01 | 4.40 | +3.78 | +0.87 | +2.05 | +0.59 |
| forest_low | fine | -0.03 | 5.83 | -0.02 | +0.07 | +0.78 | -0.76 |
| town_approach | plain | -0.02 | 5.93 | -1.87 | -0.41 | +0.13 | -1.36 |
| town_approach | fine | -0.02 | 8.37 | -0.47 | -0.22 | +0.51 | -0.68 |

The GPU does not notice: every GPU median within 0.03 ms, A's own spread 0.00 to 0.01, and draw
calls equal to within one. **TRUST THE THREE-WAY RUNS IN `working_with_godot.md`, NOT THE PROCESSOR
COLUMNS OF THIS TABLE** -- it is a two-editor run of the MSVC build under a different load, and the
8.7 to 9.3 ms it reads is the compiler. Measured three ways on `traffic` and `runway_base`, both
finishes, interleaved twice: official stock 7.6-8.4 ms, llvm-mingw double 7.3-8.0 ms, MSVC double
9.7-10.8 ms, GPU the same on all three. The gate passed 57/57 in 240 s on the production llvm build.
Drafts: `cockpit-double/cost2`, `cost3`, `cost4`.

### Host-generated network radio (2026-09-16)

Ambient `TowerFrequency` chatter is gone. The AUDIO page's HOST RADIO section is the only source of generated ATC:
the host asks Kokoro to render a selected or typed line, `AudioEffectCapture` reads it from the silent `RadioCapture`
bus, and `RadioClip` low-pass resamples it to 8 kHz IMA ADPCM. `Radio` sends the bounded clip with Item 9's
`LongTransfer`; clients never load Kokoro. The host also decodes and plays the transmitted bytes, so there is one
playback path.

Measured by `tests/radio_clip.gd`: 25.98 dB SNR for a two-tone speech-band probe, 4,003.0 bytes/s, and exact delivery
of the seven-second maximum through deterministic 10% first-attempt loss in 2,800 ms. A clip is capped at seven seconds/32 KiB and expires after three
wall seconds. Seven seconds is the clip cap: about 28 KiB leaves retry room under the carrier's 12 KiB/s pace before
that deadline. When simulation timing exists, a clip more than 360 server frames old is also dropped. Only the host may
send kind `clip`.

`tests/radio_peers.gd` is the real ENet gate. It loads the model on the host, points the client at an empty model folder
and missing extension, presses the real `Radio.speak` path, and proves both play one decoded clip while client publishing
is refused. `tools/export.ps1 -HostVoice` copies the three model files to `kokoro/models` and the single-precision
extension, manifest, and ONNX Runtime to `addons/kokoro_gd/bin` beside the executable. Without `-HostVoice`, export says
explicitly that it is a client/non-speaking build. The exported `--speak-test` is the gate: it must print
`VOICE_SAMPLES=` and `CLIP_BYTES=`. All non-XR Godot runs use both `--xr-mode off` and `--desktop-only`.

The old chatter and voice-thread suites were retired because both exercised the deleted periodic filler scheduler.
Codec quality/loss/refusal/staleness is now `radio_clip`; actual threaded synthesis, capture, same-path host playback,
model-free client playback and frame responsiveness are covered by `radio_peers` and the exported speak test.

Primary API evidence: Godot `AudioEffectCapture` documents bus PCM capture for network transmission and
`AudioStreamWAV` documents dynamically generated PCM playback. Steamworks `ISteamUser` only records microphone voice
with StartVoiceRecording/GetVoice and decodes that format with DecompressVoice; it exposes no arbitrary PCM injection,
so generated ATC travels on the game's bounded session carrier rather than Steam voice.

### Which build is this: the stamp, the clipboard's frame and BUILD_INFO.txt (2026-09-18)

Asked for on 2026-09-18: the build in a text file in the build folder, and on something always visible that is in every
screenshot and video, so a picture or a player can say which build it came from ("look at the ipad, or the lower right
of the screen").

- **`BuildPlate` (`ui/build_plate.gd`) is the one answer.** Version, release name, commit, branch, time, and `line()`:
  `0.2.1 leaping-llama · 3631368a · 2026-09-19` in a release, `dev · b95bfa89 · 2026-09-18` in anything else, each
  ending with the day it was BUILT, in UTC. Nothing else types any part of it.
- **WHEN IT WAS BUILT IS ONE NUMBER: `BuildPlate.time()`, epoch seconds UTC (2026-09-19, lane/buildtime).** The date on
  the line, the handshake's `built`, the CREW page's lines and BUILD_INFO.txt's `built:` all come from it. A release
  and a dev export bake it as `application/build/time`. This replaced `build/date`, a local "2026-09-18 14:03" string
  that no two machines could subtract. **A dev run's time is its COMMIT's committer time**, read out of `.git` by
  `GitPack` (`ui/git_pack.gd`) with no git process. The commit time is the same on every machine at that commit, so two
  lanes at one commit are the same age to the second. The day it ran (what the dev line said until then) and the time
  HEAD moved (the reflog) both differ by machine, and were rejected.
  - **Reading a commit from files means reading PACKS.** The shared repo held no loose objects at all on 2026-09-19, and
    1,156 of its 3,624 packed commits (32 %) were deltas. `GitPack` binary-searches each version-2 `.idx` and applies
    offset and name deltas. The first read at boot costs **0.94 ms**, and 500 commits back (19 of them deltas) take
    about 150 ms and all agree with `git log --format=%ct` (`tests/build_time.gd`).
  - **THE ZLIB TRAP: `PackedByteArray.decompress_dynamic` never returns on a stream with bytes after its end.** Its inner
    loop waits for input or output to run out, and zlib at stream end consumes neither (`core/io/compression.cpp`). In a
    pack the next object always follows. So a packed object is inflated with `decompress` to the exact size its entry
    header gives, and only a loose file, one stream and nothing after it, goes through `decompress_dynamic`.
  - Only 1 of the newest 60 commits was a delta, so a test of the newest few proves nothing about deltas. The suite
    reads 500 and asks git how many were deltas.
- **A release is baked; a dev run reads `.git`.** `tools/release_beta.ps1` writes `application/build/{name,commit,
  branch,date}` into project.godot after the import and before `--export-release`, and puts the file back in a
  `finally`: those settings travel in the pck's project.binary, with no export filter to forget, and no hash is ever
  committed. A dev run reads HEAD and its ref from the checkout, following a worktree's `.git` file to its gitdir and
  `commondir`. There is no `+dirty`, because `git status` took 65 to 187 ms here on every boot of every suite.
- **`BuildStamp`, the autoload, draws it in the lower right**, on CanvasLayer 1024, above the level curtain's 512, so it
  shows between levels too. It ignores the mouse, and it copies itself into the director's recording window while that
  is up. **It hides while the root viewport is in XR**, because a root CanvasLayer is composited into the eye buffers
  (see `autoload/monitor.gd`), so the desktop mirror of a VR session has no stamp. A headset player reads the
  clipboard instead.
- **The stamp also names the LANE and the WORKTREE** (2026-09-19, lane/stamps): `dev · da673ea5 · 2026-09-20 · lane/stamps ·
  C:\gg-wt\stamps`, from `BuildPlate.where`, derived from `res://`'s own path (the folder under `gg-wt` is the lane, anything
  else is `main`) and never typed, passed in or read from an environment variable. It is not in `BuildPlate.line()`, which
  the handshake compares, so two lanes at one commit are still one build; a release says nothing of it. The stamp is now about
  490 px wide of the 1600 canvas. How to take a picture or a film, in the whole, is in the doc block at the top of
  `autoload/build_stamp.gd`; `tests/build_stamp.gd` fails a probe that makes a SubViewport picture without `attach_to`.
- **The clipboard says it on its FRAME** (`Clipboard._a_build_line`, a Label3D on the lower bezel, 6 mm tall), not on
  the page. That way every tab has it, it takes none of the page's spent height, and it never redraws the render target.
- **A probe that measures the root viewport's pixels skips `BuildStamp.pixels()`.** The stamp is in every picture on
  purpose and is never switched off for a probe. Six probes scan the frame and mask it: bake, vat, oil platform, star,
  scenery's star count and director_shot. A new whole-frame measurement does the same.
- **A probe that photographs a SubViewport of its own calls `BuildStamp.attach_to(stage)`**, which puts the same stamp in
  that viewport's lower right, sized to it (151x22 px on 960x540), and `BuildStamp.pixels_in(stage)` to mask it. Eight
  probes do: apache, falcon, littlebird, prowler (three stages), puff, savoia, tomcat and tomcat_surfaces. The
  director's recording window gets its copy the same way. **A probe that saves a board's PAGE** (the glass
  SubViewport, `panel.get("_screen")`) attaches one there too: craft, crew, code_pad, music, notice, radio, sky,
  many_seats and level_shot. Left without one: `mist_multiview`, whose stage is in XR, and `director_cost`, which measures its window's
  colour spread. Probes that photograph the root viewport, such as the galleries, pilot_seat_shot and every
  `get_viewport()` shot, have the autoload's stamp already.
- **One export path.** `tools/export.ps1` is a thin wrapper over `release_beta.ps1 -Dev`: the double editor, the commit,
  branch and time baked in with no name, so a dev build says `dev · <commit> · <when built>`, never `dev · unknown`
  (an exported game has no `.git` to read). `BuildPlate.is_release()` needs a baked NAME as well as a commit.
- **Every release folder has `BUILD_INFO.txt`**: version, name, full commit, branch, time ("built: 2026-09-19 15:15 UTC
  (epoch 1789830928)"), engine, the exporting editor, music tracks, host voice. `-ExportOnly -OutDir <dir>` makes a
  test build and nothing else. The exported game prints `BUILT=<epoch>` beside `BUILD=`, and `build_export` checks that
  it falls inside the export's own window.
- **"WHAT IS THE LATEST BUILD" IS WRITTEN AND SWITCHED OFF** (the user, 2026-09-19: "plan to have some sort of 'what is
  the latest build' http request (commented out for now)"). `BuildStamp.ask_for_the_latest_build` would GET
  `LATEST_BUILD_URL` once at boot, expecting `{"line", "built", "commit", "url"}`, and add "0.2.2 is out, 3 days newer"
  to the stamp. The URL is empty, the call in `_ready` is commented out, and the function makes nothing while the URL is
  empty. `build_time` fails if the URL is filled in. To switch it on: publish that JSON from `release_beta.ps1`, fill
  in the URL, uncomment the call, and give the suite a local server to ask.

Gates: `build_stamp`, which walks the desk and every level, checks three sizes, a click through the stamp and all ten
tabs of the board, and the stamp's date against git's. `build_export`, which does a real export through the script
and runs the built game to read its `BUILD=` and `BUILT=` lines. `build_time`, which checks the dev time against git
over 500 commits and a scratch repo's loose-then-packed commit, the age words, the CREW page's lines and the switched-off
latest-build request. `handshake_peers` for the words each side is shown. Probe: `build_stamp_shot`.
