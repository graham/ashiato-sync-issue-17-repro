extends Node
## What actually stops the car going faster?
##
##   Godot --path addon --headless res://tests/top_speed.tscn
##
## Four things could be the binding constraint, and only one of them is. Rather than argue
## from the equations, each is moved on its own and the effect measured: whatever changes
## top speed is what was limiting it.

const DT: float = 1.0 / 60.0


func _top_speed(tune: Dictionary) -> float:
	var w = ClassDB.instantiate("DrivingWorld")
	w.start(0)
	w.set_handling(tune)
	var car: int = w.spawn_car(0, Vector3(0, 0.5, 0))
	var best: float = 0.0
	for i in range(2400):
		w.set_car_input(car, 1.0, 0.0, false)
		w.tick(DT)
		var v: Vector3 = w.car_state(car)["velocity"]
		best = maxf(best, Vector2(v.x, v.z).length())
		var p: Vector3 = w.car_state(car)["position"]
		if absf(p.x) > 350.0 or absf(p.z) > 350.0:
			break   # the test world's ground runs out at 400 m
	w.teardown()
	return best


func _ready() -> void:
	var base: float = _top_speed({})
	print("[top] stock: %.1f m/s (%.0f km/h)" % [base, base * 3.6])
	print("[top] moving one thing at a time:")
	var cases: Array = [
		["engine_hp x2", {"engine_hp": 234.0}],
		["drag halved", {"drag": 4.0}],
		["rolling resistance x0", {"rolling_resistance": 0.0}],
		["gearing x2 (low-speed force)", {"drive_force_per_hp": 85.4}],
		["grip x2", {"grip": 4.6}],
		["grip speed loss x0", {"grip_speed_loss": 0.0}],
	]
	for c in cases:
		var v: float = _top_speed(c[1])
		print("[top]   %-30s %5.1f m/s   %+5.1f" % [c[0], v, v - base])

	# Power against drag means top speed goes as the CUBE root of power: doubling it is
	# worth about 26%, not 100%. If that holds, the limit is aerodynamic.
	var doubled: float = _top_speed({"engine_hp": 234.0})
	var ratio: float = doubled / base
	print("[top] doubling power gave %.2fx; the cube root of 2 is %.2f" % [
		ratio, pow(2.0, 1.0 / 3.0)])

	# Asserted, because the answer is a design decision as much as a measurement: the car
	# is meant to be limited by the air, not by its tires or its ability to put power down.
	# If grip or gearing ever start moving top speed, something has changed that nobody
	# meant to change.
	var failures: PackedStringArray = []
	if absf(ratio - pow(2.0, 1.0 / 3.0)) > 0.06:
		failures.append("power no longer buys the cube root: %.2fx" % ratio)
	for locked in [["gearing", {"drive_force_per_hp": 85.4}], ["grip", {"grip": 4.6}]]:
		var v: float = _top_speed(locked[1])
		if absf(v - base) > 0.3:
			failures.append("%s now changes top speed by %.1f m/s" % [locked[0], v - base])
	for f in failures:
		print("[top] FAIL %s" % f)
	print("[top] RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)
