extends Node
## Headless: does the simulation stand on the ground the function describes -- and ask it the questions it asked the
## island's slab?
##
##   Godot --headless --path cockpit res://tests/ground_collision.tscn
##
## THE GROUND IS NOT REPLICATED (agents.md, RULES 8). Every peer lays it from `GroundField` as Box3D height fields, and
## a peer whose hillside is anywhere else predicts itself into the server's. None of that shows in a picture or a count,
## so every check here is against something the simulation did not compute (`ashiato-gd/src/cockpit/bedrock.hpp`):
##
## - EVERY LAND CELL HAS ITS FIELDS. The cells with any sample above -40 m, found here from `GroundField.heights`, are the
##   cells the world built; a cell whose samples span more than 65,535 ticks is four, and a quarter that still does is
##   four again; no field lost a height.
## - A RAY DOWN LANDS ON THE DRAWN GROUND (T2). At 10,000 random land points Box3D's own ray finds the ground within a
##   millimetre of the triangle worked out here from the four samples round the point, on Box3D's diagonal; a ray from
##   half a metre above reaches it and one from a metre and a half does not. The simulation's `ground_height_at` is the
##   same triangle.
## - THE PYRAMID IS NEVER OPTIMISTIC (T6). Random legs over the land at three clearances: every one the world calls
##   clear stands clear of the drawn ground sampled here every 2 m, and both answers are given often enough to mean it.
##   And a level leg a quarter of a metre under every summit standing between a pyramid square's corners is called
##   blocked.
## - EVERY PEER LAYS THE SAME GROUND (T9). A client's hash of every field equals the server's, and another seed's does
##   not -- the second half is what shows the hash can tell two worlds apart at all.
## - WITH NO GROUND THE ISLAND ANSWERS AS BEFORE, and with one the leg test the autopilots ask sees it: a leg through the
##   highest summit is clear in a world with no ground and blocked in one with it.
## - A TANKER SCOOPS FROM A LAKE (T8) at its own level, well above the sea's, and from the sea, and not from the lake's
##   shallow shore or over its rim.
## - A PARKED AEROPLANE HOLDS ON A SLOPE (T4): a light aeroplane set down with its brakes on ground of 3, 8 and 12
##   degrees moves under half a metre in 30 s, and with them off on 8 degrees it rolls.
##
## The world is the game's (`GroundTuning`): 64 km, ranges to 3,000 m, seed 0.
##
## Read RESULT=, not the exit code.

const HZ: float = 120.0
const TICKS_PER_METRE: float = 32.0
const SPACING: int = 16
const CELL: int = 1024
## A cell whose every sample is at or under this, in ticks, is open sea.
const SEA_FLOOR_TICKS: int = -40 * 32
const FIELD_RANGE_TICKS: int = 65535
const RAY_POINTS: int = 10000
const LEG_POINTS: int = 1000
const WITHIN: float = 0.001
const PYRAMID_LEGS: int = 600
## Legs flown just under a summit of the drawn ground, each 20 m, a quarter of a metre under a sample that stands at
## least 1.5 m above every other within 32 m, so the pyramid's rounding up to whole metres cannot hide one. The ground
## is smooth: the game's world has 22 such summits between pyramid corners, and every one is flown under.
const LEAST_SUMMITS: int = 20
const SUMMIT_PROUD_TICKS: int = 48
const UNDER_SUMMIT: float = 0.25
const SUMMIT_LEG_HALF: float = 10.0
## [clearance, overhead]: a look ahead, a leg kept, and the bare ground.
const CLEARANCES: Array = [[30.0, 0.0], [60.0, 60.0], [0.0, 0.0]]
const SAMPLE_EVERY: float = 2.0
## The least share of the legs each answer must be given on, or the check never tested anything.
const LEAST_SHARE: float = 0.1
const SCOOP_OVER: float = 10.0
const SCOOP_SPEED: float = 45.0
## A lake whose level is under this cannot tell a scoop over its own water from one over the sea's 15 m.
const LAKE_HIGHER_THAN: float = 30.0
const SHALLOW: float = 3.0
const SLOPES: Array[float] = [3.0, 8.0, 12.0]
const SLOPE_WITHIN: float = 0.75
const PARK_SECONDS: float = 30.0
const PARKED_MOVES_LESS_THAN: float = 0.5
const UNBRAKED_ROLLS_MORE_THAN: float = 5.0

var _failures: PackedStringArray = []
var _origin: int = 0
var _cells: int = 0
var _next_client: int = 700


