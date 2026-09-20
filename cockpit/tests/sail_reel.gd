extends Node
## A FILM OF THE BRIG UNDER SAIL: heeled on a beam reach, from astern, off the bow, alongside at the wave, up onto a
## crane, and put about through the wind -- recorded by MovieWriter from this probe's own viewport (lane/sailshots,
## 2026-09-20).
##
##   <editor>.console.exe --path cockpit --xr-mode off --resolution 1600x900 --fixed-fps 30 --write-movie <out.avi>
##       res://tests/sail_reel.tscn -- --level=watch --wind=14
##
## WHY THIS EXISTS. The user asked for the sailboats "on the water, moving and listing a bit (due to wind)", and said
## the listing could be faked. FOR THIS BOAT IT IS NOT, and it must never be. `Sim.Kind.PIRATE` is the only kind on the
## `Sail` movement model: four sails on two masts, each with its own `SailCurve` driven by apparent wind, each sail's
## force applied at that sail's real height, and a metacentric torque righting her. The lean in this film is what the
## rig does to the hull. Turning `--wind=` up is the whole of how a stiffer lean is asked for -- and `tests/sailing.gd`
## asserts that relationship, so the film and the suite are looking at the same thing.
##
## THE LEAN ONLY SHOWS FROM THE SHIP'S FORE-AND-AFT LINE, which cost `tests/pirate_shot.gd` a set of pictures on the day
## this was written. A camera on the beam the masts lean towards foreshortens them into nothing: -17.3 degrees of real
## heel drew as about two degrees of mast tilt. So the shots that are FOR the heel stand astern or fine on the bow, and
## the beam shots are for the sail plan and the wake.
##
## EVERY POSE IS SHIP-RELATIVE, in `POSES`: so many metres to starboard, so many aft, so many up, all measured on the
## ship's own flattened axes and rebuilt every frame off her drawn transform. A ship making five metres a second leaves
## a camera placed once behind in seconds, and a dolly between two ship-relative poses is an orbit around a moving ship
## rather than a slide past where she used to be.
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (`seeing_the_game.md`). What it holds is that
## the film is of what it says it is -- the wind the probe asked for is the wind the sails felt, the ship was on the
## course she was sent to, and she was actually leaning while the heel shots were rolling. Whether it looks good is
## for eyes. `tests/sailing.gd` holds the sailing itself.
##
## NEVER A CAPTURE OF THE DESKTOP. MovieWriter records this probe's own viewport and nothing else.

## Frames a second, which must match the `--fixed-fps` the recorder is given or the film runs at the wrong speed.
const FPS: float = 30.0
## The wind the ship sails in, in metres a second, unless `--wind=` says otherwise, and the compass bearing it comes
## from. At 14 she makes about 5 m/s on a beam reach and heels about 17 degrees (measured 2026-09-20).
const WIND: float = 14.0
const FROM: float = 0.0
## Where she sails: far past the island's square on the negative side of both axes, the same open water
## `tests/pirate_shot.gd` uses, so the two agree about which sea this is.
const SEA := Vector3(-11000.0, 0.0, -11000.0)
## How long she sails before the camera rolls, so she is settled on her point of sail, heeled and making way.
const SAIL_FIRST: float = 70.0
## Frames held at a new pose before a shot begins. SMALL, BECAUSE THE RECORDER IS RUNNING: every settle frame is in the
## film as a frozen camera the viewer sits through (`tests/adriatic_reel.gd` measured that cost at a 62.7% unique-frame
## ratio against the 90% rule of the house). The sea and the sails move under a still camera, so twelve is plenty.
const SETTLE: int = 12
## How far a fixed plate creeps towards its subject over its own length, as a share of the distance. A locked-off camera
## on a moving ship is already alive; this is only so that no two frames are identical.
const CREEP: float = 0.05

