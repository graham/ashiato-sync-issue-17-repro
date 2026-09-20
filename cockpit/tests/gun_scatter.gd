extends Node
## Headless: a fighter's rounds do not all leave down one line (lane/gunscatter, 2026-09-19).
##
##   Godot --headless --path cockpit res://tests/gun_scatter.tscn [-- --flat]
##
## THE USER'S WORDS: "add some random distribution to the bullets coming out of the plane, not much just enough to add
## some randomness." The pilot gets into an F/A-18F, arms it and holds the fire key for a second, and every round the
## SERVER makes with this client's name on it is measured against the nose the server says the jet has:
##
## - NOT ONE LINE: the widest round is off the nose by more than half the M61's scatter, and rounds differ from each
##   other, not only from the nose;
## - NOT MUCH: no round is off by more than the scatter (2 mrad) and the wire's own rounding of a velocity;
## - THE SAME ROUND, THE SAME DICE: the hash the scatter is rolled from answers the same twice for a gun and a round
##   number, and differently for the next round and for another gun -- which is how a gunner's machine and the server
##   agree on a predicted round (`tests/shell_prediction.gd` holds the wire side of that).
##
## `-- --flat` sets every gun's scatter to 0 through `set_gun_scatter_scale`; the "not one line" check MUST then fail,
## which is how this suite is shown to be able to fail.
##
## Read RESULT=, not the exit code.

## THE F/A-18F's SCATTER, radians, typed here on purpose as the thing the table is checked AGAINST.
const SCATTER: float = 0.002
## WHAT THE WIRE ADDS: a velocity component is rounded to a quarter of a metre a second over 1,050, and the jet's pose
## may be a tick off the round's own.
const SLACK: float = 0.0008

var _failures: PackedStringArray = []
var _level: FlightLevel = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[gun_scatter] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(240):
		await get_tree().physics_frame
	if "--flat" in OS.get_cmdline_user_args():
		Sim.server.set_gun_scatter_scale(0.0)
	var rig: PilotRig = _level.rig
	rig.ask_for_kind(Sim.Kind.FIGHTER)
	var view: VehicleView = null
	for i in range(900):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and view.kind == Sim.Kind.FIGHTER and rig.seat_index() == 0:
			break
	_check("the_player_gets_into_the_fighter", view != null and view.kind == Sim.Kind.FIGHTER, "view %s" % view)
	if view == null:
		_finish()
		return
	for i in range(30):
		await get_tree().physics_frame
	var guns: Dictionary = {}
	for entry in (Sim.missile_schema(Sim.Kind.FIGHTER).get("stations", []) as Array):
		if String((entry as Dictionary).get("name", "")) == "guns":
			guns = entry
	await _select_station(view, int(guns.get("station", -1)))
	if not bool(Sim.client.craft_systems(view.entity).get("master", false)):
		await _hold("master_arm", 2)
		for i in range(30):
			await get_tree().physics_frame
	var angles: Array = await _burst()
	_check("a_second_of_the_trigger_makes_a_burst", angles.size() >= 50, "%d rounds" % angles.size())
	var widest: float = 0.0
	var mean: Vector2 = Vector2.ZERO
	for a in angles:
		widest = maxf(widest, (a as Vector2).length())
		mean += a as Vector2
	mean /= maxf(1.0, float(angles.size()))
	var spread: float = 0.0
	for a in angles:
		spread = maxf(spread, ((a as Vector2) - mean).length())
	_check("the_rounds_are_not_all_on_one_line", angles.size() >= 50 and spread > SCATTER * 0.5,
		"widest round %.2f mrad from the mean round, floor %.2f" % [spread * 1000.0, SCATTER * 500.0])
	_check("and_not_by_much", angles.size() >= 50 and widest <= SCATTER + SLACK,
		"widest %.2f mrad off the nose, ceiling %.2f" % [widest * 1000.0, (SCATTER + SLACK) * 1000.0])
	var one: Vector2 = Sim.server.scatter_dice(1234, 77)
	var same: Vector2 = Sim.server.scatter_dice(1234, 77)
	var next: Vector2 = Sim.server.scatter_dice(1234, 78)
	var other: Vector2 = Sim.server.scatter_dice(1235, 77)
	_check("the_same_round_from_the_same_gun_rolls_the_same_dice", one == same, "%s and %s" % [one, same])
	_check("the_next_round_and_another_gun_roll_others", one != next and one != other and next != other
		and one.x != other.y and one.y != other.x and one.x != next.y, "%s, %s, %s" % [one, next, other])
	_finish()


## HOLD THE FIRE KEY and read, for each new round this client fired, the angle from the server's nose in the jet's own
## across and up, in radians.
func _burst() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for row in Sim.server.shot_states():
		seen[int((row as Dictionary).get("entity", 0))] = true
	var code: Key = _key_of("fire")
	_key(code, true)
	for i in range(150):
		if i == 120:
			_key(code, false)
		await get_tree().physics_frame
		var id: int = _server_id()
		var state: Dictionary = Sim.server.vehicle_state(id) if id != 0 else {}
		if state.is_empty():
			continue
		var basis := Basis(state["basis"] as Quaternion)
		var velocity: Vector3 = state.get("velocity", Vector3.ZERO)
		for row in Sim.server.shot_states():
			var shot: Dictionary = row
			var entity: int = int(shot.get("entity", 0))
			if seen.has(entity):
				continue
			seen[entity] = true
			if int(shot.get("shooter", -1)) != Sim.local_client_id():
				continue
			var own: Vector3 = basis.inverse() * ((shot["velocity"] as Vector3) - velocity)
			out.append(Vector2(own.x, own.y) / -own.z)
	return out


func _server_id() -> int:
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", -1)) == Sim.local_client_id():
			return int((pilot as Dictionary).get("vehicle", 0))
	return 0


func _select_station(view: VehicleView, wanted: int) -> void:
	for press in range(4):
		if int(Sim.client.craft_systems(view.entity).get("weapon", -1)) == wanted:
			return
		await _hold("weapon_station", 2)
		for i in range(30):
			await get_tree().physics_frame


func _key_of(action: String) -> Key:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	_check("the_%s_action_is_bound_to_a_key" % action, false, "nothing bound")
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


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL " + ", ".join(_failures))
	get_tree().quit()
