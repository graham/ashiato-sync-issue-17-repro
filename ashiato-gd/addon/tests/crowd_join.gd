extends Node
## A player joining a busy sky keeps their seat: on the host's machine and on their own, every tick, exactly one craft
## holds them, and the joiner predicts only the craft it flies.
##
##   Godot --headless --path addon res://tests/crowd_join.tscn
##
## A server, the host's own client on peer 1 and a joiner, in one process over a carried link, beside seventy moving
## craft -- the shape of `cockpit/tests/two_peers.gd` with the socket and the second process taken out, so a timing
## that took load and luck to hit there happens here on every run.
##
## THE BUG THIS PINS (cockpit-joinfix, 2026-09-14). two_peers failed about one run in three on a busy machine: the host
## reported clients=2 pilots=1 for a whole minute. The server had the joiner seated; the host's copy of the joiner's
## craft said nobody was in it, so the host's pilot row named vehicle 0 and the world drew no one. Nothing in the
## cockpit wrote that seat. ashiato-sync's send loop released a quantized frame it had never retained whenever a
## record did not fit the budget, and a frame shared with another client (the same-frame cache) was freed while that
## client still held it as its baseline. The index was reused for another craft, and every component whose dirty
## generation matched -- Seats, which almost never changes, first of all -- was copied from the wrong entity. Measured
## before the fix, with main's libraries and with the ones from before cockpit-crewsync alike: 13 and 14 of 48 join
## timings lost the seat at the last tick, and a tick-by-tick trace had the joiner's world put itself in four craft
## at once, each of which it then predicted. The fix is tools/patches/ashiato-sync-retain-before-release.patch.
##
## EVERY TICK, NOT THE LAST ONE. The wrong seat moves between craft as baselines are acknowledged, so a single look at
## the end saw it about one time in four. Counting claims on every tick after the joiner has arrived fails on every run.
##
## WHY A CROWD. Nothing is lost unless a record fails to fit, and a joiner handed seventy-two craft at once is the
## ordinary way to fill a budget. With no crowd, 0 of 48 timings lost anything.
##
## Read RESULT=, not the exit code.

const TICK_HZ: float = 120.0
const DT: float = 1.0 / TICK_HZ
const PEER_HOST: int = 1
## The widest peer id Godot hands out is 2^31-1; this one came out of a real ENet join.
const PEER_JOIN: int = 1787759478
## Kinds, matching kKind* in cockpit_world.cpp.
const POD: int = 0
const PLANE: int = 1
const CROWD: int = 70
## One-way ticks to the joiner. The sweep lost the seat at every start on this link.
const JOIN_DELAY_TICKS: int = 8
## Ticks the host flies alone before anybody knocks, as a world build leaves it.
const HOST_ALONE_TICKS: int = 180
## Ticks watched after the joiner starts, and the part of them in which it has to have arrived.
const JOIN_TICKS: int = 720
const ARRIVAL_TICKS: int = 120
## Ticks after the joiner starts, one trial each: four phases of the host's send order.
const STARTS: Array[int] = [0, 5, 11, 29]

var server
var host
var joiner
var _failures: PackedStringArray = []
var _tick: int = 0
var _flight: Array = []
var _spawned: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[crowd_join] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("the_cockpit_module_is_built", false, "CockpitWorld not registered; build with -WithCockpit")
		_finish()
		return
	var handshook: int = 0
	var seated: int = 0
	var watched: int = 0
	var host_wrong: int = 0
	var joiner_wrong: int = 0
	var host_seat_wrong: int = 0
	var predicted_wrong: int = 0
	var worst: String = ""
	for start in STARTS:
		var trial: Dictionary = _trial(start)
		handshook += 1 if bool(trial["handshook"]) else 0
		seated += 1 if bool(trial["seated"]) else 0
		watched += int(trial["watched"])
		host_wrong += int(trial["host_wrong"])
		joiner_wrong += int(trial["joiner_wrong"])
		host_seat_wrong += int(trial["host_seat_wrong"])
		predicted_wrong += int(trial["predicted_wrong"])
		if worst == "" and String(trial["first_wrong"]) != "":
			worst = "start %d: %s" % [start, trial["first_wrong"]]
	_check("every_joiner_handshook", handshook == STARTS.size(), "%d of %d" % [handshook, STARTS.size()])
	_check("and_the_server_seated_every_one", seated == STARTS.size(), "%d of %d" % [seated, STARTS.size()])
	# THE DENOMINATOR, so a pass over no ticks cannot pass.
	_check("ticks_were_watched_after_arrival", watched >= STARTS.size() * (JOIN_TICKS - ARRIVAL_TICKS) / 2,
		"%d ticks" % watched)
	_check("on_the_host_exactly_one_craft_holds_the_joiner_every_tick", host_wrong == 0,
		"%d of %d ticks wrong; %s" % [host_wrong, watched, worst])
	_check("on_the_joiner_exactly_one_craft_holds_itself_every_tick", joiner_wrong == 0,
		"%d of %d ticks wrong; %s" % [joiner_wrong, watched, worst])
	_check("and_exactly_one_holds_the_host", host_seat_wrong == 0, "%d of %d ticks wrong" % [host_seat_wrong, watched])
	_check("the_joiner_predicts_only_the_craft_it_flies", predicted_wrong == 0,
		"%d of %d ticks predicted another craft" % [predicted_wrong, watched])
	_finish()


