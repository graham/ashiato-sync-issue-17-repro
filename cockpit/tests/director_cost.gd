extends Node
## WHAT A SECOND VIEW OF THE WORLD COSTS, measured before any of item 20 was built.
##
##   Godot --path cockpit --fixed-fps 60 --xr-mode off res://tests/director_cost.tscn -- --level=watch
##   Godot --path cockpit --fixed-fps 60 --xr-mode off res://tests/director_cost.tscn -- --level=watch \
##       --frames=240 --rounds=3 --out=C:/somewhere
##
## NOT HEADLESS -- it renders. Headless has no rendering device, so every picture would be a black
## rectangle and every GPU time a zero, and both look like results. `tests/scenery_shot.gd` says the
## same and this borrows its clocks.
##
## WHY IT EXISTS, AND WHY IT IS THE FIRST THING THE LANE DID. plan.md item 20 asks for the desktop
## window to show a DIFFERENT view from the headset's while recording. Today the window is a MIRROR:
## one camera, drawn once, shown twice. A different view is a second camera and a SECOND FULL PASS
## over the world, and this is the one feature on the plan that deliberately costs frames in a game
## whose first priority is headset framerate. So the cost was measured before the furniture was
## designed, because the number decides the SHAPE of the feature -- a pass that costs a fifth of a
## millisecond is a switch on a panel, and a pass that costs six is a different feature.
##
## WHAT IT ESTABLISHED, 2026-09-15, RTX 5080, D3D12, Mobile renderer, double build, the `watch` level
## with 79 vehicles held still, root viewport 1600x900 at 1.4x (the headset's own render scale), the
## second view at 1.0x with MSAA off, three rounds of 240 frames each, baseline floor 2.05 ms:
##
##                added to a frame     its own GPU timer   its own CPU timer
##   sub_1920         +0.617 ms            0.740 ms            0.489 ms
##   sub_1600         +0.671 ms            0.601 ms            0.498 ms
##   sub_1280         +0.607 ms            0.487 ms            0.478 ms
##   sub_960          +0.596 ms            0.411 ms            0.473 ms
##   window_1600      +0.702 ms            0.604 ms            0.490 ms
##
## THREE ANSWERS, AND THE THIRD WAS NOT THE ONE EXPECTED.
##
## **Yes, a second `Viewport` with its own `Camera3D` sharing the root's `World3D` draws the live
## world.** Not a still, not a copy: the same aircraft, sea and weather, from somewhere else.
##
## **It costs about two thirds of a millisecond**, which is well under the millisecond the feature was
## given to stay inside. So it ships -- with a switch, off by default, which is what the user asked for
## anyway.
##
## **And SHRINKING THE RECORDING SAVES ALMOST NOTHING.** 960x540 costs 0.596 ms and 1920x1080 costs
## 0.617: a fiftieth of a millisecond for a ninth of the pixels. The per-viewport GPU timer falls from
## 0.740 to 0.411 as expected, and the frame does not get faster, because what the frame is waiting on
## is the CPU half -- a second cull and a second render list over seventy-nine vehicles and a whole
## island -- and that is 0.47-0.50 ms at EVERY size. So the director's camera records at the window's
## own size and the render scale is not a knob worth turning. The thing that saves the 0.65 ms is
## turning it off, which is the switch and the red light.
##
## A SEPARATE `Window` COSTS THE SAME AS A `SubViewport` OF THE SAME SIZE -- 0.702 against 0.671, inside
## the spread of either. That was the question behind the question: a `Window` is its own viewport,
## blitted to its own OS window, and the root's `use_xr` never touches it, so it is the one arrangement
## whose behaviour in a headset can be reasoned about rather than hoped for. Nothing is being paid for
## that safety.
##
## WHAT IT MEASURES, in strict interleave: `off`, one second view, `off`, the next, `off` ... and the
## whole ladder `--rounds` times. A measured pass is counted only when the two `off` rounds either
## side of it AGREE -- see `_settle_up`. That is the rule in running_a_team_here.md, and it is here
## because the first version of this probe ran the ladder once, in order, and reported that a 1280
## view cost MORE than a 1920 one. It did not; the world was getting busier underneath it.
##
## THE SECOND VIEWPORT SHARES THE WORLD (`own_world_3d = false`), which is the whole point: the
## director's camera must see the same aircraft, the same sea and the same weather as the pilot's, not
## a copy. It is also what makes the second pass a real pass -- a viewport with an empty world would
## draw nothing, cost nothing, and look like very good news.
##
## HOW IT TIMES. `RenderingServer.viewport_set_measure_render_time` on the root AND on the second
## viewport, plus the wall clock between two `frame_post_draw`s. The per-viewport GPU timers attribute
## each pass to its own RID, so the ROOT's number barely moves when a second viewport appears -- only
## the wall clock sees the whole frame. Read the wall clock as the answer and the viewport timers as
## the breakdown. Vsync off, or a frame capped at the display's rate measures the display.
##
## WHAT IT CANNOT SAY, and does not claim: whether Godot draws a second viewport while the ROOT
## viewport is in XR mode. That needs an OpenXR session and this machine has no headset (plan.md item
## 0). What it does establish is the cost of the second pass itself, which does not depend on what the
## first pass is doing, and that a `Window` draws the shared world at all.
##
## A PROVEN NEGATIVE THAT WAS NEARLY MISSED: the first version compared the two pictures by their MEAN
## COLOUR, and two views of the same island at the same hour average to almost the same grey-green. A
## `Window` view that was genuinely different failed at 0.0022 apart while a view that was the root's
## own would have passed at 0.01. `_pixels_apart` asks whether the same pixel shows the same thing,
## which no summary of a picture can answer.
##
## A probe, not a suite: a frame time has no right answer on somebody else's GPU. The verdicts it does
## give are that each second view DREW a world of its own, and that at least one round of each survived
## its own baselines -- a run where every round is thrown away has measured nothing and says so.
##
## Read RESULT=, not the exit code.

