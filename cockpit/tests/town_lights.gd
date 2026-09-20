extends Node
## Headless: does every building carry far lights that stand where its windows are, carry what its windows give, are
## drawn as far as the building is, arrive and leave with it, and are worked out off the frame?
##
##   Godot --headless --path cockpit res://tests/town_lights.tscn
##
## Asked for on 2026-09-15: "I should be able to see the lights on a building from farther away". A far light is a point
## `TownView` puts off a wall for every `TownTuning.FAR_LIGHT_WINDOWS` windows a side (world/shaders/town_lights.gdshaderinc),
## and the wall hands its lights to it across the band before `windows_to`. What a picture cannot be trusted to show, and
## is held here against something the lights did not compute:
##
## - THE WALL. Every point stands `FAR_LIGHT_OFF_WALL` out from one wall of a building in the list, inside that wall's
##   extent, and its out axis points away from that building's middle -- worked out here from the box, never from
##   `TownView.lights_on_a_wall`.
## - THE WINDOWS. What a building's points carry, in square metres of wall, is its four walls' area, less only the part
##   cells too narrow to hold half a window.
## - THE REACH. A kilometre's lights are drawn at least as far as its buildings, and `FAR` beyond their own furthest point.
## - THE HANDOVER. Flown out 14 km and back at the plane's speed with the scenery drawn to `FLOWN_REACH`, so every kilometre
##   is let go and built again on the way, frame by frame: no kilometre of buildings built without its lights (a hole),
##   none with two sets (a double), and no lights built without their buildings. At the level's 24 km a flight off the
##   island lets nothing go, and the first run of this check passed on 0 cells built.
## - OFF THE FRAME. Every cell's work slowed to 50 ms, and no `watch` takes that long while lights arrive.
## - ONE FUNCTION. The wall's shader and the lights' take their share of the handover from `town_far_share`, and nothing
##   else in either works it out.
## - THE BUDGET, asked for on 2026-09-15: every kilometre's far lights worked out here, one after another, and the slowest
##   under `CELL_BUILD_MSEC` (the work a worker does, timed where it can be timed); and the instance data of the island
##   tiled `TILED` times -- the 72 km world `tests/scenery_memory.gd` flies, every kilometre of which the yard could be
##   holding -- under `TILED_MB`. Printed per cell for a person.
##   TIMED FIVE TIMES A KILOMETRE AND THE FASTEST KEPT. A kilometre's work is milliseconds of GDScript, and on a machine running
##   other lanes' suites one timing is the work plus whatever took the core from it: cockpit-terrain's runs read the inner
##   city at 14.2 to 15.4 ms beside other full runs, where the same code, alternated three times each under the same load
##   against 352a15fc (before any obstruction light), read 3.81 / 4.24 / 3.84 ms there and 4.21 / 3.99 / 3.89 ms on main
##   45627150, medians 3.84 and 3.99 (2026-09-15). GDScript has no clock for a thread's own CPU time -- Time.get_ticks_usec
##   is the wall's -- so the least interrupted of `BUDGET_TRIES` is the reading; a slower work raises all of them, and so
##   the fastest.
##
## Read RESULT=, not the exit code.

const FAR: float = 24000.0
## The reach the flight is drawn to: short enough that a 14 km leg lets the island go and builds it again.
const FLOWN_REACH: float = 4000.0
## How long, in real milliseconds, a section waits for workers: a suite's frames go by far faster than a worker's 50 ms.
const WAIT_MSEC: int = 20000
const FRAME: float = 1.0 / 90.0
const PLANE: float = 166.0
const WORK_MSEC: int = 50
const SAME: float = 0.01
## The budget: one kilometre's far lights worked out in under this many milliseconds, and the island's far lights tiled
## TILED times -- tests/scenery_memory.gd's 72 km world -- in under TILED_MB of instance data.
const CELL_BUILD_MSEC: float = 10.0
const TILED: int = 25
const TILED_MB: float = 20.0
## How many times each kilometre's work is timed for the budget, the fastest kept: see THE BUDGET at the top.
const BUDGET_TRIES: int = 5

