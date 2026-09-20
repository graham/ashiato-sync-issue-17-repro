extends Node
## Headless: does the stick leave an aeroplane at a standstill alone, as a wing with no air over it must?
##
##   Godot --headless --path cockpit res://tests/ground_stick.tscn [-- --kind=tomcat] [--set=control_authority*0.5]
##
## THE BUG, 2026-09-18 (`lane/tomcat2`, learnings/2026-09-18-tomcat2.md): a scripted stick stood a parked F-14 on its
## back in the first take of its surfaces reel. A control surface is a small wing, and what it pushes with is dynamic
## pressure, one half rho v squared: at a standstill it pushes with nothing, and on the ground the wheels hold the
## aeroplane level. The user: "fix this please". Two causes, both in `cockpit_world.cpp`:
## - `apply_controls` kept a 12 per cent FLOOR under the surfaces' authority whatever the airspeed. It is now
##   `surface_bite`, the dynamic pressure's share of what it is at `control_reference`, with no floor.
## - `fly_airplane`'s taxiing branch, where the stick does nothing and the rudder is a nosewheel, asked for a HEIGHT
##   against the terrain map as well as weight on the wheels, so a craft on a floor the map does not know (the reel's
##   stage, 400 m up) got the flight controls on its wheels. It now asks the wheels' own ray.
##
## EVERY RUN IS FLOWN THROUGH `set_pilot_input`, the frame a seated player's rig sends: the stick and the pedals, the
## brakes held, the lever at idle. Nothing is placed, spun or read back by any function the craft is flown with.
##
## WHERE EACH AEROPLANE STANDS, and why each is here:
## - ON A STAGE 400 m UP: a static floor where the bench's `--parked` reel stands its craft. This is the floor the bug
##   was found on, and the terrain map says the ground is 400 m below it.
## - ON THE SLAB AT SEA LEVEL: the runway every other suite uses, where the taxiing branch already held.
## - AFLOAT, for the two that land on water: the water bomber and the Savoia, out past the slab's edge.
##
## WHAT IS HELD, per aeroplane per place:
## - PARKED, FULL STICK LEFT, RIGHT, BACK AND FORWARD AND FULL PEDAL, three seconds each: the bank and the pitch move
##   by less than PARKED_DEGREES, and the body's roll and pitch rates stay within PARKED_RATE of what they were over
##   three seconds hands off (the swell rocks a flying boat on its own).
## - TAXIING AT 5 m/s ON WHEELS, FULL STICK LEFT AND RIGHT: the bank moves by less than TAXI_DEGREES more than it does
##   hands off. On the stage that was the second cause: with the surfaces faded to a twenty-third of their authority
##   the three jets still rolled onto their backs there, until the taxiing branch asked the wheels.
## - TAXIING AT 5 m/s AFLOAT, FULL STICK LEFT AND RIGHT: the bank moves by less than FLOAT_DEGREES more than it does
##   hands off. The flight controls stay on afloat (making the water a taxiing branch killed the stick on the take-off
##   run and `tests/water.gd`'s water bomber skipped off the sea twice), so what holds the wings up is the WINGTIP
##   FLOATS (`float_the_wingtips`, lane/floats): before them `alight` left a hull neutral in roll, and a held full
##   stick rolled the Savoia over (179.6 degrees on main 6bb8d96c) and tipped the water bomber 20.
## - AND THE SAME WITHOUT THE FLOATS, which must FAIL the row above: `float_lift` 0 is the hull with its floats taken
##   away, and if a flying boat stays upright then too, the row is not measuring its floats.
## - AT ROTATION SPEED the stick is SUPPOSED to work, so nothing is held there: the bank and pitch a full stick gives
##   in a second and a half on the stage are printed, so the next lane can see the surfaces come alive.
##
## Read RESULT=.

