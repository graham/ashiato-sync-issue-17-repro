extends Node
## A real ENet host, a joiner, then a late joiner: all three converge on one roster.
##
## AND STEAM NAMES (lane/buildtime, 2026-09-19: "if it's available, we should have players names pulled from steam (not
## player 1, player 2)"). A fourth process, CAROL, types no name, and her Steam persona arrives only AFTER the host has
## acknowledged her first card (`--pretend-persona=CAROL@heard`), which is Steam starting late: her card went out as
## "PLAYER N", and every machine must end up calling her CAROL. The host has a persona too, STEAMHOST, and typed HOST,
## and the typed name must win. Every child is headless, and each must say it did not start Steam.
## Mutants: `_keep_my_card` returning at once (CAROL stays PLAYER N: `a_late_steam_name_reaches_every_machine`); the
## typed name losing to the persona (`each_peer_has_the_validated_cards`).

const FIRST_PORT: int = 47940
const PORTS: int = 8
const PATIENCE_MSEC: int = 70000
var children: Array[int] = []
var failures: PackedStringArray = []


func check(label: String, ok: bool, detail: String) -> void:
	print("[names_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: failures.append(label)


func _ready() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	# THIS CHECKOUT'S PORTS (`TestPorts`), the first free one asked silently before the host starts; 0 once none is.
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	var reports: Array[Dictionary] = []
	while port != 0:
		await bury()
		var logs := PackedStringArray([
			ProjectSettings.globalize_path(TestPorts.log_for("names_peers", "host")),
			ProjectSettings.globalize_path(TestPorts.log_for("names_peers", "alice")),
			ProjectSettings.globalize_path(TestPorts.log_for("names_peers", "bob")),
			ProjectSettings.globalize_path(TestPorts.log_for("names_peers", "carol"))])
		for path in logs:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		children.append(spawn(project, logs[0], ["--host=%d" % port, "--world=lobby", "--report=1",
			"--player-name=HOST", "--player-colour=1", "--pretend-persona=STEAMHOST"]))
		await get_tree().create_timer(0.3).timeout
		if read(logs[0]).contains("BOOT_ERROR=Could not listen"):
			port = TestPorts.first_free(FIRST_PORT, PORTS, port)
			continue
		children.append(spawn(project, logs[1], ["--join=127.0.0.1:%d" % port, "--report=1",
			"--player-name=ALICE", "--player-colour=3"]))
		var first: bool = await wait_for(logs.slice(0, 2), 2)
		check("the_first_joiner_reaches_the_authoritative_roster", first, latest(read(logs[0])).get("roster", "-"))
		children.append(spawn(project, logs[2], ["--join=127.0.0.1:%d" % port, "--report=1",
			"--player-name=BOB", "--player-colour=6"]))
		var late: bool = await wait_for(logs.slice(0, 3), 3)
		check("a_late_joiner_and_both_existing_peers_converge", late, latest(read(logs[0])).get("roster", "-"))
		children.append(spawn(project, logs[3], ["--join=127.0.0.1:%d" % port, "--report=1",
			"--pretend-persona=CAROL@heard"]))
		var named: bool = await wait_for_name(logs, ":CAROL:")
		for path in logs: reports.append(latest(read(path)))
		# HER FIRST CARD WAS THE FALLBACK: the host's roster said PLAYER_n for her before it said CAROL, so what is proved
		# is a card said again, not a persona that happened to be there first.
		# Read off the host's NET_ROSTER lines, one per revision it publishes: four cards TWICE is her fallback card and
		# then her named one. (Its once-a-second SESSION_REPORT missed the fallback: the card is said again in a frame.)
		var fallback_first: bool = read(logs[0]).count("cards=4") >= 2
		var rosters: PackedStringArray = []
		for report in reports:
			rosters.append(String(report.get("roster", "-")))
		check("a_late_steam_name_reaches_every_machine", named and fallback_first,
			"fallback first %s; %s" % [fallback_first, " | ".join(rosters)])
		var said_no: bool = true
		for path in logs:
			said_no = said_no and read(path).contains("STEAM_AT_BOOT=no (headless)")
		check("no_headless_peer_started_steam", said_no, "every child says STEAM_AT_BOOT=no (headless)")
		break
	await bury()
	check("a_port_was_available", port != 0, "port %d" % port if port != 0 else TestPorts.busy(FIRST_PORT, PORTS))
	for report in reports:
		var roster: String = String(report.get("roster", ""))
		check("each_peer_has_the_validated_cards", roster.contains(":HOST:1") and roster.contains(":ALICE:3")
			and roster.contains(":BOB:6") and roster.contains(":CAROL:") and not roster.contains("STEAMHOST"), roster)
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL " + ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


func spawn(project: String, log_path: String, user_args: Array[String]) -> int:
	var args: Array[String] = ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--log-file", log_path,
		"--path", project, "--"]
	args.append_array(user_args)
	return OS.create_process(OS.get_executable_path(), args)


func wait_for(logs: PackedStringArray, wanted: int) -> bool:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < PATIENCE_MSEC:
		var all: bool = true
		for path in logs:
			var report: Dictionary = latest(read(path))
			all = all and String(report.get("roster", "")).split(",", false).size() == wanted
		if all: return true
		await get_tree().create_timer(0.1).timeout
	return false


## Until every log's latest roster holds `words`.
func wait_for_name(logs: PackedStringArray, words: String) -> bool:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < PATIENCE_MSEC:
		var all: bool = true
		for path in logs:
			all = all and String(latest(read(path)).get("roster", "")).contains(words)
		if all: return true
		await get_tree().create_timer(0.1).timeout
	return false


func latest(text: String) -> Dictionary:
	var out: Dictionary = {}
	for line in text.split("\n"):
		if not line.begins_with("SESSION_REPORT "): continue
		out.clear()
		for pair in line.substr(15).strip_edges().split(" ", false):
			var at: int = pair.find("=")
			if at > 0: out[pair.left(at)] = pair.substr(at + 1)
	return out


func read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func bury() -> void:
	var old: Array[int] = children.duplicate()
	children.clear()
	for pid in old:
		if pid > 0 and OS.is_process_running(pid): OS.kill(pid)
	var since: int = Time.get_ticks_msec()
	for pid in old:
		while OS.is_process_running(pid) and Time.get_ticks_msec() - since < 5000:
			await get_tree().create_timer(0.05).timeout


func _exit_tree() -> void:
	for pid in children:
		if pid > 0 and OS.is_process_running(pid): OS.kill(pid)
