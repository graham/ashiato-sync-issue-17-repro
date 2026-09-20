extends Node
## Headless: A PLAYER PUT IN ANOTHER CRAFT BY THE SERVER IS STILL ONE PLAYER, FLOWN BY THEIR OWN INPUT.
##
##   Godot --headless --xr-mode off --fixed-fps 120 --path cockpit res://tests/restage.tscn
##
## Two server bugs found staging pictures for the signal lamp (learnings/2026-09-18-lightgun.md, S-1 and S-2):
##   S-1  `spawn_pilot` for a client who already has a pilot made a SECOND pilot entity. The client appeared twice in
##        `pilot_states()`, and the server flew the new craft from the old pilot's input.
##   S-2  two `spawn_vehicle` + `seat_client` in one tick: the FIRST player seated was flown from dead input.
##
## WHAT IS REAL HERE. A server and two client CockpitWorlds over the one-tick in-process link `lamp_wire` uses. Both
## clients start in pods, as a level starts them, and are moved by the server's own calls. What each check asks is
## what a player would notice: whether the craft they are in answers their input -- a command on the input frame (the
## signal lamp's channel, which the simulation keeps on the craft's bus) and the throttle axis -- and whether every
## machine sees them once.
##
## Read RESULT=, not the exit code.

const DT: float = 1.0 / 120.0
const TICK_HZ: float = 120.0
const A_PEER: int = 2
const B_PEER: int = 3
const POD: int = Sim.Kind.POD
const PLANE: int = Sim.Kind.PLANE

var _failures: PackedStringArray = []
var _server: RefCounted = null
var _a: RefCounted = null
var _b: RefCounted = null
var _tick: int = 0
var _in_flight: Array = []
## What each client's input frame says: {"throttle": float, ...} merged over `_controls()`.
var _input_a: Dictionary = {}
var _input_b: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[restage] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld is not registered")
		_finish()
		return
	SignalLamp.fit_kind(PLANE)
	_spawn_pilot_again_moves_the_player()
	_two_seated_in_one_tick_both_fly(false)
	_two_seated_in_one_tick_both_fly(true)
	_finish()


## ---- S-1 -------------------------------------------------------------------------------------

func _spawn_pilot_again_moves_the_player() -> void:
	if not _stand_up():
		return
	var a: int = int(_a.local_client_id())
	var before: int = _pilot_entity(a)
	var planes: Array = []
	for i in range(2):
		var at := Vector3(200.0 * float(i), 700.0, -300.0)
		var made: Dictionary = _server.spawn_pilot(a, PLANE, at, 0.0, Vector3(0.0, 0.0, -70.0))
		planes.append(int(made.get("vehicle", 0)))
		_advance(20)
	_advance(40)
	var on_server: int = _count_pilots(_server, a)
	var on_b: int = _count_pilots(_b, a)
	_check("s1_spawn_pilot_again_leaves_the_client_one_pilot", on_server == 1 and on_b == 1,
		"client %d has %d pilots on the server, %d on another machine (was entity %d)" % [a, on_server, on_b, before])
	_check("s1_and_it_is_the_same_pilot", _pilot_entity(a) == before,
		"pilot entity %d, was %d" % [_pilot_entity(a), before])
	var seated: int = int(_server.pilot_seat_vehicle(a)) if _server.has_method("pilot_seat_vehicle") else _seated_in(a)
	_check("s1_and_it_sits_in_the_newest_craft", seated == int(planes[1]),
		"in %d; spawned %s" % [seated, planes])
	_check("s1_and_the_newest_craft_answers_its_command", _answers_a_command(_a, a, int(planes[1]), 9),
		"lamp channel on plane %d" % int(planes[1]))
	_teardown()


## ---- S-2 -------------------------------------------------------------------------------------

