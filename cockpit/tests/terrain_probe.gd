extends Node
## WHAT A GROUND MADE OF A FUNCTION COSTS, AND WHETHER EVERY MACHINE BUILDS THE SAME ONE. A probe for the terrain
## design (godotgames-drafts/2026-09-14/cockpit-terrain/report.md), not a suite.
##
##   Godot --headless --path cockpit res://tests/terrain_probe.tscn -- --parts=bits,time,map,cracks --out=C:/somewhere
##   Godot --path cockpit res://tests/terrain_probe.tscn -- --level=watch --parts=patch --out=C:/somewhere
##
## - `bits`: checks the extension's `GroundField` configured from `GroundTuning`, then hashes the heights and water at a
##   fixed set of points (a 97 by 97 lattice over the 64 km square, both sides of zero, and every lake and site centre)
##   and the lake and site catalogue. Run on the stock and the double editor; the C++ copy prints the same hash.
## - `time`: microseconds a sample in GDScript, for the question "can the game layer build the collision".
## - `map`: the whole world at 128 m as a shaded picture, `world_map.png`, lakes blue, towns red, airfields yellow.
## - `cracks`: the largest gap a cell edge opens between one grid spacing and the next, which a skirt has to cover.
## - `patch`: WINDOWED. The real level, its flat ground, rock, towns and woods hidden, and cells of terrain drawn round
##   a place with a level of detail by ring, photographed from 300 m and 3 km on both finishes beside today's island
##   from the same heights, with draws, primitives and the time each cell's mesh took.

const CELL: int = 1024
## The world the probe draws: the game's own ground tuning, through the C++ field.
const WORLD_HALF: int = GroundTuning.WORLD_HALF

var _out: String = "user://terrain_probe"
var _parts: PackedStringArray = ["bits", "time"]
var _failures: PackedStringArray = []
var ground: Ground = null


