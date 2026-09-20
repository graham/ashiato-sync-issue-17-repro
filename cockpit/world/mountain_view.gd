extends Node3D
class_name MountainView
## THE ISLAND'S MOUNTAINS, DRAWN: one mesh a tile, made from exactly the arrays the simulation's collision was built from.
##
## THE PICTURE IS THE COLLISION. `MountainRange.tile(i)` (ashiato-gd/src/cockpit/mountain_range.hpp) hands this the same
## vertices and indices `CockpitWorld.set_mountains` handed Box3D -- whole metres and ticks of 1/32 m, exact in a float32 --
## so what is drawn is what is hit, to the bit, at every distance. There is no level of detail: the island's mountains are
## about 40,000 triangles, which a GPU draws without noticing, and a coarser far picture would be a hillside the simulation
## does not have. `tests/mountains.gd` casts rays at the arrays this draws.
##
## ALWAYS DRAWN, NOT STREAMED. The boxes they replaced were a streamed layer of the scenery yard, cut off about 10 km from
## the eye, and from 20 km out the island had no skyline at all (2026-09-18, the `mtn_far` before picture). The mountains
## are the background the user asked for, so every tile is resident from the level's load, and the renderer culls a tile
## by its bounds like any other mesh: ~40 tiles, a draw call each that is in view.
##
## FACETED NEAR, SMOOTH FAR (`shaders/mountain.gdshaderinc`): each triangle is lit flat, from the screen-space derivative
## of its own position -- the house's low-poly look -- and past a few kilometres that blends to the smooth normals built
## here, so a triangle smaller than a pixel does not flicker between its neighbours' lights as the view moves.
##
## THE GRIT RIDES IN THE VERTEX COLOUR: red how deep in a gully a vertex lies, green how far down its flank, both from the
## function (range_core.hpp); the shader cuts creek grooves, gully rims, scree, strata and snow from them. No texture.

const PLAIN: Shader = preload("res://world/shaders/mountain.gdshader")
const FINE: Shader = preload("res://world/shaders/mountain_fine.gdshader")

var _plain: ShaderMaterial = null
var _fine: ShaderMaterial = null
var _tiles: Array[MeshInstance3D] = []
var _triangles: int = 0


## THE GROUND'S NUMBERS THE FOOT IS PAINTED WITH, copied off the island ground's own material (grass.gdshader), so the two
## are one set of numbers.
const FROM_THE_GROUND: Array[StringName] = [&"dry_colour", &"lush_colour", &"patch_scale"]


## DRAW EVERY TILE OF `mountains`, a configured `MountainRange`, in the finish asked for, the foot painted as `ground` -- the
## island ground's ShaderMaterial -- is. Returns how many tiles.
func show_mountains(mountains: Object, fine: bool, ground: ShaderMaterial = null) -> int:
	_plain = _paint(PLAIN)
	_fine = _paint(FINE)
	if ground != null:
		for key in FROM_THE_GROUND:
			var value: Variant = ground.get_shader_parameter(key)
			if value != null:
				_plain.set_shader_parameter(key, value)
				_fine.set_shader_parameter(key, value)
	for t in range(int(mountains.call("tile_count"))):
		var tile: Dictionary = mountains.call("tile", t)
		var node := MeshInstance3D.new()
		node.name = "Tile_%d" % t
		node.mesh = tile_mesh(tile)
		var origin: Vector2i = tile["origin"]
		node.position = Vector3(float(origin.x), 0.0, float(origin.y))
		node.set_meta(&"origin", origin)
		add_child(node)
		_tiles.append(node)
		_triangles += (tile["indices"] as PackedInt32Array).size() / 3
	# A PROBE'S SWITCH, `--mountain-smooth=off` after the bare `--`: every facet lit flat at every distance, to measure
	# what the far blend to smooth normals buys against shimmer. Nothing in the game passes it.
	if FlightLevel._asked("mountain-smooth") == "off":
		for paint in [_plain, _fine]:
			paint.set_shader_parameter(&"smooth_from", Vector2(1.0e9, 1.0e9 + 1.0))
	wear(fine)
	return _tiles.size()


## THE HAZE, EVERY FRAME, from the Environment the world is drawn with: its fog density, and its fog colour mixed toward
## the sky's horizon by its aerial perspective, as the engine's own fog mixes it. Every frame, because a cloud the eye is in
## raises the density (Daylight.show_in_cloud) and the mountains must white out with everything else. Written only when
## it changed.
var _haze: Vector4 = Vector4(-1.0, 0.0, 0.0, 0.0)


func _process(_delta: float) -> void:
	if _plain == null or not is_inside_tree():
		return
	var air: Environment = get_world_3d().environment
	if air == null:
		return
	var density: float = air.fog_density if air.fog_enabled else 0.0
	var colour: Color = air.fog_light_color
	var horizon: Variant = air.sky.sky_material.get(&"sky_horizon_color") if air.sky != null and air.sky.sky_material != null 		else null
	if horizon is Color:
		colour = colour.lerp(horizon as Color, air.fog_aerial_perspective)
	var now := Vector4(density, colour.r, colour.g, colour.b)
	if now.is_equal_approx(_haze):
		return
	_haze = now
	for paint in [_plain, _fine]:
		paint.set_shader_parameter(&"haze_density", density)
		paint.set_shader_parameter(&"haze_colour", Color(colour.r, colour.g, colour.b))


## PUT THE FINISH ON: FINE's grooves and grain, or PLAIN's.
func wear(fine: bool) -> void:
	for node in _tiles:
		node.material_override = _fine if fine else _plain


## Whether every tile wears FINE, as `FlightLevel.finish_worn` asks each surface; false with no tiles.
func wears_fine() -> bool:
	if _tiles.is_empty():
		return false
	for node in _tiles:
		if node.material_override != _fine:
			return false
	return true


## Every tile drawn, for the suites: what they read back is the picture itself.
func drawn_tiles() -> Array[MeshInstance3D]:
	return _tiles


func triangles() -> int:
	return _triangles


func _paint(shader: Shader) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = shader
	var numbers: Dictionary = RockTuning.mountain_numbers()
	for key in numbers:
		paint.set_shader_parameter(key, numbers[key])
	return paint


## ONE TILE'S MESH, from its arrays as `MountainRange.tile` gives them: the vertices and indices untouched, the grit as
## the vertex colour, and each vertex's normal the area-weighted mean of the faces round it, for the far blend. Static and
## pure, so a suite can build it too.
static func tile_mesh(tile: Dictionary) -> ArrayMesh:
	var vertices: PackedVector3Array = tile["vertices"]
	var indices: PackedInt32Array = tile["indices"]
	var grit: PackedByteArray = tile["grit"]
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for k in range(0, indices.size(), 3):
		var a: Vector3 = vertices[indices[k]]
		# Clockwise from above: (c - a) x (b - a) points up, and its length is twice the area, which is the weight.
		var face: Vector3 = (vertices[indices[k + 2]] - a).cross(vertices[indices[k + 1]] - a)
		for c in range(3):
			normals[indices[k + c]] += face
	var colours := PackedColorArray()
	colours.resize(vertices.size())
	for v in range(vertices.size()):
		normals[v] = normals[v].normalized() if normals[v].length_squared() > 0.0 else Vector3.UP
		colours[v] = Color(float(grit[2 * v]) / 255.0, float(grit[2 * v + 1]) / 255.0, 0.0, 1.0)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
