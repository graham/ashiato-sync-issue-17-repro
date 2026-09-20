extends Node3D
class_name LakeSheets
## THE LAKES OF THE GENERATED GROUND, DRAWN AS WATER: every lake's water cells, flat at that lake's own level, in ONE mesh
## -- one draw call for every lake in the world -- wearing the sea's shader for the finish (`WaterSurface`).
##
## BEFORE 2026-09-17 A LAKE WAS NOT DRAWN AT ALL. The simulation floated hulls on it (`Terrain.water_height`, the
## bedrock's `water_ticks_at`) and the tanker scooped from it, while GroundView coloured its bed by height and slope like
## any other ground: a flying boat afloat sat on grass-green ground at the lake's level, and its wake lay on that.
## Found by the water audit asked for with "let's make sure we always use the good water shader".
##
## WHERE THE WATER IS, from the ground itself: a lake's square, `CELL` metres a cell, asked of `waters_at` at every
## corner, and a cell is drawn where any corner is THIS lake's water -- the level of the water at the lake's middle, to
## the tick. The shore is left to the ground, which stands above the water's level there and hides the sheet under it.
##
## EXACTLY AT THE WATER THE SIMULATION FLOATS A HULL ON: `Terrain.water_height`, the bedrock's own water, with nothing
## added -- the tanker floats on this surface, so the surface is where the tanker floats (team-lead, 2026-09-17). A first
## version stood 3 cm over it.
##
## ONE MESH, NOT ONE A LAKE (team-lead): thirteen lakes were thirteen draw calls. Vertices are world metres from this
## node's origin, which stays at the world's; float32 holds a vertex 30 km out to about 2 mm, flat water that nobody
## can see step.
##
## STILL WATER, BECAUSE THE SHEET SAYS IT IS INLAND (`WaterSurface.wear`'s `inland`, 2026-09-20). This block used to say
## the lakes are "inside the coast band, where both ocean shaders move nothing", which was true on the island level and
## false on every generated one -- and the lakes only exist on the generated ones. `land_half` is handed
## `Terrain.WORLD_HALF`, 7,200 m, whatever level is flown, and `tests/rivers_survey.gd` measured 30 of the 54 lakes on
## the five generated levels standing outside that band at full sea motion, the furthest 19 km out. A lake is flat now
## wherever it lies, with the wind-sea painted on it -- and a wake laid on it (WakeYard) lies flat on it too.

## The cell a lake is sampled on, metres, and the most cells across one lake: a larger lake is sampled coarser.
const CELL: float = 16.0
const MOST_CELLS: int = 128
## Ticks in a metre, as the ground function answers heights and water in (`ground_core.hpp`, kTicksPerMetre).
const TICKS: float = 32.0
## HOW DRY A CORNER THAT IS NOT THIS LAKE'S WATER IS HELD, metres. Any negative number does; it only has to put the
## corner on the land side of the crossing, and a millimetre would be lost in a float32 beside a 27 m depth.
const DRY: float = 0.01

## Each lake drawn: {"centre": Vector2, "level": float metres, "cells": int}.
var _lakes: Array[Dictionary] = []
## Every lake, one mesh.
var _sheet: MeshInstance3D = null


func _ready() -> void:
	var finish: Node = get_node_or_null("/root/Finish")
	if finish != null:
		finish.connect("changed", wear)


