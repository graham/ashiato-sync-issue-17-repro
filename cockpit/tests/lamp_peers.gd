extends Node
## Headless: two real processes over a real socket on the loopback, each flying its own aircraft, flash signal lamps at each
## other through the desk's own keys -- and each machine sees the other's colour, soon, on the other's lamp, pointing where
## the other is looking.
##
##   Godot --headless --path cockpit res://tests/lamp_peers.tscn
##
## ASKED FOR ON 2026-09-18: "other players in other planes need to be able to see this light gun. The idea being two
## players could use light signals to talk to each other." This is that, end to end: a key down on one machine, the rig,
## the lamp, the bus, the host, and the far machine's sky drawing the lamp from the craft's page and the pilot's pose.
##
## NO SEAT HAS A LAMP UNTIL A PLAYER PLACES ONE (lane/lampopt, 2026-09-19: "let's have the light gun (like the director
## camera) is optional, not always present and can be loaded via the ipad"). So each child PLACES its lamp first, off the
## parts bin (`--place-lamp=`, the signal "+ SIGNAL LAMP" emits), the host a second after it meets the joiner and the
## joiner two, and the joiner BINS its lamp again once its flashes are over (`--bin-lamp=`). The checks:
##   * each machine draws no lamp at the other's seat before the other placed one, and draws one within `MOST_MS` after;
##   * binned, the host takes the joiner's lamp away within `MOST_MS`.
##
## THE CHILDREN (`SignalLampHarness`): the JOINER flashes red, then green, then red again (`--flash=`); the HOST, white.
## Both run with `--lamps=1`, which writes a LAMP line for every change in any lamp that machine draws and a LAMP_KEY line
## for every key the harness pressed or let go. The checks read both logs:
##   * every one of the joiner's colours, and dark after each, appears on the host's copy of the joiner's lamp, and the
##     host's white on the joiner's copy of the host's -- each within `MOST_MS` of the key;
##   * and never two colours at once: each machine only ever shows one colour on a lamp (one value on the bus);
##   * the host's copy of the joiner's lamp is where the joiner's own is, in the joiner's seat's frame, within 2 cm, and
##     aims the same way within 2 degrees -- the desk holds it along the view, and the view is on the joiner's pilot state.
##
## RUN WITHOUT --fixed-fps, so both children's frames are the wall's and a millisecond on one is a millisecond on the
## other. Under it each process steps as fast as it can (`WingSweepHarness`).
##
## PORTS 48160-48169 of this checkout's block (`TestPorts`). The children write --log-file, as `crew_peers` explains.
##
## MEASURED (2026-09-19, loopback): a placed lamp drawn on the other machine 53 and 65 ms after it was placed, and a
## binned one gone 67 ms after; the colours at worst 71 ms (host) and 51 ms (joiner) after the key.
## MEASURED (2026-09-18, loopback, both at 120 Hz): the host saw the joiner's changes at worst 89 ms after the key (10.7
## ticks), the joiner the host's at worst 54 ms. The in-process floor is three ticks (`tests/lamp_wire.gd`); what a real
## session adds is the frames the rig and the sky wait for and the joiner's input frame arriving ahead of the server's
## tick, which is the same wait every switch and trigger in the game has. It is a round of Morse, not a twitch shot.
##
## MUTANTS, each applied alone and reverted (2026-09-18, and 2026-09-19 for the first):
##   * `PilotRig._say_whether_i_have_a_lamp` never proposing -- a placed lamp is not announced on the wire:
##       FAIL and_the_host_draws_it_within_150_ms_of_the_placing (2073 ms)
##       FAIL and_the_joiner_draws_it_within_150_ms_of_the_placing (4027 ms)
##       FAIL binned_on_the_joiner_the_host_takes_its_lamp_away_within_150_ms (binned at ..., gone never)
##     -- the far lamp still came, late, with the first flash, whose value carries `FITTED` too; nothing ever took it away.
##   * `Sky._show_their_lamp` not called -- the far machine never draws what the bus says:
##       FAIL the_host_sees_the_joiners_colours_within_150_ms (red never, dark never, green never, ...)
##       FAIL the_host_draws_the_joiners_red_lamp_where_the_joiner_holds_it (no red line on the host)
##   * `SignalLamp.apply` believing the wire over what this machine has just told it (the guard removed):
##       FAIL the_host_sees_the_joiners_colours_within_150_ms (dark never, dark never, dark never)
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 48160
const PORTS: int = 10
const PATIENCE_SECONDS: float = 90.0
## THE JOINER'S FLASHES, in seconds after it first sees the host flying, and the HOST'S.
const JOINER_FLASHES: String = "4:red:0.8,5.5:green:0.5,6.5:red:0.5"
const HOST_FLASHES: String = "5:white:0.8"
## WHEN EACH PLACES ITS LAMP, and when the joiner bins its own, on the same clock.
const HOST_PLACES: String = "1"
const JOINER_PLACES: String = "2"
const JOINER_BINS: String = "9"
## HOW LONG A FLASH MAY TAKE, key to the far machine's lamp, in milliseconds. The rig reads the key on its next physics
## frame and sends it on its next input frame; the host applies it on its next tick and sends the craft's page; the far
## machine draws it the frame after. Five 120 Hz ticks of that is ~42 ms; the rest is room for two real processes'
## frames not lining up and the joiner's input lead, and for a busy machine: 89 ms was measured under six other lanes'
## suites. What it measured is printed.
const MOST_MS: int = 150

