extends Node
## Headless, three machines: THE SKY IS THE SESSION'S, AND THE FINISH IS NOT.
##
##   Godot --headless --fixed-fps 120 --path cockpit res://tests/sky_peers.tscn
##
## Plan item 17, asked for on 2026-09-15: "time of day and other level options are not synced, graphics detail shouldn't
## be synced, but time of day should. Toggle clouds could also be a networked choice." The distinction is the whole item:
## what the world IS must agree across a session, and what a machine can AFFORD to draw must not. So this holds both halves
## at once, on the same press, rather than one of them.
##
## THIS PROCESS IS THE HOST, on the island (a suite names its level), and every choice is pressed on its own clipboard --
## the real NIGHT button, the real CLOUDS switch and the real FINE SCENERY switch on the rig's own board, which announce to
## the level exactly as a finger's press does. Every answer is read off the OTHER machines' `SESSION_REPORT`, whose `sky`,
## `clouds` and `finish` are what that machine DRAWS (the daylight, the cloud yard, the finish), never `Net`'s fields.
##
##   1. A joiner arrives under the host's day, with clouds, on whatever finish its own display chose.
##   2. The host presses NIGHT, flicks CLOUDS off and FINE SCENERY to the other finish from the joiner's. The joiner follows
##      the first two and NOT the third.
##   3. A second joiner arrives AFTER the change, and its FIRST report is already night with no clouds -- it builds under
##      the host's sky rather than flipping to it once admitted, which is what the level hello carrying the sky is for.
##      It then presses DAY on its own TIME tab (`--press-time=day`), is refused in words on its own board, and still
##      draws night; and the host still draws night. Its TRAFFIC tab has no SAVE BANDWIDTH switch, and the host's has.
##   4. This machine turns joiner, hears a count of 1 from one host, leaves, and follows a FRESH host's first change at a
##      count of 1 again: a count heard in one session is not held against the next.
##
## WHAT IS NOT PROVED HERE: a Steam session. The messages ride the same carriers the hello does, and a lost `sky` is said
## again until it is heard; `tests/level_hello.gd` holds the reading of a malformed one.
##
## PORTS 47940-47947 of this checkout's block (`TestPorts`), which no other suite uses (net_jump 47931, level_hello 47951,
## levels 47952, level_join 47953-47959). Every host -- this machine and the two children -- takes the first of them that
## nothing holds, asked silently first, and the children's logs are this checkout's own. Item 22 of `plan.md` is this
## suite failing "Couldn't create an ENet host." on another lane's sockets (`lane/train`, 2026-09-17).
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 47940
const PORTS: int = 8
## Wall seconds for this machine's own level and acknowledgements. Fixed-fps frames can run
## thousands per wall second while the socket and child process still wait on real time.
const LOCAL_SECONDS: float = 20.0
## Seconds to give a child to say something.
const CHILD_SECONDS: float = 60.0
const FLIGHT: String = "island"

