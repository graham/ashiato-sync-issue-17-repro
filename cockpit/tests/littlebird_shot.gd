extends Node3D
## Windowed visual evidence for the MH-6M Little Bird airframe, and the pictures a reader can DISPUTE.
##
##   tools\gate_run.ps1 -Probe littlebird_shot
##   tools\gate_run.ps1 -Probe littlebird_shot -Extra "--out=<folder>","--drawing=<mh6_fox52.svg>"
##
## NOT HEADLESS -- headless has no rendering device. `tests/littlebird.gd` holds everything that can be asserted,
## including what each pilot can see; this renders what a suite cannot: does it READ as a Little Bird, and does the
## cockpit LOOK as open as the rays say.
##
## FOUR LIT VIEWS of the outside (front quarter, the starboard side with both doors off, the port rear quarter with the
## tail rotor, and high over the nose looking down into the cabin); THREE FROM THE CREW'S EYES (the pilot's and the
## copilot's forward views at a headset's 100 degrees, and the pilot looking out and down through the open door); ONE
## LOOKING IN at the door with both eyes marked, to show how close the two sit; and THREE ORTHOGRAPHIC OVERLAYS on [FOX]
## itself -- the drawing rasterised by the engine (`Image.load_svg_from_string`, the falcon lane's finding) at 6 px a
## drawing unit, and the model's silhouette laid on it at the same scale, aligned on the datums the airframe is built
## from. Nothing is fitted to make the overlay agree: where they disagree, that is the finding, and the pod is meant to
## read narrower than the drawing in plan and front (the published width, `LittleBirdAirframe`'s doc block).
##
## Every picture carries `<commit>[+dirty], <date> <time>` (`modelling_here.md` section 7: a gallery goes stale and
## nothing in it says so). A SubViewport with its OWN World3D for each (`lane/prowler`); ambient COLOUR set, since
## AMBIENT_SOURCE_COLOR reads `ambient_light_color`, which defaults to black.

const RASTER: float = 6.0
const SILHOUETTE := Color(0.86, 0.10, 0.52)
const MARKER := Color(1.0, 0.62, 0.1)

var out := ""
var drawing := ""
var stamp := ""
var failures: PackedStringArray = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
		elif argument.begins_with("--drawing="):
			drawing = argument.trim_prefix("--drawing=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	if drawing.is_empty():
		drawing = OS.get_environment("USERPROFILE").path_join("godotgames-drafts/2026-09-17/cockpit-littlebird/research/mh6_fox52.svg")
	DirAccess.make_dir_recursive_absolute(out)
	stamp = _stamp()

	await _lit("cockpit-littlebird-01-front-quarter.png", Vector3(-7.5, 3.2, -8.5), Vector3(0.0, 0.2, -1.4), 40.0)
	await _lit("cockpit-littlebird-02-starboard-side-doors-off.png", Vector3(11.0, 0.9, -0.6), Vector3(0.0, 0.3, -0.6), 44.0)
	await _lit("cockpit-littlebird-03-port-rear-quarter-tail-rotor.png", Vector3(-7.5, 2.6, 8.5), Vector3(0.0, 0.4, 0.6), 42.0)
	await _lit("cockpit-littlebird-04-over-the-nose-into-the-cabin.png", Vector3(1.5, 5.2, -6.5), Vector3(0.0, 0.0, -2.3), 40.0)
	var frame := LittleBirdAirframe.new()
	frame.dress()
	var eyes: Array[Vector3] = frame.crew_eyes()
	frame.free()
	await _eye("cockpit-littlebird-05-pilot-eye-forward.png", eyes[0], 0.0, -8.0, 1.0)
	await _eye("cockpit-littlebird-06-copilot-eye-forward.png", eyes[1], 0.0, -8.0, -1.0)
	await _eye("cockpit-littlebird-07-pilot-eye-out-and-down-through-the-door.png", eyes[0], 70.0, -35.0, 1.0)
	await _lit("cockpit-littlebird-08-into-the-open-door-both-eyes-marked.png", Vector3(3.1, 1.0, -4.5),
		Vector3(0.0, 0.55, -2.4), 48.0, eyes)
	await _overlay("cockpit-littlebird-09-side-over-fox-drawing-x1.000.png", "side")
	await _overlay("cockpit-littlebird-10-front-over-fox-drawing-x1.000.png", "front")
	await _overlay("cockpit-littlebird-11-top-over-fox-drawing-x1.000.png", "top")

	print("[littlebird_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL " + ", ".join(failures), out])
	get_tree().quit(0 if failures.is_empty() else 1)


