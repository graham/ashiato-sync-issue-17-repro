extends Node3D
class_name HingeCasting
## A HINGE CASTING: a craft's drawn parts poured into one mesh, as `Casting` pours them, but with NO SKELETON. A part that
## swings on a hinge swings in the VERTEX SHADER, turned about its hinge line by an angle the craft hands the GPU as an
## `instance uniform`. RESEARCH PROOF OF CONCEPT (`research/vertex_animation.md`); nothing in the game builds one.
##
## WHY NOT BONES: `Casting` gives every part a bone and poses all seventeen from GDScript every frame, and that posing is
## what made 100 cast Cessnas 2.55 ms a frame slower than their parts (`research/static_bake.md`). A control surface and
## a gear door are RIGID PARTS TURNING ABOUT A FIXED LINE, so what the GPU needs to move one is a line and an angle, not
## a matrix. Here the CPU's whole job is to set one `vec4` per hinge, and only for a hinge whose angle changed.
##
## WHY NOT A VERTEX ANIMATION TEXTURE: a VAT replays a baked timeline, and an aileron follows the stick. A VAT indexed by
## deflection instead of time is a table of this file's formula at fixed steps, fetched per vertex; the formula is exact
## and costs a dozen multiplies. Section 3 of the research.
##
## THE AIRFRAME STAYS THE AUTHORITY, AND NOTHING NEW IS DECLARED. Which parts swing, and about which line, is the
## airframe's own record, `SkyhawkAirframe._hinges` (the node, where its hinge is, the axis): the dictionary its own
## `_swing` reads. The angle is read off the part's node as `_swing` left it. So `set_ailerons` and its siblings go on
## turning nodes, exactly as before, and this casting copies what they did.
##
## WHAT EACH HINGE HANDS THE GPU, ONE vec4 (`swing_<slot>`): xyz is how far the part has slid from its hinge, in the
## root's frame -- the flap slides aft and down as it lowers -- and w is the angle. The hinge's point and axis, in the
## root's frame at the pour, are MATERIAL uniform arrays: one per kind, shared by every copy. Each vertex carries its
## slot and its hinged parent's slot in CUSTOM0 (the trim tab hangs on the elevator: turn it about its own hinge, then
## about the elevator's). A vertex on a part that never moves is slot 0 and the shader leaves it alone.
##
## THE MATERIAL IS THE PART'S OWN, CONVERTED. A `StandardMaterial3D`'s generated shader code is read back from the
## server (what the editor's "Convert to ShaderMaterial" does), the hinge block is put at the top of `vertex()`, and the
## material's parameters are copied across. The same vertex function runs in the shadow pass, so a lowered flap casts a
## lowered shadow.
##
## LIMITS, MEASURED OR KNOWN: at most 16 instance uniforms per shader (`MAX_INSTANCE_UNIFORM_INDICES`), so 16 hinges a
## craft -- the Cessna has 8. A part that moves any other way (the propeller spins, the disc fades) is not poured and
## draws itself. A part that is hidden, or whose mesh or material changes, is not followed: `Casting` does that with a
## zero-scale bone and this does not. It carries `Casting.CAST_FROM`, so it has `Casting`'s duty to the drawn-parts
## checks too.

## The most hinges one shader can take: one instance uniform each.
const MOST_HINGES := 16

## The hinged parts, slot 1 upward: {node, slot, parent, rest_basis (root frame of the parent at the pour), axis, at,
## last (the vec4 last handed over)}.
var hinges: Array[Dictionary] = []
var instances: Array[MeshInstance3D] = []
## For each hinge slot, the instances holding a vertex on it: only those are handed its swing.
var holders: Dictionary = {}
var root: Node3D = null
## Every part poured, fixed or hinged.
var poured: int = 0


