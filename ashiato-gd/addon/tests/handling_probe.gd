extends Node
## What does the car actually do, and does it still fit the racer's track?
##
##   Godot --path addon --headless res://tests/handling_probe.tscn
##   Godot --path addon --headless res://tests/handling_probe.tscn -- --lane=10
##
## Prints steady-state cornering radii so handling is tuned against numbers rather than
## adjectives. "Too twitchy" is a judgement, but "a 49 m turning circle on a track whose lane
## is 38 m wide" is a fact, and since 2026-09-12 the facts are CHECKED, not just printed:
##
##   * FULL LOCK FITS THE LANE. Every full-lock settled radius must be no larger than half
##     the racer's lane, because a corner you can only just fit through at full lock is one
##     you cannot place the car in. The lane is read from `const LANE` in
##     racer/world/track.gd, the one place it is written, so resizing the track moves this
##     limit with it. Until then the probe printed "the lane is 74 m wide" beside its numbers
##     and exited 0 whatever they were, so a car that stopped fitting would have printed a
##     bigger number and passed.
##   * THE CAR REACHES 50 KM/H AT ALL, at the default engine power.
##
## `-- --lane=<metres>` replaces the lane read from the track. It exists to show the check
## failing: a lane narrower than twice the measured radius must print RESULT=FAIL.
##
## A CROSS-PROJECT DEPENDENCY, and the only one in addon/tests. This project cannot load a
## racer script, so the probe reads racer/world/track.gd as TEXT, through the path
## TRACK_SCRIPT below (relative to this project, which only holds inside this repository), and
## takes the number from the line `const LANE: float = <number>`. It is deliberately fragile
## in one direction only. If racer renames LANE, types it differently, makes it an
## expression, or moves track.gd, the check `lane_width_is_known` FAILS and says which of
## "no file" or "no const LANE" it was. It never falls back to a number typed here, because
## a fallback is exactly how the limit would quietly stop following the track. Fix it by
## pointing TRACK_SCRIPT or the pattern at wherever the lane is now written.
##
## Each radius is MEASURED: the car is brought to the target speed, held there on part
## throttle, given full lock, and left to settle before the yaw rate is read. An earlier
## version measured one radius and divided it by other speeds, which quietly assumed yaw
## rate is independent of speed -- it is not, and the numbers it printed were fiction.
##
## Tune with DrivingWorld.set_handling({...}), or the constants at the top of
## racer/world/race.gd, neither of which needs a rebuild.
##
## Read RESULT=, not the exit code.

const DT: float = 1.0 / 60.0
## Where the racer's track is, from this project's root. Both live in this repository.
const TRACK_SCRIPT: String = "../../racer/world/track.gd"

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[handling] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## The lane width in metres and where it came from: the --lane override if one was given,
## otherwise the `const LANE` line of the racer's track. -1 when neither is there, which
## fails the run instead of falling back to a number typed here.
func _lane() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lane="):
			return [float(arg.substr(7)), "--lane override"]
	var path: String = ProjectSettings.globalize_path("res://").path_join(TRACK_SCRIPT).simplify_path()
	if not FileAccess.file_exists(path):
		return [-1.0, "no file at %s" % path]
	var text: String = FileAccess.get_file_as_string(path)
	var found: RegExMatch = RegEx.create_from_string(
		"(?m)^const LANE\\s*:\\s*float\\s*=\\s*([0-9]+(?:\\.[0-9]+)?)").search(text)
	if found == null:
		return [-1.0, "no `const LANE: float = ...` in %s" % path]
	return [float(found.get_string(1)), "racer/world/track.gd LANE"]


## Horizontal speed. The test world's ground runs to +-400 m, and a powerful car reaches
## the edge inside the measuring run; once it is falling, velocity.length() reports the
## drop and a 32 m/s car looks like a 68 m/s one.
func _flat_speed(w, car: int) -> float:
	var v: Vector3 = w.car_state(car)["velocity"]
	return Vector2(v.x, v.z).length()


## True once the car is near the edge of the world and the numbers stop meaning anything.
func _off_the_map(w, car: int) -> bool:
	var p: Vector3 = w.car_state(car)["position"]
	return absf(p.x) > 350.0 or absf(p.z) > 350.0


