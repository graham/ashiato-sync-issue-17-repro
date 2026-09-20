extends Node
## A rendered, repeatable visual audit of BOTH Device Yard rooms at the supported load presets.
##
##   cockpit\device_yard_gallery.bat
##   cockpit\device_yard_gallery.bat --density=500 --out=C:/godotgames-drafts/yard
##
## This is deliberately a visual probe, not a network test.  It constructs the same `DeviceYard`
## node that `FlightLevel` adds, at 100, 250 and 500 endpoints per room, then saves one interior
## image from each real room.  A Segway has no rendered hull by design, so the small yellow object
## in each image is labelled "SEAT ORIGIN" rather than pretending to be a vehicle.  The actual
## session/Segway path is covered by `tests/device_yard_level.tscn`; the authoritative request path
## is covered by `tests/room_transport.tscn`.
##
## Rendering is required.  Headless runs have no image to prove anything and fail plainly.

var DEFAULT_DENSITIES := PackedInt32Array([100, 250, 500])
const SETTLE_FRAMES := 12

var _out := ""
var _densities := PackedInt32Array()
var _saved: Array[String] = []
var _failed: Array[String] = []
var _eye: Camera3D
var _caption: Label


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		_finish("rendering is required; run the gallery windowed")
		return
	_parse_arguments()
	if not _failed.is_empty():
		_finish("invalid arguments")
		return
	if DirAccess.make_dir_recursive_absolute(_out) != OK:
		_finish("could not create %s" % _out)
		return
	_light_the_probe()
	for density in _densities:
		await _photograph_density(density)
	_finish("")


func _parse_arguments() -> void:
	_densities = DEFAULT_DENSITIES.duplicate()
	for argument in OS.get_cmdline_user_args():
		var text := String(argument)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
		elif text.begins_with("--density="):
			var density_text := text.trim_prefix("--density=")
			if not density_text.is_valid_int():
				_failed.append("density is not an integer: %s" % density_text)
				continue
			var density := int(density_text)
			if not DeviceYard.PRESETS.has(density):
				_failed.append("density must be one of %s, got %d" % [DeviceYard.PRESETS, density])
				continue
			_densities = PackedInt32Array([density])
	if _out == "":
		var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
		_out = repo.path_join("screenshots").path_join(Time.get_date_string_from_system())


func _light_the_probe() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.055, 0.085)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.56, 0.70)
	environment.ambient_light_energy = 0.75
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -24.0, 0.0)
	sun.light_energy = 0.9
	add_child(sun)
	_eye = Camera3D.new()
	_eye.fov = 92.0
	_eye.near = 0.05
	_eye.far = 100.0
	add_child(_eye)
	var overlay := CanvasLayer.new()
	overlay.layer = 8
	add_child(overlay)
	_caption = Label.new()
	_caption.position = Vector2(32.0, 26.0)
	_caption.add_theme_font_size_override("font_size", 26)
	_caption.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))
	_caption.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_caption.add_theme_constant_override("shadow_offset_x", 2)
	_caption.add_theme_constant_override("shadow_offset_y", 2)
	overlay.add_child(_caption)


func _photograph_density(density: int) -> void:
	var stage := Node3D.new()
	stage.name = "DeviceYardGallery_%d" % density
	add_child(stage)
	var chart := LevelChart.new()
	chart._take({"name": "Device Yard %d visual probe" % density, "summary": "Rendered fixture only.",
		"world": "room", "arrive": "segway", "yard_devices": density,
		"spawn": {"at": [-16.0, 0.5, 0.0], "yaw_degrees": 0.0, "apart": 1.8}})
	var yard := DeviceYard.new()
	yard.name = "DeviceYard"
	stage.add_child(yard)
	yard.stand_in(chart)
	for room_id in DeviceYard.ROOMS:
		_add_seat_origin(stage, room_id)
		_add_reference_blocks(stage, room_id)
	for room_id in DeviceYard.ROOMS:
		var centre := DeviceYard.room_centre(room_id)
		# The camera remains inside the authored walls and beneath the ceiling, as a standing player
		# would.  It looks across the real endpoint instances rather than through a cut-away shell.
		_eye.global_position = centre + Vector3(0.0, 2.45, 9.4)
		_eye.look_at(centre + Vector3(0.0, 0.60, -1.8), Vector3.UP)
		_caption.text = "DEVICE YARD  /  ROOM %s  /  %d ENDPOINTS\nInterior density audit — yellow marker is the Segway seat origin" % [
			String(room_id).to_upper(), density]
		await _save_window(_out.path_join("cockpit-device-yard-%03d-%s.png" % [density, room_id]))
	stage.queue_free()
	await get_tree().process_frame


