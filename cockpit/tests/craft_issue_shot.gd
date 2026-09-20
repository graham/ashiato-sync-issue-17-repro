extends Node3D
## Visual review of two freshly issued aeroplanes at the spacing FlightLevel registers.
## The authoritative lifecycle is proved separately by issue.gd and craft_peers.gd; this
## probe keeps the placement readable to a person and leaves a durable PNG.
##
## Godot --xr-mode off --desktop-only --path cockpit --resolution 1280x720 \
##   res://tests/craft_issue_shot.tscn -- --out=C:/path/cockpit-issued-planes.png

const VIEW := preload("res://objects/vehicles/vehicle_view.tscn")

var failures: PackedStringArray = []
var out: String = ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out == "":
		var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
		out = repo.path_join("screenshots").path_join(Time.get_date_string_from_system()).path_join(
			"cockpit-issued-planes.png")
	if DisplayServer.get_name() == "headless":
		failures.append("a_rendering_device_is_available")
		_finish()
		return
	_build_apron()
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.PLANE)
	var extents: Vector3 = geometry.get("extents", Vector3.ONE)
	# The native clear check and FlightLevel both use the larger of the drawn half-span
	# and hull extents. Reading extents alone would put 13 m wings only 5.5 m apart.
	var half_span: float = maxf(float(geometry.get("span", 0.0)), maxf(extents.x, extents.z))
	var spacing: float = half_span * 2.0 + 4.0
	_add_plane(-spacing * 0.5, geometry)
	_add_plane(spacing * 0.5, geometry)
	_add_camera(spacing, geometry)
	_add_words(spacing)
	for _frame in range(40):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var saved := get_viewport().get_texture().get_image().save_png(out) == OK
	if not saved: failures.append("the_picture_is_saved")
	print("[craft_issue_shot] %s two planes %.1f m apart at %s" % [
		"PASS" if saved else "FAIL", spacing, out])
	_finish()


func _build_apron() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("8cb7d2")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d7e3e8")
	settings.ambient_light_energy = 0.75
	environment.environment = settings
	add_child(environment)
	var floor := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(90.0, 0.2, 70.0)
	floor.mesh = slab
	floor.position.y = -0.1
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color("65716f")
	concrete.roughness = 0.92
	floor.material_override = concrete
	add_child(floor)
	for x in [-30.0, 0.0, 30.0]:
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.22, 0.025, 54.0)
		stripe.mesh = stripe_mesh
		stripe.position = Vector3(x, 0.02, 0.0)
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color("e6c84d")
		stripe.material_override = paint
		add_child(stripe)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)


func _add_plane(x: float, geometry: Dictionary) -> void:
	var view := VIEW.instantiate() as VehicleView
	add_child(view)
	view.setup(0, Sim.Kind.PLANE)
	view.position = Vector3(x, float((geometry.get("extents", Vector3.ONE) as Vector3).y), 0.0)
	view.set_process(false)


func _add_camera(spacing: float, geometry: Dictionary) -> void:
	var extents: Vector3 = geometry.get("extents", Vector3.ONE)
	var camera := Camera3D.new()
	camera.fov = 48.0
	camera.position = Vector3(spacing * 1.15, maxf(17.0, extents.y * 8.0), 34.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, extents.y, 0.0))
	add_child(camera)
	camera.current = true


func _add_words(spacing: float) -> void:
	var words := Label.new()
	words.position = Vector2(34.0, 28.0)
	words.text = "AUTHORITATIVE CRAFT ISSUE\nTWO CLEAR PLACES  ·  %.1f m CENTRE TO CENTRE" % spacing
	words.add_theme_font_size_override("font_size", 24)
	words.add_theme_color_override("font_color", Color.WHITE)
	words.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	words.add_theme_constant_override("shadow_offset_x", 2)
	words.add_theme_constant_override("shadow_offset_y", 2)
	add_child(words)


func _finish() -> void:
	print("[craft_issue_shot] RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL " + ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