## POUR every drawn part under `from` into hinge castings added to `from`. `hinged` is the airframe's own hinge record,
## {MeshInstance3D: [position, axis]}. `skip` may refuse a part (return true), as `Casting.pour`'s does.
##
## A COROUTINE: `await HingeCasting.pour(...)`. Reading a material's generated shader back takes a frame (`_shaders_of`).
static func pour(from: Node3D, hinged: Dictionary, skip: Callable = Callable()) -> HingeCasting:
	var casting := HingeCasting.new()
	casting.name = "HingeCasting"
	casting.root = from
	var into_root: Transform3D = from.global_transform.affine_inverse()
	# SLOTS FIRST, in a stable order, so a parent's slot is known before its children's are asked for.
	var slot_of: Dictionary = {}
	for node in hinged:
		if not is_instance_valid(node) or not (node as Node3D).is_visible_in_tree():
			continue
		if slot_of.size() >= MOST_HINGES:
			push_warning("HingeCasting: more than %d hinges; %s left to draw itself" % [MOST_HINGES, (node as Node).name])
			continue
		slot_of[node] = slot_of.size() + 1
	for node in slot_of:
		var part: Node3D = node
		var record: Array = hinged[node]
		var parent_frame: Transform3D = into_root * (part.get_parent() as Node3D).global_transform
		casting.hinges.append({"node": part, "slot": int(slot_of[node]), "parent": _hinged_parent(part, slot_of),
			"built_at": record[0] as Vector3, "local_axis": (record[1] as Vector3).normalized(),
			"rest_basis": parent_frame.basis,
			"at": parent_frame * (record[0] as Vector3),
			"axis": (parent_frame.basis * (record[1] as Vector3)).normalized(),
			"last": Vector4(INF, INF, INF, INF), "uniform": StringName("swing_%d" % int(slot_of[node]))})
	# THE PARTS, grouped as `Casting` groups them: an instance per draw setting, a surface per material.
	var groups: Dictionary = {}
	var converted: Dictionary = {}
	var flat: Dictionary = {}
	for found in from.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if part.mesh == null or Casting._owned(part) or not part.is_visible_in_tree() or part.layers == 0:
			continue
		if skip.is_valid() and bool(skip.call(part)):
			continue
		var slot: int = int(slot_of.get(part, 0))
		var parent_slot: int = _hinged_parent(part, slot_of) if slot > 0 else 0
		if slot == 0 and _hinged_parent(part, slot_of) > 0:
			# A FIXED PART ON A HINGED ONE rides with it: slot is its parent's.
			slot = _hinged_parent(part, slot_of)
			parent_slot = _hinged_parent(_node_of_slot(slot, slot_of), slot_of)
		casting.poured += 1
		var key: String = "%d|%.3f|%.3f|%.3f|%.3f" % [part.cast_shadow, part.visibility_range_begin,
			part.visibility_range_end, part.visibility_range_begin_margin, part.visibility_range_end_margin]
		if not groups.has(key):
			groups[key] = {"like": part, "surfaces": {}, "slots": {}}
		groups[key]["slots"][slot] = true
		groups[key]["slots"][parent_slot] = true
		var into: Transform3D = into_root * part.global_transform
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
			(by[id]["chunks"] as Array).append({"arrays": part.mesh.surface_get_arrays(surface), "into": into,
				"bone": 0, "tint": tint, "slot": slot, "parent": parent_slot,
				"primitive": part.mesh.surface_get_primitive_type(surface) if part.mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES})
	var wanted: Array = []
	for key in groups:
		for id in groups[key]["surfaces"]:
			var material: Material = groups[key]["surfaces"][id]["material"]
			if material != null and not wanted.has(material): wanted.append(material)
	var shaders: Dictionary = await _shaders_of(wanted, from)
	var index: int = 0
	for key in groups:
		var like: MeshInstance3D = groups[key]["like"]
		var mesh := ArrayMesh.new()
		for id in groups[key]["surfaces"]:
			var surface: Dictionary = groups[key]["surfaces"][id]
			var arrays: Array = Casting._merge(surface["chunks"])
			if arrays.is_empty():
				continue
			# NO BONES: the slot of each vertex goes in CUSTOM0 instead, in the same order `_merge` laid the vertices.
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			var slots := PackedFloat32Array()
			for chunk in surface["chunks"]:
				if int(chunk["primitive"]) != Mesh.PRIMITIVE_TRIANGLES:
					continue
				var count: int = ((chunk["arrays"] as Array)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				for i in range(count):
					slots.append_array([float(chunk["slot"]), float(chunk["parent"]), 0.0, 0.0])
			arrays[Mesh.ARRAY_CUSTOM0] = slots
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
				Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
			var material: Material = surface["material"]
			if not converted.has(material):
				converted[material] = casting._hinged_material(material, shaders.get(material, RID()))
			mesh.surface_set_material(mesh.get_surface_count() - 1, converted[material])
		var drawn := MeshInstance3D.new()
		drawn.name = "HingeCast%d" % index
		index += 1
		drawn.mesh = mesh
		drawn.cast_shadow = like.cast_shadow
		drawn.visibility_range_begin = like.visibility_range_begin
		drawn.visibility_range_end = like.visibility_range_end
		drawn.visibility_range_begin_margin = like.visibility_range_begin_margin
		drawn.visibility_range_end_margin = like.visibility_range_end_margin
		drawn.visibility_range_fade_mode = like.visibility_range_fade_mode
		# THE BOX MUST HOLD EVERY POSE: a lowered flap leaves the poured box, and a box that does not hold it culls the
		# craft while its flap is still on screen. A metre all round covers every Cessna surface's travel.
		drawn.extra_cull_margin = 1.0
		drawn.set_meta(Casting.CAST_FROM, from.get_path())
		casting.add_child(drawn)
		casting.instances.append(drawn)
		for slot in groups[key]["slots"]:
			if int(slot) > 0:
				if not casting.holders.has(int(slot)):
					casting.holders[int(slot)] = []
				(casting.holders[int(slot)] as Array).append(drawn)
	casting.set_meta(Casting.CAST_FROM, from.get_path())
	from.add_child(casting)
	casting.transform = Transform3D.IDENTITY
	for found in from.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if part.get_parent() == casting or casting.is_ancestor_of(part):
			continue
		if part.mesh == null or Casting._owned(part) or not part.is_visible_in_tree() or part.layers == 0:
			continue
		if skip.is_valid() and bool(skip.call(part)):
			continue
		part.layers = 0
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for hinge in casting.hinges:
		hinge["holders"] = casting.holders.get(int(hinge["slot"]), [])
	# POURED AT REST OR NOT AT ALL: the vertices are stored as they stand, and the shader adds the swing to them, so a
	# surface poured deflected would be turned twice.
	for hinge in casting.hinges:
		var node: Node3D = hinge["node"]
		if not node.quaternion.is_equal_approx(Quaternion.IDENTITY) or not node.position.is_equal_approx(hinge["built_at"]):
			push_error("HingeCasting: %s was poured away from its rest pose; it will draw turned twice" % node.name)
	casting.swing()
	return casting


## The slot of the nearest hinged node above `part` (not `part` itself), or 0.
static func _hinged_parent(part: Node, slot_of: Dictionary) -> int:
	var walk: Node = part.get_parent()
	while walk != null:
		if slot_of.has(walk):
			return int(slot_of[walk])
		walk = walk.get_parent()
	return 0


static func _node_of_slot(slot: int, slot_of: Dictionary) -> Node:
	for node in slot_of:
		if int(slot_of[node]) == slot:
			return node
	return null


## HAND THE GPU EVERY HINGE THAT MOVED: its angle about its own axis, and how far it has slid from its hinge, in the
## root's frame. Returns how many hinges changed. Nothing is set for a hinge that did not move, so a parked craft costs a
## compare per hinge.
func swing() -> int:
	var changed: int = 0
	for hinge in hinges:
		var node: Node3D = hinge["node"]
		# THE CHEAP QUESTION FIRST: has the node's own transform changed at all? A parked craft stops here, and the first
		# version, which worked the angle out before asking, cost 4 us a Cessna a frame to learn that nothing had moved.
		var seen: Transform3D = node.transform
		if seen == hinge.get("seen", Transform3D()) and hinge["last"] != Vector4(INF, INF, INF, INF):
			continue
		hinge["seen"] = seen
		var q: Quaternion = seen.basis.get_rotation_quaternion()
		var axis: Vector3 = hinge["local_axis"]
		# THE ANGLE ABOUT THE HINGE'S OWN AXIS, which is all `_swing` ever turns a part by.
		var angle: float = 2.0 * atan2(q.x * axis.x + q.y * axis.y + q.z * axis.z, q.w)
		var slid: Vector3 = (hinge["rest_basis"] as Basis) * (seen.origin - (hinge["built_at"] as Vector3))
		var now := Vector4(slid.x, slid.y, slid.z, angle)
		if now == hinge["last"]:
			continue
		hinge["last"] = now
		changed += 1
		var called: StringName = hinge["uniform"]
		for drawn in hinge["holders"]:
			(drawn as MeshInstance3D).set_instance_shader_parameter(called, now)
	return changed


func _process(_delta: float) -> void:
	swing()


## THE PART'S MATERIAL AS A SHADER THAT TURNS EACH VERTEX ABOUT ITS HINGE. Built from the material's own generated code
## so it draws as the part did; the hinge block goes first in `vertex()`, before anything the material does there.
func _hinged_material(material: Material, shader_rid: RID) -> Material:
	if material == null or not shader_rid.is_valid():
		push_warning("HingeCasting: no shader to convert for %s; its parts will not swing" % material)
		return material
	var code: String = RenderingServer.shader_get_code(shader_rid)
	if code.is_empty() or code.find("void vertex() {") < 0:
		push_warning("HingeCasting: no generated shader code to convert for %s" % material)
		return material
	var uniforms: String = "\n// HINGE CASTING (research/vertex_animation.md): each vertex turned about its hinge.\n"
	uniforms += "uniform vec3 hinge_at[%d];\nuniform vec3 hinge_axis[%d];\n" % [MOST_HINGES + 1, MOST_HINGES + 1]
	for slot in range(1, hinges.size() + 1):
		uniforms += "instance uniform vec4 swing_%d = vec4(0.0);\n" % slot
	uniforms += """
vec3 hinge_turn(vec3 axis, float angle, vec3 v) {
	float c = cos(angle);
	float s = sin(angle);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}
"""
	# THE PICK IS A CHAIN OF SELECTS written out in vertex(), because an instance uniform is read through the instance's
	# own index and is not something to pass around.
	var pick: String = "vec4(0.0)"
	for slot in range(hinges.size(), 0, -1):
		pick = "(s == %d ? swing_%d : %s)" % [slot, slot, pick]
	var block: String = """
	{
		int own = int(CUSTOM0.x + 0.5);
		int up = int(CUSTOM0.y + 0.5);
		for (int step = 0; step < 2; step++) {
			int s = step == 0 ? own : up;
			if (s > 0) {
				vec4 w = %s;
				vec3 at = hinge_at[s];
				vec3 axis = hinge_axis[s];
				VERTEX = at + hinge_turn(axis, w.w, VERTEX - at) + w.xyz;
				NORMAL = hinge_turn(axis, w.w, NORMAL);
				TANGENT = hinge_turn(axis, w.w, TANGENT);
				BINORMAL = hinge_turn(axis, w.w, BINORMAL);
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
	var hinged := ShaderMaterial.new()
	hinged.shader = shader
	# THE MATERIAL'S OWN PARAMETERS, as the server holds them: what the editor's conversion copies.
	for parameter in RenderingServer.get_shader_parameter_list(shader_rid):
		var called: String = parameter["name"]
		hinged.set_shader_parameter(called, RenderingServer.material_get_param(material.get_rid(), called))
	hinged.render_priority = material.render_priority
	var at := PackedVector3Array()
	var axes := PackedVector3Array()
	at.resize(MOST_HINGES + 1)
	axes.resize(MOST_HINGES + 1)
	for hinge in hinges:
		at[int(hinge["slot"])] = hinge["at"]
		axes[int(hinge["slot"])] = hinge["axis"]
	hinged.set_shader_parameter("hinge_at", at)
	hinged.set_shader_parameter("hinge_axis", axes)
	return hinged


## Every draw this casting's instances cost in one pass: one per surface.
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


## EACH MATERIAL'S SHADER, as the server holds it. `Material.get_shader_rid` is not bound for scripts; the one door is
## `inspect_native_shader_code`, which hands the RID to every node in the group `_native_shader_source_visualizer` --
## the editor's shader viewer -- by a deferred call. So a node joins that group, every material is inspected, and a frame
## later the RIDs have arrived. The material's generated code is then the server's `shader_get_code`, which is what the
## editor's own "Convert to ShaderMaterial" reads.
## The catcher joins `near`, not the tree's root: a root still in its own `_ready` refuses a child.
static func _shaders_of(materials: Array, near: Node) -> Dictionary:
	var found: Dictionary = {}
	var tree: SceneTree = near.get_tree()
	var catcher := ShaderCatcher.new()
	near.add_child(catcher)
	catcher.add_to_group(&"_native_shader_source_visualizer")
	for material in materials:
		catcher.caught.clear()
		(material as Material).inspect_native_shader_code()
		await tree.process_frame
		if not catcher.caught.is_empty():
			found[material] = catcher.caught[0]
	catcher.queue_free()
	return found


## Stands in for the editor's shader viewer: keeps the RID it is handed.
class ShaderCatcher extends Node:
	var caught: Array[RID] = []

	func _inspect_shader(shader: RID) -> void:
		caught.append(shader)