var _failures: PackedStringArray = []
var _children: Array[int] = []
var _port: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[sky_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## IT SURVIVES ITS OWN SCENE CHANGE into the level, by hanging a copy of this script on the root, as tests/no_vr_flight.gd
## does.
func _ready() -> void:
	if get_tree().current_scene != self:
		_run()
		return
	var watcher := Node.new()
	watcher.name = "SkyPeersWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld missing")
		_finish()
		return
	var level: FlightLevel = await _this_machine_hosts()
	if level == null:
		_finish()
		return
	var first_log: String = _log_for("first")
	var first: Dictionary = await _a_joiner_arrives(first_log, [])
	_check("a_joiner_arrives_under_the_hosts_day_with_clouds",
		first.get("sky") == "day" and first.get("clouds") == "on", "the joiner said %s" % [first])
	if first.get("role") != "client":
		_finish()
		return

	# 2: THE HOST PRESSES, ON ITS OWN BOARD -- once it owes the joiner nothing. An admitted peer is owed the sky until it
	# says it heard it, and a press made while that is still outstanding rides the admission's resend rather than the
	# change's own: with this wait missing, a host that told nobody about a change (mutant: `_changed_the_sky` owing no
	# peer) still passed, because the press landed within a few frames of admission (2026-09-16).
	var owed_since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - owed_since < int(LOCAL_SECONDS * 1000.0):
		if (Net.get("_sky_owed") as Dictionary).is_empty():
			break
		await get_tree().physics_frame
	_check("the_host_owes_the_joiner_no_sky_before_it_presses", (Net.get("_sky_owed") as Dictionary).is_empty(),
		"owed %s" % [Net.get("_sky_owed")])
	var page: ClipboardPage = level.rig.clipboard.page()
	page.show_tab(ClipboardPage.Tab.TIME)
	_the_button(page, "NIGHT").pressed.emit()
	(_the_button(page, "CLOUDS") as CheckButton).button_pressed = false
	# THE FINISH THE OTHER WAY FROM THE JOINER'S, whichever that is: a joiner's finish is its own display's default, so the
	# host is put on the joiner's first and then flicked off it, which is a real flick whatever the host started on.
	var joiner_fine: bool = first.get("finish") == "fine"
	var fine_switch := _the_button(page, "FINE SCENERY") as CheckButton
	fine_switch.button_pressed = joiner_fine
	fine_switch.button_pressed = not joiner_fine
	_check("the_host_draws_what_it_pressed",
		level.time_of_day() == DaylightTuning.When.NIGHT and not level.clouds_drawn() and _drawn_fine(level) != joiner_fine,
		"time %d, clouds %s, fine %s" % [level.time_of_day(), level.clouds_drawn(), _drawn_fine(level)])
	var followed: Dictionary = await _wait_for(first_log, func(report: Dictionary) -> bool:
		return report.get("sky") == "night" and report.get("clouds") == "off")
	_check("the_joiner_follows_the_hosts_night_and_its_clouds",
		followed.get("sky") == "night" and followed.get("clouds") == "off", "the joiner said %s" % [followed])
	# THE CLOCK, SAID AS A TIME (2026-09-18): NIGHT is 23:30, at the real time the session runs at.
	var night_said: String = "words=SKY: %s, CLOUDS OFF" % Orrery.words(DaylightTuning.clock_of(DaylightTuning.When.NIGHT))
	var sky_notice: String = await _the_line(first_log, "NOTICE_DRAWN ", night_said)
	_check("and_the_joiner_sees_only_the_newest_sky_choice_as_a_notice",
		sky_notice.contains(night_said), "it drew '%s'" % sky_notice)
	# AND THE FINISH STAYS WHERE IT WAS, read in the SAME report that followed the sky -- so it is not a report from before
	# the host pressed anything.
	_check("and_keeps_its_own_finish", followed.get("finish") == first.get("finish"),
		"the joiner said %s, and %s before the host flicked its own" % [followed, first.get("finish")])

	# 3: A JOINER AFTER THE CHANGE, WHICH THEN TRIES TO SET ITS OWN.
	var late_log: String = _log_for("late")
	var late: Dictionary = await _a_joiner_arrives(late_log, ["--press-time=day", "--report-save-bandwidth"])
	_check("a_second_joiner_arrives", late.get("role") == "client", "it said %s" % [late])
	var first_said: Dictionary = _first_report(_read(late_log))
	_check("a_joiner_after_the_change_arrives_under_the_hosts_night_with_no_clouds",
		first_said.get("sky") == "night" and first_said.get("clouds") == "off",
		"its first report was %s" % [first_said])
	var pressed: String = await _the_line(late_log, "PRESSED_TIME ")
	# A REPORT FROM AFTER THE PRESS, not the last one before it: the log is cut at the PRESSED_TIME line.
	var refused: Dictionary = {}
	var since: int = Time.get_ticks_msec()
	while refused.is_empty() and Time.get_ticks_msec() - since < int(CHILD_SECONDS * 1000.0):
		var said: String = _read(late_log)
		refused = _report_in(said.substr(said.find("PRESSED_TIME ")), false) if said.contains("PRESSED_TIME ") else {}
		await get_tree().physics_frame
	_check("and_pressing_day_on_its_own_board_is_refused_in_words",
		pressed.contains("drawn=night") and pressed.contains("The host sets the time of day"), "it printed '%s'" % pressed)
	_check("and_it_still_draws_night_and_so_does_the_host",
		refused.get("sky") == "night" and level.time_of_day() == DaylightTuning.When.NIGHT,
		"the late joiner said %s, the host draws %d" % [refused, level.time_of_day()])
	# AND SAVE BANDWIDTH IS THE HOST'S: this machine's own TRAFFIC tab offers it, and the joiner's board does not.
	var offered: String = await _the_line(late_log, "SAVE_BANDWIDTH ")
	var page_here: ClipboardPage = level.rig.clipboard.page()
	page_here.show_tab(ClipboardPage.Tab.TRAFFIC)
	_check("save_bandwidth_is_on_the_hosts_board_and_not_a_joiners",
		page_here.offers_save_bandwidth() and offered.contains("offered=false") and offered.contains("host=false"),
		"host offers %s; the joiner printed '%s'" % [page_here.offers_save_bandwidth(), offered])
	await _the_hosts_clock_is_everybodys(level, first_log)
	await _a_joiner_that_saw_a_count_follows_a_fresh_host()
	_finish()