## DRAW EVERY LAKE `field` (a GroundField) catalogues, on a finish. Once, as the level is built.
func show_lakes(field: Object, fine: bool) -> void:
	if _sheet != null:
		_sheet.queue_free()
		_sheet = null
	_lakes.clear()
	if field == null:
		return
	var no_water: int = ClassDB.class_get_integer_constant("GroundField", "NO_WATER")
	var vertices := PackedVector3Array()
	var depths := PackedFloat32Array()
	var indices := PackedInt32Array()
	for entry in ((field.call("catalogue") as Dictionary).get("lakes", []) as Array):
		var lake: Dictionary = entry
		var centre := Vector2(float(int(lake["x"])), float(int(lake["z"])))
		# THE LAKE'S LEVEL IS THE GROUND'S WATER AT ITS MIDDLE, in the ticks `waters_at` answers in. The catalogue's
		# "level" is in 1/1024 m, where the water queries are in 1/32 m: read as the same unit, no cell matched and not
		# one lake was drawn (the first run of tests/water_surfaces.gd).
		var level_ticks: int = int(field.call("water_ticks_at", int(centre.x), int(centre.y)))
		if level_ticks <= no_water:
			continue
		var reach: float = float(lake.get("water_radius", lake.get("r", 0))) + CELL * 2.0
		if reach <= CELL * 2.0:
			continue
		var cells: int = clampi(ceili(2.0 * reach / CELL), 2, MOST_CELLS)
		var level: float = Terrain.water_height(Vector3(centre.x, 0.0, centre.y))
		var drawn: int = _lay(vertices, depths, indices, field, centre, reach, cells, level_ticks, no_water, level)
		if drawn > 0:
			_lakes.append({"centre": centre, "level": level, "cells": drawn})
	if vertices.is_empty():
		return
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	# HOW DEEP THE WATER IS AT EACH VERTEX, metres, as ONE FLOAT PER VERTEX in CUSTOM0: the water shaders read it to
	# shade the shallows and draw the wet line along the waterline (`shore_water.gdshaderinc`). A sheet that carries its
	# own depth needs no second texture and no depth buffer, and reading the depth buffer is one of the expensive things
	# `ocean.gdshader` was written to do without.
	#
	# NOT THE VERTEX COLOUR, which was the first try. `ARRAY_COLOR` is eight bits a channel, so every depth over 1 m
	# clamped to 1 m and the whole grading the shore is made of collapsed into the first metre. Normalising by a scale
	# would have fitted it, at 4.7 cm a step over a 12 m range, and the shore band is 0.45 m deep -- ten steps, spread
	# over metres of shoreline, which is how a smooth shallow reads as contour rings. `ARRAY_CUSTOM_R_FLOAT` is one
	# float32 and exact.
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
	_sheet.name = "Lakes"
	_sheet.mesh = mesh
	WaterSurface.wear(_sheet, fine, null, true)
	add_child(_sheet)


## PUT THE LAKES ON A FINISH, as the sea is put on one.
func wear(fine: bool) -> void:
	if _sheet != null:
		WaterSurface.wear(_sheet, fine, null, true)


