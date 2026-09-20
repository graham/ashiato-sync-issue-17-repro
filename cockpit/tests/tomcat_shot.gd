extends Node3D
## Windowed visual evidence for the F-14D Tomcat airframe AT EVERY SWEEP, and the pictures a reader can DISPUTE.
##
##   Godot --path cockpit res://tests/tomcat_shot.tscn -- --out=<folder>
##
## NOT HEADLESS -- headless has no rendering device. `tests/tomcat.gd` holds everything about this aeroplane that can be
## asserted; this renders what a suite cannot see: whether it reads as a Tomcat, and whether the swung wing LOOKS right
## in the glove at 20, 44, 68 and 75 degrees.
##
## THE ORTHOGRAPHIC VIEWS ARE AT THE SOURCE DRAWING'S OWN SCALE, 121.1 px a metre (`craft/tomcat/sources.md`), each in
## its own SubViewport with its own World3D, so a silhouette lays straight over the F-14D drawing at x1.000 with no
## fitting. The plan view is taken at 68 degrees because that is the only sweep the drawing draws.

const PX_PER_METRE: float = 121.1
const SILHOUETTE := Color(0.82, 0.16, 0.55)

var out := ""
var failures: PackedStringArray = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	var stamp := _stamp()
	for sweep in [20.0, 44.0, 68.0, 75.0]:
		await _lit("cockpit-tomcat-three-quarter-sweep-%02d.png" % int(sweep), sweep, Vector3(15.0, 9.0, -17.0), stamp)
	for sweep in [20.0, 44.0, 68.0, 75.0]:
		await _lit("cockpit-tomcat-above-sweep-%02d.png" % int(sweep), sweep, Vector3(0.5, 30.0, 2.0), stamp)
	await _lit("cockpit-tomcat-rear-quarter-sweep-68.png", 68.0, Vector3(-13.0, 6.0, 17.0), stamp)
	await _orthographic("cockpit-tomcat-ortho-top-sweep-68-at-drawing-scale.png", 68.0, Vector2i(1500, 2400),
		Vector3(0.0, 40.0, 0.0), Vector3.FORWARD)
	await _orthographic("cockpit-tomcat-ortho-side-at-drawing-scale.png", 68.0, Vector2i(2400, 1000),
		Vector3(-40.0, 0.0, 0.0), Vector3.UP)
	await _orthographic("cockpit-tomcat-ortho-rear-sweep-68-at-drawing-scale.png", 68.0, Vector2i(1500, 1000),
		Vector3(0.0, 0.0, 40.0), Vector3.UP)
	await _orthographic("cockpit-tomcat-ortho-top-sweep-20-at-drawing-scale.png", 20.0, Vector2i(2500, 2400),
		Vector3(0.0, 40.0, 0.0), Vector3.FORWARD)
	for sweep in [20.0, 47.29, 68.0, 74.61]:
		await _vat_against_parts(sweep)
	print("[tomcat_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL", out])
	get_tree().quit(0 if failures.is_empty() else 1)


## THE COMMIT AND WHETHER THE TREE WAS DIRTY, burned into every lit picture (`modelling_here.md` section 7): a gallery goes
## stale and nothing in it says so.
func _stamp() -> String:
	var head: Array = []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "--short", "HEAD"], head)
	var status: Array = []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "status", "--porcelain"], status)
	var dirty: bool = not String(status[0] if not status.is_empty() else "").strip_edges().is_empty()
	return "%s%s, %s" % [String(head[0] if not head.is_empty() else "?").strip_edges(), "+dirty" if dirty else "",
		Time.get_datetime_string_from_system(false, true)]


func _stage(size: Vector2i, background: Color, ambient: Color, energy: float) -> SubViewport:
	var stage := SubViewport.new()
	stage.size = size
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# ITS OWN WORLD, or every stage here shares one scene and each WorldEnvironment fights the others (`lane/prowler`).
	stage.own_world_3d = true
	add_child(stage)
	# THE BUILD STAMP IN THE LOWER RIGHT, as in every picture the game takes (`BuildStamp`, 2026-09-18): this stage is a
	# viewport of its own, which the root's stamp is not drawn into.
	BuildStamp.attach_to(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# AMBIENT_SOURCE_COLOR reads `ambient_light_color`, which defaults to BLACK.
	env.ambient_light_color = ambient
	env.ambient_light_energy = energy
	environment.environment = env
	stage.add_child(environment)
	return stage


## LIT, on a ground plane at the tyres, from a stated eye, with the sweep and the stamp printed in the corner.
func _lit(filename: String, sweep: float, eye: Vector3, stamp: String) -> void:
	var stage := _stage(Vector2i(1600, 900), Color(0.24, 0.28, 0.33), Color(0.62, 0.66, 0.72), 0.85)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.85, -0.55, 0.0)
	light.light_energy = 1.5
	light.shadow_enabled = true
	stage.add_child(light)
	var frame := TomcatAirframe.new()
	frame.dress()
	frame.set_sweep(sweep)
	stage.add_child(frame)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	ground.mesh = plane
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.36, 0.37, 0.36)
	ground.material_override = paint
	ground.position = Vector3(0.0, frame.height(0.0), 0.0)
	stage.add_child(ground)
	var camera := Camera3D.new()
	camera.fov = 38
	camera.current = true
	stage.add_child(camera)
	camera.global_position = eye
	camera.look_at(Vector3(0.0, frame.height(2.0), 1.0), Vector3.UP if absf(eye.normalized().y) < 0.95 else Vector3.FORWARD)
	var caption := Label.new()
	caption.text = "F-14D TomcatAirframe, wing at %.0f degrees   |   %s" % [sweep, stamp]
	caption.position = Vector2(16, 12)
	caption.add_theme_font_size_override("font_size", 26)
	stage.add_child(caption)
	await _save(stage, filename)