## ---- 3b: any time, and a running clock, are the session's -------------------------------------------------------------
##
## THE CLOCK (2026-09-18): the host sets a quarter to six on its own TIME tab -- FROZEN, then the slider let go at 17:45 --
## and the joiner draws that sun; then 60X, and the joiner's clock, as it works it out from the host's (clock, frame, rate)
## at its own estimate of the session's frame, is the host's own sums at that frame; and a joiner that arrives after, which
## never heard the change as it was made, is on the same running clock from its first report.
##
## TO THE SUN, NOT TO THE MINUTE: a clock a tenth of a degree of sun apart (24 game seconds) is the same sky. The sun a
## machine DRAWS lags its clock by up to a step (`Daylight.STEP_DEGREES`), so the drawn suns are held only while frozen.
const SAME_SKY_DEGREES: float = 0.1
const SAME_DRAWN_SUN: float = 0.05


func _the_hosts_clock_is_everybodys(level: FlightLevel, first_log: String) -> void:
	var page: ClipboardPage = level.rig.clipboard.page()
	page.show_tab(ClipboardPage.Tab.TIME)
	_the_button(page, "FROZEN").pressed.emit()
	var slider := page.find_child("ClockSlider", true, false) as HSlider
	var quarter_to_six: float = 17.0 * 60.0 + 45.0
	if slider == null:
		_check("the_time_tab_has_a_clock_slider", false, "none")
		return
	slider.value = quarter_to_six
	slider.drag_ended.emit(true)
	_check("the_host_sets_a_quarter_to_six_frozen_on_its_own_board",
		absf(Net.clock_now() - quarter_to_six) < 0.01 and Net.clock_rate == 0.0 and absf(level.clock() - quarter_to_six) < 0.01,
		"clock %s at %s, the level draws %s" % [Orrery.words(Net.clock_now()), Net.clock_rate, Orrery.words(level.clock())])
	var frozen: Dictionary = await _wait_for(first_log, func(report: Dictionary) -> bool:
		return report.has("clock") and absf(float(report["clock"]) - quarter_to_six) < 0.01 and float(report.get("rate", -1)) == 0.0)
	var host_sun: float = float(level.daylight.look["sun_height"])
	_check("and_the_joiner_draws_that_sun",
		frozen.has("sun") and absf(float(frozen["sun"]) - host_sun) < SAME_DRAWN_SUN,
		"the joiner draws the sun %s up at %s; the host %.3f up" % [frozen.get("sun"), frozen.get("clock"), host_sun])
	_the_button(page, "60X").pressed.emit()
	var running: Dictionary = await _wait_for(first_log, func(report: Dictionary) -> bool:
		return float(report.get("rate", -1)) == 60.0 and float(report.get("clock", 0.0)) > quarter_to_six + 0.5)
	var off: float = _off_the_hosts_clock(running)
	_check("and_at_60x_the_joiners_running_clock_is_the_hosts",
		off < SAME_SKY_DEGREES, "%.4f degrees of sun from the host's clock at the joiner's frame; clock %s frame %s rate %s" % [
			off, running.get("clock"), running.get("sky_frame"), running.get("rate")])
	var latest_log: String = _log_for("latest")
	var latest: Dictionary = await _a_joiner_arrives(latest_log, [])
	var first_said: Dictionary = _first_report(_read(latest_log))
	var latest_off: float = _off_the_hosts_clock(first_said)
	_check("and_a_joiner_after_the_change_is_on_that_clock_from_its_first_report",
		latest.get("role") == "client" and float(first_said.get("rate", -1)) == 60.0 and latest_off < SAME_SKY_DEGREES,
		"%.4f degrees of sun from the host's clock at its frame; its first report: clock %s frame %s rate %s, role %s" % [
			latest_off, first_said.get("clock"), first_said.get("sky_frame"), first_said.get("rate"), latest.get("role")])