## ONE LAKE'S WATER, appended to `vertices` at `level`, CUT TO THE WATERLINE: the cells of a `cells` by `cells` square
## of side 2 x `reach` round `centre`, each clipped to where the ground function crosses this lake's level. `depths`
## takes how deep the water is at each vertex, in metres, which is exactly 0 along the shore by construction. Returns
## how many cells carried water.
##
## A GRID OF WHOLE CELLS WAS A VISIBLE STAIRCASE. Until 2026-09-20 a cell was drawn whole if ANY of its four corners was
## wet, so a lake's outline was a flight of 16 m steps -- obvious from the air in the first photograph anybody took of
## one (godotgames-drafts/2026-09-20/rivers, lake_above), and green in every suite, because nothing headless can see an
## outline. Making `CELL` smaller would have cost cells squared and still been a staircase.
##
## SO THE EDGE IS INTERPOLATED, NOT SNAPPED. The ground function gives a height at every corner, and `level` minus that
## height is the DEPTH there: positive under water, negative on land, and zero exactly at the waterline. Walking each
## cell's four corners in turn, a corner under water joins the polygon and an edge whose two ends disagree contributes
## the point where the depth crosses zero. The polygon is fanned into triangles. The same 16 m grid now draws a
## shoreline good to the ground function's own slope between corners, at no extra sampling.
##
## THE CROSSINGS ARE SHARED BETWEEN THE TWO CELLS EITHER SIDE OF AN EDGE, as the corners already were. Worked out per
## cell they would be computed twice and -- worse -- could differ in the last bit and leave a crack of daylight along
## every boundary edge.
##
## A DRY CORNER IS FORCED DRY. `reach` is the water radius and a little more, so the box's own CORNERS can lie outside
## the rim the ground function raises round a lake, where the land is free to dip below this lake's level again. The
## lake a corner belongs to is still decided by `waters_at`, as before; the depth only says where between two corners
## the line falls. Without this a valley 1.2 km from the middle could grow a second sheet of the wrong lake's water.
static func _lay(vertices: PackedVector3Array, depths: PackedFloat32Array, indices: PackedInt32Array, field: Object,
		centre: Vector2, reach: float, cells: int, level_ticks: int, no_water: int, level: float) -> int:
	var side: int = cells + 1
	var step: float = 2.0 * reach / float(cells)
	var x0: float = centre.x - reach
	var z0: float = centre.y - reach
	var points := PackedInt32Array()
	points.resize(side * side * 2)
	for j in range(side):
		for i in range(side):
			var k: int = (j * side + i) * 2
			points[k] = roundi(x0 + float(i) * step)
			points[k + 1] = roundi(z0 + float(j) * step)
	var waters: PackedInt32Array = field.call("waters_at", points)
	var heights: PackedInt32Array = field.call("heights_at", points)
	# HOW DEEP THE WATER IS AT EACH CORNER, metres: this lake's level less the ground there, and a corner that is not
	# this lake's water is held dry however low the ground under it falls.
	var deep := PackedFloat32Array()
	deep.resize(side * side)
	for k in range(side * side):
		var under: float = float(level_ticks - heights[k]) / TICKS
		deep[k] = under if (waters[k] > no_water and waters[k] == level_ticks) else minf(under, -DRY)
	# EACH CORNER ONCE, shared by the cells round it: laid a cell at a time, every corner was four vertices, and the 13
	# lakes were 257,274 of them. The crossings on the cell edges are shared the same way, `_H` along x and `_V` along z.
	var corner := PackedInt32Array()
	corner.resize(side * side)
	corner.fill(-1)
	var crossing := PackedInt32Array()
	crossing.resize(side * side * 2)
	crossing.fill(-1)
	var drawn: int = 0
	var ring := PackedInt32Array()
	for j in range(cells):
		for i in range(cells):
			var a: int = j * side + i
			# THE FOUR CORNERS WALKED ROUND THE CELL, which a polygon needs and the old two triangles did not: the
			# order is a, a + 1, a + side + 1, a + side, which is the same way round as the pair it replaces.
			var about: PackedInt32Array = [a, a + 1, a + side + 1, a + side]
			var wet: int = 0
			for k in about:
				wet += 1 if deep[k] > 0.0 else 0
			if wet == 0:
				continue
			ring.clear()
			for e in range(4):
				var here: int = about[e]
				var next: int = about[(e + 1) % 4]
				if deep[here] > 0.0:
					if corner[here] < 0:
						corner[here] = vertices.size()
						vertices.append(Vector3(x0 + float(here % side) * step, level, z0 + float(here / side) * step))
						depths.append(deep[here])
					ring.append(corner[here])
				if (deep[here] > 0.0) == (deep[next] > 0.0):
					continue
				# THE WATERLINE ON THIS EDGE, shared with the cell on the other side of it. An edge runs either along x
				# (its two corners one apart) or along z (one side apart), and is filed under its lower corner.
				var low: int = mini(here, next)
				var slot: int = low * 2 + (0 if absi(here - next) == 1 else 1)
				if crossing[slot] < 0:
					var t: float = deep[here] / (deep[here] - deep[next])
					var at_here := Vector2(x0 + float(here % side) * step, z0 + float(here / side) * step)
					var at_next := Vector2(x0 + float(next % side) * step, z0 + float(next / side) * step)
					var on := at_here.lerp(at_next, t)
					crossing[slot] = vertices.size()
					vertices.append(Vector3(on.x, level, on.y))
					# EXACTLY ZERO, not the lerp of the two depths, which is the same number to the bit only because
					# `t` was solved for it. The shore band in the shader keys off this being 0.
					depths.append(0.0)
				ring.append(crossing[slot])
			for k in range(1, ring.size() - 1):
				indices.append(ring[0])
				indices.append(ring[k])
				indices.append(ring[k + 1])
			drawn += 1
	return drawn


## ---- for the tests and the boards -------------------------------------------------

## Every lake drawn: its centre, its level in metres and how many cells it has.
func lakes_drawn() -> Array[Dictionary]:
	return _lakes


## The one mesh every lake is drawn in; null in a world with no lakes.
func sheet() -> MeshInstance3D:
	return _sheet


## THE HEIGHT THE DRAWN WATER IS AT, over a point: the y of the drawn vertex nearest it, read off the mesh itself; NAN
## where there is no lake mesh. For the check that the surface is where the tanker floats.
func drawn_height_near(at: Vector2) -> float:
	if _sheet == null:
		return NAN
	var vertices: PackedVector3Array = (_sheet.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var best: float = INF
	var height: float = NAN
	for vertex in vertices:
		var away: float = Vector2(vertex.x, vertex.z).distance_squared_to(at)
		if away < best:
			best = away
			height = vertex.y
	return height + _sheet.global_position.y