func _make():
	var world = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(TICK_HZ)
	return world


func _trial(start: int) -> Dictionary:
	var out: Dictionary = {"handshook": false, "seated": false, "watched": 0, "host_wrong": 0, "joiner_wrong": 0,
		"host_seat_wrong": 0, "predicted_wrong": 0, "first_wrong": ""}
	_tick = 0
	_flight.clear()
	_spawned.clear()
	server = _make()
	host = _make()
	joiner = null
	host.set_interpolation(6, true)
	server.start(0)
	host.start(PEER_HOST)
	for world in [server, host]:
		_build_world(world)
	for i in range(CROWD):
		server.spawn_vehicle(PLANE, Vector3(float(i % 10) * 60.0 - 300.0, 600.0, float(i / 10) * 60.0), 0.0,
			Vector3(70.0, 0.0, 0.0))
	_advance(HOST_ALONE_TICKS + start)
	var id_host: int = int(host.local_client_id())
	joiner = _make()
	joiner.set_interpolation(6, true)
	joiner.start(PEER_JOIN)
	_build_world(joiner)
	for i in range(JOIN_TICKS):
		_advance(1)
		var id_join: int = int(joiner.local_client_id())
		if i < ARRIVAL_TICKS or id_join == 0 or not _spawned.has(id_join):
			continue
		out["watched"] = int(out["watched"]) + 1
		var on_host: int = _claims(host, id_join).size()
		var mine: Array = _claims(joiner, id_join)
		var theirs: int = _claims(joiner, id_host).size()
		var predicted: int = 0
		for row in joiner.vehicle_states():
			if bool((row as Dictionary).get("predicted", false)) and not mine.has(int(row["entity"])):
				predicted += 1
		if on_host != 1:
			out["host_wrong"] = int(out["host_wrong"]) + 1
		if mine.size() != 1:
			out["joiner_wrong"] = int(out["joiner_wrong"]) + 1
		if theirs != 1:
			out["host_seat_wrong"] = int(out["host_seat_wrong"]) + 1
		if predicted != 0:
			out["predicted_wrong"] = int(out["predicted_wrong"]) + 1
		if String(out["first_wrong"]) == "" and (on_host != 1 or mine.size() != 1 or theirs != 1 or predicted != 0):
			out["first_wrong"] = "tick %d after the join: the host has the joiner in %d craft, the joiner itself in %d, the host in %d, and predicts %d others" % [
				i, on_host, mine.size(), theirs, predicted]
	var id_joined: int = int(joiner.local_client_id())
	out["handshook"] = id_joined != 0
	out["seated"] = _spawned.has(id_joined) and int(server.vehicle_seats(int(_spawned[id_joined]["vehicle"]))[0]) == id_joined
	for world in [server, host, joiner]:
		world.teardown()
	server = null
	host = null
	joiner = null
	return out


## Every craft in this world with the client in any seat.
func _claims(world, client_id: int) -> Array:
	var out: Array = []
	for row in world.vehicle_states():
		if (world.vehicle_seats(int(row["entity"])) as PackedInt64Array).has(client_id):
			out.append(int(row["entity"]))
	return out


func _build_world(world) -> void:
	world.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(4000.0, 2.0, 4000.0))


## As `Sim._seat_new_clients`: every client the server has accepted is given a pod before the server ticks.
func _seat_new_clients() -> void:
	for id in server.connected_clients():
		if id == 0 or _spawned.has(id):
			continue
		var slot: int = _spawned.size()
		_spawned[id] = server.spawn_pilot(id, POD, Vector3(float(slot % 4) * 14.0 - 21.0, 30.0,
			float(slot / 4) * 14.0), 0.0)


func _advance(ticks: int) -> void:
	for i in range(ticks):
		_tick += 1
		_seat_new_clients()
		server.tick(DT)
		host.tick(DT)
		if joiner != null:
			joiner.tick(DT)
		_pump()


## The host's own client is delivered at once, as `Sim._carry_packets` does; the joiner's link is slow both ways.
func _pump() -> void:
	for packet in server.take_outbound():
		var peer: int = int(packet["peer"])
		_flight.append([_tick + (JOIN_DELAY_TICKS if peer == PEER_JOIN else 0), peer, 0, packet["bytes"],
			packet["bits"]])
	for packet in host.take_outbound():
		_flight.append([_tick, 0, PEER_HOST, packet["bytes"], packet["bits"]])
	if joiner != null:
		for packet in joiner.take_outbound():
			_flight.append([_tick + JOIN_DELAY_TICKS, 0, PEER_JOIN, packet["bytes"], packet["bits"]])
	var still: Array = []
	for entry in _flight:
		if int(entry[0]) > _tick:
			still.append(entry)
			continue
		match int(entry[1]):
			0:
				server.deliver(int(entry[2]), entry[3], int(entry[4]))
			PEER_HOST:
				host.deliver(1, entry[3], int(entry[4]))
			PEER_JOIN:
				if joiner != null:
					joiner.deliver(1, entry[3], int(entry[4]))
	_flight = still


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