## `<short commit>[+dirty], <date> <time>`, read from git, so a picture says what it is a picture of.
func _stamp() -> String:
	var root: String = ProjectSettings.globalize_path("res://")
	var said: Array = []
	OS.execute("git", ["-C", root, "rev-parse", "--short", "HEAD"], said)
	var status: Array = []
	OS.execute("git", ["-C", root, "status", "--porcelain"], status)
	var dirty: bool = not status.is_empty() and not String(status[0]).strip_edges().is_empty()
	var head: String = String(said[0]).strip_edges() if not said.is_empty() else "?"
	return "%s%s, %s" % [head, "+dirty" if dirty else "", Time.get_datetime_string_from_system(false, true)]


func _stage(size: Vector2i, background: Color, ambient: Color, energy: float, caption: String) -> SubViewport:
	var stage := SubViewport.new()
	stage.size = size
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.own_world_3d = true
	stage.msaa_3d = Viewport.MSAA_4X
	add_child(stage)
	# THE BUILD STAMP IN THE LOWER RIGHT, as in every picture the game takes (`BuildStamp`, 2026-09-18): this stage is a
	# viewport of its own, which the root's stamp is not drawn into.
	BuildStamp.attach_to(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = energy
	environment.environment = env
	stage.add_child(environment)
	if not caption.is_empty():
		var label := Label.new()
		label.text = "MH-6M LittleBirdAirframe   %s   %s" % [caption, stamp]
		label.position = Vector2(12, size.y - 30)
		label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
		label.add_theme_font_size_override("font_size", 16)
		stage.add_child(label)
	return stage


## The helicopter on a plain ground in daylight, with a sun that casts shadows.
func _scene(stage: SubViewport) -> LittleBirdAirframe:
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, -0.6, 0.0)
	light.light_energy = 1.35
	light.shadow_enabled = true
	stage.add_child(light)
	var frame := LittleBirdAirframe.new()
	frame.dress()
	stage.add_child(frame)
	# PARKED, a quarter-radian round, so no blade hides the boom in the side view.
	frame.set_rotors(true, 0.0, 0.25 / (TAU * RotorcraftKit.MAIN_TURNS))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	ground.mesh = plane
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.42, 0.47, 0.36)
	ground.material_override = grass
	ground.position.y = -(Sim.geometry_of(Sim.Kind.LITTLEBIRD)["extents"] as Vector3).y
	stage.add_child(ground)
	# Marks on the ground every two metres ahead, so a picture from the eye has something to judge "down" against.
	for i in range(1, 8):
		var mark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(3.0, 0.01, 0.12)
		mark.mesh = box
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color(0.92, 0.92, 0.88)
		mark.material_override = paint
		mark.position = Vector3(0.0, ground.position.y + 0.005, -3.7 - 2.0 * i)
		stage.add_child(mark)
	return frame


## A LIT VIEW from `from` at `target`; `marks` puts an amber ball at each point given (the crew's eyes).
func _lit(filename: String, from: Vector3, target: Vector3, fov: float, marks: Array = []) -> void:
	var stage := _stage(Vector2i(1600, 900), Color(0.62, 0.72, 0.82), Color(0.70, 0.74, 0.80), 0.8,
		filename.get_basename().get_slice("littlebird-", 1))
	_scene(stage)
	for m in marks:
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.09
		sphere.height = 0.18
		ball.mesh = sphere
		var paint := StandardMaterial3D.new()
		paint.albedo_color = MARKER
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ball.material_override = paint
		ball.position = m
		stage.add_child(ball)
	var camera := Camera3D.new()
	camera.fov = fov
	camera.current = true
	stage.add_child(camera)
	camera.global_position = from
	camera.look_at(target, Vector3.UP)
	await _save(stage, filename)


