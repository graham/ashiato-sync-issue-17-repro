extends Node
## WHO SITS WHERE IS THE SERVER'S TO SAY, ONE PLAYER TO A SEAT, AND EVERY MACHINE AGREES.
##
##   Godot --path addon --headless res://tests/crew_join.tscn
##
## A server and four clients in one process across a delayed link. A flies an aeroplane; B, C and D
## each fly a craft of their own. Then, through the input frame the clipboard's CREW page fills in
## (a player to sit with, and which of their seats):
##
##   1. every machine lists the same craft with the same crews, off the replicated Seats alone;
##   2. B and C ask for the SAME seat of A's aeroplane on the SAME server tick, and exactly one of
##      them gets it -- the lower client id, which is the rule -- while the other stays where it was
##      and is told why;
##   3. a player asks for a particular free seat and gets THAT seat, not the first free one;
##   4. a taken seat, a full craft, a seat the craft does not have, a player who is flying nothing
##      and the seat you are already in are each refused, each with its own reason, and nobody moves;
##   5. every machine shows the new seats within AGREE_TICKS of the server deciding them;
##   6. a player who leaves frees the seat on every machine, and so does one who disconnects;
##   7. a JOIN with no seat named still means the first free seat, which is what crew_cabin sends;
##   8. a player already in a craft who asks for another free seat of it moves there, and the seat they left is free,
##      on every machine;
##  10. and every press is a MENU REQUEST NUMBER, bumped once a press and on every frame (`ControlInput::menu_request`),
##      which the server acts on when it changes: over a link that bunches a client's frames in threes, over a stream
##      that stalls and lands in a lump, across a second press whose frames between were all skipped, and from a player
##      who disconnects, rejoins and presses at once, every press is acted on. A button edge lost 2 of 5 over the first and
##      5 of 5 over the second (2026-09-15), because the server applies the newest frame due and skips the rest;
##   9. and all of it in a CROWDED sky: seventy craft moving, a race for one seat, and every tick after it exactly one
##      craft holding each player on every machine.
##
## THE RULE FOR TWO PRESSES ON ONE TICK: THE LOWER CLIENT ID WINS. The server decides every JOIN after the simulation
## jobs, sorted by client id (`CockpitWorld::answer_the_joins`); which of two frames simulated on one tick arrived first
## is not something the server can see.
##
## WHY A CROWD AS WELL (cockpit-joinfix, 2026-09-15). ashiato-sync once released a quantized frame it had never retained
## when a record did not fit the send budget, and a client then copied Seats from the wrong craft -- a player in no craft,
## or in several. It needs budget pressure to show, and a quiet five-craft sky never has any. The fix is
## tools/patches/ashiato-sync-retain-before-release.patch; `crowd_join` pins the mechanism, and section 9 holds this
## suite's own seats to it. Claims are counted on EVERY tick, as `crowd_join` counts them, because a wrong seat moves.
##
## THE SAME TICK IS PROVED, NOT HOPED FOR. Two clients pressing on the same loop iteration here are
## usually simulated on the same server tick, but a client's frames are mapped onto the server's clock
## by sync, so the suite reads the server's own `join_log` and asks again until both presses land on
## one tick, printing how many tries that took.
##
## A library from before this suite has no `join_log` or `join_answer`: those checks fail and say so,
## rather than the suite stopping on a call to a method that is not there.
##
## Read RESULT=, not the exit code.

const TICK_HZ: float = 60.0
const DT: float = 1.0 / TICK_HZ
## One-way delay in ticks, as cockpit_loopback's and crew_cabin's.
const LINK_DELAY_TICKS: int = 4
## HOW LATE A MACHINE MAY SHOW A SEAT CHANGE, counted from the tick the server decided it. The
## server writes Seats on its tick, the packet lands LINK_DELAY_TICKS later and the client applies
## it on its next tick; a craft the machine PREDICTS (A's own aeroplane, on A) takes the change on
## the rollback that packet causes, which is the same tick. Two more for the order ticks run in here.
## Measured on the first run of this suite; see agents.md, "WHO SITS WHERE".
const AGREE_TICKS: int = LINK_DELAY_TICKS + 3
## How long a press is held on the frame. The server edge-detects JOIN, so two frames is one press.
const PRESS_TICKS: int = 2
## How many times the race is run again when the two presses did not land on one server tick.
const RACE_TRIES: int = 6
const PEER_A: int = 1
const PEER_B: int = 2
const PEER_C: int = 3
const PEER_D: int = 4
## The machine that rejoins, on a FRESH Godot peer id as a real transport gives one: the widest Godot hands out.
const PEER_REJOIN: int = 2147483646

## Kinds and bits, matching cockpit_world.cpp.
const POD: int = 0
const PLANE: int = 1
const USE: int = 2
const JOIN: int = 32
## Nobody, matching kNoOccupant: a client id no player has.
const NOBODY: int = 255
const SECTIONS: int = 15
## A stalled stream: a client's frames to the server sent in this many ticks from a press all land together.
const STALL_TICKS: int = 10
## Section 10's link: every client frame bound for the server is held to a tick that is a multiple of this.
const BUNCH: int = 3
## Presses of each kind in section 10.
const HOLD_TRIALS: int = 5
## Ticks a held press waits for its answer before the trial counts it unanswered.
const HOLD_PATIENCE_TICKS: int = 60
## How many moving craft fill the sky for section 9, as `crowd_join`'s seventy.
const CROWD: int = 70
## How long every machine's seats are counted in the crowd, every tick.
const CROWD_WATCH_TICKS: int = 600

