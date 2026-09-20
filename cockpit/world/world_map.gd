extends RefCounted
class_name WorldMap
## THE WORLD, FILED BY THE KILOMETRE: every solid box in the one cell its centre stands in, and what each cell
## holds reaching as far as its boxes do.
##
## WHY IT EXISTS. The user wants a world of 30 to 70 km that is drawn round the aircraft rather than all at once
## (design: godotgames-drafts/2026-09-14/cockpit-streaming/design.md). The simulation keeps EVERY static box on
## every peer -- rule 8, and a box is about 930 bytes and costs a tick nothing (`tests/streaming_probe.gd`) -- so
## what streams is the PICTURE, and a picture streamed by cell needs the one list filed by cell first. This is that
## filing and nothing else: it draws nothing, and nothing is taken out of the simulation.
##
## BY THE CENTRE, NOT THE FOOTPRINT, and that is the decision. `BoxGrid` files a box in every cell its footprint
## touches, which is right for asking "is this point clear" and wrong for drawing: a box on a border would be drawn
## once by each cell it touches. So here a box belongs to exactly one cell, and each cell's BOUNDS grow to hold
## everything filed in it -- which is what a visibility range or a cull box has to be sized from, since a mountain
## filed in one cell can lean a few hundred metres into the next.
##
## HANDED THE LIST, NEVER BUILDING IT. The level builds `Terrain.boxes()` once for the simulation; this files the
## same dictionaries it is handed, in the order it is handed them, and copies none.
##
## `tests/world_map.gd` holds it to the list: every box in exactly one cell, every centre inside its cell's square,
## every cell's bounds the tight hull of its boxes, and a negative coordinate in the cell below zero.

## A cell's side, metres. A kilometre: four of `BoxGrid`'s 256 m cells a side, a city in two or three, and at the
## plane's 166 m/s about six seconds to cross. See the design, "Cells and rings".
const CELL: float = 1024.0

## Vector2i -> Array[Dictionary], the boxes filed there, in the order the list gave them.
var _boxes: Dictionary = {}
## Vector2i -> AABB, the hull of everything filed there.
var _bounds: Dictionary = {}
var _filed: int = 0
## Entries that could not be filed -- no position or no half-extents as Vector3s -- counted, and each one warned.
var refused: int = 0


func _init(solid: Array[Dictionary]) -> void:
	for box in solid:
		if not (box.get("position") is Vector3) or not (box.get("half_extents") is Vector3):
			push_warning("[world_map] a box with no position or no half_extents as Vector3s is not filed: %s" % box)
			refused += 1
			continue
		var at: Vector3 = box["position"]
		var half: Vector3 = box["half_extents"]
		var cell: Vector2i = cell_of(at)
		var hull := AABB(at - half, half * 2.0)
		if _boxes.has(cell):
			(_boxes[cell] as Array[Dictionary]).append(box)
			_bounds[cell] = (_bounds[cell] as AABB).merge(hull)
		else:
			var here: Array[Dictionary] = [box]
			_boxes[cell] = here
			_bounds[cell] = hull
		_filed += 1


## The cell a point stands in. FLOORED, so the kilometre just below zero is cell -1 and not a second cell 0: `int()`
## truncates towards zero and would file everything within a kilometre either side of an axis into one cell twice
## the size of the rest.
static func cell_of(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / CELL), floori(at.z / CELL))


## The ground a cell covers, as a rectangle on x and z.
static func square_of(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL))


## Every cell with anything filed in it, in order along x and then z, so two maps of one list list them alike. The
## sea has none: a cell with nothing in it is never asked for.
func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in _boxes:
		out.append(cell)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return out


func has_cell(cell: Vector2i) -> bool:
	return _boxes.has(cell)


## The boxes filed in a cell, the list's own dictionaries in the list's order; empty for a cell with none. READ-ONLY by
## agreement: it is the filing itself, not a copy.
func boxes_in(cell: Vector2i) -> Array[Dictionary]:
	if not _boxes.has(cell):
		var none: Array[Dictionary] = []
		return none
	return _boxes[cell]


## The hull of everything filed in a cell, which reaches past the cell's square wherever a box does. An empty AABB for a
## cell with nothing in it.
func bounds_of(cell: Vector2i) -> AABB:
	return _bounds.get(cell, AABB())


## How many boxes were filed, over every cell.
func filed() -> int:
	return _filed
