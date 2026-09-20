extends Node3D
class_name CockpitBench
## A COCKPIT ON A BENCH: one craft, no world, and everything it is doing written on a board.
##
## Two modes, and the difference is how many people are in it.
##
##   SEAT      one station, one pilot, and the physics running underneath so the controls
##             actually do something. For laying out a cockpit and watching what it sends.
##   CREW      every seat, every station, and NO physics and no level at all. For sitting
##             several people in one aircraft and checking that what each of them does
##             appears on everybody else's panel.
##   FLY       ONE aeroplane, nobody in it, flying itself in an empty sky, watched from
##             outside. For the question "can this thing hold a height at all", which is
##             not a question about a cockpit and had nowhere else to be asked.
##
## Neither loads `sky.tscn`. That is the point: a hundred and forty machines, four hundred
## boxes of terrain and a railway are between you and the thing you are trying to look at,
## and none of them are needed to find out whether the flap lever is fitted.
##
##   Godot --path cockpit res://tests/bench.tscn -- --kind=osprey --mode=seat --seat=2
##   Godot --path cockpit res://tests/bench.tscn -- --kind=chinook --mode=crew
##   Godot --path cockpit -- --level=fly --kind=airliner
##
## Or set `kind` and `mode` in the inspector and press play.

## HOW HIGH THE FLY BENCH PUTS ITS AUTOPILOT, and holds it (see `_start_a_world`): the height the reel's stage
## (`tests/craft_video_demo.gd`) is built under.
const FLY_HEIGHT: float = 520.0
## THE REEL STAGE'S GROUND, 120 m under that: where `--parked` stands its craft, and where `craft_video_demo.gd` draws
## its fields. One number, so a parked craft stands on the ground the reel draws.
const STAGE_GROUND: float = FLY_HEIGHT - 120.0
## THE REEL'S RIVER, where `--afloat` puts a flying boat: its surface a metre over the stage's ground, running north and
## south this far east of the stage's middle. `craft_video_demo.gd` draws it here, so the water a hull floats on is the
## water the reel shows.
const STAGE_WATER: float = STAGE_GROUND + 1.0
const RIVER_X: float = 720.0
## How fast `--afloat` sets a flying boat moving along the river, m/s: `tests/ground_stick.gd`'s taxiing speed.
const TAXI_AFLOAT: float = 5.0

enum Mode {
	## One station, one pilot, physics on.
	SEAT,
	## Every station, no physics.
	CREW,
	## One craft, no crew, its own autopilot flying it, watched from outside.
	FLY,
}

@export var kind: Sim.Kind = Sim.Kind.PLANE
@export var mode: Mode = Mode.SEAT
## WHICH SEAT to sit in. A craft has several and they are not the same job: the pilot flies
## it, a gunner aims something, and the one on a Chinook's ramp faces backwards. Testing a
## cockpit means testing the seat you are testing.
@export var seat: int = 0
## THE BUILDER ALREADY ON, for laying this cockpit out: the rig sits in the seat, BUILD is switched on and
## the board is open at its page, so a grab moves a control and SAVE writes the layout as JSON. The
## "Build a cockpit" door on the desk, or `--level=build`.
@export var build: bool = false

var _view: VehicleView = null
var _entity: int = 0
## `--circuit=<metres>`: a square of waypoints that side long round where the fly bench starts, at its height, so the
## autopilot banks round four corners instead of flying straight -- for a reel of a craft turning. 0, the default, is
## the empty sky the bench has always had.
var circuit: float = 0.0
## `--parked=1`: the fly bench's craft STANDS ON ITS WHEELS on a floor at STAGE_GROUND, with no autopilot, for a reel of
## what a crew does to a craft at rest (the F-14's surfaces worked by a scripted stick, `craft_video_demo.gd`).
var parked: bool = false
## `--pen=0`: a parked craft stands WITHOUT the pen round it. The pen's walls are collision, and so are what a round hits:
## the AH-64's chin gun (lane/apache, 2026-09-18) burst every round two centimetres from its own muzzle, fragments and
## smoke all over the reel, until a gun reel stood the craft on the open floor. A reel that fires and works no stick has
## nothing for the pen to stop.
var pen: bool = true
## `--afloat=1`: the fly bench's flying boat SITS ON THE REEL'S RIVER instead, the water standing at STAGE_WATER, moving
## at TAXI_AFLOAT along it with no floor anywhere under it, for a reel of a hull on the water (lane/floats, 2026-09-18:
## the Savoia under a held full stick).
var afloat: bool = false
## THE SERVER'S ID FOR THE FLY BENCH'S CRAFT. Entity ids are per world: `_entity` is the client's, and seating a player
## (`seat_client`) asks the server's.
var on_server: int = 0
var _board: Label = null
var _rig: PilotRig = null