var _failures: PackedStringArray = []
var _sections_ran: int = 0
var server
var client_a
var client_b
var client_c
var client_d
## The machine that disconnected and came back, on its own fresh peer. Null until section 13.
var client_rejoin = null
var _tick: int = 0
## [deliver_at_tick, target (0 is the server), from_peer, bytes, bits]
var _in_flight: Array = []
## peer -> the control overrides that client holds every tick.
var _inputs: Dictionary = {}
## Peers whose machine has gone: not ticked, not delivered to.
var _gone: Dictionary = {}
## Client frames bound for the server are held to a multiple of this many ticks. 1 is a plain link.
var _bunch_to_server: int = 1
## Client frames bound for the server sent before this tick all land on it: a stalled stream released in a lump. -1 for none.
var _stall_to_server_until: int = -1
## peer -> the menu request number that peer's frames carry, on every frame, as PilotRig's does. Bumped once per press.
var _menu_requests: Dictionary = {}
## A client id for a server-driven pilot that is nobody's machine.
var _next_spare: int = 200


func _check(label: String, ok: bool, detail: String) -> void:
	print("[crew_join] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _controls(overrides: Dictionary) -> Dictionary:
	var input: Dictionary = {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0, "trigger": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0,
	}
	for key in overrides:
		input[key] = overrides[key]
	return input


func _world_of(peer: int):
	match peer:
		PEER_A: return client_a
		PEER_B: return client_b
		PEER_C: return client_c
		PEER_D: return client_d
		PEER_REJOIN: return client_rejoin
	return null


## Every client machine this suite has started, in peer order: the four, and the rejoiner once it exists.
func _peers() -> Array:
	return [PEER_A, PEER_B, PEER_C, PEER_D] + ([PEER_REJOIN] if client_rejoin != null else [])


## Every machine still in the session, the server first.
func _machines() -> Array:
	var out: Array = [server]
	for peer in _peers():
		if not _gone.has(peer):
			out.append(_world_of(peer))
	return out


func _pump() -> void:
	for packet in server.take_outbound():
		_in_flight.append([_tick + LINK_DELAY_TICKS, int(packet["peer"]), 0, packet["bytes"], packet["bits"]])
	for peer in _peers():
		if _gone.has(peer):
			continue
		for packet in _world_of(peer).take_outbound():
			var due: int = _tick + LINK_DELAY_TICKS
			due = ((due + _bunch_to_server - 1) / _bunch_to_server) * _bunch_to_server
			if _tick < _stall_to_server_until:
				due = maxi(due, _stall_to_server_until)
			_in_flight.append([due, 0, peer, packet["bytes"], packet["bits"]])
	var still_flying: Array = []
	for entry in _in_flight:
		if int(entry[0]) > _tick:
			still_flying.append(entry)
			continue
		var target: int = int(entry[1])
		if target == 0:
			if not _gone.has(int(entry[2])):
				server.deliver(int(entry[2]), entry[3], entry[4])
			continue
		if not _gone.has(target):
			_world_of(target).deliver(0, entry[3], entry[4])
	_in_flight = still_flying


## THE GAME'S ORDER: inputs, server tick, client ticks, then every packet due carried across.
func _advance(ticks: int) -> void:
	for i in range(ticks):
		for peer in _inputs:
			if not _gone.has(peer):
				var frame: Dictionary = (_inputs[peer] as Dictionary).duplicate()
				frame["menu_request"] = int(_menu_requests.get(peer, 0))
				_world_of(peer).set_input(_controls(frame))
		_tick += 1
		server.tick(DT)
		for peer in _peers():
			if not _gone.has(peer):
				_world_of(peer).tick(DT)
		_pump()


## PRESS JOIN on these peers' frames at once: {peer: [client to sit with, seat or -1]}.
func _press_join(presses: Dictionary) -> void:
	for peer in presses:
		var ask: Array = presses[peer]
		_ask_to_join(int(peer), int(ask[0]), int(ask[1]))
	_advance(PRESS_TICKS)
	for peer in presses:
		_inputs[peer] = {}


## ONE MENU PRESS OF A JOIN on `peer`'s frames: the request number moves on by one, mod 8, and the player and seat ride beside
## it until the caller clears them. The number itself never leaves the frame.
func _ask_to_join(peer: int, client: int, seat: int) -> void:
	_menu_requests[peer] = (int(_menu_requests.get(peer, 0)) + 1) % 8
	var frame: Dictionary = {"join_wanted": client}
	if seat >= 0:
		frame["join_seat"] = seat
	_inputs[peer] = frame


## ONE MENU PRESS OF A CRAFT on `peer`'s frames, the same way.
func _ask_for_kind(peer: int, kind: int) -> void:
	_menu_requests[peer] = (int(_menu_requests.get(peer, 0)) + 1) % 8
	_inputs[peer] = {"kind_wanted": kind}


## One pilot's replicated state, by client id.
func _pilot_of(world, client_id: int) -> Dictionary:
	for pilot in world.pilot_states():
		if int(pilot["client"]) == client_id:
			return pilot
	return {}


## Who sits in A's craft, as the SERVER's four occupant ids (-1 empty).
func _seats_of_a() -> PackedInt64Array:
	return server.vehicle_seats(int(_pilot_of(server, client_a.local_client_id()).get("vehicle", 0)))


## EVERY CREWED CRAFT THIS MACHINE KNOWS, as one line: its kind and its four seats, sorted. Client ids
## mean the same on every machine and entity ids do not, so two machines that agree print the same.
## Off `vehicle_seats`, which is the replicated Seats -- exactly what the CREW page is drawn from.
func _roster(world) -> String:
	var lines: PackedStringArray = []
	for vehicle in world.vehicle_states():
		var seats: PackedInt64Array = world.vehicle_seats(int(vehicle["entity"]))
		var crewed: bool = false
		for who in seats:
			crewed = crewed or int(who) != -1
		if crewed:
			lines.append("%d:%s" % [int(vehicle["kind"]), seats])
	lines.sort()
	return " | ".join(lines)


## Ticks from now until every machine prints the server's roster, or -1 after `limit`.
func _ticks_until_every_machine_agrees(limit: int) -> int:
	for waited in range(limit + 1):
		var truth: String = _roster(server)
		var same: bool = true
		for world in _machines():
			same = same and _roster(world) == truth
		if same:
			return waited
		_advance(1)
	return -1


## What the server said to the last few JOIN presses, or [] on a library without the log.
func _log() -> Array:
	return server.join_log() if server.has_method("join_log") else []


## The server's decisions about `client` since log row `from`.
func _decisions_for(client: int, from: int) -> Array:
	var out: Array = []
	var rows: Array = _log()
	for i in range(from, rows.size()):
		if int((rows[i] as Dictionary).get("client", -1)) == client:
			out.append(rows[i])
	return out


## What this machine was last told about its own JOIN, or {} on a library without it.
func _answer(world) -> Dictionary:
	return world.join_answer() if world.has_method("join_answer") else {}


## Ticks until `world` has been told something new (its answer count moved past `before`), or -1.
func _ticks_until_told(world, before: int, limit: int) -> int:
	for waited in range(limit + 1):
		if int(_answer(world).get("count", 0)) != before:
			return waited
		_advance(1)
	return -1


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("[crew_join] CockpitWorld not registered; build with -WithCockpit")
		_failures.append("cockpit_world_is_registered")
		_finish()
		return

	server = ClassDB.instantiate("CockpitWorld")
	client_a = ClassDB.instantiate("CockpitWorld")
	client_b = ClassDB.instantiate("CockpitWorld")
	client_c = ClassDB.instantiate("CockpitWorld")
	client_d = ClassDB.instantiate("CockpitWorld")
	for world in [server, client_a, client_b, client_c, client_d]:
		world.set_tick_rate(TICK_HZ)
	_check("five_worlds_start", server.start(0) and client_a.start(PEER_A) and client_b.start(PEER_B)
		and client_c.start(PEER_C) and client_d.start(PEER_D), "a server and four clients")
	for world in [server, client_a, client_b, client_c, client_d]:
		world.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(8000.0, 2.0, 8000.0))
	_advance(90)
	var id_a: int = client_a.local_client_id()
	var id_b: int = client_b.local_client_id()
	var id_c: int = client_c.local_client_id()
	var id_d: int = client_d.local_client_id()
	_check("four_clients_handshook", server.connected_clients().size() == 4 and id_a > 0 and id_b > 0
		and id_c > 0 and id_d > 0, "server sees %s" % [server.connected_clients()])
	if server.connected_clients().size() != 4:
		_finish()
		return

	server.spawn_pilot(id_a, PLANE, Vector3(0.0, 600.0, 0.0), 0.0, Vector3(0.0, 0.0, -60.0))
	server.spawn_pilot(id_b, POD, Vector3(300.0, 30.0, 0.0), 0.0, Vector3.ZERO)
	server.spawn_pilot(id_c, POD, Vector3(-300.0, 30.0, 0.0), 0.0, Vector3.ZERO)
	server.spawn_pilot(id_d, POD, Vector3(0.0, 30.0, 300.0), 0.0, Vector3.ZERO)
	# Somewhere for a leaver to go: "take the next craft" needs a craft with a free seat.
	server.spawn_vehicle(POD, Vector3(900.0, 30.0, 900.0), 0.0)
	_inputs = {PEER_A: {"throttle": 0.8}, PEER_B: {}, PEER_C: {}, PEER_D: {}}
	_advance(60)
	print("[crew_join] clients A %d, B %d, C %d, D %d" % [id_a, id_b, id_c, id_d])

	_test_every_machine_lists_the_same_crews()
	_test_two_asking_for_one_seat_on_one_tick(id_a, id_b, id_c)
	_test_a_named_seat_is_that_seat(id_a, id_b, id_c)
	_test_a_seat_move_within_the_craft_frees_the_old_seat(id_a, id_b, id_c)
	_test_a_taken_seat_is_refused(id_a, id_b, id_d)
	_test_the_seat_you_are_in_is_refused(id_a, id_b)
	_test_a_full_craft_a_missing_seat_and_nobody_are_refused(id_a, id_d)
	_test_leaving_frees_the_seat_everywhere(id_a, id_c)
	_test_a_disconnect_frees_the_seat_everywhere(id_a, id_b)
	_test_a_join_with_no_seat_takes_the_first_free_one(id_a, id_d)
	_test_a_menu_press_survives_a_bunched_link(id_a, id_d)
	_test_a_craft_press_survives_a_stalled_stream(id_d)
	_test_a_second_press_across_a_skipped_stretch_is_acted_on(id_a, id_d)
	_test_a_player_who_rejoins_is_answered_at_once(id_a, id_b)
	_test_a_crowded_sky_keeps_every_seat_on_every_machine(id_a, id_c, id_d)
	_check("every_section_of_the_suite_ran", _sections_ran == SECTIONS, "%d of %d" % [_sections_ran, SECTIONS])
	_finish()


