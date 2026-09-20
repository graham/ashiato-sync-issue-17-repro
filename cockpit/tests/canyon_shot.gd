extends Node
## THE GORGE, LOOKED AT: a river in a canyon, from the air and from inside it (lane/rivers, 2026-09-20).
##
##   Godot --path cockpit --resolution 1600x900 --xr-mode off res://tests/canyon_shot.tscn -- --level=watch
##       --out=C:/somewhere
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (seeing_the_game.md). Whether the canyon is
## as deep as the level asked, whether its floor is flyable and whether a fighter in it is concealed are numbers, and
## they are `tests/canyon.gd`'s. This is the half of it no suite can have: whether a canyon with a river in the bottom
## LOOKS like one. NEVER A CAPTURE OF THE DESKTOP: every picture is the viewport's own image.
##
## The views run down the gorge -- the whole length from high up, the walls from the rim, and four from inside at the
## height a fighter would fly it, which is the shot that says whether this was worth building.

## THE VIEWS: the camera's place and what it looks at, world metres, and its field of view.
## from.y is a HEIGHT OVER THE SURFACE, as the test field's shots are, so a hill under the eye does not bury it.
const LOOKS: Array[Dictionary] = [
	{"name": "whole", "from": Vector3(-11800.0, 4200.0, -11500.0), "at": Vector3(-11800.0, 0.0, -1000.0), "fov": 60.0},
	{"name": "rim", "from": Vector3(-12900.0, 340.0, -4200.0), "at": Vector3(-12400.0, 0.0, -4200.0), "fov": 60.0},
	{"name": "down", "from": Vector3(-12400.0, 900.0, -4600.0), "at": Vector3(-11900.0, 0.0, -1400.0), "fov": 55.0},
	{"name": "inside-north", "from": Vector3(-12400.0, 60.0, -4200.0), "at": Vector3(-11900.0, 40.0, -1200.0), "fov": 70.0},
	{"name": "inside-south", "from": Vector3(-11800.0, 60.0, -1000.0), "at": Vector3(-12350.0, 40.0, -4000.0), "fov": 70.0},
	{"name": "inside-bend", "from": Vector3(-12200.0, 55.0, 2200.0), "at": Vector3(-11400.0, 40.0, 4600.0), "fov": 70.0},
	{"name": "water", "from": Vector3(-11800.0, 14.0, -1000.0), "at": Vector3(-11950.0, 6.0, -2400.0), "fov": 65.0},
]
## Frames given to the ground and its scenery to stream in round a new eye before the picture.
const SETTLE: int = 240

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://canyon_shot"
var _scene: String = "look"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--scene="):
			_scene = argument.trim_prefix("--scene=")
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var chosen: String = Net.choose_level("canyon")
	_check("the_gorge_can_be_chosen", chosen == "", chosen)
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	while _level.ground_built_msec < 0.0 or not Sim.is_ready:
		await _frames(1)
	await _frames(60)
	var words := _level.get_node_or_null("Ui") as CanvasLayer
	if words != null:
		words.visible = false
	for board in _level.observer.find_children("*", "CanvasItem", true, false):
		(board as CanvasItem).visible = false
	if _scene == "look":
		await _look()
	else:
		_check("the_scene_is_one_this_probe_draws", false, "'%s': look" % _scene)
	_finish()


func _look() -> void:
	var camera: Camera3D = _level.observer
	for look in LOOKS:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = look["fov"]
		var at: Vector3 = look["at"]
		at.y = maxf(at.y, Terrain.surface_height(at))
		var from: Vector3 = look["from"]
		from.y += Terrain.surface_height(from)
		camera.look_from(from, at)
		await _frames(SETTLE)
		_save("canyon-look-%s" % look["name"])


func _save(name: String) -> void:
	var path: String = _out.path_join(name + ".png")
	_check("saved_%s" % name, get_viewport().get_texture().get_image().save_png(path) == OK, path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _check(label: String, ok: bool, detail: String) -> void:
	print("[canyon_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _finish() -> void:
	Net.choose_level(ChartDrawer.DEFAULT)
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
