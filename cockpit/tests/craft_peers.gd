extends Node
## Real ENet proof for CRAFT requests. Every process is explicitly desktop-only.
## One island pair takes an existing PLANE; another pair asks for one-seat SEGWAYs that
## do not exist and receives two separately issued craft; a lobby pair asks for a PLANE
## and is refused in words because rooms register no issue locations.

const FIRST_PORT := 48120
const LAST_PORT := 48129
const PATIENCE_MSEC := 60000
const BURY_MSEC := 5000

var failures: PackedStringArray = []
var children: Array[int] = []
## THIS CHECKOUT'S PORTS (`TestPorts`): the first that nothing holds, asked silently, and each pair after takes the next
## free one above it. 0 once there are none.
var port: int = TestPorts.first_free(FIRST_PORT, LAST_PORT - FIRST_PORT + 1)


func check(label: String, ok: bool, detail: String) -> void:
	print("[craft_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: failures.append(label)


func _ready() -> void:
	# The integrated 200-aircraft load machinery makes the first island replication burst
	# substantially larger. Wait until that burst has settled before pressing the page;
	# this test is about the CRAFT path, not whether a one-second boot press survives it.
	var spare := await pair("island", "", "plane:3", func(h: Dictionary, j: Dictionary) -> bool:
		return String(h.get("crew", "")) == String(j.get("crew", "")) and String(j.get("crew", "")).contains("plane:"))
	check("a_joiner_takes_an_existing_free_plane", bool(spare.get("done", false)), "%s" % [spare])

	var added := await pair("island", "", "plane:2", func(_h: Dictionary, j: Dictionary) -> bool:
		return int(j.get("vehicles", 0)) >= 80 and String(j.get("crew", "")).contains("plane:"), "plane:1")
	check("traffic_add_still_makes_a_free_craft_the_walk_can_reach", bool(added.get("done", false)), "%s" % [added])

	var issued := await pair("island", "segway:1", "segway:1", func(h: Dictionary, j: Dictionary) -> bool:
		var crew := String(h.get("crew", ""))
		return crew == String(j.get("crew", "")) and _two_one_seat(crew, "segway"))
	check("two_players_receive_two_separately_issued_segways", bool(issued.get("done", false)), "%s" % [issued])

	var room := await pair("lobby", "", "plane:1", func(h: Dictionary, j: Dictionary) -> bool:
		return (String(j.get("answer", "")) == "kind_no_issue_place"
			and String(j.get("craft_answer", "")).contains("no_clear_place_to_issue_a_PLANE")))
	check("a_room_refuses_in_words_without_spawning", bool(room.get("done", false)), "%s" % [room])
	_finish()


func pair(level: String, host_craft: String, join_craft: String, done_when: Callable,
		host_add: String = "") -> Dictionary:
	var project := ProjectSettings.globalize_path("res://")
	while port != 0:
		var host_log := ProjectSettings.globalize_path(TestPorts.log_for("craft_peers", "%d_host" % port))
		var join_log := ProjectSettings.globalize_path(TestPorts.log_for("craft_peers", "%d_join" % port))
		for path in [host_log, join_log]:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		var common := ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--path", project]
		var host_args: Array = common + ["--log-file", host_log, "--", "--host=%d" % port,
			"--world=%s" % level, "--report=1"]
		var join_args: Array = common + ["--log-file", join_log, "--", "--join=127.0.0.1:%d" % port,
			"--report=1"]
		if host_craft != "": host_args.append("--craft=%s" % host_craft)
		if join_craft != "": join_args.append("--craft=%s" % join_craft)
		if host_add != "": host_args.append("--add=%s" % host_add)
		children.append(OS.create_process(OS.get_executable_path(), PackedStringArray(host_args)))
		children.append(OS.create_process(OS.get_executable_path(), PackedStringArray(join_args)))
		var began := Time.get_ticks_msec()
		var host: Dictionary = {}
		var join: Dictionary = {}
		var busy := false
		var done := false
		while Time.get_ticks_msec() - began < PATIENCE_MSEC:
			var host_text := _read(host_log)
			var join_text := _read(join_log)
			busy = host_text.contains("BOOT_ERROR=Could not listen")
			host = latest(host_text); join = latest(join_text)
			done = not host.is_empty() and not join.is_empty() and done_when.call(host, join)
			if busy or done: break
			await get_tree().create_timer(0.1).timeout
		await bury()
		var result := {"level": level, "port": port, "host": host, "join": join, "done": done,
			"host_openxr": _xr_lines(_read(host_log)), "join_openxr": _xr_lines(_read(join_log))}
		if busy:
			port = TestPorts.first_free(FIRST_PORT, LAST_PORT - FIRST_PORT + 1, port)
			continue
		check("child_logs_contain_no_openxr_runtime_lines_%s_%d" % [level, port],
			int(result.host_openxr) == 0 and int(result.join_openxr) == 0, "%s" % [result])
		port = TestPorts.first_free(FIRST_PORT, LAST_PORT - FIRST_PORT + 1, port)
		return result
	return {"done": false, "error": TestPorts.busy(FIRST_PORT, LAST_PORT - FIRST_PORT + 1)}


static func _two_one_seat(crew: String, kind: String) -> bool:
	var rows := crew.split("/", false)
	if rows.size() != 2: return false
	for row in rows:
		if not row.begins_with(kind + ":"): return false
		var aboard := 0
		for seat in row.get_slice(":", 1).split(".", false):
			aboard += 0 if seat == "-" else 1
		if aboard != 1: return false
	return true


static func latest(text: String) -> Dictionary:
	var out: Dictionary = {}
	for line in text.split("\n"):
		if not line.begins_with("SESSION_REPORT "): continue
		out.clear()
		for pair_text in line.substr(15).strip_edges().split(" ", false):
			var kv := pair_text.split("=", true, 1)
			if kv.size() == 2: out[kv[0]] = kv[1]
	return out


static func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


static func _xr_lines(text: String) -> int:
	var count := 0
	for line in text.split("\n"):
		var lower := line.to_lower()
		if lower.contains("openxr") or lower.contains("xr runtime"): count += 1
	return count


func bury() -> void:
	var dying := children.duplicate()
	for pid in children:
		if pid > 0 and OS.is_process_running(pid): OS.kill(pid)
	children.clear()
	var began := Time.get_ticks_msec()
	for pid in dying:
		while pid > 0 and OS.is_process_running(pid) and Time.get_ticks_msec() - began < BURY_MSEC:
			await get_tree().create_timer(0.05).timeout


func _finish() -> void:
	for pid in children:
		if pid > 0 and OS.is_process_running(pid): OS.kill(pid)
	print("[craft_peers] RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)
