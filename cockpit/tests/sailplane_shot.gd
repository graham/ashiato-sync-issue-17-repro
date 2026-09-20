extends Node3D
## Windowed visual evidence for the Duo Discus airframe, and the pictures a reader can DISPUTE.
##
##   Godot --path cockpit res://tests/sailplane_shot.tscn --xr-mode off -- --out=<folder>
##
## NOT HEADLESS -- headless has no rendering device. `tests/sailplane.gd` holds everything about this aeroplane that can
## be asserted; this renders what a suite cannot see: does it READ as a modern two-seat sailplane.
##
## LIT VIEWS in a sky of their own: the front quarter from above, the side, the top, the aeroplane banked 35 degrees with
## the stick over and the ailerons seen to move, the rear quarter with the stick back, right rudder and the airbrakes out,
## and the canopy close. And THREE ORTHOGRAPHIC SILHOUETTES at exactly `PX_PER_METRE`, the scale the three-view it was
## measured from reads at 300 dpi (132.95 px a metre, `craft/glider/measure_duo.py`), so the overlay lays them over that
## drawing at x1.000 with no fitting. The drawing itself is never in the repository.
##
## AND THE CREW, as the game builds the craft (`craft_glider.tscn`, every station fitted): a head at each rig eye
## (`CockpitStation.EYE_HEIGHT` over the seat anchor) with shoulders under it, seen from outside through the canopy and
## cut away from starboard, and the view from each pilot's eye -- ahead over the nose, and down at the stick, pedals and
## airbrake lever. The heads are markers, not a body: nothing in the game draws the player.
##
## A SubViewport with its OWN World3D for each (`lane/prowler`); ambient colour and energy both set (`modelling_here.md`).

const PX_PER_METRE: float = 132.95
const SILHOUETTE := Color(0.82, 0.16, 0.55)
const SKY := Color(0.52, 0.66, 0.84)

var out := ""
var failures: PackedStringArray = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)

	await _lit("cockpit-sailplane-01-front-quarter.png", Vector3(-12.0, 5.5, -14.0), Vector3(0.0, 0.3, -1.0), 50.0, {})
	await _lit("cockpit-sailplane-02-side.png", Vector3(-26.0, 0.8, 0.0), Vector3(0.0, 0.5, 0.0), 26.0, {})
	await _lit("cockpit-sailplane-03-from-above.png", Vector3(0.0, 30.0, 4.0), Vector3(0.0, 0.0, -0.2), 42.0, {})
	await _lit("cockpit-sailplane-04-banked-35-stick-right.png", Vector3(-10.0, 3.0, -17.0), Vector3(0.0, 0.3, -1.0),
		50.0, {"bank": 35.0, "roll": 1.0})
	await _lit("cockpit-sailplane-05-rear-quarter-stick-back-right-rudder-airbrakes-out.png", Vector3(9.0, 4.5, 12.0),
		Vector3(0.0, 0.5, 1.0), 50.0, {"pitch": 1.0, "yaw": 1.0, "airbrakes": 1.0})
	await _lit("cockpit-sailplane-06-canopy-close.png", Vector3(-3.6, 1.2, -4.8), Vector3(0.0, 0.2, -2.3), 40.0, {})
	await _orthographic("cockpit-sailplane-07-side-at-132.95px-per-m.png", Vector2i(1300, 420), Vector3(-40.0, 0.0, 0.0),
		Vector3.UP)
	await _orthographic("cockpit-sailplane-08-front-at-132.95px-per-m.png", Vector2i(2760, 420), Vector3(0.0, 0.0, -40.0),
		Vector3.UP)
	await _orthographic("cockpit-sailplane-09-top-at-132.95px-per-m.png", Vector2i(2760, 1300), Vector3(0.0, 40.0, 0.0),
		Vector3.BACK)

	await _crew("cockpit-sailplane-10-both-pilots-through-the-canopy.png", "outside")
	await _crew("cockpit-sailplane-11-both-pilots-cut-away-from-starboard.png", "cutaway")
	await _crew("cockpit-sailplane-12-front-pilots-eye-ahead.png", "eye0")
	await _crew("cockpit-sailplane-13-front-pilots-eye-down-at-stick-pedals-airbrake.png", "down0")
	await _crew("cockpit-sailplane-14-back-pilots-eye-ahead-over-the-front-pilot.png", "eye1")
	await _crew("cockpit-sailplane-15-back-pilots-eye-down-at-stick-pedals-airbrake.png", "down1")
	print("[sailplane_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL", out])
	get_tree().quit(0 if failures.is_empty() else 1)


func _stage(size: Vector2i, background: Color, ambient: Color, energy: float) -> SubViewport:
	var stage := SubViewport.new()
	stage.size = size
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.own_world_3d = true
	stage.msaa_3d = Viewport.MSAA_4X
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


