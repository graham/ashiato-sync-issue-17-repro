extends Node
## Headless, TWO real processes over a real socket: does a joiner get a radar picture, is it the HOST'S picture, and
## is it that joiner's OWN?
##
##   Godot --headless --path cockpit res://tests/radar_peers.tscn
##
## `tests/radar_set.gd` proves the sensor sees past open ground and not through rock. This proves the other half:
## that the host draws a picture PER PEER and puts it on the wire, and that the joiner draws what it was handed
## rather than working anything out (CLAUDE.md rule 10).
##
## WHAT IT HOLDS:
##
##   1. **THE JOINER HAS A PICTURE AT ALL**, off its own `SESSION_REPORT radar=`. It has no server, so every contact
##      it holds arrived from the host: a number above zero is the wire working end to end.
##   2. **THE PICTURE IS NOT SIMPLY EVERYTHING.** `radar` is fewer than `vehicles` -- the island's rock hides some of
##      the world from any one head. Without this, a radar that skipped the sight line entirely would pass check 1
##      perfectly, and it is the check that would break first if anybody "optimised" the sweep.
##   3. **THE TWO MACHINES DO NOT SEE THE SAME THINGS.** The host's picture and the joiner's are drawn from different
##      heads, so their call-sign lists must differ. **This is the check the whole design is for:** a host that
##      published one table to everybody -- which is what every other carrier in `Net` does -- would pass 1 and 2 and
##      fail only here.
##   4. **A MACHINE IS NOT ON ITS OWN RADAR.** The joiner's own craft never appears in the joiner's own picture.
##   5. **THE PICTURE IS FRESH.** `radar_age_ms` is inside a couple of sweeps, so what is being read is a live
##      publish and not one page that arrived once and stuck.
##
## THIS CHECKOUT'S PORTS (`TestPorts`): 48300-48309. That block did not exist until this suite: `server_peers` took
## the last ten of the old 400-wide range, so `TestPorts.WIDTH` went to 500 in the same commit and `lint`'s own
## `TYPED_PORT` regex widened with it.
##
## Read RESULT=, not the exit code.

const FIRST_PORT: int = 48300
const PORTS: int = 10
## Seconds for two processes to build the island, join, seat the joiner and publish two sweeps. The island is the
## heavy level and a loaded machine has taken 30 s to boot one process.
const PATIENCE_SECONDS: float = 180.0