## THE CAMERA POSES, in the ship's own metres: `out` to starboard, `aft` towards the stern, `up` above her waterline,
## and `at` the height on her centreline the lens is pointed at. Negative `aft` is ahead of her.
##
## `heel` marks the poses the LEAN is meant to read in -- astern and fine on the bow -- and the film's checks only ask
## about her heel while one of those is on camera.
const POSES: Dictionary = {
	"astern": {"out": 0.0, "aft": 62.0, "up": 17.0, "at": 12.0, "fov": 60.0, "heel": true},
	"astern_far": {"out": 14.0, "aft": 150.0, "up": 34.0, "at": 12.0, "fov": 50.0, "heel": true},
	"bow": {"out": 22.0, "aft": -58.0, "up": 6.0, "at": 10.0, "fov": 60.0, "heel": true},
	"bow_far": {"out": 46.0, "aft": -120.0, "up": 20.0, "at": 12.0, "fov": 52.0, "heel": true},
	"beam": {"out": -62.0, "aft": 0.0, "up": 11.0, "at": 12.0, "fov": 60.0, "heel": false},
	"wave": {"out": -27.0, "aft": -14.0, "up": 3.4, "at": 7.0, "fov": 68.0, "heel": false},
	"crane": {"out": -70.0, "aft": 40.0, "up": 96.0, "at": 6.0, "fov": 58.0, "heel": false},
	"quarter": {"out": 44.0, "aft": 52.0, "up": 15.0, "at": 11.0, "fov": 60.0, "heel": true},
}

## THE FILM. `hold` stands at one pose; `move` eases from one to another, which is an orbit when they differ round her
## and a crane when they differ in height. `tack` is the same as a hold except that the helmsman is told to go about at
## the top of it, so the shot contains the manoeuvre rather than following it.
const FILM: Array[Dictionary] = [
	{"kind": "hold", "pose": "astern", "seconds": 5.0},
	{"kind": "move", "from": "astern", "to": "beam", "seconds": 8.0},
	{"kind": "hold", "pose": "wave", "seconds": 5.0},
	{"kind": "move", "from": "wave", "to": "bow_far", "seconds": 8.0},
	{"kind": "hold", "pose": "bow", "seconds": 5.0},
	{"kind": "move", "from": "beam", "to": "crane", "seconds": 8.0},
	{"kind": "tack", "pose": "quarter", "seconds": 26.0},
	{"kind": "move", "from": "astern_far", "to": "astern", "seconds": 8.0},
]

var _level: FlightLevel = null
var _failures: PackedStringArray = []
var _ship: int = 0
## The compass heading she was told to hold, so the film can say whether she held it.
var _course: float = 0.0
var _wind: float = WIND
var _caption: Label = null
## `--caption=off`: the burnt-in wind, way and heel come off. ON by default, and that is deliberate -- a film of a lean
## nobody faked should carry the number it is leaning by.
var _captioned: bool = true
## The worst leeward heel seen while a `heel` pose was on camera, in degrees, and whether any was.
var _leaned: float = 0.0
var _heel_frames: int = 0
## THE FRAME THE FILM STARTS ON, so the trim is measured and not guessed. MovieWriter begins recording at the first
## drawn frame and cannot be stopped and started, so the `SAIL_FIRST` seconds she spends settling onto her point of
## sail are on the front of the AVI -- about seventy seconds of the observer's default view before the camera rolls.
## `Engine.get_frames_drawn()` counts exactly the frames the recorder wrote, so the difference IS the trim.
var _frames_before_the_film: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[sail_reel] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"wind": _wind = float(parts[1])
			"caption": _captioned = parts[1] != "off"
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null or Sim.server == null:
		_check("there_is_a_server_and_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	# NOT BEFORE THE LEVEL IS READY. `world/sky.gd:_on_sim_ready` pushes `Terrain.weather()` -- a wandering 5 to 12 m/s
	# from 244 degrees -- over whatever a probe set earlier, and it fires after this script's first frames. Setting the
	# weather before it is how `tests/pirate_shot.gd` came to photograph three ships on points of sail nobody chose.
	while not Sim.is_ready:
		await _frames(1)
	await _frames(1)
	for world in [Sim.server, Sim.client]:
		if world != null:
			world.set_weather({"from": FROM, "low": _wind, "high": _wind, "veer": 0.0, "seed": 1})
	_hide_the_writing()
	if _captioned:
		_raise_the_caption()
	# A BEAM REACH, which is where a square rigger both goes and leans.
	_course = FROM - PI * 0.5
	var nose := Vector3(sin(_course), 0.0, -cos(_course))
	_ship = Sim.spawn_ai_vehicle(Sim.Kind.PIRATE, SEA, -_course, nose * 3.0)
	_check("the_helmsman_took_the_course", Sim.server.hold_course(_ship, _course), "entity %d" % _ship)
	for i in range(int(SAIL_FIRST * 120.0)):
		await get_tree().physics_frame
	_check_the_wind_is_the_one_it_asked_for()
	_frames_before_the_film = Engine.get_frames_drawn()
	print("[sail_reel] the film starts at frame %d: trim %.2f s off the front of the movie at %d fps" % [
		_frames_before_the_film, float(_frames_before_the_film) / FPS, int(FPS)])
	await _roll()
	_finish()


## THE HUD AND THE OBSERVER'S BOARDS COME OFF. A film wants the sea, not the frame counter over it.
func _hide_the_writing() -> void:
	var words := _level.get_node_or_null("Ui") as CanvasLayer
	if words != null:
		words.visible = false
	for board in _level.observer.find_children("*", "CanvasItem", true, false):
		(board as CanvasItem).visible = false


func _raise_the_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(20.0, 20.0)
	_caption.add_theme_font_size_override("font_size", 20)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 6)
	layer.add_child(_caption)


