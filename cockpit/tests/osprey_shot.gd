extends Node3D
## Windowed visual evidence for the V-22, and the pictures a reader can DISPUTE.
##
##   <editor>.console.exe --path cockpit --xr-mode off res://tests/osprey_shot.tscn -- --out=<folder> [--only=before]
##
## NOT HEADLESS -- headless has no rendering device. `tests/osprey.gd` holds everything about this aircraft that can be
## asserted; this renders what a suite cannot see: does it READ as an MV-22B, and do its nacelles and proprotors look
## right part-way as well as at the ends. Every picture is a SubViewport of the probe's own, never the desktop.
##
## THE CRAFT VIEWS are `craft_osprey.tscn` as the game builds it, from three fixed cameras: `--only=before` takes only
## those, so a run on the old model before the change and one on the new model after are the same cameras on the same
## scene. THE POSES are the airframe at 0, 45 and 90 degrees with its proprotors turning. THE SILHOUETTES are orthographic,
## flat and unshaded, at the drawing's own scale for each view -- 77.63 px a metre for the sides, 78.26 for the fronts and
## plans (`craft/osprey/measure_views.py`) -- each with a second picture of the proprotors' discs alone, so
## `craft/osprey/overlay_views.py` can lay them over [JJ]'s six views at x1.000 and report the agreement with and without
## the discs, whose blades stand wherever the draughtsman stopped them.
##
## A SubViewport with its OWN World3D for each, because without it every stage shares the parent's world (`lane/prowler`).
## AMBIENT_SOURCE_COLOR reads `ambient_light_color`, which defaults to BLACK, so both are set.

const CRAFT := preload("res://objects/vehicles/craft_osprey.tscn")
## [JJ]'s scales: the sides' 1,357 px and the plans' 1,368 px for the published 17.48 m; the fronts share the plans'.
const SIDE_PX_PER_METRE: float = 1357.0 / 17.48
const PLAN_PX_PER_METRE: float = 1368.0 / 17.48
const SILHOUETTE := Color(0.82, 0.16, 0.55)
## The gear frames, as amounts of the cycle from up (0) to down (1): the doors' share, the legs', the doors' again.
const GEAR_FRAMES: Array = [0.0, 0.1, 0.2, 0.4, 0.6, 0.8, 0.9, 1.0]
const DISC := Color(0.10, 0.45, 0.85)

