extends Node
## A SIGNAL LAMP 1.5 KM OFF, BY DAY AND AT NIGHT: how many pixels of its colour a player sees when it is aimed at them,
## a little off, and well away -- counted off the real frame, in the real level, with the real sky, mist and tonemapper.
##
##   Godot --path cockpit --resolution 1600x900 res://tests/lamp_beam_shot.tscn -- --level=watch --out=C:/somewhere
##
## NOT HEADLESS -- it renders. A picture is written for every case beside the counts.
##
## WHAT IS REAL AND WHAT IS NOT. The level, the time of day (through `FlightLevel.choose_time`, the call the clipboard's
## TIME tab makes), the observer's camera and the lamp are all the shipping ones. What is placed by hand is the lamp itself:
## a `SignalLamp` hung in the air 1.5 km ahead of the camera, lit through `SignalLamp.ask` and turned by its parent. The
## whole path that puts a far player's lamp there -- the bus, the pilot state, `Sky._show_their_lamp` -- is
## `tests/lamp_peers.gd`'s; this is only "can a person see it".
##
## WHAT IT HOLDS, at each time of day:
##   * red aimed at the eye is at least `LEAST_PIXELS` red pixels, and green likewise green;
##   * 10 degrees off the axis it is fewer than aimed, and 60 degrees off it is nothing;
##   * dark, it is nothing.
##
## MEASURED (2026-09-18, RTX 5080, D3D12, Mobile, 1600x900, the double editor), pixels of the lamp's colour at 1.5 km:
##   DAY    red aimed 24, 10 degrees off 16, 60 off 0; green 28; white 48; dark 0
##   NIGHT  red aimed 76, 10 degrees off 68, 60 off 0; green 78; white 32; dark 0
## At a least angle of 4 milliradians it was 4 red pixels by day and 15 at night: see `SignalLamp.LEAST_ANGLE`.
##
## MUTANT (2026-09-18): the beam taken out of the shader (`in_beam = 1.0` everywhere):
##   FAIL a_red_lamp_10_degrees_off_is_dimmer_by_DAY (24 against 24)
##   FAIL a_red_lamp_60_degrees_off_is_not_seen_by_DAY (24 red px)
##
## Read RESULT=, not the exit code.

## How far off the lamp is, metres, and how high the eye and the lamp are over the runway.
const AWAY: float = 1500.0
const HIGH: float = 300.0
## THE FEWEST PIXELS OF ITS COLOUR A LAMP AIMED AT YOU MAY BE. A navigation light is measured at about eight at this
## range (VehicleLights, 2026-09-12); a signal lamp aimed at you should beat it.
const LEAST_PIXELS: int = 12
## HOW BIG A BOX ROUND THE LAMP IS COUNTED, pixels. 160 took in a town light below the lamp at night (2 red px with
## the lamp dark); 48 is the lamp and its halo and nothing else.
const BOX: int = 48
const WARM: int = 240
const SETTLE: int = 60

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = ""
var _mount: Node3D = null
var _lamp: SignalLamp = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[lamp_beam] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
	if _out.is_empty():
		_out = ProjectSettings.globalize_path("user://lamp_beam")
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	for i in range(WARM):
		await get_tree().process_frame
	# THE EYE HIGH OVER THE RUNWAY, LOOKING ALONG IT, AND THE LAMP 1.5 KM AHEAD.
	var runway: Dictionary = Terrain.runways()[0]
	var bearing: float = float(runway["bearing"])
	var ahead := Vector3(-sin(bearing), 0.0, -cos(bearing))
	var eye: Vector3 = (runway["centre"] as Vector3) + Vector3(0.0, HIGH, 0.0)
	var there: Vector3 = eye + ahead * AWAY
	_mount = Node3D.new()
	_mount.name = "LampMount"
	_level.add_child(_mount)
	_mount.global_position = there
	_lamp = SignalLamp.new()
	_mount.add_child(_lamp)
	_lamp.setup(0)
	for time in [DaylightTuning.When.DAY, DaylightTuning.When.NIGHT]:
		_level.call("choose_time", time)
		var when: String = DaylightTuning.name_of(time)
		for i in range(SETTLE):
			_place(eye, there)
			await get_tree().process_frame
		var aimed: int = await _count("%s-red-aimed" % when, eye, SignalLamp.RED, 0.0)
		var off10: int = await _count("%s-red-10-degrees-off" % when, eye, SignalLamp.RED, 10.0)
		var off60: int = await _count("%s-red-60-degrees-off" % when, eye, SignalLamp.RED, 60.0)
		var green: int = await _count("%s-green-aimed" % when, eye, SignalLamp.GREEN, 0.0)
		var white: int = await _count("%s-white-aimed" % when, eye, SignalLamp.WHITE, 0.0)
		var dark: int = await _count("%s-dark-aimed" % when, eye, SignalLamp.DARK, 0.0)
		print("[lamp_beam] %s at %.0f m: red aimed %d, 10 off %d, 60 off %d; green %d; white %d; dark %d px"
			% [when, AWAY, aimed, off10, off60, green, white, dark])
		_check("a_red_lamp_aimed_at_you_is_seen_by_%s" % when, aimed >= LEAST_PIXELS, "%d red px" % aimed)
		_check("a_green_one_too_by_%s" % when, green >= LEAST_PIXELS, "%d green px" % green)
		_check("a_red_lamp_10_degrees_off_is_dimmer_by_%s" % when, off10 < aimed, "%d against %d" % [off10, aimed])
		_check("a_red_lamp_60_degrees_off_is_not_seen_by_%s" % when, off60 <= 1, "%d red px" % off60)
		_check("a_dark_lamp_is_not_seen_by_%s" % when, dark <= 1, "%d px of any lamp colour" % dark)
	_finish()


