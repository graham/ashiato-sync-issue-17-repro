extends Node
## Headless, two machines: A LEVEL CHANGE IS ANNOUNCED BEFORE IT HAPPENS, AND WHO JOINED AND WHO LEFT IS SAID.
##
##   Godot --headless --fixed-fps 120 --path cockpit res://tests/notices.tscn
##
## Plan item 13, asked for on 2026-09-15: "we need a notification system so we know when users join, leave, or other
## important things happen." Built against the case `lane/lobby` left: "nothing yet says a level change is coming. The
## client learns about it when its screen goes away."
##
## THIS PROCESS IS THE HOST, in the LOBBY (a suite names its level), and it launches the island from the briefing room's
## own launch board -- the real `Button` a player's beam presses. The joiner is a child whose log says what it DREW: every
## change of the notice on its flat status line (`NOTICE_DRAWN`), and when `Net` started the level change
## (`NET_LEVEL_CHANGING`). The order of those two lines in one log is the whole claim: the words were on its screen, in the
## lobby, before the screen went.
##
##   1. ALONE, a launch gets a short local cue: enough to fade rather than cut, without the multiplayer warning.
##   2. A joiner arrives, and both machines say so: the host "PLAYER n JOINED", the joiner "YOU JOINED AS PLAYER n".
##   3. The host launches the island. The level does NOT change on the press; the joiner draws "EVERYBODY TO THE ISLAND IN
##      n S" while still in the lobby, and only then starts the change; the host changes `Net.LEVEL_WARNING_MSEC` after.
##   4. The joiner leaves through MAIN MENU on the island (`--leave-in`), and the host draws "PLAYER n LEFT".
##   5. A joiner is KILLED on the island, so the host still counts it as admitted and it will never answer, and the host
##      calls the lobby: the change is made at the warning and not a moment for the dead peer's sake (team-lead asked).
##
## WHAT IS NOT PROVED HERE: the board's notice line in a hand -- tests/clipboard.gd holds that it fits on every tab at its
## longest, and the flat line and the board read the same `Net.notice_words`. Malformed notices are tests/level_hello.gd's.
##
## PORTS 47932-47939 of this checkout's block (`TestPorts`), which no other suite uses (net_jump 47931, sky_peers
## 47940-47947). Each section hosts on the first of them nothing holds, asked silently first: this used to hunt by calling
## `Net.host` until one worked, and every held port on the way printed "ERROR: Couldn't create an ENet host.", which the
## runner's error gate turns red however the suite ends. The children's logs are this checkout's own, too: they were
## `user://notices_joiner.log` for every lane on the machine, and on 2026-09-18 two lanes' late joiners wrote one file
## interleaved while each lane's suite waited on it for three minutes (`lane/ports`).
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 47932
const PORTS: int = 8
## Seconds to wait for a child, a scene or a notice, on the wall clock: under `--fixed-fps` frames are not seconds.
const PATIENCE_SECONDS: float = 60.0
const ROOM: String = "lobby"
const FLIGHT: String = "island"

var _failures: PackedStringArray = []
var _children: Array[int] = []
var _port: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[notices] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if get_tree().current_scene != self:
		_run()
		return
	var watcher := Node.new()
	watcher.name = "NoticesWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld missing")
		_finish()
		return
	await _alone_a_launch_gets_a_short_cue()
	await _with_a_joiner_a_launch_is_announced_first()
	await _a_joiner_that_never_answers_does_not_hold_the_session()
	_finish()


## ---- 1: alone ---------------------------------------------------------------------------------------------------------

