extends Node3D
## Windowed: EVERY PILOT SEAT PRESET IN A ROW, from the side (the recline is what reads) and three-quarters on, each
## with a pale ball for the head and a red dot where the rig puts the occupant's eye, so a reader sees the chair fitted
## to the player rather than in the abstract.
##
##   Godot --path cockpit res://tests/pilot_seat_shot.tscn --xr-mode off -- --out=<folder>
##
## NOT HEADLESS. `tests/pilot_seat.gd` holds the geometry; this is the picture it cannot take. Every frame is stamped with
## the commit, whether the tree was dirty and the time (`modelling_here.md` section 7, "a gallery goes stale").

const SPACING: float = 1.25

var out := ""
var failures: PackedStringArray = []
var _stamp := ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	_stamp = _commit_stamp()
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.80, 0.83, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.72, 0.76)
	env.ambient_light_energy = 0.8
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, 0.7, 0.0)
	light.light_energy = 1.3
	light.shadow_enabled = true
	add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.55, 0.56, 0.57)
	ground.material_override = grey
	add_child(ground)
	var names: Array = PilotSeat.PRESETS.keys()
	var stands: Array[Node3D] = []
	for name in names:
		var stand := Node3D.new()
		stand.name = "Stand_%s" % name
		add_child(stand)
		stand.add_child(PilotSeat.of(String(name)))
		_mark_the_occupant(stand)
		var label := Label3D.new()
		var p: Dictionary = PilotSeat.preset(String(name))
		label.text = "%s\n%.0f deg" % [name, float(p["recline"])]
		label.font_size = 64
		label.pixel_size = 0.0025
		label.modulate = Color(0.08, 0.08, 0.10)
		label.outline_size = 0
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0.0, 1.95, 0.0)
		stand.add_child(label)
		stands.append(stand)
	var camera := Camera3D.new()
	camera.current = true
	add_child(camera)
	var caption := Label.new()
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
	caption.position = Vector2(16, 12)
	var layer := CanvasLayer.new()
	layer.add_child(caption)
	add_child(layer)
	# THE SIDE: seats in a line fore and aft, seen square from starboard, orthographic, so the lean is an angle on the page.
	var row: float = SPACING * float(stands.size() - 1)
	for i in range(stands.size()):
		stands[i].position = Vector3(0.0, 0.0, -row * 0.5 + SPACING * 1.35 * float(i) - row * 0.18)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.6
	camera.position = Vector3(8.0, 0.95, 0.0)
	camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	caption.text = "PilotSeat presets from the side, facing left; the ball is the rig's eye (CockpitStation.EYE_HEIGHT %.2f m)   %s" % [
		CockpitStation.EYE_HEIGHT, _stamp]
	# The row is wider than a 2.6 m frame: take it in two halves.
	var half: int = (stands.size() + 1) / 2
	for page in range(2):
		var from: int = page * half
		var to: int = mini(from + half, stands.size())
		var middle: float = (stands[from].position.z + stands[to - 1].position.z) * 0.5
		camera.size = absf(stands[to - 1].position.z - stands[from].position.z) + 1.6
		camera.position = Vector3(8.0, 0.95, middle)
		camera.look_at(Vector3(0.0, 0.95, middle), Vector3.UP)
		await _save("cockpit-chairs-gallery-side-%d.png" % (page + 1))
	# THREE-QUARTERS ON: the same seats abreast, seen from ahead and to port, a little above.
	for i in range(stands.size()):
		# +X IS ON THE LEFT of a camera looking aft, so the first preset stands at +X to read first.
		stands[i].position = Vector3(row * 0.5 - SPACING * float(i), 0.0, 0.0)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 40.0
	camera.position = Vector3(2.6, 2.4, -6.4)
	camera.look_at(Vector3(0.0, 0.75, 0.0), Vector3.UP)
	caption.text = "PilotSeat presets three-quarters on, left to right: %s   %s" % [", ".join(PackedStringArray(names)), _stamp]
	await _save("cockpit-chairs-gallery-three-quarter.png")
	# AND CLOSE ON EACH, three-quarters from ahead: the handle, the harness, the headbox.
	for i in range(stands.size()):
		var at: Vector3 = stands[i].position
		camera.fov = 34.0
		camera.position = at + Vector3(1.5, 1.55, -2.3)
		camera.look_at(at + Vector3(0.0, 0.85, 0.0), Vector3.UP)
		caption.text = "%s   %s" % [names[i], _stamp]
		await _save("cockpit-chairs-close-%s.png" % names[i])
	print("[pilot_seat_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL " + ", ".join(failures), out])
	get_tree().quit(0 if failures.is_empty() else 1)


## A PALE BALL FOR THE HEAD AND A RED DOT AT THE EYE, where the rig puts the occupant.
func _mark_the_occupant(stand: Node3D) -> void:
	var skin := StandardMaterial3D.new()
	# OPAQUE: a see-through material must be misted or exempted (`lint`), and a head needs neither.
	skin.albedo_color = Color(0.95, 0.80, 0.62)
	var head := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.10
	ball.height = 0.22
	head.mesh = ball
	head.material_override = skin
	head.position = Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.08)
	stand.add_child(head)
	var eye := MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.025
	dot.height = 0.05
	eye.mesh = dot
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.12, 0.10)
	eye.material_override = red
	eye.position = Vector3(0.0, CockpitStation.EYE_HEIGHT, -0.02)
	stand.add_child(eye)


func _commit_stamp() -> String:
	var head: Array = []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "--short", "HEAD"], head)
	var status: Array = []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "status", "--porcelain"], status)
	var dirty: bool = not String(status[0] if not status.is_empty() else "").strip_edges().is_empty()
	return "%s%s, %s" % [String(head[0] if not head.is_empty() else "?").strip_edges(), "+dirty" if dirty else "",
		Time.get_datetime_string_from_system(false, true)]


func _save(filename: String) -> void:
	for frame in range(4):
		await RenderingServer.frame_post_draw
	var path := out.path_join(filename)
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(filename)
	print("[pilot_seat_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
