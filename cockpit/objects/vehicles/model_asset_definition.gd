extends RefCounted
class_name ModelAssetDefinition
## The visual-only boundary between an immutable craft package and an imported scene.
## Godot's PackedScene contract supports runtime instantiate() for imported GLB scenes:
## https://docs.godotengine.org/en/stable/classes/class_packedscene.html

const AXIS_FORWARD := "-Z"
const AXIS_UP := "+Y"
const UNIT := "metres"
const DIMENSION_TOLERANCE := 0.02


static func definition_for(kind: int, root: String = AuthoredCraftPackages.ROOT) -> Dictionary:
	var package := AuthoredCraftPackages.read(kind, AuthoredCraftPackages.REVISION, root)
	if package.has("error"):
		return package
	var craft := package["craft"] as Dictionary
	var definition: Variant = craft.get("visual", null)
	if definition == null:
		return {}
	if not (definition is Dictionary):
		return {"error": "visual must be an object"}
	var why := validate(definition as Dictionary)
	return {"error": why} if why != "" else definition as Dictionary


static func validate(definition: Dictionary) -> String:
	if String(definition.get("units", "")) != UNIT:
		return "visual units must be metres"
	if String(definition.get("forward_axis", "")) != AXIS_FORWARD \
			or String(definition.get("up_axis", "")) != AXIS_UP:
		return "visual axes must be -Z forward and +Y up"
	var dimensions := definition.get("dimensions_m", []) as Array
	if dimensions.size() != 3:
		return "visual dimensions_m must be [span, height, length]"
	for value in dimensions:
		if not (value is float or value is int) or float(value) <= 0.0:
			return "visual dimensions must be positive numbers"
	var origin := definition.get("offset_m", []) as Array
	var rotation := definition.get("rotation_deg", []) as Array
	if origin.size() != 3 or rotation.size() != 3:
		return "visual offset_m and rotation_deg must be triples"
	var path := String(definition.get("scene", ""))
	if not path.is_empty() and (not path.begins_with("res://") or not (path.ends_with(".tscn") or path.ends_with(".scn") or path.ends_with(".glb") or path.ends_with(".gltf"))):
		return "visual scene must be a res:// PackedScene or GLB"
	var sockets: Variant = definition.get("sockets", null)
	if not (sockets is Dictionary):
		return "visual sockets must be an object"
	for socket_name in sockets:
		if String(socket_name).is_empty() or not ((sockets as Dictionary)[socket_name] is Array) \
				or ((sockets as Dictionary)[socket_name] as Array).size() != 3:
			return "visual socket %s must be a named metre triple" % socket_name
	return ""


static func instantiate_for(kind: int, geometry: Dictionary,
		root: String = AuthoredCraftPackages.ROOT) -> Dictionary:
	var definition := definition_for(kind, root)
	if definition.is_empty() or definition.has("error"):
		return definition
	# Dimensions are presentation facts. Native extents, seats and model identifiers are
	# intentionally never written here, so a visual replacement cannot alter simulation.
	var path := String(definition.get("scene", ""))
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		return {"error": "visual scene is unavailable"}
	var packed := ResourceLoader.load(path, "PackedScene") as PackedScene
	if packed == null or not packed.can_instantiate():
		return {"error": "visual scene is not instantiable"}
	var node := packed.instantiate() as Node3D
	if node == null:
		return {"error": "visual scene root must be Node3D"}
	# Imported GLB scenes already contain meshes. Code-native procedural scenes may build
	# through the same boundary and expose `_build`; materialize them before scale checks.
	if node.get_child_count() == 0 and node.has_method("_build"):
		node.call("_build")
	node.position = _vector(definition.get("offset_m", []))
	var degrees := _vector(definition.get("rotation_deg", []))
	node.rotation = Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))
	var actual := _mesh_bounds(node).size
	var expected := _vector(definition.get("dimensions_m", []))
	var measured := Vector3(actual.x, actual.y, actual.z)
	if actual == Vector3.ZERO or absf(measured.x - expected.x) > expected.x * DIMENSION_TOLERANCE \
			or absf(measured.y - expected.y) > expected.y * DIMENSION_TOLERANCE \
			or absf(measured.z - expected.z) > expected.z * DIMENSION_TOLERANCE:
		node.free()
		return {"error": "visual scene bounds %s differ from declared metres %s" % [measured, expected]}
	return {"node": node, "definition": definition, "native_geometry": geometry.duplicate(true),
		"bounds": _mesh_bounds(node)}


static func _vector(value: Variant) -> Vector3:
	var values := value as Array
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


static func _mesh_bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var found := false
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var drawn := child as MeshInstance3D
		if drawn.mesh == null: continue
		var transform := Transform3D.IDENTITY
		var cursor: Node3D = drawn
		while cursor != root:
			transform = cursor.transform * transform
			cursor = cursor.get_parent() as Node3D
		var local := drawn.get_aabb()
		for corner in range(8):
			var point := transform * local.get_endpoint(corner)
			bounds = bounds.expand(point) if found else AABB(point, Vector3.ZERO)
			found = true
	return bounds