## ---- 1. THE LIST ----------------------------------------------------------------------------------

func _test_every_machine_lists_the_same_crews() -> void:
	_sections_ran += 1
	var waited: int = _ticks_until_every_machine_agrees(60)
	var rows: int = _roster(server).split(" | ", false).size()
	_check("every_machine_lists_four_crewed_craft_alike", waited >= 0 and rows == 4,
		"%d craft after %d ticks: server %s; A %s; D %s" % [rows, waited, _roster(server), _roster(client_a),
			_roster(client_d)])


## ---- 2. THE RACE ----------------------------------------------------------------------------------

## B AND C ASK FOR SEAT 1 OF A's AEROPLANE ON ONE SERVER TICK. Exactly one is seated; it is the lower
## client id; the other is still in its own pod and is told the seat was taken.
func _test_two_asking_for_one_seat_on_one_tick(id_a: int, id_b: int, id_c: int) -> void:
	_sections_ran += 1
	var tries: int = 0
	var same_tick: bool = false
	var b_rows: Array = []
	var c_rows: Array = []
	var pod_b: int = int(_pilot_of(server, id_b).get("vehicle", 0))
	var pod_c: int = int(_pilot_of(server, id_c).get("vehicle", 0))
	while tries < RACE_TRIES and not same_tick:
		tries += 1
		var from: int = _log().size()
		var told_b: int = int(_answer(client_b).get("count", 0))
		var told_c: int = int(_answer(client_c).get("count", 0))
		_press_join({PEER_B: [id_a, 1], PEER_C: [id_a, 1]})
		_advance(LINK_DELAY_TICKS * 2 + 4)
		b_rows = _decisions_for(id_b, from)
		c_rows = _decisions_for(id_c, from)
		same_tick = b_rows.size() == 1 and c_rows.size() == 1 \
			and int(b_rows[0].get("tick", -1)) == int(c_rows[0].get("tick", -2))
		if same_tick:
			break
		# NOT ONE TICK: put both back where they were and ask again. A library with no log never gets here twice.
		if not server.has_method("join_log"):
			break
		for pair in [[id_b, pod_b], [id_c, pod_c]]:
			if int(_pilot_of(server, int(pair[0])).get("vehicle", 0)) != int(pair[1]):
				server.seat_client(int(pair[0]), int(pair[1]), 0)
		_advance(30)
		print("[crew_join] try %d: B's presses %s, C's %s, not one tick; again" % [tries, b_rows, c_rows])
		var _unused: Array = [told_b, told_c]
	print("[crew_join] measure: both presses on one server tick after %d tries: %s" % [tries, same_tick])
	_check("both_presses_were_decided_on_one_server_tick", same_tick,
		"B %s, C %s, in %d tries" % [b_rows, c_rows, tries])

	var seats: PackedInt64Array = _seats_of_a()
	var winner: int = mini(id_b, id_c)
	var loser: int = maxi(id_b, id_c)
	var in_a: int = 0
	for who in seats:
		in_a += 1 if int(who) == id_b or int(who) == id_c else 0
	_check("exactly_one_of_them_is_seated", in_a == 1 and int(seats[1]) == winner,
		"seats %s; the lower id, %d, should hold seat 1" % [seats, winner])
	var loser_pod: int = pod_b if loser == id_b else pod_c
	_check("and_the_other_stays_in_its_own_craft", int(_pilot_of(server, loser).get("vehicle", 0)) == loser_pod,
		"client %d is in %d, its pod is %d" % [loser, int(_pilot_of(server, loser).get("vehicle", 0)), loser_pod])
	var loser_rows: Array = c_rows if loser == id_c else b_rows
	_check("and_the_server_says_the_seat_was_taken",
		loser_rows.size() == 1 and String(loser_rows[0].get("why", "")) == "seat_taken",
		"%s" % [loser_rows])
	var loser_world = client_c if loser == id_c else client_b
	var winner_world = client_b if loser == id_c else client_c
	var waited: int = _ticks_until_every_machine_agrees(AGREE_TICKS * 3)
	print("[crew_join] measure: every machine showed the race's seats %d ticks after the answer window" % waited)
	_check("every_machine_shows_one_player_in_the_seat", waited >= 0 and waited <= AGREE_TICKS,
		"%d ticks, allowed %d: A %s" % [waited, AGREE_TICKS, _roster(client_a)])
	_check("and_the_refused_player_is_told_why_on_its_own_machine",
		String(_answer(loser_world).get("why", "")) == "seat_taken",
		"it holds %s" % [_answer(loser_world)])
	_check("and_the_winner_is_told_it_is_in", String(_answer(winner_world).get("why", "")) == "joined",
		"it holds %s" % [_answer(winner_world)])


