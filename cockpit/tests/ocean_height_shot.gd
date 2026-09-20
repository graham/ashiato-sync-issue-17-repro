extends Node
## THE SEA IS DRAWN AT THE HEIGHT THE SIMULATION FLOATS HULLS ON, AND THE PAINTED DETAIL MOVES NO VERTEX -- read off the GPU,
## from each ocean shader's own `vertex()`.
##
##   Godot --path cockpit --xr-mode off --resolution 640x360 res://tests/ocean_height_shot.tscn
##
## NOT HEADLESS: it renders. A PROBE with assertions, run by hand beside the gate (docs.gd PROBES), because the gate is
## headless and a vertex shader only runs on a rendering device.
##
## WHY RENDERED. The only height a hull can be judged against is the simulation's (`swell_height_at`): no hull floats on
## anything drawn, and a drawn wave over a deck the simulation keeps dry reads as a swamped boat (FINE's chop at 0.4 over
## the launch, 2026-09-15). The sea's surface detail (`ocean_detail.gdshaderinc`, 2026-09-15) was to be all normal, roughness
## and colour; a copy of the vertex formula in GDScript would agree with itself whatever the shader did. So this runs the
## shader FILE: its source is read, its `fragment()` cut off and replaced by one that writes the displaced `world_pos.y`,
## and its render mode made unshaded. The vertex code that runs is the file's own, byte for byte; a height added anywhere
## in it is a height read here.
##
## THE HEIGHT IS WHERE THE PIXEL WAS RASTERISED, not the shader's `world_pos` varying: the fine shader works `world_pos` out
## beside `VERTEX` rather than from it, so a height added to `VERTEX` alone moved the sea and left the varying where it was.
## The fragment rebuilds the world position from its view-space `VERTEX` through VIEW_MATRIX, which both builds hand over
## whole (eye.gdshaderinc).
##
## AGAINST THE SWELL AT THE SHEET'S OWN VERTICES. A sheet of 3 m triangles is flat between its corners, and a 150 m swell
## bends away from that by up to a millimetre across a cell's diagonal: the first run read 0.84 mm against a 1 mm bound, the
## mesh's error and not the shader's. So each pixel is held to `swell_height_at` at the three corners of the triangle it lies
## in, interpolated as the rasteriser does, to 0.1 mm; the plain distance to the swell at the pixel is printed beside it.
##
## HOW THE HEIGHT COMES BACK. An orthographic camera looks straight down on a PATCH of SeaSwell's own sheet, handed the swell
## by `SeaSwell.hand_the_swell` and the wind-sea by `WindSea.hand`, in a SubViewport with a 2D HDR buffer, so the colour
## is read back as half floats. Three channels carry the height at 1/16, 1/4 and 1/64 m steps so each resolves the next:
## about 20 µm, far under the millimetre held.
##
## WHAT IS HELD, at four patches far off the island, one in each quadrant, each straddling a line the swell's wrap flips on:
## - PLAIN, and FINE with its chop stilled: every pixel within 1 mm of `swell_height_at` (the sheet's 3 m cells bend a 150 m
##   wave by under half a millimetre between vertices), and the heights rise and fall by more than 0.3 m so a dead sea
##   cannot pass;
## - both, with every wind-sea height ten times over: the same heights to the micrometre;
## - FINE at its own chop: never more than a small boat's freeboard over the simulated swell -- `FREEBOARD`, the launch's
##   0.4 m of deck over the water (agents.md, "Every boat's crew stands where its helm really is") -- and more than a
##   centimetre, so a probe that cannot see the chop cannot pass.
##
## Prints RESULT=PASS, or RESULT=FAIL and the checks that failed.

const PATCH: float = 48.0
const PIXELS: int = 192
const PATCHES: Array[Vector2] = [Vector2(8192.0, 0.0), Vector2(-8192.0, 2048.0), Vector2(10240.0, -6144.0),
	Vector2(-9216.0, -4096.0)]
const FREEBOARD: float = 0.4
## FINE's chop is read at this many moments, this many seconds apart: its longest wave, 70 m, passes in 6.7 s.
const CHOP_MOMENTS: int = 8
const CHOP_GAP: float = 0.9
const SHADERS: Dictionary = {"plain": "res://world/shaders/ocean.gdshader", "fine": "res://world/shaders/ocean_fine.gdshader"}

