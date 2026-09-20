extends Node
## What happens to the predicted car when you LET GO of a key?
##
##   Godot --path addon --headless res://tests/input_release.tscn
##
## Reported symptom: releasing throttle snaps the car back to an earlier state. Prediction
## runs ahead of the server, so a correction that is not reconciled forward shows up as a
## jump backwards -- and releasing a key is exactly when the client's input and whatever
## the server last heard are most likely to disagree.
##
## Measures the client car's position every tick and reports any BACKWARD movement, which
## a car coasting to a stop should never do.

const DT: float = 1.0 / 60.0
const DELAY: int = 4

var _flight: Array = []
var _tick: int = 0
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[release] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _pump(s, c) -> void:
	for p in s.take_outbound():
		_flight.append([_tick + DELAY, false, p["bytes"], p["bits"]])
	for p in c.take_outbound():
		_flight.append([_tick + DELAY, true, p["bytes"], p["bits"]])
	var keep: Array = []
	for e in _flight:
		if e[0] <= _tick:
			if e[1]: s.deliver(1, e[2], e[3])
			else: c.deliver(0, e[2], e[3])
		else: keep.append(e)
	_flight = keep


func _ready() -> void:
	var s = ClassDB.instantiate("DrivingWorld")
	var c = ClassDB.instantiate("DrivingWorld")
	s.start(0)
	c.start(1)
	s.spawn_car(0, Vector3(20, 0.5, 0))   # a bystander, so the server has traffic
	for i in range(90):
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c)
	while c.local_client_id() == 0:
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c)
	s.spawn_car(c.local_client_id(), Vector3(0, 0.5, 0))

	var mine: int = 0
	for i in range(90):
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c)
		for e in c.car_entities():
			if c.car_owner(e) == c.local_client_id():
				mine = e
	_check("own_car_found", mine != 0, "client entity %d" % mine)
	if mine == 0:
		_finish(); return

	# Drive forward for a second.
	for i in range(60):
		c.set_input(1.0, 0.0, false)
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c)

	var at_release: Vector3 = c.car_state(mine).get("position", Vector3())
	var speed_at_release: float = (c.car_state(mine).get("velocity", Vector3()) as Vector3).length()
	_check("moving_before_release", speed_at_release > 1.0,
		"%.1f m/s when the key is let go" % speed_at_release)

	# LET GO. Then watch every tick for the car going backwards or jumping.
	var previous: Vector3 = at_release
	var worst_backward: float = 0.0
	var worst_jump: float = 0.0
	var previous_speed: float = speed_at_release
	var dropped_by: int = -1
	var forward := Vector3(sin(c.car_state(mine).get("yaw", 0.0)), 0,
						   cos(c.car_state(mine).get("yaw", 0.0)))
	for i in range(120):
		c.set_input(0.0, 0.0, false)
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c)
		var speed_now: float = (c.car_state(mine).get("velocity", Vector3()) as Vector3).length()
		if dropped_by < 0 and speed_now < previous_speed:
			dropped_by = i
		previous_speed = speed_now
		var now: Vector3 = c.car_state(mine).get("position", Vector3())
		var step: Vector3 = now - previous
		# Movement against the car's heading: a coasting car must not reverse.
		worst_backward = maxf(worst_backward, -step.dot(forward))
		worst_jump = maxf(worst_jump, step.length())
		previous = now

	print("[release] worst backward step %.4f m, worst single-tick jump %.4f m" %
		[worst_backward, worst_jump])
	_check("release_took_effect_immediately", dropped_by <= 3 and dropped_by >= 0,
		"speed began falling %d ticks after the key was let go" % dropped_by)
	# A car decelerating from ~20 m/s covers ~0.33 m a tick, so a jump far above that is a
	# correction being applied as a teleport rather than reconciled.
	_check("never_moves_backward", worst_backward < 0.01,
		"%.4f m against its own heading while coasting" % worst_backward)
	_check("no_teleport_on_release", worst_jump < 0.6,
		"largest single-tick move %.4f m" % worst_jump)

	_finish()


func _finish() -> void:
	print("[release] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % [_failures]))
	get_tree().quit(0 if _failures.is_empty() else 1)
