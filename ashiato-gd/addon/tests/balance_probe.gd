extends Node
## Does the car understeer or oversteer, and by how much?
##
##   Godot --path addon --headless res://tests/balance_probe.tscn
##
## "It feels loose" is not something you can tune against. This compares the turn the
## front wheels ASKED for against the turn the car actually took:
##
##   neutral yaw rate = speed * tan(steer) / wheelbase
##
## balance = actual / neutral. Below 1 the car is running wider than the wheels point
## (understeer); above 1 it is rotating faster than they point (oversteer). Sideslip is
## the angle between where the car is pointing and where it is actually going -- the tail
## hanging out -- which is what "loose" actually looks like from the driver's seat.

const DT: float = 1.0 / 60.0


## Samples the whole corner rather than reading the state at the end.
##
## Reading only the final tick was measuring the wrong thing entirely: ten seconds of
## brake stops the car and then REVERSES it, and a car reversing with its wheels turned
## pirouettes -- which showed up as 162 degrees of sideslip and looked exactly like a
## catastrophic spin. Nothing was wrong with the car. Only ticks where it is still
## travelling forwards at a sane speed say anything about handling.
func _measure(label: String, throttle: float, lock: float, entry: float) -> Dictionary:
	var w = ClassDB.instantiate("DrivingWorld")
	w.start(0)
	var car: int = w.spawn_car(0, Vector3(0, 0.5, 0))

	var balances: Array[float] = []
	var peak_slip: float = 0.0
	var spun: bool = false
	for i in range(900):
		var st: Dictionary = w.car_state(car)
		var v: Vector3 = st["velocity"]
		var flat := Vector2(v.x, v.z)
		var speed: float = flat.length()
		if i < 300:
			w.set_car_input(car, 1.0 if speed < entry else 0.0, 0.0, false)
			w.tick(DT)
			continue
		w.set_car_input(car, throttle, lock, false)
		w.tick(DT)

		st = w.car_state(car)
		v = st["velocity"]
		flat = Vector2(v.x, v.z)
		speed = flat.length()
		if speed < 4.0:
			continue
		var yaw: float = st["yaw"]
		var heading := Vector2(sin(yaw), cos(yaw))
		# Still going roughly forwards? Once it is not, it is reversing, not sliding.
		if heading.dot(flat.normalized()) < 0.0:
			continue
		var slip: float = absf(heading.angle_to(flat.normalized()))
		peak_slip = maxf(peak_slip, slip)
		if slip > deg_to_rad(45.0):
			spun = true
		var steer: float = w.steer_angle(car)
		var neutral: float = speed * tan(steer) / w.wheelbase()
		if absf(neutral) > 0.001:
			balances.append(float(st["yaw_rate"]) / neutral)

	if balances.is_empty():
		print("  %-20s no usable samples" % label)
		w.teardown()
		return {}
	var mean: float = 0.0
	for b in balances:
		mean += b
	mean /= float(balances.size())
	var settled: float = Vector2(
		w.car_state(car)["velocity"].x, w.car_state(car)["velocity"].z).length()
	var verdict: String = "neutral"
	if mean < 0.9:
		verdict = "understeer"
	elif mean > 1.1:
		verdict = "OVERSTEER"
	print("  %-20s balance %4.2f (%-10s)  peak sideslip %4.1f deg  settled %4.1f m/s%s" % [
		label, mean, verdict, rad_to_deg(peak_slip), settled,
		"   <-- SPUN" if spun else ""])
	w.teardown()
	return {"balance": mean, "sideslip": rad_to_deg(peak_slip), "spun": spun}


func _ready() -> void:
	print("balance = actual turn / turn the wheels asked for.  <1 understeer, >1 oversteer")
	var results: Dictionary = {}
	print("-- mid speed (16 m/s entry) --")
	results["mid_steady"] = _measure("steady throttle", 0.55, 1.0, 16.0)
	results["mid_power"] = _measure("hard power", 1.0, 1.0, 16.0)
	results["mid_lift"] = _measure("lift off", 0.0, 1.0, 16.0)
	results["mid_brake"] = _measure("braking in", -0.5, 1.0, 16.0)
	_measure("half lock, steady", 0.55, 0.5, 16.0)
	_measure("half lock, lift", 0.0, 0.5, 16.0)
	# The cases the car is actually asked about at racing speed. Understeer here reads as
	# "the car ignored me"; a four-wheel slide reads as something you are doing.
	print("-- high speed (20 m/s entry, near this car's 21 m/s top) --")
	results["fast_steady"] = _measure("half lock, steady", 0.55, 0.5, 20.0)
	results["fast_power"] = _measure("half lock, power", 1.0, 0.5, 20.0)
	results["fast_lift"] = _measure("half lock, lift", 0.0, 0.5, 20.0)
	_measure("full lock, steady", 0.55, 1.0, 20.0)
	# ---- what the numbers have to keep saying ----
	var failures: PackedStringArray = []
	for name in results:
		if (results[name] as Dictionary).get("spun", false):
			failures.append("%s spun" % name)
	# The point of the speed-faded rear grip: at racing speed the car slides on all four
	# rather than washing wide with its tail planted.
	if float(results["fast_steady"]["sideslip"]) < 10.0:
		failures.append("no slide at speed (%.1f deg, want >10)" % results["fast_steady"]["sideslip"])
	# ...but it must stay composed when it is slow, or it is undriveable rather than fun.
	if float(results["mid_power"]["sideslip"]) > 10.0:
		failures.append("loose under power at mid speed (%.1f deg)" % results["mid_power"]["sideslip"])
	# Sliding, not swapping ends. Above about 1.3 the car rotates faster than anyone can
	# catch, and "all-wheel slide" has quietly become "spin".
	for name in results:
		var b: float = float((results[name] as Dictionary).get("balance", 1.0))
		if b > 1.3:
			failures.append("%s oversteers hard (balance %.2f)" % [name, b])
	for f in failures:
		print("[balance] FAIL %s" % f)
	print("[balance] RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)
