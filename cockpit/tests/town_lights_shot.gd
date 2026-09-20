extends Node
## A TOWN'S LIGHTS BY DISTANCE: the first city photographed from fixed ranges, at a time of day, in clear air and in
## the low mist, on each finish -- with the reaches that decide what is drawn printed beside each picture, the lit points
## counted, and the frame timed.
##
##   Godot --path cockpit --resolution 1600x900 res://tests/town_lights_shot.tscn -- --level=watch --clouds=none \
##       --distances=2000,5000,10000,15000 --finishes=plain,fine --times=night --airs=clear,mist --out=C:/somewhere
##
## NOT HEADLESS -- it renders, and what it is for is looking. Asked for on 2026-09-15: "I should be able to see the lights on
## a building from farther away". The question a picture answers is where the lights stop; the question the printout
## answers is WHICH limit stopped them -- the batch's visibility range, the window grid's fade, or the fog.
##
## WHERE IT STANDS. South of `TownCatalogue.towns()[0]`'s centre (or on `--bearing=` degrees from north, clockwise) at each
## distance, looking at its middle 60 m up. CLEAR is the eye `CLEAR_UP` over the ground and MIST the eye `MIST_UP` over it.
## The depth fog is the time of day's `clear_air` at both heights (since 2026-09-15); what the low eye adds is the low mist,
## drawn by `MistLayer`'s pass over the whole view. What is printed is read back off the environment, never worked out here.
##
## WHAT IS COUNTED, inside the box round the town's buildings on the picture (`_town_box`): POINTS, pixels brighter than all
## eight neighbours and `POINT_ABOVE` over the box's own background (the median of its border); and LIGHT, the sum of
## every pixel's luminance over that background. A town drawn as flat glowing blocks has light and few points; a town
## that has faded has neither. The box is saved as a 1:1 crop and four times enlarged, for point size and shimmer.
##
## `--sweep=FROM,TO,STEP` stands at every STEP metres from FROM to TO instead of `--distances`, and holds the town's light
## across the handover between its walls and its far lights: no reading may fall under three quarters of the lower of its
## two neighbours or rise over a third above the higher -- a gap between the two is a dip, both at once is a bump.
##
## `--compare` photographs each view again with the far lights hidden, and against two frames of the same picture with
## them shown, so whatever else moves on its own is not counted. By DAY hiding them may change no more than that; at
## NIGHT over the mist past FINE's `windows_to` it must change more. Evening and the mist are printed and not held: how far
## a light is seen through them is the fog's to say. `--far-lights=off` hides them for every view, to time without them.
##
## `--up=M` stands the CLEAR eye M metres over the ground instead of `CLEAR_UP`: low, so near blocks stand in front of far
## ones, for the picture of a tall block hiding a lower one's lit side.
##
## `--fog-check` DOES NOTHING ELSE: it holds the far lights' own fog to the engine's. At each finish's handover distance,
## over the mist, the town is drawn four ways -- its walls' lights alone and its far lights alone, each with the fog at
## the preset's density and at none -- and each lit against the same view with no window lit, so walls, roads, sky and the
## fog's own colour cancel. What each lets through is the lit light with fog over the lit light without, in linear light
## with the linear tonemapper and a glow low enough that nothing clips. The two must agree within `FOG_AGREE`. And the
## environment must have no height fog, no volumetric fog and the exponential fog mode, which is all
## `world/shaders/scene_fog.gdshaderinc` models.
##
## THE LAMPS (obstruction lights since 2026-09-15): REDS is how many pixels in the box are a red point -- red over the median
## of the 5x5 ring round them by `POINT_ABOVE`, reddest of their eight neighbours and red rather than warm -- and it is printed
## ONLY BESIDE THE SAME COUNT WITH THE LAMPS HIDDEN, never alone. Over the mist the hidden count is 0; from a low eye near the
## city the lit brick walls give 203 at 1 km and 216 at 2 km in the mist with no lamp drawn (2026-09-15), so there a red count
## says nothing, and the pixels changed by hiding the lamps are the reading. The flash is HELD ON for every
## picture (`--flash=live` leaves it flashing on the tick), since a picture taken between flashes shows no red. `--compare`
## hides the lamps as well as the far lights and prints what each changes; by DAY hiding the lamps may change no more than
## two frames do. `--lamps=off` hides them for every view, to time without them.
##
## THE STREET LIGHTS ARE SWITCHED OFF (`TownTuning.STREET_LIGHTS_ON`, 2026-09-15). `--street-lights=on` builds them for the run,
## through `TownView.street_lights_in_tests`, to look at them or to time them against the town without. Every view prints what it
## cost beside its picture: the street lights' batches built, draws and primitives in the view and in the shadow pass, static
## memory and video memory.
##
## `--light-least=X` and `--light-spacing=X` set the far lights' faintest peak and gathering spacing for the run, to choose
## `TownTuning.FAR_LIGHT_LEAST` and `FAR_LIGHT_SPACING` by eye; `--lights-shader=res://...` draws them with another shader.
##
## THE WORLD IS HELD STILL while it looks: no simulation, no vehicles, rounds, text, fires or the air's markers, which would
## otherwise be lights of their own in the box.

