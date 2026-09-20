extends Node3D
## A REEL OF THE LITTLE BIRD TAKING OFF, FLYING A 500 ft HELICOPTER PATTERN, AND LANDING.
##
##   <editor>.console.exe --path cockpit --xr-mode off --desktop-only --resolution 1600x900 \
##       --write-movie <out.avi> --fixed-fps 30 res://tests/littlebird_circuit_reel.tscn -- --out=<folder>
##
## The same `LittleBirdCircuitPilot` as `tests/littlebird_circuit.gd`. MovieWriter records
## this viewport, never the desktop.

const TICK: float = 1.0 / 120.0
const CLIENT: int = 60
const KIND: int = Sim.Kind.LITTLEBIRD
const MOST_SECONDS: float = 280.0
const TICKS_PER_FRAME: int = 8
const STILLS: Array = [
	[10.0, "takeoff"],
	[55.0, "crosswind"],
	[110.0, "downwind"],
	[170.0, "final"],
	[230.0, "landing"],
]

var out := ""
var _world: Object
var _pilot_id: int = 0
var _craft: int = 0
var _hands: LittleBirdCircuitPilot
var _hy: float = 1.3
var _t: float = 0.0
var _input: Dictionary = {}
var _frame: LittleBirdAirframe = null
var _camera: Camera3D = null
var _caption: Label = null
var _stills_taken: int = 0
var _failures: PackedStringArray = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	if DisplayServer.get_name() == "headless":
		print("[littlebird_circuit_reel] RESULT=FAIL headless has no rendering device")
		get_tree().quit(1)
		return
	_stage()
	_hy = float((Sim.geometry_of(KIND).get("extents", Vector3.ONE) as Vector3).y)
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(8000.0, 400.0, 8000.0))
	TuningCard.from_command_line().apply_to(_world, KIND)
	var made: Dictionary = _world.spawn_pilot(CLIENT, KIND, Vector3(0.0, _hy + 0.08, 320.0), 0.0, Vector3.ZERO)
	_craft = int(made.get("vehicle", 0))
	_pilot_id = int(made.get("pilot", 0))
	_hands = LittleBirdCircuitPilot.new()
	_hands.begin(_world.handling(KIND), _hy, 0.0)
	_input = {"throttle": LittleBirdCircuitPilot.IDLE, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0}
	BuildStamp.attach_to.call_deferred(get_viewport())


func _stage() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.56, 0.68, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.74, 0.80)
	env.ambient_light_energy = 0.8
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, -0.6, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	for piece in [
		[Vector2(8000.0, 8000.0), Color(0.36, 0.44, 0.30), 0.0],
		[Vector2(45.0, 900.0), Color(0.34, 0.34, 0.33), 0.04],
		[Vector2(0.8, 900.0), Color(0.85, 0.85, 0.80), 0.05],
	]:
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = piece[0]
		ground.mesh = plane
		var paint := StandardMaterial3D.new()
		paint.albedo_color = piece[1]
		ground.material_override = paint
		ground.position = Vector3(0.0, float(piece[2]), 0.0)
		add_child(ground)
	_frame = LittleBirdAirframe.new()
	_frame.dress(Sim.geometry_of(KIND))
	add_child(_frame)
	_camera = Camera3D.new()
	_camera.fov = 48.0
	_camera.far = 4000.0
	add_child(_camera)
	_camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 26)
	_caption.add_theme_color_override("font_color", Color(0.04, 0.05, 0.08))
	_caption.position = Vector2(24, 18)
	layer.add_child(_caption)


func _process(_delta: float) -> void:
	if _world == null:
		return
	for _n in range(TICKS_PER_FRAME):
		var r: Dictionary = _read()
		_input = _hands.step(r, TICK)
		_world.set_pilot_input(_pilot_id, _input)
		_world.tick(TICK)
		_t += TICK
	_draw()
	if _stills_taken < STILLS.size() and _t >= float(STILLS[_stills_taken][0]):
		_still(String(STILLS[_stills_taken][1]))
		_stills_taken += 1
	if _hands.landed or _t >= MOST_SECONDS:
		var r: Dictionary = _read()
		var at: Vector3 = r["at"]
		print("[littlebird_circuit_reel] ended %.1f s leg %s at x %.0f z %.0f y %.1f speed %.1f landed %s" % [
			_t, _hands.leg, at.x, at.z, at.y, float(r["ground_speed"]), _hands.landed])
		if not _hands.lifted or not _hands.on_downwind or not _hands.landed:
			_failures.append("did not complete the circuit")
		_world.teardown()
		_world = null
		print("[littlebird_circuit_reel] RESULT=%s into %s" % [
			"PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures), out])
		get_tree().quit(0 if _failures.is_empty() else 1)


func _draw() -> void:
	var s: Dictionary = _world.vehicle_state(_craft)
	var basis := Basis(s.get("basis", Quaternion()) as Quaternion)
	var at: Vector3 = s.get("position", Vector3.ZERO)
	_frame.global_transform = Transform3D(basis, at)
	_frame.set_rotors(true, float(_input.get("throttle", 0.0)), _t)
	# Chase off the starboard quarter, looking at the nose -- the whole point is seeing it fly forward.
	var back: Vector3 = basis * Vector3(6.0, 3.5, 14.0)
	_camera.global_position = at + back
	_camera.look_at(at + basis * Vector3(0.0, 0.4, -4.0), Vector3.UP)
	var r: Dictionary = _read()
	_caption.text = "MH-6M  %5.1f s   %s   height %5.1f m AGL   speed %5.1f m/s   heading %5.0f" % [
		_t, _hands.leg, (r["at"] as Vector3).y - _hy, float(r["ground_speed"]), float(r["heading"])]


func _still(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = out.path_join("littlebird-circuit-%s.png" % name)
	if image.save_png(path) != OK:
		_failures.append(name)
	print("[littlebird_circuit_reel] saved %s" % path)


func _read() -> Dictionary:
	var s: Dictionary = _world.vehicle_state(_craft)
	var b := Basis(s.get("basis", Quaternion()) as Quaternion)
	var nose: Vector3 = b * Vector3.FORWARD
	var right: Vector3 = b * Vector3.RIGHT
	var v: Vector3 = s.get("velocity", Vector3.ZERO)
	var flat := Vector3(v.x, 0.0, v.z)
	return {
		"at": s.get("position", Vector3.ZERO) as Vector3, "v": v, "along": v.dot(nose),
		"ground_speed": flat.length(), "vy": v.y, "side": v.dot(right), "up": (b * Vector3.UP).y,
		"pitch": rad_to_deg(asin(clampf(nose.y, -1.0, 1.0))),
		"bank": rad_to_deg(asin(clampf(-right.y, -1.0, 1.0))),
		"heading": rad_to_deg(atan2(-nose.x, -nose.z)),
	}
