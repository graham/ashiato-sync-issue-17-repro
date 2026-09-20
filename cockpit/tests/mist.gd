extends Node
## Headless: does the low mist lie low, thin with height, change with the time of day, stand on the ground the world says, and
## get its chart baked off the frame?
##
##   Godot --headless --path cockpit res://tests/mist.tscn
##
## WHAT HEADLESS CAN AND CANNOT SAY. A picture of mist is for eyes (tests/scenery_shot.gd, the mist views). What a suite holds is
## the arithmetic the shader draws with -- `MistLayer.density_at`, the same bands with the noise at its mean -- the numbers the
## LEVEL puts on the mist material through its own `choose_time`, the chart against the ground function it was handed, and the
## thread a chart was baked on.
##
## Read RESULT=, not the exit code.

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[mist] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_the_mist_lies_low_and_thins_with_height_at_every_time_of_day()
	_the_chart_is_the_ground_it_is_handed()
	_the_chart_holds_the_valleys_below_their_surroundings()
	await _a_chart_is_baked_off_the_frame()
	await _the_level_puts_each_times_mist_on_the_material()
	_the_compute_mist_draws_on_plain_only()
	_the_compute_mist_packs_every_number_where_its_shader_reads_it()
	_each_eye_gets_its_own_projection()
	_a_resized_views_framebuffers_are_let_go()
	_the_domes_lie_over_the_towns_and_thin_with_height()
	_the_glow_is_the_windows_light_and_none_by_day()
	_the_shader_reads_as_many_towns_as_the_layer_writes()
	_the_haze_pools_in_the_valleys_and_nowhere_else()
	_finish()


## THE COMPUTE MIST ON PLAIN, THE SPATIAL PASS ON FINE (step 2c): compute where there is a RenderingDevice and the finish is PLAIN,
## never on FINE (MSAA: MistEffect's header), never without a device, and never when a probe asks for the spatial pass or its fill.
func _the_compute_mist_draws_on_plain_only() -> void:
	var wrong: Array[String] = []
	for case in [[false, true, "", MistTuning.COMPUTE_ON_PLAIN], [true, true, "", false], [false, false, "", false],
			[false, true, "spatial", false], [false, true, "fill", false], [false, true, "edges", false], [true, true, "compute", false], [false, true, "compute", true],
				[false, true, "compute-half", true], [true, true, "compute-half", false],
				[false, true, "compute-mask", true], [true, true, "compute-mask", false]]:
		if MistLayer.computes(case[0], case[1], case[2]) != case[3]:
			wrong.append("fine %s, device %s, asked '%s'" % [case[0], case[1], case[2]])
	_check("and_the_compute_mist_draws_on_plain_only", wrong.is_empty(), "%s" % [wrong])


## A RESIZED VIEW'S FRAMEBUFFERS ARE LET GO (team-lead, 2026-09-15): the lay-on keeps a framebuffer per colour texture, and a
## resize, a finish change or a headset hands the views new textures. After a frame that drew into the new ones, every old
## framebuffer is to be let go and every one drawn into kept; a frame that drew into nothing (the half-pass probe) lets all go.
## Keys stand in for colour RIDs: there is no RenderingDevice headless.
func _a_resized_views_framebuffers_are_let_go() -> void:
	var cache := {"old_left": "fb1", "old_right": "fb2", "new_left": "fb3", "new_right": "fb4"}
	var gone: Array = MistEffect.framebuffers_to_let_go(cache, ["new_left", "new_right"])
	gone.sort()
	var kept_all: Array = MistEffect.framebuffers_to_let_go(cache, cache.keys())
	var nothing_drawn: Array = MistEffect.framebuffers_to_let_go(cache, [])
	_check("and_a_resized_views_framebuffers_are_let_go", gone == ["old_left", "old_right"] and kept_all.is_empty()
		and nothing_drawn.size() == 4, "let go after a resize %s, with nothing new %s, with nothing drawn %d" % [gone, kept_all, nothing_drawn.size()])