var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[town_lights] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var solid: Array[Dictionary] = Terrain.boxes()
	var map := WorldMap.new(solid)
	var buildings: Array[Dictionary] = []
	for box in solid:
		if int(box["group"]) == Terrain.Group.BUILDING:
			buildings.append(box)
	var pair: Array = _towns(map)
	(pair[0] as SceneryYard).fill_around(Vector3.ZERO)
	_every_far_light_stands_off_a_wall_of_its_building(buildings, pair[1])
	_every_buildings_far_lights_carry_its_walls(buildings, pair[1])
	_every_kilometres_lights_are_drawn_as_far_as_its_buildings(pair[1])
	(pair[0] as Node).queue_free()
	await _flown_out_and_back_every_kilometre_of_buildings_has_its_lights_once(map)
	await _the_far_lights_are_worked_off_the_frame(map)
	_the_handover_is_one_function()
	_the_far_lights_fit_their_budget(map)
	SceneryYard.work_delay_msec = 0
	_check("every_section_of_the_suite_ran", _sections == 7, "%d of 7" % _sections)
	_finish()


func _towns(map: WorldMap, reach: float = FAR) -> Array:
	var yard := SceneryYard.new()
	add_child(yard)
	yard.set_process(false)
	var towns := TownView.new()
	add_child(towns)
	towns.draw_towns(map, [] as Array[Dictionary], reach, yard)
	return [yard, towns]


## Every far light, as `{at, out, area, cell}` in the world, read out of the very buffer each batch was handed (row
## `row` of the basis at `row * 4`, followed by that row's origin; the custom data after the 12 transform floats --
## `SceneryYard.put_transform`'s layout). The batch keeps nothing else: see `TownView.lights_buffer`.
static func _points(towns: TownView) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var stride: int = SceneryYard.TRANSFORM_FLOATS + SceneryYard.EXTRA_FLOATS
	for batch in towns.light_batches():
		var buffer: PackedFloat32Array = batch.get_meta(&"buffer", PackedFloat32Array())
		for i in range(buffer.size() / stride):
			var o: int = i * stride
			out.append({"at": batch.position + Vector3(buffer[o + 3], buffer[o + 7], buffer[o + 11]),
				"out": Vector3(buffer[o + 2], buffer[o + 6], buffer[o + 10]), "area": buffer[o + SceneryYard.TRANSFORM_FLOATS],
				"cell": batch.get_meta(&"cell")})
	return out


## ---- the wall ------------------------------------------------------------------------------------

func _every_far_light_stands_off_a_wall_of_its_building(buildings: Array[Dictionary], towns: TownView) -> void:
	var points: Array[Dictionary] = _points(towns)
	var astray: Array[String] = []
	var facing_in: int = 0
	for point in points:
		var at: Vector3 = point["at"]
		var out: Vector3 = point["out"]
		var found: bool = false
		for building in buildings:
			var centre: Vector3 = building["position"]
			var half: Vector3 = building["half_extents"]
			var from: Vector3 = at - centre
			# ON WHICH WALL, asked of the box: the axis it stands furthest out along, by the box's own size.
			var wall_out: float = maxf(absf(from.x) - half.x, absf(from.z) - half.z)
			if absf(wall_out - TownTuning.FAR_LIGHT_OFF_WALL) > SAME or absf(from.y) > half.y + SAME:
				continue
			var along_x: bool = absf(from.x) - half.x < absf(from.z) - half.z
			if along_x and absf(from.x) > half.x + SAME or not along_x and absf(from.z) > half.z + SAME:
				continue
			found = true
			var away := Vector3(0.0, 0.0, signf(from.z)) if along_x else Vector3(signf(from.x), 0.0, 0.0)
			if out.distance_to(away) > SAME:
				facing_in += 1
			break
		if not found and astray.size() < 4:
			astray.append("%s in %s" % [at.round(), point["cell"]])
		elif not found:
			astray.append("")
	_check("every_far_light_stands_off_a_wall_of_a_building_in_the_list_and_faces_away_from_it",
		points.size() > 1000 and astray.is_empty() and facing_in == 0,
		"%d points; %d on no wall %s; %d facing into their building" % [points.size(), astray.size(),
			astray.slice(0, 4), facing_in])
	_sections += 1


## ---- the windows ---------------------------------------------------------------------------------

func _every_buildings_far_lights_carry_its_walls(buildings: Array[Dictionary], towns: TownView) -> void:
	var carried: float = 0.0
	for point in _points(towns):
		carried += float(point["area"])
	var walls: float = 0.0
	for building in buildings:
		var half: Vector3 = building["half_extents"]
		walls += 2.0 * (half.x * 2.0 + half.z * 2.0) * half.y * 2.0
	var share: float = carried / maxf(walls, 1.0)
	_check("the_far_lights_carry_the_wall_area_of_every_building_less_only_its_part_cells",
		share > 0.9 and share <= 1.0 + SAME,
		"%.0f m2 carried of %.0f m2 of wall on %d buildings: %.3f" % [carried, walls, buildings.size(), share])
	_sections += 1


