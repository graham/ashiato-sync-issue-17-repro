extends Node
## Headless, over real ENet: THE CLIPBOARD'S LOG TAB, pressed through its own tab button: on a host flying the real
## level, who joined and who was turned away and why; on a joiner at the desk, its own knocks -- the refusal naming both
## builds, and a knock nobody answered.
##
##   Godot --headless --path cockpit res://tests/handshake_log.tscn
##   Godot --path cockpit res://tests/handshake_log.tscn -- --out=C:/Users/Graham/godotgames-drafts/2026-09-18/cockpit-handshake
##
## Asked for on 2026-09-18: "There should be a server log message that explains why a user couldn't connect (we need a
## server log panel in the ipad). and the client MUST know why (if possible), it couldn't connect."
##
## THIS PROCESS IS THE HOST FIRST AND THE JOINER SECOND, on the real flight level and the real desk, each with its rig and
## the board in its hand; the other side is a child process each time. The other build is PRETENDED
## (`--pretend-build=`, `Net._pretend`), because one checkout is one build. With `--out=` and a window, it also saves the
## pictures: the host's LOG, the joiner's desk with the refusal on it, its board, and the knock nobody answered.
##
## Mutant, red on `the_host_s_log_tab_says_who_joined_and_who_was_turned_away`: the page drawing nothing.
##
## It survives its own scene changes the way tests/desk_join.gd does: a second copy of this script on /root.
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 48020
const PORTS: int = 8
const PATIENCE_MSEC: int = 60000
const OTHER_COMMIT: String = "1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d"
const OTHER_LINE: String = "0.2.0 soaring-otter · 1a2b3c4d"

var _failures: PackedStringArray = []
var _children: Array[int] = []
var _out: String = ""
var _pictures: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[handshake_log] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if get_tree().current_scene != self:
		_run()
		return
	var watcher := Node.new()
	watcher.name = "HandshakeLogWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if String(argument).begins_with("--out=") and DisplayServer.get_name() != "headless":
			_out = String(argument).substr(6)
			DirAccess.make_dir_recursive_absolute(_out)
	print("[handshake_log] display %s, pictures to '%s'" % [DisplayServer.get_name(), _out])
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld missing")
		_finish()
		return
	await _the_host_s_log()
	await _the_joiner_s_log()
	_finish()


## ---- the host ---------------------------------------------------------------------------------------------------

func _the_host_s_log() -> void:
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	if port == 0:
		_check("a_port_was_available", false, TestPorts.busy(FIRST_PORT, PORTS))
		return
	Net.logbook.clear()
	Net.host(port)
	get_tree().change_scene_to_file("res://world/sky.tscn")
	var level: FlightLevel = await _flying()
	_check("the_host_flies_its_level", level != null and Net.is_host, "level %s" % [level])
	if level == null:
		return
	var project: String = ProjectSettings.globalize_path("res://")
	var join: String = "--join=127.0.0.1:%d" % port
	_spawn(project, TestPorts.log_for("handshake_log", "same"), [join, "--report=1"])
	_spawn(project, TestPorts.log_for("handshake_log", "other"), [join, "--report=1",
		"--pretend-build=%s|%s" % [OTHER_COMMIT, OTHER_LINE]])
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < PATIENCE_MSEC and not (_has_row("JOINED", "") and _has_row("REFUSED",
			"wrong_version")):
		await get_tree().process_frame
	var board: Clipboard = level.rig.clipboard
	var page: ClipboardPage = board.page()
	var pressed: bool = _press_the_tab(page, "LOG")
	await _frames(2)
	var shown: String = page.log_text()
	_check("the_host_s_log_tab_says_who_joined_and_who_was_turned_away", pressed and shown.contains("JOINED")
		and shown.contains("REFUSED wrong version") and shown.contains(OTHER_LINE) and shown.contains(BuildPlate.line()),
		"pressed %s, page:\n%s" % [pressed, shown])
	_check("newest_first", shown.find("REFUSED") < shown.find("CONNECTED") or shown.find("JOINED") < shown.find(
		"CONNECTED"), "first line '%s'" % shown.get_slice("\n", 0))
	if _out != "":
		board.show_board(true)
		await _save_glass(board.panel(), "cockpit-handshake-01-host-log-tab.png")
	Sim.stop()
	Net.leave("suite")
	_bury()
	await _frames(10)


## ---- the joiner ---------------------------------------------------------------------------------------------------

