extends Node
## Headless: is what the yard holds bounded by the ring round the eye, never by the distance flown -- and does turning back
## build from what was kept, rather than working a cell out again?
##
##   Godot --headless --path cockpit res://tests/scenery_memory.tscn
##
## The user's world is 30 to 70 km. On the island every cell is within reach of every other and nothing is ever let go, so
## this flies the island tiled five by five (72 km), a picture only: the yard's rock and concrete and `TownView`'s
## buildings and paint, handed to a yard with no level and no simulation, moved through `watch` and given the workers'
## time with `catch_up`, as `tests/scenery_rings.gd` does.
##
## - TURNING BACK: filled at home, the eye moved 6 km away until nothing more changes, then home again. Every cell let go
##   on the way out and built again at home is built from the numbers kept for it: no work is started on the way back.
##   The eye is moved with `watch(eye, 0.0)`, which keeps its velocity at none, so the point ahead is the eye and nothing
##   beyond home is wanted.
## - MEMORY: a lawnmower of three 60 km rows across the map, 220 km at the plane's top speed. The flight's last third
##   visits ground its first third never saw; the live cells, the nodes in the tree and the engine's static memory in the
##   last third may not pass the first third's peak by more than 5 %, and the cells kept never pass `KEEP_CELLS`.
##
## Read RESULT=, not the exit code.

const REACH: float = 24000.0
const TILES: int = 5
const PLANE: float = 166.0
## Thirty frames a second: the yard's rules are in metres, and 5.5 m a frame re-plans as often as 1.8 m does.
const FRAME: float = 1.0 / 30.0
const SLACK: float = 1.05


const RockLattice = preload("res://tests/rock_lattice.gd")
var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[scenery_memory] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
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
	_turning_back_builds_from_what_was_kept(map)
	_swapping_back_to_a_kept_level_starts_no_work(map)
	await _memory_is_bounded_by_the_ring_not_the_distance_flown(map, island)
	_check("every_section_of_the_suite_ran", _sections == 3, "%d of 3" % _sections)
	_finish()


## ---- turning back --------------------------------------------------------------------------------------

func _turning_back_builds_from_what_was_kept(map: WorldMap) -> void:
	var yard := SceneryYard.new()
	add_child(yard)
	yard.set_process(false)
	yard.draw_boxes(map, REACH, false)
	var home := Vector3(-6000.0, 500.0, 0.0)
	var away := Vector3(0.0, 500.0, 0.0)
	yard.fill_around(home)
	var let_go_home: int = yard.let_go
	var out_frames: int = _settle(yard, away)
	var let_go_out: int = yard.let_go - let_go_home
	var works_then: int = yard.works_started
	var hits_then: int = yard.kept_hits
	var built_then: int = yard.built
	var back_frames: int = _settle(yard, home)
	var works_back: int = yard.works_started - works_then
	var hits_back: int = yard.kept_hits - hits_then
	var built_back: int = yard.built - built_then
	# AND HOME IS WHOLE AGAIN: every rock cell within reach of home is built, measured here from the cells' own boxes.
	var missing: int = 0
	var built_rock: Array[Vector2i] = yard.built_cells("Rock")
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
		if any and _ground(home, hull) <= REACH and not built_rock.has(cell):
			missing += 1
	_check("turning_back_over_ground_just_left_builds_every_cell_from_what_was_kept_and_starts_no_work",
		let_go_out > 0 and built_back > 0 and works_back == 0 and hits_back == built_back and missing == 0,
		"%d cells let go over %d frames going 6 km out; coming back over %d frames, %d built, %d of them from what was kept, %d works started; %d rock cells within reach of home unbuilt; %d kept of %d allowed"
			% [let_go_out, out_frames, back_frames, built_back, hits_back, works_back, missing, yard.kept_count(),
				SceneryYard.keep_cells])
	yard.free()
	_sections += 1


## ---- a kept level ----------------------------------------------------------------------------------------------

## LEVELS KEEP THEIR NUMBERS TOO: a levelled layer over the rock cells, filled at home, where the nearest cells are drawn at
## the finest level. The eye goes 6 km away, so they swap to the coarser level and their fine numbers are kept, then home
## again: every swap back to the fine level is built from what was kept, and no work is started for it. The keep is made
## large for this, so a cell dropped from it for want of room cannot pass as a cell that was never kept.
const LEVEL_REACHES: Array[float] = [4000.0, 12000.0]

