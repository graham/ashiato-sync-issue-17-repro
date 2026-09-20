extends RefCounted
## Large, map-only terrain for visual probes whose ordinary test room contains
## no level scenery. Layer 20 keeps it out of the probe's eye camera while the
## LevelMap camera (which sees all layers) records it.

const MAP_LAYER := 1 << 19


static func add_island(parent: Node) -> void:
	_mesh(parent, Vector3(16000, 4, 16000), Vector3(0, -4, 0), Color("164d72"))
	_mesh(parent, Vector3(14400, 2, 14400), Vector3(0, -1, 0), Color("486b43"))
	for box in Terrain.boxes():
		var half := box.get("half_extents", Vector3.ZERO) as Vector3
		if half == Vector3.ZERO:
			continue
		var at := box["position"] as Vector3
		var height := clampf((at.y + half.y) / 700.0, 0.0, 1.0)
		_mesh(parent, half * 2.0, at, Color("65744b").lerp(Color("b6afa0"), height))


static func _mesh(parent: Node, size: Vector3, at: Vector3, colour: Color) -> void:
	var shape := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	shape.mesh = box
	shape.position = at
	shape.layers = MAP_LAYER
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	shape.material_override = material
	parent.add_child(shape)
