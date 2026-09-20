# cockpit — a crew, and the session they share

Part of [`agents.md`](../agents.md), which carries the rules every one of these files assumes and an
index of the rest. **How more than one person gets into one aeroplane and into one session,
and everything they say to each other.**

## THE COMMAND BUS

A crew shares more than a stick. Gear, flaps, a throttle lever, which weapon is selected,
which radio channel -- all of it has to reach everyone aboard, and none of it belongs in
`ControlInput`, which is one pilot's momentary demand and is deliberately never replicated
to anybody.

So the bus lives on the VEHICLE, and on each crew member's CABIN, and what separates the pieces is
whether the SIMULATION reads them and whether anybody OUTSIDE can see them:

| | | | Who receives it |
|---|---|---|---|
| `CraftControls` | throttle, flaps, trim, gear, spoilers, doors | the physics reads it | everyone |
| `CraftSystems` | the turrets, the lights, the rails, the tank | seen from outside the craft | everyone |
| `CabinSystems` | weapon, radio, display, mode, master arm, crew lamp | nothing outside the cockpit can tell | **the crew only, snapped** |
| `CrewControls` | where every seat's levers ARE, and the linkage they share | nothing reads it -- it exists to be looked at | **the crew only, snapped** |

The last two are on a `Cabin`, one entity per crew member, and are the only things about a
craft that are not sent to everybody. See "Only the crew see into the cockpit" below.

**What the channels mean is per kind.** The wire only ever carries a channel number and a
value; everything that makes one mean "flaps" and another "collective trim" is in
`craft_schema`, which the game asks for to build a cockpit and the simulation asks to decide
whether a command is even meaningful. An aeroplane has flaps, gear and spoilers; a
helicopter has cyclic trim and a hover hold; a car has a handbrake. A command for a channel
a craft is not fitted with is REFUSED, not quietly ignored.

**Two rules on who may command what.** The physical half needs a flying station -- a gunner
may change weapons and the radio from the back seat and may not put the gear down. The
internal half is open to any seat.

### It goes on the input frame, not down a side channel

A command rides on `ControlInput` as a channel, a value and a sixteen-bit sequence (two bits until 2026-09-17, eight
until 2026-09-18: see "A joiner's dragged lever lost the value it was let go at" and "Past the named channels", below). That is not
laziness: an input frame is the only thing in this game that already survives a rollback
correctly. Sync keeps it, replays it, and the server already edge-detects buttons on it. A
reliable side channel -- Godot RPC or otherwise -- would arrive on a frame nobody was
resimulating and land in a different order on a replay. The sequence is what makes it a
command rather than a level: holding a switch does not send it a hundred and twenty times a
second, and a replayed frame does not apply it twice.

**This is why the bus is ashiato's and not Godot's.** The physical half must go through the
rollback machinery, because gear and flaps change the physics and a predicting client has to
predict them. Splitting the transport so the internal half went over RPCs would buy two
ordering models and two failure modes for a component that costs 48 bits and only sends when
it changes.

Note what that argument is and is not about. It is about the TRANSPORT -- one ordering
model, not two. It says nothing about the AUDIENCE, and the two were confused for a while:
everything on a vehicle went to everybody because the bus was ashiato's, as though sending
less were only possible over an RPC. It is not. See below.

### Only the crew see into the cockpit

Asked for on 2026-09-14: "filter data on the server to only send it to some clients, then have the clients SNAP
rather than INTERPOLATE the results. That way we have private data flow between pilots in one vehicle and no Godot
for syncing of game data."

**A crew's cockpit rides on CABINS: one entity per crew member, sent to that member alone, snapped on arrival.**
`publish_cabins` (server, after the tick) gives every occupant of every seat a `Cabin` for that craft -- `CabinOwner`
(whose, which seat, the craft as an entity reference), `CabinSystems` (the crew's switches) and `CrewControls` (every
seat's levers) -- moves the seat on it when they change seat, and retires it when they leave the craft. The server's one
copy of the switches is `CrewSwitches`, a plain ECS component on the vehicle that `apply_command` writes.

- **Only its owner is sent a cabin.** The decider in `CockpitWorld::start` answers the largest float for the
  cabin's own client and zero for everybody else, and sync skips an entity whose priority is zero or less before it is
  serialised or given a network id (`client_update_scheduler.cpp`, `send_client`). It was NaN until ashiato-sync
  8fa08cf, where zero became the filter and NaN began to throw in an assert build. A new or reused slot starts filtered
  for every client and is asked before its first send, so an outsider is never told a cabin exists and never sent its removal.
- **Every machine snaps it.** The mode selector puts the `Cabin` archetype in `ReplicationClientMode::Snap`, which
  applies a record in the client's tick the moment its packet is processed and erases a destroyed one at once.
- **Nobody predicts it.** So a crew switch no longer reaches the pilot's predicting machine as a rollback of the world.

Measured in `ashiato-gd/addon/tests/crew_cabin` -- A flying, B its copilot, C elsewhere and then boarding and leaving
five times -- on the library before (2c774b5's cockpit module) and after:

| | before | after |
|---|---|---|
| crew records written to C while not aboard (server trace, per client) | 30 | 0 |
| the copilot shows a switch, ticks after its packet lands, 1-tick link | 3 (buffer 5 frames) | 0 |
| the same over the 4-tick link | 2 (buffer 7) | 0 |
| C's copy of the cabin after C leaves | kept, in 5 rounds of 5 | gone 5 ticks after leaving |
| crew records written to C after it leaves | 10 a round | 0 |
| the pilot's own radio appearing on a tick the pilot's machine rolled back | 3 of 3 | 0 of 3 |

**Why the buffer did not show over a long link.** A Step component on an interpolated entity is applied when the
buffered clock reaches its frame, and sync's estimate of the server takes the link out -- so a record that lands later
than the buffer is deep is applied on arrival anyway. Over 4 ticks it looked snapped; over 1 tick, the machine on the
same network, it was 3 ticks late. Measure a lag over a link SHORTER than the buffer.

**It replaced a component mask** on the vehicle, which withheld only `CrewControls` and needed
`ashiato-gd/tools/patches/ashiato-sync-baseline-on-mask-open.patch` to survive re-opening. A mask on a live entity has
two faults a cabin does not: closing it removes nothing from somebody who left, and sync asks about an entity only when
it is DIRTY, so a crew change on a still craft was noticed late (8 ticks after sitting down, against 5). The patch is
still applied and still required by both build scripts; nothing in cockpit uses a mask now.

**One cabin per crew member, not one per crewed craft, and the numbers chose.** `ashiato-gd/addon/tests/cabin_granularity`
flies a full gunship (four crew) and an outsider for 600 ticks of the stick moving and 30 switch commands, then hands the
fourth seat back and forth five times. Built both ways on 2026-09-14, the per-craft variant sending one cabin to everybody
seated in the craft:

| | before (a mask on the vehicle) | per member | per craft |
|---|---|---|---|
| bytes a tick to each crew member | 81.4 | 82.3 | 82.3 |
| bytes a tick to the outsider | 65.2 | 65.1 | 65.1 |
| crew bits a tick written to the outsider | 25.1 | 0 | 0 |
| ids started / destroy records, each client whose seat changed hands | 0 / 0 | 10 / 40 | 1 / 0 |
| the leaver's copy of the cabin | kept | gone within 5 ticks | kept, 5 rounds of 5 |

The wire is the same to a tenth of a byte, because sync writes one packet per client: a change in a four-seat craft is four
records either way, one to each crew member, and per member adds only the cabin's owner in a full record. Per craft
churns fewer ids, and never takes the cockpit away from somebody who leaves -- sync has no removal for an audience that
closes -- which is the half of "private" the request asked for. Destroy records count every resend before the client's
ack, so 40 is 10 destroys, not 40. Anything private to ONE seat would be a field keyed by seat on the same cabin; nothing
needs it yet.

**Everything else still goes to everybody, and has to.** The pose is the aeroplane in the sky; the kind picks its shape
and its handling; gear, flaps and nacelle angle are visible from outside it; a turret is somebody else's barrel tracking
you; the lights and the rails can be seen. The rule is not "share less", it is "share what can be perceived".

**Every trait still writes its component in full.** The "delta" in this protocol is *which* components changed, never
arithmetic inside one, so a boarder's first cabin record is absolute values (`round_N_and_its_first_frame_is_the_whole_cabin`).
A trait that starts using the baseline parameter breaks that.

**A switch is the crew's or the craft's by its bit.** `kCrewFlags` (the master arm, the crew lamp) travel on
`CabinSystems` and `kOutsideFlags` (the lights, and two spare) on `CraftSystems`, each serializer masked to its own, and a
`static_assert` beside `kMasterArmBit` holds the two apart. It stopped the first build: the outside mask was 0x000F, which
took the master arm with it.

`sitting_down_opens_the_cockpit` and `only_the_crew_see_the_cockpit` in `cockpit_loopback` still hold, now against
cabins; `crew_cabin` is the suite that counts the wire.

### The thing that made this worth doing properly

The turret used to live in `VehicleState`. It moved here, and the reason is the sharpest
rule in the project stated backwards:

**On a PREDICTED entity, an authoritative value only ever arrives ON A ROLLBACK.** Between
rollbacks the local simulation owns the state -- that is what prediction IS. So anything on
a predicted vehicle that this machine cannot compute for itself, because it does not have
the input that drives it, never arrives at all unless something rewinds. The pilot of an
aeroplane watched their own gunner's turret sit dead ahead while it swung for everybody
else, and `VehicleState` deliberately does not rewind the world over a barrel.

So `CraftSystems` DOES roll back, on a coarse threshold. What makes that affordable is the
other half of the correction machinery: a rollback moves the picture by the size of the
disagreement, and a turret disagreement moves position and attitude by nothing at all. It
costs resimulation, not comfort.

**And the crew's own switches are not on it any more, for exactly that reason.** A radio channel or a master arm
thrown in the cockpit used to reach the pilot's predicting machine as a rollback of the whole world: the pilot's own
radio appeared on a rollback tick 3 times in 3. On a cabin, which nobody predicts, 0 in 3
(`crew_cabin`, `and_it_takes_no_rollback_to_show_it`).

### A job writes what a job declares

Three separate times now: routes, turrets and the throttle lever were each first written
from inside `drive_vehicle`, which the simulation job runs, and each time the write silently
did not stick. `publish_routes`, `publish_levers` and `aim_turrets` all run after the job,
beside `update_display`. If a component write appears to do nothing, this is why.

### A switch on the craft shows the craft: CRAFT, SEAT and PILOT

**Every control says whose its position is**, in `VehicleControl.scope`, set by each part in `_build`:

| scope | what it is | sent | drawn from |
|---|---|---|---|
| `CRAFT` | a setting on the bus: switches, levers, trim, the master arm, selectors | as a PROPOSAL, when a hand here moves it | the craft, at every seat |
| `SEAT` | yours while you hold it: your input, sent to the craft as a demand, not a shared setting | on the input frame, every tick | your hand; the linkage for everybody else |
| `PILOT` | yours alone | never | nothing but you |

**A saved cockpit carries it.** Every entry `CockpitLayout` writes has `"scope": "craft" | "seat" | "pilot"`, as a word
because the file is for a person. Read back with the part's OWN scope as the default at that call site, so a layout
from before scopes loads as what each part is, and a word that is not a scope warns and changes nothing. The builder
suite fails a part in the bin that leaves `scope` UNSAID.

**Suites don't read the player's saved cockpits.** `user://cockpits` belongs to whoever plays on the machine, and
`CockpitStation.fit()` applies it last of all, so a suite measuring the cockpits AS AUTHORED was measuring the player's
arrangement: on 2026-09-13 a plane layout saved while playing failed `fit` on four pairs the player had put side by side.
`CockpitStation.use_saved_layouts` is on in the game and turned off by `tests/fit.gd` before it builds anything. The
suites that test saving on purpose leave it on and put the player's file back: `pedals` writes a layout, rebuilds the
station the way the game does and finds the pedals where they were put, which is the proof a saved layout still applies.
Never fix such a failure by deleting or moving the player's file.

**And suites never write there either.** The same night the first full gate after that DELETED the user's plane
cockpit: `tests/builder.gd` called `CockpitLayout.forget(PLANE, 0)` at its start and end, as it had in every gate since
2026-09-11, and no copy survived in `user://`, `%TEMP%`, the job scratchpads or the Recycle Bin. `CockpitLayout.folder`
is now `user://test_cockpits` for any run started on a scene under `tests/` or `marshalling/tests/` (read from the
command line, so a suite run by hand is covered too) and `user://cockpits` otherwise; `PlacingGrid.path` follows it.
`builder` checks it first. `run_all.ps1` hashes every file in the player's `cockpits` folder before and after and fails
the run as `player-files`, naming what changed.

**An MFD panel's keys are the pilot's.** `MfdPanel` was the craft's, and `DISPLAY` is one selector for the whole
aircraft, so a key pressed on one panel lit the same key on every MFD panel aboard. The page on the glass already
chose itself locally (`MfdPage`), so which key a person last pressed is theirs. A layout can make a panel the craft's
again.

The sharing code reads the scope and nothing else. `FlightLevel._draw_cockpit` used to walk four roles -- extra,
flaps, gear, drop -- through a second copy of `channel_value` that knew four channels, so the trim wheel, the master
arm switch and every knob and switch the builder can place were drawn from the last hand that touched them. Measured
before: the U key armed the craft in five frames and both master arm switches still read SAFE two seconds later, and a
hand on the pilot's switch found it at SAFE on an armed aeroplane, so pulling it back sent nothing.

**A press proposes; the craft decides.** `VehicleView.propose` sends the command and `shown_value` shows the ask until
the craft agrees with it or `PROPOSAL_GRACE` (0.5 s past `Sim.drawing_late`, counted in physics frames) runs out --
then the craft wins, which is how a press the server refuses snaps back. The rig proposes only what a hand on this
machine moved (`VehicleControl.moved`, which `apply` never emits), and a `Bind.step` steps from `shown_value`.

**One command per input frame, and it was losing the rest.** `CockpitWorld::send_command` keeps ONE pending command and
bumps a two-bit sequence, so a second command in the same frame overwrote the first and four wrapped the sequence back
to where it was, and the server saw nothing. U and Y pressed together: "master true -> true, station 0 -> 1".
The queue lives in the library now (ashiato 09a9e29): each command rides a thirtieth of a second of frames, 4 at
120 Hz, so a burst of five lands about 16 ticks end to end and a frame the server skips does not lose one. It lived in
`Sim.send_command` first (770aa14), one per tick, and was taken out once the library's landed, so there is one queue;
`five_channels_asked_for_in_one_frame_all_land` held through both. Sim's had one case wrong that the library gets right:
it kept the latest value per channel for CREW_TOGGLE too, which is a press the server flips on receipt, so two presses
of the crew button inside one tick flipped the light once.

**And that loss had been hiding a third bug.** `_take` forgot what the rig had sent, so the next frame sent every
wheel's and switch's LOCAL position: with the queue in, changing seat in an armed aeroplane trimmed to 200 left it
"master false, trim 128". Before the queue the dozen commands of a seat change overwrote each other and the check
passed. Fix a lost-message bug and the messages it was losing start arriving -- look for what they say.

**A joiner's dragged lever lost the value it was let go at (2026-09-17), and every dragged CRAFT-bus control from a
joiner could.** A lever dragged across its travel sends a new command each time the last has ridden its 4 frames. The
server acts when the frame's sequence differs from the last it saw from that client, and sync hands it only the NEWEST
input frame due, skipping older ones that came late alongside it. Skipping the middle of a drag is harmless -- the
newest frame carries the latest value -- UNLESS THE SEQUENCE WRAPPED, and at two bits four skipped commands read as
no change: the let-go value then sat on every later frame under a sequence the server thought it had acted on, and was
lost for good. Five skipped read as one, which lands a value from the middle of the drag. So a joiner whose frames
reach the server in bursts -- a loaded machine, a jittery link -- could leave the trim wheel, the flaps lever or the
F-14's sweep handle anywhere along its travel. The host never saw it: its own hand does not cross the wire.
- **How it was found**: `sweep_peers` went red on main when the puff clouds made both processes heavier. The RIO's
  handle moved on the joiner, `propose` sent it, and the wings never moved on either machine; under 30 CPU burners
  both machines ended at 52.6 degrees, a value from the middle of the RIO's drag that nobody let go at. Main's
  `sky.gd` swapped for the one before the clouds passed in 21.7 s, and nothing in it touched input -- only the load
  did.
- **The fix**: the sequence is eight bits (PROTOCOL 16, +6 bits on a frame whose command changed, the full frame 327
  to 333). 256 commands would have to be skipped now, over a second of dragging with not one frame reaching the server.
- **The test**: `tests/command_burst.gd`, over `gun_link`'s in-process link, seats a real client in the Tomcat's back
  seat, HOLDS its packets while it sends N commands through `send_command`, then lets them through at once. On the
  two-bit bus: 1, 2, 3 and 5 landed; 4 and 8 left the server on the value before the burst.
- **Look here first** when a joiner's control "moved but did nothing" and the host's own always works: the joiner's
  frames are crossing a wire, and the host's are not.
- **Sixteen bits since 2026-09-18** (busbits, at the user's asking): `kCommandSeqBits`, 65,536 commands, and
  `command_burst` holds a burst of 256 too, red with the width set back to eight. The server still compares with `!=`
  rather than a half-window "newer than": sync discards a late frame rather than handing it over (`input_window` counts
  377 of them), so there is no stale frame to guard against, and a half window would refuse up to 32,768 commands
  from a client whose remembered number went more than half the range stale.

### Past the named channels: a craft with hundreds of devices (busbits, 2026-09-18)

Asked for on 2026-09-18: "There could easily be 255 or 512 devices in a single vehicle ... internal to the plane there
will be many (including sometimes 4x for a single device, one for each pilot). Let's make sure we can support a large
amount > 256 and we can configure more if we get there."

**A device was never the limit; a channel was.** Any number of controls, keys and per-seat copies work ONE channel
through `DeviceSignalRouter` -- the pilot's and the copilot's flap levers both send `FLAPS`. What was capped was how
many independent values a crew shares: 32 channels, five bits on the wire, seventeen used, and every one a
hand-written case in `apply_command` writing a named field. A channel past them had nowhere to travel and nowhere to
be kept, so widening the number alone would have bought nothing.

**Every width is one number in `cockpit_components.hpp`**: `kCommandChannelBits` (16, so 65,536 channels),
`kShortChannelBits` (5), `kCommandSeqBits` (16), `kGenericValueBits` (8) and `kPageChannelBits` (5, 32 to a page). The
serializers, `send_command`, `apply_command`, `fit_channels` and `bus_limits()` read them, and GDScript reads
`Sim.bus_limits()` rather than typing any of them. `many_devices` holds `Sim.Channel` against the library's count.

**The named channels stay what they were, below 32, on the short form.** A command's channel is a form bit and then
five bits or sixteen (`command_channel_bits`), so a craft working only named channels pays one bit more than before.
`kChannelCount` is still 17 and `Fitted channel[kChannelCount]` still a fixed table; nothing about gear, flaps or the
sweep changed.

**GENERIC CHANNELS start at 32.** `Sim.fit_channels(kind, [{channel, name, range, audience}])` fits a kind with any
number of them, `audience` "crew" or "craft". The table is the process's, not a world's, because every CockpitWorld in
a process -- the server, a suite's clients, `Sim`'s shape-only world that `craft_schema` is asked through -- has to
agree; it is sorted and binary-searched, so 512 channels are 512 entries (48 bytes each, 24,624 in all) and not a
65,536-slot array. It is refused while any world is started, and a malformed entry is refused with a warning while the
rest are fitted. `craft_schema` lists them after the named ones with `generic: true`, so the router, the builder's
channel names and `VehicleView.channel_range` see them with no other change. **Any seat may command one** -- none is
physical.

**The values live on `BusPage` entities, 32 to a page**, as a room's endpoints do. A CRAFT page (`client ==
kNoOccupant`) goes to everybody at its craft's own sphere priority, exactly as `CraftSystems` reaches a spectator in
another craft. A CREW page is one crew member's copy, sent to that client alone by the same zero-for-everybody-else decider that sends a
cabin, mirrored from the server's `crew_values_` in `publish_cabins` and retired with the member. Both snap. **A page
exists only once a value on it is not zero**, and its record is sparse -- a 32-bit mask and the values that are set --
so a panel of switches all off costs the wire nothing, and a page with one switch on is 59 bits and the craft reference
(client 8, page 11, mask 32, the value 8) against 307 written in full. `VehicleView.channel_value` reads `bus_values(entity)` once a physics frame for a generic channel.

**Measured in `tests/many_devices.gd`** -- a server, a joiner in the F-14's back seat and a spectator in a pod, over the
in-process link, 512 generic channels (even crew, odd craft) and channel 65,535, driven through `VehicleControl` ->
`DeviceSignalRouter.route` -> `Sim.send_command`:

| | quiet | draining 512 commands |
|---|---|---|
| bytes a tick down to the joiner (crew member) | 56.0 | 106.8 |
| bytes a tick down to the spectator | 56.0 | 76.4 |
| bytes a tick up from the joiner | 12.0 | 14.9 |
| server tick | 0.020 ms | 0.028 ms |

After the panel: 17 craft pages, 16 crew truth pages and 16 pages for each of the two crew, 3,256 bytes of page data in
all. All 513 land on the server and the joiner, every craft channel and not one crew channel on the spectator, and a
crew member who changes craft is left with no crew channel and every craft one. Before and after, on the rest of the
wire: a full input frame 333 -> 342 bits, the worst delta frame 404 -> 424 (it now carries a wide channel), steady
flight at link 16 71.2 -> 72.2 bytes a tick up (`input_window`); `bulk_load` 13.1 -> 13.2 kB/s up a client and
247.6 kB/s down unchanged; `wire_budget` unchanged at a peak of 1,611 bytes a tick.

**The command queue is a panel, 512, and still one command at a time on the frames** (`kCommandQueueCap`; it was 16,
every channel the bus had). Each command rides `kCommandRideSeconds`, so ONE CLIENT PUTS THROUGH ABOUT THIRTY COMMANDS A
SECOND: a whole 512-channel preset takes seventeen seconds to land. That ride is the burst-loss fix above and was not
traded; a preset that must land at once wants a different message, not a shorter ride.

**Not done, and where it would go.** No craft is fitted with generic channels yet: `fit_channels` is called by the
suite, and a craft package does not declare them (`CraftPackage` says native code stays authoritative until a
pre-session registry installs a package identically on every peer -- that registry is where a package's generic
channels belong). Seats are still four (`kMaxSeats`, two bits), turrets three, rooms two; a station holds at most 512
devices (`CraftPackage.MOST_CONTROLS`), which is devices and not channels. A generic value is eight bits.

`tests/shared_controls.gd` is the suite: the desk's keys, and a hand closed on a switch and a wheel, placed again on
every frame because a forced hand is a WORLD pose and the aeroplane is doing 58 m/s. Placed once, the first run's hand
was left behind in the sky and wound a trim wheel to its stop.

**Trim cannot be sent to exactly neutral**: the server folds the byte as `v / 127.5 - 1`, so 128 is +0.0039 of trim and
+0.0024 of pitch through `kTrimAuthority`. Left, because fixing it is a simulation change in every build.

### The stick trims the craft, and every wheel shows it

**A thumb on the column winds the CRAFT'S trim, not a wheel.** `PilotRig._wind_the_trim` starts from
`VehicleView.shown_value(TRIM)`, keeps the fraction while the mini joystick is held (a channel counts whole notches
and a frame of winding is a small part of one), and proposes every whole notch; every trim wheel aboard draws what the
craft decided. Pulled back is nose up. Pressing the joystick in proposes `TrimWheel.neutral(range)`, which is also
what the wheel's own binding sends -- the stick used to type 128 beside it.

It did nothing before, measured: the rig wound `_reading("trim", null)`, which finds only a trim wheel a hand is
HOLDING, and then skipped a held wheel, so sixty frames of the joystick held back left the craft at 128. And the desk
threw away what a forced finger put in `trim_rate`, so no suite could push it. After: 128 -> 151 over 60 frames against
`TRIM_RATE` x 255 x 0.5 s = 22.9, every wheel at 151 six frames later, and the click back to 128 with every wheel.

**Only a column that may trim is bound to.** `CockpitStation.trim_range_of(kind)` is the one question the wheel and the
column both ask -- the trim channel's range, on a craft whose trim works a wing or a rotor -- and
`_fit_the_trim_to_the_column` gives a stick or yoke that range only at a seat that flies, because the server takes a
physical channel from no other. At 0 `FlightStick.column_bindings` leaves the mini joystick and its click out, and they
fall through to the empty hand. The pod's stick used to take the thumbstick for "wind the trim" on a craft with no trim
channel: held, it now says "rudder and wind the throttle", exactly what an empty right hand says.

### A control being placed goes down on a grid, and is furniture while it is carried

**Snap to grid, in the builder, on the hand carrying the control.** Asked for on 2026-09-13. While placing, the hand
that holds a control has its joystick's click as snap on or off and its joystick's flick as the step: up coarser, down
finer, and held over it repeats after 0.4 s every 0.25 s, counted on physics frames (`PilotRig._step_the_grid`).
Rotation walks 5 to 90 degrees in fives (default 15); position walks 0.5, 1, 2, 5 and 10 cm (default 1 cm) on x, y and z
separately. Which of the two the click and flick work on is `PlacingGrid.stick_adjusts`.

**One grid, the pilot's, kept.** `PlacingGrid` is a pure object -- `snapped(transform)` is arithmetic with no scene in
it -- held by the rig, never sent, written to `user://cockpits/snap.json` on every change and read when a rig is made.
Every value read takes its own default at its own line, a rotation step that is not a multiple of five is put on one
and said, and a position step not in the list goes back to a centimetre and is said.

**In the station's frame, in the order the file is written in.** The grid is applied to the control's transform right
after `offer_hand_to_place`, every frame the hand holds it, from the hand's own pose -- so rounding never accumulates --
and in the frame `CockpitLayout` writes "at" and "facing" in. Position is rounded relative to the station's origin, the
seat anchor on the play-space floor. Rotation is rounded per Euler axis in YXZ, which is `Node3D.rotation`'s default
order and so the order "facing" is saved in. Every position step divides a millimetre, so `_triple`'s rounding keeps a
saved control on its grid. The grip ends up to half a step off the hand; that is what a grid is.

**A snapped facing reloads to the same basis.** Written to a thousandth of a degree and read back through `deg_to_rad`,
every snapped facing across pitch -90 to 90 and yaw and roll round the circle comes back within 1e-4
(`a_snapped_facing_written_and_read_back_is_the_same_basis_to_1e-4`). Near a pitch of 90 yaw and roll share an axis, so
two triples can name one basis; the check holds the BASIS, which is what a lever is drawn from.

**And it closed a leak.** The held control's own table is laid under the builder's, and the builder's said nothing about
the joystick -- so a stick being carried across the console wound the aeroplane's trim under a resting thumb (128 -> 151
over 60 frames) and re-centred it on a click (200 -> 128), while it was furniture. The grid's bindings take both inputs
on the carrying hand. `tests/snap.gd`, in a real plane, because a bench has no craft to propose trim to and a check
there would pass over it.

### The snap board rides the working hand, is worked from the other, and can be moved

**On the hand doing the work** ("similar to an iPad but attached to the controller that is working with the device").
The trigger of the hand carrying a control puts `SnapBoard` up on that hand, and again puts it away; up on the other
hand already, it moves across. It is a `TouchPanel` with a `SnapPage` -- rotation snap and its step, position snap, its
step and its axes, which of the two the joystick works, and RESET POSITION -- sized and coloured from `BoardStyle`, at
the clipboard's pixel density. The page announces and the rig decides, so the joystick and the board can never show two
different grids. It goes away with the builder.

**Worked from the other hand.** `PilotRig._point_a_hand` (it was `_point_the_right_hand`) asks which hand points: the
clipboard is held left and worked right, and wins while it is up; otherwise a snap board is worked from the hand it is
NOT on; otherwise the right, for the panels a level hands over. The beam moves to that hand. While the board is up its
bindings take the pointing hand's trigger away from everything under them, so a free hand carrying a lever of its own
cannot open a second board with the same pull. The beam aims whichever glass its ray crosses first -- the board, or a
screen beyond it -- and keeps the one press state for all of them: see `HandBeam`.

**Moved by its edge** ("the menu that is on the device might need to be moved in a crowded cockpit"). The other hand
squeezes the band round the glass -- never the glass, which is the pointer's -- and the board follows it in the working
hand's frame, the subtraction `offer_hand_to_place` does. `_work_the_controls` offers a free hand to the board's edge
BEFORE any control, and a hand the board takes is offered to nothing else that frame, so a crew button standing 3 cm
behind the edge stays exactly where it is. Squeeze and hold only; no tap-to-latch for furniture. A drag stops
`PlacingGrid.BOARD_REACH` (0.45 m) from the working hand, so it cannot be left behind the seat.

**One offset, kept, mirrored.** Where it was put down is `PlacingGrid.board_at` and `board_facing`, in the right hand's
frame, written with the grid; the left hand gets the mirror image (x, yaw and roll negated). Set on the right, kept, and
reopened on the left, it lands on the mirror to 1e-4 -- checked as a matrix reflection, not as negated angles, so a wrong
sign cannot agree with itself. Saved to a thousandth of a degree, for the same reason every other facing is.

**A board is born away.** A Node3D is visible from the moment it exists and `_ready` runs only when it is added, so the
first board the rig made read as already up on the hand that asked for it and the first trigger put it away before it
was ever hung on that hand. `SnapBoard._init` makes it invisible.

## THE HUD, AND THE ONE PLACE HEAD-LOCKING IS RIGHT

`ui/vehicle_hud.tscn`, carried by the rig, reparented to whichever camera is current. It
reads the vehicle's KIND, its MOVEMENT MODEL, a line on what to expect of that model,
WHICH SEAT you are in and WHAT ITS STICK DOES, and the speed. The flat status label mirrors
it, for debugging with the headset off.

The seat line matters as much as the vehicle line now that seats differ: the same stick
flies the aeroplane from the front two and swings a barrel from the back two, and finding
that out by pulling on it is not a reasonable thing to ask of anybody.

It exists because every vehicle is a box and the five models feel completely different, so
from inside one there is nothing at all to tell them apart. That is not hypothetical: a
player spawned in the pod, flew a `HOVER` model, and reported that the flight model flew
like a spaceship. It does. It is a spaceship. It was the wrong vehicle, and nothing on
screen said so.

It is the **only** thing in this project mounted on the head rather than on a seat, and
that is deliberate both ways. Everything a pilot can see of the cockpit is seat-parented,
because that is what makes it steady at speed. The HUD cannot be: a panel bolted into the
cockpit is in front of your face only if the play space origin happens to sit under the
chair, which nothing here can know. It draws with depth testing off, so the hull it is
inside cannot hide it.

**Down until you put it up (2026-09-14).** Asked for as "turn off the hud that shows up connected to the head (we need a
toggle in the ipad to turn it back on)". `PilotRig._hud_on` starts false on every start, on a headset and a desk alike,
and the clipboard's HUD switch -- on every tab, beside BUTTON LABELS -- announces `chose_hud`; `PilotRig.show_the_hud`
decides, and hands the answer back to the switch through `Clipboard.show_hud`. Yours alone: nothing is sent. **Down is
hidden and unwritten**: `_update_hud` and the frame-step check in `_process` return first, so nothing asks the simulation
for the vehicle or rebuilds the panel's text. Hiding it and writing it anyway was the other way; it is a read of the
vehicle's state every tick for a panel nobody can see. Put up again, the frame-step check starts afresh, so the distance
flown while it was down is not a red flash. `MarshalRig` still hides its own in `_ready`, as before.

The fourth switch had no room in the row of three (BUTTON LABELS already asked 318 of its 324 px), so the switches are two
rows of two: LABELS and FINE SCENERY, BUTTON LABELS and HUD, each in the middle of its half. That cost every page 67 px;
BUILD keeps 95 px spare, 54 with the fire debrief (the budget under "AN AUDIO TAB").

**How it was proved.** `tests/clipboard.gd`, on a rig with its board up, by the right hand's beam and trigger: the HUD is
hidden, `PilotRig.hud_writes` does not move over six physics ticks and the switch is off; the beam on HUD puts it up and
it is written (5 writes in 6 ticks); the beam again puts it away and it is written 0 times in 6 ticks. `tests/smoke.gd`
asks a rig that has flown a whole world whether the HUD is down and was never written, then puts it up with
`show_the_hud` and reads it as it always did ("POD · hover", seat 1 of 4). RED with `_hud_on` starting true: "HUD visible
true, written 5 times in 6 ticks", and in smoke "visible true, up true, written 5363 times". RED with the `_hud_on` guard
taken out of `_update_hud`: "HUD visible false, written 5 times in 6 ticks" and "written 6 times in 6 ticks" once put
away. The pill check counts only words that can be seen: HELP's legend scrolls under the switches, and counted whole its
hidden lines stood 0 px from LABELS' pill. Looked at, windowed on the stock editor: the board with HUD off and on, and
the world from the seat with the HUD put up.

## AND SO IS THE SOUND

This was a flight simulator with **no sound of any kind** -- not a stub, not a bus layout,
not a placeholder, zero `AudioStreamPlayer` in eighty-two scripts and no audio file in the
repository. That is not a polish item, it is a missing instrument: an engine note is how a
pilot holds a power setting without looking at anything, wind noise is how they feel speed
with their eyes on the horizon, and a gun with no report does not read as a gun.

`objects/vehicles/vehicle_sound.gd` generates it a sample at a time, which is the same
budget every surface in this game is drawn on and for a related reason. There are no
textures here because a headset is fill-rate bound; there are no audio files because an
`AudioStreamGenerator` is a few multiply-adds a sample with no file, no import step and no
memory -- and because every craft can then be a different animal from one table.

**One player per craft and not two.** The engine and the wind are summed into a single
generator: two players would be two buffers to keep fed, two 3D attenuations computed for one
aeroplane, and a pan that could disagree with itself.

**THE MAPPING IS A PURE STATIC AND THE SYNTHESIS IS NOT.** `VehicleSound.tone_for(base_hz,
throttle, airspeed)` is three numbers in and three out with no state anywhere, so a headless
suite walks it across its whole range: the note rises with power and so does the level (an
engine that only got LOUDER is a throttle with no feel), both have a floor because an idling
engine is not a silent one, and the wind is the SQUARE of airspeed because it is the same
term the drag is -- a rush that grew linearly would be as loud taxiing as at half speed.

**The note comes off the SHAPE TABLE and not out of a table here.** A bigger machine has a
bigger engine and a lower note, as a power of the mass, so `base_note` asks
`Sim.geometry_of`: the 780 kg light aeroplane sits at 100 Hz and the heaviest craft in the
table, the ten-thousand-tonne carrier, on the 22 Hz floor -- under that is not a note, it is a
vibration nothing can reproduce. The power is worked out from the table (`_note_power`, about
0.16): the segway 142.6 Hz, the 737 and the tank near 50, the 747 near 39. It was the cube
root, which reached the floor at 73 t, so once lane/liners made the 747 280 t (2026-09-19) it,
the train, the pirate ship and every warship shared one 22 Hz note. `feel` walks every kind by
mass and wants each heavier one strictly lower. Retune a craft's mass in the C++ and its voice
retunes with it. This is the same rule the drawn geometry already follows.

**A craft gets a voice when somebody sits in it**, built and freed in `VehicleView.man`
beside the stations and for the same measured reason: a hundred and forty machines nobody is
in would be a hundred and forty ring buffers filled for nobody.

**A craft with nothing running is silent.** `Model::Fixed` answers for the control tower; the
glider is NAMED, because a glider is an aeroplane with the thrust set to zero and that number
is in the simulation's handling table, which is not published to this side of the line. Every
kind including the tower carries a throttle channel on the bus, so `craft_schema` cannot be
asked.

**The gun is a one-shot and that is a decision.** Feeding a hundred and fifty milliseconds of
crack into a ring buffer means per-frame bookkeeping for every round in the air, and a 25 mm
cannon puts thirty a second up. `VehicleSound.report` builds an `AudioStreamWAV` in code --
filtered noise under a sharp attack and an exponential tail, which is what a gun report
physically is -- one per calibre, kept. `ShotYard` fires it at the MUZZLE when a round is
born, which is the one edge there is, and water is silent because six tonnes leaving a tanker
is not a gun.

**And it is silent where there is nobody to hear it, and muted unless asked.** Headless
has no audio device, so no players are built at all -- not built and muted. Twenty-four
suites run in this project and none of them should be filling a ring buffer. A windowed run
builds its players on the `Game` bus, and that bus starts MUTED unless `--audio` is on the
command line (either side of the bare `--`): nearly every run here is an agent looking at a
window, and sound is opt-in for that reason. `PilotHeadphones.asked_for()` is the rule
(`VehicleSound.asked_for` reads it) and `feel` checks it. Until 2026-09-13 the flag decided
whether players were BUILT, which could not be turned on in flight; see "A VOICE ON THE RADIO,
AND BOTH EARS OFF AT START". The same word does the same job in racer and topdowntest.

Measured by running it: a windowed run shows one uncorked PipeWire sink-input named
`cockpit`. Whether any of it SOUNDS like an aeroplane is a question for a pair of ears and
nothing here pretends otherwise.

**What is not here:** one report per round (see the haptics note -- it wants a shooter field
on `ShotState`), a stall buffet, rotor slap, tyre roar, a touchdown, and Doppler. Doppler
wants the simulation's velocity handed in: a node moved by `Sim.vehicle_transform` every
frame is a node that teleports rather than one that travels, so `doppler_tracking` has
nothing true to read.

### MUSIC IS SESSION STATE; THE TRACKS ARE EXTERNAL DATA

Music files are never networked and never imported into the PCK. `RecordShelf` scans the first
existing `--music=DIR`, `music/` beside the executable, or the editor-only `res://music` fallback;
`cockpit/music/.gdignore` keeps local tracks out of imports and exports. `tools/export.ps1` copies
`.ogg` files beside the executable. The filename stem is the wire id.

The host owns `{track, started_frame, volume_from, volume_to, fade_from_frame, fade_frames, music_n}`.
`music` is repeated until `music_heard`, and the same fields ride the level hello so a late joiner
starts mid-track. `MusicBox` computes seek and dB from `Sim.client.timing().estimated_server_frame`;
a fade is one small state change, never a stream of volume packets. AUDIO's MUSIC switch mutes only
this machine. `tests/music_peers.gd` is the real-ENet gate; `record_shelf`, `music_page` and
`music_shot` cover the catalog, real button path and picture. Every non-XR launch uses both
`--xr-mode off` and `--desktop-only`; the second flag prevents the project startup path from
probing the OpenXR runtime even when XR rendering is disabled.

Measured 2026-09-16: the Windows PCK was 4,282,200 bytes with external fixture Oggs beside the exe;
the exported `--music-list` found `test_tone`. Godot's Dummy audio driver advanced the runtime Ogg
past 0.1 seconds, so the headless catalog gate observes real playback. `--voice-test` on that export
printed an empty model folder, settling item 21's export hypothesis: its model data must be copied.

### A VOICE ON THE RADIO, AND BOTH EARS OFF AT START

Asked for on 2026-09-13: "look at the kokoro-gd component and add it to this project, then we'll need an audio panel
in the ipad (default to all off), one for game sound another for using kokoro to play audio."

`autoload/headphones.gd` (`Headphones`, class `PilotHeadphones`) is what the pilot hears, and it has the shape `Finish`
has: a choice is announced to it (`choose_game_sound`, `choose_voice`), it decides, and it says what it decided on
`changed`. Two buses, made in code because there is no bus layout file: `Game`, which every player `VehicleSound`
builds is on, and `Radio`, through `RadioBus`'s band-pass and drive. GAME SOUND mutes `Game` and nothing else, and
`--audio` says where it starts. **Players are now built wherever there is an audio device and the MUTE is the
switch**: when `--audio` decided whether they were BUILT, a craft somebody sat in with the sound off would have had
nothing to unmute. Headless still builds none. Both start off every run, and nothing is remembered between runs.

**The voice is kokoro-gd** (`../../kokoro-gd/`), Kokoro-82M text-to-speech in C++ over ONNX Runtime, built by
`../../kokoro-gd/scripts/build.ps1` (and `-Double`) and copied into `addons/kokoro_gd/bin`: one library per precision and
`onnxruntime.dll`. Four decisions, each ruling out the obvious way:

- **The libraries are NOT committed, unlike ashiato's.** They are ignored in `bin/`; only the `.gdextension`, the
  `.gdignore` and `radio_bus.gd` are in git. VOICE cannot work from a fresh clone anyway without the 325 MB model,
  which a script fetches, so committing 17 MB of third-party binary (again at every ONNX Runtime release, and with
  no Linux build to go beside it) would buy nothing. A clone therefore has no library, and VOICE says what is missing
  and the command that fixes it: "No voice library (...): run kokoro-gd/scripts/build.ps1", "No voice model at ...:
  run kokoro-gd/scripts/fetch_models.sh". Decided 2026-09-13.
- **Not an extension Godot finds by itself.** `bin/` has a `.gdignore`. A `.gdextension` the importer discovers is
  loaded at every boot, and on a machine with no library for its platform and precision Godot prints "No GDExtension
  library found for current OS and architecture" as an ERROR, which fails every suite. So
  `PilotHeadphones.library_for_this_machine` reads the entries the way Godot does (every tag a feature, most tags
  wins), and `GDExtensionManager.load_extension` is called only when that file and ONNX Runtime are both there.
- **Not an autoload scene**, which kokoro-gd's README says to add: a scene whose root is a `KokoroServer` fails to load
  where the class is absent, and would start its worker thread at boot. Nothing names a kokoro class as a type, and
  `tests/lint.gd` compiles `headphones.gd` on machines where the class does not exist.
- **The native library at boot; not the model.** A complete optional install prepares the 17 MB native library during
  initial boot because its synchronous Windows load cost 15--29 ms and made the first VOICE pull miss a 90 Hz frame.
  The model is 325 MB and remains lazy. VOICE on builds a `KokoroServer` and loads it; VOICE off clears the
  channel, stops and frees the tower's player, and frees the server. The player goes too because leaving it playing
  its channel after the server was freed leaked one object at exit, every run, with an orphan StringName `Radio`;
  a bare server or a bare channel freed alone did not (a throwaway probe, 2026-09-13). A freed server cannot restart (its shutdown flag is never reset), so each VOICE on
  builds a new one, and one still loading is freed when it finishes rather than on the spot, because freeing it joins
  the worker thread and the main thread would wait out the load.

**Where the model is:** `KOKORO_MODELS` when set, and then ONLY there, so a player who names a folder means it and a
test can name an empty one; otherwise the folder `../../kokoro-gd/scripts/fetch_models.sh` writes, beside this game, and
then `user://kokoro`. A folder counts only with `kokoro_fp32.onnx`, `voices.bin` and `lexicon.txt` all in it, checked
before the extension is asked, so a missing file is a sentence rather than an error from inside the library.

**What it says:** the tower answers a radio check when VOICE comes on, in `bm_george`: "Cockpit, tower, reading you
five by five." Every word is in the lexicon, so it raises no pronunciation warning. On the double editor the fp32 model
loaded in 2.1 s cold and 0.8 s warm, and kokoro's own CLI spoke the line as 2.72 s of audio in 346 ms of compute.

**How it was proved:** `tests/headphones.gd` -- both ears off at start with the game bus muted; no library and no
model, each leaving its sentence and no error; the radio check reaching the channel without a synthesis failure; VOICE
off putting the tower's radio away and freeing the server; VOICE on again speaking on a new server and channel; and
VOICE off while loading. Each was shown RED by breaking the line it guards. This said "headless cannot HEAR", after
kokoro-gd's DESIGN.md; on 4.7.2 here `--headless` does run the mix at real time, and kokoro raises its start and finish
for every line (see "THE FREQUENCY TALKS", 2026-09-14).

**And since 2026-09-13, as speech, with the switch.** "It's very important that the speech features are testable."
The suite's first section says the model and worker are NOT in the process after boot and 60 frames with VOICE off
(no server and no radio channel); its last pulls the
AUDIO tab's VOICE switch with the right hand's beam, as `tests/clipboard.gd` pulls GAME SOUND, and reads kokoro-gd's
`RadioChannel.get_transmitted()` -- every sample the worker put on the channel, counted whether or not anything mixed it,
which is how a headless run sees sound. Measured on the double editor: runtime `addons\kokoro_gd\bin\onnxruntime.dll`
1.30.0 (`KokoroServer.get_runtime()`), the radio check 65,392 frames = 2.72 s at a peak of 0.505, and ten more pulls off
and on each loading again in 0.7 s and speaking the same 2.72 s on the last. RED by loading the extension from
`Headphones._ready`, by cutting the rig's `chose_voice` connection, and by a radio check of "Roger." (0.58 s). Out loud,
on the stock editor windowed with `--audio` (WASAPI, 96 kHz), the line played for 2.73 s between the server's
`utterance_started` and `utterance_finished`, which the audio thread raises.

How to test speech:

    powershell -ExecutionPolicy Bypass -File tests\run_all.ps1 -Only headphones
    # needs addons/kokoro_gd/bin (../../kokoro-gd/scripts/build.ps1, and -Double) and ../../kokoro-gd/models
    # (scripts/fetch_models.sh); without either the speech sections SKIP and say which
    Godot_v4.7.2-stable_win64.exe --path cockpit -- --audio
    # windowed, stock editor: the clipboard's AUDIO tab, VOICE, and the tower answers

**A fresh clone was proved by renaming `bin` away:** the import, the headphones suite (two sections run, three skipped
with the reason) and a 900-frame headless boot of the game printed no engine error, and the project's extension list
never named kokoro, with `bin` away or back.

**One line is not guarded by a test:** `RadioChannel.clear()` on VOICE off, which makes kokoro's worker abandon chunks
it is still synthesising. `is_transmitting` cannot show it: it reads a squelch flag the audio thread closes at the end
of a tail, and a stopped player is never mixed again, so it stays true with or without `clear()` (measured 2026-09-13).
Deleting `clear()` leaves the suite green; that is written here rather than hidden behind a check that cannot fail.

### THE FREQUENCY TALKS

Asked for on 2026-09-13: "for voice, if it's available, just have the planes and tower occasionally (once per 15
seconds) use a different voice to make some sort of radio transmission."

