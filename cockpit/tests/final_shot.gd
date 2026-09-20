extends Node
## THE ISLAND STRIP'S FINAL, SEEN: down it from 5 km out at the glide path's own height, an oblique view from outside the corridor,
## and straight down on the notch the keep-out cut (lane/throughrock, 2026-09-19).
##
##   Godot --path cockpit --fixed-fps 60 --resolution 1280x720 res://tests/final_shot.tscn -- --level=watch --clouds=none --out=C:/somewhere --prefix=after
##
## NOT HEADLESS. Viewport only: it saves the viewport's own image and never the desktop. `--prefix` names the run ("before"
## with the keep-out taken out, "after" with it), so the two sit side by side.

var _out: String = "user://final_shots"
var _prefix: String = "shot"
var _level: FlightLevel = null
var _failures: PackedStringArray = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--prefix="):
			_prefix = argument.trim_prefix("--prefix=")
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	await _frames(90)
	var words := _level.get_node_or_null("Ui") as CanvasLayer
	if words != null:
		words.visible = false
	for board in _level.observer.find_children("*", "CanvasItem", true, false):
		(board as CanvasItem).visible = false
	var field: Dictionary = Airfield.named("island_strip")
	_check("the_island_strip_is_laid", not field.is_empty(), "")
	if field.is_empty():
		_finish()
		return
	var p: TrafficPattern = Airfield.pattern_for(field, Sim.Kind.JUMBO)
	var ifr := InstrumentApproach.make(p, Airfield.numbers_of(Sim.Kind.JUMBO))
	var camera: Camera3D = _level.observer
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 55.0
	camera.far = 30000.0
	# DOWN THE FINAL: 5 km out on the centreline, at the path's own height, looking at the threshold.
	var out5: Vector3 = p.point(-5000.0, 0.0)
	out5.y = ifr.final_height(out5)
	var threshold: Vector3 = p.point(0.0, 0.0) + Vector3.UP * 20.0
	camera.look_from(out5, threshold)
	await _frames(60)
	_save("down-the-final")
	# OBLIQUE, from the south-west and high, so the corridor runs away from the eye between the ranges either side: the
	# notch is judged as landform here, and not as a rectangle.
	var middle: Vector3 = p.point(-2600.0, 0.0)
	camera.look_from(middle + Vector3(-2600.0, 1500.0, -3600.0), middle + Vector3(0.0, 0.0, 400.0))
	await _frames(60)
	_save("oblique")
	# AND STRAIGHT DOWN, the corridor in the middle, five kilometres across.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5200.0
	camera.far = 8000.0
	var centre: Vector3 = p.point(-2800.0, 0.0) * Vector3(1, 0, 1)
	camera.look_from(centre + Vector3.UP * 3000.0, centre + Vector3(0.0, 0.0, -0.001))
	await _frames(60)
	_save("from-above")
	_finish()


func _save(label: String) -> void:
	var path: String = _out.path_join("%s-%s.png" % [_prefix, label])
	_check("saved_%s" % label, get_viewport().get_texture().get_image().save_png(path) == OK, path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _check(label: String, ok: bool, detail: String) -> void:
	print("[final_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _finish() -> void:
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
