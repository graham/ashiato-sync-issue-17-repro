extends Node
## THE LEVELS, AS A PERSON SEES THEM: the desk's levels screen, the whole desk and that screen close from the seated eye,
## the words a refused joiner reads on the desk, and the clipboard's CREW page with the level at its head, saved as PNGs.
##
##   Godot --path cockpit res://tests/level_shot.tscn -- --out=C:/Users/Graham/godotgames-drafts/2026-09-15/cockpit-levels
##
## NOT HEADLESS: headless has no rendering device and every picture comes back black. A PROBE, because whether a level's
## name and summary read at a desk's distance has no assertion. tests/levels.gd holds that the row is there and chooses
## with a click; tests/level_hello.gd and tests/level_join.gd hold the refusal's words; this is what they look like.
##
## THE ROW TWICE: the game's own folder, which is what a player sees today, and the two-level fixture folder with the
## second chosen, which is what choosing looks like. THE REFUSAL IS A REAL ONE: `Net` joins a bare socket on the loopback
## and is told a different copy of the island, and the desk writes what `Net` says.
##
## Read RESULT=, not the exit code.

const DESK := preload("res://world/desk.tscn")
const FIXTURES: String = "res://tests/level_fixtures"
## A port of the lane's own range.
## 47958 of this checkout's block (`TestPorts`), asked silently at load whether anything holds it: a fixed
## number was the same socket in every lane. Held, and the suite says PORT BUSY at once rather than timing out.
static var PORT: int = TestPorts.first_free(47958, 1)

var _saved: Array[String] = []
var _failed: Array[String] = []


func _ready() -> void:
	if PORT == 0:
		print("RESULT=FAIL port_busy %s" % TestPorts.busy(47958, 1))
		get_tree().quit(1)
		return
	var out: String = _out_folder()
	DirAccess.make_dir_recursive_absolute(out)

	# 1: THE GAME'S OWN LEVELS, on the levels screen, and from the seated eye: the whole desk, then that screen close.
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	Net.choose_level(ChartDrawer.DEFAULT)
	var desk := DESK.instantiate() as DeskRoom
	add_child(desk)
	await _frames(8)
	var panel := desk.get("_charts") as TouchPanel
	var sessions := desk.get("_panel") as TouchPanel
	await _save_glass(panel, out.path_join("desk_levels_screen.png"))
	await _save_glass(sessions, out.path_join("desk_session_screen.png"))
	await _save_glass(desk.get("_doors") as TouchPanel, out.path_join("desk_doors_screen.png"))
	# THE ARC IS WIDER THAN ONE PICTURE: from the eye an end screen's outer corner is 72 degrees off straight ahead, which
	# a head turns to and a flat frame cannot hold. So the eye's own picture, as wide as it will go, and one from 40 cm
	# behind the eye, which takes in the whole desk.
	await _save_from_the_eye(desk, sessions, 100.0, 0.0, out.path_join("desk_from_the_chair.png"))
	await _save_from_the_eye(desk, sessions, 70.0, 0.40, out.path_join("desk_from_behind_the_chair.png"))
	await _save_from_the_eye(desk, panel, 34.0, 0.0, out.path_join("desk_levels_screen_from_the_chair.png"))

	# 2: THE OTHER LEVEL CHOSEN, the way a player chooses it: `Net` told, and the desk shown what `Net` has.
	var other: String = ChartDrawer.charts().back().id
	Net.choose_level(other)
	desk.call("_show_the_levels")
	await _frames(4)
	await _save_glass(panel, out.path_join("desk_levels_screen_%s_chosen.png" % other))
	await _save_from_the_eye(desk, sessions, 70.0, 0.40, out.path_join("desk_from_behind_the_chair_%s_chosen.png" % other))
	await _save_from_the_eye(desk, panel, 34.0, 0.0, out.path_join("desk_levels_screen_from_the_chair_%s_chosen.png"
		% other))

	# 2b: A FOLDER OF THE FIXTURES' LEVELS, THE SECOND CHOSEN, which is what a longer list looks like.
	ChartDrawer.open_at(FIXTURES)
	Net.choose_level("good_b")
	desk.call("_show_the_levels")
	await _frames(4)
	await _save_glass(panel, out.path_join("desk_levels_screen_fixtures_second_chosen.png"))

	# 3: A JOIN REFUSED, as the desk writes it: a bare host, and a hello naming another copy of the island.
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	Net.choose_level(ChartDrawer.DEFAULT)
	desk.call("_show_the_levels")
	var host := ENetMultiplayerPeer.new()
	host.create_server(PORT, 4)
	var heard: Array[String] = []
	var listening := func(text: String) -> void: heard.append(text)
	Net.session_message.connect(listening)
	Net.join("127.0.0.1", PORT)
	for i in range(600):
		host.poll()
		if heard.has("Connected. Asking the host which level..."):
			break
		await get_tree().physics_frame
	var island: LevelChart = ChartDrawer.chart(ChartDrawer.DEFAULT)
	Net.hear_hello(1, JSON.stringify({"say": "level", "protocol": Net.PROTOCOL, "level": island.id,
		"hash": "0".repeat(64), "name": island.name}).to_utf8_buffer())
	Net.session_message.disconnect(listening)
	await _frames(4)
	var said: String = heard.back() if not heard.is_empty() else ""
	if said != "The host's copy of The island is not the same as yours.":
		_failed.append("the refusal read '%s'" % said)
	await _save_glass(sessions, out.path_join("desk_join_refused.png"))
	for i in range(10):
		host.poll()
		await get_tree().physics_frame
	host.close()
	desk.queue_free()
	await _frames(2)

	# 4: THE CLIPBOARD'S CREW PAGE, with the level at its head, on the glass the board is drawn at.
	var board := TouchPanel.new()
	board.page = preload("res://ui/menus/clipboard_page.tscn")
	board.size = Vector2(0.34, 0.25)
	board.pixels = 1024
	add_child(board)
	await _frames(2)
	var page := board.shown() as ClipboardPage
	page.show_tab(ClipboardPage.Tab.CREW)
	page.refresh()
	await _save_glass(board, out.path_join("clipboard_crew_level.png"))

	print("[level_shot] saved %s" % [_saved])
	var ok: bool = _failed.is_empty() and _saved.size() == 12
	print("[level_shot] RESULT=%s %s" % ["PASS" if ok else "FAIL", ", ".join(_failed)])
	get_tree().quit(0 if ok else 1)


