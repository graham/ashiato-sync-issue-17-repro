extends Node3D
## Windowed visual evidence for the AH-64D Apache airframe, and the pictures a reader can DISPUTE.
##
##   tools\gate_run.ps1 -Probe apache_shot
##   tools\gate_run.ps1 -Probe apache_shot -Extra "--out=<folder>","--drawing=<ah64_3view.png>"
##
## NOT HEADLESS -- headless has no rendering device. `tests/apache.gd` holds everything that can be asserted, including
## what each eye can see; this renders what a suite cannot: does it READ as an Apache, and do the two cockpits LOOK as a
## gunner and a pilot need them to.
##
## FOUR LIT VIEWS of the outside (front quarter, the port side with the tail rotor, the starboard rear quarter, and high
## over the nose looking down into both cockpits); FOUR FROM THE CREW'S EYES at a headset's 100 degrees (the gunner ahead,
## the gunner down over the nose, the gunner out and down to the left past the stub wing, the pilot ahead over the gunner's
## canopy); ONE from the side with both eyes marked, to show the step; ONE of the chin gun turned 60 degrees to port and
## 20 down; and THREE ORTHOGRAPHIC OVERLAYS on [ARMY] itself -- the PNG enlarged RASTER times and the model's silhouette
## laid on it at the drawing's own scale, aligned on the datums the airframe is built from. Nothing is fitted to make the
## overlay agree: where they disagree, that is the finding, and the canopy is MEANT to read wider in the front view (the
## widened cockpit, `ApacheAirframe`'s doc block).
##
## Every picture carries `<commit>[+dirty], <date> <time>` (`modelling_here.md` section 7). A SubViewport with its OWN
## World3D for each (`lane/prowler`); ambient COLOUR set, since AMBIENT_SOURCE_COLOR reads `ambient_light_color`, which
## defaults to black.

## The drawing is 574 x 385 px; four times is big enough to see a 5.5 cm pixel as a pixel.
const RASTER: float = 4.0
const SILHOUETTE := Color(0.86, 0.10, 0.52)
const MARKER := Color(1.0, 0.62, 0.1)
## [ARMY]'s own datums for the views the side view's `NOSE_X`/`GROUND_Y` do not cover: the front view's centreline and
## its ground (the wheels' lowest pixel), and the plan view's centreline and nose.
const FRONT_CENTRE: Vector2 = Vector2(409.0, 160.5)
const PLAN_CENTRE: Vector2 = Vector2(138.5, 71.0)

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
		drawing = OS.get_environment("USERPROFILE").path_join("godotgames-drafts/2026-09-18/cockpit-apache/research/ah64_3view.png")
	DirAccess.make_dir_recursive_absolute(out)
	stamp = _stamp()

	await _lit("cockpit-apache-01-front-quarter.png", Vector3(-9.0, 3.6, -11.5), Vector3(0.0, 0.2, -2.0), 42.0)
	await _lit("cockpit-apache-02-port-side-tail-rotor.png", Vector3(-17.0, 1.2, 0.0), Vector3(0.0, 0.4, 0.0), 48.0)
	await _lit("cockpit-apache-03-starboard-rear-quarter.png", Vector3(10.0, 3.0, 12.0), Vector3(0.0, 0.3, 0.0), 45.0)
	await _lit("cockpit-apache-04-over-the-nose-into-both-cockpits.png", Vector3(2.2, 5.8, -9.8), Vector3(0.0, 0.3, -4.4),
		40.0)
	var frame := ApacheAirframe.new()
	frame.dress()
	var eyes: Array[Vector3] = frame.crew_eyes()
	frame.free()
	await _eye("cockpit-apache-05-gunner-eye-forward.png", eyes[1], 0.0, -6.0, 1.0)
	await _eye("cockpit-apache-06-gunner-eye-down-over-the-nose.png", eyes[1], 0.0, -25.0, 1.0)
	await _eye("cockpit-apache-07-gunner-eye-out-and-down-to-port.png", eyes[1], 65.0, -35.0, -1.0)
	await _eye("cockpit-apache-08-pilot-eye-forward-over-the-gunner.png", eyes[0], 0.0, -6.0, 1.0)
	await _lit("cockpit-apache-09-starboard-side-both-eyes-marked.png", Vector3(7.0, 1.2, -4.6), Vector3(0.0, 0.6, -4.6),
		44.0, eyes)
	await _lit("cockpit-apache-10-chin-gun-60-port-20-down.png", Vector3(-4.2, -0.2, -8.6), Vector3(0.0, -0.8, -5.0),
		40.0, [], Vector2(deg_to_rad(60.0), deg_to_rad(-20.0)))
	await _overlay("cockpit-apache-11-side-over-army-drawing-x1.000.png", "side")
	await _overlay("cockpit-apache-12-front-over-army-drawing-x1.000.png", "front")
	await _overlay("cockpit-apache-13-top-over-army-drawing-x1.000.png", "top")
	await _beside("cockpit-apache-14-three-quarter-beside-the-army-three-view.png")

	print("[apache_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL " + ", ".join(failures), out])
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
		label.text = "AH-64D ApacheAirframe   %s   %s" % [caption, stamp]
		label.position = Vector2(12, size.y - 30)
		label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
		label.add_theme_font_size_override("font_size", 16)
		stage.add_child(label)
	return stage


