extends MeshInstance3D
class_name SeaSwell
## THE SEA'S SHEET: a surface with vertices in it, so a wave can have a shape. The fine sea draws it with
## Gerstner chop over the simulation's standing swell; the plain sea wears the same sheet (`carry`) with the
## standing swell alone.
##
## The plain sea was one quad with four corners and could not be anything but flat -- every wave
## on it a normal, painted. That is right at two thousand feet and wrong at fifteen metres,
## which is where a water bomber scoops and where every boat is, and where a flat sea with
## moving highlights reads as a floor.
##
## So this is a grid, and the grid FOLLOWS THE EYE. Vertices are only worth having near enough
## to see a wave's shape, so the cells are CELL metres across out to FINE_REACH and then grow by
## GROWTH each ring to the horizon: about fifty-eight thousand vertices for a sea 48 km across.
## The shader moves them with four Gerstner waves that fade out by the range the cells are too
## coarse to carry them, and beyond that it is the plain sea's painted normal again.
##
## SNAPPED, NOT SLID. The grid moves in whole cells, so a near vertex always lands where another
## vertex was and the waves do not swim as the aircraft moves. The outer rings do not line up,
## and they do not have to: nothing out there is displaced.
##
## THE COAST. The island is a slab at sea level and the sea runs under it two centimetres down,
## so a wave near the shore would come up through the grass. The shader fades the shape to
## nothing inside a band offshore; see `land_half`.
##
## WHAT IT DOES NOT DO: move a boat. Buoyancy is computed in the simulation against its own
## standing swell (`swell_height`), the same on every peer, and the chop drawn here is scenery: a
## wave that lifted a hull on one machine and not another would be a desync, not a detail. The
## standing swell is handed to the shaders from the simulation (`hand_the_swell`), so the water
## drawn at a hull is the water the hull is in. See agents.md, "THE SCENERY HAS TWO FINISHES" and
## "A SHIP UNDER SAIL".
##
## THE PLAIN SEA, CARRIED. PLAIN's sea was a 48 km PlaneMesh with four vertices, so on the finish a
## headset starts on every hull heaved +-0.76 m through a flat plane (the brig's waterline pictures,
## 2026-09-15). It wears this sheet now, follows the eye with it and is handed the same swell. One
## mesh, one follow.

const SHADER: Shader = preload("res://world/shaders/ocean_fine.gdshader")

## The near cell, in metres, and how far out it stays that size.
const CELL: float = 3.0
const FINE_REACH: float = 150.0
## Each ring beyond that is this much wider than the one inside it.
const GROWTH: float = 1.1
## Half the width of the whole sheet. The plain sea is 48 km across; so is this.
const REACH: float = 24000.0

## The plain finish's sea, once `carry` has been handed it: moved with this sheet whether or not this is drawn.
var _plain: MeshInstance3D = null


func _ready() -> void:
	if mesh == null:
		mesh = sheet()
	# THE SEA'S OWN SHADER FOR THE FINISH, from the one place water is dressed (`WaterSurface`), so a level that
	# names its sea's colours colours this sheet too -- until 2026-09-19 this built a material of its own, and a
	# pond could not be a new blue but the fine sea still could.
	WaterSurface.wear(self, true)
	set_process(visible or _plain != null)
	visibility_changed.connect(func(): set_process(is_visible_in_tree() or _plain != null))


## THE PLAIN SEA WEARS THIS SHEET. It is given the mesh, handed the standing swell, and moved with every snap. This
## node is hidden on PLAIN, and a hidden node stops processing, so carrying one keeps it following.
func carry(plain: MeshInstance3D) -> void:
	if mesh == null:
		mesh = sheet()
	_plain = plain
	plain.mesh = mesh
	WaterSurface.wear(plain, false)
	set_process(true)


## THE SIMULATION'S STANDING SWELL, handed to a material on either ocean shader: its heights, its periodic wave vectors
## and its tile, off `Sim.swell_shape`. Both finishes' seas and the carrier deck's call this, so no caller types five
## parameter names, and nothing that is not handed it paints a swell.
static func hand_the_swell(material: ShaderMaterial) -> void:
	var standing: Dictionary = Sim.swell_shape()
	if material == null or standing.is_empty():
		return
	material.set_shader_parameter("standing_height", float(standing["height"]))
	material.set_shader_parameter("standing_second_height", float(standing["second_height"]))
	material.set_shader_parameter("standing_first", standing["first"])
	material.set_shader_parameter("standing_second", standing["second"])
	material.set_shader_parameter("standing_tile", float(standing["tile"]))
	# AND THE WIND-SEA THE BOATS FEEL (C1): each wave as (x, z, height), three of them, zero where the library has none.
	var wind := PackedVector3Array()
	for wave in (standing.get("wind_waves", []) as Array):
		wind.append(wave)
	while wind.size() < 3:
		wind.append(Vector3.ZERO)
	material.set_shader_parameter("standing_wind", wind)


func _process(_delta: float) -> void:
	var eye: Camera3D = get_viewport().get_camera_3d()
	if eye == null:
		return
	var at: Vector3 = eye.global_position
	global_position = Vector3(snappedf(at.x, CELL), global_position.y, snappedf(at.z, CELL))
	if _plain != null:
		_plain.global_position = Vector3(global_position.x, _plain.global_position.y, global_position.z)


## THE SHEET, built once. Where the grid lines fall along one axis, then every crossing of them.
static func sheet() -> ArrayMesh:
	var lines: PackedFloat32Array = stations()
	var n: int = lines.size()
	var vertices := PackedVector3Array()
	vertices.resize(n * n)
	var normals := PackedVector3Array()
	normals.resize(n * n)
	for j in range(n):
		for i in range(n):
			vertices[j * n + i] = Vector3(lines[i], 0.0, lines[j])
			normals[j * n + i] = Vector3.UP
	var indices := PackedInt32Array()
	indices.resize((n - 1) * (n - 1) * 6)
	var k: int = 0
	for j in range(n - 1):
		for i in range(n - 1):
			var a: int = j * n + i
			indices[k] = a
			indices[k + 1] = a + 1
			indices[k + 2] = a + n
			indices[k + 3] = a + 1
			indices[k + 4] = a + n + 1
			indices[k + 5] = a + n
			k += 6
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## Where the grid lines cross one axis: CELL apart to FINE_REACH, then growing to REACH.
static func stations() -> PackedFloat32Array:
	var outward: Array[float] = []
	var inner: int = int(round(FINE_REACH / CELL))
	for i in range(inner + 1):
		outward.append(float(i) * CELL)
	var step: float = CELL
	var at: float = float(inner) * CELL
	while at < REACH:
		step *= GROWTH
		at = minf(at + step, REACH)
		outward.append(at)
	var out := PackedFloat32Array()
	for i in range(outward.size() - 1, 0, -1):
		out.append(-outward[i])
	for one in outward:
		out.append(one)
	return out
