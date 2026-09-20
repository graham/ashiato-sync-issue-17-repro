extends Node3D
## Windowed visual evidence for the airliners and the C-130, and the pictures a reader can DISPUTE.
##
##   <editor>.console.exe --path cockpit --xr-mode off res://tests/liners_shot.tscn -- --only=737 --out=<folder>
##   ... -- --only=lineup      the SCALE LINE-UP: the three beside a Super Hornet and a Cessna, as the game draws them
##
## NOT HEADLESS -- headless has no rendering device. `tests/airliners.gd` holds everything about these aeroplanes that can
## be asserted; this renders what a suite cannot see: does it READ as a 737, and do its gear, flaps and spoilers look right
## part-way as well as at the ends. Every picture is a SubViewport of the probe's own, never the desktop.
##
## LIT VIEWS: the front and rear quarters, the side, the belly from below, the landing configuration (flaps and spoilers
## out), and the gear cycle as frames at fixed amounts. And THREE ORTHOGRAPHIC SILHOUETTES at exactly the reference
## drawing's own scale, so `craft/airliner/overlay_views.py` lays them over Boeing's drawing at x1.000 with no fitting.
##
## A SubViewport with its OWN World3D for each, because without it every stage shares the parent's world and each
## WorldEnvironment fights the others (`lane/prowler`). AMBIENT_SOURCE_COLOR reads `ambient_light_color`, which defaults to
## BLACK, so both are set.

const SILHOUETTE := Color(0.82, 0.16, 0.55)
## The gear frames, as amounts of the cycle from up (0) to down (1): the doors' share, the legs', the doors' again.
const GEAR_FRAMES: Array = [0.0, 0.1, 0.2, 0.4, 0.6, 0.8, 0.9, 1.0]

## EACH AEROPLANE: its class, the label burnt into its pictures, and the reference drawing's scale in pixels a metre
## (`craft/airliner/measure_views.py`: 2,963 px for the printed 39.47 m; `craft/jumbo/measure_views.py`: 2,271 px for
## the printed 70.67 m; both at 600 dpi).
const PLANES: Dictionary = {
	"737": {"make": "Boeing737", "label": "Boeing 737-800W", "px_per_metre": 2963.0 / 39.47, "prefix": "liners-737"},
	"747": {"make": "Boeing747", "label": "Boeing 747-400", "px_per_metre": 2271.0 / 70.67, "prefix": "liners-747"},
	# THE C-130s' REFERENCE, Lockheed Martin's General Arrangement, is NOT at one scale (`craft/gunship/measure_views.py`):
	# its plan is 75.618 px a metre at 1200 dpi and its side and front 82.106. Each silhouette is rendered at its own view's,
	# of the airframe STRETCHED to the J-30 the drawing draws.
	"c130": {"make": "Hercules", "armed": false, "label": "Lockheed C-130H", "prefix": "liners-c130",
		"px": {"side": 82.106, "top": 75.618, "front": 82.106}},
	"ac130": {"make": "Hercules", "armed": true, "label": "Lockheed AC-130U", "prefix": "liners-ac130",
		"px": {"side": 82.106, "top": 75.618, "front": 82.106}},
}

var out := ""
var failures: PackedStringArray = []


func _ready() -> void:
	var only: PackedStringArray = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
		elif argument.begins_with("--only="):
			only = argument.trim_prefix("--only=").split(",")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	for key in PLANES:
		if not only.is_empty() and not only.has(key):
			continue
		await _pictures_of(PLANES[key])
	if only.is_empty() or only.has("lineup"):
		await _lineup()
	print("[liners_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL", out])
	get_tree().quit(0 if failures.is_empty() else 1)


func _make(plan: Dictionary, stretched: bool = false) -> JetlinerAirframe:
	match String(plan["make"]):
		"Hercules":
			var h := HerculesAirframe.new()
			h.armed = bool(plan["armed"])
			h.stretched = stretched
			return h
		"Boeing737":
			return Boeing737Airframe.new()
		"Boeing747":
			return Boeing747Airframe.new()
	return null


