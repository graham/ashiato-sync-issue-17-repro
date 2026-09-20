extends Node
## Do two cars collide with each other, and is the result fair to both?
##
##   Godot --path addon --headless res://tests/car_collision.tscn
##
## Cars bumping is the whole point of racing together, and it is the case most at risk
## from how the simulation job is structured. The Box3D world was once stepped INSIDE the
## per-car loop, so whichever car the job reached first was simulated against neighbours
## still sitting at last tick's positions.
##
## A symmetric head-on is what exposes that, and it is the whole reason this file exists:
## two identical cars driving into each other from equal distances must meet in the
## middle. They used to meet 3 m off centre.
##
## Read RESULT=, not the exit code.

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[collision] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _head_on(car_count: int) -> Dictionary:
	var w = ClassDB.instantiate("DrivingWorld")
	w.start(0)
	# Head-on, 20 m apart, both driving FORWARDS into each other. b is spawned facing the
	# other way rather than given negative throttle: reverse is deliberately weaker than
	# forward, so opposite throttles would not be a symmetric test and this file would be
	# measuring the gearbox instead of the stepping order.
	var a: int = w.spawn_car(0, Vector3(0, 0.5, -10), 0.0)
	var b: int = w.spawn_car(0, Vector3(0, 0.5, 10), PI)
	# Extra cars parked well clear, purely to prove the result does not depend on how
	# many entities the job happens to walk before reaching these two.
	var spare: Array[int] = []
	for i in range(car_count - 2):
		spare.append(w.spawn_car(0, Vector3(60.0 + float(i) * 8.0, 0.5, 0)))

	for i in range(240):
		w.set_car_input(a, 1.0, 0.0, false)
		w.set_car_input(b, 1.0, 0.0, false)
		for car in spare:
			w.set_car_input(car, 0.0, 0.0, false)
		w.tick(1.0 / 60.0)

	var pa: Vector3 = w.car_state(a).get("position", Vector3())
	var pb: Vector3 = w.car_state(b).get("position", Vector3())
	return {"gap": pb.z - pa.z, "midpoint": (pa.z + pb.z) * 0.5}


func _ready() -> void:
	if not ClassDB.class_exists("DrivingWorld"):
		print("[collision] extension missing; build with -WithDriving")
		_finish()
		return

	var two: Dictionary = _head_on(2)
	# Cars are 4 m long, so two touching nose to nose sit ~4 m apart centre to centre.
	_check("cars_collide", two["gap"] > 3.0,
		"%.2f m apart, not driven through each other" % two["gap"])

	# THE regression this file exists for. The Box3D world used to be stepped once PER
	# CAR inside the simulation job, so whichever car the job reached first was simulated
	# against neighbours still at last tick's positions. This symmetric head-on drifted
	# 3.00 m off centre because of it. One step per tick, after every car has had its
	# forces applied, makes it fair.
	_check("collision_is_fair", absf(two["midpoint"]) < 0.1,
		"midpoint %.3f m, budget 0.1 (was 3.00 when the world stepped per car)" % two["midpoint"])

	# And it must stay fair as cars are added, since the per-car stepping got worse the
	# more entities there were.
	var five: Dictionary = _head_on(5)
	_check("fair_with_more_cars", absf(five["midpoint"]) < 0.1,
		"midpoint %.3f m with 5 cars in the world" % five["midpoint"])
	_check("same_result_with_more_cars", absf(five["gap"] - two["gap"]) < 0.1,
		"gap %.2f vs %.2f -- bystanders do not change the outcome" % [five["gap"], two["gap"]])

	_finish()


func _finish() -> void:
	print("[collision] RESULT=%s" % (
		"PASS" if _failures.is_empty() else "FAIL %s" % [_failures]))
	get_tree().quit(0 if _failures.is_empty() else 1)
