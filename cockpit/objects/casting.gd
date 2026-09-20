extends Node3D
class_name Casting
## A CASTING: many drawn parts poured into one mesh, which the renderer draws in one call per material while the parts it
## was cast from stay in the tree, named and moving, as the pattern. RESEARCH PROOF OF CONCEPT (`research/static_bake.md`);
## nothing in the game builds one yet.
##
## THE DECISION: THE PATTERN STAYS THE AUTHORITY, AND NOTHING IS DECLARED. A craft is built as it always has been -- named
## `MeshInstance3D`s, a flap on a node pivoted on its hinge, `set_flaps` turning that node -- and `Casting.pour(root)` then
## copies every part's triangles into one `ArrayMesh`, each part rigidly weighted to ONE BONE of its own. Every frame the
## casting reads each part's transform relative to the root and its visibility, and poses that part's bone to match. So a
## flap moves because its pattern node moved, exactly as before, and nobody wrote down which parts move: a table of
## "these are the animated ones" is a second copy of what `set_flaps` already knows (CLAUDE.md rule 4), and it goes out of
## date the first time somebody makes a strut fold. A part that is hidden has its bone scaled to nothing.
##
## THE PATTERN STOPS DRAWING, AND STAYS VISIBLE. Each part cast is put on render layer 0 with its shadow off, so no camera
## and no light draws it; `visible` is untouched, because it is what the airframe's own code toggles (`set_propeller`
## swaps the blades for the disc) and what `named_parts`, `joined_parts` and every geometry suite walk. Those suites go on
## measuring the pattern. **They must skip the casting**, which carries the meta `CAST_FROM`: it overlaps every part it was
## cast from, so to a union of drawn boxes it would join a floating part back to the aeroplane (measured in
## `tests/bake_shot.gd`).
##
## ONE SURFACE PER MATERIAL, ONE INSTANCE PER DRAW SETTING. A surface is a draw call, so parts sharing a material instance
## share a surface. Shadow casting and a visibility range belong to an instance, not a surface, so parts that differ in
## those go to separate casting instances; every instance shares the one skeleton.
##
## A PART THAT CHANGES WHAT IT IS LEAVES. If a part's mesh or active material is no longer the one it was cast with,
## its bone is scaled to nothing and the part is put back on its own layers, drawing itself again. A casting can never
## show a stale picture; at worst it costs the draw it would have saved.
##
## MATERIALS THAT DIFFER ONLY IN THEIR ALBEDO COLOUR BECOME ONE, with the colour moved into the vertices -- the house
## style every faceted model here already uses (`modelling_here.md` section 4). A building authored as boxes with one
## `StandardMaterial3D` a colour is eight surfaces, so eight draws on the Mobile renderer, however it is merged; flattened
## it is one. Colour is carried in LINEAR and written back as sRGB with `vertex_color_is_srgb`, because the albedo colour
## is sRGB and a vertex colour is linear unless told otherwise (the carrier's 0.19 deck that drew at 0.47). A material
## with a texture, transparency or anything else that differs is left as its own surface.
##
## WHAT IT DOES NOT TOUCH: collision, which is the simulation's box in C++; seats, sockets and anything under a control,
## a station or a shell, which own their own meshes and are not cast -- the same owners `tests/drawn_parts.gd` stops at.

## Meta on every casting instance, naming the root it was poured from. What a suite that walks drawn parts skips.
const CAST_FROM := &"cast_from"

## The parts, in bone order: {node, mesh, material (Array per surface), layers, shadow, bone}.
var parts: Array[Dictionary] = []
var skeleton: Skeleton3D = null
var instances: Array[MeshInstance3D] = []
var root: Node3D = null
## Parts that left the casting because their mesh or material changed, by name.
var left: PackedStringArray = []