## EVERY NUMBER WHERE THE COMPUTE SHADER READS IT: `MistEffect.pack` of a written set whose every number is different comes out
## in mist_half.glsl's order, and that order is READ FROM THE SHADER'S OWN Params block, so reordering either one fails here.
func _the_compute_mist_packs_every_number_where_its_shader_reads_it() -> void:
	var written := {"mist_haze": Vector4(1, 2, 3, 4), "mist_stratus": Vector4(5, 6, 7, 8), "mist_stratus_look": Vector4(9, 10, 11, 12),
		"mist_colour": Color(13, 14, 15, 16), "mist_sun_colour": Color(17, 18, 19, 20), "mist_towards_sun": Vector3(21, 22, 23),
		"mist_steps": 24, "mist_sun": Vector3(25, 26, 27), "mist_chart_frame": Vector4(29, 30, 31, 32),
		"mist_ground_range": Vector2(33, 34), "mist_ceiling": 35.0, "mist_reach": 36.0, "mist_stratus_cover": Vector2(37, 38),
		"mist_town": Vector4(41, 42, 43, 44), "mist_town_glow": Vector3(45, 46, 47), "mist_pool": Vector4(49, 50, 51, 52)}
	var packed: PackedFloat32Array = MistEffect.pack(written)
	var wanted: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 0,
		29, 30, 31, 32, 33, 34, 35, 36, 37, 38, MistTuning.SKY_REACH, MistTuning.COMPUTE_EDGE, 41, 42, 43, 44, 45, 46, 47, 0, 49, 50, 51, 52]
	var off: Array[int] = []
	for i in range(mini(packed.size(), wanted.size())):
		if not is_equal_approx(packed[i], float(wanted[i])):
			off.append(i)
	var code: String = FileAccess.get_file_as_string("res://world/shaders/mist_half.glsl")
	var from: int = code.find("uniform Params {")
	var block: String = code.substr(from, code.find("} params;") - from)
	var order: Array[String] = ["vec4 haze;", "vec4 stratus;", "vec4 stratus_look;", "vec4 colour;", "vec4 sun_colour;",
		"vec4 towards_sun_steps;", "vec4 sun_clock;", "vec4 chart_frame;", "vec4 ground_ceiling_reach;", "vec4 cover_sky;",
		"vec4 town;", "vec4 town_glow;", "vec4 pool;", "vec4 eye;",
		"mat4 to_world;"]
	var at: int = -1
	var out_of_order: Array[String] = []
	for field in order:
		var found: int = block.find(field)
		if found <= at:
			out_of_order.append(field)
		at = found
	_check("and_the_compute_mist_packs_every_number_where_its_shader_reads_it",
		packed.size() == MistEffect.NUMBERS and off.is_empty() and out_of_order.is_empty() and MistEffect.CLOCK_AT == 27,
		"%d numbers, wrong at %s, shader fields out of order %s" % [packed.size(), off, out_of_order])


## EACH EYE ITS OWN PROJECTION (team-lead's multiview check): handed a frame's scene data with two views whose projections differ
## by the eyes' offset, `MistEffect.view_constants` packs each view's own inverse and not the other's, and the camera goes in
## centred and whole.
class TwoEyes:
	var left := Projection.create_perspective_hmd(90.0, 1.0, 0.05, 20000.0, false, 1, 0.064, 1.5)
	var right := Projection.create_perspective_hmd(90.0, 1.0, 0.05, 20000.0, false, 2, 0.064, 1.5)

	func get_view_projection(view: int) -> Projection:
		return left if view == 0 else right


