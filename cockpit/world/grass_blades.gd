extends MultiMeshInstance3D
class_name GrassBlades
## BLADES OF GRASS ROUND THE EYE, on the fine finish, and nowhere else.
##
## A field painted on a plane is right from the air and wrong from a cockpit parked beside the
## runway, where the eye is a metre and a half off the ground and the ground is plainly a floor.
## So near the eye there are blades: clumps of five triangles on a lattice SPACING apart, out to
## REACH metres, that follow the eye in whole steps. See `grass_blades.gdshader` for what makes
## each clump itself and keeps it put while the lattice moves.
##
## OPAQUE, NOT ALPHA-CARDS. The usual grass is a textured card with a cut-out, and a cut-out
## throws away the early depth test on exactly the kind of GPU a headset has -- every card behind
## every other card is shaded and then discarded. A triangle that IS the blade is shaded once, and
## a field of them covers the same pixels the ground under it would have.
##
## AND NONE AT ALL FROM HEIGHT. Past CEILING metres up, a blade is less than a pixel long at the
## nearest it can be, so the instance count drops to zero -- one integer, no draw.
##
## The clumps are the ground's colour because they read the ground's own numbers:
## `match_the_ground` copies them off its material rather than typing them again.

const SHADER: Shader = preload("res://world/shaders/grass_blades.gdshader")

const SPACING: float = 0.6
const REACH: float = 36.0
const CEILING: float = 120.0
## How many blades in a clump, and how far from its centre they stand.
const BLADES: int = 5
const CLUMP: float = 0.12

var _paint: ShaderMaterial = null
## How many pavement rectangles the shader takes, and the margin kept round each, metres. See `_keep_off_the_pavement`.
const PAVEMENT_SLOTS: int = 8
const PAVEMENT_MARGIN: float = 1.0
## The rectangles last handed to the shader.
var _pavement_shown: Array[Vector4] = []


func _ready() -> void:
	var across: int = int(ceil(REACH * 2.0 / SPACING))
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = _clump()
	many.instance_count = across * across
	var start: float = -float(across) * 0.5 * SPACING
	for j in range(across):
		for i in range(across):
			many.set_instance_transform(j * across + i, Transform3D(Basis.IDENTITY,
				Vector3(start + float(i) * SPACING, 0.0, start + float(j) * SPACING)))
	multimesh = many
	_paint = ShaderMaterial.new()
	_paint.shader = SHADER
	# A heading and not the wind, which is zero: see `Terrain.SWELL_HEADING`.
	_paint.set_shader_parameter("wind", Terrain.SWELL_HEADING)
	_paint.set_shader_parameter("reach", REACH)
	_paint.set_shader_parameter("spacing", SPACING)
	_paint.set_shader_parameter("land_half", Terrain.WORLD_HALF)
	_paint.set_shader_parameter("runway", _runway_rectangle())
	material_override = _paint
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The lattice's bounds are the lattice; a blade swaying out of them is centimetres.
	extra_cull_margin = 2.0
	set_process(is_visible_in_tree())
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))


func _process(_delta: float) -> void:
	var eye: Camera3D = get_viewport().get_camera_3d()
	if eye == null:
		return
	var at: Vector3 = eye.global_position
	global_position = Vector3(snappedf(at.x, SPACING), 0.0, snappedf(at.z, SPACING))
	multimesh.visible_instance_count = 0 if at.y > CEILING else -1
	if at.y <= CEILING:
		_keep_off_the_pavement(at)


## NO GRASS THROUGH AN AIR BASE'S PAVEMENT: the slabs within reach of the eye, as rectangles with PAVEMENT_MARGIN round
## them, handed to the shader -- at most PAVEMENT_SLOTS, and only when the set changes. A base's slabs are axis-aligned in
## the world (AirbasePlan lays them only on quarter-turn runways), so a slab's rectangle is exact.
func _keep_off_the_pavement(eye: Vector3) -> void:
	if _paint == null:
		return
	var near: Array[Vector4] = []
	var reach: float = REACH + PAVEMENT_MARGIN
	for base in AirbasePlan.bases():
		for slab in base["pavement"]:
			var middle: Vector3 = slab["position"]
			var half: Vector3 = (slab["half_extents"] as Vector3) + Vector3(PAVEMENT_MARGIN, 0.0, PAVEMENT_MARGIN)
			if absf(middle.x - eye.x) > half.x + reach or absf(middle.z - eye.z) > half.z + reach:
				continue
			if near.size() < PAVEMENT_SLOTS:
				near.append(Vector4(middle.x - half.x, middle.z - half.z, middle.x + half.x, middle.z + half.z))
	if near == _pavement_shown:
		return
	_pavement_shown = near
	var slots: Array[Vector4] = near.duplicate()
	slots.resize(PAVEMENT_SLOTS)
	_paint.set_shader_parameter("pavement", slots)
	_paint.set_shader_parameter("pavements", near.size())


## The field's own colours, off the ground's material.
func match_the_ground(ground: ShaderMaterial) -> void:
	if ground == null or _paint == null:
		return
	for field in ["dry_colour", "lush_colour", "patch_scale"]:
		_paint.set_shader_parameter(field, ground.get_shader_parameter(field))


## THE RUNWAY AS A RECTANGLE ON THE GROUND, with a few metres' margin, from its own axis -- so
## a runway turned to a different bearing still has no grass on it.
static func _runway_rectangle() -> Vector4:
	var axis: Dictionary = Terrain.runway_axis()
	var along: Vector3 = (axis["along"] as Vector3) * (Terrain.RUNWAY_LENGTH * 0.5 + 6.0)
	var across: Vector3 = (axis["across"] as Vector3) * (Terrain.RUNWAY_WIDTH * 0.5 + 6.0)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for corner in [along + across, along - across, -along + across, -along - across]:
		var at: Vector3 = Terrain.RUNWAY_AT + corner
		low = Vector2(minf(low.x, at.x), minf(low.y, at.z))
		high = Vector2(maxf(high.x, at.x), maxf(high.y, at.z))
	return Vector4(low.x, low.y, high.x, high.y)


## FIVE BLADES ROUND A CENTRE, each a thin triangle one unit tall that leans a little outwards.
## The shader scales the height; this is only the shape.
static func _clump() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for b in range(BLADES):
		var about: float = TAU * float(b) / float(BLADES) + 0.3
		var out := Vector3(cos(about), 0.0, sin(about))
		var side := Vector3(-out.z, 0.0, out.x) * 0.025
		var root: Vector3 = out * CLUMP
		for corner in [root - side, root + side, root + out * 0.10 + Vector3.UP]:
			vertices.append(corner)
			normals.append(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
