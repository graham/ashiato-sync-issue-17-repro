extends Node3D
## Windowed pictures of Porco Rosso's red flying boat, `SavoiaAirframe`, and silhouettes a reader can lay over the
## reference photographs and argue with.
##
##   Godot --xr-mode off --path cockpit res://tests/savoia_shot.tscn -- --out=<folder>
##
## NOT HEADLESS -- headless has no rendering device. `tests/savoia.gd` holds everything about the aeroplane that can be
## asserted; this renders what a suite cannot see: does it READ as Porco's plane.
##
## LIT VIEWS: the front quarter from above (the hero), a broadside to set beside the side photograph, the rear quarter
## with its fin, the underside from low ahead with the wing's tricolour and the tan planing bottom, the aeroplane afloat
## on water at its draught with the propeller turning and the stick hard over, back and right rudder so the hinges are
## seen to move the right way, the view from the pilot's eye forward through the slot under the nacelle, and a view from
## above. Then THREE ORTHOGRAPHIC SILHOUETTES at `PX_PER_METRE`.
##
## Every lit picture carries `<commit>[+dirty], <time>` (`modelling_here.md` section 7: a gallery goes stale and nothing
## in it says so). A SubViewport with its OWN World3D for each (`lane/prowler`); ambient COLOUR set as well as energy.

const PX_PER_METRE: float = 100.0
const SILHOUETTE := Color(0.82, 0.16, 0.55)

var out := ""
var failures: PackedStringArray = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("user://savoia_shot")
	DirAccess.make_dir_recursive_absolute(out)
	var stamp := _stamp()

	await _lit("savoia-01-front-quarter.png", Vector3(-9.5, 4.5, -10.5), Vector3(0.0, 0.0, -0.3), 40.0, stamp, {})
	await _lit("savoia-02-broadside.png", Vector3(-17.0, 0.2, 0.0), Vector3(0.0, 0.0, 0.0), 36.0, stamp, {})
	await _lit("savoia-03-rear-quarter.png", Vector3(9.0, 4.0, 11.0), Vector3(0.0, 0.2, 0.0), 40.0, stamp, {})
	await _lit("savoia-04-underside-low-ahead.png", Vector3(-6.5, -4.2, -9.5), Vector3(0.0, -0.4, 0.0), 44.0, stamp,
		{"no_ground": true})
	await _lit("savoia-05-afloat-prop-turning-stick-right-back-right-rudder.png", Vector3(8.5, 3.2, -10.0),
		Vector3(0.0, -0.2, 0.2), 40.0, stamp, {"water": true, "deflected": true})
	await _lit("savoia-06-above.png", Vector3(0.3, 16.0, 1.0), Vector3(0.0, 0.0, 0.0), 44.0, stamp, {})
	await _pilot("savoia-07-pilot-eye-forward.png", stamp)
	await _orthographic("savoia-08-side-at-100px-per-m.png", Vector2i(1100, 500), Vector3(-40.0, 0.0, 0.0), Vector3.UP)
	await _orthographic("savoia-09-top-at-100px-per-m.png", Vector2i(1200, 1000), Vector3(0.0, 40.0, 0.0), Vector3.FORWARD)
	await _orthographic("savoia-10-front-at-100px-per-m.png", Vector2i(1200, 500), Vector3(0.0, 0.0, -40.0), Vector3.UP)

	print("[savoia_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL", out])
	get_tree().quit(0 if failures.is_empty() else 1)


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
	env.ambient_light_color = ambient
	env.ambient_light_energy = energy
	environment.environment = env
	stage.add_child(environment)
	return stage


