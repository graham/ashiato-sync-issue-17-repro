extends Node
## REPRODUCES ashiato-sync ISSUE #17: a joining client that stops being told about a craft for over a thousand ticks.
##
##   Godot --headless --xr-mode off --path cockpit res://tests/issue17_repro.tscn
##   Godot --headless --xr-mode off --path cockpit res://tests/issue17_repro.tscn -- --trace-root=<a fast local dir>
##
## WRITTEN TO BE READ BY SOMEBODY WHO HAS NEVER SEEN THIS GAME. It is the reproduction sent to the maintainer of
## ashiato-sync, and `find_once.bat` and `find_repeating.bat` at the top of the repository are wrappers around it.
##
## WHAT IT DOES. Starts two real OS processes talking over ENet on the loopback: a host serving about 146 replicated
## aircraft, and one client that joins 300 ms later. Both are told `--priority-radius=1000`, so the host's priority
## sphere makes craft within 1000 m of the joiner four times as likely to be chosen as craft outside it. The sphere is
## a RATE, never a filter: a craft outside it must still arrive, and keep arriving.
##
## WHAT IT MEASURES. FRESHNESS, NOT MOTION. The level has craft that legitimately never move -- a carrier's deck,
## parked aeroplanes -- and sync sends nothing for an entity that has not changed, so "every craft moved" would fail
## for the wrong reason. The joiner therefore watches only craft moving faster than 5 m/s by their own replicated
## velocity. A moving craft is dirty on the host every single tick, so how stale it is IS how long it has waited to be
## chosen. The joiner keeps, per craft, the server frame of the newest VehicleState record it has decoded
## (`CockpitWorld::received_frames`, fed at decode time, before any apply), and reports the worst.
##
## THE ALLOWANCE IS COMPUTED, NOT TYPED. With N near craft at weight k and F far ones at 1, a far craft's turn comes
## round every A = (k*N + F) / M ticks when M records fit in a tick. The joiner reports the M it actually achieved
## this run, so the bound follows the run rather than the run being judged against a guess. It allows 2*ceil(A) and
## four ticks more for the link and for the report's own sampling. In practice that lands near 10.
##
## WHAT REPRODUCING LOOKS LIKE. A craft waits 500-1500 ticks against an allowance near 10 -- about a hundred times
## over -- while nothing is refused, nothing is lost, and the totals look healthy.
##
## IT DOES NOT REPRODUCE EVERY RUN. About four runs in five at the time of writing. `find_repeating.bat` exists
## because of that.
##
## Read the VERDICT line. RESULT=FAIL means the bug appeared; RESULT=PASS means this run happened to be healthy.

static var PORT: int = TestPorts.first_free(47994, 1)
const PATIENCE_MS := 90000
const SETTLE_MS := 3000
const WINDOW_MS := 8000
const RADIUS := 1000
const STACK := 50
## Ticks allowed on top of 2 * ceil(A): the report is sampled five times a second, and a record is a tick on the link.
const SLACK_TICKS := 4
## How long a child gets to close a trace and go, when tracing was asked for.
const GOODBYE_MS := 30000

var _children: Array[int] = []
var _failed := false
var _said: Array[String] = []
var _root := ""
var _began_at: Dictionary = {}


