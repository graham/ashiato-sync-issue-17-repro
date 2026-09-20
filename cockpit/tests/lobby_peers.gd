extends Node
## Headless: two real processes standing in the LOBBY, and does each of them see the other's segway?
##
##   Godot --headless --path cockpit res://tests/lobby_peers.tscn
##
## Asked for on 2026-09-15 with the lobby: "let's make a lobby level, where players join". The claim being held is the
## whole reason the lobby is a LEVEL rather than a room you visit -- that a player in the briefing room is an ordinary
## player in an ordinary session, so the segway under them replicates with no new machinery at all. Two players in a
## bare scene would not see each other; these two must.
##
## THE SHAPE IS tests/two_peers.gd's, and deliberately so: a host (`--host=PORT --world=lobby --report=1`) and a joiner
## (`--join=127.0.0.1:PORT --report=1`), both headless, both writing to a log file this reads. A SOCKET IS NOT A PLAYER
## (team-lead, 2026-09-14), so the checks are on what only a joined player makes: two sync clients named on each
## machine, two pilots drawn on each, and the CREW LINE -- `Sim`'s own manifest, as tests/crew_peers.gd reads it --
## naming two segways on both.
##
## THE ISLAND PAIR IS THE CONTRAST, and it is a case rather than a revert. The same two processes on the island give
## `crew=pod:1/pod:2`, which is what this suite would read if `Sim` ever went back to seating a constant kind instead of
## asking the level (`LevelChart.arrive_kind`). Keeping it here means the discrimination cannot quietly rot: if the
## lobby pair stopped saying segway the first case fails, and if the report stopped saying anything useful the second
## does.
##
## THIS CHECKOUT'S PORTS (`TestPorts`), the first free one asked silently before a child starts, from these:
## PORTS 47970-47977, which no other suite uses (level_join 47953-47959, steam_join 47961-47963, code_pad 47964-47965,
## two_peers 47980-47989, crew_peers and desk_join 47990-47999). A host that cannot listen says
## BOOT_ERROR=Could not listen and the next port is tried.
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 47970
const PORTS: int = 8
## Seconds for both worlds to build and the joiner to be seen, before the children are killed.
const PATIENCE_SECONDS: float = 60.0

var _failures: PackedStringArray = []
var _children: Array[int] = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[lobby_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var lobby: Dictionary = await _a_pair_on("lobby")
	_hold(lobby, "lobby", "segway")
	var island: Dictionary = await _a_pair_on("island")
	_hold(island, "island", "pod")
	_finish()


## WHAT A PAIR ON ONE LEVEL MUST HAVE DONE: both machines in one session, both drawing both players, both on that
## level, and both listing one craft of `kind` per player on their CREW page.
func _hold(pair: Dictionary, level: String, kind: String) -> void:
	var host: Dictionary = pair["host"]
	var join: Dictionary = pair["join"]
	_check("a_port_was_free_to_host_%s_on" % level, bool(pair["started"]), "on %d" % int(pair["port"])
		if bool(pair["started"]) else TestPorts.busy(FIRST_PORT, PORTS))
	_check("two_players_stand_in_%s_and_each_draws_the_other" % level,
		int(host.get("clients", 0)) == 2 and int(host.get("pilots", 0)) == 2
		and int(join.get("clients", 0)) == 2 and int(join.get("pilots", 0)) == 2,
		"host %s, joiner %s" % [host, join])
	_check("and_both_are_on_%s" % level, host.get("level") == level and join.get("level") == level,
		"host %s, joiner %s" % [host.get("level"), join.get("level")])
	# THE CREW LINE IS `kind:seat.seat...` per craft, sorted, so two machines that agree print the same word. Two
	# players on this level make two of them, each of `kind`, and each with a client id in its one seat.
	_check("and_each_of_them_lists_two_%ss_with_a_player_on_each" % kind,
		_two_crewed(String(host.get("crew", "")), kind) and _two_crewed(String(join.get("crew", "")), kind),
		"host crew '%s', joiner crew '%s'" % [host.get("crew", "-"), join.get("crew", "-")])


## Whether a crew line is exactly two craft of `kind`, each with somebody in its first seat.
func _two_crewed(crew: String, kind: String) -> bool:
	var rows: PackedStringArray = crew.split("/", false)
	if rows.size() != 2:
		return false
	for row in rows:
		if not row.begins_with("%s:" % kind):
			return false
		var seats: PackedStringArray = row.substr(kind.length() + 1).split(".", false)
		if seats.is_empty() or String(seats[0]) == "-" or not String(seats[0]).is_valid_int():
			return false
	return true


## A HOST AND A JOINER ON ONE LEVEL, run until both report a second player or the patience runs out. `--world=` goes to
## the HOST only: a joiner flies the host's level and is told which, and naming one beside a join is a BOOT_ERROR.
func _a_pair_on(level: String) -> Dictionary:
	var project: String = ProjectSettings.globalize_path("res://")
	var host_log: String = ProjectSettings.globalize_path(TestPorts.log_for("lobby_peers", "%s_host" % level))
	var join_log: String = ProjectSettings.globalize_path(TestPorts.log_for("lobby_peers", "%s_join" % level))
	var host_report: Dictionary = {}
	var join_report: Dictionary = {}
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	var started: bool = false
	var since: int = 0
	while port != 0 and not started:
		for path in [host_log, join_log]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		_children.append(OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--log-file",
			host_log, "--path", project, "--", "--host=%d" % port, "--world=%s" % level, "--report=1"]))
		_children.append(OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--log-file",
			join_log, "--path", project, "--", "--join=127.0.0.1:%d" % port, "--report=1"]))
		since = Time.get_ticks_msec()
		var busy: bool = false
		while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
			var host_said: String = _read(host_log)
			busy = host_said.contains("BOOT_ERROR=Could not listen")
			host_report = _latest_report(host_said)
			join_report = _latest_report(_read(join_log))
			if busy or _joined(host_report, join_report):
				break
			await get_tree().create_timer(0.1).timeout
		await _bury_the_children()
		if busy:
			var next: int = TestPorts.first_free(FIRST_PORT, PORTS, port)
			print("[lobby_peers] port %d is in use; trying %d" % [port, next])
			port = next
			continue
		started = true
	print("[lobby_peers] %s after %d ms: host %s, joiner %s" % [level, Time.get_ticks_msec() - since, host_report,
		join_report])
	return {"host": host_report, "join": join_report, "started": started, "port": port}


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## The last `SESSION_REPORT role=host ... crew=segway:1/segway:2 ...` in a log, as a Dictionary.
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