## POUR every drawn part under `root` into castings added to `root`, and return the Casting node that keeps them posed.
## `skip` is called with each candidate MeshInstance3D and may refuse it (return true to leave it out).
static func pour(from: Node3D, skip: Callable = Callable(), flatten: bool = true) -> Casting:
	var casting := Casting.new()
	var flat: Dictionary = {}
	casting.name = "Casting"
	casting.root = from
	var groups: Dictionary = {}
	for found in from.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if part.mesh == null or part.skeleton != NodePath("") and part.skin != null:
			continue
		# A PART HIDDEN WHEN POURED STAYS OUT, and draws itself if it is ever shown: the Cessna's propeller disc, which only
		# a turning propeller shows, and the procedural hull a package's visual scene replaces. Pouring them would carry
		# their triangles in every frame, scaled to nothing.
		if _owned(part) or not part.is_visible_in_tree() or part.layers == 0:
			continue
		if skip.is_valid() and bool(skip.call(part)):
			continue
		var bone: int = casting.parts.size()
		var materials: Array = []
		for surface in range(part.mesh.get_surface_count()):
			materials.append(part.get_active_material(surface))
		casting.parts.append({"node": part, "mesh": part.mesh, "material": materials, "layers": part.layers,
			"shadow": part.cast_shadow, "bone": bone})
		var key: String = "%d|%.3f|%.3f|%.3f|%.3f" % [part.cast_shadow, part.visibility_range_begin,
			part.visibility_range_end, part.visibility_range_begin_margin, part.visibility_range_end_margin]
		if not groups.has(key):
			groups[key] = {"like": part, "surfaces": {}}
		var into: Transform3D = from.global_transform.affine_inverse() * part.global_transform
		for surface in range(part.mesh.get_surface_count()):
			var material: Material = materials[surface]
			var by: Dictionary = groups[key]["surfaces"]
			var id: Variant = material.get_instance_id() if material != null else 0
			var tint: Dictionary = {}
			var signature: String = _albedo_only(material) if flatten else ""
			if not signature.is_empty():
				if not flat.has(signature):
					flat[signature] = _flat_material(material as StandardMaterial3D)
				var standard := material as StandardMaterial3D
				tint = {"albedo": standard.albedo_color, "vertex": standard.vertex_color_use_as_albedo,
					"srgb": standard.vertex_color_is_srgb}
				material = flat[signature]
				id = signature
			if not by.has(id):
				by[id] = {"material": material, "chunks": []}
			(by[id]["chunks"] as Array).append({"arrays": part.mesh.surface_get_arrays(surface), "into": into, "bone": bone,
				"tint": tint,
				"primitive": part.mesh.surface_get_primitive_type(surface) if part.mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES})
	if casting.parts.is_empty():
		return casting
	casting.skeleton = Skeleton3D.new()
	casting.skeleton.name = "CastingSkeleton"
	var skin := Skin.new()
	for entry in casting.parts:
		# A BONE IS NAMED FOR ITS PART, and a bone name may hold neither ':' nor '/', so not the part's path: the first
		# pour named them by path, `add_bone` refused all seventeen, and the casting drew nothing at all.
		casting.skeleton.add_bone("%d_%s" % [int(entry["bone"]), String((entry["node"] as Node).name)])
		# THE BIND IS THE INVERSE OF WHERE THE PART WAS WHEN IT WAS POURED: its vertices are stored in the root's frame at
		# that pose, so a bone posed to the part's pose now carries them to where the part is now.
		var poured: Transform3D = from.global_transform.affine_inverse() * (entry["node"] as Node3D).global_transform
		skin.add_bind(int(entry["bone"]), poured.affine_inverse())
	casting.add_child(casting.skeleton)
	var index: int = 0
	for key in groups:
		var like: MeshInstance3D = groups[key]["like"]
		var mesh := ArrayMesh.new()
		for id in groups[key]["surfaces"]:
			var surface: Dictionary = groups[key]["surfaces"][id]
			var arrays: Array = _merge(surface["chunks"])
			if arrays.is_empty():
				continue
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, surface["material"])
		var drawn := MeshInstance3D.new()
		drawn.name = "Cast%d" % index
		index += 1
		drawn.mesh = mesh
		drawn.cast_shadow = like.cast_shadow
		drawn.visibility_range_begin = like.visibility_range_begin
		drawn.visibility_range_end = like.visibility_range_end
		drawn.visibility_range_begin_margin = like.visibility_range_begin_margin
		drawn.visibility_range_end_margin = like.visibility_range_end_margin
		drawn.visibility_range_fade_mode = like.visibility_range_fade_mode
		drawn.set_meta(CAST_FROM, from.get_path())
		casting.add_child(drawn)
		drawn.skin = skin
		drawn.skeleton = drawn.get_path_to(casting.skeleton)
		casting.instances.append(drawn)
	casting.set_meta(CAST_FROM, from.get_path())
	from.add_child(casting)
	# THE CASTING SITS AT THE ROOT'S ORIGIN, so its bones are in the root's frame.
	casting.transform = Transform3D.IDENTITY
	for entry in casting.parts:
		var node: MeshInstance3D = entry["node"]
		node.layers = 0
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	casting.pose()
	return casting


