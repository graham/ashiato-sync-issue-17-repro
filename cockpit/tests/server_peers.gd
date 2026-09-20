extends Node
## Headless, TWO real processes over a real socket: does `--level=server` serve a world it is not playing?
##
##   Godot --headless --path cockpit res://tests/server_peers.tscn
##
## WHY THIS IS A PEERS SUITE AND NOT AN IN-PROCESS ONE. The thing under test is a process that hosts and does not play,
## and the only way to tell "serves nobody" from "serves nothing" is to have somebody arrive. One process can show a
## console with a zero on it; it cannot show that the zero becomes a one when a real machine joins over a real socket,
## which is the entire claim.
##
## WHAT IT HOLDS, and every one of these can fail for the right reason:
##
##   1. THE SERVER COMES UP AND SIMULATES. `SERVER_CONSOLE role=host ready=yes` with a craft count above zero -- the
##      island's own traffic, which the server runs for everybody whether or not anybody is watching it. `ready=` is
##      `Sim.is_ready` and it is checked EXPLICITLY, because the way this went wrong was a server whose scenery built
##      perfectly and whose world then never moved: `ready=no craft=0` for as long as it was watched.
##   2. **THE SERVER FLIES NOTHING OF ITS OWN.** Alone, `pilots=0` and `craft=93` -- the island's traffic and not one
##      thing more. A host is a sync client like any other and `_seat_new_clients` gives every client a pod, so before
##      `seat_the_host` the server flew a parked aeroplane for ever: measured, with nobody connected, `craft=94
##      pilots=1`. The 93rd craft against the 94th is the whole difference, which is why the count is checked and not
##      just the pilots.
##   3. A REAL CLIENT JOINS AND IS SEATED. The server lists two players and `pilots=1` -- one, not two, which is the
##      half of the fix that could have been broken by turning seating off altogether the way the flat lobby does.
##   4. THE JOINER ACTUALLY GETS A CRAFT, read off the JOINER's own `SESSION_REPORT`, not off the server's opinion of it.
##   5. NOBODY IS FLYING ON THE SERVER'S SIDE OF THE GLASS. The rig prints its key list (`[XR] Desktop: ...`) the moment
##      it is built, so the server's log NOT containing that line is what proves no rig, no seat, no hands and no XR.
##      The joiner's log containing it is the control: the same check on a machine that IS playing must come out the
##      other way, or it is a check about nothing.
##   6. **THE SERVER'S RADAR LOOKS FROM THE CONTROL TOWER.** A dedicated server flies nothing, so its head is a
##      controller's, and `RadarWatch` puts it on the `Sim.Kind.TOWER` the level already stands beside its first
##      runway. Held on the flag and on the head's HEIGHT, because a smaller picture is not evidence an aerial moved.
##   7. THE CONSOLE AND `SESSION_REPORT` AGREE. `SERVER_CONSOLE craft=` against `SESSION_REPORT served=`, both from the
##      server's own list. `server_console.gd`'s doc block claims the panel cannot drift from the report because both
##      ask the same authority; this is that claim, written down as something that fails when it stops being true.
##
## MUTANTS THIS CATCHES, each run against it:
##   - `seat_the_host` ignored in `_seat_new_clients`: check 2 fails, `pilots=1 craft=94` alone.
##   - the host's pod never spawned at all rather than spawned and taken away: check 1 fails, `ready=no craft=0`, which
##     is the trap this whole arrangement exists to avoid and the reason `ready=` is on the line.
##   - `Sim.seat_players = false` used instead (the flat lobby's switch): check 3 fails, the joiner is never seated.
##   - `server` kept as handed rather than resolved through `_server()`: check 1 fails, `craft=-1` for ever, because
##     `Sky` builds the console before it calls `Sim.start()`.
##   - `"server"` left out of `Sky._nobody_is_playing`: check 5 fails, the server builds a rig and prints the keys.
##   - the console counting `Sim.current` rather than the server's list: check 7 fails on a host, where the two differ.
##   - `RadarWatch._head_for` left on its origin placeholder: check 6 fails, the head reads 0 m over open water.
##
## THIS CHECKOUT'S PORTS (`TestPorts`): 48290-48299. It was the last block of a 400-wide range when this suite was
## written, and `radar_peers` then had nowhere to go, so `TestPorts.WIDTH` is 500 and the range ends at 48399. See
## the note there before taking another block.
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 48290
const PORTS: int = 10
## Seconds for a server to build the island and a joiner to arrive, be seated and report it. The island is the heavy
## level and a loaded machine has taken 30 s just to boot one process, so this is generous on purpose: a deadline that
## expires under load reports "the server did not serve" when it means "nobody has finished starting".
const PATIENCE_SECONDS: float = 150.0
## How long the server is watched ALONE before the joiner is started. Long enough for several console lines, so check 2
## is read off a settled server rather than off the one tick before its own pod would have been spawned.
const ALONE_SECONDS: float = 12.0