func _each_eye_gets_its_own_projection() -> void:
	var eyes := TwoEyes.new()
	var full := Vector2i(2890, 3091)
	var half := Vector2i(1445, 1546)
	var first: PackedFloat32Array = MistEffect.view_constants(eyes, 0, full, half)
	var second: PackedFloat32Array = MistEffect.view_constants(eyes, 1, full, half)
	var own: bool = true
	for view in [[first, eyes.left], [second, eyes.right]]:
		var inverse: Projection = (view[1] as Projection).inverse()
		for column in range(4):
			for row in range(4):
				if not is_equal_approx((view[0] as PackedFloat32Array)[column * 4 + row], inverse[column][row]):
					own = false
	var camera := Transform3D(Basis(Vector3.UP, 0.7), Vector3(12000.0, 300.0, -4000.0))
	var packed: PackedFloat32Array = MistEffect.camera_constants(camera)
	var camera_ok: bool = packed.size() == 20 and is_equal_approx(packed[0], 12000.0) and is_equal_approx(packed[4], camera.basis.x.x) \
		and is_equal_approx(packed[10], camera.basis.y.z) and is_equal_approx(packed[19], 1.0)
	_check("and_each_eye_gets_its_own_projection", first != second and own and first.size() == 20 and
		is_equal_approx(first[16], 2890.0) and is_equal_approx(first[19], 1546.0) and camera_ok,
		"views differ %s, each its own inverse %s, camera %s" % [first != second, own, camera_ok])


## LOW AND THIN WITH HEIGHT, AND NEVER NONE. At every time of day, over the ground: denser two metres up than sixty, sixty than
## a stratus band's top over it, and next to nothing over the ceiling; the ground haze thicker at the low sun (EVENING, which
## stands for dawn and dusk) than by day; and some mist at every time.
func _the_mist_lies_low_and_thins_with_height_at_every_time_of_day() -> void:
	var ground: float = 37.0
	var at := Vector2(1200.0, -800.0)
	var wrong: Array[String] = []
	var none: Array[String] = []
	for time in range(DaylightTuning.When.size()):
		var mist: Dictionary = MistTuning.preset(time)
		var over_band: float = float(mist["stratus_height"]) + float(mist["stratus_width"]) * 3.0
		var low: float = MistLayer.density_at(time, Vector3(at.x, ground + 2.0, at.y), ground)
		var sixty: float = MistLayer.density_at(time, Vector3(at.x, ground + 60.0, at.y), ground)
		var over: float = MistLayer.density_at(time, Vector3(at.x, ground + over_band, at.y), ground)
		var ceiling: float = MistLayer.density_at(time, Vector3(at.x, ground + MistTuning.CEILING, at.y), ground)
		if not (low > sixty and sixty > over and ceiling < low * 0.001):
			wrong.append("%s: 2 m %.6f, 60 m %.6f, over the band %.6f, ceiling %.8f" % [DaylightTuning.name_of(time), low, sixty,
				over, ceiling])
		if low <= 0.0:
			none.append(DaylightTuning.name_of(time))
	_check("and_the_mist_falls_with_height_at_every_time_of_day", wrong.is_empty(), "%s" % [wrong])
	_check("and_there_is_mist_at_every_time_of_day", none.is_empty(), "none at %s" % [none])
	var noon: float = MistLayer.density_at(DaylightTuning.When.DAY, Vector3(at.x, ground + 2.0, at.y), ground)
	var dawn: float = MistLayer.density_at(DaylightTuning.When.EVENING, Vector3(at.x, ground + 2.0, at.y), ground)
	_check("and_day_is_thinner_than_the_low_sun", noon < dawn, "day %.6f, evening %.6f" % [noon, dawn])


