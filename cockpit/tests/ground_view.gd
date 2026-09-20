extends Node
## Headless: is the ground drawn the ground the simulation stands on -- every cell the collision holds drawn, the finest
## level the collision's own triangles, no crack between two cells at any two levels -- and does the yard draw it by
## distance?
##
##   Godot --headless --path cockpit res://tests/ground_view.tscn
##
## `GroundView` (world/ground_view.gd) lays the C++ ground into a `SceneryYard` as a levelled layer. Nothing on a screen
## says a drawn hillside is a metre from the one an aeroplane lands on, or that a crack opens where two levels meet, so
## every check here is against something the view did not compute:
##
## - EVERY CELL THE COLLISION HOLDS IS DRAWN: the cells with a 16 m sample above -40 m, found here from
##   `GroundField.heights` as `tests/ground_collision.gd` finds them, are all cells of the layer.
## - THE FINEST LEVEL IS THE COLLISION (T3): every vertex of the highest cells is the function's height at its own
##   metres, to the tick; every square's two triangles share the edge Box3D's share; and a Box3D ray down, in a world
##   standing on the same ground, lands on the drawn triangle at random triangles' middles within a millimetre.
## - A COARSER LEVEL FOLLOWS THE CREST: at 32, 64 and 128 m every square of the highest cells is split on the diagonal
##   whose middle is nearer the function's height at the square's middle, some squares take the other diagonal, and the
##   drawn middles stand nearer the function than Box3D's diagonal leaves them.
## - THE GROUND IS LIT FROM THE FUNCTION'S OWN NORMALS: at every level of the highest cells the normal map has the size its
##   texel gives, and every texel is the normal of the function a texel either side of it, worked out here from
##   `GroundField.heights`, to a byte's rounding. How far a coarser map's light stands from the finest map's at the texels
##   they share is printed: that is the ground's light filtered to the level's distance, by design.
## - NO CRACK AT ANY TWO LEVELS (T7): for the mountain cells and their neighbours east and south, at every pair of
##   different levels, the gap between the two drawn edges every 16 m along the edge they share is spanned by the skirt
##   of whichever edge is higher -- and the skirt vertices really hang that deep.
## - A CELL WORKED ON A THREAD IS THE CELL WORKED HERE, at every level.
## - IN A YARD, every cell within reach is drawn once, at the finest level its distance allows, with that level's vertex
##   count.
##
## The world is the game's (`GroundTuning`): 64 km, ranges to 3,000 m, seed 0. It prints what a cell costs at each level.
##
## Read RESULT=, not the exit code.

const HZ: float = 120.0
const TICKS_PER_METRE: float = 32.0
const CELL: int = 1024
const SEA_FLOOR_TICKS: int = -40 * 32
const FAR: float = 12000.0
const WITHIN: float = 0.001
## The highest cells, where the ground is steepest and the gaps between levels deepest.
const MOUNTAIN_CELLS: int = 12
const RAYS: int = 480

var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[ground_view] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var can: bool = ClassDB.class_exists("GroundField") and ClassDB.class_exists("CockpitWorld") \
		and ClassDB.class_has_method("CockpitWorld", "set_ground")
	_check("the_extension_has_the_ground_and_a_world_to_stand_on_it", can, "engine %s, double=%s" % [
		Engine.get_version_info()["string"], OS.has_feature("double")])
	if not can:
		_finish()
		return
	var field: Object = ClassDB.instantiate("GroundField")
	var problems: PackedStringArray = field.call("configure", GroundTuning.values())
	_check("the_games_world_configures", problems.is_empty(), str(problems))
	var yard := SceneryYard.new()
	add_child(yard)
	yard.set_process(false)
	var view := GroundView.new()
	add_child(view)
	var began: int = Time.get_ticks_usec()
	var laid: int = view.show_ground(field, yard, FAR)
	print("[ground_view] %d cells found in %.0f ms" % [laid, float(Time.get_ticks_usec() - began) / 1000.0])
	var cells: Array[Vector2i] = yard.cells_of(GroundView.LAYER)

	_every_cell_the_collision_holds_is_drawn(field, cells)
	var mountain: Array[Vector2i] = _highest_cells(field, cells)
	_the_finest_level_is_the_collision(field, mountain)
	_a_coarser_level_follows_the_crest(field, mountain)
	_the_ground_is_lit_from_the_functions_own_normals(field, mountain)
	_no_crack_between_two_cells_at_any_two_levels(field, cells, mountain)
	await _a_cell_worked_on_a_thread_is_the_cell_worked_here(field, mountain[0])
	_in_a_yard_every_cell_is_drawn_at_its_level(yard, view, cells, mountain[0])
	_what_a_cell_costs(field, mountain[0])
	_check("every_section_of_the_suite_ran", _sections == 7, "%d of 7" % _sections)
	yard.catch_up()
	yard.free()
	view.free()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()


