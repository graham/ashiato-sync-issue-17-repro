extends Node
## Headless, two real processes over ENet: WHERE A SECOND PLAYER IS PUT on the glider level, when they join and after
## they crash -- beside somebody who is already flying, and never back at the thermal on their own.
##
##   Godot --headless --path cockpit res://tests/gliderlevel_peers.tscn
##
## The user, 2026-09-19: "Any player that joins or crashes should be respawned at the first zone at 1000 feet (or if there
## are other players, within 100 meteres of that player) so they can start over." tests/gliderlevel.gd holds the alone
## half of that rule in one process. This holds the OTHER half, which only exists with a second machine on a socket: a
## joiner arriving beside the player already up, and a crash landing its crew beside them too.
##
## THIS PROCESS IS THE HOST, because the winch is the host's (`GliderWinch`, asked by `Sim._seat_new_clients` and
## `CrewRespawn`) and the host's world is where both craft can be measured against each other without the wire's lead in
## between. The joiner is an ordinary child process, `--join=127.0.0.1:PORT --report=1`, with nothing about this suite in
## it. The crash is flown HERE, through the real W key held down, as tests/gliderlevel.gd flies its own.
##
## WHAT IS HELD:
## - the joiner is launched BESIDE this player: the winch says so by client, and the craft is first seen inside the
##   level's `beside` (100 m) of this one, at the same height, on the same heading, and at their speed or the glider's
##   cruise, whichever is greater (`GliderWinch.flying`, which is what keeps the simulation from rescuing it to 800 m);
## - and after this player flies into the ground, the fresh craft is beside the joiner in the same way -- not over the
##   first thermal, which is where it would go if the rule ignored other players.
##
## THIS CHECKOUT'S PORTS (`TestPorts`), the first free one asked silently before the child starts:
## PORTS 47920-47927, which no other suite uses (notices 47932, names_peers and sky_peers 47940).
##
## Read RESULT=, not the exit code.

const LEVEL: String = "gliders"
const FIRST_PORT: int = 47920
const PORTS: int = 8
## Seconds of WALL CLOCK for the level to stand and for the child to join: a second process on a socket is outside this
## one, and outside waits are wall-clock waits (learnings/2026-09-17, `lane/session`).
const BUILD_SECONDS: float = 90.0
const JOIN_SECONDS: float = 120.0
## And seconds of THIS PROCESS'S OWN SIMULATION for the respawn, which is `CrewRespawn.SECONDS` of simulated time and
## nothing to do with the wall clock: waited in frames. At 30 s of wall clock this went red under a loaded machine with a
## respawn that had not happened yet ("no craft (0, 8)"), which is the same trap from the other side.
## Seconds of simulation the dive is given to reach the ground, and the respawn after it.
const DIVE_SECONDS: float = 40.0
const RESPAWN_PATIENCE_S: float = CrewRespawn.SECONDS + 8.0
## How far apart, in height and in heading, two craft launched beside each other may be: a tick of sink, and a degree.
const HEIGHT_WITHIN: float = 1.0
const HEADING_WITHIN: float = 0.02
const SPEED_WITHIN: float = 1.0

var _failures: PackedStringArray = []
var _sections: int = 0
var _child: int = 0
var _port: int = 0
var _level: FlightLevel = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[gliderlevel_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if get_tree().current_scene != self:
		_run()
		return
	# HOSTING CHANGES THE SCENE, so this node watches from the root rather than being the scene that is replaced
	# (tests/no_vr_flight.gd's shape).
	var watcher := Node.new()
	watcher.name = "GliderPeersWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld missing")
		_finish()
		return
	_port = TestPorts.first_free(FIRST_PORT, PORTS)
	if _port == 0:
		_check("a_port_was_free_to_host_on", false, TestPorts.busy(FIRST_PORT, PORTS))
		_finish()
		return
	Net.choose_level(LEVEL)
	Net.host(_port)
	get_tree().change_scene_to_file("res://world/sky.tscn")
	_level = await _flying()
	_check("the_host_flies_the_glider_level", _level != null and Net.is_host and Net.level == LEVEL,
		"level %s, host %s, on %s, port %d" % [_level, Net.is_host, Net.level, _port])
	if _level == null:
		_finish()
		return
	var mine: int = _craft_of(Sim.local_client_id())
	if mine == 0:
		_check("this_player_is_flying_a_glider", false, "no craft")
		_finish()
		return
	await _a_joiner_arrives_beside_the_player_already_up()
	await _and_a_crash_puts_this_player_back_beside_them()
	_check("every_section_of_the_suite_ran", _sections == 2, "%d of 2" % _sections)
	_finish()


## ---- the join --------------------------------------------------------------------------------------------------

func _a_joiner_arrives_beside_the_player_already_up() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	var log_path: String = ProjectSettings.globalize_path(TestPorts.log_for("gliderlevel_peers", "join_%d" % _port))
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(log_path)
	_child = OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only",
		"--fixed-fps", "120", "--log-file", log_path, "--path", project, "--",
		"--join=127.0.0.1:%d" % _port, "--report=1"])
	var mine: int = _craft_of(Sim.local_client_id())
	var theirs: int = 0
	var first_seen: Dictionary = {}
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(JOIN_SECONDS * 1000.0):
		await get_tree().physics_frame
		theirs = _other_craft()
		if theirs != 0:
			first_seen = Sim.server.vehicle_state(theirs)
			break
	var launch: Dictionary = Sim.winch_launches.back() if not Sim.winch_launches.is_empty() else {}
	var ours: Dictionary = Sim.server.vehicle_state(mine) if mine != 0 else {}
	var words: String = _beside(first_seen, ours, int(launch.get("beside", -1)), Sim.local_client_id())
	_check("a_joiner_is_launched_beside_the_player_already_flying", theirs != 0 and not words.begins_with("WRONG"),
		"%.1f s after the child started: %s" % [float(Time.get_ticks_msec() - since) / 1000.0, words])
	_sections += 1


