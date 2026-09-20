extends Node3D
class_name MistLayer
## THE LOW MIST OVER THE WHOLE VIEW: one quad drawn after everything opaque, which takes away and puts back what the mist
## between the eye and each pixel does (`world/shaders/mist.gdshader`), on both finishes, lying on a chart of the ground baked
## on a worker round the eye (`MistChart`).
##
## Asked for on 2026-09-15: "near-ground mist or low clouds that is thinner and creates more atmosphere". The mist before it was
## the environment's depth fog eased by the eye's height: one wall, the same everywhere, with no top (see `MistTuning`).
##
## ITS NUMBERS ARE GLOBAL SHADER UNIFORMS (project.godot [shader_globals], `mist_*`), because every see-through shader drawn after
## the pass must mist itself the same way (world/shaders/mist.gdshaderinc, held by tests/lint.gd) and a material cannot be
## handed them one by one. Written through RenderingServer ONCE PER CHANGE, and counted and recorded here (`writes`,
## `mist_written`) because reading a global back is a stall and headless has nothing to read. WHEN THE LAYER LEAVES THE TREE its
## densities go to 0, so a level with no mist -- a menu, `--mist=off` -- never wears the last level's.
##
## OWNED BY THE LEVEL AND TOLD, NEVER ASKING. The level hands it the time of day (`show_time`) and the finish (`wear`) once per
## change. The eye it reads each frame is the camera the viewport is drawn with, the midpoint of the eyes in a headset, and only
## to decide when the chart is baked again.
##
## THE CHART IS BAKED ON A WORKER, and the frame only uploads a finished image: `MistChart.bake` is static and pure, the task
## writes only into a Dictionary made for it, and the main thread reads that once `WorkerThreadPool.is_task_completed` says so.

const SHADER: Shader = preload("res://world/shaders/mist.gdshader")

## Which `DaylightTuning.When` the look the mist was last written for is nearest, or -1; and that look's count, or -1.
var time: int = -1
var _look_n: int = -1
## Whether FINE's steps are on.
var fine: bool = false
## How many global writes, ever, so a test can hold a still level to none.
var writes: int = 0
## Every global as last written, by name, for the tests.
var written: Dictionary = {}
## THE MIST'S CLOCK, seconds, written to `mist_clock` once a frame and not counted in `writes`: it is time, not a number that
## changed. Every mist call hands it rather than TIME (see mist.gdshaderinc).
var clock: float = 0.0
## Where the chart drawn now is centred (`MistChart.middle_for`), the thread it was baked on, and the texture.
var chart_middle := Vector3(INF, 0.0, INF)
var baked_on_thread: int = -1
var chart: ImageTexture = null
## THE TOWNS' TEXTURE (step 3): a texel a town, centre (x, ground y, z) and radius, and how many are in it.
var towns_texture: ImageTexture = null
var town_count: int = 0
## A TEST'S SEAM: milliseconds every bake sleeps, inside the work, so work done on the main thread by any path sleeps too.
var bake_delay_msec: int = 0

## THE COMPUTE MIST on PLAIN (`MistEffect`), hung on the level's Compositor, or null while the spatial quad draws. Whether it
## is the pass now, and the WorldEnvironment the level handed over (`use_environment`).
var effect: MistEffect = null
var computing: bool = false
var _air: WorldEnvironment = null
var _handed: bool = false
var _chart_rd := RID()
var _towns_rd := RID()
var _dome_density: float = 0.0
var _quad: MeshInstance3D = null
var _paint: ShaderMaterial = null
var _task: int = -1
var _baking: Dictionary = {}
## Which finish was last written: -1 none, 0 PLAIN, 1 FINE.
var _worn: int = -1