var out := ""
var only := ""
var failures: PackedStringArray = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)

	if only == "crowd":
		await _crowd()
		get_tree().quit(0)
		return
	var tag := "before" if only == "before" else "after"
	await _craft("osprey-%s-1-front-quarter.png" % tag, Vector3(-17.0, 6.0, -19.0), Vector3(0.0, 0.5, -1.0), 44.0)
	await _craft("osprey-%s-2-side.png" % tag, Vector3(-34.0, 1.5, 0.0), Vector3(0.0, 0.5, 0.0), 44.0)
	await _craft("osprey-%s-3-rear-quarter.png" % tag, Vector3(16.0, 5.0, 20.0), Vector3(0.0, 0.5, 1.0), 44.0)
	if only != "before":
		var travel_deg: float = rad_to_deg(OspreyAirframe.travel())
		for degrees in [0.0, 45.0, 90.0]:
			await _lit("osprey-04-nacelles-%02d-deg-rotors-turning.png" % int(degrees), Vector3(-19.0, 7.0, -17.0),
				Vector3(0.0, 1.0, 0.0), 46.0, {"tilt": degrees / travel_deg, "running": true, "seconds": 0.37})
		await _lit("osprey-05-helicopter-mode-parked-from-ahead.png", Vector3(0.0, 2.0, -30.0), Vector3(0.0, 1.5, 0.0),
			46.0, {"tilt": 90.0 / travel_deg})
		await _lit("osprey-06-aeroplane-mode-from-above.png", Vector3(-14.0, 20.0, 10.0), Vector3(0.0, 0.0, 0.0), 50.0,
			{"tilt": 0.0, "running": true, "seconds": 0.21})
		await _lit("osprey-07-flight-deck-close.png", Vector3(-4.5, 1.2, -12.0), Vector3(0.0, 0.3, -6.5), 40.0,
			{"tilt": 90.0 / travel_deg})
		await _lit("osprey-20-ramp-down-from-behind.png", Vector3(3.5, 0.3, 17.0), Vector3(0.0, -0.9, 5.0), 46.0,
			{"tilt": 90.0 / travel_deg, "ramp": 1.0})
		await _lit("osprey-21-ramp-shut-from-behind.png", Vector3(3.5, 0.3, 17.0), Vector3(0.0, -0.9, 5.0), 46.0,
			{"tilt": 90.0 / travel_deg, "ramp": 0.0})
		await _lit("osprey-22-ramp-half-way-from-the-side.png", Vector3(16.0, -0.4, 9.0), Vector3(0.0, -0.8, 4.5), 44.0,
			{"tilt": 90.0 / travel_deg, "ramp": 0.5})
		await _lit("osprey-23-crew-door-open.png", Vector3(7.5, 0.2, -8.5), Vector3(1.3, -0.6, -4.9), 38.0,
			{"tilt": 90.0 / travel_deg, "door": 1.0})
		for amount in GEAR_FRAMES:
			await _lit("osprey-24-gear-%03d.png" % int(round(amount * 100.0)), Vector3(6.5, -1.55, -9.5),
				Vector3(0.6, -1.35, -3.6), 50.0, {"tilt": 90.0 / travel_deg, "gear": amount})
		for seat in [0, 1]:
			await _eye("osprey-25-flight-deck-from-seat-%d.png" % seat, seat, 12.0)
			await _eye("osprey-26-panel-from-seat-%d.png" % seat, seat, 38.0)
		# THE SILHOUETTES, with the gear hidden: [JJ] draws it up.
		var heli: float = 90.0 / travel_deg
		await _orthographic("osprey-10-side-aeroplane", Vector2i(2000, 1300), Vector3(40.0, 0.0, 0.0), Vector3.UP,
			SIDE_PX_PER_METRE, 0.0)
		await _orthographic("osprey-11-side-helicopter", Vector2i(2000, 1300), Vector3(-40.0, 0.0, 0.0), Vector3.UP,
			SIDE_PX_PER_METRE, heli)
		await _orthographic("osprey-12-front-aeroplane", Vector2i(2200, 1300), Vector3(0.0, 0.0, -40.0), Vector3.UP,
			PLAN_PX_PER_METRE, 0.0)
		await _orthographic("osprey-13-front-helicopter", Vector2i(2200, 1300), Vector3(0.0, 0.0, -40.0), Vector3.UP,
			PLAN_PX_PER_METRE, heli)
		await _orthographic("osprey-14-plan-aeroplane", Vector2i(2000, 2300), Vector3(0.0, 40.0, 0.0), Vector3.LEFT,
			PLAN_PX_PER_METRE, 0.0)
		await _orthographic("osprey-15-plan-helicopter", Vector2i(2000, 2300), Vector3(0.0, 40.0, 0.0), Vector3.RIGHT,
			PLAN_PX_PER_METRE, heli)

	print("[osprey_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL", out])
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


func _ground(stage: SubViewport, at: float) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	ground.mesh = plane
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.45, 0.45, 0.43)
	ground.material_override = concrete
	ground.position.y = at
	stage.add_child(ground)


func _label(stage: SubViewport, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
	label.position = Vector2(24, 18)
	stage.add_child(label)


func _camera(stage: SubViewport, from: Vector3, target: Vector3, fov: float) -> void:
	var camera := Camera3D.new()
	camera.fov = fov
	camera.current = true
	stage.add_child(camera)
	camera.global_position = from
	camera.look_at(target, Vector3.UP)


func _sun(stage: SubViewport) -> void:
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.85, -0.7, 0.0)
	light.light_energy = 1.3
	light.shadow_enabled = true
	stage.add_child(light)