## ---- the crash -------------------------------------------------------------------------------------------------

func _and_a_crash_puts_this_player_back_beside_them() -> void:
	var wreck: int = _craft_of(Sim.local_client_id())
	var respawned_before: int = _level.respawner.respawned if _level.respawner != null else -1
	_key(KEY_W, true)
	var hz: int = Engine.physics_ticks_per_second
	var ticks: int = 0
	while ticks < int(DIVE_SECONDS * hz) and not bool((Sim.server.hull_state(wreck) as Dictionary).get("destroyed", false)):
		await get_tree().physics_frame
		ticks += 1
	_key(KEY_W, false)
	var crashed: bool = bool((Sim.server.hull_state(wreck) as Dictionary).get("destroyed", false))
	var fresh: int = 0
	var first_seen: Dictionary = {}
	var waited: int = 0
	while crashed and waited < int(RESPAWN_PATIENCE_S * float(hz)):
		await get_tree().physics_frame
		waited += 1
		var now: int = _craft_of(Sim.local_client_id())
		if now != 0 and now != wreck:
			fresh = now
			first_seen = Sim.server.vehicle_state(now)
			break
	var theirs: int = _other_craft()
	var launch: Dictionary = _level.respawner.last_launch if _level.respawner != null else {}
	var words: String = _beside(first_seen, Sim.server.vehicle_state(theirs) if theirs != 0 else {},
		int(launch.get("beside", -1)), _other_client())
	_check("and_a_crash_puts_this_player_back_beside_the_other_one",
		crashed and fresh != 0 and _level.respawner.respawned == respawned_before + 1 and not words.begins_with("WRONG"),
		"dived %.1f s, destroyed %s, back in the air %.1f s later; %s" % [float(ticks) / float(hz), crashed,
			float(waited) / float(hz), words])
	_sections += 1


## ---- what "beside" means ---------------------------------------------------------------------------------------

## WHETHER ONE CRAFT WAS PUT BESIDE ANOTHER, in words: inside the level's `beside`, at the same height, heading and
## speed, and the winch saying whose side it was put on. Words beginning "WRONG" when the rule is broken.
func _beside(fresh: Dictionary, other: Dictionary, beside_client: int, wanted_client: int) -> String:
	if fresh.is_empty() or other.is_empty():
		return "WRONG: no craft (%d, %d)" % [fresh.size(), other.size()]
	var a: Vector3 = fresh["position"]
	var b: Vector3 = other["position"]
	var apart: float = a.distance_to(b)
	var height: float = absf(a.y - b.y)
	var va: Vector3 = fresh["velocity"]
	var vb: Vector3 = other["velocity"]
	var heading: float = absf(angle_difference(atan2(-va.x, -va.z), atan2(-vb.x, -vb.z)))
	# THEIR SPEED OR THE KIND'S CRUISE, whichever is greater: see `GliderWinch.flying`.
	var speed: float = absf(va.length() - maxf(vb.length(), Terrain.cruise_for(Sim.Kind.GLIDER)))
	var room: float = float(_level.level.launch["beside"])
	var ok: bool = apart <= room and height <= HEIGHT_WITHIN and heading <= HEADING_WITHIN and speed <= SPEED_WITHIN \
		and beside_client == wanted_client and wanted_client > 0
	return ("" if ok else "WRONG: ") + "%.1f m apart (allowed %.0f), %.2f m of height, %.3f rad of heading, %.2f m/s; the winch put it beside client %d, wanted %d" % [
		apart, room, height, heading, speed, beside_client, wanted_client]


## ---- the plumbing ----------------------------------------------------------------------------------------------

func _flying() -> FlightLevel:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(BUILD_SECONDS * 1000.0):
		await get_tree().physics_frame
		var level := get_tree().current_scene as FlightLevel
		if level != null and level.ground_built_msec >= 0.0 and Sim.is_ready and Sim.server != null \
				and _craft_of(Sim.local_client_id()) != 0:
			return level
	return null


func _craft_of(client: int) -> int:
	if Sim.server == null:
		return 0
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", 0)) == client:
			return int((pilot as Dictionary).get("vehicle", 0))
	return 0


func _other_client() -> int:
	if Sim.server == null:
		return 0
	for pilot in Sim.server.pilot_states():
		var client: int = int((pilot as Dictionary).get("client", 0))
		if client != Sim.local_client_id() and client != 0:
			return client
	return 0


func _other_craft() -> int:
	var client: int = _other_client()
	return _craft_of(client) if client != 0 else 0


func _key(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


func _finish() -> void:
	if _child != 0:
		OS.kill(_child)
		_child = 0
	Sim.stop()
	Net.leave("suite over")
	Net.choose_level(ChartDrawer.DEFAULT)
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
