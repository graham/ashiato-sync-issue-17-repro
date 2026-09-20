extends Node
## Does anything ever tip, climb or roll? The sim is 3D; the game is not.
##
##   Godot --path addon --headless res://tests/roll_probe.tscn
##
## Roll and pitch are suppressed BY CONSTRUCTION, not by luck: push_to_physics rebuilds
## the body's orientation from yaw alone every tick and forces angular velocity to
## (0, yaw_rate, 0), and read_from_physics takes only angular.y back. Box3D may well
## generate roll inside a step; nothing carries it to the next one. Tire forces are also
## applied at the centre-of-mass height rather than at the contact patch, so there is no
## roll torque to suppress in the first place.
##
## Height is NOT suppressed -- gravity is on and vy round-trips -- so this measures what
## is left: can a car be shoved off the deck, climb another one, or flip. A hard wall
## slam lifts it a few centimetres and that is all.
const DT: float = 1.0 / 60.0

func _ready() -> void:
	# 1. Hard angled slam into a wall.
	var w = ClassDB.instantiate("DrivingWorld")
	w.start(0)
	w.add_track_box(Vector3(0, 1, 40), Vector3(60, 2, 2))
	var car: int = w.spawn_car(0, Vector3(0, 0.5, 0), 0.5)   # 29 deg off square
	var worst_y: float = 0.0
	var top_speed: float = 0.0
	for i in range(600):
		w.set_car_input(car, 1.0, 0.0, false)
		w.tick(DT)
		var st: Dictionary = w.car_state(car)
		var p: Vector3 = st["position"]
		# Cars are spawned at 0.5 and settle to 0.4 resting height, so the first few ticks
		# are the drop, not a collision.
		if i > 30:
			worst_y = maxf(worst_y, absf(p.y - 0.4))
		top_speed = maxf(top_speed, (st["velocity"] as Vector3).length())
	print("[roll] wall slam at %.1f m/s: worst height error %.4f m" % [top_speed, worst_y])
	w.teardown()

	# 2. One car driven into the side of another -- the classic way to climb something.
	w = ClassDB.instantiate("DrivingWorld")
	w.start(0)
	var a: int = w.spawn_car(0, Vector3(0, 0.5, -14))
	var b: int = w.spawn_car(0, Vector3(0, 0.5, 0), PI * 0.5)   # parked across our path
	var worst_a: float = 0.0
	var worst_b: float = 0.0
	for i in range(600):
		w.set_car_input(a, 1.0, 0.0, false)
		w.set_car_input(b, 0.0, 0.0, false)
		w.tick(DT)
		if i > 30:
			worst_a = maxf(worst_a, absf((w.car_state(a)["position"] as Vector3).y - 0.4))
			worst_b = maxf(worst_b, absf((w.car_state(b)["position"] as Vector3).y - 0.4))
	print("[roll] t-bone: rammer %.4f m, rammed %.4f m off the deck" % [worst_a, worst_b])
	w.teardown()

	var ok: bool = worst_y < 0.05 and worst_a < 0.05 and worst_b < 0.05
	print("[roll] RESULT=%s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
