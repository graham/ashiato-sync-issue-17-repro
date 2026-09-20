extends Node
## Real ENet confirmation: a host and two delayed joiners load 200 aircraft through the
## host's real TRAFFIC button. Timings are descriptive because three rendering processes
## contend for this desk; the in-process bulk_load owns the server tick verdict.

const CROWD := preload("res://tests/crowd.gd")
## 47992 of this checkout's block (`TestPorts`), or the next free one after it, asked silently before any child starts:
## a fixed 47992 was the same socket in every lane, so two lanes' joiners met one lane's host.
const FIRST_PORT := 47992
const PORTS := 2
const PATIENCE_MS := 90000
const WINDOW_MS := 8000
const SOCKET_SETTLE_MS := 3000

var _children: Array[int] = []
var _failed := false
var _said: Array[String] = []


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL extension_missing")
		get_tree().quit(1)
		return
	# The same run supplies the 15% reference rather than freezing yesterday's bandwidth.
	var harness: Node = CROWD.new()
	var reference: Dictionary = harness.run_bulk_cell(200, 2, 8, 600, 1200)
	harness.free()
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	if port == 0:
		print("RESULT=FAIL port_busy %s" % TestPorts.busy(FIRST_PORT, PORTS))
		get_tree().quit(1)
		return
	var project := ProjectSettings.globalize_path("res://")
	var logs := {
		"host": ProjectSettings.globalize_path(TestPorts.log_for("bulk_peers", "host")),
		"a": ProjectSettings.globalize_path(TestPorts.log_for("bulk_peers", "a")),
		"b": ProjectSettings.globalize_path(TestPorts.log_for("bulk_peers", "b")),
	}
	for path in logs.values():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	# Real latency is wall-clock latency. Accelerating these child simulations with
	# --fixed-fps would turn 50 ms into hundreds of simulated frames and test a fiction.
	var common := ["--headless", "--xr-mode", "off", "--desktop-only", "--path", project]
	_children.append(OS.create_process(OS.get_executable_path(), common + ["--log-file", logs.host, "--",
		"--host=%d" % port, "--world=%s" % ChartDrawer.DEFAULT, "--report=1", "--stack=200"] + _passed_on()))
	await _wall_msec(300)
	_children.append(OS.create_process(OS.get_executable_path(), common + ["--log-file", logs.a, "--",
		"--join=127.0.0.1:%d" % port, "--report=1", "--latency=50", "--stack=0"]))
	_children.append(OS.create_process(OS.get_executable_path(), common + ["--log-file", logs.b, "--",
		"--join=127.0.0.1:%d" % port, "--report=1", "--latency=50"]))
	var began := Time.get_ticks_msec()
	var host: Dictionary = {}
	var a: Dictionary = {}
	var b: Dictionary = {}
	while Time.get_ticks_msec() - began < PATIENCE_MS:
		host = _latest(logs.host)
		a = _latest(logs.a)
		b = _latest(logs.b)
		if int(host.get("stack", 0)) == 200 and int(a.get("vehicles", 0)) == int(host.get("vehicles", -1)) \
				and int(b.get("vehicles", 0)) == int(host.get("vehicles", -1)) \
				and int(host.get("clients", 0)) == 3:
			break
		# The suite runner advances this parent with --fixed-fps. Yield real wall time as
		# well as a frame, or the observer steals a core from the three processes measured.
		OS.delay_msec(10)
		await get_tree().process_frame
	_check("the_host_page_builds_200_for_both_joiners", int(host.get("stack", 0)) == 200 \
		and int(a.get("vehicles", 0)) == int(host.get("vehicles", -1)) \
		and int(b.get("vehicles", 0)) == int(host.get("vehicles", -1)),
		"host=%s a=%s b=%s" % [host, a, b])
	_check("both_joiners_use_the_configured_real_link", int(a.get("link_ms", -1)) == 50 \
		and int(b.get("link_ms", -1)) == 50, "a=%s b=%s" % [a.get("link_ms"), b.get("link_ms")])
	var refused := FileAccess.get_file_as_string(logs.a) if FileAccess.file_exists(logs.a) else ""
	_check("a_joiners_stack_button_is_refused_in_words", refused.contains("PRESSED_STACK 0") \
		and refused.contains("Only the host"), "real TRAFFIC press")
	if not _failed:
		await _wall_msec(SOCKET_SETTLE_MS)
		var first_a := _reports(logs.a).size()
		var first_b := _reports(logs.b).size()
		await _wall_msec(WINDOW_MS)
		_measure_joiner("a", _reports(logs.a).slice(first_a), reference)
		_measure_joiner("b", _reports(logs.b).slice(first_b), reference)
	_kill_children()
	if not _passed_on().is_empty() and FileAccess.file_exists(logs.host):
		for line in FileAccess.get_file_as_string(logs.host).split("\n"):
			if line.contains("refusal bound"):
				print("[bulk_peers] host: %s" % line.strip_edges())
	print("RESULT=%s%s" % ["FAIL " if _failed else "PASS", ", ".join(_said)])
	get_tree().quit(1 if _failed else 0)