func _ready() -> void:
	if PORT == 0:
		print("RESULT=FAIL port_busy %s" % TestPorts.busy(47994, 1))
		get_tree().quit(1)
		return
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL extension_missing")
		print("VERDICT: CANNOT RUN -- the ashiato-gd extension did not load. Build it first; see the README.")
		get_tree().quit(1)
		return
	var project := ProjectSettings.globalize_path("res://")
	_root = _where_the_trace_goes()
	var tracing := not _root.is_empty()
	var extra_host := PackedStringArray()
	var extra_joiner := PackedStringArray()
	if tracing:
		# THE LIBRARY'S OWN TRACE FILES, one directory per role, which is what upstream asked for on issue #17.
		# Off unless asked: it is about 210 MB a run.
		var server_dir := _root.path_join("server")
		var joiner_dir := _root.path_join("joiner")
		for directory in [server_dir, joiner_dir]:
			DirAccess.make_dir_recursive_absolute(directory)
		extra_host.append("--sync-trace-dir=%s" % server_dir)
		extra_joiner.append("--sync-trace-dir=%s" % joiner_dir)
		print("[issue17] traces -> %s" % _root)
	# ASKED TO LEAVE, NEVER KILLED, whether or not it is tracing: the trace writer is a thread with a queue in front
	# of it, so a killed process loses the end of the run -- the part with the stall in it.
	var stop_file := _stop_file()
	extra_host.append("--stop-file=%s" % stop_file)
	extra_joiner.append("--stop-file=%s" % stop_file)
	if FileAccess.file_exists(stop_file):
		DirAccess.remove_absolute(stop_file)
	var logs := {
		"host": ProjectSettings.globalize_path(TestPorts.log_for("issue17_repro", "host")),
		"joiner": ProjectSettings.globalize_path(TestPorts.log_for("issue17_repro", "joiner")),
	}
	for path in logs.values():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var common := ["--headless", "--xr-mode", "off", "--desktop-only", "--path", project]
	_began_at["host"] = _now()
	_children.append(OS.create_process(OS.get_executable_path(), common + ["--log-file", logs.host, "--",
		"--host=%d" % PORT, "--world=%s" % ChartDrawer.DEFAULT, "--report=1", "--stack=%d" % STACK,
		"--priority-radius=%d" % RADIUS] + Array(extra_host)))
	await _wall_msec(300)
	_began_at["joiner"] = _now()
	_children.append(OS.create_process(OS.get_executable_path(), common + ["--log-file", logs.joiner, "--",
		"--join=127.0.0.1:%d" % PORT, "--report=1", "--freshness=1", "--priority-radius=%d" % RADIUS]
		+ Array(extra_joiner)))
	print("[issue17] host and joiner started on port %d; giving them up to %d s to converge" % [PORT, PATIENCE_MS / 1000])
	var began := Time.get_ticks_msec()
	var host: Dictionary = {}
	var joiner: Dictionary = {}
	while Time.get_ticks_msec() - began < PATIENCE_MS:
		host = _latest(logs.host, "SESSION_REPORT ")
		joiner = _latest(logs.joiner, "SESSION_REPORT ")
		if int(host.get("stack", 0)) == STACK and int(joiner.get("vehicles", 0)) == int(host.get("served", -1)) \
				and int(host.get("clients", 0)) == 2:
			break
		OS.delay_msec(10)
		await get_tree().process_frame
	_check("the_host_asked_for_the_sphere_on_its_command_line",
		String(host.get("sphere", "")).begins_with("on:%d:" % RADIUS), "sphere=%s" % host.get("sphere", "?"))
	# AGAINST THE HOST'S SERVER, not its client: a host whose prioritizer withheld the far craft draws them no more
	# than the joiner does, and the two agreeing proves nothing.
	_check("the_joiner_converges_on_every_vehicle_the_host_serves",
		int(joiner.get("vehicles", 0)) == int(host.get("served", -1)) and int(host.get("stack", 0)) == STACK \
			and int(host.get("served", 0)) >= STACK,
		"host serves %s (stack %s) and draws %s, joiner draws %s" % [host.get("served", "?"), host.get("stack", "?"),
			host.get("vehicles", "?"), joiner.get("vehicles", "?")])
	var measured: Dictionary = {}
	if not _failed:
		print("[issue17] converged; settling %d s, then measuring for %d s" % [SETTLE_MS / 1000, WINDOW_MS / 1000])
		await _wall_msec(SETTLE_MS)
		var first := _rows(logs.joiner, "FRESHNESS ").size()
		await _wall_msec(WINDOW_MS)
		var rows := _rows(logs.joiner, "FRESHNESS ").slice(first)
		host = _latest(logs.host, "SESSION_REPORT ")
		measured = _measure(rows, host)
	var left := await _ask_the_children_to_go(stop_file)
	if tracing:
		_write_the_manifest(host, measured, left, logs)
		for who in logs.keys():
			if FileAccess.file_exists(logs[who]):
				DirAccess.copy_absolute(logs[who], _root.path_join("%s.log" % who))
	_say_the_verdict(measured, host)
	print("RESULT=%s%s" % ["FAIL " if _failed else "PASS", ", ".join(_said)])
	get_tree().quit(1 if _failed else 0)


