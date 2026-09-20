extends Node
## Headless: A SESSION OF SIXTY-FOUR PLAYERS, the ninth and the sixty-fourth of whom join a craft through the real path.
##
##   Godot --headless --xr-mode off --fixed-fps 120 --path cockpit res://tests/players.tscn
##
## THE USER, 2026-09-18: "let's make the max 64 for now, i want to see how things break down at higher loads." The
## session cap went from eight to sixty-four (`Net.MAX_PLAYERS`) and a craft now holds sixty-four people
## (`kMostAboard`), and the checks team-lead asked for are "a join at player 9 and at 64 works; a 65th is refused out
## loud". The 65th is `tests/players_peers.gd`, over a real socket. This is the other two, in one process: a server
## and sixty-four client CockpitWorlds over the one-tick in-process link `many_seats` uses, every one handshaking,
## every one given a pod, and two of them -- the ninth and the sixty-fourth to arrive -- sending the input frame a
## JOIN press makes for seats 9 and 64 of a Chinook fitted with seventy-two. Every machine is then asked who is aboard.
##
## BEFORE: with eight the cap, a ninth client was never a player at all; and a craft's list of people aboard held
## sixteen, written in five bits, so a craft could not have held the sixty-four a session now has.
##
## Read RESULT=, not the exit code.

const DT: float = 1.0 / 120.0
const TICK_HZ: float = 120.0
const POD: int = 0
const CRAFT: int = Sim.Kind.CHINOOK
const CRAFT_SEATS: int = 72
const PILOT_CLIENT: int = 201
## Which arrivals join, by the order they came in, and the seat each asks for.
const JOINS: Dictionary = {9: 9, 64: 64}

var _failures: PackedStringArray = []
var _server: RefCounted = null
## peer -> world, in the order they were made.
var _clients: Dictionary = {}
var _frames: Dictionary = {}
var _tick: int = 0
var _in_flight: Array = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[players] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld is not registered")
		_finish()
		return
	_check("a_session_holds_sixty_four_players_and_a_craft_as_many_people", Net.MAX_PLAYERS == 64
		and int(Sim.seat_limits().get("most_aboard", 0)) >= Net.MAX_PLAYERS and Net.host_refusal() == "",
		"MAX_PLAYERS %d, most aboard %d" % [Net.MAX_PLAYERS, int(Sim.seat_limits().get("most_aboard", 0))])
	var cabin: Array = []
	for seat in range(CRAFT_SEATS):
		cabin.append({"position": Vector3(-1.2 + 0.8 * float(seat % 4), -0.4, -4.0 + 0.7 * float(seat / 4)), "yaw": 0.0,
			"station": "pilot" if seat == 0 else "operator"})
	var fitted: Dictionary = Sim.fit_seats(CRAFT, cabin)
	_check("the_craft_is_fitted_with_seventy_two_seats", int(fitted.get("fitted", 0)) == CRAFT_SEATS, "%s" % fitted)
	var began: int = Time.get_ticks_msec()
	var hull: int = _stand_up(Net.MAX_PLAYERS)
	if hull != 0:
		_the_ninth_and_the_sixty_fourth_join(hull)
	print("[players] %d clients stood up and joined in %.1f s of wall" % [_clients.size(),
		float(Time.get_ticks_msec() - began) / 1000.0])
	_finish()


func _finish() -> void:
	_teardown()
	Sim.fit_seats(CRAFT, [])
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


## ARRIVALS IN ORDER: client id of the n-th world made, 1-based. The server gives ids as they handshake.
func _arrival(n: int) -> RefCounted:
	return _clients.values()[n - 1]


func _the_ninth_and_the_sixty_fourth_join(hull: int) -> void:
	for n in JOINS:
		var frame: Dictionary = _frames[_clients.keys()[int(n) - 1]]
		frame["menu_request"] = 1
		frame["join_wanted"] = PILOT_CLIENT
		frame["join_seat"] = int(JOINS[n])
	_advance(40)
	for n in JOINS:
		_frames[_clients.keys()[int(n) - 1]].erase("join_wanted")
	_advance(60)
	var seats: PackedInt64Array = _server.vehicle_seats(hull)
	for n in JOINS:
		var world: RefCounted = _arrival(int(n))
		var me: int = int(world.local_client_id())
		var answer: Dictionary = world.join_answer()
		_check("player_%d_sits_in_seat_%d" % [n, JOINS[n]], seats.size() > int(JOINS[n]) and seats[int(JOINS[n])] == me
			and String(answer.get("why", "")) == "joined" and int(answer.get("seat", -1)) == int(JOINS[n]),
			"client %d; the server has %s in that seat; told '%s' %s" % [me,
				seats[int(JOINS[n])] if seats.size() > int(JOINS[n]) else "nothing", answer.get("why", "-"),
				answer.get("seat", "-")])
	# AND EVERY MACHINE SAYS SO: all sixty-four, the two aboard and the sixty-two who are not.
	var agree: int = 0
	var disagree: PackedStringArray = []
	for peer in _clients:
		var world: RefCounted = _clients[peer]
		var here: int = _local_hull(world)
		var theirs: PackedInt64Array = world.vehicle_seats(here) if here != 0 else PackedInt64Array()
		if theirs == seats:
			agree += 1
		elif disagree.size() < 4:
			disagree.append("peer %d: %s" % [peer, theirs.size()])
	_check("every_one_of_sixty_four_machines_agrees_who_is_aboard", agree == _clients.size(),
		"%d of %d agree%s" % [agree, _clients.size(), "" if disagree.is_empty() else "; " + ", ".join(disagree)])