var _failures: PackedStringArray = []
var _world: Object = null
var _port: SubViewport = null
var _eye: Camera3D = null
var _sheet: MeshInstance3D = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[ocean_height] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_world = ClassDB.instantiate("CockpitWorld")
	_build()
	for finish in ["plain", "fine"]:
		var shader: Shader = _probe_shader(String(SHADERS[finish]))
		var still: bool = finish == "fine"
		var drawn: Array = await _heights(shader, 1.0, 0.0 if still else -1.0)
		var loud: Array = await _heights(shader, 10.0, 0.0 if still else -1.0)
		var worst: float = 0.0
		var direct: float = 0.0
		var low: float = 1.0e9
		var high: float = -1.0e9
		var changed: float = 0.0
		for i in range(drawn.size()):
			var sample: Vector3 = drawn[i]
			worst = maxf(worst, absf(sample.y - _swell_on_the_sheet(sample.x, sample.z)))
			direct = maxf(direct, absf(sample.y - float(_world.swell_height_at(sample.x, sample.z))))
			low = minf(low, sample.y)
			high = maxf(high, sample.y)
			changed = maxf(changed, absf((loud[i] as Vector3).y - sample.y))
		var label: String = finish if not still else "fine_with_its_chop_stilled"
		_check("%s_is_drawn_at_the_simulations_swell" % label, drawn.size() > 0 and worst < 0.0001,
			"%d pixels over %d patches, worst %.6f m off swell_height_at at the sheet's corners (%.5f m off it at the pixel)" % [
				drawn.size(), PATCHES.size(), worst, direct])
		_check("and_%s_rises_and_falls" % label, high - low > 0.3, "%.3f to %.3f m" % [low, high])
		_check("and_on_%s_ten_times_the_wind_sea_moves_no_vertex" % finish, drawn.size() == loud.size() and changed < 0.000005,
			"%.7f m moved at worst" % changed)
		if finish == "fine":
			# OVER TIME, NOT AT ONE MOMENT. The chop travels with TIME, and the four launches that chose its steepness rendered
			# at nearly one moment, so they sampled one crest (agents.md, "FINE'S TRAVELLING CHOP IS CALMED NEAR THE EYE"). Read
			# at CHOP_MOMENTS moments across its longest wave's period, and each moment's worst must differ, so a chop that has
			# stopped cannot pass.
			var over: float = 0.0
			var each := PackedFloat32Array()
			var started: int = Time.get_ticks_msec()
			for moment in range(CHOP_MOMENTS):
				if moment > 0:
					await get_tree().create_timer(CHOP_GAP).timeout
				var worst_now: float = -1.0e9
				for sample in await _heights(shader, 1.0, -1.0):
					worst_now = maxf(worst_now,
						(sample as Vector3).y - float(_world.swell_height_at((sample as Vector3).x, (sample as Vector3).z)))
				each.append(worst_now)
				over = maxf(over, worst_now)
			var spread: float = 0.0
			for a in each:
				for b in each:
					spread = maxf(spread, a - b)
			_check("fines_chop_stays_under_a_small_boats_freeboard", over < FREEBOARD,
				"%.3f m over the simulated swell at worst in %d moments over %.1f s, against %.2f m" % [over, CHOP_MOMENTS,
					float(Time.get_ticks_msec() - started) / 1000.0, FREEBOARD])
			_check("and_the_probe_sees_fines_chop", over > 0.01, "%.3f m" % over)
			_check("and_fines_chop_moves_between_the_moments_read", spread > 0.005,
				"each moment's worst %s m" % [", ".join(Array(each).map(func(v): return "%.3f" % v))])
	_finish()


## THE SHADER FILE WITH ITS FRAGMENT REPLACED: unshaded, and the displaced height in three channels.
func _probe_shader(path: String) -> Shader:
	var source: String = FileAccess.get_file_as_string(path)
	var mode_at: int = source.find("render_mode")
	var mode_end: int = source.find(";", mode_at)
	var fragment_at: int = source.find("void fragment()")
	_check("%s_has_a_render_mode_and_a_fragment_to_replace" % path.get_file(), mode_at >= 0 and fragment_at > mode_end, path)
	var code: String = source.substr(0, mode_at) + "render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled;" \
		+ source.substr(mode_end + 1, fragment_at - mode_end - 1) \
		+ "void fragment() {\n\tvec3 at = transpose(mat3(VIEW_MATRIX)) * (VERTEX - VIEW_MATRIX[3].xyz);\n\tfloat h = at.y + 8.0;\n" \
		+ "\tALBEDO = vec3(h / 16.0, fract(h * 4.0), fract(h * 64.0));\n}\n"
	var shader := Shader.new()
	shader.code = code
	return shader