func _ready() -> void:
	_read_the_command_line()
	_light_it()
	_build_the_board()
	await _start_a_world()
	if _entity == 0:
		_board.text = "no craft"
		print("[bench] no craft: extension %s, sim ready %s" % [
			Sim.is_available(), Sim.is_ready])
		get_tree().quit()
		return
	print("[bench] %s entity %d" % [Sim.kind_name(kind), _entity])
	_view = load("res://objects/vehicles/vehicle_view.tscn").instantiate() as VehicleView
	add_child(_view)
	_view.setup(_entity, kind)
	if mode == Mode.FLY:
		# NOBODY ABOARD. The whole point is what the machine does when it is left alone, so
		# there is no rig and no station -- just the aeroplane, the autopilot and a camera
		# far enough back to see whether the nose is going up and down.
		_view.man([], -1)
		_chase = Camera3D.new()
		add_child(_chase)
		_chase.current = true
		return
	# EVERY SEAT IN CREW MODE, and just the one in SEAT mode. `man` takes the list of seats
	# that have somebody in them, so this is the same call the level makes with a different
	# list -- the bench is not a special case anywhere in VehicleView.
	var aboard: Array = []
	if mode == Mode.CREW:
		for i in range(_view.seats.size()):
			aboard.append(i)
	else:
		aboard.append(mini(seat, _view.seats.size() - 1))
	_view.man(aboard, mini(seat, _view.seats.size() - 1))
	_rig = load("res://player/pilot_rig.tscn").instantiate() as PilotRig
	add_child(_rig)
	_rig.sit_in(_view.seat_anchor(mini(seat, _view.seats.size() - 1)))
	if build:
		_open_the_builder()


## THE BUILDER ON, AND ITS PAGE OPEN. The same switch the board's BUILD is, so nothing here is a second way
## of building: one frame later, so the rig has taken its seat and reached the controls it will move.
func _open_the_builder() -> void:
	await get_tree().process_frame
	if _rig == null or _rig.clipboard == null:
		return
	_rig.build_the_cockpit(true)
	_rig.clipboard.show_board(true)
	if _rig.clipboard.page() != null:
		_rig.clipboard.page().show_tab(ClipboardPage.Tab.BUILD)
	print("[bench] building %s seat %d: grab to move, SAVE writes JSON" % [Sim.kind_name(kind), seat])


var _chase: Camera3D = null
## What the trim readout is built from: the swing in height and the number of times the
## climb has changed direction. AN AVERAGE CANNOT SEE AN OSCILLATION -- a machine
## porpoising through its bug by a hundred metres has exactly the right mean height -- so
## these are the two numbers that say whether it is actually settled.
var _highest: float = -1e9
var _lowest: float = 1e9
var _flips: int = 0
var _was_climbing: int = 0
var _watching: float = 0.0

var _headless_due: float = 1.0
var _headless_ticks: int = 0


