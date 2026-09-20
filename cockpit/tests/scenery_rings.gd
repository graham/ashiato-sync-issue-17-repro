extends Node
## Headless: does the picture keep round the eye -- built as it comes within reach, built ahead of where the eye is
## going, let go well out of reach and not before, a few a frame, and never twice for an eye going round in circles?
##
##   Godot --headless --path cockpit res://tests/scenery_rings.tscn
##
## `SceneryYard` (world/scenery_yard.gd) decides when a kilometre of scenery is built and when it is let go. On the
## island every cell is within the cameras' 24 km of every other, so nothing is ever let go there; the rings are driven
## here over the island TILED five by five -- 72 km, 1,525 cells a layer -- which is a picture only, handed to a yard
## with no level and no simulation, and moved with the yard's own `watch(eye, delta)` seam, frame by frame.
##
## THE WORK IS ON WORKER THREADS since increment 4, and this suite drives thousands of frames in the time a thread takes
## to plan one: after every `watch` it calls `catch_up`, which waits for the workers and takes their plan, as the frames
## of a real flight would. What the frame itself pays is `tests/scenery_workers.gd`'s business.
##
## Every check is a distance measured here from the cells' own bounds, never the yard's answer about itself:
##
## - AT REST, what is built is exactly what is within reach, and nothing beyond reach and the margin is kept.
## - FLOWN ACROSS, no cell comes within the eye's reach unbuilt: it was built while it was still ahead.
## - AHEAD, a cell out of reach of the eye but within reach of where it will be in `LOOK_AHEAD` seconds is built.
## - ROUND IN CIRCLES on the edge of reach, a cell is built once and not let go.
## - A JUMP across the map is filled in over several frames, none of which spends more than the budget and one cell.
## - LET GO means gone: the node is freed, and the yard no longer counts it.
## - ON THE ISLAND, filled round any eye on it, every cell is built.
##
## Read RESULT=, not the exit code.

const REACH: float = 24000.0
const RockLattice = preload("res://tests/rock_lattice.gd")
const TILES: int = 5
const FRAME: float = 1.0 / 90.0
## The plane's top speed, m/s (`tests/streaming_probe.gd --parts=speeds`).
const PLANE: float = 166.0

var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[scenery_rings] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var island: Array[Dictionary] = Terrain.boxes()
	var tiled: Array[Dictionary] = []
	var span: float = Terrain.WORLD_HALF * 2.0
	for i in range(TILES):
		for j in range(TILES):
			var offset := Vector3((float(i) - float(TILES / 2)) * span, 0.0, (float(j) - float(TILES / 2)) * span)
			for box in island:
				var copy: Dictionary = box.duplicate()
				copy["position"] = (box["position"] as Vector3) + offset
				tiled.append(copy)
	# AND ROCK ALL OVER IT, a box a kilometre: see rock_lattice.gd for why it is laid here.
	tiled.append_array(RockLattice.laid(span * float(TILES)))
	var map := WorldMap.new(tiled)
	_check("there_is_a_big_world_to_fly_over", map.cells().size() > 1000,
		"%d boxes in %d cells, %.0f km across" % [tiled.size(), map.cells().size(), span * TILES / 1000.0])

	_at_rest_what_is_built_is_what_is_in_reach(map)
	_flown_across_nothing_arrives_unbuilt(map)
	_round_in_circles_a_cell_is_built_once(map)
	_a_jump_is_filled_in_a_few_at_a_time(map)
	# AWAITED: this section waits for frames, and called bare it ran on after RESULT= had been printed.
	await _let_go_means_gone(map)
	_on_the_island_everything_is_built(island)
	_levels_are_finer_near_and_swap_without_a_hole_or_a_flap(map)
	_check("every_section_of_the_suite_ran", _sections == 7, "%d of 7" % _sections)
	_finish()


func _yard(map: WorldMap) -> SceneryYard:
	var yard := SceneryYard.new()
	add_child(yard)
	yard.set_process(false)
	yard.draw_boxes(map, REACH, false)
	return yard


