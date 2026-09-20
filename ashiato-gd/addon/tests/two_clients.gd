extends Node
## Does a SECOND player get a car?
##
##   Godot --path addon --headless res://tests/two_clients.tscn
##
## The bug this exists for: the game spawned a car only for the host's own client, so
## anyone who joined got nothing -- no car, and therefore no camera target, so they found
## themselves staring at empty track from a distance. It looks like a camera fault and is
## a spawning one, and no single-client test could have seen it.

const DT: float = 1.0 / 60.0
const DELAY: int = 4
var _flight: Array = []
var _tick: int = 0
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[two] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## Two clients on separate peer ids, which is the part that matters: the server tells them
## apart by peer, and hands each its own sync client id.
func _pump(s, clients: Array) -> void:
	for p in s.take_outbound():
		_flight.append([_tick + DELAY, int(p["peer"]), p["bytes"], p["bits"]])
	for i in range(clients.size()):
		for p in clients[i].take_outbound():
			_flight.append([_tick + DELAY, -(i + 1), p["bytes"], p["bits"]])
	var keep: Array = []
	for e in _flight:
		if e[0] > _tick:
			keep.append(e)
			continue
		if e[1] < 0:
			s.deliver(-e[1], e[2], e[3])       # client -> server, as peer 1 or 2
		elif e[1] - 1 < clients.size():
			clients[e[1] - 1].deliver(0, e[2], e[3])
		# else: addressed to a client that has since gone. A real transport drops those
		# silently; indexing past the end of this array instead took the whole delivery
		# loop down with it, and the surviving client then received nothing at all --
		# which looked exactly like the despawn failing to reach it.
	_flight = keep


## The grid, kept the way race.gd keeps it: a car for every client the server has, and
## none for any it does not.
func _reconcile(s, spawned: Dictionary, spots: Array) -> void:
	var connected: PackedInt64Array = s.connected_clients()
	for id in connected:
		if id != 0 and not spawned.has(id):
			spawned[id] = s.spawn_car(id, spots[spawned.size() % spots.size()])
	for id in spawned.keys():
		if id not in connected:
			s.despawn_car(spawned[id])
			spawned.erase(id)


func _ready() -> void:
	var s = ClassDB.instantiate("DrivingWorld")
	s.set_tracing(true)
	s.start(0)
	var a = ClassDB.instantiate("DrivingWorld")
	var b = ClassDB.instantiate("DrivingWorld")
	a.set_tracing(true)
	a.start(1)
	b.start(2)
	var clients: Array = [a, b]

	# The grid is reconciled the way the game does it: every client the server knows about
	# gets a car, at a different spawn point.
	var spawned: Dictionary = {}
	var spots: Array = [Vector3(-20, 0.5, 42), Vector3(-8, 0.5, 42), Vector3(4, 0.5, 42)]
	for i in range(600):
		_tick += 1
		_reconcile(s, spawned, spots)
		s.tick(DT)
		for c in clients:
			c.tick(DT)
		_pump(s, clients)

	_check("both_clients_connected", s.connected_clients().size() == 2,
		"server sees %d clients: %s" % [s.connected_clients().size(), s.connected_clients()])
	_check("each_client_got_a_car", spawned.size() == 2,
		"%d cars spawned for %d clients" % [spawned.size(), s.connected_clients().size()])

	# THE check. Each client must be able to find a car that belongs to IT -- that is what
	# the camera follows and what the driver steers.
	for i in range(clients.size()):
		var c = clients[i]
		var mine: int = 0
		for e in c.car_entities():
			if c.car_owner(e) == c.local_client_id():
				mine = e
		_check("client_%d_can_see_its_own_car" % (i + 1), mine != 0,
			"sync client %d owns entity %d of %d known cars" % [
				c.local_client_id(), mine, c.car_entities().size()])

	_check("clients_got_different_ids", a.local_client_id() != b.local_client_id(),
		"%d and %d" % [a.local_client_id(), b.local_client_id()])
	_check("each_sees_both_cars",
		a.car_entities().size() == 2 and b.car_entities().size() == 2,
		"%d and %d cars known" % [a.car_entities().size(), b.car_entities().size()])

	# ---- and now one of them leaves ----
	#
	# sync is handed packets and nothing else, so it never learns a socket closed. Until it
	# is told, the departed client stays in connected_clients(), the grid keeps a car for
	# it, and that car sits on the track for the rest of the race with nobody driving it.
	var leaver: int = b.local_client_id()
	# A REAL CLIENT, CONNECTED, BEFORE IT IS FORGOTTEN: "not in connected_clients()" is as true of client 0.
	var was_connected: bool = leaver > 0 and leaver in s.connected_clients()
	var leaver_car: int = spawned[leaver]
	s.remove_client(leaver)
	_check("server_forgot_the_client", was_connected and not (leaver in s.connected_clients()),
		"client %d, connected before %s; clients now %s" % [leaver, was_connected, s.connected_clients()])

	# Only client A keeps ticking; B is gone.
	for i in range(240):
		_tick += 1
		_reconcile(s, spawned, spots)
		s.tick(DT)
		a.tick(DT)
		_pump(s, [a])

	# Asked of the tracer rather than inferred from the car list, because "the client no
	# longer has that car" is also true if the client stopped receiving anything at all --
	# which is exactly what a bug in this test's own delivery loop made it look like.
	var client_saw_destroy: int = 0
	var server_sent_destroy: int = 0
	for e in s.take_trace_events():
		if str(e["type"]) == "entity_destroyed":
			server_sent_destroy += 1
	for e in a.take_trace_events():
		if str(e["type"]) == "entity_destroyed":
			client_saw_destroy += 1
	_check("the_server_announced_the_destroy", server_sent_destroy > 0,
		"%d entity_destroyed events" % server_sent_destroy)
	_check("the_other_client_applied_it", client_saw_destroy > 0,
		"%d entity_destroyed events received" % client_saw_destroy)

	_check("their_car_was_despawned", not spawned.has(leaver),
		"grid is now %s" % [spawned.keys()])
	_check("the_car_is_gone_from_the_server", not (leaver_car in s.car_entities()),
		"entity %d removed" % leaver_car)
	# THE check: the car has to disappear on the OTHER PLAYER's screen too, which is where
	# an abandoned car would actually be sitting.
	var still_there: bool = false
	for e in a.car_entities():
		if a.car_owner(e) == leaver:
			still_there = true
	_check("the_other_client_stopped_seeing_it", not still_there,
		"client A knows %d car(s)" % a.car_entities().size())

	s.teardown(); a.teardown(); b.teardown()
	print("[two] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % [_failures]))
	get_tree().quit(0 if _failures.is_empty() else 1)