func _save_glass(panel: TouchPanel, path: String) -> void:
	var screen := panel.get("_screen") as SubViewport
	# THE BUILD STAMP IN THE PAGE'S LOWER RIGHT: a picture of a page is a screenshot too (`BuildStamp`, 2026-09-18).
	BuildStamp.attach_to(screen)
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await _frames(10)
	await RenderingServer.frame_post_draw
	_keep(screen.get_texture().get_image(), path)


## FROM THE SEATED EYE, turned to look at `panel`: a camera of the probe's own, stood where the rig's desktop eye is, so
## the rig's head handling cannot turn it back between frames. A wide `fov` takes in the desk; a narrow one, one screen.
## `behind` moves the camera that far back from the eye, away from the desk, along the floor.
func _save_from_the_eye(desk: DeskRoom, panel: TouchPanel, fov: float, behind: float, path: String) -> void:
	var rig := desk.get("_rig") as PilotRig
	var eye := Camera3D.new()
	add_child(eye)
	eye.global_position = rig.desktop_camera.global_position + desk.global_basis.z.normalized() * behind
	eye.look_at(panel.global_position, Vector3.UP)
	eye.fov = fov
	eye.make_current()
	await _save_window(path)
	rig.desktop_camera.make_current()
	eye.queue_free()


func _save_window(path: String) -> void:
	await _frames(10)
	await RenderingServer.frame_post_draw
	_keep(get_viewport().get_texture().get_image(), path)


func _keep(picture: Image, path: String) -> void:
	var err: int = picture.save_png(path)
	print("[level_shot] %d x %d, %s, %s" % [picture.get_width(), picture.get_height(), error_string(err), path])
	if err == OK:
		_saved.append(path.get_file())
	else:
		_failed.append("%s not saved" % path.get_file())


func _out_folder() -> String:
	for argument in OS.get_cmdline_user_args():
		if String(argument).begins_with("--out="):
			return String(argument).substr(6)
	return ProjectSettings.globalize_path("user://level_shot")


func _frames(how_many: int) -> void:
	for i in range(how_many):
		await get_tree().process_frame