## BOTH MACHINES DRAWING BOTH PLAYERS, AND BOTH CREW LINES FULL: a report read a tick after the joiner arrived can name
## two clients while the manifest is still one craft, and reading that would be reading a half-built session.
func _joined(host_report: Dictionary, join_report: Dictionary) -> bool:
	return int(host_report.get("clients", 0)) == 2 and int(host_report.get("pilots", 0)) == 2 \
		and int(join_report.get("clients", 0)) == 2 and int(join_report.get("pilots", 0)) == 2 \
		and String(host_report.get("crew", "")).count("/") == 1 \
		and String(join_report.get("crew", "")).count("/") == 1


## EVERY CHILD KILLED, AND WAITED OUT BEFORE THE NEXT PAIR STARTS.
##
## `OS.kill` RETURNS BEFORE WINDOWS HAS ENDED THE PROCESS, and a host that is still shutting down still holds its UDP
## port. This suite runs two pairs of children, one level each, and started the second the instant it had asked the first
## to die -- so the second pair walked the whole port range finding each one busy in turn and gave up:
## "port 47975 is in use; trying 47976 ... tried 47970 to 47978" (2026-09-15, under another lane's load). It had passed
## six runs in a row before that, which is what a race looks like until the machine is busy.
##
## SO THE WAIT IS ITS OWN DEADLINE, and it is not the same thing as the port being busy: a process that will not die is a
## different bug from a port that has not been let go, and a suite that conflated them would report the wrong one. If a
## child outlasts `BURY_SECONDS` this says so and carries on, because the port loop below is still there to cope.
const BURY_SECONDS: float = 5.0


## TWO FUNCTIONS, because teardown cannot wait. `_finish` quits the process and must not be a coroutine, so it asks for
## the kill and goes; only the loop that is about to start ANOTHER pair waits for the ports to come back.
func _kill_the_children() -> void:
	for pid in _children:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_children.clear()


func _bury_the_children() -> void:
	var dying: Array[int] = _children.duplicate()
	_kill_the_children()
	var since: int = Time.get_ticks_msec()
	for pid in dying:
		while pid > 0 and OS.is_process_running(pid) 				and Time.get_ticks_msec() - since < int(BURY_SECONDS * 1000.0):
			await get_tree().create_timer(0.05).timeout
		if pid > 0 and OS.is_process_running(pid):
			print("[lobby_peers] child %d outlasted %.1f s after being killed" % [pid, BURY_SECONDS])


func _finish() -> void:
	_kill_the_children()
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
