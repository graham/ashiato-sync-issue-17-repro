extends Node3D
class_name ModelInspector
## Builder overlay for the model/package coordinate contract. It deliberately reads native
## collision and station geometry separately from optional visual metadata.

var inspected: VehicleView = null
var overlays := Node3D.new()


func _ready() -> void:
	overlays.name = "ModelInspectionOverlay"
	add_child(overlays)


func inspect(view: VehicleView) -> void:
	if inspected == view:
		return
	inspected = view
	for child in overlays.get_children(): child.queue_free()
	if view == null:
		return
	var geometry := Sim.geometry_of(view.kind)
	var half := geometry.get("extents", Vector3.ONE) as Vector3
	_axis(Vector3.ZERO, Vector3.RIGHT * maxf(half.x, 2.0), Color.RED, "X starboard")
	_axis(Vector3.ZERO, Vector3.UP * maxf(half.y, 2.0), Color.GREEN, "Y up")
	_axis(Vector3.ZERO, Vector3.FORWARD * maxf(half.z, 2.0), Color.BLUE, "-Z forward")
	_wire_box(half, Color(1.0, 0.65, 0.08))
	for seat_index in range((geometry.get("seat_poses", []) as Array).size()):
		var pose := (geometry["seat_poses"] as Array)[seat_index] as Dictionary
		_marker("Seat%dEye" % seat_index, pose.get("position", Vector3.ZERO) + Vector3.UP * CockpitStation.EYE_HEIGHT,
			Color(0.15, 0.9, 1.0), "seat %d" % seat_index)
	var definition := ModelAssetDefinition.definition_for(view.kind)
	if not definition.has("error"):
		for socket_name in (definition.get("sockets", {}) as Dictionary):
			_marker("Socket_%s" % socket_name, ModelAssetDefinition._vector(definition.sockets[socket_name]),
				Color(1.0, 0.20, 0.75), String(socket_name))
		var dimensions := definition.get("dimensions_m", []) as Array
		if dimensions.size() == 3:
			_label("%.2f m span  |  %.2f m high  |  %.2f m long" % dimensions,
				Vector3(0, half.y + 2.2, 0), Color.WHITE)


func show_exterior(shown: bool) -> void:
	if inspected != null and inspected._visual_scene != null:
		var exterior := inspected._visual_scene.get_node_or_null("Exterior") as Node3D
		if exterior != null: exterior.visible = shown
	elif inspected != null and inspected._rotorcraft != null:
		inspected._rotorcraft.get("exterior").visible = shown


func show_interior(shown: bool) -> void:
	if inspected != null and inspected._visual_scene != null:
		var interior := inspected._visual_scene.get_node_or_null("Interior") as Node3D
		if interior != null: interior.visible = shown
	elif inspected != null and inspected._rotorcraft != null:
		inspected._rotorcraft.get("interior").visible = shown


func show_overlays(shown: bool) -> void:
	overlays.visible = shown


func _axis(from: Vector3, to: Vector3, colour: Color, words: String) -> void:
	_line(from, to, colour)
	_label(words, to, colour)


func _wire_box(half: Vector3, colour: Color) -> void:
	var corners: Array[Vector3] = []
	for x in [-half.x, half.x]:
		for y in [-half.y, half.y]:
			for z in [-half.z, half.z]: corners.append(Vector3(x, y, z))
	for a in range(corners.size()):
		for b in range(a + 1, corners.size()):
			var difference := corners[a] - corners[b]
			var changed := int(absf(difference.x) > 0.001) + int(absf(difference.y) > 0.001) + int(absf(difference.z) > 0.001)
			if changed == 1: _line(corners[a], corners[b], colour)


func _line(from: Vector3, to: Vector3, colour: Color) -> void:
	var mesh := ImmediateMesh.new(); mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_set_color(colour); mesh.surface_add_vertex(from)
	mesh.surface_set_color(colour); mesh.surface_add_vertex(to); mesh.surface_end()
	var node := MeshInstance3D.new(); node.mesh = mesh
	var material := StandardMaterial3D.new(); material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; node.material_override = material
	overlays.add_child(node)


func _marker(label: String, at: Vector3, colour: Color, words: String) -> void:
	var node := MeshInstance3D.new(); node.name = label; var mesh := SphereMesh.new()
	mesh.radius = 0.12; mesh.height = 0.24; node.mesh = mesh; node.position = at
	var material := StandardMaterial3D.new(); material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; node.material_override = material
	overlays.add_child(node); _label(words, at + Vector3.UP * 0.25, colour)


func _label(words: String, at: Vector3, colour: Color) -> void:
	var label := Label3D.new(); label.text = words; label.position = at; label.modulate = colour
	label.font_size = 40; label.pixel_size = 0.004; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	overlays.add_child(label)