func _physics_process(_delta: float) -> void:
	if _view == null or _entity == 0:
		return
	if mode == Mode.FLY:
		_watch_it_fly(_delta)
		_view.draw()
		_write_the_trim()
		if DisplayServer.get_name() == "headless":
			_headless_due -= _delta
			if _headless_due <= 0.0:
				_headless_due = 1.0
				print(_board.text)
				_headless_ticks += 1
				if _headless_ticks >= 20:
					get_tree().quit()
		return
	# NOTHING DRIVES THE SIMULATION FROM HERE. The rig feeds its own input on its own
	# physics frame and the Sim autoload ticks the world, exactly as they do in the level --
	# a bench that ticked the world itself would be testing a second code path.
	#
	# CREW MODE gets its craft on the ground with the throttle shut, which makes it a stand
	# for four chairs: nothing moves, nothing falls, and what is being tested is whether
	# four people in it see the same thing.
	_view.draw()
	# AND FEED THE SCREENS AND THE SIGHT, which until now only the world did -- so a
	# cockpit on a bench had a sight that said "no gun" and displays with nothing on them,
	# which is the one thing a bench exists to let you look at.
	var roster: Array = _view.crew()
	var state: Dictionary = _view.craft_state()
	for station in _view.stations():
		(station as CockpitStation).show_state(state, roster)
	_write_the_board()
	# Headless, there is no board to look at, so it goes to the log once a second. That is
	# what makes this runnable in the suite as well as by hand.
	if DisplayServer.get_name() == "headless":
		_headless_due -= _delta
		if _headless_due <= 0.0:
			_headless_due = 1.0
			print(_board.text)
			_headless_ticks += 1
			if _headless_ticks >= 2:
				get_tree().quit()


## EVERYTHING THE CRAFT IS DOING, in one column, both halves of it.
##
## The PHYSICS half -- what the aeroplane is being flown with -- and the INTERNAL half, the
## command bus: every channel this kind is fitted with, its value, and whether it is one
## that moves the aircraft or one that only the crew can see. A cockpit is mostly the second
## sort, and the second sort is exactly what has no other way of being checked.
func _write_the_board() -> void:
	var rows: PackedStringArray = []
	rows.append("%s   seat %d of %d   %s" % [
		Sim.kind_name(kind).to_upper(), _rig.seat_index() + 1, _view.seats.size(),
		"CREW (no physics)" if mode == Mode.CREW else "SEAT"])
	rows.append("")

	var frame: Dictionary = _rig.read_controls()
	rows.append("-- what this seat is asking for --")
	for axis in ["throttle", "pitch", "roll", "rudder", "brake"]:
		rows.append("  %-9s %+6.2f" % [axis, float(frame.get(axis, 0.0))])
	rows.append("  buttons   %d" % int(frame.get("buttons", 0)))

	var linked: Dictionary = Sim.client.crew_controls(_entity)
	rows.append("")
	rows.append("-- the linkage, which every seat sees --")
	rows.append("  stick     %+.2f across  %+.2f fore" % [
		(linked.get("linked_stick", Vector2.ZERO) as Vector2).x,
		(linked.get("linked_stick", Vector2.ZERO) as Vector2).y])
	rows.append("  rudder    %+.2f" % float(linked.get("linked_rudder", 0.0)))
	rows.append("  throttle  %+.2f" % float(linked.get("linked_throttle", 0.0)))
	rows.append("  hands on  %s" % [linked.get("hands_on", 255)])

	rows.append("")
	rows.append("-- the command bus --")
	var bus: Dictionary = Sim.client.craft_controls(_entity)
	var systems: Dictionary = Sim.client.craft_systems(_entity)
	for channel in (Sim.client.craft_schema(kind).get("channels", []) as Array):
		var name: String = String(channel.get("name", "?"))
		var physical: bool = bool(channel.get("physical", false))
		rows.append("  %-13s %-9s %s" % [name, _channel_value(name, bus, systems),
			"physics" if physical else "internal"])

	if mode == Mode.SEAT:
		var state: Dictionary = Sim.client.vehicle_state(_entity)
		rows.append("")
		rows.append("-- and what the craft is doing about it --")
		rows.append("  speed     %.1f m/s" % (state.get("velocity", Vector3.ZERO) as Vector3).length())
		rows.append("  height    %.1f m" % (state.get("position", Vector3.ZERO) as Vector3).y)
		rows.append("  spin      %.2f rad/s" % (state.get("spin", Vector3.ZERO) as Vector3).length())
	_board.text = "\n".join(rows)


