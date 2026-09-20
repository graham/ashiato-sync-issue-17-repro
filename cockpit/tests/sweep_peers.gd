extends Node
## Headless: THE F-14'S WING SWEEP ACROSS TWO REAL MACHINES. A host takes a Tomcat and flies it; a joiner boards it as
## the RIO. Each moves the sweep handle at ITS OWN seat with a hand, and each machine writes down every change in the
## wings it sees. Read RESULT=, not the exit code.
##
##   Godot --headless --path cockpit res://tests/sweep_peers.tscn
##
## WHAT THE USER ASKED FOR, checked from both logs: the sweep "should be visible to all players and controllable by both
## the pilot and copilot". So:
##   the PILOT's handle sweeps the wings as the RIO's machine sees them, and the RIO's handle -- which nobody on that
##   machine touched -- moves to match (the handle shows the bus, not the hand: house rule 5);
##   the RIO's handle, at a seat that does not fly, sweeps the wings as the PILOT's machine sees them;
##   the wings TRAVEL: the other machine sees intermediate values, not a jump, at about 12 degrees a second;
##   BOTH HANDS AT ONCE: the two machines end agreeing on one of the two asks -- the last command to reach the server
##   wins, which is what two hands on one lever do.
##
## THE REAL PATH. The host takes the Tomcat with the real key a desk player presses (F1 + kind, both codes set). The
## joiner boards through the JOIN on its own CREW page (`--board`). Each handle is moved by a hand closed on it through
## the rig's own hand pass. Nothing here sends a command. See `WingSweepHarness`, which both children run.
##
## THIS CHECKOUT'S PORTS (`TestPorts`), the first free one asked silently before a child starts, from these:
## PORTS 48200-48209, which no other suite uses. The children write --log-file, for the reason two_peers gives.

const FIRST_PORT: int = 48200
const PORTS: int = 10
const PATIENCE_SECONDS: float = 150.0
const BOARD_AFTER_SECONDS: int = 3
## Each machine's plan: WHEN:DEGREES, where WHEN is seconds after both seats are manned, or `@BYTE+SECONDS` after that
## machine sees the wings settled at that bus value (`WingSweepHarness`). The pilot sweeps back first; the RIO waits for
## the wings to arrive and brings them forward; then both hands move two seconds after each machine sees THAT settle,
## which is "at once" as nearly as two machines can arrange it.
const PILOT_PLAN := "3:68,@46+2:40"
const RIO_PLAN := "@223+1:30,@46+2:60"
## The bus's bytes for those angles: 0 is 20 degrees and 255 is 75.
const FULL: int = 223      # 68 degrees
const RIO_ASK: int = 46    # 30 degrees
const PILOT_LAST: int = 93  # 40 degrees
const RIO_LAST: int = 185   # 60 degrees
## The seconds a full sweep from 20 to 68 degrees should take at 12 degrees a second.
const TRAVEL_SECONDS: float = 4.0

var _failures: PackedStringArray = []
var _children: Array[int] = []
var _let_go_at: int = -1