## Every cell of the rock layer with the ground distance from `eye` to its bounds, measured here.
func _distances(map: WorldMap, eye: Vector3) -> Dictionary:
	var out: Dictionary = {}
	for cell in map.cells():
		var hull := AABB()
		var any: bool = false
		for box in map.boxes_in(cell):
			if int(box["group"]) != Terrain.Group.ROCK:
				continue
			var half: Vector3 = box["half_extents"]
			var one := AABB((box["position"] as Vector3) - half, half * 2.0)
			hull = one if not any else hull.merge(one)
			any = true
		if not any:
			continue
		var dx: float = maxf(maxf(hull.position.x - eye.x, 0.0), eye.x - hull.end.x)
		var dz: float = maxf(maxf(hull.position.z - eye.z, 0.0), eye.z - hull.end.z)
		out[cell] = sqrt(dx * dx + dz * dz)
	return out


## ---- at rest --------------------------------------------------------------------------------------

func _at_rest_what_is_built_is_what_is_in_reach(map: WorldMap) -> void:
	var yard := _yard(map)
	var eye := Vector3(3000.0, 500.0, -2000.0)
	yard.fill_around(eye)
	for i in range(30):
		yard.watch(eye, FRAME)
		yard.catch_up()
	var distance: Dictionary = _distances(map, eye)
	var built: Array[Vector2i] = yard.built_cells("Rock")
	var missing: int = 0
	var extra: int = 0
	for cell in distance:
		var is_built: bool = built.has(cell)
		if float(distance[cell]) <= REACH and not is_built:
			missing += 1
		if float(distance[cell]) > REACH and is_built:
			extra += 1
	_check("at_rest_every_rock_cell_within_reach_is_built_and_none_beyond",
		missing == 0 and extra == 0 and built.size() > 0,
		"%d built of %d rock cells, %d missing within %.0f m, %d built beyond it" % [built.size(), distance.size(),
			missing, REACH, extra])
	yard.queue_free()
	_sections += 1


## ---- flown across -----------------------------------------------------------------------------------

func _flown_across_nothing_arrives_unbuilt(map: WorldMap) -> void:
	var yard := _yard(map)
	var eye := Vector3(-30000.0, 600.0, -2000.0)
	yard.fill_around(eye)
	var velocity := Vector3(PLANE, 0.0, 0.0)
	var late: int = 0
	var ahead_unbuilt: int = 0
	var frames: int = int(40000.0 / PLANE / FRAME)
	var checked: int = 0
	var missed_at: Array[int] = []
	for f in range(frames):
		eye += velocity * FRAME
		yard.watch(eye, FRAME)
		yard.catch_up()
		# A LOOK A SECOND, THE FIRST A SECOND IN. The fill was made with the eye at rest, and the plan the first frame of
		# flight asks for is built on the frames after it: on a worker since increment 4, where increment 3 planned and built
		# inside that one `watch`. A look on frame 0 counted 3 cells that plan had just asked for; every later look, none.
		if f % 90 != 89:
			continue
		checked += 1
		var built: Array[Vector2i] = yard.built_cells("Rock")
		var here: Dictionary = _distances(map, eye)
		var there: Dictionary = _distances(map, eye + velocity * SceneryYard.LOOK_AHEAD)
		for cell in here:
			if float(here[cell]) <= REACH and not built.has(cell):
				late += 1
			elif float(here[cell]) > REACH and float(there[cell]) <= REACH - WorldMap.CELL and not built.has(cell):
				ahead_unbuilt += 1
				if missed_at.size() < 6 and not missed_at.has(f):
					missed_at.append(f)
	_check("flown_across_at_the_planes_top_speed_no_cell_comes_within_reach_unbuilt", late == 0 and checked > 100,
		"%d looks over %.0f km at %.0f m/s, %d cells within reach unbuilt" % [checked, 40.0, PLANE, late])
	_check("and_a_cell_within_reach_of_where_the_eye_will_be_is_built_before_it_is_within_reach_of_the_eye",
		ahead_unbuilt == 0, "%d cells a kilometre inside reach of the eye %.0f s ahead were not yet built%s" % [ahead_unbuilt,
			SceneryYard.LOOK_AHEAD, "" if missed_at.is_empty() else ", at frames %s" % [str(missed_at)]])
	yard.queue_free()
	_sections += 1


## ---- round in circles -------------------------------------------------------------------------------

