extends Node
## Headless: SPOTTING SIZE IS NOBODY ELSE'S -- two real processes over a real socket, the host wearing HIGH, the joiner
## wearing nothing, and the joiner draws every craft, the host's included, at its true size.
##
##   Godot --headless --path cockpit res://tests/spotting_peers.tscn
##
## THE CHILDREN run with `--report=1` and `--spectacles=1` (`FlightLevel._spectacles_line`): five times a second each says
## what it wears, how many craft it draws, how many of them bigger than they are, and the biggest scale. The host adds
## `--spotting=high` and the joiner `--spotting=off`, which `Spectacles.worn` takes for this run over whatever the player's
## file says, and never writes back.
##
## THE CHECKS, on what both machines SAY, once both are flying and each draws the other:
##   * the host draws some far craft bigger -- the setting was really on, so the joiner's 1.000 means something;
##   * and the joiner, wearing none, draws every craft at exactly its true size the whole time, the host's among them.
## The setting is not in any wire format: `Spectacles` lives on the rig, and nothing in `net/` or `autoload/` names it.
##
## PORTS 48240-48249 of this checkout's block (`TestPorts`).
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 48240
const PORTS: int = 10
const PATIENCE_SECONDS: float = 90.0
## HOW LONG BOTH ARE WATCHED once both are flying, seconds.
const WATCH_SECONDS: float = 6.0

var _failures: PackedStringArray = []
var _children: Array[int] = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[spotting_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	var host_log: String = ProjectSettings.globalize_path(TestPorts.log_for("spotting_peers", "host"))
	var join_log: String = ProjectSettings.globalize_path(TestPorts.log_for("spotting_peers", "join"))
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	var started: bool = false
	var since: int = 0
	var met_at: int = -1
	var host_lines: Array[Dictionary] = []
	var join_lines: Array[Dictionary] = []
	while port != 0 and not started:
		for path in [host_log, join_log]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		_children.append(OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only",
			"--fixed-fps", "120", "--log-file", host_log, "--path", project, "--", "--host=%d" % port,
			"--world=%s" % ChartDrawer.DEFAULT, "--report=1", "--spectacles=1", "--spotting=high"]))
		_children.append(OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only",
			"--fixed-fps", "120", "--log-file", join_log, "--path", project, "--", "--join=127.0.0.1:%d" % port,
			"--report=1", "--spectacles=1", "--spotting=off"]))
		since = Time.get_ticks_msec()
		var busy: bool = false
		while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
			var host_said: String = _read(host_log)
			var join_said: String = _read(join_log)
			busy = host_said.contains("BOOT_ERROR=Could not listen")
			if met_at < 0 and _both_flying(host_said) and _both_flying(join_said):
				met_at = Time.get_ticks_msec()
			if busy or (met_at >= 0 and Time.get_ticks_msec() - met_at > int(WATCH_SECONDS * 1000.0)):
				host_lines = _spectacles_after(host_said, _last_report_count_before(host_said))
				join_lines = _spectacles_after(join_said, _last_report_count_before(join_said))
				break
			await get_tree().create_timer(0.1).timeout
		_kill_the_children()
		if busy:
			var next: int = TestPorts.first_free(FIRST_PORT, PORTS, port)
			print("[spotting_peers] port %d is in use; trying %d" % [port, next])
			port = next
			continue
		started = true
	_check("a_port_was_free_to_host_on", started, "on %d" % port if started else TestPorts.busy(FIRST_PORT, PORTS))
	_check("both_machines_were_flying_and_drawing_each_other", met_at >= 0,
		"met after %s ms" % [met_at - since if met_at >= 0 else "never"])
	var host_bigger: int = 0
	var host_biggest: float = 1.0
	for line in host_lines:
		host_bigger = maxi(host_bigger, int(line.get("bigger", "0")))
		host_biggest = maxf(host_biggest, float(line.get("biggest", "1")))
	var join_wears: PackedStringArray = []
	var join_bigger: int = 0
	var join_biggest: float = 1.0
	var join_drawn: int = 0
	for line in join_lines:
		if not join_wears.has(String(line.get("strength", "?"))):
			join_wears.append(String(line.get("strength", "?")))
		join_bigger = maxi(join_bigger, int(line.get("bigger", "0")))
		join_biggest = maxf(join_biggest, float(line.get("biggest", "1")))
		join_drawn = maxi(join_drawn, int(line.get("drawn", "0")))
	print("[spotting_peers] measure: host %d lines, up to %d craft bigger, biggest x%.3f; joiner %d lines wearing %s, %d drawn, %d bigger, biggest x%.3f" % [
		host_lines.size(), host_bigger, host_biggest, join_lines.size(), join_wears, join_drawn, join_bigger,
		join_biggest])
	_check("the_host_wearing_high_draws_far_craft_bigger", host_lines.size() >= 5 and host_bigger > 0
		and host_biggest > 1.5, "%d lines, %d bigger, biggest x%.3f" % [host_lines.size(), host_bigger, host_biggest])
	_check("and_the_joiner_wearing_none_draws_every_craft_its_true_size", join_lines.size() >= 5 and join_drawn >= 2
		and join_wears == PackedStringArray(["OFF"]) and join_bigger == 0 and join_biggest == 1.0,
		"%d lines wearing %s, %d drawn, %d bigger, biggest x%.3f" % [join_lines.size(), join_wears, join_drawn,
			join_bigger, join_biggest])
	_finish()


## WHETHER A LOG'S LATEST REPORT HAS TWO PILOTS, which is both players flying and drawn (`tests/two_peers.gd`).
func _both_flying(said: String) -> bool:
	var at: int = said.rfind("SESSION_REPORT ")
	if at < 0:
		return false
	var line: String = said.substr(at, said.find("\n", at) - at)
	return line.contains(" pilots=2 ")


## HOW MANY SPECTACLES LINES CAME BEFORE BOTH WERE FLYING, so only the lines while they were are read: the index of the
## first SESSION_REPORT that says two pilots.
func _last_report_count_before(said: String) -> int:
	var count: int = 0
	for line in said.split("\n"):
		if line.begins_with("SESSION_REPORT ") and line.contains(" pilots=2 "):
			return count
		if line.begins_with("SPECTACLES "):
			count += 1
	return count


## Every `SPECTACLES ...` line after the first `skip`, as {strength: "HIGH", ...}.
func _spectacles_after(said: String, skip: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: int = 0
	for line in said.split("\n"):
		if not line.begins_with("SPECTACLES "):
			continue
		seen += 1
		if seen <= skip:
			continue
		var row: Dictionary = {}
		for pair in line.substr(11).strip_edges().split(" ", false):
			var kv: PackedStringArray = pair.split("=")
			if kv.size() == 2:
				row[kv[0]] = kv[1]
		out.append(row)
	return out


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


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
