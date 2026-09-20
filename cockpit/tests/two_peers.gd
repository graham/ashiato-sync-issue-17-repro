extends Node
## Headless: does a second PLAYER arrive -- two real processes, one hosting and one joining by command line, over a
## real socket on the loopback -- and does each see the other flying?
##
##   Godot --headless --path cockpit res://tests/two_peers.tscn
##
## THE GAP THIS CLOSES. tests/session.gd proves the socket the desk opens completes a handshake with a raw ENet guest,
## and says in its own comment that only two processes with two `Sim`s can prove a PLAYER arrives -- and that there
## was no boot flag to start one. `LaunchOrder` is that flag. So this starts two children: a host (`--host=PORT`) and a
## joiner (`--join=127.0.0.1:PORT`), both headless, both with `--report=1`, which has the world print a
## `SESSION_REPORT` line five times a second. A socket connecting is not enough (team-lead, 2026-09-14); the checks
## are on what only a joined player makes:
##   the HOST names two machines' sync clients, and the host's world draws the joiner's pilot;
##   the JOINER is a client in an ENet session, names two machines' sync clients as well, and draws the host's pilot
##   beside its own.
##
## THE JOINER NAMING THE HOST was false when this suite was written: `Sim` announced each machine's client id once, as
## it arrived, so the host's went to an empty room and the joiner reported clients=1 (2026-09-14, on 527935b).
## cockpit-crewsync replaced that announcement with `Sim.client_of_peer`, read off the pilots every machine receives,
## and the joiner's check was added with it.
##
## THE CHILDREN WRITE TO LOG FILES, and this reads the files. Measured on 4.7.2 (2026-09-14): `OS.execute_with_pipe`
## reads a running child's stdout without blocking, but once the child has exited, asking the pipe how much is waiting
## prints `ERROR: Condition "!PeekNamedPipe(...)"` -- and the runner fails a suite that prints an ERROR line, so a child
## quitting on BOOT_ERROR would race it. A child started with `--log-file` had each printed line in the file within the
## 50 ms the reader polled at, with no error at all.
##
##
## THE HOST NAMES ITS LEVEL. Since 2026-09-15 a host that chose nothing starts in the LOBBY (`Net.suit_the_session`, the
## user's rule), and a briefing room is a segway each with one seat in it. This suite is about a second PLAYER arriving in the game's own world, so it
## hosts the island in as many words rather than following a default that can move under it.##
## THIS CHECKOUT'S PORTS (`TestPorts`), the first free one asked silently before a child starts, from these:
## PORTS 47980-47989, which no other suite uses (session 7788 and 47913, steam_join 47961-47963, code_pad 47964). A
## host that cannot listen says BOOT_ERROR=Could not listen, and the next port is tried.
##
## A DEADLINE KILLS BOTH CHILDREN, by the pid `OS.create_process` returned, which is the engine itself and not the
## console launcher (measured: `OS.get_executable_path()` is `Godot_v4.7.2-stable_win64.exe`). The runner's own deadline
## kills anything with this worktree's path on its command line.
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 47980
const PORTS: int = 10
## Seconds for both worlds to build and the joiner to be seen, before the children are killed.
const PATIENCE_SECONDS: float = 60.0

var _failures: PackedStringArray = []
var _children: Array[int] = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[two_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	var host_log: String = ProjectSettings.globalize_path(TestPorts.log_for("two_peers", "host"))
	var join_log: String = ProjectSettings.globalize_path(TestPorts.log_for("two_peers", "join"))
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
			host_log, "--path", project, "--", "--host=%d" % port, "--world=%s" % ChartDrawer.DEFAULT,
			"--report=1"]))
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
		_kill_the_children()
		if busy:
			var next: int = TestPorts.first_free(FIRST_PORT, PORTS, port)
			print("[two_peers] port %d is in use; trying %d" % [port, next])
			port = next
			continue
		started = true
	print("[two_peers] after %d ms: host %s, joiner %s" % [Time.get_ticks_msec() - since, host_report, join_report])
	_check("a_port_was_free_to_host_on", started, "on %d" % port if started else TestPorts.busy(FIRST_PORT, PORTS))
	_check("the_host_counts_two_machines_in_its_simulation", int(host_report.get("clients", 0)) == 2,
		"host said %s" % [host_report])
	_check("and_draws_the_joiner_flying", int(host_report.get("pilots", 0)) == 2, "host said %s" % [host_report])
	_check("the_joiner_is_a_client_in_an_enet_session", host_report.get("role") == "host"
		and join_report.get("role") == "client" and join_report.get("transport") == "enet",
		"host %s, joiner %s" % [host_report, join_report])
	_check("and_names_the_hosts_sync_client_as_well_as_its_own", int(join_report.get("clients", 0)) == 2,
		"joiner said %s" % [join_report])
	_check("and_draws_the_host_flying_beside_itself", int(join_report.get("pilots", 0)) == 2,
		"joiner said %s" % [join_report])
	_finish()


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## The last `SESSION_REPORT role=host transport=enet clients=2 pilots=2` in a log, as {role: "host", ...}.
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


func _joined(host_report: Dictionary, join_report: Dictionary) -> bool:
	return int(host_report.get("clients", 0)) == 2 and int(host_report.get("pilots", 0)) == 2 \
		and int(join_report.get("clients", 0)) == 2 and int(join_report.get("pilots", 0)) == 2


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