## ---- the reach -----------------------------------------------------------------------------------

func _every_kilometres_lights_are_drawn_as_far_as_its_buildings(towns: TownView) -> void:
	var ends: Dictionary = {}
	for batch in towns.building_batches():
		ends[batch.get_meta(&"cell")] = batch.visibility_range_end
	var short: Array[String] = []
	for batch in towns.light_batches():
		var cell: Vector2i = batch.get_meta(&"cell")
		var furthest: float = 0.0
		var buffer: PackedFloat32Array = batch.get_meta(&"buffer", PackedFloat32Array())
		var stride: int = SceneryYard.TRANSFORM_FLOATS + SceneryYard.EXTRA_FLOATS
		for i in range(buffer.size() / stride):
			var o: int = i * stride
			furthest = maxf(furthest, Vector3(buffer[o + 3], buffer[o + 7], buffer[o + 11]).length())
		if not ends.has(cell) or batch.visibility_range_end < float(ends[cell]) \
				or batch.visibility_range_end < FAR + furthest - SAME:
			short.append("%s ends at %.0f, its buildings at %s, wants %.0f" % [cell, batch.visibility_range_end,
				ends.get(cell, "none"), FAR + furthest])
	_check("every_kilometres_far_lights_are_drawn_as_far_as_its_buildings_and_its_furthest_point",
		not towns.light_batches().is_empty() and towns.light_batches().size() == ends.size() and short.is_empty(),
		"%d light batches, %d building batches%s" % [towns.light_batches().size(), ends.size(),
			"" if short.is_empty() else ": %s" % [short.slice(0, 3)]])
	_sections += 1


## ---- the handover -------------------------------------------------------------------------------

func _flown_out_and_back_every_kilometre_of_buildings_has_its_lights_once(map: WorldMap) -> void:
	var pair: Array = _towns(map, FLOWN_REACH)
	var yard: SceneryYard = pair[0]
	var towns: TownView = pair[1]
	var eye := Vector3(0.0, 500.0, 0.0)
	yard.fill_around(eye)
	var holes: int = 0
	var doubles: int = 0
	var orphans: int = 0
	var frames: int = 0
	var let_go_before: int = yard.let_go
	var built_before: int = yard.built
	# OUT 14 km AND BACK, far enough at FLOWN_REACH that every kilometre of the island is let go and built again.
	for leg in [Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0)]:
		var travelled: float = 0.0
		while travelled < 14000.0:
			eye += (leg as Vector3) * PLANE * FRAME * 8.0
			travelled += PLANE * FRAME * 8.0
			# THE TIME THE STEP TOOK, eight frames: told one frame for eight frames' distance, the yard read 1,328 m/s, looked
			# 13 km ahead and let nothing go in 14 km (the second run of this check, 0 cells built on the way).
			yard.watch(eye, FRAME * 8.0)
			if frames % 8 == 0:
				yard.catch_up()
			frames += 1
			var walls: Dictionary = {}
			var lights: Dictionary = {}
			for child in towns.get_children():
				var batch := child as MultiMeshInstance3D
				# The obstruction lights are a third node on a kilometre of buildings, and neither its walls nor its far lights.
				if batch == null or batch.is_queued_for_deletion() or bool(batch.get_meta(&"obstruction", false)):
					continue
				var into: Dictionary = lights if bool(batch.get_meta(&"lights", false)) else walls
				var cell: Vector2i = batch.get_meta(&"cell")
				into[cell] = int(into.get(cell, 0)) + 1
			for cell in walls:
				if not lights.has(cell):
					holes += 1
			for cell in lights:
				if int(lights[cell]) > 1 or int(walls.get(cell, 0)) > 1:
					doubles += 1
				if not walls.has(cell):
					orphans += 1
			await get_tree().process_frame
	_check("flown_14_km_out_and_back_no_kilometre_of_buildings_is_drawn_without_its_lights_or_with_two",
		holes == 0 and doubles == 0 and orphans == 0 and yard.let_go > let_go_before and yard.built > built_before,
		"%d frames, %d cells let go and %d built on the way; %d holes, %d doubles, %d lights with no buildings" % [
			frames, yard.let_go - let_go_before, yard.built - built_before, holes, doubles, orphans])
	yard.queue_free()
	towns.queue_free()
	await get_tree().process_frame
	_sections += 1


## ---- off the frame -------------------------------------------------------------------------------

