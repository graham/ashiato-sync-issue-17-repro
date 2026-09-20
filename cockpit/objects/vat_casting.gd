extends Node3D
class_name VatCasting
## A VAT CASTING: a craft's drawn parts poured into one mesh with no skeleton, every moving feature -- flaps, ailerons,
## gear, hook -- baked into a RIGID-BODY VERTEX ANIMATION TEXTURE and replayed in the vertex shader. RESEARCH PROOF OF
## CONCEPT (`research/vertex_animation.md`); nothing in the game builds one.
##
## A RIGID-BODY VAT, NOT A PER-VERTEX ONE. A per-vertex VAT stores every vertex's position for every frame: thousands of
## texels saying what one transform says, for parts that never bend. Here the texture has ONE COLUMN PER PART and ONE ROW
## PER SAMPLE OF A FEATURE'S AMOUNT; a texel pair is that part's rotation (a quaternion) and offset from its pour pose, in
## the root's frame. Each vertex carries only its part's column and which features move it (CUSTOM0). This is the mode
## Houdini calls rigid-body VAT.
##
## INDEXED BY AMOUNT, NOT BY TIME. An aileron follows the stick; a VAT that plays a clip cannot. So a feature's rows run
## from its low amount to its high, and each craft hands the GPU where each feature stands now as an `instance uniform`
## (a 0..1 fraction, four features to a vec4), set only when it changed. Five independent Cessna features are five rows
## ranges read independently, not a clip of every combination.
##
## BAKED BY THE AIRFRAME'S OWN SETTERS, SO NOTHING IS DECLARED BUT THE FEATURE. The bake calls `set_ailerons`,
## `set_gear` and the rest at each sample amount and records where every part went. So the gear's doors-then-legs order,
## the aileron's 20-up-15-down, the flap's slide aft -- anything the setter does to a rigid part -- is in the texture
## without a line here knowing it. A feature is {name, set: Callable(amount), get: Callable() -> amount, low, high}.
##
## TWO FEATURES MAY MOVE ONE PART, INNER FIRST: the Cessna's trim tab turns on its own hinge (trim) and rides the elevator
## (pitch). The feature that moves a DEEPER node of the part's chain is applied first; that is the order the node tree
## composes them in. A part moved by three features keeps the first two and says so.
##
## LIMITS: 16 features a craft (four vec4 instance uniforms, of the 16 a shader may have). Linear blending between two
## samples is not exact for a turn about a hinge off the root's origin; the error is measured, per sample count, in the
## probe. A part's visibility is not baked: a feature that hides or shows a part is not followed. It carries
## `Casting.CAST_FROM`, so it has `Casting`'s duty to the drawn-parts checks.

const MOST_FEATURES := 16
## ROWS A FEATURE GETS. Measured on the fighter's gear doors, whose whole swing is the first quarter of the gear's travel:
## worst vertex 9.2 mm at 33 rows, 2.2 mm at 65, 0.59 mm at 129. A row is 32 bytes a part, so rows are cheap.
const SAMPLES := 129

## The features, in texture order: {name, set, get, low, high, rest, last}.
var features: Array[Dictionary] = []
var instances: Array[MeshInstance3D] = []
var root: Node3D = null
var poured: int = 0
var samples: int = SAMPLES
## The parts, in column order, and where each stood in the root's frame when poured.
var columns: Array[MeshInstance3D] = []
var rest_poses: Array[Transform3D] = []
## How many parts each feature moves, by name: what the bake found, for the report.
var moved_by: Dictionary = {}
## The two textures, kept to measure.
var turn_image: Image
var shift_image: Image


