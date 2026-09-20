extends Node
## The simulation, and the one rule the renderer follows.
##
## Everything in the world lives in the ashiato ECS behind `client` and, when hosting,
## `server`. Godot nodes are views: they are moved to match, and never asked.
##
## ---------------------------------------------------------------------------------
## HOW THINGS ARE DRAWN, WHICH IS THE WHOLE POINT
## ---------------------------------------------------------------------------------
##
##   1. The simulation ticks EXACTLY ONCE per Godot physics frame. Godot's physics rate is
##      set from the tick rate to make that true.
##   2. Each tick, every vehicle's display pose is captured into `previous` and `current`.
##   3. Each RENDER frame, a vehicle node is placed at previous.interpolate_with(current,
##      Engine.get_physics_interpolation_fraction()).
##
## That is one clock and one mechanism, which is why it can be verified. The version this
## replaced had two -- ticks scheduled on Godot's physics clock, the fraction between them
## measured with the render delta -- and Godot deliberately smooths one against the other,
## so they disagreed by a wandering fraction of a frame. That wander went straight into
## the drawn position, and a controller held perfectly still shook because the frame it
## was being drawn in was moving.
##
## PILOTS ARE NOT INTERPOLATED AND MUST NOT BE. A pilot is seat-local poses, drawn as a
## child of their vehicle's node. A hand held still has a constant local transform whether
## the aircraft is parked or doing 200 knots, so there is nothing there to smooth -- and
## anything that tried would be adding motion rather than removing it.

## Vehicle kinds, one per row of ashiato-gd/src/cockpit/cockpit_kinds.inc, in its order. The simulation is the
## authority on what these mean: ask geometry_of() for the shape and geometry_of(kind)["model_name"] for the MOVEMENT
## MODEL each one declares, rather than writing either down twice.
##
## WRITTEN, NOT TYPED (lane/kinds, 2026-09-18): run res://tools/generate_kind_enum.tscn after adding a row, and
## tests/many_kinds.gd names any entry this and the library disagree about.
## BEGIN KINDS: written by tools/generate_kind_enum.tscn from cockpit_kinds.inc. Do not edit by hand.
enum Kind {
	POD, PLANE, BOAT, CAR, HELI, TRAIN, AIRLINER, OSPREY, CHINOOK, GUNBOAT, CESSNA, TOWER, CARRIER, BATTLESHIP,
	TANK, GUNSHIP, TANKER, GLIDER, PIRATE, HAWKEYE, SUBMARINE, SEGWAY, JUMBO, FIGHTER, UH60, TOMCAT, SAVOIA,
	FALCON, LITTLEBIRD, PROWLER, CB90, APACHE, LIGHTNING, WARTHOG, TRANSPORT, P51, P47, FIREBOAT, PHANTOM
}
## END KINDS

## "NO KIND IN PARTICULAR", on the input frame beside the buttons.
##
## It was 15, which was one past the last kind while there were sixteen of them and IS the
## gunship now that there are seventeen -- and the server reads anything below the number of
## kinds as a kind somebody named. It was then 31, typed here and in the C++, which was the
## thirty-second kind's number. Now it is READ from the library (`kind_limits`, lane/kinds,
## 2026-09-18): the top of `kKindIdBits`, 65,535, and tests/many_kinds.gd goes red if this
## and the C++ ever disagree.
static var NO_KIND: int = int(kind_limits().get("no_kind", -1))

## EVERY WIDTH A KIND HAS, from `cockpit_components.hpp` through `CockpitWorld.kind_limits`:
## `id_bits` (16), `no_kind` (65,535), `short_bits` (5) and `short_kinds` (30, the kinds that
## travel in five bits), and `kind_count`, which `Kind` below must match. Asked once.
static func kind_limits() -> Dictionary:
	if _kind_limits.is_empty() and ClassDB.class_exists("CockpitWorld"):
		_kind_limits = ClassDB.class_call_static(&"CockpitWorld", &"kind_limits")
	return _kind_limits

static var _kind_limits: Dictionary = {}

## THE SHAPE OF A KIND, with or without a running world.
##
## `kind_geometry` reads the shape table, which a CockpitWorld builds in its CONSTRUCTOR --
## no session, no network, no tick. So the editor can ask the same question the game asks,
## off a throwaway world it makes for the purpose and keeps.
##
## That is the whole reason a vehicle can be looked at in the editor without a second copy
## of the shape table in GDScript. A constant here and a matching constant in the C++ agree
## until one of them changes, and then the thing you can see is a different size from the
## thing you collide with -- which is maddening precisely because it looks correct.
static var _shapes: Object = null


static func geometry_of(kind: int) -> Dictionary:
	# OFF THE MAIN THREAD, THE TABLE OF ITS OWN: a worker may not reach /root/Sim through the tree ("The caller thread can't
	# call get_node_or_null"), and the island's mountains are first built on the mist's worker, whose keep-outs walk the
	# spawns, which ask this (2026-09-18). The table is the library's either way, so the answer is the same.
	if Engine.get_main_loop() != null and not Engine.is_editor_hint() and OS.get_thread_caller_id() == OS.get_main_thread_id():
		var running = Engine.get_main_loop().root.get_node_or_null("/root/Sim")
		if running != null and running.client != null:
			return running.client.kind_geometry(kind)
	if _shapes == null:
		if not ClassDB.class_exists("CockpitWorld"):
			return {}
		_shapes = ClassDB.instantiate("CockpitWorld")
	return _shapes.kind_geometry(kind)


## WHETHER A KIND CARRIES A WATER TANK, asked of the simulation's own `has_a_tank` by the same route as `geometry_of`, so
## a cockpit fits a tank gauge where the simulation keeps water and nowhere else.
static func carries_water(kind: int) -> bool:
	if _shapes == null:
		if not ClassDB.class_exists("CockpitWorld"):
			return false
		_shapes = ClassDB.instantiate("CockpitWorld")
	return bool(_shapes.carries_water(kind)) if _shapes.has_method("carries_water") else false


## HOW A KIND HANDLES, by the same route as `geometry_of` above and for the same reason.
##
## THE LOCOMOTIVE'S TRUCK CENTRES ARE A HANDLING NUMBER, because the rail solver samples the
## track at two points that far apart -- that is what makes a body span the CHORD of a curve
## instead of bending along it. The model has to draw its trucks in the same two places, and
## before this it did not: `_build_train_body` put them at 0.52 of the half-length, which was
## 9.36 m under the old 18 m shape, while `bogie_spacing` said 11.0. Two numbers for one
## distance, neither aware of the other, and nothing could see it because the drawn trucks and
## the sampled trucks never appear in the same picture.
##
## So the model asks. The doc block above already says why, about size: "a constant here and a
## matching constant in the C++ agree until one of them changes, and then the thing you can see
## is a different size from the thing you collide with -- which is maddening precisely because
## it looks correct." The same sentence is true of where it rides.
static func handling_of(kind: int) -> Dictionary:
	if Engine.get_main_loop() != null and not Engine.is_editor_hint():
		var running = Engine.get_main_loop().root.get_node_or_null("/root/Sim")
		if running != null and running.client != null:
			return running.client.handling(kind)
	if _shapes == null:
		if not ClassDB.class_exists("CockpitWorld"):
			return {}
		_shapes = ClassDB.instantiate("CockpitWorld")
	return _shapes.handling(kind) if _shapes.has_method("handling") else {}


## WHERE A TILTROTOR'S THRUST POINTS at a tilt, in the craft's frame, by the simulation's own expression
## (`CockpitWorld.thrust_axis`): what the F-35B's drawn nozzle is held to. ZERO with no extension, or on a library too old
## to say, so a check that needs it fails rather than passing on a default.
static func thrust_axis_of(kind: int, tilt: float) -> Vector3:
	if _shapes == null:
		if not ClassDB.class_exists("CockpitWorld"):
			return Vector3.ZERO
		_shapes = ClassDB.instantiate("CockpitWorld")
	return _shapes.thrust_axis(kind, tilt) if _shapes.has_method("thrust_axis") else Vector3.ZERO


## THE STANDING SWELL THE SIMULATION FLOATS HULLS ON: both waves' heights, wave vectors and the wrap, off the same
## constants `swell_height` uses. What the FINE sea displaces its surface by, so the water drawn at a hull is the water
## the hull is on (see SeaSwell). {} with no extension, or on a library too old to say.
static func swell_shape() -> Dictionary:
	if _shapes == null:
		if not ClassDB.class_exists("CockpitWorld"):
			return {}
		_shapes = ClassDB.instantiate("CockpitWorld")
	return _shapes.swell_shape() if _shapes.has_method("swell_shape") else {}


static func schema_of(kind: int) -> Dictionary:
	if _shapes == null:
		if not ClassDB.class_exists("CockpitWorld"):
			return {}
		_shapes = ClassDB.instantiate("CockpitWorld")
	return _shapes.craft_schema(kind)


## What a kind is called, for anything a person has to read. The simulation has the same
## names on its shapes; this is here so the level does not have to ask the world a question
## to label a key.
static func kind_name(kind: int) -> String:
	return Kind.keys()[kind].to_lower() if kind >= 0 and kind < Kind.size() else "?"

## Movement models, matching Model in cockpit_world.cpp. The difference between these is
## which forces exist at all, not their size.
enum Model { HOVER, AIRPLANE, HELICOPTER, CAR, BOAT, TRAIN, TILTROTOR, FIXED, SAIL }

## The command bus channels. The wire only ever carries a number and a value; what makes
## one mean "flaps" is craft_schema, per kind.
enum Channel {
	THROTTLE = 0, FLAPS = 1, TRIM = 2, GEAR = 3, SPOILERS = 4, TILT = 5, DROP = 6, FOLD = 7,
	WEAPON = 8, RADIO = 9, DISPLAY = 10, MODE = 11, LIGHTS = 12, MASTER = 13,
	CREW_TOGGLE = 14,
	## THE ARRESTING HOOK, on a carrier aeroplane: stowed or down. PHYSICAL, though it sits above the system half --
	## the eight low numbers are all taken and renumbering the systems would change every saved layout that stores a
	## channel number. `is_physical` in cockpit_world.cpp is what makes both ranges one half.
	HOOK = 15,
	## THE WING SWEEP, on a swing-wing aeroplane: 0 is the wings spread at 20 degrees and 255 overswept at 75
	## (`SweepHandle`, `TomcatAirframe`). The first number past the sixteen the bus had. Anybody seated may move it,
	## pilot and RIO alike, and everybody in sight sees it; it changes nothing the flight model knows yet. Where it lives
	## in the simulation, and why, is in `cockpit_world.cpp`'s `Channel::Sweep`.
	SWEEP = 16,
}

