extends Node3D
## A REEL OF THE V-22 DOING WHAT A TILTROTOR IS FOR: parked with its nacelles up, straight up off the ground, a hover, the
## gear up, and the conversion -- the nacelles wound forward to the wing-borne aeroplane -- drawn from the real simulation,
## flown through a seated pilot's own control frame.
##
##   <editor>.console.exe --path cockpit --xr-mode off --resolution 1600x900 --write-movie <out.avi> --fixed-fps 30
##       res://tests/osprey_reel.tscn -- --out=<folder>
##
## `tests/lightning_reel.gd`'s shape, and for its reason: the fly bench hands a craft to the AUTOPILOT, which flies a
## tiltrotor as an aeroplane, and the conversion is the one thing this reel is about. So this probe runs its own
## `CockpitWorld` (a pilot spawned in the craft, `set_pilot_input` each tick, a bus command for the nacelles and the gear)
## and draws an `OspreyAirframe` where the world says the craft is: its nacelles from the world's tilt channel -- the lever
## times the kind's `vector_travel`, the same product `fly_tiltrotor` turns the thrust by -- its proprotors turning, and
## its gear eased toward the world's bit as `VehicleView` eases it. Every frame is this probe's own viewport:
## MovieWriter records the game's window, never the desktop.
##
## A caption burns in what the world says: the time, the nacelles' angle, the height, the climb and the speed, so a reader
## can check the picture against the numbers. STILLS at fixed moments go to `--out`.

const TICK: float = 1.0 / 120.0
const FRAME: float = 1.0 / 30.0
const GROUND_HALF: float = 40000.0
const CLIENT: int = 60
const K_PITCH: float = 2.5
const K_BANK: float = 2.5
const K_HEADING: float = 1.2
const HOVER_AT: float = 30.0
## THE SCRIPT, seconds from the start: power at 3, a hover at HOVER_AT, the gear up at 14, the nacelles wound from vertical
## to forward from 18 over CONVERSION_OVER seconds, and wing-borne to the end.
const LIFT_AT: float = 3.0
const GEAR_UP_AT: float = 14.0
const CONVERSION_AT: float = 18.0
const CONVERSION_OVER: float = 16.0
const END_AT: float = 44.0
## STILLS: [seconds, name].
const STILLS: Array = [[2.0, "parked-nacelles-up"], [7.0, "lifting-off"], [12.0, "hover"], [17.0, "hover-gear-up"],
	[23.0, "converting-60-deg"], [28.0, "converting-30-deg"], [42.0, "wing-borne"]]

var out := ""
var _world: Object = null
var _pilot: int = 0
var _craft: int = 0
var _h: Dictionary = {}
var _hy: float = 0.0
var _t: float = 0.0
var _seq: int = 0
var _input: Dictionary = {}
var _frame: OspreyAirframe = null
var _camera: Camera3D = null
var _caption: Label = null
var _gear_drawn: float = 1.0
var _gear_down: bool = true
var _mark := Vector3.ZERO
var _stills_taken: int = 0
var _failures: PackedStringArray = []
var _travel: float = 1.0
var _lowest_in_conversion: float = INF


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	_stage()
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(GROUND_HALF, 400.0, GROUND_HALF))
	_h = _world.handling(Sim.Kind.OSPREY)
	_travel = float(_h["vector_travel"])
	_hy = float((Sim.geometry_of(Sim.Kind.OSPREY).get("extents", Vector3.ONE) as Vector3).y)
	var made: Dictionary = _world.spawn_pilot(CLIENT, Sim.Kind.OSPREY, Vector3(0.0, _hy + 0.05, 0.0), 0.0, Vector3.ZERO)
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_input = {"throttle": 0.002, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0}
	_mark = _read()["at"]


## The ground, a runway strip, the light and the camera, in the probe's own world.
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
	for piece in [[Vector2(6000.0, 6000.0), Color(0.36, 0.44, 0.30), 0.0], [Vector2(40.0, 3000.0), Color(0.34, 0.34, 0.33), 0.02],
			[Vector2(1.0, 3000.0), Color(0.85, 0.85, 0.80), 0.03]]:
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = piece[0]
		ground.mesh = plane
		var paint := StandardMaterial3D.new()
		paint.albedo_color = piece[1]
		ground.material_override = paint
		ground.position = Vector3(0.0, float(piece[2]), -1200.0)
		add_child(ground)
	_frame = OspreyAirframe.new()
	_frame.dress(Sim.geometry_of(Sim.Kind.OSPREY))
	add_child(_frame)
	_camera = Camera3D.new()
	_camera.fov = 42.0
	_camera.far = 6000.0
	add_child(_camera)
	_camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 26)
	_caption.add_theme_color_override("font_color", Color(0.04, 0.05, 0.08))
	_caption.position = Vector2(24, 18)
	layer.add_child(_caption)
	# DEFERRED: the root is still setting up its children while this `_ready` runs ("Parent node is busy").
	BuildStamp.attach_to.call_deferred(get_viewport())