## A viewport of its own, an orthographic eye looking straight down, and SeaSwell's sheet.
func _build() -> void:
	_port = SubViewport.new()
	_port.size = Vector2i(PIXELS, PIXELS)
	_port.use_hdr_2d = true
	_port.own_world_3d = true
	_port.msaa_3d = Viewport.MSAA_DISABLED
	_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_port)
	var air := WorldEnvironment.new()
	var black := Environment.new()
	black.background_mode = Environment.BG_COLOR
	black.background_color = Color.BLACK
	black.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	air.environment = black
	_port.add_child(air)
	_eye = Camera3D.new()
	_eye.projection = Camera3D.PROJECTION_ORTHOGONAL
	_eye.size = PATCH
	_eye.near = 1.0
	_eye.far = 500.0
	_port.add_child(_eye)
	_sheet = MeshInstance3D.new()
	_sheet.mesh = SeaSwell.sheet()
	_port.add_child(_sheet)


## THE DRAWN HEIGHT AT EVERY PIXEL OF EVERY PATCH, as (x, height, z). `loudness` multiplies the wind-sea's heights;
## `steepness` below zero leaves the shader's own.
func _heights(shader: Shader, loudness: float, steepness: float) -> Array:
	var wet := ShaderMaterial.new()
	wet.shader = shader
	wet.set_shader_parameter("land_half", Terrain.WORLD_HALF)
	wet.set_shader_parameter("wind", Terrain.SWELL_HEADING)
	SeaSwell.hand_the_swell(wet)
	WindSea.hand(wet, WindSea.ships_wind())
	var heights: PackedFloat32Array = wet.get_shader_parameter("wind_sea_height")
	for i in range(heights.size()):
		heights[i] *= loudness
	wet.set_shader_parameter("wind_sea_height", heights)
	if steepness >= 0.0:
		wet.set_shader_parameter("swell_steepness", steepness)
	_sheet.material_override = wet
	var out: Array = []
	for middle in PATCHES:
		_eye.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(middle.x, 200.0, middle.y))
		_sheet.global_position = Vector3(snappedf(middle.x, SeaSwell.CELL), 0.0, snappedf(middle.y, SeaSwell.CELL))
		for i in range(6):
			await RenderingServer.frame_post_draw
		var picture: Image = _port.get_texture().get_image()
		var step: float = PATCH / float(PIXELS)
		for row in range(2, PIXELS - 2, 3):
			for column in range(2, PIXELS - 2, 3):
				var colour: Color = picture.get_pixel(column, row)
				var coarse: float = colour.r * 16.0
				var quarter: float = (roundf(coarse * 4.0 - colour.g) + colour.g) / 4.0
				var fine: float = (roundf(quarter * 64.0 - colour.b) + colour.b) / 64.0
				out.append(Vector3(middle.x + (float(column) + 0.5 - float(PIXELS) * 0.5) * step, fine - 8.0,
					middle.y + (float(row) + 0.5 - float(PIXELS) * 0.5) * step))
	return out


## THE SIMULATION'S SWELL AS THE SHEET CAN CARRY IT: `swell_height_at` at the corners of the triangle (x, z) lies in, mixed
## as the rasteriser mixes them. The sheet's cells near its middle are `SeaSwell.CELL` square, each split from its (i+1, j)
## corner to its (i, j+1) corner (`SeaSwell.sheet`'s index order), and the sheet stands where `_heights` snapped it.
func _swell_on_the_sheet(x: float, z: float) -> float:
	var origin: Vector3 = _sheet.global_position
	var cell: float = SeaSwell.CELL
	var i: float = floor((x - origin.x) / cell)
	var j: float = floor((z - origin.z) / cell)
	var fx: float = (x - origin.x) / cell - i
	var fz: float = (z - origin.z) / cell - j
	var x0: float = origin.x + i * cell
	var z0: float = origin.z + j * cell
	var h10: float = float(_world.swell_height_at(x0 + cell, z0))
	var h01: float = float(_world.swell_height_at(x0, z0 + cell))
	if fx + fz <= 1.0:
		var h00: float = float(_world.swell_height_at(x0, z0))
		return h00 + fx * (h10 - h00) + fz * (h01 - h00)
	var h11: float = float(_world.swell_height_at(x0 + cell, z0 + cell))
	return h11 + (1.0 - fx) * (h01 - h11) + (1.0 - fz) * (h10 - h11)


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit()
