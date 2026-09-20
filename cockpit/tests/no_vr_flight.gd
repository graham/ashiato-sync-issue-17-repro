extends Node
## Headless, two machines: THE WHOLE FLOW WITH NO HEADSET. Start the game, join the lobby, have the host launch the
## island from the briefing room, follow it there, and then change seat and change craft -- every step through the
## control a person would actually touch.
##
##   Godot --headless --path cockpit res://tests/no_vr_flight.tscn
##
## THIS IS THE NO-VR PATH, AND THAT IS WHY IT EXISTS. The user, 2026-09-15: "Please make sure we have a way to (without
## vr) start up the game, join the lobby and start a island level, change seats and planes that way we can test this
## without VR which is a requirement for this coding agent, since it can't use a vr headset." This machine has no
## headset and no agent working here can put one on, so a flow that can only be exercised by a person wearing one is a
## flow that silently rots: nothing exercises it on any commit, and the day it breaks nobody finds out until somebody
## puts the headset on. Every step below is pressed on a desk -- a real `Button` on a real screen, a real `LineEdit`
## typed into, or a real key through `Input.parse_input_event` with both `keycode` and `physical_keycode` set
## (CLAUDE.md, rule 9) -- and every answer is read off the rig or off the other machine's report, never off the thing
## that was pressed.
##
## THIS PROCESS IS THE JOINER, which is the user's own order of events ("start up the game, join the lobby"). The host
## is a child started with `--host=PORT --launch=island --report=1`: it chooses no level, so it starts in the LOBBY by
## the day's rule, and `--launch=` has it press the island on its own briefing room's launch board once a second player
## is in the room -- the same real `Button`, pressed the way `--board=` presses JOIN on a CREW page. Only the host may
## change the level, so the launch has to happen over there.
##
## WHAT IS NOT PROVED HERE, said plainly: nothing about a headset. The same controls exist in one -- the launch board is
## handed to `PilotRig.pointer_panels`, which is what the hand beam points at, and F, G and H are buttons on the input
## frame that a headset's controllers set through their own bindings -- but this suite presses the desk's half, because
## the desk's half is the half a machine with no headset can press.
##
## THIS CHECKOUT'S PORTS (`TestPorts`), the first free one asked silently before a child starts, from these:
## PORTS 47966-47969, which no other suite uses (steam_join 47961-47963, code_pad 47964-47965, lobby_peers 47970-47977).
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 47966
const PORTS: int = 4
## Wall seconds for this process's UI and replicated seat changes. `--fixed-fps` deliberately
## runs frames faster than time, while child processes and sockets still advance on wall time.
const LOCAL_SECONDS: float = 20.0
## How long a key is held before it is let go: the frame the rig reads it, and a few either side.
const KEY_FRAMES: int = 10
## Seconds to give the child host to say something.
const CHILD_SECONDS: float = 60.0
## The level the briefing room launches into.
const FLIGHT: String = "island"

var _failures: PackedStringArray = []
var _sections: int = 0
var _child: int = 0
var _port: int = 0
var _log: String = ""


func _check(label: String, ok: bool, detail: String) -> void:
	print("[no_vr_flight] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## IT SURVIVES ITS OWN SCENE CHANGES -- the desk, then the lobby, then the island -- by hanging a copy of this script on
## the root, the way tests/levels.gd and tests/desk_join.gd do.
func _ready() -> void:
	if get_tree().current_scene != self:
		_run()
		return
	var watcher := Node.new()
	watcher.name = "NoVrWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld missing")
		_finish()
		return
	if not await _a_host_starts_the_game_and_waits_in_the_lobby():
		_finish()
		return
	var briefing: FlightLevel = await _this_player_joins_the_lobby_from_the_main_menu()
	if briefing == null:
		_finish()
		return
	var sky: FlightLevel = await _the_host_launches_the_island_and_this_machine_follows()
	if sky == null:
		_finish()
		return
	await _change_seat_and_change_craft(sky)
	_check("every_section_of_the_suite_ran", _sections == 4, "%d of 4" % _sections)
	_finish()


## ---- 1: a host starts the game, and is in the briefing room ----------------------------------------------------------