## THE C++ GROUND IN THE SKETCH'S SHAPE: `height_ticks`, `water_ticks`, and the catalogue as `lakes` keyed by cell,
## `towns` and `airfields`, so the parts below read as they did when the ground was `tests/ground_sketch.gd` -- deleted
## once `tests/ground_field.gd` held the C++ to the sketch's hashes on both editors (2026-09-14).
class Ground:
	var field: Object = null
	var lakes: Dictionary = {}
	var towns: Array = []
	var airfields: Array = []

	func _init(values: Dictionary) -> void:
		field = ClassDB.instantiate("GroundField")
		var problems: PackedStringArray = field.call("configure", values)
		if not problems.is_empty():
			push_error("[terrain] the ground refused its tuning: %s" % problems)
		var catalogue: Dictionary = field.call("catalogue")
		for lake in catalogue.get("lakes", []):
			lakes[lake["cell"]] = lake
		towns = catalogue.get("towns", [])
		airfields = catalogue.get("airfields", [])

	func height_ticks(x: int, z: int) -> int:
		return field.call("height_ticks_at", x, z)

	func water_ticks(x: int, z: int) -> int:
		return field.call("water_ticks_at", x, z)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--parts="):
			_parts = argument.get_slice("=", 1).split(",")
		elif argument.begins_with("--out="):
			_out = argument.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	print("[terrain] engine %s, double=%s" % [Engine.get_version_info()["string"],
		str(OS.has_feature("double"))])
	var began: int = Time.get_ticks_usec()
	ground = Ground.new(GroundTuning.values())
	print("[terrain] catalogue: %d lakes, %d towns, %d airfields in %.0f ms" % [ground.lakes.size(),
		ground.towns.size(), ground.airfields.size(), float(Time.get_ticks_usec() - began) / 1000.0])
	for part in _parts:
		match part:
			"bits": _bits()
			"time": _time()
			"map": _map()
			"cracks": _cracks()
			"patch": await _patch()
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(label: String, ok: bool, detail: String) -> void:
	print("  [%s] %s: %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## ---- bits ------------------------------------------------------------------------------------------------------

## The fixed points every copy of the function is asked about, in order.
func points() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in range(97):
		for j in range(97):
			out.append(-32000 + i * 667)
			out.append(-31990 + j * 659)
	for x in [-17, -16, -15, -1, 0, 1, 15, 16, 17, 4095, 4096, -4096, -4097, 65535, -65536]:
		for z in [-1, 0, 1, -4097, 4096]:
			out.append(x)
			out.append(z)
	for key in _sorted(ground.lakes.keys()):
		var lake: Dictionary = ground.lakes[key]
		for d in [0, 150, 333, 600]:
			out.append(int(lake["x"]) + d)
			out.append(int(lake["z"]) - d / 2)
	for site in ground.towns + ground.airfields:
		for d in [0, 200, 450, 700, 1000]:
			out.append(int(site["x"]) - d)
			out.append(int(site["z"]) + d)
	return out


static func _sorted(keys: Array) -> Array:
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return keys


func _bits() -> void:
	# The ground is the extension's now; the hashes below are what `tests/ground_field.gd` holds it to.
	_check("the_ground_is_the_extensions", ground.field != null and bool(ground.field.call("is_configured")),
		"GroundField configured with %s" % GroundTuning.values())
	var at: PackedInt32Array = points()
	var heights := PackedInt32Array()
	var water := PackedInt32Array()
	for k in range(0, at.size(), 2):
		heights.append(ground.height_ticks(at[k], at[k + 1]))
		water.append(ground.water_ticks(at[k], at[k + 1]))
	var catalogue := PackedInt32Array()
	for key in _sorted(ground.lakes.keys()):
		var lake: Dictionary = ground.lakes[key]
		catalogue.append_array([key.x, key.y, lake["x"], lake["z"], lake["r"], lake["depth"], lake["level"], lake["salt"]])
	for site in ground.towns:
		catalogue.append_array([site["x"], site["z"], site["r"], site["margin"], site["level"]])
	for site in ground.airfields:
		catalogue.append_array([site["x"], site["z"], site["half_long"], site["half_wide"], site["margin"], site["level"]])
	var low: int = 1 << 30
	var high: int = -(1 << 30)
	for h in heights:
		low = mini(low, h)
		high = maxi(high, h)
	print("[terrain] bits: %d points, heights %.2f to %.2f m, first five %s" % [heights.size(),
		float(low) / 32.0, float(high) / 32.0, heights.slice(0, 5)])
	print("[terrain] bits: points  sha256 %s" % _sha(at.to_byte_array()))
	print("[terrain] bits: heights sha256 %s" % _sha(heights.to_byte_array()))
	print("[terrain] bits: water   sha256 %s" % _sha(water.to_byte_array()))
	print("[terrain] bits: catalogue sha256 %s (%d ints)" % [_sha(catalogue.to_byte_array()), catalogue.size()])
	var file := FileAccess.open(_out.path_join("points.bin"), FileAccess.WRITE)
	file.store_buffer(at.to_byte_array())
	file.close()
	file = FileAccess.open(_out.path_join("heights_%s.bin" % ("double" if OS.has_feature("double") else "stock")),
		FileAccess.WRITE)
	file.store_buffer(heights.to_byte_array())
	file.close()


static func _sha(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


## ---- time ------------------------------------------------------------------------------------------------------

func _time() -> void:
	var n: int = 20000
	var sum: int = 0
	var began: int = Time.get_ticks_usec()
	for k in range(n):
		sum += ground.height_ticks(-20000 + (k * 7919) % 40000, -20000 + (k * 104729) % 40000)
	var spent: float = float(Time.get_ticks_usec() - began)
	print("[terrain] time: %d samples in %.0f ms, %.1f us a sample (checksum %d)" % [n, spent / 1000.0,
		spent / n, sum])
	# What the collision would cost built here, at 16 m over the 64 km square.
	var samples: float = pow(64000.0 / 16.0 + 1.0, 2.0)
	print("[terrain] time: a 16 m field over 64 km is %.1f M samples, %.0f s in this GDScript" % [samples / 1e6,
		samples * spent / n / 1e6])


## ---- map -------------------------------------------------------------------------------------------------------

func _map() -> void:
	var step: int = 128
	var n: int = WORLD_SPAN / step + 1
	var began: int = Time.get_ticks_usec()
	var h := PackedInt32Array()
	var wet := PackedByteArray()
	h.resize(n * n)
	wet.resize(n * n)
	for j in range(n):
		for i in range(n):
			var x: int = -WORLD_HALF + i * step
			var z: int = -WORLD_HALF + j * step
			var ticks: int = ground.height_ticks(x, z)
			h[j * n + i] = ticks
			var water: int = ground.water_ticks(x, z)
			wet[j * n + i] = 0 if water < -(1 << 29) else (1 if water == 0 else 2)
	print("[terrain] map: %d samples in %.1f s" % [n * n, float(Time.get_ticks_usec() - began) / 1e6])
	var image := Image.create(n, n, false, Image.FORMAT_RGB8)
	var highest: int = 0
	var land: int = 0
	for j in range(n):
		for i in range(n):
			var here: float = float(h[j * n + i]) / 32.0
			highest = maxi(highest, h[j * n + i])
			var east: float = float(h[j * n + mini(i + 1, n - 1)]) / 32.0
			var south: float = float(h[mini(j + 1, n - 1) * n + i]) / 32.0
			var normal := Vector3(here - east, float(step), here - south).normalized()
			var light: float = clampf(normal.dot(Vector3(-0.5, 0.75, -0.45).normalized()) * 1.25, 0.25, 1.15)
			var colour: Color
			match wet[j * n + i]:
				1: colour = Color(0.05, 0.16, 0.30).lerp(Color(0.12, 0.35, 0.45), clampf(1.0 + here / 60.0, 0.0, 1.0))
				2: colour = Color(0.20, 0.45, 0.70)
				_:
					land += 1
					var slope: float = 1.0 - normal.y
					colour = Color(0.30, 0.45, 0.20).lerp(Color(0.52, 0.50, 0.34), clampf(here / 500.0, 0.0, 1.0))
					colour = colour.lerp(Color(0.45, 0.42, 0.40), clampf(slope * 6.0, 0.0, 1.0))
					colour = colour.lerp(Color(0.95, 0.95, 0.97), clampf((here - 950.0) / 200.0, 0.0, 1.0))
					colour = Color(colour.r * light, colour.g * light, colour.b * light)
			image.set_pixel(i, j, colour)
	for town in ground.towns:
		var ci: int = (int(town["x"]) + WORLD_HALF) / step
		var cj: int = (int(town["z"]) + WORLD_HALF) / step
		var r: int = int(town["r"]) / step
		image.fill_rect(Rect2i(ci - r, cj - r, r * 2 + 1, r * 2 + 1), Color(0.85, 0.15, 0.1))
	for strip in ground.airfields:
		var ci: int = (int(strip["x"]) - int(strip["half_long"]) + WORLD_HALF) / step
		var cj: int = (int(strip["z"]) - int(strip["half_wide"]) + WORLD_HALF) / step
		image.fill_rect(Rect2i(ci, cj, maxi(int(strip["half_long"]) * 2 / step, 1),
			maxi(int(strip["half_wide"]) * 2 / step, 1)), Color(1.0, 0.85, 0.1))
	image.save_png(_out.path_join("world_map.png"))
	print("[terrain] map: highest %.0f m, land %.0f %% of the square, %s" % [float(highest) / 32.0,
		100.0 * land / (n * n), _out.path_join("world_map.png")])
	for lake in ground.lakes.values():
		print("[terrain] map: lake at (%d, %d) r %d m, level %.1f m" % [lake["x"], lake["z"], lake["r"],
			float(lake["level"]) / 1024.0])
	for town in ground.towns:
		print("[terrain] map: town at (%d, %d) r %d m, level %.1f m" % [town["x"], town["z"], town["r"],
			float(town["level"]) / 1024.0])
	for strip in ground.airfields:
		print("[terrain] map: airfield at (%d, %d) %s, level %.1f m" % [strip["x"], strip["z"],
			"along x" if int(strip["half_long"]) > int(strip["half_wide"]) else "along z", float(strip["level"]) / 1024.0])


const WORLD_SPAN: int = 64000


## ---- cracks ----------------------------------------------------------------------------------------------------

## THE GAP AN EDGE OPENS between a cell drawn at spacing s and its neighbour at 2s: the fine edge has a vertex at every
## s, the coarse one a straight line between every 2s, and the crack is the fine vertex's distance off that line.
func _cracks() -> void:
	var region: int = 16
	for spacing in [16, 32, 64, 128]:
		var worst: float = 0.0
		var total: float = 0.0
		var counted: int = 0
		var worst_at := Vector2i.ZERO
		for c in range(region):
			for line in range(region + 1):
				# Edges along x at z = line * CELL, and along z at x = line * CELL, round a patch of mountains.
				for along_x in [true, false]:
					for k in range(0, CELL, spacing * 2):
						var a: int = (c * CELL - 8 * CELL) + k
						var fixed: int = line * CELL - 8 * CELL
						var p0: int = ground.height_ticks(a, fixed) if along_x else ground.height_ticks(fixed, a)
						var p1: int = ground.height_ticks(a + spacing * 2, fixed) if along_x \
							else ground.height_ticks(fixed, a + spacing * 2)
						var mid: int = ground.height_ticks(a + spacing, fixed) if along_x \
							else ground.height_ticks(fixed, a + spacing)
						var gap: float = absf(float(mid) - float(p0 + p1) * 0.5) / 32.0
						total += gap
						counted += 1
						if gap > worst:
							worst = gap
							worst_at = Vector2i(a, fixed) if along_x else Vector2i(fixed, a)
		print("[terrain] cracks: %3d m against %3d m: worst %.2f m at %s, mean %.3f m over %d edge vertices" % [
			spacing, spacing * 2, worst, worst_at, total / counted, counted])


## ---- patch -----------------------------------------------------------------------------------------------------

## How far out each spacing is drawn, as a Chebyshev distance in cells from the middle cell: [furthest ring, metres].
## The last ring, 19, is the streaming design's far ring: fog is 95 % by about 18.7 km.
const RINGS: Array = [[1, 16], [3, 32], [7, 64], [13, 128], [19, 256]]
const LOD_TINTS: Dictionary = {16: Color(1.0, 0.2, 0.2), 32: Color(1.0, 0.8, 0.1), 64: Color(0.2, 0.9, 0.3),
	128: Color(0.2, 0.6, 1.0), 256: Color(0.7, 0.3, 1.0)}
## The level's own children the terrain pictures keep; everything else Node3D or CanvasItem is hidden for them.
const KEEP: Array[String] = ["Sea", "Swell", "Lift", "WorldEnvironment", "DirectionalLight3D", "Observer", "TerrainPatch"]

var _level: Node = null
var _terrain: Node3D = null
var _paint: Dictionary = {}       # [spacing, fine] -> ShaderMaterial
var _cells: Array[MeshInstance3D] = []
var _flat_hidden: bool = false


func _patch() -> void:
	if DisplayServer.get_name() == "headless":
		_check("patch_is_windowed", false, "headless has no rendering device; every picture would be black")
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_level = load("res://world/sky.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	while not Sim.is_ready:
		await get_tree().physics_frame
	for i in range(30):
		await get_tree().process_frame
	if _level.get("observer") == null:
		_check("there_is_an_observer", false, "pass --level=watch after the bare --")
		return
	# A PLANE OF ITS OWN, wider than the level's: the plain sea wears SeaSwell's 48 km sheet since 2026-09-15, and this view
	# is kilometres from any vertex the swell moves.
	var sea := _level.get_node("Sea") as MeshInstance3D
	var wide := PlaneMesh.new()
	wide.size = Vector2(128000.0, 128000.0)
	sea.mesh = wide

	# THE PLACE: the lake with the highest ground within 9 km north of it, looked at from 2.6 km south.
	var lake: Dictionary = {}
	var best: int = -1
	for candidate in ground.lakes.values():
		var lx: int = candidate["x"]
		var lz: int = candidate["z"]
		if absi(lx) > 18000 or absi(lz) > 16000:
			continue
		var highest: int = 0
		for d in range(1000, 9001, 1000):
			for dx in range(-3000, 3001, 1000):
				highest = maxi(highest, ground.height_ticks(lx + dx, lz - d))
		if highest > best:
			best = highest
			lake = candidate
	var target := Vector3(float(lake["x"]), 0.0, float(lake["z"]))
	target.y = _ground_at(target.x, target.z)
	print("[terrain] patch: the lake at (%d, %d), level %.1f m, ground to its north up to %.0f m" % [lake["x"],
		lake["z"], float(lake["level"]) / 1024.0, float(best) / 32.0])
	var low_at := Vector3(target.x, 0.0, target.z + 2600.0)
	low_at.y = _ground_at(low_at.x, low_at.z) + 300.0
	var low_to := Vector3(target.x, 0.0, target.z - 2400.0)
	low_to.y = _ground_at(low_to.x, low_to.z) + 120.0
	var high_at := Vector3(target.x, 3000.0, target.z + 9000.0)

	# TODAY'S ISLAND FIRST, from the same heights over the ground and the same angles.
	for fine in [false, true]:
		await _wear(fine)
		await _shoot("today_300m_%s" % _finish(fine), Vector3(0.0, 300.0, 2600.0), Vector3(0.0, 120.0, -2400.0))
		await _shoot("today_3km_%s" % _finish(fine), Vector3(0.0, 3000.0, 9000.0), Vector3(0.0, 0.0, 0.0))

	_terrain = Node3D.new()
	_terrain.name = "TerrainPatch"
	_level.add_child(_terrain)
	_flat_hidden = true
	await _build_the_patch(WorldMap.cell_of(Vector3(target.x, 0.0, target.z + 1300.0)))
	# `--lakes=off` draws no lake water: the mutant that asks whether pale beads along shores at 3 km -- unchanged with
	# the skirts off, outward only, or the sea hidden -- are a lake's flat disc poking up through coarse ground.
	if _asked("lakes", "on") != "off":
		_draw_the_lakes()
	for fine in [false, true]:
		await _wear(fine)
		await _shoot("terrain_300m_%s" % _finish(fine), low_at, low_to)
		await _shoot("terrain_3km_%s" % _finish(fine), high_at, target)
	await _wear(false)
	_tint_the_rings(0.6)
	await _shoot("terrain_3km_rings", high_at, target)
	await _shoot("terrain_300m_rings", low_at, low_to)
	_tint_the_rings(0.0)
	# AND ALONG A VALLEY FLOOR, low, where the nearest ring and the skirts are.
	var skim_at := Vector3(target.x - 1500.0, 0.0, target.z + 900.0)
	skim_at.y = _ground_at(skim_at.x, skim_at.z) + 40.0
	var skim_to := Vector3(target.x + 1500.0, 0.0, target.z - 1200.0)
	skim_to.y = _ground_at(skim_to.x, skim_to.z) + 60.0
	await _wear(true)
	await _shoot("terrain_40m_fine", skim_at, skim_to)


func _ground_at(x: float, z: float) -> float:
	return float(ground.height_ticks(int(round(x)), int(round(z)))) / 32.0


static func _finish(fine: bool) -> String:
	return "fine" if fine else "plain"


func _wear(fine: bool) -> void:
	(get_node("/root/Finish")).call("choose", fine)
	for cell in _cells:
		cell.material_override = _paint[[int(cell.get_meta(&"spacing")), fine]]
	for i in range(10):
		await get_tree().process_frame


func _tint_the_rings(amount: float) -> void:
	for key in _paint:
		(_paint[key] as ShaderMaterial).set_shader_parameter("lod_tint_amount", amount)


## A switch off the command line, `--name=value`, or `otherwise`.
static func _asked(name: String, otherwise: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--%s=" % name):
			return argument.get_slice("=", 1)
	return otherwise


func _hide_the_flat_world() -> void:
	# `--sun-shadows=off`: the sun's shadows off for the terrain pictures, to ask whether a straight step in the light
	# near the eye is the shadow map on long coarse triangles (the fixed-stencil normals did not remove it).
	if OS.get_cmdline_user_args().has("--sun-shadows=off"):
		(_level.get_node("DirectionalLight3D") as DirectionalLight3D).shadow_enabled = false
	# `--sea=off` hides both seas and `--far=metres` moves the camera's far plane: which of the two draws the grey band
	# across the horizon in every 3 km picture, today's island's as well.
	if _asked("sea", "on") == "off":
		(_level.get_node("Sea") as Node3D).visible = false
		(_level.get_node("Swell") as Node3D).visible = false
	if _asked("far", "") != "":
		(_level.get("observer") as Camera3D).far = float(_asked("far", "24000"))
	# `--sky-ground=fog`: the sky's lower half painted the fog's own colour, the mutant that asks whether the grey band
	# below the horizon -- still there with the sea hidden, narrower with a 60 km far plane -- is the sky's ground colour
	# seen wherever nothing is drawn below the horizon.
	if _asked("sky-ground", "") == "fog":
		var air: Environment = (_level.get_node("WorldEnvironment") as WorldEnvironment).environment
		var sky_paint := air.sky.sky_material as ShaderMaterial
		sky_paint.set_shader_parameter("ground_horizon_color", air.fog_light_color)
		sky_paint.set_shader_parameter("ground_bottom_color", air.fog_light_color)
	for child in _level.get_children():
		if KEEP.has(String(child.name)):
			continue
		if child is Node3D:
			(child as Node3D).visible = false
		elif child is CanvasItem:
			(child as CanvasItem).visible = false
		elif child is CanvasLayer:
			(child as CanvasLayer).visible = false
	for child in (_level.get("observer") as Node).get_children():
		if child is Node3D:
			(child as Node3D).visible = false
		elif child is CanvasLayer:
			(child as CanvasLayer).visible = false


func _shoot(label: String, at: Vector3, toward: Vector3) -> void:
	# `--views=a,b` shoots only those, so a mutant run is minutes rather than all eleven pictures.
	var views: String = _asked("views", "")
	if views != "" and not views.split(",").has(label):
		return
	var observer: Node = _level.get("observer")
	var sums: Vector2 = Vector2.ZERO
	for i in range(60):
		if _flat_hidden:
			_hide_the_flat_world()
		observer.call("look_from", at, toward)
		await get_tree().process_frame
		if i >= 40:
			sums += Vector2(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_out.path_join(label + ".png"))
	print("[terrain] shot %-20s from %s: draws %.0f, primitives %.0f" % [label, at.snappedf(1.0), sums.x / 20.0,
		sums.y / 20.0])


func _build_the_patch(middle: Vector2i) -> void:
	for ring in RINGS:
		var spacing: int = ring[1]
		for fine in [false, true]:
			var paint := ShaderMaterial.new()
			paint.shader = load("res://tests/terrain_probe_ground_fine.gdshader") if fine \
				else load("res://tests/terrain_probe_ground.gdshader")
			paint.set_shader_parameter("lod_tint", LOD_TINTS[spacing])
			paint.set_shader_parameter("lod_tint_amount", 0.0)
			# `--patches=off`: the colour patches' value noise held still (a scale of zero), the mutant that asks whether the
			# straight streaks near the eye -- unchanged with every cell at 16 m -- are that noise's 625 m lattice.
			if _asked("patches", "on") == "off":
				paint.set_shader_parameter("patch_scale", 0.0)
			# `--rock=off`: no rock colour anywhere, the mutant that asks whether pale beads along valleys and shores at
			# 3 km -- unchanged with skirts off or outward, lakes off, or the sea hidden -- are the steep walls of a carved
			# valley floor or lake basin painted as rock and aliased at a coarse spacing.
			if _asked("rock", "on") == "off":
				paint.set_shader_parameter("rock_amount", 0.0)
			# `--clumps=off`: FINE's clump noise held still (a scale of zero), which also flattens the relief it tips the
			# normal by -- the mutant that asks whether the streaks and tiles near the eye, unchanged with normals straight
			# up, are that value noise's 28.6 m lattice.
			if _asked("clumps", "on") == "off":
				paint.set_shader_parameter("clump_scale", 0.0)
			_paint[[spacing, fine]] = paint
	var stats: Dictionary = {}
	# `--reach=cells` draws a smaller patch; `--spacing=metres` draws every cell at one spacing (16, 32, 64, 128 or 256),
	# the mutant that asks whether a straight step in the light near the eye is the level of detail changing.
	var reach: int = int(_asked("reach", str(int(RINGS[RINGS.size() - 1][0]))))
	var one_spacing: int = int(_asked("spacing", "0"))
	var built: int = 0
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var ring: int = maxi(absi(dx), absi(dz))
			var spacing: int = 16
			for r in RINGS:
				if ring <= int(r[0]):
					spacing = r[1]
					break
			if one_spacing > 0:
				spacing = one_spacing
			var cell := middle + Vector2i(dx, dz)
			var began: int = Time.get_ticks_usec()
			var made: Dictionary = _cell_mesh(cell, spacing)
			var row: Dictionary = stats.get(spacing, {"cells": 0, "skipped": 0, "triangles": 0, "sample_ms": 0.0,
				"mesh_ms": 0.0, "skirt_most": 0.0})
			if made.is_empty():
				row["skipped"] += 1
			else:
				var node := MeshInstance3D.new()
				node.name = "Cell_%d_%d" % [cell.x, cell.y]
				node.mesh = made["mesh"]
				node.position = Vector3(float(cell.x * CELL), 0.0, float(cell.y * CELL))
				node.set_meta(&"spacing", spacing)
				node.material_override = _paint[[spacing, false]]
				_terrain.add_child(node)
				_cells.append(node)
				row["cells"] += 1
				row["triangles"] += int(made["triangles"])
				row["sample_ms"] += float(made["sample_usec"]) / 1000.0
				row["mesh_ms"] += float(Time.get_ticks_usec() - began - int(made["sample_usec"])) / 1000.0
				row["skirt_most"] = maxf(float(row["skirt_most"]), float(made["skirt"]))
			stats[spacing] = row
			built += 1
			if built % 24 == 0:
				await get_tree().process_frame
	var triangles: int = 0
	for spacing in stats:
		var row: Dictionary = stats[spacing]
		triangles += int(row["triangles"])
		# The format string in parentheses: `"a" + "b" % args` formats only "b", and printed the template five times.
		print(("[terrain] patch: %3d m cells %4d (%d all sea, skipped), %7d triangles, sampling %.1f ms a cell, mesh "
			+ "%.2f ms a cell, deepest skirt %.1f m") % [spacing, row["cells"], row["skipped"], row["triangles"],
			float(row["sample_ms"]) / maxi(int(row["cells"]), 1), float(row["mesh_ms"]) / maxi(int(row["cells"]), 1),
			row["skirt_most"]])
	print("[terrain] patch: %d cells, %d triangles in all" % [_cells.size(), triangles])


## ONE CELL'S GROUND at `spacing`: the vertices in the cell's own frame, normals from the samples either side, the
## triangles split on the diagonal Box3D's height field splits on, and a skirt down each edge as deep as the largest
## gap that edge can open against a neighbour one spacing finer or coarser.
func _cell_mesh(cell: Vector2i, spacing: int) -> Dictionary:
	var began: int = Time.get_ticks_usec()
	var n: int = CELL / spacing + 1
	var w: int = n + 2
	var ox: int = cell.x * CELL
	var oz: int = cell.y * CELL
	var h := PackedFloat32Array()
	h.resize(w * w)
	var highest: float = -INF
	for j in range(w):
		for i in range(w):
			var y: float = float(ground.height_ticks(ox + (i - 1) * spacing, oz + (j - 1) * spacing)) / 32.0
			h[j * w + i] = y
			highest = maxf(highest, y)
	if highest < -40.0:
		return {}
	# THE SKIRT: each edge's vertices against the line every other one makes, and -- past the finest spacing -- the
	# edge sampled at half the spacing against the line these vertices make.
	var skirt: float = 0.5
	var edges: Array = [[0, 0, 1, 0], [0, n - 1, 1, 0], [0, 0, 0, 1], [n - 1, 0, 0, 1]]
	for edge in edges:
		for k in range(1, n - 1, 2):
			var a: float = h[(edge[1] + edge[3] * (k - 1) + 1) * w + edge[0] + edge[2] * (k - 1) + 1]
			var b: float = h[(edge[1] + edge[3] * (k + 1) + 1) * w + edge[0] + edge[2] * (k + 1) + 1]
			var m: float = h[(edge[1] + edge[3] * k + 1) * w + edge[0] + edge[2] * k + 1]
			skirt = maxf(skirt, absf(m - (a + b) * 0.5) + 0.5)
		if spacing > 16:
			for k in range(n - 1):
				var a: float = h[(edge[1] + edge[3] * k + 1) * w + edge[0] + edge[2] * k + 1]
				var b: float = h[(edge[1] + edge[3] * (k + 1) + 1) * w + edge[0] + edge[2] * (k + 1) + 1]
				var mx: int = ox + (edge[0] + edge[2] * k) * spacing + edge[2] * spacing / 2
				var mz: int = oz + (edge[1] + edge[3] * k) * spacing + edge[3] * spacing / 2
				var m: float = float(ground.height_ticks(mx, mz)) / 32.0
				skirt = maxf(skirt, absf(m - (a + b) * 0.5) + 0.5)
	var sample_usec: int = Time.get_ticks_usec() - began
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	# NORMALS FROM ONE STENCIL AT EVERY SPACING (`--normals=own` puts back the spacing's own): the first pictures lit a
	# 32 m cell's slopes from samples 32 m apart and its 16 m neighbour's from 16 m, and the ring boundary showed as a step
	# in the light on the ground.
	var own: bool = OS.get_cmdline_user_args().has("--normals=own")
	# `--normals=up`: every normal straight up, so the light is the same on every triangle -- the mutant that asks whether
	# the facets and streaks on the ground near the eye (unchanged with every cell at 16 m, shadows off, the patches'
	# noise still, or either stencil) are the 16 m triangles being lit a vertex at a time.
	var up: bool = _asked("normals", "") == "up"
	for j in range(n):
		for i in range(n):
			verts.append(Vector3(float(i * spacing), h[(j + 1) * w + i + 1], float(j * spacing)))
			if up:
				normals.append(Vector3.UP)
			elif own:
				var ddx: float = h[(j + 1) * w + i + 2] - h[(j + 1) * w + i]
				var ddz: float = h[(j + 2) * w + i + 1] - h[j * w + i + 1]
				normals.append(Vector3(-ddx, 2.0 * float(spacing), -ddz).normalized())
			else:
				var x: int = ox + i * spacing
				var z: int = oz + j * spacing
				var sx: float = float(ground.height_ticks(x + 16, z) - ground.height_ticks(x - 16, z)) / 32.0
				var sz: float = float(ground.height_ticks(x, z + 16) - ground.height_ticks(x, z - 16)) / 32.0
				normals.append(Vector3(-sx, 32.0, -sz).normalized())
	for j in range(n - 1):
		for i in range(n - 1):
			var a: int = j * n + i
			# Box3D's cell is (a, c, b) and (d, b, c), anticlockwise from above; Godot's front faces are clockwise.
			indices.append_array([a, a + 1, a + n, a + n + 1, a + n, a + 1])
	# `--skirts=off` draws none; `--skirts=out` draws each skirt facing out of its own cell only, the winding that faces
	# out being the second for the edge at z = 0 and x = far, the first for z = far and x = 0 (worked from the cross
	# product of the edge and the drop). The mutants that ask whether pale beaded lines along valleys at 3 km are skirts.
	var skirts: String = _asked("skirts", "both")
	for e in range(edges.size() if skirts != "off" else 0):
		var edge: Array = edges[e]
		var first: int = verts.size()
		for k in range(n):
			var top: int = (edge[1] + edge[3] * k) * n + edge[0] + edge[2] * k
			verts.append(verts[top] - Vector3(0.0, skirt, 0.0))
			normals.append(normals[top])
		var outward_first: bool = e == 1 or e == 2
		for k in range(n - 1):
			var t0: int = (edge[1] + edge[3] * k) * n + edge[0] + edge[2] * k
			var t1: int = (edge[1] + edge[3] * (k + 1)) * n + edge[0] + edge[2] * (k + 1)
			# Both windings by default: a skirt is seen from whichever side the crack is on.
			if skirts == "both" or outward_first:
				indices.append_array([t0, t1, first + k, t1, first + k + 1, first + k])
			if skirts == "both" or not outward_first:
				indices.append_array([t0, first + k, t1, t1, first + k, first + k + 1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {"mesh": mesh, "triangles": indices.size() / 3, "sample_usec": sample_usec, "skirt": skirt}


## A FLAT DISC OF THE SEA'S OWN PAINT at each lake's level, as wide as the rim that keeps the ground above it.
func _draw_the_lakes() -> void:
	var sea := _level.get_node("Sea") as MeshInstance3D
	var wet: Material = sea.material_override if sea.material_override != null else sea.mesh.surface_get_material(0)
	for lake in ground.lakes.values():
		var radius: float = float(lake["water_radius"])
		var verts := PackedVector3Array([Vector3.ZERO])
		var normals := PackedVector3Array([Vector3.UP])
		var indices := PackedInt32Array()
		for k in range(64):
			var about: float = TAU * float(k) / 64.0
			verts.append(Vector3(cos(about) * radius, 0.0, sin(about) * radius))
			normals.append(Vector3.UP)
			indices.append_array([0, 1 + k, 1 + (k + 1) % 64])
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = wet
		node.position = Vector3(float(lake["x"]), float(lake["level"]) / 1024.0, float(lake["z"]))
		_terrain.add_child(node)