## THE CHART IS THE GROUND IT IS HANDED: a slope going up 0.05 m a metre eastwards and 0.02 northwards comes back texel for texel
## at the texels' own middles, and so do its lowest and highest.
func _the_chart_is_the_ground_it_is_handed() -> void:
	var slope := func(p: Vector3) -> float: return 20.0 + p.x * 0.05 + p.z * 0.02
	# HANDED IN `Terrain.surface_heights`' SHAPE: texel centres, rows along z, index j * texels + i.
	var slope_grid := func(corner: Vector2, texels: int, spacing: float) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		for j in range(texels):
			for i in range(texels):
				out.append(slope.call(Vector3(corner.x + (float(i) + 0.5) * spacing, 0.0, corner.y + (float(j) + 0.5) * spacing)))
		return out
	var middle := Vector3(4096.0, 0.0, -8192.0)
	var baked: Dictionary = MistChart.bake(middle, 2048.0, 16, slope_grid)
	var image: Image = baked["image"]
	var frame: Vector4 = baked["frame"]
	var off: int = 0
	var worst: float = 0.0
	for j in range(16):
		for i in range(16):
			var at := Vector3(frame.x + (float(i) + 0.5) * 128.0, 0.0, frame.y + (float(j) + 0.5) * 128.0)
			var miss: float = absf(image.get_pixel(i, j).r - float(slope.call(at)))
			worst = maxf(worst, miss)
			if miss > 0.01:
				off += 1
	var range_seen: Vector2 = baked["ground_range"]
	_check("and_the_chart_is_the_ground_it_was_handed", off == 0 and absf(range_seen.y - range_seen.x - 0.07 * 1920.0) < 0.1,
		"%d of 256 texels off (worst %.3f m), range %s" % [off, worst, range_seen])


## OFF THE FRAME: with every bake slowed to 300 ms by the layer's own seam, an eye that flies to a new chart's worth of ground
## is given a new chart by a worker, no frame of the layer waits for it, and the thread it was baked on is not the main thread.
func _a_chart_is_baked_off_the_frame() -> void:
	var layer := MistLayer.new()
	add_child(layer)
	var eye := Camera3D.new()
	add_child(eye)
	eye.current = true
	layer.bake_now(Vector3.ZERO)
	var first: Vector3 = layer.chart_middle
	layer.bake_delay_msec = 300
	eye.global_position = Vector3(MistTuning.CHART_RECENTRE * 3.0, 500.0, 0.0)
	var slowest_usec: int = 0
	var frames: int = 0
	var began: int = Time.get_ticks_msec()
	while layer.chart_middle == first and Time.get_ticks_msec() - began < 5000:
		var t: int = Time.get_ticks_usec()
		layer._process(0.016)
		slowest_usec = maxi(slowest_usec, Time.get_ticks_usec() - t)
		frames += 1
		await get_tree().process_frame
	_check("and_a_new_chart_arrives_when_the_eye_flies_off_the_old_one", layer.chart_middle == MistChart.middle_for(eye.global_position),
		"middle %s, wanted %s, after %d frames" % [layer.chart_middle, MistChart.middle_for(eye.global_position), frames])
	_check("and_no_frame_waits_for_it", slowest_usec < 100000, "slowest frame of the layer %d us against a 300 ms bake" % slowest_usec)
	_check("and_it_was_baked_off_the_main_thread", layer.baked_on_thread >= 0 and layer.baked_on_thread != OS.get_main_thread_id(),
		"baked on %d, main %d" % [layer.baked_on_thread, OS.get_main_thread_id()])
	layer.queue_free()
	eye.queue_free()


