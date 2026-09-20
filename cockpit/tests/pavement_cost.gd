extends Node
## WHAT THE PAVEMENT'S NEAR DETAIL COSTS, IN MILLISECONDS, ON A CAMERA PATH THAT IS THE SAME EVERY TIME.
##
##   Godot --path cockpit --resolution 1600x900 --xr-mode off res://tests/pavement_cost.tscn -- --level=watch
##       --clouds=none --rounds=3
##
## "CHEAP" IS THE USER'S OWN WORD, SO IT IS A REQUIREMENT AND NOT A HOPE. A detail shader that looks better and costs
## four milliseconds has failed the request as written, so this exists to turn the claim into a number before anybody
## writes the word down. A probe, not a suite: headless has no rendering device and a frame time from the dummy
## renderer is a measurement of nothing.
##
## FIVE ARMS, and the first of them is the point of the exercise:
##
## - `was`    the bare StandardMaterial3D the runway wore before this lane. The baseline, in the same run as the rest.
## - `plain`  and `fine`, the two tiers, at the ranges `DetailReach` ships.
## - `plain2x` and `fine2x`, the same two with `DetailReach.pavement_numbers(2.0)` -- every band pushed to twice its
##   range. That is the answer to "what does pushing the threshold out cost", which is otherwise a guess, and it is
##   asked through the same function the game uses rather than by editing the constant.
##
## INTERLEAVED, NOT ONE AFTER ANOTHER. Each round runs all five arms in order and the rounds are pooled, because the
## simulation is running underneath and the traffic is not in the same place in arm five as it was in arm one. That
## confound cannot be removed without stopping the world, so it is spread across the arms instead of being allowed to
## land on the last one. Run more rounds if two arms are within noise of each other.
##
## AND THE WORST FRAME IS REPORTED AS WELL AS THE MIDDLE, because a mean that holds while the worst tick doubles is a
## stutter, and the moment this feature is for -- short final, low, with the whole touchdown zone in frame at its
## richest -- is the exact moment a stutter is least welcome.
##
## VSYNC OFF AND NO FPS CAP, or every arm reads exactly 16.67 ms and the probe measures the monitor.

## HOW FAR OUT THE PATH STARTS AND WHERE IT ENDS, in the runway's frame: metres along from the threshold (negative is
## out on the approach) and height. A 3-degree slope from 1.5 km out down to the roll, which is the descent this
## feature was sized for -- the far band gives up at 1400 m and the near one comes in at 160.
const FROM_ALONG: float = -1500.0
const FROM_UP: float = 80.0
const TO_ALONG: float = 600.0
const TO_UP: float = 2.0
## How many frames a pass over that path takes, and how many are thrown away first so a shader compilation and the
## sun settling are not counted as the cost of a surface.
const PASS_FRAMES: int = 150
const WARM_FRAMES: int = 45

var _out: String = "user://pavement_cost"
var _rounds: int = 8
## HOW MANY ROUNDS ARE THROWN AWAY BEFORE ANYTHING IS COUNTED, and this is the number that made this probe honest.
##
## Per-round figures showed every frame over 25 ms living in rounds ONE AND TWO, and rounds three and four with not a
## single one for any arm. The spikes were the engine warming -- pipelines specialising, the scenery yard building
## its cells along a path it had not flown yet -- and they landed on whichever arm happened to be running, which in
## round one was `plain` (50 frames over 25 ms, worst 85.6) and in round two was `fine2x` (27, worst 75.1). Reported
## as a per-arm p99 they said `plain` had a 45 ms tail and `fine` did not, which is not a thing a cheaper shader can
## do and was the clue. Forty-five warm FRAMES per arm was not enough because what warms is the whole level, not the
## material; whole ROUNDS are.
var _warm_rounds: int = 2
## WHICH CAMERA: `path` flies the approach, `fill` stands still on the roll with the pavement filling the frame.
##
## `path` IS THE REALISTIC ONE AND IT COULD NOT RESOLVE THE ANSWER. Flying the approach moves the scenery yard,
## the traffic and the mist as well as the pavement, and their variance is whole milliseconds while the effect being
## looked for is a fraction of one: four clean rounds put every arm within 0.9 ms of the baseline in no consistent
## order, with `fine2x` reading CHEAPER than `fine`, which cannot happen. A rig that returns an impossible ordering
## has not measured anything, whatever its medians say.
##
## `fill` is the answer to that, and it is also the conservative question. The camera stands on the roll with the
## touchdown zone filling most of the screen and does not move, so the scenery stops streaming and the pavement --
## at its richest, both bands full on -- is most of what the GPU is asked for. Whatever it costs there is more than
## it will ever cost in flight, so a `fill` number that is cheap settles the user's word for every other view.
var _mode: String = "fill"
var _level: FlightLevel = null
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[pavement_cost] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--rounds="):
			_rounds = maxi(1, int(argument.trim_prefix("--rounds=")))
		elif argument.begins_with("--warm-rounds="):
			_warm_rounds = maxi(0, int(argument.trim_prefix("--warm-rounds=")))
		elif argument.begins_with("--mode="):
			_mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	await _frames(90)
	var words := _level.get_node_or_null("Ui") as CanvasLayer
	if words != null:
		words.visible = false
	for board in _level.observer.find_children("*", "CanvasItem", true, false):
		(board as CanvasItem).visible = false
	var runway := _level.get_node_or_null("Runway") as MultiMeshInstance3D
	var frames: Array[Dictionary] = Terrain.runways()
	if runway == null or frames.is_empty():
		_check("there_is_a_runway_to_fly_at", false, "no Runway node or no runways")
		_finish()
		return
	await _measure(runway, frames[0])
	_finish()