## FOLLOW IT, from behind and a little above, looking at it. A chase view rather than a
## cockpit one because what is being looked for is the ATTITUDE: an aeroplane hunting in
## pitch is obvious from outside and almost invisible from the seat.
func _watch_it_fly(delta: float) -> void:
	var state: Dictionary = Sim.client.vehicle_state(_entity)
	if state.is_empty():
		return
	var at: Vector3 = state["position"]
	var going: Vector3 = state["velocity"]
	if _chase != null:
		var back: Vector3 = Vector3.BACK
		if going.length() > 1.0:
			back = -going.normalized()
		_chase.global_position = at + back * 60.0 + Vector3.UP * 14.0
		_chase.look_at(at, Vector3.UP)

	# A settling period before anything is counted, so the first seconds of an aeroplane
	# being dropped into the sky do not read as a hunt.
	_watching += delta
	if _watching < 10.0:
		return
	_highest = maxf(_highest, at.y)
	_lowest = minf(_lowest, at.y)
	var climbing: int = 0
	if going.y > 0.6:
		climbing = 1
	elif going.y < -0.6:
		climbing = -1
	if climbing != 0 and _was_climbing != 0 and climbing != _was_climbing:
		_flips += 1
	if climbing != 0:
		_was_climbing = climbing


## IS IT IN TRIM? Every number that answers that, and nothing that does not.
func _write_the_trim() -> void:
	var state: Dictionary = Sim.client.vehicle_state(_entity)
	if state.is_empty():
		_board.text = "%s: the craft has gone" % Sim.kind_name(kind)
		return
	var at: Vector3 = state["position"]
	var going: Vector3 = state["velocity"]
	var facing: Quaternion = state.get("basis", Quaternion.IDENTITY)
	var nose: Vector3 = Basis(facing) * Vector3.FORWARD
	var wing: Vector3 = Basis(facing) * Vector3.RIGHT
	var numbers: Dictionary = Sim.client.handling(kind)
	var stall: float = float(numbers.get("stall_speed", 0.0))
	var bus: Dictionary = Sim.client.craft_controls(_entity)

	var rows: PackedStringArray = []
	rows.append("%s   FLYING ITSELF   %s" % [Sim.kind_name(kind).to_upper(),
		"settling" if _watching < 10.0 else "watched for %.0f s" % (_watching - 10.0)])
	rows.append("")
	rows.append("-- where it is --")
	rows.append("  height    %8.1f m" % at.y)
	rows.append("  climb     %+8.2f m/s" % going.y)
	rows.append("  pitch     %+8.1f deg" % rad_to_deg(asin(clampf(nose.y, -1.0, 1.0))))
	rows.append("  bank      %+8.1f deg" % rad_to_deg(asin(clampf(-wing.y, -1.0, 1.0))))
	rows.append("")
	rows.append("-- how fast, against what it needs --")
	rows.append("  speed     %8.1f m/s" % going.length())
	rows.append("  stall     %8.1f m/s" % stall)
	rows.append("  margin    %8.2f x   %s" % [
		going.length() / maxf(stall, 0.1),
		"THIN" if going.length() < stall * 1.15 else "ok"])
	rows.append("  cruise    %8.1f m/s" % float(numbers.get("cruise", 0.0)))
	rows.append("  throttle  %8.2f" % float(bus.get("throttle", 0.0)))
	rows.append("")
	rows.append("-- is it in trim --")
	if _watching < 10.0:
		rows.append("  settling...")
	else:
		rows.append("  wandered  %8.1f m   (%.0f to %.0f)" % [
			_highest - _lowest, _lowest, _highest])
		rows.append("  hunting   %8d changes of climb direction" % _flips)
		rows.append("  verdict   %s" % [
			"IN TRIM" if _highest - _lowest < 70.0 and _flips <= 4 else "NOT SETTLED"])
	_board.text = "\n".join(rows)


