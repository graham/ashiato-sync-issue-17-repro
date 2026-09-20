extends Node
## THE SLOOP AND THE LEIGH 30 CUTTER, SAILING: four of them on open water, moving and heeled, filmed and photographed
## in one run (lane/sailshots, 2026-09-20).
##
##   <editor>.console.exe --path cockpit --xr-mode off --resolution 1600x900 --fixed-fps 30 --write-movie <out.avi>
##       res://tests/small_craft_reel.tscn -- --level=watch --out=C:/somewhere
##
## BOTH AT ONCE, AND THAT IS THE POINT. `--write-movie` gives the film; `--out=` saves a PNG at the top of every shot
## from the same viewport in the same run. A second launch to take the stills would be a second sea state, a second
## wind and a second set of liveries, and the two sets would quietly disagree.
##
## WHAT THEY ARE. `cruising_sloop` is a masthead sloop of the Beneteau Oceanis 40.1's size and `classic_cutter` is the
## Leigh 30, a 1979 Chuck Paine long-keel cutter -- the boat the user asked for by name. NEITHER IS A KIND. They are
## scenery drawn from `SmallCraftDraft` and there is no simulation under them, so they cannot sail themselves and they
## cannot heel. `ScenerySailboat` moves them and leans them, and says in its own doc block that the lean is drawn --
## the user's own permission, "you can fake the listing for affect", spent on the two boats it was meant for.
##
## THE BRIG IS THE OTHER HALF AND IS NOT FAKED. `tests/sail_reel.gd` films `Sim.Kind.PIRATE`, whose heel comes out of
## four sails pushing on a hull. If you are comparing the two films, that is the difference between them.
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (`seeing_the_game.md`). What it holds is that
## the boats were actually under way and actually leaning to leeward of the wind the world really had, which is the one
## thing a picture of a fake ought to be held to. Whether they look like boats is for eyes, and
## `tests/merchant_models.gd` holds their shapes.
##
## NEVER A CAPTURE OF THE DESKTOP. MovieWriter records this probe's own viewport and nothing else.

const FPS: float = 30.0
## The wind they sail in and the bearing it comes from. Steady, so the film is not at the mercy of a gust, and strong
## enough that `ScenerySailboat` is near its full drawn lean.
const WIND: float = 12.0
const FROM: float = 0.0
## Where they sail: the same open water off the island's negative corner that `tests/pirate_shot.gd` and
## `tests/sail_reel.gd` use, so all three probes agree about which sea this is.
const SEA := Vector3(-11000.0, 0.0, -11000.0)
## Frames held at a new pose before a shot begins, and how far a fixed plate creeps over its own length.
const SETTLE: int = 12
const CREEP: float = 0.05

## THE FLEET: which boat, which livery, where she starts relative to `SEA`, what she steers and how fast. FOUR BOATS
## AND NOT TWO, because the user said "the sailboats we made ... there are multiple": two of each, on opposite tacks,
## so the film shows that a sloop and a cutter are not the same boat and that the lean follows the wind rather than
## being painted on. Five knots is 2.57 m/s; the sloop is the bigger boat and goes a little better.
const FLEET: Array[Dictionary] = [
	{"boat": "cruising_sloop", "livery": 1, "offset": Vector3(0.0, 0.0, 0.0), "heading": -90.0, "speed": 3.10},
	{"boat": "classic_cutter", "livery": 0, "offset": Vector3(-34.0, 0.0, 26.0), "heading": -90.0, "speed": 2.57},
	{"boat": "cruising_sloop", "livery": 4, "offset": Vector3(150.0, 0.0, 120.0), "heading": 90.0, "speed": 3.10},
	{"boat": "classic_cutter", "livery": 3, "offset": Vector3(190.0, 0.0, 86.0), "heading": 90.0, "speed": 2.57},
]

## THE CAMERA POSES, in the lead boat's own metres: `out` to starboard, `aft` towards her stern, `up` above the water,
## `at` the height on her centreline the lens points at. Negative `aft` is ahead of her.
##
## HEEL SHOWS FROM HER FORE-AND-AFT LINE AND NOWHERE ELSE, which cost `tests/pirate_shot.gd` a whole set of pictures on
## the day this was written: a camera on the beam she leans towards foreshortens the lean into nothing. So `astern` and
## `bow` are the shots that are FOR the lean, and the beam shots are for her sheer and her rig.
const POSES: Dictionary = {
	"astern": {"out": 1.0, "aft": 26.0, "up": 5.2, "at": 4.0, "fov": 55.0},
	"bow": {"out": 9.0, "aft": -30.0, "up": 3.4, "at": 5.0, "fov": 55.0},
	"beam": {"out": -26.0, "aft": 2.0, "up": 5.0, "at": 5.0, "fov": 55.0},
	"beam_far": {"out": -70.0, "aft": 30.0, "up": 11.0, "at": 6.0, "fov": 46.0},
	"crane": {"out": -42.0, "aft": 34.0, "up": 46.0, "at": 3.0, "fov": 52.0},
	"fleet": {"out": -96.0, "aft": 128.0, "up": 26.0, "at": 6.0, "fov": 46.0},
}

