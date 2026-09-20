extends Node
## Do another player's front wheels point the right way when they REVERSE?
##
##   Godot --path addon --headless res://tests/reverse_wheels.tscn
##
## Only your own car knows its steering angle -- input is never replicated. Everyone
## else's is inferred from the bicycle relation, yaw_rate = v * tan(steer) / wheelbase,
## turned around. The catch is that `v` there is SIGNED: reverse, and the same steering
## angle produces the opposite yaw rate, because the wheels are dragging the car rather
## than pulling it. Invert that with a speed MAGNITUDE and the wheels come out mirrored --
## correct on the driver's screen, backwards on everyone else's.

const DT: float = 1.0 / 60.0
const WHEELBASE: float = 2.6
const MAX_LOCK: float = 0.58
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[reverse] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## What race.gd used to compute for somebody else's car: speed as a magnitude.
func _angle_from_magnitude(state: Dictionary) -> float:
	var speed: float = (state["velocity"] as Vector3).length()
	if speed < 1.0:
		return 0.0
	return clampf(atan2(float(state["yaw_rate"]) * WHEELBASE, speed), -MAX_LOCK, MAX_LOCK)


## What it computes now: velocity projected onto the car's own nose, sign and all.
func _angle_from_signed(state: Dictionary) -> float:
	var v: Vector3 = state["velocity"]
	var yaw: float = state["yaw"]
	var forward: float = Vector2(v.x, v.z).dot(Vector2(sin(yaw), cos(yaw)))
	if absf(forward) < 1.0:
		return 0.0
	return clampf(atan(float(state["yaw_rate"]) * WHEELBASE / forward), -MAX_LOCK, MAX_LOCK)


## Drives one car and reports [true steer, angle from magnitude, angle from signed speed].
func _drive(throttle: float, steer: float) -> Array:
	var w = ClassDB.instantiate("DrivingWorld")
	w.start(0)
	var car: int = w.spawn_car(0, Vector3(0, 0.5, 0))
	for i in range(240):
		w.set_car_input(car, throttle, steer, false)
		w.tick(DT)
	var state: Dictionary = w.car_state(car)
	var truth: float = w.steer_angle(car)
	var out: Array = [truth, _angle_from_magnitude(state), _angle_from_signed(state),
		Vector2(state["velocity"].x, state["velocity"].z).dot(
			Vector2(sin(state["yaw"]), cos(state["yaw"])))]
	w.teardown()
	return out


func _ready() -> void:
	for case in [["forwards", 1.0, 1.0], ["reversing", -1.0, 1.0]]:
		var r: Array = _drive(case[1], case[2])
		print("[reverse] %-10s forward speed %6.2f m/s  true steer %6.3f  magnitude %6.3f  signed %6.3f"
			% [case[0], r[3], r[0], r[1], r[2]])
		# Sign is the whole question: a wheel drawn at the right angle the wrong way round
		# is worse than one drawn straight.
		_check("%s_signed_matches_the_driver" % case[0],
			signf(r[2]) == signf(r[0]) and absf(r[2]) > 0.05,
			"true %.3f, inferred %.3f" % [r[0], r[2]])
		if case[0] == "reversing":
			_check("magnitude_version_was_wrong",
				signf(r[1]) != signf(r[0]),
				"the old formula gave %.3f where the driver had %.3f -- this is the bug"
					% [r[1], r[0]])

	print("[reverse] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % [_failures]))
	get_tree().quit(0 if _failures.is_empty() else 1)