## One channel's value, wherever it happens to live. The physical half is on CraftControls
## and the internal half on CraftSystems, and a board that made the reader know which is a
## board nobody reads.
func _channel_value(name: String, bus: Dictionary, systems: Dictionary) -> String:
	match name:
		"throttle": return "%.2f" % float(bus.get("throttle", 0.0))
		"flaps": return "%.2f" % float(bus.get("flaps", 0.0))
		"trim", "cyclic trim", "drive trim": return "%+.2f" % float(bus.get("trim", 0.0))
		"nacelles": return "%.2f" % float(bus.get("tilt", 0.0))
		"gear", "ramp", "handbrake": return "down" if bool(bus.get("gear", false)) else "up"
		"spoilers": return "out" if bool(bus.get("spoilers", false)) else "in"
		"weapon": return "%d" % int(systems.get("weapon", 0))
		"radio": return "%d" % int(systems.get("radio", 0))
		"display page", "trip computer", "sounder": return "%d" % int(systems.get("display", 0))
		"hover hold", "anchor": return "%d" % int(systems.get("mode", 0))
		"master arm": return "on" if bool(systems.get("master", false)) else "off"
		"crew button": return "lit" if bool(systems.get("crew_light", false)) else "dark"
		_: return "-"


## `-- --kind=osprey --mode=crew`, so a bench can be launched at one craft without opening
## the editor.
func _read_the_command_line() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"kind":
				for i in range(Sim.Kind.size()):
					if Sim.kind_name(i) == parts[1].to_lower():
						kind = i as Sim.Kind
			# `--level=` too, because that is what the boot router is given and asking for
			# the same thing twice on one command line is how you get them disagreeing.
			"mode", "level":
				match parts[1].to_lower():
					"crew": mode = Mode.CREW
					"fly", "trim": mode = Mode.FLY
					"build":
						mode = Mode.SEAT
						build = true
					_: mode = Mode.SEAT
			"seat":
				seat = maxi(int(parts[1]), 0)
			"circuit":
				circuit = maxf(float(parts[1]), 0.0)
			"parked":
				parked = parts[1] not in ["0", "false", "no"]
			"pen":
				pen = parts[1] not in ["0", "false", "no"]
			"afloat":
				afloat = parts[1] not in ["0", "false", "no"]