## THE VIEW FROM AN EYE: `az` degrees outboard (toward `outboard`'s side), `el` above level, at a headset's field.
func _eye(filename: String, eye: Vector3, az: float, el: float, outboard: float) -> void:
	var stage := _stage(Vector2i(1600, 1000), Color(0.62, 0.72, 0.82), Color(0.70, 0.74, 0.80), 0.8,
		filename.get_basename().get_slice("littlebird-", 1))
	_scene(stage)
	var camera := Camera3D.new()
	camera.fov = 100.0
	camera.near = 0.03
	camera.current = true
	stage.add_child(camera)
	camera.global_position = eye
	var a: float = deg_to_rad(az)
	var e: float = deg_to_rad(el)
	camera.look_at(eye + Vector3(outboard * sin(a) * cos(e), sin(e), -cos(a) * cos(e)), Vector3.UP)
	await _save(stage, filename)


## THE MODEL'S SILHOUETTE ON THE DRAWING, at the drawing's own 6 px a unit, aligned on the airframe's datums.
func _overlay(filename: String, view: String) -> void:
	var text: String = FileAccess.get_file_as_string(drawing)
	if text.is_empty():
		print("[littlebird_shot] SKIPPED %s: no drawing at %s (see craft/littlebird/sources.md)" % [filename, drawing])
		return
	var paper := Image.new()
	if paper.load_svg_from_string(text, RASTER) != OK:
		failures.append(filename)
		return
	var half: Vector3 = Sim.geometry_of(Sim.Kind.LITTLEBIRD)["extents"]
	var unit: float = LittleBirdAirframe.UNIT
	var size := Vector2i(1900, 900) if view != "front" else Vector2i(1700, 800)
	if view == "top":
		size = Vector2i(1500, 1700)
	# The model's origin, in drawing units, in each view: where the datums put it.
	var origin := Vector2.ZERO
	var from := Vector3.ZERO
	var up := Vector3.UP
	match view:
		"side":
			origin = Vector2(LittleBirdAirframe.NOSE_X + half.z / unit, LittleBirdAirframe.GROUND_Y - half.y / unit)
			from = Vector3(-40.0, 0.0, 0.0)
		"front":
			origin = Vector2(389.929, 154.42 - half.y / unit)
			from = Vector3(0.0, 0.0, -40.0)
		"top":
			origin = Vector2(125.073, LittleBirdAirframe.PLAN_NOSE_Y + half.z / unit)
			from = Vector3(0.0, 40.0, 0.0)
			up = Vector3.FORWARD
	var stage := _stage(size, Color.WHITE, Color.WHITE, 1.0, "")
	var frame := LittleBirdAirframe.new()
	frame.dress()
	stage.add_child(frame)
	frame.set_rotors(false, 0.0, 0.0)
	var flat := StandardMaterial3D.new()
	flat.albedo_color = SILHOUETTE
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for node in frame.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = flat
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = float(size.x) * unit / RASTER
	camera.near = 0.05
	camera.far = 200.0
	camera.current = true
	stage.add_child(camera)
	camera.global_position = from
	camera.look_at(Vector3.ZERO, up)
	for i in range(4):
		await RenderingServer.frame_post_draw
	var shot: Image = stage.get_texture().get_image()
	shot.convert(Image.FORMAT_RGBA8)
	paper.convert(Image.FORMAT_RGBA8)
	var corner := Vector2i(roundi(origin.x * RASTER - size.x * 0.5), roundi(origin.y * RASTER - size.y * 0.5))
	var sheet := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	sheet.blit_rect(paper, Rect2i(corner, size), Vector2i.ZERO)
	var painted: int = 0
	for y in range(size.y):
		for x in range(size.x):
			var c: Color = shot.get_pixel(x, y)
			if c.g < 0.5 and c.r > 0.5:
				sheet.set_pixel(x, y, sheet.get_pixel(x, y).lerp(SILHOUETTE, 0.45))
				painted += 1
	stage.queue_free()
	# A silhouette that covers almost nothing is a camera pointed at the wrong place, not a picture.
	if painted < 20000:
		failures.append("%s (only %d silhouette pixels)" % [filename, painted])
	var path := out.path_join(filename)
	var error := sheet.save_png(path)
	if error != OK:
		failures.append(filename)
	print("[littlebird_shot] %s %s (%d silhouette pixels, the model's origin at drawing (%.2f, %.2f))"
		% ["saved" if error == OK else "FAILED", path, painted, origin.x, origin.y])


func _save(stage: SubViewport, filename: String) -> void:
	for i in range(4):
		await RenderingServer.frame_post_draw
	var path := out.path_join(filename)
	var error := stage.get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(filename)
	print("[littlebird_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
	stage.queue_free()