## ---- 3. A NAMED SEAT ------------------------------------------------------------------------------

## THE LOSER ASKS FOR SEAT 3 while seat 2 is free, and gets 3. The old path would have put it in 2.
func _test_a_named_seat_is_that_seat(id_a: int, id_b: int, id_c: int) -> void:
	_sections_ran += 1
	var loser: int = maxi(id_b, id_c)
	var peer: int = PEER_C if loser == id_c else PEER_B
	var from: int = _log().size()
	_press_join({peer: [id_a, 3]})
	_advance(LINK_DELAY_TICKS * 2 + 4)
	var seats: PackedInt64Array = _seats_of_a()
	_check("a_named_free_seat_is_the_seat_you_get", int(seats[3]) == loser and int(seats[2]) == -1,
		"seats %s, asked seat 3 for %d; server said %s" % [seats, loser, _decisions_for(loser, from)])
	var waited: int = _ticks_until_every_machine_agrees(AGREE_TICKS * 3)
	_check("and_every_machine_shows_it", waited >= 0 and waited <= AGREE_TICKS, "%d ticks" % waited)


## ---- 3b. A MOVE WITHIN THE CRAFT --------------------------------------------------------------------

## THE PLAYER IN SEAT 4 ASKS FOR SEAT 3 OF THE SAME CRAFT, and moves; seat 4 is free on every machine. Then back again,
## so the sections after this one find the craft as they expect.
func _test_a_seat_move_within_the_craft_frees_the_old_seat(id_a: int, id_b: int, id_c: int) -> void:
	_sections_ran += 1
	var mover: int = int(_seats_of_a()[3])
	var peer: int = PEER_C if mover == id_c else PEER_B
	var world = client_c if mover == id_c else client_b
	var told: int = int(_answer(world).get("count", 0))
	_press_join({peer: [id_a, 2]})
	var answered: int = _ticks_until_told(world, told, LINK_DELAY_TICKS * 3 + 6)
	var moved: PackedInt64Array = _seats_of_a()
	var waited: int = _ticks_until_every_machine_agrees(AGREE_TICKS * 3)
	_check("a_player_who_asks_for_another_seat_of_their_craft_moves_there_and_frees_the_old_one",
		mover > 0 and int(moved[2]) == mover and int(moved[3]) == -1 and moved.count(mover) == 1
			and String(_answer(world).get("why", "")) == "joined",
		"client %d from seat 4 to seat 3: seats %s; told %s after %d ticks" % [mover, moved, _answer(world), answered])
	_check("and_every_machine_shows_the_old_seat_free", waited >= 0 and waited <= AGREE_TICKS,
		"%d ticks: A %s; D %s" % [waited, _roster(client_a), _roster(client_d)])
	_press_join({peer: [id_a, 3]})
	_advance(LINK_DELAY_TICKS * 2 + 4)
	_ticks_until_every_machine_agrees(AGREE_TICKS * 3)
	var _unused: int = id_b