## WHAT A MATERIAL IS APART FROM ITS ALBEDO COLOUR, or "" if it cannot be flattened: every stored property except the
## colour and the two vertex-colour switches, so two materials with the same signature draw the same once their colour
## is in the vertices. Not a `StandardMaterial3D`, or textured, or transparent: "".
static func _albedo_only(material: Material) -> String:
	var standard := material as StandardMaterial3D
	if standard == null or standard.albedo_texture != null or standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return ""
	var words: PackedStringArray = []
	for property in standard.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var called: String = property["name"]
		if called in ["albedo_color", "vertex_color_use_as_albedo", "vertex_color_is_srgb", "resource_name", "resource_path",
				"resource_local_to_scene", "script"]:
			continue
		words.append("%s=%s" % [called, var_to_str(standard.get(called))])
	return "|".join(words)


static func _flat_material(like: StandardMaterial3D) -> StandardMaterial3D:
	var flat := like.duplicate() as StandardMaterial3D
	flat.albedo_color = Color.WHITE
	flat.vertex_color_use_as_albedo = true
	flat.vertex_color_is_srgb = true
	return flat


## A MESH INSIDE A CONTROL, A STATION OR A SHELL belongs to it: those change their own meshes and materials as they are
## worked, and are not the craft's to cast.
static func _owned(part: Node) -> bool:
	var walk: Node = part.get_parent()
	while walk != null:
		if walk is VehicleControl or walk is CockpitStation or walk is CockpitShell:
			return true
		walk = walk.get_parent()
	return false


## POSE every bone to its part, as the part stands now: its transform in the root's frame, or nothing if it is hidden.
## Returns how many bones moved.
func pose() -> int:
	if skeleton == null:
		return 0
	var moved: int = 0
	var into: Transform3D = root.global_transform.affine_inverse()
	for entry in parts:
		var node: MeshInstance3D = entry["node"]
		var bone: int = entry["bone"]
		var gone: bool = not is_instance_valid(node) or _changed(entry)
		var hidden: bool = gone or not node.is_visible_in_tree()
		var want: Transform3D = (Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO) if hidden
			else into * node.global_transform)
		if skeleton.get_bone_pose(bone) == want:
			continue
		moved += 1
		# A HIDDEN PART'S BONE IS SCALED TO NOTHING, set in three parts: `set_bone_pose` turns its basis into a quaternion,
		# and a zero basis is not a rotation -- the flown Cessna's feathered blades printed that error a hundred times.
		if hidden:
			skeleton.set_bone_pose_position(bone, Vector3.ZERO)
			skeleton.set_bone_pose_scale(bone, Vector3.ZERO)
		else:
			skeleton.set_bone_pose(bone, want)
	return moved


func _process(_delta: float) -> void:
	pose()