## THE WHOLE POINT OF THE RUN, in words, for a reader who has never seen this game.
func _say_the_verdict(measured: Dictionary, host: Dictionary) -> void:
	print("")
	print("---------------- ashiato-sync issue #17 ----------------")
	print("  scenario : %s craft on the host, one joining client, two OS processes over ENet" % host.get("served", "?"))
	print("             priority sphere %s, %d Hz, %d bytes per tick" % [host.get("sphere", "?"),
		int(Sim.DEFAULT_TICK_HZ), int(round(245000.0 / Sim.DEFAULT_TICK_HZ))])
	if measured.is_empty():
		print("  VERDICT  : COULD NOT MEASURE -- the two peers never converged. Not the bug; see the log above.")
		print("--------------------------------------------------------")
		return
	print("  measured : the joiner's stalest moving FAR craft waited %s server frames for an update" % measured.get(
		"far_worst", "?"))
	print("             its stalest moving NEAR craft waited %s" % measured.get("near_worst", "?"))
	print("  allowed  : %s, computed from the %s records a tick this run actually achieved" % [
		measured.get("bound", "?"), measured.get("per_tick", "?")])
	if _failed:
		print("  VERDICT  : BUG REPRODUCED. One craft waited %s ticks where %s was the allowance, about %sx over." % [
			measured.get("far_worst", "?"), measured.get("bound", "?"),
			int(float(measured.get("far_worst", 0)) / maxf(float(measured.get("bound", 1)), 1.0))])
		print("             Nothing was refused and nothing was lost: %s craft were never received at all." %
			measured.get("unseen", "?"))
	else:
		print("  VERDICT  : not reproduced on this run. It is intermittent -- use find_repeating.bat.")
	print("--------------------------------------------------------")


## `-- --trace-root=<path>`, or empty for no trace files at all.
func _where_the_trace_goes() -> String:
	var asked := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--trace-root="):
			asked = argument.get_slice("=", 1)
	if asked.is_empty():
		return ""
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "-").replace("T", "_")
	return asked.path_join(stamp)


func _stop_file() -> String:
	var where := _root if not _root.is_empty() else ProjectSettings.globalize_path("user://")
	return where.path_join("issue17_stop_%d" % PORT)


## THE STOP FILE, AND THEN WAIT. Whether each child left of its own accord is part of the evidence when tracing, so it
## is returned rather than merely done.
func _ask_the_children_to_go(stop_file: String) -> Dictionary:
	var note := FileAccess.open(stop_file, FileAccess.WRITE)
	if note != null:
		note.store_string("stop\n")
		note.close()
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < GOODBYE_MS:
		var still := 0
		for pid in _children:
			if pid > 0 and OS.is_process_running(pid):
				still += 1
		if still == 0:
			var took := Time.get_ticks_msec() - began
			_children.clear()
			return {"clean": true, "ms": took}
		OS.delay_msec(50)
		await get_tree().process_frame
	var forced := 0
	for pid in _children:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
			forced += 1
	_children.clear()
	print("[issue17] WARNING: %d child(ren) had to be killed; a trace from this run may be missing its tail" % forced)
	return {"clean": false, "ms": GOODBYE_MS, "killed": forced}