## The helicopter on a plain ground in daylight, with a sun that casts shadows, and marks on the ground every two metres
## ahead so a picture from an eye has something to judge "down" against.
func _scene(stage: SubViewport, gun: Vector2 = Vector2.ZERO) -> ApacheAirframe:
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, -0.6, 0.0)
	light.light_energy = 1.35
	light.shadow_enabled = true
	stage.add_child(light)
	var frame := ApacheAirframe.new()
	frame.dress()
	stage.add_child(frame)
	# PARKED an eighth of a turn round, so no blade lies along the boom in the side view.
	frame.set_rotors(false, 0.0, 0.0)
	RotorcraftKit.turn(frame.main_rotor, 0.06, 0.0)
	frame.set_gun(gun.x, gun.y)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(160.0, 160.0)
	ground.mesh = plane
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.42, 0.47, 0.36)
	ground.material_override = grass
	ground.position.y = -ApacheAirframe.DEFAULT_HALF.y
	stage.add_child(ground)
	for i in range(1, 10):
		var mark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(3.0, 0.01, 0.12)
		mark.mesh = box
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color(0.92, 0.92, 0.88)
		mark.material_override = paint
		mark.position = Vector3(0.0, ground.position.y + 0.005, -7.5 - 2.0 * i)
		stage.add_child(mark)
	return frame


## A LIT VIEW from `from` at `target`; `marks` puts an amber ball at each point given (the crew's eyes).
func _lit(filename: String, from: Vector3, target: Vector3, fov: float, marks: Array = [],
		gun: Vector2 = Vector2.ZERO) -> void:
	var stage := _stage(Vector2i(1600, 900), Color(0.62, 0.72, 0.82), Color(0.70, 0.74, 0.80), 0.8,
		filename.get_basename().get_slice("apache-", 1))
	_scene(stage, gun)
	for m in marks:
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.09
		sphere.height = 0.18
		ball.mesh = sphere
		var paint := StandardMaterial3D.new()
		paint.albedo_color = MARKER
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.no_depth_test = true
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


## THE VIEW FROM AN EYE: `az` degrees off dead ahead toward `side` (+1 right), `el` above level, at a headset's field.
func _eye(filename: String, eye: Vector3, az: float, el: float, side: float) -> void:
	var stage := _stage(Vector2i(1600, 1000), Color(0.62, 0.72, 0.82), Color(0.70, 0.74, 0.80), 0.8,
		filename.get_basename().get_slice("apache-", 1))
	_scene(stage)
	var camera := Camera3D.new()
	camera.fov = 100.0
	camera.near = 0.03
	camera.current = true
	stage.add_child(camera)
	camera.global_position = eye
	var a: float = deg_to_rad(az)
	var e: float = deg_to_rad(el)
	camera.look_at(eye + Vector3(side * sin(a) * cos(e), sin(e), -cos(a) * cos(e)), Vector3.UP)
	await _save(stage, filename)