## HAS THIS PART STOPPED BEING WHAT WAS POURED? If so it leaves: back on its own layers and shadow, drawing itself.
func _changed(entry: Dictionary) -> bool:
	if entry.get("left", false):
		return true
	var node: MeshInstance3D = entry["node"]
	var same: bool = node.mesh == entry["mesh"]
	if same:
		for surface in range((entry["material"] as Array).size()):
			if node.get_active_material(surface) != (entry["material"] as Array)[surface]:
				same = false
				break
	if same:
		return false
	entry["left"] = true
	node.layers = entry["layers"]
	node.cast_shadow = entry["shadow"]
	left.append(String(node.name))
	return true


## Every draw call this casting's instances cost in one pass: one per surface of each visible instance.
func surfaces() -> int:
	var total: int = 0
	for drawn in instances:
		total += drawn.mesh.get_surface_count()
	return total


## Every triangle in the casting.
func triangles() -> int:
	var total: int = 0
	for drawn in instances:
		for surface in range(drawn.mesh.get_surface_count()):
			total += _triangles_in(drawn.mesh.surface_get_arrays(surface))
	return total


static func _triangles_in(arrays: Array) -> int:
	var indices = arrays[Mesh.ARRAY_INDEX]
	if indices != null and (indices as PackedInt32Array).size() > 0:
		return (indices as PackedInt32Array).size() / 3
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	return 0 if vertices == null else (vertices as PackedVector3Array).size() / 3


## ONE SURFACE FROM MANY CHUNKS: vertices and normals carried into the root's frame, colours and UVs kept, every vertex
## weighted wholly to its part's bone. A chunk that is not triangles is skipped and said so.
static func _merge(chunks: Array) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var any_colour: bool = false
	var any_uv: bool = false
	for chunk in chunks:
		if int(chunk["primitive"]) != Mesh.PRIMITIVE_TRIANGLES:
			push_warning("Casting: a surface that is not triangles was left out")
			continue
		var arrays: Array = chunk["arrays"]
		var into: Transform3D = chunk["into"]
		var turn: Basis = into.basis.inverse().transposed()
		var from: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var their_normals = arrays[Mesh.ARRAY_NORMAL]
		var their_colours = arrays[Mesh.ARRAY_COLOR]
		var their_uvs = arrays[Mesh.ARRAY_TEX_UV]
		var their_indices = arrays[Mesh.ARRAY_INDEX]
		var tint: Dictionary = chunk.get("tint", {})
		var base: int = vertices.size()
		for i in range(from.size()):
			vertices.append(into * from[i])
			normals.append((turn * (their_normals as PackedVector3Array)[i]).normalized()
				if their_normals != null and (their_normals as PackedVector3Array).size() == from.size() else Vector3.UP)
			var has_colour: bool = their_colours != null and (their_colours as PackedColorArray).size() == from.size()
			if not tint.is_empty():
				# THE MATERIAL'S COLOUR TIMES THE VERTEX'S IF THE MATERIAL USED IT, in linear, written back as sRGB.
				var linear: Color = (tint["albedo"] as Color).srgb_to_linear()
				if bool(tint["vertex"]) and has_colour:
					var own: Color = (their_colours as PackedColorArray)[i]
					linear *= own.srgb_to_linear() if bool(tint["srgb"]) else own
				colours.append(linear.linear_to_srgb())
				any_colour = true
			elif has_colour:
				colours.append((their_colours as PackedColorArray)[i])
				any_colour = true
			else:
				colours.append(Color.WHITE)
			if their_uvs != null and (their_uvs as PackedVector2Array).size() == from.size():
				uvs.append((their_uvs as PackedVector2Array)[i])
				any_uv = true
			else:
				uvs.append(Vector2.ZERO)
			bones.append_array([int(chunk["bone"]), 0, 0, 0])
			weights.append_array([1.0, 0.0, 0.0, 0.0])
		if their_indices != null and (their_indices as PackedInt32Array).size() > 0:
			for index in their_indices:
				indices.append(base + int(index))
		else:
			for i in range(from.size()):
				indices.append(base + i)
	if vertices.is_empty():
		return []
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	if any_colour:
		arrays[Mesh.ARRAY_COLOR] = colours
	if any_uv:
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays
