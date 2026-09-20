extends Node3D
## Windowed: THE PILOT'S CHAIRS IN THEIR CRAFT, as the game builds them (`VehicleView`, every seat manned): a cutaway
## from the side through each cockpit, a three-quarter from outside through the glass, and a look down from the pilot's
## own eye at the pan and the handle between the knees.
##
##   Godot --path cockpit res://tests/chair_craft_shot.tscn --xr-mode off -- --out=<folder> [--kind=falcon]
##
## NOT HEADLESS. `tests/pilot_seat.gd` holds the chairs under the skin and out of every sight line; this is the picture.
##
## THE CUTAWAY IS THE CAMERA'S NEAR PLANE, not an edited model: an orthographic camera to starboard with its near plane
## `CUT` outboard of the outermost chaired seat slices off the near side of the fuselage and the canopy, and shows the
## chair and the head in their true section. A ball stands at every seat's eye (`CockpitStation.EYE_HEIGHT` over its
## anchor, where the rig puts a real head), so the gap between a head and its headbox is read in the aeroplane.

const KINDS: Array[String] = ["falcon", "tomcat", "fighter", "uh60", "chinook", "heli", "littlebird", "apache"]
## HOW FAR OUTBOARD OF THE OUTERMOST CHAIRED SEAT THE CUT IS, in metres: past a chair's half-width (0.25 for the
## armoured seat), inside any cockpit's side. On a tandem jet the seats are on the centreline and the cut is 0.28 m out;
## side by side it passes just outboard of the starboard pilot, who hides the port one.
const CUT: float = 0.28

var out := ""
var only := ""
var failures: PackedStringArray = []
var _stamp := ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
		if argument.begins_with("--kind="):
			only = argument.trim_prefix("--kind=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	CockpitStation.use_saved_layouts = false
	_stamp = _commit_stamp()
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.72, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.74, 0.78)
	env.ambient_light_energy = 0.9
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, 0.9, 0.0)
	light.light_energy = 1.2
	add_child(light)
	var camera := Camera3D.new()
	camera.current = true
	add_child(camera)
	var caption := Label.new()
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
	caption.position = Vector2(16, 12)
	var layer := CanvasLayer.new()
	layer.add_child(caption)
	add_child(layer)
	for kind in KINDS:
		if not only.is_empty() and kind != only:
			continue
		var view := (load("res://objects/vehicles/craft_%s.tscn" % kind) as PackedScene).instantiate() as VehicleView
		add_child(view)
		view._show_in_editor()
		var eyes: Array[Vector3] = []
		var outboard: float = 0.0
		var chairs: PackedStringArray = []
		for seat in range(view.seats.size()):
			var anchor: Node3D = view.seats[seat]
			var chair := anchor.get_node_or_null("Chair") as MeshInstance3D
			if chair == null:
				continue
			chairs.append("seat %d %s" % [seat, chair.get_meta("preset", "")])
			_head(anchor)
			eyes.append(anchor.global_transform * Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0))
			outboard = maxf(outboard, anchor.position.x)
		if eyes.is_empty():
			failures.append("%s has no chair" % kind)
			view.queue_free()
			continue
		for i in range(8):
			await get_tree().process_frame
		var middle := Vector3.ZERO
		for eye in eyes:
			middle += eye
		middle /= float(eyes.size())
		# THE CUTAWAY, square from starboard, the near plane at CUT.
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		var span: float = absf(eyes[0].z - eyes[eyes.size() - 1].z)
		camera.size = maxf(2.6, span + 2.4)
		camera.position = Vector3(6.0, middle.y - 0.45, middle.z)
		camera.look_at(Vector3(0.0, middle.y - 0.45, middle.z), Vector3.UP)
		camera.near = 6.0 - outboard - CUT
		camera.far = 30.0
		caption.text = "%s cut away %.2f m outboard of the centreline, from starboard: %s; balls at the rig's eyes   %s" % [
			kind, outboard + CUT, ", ".join(chairs), _stamp]
		await _save("cockpit-chairs-craft-%s-cutaway.png" % kind)
		# THROUGH THE GLASS, three-quarters from ahead and above, as anybody walking up to it sees.
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.near = 0.05
		camera.fov = 34.0
		camera.position = middle + Vector3(3.2, 2.2, -3.6)
		camera.look_at(middle - Vector3(0.0, 0.35, 0.0), Vector3.UP)
		caption.text = "%s from outside, through the canopy   %s" % [kind, _stamp]
		await _save("cockpit-chairs-craft-%s-outside.png" % kind)
		# FROM THE PILOT'S EYE, looking down at the pan and the handle between the knees, past the pedals.
		var pilot: Node3D = view.seats[0]
		camera.fov = 80.0
		camera.global_position = eyes[0] + pilot.global_transform.basis * Vector3(0.0, 0.0, 0.05)
		camera.look_at(pilot.global_transform * Vector3(0.0, 0.30, -0.45), Vector3.UP)
		caption.text = "%s seat 0, from the pilot's eye, looking down between the knees   %s" % [kind, _stamp]
		await _save("cockpit-chairs-craft-%s-eye-down.png" % kind)
		remove_child(view)
		view.free()
	print("[chair_craft_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL " + ", ".join(failures), out])
	get_tree().quit(0 if failures.is_empty() else 1)


## A HEAD WHERE THE RIG PUTS ONE: a ball behind the eye, a red dot at it.
func _head(anchor: Node3D) -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.95, 0.80, 0.62)
	var head := MeshInstance3D.new()
	head.name = "HeadMarker"
	var ball := SphereMesh.new()
	ball.radius = 0.10
	ball.height = 0.22
	ball.radial_segments = 12
	ball.rings = 6
	head.mesh = ball
	head.material_override = skin
	head.position = Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.08)
	anchor.add_child(head)
	var eye := MeshInstance3D.new()
	eye.name = "EyeMarker"
	var dot := SphereMesh.new()
	dot.radius = 0.025
	dot.height = 0.05
	eye.mesh = dot
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.12, 0.10)
	eye.material_override = red
	eye.position = Vector3(0.0, CockpitStation.EYE_HEIGHT, -0.02)
	anchor.add_child(eye)


func _commit_stamp() -> String:
	var head: Array = []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "--short", "HEAD"], head)
	var status: Array = []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "status", "--porcelain"], status)
	var dirty: bool = not String(status[0] if not status.is_empty() else "").strip_edges().is_empty()
	return "%s%s, %s" % [String(head[0] if not head.is_empty() else "?").strip_edges(), "+dirty" if dirty else "",
		Time.get_datetime_string_from_system(false, true)]


func _save(filename: String) -> void:
	for frame in range(5):
		await RenderingServer.frame_post_draw
	var path := out.path_join(filename)
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(filename)
	print("[chair_craft_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