## EVERYTHING UPSTREAM ASKED TO BE TOLD ABOUT A TRACED RUN, in the trace directory with the traces.
func _write_the_manifest(host: Dictionary, measured: Dictionary, left: Dictionary, logs: Dictionary) -> void:
	var out := PackedStringArray()
	out.append("# ashiato-sync issue 17 capture")
	out.append("result=%s" % ("FAIL" if _failed else "PASS"))
	out.append("failed_checks=%s" % ("-" if _said.is_empty() else ",".join(_said)))
	out.append("")
	out.append("[processes]")
	out.append("host_started_utc=%s" % _began_at.get("host", "?"))
	out.append("joiner_started_utc=%s" % _began_at.get("joiner", "?"))
	out.append("joiner_client_id=%s" % measured.get("client_id", "?"))
	out.append("shut_down_cleanly=%s" % str(left.get("clean", false)).to_lower())
	out.append("shutdown_ms=%s" % left.get("ms", "?"))
	out.append("port=%d" % PORT)
	out.append("host_log=%s" % logs.get("host", "?"))
	out.append("joiner_log=%s" % logs.get("joiner", "?"))
	out.append("")
	out.append("[measurement]")
	out.append("stalest_far_craft_ticks=%s" % measured.get("far_worst", "?"))
	out.append("stalest_far_craft_entity_on_the_joiner=%s" % measured.get("far_worst_entity", "?"))
	out.append("stalest_far_craft_last_server_frame=%s" % measured.get("far_worst_at", "?"))
	out.append("newest_server_frame_at_that_sample=%s" % measured.get("far_worst_newest", "?"))
	out.append("server_frame_interval_of_the_gap=%s..%s" % [measured.get("far_worst_at", "?"),
		measured.get("far_worst_newest", "?")])
	out.append("stalest_near_craft_ticks=%s" % measured.get("near_worst", "?"))
	out.append("bound_the_suite_allowed=%s" % measured.get("bound", "?"))
	out.append("never_received=%s" % measured.get("unseen", "?"))
	out.append("moving_near=%s moving_far=%s" % [measured.get("near", "?"), measured.get("far", "?")])
	out.append("records_per_tick=%s" % measured.get("per_tick", "?"))
	out.append("# ENTITY IDS ARE THE JOINER'S. The host numbers the same craft differently; the trace records carry")
	out.append("# both a local and a server entity, so the pairing is in the data rather than in this file.")
	out.append("")
	out.append("[scenario]")
	out.append("craft_served_by_the_host=%s" % host.get("served", "?"))
	out.append("holding_stack=%d" % STACK)
	out.append("priority_sphere=%s" % host.get("sphere", "?"))
	out.append("priority_radius_m=%d" % RADIUS)
	out.append("priority_inside=%s outside=%s" % [Sim.PRIORITY_INSIDE, Sim.PRIORITY_OUTSIDE])
	out.append("tick_hz=%s" % Sim.DEFAULT_TICK_HZ)
	out.append("settle_ms=%d measured_window_ms=%d" % [SETTLE_MS, WINDOW_MS])
	out.append("joiner_started_ms_after_the_host=300")
	out.append("")
	out.append("[sync configuration]")
	out.append("bandwidth_bytes_per_second=245000")
	out.append("bandwidth_bytes_per_tick=%d" % int(round(245000.0 / Sim.DEFAULT_TICK_HZ)))
	out.append("mtu_bytes=1200")
	out.append("max_budget_refusals_per_client_tick=2")
	out.append("max_pending_packet_acks_per_client=255")
	out.append("client_local_wire_network_id_bits=20")
	var path := _root.path_join("manifest.txt")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(out) + "\n")
		file.close()
		print("[issue17] manifest -> %s" % path)