func _alone_a_launch_gets_a_short_cue() -> void:
	var room: FlightLevel = await _host_the_lobby()
	if room == null:
		return
	var noticed: Array = [0]
	var count := func() -> void: noticed[0] += 1
	Net.noticed.connect(count)
	var covered: Array = [false]
	var saw_cover := func(target: String, _revision: int) -> void:
		if target == FLIGHT: covered[0] = true
	Transition.covered.connect(saw_cover)
	_press_the_launch(room)
	_check("alone_the_launch_gets_only_the_short_fade_cue",
		Net.level == ROOM and Net.level_called_in() > 0 and Net.level_called_in() <= Net.LEVEL_LOCAL_CUE_MSEC and noticed[0] == 1,
		"level %s, called in %d ms, %d notice(s)" % [Net.level, Net.level_called_in(), noticed[0]])
	Net.noticed.disconnect(count)
	await _the_level_comes_up(FLIGHT)
	_check("and_it_was_black_before_the_scene_changed", covered[0], "covered %s" % covered[0])
	Transition.covered.disconnect(saw_cover)
	await _leave_this_session()


## ---- 2 to 4: with a joiner ----------------------------------------------------------------------------------------------

func _with_a_joiner_a_launch_is_announced_first() -> void:
	var room: FlightLevel = await _host_the_lobby()
	if room == null:
		return
	var log_path: String = ProjectSettings.globalize_path(TestPorts.log_for("notices", "joiner"))
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(log_path)
	_children.append(OS.create_process(OS.get_executable_path(), PackedStringArray(["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120",
		"--log-file", log_path, "--path", ProjectSettings.globalize_path("res://"), "--", "--join=127.0.0.1:%d" % _port,
		"--report=1", "--latency=125", "--leave-in=%s:2" % FLIGHT])))

	# 2: WHO JOINED, on both machines' flat lines.
	var host_joined: String = await _until_drawn_here(room, "JOINED", "")
	_check("the_host_draws_who_joined", host_joined.begins_with("PLAYER ") and host_joined.contains(" JOINED"),
		"the host's line reads '%s'" % host_joined)
	var joiner_joined: String = await _until_in_the_log(log_path, "words=YOU JOINED AS PLAYER ")
	_check("and_the_joiner_is_told_its_own_number", joiner_joined != "", "its log said '%s'" % joiner_joined)

	# 3: THE LAUNCH, once the host owes the joiner nothing, so the warning is its own message and not a resend's passenger.
	var since: int = Time.get_ticks_msec()
	while not (Net.get("_notice_owed") as Dictionary).is_empty() \
			and Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
		await get_tree().physics_frame
	# A SECOND REAL PEER CONNECTS DURING THE COUNTDOWN. Net owes the active cue from a peer's arrival, before admission, so
	# it still covers although it missed the original send; its fixed edge delay makes resend and arrival non-uniform.
	#
	# IT IS BOOTED BEFORE THE PRESS, HELD, AND LET GO AFTER IT. It used to be started 0.2 s AFTER the press, which assumed
	# a fresh Godot boots, loads the project and connects inside the 3 s warning. On a quiet machine it does; with six
	# lanes gating at once it did not (`lane/ports`, 2026-09-18, twice in a row in an isolated lane: its engine took
	# 5,577 ms to come up). It arrived after the change, loaded the island directly, never wrote a cue -- and this suite
	# then waited 60 s on each of three lines that could never come, which is EXACTLY the runner's 180 s deadline. That
	# was `notices`' TIMEOUT in nearly every lane's gate, and it was never a port. Now `--hold-until` (world/boot.gd)
	# boots it and holds its join until this suite writes a file, which it does only after the press; and when it
	# connected is measured here and checked to fall between the press and the change.
	var late_log: String = ProjectSettings.globalize_path(TestPorts.log_for("notices", "late_joiner"))
	var let_go: String = ProjectSettings.globalize_path(TestPorts.log_for("notices", "late_joiner_go"))
	for path in [late_log, let_go]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var arrived: Array = [0]
	var saw_arrival := func(_peer: int) -> void:
		if arrived[0] == 0: arrived[0] = Time.get_ticks_msec()
	Net.peer_joined.connect(saw_arrival)
	var booting: int = Time.get_ticks_msec()
	_children.append(OS.create_process(OS.get_executable_path(), PackedStringArray(["--headless", "--xr-mode", "off", "--desktop-only",
		"--fixed-fps", "120", "--log-file", late_log, "--path", ProjectSettings.globalize_path("res://"), "--",
		"--join=127.0.0.1:%d" % _port, "--hold-until=%s" % let_go, "--report=1", "--latency=175",
		"--leave-in=%s:2" % FLIGHT])))
	while not _read(late_log).contains("HOLDING until") and Time.get_ticks_msec() - booting < int(PATIENCE_SECONDS * 1000.0):
		await get_tree().process_frame
	var booted_in: int = Time.get_ticks_msec() - booting
	var pressed_at: int = Time.get_ticks_msec()
	_press_the_launch(room)
	# WHEN THE CHANGE IS MADE, asked of Net at the press rather than read off this process seeing `Net.level` move, which
	# lags the change by the host's own reload (564 to 832 ms, see RELOAD_GRACE_MSEC).
	var changed_at: int = pressed_at + Net.level_called_in()
	var go := FileAccess.open(let_go, FileAccess.WRITE)
	if go != null:
		go.store_string("pressed at %d" % pressed_at)
		go.close()
	_check("with_somebody_to_tell_the_press_does_not_change_the_level",
		Net.level == ROOM and Net.level_called_in() > 0, "level %s, called in %d ms" % [Net.level, Net.level_called_in()])
	while Net.level != FLIGHT and Time.get_ticks_msec() - pressed_at < int(PATIENCE_SECONDS * 1000.0):
		await get_tree().physics_frame
	var waited: int = Time.get_ticks_msec() - pressed_at
	_check("and_the_host_changes_it_after_the_warning", Net.level == FLIGHT and waited >= Net.LEVEL_WARNING_MSEC,
		"level %s after %d ms, the warning is %d" % [Net.level, waited, Net.LEVEL_WARNING_MSEC])
	await _until_in_the_log(log_path, "NET_LEVEL_CHANGING ")
	var said: String = _read(log_path)
	var warned_at: int = said.find("NOTICE_DRAWN level=%s" % ROOM)
	var warning: String = _line_at(said, said.find("words=EVERYBODY TO", maxi(warned_at, 0)))
	var changing_at: int = said.find("NET_LEVEL_CHANGING ")
	_check("the_joiner_drew_the_warning_in_the_lobby_before_its_level_changed",
		warning.contains("level=%s" % ROOM) and warning.contains(" IN ") and changing_at > said.find(warning) \
			and said.find(warning) >= 0,
		"warning '%s' at %d, the change at %d" % [warning, said.find(warning), changing_at])
	await _until_in_the_log(log_path, "TRANSITION_REVEALED target=%s" % FLIGHT)
	said = _read(log_path)
	var cue_at: int = said.find("TRANSITION_CUE target=%s" % FLIGHT)
	var black_at: int = said.find("TRANSITION_COVERED target=%s" % FLIGHT)
	var reveal_at: int = said.find("TRANSITION_REVEALED target=%s" % FLIGHT)
	_check("the_delayed_joiner_covers_before_replacing_and_reveals_after_build",
		cue_at >= 0 and black_at > cue_at and changing_at > black_at and reveal_at > changing_at,
		"cue %d, black %d, changing %d, reveal %d" % [cue_at, black_at, changing_at, reveal_at])
	Net.peer_joined.disconnect(saw_arrival)
	_check("the_late_joiner_connected_after_the_press_and_before_the_change",
		arrived[0] > pressed_at and arrived[0] < changed_at,
		"booted and held in %d ms; connected %d ms after the press; the change came %d ms after it" % [
			booted_in, arrived[0] - pressed_at if arrived[0] > 0 else -1, changed_at - pressed_at])
	# ONE WAIT, ON EITHER ENDING: the reveal, or the island's own notice, which follows the reveal when there is one and is
	# drawn anyway when there is not. Three waits of 60 s on lines a late arrival never writes was the hang above.
	await _until_in_the_log_any(late_log, ["TRANSITION_REVEALED target=%s" % FLIGHT, "NOTICE_DRAWN level=%s" % FLIGHT])
	var late_said: String = _read(late_log)
	var late_cue: String = _line_at(late_said, late_said.find("TRANSITION_CUE target=%s" % FLIGHT))
	var late_change: String = _line_at(late_said, late_said.find("NET_LEVEL_CHANGING "))
	var late_reveal: String = _line_at(late_said, late_said.find("TRANSITION_REVEALED target=%s" % FLIGHT))
	var late_cue_at: int = late_said.find("TRANSITION_CUE target=%s" % FLIGHT)
	var late_black_at: int = late_said.find("TRANSITION_COVERED target=%s" % FLIGHT)
	var late_change_at: int = late_said.find("NET_LEVEL_CHANGING ")
	var late_reveal_at: int = late_said.find("TRANSITION_REVEALED target=%s" % FLIGHT)
	_check("a_peer_arriving_during_the_countdown_also_covers_before_change_and_reveals_after_build",
		late_cue != "" and late_change != "" and late_reveal != "" and late_cue_at >= 0 and late_black_at > late_cue_at \
			and late_change_at > late_black_at and late_reveal_at > late_change_at,
		"cue %d, black %d, changing %d, reveal %d" % [late_cue_at, late_black_at, late_change_at, late_reveal_at])

	# 4: WHO LEFT: the joiner presses MAIN MENU two seconds into the island.
	var host_left: String = await _until_drawn_here(get_tree().current_scene as FlightLevel, " LEFT", FLIGHT)
	_check("when_the_joiner_leaves_through_main_menu_the_host_draws_who_left",
		host_left.begins_with("PLAYER ") and host_left.ends_with(" LEFT") and _read(log_path).contains("LEAVING through"),
		"the host's line reads '%s'" % host_left)