var _failures: PackedStringArray = []
var _children: Array[int] = []
var _logs: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[server_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	for who in ["server", "pilot"]:
		_logs[who] = ProjectSettings.globalize_path(TestPorts.log_for("server_peers", who))
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	var started: bool = false
	var alone: Dictionary = {}
	while port != 0 and not started:
		await _bury()
		for path in _logs.values():
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		# THE SERVER, exactly as `tools/server.ps1` starts one, plus `--report=1` so check 6 has a report to compare the
		# console against. Nothing else about the run is a test arrangement.
		_spawn(project, "server", ["--host=%d" % port, "--level=server", "--world=island", "--report=1"])
		await get_tree().create_timer(0.4).timeout
		if _read("server").contains("BOOT_ERROR=Could not listen"):
			var next: int = TestPorts.first_free(FIRST_PORT, PORTS, port)
			print("[server_peers] port %d is in use; trying %d" % [port, next])
			_kill_the_children()
			port = next
			continue

		# ---- ALONE: wait until it is serving, then watch it stay empty --------------------------
		var since: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
			if int(_latest("server", "SERVER_CONSOLE").get("craft", "-1").to_int()) > 0:
				break
			await get_tree().create_timer(0.3).timeout
		await get_tree().create_timer(ALONE_SECONDS).timeout
		alone = _latest("server", "SERVER_CONSOLE")

		# ---- AND THEN SOMEBODY ARRIVES ----------------------------------------------------------
		_spawn(project, "pilot", ["--join=127.0.0.1:%d" % port, "--player-name=PILOT", "--report=1"])
		# WAIT FOR THE JOINER TO HAVE THE WORLD, not merely to be listed on the server. The first version of this loop
		# stopped as soon as the SERVER said two players, and then read the joiner's own report -- which was its FIRST
		# one, written before replication had sent it anything: `pilots=1 vehicles=0`, and check 4 failed on a machine
		# that was about to be perfectly fine. Both ends have to have settled before either is asked.
		since = Time.get_ticks_msec()
		while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
			var console: Dictionary = _latest("server", "SERVER_CONSOLE")
			var mine: Dictionary = _latest("pilot", "SESSION_REPORT")
			if console.get("players", "0").to_int() >= 2 and console.get("pilots", "0").to_int() >= 1 \
					and mine.get("vehicles", "0").to_int() > 0:
				break
			await get_tree().create_timer(0.3).timeout
		started = true

	var served: Dictionary = _latest("server", "SERVER_CONSOLE")
	var report: Dictionary = _latest("server", "SESSION_REPORT")
	var joiner: Dictionary = _latest("pilot", "SESSION_REPORT")
	print("[server_peers] alone=%s served=%s report=%s joiner=%s" % [alone, served, report, joiner])

	_check("a_port_was_free_to_host_on", started, "on %d" % port if started else TestPorts.busy(FIRST_PORT, PORTS))

	# ---- 1. it serves a simulated world ---------------------------------------------------------
	_check("the_server_comes_up_hosting_and_simulating",
		String(alone.get("role", "")) == "host" and String(alone.get("ready", "no")) == "yes"
			and alone.get("craft", "0").to_int() > 0,
		"role=%s ready=%s craft=%s level=%s" % [alone.get("role", "-"), alone.get("ready", "-"),
			alone.get("craft", "-"), alone.get("level", "-")])

	# ---- 2. and flies nothing of its own --------------------------------------------------------
	# THE POD IT WAS HANDED TO FINISH ITS HANDSHAKE HAS GONE AGAIN, and said so in words. Checked on the note as well
	# as on the count, because `pilots=0` is also what a server that was never seated at all reads -- and that server
	# is the broken one. The note is the only thing that tells the two apart.
	_check("and_flies_nothing_of_its_own_while_nobody_is_connected",
		alone.get("pilots", "-1").to_int() == 0
			and _read("server").contains("[sim] the server's own pod is gone"),
		"pilots=%s craft=%s, and the pod %s" % [alone.get("pilots", "-"), alone.get("craft", "-"),
			"was given up" if _read("server").contains("the server's own pod is gone") else "WAS NEVER TAKEN AWAY"])

	# ---- 3. a real client joins and IS seated ---------------------------------------------------
	_check("a_joiner_is_listed_on_the_server", served.get("players", "0").to_int() == 2,
		"players=%s who=%s" % [served.get("players", "-"), served.get("who", "-")])
	_check("and_is_seated_while_the_server_still_is_not",
		served.get("pilots", "-1").to_int() == 1,
		"pilots=%s (one joiner, no server pod)" % served.get("pilots", "-"))

	# ---- 4. the joiner's own account of itself --------------------------------------------------
	_check("and_the_joiner_says_it_has_a_craft_of_its_own",
		joiner.get("pilots", "0").to_int() >= 1 and joiner.get("vehicles", "0").to_int() > 0,
		"joiner pilots=%s vehicles=%s" % [joiner.get("pilots", "-"), joiner.get("vehicles", "-")])

	# ---- 5. no rig on the server, and a rig on the machine that is playing ----------------------
	var server_rig: bool = _read("server").contains("[XR] Desktop:")
	var pilot_rig: bool = _read("pilot").contains("[XR] Desktop:")
	_check("the_server_builds_no_rig_no_seat_and_no_xr", not server_rig,
		"the server's log %s the rig's key list" % ["PRINTED" if server_rig else "never printed"])
	_check("and_the_machine_that_is_playing_does", pilot_rig,
		"the joiner's log %s it" % ["printed" if pilot_rig else "NEVER PRINTED, so check 5 proves nothing"])

	# ---- AND THE SERVER'S RADAR LOOKS FROM THE CONTROL TOWER ------------------------------------
	# A dedicated server flies nothing, so its radar head is a controller's: the `Sim.Kind.TOWER` `Terrain` stands
	# beside the first runway. Held on `radar_from_tower` AND on the head's own height, because "the picture got
	# smaller" is not evidence that an aerial moved -- a picture is smaller for a dozen reasons. The island's slab is
	# y = 0 and the middle of the map is open water, so a head still at the origin reads 0 and fails here.
	_check("the_server_s_radar_looks_from_the_control_tower",
		String(report.get("radar_from_tower", "no")) == "yes" and _head_height(report) > 1.0,
		"head %s, from the tower: %s" % [report.get("radar_head", "-"), report.get("radar_from_tower", "-")])

	# ---- 6. the console and the report cannot drift ---------------------------------------------
	var on_screen: int = served.get("craft", "-1").to_int()
	var in_report: int = report.get("served", "-2").to_int()
	_check("the_console_and_session_report_agree_about_the_craft", on_screen == in_report and on_screen > 0,
		"console craft=%d, report served=%d" % [on_screen, in_report])

	_finish()


## ---- the children ------------------------------------------------------------------------------

func _spawn(project: String, who: String, flags: Array) -> void:
	var arguments: Array = ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120",
		"--log-file", String(_logs[who]), "--path", project, "--"]
	arguments.append_array(flags)
	_children.append(OS.create_process(OS.get_executable_path(), arguments))


func _read(who: String) -> String:
	var path: String = String(_logs[who])
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## HOW HIGH THE RADAR HEAD STANDS, off `radar_head=x,y,z`. -1 where the report does not carry one.
func _head_height(report: Dictionary) -> float:
	var parts: PackedStringArray = String(report.get("radar_head", "-")).split(",")
	return float(parts[1]) if parts.size() == 3 else -1.0


## The LAST line in that log beginning with that word, as `key -> value`. The last one because a value that has not
## settled yet must never be mistaken for a value that never will; every report line in this project is written to be
## read this way.
func _latest(who: String, word: String) -> Dictionary:
	var out: Dictionary = {}
	for line in _read(who).split("\n"):
		if not line.begins_with(word + " "):
			continue
		out.clear()
		for pair in line.substr(word.length() + 1).strip_edges().split(" ", false):
			var kv: PackedStringArray = pair.split("=")
			if kv.size() == 2:
				out[kv[0]] = kv[1]
	return out


func _kill_the_children() -> void:
	for pid in _children:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_children.clear()


## Let a killed child's socket go before the next attempt takes the same port.
func _bury() -> void:
	_kill_the_children()
	await get_tree().create_timer(0.3).timeout


func _finish() -> void:
	_kill_the_children()
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