## ---- the arms ----------------------------------------------------------------------------

## THE FIVE MATERIALS, built once. `was` is the three lines the commit removed; the rest are the game's own two
## shaders, dressed through `DetailReach` exactly as `Sky._pavement_paint` dresses them -- at the shipped reach and at
## twice it.
func _arms() -> Array[Dictionary]:
	var was := StandardMaterial3D.new()
	was.vertex_color_use_as_albedo = true
	was.roughness = 0.92
	return [
		{"name": "was", "material": was},
		{"name": "plain", "material": _paint(FlightLevel.PAVEMENT, 1.0)},
		{"name": "fine", "material": _paint(FlightLevel.PAVEMENT_FINE, 1.0)},
		{"name": "plain2x", "material": _paint(FlightLevel.PAVEMENT, 2.0)},
		{"name": "fine2x", "material": _paint(FlightLevel.PAVEMENT_FINE, 2.0)},
	]


func _paint(which: Shader, reach: float) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = which
	var wanted: Dictionary = DetailReach.pavement_numbers(reach)
	for uniform in which.get_shader_uniform_list():
		var named: String = String(uniform["name"])
		if wanted.has(named):
			paint.set_shader_parameter(named, wanted[named])
	return paint


func _measure(runway: MultiMeshInstance3D, frame: Dictionary) -> void:
	var camera: Camera3D = _level.observer
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 55.0
	camera.far = 30000.0
	var arms: Array[Dictionary] = _arms()
	# PER ROUND, NOT POOLED: the report below pairs each arm against the baseline WITHIN a round, which is the only
	# way to get a number off a machine five other lanes are also using.
	var gathered: Dictionary = {}
	for arm in arms:
		gathered[arm["name"]] = []
	for round_index in range(_rounds):
		# THE ORDER REVERSES EVERY OTHER ROUND, and that is not tidiness. The first run of this probe put `was` first
		# in every round and reported the new shaders as 0.8 to 1.3 ms FASTER than the bare material -- a strong
		# enough claim that the order it was measured in had to be ruled out before it could be believed. Any drift
		# across a round, thermal or from the traffic thickening, lands on whichever arm always goes first; running
		# A B C D E then E D C B A cancels the linear part of it.
		var order: Array[Dictionary] = arms.duplicate()
		if round_index % 2 == 1:
			order.reverse()
		for arm in order:
			runway.material_override = arm["material"]
			# WARM, UNTIMED: the first frames after a material change are the shader being compiled.
			for i in range(WARM_FRAMES):
				_stand(camera, frame, float(i) / float(WARM_FRAMES))
				await get_tree().process_frame
			var spent: Array = gathered[arm["name"]]
			var mine := PackedFloat32Array()
			var last: int = Time.get_ticks_usec()
			for i in range(PASS_FRAMES):
				_stand(camera, frame, float(i) / float(PASS_FRAMES - 1))
				await get_tree().process_frame
				var now: int = Time.get_ticks_usec()
				mine.append(float(now - last) / 1000.0)
				last = now
			if round_index >= _warm_rounds:
				spent.append(mine)
				gathered[arm["name"]] = spent
			# PER ROUND, so a tail that lives entirely in round one can be told from one that is really there. The
			# first run of this probe reported `plain` with a p99 of 45 ms and a worst of 64 against `fine`'s 21 and
			# 27, which is not a thing a cheaper shader can do, so the question was where those frames were.
			var sorted_mine: Array = Array(mine)
			sorted_mine.sort()
			var over: int = 0
			for ms in mine:
				if ms > 25.0:
					over += 1
			print("[pavement_cost]   round %d%s %-8s p50 %.3f worst %.3f, %d frames over 25 ms"
				% [round_index + 1, " (warm, thrown away)" if round_index < _warm_rounds else "", arm["name"], float(sorted_mine[int(sorted_mine.size() * 0.5)]),
					float(sorted_mine[sorted_mine.size() - 1]), over])
		print("[pavement_cost] round %d of %d done" % [round_index + 1, _rounds])
	_report(gathered, arms)


