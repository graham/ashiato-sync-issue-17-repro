extends Node3D
## Windowed visual evidence for the four warbirds' airframes, and the pictures a reader can DISPUTE.
##
##   <editor>.console.exe --path cockpit --xr-mode off res://tests/warbirds_shot.tscn -- --only=p51 --out=<folder>
##
## NOT HEADLESS -- headless has no rendering device. `tests/p51.gd` and its siblings hold everything about each aeroplane
## that can be asserted; this renders what a suite cannot see: does it READ as a Mustang, and do its gear, doors,
## surfaces and propeller look right part-way as well as at the ends. Every picture is a SubViewport of the probe's own,
## never the desktop.
##
## LIT VIEWS: the front and rear quarters, the side, from above and from below; each surface at its stop (roll, pitch,
## yaw, the flaps); the gear cycle as eight frames at fixed amounts, from low at the front quarter and from ahead; and
## THREE ORTHOGRAPHIC SILHOUETTES, gear down (or up, as its drawing draws it) and the propellers left out, at exactly its
## drawing's pixels a metre with the airframe's datum at the picture's middle (the P-51's and P-47's spinner tip, the
## P-38's gondola nose on its reference line), so `craft/<kind>/overlay_views.py` lays them over the three-view at x1.000 with no fitting.
##
## A SubViewport with its OWN World3D for each, because without it every stage shares the parent's world and each
## WorldEnvironment fights the others (`lane/prowler`). AMBIENT_SOURCE_COLOR reads `ambient_light_color`, which defaults to
## BLACK, so both are set.

const SILHOUETTE := Color(0.82, 0.16, 0.55)
## The gear frames, as amounts of the cycle from up (0) to down (1): the doors' share, the legs', the doors' again.
const GEAR_FRAMES: Array = [0.0, 0.1, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0]

## EACH WARBIRD: its class, the label burnt into its pictures, the prefix of its files, and its SILHOUETTES' SCALE in
## pixels a metre -- its drawing's plan scale, so the plan is laid at its own pixels and the other views are resampled to
## it (`craft/<kind>/overlay_views.py`).
const PLANES: Dictionary = {
	"p51": {"make": "P51", "label": "North American P-51D Mustang", "prefix": "warbirds-p51", "px": 123.88},
	"p47": {"make": "P47", "label": "Republic P-47D-30 Thunderbolt", "prefix": "warbirds-p47", "px": 116.00},
	"p38": {"make": "P38", "label": "Lockheed P-38L Lightning", "prefix": "warbirds-p38", "px": 94.07, "silhouette_gear": 0.0},
}

var out := ""
var only: PackedStringArray = []
var failures: PackedStringArray = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=").split(",")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	for key in PLANES:
		if only.is_empty() or only.has(key):
			await _pictures_of(PLANES[key])
	print("[warbirds_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL", out])
	get_tree().quit(0 if failures.is_empty() else 1)


static func _make(plan: Dictionary) -> WarbirdAirframe:
	match String(plan["make"]):
		"P51":
			return P51Airframe.new()
		"P47":
			return P47Airframe.new()
		"P38":
			return P38Airframe.new()
	return null


func _pictures_of(plan: Dictionary) -> void:
	var p: String = plan["prefix"]
	var probe := _make(plan)
	probe.dress()
	var half: Vector3 = probe.geometry()["extents"] as Vector3
	var span: float = float(probe.geometry()["span"])
	probe.free()
	var l: float = maxf(half.z, span * 0.5)
	var low: float = -half.y * 0.4
	await _lit(plan, p + "-01-front-quarter.png", Vector3(-l * 1.45, l * 0.45, -l * 1.6), Vector3(0.0, low, -half.z * 0.1), 36.0, {})
	await _lit(plan, p + "-02-rear-quarter.png", Vector3(l * 1.5, l * 0.55, l * 1.55), Vector3(0.0, low, half.z * 0.05), 36.0, {})
	await _lit(plan, p + "-03-side.png", Vector3(l * 2.9, 0.0, 0.0), Vector3(0.0, low * 0.5, 0.0), 38.0, {})
	await _lit(plan, p + "-04-from-above.png", Vector3(-l * 0.4, l * 2.9, l * 0.6), Vector3(0.0, 0.0, 0.1), 42.0, {})
	await _lit(plan, p + "-05-from-below-gear-up.png", Vector3(-l * 0.5, -l * 2.2, -l * 0.7), Vector3(0.0, -half.y * 0.3, 0.0),
		44.0, {"gear": 0.0}, true)
	await _lit(plan, p + "-06-nose-low-ahead.png", Vector3(-l * 0.35, -half.y * 0.55, -l * 1.5), Vector3(0.0, -half.y * 0.1, -half.z * 0.5), 34.0, {})
	# THE SURFACES FROM BEHIND AND ABOVE, where a trailing edge's travel shows: from the quarter, the first pictures of
	# the P-51's aileron and rudder read as neutral.
	await _lit(plan, p + "-07-roll-right.png", Vector3(-l * 0.2, l * 0.35, l * 1.9), Vector3(0.0, -half.y * 0.2, 0.0), 44.0, {"roll": 1.0})
	await _lit(plan, p + "-08-pitch-up.png", Vector3(-l * 0.9, l * 0.5, l * 1.6), Vector3(0.0, 0.0, half.z * 0.4), 34.0, {"pitch": 1.0})
	await _lit(plan, p + "-09-yaw-right.png", Vector3(-l * 0.05, l * 1.1, l * 1.5), Vector3(0.0, 0.0, half.z * 0.5), 30.0, {"yaw": 1.0})
	await _lit(plan, p + "-10-flaps-down.png", Vector3(-l * 1.0, l * 0.4, l * 1.7), Vector3(0.0, 0.0, half.z * 0.1), 40.0, {"flaps": 1.0})
	for amount in GEAR_FRAMES:
		await _lit(plan, p + "-12-gear-%03d.png" % int(round(amount * 100.0)), Vector3(-l * 1.2, -half.y * 0.55, -l * 0.9),
			Vector3(0.0, -half.y * 0.55, -half.z * 0.3), 40.0, {"gear": amount})
	for amount in GEAR_FRAMES:
		await _lit(plan, p + "-13-gear-ahead-%03d.png" % int(round(amount * 100.0)), Vector3(0.0, -half.y * 0.5, -l * 1.9),
			Vector3(0.0, -half.y * 0.6, 0.0), 30.0, {"gear": amount})
	# THE SILHOUETTES, each centred on the drawing's datum: the spinner's tip from the side and above, the propeller's
	# axis from ahead. The camera looks along the craft's axes from 60 m off, each view turned as the drawing turns it:
	# the side from PORT with the nose to the left, the plan nose left with starboard up, the front with starboard on the
	# viewer's left.
	var datum := Vector3.ZERO
	var probe2 := _make(plan)
	probe2.dress()
	datum = probe2.point(0.0, 0.0, 0.0)
	probe2.free()
	var reach: float = maxf(half.z, span * 0.5) * 2.0 + 2.0
	var px: float = float(plan["px"])
	await _orthographic(plan, p + "-20-side-at-drawing-scale.png", Vector2i(int(reach * 2.0 * px), int(8.0 * px)),
		datum + Vector3(-60.0, 0.0, 0.0), datum, Vector3.UP)
	await _orthographic(plan, p + "-21-top-at-drawing-scale.png", Vector2i(int(reach * 2.0 * px), int(reach * 2.0 * px)),
		datum + Vector3(0.0, 60.0, 0.0), datum, Vector3.RIGHT)
	await _orthographic(plan, p + "-22-front-at-drawing-scale.png", Vector2i(int(reach * 2.0 * px), int(8.0 * px)),
		datum + Vector3(0.0, 0.0, -60.0), datum, Vector3.UP)


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


