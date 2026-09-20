extends Node3D
## Windowed visual evidence for the F-4E airframe, and the pictures a reader can DISPUTE.
##
##   <editor>.console.exe --path cockpit --xr-mode off res://tests/phantom_shot.tscn -- --out=<folder>
##
## NOT HEADLESS -- headless has no rendering device. `tests/phantom.gd` holds everything about this aeroplane that can
## be asserted; this renders what a suite cannot see: does it READ as a Phantom. Every picture is a SubViewport of this
## probe's own, NEVER the desktop -- a lane caught another application on the user's screen on 2026-09-18.
##
## WHAT EACH PICTURE IS FOR, because `lane/audit` proved that a thorough look through the wrong instrument is still
## blind -- it missed a machine gun in a picture it had open, because it was looking for boxiness:
## - the FRONT-ON view is the only one that can show the 12-degree outer dihedral and the 23-degree stabilator
##   anhedral, which are the two angles that decide whether this is a Phantom or just a fighter;
## - the TOP view is the only one that shows the dogtooth and the planform;
## - the LOW THREE-QUARTER FRONT is the only one that shows the intake splitters standing off the skin with daylight
##   in the boundary-layer gap;
## - the NOSE view is the only one that shows the gun fairing, which is what makes this an E;
## - the TAIL view is the only one that shows the nozzle petals and the hook between them.
## Say what a picture cannot show before reading a conclusion off it: none of these shows the fuselage section, which
## is the part of the table with the most judgement in it.
##
## THE ORTHOGRAPHIC OVERLAYS, and the one place this sheet needs more than the nine craft that already have an
## overlay. `craft/lightning/overlay_views.py` renders all three views at ONE px-per-metre, because the JSF's
## three renders share a camera. **THESE THREE VIEWS DO NOT SHARE A SCALE.** Measured off their own printed
## figures by `craft/phantom/measure_manual.py`: the side view is 100.42 px/m, the plan 100.26 along, the front
## 101.54. A single constant would report 1.3 per cent of disagreement on the front view that belongs to the
## PAPER and not to the model -- which is exactly the kind of number a reader would spend an afternoon chasing.
## So each view is rendered at ITS OWN scale, and each carries that scale in its own name.
##
## AND THE PLAN VIEW STILL CANNOT BE MATCHED ON BOTH AXES AT ONCE, because the sheet is stretched about one per
## cent ALONG the aeroplane and an orthographic render is isotropic by construction. It is rendered at the ALONG
## scale, so it reads about 0.8 per cent WIDE across -- 1,173 px against the drawn 1,164. **That residual is the
## finding, not a fault**, and `overlay_views.py` prints it separately from the agreement so nobody tries to
## scale it away.
##
## A SubViewport with its OWN World3D for each, because without it every stage shares the parent's world and each
## WorldEnvironment fights the others (`lane/prowler`). AMBIENT_SOURCE_COLOR reads `ambient_light_color`, which
## defaults to BLACK, so both are set (`lane/fleet`).

## EACH VIEW'S OWN SCALE, every one of them off a figure printed on THAT view
## (`craft/phantom/measure_manual.py`). They differ by up to 1.3 per cent and that is the sheet, not the model.
const SIDE_PX_PER_METRE: float = 713.0 / 7.09       # the printed 7.09 m wheelbase, a STATION difference
const PLAN_PX_PER_METRE: float = 1925.0 / 19.2      # the plan's own drawn length against the printed 19.2 m
const FRONT_PX_PER_METRE: float = 1189.0 / 11.71    # the printed 11.71 m span's own rule
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

	await _lit("phantom-01-front-quarter.png", Vector3(-15.0, 4.5, -16.0), Vector3(0.0, 1.6, -1.0), 38.0)
	await _lit("phantom-02-rear-quarter.png", Vector3(14.0, 5.0, 16.0), Vector3(0.0, 1.8, 2.0), 38.0)
	await _lit("phantom-03-side.png", Vector3(-27.0, 2.2, 0.5), Vector3(0.0, 1.9, 0.5), 40.0)
	# THE ONE PICTURE THAT SHOWS BOTH ANGLES. Level with the wing, dead ahead.
	await _lit("phantom-04-front-on-dihedral-and-anhedral.png", Vector3(0.0, 2.6, -26.0), Vector3(0.0, 2.2, 0.0), 30.0)
	await _lit("phantom-05-top-dogtooth-and-planform.png", Vector3(0.5, 22.0, 1.0), Vector3(0.0, 1.5, 0.5), 40.0)
	await _lit("phantom-06-intake-splitters-low-ahead.png", Vector3(-5.0, 0.9, -9.5), Vector3(-1.1, 2.0, -0.5), 34.0)
	await _lit("phantom-07-nose-and-gun-fairing.png", Vector3(-6.0, 1.1, -8.5), Vector3(-0.2, 1.4, -6.6), 34.0)
	await _lit("phantom-08-tail-nozzles-and-hook.png", Vector3(4.5, 1.6, 10.5), Vector3(0.0, 1.6, 4.5), 34.0)
	await _lit("phantom-09-canopies-from-above.png", Vector3(-5.0, 6.0, -7.0), Vector3(0.0, 2.6, -4.2), 30.0)

	# THE MOVING PARTS. A suite can hold every angle to a hundredth of a degree and say nothing about whether a
	# deflected surface reads as a deflected surface, or whether an open canopy looks like a Phantom's. `lane/harrier`
	# proved nine green checks on nozzles nobody could see.
	await _posed("phantom-13-landing-configuration.png", Vector3(-14.0, 3.2, -14.0), Vector3(0.0, 1.6, -0.5), 36.0,
		{"slats": 1.0, "flaps": 1.0}, "slats and flaps fully out")
	await _posed("phantom-14-canopies-open.png", Vector3(-7.0, 4.6, -8.5), Vector3(0.0, 2.7, -4.6), 32.0,
		{"canopies": 1.0}, "both canopies open")
	await _posed("phantom-15-stick-right.png", Vector3(0.0, 13.0, -6.0), Vector3(0.0, 1.5, 0.5), 40.0,
		{"stick": Vector2(1.0, 0.0)}, "stick hard right: starboard aileron up, port down, stabilators differential")
	await _posed("phantom-16-stick-back-and-rudder.png", Vector3(9.0, 4.0, 13.0), Vector3(0.0, 2.2, 5.0), 34.0,
		{"stick": Vector2(0.0, 1.0), "yaw": 1.0}, "stick back and right pedal")
	await _posed("phantom-17-nozzles-in-afterburner.png", Vector3(4.0, 2.2, 10.5), Vector3(0.0, 1.7, 5.5), 30.0,
		{"nozzle": 1.0}, "nozzles fully open")

	await _orthographic("phantom-10-side-at-100.42-px-per-m.png", Vector2i(2100, 900),
		Vector3(-60.0, 0.0, 0.0), Vector3.UP, SIDE_PX_PER_METRE)
	await _orthographic("phantom-11-top-at-100.26-px-per-m.png", Vector2i(2100, 1400),
		Vector3(0.0, 60.0, 0.0), Vector3.RIGHT, PLAN_PX_PER_METRE)
	await _orthographic("phantom-12-front-at-101.54-px-per-m.png", Vector2i(1400, 900),
		Vector3(0.0, 0.0, -60.0), Vector3.UP, FRONT_PX_PER_METRE)

	print("[phantom_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL", out])
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