## ---- 4. REFUSALS ----------------------------------------------------------------------------------

## D ASKS FOR SEAT 1, which the race's winner holds. Nobody moves, and D is told the seat is taken.
func _test_a_taken_seat_is_refused(id_a: int, id_b: int, id_d: int) -> void:
	_sections_ran += 1
	var before: String = _roster(server)
	var told: int = int(_answer(client_d).get("count", 0))
	_press_join({PEER_D: [id_a, 1]})
	var waited: int = _ticks_until_told(client_d, told, LINK_DELAY_TICKS * 3 + 6)
	_check("a_taken_seat_is_refused_and_nobody_moves", _roster(server) == before,
		"before %s, after %s" % [before, _roster(server)])
	_check("and_the_asker_is_told_the_seat_is_taken", String(_answer(client_d).get("why", "")) == "seat_taken",
		"told %s after %d ticks" % [_answer(client_d), waited])
	var _unused: int = id_b


## B ASKS FOR THE SEAT B IS ALREADY IN. It stays, and is told so.
func _test_the_seat_you_are_in_is_refused(id_a: int, id_b: int) -> void:
	_sections_ran += 1
	var seats: PackedInt64Array = _seats_of_a()
	var mine: int = seats.find(id_b)
	var world = client_b
	var peer: int = PEER_B
	if mine < 0:
		# C won the race instead; the check is the same with C.
		mine = seats.find(client_c.local_client_id())
		world = client_c
		peer = PEER_C
	var told: int = int(_answer(world).get("count", 0))
	var before: String = _roster(server)
	_press_join({peer: [id_a, mine]})
	var waited: int = _ticks_until_told(world, told, LINK_DELAY_TICKS * 3 + 6)
	_check("the_seat_you_are_in_is_refused_rather_than_taken_again",
		_roster(server) == before and String(_answer(world).get("why", "")) == "already_there",
		"seat %d; told %s after %d ticks; before %s, after %s" % [mine, _answer(world), waited, before,
			_roster(server)])


## A CRAFT WITH EVERY SEAT TAKEN, A SEAT THE CRAFT DOES NOT HAVE, AND A PLAYER FLYING NOTHING.
func _test_a_full_craft_a_missing_seat_and_nobody_are_refused(id_a: int, id_d: int) -> void:
	_sections_ran += 1
	# Fill A's last seat with a server-driven pilot, who is nobody's machine.
	var seats: PackedInt64Array = _seats_of_a()
	var craft: int = int(_pilot_of(server, id_a).get("vehicle", 0))
	var spare: int = _next_spare
	_next_spare += 1
	var parked: Dictionary = server.spawn_pilot(spare, POD, Vector3(600.0, 30.0, -600.0), 0.0, Vector3.ZERO)
	_advance(2)
	var empty: int = seats.find(-1)
	var filled: bool = empty >= 0 and bool(server.seat_client(spare, craft, empty))
	_advance(4)
	_check("a_is_full", filled and _seats_of_a().find(-1) < 0, "seats %s" % [_seats_of_a()])
	var pod_d: int = int(_pilot_of(server, id_d).get("vehicle", 0))
	var told: int = int(_answer(client_d).get("count", 0))
	_press_join({PEER_D: [id_a, -1]})
	var waited: int = _ticks_until_told(client_d, told, LINK_DELAY_TICKS * 3 + 6)
	_check("a_full_craft_is_refused", int(_pilot_of(server, id_d).get("vehicle", 0)) == pod_d
		and String(_answer(client_d).get("why", "")) == "full",
		"D in %d (pod %d), told %s after %d ticks" % [int(_pilot_of(server, id_d).get("vehicle", 0)), pod_d,
			_answer(client_d), waited])

	# A KIND WITH FEWER THAN FOUR SEATS, found off the shape table rather than named: asking for the seat past its last
	# is asking for a seat that is not there. (It was a car, which has four; the first run of this suite seated D in it.)
	var short_kind: int = -1
	for kind in range(int(server.kind_count())):
		var seats_here: int = int(server.kind_geometry(kind).get("seats", 4))
		if seats_here > 0 and seats_here < 4 and String(server.kind_geometry(kind).get("model_name", "")) != "fixed":
			short_kind = kind
			break
	var short_seats: int = int(server.kind_geometry(short_kind).get("seats", 4)) if short_kind >= 0 else 4
	var driver: int = _next_spare
	_next_spare += 1
	if short_kind >= 0:
		server.spawn_pilot(driver, short_kind, Vector3(-600.0, 400.0, -600.0), 0.0, Vector3(0.0, 0.0, -50.0))
	_advance(4)
	told = int(_answer(client_d).get("count", 0))
	_press_join({PEER_D: [driver, short_seats]})
	waited = _ticks_until_told(client_d, told, LINK_DELAY_TICKS * 3 + 6)
	_check("a_seat_the_craft_does_not_have_is_refused", short_kind >= 0
		and int(_pilot_of(server, id_d).get("vehicle", 0)) == pod_d
		and String(_answer(client_d).get("why", "")) == "no_such_seat",
		"%s of %d seats, asked seat index %d; told %s after %d ticks" % [
			server.kind_geometry(short_kind).get("name", "?") if short_kind >= 0 else "no kind", short_seats,
			short_seats, _answer(client_d), waited])

	# A client id with no pilot: nobody to sit with, which is also what a player who has LEFT looks like.
	told = int(_answer(client_d).get("count", 0))
	_press_join({PEER_D: [NOBODY - 1, 0]})
	waited = _ticks_until_told(client_d, told, LINK_DELAY_TICKS * 3 + 6)
	_check("a_player_who_is_not_here_is_refused", int(_pilot_of(server, id_d).get("vehicle", 0)) == pod_d
		and String(_answer(client_d).get("why", "")) == "gone",
		"told %s after %d ticks" % [_answer(client_d), waited])
	# And make room again for what follows.
	server.despawn_pilot(int(parked.get("pilot", 0)))
	_advance(4)


