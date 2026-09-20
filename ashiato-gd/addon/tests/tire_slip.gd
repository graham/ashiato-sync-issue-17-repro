extends Node
## Do the tires report sliding when they are actually sliding, and which ones?
##
##   Godot --path addon --headless res://tests/tire_slip.tscn
##
## The number is a fraction of what the tire has: at or below 1 it is gripping, above 1 it
## is being asked for more than the rubber can give. This is what the skid marks are drawn
## from, so the cases that matter are the ones a driver would expect to leave rubber.

const DT: float = 1.0 / 60.0
const FL: int = 0
const FR: int = 1
const RL: int = 2
const RR: int = 3
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[slip] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## Drives one car for a while and returns the worst slip each tire reached.
func _drive(throttle: float, steer: float, handbrake: bool, settle: int) -> PackedFloat32Array:
	var w = ClassDB.instantiate("DrivingWorld")
	w.start(0)
	var car: int = w.spawn_car(0, Vector3(0, 0.5, 0))
	for i in range(180):
		w.set_car_input(car, 1.0, 0.0, false)
		w.tick(DT)
	var worst := PackedFloat32Array([0, 0, 0, 0])
	for i in range(settle):
		w.set_car_input(car, throttle, steer, handbrake)
		w.tick(DT)
		var slip: PackedFloat32Array = w.tire_slip(car)
		for t in range(4):
			worst[t] = maxf(worst[t], slip[t])
	w.teardown()
	return worst


func _ready() -> void:
	var cruising: PackedFloat32Array = _drive(0.4, 0.0, false, 120)
	print("[slip] cruising straight  FL %.2f FR %.2f RL %.2f RR %.2f" % [
		cruising[FL], cruising[FR], cruising[RL], cruising[RR]])
	_check("straight_line_does_not_slide",
		cruising[FL] < 1.0 and cruising[RL] < 1.0,
		"nothing above 1 while driving normally")

	var cornering: PackedFloat32Array = _drive(0.55, 1.0, false, 120)
	print("[slip] full lock          FL %.2f FR %.2f RL %.2f RR %.2f" % [
		cornering[FL], cornering[FR], cornering[RL], cornering[RR]])
	# Full lock at speed asks the FRONT for a turn no tire can deliver -- that is the
	# understeer the handling probe measures, seen from the tire's side.
	_check("full_lock_slides_the_front",
		cornering[FL] > 1.0 or cornering[FR] > 1.0,
		"front reaches %.2f" % maxf(cornering[FL], cornering[FR]))

	var handbrake: PackedFloat32Array = _drive(0.0, 0.6, true, 90)
	print("[slip] handbrake turn     FL %.2f FR %.2f RL %.2f RR %.2f" % [
		handbrake[FL], handbrake[FR], handbrake[RL], handbrake[RR]])
	# The handbrake exists to break the REAR loose. If that does not show here, the marks
	# would appear under the wrong end of the car.
	_check("handbrake_slides_the_rear",
		maxf(handbrake[RL], handbrake[RR]) > 1.0,
		"rear reaches %.2f" % maxf(handbrake[RL], handbrake[RR]))
	_check("handbrake_slides_rear_harder_than_front",
		maxf(handbrake[RL], handbrake[RR]) > maxf(handbrake[FL], handbrake[FR]),
		"rear %.2f vs front %.2f" % [
			maxf(handbrake[RL], handbrake[RR]), maxf(handbrake[FL], handbrake[FR])])

	print("[slip] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % [_failures]))
	get_tree().quit(0 if _failures.is_empty() else 1)
