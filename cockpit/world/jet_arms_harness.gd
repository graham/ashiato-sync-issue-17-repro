extends Node
class_name JetArmsHarness
## FOR A HARNESS: fire a jet's gun and launch one of its missiles with the pilot's own keys, or watch somebody else do
## it and write down what this machine sees. Added by `FlightLevel` only when `--arms=` is on the command line; a player
## never has one. `tests/jet_arms_peers.gd` runs two machines with it and reads both logs (lane/jetarms, 2026-09-18).
##
##   --arms=fire    once this machine is in a jet with a gun on its selector (`--take-kind=`, `WingSweepHarness`), and
##                  two seconds after: the master arm key, the station key until the guns are selected, the fire key
##                  held for a second; then the heat station, a light twin put on the nose (the host's server does
##                  that -- there is no key for a target), the lock key until it is LOCKED and the launch key. Every
##                  press is a key event with both codes set, as `tests/jet_arms.gd` presses them.
##                  Writes `ARMS FIRED rounds=N` (rounds with this client's name on them, as this machine received
##                  them) and `ARMS LAUNCHED missile=ID`.
##   --arms=watch   writes `ARMS SEEN` whenever what this machine sees of OTHER machines' weapons changes: how many
##                  distinct rounds it has been handed with somebody else's name on them, how many of those the shot
##                  yard is drawing right now, how many distinct missiles, and how many the missile yard is drawing.

var _sky: Node = null
var _mode: String = ""
var _started: bool = false
var _in_jet_at: int = -1
## What `watch` has seen: distinct round and missile entities, and the most drawn at once.
var _rounds: Dictionary = {}
var _missiles: Dictionary = {}
var _most_tracers: int = 0
var _most_drawn_missiles: int = 0
var _last: Array = []


static func wanted(asked: Callable) -> bool:
	return String(asked.call("arms")) != ""


func _init(sky: Node) -> void:
	_sky = sky
	name = "JetArmsHarness"
	_mode = String(FlightLevel._asked("arms"))


func _physics_process(_delta: float) -> void:
	if Sim.client == null or not Sim.is_ready:
		return
	var rig: PilotRig = _sky.get("rig") as PilotRig
	if rig == null:
		return
	if _mode == "fire" and not _started:
		var view: VehicleView = rig.vehicle_view()
		var guns: bool = false
		if view != null and rig.seat_index() == 0:
			for entry in (Sim.missile_schema(view.kind).get("stations", []) as Array):
				guns = guns or bool((entry as Dictionary).get("gun", false))
		if not guns:
			return
		if _in_jet_at < 0:
			_in_jet_at = Time.get_ticks_msec()
		if Time.get_ticks_msec() - _in_jet_at < 2000:
			return
		_started = true
		_fire(rig, view)
	if _mode == "watch":
		_watch()


func _fire(rig: PilotRig, view: VehicleView) -> void:
	var me: int = Sim.local_client_id()
	var seen: Dictionary = {}
	for row in Sim.shots:
		seen[int((row as Dictionary).get("entity", 0))] = true
	await _hold("master_arm", 3)
	await _select(view, "guns")
	var code: Key = _key_of("fire")
	_key(code, true)
	var fired: int = 0
	for i in range(180):
		if i == 120:
			_key(code, false)
		await get_tree().physics_frame
		for row in Sim.shots:
			var entity: int = int((row as Dictionary).get("entity", 0))
			if not seen.has(entity):
				seen[entity] = true
				if int((row as Dictionary).get("shooter", -1)) == me:
					fired += 1
	print("ARMS FIRED rounds=%d kind=%s" % [fired, Sim.kind_name(view.kind)])
	await _select(view, "heat")
	var target: int = _put_a_target_on_the_nose()
	print("ARMS TARGET server=%d" % target)
	for i in range(30):
		await get_tree().physics_frame
	for attempt in range(3):
		await _hold("lock", 3)
		for i in range(240):
			await get_tree().physics_frame
			if int(_my_lock().get("phase", 0)) == LockSight.Phase.LOCKED:
				break
		if int(_my_lock().get("phase", 0)) == LockSight.Phase.LOCKED:
			break
	var before: Dictionary = {}
	for row in Sim.missiles:
		before[int((row as Dictionary).get("entity", 0))] = true
	await _hold("launch", 3)
	for i in range(120):
		await get_tree().physics_frame
		for row in Sim.missiles:
			var one: Dictionary = row
			if int(one.get("client", -1)) == me and not before.has(int(one.get("entity", 0))):
				print("ARMS LAUNCHED missile=%d lock=%s" % [int(one.get("entity", 0)), _my_lock().get("phase_name", "-")])
				return
	print("ARMS LAUNCHED missile=0 lock=%s why=%s" % [_my_lock().get("phase_name", "-"), _my_lock().get("why_name", "-")])