func _start_a_world() -> void:
	if not Sim.is_available():
		return
	# THE SAME HANDSHAKE THE LEVEL DOES, in the same order: connect first, then ask for a
	# session. `Sim.is_ready` is set from a signal, so a bench that asked for a session and
	# then polled the flag waited for a signal that had already been emitted.
	# An Array and not a bool, because a GDScript lambda captures by VALUE: a flag cleared
	# inside the callback is cleared on a copy, and the loop below waits for ever on the
	# original. It has caught this twice now.
	var waiting: Array = [not Sim.is_ready]
	if bool(waiting[0]):
		Sim.sim_ready.connect(func(): waiting[0] = false, CONNECT_ONE_SHOT)
	Net.play_solo()
	# AND START THE WORLD. `play_solo` only announces a session -- it is the level that
	# listens for that and builds the simulation, and a bench without a level has to do the
	# one line of it that matters. Nothing else in `sky._build` is wanted here: no terrain,
	# no railway, no hundred and forty machines.
	Sim.start()
	var patience: int = 600
	while bool(waiting[0]) and patience > 0:
		patience -= 1
		await get_tree().physics_frame
	# FLY MODE GETS AN AUTOPILOT and everything else gets a vehicle. It is the same spawn
	# the world uses for its traffic, so what is being watched is the autopilot the game
	# actually flies with rather than a second one written for a bench.
	#
	# AND HELD AT THE HEIGHT IT WAS SPAWNED AT, through `set_ai_altitude`, the layer `HoldingStack` gives a stacked
	# aircraft. This said "520 m because that is `recovery_height`: with no waypoints the autopilot holds that" -- true of
	# an AEROPLANE. `recovery_height` sends a helicopter to 220 m, so the heli, UH-60 and Chinook each left 520 m at
	# 12 m/s and were at 250 m 24 s later, through the reel's stage ground at 400 m (the user saw it; `tests/rotor_hold.gd`
	# measures it). Held, every kind stays where it was put, which is what a bench is for.
	if mode == Mode.FLY:
		if circuit > 0.0:
			for corner in [Vector2(0.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)]:
				Sim.add_ai_waypoint(kind, Vector3(corner.x * circuit, FLY_HEIGHT, corner.y * circuit))
		var flown: int = 0
		if afloat:
			# THE WATER WHERE THE REEL DRAWS IT: this kind's sea stands at the river's surface, and with no floor and no
			# ground map under the stage, `water_under` answers "water" everywhere the wheels find nothing.
			Sim.set_handling(kind, {"water_level": STAGE_WATER})
			var waterline: float = float(Sim.geometry_of(kind).get("waterline", 0.0))
			flown = Sim.spawn_vehicle(kind, Vector3(RIVER_X, STAGE_WATER - waterline, 0.0), 0.0,
				Vector3(0.0, 0.0, -TAXI_AFLOAT))
		elif parked:
			var half: Vector3 = Sim.geometry_of(kind).get("extents", Vector3.ONE)
			Sim.add_static_box(Vector3(0.0, STAGE_GROUND - 2.0, 0.0), Vector3(400.0, 2.0, 400.0))
			# AND A PEN: four walls of collision only, 2 cm off each face of the craft's simulation box. The simulation
			# answers a stick with torque at any airspeed, so a full roll input stood an F-14 on its back in the first
			# take of the surfaces reel (2026-09-18). The reel's stage draws only its own scenery, so the pen is never
			# seen; it is a stand, not a claim about how an aeroplane sits on its wheels.
			var clear: float = 0.02
			for side in ([-1.0, 1.0] if pen else []):
				Sim.add_static_box(Vector3(side * (half.x + clear + 0.5), STAGE_GROUND + half.y * 1.5, 0.0),
					Vector3(0.5, half.y * 1.5, half.z + 1.0))
				Sim.add_static_box(Vector3(0.0, STAGE_GROUND + half.y * 1.5, side * (half.z + clear + 0.5)),
					Vector3(half.x + 1.0, half.y * 1.5, 0.5))
			flown = Sim.spawn_vehicle(kind, Vector3(0.0, STAGE_GROUND + half.y + 0.05, 0.0), 0.0)
		else:
			flown = Sim.spawn_ai_vehicle(kind, Vector3(0.0, FLY_HEIGHT, 0.0), 0.0,
				Vector3(0.0, 0.0, -Terrain.cruise_for(kind)))
			if flown != 0:
				Sim.server.set_ai_altitude(flown, FLY_HEIGHT)
		on_server = flown
		# ENTITY IDS ARE PER WORLD. What comes back is the SERVER's, and everything drawn
		# and read here is the CLIENT's copy -- the same distinction that once had a probe
		# reporting 175 degrees of error between two different aeroplanes. So the bench
		# waits for its aeroplane to arrive over the wire and takes the id from there, which
		# is exactly how the level builds its views.
		# BY KIND, not by being first. Every player who joins is issued a pod, including
		# the one nobody is looking through on a bench, so the first entity on the wire is
		# a stationary pod at 30 m and the board cheerfully reported it as in trim.
		for i in range(240):
			await get_tree().physics_frame
			for entity in Sim.current:
				if int((Sim.current[entity] as Dictionary).get("kind", -1)) == kind:
					_entity = int(entity)
					return
		return
	# Airborne if it flies, on the deck if it does not: a bench is not the place to find out
	# that an aeroplane spawned at a standstill stalls before it can accelerate.
	var flying: bool = mode == Mode.SEAT and (kind == Sim.Kind.PLANE \
		or kind == Sim.Kind.AIRLINER or kind == Sim.Kind.OSPREY)
	_entity = Sim.spawn_vehicle(kind, Vector3(0.0, 400.0 if flying else 2.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -Terrain.cruise_for(kind)) if flying else Vector3.ZERO)


func _light_it() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	var sky := WorldEnvironment.new()
	var air := Environment.new()
	air.background_mode = Environment.BG_COLOR
	air.background_color = Color(0.28, 0.36, 0.45)
	air.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	air.ambient_light_color = Color(0.55, 0.58, 0.62)
	air.ambient_light_energy = 0.9
	sky.environment = air
	add_child(sky)


func _build_the_board() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var back := ColorRect.new()
	back.color = Color(0.03, 0.04, 0.05, 0.82)
	back.position = Vector2(12.0, 12.0)
	back.size = Vector2(430.0, 640.0)
	layer.add_child(back)
	_board = Label.new()
	_board.position = Vector2(24.0, 22.0)
	_board.add_theme_font_size_override("font_size", 15)
	_board.add_theme_color_override("font_color", Color(0.55, 0.92, 0.62))
	layer.add_child(_board)
