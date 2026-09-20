extends Node
## Headless, two real processes: A JOINED MACHINE UNDER A PRIORITY SPHERE STILL RECEIVES EVERY CRAFT, NEAR AND FAR.
##
##   Godot --headless --xr-mode off --path cockpit res://tests/priority_peers.tscn
##
## An ENet host and one joiner, both started from the command line with `--priority-radius=1000`, so the 2.8 km holding
## stack the host builds through its real TRAFFIC button (`--stack=50`) puts craft both inside and outside the joiner's
## sphere. The sphere is a rate and never a filter: a craft outside it must still arrive, and keep arriving.
##
## FRESHNESS, NOT MOTION. The level has craft that legitimately do not move -- the carrier's deck, parked aeroplanes -- and
## sync sends nothing for an entity that has not changed, so "every craft moved" would fail for the wrong reason. The
## joiner runs with `--freshness=1`: its client world keeps, without a Dictionary per event, the server frame of the newest
## VehicleState record for each craft (`CockpitWorld::received_frames`), and its report line says how stale the stalest
## MOVING craft is, near and far, by the craft's own replicated velocity. A moving craft is dirty on the host every tick, so
## its staleness is exactly how long it has waited to be chosen.
##
## THE BOUND, from the arithmetic: with N near craft at k and F far ones at 1, a far craft is chosen every
## A = (k * N + F) / M ticks when M updates fit a tick, and every tick when they all fit. The joiner reports the M it
## received; the check allows 2 * ceil(A) ticks and four more for the link and the report's own sampling.
##
## WHAT IT HOLDS:
##   * the host reports the sphere the command line asked for, and the joiner's client has craft both inside and outside;
##   * the joiner converges on every vehicle the host's SERVER has, not merely on what the host's own client draws;
##   * over an eight-second window, every moving far craft and every moving near craft is fresh within the bound, and no
##     moving craft was never received.
##
## Read RESULT=, not the exit code.

## 47994 of this checkout's block (`TestPorts`), asked silently at load whether anything holds it: a fixed
## number was the same socket in every lane. Held, and the suite says PORT BUSY at once rather than timing out.
static var PORT: int = TestPorts.first_free(47994, 1)
const PATIENCE_MS := 90000
const SETTLE_MS := 3000
const WINDOW_MS := 8000
const RADIUS := 1000
const STACK := 50
## Ticks allowed on top of 2 * ceil(A): the report is sampled five times a second, and a record is a tick on the link.
const SLACK_TICKS := 4

var _children: Array[int] = []
var _failed := false
var _said: Array[String] = []


func _ready() -> void:
	if PORT == 0:
		print("RESULT=FAIL port_busy %s" % TestPorts.busy(47994, 1))
		get_tree().quit(1)
		return
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL extension_missing")
		get_tree().quit(1)
		return
	var project := ProjectSettings.globalize_path("res://")
	var logs := {
		"host": ProjectSettings.globalize_path(TestPorts.log_for("priority_peers", "host")),
		"joiner": ProjectSettings.globalize_path(TestPorts.log_for("priority_peers", "joiner")),
	}
	for path in logs.values():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	# Wall-clock, like bulk_peers: --fixed-fps on a child would make a socket's time a fiction.
	var common := ["--headless", "--xr-mode", "off", "--desktop-only", "--path", project]
	_children.append(OS.create_process(OS.get_executable_path(), common + ["--log-file", logs.host, "--",
		"--host=%d" % PORT, "--world=%s" % ChartDrawer.DEFAULT, "--report=1", "--stack=%d" % STACK,
		"--priority-radius=%d" % RADIUS]))
	await _wall_msec(300)
	_children.append(OS.create_process(OS.get_executable_path(), common + ["--log-file", logs.joiner, "--",
		"--join=127.0.0.1:%d" % PORT, "--report=1", "--freshness=1", "--priority-radius=%d" % RADIUS]))
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
	# AGAINST THE HOST'S SERVER, not its client: a host whose prioritizer withheld the far craft draws them no more than
	# the joiner does, and the two agreeing on 19 of 133 passed this check with NaN outside the sphere.
	_check("the_joiner_converges_on_every_vehicle_the_host_serves",
		int(joiner.get("vehicles", 0)) == int(host.get("served", -1)) and int(host.get("stack", 0)) == STACK \
			and int(host.get("served", 0)) >= STACK,
		"host serves %s (stack %s) and draws %s, joiner draws %s" % [host.get("served", "?"), host.get("stack", "?"),
			host.get("vehicles", "?"), joiner.get("vehicles", "?")])
	if not _failed:
		await _wall_msec(SETTLE_MS)
		var first := _rows(logs.joiner, "FRESHNESS ").size()
		await _wall_msec(WINDOW_MS)
		var rows := _rows(logs.joiner, "FRESHNESS ").slice(first)
		host = _latest(logs.host, "SESSION_REPORT ")
		_measure(rows, host)
	_kill_children()
	print("RESULT=%s%s" % ["FAIL " if _failed else "PASS", ", ".join(_said)])
	get_tree().quit(1 if _failed else 0)


func _measure(rows: Array[Dictionary], host: Dictionary) -> void:
	_check("the_joiner_reports_freshness", rows.size() >= 10, "%d reports" % rows.size())
	if rows.is_empty():
		return
	var far_worst := 0
	var near_worst := 0
	var far := 0
	var near := 0
	var unseen := 0
	var updates := 0.0
	var inside := String(host.get("sphere", "on:0:1:1:flat")).split(":")
	var k := float(inside[2]) / maxf(float(inside[3]), 0.01) if inside.size() >= 4 else 1.0
	for row in rows:
		far_worst = maxi(far_worst, int(row.get("far_stale", 0)))
		near_worst = maxi(near_worst, int(row.get("near_stale", 0)))
		far = maxi(far, int(row.get("far", 0)))
		near = maxi(near, int(row.get("near", 0)))
		unseen = maxi(unseen, int(row.get("unseen", 0)))
		updates += float(row.get("per_tick", 0.0))
	updates /= float(rows.size())
	var a := (k * float(near) + float(far)) / maxf(updates, 0.001)
	var bound := 2 * maxi(1, ceili(a)) + SLACK_TICKS
	print("PRIORITY_PEERS near=%d far=%d per_tick=%.2f k=%.1f A=%.2f bound=%d near_worst=%d far_worst=%d unseen=%d reports=%d" % [
		near, far, updates, k, a, bound, near_worst, far_worst, unseen, rows.size()])
	_check("the_joiner_has_moving_craft_on_both_sides_of_the_sphere", near > 0 and far > 0,
		"%d near, %d far, moving" % [near, far])
	_check("no_moving_craft_was_never_received", unseen == 0, "%d never received" % unseen)
	_check("far_craft_stay_fresh", far_worst <= bound, "stalest far craft %d ticks, bound %d (A %.2f)" % [far_worst, bound, a])
	_check("near_craft_stay_fresh", near_worst <= bound, "stalest near craft %d ticks, bound %d" % [near_worst, bound])


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
	print("[priority_peers] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
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