const TICK: float = 1.0 / 120.0
const CLIENT: int = 70
## THE BENCH'S STAGE: `tests/bench.gd`'s STAGE_GROUND, where the reel that found this stands its craft.
const STAGE: float = 400.0
## The island slab's half-width; beyond it there is only sea (as `water_rudder.gd`).
const COAST: float = 7200.0
## A PARKED AEROPLANE UNDER A FULL STICK: degrees of bank or pitch it may move, and rad/s it may turn at. The hull is a
## box on a floor, so it settles a fraction of a degree on its own; main's library rolled the F-14 past 90.
const PARKED_DEGREES: float = 2.0
const PARKED_RATE: float = 0.05
const TAXI: float = 5.0
const TAXI_DEGREES: float = 2.0
## AFLOAT, A WING SITS DOWN ON ITS FLOAT: a level flying boat's floats kiss the water or clear it, so a held stick dips
## the wing until its float is far enough in to hold it, which is how a real one rests. So the bank a full stick may
## reach afloat is the bank that puts the float's top in the water, worked out from the simulation's own floats and
## waterline (`_float_buried_at`), and this much over it for the swell. Measured on lane/floats: the Savoia sits at 10.0
## degrees against 9.3 to bury its float, the water bomber at 3.0 against 1.3 (the stick at 5 m/s is still far stronger
## than an aileron at that speed would be -- gap 1 in agents.md's "The flight model, as found" -- so both floats go
## all the way in, and the floats are what stop them there).
const FLOAT_DEGREES: float = 4.0
const HOLD: float = 3.0
## The lever pulled to its stop: 0.0 means "hand off the lever" and leaves it where it was (`handling.gd`, IDLE).
const IDLE: float = 0.002
const AMPHIBIANS: Array = [Sim.Kind.TANKER, Sim.Kind.SAVOIA]

var _failures: PackedStringArray = []
var _world: Object = null
var _craft: int = 0
var _pilot: int = 0
var _input: Dictionary = {}
## `--set=` retunes, as `handling.gd`: key -> [is_factor, number].
var _overrides: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[ground_stick] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	var only: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):
			only = arg.trim_prefix("--kind=")
		if arg.begins_with("--set="):
			for pair in arg.trim_prefix("--set=").split(",", false):
				var factor: bool = pair.contains("*")
				var bits: PackedStringArray = pair.split("*" if factor else "=")
				_overrides[bits[0]] = [factor, float(bits[1])]
	var flown: int = 0
	for kind in range(Sim.Kind.size()):
		var name: String = Sim.kind_name(kind)
		if not only.is_empty() and name != only:
			continue
		if int(Sim.geometry_of(kind).get("model", -1)) != Sim.Model.AIRPLANE:
			continue
		if not bool(Sim.geometry_of(kind).get("pilotable", true)):
			continue
		flown += 1
		_parked(kind, "stage")
		_parked(kind, "slab")
		_taxiing(kind, "stage")
		_taxiing(kind, "slab")
		if kind in AMPHIBIANS:
			_parked(kind, "afloat")
			_taxiing(kind, "afloat")
			_taxiing(kind, "afloat", {"float_lift": 0.0})
		_at_rotation_speed(kind)
		_end()
		await get_tree().process_frame
	_check("every_aeroplane_was_stood_still_and_measured", flown > 0, "%d aeroplanes" % flown)
	_finish()


## ---- the world and the seat -----------------------------------------------------------------------------------

## A WORLD, and the aeroplane standing still or rolling at `speed` along its nose, settled for `settle` seconds with
## the stick centred. Returns false if the seat could not be taken.
func _begin(kind: int, place: String, speed: float, settle: float, mutant: Dictionary = {}) -> bool:
	_end()
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	var hy: float = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y)
	var at: Vector3
	match place:
		"stage":
			_world.add_static_box(Vector3(0.0, STAGE - 2.0, 0.0), Vector3(2000.0, 2.0, 2000.0))
			at = Vector3(0.0, STAGE + hy + 0.05, 0.0)
		"slab":
			_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(COAST, 400.0, COAST))
			at = Vector3(0.0, hy + 0.05, 0.0)
		_:
			_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(COAST, 400.0, COAST))
			at = Vector3(0.0, 1.0, COAST + 1200.0)
	if not _overrides.is_empty():
		var now: Dictionary = _world.handling(kind)
		var tuned: Dictionary = {}
		for key in _overrides:
			var o: Array = _overrides[key]
			tuned[key] = float(now.get(key, 0.0)) * float(o[1]) if bool(o[0]) else float(o[1])
		_world.set_handling(kind, tuned)
	if not mutant.is_empty():
		_world.set_handling(kind, mutant)
	# Yaw 0 points the nose along -Z.
	var made: Dictionary = _world.spawn_pilot(CLIENT, kind, at, 0.0, Vector3(0.0, 0.0, -speed))
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_input = {"throttle": IDLE, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 1.0 if speed == 0.0 else 0.0}
	if _craft == 0 or _pilot == 0:
		return false
	_hold(settle, speed)
	return true


