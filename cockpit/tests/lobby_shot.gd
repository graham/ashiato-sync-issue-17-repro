extends Node
## THE BRIEFING ROOM, AS A PLAYER SEES IT: three PNGs from inside the lobby level -- the standing eye where a player
## arrives, the same room from a high corner so the whole of it is in one frame, and a desk close enough to read the
## joystick and the buttons on it.
##
##   Godot --path cockpit res://tests/lobby_shot.tscn -- --out=C:/Users/Graham/godotgames-drafts/2026-09-15/cockpit-lobby
##
## NOT HEADLESS: headless has no rendering device and every picture comes back a black rectangle. A PROBE, because
## whether a room reads as a room -- lit, the right size, the marks and the desks where a person would look for them --
## has no assertion in it. `tests/lobby.gd` holds that the marks are where the arrivals are put, that the props are there
## and that the walls reach the simulation; this is what all of that looks like.
##
## THE FIRST PICTURE IS THE RIG'S OWN CAMERA, not a camera of the probe's: it is the level's own desk view, from the eye
## of the segway this machine was seated on, so what it shows is what a player standing there sees. The other two are the
## probe's own cameras, and say so.
##
## Read RESULT=, not the exit code.

const LEVEL := preload("res://world/sky.tscn")
const LOBBY: String = "lobby"
## Frames to wait for the level to build, the session to come up and the segway to settle onto the floor.
const PATIENCE: int = 1800
const SETTLE: int = 120

var _saved: Array[String] = []
var _failed: Array[String] = []


func _ready() -> void:
	var out: String = _out_folder()
	DirAccess.make_dir_recursive_absolute(out)
	var refusal: String = Net.choose_level(LOBBY)
	if refusal != "":
		print("[lobby_shot] RESULT=FAIL %s" % refusal)
		get_tree().quit(1)
		return
	var level := LEVEL.instantiate() as FlightLevel
	add_child(level)
	var up: bool = false
	for i in range(PATIENCE):
		if level.level != null and level.level.id == LOBBY and level.room != null and Sim.is_ready \
				and level.rig != null and level.rig.is_seated():
			up = true
			break
		await get_tree().physics_frame
	if not up:
		print("[lobby_shot] RESULT=FAIL the lobby never came up (level %s, room %s, ready %s)" % [
			level.level.id if level.level != null else "-", level.room, Sim.is_ready])
		get_tree().quit(1)
		return
	for i in range(SETTLE):
		await get_tree().physics_frame
	var chart: LevelChart = level.level
	var middle: Vector3 = BriefingRoom.middle_of(chart)
	print("[lobby_shot] standing in %s: %d marks, %d props, the room's middle at %s" % [chart.name,
		level.room.marks().size(), level.room.props().size(), middle])

	# 1: THE PLAYER'S OWN EYE, the rig's desktop camera, after pressing R.
	#
	# RECENTRED FIRST, and that is not tidying up: the desk camera is mouse-look, and for the few frames between the
	# level coming up and the launch board being handed to `PilotRig.pointer_panels` the mouse is still CAPTURED -- so
	# any motion of the real mouse in that window pitches the view, and a probe run twice gives two different pictures
	# (measured 2026-09-15: one run level, the next looking at the ceiling). `recentre` is what the R key does, so this
	# is a picture from a real control rather than from a camera the probe placed.
	level.rig.recentre()
	await _save_window(out.path_join("lobby_from_the_eye.png"))

	# 2: THE WHOLE ROOM, from a high corner of it, so the marks on the floor and the row of desks are in one frame.
	await _save_from(middle + Vector3(BriefingRoom.INSIDE.x * 0.75, BriefingRoom.INSIDE.y - 0.4,
		BriefingRoom.INSIDE.z * 0.8), middle + Vector3(0.0, 0.3, -2.0), 78.0,
		out.path_join("lobby_from_the_corner.png"), level)

	# 3: ONE DESK, from where a person standing at it would be looking: a stride back and at standing eye height.
	var desks: Array[Vector3] = BriefingRoom.desk_places(chart)
	var desk: Vector3 = desks[1] if desks.size() > 1 else middle
	await _save_from(desk + Vector3(0.0, 1.55, 0.85), desk + Vector3(0.0, BriefingRoom.DESK_TOP, 0.0), 55.0,
		out.path_join("lobby_a_desk.png"), level)

	print("[lobby_shot] saved %s" % [_saved])
	var ok: bool = _failed.is_empty() and _saved.size() == 3
	print("[lobby_shot] RESULT=%s %s" % ["PASS" if ok else "FAIL", ", ".join(_failed)])
	get_tree().quit(0 if ok else 1)


## A PICTURE FROM A CAMERA OF THE PROBE'S OWN, stood at `from` and looking at `at`: the rig's head handling would turn
## its own camera back between frames, so a view the rig does not know about gets a camera the rig does not own. The
## rig's camera is made current again afterwards.
func _save_from(from: Vector3, at: Vector3, fov: float, path: String, level: FlightLevel) -> void:
	var eye := Camera3D.new()
	add_child(eye)
	eye.global_position = from
	eye.look_at(at, Vector3.UP)
	eye.fov = fov
	eye.far = 400.0
	eye.make_current()
	await _save_window(path)
	eye.queue_free()
	if level.rig != null and level.rig.desktop_camera != null:
		level.rig.desktop_camera.make_current()


func _save_window(path: String) -> void:
	for i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var err: int = picture.save_png(path)
	print("[lobby_shot] %d x %d, %s, %s" % [picture.get_width(), picture.get_height(), error_string(err), path])
	if err == OK:
		_saved.append(path.get_file())
	else:
		_failed.append("%s not saved" % path.get_file())


func _out_folder() -> String:
	for argument in OS.get_cmdline_user_args():
		if String(argument).begins_with("--out="):
			return String(argument).substr(6)
	return ProjectSettings.globalize_path("user://lobby_shot")