## ---- the cells ----------------------------------------------------------------------------------------------------

func _every_cell_the_collision_holds_is_drawn(field: Object, cells: Array[Vector2i]) -> void:
	var drawn: Dictionary = {}
	for cell in cells:
		drawn[cell] = true
	var half: int = int((field.call("tuning") as Dictionary)["world_half"])
	var across: int = 2 * ((half + CELL - 1) / CELL)
	var held: int = 0
	var missing: Array[Vector2i] = []
	for row in range(across):
		for column in range(across):
			var cell := Vector2i(column - across / 2, row - across / 2)
			var heights: PackedInt32Array = field.call("heights", cell.x * CELL, cell.y * CELL, 65, 65, 16)
			heights.sort()
			if heights[heights.size() - 1] <= SEA_FLOOR_TICKS:
				continue
			held += 1
			if not drawn.has(cell):
				missing.append(cell)
	_check("every_cell_the_collision_holds_is_drawn", held > 0 and missing.is_empty(),
		"%d cells held, %d drawn, %d held and not drawn%s" % [held, cells.size(), missing.size(),
			"" if missing.is_empty() else ": %s" % [missing.slice(0, 6)]])
	_sections += 1


## The layer's cells whose highest sample every 128 m is highest, highest first.
func _highest_cells(field: Object, cells: Array[Vector2i]) -> Array[Vector2i]:
	var rows: Array = []
	for cell in cells:
		var heights: PackedInt32Array = field.call("heights", cell.x * CELL, cell.y * CELL, 9, 9, 128)
		heights.sort()
		rows.append([heights[heights.size() - 1], cell])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	var out: Array[Vector2i] = []
	for row in rows.slice(0, MOUNTAIN_CELLS):
		out.append(row[1])
	return out


## ---- the collision --------------------------------------------------------------------------------------------------

func _the_finest_level_is_the_collision(field: Object, cells: Array[Vector2i]) -> void:
	var n: int = CELL / GroundView.SPACINGS[0] + 1
	var spacing: int = GroundView.SPACINGS[0]
	var wrong_vertex: int = 0
	var wrong_diagonal: int = 0
	var vertices: int = 0
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(HZ)
	world.start(0)
	world.set_ground(field)
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	var rays: int = 0
	var missed: int = 0
	var worst: float = 0.0
	for cell in cells:
		var done: Dictionary = GroundView.cell_arrays(field, cell, 0)
		var verts: PackedVector3Array = done["vertices"]
		var indices: PackedInt32Array = done["indices"]
		var points := PackedInt32Array()
		for j in range(n):
			for i in range(n):
				points.append_array([cell.x * CELL + i * spacing, cell.y * CELL + j * spacing])
		var ticks: PackedInt32Array = field.call("heights_at", points)
		for k in range(n * n):
			vertices += 1
			var want := Vector3(float((k % n) * spacing), float(ticks[k]) / TICKS_PER_METRE, float((k / n) * spacing))
			if verts[k] != want:
				wrong_vertex += 1
		# THE DIAGONAL: the first six indices a square has are its two triangles, sharing (x + 16, z) and (x, z + 16).
		for q in range((n - 1) * (n - 1)):
			var a: int = (q / (n - 1)) * n + q % (n - 1)
			var first: Array = [indices[6 * q], indices[6 * q + 1], indices[6 * q + 2]]
			var second: Array = [indices[6 * q + 3], indices[6 * q + 4], indices[6 * q + 5]]
			first.sort()
			second.sort()
			if first != [a, a + 1, a + n] or second != [a + 1, a + n, a + n + 1]:
				wrong_diagonal += 1
		# THROUGH BOX3D: a triangle's middle, rounded to the float32 the physics holds a position in, and the drawn
		# triangle's plane there.
		for r in range(RAYS / cells.size()):
			var tri: int = rng.randi_range(0, (n - 1) * (n - 1) * 2 - 1)
			var p0: Vector3 = verts[indices[tri * 3]]
			var p1: Vector3 = verts[indices[tri * 3 + 1]]
			var p2: Vector3 = verts[indices[tri * 3 + 2]]
			var middle: Vector3 = (p0 + p1 + p2) / 3.0
			var held := PackedFloat32Array([float(cell.x * CELL) + middle.x, float(cell.y * CELL) + middle.z])
			var local_x: float = held[0] - float(cell.x * CELL)
			var local_z: float = held[1] - float(cell.y * CELL)
			var up: Vector3 = (p1 - p0).cross(p2 - p0)
			var plane: float = p0.y - (up.x * (local_x - p0.x) + up.z * (local_z - p0.z)) / up.y
			var below: float = world.first_solid_below(Vector3(held[0], plane + 50.0, held[1]), 100.0)
			rays += 1
			if below < 0.0:
				missed += 1
			else:
				worst = maxf(worst, absf(plane + 50.0 - below - plane))
	world.teardown()
	_check("the_finest_level_draws_the_functions_own_heights_on_box3ds_diagonal",
		wrong_vertex == 0 and wrong_diagonal == 0 and vertices > 0,
		"%d vertices in the %d highest cells, %d off the function; %d squares on the other diagonal" % [vertices,
			cells.size(), wrong_vertex, wrong_diagonal])
	_check("and_a_box3d_ray_lands_on_the_drawn_triangle_within_a_millimetre", missed == 0 and worst <= WITHIN,
		"%d rays, %d missed, worst %.3f mm" % [rays, missed, worst * 1000.0])
	_sections += 1


