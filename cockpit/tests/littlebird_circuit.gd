extends Node
## Headless: THE LITTLE BIRD TAKES OFF, FLIES A HELICOPTER PATTERN, AND LANDS.
##
##   Godot --headless --path cockpit --fixed-fps 120 --xr-mode off res://tests/littlebird_circuit.tscn
##   [... -- --set=rotors=0]  the old thruster, the climb check's mutant, as `--set=surfaces=0` on the Cessna.
##
## A seated pilot's own frame (`set_pilot_input`) flies a 500 ft circuit, closer in than
## the aeroplane pattern ([AIM] 4-3-3 a; FAA Helicopter Flying Handbook ch.9: five legs,
## nose along the track, a 7-12 degree final, hover, then a vertical settle).
## The robot is `LittleBirdCircuitPilot`: rate-limited stick, heading slewed at 10 deg/s,
## bank capped at 16 degrees. The first version chased corners with full cyclic and
## looked like a series of skids.
##
## Read RESULT=.

const TICK: float = 1.0 / 120.0
const CLIENT: int = 60
const KIND: int = Sim.Kind.LITTLEBIRD
const MOST_SECONDS: float = 280.0
const STRIP_HALF: float = 22.5
const RUNWAY_HALF: float = 450.0

var _world: Object
var _pilot: int = 0
var _craft: int = 0
var _hands: LittleBirdCircuitPilot
var _hy: float = 1.3
var _t: float = 0.0
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[littlebird_circuit] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL no CockpitWorld")
		get_tree().quit(1)
		return
	_hy = float((Sim.geometry_of(KIND).get("extents", Vector3.ONE) as Vector3).y)
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(8000.0, 400.0, 8000.0))
	var card := TuningCard.from_command_line()
	card.apply_to(_world, KIND)
	if not card.is_empty():
		print("[littlebird_circuit] %s rotors=%s" % [str(card.retune), _world.handling(KIND).get("rotors", "?")])
	var made: Dictionary = _world.spawn_pilot(CLIENT, KIND, Vector3(0.0, _hy + 0.08, 320.0), 0.0, Vector3.ZERO)
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_hands = LittleBirdCircuitPilot.new()
	_hands.begin(_world.handling(KIND), _hy, 0.0)
	_check("a_pilot_is_seated_on_the_strip", _craft != 0 and _pilot != 0,
		"vehicle %d, pilot %d, hy %.2f" % [_craft, _pilot, _hy])
	if _craft == 0:
		_finish()
		return
	_fly_the_circuit()
	_finish()


func _fly_the_circuit() -> void:
	var last_leg: String = ""
	while _t < MOST_SECONDS and not _hands.landed:
		var r: Dictionary = _read()
		var input: Dictionary = _hands.step(r, TICK)
		_world.set_pilot_input(_pilot, input)
		_world.tick(TICK)
		_t += TICK
		if _hands.leg != last_leg:
			print("[littlebird_circuit] leg %s at %.1f s: x %.0f z %.0f y %.0f speed %.1f heading %.0f" % [
				_hands.leg, _t, (r["at"] as Vector3).x, (r["at"] as Vector3).z, (r["at"] as Vector3).y,
				float(r["ground_speed"]), float(r["heading"])])
			last_leg = _hands.leg
	var r: Dictionary = _read()
	var at: Vector3 = r["at"]
	var nose_share: float = 0.0
	if _hands.nose_fast_s > 1.0:
		nose_share = _hands.nose_ok_s / _hands.nose_fast_s
	_check("it_lifts_off_from_the_strip", _hands.lifted,
		"highest %.1f m AGL (hy %.2f)" % [_hands.max_y - _hy, _hy])
	_check("it_reaches_helicopter_pattern_height", _hands.at_height,
		"highest %.1f m AGL against 500 ft = %.0f m" % [_hands.max_y - _hy, LittleBirdCircuitPilot.PATTERN_FT])
	_check("it_flies_the_downwind_beside_the_runway", _hands.on_downwind,
		"furthest left %.0f m (offset %.0f)" % [_hands.downwind_x, LittleBirdCircuitPilot.OFFSET])
	_check("it_flies_nose_forward", nose_share >= 0.75,
		"heading within 25 deg of track for %.0f %% of time above 8 m/s (at least 75)" % [100.0 * nose_share])
	_check("it_lands_on_the_runway", _hands.landed and absf(at.x) < STRIP_HALF + 18.0
			and at.z > -RUNWAY_HALF and at.z < RUNWAY_HALF and float(r["up"]) > 0.9,
		"at rest x %.1f z %.1f y %.1f (hy %.2f), sink %.2f m/s, up %.2f, last leg %s" % [
			at.x, at.z, at.y, _hy, _hands.touch_vy, float(r["up"]), _hands.leg])


func _read() -> Dictionary:
	var s: Dictionary = _world.vehicle_state(_craft)
	var b := Basis(s.get("basis", Quaternion()) as Quaternion)
	var nose: Vector3 = b * Vector3.FORWARD
	var right: Vector3 = b * Vector3.RIGHT
	var v: Vector3 = s.get("velocity", Vector3.ZERO)
	var flat := Vector3(v.x, 0.0, v.z)
	return {
		"at": s.get("position", Vector3.ZERO) as Vector3, "v": v, "along": v.dot(nose),
		"ground_speed": flat.length(), "vy": v.y, "side": v.dot(right), "up": (b * Vector3.UP).y,
		"pitch": rad_to_deg(asin(clampf(nose.y, -1.0, 1.0))),
		"bank": rad_to_deg(asin(clampf(-right.y, -1.0, 1.0))),
		"heading": rad_to_deg(atan2(-nose.x, -nose.z)),
	}


func _finish() -> void:
	if _world != null:
		_world.teardown()
		_world = null
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