func _init() -> void:
	name = "Mist"
	_paint = ShaderMaterial.new()
	_paint.shader = SHADER
	# `--mist-pass=fill` draws the quad with nothing in it and no depth read: a pricing probe, to split the full-screen fill from
	# the depth copy the pass reads (team-lead, 2026-09-15). Never a level's choice.
	if pass_asked_on_the_command_line() == "fill":
		_paint.shader = load("res://tests/mist_fill_probe.gdshader")
	# `--mist-pass=edges` draws the depth buffer's jumps, two-surface texels and sky, for the compute mist's edge counts
	# (tests/mist_edges_probe.gdshader). Never a level's.
	elif pass_asked_on_the_command_line() == "edges":
		_paint.shader = load("res://tests/mist_edges_probe.gdshader")
		_paint.set_shader_parameter("edge", MistTuning.COMPUTE_EDGE)
	# FIRST AMONG THE TRANSPARENT: anything see-through drawn after it mists itself through mist.gdshaderinc and is laid over the
	# misted world, rather than misted as if it stood where the depth buffer says.
	_paint.render_priority = Material.RENDER_PRIORITY_MIN
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	_quad = MeshInstance3D.new()
	_quad.name = "Quad"
	_quad.mesh = mesh
	_quad.material_override = _paint
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# NEVER CULLED: the shader puts the quad in clip space wherever its node stands.
	_quad.custom_aabb = AABB(Vector3(-1e7, -1e7, -1e7), Vector3(2e7, 2e7, 2e7))
	add_child(_quad)
	_paint.set_shader_parameter("sky_reach", MistTuning.SKY_REACH)
	_write(&"mist_ceiling", MistTuning.CEILING)
	_write(&"mist_reach", MistTuning.REACH)
	# NO TOWNS UNTIL THE LEVEL HANDS THEM, but a texture from the start: the compute mist binds it every frame.
	show_towns([])


## PUT A TIME OF DAY ON THE MIST, if it is not on already: `MistTuning`'s numbers, and the sun `DaylightTuning` names.
## THE SHARE OF THE GAME'S HAZE THIS LEVEL'S MIST HOLDS (`LevelChart.haze`), 1 unless the level asks for less: every
## density below is multiplied by it, the haze, the stratus and the towns' domes, and nothing else.
var haze: float = 1.0
var _last_day: Dictionary = {}


## THE LEVEL'S AIR (lane/testfield, 2026-09-19): thin the mist to a share of the presets and draw the time of day again.
func thin(share: float) -> void:
	haze = share
	if not _last_day.is_empty():
		_look_n = -1
		show_time(_last_day)


func show_time(day: Dictionary) -> void:
	if int(day.get("n", -2)) == _look_n and _look_n >= 0:
		return
	_last_day = day
	_look_n = int(day.get("n", -1))
	time = int(day.get("time", Daylight.nearest_preset(float(day["minutes"]))))
	var mist: Dictionary = MistTuning.at(day)
	var part: String = part_asked_on_the_command_line()
	_write(&"mist_haze", Vector4(0.0 if part in ["stratus", "none"] else float(mist["haze_density"]) * haze, float(mist["haze_height"]),
		MistTuning.HAZE_BREAKUP, MistTuning.HAZE_SCALE))
	_write(&"mist_stratus", Vector4(0.0 if part in ["haze", "none"] else float(mist["stratus_density"]) * haze, float(mist["stratus_height"]),
		float(mist["stratus_width"]), MistTuning.STRATUS_SCALE))
	_write(&"mist_stratus_cover", mist["stratus_cover"])
	# THE HORIZON SKY'S COLOUR: see MistTuning's note. Never typed twice.
	_write(&"mist_colour", day["sky_horizon"])
	_write(&"mist_sun_colour", (day["sun_colour"] as Color) * float(day["sun_energy"]))
	_write(&"mist_towards_sun", day["towards_light"])
	_write(&"mist_sun", Vector3(float(mist["sun_glow"]), MistTuning.SUN_TIGHTNESS, MistTuning.DRIFT))
	# THE TOWNS' DOMES AND THEIR GLOW, from the same presets: the dome is haze, so it goes with the haze in the part probes.
	_dome_density = 0.0 if part in ["stratus", "none"] else float(mist["dome_density"]) * haze
	_write_town()
	_write(&"mist_town_glow", town_glow_of(day))
	# THE VALLEY POOLS, from the same presets (step 4): pools are haze, so they go with the haze in the part probes, and
	# `--mist-relief=off` takes them away for the pictures that tell what they add.
	_write(&"mist_pool", Vector4(0.0 if part in ["stratus", "none"] or relief_asked_off() else float(mist["pool_gain"]),
		MistTuning.POOL_DEPTH, 0.0, 0.0))