## ---- the crest -------------------------------------------------------------------------------------------------------

## A COARSER LEVEL FOLLOWS THE CREST. Above the finest level every square is split on the diagonal whose middle is nearer
## the function's own height at the square's middle, a tie on Box3D's; read here from the drawn indices against
## `GroundField.heights` asked here. Some squares must take the other diagonal, or the rule was never used. And summed
## over every square the drawn middles must stand nearer the function than Box3D's diagonal leaves them: on one fixed
## diagonal a crest lying across the squares was drawn as a sawtooth (team-lead's picture point 1, and the crest crop's
## tooth count, 223 turns of light and shade before and 133 after).
func _a_coarser_level_follows_the_crest(field: Object, cells: Array[Vector2i]) -> void:
	var squares: int = 0
	var wrong: int = 0
	var turned: int = 0
	var drawn_off: int = 0
	var box3d_off: int = 0
	var said: PackedStringArray = []
	for level in range(1, GroundView.SPACINGS.size()):
		var spacing: int = GroundView.SPACINGS[level]
		var n: int = CELL / spacing + 1
		var level_turned: int = 0
		var level_squares: int = 0
		for cell in cells:
			var done: Dictionary = GroundView.cell_arrays(field, cell, level)
			var indices: PackedInt32Array = done["indices"]
			var corners: PackedInt32Array = field.call("heights", cell.x * CELL, cell.y * CELL, n, n, spacing)
			var middles: PackedInt32Array = field.call("heights", cell.x * CELL + spacing / 2, cell.y * CELL + spacing / 2,
				n - 1, n - 1, spacing)
			for q in range((n - 1) * (n - 1)):
				var a: int = (q / (n - 1)) * n + q % (n - 1)
				# The first six indices a square has are its two triangles; on the other diagonal the first shares (a, a + n + 1).
				var first: Array = [indices[6 * q], indices[6 * q + 1], indices[6 * q + 2]]
				first.sort()
				var drawn_other: bool = first == [a, a + 1, a + n + 1]
				# Twice the height error of each diagonal's middle, in ticks.
				var middle: int = 2 * middles[q]
				var along_box3d: int = absi(corners[a + 1] + corners[a + n] - middle)
				var along_other: int = absi(corners[a] + corners[a + n + 1] - middle)
				squares += 1
				level_squares += 1
				if drawn_other != (along_other < along_box3d):
					wrong += 1
				if drawn_other:
					turned += 1
					level_turned += 1
				drawn_off += along_other if drawn_other else along_box3d
				box3d_off += along_box3d
		said.append("%d m %d of %d turned" % [spacing, level_turned, level_squares])
	var metres: float = 2.0 * TICKS_PER_METRE * float(maxi(squares, 1))
	_check("a_coarser_level_splits_every_square_on_the_diagonal_that_follows_the_crest",
		squares > 0 and wrong == 0 and turned > 0 and drawn_off < box3d_off,
		"%s; %d on the wrong diagonal; the drawn middles %.2f m off the function on average, on Box3D's diagonal %.2f m" % [
			", ".join(said), wrong, float(drawn_off) / metres, float(box3d_off) / metres])
	_sections += 1


## ---- the light -------------------------------------------------------------------------------------------------------

## THE GROUND IS LIT FROM THE FUNCTION'S OWN NORMALS. Per-vertex normals interpolated across 32 m and 64 m quads drew steep
## faces as vertical fluting (team-lead's picture point 2), so the ground is lit a pixel at a time from a normal map
## baked for each cell (`world/shaders/ground_view.gdshader`), a texel every 16 m at 16 m and 32 m, 32 m at 64 m and
## 64 m at 128 m (`GroundView.texel_metres`). Held against numbers the view did not compute: each texel decoded from its
## bytes against the function's normal a texel either side, from a `heights` grid asked here, within a byte's rounding.
## A coarser map's light at the texels it shares with the finest map is printed as angles, not held: a texel 64 m wide
## is the ground's light at the distance a 128 m cell is drawn, not the 16 m light.
func _the_ground_is_lit_from_the_functions_own_normals(field: Object, cells: Array[Vector2i]) -> void:
	var maps: int = 0
	var wrong_size: int = 0
	var worst: float = 0.0
	var said: PackedStringArray = []
	for level in range(GroundView.SPACINGS.size()):
		var texel: int = GroundView.texel_metres(level)
		var texels: int = CELL / texel + 1
		var w: int = texels + 2
		var angle_sum: float = 0.0
		var angle_worst: float = 0.0
		var shared: int = 0
		for cell in cells:
			var done: Dictionary = GroundView.cell_arrays(field, cell, level)
			var bytes: PackedByteArray = done["normal_map"]
			maps += 1
			if int(done["texels"]) != texels or bytes.size() != texels * texels * 3:
				wrong_size += 1
				continue
			var grid: PackedInt32Array = field.call("heights", cell.x * CELL - texel, cell.y * CELL - texel, w, w, texel)
			var finest: PackedByteArray = GroundView.cell_arrays(field, cell, 0)["normal_map"] if level > 0 else bytes
			var finest_texels: int = CELL / GroundView.texel_metres(0) + 1
			var ratio: int = texel / GroundView.texel_metres(0)
			for tj in range(texels):
				for ti in range(texels):
					var at: int = (tj + 1) * w + ti + 1
					var want := Vector3(-float(grid[at + 1] - grid[at - 1]) / TICKS_PER_METRE, 2.0 * texel,
						-float(grid[at + w] - grid[at - w]) / TICKS_PER_METRE).normalized()
					var got: Vector3 = _decoded(bytes, (tj * texels + ti) * 3)
					var off: Vector3 = (got - want).abs()
					worst = maxf(worst, maxf(off.x, maxf(off.y, off.z)))
					if level > 0:
						var fine_at: Vector3 = _decoded(finest, (tj * ratio * finest_texels + ti * ratio) * 3)
						var angle: float = rad_to_deg(got.normalized().angle_to(fine_at.normalized()))
						angle_sum += angle
						angle_worst = maxf(angle_worst, angle)
						shared += 1
		if level > 0:
			said.append("%d m map %d texels, %.1f degrees from the finest map's light on average, %.1f at worst" % [
				GroundView.SPACINGS[level], texels, angle_sum / float(maxi(shared, 1)), angle_worst])
		else:
			said.append("%d m map %d texels" % [GroundView.SPACINGS[level], texels])
	# One byte is 2/255 of the range -1..1; rounding to the nearest byte is half that.
	var byte: float = 1.0 / 255.0
	_check("the_ground_is_lit_from_a_normal_map_that_is_the_functions_own_normal_at_its_texel",
		maps > 0 and wrong_size == 0 and worst <= byte + 1e-6,
		"%d maps in the %d highest cells, %d the wrong size, worst texel %.5f off the function against a byte's rounding of %.5f; %s" % [
			maps, cells.size(), wrong_size, worst, byte, "; ".join(said)])
	_sections += 1