func _check(label: String, ok: bool, detail: String) -> void:
	print("[sweep_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	var host_log: String = ProjectSettings.globalize_path(TestPorts.log_for("sweep_peers", "host"))
	var join_log: String = ProjectSettings.globalize_path(TestPorts.log_for("sweep_peers", "join"))
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	var started: bool = false
	var host_said: String = ""
	var join_said: String = ""
	var since: int = Time.get_ticks_msec()
	while port != 0 and not started:
		for path in [host_log, join_log]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		_children.append(OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only",
			"--fixed-fps", "120", "--log-file", host_log, "--path", project, "--", "--host=%d" % port,
			"--world=%s" % ChartDrawer.DEFAULT, "--report=1", "--take-kind=tomcat", "--sweep=%s" % PILOT_PLAN]))
		_children.append(OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only",
			"--fixed-fps", "120", "--log-file", join_log, "--path", project, "--", "--join=127.0.0.1:%d" % port,
			"--report=1", "--board=%d" % BOARD_AFTER_SECONDS, "--sweep=%s" % RIO_PLAN]))
		since = Time.get_ticks_msec()
		var busy: bool = false
		while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
			host_said = _read(host_log)
			join_said = _read(join_log)
			busy = host_said.contains("BOOT_ERROR=Could not listen")
			# DONE three seconds after both have let go of their last drag, and once the wings have settled. The first
			# version stopped the moment both logs looked settled, which can be before the last command has crossed the
			# wire: it killed both machines with the RIO's last drag still in flight.
			if busy:
				break
			if host_said.count("let go at") >= 2 and join_said.count("let go at") >= 2:
				if _let_go_at < 0:
					_let_go_at = Time.get_ticks_msec()
				if Time.get_ticks_msec() - _let_go_at > 3000 and _settled(host_said) and _settled(join_said):
					break
			await get_tree().create_timer(0.25).timeout
		_kill_the_children()
		if busy:
			var next: int = TestPorts.first_free(FIRST_PORT, PORTS, port)
			print("[sweep_peers] port %d is in use; trying %d" % [port, next])
			port = next
			continue
		started = true
	print("[sweep_peers] after %d ms" % (Time.get_ticks_msec() - since))
	var host: Array = _wings(host_said)
	var join: Array = _wings(join_said)
	print("[sweep_peers] measure: %d WINGS lines on the host, %d on the joiner" % [host.size(), join.size()])
	_check("a_port_was_free_to_host_on", started, "on %d" % port if started else TestPorts.busy(FIRST_PORT, PORTS))
	_check("the_host_took_a_tomcat_with_the_real_key_and_the_joiner_boarded_it_as_rio",
		host_said.contains("TOOK tomcat") and join_said.contains("BOARDING") and host_said.contains("CREWED seat 0")
			and join_said.contains("CREWED seat 1"),
		"TOOK %s, BOARDING %s, host crewed at seat 0 %s, joiner at seat 1 %s" % [host_said.contains("TOOK tomcat"),
			join_said.contains("BOARDING"), host_said.contains("CREWED seat 0"), join_said.contains("CREWED seat 1")])
	_the_pilots_hand_sweeps_the_wings_the_rio_sees(join, join_said, host)
	_the_rios_hand_sweeps_the_wings_the_pilot_sees(host, host_said)
	_both_hands_at_once_end_with_both_machines_agreeing(host, join, host_said, join_said)
	_finish()


## THE PILOT'S HAND, SEEN FROM THE RIO'S MACHINE: the command arrives, the wings travel to it one small step at a time and
## at about the rate, and the RIO's own handle -- untouched on this machine -- moves to the command before the RIO's hand
## ever closes on it.
func _the_pilots_hand_sweeps_the_wings_the_rio_sees(join: Array, said: String, host: Array) -> void:
	var climb: Array = _travel(join, 0, FULL)
	# THE RATE ON THE HOST, which is the server: its ticks are the simulation's. The joiner's physics clock is its own
	# (under --fixed-fps each process steps as fast as it can) and times the arrival of packets, not the travel.
	var served: Array = _travel(host, 0, FULL)
	var steps: Dictionary = {}
	var jump: int = 0
	for i in range(1, climb.size()):
		steps[int(climb[i]["sweep"])] = true
		jump = maxi(jump, absi(int(climb[i]["sweep"]) - int(climb[i - 1]["sweep"])))
	var seconds: float = float(int(served[-1]["tick"]) - int(served[0]["tick"])) / 120.0 if served.size() > 1 else 0.0
	var before_own: String = said.substr(0, said.find("SWEEP seat 1 asks"))
	var handle_moved: bool = false
	for row in _wings(before_own):
		if absf(float(row["handle"]) - 68.0) < 0.6:
			handle_moved = true
	_check("the_pilots_hand_sweeps_the_wings_the_rio_sees_and_moves_the_rios_handle",
		climb.size() > 1 and steps.size() >= 30 and jump <= FULL / 5 and absf(seconds - TRAVEL_SECONDS) < 1.0 and handle_moved,
		"on the RIO's machine the wings went 0 to %d through %d different values, the largest step %d (a jump would be %d); on the server the travel took %.2f s against %.1f; the RIO's own handle showed 68 degrees before the RIO touched it: %s"
			% [FULL, steps.size(), jump, FULL, seconds, TRAVEL_SECONDS, handle_moved])


## THE RIO'S HAND, SEEN FROM THE PILOT'S MACHINE -- a seat that does not fly, on a channel the server takes from it -- and
## the pilot's handle moved to match.
func _the_rios_hand_sweeps_the_wings_the_pilot_sees(host: Array, said: String) -> void:
	var back: Array = _travel(host, FULL, RIO_ASK)
	var steps: Dictionary = {}
	for row in back:
		steps[int(row["sweep"])] = true
	var before_last: String = said.substr(0, said.rfind("SWEEP seat 0 asks"))
	var handle_moved: bool = false
	for row in _wings(before_last):
		if absf(float(row["handle"]) - 30.0) < 0.6:
			handle_moved = true
	_check("the_rios_hand_sweeps_the_wings_the_pilot_sees_and_moves_the_pilots_handle",
		back.size() > 1 and steps.size() >= 30 and handle_moved,
		"on the pilot's machine the wings came from %d back to %d through %d different values; the pilot's handle showed 30 degrees without the pilot touching it: %s"
			% [FULL, RIO_ASK, steps.size(), handle_moved])


