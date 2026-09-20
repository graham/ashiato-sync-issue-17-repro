extends Node3D
## Windowed: THE MH-6M FROM EVERY SEAT, AS THE GAME BUILDS IT -- a `VehicleView` of kind 28 with its stations, not the
## airframe alone that `littlebird_shot` photographs. The open cockpit is the point, so each pilot is photographed
## looking ahead and out of his own door, and the craft from outside with its stations in it -- twice under the pilot's
## door, where the standard footwell stood out of the belly (`--tag=before` / `--tag=after` name the pair).
##
##   Godot --path cockpit res://tests/littlebird_seat_shot.tscn -- --out=<folder>
##
## TWO SEATS SINCE 2026-09-18: the bench riders' stations hung their screens in the air outboard of the aircraft (the
## first set of these pictures), and the kind has the pilot and the copilot only.
##
## NOT HEADLESS. Each seat picture is taken from the seat's own eye, `CockpitStation.EYE_HEIGHT` over the seat marker the
## view places, at a headset's 100 degrees, over a plain ground with a painted line every two metres ahead so "down" can
## be judged. Every picture carries `<commit>[+dirty], <date> <time>`.

const LOOKS: Array = [
	[0, "pilot-ahead", 0.0, -8.0],
	[0, "pilot-out-of-his-door", 75.0, -30.0],
	[1, "copilot-ahead", 0.0, -8.0],
	[1, "copilot-out-of-his-door", 75.0, -30.0],
]

var out := ""
var stamp := ""
var failures: PackedStringArray = []
var _label: Label
## `--tag=before` or `--tag=after`, carried in the under-the-door picture's name.
var _tag := "now"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
		elif argument.begins_with("--tag="):
			_tag = argument.trim_prefix("--tag=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	stamp = _stamp()
	CockpitStation.use_saved_layouts = false
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.72, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.74, 0.80)
	env.ambient_light_energy = 0.8
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, -0.6, 0.0)
	light.light_energy = 1.35
	light.shadow_enabled = true
	add_child(light)
	var view := (load("res://objects/vehicles/craft_littlebird.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var half: Vector3 = Sim.geometry_of(Sim.Kind.LITTLEBIRD)["extents"]
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	ground.mesh = plane
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.42, 0.47, 0.36)
	ground.material_override = grass
	ground.position.y = -half.y
	add_child(ground)
	for i in range(1, 8):
		for side in [0.0, -1.0, 1.0]:
			var mark := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(2.0, 0.01, 0.12) if side == 0.0 else Vector3(0.12, 0.01, 1.0)
			mark.mesh = box
			var paint := StandardMaterial3D.new()
			paint.albedo_color = Color(0.92, 0.92, 0.88)
			mark.material_override = paint
			mark.position = Vector3(0.0, -half.y + 0.005, -3.7 - 2.0 * i) if side == 0.0 \
				else Vector3(side * (1.0 + 2.0 * i), -half.y + 0.005, -1.7)
			add_child(mark)
	_label = Label.new()
	_label.position = Vector2(12, 1000 - 30)
	_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	_label.add_theme_font_size_override("font_size", 16)
	add_child(_label)
	get_viewport().size = Vector2i(1600, 1000)
	var camera := Camera3D.new()
	camera.current = true
	camera.near = 0.03
	add_child(camera)
	print("[littlebird_seat_shot] %d seats in the view" % view.seats.size())
	if view.seats.size() != 2:
		failures.append("seats")
	camera.fov = 45.0
	camera.global_position = view.to_global(Vector3(4.2, 1.6, -5.0))
	camera.look_at(view.to_global(Vector3(0.0, 0.4, -2.0)), Vector3.UP)
	await _save(camera, "cockpit-littlebird-20-craft-with-its-stations-starboard-front-quarter.png")
	# UNDER THE STARBOARD DOOR, low, where a station's footwell stood out of the belly before the Little Bird named its own.
	camera.fov = 50.0
	camera.global_position = view.to_global(Vector3(2.6, -0.75, -2.3))
	camera.look_at(view.to_global(Vector3(0.3, -0.45, -2.55)), Vector3.UP)
	await _save(camera, "cockpit-littlebird-27-under-the-starboard-door-%s.png" % _tag)
	# AND CLOSE, FROM BELOW THE DOOR, at the pilot's footwell itself: the standard 0.60 m plate stood 0.30 m out of the belly
	# here, and a picture from further off shows the belly's own dark band instead of it.
	camera.fov = 55.0
	camera.global_position = view.to_global(Vector3(1.35, -1.05, -2.2))
	camera.look_at(view.to_global(Vector3(0.40, -0.62, -2.62)), Vector3.UP)
	await _save(camera, "cockpit-littlebird-28-the-pilots-footwell-from-below-the-door-%s.png" % _tag)
	for look in LOOKS:
		var seat: int = int(look[0])
		if seat >= view.seats.size():
			continue
		var marker: Node3D = view.seats[seat]
		var eye: Vector3 = marker.global_transform * Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
		# THE SEAT'S OWN AHEAD, turned `az` degrees towards the seat's outboard side.
		var outboard: float = signf((view.global_transform.affine_inverse() * eye).x)
		var a: float = deg_to_rad(float(look[2]))
		var e: float = deg_to_rad(float(look[3]))
		var local := Vector3(outboard * sin(a) * cos(e), sin(e), -cos(a) * cos(e))
		var direction: Vector3 = (marker.global_transform.basis * local).normalized()
		camera.fov = 100.0
		camera.global_position = eye
		camera.look_at(eye + direction, Vector3.UP)
		await _save(camera, "cockpit-littlebird-%02d-seat%d-%s.png" % [21 + LOOKS.find(look), seat, look[1]])
	print("[littlebird_seat_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL " + ", ".join(failures), out])
	get_tree().quit(0 if failures.is_empty() else 1)


func _stamp() -> String:
	var root: String = ProjectSettings.globalize_path("res://")
	var said: Array = []
	OS.execute("git", ["-C", root, "rev-parse", "--short", "HEAD"], said)
	var status: Array = []
	OS.execute("git", ["-C", root, "status", "--porcelain"], status)
	var dirty: bool = not status.is_empty() and not String(status[0]).strip_edges().is_empty()
	return "%s%s, %s" % [String(said[0]).strip_edges() if not said.is_empty() else "?", "+dirty" if dirty else "",
		Time.get_datetime_string_from_system(false, true)]


func _save(camera: Camera3D, filename: String) -> void:
	_label.text = "MH-6M kind 28 as the game builds it   %s   %s" % [filename.get_basename().get_slice("littlebird-", 1), stamp]
	for frame in range(4):
		await RenderingServer.frame_post_draw
	if get_viewport().get_camera_3d() != camera:
		failures.append("%s drawn through another camera" % filename)
	var path := out.path_join(filename)
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(filename)
	print("[littlebird_seat_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
