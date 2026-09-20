extends Node3D
## Windowed visual evidence for the A-10C airframe, and the pictures a reader can DISPUTE.
##
##   <editor>.console.exe --path cockpit --xr-mode off res://tests/warthog_shot.tscn -- --out=<folder>
##
## NOT HEADLESS -- headless has no rendering device. `tests/warthog.gd` holds everything about this aeroplane that can be
## asserted; this renders what a suite cannot see: does it READ as an A-10, and do its gear, doors, surfaces and gun look
## right part-way as well as at the ends. Every picture is a SubViewport of the probe's own, never the desktop.
##
## LIT VIEWS: the front and rear quarters, the side, from above and from below; the GAU-8 from low ahead; each surface at
## its stop (roll, pitch, yaw, the flaps and the decelerons split open as the speed brake); and the gear cycle as eight
## frames at fixed amounts. And THREE ORTHOGRAPHIC SILHOUETTES, gear up, at exactly `PX_PER_METRE`, the three-view's own
## scale, so `craft/warthog/overlay_views.py` lays them over the drawing at x1.000 with no fitting.
##
## A SubViewport with its OWN World3D for each, because without it every stage shares the parent's world and each
## WorldEnvironment fights the others (`lane/prowler`). AMBIENT_SOURCE_COLOR reads `ambient_light_color`, which defaults to
## BLACK, so both are set.

## THE THREE-VIEW'S SCALE at the x3 raster: 3,503 px for the published 17.53 m span (`craft/warthog/measure_views.py`).
const PX_PER_METRE: float = 3503.0 / 17.53
const SILHOUETTE := Color(0.82, 0.16, 0.55)
## The gear frames, as amounts of the cycle from up (0) to down (1): the doors' share, the legs', the doors' again.
const GEAR_FRAMES: Array = [0.0, 0.1, 0.2, 0.4, 0.6, 0.8, 0.9, 1.0]

var out := ""
var failures: PackedStringArray = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)

	await _lit("warthog-01-front-quarter.png", Vector3(-14.0, 4.0, -16.0), Vector3(0.0, -0.3, -0.8), 40.0, {})
	await _lit("warthog-02-rear-quarter.png", Vector3(14.0, 5.0, 16.0), Vector3(0.0, 0.0, 0.8), 40.0, {})
	await _lit("warthog-03-side.png", Vector3(28.0, 0.6, 0.0), Vector3(0.0, 0.0, 0.0), 40.0, {})
	await _lit("warthog-04-from-above.png", Vector3(-6.0, 26.0, 8.0), Vector3(0.0, 0.0, 0.3), 42.0, {})
	await _lit("warthog-05-from-below-gear-up.png", Vector3(-6.0, -18.0, -6.0), Vector3(0.0, -0.5, 0.0), 50.0,
		{"gear": 0.0}, true)
	await _lit("warthog-06-gau8-low-ahead.png", Vector3(-2.4, -1.1, -13.0), Vector3(0.0, -0.9, -7.2), 26.0, {})
	await _lit("warthog-07-roll-right.png", Vector3(-9.0, 6.0, 17.0), Vector3(0.0, 0.0, 0.5), 42.0, {"roll": 1.0})
	await _lit("warthog-08-pitch-up.png", Vector3(-9.0, 6.0, 17.0), Vector3(0.0, 0.0, 0.5), 42.0, {"pitch": 1.0})
	await _lit("warthog-09-yaw-right.png", Vector3(-9.0, 6.0, 17.0), Vector3(0.0, 0.0, 0.5), 42.0, {"yaw": 1.0})
	await _lit("warthog-10-flaps-down.png", Vector3(-9.0, 6.0, 17.0), Vector3(0.0, 0.0, 0.5), 42.0, {"flaps": 1.0})
	await _lit("warthog-11-decelerons-split-open.png", Vector3(-12.0, 2.5, 12.0), Vector3(-5.0, 0.0, 1.0), 34.0,
		{"brake": 1.0})
	# THE WING, which the user asked to see: its structure close to, gear up so the main wheel shows half out of its pod,
	# the decelerons split and the flaps down, from ahead, low and outboard of the port wing; then the whole wing from dead
	# ahead, where the flat centre section, the outer panels' dihedral and the drooped tips read against the sky; and the
	# slotted flaps from behind.
	await _lit("warthog-13-wing-close-up-pod-slat-droop-decelerons.png", Vector3(-10.5, 0.4, -9.0), Vector3(-5.0, -0.5, 0.8),
		46.0, {"gear": 0.0, "brake": 1.0, "flaps": 1.0, "wing": true})
	await _lit("warthog-14-wing-from-dead-ahead.png", Vector3(0.0, -0.35, -34.0), Vector3(0.0, -0.35, 0.0), 21.0,
		{"gear": 0.0})
	await _lit("warthog-15-slotted-flaps-from-behind.png", Vector3(-6.0, -1.2, 13.0), Vector3(-2.5, -0.9, 1.5), 40.0,
		{"flaps": 1.0})
	for amount in GEAR_FRAMES:
		await _lit("warthog-12-gear-%03d.png" % int(round(amount * 100.0)), Vector3(-15.0, -0.8, -5.0),
			Vector3(0.0, -0.8, -1.5), 46.0, {"gear": amount})
	await _orthographic("warthog-20-side-at-drawing-scale.png", Vector2i(3600, 1200), Vector3(40.0, 0.0, 0.0), Vector3.UP)
	await _orthographic("warthog-21-top-at-drawing-scale.png", Vector2i(3600, 3700), Vector3(0.0, 40.0, 0.0), Vector3.LEFT)
	await _orthographic("warthog-22-front-at-drawing-scale.png", Vector2i(3700, 1200), Vector3(0.0, 0.0, -40.0), Vector3.UP)

	print("[warthog_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL", out])
	get_tree().quit(0 if failures.is_empty() else 1)


