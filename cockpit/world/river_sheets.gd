extends Node3D
class_name RiverSheets
## THE WATER IN A LEVEL'S RIVERS, DRAWN: every river's ribbon in ONE mesh, wearing the sea's shader as inland water
## (`WaterSurface`), with how deep the water is at each vertex in CUSTOM0 so the banks get the same shore the lakes do
## (`shaders/shore_water.gdshaderinc`).
##
## A RIBBON, NOT A FIELD OF CELLS. A lake is a blob and `LakeSheets` finds it by asking the ground where the water is;
## a river is a line the level drew, so its water is laid along that line -- a cross-section every `STEP` metres, from
## one bank to the other -- and there is nothing to search for. It is also why a river's mesh is small: a 6 km river
## 50 m wide is about 750 vertices, against 44,000 for alpine's thirteen lakes.
##
## THE SURFACE IS THE ONE THE SIMULATION FLOATS ON, to the tick: `Terrain.water_height` at the station's middle, which
## is the ground function's own answer for the river there (`ground_core.cpp`, `water_ticks`), so a hull on the river
## sits in it and a wake lies flat on it. `LakeSheets` learnt this the hard way -- its first version stood 3 cm over
## the water and the tanker floated through its own reflection.
##
## THE DEPTH ACROSS THE RIVER IS A PARABOLA, deepest in the middle and EXACTLY ZERO at both banks, which is what makes
## the shore band land on the waterline rather than somewhere near it. The ground function cuts a flat bed at the
## draught, so this is the water's shape and not the bed's: what it is for is the shading.

## How far apart the cross-sections are along a river, metres, and how many vertices across one. A river is narrow and
## nearly flat, so neither needs to be large; 24 m stations keep a bend from reading as a polygon and 5 across the
## water puts a vertex on each bank, one in the middle and one either side of it for the shallows to grade through.
const STEP: float = 24.0
const ACROSS: int = 5

## Each river drawn: {"stations": int, "fall": float metres from its head to its mouth}.
var _rivers: Array[Dictionary] = []
var _sheet: MeshInstance3D = null


func _ready() -> void:
	var finish: Node = get_node_or_null("/root/Finish")
	if finish != null:
		finish.connect("changed", wear)


## DRAW EVERY RIVER `rivers` declares, on a finish. Once, as the level is built. `field` is the configured GroundField,
## which is the authority for where the water stands.
func show_rivers(rivers: Array, field: Object, fine: bool) -> void:
	if _sheet != null:
		_sheet.queue_free()
		_sheet = null
	_rivers.clear()
	if field == null or rivers.is_empty():
		return
	var vertices := PackedVector3Array()
	var depths := PackedFloat32Array()
	var indices := PackedInt32Array()
	for one in rivers:
		var river: Dictionary = one
		var drawn: Dictionary = _lay(vertices, depths, indices, river, field)
		if int(drawn["stations"]) > 1:
			_rivers.append(drawn)
	if vertices.is_empty():
		return
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_CUSTOM0] = depths
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_R_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	_sheet = MeshInstance3D.new()
	_sheet.name = "Rivers"
	_sheet.mesh = mesh
	WaterSurface.wear(_sheet, fine, null, true)
	add_child(_sheet)


## PUT THE RIVERS ON A FINISH, as the sea and the lakes are put on one.
func wear(fine: bool) -> void:
	if _sheet != null:
		WaterSurface.wear(_sheet, fine, null, true)


## ONE RIVER'S RIBBON, appended to `vertices`: a cross-section every STEP metres along the centre line, ACROSS vertices
## wide, at the water's own level there. What was drawn.
static func _lay(vertices: PackedVector3Array, depths: PackedFloat32Array, indices: PackedInt32Array,
		river: Dictionary, field: Object) -> Dictionary:
	var points: Array = river["points"]
	if points.size() < 2:
		return {"stations": 0, "fall": 0.0}
	var half: float = float(int(river.get("width", Watercourse.WIDTH_DEFAULT))) * 0.5
	var draught: float = float(int(river.get("draught", Watercourse.DRAUGHT_DEFAULT)))
	var first: int = vertices.size()
	var stations: int = 0
	var highest: float = -INF
	var lowest: float = INF
	for k in range(points.size() - 1):
		var a := Vector2(float(int(points[k][0])), float(int(points[k][1])))
		var b := Vector2(float(int(points[k + 1][0])), float(int(points[k + 1][1])))
		var legs: int = maxi(int(ceil(a.distance_to(b) / STEP)), 1)
		# THE LAST STATION OF A LEG IS THE FIRST OF THE NEXT, so it is laid once: a seam of doubled vertices down every
		# corner would be a crack in the water wherever two legs meet.
		var last: int = legs if k == points.size() - 2 else legs - 1
		for s in range(last + 1):
			var at: Vector2 = a.lerp(b, float(s) / float(legs))
			var along: Vector2 = (b - a).normalized()
			var across := Vector2(-along.y, along.x)
			var water: float = Watercourse.water_level_at(field, int(round(at.x)), int(round(at.y)))
			if is_nan(water):
				continue
			highest = maxf(highest, water)
			lowest = minf(lowest, water)
			for c in range(ACROSS):
				var t: float = float(c) / float(ACROSS - 1) * 2.0 - 1.0
				var on: Vector2 = at + across * (t * half)
				vertices.append(Vector3(on.x, water, on.y))
				# ZERO AT BOTH BANKS, deepest in the middle: the shore band keys off this being 0 at the edge.
				depths.append(draught * (1.0 - t * t))
			stations += 1
	for s in range(stations - 1):
		for c in range(ACROSS - 1):
			var v: int = first + s * ACROSS + c
			indices.append_array([v, v + 1, v + ACROSS, v + 1, v + ACROSS + 1, v + ACROSS])
	return {"stations": stations, "fall": (highest - lowest) if stations > 1 else 0.0}


## ---- for the tests and the boards -------------------------------------------------

## Every river drawn: how many cross-sections it has and how far it falls from its head to its mouth.
func rivers_drawn() -> Array[Dictionary]:
	return _rivers


## The one mesh every river is drawn in; null in a level with no rivers.
func sheet() -> MeshInstance3D:
	return _sheet