## ONE ORTHOGRAPHIC SILHOUETTE at the drawing's scale: the camera's width is the viewport's width over PX_PER_METRE.
func _orthographic(filename: String, sweep: float, size: Vector2i, from: Vector3, up: Vector3) -> void:
	var stage := _stage(size, Color.WHITE, Color.WHITE, 1.0)
	var frame := TomcatAirframe.new()
	frame.dress()
	frame.set_sweep(sweep)
	stage.add_child(frame)
	var flat := StandardMaterial3D.new()
	flat.albedo_color = SILHOUETTE
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for node in frame.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = flat
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = float(size.x) / PX_PER_METRE
	camera.near = 0.05
	camera.far = 200.0
	camera.current = true
	stage.add_child(camera)
	camera.global_position = from
	camera.look_at(Vector3.ZERO, up)
	await _save(stage, filename)


func _save(stage: SubViewport, filename: String) -> void:
	for frame in range(4):
		await RenderingServer.frame_post_draw
	var path := out.path_join(filename)
	var error := stage.get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(filename)
	print("[tomcat_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
	stage.queue_free()


## THE SWEEP THROUGH THE VAT, AGAINST THE PARTS, BY PIXELS. Two stages lit and framed alike from above and behind the
## wing: one airframe drawn as its parts, one poured into a `VatCasting` and played by the shader. The sweeps include two
## OFF the table's rows. A pixel counts as different if any channel differs by more than 2 of 255; the check fails if more
## than one in a thousand of the aeroplane's own pixels do (`vat` measured 1 of 112,510 on the Cessna).
func _vat_against_parts(sweep: float) -> void:
	var pictures: Array[Image] = []
	var stamp := Rect2i()
	for casting in [false, true]:
		var stage := _stage(Vector2i(1200, 800), Color(0.24, 0.28, 0.33), Color(0.62, 0.66, 0.72), 0.85)
		var light := DirectionalLight3D.new()
		light.rotation = Vector3(-0.85, -0.55, 0.0)
		light.light_energy = 1.5
		stage.add_child(light)
		var frame := TomcatAirframe.new()
		frame.dress()
		stage.add_child(frame)
		if casting:
			var vat: VatCasting = await VatCasting.pour(frame, frame.features())
			vat.set_process(false)
			frame.set_sweep(sweep)
			vat.play()
		else:
			frame.set_sweep(sweep)
		var camera := Camera3D.new()
		camera.fov = 40
		camera.current = true
		stage.add_child(camera)
		camera.global_position = Vector3(9.0, 16.0, 16.0)
		camera.look_at(Vector3(0.0, frame.height(2.0), 1.5), Vector3.UP)
		for i in range(4):
			await RenderingServer.frame_post_draw
		pictures.append(stage.get_texture().get_image())
		stamp = BuildStamp.pixels_in(stage)
		stage.queue_free()
	var background := pictures[0].get_pixel(0, 0)
	var aeroplane: int = 0
	var differ: int = 0
	var marked := pictures[1].duplicate() as Image
	for y in range(pictures[0].get_height()):
		for x in range(pictures[0].get_width()):
			# NOT THE BUILD STAMP: its letters are not the background, so they would count as aeroplane.
			if stamp.has_point(Vector2i(x, y)):
				continue
			var a: Color = pictures[0].get_pixel(x, y)
			var b: Color = pictures[1].get_pixel(x, y)
			if not (a.is_equal_approx(background) and b.is_equal_approx(background)):
				aeroplane += 1
			if absf(a.r - b.r) > 2.0 / 255.0 or absf(a.g - b.g) > 2.0 / 255.0 or absf(a.b - b.b) > 2.0 / 255.0:
				differ += 1
				marked.set_pixel(x, y, Color(1.0, 0.0, 1.0))
	var name := "cockpit-tomcat-vat-against-parts-sweep-%05.2f.png" % sweep
	marked.save_png(out.path_join(name))
	var ok: bool = aeroplane > 10000 and float(differ) <= float(aeroplane) * 0.001
	if not ok:
		failures.append(name)
	print("[tomcat_shot] vat against parts at %.2f degrees: %d of %d aeroplane pixels differ (%s); magenta marks them in %s"
		% [sweep, differ, aeroplane, "PASS" if ok else "FAIL", name])
