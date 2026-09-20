extends Node
## Headless: two real processes, a host and a joiner over a real socket on the loopback, each flying a craft of its own --
## and then the joiner boards the host's craft through its own CREW page, and both machines list the same crew.
##
##   Godot --headless --path cockpit res://tests/crew_peers.tscn
##
## THE SIBLING OF tests/two_peers.gd, which proves a second player arrives. This one proves the thing the user asked to
## test with other people: "separate planes as well as both in the same plane". Both children run with `--report=1`, and
## the report's `crew` word is the CREW page's own manifest on that machine (`Sky._crew_line`): every crewed craft, its
## seats, who is in each. The joiner also runs with `--board=3`, which three seconds after its page first lists the
## host's craft presses that craft's first JOIN on its own clipboard (`Sky._board_when_asked`).
##
## The checks are on what both machines SAY, from their own logs:
##   APART: each lists two craft, one player in each, and the two lists are the same;
##   the joiner pressed JOIN on its page;
##   TOGETHER: each lists one craft with both players in it, and the two lists are the same;
##   and the joiner's machine was told "joined" by the host.
##
## THE HOST DRAWING THE JOINER is not asked here: two_peers asks it, and on main it fails about one run in three
## (cockpit-joinfix, 2026-09-15). A host that has no pilot for the joiner lists no craft for it either -- the manifest's
## craft come off the pilots -- so that fault shows here as APART never agreeing, and the detail says which machine.
##
##
## THE HOST NAMES ITS LEVEL. Since 2026-09-15 a host that chose nothing starts in the LOBBY (`Net.suit_the_session`, the
## user's rule), and a briefing room is a segway each with one seat in it. This suite is about boarding another player's craft, so it
## hosts the island in as many words rather than following a default that can move under it.##
## PORTS 47990-47999 of this checkout's block (`TestPorts`); the first nothing holds is asked silently before a child
## starts, and a host that still cannot listen says BOOT_ERROR=Could not listen and the next free one is tried. The children write --log-file, for the reason two_peers gives.
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 47990
const PORTS: int = 10
## Seconds for both worlds to build, meet, stand apart and board, before the children are killed.
const PATIENCE_SECONDS: float = 90.0
## How long after first listing the host's craft the joiner presses JOIN. Long enough for several reports apart.
const BOARD_AFTER_SECONDS: int = 3

var _failures: PackedStringArray = []
var _children: Array[int] = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[crew_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	var host_log: String = ProjectSettings.globalize_path(TestPorts.log_for("crew_peers", "host"))
	var join_log: String = ProjectSettings.globalize_path(TestPorts.log_for("crew_peers", "join"))
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	var started: bool = false
	var since: int = 0
	var apart: Dictionary = {}
	var together: Dictionary = {}
	var host_report: Dictionary = {}
	var join_report: Dictionary = {}
	var boarded: bool = false
	while port != 0 and not started:
		for path in [host_log, join_log]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		_children.append(OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--log-file",
			host_log, "--path", project, "--", "--host=%d" % port, "--world=%s" % ChartDrawer.DEFAULT,
			"--report=1"]))
		_children.append(OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--log-file",
			join_log, "--path", project, "--", "--join=127.0.0.1:%d" % port, "--report=1",
			"--board=%d" % BOARD_AFTER_SECONDS]))
		since = Time.get_ticks_msec()
		var busy: bool = false
		while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
			var host_said: String = _read(host_log)
			var join_said: String = _read(join_log)
			busy = host_said.contains("BOOT_ERROR=Could not listen")
			host_report = _latest_report(host_said)
			join_report = _latest_report(join_said)
			boarded = join_said.contains("BOARDING ")
			var host_crew: String = String(host_report.get("crew", ""))
			var join_crew: String = String(join_report.get("crew", ""))
			if apart.is_empty() and host_crew == join_crew and _crews(host_crew) == [1, 1]:
				apart = {"crew": host_crew, "ms": Time.get_ticks_msec() - since}
			if together.is_empty() and host_crew == join_crew and _crews(host_crew) == [2] \
					and join_report.get("answer") == "joined":
				together = {"crew": host_crew, "ms": Time.get_ticks_msec() - since}
			if busy or not together.is_empty():
				break
			await get_tree().create_timer(0.1).timeout
		_kill_the_children()
		if busy:
			var next: int = TestPorts.first_free(FIRST_PORT, PORTS, port)
			print("[crew_peers] port %d is in use; trying %d" % [port, next])
			port = next
			continue
		started = true
	print("[crew_peers] after %d ms: host %s, joiner %s" % [Time.get_ticks_msec() - since, host_report, join_report])
	print("[crew_peers] measure: apart agreed at %s ms, together agreed at %s ms" % [apart.get("ms", "never"),
		together.get("ms", "never")])
	_check("a_port_was_free_to_host_on", started, "on %d" % port if started else TestPorts.busy(FIRST_PORT, PORTS))
	_check("apart_both_machines_list_two_craft_with_one_player_each_and_agree", not apart.is_empty(),
		"agreed on %s; last host crew %s, joiner crew %s" % [apart.get("crew", "nothing"), host_report.get("crew"),
			join_report.get("crew")])
	_check("the_joiner_pressed_join_on_its_crew_page", boarded, "BOARDING in the joiner's log: %s" % boarded)
	_check("together_both_machines_list_one_craft_with_both_aboard_and_agree", not together.is_empty(),
		"agreed on %s; last host crew %s, joiner crew %s" % [together.get("crew", "nothing"), host_report.get("crew"),
			join_report.get("crew")])
	_check("and_the_host_told_the_joiner_it_joined", join_report.get("answer") == "joined",
		"joiner's answer %s" % [join_report.get("answer")])
	_finish()


## How many players are in each crewed craft of a `crew` word, sorted: "pod:1.-.-.-/pod:2.-.-.-" is [1, 1].
static func _crews(crew: String) -> Array:
	var out: Array = []
	if crew == "" or crew == "none":
		return out
	for row in crew.split("/", false):
		var aboard: int = 0
		for seat in row.get_slice(":", 1).split(".", false):
			aboard += 0 if seat == "-" else 1
		out.append(aboard)
	out.sort()
	return out


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## The last `SESSION_REPORT ...` in a log, as {role: "host", ...}.
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