## ---- 5. LEAVING -----------------------------------------------------------------------------------

## C (or whoever holds seat 3) takes the next craft, and seat 3 is empty on every machine.
func _test_leaving_frees_the_seat_everywhere(id_a: int, id_c: int) -> void:
	_sections_ran += 1
	var seats: PackedInt64Array = _seats_of_a()
	var leaver: int = int(seats[3])
	var peer: int = PEER_C if leaver == id_c else PEER_B
	_inputs[peer] = {"buttons": USE}
	_advance(PRESS_TICKS)
	_inputs[peer] = {}
	var decided: int = -1
	for i in range(LINK_DELAY_TICKS * 3 + 6):
		if int(_seats_of_a()[3]) == -1:
			decided = i
			break
		_advance(1)
	var waited: int = _ticks_until_every_machine_agrees(AGREE_TICKS * 3)
	print("[crew_join] measure: a leave freed the seat on the server %d ticks after the press, everywhere %d later" % [
		decided, waited])
	_check("a_player_who_leaves_frees_the_seat_on_every_machine",
		leaver > 0 and decided >= 0 and waited >= 0 and waited <= AGREE_TICKS,
		"client %d left seat 3; server %s; A %s" % [leaver, _seats_of_a(), _roster(client_a)])
	var _unused: int = id_a


## ---- 6. DISCONNECTING -----------------------------------------------------------------------------

## THE SEAT-1 PLAYER'S MACHINE GOES, and the host does what `Sim` does when a peer leaves: the client is
## removed from sync and its pilot despawned. Seat 1 is empty on every machine left.
func _test_a_disconnect_frees_the_seat_everywhere(id_a: int, id_b: int) -> void:
	_sections_ran += 1
	var seats: PackedInt64Array = _seats_of_a()
	var leaver: int = int(seats[1])
	var peer: int = PEER_B if leaver == id_b else PEER_C
	var pilot: int = int(_pilot_of(server, leaver).get("entity", 0))
	# THE SERVER'S NUMBER FOR THE LEAVER, before and after: it has pressed, so non-zero; removed, it must read 0, or a later
	# client given this id would have its first presses matched against it.
	var has_number: bool = server.has_method("last_menu_request_of")
	var number_before: int = int(server.last_menu_request_of(leaver)) if has_number and leaver > 0 else -1
	_gone[peer] = true
	var removed: bool = leaver > 0 and bool(server.remove_client(leaver))
	var number_after: int = int(server.last_menu_request_of(leaver)) if has_number and leaver > 0 else -1
	server.despawn_pilot(pilot)
	# A REAL LEAVER, REALLY REMOVED: on the edge library this section passed with "client -1 gone", removing nobody.
	_check("a_disconnect_removes_a_real_client", leaver > 0 and removed and not server.connected_clients().has(leaver),
		"leaver %d, removed %s, still listed %s" % [leaver, removed, server.connected_clients().has(leaver)])
	_check("and_the_server_forgets_its_menu_number_the_moment_it_is_removed", has_number and number_before > 0
		and number_after == 0, "client %d: %d before, %d after (binding %s)" % [leaver, number_before, number_after,
			has_number])
	var decided: bool = int(_seats_of_a()[1]) == -1
	_advance(1)
	var waited: int = _ticks_until_every_machine_agrees(AGREE_TICKS * 3)
	print("[crew_join] measure: a disconnect freed the seat on every machine left %d ticks later" % waited)
	_check("a_player_who_disconnects_frees_the_seat_on_every_machine", removed
		and decided and waited >= 0 and waited <= AGREE_TICKS and int(_seats_of_a()[1]) == -1,
		"client %d gone; server %s; A %s; D %s" % [leaver, _seats_of_a(), _roster(client_a), _roster(client_d)])
	var _unused: int = id_a


## ---- 7. THE OLD PRESS -----------------------------------------------------------------------------

## A JOIN WITH NO SEAT NAMED is "a free seat of theirs", the first one: seat 1, now that it is free.
func _test_a_join_with_no_seat_takes_the_first_free_one(id_a: int, id_d: int) -> void:
	_sections_ran += 1
	_press_join({PEER_D: [id_a, -1]})
	_advance(LINK_DELAY_TICKS * 2 + 4)
	var seats: PackedInt64Array = _seats_of_a()
	_check("a_join_with_no_seat_named_takes_the_first_free_one", int(seats[1]) == id_d,
		"seats %s, D is %d" % [seats, id_d])
	var waited: int = _ticks_until_every_machine_agrees(AGREE_TICKS * 3)
	_check("and_every_machine_left_shows_it", waited >= 0 and waited <= AGREE_TICKS, "%d ticks" % waited)


## ---- 10. THE MENU REQUEST NUMBER, OVER A BUNCHED LINK -------------------------------------------------------------

