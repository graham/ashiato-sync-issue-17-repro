extends Node
## Headless, two real processes on the loopback: a joiner learns the host's level before either simulates the other,
## and the host holds the joiner back until it has built it; a joiner with another copy of the level, or without it, is
## refused in words and never simulated.
##
##   Godot --headless --path cockpit res://tests/level_join.tscn
##
## Asked for on 2026-09-15: "a joiner learns the host's level before its simulation starts, loads it, and only then
## begins receiving and predicting ... The server never simulates a joiner until the joiner's level is loaded." Each
## pair is a host (`--host=PORT --report=1`) and a joiner (`--join=127.0.0.1:PORT --report=1`), started the way
## tests/two_peers.gd starts them, reading the same `SESSION_REPORT` lines out of their log files, plus what `Net` prints
## with `--report=1`: NET_LOADED on the joiner and NET_ADMITTED on the host, each with the machine's Unix time.
##
## THE JOINER BUILDS SLOWLY ON PURPOSE (`--load-slowly=2`): the island stands in one frame, and a joiner whose level was
## built before its first tick would show a gate that holds nothing. Two seconds is about half the alpine ground's build.
##
## THE OTHER COPY is `tests/level_fixtures_other/island`, the island with its pod put elsewhere; the level nobody else
## has is a fixture's, hosted with `--levels-from=res://tests/level_fixtures --world=good_b`.
##
## PORTS 47953-47959 of this checkout's block (`TestPorts`). Each pair takes the first above the last pair's that nothing
## holds, asked silently before a child starts; a host that still cannot listen moves to the next.
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 47953
const LAST_PORT: int = 47959
const PATIENCE_SECONDS: float = 60.0
## How long the joiner waits before saying its level is built.
const SLOW_SECONDS: float = 2.0
## After a refusal, how many reports the host must have printed before it is judged never to have let the joiner in: a
## second of them. A fixed two seconds after the joiner's BOOT_ERROR was once not enough for a busy host to print ANY
## (2026-09-15, after smoke under load: the other copy refused in 2.4 s, then 0 host reports), and a check over no
## reports refuses to pass rather than pass on nothing.
const WATCH_REPORTS: int = 5
const WATCH_AFTER_SECONDS: float = 0.0

var _failures: PackedStringArray = []
var _children: Array[int] = []
var _port: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[level_join] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	await _a_joiner_on_the_same_level_is_held_back_while_it_builds_and_then_flies()
	await _a_joiner_with_another_copy_of_the_level_is_refused()
	await _a_joiner_without_the_host_s_level_is_refused()
	_finish()


## ---- 1: the same level ---------------------------------------------------------------------------------------------

func _a_joiner_on_the_same_level_is_held_back_while_it_builds_and_then_flies() -> void:
	var pair: Dictionary = await _pair("same", ["--world=island"], ["--load-slowly=%s" % SLOW_SECONDS],
		_both_flying, 0.0)
	var host_reports: Array[Dictionary] = _reports(pair["host"])
	var join_reports: Array[Dictionary] = _reports(pair["join"])
	var host_last: Dictionary = host_reports.back() if not host_reports.is_empty() else {}
	var join_last: Dictionary = join_reports.back() if not join_reports.is_empty() else {}
	_check("both_machines_name_two_clients_and_draw_two_pilots",
		_flying_together(host_reports) and _flying_together(join_reports),
		"host %s, joiner %s" % [host_last, join_last])
	_check("and_both_are_on_the_host_s_level", host_last.get("level") == "island" and join_last.get("level") == "island",
		"host %s, joiner %s" % [host_last.get("level"), join_last.get("level")])
	var loaded: Dictionary = _line_fields(pair["join"], "NET_LOADED")
	var admitted: Dictionary = _line_fields(pair["host"], "NET_ADMITTED")
	_check("the_joiner_said_its_level_was_built_and_the_host_let_it_in", not loaded.is_empty() and not admitted.is_empty(),
		"loaded %s, admitted %s" % [loaded, admitted])
	_check("and_not_before_it_was_built",
		not loaded.is_empty() and not admitted.is_empty() and float(admitted.get("at", 0)) >= float(loaded.get("at", INF)),
		"built at %s, let in at %s" % [loaded.get("at"), admitted.get("at")])
	_check("while_it_built_the_host_held_its_simulation_back", int(admitted.get("held", 0)) > 0,
		"%s packets held" % admitted.get("held"))
	# NOTHING OF THE JOINER IN THE HOST'S SIMULATION BEFORE IT WAS LET IN: every report the host printed before that line.
	var before: Array[Dictionary] = _reports(String(pair["host"]).get_slice("NET_ADMITTED", 0))
	var early: Array = before.filter(_names_anyone_else)
	_check("and_named_no_client_and_drew_no_pilot_for_it_until_then", not before.is_empty() and early.is_empty(),
		"%d reports before, %d with more than the host: %s" % [before.size(), early.size(), early.slice(0, 2)])


## ---- 2: another copy ---------------------------------------------------------------------------------------------

func _a_joiner_with_another_copy_of_the_level_is_refused() -> void:
	var pair: Dictionary = await _pair("other_copy", ["--world=island"],
		["--levels-from=res://tests/level_fixtures_other"], _refused_at_boot, WATCH_AFTER_SECONDS)
	_refused(pair, "The host's copy of The island is not the same as yours.")


## ---- 3: a level the joiner does not have --------------------------------------------------------------------------

