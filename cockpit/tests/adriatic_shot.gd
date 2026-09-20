extends Node
## THE ADRIATIC, LOOKED AT: the archipelago from the air, for eyes and for the user's proof.
##
##   Godot --path cockpit --resolution 1600x900 --xr-mode off res://tests/adriatic_shot.tscn -- --level=watch --time=evening
##       --out=C:/somewhere
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (seeing_the_game.md). Whether the level stands,
## has a sea and a Savoia in the cove is tests/adriatic.gd's; this is for eyes. NEVER A CAPTURE OF THE DESKTOP: every
## picture is the viewport's own image.
##
## `--scene=look`: stills from the air, each `adriatic-look-<name>.png` in `--out` -- the whole thirty-two kilometres from
## the south, the cove a seaplane takes off from, the needle channel and the twin fangs (the fly-throughs), the three
## sisters, a wooded island, and a low pass at 15 m between the needles.

## THE VIEWS: the camera's place and what it looks at, world metres, and its field of view.
## from.y is a HEIGHT OVER THE SURFACE, as the test field's shots are, so a hill under the eye does not bury it.
const LOOKS: Array[Dictionary] = [
	{"name": "whole", "from": Vector3(0.0, 5500.0, 14000.0), "at": Vector3(0.0, 0.0, 0.0), "fov": 60.0},
	{"name": "across", "from": Vector3(11000.0, 700.0, 11000.0), "at": Vector3(2000.0, 40.0, 2000.0), "fov": 55.0},
	{"name": "cove", "from": Vector3(2800.0, 180.0, 2200.0), "at": Vector3(5200.0, 4.0, 4200.0), "fov": 65.0},
	{"name": "woods", "from": Vector3(-2500.0, 90.0, -3000.0), "at": Vector3(-3780.0, 25.0, -4313.0), "fov": 60.0},
	{"name": "needles", "from": Vector3(9200.0, 40.0, 8268.0), "at": Vector3(10000.0, 80.0, 8268.0), "fov": 55.0},
	{"name": "needles-high", "from": Vector3(8600.0, 280.0, 7800.0), "at": Vector3(10000.0, 80.0, 8268.0), "fov": 50.0},
	{"name": "fangs", "from": Vector3(-12800.0, 35.0, -2854.0), "at": Vector3(-13500.0, 70.0, -2854.0), "fov": 50.0},
	{"name": "sisters", "from": Vector3(-5600.0, 220.0, 12320.0), "at": Vector3(-7200.0, 80.0, 12320.0), "fov": 55.0},
	{"name": "east-pine", "from": Vector3(11000.0, 250.0, 400.0), "at": Vector3(13000.0, 40.0, 400.0), "fov": 55.0},
	{"name": "low-pass", "from": Vector3(9700.0, 15.0, 8268.0), "at": Vector3(10300.0, 40.0, 8268.0), "fov": 70.0},
]
## Frames given to the ground and its scenery to stream in round a new eye before the picture.
const SETTLE: int = 240

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://adriatic_shot"
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
		_save("adriatic-look-%s" % look["name"])


func _save(name: String) -> void:
	var path: String = _out.path_join(name + ".png")
	_check("saved_%s" % name, get_viewport().get_texture().get_image().save_png(path) == OK, path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _check(label: String, ok: bool, detail: String) -> void:
	print("[adriatic_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _finish() -> void:
	Net.choose_level(ChartDrawer.DEFAULT)
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