func _two_seated_in_one_tick_both_fly(busy: bool) -> void:
	if not _stand_up():
		return
	# AND A WORLD LIKE A SESSION'S: the priority sphere the host hands over (`Sim._hand_over_the_sphere`), and forty
	# unmanned planes about, which is where the picture harness met S-2 and a bare world did not.
	var tag: String = "_busy" if busy else ""
	if busy:
		_server.set_priority_sphere(true, 10000.0, 4.0, 1.0, 0)
		for i in range(40):
			_server.spawn_vehicle(PLANE, Vector3(-2000.0 + 100.0 * float(i), 900.0, -2500.0), 0.0, Vector3(0.0, 0.0, -70.0))
		_advance(60)
	var a: int = int(_a.local_client_id())
	var b: int = int(_b.local_client_id())
	# AT 55 M/S, UNDER A PLANE'S FLYING SPEED, as the picture harness staged them: seated in the pilot's seat, each is
	# relaunched by `launch_if_grounded`. At 70 m/s neither was, and S-2 did not show.
	var one: int = int(_server.spawn_vehicle(PLANE, Vector3(-200.0, 700.0, -300.0), 0.0, Vector3(0.0, 0.0, -55.0)))
	var two: int = int(_server.spawn_vehicle(PLANE, Vector3(200.0, 700.0, -300.0), 0.0, Vector3(0.0, 0.0, -55.0)))
	var seated_a: bool = bool(_server.seat_client(a, one, 0))
	var seated_b: bool = bool(_server.seat_client(b, two, 0))
	_advance(60)
	_check("s2_both_are_seated" + tag, seated_a and seated_b and _seated_in(a) == one and _seated_in(b) == two,
		"a in %d (asked %d, %s), b in %d (asked %d, %s)" % [_seated_in(a), one, seated_a, _seated_in(b), two, seated_b])
	_check("s2_the_first_seated_answers_its_command" + tag, _answers_a_command(_a, a, one, 5), "client %d on plane %d" % [a, one])
	_check("s2_and_the_second_seated_too" + tag, _answers_a_command(_b, b, two, 6), "client %d on plane %d" % [b, two])
	# AND THEIR THROTTLES: one open, one shut, and the open one faster after two seconds -- the flight model's own answer.
	_input_a = {"throttle": 1.0}
	_input_b = {"throttle": 0.0}
	var speed_one: float = _speed(one)
	var speed_two: float = _speed(two)
	_advance(240)
	var gained_one: float = _speed(one) - speed_one
	var gained_two: float = _speed(two) - speed_two
	_check("s2_the_first_seated_flies_on_its_own_throttle" + tag, gained_one > gained_two + 1.0,
		"open %+.1f m/s, shut %+.1f m/s over two seconds" % [gained_one, gained_two])
	_input_a = {"throttle": 0.0}
	_input_b = {"throttle": 1.0}
	speed_one = _speed(one)
	speed_two = _speed(two)
	_advance(240)
	gained_one = _speed(one) - speed_one
	gained_two = _speed(two) - speed_two
	_check("s2_and_the_second_on_its_own" + tag, gained_two > gained_one + 1.0,
		"open %+.1f m/s, shut %+.1f m/s over two seconds" % [gained_two, gained_one])
	# AND EACH PLAYER SEES THE OTHER'S PLANE WHERE THE SERVER HAS IT. This is what the picture harness saw go wrong: the
	# server flew the first player's plane on its own throttle, and the OTHER player's copy of it dived 400 m.
	var b_sees_one: float = _their_plane_height(_b, a) - _height(_server, one)
	var a_sees_two: float = _their_plane_height(_a, b) - _height(_server, two)
	_check("s2_the_second_player_sees_the_first_players_plane_where_it_is" + tag, absf(b_sees_one) < 5.0,
		"%.1f m off the server's height" % b_sees_one)
	_check("s2_and_the_first_sees_the_seconds" + tag, absf(a_sees_two) < 5.0, "%.1f m off the server's height" % a_sees_two)
	_teardown()


## ---- asking the worlds -----------------------------------------------------------------------

## WHETHER `world`'s player makes a command land on `vehicle`'s bus on the server: the lamp channel of seat 0.
func _answers_a_command(world: RefCounted, _client: int, vehicle: int, value: int) -> bool:
	var channel: int = SignalLamp.channel_for(0)
	world.send_command(channel, value)
	_advance(20)
	return int(_server.bus_values(vehicle).get(channel, -1)) == value


func _count_pilots(world: RefCounted, client: int) -> int:
	var n: int = 0
	for state in world.pilot_states():
		if int((state as Dictionary).get("client", 0)) == client:
			n += 1
	return n