func _round_in_circles_a_cell_is_built_once(map: WorldMap) -> void:
	var yard := _yard(map)
	# A HELICOPTER ORBIT OF 300 m, centred where the nearest edge of some cell's bounds is exactly REACH away: the circle
	# takes that cell in and out of reach every lap.
	var start := Vector3(0.0, 300.0, 0.0)
	var distance: Dictionary = _distances(map, start)
	var edge_cell := Vector2i.ZERO
	var best: float = INF
	for cell in distance:
		var off: float = absf(float(distance[cell]) - REACH)
		if off < best:
			best = off
			edge_cell = cell
	var centre: Vector3 = start
	yard.fill_around(centre)
	var built_before: int = yard.built
	var let_go_before: int = yard.let_go
	var laps: int = 0
	var heli: float = 28.0
	var radius: float = 300.0
	var frames: int = int(TAU * radius / heli / FRAME) * 6
	for f in range(frames):
		var angle: float = heli * float(f) * FRAME / radius
		yard.watch(centre + Vector3(cos(angle), 0.0, sin(angle)) * radius, FRAME)
		yard.catch_up()
	laps = int(float(frames) * FRAME * heli / (TAU * radius))
	var built_during: int = yard.built - built_before
	var let_go_during: int = yard.let_go - let_go_before
	_check("round_in_circles_on_the_edge_of_reach_a_cell_is_built_at_most_once_and_never_let_go",
		let_go_during == 0 and built_during <= distance.size(),
		"%d laps of %.0f m at %.0f m/s round a cell %.0f m off the edge of reach: %d built, %d let go" % [laps, radius, heli,
			best, built_during, let_go_during])
	yard.queue_free()
	_sections += 1


## ---- a jump ----------------------------------------------------------------------------------------

func _a_jump_is_filled_in_a_few_at_a_time(map: WorldMap) -> void:
	var yard := _yard(map)
	yard.fill_around(Vector3(-30000.0, 500.0, -30000.0))
	yard.most_frame_usec = 0
	var there := Vector3(30000.0, 500.0, 30000.0)
	var frames: int = 0
	var worst: int = 0
	while frames < 2000:
		yard.most_frame_usec = 0
		yard.watch(there, FRAME)
		worst = maxi(worst, yard.most_frame_usec)
		yard.catch_up()
		frames += 1
		var distance: Dictionary = _distances(map, there)
		var wanted: int = 0
		for cell in distance:
			if float(distance[cell]) <= REACH:
				wanted += 1
		if yard.built_cells("Rock").size() >= wanted and frames > 1:
			break
	_check("a_jump_across_the_map_is_filled_in_over_several_frames_none_over_the_budget_and_one_cell",
		frames > 1 and worst <= SceneryYard.ATTACH_BUDGET_USEC + yard.most_cell_usec,
		"%d frames to fill, the worst %d us against a budget of %d and a largest cell of %d us" % [frames, worst,
			SceneryYard.ATTACH_BUDGET_USEC, yard.most_cell_usec])
	yard.queue_free()
	_sections += 1


## ---- let go ----------------------------------------------------------------------------------------

func _let_go_means_gone(map: WorldMap) -> void:
	var yard := _yard(map)
	var eye := Vector3(-30000.0, 500.0, 0.0)
	yard.fill_around(eye)
	var held: Array[MultiMeshInstance3D] = yard.box_batches()
	for i in range(40):
		yard.watch(Vector3(30000.0, 500.0, 0.0), FRAME)
		yard.catch_up()
	# A queue_free lands at the END of a frame, after that frame's process_frame: two, to be past it.
	await get_tree().process_frame
	await get_tree().process_frame
	var alive: int = 0
	for node in held:
		if is_instance_valid(node):
			alive += 1
	var counted_far: int = 0
	var distance: Dictionary = _distances(map, Vector3(30000.0, 500.0, 0.0))
	for cell in yard.built_cells("Rock"):
		if float(distance.get(cell, 0.0)) > REACH + SceneryYard.LET_GO_BEYOND:
			counted_far += 1
	_check("a_cell_let_go_is_freed_and_no_longer_counted", alive < held.size() and counted_far == 0 and yard.let_go > 0,
		"%d of %d batches from the first place still alive two frames after moving 60 km, %d let go, %d beyond the margin still counted"
			% [alive, held.size(), yard.let_go, counted_far])
	yard.queue_free()
	_sections += 1


## ---- the island -------------------------------------------------------------------------------------