## THE SECOND MACHINE, started from a cold command line with nothing chosen. `--host` goes through `world/boot.gd` to
## `Net.host`, which is the same function the desk's HOST button calls, so "nothing chosen means the lobby" holds on
## both doors. What this section holds is that a host reaches a briefing room without anybody touching a headset.
func _a_host_starts_the_game_and_waits_in_the_lobby() -> bool:
	var project: String = ProjectSettings.globalize_path("res://")
	var started: bool = false
	var said: Dictionary = {}
	_port = TestPorts.first_free(FIRST_PORT, PORTS)
	while _port != 0 and not started:
		_log = ProjectSettings.globalize_path(TestPorts.log_for("no_vr_flight", "host_%d" % _port))
		if FileAccess.file_exists(_log):
			DirAccess.remove_absolute(_log)
		_child = OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only",
			"--fixed-fps", "120", "--log-file", _log,
			"--path", project, "--", "--host=%d" % _port, "--launch=%s" % FLIGHT, "--report=1"])
		said = await _wait_for_the_child(func(report: Dictionary) -> bool:
			return report.get("role") == "host" or _read().contains("BOOT_ERROR=Could not listen"))
		if _read().contains("BOOT_ERROR=Could not listen"):
			var next: int = TestPorts.first_free(FIRST_PORT, PORTS, _port)
			print("[no_vr_flight] port %d is in use; trying %d" % [_port, next])
			_kill_the_child()
			_port = next
			continue
		started = true
	_check("a_port_was_free_to_host_on", started, "on %d" % _port if started else TestPorts.busy(FIRST_PORT, PORTS))
	_check("a_host_starting_the_game_with_nothing_chosen_waits_in_the_lobby",
		said.get("role") == "host" and String(said.get("level", "")) == ChartDrawer.HOSTING
			and int(said.get("pilots", 0)) == 1, "the host said %s" % [said])
	_sections += 1
	return started and String(said.get("level", "")) == ChartDrawer.HOSTING


## ---- 2: this player joins the lobby, from the main menu --------------------------------------------------------------

## FROM A COLD MAIN MENU, WITH A MOUSE AND A KEYBOARD: the address typed into the real field and the real Join button
## pressed, which is tests/desk_join.gd's path. What is new here is where it lands -- a briefing room, on a segway,
## with the host standing in it.
func _this_player_joins_the_lobby_from_the_main_menu() -> FlightLevel:
	Sim.stop()
	Net.leave("suite")
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
	_check("the_game_starts_at_a_main_menu_with_an_address_to_type_into", menu != null and field != null,
		"screen %s, field %s" % [menu, field])
	if field == null:
		_sections += 1
		return null
	field.text = "127.0.0.1:%d" % _port
	_press_the_button(menu, "Join")
	var briefing: FlightLevel = await _the_level_that_comes_up(ChartDrawer.HOSTING)
	_check("and_joining_lands_this_player_in_the_hosts_briefing_room_on_a_segway",
		briefing != null and briefing.level != null and briefing.level.id == ChartDrawer.HOSTING
			and briefing.room != null and briefing.rig != null and briefing.rig.is_seated()
			and briefing.rig.vehicle_view() != null and briefing.rig.vehicle_view().kind == Sim.Kind.SEGWAY,
		"level %s, room %s, standing in %s" % [
			briefing.level.id if briefing != null and briefing.level != null else "-",
			briefing.room if briefing != null else null,
			Sim.kind_name(briefing.rig.vehicle_view().kind) if briefing != null and briefing.rig != null
				and briefing.rig.vehicle_view() != null else "nothing"])
	if briefing == null or briefing.room == null:
		_sections += 1
		return null
	# AND EACH MACHINE SEES THE OTHER'S SEGWAY, on its own manifest: `crew` is the word the CREW page lists.
	var mine: String = await _my_crew_line(briefing, 2)
	var said: Dictionary = await _wait_for_the_child(func(report: Dictionary) -> bool:
		return int(report.get("pilots", 0)) == 2)
	_check("and_both_machines_see_two_players_standing_on_segways",
		_two_of(mine, "segway") and _two_of(String(said.get("crew", "")), "segway")
			and int(said.get("clients", 0)) == 2,
		"this machine '%s', the host said %s" % [mine, said])
	_sections += 1
	return briefing


## ---- 3: the host launches, and this machine follows ------------------------------------------------------------------