## EVERY WIDTH THE COMMAND BUS HAS, from `cockpit_components.hpp` through `CockpitWorld.bus_limits` (busbits,
## 2026-09-18): `channel_bits` and `channels` (16, 65,536), `first_generic_channel` (32; the named channels above are
## all below it), `named_channels` (17), `seq_bits`, `value_bits`, `page_channels` and `queue_cap`. Read, not typed:
## `tests/many_devices.gd` holds the enum above against it, so a channel added to one and not the other is red.
static func bus_limits() -> Dictionary:
	if _bus_limits.is_empty() and ClassDB.class_exists("CockpitWorld"):
		_bus_limits = ClassDB.class_call_static(&"CockpitWorld", &"bus_limits")
	return _bus_limits

## Asked once: the widths are compiled into the library and cannot change under a running game.
static var _bus_limits: Dictionary = {}


## EVERY WIDTH A SEAT HAS, from the library: `seat_bits`, `short_seat_bits`, `most_seats` a craft may be built with,
## `most_aboard` people one craft holds at once, `aboard_count_bits`. Asked once, as `bus_limits` is.
static func seat_limits() -> Dictionary:
	if _seat_limits.is_empty() and ClassDB.class_exists("CockpitWorld"):
		_seat_limits = ClassDB.class_call_static(&"CockpitWorld", &"seat_limits")
	return _seat_limits

static var _seat_limits: Dictionary = {}


## FIT A KIND WITH ITS SEATS: `[{position, yaw, station}]` in seat order, station "pilot", "copilot", "turret" or
## "operator", seat 0 a pilot's; an empty list puts back the seats the kind is built with. As many as `most_seats`
## (the user, 2026-09-18: "yes, no max"). Every machine fits the same, before any world starts; the library refuses
## while one is running, and refuses the whole list if one seat is malformed, because a seat's number is its place in
## the list. Answers `{fitted, why}`. The shape-only world `geometry_of` asks is made again, so it sees the new seats.
static func fit_seats(kind: int, seats: Array) -> Dictionary:
	if not ClassDB.class_exists("CockpitWorld"):
		return {"fitted": 0, "why": "no library"}
	var answer: Dictionary = ClassDB.class_call_static(&"CockpitWorld", &"fit_seats", kind, seats)
	_shapes = null
	# AND A LAMP CHANNEL FOR EVERY SEAT IT NOW HAS. See `SignalLamp.fit_kind`.
	if int(answer.get("fitted", 0)) > 0 or seats.is_empty():
		SignalLamp.fit_kind(kind)
	return answer


## FIT A KIND WITH ITS GENERIC CHANNELS: `[{channel, name, range, audience}]`, audience "crew" or "craft", channels
## from `first_generic_channel` up. Every machine fits the same, before any world starts; the library refuses while
## one is running. Past the named channels a craft may have as many as the wire can name, and a device -- a switch,
## a key, one of four per-seat copies -- works one through `DeviceSignalRouter` like any other. Answers
## `{fitted, refused}`; a malformed entry is refused with a warning and the rest are fitted.
static func fit_channels(kind: int, channels: Array) -> Dictionary:
	if not ClassDB.class_exists("CockpitWorld"):
		return {"fitted": 0, "refused": channels.size()}
	return ClassDB.class_call_static(&"CockpitWorld", &"fit_channels", kind, channels)


## WHAT A BUS CHANNEL IS CALLED, for anything a person has to read.
##
## Wanted by the controls that could be wired to ANY of them -- a knob, a dial, a switch --
## whose own name says nothing about what they do. A lever called FLAPS is a flap lever; a
## knob is a knob until you know what it turns.
##
## OFF THE ENUM ITSELF, like `kind_name` above, so a channel added to the list is named
## without anything here being edited. A hand-written table beside an enum is a table that
## goes stale, and the stale entry is always the newest one.
static func channel_name(channel: int) -> String:
	for named in Channel:
		if int(Channel[named]) == channel:
			return String(named).replace("_", " ").to_lower()
	return "unwired"


## Button bits in the control frame, matching kButton* in cockpit_world.cpp.
const BUTTON_SEAT: int = 1
const BUTTON_USE: int = 2
const BUTTON_MENU: int = 4
const BUTTON_KIND: int = 8
## THE TRIGGER. Edge-detected on the server with the others -- see kButtonFire -- so a
## replayed input frame fires one round rather than a magazine.
const BUTTON_FIRE: int = 16
## SIT WITH THAT PLAYER. Carried beside `join_wanted` on the input frame, because the seat
## buttons browse the world in entity order and cannot be aimed at a person.
const BUTTON_JOIN: int = 32
## "ANY FREE SEAT OF THEIRS", in `join_seat` beside `join_wanted`. -1, and NOT the simulation's own sentinel, which is
## the top of however wide a seat is (`kAnySeat`, 65,535 since lane/seats): it was 7, the top of three bits, and a
## craft may now have a seat 7 to be asked for. `set_pilot_input` reads -1 as any and every other number as a seat.
const ANY_SEAT: int = -1
## How many menu request numbers there are: three bits on the wire, matching `ControlInput::menu_request`.
const MENU_REQUESTS: int = 8
## LOCK WHAT THE SEEKER CAN SEE, and a second press lets it go. A level on the input frame like the trigger, and
## edge-detected on the server for the same reason: see kButtonLock, and `lock_states` for what comes back.
const BUTTON_LOCK: int = 64
## LAUNCH A MISSILE from the selected station. The server takes the rising edge and refuses one it would not launch
## -- not armed, nothing loaded, no lock -- and says why in the seat's lock state rather than here.
const BUTTON_LAUNCH: int = 128

## How often the world is simulated, and therefore how often it goes on the wire.
##
## A SETTING, because it is the bandwidth dial and traffic is very nearly linear in it.
## But every peer in a session must agree -- a rollback replays ticks, so two peers on
## different rates are running two different games -- so it only changes between sessions.
## 120, which is the ceiling CockpitWorld will accept, and it is here because of what the
## tick rate BUYS at speed: the renderer draws between two simulated states, so the tick is
## the length of the interval it has to guess across. At 60 Hz and 300 kph that interval is
## 1.4 m of aeroplane; at 120 Hz it is 0.7. Every timing error left in the frame -- and
## there is always some -- is halved with it.
##
## It is affordable because it was measured rather than assumed: a tick costs 0.06 ms with
## the whole world loaded, so 120 of them is well under one per cent of a core. What it is
## NOT free in is bandwidth, which is very nearly linear in the rate, so a session over a
## real network may want to come back down. [ and ] do that.
const DEFAULT_TICK_HZ: float = 120.0
const MIN_TICK_HZ: float = 20.0
const MAX_TICK_HZ: float = 120.0
const TICK_HZ_STEPS: PackedFloat32Array = [20.0, 24.0, 30.0, 36.0, 45.0, 60.0, 72.0, 90.0,
	120.0]

## How far behind the server other people are drawn. Live and per-machine: it costs nobody
## else anything. At a lower tick rate each frame covers more time, so the same count buys
## proportionally more slack -- which is the other half of the bandwidth trade.
##
## IT COSTS NO BANDWIDTH AT ALL, which is worth saying plainly because it is the one dial
## here that is free on the wire. Measured over a starved world -- 408 entities, four
## clients, 100 ms -- every depth from 3 to 63 frames sent exactly 123.9 kB/s per client
## and caused exactly the same number of rollbacks. What it buys is smoothness on entities
## that are not being SENT often enough to interpolate between, which is what happens to
## everything once the crowd is big enough. See "HOW MANY PLAYERS" in agents.md.
##
## What it costs is LAG on everything this machine does not predict: `frames / tick_hz`
## seconds, on top of the link. Twelve frames at 120 Hz is another tenth of a second on
## every other aircraft in the sky. That is cheap for traffic four kilometres away and
## expensive for the one you are formating on, and there is no way to say so today --
## the buffer is one number for the whole world, not a number per entity.
##
## 63 AND NOT 64, and this is a hard edge rather than taste. ashiato-sync's
## `buffered_frame_lag_capacity` is 64 and it validates with `>=`, by THROWING: ask a
## CockpitWorld for 64 and `std::invalid_argument` comes out of `start` where nothing
## catches it, and the process is gone. `set_buffer_frames` is guarded; `set_interpolation`
## is not, because it only stores the number and the throw happens later.
const DEFAULT_BUFFER_FRAMES: int = 3
const MIN_BUFFER_FRAMES: int = 1
const MAX_BUFFER_FRAMES: int = 63

## THE PRIORITY SPHERE: what is near a machine's own craft is sent to it more often than what is far away. THE ONE PLACE
## ITS NUMBERS ARE WRITTEN; CockpitWorld starts with it off and is handed these at `start`. See agents.md, "THE PRIORITY
## SPHERE", for what they do and the command lines that change them for one run.
##
## IT IS A RATE, NOT A FILTER. The host's sync sends a client whatever changed, largest accumulated priority first, until
## that client's budget for the tick is spent -- so these numbers do nothing while everything fits, and under a shortage a
## craft inside the radius is chosen PRIORITY_INSIDE times as often as one outside. Nothing is ever withheld: a withheld
## craft would freeze on that machine for good.
##
## 4, NOT 8, from the arithmetic at today's 245 kB/s budget (about 104 craft updates a tick): in a 2,000-craft world with
## 200 of them near you, 4 gives the near ones 19 Hz and the far 4.8 Hz (6.2 Hz each with no sphere); 8 gives 29 Hz and
## 3.7 Hz, which is too much taken from everybody else. With 30 near, 4 gives 24 Hz and costs the far ones 3%.
## OUTSIDE IS 1.0, the priority everything had before, so nothing beyond the radius is ever sent less often than it was
## unless INSIDE is raised past what the budget can carry.
const PRIORITY_SPHERE_ON: bool = true
const PRIORITY_RADIUS_M: float = 10000.0
const PRIORITY_INSIDE: float = 4.0
const PRIORITY_OUTSIDE: float = 1.0
## FLAT: every craft inside gets PRIORITY_INSIDE. LINEAR: PRIORITY_INSIDE at your own craft, falling to PRIORITY_OUTSIDE at
## the edge. The numbers are CockpitWorld's.
enum Falloff { FLAT = 0, LINEAR = 1 }
const PRIORITY_FALLOFF: int = Falloff.FLAT

signal sim_ready
signal sim_restarting

## THE FLIGHT RECORDER while one is asked for (`--trace-craft=`), else null. See `CraftTrace`.
var trace: CraftTrace = null