## THE WIND THE SAILS ACTUALLY FEEL, asked of the authority that used it rather than believed from the constant that
## requested it (CLAUDE.md rule 4). `sail_report`'s `wind` is where the air GOES, so the bearing it comes from is
## `atan2(-x, z)` -- the same convention `Terrain.weather` states from the other end.
func _check_the_wind_is_the_one_it_asked_for() -> void:
	var goes: Vector3 = (Sim.server.sail_report(_ship) as Dictionary).get("wind", Vector3.ZERO)
	var bearing: float = atan2(-goes.x, goes.z)
	var off: float = rad_to_deg(absf(wrapf(bearing - FROM, -PI, PI)))
	_check("the_ship_sails_in_the_wind_the_film_set", off <= 2.0 and absf(goes.length() - _wind) <= 1.0,
		"%.1f m/s from %.0f degrees, asked for %.1f from %.0f" % [goes.length(), rad_to_deg(bearing), _wind,
			rad_to_deg(FROM)])


func _roll() -> void:
	var filmed: float = 0.0
	for shot in FILM:
		var kind: String = String(shot["kind"])
		var seconds: float = float(shot["seconds"])
		match kind:
			"hold": await _hold(String(shot["pose"]), seconds)
			"tack": await _tack(String(shot["pose"]), seconds)
			_: await _move(String(shot["from"]), String(shot["to"]), seconds)
		filmed += seconds
		print("[sail_reel] %s %s %.1f s" % [kind, shot.get("pose", "%s to %s" % [shot.get("from"), shot.get("to")]),
			seconds])
	_check("the_film_is_long_enough", filmed >= 45.0, "%.1f s at %d fps" % [filmed, int(FPS)])
	_check("she_was_leaning_while_the_heel_shots_rolled", _heel_frames > 0 and _leaned >= 8.0,
		"%.1f degrees of leeward heel at her most, over %d frames on a heel pose" % [_leaned, _heel_frames])


func _hold(name: String, seconds: float) -> void:
	if not _aim(name, 0.0):
		return
	await _frames(SETTLE)
	var count: int = int(seconds * FPS)
	for i in range(count):
		_aim(name, CREEP * float(i) / float(maxi(count - 1, 1)))
		await get_tree().process_frame


## THE SHIP PUT ABOUT, filmed from her quarter: the helmsman is told the new course at the top of the shot and the
## camera stays on her through the whole manoeuvre, so the tack happens on screen rather than between two cuts.
func _tack(name: String, seconds: float) -> void:
	if not _aim(name, 0.0):
		return
	await _frames(SETTLE)
	_course = FROM + PI * 0.5
	Sim.server.hold_course(_ship, _course)
	var count: int = int(seconds * FPS)
	for i in range(count):
		_aim(name, CREEP * float(i) / float(maxi(count - 1, 1)))
		await get_tree().process_frame
	_check_she_is_on_the_course_she_was_sent_to("after the tack")