## PUT A FINISH ON THE MIST: FINE takes more steps along a ray and reads the stratus's second octave. Written only on a change.
## `--mist-steps=N` after the bare `--` holds both finishes to N steps, for the probe to price a step.
func wear(fine_now: bool) -> void:
	if _worn == int(fine_now):
		return
	_worn = int(fine_now)
	fine = fine_now
	var asked: int = steps_asked_on_the_command_line()
	_write(&"mist_steps", asked if asked >= 0 else (MistTuning.STEPS_FINE if fine else MistTuning.STEPS_PLAIN))
	_write(&"mist_stratus_look", Vector4(1.0 if fine else 0.0, MistTuning.STRATUS_MODELLING, MistTuning.STRATUS_REACH,
		MistTuning.STRATUS_MOST_TAU))
	_choose_the_pass()


## THE ENVIRONMENT THE COMPUTE MIST HANGS ON, from the level: its Compositor carries `effect` on PLAIN.
func use_environment(air: WorldEnvironment) -> void:
	_air = air
	_choose_the_pass()


## THE TOWNS THE DOMES STAND OVER, from the level once the ground and the towns stand (`TownCatalogue.towns()`, never TOWNS: on
## the generated ground a town is seated where its site is). A texel a town, at most `MistTuning.MOST_TOWNS`, the largest first as
## the catalogue orders them; a warning for any left out.
func show_towns(towns: Array) -> void:
	# `--mist-towns=off` after the bare `--` hands none: the pictures' probe for what the domes themselves add. Never a level's.
	if towns_asked_off():
		towns = []
	if towns.size() > MistTuning.MOST_TOWNS:
		push_warning("[mist] %d towns and the domes read %d; the smallest are left out" % [towns.size(), MistTuning.MOST_TOWNS])
	var image := Image.create(MistTuning.MOST_TOWNS, 1, false, Image.FORMAT_RGBAF)
	town_count = mini(towns.size(), MistTuning.MOST_TOWNS)
	for i in range(town_count):
		var centre: Vector3 = towns[i]["centre"]
		image.set_pixel(i, 0, Color(centre.x, centre.y, centre.z, float(towns[i]["radius"])))
	if towns_texture == null:
		towns_texture = ImageTexture.create_from_image(image)
		RenderingServer.global_shader_parameter_set(&"mist_towns", towns_texture.get_rid())
		if RenderingServer.get_rendering_device() != null:
			_towns_rd = RenderingServer.texture_get_rd_texture(towns_texture.get_rid())
		written["mist_towns"] = towns_texture
		writes += 1
	else:
		towns_texture.update(image)
	_write_town()


## THE LIGHT A TOWN'S DOME PUTS BACK at a time of day: a lit window's colour, times the share of windows lit and their glow as
## TownView lights them, times `MistTuning.TOWN_GLOW` -- windows only while street lights are off (TownTuning.STREET_LIGHTS_ON).
## Static and pure.
static func town_glow(which: int) -> Vector3:
	return town_glow_of(DaylightTuning.look_of(which))


## The same at any look.
static func town_glow_of(day: Dictionary) -> Vector3:
	var light: Color = TownTuning.PLAIN_WINDOW_LIGHT
	var share: float = float(day["windows_lit"]) * float(day["window_glow"]) * MistTuning.TOWN_GLOW
	return Vector3(light.r, light.g, light.b) * share


## HOW DENSE A TOWN'S DOME IS AT A POINT at a time of day: the shader's dome extinction per metre, summed over `towns`, for the
## tests. Static and pure.
static func dome_density_at(which: int, point: Vector3, towns: Array) -> float:
	var density: float = float(MistTuning.preset(which)["dome_density"])
	var sum: float = 0.0
	for i in range(mini(towns.size(), MistTuning.MOST_TOWNS)):
		var centre: Vector3 = towns[i]["centre"]
		var spread: float = maxf(float(towns[i]["radius"]) * MistTuning.DOME_SPREAD, 1.0)
		var off: float = Vector2(point.x - centre.x, point.z - centre.z).length() / spread
		sum += density * exp(-off * off) * exp(-maxf(point.y - centre.y, 0.0) / MistTuning.DOME_HEIGHT)
	return sum


func _write_town() -> void:
	_write(&"mist_town", Vector4(float(town_count), _dome_density, MistTuning.DOME_HEIGHT, MistTuning.DOME_SPREAD))


