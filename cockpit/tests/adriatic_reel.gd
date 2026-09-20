extends Node
## A FILM OF THE ADRIATIC, IN THE REAL LEVEL: the archipelago from the air, fixed plates cut against moving
## cameras, recorded by MovieWriter from this probe's own viewport.
##
##   <editor>.console.exe --path cockpit --xr-mode off --desktop-only --resolution 1600x900 \
##       --write-movie <out.avi> --fixed-fps 30 res://tests/adriatic_reel.tscn -- --level=watch
##
## NOT `craft_video_demo.gd`, AND THIS IS THE WHOLE REASON THIS FILE EXISTS. That tool says so in its own doc --
## "the stage has no FlightLevel" -- because it builds a small bench with a water plane (`CockpitBench.STAGE_WATER`)
## to photograph one craft against. A bench has no islands, no forest, no mountains and no sea but its own, and it
## parses no `--world`, so an argument naming a level is accepted by the script that launches it and then silently
## dropped. Three clips were filmed that way on 2026-09-19 and read as an empty sea, and the emptiness was taken for
## a dull level rather than for no level at all. The user spotted it: "we have much more detailed levels in the repo
## are you sure you're using your adriatic level?" They were right. This probe stands the REAL `FlightLevel` up, the
## way `tests/warthog_reel.gd` does, and films that.
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (`seeing_the_game.md`). Whether the level
## stands at all is `tests/adriatic.gd`'s job; this is for eyes.
##
## NEVER A CAPTURE OF THE DESKTOP. MovieWriter records this probe's own viewport and nothing else.
##
## THE VIEWPOINTS ARE NOT RETYPED. Every fixed plate is a row of `adriatic_shot.gd`'s `LOOKS` table, read from that
## script, because those ten were chosen by looking and are the ones already proven to frame something -- the cove,
## the 17.5 m needle channel, the 8.3 m fangs, the three sisters. One number, one place: a viewpoint improved there
## improves the film here, and the two can never drift apart.
##
## WHY EACH SHOT IS SLOW. A landscape needs seconds to read, and a cut that teleports the camera ten kilometres
## arrives before the scenery has streamed in round the new eye. So the film is ordered to walk the map rather than
## jump about it, every shot opens with the camera already in place for `SETTLE` frames before it starts to move,
## and the moving shots are eased at both ends rather than starting and stopping dead.

## The probe this film borrows its viewpoints from. `LOOKS` is that script's own constant, so there is one table.
const SHOT: GDScript = preload("res://tests/adriatic_shot.gd")

## Frames held at a new eye before a shot begins, so the ground and its trees are in round it.
##
## SMALL, BECAUSE THE RECORDER IS RUNNING. The still probe can afford 240 frames at each eye because it throws them
## away and keeps one picture. Here every settle frame is IN THE FILM, as a frozen camera the viewer sits through:
## at 45 frames a shot that was 450 frames, fifteen seconds of dead air in a seventy-six second film, and it showed
## up as a unique-frame ratio of 62.7% when the rule of the house is 90% (2026-09-19). The film walks the map rather
## than jumping about it, so twelve frames is enough for the ground to catch up.
const SETTLE: int = 12
## HOW FAR A FIXED PLATE CREEPS over its own length, as a share of the distance to what it is looking at. A locked-off
## camera is not a still photograph: the sea moves under it and the clouds move over it, but a camera that is exactly
## still for six seconds reads as a freeze and encodes as one. A creep this small is not seen as movement -- it is
## seen as the shot being alive.
const CREEP: float = 0.035
## Frames a second, which must match the `--fixed-fps` the recorder is given or the film runs at the wrong speed.
const FPS: float = 30.0

## THE FILM. `hold` is a fixed plate on the named viewpoint; `move` eases from one viewpoint's camera to another's,
## which is a dolly when they differ in place and a crane when they differ in height. `seconds` is screen time.
## Fixed and moving alternate on purpose (the user, 2026-09-19: "use a combo of fixed camera and moving camera,
## that way it's more cinematic").
const FILM: Array[Dictionary] = [
	{"kind": "hold", "look": "whole", "seconds": 6.0},
	{"kind": "move", "from": "whole", "to": "across", "seconds": 9.0},
	{"kind": "hold", "look": "cove", "seconds": 6.0},
	{"kind": "move", "from": "cove", "to": "woods", "seconds": 8.0},
	{"kind": "hold", "look": "sisters", "seconds": 6.0},
	{"kind": "move", "from": "needles-high", "to": "needles", "seconds": 9.0},
	{"kind": "move", "from": "needles", "to": "low-pass", "seconds": 8.0},
	{"kind": "hold", "look": "east-pine", "seconds": 6.0},
	{"kind": "move", "from": "east-pine", "to": "fangs", "seconds": 9.0},
	{"kind": "move", "from": "across", "to": "whole", "seconds": 9.0},
]

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _looks: Dictionary = {}


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	for look in SHOT.LOOKS:
		_looks[String(look["name"])] = look
	var chosen: String = Net.choose_level("adriatic")
	_check("the_adriatic_can_be_chosen", chosen == "", chosen)
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	while _level.ground_built_msec < 0.0 or not Sim.is_ready:
		await _frames(1)
	await _frames(90)
	_hide_the_writing()
	await _roll()
	_finish()


