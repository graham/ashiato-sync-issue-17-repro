extends Node
## THE HOST CHANGES THE LEVEL, FROM THE CLIENT'S SEAT: three PNGs of the same joined player -- briefing room, fully black
## persistent curtain, and island -- with nothing pressed on this machine in between.
##
##   Godot --path cockpit res://tests/level_change_shot.tscn -- --out=C:/Users/Graham/godotgames-drafts/2026-09-16/cockpit-lobby
##
## NOT HEADLESS: headless has no rendering device and every picture comes back a black rectangle. A PROBE, because what
## it shows -- that a player who pressed nothing is somewhere else now -- has no assertion in it beyond the ones
## `tests/no_vr_flight.gd` and `tests/level_hello.gd` already make. This is what those look like from the seat.
##
## THE PAIR IS THE POINT. One picture of a briefing room and one of an island prove nothing on their own; the same
## client, in one session, on one socket, before and after its host pressed a level, is item 11 in two frames.
##
## THE HOST IS A CHILD, started with `--host=PORT --launch=island:SECONDS --report=1`: it waits that many seconds after
## a second player appears before pressing the island on its own launch board, which is the window this probe uses to
## take the first picture. This machine joins through the desk exactly as a person does -- the address typed into the
## real field, the real Join button pressed.
##
## THIS CHECKOUT'S PORTS (`TestPorts`), the first free one asked silently before a child starts, from these:
## PORTS 47966-47969, shared with tests/no_vr_flight.gd, which never runs at the same time.
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 47966
const PORTS: int = 4
## How long the host waits, after it can see this machine, before it launches: long enough to take a picture in.
const LAUNCH_AFTER: float = 12.0
## Wall seconds for local UI/session work and for the child host's launch. A fixed-fps probe
## can consume thousands of frames before a socket or child-process wall timer advances.
const LOCAL_SECONDS: float = 20.0
const CHILD_SECONDS: float = 60.0
const FLIGHT: String = "island"

var _saved: Array[String] = []
var _failed: Array[String] = []
var _child: int = 0
var _port: int = 0
var _log: String = ""


func _ready() -> void:
	if get_tree().current_scene != self:
		_run()
		return
	var watcher := Node.new()
	watcher.name = "LevelChangeShotWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	var out: String = _out_folder()
	DirAccess.make_dir_recursive_absolute(out)
	var project: String = ProjectSettings.globalize_path("res://")
	var up: bool = false
	_port = TestPorts.first_free(FIRST_PORT, PORTS)
	while _port != 0 and not up:
		_log = ProjectSettings.globalize_path(TestPorts.log_for("level_change_shot", "host_%d" % _port))
		if FileAccess.file_exists(_log):
			DirAccess.remove_absolute(_log)
		_child = OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--log-file", _log,
			"--path", project, "--", "--host=%d" % _port, "--launch=%s:%s" % [FLIGHT, LAUNCH_AFTER], "--report=1"])
		var said: Dictionary = await _wait_for_the_child(func(report: Dictionary) -> bool:
			return report.get("role") == "host" or _read().contains("BOOT_ERROR=Could not listen"))
		if _read().contains("BOOT_ERROR=Could not listen"):
			_kill_the_child()
			_port = TestPorts.first_free(FIRST_PORT, PORTS, _port)
			continue
		up = String(said.get("level", "")) == ChartDrawer.HOSTING
		if not up:
			break
	if not up:
		_stop("no host came up in the lobby on port %d" % _port if _port != 0 else TestPorts.busy(FIRST_PORT, PORTS))
		return

	# JOINED THROUGH THE DESK, as a person joins: the address typed into the real field and the real button pressed.
	Sim.stop()
	Net.leave("probe")
	get_tree().change_scene_to_file(Doors.DESK)
	# WAITED FOR `_menu`, NOT FOR THE PANEL. `DeskRoom._ready` builds its screens, waits a frame, and only THEN connects
	# `_menu.chose` to `_on_chose` -- so a press on a screen that merely exists announces to nobody, and the desk sits
	# there having been pressed. Measured 2026-09-15 on the windowed probe: "scene Desk, in session false, transport
	# none" after a Join that went nowhere.
	var menu: SessionMenu = null
	var menu_since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - menu_since < int(LOCAL_SECONDS * 1000.0):
		var desk := get_tree().current_scene as DeskRoom
		if desk != null and desk.get("_menu") != null:
			menu = desk.get("_menu") as SessionMenu
			break
		await get_tree().physics_frame
	var field: LineEdit = _address_field(menu) if menu != null else null
	if field == null:
		_stop("the desk had no address field")
		return
	field.text = "127.0.0.1:%d" % _port
	_press(menu, "Join")

	# 1: THE BRIEFING ROOM, from this client's own eye, with the host standing in it too.
	var briefing: FlightLevel = await _the_level_that_comes_up(ChartDrawer.HOSTING)
	if briefing == null or briefing.room == null:
		_stop("this machine never reached the host's briefing room")
		return
	print("[level_change_shot] in %s, %d other player(s) in the room" % [briefing.level.name,
		(briefing.get("_pilots") as Dictionary).size()])
	# RECENTRED, which is the R key: the desk camera is mouse-look and the mouse is captured for the few frames before
	# the level hands the launch board to the rig, so a stray flick of the real mouse would point this picture at the
	# ceiling. Measured on tests/lobby_shot.gd, 2026-09-15.
	briefing.rig.recentre()
	await _save(out.path_join("level_change_1_the_briefing_room.png"))

	# 2: FULLY BLACK BEFORE REPLACEMENT. The cue arrives while this client is still in the briefing room; the autoload
	# curtain, unlike that room, survives what follows. Capture its exact covered signal rather than guessing a delay.
	var launched: bool = false
	var launch_since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - launch_since < int(CHILD_SECONDS * 1000.0):
		if _read().contains("LAUNCHING %s" % FLIGHT):
			launched = true
			break
		await get_tree().physics_frame
	if not launched:
		_stop("the host never pressed its launch board")
		return
	var cover_since: int = Time.get_ticks_msec()
	while Transition.opacity() < 0.999 and Time.get_ticks_msec() - cover_since < 10000:
		await get_tree().process_frame
	if Transition.opacity() < 0.999:
		_stop("the transition curtain never became opaque")
		return
	await _save(out.path_join("level_change_2_fully_black.png"))

	# 3: THE ISLAND, from the same client after its local build completed and the curtain faded away.
	var sky: FlightLevel = await _the_level_that_comes_up(FLIGHT)
	if sky == null or sky.level == null or sky.level.id != FLIGHT:
		_stop("this machine never followed the host to %s" % FLIGHT)
		return
	print("[level_change_shot] followed to %s, flying %s" % [sky.level.name,
		Sim.kind_name(sky.rig.vehicle_view().kind) if sky.rig.vehicle_view() != null else "nothing"])
	sky.rig.recentre()
	# A FEW SECONDS OF FLIGHT so the picture is of a world, not of the first frame of one.
	for i in range(240):
		await get_tree().physics_frame
	var reveal_since: int = Time.get_ticks_msec()
	while Transition.opacity() > 0.001 and Time.get_ticks_msec() - reveal_since < 10000:
		await get_tree().process_frame
	await _save(out.path_join("level_change_3_the_island.png"))

	print("[level_change_shot] saved %s" % [_saved])
	var ok: bool = _failed.is_empty() and _saved.size() == 3
	print("[level_change_shot] RESULT=%s %s" % ["PASS" if ok else "FAIL", ", ".join(_failed)])
	_kill_the_child()
	get_tree().quit(0 if ok else 1)


