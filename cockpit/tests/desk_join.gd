extends Node
## Headless: can somebody sitting at the MAIN MENU join a game by typing its address, without playing solo first?
##
##   Godot --headless --path cockpit res://tests/desk_join.tscn
##
## Asked for on 2026-09-15: "When a server starts, it doesn't work correctly, clients need to start the single player
## game, then join, they should be able to load from the main menu, build some tests to make sure that this works
## correctly by connecting via ip."
##
## THE GAP THIS CLOSES, and it is exactly the path the report is about. `tests/session.gd` presses **Host** on the desk
## and then reaches the socket with a raw ENet guest -- a socket, not a player, and not the Join button.
## `tests/two_peers.gd` starts two processes with `--host=` and `--join=` BOOT FLAGS, which go through `world/boot.gd`
## and never touch the desk at all. So every piece of the joining path was covered except the one a player uses: the
## address field and the Join button on the session screen.
##
## THE SUITE IS THE JOINER, and the host is a child process. That is the way round that matters: the thing under test
## is this process's own desk, its own `Net`, its own scene change and its own world, driven by the real button. A
## child hosts with `--host=PORT --report=1` because a host is not what is in question -- `session.gd` and
## `two_peers.gd` both hold that already.
##
## AND IT PROVES A PLAYER ARRIVED, not a socket. A connected socket was the thing that looked like success and was not
## (team-lead, 2026-09-14): the checks are that this machine lands in the WORLD, is a client in an ENet session, and
## that the host's own `SESSION_REPORT` line names two machines' sync clients and draws two pilots. A join that opens a
## socket and never loads is what is being hunted, and it passes every check that stops at the socket.
##
## IT SURVIVES ITS OWN SCENE CHANGE the way tests/session.gd does: the scene's root hangs a second copy of this script
## on /root, which is a sibling of the current scene and outlives every swap.
##
## Read RESULT=, not the exit code.

## THE CHILD HOST CHOOSES NO LEVEL, so since 2026-09-15 it hosts the LOBBY (`Net.suit_the_session`, the user's rule) and
## this machine, which has the island, is told the host's level on arrival and flies that. Left as it is on purpose: what
## is in question here is the Join button and the address field, and a joiner arriving on a level it did not have chosen
## is the ordinary case rather than a special one. tests/two_peers.gd and tests/crew_peers.gd name the island instead,
## because what they are about needs a world with craft in it.
##
## A PORT OF ITS OWN, typed into the field as `127.0.0.1:PORT`. Ports nothing else uses: session 7788 and 47913,
## steam_join 47961-47963, code_pad 47964-47965, two_peers 47980-47989. Deliberately NOT `Net.DEFAULT_PORT`: a suite on
## 7788 fights a developer's own game for it, and, more to the point, a host on another port was unreachable from the
## main menu until 2026-09-15, so this is the check that holds the fix.
const FIRST_PORT: int = 47990
const PORTS: int = 8
## Frames to wait for the desk to finish wiring its session screen: a second at the project's rate, against the one
## frame it measured at. See the note where it is waited for.
const WIRED_PATIENCE: int = 120
## Seconds to give the child host to come up before this machine knocks on it.
const HOST_PATIENCE: float = 30.0
## Seconds for this machine to get from the button to the world with the host drawing it.
const JOIN_PATIENCE: float = 40.0

var _failures: PackedStringArray = []
var _sections: int = 0
var _children: Array[int] = []
var _host_log: String = ""