## CockpitWorld. `client` exists whenever a session does; `server` only on the host.
var client: RefCounted = null
var server: RefCounted = null

## True once the client has handshaked. Nothing may read state before this.
var is_ready: bool = false

var tick_hz: float = DEFAULT_TICK_HZ
var buffer_frames: int = DEFAULT_BUFFER_FRAMES
## THE SPHERE THIS MACHINE ASKS FOR: the PRIORITY_* constants, then the command line over them (see
## `priority_sphere_asked`), then whatever `set_priority_sphere` was last given. Kept across a restart of the session, so a
## level change keeps what was set. Only the host's does anything.
var priority_sphere: Dictionary = priority_sphere_asked(OS.get_cmdline_user_args())
## SAVE BANDWIDTH: THE POSE LOD, the host's choice on its iPad (TRAFFIC). On, the server stops sending a far player's head
## and hands (`CockpitWorld.set_pose_lod`), which come back within `POSE_NEAR_M`. The user, 2026-09-18: "let's keep
## bandwidth saving off by default, but make it an option in the ipad." OFF unless this machine's host settings file says
## on; read at boot and handed to the server at every start, and written every time the switch is set. Only the host's
## does anything, as the sphere's. What it saves is in agents.md, "A FAR PLAYER'S HEAD AND HANDS ARE NOT SENT".
var save_bandwidth: bool = false
## Where it is kept: the player's folder in the game and a suite's own under a test scene, as `Spectacles` keeps
## spotting.json and `PlacingGrid` snap.json (`CockpitLayout.folder_for`), so no run ever changes the player's choice.
var host_settings_path: String = CockpitLayout.folder_for(OS.get_cmdline_args()).path_join("host_settings.json")
## The pose LOD's distances: sent within NEAR, not sent past FAR, and in between whatever it was. The first measured
## guess (lane/ashiato-latest step 3); a headset look may move them.
const POSE_NEAR_M: float = 250.0
const POSE_FAR_M: float = 350.0
## SYNC'S OWN TRACE, for a probe that needs to know which craft a joined machine had no frame for. Read by `start()`,
## because a tracer is attached as the client and server are BUILT; set afterwards it records nothing. Off in the
## game: every event becomes a Dictionary.
var tracing: bool = false

## entity -> the vehicle's display pose at the last two ticks. The renderer reads these.
var previous: Dictionary = {}
var current: Dictionary = {}

## Every pilot, as of the most recent tick. See _capture_states for why it is captured
## rather than asked for.
var pilots: Array = []

## WHAT THE SERVER LAST SAID TO THIS MACHINE'S JOIN: {count, why, seat}, or {} before any answer or with no cabin to
## carry one. Captured with the pilots, once a tick. See CockpitWorld::join_answer.
var join_answer: Dictionary = {}
## Whether this library can answer a JOIN at all, asked once per session: -1 not yet asked.
var _has_join_answer: int = -1

## THIS MACHINE'S MENU REQUEST NUMBER, on every input frame (`ControlInput::menu_request`). It moves on by one, mod
## MENU_REQUESTS, for each JOIN or craft pressed on the clipboard, and the server acts when it changes. 0 at the start of
## every session -- `start` puts it back -- because the server's copy for a client starts at 0 and is erased when the
## client leaves, so a machine that reconnects under the same client id must start at 0 too.
var menu_request: int = 0


## THE NEXT MENU PRESS'S NUMBER, taken. Only `PilotRig` presses.
func next_menu_request() -> int:
	menu_request = (menu_request + 1) % MENU_REQUESTS
	return menu_request

## EVERY ROUND IN THE AIR, as of the most recent tick.
##
## Captured here with the vehicles and the pilots, and for the same reason: a Dictionary per
## round built at the DISPLAY rate is garbage nobody asked for. A shot changes twice in its
## life -- when it is fired and when it lands -- so this list is nearly always the same list
## it was last tick.
var shots: Array = []

## EVERY FIRE STILL BURNING, as of the most recent tick.
##
## Captured with the shots and for the same reason: a Dictionary per fire built at the
## display rate is garbage nobody asked for, and a fire that nobody is dropping water on
## changes by a fraction of a per cent a second.
var fires: Array = []

## EVERY MOMENT THIS MACHINE HAS BEEN TOLD ABOUT SINCE THE LAST TICK, and only since then.
##
## A CUE IS NOT A STATE, which is the whole difference and the reason this list is DRAINED
## rather than read. Everything else here -- the vehicles, the pilots, the shots, the fires
## -- is a fact that is still true, and asking twice is free. A cue happened: it is stamped
## with the frame it happened on, it is delivered once, and a machine that reads it twice
## plays the same gush of water twice.
##
## See `CraftCue` in the C++ for what one carries and when to prefer one over a component.
var cues: Array = []
## EVERY CRAFT THAT IS NOT WHOLE, as this machine last heard it (lane/combat): entity -> {left 0..1, stage 0 whole /
## 1 thin smoke / 2 thick / 3 destroyed, destroyed, cause_name, weapon_name, by, by_kind, by_kind_name, speed}. Captured
## once a tick with everything else; a whole craft is not in it. See `CockpitWorld.hull_states`.
var hulls: Dictionary = {}
## A CRAFT WAS LOST, on the host: shot down or crashed, with who was aboard. `kill` is `CockpitWorld.take_kills`'s row.
## The log line is written here; the crew's overview and the respawn listen.
signal craft_lost(kill: Dictionary)
var _has_hulls: int = -1

## THE PREDICTED SHELLS THIS MACHINE'S GUNNER FIRED, OR WAS REFUSED, not yet drawn: see `CockpitWorld::shell_cues`.
var shells_cued: Array = []


## The shells cued since the last time anybody asked, and the asking empties them. See ShotYard.draw_shots.
func take_shells_cued() -> Array:
	var taken: Array = shells_cued
	shells_cued = []
	return taken

## EVERY MISSILE IN THE AIR, and every seat's lock, as of the most recent tick.
##
## Captured with the shots and for the same reason. Unlike a shot, a missile's position changes every tick -- it is
## steered by a target somebody else is flying -- so this list is new each tick, and it is still built once a tick
## rather than once a drawn frame. See MissileYard for the missiles and LockSight for the locks.
var missiles: Array = []
var locks: Array = []
## Whether this library has missiles at all, asked once per session: -1 not yet asked.
var _has_missiles: int = -1

var _pilots: Dictionary = {}
var _input: Dictionary = {}


func _ready() -> void:
	set_physics_process(false)
	load_host_settings()
	Net.packet_arrived.connect(_on_packet)
	Net.peer_left.connect(_on_peer_left)
	Net.session_ended.connect(func(_reason: String) -> void: stop())
	_watch_for_the_stop_file()


## `-- --sync-trace-dir=<path>` on this world, if the command line asked and the library can.
##
## Guarded by `has_method` because the shared library is upstream-locked and need not have it: a
## checkout whose ashiato_gd predates the capture build says so once and runs normally.
func _write_the_sync_trace_into(world: Object) -> void:
	var directory := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sync-trace-dir="):
			directory = argument.get_slice("=", 1)
	if directory.is_empty():
		return
	if not world.has_method("set_sync_trace_dir"):
		push_warning("[Sim] --sync-trace-dir asked for, but this ashiato_gd has no set_sync_trace_dir.")
		return
	DirAccess.make_dir_recursive_absolute(directory)
	world.set_sync_trace_dir(directory)
	print("[Sim] sync trace -> %s" % directory)


## LEAVE OF OUR OWN ACCORD when a file appears, so the trace writers flush and close.
##
## `-- --stop-file=<path>`. A harness that starts two real processes has no other way to end them
## tidily: `OS.kill` takes the tail of an asynchronous trace with it, which is exactly the part a
## capture for upstream is about. Polled at 4 Hz, which is far below anything being measured.
func _watch_for_the_stop_file() -> void:
	var path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stop-file="):
			path = argument.get_slice("=", 1)
	if path.is_empty():
		return
	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		if not FileAccess.file_exists(path):
			return
		print("[Sim] stop file %s is there: closing the sync trace and leaving" % path)
		stop()
		get_tree().quit(0))
	add_child(timer)


func is_available() -> bool:
	return ClassDB.class_exists("CockpitWorld")


func tick_dt() -> float:
	return 1.0 / maxf(tick_hz, 1.0)


## WHETHER THIS MACHINE KEEPS CLIENT RECEIPTS -- the server frame of each craft's newest state, and a count -- so that
## something can say how often a craft really arrives. Set by a level BEFORE `start`, and false everywhere else.
##
## COUNTED WHERE THE RECORDS LAND, WHICH IS THE WHOLE POINT. sync's `component_sent` trace event fires while a record is
## SERIALISED, before the budget check that may drop it, so it counts what a client was OWED: at 200 craft it says every
## craft every tick where receipts say 35 to 41 times a second (agents.md, "MEASURE A SEND ON THE CLIENT"). A statistics
## table built on it would report a lie confidently, and one already did.
## That was sync up to 90f50bf. Since 8fa08cf `component_sent` fires only once a record is in a packet, which is
## closer, but a packet can still be lost, so an arrival is still counted where it lands.
var want_receipts: bool = false

## WHETHER A CLIENT ARRIVING IS GIVEN SOMETHING TO FLY. True everywhere a world exists, and false in a room that has no
## world at all -- `world/flat_lobby.gd`, the flat 2D voice lobby, which stands up a simulation ONLY so that players have
## sync client ids for the roster to be keyed by.
##
## MEASURED, 2026-09-19, which is why this flag exists: `_seat_new_clients` gives every player a pod at the level's spawn
## height, and `Terrain.highest_near` answers 0 where no terrain was ever built, so in a session with no level the pods
## fall for ever. Two headless lobby peers printed CockpitWorld's "the wire clamped 33590 position coordinates past its
## range" once a second, falling through -1922 m, -3632 m, -5275 m, and a harness fails on the first engine error. Set
## BEFORE `start`, like `want_receipts`, and for the same reason: what the simulation does with an arriving client is
## decided while it is being stood up, not afterwards.
##
## Rejected: leaving the pods and turning the error off, which would hide the one message that says the wire is carrying
## nonsense; and building terrain for a room that draws nothing, which is the 3D world this room exists to not be.
var seat_players: bool = true