func _measure(rows: Array[Dictionary], host: Dictionary) -> Dictionary:
	_check("the_joiner_reports_freshness", rows.size() >= 10, "%d reports" % rows.size())
	if rows.is_empty():
		return {}
	var far_worst := 0
	var near_worst := 0
	var far := 0
	var near := 0
	var unseen := 0
	var updates := 0.0
	var worst_entity := 0
	var worst_at := -1
	var worst_newest := -1
	var client_id := 0
	var inside := String(host.get("sphere", "on:0:1:1:flat")).split(":")
	var k := float(inside[2]) / maxf(float(inside[3]), 0.01) if inside.size() >= 4 else 1.0
	for row in rows:
		# THE SAMPLE THAT HELD THE WORST GAP, so a traced run can name the craft and the server frames it ran over.
		if int(row.get("far_stale", 0)) > far_worst:
			worst_entity = int(row.get("far_worst", 0))
			worst_at = int(row.get("far_worst_at", -1))
			worst_newest = int(row.get("newest", -1))
		far_worst = maxi(far_worst, int(row.get("far_stale", 0)))
		near_worst = maxi(near_worst, int(row.get("near_stale", 0)))
		far = maxi(far, int(row.get("far", 0)))
		near = maxi(near, int(row.get("near", 0)))
		unseen = maxi(unseen, int(row.get("unseen", 0)))
		client_id = maxi(client_id, int(row.get("client_id", 0)))
		updates += float(row.get("per_tick", 0.0))
	updates /= float(rows.size())
	var a := (k * float(near) + float(far)) / maxf(updates, 0.001)
	var bound := 2 * maxi(1, ceili(a)) + SLACK_TICKS
	print("ISSUE17 near=%d far=%d per_tick=%.2f k=%.1f A=%.2f bound=%d near_worst=%d far_worst=%d unseen=%d reports=%d" % [
		near, far, updates, k, a, bound, near_worst, far_worst, unseen, rows.size()])
	print("ISSUE17 stalest_far_entity=%d last_server_frame=%d newest_server_frame=%d client_id=%d" % [
		worst_entity, worst_at, worst_newest, client_id])
	_check("the_joiner_has_moving_craft_on_both_sides_of_the_sphere", near > 0 and far > 0,
		"%d near, %d far, moving" % [near, far])
	_check("no_moving_craft_was_never_received", unseen == 0, "%d never received" % unseen)
	_check("far_craft_stay_fresh", far_worst <= bound, "stalest far craft %d ticks, bound %d (A %.2f)" % [far_worst, bound, a])
	_check("near_craft_stay_fresh", near_worst <= bound, "stalest near craft %d ticks, bound %d" % [near_worst, bound])
	return {"far_worst": far_worst, "near_worst": near_worst, "bound": bound, "unseen": unseen, "near": near,
		"far": far, "per_tick": "%.2f" % updates, "far_worst_entity": worst_entity, "far_worst_at": worst_at,
		"far_worst_newest": worst_newest, "client_id": client_id}


func _now() -> String:
	return "%s (unix_ms %d)" % [Time.get_datetime_string_from_system(true),
		int(Time.get_unix_time_from_system() * 1000.0)]


func _rows(path: String, word: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return out
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.begins_with(word):
			continue
		var row: Dictionary = {}
		for pair in line.substr(word.length()).strip_edges().split(" ", false):
			var kv := pair.split("=")
			if kv.size() == 2:
				row[kv[0]] = kv[1]
		out.append(row)
	return out


func _latest(path: String, word: String) -> Dictionary:
	var rows := _rows(path, word)
	return rows[-1] if not rows.is_empty() else {}


func _wall_msec(msec: int) -> void:
	var until := Time.get_ticks_msec() + msec
	while Time.get_ticks_msec() < until:
		OS.delay_msec(10)
		await get_tree().process_frame


func _check(name: String, passed: bool, detail: String) -> void:
	print("[issue17] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
	if not passed:
		_failed = true
		_said.append(name)


func _exit_tree() -> void:
	for pid in _children:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_children.clear()
