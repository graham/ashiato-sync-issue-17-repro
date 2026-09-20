extends Node
## What does predicting EVERY car actually do to the cars you do not drive?
##
##   Godot --path addon --headless res://tests/predict_all.tscn
##
## Prediction means "run the simulation forward from the last known state", and the
## simulation runs on INPUT. For your own car you have it. For somebody else's you never
## do -- sync carries input from a client to the server, and the server does not forward
## it to anyone else, deliberately: it would be pure bandwidth for something the server
## has already simulated on your behalf.
##
## So this measures the thing that matters rather than arguing about it: how evenly a
## remote car moves across frames. Smooth interpolation gives near-identical steps; a car
## being held still and then corrected gives spikes.

const DT: float = 1.0 / 60.0
const DELAY: int = 4
var _flight: Array = []
var _tick: int = 0
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[predictall] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _pump(s, c) -> void:
	for p in s.take_outbound(): _flight.append([_tick + DELAY, false, p["bytes"], p["bits"]])
	for p in c.take_outbound(): _flight.append([_tick + DELAY, true, p["bytes"], p["bits"]])
	var keep: Array = []
	for e in _flight:
		if e[0] <= _tick:
			if e[1]: s.deliver(1, e[2], e[3])
			else: c.deliver(0, e[2], e[3])
		else: keep.append(e)
	_flight = keep


## Returns [mean step, worst step, jerk] for a server-driven car as the CLIENT draws it.
func _remote_motion(predict_all: bool, erratic: bool) -> Array:
	_flight = []
	var s = ClassDB.instantiate("DrivingWorld")
	var c = ClassDB.instantiate("DrivingWorld")
	s.start(0)
	c.set_predict_all(predict_all)
	c.start(1)
	var bot: int = s.spawn_car(0, Vector3(0, 0.5, 0))
	for i in range(120):
		_tick += 1
		s.set_car_input(bot, 1.0, 0.15, false)
		s.tick(DT); c.tick(DT); _pump(s, c)

	var steps: Array[float] = []
	var error: float = 0.0
	var error_samples: int = 0
	var previous := Vector3.ZERO
	var have_previous: bool = false
	for i in range(300):
		_tick += 1
		# Erratic: the bot throws the wheel the other way every third of a second. This is
		# the case prediction cannot help with, because the client is never told about the
		# change -- it can only keep guessing the old one until a correction arrives.
		var steer: float = (1.0 if (i / 20) % 2 == 0 else -1.0) if erratic else 0.15
		s.set_car_input(bot, 1.0, steer, false)
		s.tick(DT); c.tick(DT); _pump(s, c)
		for sample in c.sampled_cars():
			if not sample["sampled"]:
				continue
			var p: Vector3 = sample["position"]
			if have_previous:
				steps.append((p - previous).length())
			previous = p
			have_previous = true
			# Smoothness is only half the question. A car can be drawn perfectly evenly
			# and still be in the wrong place -- interpolation is deliberately behind, and
			# prediction is a guess. This is how far the drawn car is from where the
			# server says it actually is, right now.
			error += (p - (s.car_state(bot)["position"] as Vector3)).length()
			error_samples += 1

	var mean: float = 0.0
	var worst: float = 0.0
	for step in steps:
		mean += step
		worst = maxf(worst, step)
	mean /= maxf(float(steps.size()), 1.0)
	# Jerk: how much each step differs from the one before. This is what "smooth" means
	# to an eye -- a car can move fast and look fine, but it cannot keep changing pace.
	var jerk: float = 0.0
	for i in range(1, steps.size()):
		jerk += absf(steps[i] - steps[i - 1])
	jerk /= maxf(float(steps.size() - 1), 1.0)
	s.teardown(); c.teardown()
	return [mean, worst, jerk, steps.size(), error / maxf(float(error_samples), 1.0)]


func _ready() -> void:
	print("[predictall] -- steady: a bot holding one steering angle --")
	var interpolated: Array = _remote_motion(false, false)
	var predicted: Array = _remote_motion(true, false)
	print("[predictall]   interpolated: jerk %.5f, %.2f m from the truth" % [
		interpolated[2], interpolated[4]])
	print("[predictall]   predicted:    jerk %.5f, %.2f m from the truth" % [
		predicted[2], predicted[4]])

	print("[predictall] -- erratic: a bot reversing lock three times a second --")
	var interp_erratic: Array = _remote_motion(false, true)
	var predict_erratic: Array = _remote_motion(true, true)
	print("[predictall]   interpolated: jerk %.5f, %.2f m from the truth" % [
		interp_erratic[2], interp_erratic[4]])
	print("[predictall]   predicted:    jerk %.5f, %.2f m from the truth" % [
		predict_erratic[2], predict_erratic[4]])

	_check("both_modes_draw_the_car", int(interpolated[3]) > 100 and int(predicted[3]) > 100,
		"%d vs %d samples" % [interpolated[3], predicted[3]])
	# Not an opinion about which is better -- a record of which one this game measured as
	# smoother, so the choice on the main menu is an informed one.
	for pair in [["steady", interpolated, predicted], ["erratic", interp_erratic, predict_erratic]]:
		var i_jerk: float = (pair[1] as Array)[2]
		var p_jerk: float = (pair[2] as Array)[2]
		print("[predictall] %s: %s is smoother (%.5f vs %.5f)" % [
			pair[0], "interpolation" if i_jerk <= p_jerk else "prediction",
			minf(i_jerk, p_jerk), maxf(i_jerk, p_jerk)])
	print("[predictall] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)