func _stage(size: Vector2i, background: Color, ambient: Color, energy: float) -> SubViewport:
	var stage := SubViewport.new()
	stage.size = size
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.own_world_3d = true
	add_child(stage)
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


## A LIT VIEW from `from` looking at `target`, over a plain ground the gear stands on, the airframe posed by `pose`
## (`gear`, `roll`, `pitch`, `yaw`, `flaps`, `brake`). `from_below` lights it from underneath too and leaves the ground
## out, so a view up at the belly is not the ground's underside.
func _lit(filename: String, from: Vector3, target: Vector3, fov: float, pose: Dictionary,
		from_below: bool = false) -> void:
	var stage := _stage(Vector2i(1600, 900), Color(0.58, 0.66, 0.74), Color(0.66, 0.70, 0.76), 0.85)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.85, -0.7, 0.0)
	light.light_energy = 1.3
	light.shadow_enabled = true
	stage.add_child(light)
	if from_below:
		var fill := DirectionalLight3D.new()
		fill.rotation = Vector3(0.9, 0.4, 0.0)
		fill.light_energy = 0.7
		stage.add_child(fill)
	var frame := WarthogAirframe.new()
	frame.dress()
	stage.add_child(frame)
	frame.set_gear(float(pose.get("gear", 1.0)))
	frame.set_ailerons(float(pose.get("roll", 0.0)))
	frame.set_elevators(float(pose.get("pitch", 0.0)))
	frame.set_rudders(float(pose.get("yaw", 0.0)))
	frame.set_flaps(float(pose.get("flaps", 0.0)))
	frame.set_speedbrake(float(pose.get("brake", 0.0)))
	if not from_below:
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(90.0, 90.0)
		ground.mesh = plane
		var concrete := StandardMaterial3D.new()
		concrete.albedo_color = Color(0.45, 0.45, 0.43)
		ground.material_override = concrete
		ground.position.y = frame.point(0.0, WarthogAirframe.ground(), 0.0).y
		stage.add_child(ground)
	var label := Label.new()
	label.text = "A-10C  " + ", ".join(_said(pose))
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
	label.position = Vector2(24, 18)
	stage.add_child(label)
	var camera := Camera3D.new()
	camera.fov = fov
	camera.current = true
	stage.add_child(camera)
	camera.global_position = from
	camera.look_at(target, Vector3.UP)
	await _save(stage, filename)


static func _said(pose: Dictionary) -> PackedStringArray:
	var said: PackedStringArray = []
	if pose.has("gear"):
		said.append("gear %.0f%% (0 up, 100 down)" % (float(pose["gear"]) * 100.0))
	if pose.has("wing"):
		return PackedStringArray(["the wing: centre section, slat, gear pod (wheel half out), drooped tip, decelerons split, flaps down"])
	if pose.has("roll"):
		said.append("stick full right: right aileron up, left down")
	if pose.has("pitch"):
		said.append("stick full back: elevators up")
	if pose.has("yaw"):
		said.append("right pedal: both rudders right")
	if pose.has("flaps"):
		said.append("flaps down 20 deg")
	if pose.has("brake"):
		said.append("speed brake open: each aileron splits 40 deg up and 40 down")
	if said.is_empty():
		said.append("gear down, everything neutral")
	return said


## ONE ORTHOGRAPHIC VIEW at PX_PER_METRE, flat and unshaded, centred on the craft's origin, gear UP as the drawing draws it.
func _orthographic(filename: String, size: Vector2i, from: Vector3, up: Vector3) -> void:
	var stage := _stage(size, Color.WHITE, Color.WHITE, 1.0)
	var frame := WarthogAirframe.new()
	frame.dress()
	stage.add_child(frame)
	frame.set_gear(0.0)
	var flat := StandardMaterial3D.new()
	flat.albedo_color = SILHOUETTE
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for node in frame.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = flat
		for s in range((node as MeshInstance3D).get_surface_override_material_count()):
			(node as MeshInstance3D).set_surface_override_material(s, null)
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
	print("[warthog_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
	stage.queue_free()