func _lit(filename: String, from: Vector3, target: Vector3, fov: float) -> void:
	var stage := _stage(Vector2i(1600, 900), Color(0.58, 0.66, 0.74), Color(0.66, 0.70, 0.76), 0.85)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.85, -0.7, 0.0)
	light.light_energy = 1.3
	light.shadow_enabled = true
	stage.add_child(light)
	var frame := PhantomAirframe.new()
	frame.dress()
	stage.add_child(frame)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90.0, 90.0)
	ground.mesh = plane
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.45, 0.45, 0.43)
	ground.material_override = concrete
	ground.position.y = frame.point(0.0, 0.0, 0.0).y
	stage.add_child(ground)
	var label := Label.new()
	label.text = "F-4E Phantom II  gear down, surfaces neutral"
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


## ONE LIT VIEW WITH THE AEROPLANE POSED. `pose` names the setters by their own names, so a picture asks the airframe
## for exactly what the suite asks it for and the two cannot drift apart.
func _posed(filename: String, from: Vector3, target: Vector3, fov: float, pose: Dictionary, said: String) -> void:
	var stage := _stage(Vector2i(1600, 900), Color(0.58, 0.66, 0.74), Color(0.66, 0.70, 0.76), 0.85)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.85, -0.7, 0.0)
	light.light_energy = 1.3
	light.shadow_enabled = true
	stage.add_child(light)
	var frame := PhantomAirframe.new()
	frame.dress()
	stage.add_child(frame)
	frame.set_slats(float(pose.get("slats", 0.0)))
	frame.set_flaps(float(pose.get("flaps", 0.0)))
	frame.set_canopies(float(pose.get("canopies", 0.0)))
	frame.set_nozzle(float(pose.get("nozzle", 0.0)))
	frame.follow_the_stick(pose.get("stick", Vector2.ZERO) as Vector2, float(pose.get("yaw", 0.0)))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90.0, 90.0)
	ground.mesh = plane
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.45, 0.45, 0.43)
	ground.material_override = concrete
	ground.position.y = frame.point(0.0, 0.0, 0.0).y
	stage.add_child(ground)
	var label := Label.new()
	label.text = "F-4E Phantom II  " + said
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


## ONE ORTHOGRAPHIC VIEW at `px_per_metre`, flat and unshaded, so it can be laid over [TO] at x1.000 with no
## fitting. The scale is a parameter and not a constant because this sheet's three views do not share one.
func _orthographic(filename: String, size: Vector2i, from: Vector3, up: Vector3, px_per_metre: float) -> void:
	var stage := _stage(size, Color.WHITE, Color.WHITE, 1.0)
	var frame := PhantomAirframe.new()
	frame.dress()
	stage.add_child(frame)
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
	camera.size = float(size.x) / px_per_metre
	camera.near = 0.05
	camera.far = 200.0
	camera.current = true
	stage.add_child(camera)
	camera.global_position = from
	camera.look_at(Vector3.ZERO, up)
	await _save(stage, filename)


func _save(stage: SubViewport, filename: String) -> void:
	for _f in range(4):
		await RenderingServer.frame_post_draw
	var path := out.path_join(filename)
	var error := stage.get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(filename)
	print("[phantom_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
	stage.queue_free()