static func _local_hull(world: RefCounted) -> int:
	for row in world.vehicle_states():
		if int(row.get("kind", -1)) == CRAFT:
			return int(row.get("entity", 0))
	return 0


func _stand_up(count: int) -> int:
	_server = ClassDB.instantiate("CockpitWorld")
	_server.set_tick_rate(TICK_HZ)
	_server.start(0)
	for i in range(count):
		var peer: int = i + 2
		var world: RefCounted = ClassDB.instantiate("CockpitWorld")
		world.set_tick_rate(TICK_HZ)
		world.start(peer)
		_clients[peer] = world
		_frames[peer] = {}
	for world in [_server] + _clients.values():
		world.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(900.0, 2.0, 900.0))
	# EVERY ONE HANDSHAKES, however long sixty-four take: by frames, since the link is this process's own.
	var waited: int = 0
	var shook: int = 0
	while waited < 1200:
		_advance(30)
		waited += 30
		shook = 0
		for world in _clients.values():
			shook += 1 if int((world as RefCounted).local_client_id()) > 0 else 0
		if shook == count:
			break
	var ids: Dictionary = {}
	for world in _clients.values():
		ids[int((world as RefCounted).local_client_id())] = true
	_check("all_sixty_four_clients_handshake_with_distinct_ids", shook == count and ids.size() == count
		and not ids.has(0), "%d of %d in %d ticks, %d distinct ids, the highest %d" % [shook, count, waited, ids.size(),
			ids.keys().max() if not ids.is_empty() else -1])
	if shook != count:
		return 0
	var made: Dictionary = _server.spawn_pilot(PILOT_CLIENT, CRAFT, Vector3(0.0, 3000.0, 0.0), 0.0, Vector3.ZERO)
	var spot: int = 0
	for world in _clients.values():
		spot += 1
		_server.spawn_pilot(int((world as RefCounted).local_client_id()), POD,
			Vector3(-400.0 + 12.0 * float(spot % 64), 4.0, 300.0 + 12.0 * float(spot / 64)), 0.0, Vector3.ZERO)
	_advance(90)
	var hull: int = int(made.get("vehicle", 0))
	_check("the_craft_is_made_and_seen_by_the_last_to_arrive", hull != 0 and _local_hull(_arrival(count)) != 0,
		"hull %d" % hull)
	return hull


func _controls(peer: int) -> Dictionary:
	var out: Dictionary = {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0,
		"join_wanted": 255, "join_seat": Sim.ANY_SEAT, "menu_request": 0,
	}
	out.merge(_frames.get(peer, {}), true)
	return out


func _advance(ticks: int) -> void:
	for i in range(ticks):
		for peer in _clients:
			(_clients[peer] as RefCounted).set_input(_controls(peer))
		_tick += 1
		_server.tick(DT)
		for peer in _clients:
			(_clients[peer] as RefCounted).tick(DT)
		_pump()


## A ONE-TICK LINK: everything sent this tick is delivered before the next.
func _pump() -> void:
	for packet in _server.take_outbound():
		_in_flight.append([_tick, int(packet["peer"]), 0, packet["bytes"], packet["bits"]])
	for from_peer in _clients:
		for packet in (_clients[from_peer] as RefCounted).take_outbound():
			_in_flight.append([_tick, 0, int(from_peer), packet["bytes"], packet["bits"]])
	var still_flying: Array = []
	for entry in _in_flight:
		if int(entry[0]) > _tick:
			still_flying.append(entry)
			continue
		if int(entry[1]) == 0:
			_server.deliver(int(entry[2]), entry[3], entry[4])
		elif _clients.has(int(entry[1])):
			(_clients[int(entry[1])] as RefCounted).deliver(0, entry[3], entry[4])
	_in_flight = still_flying


func _teardown() -> void:
	for peer in _clients:
		(_clients[peer] as RefCounted).teardown()
	_clients.clear()
	if _server != null:
		_server.teardown()
	_server = null
	_in_flight.clear()