## AND WHETHER THE MACHINE THAT IS HOSTING KEEPS ONE OF ITS OWN. True everywhere except a dedicated server.
##
## `seat_players` is all-or-nothing and a server needs neither half of it: it must seat every client that JOINS -- that
## is the whole job -- and must not be flying an aeroplane itself. Left true, a `--level=server` host spawns a pod at
## the level's first spawn spot and then never flies it: measured on the island, `SERVER_CONSOLE` read `craft=94
## pilots=1` with nobody connected, so the server was flying a parked aeroplane, replicated to every joiner and, once
## there is radar, showing on it as a contact nobody is in.
##
## ---------------------------------------------------------------------------------------------------
## IT IS SEATED AND THEN UNSEATED, AND THAT IS NOT A NICETY. MEASURED, 2026-09-20.
## ---------------------------------------------------------------------------------------------------
##
## THE OBVIOUS IMPLEMENTATION -- never seat the host at all -- STOPS THE WHOLE WORLD, and it does it silently, which is
## the worst shape a failure can have. A `--level=server` host that was never seated reported, for as long as it was
## watched:
##
##     SERVER_CONSOLE role=host level=island ready=no players=1 craft=0 pilots=0 up_s=62
##
## `ready=no` is `Sim.is_ready`, which is the replication CLIENT's connection state (`CockpitWorld::net_status`,
## `client_->connection_state() == Ready`). `Sky._process` returns on `not Sim.is_ready` before it reaches anything,
## so the level was built -- the forest grew, 1892 trees -- and then **nothing was ever seeded into it and no
## `SESSION_REPORT` was ever printed**. The scenery was there and the world was empty and still.
##
## So on this library the host's own replication client does not finish its handshake until the server has spawned
## something for it. WHY that is so is in the sync library and not here; what is measured here is that it IS so, and
## `../../todo/flatcrew--the-host-client-needs-a-pod-to-go-ready.md` carries the question upstream.
##
## THEREFORE: the host IS seated, exactly once, and its pod is taken away again the moment `is_ready` goes true, after
## which `_host_pod_gone` stops it ever coming back. The world then runs with nobody in it --
##
##     SERVER_CONSOLE role=host level=island ready=yes players=1 craft=93 pilots=0 up_s=42
##
## -- 93 craft being the island's own traffic, and the 94th being the pod that has gone. The client stays Ready after
## the despawn, which was the thing this could have got wrong and is why it was watched for forty seconds rather than
## asserted.
##
## REJECTED: leaving the pod and teaching the radar to ignore it, which puts a special case in the one place that must
## not have one (rule 10 -- a contact is what the server says it is); and changing the readiness rule in the C++, which
## is the shared upstream-locked library and no business of a lane about flat seats.
var seat_the_host: bool = true

## Whether the host's own pod has already been taken away again. Only ever true on a dedicated server.
var _host_pod_gone: bool = false


func start() -> bool:
	if not is_available():
		push_error("[Sim] CockpitWorld missing. Build ashiato-gd: tools\\build.ps1 -WithCockpit")
		return false
	stop()
	_apply_engine_tick_rate()
	# EVERY SEAT'S SIGNAL LAMP CHANNEL, before any world is made -- the library refuses a channel changing meaning
	# under a live peer -- and on every machine alike, which is what makes the channel mean the same everywhere.
	SignalLamp.fit_every_kind()
	SignalLamp.forget_the_live_lamps()

	client = ClassDB.instantiate("CockpitWorld")
	# Both are read when the replication client is BUILT, so both must be set before
	# start(). Asking afterwards is silently too late.
	client.set_tick_rate(tick_hz)
	client.set_interpolation(buffer_frames, true)
	# `--freshness=1`, for a harness, or `Sim.want_receipts`, for a level that keeps network statistics: when each
	# craft's state last arrived, kept without a Dictionary per trace event. See CockpitWorld::received_frames and
	# tests/priority_peers.gd.
	#
	# IT HAS TO BE ASKED FOR BEFORE THIS LINE. A tracer is attached when the replication client is BUILT, so
	# `set_tracing(true)` after `start` records nothing AND SAYS NOTHING -- lane/sphere's cabin check read an empty
	# trace that way. A level that wants statistics sets `want_receipts` before it calls `start`, which is why this is
	# a property and not a method.
	var freshness: bool = (want_receipts or OS.get_cmdline_user_args().has("--freshness=1")) \
		and client.has_method("set_receipts_only")
	client.set_tracing(tracing or freshness)
	if freshness and not tracing:
		client.set_receipts_only(true)
	# `--sync-trace-dir=<path>`: ashiato-sync's OWN trace files, written by the library's asynchronous
	# writer, which is the raw capture upstream asked for on issue #17. A JOINER traces its client; a host
	# traces its server (below). Not both in one process: the two would share a directory, and what the
	# maintainer asked for is one directory per role. Before `start`, for the reason above.
	if not Net.is_host and Net.is_networked():
		_write_the_sync_trace_into(client)
	client.start(Net.my_peer_id())

	if Net.is_host or not Net.is_networked():
		server = ClassDB.instantiate("CockpitWorld")
		server.set_tick_rate(tick_hz)
		server.set_tracing(tracing)
		# `--refusals=N`, for an A/B of the host's refusal bound (CockpitWorld.set_budget_refusals; 0 unbounded). Absent,
		# the library's own measured default stands.
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--refusals=") and server.has_method("set_budget_refusals"):
				server.set_budget_refusals(int(argument.get_slice("=", 1)))
				print("[Sim] refusal bound %d on this host (0 is unbounded)" % server.budget_refusals())
		_write_the_sync_trace_into(server)
		server.start(0)
		_hand_over_the_sphere()
		_hand_over_save_bandwidth()
		# `-- --trace-craft=cessna`: see `CraftTrace`. Only a host has a server to read, and nothing is built unless asked.
		trace = CraftTrace.from_command_line()
		if trace != null and trace.refusal.is_empty():
			add_child(trace)
		elif trace != null:
			push_error("[CraftTrace] " + trace.refusal)

	# `-- --set=rotors=1 --kind=littlebird`, same card the suites clip on (`TuningCard`).
	# Surfaces and rotors default on in C++ for the Cessna and the Little Bird; this is the
	# A/B: `--set=surfaces=0` or `--set=rotors=0` flies the old model without a rebuild.
	var card := TuningCard.from_command_line()
	if not card.is_empty():
		print("[Sim] %s" % card.clip_on())

	is_ready = false
	_pilots.clear()
	previous.clear()
	current.clear()
	pilots.clear()
	missiles.clear()
	locks.clear()
	_has_missiles = -1
	_has_join_answer = -1
	join_answer = {}
	menu_request = 0
	set_physics_process(true)
	return true


func stop() -> void:
	set_physics_process(false)
	if trace != null:
		if trace.get_parent() == self:
			remove_child(trace)
		trace.close()
		trace.free()
		trace = null
	# BEFORE teardown, and it is why `stop` is called on the way out of a traced run rather than the
	# process simply being killed: the writer is a thread with a queue in front of it, so a killed
	# process loses whatever had not reached the file yet.
	for world in [client, server]:
		if world != null and world.has_method("close_sync_trace"):
			world.close_sync_trace()
	if client != null:
		client.teardown()
	if server != null:
		server.teardown()
	client = null
	server = null
	is_ready = false
	_pilots.clear()
	previous.clear()
	current.clear()


## EVERY WORLD THIS PEER OWNS: the client always, the server too when hosting or solo.
##
## The one place the "build it identically in both" rule is written down. Anything that is
## part of the WORLD rather than of the simulation's moving state -- the static collision,
## the handling tables, the railway, the waypoints -- has to exist in both, because a peer
## whose ground or railway is somewhere else predicts itself into it. Six functions below
## used to spell that out with a pair of null checks each, which is six places for the
## pair to come apart.
##
## Spawning does NOT go through this. A spawn is the server's alone, and the difference is
## the point: shape is shared, state is authored.
func _worlds() -> Array:
	var out: Array = []
	if client != null:
		out.append(client)
	if server != null:
		out.append(server)
	return out


## Static collision, built identically in every world. Not replicated: both sides build it
## from the same data, and a peer whose ground is elsewhere predicts itself into it.
func add_static_box(position: Vector3, half_extents: Vector3) -> void:
	for world in _worlds():
		world.add_static_box(position, half_extents)


## THE GENERATED GROUND, GIVEN TO EVERY WORLD: `GroundField`'s height fields, built identically in each and not replicated,
## like the static boxes. ONE WORLD A FRAME, awaited: a build is about 2 s on the main thread on either editor (2026-09-15),
## and a headset must be handed a frame between the two rather than 4.3 s of nothing. False if any world refused it.
func set_ground(field: Object) -> bool:
	var ok: bool = true
	for world in _worlds():
		ok = bool(world.set_ground(field)) and ok
		await get_tree().process_frame
	return ok


## THE ISLAND'S MOUNTAINS, GIVEN TO EVERY WORLD: `MountainRange`'s triangles as static Box3D meshes, built identically in
## each from the same shared description and not replicated, like the static boxes (massif.hpp). About 6 ms a world, so no
## frame is handed back between them. False if any world refused it.
func set_mountains(mountains: Object) -> bool:
	var ok: bool = true
	for world in _worlds():
		ok = bool(world.set_mountains(mountains)) and ok
	return ok


## THE WORLD'S SOFT EDGE, told to every world with the geometry: see `WorldEdge` and `CockpitWorld.set_boundary`.
## Not replicated, like the wind: every peer works the same band out of the same level.
func set_boundary(start: float, depth: float) -> void:
	for world in _worlds():
		world.set_boundary(start, depth)


## THE BAND THIS SESSION'S LEVEL WORKED OUT: {start, depth, warn_from, error}, or {} before one is built.
var edge: Dictionary = {}


## How a kind handles, and where its water is. Part of the SIMULATION, like the static
## geometry: a rollback replays ticks, so a peer that tuned a vehicle differently would
## replay them differently. Set identically everywhere, and set it before anything of that
## kind is spawned.
func set_handling(kind: int, values: Dictionary) -> void:
	for world in _worlds():
		world.set_handling(kind, values)


## Which of the five movement models a kind uses. Also part of the simulation.
func set_movement_model(kind: int, model: int) -> void:
	for world in _worlds():
		world.set_movement_model(kind, model)


## ONE WAYPOINT ON A RAILWAY: where the rail passes through, and how far it is rolled
## where it does. Both halves matter -- a point on its own has no twist, so there would be
## nowhere to say a corner is banked and no way for the drawn track and the train riding it
## to agree about which way is up.
##
## Built on both sides, like the static collision, and for the same reason: a train's whole
## replicated state is how far along it has got, which only means anything if everybody has
## the same railway.
func add_rail_point(track: int, position: Vector3, roll: float) -> void:
	for world in _worlds():
		world.add_rail_point(track, position, roll)