func _end() -> void:
	if _world != null:
		_world.teardown()
		_world = null


## `seconds` of the pilot's frame as it stands, with the lever working to hold `speed` along the nose if it is not 0.
## Returns the most the bank and the pitch moved from where they were at the start, and the largest roll and pitch rate.
func _hold(seconds: float, speed: float) -> Dictionary:
	var first: Dictionary = _read()
	var most := {"bank": 0.0, "pitch": 0.0, "roll_rate": 0.0, "pitch_rate": 0.0, "tilt": 0.0}
	for i in range(int(round(seconds / TICK))):
		if speed > 0.0:
			var along: float = float(_read().get("along", 0.0))
			_input["throttle"] = clampf(0.1 + (speed - along) * 0.3, IDLE, 1.0)
		_world.set_pilot_input(_pilot, _input)
		_world.tick(TICK)
		var r: Dictionary = _read()
		most["bank"] = maxf(most["bank"], absf(wrapf(float(r["bank"]) - float(first["bank"]), -180.0, 180.0)))
		most["tilt"] = maxf(most["tilt"], absf(float(r["bank"])))
		most["pitch"] = maxf(most["pitch"], absf(float(r["pitch"]) - float(first["pitch"])))
		most["roll_rate"] = maxf(most["roll_rate"], absf(float(r["roll_rate"])))
		most["pitch_rate"] = maxf(most["pitch_rate"], absf(float(r["pitch_rate"])))
	return most


## The attitude in a pilot's words, and the body's own rates: roll about the nose, pitch about the right wing.
func _read() -> Dictionary:
	var s: Dictionary = _world.vehicle_state(_craft)
	var b := Basis(s.get("basis", Quaternion()) as Quaternion)
	var nose: Vector3 = b * Vector3.FORWARD
	var right: Vector3 = b * Vector3.RIGHT
	var up: Vector3 = b * Vector3.UP
	var spin: Vector3 = s.get("spin", Vector3.ZERO)
	var v: Vector3 = s.get("velocity", Vector3.ZERO)
	# Bank from atan2, so a craft on its back reads 180 rather than asin's 0.
	return {
		"bank": rad_to_deg(atan2(-right.y, up.y)),
		"pitch": rad_to_deg(asin(clampf(nose.y, -1.0, 1.0))),
		"roll_rate": spin.dot(nose),
		"pitch_rate": spin.dot(right),
		"along": v.dot(nose),
		"up": up.y,
	}


## ---- what is held ----------------------------------------------------------------------------------------------

func _parked(kind: int, place: String) -> void:
	var name: String = Sim.kind_name(kind)
	if not _begin(kind, place, 0.0, 3.0):
		_check("%s_%s_could_be_boarded" % [name, place], false, "spawn_pilot refused it")
		return
	# HANDS OFF FIRST: what the floor or the swell does on its own, which the rates are held against. Afloat, the
	# water bomber rocks at 0.05 rad/s with nobody touching anything.
	var still: Dictionary = _hold(HOLD, 0.0)
	var worst := {"bank": 0.0, "pitch": 0.0, "roll_rate": 0.0, "pitch_rate": 0.0}
	var notes: PackedStringArray = ["hands off: bank %.1f pitch %.1f roll rate %.3f" % [still["bank"], still["pitch"],
		still["roll_rate"]]]
	for leg in [["roll", 1.0], ["roll", -1.0], ["pitch", 1.0], ["pitch", -1.0], ["rudder", 1.0]]:
		_input["pitch"] = 0.0
		_input["roll"] = 0.0
		_input["rudder"] = 0.0
		_input[leg[0]] = leg[1]
		var got: Dictionary = _hold(HOLD, 0.0)
		for key in worst:
			worst[key] = maxf(worst[key], got[key])
		notes.append("%s %+d: bank %.1f pitch %.1f" % [leg[0], int(leg[1]), got["bank"], got["pitch"]])
	var ok: bool = worst["bank"] < PARKED_DEGREES and worst["pitch"] < PARKED_DEGREES \
		and worst["roll_rate"] < still["roll_rate"] + PARKED_RATE 		and worst["pitch_rate"] < still["pitch_rate"] + PARKED_RATE
	_check("%s_parked_%s_the_stick_moves_nothing" % [name, place], ok,
		"most bank %.2f deg, pitch %.2f deg, roll rate %.3f, pitch rate %.3f rad/s, up %.2f; %s"
		% [worst["bank"], worst["pitch"], worst["roll_rate"], worst["pitch_rate"], float(_read()["up"]),
			", ".join(notes)])