## THE HOST PRESSES THE ISLAND ON ITS BRIEFING ROOM'S LAUNCH BOARD, and this machine -- which pressed nothing, chose
## nothing and joined nothing a second time -- is in the island a moment later, flying. That is item 11 and plan item
## 2d at once: with the lobby being a level, launching the briefing into the flight IS the host changing the level.
func _the_host_launches_the_island_and_this_machine_follows() -> FlightLevel:
	var launched: bool = false
	var launch_since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - launch_since < int(CHILD_SECONDS * 1000.0):
		if _read().contains("LAUNCHING %s" % FLIGHT):
			launched = true
			break
		await get_tree().physics_frame
	_check("the_host_presses_the_island_on_its_launch_board", launched, "the host's log %s say so"
		% ["does" if launched else "does not"])
	var sky: FlightLevel = await _the_level_that_comes_up(FLIGHT)
	_check("and_this_machine_follows_it_there_without_joining_again",
		sky != null and sky.level != null and sky.level.id == FLIGHT and sky.room == null
			and sky.rig != null and sky.rig.is_seated() and Net.is_in_session and not Net.is_host,
		"level %s, room %s, seated %s, in session %s" % [
			sky.level.id if sky != null and sky.level != null else "-", sky.room if sky != null else null,
			sky.rig.is_seated() if sky != null and sky.rig != null else false, Net.is_in_session])
	if sky == null or sky.level == null or sky.level.id != FLIGHT:
		_sections += 1
		return null
	var said: Dictionary = await _wait_for_the_child(func(report: Dictionary) -> bool:
		return String(report.get("level", "")) == FLIGHT and int(report.get("pilots", 0)) == 2)
	var mine: String = await _my_crew_line(sky, 2)
	_check("and_both_machines_are_flying_the_island_together_again",
		String(said.get("level", "")) == FLIGHT and int(said.get("clients", 0)) == 2
			and int(said.get("pilots", 0)) == 2 and not mine.contains("segway")
			and not String(said.get("crew", "")).contains("segway"),
		"this machine '%s', the host said %s" % [mine, said])
	_sections += 1
	return sky


## ---- 4: change seat, change craft --------------------------------------------------------------------------------------

## THE KEYS A PLAYER HAS, pressed through the real event queue and read back off the RIG rather than off the key.
##
## F is the next seat in this craft, G the next craft, H the next KIND of craft. All three are BUTTONS ON THE INPUT
## FRAME (`Sim.BUTTON_SEAT`, `BUTTON_USE`, `BUTTON_KIND`), so it is the server that moves the pilot and this reads where
## the pilot ended up -- over a real socket, on a machine that is not the host, which is the harder half.
##
## THE THREE ARE DIFFERENT QUESTIONS AND ARE ASKED SEPARATELY. F must change the seat and NOT the craft; G must change
## the craft; H must change the KIND, which is the "and planes" in what was asked for -- a G that walked from one pod to
## the next pod would pass a check that only asked whether something had changed.
func _change_seat_and_change_craft(sky: FlightLevel) -> void:
	var rig: PilotRig = sky.rig
	var arrived: VehicleView = rig.vehicle_view()
	_check("this_player_arrives_in_a_craft_with_more_than_one_seat", arrived != null and arrived.seats.size() > 1,
		"a %s with %d seat(s)" % [Sim.kind_name(arrived.kind) if arrived != null else "?",
			arrived.seats.size() if arrived != null else 0])
	if arrived == null or arrived.seats.size() < 2:
		_sections += 1
		return
	# F: THE NEXT SEAT IN THIS CRAFT, and the same craft afterwards.
	var seat_was: int = rig.seat_index()
	var craft_was: int = arrived.entity
	await _press_the_key(KEY_F)
	await _until(func() -> bool: return rig.seat_index() != seat_was)
	var after_f: VehicleView = rig.vehicle_view()
	_check("pressing_f_changes_seat_within_the_craft_it_is_in", rig.seat_index() != seat_was
		and after_f != null and after_f.entity == craft_was,
		"seat %d -> %d, craft %d -> %d" % [seat_was, rig.seat_index(), craft_was,
			after_f.entity if after_f != null else 0])
	# G: THE NEXT CRAFT.
	var before: int = after_f.entity if after_f != null else 0
	await _press_the_key(KEY_G)
	await _until(func() -> bool:
		var now: VehicleView = rig.vehicle_view()
		return now != null and now.entity != before)
	var after_g: VehicleView = rig.vehicle_view()
	_check("pressing_g_changes_craft", after_g != null and after_g.entity != before and rig.is_seated(),
		"craft %d -> %d, a %s" % [before, after_g.entity if after_g != null else 0,
			Sim.kind_name(after_g.kind) if after_g != null else "?"])
	# H: THE NEXT KIND OF CRAFT -- out of the pods and into something that flies, which is the "and planes".
	var kind_was: int = after_g.kind if after_g != null else -1
	await _press_the_key(KEY_H)
	await _until(func() -> bool:
		var now: VehicleView = rig.vehicle_view()
		return now != null and now.kind != kind_was)
	var after_h: VehicleView = rig.vehicle_view()
	_check("and_pressing_h_changes_the_kind_of_craft", after_h != null and after_h.kind != kind_was
		and rig.is_seated(), "a %s -> a %s" % [Sim.kind_name(kind_was),
			Sim.kind_name(after_h.kind) if after_h != null else "?"])
	# J: THE GEAR, in a craft that has some. H again until this seat flies one, then J, and this machine's own copy of the
	# bus -- the server's answer come back over the wire -- is what is read, never the key.
	var geared: VehicleView = rig.vehicle_view()
	for i in range(Sim.Kind.size()):
		# FLYING WITH ITS GEAR UP, so the press is one the squat switch cannot refuse.
		if geared != null and geared.channel_range(Sim.Channel.GEAR) > 0 and rig.seat_index() == 0 \
				and not bool(Sim.client.craft_controls(geared.entity).get("gear", true)):
			break
		var was: int = geared.kind if geared != null else -1
		await _press_the_key(KEY_H)
		await _until(func() -> bool:
			var now: VehicleView = rig.vehicle_view()
			return now != null and now.kind != was)
		geared = rig.vehicle_view()
	if geared == null or geared.channel_range(Sim.Channel.GEAR) <= 0 \
			or bool(Sim.client.craft_controls(geared.entity).get("gear", true)):
		_check("a_desk_pilot_finds_a_flying_craft_with_its_gear_up", false, "last a %s" % [Sim.kind_name(geared.kind) if geared else "?"])
	else:
		var gear_was: bool = bool(Sim.client.craft_controls(geared.entity).get("gear", false))
		await _press_the_key(KEY_J)
		await _until(func() -> bool: return bool(Sim.client.craft_controls(geared.entity).get("gear", false)) != gear_was)
		var gear_now: bool = bool(Sim.client.craft_controls(geared.entity).get("gear", false))
		_check("and_pressing_j_moves_the_gear_on_the_bus", gear_now != gear_was,
			"a %s in the air, gear %s -> %s" % [Sim.kind_name(geared.kind), gear_was, gear_now])
	_sections += 1