## ---- 5: a joiner that never answers ---------------------------------------------------------------------------------
##
## THE COUNT-DOWN STARTS AT THE PRESS AND WAITS ON NOBODY: `Net.call_the_level` fixes `due` there, and `_keep_the_notices`
## makes the change when it passes, whether or not anybody has said `notice_heard`. So a joiner on a bad link, or one that
## has just crashed, cannot hold the session in the lobby. This holds it: a joiner killed outright -- no MAIN MENU, so ENet
## goes on counting it as connected for seconds -- and the host calls the lobby. It is called through `Net.call_the_level`
## directly, because the island has no launch board; section 3 holds that the board is what calls it.
##
## THE BOUND is the warning plus `RELOAD_GRACE_MSEC`. Measured before it was set (2026-09-16, this suite, three runs): the
## level change is MADE 3003 ms after the press, and the suite sees `Net.level` move 564 to 832 ms later, because the host's
## own deferred reload of `sky.tscn` finishes inside that frame before this coroutine resumes; `Sim.stop` is 0 to 1 ms of it.
## Two seconds is more than twice the worst, and a change that waited on the dead peer would wait for ENet's timeout, 5 s at
## the least.
const RELOAD_GRACE_MSEC: int = 2000


func _a_joiner_that_never_answers_does_not_hold_the_session() -> void:
	var island := get_tree().current_scene as FlightLevel
	if island == null or Net.level != FLIGHT:
		_check("the_host_is_on_the_island_for_section_5", false, "level %s" % Net.level)
		return
	var log_path: String = ProjectSettings.globalize_path(TestPorts.log_for("notices", "crashed"))
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(log_path)
	var doomed: int = OS.create_process(OS.get_executable_path(), PackedStringArray(["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120",
		"--log-file", log_path, "--path", ProjectSettings.globalize_path("res://"), "--", "--join=127.0.0.1:%d" % _port,
		"--report=1"]))
	_children.append(doomed)
	var joined: String = await _until_drawn_here(island, "JOINED", FLIGHT)
	OS.kill(doomed)
	var still_counted: bool = Net.has_anybody_to_tell()
	var pressed_at: int = Time.get_ticks_msec()
	var why: String = Net.call_the_level(ROOM)
	var owed_at_the_call: int = (Net.get("_notice_owed") as Dictionary).size()
	while Net.level != ROOM and Time.get_ticks_msec() - pressed_at < int(PATIENCE_SECONDS * 1000.0):
		await get_tree().physics_frame
	var waited: int = Time.get_ticks_msec() - pressed_at
	_check("a_killed_joiner_is_still_counted_so_the_call_is_warned",
		joined != "" and still_counted and why == "" and owed_at_the_call > 0,
		"joined '%s', counted %s, called '%s', owed %d" % [joined, still_counted, why, owed_at_the_call])
	_check("and_the_host_leaves_at_the_warning_all_the_same",
		Net.level == ROOM and waited >= Net.LEVEL_WARNING_MSEC and waited <= Net.LEVEL_WARNING_MSEC + RELOAD_GRACE_MSEC,
		"level %s after %d ms, bound %d" % [Net.level, waited, Net.LEVEL_WARNING_MSEC + RELOAD_GRACE_MSEC])
	# AND LET THE LOBBY FINISH STANDING before the suite stops the simulation under it: `_finish` stopping `Sim` mid-build
	# left the level's own `_mark_the_edge` asking a world that had gone ("Nonexistent function 'turn_radii' in base
	# 'Nil'", the first run of this section).
	await _the_level_comes_up(ROOM)