func _pictures_of(plan: Dictionary) -> void:
	var p: String = plan["prefix"]
	var probe := _make(plan)
	probe.dress()
	var half: Vector3 = (probe.geometry()["extents"] as Vector3)
	var probe_span: float = float(probe.geometry()["span"])
	probe.free()
	var l: float = half.z
	await _lit(plan, p + "-01-front-quarter.png", Vector3(-l * 1.35, l * 0.42, -l * 1.55), Vector3(0.0, 0.0, -l * 0.08), 36.0, {})
	await _lit(plan, p + "-02-rear-quarter.png", Vector3(l * 1.4, l * 0.5, l * 1.5), Vector3(0.0, 0.5, l * 0.05), 36.0, {})
	await _lit(plan, p + "-03-side.png", Vector3(-l * 2.6, 0.5, 0.0), Vector3(0.0, 1.5, 0.0), 38.0, {})
	await _lit(plan, p + "-04-landing-configuration.png", Vector3(-l * 1.2, l * 0.35, l * 0.9), Vector3(0.0, 0.0, l * 0.1),
		40.0, {"flaps": 1.0, "spoilers": 1.0})
	await _lit(plan, p + "-05-belly-from-below.png", Vector3(-l * 0.6, -l * 0.55, -l * 0.9), Vector3(0.0, -1.0, 0.0), 46.0,
		{"gear": 1.0}, true)
	for amount in GEAR_FRAMES:
		await _lit(plan, p + "-06-gear-%03d.png" % int(round(amount * 100.0)), Vector3(-l * 1.3, -half.y + 1.4, -l * 0.55),
			Vector3(0.0, -half.y + 1.2, -l * 0.35), 40.0, {"gear": amount}, false, false)
	if String(plan["make"]) == "Hercules":
		await _lit(plan, p + "-10-ramp-open.png", Vector3(l * 0.7, 3.5, l * 1.75), Vector3(0.0, -1.2, l * 0.35), 38.0,
			{"ramp": 1.0})
		if bool(plan["armed"]):
			# FROM THE PORT REAR QUARTER, UNDER THE WING: the barrels point straight out to port, so a camera square to the
			# side sees three muzzles end-on, and the first build's pictures showed specks (2026-09-19). From aft and a little
			# below the wing all three stand out in profile against the ground.
			var gun_eye := Vector3(-l * 1.05, -half.y + 3.2, l * 1.05)
			var gun_look := Vector3(-2.5, -half.y + 1.9, -l * 0.1)
			await _lit(plan, p + "-11-guns-run-out.png", gun_eye, gun_look, 40.0, {"guns": 1.0})
			await _lit(plan, p + "-12-guns-stowed.png", gun_eye, gun_look, 40.0, {"guns": 0.0})
			await _lit(plan, p + "-13-port-rear-quarter.png", Vector3(-l * 1.4, l * 0.5, l * 1.5), Vector3(0.0, 0.5, l * 0.05),
				36.0, {"guns": 1.0})
	var scales: Dictionary = plan.get("px", {"side": plan.get("px_per_metre", 1.0), "top": plan.get("px_per_metre", 1.0),
		"front": plan.get("px_per_metre", 1.0)})
	var along: float = l * 2.0 + 6.0
	await _orthographic(plan, p + "-07-side-at-drawing-scale.png", Vector2i(int(along * float(scales["side"])),
		int(l * 1.5 * float(scales["side"]))), Vector3(-80.0, 0.0, 0.0), Vector3.UP, float(scales["side"]))
	# THE TOP VIEW IS AS TALL AS THE SPAN, not the length: a square frame cut the C-130's tips off (its span is 40.4 m
	# and its length 29.8), and the overlay read the cut as the model's.
	var span: float = float(probe_span) * 2.0 + 6.0
	await _orthographic(plan, p + "-08-top-at-drawing-scale.png", Vector2i(int(along * float(scales["top"])),
		int(maxf(along, span) * float(scales["top"]))), Vector3(0.0, 80.0, 0.0), Vector3.RIGHT, float(scales["top"]))
	await _orthographic(plan, p + "-09-front-at-drawing-scale.png", Vector2i(int(along * float(scales["front"])),
		int(l * 1.5 * float(scales["front"]))), Vector3(0.0, 0.0, -80.0), Vector3.UP, float(scales["front"]))


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