func close_rail(track: int) -> float:
	# NOT through _worlds(), and deliberately. Both worlds have to be told the railway is
	# closed, but only one answer is wanted back, and folding that into the loop would make
	# the return value depend on which order _worlds() happens to list them in. A hidden
	# ordering dependency is a worse thing than a repeated null check.
	if client != null:
		client.close_rail(track)
	return float(server.close_rail(track)) if server != null else 0.0


## A locomotive on a railway. Server only, like every other spawn.
func spawn_train(track: int, distance: float, speed: float) -> int:
	return int(server.spawn_train(track, distance, speed)) if server != null else 0


## Somewhere an autopilot may be sent. Part of the world, like the static collision, and
## registered on both sides for the same reason: the two have to agree about what exists.
func add_ai_waypoint(kind: int, position: Vector3) -> void:
	for world in _worlds():
		world.add_ai_waypoint(kind, position)


## Somewhere a named CRAFT request may issue a new vehicle when every existing one is full.
## Static world construction, so both prediction worlds receive the same catalogue even
## though only the authoritative server may consume a place.
func add_issue_place(kind: int, position: Vector3, yaw: float,
		velocity: Vector3 = Vector3.ZERO) -> void:
	for world in _worlds():
		world.add_issue_place(kind, position, yaw, velocity)


## THE WEATHER THE SHIPS SAIL IN (`CockpitWorld.set_weather`): a wind wandering between `low` and `high` metres a second
## about `from`, a function of the frame and the seed, so every world told the same thing has the same wind with nothing
## sent. Told to both worlds for the reason the waypoints are: the two have to agree about what exists.
func set_weather(weather: Dictionary) -> void:
	for world in _worlds():
		world.set_weather(weather)


## WHETHER AIRCRAFT FEEL THAT WIND. Only aeroplanes, helicopters and tiltrotors read the air (`air_at`); ships read the
## weather themselves. The user decided on 2026-09-15 that aircraft do not; the level says so.
## WHETHER THIS WORLD HAS A SEA past its solid ground, which the crash rule drowns aircraft in (lane/combat). The
## island's level says so; a bare world has none, because nothing can tell its empty space from a floorless sea.
func set_sea(on: bool) -> void:
	for world in _worlds():
		if world.has_method("set_sea"):
			world.set_sea(on)


func set_wind_on_wings(felt: bool) -> void:
	for world in _worlds():
		world.set_wind_on_wings(felt)


## A vehicle with nobody in it that flies itself. Server only -- clients receive it as
## buffered interpolation, because nobody else has its input.
func spawn_ai_vehicle(kind: int, position: Vector3, yaw: float = 0.0,
		velocity: Vector3 = Vector3.ZERO) -> int:
	return int(server.spawn_ai_vehicle(kind, position, yaw, velocity)) if server != null \
		else 0


## Fly off that one, at this offset in its frame: right, up, behind. Server only, like the
## autopilot itself. The leader does not have to be an autopilot -- put a player in the lead
## machine and its flight follows them.
func set_ai_leader(follower: int, leader: int, slot: Vector3) -> bool:
	return bool(server.set_ai_leader(follower, leader, slot)) if server != null else false


## `velocity` matters for anything with a wing. An aeroplane put into the air at a
## standstill does not take off: it falls, the airflow arrives from below, the angle of
## attack goes past the stall within a few ticks, and it mushes into the ground at full
## power. Spawn aircraft at a flying speed.
func spawn_vehicle(kind: int, position: Vector3, yaw: float = 0.0,
		velocity: Vector3 = Vector3.ZERO) -> int:
	return int(server.spawn_vehicle(kind, position, yaw, velocity)) if server != null else 0


## HOW FAR BEHIND THE SERVER THIS MACHINE DRAWS, in seconds.
##
## HOW STALE EVERYTHING THIS MACHINE INTERPOLATES IS, in seconds: the lag the clock is holding right now. A round's
## birth record is that stale too, so whoever draws it winds the flight forward by this much, or every remote shell
## starts at the muzzle late and crawls after an aeroplane that has moved on.
##
## THE LIVE LAG, AND ONLY THE LIVE LAG (2026-09-13). This read `net_status()`, whose `buffer_frames` is the depth ASKED
## for -- three frames -- and not the lag held, which with automatic interpolation grows to cover the link: sync sizes it
## as the one-way latency plus a multiple of the jitter (ashiato-sync `src/client_clock.cpp:379`, and the latency is
## half the measured round trip, :216). On a real link every remote shell was wound on by three frames when it was
## being drawn more than that late.
##
## AND NO LATENCY TERM, though the old line reached for one. Sync draws an interpolated entity at the estimated server
## PRESENT minus that lag (`client_clock.cpp:106`) -- the time-sync offset has already taken the link out
## (:212-226) -- so a record born at server frame T
## is on screen exactly the lag late, link included, and adding the latency as well would draw every remote round
## ahead of where the server has it. `net_status()` never carried a `latency_frames`, so that half of the old sum was
## always zero. See `shots.gd`, which measures both halves on a delayed link.
func drawing_late() -> float:
	if client == null:
		return 0.0
	# THE LAG THE CLOCK IS HOLDING NOW, off `timing()`, and nothing added to it. See the note above.
	var held: Dictionary = client.timing()
	# AND NO QUIET FALLBACK. A missing key reverting to the depth that was asked for is exactly how this hid; it is
	# said, once, and nothing is wound on at all until the clock has a lag to report.
	if not held.has("buffer_frames"):
		if not _said_no_lag:
			_said_no_lag = true
			push_warning("[Sim] timing() has no buffer_frames: remote rounds are not wound forward")
		return 0.0
	return maxf(float(held["buffer_frames"]), 0.0) * tick_dt()


## Whether `drawing_late` has already said the clock reports no lag. Once, not once a frame.
var _said_no_lag: bool = false


## THE WIND, AND THE AIR THAT IS GOING UP.
##
## Told to the simulation when the world is built, exactly like the static geometry: every
## peer must be given the same numbers, and neither is replicated. See `set_wind` in the C++
## and the note at the top of Terrain about why a generated world is not on the wire.
func set_wind(at_surface: Vector3, shear_per_km: float) -> void:
	if client != null:
		client.set_wind(at_surface, shear_per_km)
	if server != null and server != client:
		server.set_wind(at_surface, shear_per_km)


func add_lift_zone(at: Vector3, radius: float, strength: float, top: float) -> void:
	if client != null:
		client.add_lift_zone(at, radius, strength, top)
	if server != null and server != client:
		server.add_lift_zone(at, radius, strength, top)


## What the wind is doing at a height, for anything that has to lean with it.
func wind(height: float) -> Vector3:
	return client.wind(height) if client != null else Vector3.ZERO


## HOW FAST THE AIR IS GOING UP HERE, in metres a second. What a variometer reads before the
## aeroplane has done anything about it.
func rising(at: Vector3) -> float:
	return float(client.rising(at)) if client != null else 0.0


## LIGHT A FIRE, at a place on the ground. Server only, like every other spawn: a fire is an
## entity and entities are the server's.
##
## The world's fires are lit from `Terrain`, with the scenery, because that is the file that
## knows where the mountains are -- see the note there. Unlike the scenery they are
## REPLICATED, because they change and everybody has to agree about whether one is out.
func light_fire(at: Vector3, strength: float = 1.0) -> int:
	return int(server.light_fire(at, strength)) if server != null else 0


## How full a craft's water tank is, 0 to 1, or -1 for a craft that has no tank.
func tank_load(vehicle: int) -> float:
	return float(client.tank_load(vehicle)) if client != null else -1.0


## WHAT A CUE IS ABOUT. Matching `kCue*` in cockpit_components.hpp: one event number, and a
## new moment is a constant here rather than a new type on the wire.
enum Cue {
	## The tank doors opened with water aboard, and six tonnes started leaving. `value` is
	## how full the tank was, 0 to 255.
	WATER_RELEASE = 0,
	## A missile left a rail. `entity` is the launching vehicle, `value` is the pylon in the low four bits and the
	## missile type above them. See MissileYard.launched.
	MISSILE_LAUNCH = 1,
	## A missile ended. `entity` is the missile, `value` the surface it ended on -- including 5, a proximity burst.
	MISSILE_END = 2,
	## A CRAFT WAS DESTROYED this frame (lane/combat). `entity` is the craft, `value` the `HullCause`. The fireball and the
	## pieces start from it; the wreck itself is `hulls`, so a machine that joins later draws the wreck without the bang.
	DESTROYED = 3,
}


## WHAT DID IT, matching `kHullCause*`: the last damage a hull took, and so what killed it.
enum HullCause { NONE = 0, GUN = 1, MISSILE = 2, GROUND = 3, WATER = 4, COLLISION = 5 }


## Whether this aeroplane is scooping right now: low, slow enough, and over open water.
func is_scooping(vehicle: int) -> bool:
	return client != null and bool(client.is_scooping_now(vehicle))


## PULL THE TRIGGER on one gun of one vehicle, without a pair of hands.
##
## Server only, like every other spawn -- a round is an entity, and entities are the
## server's. This is what the AI fires with and what a test fires with; a player's trigger
## goes the other way, as a level on the input frame -- the server fires again every reload
## while it is held -- and a round fired this way names no shooter.
func fire_gun(vehicle: int, mount: int = 0) -> int:
	return int(server.fire_gun(vehicle, mount)) if server != null else 0


## What a kind's gun is: where it sits, how fast the round leaves, what it can load. Asked
## of the simulation rather than written down here, so the drawn barrel is the barrel the
## round actually comes out of.
static func gun_of(kind: int, mount: int = 0) -> Dictionary:
	if Engine.get_main_loop() != null and not Engine.is_editor_hint():
		var running = Engine.get_main_loop().root.get_node_or_null("/root/Sim")
		if running != null and running.client != null:
			return running.client.gun_schema(kind, mount)
	if _shapes == null:
		if not ClassDB.class_exists("CockpitWorld"):
			return {}
		_shapes = ClassDB.instantiate("CockpitWorld")
	return _shapes.gun_schema(kind, mount)