## A LIT VIEW in the sky from `from` looking at `target`. `pose` banks the aeroplane and moves its controls.
func _lit(filename: String, from: Vector3, target: Vector3, fov: float, pose: Dictionary) -> void:
	var stage := _stage(Vector2i(1600, 900), SKY, Color(0.70, 0.74, 0.80), 0.9)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.95, -0.6, 0.0)
	light.light_energy = 1.3
	stage.add_child(light)
	var frame := SailplaneAirframe.new()
	frame.dress()
	stage.add_child(frame)
	frame.rotation = Vector3(0.0, 0.0, -deg_to_rad(float(pose.get("bank", 0.0))))
	frame.set_ailerons(float(pose.get("roll", 0.0)))
	frame.set_elevator(float(pose.get("pitch", 0.0)))
	frame.set_rudder(float(pose.get("yaw", 0.0)))
	frame.set_airbrakes(float(pose.get("airbrakes", 0.0)))
	var camera := Camera3D.new()
	camera.fov = fov
	camera.current = true
	stage.add_child(camera)
	camera.global_position = from
	camera.look_at(target, Vector3.UP)
	await _save(stage, filename)


## ONE ORTHOGRAPHIC VIEW at PX_PER_METRE, flat and unshaded, centred on the craft's origin.
func _orthographic(filename: String, size: Vector2i, from: Vector3, up: Vector3) -> void:
	var stage := _stage(size, Color.WHITE, Color.WHITE, 1.0)
	var frame := SailplaneAirframe.new()
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
	camera.size = float(size.x) / PX_PER_METRE
	camera.near = 0.05
	camera.far = 200.0
	camera.current = true
	stage.add_child(camera)
	camera.global_position = from
	camera.look_at(Vector3.ZERO, up)
	await _save(stage, filename)


## THE CRAFT AS THE GAME BUILDS IT, both stations fitted, with a head and shoulders at each rig eye.
func _crew(filename: String, view_of: String) -> void:
	CockpitStation.use_saved_layouts = false
	var stage := _stage(Vector2i(1600, 900), SKY, Color(0.70, 0.74, 0.80), 0.9)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.95, -0.6, 0.0)
	light.light_energy = 1.3
	stage.add_child(light)
	var view := (load("res://objects/vehicles/craft_glider.tscn") as PackedScene).instantiate() as VehicleView
	stage.add_child(view)
	view._show_in_editor()
	var eyes: Array[Vector3] = []
	for seat in range(view.seats.size()):
		var anchor: Node3D = view.seat_anchor(seat)
		# In `eye*` views the pilot whose eye it is has no head drawn: the camera is inside it.
		if not (view_of.ends_with(str(seat)) and (view_of.begins_with("eye") or view_of.begins_with("down"))):
			_pilot(anchor)
		eyes.append(anchor.global_transform * Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0))
	var camera := Camera3D.new()
	camera.current = true
	stage.add_child(camera)
	var middle: Vector3 = (eyes[0] + eyes[eyes.size() - 1]) * 0.5
	match view_of:
		"outside":
			camera.fov = 34.0
			camera.global_position = middle + Vector3(3.0, 2.0, -3.4)
			camera.look_at(middle - Vector3(0.0, 0.25, 0.0), Vector3.UP)
		"cutaway":
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 4.2
			camera.global_position = Vector3(6.0, middle.y - 0.5, middle.z + 0.3)
			camera.look_at(Vector3(0.0, middle.y - 0.5, middle.z + 0.3), Vector3.UP)
			# THE CUT IS THE NEAR PLANE, 0.12 m to starboard of the centreline, as `chair_craft_shot`'s is.
			camera.near = 6.0 - 0.12
			camera.far = 30.0
		_:
			var seat: int = int(view_of.right(1))
			var anchor: Node3D = view.seat_anchor(seat)
			camera.fov = 90.0
			camera.near = 0.02
			camera.global_position = eyes[seat]
			if view_of.begins_with("eye"):
				camera.look_at(anchor.global_transform * Vector3(0.0, CockpitStation.EYE_HEIGHT - 0.35, -3.0), Vector3.UP)
			else:
				camera.look_at(anchor.global_transform * Vector3(0.0, 0.70, -0.55), Vector3.UP)
	await _save(stage, filename)


## A SEATED PILOT'S MARKER: a head at the rig's eye and the shoulders a neck under it. Not a body the game draws.
func _pilot(anchor: Node3D) -> void:
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
	head.position = Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.06)
	anchor.add_child(head)
	var suit := StandardMaterial3D.new()
	suit.albedo_color = Color(0.20, 0.30, 0.48)
	var torso := MeshInstance3D.new()
	torso.name = "ShouldersMarker"
	var box := BoxMesh.new()
	box.size = Vector3(0.40, 0.26, 0.22)
	torso.mesh = box
	torso.material_override = suit
	torso.position = Vector3(0.0, CockpitStation.EYE_HEIGHT - CockpitStation.NECK - 0.10, 0.08)
	anchor.add_child(torso)


func _save(stage: SubViewport, filename: String) -> void:
	for frame in range(4):
		await RenderingServer.frame_post_draw
	var path := out.path_join(filename)
	var error := stage.get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(filename)
	print("[sailplane_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
	stage.queue_free()