## A LIT VIEW from `from` looking at `target`, over a plain ground the gear stands on, the airframe posed by `pose`
## (`gear`, `flaps`, `spoilers`). `from_below` lights it from underneath too and leaves the ground out; `ground_under`
## false leaves it out of a gear frame, where an aeroplane on the ground with its legs half up is a picture of nothing.
func _lit(plan: Dictionary, filename: String, from: Vector3, target: Vector3, fov: float, pose: Dictionary,
		from_below: bool = false, ground_under: bool = true) -> void:
	var stage := _stage(Vector2i(1600, 900), Color(0.58, 0.66, 0.74), Color(0.66, 0.70, 0.76), 0.85)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.85, -0.7, 0.0)
	light.light_energy = 1.3
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 250.0
	stage.add_child(light)
	if from_below:
		var fill := DirectionalLight3D.new()
		fill.rotation = Vector3(0.9, 0.4, 0.0)
		fill.light_energy = 0.7
		stage.add_child(fill)
	var frame := _make(plan)
	frame.dress()
	stage.add_child(frame)
	frame.set_gear(float(pose.get("gear", 1.0)))
	frame.set_flaps(float(pose.get("flaps", 0.0)))
	frame.set_spoilers(float(pose.get("spoilers", 0.0)))
	frame.set_ramp(float(pose.get("ramp", 0.0)))
	if frame.has_method("set_guns"):
		frame.call("set_guns", float(pose.get("guns", 1.0)))
	if not from_below and ground_under:
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(800.0, 800.0)
		ground.mesh = plane
		var concrete := StandardMaterial3D.new()
		concrete.albedo_color = Color(0.45, 0.45, 0.43)
		ground.material_override = concrete
		ground.position.y = frame.point(0.0, 0.0, 0.0).y
		stage.add_child(ground)
	var label := Label.new()
	label.text = String(plan["label"]) + "  " + ", ".join(_said(pose))
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
	label.position = Vector2(24, 18)
	stage.add_child(label)
	var camera := Camera3D.new()
	camera.fov = fov
	camera.far = 2000.0
	camera.current = true
	stage.add_child(camera)
	camera.global_position = from
	camera.look_at(target, Vector3.UP)
	await _save(stage, filename)


static func _said(pose: Dictionary) -> PackedStringArray:
	var said: PackedStringArray = []
	if pose.has("gear"):
		said.append("gear %.0f%% (0 up, 100 down)" % (float(pose["gear"]) * 100.0))
	if pose.has("flaps"):
		said.append("flaps %.0f deg" % (float(pose["flaps"]) * rad_to_deg(JetlinerAirframe.FLAP_TRAVEL)))
	if pose.has("spoilers"):
		said.append("spoilers up")
	if pose.has("ramp"):
		said.append("ramp down, cargo door up")
	if pose.has("guns"):
		said.append("guns run out" if float(pose["guns"]) > 0.5 else "guns stowed")
	if said.is_empty():
		said.append("gear down, surfaces neutral")
	return said


