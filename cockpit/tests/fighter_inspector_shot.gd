extends Node3D
## Windowed visual evidence for any craft's model contract and builder inspector.
##
##   Godot --path cockpit res://tests/fighter_inspector_shot.tscn -- --kind=fighter --gear=up --hook=down --tag=up
##
## `--gear=up|down` and `--hook=stowed|down` pose a visual scene that has `set_gear` and `set_hook` (the F/A-18F's does), and
## `--tag` names the pictures apart. `--ortho` also draws side, front and top views ORTHOGRAPHIC at ORTHO_PIXELS_PER_METRE
## with the model's origin at the picture's centre, so a reference three-view scaled to the same pixels per metre lays
## straight over them. NOT headless; RESULT= is only whether every picture saved.

## One scale for every orthographic picture, so a reference drawing is scaled once.
const ORTHO_PIXELS_PER_METRE := 40.0

var out := ""
var camera: Camera3D
var fighter: VehicleView
var inspector: ModelInspector
var failures: PackedStringArray = []
var kind: int = Sim.Kind.FIGHTER
var kind_name := "fighter"
var tag := ""
var ortho := false
## `--measure`: THE CRAFT'S COST in this bare room, where nothing else changes between frames: draw calls, primitives and
## the viewport's CPU and GPU render time averaged over MEASURED_FRAMES with it shown and hidden, from the exterior pose. In
## the flight level the same subtraction read -10 draw calls, because the world's own draws move from frame to frame.
var measure := false
const MEASURED_FRAMES := 120


func _ready() -> void:
	var gear := ""
	var hook := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--kind="): kind_name = argument.trim_prefix("--kind=").to_lower()
		elif argument.begins_with("--gear="): gear = argument.trim_prefix("--gear=")
		elif argument.begins_with("--hook="): hook = argument.trim_prefix("--hook=")
		elif argument.begins_with("--tag="): tag = "-" + argument.trim_prefix("--tag=")
		elif argument == "--ortho": ortho = true
		elif argument == "--measure": measure = true
	for candidate in range(Sim.Kind.size()):
		if Sim.kind_name(candidate) == kind_name: kind = candidate
	if out.is_empty(): out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	var environment := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.24,0.28,0.33)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_energy = 1.1
	# A GREY AMBIENT, so a face turned from the light reads as shape and not as a black hole in the picture.
	env.ambient_light_color = Color(0.55, 0.57, 0.60)
	environment.environment = env; add_child(environment)
	var light := DirectionalLight3D.new(); light.rotation = Vector3(-0.8,-0.55,0); light.light_energy=1.4; add_child(light)
	# THE FLOOR IS WHERE THE CRAFT RESTS: the native hull's half-height under its origin, as a parked craft stands.
	var rest: float = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y)
	var floor := MeshInstance3D.new(); var floor_mesh := BoxMesh.new(); floor_mesh.size=Vector3(36,0.15,36)
	floor.mesh=floor_mesh; floor.position=Vector3(0,-rest - 0.075,0); add_child(floor)
	var scene := load("res://objects/vehicles/craft_%s.tscn" % kind_name) as PackedScene
	if scene == null:
		print("[fighter_inspector_shot] RESULT=FAIL missing %s" % kind_name); get_tree().quit(1); return
	fighter=scene.instantiate() as VehicleView
	add_child(fighter); fighter.preview_kind=kind; fighter._show_in_editor(); fighter._show_body(false)
	var visual: Node3D = fighter._visual_scene
	if visual != null and visual.has_method("set_gear") and not gear.is_empty():
		visual.call("set_gear", 0.0 if gear == "up" else 1.0)
	if visual != null and visual.has_method("set_hook") and not hook.is_empty():
		visual.call("set_hook", 1.0 if hook == "down" else 0.0)
	inspector=ModelInspector.new(); add_child(inspector); inspector.inspect(fighter); inspector.show_overlays(false); inspector.show_interior(false)
	camera=Camera3D.new(); camera.fov=48; camera.current=true; add_child(camera)
	await _capture("%s%s-exterior.png" % [kind_name, tag], Vector3(14,7,18), Vector3(0,0,0))
	if measure:
		await _measure_cost()
	await _capture("%s%s-three-quarter-front.png" % [kind_name, tag], Vector3(-13,3.0,-16), Vector3(0,0.2,0))
	await _capture("%s%s-three-quarter-low.png" % [kind_name, tag], Vector3(9,-0.4,-11), Vector3(0,-0.2,1.5))
	await _capture("%s%s-cockpit-above.png" % [kind_name, tag], Vector3(2.2,4.2,-6.8), Vector3(0,1.4,-3.6))
	# THE LEX AND THE CARET INTAKE, close, from the port front quarter a little above and a little below the strake.
	await _capture("%s%s-lex-intake-above.png" % [kind_name, tag], Vector3(-6.5,3.2,-7.5), Vector3(-1.2,0.6,0.0))
	await _capture("%s%s-lex-intake-below.png" % [kind_name, tag], Vector3(-6.0,-0.3,-6.5), Vector3(-1.1,0.3,0.2))
	if ortho:
		floor.visible = false
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = get_viewport().get_visible_rect().size.y / ORTHO_PIXELS_PER_METRE
		await _capture("%s%s-ortho-side.png" % [kind_name, tag], Vector3(-40,0,0), Vector3(0,0,0))
		await _capture("%s%s-ortho-front.png" % [kind_name, tag], Vector3(0,0,-40), Vector3(0,0,0))
		await _capture("%s%s-ortho-top.png" % [kind_name, tag], Vector3(0,40,0), Vector3(0,0,0))
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		floor.visible = true
	inspector.show_overlays(true)
	await _capture("%s%s-inspector-side.png" % [kind_name, tag], Vector3(20,1.8,0), Vector3(0,0.7,0))
	await _capture("%s%s-inspector-front.png" % [kind_name, tag], Vector3(0,1.8,-22), Vector3(0,0.7,0))
	await _capture("%s%s-inspector-top.png" % [kind_name, tag], Vector3(0,26,0.5), Vector3(0,0,0))
	print("[fighter_inspector_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL", out])
	get_tree().quit(0 if failures.is_empty() else 1)