func _stop(why: String) -> void:
	var level := get_tree().current_scene as FlightLevel
	print("[level_change_shot] scene %s, level %s, in session %s, transport %s, ready %s, seated %s" % [
		get_tree().current_scene, level.level.id if level != null and level.level != null else "-",
		Net.is_in_session, Net.transport, Sim.is_ready,
		level.rig.is_seated() if level != null and level.rig != null else false])
	print("[level_change_shot] the host last said %s" % [_latest_report(_read())])
	print("[level_change_shot] RESULT=FAIL %s" % why)
	_kill_the_child()
	get_tree().quit(1)


func _the_level_that_comes_up(id: String) -> FlightLevel:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(CHILD_SECONDS * 1000.0):
		var level := get_tree().current_scene as FlightLevel
		if level != null and level.level != null and level.level.id == id and Sim.is_ready \
				and level.rig != null and level.rig.is_seated():
			for j in range(90):
				await get_tree().physics_frame
			return level
		await get_tree().physics_frame
	return get_tree().current_scene as FlightLevel


func _save(path: String) -> void:
	for i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var err: int = picture.save_png(path)
	print("[level_change_shot] %d x %d, %s, %s" % [picture.get_width(), picture.get_height(), error_string(err), path])
	if err == OK:
		_saved.append(path.get_file())
	else:
		_failed.append("%s not saved" % path.get_file())


func _wait_for_the_child(until: Callable) -> Dictionary:
	var since: int = Time.get_ticks_msec()
	var report: Dictionary = {}
	while Time.get_ticks_msec() - since < 60000:
		report = _latest_report(_read())
		if until.call(report):
			return report
		await get_tree().physics_frame
	return report


func _read() -> String:
	return FileAccess.get_file_as_string(_log) if _log != "" and FileAccess.file_exists(_log) else ""


func _latest_report(said: String) -> Dictionary:
	var out: Dictionary = {}
	for line in said.split("\n"):
		if not line.begins_with("SESSION_REPORT "):
			continue
		out.clear()
		for pair in line.substr(15).strip_edges().split(" ", false):
			var kv: PackedStringArray = pair.split("=")
			if kv.size() == 2:
				out[kv[0]] = kv[1]
	return out


func _press(menu: Control, words: String) -> void:
	for node in menu.find_children("*", "Button", true, false):
		if (node as Button).text == words:
			(node as Button).pressed.emit()
			return


func _address_field(menu: SessionMenu) -> LineEdit:
	var pad: Array = menu.find_children("*", "CodePad", true, false)
	for node in menu.find_children("*", "LineEdit", true, false):
		var line := node as LineEdit
		if line.is_visible_in_tree() and (pad.is_empty() or not (pad[0] as Node).is_ancestor_of(line)):
			return line
	return null


func _kill_the_child() -> void:
	if _child > 0 and OS.is_process_running(_child):
		OS.kill(_child)
	_child = 0


func _out_folder() -> String:
	for argument in OS.get_cmdline_user_args():
		if String(argument).begins_with("--out="):
			return String(argument).substr(6)
	return ProjectSettings.globalize_path("user://level_change_shot")