## THE CRAFT AS THE GAME BUILDS IT: `craft_osprey.tscn`, a VehicleView previewing the kind, over a ground at the
## collision box's floor -- which is where the physics puts the ground, whatever the model draws.
func _craft(filename: String, from: Vector3, target: Vector3, fov: float) -> void:
	var stage := _stage(Vector2i(1600, 900), Color(0.58, 0.66, 0.74), Color(0.66, 0.70, 0.76), 0.85)
	_sun(stage)
	var craft := CRAFT.instantiate()
	stage.add_child(craft)
	# The scene builds itself only in the editor (`preview_kind`); a running probe asks it as the game does.
	craft.call("setup", 0, Sim.Kind.OSPREY)
	var extents: Vector3 = Sim.geometry_of(Sim.Kind.OSPREY).get("extents", Vector3.ONE)
	_ground(stage, -extents.y)
	_label(stage, "V-22 (craft_osprey.tscn), ground at the collision box's floor, y = %.2f m" % -extents.y)
	_camera(stage, from, target, fov)
	await _save(stage, filename)


## THE AIRFRAME ON ITS OWN, posed: `tilt` 0 to 1 of the travel, the rotors `running` at `seconds` on the clock.
func _lit(filename: String, from: Vector3, target: Vector3, fov: float, pose: Dictionary) -> void:
	var stage := _stage(Vector2i(1600, 900), Color(0.58, 0.66, 0.74), Color(0.66, 0.70, 0.76), 0.85)
	_sun(stage)
	var frame := OspreyAirframe.new()
	frame.dress(Sim.geometry_of(Sim.Kind.OSPREY))
	stage.add_child(frame)
	frame.set_tilt(float(pose.get("tilt", 1.0)))
	frame.set_rotors(bool(pose.get("running", false)), 0.5, float(pose.get("seconds", 0.0)))
	frame.set_gear(float(pose.get("gear", 1.0)))
	frame.set_ramp(float(pose.get("ramp", 0.0)))
	frame.set_door(float(pose.get("door", 0.0)))
	_ground(stage, frame.point(0.0, OspreyAirframe.ground(), 0.0).y)
	var said: String = "MV-22B  nacelles %.1f deg%s" % [rad_to_deg(frame.tilt_angle()),
		", proprotors turning" if bool(pose.get("running", false)) else ", parked"]
	if pose.has("gear"):
		said += ", gear %.0f%% (0 up, 100 down)" % (float(pose["gear"]) * 100.0)
	if pose.has("ramp"):
		said += ", ramp %.0f%% open" % (float(pose["ramp"]) * 100.0)
	if pose.has("door"):
		said += ", crew door %.0f%% open" % (float(pose["door"]) * 100.0)
	_label(stage, said)
	_camera(stage, from, target, fov)
	await _save(stage, filename)


## THE FLIGHT DECK FROM A PILOT'S EYE: the game's own craft scene with every station manned, the camera at the seat's
## anchor plus `CockpitStation.EYE_HEIGHT`, looking ahead and `down` degrees below level: 12 for the view over the nose,
## 38 for the panel, whose screens stand below a 12-degree frame. Seat 0 is the pilot's, on the right.
func _eye(filename: String, seat: int, down: float) -> void:
	var stage := _stage(Vector2i(1600, 900), Color(0.58, 0.66, 0.74), Color(0.66, 0.70, 0.76), 0.85)
	_sun(stage)
	var craft := CRAFT.instantiate() as VehicleView
	stage.add_child(craft)
	craft.setup(0, Sim.Kind.OSPREY)
	craft.man([0, 1, 2, 3], seat)
	var extents: Vector3 = Sim.geometry_of(Sim.Kind.OSPREY).get("extents", Vector3.ONE)
	_ground(stage, -extents.y)
	var anchor: Node3D = craft.seat_anchor(seat)
	var eye: Vector3 = anchor.position + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
	_label(stage, "MV-22B flight deck from seat %d (%s), eye %.2f m over the belly, looking %.0f degrees down" % [seat,
		"the pilot's, on the right" if seat == 0 else "the copilot's, on the left",
		eye.y + extents.y - OspreyAirframe.CLEARANCE, down])
	var camera := Camera3D.new()
	camera.fov = 80.0
	camera.near = 0.05
	camera.current = true
	stage.add_child(camera)
	camera.position = eye
	camera.rotation = Vector3(deg_to_rad(-down), 0.0, 0.0)
	await _save(stage, filename)