## The world runs this long before anything is measured: the fleet seeded, the fires lit.
const WARM: int = 240
## Frames given to a freshly built viewport to compile its pipelines before its frames count. A first
## frame that builds a shader is a hitch, not a cost.
const SETTLE: int = 60
## Frames given back to the baseline after a viewport is torn down.
const COOL: int = 30

## Each second view measured: its name, its size, and how it is made. `off` is not in the list; it is
## run before and after every one of these.
const LADDER: Array[Dictionary] = [
	{"name": "sub_1920", "size": Vector2i(1920, 1080), "how": "sub"},
	{"name": "sub_1600", "size": Vector2i(1600, 900), "how": "sub"},
	{"name": "sub_1280", "size": Vector2i(1280, 720), "how": "sub"},
	{"name": "sub_960", "size": Vector2i(960, 540), "how": "sub"},
	{"name": "window_1600", "size": Vector2i(1600, 900), "how": "window"},
]

## How far apart the two `off` rounds either side of a measured one may be before that round is thrown
## away. running_a_team_here.md's number, from the lane that learnt it on the mist sweeps.
const ROUNDS_AGREE_WITHIN: float = 0.05

## WHICH FRAME OF A ROUND IS THE MEASUREMENT: the tenth-percentile frame, not the median one.
##
## running_a_team_here.md: "time the work five times and keep the fastest. A regression still raises
## the minimum." The same holds inside one round. The MEDIAN frame of a 2.5 ms baseline wandered by
## 0.1 ms between rounds here -- four per cent, and twice the tolerance -- because a median carries
## every hitch the machine had. The floor is what the frame costs when nothing interrupts it, and it
## moved by a hundredth between rounds while the median moved by a tenth. It cannot flatter a
## regression: a pass that always costs 0.6 ms more raises the floor by 0.6 ms too. The median and the
## p95 are still printed beside it, because a change that shows only in the p95 is a stutter and worth
## seeing.
const WALL_FLOOR: float = 0.1

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _frames: int = 240
var _rounds: int = 3
var _out: String = "user://director_cost"
## Every counted delta, by pass name: the frame time with the second view minus the mean of the two
## baselines either side of it.
var _deltas: Dictionary = {}
## Every counted second-viewport GPU reading, by pass name.
var _own_gpu: Dictionary = {}
## Every counted second-viewport CPU reading, by pass name.
var _own_cpu: Dictionary = {}
## Rounds thrown away because their baselines disagreed, as `name: [detail, ...]`.
var _voided: Dictionary = {}