## A LIT VIEW from `from` looking at `target`, parked (`parked()`) on a plain ground its tyres stand on, the airframe posed by `pose`
## (`gear`, `roll`, `pitch`, `yaw`, `flaps`). `from_below` lights it from underneath too and leaves the ground out.
func _lit(plan: Dictionary, filename: String, from: Vector3, target: Vector3, fov: float, pose: Dictionary,
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
	var frame := _make(plan)
	frame.dress()
	stage.add_child(frame)
	# PARKED AS IT PARKS: a taildragger tail down on its tail wheel. Built level, it sat on its mains with the tail wheel
	# in the air and read as floating. From below there is no ground, and it flies level.
	if not from_below:
		frame.transform = frame.parked()
	frame.set_gear(float(pose.get("gear", 1.0)))
	frame.set_ailerons(float(pose.get("roll", 0.0)))
	frame.set_elevators(float(pose.get("pitch", 0.0)))
	frame.set_rudders(float(pose.get("yaw", 0.0)))
	frame.set_flaps(float(pose.get("flaps", 0.0)))
	frame.set_props(0.125)
	if not from_below:
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(120.0, 120.0)
		ground.mesh = plane
		var concrete := StandardMaterial3D.new()
		concrete.albedo_color = Color(0.45, 0.45, 0.43)
		ground.material_override = concrete
		ground.position.y = -(frame.geometry()["extents"] as Vector3).y
		stage.add_child(ground)
	var label := Label.new()
	label.text = String(plan["label"]) + "  " + ", ".join(_said(pose))
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
	if pose.has("roll"):
		said.append("stick full right: right aileron up, left down")
	if pose.has("pitch"):
		said.append("stick full back: elevators up")
	if pose.has("yaw"):
		said.append("right pedal: rudder right")
	if pose.has("flaps"):
		said.append("flaps fully down")
	if said.is_empty():
		said.append("gear down, everything neutral")
	return said


## ONE ORTHOGRAPHIC VIEW at the plane's `px`, flat and unshaded, gear down (up where the drawing draws it dashed, the
## plane's `silhouette_gear`), the propeller left out (where a blade stands is where the draughtsman stopped it,
## lane/osprey), looking at `target` from `from`.
func _orthographic(plan: Dictionary, filename: String, size: Vector2i, from: Vector3, target: Vector3, up: Vector3) -> void:
	var stage := _stage(size, Color.WHITE, Color.WHITE, 1.0)
	var frame := _make(plan)
	frame.dress()
	stage.add_child(frame)
	frame.set_gear(float(plan.get("silhouette_gear", 1.0)))
	var flat := StandardMaterial3D.new()
	flat.albedo_color = SILHOUETTE
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for node in frame.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if String(mesh.name).begins_with("Propeller"):
			mesh.visible = false
		mesh.material_override = flat
		for s in range(mesh.get_surface_override_material_count()):
			mesh.set_surface_override_material(s, null)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = float(size.x) / float(plan["px"])
	camera.near = 0.05
	camera.far = 200.0
	camera.current = true
	stage.add_child(camera)
	camera.global_position = from
	camera.look_at(target, up)
	await _save(stage, filename)


func _save(stage: SubViewport, filename: String) -> void:
	for frame in range(4):
		await RenderingServer.frame_post_draw
	var path := out.path_join(filename)
	var error := stage.get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(filename)
	print("[warbirds_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
	stage.queue_free()
