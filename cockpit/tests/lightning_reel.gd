extends Node3D
## A REEL OF THE F-35B DOING WHAT A B IS FOR: parked, the nozzle swung down and the lift fan's doors open, straight up off
## the ground, a hover, the gear up, and the transition to wing-borne flight -- drawn from the real simulation, flown
## through a seated pilot's own control frame by `tests/lightning_flight.gd`'s robot.
##
##   <editor>.console.exe --path cockpit --xr-mode off --resolution 1600x900 --write-movie <out.avi> --fixed-fps 30
##       res://tests/lightning_reel.tscn -- --out=<folder>
##
## NOT THE FLY BENCH: that hands its craft to the AUTOPILOT, which flies an F-35B as an aeroplane with the nozzle aft --
## the one thing this reel is not about. So this probe runs its own `CockpitWorld` headless-style (a pilot spawned in the
## craft, `set_pilot_input` each tick, a bus command for the nozzle), and draws a `LightningAirframe` where the world says
## the craft is, its nozzle from the world's tilt channel and its gear eased toward the world's bit as `VehicleView` eases
## it. Every frame is this probe's own viewport -- MovieWriter records the game's window, never the desktop.
##
## A caption burns in what the world says: the time, the nozzle's angle (the lever times the kind's `vector_travel`), the
## height, the climb and the speed, so a reader can check the picture against the numbers.
##
## STILLS at fixed moments go to `--out`, named for what they show, for the blog and for a reader without a player.

const TICK: float = 1.0 / 120.0
const FRAME: float = 1.0 / 30.0
const GROUND_HALF: float = 40000.0
const CLIENT: int = 60
const K_PITCH: float = 2.5
const K_BANK: float = 2.5
const K_HEADING: float = 1.2
const HOVER_AT: float = 25.0
## THE SCRIPT, seconds from the start: nozzle down at 2, full power at 4, a hover at HOVER_AT from 12, the gear up at 16,
## the nozzle wound aft from 20 over 12 s, and wing-borne to the end.
const NOZZLE_DOWN_AT: float = 2.0
const LIFT_AT: float = 4.0
const GEAR_UP_AT: float = 16.0
const TRANSITION_AT: float = 20.0
const TRANSITION_OVER: float = 12.0
const END_AT: float = 40.0
## STILLS: [seconds, name].
const STILLS: Array = [[1.5, "parked-nozzle-aft"], [3.8, "nozzle-down-fan-doors-open"], [8.0, "vertical-take-off"],
	[14.0, "hover"], [19.0, "hover-gear-up"], [26.0, "transition"], [38.0, "wing-borne"]]

var out := ""
var _world: Object = null
var _missiles: MissileYard = null
var _exhaust: ExhaustYard = null
var _pilot: int = 0
var _craft: int = 0
var _h: Dictionary = {}
var _hy: float = 0.0
var _t: float = 0.0
var _seq: int = 0
var _input: Dictionary = {}
var _frame: LightningAirframe = null
var _camera: Camera3D = null
var _caption: Label = null
var _gear_drawn: float = 1.0
var _gear_down: bool = true
var _mark := Vector3.ZERO
var _stills_taken: int = 0
var _failures: PackedStringArray = []
var _travel: float = 1.0


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	_stage()
	_build_the_exhaust()
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(GROUND_HALF, 400.0, GROUND_HALF))
	_h = _world.handling(Sim.Kind.LIGHTNING)
	_travel = float(_h.get("vector_travel", 1.658))
	_hy = float((Sim.geometry_of(Sim.Kind.LIGHTNING).get("extents", Vector3.ONE) as Vector3).y)
	var made: Dictionary = _world.spawn_pilot(CLIENT, Sim.Kind.LIGHTNING, Vector3(0.0, _hy + 0.05, 0.0), 0.0, Vector3.ZERO)
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_input = {"throttle": 0.002, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0}
	_mark = _read()["at"]