func _move(from_name: String, to_name: String, seconds: float) -> void:
	if not (POSES.has(from_name) and POSES.has(to_name)):
		_check("the_film_names_a_pose_that_exists", false, "%s to %s" % [from_name, to_name])
		return
	_aim(from_name, 0.0)
	await _frames(SETTLE)
	var a: Dictionary = POSES[from_name]
	var b: Dictionary = POSES[to_name]
	var count: int = int(seconds * FPS)
	for i in range(count):
		# EASED AT BOTH ENDS. A dolly that starts and stops dead reads as a snap, not as a camera on a crane.
		var t: float = smoothstep(0.0, 1.0, float(i) / float(maxi(count - 1, 1)))
		var mixed: Dictionary = {
			"out": lerpf(float(a["out"]), float(b["out"]), t),
			"aft": lerpf(float(a["aft"]), float(b["aft"]), t),
			"up": lerpf(float(a["up"]), float(b["up"]), t),
			"at": lerpf(float(a["at"]), float(b["at"]), t),
			"fov": lerpf(float(a["fov"]), float(b["fov"]), t),
			"heel": bool(a["heel"]) and bool(b["heel"]),
		}
		_stand(mixed, 0.0)
		await get_tree().process_frame


func _aim(name: String, creep: float) -> bool:
	if not POSES.has(name):
		_check("the_film_names_a_pose_that_exists", false, name)
		return false
	_stand(POSES[name], creep)
	return true


## THE CAMERA, OFF HER DRAWN TRANSFORM, this frame. Her flattened axes, never her heeled ones: a camera hung off a
## rolling mast rolls with it, and a horizon that leans with the ship shows no lean at all.
func _stand(pose: Dictionary, creep: float) -> void:
	var drawn: int = _drawn()
	if drawn == 0:
		return
	var her: Transform3D = Sim.vehicle_transform(drawn)
	var at: Vector3 = her.origin
	var right: Vector3 = Vector3(her.basis.x.x, 0.0, her.basis.x.z).normalized()
	var aft: Vector3 = Vector3(her.basis.z.x, 0.0, her.basis.z.z).normalized()
	var target: Vector3 = at + Vector3(0.0, float(pose["at"]), 0.0)
	var eye: Vector3 = at + right * float(pose["out"]) + aft * float(pose["aft"]) \
		+ Vector3(0.0, float(pose["up"]), 0.0)
	var camera: Camera3D = _level.observer
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = float(pose["fov"])
	camera.look_from(eye.lerp(target, creep), target)
	var report: Dictionary = Sim.server.sail_report(_ship)
	var heel: float = rad_to_deg(float(report.get("heel", 0.0)))
	if bool(pose.get("heel", false)):
		_heel_frames += 1
		_leaned = maxf(_leaned, -heel)
	if _caption != null:
		_caption.text = "a brig under sail  ·  wind %.0f m/s  ·  %.1f m/s through the water  ·  heel %.1f deg" % [
			_wind, float(report.get("way", 0.0)), heel]


## HER HULL ON THIS MACHINE'S CLIENT for the server's entity: entity ids are per world, so it is the brig drawn nearest
## the server's position. The same walk `tests/pirate_shot.gd` does.
func _drawn() -> int:
	var truth: Vector3 = (Sim.server.vehicle_state(_ship) as Dictionary).get("position", Vector3.ZERO)
	var best: int = 0
	var nearest: float = INF
	for entity in Sim.current:
		var state: Dictionary = Sim.current[entity]
		if int(state.get("kind", -1)) != Sim.Kind.PIRATE:
			continue
		var apart: float = ((state["position"] as Vector3) - truth).length()
		if apart < nearest:
			nearest = apart
			best = int(entity)
	return best


func _check_she_is_on_the_course_she_was_sent_to(when: String) -> void:
	var basis: Quaternion = (Sim.server.vehicle_state(_ship) as Dictionary)["basis"]
	var nose: Vector3 = basis * Vector3.FORWARD
	var off: float = rad_to_deg(absf(wrapf(atan2(nose.x, -nose.z) - _course, -PI, PI)))
	_check("she_is_on_the_course_she_was_sent_to_%s" % when.replace(" ", "_"), off <= 20.0,
		"%.0f degrees off the %.0f she was told to hold" % [off, rad_to_deg(_course)])


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