## WHERE THE CAMERA IS AT `t` ALONG THE PATH, 0 out on the approach and 1 on the roll. A straight line in the
## runway's own frame, so the path is the same path on any strip and in any world.
func _stand(camera: Camera3D, frame: Dictionary, t: float) -> void:
	var threshold: Vector3 = frame["threshold"]
	var along: Vector3 = frame["along"]
	if _mode == "fill":
		# STILL, LOW, AND LOOKING DOWN THE STRIP from just short of the touchdown zone: the pavement is most of the
		# frame and nothing else in the world is moving toward or away from the eye.
		camera.fov = 78.0
		camera.look_from(threshold + along * 170.0 + Vector3.UP * 1.2,
			threshold + along * 380.0 + Vector3.UP * 0.4)
		return
	var at_along: float = lerpf(FROM_ALONG, TO_ALONG, t)
	var from: Vector3 = threshold + along * at_along + Vector3.UP * lerpf(FROM_UP, TO_UP, t)
	camera.look_from(from, threshold + along * (at_along + 900.0))


## ---- the report --------------------------------------------------------------------------

func _report(gathered: Dictionary, arms: Array[Dictionary]) -> void:
	var counted: int = _rounds - _warm_rounds
	print("[pavement_cost] mode %s: %d frames an arm over %d counted rounds, vsync off; %d warm rounds thrown away"
		% [_mode, PASS_FRAMES * counted, counted, _warm_rounds])
	# THE BASELINE IS THE CANARY. `was` is the material the game already had; nothing in this lane can make it slower,
	# so a round in which IT stutters is a round in which the machine was busy with somebody else, and every arm's
	# number in that round is void. Five other lanes share this GPU and one of them held MEASUREMENT until two
	# minutes before this run; the first attempt at this report had the baseline itself at a p50 of 33 ms with 124
	# frames over 25 in one round, which is how the rule got written. Judging it by the arm that CANNOT have changed
	# is the one test of the machine that is not circular.
	var clean: Array[int] = []
	for round_index in range(counted):
		var base: PackedFloat32Array = (gathered["was"] as Array)[round_index]
		var spikes: int = 0
		for ms in base:
			if ms > 25.0:
				spikes += 1
		if spikes == 0:
			clean.append(round_index)
		else:
			print("[pavement_cost] round %d is void: the unchanged baseline had %d frames over 25 ms in it"
				% [round_index + _warm_rounds + 1, spikes])
	_check("the_machine_was_quiet_enough_to_measure_on", clean.size() >= 2,
		"%d of %d counted rounds were clean" % [clean.size(), counted])
	if clean.size() < 2:
		print("[pavement_cost] not reporting a cost off fewer than two clean rounds; run it again when the machine is quiet")
		return
	# EVERY ARM'S MIDDLE AND WORST, over the clean rounds only.
	var middles: Dictionary = {}
	for arm in arms:
		var named: String = arm["name"]
		var all := PackedFloat32Array()
		for round_index in clean:
			all.append_array((gathered[named] as Array)[round_index])
		var sorted: Array = Array(all)
		sorted.sort()
		var total: float = 0.0
		for ms in sorted:
			total += ms
		middles[named] = float(sorted[int(sorted.size() * 0.5)])
		print("[pavement_cost] %-8s mean %.3f ms, p50 %.3f, p99 %.3f, worst %.3f"
			% [named, total / float(sorted.size()), float(sorted[int(sorted.size() * 0.5)]),
				float(sorted[mini(int(sorted.size() * 0.99), sorted.size() - 1)]), float(sorted[sorted.size() - 1])])
	# THE COST: THE POOLED MEDIAN OVER EVERY CLEAN FRAME, with the per-round spread beside it as the uncertainty.
	#
	# WHY THE POOLED ONE IS THE HEADLINE AND THE PER-ROUND ONE IS NOT. Pairing each arm against the baseline within
	# its own round cancels anything that moved the whole machine between rounds, which is the right instinct -- but
	# a round is 150 frames and its median carries a couple of milliseconds of its own noise, so the per-round
	# deltas come out spread from -2.5 to +2.7 and say nothing. Nine hundred frames pooled is the stable statistic.
	#
	# WHAT SAYS THE POOLED NUMBER IS REAL RATHER THAN A PREFERRED READING: the five arms come out in the order
	# physics requires -- was < plain < plain2x < fine < fine2x -- with no thumb on the scale. Every earlier version
	# of this probe produced an ordering with `fine2x` cheaper than `fine` somewhere in it, which is impossible, and
	# that is what said the rig was not measuring yet. An ordering that cannot happen is the most useful thing a
	# noisy rig produces, because it is the one result you cannot talk yourself into believing.
	var was: float = float(middles["was"])
	for named in ["plain", "fine", "plain2x", "fine2x"]:
		var deltas: Array[float] = []
		for round_index in clean:
			deltas.append(_middle_of((gathered[named] as Array)[round_index])
				- _middle_of((gathered["was"] as Array)[round_index]))
		deltas.sort()
		var pooled: float = float(middles[named]) - was
		middles["delta_" + named] = pooled
		print("[pavement_cost] %-8s costs %+.3f ms a frame against the bare material (%+.1f %%; per-round spread %+.3f to %+.3f over %d clean rounds)"
			% [named, pooled, pooled / maxf(was, 0.001) * 100.0, deltas[0], deltas[deltas.size() - 1], deltas.size()])
	# IS THE ORDERING THE ONE PHYSICS ALLOWS? Each of these costs strictly more work per pixel than the one before
	# it, so if the numbers disagree the rig has not resolved them and nothing below should be believed.
	var ordered: bool = float(middles["plain"]) <= float(middles["fine"]) 		and float(middles["plain"]) <= float(middles["plain2x"]) 		and float(middles["fine"]) <= float(middles["fine2x"])
	_check("the_rig_resolved_the_arms_from_each_other", ordered,
		"plain %.3f, plain2x %.3f, fine %.3f, fine2x %.3f"
			% [float(middles["plain"]), float(middles["plain2x"]), float(middles["fine"]), float(middles["fine2x"])])
	if not ordered:
		# WHAT CAN STILL BE SAID WHEN THE ARMS CANNOT BE TOLD APART, which is not nothing: every arm is within this
		# much of the unchanged baseline, so whatever the near detail costs, it costs less than that. A bound is a
		# real answer to "is it cheap" even when a point estimate is not available.
		var bound: float = 0.0
		for named in ["plain", "fine", "plain2x", "fine2x"]:
			bound = maxf(bound, absf(float(middles["delta_" + named])))
		print("[pavement_cost] the arms are within the noise of this machine, so no arm gets a point cost. What "
			+ "holds: every arm is within %.3f ms of the unchanged baseline in mode %s, so the near detail costs "
				% [bound, _mode] + "less than that. Five lanes share this GPU; run it again on a quiet one.")
	# THE CLAIM THE USER ASKED FOR, AS A CHECK THAT CAN FAIL, and the line depends on which question was asked.
	#
	# `fill` is the pathological view -- the pavement is most of a 1600x900 frame and both bands are full on -- so it
	# is an upper bound and nothing in flight will cost more. A millisecond there is the line. `path` is the
	# realistic descent, where the runway is a fraction of the frame; half a millisecond is the line there, and it
	# is tighter precisely because the honest answer ought to be near zero.
	var line: float = 1.0 if _mode == "fill" else 0.5
	_check("the_near_detail_is_cheap_on_the_shipped_reach", float(middles["delta_fine"]) < line,
		"fine costs %+.3f ms in mode %s, against a line of %.1f" % [float(middles["delta_fine"]), _mode, line])


## The median of one pass's frame times.
func _middle_of(spent: PackedFloat32Array) -> float:
	var sorted: Array = Array(spent)
	sorted.sort()
	return float(sorted[int(sorted.size() * 0.5)])


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