func _swapping_back_to_a_kept_level_starts_no_work(map: WorldMap) -> void:
	var yard := SceneryYard.new()
	add_child(yard)
	yard.set_process(false)
	var holder := Node3D.new()
	add_child(holder)
	var hulls: Dictionary = {}
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
			hulls[cell] = hull
	# EVERY BUILD HANDED ITS OWN LEVEL'S NUMBERS: counted here, where swaps back take numbers from the keep. The flight in
	# tests/scenery_rings.gd never swaps back, and numbers kept under the wrong level passed its count of the same.
	var wrong: Array[int] = [0]
	yard.add_level_layer("Levels", hulls, LEVEL_REACHES, holder,
		func(cell: Vector2i, level: int) -> Dictionary: return {"cell": cell, "level": level},
		func(cell: Vector2i, level: int, done: Dictionary) -> Array[Node3D]:
			if done.get("cell", Vector2i(-99999, -99999)) != cell or int(done.get("level", -1)) != level:
				wrong[0] += 1
			var node := Node3D.new()
			node.set_meta(&"cell", cell)
			var out: Array[Node3D] = [node]
			return out)
	var keep_was: int = SceneryYard.keep_cells
	SceneryYard.keep_cells = 8192
	var home := Vector3(-6000.0, 500.0, 0.0)
	var away := Vector3(0.0, 500.0, 0.0)
	# FAR ENOUGH THAT HOME IS LET GO: a cell drawn fine at home was swapped coarse at `away`, keeping its fine numbers, and is
	# let go here, keeping its coarse ones -- so coming home it has both levels kept, and must take the fine one.
	var far := Vector3(16000.0, 500.0, 0.0)
	yard.fill_around(home)
	var swapped_home: int = yard.swapped
	_settle(yard, away)
	var swapped_out: int = yard.swapped - swapped_home
	var let_go_before_far: int = yard.let_go
	_settle(yard, far)
	var let_go_far: int = yard.let_go - let_go_before_far
	var works_then: int = yard.works_started
	var hits_then: int = yard.kept_hits
	var swapped_then: int = yard.swapped
	var built_then: int = yard.built
	_settle(yard, home)
	var works_back: int = yard.works_started - works_then
	var hits_back: int = yard.kept_hits - hits_then
	var swapped_back: int = yard.swapped - swapped_then
	var built_back: int = yard.built - built_then
	var coarse_at_home: int = 0
	for cell in hulls:
		var hull: AABB = hulls[cell]
		var dx: float = maxf(maxf(hull.position.x - home.x, 0.0), home.x - hull.end.x)
		var dz: float = maxf(maxf(hull.position.z - home.z, 0.0), home.z - hull.end.z)
		if sqrt(dx * dx + dz * dz) <= LEVEL_REACHES[0] and yard.level_of("Levels", cell) != 0:
			coarse_at_home += 1
	SceneryYard.keep_cells = keep_was
	_check("swapping_back_to_a_kept_finer_level_builds_from_what_was_kept_and_starts_no_work",
		swapped_out > 0 and let_go_far > 0 and built_back > 0 and works_back == 0 and hits_back == swapped_back + built_back
			and coarse_at_home == 0,
		"%d swapped going 6 km out, %d let go going 22 km out; coming home %d swapped and %d built, %d of them from what was kept, %d works started; %d cells within %.0f m of home not drawn at level 0"
			% [swapped_out, let_go_far, swapped_back, built_back, hits_back, works_back, coarse_at_home, LEVEL_REACHES[0]])
	_check("and_every_build_there_and_back_was_handed_its_own_cell_and_levels_numbers", wrong[0] == 0,
		"%d builds handed another cell's or level's numbers" % wrong[0])
	yard.free()
	holder.free()
	_sections += 1


## `watch` at `eye` with no velocity, the workers caught up each time, until neither a build, a swap nor a let-go has
## happened for thirty frames. Returns the frames it took.
func _settle(yard: SceneryYard, eye: Vector3) -> int:
	var frames: int = 0
	var quiet: int = 0
	var last: Array = [-1, -1, -1]
	while frames < 4000 and quiet < 30:
		yard.watch(eye, 0.0)
		yard.catch_up()
		frames += 1
		var now: Array = [yard.built, yard.let_go, yard.swapped]
		quiet = quiet + 1 if now == last else 0
		last = now
	return frames


## ---- memory -----------------------------------------------------------------------------------------------