func _measure_joiner(who: String, rows: Array[Dictionary], reference: Dictionary) -> void:
	_check("%s_reports_a_measurement_window" % who, rows.size() >= 10, "%d reports" % rows.size())
	if rows.size() < 2:
		return
	var seconds := float(WINDOW_MS) / 1000.0
	var carrier_bytes := int(rows[-1].get("rx_bytes", 0)) - int(rows[0].get("rx_bytes", 0))
	var carrier_packets := int(rows[-1].get("rx_packets", 0)) - int(rows[0].get("rx_packets", 0))
	var carrier_largest := 0
	var socket_bytes := 0
	var socket_packets := 0
	var first_buffers: Array[int] = []
	var last_buffers: Array[int] = []
	var third := maxi(1, rows.size() / 3)
	for i in range(rows.size()):
		carrier_largest = maxi(carrier_largest, int(rows[i].get("rx_largest", 0)))
		socket_bytes += int(rows[i].get("enet_in_bytes", 0))
		socket_packets += int(rows[i].get("enet_in_packets", 0))
		if i < third:
			first_buffers.append(int(rows[i].get("buffer", -1)))
		if i >= rows.size() - third:
			last_buffers.append(int(rows[i].get("buffer", -1)))
	first_buffers.sort()
	last_buffers.sort()
	var first_buffer := first_buffers[first_buffers.size() / 2]
	var last_buffer := last_buffers[last_buffers.size() / 2]
	var kb_s := float(carrier_bytes) / seconds / 1024.0
	var expected := float(reference["down_kB_s_per_client"])
	var socket_mean := float(socket_bytes) / float(maxi(1, socket_packets))
	var rollback_rate := float(int(rows[-1].get("rollbacks", 0)) - int(rows[0].get("rollbacks", 0))) / seconds
	print("REAL_BULK joiner=%s vehicles=%s carrier_kB_s=%.1f carrier_packets_s=%.1f carrier_largest_B=%d socket_bytes_packet=%.1f socket_packets_s=%.1f buffer=%d->%d rollbacks_s=%.2f latency_frames=%s" % [
		who, rows[-1].get("vehicles", "?"), kb_s, float(carrier_packets) / seconds,
		carrier_largest, socket_mean, float(socket_packets) / seconds, first_buffer, last_buffer,
		rollback_rate, rows[-1].get("latency_frames", "?")])
	_check("%s_sees_every_stack_aircraft" % who, int(rows[-1].get("vehicles", 0)) >= 203,
		"%s vehicles" % rows[-1].get("vehicles", "?"))
	_check("%s_carrier_stays_below_sync_mtu" % who, carrier_largest <= 1200,
		"largest %d B; ENet socket mean %.1f B over %d packets" % [carrier_largest, socket_mean, socket_packets])
	_check("%s_matches_the_in_process_bandwidth" % who,
		kb_s >= expected * 0.85 and kb_s <= expected * 1.15,
		"real %.1f kB/s, in-process %.1f kB/s" % [kb_s, expected])
	_check("%s_buffer_does_not_climb" % who, last_buffer - first_buffer <= 1,
		"%d -> %d" % [first_buffer, last_buffer])


func _reports(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return out
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.begins_with("SESSION_REPORT "):
			continue
		var row: Dictionary = {}
		for pair in line.substr(15).strip_edges().split(" ", false):
			var kv := pair.split("=")
			if kv.size() == 2:
				row[kv[0]] = kv[1]
		out.append(row)
	return out


func _latest(path: String) -> Dictionary:
	var rows := _reports(path)
	return rows[-1] if not rows.is_empty() else {}


func _wall_msec(msec: int) -> void:
	var until := Time.get_ticks_msec() + msec
	while Time.get_ticks_msec() < until:
		OS.delay_msec(10)
		await get_tree().process_frame


func _check(name: String, passed: bool, detail: String) -> void:
	print("[bulk_peers] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
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


## THIS RUN'S OWN `--refusals=N`, handed on to the host child, for an A/B of the host's refusal bound. Nothing otherwise.
func _passed_on() -> Array:
	var passed: Array = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--refusals="):
			passed.append(argument)
	return passed
