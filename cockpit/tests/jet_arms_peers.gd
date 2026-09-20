extends Node
## Headless, two real machines: A JET'S GUN AND MISSILE, SEEN BY SOMEBODY ELSE. A host takes an F-16 with the real key,
## arms it, fires the M61 for a second and launches a Sidewinder at a light twin on its nose, all on the pilot's own keys
## (`JetArmsHarness --arms=fire`); a joiner flies its own craft and writes down every round and missile with somebody
## else's name on it that it is handed, and how many its own shot yard and missile yard are drawing
## (`--arms=watch`). Read RESULT=, not the exit code.
##
##   Godot --headless --path cockpit res://tests/jet_arms_peers.tscn
##
## THE USER'S "SEEN BY EVERYONE": tracers, missile trails and hits through the existing paths (lane/jetarms,
## 2026-09-18). A round is a birth record every machine flies for itself (`ShotYard`), and a missile is on the wire every
## tick (`MissileYard`), so this asks the one thing a single process cannot: that the OTHER machine is handed every round
## the pilot fired, and draws them, and draws the missile.
##
## THIS CHECKOUT'S PORTS (`TestPorts`), the first free one asked silently before a child starts, from these:
## PORTS 48240-48247, which no other suite uses. The children write --log-file, for the reason two_peers gives.

const FIRST_PORT: int = 48240
const PORTS: int = 8
const PATIENCE_SECONDS: float = 150.0
## After the launch, how long the joiner is given to be handed the missile and draw it.
const AFTER_LAUNCH_SECONDS: float = 5.0

var _failures: PackedStringArray = []
var _children: Array[int] = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[jet_arms_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	var host_log: String = ProjectSettings.globalize_path(TestPorts.log_for("jet_arms_peers", "host"))
	var join_log: String = ProjectSettings.globalize_path(TestPorts.log_for("jet_arms_peers", "join"))
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
			"--world=%s" % ChartDrawer.DEFAULT, "--take-kind=falcon", "--arms=fire"]))
		_children.append(OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only",
			"--fixed-fps", "120", "--log-file", join_log, "--path", project, "--", "--join=127.0.0.1:%d" % port,
			"--arms=watch"]))
		since = Time.get_ticks_msec()
		var busy: bool = false
		var launched_at: int = -1
		while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
			host_said = _read(host_log)
			join_said = _read(join_log)
			busy = host_said.contains("BOOT_ERROR=Could not listen")
			if busy:
				break
			if host_said.contains("ARMS LAUNCHED"):
				if launched_at < 0:
					launched_at = Time.get_ticks_msec()
				if Time.get_ticks_msec() - launched_at > int(AFTER_LAUNCH_SECONDS * 1000.0):
					break
			await get_tree().create_timer(0.25).timeout
		_kill_the_children()
		if busy:
			var next: int = TestPorts.first_free(FIRST_PORT, PORTS, port)
			print("[jet_arms_peers] port %d is in use; trying %d" % [port, next])
			port = next
			continue
		started = true
	print("[jet_arms_peers] after %d ms" % (Time.get_ticks_msec() - since))
	_check("a_port_was_free_to_host_on", started, "on %d" % port if started else TestPorts.busy(FIRST_PORT, PORTS))
	var fired: int = _number(host_said, "ARMS FIRED rounds=")
	_check("the_host_took_an_f16_and_fired_its_gun_on_the_pilots_keys", host_said.contains("TOOK falcon")
		and fired >= 90, "TOOK falcon %s; %d round(s) in the second the fire key was held" % [
			host_said.contains("TOOK falcon"), fired])
	var seen: int = _number(join_said, "rounds=", true)
	var tracers: int = _number(join_said, "most_tracers=", true)
	_check("the_joiner_is_handed_every_round_and_draws_the_tracers", fired > 0 and seen >= fired and tracers >= 10,
		"%d round(s) fired, %d with the pilot's name on them handed to the joiner, at most %d drawn at once" % [
			fired, seen, tracers])
	var missile: int = _number(host_said, "ARMS LAUNCHED missile=")
	var missiles: int = _number(join_said, " missiles=", true)
	var drawn: int = _number(join_said, "most_drawn_missiles=", true)
	_check("the_host_launched_a_sidewinder_on_a_lock_and_the_joiner_draws_it", missile > 0 and missiles >= 1
		and drawn >= 1, "the host's launch: %s; the joiner was handed %d missile(s) and drew at most %d at once" % [
			_line(host_said, "ARMS LAUNCHED"), missiles, drawn])
	_finish()


## THE NUMBER AFTER `key` on the first line holding it, or on the LAST with `last`: -1 if none.
func _number(text: String, key: String, last: bool = false) -> int:
	var at: int = text.rfind(key) if last else text.find(key)
	if at < 0:
		return -1
	var digits: String = ""
	for c in text.substr(at + key.length(), 24):
		if c < "0" or c > "9":
			break
		digits += c
	return int(digits) if digits != "" else -1


func _line(text: String, key: String) -> String:
	var at: int = text.find(key)
	return text.substr(at, text.find("\n", at) - at).strip_edges() if at >= 0 else "none"


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
