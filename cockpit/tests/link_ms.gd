extends Node
## Headless: THE LEVEL'S OWN LINK, AND WHAT SYNC MEASURES OF IT ON THE OTHER MACHINE.
##
## The stress level asks for 80 ms. `Net.suit_the_link` gives the whole of it to every remote machine and none of it to
## the host, so 80 ms means 80 ms ONE WAY and 160 ms round trip -- `Net.extra_latency_ms` delays this machine's sends
## AND its receives, so one machine's edge is crossed once in each direction. Both ends holding 80 would be 160 one way
## and 320 round trip: the same number meaning twice the lag, which is the mistake this suite exists to make loud.
##
## THE DATUM IS NOT THE NUMBER THAT WAS INJECTED. Section 3 reads `timing().latency_frames` out of the joiner's own
## SESSION_REPORT: sync's estimate of the link, made in C++ from server frame numbers, against a delay put on the wire
## by GDScript at the socket edge. A suite that checked `Net.extra_latency_ms == 80` would be asking the injector what
## it injected (testing_godot_headless.md, "Anchor the check outside the thing it is checking"). A second joiner flies
## the same level with `--latency=0`, and the answer is the DIFFERENCE between the two, so the nine-ish frames are read
## against a MEASURED zero and not against arithmetic.
##
##     Godot --headless --xr-mode off --path cockpit res://tests/link_ms.tscn
##
## WALL CLOCK, AND NO `--fixed-fps` ON THE CHILDREN: a delay in milliseconds measured by a process running as fast as it
## can is a fiction (`bulk_peers` says the same, for the same reason).

## THROUGH THE AUTHORITY, so two checkouts gating at once do not bind the same socket. `priority_peers` typed 47994
## too, and `crew_peers`' range swallows it. See TestPorts.
## A `static var` and not a `const`: a const's initialiser must be a compile-time constant and a call is not one, so
## `const PORT := TestPorts.of(47994)` does not compile. Found by `lint`, which is why `lint` runs first.
## 47994 of this checkout's block (`TestPorts`), asked silently at load whether anything holds it: a fixed
## number was the same socket in every lane. Held, and the suite says PORT BUSY at once rather than timing out.
static var PORT: int = TestPorts.first_free(47994, 1)
const PATIENCE_MS := 60000
const SETTLE_MS := 7000
const WINDOW_MS := 5000
## 80 ms at 120 Hz is 9.6 ticks each way. sync reports whole frames, smooths its estimate, and a joiner's clock sits a
## tick either side of the host's, so the window is generous at the edges -- and both mutations in this suite's entry
## move the number to 0 or to 19, which is nowhere near it.
const WANT_FRAMES_LOW := 8
const WANT_FRAMES_HIGH := 12
## What sync measures of a link that is not there: a frame or two on this loopback, never nine.
const QUIET_FRAMES_MOST := 3

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
	_the_level_file_says_eighty()
	_the_rule_gives_it_to_the_remote_machine_only()
	await _over_a_real_socket()
	print("RESULT=%s%s" % ["FAIL " if _failed else "PASS", ", ".join(_said)])
	get_tree().quit(1 if _failed else 0)


## ---- 1. the level file ------------------------------------------------------------------------

func _the_level_file_says_eighty() -> void:
	var stress: LevelChart = ChartDrawer.chart("stress")
	_check("the_stress_level_is_on_the_desk", stress != null and stress.usable(),
		stress.refusal if stress != null else "no such level")
	if stress != null:
		_check("the_stress_level_asks_for_eighty_ms", stress.link_ms == 80, "link_ms %d" % stress.link_ms)
	var island: LevelChart = ChartDrawer.chart(ChartDrawer.DEFAULT)
	_check("a_level_that_says_nothing_asks_for_no_link", island != null and island.link_ms == 0,
		"island link_ms %d" % (island.link_ms if island != null else -1))
	# A LINK A SOCKET WOULD CLAMP IS A REFUSAL, not a number quietly made smaller behind the level's back: a measurement
	# would then have been taken over a link nobody wrote down.
	var over := LevelChart.new()
	over._take({"name": "Too far", "summary": "A link longer than a machine may hold.", "world": "island",
		"link_ms": Net.EXTRA_LATENCY_MOST_MS + 1, "spawn": {"at": [0, 30, 0], "yaw_degrees": 0}})
	_check("a_link_past_the_most_a_machine_holds_is_refused", not over.usable() and over.refusal.contains("link_ms"),
		"'%s'" % over.refusal)
	var fractional := LevelChart.new()
	fractional._take({"name": "Half a millisecond", "summary": "A link that is not whole.", "world": "island",
		"link_ms": 12.5, "spawn": {"at": [0, 30, 0], "yaw_degrees": 0}})
	_check("a_link_that_is_not_whole_is_refused", not fractional.usable(), "'%s'" % fractional.refusal)
	# AND THE LEVEL'S LINK IS IN ITS HASH, so a host and a joiner cannot fly one level over two different links.
	var slow := {"name": "A level", "summary": "A level.", "world": "island", "link_ms": 80,
		"spawn": {"at": [0, 30, 0], "yaw_degrees": 0}}
	var quick := slow.duplicate(true)
	quick["link_ms"] = 0
	_check("the_link_is_part_of_what_a_joiner_checks",
		LevelChart.canonical_hash(slow) != LevelChart.canonical_hash(quick),
		"%s against %s" % [LevelChart.canonical_hash(slow).left(8), LevelChart.canonical_hash(quick).left(8)])