## THE FILM. A still is saved at the top of each shot, named after it.
const FILM: Array[Dictionary] = [
	{"kind": "hold", "pose": "astern", "seconds": 5.0},
	{"kind": "move", "from": "astern", "to": "beam", "seconds": 7.0},
	{"kind": "hold", "pose": "bow", "seconds": 5.0},
	{"kind": "move", "from": "bow", "to": "beam_far", "seconds": 7.0},
	{"kind": "hold", "pose": "fleet", "seconds": 6.0},
	{"kind": "move", "from": "beam_far", "to": "crane", "seconds": 7.0},
	{"kind": "hold", "pose": "astern", "seconds": 5.0},
]

var _level: FlightLevel = null
var _failures: PackedStringArray = []
var _boats: Array[ScenerySailboat] = []
var _out: String = ""
var _caption: Label = null
var _captioned: bool = true
## The worst leeward lean seen on the lead boat while the camera was rolling, in degrees.
var _leaned: float = 0.0
## Where the lead boat was when the camera started, so the film can say she actually went somewhere.
var _started_at := Vector3.ZERO
## The frame the film starts on, so a trim off the front of the movie is measured and not guessed -- MovieWriter cannot
## be stopped and started, so everything before the first shot is on the front of the AVI.
var _frames_before_the_film: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[small_craft_reel] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"out": _out = parts[1]
			"caption": _captioned = parts[1] != "off"
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null or Sim.server == null:
		_check("there_is_a_server_and_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	# NOT BEFORE THE LEVEL IS READY. `world/sky.gd:_on_sim_ready` pushes `Terrain.weather()` over whatever a probe set
	# earlier, and it fires after this script's first frames -- the bug that had `tests/pirate_shot.gd` photographing
	# three ships on points of sail nobody chose, from 2026-09-15 until the day this was written.
	while not Sim.is_ready:
		await _frames(1)
	await _frames(1)
	for world in [Sim.server, Sim.client]:
		if world != null:
			world.set_weather({"from": FROM, "low": WIND, "high": WIND, "veer": 0.0, "seed": 1})
	_check_the_wind_is_the_one_it_asked_for()
	_hide_the_writing()
	if _captioned:
		_raise_the_caption()
	for row in FLEET:
		var boat: ScenerySailboat = ScenerySailboat.one(String(row["boat"]), SEA + (row["offset"] as Vector3),
			deg_to_rad(float(row["heading"])), int(row["livery"]), float(row["speed"]))
		_level.add_child(boat)
		_boats.append(boat)
	await _frames(30)
	_started_at = _boats[0].global_position
	_frames_before_the_film = Engine.get_frames_drawn()
	print("[small_craft_reel] the film starts at frame %d: trim %.2f s off the front of the movie at %d fps" % [
		_frames_before_the_film, float(_frames_before_the_film) / FPS, int(FPS)])
	await _roll()
	_check_they_went_somewhere()
	_finish()


## THE WIND THEY LEAN AWAY FROM, asked of the authority that has it rather than believed from the constant that asked
## for it (CLAUDE.md rule 4). `sail_report` needs a sailing kind and these are not kinds, so the world's own `weather`
## is the one that answers -- which is exactly the call `ScenerySailboat` leans by.
func _check_the_wind_is_the_one_it_asked_for() -> void:
	var weather: Dictionary = Sim.server.weather()
	var off: float = rad_to_deg(absf(wrapf(float(weather.get("from", 0.0)) - FROM, -PI, PI)))
	_check("the_boats_sail_in_the_wind_the_film_set", off <= 2.0 and absf(float(weather.get("speed", 0.0)) - WIND) <= 1.0,
		"%.1f m/s from %.0f degrees, asked for %.1f from %.0f" % [float(weather.get("speed", 0.0)),
			rad_to_deg(float(weather.get("from", 0.0))), WIND, rad_to_deg(FROM)])


## SHE WAS ACTUALLY UNDER WAY: a boat on a track that never advanced would photograph exactly like one that did.
func _check_they_went_somewhere() -> void:
	var gone: float = (_boats[0].global_position - _started_at).length()
	_check("the_lead_boat_was_under_way", gone >= 40.0, "%.0f m made good while the camera rolled" % gone)


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


func _roll() -> void:
	var filmed: float = 0.0
	for shot in FILM:
		var kind: String = String(shot["kind"])
		var seconds: float = float(shot["seconds"])
		if kind == "hold":
			await _hold(String(shot["pose"]), seconds)
		else:
			await _move(String(shot["from"]), String(shot["to"]), seconds)
		filmed += seconds
	_check("the_film_is_long_enough", filmed >= 40.0, "%.1f s at %d fps" % [filmed, int(FPS)])
	# THE ONE THING A PICTURE OF A FAKE MUST BE HELD TO: that the fake was on while it was being photographed. A drawn
	# heel that silently returned zero -- no server, a world with no `weather` method, a wind of nothing -- would give
	# a film of four boats standing bolt upright and every other check here would still pass.
	_check("they_were_leaning_while_the_camera_rolled", _leaned >= 6.0,
		"%.1f degrees of drawn leeward lean on the lead boat at her most" % _leaned)


func _hold(name: String, seconds: float) -> void:
	if not _aim(name, 0.0):
		return
	await _frames(SETTLE)
	_photograph(name)
	var count: int = int(seconds * FPS)
	for i in range(count):
		_aim(name, CREEP * float(i) / float(maxi(count - 1, 1)))
		await get_tree().process_frame


func _move(from_name: String, to_name: String, seconds: float) -> void:
	if not (POSES.has(from_name) and POSES.has(to_name)):
		_check("the_film_names_a_pose_that_exists", false, "%s to %s" % [from_name, to_name])
		return
	_aim(from_name, 0.0)
	await _frames(SETTLE)
	_photograph("%s-to-%s" % [from_name, to_name])
	var a: Dictionary = POSES[from_name]
	var b: Dictionary = POSES[to_name]
	var count: int = int(seconds * FPS)
	for i in range(count):
		# EASED AT BOTH ENDS: a dolly that starts and stops dead reads as a snap, not as a camera on a crane.
		var t: float = smoothstep(0.0, 1.0, float(i) / float(maxi(count - 1, 1)))
		_stand({
			"out": lerpf(float(a["out"]), float(b["out"]), t),
			"aft": lerpf(float(a["aft"]), float(b["aft"]), t),
			"up": lerpf(float(a["up"]), float(b["up"]), t),
			"at": lerpf(float(a["at"]), float(b["at"]), t),
			"fov": lerpf(float(a["fov"]), float(b["fov"]), t),
		}, 0.0)
		await get_tree().process_frame


func _aim(name: String, creep: float) -> bool:
	if not POSES.has(name):
		_check("the_film_names_a_pose_that_exists", false, name)
		return false
	_stand(POSES[name], creep)
	return true


## THE CAMERA, OFF THE LEAD BOAT'S POSE, this frame -- and off her FLATTENED axes, never her heeled ones. A camera hung
## off a leaning mast leans with it, and a horizon that leans with the boat shows no lean at all.
func _stand(pose: Dictionary, creep: float) -> void:
	var her: Transform3D = _boats[0].global_transform
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
	var drawn: Dictionary = _boats[0].drawn_pose()
	_leaned = maxf(_leaned, -float(drawn["drawn_heel_deg"]))
	if _caption != null:
		_caption.text = "%s and a Leigh 30 cutter  ·  wind %.0f m/s  ·  %.1f m/s through the water  ·  drawn lean %.1f deg" % [
			"a cruising sloop" if String(drawn["boat"]) == "cruising_sloop" else "a Leigh 30 cutter", WIND,
			float(drawn["speed"]), float(drawn["drawn_heel_deg"])]


## A STILL FROM THE SAME VIEWPORT the film is being recorded from, and the pose of every boat beside it, so a picture
## that looks wrong can be told apart from a boat that is.
func _photograph(name: String) -> void:
	for boat in _boats:
		var pose: Dictionary = boat.drawn_pose()
		print("[small_craft_reel] %s: %s heading %.0f, %.2f m/s, DRAWN heel %.1f deg, swell pitch %.1f deg" % [name,
			pose["boat"], float(pose["heading_deg"]), float(pose["speed"]), float(pose["drawn_heel_deg"]),
			float(pose["swell_pitch_deg"])])
	if _out == "":
		return
	var path: String = "%s/small-craft-%s.png" % [_out, name]
	_check("saved_%s" % name.replace("-", "_"), get_viewport().get_texture().get_image().save_png(path) == OK, path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
