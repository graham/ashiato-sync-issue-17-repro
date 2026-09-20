extends RefCounted
class_name BoxGrid
## THE ISLAND'S SOLID BOXES, FILED BY WHERE THEY STAND, so "is this point clear of everything" asks the few boxes
## near it instead of all of them.
##
## WHY IT EXISTS: the towns took `Terrain.boxes()` from 383 boxes to 650, and the waypoint pools -- which asked every
## candidate point about every box, and rebuilt the whole list once per kind -- went from 301 ms to 1,154 ms at boot
## (boot_probe, 2026-09-13). A walk that grows with the number of boxes times the number of points grows with every
## building; one that files boxes into cells grows with the few in a cell.
##
## THE SAME ARITHMETIC, NOT A NEW TEST. `is_clear_of` is `Terrain._clear_of` -- a point inside a box fattened by `room`
## on every axis -- run over the boxes filed in the cells the fattened point could touch. A box is filed in every cell
## its footprint covers, so a box can never be missed by asking the cells a query covers. `tests/towns.gd` holds the
## grid to the plain walk: the same answer for every waypoint of every kind and for thousands of random points.
##
## BUILT ONCE PER LIST AND HANDED ROUND, like the list itself. It holds the dictionaries it was given, never copies.

## A cell's side, metres. A city block is 96 m and a mountain layer is hundreds, so 256 m keeps a town's buildings to a
## handful of cells and a peak to a few.
const CELL: float = 256.0

var _cells: Dictionary = {}
## Boxes taller or wider than this many cells are kept in one list everyone asks -- the island's own ground slab would
## otherwise be filed into three thousand cells.
const HUGE_CELLS: int = 64
var _huge: Array[Dictionary] = []


func _init(solid: Array[Dictionary]) -> void:
	for box in solid:
		var at: Vector3 = box["position"]
		var half: Vector3 = box["half_extents"]
		var low := Vector2i(floori((at.x - half.x) / CELL), floori((at.z - half.z) / CELL))
		var high := Vector2i(floori((at.x + half.x) / CELL), floori((at.z + half.z) / CELL))
		if (high.x - low.x + 1) * (high.y - low.y + 1) > HUGE_CELLS:
			_huge.append(box)
			continue
		for cx in range(low.x, high.x + 1):
			for cz in range(low.y, high.y + 1):
				var key := Vector2i(cx, cz)
				if not _cells.has(key):
					_cells[key] = [] as Array[Dictionary]
				(_cells[key] as Array[Dictionary]).append(box)


## Whether `at` is further than `room` outside every box: `Terrain._clear_of`, asked of the nearby boxes only.
func is_clear_of(at: Vector3, room: float) -> bool:
	if not _clear_of(_huge, at, room):
		return false
	var low := Vector2i(floori((at.x - room) / CELL), floori((at.z - room) / CELL))
	var high := Vector2i(floori((at.x + room) / CELL), floori((at.z + room) / CELL))
	for cx in range(low.x, high.x + 1):
		for cz in range(low.y, high.y + 1):
			var here: Variant = _cells.get(Vector2i(cx, cz))
			if here != null and not _clear_of(here as Array[Dictionary], at, room):
				return false
	return true


## The walk itself, the same three lines as `Terrain._clear_of`.
static func _clear_of(boxes: Array[Dictionary], at: Vector3, room: float) -> bool:
	for box in boxes:
		var to: Vector3 = at - (box["position"] as Vector3)
		var half: Vector3 = (box["half_extents"] as Vector3) + Vector3.ONE * room
		if absf(to.x) < half.x and absf(to.y) < half.y and absf(to.z) < half.z:
			return false
	return true