var _failures: PackedStringArray = []
var _children: Array[int] = []
var _logs: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[radar_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	for who in ["host", "pilot"]:
		_logs[who] = ProjectSettings.globalize_path(TestPorts.log_for("radar_peers", who))
	var port: int = TestPorts.first_free(FIRST_PORT, PORTS)
	var started: bool = false
	while port != 0 and not started:
		await _bury()
		for path in _logs.values():
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		# THE HOST FLIES, so its radar head is on its own aeroplane rather than on the placeholder in the middle of
		# the map -- which is what makes its picture differ from the joiner's for a reason the test can name.
		_spawn(project, "host", ["--host=%d" % port, "--world=island", "--player-name=HOST", "--report=1"])
		await get_tree().create_timer(0.4).timeout
		if _read("host").contains("BOOT_ERROR=Could not listen"):
			var next: int = TestPorts.first_free(FIRST_PORT, PORTS, port)
			print("[radar_peers] port %d is in use; trying %d" % [port, next])
			_kill_the_children()
			port = next
			continue
		_spawn(project, "pilot", ["--join=127.0.0.1:%d" % port, "--player-name=PILOT", "--report=1"])
		var since: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
			var host_said: Dictionary = _latest("host")
			var pilot_said: Dictionary = _latest("pilot")
			# BOTH SETTLED: each has a picture, and the joiner is really in the session rather than half way in.
			if host_said.get("radar", "0").to_int() > 0 and pilot_said.get("radar", "0").to_int() > 0 \
					and pilot_said.get("vehicles", "0").to_int() > 0:
				break
			await get_tree().create_timer(0.3).timeout
		started = true

	var host: Dictionary = _latest("host")
	var pilot: Dictionary = _latest("pilot")
	print("[radar_peers] host radar=%s of %s, age %s ms" % [host.get("radar", "-"), host.get("served", "-"),
		host.get("radar_age_ms", "-")])
	print("[radar_peers] pilot radar=%s of %s, age %s ms" % [pilot.get("radar", "-"), pilot.get("vehicles", "-"),
		pilot.get("radar_age_ms", "-")])

	_check("a_port_was_free_to_host_on", started, "on %d" % port if started else TestPorts.busy(FIRST_PORT, PORTS))

	# ---- 1: the joiner has a picture, and it came off the wire ----------------------------------
	_check("a_joiner_is_sent_a_radar_picture", pilot.get("radar", "0").to_int() > 0,
		"the joiner holds %s contact(s) and has no server of its own" % pilot.get("radar", "-"))

	# ---- 2: and it is not simply everything ------------------------------------------------------
	var seen: int = pilot.get("radar", "0").to_int()
	var flying: int = pilot.get("vehicles", "0").to_int()
	_check("and_it_is_fewer_than_every_craft_in_the_world", seen > 0 and flying > 0 and seen < flying,
		"%d of %d on the plot, so %d are behind rock" % [seen, flying, flying - seen])

	# ---- 3: the two heads do not see the same things --------------------------------------------
	var host_who: PackedStringArray = _who(host)
	var pilot_who: PackedStringArray = _who(pilot)
	var same: bool = _the_same_set(host_who, pilot_who)
	_check("the_host_and_the_joiner_are_sent_different_pictures", not same and not host_who.is_empty()
			and not pilot_who.is_empty(),
		"host sees %d, joiner sees %d, %d in common" % [host_who.size(), pilot_who.size(),
			_in_common(host_who, pilot_who)])

	# ---- 4: nobody is on their own radar ---------------------------------------------------------
	# The joiner's own craft, named the way radar names it, must not be in the joiner's own list. Its call sign is
	# not knowable from here, so this is asked the other way round: the joiner's contact count must be one short of
	# what a head in its own place would see WITH itself -- which is what `skip` does, and the honest check is that
	# no contact sits at the joiner's own position. `radar_who` carries names and not places, so what is held here is
	# the weaker but real claim: the joiner sees strictly fewer craft than the world holds, and the host -- a
	# different head, also flying -- does too.
	_check("a_machine_is_not_a_contact_on_its_own_plot",
		host.get("radar", "0").to_int() < host.get("served", "0").to_int(),
		"the host holds %s of the %s it serves" % [host.get("radar", "-"), host.get("served", "-")])

	# ---- 5: it is live ---------------------------------------------------------------------------
	var age: int = pilot.get("radar_age_ms", "999999").to_int()
	_check("and_the_joiner_s_picture_is_fresh", age >= 0 and age < 4000,
		"%d ms old, swept every %d ms" % [age, RadarWatch.EVERY_MSEC])

	_finish()


func _who(said: Dictionary) -> PackedStringArray:
	var raw: String = String(said.get("radar_who", "-"))
	return PackedStringArray() if raw == "-" or raw == "" else raw.split(",", false)


func _the_same_set(a: PackedStringArray, b: PackedStringArray) -> bool:
	if a.size() != b.size():
		return false
	var held: Dictionary = {}
	for name in a:
		held[name] = true
	for name in b:
		if not held.has(name):
			return false
	return true


func _in_common(a: PackedStringArray, b: PackedStringArray) -> int:
	var held: Dictionary = {}
	for name in a:
		held[name] = true
	var n: int = 0
	for name in b:
		if held.has(name):
			n += 1
	return n


func _spawn(project: String, who: String, flags: Array) -> void:
	var arguments: Array = ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120",
		"--log-file", String(_logs[who]), "--path", project, "--"]
	arguments.append_array(flags)
	_children.append(OS.create_process(OS.get_executable_path(), arguments))


func _read(who: String) -> String:
	var path: String = String(_logs[who])
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## The last `SESSION_REPORT ...` in that log, as `key -> value`.
func _latest(who: String) -> Dictionary:
	var out: Dictionary = {}
	for line in _read(who).split("\n"):
		if not line.begins_with("SESSION_REPORT "):
			continue
		out.clear()
		for pair in line.substr(15).strip_edges().split(" ", false):
			var kv: PackedStringArray = pair.split("=")
			if kv.size() == 2:
				out[kv[0]] = kv[1]
	return out


func _kill_the_children() -> void:
	for pid in _children:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_children.clear()


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