## BOTH HANDS AT ONCE, to 40 and to 60 degrees. LAST WRITE WINS: the command the server holds at the end is the last one
## a hand sent, and both machines agree on it -- the command, where the wings stopped, and where both handles stand. Which
## hand was last is a race between two machines, so the check asks that the winner is ONE OF THE TWO LET-GOS each machine
## wrote down, not which.
func _both_hands_at_once_end_with_both_machines_agreeing(host: Array, join: Array, host_said: String,
		join_said: String) -> void:
	var h: Dictionary = host[-1] if not host.is_empty() else {}
	var j: Dictionary = join[-1] if not join.is_empty() else {}
	var command: int = int(h.get("command", -1))
	var lets: Array[float] = [_last_let_go(host_said), _last_let_go(join_said)]
	var won: String = "neither"
	for index in range(2):
		if absi(command - int(round(SweepHandle.fraction_of(lets[index]) * 255.0))) <= 1:
			won = ["the pilot's", "the RIO's"][index] + " %.1f degrees" % lets[index]
	_check("both_hands_at_once_end_with_both_machines_agreeing_on_the_last_one",
		not h.is_empty() and command == int(j.get("command", -2)) and int(h.get("sweep", -1)) == command
			and int(j.get("sweep", -2)) == command and won != "neither"
			and absf(float(h.get("handle", -1.0)) - float(j.get("handle", -2.0))) < 0.6
			and absf(lets[0] - 40.0) < 1.0 and absf(lets[1] - 60.0) < 1.0,
		"the pilot let go at %.1f and the RIO at %.1f (asked 40 and 60); %s won: host command %s sweep %s handle %s drawn %s; joiner command %s sweep %s handle %s drawn %s"
			% [lets[0], lets[1], won, h.get("command"), h.get("sweep"), h.get("handle"), h.get("drawn"),
				j.get("command"), j.get("sweep"), j.get("handle"), j.get("drawn")])


## Where this machine's hand last let go of its handle, in degrees, from its own `SWEEP ... let go at` line.
static func _last_let_go(said: String) -> float:
	var at: int = said.rfind("let go at ")
	return float(said.substr(at + 10).get_slice(" ", 0)) if at >= 0 else -1.0


## THE ROWS OF ONE TRAVEL: from the last row whose wings are still at `from` once the command has left it, to the first
## whose wings have reached `to`. The command moves in steps while a hand drags the handle, so the travel starts where
## the WINGS start moving, not where the command arrives.
static func _travel(rows: Array, from: int, to: int) -> Array:
	var out: Array = []
	var start: int = -1
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		if start < 0:
			if absi(int(row["sweep"]) - from) <= 1 and int(row["command"]) != int(row["sweep"]) and signi(int(row["command"]) - from) == signi(to - from):
				start = i
			continue
		out.append(row)
		if absi(int(row["sweep"]) - to) <= 0:
			break
	if start >= 0:
		out.push_front(rows[start])
	return out if not out.is_empty() and absi(int(out[-1]["sweep"]) - to) <= 0 else []


## Every WINGS line of a log, in order: {tick, entity, command, sweep, handle, drawn}. The tick is the physics frame, at
## the 120 Hz both children run.
static func _wings(said: String) -> Array:
	var out: Array = []
	for line in said.split("\n"):
		if not line.begins_with("WINGS "):
			continue
		var row: Dictionary = {}
		for pair in line.substr(6).strip_edges().split(" ", false):
			var kv: PackedStringArray = pair.split("=")
			if kv.size() == 2:
				row[kv[0]] = kv[1]
		if row.has("sweep"):
			out.append(row)
	return out


## THE WINGS HAVE STOPPED: the last WINGS line says the sweep has reached the command.
static func _settled(said: String) -> bool:
	var rows: Array = _wings(said)
	return not rows.is_empty() and rows[-1]["sweep"] == rows[-1]["command"]


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _kill_the_children() -> void:
	for pid in _children:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_children.clear()


func _finish() -> void:
	_kill_the_children()
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