## D, IN A's CRAFT, ASKS FOR SEAT 3, THEN 4, THEN 3... over a link that hands the server D's frames three at a time, starting
## a tick later each time so a press lands in each place of a bunch. Each press moves D's number on by one and keeps the
## seat beside it until the answer's count moves, as `PilotRig.ask_to_join` does. Every one must be answered.
func _test_a_menu_press_survives_a_bunched_link(id_a: int, id_d: int) -> void:
	_sections_ran += 1
	_bunch_to_server = BUNCH
	_advance(30)
	var answered: int = 0
	var ticks: Array = []
	for trial in range(HOLD_TRIALS):
		_advance(trial)
		var told: int = int(_answer(client_d).get("count", 0))
		_ask_to_join(PEER_D, id_a, 2 + trial % 2)
		var waited: int = _ticks_until_told(client_d, told, HOLD_PATIENCE_TICKS)
		_inputs[PEER_D] = {}
		if waited >= 0:
			answered += 1
			ticks.append(waited)
		_advance(12)
	_bunch_to_server = 1
	_advance(30)
	print("[crew_join] measure: over a link bunched in %ds, %d of %d menu presses answered, in %s ticks" % [BUNCH,
		answered, HOLD_TRIALS, ticks])
	_check("over_a_bunched_link_every_menu_press_is_answered", answered == HOLD_TRIALS,
		"%d of %d, after %s ticks" % [answered, HOLD_TRIALS, ticks])
	var _unused: int = id_d


## ---- 11. A CRAFT PRESS, OVER A STALLED STREAM ----------------------------------------------------------------------

## D ASKS FOR "A POD" AGAIN AND AGAIN, with spare pods to walk to -- and every time D's frames to the server stall for
## STALL_TICKS from the press and then land together. While nothing arrives the server repeats D's last input; when the
## lump lands it applies the newest frame due and skips the rest. The number is on the newest frame as on every other, so
## every press must move D. A one-frame button press moved D 0 times of 5 over the same stall on the edge build.
func _test_a_craft_press_survives_a_stalled_stream(id_d: int) -> void:
	_sections_ran += 1
	for i in range(4):
		server.spawn_vehicle(POD, Vector3(-900.0 - 40.0 * i, 30.0, -900.0), 0.0)
	_advance(60)
	var moved: int = 0
	var ticks: Array = []
	for trial in range(HOLD_TRIALS):
		var was: int = int(_pilot_of(server, id_d).get("vehicle", 0))
		_stall_to_server_until = _tick + STALL_TICKS
		_ask_for_kind(PEER_D, POD)
		var after: int = -1
		for i in range(HOLD_PATIENCE_TICKS):
			_advance(1)
			if int(_pilot_of(server, id_d).get("vehicle", 0)) != was:
				after = i
				break
		_inputs[PEER_D] = {}
		_stall_to_server_until = -1
		if after >= 0:
			moved += 1
			ticks.append(after)
		_advance(30)
	print("[crew_join] measure: over a stream stalled %d ticks from each press, %d of %d craft presses moved D, in %s ticks" % [
		STALL_TICKS, moved, HOLD_TRIALS, ticks])
	_check("over_a_stalled_stream_every_craft_press_moves_the_player", moved == HOLD_TRIALS,
		"%d of %d, after %s ticks" % [moved, HOLD_TRIALS, ticks])


## ---- 12. A SECOND PRESS ACROSS A SKIPPED STRETCH ---------------------------------------------------------------------

## D PRESSES JOIN, AND THREE TICKS LATER PRESSES AGAIN FOR ANOTHER SEAT, and every frame between the two -- the first press,
## the stretch where a button would have been let up, the second press's own first frame -- is in one stall. An edge needed
## the server to see the button go up and down again, which is exactly the stretch a stall skips; a number only has to be
## different from the last one the server acted on. D must end up in the second seat, told so.
func _test_a_second_press_across_a_skipped_stretch_is_acted_on(id_a: int, id_d: int) -> void:
	_sections_ran += 1
	var landed: int = 0
	var seen: Array = []
	for trial in range(HOLD_TRIALS):
		var first: int = 2 + trial % 2
		var second: int = 5 - first
		_stall_to_server_until = _tick + STALL_TICKS
		var told: int = int(_answer(client_d).get("count", 0))
		_ask_to_join(PEER_D, id_a, first)
		_advance(3)
		_ask_to_join(PEER_D, id_a, second)
		var waited: int = _ticks_until_told(client_d, told, HOLD_PATIENCE_TICKS)
		_advance(LINK_DELAY_TICKS * 2 + 4)
		_inputs[PEER_D] = {}
		_stall_to_server_until = -1
		var sits: int = _seats_of_a().find(id_d)
		seen.append("%d->%d after %d" % [first, sits, waited])
		if waited >= 0 and sits == second:
			landed += 1
		_advance(20)
	print("[crew_join] measure: a second press %d ticks after the first, both inside one stall: %d of %d landed in the second seat (%s)" % [
		3, landed, HOLD_TRIALS, seen])
	_check("a_second_press_across_a_stretch_the_server_skipped_is_still_acted_on", landed == HOLD_TRIALS,
		"%d of %d: %s" % [landed, HOLD_TRIALS, seen])


## ---- 13. A PLAYER WHO REJOINS -------------------------------------------------------------------------------------