func _memory_is_bounded_by_the_ring_not_the_distance_flown(map: WorldMap, island: Array[Dictionary]) -> void:
	var yard := SceneryYard.new()
	add_child(yard)
	yard.set_process(false)
	yard.draw_boxes(map, REACH, false)
	var towns := TownView.new()
	add_child(towns)
	towns.draw_towns(map, TownPlan.streets() + TownPlan.road_marks(Terrain.roads(island)), REACH, yard)
	var route: Array[Vector3] = [Vector3(-30000.0, 600.0, -20000.0), Vector3(30000.0, 600.0, -20000.0),
		Vector3(30000.0, 600.0, 0.0), Vector3(-30000.0, 600.0, 0.0), Vector3(-30000.0, 600.0, 20000.0),
		Vector3(30000.0, 600.0, 20000.0)]
	var length: float = 0.0
	for i in range(route.size() - 1):
		length += route[i].distance_to(route[i + 1])
	yard.fill_around(route[0])
	# EACH THIRD's peaks: live cells, nodes in the tree, static memory in MB, cells kept.
	var peaks: Array = [[0, 0, 0.0, 0], [0, 0, 0.0, 0], [0, 0, 0.0, 0]]
	var frames: int = int(length / PLANE / FRAME)
	var leg: int = 0
	var along_leg: float = 0.0
	var eye: Vector3 = route[0]
	for f in range(frames):
		along_leg += PLANE * FRAME
		while leg < route.size() - 2 and along_leg > route[leg].distance_to(route[leg + 1]):
			along_leg -= route[leg].distance_to(route[leg + 1])
			leg += 1
		eye = route[leg] + (route[leg + 1] - route[leg]).normalized() * minf(along_leg, route[leg].distance_to(route[leg + 1]))
		yard.watch(eye, FRAME)
		yard.catch_up()
		# A REAL FRAME EVERY FRAME, so every node let go is freed before it is counted.
		await get_tree().process_frame
		if f % 30 != 0:
			continue
		var third: int = mini(int(float(f) / float(frames) * 3.0), 2)
		var row: Array = peaks[third]
		row[0] = maxi(int(row[0]), yard.built_count())
		row[1] = maxi(int(row[1]), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		row[2] = maxf(float(row[2]), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
		row[3] = maxi(int(row[3]), yard.kept_count())
	var first: Array = peaks[0]
	var last: Array = peaks[2]
	var detail: String = "%.0f km over %d frames; peaks by third, live cells %d / %d / %d, nodes %d / %d / %d, static %.1f / %.1f / %.1f MB, kept %d / %d / %d; %d built and %d let go" % [
		length / 1000.0, frames, peaks[0][0], peaks[1][0], peaks[2][0], peaks[0][1], peaks[1][1], peaks[2][1],
		peaks[0][2], peaks[1][2], peaks[2][2], peaks[0][3], peaks[1][3], peaks[2][3], yard.built, yard.let_go]
	_check("across_220_km_of_a_72_km_world_the_live_cells_in_the_last_third_stay_within_the_first_thirds_peak",
		length >= 200000.0 and int(last[0]) <= int(float(first[0]) * SLACK) and int(first[0]) > 0, detail)
	_check("and_so_do_the_nodes_in_the_tree_and_the_engines_static_memory",
		int(last[1]) <= int(float(first[1]) * SLACK) and float(last[2]) <= float(first[2]) * SLACK,
		"nodes %d against %d, static %.1f MB against %.1f" % [last[1], first[1], last[2], first[2]])
	_check("and_the_cells_kept_for_turning_back_never_pass_their_bound",
		int(peaks[0][3]) <= SceneryYard.keep_cells and int(peaks[1][3]) <= SceneryYard.keep_cells
			and int(last[3]) <= SceneryYard.keep_cells and int(last[3]) > 0,
		"kept at most %d / %d / %d, bound %d" % [peaks[0][3], peaks[1][3], peaks[2][3], SceneryYard.keep_cells])
	towns.free()
	yard.free()
	_sections += 1


static func _ground(at: Vector3, bounds: AABB) -> float:
	var dx: float = maxf(maxf(bounds.position.x - at.x, 0.0), at.x - bounds.end.x)
	var dz: float = maxf(maxf(bounds.position.z - at.z, 0.0), at.z - bounds.end.z)
	return sqrt(dx * dx + dz * dz)


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