func _pilot_entity(client: int) -> int:
	for state in _server.pilot_states():
		if int((state as Dictionary).get("client", 0)) == client:
			return int((state as Dictionary).get("entity", 0))
	return 0


func _seated_in(client: int) -> int:
	for state in _server.pilot_states():
		if int((state as Dictionary).get("client", 0)) == client:
			return int((state as Dictionary).get("vehicle", 0))
	return 0


## THE HEIGHT OF `them`'s CRAFT, as `world` draws it: found through that world's own pilot states, since entity ids are
## per world.
func _their_plane_height(world: RefCounted, them: int) -> float:
	var theirs: int = 0
	for state in world.pilot_states():
		if int((state as Dictionary).get("client", 0)) == them:
			theirs = int((state as Dictionary).get("vehicle", 0))
	return _height(world, theirs) if theirs != 0 else -9999.0


func _height(world: RefCounted, vehicle: int) -> float:
	for row in world.vehicle_states():
		if int((row as Dictionary).get("entity", 0)) == vehicle:
			return ((row as Dictionary).get("position", Vector3.ZERO) as Vector3).y
	return (world.vehicle_state(vehicle).get("position", Vector3.ZERO) as Vector3).y


func _speed(vehicle: int) -> float:
	for row in _server.vehicle_states():
		if int((row as Dictionary).get("entity", 0)) == vehicle:
			return ((row as Dictionary).get("velocity", Vector3.ZERO) as Vector3).length()
	return (_server.vehicle_state(vehicle).get("velocity", Vector3.ZERO) as Vector3).length()


## ---- the worlds ----------------------------------------------------------------------------------

func _stand_up() -> bool:
	_server = ClassDB.instantiate("CockpitWorld")
	_a = ClassDB.instantiate("CockpitWorld")
	_b = ClassDB.instantiate("CockpitWorld")
	_input_a = {}
	_input_b = {}
	for world in [_server, _a, _b]:
		world.set_tick_rate(TICK_HZ)
	_server.start(0)
	_a.start(A_PEER)
	_b.start(B_PEER)
	for world in [_server, _a, _b]:
		world.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(4000.0, 2.0, 4000.0))
	_advance(90)
	var a: int = int(_a.local_client_id())
	var b: int = int(_b.local_client_id())
	if a <= 0 or b <= 0:
		_check("both_clients_handshook", false, "client ids %d and %d" % [a, b])
		_teardown()
		return false
	_server.spawn_pilot(a, POD, Vector3(30.0, 2.0, 0.0), 0.0, Vector3.ZERO)
	_server.spawn_pilot(b, POD, Vector3(-30.0, 2.0, 0.0), 0.0, Vector3.ZERO)
	_advance(60)
	return true


func _controls() -> Dictionary:
	return {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3(0.0, 1.35, 0.0), "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, 0.95, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, 0.95, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0,
	}


func _advance(ticks: int) -> void:
	for i in range(ticks):
		var mine: Dictionary = _controls()
		mine.merge(_input_a, true)
		_a.set_input(mine)
		var theirs: Dictionary = _controls()
		theirs.merge(_input_b, true)
		_b.set_input(theirs)
		_tick += 1
		_server.tick(DT)
		_a.tick(DT)
		_b.tick(DT)
		_pump()


func _pump() -> void:
	for packet in _server.take_outbound():
		_in_flight.append([_tick, int(packet["peer"]), 0, packet["bytes"], packet["bits"]])
	for packet in _a.take_outbound():
		_in_flight.append([_tick, 0, A_PEER, packet["bytes"], packet["bits"]])
	for packet in _b.take_outbound():
		_in_flight.append([_tick, 0, B_PEER, packet["bytes"], packet["bits"]])
	var still_flying: Array = []
	for entry in _in_flight:
		if int(entry[0]) > _tick:
			still_flying.append(entry)
			continue
		match int(entry[1]):
			0:
				_server.deliver(int(entry[2]), entry[3], entry[4])
			A_PEER:
				_a.deliver(0, entry[3], entry[4])
			B_PEER:
				_b.deliver(0, entry[3], entry[4])
	_in_flight = still_flying


func _teardown() -> void:
	for world in [_a, _b, _server]:
		if world != null:
			world.teardown()
	_a = null
	_b = null
	_server = null
	_in_flight.clear()


func _finish() -> void:
	_teardown()
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