var _failures: PackedStringArray = []
var _children: Array[int] = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[lamp_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	var host_log: String = ProjectSettings.globalize_path(TestPorts.log_for("lamp_peers", "host"))
	var join_log: String = ProjectSettings.globalize_path(TestPorts.log_for("lamp_peers", "join"))
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	var started: bool = false
	var host_said: String = ""
	var join_said: String = ""
	while port != 0 and not started:
		for path in [host_log, join_log]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		_children.append(OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only",
			"--log-file", host_log, "--path", project, "--", "--host=%d" % port, "--world=%s" % ChartDrawer.DEFAULT,
			"--lamps=1", "--place-lamp=%s" % HOST_PLACES, "--flash=%s" % HOST_FLASHES] + _passed_on()))
		_children.append(OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only",
			"--log-file", join_log, "--path", project, "--", "--join=127.0.0.1:%d" % port, "--lamps=1",
			"--place-lamp=%s" % JOINER_PLACES, "--bin-lamp=%s" % JOINER_BINS, "--flash=%s" % JOINER_FLASHES] + _passed_on()))
		var since: int = Time.get_ticks_msec()
		var busy: bool = false
		while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
			host_said = _read(host_log)
			_host_said_last = host_said
			join_said = _read(join_log)
			busy = host_said.contains("BOOT_ERROR=Could not listen")
			# DONE WHEN BOTH HAVE LET GO OF THEIR LAST KEY AND TWO SECONDS HAVE PASSED on the later one.
			var host_done: int = _last_release(host_said, HOST_FLASHES.split(",").size())
			var join_done: int = _last_release(join_said, JOINER_FLASHES.split(",").size())
			# AND THE JOINER HAS BINNED ITS LAMP, two seconds ago.
			var binned: int = _stamp(join_said, "LAMP_BINNED ")
			if busy or (host_done > 0 and join_done > 0 and binned > 0 and _now() - maxi(maxi(host_done, join_done), binned) > 2000):
				break
			await get_tree().create_timer(0.2).timeout
		_kill_the_children()
		if busy:
			var next: int = TestPorts.first_free(FIRST_PORT, PORTS, port)
			print("[lamp_peers] port %d is in use; trying %d" % [port, next])
			port = next
			continue
		started = true
	_check("a_port_was_free_to_host_on", started, "on %d" % port if started else TestPorts.busy(FIRST_PORT, PORTS))
	var host_lamps: Array = _lamps(host_said)
	var join_lamps: Array = _lamps(join_said)
	var joiner: int = _own_client(join_lamps)
	var host: int = _own_client(host_lamps)
	_check("both_machines_drew_their_own_lamp", joiner > 0 and host > 0, "joiner client %d, host client %d" % [joiner, host])
	_one_way("host_sees_the_joiners", _keys(join_said), host_lamps, joiner)
	_one_way("joiner_sees_the_hosts", _keys(host_said), join_lamps, host)
	_never_two_colours(host_lamps, "host")
	_never_two_colours(join_lamps, "joiner")
	_the_far_lamp_is_where_the_near_one_is(join_lamps, host_lamps, joiner)
	_a_lamp_appears_when_placed("host", host_said, join_said, joiner)
	_a_lamp_appears_when_placed("joiner", join_said, host_said, host)
	_a_binned_lamp_goes(host_said, join_said, joiner)
	_finish()


## ---- placed and binned --------------------------------------------------------------------------