## HOW FAR A REPORTED CLOCK'S SUN IS FROM THE HOST'S, degrees: the host's own (clock, frame, rate) run to the frame the report
## was worked out at, the sums every machine does. 180 for a report with no clock.
static func _off_the_hosts_clock(report: Dictionary) -> float:
	if not report.has("clock") or not report.has("sky_frame"):
		return 180.0
	var hosts: float = Net.clock_at + (float(report["sky_frame"]) - Net.clock_frame) / maxf(Sim.tick_hz, 1.0) \
		* Net.clock_rate / 60.0
	return rad_to_deg(Orrery.sun(hosts).angle_to(Orrery.sun(float(report["clock"]))))


## ---- 4: a count heard in one session is not held against the next --------------------------------------------------
##
## A PEER TAKES ONLY A HIGHER COUNT, so a count that outlived its session would refuse a fresh host's sky for ever: seen
## 1 from one host, and a new host's first change is 1 again. `Net._start_afresh` puts it back to -1, and every door that
## joins goes through it (team-lead asked for the case, 2026-09-16). So THIS machine turns joiner: a host that presses
## NIGHT once somebody is there (count 1), left; then a second host, fresh, that presses EVENING (count 1 again). The
## evening must reach this machine. EVENING and not NIGHT again, because a joiner keeps the last sky it was told when it
## leaves, and a refused count would then look exactly like a followed one. Both hosts are children on the island, pressing their own TIME tab through
## `--press-time`, which waits for another player.
func _a_joiner_that_saw_a_count_follows_a_fresh_host() -> void:
	Sim.stop()
	Net.leave("suite: this machine turns joiner")
	get_tree().unload_current_scene()
	for pid in _children:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_children.clear()
	var first_port: int = TestPorts.first_free(FIRST_PORT, PORTS, _port)
	var first: FlightLevel = await _join_a_host_that_presses("first_host", first_port, DaylightTuning.When.NIGHT)
	var heard: int = int(Net.get("_sky_heard"))
	_check("this_machine_hears_the_first_hosts_night_at_count_1",
		first != null and first.time_of_day() == DaylightTuning.When.NIGHT and heard == 1,
		"draws %d, heard count %d" % [first.time_of_day() if first != null else -1, heard])
	Sim.stop()
	Net.leave("suite: to the second host")
	get_tree().unload_current_scene()
	var second: FlightLevel = await _join_a_host_that_presses("second_host",
		TestPorts.first_free(FIRST_PORT, PORTS, maxi(first_port, _port)), DaylightTuning.When.EVENING)
	_check("and_follows_a_fresh_hosts_evening_at_count_1_again",
		second != null and second.time_of_day() == DaylightTuning.When.EVENING,
		"draws %d, heard count %d" % [second.time_of_day() if second != null else -1, int(Net.get("_sky_heard"))])


## A CHILD HOST ON THE ISLAND that presses `time` once this machine is in, joined the way the desk joins: `Net.join`, the
## session up, and the flight level's scene. The level, once it draws that time or the patience runs out.
func _join_a_host_that_presses(who: String, port: int, time: int) -> FlightLevel:
	if port == 0:
		_check("a_port_was_free_for_the_%s" % who, false, TestPorts.busy(FIRST_PORT, PORTS))
		return null
	var log_path: String = _log_for(who)
	_children.append(OS.create_process(OS.get_executable_path(), PackedStringArray(["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120",
		"--log-file", log_path, "--path", ProjectSettings.globalize_path("res://"), "--", "--host=%d" % port,
		"--world=%s" % FLIGHT, "--report=1", "--press-time=%s" % String(DaylightTuning.When.keys()[time]).to_lower()])))
	await _wait_for(log_path, func(report: Dictionary) -> bool: return report.get("role") == "host")
	Net.join("127.0.0.1", port)
	# ON THE WALL CLOCK, not in frames: under `--fixed-fps` a frame costs what it costs, and 2400 of them passed in about a
	# second while a real socket was still saying hello (the first run of this section, 2026-09-16).
	var since: int = Time.get_ticks_msec()
	while not Net.is_in_session and Time.get_ticks_msec() - since < int(CHILD_SECONDS * 1000.0):
		await get_tree().physics_frame
	if not Net.is_in_session:
		_check("this_machine_joins_%s" % who, false, "transport %s" % Net.transport)
		return null
	get_tree().change_scene_to_file("res://world/sky.tscn")
	since = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(CHILD_SECONDS * 1000.0):
		var level := get_tree().current_scene as FlightLevel
		if level != null and level.time_of_day() == time:
			return level
		await get_tree().physics_frame
	return get_tree().current_scene as FlightLevel