## THROUGH THE LEVEL'S OWN `choose_time`, the call the clipboard's TIME tab lands on: each time of day's numbers on the mist's
## material, the sun the daylight names, and a still level writing nothing more.
func _the_level_puts_each_times_mist_on_the_material() -> void:
	var level := (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	if level.mist == null:
		_check("there_is_a_mist_in_the_level", false, "no MistLayer")
		level.queue_free()
		return
	var wrong: Array[String] = []
	for time in range(DaylightTuning.When.size()):
		level.choose_time(time)
		var mist: Dictionary = MistTuning.preset(time)
		# PACKED IN THE GLOBALS: `mist_haze` is (density, height, breakup, scale), `mist_stratus` (density, height, width, scale).
		var haze: Vector4 = level.mist.mist_written("mist_haze")
		var stratus: Vector4 = level.mist.mist_written("mist_stratus")
		var said: Dictionary = {"haze_density": haze.x, "haze_height": haze.y, "stratus_density": stratus.x,
			"stratus_height": stratus.y}
		for field in said:
			if not is_equal_approx(float(said[field]), float(mist[field])):
				wrong.append("%s %s %s against %s" % [DaylightTuning.name_of(time), field, said[field], mist[field]])
		if not (level.mist.mist_written("mist_towards_sun") as Vector3).is_equal_approx(DaylightTuning.towards_the_sun(time)):
			wrong.append("%s sun" % DaylightTuning.name_of(time))
		# THE GLOW IS WHAT THE TOWN IS LIGHTING, asked of the town's own material rather than of `MistLayer.town_glow`, which is
		# what the level writes it with: taking `windows_lit` out of that function left this and the glow check green (team-lead's
		# mutants, 2026-09-15). A lit window's colour, times the share of windows TownView's materials light, times the glow
		# the level hands them with it, times TOWN_GLOW.
		var lit: Array[float] = level.towns.windows_lit() if level.towns != null else []
		if lit.is_empty() or lit.min() != lit.max():
			wrong.append("%s towns lighting %s" % [DaylightTuning.name_of(time), lit])
		else:
			var light: Color = TownTuning.PLAIN_WINDOW_LIGHT
			var share: float = lit[0] * float(DaylightTuning.preset(time)["window_glow"]) * MistTuning.TOWN_GLOW
			var shown := Vector3(light.r, light.g, light.b) * share
			if not (level.mist.mist_written("mist_town_glow") as Vector3).is_equal_approx(shown):
				wrong.append("%s town glow %s, not the lit windows' %s" % [DaylightTuning.name_of(time),
					level.mist.mist_written("mist_town_glow"), shown])
		if not is_equal_approx((level.mist.mist_written("mist_pool") as Vector4).x, float(mist["pool_gain"])):
			wrong.append("%s pool gain %s, not the preset's %s" % [DaylightTuning.name_of(time), level.mist.mist_written("mist_pool"),
				mist["pool_gain"]])
		if not (level.mist.mist_written("mist_colour") as Color).is_equal_approx(DaylightTuning.preset(time)["sky_horizon"]):
			wrong.append("%s colour %s, not the horizon sky's" % [DaylightTuning.name_of(time), level.mist.mist_written("mist_colour")])
	_check("and_the_level_puts_each_times_mist_on_the_material", wrong.is_empty(), "%s" % [wrong])
	var writes: int = level.mist.writes
	for i in range(60):
		await get_tree().process_frame
	_check("and_a_still_level_writes_no_mist", level.mist.writes == writes, "%d writes in 60 frames" % (level.mist.writes - writes))
	level.queue_free()
	await get_tree().process_frame


## THE DOMES LIE OVER THE TOWNS (step 3): at every time of day, over a town 400 m across standing at 20 m, the dome is denser
## 20 m over its middle than 5 km out at the same height, denser at 20 m than 400 m up, and there at every time. AND THE SHADER
## TAKES IT, held by the shader's STRUCTURE (headless draws nothing): `mist_dome_tau` sums the term `dome_density_at` mirrors
## (the Gaussian across, times the height's fall from the town's own ground), assigns its sum nowhere else and returns it; and
## `mist_along` takes `m_dome_tau` from `mist_dome_tau` alone, assigns it nowhere else, and adds it to the extinction once.
## Reading only the GDScript mirror, zeroing the dome in mist_core left this green; a bare substring then survived a zero
## assigned before the add and a zero returned from the sum (team-lead's mutants, 2026-09-15).
func _the_domes_lie_over_the_towns_and_thin_with_height() -> void:
	var core: String = FileAccess.get_file_as_string("res://world/shaders/mist_core.gdshaderinc").replace("\r\n", "\n")
	var shader: Array[String] = _the_shader_takes_the_dome(core)
	var towns: Array = [{"centre": Vector3(1000.0, 20.0, -2000.0), "radius": 400.0}]
	var wrong: Array[String] = []
	for time in range(DaylightTuning.When.size()):
		var over: float = MistLayer.dome_density_at(time, Vector3(1000.0, 40.0, -2000.0), towns)
		var out: float = MistLayer.dome_density_at(time, Vector3(6000.0, 40.0, -2000.0), towns)
		var high: float = MistLayer.dome_density_at(time, Vector3(1000.0, 420.0, -2000.0), towns)
		if not (over > 0.0 and over > out * 1000.0 and over > high * 10.0):
			wrong.append("%s: over %.8f, 5 km out %.10f, 400 m up %.8f" % [DaylightTuning.name_of(time), over, out, high])
	_check("and_the_domes_lie_over_the_towns_and_thin_with_height", wrong.is_empty() and shader.is_empty(),
		"%s; the shader %s" % [wrong, shader])


## WHAT IS WRONG WITH HOW mist_core TAKES THE DOME, in words; empty when nothing is. A function's body is its text from its
## signature to the first `}` at the start of a line.
static func _the_shader_takes_the_dome(core: String) -> Array[String]:
	var wrong: Array[String] = []
	var dome: String = _body_of(core, "float mist_dome_tau(")
	var along: String = _body_of(core, "vec4 mist_along(")
	if dome == "" or along == "":
		return ["has no mist_dome_tau or no mist_along"]
	var term: String = "m_sum += mist_town.y * exp(-m_off * m_off) * mist_exp_integral("
	if dome.count(term) != 1:
		wrong.append("mist_dome_tau sums the dome term %d times" % dome.count(term))
	if _assignments(dome, "m_sum") != 2:
		wrong.append("mist_dome_tau assigns m_sum %d times, not its start and the term" % _assignments(dome, "m_sum"))
	if dome.count("return") != 1 or dome.count("return m_sum;") != 1:
		wrong.append("mist_dome_tau does not return its sum alone")
	if along.count("float m_dome_tau = mist_town.y > 0.0 ? mist_dome_tau(m_eye, m_dir, m_ta, m_tb) : 0.0;") != 1:
		wrong.append("mist_along does not take m_dome_tau from mist_dome_tau")
	if _assignments(along, "m_dome_tau") != 1:
		wrong.append("mist_along assigns m_dome_tau %d times" % _assignments(along, "m_dome_tau"))
	if along.count("m_tau += m_dome_tau;") != 1:
		wrong.append("mist_along adds m_dome_tau to the extinction %d times" % along.count("m_tau += m_dome_tau;"))
	return wrong


static func _body_of(code: String, signature: String) -> String:
	var from: int = code.find(signature)
	if from < 0:
		return ""
	var until: int = code.find("\n}", from)
	return code.substr(from, until - from) if until > from else ""


## How many times `name` is assigned in `code`: `=`, `+=`, `-=`, `*=` or `/=`, never `==`.
static func _assignments(code: String, name: String) -> int:
	var pattern := RegEx.new()
	pattern.compile("\\b%s\\s*[-+*/]?=(?!=)" % name)
	return pattern.search_all(code).size()


## THE GLOW IS THE WINDOWS' LIGHT (step 3): none by day, some at night, the colour of a lit window, and the level writes the same.
func _the_glow_is_the_windows_light_and_none_by_day() -> void:
	var day: Vector3 = MistLayer.town_glow(DaylightTuning.When.DAY)
	var night: Vector3 = MistLayer.town_glow(DaylightTuning.When.NIGHT)
	var light: Color = TownTuning.PLAIN_WINDOW_LIGHT
	var shade: Vector3 = night / maxf(night.x, 1e-9)
	_check("and_the_glow_is_the_windows_light_and_none_by_day", day.is_zero_approx() and night.x > 0.0
		and shade.is_equal_approx(Vector3(1.0, light.g / light.r, light.b / light.r)) and not TownTuning.STREET_LIGHTS_ON,
		"day %s, night %s, street lights on %s" % [day, night, TownTuning.STREET_LIGHTS_ON])


## AS MANY TOWNS AS THE LAYER WRITES: the shader's `M_MOST_TOWNS` (mist_core.gdshaderinc) is `MistTuning.MOST_TOWNS`, read from the
## shader's own text, and the texture the layer writes is that many texels wide.
func _the_shader_reads_as_many_towns_as_the_layer_writes() -> void:
	var code: String = FileAccess.get_file_as_string("res://world/shaders/mist_core.gdshaderinc")
	var said: String = "const int M_MOST_TOWNS = %d;" % MistTuning.MOST_TOWNS
	var layer := MistLayer.new()
	layer.show_towns([{"centre": Vector3(1.0, 2.0, 3.0), "radius": 4.0}])
	var width: int = layer.towns_texture.get_width() if layer.towns_texture != null else -1
	var town: Vector4 = layer.mist_written("mist_town")
	_check("and_the_shader_reads_as_many_towns_as_the_layer_writes", code.contains(said) and width == MistTuning.MOST_TOWNS
		and int(town.x) == 1, "shader says it %s, texture %d wide, count %d" % [code.contains(said), width, int(town.x)])
	layer.free()


## THE CHART HOLDS THE VALLEYS BELOW THEIR SURROUNDINGS (step 4): handed ground at 100 m with a pit 150 m deep 9 km west of the
## middle and a ridge 150 m high 9 km east, at 128 m a texel as the level's charts are, the chart's relief (its green) is
## well below zero on the pit's floor, well above on the ridge's crest, and zero on the flat between them and in a corner; a flat
## hands no relief anywhere; and the chart is RGF, the format MistLayer's texture keeps for every later chart.
## FAR APART ON PURPOSE: the blur reaches four times RELIEF_TEXELS texels each way, and a pit inside that reach of the middle
## would lift the flat between them; `reach_clear` says so if a wider blur is ever tuned in.
func _the_chart_holds_the_valleys_below_their_surroundings() -> void:
	var reach_clear: bool = 4.0 * float(MistTuning.RELIEF_TEXELS) * 128.0 + 1600.0 < 9000.0
	var image: Image = MistChart.bake(Vector3.ZERO, 32768.0, 256, _grid_of(_pit_and_ridge))["image"]
	var pit_floor: float = image.get_pixel(57, 128).g
	var ridge_crest: float = image.get_pixel(198, 128).g
	var between: float = image.get_pixel(128, 128).g
	var corner: float = image.get_pixel(0, 0).g
	var flat: Image = MistChart.bake(Vector3.ZERO, 32768.0, 256, _grid_of(_flat_ground))["image"]
	var flat_worst: float = 0.0
	for j in range(256):
		for i in range(256):
			flat_worst = maxf(flat_worst, absf(flat.get_pixel(i, j).g))
	_check("and_the_chart_holds_the_valleys_below_their_surroundings", reach_clear and image.get_format() == Image.FORMAT_RGF
		and pit_floor < -40.0 and ridge_crest > 40.0 and absf(between) < 0.5 and absf(corner) < 0.5 and flat_worst < 0.001,
		"format %d, pit floor %.1f m, ridge crest %.1f, between %.2f, corner %.2f, a flat's worst %.4f" % [image.get_format(),
			pit_floor, ridge_crest, between, corner, flat_worst])


func _pit_and_ridge(p: Vector2) -> float:
	var pit: float = 150.0 * exp(-(p - Vector2(-9000.0, 0.0)).length_squared() / (400.0 * 400.0))
	var ridge: float = 150.0 * exp(-pow(p.x - 9000.0, 2.0) / (300.0 * 300.0))
	return 100.0 - pit + ridge


func _flat_ground(_p: Vector2) -> float:
	return 100.0


## A GROUND FUNCTION OF A POINT IN PLAN, as `Terrain.surface_heights`' bulk shape: texel centres, rows along z, j * texels + i.
func _grid_of(ground: Callable) -> Callable:
	return func(corner: Vector2, texels: int, spacing: float) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		for j in range(texels):
			for i in range(texels):
				out.append(float(ground.call(Vector2(corner.x + (float(i) + 0.5) * spacing, corner.y + (float(j) + 0.5) * spacing))))
		return out


## THE HAZE POOLS IN THE VALLEYS AND NOWHERE ELSE (step 4): at every time of day the haze over ground `POOL_DEPTH` below its
## surroundings is thicker than over a flat, over a ridge it is a flat's, and night's pool is the deepest and day's the
## shallowest. AND THE SHADER TAKES IT, held by its structure (headless draws nothing; the domes' lesson): `mist_chart_at` reads
## the relief with the height, `mist_pool_at` is one plus the gain over the relief below zero, and each of mist_along's two haze
## halves multiplies its density by the pool read at the same lower end its ground is.
func _the_haze_pools_in_the_valleys_and_nowhere_else() -> void:
	var core: String = FileAccess.get_file_as_string("res://world/shaders/mist_core.gdshaderinc").replace("\r\n", "\n")
	var shader: Array[String] = _the_shader_pools_the_haze(core)
	var wrong: Array[String] = []
	var valleys: Array[float] = []
	for time in range(DaylightTuning.When.size()):
		var valley: float = MistLayer.pool_scale_at(time, -MistTuning.POOL_DEPTH)
		var flat: float = MistLayer.pool_scale_at(time, 0.0)
		var ridge: float = MistLayer.pool_scale_at(time, 80.0)
		if not (valley > 1.2 and is_equal_approx(flat, 1.0) and is_equal_approx(ridge, 1.0)):
			wrong.append("%s: valley %.3f, flat %.3f, ridge %.3f" % [DaylightTuning.name_of(time), valley, flat, ridge])
		valleys.append(valley)
	var ordered: bool = valleys[DaylightTuning.When.DAY] < valleys[DaylightTuning.When.EVENING] \
		and valleys[DaylightTuning.When.EVENING] < valleys[DaylightTuning.When.NIGHT]
	_check("and_the_haze_pools_in_the_valleys_and_nowhere_else", wrong.is_empty() and ordered and shader.is_empty(),
		"%s; day < evening < night %s %s; the shader %s" % [wrong, ordered, valleys, shader])


## WHAT IS WRONG WITH HOW mist_core POOLS THE HAZE, in words; empty when nothing is.
static func _the_shader_pools_the_haze(core: String) -> Array[String]:
	var wrong: Array[String] = []
	var chart: String = _body_of(core, "vec2 mist_chart_at(")
	var pool: String = _body_of(core, "float mist_pool_at(")
	var along: String = _body_of(core, "vec4 mist_along(")
	if chart == "" or pool == "" or along == "":
		return ["has no mist_chart_at, mist_pool_at or mist_along"]
	if chart.count("return textureLod(mist_ground, m_uv, 0.0).rg;") != 1:
		wrong.append("mist_chart_at does not read the height and the relief together")
	if pool.count("return") != 1 or pool.count("return 1.0 + mist_pool.x * smoothstep(0.0, max(mist_pool.y, 1.0), -m_relief);") != 1:
		wrong.append("mist_pool_at is not one plus the gain over the relief below zero")
	for name in ["m_chart_a", "m_chart_b", "m_chart_m", "m_near_pool", "m_far_pool"]:
		if _assignments(along, name) != 1:
			wrong.append("mist_along assigns %s %d times" % [name, _assignments(along, name)])
	for line in ["vec2 m_chart_a = mist_chart_at(m_a.xz);", "vec2 m_chart_b = mist_chart_at(m_b.xz);",
			"float m_ground_a = m_chart_a.x;", "float m_ground_b = m_chart_b.x;", "float m_ground_m = m_chart_m.x;",
			"float m_near_pool = mist_pool_at(m_ground_a <= m_ground_m ? m_chart_a.y : m_chart_m.y);",
			"float m_far_pool = mist_pool_at(m_ground_m <= m_ground_b ? m_chart_m.y : m_chart_b.y);",
			"m_tau += mist_haze.x * m_near_pool * (1.0 - mist_haze.z * m_breakup_a) * mist_exp_integral(m_ya, m_ym, m_half, m_near_ground, m_haze_height);",
			"m_tau += mist_haze.x * m_far_pool * (1.0 - mist_haze.z * m_breakup_b) * mist_exp_integral(m_ym, m_yb, m_half, m_far_ground, m_haze_height);"]:
		if along.count(line) != 1:
			wrong.append("mist_along lacks: %s" % line)
	return wrong


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