## THE HUD AND THE OBSERVER'S BOARDS COME OFF. A film wants the world, not the frame counter over it.
func _hide_the_writing() -> void:
	var words := _level.get_node_or_null("Ui") as CanvasLayer
	if words != null:
		words.visible = false
	for board in _level.observer.find_children("*", "CanvasItem", true, false):
		(board as CanvasItem).visible = false


func _roll() -> void:
	var seconds_filmed: float = 0.0
	for shot in FILM:
		var kind: String = String(shot["kind"])
		var seconds: float = float(shot["seconds"])
		if kind == "hold":
			await _hold(String(shot["look"]), seconds)
		else:
			await _move(String(shot["from"]), String(shot["to"]), seconds)
		seconds_filmed += seconds
		print("[adriatic_reel] %s %s %.1f s" % [kind, shot.get("look", "%s to %s" % [shot.get("from"), shot.get("to")]), seconds])
	_check("the_film_is_long_enough", seconds_filmed >= 60.0, "%.1f s" % seconds_filmed)
	print("[adriatic_reel] %.1f seconds at %d fps" % [seconds_filmed, int(FPS)])


## A FIXED PLATE: the camera stands where it is put and creeps toward what it is watching by `CREEP` over the shot.
func _hold(name: String, seconds: float) -> void:
	if not _aim(name):
		return
	await _frames(SETTLE)
	var look: Dictionary = _looks[name]
	var eye: Vector3 = _eye(look["from"])
	var target: Vector3 = _target(look["at"])
	var camera: Camera3D = _level.observer
	var count: int = int(seconds * FPS)
	for i in range(count):
		var t: float = float(i) / float(maxi(count - 1, 1))
		camera.look_from(eye.lerp(target, CREEP * t), target)
		await get_tree().process_frame


func _move(from_name: String, to_name: String, seconds: float) -> void:
	if not (_looks.has(from_name) and _looks.has(to_name)):
		_check("the_film_names_a_viewpoint_that_exists", false, "%s to %s" % [from_name, to_name])
		return
	_aim(from_name)
	await _frames(SETTLE)
	var a: Dictionary = _looks[from_name]
	var b: Dictionary = _looks[to_name]
	var a_from: Vector3 = _eye(a["from"])
	var b_from: Vector3 = _eye(b["from"])
	var a_at: Vector3 = _target(a["at"])
	var b_at: Vector3 = _target(b["at"])
	var camera: Camera3D = _level.observer
	var count: int = int(seconds * FPS)
	for i in range(count):
		# EASED AT BOTH ENDS. A dolly that starts and stops dead reads as a snap, not as a camera on a crane.
		var t: float = smoothstep(0.0, 1.0, float(i) / float(maxi(count - 1, 1)))
		camera.fov = lerpf(float(a["fov"]), float(b["fov"]), t)
		camera.look_from(a_from.lerp(b_from, t), a_at.lerp(b_at, t))
		await get_tree().process_frame


## A VIEWPOINT'S EYE IN WORLD METRES. `from.y` in the table is a HEIGHT OVER THE SURFACE, as the still probe reads
## it, so a hill under the camera lifts it rather than swallowing it.
func _eye(from: Vector3) -> Vector3:
	var eye: Vector3 = from
	eye.y += Terrain.surface_height(from)
	return eye


## WHAT IT LOOKS AT, never below the surface under that point.
func _target(at: Vector3) -> Vector3:
	var target: Vector3 = at
	target.y = maxf(target.y, Terrain.surface_height(at))
	return target


func _aim(name: String) -> bool:
	if not _looks.has(name):
		_check("the_film_names_a_viewpoint_that_exists", false, name)
		return false
	var look: Dictionary = _looks[name]
	var camera: Camera3D = _level.observer
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = float(look["fov"])
	camera.look_from(_eye(look["from"]), _target(look["at"]))
	return true


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _check(label: String, ok: bool, detail: String) -> void:
	print("[adriatic_reel] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _finish() -> void:
	Net.choose_level(ChartDrawer.DEFAULT)
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
