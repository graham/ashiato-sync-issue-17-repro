extends Node
## REAL ENET, one host and two joiners. One joiner has a clean loopback; the other delays
## both socket edges by 100 ms. Sync's measured one-way latency must therefore rise by
## about twelve 120 Hz frames, and both join handshakes must still finish.

## 47990 of this checkout's block (`TestPorts`), asked silently at load whether anything holds it: a fixed
## number was the same socket in every lane. Held, and the suite says PORT BUSY at once rather than timing out.
static var PORT: int = TestPorts.first_free(47990, 1)
const PATIENCE_MS := 60000
const SETTLE_MS := 6000

var _children: Array[int] = []
var _failed := false
var _said: Array[String] = []


func _ready() -> void:
	if PORT == 0:
		print("RESULT=FAIL port_busy %s" % TestPorts.busy(47990, 1))
		get_tree().quit(1)
		return
	var project := ProjectSettings.globalize_path("res://")
	var host_log := ProjectSettings.globalize_path(TestPorts.log_for("latency", "host"))
	var clean_log := ProjectSettings.globalize_path(TestPorts.log_for("latency", "clean"))
	var slow_log := ProjectSettings.globalize_path(TestPorts.log_for("latency", "slow"))
	for path in [host_log, clean_log, slow_log]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var common := ["--headless", "--xr-mode", "off", "--desktop-only", "--path", project]
	_children.append(OS.create_process(OS.get_executable_path(), common + ["--log-file", host_log, "--",
		"--host=%d" % PORT, "--world=%s" % ChartDrawer.DEFAULT, "--report=1"]))
	await _wall_msec(250)
	_children.append(OS.create_process(OS.get_executable_path(), common + ["--log-file", clean_log, "--",
		"--join=127.0.0.1:%d" % PORT, "--report=1", "--latency=0"]))
	_children.append(OS.create_process(OS.get_executable_path(), common + ["--log-file", slow_log, "--",
		"--join=127.0.0.1:%d" % PORT, "--report=1", "--latency=100"]))
	var began := Time.get_ticks_msec()
	var host: Dictionary = {}
	var clean: Dictionary = {}
	var slow: Dictionary = {}
	while Time.get_ticks_msec() - began < PATIENCE_MS:
		host = _latest(host_log)
		clean = _latest(clean_log)
		slow = _latest(slow_log)
		if int(host.get("clients", 0)) == 3 and int(clean.get("clients", 0)) == 3 \
				and int(slow.get("clients", 0)) == 3:
			break
		await get_tree().process_frame
	_check("both_joiners_complete_the_level_hello", int(host.get("clients", 0)) == 3 \
		and int(clean.get("clients", 0)) == 3 and int(slow.get("clients", 0)) == 3,
		"host=%s clean=%s delayed=%s" % [host, clean, slow])
	if not _failed:
		await _wall_msec(SETTLE_MS)
		clean = _latest(clean_log)
		slow = _latest(slow_log)
		var clean_frames := int(clean.get("latency_frames", -1))
		var slow_frames := int(slow.get("latency_frames", -1))
		_check("the_command_line_sets_the_link_delay", int(slow.get("link_ms", -1)) == 100 \
			and int(clean.get("link_ms", -1)) == 0, "clean=%s delayed=%s" % [clean, slow])
		_check("both_socket_edges_contribute_to_the_measured_latency", slow_frames >= clean_frames + 8 \
			and slow_frames <= clean_frames + 20,
			"clean %d frames, 100 ms each way %d frames" % [clean_frames, slow_frames])
	_kill_children()
	print("RESULT=%s%s" % ["FAIL " if _failed else "PASS", ", ".join(_said)])
	get_tree().quit(1 if _failed else 0)


func _latest(path: String) -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(path):
		return out
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.begins_with("SESSION_REPORT "):
			continue
		out.clear()
		for pair in line.substr(15).strip_edges().split(" ", false):
			var kv := pair.split("=")
			if kv.size() == 2:
				out[kv[0]] = kv[1]
	return out


func _wall_msec(msec: int) -> void:
	var until := Time.get_ticks_msec() + msec
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _check(name: String, passed: bool, detail: String) -> void:
	print("[latency] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
	if not passed:
		_failed = true
		_said.append(name)


func _kill_children() -> void:
	for pid in _children:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_children.clear()


func _exit_tree() -> void:
	_kill_children()