## ON `watcher`'s MACHINE, NO LAMP AT `owner`'s SEAT BEFORE `owner` PLACED ONE, AND ONE WITHIN `MOST_MS` AFTER.
func _a_lamp_appears_when_placed(who: String, watcher_said: String, owner_said: String, owner: int) -> void:
	var placed: int = _stamp(owner_said, "LAMP_PLACED ")
	var seen: Array = _seen(watcher_said, owner)
	var early: int = 0
	var none_before: bool = false
	var arrived: int = -1
	for line in seen:
		if int(line["ms"]) < placed:
			if bool(line["present"]):
				early += 1
			else:
				none_before = true
		elif bool(line["present"]) and arrived < 0:
			arrived = int(line["ms"]) - placed
	_check("the_%s_draws_no_lamp_at_the_other_seat_until_it_is_placed" % who,
		placed > 0 and none_before and early == 0, "placed at %d, %d lamp lines before it, a none line %s" % [placed, early,
			none_before])
	_check("and_the_%s_draws_it_within_%d_ms_of_the_placing" % [who, MOST_MS], arrived >= 0 and arrived <= MOST_MS,
		"%s" % ("%d ms" % arrived if arrived >= 0 else "never"))
	print("[lamp_peers] measure: the %s drew the other's placed lamp %d ms after it was placed" % [who, arrived])


## BINNED ON THE JOINER, GONE ON THE HOST within `MOST_MS`.
func _a_binned_lamp_goes(host_said: String, join_said: String, joiner: int) -> void:
	var binned: int = _stamp(join_said, "LAMP_BINNED ")
	var gone: int = -1
	for line in _seen(host_said, joiner):
		if int(line["ms"]) >= binned and not bool(line["present"]):
			gone = int(line["ms"]) - binned
			break
	_check("binned_on_the_joiner_the_host_takes_its_lamp_away_within_%d_ms" % MOST_MS,
		binned > 0 and gone >= 0 and gone <= MOST_MS, "binned at %d, gone %s" % [binned,
			"%d ms after" % gone if gone >= 0 else "never"])


## THE WALL-CLOCK MS OF THE FIRST LINE STARTING `prefix`, or 0.
func _stamp(said: String, prefix: String) -> int:
	for line in said.split("\n"):
		if line.begins_with(prefix):
			for pair in line.split(" ", false):
				if pair.begins_with("ms="):
					return int(pair.trim_prefix("ms="))
	return 0


## EVERY `LAMP_SEEN` LINE ABOUT `client`'s SEAT, in order.
func _seen(said: String, client: int) -> Array:
	var out: Array = []
	for line in said.split("\n"):
		if not line.begins_with("LAMP_SEEN "):
			continue
		var row: Dictionary = {}
		for pair in line.substr(10).strip_edges().split(" ", false):
			var kv: PackedStringArray = pair.split("=")
			if kv.size() == 2:
				row[kv[0]] = kv[1]
		if int(row.get("client", 0)) == client:
			out.append({"ms": int(row.get("ms", 0)), "present": String(row.get("present", "0")) == "1"})
	return out


## EVERY KEY ONE MACHINE PRESSED, AND LET GO, SEEN ON THE OTHER'S COPY OF ITS LAMP within `MOST_MS`.
func _one_way(label: String, keys: Array, far: Array, owner: int) -> void:
	var worst: int = -1
	var missed: PackedStringArray = []
	for key in keys:
		var wanted: String = String(key["colour"]) if bool(key["down"]) else "dark"
		var seen: int = -1
		for line in far:
			if int(line["client"]) == owner and int(line["mine"]) == 0 and int(line["ms"]) >= int(key["ms"]) \
					and String(line["colour"]) == wanted:
				seen = int(line["ms"]) - int(key["ms"])
				break
		if seen < 0 or seen > MOST_MS:
			missed.append("%s %s" % [wanted, "never" if seen < 0 else "%d ms" % seen])
		worst = maxi(worst, seen)
	var ticks: float = float(worst) / (1000.0 / 120.0)
	print("[lamp_peers] measure: %s colours arrived at worst %d ms after the key (%.1f ticks at 120 Hz) over %d changes"
		% [label, worst, ticks, keys.size()])
	_check("the_%s_colours_within_%d_ms" % [label, MOST_MS], missed.is_empty() and keys.size() >= 2,
		"%d changes, worst %d ms" % [keys.size(), worst] if missed.is_empty() else ", ".join(missed))