world/tower_frequency.gd (retired ambient filler) (`TowerFrequency`, built by the sky level) puts a line on the tower's radio about every
`RadioTuning.INTERVAL` (15) wall seconds, give or take `JITTER` (2). The lines come from `world/radio_phrases.gd`
(`RadioPhrases`), a catalogue of exchanges in which a line names the reply the other side gives in the next slot,
filled from the aircraft that speaks. `world/radio_tuning.gd` (`RadioTuning`) holds the voices, the callsign words,
the interval, the range, the length caps and the thread count.

- **Only with a voice.** With VOICE off, or still loading, it says nothing and asks nothing.
- **It proposes; the headphones decide.** `Headphones.on_air()` is true from the moment a line is queued until kokoro
  reports that the mix played its last sample (`utterance_finished`) or that the line could not be spoken. Chatter
  waits for it. The radio check is queued at NORMAL priority and chatter at LOW, on the one channel.
  `RadioTuning.GIVE_UP` (10 s) lets go of a line that is neither, and nothing tests it.
- **Who.** The tower speaks in `bm_george`. The aircraft are anything with a flying movement model
  (`Sim.geometry_of(kind)["model_name"]`), moving faster than `FLYING_SPEED`, with every seat empty, within
  `RADIO_RANGE` (15 km) of the camera this machine draws from. With nobody in range, the tower talks to all stations.
  Each aircraft speaks in one of am_michael, bf_emma, bm_lewis, af_bella, am_adam and af_sarah, never the tower's.
  The pick is a hash of the whole entity id, not a remainder of it: an id is `(version << 32) | index` in ashiato, so
  a remainder walks neighbouring slots through the pool in order. The suite's posed aircraft were 4294967421 and
  4294967422.
- **What.** A callsign is a kind word plus two digits from the same hash ("Airliner 55"). A heading or a carrier
  bearing is to the nearest ten, and runway 36 comes from `Terrain.RUNWAY_BEARING`. All of those are left as digits
  for kokoro to read the radio way. Altitudes are composed in words, "two thousand five hundred feet" below 6,000 ft
  and "flight level 060" above, and a carrier distance is "three miles". A phrase with a slot the sky cannot fill is
  not said. Chatter is read at speed 1.5; the radio check stays at 1.3.
- **Per machine.** Nothing is on the wire.

**A headless run mixes.** kokoro-gd's DESIGN.md said Godot's Dummy driver never pumps the audio thread, so the design
expected a 4 s ring that never drained and a worker stopped for good by the second line. It carried a rule calling a
line over once its frames had had time to play, and cleared the ring. On 4.7.2 here, `--headless` mixed at real time:
kokoro reported every line started and finished, the radio check's 2.72 s was on air from +65 ms to +2,775 ms, and the
rule never fired in thirteen lines. It was taken out, and DESIGN.md and `tests/headphones.gd` are corrected.

**What the first runs found (2026-09-14):**
- `run_all.ps1 -Only chatter` failed lint on seven scripts, because the three new classes were not in the class cache.
  `-Only` does not import, as the missile section above says. One `--headless --import --path cockpit` fixed it, with
  the user's editor open on the project.
- The word cap counted a bare "," or "." as a word once the slots were cut out, so it read three ten-word lines as
  twelve or thirteen and left them out.
- One of those was `roger_heading`, the reply to `heading`, which stayed in. The frequency, due that reply, looked it
  up and got a script error once a slot, 173 of them in under a minute, and never cleared the answer.
  `RadioPhrases.usable` now keeps leaving out any phrase whose reply was left out, and `TowerFrequency` drops a due
  answer it cannot find.
- A tanker asked for at 2,438.4 m was found at 2,000.04 m, so the simulation puts nothing above two kilometres. The
  suite's flight-level craft is at 1,950 m.
- The suite's first overlap check timed a line from when it NOTICED the frames, +405 ms for a line the mix started at
  +65 ms, so every correctly spaced line read as early. It reads kokoro's own start and finish now.
- Its first voice-off window was three seconds. The seam that shortens the interval is set after the level has run,
  so a frequency with its voice gates cut had already scheduled its first line fifteen seconds out, and both the
  voice-off and the loading checks passed with every gate cut. The window is now a whole real slot plus a second.

**How it was proved:** tests/chatter.gd (retired with ambient filler), 26 checks, green in 43.2 s with the real model. The player is put in a
light aeroplane flying at 79 m/s through `PilotRig.ask_for_kind`, so only its crew keeps it off the frequency. That
run heard the radio check (2.72 s), then six lines:
- "Tower, Viper 14, carrier in sight." (am_adam, 1.55 s)
- "Viper 14, carrier bearing 190, five miles." (bm_george, 3.25 s)
- "All stations, tower, runway 36 in use." (bm_george, 2.63 s)
- "Tower, Viper 73, passing one thousand feet." (af_bella, 1.84 s)
- "Viper 73, roger, report leaving the zone." (bm_george, 2.60 s)
- "Wilco, Viper 73." (af_bella, 1.02 s)

Each line was queued 4 to 6 ms after the previous one's finish, and on air within 0.15 s of its published length.

Checks were shown RED by breaks in what they guard. A python script applied each set, ran the suite and restored
every file byte for byte, and the `git diff` hash was the same after every set:
- set A: slot validation cut, a too-long phrase added, `wilco` given to the tower, the compass flipped, the transition
  at 9,000 ft, the range filter cut, the all-stations phrases removed, and the voice picked by remainder again.
  Every catalogue, heading, height, flight-level, runway, range, all-stations and voice-pick check went red.
- set B1: the `on_air` wait cut, the tower speaking in aircraft voices, a random voice per line, and a 1 s cap. The
  overlap, on-air length, cap, tower voice and kept-voice checks went red.
- set B2: the frequency's voice gate and `say`'s ON gate cut, and the server kept on VOICE off. The loading check and
  the VOICE-off-at-the-end check went red.
- set C: the carrier bearing reversed, `fill` upper-casing its slots, and a crewed craft counted as traffic. The
  carrier, phrase-fill and own-craft checks went red. The own-craft check had passed with the crew test cut until
  the player was put in a flying aeroplane: the craft the suite starts in is not flying.
- set C2: the sky builds no frequency. That check went red.

**Not shown RED, and why:**
- `there_is_a_carrier_to_take_bearings_on` and `and_then_the_voice_is_on` are the preconditions the checks after
  them stand on.
- `at_least_3_lines_went_out` only counts.
- `the_tower_and_an_aircraft_both_spoke` is a presence check that no set broke: nothing above silences one side alone.
- `with_voice_off_the_frequency_says_nothing` never fails, because with VOICE off there is no kokoro server, so
  `say` refuses below any gate a break can reach.

`tests/headphones.gd` still passes (19.8 s).

**A line after a silence was clipped, and the suite above could not see it** (found 2026-09-13, fixed 2026-09-14).
Windowed, with fifteen seconds between lines, every chatter line after the radio check was "on air" for a fraction of
itself: on the stock editor, WASAPI, four ONNX threads, "Tower, Viper 20, heading 350." was 0.46 s on air of 1.73 s
published, "Viper 20, roger, maintain two thousand feet." 0.60 of 2.89, "Wilco, Viper 20." 0.24 of 0.97, while the radio
check was 2.71 of 2.72. The cause was in kokoro-gd's mix: a cue marker is stamped in PUBLISHED samples, and the mix
compared it with every frame it had MIXED, silence included, so after any gap both of a line's cues were already
"reached" and `utterance_finished` came when synthesis ended. `Headphones.on_air` cleared early and the tail and carrier
close landed mid-sentence. This suite's lines run back to back, 4 to 6 ms apart, so the drift stayed under 0.15 s.