func _taxiing(kind: int, place: String, mutant: Dictionary = {}) -> void:
	var name: String = Sim.kind_name(kind)
	if not _begin(kind, place, TAXI, 2.0, mutant):
		_check("%s_%s_could_be_boarded" % [name, place], false, "spawn_pilot refused it")
		return
	var still: Dictionary = _hold(HOLD, TAXI)
	var worst: float = 0.0
	var tilt: float = 0.0
	var notes: PackedStringArray = ["hands off: bank %.1f" % still["bank"]]
	for side in [1.0, -1.0]:
		_input["roll"] = side
		var got: Dictionary = _hold(HOLD, TAXI)
		worst = maxf(worst, got["bank"])
		tilt = maxf(tilt, got["tilt"])
		notes.append("roll %+d: bank %.1f, %.1f from level" % [int(side), got["bank"], got["tilt"]])
	_input["roll"] = 0.0
	var along: float = float(_read()["along"])
	var detail: String = "most bank %.2f deg at %.1f m/s; %s" % [worst, along, ", ".join(notes)]
	if place == "afloat":
		# FROM LEVEL, not from where each leg started: a wing held down on its float and then the other is a swing of
		# twice the bank either one sits at, and it is the bank that says whether the float is holding.
		var allowed: float = _float_buried_at(kind) + FLOAT_DEGREES
		var held: bool = tilt < allowed
		detail = "most %.2f deg from level, allowed %.2f; %s" % [tilt, allowed, detail]
		if mutant.is_empty():
			_check("%s_taxiing_afloat_at_5_its_floats_hold_the_wings_up" % name, held, detail)
		else:
			_check("%s_taxiing_afloat_at_5_without_its_floats_goes_over" % name, not held,
				"%s; the row above must fail with float_lift 0, or it is not measuring the floats" % detail)
		return
	_check("%s_taxiing_%s_at_5_the_stick_barely_banks_it" % [name, place], worst < still["bank"] + TAXI_DEGREES,
		detail)


## THE BANK AT WHICH A FLYING BOAT'S FLOAT IS ALL THE WAY UNDER, in degrees: the float's top over the waterline, over
## how far out it is. From `kind_geometry`, the same floats and waterline the physics floats it on; 90 if it has none.
func _float_buried_at(kind: int) -> float:
	var geometry: Dictionary = Sim.geometry_of(kind)
	var floats: Array = geometry.get("floats", []) as Array
	if floats.is_empty():
		return 90.0
	var one: Dictionary = floats[0]
	var keel: Vector3 = one["keel"]
	var top: float = keel.y + float(one["height"]) - float(geometry.get("waterline", 0.0))
	return rad_to_deg(atan2(maxf(top, 0.0), absf(keel.x)))


## AT ROTATION SPEED, REPORTED: the surfaces are meant to work here. Stood on the stage, where the flight branch runs,
## with the lever holding the speed, a second and a half of full right stick and then of full back stick.
func _at_rotation_speed(kind: int) -> void:
	var name: String = Sim.kind_name(kind)
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	var rotate: float = 1.2 * float((world.handling(kind) as Dictionary).get("stall_speed", 30.0))
	world.teardown()
	var said: PackedStringArray = []
	for leg in [["roll", 1.0], ["pitch", 1.0]]:
		if not _begin(kind, "stage", rotate, 0.5):
			return
		_input[leg[0]] = leg[1]
		var got: Dictionary = _hold(1.5, rotate)
		said.append("%s +1: bank %.1f pitch %.1f" % [leg[0], got["bank"], got["pitch"]])
	print("[ground_stick] %s at rotation speed %.1f m/s on the stage (reported, not held): %s"
		% [name, rotate, ", ".join(said)])


func _finish() -> void:
	_end()
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