var _sub: SubViewport = null
var _window: Window = null
var _second_camera: Camera3D = null


func _check(what: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS %s" % what)
	else:
		print("FAIL %s%s" % [what, "" if detail == "" else " (%s)" % detail])
		_failures.append(what)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"frames":
				_frames = maxi(int(parts[1]), 1)
			"rounds":
				_rounds = maxi(int(parts[1]), 1)
			"out":
				_out = parts[1]

	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return

	var world: Dictionary = ChartDrawer.asked_in(OS.get_cmdline_user_args(), "none")
	if String(world["error"]) != "":
		_check("the_level_asked_for_is_a_level", false, String(world["error"]))
		_finish()
		return
	if String(world["id"]) != "":
		var why: String = Net.choose_level(String(world["id"]))
		if why != "":
			_check("the_level_asked_for_is_chosen", false, why)
			_finish()
			return

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# AT THE HEADSET'S RENDER SCALE, for the same reason `scenery_shot` does it: a headset draws each
	# eye at 1.4x, which is twice the pixels, and a baseline taken at 1.0 would flatter the first pass
	# and make the second look dearer by comparison than it is.
	get_viewport().scaling_3d_scale = PilotRig.RENDER_SCALE
	print("[director] %s, %s precision, %s on %s, window %s, root 3D scale %.2f, msaa_3d %d, ONE view (a headset draws two)" % [
		Engine.get_version_info()["string"], "double" if OS.has_feature("double") else "single",
		RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(), DisplayServer.window_get_size(),
		get_viewport().scaling_3d_scale, get_viewport().msaa_3d])

	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	if _level.observer == null:
		_check("there_is_nobody_watching", false, "pass --level=watch after the bare --")
		_finish()
		return
	for i in range(WARM):
		await get_tree().process_frame
	# THE WORLD IS STOPPED BEFORE ANYTHING IS TIMED, and this was not the first plan. The first run of
	# this probe let the world run, and every single round was thrown away: the baseline climbed from
	# 4.74 to 6.07 ms through one ladder as the fires spread and the fleet flew, and a rising baseline
	# reported that a 1280-wide second view cost MORE than a 1920-wide one. The drift was the WORLD,
	# not the machine. `_pause_the_simulation` is `scenery_shot`'s, and it leaves all seventy-nine
	# vehicles drawn where they stand -- the load stays, only the change goes.
	_pause_the_simulation()
	for i in range(COOL):
		await get_tree().process_frame

	DirAccess.make_dir_recursive_absolute(_out)
	var root: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(root, true)

	# STRICTLY INTERLEAVED: a baseline, a second view, a baseline, the next second view, a baseline.
	# Each measured round is bracketed by its own two baselines and judged against them alone.
	var before: float = await _time_a_baseline(root, "warm")
	for round_number in range(_rounds):
		for rung in LADDER:
			var reading: Dictionary = await _time_a_second_view(root, rung, round_number == 0)
			var after: float = await _time_a_baseline(root, String(rung["name"]))
			_settle_up(String(rung["name"]), before, after, reading)
			before = after

	_report()
	_finish()


## THE WORLD DRAWN ONCE, AS THE GAME DOES TODAY. Returns the median frame time.
func _time_a_baseline(root: RID, after_what: String) -> float:
	for i in range(COOL):
		await get_tree().process_frame
	var reading: Dictionary = await _time(root, RID())
	print("[director] baseline after=%s wall_floor_ms=%.3f wall_median_ms=%.3f root_gpu_ms=%.3f root_cpu_ms=%.3f" % [
		after_what, float(reading["wall"]), float(reading["wall_median"]),
		float(reading["root_gpu"]), float(reading["root_cpu"])])
	return float(reading["wall"])


## THE WORLD DRAWN TWICE. Builds the second view, lets it compile, times it, takes it down again.
func _time_a_second_view(root: RID, rung: Dictionary, save_a_picture: bool) -> Dictionary:
	var how: String = String(rung["how"])
	var size: Vector2i = rung["size"]
	var second: RID = _build_a_subviewport(size) if how == "sub" else _build_a_window(size)
	RenderingServer.viewport_set_measure_render_time(second, true)
	for i in range(SETTLE):
		await get_tree().process_frame
	if save_a_picture:
		_prove_it_drew(String(rung["name"]))
	var reading: Dictionary = await _time(root, second)
	print("[director] pass=%s how=%s size=%s wall_floor_ms=%.3f wall_median_ms=%.3f wall_p95_ms=%.3f root_gpu_ms=%.3f root_cpu_ms=%.3f second_gpu_ms=%.3f second_cpu_ms=%.3f" % [
		String(rung["name"]), how, size, float(reading["wall"]), float(reading["wall_median"]),
		float(reading["wall_p95"]),
		float(reading["root_gpu"]), float(reading["root_cpu"]),
		float(reading["second_gpu"]), float(reading["second_cpu"])])
	_tear_down()
	await get_tree().process_frame
	return reading


## `_frames` frames of wall clock and of both viewports' own GPU and CPU timers, as medians.
##
## THE CPU TIMER IS HERE BECAUSE THE FIRST RUN'S NUMBERS DID NOT ADD UP. A 1920-wide second view read
## 0.70 ms of GPU and a 960-wide one 0.43, a difference of a quarter of a millisecond -- and their WALL
## clocks were within a tenth of each other. Most of what a second viewport costs is not pixels: it is
## a second cull and a second render list over seventy-nine vehicles and the whole island, on the CPU,
## and that costs the same whatever size the picture is. Shrinking the recording is therefore a much
## smaller saving than it looks, which is a thing the feature needed to know before it chose a default.
func _time(root: RID, second: RID) -> Dictionary:
	await RenderingServer.frame_post_draw
	var deltas: PackedFloat64Array = []
	var root_gpu: PackedFloat64Array = []
	var root_cpu: PackedFloat64Array = []
	var second_gpu: PackedFloat64Array = []
	var second_cpu: PackedFloat64Array = []
	var last: int = Time.get_ticks_usec()
	for i in range(_frames):
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		deltas.append(float(now - last) / 1000.0)
		last = now
		root_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root))
		root_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root))
		if second.is_valid():
			second_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(second))
			second_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(second))
	return {"wall": _percentile(deltas, WALL_FLOOR), "wall_median": _median(deltas),
		"wall_p95": _percentile(deltas, 0.95),
		"root_gpu": _median(root_gpu), "root_cpu": _median(root_cpu),
		"second_gpu": _median(second_gpu) if second.is_valid() else 0.0,
		"second_cpu": _median(second_cpu) if second.is_valid() else 0.0}