## THE MODEL'S SILHOUETTE ON THE DRAWING, at RASTER times the drawing's own pixels, aligned on the airframe's datums.
func _overlay(filename: String, view: String) -> void:
	var paper := Image.load_from_file(drawing)
	if paper == null or paper.is_empty():
		print("[apache_shot] SKIPPED %s: no drawing at %s (see craft/apache/sources.md)" % [filename, drawing])
		return
	paper.resize(int(paper.get_width() * RASTER), int(paper.get_height() * RASTER), Image.INTERPOLATE_NEAREST)
	var half: Vector3 = ApacheAirframe.DEFAULT_HALF
	var unit: float = ApacheAirframe.UNIT
	var size := Vector2i(1500, 600)
	# The model's origin, in drawing pixels, in each view: where the datums put it.
	var origin := Vector2.ZERO
	var from := Vector3.ZERO
	var up := Vector3.UP
	match view:
		"side":
			origin = Vector2(ApacheAirframe.NOSE_X + half.z / unit, ApacheAirframe.GROUND_Y - half.y / unit)
			from = Vector3(-60.0, 0.0, 0.0)
		"front":
			size = Vector2i(1200, 480)
			origin = Vector2(FRONT_CENTRE.x, FRONT_CENTRE.y - half.y / unit)
			from = Vector3(0.0, 0.0, -60.0)
		"top":
			size = Vector2i(1000, 1300)
			origin = Vector2(PLAN_CENTRE.x, PLAN_CENTRE.y + half.z / unit)
			from = Vector3(0.0, 60.0, 0.0)
			up = Vector3.FORWARD
	var stage := _stage(size, Color.WHITE, Color.WHITE, 1.0, "")
	var frame := ApacheAirframe.new()
	frame.dress()
	stage.add_child(frame)
	# THE ROTOR PARKED AS THE DRAWING DRAWS IT: an X in plan, a blade each side in the front view.
	frame.set_rotors(false, 0.0, 0.0)
	RotorcraftKit.turn(frame.main_rotor, 0.125 if view == "top" else 0.0, 0.0)
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
				sheet.set_pixel(x, y, sheet.get_pixel(x, y).lerp(SILHOUETTE, 0.40))
				painted += 1
	stage.queue_free()
	# A silhouette that covers almost nothing is a camera pointed at the wrong place, not a picture.
	if painted < 15000:
		failures.append("%s (only %d silhouette pixels)" % [filename, painted])
	var path := out.path_join(filename)
	var error := sheet.save_png(path)
	if error != OK:
		failures.append(filename)
	print("[apache_shot] %s %s (%d silhouette pixels, the model's origin at drawing (%.2f, %.2f))"
		% ["saved" if error == OK else "FAILED", path, painted, origin.x, origin.y])


func _save(stage: SubViewport, filename: String) -> void:
	for i in range(4):
		await RenderingServer.frame_post_draw
	var path := out.path_join(filename)
	var error := stage.get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(filename)
	print("[apache_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
	stage.queue_free()


## THE MODEL BESIDE THE DRAWING IT WAS MEASURED FROM: the front-quarter view on the left, [ARMY] enlarged on the right,
## on one sheet, so a reader compares the two without opening two files.
func _beside(filename: String) -> void:
	var paper := Image.load_from_file(drawing)
	if paper == null or paper.is_empty():
		print("[apache_shot] SKIPPED %s: no drawing at %s" % [filename, drawing])
		return
	paper.convert(Image.FORMAT_RGBA8)
	paper.resize(int(paper.get_width() * 1.8), int(paper.get_height() * 1.8), Image.INTERPOLATE_BILINEAR)
	var stage := _stage(Vector2i(1100, 700), Color(0.62, 0.72, 0.82), Color(0.70, 0.74, 0.80), 0.8, "")
	_scene(stage)
	var camera := Camera3D.new()
	camera.fov = 44.0
	camera.current = true
	stage.add_child(camera)
	camera.global_position = Vector3(-10.5, 4.2, -13.0)
	camera.look_at(Vector3(0.0, 0.3, -1.5), Vector3.UP)
	for i in range(4):
		await RenderingServer.frame_post_draw
	var shot: Image = stage.get_texture().get_image()
	shot.convert(Image.FORMAT_RGBA8)
	stage.queue_free()
	var sheet := Image.create(1100 + paper.get_width() + 20, maxi(700, paper.get_height()) + 40, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i(0, 0))
	sheet.blit_rect(paper, Rect2i(Vector2i.ZERO, paper.get_size()), Vector2i(1120, 0))
	var path := out.path_join(filename)
	var error := sheet.save_png(path)
	if error != OK:
		failures.append(filename)
	print("[apache_shot] %s %s (the model %s; the drawing is [ARMY], public domain)" % ["saved" if error == OK else "FAILED",
		path, stamp])