func _corner(target_speed: float, lock: float) -> Array:
	var w = ClassDB.instantiate("DrivingWorld")
	w.start(0)
	var car: int = w.spawn_car(0, Vector3(0, 0.5, 0))
	for i in range(900):
		var speed: float = _flat_speed(w, car)
		# Part throttle to hold the target, so the corner is measured at the speed asked
		# for rather than at whatever the car happens to be doing.
		var throttle: float = 1.0 if speed < target_speed else -0.15
		var steer: float = 0.0 if i < 240 else lock
		w.set_car_input(car, throttle, steer, false)
		w.tick(DT)
	var v: float = _flat_speed(w, car)
	var rate: float = absf(w.car_state(car)["yaw_rate"])
	w.teardown()
	return [v, rate, v / rate if rate > 0.001 else INF]


func _ready() -> void:
	var lane: Array = _lane()
	var lane_width: float = lane[0]
	var limit: float = lane_width / 2.0
	_check("lane_width_is_known", lane_width > 0.0, "%.1f m, from %s" % [lane_width, lane[1]])

	var w = ClassDB.instantiate("DrivingWorld")
	w.start(0)
	var car: int = w.spawn_car(0, Vector3(0, 0.5, 0))
	for i in range(900):
		w.set_car_input(car, 1.0, 0.0, false)
		w.tick(DT)
		if _off_the_map(w, car):
			break
	var top: float = _flat_speed(w, car)
	print("top speed: %.1f m/s (%.0f km/h)" % [top, top * 3.6])

	# Time to 50 km/h, the number that decides whether the car feels alive off the line.
	w.teardown()
	w = ClassDB.instantiate("DrivingWorld")
	w.start(0)
	var default_hp: float = float(w.handling()["engine_hp"])
	car = w.spawn_car(0, Vector3(0, 0.5, 0))
	var reached: float = -1.0
	for i in range(900):
		w.set_car_input(car, 1.0, 0.0, false)
		w.tick(DT)
		if reached < 0.0 and _flat_speed(w, car) >= 13.9:
			reached = (i + 1) * DT
	print("0-50 km/h: %.1f s" % reached)
	w.teardown()
	_check("reaches_50_kmh_at_default_power", reached > 0.0,
		("%.1f s" % reached if reached > 0.0 else "never, in %.0f s" % (900 * DT))
		+ " at the default %.0f hp" % default_hp)

	# Entry speed is asked for, not achieved: a cornering tire scrubs speed, so the car
	# settles wherever grip and drag agree. That the fast entries all converge on the same
	# number IS the result -- it is what "grip limited" means.
	# What the + and - keys in the racer actually buy you.
	print("engine power range:")
	for hp in [40.0, 117.0, 250.0, 400.0]:
		var e = ClassDB.instantiate("DrivingWorld")
		e.start(0)
		e.set_handling({"engine_hp": hp})
		var c: int = e.spawn_car(0, Vector3(0, 0.5, 0))
		var fifty: float = -1.0
		for i in range(1200):
			e.set_car_input(c, 1.0, 0.0, false)
			e.tick(DT)
			if fifty < 0.0 and _flat_speed(e, c) >= 13.9:
				fifty = (i + 1) * DT
			if _off_the_map(e, c):
				break
		var v: float = _flat_speed(e, c)
		print("  %3.0f hp: top %5.1f m/s (%3.0f km/h), 0-50 km/h %s" % [
			hp, v, v * 3.6, "%.1f s" % fifty if fifty > 0.0 else "never"])
		e.teardown()

	print("cornering (lock, entry -> settled):")
	var full_lock: PackedStringArray = []
	var widest: float = 0.0
	for lock in [1.0, 0.6, 0.3]:
		for target in [10.0, 18.0]:
			var r: Array = _corner(target, lock)
			print("  lock %.1f  entry %4.1f -> %5.1f m/s (%3.0f km/h): %5.2f rad/s, radius %5.1f m, %.2f g" % [
				lock, target, r[0], r[0] * 3.6, r[1], r[2],
				(r[0] * r[1]) / 9.81 if r[2] < INF else 0.0])
			if lock == 1.0:
				full_lock.append("%.1f m at %.1f m/s" % [r[2], r[0]])
				widest = maxf(widest, r[2])
	# The track was resized around these numbers rather than the other way round: its lane
	# is about twice the radius the car needs at its top speed. Twice, because a corner you
	# can only just fit through at full lock is one you cannot place the car in.
	print("(the track's lane is %.0f m wide, so corners up to ~%.0f m radius are driveable)" % [
		lane_width, limit])
	_check("full_lock_fits_the_lane", lane_width > 0.0 and widest <= limit,
		"widest full-lock radius %.1f m against a limit of %.1f m, half the %.1f m lane; %s" % [
			widest, limit, lane_width, ", ".join(full_lock)])

	print("[handling] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % [_failures]))
	get_tree().quit(0 if _failures.is_empty() else 1)