func _watch() -> void:
	var me: int = Sim.local_client_id()
	for row in Sim.shots:
		var shot: Dictionary = row
		var shooter: int = int(shot.get("shooter", -1))
		if shooter >= 0 and shooter != me:
			_rounds[int(shot.get("entity", 0))] = true
	for row in Sim.missiles:
		var one: Dictionary = row
		if int(one.get("client", -1)) != me:
			_missiles[int(one.get("entity", 0))] = true
	var level: FlightLevel = _sky as FlightLevel
	var tracers: int = level.shots.in_the_air() if level != null and level.shots != null else -1
	var drawn: int = level.missiles.in_the_air() if level != null and level.missiles != null else -1
	_most_tracers = maxi(_most_tracers, tracers)
	_most_drawn_missiles = maxi(_most_drawn_missiles, drawn)
	var now: Array = [_rounds.size(), _most_tracers, _missiles.size(), _most_drawn_missiles]
	if now == _last:
		return
	_last = now
	print("ARMS SEEN rounds=%d most_tracers=%d missiles=%d most_drawn_missiles=%d" % now)


## ---- the pilot's keys ---------------------------------------------------------------------

func _select(view: VehicleView, wanted: String) -> void:
	var station: int = -1
	for entry in (Sim.missile_schema(view.kind).get("stations", []) as Array):
		if String((entry as Dictionary).get("name", "")) == wanted:
			station = int((entry as Dictionary).get("station", -1))
	for press in range(4):
		if int(Sim.client.craft_systems(view.entity).get("weapon", -1)) == station:
			return
		await _hold("weapon_station", 3)
		for i in range(30):
			await get_tree().physics_frame


func _my_lock() -> Dictionary:
	for row in Sim.locks:
		if int((row as Dictionary).get("client", -1)) == Sim.local_client_id():
			return row
	return {}


## A LIGHT TWIN ON THE NOSE of this client's jet, as the server has it, 900 m out and going its way: the host is the
## server, so this is the harness's setup and not the pilot's -- nobody has a key for a target.
func _put_a_target_on_the_nose() -> int:
	if Sim.server == null:
		return 0
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", -1)) != Sim.local_client_id():
			continue
		var mine: Dictionary = Sim.server.vehicle_state(int((pilot as Dictionary).get("vehicle", 0)))
		var at: Vector3 = mine.get("position", Vector3.ZERO) as Vector3
		var facing := Basis(mine.get("basis", Quaternion.IDENTITY) as Quaternion)
		var nose: Vector3 = -facing.z
		return int(Sim.server.spawn_vehicle(Sim.Kind.PLANE, at + nose * 900.0 + facing.y * 20.0,
			atan2(-nose.x, -nose.z), mine.get("velocity", Vector3.ZERO) as Vector3))
	return 0


func _key_of(action: String) -> Key:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	return KEY_NONE


func _key(code: Key, down: bool) -> void:
	if code == KEY_NONE:
		return
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = down
	Input.parse_input_event(press)


func _hold(action: String, frames: int) -> void:
	var code: Key = _key_of(action)
	_key(code, true)
	for i in range(frames):
		await get_tree().physics_frame
	_key(code, false)
	await get_tree().physics_frame