func _process(_delta: float) -> void:
	if _world == null:
		return
	# FOUR TICKS A FRAME: the world at 120 Hz, the movie at 30.
	for i in range(4):
		_fly()
		_world.set_pilot_input(_pilot, _input)
		_world.tick(TICK)
		_t += TICK
	_draw()
	if _stills_taken < STILLS.size() and _t >= float(STILLS[_stills_taken][0]):
		_still(String(STILLS[_stills_taken][1]))
		_stills_taken += 1
	if _t >= END_AT:
		var r: Dictionary = _read()
		var tilt: float = float((_world.craft_controls(_craft) as Dictionary).get("tilt", -1.0))
		print("[osprey_reel] ended %.1f m up at %.1f m/s along the nose, nacelles %.1f deg; the lowest in the conversion %.1f m"
			% [(r["at"] as Vector3).y - _hy, float(r["along"]), rad_to_deg(tilt * _travel), _lowest_in_conversion])
		# WING-BORNE: the nacelles forward, going faster than the wing's stall, and never back on the ground on the way.
		if tilt > 0.02 or float(r["along"]) < 60.0 or _lowest_in_conversion < 5.0:
			_failures.append("not wing-borne at the end")
		_world.teardown()
		_world = null
		print("[osprey_reel] RESULT=%s into %s" % ["PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures), out])
		get_tree().quit(0 if _failures.is_empty() else 1)


## THE SCRIPT, as a pilot's hands.
func _fly() -> void:
	var r: Dictionary = _read()
	var at: Vector3 = r["at"]
	if _t < CONVERSION_AT:
		_command(Sim.Channel.TILT, _vertical_tilt())
	if _t < LIFT_AT:
		_input["throttle"] = 0.002
		return
	if _t >= GEAR_UP_AT and _gear_down:
		_command(Sim.Channel.GEAR, 0)
		_gear_down = false
		return
	if _t < CONVERSION_AT:
		var target: float = _mark.y + HOVER_AT
		var vy_to: float = clampf(0.6 * (target - at.y), -2.0, 3.0)
		_input["throttle"] = _collective(float(r["vy"]), vy_to)
		_hold_spot(r, Vector3(_mark.x, at.y, _mark.z))
		return
	# THE CONVERSION: the nacelles wound forward over CONVERSION_OVER seconds, full power, the height held on the stick.
	_lowest_in_conversion = minf(_lowest_in_conversion, at.y - _hy)
	var share: float = clampf((_t - CONVERSION_AT) / CONVERSION_OVER, 0.0, 1.0)
	_command(Sim.Channel.TILT, int(round(float(_vertical_tilt()) * (1.0 - share))))
	_input["throttle"] = 1.0
	_hands(r, clampf(0.25 * (_mark.y + HOVER_AT + 10.0 - at.y) - 1.2 * float(r["vy"]), -8.0, 10.0), 0.0)
	_input["rudder"] = 0.0


## THE DRAWING: the airframe where the world says, its nacelles from the world's lever, its proprotors turning on the
## clock, its gear eased as `VehicleView` eases it, and a chase camera off the starboard quarter.
func _draw() -> void:
	var s: Dictionary = _world.vehicle_state(_craft)
	var basis := Basis(s.get("basis", Quaternion()) as Quaternion)
	var at: Vector3 = s.get("position", Vector3.ZERO)
	_frame.global_transform = Transform3D(basis, at)
	var bus: Dictionary = _world.craft_controls(_craft)
	var tilt: float = float(bus.get("tilt", 0.0))
	_frame.set_tilt(tilt)
	var want: float = 1.0 if bool(bus.get("gear", true)) else 0.0
	_gear_drawn = move_toward(_gear_drawn, want, FRAME / OspreyAirframe.GEAR_SECONDS)
	_frame.set_gear(_gear_drawn)
	_frame.set_rotors(_t >= 1.0, float(_input.get("throttle", 0.0)), _t)
	# The camera: off the starboard quarter for the hover, then a chase off the starboard quarter aft that keeps up.
	var chase: float = clampf((_t - CONVERSION_AT) / 8.0, 0.0, 1.0)
	var off: Vector3 = Vector3(30.0, 5.0, 26.0).lerp(Vector3(24.0, 8.0, 46.0), chase)
	_camera.global_position = at + off
	_camera.look_at(at + Vector3(0.0, 1.0, -2.0), Vector3.UP)
	var r: Dictionary = _read()
	_caption.text = "MV-22B  %4.1f s   nacelles %4.1f deg   height %5.1f m   climb %+5.1f m/s   speed %5.1f m/s   gear %s" % [
		_t, rad_to_deg(tilt * _travel), (r["at"] as Vector3).y - _hy, float(r["vy"]), float(r["along"]),
		"down" if bool(bus.get("gear", true)) else "up"]


func _still(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = out.path_join("osprey-reel-%s.png" % name)
	if image.save_png(path) != OK:
		_failures.append(name)
	print("[osprey_reel] saved %s" % path)


# ---- the robot's hands, `tests/lightning_reel.gd`'s --------------------------------------------------------------------

## THE LEVER THAT STANDS THE NACELLES STRAIGHT UP: 90 degrees of the kind's `vector_travel`, as a byte on the tilt channel.
func _vertical_tilt() -> int:
	return int(round(255.0 * (PI * 0.5) / _travel))


func _collective(vy: float, vy_to: float) -> float:
	var hold: float = (1.0 - float(_h.get("hover", 0.0))) / maxf(float(_h.get("collective_range", 1.0)), 0.01)
	return clampf(hold + 0.25 * (vy_to - vy), 0.002, 1.0)


func _hold_spot(r: Dictionary, mark: Vector3) -> void:
	var at: Vector3 = r["at"]
	var v: Vector3 = r["v"]
	var basis: Basis = r["basis"]
	var to: Vector3 = Vector3(mark.x - at.x, 0.0, mark.z - at.z)
	var error: Vector3 = to.limit_length(8.0) * 0.4 - Vector3(v.x, 0.0, v.z)
	var forward: Vector3 = basis * Vector3.FORWARD
	var right: Vector3 = basis * Vector3.RIGHT
	var pitch_to: float = clampf(-error.dot(Vector3(forward.x, 0.0, forward.z).normalized()) * 2.0, -10.0, 10.0)
	var bank_to: float = clampf(error.dot(Vector3(right.x, 0.0, right.z).normalized()) * 2.0, -10.0, 10.0)
	_hands(r, pitch_to, bank_to)
	_input["rudder"] = clampf(-float(r["heading"]) * K_HEADING / 30.0, -1.0, 1.0)


func _hands(r: Dictionary, pitch_to: float, bank_to: float) -> void:
	var rates: Vector2 = Vector2(rad_to_deg(float(_h.get("pitch_rate", 1.0))), rad_to_deg(float(_h.get("roll_rate", 1.0))))
	_input["pitch"] = clampf((pitch_to - float(r["pitch"])) * K_PITCH / rates.x, -1.0, 1.0)
	_input["roll"] = clampf((bank_to - float(r["bank"])) * K_BANK / rates.y, -1.0, 1.0)


func _command(channel: int, value: int) -> void:
	# A NEW SEQUENCE ONLY FOR A NEW VALUE: the same command resent every tick on a fresh number is applied every tick.
	if int(_input.get("command_channel", -1)) == channel and int(_input.get("command_value", -1)) == value:
		return
	_seq = _seq % 3 + 1
	_input["command_channel"] = channel
	_input["command_value"] = value
	_input["command_seq"] = _seq


func _read() -> Dictionary:
	var s: Dictionary = _world.vehicle_state(_craft)
	var b := Basis(s.get("basis", Quaternion()) as Quaternion)
	var nose: Vector3 = b * Vector3.FORWARD
	var right: Vector3 = b * Vector3.RIGHT
	var v: Vector3 = s.get("velocity", Vector3.ZERO)
	return {
		"at": s.get("position", Vector3.ZERO) as Vector3, "v": v, "vy": v.y, "along": v.dot(nose), "basis": b,
		"pitch": rad_to_deg(asin(clampf(nose.y, -1.0, 1.0))),
		"bank": rad_to_deg(asin(clampf(-right.y, -1.0, 1.0))),
		"heading": rad_to_deg(atan2(-nose.x, -nose.z)),
	}