func _decoded(bytes: PackedByteArray, k: int) -> Vector3:
	return Vector3(float(bytes[k]), float(bytes[k + 1]), float(bytes[k + 2])) / 255.0 * 2.0 - Vector3.ONE


## ---- the cracks ------------------------------------------------------------------------------------------------------

func _no_crack_between_two_cells_at_any_two_levels(field: Object, cells: Array[Vector2i], mountain: Array[Vector2i]) -> void:
	var drawn: Dictionary = {}
	for cell in cells:
		drawn[cell] = true
	var made: Dictionary = {}
	var pairs: int = 0
	var gaps: int = 0
	var uncovered: int = 0
	var worst_gap: float = 0.0
	var worst_detail: String = ""
	var bad_skirts: int = 0
	for cell in mountain:
		for step in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other: Vector2i = cell + step
			if not drawn.has(other):
				continue
			pairs += 1
			var along_z: bool = step.x == 1
			for la in range(GroundView.SPACINGS.size()):
				for lb in range(GroundView.SPACINGS.size()):
					if la == lb:
						continue
					var a: Dictionary = _made(made, field, cell, la)
					var b: Dictionary = _made(made, field, other, lb)
					for f in range(GroundView.EDGE_SAMPLES):
						var t: float = float(f * GroundView.FINEST)
						var ha: float = _edge_height(a, la, along_z, true, t)
						var hb: float = _edge_height(b, lb, along_z, false, t)
						var gap: float = absf(ha - hb)
						var reach: float = float(a["skirt"]) if ha >= hb else float(b["skirt"])
						gaps += 1
						if gap > worst_gap:
							worst_gap = gap
							worst_detail = "%s at %d m against %s at %d m" % [cell, GroundView.SPACINGS[la], other,
								GroundView.SPACINGS[lb]]
						if gap > reach + WITHIN:
							uncovered += 1
	# AND THE SKIRTS HANG: every skirt vertex is its edge vertex, as deep as the skirt says.
	for key in made:
		var done: Dictionary = made[key]
		var level: int = key[1]
		var n: int = CELL / GroundView.SPACINGS[level] + 1
		var verts: PackedVector3Array = done["vertices"]
		if verts.size() != n * n + 4 * n:
			bad_skirts += 1
			continue
		var sides: Array = [[0, 0, 1, 0], [0, n - 1, 1, 0], [0, 0, 0, 1], [n - 1, 0, 0, 1]]
		for e in range(4):
			for k in range(n):
				var side: Array = sides[e]
				var top: int = (int(side[1]) + int(side[3]) * k) * n + int(side[0]) + int(side[2]) * k
				if absf(verts[n * n + e * n + k].y - (verts[top].y - float(done["skirt"]))) > WITHIN \
						or verts[n * n + e * n + k].x != verts[top].x or verts[n * n + e * n + k].z != verts[top].z:
					bad_skirts += 1
	_check("no_crack_between_two_cells_at_any_two_levels_a_skirt_does_not_span",
		pairs > 0 and uncovered == 0 and bad_skirts == 0,
		"%d neighbour pairs of the highest cells, every pair of levels, %d gaps every 16 m: %d not spanned, %d skirt vertices not where the skirt says; the widest gap %.1f m, %s"
			% [pairs, gaps, uncovered, bad_skirts, worst_gap, worst_detail])
	_sections += 1


func _made(made: Dictionary, field: Object, cell: Vector2i, level: int) -> Dictionary:
	var key: Array = [cell, level]
	if not made.has(key):
		made[key] = GroundView.cell_arrays(field, cell, level)
	return made[key]


## The height of a cell's drawn edge `t` metres along it: its x = CELL (or x = 0) column when `along_z`, its z = CELL (or
## z = 0) row otherwise, read off the vertices it drew.
static func _edge_height(done: Dictionary, level: int, along_z: bool, far: bool, t: float) -> float:
	var spacing: int = GroundView.SPACINGS[level]
	var n: int = CELL / spacing + 1
	var verts: PackedVector3Array = done["vertices"]
	var k: int = mini(floori(t / float(spacing)), n - 2)
	var u: float = (t - float(k * spacing)) / float(spacing)
	var line: int = n - 1 if far else 0
	var v0: float = verts[k * n + line].y if along_z else verts[line * n + k].y
	var v1: float = verts[(k + 1) * n + line].y if along_z else verts[line * n + k + 1].y
	return lerpf(v0, v1, u)