## WHICH GUN A SEAT WORKS, or -1 for a seat that works none.
##
## ASKED, NOT WORKED OUT HERE. The cockpit used to count turret seats for itself to decide
## which sight to fit, the simulation counted them a second way to decide which gun to aim,
## and a third copy decided which to fire. They disagreed: a lone gunner in the back of a
## gunship traversed and fired the 25 mm while looking through the 105's sight, and every
## seat looked as though it worked the same gun -- because sitting alone anywhere gave you
## mount 0.
##
## There is one rule now and it lives in `mount_of_seat`, beside the seat table it reads.
static func mount_of_seat(kind: int, seat: int) -> int:
	if Engine.get_main_loop() != null and not Engine.is_editor_hint():
		var running = Engine.get_main_loop().root.get_node_or_null("/root/Sim")
		if running != null and running.client != null:
			return int(running.client.seat_mount(kind, seat))
	if _shapes == null:
		if not ClassDB.class_exists("CockpitWorld"):
			return -1
		_shapes = ClassDB.instantiate("CockpitWorld")
	return int(_shapes.seat_mount(kind, seat))


## WHAT MISSILES A KIND CARRIES AND WHO CAN LAUNCH THEM: `{"stations": [{"name", "type", "pylons": [Vector3]}],
## "launch_seats": [...]}`, asked of the simulation like `gun_of`. The station's index is the value of the Weapon
## channel, and pylons are numbered through the stations in order -- see MissileYard.pylon_of. Empty on a kind with
## none, and on a library built before missiles.
## WHERE A GUN'S SHELL COMES DOWN ON FLAT WATER at `elevation`: {"range", "seconds"}, from the simulation's own flight
## arithmetic (`CockpitWorld::shell_reach_of`). {} with no world to ask. See RangeSight.
static func shell_reach(kind: int, mount: int, elevation: float) -> Dictionary:
	var asked: Object = _the_world_to_ask()
	if asked == null or not asked.has_method("shell_reach"):
		return {}
	return asked.shell_reach(kind, mount, elevation)


static func missile_schema(kind: int) -> Dictionary:
	var asked: Object = _the_world_to_ask()
	if asked == null or not asked.has_method("missile_schema"):
		return {}
	return asked.missile_schema(kind)


## ONE ROW OF THE MISSILE TABLE: its seeker, cone, range, lock time, motor and the rest. See `missile_schema`.
static func missile_type(id: int) -> Dictionary:
	var asked: Object = _the_world_to_ask()
	if asked == null or not asked.has_method("missile_type"):
		return {}
	return asked.missile_type(id)


## The running client when there is one, else the shape-only world the other schema questions use.
static func _the_world_to_ask() -> Object:
	if Engine.get_main_loop() != null and not Engine.is_editor_hint():
		var running = Engine.get_main_loop().root.get_node_or_null("/root/Sim")
		if running != null and running.client != null:
			return running.client
	if _shapes == null:
		if not ClassDB.class_exists("CockpitWorld"):
			return null
		_shapes = ClassDB.instantiate("CockpitWorld")
	return _shapes


## EVERY SEAT'S LOCK ON ONE VEHICLE, from this tick's `locks`. What `VehicleView.craft_state` publishes, so every
## screen and sight aboard reads the same rows.
func locks_for(vehicle: int) -> Array:
	var out: Array = []
	for row in locks:
		if int((row as Dictionary).get("vehicle", 0)) == vehicle:
			out.append(row)
	return out


## Move one channel of the command bus. It rides on input frames -- see the note
## on CockpitWorld::send_command for why it is not a reliable side channel.
##
## STRAIGHT THROUGH, because the library queues now (ashiato 09a9e29). It used to keep ONE pending
## command and bump a two-bit sequence per call, so a second command in the same frame overwrote the
## first and four wrapped the sequence to nothing -- and this autoload queued them, one per tick, as
## the fix that needed no build (770aa14). The library's queue does that and more: it keeps each
## command on the frames for a thirtieth of a second, so a frame the server skips online does not take
## the command with it, and it keeps the latest value per channel exactly as this one did. Two queues
## would have been two places to disagree about order, so this one is gone.
## `five_channels_asked_for_in_one_frame_all_land` in `tests/shared_controls.gd` held through the change.
##
## A REFUSAL IS SAID, not swallowed: the library returns false and warns past `bus_limits().queue_cap`
## commands queued (512 since busbits, 2026-09-18; it was sixteen), and for a channel past the wire's top.
func send_command(channel: int, value: int) -> void:
	if client != null:
		client.send_command(channel, value)


## What this player is doing this tick. Merged, so a caller that only moves one hand does
## not have to resend the rest.
func set_input(values: Dictionary) -> void:
	for key in values:
		_input[key] = values[key]


func local_client_id() -> int:
	return int(client.local_client_id()) if client != null else 0


## WHICH SYNC CLIENT CAME IN ON A GODOT PEER, and back, on ANY machine: 0 for nobody. The server learns the pair from
## sync's connection events and puts the peer on each pilot's replicated PilotOwner, so every machine -- the host, a
## joiner, a machine that joined after everybody else -- reads the same map off the pilots it already receives. It was
## a reliable Godot RPC that each machine sent once, as it arrived, so a later joiner never heard the host's id.
func client_of_peer(peer: int) -> int:
	return int(client.client_of_peer(peer)) if client != null else 0


## THE SAME QUESTION ASKED OF A HOST'S OWN SERVER, which is where the answer actually comes from: sync saw that client
## arrive on that peer (`_on_peer_left` has always asked it this way). 0 on a machine that is not hosting.
##
## WHY BOTH EXIST. `client_of_peer` above reads the map off the replicated PilotOwner components, which is the only way a
## JOINER can know who is who -- it never saw anybody connect. A host does not need the detour, and in a session where
## nobody has a pilot the detour is the difference between knowing and not: the flat voice lobby seats nobody
## (`seat_players`), so its host asked the pilots, was told 0, and published a roster with only itself on it while the
## joiner sat there with a client id of 2 (measured 2026-09-19).
func server_client_of_peer(peer: int) -> int:
	return int(server.client_of_peer(peer)) if server != null else 0


func peer_of_client(sync_client: int) -> int:
	return int(client.peer_of_client(sync_client)) if client != null else 0


## ---- the tick ---------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if client == null:
		return
	# ONCE. Godot already decides how many physics frames a slow render frame owes and
	# calls this that many times, so there is nothing an accumulator here could do except
	# disagree with it.
	if not _input.is_empty():
		client.set_input(_input)
	if server != null:
		_seat_new_clients()
		server.tick(tick_dt())
		# A PLAYER WITH A SIGNAL LAMP UP HAS THEIR HANDS SENT AT ANY RANGE, whatever the far-pose LOD says: their lamp is
		# drawn from them. See `SignalLamp.keep_held_lamps_live`.
		SignalLamp.keep_held_lamps_live(server)
		_log_the_losses()
	client.tick(tick_dt())
	_carry_packets()
	_capture_states()

	if not is_ready and bool(client.net_status().get("ready", false)):
		is_ready = true
		sim_ready.emit()


## The two states the renderer interpolates between. Captured here, once, immediately
## after the tick that produced the newer one.
func _capture_states() -> void:
	previous = current
	var fresh: Dictionary = {}
	for vehicle in client.vehicle_states():
		fresh[int(vehicle["entity"])] = vehicle
	current = fresh
	# Captured HERE, on the physics frame, for the same reason the vehicle states are: the
	# renderer used to ask the simulation for this list itself, every drawn frame, and each
	# call builds a fresh Dictionary per pilot with ten keys in it. Nothing in it changes
	# between ticks, so all that bought was garbage at the display rate.
	pilots = client.pilot_states()
	shots = client.shot_states()
	fires = client.fire_states()
	# AND THE MISSILES AND THE LOCKS, on a library built with them. Asked once, so a library from before missiles is a
	# game with none rather than an error every tick.
	if _has_missiles < 0:
		_has_missiles = 1 if client.has_method("missile_states") else 0
	if _has_missiles == 1:
		missiles = client.missile_states()
		locks = client.lock_states()
	if _has_join_answer < 0:
		_has_join_answer = 1 if client.has_method("join_answer") else 0
	if _has_join_answer == 1:
		join_answer = client.join_answer()
	# DRAINED, not polled: see `cues`. Once a tick, on the physics frame, because that is
	# the clock a frame stamp means anything against.
	cues = client.take_cues()
	# AND WHAT IS LEFT OF EVERY HULL (lane/combat), on a library that has hit points.
	if _has_hulls < 0:
		_has_hulls = 1 if client.has_method("hull_states") else 0
	if _has_hulls == 1:
		var fresh_hulls: Dictionary = {}
		for row in client.hull_states():
			fresh_hulls[int((row as Dictionary)["entity"])] = row
		hulls = fresh_hulls
	# AND THE SHELLS THIS MACHINE'S GUNNER FIRED, QUEUED rather than replaced: the drawing takes them (`take_shells_cued`),
	# and a draw frame that ran twice in a tick, or not at all, must neither draw a shell twice nor lose one.
	if client.has_method("shell_cues"):
		shells_cued.append_array(client.shell_cues())
	# A vehicle that has only just appeared has no previous pose. Give it this one, so it
	# is drawn where it is rather than interpolated from wherever the dictionary happened
	# to be empty -- which is the origin.
	for entity in current:
		if not previous.has(entity):
			previous[entity] = current[entity]


## Where a vehicle should be drawn RIGHT NOW.
##
## The fraction is Godot's own, computed against the same clock it schedules physics on,
## so the drawn frame and the simulated frame cannot drift apart.
## `alpha` is normally left alone, and then it is Godot's own fraction. It is exposed so a
## test can walk the whole interval and check the spacing is even, which is the only way to
## measure smoothness without a real display: headless has no independent render clock, so
## a loop that steps physics and render together would report perfect smoothness whatever
## this function did.
func vehicle_transform(entity: int, alpha: float = -1.0) -> Transform3D:
	if not current.has(entity):
		return Transform3D.IDENTITY
	var now: Dictionary = current[entity]
	var was: Dictionary = previous.get(entity, now)
	if alpha < 0.0:
		alpha = Engine.get_physics_interpolation_fraction()
	var basis := Basis((was["basis"] as Quaternion).slerp(now["basis"] as Quaternion, alpha))
	var origin: Vector3 = (was["position"] as Vector3).lerp(now["position"] as Vector3, alpha)
	return Transform3D(basis, origin)


