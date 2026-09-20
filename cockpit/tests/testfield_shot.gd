extends Node
## THE TEST FIELD, LOOKED AT: the no-sea level from the air, for eyes and for the user's proof.
##
##   Godot --path cockpit --resolution 1600x900 --xr-mode off res://tests/testfield_shot.tscn -- --level=watch
##       --clouds=none --scene=look --out=C:/somewhere
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (seeing_the_game.md). Whether the level stands,
## has no sea and keeps every final clear is tests/testfield.gd's; this is for eyes. NEVER A CAPTURE OF THE DESKTOP: every
## picture is the viewport's own image.
##
## `--scene=look`: stills from the air, each `testfield-look-<name>.png` in `--out` -- each of the four fields from a
## kilometre or two up (the west airport's parallels, the east airport's crossing, the air base, the small field) and a
## high oblique from the south with the west airport and the air base in one frame, 25 km off; and the level's own
## mountains, the lone peak with the northern ridge behind it from West, and the air base under its ridge.

## THE VIEWS: the camera's place and what it looks at, world metres, and its field of view.
const LOOKS: Array[Dictionary] = [
	{"name": "west", "from": Vector3(-15600.0, 1300.0, 3600.0), "at": Vector3(-18000.0, 0.0, 0.0), "fov": 55.0},
	{"name": "east", "from": Vector3(14200.0, 1400.0, 2600.0), "at": Vector3(16600.0, 0.0, -700.0), "fov": 55.0},
	{"name": "base", "from": Vector3(1600.0, 1000.0, -11800.0), "at": Vector3(0.0, 0.0, -14200.0), "fov": 55.0},
	{"name": "small-field", "from": Vector3(3400.0, 700.0, 14600.0), "at": Vector3(2000.0, 0.0, 13000.0), "fov": 55.0},
	{"name": "mountains-west", "from": Vector3(-16500.0, 1100.0, 3500.0), "at": Vector3(-6000.0, 450.0, -9000.0), "fov": 55.0},
	{"name": "mountains-base", "from": Vector3(2500.0, 1300.0, -6500.0), "at": Vector3(-3000.0, 350.0, -18500.0), "fov": 55.0},
	{"name": "two-airports", "from": Vector3(-1000.0, 7000.0, 17000.0), "at": Vector3(-9000.0, 0.0, -6000.0), "fov": 60.0},
]
## Frames given to the ground and its scenery to stream in round a new eye before the picture.
const SETTLE: int = 240

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://testfield_shot"
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
	var chosen: String = Net.choose_level("testfield")
	_check("the_test_field_can_be_chosen", chosen == "", chosen)
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
	_finish()


func _look() -> void:
	var camera: Camera3D = _level.observer
	for look in LOOKS:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = look["fov"]
		var at: Vector3 = look["at"]
		at.y = Terrain.ground_height(at)
		var from: Vector3 = look["from"]
		from.y += Terrain.ground_height(from)
		camera.look_from(from, at)
		await _frames(SETTLE)
		_save("testfield-look-%s" % look["name"])


func _save(name: String) -> void:
	var path: String = _out.path_join(name + ".png")
	_check("saved_%s" % name, get_viewport().get_texture().get_image().save_png(path) == OK, path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _check(label: String, ok: bool, detail: String) -> void:
	print("[testfield_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _finish() -> void:
	Net.choose_level(ChartDrawer.DEFAULT)
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