## A visual-only locator for the actual Segway seat origin.  `VehicleCatalogue` intentionally
## draws no Segway hull, so a labelled marker is more honest and more useful than a made-up model.
func _add_seat_origin(stage: Node3D, room_id: StringName) -> void:
	var origin := DeviceYard.room_centre(room_id) + Vector3(-11.4, 0.10, 8.5)
	var marker := MeshInstance3D.new()
	marker.name = "SeatOrigin_%s" % room_id
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.62
	mesh.height = 0.16
	marker.mesh = mesh
	marker.position = origin
	marker.material_override = _material(Color(0.96, 0.78, 0.20))
	stage.add_child(marker)
	var label := Label3D.new()
	label.name = "SeatOriginLabel_%s" % room_id
	label.text = "SEGWAY\nSEAT ORIGIN"
	label.font_size = 48
	label.pixel_size = 0.004
	label.modulate = Color(1.0, 0.86, 0.35)
	label.position = origin + Vector3(0.0, 0.42, 0.0)
	stage.add_child(label)


## Three fixed-size landmarks establish scale without changing the yard or its endpoint layout.
func _add_reference_blocks(stage: Node3D, room_id: StringName) -> void:
	var centre := DeviceYard.room_centre(room_id)
	_add_block(stage, "ScalePillar_%s" % room_id, centre + Vector3(11.9, 1.25, 8.6), Vector3(0.60, 2.5, 0.60),
		Color(0.30, 0.90, 0.72))
	_add_block(stage, "ForwardReference_%s" % room_id, centre + Vector3(0.0, 0.50, -10.4), Vector3(1.40, 1.0, 0.80),
		Color(0.35, 0.60, 1.0))
	_add_block(stage, "SideReference_%s" % room_id, centre + Vector3(-12.6, 0.35, -5.4), Vector3(0.75, 0.70, 0.75),
		Color(0.95, 0.38, 0.28))


func _add_block(stage: Node3D, named: String, at: Vector3, size: Vector3, colour: Color) -> void:
	var block := MeshInstance3D.new()
	block.name = named
	var mesh := BoxMesh.new()
	mesh.size = size
	block.mesh = mesh
	block.position = at
	block.material_override = _material(colour)
	stage.add_child(block)


func _material(colour: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = colour
	paint.roughness = 0.62
	return paint


func _save_window(path: String) -> void:
	for frame in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var error := picture.save_png(path)
	print("[device_yard_gallery] %d x %d, %s, %s" % [picture.get_width(), picture.get_height(), error_string(error), path])
	if error == OK:
		_saved.append(path)
	else:
		_failed.append("%s: %s" % [path.get_file(), error_string(error)])


func _finish(reason: String) -> void:
	if reason != "":
		_failed.append(reason)
	var expected := _densities.size() * DeviceYard.ROOMS.size()
	var ok := _failed.is_empty() and _saved.size() == expected
	print("[device_yard_gallery] RESULT=%s %d of %d saved into %s%s" % ["PASS" if ok else "FAIL", _saved.size(),
		expected, _out, " (%s)" % "; ".join(_failed) if not _failed.is_empty() else ""])
	get_tree().quit(0 if ok else 1)