## ONE COLOUR AT A TIME ON EVERY LAMP: every change a machine wrote down is one colour, never two. The bus carries one
## value per seat, so this is a check that nothing drew two lights from it -- the lens and the pips agreeing is
## `tests/signal_lamp.gd`'s.
func _never_two_colours(lines: Array, who: String) -> void:
	var bad: int = 0
	for line in lines:
		if not ["dark", "white", "red", "green"].has(String(line["colour"])):
			bad += 1
	_check("the_%s_only_ever_drew_one_colour_on_a_lamp" % who, bad == 0 and not lines.is_empty(),
		"%d changes, %d not one colour" % [lines.size(), bad])


## THE HOST'S COPY OF THE JOINER'S LAMP, WHILE RED, IS WHERE THE JOINER'S OWN IS, AND AIMS THE SAME WAY.
func _the_far_lamp_is_where_the_near_one_is(near: Array, far: Array, owner: int) -> void:
	var mine: Dictionary = {}
	var theirs: Dictionary = {}
	for line in near:
		if int(line["client"]) == owner and int(line["mine"]) == 1 and String(line["colour"]) == "red":
			mine = line
			break
	for line in far:
		if int(line["client"]) == owner and int(line["mine"]) == 0 and String(line["colour"]) == "red":
			theirs = line
			break
	if mine.is_empty() or theirs.is_empty():
		_check("the_host_draws_the_joiners_red_lamp_where_the_joiner_holds_it", false, "no red line on %s"
			% ("the joiner" if mine.is_empty() else "the host"))
		return
	var apart: float = (mine["at"] as Vector3).distance_to(theirs["at"] as Vector3)
	var turned: float = rad_to_deg((mine["aim"] as Vector3).angle_to(theirs["aim"] as Vector3))
	_check("the_host_draws_the_joiners_red_lamp_where_the_joiner_holds_it", apart < 0.02 and turned < 2.0
		and int(theirs["holder"]) == SignalLamp.DESK,
		"%.4f m and %.2f degrees apart, holder %d; the joiner's at %s aiming %s" % [apart, turned, int(theirs["holder"]),
			mine["at"], mine["aim"]])


## ---- reading the logs -----------------------------------------------------------------------------

func _lamps(said: String) -> Array:
	var out: Array = []
	for line in said.split("\n"):
		if not line.begins_with("LAMP ms="):
			continue
		var row: Dictionary = {}
		for pair in line.substr(5).strip_edges().split(" ", false):
			var kv: PackedStringArray = pair.split("=")
			if kv.size() == 2:
				row[kv[0]] = kv[1]
		out.append({"ms": int(row.get("ms", 0)), "client": int(row.get("client", 0)), "seat": int(row.get("seat", 0)),
			"mine": int(row.get("mine", 0)), "colour": String(row.get("colour", "")), "holder": int(row.get("holder", 0)),
			"at": _vector(String(row.get("at", ""))), "aim": _vector(String(row.get("aim", "")))})
	return out


func _keys(said: String) -> Array:
	var out: Array = []
	for line in said.split("\n"):
		if not line.begins_with("LAMP_KEY "):
			continue
		var row: Dictionary = {}
		for pair in line.substr(9).strip_edges().split(" ", false):
			var kv: PackedStringArray = pair.split("=")
			if kv.size() == 2:
				row[kv[0]] = kv[1]
		out.append({"ms": int(row.get("ms", 0)), "colour": String(row.get("colour", "")),
			"down": String(row.get("down", "")) == "true"})
	return out


## When a machine let go of its `count`th key, or 0.
func _last_release(said: String, count: int) -> int:
	var ups: Array = []
	for key in _keys(said):
		if not bool(key["down"]):
			ups.append(int(key["ms"]))
	return int(ups[count - 1]) if ups.size() >= count else 0


func _own_client(lines: Array) -> int:
	for line in lines:
		if int(line["mine"]) == 1:
			return int(line["client"])
	return 0


static func _vector(text: String) -> Vector3:
	var parts: PackedStringArray = text.split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2])) if parts.size() == 3 else Vector3.ZERO


static func _now() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _kill_the_children() -> void:
	for pid in _children:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_children.clear()


func _finish() -> void:
	# THE HOST'S REFUSAL BOUND, when this run was given one to hand on: its own line, so an A/B shows it arrived.
	if not _passed_on().is_empty():
		for line in _host_said_last.split("\n"):
			if line.contains("refusal bound"):
				print("[lamp_peers] host: %s" % line.strip_edges())
	_kill_the_children()
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## The host child's log as last read, for `_finish`.
var _host_said_last: String = ""


## THIS RUN'S OWN `--refusals=N`, handed on to both children, for an A/B of the host's refusal bound. Nothing otherwise.
func _passed_on() -> Array:
	var passed: Array = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--refusals="):
			passed.append(argument)
	return passed