## A STOPWATCH ON A HUNDRED OSPREYS, the per-frame work the V-22 added to every instance: each view handed its bus every
## frame (the nacelles, the gear and the ramp eased, the proprotors turned, the VAT's uniforms set), with the rotors
## running and then parked, A B A B, 240 frames each. Printed, not asserted: team-lead asked for a stopwatch figure.
func _crowd() -> void:
	var stage := _stage(Vector2i(1280, 720), Color(0.58, 0.66, 0.74), Color(0.66, 0.70, 0.76), 0.85)
	_sun(stage)
	var views: Array = []
	for i in range(100):
		var craft := CRAFT.instantiate() as VehicleView
		stage.add_child(craft)
		craft.setup(0, Sim.Kind.OSPREY)
		craft.position = Vector3(float(i % 10) * 30.0 - 135.0, 0.0, -float(i / 10) * 25.0 - 20.0)
		views.append(craft)
	var camera := Camera3D.new()
	camera.current = true
	stage.add_child(camera)
	camera.position = Vector3(0.0, 60.0, 60.0)
	camera.look_at(Vector3(0.0, 0.0, -130.0), Vector3.UP)
	for _i in range(120):
		await RenderingServer.frame_post_draw
	var bus: Dictionary = {"tilt": 0.6, "throttle": 0.5, "gear": true, "drop": false}
	for run in ["running", "parked", "running", "parked"]:
		var seated := PackedInt64Array([7]) if run == "running" else PackedInt64Array()
		var spent: int = 0
		var began: int = Time.get_ticks_usec()
		for frame in range(240):
			var t0: int = Time.get_ticks_usec()
			var seconds: float = float(frame) / 60.0
			for view in views:
				(view as VehicleView).draw_the_osprey_from(bus if run == "running" else {"tilt": 0.6, "throttle": 0.0},
					seated, Vector3.ZERO, 1.0 / 60.0, seconds)
			spent += Time.get_ticks_usec() - t0
			await RenderingServer.frame_post_draw
		var wall: float = float(Time.get_ticks_usec() - began) / 240.0 / 1000.0
		print("[osprey_shot] crowd of 100, rotors %s: %.3f ms a frame handing the views their buses, %.2f ms a frame in all"
			% [run, float(spent) / 240.0 / 1000.0, wall])
	print("[osprey_shot] RESULT=PASS crowd")


## ONE ORTHOGRAPHIC VIEW at `scale` px a metre, flat and unshaded, centred on the craft's origin, gear hidden, nacelles
## at `tilt`: `<name>.png` the airframe without its discs, `<name>-discs.png` the discs alone, same camera.
func _orthographic(name: String, size: Vector2i, from: Vector3, up: Vector3, scale: float, tilt: float) -> void:
	for discs in [false, true]:
		var stage := _stage(size, Color.WHITE, Color.WHITE, 1.0)
		var frame := OspreyAirframe.new()
		frame.dress(Sim.geometry_of(Sim.Kind.OSPREY))
		stage.add_child(frame)
		frame.set_tilt(tilt)
		frame.set_rotors(discs, 0.0, 0.0)
		var flat := StandardMaterial3D.new()
		flat.albedo_color = DISC if discs else SILHOUETTE
		flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flat.cull_mode = BaseMaterial3D.CULL_DISABLED
		for node in frame.find_children("*", "MeshInstance3D", true, false):
			var part := node as MeshInstance3D
			var is_disc: bool = OspreyAirframe.unpoured(part)
			var is_gear: bool = String(part.name).contains("Gear")
			part.visible = (is_disc if discs else not is_disc) and not is_gear
			part.material_override = flat
			for s in range(part.get_surface_override_material_count()):
				part.set_surface_override_material(s, null)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.size = float(size.x) / scale
		camera.near = 0.05
		camera.far = 200.0
		camera.current = true
		stage.add_child(camera)
		camera.global_position = from
		camera.look_at(Vector3.ZERO, up)
		await _save(stage, name + ("-discs.png" if discs else ".png"))


func _save(stage: SubViewport, filename: String) -> void:
	for frame in range(4):
		await RenderingServer.frame_post_draw
	var path := out.path_join(filename)
	var error := stage.get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(filename)
	print("[osprey_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
	stage.queue_free()