## How long the world runs before anything is looked at: the level built and the yard filled.
const WARM: int = 240
## How long a pose, a finish or a time is given before its frames count.
const SETTLE: int = 45
## The eye over the ground in clear air and in the mist, metres: over the low mist's ceiling, and down in its haze.
const CLEAR_UP: float = 900.0
const MIST_UP: float = 40.0
## How much brighter than the box's background a pixel must be, and than its eight neighbours, to be a point of light.
const POINT_ABOVE: float = 0.03
## How closely the walls' lights and the far lights must agree on what the fog lets through, as a share of the light.
const FOG_AGREE: float = 0.03
## Where the lamps are held to the fog, metres south of the city: far enough that every red is on its floor.
const LAMP_FOG_AT: float = 5000.0

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://town_lights"
var _frames: int = 60
var _distances: Array[float] = [2000.0, 5000.0, 10000.0, 15000.0]
var _finishes: Array[String] = ["plain", "fine"]
var _times: Array[int] = []
var _airs: Array[String] = ["clear", "mist"]
var _bearing: float = 180.0
## Where the camera is held, re-placed every frame: the observer would otherwise be moved by its own input.
var _pose: Array = []
## `--sweep`: whether the distances are a sweep across the handover, and each view's town light in order, per series.
var _sweeping: bool = false
var _series_light: Array[float] = []
## `--compare` and `--far-lights=off`: see the top of the file.
var _compare: bool = false
var _far_lights_off: bool = false
## `--lamps=off` and `--flash=`: see THE LAMPS at the top. The phase the flash is held at, or -1 to leave it on the tick.
var _lamps_off: bool = false
var _flash_held: float = 0.12
## `--up=M` and `--fog-check`: see the top of the file.
var _up: float = -1.0
var _fog_check: bool = false
## How many pixels of the town's box two frames of one picture differ by, the most seen, beyond which a change is counted.
const CHANGED: float = 8.0 / 255.0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[lights] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.lstrip("-") == "compare":
			_compare = true
			continue
		if argument.lstrip("-") == "fog-check":
			_fog_check = true
			continue
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"out":
				_out = parts[1]
			"frames":
				_frames = maxi(int(parts[1]), 1)
			"distances":
				_distances.assign([])
				for one in parts[1].split(",", false):
					_distances.append(float(one))
			"finishes":
				_finishes.assign(Array(parts[1].split(",", false)))
			"airs":
				_airs.assign(Array(parts[1].split(",", false)))
			"bearing":
				_bearing = float(parts[1])
			"far-lights":
				_far_lights_off = parts[1] == "off"
			"lamps":
				_lamps_off = parts[1] == "off"
			"street-lights":
				TownView.street_lights_in_tests = parts[1] == "on"
			"flash":
				_flash_held = -1.0 if parts[1] == "live" else float(parts[1])
			"up":
				_up = float(parts[1])
			"sweep":
				var ends: PackedStringArray = parts[1].split(",")
				_distances.assign([])
				var at: float = float(ends[0])
				while at <= float(ends[1]) + 0.5:
					_distances.append(at)
					at += maxf(float(ends[2]), 1.0)
				_sweeping = true
			"times":
				for asked in parts[1].split(",", false):
					var which: int = DaylightTuning.When.keys().find(asked.to_upper())
					if which < 0:
						_check("the_time_%s_is_a_time_of_day" % asked, false, "day, evening or night")
					else:
						_times.append(which)
	if _times.is_empty():
		_times.append(DaylightTuning.When.NIGHT)
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	# WHICH LEVEL, AS BOOT WOULD CHOOSE IT. This probe builds the level itself, so boot never reads `--world=`: without this
	# the flag was ignored in silence, and the first pictures of seated inner on the alpine world were the island's inner
	# (2026-09-15). `ChartDrawer.asked_in` and `Net.choose_level`, exactly as world/boot.gd calls them, refusal and all.
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
	print("[lights] level %s, world %s; the first town stands at %s" % [Net.level, ChartDrawer.chart(Net.level).world,
		"its seat once the ground stands" if ChartDrawer.chart(Net.level).world != "island" else str(TownCatalogue.towns()[0]["centre"])])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_viewport().scaling_3d_scale = PilotRig.RENDER_SCALE
	print("[lights] %s, %s precision, %s on %s, window %s, 3D scale %.2f, ONE view (a headset draws two)" % [
		Engine.get_version_info()["string"], "double" if OS.has_feature("double") else "single",
		RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name(),
		DisplayServer.window_get_size(), get_viewport().scaling_3d_scale])
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	# A GENERATED GROUND TAKES SECONDS TO STAND, and the level builds its towns after it: the warm-up counts from then, and the
	# first town is read only once it is seated.
	if ChartDrawer.chart(Net.level).world != "island":
		const GROUND_PATIENCE: int = 6000
		var waited: int = 0
		while _level.ground_built_msec < 0.0 and waited < GROUND_PATIENCE:
			await get_tree().process_frame
			waited += 1
		_check("the_generated_ground_stood", _level.ground_built_msec >= 0.0,
			"in %.0f ms after %d frames; the first town, %s, at %s" % [_level.ground_built_msec, waited,
				TownCatalogue.towns()[0]["name"], TownCatalogue.towns()[0]["centre"]])
		if _level.ground_built_msec < 0.0:
			_finish()
			return
	for i in range(WARM):
		await get_tree().process_frame
	_hold_still()
	# THE FLASH HELD ON, written after the level hands the tick's phase and before the frame is drawn.
	if _flash_held >= 0.0:
		RenderingServer.frame_pre_draw.connect(func() -> void:
			if _level != null and _level.towns != null and _level.towns.lamp_material() != null:
				_level.towns.lamp_material().set_shader_parameter("flash_phase", _flash_held))
	# `--lights-shader=res://...`: the far lights drawn with another shader, to take one apart or time one against another.
	# `--light-least=X`: the far lights' faintest peak (TownTuning.FAR_LIGHT_LEAST) set to X for the run, to choose it by eye.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--lights-shader="):
			for material in _level.towns.call("_light_materials"):
				(material as ShaderMaterial).shader = load(argument.get_slice("=", 1))
		# `--night-adaptation=X`: the pools' night adaptation (TownTuning.night_adaptation()) for the run, on the pools and the
		# lamps both.
		if argument.begins_with("--night-adaptation="):
			# The pools' material is null while the street lights are switched off.
			for material in [_level.towns.pool_material(), _level.towns.lamp_material()]:
				if material != null:
					(material as ShaderMaterial).set_shader_parameter("night_adaptation", float(argument.get_slice("=", 1)))
			print("[lights] night_adaptation set to %s for this run" % argument.get_slice("=", 1))
		if argument.begins_with("--light-least="):
			for material in _level.towns.call("_light_materials"):
				(material as ShaderMaterial).set_shader_parameter("point_least", float(argument.get_slice("=", 1)))
			print("[lights] far lights' point_least set to %s for this run" % argument.get_slice("=", 1))
		# `--light-spacing=X`: the far lights' gathering spacing in pixels (TownTuning.FAR_LIGHT_SPACING), likewise.
		if argument.begins_with("--light-spacing="):
			for material in _level.towns.call("_light_materials"):
				(material as ShaderMaterial).set_shader_parameter("point_spacing", float(argument.get_slice("=", 1)))
			print("[lights] far lights' point_spacing set to %s for this run" % argument.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(_out)
	var viewport: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	_print_the_reaches()
	if _fog_check:
		await _hold_the_fog_to_the_engines(viewport)
		_pose = []
		_finish()
		return
	for finish_name in _finishes:
		await _wear(finish_name)
		for time in _times:
			_level.choose_time(time)
			for air in _airs:
				_series_light.clear()
				for distance in _distances:
					await _look(viewport, finish_name, time, air, distance)
				_hold_the_handover("%s_%s_%s" % [finish_name, DaylightTuning.name_of(time).to_lower(), air])
	_pose = []
	_finish()


func _process(_delta: float) -> void:
	if _pose.is_empty() or _level == null or _level.observer == null:
		return
	_level.observer.look_from(_pose[0], _pose[1])


## NOTHING BUT THE TOWN MAKES LIGHT: the simulation stopped, and every vehicle, round, carriage, fire and line of text hidden.
func _hold_still() -> void:
	var sim: Node = get_node("/root/Sim")
	sim.set_physics_process(false)
	_level.set_physics_process(false)
	sim.set("previous", sim.get("current"))
	for node_name in ["Vehicles", "Shots", "Ui"]:
		var node: Node = _level.get_node_or_null(node_name)
		if node != null:
			node.set("visible", false)
	var carriages: Dictionary = _level.get("_carriages")
	for engine in carriages:
		for car in carriages[engine]:
			(car as Node3D).visible = false
	if _level.burning != null:
		_level.burning.set("visible", false)
	if _level.lift != null:
		_level.lift.set("visible", false)
	var board := _level.observer.get("_board") as CanvasItem
	if board != null:
		board.visible = false


## WHAT DECIDES HOW FAR A TOWN IS DRAWN, as the level has it: every building batch's visibility range, each finish's window
## fade, and the far glow. Read off the nodes and the materials.
func _print_the_reaches() -> void:
	var ends: Array[float] = []
	for batch in _level.towns.building_batches():
		ends.append(batch.visibility_range_end)
	ends.sort()
	var materials: Array = _level.towns.call("_materials")
	var windows_to: Array = materials.map(func(m: ShaderMaterial): return m.get_shader_parameter("windows_to"))
	print("[lights] reaches: camera far %.0f m; %d building batches, visibility_range_end %.0f to %.0f m; windows_to plain/fine %s; far_glow %s" % [
		_level.observer.far, ends.size(), ends.front() if not ends.is_empty() else -1.0,
		ends.back() if not ends.is_empty() else -1.0, windows_to, materials[0].get_shader_parameter("far_glow")])


func _look(viewport: RID, finish_name: String, time: int, air: String, distance: float) -> void:
	var town: Dictionary = TownCatalogue.towns()[0]
	var centre: Vector3 = town["centre"]
	var away := Vector3(sin(deg_to_rad(_bearing)), 0.0, -cos(deg_to_rad(_bearing)))
	var at: Vector3 = centre + away * distance
	var ground: float = maxf(Terrain.surface_height(at), 0.0)
	at.y = ground + (MIST_UP if air == "mist" else (_up if _up > 0.0 else CLEAR_UP))
	_pose = [at, centre + Vector3.UP * 60.0]
	if _far_lights_off:
		_show_far_lights(false)
	if _lamps_off:
		_show_lamps(false)
	for i in range(SETTLE):
		await get_tree().process_frame
	var gpu: Array = []
	var cpu: Array = []
	for i in range(_frames):
		await RenderingServer.frame_post_draw
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
	gpu.sort()
	cpu.sort()
	var draws: int = RenderingServer.viewport_get_render_info(viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var picture: Image = get_viewport().get_texture().get_image()
	var name: String = "town-%s-%s-%s-%02dkm" % [finish_name, DaylightTuning.name_of(time).to_lower(), air,
		int(round(distance / 1000.0))]
	var saved: int = picture.save_png("%s/%s.png" % [_out, name])
	_check("saved_%s" % name, saved == OK, _out)
	var air_now: Environment = (_level.get_node("WorldEnvironment") as WorldEnvironment).environment
	var density: float = air_now.fog_density
	var box: Rect2i = _town_box(picture)
	var reading: Dictionary = _read_the_box(picture, box)
	if box.size.x > 0:
		var crop: Image = picture.get_region(box)
		crop.save_png("%s/%s-crop.png" % [_out, name])
		var big: Image = crop.duplicate()
		big.resize(box.size.x * 4, box.size.y * 4, Image.INTERPOLATE_NEAREST)
		big.save_png("%s/%s-crop4x.png" % [_out, name])
	print("[lights] view=%s eye=(%.0f, %.0f, %.0f) fog_density=%.6f transmission=%.4f box=%s points=%d light=%.2f brightest=%.3f background=%.3f gpu_median_ms=%.3f cpu_median_ms=%.3f draws=%d" % [
		name, at.x, at.y, at.z, density, exp(-density * distance), box, reading["points"], reading["light"],
		reading["brightest"], reading["background"], float(gpu[gpu.size() / 2]), float(cpu[cpu.size() / 2]), draws])
	# WHAT THE VIEW COST, beside the picture: the street lights are what the switch is for (2026-09-15).
	var visible: int = RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	var shadow: int = RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW
	print("[lights] cost view=%s street_lights=%s lamps_poles_pools_batches=%d,%d,%d draws_visible=%d draws_shadow=%d primitives_visible=%d primitives_shadow=%d static_mb=%.2f video_mb=%.2f buffer_mb=%.2f texture_mb=%.2f" % [
		name, "on" if TownView.street_lights_on() else "off", _level.towns.street_lamp_batches().size(),
		_level.towns.pole_batches().size(), _level.towns.pool_batches().size(),
		draws, RenderingServer.viewport_get_render_info(viewport, shadow, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RenderingServer.viewport_get_render_info(viewport, visible, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		RenderingServer.viewport_get_render_info(viewport, shadow, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0])
	_series_light.append(float(reading["light"]))
	if _compare and not _far_lights_off and box.size.x > 0:
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var again: Image = get_viewport().get_texture().get_image()
		_show_far_lights(false)
		for i in range(3):
			await RenderingServer.frame_post_draw
		var hidden: Image = get_viewport().get_texture().get_image()
		_show_far_lights(true)
		var moving: int = _changed(picture, again, box)
		var theirs: int = _changed(picture, hidden, box)
		print("[lights] far_lights view=%s pixels_changed_hiding_them=%d pixels_changed_on_their_own=%d" % [name, theirs, moving])
		_show_lamps(false)
		for i in range(3):
			await RenderingServer.frame_post_draw
		var unlamped: Image = get_viewport().get_texture().get_image()
		_show_lamps(true)
		var lamps_changed: int = _changed(picture, unlamped, box)
		# THE REDS THAT ARE NOT LAMPS, counted in the same box with the lamps hidden: what the lamps add is the difference.
		var reds_without: int = int(_read_the_box(unlamped, box)["reds"])
		print("[lights] lamps view=%s pixels_changed_hiding_them=%d pixels_changed_on_their_own=%d reds_shown=%d reds_hidden=%d" % [
			name, lamps_changed, moving, reading["reds"], reds_without])
		if time == DaylightTuning.When.DAY:
			_check("by_day_the_lamps_draw_nothing_%s" % name, lamps_changed <= moving,
				"%d pixels of the town's box changed with them hidden, %d between two frames" % [lamps_changed, moving])
		if time == DaylightTuning.When.DAY:
			_check("by_day_the_far_lights_draw_nothing_%s" % name, theirs <= moving,
				"%d pixels of the town's box changed with them hidden, %d between two frames" % [theirs, moving])
		elif time == DaylightTuning.When.NIGHT and air == "clear" and distance >= TownTuning.FINE_WINDOWS_TO:
			_check("at_night_past_the_windows_the_far_lights_draw_%s" % name, theirs > moving + 10,
				"%d pixels of the town's box changed with them hidden, %d between two frames" % [theirs, moving])


## THE FAR LIGHTS' FOG AGAINST THE ENGINE'S: see `--fog-check` at the top of the file.
func _hold_the_fog_to_the_engines(viewport: RID) -> void:
	var air: Environment = (_level.get_node("WorldEnvironment") as WorldEnvironment).environment
	_check("the_scenes_fog_is_only_what_the_far_lights_take",
		air.fog_mode == Environment.FOG_MODE_EXPONENTIAL and absf(air.fog_height_density) < 0.000001
			and not air.volumetric_fog_enabled,
		"fog mode %d, height density %f, volumetric %s" % [air.fog_mode, air.fog_height_density, air.volumetric_fog_enabled])
	_level.choose_time(DaylightTuning.When.NIGHT)
	air.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var walls: Array = _level.towns.call("_materials")
	var lights: Array = _level.towns.call("_light_materials")
	var town: Dictionary = TownCatalogue.towns()[0]
	var centre: Vector3 = town["centre"]
	# THE HANDOVER ASKED OF TownTuning, never read back off a material this check has already pushed out of reach: the first
	# version did, and checked FINE at 1 m (2026-09-15).
	var handovers: Array[float] = [TownTuning.PLAIN_WINDOWS_TO, TownTuning.FINE_WINDOWS_TO]
	# CLEAR AIR AND THICKER: night's clear air, and the depth fog a hundredth of the way into a cloud's whiteout -- two densities
	# Daylight really writes. Until 2026-09-15 they were night's `mist_above` and `mist_density`, the depth fog over and in an
	# eye-height mist that is gone (the low mist lies in the world now, `MistLayer`).
	var clear: float = float(DaylightTuning.NIGHT["clear_air"])
	var densities: Array[float] = [clear, lerpf(clear, CloudTuning.WHITEOUT_DENSITY, 0.01)]
	for f in range(2):
		await _wear(["plain", "fine"][f])
		var handover: float = handovers[f]
		var at: Vector3 = centre + Vector3(0.0, 0.0, handover)
		at.y = maxf(Terrain.surface_height(at), 0.0) + CLEAR_UP
		_pose = [at, centre + Vector3.UP * 60.0]
		for i in range(SETTLE):
			await get_tree().process_frame
		for density in densities:
			await _hold_one_density(f, handover, density, air, walls, lights)
	await _hold_the_lamps_to_the_fog(air)


## ONE FINISH AND ONE FOG DENSITY: the walls' lights and the far lights, each lit and unlit, with the fog and without.
func _hold_one_density(f: int, handover: float, density: float, air: Environment, walls: Array, lights: Array) -> void:
		var through: Dictionary = {}
		for side in ["walls", "lights"]:
			# WHO CARRIES THE LIGHT: the walls with their fade pushed out of reach and the far lights with none, or the reverse.
			var wall_to: float = 1000000.0 if side == "walls" else 1.0
			for material in walls + lights:
				(material as ShaderMaterial).set_shader_parameter("windows_to", wall_to)
				(material as ShaderMaterial).set_shader_parameter("point_least", 0.0001)
			var lamp: Array[float] = []
			for fog in [density, 0.0]:
				air.fog_density = fog
				var sums: Array[float] = []
				for lit in [0.55, 0.0]:
					_level.towns.light_windows(lit, 0.3)
					for i in range(6):
						await RenderingServer.frame_post_draw
					var picture: Image = get_viewport().get_texture().get_image()
					sums.append(_linear_light(picture, _town_box(picture)))
				lamp.append(sums[0] - sums[1])
			through[side] = lamp[0] / maxf(lamp[1], 0.000001)
			print("[lights] fog view=%s-handover-%.0fm density=%.6f side=%s lamp light with fog %.3f without %.3f through %.4f" % [
				["plain", "fine"][f], handover, density, side, lamp[0], lamp[1], through[side]])
			air.fog_density = density
		_check("the_far_lights_let_through_what_the_walls_lights_do_%s_at_%f" % [["plain", "fine"][f], density],
			absf(float(through["walls"]) - float(through["lights"])) < FOG_AGREE,
			"at %.0f m and density %.6f: walls %.4f, far lights %.4f, exp(-density * distance) %.4f" % [handover, density,
				through["walls"], through["lights"], exp(-density * handover)])


## THE LAMPS TAKE THE FOG AS THE ENGINE'S FOG SAYS, FLOOR AND ALL: at `LAMP_FOG_AT` over the mist, at night, the lamps' light --
## the town with them shown against it with them hidden, so everything else cancels -- with the fog at night's mist density
## and at none, in linear light under the linear tonemapper. What gets through must be exp(-density * distance) to within
## `FOG_AGREE` of the light: a floor applied after the transmission lets through far more.
func _hold_the_lamps_to_the_fog(air: Environment) -> void:
	await _wear("plain")
	var centre: Vector3 = TownCatalogue.towns()[0]["centre"]
	var at: Vector3 = centre + Vector3(0.0, 0.0, LAMP_FOG_AT)
	at.y = maxf(Terrain.surface_height(at), 0.0) + CLEAR_UP
	_pose = [at, centre + Vector3.UP * 60.0]
	# NO WINDOW LIT, SO NOTHING CLIPS UNDER A LAMP, and the lamps at night's full share, set on their material for this check.
	_level.towns.light_windows(0.0, 0.0)
	_level.towns.lamp_material().set_shader_parameter("lamps", 1.0)
	for i in range(SETTLE):
		await get_tree().process_frame
	# THE THICKER OF THE TWO DENSITIES DAYLIGHT REALLY WRITES, as the windows' check above takes: night's clear air a hundredth of
	# the way into a cloud's whiteout. It was night's `mist_density`, the eye-height mist that is gone (`MistLayer`, 2026-09-15).
	var density: float = lerpf(float(DaylightTuning.NIGHT["clear_air"]), CloudTuning.WHITEOUT_DENSITY, 0.01)
	var lamp: Array[float] = []
	for fog in [density, 0.0]:
		air.fog_density = fog
		var sums: Array[float] = []
		for shown in [true, false]:
			_show_lamps(shown)
			for i in range(6):
				await RenderingServer.frame_post_draw
			var picture: Image = get_viewport().get_texture().get_image()
			sums.append(_linear_light(picture, _town_box(picture)))
		_show_lamps(true)
		lamp.append(sums[0] - sums[1])
	var through: float = lamp[0] / maxf(lamp[1], 0.000001)
	var wanted: float = exp(-density * LAMP_FOG_AT)
	print("[lights] fog view=lamps-%.0fm density=%.6f lamp light with fog %.3f without %.3f through %.4f wanted %.4f" % [
		LAMP_FOG_AT, density, lamp[0], lamp[1], through, wanted])
	_check("the_lamps_let_through_what_the_fog_does_floor_and_all", lamp[1] > 0.0 and absf(through - wanted) < FOG_AGREE,
		"at %.0f m and density %.6f: %.4f through, exp(-density * distance) %.4f" % [LAMP_FOG_AT, density, through, wanted])
	air.fog_density = density


## THE LIGHT IN `box` in linear light, each pixel's sRGB turned back to linear, summed.
static func _linear_light(picture: Image, box: Rect2i) -> float:
	var total: float = 0.0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			total += picture.get_pixel(x, y).srgb_to_linear().get_luminance()
	return total


## THE FAR LIGHTS SHOWN OR HIDDEN, on every built kilometre.
func _show_far_lights(on: bool) -> void:
	for batch in _level.towns.light_batches():
		batch.visible = on


## THE LAMPS SHOWN OR HIDDEN, on every built kilometre.
## The LIGHTS only -- obstruction lights, street lamps and their pools. A pole is there by day as at night, so it is not one:
## hidden with them, the poles changed 740 pixels at 700 m by day (2026-09-15).
func _show_lamps(on: bool) -> void:
	for batch in _level.towns.obstruction_batches() + _level.towns.street_lamp_batches() + _level.towns.pool_batches():
		batch.visible = on


## How many pixels of `box` differ between two pictures by more than `CHANGED` in any channel.
static func _changed(a: Image, b: Image, box: Rect2i) -> int:
	var count: int = 0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			if absf(p.r - q.r) > CHANGED or absf(p.g - q.g) > CHANGED or absf(p.b - q.b) > CHANGED:
				count += 1
	return count


## ACROSS THE HANDOVER, NO DIP AND NO BUMP: see `--sweep` at the top of the file.
func _hold_the_handover(series: String) -> void:
	if not _sweeping or _series_light.size() < 3:
		return
	var wrong: Array[String] = []
	for i in range(1, _series_light.size() - 1):
		var before: float = _series_light[i - 1]
		var after: float = _series_light[i + 1]
		var here: float = _series_light[i]
		if here < minf(before, after) * 0.75 or here > maxf(before, after) * 1.33:
			wrong.append("%.0f m reads %.1f between %.1f and %.1f" % [_distances[i], here, before, after])
	_check("across_the_handover_the_towns_light_neither_dips_nor_doubles_%s" % series, wrong.is_empty(),
		"%d readings from %.0f to %.0f m%s" % [_series_light.size(), _distances.front(), _distances.back(),
			"" if wrong.is_empty() else ": " + "; ".join(wrong)])


## THE BOX ROUND THE FIRST TOWN'S BUILDINGS ON THE PICTURE, padded by eight pixels and clipped to it; empty if none is in front.
func _town_box(picture: Image) -> Rect2i:
	var eye: Camera3D = get_viewport().get_camera_3d()
	var town: Dictionary = TownCatalogue.towns()[0]
	var box := Rect2()
	var any: bool = false
	var scale := Vector2(picture.get_size()) / get_viewport().get_visible_rect().size
	for building in _level.towns.drawn_buildings():
		var at: Vector3 = building["position"]
		if Vector2(at.x - town["centre"].x, at.z - town["centre"].z).length() > float(town["radius"]) * 1.2:
			continue
		var half: Vector3 = building["half_extents"]
		for corner in [Vector3(-1, -1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1), Vector3(1, -1, -1)]:
			var point: Vector3 = at + half * corner
			if eye.is_position_behind(point):
				continue
			var on: Vector2 = eye.unproject_position(point) * scale
			box = Rect2(on, Vector2.ZERO) if not any else box.expand(on)
			any = true
	if not any:
		return Rect2i()
	return Rect2i(box.grow(8.0)).intersection(Rect2i(Vector2i.ZERO, picture.get_size()))


## POINTS, LIGHT AND THE BRIGHTEST PIXEL in `box`, against the median luminance of its border. See the top of the file.
func _read_the_box(picture: Image, box: Rect2i) -> Dictionary:
	var out: Dictionary = {"points": 0, "reds": 0, "light": 0.0, "brightest": 0.0, "background": 0.0}
	# RED POINTS: a pixel with twice as much red as green, redder than its eight neighbours, and red over its OWN background by
	# POINT_ABOVE -- the median red of the ring of sixteen pixels two out round it. Against one corner of the box instead, the
	# low mist's own tint passed as red: 680 "reds" at 2 km from 40 m up, where 278 pixels changed with the lamps hidden
	# (2026-09-15).
	if box.size.x >= 5 and box.size.y >= 5:
		for y in range(box.position.y + 2, box.end.y - 2):
			for x in range(box.position.x + 2, box.end.x - 2):
				var p: Color = picture.get_pixel(x, y)
				if p.r < 2.0 * p.g:
					continue
				var reddest: bool = true
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if (dx != 0 or dy != 0) and picture.get_pixel(x + dx, y + dy).r >= p.r:
							reddest = false
				if not reddest:
					continue
				var ring: Array[float] = []
				for d in range(-2, 3):
					ring.append(picture.get_pixel(x + d, y - 2).r)
					ring.append(picture.get_pixel(x + d, y + 2).r)
				for d in range(-1, 2):
					ring.append(picture.get_pixel(x - 2, y + d).r)
					ring.append(picture.get_pixel(x + 2, y + d).r)
				ring.sort()
				if p.r >= (ring[ring.size() / 2 - 1] + ring[ring.size() / 2]) * 0.5 + POINT_ABOVE:
					out["reds"] = int(out["reds"]) + 1
	if box.size.x < 3 or box.size.y < 3:
		return out
	var border: Array[float] = []
	for x in range(box.position.x, box.end.x):
		border.append(picture.get_pixel(x, box.position.y).get_luminance())
		border.append(picture.get_pixel(x, box.end.y - 1).get_luminance())
	for y in range(box.position.y, box.end.y):
		border.append(picture.get_pixel(box.position.x, y).get_luminance())
		border.append(picture.get_pixel(box.end.x - 1, y).get_luminance())
	border.sort()
	var background: float = border[border.size() / 2]
	out["background"] = background
	for y in range(box.position.y + 1, box.end.y - 1):
		for x in range(box.position.x + 1, box.end.x - 1):
			var here: float = picture.get_pixel(x, y).get_luminance()
			out["light"] = float(out["light"]) + maxf(here - background, 0.0)
			out["brightest"] = maxf(float(out["brightest"]), here)
			if here < background + POINT_ABOVE:
				continue
			var peak: bool = true
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if (dx != 0 or dy != 0) and picture.get_pixel(x + dx, y + dy).get_luminance() >= here:
						peak = false
			if peak:
				out["points"] = int(out["points"]) + 1
	return out


## THE FINISH, BY THE KEY a player presses, read back off the level's surfaces. As `tests/scenery_shot.gd` wears one.
func _wear(finish_name: String) -> void:
	var fine: bool = finish_name == "fine"
	get_viewport().msaa_3d = Finish.multisampling()
	if Finish.is_fine() != fine:
		var code: Key = KEY_NONE
		for event in InputMap.action_get_events(Finish.ACTION):
			var key := event as InputEventKey
			if key != null:
				code = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		for down in [true, false]:
			var press := InputEventKey.new()
			press.keycode = code
			press.physical_keycode = code
			press.pressed = down
			Input.parse_input_event(press)
			await get_tree().process_frame
	get_viewport().msaa_3d = Finish.multisampling()
	_check("the_key_put_on_%s" % finish_name, Finish.is_fine() == fine and _level.towns.worn() == fine,
		"fine is %s, towns worn fine %s" % [Finish.is_fine(), _level.towns.worn()])


func _finish() -> void:
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
