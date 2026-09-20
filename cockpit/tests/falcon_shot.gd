extends Node3D
## Windowed visual evidence for the F-16A Block 15 airframe, and the pictures a reader can DISPUTE.
##
##   tools\gate_run.ps1 -Probe falcon_shot
##
## NOT HEADLESS -- headless has no rendering device, so the file comes back a black rectangle or the run hangs waiting
## for a frame that never draws. `tests/falcon.gd` holds everything about this aeroplane that can be asserted; this
## renders what a suite cannot see: does it READ as an F-16.
##
## FOUR LIT VIEWS: the front quarter from above, the chin intake from low ahead, the rear quarter with its ventral fins and
## nozzle, and the same rear quarter with the stick hard over, back and right rudder, so the three hinges are seen to
## move the right way. And THREE ORTHOGRAPHIC SILHOUETTES at exactly `PX_PER_METRE`, which is 8 px a drawing millimetre
## at the drawing's 1:100, so `craft/falcon/overlay_threeview.py` lays them over [CEL] at x1.000 with no fitting.
##
## A SubViewport with its OWN World3D for each, because without it every stage shares the parent's world and each
## WorldEnvironment fights the others (`lane/prowler`). AMBIENT_SOURCE_COLOR reads `ambient_light_color`, which defaults
## to BLACK, so both are set.

const PX_PER_METRE: float = 80.0
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

	await _lit("cockpit-falcon-01-front-quarter.png", Vector3(-11.5, 5.0, -13.5), Vector3(0.0, 0.2, -0.5), 38.0, false)
	await _lit("cockpit-falcon-02-chin-intake-low-ahead.png", Vector3(-4.2, -0.6, -12.5), Vector3(0.0, 0.2, -2.0), 36.0, false)
	await _lit("cockpit-falcon-03-rear-quarter.png", Vector3(10.5, 4.0, 13.5), Vector3(0.0, 0.4, 0.5), 38.0, false)
	await _lit("cockpit-falcon-04-rear-quarter-stick-right-back-right-rudder.png", Vector3(10.5, 4.0, 13.5),
		Vector3(0.0, 0.4, 0.5), 38.0, true)
	await _lit("cockpit-falcon-05-side-lit.png", Vector3(-24.0, 0.6, 0.0), Vector3(0.0, 0.6, 0.0), 40.0, false)
	await _orthographic("cockpit-falcon-06-side-at-80px-per-m.png", Vector2i(1400, 600), Vector3(-40.0, 0.0, 0.0), Vector3.UP)
	await _orthographic("cockpit-falcon-07-front-at-80px-per-m.png", Vector2i(900, 600), Vector3(0.0, 0.0, -40.0), Vector3.UP)
	await _orthographic("cockpit-falcon-08-top-at-80px-per-m.png", Vector2i(1400, 900), Vector3(0.0, 40.0, 0.0), Vector3.RIGHT)

	print("[falcon_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL", out])
	get_tree().quit(0 if failures.is_empty() else 1)


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


## A LIT VIEW from `from` looking at `target`, over a plain ground so the gear is seen to stand on something.
func _lit(filename: String, from: Vector3, target: Vector3, fov: float, deflected: bool) -> void:
	var stage := _stage(Vector2i(1600, 900), Color(0.58, 0.66, 0.74), Color(0.66, 0.70, 0.76), 0.85)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.85, -0.7, 0.0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	stage.add_child(light)
	var frame := FalconAirframe.new()
	frame.dress()
	stage.add_child(frame)
	if deflected:
		frame.set_flaperons(1.0)
		frame.set_stabilators(1.0)
		frame.set_rudder(1.0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	ground.mesh = plane
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.45, 0.45, 0.43)
	ground.material_override = concrete
	# On the ground the tyres stand on: the lowest drawn point, which is the box's bottom face.
	ground.position.y = -(Sim.geometry_of(Sim.Kind.FALCON)["extents"] as Vector3).y
	stage.add_child(ground)
	var camera := Camera3D.new()
	camera.fov = fov
	camera.current = true
	stage.add_child(camera)
	camera.global_position = from
	camera.look_at(target, Vector3.UP)
	await _save(stage, filename)


## ONE ORTHOGRAPHIC VIEW at PX_PER_METRE, flat and unshaded, centred on the craft's origin, so the overlay script can put
## the origin on the drawing without fitting anything.
func _orthographic(filename: String, size: Vector2i, from: Vector3, up: Vector3) -> void:
	var stage := _stage(size, Color.WHITE, Color.WHITE, 1.0)
	var frame := FalconAirframe.new()
	frame.dress()
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
	print("[falcon_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
	stage.queue_free()