## ---- 2. the rule, with no socket under it -----------------------------------------------------

func _the_rule_gives_it_to_the_remote_machine_only() -> void:
	# what the level asks, hosting, networked, chosen, what the machine holds now -> what it holds after
	var cases: Array = [
		["a_joiner_holds_the_whole_of_it", 80, false, true, false, 0, 80],
		["the_host_holds_none_of_it", 80, true, true, false, 0, 0],
		["a_machine_on_no_socket_holds_none_of_it", 80, false, false, false, 0, 0],
		["a_level_that_asks_nothing_takes_it_off_again", 0, false, true, false, 80, 0],
		["a_persons_choice_stands_over_the_level", 80, false, true, true, 25, 25],
		["and_stands_over_a_level_that_asks_nothing", 0, false, true, true, 80, 80],
	]
	for case in cases:
		var got: int = Net.link_for(int(case[1]), bool(case[2]), bool(case[3]), bool(case[4]), int(case[5]))
		_check("rule_%s" % String(case[0]), got == int(case[6]), "got %d ms, wanted %d" % [got, int(case[6])])


## ---- 3. over a real socket --------------------------------------------------------------------

## A HOST AND TWO JOINERS on the stress level, each in its own process: one takes the level's link, the other is told
## `--latency=0`, which is a person choosing and therefore beats the level. The answer is the DIFFERENCE between the two
## joiners' measured latencies, so the loopback's own frame or two, the joiners' clocks and whatever the desk was doing
## divide out -- and neither figure is the millisecond count this game injected.
##
## `tests/latency` already gates the socket mechanism itself (a `--latency=100` joiner measuring about twelve frames
## more than a clean one). What is new here, and all this section checks, is the path from the LEVEL FILE to that same
## socket, and the host holding none of it.
func _over_a_real_socket() -> void:
	var project := ProjectSettings.globalize_path("res://")
	# AND THE LOGS ARE NAMED FOR THE CHECKOUT (`TestPorts.log_for`), so two checkouts' children never write the same file. Every lane's cockpit
	# shares one `user://` -- `override.cfg` cannot move it, because Godot has chosen the user directory before that
	# file is read -- and each run deletes these at its start, so the loser of a race reads an empty file and reports
	# an empty dictionary, which looks exactly like the code under test being broken. It cost this lane an hour.
	var logs := {
		"host": ProjectSettings.globalize_path(TestPorts.log_for("link_ms", "host")),
		"level": ProjectSettings.globalize_path(TestPorts.log_for("link_ms", "level")),
		"chosen": ProjectSettings.globalize_path(TestPorts.log_for("link_ms", "chosen")),
	}
	for path in logs.values():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var common := ["--headless", "--xr-mode", "off", "--desktop-only", "--path", project]
	_children.append(OS.create_process(OS.get_executable_path(), common + ["--log-file", logs.host, "--",
		"--host=%d" % PORT, "--world=stress", "--report=1"]))
	await _wall_msec(500)
	_children.append(OS.create_process(OS.get_executable_path(), common + ["--log-file", logs.level, "--",
		"--join=127.0.0.1:%d" % PORT, "--report=1"]))
	_children.append(OS.create_process(OS.get_executable_path(), common + ["--log-file", logs.chosen, "--",
		"--join=127.0.0.1:%d" % PORT, "--report=1", "--latency=0"]))
	var began := Time.get_ticks_msec()
	var host: Dictionary = {}
	var level: Dictionary = {}
	var chosen: Dictionary = {}
	while Time.get_ticks_msec() - began < PATIENCE_MS:
		host = _latest(logs.host)
		level = _latest(logs.level)
		chosen = _latest(logs.chosen)
		if int(host.get("clients", 0)) == 3 and String(level.get("level", "")) == "stress" \
				and String(chosen.get("level", "")) == "stress":
			break
		OS.delay_msec(10)
		await get_tree().process_frame
	# THIS SECTION'S OWN ANSWER, not the suite's. Asking `_failed` here would skip the measurement whenever ANY earlier
	# check had gone red -- which is exactly what happened under the first mutation: the pure rule failed, and the
	# socket round, the part that costs twenty seconds and carries the number, never ran.
	var everybody_arrived: bool = int(host.get("clients", 0)) == 3 \
		and String(level.get("level", "")) == "stress" and String(chosen.get("level", "")) == "stress"
	_check("both_joiners_fly_the_hosts_level_over_the_link_it_asks_for", everybody_arrived,
		"host clients=%s, joiners on %s and %s" % [host.get("clients"), level.get("level"), chosen.get("level")])
	if not everybody_arrived:
		_kill_children()
		return
	await _wall_msec(SETTLE_MS)
	var first_level := _reports(logs.level).size()
	var first_chosen := _reports(logs.chosen).size()
	var first_host := _reports(logs.host).size()
	await _wall_msec(WINDOW_MS)
	var level_rows: Array[Dictionary] = _reports(logs.level).slice(first_level)
	var chosen_rows: Array[Dictionary] = _reports(logs.chosen).slice(first_chosen)
	var host_rows: Array[Dictionary] = _reports(logs.host).slice(first_host)
	_kill_children()
	_check("every_machine_reported_a_window",
		level_rows.size() >= 5 and chosen_rows.size() >= 5 and host_rows.size() >= 5,
		"%d, %d and %d reports" % [level_rows.size(), chosen_rows.size(), host_rows.size()])
	if level_rows.size() < 5 or chosen_rows.size() < 5 or host_rows.size() < 5:
		return
	var level_frames := _median(level_rows, "latency_frames")
	var chosen_frames := _median(chosen_rows, "latency_frames")
	var host_frames := _median(host_rows, "latency_frames")
	var grew := level_frames - chosen_frames
	print("LINK_MS level_joiner_holds=%d chosen_joiner_holds=%d host_holds=%d latency_frames level=%.1f chosen=%.1f host=%.1f grew=%.1f (%.1f ms one way at 120 Hz)" % [
		int(level_rows[-1].get("link_ms", -1)), int(chosen_rows[-1].get("link_ms", -1)),
		int(host_rows[-1].get("link_ms", -1)), level_frames, chosen_frames, host_frames,
		grew, grew / 120.0 * 1000.0])
	_check("the_level_puts_its_own_link_on_a_joiner", int(level_rows[-1].get("link_ms", -1)) == 80,
		"%d ms" % int(level_rows[-1].get("link_ms", -1)))
	_check("a_joiner_that_was_told_otherwise_keeps_its_own", int(chosen_rows[-1].get("link_ms", -1)) == 0,
		"%d ms" % int(chosen_rows[-1].get("link_ms", -1)))
	# THE HOST HOLDS NONE OF IT, and its own client is in its own process, so the host's row on any stats board reads a
	# link of nothing. That is the definition working rather than a bug, and it is checked here so it cannot change
	# without somebody saying so.
	_check("the_host_adds_no_delay_of_its_own", int(host_rows[-1].get("link_ms", -1)) == 0,
		"host holds %d ms" % int(host_rows[-1].get("link_ms", -1)))
	_check("the_host_measures_no_link_to_itself", host_frames <= float(QUIET_FRAMES_MOST),
		"host latency_frames %.1f" % host_frames)
	# AND THE ANSWER, out of sync's own estimate, as the difference between the two joiners.
	_check("sync_measures_the_link_the_level_asked_for",
		grew >= float(WANT_FRAMES_LOW) and grew <= float(WANT_FRAMES_HIGH),
		"%.1f frames more than the joiner with no link, wanted %d to %d" % [grew, WANT_FRAMES_LOW, WANT_FRAMES_HIGH])


func _median(rows: Array[Dictionary], key: String) -> float:
	var values: Array[float] = []
	for row in rows:
		values.append(float(row.get(key, 0)))
	values.sort()
	return values[values.size() / 2]


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
	print("[link_ms] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
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