## WHICH PASS DRAWS THE MIST: the spatial quad, unless `MistTuning.COMPUTE_ON_PLAIN` puts the compute mist on PLAIN where there is a
## RenderingDevice (it is off: see MistTuning); never compute on FINE (MSAA: see MistEffect) or without a device.
## `--mist-pass=spatial`, `compute`, `compute-half` or `compute-mask` after the bare `--` holds it, for the probes. Static and pure.
static func computes(fine_now: bool, has_device: bool, asked: String) -> bool:
	if fine_now or not has_device or asked in ["spatial", "fill", "edges"]:
		return false
	return asked in ["compute", "compute-half", "compute-mask"] or MistTuning.COMPUTE_ON_PLAIN


func _choose_the_pass() -> void:
	var want: bool = _air != null and computes(fine, RenderingServer.get_rendering_device() != null, pass_asked_on_the_command_line())
	if want and effect == null:
		effect = MistEffect.new()
		# `--mist-pass=compute-half` times the half-resolution pass with nothing laid on: the composite costs the difference.
		effect.lay_on = pass_asked_on_the_command_line() != "compute-half"
		if not effect.lay_on:
			print("[mist] laying on skipped (--mist-pass=compute-half): the half-resolution pass alone, nothing laid on")
		# `--mist-pass=compute-mask` draws the half pass's edge mask instead of the mist, for its share of texels.
		effect.show_mask = pass_asked_on_the_command_line() == "compute-mask"
		if effect.show_mask:
			print("[mist] the edge mask drawn instead of the mist (--mist-pass=compute-mask)")
	if effect != null:
		var compositor: Compositor = _air.compositor if _air != null and _air.compositor != null else Compositor.new()
		var effects: Array[CompositorEffect] = compositor.compositor_effects
		if want and not effects.has(effect):
			effects.append(effect)
		elif not want and effects.has(effect):
			effects.erase(effect)
		compositor.compositor_effects = effects
		if _air != null:
			_air.compositor = compositor
	_quad.visible = not want
	if want != computing:
		print("[mist] pass %s" % ("compute" if want else "spatial"))
	computing = want
	_handed = false


## Whether the mist is drawn FINE, read off what was written.
func wears_fine() -> bool:
	return float((written.get("mist_stratus_look", Vector4.ZERO) as Vector4).x) > 0.5


## What a mist global was last written as, for the tests; null for one never written.
func mist_written(field: String) -> Variant:
	return written.get(field, null)


## What `--mist=` asked for, lower case, or "" for nothing asked. `off` builds no mist.
static func asked_on_the_command_line() -> String:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() == 2 and parts[0].to_lower() == "mist":
			return parts[1].to_lower()
	return ""


## Whether `--mist-relief=off` asked for no valley pools, for the pictures that tell what the pools add. Never a level's.
static func relief_asked_off() -> bool:
	return "--mist-relief=off" in OS.get_cmdline_user_args()


## HOW MUCH THICKER THE HAZE LIES over ground whose relief is `relief` metres (`MistChart.relief_of`) at a time of day: the
## shader's `mist_pool_at`, for the tests. Static and pure.
static func pool_scale_at(which: int, relief: float) -> float:
	return 1.0 + float(MistTuning.preset(which)["pool_gain"]) * smoothstep(0.0, MistTuning.POOL_DEPTH, -relief)


## Whether `--mist-towns=off` asked for no domes, for the pictures that tell what the domes add.
static func towns_asked_off() -> bool:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() == 2 and parts[0].to_lower() == "mist-towns" and parts[1].to_lower() == "off":
			return true
	return false


## The steps `--mist-steps=` asked for, or -1.
static func steps_asked_on_the_command_line() -> int:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() == 2 and parts[0].to_lower() == "mist-steps" and parts[1].is_valid_int():
			return maxi(parts[1].to_int(), 0)
	return -1


## What `--mist-pass=` asked for, lower case: `fill` for the pricing probe's empty quad; "" for the mist.
static func pass_asked_on_the_command_line() -> String:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() == 2 and parts[0].to_lower() == "mist-pass":
			return parts[1].to_lower()
	return ""


## What `--mist-part=` asked for: `haze` or `stratus` draws that part of the mist alone, for pictures that tell one part's look
## from the other's; `none` keeps the pass drawing with nothing in it, to price the pass itself; "" for both.
static func part_asked_on_the_command_line() -> String:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() == 2 and parts[0].to_lower() == "mist-part":
			return parts[1].to_lower()
	return ""


