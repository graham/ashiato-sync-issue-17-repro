extends Node
## Headless: is the island's filing by the kilometre the island, box for box?
##
##   Godot --headless --path cockpit res://tests/world_map.tscn
##
## `WorldMap` is what a picture streamed round the aircraft will be drawn from, one cell at a time, so a box it loses
## is a mountain the simulation has and nobody can see, and a box it files twice is a building drawn twice on a border.
## Neither shows in a count of cells or a count of boxes alone, so every check here is against something the map did
## not compute:
##
## - THE LIST ITSELF. Every cell's boxes, put back together, are `Terrain.boxes()` as a multiset to the centimetre --
##   not merely as many.
## - THE GROUND. A box's centre lies inside its cell's square, asked with the square's own rectangle, not with
##   `cell_of` -- a check that asked `cell_of` would agree with any mistake `cell_of` made.
## - THE BOXES. A cell's bounds hold every box filed in it, and every face of the bounds is some box's face: tight,
##   so a visibility range sized from it is sized from the mountain and not from a guess.
## - AN AXIS. Just below zero is the cell below zero, on both axes.
## - A REFUSAL. An entry with no position is not filed, and is counted.
##
## Read RESULT=, not the exit code.

## How close two sizes or places must be to count as the same, metres. The boxes are generated to the centimetre.
const SAME: float = 0.01

var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[world_map] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var solid: Array[Dictionary] = Terrain.boxes()
	var began: int = Time.get_ticks_usec()
	var map := WorldMap.new(solid)
	var took_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	# More than 400: 1,080 boxes until the mountains became ranges (2026-09-18) and 583 rock boxes left the list.
	_check("there_is_an_island_to_file", solid.size() > 400 and map.cells().size() > 10,
		"%d boxes into %d cells of %.0f m in %.2f ms" % [solid.size(), map.cells().size(), WorldMap.CELL, took_ms])
	_every_box_is_filed_exactly_once(solid, map)
	_every_box_stands_in_its_own_cell(map)
	_every_cells_bounds_are_the_hull_of_its_boxes(map)
	_below_zero_is_the_cell_below_zero()
	_a_box_with_no_place_is_refused()
	_check("every_section_of_the_suite_ran", _sections == 5, "%d of 5" % _sections)
	_finish()


## ---- the list ----------------------------------------------------------------------------

func _every_box_is_filed_exactly_once(solid: Array[Dictionary], map: WorldMap) -> void:
	var wanted: Dictionary = {}
	for box in solid:
		var key: String = _key(box)
		wanted[key] = int(wanted.get(key, 0)) + 1
	var got: Dictionary = {}
	var count: int = 0
	for cell in map.cells():
		for box in map.boxes_in(cell):
			var key: String = _key(box)
			got[key] = int(got.get(key, 0)) + 1
			count += 1
	var missing: PackedStringArray = []
	var extra: PackedStringArray = []
	for key in wanted:
		var short: int = int(wanted[key]) - int(got.get(key, 0))
		if short > 0:
			missing.append("%s x%d" % [key, short])
		elif short < 0:
			extra.append("%s x%d" % [key, -short])
	for key in got:
		if not wanted.has(key):
			extra.append("%s x%d" % [key, int(got[key])])
	_check("every_box_of_the_island_is_filed_exactly_once",
		missing.is_empty() and extra.is_empty() and count == solid.size() and map.filed() == solid.size(),
		"%d filed of %d, %d missing, %d extra%s" % [count, solid.size(), missing.size(), extra.size(),
			"" if missing.is_empty() and extra.is_empty() else ": %s" % [str((Array(missing) + Array(extra)).slice(0, 4))]])

	# AND IN THE LIST'S OWN ORDER inside each cell, so two maps of one island file alike, and a picture drawn from them
	# draws alike.
	var again := WorldMap.new(Terrain.boxes())
	var differ: int = 0
	for cell in map.cells():
		var mine: Array[Dictionary] = map.boxes_in(cell)
		var theirs: Array[Dictionary] = again.boxes_in(cell)
		if mine.size() != theirs.size():
			differ += 1
			continue
		for i in range(mine.size()):
			if _key(mine[i]) != _key(theirs[i]):
				differ += 1
				break
	_check("and_two_maps_of_the_island_file_it_alike_in_the_same_order",
		differ == 0 and again.cells() == map.cells(), "%d of %d cells differ" % [differ, map.cells().size()])
	_sections += 1


## ---- the ground ----------------------------------------------------------------------------

func _every_box_stands_in_its_own_cell(map: WorldMap) -> void:
	var astray: PackedStringArray = []
	var checked: int = 0
	var reaching: int = 0
	for cell in map.cells():
		var square: Rect2 = WorldMap.square_of(cell)
		for box in map.boxes_in(cell):
			checked += 1
			var at: Vector3 = box["position"]
			var half: Vector3 = box["half_extents"]
			# Inside the square, its lower edges in and its upper edges out -- which is what floor means.
			var centre := Vector2(at.x, at.z)
			if not (centre.x >= square.position.x and centre.x < square.end.x
					and centre.y >= square.position.y and centre.y < square.end.y):
				astray.append("%s in %s" % [centre, cell])
			if not square.encloses(Rect2(centre - Vector2(half.x, half.z), Vector2(half.x, half.z) * 2.0)):
				reaching += 1
	_check("every_box_centre_stands_inside_its_cells_square", astray.is_empty() and checked > 0,
		"%d boxes, %d astray%s; %d of them reach past their square, which is what the bounds are for" % [checked,
			astray.size(), "" if astray.is_empty() else ": %s" % [str(Array(astray).slice(0, 4))], reaching])
	_sections += 1