## COUNT THE ROUND, OR THROW IT AWAY. The two baselines either side of a measured round must agree to
## `ROUNDS_AGREE_WITHIN`, or the machine changed underneath the measurement and the difference is not
## the viewport's. A thrown-away round is said out loud: a probe that quietly dropped the rounds it
## did not like would report whatever it was hoping for.
func _settle_up(name_of: String, before: float, after: float, reading: Dictionary) -> void:
	if absf(after - before) > ROUNDS_AGREE_WITHIN:
		_voided.get_or_add(name_of, []).append("%.3f then %.3f ms" % [before, after])
		print("[director] VOID %s: baselines %.3f and %.3f ms disagree by more than %.3f" % [
			name_of, before, after, ROUNDS_AGREE_WITHIN])
		return
	_deltas.get_or_add(name_of, []).append(float(reading["wall"]) - (before + after) * 0.5)
	_own_gpu.get_or_add(name_of, []).append(float(reading["second_gpu"]))
	_own_cpu.get_or_add(name_of, []).append(float(reading["second_cpu"]))


func _report() -> void:
	print("[director] COST OF A SECOND FULL PASS OVER THE WORLD, over %d rounds of %d frames:" % [
		_rounds, _frames])
	var counted: int = 0
	for rung in LADDER:
		var name_of: String = String(rung["name"])
		var each: Array = _deltas.get(name_of, [])
		var voided: Array = _voided.get(name_of, [])
		if each.is_empty():
			print("[director]   %-12s no round counted; %d void" % [name_of, voided.size()])
			continue
		counted += 1
		var least: float = INF
		var most: float = -INF
		var total: float = 0.0
		for one in each:
			least = minf(least, float(one))
			most = maxf(most, float(one))
			total += float(one)
		print("[director]   %-12s %+.3f ms a frame (%d counted, %d void, %.3f to %.3f); its own timers, GPU %.3f ms and CPU %.3f ms" % [
			name_of, total / float(each.size()), each.size(), voided.size(), least, most,
			_mean(_own_gpu.get(name_of, [])), _mean(_own_cpu.get(name_of, []))])
	_check("every_second_view_was_timed_at_least_once", counted == LADDER.size(),
		"%d of %d had a round its baselines agreed on; run it on a quieter machine" % [counted, LADDER.size()])


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for one in values:
		total += float(one)
	return total / float(values.size())