## ---- the machinery -----------------------------------------------------------------------------------------------------

## HOST THE LOBBY, as the desk does: the level chosen, `Net.host`, the flight level's scene, and its launch board up.
func _host_the_lobby() -> FlightLevel:
	_check("the_lobby_is_chosen", Net.choose_level(ROOM) == "", "Net.level %s" % Net.level)
	_port = TestPorts.first_free(FIRST_PORT, PORTS)
	if _port == 0:
		_check("a_port_was_free_to_host_on", false, TestPorts.busy(FIRST_PORT, PORTS))
		return null
	Net.host(_port)
	if not Net.is_in_session:
		_check("the_lobby_is_hosted_on_port_%d" % _port, false, "Net.transport %s" % Net.transport)
		return null
	get_tree().change_scene_to_file("res://world/sky.tscn")
	return await _the_level_comes_up(ROOM)


func _the_level_comes_up(id: String) -> FlightLevel:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
		var level := get_tree().current_scene as FlightLevel
		if level != null and level.level != null and level.level.id == id and Sim.is_ready and level.rig != null \
				and level.rig.is_seated() and (id != ROOM or (level.room != null and level.room.board != null)):
			return level
		await get_tree().physics_frame
	_check("the_%s_comes_up" % id, false, "scene %s" % get_tree().current_scene)
	return null