## ---- the machinery -----------------------------------------------------------------------------------------------------

## HOST ON THE ISLAND, as the desk does it: the level chosen, `Net.host`, and the flight level's own scene.
func _this_machine_hosts() -> FlightLevel:
	_check("the_island_is_chosen", Net.choose_level(FLIGHT) == "", "Net.level %s" % Net.level)
	_port = TestPorts.first_free(FIRST_PORT, PORTS)
	if _port == 0:
		_check("a_port_was_free_to_host_on", false, TestPorts.busy(FIRST_PORT, PORTS))
		return null
	Net.host(_port)
	_check("this_machine_hosts_on_port_%d" % _port, Net.is_in_session, "transport %s" % Net.transport)
	if not Net.is_in_session:
		return null
	get_tree().change_scene_to_file("res://world/sky.tscn")
	var level_since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - level_since < int(LOCAL_SECONDS * 1000.0):
		var level := get_tree().current_scene as FlightLevel
		if level != null and level.level != null and level.level.id == FLIGHT and Sim.is_ready and level.rig != null \
				and level.rig.is_seated():
			return level
		await get_tree().physics_frame
	_check("this_machine_is_flying_the_island", false, "scene %s" % get_tree().current_scene)
	return null


func _log_for(who: String) -> String:
	var path: String = ProjectSettings.globalize_path(TestPorts.log_for("sky_peers", who))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return path


## A JOINER, and its report once it is flying beside this machine: two clients named and two pilots drawn.
func _a_joiner_arrives(log_path: String, more: Array) -> Dictionary:
	var arguments: Array = ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--log-file", log_path, "--path",
		ProjectSettings.globalize_path("res://"), "--", "--join=127.0.0.1:%d" % _port, "--report=1"]
	arguments.append_array(more)
	_children.append(OS.create_process(OS.get_executable_path(), PackedStringArray(arguments)))
	return await _wait_for(log_path, func(report: Dictionary) -> bool:
		return report.get("role") == "client" and int(report.get("clients", 0)) >= 2 and int(report.get("pilots", 0)) >= 2)


func _wait_for(log_path: String, until: Callable) -> Dictionary:
	var since: int = Time.get_ticks_msec()
	var report: Dictionary = {}
	while Time.get_ticks_msec() - since < int(CHILD_SECONDS * 1000.0):
		report = _report_in(_read(log_path), false)
		if until.call(report):
			return report
		await get_tree().physics_frame
	return report


func _the_line(log_path: String, starts: String, contains: String = "") -> String:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(CHILD_SECONDS * 1000.0):
		for line in _read(log_path).split("\n"):
			if line.begins_with(starts) and (contains.is_empty() or line.contains(contains)):
				return line.strip_edges()
		await get_tree().physics_frame
	return ""


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _first_report(said: String) -> Dictionary:
	return _report_in(said, true)


## The last `SESSION_REPORT` in a log, or the first, as a Dictionary.
static func _report_in(said: String, first: bool) -> Dictionary:
	var out: Dictionary = {}
	for line in said.split("\n"):
		if not line.begins_with("SESSION_REPORT "):
			continue
		out.clear()
		for pair in line.substr(15).strip_edges().split(" ", false):
			var kv: PackedStringArray = pair.split("=")
			if kv.size() == 2:
				out[kv[0]] = kv[1]
		if first:
			return out
	return out


func _the_button(page: ClipboardPage, words: String) -> Button:
	for node in page.find_children("*", "Button", true, false):
		if (node as Button).text == words:
			return node as Button
	push_error("[sky_peers] no button says %s" % words)
	return Button.new()


## WHAT THE HOST'S OWN SURFACES WEAR, off `finish_worn` rather than off `Finish`: did the switch reach the sea.
static func _drawn_fine(level: FlightLevel) -> bool:
	return bool(level.finish_worn().get("sea", false))


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
