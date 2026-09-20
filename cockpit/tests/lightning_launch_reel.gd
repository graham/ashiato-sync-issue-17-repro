extends Node3D
## A SLOW REEL OF AN F-35B'S BAY LAUNCH: the doors swing open, the AMRAAM is pushed out and falls clear, its motor lights,
## and the doors shut -- from the real simulation, launched through a seated pilot's own frame (the selector, the master
## arm, LOCK and LAUNCH, as `tests/lightning_bays.gd` does it), and drawn at a QUARTER OF REAL SPEED: one 120 Hz tick of
## the world a 30 fps frame of the film.
##
##   <editor>.console.exe --path cockpit --xr-mode off --resolution 1600x900 --write-movie <out.avi> --fixed-fps 30
##       res://tests/lightning_launch_reel.tscn -- --out=<folder>
##
## Its own `CockpitWorld` and its own drawing, as `lightning_reel` is: the airframe where the world says, its bay doors
## eased toward the world's bits over `BAY_SECONDS` as `VehicleView` eases them, the stored missiles by `HungStores` from
## the kind's schema and the world's `stores`, and a missile in flight drawn with `HungStores`' own mesh and a plume while
## the WORLD says its motor burns. The camera rides the aeroplane, under its port side, looking at the bay. Every
## frame is this probe's viewport through MovieWriter, never the desktop. A caption says what the world says.

const TICK: float = 1.0 / 120.0
const CLIENT: int = 60
const BUTTON_LOCK: int = 1 << 6
const BUTTON_LAUNCH: int = 1 << 7
const LAUNCH_AT: float = 3.0
const END_AT: float = 8.5

var out := ""
var _world: Object = null
var _pilot: int = 0
var _craft: int = 0
var _t: float = 0.0
var _seq: int = 0
var _input: Dictionary = {}
var _frame: LightningAirframe = null
var _stores: HungStores = null
var _camera: Camera3D = null
var _caption: Label = null
var _bays_drawn: Array[float] = [0.0, 0.0]
var _flying: Dictionary = {}
var _mesh: ArrayMesh = null
var _plume: StandardMaterial3D = null
var _stills: Dictionary = {}
var _launched: float = -1.0
var _first_seen: float = -1.0
var _lit: float = -1.0
var _failures: PackedStringArray = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.67, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.75, 0.80)
	env.ambient_light_energy = 0.9
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, -0.5, 0.0)
	sun.light_energy = 1.2
	add_child(sun)
	var under := DirectionalLight3D.new()
	under.rotation = Vector3(0.9, 0.3, 0.0)
	under.light_energy = 0.6
	add_child(under)
	_frame = LightningAirframe.new()
	_frame.dress()
	add_child(_frame)
	_frame.set_gear(0.0)
	_stores = HungStores.new()
	_frame.add_child(_stores)
	var entry: Dictionary = VehicleCatalogue.CRAFT.get(Sim.Kind.LIGHTNING, {})
	_stores.fit(Sim.missile_schema(Sim.Kind.LIGHTNING), entry.get("store_pylons", {}))
	_mesh = HungStores.missile_mesh(HungStores.SHAPES["active radar"])
	_plume = StandardMaterial3D.new()
	_plume.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_plume.albedo_color = Color(1.0, 0.72, 0.30)
	_camera = Camera3D.new()
	_camera.fov = 62.0
	add_child(_camera)
	_camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 26)
	_caption.add_theme_color_override("font_color", Color(0.04, 0.05, 0.08))
	_caption.position = Vector2(24, 18)
	layer.add_child(_caption)
	BuildStamp.attach_to.call_deferred(get_viewport())
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	var made: Dictionary = _world.spawn_pilot(CLIENT, Sim.Kind.LIGHTNING, Vector3(0.0, 1500.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -150.0))
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_world.spawn_ai_vehicle(Sim.Kind.PLANE, Vector3(0.0, 1500.0, -1200.0), 0.0, Vector3(0.0, 0.0, -60.0))
	_input = {"throttle": 0.6, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0, "buttons": 0, "trigger": 0.0}
	_command(Sim.Channel.GEAR, 0)