## HOW FAR ALONG ITS RAILWAY A TRAIN IS RIGHT NOW, for drawing: the tick's distance plus what its own speed carries it
## through the part of the tick already drawn. -1.0 for anything that is not on rails.
##
## THE SAME JOB `vehicle_transform` DOES, for the one thing that is not posed from a vehicle state. A locomotive is drawn
## between its two simulated poses and glides; every boxcar hung behind it was placed from the CURRENT tick's distance,
## so a rake stood still through a tick and jumped 0.183 m at each tick boundary -- at 120 Hz and 22 m/s, against a
## locomotive moving smoothly, which opens and closes every coupling 120 times a second. The user, 2026-09-19: *"The
## train has a fair amount of jitter in it ... train position is not 100% critical but smoothness is."*
##
## NO SECOND CAPTURED STATE IS NEEDED, and that is why this is not `previous`/`current`. A train on rails has a scalar
## speed, held constant across a tick by `run_on_rails` (the force is applied at the tick's start), so where it is part
## way through one is exactly `distance + speed * dt * alpha`. Reading it off the speed cannot drift from what the
## simulation did; interpolating between two captured distances would also have to unwrap the lap, because the distance
## wraps to 0 at the end of the loop and a lerp across that seam would fling the whole rake backwards once a lap.
##
## `alpha` is normally left alone, and then it is Godot's own physics fraction. It is exposed for the same reason
## `vehicle_transform`'s is: headless has no independent render clock, so the only way to measure smoothness is to walk
## the interval by hand. See `tests/track_drawn.gd`.
func rail_distance(entity: int, alpha: float = -1.0) -> float:
	if client == null:
		return -1.0
	var state: Dictionary = client.rail_state(entity)
	if state.is_empty():
		return -1.0
	if alpha < 0.0:
		alpha = Engine.get_physics_interpolation_fraction()
	var length: float = client.rail_length(int(state.get("track", 0)))
	# BETWEEN THE LAST TWO TICKS, exactly as `vehicle_transform` draws the locomotive: that is a lerp from the PREVIOUS
	# tick's pose to the current one, so a drawn frame is up to a whole tick behind `current`. Reading the distance
	# forward from `current` instead put every car a tick -- 0.18 m -- ahead of the locomotive pulling it.
	var along: float = float(state.get("distance", 0.0)) \
		- float(state.get("speed", 0.0)) * tick_dt() * (1.0 - alpha)
	return fposmod(along, length) if length > 0.0 else along


## A SHIP'S RIGGING as this machine has it: the replicated component, so a machine only watching the ship draws what
## the server's sails did. {} for anything without sails, and on a library too old to carry it.
func vehicle_rigging(entity: int) -> Dictionary:
	if client == null or not client.has_method("vehicle_rigging"):
		return {}
	return client.vehicle_rigging(entity)


## EVERY MOUNT on a vehicle, in seat order, drawn between the same two simulated states as
## the hull. One entry per gunner, because two people at two guns are looking at two
## different things.
func vehicle_turrets(entity: int, alpha: float = -1.0) -> Array:
	if not current.has(entity):
		return []
	var now: Array = current[entity].get("turrets", [])
	var was: Array = (previous.get(entity, current[entity]) as Dictionary).get(
		"turrets", now)
	if alpha < 0.0:
		alpha = Engine.get_physics_interpolation_fraction()
	var out: Array = []
	for i in range(now.size()):
		var to: Vector2 = now[i]
		var from: Vector2 = was[i] if i < was.size() else to
		out.append(Vector2(from.x + angle_difference(from.x, to.x) * alpha,
			lerpf(from.y, to.y, alpha)))
	return out


## ---- who is who -------------------------------------------------------------

## EVERY ARRIVAL A LEVEL'S WINCH LAUNCHED (`GliderWinch.place`, with `client` added), newest last, for the tests: where it
## was asked for is the only record of it, since the craft moves from its first tick.
var winch_launches: Array[Dictionary] = []


## EVERY PLAYER GETS A VEHICLE, because there is no state in which a player exists without
## one. Reconciled against the server's own client list rather than driven off
## peer_connected: those are two different numbering schemes.
##
## WHERE, is the session's level: its spawn for the first pod, and the rest four across and on down from it, 14 m apart.
## The island's spawn is the -21, 30, 0 this used to type, so every suite's pods are where they were.
func _seat_new_clients() -> void:
	if not seat_players:
		return
	var connected: PackedInt64Array = server.connected_clients()
	var level: LevelChart = null
	for id in connected:
		# 0 means "not assigned yet", deliberately not sync's invalid_client_id -- that is
		# 255, which passes a `> 0` test while naming a client that does not exist.
		if id == 0 or _pilots.has(id):
			continue
		# AND NOT THE MACHINE THAT IS HOSTING, on a dedicated server -- ONCE ITS POD HAS ALREADY GONE. It is seated
		# first and taken away below, which is not a nicety: see `seat_the_host`.
		if not seat_the_host and _host_pod_gone and id == local_client_id():
			continue
		if level == null:
			level = ChartDrawer.chart(Net.level)
		if level == null:
			push_error("[Sim] the session's level '%s' is not one ChartDrawer has; nobody is seated" % Net.level)
			return
		# WHERE, AND IN WHAT, ARE BOTH THE LEVEL'S ANSWER. This worked out the spot inline and always spawned a POD, so a
		# briefing room could not stand anybody up in a segway and a room's arrivals would have been 14 m apart in a 20 m
		# room. `LevelChart.spot_for` is the arithmetic, and the briefing room draws a floor mark from the same function.
		# A LEVEL WITH A WINCH LAUNCHES ITS ARRIVALS (`GliderWinch`, the glider level): at its first thermal, or beside
		# another player already flying. The same rule a respawn asks, so a join and a crash cannot put a player in two
		# different places.
		var launch: Dictionary = GliderWinch.place(level, level.arrive_kind, GliderWinch.others_aloft(server, [id]))
		if not launch.is_empty():
			_pilots[id] = server.spawn_pilot(id, level.arrive_kind, launch["position"], float(launch["yaw"]),
				launch["velocity"])
			launch["client"] = id
			winch_launches.append(launch)
			while winch_launches.size() > 64:
				winch_launches.pop_front()
			print("[winch] client %d launched at %s%s" % [id, (launch["position"] as Vector3).snapped(Vector3.ONE * 0.1),
				" beside client %d" % int(launch["beside"]) if int(launch["beside"]) >= 0 else " over the first thermal"])
			continue
		var spot: Vector3 = level.spot_for(_pilots.size())
		# THE SPAWN'S HEIGHT IS OVER WHAT IS UNDER IT: the island's slab is 0, so its 30 m stays 30 m, and on the generated
		# ground it is over the highest surface within that height of the spot, so a pod is never put inside a hill.
		spot.y = Terrain.highest_near(spot, level.spawn_at.y) + level.spawn_at.y
		_pilots[id] = server.spawn_pilot(id, level.arrive_kind, spot, level.spawn_yaw, arrival_velocity(level))

	# AND THE HOST'S OWN POD GOES THE MOMENT THE SIMULATION IS UP, on a dedicated server. See `seat_the_host` for why
	# it had to exist at all, and for the measurement. After this the guard above stops it ever coming back.
	if not seat_the_host and not _host_pod_gone and is_ready:
		var mine: int = local_client_id()
		if mine > 0 and _pilots.has(mine):
			server.despawn_pilot(int(_pilots[mine].get("pilot", 0)))
			server.despawn_vehicle(int(_pilots[mine].get("vehicle", 0)))
			_pilots.erase(mine)
			_host_pod_gone = true
			print("[sim] the server's own pod is gone; it was only ever there to finish the handshake")

	for id in _pilots.keys():
		if id not in connected:
			server.despawn_pilot(int(_pilots[id].get("pilot", 0)))
			server.despawn_vehicle(int(_pilots[id].get("vehicle", 0)))
			_pilots.erase(id)


## HOW FAST AN ARRIVAL IS PUT IN ITS CRAFT: an aeroplane at its cruise along the spawn's heading, since one put in the air
## at a standstill stalls before it can accelerate, and a glider has no engine to accelerate with (the glider level
## arrives in one, 1,000 ft up; lane/gliderlevel, 2026-09-19). Anything else, and a spawn on the ground, arrives still:
## `LevelChart.spawn_at`'s y is a height over the ground, and a pod, a segway or a craft stood on its wheels is still.
static func arrival_velocity(level: LevelChart) -> Vector3:
	if level.spawn_at.y < ARRIVE_FLYING_OVER or String(geometry_of(level.arrive_kind).get("model_name", "")) != "airplane":
		return Vector3.ZERO
	return Terrain.nose_from_yaw(level.spawn_yaw) * Terrain.cruise_for(level.arrive_kind)


## How high over the ground an aeroplane's spawn must be for it to arrive flying, metres: the simulation's own "in the air"
## for a launch (`launch_if_grounded`, 20 m) and more, so a spawn on an apron is never one.
const ARRIVE_FLYING_OVER: float = 50.0


## EVERY KILL AND CRASH THE SERVER DECIDED THIS TICK, written in the host's log and announced (lane/combat). The user's
## "score-ish feedback": a line on the LOG tab and in the console for each, which `grep NET_KILL` finds.
##
##   NET_KILL side=host victim=412 kind=plane by="PLAYER 2" by_kind=cb90 weapon=12.7mm words="..."
##   NET_CRASH side=host victim=388 kind=savoia cause=water speed_kt=140 words="..."
func _log_the_losses() -> void:
	if server == null or not server.has_method("take_kills"):
		return
	for row in server.take_kills():
		var kill: Dictionary = row
		kill["words"] = loss_words(kill)
		var crew: Array = kill.get("crew", [])
		var facts: Dictionary = {"victim": int(kill["victim"]), "kind": String(kill["kind_name"]),
			"crew": ",".join(crew.map(func(c: Variant) -> String: return Net.name_of(int(c)))),
			"words": String(kill["words"])}
		var cause: int = int(kill["cause"])
		if cause == HullCause.GUN or cause == HullCause.MISSILE:
			facts["by"] = Net.name_of(int(kill["by"])) if int(kill["by"]) >= 0 else "AI"
			facts["by_kind"] = String(kill["by_kind_name"])
			facts["weapon"] = String(kill["weapon_name"])
			Net.logbook.write("KILL", "host", facts)
		else:
			facts["cause"] = String(kill["cause_name"])
			facts["speed_kt"] = roundi(float(kill["speed"]) * KNOTS_PER_MS)
			facts["rule"] = String(kill.get("rule", ""))
			Net.logbook.write("CRASH", "host", facts)
		craft_lost.emit(kill)


## Knots in a metre a second.
const KNOTS_PER_MS: float = 1.943844


