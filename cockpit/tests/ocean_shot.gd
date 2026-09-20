extends Node
## THE OPEN SEA, LOOKED AT: from 20 m, 200 m and 1,000 m, at a grazing angle, into the sun's glitter, at dusk and under the
## moon, on each finish -- and what the sea costs the GPU from each place.
##
##   Godot --path cockpit --fixed-fps 60 --resolution 1600x900 res://tests/ocean_shot.tscn -- --level=watch --out=C:/somewhere
##   ... -- --level=watch --views=sea_20,grazing --finishes=plain --frames=240 --tag=after
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device. Whether the sea reads as an ocean -- dark, rough,
## varied, lit by the sky -- is for eyes; what the sea costs is for the GPU timer, which `--frames` reads over that many frames
## after `SETTLE` and prints as a median, vsync off.
##
## THE PLACES ARE FAR PAST THE ISLAND, off its +x side (`SEA`), where SeaSwell gives the sea its whole shape and nothing but
## water is in frame. A view faces OUT (along +x, away from the island) or into the LIGHT (the level's own DirectionalLight3D
## flattened, the sun by day and the moon at night), so glitter and its absence are both drawn. The same frame count reaches
## every picture in every launch under `--fixed-fps`, so a before and an after are drawn at the same shader TIME.
##
## The finish is chosen through `Finish.choose`, as tests/ship_shot.gd does: this looks at the sea, not at the switch
## (tests/scenery_shot.gd presses the key). Pictures in `--out`: `ocean-<finish>-<view>[-<tag>].png`.

## Frames after the camera, finish or time of day moves before a picture.
const SETTLE: int = 90
## Where the views stand: 3.3 km past the island's +x edge, off its middle.
const SEA := Vector3(10500.0, 0.0, 1500.0)
## Each view: eye height, pitch in degrees (negative looks down), facing ("out" or "light"), time of day, field of view.
const VIEWS: Dictionary = {
	"sea_20": [20.0, -8.0, "out", DaylightTuning.When.DAY, 70.0],
	"sea_200": [200.0, -20.0, "out", DaylightTuning.When.DAY, 70.0],
	"sea_1000": [1000.0, -30.0, "out", DaylightTuning.When.DAY, 70.0],
	"grazing": [3.0, -1.5, "out", DaylightTuning.When.DAY, 70.0],
	"glitter_60": [60.0, -10.0, "light", DaylightTuning.When.DAY, 70.0],
	"close_8": [8.0, -35.0, "out", DaylightTuning.When.DAY, 70.0],
	"dusk_20": [20.0, -6.0, "light", DaylightTuning.When.EVENING, 70.0],
	"dusk_200": [200.0, -15.0, "out", DaylightTuning.When.EVENING, 70.0],
	"night_moon_40": [40.0, -8.0, "light", DaylightTuning.When.NIGHT, 70.0],
	"night_200": [200.0, -15.0, "out", DaylightTuning.When.NIGHT, 70.0],
	# A HEADSET'S PIXEL: the field of view is worked out so a pixel of the window covers what a pixel of the headset does
	# (a field of view of 0 here), looking down the sun's glitter at dusk, for `--flicker`.
	"dusk_headset": [20.0, -4.0, "light", DaylightTuning.When.EVENING, 0.0],
}
## `--flicker=N`: the crop of each view saved and compared this many frames running, as a headset sees them one after another.
const FLICKER_CROP := Vector2i(480, 270)
## A step in luminance past this, of 255, between one frame and the next is counted as a pixel that popped.
const FLICKER_POP: float = 24.0

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://ocean_shot"
var _tag: String = ""
var _views: Array = VIEWS.keys()
var _finishes: PackedStringArray = ["plain", "fine"]
var _frames_timed: int = 0
var _flicker: int = 0
## `--scale=`: the 3D render scale. The game's own by default. PAST 2.0 IT IS 2.0: the rendering server clamps it, and 3.56,
## once taken for a headset's 18.3 MP, drew 3200x1800 (working_with_godot.md). Time a headset at 2.0, 31.2 px a degree like
## its render target, and multiply a difference by 18.3 / 5.76 (agents.md, "WHAT THE PAINTED SEA MAY COST").
var _scale: float = PilotRig.RENDER_SCALE


