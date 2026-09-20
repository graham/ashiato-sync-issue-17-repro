extends Node3D
## Windowed visual evidence for the EA-6B Prowler airframe, and the one picture a reader can DISPUTE.
##
##   tools\gate_run.ps1 -Probe prowler_shot
##
## NOT HEADLESS -- headless has no rendering device, so the file comes back a black rectangle or the run hangs waiting
## for a frame that never draws. `tests/prowler.gd` holds everything about this aeroplane that can be asserted; this
## renders what a suite cannot see.
##
## IT DRAWS THE ORTHOGRAPHIC VIEWS AT THE SOURCE DRAWING'S OWN SCALE. The NAVAIR three-view this model is measured from
## is 1.4709 px an inch in its side view (`craft/prowler/sources.md`), which is 57.909 px a metre. Each orthographic
## view here is rendered into a SubViewport of a chosen pixel width with the camera's orthogonal width set to that width
## divided by 57.909, so the drawn aeroplane comes out at EXACTLY the drawing's scale and can be laid straight over it
## at x1.000 with no fitting. A picture somebody can argue with beats "it looks right".
##
## A SubViewport rather than the window, because the window's size is whatever the project and the desktop make it, and
## a scale that depends on that is not a scale.
##
## The model is drawn flat and unshaded for the three orthographic views -- a silhouette is what compares against a line
## drawing -- and lit for the three-quarter view, which is the one that answers "does this read as a Prowler".

## The source drawing's side view, px a metre. Changing this changes what the overlay means, so it is stated once.
const PX_PER_METRE: float = 57.909
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

	await _lit_three_quarter()
	await _lit_cockpit()
	await _pilot_eye(0, "cockpit-prowler-06-pilot-forward-view.png")
	await _pilot_eye(1, "cockpit-prowler-07-copilot-forward-view.png")
	# Side, front and top, each sized to hold the whole aeroplane at the drawing's scale with a little margin.
	await _orthographic("cockpit-prowler-02-side-at-sac-scale.png", Vector2i(1180, 460), Vector3(40.0, 0.0, 0.0), Vector3.UP)
	await _orthographic("cockpit-prowler-03-front-at-sac-scale.png", Vector2i(1060, 460), Vector3(0.0, 0.0, -40.0), Vector3.UP)
	await _orthographic("cockpit-prowler-04-top-at-sac-scale.png", Vector2i(1060, 1180), Vector3(0.0, 40.0, 0.0), Vector3.FORWARD)

	print("[prowler_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL", out])
	get_tree().quit(0 if failures.is_empty() else 1)


## THE ONE THAT ANSWERS "DOES IT READ AS A PROWLER": lit, from the front quarter and a little above, which is where the
## fin-tip fairing, the long canopy and the folding wing all show at once.
func _lit_three_quarter() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1280, 720)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# ITS OWN WORLD. Without this every stage here shares the parent's World3D, so all four aeroplanes stand in one
	# scene, each stage's WorldEnvironment fights the others, and the orthographic silhouettes came back on the lit
	# stage's blue-grey instead of white.
	stage.own_world_3d = true
	add_child(stage)
	# THE BUILD STAMP IN THE LOWER RIGHT, as in every picture the game takes (`BuildStamp`, 2026-09-18): this stage is a
	# viewport of its own, which the root's stamp is not drawn into.
	BuildStamp.attach_to(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.24, 0.28, 0.33)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# AMBIENT_SOURCE_COLOR reads `ambient_light_color`, which defaults to BLACK, so setting only the energy lights
	# nothing: the first three-quarter shot came back with an unlit fuselage against a lit wing.
	env.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_energy = 0.9
	environment.environment = env
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.75, -0.6, 0.0)
	light.light_energy = 1.5
	stage.add_child(light)
	var frame := _game_view(stage)
	var camera := Camera3D.new()
	camera.fov = 36
	camera.current = true
	stage.add_child(camera)
	camera.global_position = Vector3(10.5, 4.6, -17.3)
	camera.look_at(Vector3(0.0, 0.2, 0.0), Vector3.UP)
	await _save(stage, "cockpit-prowler-01-three-quarter.png")


## THROUGH THE GLASSHOUSE, because "transparent" is a visual claim and the whole four-seat arrangement must read in
## one image: both rows, the canopy bows and the green mission-display scale cues behind gold glass.
func _lit_cockpit() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1280, 720)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.own_world_3d = true
	add_child(stage)
	# THE BUILD STAMP IN THE LOWER RIGHT, as in every picture the game takes (`BuildStamp`, 2026-09-18): this stage is a
	# viewport of its own, which the root's stamp is not drawn into.
	BuildStamp.attach_to(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.13, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.74, 0.78, 0.84)
	env.ambient_light_energy = 1.25
	environment.environment = env
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.55, -0.8, 0.0)
	light.light_energy = 2.0
	stage.add_child(light)
	var frame := _game_view(stage)
	var camera := Camera3D.new()
	camera.fov = 34
	camera.current = true
	stage.add_child(camera)
	camera.global_position = Vector3(4.0, 2.4, -10.0)
	camera.look_at(Vector3(0.0, 0.55, -5.0), Vector3.UP)
	await _save(stage, "cockpit-prowler-05-glasshouse-and-four-crew.png")


## WHAT EACH FRONT-SEAT PLAYER ACTUALLY GETS. These use the same assembled VehicleView and authored stations as the
## game; the earlier exterior-only probe could not reveal either the opaque skin behind the glass or duplicate screens.
func _pilot_eye(seat: int, filename: String) -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1280, 720)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.own_world_3d = true
	add_child(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.48, 0.66, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.80, 0.84, 0.88)
	env.ambient_light_energy = 1.15
	environment.environment = env
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.65, -0.5, 0.0)
	light.light_energy = 1.4
	stage.add_child(light)
	var view := _game_view(stage)
	var anchor := view.seat_anchor(seat)
	var camera := Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.03
	camera.current = true
	stage.add_child(camera)
	camera.global_position = anchor.global_position + Vector3.UP * CockpitStation.EYE_HEIGHT
	camera.look_at(camera.global_position + Vector3.FORWARD * 20.0, Vector3.UP)
	await _save(stage, filename)


## ONE ORTHOGRAPHIC VIEW at the source drawing's scale. `size` is the viewport in pixels and `from` the direction the
## camera looks from; the camera's orthogonal WIDTH is the viewport's width divided by PX_PER_METRE, which is what makes
## the output directly comparable to the drawing.
func _orthographic(filename: String, size: Vector2i, from: Vector3, up: Vector3) -> void:
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
	env.background_color = Color.WHITE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	environment.environment = env
	stage.add_child(environment)
	var frame := _game_view(stage)
	# FLAT AND UNSHADED, so the picture is a silhouette to lay over a line drawing rather than a rendering to admire.
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


func _game_view(stage: Node) -> VehicleView:
	var view := (load("res://objects/vehicles/craft_prowler.tscn") as PackedScene).instantiate() as VehicleView
	stage.add_child(view)
	view.preview_kind = Sim.Kind.PROWLER
	view._show_in_editor()
	view._show_body(false)
	return view


func _save(stage: SubViewport, filename: String) -> void:
	for frame in range(3):
		await RenderingServer.frame_post_draw
	var path := out.path_join(filename)
	var error := stage.get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(filename)
	print("[prowler_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