func _the_far_lights_are_worked_off_the_frame(map: WorldMap) -> void:
	var pair: Array = _towns(map)
	var yard: SceneryYard = pair[0]
	var towns: TownView = pair[1]
	yard.fill_around(Vector3(0.0, 500.0, 60000.0))
	SceneryYard.work_delay_msec = WORK_MSEC
	var worst_usec: int = 0
	var frames: int = 0
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < WAIT_MSEC and towns.light_batches().size() < yard.cells_of(TownView.BUILDINGS).size():
		var t: int = Time.get_ticks_usec()
		yard.watch(Vector3(0.0, 500.0, 0.0), FRAME)
		worst_usec = maxi(worst_usec, Time.get_ticks_usec() - t)
		await get_tree().process_frame
		frames += 1
	SceneryYard.work_delay_msec = 0
	_check("with_every_cells_work_slowed_to_50_ms_the_far_lights_arrive_and_no_watch_waits_for_one",
		towns.light_batches().size() == yard.cells_of(TownView.BUILDINGS).size() and worst_usec < WORK_MSEC * 1000,
		"%d of %d kilometres lit over %d frames; the worst watch %d us against one cell's work of %d us" % [
			towns.light_batches().size(), yard.cells_of(TownView.BUILDINGS).size(), frames, worst_usec, WORK_MSEC * 1000])
	yard.queue_free()
	towns.queue_free()
	await get_tree().process_frame
	_sections += 1


## ---- one function --------------------------------------------------------------------------------

func _the_handover_is_one_function() -> void:
	var wall: String = FileAccess.get_file_as_string("res://world/shaders/building.gdshaderinc")
	var lights: String = FileAccess.get_file_as_string("res://world/shaders/town_lights.gdshaderinc")
	var once: String = FileAccess.get_file_as_string("res://world/shaders/town_handover.gdshaderinc")
	var wrong: Array[String] = []
	if wall.count("town_far_share(far, windows_to)") != 1:
		wrong.append("the wall does not take 1 - town_far_share(far, windows_to) once")
	if lights.count("town_far_share(away, windows_to)") != 1:
		wrong.append("the lights do not take town_far_share(away, windows_to) once")
	for text in [wall, lights]:
		if text.contains("windows_to *"):
			wrong.append("a shader works the band out beside the function")
	if once.count("smoothstep(") != 1:
		wrong.append("the handover is not one smoothstep")
	_check("the_wall_and_the_far_lights_take_the_handover_from_one_function_and_nowhere_else", wrong.is_empty(),
		"; ".join(wrong) if not wrong.is_empty() else "building.gdshaderinc and town_lights.gdshaderinc each call it once")
	_sections += 1


## ---- the budget ---------------------------------------------------------------------------------

func _the_far_lights_fit_their_budget(map: WorldMap) -> void:
	var stride: int = SceneryYard.TRANSFORM_FLOATS + SceneryYard.EXTRA_FLOATS
	var total: int = 0
	var slowest_msec: float = 0.0
	var densest: int = 0
	var rows: PackedStringArray = []
	for cell in map.cells():
		var mine: Array[Dictionary] = []
		for box in map.boxes_in(cell):
			if int(box["group"]) == Terrain.Group.BUILDING:
				mine.append(box)
		if mine.is_empty():
			continue
		var done: Dictionary = {}
		var msec: float = INF
		for attempt in range(BUDGET_TRIES):
			var began: int = Time.get_ticks_usec()
			done = TownView.lights_buffer(mine, Vector3.ZERO)
			msec = minf(msec, float(Time.get_ticks_usec() - began) / 1000.0)
		var count: int = int(done["count"])
		total += count
		densest = maxi(densest, count)
		slowest_msec = maxf(slowest_msec, msec)
		rows.append("%s: %d buildings, %d points, %.0f KB, %.2f ms fastest of %d" % [cell, mine.size(), count,
			float((done["buffer"] as PackedFloat32Array).size() * 4) / 1024.0, msec, BUDGET_TRIES])
	print("[town_lights] far lights by kilometre: %s" % "; ".join(rows))
	var island_mb: float = float(total * stride * 4) / 1048576.0
	_check("every_kilometres_far_lights_are_worked_out_inside_the_budget_and_the_72_km_world_holds_them_in_it",
		total > 0 and slowest_msec < CELL_BUILD_MSEC and island_mb * TILED < TILED_MB,
		"%d points on the island in %d kilometres, the densest %d; %.2f MB of instance data, %.1f MB tiled %d times (under %.0f); the slowest kilometre %.2f ms (under %.0f)" % [
			total, rows.size(), densest, island_mb, island_mb * TILED, TILED, TILED_MB, slowest_msec, CELL_BUILD_MSEC])
	_sections += 1


func _finish() -> void:
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