## THE MACHINE THAT DISCONNECTED COMES BACK and presses JOIN at once, and must be answered. Its number starts again at 0,
## so its first press is 1, a change from the server's 0 for a client it has not heard from.
##
## NOT THE SAME CLIENT ID, ALMOST ALWAYS. sync hands out the next id past the last it gave and wraps to 1 only after 254
## (`find_next_available_client_id`, `next_connect_client_id_`), so a machine that leaves comes back as a new client --
## client 5 after 2 left, on 2026-09-15 -- and its id returns only some 250 connections later. That case, where a server
## still holding the old client's last number would ignore a rejoiner's first presses, is covered by `remove_client`
## erasing `last_menu_request_`, read in the code and not exercised here: a bounded suite cannot connect 250 times.
func _test_a_player_who_rejoins_is_answered_at_once(id_a: int, id_b: int) -> void:
	_sections_ran += 1
	var left: int = id_b
	# THE OLD CLIENT IS GONE FIRST, as it is when a real reconnect arrives: a new connection on the old client's own peer
	# is that client, not a rejoin -- which is how the edge-library run "came back as client 2".
	var gone_first: bool = not server.connected_clients().has(left)
	client_rejoin = ClassDB.instantiate("CockpitWorld")
	client_rejoin.set_tick_rate(TICK_HZ)
	var started: bool = client_rejoin.start(PEER_REJOIN)
	client_rejoin.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(8000.0, 2.0, 8000.0))
	_menu_requests[PEER_REJOIN] = 0
	_inputs[PEER_REJOIN] = {}
	var back: int = 0
	for i in range(240):
		_advance(1)
		back = int(client_rejoin.local_client_id())
		if back > 0:
			break
	var fresh_number: int = int(server.last_menu_request_of(back)) if server.has_method("last_menu_request_of") \
		and back > 0 else -1
	if back > 0:
		server.spawn_pilot(back, POD, Vector3(420.0, 30.0, 420.0), 0.0, Vector3.ZERO)
	for i in range(90):
		_advance(1)
		if int(_pilot_of(client_rejoin, back).get("vehicle", 0)) != 0:
			break
	_ask_to_join(PEER_REJOIN, id_a, -1)
	var waited: int = _ticks_until_told(client_rejoin, 0, HOLD_PATIENCE_TICKS * 2)
	_inputs[PEER_REJOIN] = {}
	_advance(LINK_DELAY_TICKS * 2 + 4)
	print("[crew_join] measure: the machine that left as client %d came back on a fresh peer as client %d, the server holding number %d for it; its first press, number %d, was answered after %d ticks: %s" % [
		left, back, fresh_number, int(_menu_requests.get(PEER_REJOIN, 0)), waited, _answer(client_rejoin)])
	_check("a_player_who_rejoins_and_presses_at_once_is_answered", gone_first and started and back > 0
		and fresh_number == 0 and waited >= 0,
		"old client gone first %s, started %s, client %d (was %d), server's number for it %d, answered after %d ticks: %s" % [
			gone_first, started, back, left, fresh_number, waited, _answer(client_rejoin)])


## ---- 9. A CROWDED SKY ---------------------------------------------------------------------------------------

## SEVENTY CRAFT ARRIVE MOVING, and in the same breath C and D race for one free seat of A's craft. Exactly one of them
## gets it, by the rule; then for CROWD_WATCH_TICKS, on every tick, every machine holds each of A, C and D in exactly one
## craft, and the seat the race was for in exactly one player. What it would look like without the sync fix is a player
## in no craft or in two on a client, while the server stays right.
func _test_a_crowded_sky_keeps_every_seat_on_every_machine(id_a: int, id_c: int, id_d: int) -> void:
	_sections_ran += 1
	for i in range(CROWD):
		server.spawn_vehicle(PLANE, Vector3(float(i % 10) * 60.0 - 300.0, 700.0, float(i / 10) * 60.0 + 1200.0), 0.0,
			Vector3(70.0, 0.0, 0.0))
	# C back into its own craft first, so both racers are outside A's craft.
	if _seats_of_a().has(id_c):
		_inputs[PEER_C] = {"buttons": USE}
		_advance(PRESS_TICKS)
		_inputs[PEER_C] = {}
		_advance(LINK_DELAY_TICKS * 2 + 4)
	if _seats_of_a().has(id_d):
		_inputs[PEER_D] = {"buttons": USE}
		_advance(PRESS_TICKS)
		_inputs[PEER_D] = {}
		_advance(LINK_DELAY_TICKS * 2 + 4)
	var free: int = _seats_of_a().find(-1)
	var from: int = _log().size()
	_press_join({PEER_C: [id_a, free], PEER_D: [id_a, free]})
	_advance(LINK_DELAY_TICKS * 2 + 4)
	var c_rows: Array = _decisions_for(id_c, from)
	var d_rows: Array = _decisions_for(id_d, from)
	var same_tick: bool = c_rows.size() == 1 and d_rows.size() == 1 \
		and int(c_rows[0].get("tick", -1)) == int(d_rows[0].get("tick", -2))
	var seats: PackedInt64Array = _seats_of_a()
	_check("in_a_crowd_one_of_two_racers_takes_the_seat_by_the_rule", free > 0 and int(seats[free]) == mini(id_c, id_d)
		and not seats.has(maxi(id_c, id_d)),
		"seat %d: seats %s; C %s, D %s; one tick %s" % [free + 1, seats, c_rows, d_rows, same_tick])
	var watched: int = 0
	var wrong: int = 0
	var first_wrong: String = ""
	for i in range(CROWD_WATCH_TICKS):
		_advance(1)
		watched += 1
		for world in _machines():
			for who in [id_a, id_c, id_d]:
				var held: int = _claims(world, who).size()
				if held != 1:
					wrong += 1
					if first_wrong == "":
						first_wrong = "tick %d: %s holds client %d in %d craft" % [i,
							"the server" if world == server else "client %d" % int(world.local_client_id()), who, held]
	var sent: int = _machines().size() * 3 * watched
	print("[crew_join] measure: in a sky of %d craft, %d of %d claims wrong over %d ticks on %d machines" % [
		server.vehicle_states().size(), wrong, sent, watched, _machines().size()])
	_check("and_every_tick_every_machine_holds_each_player_in_exactly_one_craft", watched == CROWD_WATCH_TICKS
		and wrong == 0 and server.vehicle_states().size() >= CROWD,
		"%d of %d claims wrong; %s" % [wrong, sent, first_wrong if first_wrong != "" else "none"])


## Every craft in this world with the client in any seat, as `crowd_join` counts them.
func _claims(world, client_id: int) -> Array:
	var out: Array = []
	for row in world.vehicle_states():
		if (world.vehicle_seats(int(row["entity"])) as PackedInt64Array).has(client_id):
			out.append(int(row["entity"]))
	return out


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