## THE PICTURE THE SECOND VIEW DREW, AND THE PROOF THAT IT DREW ANYTHING.
##
## A second viewport that fails silently hands back a texture full of the clear colour, and a clear
## colour is a perfectly good-looking picture in a log. So the check is not "is there an image" but
## "is this image neither blank nor the root's own" -- the same question the feature itself has to
## answer, one measurement earlier.
func _prove_it_drew(name_of: String) -> void:
	var view: Viewport = _sub if _sub != null else _window
	var picture: Image = view.get_texture().get_image() if view != null else null
	if picture == null:
		_check("the_%s_view_has_a_picture" % name_of, false, "no viewport texture")
		return
	picture.save_png("%s/%s.png" % [_out, name_of])
	var root_picture: Image = get_viewport().get_texture().get_image()
	root_picture.save_png("%s/%s-root.png" % [_out, name_of])
	var mine: Dictionary = _spread_of(picture)
	_check("the_%s_view_drew_a_world" % name_of, float(mine["spread"]) > 0.02,
		"colour spread %.4f, mean %s" % [mine["spread"], mine["mean"]])
	# DIFFERENT CAMERAS, DIFFERENT PICTURES, PIXEL BY PIXEL. Mean colour was the first thing tried and
	# it is nearly useless here: two views of the same island at the same hour average to almost the
	# same grey-green. The question is whether the same pixel shows the same thing.
	var apart: float = _pixels_apart(picture, root_picture)
	_check("and_the_%s_view_is_not_the_root_view" % name_of, apart > 0.02,
		"%.4f mean difference a pixel from the root's picture" % apart)


## HOW FAR APART TWO PICTURES ARE, per pixel, in colour. Sampled on a grid by FRACTION of the width,
## so two pictures of different sizes can still be compared -- a 960-wide recording against a
## 1600-wide root is the ordinary case here.
func _pixels_apart(one: Image, other: Image) -> float:
	const GRID: int = 48
	var total: float = 0.0
	for j in range(GRID):
		for i in range(GRID):
			var across: float = (float(i) + 0.5) / float(GRID)
			var down: float = (float(j) + 0.5) / float(GRID)
			var a: Color = one.get_pixel(int(across * one.get_width()), int(down * one.get_height()))
			var b: Color = other.get_pixel(int(across * other.get_width()), int(down * other.get_height()))
			total += (Vector3(a.r, a.g, a.b) - Vector3(b.r, b.g, b.b)).length()
	return total / float(GRID * GRID)