func _a_joiner_without_the_host_s_level_is_refused() -> void:
	var pair: Dictionary = await _pair("no_such_level", ["--levels-from=res://tests/level_fixtures", "--world=good_b"],
		[], _refused_at_boot, WATCH_AFTER_SECONDS)
	_refused(pair, "The host is flying Good B, a level this game does not have.")


## WHAT `_pair` WAITS ON, and what a report is asked, as functions: an inline lambda followed by another argument on its
## line is a parse error, and a parse error hangs a suite to its deadline (2026-09-15, this file's first run).
func _both_flying(host: String, join: String) -> bool:
	return _flying_together(_reports(host)) and _flying_together(_reports(join))


func _refused_at_boot(host: String, join: String) -> bool:
	return join.contains("BOOT_ERROR=") and _reports(host).size() >= WATCH_REPORTS


func _names_anyone_else(report: Dictionary) -> bool:
	return int(report.get("clients", 0)) > 1 or int(report.get("pilots", 0)) > 1


func _names_another_client(report: Dictionary) -> bool:
	return int(report.get("clients", 0)) > 1


func _refused(pair: Dictionary, words: String) -> void:
	var tag: String = pair["tag"]
	var said: String = ""
	for line in String(pair["join"]).split("\n"):
		if line.begins_with("BOOT_ERROR="):
			said = line.substr("BOOT_ERROR=".length()).strip_edges()
	_check("%s_the_joiner_is_refused_in_words" % tag, said == words, "'%s'" % said)
	var host_reports: Array[Dictionary] = _reports(pair["host"])
	var had: Array = host_reports.filter(_names_another_client)
	_check("%s_and_the_host_never_let_it_in_or_simulated_it" % tag,
		not String(pair["host"]).contains("NET_ADMITTED") and not host_reports.is_empty() and had.is_empty(),
		"%d host reports, %d naming another client" % [host_reports.size(), had.size()])


## ---- the machinery -------------------------------------------------------------------------------------------

## A HOST AND A JOINER, until `done` says so or the patience runs out, and then `watch_after` seconds more. Returns both
## logs as text, and the tag.
func _pair(tag: String, host_extra: Array, join_extra: Array, done: Callable, watch_after: float) -> Dictionary:
	var project: String = ProjectSettings.globalize_path("res://")
	var host_log: String = ProjectSettings.globalize_path(TestPorts.log_for("level_join", "%s_host" % tag))
	var join_log: String = ProjectSettings.globalize_path(TestPorts.log_for("level_join", "%s_join" % tag))
	_port = TestPorts.first_free(FIRST_PORT, LAST_PORT - FIRST_PORT + 1, _port)
	while _port != 0:
		for path in [host_log, join_log]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		var host_args: Array = ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--log-file", host_log, "--path", project, "--",
			"--host=%d" % _port, "--report=1"] + host_extra
		var join_args: Array = ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--log-file", join_log, "--path", project, "--",
			"--join=127.0.0.1:%d" % _port, "--report=1"] + join_extra
		_children.append(OS.create_process(OS.get_executable_path(), host_args))
		_children.append(OS.create_process(OS.get_executable_path(), join_args))
		var since: int = Time.get_ticks_msec()
		var busy: bool = false
		while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
			var host_said: String = _read(host_log)
			busy = host_said.contains("BOOT_ERROR=Could not listen")
			if busy or done.call(host_said, _read(join_log)):
				break
			await get_tree().create_timer(0.1).timeout
		if not busy and watch_after > 0.0:
			await get_tree().create_timer(watch_after).timeout
		var out: Dictionary = {"tag": tag, "host": _read(host_log), "join": _read(join_log),
			"seconds": float(Time.get_ticks_msec() - since) / 1000.0}
		_kill_the_children()
		if busy:
			print("[level_join] port %d is in use; trying the next" % _port)
			_port = TestPorts.first_free(FIRST_PORT, LAST_PORT - FIRST_PORT + 1, _port)
			continue
		print("[level_join] %s after %.1f s on port %d" % [tag, out["seconds"], _port])
		return out
	_check("%s_a_port_was_free" % tag, false, TestPorts.busy(FIRST_PORT, LAST_PORT - FIRST_PORT + 1))
	return {"tag": tag, "host": "", "join": "", "seconds": 0.0}


func _flying_together(reports: Array[Dictionary]) -> bool:
	return not reports.is_empty() and int(reports.back().get("clients", 0)) == 2 \
		and int(reports.back().get("pilots", 0)) == 2


## Every `SESSION_REPORT key=value ...` line in a log, in order, as Dictionaries.
func _reports(said: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line in said.split("\n"):
		if line.begins_with("SESSION_REPORT "):
			out.append(_fields(line))
	return out


## The first line starting with `word` in a log, as its key=value fields, or {}.
func _line_fields(said: String, word: String) -> Dictionary:
	for line in said.split("\n"):
		if line.begins_with(word + " "):
			return _fields(line)
	return {}


func _fields(line: String) -> Dictionary:
	var out: Dictionary = {}
	for token in line.strip_edges().split(" "):
		if token.contains("="):
			out[token.get_slice("=", 0)] = token.substr(token.find("=") + 1)
	return out


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _kill_the_children() -> void:
	for pid in _children:
		if OS.is_process_running(pid):
			OS.kill(pid)
	_children.clear()


func _finish() -> void:
	_kill_the_children()
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