func _check(label: String, ok: bool, detail: String) -> void:
	print("[ocean_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--views="):
			_views = Array(argument.trim_prefix("--views=").split(","))
		elif argument.begins_with("--finishes="):
			_finishes = argument.trim_prefix("--finishes=").split(",")
		elif argument.begins_with("--tag="):
			_tag = argument.trim_prefix("--tag=")
		elif argument.begins_with("--frames="):
			_frames_timed = argument.trim_prefix("--frames=").to_int()
		elif argument.begins_with("--flicker="):
			_flicker = argument.trim_prefix("--flicker=").to_int()
		elif argument.begins_with("--scale="):
			_scale = argument.trim_prefix("--scale=").to_float()
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_viewport().scaling_3d_scale = _scale
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	print("[ocean_shot] %s, %s precision, %s on %s, window %s" % [Engine.get_version_info()["string"],
		"double" if OS.has_feature("double") else "single", RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(), DisplayServer.window_get_size()])
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	await _frames(60)
	# EVERY OVERLAY, the observer's own board included: it is a CanvasLayer of the observer's, not the level's `Ui`, and the
	# first pictures carried "WATCHING 73 vehicles" in the corner.
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var finish: Node = get_node("/root/Finish")
	for finish_name in _finishes:
		finish.call("choose", finish_name == "fine")
		for view in _views:
			if not VIEWS.has(view):
				_check("view_%s_exists" % view, false, "views: %s" % ", ".join(VIEWS.keys()))
				continue
			var spec: Array = VIEWS[view]
			_level.choose_time(int(spec[3]))
			await _frames(2)
			_pose(spec)
			await _frames(SETTLE)
			_pose(spec)
			await _frames(1)
			var name: String = "ocean-%s-%s%s" % [finish_name, view, ("-" + _tag) if _tag != "" else ""]
			_save(get_viewport().get_texture().get_image(), name)
			if _frames_timed > 0:
				await _time(name)
			if _flicker > 1:
				await _measure_flicker(name)
	_finish()


## STAND AT THE VIEW'S HEIGHT AND LOOK. The observer is told to stand still (`look_from`), so it chases nothing.
func _pose(spec: Array) -> void:
	var eye: Camera3D = _level.observer
	if float(spec[4]) > 0.0:
		eye.fov = float(spec[4])
	else:
		# The window's width covers width / (pixels a degree) degrees; the camera's fov is vertical.
		var window: Vector2 = Vector2(DisplayServer.window_get_size())
		var across: float = deg_to_rad(window.x / float(load("res://tests/builder.gd").get("HEADSET_PIXELS_PER_DEGREE")))
		eye.fov = rad_to_deg(2.0 * atan(tan(across * 0.5) * window.y / window.x))
	var facing := Vector3(1.0, 0.0, 0.0)
	if String(spec[2]) == "light":
		var light := _level.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
		if light != null:
			var toward_light: Vector3 = light.global_basis.z
			toward_light.y = 0.0
			if toward_light.length() > 0.01:
				facing = toward_light.normalized()
	var pitch: float = deg_to_rad(float(spec[1]))
	var at: Vector3 = SEA + Vector3.UP * float(spec[0])
	var ahead: Vector3 = facing * cos(pitch) + Vector3.UP * sin(pitch)
	_level.observer.call("look_from", at, at + ahead * 1000.0)


## THE GPU TIMER'S MEDIAN over `--frames` frames, and the CPU's beside it.
func _time(name: String) -> void:
	var rid: RID = get_viewport().get_viewport_rid()
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	for i in range(_frames_timed):
		await get_tree().process_frame
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
	gpu.sort()
	cpu.sort()
	print("[ocean_shot] timing %s gpu_median_ms %.3f cpu_median_ms %.3f frames %d" % [name, gpu[gpu.size() / 2],
		cpu[cpu.size() / 2], _frames_timed])


## HOW MUCH THE GLITTER FLICKERS: `--flicker` frames running, each cropped 1:1 from the middle of the lower half of the
## window (where the sun's path lies in `dusk_headset`) and saved, and each compared with the frame before it in luminance:
## the mean step, the 99th-percentile step and the share of pixels that popped by more than FLICKER_POP of 255. Waves that
## move smoothly step a little everywhere; a sea that sparkles pops.
func _measure_flicker(name: String) -> void:
	var window: Vector2i = DisplayServer.window_get_size()
	var corner := Vector2i((window.x - FLICKER_CROP.x) / 2, window.y / 2 + (window.y / 2 - FLICKER_CROP.y) / 2)
	var before: Image = null
	var steps := PackedFloat32Array()
	var popped: int = 0
	for i in range(_flicker):
		await RenderingServer.frame_post_draw
		var crop: Image = get_viewport().get_texture().get_image().get_region(Rect2i(corner, FLICKER_CROP))
		_save(crop, "%s-flicker-%d" % [name, i])
		if before != null:
			for y in range(FLICKER_CROP.y):
				for x in range(FLICKER_CROP.x):
					var step: float = absf(crop.get_pixel(x, y).get_luminance() - before.get_pixel(x, y).get_luminance()) * 255.0
					steps.append(step)
					if step > FLICKER_POP:
						popped += 1
		before = crop
	if steps.is_empty():
		return
	var total: float = 0.0
	for step in steps:
		total += step
	steps.sort()
	print("[ocean_shot] flicker %s frames %d crop %s mean_step %.2f p99_step %.1f popped %.3f %%" % [name, _flicker,
		FLICKER_CROP, total / float(steps.size()), steps[int(float(steps.size()) * 0.99)],
		100.0 * float(popped) / float(steps.size())])


func _save(picture: Image, name: String) -> void:
	var path: String = _out.path_join(name + ".png")
	_check("saved_%s" % name, picture.save_png(path) == OK, path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