func _press_the_launch(room: FlightLevel) -> void:
	var board := room.room.board.shown() as ChartMenu
	(board.level_buttons[FLIGHT] as Button).pressed.emit()


func _leave_this_session() -> void:
	Sim.stop()
	Net.leave("suite: the next section")
	get_tree().unload_current_scene()
	await get_tree().process_frame


## THE NOTICE ON THIS MACHINE'S FLAT STATUS LINE, off the Label itself: its first line, once it holds `words`.
func _until_drawn_here(level: FlightLevel, words: String, on: String) -> String:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
		var current := get_tree().current_scene as FlightLevel
		if current != null and (on == "" or (current.level != null and current.level.id == on)):
			level = current
		var status := level.get("_status") as Label if level != null and is_instance_valid(level) else null
		var first: String = status.text.get_slice("\n", 0) if status != null else ""
		if first.contains(words):
			return first
		await get_tree().physics_frame
	return ""


func _until_in_the_log(path: String, words: String) -> String:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
		var said: String = _read(path)
		if said.contains(words):
			return _line_at(said, said.find(words))
		await get_tree().physics_frame
	return ""


## The first of `any` to appear in the log, as its line, or "" once the patience runs out.
func _until_in_the_log_any(path: String, any: Array) -> String:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
		var said: String = _read(path)
		for words in any:
			if said.contains(String(words)):
				return _line_at(said, said.find(String(words)))
		await get_tree().physics_frame
	return ""


static func _line_at(said: String, at: int) -> String:
	if at < 0:
		return ""
	var start: int = said.rfind("\n", at) + 1
	var end: int = said.find("\n", at)
	return said.substr(start, (end if end >= 0 else said.length()) - start).strip_edges()


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _finish() -> void:
	for pid in _children:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_children.clear()
	Sim.stop()
	Net.leave("suite over")
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