## ONE ORTHOGRAPHIC VIEW at the drawing's scale, flat and unshaded, centred on the craft's origin, gear DOWN as the
## drawings draw it; a Hercules stretched to the J-30 its drawing draws.
func _orthographic(plan: Dictionary, filename: String, size: Vector2i, from: Vector3, up: Vector3,
		px_per_metre: float) -> void:
	var stage := _stage(size, Color.WHITE, Color.WHITE, 1.0)
	stage.msaa_3d = Viewport.MSAA_DISABLED
	var frame := _make(plan, true)
	frame.dress()
	stage.add_child(frame)
	frame.set_gear(1.0)
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
	camera.size = float(size.x) / px_per_metre
	camera.near = 0.05
	camera.far = 400.0
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
	print("[liners_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
	stage.queue_free()


## THE SCALE LINE-UP: the 747, the C-130 (the AC-130U), the 737, the Super Hornet and the Cessna side by side, noses on one
## line and wheels on one ground, each as `VehicleView` draws it in the game -- so the picture is the game's own scale and
## nothing laid out for it. The brief: "make sure you get the sizes of these craft right, scale is important".
const LINEUP: Array = [
	{"kind": Sim.Kind.JUMBO, "label": "Boeing 747-400"},
	{"kind": Sim.Kind.GUNSHIP, "label": "AC-130U"},
	{"kind": Sim.Kind.AIRLINER, "label": "Boeing 737-800W"},
	{"kind": Sim.Kind.FIGHTER, "label": "F/A-18F"},
	{"kind": Sim.Kind.CESSNA, "label": "Cessna"},
]


func _lineup() -> void:
	for view_name in ["front-quarter", "top", "nose-on"]:
		var stage := _stage(Vector2i(1920, 1080), Color(0.58, 0.66, 0.74), Color(0.66, 0.70, 0.76), 0.85)
		var light := DirectionalLight3D.new()
		light.rotation = Vector3(-0.85, -0.7, 0.0)
		light.light_energy = 1.3
		light.shadow_enabled = true
		light.directional_shadow_max_distance = 500.0
		stage.add_child(light)
		var x: float = 0.0
		var said: PackedStringArray = []
		for entry in LINEUP:
			var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
			stage.add_child(view)
			view.setup(0, int(entry["kind"]))
			var box := _drawn_box(view)
			# Wing tip to wing tip with 6 m between, the nose on z = 0 and the lowest drawn point on the ground.
			x += box.size.x * 0.5
			view.position = Vector3(x - box.get_center().x, -box.position.y, -box.position.z)
			var tag := Label3D.new()
			tag.text = "%s
%.1f m long, %.1f m span" % [entry["label"], box.size.z, box.size.x]
			tag.font_size = 160
			tag.pixel_size = 0.014
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.modulate = Color(0.05, 0.05, 0.08)
			tag.outline_size = 0
			tag.no_depth_test = true
			# AHEAD OF THE NOSES, in two rows, so the Cessna's and the Hornet's labels do not overlap each other or anyone's wing.
			tag.position = Vector3(x, 1.5, -8.0 - 12.0 * float(said.size() % 2))
			stage.add_child(tag)
			said.append("%s %.1f x %.1f" % [entry["label"], box.size.z, box.size.x])
			x += box.size.x * 0.5 + 6.0
		print("[liners_shot] lineup: %s" % ", ".join(said))
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(1200.0, 1200.0)
		ground.mesh = plane
		var concrete := StandardMaterial3D.new()
		concrete.albedo_color = Color(0.45, 0.45, 0.43)
		ground.material_override = concrete
		stage.add_child(ground)
		var camera := Camera3D.new()
		camera.far = 3000.0
		camera.current = true
		stage.add_child(camera)
		var middle := Vector3(x * 0.5, 0.0, 30.0)
		match view_name:
			"front-quarter":
				camera.fov = 40.0
				camera.global_position = Vector3(x * 0.5 - 70.0, 70.0, -150.0)
				camera.look_at(middle + Vector3(0.0, 0.0, -5.0), Vector3.UP)
			"top":
				camera.projection = Camera3D.PROJECTION_ORTHOGONAL
				camera.keep_aspect = Camera3D.KEEP_WIDTH
				camera.size = x + 10.0
				camera.global_position = Vector3(x * 0.5, 300.0, 28.0)
				camera.look_at(Vector3(x * 0.5, 0.0, 28.0), Vector3.FORWARD)
			"nose-on":
				camera.projection = Camera3D.PROJECTION_ORTHOGONAL
				camera.keep_aspect = Camera3D.KEEP_WIDTH
				camera.size = x + 10.0
				camera.global_position = Vector3(x * 0.5, 16.0, -300.0)
				camera.look_at(Vector3(x * 0.5, 16.0, 0.0), Vector3.UP)
		await _save(stage, "liners-lineup-%s.png" % view_name)


## The box round every MeshInstance3D under `root`, in the stage's frame.
static func _drawn_box(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var b: AABB = root.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