## ---- the boxes ----------------------------------------------------------------------------

func _every_cells_bounds_are_the_hull_of_its_boxes(map: WorldMap) -> void:
	var loose: PackedStringArray = []
	var wider: float = 0.0
	for cell in map.cells():
		var bounds: AABB = map.bounds_of(cell)
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		for box in map.boxes_in(cell):
			var at: Vector3 = box["position"]
			var half: Vector3 = box["half_extents"]
			low = Vector3(minf(low.x, at.x - half.x), minf(low.y, at.y - half.y), minf(low.z, at.z - half.z))
			high = Vector3(maxf(high.x, at.x + half.x), maxf(high.y, at.y + half.y), maxf(high.z, at.z + half.z))
		if not ((bounds.position - low).length() < SAME and (bounds.end - high).length() < SAME):
			loose.append("%s: %s against %s..%s" % [cell, bounds, low, high])
		var square: Rect2 = WorldMap.square_of(cell)
		wider = maxf(wider, maxf(square.position.x - bounds.position.x, bounds.end.x - square.end.x))
		wider = maxf(wider, maxf(square.position.y - bounds.position.z, bounds.end.z - square.end.y))
	_check("every_cells_bounds_are_exactly_the_hull_of_its_boxes", loose.is_empty(),
		"%d cells, %d loose%s; the furthest reach past a square is %.0f m" % [map.cells().size(), loose.size(),
			"" if loose.is_empty() else ": %s" % [str(Array(loose).slice(0, 2))], wider])
	_check("and_a_cell_with_nothing_in_it_has_no_bounds_and_no_boxes",
		not map.has_cell(Vector2i(40, 40)) and map.boxes_in(Vector2i(40, 40)).is_empty()
			and map.bounds_of(Vector2i(40, 40)).size == Vector3.ZERO,
		"cell (40, 40), 40 km out to sea")
	_sections += 1


## ---- an axis ----------------------------------------------------------------------------------

func _below_zero_is_the_cell_below_zero() -> void:
	var cases: Array = [
		[Vector3(0.5, 0.0, 0.5), Vector2i(0, 0)],
		[Vector3(-0.5, 0.0, 0.5), Vector2i(-1, 0)],
		[Vector3(0.5, 0.0, -0.5), Vector2i(0, -1)],
		[Vector3(-1023.9, 0.0, -1024.1), Vector2i(-1, -2)],
		[Vector3(1024.0, 0.0, 2047.9), Vector2i(1, 1)],
	]
	var wrong: PackedStringArray = []
	for case in cases:
		var got: Vector2i = WorldMap.cell_of(case[0])
		if got != case[1]:
			wrong.append("%s -> %s, wanted %s" % [case[0], got, case[1]])
	# And a map of two boxes a metre either side of the origin puts them in two cells, not one.
	var either_side := WorldMap.new([
		{"position": Vector3(-1.0, 5.0, 1.0), "half_extents": Vector3.ONE},
		{"position": Vector3(1.0, 5.0, 1.0), "half_extents": Vector3.ONE}] as Array[Dictionary])
	_check("just_below_zero_is_the_cell_below_zero_on_both_axes",
		wrong.is_empty() and either_side.cells().size() == 2,
		"%d cases%s; two boxes either side of x = 0 in %d cells" % [cases.size(),
			"" if wrong.is_empty() else ": %s" % wrong, either_side.cells().size()])
	_sections += 1


## ---- a refusal --------------------------------------------------------------------------------

func _a_box_with_no_place_is_refused() -> void:
	var map := WorldMap.new([
		{"position": Vector3(10.0, 5.0, 10.0), "half_extents": Vector3.ONE},
		{"half_extents": Vector3.ONE},
		{"position": Vector2(10.0, 10.0), "half_extents": Vector3.ONE}] as Array[Dictionary])
	_check("a_box_with_no_place_is_not_filed_and_is_counted",
		map.refused == 2 and map.filed() == 1 and map.cells().size() == 1,
		"refused %d, filed %d, in %d cells" % [map.refused, map.filed(), map.cells().size()])
	_sections += 1


## A box as the numbers that make it that box: where, how big, and what it is, to the centimetre.
static func _key(box: Dictionary) -> String:
	var at: Vector3 = box["position"]
	var half: Vector3 = box["half_extents"]
	return "%.2f,%.2f,%.2f|%.2f,%.2f,%.2f|%d" % [at.x, at.y, at.z, half.x, half.y, half.z, int(box.get("group", -1))]


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