func _check(label: String, ok: bool, detail: String) -> void:
	print("[desk_join] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if get_tree().current_scene != self:
		_run()
		return
	var watcher := Node.new()
	watcher.name = "DeskJoinWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_what_a_typed_address_means()
	await _a_desk_joins_a_host_by_its_address()
	_check("every_section_of_the_suite_ran", _sections == 2, "%d of 2" % _sections)
	_finish()


## ---- 1: what a person may type into the address field ---------------------------------------------------------------

## AN ADDRESS, OR AN ADDRESS AND A PORT, and a sentence for anything else.
##
## Until 2026-09-15 the field meant an address and nothing else: `DeskRoom` handed its text to `Net.join`, whose port
## argument defaults, so a host on any other port could not be reached from the main menu at all, and somebody typing
## `192.168.1.50:7788` -- which is what a person types -- passed that whole string to `create_client` as a host name.
## ENet returns OK for a name that does not resolve and then sits in CONNECTION_CONNECTING for ever
## (`working_with_godot.md`), so the only thing that ever said no was the desk's ten-second timeout, with the
## thoroughly misleading "Nothing is listening there."
##
## PURE, so every spelling is a check without a socket. The parser is `LaunchOrder.read_address`, which is the SAME one
## `--join=` has always used -- one parser, two doors, so a spelling that works on the command line works in the field.
func _what_a_typed_address_means() -> void:
	var cases: Array = [
		["127.0.0.1", "127.0.0.1", Net.DEFAULT_PORT, ""],
		["192.168.1.50:5000", "192.168.1.50", 5000, ""],
		["  10.0.0.7  ", "10.0.0.7", Net.DEFAULT_PORT, ""],
		["a-host-name.local:1234", "a-host-name.local", 1234, ""],
		["127.0.0.1:0", "", 0, "port"],
		["127.0.0.1:99999", "", 0, "port"],
		["127.0.0.1:nonsense", "", 0, "port"],
		[":5000", "", 0, "address"],
		["", "", 0, "address"],
	]
	var wrong: PackedStringArray = []
	for case in cases:
		var got: Dictionary = LaunchOrder.read_address(String(case[0]), Net.DEFAULT_PORT)
		var why: String = String(case[3])
		if why == "":
			if String(got["error"]) != "" or String(got["address"]) != String(case[1]) or int(got["port"]) != int(case[2]):
				wrong.append("'%s' gave %s, wanted %s:%d" % [case[0], got, case[1], int(case[2])])
		elif not String(got["error"]).contains(why):
			wrong.append("'%s' gave '%s', wanted a sentence about the %s" % [case[0], got["error"], why])
	_check("the_address_field_reads_an_address_and_an_optional_port_and_refuses_the_rest", wrong.is_empty(),
		"%d spellings%s" % [cases.size(), "" if wrong.is_empty() else "; " + "; ".join(wrong)])
	_sections += 1


## ---- 2: the main menu to the host's world ---------------------------------------------------------------------------

func _a_desk_joins_a_host_by_its_address() -> void:
	# ---- a host to join, in a process of its own -------------------------------------------------------------------
	_host_log = ProjectSettings.globalize_path(TestPorts.log_for("desk_join", "host"))
	var project: String = ProjectSettings.globalize_path("res://")
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	var listening: bool = false
	var since: int = 0
	while port != 0 and not listening:
		if FileAccess.file_exists(_host_log):
			DirAccess.remove_absolute(_host_log)
		_children.append(OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--log-file",
			_host_log, "--path", project, "--", "--host=%d" % port, "--report=1"]))
		since = Time.get_ticks_msec()
		var busy: bool = false
		while Time.get_ticks_msec() - since < int(HOST_PATIENCE * 1000.0):
			var said: String = _read(_host_log)
			busy = said.contains("BOOT_ERROR=Could not listen")
			# THE HOST IS READY WHEN ITS WORLD IS REPORTING, not when the process exists: a knock that lands before the
			# host has a level to name is a knock the hello cannot answer, and this suite would be testing its own race.
			if busy or not _latest_report(said).is_empty():
				break
			await get_tree().create_timer(0.1).timeout
		if busy:
			var next: int = TestPorts.first_free(FIRST_PORT, PORTS, port)
			print("[desk_join] port %d is in use; trying %d" % [port, next])
			_kill_the_children()
			port = next
			continue
		listening = not _latest_report(_read(_host_log)).is_empty()
		if not listening:
			break
	_check("a_host_is_up_to_be_joined", listening, "port %d, host said %s" % [port,
		_latest_report(_read(_host_log))] if port != 0 else TestPorts.busy(FIRST_PORT, PORTS))
	if not listening:
		_sections += 1
		return

	# ---- this machine, at the main menu ----------------------------------------------------------------------------
	get_tree().change_scene_to_file("res://world/desk.tscn")
	var desk: DeskRoom = null
	for i in range(600):
		await get_tree().process_frame
		if get_tree().current_scene is DeskRoom:
			desk = get_tree().current_scene as DeskRoom
			break
	# WAITED FOR `_menu`, WHICH IS SET AFTER THE DESK HAS CONNECTED IT, and not for the panel or for a count of frames.
	#
	# `DeskRoom._ready` builds its three screens, waits a frame, and only THEN connects `_menu.chose` to `_on_chose` --
	# so a press on a screen that merely EXISTS emits into a signal with no listener, and what a suite sees is a desk
	# that was pressed and did nothing (the lobby lane's windowed probe, 2026-09-15: "scene Desk, in session false,
	# transport none" after a Join). This suite waited six process frames instead.
	#
	# IT WAS NOT RELYING ON LUCK, MEASURED BEFORE IT WAS CHANGED: the desk wired its session screen 1 frame after it
	# became the scene, on three runs out of three, against the 6 waited -- five frames of slack. But six is a number
	# nobody chose against the thing it has to outlast, and the next thing that adds an `await` to `_ready` spends it.
	# Waiting for the thing itself cannot go stale, and a failure now says what it means.
	var wired: bool = false
	for i in range(WIRED_PATIENCE):
		if desk != null and desk.get("_menu") != null:
			wired = true
			break
		await get_tree().process_frame
	var menu: SessionMenu = desk.get("_menu") as SessionMenu if wired else null
	_check("the_desk_is_up_with_its_session_screen_wired", menu != null, "desk %s, menu %s" % [desk, menu])
	if menu == null:
		_sections += 1
		return
	# NOTHING PLAYED SOLO FIRST. That is the whole report: a player who has not started a session should be able to
	# join from here, and this holds that the machine really is in no session when the button is pressed.
	_check("and_this_machine_is_in_no_session_before_it_presses_join",
		not Net.is_in_session and Net.transport == "none" and not Net.is_networked(),
		"in session %s, transport %s" % [Net.is_in_session, Net.transport])

	# ---- the address typed in, and Join pressed --------------------------------------------------------------------
	var field: LineEdit = _address_field(menu)
	_check("the_session_screen_has_an_address_to_type_into", field != null, "%s" % [field])
	if field == null:
		_sections += 1
		return

	# ---- FIRST AS ANOTHER BUILD, and then at a port nobody holds: every way in ends in words, on the screen and on the
	# board. The user, 2026-09-18: "the client MUST know why (if possible), it couldn't connect." This machine pretends
	# to be a release a version behind (`Net._pretend`, what `--pretend-build=` sets), which is the one thing a suite
	# cannot be by running another checkout; the field, the button, the host and its refusal are the real ones.
	var rig: PilotRig = desk.get("_rig") as PilotRig
	var other_line: String = "0.2.0 soaring-otter · 1a2b3c4d"
	(Net.get("_pretend") as Dictionary).merge({"commit": "1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d", "line": other_line})
	field.text = "127.0.0.1:%d" % port
	_press(menu, "Join")
	since = Time.get_ticks_msec()
	while Net.transport != "none" and Time.get_ticks_msec() - since < int(JOIN_PATIENCE * 1000.0):
		await get_tree().process_frame
	await get_tree().process_frame
	(Net.get("_pretend") as Dictionary).clear()
	var screen: String = _said_on(menu)
	var board: String = rig.clipboard.page().said_text() if rig != null and rig.clipboard.page() != null else ""
	var host_line: String = BuildPlate.line()
	_check("another_build_pressing_join_is_told_why_on_the_screen_naming_both_builds",
		screen.begins_with("Can't join") and screen.contains(host_line) and screen.contains(other_line)
			and get_tree().current_scene == desk, "'%s'" % screen)
	_check("and_on_the_board_in_its_hand", board == screen, "board '%s'" % board)
	_check("and_the_host_wrote_it_down", _read(_host_log).contains("NET_REFUSED side=host code=wrong_version"),
		"host said '%s'" % _last_line_with(_read(_host_log), "NET_REFUSED"))
	var nobody: int = TestPorts.first_free(FIRST_PORT, PORTS, port)
	Net.patience["connect"] = 1.5
	field.text = "127.0.0.1:%d" % nobody
	_press(menu, "Join")
	since = Time.get_ticks_msec()
	while Net.transport != "none" and Time.get_ticks_msec() - since < 8000:
		await get_tree().process_frame
	await get_tree().process_frame
	Net.patience["connect"] = Net.PATIENCE["connect"]
	screen = _said_on(menu)
	board = rig.clipboard.page().said_text() if rig != null and rig.clipboard.page() != null else ""
	_check("a_join_nobody_answers_says_where_and_how_long_on_the_screen_and_the_board",
		screen == Net.connect_words("127.0.0.1:%d" % nobody, 1.5, false) and board == screen,
		"screen '%s', board '%s'" % [screen, board])
	# TYPED AS A PLAYER WOULD TYPE IT, into the real field, ADDRESS:PORT, and the real button pressed after. RED before
	# the desk learned to read a port (2026-09-15): the whole string went to `create_client` as a host name, which does
	# not resolve, and ten seconds later the screen said "Nothing is listening there."
	field.text = "127.0.0.1:%d" % port
	var pressed: bool = _press(menu, "Join")
	_check("and_a_join_button_to_press", pressed, "found and emitted")

	# ---- and it lands in the world, with the host drawing it --------------------------------------------------------
	since = Time.get_ticks_msec()
	var arrived: bool = false
	while Time.get_ticks_msec() - since < int(JOIN_PATIENCE * 1000.0):
		if get_tree().current_scene is FlightLevel and Sim.is_ready and Net.is_in_session:
			arrived = true
			break
		await get_tree().process_frame
	# WHAT THE SCREEN SAID, READ ONLY WHILE IT IS STILL THERE. A join that works frees the desk, and the first version of
	# this suite reached into the freed menu to build its own failure message -- so a PASSING join aborted the section
	# with "previously freed instance" and printed nothing at all. The detail is gathered behind `is_instance_valid`.
	var said: String = _said_on(menu) if is_instance_valid(menu) else "(the desk is gone, which is what flying means)"
	_check("pressing_join_at_the_main_menu_lands_in_the_hosts_world",
		arrived and Net.transport == "enet" and not Net.is_host and Net.is_networked(),
		"scene %s, in session %s, transport %s, host %s, said '%s'" % [
			get_tree().current_scene.get_class() if get_tree().current_scene != null else "none", Net.is_in_session,
			Net.transport, Net.is_host, said])

	# THE HOST SEES A PLAYER, not a socket. Its own report line, read out of its log.
	var host_report: Dictionary = {}
	since = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(JOIN_PATIENCE * 1000.0):
		host_report = _latest_report(_read(_host_log))
		if int(host_report.get("clients", 0)) == 2 and int(host_report.get("pilots", 0)) == 2:
			break
		await get_tree().create_timer(0.1).timeout
	_check("and_the_host_counts_two_machines_and_draws_two_pilots",
		int(host_report.get("clients", 0)) == 2 and int(host_report.get("pilots", 0)) == 2,
		"host said %s" % [host_report])

	Sim.stop()
	Net.leave("suite")
	_kill_the_children()
	for i in range(10):
		await get_tree().process_frame
	_sections += 1


## THE ADDRESS FIELD on the session screen: the visible LineEdit that is not the join code keypad's.
func _address_field(menu: SessionMenu) -> LineEdit:
	var pad: Array = menu.find_children("*", "CodePad", true, false)
	for node in menu.find_children("*", "LineEdit", true, false):
		var line := node as LineEdit
		if line.is_visible_in_tree() and (pad.is_empty() or not (pad[0] as Node).is_ancestor_of(line)):
			return line
	return null


## What the session screen last said, for a failure's detail line.
func _said_on(menu: SessionMenu) -> String:
	var said: String = ""
	for node in menu.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and label.text != "":
			said = label.text
	return said


func _press(within: Node, words: String) -> bool:
	for node in within.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == words and button.is_visible_in_tree():
			button.pressed.emit()
			return true
	return false


func _last_line_with(text: String, words: String) -> String:
	var found: String = ""
	for line in text.split("\n"):
		if line.contains(words):
			found = line.strip_edges()
	return found


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## The last `SESSION_REPORT role=host transport=enet clients=2 pilots=2` in a log, as a Dictionary.
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


func _kill_the_children() -> void:
	for pid in _children:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_children.clear()


func _finish() -> void:
	_kill_the_children()
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