func _process(_delta: float) -> void:
	if _world == null:
		return
	# ONE TICK A FRAME: a quarter of real speed at 30 fps. Before the launch, eight ticks a frame to get there.
	var ticks: int = 8 if _t < LAUNCH_AT - 1.0 else 1
	for i in range(ticks):
		_script()
		_hold_level()
		_world.set_pilot_input(_pilot, _input)
		_world.tick(TICK)
		_t += TICK
		_input["buttons"] = 0
	_draw(TICK * float(ticks))
	if _t >= END_AT:
		print("[lightning_launch_reel] launched %.2f, the missile appeared %.2f, lit %.2f" % [_launched, _first_seen, _lit])
		if _first_seen < 0.0 or _lit < 0.0:
			_failures.append("no launch filmed")
		_world.teardown()
		_world = null
		print("[lightning_launch_reel] RESULT=%s into %s" % ["PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures), out])
		get_tree().quit(0 if _failures.is_empty() else 1)


## THE PILOT'S HANDS: the radar station, the master arm, LOCK, and LAUNCH at LAUNCH_AT.
func _script() -> void:
	if absf(_t - 0.2) < TICK * 0.5:
		_command(Sim.Channel.WEAPON, 1)
	elif absf(_t - 0.5) < TICK * 0.5:
		_command(Sim.Channel.MASTER, 1)
	elif absf(_t - 0.8) < TICK * 0.5:
		_input["buttons"] = BUTTON_LOCK
	elif absf(_t - LAUNCH_AT) < TICK * 0.5:
		_input["buttons"] = BUTTON_LAUNCH
		_launched = _t


func _hold_level() -> void:
	var st: Dictionary = _world.vehicle_state(_craft)
	var basis := Basis(st["basis"] as Quaternion)
	var nose: Vector3 = basis * Vector3.FORWARD
	var right: Vector3 = basis * Vector3.RIGHT
	var v: Vector3 = st["velocity"]
	_input["pitch"] = clampf((-rad_to_deg(asin(clampf(nose.y, -1.0, 1.0))) - v.y * 0.5) * 0.05, -1.0, 1.0)
	_input["roll"] = clampf(rad_to_deg(asin(clampf(right.y, -1.0, 1.0))) * 0.05, -1.0, 1.0)


func _draw(delta: float) -> void:
	var st: Dictionary = _world.vehicle_state(_craft)
	var craft := Transform3D(Basis(st["basis"] as Quaternion), st["position"] as Vector3)
	_frame.global_transform = craft
	var systems: Dictionary = _world.craft_systems(_craft)
	var bays: int = int(systems.get("bays", 0))
	for index in range(2):
		var want: float = 1.0 if (bays >> index) & 1 == 1 else 0.0
		_bays_drawn[index] = move_toward(_bays_drawn[index], want, delta / LightningAirframe.BAY_SECONDS)
		_frame.set_bay(1.0 if index == 0 else -1.0, _bays_drawn[index])
	_stores.show_loaded(int(systems.get("stores", 0)))
	# THE MISSILE IN FLIGHT, where the world has it, with a plume while the world says its motor burns.
	var said: String = "in its bay"
	for m in _world.missile_states():
		var id: int = int(m["entity"])
		if not _flying.has(id):
			var body := MeshInstance3D.new()
			body.mesh = _mesh
			var paint := StandardMaterial3D.new()
			paint.vertex_color_use_as_albedo = true
			paint.vertex_color_is_srgb = true
			body.material_override = paint
			add_child(body)
			var plume := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.12
			cone.bottom_radius = 0.02
			cone.height = 3.0
			plume.mesh = cone
			plume.material_override = _plume
			body.add_child(plume)
			plume.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, 1.825 + 1.5))
			_flying[id] = {"body": body, "plume": plume}
			if _first_seen < 0.0:
				_first_seen = _t
		var drawn: Dictionary = _flying[id]
		var forward: Vector3 = (m.get("forward", Vector3.FORWARD) as Vector3)
		if forward.length_squared() < 0.001:
			forward = craft.basis * Vector3.FORWARD
		(drawn["body"] as Node3D).global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), m["position"] as Vector3)
		var motor: bool = bool(m["motor"])
		(drawn["plume"] as Node3D).visible = motor
		if motor and _lit < 0.0:
			_lit = _t
		var local: Vector3 = craft.affine_inverse() * (m["position"] as Vector3)
		said = "%s, %.1f m under the belly" % ["MOTOR LIT" if motor else "falling clear, unlit", _frame.point(0.0, 0.0, 0.0).y - local.y]
	# The camera: under the PORT side, where the first missile goes (the lowest loaded rail, pylon 2), a little aft of the bays, looking at them, riding the aeroplane.
	_camera.global_transform = craft * Transform3D(Basis.IDENTITY, Vector3(-3.6, -6.0, 5.4))
	_camera.look_at(craft * Vector3(-0.6, -2.4, 0.0), craft.basis * Vector3.UP)
	_caption.text = "F-35B bay launch, quarter speed   %4.2f s   bays %s   AMRAAM: %s" % [_t,
		["shut", "starboard open", "port open", "both open"][bays], said if _first_seen >= 0.0 else
		(("doors open, on its rail" if _bays_drawn.max() >= 1.0 else "doors opening") if bays != 0 else "in its bay")]
	for moment in [["doors-open", _launched + 0.95], ["pushed-out", _first_seen + 0.15], ["motor-lit", _lit + 0.1],
			["doors-shutting", _first_seen + 2.1]]:
		var label: String = moment[0]
		var when: float = float(moment[1])
		var base: float = [_launched, _first_seen, _lit, _first_seen][["doors-open", "pushed-out", "motor-lit", "doors-shutting"].find(label)]
		if base > 0.0 and _t >= when and not _stills.has(label):
			_stills[label] = true
			_still(label)


func _still(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = out.path_join("lightning-launch-%02d-%s.png" % [_stills.size(), label])
	if get_viewport().get_texture().get_image().save_png(path) != OK:
		_failures.append(label)
	print("[lightning_launch_reel] saved %s" % path)


func _command(channel: int, value: int) -> void:
	_seq = _seq % 3 + 1
	_input["command_channel"] = channel
	_input["command_value"] = value
	_input["command_seq"] = _seq