## ---- the thread ------------------------------------------------------------------------------------------------------

func _a_cell_worked_on_a_thread_is_the_cell_worked_here(field: Object, cell: Vector2i) -> void:
	var differ: Array[int] = []
	for level in range(GroundView.SPACINGS.size()):
		var here: Dictionary = GroundView.cell_arrays(field, cell, level)
		var slot: Dictionary = {}
		var task: int = WorkerThreadPool.add_task(func() -> void: slot["done"] = GroundView.cell_arrays(field, cell, level))
		while not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(task)
		var there: Dictionary = slot.get("done", {})
		for key in ["vertices", "normals", "colors", "indices", "skirt"]:
			if not there.has(key) or here[key] != there[key]:
				differ.append(level)
				break
	_check("a_cell_worked_on_a_thread_is_the_cell_worked_here_at_every_level", differ.is_empty(),
		"cell %s, levels that differ: %s" % [cell, differ])
	_sections += 1


## ---- the yard -------------------------------------------------------------------------------------------------------

func _in_a_yard_every_cell_is_drawn_at_its_level(yard: SceneryYard, view: GroundView, cells: Array[Vector2i],
		around: Vector2i) -> void:
	var eye := Vector3(float(around.x * CELL) + 512.0, 3500.0, float(around.y * CELL) + 512.0)
	yard.fill_around(eye)
	for i in range(30):
		yard.watch(eye, 1.0 / 30.0)
		yard.catch_up()
	var reaches: Array[float] = []
	for out in GroundView.CELLS_OUT:
		reaches.append(float(out * CELL))
	reaches.append(FAR)
	var drawn: Dictionary = {}
	var wrong_count: int = 0
	for node in view.get_children():
		var mesh_node := node as MeshInstance3D
		var cell: Vector2i = node.get_meta(&"cell")
		var level: int = node.get_meta(&"level")
		if not drawn.has(cell):
			drawn[cell] = []
		(drawn[cell] as Array).append(level)
		var n: int = CELL / GroundView.SPACINGS[level] + 1
		if mesh_node == null or (mesh_node.mesh as ArrayMesh).surface_get_array_len(0) != n * n + 4 * n:
			wrong_count += 1
	var misdrawn: int = 0
	var at_level: Array[int] = [0, 0, 0, 0]
	for cell in cells:
		var dx: float = maxf(maxf(float(cell.x * CELL) - eye.x, 0.0), eye.x - float((cell.x + 1) * CELL))
		var dz: float = maxf(maxf(float(cell.y * CELL) - eye.z, 0.0), eye.z - float((cell.y + 1) * CELL))
		var distance: float = sqrt(dx * dx + dz * dz)
		var want: int = -1
		for k in range(reaches.size()):
			if distance <= reaches[k]:
				want = k
				break
		var got: Array = drawn.get(cell, [])
		if want < 0 and not got.is_empty() or want >= 0 and (got.size() != 1 or int(got[0]) != want):
			misdrawn += 1
		elif want >= 0:
			at_level[want] += 1
	_check("in_a_yard_every_cell_within_reach_is_drawn_once_at_the_finest_level_its_distance_allows",
		misdrawn == 0 and wrong_count == 0 and at_level[0] > 0 and at_level[1] > 0 and at_level[2] > 0 and at_level[3] > 0,
		"from over %s: %s cells at 16, 32, 64 and 128 m; %d drawn wrong, %d with the wrong vertex count" % [around,
			at_level, misdrawn, wrong_count])
	_sections += 1


func _what_a_cell_costs(field: Object, cell: Vector2i) -> void:
	for level in range(GroundView.SPACINGS.size()):
		var began: int = Time.get_ticks_usec()
		var done: Dictionary = {}
		for r in range(3):
			done = GroundView.cell_arrays(field, cell, level)
		var work_ms: float = float(Time.get_ticks_usec() - began) / 3000.0
		print("[ground_view] %3d m: %.2f ms of work a cell, %d triangles, a skirt %.1f m deep" % [
			GroundView.SPACINGS[level], work_ms, (done["indices"] as PackedInt32Array).size() / 3, float(done["skirt"])])
