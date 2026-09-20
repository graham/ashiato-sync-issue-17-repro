extends Node
## ONE SEA IN TWO COLOURS, SIDE BY SIDE: the real ocean sheet, dressed through `WaterSurface`, once as a warm
## Mediterranean and once as a cold northern coast.
##
##   Godot --path cockpit --xr-mode off --resolution 1600x800 res://tests/water_colour_shot.tscn -- --level=watch
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device. The gate holds the colours as numbers
## (`tests/water_surfaces.gd`, `tests/levels.gd`); this is the picture that proves a level's `water` key is visible.
##
## THE PLACE IS ocean_shot's open sea, off the island's +x side, so nothing but water is in frame. The same camera,
## the same TIME, two charts; only the three colour uniforms change, because `WaterSurface.dressed` is the one place
## any water is dressed and a second way to paint it would be a second blue.
##
## Pictures in `--out`: `water-warm.png`, `water-cold.png`, `water-warm-and-cold.png`.

const SETTLE: int = 90
const SEA := Vector3(10500.0, 0.0, 1500.0)
const WARM := {"deep": Vector3(0.012, 0.078, 0.102), "crest": Vector3(0.035, 0.155, 0.140),
	"foam": Vector3(0.88, 0.93, 0.92)}
const COLD := {"deep": Vector3(0.008, 0.022, 0.048), "crest": Vector3(0.04, 0.08, 0.11),
	"foam": Vector3(0.86, 0.90, 0.94)}

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = ""


func _check(label: String, ok: bool, detail: String) -> void:
	print("[water_colour] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://").get_base_dir().path_join("screenshots").path_join("2026-09-19")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	await _frames(60)
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var finish: Node = get_node("/root/Finish")
	if finish != null:
		finish.call("choose", false)
	_pose()
	await _frames(SETTLE)
	var warm: LevelChart = _chart_with(WARM)
	var cold: LevelChart = _chart_with(COLD)
	_wear(warm)
	_pose()
	await _frames(SETTLE)
	var warm_picture: Image = get_viewport().get_texture().get_image()
	_save(warm_picture, "water-warm")
	_wear(cold)
	_pose()
	await _frames(SETTLE)
	var cold_picture: Image = get_viewport().get_texture().get_image()
	_save(cold_picture, "water-cold")
	var side: Image = _beside(warm_picture, cold_picture)
	_save(side, "water-warm-and-cold")
	_check("the_two_seas_are_not_the_same_picture", not _same_picture(warm_picture, cold_picture),
		"%dx%d" % [warm_picture.get_width(), warm_picture.get_height()])
	_finish()


func _chart_with(colours: Dictionary) -> LevelChart:
	var named := LevelChart.new()
	var water := {}
	for field in colours:
		var rgb: Vector3 = colours[field]
		water[field] = [rgb.x, rgb.y, rgb.z]
	named._take({"name": "A sea", "summary": "A sea of one colour.", "world": "island",
		"spawn": {"at": [0, 30, 0], "yaw_degrees": 0}, "water": water})
	return named


func _wear(chart: LevelChart) -> void:
	var worn: int = 0
	for node in _level.find_children("*", "GeometryInstance3D", true, false):
		var mesh := node as GeometryInstance3D
		if not WaterSurface.is_water(mesh.material_override):
			continue
		var fine: bool = (mesh.material_override as ShaderMaterial).shader == WaterSurface.FINE
		WaterSurface.wear(mesh, fine, chart)
		worn += 1
	_check("water_was_there_to_colour", worn > 0, "%d surfaces" % worn)


func _pose() -> void:
	var eye: Camera3D = _level.observer
	eye.fov = 70.0
	var at: Vector3 = SEA + Vector3.UP * 200.0
	var ahead := Vector3(1.0, 0.0, 0.0) * cos(deg_to_rad(-20.0)) + Vector3.UP * sin(deg_to_rad(-20.0))
	_level.observer.call("look_from", at, at + ahead * 1000.0)


func _beside(left: Image, right: Image) -> Image:
	var out := Image.create(left.get_width() + right.get_width(), maxi(left.get_height(), right.get_height()),
		false, left.get_format())
	out.blit_rect(left, Rect2i(Vector2i.ZERO, left.get_size()), Vector2i.ZERO)
	out.blit_rect(right, Rect2i(Vector2i.ZERO, right.get_size()), Vector2i(left.get_width(), 0))
	return out


func _same_picture(a: Image, b: Image) -> bool:
	if a.get_size() != b.get_size():
		return false
	var different: int = 0
	for y in range(0, a.get_height(), 8):
		for x in range(0, a.get_width(), 8):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				different += 1
	return different == 0


func _save(picture: Image, name: String) -> void:
	var path: String = _out.path_join(name + ".png")
	_check("saved_%s" % name, picture.save_png(path) == OK, path)
	print("[water_colour] wrote %s" % path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
