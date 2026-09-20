extends Node
## A LAUNCH FROM THE SEAT IS HANDED ITS LAUNCH CUE, on the pilot's own machine -- where for a while it was not.
##
## Sync erased a cue as acknowledged when the client acknowledged a packet that had never carried it, and a pilot's own
## aeroplane in the level rides in few packets, so most cues on it died unsent. See agents.md,
## "A LAUNCH FROM THE SEAT WAS NEVER HANDED ITS LAUNCH CUE".
## Written on 2026-09-13 as a repro, it failed on ashiato ed0e3eb -- one missile from the seat, no launch cue -- and
## passes on ashiato 5e14119. Kept as the regression test for it.
##
## THE REAL ROAD FOR THE LAUNCH, THE SERVER'S FOR THE CONTROL. Master arm, the heat station and the launch are the
## desk's keys; the cues are counted off `Sim.cues` after Sim drains them, never drained here. The rail the level draws
## the seat's missile off must be the one its cue named: the pilot-list fallback puts it on the same rail, and a check
## on where it was drawn would pass with no cue at all. The control launches off the other heat rail of the same
## aeroplane once the reload allows, so a FAIL on the seat beside a PASS on the control is the seat's road, and a FAIL
## on both is a test that cannot see cues. Heat, because it needs no lock to launch.
##
## Read RESULT=, not the exit code.

const PLANE: int = Sim.Kind.PLANE

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _launch_cues: Array = []
var _end_cues: Array = []
var _missiles_seen: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[missile_cues] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## EVERY TICK, what Sim drained: the missile cues, and every missile of this client's that has been on the wire.
func _physics_process(_delta: float) -> void:
	for row in Sim.cues:
		var cue: Dictionary = row
		var what: int = int(cue.get("what", -1))
		if what == Sim.Cue.MISSILE_LAUNCH:
			_launch_cues.append(cue)
		elif what == Sim.Cue.MISSILE_END:
			_end_cues.append(cue)
	for row in Sim.missiles:
		if int((row as Dictionary).get("client", -1)) == Sim.local_client_id():
			_missiles_seen[int((row as Dictionary)["entity"])] = true


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld")
		_finish()
		return
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(240)
	var rig: PilotRig = _level.rig
	rig.ask_for_kind(PLANE)
	var view: VehicleView = null
	for i in range(900):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and view.kind == PLANE and rig.seat_index() == 0:
			break
	if view == null or view.kind != PLANE or rig.seat_index() != 0:
		_check("the_player_is_in_a_plane_at_its_pilot_seat", false, "seat %d" % rig.seat_index())
		_finish()
		return

	# ARMED, ON THE HEAT STATION, on the desk's own keys.
	await _hold("master_arm", 2)
	await _frames(60)
	var heat: int = -1
	for station in (Sim.missile_schema(PLANE).get("stations", []) as Array):
		if String((station as Dictionary).get("name", "")) == "heat":
			heat = int((station as Dictionary).get("station", -1))
	for press in range(4):
		if int(Sim.client.craft_systems(view.entity).get("weapon", -1)) == heat:
			break
		await _hold("weapon_station", 2)
		await _frames(30)
	var systems: Dictionary = Sim.client.craft_systems(view.entity)
	_check("the_seat_is_armed_on_its_heat_station",
		bool(systems.get("master", false)) and heat >= 0 and int(systems.get("weapon", -1)) == heat,
		"master %s, weapon %s, heat is station %d" % [systems.get("master"), systems.get("weapon"), heat])

	# THE SEAT'S LAUNCH: Enter held, then a second of ticks for the cue to come.
	var missiles_before: int = _missiles_seen.size()
	var known: Array = _missiles_seen.keys()
	var launches_before: int = _launch_cues.size()
	var launch_frame: int = Engine.get_physics_frames()
	await _hold("launch", 10)
	await _seconds(1.0)
	_check("a_launch_from_the_seat_is_one_missile", _missiles_seen.size() == missiles_before + 1,
		"%d new missile(s) of this client's; the seat says %s" % [_missiles_seen.size() - missiles_before,
			_seat_says()])
	_check("and_the_launching_client_is_handed_its_launch_cue", _launch_cues.size() == launches_before + 1,
		"launch key down at physics frame %d; launch cues %s; end cues so far %s" % [launch_frame,
			_launch_cues.slice(launches_before), _end_cues])
	var seat_missile: int = 0
	for entity in _missiles_seen:
		if not known.has(entity):
			seat_missile = int(entity)
	var rail: String = _level.missiles.rail_found_by(seat_missile) if _level.missiles != null else "no yard"
	_check("and_the_level_draws_it_off_the_rail_its_cue_named", rail == "cue",
		"missile %d, rail found by %s" % [seat_missile, rail if rail != "" else "nothing"])

	# THE CONTROL: the server launches off the other heat rail of the same aeroplane, once the reload allows.
	await _seconds(float(Sim.missile_type(heat).get("reload_s", 2.0)) + 0.5)
	var server_plane: int = 0
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", -1)) == Sim.local_client_id():
			server_plane = int((pilot as Dictionary).get("vehicle", 0))
	var control_before: int = _launch_cues.size()
	var missile: int = int(Sim.server.launch_missile(server_plane, heat, 0))
	await _seconds(1.0)
	_check("and_a_server_launch_from_the_same_aeroplane_is_handed_its_launch_cue",
		missile != 0 and _launch_cues.size() == control_before + 1,
		"server missile %d; launch cues %s" % [missile, _launch_cues.slice(control_before)])
	_finish()


func _seat_says() -> String:
	for row in Sim.server.lock_states():
		if int((row as Dictionary).get("client", -1)) == Sim.local_client_id():
			return String((row as Dictionary).get("why_name", "-"))
	return "-"


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += Sim.tick_dt()


## THE KEY AN ACTION IS BOUND TO, off the InputMap, pressed with both codes set.
func _hold(action: String, frames: int) -> void:
	var code: Key = KEY_NONE
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			code = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			break
	if code == KEY_NONE:
		_check("the_%s_action_is_bound_to_a_key" % action, false, "nothing bound")
		return
	_key(code, true)
	await _frames(frames)
	_key(code, false)
	await get_tree().physics_frame


func _key(code: Key, down: bool) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = down
	Input.parse_input_event(press)


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