## A LIT VIEW from `eye` at `target`, over a plain ground at the keel (as a kit on its stand) or on water at the hull's
## draught, captioned with the stamp.
func _lit(filename: String, eye: Vector3, target: Vector3, fov: float, stamp: String, options: Dictionary) -> void:
	var stage := _stage(Vector2i(1600, 900), Color(0.62, 0.72, 0.82), Color(0.68, 0.72, 0.78), 0.8)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, -0.6, 0.0)
	light.light_energy = 1.35
	light.shadow_enabled = true
	stage.add_child(light)
	var frame := SavoiaAirframe.new()
	frame.dress()
	stage.add_child(frame)
	if options.get("deflected", false):
		frame.set_ailerons(1.0)
		frame.set_elevator(1.0)
		frame.set_rudder(1.0)
		frame.set_propeller(true, 0.8, 0.37)
	var said: String = "parked"
	if options.get("water", false):
		var water := MeshInstance3D.new()
		var sea := PlaneMesh.new()
		sea.size = Vector2(120.0, 120.0)
		water.mesh = sea
		water.name = "Sea"
		# THE SEA'S OWN SHADER, as every water here is dressed (WaterSurface): a flat blue until 2026-09-17. INLAND,
		# because this 120 m square is the Savoia's pond and not the sea: no swell, no chop, at any distance.
		WaterSurface.wear(water, Finish.is_fine(), null, true)
		# ESTIMATE: afloat at 0.30 m over the keel, where the floats' keels (0.28) just touch.
		water.position.y = frame.height(0.30)
		stage.add_child(water)
		said = "afloat at 0.30 m draught, propeller turning, stick right and back, right rudder"
	elif not options.get("no_ground", false):
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(80.0, 80.0)
		ground.mesh = plane
		var grey := StandardMaterial3D.new()
		grey.albedo_color = Color(0.46, 0.46, 0.44)
		ground.material_override = grey
		ground.position.y = frame.height(0.0)
		stage.add_child(ground)
	else:
		said = "from below"
	var camera := Camera3D.new()
	camera.fov = fov
	camera.current = true
	stage.add_child(camera)
	camera.global_position = eye
	camera.look_at(target, Vector3.UP if absf(eye.normalized().y) < 0.95 else Vector3.FORWARD)
	_caption(stage, "SavoiaAirframe, %s   |   %s" % [said, stamp])
	await _save(stage, filename)


## FROM THE PILOT'S EYE, looking level ahead with a headset's field of view: through the slot between the wing's top and
## the nacelle's belly.
func _pilot(filename: String, stamp: String) -> void:
	var stage := _stage(Vector2i(1600, 900), Color(0.62, 0.72, 0.82), Color(0.68, 0.72, 0.78), 0.8)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, -0.6, 0.0)
	light.light_energy = 1.35
	stage.add_child(light)
	var frame := SavoiaAirframe.new()
	frame.dress()
	stage.add_child(frame)
	var camera := Camera3D.new()
	camera.fov = 90.0
	camera.near = 0.02
	camera.current = true
	stage.add_child(camera)
	camera.global_position = frame.eye()
	camera.look_at(frame.eye() + Vector3(0.0, -0.12, -1.0), Vector3.UP)
	_caption(stage, "SavoiaAirframe, from the pilot's eye %.2f m over the keel, 90 deg, 7 deg down   |   %s"
		% [frame.eye().y - frame.height(0.0), stamp])
	await _save(stage, filename)


## ONE ORTHOGRAPHIC SILHOUETTE at PX_PER_METRE, flat and unshaded, centred on the craft's origin.
func _orthographic(filename: String, size: Vector2i, from: Vector3, up: Vector3) -> void:
	var stage := _stage(size, Color.WHITE, Color.WHITE, 1.0)
	var frame := SavoiaAirframe.new()
	frame.dress()
	stage.add_child(frame)
	var flat := StandardMaterial3D.new()
	flat.albedo_color = SILHOUETTE
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.cull_mode = BaseMaterial3D.CULL_DISABLED
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


func _caption(stage: SubViewport, text: String) -> void:
	var caption := Label.new()
	caption.text = text
	caption.position = Vector2(16, 12)
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
	stage.add_child(caption)


func _save(stage: SubViewport, filename: String) -> void:
	for frame in range(4):
		await RenderingServer.frame_post_draw
	var path := out.path_join(filename)
	var error := stage.get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(filename)
	print("[savoia_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
	stage.queue_free()