## ---- the machinery -----------------------------------------------------------------------------------------------------

## THE LEVEL THAT COMES UP, waited for: a `FlightLevel` that says it is the level asked for, with the session ready and
## this machine seated in it, plus a moment for the other player to arrive on the manifest.
func _the_level_that_comes_up(id: String) -> FlightLevel:
	# ON THE WALL CLOCK, not `PATIENCE` frames. Since plan item 13 a launch with somebody to tell waits
	# `Net.LEVEL_WARNING_MSEC` of wall time, and under `--fixed-fps` 2400 frames ran out first: "level lobby, room
	# BriefingRoom, seated true" (2026-09-16), with the host's own change still to come.
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(CHILD_SECONDS * 1000.0):
		var level := get_tree().current_scene as FlightLevel
		if level != null and level.level != null and level.level.id == id and Sim.is_ready \
				and level.rig != null and level.rig.is_seated():
			for j in range(60):
				await get_tree().physics_frame
			return level
		await get_tree().physics_frame
	return get_tree().current_scene as FlightLevel


## THIS MACHINE'S OWN CREW LINE, once it lists `how_many` craft: the same word the report prints, off the same function.
func _my_crew_line(level: FlightLevel, how_many: int) -> String:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(CHILD_SECONDS * 1000.0):
		var line: String = String(level.call("_crew_line"))
		if line.split("/", false).size() >= how_many:
			return line
		await get_tree().physics_frame
	return String(level.call("_crew_line"))


## Whether a crew line is exactly two craft of one kind.
func _two_of(crew: String, kind: String) -> bool:
	var rows: PackedStringArray = crew.split("/", false)
	if rows.size() != 2:
		return false
	for row in rows:
		if not row.begins_with("%s:" % kind):
			return false
	return true


## THE CHILD'S LATEST `SESSION_REPORT`, waited for until it says what is wanted or the patience runs out.
func _wait_for_the_child(until: Callable) -> Dictionary:
	var since: int = Time.get_ticks_msec()
	var report: Dictionary = {}
	while Time.get_ticks_msec() - since < int(CHILD_SECONDS * 1000.0):
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


## A KEY HELD THROUGH THE REAL EVENT QUEUE and let go again, with both `keycode` and `physical_keycode` set. Held for a
## few frames because the rig reads the keyboard once a physics frame and the button rides an input frame from there.
func _press_the_key(key: Key) -> void:
	_key(key, true)
	for i in range(KEY_FRAMES):
		await get_tree().physics_frame
	_key(key, false)
	for i in range(4):
		await get_tree().physics_frame


func _key(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


func _until(said: Callable) -> bool:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(LOCAL_SECONDS * 1000.0):
		if said.call():
			return true
		await get_tree().physics_frame
	return said.call()


func _press_the_button(menu: Control, words: String) -> void:
	for node in menu.find_children("*", "Button", true, false):
		if (node as Button).text == words:
			(node as Button).pressed.emit()
			return


## THE ADDRESS FIELD on the session screen: the visible LineEdit that is not the join code keypad's, as
## tests/desk_join.gd finds it.
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


func _finish() -> void:
	_kill_the_child()
	Sim.stop()
	Net.leave("suite over")
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