func _the_joiner_s_log() -> void:
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	var project: String = ProjectSettings.globalize_path("res://")
	var host_log: String = ProjectSettings.globalize_path(TestPorts.log_for("handshake_log", "host"))
	if FileAccess.file_exists(host_log):
		DirAccess.remove_absolute(host_log)
	_spawn(project, host_log, ["--host=%d" % port, "--report=1"])
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < PATIENCE_MSEC and not _read(host_log).contains("SESSION_REPORT"):
		await get_tree().create_timer(0.1).timeout
	Net.logbook.clear()
	get_tree().change_scene_to_file("res://world/desk.tscn")
	var desk: DeskRoom = null
	for i in range(600):
		await get_tree().process_frame
		desk = get_tree().current_scene as DeskRoom
		if desk != null and desk.get("_menu") != null:
			break
	var menu: SessionMenu = desk.get("_menu") as SessionMenu if desk != null else null
	var field: LineEdit = _address_field(menu) if menu != null else null
	_check("the_joiner_is_at_the_desk_with_an_address_to_type", field != null, "desk %s" % [desk])
	if field == null:
		return
	var rig: PilotRig = desk.get("_rig") as PilotRig
	# AS ANOTHER BUILD, through the real field and button.
	(Net.get("_pretend") as Dictionary).merge({"commit": OTHER_COMMIT, "line": OTHER_LINE})
	field.text = "127.0.0.1:%d" % port
	_press(menu, "Join")
	since = Time.get_ticks_msec()
	while Net.transport != "none" and Time.get_ticks_msec() - since < PATIENCE_MSEC:
		await get_tree().process_frame
	await _frames(4)
	(Net.get("_pretend") as Dictionary).clear()
	if _out != "":
		await _save_glass(desk.get("_panel") as TouchPanel, "cockpit-handshake-02-desk-refused-wrong-version.png")
		await _save_window("cockpit-handshake-03-desk-refused-from-the-chair.png")
	var page: ClipboardPage = rig.clipboard.page()
	var pressed: bool = _press_the_tab(page, "LOG")
	await _frames(2)
	var shown: String = page.log_text()
	_check("the_joiner_s_log_tab_says_it_was_refused_and_why_naming_both_builds", pressed
		and shown.contains("REFUSED wrong version") and shown.contains(OTHER_LINE) and shown.contains(BuildPlate.line()),
		"page:\n%s" % shown)
	if _out != "":
		rig.clipboard.show_board(true)
		await _save_glass(rig.clipboard.panel(), "cockpit-handshake-04-joiner-board-log.png")
	# AND A KNOCK NOBODY ANSWERS.
	var nobody: int = TestPorts.first_free(FIRST_PORT, PORTS, port)
	Net.patience["connect"] = 3.0
	field.text = "127.0.0.1:%d" % nobody
	_press(menu, "Join")
	since = Time.get_ticks_msec()
	while Net.transport != "none" and Time.get_ticks_msec() - since < 10000:
		await get_tree().process_frame
	Net.patience["connect"] = Net.PATIENCE["connect"]
	await _frames(4)
	shown = page.log_text()
	_check("and_a_knock_nobody_answered_is_on_it_too_newest_first", shown.get_slice("\n", 0).contains("TIMED_OUT")
		and shown.contains("No answer from 127.0.0.1:%d after 3 s" % nobody), "page:\n%s" % shown)
	if _out != "":
		await _save_glass(desk.get("_panel") as TouchPanel, "cockpit-handshake-05-desk-no-answer.png")
		await _save_glass(rig.clipboard.panel(), "cockpit-handshake-06-joiner-board-log-no-answer.png")
	_bury()


## ---- the machinery ----------------------------------------------------------------------------------------------

func _flying() -> FlightLevel:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < PATIENCE_MSEC:
		var level := get_tree().current_scene as FlightLevel
		if level != null and level.rig != null and level.rig.clipboard != null and Sim.is_ready:
			return level
		await get_tree().process_frame
	return null


func _has_row(event: String, code: String) -> bool:
	for row in Net.logbook.rows():
		if String(row.get("event", "")) == event and (code == "" or String(row.get("code", "")) == code):
			return true
	return false


## THE TAB, PRESSED AS A FINGER PRESSES IT: the page's own tab button, found by its word.
func _press_the_tab(page: ClipboardPage, words: String) -> bool:
	return page != null and _press(page, words)


func _press(within: Node, words: String) -> bool:
	for node in within.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == words:
			button.pressed.emit()
			return true
	return false


func _address_field(menu: SessionMenu) -> LineEdit:
	var pad: Array = menu.find_children("*", "CodePad", true, false)
	for node in menu.find_children("*", "LineEdit", true, false):
		var line := node as LineEdit
		if line.is_visible_in_tree() and (pad.is_empty() or not (pad[0] as Node).is_ancestor_of(line)):
			return line
	return null


func _save_glass(panel: TouchPanel, name: String) -> void:
	var screen := panel.get("_screen") as SubViewport
	BuildStamp.attach_to(screen)
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await _frames(10)
	await RenderingServer.frame_post_draw
	_keep(screen.get_texture().get_image(), name)


func _save_window(name: String) -> void:
	await _frames(10)
	await RenderingServer.frame_post_draw
	_keep(get_viewport().get_texture().get_image(), name)


func _keep(picture: Image, name: String) -> void:
	var path: String = _out.path_join(name)
	var err: int = picture.save_png(path)
	print("[handshake_log] %d x %d, %s, %s" % [picture.get_width(), picture.get_height(), error_string(err), path])
	if err == OK:
		_pictures += 1
	else:
		_failures.append("%s not saved" % name)


func _spawn(project: String, log_path: String, user_args: Array[String]) -> void:
	var args: Array[String] = ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--log-file",
		ProjectSettings.globalize_path(log_path), "--path", project, "--"]
	args.append_array(user_args)
	_children.append(OS.create_process(OS.get_executable_path(), args))


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _bury() -> void:
	for pid in _children:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_children.clear()


func _frames(how_many: int) -> void:
	for i in range(how_many):
		await get_tree().process_frame


func _finish() -> void:
	_bury()
	if _out != "":
		print("[handshake_log] %d pictures in %s" % [_pictures, _out])
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