## THE EXHAUST, in the probe's own world (lane/harrier, 2026-09-19). `ExhaustYard` normally takes its strength off the
## replicated command bus, which every machine holds for every entity -- but this probe runs its own `CockpitWorld`
## with no `Sim.client` in it at all, so it hands the yard its own reader, as `MissileYard.find_rail` is handed one.
## The clock is a bare `MissileYard`, which is what `tests/craft_video_demo.gd` does for the same reason: every yard of
## this family ages its instances on that one clock, so they freeze and resume together.
func _build_the_exhaust() -> void:
	_missiles = MissileYard.new()
	_missiles.name = "TrailClock"
	add_child(_missiles)
	_exhaust = ExhaustYard.new()
	_exhaust.name = "Exhaust"
	_exhaust.follow(_missiles)
	_exhaust.throttle_of = func(_entity: int) -> float:
		return float(_input.get("throttle", 0.0))
	add_child(_exhaust)


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
	for piece in [[Vector2(3000.0, 3000.0), Color(0.36, 0.44, 0.30), 0.0], [Vector2(40.0, 1200.0), Color(0.34, 0.34, 0.33), 0.02],
			[Vector2(1.0, 1200.0), Color(0.85, 0.85, 0.80), 0.03]]:
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = piece[0]
		ground.mesh = plane
		var paint := StandardMaterial3D.new()
		paint.albedo_color = piece[1]
		ground.material_override = paint
		ground.position = Vector3(0.0, float(piece[2]), -300.0)
		add_child(ground)
	_frame = LightningAirframe.new()
	_frame.dress()
	add_child(_frame)
	_camera = Camera3D.new()
	_camera.fov = 40.0
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
		print("[lightning_reel] ended at %.1f m, %.1f m/s, nozzle %.2f" % [(r["at"] as Vector3).y - _hy, float(r["along"]),
			float((_world.craft_controls(_craft) as Dictionary).get("tilt", -1.0))])
		_world.teardown()
		_world = null
		print("[lightning_reel] RESULT=%s into %s" % ["PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures), out])
		get_tree().quit(0 if _failures.is_empty() else 1)


## THE SCRIPT, as a pilot's hands.
func _fly() -> void:
	var r: Dictionary = _read()
	var at: Vector3 = r["at"]
	if _t >= NOZZLE_DOWN_AT and _t < TRANSITION_AT:
		_command(Sim.Channel.TILT, _hover_tilt())
	if _t < LIFT_AT:
		_input["throttle"] = 0.002
		return
	if _t >= GEAR_UP_AT and _gear_down:
		_command(Sim.Channel.GEAR, 0)
		_gear_down = false
	if _t < TRANSITION_AT:
		var target: float = _mark.y + HOVER_AT
		var vy_to: float = clampf(0.6 * (target - at.y), -2.0, 3.0)
		_input["throttle"] = _collective(float(r["vy"]), vy_to) if _t > LIFT_AT + 0.5 else 1.0
		_hold_spot(r, Vector3(_mark.x, at.y, _mark.z))
		return
	# THE TRANSITION: the nozzle wound aft over TRANSITION_OVER seconds, full power, height held on the stick.
	var share: float = clampf((_t - TRANSITION_AT) / TRANSITION_OVER, 0.0, 1.0)
	_command(Sim.Channel.TILT, int(round(float(_hover_tilt()) * (1.0 - share))))
	_input["throttle"] = 1.0
	_hands(r, clampf(0.25 * (_mark.y + HOVER_AT + 10.0 - at.y) - 1.2 * float(r["vy"]), -8.0, 10.0), 0.0)
	_input["rudder"] = 0.0


## THE DRAWING: the airframe where the world says, its nozzle from the world's lever, its gear eased as `VehicleView` eases
## it, the fan turning while the nozzle is down, and a chase camera off the starboard quarter.
func _draw() -> void:
	var s: Dictionary = _world.vehicle_state(_craft)
	var basis := Basis(s.get("basis", Quaternion()) as Quaternion)
	var at: Vector3 = s.get("position", Vector3.ZERO)
	_frame.global_transform = Transform3D(basis, at)
	var bus: Dictionary = _world.craft_controls(_craft)
	var tilt: float = float(bus.get("tilt", 0.0))
	_frame.set_nozzle(tilt)
	var want: float = 1.0 if bool(bus.get("gear", true)) else 0.0
	_gear_drawn = move_toward(_gear_drawn, want, FRAME / LightningAirframe.GEAR_SECONDS)
	_frame.set_gear(_gear_drawn)
	if tilt > 0.0:
		_frame.set_fan(_t * LightningAirframe.FAN_BLADE_PASSES)
	# THE EXHAUST, off the airframe's own declared ports and this world's throttle. Laid AFTER the airframe is placed
	# and its nozzle set, because the ports hang on the nozzle's hinge: a plume laid first would be drawn a frame
	# behind the metal it comes out of, which on a nozzle swinging through 95 degrees is a visible lag.
	#
	# AND THE CLOCK HAS TO BE WOUND, which is not obvious and cost this probe its first run. `MissileYard._clock`
	# advances inside `draw_missiles()` and nowhere else, because in the game the level calls that every frame. A bare
	# yard used only as a clock never gets the call, so it stands still at zero -- and a ground puff whose age is
	# always zero fades in from nothing for ever and is NEVER DRAWN. The suite was green, the yard reported its puffs
	# thrown, and the first picture of a hovering F-35B had no ground wash under it at all.
	if _exhaust != null:
		_missiles.draw_missiles([], _camera.global_position, FRAME)
		_exhaust.lay({_craft: _frame})
	# The camera: off the starboard quarter for the hover, then a chase off the starboard quarter aft once it is going
	# somewhere, which it keeps up with -- the first cut's slow follow was left behind by a jet doing 140 m/s.
	var chase: float = clampf((_t - TRANSITION_AT) / 6.0, 0.0, 1.0)
	var off: Vector3 = Vector3(20.0, 3.0, 16.0).lerp(Vector3(16.0, 5.0, 34.0), chase)
	_camera.global_position = at + off
	_camera.look_at(at + Vector3(0.0, 0.5, -1.0), Vector3.UP)
	var r: Dictionary = _read()
	_caption.text = "F-35B  %4.1f s   nozzle %3.0f deg down   height %5.1f m   climb %+5.1f m/s   speed %5.1f m/s   gear %s" % [
		_t, rad_to_deg(tilt * _travel), (r["at"] as Vector3).y - _hy, float(r["vy"]), float(r["along"]),
		"down" if bool(bus.get("gear", true)) else "up"]


func _still(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = out.path_join("lightning-reel-%s.png" % name)
	if image.save_png(path) != OK:
		_failures.append(name)
	print("[lightning_reel] saved %s" % path)


# ---- the robot's hands, `tests/lightning_flight.gd`'s ----------------------------------------------------------------

func _hover_tilt() -> int:
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