## A CHART ROUND THIS EYE, NOW: started on a worker and waited for, as the level loads -- a load, not a hitch.
func bake_now(eye: Vector3) -> void:
	_start_bake(MistChart.middle_for(eye))
	WorkerThreadPool.wait_for_task_completion(_task)
	_take_bake()


func _process(delta: float) -> void:
	clock += delta
	RenderingServer.global_shader_parameter_set(&"mist_clock", clock)
	if computing and effect != null:
		# THE NUMBERS ONCE PER CHANGE, THE CLOCK EVERY FRAME, handed by value to the render thread (MistEffect).
		if not _handed and _chart_rd.is_valid() and _towns_rd.is_valid():
			effect.hand(MistEffect.pack(written), _chart_rd, _towns_rd)
			_handed = true
		effect.hand_clock(clock)
	if _task >= 0:
		if WorkerThreadPool.is_task_completed(_task):
			WorkerThreadPool.wait_for_task_completion(_task)
			_take_bake()
		return
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return
	var wanted: Vector3 = MistChart.middle_for(camera.global_position)
	if wanted != chart_middle:
		_start_bake(wanted)


func _start_bake(middle: Vector3) -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_take_bake()
	var into: Dictionary = {}
	_baking = into
	var delay: int = bake_delay_msec
	_task = WorkerThreadPool.add_task(func() -> void:
		if delay > 0:
			OS.delay_msec(delay)
		into.merge(MistChart.bake(middle, MistTuning.CHART_SPAN, MistTuning.CHART_TEXELS, Terrain.surface_heights)))


func _take_bake() -> void:
	_task = -1
	if _baking.is_empty():
		return
	var image: Image = _baking["image"]
	if chart == null:
		chart = ImageTexture.create_from_image(image)
		# A SAMPLER GLOBAL TAKES THE TEXTURE'S RID (material_storage.cpp, global_shader_parameter_set).
		RenderingServer.global_shader_parameter_set(&"mist_ground", chart.get_rid())
		# THE COMPUTE MIST SAMPLES THE SAME CHART through its RenderingDevice texture; null where there is no device.
		if RenderingServer.get_rendering_device() != null:
			_chart_rd = RenderingServer.texture_get_rd_texture(chart.get_rid())
		written["mist_ground"] = chart
		writes += 1
	else:
		chart.update(image)
	_write(&"mist_chart_frame", _baking["frame"])
	_write(&"mist_ground_range", _baking["ground_range"])
	chart_middle = _baking["middle"]
	baked_on_thread = int(_baking["thread"])
	_baking = {}


func _exit_tree() -> void:
	# NO MIST WITH NO LAYER: every density to 0, and the time forgotten so a layer added again writes its numbers again.
	for field in [&"mist_haze", &"mist_stratus"]:
		var packed: Vector4 = written.get(String(field), Vector4.ZERO)
		packed.x = 0.0
		_write(field, packed)
	_dome_density = 0.0
	_write_town()
	_write(&"mist_pool", Vector4(0.0, MistTuning.POOL_DEPTH, 0.0, 0.0))
	time = -1
	_look_n = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)


## HOW DENSE THE MIST IS AT A POINT at a time of day, over ground `ground` metres high, with the noise at its mean: the shader's
## extinction per metre, in GDScript, for the tests. Static and pure.
static func density_at(which: int, point: Vector3, ground: float) -> float:
	var mist: Dictionary = MistTuning.preset(which)
	var above: float = maxf(point.y - ground, 0.0)
	var haze: float = float(mist["haze_density"]) * (1.0 - MistTuning.HAZE_BREAKUP * 0.5) \
		* exp(-above / float(mist["haze_height"]))
	var cover: Vector2 = mist["stratus_cover"]
	var band: float = (above - float(mist["stratus_height"])) / float(mist["stratus_width"])
	var stratus: float = float(mist["stratus_density"]) * smoothstep(cover.x, cover.y, 0.5) * exp(-band * band)
	return haze + stratus


func _write(field: StringName, value: Variant) -> void:
	RenderingServer.global_shader_parameter_set(field, value)
	written[String(field)] = value
	writes += 1
	_handed = false