## WHAT HAPPENED, IN WORDS, from a kill row or a hull row: "Shot down by PLAYER 2's cb90 · 12.7mm", "Hit the water at 140
## knots". One sentence for the log and the crash panel both, so the two cannot tell it differently.
static func loss_words(row: Dictionary) -> String:
	var cause: String = String(row.get("cause_name", ""))
	var speed_kt: int = roundi(float(row.get("speed", 0.0)) * KNOTS_PER_MS)
	var by: int = int(row.get("by", -1))
	var by_kind: String = String(row.get("by_kind_name", ""))
	var who: String = ""
	if by >= 0:
		who = Net.name_of(by) + ("'s " + by_kind if not by_kind.is_empty() else "")
	elif not by_kind.is_empty():
		who = "a " + by_kind
	match cause:
		"gun", "missile":
			var weapon: String = String(row.get("weapon_name", ""))
			var line: String = "Shot down" if cause == "gun" else "Hit by a missile"
			if not who.is_empty():
				line += " by " + who
			if not weapon.is_empty():
				line += " · " + weapon
			return line
		"water":
			return "Hit the water at %d knots" % speed_kt
		"ground":
			return "Hit the ground at %d knots" % speed_kt
		"collision":
			return "Collided with %s at %d knots" % [who if not who.is_empty() else "another craft", speed_kt]
	return "Destroyed"


## WHAT IS LEFT OF ONE CRAFT as this machine last heard, or {} for a whole one.
func hull_of(entity: int) -> Dictionary:
	return hulls.get(entity, {})


## ---- transport ---------------------------------------------------------------

func _carry_packets() -> void:
	if not Net.is_networked():
		# Solo hands packets straight across. The handshake, prediction and rollback all
		# still happen, which is what makes solo a real test of the networked path rather
		# than a separate mode with its own bugs.
		for packet in server.take_outbound():
			client.deliver(0, packet["bytes"], packet["bits"])
		for packet in client.take_outbound():
			server.deliver(1, packet["bytes"], packet["bits"])
		return

	# The host's OWN client is wired to its server through the same entry points a remote
	# client uses, with this machine's real peer id, so the host cannot accidentally be
	# playing a different game from the people who joined it.
	var me: int = Net.my_peer_id()
	for packet in client.take_outbound():
		if Net.is_host:
			server.deliver(me, packet["bytes"], packet["bits"])
		else:
			Net.send_to_server(packet["bytes"], packet["bits"])

	if server != null:
		for packet in server.take_outbound():
			var peer: int = int(packet["peer"])
			if peer == me:
				client.deliver(1, packet["bytes"], packet["bits"])
			else:
				Net.send_to(peer, packet["bytes"], packet["bits"])


func _on_packet(from_peer: int, bytes: PackedByteArray, bits: int) -> void:
	if client == null:
		return
	# Godot peer ids ARE sync PeerIds, so there is nothing to map here.
	if Net.is_host and server != null:
		# NOT A JOINER STILL BUILDING ITS LEVEL: sync would make it a client, seat it and simulate it in a world it does
		# not have yet. Held back, and counted, until it says the level is loaded. See Net's "THE HELLO".
		if not Net.admits(from_peer):
			Net.held_back += 1
			return
		server.deliver(from_peer, bytes, bits)
	else:
		client.deliver(from_peer, bytes, bits)


func _on_peer_left(peer_id: int) -> void:
	if server == null:
		return
	# sync is handed packets and nothing else, so it never learns that a socket closed.
	# Left untold it keeps the client in client_ids() and keeps sending into the void.
	# WHICH CLIENT THAT WAS is sync's to say: it saw the client arrive on this peer. See `client_of_peer`.
	var sync_client: int = int(server.client_of_peer(peer_id))
	if sync_client != 0:
		server.remove_client(sync_client)


## ---- tuning ------------------------------------------------------------------

## Godot's physics rate follows the simulation rate, so there is one clock. The engine
## setting is a consequence of the game's choice, never the other way round.
func _apply_engine_tick_rate() -> void:
	Engine.physics_ticks_per_second = int(round(tick_hz))


## Refused while networked rather than warned about: a peer that quietly moved to a
## different rate would keep running, disagree about every frame number, and look like the
## network having a bad day.
func request_tick_rate(hz: float) -> bool:
	var wanted: float = clampf(hz, MIN_TICK_HZ, MAX_TICK_HZ)
	if is_equal_approx(wanted, tick_hz):
		return true
	if Net.is_networked():
		push_warning("[Sim] The tick rate is fixed for the session: every peer has to "
			+ "agree. Set it before hosting or joining.")
		return false
	tick_hz = wanted
	_apply_engine_tick_rate()
	if client != null:
		sim_restarting.emit()
	return true


func step_tick_rate(direction: int) -> bool:
	var index: int = 0
	var best: float = INF
	for i in range(TICK_HZ_STEPS.size()):
		var distance: float = absf(TICK_HZ_STEPS[i] - tick_hz)
		if distance < best:
			best = distance
			index = i
	return request_tick_rate(TICK_HZ_STEPS[clampi(index + direction, 0,
		TICK_HZ_STEPS.size() - 1)])


## THE PRIORITY SPHERE FROM A COMMAND LINE, over the PRIORITY_* constants, after the bare `--`:
##
##   --priority-off   --priority-radius=5000   --priority-inside=8   --priority-outside=1   --priority-falloff=linear
##
## A value that is not a number, or that the world would refuse, is warned about and left at the constant, so a typo is a
## warning and not a session with no sphere. Static, so a suite can hand it an argument list of its own.
static func priority_sphere_asked(arguments: PackedStringArray) -> Dictionary:
	var asked: Dictionary = {
		"enabled": PRIORITY_SPHERE_ON,
		"radius_m": PRIORITY_RADIUS_M,
		"inside": PRIORITY_INSIDE,
		"outside": PRIORITY_OUTSIDE,
		"falloff": PRIORITY_FALLOFF,
	}
	for argument in arguments:
		if argument == "--priority-off":
			asked["enabled"] = false
			continue
		if argument == "--priority-on":
			asked["enabled"] = true
			continue
		if not argument.begins_with("--priority-") or not argument.contains("="):
			continue
		var key: String = argument.get_slice("=", 0).trim_prefix("--priority-")
		var value: String = argument.get_slice("=", 1)
		match key:
			"radius", "inside", "outside":
				var field: String = "radius_m" if key == "radius" else key
				var least: float = 0.0 if key == "radius" else 0.01
				if value.is_valid_float() and float(value) >= least:
					asked[field] = float(value)
				else:
					push_warning("[Sim] %s ignored: wants a number of at least %s" % [argument, least])
			"falloff":
				if value.to_lower() in ["flat", "linear"]:
					asked["falloff"] = Falloff.LINEAR if value.to_lower() == "linear" else Falloff.FLAT
				else:
					push_warning("[Sim] %s ignored: flat or linear" % argument)
			_:
				push_warning("[Sim] %s is not a priority setting: radius, inside, outside, falloff, off or on" % argument)
	return asked


## CHANGE THE SPHERE, live. Returns "" when it is in force, or the words to show whoever pressed it. Only the host's
## sphere does anything -- the prioritizer is the host's -- so a joiner is told so, as the TIME tab tells one.
func set_priority_sphere(enabled: bool, radius_m: float, inside: float, outside: float, falloff: int) -> String:
	if Net.is_networked() and not Net.is_host:
		return "Only the host decides what is sent first."
	var wanted: Dictionary = {"enabled": enabled, "radius_m": radius_m, "inside": inside, "outside": outside,
		"falloff": falloff}
	if server != null and not server.set_priority_sphere(enabled, radius_m, inside, outside, falloff):
		return "Refused: a radius of 0 to 1,000 km, and priorities of 0.01 to 1000."
	priority_sphere = wanted
	return ""


## WHAT THE HOST HAS IN FORCE, in one word for a report line: `on:10000:4:1:flat`, `off`, or `host` on a joiner, whose
## own setting does nothing.
func priority_sphere_words() -> String:
	if server == null:
		return "host"
	var in_force: Dictionary = server.priority_sphere()
	if not bool(in_force.get("enabled", false)):
		return "off"
	return "on:%s:%s:%s:%s" % [str(float(in_force["radius_m"])).trim_suffix(".0"),
		str(float(in_force["inside"])).trim_suffix(".0"), str(float(in_force["outside"])).trim_suffix(".0"),
		"linear" if int(in_force["falloff"]) == Falloff.LINEAR else "flat"]


## WHETHER THIS MACHINE DECIDES WHAT THE SERVER SENDS: the host, or a machine playing alone. The sphere and the bandwidth
## saving are both its; a joiner's board does not offer them.
func decides_what_is_sent() -> bool:
	return Net.is_host or not Net.is_networked()


## THE HOST'S SETTINGS FILE, READ: `save_bandwidth` from it, or off. Called at boot; a suite calls it again to stand in
## for a restart. A file that is not an object, or has no such key, leaves it off and says so once.
func load_host_settings() -> void:
	save_bandwidth = false
	if not FileAccess.file_exists(host_settings_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(host_settings_path))
	if not parsed is Dictionary:
		push_warning("[Sim] %s is not an object; bandwidth saving stays off" % host_settings_path)
		return
	save_bandwidth = bool((parsed as Dictionary).get("save_bandwidth", false))


## SAVE BANDWIDTH ON OR OFF, live, and kept. Returns "" when it is in force, or the words to show whoever pressed it: a
## joiner is told only the host decides, and nothing is written.
func set_save_bandwidth(on: bool) -> String:
	if not decides_what_is_sent():
		return "Only the host decides what is sent."
	save_bandwidth = on
	if server != null and server.has_method("set_pose_lod"):
		_hand_over_save_bandwidth()
	var file := FileAccess.open(host_settings_path, FileAccess.WRITE)
	if file == null:
		return "Set, but not kept: %s could not be written." % host_settings_path
	file.store_string(JSON.stringify({"save_bandwidth": on}))
	return ""


func _hand_over_save_bandwidth() -> void:
	if not server.has_method("set_pose_lod"):
		return
	if not server.set_pose_lod(save_bandwidth, POSE_NEAR_M, POSE_FAR_M):
		push_warning("[Sim] the pose LOD was refused; far players' poses are sent as they always were")


func _hand_over_the_sphere() -> void:
	var asked: Dictionary = priority_sphere
	if not server.set_priority_sphere(bool(asked["enabled"]), float(asked["radius_m"]), float(asked["inside"]),
			float(asked["outside"]), int(asked["falloff"])):
		push_warning("[Sim] the priority sphere %s was refused; the host sends as it always did" % str(asked))


func set_buffer_frames(frames: int) -> void:
	buffer_frames = clampi(frames, MIN_BUFFER_FRAMES, MAX_BUFFER_FRAMES)
	if client != null:
		client.set_buffer_frames(buffer_frames)
