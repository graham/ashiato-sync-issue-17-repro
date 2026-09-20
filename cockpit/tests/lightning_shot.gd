extends Node3D
## Windowed visual evidence for the F-35B airframe, and the pictures a reader can DISPUTE.
##
##   <editor>.console.exe --path cockpit --xr-mode off res://tests/lightning_shot.tscn -- --out=<folder>
##
## NOT HEADLESS -- headless has no rendering device. `tests/lightning.gd` holds everything about this aeroplane that can be
## asserted; this renders what a suite cannot see: does it READ as an F-35B, and do its doors, nozzle and gear look right
## part-way as well as at the ends. Every picture is a SubViewport of the probe's own, never the desktop.
##
## LIT VIEWS: the front and rear quarters, the intakes from low ahead, the side; the nozzle at 0, 45 and 90 degrees with
## the lift fan's doors; the STOVL configuration from above; the bays open from below; and the gear cycle as seven frames
## at fixed amounts for `craft/lightning/strip.py` to lay side by side. And THREE ORTHOGRAPHIC SILHOUETTES at exactly
## `PX_PER_METRE`, the JSF renders' own scale, so `craft/lightning/overlay_views.py` lays them over those renders at x1.000
## with no fitting.
##
## A SubViewport with its OWN World3D for each, because without it every stage shares the parent's world and each
## WorldEnvironment fights the others (`lane/prowler`). AMBIENT_SOURCE_COLOR reads `ambient_light_color`, which defaults to
## BLACK, so both are set.

## THE JSF RENDERS' SCALE: 1,914 px for the published 10.7 m span (`craft/lightning/measure_views.py`).
const PX_PER_METRE: float = 1914.0 / 10.7
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

	await _lit("lightning-01-front-quarter.png", Vector3(-12.5, 4.5, -14.0), Vector3(0.0, 0.0, -0.5), 38.0, {})
	await _lit("lightning-02-rear-quarter.png", Vector3(12.0, 4.5, 14.0), Vector3(0.0, 0.2, 1.0), 38.0, {})
	await _lit("lightning-03-intakes-low-ahead.png", Vector3(-3.6, -0.5, -13.0), Vector3(0.0, -0.1, -3.5), 34.0, {})
	await _lit("lightning-04-side.png", Vector3(-24.0, 0.4, 0.0), Vector3(0.0, 0.2, 0.0), 40.0, {})
	for amount in [0.0, 0.5, 1.0]:
		await _lit("lightning-05-nozzle-%02d-deg.png" % int(round(amount * 95.0)), Vector3(-12.5, -0.5, 12.5),
			Vector3(0.0, -0.4, 4.5), 38.0, {"nozzle": amount})
	await _lit("lightning-06-stovl-from-above.png", Vector3(-9.0, 12.0, 7.5), Vector3(0.0, 0.0, 0.5), 40.0,
		{"nozzle": 1.0, "fan": 0.3})
	await _lit("lightning-07-bays-open-from-below.png", Vector3(-4.0, -5.5, -3.0), Vector3(0.0, -0.7, 0.8), 50.0,
		{"bays": 1.0}, true)
	for amount in GEAR_FRAMES:
		await _lit("lightning-08-gear-%03d.png" % int(round(amount * 100.0)), Vector3(-15.0, -0.8, -3.0),
			Vector3(0.0, -0.8, -0.3), 46.0, {"gear": amount})
	await _orthographic("lightning-09-side-at-jsf-scale.png", Vector2i(3000, 2400), Vector3(-40.0, 0.0, 0.0), Vector3.UP)
	await _orthographic("lightning-10-top-at-jsf-scale.png", Vector2i(3000, 2400), Vector3(0.0, 40.0, 0.0), Vector3.RIGHT)
	await _orthographic("lightning-11-front-at-jsf-scale.png", Vector2i(3000, 2400), Vector3(0.0, 0.0, -40.0), Vector3.UP)

	print("[lightning_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL", out])
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
## (`nozzle`, `gear`, `bays`, `fan`). `from_below` lights it from underneath too and leaves the ground out, so a view up at
## the belly is not the ground's underside.
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
	var frame := LightningAirframe.new()
	frame.dress()
	stage.add_child(frame)
	frame.set_nozzle(float(pose.get("nozzle", 0.0)))
	frame.set_gear(float(pose.get("gear", 1.0)))
	frame.set_bay(1.0, float(pose.get("bays", 0.0)))
	frame.set_bay(-1.0, float(pose.get("bays", 0.0)))
	frame.set_fan(float(pose.get("fan", 0.0)))
	if not from_below:
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(80.0, 80.0)
		ground.mesh = plane
		var concrete := StandardMaterial3D.new()
		concrete.albedo_color = Color(0.45, 0.45, 0.43)
		ground.material_override = concrete
		ground.position.y = frame.point(0.0, LightningAirframe.ground(), 0.0).y
		stage.add_child(ground)
	var label := Label.new()
	label.text = "F-35B  " + ", ".join(_said(pose))
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
	if pose.has("nozzle"):
		said.append("nozzle %.0f deg down" % (float(pose["nozzle"]) * 95.0))
	if pose.has("gear"):
		said.append("gear %.0f%% (0 up, 100 down)" % (float(pose["gear"]) * 100.0))
	if pose.has("bays"):
		said.append("bays open")
	if said.is_empty():
		said.append("gear down, everything shut")
	return said


## ONE ORTHOGRAPHIC VIEW at PX_PER_METRE, flat and unshaded, centred on the craft's origin, gear UP as the renders draw it.
func _orthographic(filename: String, size: Vector2i, from: Vector3, up: Vector3) -> void:
	var stage := _stage(size, Color.WHITE, Color.WHITE, 1.0)
	var frame := LightningAirframe.new()
	frame.dress()
	stage.add_child(frame)
	frame.set_gear(0.0)
	var flat := StandardMaterial3D.new()
	flat.albedo_color = SILHOUETTE
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	print("[lightning_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
	stage.queue_free()