Fixing that uncovered its mirror: a line's start cue had been pushed before inference, and the old count's early end
had hidden it. On the first fixed library the back-to-back lines ran long instead, 2.72 s published and 3.35 s on air,
which is the synthesis time with the carrier open. Both are fixed in kokoro-gd (see its DESIGN.md, "Cues follow published
samples"): a start fires on the block that takes its line's first sample, and an end on the block that takes its last.

`a_line_after_a_silence_is_on_air_as_long_as_it_was_spoken` is the check. It sets the frequency's gap to the longest line
(`RadioTuning.MOST_SECONDS`) plus `SILENCE_SECONDS` (3), takes two lines, and times the second from kokoro's start to its
finish against the samples the channel published for it. The silence before it is measured without the cues, from the
queue times and the first line's published length. RED on the old library: "after 5.75 s of silence, 'Tower, Rescue 81,
heading 200.' in af_sarah: 1.56 s published, 0.56 s on air". GREEN on the fixed one: "after 4.38 s of silence, 'All
stations, tower, departures and arrivals runway 36.': 3.16 s published, 3.16 s on air". The back-to-back check went RED on
the half-fixed library ("line 0: 2.72 s published, 3.35 s on air") and is green again; the radio check now starts +678 ms
after it is queued, which is its synthesis, and is on air 2.69 s.

How to test the frequency:

    powershell -ExecutionPolicy Bypass -File tests\run_all.ps1 -Only chatter
    # needs the library and the model, as the headphones suite does; after adding a class, import first

### THE VOICE HOLDS NO FRAME

Asked for on 2026-09-14: "get it working in its own thread so it doesn't block anything." It did most of that already.
Three things did not, and they were found by timing frames rather than by reading the code.

**Which thread does what**, from the code:
- **Main thread:**
  - `TowerFrequency._process` picks who speaks and fills the phrase.
  - `Headphones.say` calls `RadioChannel.queue`, which calls `KokoroServer.enqueue`: two short locks, a copy of the text
    and a condition variable.
  - `KokoroServer._process` swaps the pending-signal queue and pops each channel's played events.
  - Initial boot calls `GDExtensionManager.load_extension`, which is synchronous and belongs before gameplay.
  - Every VOICE on instantiates a server, a channel and a player.
- **kokoro's worker, one detached thread per server:**
  - loads the lexicon, voices and ONNX session;
  - phonemises and tokenises;
  - runs the model on `RadioTuning.WORKER_THREADS` ONNX threads;
  - trims silence, keeps the phrase cache, and publishes samples and cue markers into the channel;
  - frees the model when it is told to stop.
- **Godot's audio thread:** `RadioChannelPlayback` mixes from a lock-free ring. Its cues, click, squelch and tail are
  in C++, and resampling from 24 kHz is Godot's `AudioStreamPlaybackResampled`.

**What held the main thread, and where it went** (kokoro-gd 4ba953e, its DESIGN.md has the detail). Measured headless on the
double editor, on the real sky, by the original tests/voice_thread.gd and a throwaway probe. On the library before:
- **VOICE off mid-line** held one frame for 393 to 545 ms. Freeing the server joined its worker, which finished inference
  first.
- **VOICE off when idle** held 72 to 80 ms, freeing the ONNX session.
- **VOICE on** took 71 to 140 ms. 33 to 38 ms of it was `ClassDB.instantiate("KokoroServer")` building ONNX Runtime's `Env`
  on this thread, and the first `Env` of a process is the dear one.

The worker now owns everything it touches in a shared `Core` and is detached. Stopping returns at once, and the model
is freed on the worker. The `Env` is built in `load()`. The extension waits for live workers when it is uninitialised,
so none is inside the library at exit.

After the worker change, each event against the frames just before it, median of three: the first VOICE on 9.5 ms (the
library load was 4.0 to 5.7 ms of that), the load +6.0 ms, VOICE off mid-line +0.7 ms, VOICE off idle +8.3 ms, eight lines
going out +3.9 ms, and a queued line 5 µs (102 µs at worst). Instantiating the server fell to 41 to 65 µs and freeing
it mid-line to 80 to 183 µs. Headphones' ten VOICE toggles leave nothing leaked or printed at exit.

**How the suite judges it, and the two versions that were wrong.** An event is the worst of `EVENT_FRAMES` (4) frames
from the one it happened in, and its pair is as many frames just before it with nothing done. A check fails when the
median of event-minus-pair over three throws is over one 90 Hz frame. The first VOICE on is judged by its own call
time over the GAME SOUND switch's, within two frames: one for the library load and one for the rest.
- **A 1.5 s window after each event against the worst VOICE-off frame:** a single 190 ms frame from another lane failed a
  library that had measured 19 ms.
- **Four frames against a VOICE-off p99 taken once at the start:** a C++ build in another lane started after the
  baseline, and every event read 85 to 200 ms against a 25 ms bound.
- **A median over all six VOICE on calls:** the blocking library passed it, because only the first of a process was
  dear.
- **The load's first pair** reached back over the previous VOICE off's 390 ms frame, and read every load hundreds of
  milliseconds under it. It is now 140 fresh VOICE-off frames (`LOAD_PAIR_FRAMES`).

**RED:** the blocking library failed the first VOICE on (70.8 ms, 68.6 over GAME SOUND), off mid-line (+393 ms) and off
idle (+72 ms). No library ever held the load, a line or a queue, so those three were broken on purpose, in one run,
and restored byte for byte. A 100 ms stall in `Headphones._process` while loading read +105 ms; 50 ms in
`TowerFrequency._say_something` read +55 ms per line; and 2 ms in `Headphones.say` read 2,547 µs against 1,000.

    powershell -ExecutionPolicy Bypass -File tests\run_all.ps1 -Only voice_thread
    # needs the library and the model; about 18 s here; judge it on a machine that is not also compiling if it fails

**The gate follows the current host-generated clip path again (2026-09-17).** The periodic `TowerFrequency` was retired
and took its old harness with it, leaving first activation unguarded. The restored suite measures the library activation,
every frame of model loading, first capture-bus construction, shutdown during capture, an enable-render-disable-enable
cycle, and idle shutdown. It also found a lifecycle bug in the replacement path: VOICE off cleared the playback channel
but left `RadioCapture` and its channel bound to the server being freed, so the next enable could queue into the stopped
worker. `_put_the_render_away` now clears and releases that whole path with the server.

Measured on the double editor with the actual fp32 model: first activation 6.24 ms against a 1.93 ms ordinary switch,
its frame +6.31 ms; the 0.7 s model load added 0 us at p99 to the main loop; first host capture setup and queue 3.00 ms;
shutdown during capture +2.67 ms; idle shutdown median +11.46 ms over its adjacent pairs. The first activation, load and
capture are each below one 90 Hz frame; idle teardown is bounded below two. The old blocking implementation's 72--80 ms
idle teardown and 393--545 ms busy teardown still fail these bounds by a wide margin.

**What the frequency costs a drawn frame**, windowed on the double editor (D3D12, RTX 5080), vsync off, a line every 15 s,
4 ONNX threads (`tests/radio_shot.gd`, 2026-09-14). Eight runs alternated VOICE off and on, PLAIN then FINE, over two
rounds, with other lanes' editors open. Two runs landed on the double lane's SCons build of the editor, at 100% CPU, and
are left out: FINE on (median 59.8 ms, every frame over budget) and PLAIN off (median 35.4 ms). The rest, in ms:

| Finish | VOICE | Median | p99 | Worst |
|---|---|---|---|---|
| PLAIN | off | 13.12 | 24.25 | 35.04 |
| PLAIN | on | 12.78 | 25.15 | 48.23 |
| PLAIN | on, within 1.5 s of a line | 13.77 | 29.27 | 35.07 |
| FINE | off | 13.11 | 24.24 | 38.11 |
| FINE | on | 13.71 | 23.12 | 32.86 |
| FINE | on, within 1.5 s of a line | 14.32 | 28.94 | 32.86 |

The median moves by under a millisecond, p99 near a line rises by 4 to 5 ms, and the worst frame near a line is no worse
than VOICE off's. Most frames are over 11.1 ms with VOICE off at this window size: here the budget belongs to the
renderer, and a headset's own frame times are still unmeasured (see "THE SCENERY HAS TWO FINISHES"). The same runs heard
every line on air for as long as it was published: 2.63 s of 2.63, 1.71 of 1.70, 3.04 of 3.04, 1.90 of 1.90 and 2.76 of
2.75.

**How many ONNX threads: two** (`RadioTuning.WORKER_THREADS`, which was kokoro's default of four). Measured the same way,
PLAIN, a line every 8 s. The first ladder was interleaved off 1 4 2 off 1 4 2, and other lanes' work spoiled most of it:
- cockpit-terrain's C++ build started inside the 1-thread run and covered the 4 and 2 runs (66% CPU, 8 compilers);
- the second 2-thread run shared the GPU with two other lanes' windowed probes;
- the second 4-thread run was closed after 64 s with the model loaded and nothing printed (not explained).

So the second ladder bracketed every count between two VOICE-off runs (off 1 off 4 off 2 off, 60 s each), recorded
the other lanes' windowed Godot processes at each run's start and end (CPU load cannot see the GPU), and kept a rung
only if its two brackets agreed. The pairs that held, against VOICE off, in ms:

| Threads | Where | Median | p99 near a line | Worst near a line | Queued to on air |
|---|---|---|---|---|---|
| 1 | first ladder, runs 5-6 | +0.5 | +6.6 | 41.0 (off: 32.2) | 0.46 to 1.6 s |
| 2 | second ladder, run 6 (brackets 12.26 and 12.63 median) | +0.9 | +4.7 | 28.4 (off: 29.6, 30.2) | 0.35 to 1.2 s |
| 4 | the A/B above, PLAIN | -0.3 | +5.0 | 35.1 (off: 35.0) | 0.30 to 0.52 s |

No count is separable from another beyond this machine's noise. Two halves the cores kokoro takes from a renderer that
already spends the frame, at no measured cost, and fp32 on two threads is 2.49x real time (kokoro-gd's DESIGN.md). One
had the only worst frame above its VOICE-off pair and the slowest synthesis. An earlier ladder on the stock editor
(parked 2026-09-14) had recommended one for its worst frame; that did not reproduce on the double editor. Every line in
every run, including those under the build, was on air for its published length.

### THE CRASH THAT WAS NOT THE VOICE

On 2026-09-13 `missile_cues` died silently in two full gates (21:56 and 22:28), the evening VOICE landed, and it passed
alone. The Application log said the double editor died in KERNELBASE.dll with 0xc06d007f, "a delay-loaded procedure was
not found", and System32 holds a Windows ML `onnxruntime.dll` (1.17) beside the 1.30 kokoro ships, so the voice was the
obvious suspect. **It was not, and the minidumps said so in one read.** Six of them were in
`%LOCALAPPDATA%\CrashDumps`, back to 2026-09-07, and all six decode to the same record: `dinput8.dll`'s delay-load of
`CreateInputHostForProcess` from `ext-ms-win-mininput-inputhost-l1-1-1.dll` failed, on a loader worker thread, in a process
holding 38 modules and no extension at all. Three predate kokoro. The command lines inside them were ordinary headless
suites: `missile_cues` at 22:28, `trim` on 2026-09-10 -- whichever suite happened to be starting.

**It is Windows, while loading Godot, and nothing Godot does reaches it.** A headless start of the double editor on an
empty project has dinput8, HID and inputhost loaded and that delay-load resolved within 223 ms, when the process has its
main thread, four ntdll workers and an inputhost thread and none of Godot's own; Godot's thread pool starts at about 500 ms.
dinput8 is not a static import of the exe or of anything it imports. Headless Godot creates no `JoypadSDL`
(`DisplayServerWindows` does), and no SDL hint in the environment changes the slot: `SDL_JOYSTICK_DIRECTINPUT`, `_WGI`,
`_RAWINPUT`, `_HIDAPI`, `_GAMEINPUT`, `SDL_XINPUT_ENABLED`, each and all at 0, and `SDL_JOYSTICK_THREAD=0`, which would
take a thread away, left the count at 42. Read as the slot `dinput8.dll+0x48010` out of the running child: a pointer inside
dinput8 is the stub, one into inputhost.dll means the call ran. Rejected on that evidence: the SDL hint, the first fix tried.

**What the runner does about it:** `tests/run_all.ps1` starts a suite ONCE more, printed `RETRIED`, when it exits with
exactly 0xC06D007F and printed no RESULT line; any other exit, or a second such exit, is judged as before. Shown with a
throwaway suite that quit with that code: first start RETRIED then PASS; made to do it twice, RETRIED then FAIL, runner
exit 1. The rate was not reproduced outside a gate: 300 sequential headless starts of an empty project, 0 crashes, 0 dumps.
Not in `run_all.sh`: DirectInput is Windows', and bash sees an exit code's low byte only. Not tried, because it is an
administrator's change to the machine: `MaxLoaderThreads=1` for the double editor's exe under Image File Execution Options,
which turns off the parallel loader the crash happens on.

**And it caught one for real the same night.** Gate 3 on HEAD c394007 (2026-09-13, 23:34): `trim` RETRIED "Windows killed
it while loading (exit 0xC06D007F, nothing printed)", passed on its second start, and the gate was 45/45 in 220.6 s; the
Application log gained exactly one Id-1000 event across gates 2 and 3 and ten solo `missile_cues` runs (10 of 10 PASS).
Two gates and ten runs is about a hundred and ten Godot starts for one crash, which is the rate that made it look like
a missile_cues flake.

To decode a new dump: the exception stream's first parameter points at a `DelayLoadInfo` on the faulting thread's stack,
whose `szDll` and `szProcName` point into the importing module's image, readable from the DLL on disk at the same RVA.

## A JOIN CODE, AND STEAM

    Host over Steam, on the desk's session screen

Asked for on 2026-09-14: "i want to be able to have a join code for steam players so they can join a game via a join
code rather than having to be invited or searching for a game." And then, the same day: joinable by code AND by Steam
invites and friends' profiles.

**A host makes a lobby and writes a code on it; a friend types the code and a search finds the lobby.** `JoinCode`
(`net/join_code.gd`) is the code: six of `23456789ABCDEFGHJKLMNPQRSTUVWXYZ`, shown as K7M-Q2X. There is no 0, O,
1 or I, the pairs a code read across a room loses, and there are thirty-two symbols because that divides a byte, so a
random byte lands on each one equally. 32^6 is 1.07e9 codes, and a new one clashes with one of a hundred open lobbies
with chance 9.3e-8. It is the one validator: whatever a person typed goes there first, and no directory is asked about
anything it refuses. It refuses in sentences, asserted exactly in `tests/join_code.gd`.

What the host writes on the lobby, and what a joiner checks:

| key | value | a joiner refuses when |
|---|---|---|
| `game` | `cockpit_v1` (`Net.GAME_TAG`) | it is another game's: "That is not a cockpit game." |
| `code` | the code | -- (the search filters on it) |
| `build` | public channel, exactly `alpha` | it differs: "The host is on a different build." |
| `compatibility` | `cockpit-1`, protocol version, and the stamped ashiato revision | it differs: "The host is on an incompatible alpha revision." |
| `host` | the host's Steam id | the lobby's owner is somebody else: "The host has left that game." -- and this one **only once inside**, see "What Steam will not tell a stranger" |

`build` names the public channel. `compatibility` catches a machine on a different cockpit protocol/source revision and,
where the generic AshiatoWorld API is present, a different stamped native revision. It never uses `unknown` as an identity.

**PUBLIC, and what that exposes.** Steamworks documents PUBLIC as "returned by search and visible to friends".
INVISIBLE is returned by search but not visible to friends, so a friend's profile has no Join Game. FRIENDS_ONLY "does
not show up in the lobby list", so no code could find it; racer hosts FRIENDS_ONLY, which is why this is not racer's
lobby. The cost of PUBLIC: the lobby shows in any unfiltered lobby search on App ID 480, which every Steamworks developer
shares. Every search this game makes is filtered on `game`, and on `code` as well when a code was typed. **Look for
players (2026-09-15) is the search with the code filter left off**, which needed nothing new written on a lobby and no
change of lobby type -- and there is no lobby type that would hide a game from that list and keep invites working, so a
host who hosts over Steam is listed.

**Every stage has a deadline, and the deadline is what says no.** Steam answers a request later or never. Measured
against the real backend on 2026-09-14 (`tests/steam_probe.gd`): a lobby made in 187 ms, found by its code in 186 ms,
and not found 228 ms after it was left. `Net.PATIENCE` gives each stage far more than that:

| stage | who | what it waits for | seconds | says when it runs out |
|---|---|---|---|---|
| check | host | a search for the drawn code; anything found draws again, three times | 20 | "Steam did not answer. Try again." |
| open | host | the lobby to be made | 20 | "Steam did not make a lobby in time." |
| search | joiner by code | every lobby holding the code, two at most | 20 | "Steam did not answer. Try again." |
| browse | anybody looking | every lobby of this game, `Net.MOST_LISTED` at most | 20 | "Steam did not answer. Try again." |
| enter | joiner | the lobby to let us in | 10 | "Steam did not let you into that game in time." |
| connect | joiner | the host's socket | 10 | "The host did not answer." |

The other refusals: "No game has the code K7M-Q2X. Check it with the host.", "Two games share that code; ask the host to
host again.", "That game is full (8 of 8).", and for Steam's answers at the door "That game has ended.", "That game
filled up.", "Too many tries; wait a minute." and "Steam would not let you in (response N).". A host refused says
"Steam could not make a lobby (result N)." or "Every code drawn was already in use. Try again.". A refusal takes
`Net.transport` back to "none" and is the last thing `session_message` said, which is how the desk knows to stay.

**A code is checked before a lobby is made with it, not after.** Searching for our own lobby's code would have to wait
for Steam to publish what was written on it; until then nothing would answer, and a clash would look like none.

### What Steam will not tell a stranger, and the join it broke

**`getLobbyOwner` answers 0 to a machine that is not in the lobby**, and until 2026-09-15 `Net` asked it of every
search result. The comparison was then `"0"` against a seventeen-digit Steam id, which can never match, so **every
lobby a search ever found was refused**: a typed code was told "The host has left that game." the instant its search
succeeded, and every row of the games list carried that sentence where its JOIN should have been.

**It is not the whole of what was reported, and the sentences say so.** The report was "joining by code doesn't, it
always says there is no game at that code", and "No game has the code %s. Check it with the host." is reached only when
the search comes back EMPTY -- a strictly earlier step than this bug, which needs the search to have SUCCEEDED. Either
the refusal was compressed in the retelling, or a second fault lives in the search itself that one Steam account cannot
see. Do not read the fix below as an account of that sentence.

**One Steam account could not see it, and that is the lesson.** The machine that makes a lobby is IN it, and a member
is told its owner, so `tests/steam_probe.gd` -- which had only ever searched for its own lobby -- was green against the
real backend on the day the feature shipped and stayed green. A probe that stands where the code stands is not the same
as a probe that stands where the *other machine* stands.

**App ID 480 is how one account asks about two.** Every Steamworks developer shares it, so an unfiltered worldwide
search returns fifty lobbies this machine is not in -- the exact shape of the lobby a joiner's search finds.
`tests/steam_probe.gd --strangers` asks each of them what `Net._what_is_wrong_with` asks:

| asked of fifty lobbies this machine is not in | answered |
|---|---|
| `getLobbyMemberLimit` | 50 of 50 |
| `getNumLobbyMembers` | 50 of 50 |
| `getAllLobbyData` (any data at all) | 44 of 50 |
| **`getLobbyOwner`** | **0 of 50** |

Steamworks says the same of it: "You must be a member of the lobby to access this." And a search FILTERED on a
stranger's own key handed back a lobby whose data this machine could read, so the other three questions a joiner asks
of a search result -- the game, the build, the level and its hash -- are all sound from outside.

**So the question moved rather than went.** It is still the right question -- Steam hands a lobby to another member when
its owner goes, and a lobby whose owner is not the host it names is a game whose simulation left with its host -- and
`Net._whose_lobby_it_turned_out_to_be` is now its own predicate, asked in `_on_entered`, where this machine is a member.
That is where an invite has always been checked, so both ways in ask it in one place. A refusal costs one lobby entry
now, which is the price of the only thing that knows the answer being Steam. Rejected: having the host write its id
somewhere a stranger can read, which it already does -- that is the `host` key this compares against, and the missing
half is who owns the lobby NOW; and dropping the check, which would fly a joiner into a session whose host had gone.

**The gate is the paper directory made honest.** `PaperLobbyDirectory.owner` answered about any lobby it had written
down; it answers 0 about one this machine is not in now, as Steam does. Against the old `Net` that reads RED on 22
checks of `tests/steam_join.gd` -- every code join, the lower-case join, the lobby's member count, the carrier check
and six of the seven refusals at the door -- and on 7 of `tests/code_pad.gd`, including "a join on a row joins that
game and the desk flies into it". **Anything a suite believes about a lobby it is not in has to be something Steam
would really say**, and that is the rule this cost.

### Two more numbers the probe now holds

**A lobby's data reaches the matchmaking servers about 1.7 seconds after it is written.** Measured by
`tests/steam_probe.gd --host`, which hosts through `Net` itself and then searches once a second: nothing at 371 ms,
found at 1717 ms, and the whole lobby arrives at once -- the tag alone, the code alone and both together all began
matching in the same search. Nothing in the game waits less than that (a joiner types six characters first), but a
probe that searches immediately reports a bug that is only its own haste, and this one did before it was made to wait.

**Two lobby searches asked together leave only the later one.** Steamworks says "there can only be one active lobby
search at a time"; `--overlap` measured what that means: of a browse and a code search issued one after the other with
nothing awaited between, **one** answer came back and it was the second request's. So a code typed while "Look for
other players" is still out is answered correctly, and it is the browse that is lost -- the games list stays empty with
no deadline left to say so, which is a wart and not a refusal. This rules the overlap out as a cause of "No game has
the code".

**An invite skips the search, so everything is checked again once inside.** `Net.join_lobby` is where an accepted
invite and a friend's Join Game land (`LobbyDirectory.invited`, which is GodotSteam's `join_requested`). A search result
carries its lobby's data, so a code join is refused before it enters when it can be; every join is checked again after
entering, the same way however it arrived.

**And the desk starts Steam, so an invite can arrive at all.** `join_requested` is a callback, and a callback reaches only
a process that has started Steam and pumps it. `SteamLobbyDirectory` starts Steam the first time it is asked, which used to
be the first Steam button, so a player who accepted an invite while sitting at the desk heard nothing. `DeskRoom` now asks
when it opens. It never asks headless (`DeskRoom.starts_steam`), because a suite, a harness and a second instance on one
machine must not touch the Steam client. An invite accepted while the game is not running starts the game with
`+connect_lobby ID`, which the boot flags read (WHERE THE GAME STARTS). `tests/steam_join.gd` checks that a headless desk
leaves the directory unasked and that a desk told an invite could arrive asks it once; before the change that asked 0.

**A lobby that refused us was never ours to leave.** The first green run of `tests/steam_join.gd` failed five checks:
`Net` left every lobby that turned it away at the door. Steam ignores that, but the paper directory counted it and
took the other game's member count to 0. `Net.lobby` is now the lobby this machine is IN, the one being entered is
separate until it answers, and a yes that arrives after the deadline is left at once. The paper directory writes down
every leave of a lobby this machine was not in (`stray_leaves`), and against the old `Net` that check went red in all
five cases, on lobby 101.

**The seam is a directory.** `Net` asks a `LobbyDirectory` (`net/lobby_directory.gd`) and never Steam by name.
`SteamLobbyDirectory` (`net/steam_lobby_directory.gd`) reaches Steam through `Engine.get_singleton`, because a script
that names the `Steam` class does not parse where the library did not load, and it starts Steam the first time it is
asked rather than at boot. `PaperLobbyDirectory` (`net/paper_lobby_directory.gd`) keeps lobbies in Dictionaries,
answers a frame late, can withhold or change any answer, and hands out real ENet peers on the loopback. So
`tests/steam_join.gd` drives the desk's Host over Steam button into the world, a typed code over a real socket into a
session, sixteen join refusals, an invite and three invite refusals, and four host refusals, with only Steam itself
missing. Against a stub `Net` with the same names it failed 52 of its checks; it passes 87.

**Over Steam, `unreliable_ordered` is reliable, so Steam sessions send on an unreliable RPC.** Read in GodotSteam
v4.21-gde's own source, godotsteam_multiplayer_peer.cpp lines 721 to 723: `TRANSFER_MODE_UNRELIABLE_ORDERED` returns
`k_nSteamNetworkingSend_Reliable`, commented "No equivalent". That is the head-of-line blocking the comment on
`Net._receive` rules out. So `Net.carrier_for(transport)` sends a Steam session's sync bytes on `_receive_unordered`,
marked `unreliable`, and ENet keeps `_receive`. `SteamLobbyDirectory` also turns Nagle off on the peer: GodotSteam
defaults `no_nagle` to false, and sync sends a small packet every tick.

**Unreliable was measured before it was trusted.** Valve's isteamnetworkingsockets.h says unreliable messages may be
dropped, reordered and received more than once. `../../ashiato-gd/addon/tests/crowd_shuffled.gd` (a probe) flies
crowd_sight's 80-autopilot sky over its 4-tick link, varied six ways:

| link | steps over a quarter tick, of 95,920 craft-ticks | missiles and ends |
|---|---|---|
| one packet in twenty swapped, dropped or delivered twice | 0 | 3 of 3, 3 of 3 |
| every other packet two ticks late, swapped | 20,605 (worst 2.01 ticks) | 3 of 3, 3 of 3 |
| the same delays held in order | 3,840 | 3 of 3, 3 of 3 |
| every other packet dropped | 277, one leap of 325.77 ticks | 2 of 3, 0 of 3 |

Sync files an update at its own frame, so an occasional straggler costs nothing. A guard that dropped stragglers
measured no better at one in twenty, so there is none. `tests/steam_join.gd` checks that a joined simulation's
handshake goes out on the unreliable carrier, and that the script's RPC table gives the two carriers transfer modes 0
and 1.

### A keypad on the session screen, and keys for a desk

**Join with a code swaps the session screen's buttons for a keypad on the same glass**, so a headset types with a
fingertip or the beam where it hosts from. `CodePad` (`ui/menus/code_pad.gd`) has a key for each of `JoinCode.ALPHABET`'s
thirty-two symbols, read off the constant so no key types a symbol a code cannot have. It also has a field that groups
what is typed as it is read out (K7M-Q2X), and DELETE, CLEAR, BACK and JOIN. It announces and never judges. JOIN emits the
field as it stands, the desk hands it to `Net.join_code`, and `JoinCode`'s sentence appears under the keypad, where the
player can fix it. A code that joins flies the desk into the world the way hosting over Steam does.

**The refusal is written as large as the label over the field** (`CodePad.LABEL_SIZE`, asked by the session screen's
message line rather than typed there). The first shot showed it at the screen's old 15 px under a 24 px label: the
sentence a player has to act on was smaller than the heading over what they typed. At the label's size it fits on one
line, and Quit still fits on the 1024 x 760 glass with about 170 px to spare.

**A text field on a panel took no keys.** A `TouchPanel` is a SubViewport under a Node3D, with no container to hand it
the keyboard: a LineEdit on one took focus from a click and heard nothing typed. Measured on 2026-09-14 in
`tests/code_pad.gd`, the desk's existing address field was pulled on and ".9" typed, and it still read '127.0.0.1'. Now
the panel whose page has a focused text field takes each key first, in `_input`, and marks it handled. That also keeps
the keys from the rig's `_unhandled_input` bindings.

**And the rig polled M with nothing to ask** (CLAUDE.md, rule 9): typing into the desk raised the clipboard over the
keypad. `TouchPanel.is_typing` is the focus gate it asks first. With the gate taken out again, `tests/code_pad.gd` went
red on it (board up true).

`tests/code_pad.gd` presses all of it through the rig's seams:
- the keypad opened with a beam pull, with every key present and on the glass;
- six keys pulled spelling K7M-Q2X, and a seventh not taken;
- a keyboard typing into the field and into the address field, with both keycodes set;
- a short code refused in words under the keypad;
- a code joining a paper lobby over a real loopback socket and flying into the world.

`tests/code_pad_shot.gd` saves what the screen looks like.

**And the code stays readable once the desk is gone, on every tab of the board.** The desk says a host's code once,
and the world replaces it. So the board in the hand carries "STEAM CODE K7M-Q2X · 1 of 8 players connected", counting
every machine in the session, and the status line on a monitor reads "Host (Steam K7M-Q2X)". A joiner sees the same,
because a joiner knows the code it came by.

**It moved off CREW's body and became furniture on 2026-09-15**, asked for as "make sure the multiplayer steam code is
shown somewhere on the ipad or on the hud". It had been the head of the CREW list since the day before, and CREW is the
sixth of eight tabs and not the one the board opens on: a host reading a code out to a friend had to go and find it
first, which is the same objection the fire debrief's note makes one line above it in `ClipboardPage._ready`. It is now a
line beside the debrief -- off the scrolling page, above the answer line, on whatever tab is up -- and it is out of
CREW's body, because the same words twice on one page read as a mistake.

**Written from `ClipboardPage.tick`, which runs every frame the board is up.** The first version wrote it from
`show_crew`, which `Clipboard` calls only when the simulation hands it a DIFFERENT pilots array -- so the line appeared
when somebody took off or landed and not when the code was drawn. `tick` is both paths' common end, and it answers
whether the board looks different for it, so the render target is repainted only when the sentence actually changed.
`Net.aboard()` is the one place the count is worked out, because the games list says the same thing about somebody
else's lobby.

**What it costs the board.** Two lines of furniture on every tab now, and the fit check measures the worst case -- the
debrief AND the code at once -- rather than one at a time, because that is the board a hosting player in a fire actually
flies with. `tests/clipboard.gd` walks all eight tabs and fails if any of them hides the code; RED with the line back
under CREW, "on CRAFT, TRAFFIC, FEEL, BUILD, TIME, AUDIO, HELP it says nothing". `tests/steam_join.gd` checks the real
thing: a host flown into the world by the Host over Steam button reads its own code off the board, and the count goes to
"2 of 8 players connected" when a loopback guest arrives.

### Looking for other players

    Look for players, on the desk's session screen

Asked for on 2026-09-15: "can you also add a button to look for other players." The code is for a friend who read
theirs out to you; this is for a player with nobody to ask.

**It is the same search with the code filter left off.** `Net.look_for_games` asks the directory for every lobby wearing
`game: cockpit_v1`, `Net.MOST_LISTED` (20) at most, on the `browse` deadline. Nothing new is written on a lobby and no
lobby type changed: the lobby has been PUBLIC since 2026-09-14, so it was already in Steam's list. `Net._read_the_games`
turns each match into a row -- the lobby, the code, the level and its name, the players and the limit, and `why` it
cannot be joined or "" -- and `games_listed` carries them. Joining one is `Net.join_game(lobby)`, which goes through
`_check_the_lobby` like a typed code: **the row carries the lobby, not the code**, because two lobbies holding one code
are refused by a search and a row on a screen is one lobby a player pointed at.

**Every game is listed, including the ones that cannot be joined, with the reason where the JOIN would be.** A friend a
release behind is somebody to talk to about the release they are behind on, and a game silently missing from the list is
a bug report about the list. The reasons are `_what_is_wrong_with`'s own sentences, the same ones a typed code gets,
plus "Full." -- which the row says short because the row already shows "8 of 8 players". **Not "The host has left
that game.", though**: that is the one question a row cannot answer, because Steam will not tell a machine who owns a
lobby it is not in (see "What Steam will not tell a stranger"). A row whose host has gone is offered, and the refusal
comes one step later, on entering.

**The order is joinable first, then the fullest, then by lobby id**, so a player looking for people finds people, and
two screens of one answer agree.

**Six rows and a MORE button, not a scrolling list.** The board in the cockpit scrolls with the thumb of the hand
holding it; a screen standing on the desk has no thumb, and a scroll bar two millimetres wide is not something a beam
from a seat drags. MORE says which page of how many and wraps round to the first, so every game is reachable -- which is
the objection that keeps the crew page from paging, answered here by a button.

**Six is measured, and the measurement is not the obvious one.** With the longest sentence `Net` says wrapped under it,
six rows put the session screen at 652 px of the 716 it has; a seventh at 718. A seventh does not LOOK too tall: a VBox
asked for more room than it has shortens its children rather than running off the glass, and Godot clamps a Control's
size UP to its own minimum, so "nothing is off the glass" AND "the list fits its room" AND "the column fits its size"
are all still true at seven rows -- `wants` and `size.y` both read 718. `tests/code_pad.gd` measures what the column ASKS
FOR against the glass less its margins, which is the one number that does not move, and that check goes red at seven.

**The button shares a row with Join with a code**, because the three above are three different games to be in and these
two are one game -- somebody else's -- reached two ways. Not for height: the front of the screen wants 610 px of 716
with the longest refusal wrapped under it, so a fifth stacked button would have fitted.

**A look round is not a session, so nothing is torn down for it.** The browse deadline says "Steam did not answer. Try
again." and hands back an empty list; it does not go through `_refuse`, which would end a session the player is not in
and leave those words as `Net.parting_words`. Looking while in a session is refused outright -- "Leave this game before
looking for another." -- because joining off the list leaves the one you are in, and this screen announces rather than
acts. The desk does not await the search either: the player can press BACK, type a code or fly solo while Steam is still
thinking, and an answer that arrives after BACK is dropped, because it answers a question nobody is asking.

**The list goes empty while it is looking**, rather than standing stale. A row still on the glass is a game still being
offered, and the answer on its way may not have it in.

`tests/code_pad.gd` presses the whole of it through the rig's beam, against eight paper lobbies -- one worth joining and
carried on a real loopback socket, four more joinable, one full, one a release behind, one on a level this game does not
have, plus one of another game's that must not appear:
- the button, and one pull putting the list in place of the buttons;
- the search asked for `{game: cockpit_v1}` and nothing else;
- eight games on two pages, the fullest joinable one first with its code and a JOIN;
- the full one saying "Full." with no JOIN, and the other two saying which and why on page two;
- MORE turning the page and MORE again coming back;
- the whole list on the glass, and the column asking for no more room than it has;
- a JOIN on a row entering that lobby and flying the desk into that game.

### Two processes on one machine are ONE Steam user, and cannot test a join

Tried on 2026-09-15, sequenced, the joiner given its own `user://` through a second `APPDATA`
(Godot 4.7 has no `--user-data-dir`, and a lane's `override.cfg` sets `custom_user_dir_name`):

```
host    STEAM_ID=76561198002515329  STEAM_CODE=TGF5XU  SESSION=steam host
joiner  STEAM_ID=76561198002515329  BOOT_ERROR=The host did not answer.
```

**The ids are the same, and everything follows from that.** The joiner found the lobby by its
code, passed every check and was let in; it died at `connect_to_lobby`, which was a socket to
itself. Run again with the `getLobbyOwner` bug restored it said the SAME sentence, because
membership is per USER and not per process: the joiner process was already a member of the
host's lobby, so it was told the owner like any member. **One account cannot be a stranger to
its own lobby.** That is why the bug shipped, and why fifty strangers on App ID 480 were the
only way to see it.

So a join tested this way can never succeed whatever the code does, and the sentence it
produces is "The host did not answer." Nothing about a real join can be concluded from it —
only that the search, the checks and the lobby entry all work. No lobby is left behind:
`steam_probe.gd --browse` reads 0 afterwards, because Steam destroys a lobby whose last
member goes.

### Joining over Steam on two machines: the run only a person can make

One Steam account cannot be two peers on one machine, and two Steam clients cannot run on one machine. So everything
above was proved on paper, over ENet on the loopback, or against the real Steam backend from one account (a lobby made
and found by its code). What only two machines can prove is a second Steam account arriving in the game, and the
packets between them.

**What each machine needs.**
- Windows, this repository at the same commit, and `tools\bootstrap.ps1` run once.
- The launcher, `cockpit\tools\play.ps1`, which prefers the double-precision editor. `-Stock` uses the stock one; both
  carry GodotSteam.
- A Steam client running and signed in, with a **different Steam account on each machine**. App ID 480 needs no
  purchase.
- No port forwarding: Steam relays.

**The way a player does it.**
1. **Host.** `powershell -ExecutionPolicy Bypass -File cockpit\tools\play.ps1 --level=menu`, then at the desk press **Host
   over Steam**.
   - The world loads.
   - The code is on the clipboard (M, or the menu button), on whatever tab is up, as "STEAM CODE K7M-Q2X · 1 of 8
     players connected", and on the status line, as "Host (Steam K7M-Q2X)".
2. **Joiner.** The same command, then **Join with a code**, type the code, and press **JOIN**.
   - The world loads within a few seconds.
   - The host's board reads "2 of 8 players connected" and its CREW tab lists the joiner.
3. **Crew.** The joiner presses JOIN on a free seat of the host's craft on the CREW tab, and should be seated in that
   seat. Then follow "Testing a crew with other people: apart, then together".
4. **Quit.** The host quits through the clipboard's MAIN MENU and then Quit.
   - The joiner is told "Host left".
   - Neither process leaves a crash report.
5. **Wrong codes.** A code nobody holds says "No game has the code … Check it with the host." The right code in lower
   case works.
6. **Invites.** Send the joiner a Steam invite, or have the joiner use Join Game on the host's profile.
   - At the desk, the joiner joins.
   - With the game not running, Steam starts it straight into the host's game.

**The quick way, and what to send back.**
- **Host:** `powershell -ExecutionPolicy Bypass -File cockpit\tools\play.ps1 --steam-host`. It prints
  `STEAM_ID=7656119...`, `STEAM_CODE=K7MQ2X` and `SESSION=steam host`.
- **Joiner:** `… play.ps1 --steam-join=K7MQ2X`. It prints `SESSION=steam client`, or `BOOT_ERROR=` and the reason.
- **Send back:**
  - both consoles' `STEAM_ID=`, `SESSION=`, `STEAM_CODE=` or `BOOT_ERROR=` lines. **The two `STEAM_ID=` lines
    must differ**, and that is the first thing to check: two processes signed in as one account are not two
    peers, so a run made that way proves nothing about a join whatever it prints. A Steam mode says the id
    before it asks Steam for anything, so even a process that is then refused prints it;
  - each window's status line after a minute of flying, with its KB/s out and its rollbacks;
  - whether each player sees the other's craft move smoothly.

  This is the first real link to carry the unreliable Steam packets.

**What would mean something is wrong.**
- "Steam is not in this build.": GodotSteam did not load. Send the console's first lines.
- "Steam is not running.": the client is not signed in.
- "The host is on a different build.": the two machines are not on the same commit.
- A joiner that loads the world and sees nobody.
- A crash report on quitting.

### GodotSteam is built here, in both precisions

    powershell -ExecutionPolicy Bypass -File tools\build_godotsteam.ps1 -Sdk <steamworks_sdk_165.zip> -GodotSteam <checkout at v4.21-gde> -GodotCpp <godot-cpp> -Install

**The GodotSteam release is single-precision, and the double editor dies on it.** Measured on 2026-09-14 with
`tests/steam_probe.gd`. Untagged, the double editor crashed inside libgodotsteam while registering its classes, and
cockpit's lint exited 0xC0000374 before printing a line. Tagged `single`, it skipped the library but printed three
`ERROR:` lines on every run, and the runner failed `docs` on them. Codeberg's 4.21, 4.22 and 4.22.1 releases each ship
one plugin zip and no double build.

So the build script builds GodotSteam v4.21-gde (807b7c97), the version racer and topdowntest commit, four ways:
template_debug and template_release, single and double. It builds against the engine's own API files and godot-cpp
101ae38, the checkout ashiato builds against 4.7. `addons/godotsteam/godotsteam.gdextension` names every entry by
precision, as ashiato's does. Each build took 90 to 100 s at eight jobs. Afterwards the double editor, inside cockpit,
loaded `Steam`, initialised it as 480 and found a real lobby by its code in 188 ms; the stock editor did the same in
175 ms.

**The Steamworks SDK is not in the repository.** SDK 1.65 came from partner.steamgames.com/downloads, which needed no
login from this machine. The zip is 25,023,007 bytes, SHA-256
8c42792e09100988e31e3dc069de2eb1bc60702a0445bb37298ba0c54067c202. Only its redistributable `steam_api64.dll` is
committed, beside the libraries, and the build script refuses any other: it checks for SHA-256 e6d9bafb... GodotSteam's
own 4.21 release ships a different one (8de54d32..., still in racer and topdowntest), although it says it is for SDK 1.65.

**GodotSteam 4.21's SConstruct does not parse.** Its doc-data block is a tab-indented `try:` whose `except` is indented
with spaces, and Python 3 stops at line 79 before compiling anything. The build script mends its own copy of the tree
and leaves the checkout as shipped.

**Linux is owed.** Nothing is built for Linux here, so a Linux editor of either precision prints the three "No GDExtension
library found" lines and has no Steam until the script gains a Linux half and is run on that machine. This is the same
arrangement as ashiato's double Linux library.

### A player who quits after using Steam must not crash

**A GDScript lambda still connected to the `Steam` singleton when the game quits makes the process exit 0xC0000005,
after everything else has finished.** Measured on 2026-09-14 on both editors, two runs a case:

| left on the `Steam` singleton at quit | exit |
|---|---|
| nothing, with Steam initialised | 0 |
| a lambda on `lobby_created`, with Steam never initialised and never called | 0xC0000005 |
| the same lambda, disconnected before quitting | 0 |
| a lambda, after a real lobby was made (left or not, callbacks pumped 3 s or not, `steamShutdown` or not) | 0xC0000005 |
| a bound method, left connected | 0 |

GodotSteam frees its singleton in the extension's terminator, after the scripts are gone. The bisection nearly blamed the
lobby, because the search-only run had disconnected its own lambda and the lobby runs had not. The engine side is written
down in the workshop's working_with_godot.md, under Writing a GDExtension.

So `SteamLobbyDirectory` keeps every connection it makes, `close()` takes them off and shuts Steam down, and
`Net._exit_tree` leaves any lobby and calls it. `tests/steam_quit.gd` reads the exit code the only way one can be read: it
starts a child that hosts over Steam through `Net` and quits. Before the fix the child hosted and exited 0xC0000005, in
2244 ms. After it, four children hosted real lobbies and exited 0, twice on each editor.

## A CLIPBOARD IN YOUR LEFT HAND

    the MENU BUTTON on the left controller, or M on a desk

`TouchPanel` is an ordinary Control tree rendered to a SubViewport and hung on a quad, with a
fingertip turned into a synthetic mouse event. One menu system: a cockpit instrument, the two
screens on the desk and the clipboard are the same thing with different pages, and a page is
authored in the editor like any other UI without knowing it will be pressed in a headset.
`CraftDisplay` is a `TouchPanel` with the one rule that makes an instrument an instrument.

**Every menu in this game was furniture until now.** The session screen and the level screen
stand on a desk in the room you start in, and the moment you were flying there was nothing to
press: changing aircraft was a function key or a thumb button that walked a hundred and sixty
machines in entity order, and there was no way at all to join a particular person.

So the menu is CARRIED. A panel on the left hand, brought up and put away with the left
controller's menu button, and pressed with the RIGHT hand -- a panel in a hand that also has
to press it is a panel nobody can press.

**In the hand is not the same as on the head.** There is a rule here that a summoned panel is
placed once and then belongs to the play space, because a panel welded in front of your eyes
is one you cannot look away from, cannot look around and cannot lean in to read. A clipboard
is not that: it is on the end of your arm, you look away from it by looking away, and you put
it away by dropping your hand. The rule is about the HEAD.

**A press is the fingertip arriving**, not a trigger pull. A panel you have to point at and
click is a panel being used with a mouse in a headset -- except on a desk, where there is no
hand to reach with, and the mouse is exactly the right tool: a ray from the eye through the
cursor, met with the plane of the glass, arriving at `press` by the same path a finger does.
The cursor is let go of while the board is up and taken back when it goes away.

**And a pointer as well, because the user could not tell what they were about to press (2026-09-12).** In the
headset the fingertip alone was hard to use: the text was small and nothing showed where a press would land. So the
page's text and buttons are 1.4 times the size (`ClipboardPage.TEXT_SCALE`, one number every font and minimum size
goes through), and while the board is up a thin beam grows from the RIGHT hand. `HandBeam` meets it with the first
glass along its ray, it stops exactly there, and the trigger presses what it is on. The fingertip still presses as before; the
beam is for seeing, and pressing, from further off. **One pull is one press**: while the beam is on the glass the
trigger's own binding, "press what is highlighted", is held off, and off the glass it works as before.

**Aim a hand AWAY with `Basis.looking_at(+normal)`.** `looking_at` points -Z at its argument, and a hand standing
out along the glass's normal that is turned to -normal is aimed straight back at the glass. The first aim-away case
in `tests/clipboard.gd` did exactly that and failed; the corrected case was then run once with the old pose put
back, to show it can go red (2026-09-13), before run_all passed with it.

`HandMenu`, which this file used to describe, was deleted long before any of this: nothing
had ever summoned one.

### TWO PAGES: WHICH AIRCRAFT, AND WHICH PERSON

**CRAFT** is every kind as a wrapped row of buttons, and pressing one asks for a machine of
that kind through the mechanism the function keys already use.

**CREW** is one row per CREWED craft -- what it is, then each of its seats with its station and who is in it -- and a
JOIN on every free seat. Everything on it is already replicated, so the page is a listing rather than a new question
asked of the network. See "WHO SITS WHERE IS THE SERVER'S" below.

### AND A HELP PAGE THAT CANNOT DRIFT

**The only legend this game had was a `print`.** `PilotRig._enter_desktop` wrote the key list
to stdout, which a player who double-clicks the game never sees and which in a headset is
invisible twice over -- and the VR bindings, which are the rich half ("the trigger fires the
gun the hand is holding, and the thumb depends on what that is"), were written down nowhere a
player could read at all. The printed line said **"F1-F10 a type" while eighteen keys were
bound to eighteen craft**, which is what a list kept in three places always comes to.

So there is a HELP tab, and it is DRAWN FROM THE LIVE TABLES. The VR half comes from
`_bindings_for`, which is the function the fingers are actually read through -- the global
set, with whatever the hand is holding laid over it, and the builder and the board on top of
that -- so the page says what the thumb does in THIS hand on THIS control. Take hold of a gun
and the trigger row changes from "brake" to "fire".

**And the keyboard is one table now.** `PilotRig.DESK_KEYS` is walked by `_bind_actions`, by
the stdout line and by the page, with the one key per craft type generated off `Sim.Kind` so
a kind added in the C++ arrives on the page without anything here being edited. A key bound
without a sentence beside it turns up on the page saying nothing.

**`Bind` learned to speak English**, which is what turns a table into a legend:
`Bind.input_name` names a finger and `Bind.says` turns one action into words, off `Sim`'s own
button constants and `Sim.channel_name`. `Bind.nothing()` says "nothing here" out loud rather
than being left off, because a gun grip taking the brake off the trigger is a thing a gunner
needs to know.

**The grip and the menu button are added by the rig** and that is not a drift risk but the
opposite: they are the two inputs `Bind` says may never be bound, so they are in no table to
be read from, and a legend listing only the bindable ones would leave out the input every
interaction in this game starts with.

`tests/clipboard.gd` holds it, and it is a genuine drift test rather than a tautology,
because it compares two independently written representations: `desk_keys` and
`_bindings_for` on one side, the strings read back out of the `Control` tree on the other.
It checks every bound key, every craft type, every bound finger on both hands, and that
taking hold of a gun changes what the trigger says.

**And the page is rebuilt when the BINDINGS change, not every frame.** Which control each
hand holds, plus the builder's two flags, are the only four things `_bindings_for` reads --
so anything else moving cannot change a row, and building fifty rows of strings at the
display rate for a page that is usually not even on show is the per-frame garbage this
project has already had to go and find once.

### AND A TIME OF DAY: ANY TIME, AND HOW FAST (2026-09-18)

"Execute the ability to change the time to arbitrary times of day from the ipad (not just the three we have now)." The TIME
tab (screenshots/2026-09-18/cockpit-daytime-12-the-time-tab.png), top to bottom:
- a readout: the clock, the sky by an almanac's words, the rate;
- DAWN / DAY / EVENING / DUSK / NIGHT (`Orrery.Point`);
- -1H / -10M, a slider across the day in 5-minute steps, +10M / +1H;
- FROZEN / REAL TIME / 60X / 600X / TIMELAPSE (a day in ten seconds);
- CLOUDS.

Every press announces `chose_clock` or `chose_rate`, which `FlightLevel.choose_clock` and `choose_rate` decide through
`Net`, and every highlight is the level's answer (`show_time`, `show_rate`). The slider announces when it is let go, not
on every step of a drag. The time-of-day dial keeps its three stops and shows the preset the look is most like, because five
names crowd its placard. tests/scenery.gd presses +1H with the beam. tests/sky_peers.gd has the host set 17:45 on the
slider, frozen, and then 60X: the joiner draws the same sun to 0.05 degrees, its running clock is the host's own sums at its
frame to 0.1 degrees of sun, and so is a joiner that arrives after. The mutant joiner that took the clock as said NOW
rather than at its frame was 0.15 and 1.1 degrees off. The wire is `Net`'s sky hello, (clock, frame, rate), under "THE
SKY".

**Until 2026-09-18, three buttons (below, as written):**

### AND A TIME OF DAY: DAY, EVENING, NIGHT

Asked for on 2026-09-13: "let's make sure we can configure time of day on the iPad as well so we can test day, evening
and night", and then "make sure the time of day is one of the tabs". **TIME** is the sixth of seven tabs (CRAFT, CREW,
TRAFFIC, FEEL, BUILD, TIME, HELP): three buttons a third of the board wide each, the one on show pressed and amber. The
row is built off `ClipboardPage.Tab.keys()`, so the words and the enum are one list. Seven tabs share the row at the
size they already had, with no word shortened: the fit check passes on all seven (373 visible controls, nothing past
1024 px, only HELP scrolls), and RED, three TIME buttons asking 400 px each ran the row to 1234 px and failed it.

**The page announces, the level decides, and the highlight is the level's.** A press emits `chose_time`, which the
level (`FlightLevel.choose_time`) connects as it does `chose_traffic`, and the page then puts its buttons back to what it
was last handed -- a toggle button presses itself, and a highlight that moved on the press would be the page guessing.
The level hands the board `show_time` at start and on every change. A level with no sky (the hall, the marshalling
levels) hands it nothing, and the page shows "No sky to change here." instead of three dead buttons. Under the three
times, a CLOUDS switch on the same terms (2026-09-16), and the line under the tabs says whose sky it is
(`ClipboardPage.time_words`). No desk key, so the
HELP page is unchanged. What it changes is under THE TIME OF DAY.

### JOINING A NAMED PERSON IS ONE FIELD ON THE INPUT FRAME

`seat_client` has always been the right call and nothing could reach it: the seat buttons
walk the world in entity order, which is browsing, and entity ids are per-machine anyway. So
`join_wanted` is a CLIENT ID beside `kind_wanted`, with a button bit next to the others, and
the server finds whatever that player is flying and takes the first free seat in it -- a crew
fills from the front. It **refuses rather than shuffles**, which is `seat_client`'s own rule:
a full craft, a craft that has gone or a player sitting nowhere all mean no.

On the input frame and not down a reliable side channel, for the reason written on
`ControlInput`: an input frame is the only thing in this game that survives a rollback.

**A menu press has to be ONE request.** The frame goes out every tick, so a request whose button went up and down on
every frame would be one the server answers a hundred and twenty times a second -- "put me in a helicopter" becoming a
player moved between helicopters for as long as the menu is open. The server edge-detects the buttons, so what makes a
press one request is one RISE of its button, not one frame.

**And a menu press is a NUMBER, because a frame can be skipped.** The clipboard's JOIN and craft presses used to be
button edges. The server applies the newest input frame due and skips older ones that arrive together, and repeats
the last input while none arrives (ashiato-gd/LEARNINGS.md, "An input frame carries one command, and sync may skip a
frame"). So an edge on a skipped frame was lost: `tests/crew_peers.gd`'s joiner pressed JOIN and was never answered in 2
runs of 7 with the press on one frame, and in 1 of 34 with it held until answered -- a held press still needs the
server to see the button rise, and a second press needs it to see the button fall first. `ControlInput::menu_request`
is three bits that move on by one per press (`Sim.next_menu_request`) and stay on EVERY frame; the server acts when the
number for a client differs from the last it acted on (`drive_pilot`, `last_menu_request_`), whichever frame shows it.
A JOIN's player and seat, or a craft's kind, ride beside the number until the server shows its answer -- a JOIN's answer
count moving, a craft changing -- or the patience runs out (`Net.patience`'s "connect", 10 s; not a number of its own),
and then the board says "The host didn't answer. Try again." or "The host didn't move you to a PLANE. Try again." in
amber: never a spinner that stops without a word. The JOIN button bit is no longer read; the desk's craft keys and the
thumb buttons keep BUTTON_KIND's edge, because a key or a finger is held for many frames.

**Four rules the number keeps.**
- **It starts at 0 on both sides.** The server's copy for a client reads 0 until the first change, and `forget_client`
  clears it on every removal -- from `remove_client` and from sync's own Removed event (`last_menu_request_of` reads it);
  `Sim.start` puts this machine's back to 0. A rejoiner arrives as a new client and presses 1 first, and that is a change.
- **One menu press at a time, which is its wraparound limit.** Three bits wrap after eight presses, so eight between two
  frames the server applies would look like none. While a JOIN or a craft is waiting, another menu press is refused and
  the board says "Still waiting for the host to answer your last press."; a press waits at most the patience.
- **It is acted on once.** The server records the number in `drive_pilot` under `is_server_` and never resimulates
  (`register_simulation_jobs` runs the server's bodies as plain jobs), exactly as `last_command_seq_` is kept.
- **Nothing predicts it.** The client runs the same `drive_pilot`, and every menu branch in it is `is_server_`.

**What it costs.** 3 bits in every serialised input frame, client to server: about 45 bytes a second up per client at
120 Hz, before sync's resends. Nothing down.

Measured on 2026-09-15. `ashiato-gd/addon/tests/crew_join` drives every press the way the rig does. On the edge build, a
library with no `menu_request`, each of its counter sections acted on nothing: 0 of 5 presses answered over a link that
bunches a client's frames in threes, 0 of 5 craft presses over a stream that stalls 10 ticks and lands in a lump, 0 of 5
second presses across a stretch the server skipped, and a player who rejoined and pressed at once went unanswered. On
the counter library (single FFC84511, double 605DA55B) all four passed: 5 of 5 answered in 11 to 13 ticks, 5 of 5 moved
in 10, 5 of 5 landed in the second seat, and the rejoiner was answered in 11 ticks. The seat race, every refusal and the
crowd of 78 craft passed too, the crowd with 0 of 9,000 seat claims wrong over 600 ticks on 5 machines. For comparison,
a one-frame button press was answered in 3 of 5 over the bunched link and moved the player in 0 of 5 over the stall (the
edge build, measured before the counter). `tests/clipboard.gd` holds the rig's contract: the number moves on once per
press and is on every frame, a second press while one waits is refused and said, the number wraps at eight, `Sim.start`
resets it, and a press the server never shows is let go after the connect patience and said in amber. crew_peers, two
real processes on the finished code (e144640b), passed 10 of 10 in a row, each in 6 to 9 s: both machines agreed on the
craft apart in 2,906 to 3,750 ms and together in 6,115 to 8,744 ms. All ten ran under load from other lanes: 2 to 10 of
their Godot processes beside each run, terrain's gate in all ten, moon in nine and townlights in six (recorded per run
by worktree path). With five lanes live there was never a quiet machine, and load is the harder condition. Before the
counter a press held until answered went unanswered 1 run in 34.

A MACHINE THAT LEAVES COMES BACK AS A NEW CLIENT, AND THE SERVER FORGETS THE OLD ONE ON EVERY PATH. sync hands out the
next id past the last it gave and wraps to 1 only after 254 (`ReplicationServer::find_next_available_client_id`,
`next_connect_client_id_`), so a rejoiner arrives as a new client -- client 5 after client 2 left -- and its old id returns
only some 250 connections later. For that later client, `forget_client` clears the old one's menu number, join answer and
command sequence both from `remove_client` and from sync's own Removed event, which covers sync's idle timeout (off in the
cockpit today). `last_menu_request_of` reads the server's copy: in crew_join a client that has pressed reads 2 and reads
0 the moment it is removed, and a mutant whose `remove_client` kept the number read 2 after. The one run in which a
machine "came back as client 2" was the test: on the edge library nobody had joined, so the disconnect removed nobody
(its leaver was -1) and still passed, and the rejoin started on the peer of a client still connected. The disconnect now
needs a real leaver, and the rejoin arrives on a fresh peer, as a transport sends one.

### WHO SITS WHERE IS THE SERVER'S: A SEAT ON THE PAGE, ONE PLAYER TO IT, AND AN ANSWER

Asked for on 2026-09-15: "a panel in the ipad that allows me to see a list of other players that are in a plane and join
them. Make sure this is server authoritative, and that only one pilot may be in a seat at a time."

**At most eight crewed craft, and the thumb scrolls the rest.** A session is `Net.MAX_PLAYERS` players, so at most
eight crewed craft; four fit with the code line and a refusal showing (459 px of content in 739), eight do not. CREW is in
`ClipboardPage.MAY_SCROLL` with that reason, nearest first so the craft in sight are on show, and `tests/clipboard.gd`
lists ten, checks the order, and has the thumb bring the farthest onto the glass. Pages, or "N more", were rejected: a
craft the page cannot reach is a friend you cannot join. The code line counts machines, "2 of 8 players connected" --
"1 of 8 aboard" above a craft visibly holding two read as a wrong count. It is not on this page any more (2026-09-15):
it is furniture on every tab, so CREW keeps the height it was measured with.

**The page is a manifest.** `CrewManifest.read` turns what every machine already holds into one row per crewed craft:
the craft off `Sim.pilots`, and its seats off the craft's own replicated `Seats` (`vehicle_seats`), each with its
station from the shape table (`kind_geometry`). Yours first, then nearest first, each row titled with its kind, whose it is
("YOURS", or "PLAYER n'S" for the first occupant in seat order, the pilot whenever there is one) and its room ("2 FREE ·
1.2 KM"). A check compares every seat's word on a row with the kind's own `seat_poses`: the first pictures said COPILOT
on every seat because the test's made-up manifest used one word for all four, and nothing had compared the page with the
craft. `Clipboard` builds it at most once a simulated tick and hands
it to `ClipboardPage.show_crew`; the page draws five equal columns -- the craft, then four seats -- so eight players in
four craft are 4 rows and fit without scrolling (`tests/clipboard.gd`, `the_crew_page_fits_full`), with a JOIN on each
free seat. **The seats come from `Seats`, not from the pilots**: an occupant is a byte in `Seats` whether or not this
machine has its pilot yet, and a manifest built from pilots alone offered 3 JOINs on a pod the server had filled.

**A craft is named by a player in it.** A JOIN puts `join_wanted` (a client id, 8 bits) and `join_seat` (0 to 3, or 7 for
any free seat, 3 bits, `kAnySeat`) on the input frame for one frame, with the JOIN button bit. Entity ids are per world
and a client id is the same everywhere, so "seat 3 of the craft player 2 is in" is the only way to name a seat across
machines.

**What the field costs.** 3 bits in every serialised input frame, client to server only -- 45 bytes a second up per
client at 120 Hz, and again in each copy sync resends for loss. Nothing comes back down. It rides the client's input
history with the rest of `ControlInput`, so a resimulated frame carries the same value, but nothing on the predicted path
reads it: a JOIN is decided `is_server_` alone, and `ControlInput::should_roll_back` is false, so it can cause no
rollback. It is its own commit because terrain's wire increment changes quantisers in the same serialiser.

**The server alone decides, after the jobs, lowest client id first.** `drive_pilot` only notes the press
(`join_presses_`); `answer_the_joins` runs in `tick()` after the simulation and before `publish_cabins`, sorts the presses
by client id and hands each to `join_player`. It used to be decided inside the pilots job, which writes `Seats` without
declaring it and decides two presses on one tick in pilot-entity order -- an order nobody chose. `move_pilot` writes
`Seats` at once, so the second of two presses for one seat finds it taken: **one player a seat is structural, not a check
that has to be trusted.** Nothing on a client writes `Seats`; every seat change is `is_server_`.

**Every refusal has a reason and the refused player reads it.** `join_player` answers `kJoin*`: joined, `seat_taken`,
`full` (any seat asked and none free), `gone` (that player is flying nothing, or is not here), `already_there` (the seat
you are in, or any seat of the craft you are in) and `no_such_seat` (past the craft's last seat; refused, not clamped).
The server keeps a count and the reason per CLIENT, and `publish_cabins` writes them onto that member's `CabinOwner` --
four bits each, the cabin being the one thing sent to that member alone and snapped -- so an answer is private, lands on
the tick its packet does, and follows a player who joined onto the new craft's cabin. `CockpitWorld.join_answer()` reads
it back; `Sim.join_answer` captures it each tick; the page says it in the line under the tabs the moment the count moves
after a press ("Asking the host for that seat..." until then), on whatever tab is up, and CREW keeps showing it.
**And where the pilot is looking**: on CREW the sentence stands at the head of the crew list instead, and the line under
the tabs keeps its instruction, because the same words twice on one page read as a mistake; on any other tab the pilot
turned to while the answer was on its way, the line under the tabs says it. At the head of the list it is at the page's
largest writing (`BoardStyle.text(24)`, 34 px, about 8 mm on the board) and amber when it is a no. The line under the tabs
is 24 px and dim and at the far end of the board from a JOIN near the bottom of the list; a pilot who has just pressed is
looking at the list (team-lead, 2026-09-15). The full page with the answer showing still fits without scrolling.
`join_log()` is the server's last 32 decisions with the tick each was made on, for tests. **A player whose craft has gone
holds no cabin and so reads no answer**; pressing any craft button gets them a craft, and then a cabin.

**A move within the craft is a join like any other.** A player in seat 4 who presses JOIN on seat 3 of the same craft
names a seat that is free and not theirs, so `move_pilot` takes them there and empties seat 4 on the same tick; every
machine shows it within the same bound as a join.

**Leaving and disconnecting free the seat.** Taking another craft is `move_pilot`, which empties the old seat on the same
tick. A peer that leaves is removed from sync and its pilot despawned by `Sim._seat_new_clients`, which vacates its seat;
`despawn_vehicle` refuses a craft with anybody still aboard, so a crewmate is never dropped with it. `remove_client`
forgets the client's answer as it forgets its command sequence, because client ids are reused.

Measured in `ashiato-gd/addon/tests/crew_join` (a server and four clients in one process over a 4-tick link, 2026-09-15):

| | on 623442d's library | after |
|---|---|---|
| B and C press JOIN on seat 2 of A's aeroplane in one loop | decided on one server tick (proved from `join_log`) at the first try; B seat 2, C moved to seat 3 unasked | same tick, first try; B (the lower id) seated, C left in its pod and told `seat_taken` |
| a named free seat (4, with 3 free) | put in 3 | put in 4 |
| a taken seat, a full craft, a seat past a craft's last, a player flying nothing, your own seat | 5 of 5 moved somebody or said nothing | 5 of 5 refused, nobody moved, each told its reason within 9 ticks of the press |
| every machine shows a decided seat | -- | 0 ticks past the answer window (the check allows 7) |
| a leave frees the seat | 4 ticks on the server after the press, every machine 5 later | the same |
| a disconnect frees the seat | every machine left within 5 ticks | the same |
| seat 4 to seat 3 of your own craft | -- | moved, seat 4 free on every machine; see below |
| seventy moving craft arrive, and two race for one seat | -- | see below |

**The seat move could not be shown red on the old library**: with seats 1, 2 and 4 taken, "any free seat" is seat 3, so
the old path moved the player to the same place. So it was shown red on a mutant. Built with `move_pilot` writing the new seat and leaving the old one occupied (a double library, 2203BC8C against the gated 2BF29CD0), crew_join failed `a_player_who_asks_for_another_seat_of_their_craft_moves_there_and_frees_the_old_one` with the craft's seats reading [1, 2, 3, 3] -- one player in two seats -- and six checks after it with it, the crowd's claims among them (2,400 of 7,200 wrong, the server holding client 3 in four craft). The source was then put back and checked by SHA-256 against the committed file (A3986A9C, as checked out with CRLF), the libraries were checked out of git (B7246554, 2BF29CD0), and crew_join passed on them.

**And in a crowd.** A client's `Seats` can only be wrong under send-budget pressure (cockpit-joinfix: ashiato-sync once
recycled a quantized frame another client held as its baseline, and a client copied Seats from the wrong craft), and five
craft never make any. So section 9 adds seventy moving craft at once, races C and D for one seat of A's craft, and then
counts on every tick, on every machine, the craft that hold each of A, C and D. Measured on 2026-09-15 on the rebuilt libraries (single B7246554, double 2BF29CD0, built with retain-before-release): a sky of 74 craft, the race to the lower id on one server tick, and 0 of 7,200 claims wrong over 600 ticks on 4 machines. It has not been run on a library without the patch -- the shared ashiato-sync is patched, and `crowd_join` is the suite that holds the mechanism red and green.

14 checks failed on the old library and all pass after. `tests/clipboard.gd` presses it through the glass: the beam on
the JOIN of seat 3 of another player's airliner seats us in seat 3, not the first free seat 2, and the board reads "You
are in seat 3."; a seat the server fills the instant before a press is refused and the board reads "Somebody else has that
seat. Choose a free one."; a full craft is listed with no JOIN on it, and a press that asks anyway is told `full`.
`tests/crew_shot.tscn` photographs the page full and nearly empty.

**And two real processes.** `tests/crew_peers.gd` starts a host and a joiner over ENet on the loopback (ports 47990-47999)
with `--report=1`, whose `SESSION_REPORT` now carries `crew=` (the page's own manifest on that machine, as
`pod:1.-.-.-/pod:2.-.-.-`) and `answer=`; the joiner also runs `--board=3`, which three seconds after its page first lists
the host's craft presses that craft's first JOIN on its own clipboard (`Sky._board_when_asked`). It passes only when both
machines list two craft with one player each and agree, the joiner pressed, then both list one craft with both aboard and
agree, and the joiner was told `joined`. Measured on 2026-09-15: both machines listed `pod:1.-.-.-/pod:2.-.-.-` and agreed 3.3 s after the children started, the joiner pressed three seconds after first listing the host's pod, and both listed `pod:1.2.-.-` with the joiner told `joined` at 6.5 s. Against the sky from before `crew=`, `answer=` and `--board`, on the same library, every check but the port failed at the 90 s deadline. A host that draws no pilot for the joiner, which is the two_peers flake cockpit-joinfix owns, lists no craft for it either, so that fault fails APART here.

### Testing a crew with other people: apart, then together

What only people can check is the seats in a headset and over a real link. On every machine: this repository at the same
commit, `tools\bootstrap.ps1` run once, and the game started with `powershell -File cockpit\tools\play.ps1`.

**Start a session.**
- **Over a LAN.** Host: `play.ps1 --host` (port 7788 unless `--host=PORT`). Each joiner: `play.ps1 --join=HOST-IP` (or
  `--join=HOST-IP:PORT`). The host's firewall has to let the port in. The status line says Host or Client.
- **Over Steam.** Host: `play.ps1 --steam-host`, or Host over Steam at the desk; the code is on the board, on whatever
  tab is up. Each joiner: `play.ps1 --steam-join=CODE`, or Join with a code, or Look for players, at the desk. Each machine needs its own Steam account (see "Joining over
  Steam on two machines").

**1. Apart.** Everybody flies what they arrived in. Open the clipboard (M, or the left menu button) at CREW. Every machine
should list the same craft, yours first and marked YOURS, each with its four seats (a tank, a cessna or a glider fewer), the others
as PLAYER n, and a JOIN on each free seat. Take another craft on the CRAFT tab: within a second every machine should move
you to the new row, and your old craft should drop off the page.

**2. Together, two machines.** The joiner presses JOIN on seat 2 of the host's craft. Within a second the joiner is in the
copilot's seat, the board says "You are in seat 2.", and both pages show the host in 1 and the joiner in 2.

**3. Together, three machines.** A third player presses JOIN on seat 3 of the same craft. Then the second and third press
JOIN on the same free seat at the same moment, counted down aloud: exactly one of them gets it; the other stays where they
were and reads "Somebody else has that seat. Choose a free one." The lower PLAYER number wins a true tie, which by hand is
rare: over a real link the first press to reach the host usually wins outright.

**4. Leaving.** One of the crew takes another craft on the CRAFT tab, or quits. Within a second their seat has a JOIN on it
again on every machine, and nobody else moved.

**What each line on the board means.**
- "You are in seat N.": the host seated you.
- "Somebody else has that seat. Choose a free one.": somebody reached the host first, or was already there.
- "Every seat in that craft is taken.": a press asked for any seat and there were none.
- "That player is not flying anything now.": they left, or their craft has gone.
- "You are already in that seat.": nothing to do.
- "That craft has no such seat.": a page out of date with a craft that changed kind.
- "Asking the host for that seat..." that does not change within a couple of seconds: the press or its answer did not
  arrive. Send back the status lines of both machines.

**What would mean something is wrong.** Two players in one seat on anybody's page; a page that disagrees with another
machine's for more than a second; a JOIN on a seat that somebody is in, after a second; a seat that stays taken after its
player left or quit. Send back a photograph of each board and both status lines.

### AND THE BUTTONS FIELD WAS FOUR BITS

`ControlInput.buttons` was serialised as four bits, which was every button there was until a
trigger arrived. A fifth bit written into a four-bit field is not an error anybody sees: it
is dropped on the way out, so the gun worked when a test fired it on the server and did
nothing at all when a player pulled the trigger. Eight bits now -- six carried SEAT through JOIN, and the
missiles' LOCK (64) and LAUNCH (128) are the seventh and eighth, widened in ashiato 8433045 before either bit was
sent, so the same silent drop could not happen twice -- and the deserialiser's guard
counts its own reads rather than keeping a number beside them that has to be remembered --
it said 18 while they took 23.

### THE BOARD HAS FINGERS OF ITS OWN, AND GIVES THEM UP WHEN A HAND TAKES HOLD

**The board speaks for the fingers the way a control does.** A lever hands `PilotRig` a table
saying what the rest of the hand does while it is held; `ClipboardPage.bindings(hand)` is the
same kind of table, and `_bindings_for` lays it over everything else while the board is up.
Before this the rig carried the board's two thumb bindings itself, which is the shape the
controls stopped having when the binding became a property of the thing being worked.

| while the board is up | the hand holding it (left) | the free hand (right) |
|---|---|---|
| upper / lower thumb | up / down the page | up / down the page |
| mini joystick | flies, as it always does | up and down walk the highlight; left and right turn the tab |
| trigger | brakes, as it always does | presses what is highlighted |
| joystick click | -- | the next tab |

**The hand holding the board still flies.** Its stick is the control column and its trigger
the brake, and a board that took those away would be an aeroplane that stopped answering
whenever somebody read a menu. The board's table names neither, so they fall through.

**A highlight, and a press that is a real press.** The stick walks Godot's own focus through
the page (`find_next_valid_focus`), the scroll follows it, and the trigger pushes `ui_accept`
down and up into the page's viewport -- the event Enter or a gamepad's A sends. The button
decides what a press means, so a tab turns, a switch flips and a craft button asks for a craft
without the board knowing which it is. A highlight left on a tab that is no longer on show is
not a highlight: `highlighted` asks whether it is still visible.

**GRAB WITH THE BOARD UP AND THE BOARD GOES AWAY.** `_put_the_board_away_for` runs on the grab
edge in `_work_the_controls`, the one place a hand takes hold of anything, for either hand --
the left one letting go of the board to take the collective has put the board down. Putting it
away is the whole handover: the fingers are looked up afresh every frame from what the hand
holds and whether the board is up, so there is nothing to unbind and nothing to rebind. And a
thumb that was held down scrolling is still DOWN when the table changes under it, so the
control's own action for that thumb waits for the next real press rather than firing on the
frame the hand arrived.

**`force_input(hand, input, value)`** is the seam that makes any of this testable, and the one
`force_grip` left missing: a desk reads no controller, so every binding in the game was a
table a suite could read and never a finger it could press. While an input is forced the hands
are worked on a desk as well, through `_work_the_hands` and `_do_action`, and what they would
have put on the frame is thrown away -- the keyboard still flies.

`tests/clipboard.gd` presses all of it: the free stick walks the highlight onto a craft and the
free trigger asks for exactly that craft; the click and a sideways flick turn the tab forward
and back; and for each hand, a real grab with the board up takes the control, puts the board
away, and leaves every finger reading the control's table over the empty hand's.

**What is not here:** the keyboard has no highlight -- on a desk the mouse points at the board
-- and holding the stick over does not repeat; flick it back through the middle to move again.

### The board half as big again, four tabs across (lane/handshake, 2026-09-18)

The user: "since the number of tabs on the ipad is getting larger let's make the tab sizes a little smaller (4 across)
and let's make the ipad itself a little bigger (50%)".

- **`Clipboard.GROWN` (1.5) is the one number.** `SIZE` is `SIZE_WAS` (24 x 30 cm) times it, so 36 x 45 cm. `PIXELS` is
  1024 times it, so 1536. `AT` is `AT_WAS` moved up the tilted glass by half of what the board grew, so the bottom edge
  stays where it was, clear of the controller. Every page probe that photographs the glass at the board's size uses
  `Clipboard.SIZE` and `Clipboard.PIXELS`, never a typed 1024.
- **The writing keeps its density, 4,267 px a metre, so it is the size it was and as sharp.** The page is a canvas
  1536 x 1920 instead of 1024 x 1280, and has half as much room again each way. Measured on the board: the scrolling
  area is 1,325 px where it was 739. Of the nine tabs that declared they might scroll, only HELP still does (2,677 px
  of legend in 1,325). Ten crewed craft fit the CREW page with 102 px to spare, so `tests/clipboard.gd`'s thumb check
  lists twenty.
- **Four tabs a row (`ClipboardPage.TABS_IN_A_ROW`), a little smaller**: `TAB_TALL` 40 and `TAB_WORDS` 19, from 46 and 22.
  Eleven tabs are three rows. No tab may be a smaller target than the parts bin's 38
  (`and_no_tab_is_a_smaller_target_than_anything_else_on_the_board`).
- **The controller is 2.3 cm clear of the glass** from the 40 cm eye (it was 1.1), because the bottom edge stayed put
  and the glass grew up and out.
- **A 40-degree picture from 40 cm no longer holds the board.** `build_stamp_shot` also saves the same eye with a 90°
  lens, as a headset sees it.
- **If the words should grow with the board, that is one more number, not a relayout**: the page would render at
  `PIXELS` with its canvas kept at 1024 across (a content scale of `GROWN`). Not done, because the brief asked for the
  density to be kept.

## A JOB THAT IS NOT FLYING: THE MARSHALLER

    Godot --path cockpit -- --level=deck      a jet, onto a catapult
    Godot --path cockpit -- --level=stand     an airliner, onto a gate
    Godot --path cockpit -- --level=signals   every signal there is, to learn them in

Every player in this project is flying something, and the rule at the top of this file says
adding an on-foot state would undo most of what makes it work. **The marshaller does not
need one.** They stand in one place and move their hands, and the aeroplane comes to them --
which is a whole job, done on a real deck, with no walking in it at all.

**A POST IS A SEAT.** The rig is bolted to an anchor with the same `sit_in` an aeroplane's
seat uses and is never given a world transform, so a marshaller standing on a carrier that
is making way has hands as steady as a pilot's at 300 kph, for exactly the same reason.
`MarshalRig` inherits `PilotRig` and overrides two methods: `_seat_the_head` does nothing
(a pilot is sat DOWN to the cockpit's eye height, which is wrong on a deck) and
`_place_desktop_rig` puts the hands where the mouse says.

**A SIGNAL IS A PATH THROUGH ZONES**, not a gesture to be recognised: named spheres around
the player's own body, visited in order, which is the arithmetic `VehicleControl.offer_hand`
already does with a lever. That is what makes it drawable -- the level SHOWS you where to
put your hands -- and testable, which is how a robot marshaller in the suite launches a jet
off a catapult with no headset attached.

**THERE IS NO SIMULATION IN THOSE LEVELS.** Like the hall of cockpits, they are a rig, some
scenery and the game's own `VehicleView` for a body; the aeroplane is a node moved by a
tricycle model in GDScript. So rule 2 is untouched -- there is nothing to write a position
INTO -- and the whole position costs no C++, no vehicle kind and no change to anything the
rest of the game reads.

It lives in `marshalling/`, with its own `agents.md` -- which is where the interesting half
is: what a held signal means after the arms come down, why a turn is a rate and not an
angle, and the three bugs that were all the same bug. The join to the rest of the project is
three lines in the router, one in the desk, three buttons on the level screen and a suite
line in each test runner. `MarshallingLevel.DOORS` is the only place those scene paths are
written down.

## HOW MANY PLAYERS, AND WHAT STOPS YOU

    tests/crowd.sh                             1..32 clients at 100 ms, as a table
    tests/crowd.sh --tick 30 --ai 40           a slower clock and a populated world
    Godot --headless --path cockpit res://tests/crowd.tscn -- --clients=8 --ping=100

`tests/crowd.gd` stands a server and N clients up in one process behind a FAKE LINK -- a
queue with a delivery tick on every packet -- and reports what the wire costs, what the
server's own tick costs, and how often anybody mispredicts. It is a probe and not a suite:
there is no pass and no fail, because the answer is a number and the number depends on
what you are willing to pay for. It is not in `tests/suites.txt`.

The link being fake is the point. A delay in ticks is exact and repeatable in a way a
socket is not, so two runs at the same client count produce the same numbers and a
difference between them is a change in the code. A six-point sweep takes ten seconds.

### THE CEILING IS 1024 BYTES PER CLIENT PER TICK, AND NOBODY CHOSE IT

`ReplicationServerOptions::bandwidth_limit_bytes_per_tick` defaults to 1024 and this
project has never set it. It is not the adaptive controller -- `bandwidth.enabled` is
false, which is a different thing -- it is a hard per-client per-tick budget that applies
either way.

At 120 Hz that is **120 kB/s down per client, and it does not move**. Measured with 8
clients at 100 ms, growing the world underneath them:

| replicated entities | down per client |
|---|---|
| 16 | 41.0 kB/s |
| 24 | 67.1 kB/s |
| 40 | 119.4 kB/s |
| 72 | 123.4 kB/s |
| 136 | 123.3 kB/s |

A vehicle costs about **19.6 bytes per update**, so about 52 of them fit in a tick's
budget. Past that nothing gets louder -- entities simply come round less often, and the
server rotates them fairly, which is the part to pay attention to. Freshness is
`tick_rate * 52 / entities`: 136 entities update at 46 Hz each, 200 at 31 Hz, 2000 at
3 Hz. **The aeroplane on your wing was starved at exactly the same rate as one forty
kilometres away**, because `options.prioritizer` returned a flat 1.0 for everything that is
not a cockpit interior. Since 2026-09-17 it does not: see "THE PRIORITY SPHERE".

### WHAT GROWS WITH PLAYERS IS THE SERVER, NOT THE CLIENT

Per client the wire is flat. The server's outbound is `clients x entities`, so it is
quadratic, and so is the serialisation that produces it. At 120 Hz and 100 ms:

| clients | server out | per client | up per client | server tick |
|---|---|---|---|---|
| 1 | 11.9 kB/s | 11.9 | 68.8 | 0.012 ms |
| 4 | 96.9 kB/s | 24.2 | 68.8 | 0.056 ms |
| 16 | 1190 kB/s | 74.4 | 68.8 | 0.489 ms |
| 32 | 3957 kB/s | 123.6 | 68.7 | 3.07 ms |
| 64 | 7918 kB/s | 123.7 | 68.7 | 10.87 ms |

Sixty-four clients at 120 Hz costs 10.9 ms of a 8.3 ms frame, so that is over. The same
crowd at 30 Hz costs 8.6 ms of a 33 ms frame. These are wall clock with every client world
in the same process competing for the same core, so read the SHAPE rather than the
capacity -- but the shape is quadratic and that is real.

### UPSTREAM IS BIGGER THAN DOWNSTREAM, AND IT IS THE TICK RATE SQUARED

68.8 kB/s up against 41.0 kB/s down, per client, at eight clients. The client resends
every input frame the server has not acknowledged, up to 31 of them -- see
`client/store/input_buffer.cpp` -- so a packet carries the whole round trip's worth. The
frames in flight go up with `ping x tick_rate` and the packets go out at `tick_rate`, so
upstream is **quadratic in the tick rate** and linear in the ping. Measured, 8 clients at
100 ms:

| tick | down per client | up per client |
|---|---|---|
| 20 Hz | 6.9 kB/s | 3.9 kB/s |
| 30 Hz | 10.3 kB/s | 8.1 kB/s |
| 60 Hz | 20.5 kB/s | 20.8 kB/s |
| 120 Hz | 41.0 kB/s | 68.8 kB/s |

That redundancy buys something real: at **10% packet loss the rollback rate does not
move** (1.25/s against 1.31/s), because a lost input packet is carried again by the next
one.

### MISPREDICTS ARE SET BY THE PING, BUT ONLY THEIR SIZE

The surprise, and it is worth internalising. Four clients at 120 Hz, flying a continuous
roll so they never agree with the server:

| ping | rollbacks/s | ticks replayed each |
|---|---|---|
| 17 ms | 1.29 | 4 |
| 50 ms | 1.29 | 8 |
| 100 ms | 1.29 | 14 |
| 200 ms | 1.29 | 26 |
| 400 ms | 22.2 | 50 |

**How OFTEN a client rewinds is flat across the whole usable range** -- it is set by how
often the server's answer differs enough to matter, which is a property of the flight
model and the quantisation, not of the link. What the ping buys is how FAR back each
rewind goes, and that is exactly the round trip.

**The 400 ms row was not the prediction window running out, as this section used to say. It
was the client's own input never reaching the server** -- see the next section. A 400 ms
ping is 24 ticks each way at 120 Hz, and before 2026-09-16 every client past 15 ticks each
way sent the server stale input on every frame. `tests/input_window.gd` at 24 ticks: 380
rollbacks in 600 ticks before the fix, 10 after, the same as link 0.

### A CLIENT'S NEWEST INPUT HAS TO FIT IN ONE PACKET, AND BEFORE 2026-09-16 IT DID NOT

**Every tick sync's client sends one input packet, and what it holds is every input frame
the server has not acknowledged.** That window is the whole round trip, because a frame stays
in it until an acknowledgement a round trip old says it arrived. It was written OLDEST first
and cut at the 1200-byte MTU or the input count of 31, whichever came first, and nothing said
so. A `ControlInput` was 327 bits on every frame (three tracked poses, no delta coding), so it
held 29 frames. The server then stepped every frame on input it had already used, 2 frames
staler for every tick of latency: **frames behind = round-trip lead - 29, from a one-way
link of 15 ticks (125 ms at 120 Hz).** At 16 ticks, 600 of 600 frames starved 3 behind, and
there were 60 rollbacks where link 0 has 11. `DrivingWorld` and `VrWorld` hit the count
instead, past a lead of 31 frames.

`ashiato-gd/tools/patches/ashiato-sync-send-newest-inputs-first.patch` sent the newest
`input_frames_per_packet` frames instead, default **8** (2026-09-16 to -18; see "Since
ashiato-sync 8fa08cf" below for what replaced it). A packet costs the same at any
latency: 337 bytes a tick for a cockpit, 32 for a car, 281 for a VR avatar, where the old
window cost 1,193, 93 and 1,057 at 16 ticks. Measured on the exact pump (below) with 1% loss,
a 5-tick outage every 2 s and 0-4 ticks of jitter, per 600 ticks:

| link 16 | starved | rollbacks | bytes a tick up |
|---|---|---|---|
| stock | 600 | 71 | 1,193 |
| spill the window into 2-3 packets | 79.5 | 14.7 | 1,448 |
| newest 8 | 10.0 | 13.0 | 337 |

**Why not spill the window over more packets: ENet throws them away.** `Net._receive` is
`unreliable_ordered`, which Godot 4.7.2 sends as ENet's unreliable SEQUENCED channel
(`modules/enet/enet_multiplayer_peer.cpp:350`), and ENet discards any packet whose sequence
number is at or below one it has already delivered (`thirdparty/enet/peer.c:909`). With
jitter a tick's second packet often lands first, and 3,381 of the spill's packets were
discarded at link 16. **Why eight and not sixteen: they measured the same in every
condition.** With no jitter the lead has no spare frames, so only the first packet carrying a
frame can arrive in time; jitter buys spare lead, and eight covered 0-4 ticks of it.

**Since ashiato-sync 8fa08cf (2026-09-18) upstream sends the newest frames itself**, up to the
protocol's input count of 31, and trims the OLDEST when the MTU cuts; the 8-frame cap was not
taken, and the user accepted that. It costs upload on a long link and nothing else measured
(`tests/input_window.gd`, 600 ticks, up bytes a tick):

| | 8-frame cap | 8fa08cf |
|---|---|---|
| link 0 / 4 | 12.2 / 28.3 | 12.2 / 28.3 |
| link 16 to 42, steady flight | 72.2 | 134.0 |
| link 16, head and hands moving | 265.4 | 962.6 |
| link 16, bad ENet link: starved, rollbacks | 24, 10 | 24, 10 |

Starved frames and rollbacks are the same in every row. **It is counted, not alarmed on.**
`timing()` reports `input_frames_max` (31), `input_packets_truncated` and
`input_frames_truncated` (`ashiato-gd/src/core/input_truncation.hpp`). A cut now drops the
oldest frames, which the server most likely has, so it is not an error; stale input shows as
`input_starved` on the server's trace, and `input_window` checks that at every link. Until
8fa08cf every world pushed an error on a cut below the 8-frame cap.

**The next wall was the lead clamp, and it is now moved past the measured range** (2026-09-17).
Cockpit uses a 128-frame input history on both sides and a 128-frame prediction history on
its client. Driving and VR keep sync's 64-frame default. On the old library, the exact pump
at 36 and 42 ticks one way (300 and 350 ms) starved 600/600 frames, fell 5,400 and 12,600
frames behind in total, and rolled back 180 and 420 times. With the deeper history, links
30, 36 and 42 settled at leads 60, 72 and 84, starved zero, and rolled back 10, 10 and 11
times per 600 frames (link zero: 11). The next history edge is 127 frames, beyond 500 ms
one way at 120 Hz.

**ControlInput is delta-coded now, protocol 9.** A packet's first frame is relative to the
client's acknowledged baseline and its other frames to their predecessor. Sync only advances
that baseline from a server acknowledgement; losing the packet that would have established a
new one therefore leaves both ends on the older baseline. `input_window` deliberately drops
that packet, changes the complete button byte to `0xA5`, and proves the next packet delivers
it with one starved frame and no later starvation in the remaining 599-frame window. Sync's
`ServerInputBuffer` also ignores a relative packet whose named baseline is absent without
consuming any input frame.

The codec has a 21-bit field-group mask. Its exact diagnostic and link measurements are:

| case | size / cost |
|---|---:|
| full frame, no room request | 333 bits (327 until the command sequence went from 2 bits to 8, 2026-09-17) |
| unchanged delta | 21 bits |
| every field changed, including a room request | 404 bits (398 before the same change) |
| eight worst-case frames encoded | 11.0-11.6 us |
| steady flight, newest-eight packet | 70.5 B/tick, 72 B largest |
| head and both hands moving every tick | 264.3 B/tick, 266 B largest |

Before deltas, both flight rows were 338 B/tick in this harness and Item 10 measured about
44 kB/s at 120 Hz after carrier accounting. The 200-aircraft rerun measures **13.0 kB/s per
client upstream**, at every 2/4/8-peer, link-8/link-16 cell. The quaternion comparison is
allocation-free: it compares the same largest-component index and three quantized integers
that `write_quat` emits.

**A test harness's "link" is one tick longer each way than it says** if it delivers packets
after both worlds tick (`gun_link`, `big_guns`, `shell_prediction`): a packet sent after tick
T is first used on tick T + link + 1. `tests/input_window.gd` delivers before the receiver
ticks, which is the exact link.

### A LEVEL CAN ASK FOR A LINK, AND 80 MS MEANS 80 MS ONE WAY

Asked for on 2026-09-17: *"assuming 80ms of lag, how many craft can i support with 80ms of lag"*. Before a craft count
could be measured at 80 ms, **80 ms had to mean one thing**. `Net.extra_latency_ms` delays a machine's sends AND its
receives, so ONE machine's edge is crossed once in each direction:

| host holds | joiner holds | one way | round trip |
|---|---|---|---|
| 0 | 80 | 80 ms | 160 ms |
| 80 | 80 | 160 ms | 320 ms |

The same number meaning twice the lag. (`bulk_peers`' "50 ms at both socket edges on each joiner" is the second row:
100 ms one way.) **So the level asks, and the HOST HOLDS NONE OF IT** -- which is what makes the level's number the
one-way link between any two machines in the session.

- **`levels/stress/level.json` says `"link_ms": 80`.** It is an optional `LevelChart` key, 0 to
  `Net.EXTRA_LATENCY_MOST_MS`, refused in the level's own words if it is fractional or past that. Every level that says
  nothing asks for none, so no existing level's `content_hash` moved.
- **It is in the hash**, so a host and a joiner cannot fly one level over two different links.
- **`Net.suit_the_link` applies it at every build** (`Sky._build`), so a machine that walks out of the stress level
  walks out of the link. `Net.link_for` is the rule, pure and testable: a chosen link stands; a host and a machine on
  no socket hold none; everybody else holds the level's.
- **A person's choice beats it** -- `--latency=`, or the clipboard's LINK row, which now offers 80. That is
  `Net.level_chosen`'s shape and `Finish._chosen`'s: move an UNCHOSEN setting to the default of what is about to
  happen, leave a chosen one where the person put it.

**THE HOST'S ROW ON A STATS BOARD READS NO LATENCY AT ALL, AND THAT IS CORRECT.** The host's client is in the host's
process and never goes near a socket. A host pressing LINK lengthens every JOINER's link and none of its own; the words
on the board say so, because a zero in a table is read as a measurement and a sentence is read as a fact. The sentence
that was there before -- "This machine's link is now N ms each way" -- described something the code does not do.

**MEASURED** (`tests/link_ms`, a host and two joiners in three processes on the stress level, wall clock, no
`--fixed-fps` on the children):

| | latency_frames |
|---|---|
| the joiner on the level's 80 ms | 11.0 |
| the joiner told `--latency=0` | 0.0 |
| the host, to itself | 0.0 |
| the difference | **11.0 frames, 91.7 ms one way at 120 Hz** |

**80 ms injected reads as about 92 ms of link, and the extra frame and a bit is real**: a packet cannot be used on the
tick it arrives, which is the same effect `gun_link` and `big_guns` record as "a harness's link is one tick longer each
way than it says". **Quote both numbers, never one.** The datum is sync's own estimate, made in C++ from server frame
numbers -- not the milliseconds GDScript put on the wire, which would have been the injector asked what it injected.

**A DIFFERENCE CANCELS WHAT IS COMMON TO BOTH SIDES, INCLUDING A FAULT THAT IS COMMON TO BOTH SIDES.** The headline
datum is the gap between the two joiners, which is why desk load does not move it. The mutation that gave the HOST the
level's link too was therefore invisible to it: the joiner read 21.0 frames and the `--latency=0` joiner read 11.0, and
**the difference was 10.0, inside the window**. Only `the_host_adds_no_delay_of_its_own` and
`the_host_measures_no_link_to_itself` went red. Anything a differenced datum divides out has to be checked on its own.

| mutation | red |
|---|---|
| `link_for` ignores the level's link | `rule_a_joiner_holds_the_whole_of_it`, `the_level_puts_its_own_link_on_a_joiner`, and the measurement: 1.0 frame against 11.0 |
| the host holds the level's link too | `rule_the_host_holds_none_of_it` and `the_host_adds_no_delay_of_its_own`; the joiner measured 21.0 frames, and the difference did NOT catch it |

**Found while writing the suite**: its own guard after the join check asked `_failed`, the whole suite's flag, so a red
in the pure-rule section skipped the twenty-second socket round that carries the number. A section's guard asks its own
section's question.

### HOW MANY CRAFT AT 80 MS: ABOUT 300 AT EIGHT PLAYERS, AND THE LIMIT IS REPLICATION

Asked on 2026-09-17: *"assuming 80ms of lag, how many craft can i support with 80ms of lag"*. `tests/stress_sweep` is
the answer, a probe with no verdict, fifteen cells at **link 10 ticks each way -- 83.3 ms one way, 166.7 ms round
trip**, because a link is a whole number of ticks and 80 ms is not one. The sphere is on at the game's own 10 km.

| craft | 2 peers (TRACED) | 4 peers | 8 peers | receipts a second a craft | gap | buffer |
|---:|---:|---:|---:|---:|---:|---:|
| 100 | 2.64 | 1.57 | 2.78 | 75-81 | 2 | 11 |
| 200 | 4.87 | 3.21 | 5.22 | 40-41 | 3-4 | 11 |
| 300 | 7.59 | 4.60 | 7.86 | 27 | 5 | 11 |
| 400 | 9.88 | 6.08 | **10.25** | 20 | 6 | 11 |
| 600 | 16.92 | **8.89** | **15.24** | 14 | 9 | 11 |

Server tick p99 in milliseconds against a **8.33 ms** budget; bold is over it.

**THE TWO-PEER COLUMN IS TRACED AND IS NOT A CEILING.** `crowd` traces the server whenever there are two clients or
fewer (`trace_one_client = force_trace or clients_wanted <= 2`), and a traced tick is about twice a production one --
13.08 ms against 7.35 at 600 craft. This section's first draft read that column as the answer. `stress_sweep` prints
`traced=yes|no` on every row now, from crowd's own `timing_valid`.

**THE ANSWER.** At 83 ms one way, on this machine, with the stack's craft and the island's own traffic:
- **eight players: about 300 craft.** 300 keeps the tick at a 7.86 ms p99; 400 does not, at 10.25.
- **four players: about 500.** 400 is comfortable at 6.08 and 600 is over at 8.89.
- **two players: past the stack's 600 cap.**

**AND 80 MS ITSELF COSTS A CONSTANT, WHICH IS THE HALF A PLAYER FEELS.** The interpolation buffer settled on **11
frames in all fifteen cells** -- 100 craft or 600, two players or eight, traced or not. That is **91.7 ms of lag on
everything a machine does not predict**, fixed by the link and not by the load. A player will call it floaty, and
adding traffic does not make it floatier.

**THE WIRE IS NOT WHAT BREAKS.** The worst update gap is 9 ticks at 600 craft against an 11-frame buffer, and it fits
at every rung. Each craft still arrives 14 to 41 times a second, which is the budget binding exactly as
"200 CRAFT ARRIVE ONE TICK IN THREE" describes -- but a gap inside the buffer is not a defect a player sees.

**WHAT THE TICK IS MADE OF, and this is the actionable half** (`stress_sweep --breakdown`, one diagnostic cell at 400
craft x 8 peers, kept OUT of the grid because `set_tick_breakdown` costs 7-8 per cent of what it times):

    server_tick=9279 us over 1800 ticks
    sync=8441 us (91%)  step=312 (3%)  forces=204 (2%)  ground=170 (2%)  control=80 (1%)
    display=66 (1%)  after=47 (1%)  guidance=46 (0%)  air=44 (0%)  mixers=34 (0%)
    readback=25 (0%)  chores=13 (0%)

**Ninety-one per cent of the host's tick is replication.** Every autopilot, every force, the whole Box3D step, the
chore rota and the display come to nine. Fitting the two untraced columns gives **about 2.4 us a craft of simulation
plus about 2.6 us a craft FOR EVERY PEER**, so the tick is `craft x peers` and the ceiling halves each time the
players double. `rota_probe`'s conclusion that "five thousand autopilots is a physics and replication problem before it
is an AI one" is right, and at this scale it is a replication problem first by an order of magnitude.

**And the shape of that cost is already filed upstream.** `../../learnings/2026-09-17-sphere.md`: sync's `send_client`
serialises EVERY dirty candidate every tick -- quantized, delta-encoded, retained -- and only then asks whether the
record fits the budget, dropping what does not. Server CPU is therefore `dirty entities x clients` regardless of the
budget, while the bytes are capped by it. At 400 craft and 8 peers the wire carries about a third of what is
serialised. **That is the fix that would move this ceiling**, and it is upstream rather than here.

**THE SPHERE IS SWITCHED ON AND DOING NOTHING AT THIS GEOMETRY**, which the table says per cell: `near` is 101, 201,
301, 401, 601 and `far` is 0 in every one. The stack flies a 2.8 km ring round the island centre and `crowd` seats its
players 400 m from that centre, so every craft is inside every player's 10 km sphere. To make it bind, either fly the
players away from the stack or cut the radius -- `--priority-radius=1000` splits this scene about 1:2 and
`tests/priority_sphere` measures the effect. It is a lever for a big world, not for a crowd on one ring.

**WHAT THIS DOES NOT MEASURE.** Every world is in ONE PROCESS behind an exact tick queue, so there is no ENet
sequencing, no MTU fragmentation, no OS scheduling and no jitter: the grid is repeatable and comparable with itself,
and `net_stats` and `bulk_peers` are the real-socket checks. **What a headset can DRAW at these counts is not measured
at all** -- a headless gate has no renderer, and the client-side ceiling may well be lower than the server's.
**`set_send_budget` was left at its 245 kB/s default for every cell**; raising it moves everything above, and it is
only read at `start`.

### THE 200-AIRCRAFT HOLDING STACK IS A MEASURED PRODUCTION RUNG

Item 10 added `HoldingStack` and the TRAFFIC page's LOAD TEST section. The host can ask for
0, 50, 100 or 200 aeroplanes, or move in tens; every aircraft is a real authoritative
autopilot held in one of ten altitude layers. A client pressing the same control is refused
in words. LINK adds 0/50/100/200 ms at both ENet socket edges on this machine; the host's
own in-process client is deliberately untouched. `--stack=200`, `--latency=50` and
`--report=1` expose those same paths to the real-process gate.

`tests/bulk_probe.tscn -- --ladder=full` ran the complete 24-cell ladder on 2026-09-16.
Every cell settled for 600 ticks and measured 1,200 at 120 Hz. Downstream and upstream are
per client; tick is the fastest mean of five blocks. The two-peer rows have component
tracing on and therefore do not price a production tick; the four- and eight-peer rows do.

| link | craft | peers | down kB/s | up kB/s | packets/tick | server out kB/s | server tick ms / p99 |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 8 | 0 | 2 | 16.1 | 43.8 | 1.00 | 32.1 | 0.067 / 0.112 (traced) |
| 8 | 50 | 2 | 188.8 | 44.0 | 2.00 | 377.6 | 0.908 / 1.410 (traced) |
| 8 | 100 | 2 | 245.5 | 44.0 | 2.00 | 491.0 | 2.330 / 3.784 (traced) |
| 8 | 200 | 2 | 246.6 | 44.0 | 2.00 | 493.2 | 4.387 / 6.075 (traced) |
| 8 | 0 | 4 | 24.1 | 43.8 | 1.00 | 96.6 | 0.135 / 0.162 |
| 8 | 50 | 4 | 196.9 | 44.0 | 2.00 | 787.6 | 0.666 / 1.229 |
| 8 | 100 | 4 | 246.8 | 44.0 | 2.00 | 987.2 | 1.482 / 1.793 |
| 8 | 200 | 4 | 247.3 | 44.0 | 2.00 | 989.3 | 2.593 / 3.269 |
| 8 | 0 | 8 | 40.3 | 43.8 | 1.00 | 322.6 | 0.218 / 0.355 |
| 8 | 50 | 8 | 213.1 | 44.0 | 2.00 | 1,704.6 | 1.369 / 1.772 |
| 8 | 100 | 8 | 246.4 | 44.0 | 2.00 | 1,971.0 | 2.659 / 3.169 |
| 8 | 200 | 8 | 247.6 | 44.0 | 2.00 | 1,981.1 | 4.528 / 5.607 |
| 16 | 0 | 2 | 18.9 | 43.8 | 1.00 | 37.8 | 0.124 / 0.147 (traced) |
| 16 | 50 | 2 | 211.5 | 44.0 | 2.00 | 423.1 | 1.093 / 1.746 (traced) |
| 16 | 100 | 2 | 245.0 | 44.0 | 2.00 | 490.0 | 1.870 / 3.320 (traced) |
| 16 | 200 | 2 | 247.2 | 44.0 | 2.00 | 494.4 | 3.927 / 6.166 (traced) |
| 16 | 0 | 4 | 29.3 | 43.8 | 1.00 | 117.2 | 0.084 / 0.122 |
| 16 | 50 | 4 | 221.9 | 44.0 | 2.00 | 887.5 | 0.554 / 0.709 |
| 16 | 100 | 4 | 244.3 | 44.0 | 2.00 | 977.3 | 1.020 / 1.384 |
| 16 | 200 | 4 | 247.2 | 44.0 | 2.00 | 988.9 | 1.905 / 3.832 |
| 16 | 0 | 8 | 50.2 | 43.8 | 1.00 | 401.4 | 0.227 / 0.382 |
| 16 | 50 | 8 | 242.8 | 44.0 | 2.00 | 1,942.8 | 1.018 / 1.370 |
| 16 | 100 | 8 | 247.2 | 44.0 | 2.00 | 1,977.7 | 1.885 / 2.425 |
| 16 | 200 | 8 | 247.5 | 44.0 | 2.00 | 1,980.0 | 3.510 / 7.773 |

The result is a qualified **yes** at 200 aircraft and eight peers on this machine: the
production cell keeps the 8.33 ms tick with 4.53 ms fastest-block mean at link 8 and 3.51
ms at link 16. All 24 cells kept every vehicle, every stack aircraft inside half a layer,
every aircraft above stall, and their buffers flat (9 -> 9 at link 8, 17 -> 17 at link 16).
Packets topped out at exactly 1,200 bytes and the per-client wire plateaued near 247 kB/s;
adding peers grew host upload to 1.98 MB/s. The traced two-peer 200-aircraft cells recorded
no trace drops, no input starvation and no truncation. They also reported "240,000
stack-entity sends" and a one-tick worst update gap. **Both were wrong**, counted from a trace
event that fires for records the budget then drops. Counted where the records land, each craft
arrives about 40 times a second: see the next section. The gate also runs separate
eight-peer trace audits at links 8 and 16 so tracing cannot contaminate the production
timing cells.

`tests/bulk_peers.tscn` then used a real ENet host plus two joiners, each with 50 ms at both
socket edges. Both converged on the host's 281 total vehicles. They received 235.5 and
226.8 kB/s versus the same run's 246.6 kB/s in-process reference, with 1,200-byte largest
carrier packets, stable buffers (17 -> 15 and 12 -> 12), and zero rollbacks in the eight
second window. ENet's official `HOST_TOTAL_RECEIVED_DATA/PACKETS` counters measured 1,024
and 1,015 bytes per UDP packet on average. Godot exposes neither an ENet MTU nor a largest
UDP-packet statistic, so the exact fragmentation invariant is held at the carrier edge and
the socket layer is reported as bytes per packet rather than pretending an unavailable
maximum was measured.

Run the bounded gates with `-Only bulk_load` and `-Only bulk_peers`; run the whole table
with `res://tests/bulk_probe.tscn -- --ladder=full`, or only its six 200-craft cells with
`--ladder=full --only-max`. The rendered evidence is
`screenshots/2026-09-16/holding_stack_200.png` from `holding_stack_shot`. Every launch uses
`--xr-mode off`.

### 200 CRAFT ARRIVE ONE TICK IN THREE, AND THE SPHERE DECIDES WHICH

**This section said "DISTANCE PRIORITY REMAINS RESERVE CAPACITY, NOT A CURRENT FIX", and the measurement under it was
wrong.** It read "The traced two-peer rows sent all 240,000 stack updates with no trace drops and a one-tick worst update
gap ... There is no freshness defect for distance priority". Both numbers came from `tests/crowd.gd::_measure_trace`,
which counted sync's `component_sent` trace event for one client. sync writes that event inside `serialize_entity`, and
its scheduler serialises every dirty candidate every tick BEFORE it checks the budget, then `continue`s past what does not
fit. So the count was what each client was OWED, every craft every tick: 240,000 is 200 x 1,200. Found by `lane/sphere`
on 2026-09-17 when a 67-byte budget "sent" 62 craft a tick. See "MEASURE A SEND ON THE CLIENT" below.

**Fixed.** `crowd.gd` now counts client 0's receipts (`CockpitWorld::received_frames`, the server frame of each craft's
newest VehicleState) for every craft that client draws and does not predict. The serialised count is kept, labelled
`serialised_gap`. `bulk_load` holds the metric first: 60 craft at 167 B a tick show a received gap of 17 ticks (median
16, predicted 16) where the serialised count says 1.

**Re-measured, 2026-09-17** (`bulk_load --cell=...`, settle 600, measure 1,200 ticks, 120 Hz). The gap is in server
frames between one craft's records, the rate is records a second a craft, and every cell passed:

| craft x peers x link | sphere | near / far craft | worst / median gap | receipts/s a craft (near, far) | wire kB/s | tick ms |
|---|---|---|---|---|---|---|
| 200 x 2 x 8 | off | -- / 201 | 3 / 3 | 41.15 | 246.6 | 3.067 (traced) |
| 200 x 2 x 8 | 2.5 km x4 | 56 / 145 | 5 / 2 | 40.59 (59.94, 33.12) | 245.7 | 3.122 (traced) |
| 200 x 2 x 16 | off | -- / 201 | 4 / 3 | 36.79 | 247.2 | 3.086 (traced) |
| 200 x 2 x 16 | 2.5 km x4 | 55 / 146 | 6 / 4 | 35.90 (49.76, 30.68) | 246.4 | 3.143 (traced) |
| 200 x 8 x 8 | off | -- / 207 | 4 / 3 | 39.98 | 247.6 | 3.145 |
| 200 x 8 x 8 | 2.5 km x4 | 62 / 145 | 5 / 2 | 38.90 (57.43, 30.97) | 247.3 | 2.858 |
| 200 x 8 x 16 | off | -- / 207 | 4 / 3 | 35.32 | 247.5 | 3.178 |
| 200 x 8 x 16 | 2.5 km x4 | 61 / 146 | 6 / 2 | 34.62 (48.23, 28.94) | 247.3 | 2.975 |

**What it settles.**
- **The budget binds at 200 craft.** Each craft is sent about one tick in three (35 to 41 Hz of 120). The rotation is
  fair: the worst gap equals the predicted one, 3 or 4 ticks.
- **It is not yet a defect a player sees.** A 3-to-4-tick gap sits inside the 9-frame buffer the automatic clock settled
  on (17 at link 16). That is why the client-side numbers the old section also reported were clean, and those stand: 0.0%
  frozen on the watched craft, a 99th step 1.0x its median, flat buffers, rollbacks within twice the empty world's.
- **So the sphere is a current lever, not reserve capacity.** With it on, near craft arrive 48 to 60 Hz and far ones 29 to
  33 Hz. The worst gap grows to 5 or 6 ticks, still inside the buffer.
- **At the game's own 10 km it changes nothing at the airfield.** The holding stack flies a 2.8 km ring round the island
  centre and `crowd.gd` seats its players 400 m from that centre, so every craft is near every player. At
  `--priority-radius=1000` only the other player was near (1 near, 200 far), and neither setting splits the stack.
  **2,500 m was used because it is the radius that splits this scene about 1:2.** It is a harness choice, not a
  production setting. In play the split is real once players fly away from the stack.
- **Near is decided at the start of the window, and the craft keep flying.** A craft classed near that orbits out
  arrives at the outside rate for the rest of it. That is why near is 1.5 to 1.9 times far here rather than the 3.75 a
  still geometry gives (`tests/priority_sphere`). The worst near gap equal to the worst far one is the same effect.

**`bandwidth_limit_bytes_per_tick` is still one number** (`set_send_budget`). Raising it is the whole of "give each client
more", and the adaptive controller beside it will discover per-client what the link will carry.

### THE PRIORITY SPHERE: WHAT IS NEAR YOUR CRAFT IS SENT TO YOU MORE OFTEN

Built 2026-09-17 (`lane/sphere`) because the user asked for it: *"a sphere prioritizer that should allow me to prioritize
all craft within a distance, let's make it 10km to start ... make sure we test that it works and can easily tweak values
on it as we build."* **It is on in the game.** Craft within 10 km of a machine's own craft go to that machine at priority
4, and everything else at 1.0, which is what everything had before.

**Changing it, which is what this paragraph is for.**
- **The defaults** are in one place, the `PRIORITY_*` constants in `autoload/sim.gd`: `PRIORITY_SPHERE_ON`,
  `PRIORITY_RADIUS_M`, `PRIORITY_INSIDE`, `PRIORITY_OUTSIDE` and `PRIORITY_FALLOFF` (`Sim.Falloff.FLAT` or `LINEAR`).
  Nothing in C++ repeats them. A bare CockpitWorld starts with the sphere OFF and every priority 1.0.
- **For one run**, after the bare `--`, on the host (a joiner's own setting does nothing):

      Godot --path cockpit -- --host=7777 --priority-radius=5000 --priority-inside=8
      Godot --path cockpit -- --host=7777 --priority-off
      Godot --path cockpit -- --host=7777 --priority-falloff=linear --priority-outside=0.5

  A value that is not a number, or is below the floor, is warned about and left at the constant.
- **Live, while networked:** `Sim.set_priority_sphere(enabled, radius_m, inside, outside, falloff)` returns `""` when it
  is in force, or the words to show whoever asked. A joiner gets "Only the host decides what is sent first." It
  reaches every answer within four ticks, because sync asks again on each entity's 4-frame bucket. The setting is kept
  across a level change.
- **The suites, with other numbers:**

      Godot --headless --xr-mode off --path cockpit res://tests/priority_sphere.tscn -- --priority-inside=8
      Godot --headless --xr-mode off --path cockpit res://tests/bulk_load.tscn -- --cell=200,8,8 --sphere=on --priority-radius=1000
      tests\run_all.ps1 -Only priority

  `-Only` matches a part of a name, so `priority` runs both. `priority_sphere`'s effect half runs on `Sim.priority_sphere`, so the flags change what it measures and its replayed
  prediction follows them. Its geometry fits a radius up to 14 km and says so past that. `bulk_load`'s `--sphere=on`
  prices the same setting and prints `prioritizer_calls_tick` and `prioritizer_ns_call`.
- **Seeing it:** the host's status line and the LOAD TEST line on the clipboard say `sphere 10 km x4, 12 near`.
  SESSION_REPORT says `sphere=on:10000:4:1:flat near=<client>:<craft inside>,...` and `served=<the host server's
  vehicles>`. `Sim.server.priority_sphere()` returns all of it as a Dictionary. `priority_of(client, entity)` is the
  number the prioritizer gives.

**THE RULE.** `CockpitWorld::priority_decision`, which sync's prioritizer calls and which `priority_of` calls too.
- **A cabin first, exactly as before:** the largest float to its owner, zero (withheld) to everybody else.
- **Each client's centre** is its craft's VehicleState, from `seat_of_`, filled once a tick into a 256-entry table
  before `server_->tick`. A client in no seat has no centre and is given the outside priority for everything.
- **Craft, ships, trains, missiles, rounds and fires** go by their own position.
- **Pilots and seekers** go by where their client's craft is, so a copilot's hands in your craft are never behind the
  traffic near you.
- **A room page**, which has no position and which nobody is far from, is inside.
- **FLAT** gives `inside` within the radius. **LINEAR** gives `inside` at your craft, falling to `outside` at the edge.

**A PRIORITY IS A RATE, NEVER A FILTER.** Each tick sync adds a dirty entity's priority to its accumulator. It sends the
largest first until the client's budget is spent, and zeroes what it sent
(`ashiato-sync/src/server/client_update_scheduler.cpp`). So the sphere does nothing while everything fits, and under a
shortage an inside craft is chosen about k times as often:
- An entity at priority p is sent every A/p ticks, where A = (k x inside + outside) / updates that fit a tick.
- That holds for as long as A/k is at least one tick.
- Zero or less withholds (since ashiato-sync 8fa08cf; NaN before it, and NaN now throws in an assert build), and a
  withheld craft keeps its last copy on that machine for good (`../../ashiato-gd/LEARNINGS.md`, "A relevance that closes
  sends nothing"). **So the setter refuses NaN, zero and negatives.** It also refuses anything
  over 1000 (a cabin's float max stays first), a radius outside 0 to 1,000 km, and an unknown falloff.

**Why 4 and not 8.** At today's 245 kB/s, about 104 craft updates fit a tick:

| a 2,000-craft world | no sphere | inside 4 | inside 8 |
|---|---|---|---|
| 30 of them near you | 6.2 Hz each | near 24 Hz, far 6.0 Hz | near 46 Hz, far 5.8 Hz |
| 200 of them near you | 6.2 Hz each | near 19 Hz, far 4.8 Hz | near 29 Hz, far 3.7 Hz |

A 5-tick wait still sits inside the automatic buffer, and 4 does not gut the far world when a crowd is near.

**WHAT IT DOES, MEASURED** (`tests/priority_sphere`, in one process on an exact pump). The client's craft is 20 km from
the origin. 30 moving craft are 2 to 8 km from it, and 30 are near the origin. The budget is cut from a calibration run
to 33,750 B/s, which carries 9.00 of 61 dirty entities a tick. Receipts are counted on the client:

| | inside | outside | ratio |
|---|---|---|---|
| sphere off | 17.71 Hz | 17.62 Hz | 1.005 |
| sphere on, inside 4 | 27.63 Hz | 7.37 Hz | **3.749** |
| sync's accumulator replayed on that run's own sends a tick | 27.64 Hz | 7.36 Hz | 3.753 |
| `-- --priority-inside=8`: measured, then replayed | 30.16 Hz | 4.80 Hz | **6.283**, replay 6.289 |
| `Sim.set_priority_sphere` inside 4 -> 1, halfway through | | | 3.743, then 1.005 |
| a child process with `--priority-inside=1` | | | 1.005 |

**THE PREDICTION IS REPLAYED, NOT k.** A send lands on a whole tick, an accumulator holds whole multiples of p, and
equal accumulators are broken by sync's slot order. At 31 inside and 30 outside:
- 20 updates a tick gives 3.33, and 22 gives 2.58, where the continuous answer is 4.0.
- Replayed in the CLIENT's arrival order instead of the server's slot order, the same run predicted 3.975 against
  3.749 measured.

So the suite records how many craft arrived each tick, and replays add, stable sort, send the top M and zero in server
entity order. The measured ratio must sit within 3% of that replay. With the sphere off it must be within 5% of 1.

**Mutations, each red on its own check** (double DLL rebuilt for each, then restored):

| mutation | red |
|---|---|
| the centre is the world origin | `a_craft_9_9_km_away_is_inside` and six other rule checks; the effect inverted, 7.42 Hz inside against 28.33 Hz outside, ratio 0.262 |
| NaN outside the radius | `no_craft_or_pilot_is_ever_withheld`; the client never drew one of the 30 outside craft. In `priority_peers`, the host served 133 while host and joiner both drew 27 |
| the inside priority not applied | `a_craft_9_9_km_away_is_inside` and `on_craft_inside_the_sphere_are_sent_more_often` (1.005) |
| the setter ignored once the server has ticked | `live_after_the_change_both_groups_are_sent_alike` (3.760 after the change); the runs that start with their sphere stay green at 3.749 |

**OVER A REAL SOCKET** (`tests/priority_peers`): an ENet host with `--stack=50 --priority-radius=1000` and a joiner with
`--freshness=1`.
- The 2.8 km stack puts 4 moving craft near the joiner and 104 far.
- The joiner draws all 133 vehicles the host SERVES. The host's own `vehicles` is what its CLIENT draws, and under the
  NaN mutation that was short too.
- Freshness, not motion: parked craft are never sent because they never change. Of the craft moving faster than 5 m/s,
  the stalest far one was 1 tick old and the stalest near one 0, against a bound of 2 x ceil(A) + 4 = 8 at 64.98
  records a tick.

**WHAT IT COSTS** (`bulk_load` 200 craft x 8 peers, three alternating rounds, fastest-block mean):
- Every run made 506 prioritizer calls a tick, at 9.6 ns a call off (one try_get, as before) and 23.8 ns on. That is 5
  and 12 us a tick.
- The tick itself: link 8 off 3.119 ms and on 3.140; link 16 off 3.170 and on 3.184; main's library 3.089 and 3.158.
  The differences are within the rounds' spread.
- At 2,000 craft and 8 clients, sync would ask about 4,000 times a tick, about 0.1 ms.

**MEASURE A SEND ON THE CLIENT, NEVER WITH `component_sent`.** `tests/bulk_load` did, until 2026-09-17; see "200 CRAFT
ARRIVE ONE TICK IN THREE". sync writes that trace event inside
`UpdateWriter::serialize_entity` (`ashiato-sync/src/server.cpp`). The scheduler serialises every dirty candidate every
tick, then asks whether the record fits the budget. So `component_sent` counts what a client was OWED, not what it was
sent. At 67 B a tick over 61 moving planes, the server traced 62 a tick, 50 bytes a tick went out, and the client
received about one. `CockpitWorld::received_frames()` keeps, on a client with tracing on, the server frame of each
craft's newest VehicleState record and a count, without a Dictionary per event (`set_receipts_only`). `--freshness=1`
turns it on for a game process and prints a FRESHNESS line beside SESSION_REPORT.

**WHAT A MACHINE CAN SAY ABOUT ITS OWN LINK, for a stats table somebody else reads.** Every one of these is a
Dictionary from GDScript, cheap enough to ask once a second, and none of them needs a suite around it. A client asks its
OWN world (`Sim.client`); only the host has `Sim.server`.

| ask | on | what comes back |
|---|---|---|
| `Sim.client.received_frames()` | client | `{frames: {entity: server frame of that craft's newest VehicleState}, newest: the newest frame of any, count: every record received}`. **Updates received** is `count`; a craft's staleness is `newest - frames[entity]`; the rate over a window is the change in `count` over the change in `newest`. Empty unless tracing was on at `start` -- see below. |
| `Sim.client.resim_stats()` | client | `{count, ticks, worst_span, last_from, last_to, last_span}`. **Rollbacks** is `count` and **ticks resimulated** is `ticks`, both since the session started, so take differences. |
| `Sim.client.timing()` | client | `{latency_frames, jitter_frames, buffer_frames, buffer_target, prediction_lead, packets_received, packets_missing, estimated_server_frame, ...}` plus `input_frames_max` (the protocol's 31), `input_packets_truncated` and `input_frames_truncated`. **An estimated latency in ms** is `latency_frames / Sim.tick_hz * 1000.0`, which is sync's own measurement of the link and not a ping this game sends. |
| `Sim.client.net_status()` | either | `{bytes_in_per_second, bytes_out_per_second, send_budget_per_second, send_budget_per_tick, tick_rate, buffer_frames, clients, ready, client_id}`. |
| `Sim.server.priority_sphere()` | host | the setting, `in_force`, `calls` and `ticks` (the prioritizer's calls since start), and `near: {client id: craft inside its sphere}` -- **per client, from the host**. |
| `Sim.server.priority_of(client, entity)` | host | the priority that client would be given for that entity. |
| `Sim.server.vehicle_states().size()` | host | what the server actually has, which SESSION_REPORT prints as `served=`. `Sim.client.vehicle_states().size()` is what a machine DRAWS, and under a prioritizer the two differ on the host as well. |
| `Sim.client_of_peer(peer)` / `Sim.local_client_id()` | either | which sync client is on which Godot peer, so a table can be keyed by player. |

**RECEIPTS COST NOTHING UNLESS ASKED FOR, AND THEY ARE OFF BY DEFAULT.** `received_frames` is filled from sync's trace
callback, so the client world needs `set_tracing(true)` before `start`. `set_receipts_only(true)` then keeps the receipts
and builds no Dictionary per event, which matters because a joined machine at a hundred craft sees about 700 events a
tick. `Sim.start` does both when the command line has `--freshness=1`; a level that wants them always should ask Sim for
them at start rather than turning tracing on afterwards, which records nothing.

**Rejected:**
- NaN beyond the radius: it freezes.
- Zero beyond the radius: it freezes under a steady shortage.
- A component mask for far craft: its reopening needed a sync patch, and a closed mask keeps a stale copy.
- Finding a client's craft by scanning the registry on every call.
- The balls example's shape, `1 + 1000 * normalized` from the world origin: one centre for every client, and a
  1000:1 ratio that would stop the far world whenever the near one is busy.

### A FAR PLAYER'S HEAD AND HANDS ARE NOT SENT: THE POSE LOD (lane/ashiato-latest, 2026-09-18), OFF BY DEFAULT

Asked on 2026-09-18, about distance LOD: **"yeah, research and test it, see what you find out."** What it found is
that almost nothing on a far CRAFT is worth withholding, and one thing on a far PLAYER is.

**Where the bytes are.** A craft's VehicleState is 94% of what a client is sent (`wire_budget`); its controls,
systems, route, rigging and bus pages together are under 2%, Step, and visible from far off -- lights at night, gear,
sails, a signal lamp's craft channel. The stream nobody had priced is **PilotState**: every player's head, both hands
and grips, about 240 bits, not delta-coded, and a change on every tick in VR. `crowd` and `player_load` had always flown
with still poses, so it never showed.

**ON THE HOST'S iPAD: TRAFFIC's SAVE BANDWIDTH switch, OFF BY DEFAULT.** The user, 2026-09-18: "let's keep bandwidth
saving off by default, but make it an option in the ipad." Shown only where `Sim.decides_what_is_sent()` (the host, or
alone); `Sim.set_save_bandwidth` refuses a joiner in words, sets the server's LOD live at `Sim.POSE_NEAR_M`/`POSE_FAR_M`,
and keeps the choice in `host_settings.json` in the player's folder (a suite's own under a test scene, as
`spotting.json`), read at boot and handed to every server start
(`tests/save_bandwidth.gd`; the joiner's half in `tests/sky_peers.gd`).

**`CockpitWorld.set_pose_lod(enabled, near_m, far_m)`** tells sync to leave PilotState out of what a client is sent for
a pilot whose craft is more than `far_m` from that client's own, and put it back inside `near_m` (250 and 350 m for the
experiment). It is a component MASK, not a filter: the pilot's record still goes, with PilotOwner in it, so every
machine still knows who the pilot is and which peer they came on, and a far pilot costs a few bytes a tick instead of
about thirty. Reopening a mask makes sync send a full record, so a pilot coming near is drawn live from the first
record. **Never masked**: your own pilot, crew in your craft, anybody sitting nowhere, and a client
`set_pose_live(client, true)` holds live -- a signal lamp in hand, whose far beam lane/lightgun draws from the hand
pose. `pose_lod()` reports the setting, the masked pairs and who is held live; `pose_masked(viewer, client)` is the rule
asked directly.

**`pilot_states()` lists every pilot off PilotOwner**, with `posed` saying whether its poses are real. A far pilot whose
PilotState never arrived would otherwise have dropped out of `Sim.pilots`, and with it out of the crew manifest and the
sky's lists. Unposed, a pilot is drawn at rest, which at 350 m nobody can see.

**Only PilotState, because of a rule in sync.** Once a client has acknowledged an entity, sync does not ask the decider
about it again until it changes. So a STEP component masked while far -- a parked craft's lights, a desktop player's
seat -- can stay stale on that client for good however close it comes. Poses move every tick and heal; nothing Step is
masked. The seat a pilot is drawn in comes from the craft's `Seats`, never from PilotState, so a masked seat cannot
misplace anybody (`tests/pose_lod.gd`, `the_trap_stale_seat`).

**Measured, `tests/player_load.tscn -- --tracked [--pose-lod=on] [--budget=20000000]`**: `--tracked` moves every head
and hand every tick; `--budget` lifts the 245 kB/s cap so the cell shows what it DEMANDS. Down kB/s a client, no AI
craft; the bytes are exact, the machine was busy:

| players | still poses (seats) | moving poses | moving, pose LOD on | pairs masked |
|---|---|---|---|---|
| 8 | 39.4 | 67.4 | 45.0 | 56 of 56 |
| 16 | 71.7 | 127.8 | 84.0 | 202 of 240 |
| 32 | 136.4 | 254.1 | 160.1 | 890 of 992 |
| 64 | 247.7 (capped) | 506.6 | 313.4 | 3,592 of 4,032 |

About a third off at every size: at 32 moving players a client fits back under the budget. With 200 AI craft the budget
is already full, so the saving shows as fresher craft: receipts a second a craft 38.5 -> 40.0 at 8 players, 35.2 -> 37.8
at 16, 30.5 -> 34.4 at 32, 24.3 -> 29.1 at 64, worst gap unchanged. **The host tick does not fall**: a masked pilot is
still serialised (5.39 against 5.26 ms at 32 players uncapped), so host CPU is the refusal bound's job, not this.

**Upload is the other finding.** With moving poses a client sends 72.5 kB/s where still poses sent 13: every input
frame carries three changing poses, and since ashiato-sync 8fa08cf a packet repeats up to 31 of them. At 64 players the
host takes 4.6 MB/s in. The pose LOD does not touch that.

`tests/pose_lod.gd` holds six things: far poses not sent while the far pilot is listed and its craft arrives; a pilot
coming near drawn live from inside `near_m` plus the four-tick bucket and the link, and masked once going away; the seat
trap; crew never masked; a far craft's lights, and a lamp held live at 3 km; the boundary's hysteresis and a bad
setting refused. Every zero it counts has the LOD-off control beside it.

### THE BUFFER IS FREE ON THE WIRE, AND IT IS ONE NUMBER FOR THE WHOLE WORLD

Deepening the interpolation buffer costs NOTHING in bandwidth. Measured over a starved
world -- four clients, 408 entities, 100 ms -- every depth from 3 frames to 63 sent exactly
123.9 kB/s per client and produced exactly the same rollback rate. The only thing that
moved was smoothness: the 99th-percentile step of a watched aircraft against its median
step went 1.5x at three frames, 1.1x at twelve, 1.0x at twenty-four. That residual stutter
is the buffer running out of future samples on an entity the server is no longer sending
every tick, which is the condition every entity is in once the crowd is big enough.

**`;` and `'` change it live**, beside `[` and `]` for the tick rate, and the status line
reports what the clock settled on rather than what was asked for. Unlike the tick rate it
is allowed while networked, because it is per-machine and no other peer can tell.

`Sim.MAX_BUFFER_FRAMES` was 12 and is now **63**. The ceiling is not taste: sync's
`buffered_frame_lag_capacity` is 64 and it validates with `>=` by THROWING, so asking a
CockpitWorld for 64 puts `std::invalid_argument` through `start`, where the binding does
not catch it, and the process is gone. `set_buffer_frames` is guarded and
`set_interpolation` is not, because the latter only stores the number and the throw
happens later. **That is a live crash on bad input and the clamp is the only thing in
front of it.**

AUTOMATIC MODE ALREADY RAISES IT, and sizes from measured JITTER -- see
`auto_buffered_frame_lag_jitter_multiplier`, which is 2.0. Asked for 3, the clock settles
on 7; at 30 ms of jitter it reaches 10, at 60 ms it reaches 13. Ask for more than it would
have chosen and your number is what holds, in automatic mode as well as manual. So
deepening the buffer is genuinely one call, and jitter is the one thing it already handles
without being told.

What it does NOT handle is starvation, because sparse arrivals are not jitter: an entity
sent every eighth tick arrives perfectly regularly. That is why the clock sat at 7 frames
in the 408-entity world above while the aircraft it was drawing needed 12.

**The cost is lag on everything this machine does not predict**: `frames / tick_hz`
seconds, on top of the link. Twelve frames at 120 Hz is another tenth of a second on every
other aircraft in the sky. That is cheap for traffic four kilometres away and expensive for
the one you are formating on -- and there is no way to say so, because the buffer is one
number for the whole world and not a number per entity. A far vehicle can be drawn
further into the past than a near one for nothing, since nothing about it is interactive;
sync has no per-entity interpolation delay today, so that is the piece to add. Update rate
and buffer depth are the same decision and have to move together.

### A JOINED MACHINE DREW EVERY CRAFT HOLDING AND LEAPING, AND THE BUDGET WAS WHY

Found by cockpit-hitjump and measured by cockpit-netjump on 2026-09-14, two real processes over
ENet on the loopback in `sky.tscn` (`tests/net_jump.tscn`, host and joiner). The host's own
simulation had no lone jump in 362,924 craft-ticks; the joiner drew 0.80 per 1000 (worst 49 m)
and a common step on 824 of 7,200 ticks, saw 3 of 3 missiles and 0 of 3 missile ends. The link
was not it (0.9 frames of latency) and neither was Godot's clock (15 of 7,201 ticks doubled).

The chain, in ashiato-gd/LEARNINGS.md: one client was owed 1,847 bytes a tick against sync's
1,024, so each craft was sent every seven to ten ticks; a craft whose next frame had not arrived
when the three-frame buffer reached it HELD, and leapt when the late record landed. A missile
retired three ticks after its end took the unsent end with it.

**What fills the tick** is `tests/wire_budget.tscn`: solo, the server traced, bytes per component,
parked against moving, and the peak. Before: VehicleState 94% of 1,847 bytes, and the 24 parked
craft 555 of them, because every trait quantized raw floats and float noise below the wire's step
counted as a change. After quantizing through the wire (with the smallest-three tie guard, see
LEARNINGS): 1,315 bytes, parked craft 38; on 4e76324, with the gentler climbs, a peak of 1,359, a
99th percentile of 1,354 and a median of 1,321 against a budget of 1,024.

**The budget is bytes a second** (`set_send_budget`, before start; `net_status` reports
`send_budget_per_second` and `send_budget_per_tick`), because sync's own number is per tick and
halved every client's bandwidth when the tick rate halved. **245 kB/s by default**: 2,042 bytes a
tick at 120 Hz, half again over that peak, 1.96 Mbit/s a client and 5.9 Mbit/s up for a host with
three. It was sync's 1,024 (122 kB/s), at which a joined machine starved.

**A spent round, missile or fire stays on the wire half a second** (`kSpentSeconds`,
`spent_seconds()`), not three ticks, so its end reaches every client before sync forgets it.
The shot yard lands a round once (cockpit-guns), because a landed row is now listed for about
60 ticks. `tests/shots` asks the world how long, and checks both sides of it.

`ashiato-gd/addon/tests/crowd_sight` is the check in one process: eighty autopilots, packets
carried the same tick, over a 4-tick link, and over it under fire; no craft may step
more than a quarter of a tick of its own travel, the sky may not step together, every missile
and every missile end must arrive, and the rounding may change no bit a client receives.

**And the two glitches the budget left behind were sync freeing a baseline** (cockpit-joinfix, 2026-09-14). Two
entries sat in WHAT IS NOT HERE YET after the budget and the half-second retire:
- a joined machine that saw no missile for a whole session;
- a parked craft drawn tens of metres off for one tick.

Both had the fingerprint of a component copied from the wrong entity. `ashiato-sync-retain-before-release.patch` (see
`../../ashiato-gd/LEARNINGS.md`) is that bug fixed, and `net_jump` was run against main's library before it (E491DF4E)
and after it (0CD9FB0D) on one machine, six sessions each, interleaved. Every number is from the joiner's summary line.

| six `net_jump` sessions | before | after |
|---|---|---|
| lone jumps over 2 m | 187 in 3,230,095 craft-ticks (29, 0, 22, 0, 9, 127 a session) | 0 in 3,240,030 |
| of those on craft slower than 1 m/s | 56 | 0 |
| blinks | 20 (2, 0, 6, 0, 3, 9) | 0 |
| worst jump | 49.61 m | 0 |
| missiles and missile ends seen | 16 of 18 and 16 of 18 (one session saw 1 missile and no end) | 18 of 18 and 18 of 18 |

**The definitions** (`net_jump.gd:412-426`), counted per event (a craft-tick), not per craft:
- A **lone jump** is a craft drawn more than 2 m from its last tick on a tick when at most one other craft stepped more
  than a tick of its travel.
- A **blink** is a lone jump on a craft slower than 1 m/s that is back within 1 m the next tick.

**Count them from the summary line.** The probe prints only the first six BLINK lines and the first twelve lone jumps,
and a count of lines said 6 where the summary said 9.

**What it settles.**
- **The parked blink is closed.**
- **The lost missiles are closed on weaker evidence.** At the old entry's own rate of two bad sessions in six, six clean
  ones still happen about one time in eleven. A joined machine missing a missile on a library with the patch reopens
  it, and the tombstone suspect in its old entry is where to start.
- **`crowd_lumpy`'s whole-sky steps did not move** (see WHAT IS NOT HERE YET).

## PLAYER NAMES AND COLOURS

`Net` owns the session roster. A client repeats a `{name, colour}` card until the host acknowledges it; the host waits
for sync to map that peer to a client id, validates the proposal, then repeats one revisioned roster until each client
acknowledges it. The current roster also rides the level hello, so a late joiner can label the room while it builds.
Names are printable and at most 16 characters; colours are indices into `PlayerColours.PALETTE`, never free RGB.

Every surface uses `Net.name_of(client_id)` and `Net.colour_of(client_id)`. The map should consume those same calls.
The saved local choice is `user://player.json`; `SteamLobbyDirectory.persona_name()` is consulted only when that
directory has already initialized Steam. Asking for a name must not initialize Steam.

**STEAM NAMES, NOT "PLAYER N" (2026-09-19, lane/buildtime).** The user: "if it's available, we should have players names
pulled from steam (not player 1, player 2)". The persona was already preferred, but a player who hosted or joined by IP,
or flew solo, never started Steam, so they were PLAYER N with Steam running beside them. A joiner's card was also said
once and never again, so Steam starting later changed nothing. Three fixes, in `Net`'s "THE PLAYER'S NAME":
- **Steam starts AT BOOT for a real player, and for nobody else** (`Net.steam_at_boot_refusal`, pure). It needs a
  window, the Steam client running (`isSteamRunning`, which needs no init), no `COCKPIT_TEST_SLOT`, no `res://tests/`
  scene, no `--no-steam`, and no ENet `--host`/`--join=` on the command line. The last is how every multi-instance run
  on one machine starts, and it was the reason for the rule above: two local processes on one account, and nothing
  headless touching the client. So the rule still holds for every suite, probe and second instance; asking for a name
  still never starts Steam. Every run prints `STEAM_AT_BOOT=started, for the player's name` or `STEAM_AT_BOOT=no (why)`.
- **A joiner says its card again when the name it would carry changes** (`Net._keep_my_card`, once a frame, two strings
  compared). So Steam starting by a Steam button after the card went out is a new card within a frame. The host's own
  card is already read afresh every frame.
- **A name the player TYPED wins, across runs.** player.json now holds `typed`. Before, the flag lived for one run, so a
  name typed yesterday lost to Steam today. A name that is the fallback ("PLAYER 3") or the persona itself, pressed OK
  unchanged, is not typed: pinning "PLAYER 3" for ever is the thing that was asked away. A file from before `typed`
  counts its name as typed unless it is the fallback.

Tests: `names` puts eight launch cases through the refusal, and asks this process, which says "headless". It also
drives a typed name through a save and a reload against a persona. `names_peers` adds CAROL, a headless joiner with
no typed name and `--pretend-persona=CAROL@heard`, a persona that appears only once the host has acknowledged her
first card. The host publishes four cards twice (n=4 with her fallback, then n=5), every machine ends up with CAROL,
and the host's typed HOST beats its own persona STEAMHOST. Every child prints `STEAM_AT_BOOT=no (headless)`. The
mutants were a card never said again, the typed name losing, and headless allowed; each went red.

The roster and synchronized music share protocol 6. Their compact level-hello forms fit together with a full
eight-player roster (465 bytes in `names`); if an extreme track id pushes that one message past 512 bytes, music is
left out of the level hello and arrives through its acknowledged post-admission message instead. A large optional
audio field must never turn into a join timeout.

Validation on 2026-09-16: `names` passed validator, real LineEdit/swatch and RemotePilot surface checks;
`names_peers` passed with host + initial joiner + late joiner converging over real ENet; `level_hello`, `clipboard`,
`notices`, and `lobby` remained green. All launches used `--xr-mode off`. Visual evidence:
`screenshots/2026-09-16/cockpit-item15-names.png`.

## THE FLAT 2D VOICE LOBBY: A ROOM WITH NO WORLD IN IT (lane/voicelobby, 2026-09-19)

The user: *"I need a level, that doesn't use VR, that allows me to join a steam game (and host one) and i can just test
voice and ai voice. So it will need a player lobby with text chat, and a player list and player names ... we'll need a
different entry point and .bat so i can test it on other machines."*

`voicelobby.bat` -> `tools/voice_lobby.ps1` -> `--level=voice`, which `BootRouter` routes to `world/flat_lobby.tscn`
(`voice`, `lobby2d` and `flat` all reach it). Sound is on, XR is off explicitly, and the room is a `Control` tree: the
first flat scene in cockpit. It is a `Control` and not a `Node2D` because the lobby lane (2026-09-15) listed "the
mouse in 2D" as unsolved here and a `Control` solves it by existing.

**IT OWNS ALMOST NOTHING.** Host and join are `SessionMenu`, unchanged, acted on with the same mapping `world/desk.gd`
uses. The player list is `Net.roster_cards()`. Who joined and left is `Net.notice_words()`. Teams are `Net.team_of` /
`Net.set_team` over `TeamBoard`'s rules. Chat is `Net.say_in_chat` / `Net.chat_arrived`.

**A SESSION NOW LANDS AT THE DOOR IT ASKED FOR.** `_start_the_session` ended in `_go(WORLD)` whatever `--level=` said,
so `--host --level=voice` flew the island. It now goes through `DOORS`, with the world still the answer for a session
that named no door.

**FOUR THINGS A ROOM WITH NO WORLD HAS TO DO ITSELF, each one measured the hard way.**

1. **`Sim.start()`, because the roster is keyed by sync client id.** `Sim.local_client_id()` answers 0 while
   `Sim.client` is null, so a room with no simulation draws an empty player list however well the session works.
2. **`Net.level_loaded("")`, because that is what admits a joiner.** Until a joiner says `loaded` the host does not
   admit it, and an unadmitted peer's card and chat are never taken. `world/sky.gd` says it at the end of building a
   level; there is no level here, so the room says it with no ground hash.
3. **`Sim.seat_players = false`, because every player otherwise gets a pod.** `_seat_new_clients` gives each arrival
   `level.arrive_kind` at the level's spawn, and `Terrain.highest_near` answers 0 where no terrain was built, so the pods
   fall for ever: two headless peers printed CockpitWorld's *"the wire clamped 33590 position coordinates past its
   range"* once a second, through -1922 m, -3632 m, -5275 m. A harness fails on the first engine error. Set before
   `start`, like `want_receipts`.
4. **`Sim.server_client_of_peer`, because a host was asking the pilots who its players were.** `Sim.client_of_peer`
   reads the peer-to-client pairing off replicated `PilotOwner` components -- which is the only way a JOINER can know,
   since it never saw anybody connect, and useless in a room where nobody has a pilot. The host has its own server,
   which saw the client arrive on the peer (`_on_peer_left` always asked it that way). Measured: the host published a
   roster of one card while the joiner sat there holding client id 2. `Net` now asks the server first and falls back to
   the pilots, so a normal session behaves exactly as it did.

**TEAMS RIDE THE ROSTER CARD** (`TeamBoard`, protocol 40). The host keeps `_teams_by_client` and publishes each player's
team on the card it already publishes, so a team is read from the same place a name and a colour are. `TeamBoard.read`
does NOT clamp a number that is not a team -- it is nobody's team, because a clamp puts somebody on RED by accident --
and `share_a_team` is false for two players on NO team, which a plain `mine == theirs` gets wrong and which is the check
the whole feature turns on. The compact card grew from four elements to five; an older peer drops a five-element card and
takes the whole roster with it, so it is refused on the protocol instead.

**CHAT IS A FOURTH CARRIER, and it had to be.** Every carrier this game has keeps only the LATEST of a thing, because
each carries state: a hello is overwritten by a newer one, a notice is host-only and latest-only (and rejects free text
on purpose), and `LongTransfer.send` replaces the in-flight document of its own kind AND clears its own kind out of the
waiting queue. Type two lines quickly on any of them and the first is gone. So chat keeps the repeat-until-heard shape
and acknowledges a LINE NUMBER: `chat`/`chat_heard` from a peer, `chatline`/`chatline_heard` from the host, one line in
flight each way per peer, a repeat acknowledged and not appended twice. The host is the only place a line gets its number
and its player, so two people typing at once cannot disagree about the order.

**THE LOG IS `Label`s AND IS REBUILT FROM FACTS, NOT FROM SENTENCES.** A chat line is the only free text another
machine's player typed that this game draws, so `RichTextLabel` is out: `[img]` in somebody's message would be markup
this machine obeys. And a line can arrive before the name of whoever typed it -- measured, a joiner's first line reached
the host before its card did and the host drew "PLAYER 3: radio check" and kept saying that. `FlatLobby` keeps the lines
as facts and asks `Net.name_of` again on every redraw, so the board corrects itself when the card lands. The same list
holds the lines said before the scene existed: the boot router starts the session and only then opens the door, so a
`chatline` can land while `Net` is up and the room is not.

**THE HARNESS PRESSES THE BUTTONS.** `--say=<words>` types into the entry field and presses SEND; `--press-team=<NAME>`
presses a row's TEAM button; `--hands-at=<players>` waits until that many are listed. By NAME and not by client id
because sync numbers whichever joiner its packets reach first -- this checkout's run has BOB as 2 and ALICE as 3, and the
first version of the suite named the id and moved the wrong player, on a tick where no row existed at all.

`tests/lobby2d.gd` holds the rules and every refusal; `tests/lobby2d_peers.gd` runs three real processes on ports
48280-48289 and proves all three list all three by name, that the host's team reaches every machine and moves nobody
else, that a client is not even offered a team button, that a line typed on a joiner reaches every machine attributed to
whoever typed it, and that a player whose process is KILLED leaves no row behind.

## LIVE VOICE: A BUTTON, A LABELLED FRAME, AND A HOST THAT DECIDES WHO HEARS IT (lane/voicelobby, 2026-09-20)

The user: *"there should be a button a user holds down to talk to everyone and another that allows them to talk to
their team ... there should also always be a status icon/highlight on a player when they are the one talking"*, and
*"can there be more than one channel of audio from server to client? I might want to play human audio, and ai audio on
different channels, or i may need to mix them myself."*

**THE CHAIN, and every link is replaceable at one end only:**

```
Microphone -> VoiceFrame.encode -> Net (VOICE_BITS) -> the host's routing and team filter -> decode -> Intercom.play
```

**`Microphone` (`net/microphone.gd`) is the seam and is named for it.** It opens an input device, cuts what it hears
into 20 ms pieces and ANNOUNCES them; it knows nothing about a network, a team or a wire. Steam's own capture, if it is
ever wanted, replaces **this object and nothing else** — `tests/voice_probe.gd` measured that `getVoice` yields
compressed bytes and `decompressVoice` turns them into PCM, so either this grows a source that decompresses (everything
downstream untouched) or the compressed bytes travel as they are and `VoiceFrame.Codec.STEAM` says so. Keeping that
door open cost nothing, which is why it is a separate object.

**It is also the seam a test drives.** Whether a microphone on this desk hears anything is a property of the desk, so a
headless suite starts at `Microphone.feed` — the last place the real path is still the real path — and everything after
it is the shipping code.

**A CHANNEL IS A LABEL ON A FRAME, NOT A SEPARATE CONNECTION.** Every frame carries `speaker`, `kind` (LIVE or
GENERATED), `codec`, a sequence and its samples, so a receiver can play the two kinds on separate buses, mix them or
mute one **with no wire change**. The speaking lamp reads the same `speaker` field the audio is labelled with, so the
indicator and the sound cannot disagree.

**TWO CARRIERS UNDERNEATH, ONE LABELLED ARRIVAL POINT ON TOP.** A generated line is a bounded document that must arrive
whole and already travels as a `clip` through `LongTransfer`, measured at 25.98 dB SNR with exact completion through
10% loss; live voice is droppable frames that must never wait for a retry. **Forcing one carrier on both would make the
generated line stutter or the live voice block.** So from a client's side there is exactly one place that says "here is
audio, from this player, of this kind" — `Intercom.heard` — whichever carrier brought it. "Channels I can mix myself"
needs one labelled arrival point, not one transport.

**EVERY FRAME STANDS ALONE.** They ride `_receive_unordered` (the only carrier genuinely unreliable on BOTH transports
— `_receive` is sent Reliable over Steam, which `net.gd` records from GodotSteam's own source), so each frame carries
its own ADPCM seed and decodes without the one before it. A lost frame costs 20 ms; shared predictor state would be
corrupted from the loss to the end of the transmission. 160 samples at 8 kHz is ~94 bytes against a 512-byte hello.

**THE HOST DECIDES WHO HEARS IT, AND STAMPS WHO SPOKE.** The sender says what it INTENDS in the audience byte; the host
writes the speaker from the peer the frame arrived on and filters by `TeamBoard.share_a_team` off the roster. A client
that could name itself could put another player's voice under its own name, and a client that could choose its own
audience could send to a team it is not on.

**THE LAMP IS A PUBLISHED FACT.** `talking`/`talking_heard` carry the host's answer to every machine, published when the
set CHANGES rather than on a heartbeat. A listener on another team receives **none** of a team-talker's audio and must
still light them, because the user asked for an indicator that is always visible. `Net.is_talking` is what a row reads,
and nothing else.

**Two keys and two buttons**: T for everyone, G for your team, plus hold-to-talk buttons for the mouse. Not V — this
project has trained everybody to press that for the headset. `_unhandled_key_input` IS the focus gate (rule 9): a
`LineEdit` with focus eats its own keys, so typing in the chat box does not transmit.

### What the tests hold, and one that did not

`tests/intercom.gd` holds the frame rules and the refusals three honest machines never produce between them.
`tests/intercom_peers.gd` runs three processes on ports 48260-48269: HOST and ALICE on RED, BOB on no team, ALICE holds
the team button, and **the negative is the point** — BOB must end with **zero** frames and **zero** samples while still
seeing ALICE's lamp lit. With the team filter removed from the relay, BOB played 30 frames and 4,800 samples and both
negative checks failed by name.

**AND ONE THE SUITE DID NOT CATCH UNTIL IT WAS CHANGED.** A mutant that painted every lamp from "have I played any
frames myself" — a local guess, the exact bug the lamp exists not to be — **passed all twelve checks**, because the
lamp checks were reading `Net.talking` out of the log rather than the colour the row was actually painted. Reading the
drawn `ColorRect` back instead catches it at once, and names it: the host painted `1+2+3`, every row lit, while
`talking=[2]`. **A check that reads the fact a thing is drawn FROM is not a check that it was drawn.**

**A timing trap worth keeping.** The suite waited `create_timer(2.0)` for the lamp to clear and failed three runs out
of three under the runner while passing by hand: a `SceneTreeTimer` counts the tree's process time and the runner
starts every suite with `--fixed-fps 120`, so two of the suite's "seconds" pass in a fraction of two real ones — while
the children are separate processes in real time. It waits for the evidence in the log now, on `Time.get_ticks_msec`.

**And looking at it changed the lamp's colour** (rule 2). Lit was the speaker's own colour, which put an identical bar
next to that player's colour swatch: the talking row read as two red squares with no telling which was the lamp. Lit is
amber now — the row says WHO by being that player's row, and the lamp only has to say WHETHER.

## THE TOWER SPEAKS TO ONE TEAM, AND BOTH KINDS ARRIVE AT ONE DOOR (lane/voicelobby, 2026-09-20)

The last of the user's ask: *"we'll want to test if we can generate a message with kokoro and PLAY it to the other
players via the server."* **That transport was already built** — `Radio.speak` renders through Kokoro onto a capture
bus, `RadioClip` encodes it, `Net.send_long` carries it and every machine plays the same decoded bytes, measured at
25.98 dB SNR with exact completion through 10% loss. What step 4 added is the two things around it.

**AN AUDIENCE.** `Radio.speak(text, to_team)` and `publish_pcm(..., to_team)` take a `TeamBoard` team, or `NOBODY` for
the whole session, and the host is subject to its own filter — a line for BLUE is not heard by a host on RED, however
much it was the host that said it. The audience is held in `Radio._for_team` between the press and the render
finishing, because Kokoro answers on its own thread some hundreds of milliseconds later; it is deliberately NOT a
parameter on `Headphones.rendered`, because a text-to-speech voice has no business knowing what a team is.
`TeamBoard.share_a_team` answers who may hear it — the same function the live voice routing asks, so the two cannot
drift apart.

**ONE LABELLED ARRIVAL POINT.** `Radio._play` still plays through `Headphones` on the Radio bus — a generated line and a
person's voice are on **separate buses**, which is half of what "play them on different channels" asks for — but it
then calls `Intercom.announce(1, GENERATED, samples)`. So a machine has exactly one place that says *here is audio,
from this player, of this kind*, whichever carrier brought it. **Announce and not play: two doors into one set of
speakers would play every line twice.**

`Intercom.the_one_in_the_room` is how `Radio` finds it without reaching into a scene. It is typed `Node` and not
`Intercom`, which it obviously is: GDScript refuses `the_one_in_the_room = self` while the class is still compiling
(*"Value of type gdscript://… cannot be assigned to a variable of type Intercom"*), so the one caller asks `has_method`
rather than pretending to know more than the parser does.

**THE VOICE IS ON IN THIS ROOM.** `Headphones` starts OFF everywhere else and `play_clip` refuses a clip while it is
OFF — so without turning it on, a generated line is sent, carried, validated and then **silently not played**. That is
exactly what the first run measured: the host printed *"Sent to 2 players"* and not one machine announced a thing. A
listener pays nothing it need not: a machine with no model never reaches `Voice.ON`, and `play_clip` only asks that the
voice is not OFF, which is why `tests/radio_peers.gd`'s client plays a clip with no model and no library present.

**The host's row** is a line edit and two buttons, SAY TO EVERYONE and SAY TO MY TEAM — the same pair of audiences as
the talk buttons above them, so nobody has to learn a second idea of who is listening. It is hidden from a client
rather than refused, because a button that is always refused should not be on the screen.

### What the test proves, and the check that caught itself

`tests/intercom_peers.gd` now runs both kinds in one session: ALICE holds the team button, and the host asks the tower
to speak to the same team. **A listener receives a live frame AND a generated line and tells them apart**, which is the
user's channel requirement reduced to the one thing that demonstrates it — and **BOB, on no team, receives neither**.
Removing the audience filter from `publish_pcm` fails three checks at once, naming it: *bob played 0 frames and 8,000
samples*, *bob heard ["HOST"]*, *bob played 1 generated*.

The tower's tone goes in through `Radio.publish_pcm`, the same function `Headphones.rendered` calls with Kokoro's own
samples, so the encode, carry, validate and play path is identical. The synthesis itself is `radio_peers`' and the
export's `--speak-test`, which is where it belongs: a model on the disk is a property of the desk.

**AND ONE CHECK CAUGHT ITSELF.** `and_it_is_labelled_as_a_live_microphone_and_not_a_generated_line` asserted the host
heard kind 0 *and not* kind 1 — true only because nothing generated had ever been sent in that run. Step 4 made it
false immediately and correctly. It now asserts that **ALICE's** audio is labelled live, which is the claim that was
meant all along and is sharper than the one it replaced.

## THE WORLD SERVED AND NOT PLAYED: A DEDICATED SERVER (lane/flatcrew, 2026-09-20)

The user, 2026-09-19: *"Since not everyone has a vr headset, i want to make sure i make room to run the game as a
server in 2d (just better for resources), or headless."*

    cockpit\server.bat                          the island, hosted, with a 2D console
    cockpit\server.bat -Headless                the same with no window: SERVER_CONSOLE on stdout
    Godot --path cockpit --headless --xr-mode off -- --host=7788 --world=island --level=server

**MOST OF THE ROOM WAS ALREADY MADE, AND SAYING SO IS THE POINT.** Hosting headless already worked — every
`*_peers.gd` suite does it — and flat play was never in question: `PilotRig` boots into desktop (`_enter_desktop`,
`desktop_camera`, hands where the mouse says) and V toggles to VR. So the job was not a second way of standing a world
up. It was to NAME the thing, take off the three costs a server has no use for, and measure what that is worth.

**THE THREE COSTS, AND WHERE EACH GOES.** The rig: `Sky._nobody_is_playing()` already built none for `watch` and
`tower`, and `server` joins that list. The camera: `watch` and `tower` still build an `Observer`, so `Sky._the_server()`
builds a 2D console on its own `CanvasLayer` INSTEAD, and the level then has no camera at all — every `observer` use in
`sky.gd` was already null-guarded, so that cost nothing. The OpenXR attach: `--xr-mode off`, and on a server that is
not tidiness. A headless host on a machine with a headset runtime **attaches to it anyway**: measured,
`OpenXR: Created instance ... VirtualDesktopXR`, then a failed form factor, then a fallback — having paid for it.

**WHAT IT IS WORTH, AND WHERE THE REST WENT.** Headless on the island, twenty seconds after `SESSION=`, the child
matched by the port on its command line — the `.console.exe` is a wrapper and reports its own 6 MB otherwise:

| run | working set | private | CPU |
|---|---|---|---|
| `--level=world` (rig, XR attached) | 407.1 MB | 343.1 MB | 25.7 s |
| `--level=watch` (no rig, XR attached) | 389.7 MB | 325.8 MB | 23.3 s |
| `--level=watch --xr-mode off` | 384.8 MB | 324.2 MB | 21.0 s |

**22.3 MB and 4.7 s: five per cent of the memory, eighteen per cent of the work.** That is much less than "run it as a
server" sounds, and the remaining 385 MB is very largely SCENERY the server never draws — twenty visual yards built
unconditionally in `Sky._ready`, some of which carry simulation duties too. Carving them out is a lane of its own and
was rejected for this one deliberately: `../../todo/flatcrew--the-server-still-builds-the-scenery.md` has the scope.

### A SERVER MUST BE SEATED BEFORE IT CAN STOP FLYING, and it fails silently otherwise

A host is a sync client like any other, and `Sim._seat_new_clients` gives every client a pod — so a server flew a
parked aeroplane at the level's first spawn spot for ever, replicated to every joiner. `Sim.seat_the_host = false`
was meant to be the whole fix. **Never seating the host stops the entire world**, and the way it does it is the
lesson:

    SERVER_CONSOLE role=host level=island ready=no players=1 craft=0 pilots=0 up_s=62

`ready` is `Sim.is_ready`, the replication CLIENT's connection state. `Sky._process` returns on `not Sim.is_ready` at
its second line, so **the level built — the forest grew, 1892 trees — and then nothing was ever seeded into it and no
`SESSION_REPORT` was ever printed.** Scenery, and an empty motionless world, and no error anywhere. On this library
the host's own client does not finish its handshake until the server has spawned it something.

So the host IS seated, once, and its pod is taken away the moment `is_ready` goes true; `_host_pod_gone` stops it
coming back. The client stays Ready after the despawn, watched for forty seconds:

    SERVER_CONSOLE role=host level=island ready=yes players=1 craft=93 pilots=0 up_s=42

93 is the island's own traffic and the 94th was the pod. WHY the handshake wants an entity is the sync library's and
is carried upstream in `../../todo/flatcrew--the-host-client-needs-a-pod-to-go-ready.md`. Rejected: leaving the pod and
teaching radar to ignore it, which puts a special case where rule 10 forbids one.

### The console asks and does not keep, and its line has no spaces in it

`ServerConsole` holds no roster, no count and no total. Players from `Net.roster_cards()`, teams from `Net.team_of`,
craft from `Sim.server.vehicle_states()`, the tick from `Sim.server.tick_breakdown()` — every one asked at the moment
it is drawn (rule 4), which is why an operator reading the screen and a harness reading the log cannot disagree.
`tests/server_peers.gd`'s sixth check holds `SERVER_CONSOLE craft=` equal to `SESSION_REPORT served=` so that claim
fails when it stops being true.

**THE CRAFT COUNT IS THE SERVER'S LIST, NOT `Sim.current`** — `tower_panel.gd` measured those two disagreeing on the
island, 93 machines, only 54 of 89 shared ids naming the same kind and one id an aeroplane on the client and a train
on the server. And **the server is resolved through `_server()` on every use**, because `Sky` builds the console at
line 270 of its `_ready` and calls `Sim.start()` at line 540: kept as handed, every count would read -1 for ever and
the console would look like it worked.

`SERVER_CONSOLE` is printed once a second and is NOT gated on `--report=1`, because that line is the headless
server's face rather than a harness's request — a server that printed nothing unless a flag was passed would look
hung to whoever started it. No value on it contains a space, so the tick is a bare number there and wears its unit
only on the panel: every harness here splits on spaces and then on `=`, and one spaced value takes the next key with
it.

`tests/server_peers.gd` runs a real server and a real joiner on ports 48290-48299 — **the last block in 47900-48299**,
so the next suite that wants ports has to grow the range. `tests/server_shot.gd` is the picture and is deliberately
NOT in `suites.txt`: it needs a renderer and that runner is headless.

## RADAR: THE SENSOR THE PLOT NEVER HAD (lane/flatcrew, 2026-09-20)

The user, 2026-09-19: *"awacs or tower controller ... they focus on dispatching and radar (we don't have radar
yet)"*. They were right, but not in the way it first looks.

**THE OPERATOR'S DISPLAY WAS ALREADY BUILT.** `world/air_picture.gd` is "the whole air picture an operator watching
a plot has to read" -- players in roster colours, machines in a grey held a stated distance from every colour a
player can wear, call signs from `RadioPhrases` so the plot and the radio cannot disagree -- with `LevelMap`,
`ui/menus/map_canvas.gd`, the map page, the map screen and a `map_shot` probe around it. What it had no notion of
was a SENSOR: it draws every craft in `Sim.current`, at any range, through any mountain. So radar is not a new
picture. It is the detection that picture never had, which is why it fell out as three small files.

### The sight line was already here, under another name

**`CockpitWorld.ground_leg_is_clear` has answered "is there ground in the way" since the generated ground landed**,
over both grounds -- `Bedrock`'s height fields and `Massif`'s mountain triangles -- through one shared max-pyramid.
Two lanes' surveys in one night each concluded cockpit had no line of sight, because grepping `line_of_sight`,
`can_see` or `occlu` finds nothing: **it is named for a flight leg**, since the autopilots needed it first. Both
lanes then proposed walking `Terrain.highest_near` along the ray, which would have been slower, far coarser, and a
second opinion about where the ground is.

`world/sight_line.gd` is a name and two calls over it. What it adds is the clearance convention: an autopilot asks
for 90 m of clearance and overhead because it wants ROOM, and sight asks for zero, because a beam ten metres over a
ridge has seen past it and asking at an autopilot's clearance would hide every contact over open farmland.

**THE BIAS IS NOT NEUTRAL AND IS MEASURED.** The pyramid may call a clear leg blocked and never the other way, which
read as sight means **it may call a visible contact hidden and never a hidden one visible** -- terrain conceals
slightly MORE than geometry alone, at the grain of a 32 m square. `tests/sight_line.gd` finds the island's summit
from the pyramid rather than trusting a coordinate (614 m at -4000, 3500), blocks a 5 km line 300 m under it, clears
the identical line with the rock taken away, and sweeping upward changes from blocked to clear **exactly once over
49 rungs, at 664 m -- fifty metres above the summit.** That monotonicity is the property a hand-rolled sampler
loses, and a sensor that flickered between hidden and seen as a contact climbed would make a nonsense of
concealment. Cost: 0.7-0.8 us for a 3 km leg, so a ninety-contact sweep is under a tenth of a millisecond.

**AND IT IS THE ANSWER TO "CONCEALED FROM WHAT?"** A craft is hidden from radar exactly when it is hidden from the
same pyramid the AI flies its legs by, so a canyon cannot be both cover from radar and open sky to the traffic.

### The authority decides; everyone else displays

`RadarSet.sweep` runs on the host against `Sim.server`. Two tests and deliberately only two: slant range, then the
sight line from the head lifted by its mast (an aerial at ground level has the ground in its own line). Range is
asked first because it is arithmetic and the sight line is a query. Beam width, sweep period, minimum altitude,
Doppler, clutter, sea return, cross-section, jamming and the horizon of a curved earth are all listed in the file as
deliberately absent rather than left to be discovered.

**ROWS DESCRIBE THEMSELVES AND CARRY NO ENTITY ID, WHICH IS MEASURED AND NOT TIDY.** A client entity id and a server
entity id are different numbers for different things: on the island with 93 machines, of the 89 ids on both sides
only 54 named the same KIND and 18 the same PLACE, and one was an aeroplane on the client and a train on the server
(`world/tower_panel.gd`). A radar picture of ids for the client to look up would be **wrong about a fifth of its
contacts and confident about all of them.** `RadarSet.COLUMNS` is the order, in one place, read by both ends.

A consequence worth having: the call sign is worked out once, on the host. `air_picture.gd` records that it cannot
replicate call signs because they hash the entity id and entity ids are per-world, so two operators would read two
different numbers for the same aeroplane. A published row carries it as a string, so that is fixed for anything off
radar -- still made by `RadioPhrases.callsign`, so the plot and the headset cannot drift.

**EVERY RADAR CONTACT IS ANONYMOUS GREY, INCLUDING A MANNED ONE.** Colouring a manned contact from `PlayerColours`
would be a machine wearing a player's colour while carrying no player's name -- the exact lie `air_picture.gd` was
written to prevent, and worse here, because radar genuinely does not know who it is. `manned` rides the row so a
display can say it in one of the other channels: solid against an outline, or size.

### It makes concealment real. It is NOT anti-cheat, and nobody should think it is

Hiding behind a ridge genuinely keeps you off the published picture: the host never sends you, so an honest client
cannot draw you and a controller cannot vector anybody onto you. **It does not hide you from a determined client.**
Replication already sends every craft to every peer -- the priority sphere changes the RATE, not the visibility --
so a modified client can still see what radar does not show it. Written down because the alternative is somebody
later building a game mode on a property radar does not have; making it true means changing what replication sends,
which is a far larger job than a sensor.

### Each peer is sent a different thing, which is the whole point

`RadarWatch` is the node on the one-second timer -- `NetStats`'s shape, because it works. Every other carrier in
`Net` publishes ONE thing to everybody; this one loops the peers and sweeps once per head, because a picture is what
one head can see and sending everybody the same list makes terrain masking a decoration. So
`Net.publish_the_radar_picture` takes `{peer: rows}`. The host's own picture never goes on the wire --
`multiplayer.get_peers()` excludes it -- so it sweeps for itself and keeps the answer, or a solo game and a host
with nobody aboard would both have no radar, which are the two cases a developer actually looks at.

**`read_hello` IS A WHITELIST, AND THAT IS HOW THIS WAS CAUGHT.** The first two-peer run had the host holding 67
contacts and the joiner exactly none: an unknown `say` never reaches the match in `hear_hello`, because the
validator refuses it first. Rule 8 applied to a carrier that had not asked permission. `RadarSet.is_a_row` owns the
shape beside `COLUMNS`, and a page with one bad row is dropped WHOLE -- a silently shortened picture would look
exactly like terrain hiding something, which is the one failure radar must never be able to fake.

**A PAGE THAT NEVER ARRIVES IS A GAP, AND A GAP IS THE RIGHT ANSWER.** Latest-only, never repeated, nothing
acknowledged: a controller acting on a contact that has moved is worse off than one looking at a gap. Page 0 starts
a fresh picture and the rest add to it, and it is handed on after EVERY page rather than the last -- waiting for the
last means a picture whose final page was lost is never shown, so the plot holds the previous second's contacts and
looks perfectly confident.

The page cutter is now shared: `board_pages` and `radar_pages` are both `_pages_of` with their own word, because two
carriers each with a copy of "what fits in a hello" will one day disagree, and the copy would be the untested one.

### What it looks like, and what it costs

`tests/radar_shot.gd` plots the same island twice: ninety real aircraft at 300 m, then the forty-eight one head in
the middle of the map can see. The contacts sitting ON the ring of ranges are gone, the open central basin is
untouched, and far contacts survive only where there are GAPS between the ranges -- which is what a radar at the
centre of a ring of mountains should do and is the behaviour nobody would have thought to assert. Its first version
drew the terrain with `map_shot`'s `Terrain.boxes()`, which has drawn nothing since the mountains became a triangle
mesh, so both plots came out as contacts on an empty green field: rule 2 catching a rule 2 test. The rock is now
sampled from the mountains' own pyramid, the same one `SightLine` asks.

Measured live: a `--level=server` host on the island reported `radar=65` of 94 craft from the map's middle, and on
the stress level `radar=171` of 196. `tests/radar_peers.gd` saw the host hold 71 of 96 and the joiner 57, with 56 in
common -- two heads, two pictures, 34 ms old.

**WHERE A HEAD SITS IS HALF DONE AND SAYS SO.** A peer flying something has its head on that craft. A peer flying
NOTHING -- precisely what a tower controller is -- gets the middle of the map at mast height. That is a placeholder:
a controller's radar should stand where their station stands, and the station does not exist until the controller
seat does.

## THE DIORAMA: THE CONTROLLER'S SECOND VIEW IS A CHESSBOARD (lane/diorama, 2026-09-20)

The user, 2026-09-20: *"after building our command center i have some additions, we shouldn't use a camera and have
godot just view the map, we should regenerate a view given the data we have (that way it doesn't incur the same 3d
drawing issues and distance calculations, make a new "diorama" of sorts that shows the state of all the units,
almost like a live chessboard with the terrain and planes, boats, flying around."*

`B` at the controller's station swaps the flat plot for a miniature of the level about a metre across, built out of
numbers and rebuilt from the same radar rows four times a second. The plot is untouched and still there.

### The thing to get straight first: a diorama still has a camera

It is easy to read the request as "draw 3D without a camera", which cannot be done. What is being rejected is what
`world/level_map.gd` does -- point an orthographic `Camera3D` at the REAL world's REAL geometry at REAL scale, eight
kilometres out and eight kilometres up, render once and freeze the picture because doing it per frame would cost a
second world view every frame.

**The win is that the miniature is small and near the origin.** `world/diorama_view.gd` sets `own_world_3d` on its
`SubViewport`, which is the opposite of what `LevelMap` does and for the opposite reason: that file shares the
level's `World3D` deliberately, because a SubViewport otherwise "owns an empty scenario and its camera sees only the
background". **Here the empty scenario IS the feature.** The board's world contains one static mesh, one light and
nothing else; nothing in it is ever further from the origin than 0.6 m. No terrain geometry, no level of detail, no
shader that asks where the camera is. That is why this one can render every frame where the flat map must be frozen
after one.

It also means the board cannot accidentally show something radar did not, because there is physically nothing else
in its world to draw.

### One scale, no vertical exaggeration, and why the second part was the harder call

`world/diorama_scale.gd` is the only place the world is shrunk and everything goes through it. The tempting thing is
a taller-than-wide board, because a model railway does it and relief looks better stretched. **It is refused, and
altitude is the reason.** Exaggerate the terrain and you must exaggerate the aircraft identically or a contact at
300 m appears to fly inside a ridge that is really 600 m and drawn at 2,400; exaggerate both and a contact at ten
kilometres stands metres clear of a metre-wide board. Either way the board is lying about a number a controller is
about to say on the radio.

True scale turns out to be perfectly legible, measured: over the island's +/-7,200 m the factor is exactly
**1:12,000**, and its 653 m of relief stands **54 mm** proud of a 1.2 m board. Two contacts over one spot 2,400 m
apart draw as **200 mm** of daylight between them, where the flat plot draws one marker on top of the other.

### A piece is a tiny model, and the first answer was overturned

The board first drew a flat silhouette plate per contact, and argued for it: at 1:12,000 an F-4 is **1.4 millimetres
long**, "almost like a live chessboard" reads as arguing for tokens, and a chess piece is not a scale model of a
horse. **The user settled it the other way, 2026-09-20:** *"can you make sure you use tiny models for the planes?"*
A diorama is the thing that has little models in it, and they were right.

**The scale objection was never wrong. It is answered by breaking size away from position, not by refusing models.**
`world/diorama_miniature.gd` builds the craft at life size and `DioramaBoard._model_scale` shrinks it to a readable
size, so the rule is unchanged and is still the whole rule:

> **Position goes through `DioramaScale`. Size does not.**

A jumbo comes out a sensible amount bigger than a Cessna rather than 1:12,000 bigger, which would be 5.9 mm against
0.9 mm and illegible for both.

**THE REAL CRAFT MODELS WERE TRIED AND REFUSED ON A MEASUREMENT.** `VehicleView.setup(0, kind)` builds any kind's
actual exterior with no simulation running, which is exactly the tool it looks like. `../craft_model_audit.md`
counts what it costs: a Cessna about 40,000 triangles, an Osprey 118,000, a Hawkeye 164,000. Seventy-five contacts is
a routine board, so real models would be **three to twelve million triangles on the one screen whose entire
justification is that it is cheap** — it would have destroyed the thing the user asked for in order to satisfy the
thing the user asked for.

So a miniature is built from the shape table instead: `Sim.geometry_of(kind)` gives `extents` (the half extents of
the body) and `span` (the half wingspan), and those two numbers draw a fuselage with a pointed nose, a swept wing, a
tailplane and a fin — **about forty triangles**, faceted as the house look wants, cached per KIND and shared by every
contact of it. Helicopters get a pod, a boom and a rotor disc, because at this size the disc is the only thing that
tells a helicopter from an aeroplane. Ships reuse `ShipHull.far_mesh`, the prism silhouette that file already builds
for a hull seen from beyond 1,800 m, which is precisely this job and is already measured.

Nothing in it names a kind: `VehicleCatalogue.group` sorts by the movement model the simulation declares, so a kind
added in the C++ gets a miniature with no edit anywhere.

The convention was checked against published aeroplanes rather than assumed: the jumbo's `extents.z` doubles to
70.7 m, a 747-400's length to the decimetre, and its `span` doubles to 64.9 m against a published 64.4; the Cessna's
doubles to 11.0 m, a 172's span exactly. **One kind looks like it is in the other convention** — the Phantom's `span`
of 11.71 is an F-4's *full* published span of 11.77, where the others hold the half — so `_wing_half` clamps a wing
to 1.05 of the body's half length. That is a display clamp and not a fix; the figures are the simulation's, and the
discrepancy is worth somebody's time separately.

**The stalk is the reason a board beats a plot.** Every piece stands on a thin peg from the board's surface to its
true altitude, with a dot where it lands. It shows height, which `ui/menus/map_canvas.gd` has nowhere to put; it says
where the contact is on the ground, which a floating model cannot; and it lengthens and shortens as the contact
climbs and descends. A ship gets none — it is on the water, and a peg of no length is ink saying nothing.

**Contacts stay anonymous grey**, because `world/radar_set.gd` is explicit that radar says whether somebody is
aboard and never who. `manned` used to read as solid plate against outline and **the models took that channel away**
— a little aeroplane drawn as a wireframe is a scribble at 20 mm — so it reads in **tone** now, a crewed contact
bright against an empty one darker. That file names "solid against an outline, or size" as the options and size is
already spoken for by the kind.

### And each piece says its direction, speed and altitude

The user, in the same breath: *"make sure their direction, speed, altitude is visible with a small text label"*. Two
billboarded `Label3D` lines per piece — the call sign above, and `bearing / metres / metres per second` below in
smaller, dimmer type, because the two lines are not equally important and seventy-five of each would otherwise be a
wall of text. **In the words the side panel already uses**, three-digit bearing and then metres and metres per
second, so a controller reading the board and then the panel never converts anything in their head.

The altitude on the label is always the **reported** one, never the reckoned one: a row carries no vertical rate, so
dead reckoning moves a contact across the ground and never up or down, and printing anything else would be the label
claiming a climb nobody measured.

### It takes the SENSOR's picture, and that was the rule this lane could most easily have broken

`ControlStation` hands the board the same `RadarWatch.contacts()` rows it hands the canvas, on the same beat.
`DioramaBoard.show_contacts` decides nothing and fetches nothing. **A board that reached for `Sim.current` would
hand the controller omniscience back and nobody would notice, because it would look better** -- it would simply be a
fuller board. `tests/diorama.gd` holds it both ways: contacts that exist in no simulation anywhere are still drawn,
and an empty list draws an empty board with a world of twenty-four aircraft standing right beside it.

**AND IT ANSWERS THE CLIPPING PROBLEM FOR FREE, which was not planned.** `RadarSet.REACH_M` is 60 km and the
island's map is 7.2 km, so a contact out past the map is projected off the flat canvas and clipped --
`ControlStation._off_the_plot` exists only to count them and say the number out loud, because a silently dropped
contact looks exactly like terrain hiding one, and `../../todo/flatcrew--contacts-past-the-edge-of-the-plot.md` asks
for edge markers. **A board has no canvas edge to clip against.** The piece simply stands where it is, off the rim
in open space, which is both where it is and what it looks like: measured, a contact 17.3 km out stands 1.44 board
metres from the middle of a 1.2 m board. That does not close the note -- the plot still clips, and the plot is what
a controller reads bearings off -- but on the board the problem does not arise.

### Between sweeps: hold, or dead reckon — and the difference is not cosmetic

Radar is published once a second and the station redraws four times a second, so three updates in four have nothing
new to say. The board can do exactly two honest things with that, and `R` picks between them.

**HOLD**, which is the default. Every piece stays where the last sweep put it, and nothing on the board is ever
anything but a position the sensor actually reported.

**DEAD RECKON.** Every piece is advanced along **its own reported course** by the age of the picture — `speed` and
`heading` are columns of the row, so this is arithmetic on what the sensor said and not a position invented for the
look of it. It is what a real plot extrapolator does and it has a name that can be said out loud, which is the test
of whether a display is allowed to do something at all. The panel says so when it is on, and it names the
**distance** rather than just the fact: "dead reckoned · up to 280 m" reads as a doubt where "dead reckoned" reads as
a mode.

**IT SNAPS, IT DOES NOT EASE, and that falls out of doing it by AGE rather than by tweening.** A piece is drawn at
`reported + course × age`, so when a new page lands the age drops to nothing and the piece is back on a reported
position in one frame. Easing it from the guess towards the truth would **hide the size of the guess's error**,
which is the one thing an operator should be allowed to see. When the reckoning is good the snap is invisible because
the guess was nearly right; when a contact turns hard it jumps, and it *should* jump.

It is flat, and that is a limitation with a reason: a row carries no vertical rate, so a reckoned contact moves
across the ground and keeps the height it reported. Differencing two sweeps for a climb rate would be a second claim
built on the first. (`speed` is the magnitude of the whole velocity, so a climbing contact is reckoned very slightly
too far across the ground — at a 10° climb that is 1.5% of a second's travel, under two metres, a tenth of a
millimetre on the board.)

**While reckoning, the board advances its own pieces every frame rather than on the station's beat.** The station
redraws four times a second, which is plenty for a panel of words and is not plenty for motion — a piece stepping
four times a second is still visibly stepping. When it is holding this costs nothing at all, which is the right
shape: the honest default is also the free one and the expensive path had to be asked for.

**The choice was put to the user with a reel of each, not argued from principle.** `tests/diorama_reel.gd` records
twenty seconds of ninety real AI craft flying, one flag apart, and follows the fastest contact's piece frame by
frame. Held, it moves on **3.2% of 592 frames**; reckoned, on **99.8%**. That is the whole argument in two numbers:
holding is a one-hertz slideshow, and the user asked for planes "flying around".

Worth recording for the next person filming anything here: **`ffmpeg mpdecimate` could not tell the two reels
apart** — both are 601 unique frames — because the camera orbits slowly and every pixel changes regardless. A
whole-frame uniqueness count measures the camera, not the subject. The measurement has to follow the thing whose
motion is in question, which is why the probe tracks a contact.

### What looking at it changed, which was most of the tuning

Four things, and every one of them was invisible to the suite:

- **The colour bands were absolute metres** -- 18, 190 and 430 -- and the island's highest rock is 653, so two
  thirds of every ridge came out rock-grey or snow-white and the board looked like Iceland. They are fractions of
  the level's own measured relief now, so the snow line is near the tops because it is *defined* as near the tops,
  on a 14 km island and a 65 km generated world alike.
- **The tokens were 14 mm and read as scratches** from the opening view while being perfectly fine close in --
  which is the trap of tuning at whatever distance you happen to be debugging at. 20 mm and up.
- **The miniatures were drawn at twice the size asked for**, because `extents` are HALF extents and the scale
  divided by `extents.z` rather than by the full length: the airliner came out 70 mm on a 1,200 mm board and swamped
  its neighbours. The suite caught it, not the eye, once it was made to report the size off the DRAWN mesh.
- **And they were too dark.** An empty contact's paint at 0.52 multiplies the miniature's own 0.62 body grey down to
  about 0.32, which against the black sky behind the high contacts read as a silhouette rather than as a model --
  the exact thing the models had just been added to stop.
- **The camera was wrong in both directions.** At 1.45 m the board ran off the edges the moment it was turned; at
  1.9 it sat in the middle of a lot of black, which only showed up beside a flat plot filling its half.
- **`PITCH_LOW` at 0.06 rad** put the board edge-on with the contacts stacked into a hedge.

And one that the suite caught only once it was asked properly: the board is a 150 m grid, so `surface_board_y`
answers with the nearest sample and is up to a texel's worth of slope from a point query -- **32.5 m** at
(1500, -3750), where the terrain stands at 480.9 m and the board says 448.4. That is resolution, not error, and a
stalk has to stand on the mesh that is drawn.

### What is checked, and the check worth copying

`tests/diorama.gd` (core) holds the scale in both directions at three different extents, the board against
`Terrain.surface_height` at 196 texel centres, every one of the 37 traffic kinds getting a piece, the altitude claim
with two contacts at one place and two heights, and the reckoning with two contacts on courses 90 degrees apart --
one of anything would prove nothing in all three cases. `tests/diorama_shot.gd` is the stills and
`tests/diorama_reel.gd` the two reels; both are probes, and neither has a verdict on how it looks.

**Two checks went red when the pieces became models, and both were right to.**
`a_bigger_kind_gets_a_bigger_piece` read "airliner 0.0016 against cessna 0.0048", because a plate was a unit shape
scaled UP to its size while a miniature is built life size and scaled DOWN — so a bigger kind has a *smaller* scale
factor. Both numbers are perfectly plausible on their own and only their order gives the fault away; the check now
measures off the drawn mesh's own bounds. And the `manned` check went red because solid-against-outline had stopped
existing, which is the suite noticing a channel had been removed rather than a bug.

**The check worth copying is the transpose.** `heights` is indexed `j * TEXELS + i`, and an i/j swap is invisible on
anything symmetrical: it draws the island's own reflection, confidently, with every contact in the wrong valley. So
the suite *searches* for the point where the island is least like its own mirror -- scoring candidates by the
smaller of "how high this point stands" and "how far its mirror is from it", because a tall point whose mirror
matches proves nothing and so does a big gap down at sea level -- and asserts the board agrees with the terrain
there and disagrees with the transpose. Deliberately swapping the index turns it red at 370 m.

Its first two versions were both weaker and both looked fine. The first scored on the gap alone and settled on a
sea-level spot whose reflection is 481 m of rock: it passed, and would have passed just as happily against a
`surface_board_y` that returned zero for everything. The second searched arbitrary coordinates rather than texel
centres and went red by 32.5 m, measuring the board's resolution rather than its index.