func _measure_cost() -> void:
	var viewport: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var shown: Dictionary = await _average(viewport)
	fighter.visible = false
	var hidden: Dictionary = await _average(viewport)
	fighter.visible = true
	print("[fighter_inspector_shot] COST %s from the exterior pose, %d frames: +%.0f draw calls, +%.0f primitives, +%.3f ms CPU, +%.3f ms GPU (shown %.0f / %.0f / %.3f / %.3f, hidden %.0f / %.0f / %.3f / %.3f)"
		% [kind_name, MEASURED_FRAMES, shown["draws"] - hidden["draws"], shown["primitives"] - hidden["primitives"],
			shown["cpu"] - hidden["cpu"], shown["gpu"] - hidden["gpu"], shown["draws"], shown["primitives"], shown["cpu"],
			shown["gpu"], hidden["draws"], hidden["primitives"], hidden["cpu"], hidden["gpu"]])


func _average(viewport: RID) -> Dictionary:
	for frame in range(10): await RenderingServer.frame_post_draw
	var sums := {"draws": 0.0, "primitives": 0.0, "cpu": 0.0, "gpu": 0.0}
	for frame in range(MEASURED_FRAMES):
		await RenderingServer.frame_post_draw
		sums["draws"] += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		sums["primitives"] += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		sums["cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(viewport)
		sums["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
	for key in sums: sums[key] = float(sums[key]) / MEASURED_FRAMES
	return sums


func _capture(filename: String, from: Vector3, at: Vector3) -> void:
	camera.global_position=from; camera.look_at(at, Vector3.FORWARD if absf(from.y-at.y)>20 else Vector3.UP)
	for frame in range(3): await RenderingServer.frame_post_draw
	var path := out.path_join(filename)
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK: failures.append(filename)
	print("[fighter_inspector_shot] %s %s" % ["saved" if error==OK else "FAILED", path])