func _on_the_island_everything_is_built(island: Array[Dictionary]) -> void:
	var map := WorldMap.new(island)
	var short: PackedStringArray = []
	for eye in [Vector3(-7000.0, 500.0, -7000.0), Vector3(7000.0, 500.0, 7000.0), Vector3.ZERO, Vector3(-2200.0, 80.0, 9800.0)]:
		var yard := _yard(map)
		yard.fill_around(eye)
		var built: int = yard.built_cells("Rock").size() + yard.built_cells("Concrete").size()
		var every: int = yard.cells_of("Rock").size() + yard.cells_of("Concrete").size()
		if built != every:
			short.append("%s: %d of %d" % [eye, built, every])
		yard.free()
	_check("on_the_island_every_cell_is_built_from_anywhere_on_it_and_from_the_carrier", short.is_empty(),
		"four eyes%s" % ("" if short.is_empty() else ": %s" % [str(short)]))
	_sections += 1


## ---- levels ----------------------------------------------------------------------------------------

## A LEVELLED LAYER over the rock cells' bounds, at two levels, built by a spy: its work returns the cell and the level it
## was asked for, and its build counts every time it is handed numbers for another cell or level. What is drawn is read
## off the spy's nodes in the tree, never off the yard.
const LEVEL_REACHES: Array[float] = [4000.0, 12000.0]

func _levels_are_finer_near_and_swap_without_a_hole_or_a_flap(map: WorldMap) -> void:
	var hulls: Dictionary = _rock_hulls(map)
	var wrong: Array[int] = [0]
	var spy := func() -> Array:
		var yard := SceneryYard.new()
		add_child(yard)
		yard.set_process(false)
		var holder := Node3D.new()
		add_child(holder)
		# THE WORK, on a worker: its cell and level, after the shipped slow-work seam, naming its class for the static.
		var work := func(cell: Vector2i, level: int) -> Dictionary:
			if SceneryYard.work_delay_msec > 0:
				OS.delay_msec(SceneryYard.work_delay_msec)
			return {"cell": cell, "level": level}
		yard.add_level_layer("Levels", hulls, LEVEL_REACHES, holder, work, func(cell: Vector2i, level: int,
				done: Dictionary) -> Array[Node3D]:
			if done.get("cell", Vector2i(-99999, -99999)) != cell or int(done.get("level", -1)) != level:
				wrong[0] += 1
			var node := Node3D.new()
			node.set_meta(&"cell", cell)
			node.set_meta(&"level", level)
			var out: Array[Node3D] = [node]
			return out)
		return [yard, holder]

	# AT REST, EVERY CELL AT THE FINEST LEVEL ITS DISTANCE ALLOWS, and none drawn twice.
	var rest: Array = spy.call()
	var eye := Vector3(3000.0, 500.0, -2000.0)
	(rest[0] as SceneryYard).fill_around(eye)
	for i in range(30):
		(rest[0] as SceneryYard).watch(eye, FRAME)
		(rest[0] as SceneryYard).catch_up()
	var drawn: Dictionary = _drawn_levels(rest[1])
	var misdrawn: int = 0
	var doubled: int = 0
	var counts: Array[int] = [0, 0]
	for cell in hulls:
		var want: int = _finest(_to(hulls[cell], eye))
		var got: Array = drawn.get(cell, [])
		doubled += 1 if got.size() > 1 else 0
		if want < 0 and not got.is_empty() or want >= 0 and (got.size() != 1 or int(got[0]) != want):
			misdrawn += 1
		elif want >= 0:
			counts[want] += 1
	_check("levels_at_rest_every_cell_is_drawn_once_at_the_finest_level_its_distance_allows",
		misdrawn == 0 and doubled == 0 and counts[0] > 0 and counts[1] > 0,
		"%d at level 0 within %.0f m, %d at level 1 within %.0f m; %d drawn wrong, %d drawn twice" % [counts[0],
			LEVEL_REACHES[0], counts[1], LEVEL_REACHES[1], misdrawn, doubled])
	_let_go_of(rest)

	# FLOWN ACROSS: a cell drawn on one frame and still within the last reach is drawn on the next, never twice, and a cell a
	# kilometre inside level 0's reach is drawn at level 0.
	var flight: Array = spy.call()
	var yard: SceneryYard = flight[0]
	eye = Vector3(-20000.0, 600.0, -2000.0)
	yard.fill_around(eye)
	var velocity := Vector3(PLANE, 0.0, 0.0)
	var frame: float = 1.0 / 30.0
	var before: Dictionary = _drawn_levels(flight[1])
	var holes: int = 0
	var twice: int = 0
	var coarse_near: int = 0
	var frames: int = int(40000.0 / PLANE / frame)
	for f in range(frames):
		eye += velocity * frame
		yard.watch(eye, frame)
		yard.catch_up()
		var now: Dictionary = _drawn_levels(flight[1])
		for cell in before:
			if not now.has(cell) and _to(hulls[cell], eye) <= LEVEL_REACHES[1]:
				holes += 1
		for cell in now:
			twice += 1 if (now[cell] as Array).size() > 1 else 0
			if f % 30 == 29 and f > 30 and _to(hulls[cell], eye) <= LEVEL_REACHES[0] - WorldMap.CELL \
					and not (now[cell] as Array).has(0):
				coarse_near += 1
		before = now
	_check("levels_flown_across_no_cell_within_reach_is_ever_left_with_nothing_drawn_or_drawn_twice",
		holes == 0 and twice == 0 and yard.swapped > 0,
		"%d frames over 40 km at %.0f m/s: %d swaps, %d cells drawn then not while within %.0f m, %d frames drawn twice" % [
			frames, PLANE, yard.swapped, holes, LEVEL_REACHES[1], twice])
	_check("and_a_cell_a_kilometre_inside_the_finest_reach_is_drawn_at_the_finest_level", coarse_near == 0,
		"%d looks found a cell that near drawn coarser" % coarse_near)
	_let_go_of(flight)

	# ROUND IN CIRCLES on level 0's boundary: after the first lap, no cell swaps again.
	var circling: Array = spy.call()
	yard = circling[0]
	var centre := Vector3(0.0, 300.0, 0.0)
	var best: float = INF
	for cell in hulls:
		best = minf(best, absf(_to(hulls[cell], centre) - LEVEL_REACHES[0]))
	yard.fill_around(centre)
	var heli: float = 28.0
	var radius: float = 300.0
	var lap: int = int(TAU * radius / heli / frame)
	var swaps_after_first_lap: int = 0
	for f in range(lap * 6):
		if f == lap:
			swaps_after_first_lap = yard.swapped
		var angle: float = heli * float(f) * frame / radius
		yard.watch(centre + Vector3(cos(angle), 0.0, sin(angle)) * radius, frame)
		yard.catch_up()
	var flaps: int = yard.swapped - swaps_after_first_lap
	_check("levels_round_in_circles_on_the_finest_levels_boundary_no_cell_swaps_after_the_first_lap", flaps == 0,
		"5 more laps of %.0f m round a cell %.0f m off level 0's edge: %d swaps" % [radius, best, flaps])
	_let_go_of(circling)

	_check("levels_every_build_was_handed_the_numbers_worked_out_for_its_own_cell_and_level", wrong[0] == 0,
		"%d builds handed another cell's or level's numbers" % wrong[0])
	_sections += 1


