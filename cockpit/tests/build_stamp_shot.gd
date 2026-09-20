extends Node
## THE BUILD STAMP, AS A PERSON SEES IT: the whole window with the stamp in the lower right, a close crop of the stamp,
## and the clipboard held up with the build line on its frame, saved as PNGs.
##
##   Godot --path cockpit --xr-mode off res://tests/build_stamp_shot.tscn -- --time=day --out=C:/somewhere
##   ... -- --time=night --out=C:/somewhere
##
## NOT HEADLESS: headless has no rendering device and every picture comes back black. A PROBE, because whether small
## light writing with a dark rim reads over a bright sky and a black sea is for eyes; `tests/build_stamp.gd` holds that
## it is there, on top, in the corner, and the right words. Walks to the island the way a player does -- the level's
## button on the desk, "Fly on your own" -- so the stamp is photographed over a real level, and the pictures are named
## for the `--time=` asked for, which the level reads itself.
##
## Read RESULT=, not the exit code.

const PATIENCE: int = 2400
## Frames flown before the pictures: the world built round the eye and the curtain gone.
const FLY_FRAMES: int = 240
## How much bigger the crop is drawn than the stamp, and how much picture round it.
const CROP_ZOOM: int = 3
const CROP_ROOM: int = 14

var _saved: Array[String] = []
var _failed: Array[String] = []


func _ready() -> void:
	if get_tree().current_scene != self:
		_run()
		return
	var watcher := Node.new()
	watcher.name = "StampShot"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	var out: String = _argument("--out=", ProjectSettings.globalize_path("user://build_stamp_shot"))
	var time: String = _argument("--time=", "day")
	DirAccess.make_dir_recursive_absolute(out)
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	await _to_the_desk()
	if time == "day":
		await _save_window(out.path_join("desk.png"))
	if not await _fly(ChartDrawer.DEFAULT):
		_failed.append("the island never came up")
		_finish()
		return
	var picture: Image = await _save_window(out.path_join("%s-window.png" % time))
	var at: Rect2i = BuildStamp.pixels().grow(CROP_ROOM).intersection(Rect2i(Vector2i.ZERO, picture.get_size()))
	if at.has_area():
		var crop: Image = picture.get_region(at)
		crop.resize(at.size.x * CROP_ZOOM, at.size.y * CROP_ZOOM, Image.INTERPOLATE_NEAREST)
		_keep(crop, out.path_join("%s-stamp-crop.png" % time))
	else:
		_failed.append("the stamp has no rect")
	# THE CLIPBOARD, UP, as M puts it up on a desk: the rig's own board.
	var board: Clipboard = null
	for node in get_tree().current_scene.find_children("*", "Node3D", true, false):
		if node is Clipboard:
			board = node
			break
	if board != null:
		board.show_board(true)
		await _save_window(out.path_join("%s-clipboard.png" % time))
		# AND AS THE HOLDING PLAYER SEES IT: an eye 40 cm straight out from the glass, the distance `tests/clipboard.gd`
		# reads the board from, square to it. The stamp in the corner is still the root's, so it is in this one too.
		var glass: Node3D = board.panel()
		var was: Camera3D = get_viewport().get_camera_3d()
		var eye := Camera3D.new()
		eye.fov = 40.0
		eye.near = 0.02
		glass.add_child(eye)
		eye.position = Vector3(0.0, -0.03, 0.40)
		eye.look_at(glass.to_global(Vector3(0.0, -0.03, 0.0)), glass.global_basis.y)
		eye.make_current()
		await _save_window(out.path_join("%s-clipboard-from-the-hand.png" % time))
		# AND WITH A HEADSET'S FIELD OF VIEW, from the same place: forty degrees is a reading crop, and a board half as
		# big again (2026-09-18) no longer fits it, where a headset's ninety-odd takes in the whole board and the hand.
		eye.fov = 90.0
		await _save_window(out.path_join("%s-clipboard-from-the-hand-headset.png" % time))
		if was != null:
			was.make_current()
		eye.queue_free()
	else:
		_failed.append("no clipboard in the level")
	_finish()


func _save_window(path: String) -> Image:
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	_keep(picture, path)
	return picture


func _keep(picture: Image, path: String) -> void:
	var err: int = picture.save_png(path)
	print("[build_stamp_shot] %d x %d, %s, %s" % [picture.get_width(), picture.get_height(), error_string(err), path])
	if err == OK:
		_saved.append(path.get_file())
	else:
		_failed.append("%s not saved" % path.get_file())


func _fly(id: String) -> bool:
	var desk := get_tree().current_scene as DeskRoom
	var panel := desk.get("_panel") as TouchPanel if desk != null else null
	var menu := panel.shown() as SessionMenu if panel != null else null
	var shelf := desk.get("_charts") as TouchPanel if desk != null else null
	var charts := shelf.shown() as ChartMenu if shelf != null else null
	if menu == null or charts == null or not charts.level_buttons.has(id):
		return false
	(charts.level_buttons[id] as Button).pressed.emit()
	for node in menu.find_children("*", "Button", true, false):
		if (node as Button).text == "Fly on your own":
			(node as Button).pressed.emit()
			break
	var up: bool = await _wait_for(func() -> bool:
		var level := get_tree().current_scene as FlightLevel
		return level != null and level.level != null and level.level.id == id and Sim.is_ready)
	for i in range(FLY_FRAMES):
		await get_tree().process_frame
	return up


func _to_the_desk() -> void:
	if not get_tree().current_scene is DeskRoom:
		Doors.to_the_desk()
	await _wait_for(func() -> bool:
		var desk := get_tree().current_scene as DeskRoom
		return desk != null and desk.get("_menu") != null)
	for i in range(30):
		await get_tree().process_frame


func _wait_for(until: Callable) -> bool:
	for i in range(PATIENCE):
		if until.call():
			return true
		await get_tree().process_frame
	return until.call()


func _argument(prefix: String, otherwise: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if String(argument).begins_with(prefix):
			return String(argument).substr(prefix.length())
	return otherwise


func _finish() -> void:
	Sim.stop()
	Net.leave("probe over")
	print("[build_stamp_shot] saved %s" % [_saved])
	if _failed.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failed))
	get_tree().quit(0 if _failed.is_empty() else 1)