func _check(label: String, ok: bool, detail: String) -> void:
	print("[ground_collision] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var can: bool = ClassDB.class_exists("GroundField") and ClassDB.class_exists("CockpitWorld") \
		and ClassDB.class_has_method("CockpitWorld", "set_ground")
	_check("the_extension_can_stand_a_world_on_the_ground", can, "engine %s, double=%s" % [
		Engine.get_version_info()["string"], OS.has_feature("double")])
	if not can:
		_finish()
		return
	var ground: Object = ClassDB.instantiate("GroundField")
	var problems: PackedStringArray = ground.call("configure", GroundTuning.values())
	_check("the_games_world_configures", problems.is_empty(), str(problems))
	var half: int = int(GroundTuning.values()["world_half"])
	_cells = 2 * ((half + CELL - 1) / CELL)
	_origin = -(_cells / 2) * CELL

	var world: Object = _world(0, ground)
	var land: Dictionary = _land_cells(ground)
	_every_land_cell_has_its_fields(world, land)
	_a_ray_down_lands_on_the_drawn_ground(world, ground, land)
	_the_pyramid_is_never_optimistic(world, ground, land)
	_a_leg_just_under_a_summit_is_never_called_clear(world, ground, land)
	_every_peer_lays_the_same_ground(world, ground)
	_with_no_ground_the_island_answers_as_before(world, ground)
	_a_tanker_scoops_from_a_lake_and_not_from_its_shore(world, ground)
	_a_flying_boat_floats_over_shallow_water_and_not_on_dry_land(world, ground)
	_a_parked_aeroplane_holds_on_a_slope(world, ground, land)
	world.teardown()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()


## ---- the fields --------------------------------------------------------------------------------------------------

## Cell (column along x, row along z) -> the fields it takes, for every cell with a sample above the sea floor.
func _land_cells(ground: Object) -> Dictionary:
	var land: Dictionary = {}
	var samples: int = CELL / SPACING + 1
	for row in range(_cells):
		for column in range(_cells):
			var heights: PackedInt32Array = ground.heights(_origin + column * CELL, _origin + row * CELL, samples,
				samples, SPACING)
			var sorted: PackedInt32Array = heights.duplicate()
			sorted.sort()
			if sorted[sorted.size() - 1] <= SEA_FLOOR_TICKS:
				continue
			var span: int = sorted[sorted.size() - 1] - sorted[0]
			land[Vector2i(column, row)] = 1 if span <= FIELD_RANGE_TICKS else _fields_for(heights, samples, 0, 0, samples - 1)
	return land


## The fields a square of samples takes: one if its range holds, else those of its four quarters, down to 32 m.
static func _fields_for(heights: PackedInt32Array, samples: int, first_column: int, first_row: int, span: int) -> int:
	var low: int = 1 << 30
	var high: int = -(1 << 30)
	for r in range(span + 1):
		for c in range(span + 1):
			var at: int = heights[(first_row + r) * samples + first_column + c]
			low = mini(low, at)
			high = maxi(high, at)
	if high - low <= FIELD_RANGE_TICKS or span <= 2:
		return 1
	var half: int = span / 2
	var total: int = 0
	for quarter in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		total += _fields_for(heights, samples, first_column + quarter.x * half, first_row + quarter.y * half, half)
	return total


func _every_land_cell_has_its_fields(world: Object, land: Dictionary) -> void:
	var fields: int = 0
	var split: int = 0
	for cell in land:
		fields += int(land[cell])
		split += 1 if int(land[cell]) > 1 else 0
	var report: Dictionary = world.ground_report()
	_check("every_land_cell_has_a_field_and_every_tall_one_as_many_as_hold_it",
		int(report.get("fields", -1)) == fields and int(report.get("land_cells", -1)) == land.size()
			and int(report.get("split_cells", -1)) == split,
		"%d land cells, %d split, %d fields; the world laid %s" % [land.size(), split, fields, report])
	_check("no_field_lost_a_height", int(report.get("unheld_fields", -1)) == 0,
		"%s fields spanned more than one range" % report.get("unheld_fields", "?"))
	print("[ground_collision] laid in %.0f ms: %.1f MB of fields, %.1f MB of pyramid" % [
		float(report.get("build_usec", 0)) / 1000.0, float(report.get("bytes", 0)) / 1048576.0,
		float(report.get("pyramid_bytes", 0)) / 1048576.0])


## ---- the drawn ground ------------------------------------------------------------------------------------------

## The height of the triangle over `at`, from its square's four samples in `corners` from `first`: (x, z), (x + 16, z),
## (x, z + 16), (x + 16, z + 16). Split on the diagonal from (x + 16, z) to (x, z + 16), as Box3D splits it.
static func _drawn(at: Vector2, corners: PackedInt32Array, first: int) -> float:
	var gx: float = at.x / SPACING
	var gz: float = at.y / SPACING
	var u: float = gx - floorf(gx)
	var v: float = gz - floorf(gz)
	var h11: float = corners[first]
	var h12: float = corners[first + 1]
	var h21: float = corners[first + 2]
	var h22: float = corners[first + 3]
	var ticks: float = h11 + u * (h12 - h11) + v * (h21 - h11) if u + v <= 1.0 \
		else h22 + (1.0 - u) * (h21 - h22) + (1.0 - v) * (h12 - h22)
	return ticks / TICKS_PER_METRE


static func _corners_of(at: Vector2, into: PackedInt32Array) -> void:
	var i: int = floori(at.x / SPACING)
	var j: int = floori(at.y / SPACING)
	into.append_array([i * SPACING, j * SPACING, (i + 1) * SPACING, j * SPACING, i * SPACING, (j + 1) * SPACING,
		(i + 1) * SPACING, (j + 1) * SPACING])


## A random point in a random land cell, rounded to a float32 as the physics holds it. Box3D is built single precision
## in both libraries (`b3_pos` narrows every position), so on the double editor a ray asked at an exact double starts
## four millimetres away 32 km out, and on steep ground that was a 2.7 mm miss the stock editor never showed.
func _land_point(rng: RandomNumberGenerator, cells: Array) -> Vector2:
	var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
	var held := PackedFloat32Array([_origin + cell.x * CELL + rng.randf_range(0.0, CELL),
		_origin + cell.y * CELL + rng.randf_range(0.0, CELL)])
	return Vector2(held[0], held[1])


func _a_ray_down_lands_on_the_drawn_ground(world: Object, ground: Object, land: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260914
	var cells: Array = land.keys()
	var points: Array[Vector2] = []
	var corners := PackedInt32Array()
	for k in range(RAY_POINTS):
		var at: Vector2 = _land_point(rng, cells)
		points.append(at)
		_corners_of(at, corners)
	var heights: PackedInt32Array = ground.heights_at(corners)
	var missed: int = 0
	var worst_ray: float = 0.0
	var worst_height: float = 0.0
	var reached: int = 0
	var short: int = 0
	for k in range(points.size()):
		var at: Vector2 = points[k]
		var drawn: float = _drawn(at, heights, 4 * k)
		var below: float = world.first_solid_below(Vector3(at.x, drawn + 50.0, at.y), 100.0)
		if below < 0.0:
			missed += 1
		else:
			worst_ray = maxf(worst_ray, absf(drawn + 50.0 - below - drawn))
		worst_height = maxf(worst_height, absf(float(world.ground_height_at(at.x, at.y)) - drawn))
		if k < LEG_POINTS:
			reached += 1 if world.first_solid_below(Vector3(at.x, drawn + 0.5, at.y), 1.0) >= 0.0 else 0
			short += 1 if world.first_solid_below(Vector3(at.x, drawn + 1.5, at.y), 1.0) < 0.0 else 0
	_check("a_ray_down_lands_on_the_drawn_ground_within_a_millimetre", missed == 0 and worst_ray <= WITHIN,
		"%d points, %d missed, worst %.3f mm" % [points.size(), missed, worst_ray * 1000.0])
	_check("a_ray_from_half_a_metre_up_reaches_it_and_from_a_metre_and_a_half_does_not",
		reached == LEG_POINTS and short == LEG_POINTS, "%d and %d of %d" % [reached, short, LEG_POINTS])
	_check("the_simulations_ground_height_is_the_drawn_triangle", worst_height <= WITHIN,
		"worst %.3f mm" % (worst_height * 1000.0))


## ---- the pyramid ---------------------------------------------------------------------------------------------------

func _the_pyramid_is_never_optimistic(world: Object, ground: Object, land: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var cells: Array = land.keys()
	var clear: int = 0
	var blocked: int = 0
	var optimistic: int = 0
	var worst: String = ""
	var asked_usec: int = 0
	for n in range(PYRAMID_LEGS):
		var from: Vector2 = _land_point(rng, cells)
		var bearing: float = rng.randf_range(0.0, TAU)
		var span: float = rng.randf_range(200.0, 1200.0)
		var held := Vector3(from.x + sin(bearing) * span, 0.0, from.y - cos(bearing) * span)
		var to := Vector2(held.x, held.z)
		var a := Vector3(from.x, float(world.ground_height_at(from.x, from.y)) + rng.randf_range(20.0, 400.0), from.y)
		var b := Vector3(to.x, float(world.ground_height_at(to.x, to.y)) + rng.randf_range(20.0, 400.0), to.y)
		var grid: Dictionary = {}
		for pair in CLEARANCES:
			var clearance: float = pair[0]
			var overhead: float = pair[1]
			var began: int = Time.get_ticks_usec()
			var called_clear: bool = world.ground_leg_is_clear(a, b, clearance, overhead)
			asked_usec += Time.get_ticks_usec() - began
			if not called_clear:
				blocked += 1
				continue
			clear += 1
			if grid.is_empty():
				grid = _heights_under(ground, a, b)
			var found: String = _first_sample_under(grid, a, b, minf(clearance, overhead))
			if not found.is_empty():
				optimistic += 1
				worst = "clearance %.0f overhead %.0f: %s" % [clearance, overhead, found]
	var asked: int = clear + blocked
	_check("the_pyramid_never_calls_a_leg_clear_that_the_drawn_ground_blocks", optimistic == 0,
		"%d of %d called clear were not%s" % [optimistic, clear, "; " + worst if not worst.is_empty() else ""])
	_check("and_it_gave_both_answers_often_enough_to_mean_it",
		clear >= int(asked * LEAST_SHARE) and blocked >= int(asked * LEAST_SHARE),
		"%d clear, %d blocked, %.2f us a leg" % [clear, blocked, float(asked_usec) / maxf(asked, 1)])


## The 16 m samples over a leg's footprint, one call: {x0, z0, count_x, heights}.
func _heights_under(ground: Object, a: Vector3, b: Vector3) -> Dictionary:
	# One sample of margin on every side of the squares the leg crosses.
	var first_x: int = floori(minf(a.x, b.x) / SPACING) - 1
	var first_z: int = floori(minf(a.z, b.z) / SPACING) - 1
	var x0: int = first_x * SPACING
	var z0: int = first_z * SPACING
	var count_x: int = floori(maxf(a.x, b.x) / SPACING) + 2 - first_x + 1
	var count_z: int = floori(maxf(a.z, b.z) / SPACING) + 2 - first_z + 1
	return {"x0": x0, "z0": z0, "count_x": count_x,
		"heights": ground.heights(x0, z0, count_x, count_z, SPACING)}


## The first point along the leg, every 2 m, no higher than `lift` over the drawn ground; empty if none.
func _first_sample_under(grid: Dictionary, a: Vector3, b: Vector3, lift: float) -> String:
	var steps: int = maxi(1, ceili(Vector2(b.x - a.x, b.z - a.z).length() / SAMPLE_EVERY))
	for s in range(steps + 1):
		var p: Vector3 = a.lerp(b, float(s) / float(steps))
		var ground: float = _drawn_in(grid, p)
		if p.y - lift <= ground:
			return "at (%.0f, %.1f, %.0f) over ground at %.1f" % [p.x, p.y, p.z, ground]
	return ""


## The drawn ground at a point, from a grid `_heights_under` fetched round it.
static func _drawn_in(grid: Dictionary, p: Vector3) -> float:
	var heights: PackedInt32Array = grid["heights"]
	var count_x: int = grid["count_x"]
	var i: int = floori(p.x / SPACING) - int(grid["x0"]) / SPACING
	var j: int = floori(p.z / SPACING) - int(grid["z0"]) / SPACING
	var corners := PackedInt32Array([heights[j * count_x + i], heights[j * count_x + i + 1],
		heights[(j + 1) * count_x + i], heights[(j + 1) * count_x + i + 1]])
	return _drawn(Vector2(p.x, p.z), corners, 0)


## LEGS JUST UNDER SUMMITS. A pyramid square's corners are samples 32 m apart, so what a pyramid built from corners
## forgets is a sample between them standing above every corner round it. Each leg here is 20 m, level, a quarter of a
## metre under such a sample -- one not on a corner and standing at least 1.5 m above all 24 others within 32 m -- and
## every one must be called blocked. Random legs never came near enough to tell, and nor did short legs grazing the
## highest ground under random lines, which usually had higher ground within 32 m uphill: a pyramid built from four
## corners passed both.
func _a_leg_just_under_a_summit_is_never_called_clear(world: Object, ground: Object, land: Dictionary) -> void:
	var samples: int = CELL / SPACING + 1
	var legs: int = 0
	var called_clear: int = 0
	var worst: String = ""
	for cell in land:
		var x0: int = _origin + cell.x * CELL
		var z0: int = _origin + cell.y * CELL
		var heights: PackedInt32Array = ground.heights(x0, z0, samples, samples, SPACING)
		for j in range(2, samples - 2):
			for i in range(2, samples - 2):
				if i % 2 == 0 and j % 2 == 0:
					continue
				var peak: int = heights[j * samples + i]
				if peak <= heights[j * samples + i - 1] or peak <= heights[j * samples + i + 1] \
						or peak <= heights[(j - 1) * samples + i] or peak <= heights[(j + 1) * samples + i]:
					continue
				var proud: bool = true
				for dj in range(-2, 3):
					for di in range(-2, 3):
						if (di != 0 or dj != 0) and peak - heights[(j + dj) * samples + i + di] < SUMMIT_PROUD_TICKS:
							proud = false
				if not proud:
					continue
				var top: float = float(peak) / TICKS_PER_METRE
				var at := Vector3(x0 + i * SPACING, top - UNDER_SUMMIT, z0 + j * SPACING)
				var along := Vector3(SUMMIT_LEG_HALF, 0.0, 0.0)
				legs += 1
				if world.ground_leg_is_clear(at - along, at + along, 0.0, 0.0):
					called_clear += 1
					worst = "under the summit at (%.0f, %.2f, %.0f)" % [at.x, top, at.z]
	_check("there_are_summits_to_fly_just_under", legs >= LEAST_SUMMITS, "%d found, at least %d wanted" % [legs, LEAST_SUMMITS])
	_check("a_leg_just_under_a_summit_is_never_called_clear", called_clear == 0,
		"%d of %d called clear%s" % [called_clear, legs, "; " + worst if not worst.is_empty() else ""])


## ---- the peers ----------------------------------------------------------------------------------------------------

func _every_peer_lays_the_same_ground(server: Object, ground: Object) -> void:
	var client: Object = _world(1, ground)
	var laid: Dictionary = server.ground_report()
	var copied: Dictionary = client.ground_report()
	_check("a_client_lays_the_ground_the_server_laid",
		not laid.is_empty() and laid.get("hash") == copied.get("hash") and laid.get("fields") == copied.get("fields")
			and laid.get("bytes") == copied.get("bytes"),
		"server %s, client %s" % [laid.get("hash"), copied.get("hash")])
	client.teardown()
	var values: Dictionary = GroundTuning.values()
	values["seed"] = int(values["seed"]) + 1
	var other: Object = ClassDB.instantiate("GroundField")
	other.call("configure", values)
	var elsewhere: Object = _world(0, other)
	_check("and_the_hash_tells_another_world_apart", elsewhere.ground_report().get("hash") != laid.get("hash"),
		"seed %d: %s" % [values["seed"], elsewhere.ground_report().get("hash")])
	elsewhere.teardown()


func _with_no_ground_the_island_answers_as_before(world: Object, ground: Object) -> void:
	# THE HIGHEST SAMPLE on a 256 m grid, and a leg straight through it 200 m under its top.
	var step: int = 256
	var count: int = _cells * CELL / step + 1
	var heights: PackedInt32Array = ground.heights(_origin, _origin, count, count, step)
	var best: int = 0
	for k in range(heights.size()):
		if heights[k] > heights[best]:
			best = k
	var top := Vector3(_origin + (best % count) * step, float(heights[best]) / TICKS_PER_METRE, _origin + (best / count) * step)
	var from := Vector3(top.x - 3000.0, top.y - 200.0, top.z)
	var to := Vector3(top.x + 3000.0, top.y - 200.0, top.z)
	var bare: Object = _world(0, null)
	_check("with_no_ground_a_world_has_none", bare.ground_report().is_empty()
		and is_zero_approx(bare.ground_height_at(top.x, top.z)) and bare.first_solid_below(top + Vector3.UP * 50.0, 100.0) < 0.0,
		"report %s" % bare.ground_report())
	_check("and_a_leg_through_the_highest_summit_is_clear_without_it_and_blocked_with_it",
		bare.leg_is_clear(from, to, 60.0, 60.0) and not world.leg_is_clear(from, to, 60.0, 60.0),
		"summit at %s" % top)
	bare.teardown()


## ---- the water -----------------------------------------------------------------------------------------------------

func _a_tanker_scoops_from_a_lake_and_not_from_its_shore(world: Object, ground: Object) -> void:
	var no_water: int = ClassDB.class_get_integer_constant("GroundField", "NO_WATER")
	var lake: Vector2 = Vector2.INF
	for entry in (ground.catalogue()["lakes"] as Array):
		var x: int = int(entry["x"])
		var z: int = int(entry["z"])
		var water: int = ground.water_ticks_at(x, z)
		if water > no_water and float(water) / TICKS_PER_METRE > LAKE_HIGHER_THAN \
				and float(water - int(ground.height_ticks_at(x, z))) / TICKS_PER_METRE > 2.0 * SHALLOW:
			lake = Vector2(x, z)
			break
	_check("there_is_a_lake_high_enough_to_test", lake != Vector2.INF, "a lake over %.0f m" % LAKE_HIGHER_THAN)
	if lake == Vector2.INF:
		return
	var level: float = float(ground.water_ticks_at(int(lake.x), int(lake.y))) / TICKS_PER_METRE
	# OUT FROM THE MIDDLE, a metre at a time, to the first shallow water and then the first dry ground.
	var shore: Vector2 = Vector2.INF
	var rim: Vector2 = Vector2.INF
	for d in range(1, 3000):
		var x: int = int(lake.x) + d
		var water: int = ground.water_ticks_at(x, int(lake.y))
		if water <= no_water:
			rim = Vector2(x + 30, lake.y)
			break
		if shore == Vector2.INF and float(water - int(ground.height_ticks_at(x, int(lake.y)))) / TICKS_PER_METRE < SHALLOW * 0.5:
			shore = Vector2(x, lake.y)
	var half: int = int(GroundTuning.values()["world_half"])
	var sea := Vector2(half - 1500, 0)
	var sea_deep: bool = ground.water_ticks_at(int(sea.x), 0) == 0 and ground.height_ticks_at(int(sea.x), 0) < -20 * 32
	_check("and_it_has_a_shallow_shore_a_rim_and_a_deep_sea_to_try", shore != Vector2.INF and rim != Vector2.INF and sea_deep,
		"shore %s, rim %s, sea deep %s" % [shore, rim, sea_deep])
	if shore == Vector2.INF or rim == Vector2.INF or not sea_deep:
		return
	var places: Array = [["the_lake", lake, level, true], ["its_shallow_shore", shore, level, false],
		["over_its_rim", rim, float(world.ground_height_at(rim.x, rim.y)), false], ["the_sea", sea, 0.0, true]]
	var tankers: Array[int] = []
	for place in places:
		var at: Vector2 = place[1]
		tankers.append(int(world.spawn_vehicle(Sim.Kind.TANKER, Vector3(at.x, float(place[2]) + SCOOP_OVER, at.y),
			PI * 0.5, Vector3(-SCOOP_SPEED, 0.0, 0.0))))
	world.tick(1.0 / HZ)
	for k in range(places.size()):
		var scooping: bool = world.is_scooping_now(tankers[k])
		_check("a_tanker_%.0f_m_over_%s_%s" % [SCOOP_OVER, places[k][0], "scoops" if places[k][3] else "does_not_scoop"],
			scooping == bool(places[k][3]), "at %s, flown %.0f m over %.1f m" % [places[k][1], SCOOP_OVER, float(places[k][2])])


## ---- a flying boat, over shallow water and on dry land -----------------------------------------------------------

## HOW FAR BELOW THE HULL'S MIDDLE THE UNDERCARRIAGE LOOKS FOR GROUND, m: the tanker's half-height 1.70 plus the legs'
## reach 0.60 (`kWheelReach`), typed. Floating, the hull's middle stands 1.09 m over the water (`tanker_shape`'s
## waterline), so the legs' ray reaches 1.21 m BELOW THE SURFACE -- and any lakebed or seabed shallower than that is
## "something solid" to it.
const LEGS_REACH_UNDER_THE_SURFACE: float = 1.21
## The depth of water the check wants: deeper than the hull sits in it (its 0.59 m draught), so the hull is not on the
## bottom, and shallower than the legs' reach, so a ray-for-ground would find the bottom.
const SHALLOWER_THAN_THE_LEGS: Vector2 = Vector2(0.75, 1.10)


## OVER SHALLOW WATER A FLYING BOAT IS AFLOAT; PARKED ON THE DRY SHORE BESIDE IT, IT IS NOT.
##
## WHY IT IS HERE AND NOT IN `water.gd`: this is the game's own generated world, with a real water map. The question is
## how the simulation tells "on land" from "in the water" for an amphibian, and on the first build it asked the
## undercarriage's ray for solid ground -- which on a runway is right and over a shallow bay is WRONG: the seabed is a
## collider (`tests/seabed.gd`), so the ray finds a lakebed 1 m down exactly as it finds tarmac, and the hull loses the
## sea it is sitting in. Geometry alone cannot separate them -- a flying boat whose wheels just reach a sandbar is shaped
## exactly like one parked on a runway -- so ONLY A WATER MAP CAN, and this is the one world with one. team-lead asked
## for this case before the change was allowed to land.
##
## `hull_wet` is what the sea's forces returned: above zero means they acted.
func _a_flying_boat_floats_over_shallow_water_and_not_on_dry_land(world: Object, ground: Object) -> void:
	if not world.has_method("hull_wet"):
		_check("the_simulation_says_how_wet_a_flying_boats_hull_is", false, "no hull_wet in this library")
		return
	var no_water: int = ClassDB.class_get_integer_constant("GroundField", "NO_WATER")
	# A LAKE, AND A SPOT IN IT OF THE DEPTH WANTED, walked out from its middle a metre at a time; and the first dry
	# ground past its edge.
	var shallow: Vector3 = Vector3.INF
	var dry: Vector3 = Vector3.INF
	for entry in (ground.catalogue()["lakes"] as Array):
		var cx: int = int(entry["x"])
		var cz: int = int(entry["z"])
		if ground.water_ticks_at(cx, cz) <= no_water:
			continue
		var level: float = float(ground.water_ticks_at(cx, cz)) / TICKS_PER_METRE
		for d in range(1, 3000):
			var x: int = cx + d
			var water: int = ground.water_ticks_at(x, cz)
			if water <= no_water:
				dry = Vector3(x + 20, float(world.ground_height_at(x + 20, cz)), cz)
				break
			# THE DEPTH TO THE GROUND THE PHYSICS COLLIDES WITH, not to the field's own height ticks. The first run
			# chose by the ticks and got a spot where the collision's height field stood 4.1 m ABOVE the water -- a
			# steep shore sampled coarser -- so the "shallow water" was dry land to the ray, and the check would have
			# been about the wrong place. What the legs' ray hits is the height field, so the depth is taken to it.
			var depth: float = level - float(world.ground_height_at(x, cz))
			if shallow == Vector3.INF and depth > SHALLOWER_THAN_THE_LEGS.x and depth < SHALLOWER_THAN_THE_LEGS.y:
				shallow = Vector3(x, level, cz)
		if shallow != Vector3.INF and dry != Vector3.INF:
			break
	_check("there_is_a_lake_with_water_shallower_than_the_legs_reach_and_a_dry_shore",
		shallow != Vector3.INF and dry != Vector3.INF,
		"water %.2f to %.2f m deep, under the legs' %.2f m reach, at %s; dry ground at %s"
			% [SHALLOWER_THAN_THE_LEGS.x, SHALLOWER_THAN_THE_LEGS.y, LEGS_REACH_UNDER_THE_SURFACE, shallow, dry])
	if shallow == Vector3.INF or dry == Vector3.INF:
		return
	# AT REST ON THE WATER, AND AT REST ON THE SHORE: the same aeroplane, two places, ten seconds.
	var afloat: int = int(world.spawn_vehicle(Sim.Kind.TANKER, shallow + Vector3(0.0, 1.3, 0.0), 0.0, Vector3.ZERO))
	var parked: int = int(world.spawn_vehicle(Sim.Kind.TANKER, dry + Vector3(0.0, 2.5, 0.0), 0.0, Vector3.ZERO))
	var wet_afloat: float = 0.0
	var wet_parked: float = 0.0
	for i in range(int(10.0 * HZ)):
		world.tick(1.0 / HZ)
		wet_afloat = maxf(wet_afloat, float(world.hull_wet(afloat)))
		wet_parked = maxf(wet_parked, float(world.hull_wet(parked)))
	var depth_here: float = shallow.y - float(world.ground_height_at(shallow.x, shallow.z))
	_check("over_water_shallower_than_its_legs_reach_a_flying_boat_is_afloat", wet_afloat > 0.0,
		"in %.2f m of water, its hull was %.3f wet -- the legs' ray reaches %.2f m under the surface and finds the bed"
			% [depth_here, wet_afloat, LEGS_REACH_UNDER_THE_SURFACE])
	_check("and_parked_on_the_dry_shore_beside_it_its_hull_is_not_in_any_water", wet_parked == 0.0,
		"on dry ground at h %.1f, its hull was %s wet" % [dry.y, wet_parked])

## ---- the brakes ----------------------------------------------------------------------------------------------------

func _a_parked_aeroplane_holds_on_a_slope(world: Object, ground: Object, land: Dictionary) -> void:
	var found: Dictionary = _slopes(ground, land)
	_check("there_is_ground_of_every_slope_to_park_on", found.size() == SLOPES.size(), "found %s" % [found.keys()])
	if found.size() != SLOPES.size():
		return
	var half: float = (world.kind_geometry(Sim.Kind.PLANE).get("extents", Vector3.ONE) as Vector3).y
	var parked: Array = []
	for angle in SLOPES:
		parked.append([angle, true])
	parked.append([8.0, false])
	var inputs: Dictionary = {}
	for row in parked:
		var place: Array = found[row[0]]
		var at: Vector2 = place[0]
		var downhill: Vector2 = place[1]
		var y: float = float(world.ground_height_at(at.x, at.y)) + half + 0.3
		if not row[1]:
			at += Vector2(-downhill.y, downhill.x) * 60.0
			y = float(world.ground_height_at(at.x, at.y)) + half + 0.3
		_next_client += 1
		var seat: Dictionary = world.spawn_pilot(_next_client, Sim.Kind.PLANE, Vector3(at.x, y, at.y),
			atan2(-downhill.x, -downhill.y), Vector3.ZERO)
		row.append(int(seat.get("vehicle", 0)))
		inputs[int(seat.get("pilot", 0))] = _controls({"brake": 1.0 if row[1] else 0.0})
	for i in range(int(HZ)):
		_tick_with(world, inputs)
	for row in parked:
		row.append(world.vehicle_state(row[2]).get("position", Vector3.ZERO))
	for i in range(int(PARK_SECONDS * HZ)):
		_tick_with(world, inputs)
	for row in parked:
		var start: Vector3 = row[3]
		var now: Vector3 = world.vehicle_state(row[2]).get("position", Vector3.ZERO)
		var moved: float = Vector2(now.x - start.x, now.z - start.z).length()
		if row[1]:
			_check("a_light_aeroplane_braked_on_%d_degrees_holds" % int(row[0]), moved < PARKED_MOVES_LESS_THAN,
				"moved %.2f m in %.0f s" % [moved, PARK_SECONDS])
		else:
			_check("and_unbraked_on_%d_degrees_rolls" % int(row[0]), moved > UNBRAKED_ROLLS_MORE_THAN,
				"moved %.2f m in %.0f s" % [moved, PARK_SECONDS])


## Slope in degrees -> [point, downhill direction], each on ground that stays that steep and that way for 32 m round it.
func _slopes(ground: Object, land: Dictionary) -> Dictionary:
	var found: Dictionary = {}
	var samples: int = CELL / SPACING + 1
	for cell in land:
		var x0: int = _origin + cell.x * CELL
		var z0: int = _origin + cell.y * CELL
		var heights: PackedInt32Array = ground.heights(x0, z0, samples, samples, SPACING)
		for j in range(4, samples - 4, 4):
			for i in range(4, samples - 4, 4):
				var gradient: Vector2 = _gradient(heights, samples, i, j)
				var angle: float = rad_to_deg(atan(gradient.length()))
				for wanted in SLOPES:
					if found.has(wanted) or absf(angle - wanted) > SLOPE_WITHIN * 0.5:
						continue
					var steady: bool = true
					for o in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2)]:
						var there: Vector2 = _gradient(heights, samples, i + o.x, j + o.y)
						steady = steady and absf(rad_to_deg(atan(there.length())) - wanted) <= SLOPE_WITHIN \
							and there.normalized().dot(gradient.normalized()) > 0.98
					if steady:
						found[wanted] = [Vector2(x0 + i * SPACING, z0 + j * SPACING), -gradient.normalized()]
		if found.size() == SLOPES.size():
			break
	return found


## Rise over run at a sample, from its neighbours either side.
static func _gradient(heights: PackedInt32Array, samples: int, i: int, j: int) -> Vector2:
	var dx: float = float(heights[j * samples + i + 1] - heights[j * samples + i - 1]) / TICKS_PER_METRE / (2.0 * SPACING)
	var dz: float = float(heights[(j + 1) * samples + i] - heights[(j - 1) * samples + i]) / TICKS_PER_METRE / (2.0 * SPACING)
	return Vector2(dx, dz)


## ---- helpers -------------------------------------------------------------------------------------------------------

func _world(client_id: int, ground: Object) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(HZ)
	world.start(client_id)
	if ground != null:
		world.set_ground(ground)
	return world


func _tick_with(world: Object, inputs: Dictionary) -> void:
	for pilot in inputs:
		world.set_pilot_input(pilot, inputs[pilot])
	world.tick(1.0 / HZ)


## A complete control frame, as the loopback builds it.
static func _controls(overrides: Dictionary) -> Dictionary:
	var input: Dictionary = {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0,
	}
	for key in overrides:
		input[key] = overrides[key]
	return input