## POUR every drawn part under `from` and bake `wanted` features into it. A COROUTINE: `await VatCasting.pour(...)`.
static func pour(from: Node3D, wanted: Array, skip: Callable = Callable(), sample_count: int = SAMPLES) -> VatCasting:
	var casting := VatCasting.new()
	casting.name = "VatCasting"
	casting.root = from
	casting.samples = sample_count
	var into_root: Transform3D = from.global_transform.affine_inverse()
	for feature in wanted:
		if casting.features.size() >= MOST_FEATURES:
			push_warning("VatCasting: more than %d features; %s is not baked" % [MOST_FEATURES, feature["name"]])
			continue
		var entry: Dictionary = (feature as Dictionary).duplicate()
		entry["rest"] = float((entry["get"] as Callable).call())
		entry["last"] = INF
		# EACH FEATURE ITS OWN TABLE: its own row count, at its own place in the one texture. A feature may ask for
		# `samples`; the rest take the casting's.
		entry["rows"] = maxi(int(entry.get("samples", sample_count)), 2)
		entry["first"] = 0 if casting.features.is_empty() else int(casting.features[-1]["first"]) + int(casting.features[-1]["rows"])
		casting.features.append(entry)
	for found in from.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if part.mesh == null or Casting._owned(part) or not part.is_visible_in_tree() or part.layers == 0:
			continue
		if skip.is_valid() and bool(skip.call(part)):
			continue
		casting.columns.append(part)
	var rest: Array[Transform3D] = []
	for part in casting.columns:
		rest.append(into_root * part.global_transform)
	casting.rest_poses = rest
	# EVERY NODE'S OWN TRANSFORM AT REST, to learn which node in a part's chain each feature turns.
	var nodes: Array[Node] = from.find_children("*", "Node3D", true, false)
	var node_rest: Dictionary = {}
	for node in nodes:
		node_rest[node] = (node as Node3D).transform

	# THE BAKE: each feature through its samples, every other feature at rest, every part's delta from its pour pose.
	var width: int = casting.columns.size()
	var height: int = 0
	for feature in casting.features: height += int(feature["rows"])
	casting.turn_image = Image.create_empty(maxi(width, 1), maxi(height, 1), false, Image.FORMAT_RGBAF)
	casting.shift_image = Image.create_empty(maxi(width, 1), maxi(height, 1), false, Image.FORMAT_RGBAF)
	# {part column: {feature index: depth of the deepest node of its chain that feature turns}}
	var turned_at: Array[Dictionary] = []
	turned_at.resize(width)
	for column in range(width): turned_at[column] = {}
	for f in range(casting.features.size()):
		var feature: Dictionary = casting.features[f]
		var turned_nodes: Dictionary = {}
		var rows: int = feature["rows"]
		var first: int = feature["first"]
		for k in range(rows):
			var amount: float = lerpf(float(feature["low"]), float(feature["high"]), float(k) / float(rows - 1))
			(feature["set"] as Callable).call(amount)
			for node in nodes:
				if not (node as Node3D).transform.is_equal_approx(node_rest[node]):
					turned_nodes[node] = true
			for column in range(width):
				var delta: Transform3D = (into_root * casting.columns[column].global_transform) * rest[column].affine_inverse()
				var q: Quaternion = delta.basis.get_rotation_quaternion()
				casting.turn_image.set_pixel(column, first + k, Color(q.x, q.y, q.z, q.w))
				casting.shift_image.set_pixel(column, first + k,
					Color(delta.origin.x, delta.origin.y, delta.origin.z, 0.0))
		(feature["set"] as Callable).call(float(feature["rest"]))
		var moved: int = 0
		for column in range(width):
			var walk: Node = casting.columns[column]
			var depth: int = -1
			var level: int = 0
			while walk != from and walk != null:
				if turned_nodes.has(walk):
					depth = maxi(depth, 1000 - level)
				walk = walk.get_parent()
				level += 1
			if depth >= 0:
				turned_at[column][f] = depth
				moved += 1
		casting.moved_by[feature["name"]] = moved
	# ALL BACK AT REST, and checked: a setter that does not come back to where it was poured would bake a lie.
	for column in range(width):
		if not (into_root * casting.columns[column].global_transform).is_equal_approx(rest[column]):
			push_error("VatCasting: %s did not return to its pour pose after the bake" % casting.columns[column].name)

	# THE MESH: `Casting`'s grouping, each vertex tagged (column, inner feature + 1, outer feature + 1).
	var groups: Dictionary = {}
	var flat: Dictionary = {}
	for column in range(width):
		var part: MeshInstance3D = casting.columns[column]
		var order: Array = (turned_at[column] as Dictionary).keys()
		# DEEPER FIRST: the feature turning the node nearest the part goes first.
		order.sort_custom(func(a, b): return int(turned_at[column][a]) > int(turned_at[column][b]))
		if order.size() > 2:
			push_warning("VatCasting: %s is moved by %d features; only two are followed" % [part.name, order.size()])
		var inner: int = int(order[0]) + 1 if order.size() > 0 else 0
		var outer: int = int(order[1]) + 1 if order.size() > 1 else 0
		casting.poured += 1
		var key: String = "%d|%.3f|%.3f|%.3f|%.3f" % [part.cast_shadow, part.visibility_range_begin,
			part.visibility_range_end, part.visibility_range_begin_margin, part.visibility_range_end_margin]
		if not groups.has(key):
			groups[key] = {"like": part, "surfaces": {}}
		for surface in range(part.mesh.get_surface_count()):
			var material: Material = part.get_active_material(surface)
			var id: Variant = material.get_instance_id() if material != null else 0
			var tint: Dictionary = {}
			var signature: String = Casting._albedo_only(material)
			if not signature.is_empty():
				if not flat.has(signature):
					flat[signature] = Casting._flat_material(material as StandardMaterial3D)
				var standard := material as StandardMaterial3D
				tint = {"albedo": standard.albedo_color, "vertex": standard.vertex_color_use_as_albedo,
					"srgb": standard.vertex_color_is_srgb}
				material = flat[signature]
				id = signature
			var by: Dictionary = groups[key]["surfaces"]
			if not by.has(id):
				by[id] = {"material": material, "chunks": []}
			(by[id]["chunks"] as Array).append({"arrays": part.mesh.surface_get_arrays(surface), "into": rest[column],
				"bone": 0, "tint": tint, "tag": [float(column), float(inner), float(outer), 0.0],
				"primitive": part.mesh.surface_get_primitive_type(surface) if part.mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES})
	var wanted_materials: Array = []
	for key in groups:
		for id in groups[key]["surfaces"]:
			var material: Material = groups[key]["surfaces"][id]["material"]
			if material != null and not wanted_materials.has(material): wanted_materials.append(material)
	var shaders: Dictionary = await HingeCasting._shaders_of(wanted_materials, from)
	var turn_texture := ImageTexture.create_from_image(casting.turn_image)
	var shift_texture := ImageTexture.create_from_image(casting.shift_image)
	var converted: Dictionary = {}
	var index: int = 0
	for key in groups:
		var like: MeshInstance3D = groups[key]["like"]
		var mesh := ArrayMesh.new()
		for id in groups[key]["surfaces"]:
			var surface: Dictionary = groups[key]["surfaces"][id]
			var arrays: Array = Casting._merge(surface["chunks"])
			if arrays.is_empty():
				continue
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			var tags := PackedFloat32Array()
			for chunk in surface["chunks"]:
				if int(chunk["primitive"]) != Mesh.PRIMITIVE_TRIANGLES:
					continue
				var count: int = ((chunk["arrays"] as Array)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				for i in range(count):
					tags.append_array(chunk["tag"])
			arrays[Mesh.ARRAY_CUSTOM0] = tags
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
				Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
			var material: Material = surface["material"]
			if not converted.has(material):
				converted[material] = casting._vat_material(material, shaders.get(material, RID()), turn_texture,
					shift_texture)
			mesh.surface_set_material(mesh.get_surface_count() - 1, converted[material])
		var drawn := MeshInstance3D.new()
		drawn.name = "VatCast%d" % index
		index += 1
		drawn.mesh = mesh
		drawn.cast_shadow = like.cast_shadow
		drawn.visibility_range_begin = like.visibility_range_begin
		drawn.visibility_range_end = like.visibility_range_end
		drawn.visibility_range_begin_margin = like.visibility_range_begin_margin
		drawn.visibility_range_end_margin = like.visibility_range_end_margin
		drawn.visibility_range_fade_mode = like.visibility_range_fade_mode
		# THE BOX MUST HOLD EVERY POSE: a lowered flap or a stowed wheel leaves the poured box.
		drawn.extra_cull_margin = 2.0
		drawn.set_meta(Casting.CAST_FROM, from.get_path())
		casting.add_child(drawn)
		casting.instances.append(drawn)
	casting.set_meta(Casting.CAST_FROM, from.get_path())
	from.add_child(casting)
	casting.transform = Transform3D.IDENTITY
	for part in casting.columns:
		part.layers = 0
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	casting.play()
	return casting


## HAND THE GPU EVERY FEATURE THAT MOVED, as a 0..1 fraction of its range. Returns how many vec4s were set. A parked
## craft costs one getter call and one compare per feature.
func play() -> int:
	var changed: Dictionary = {}
	for f in range(features.size()):
		var feature: Dictionary = features[f]
		var amount: float = float((feature["get"] as Callable).call())
		if amount == float(feature["last"]):
			continue
		feature["last"] = amount
		changed[f / 4] = true
	for group in changed:
		var packed := Vector4()
		for lane in range(4):
			var f: int = int(group) * 4 + lane
			if f < features.size():
				var feature: Dictionary = features[f]
				packed[lane] = clampf(inverse_lerp(float(feature["low"]), float(feature["high"]), float(feature["last"])),
					0.0, 1.0)
		var called := StringName("vat_amounts_%d" % int(group))
		for drawn in instances:
			drawn.set_instance_shader_parameter(called, packed)
	return changed.size()


func _process(_delta: float) -> void:
	play()


## THE PART'S MATERIAL AS A SHADER THAT PLAYS THE VAT, from the material's own generated code (`HingeCasting`'s door).
func _vat_material(material: Material, shader_rid: RID, turn: Texture2D, shift: Texture2D) -> Material:
	if material == null or not shader_rid.is_valid():
		push_warning("VatCasting: no shader to convert for %s; its parts will not move" % material)
		return material
	var code: String = RenderingServer.shader_get_code(shader_rid)
	if code.find("void vertex() {") < 0:
		return material
	var groups: int = int(ceil(float(features.size()) / 4.0))
	var uniforms: String = "\n// VAT CASTING (research/vertex_animation.md): a rigid-body VAT, rows by feature amount.\n"
	uniforms += "uniform sampler2D vat_turn : filter_nearest, repeat_disable;\n"
	uniforms += "uniform sampler2D vat_shift : filter_nearest, repeat_disable;\n"
	# THE TABLE OF CONTENTS: where each feature's rows start in the texture, and how many it has.
	uniforms += "uniform int vat_first[%d];\nuniform int vat_rows[%d];\n" % [MOST_FEATURES, MOST_FEATURES]
	for group in range(maxi(groups, 1)):
		uniforms += "instance uniform vec4 vat_amounts_%d = vec4(0.0);\n" % group
	uniforms += """
vec3 vat_rotate(vec4 q, vec3 v) {
	vec3 t = 2.0 * cross(q.xyz, v);
	return v + q.w * t + cross(q.xyz, t);
}
"""
	var pick: String = "0.0"
	for f in range(features.size() - 1, -1, -1):
		pick = "(f == %d ? vat_amounts_%d.%s : %s)" % [f, f / 4, "xyzw"[f % 4], pick]
	var block: String = """
	{
		int column = int(CUSTOM0.x + 0.5);
		for (int step = 0; step < 2; step++) {
			int f = int((step == 0 ? CUSTOM0.y : CUSTOM0.z) + 0.5) - 1;
			if (f >= 0) {
				int rows = vat_rows[f];
				float row = %s * float(rows - 1);
				int r0 = min(int(floor(row)), rows - 2);
				float u = row - float(r0);
				ivec2 a = ivec2(column, vat_first[f] + r0);
				ivec2 b = a + ivec2(0, 1);
				vec4 q0 = texelFetch(vat_turn, a, 0);
				vec4 q1 = texelFetch(vat_turn, b, 0);
				q1 = dot(q0, q1) < 0.0 ? -q1 : q1;
				vec4 q = normalize(mix(q0, q1, u));
				vec3 p = mix(texelFetch(vat_shift, a, 0).xyz, texelFetch(vat_shift, b, 0).xyz, u);
				VERTEX = vat_rotate(q, VERTEX) + p;
				NORMAL = vat_rotate(q, NORMAL);
				TANGENT = vat_rotate(q, TANGENT);
				BINORMAL = vat_rotate(q, BINORMAL);
			}
		}
	}
""" % pick
	var head: int = code.find("\nvoid vertex() {")
	code = code.substr(0, head) + uniforms + code.substr(head)
	var opened: int = code.find("void vertex() {") + "void vertex() {".length()
	code = code.substr(0, opened) + block + code.substr(opened)
	var shader := Shader.new()
	shader.code = code
	var played := ShaderMaterial.new()
	played.shader = shader
	for parameter in RenderingServer.get_shader_parameter_list(shader_rid):
		var called: String = parameter["name"]
		played.set_shader_parameter(called, RenderingServer.material_get_param(material.get_rid(), called))
	played.render_priority = material.render_priority
	played.set_shader_parameter("vat_turn", turn)
	played.set_shader_parameter("vat_shift", shift)
	var firsts := PackedInt32Array()
	var counts := PackedInt32Array()
	firsts.resize(MOST_FEATURES)
	counts.resize(MOST_FEATURES)
	for f in range(features.size()):
		firsts[f] = int(features[f]["first"])
		counts[f] = int(features[f]["rows"])
	played.set_shader_parameter("vat_first", firsts)
	played.set_shader_parameter("vat_rows", counts)
	return played


## THE SHADER'S ARITHMETIC ON THE CPU, for one rest-pose point of the part in `column`: what the GPU will draw it at.
## Not an independent check -- it shares every assumption with the shader -- but it measures the blending error in
## metres. `amounts` are the features' amounts in their own units.
func played_point(column: int, rest_point: Vector3, inner: int, outer: int, amounts: Array) -> Vector3:
	var v: Vector3 = rest_point
	for f in [inner, outer]:
		if f < 0: continue
		var feature: Dictionary = features[f]
		var t: float = clampf(inverse_lerp(float(feature["low"]), float(feature["high"]), float(amounts[f])), 0.0, 1.0)
		var rows: int = feature["rows"]
		var first: int = feature["first"]
		var row: float = t * float(rows - 1)
		var r0: int = mini(int(floor(row)), rows - 2)
		var u: float = row - float(r0)
		var c0: Color = turn_image.get_pixel(column, first + r0)
		var c1: Color = turn_image.get_pixel(column, first + r0 + 1)
		var q0 := Quaternion(c0.r, c0.g, c0.b, c0.a)
		var q1 := Quaternion(c1.r, c1.g, c1.b, c1.a)
		if q0.dot(q1) < 0.0: q1 = -q1
		var q: Quaternion = Quaternion(lerpf(q0.x, q1.x, u), lerpf(q0.y, q1.y, u), lerpf(q0.z, q1.z, u),
			lerpf(q0.w, q1.w, u)).normalized()
		var s0: Color = shift_image.get_pixel(column, first + r0)
		var s1: Color = shift_image.get_pixel(column, first + r0 + 1)
		v = q * v + Vector3(lerpf(s0.r, s1.r, u), lerpf(s0.g, s1.g, u), lerpf(s0.b, s1.b, u))
	return v


func surfaces() -> int:
	var total: int = 0
	for drawn in instances:
		total += drawn.mesh.get_surface_count()
	return total


func triangles() -> int:
	var total: int = 0
	for drawn in instances:
		for surface in range(drawn.mesh.get_surface_count()):
			total += Casting._triangles_in(drawn.mesh.surface_get_arrays(surface))
	return total


## The (inner, outer) feature indices a column's vertices carry, -1 for none, read back from the mesh.
func features_of(column: int) -> Vector2i:
	for drawn in instances:
		for surface in range(drawn.mesh.get_surface_count()):
			var arrays: Array = drawn.mesh.surface_get_arrays(surface)
			var tags = arrays[Mesh.ARRAY_CUSTOM0]
			if tags == null: continue
			var packed: PackedFloat32Array = tags if tags is PackedFloat32Array else (tags as PackedByteArray).to_float32_array()
			for i in range(0, packed.size(), 4):
				if int(packed[i] + 0.5) == column:
					return Vector2i(int(packed[i + 1] + 0.5) - 1, int(packed[i + 2] + 0.5) - 1)
	return Vector2i(-1, -1)