## The finest level whose reach a distance is within, or -1 past the last: worked out here, not asked of the yard.
static func _finest(distance: float) -> int:
	for k in range(LEVEL_REACHES.size()):
		if distance <= LEVEL_REACHES[k]:
			return k
	return -1


## Every rock cell's hull, measured here from its boxes.
static func _rock_hulls(map: WorldMap) -> Dictionary:
	var out: Dictionary = {}
	for cell in map.cells():
		var hull := AABB()
		var any: bool = false
		for box in map.boxes_in(cell):
			if int(box["group"]) != Terrain.Group.ROCK:
				continue
			var half: Vector3 = box["half_extents"]
			var one := AABB((box["position"] as Vector3) - half, half * 2.0)
			hull = one if not any else hull.merge(one)
			any = true
		if any:
			out[cell] = hull
	return out


## From a point to the nearest point of a hull, on the ground.
static func _to(hull: AABB, eye: Vector3) -> float:
	var dx: float = maxf(maxf(hull.position.x - eye.x, 0.0), eye.x - hull.end.x)
	var dz: float = maxf(maxf(hull.position.z - eye.z, 0.0), eye.z - hull.end.z)
	return sqrt(dx * dx + dz * dz)


## Cell -> the levels of the spy's nodes in the tree for it.
static func _drawn_levels(holder: Node3D) -> Dictionary:
	var out: Dictionary = {}
	for node in holder.get_children():
		var cell: Vector2i = node.get_meta(&"cell")
		if not out.has(cell):
			out[cell] = []
		(out[cell] as Array).append(int(node.get_meta(&"level")))
	return out


func _let_go_of(pair: Array) -> void:
	(pair[0] as SceneryYard).catch_up()
	(pair[0] as Node).free()
	(pair[1] as Node).free()


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