## The mean colour of an image and how far its pixels spread from it. A blank viewport has a spread of
## zero whatever colour it was cleared to, which is what "it drew nothing" looks like from here.
func _spread_of(picture: Image) -> Dictionary:
	var step: int = maxi(1, picture.get_width() / 64)
	var mean: Vector3 = Vector3.ZERO
	var seen: int = 0
	var samples: Array[Vector3] = []
	for y in range(0, picture.get_height(), step):
		for x in range(0, picture.get_width(), step):
			var colour: Color = picture.get_pixel(x, y)
			var point := Vector3(colour.r, colour.g, colour.b)
			samples.append(point)
			mean += point
			seen += 1
	if seen == 0:
		return {"mean": Vector3.ZERO, "spread": 0.0}
	mean /= float(seen)
	var spread: float = 0.0
	for point in samples:
		spread += (point - mean).length()
	return {"mean": mean, "spread": spread / float(seen)}


## A SUBVIEWPORT SHARING THE WORLD, with its own camera posed away from the observer's.
func _build_a_subviewport(size: Vector2i) -> RID:
	_sub = SubViewport.new()
	_sub.name = "DirectorProbe"
	_sub.size = size
	# SHARED WORLD. `own_world_3d` left false is what makes this a second view of the SAME world
	# rather than a second, empty one.
	_sub.own_world_3d = false
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub.msaa_3d = Viewport.MSAA_DISABLED
	_sub.scaling_3d_scale = 1.0
	add_child(_sub)
	_sub.add_child(_pose_a_second_camera())
	return _sub.get_viewport_rid()


## A SEPARATE OS WINDOW, which is its own viewport and is never touched by the root's `use_xr`.
func _build_a_window(size: Vector2i) -> RID:
	_window = Window.new()
	_window.name = "DirectorWindow"
	_window.title = "director probe"
	_window.size = size
	_window.position = Vector2i(40, 40)
	_window.own_world_3d = false
	_window.msaa_3d = Viewport.MSAA_DISABLED
	_window.scaling_3d_scale = 1.0
	add_child(_window)
	_window.add_child(_pose_a_second_camera())
	return _window.get_viewport_rid()


## THE SECOND CAMERA, DELIBERATELY SOMEWHERE ELSE. Beside the observer and turned a quarter turn, so
## the two pictures cannot agree by accident and `and_the_..._view_is_not_the_root_view` means
## something. Its far plane is the level's own, or the sea would stop at 100 m and the second pass
## would be cheap for a reason that has nothing to do with viewports.
func _pose_a_second_camera() -> Camera3D:
	_second_camera = Camera3D.new()
	_second_camera.name = "DirectorProbeCamera"
	_second_camera.far = _level.observer.far
	_second_camera.near = _level.observer.near
	_second_camera.fov = 60.0
	_second_camera.position = _level.observer.global_position + Vector3(0.0, 30.0, 0.0)
	_second_camera.rotation = _level.observer.global_rotation + Vector3(0.0, PI * 0.5, 0.0)
	_second_camera.current = true
	return _second_camera


## STOP THE WORLD BUT LEAVE IT STANDING. `scenery_shot.gd`'s, for the reason given where it is called.
func _pause_the_simulation() -> void:
	var sim: Node = get_node_or_null("/root/Sim")
	if sim == null:
		_check("there_is_a_simulation_to_pause", false, "no Sim autoload")
		return
	sim.set_physics_process(false)
	_level.set_physics_process(false)
	sim.set("previous", sim.get("current"))
	print("[director] simulation paused: no ticks, no fire front, every vehicle drawn where it last was")


func _tear_down() -> void:
	if _sub != null:
		_sub.queue_free()
		_sub = null
	if _window != null:
		_window.queue_free()
		_window = null
	_second_camera = null


func _median(values: PackedFloat64Array) -> float:
	return _percentile(values, 0.5)


func _percentile(values: PackedFloat64Array, at: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = Array(values)
	sorted.sort()
	return float(sorted[clampi(int(sorted.size() * at), 0, sorted.size() - 1)])


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