## LIGHT THE LAMP `colour`, TURN IT `off_axis` DEGREES AWAY FROM THE EYE, draw, and count the pixels of that colour round
## where it is. For DARK, every lamp colour is counted.
func _count(name: String, eye: Vector3, colour: int, off_axis: float) -> int:
	_lamp.ask(SignalLamp.WHITE, false)
	_lamp.ask(SignalLamp.RED, false)
	_lamp.ask(SignalLamp.GREEN, false)
	if colour != SignalLamp.DARK:
		_lamp.ask(colour, true)
	# THE MUZZLE AT THE MOUNT, aimed at the eye and turned about the vertical by `off_axis`.
	var to_eye: Vector3 = (eye - _mount.global_position).normalized()
	var aim: Vector3 = to_eye.rotated(Vector3.UP, deg_to_rad(off_axis))
	_mount.global_basis = Basis.looking_at(aim, Vector3.UP)
	_lamp.transform = Transform3D(Basis.IDENTITY, -_lamp.muzzle().position)
	for i in range(8):
		_place(eye, _mount.global_position)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	picture.save_png(_out.path_join("cockpit-lightgun-beam-%s.png" % name))
	var camera: Camera3D = get_viewport().get_camera_3d()
	var at: Vector2 = camera.unproject_position(_lamp.muzzle().global_position)
	var counted: int = 0
	for y in range(int(at.y) - BOX / 2, int(at.y) + BOX / 2):
		for x in range(int(at.x) - BOX / 2, int(at.x) + BOX / 2):
			if x < 0 or y < 0 or x >= picture.get_width() or y >= picture.get_height():
				continue
			var px: Color = picture.get_pixel(x, y)
			if colour == SignalLamp.DARK:
				if _is(px, SignalLamp.RED) or _is(px, SignalLamp.GREEN) or _is(px, SignalLamp.WHITE):
					counted += 1
			elif _is(px, colour):
				counted += 1
	return counted


## WHETHER A PIXEL IS A LAMP'S COLOUR. Red and green by their channel leading the other two; white by all three high,
## which a sky by day can be near the sun, so white is only asked of the box round the lamp and only reported.
static func _is(px: Color, colour: int) -> bool:
	match colour:
		SignalLamp.RED:
			return px.r > 0.5 and px.g < 0.55 * px.r and px.b < 0.55 * px.r
		SignalLamp.GREEN:
			return px.g > 0.5 and px.r < 0.7 * px.g and px.b < 0.8 * px.g
		SignalLamp.WHITE:
			return px.r > 0.9 and px.g > 0.9 and px.b > 0.85
	return false


func _place(at: Vector3, toward: Vector3) -> void:
	var eye: Node = _level.observer
	if eye.has_method("look_from"):
		eye.call("look_from", at, toward)


func _finish() -> void:
	if _failures.is_empty():
		print("[lamp_beam] RESULT=PASS")
	else:
		print("[lamp_beam] RESULT=FAIL %s" % ", ".join(_failures))
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)
