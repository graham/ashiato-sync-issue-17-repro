extends Node
## A named CRAFT request prefers a free vehicle, issues only when none exists, refuses
## without a clear registered place, and retires an issued vehicle after its last seat leaves.
## Three real replication clients drive the same ControlInput/menu_request path as Clipboard.
## Read RESULT=, not the process exit code.

const DT := 1.0 / 60.0
const POD := 0
const SEGWAY := 21
const PEERS := [1, 2, 3]

var server
var clients: Dictionary = {}
var inputs: Dictionary = {}
var menu: Dictionary = {}
var failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[issue] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: failures.append(label)


func _controls(extra: Dictionary) -> Dictionary:
	var out := {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0,
		"brake": 0.0, "trigger": 0.0, "buttons": 0, "head": Vector3.ZERO,
		"head_basis": Quaternion.IDENTITY, "left": Vector3(-0.2, -0.3, -0.3),
		"left_basis": Quaternion.IDENTITY, "right": Vector3(0.2, -0.3, -0.3),
		"right_basis": Quaternion.IDENTITY, "grip_left": 0.0, "grip_right": 0.0}
	for key in extra: out[key] = extra[key]
	return out


func _advance(ticks: int) -> void:
	for _i in range(ticks):
		for peer in PEERS:
			var frame: Dictionary = (inputs.get(peer, {}) as Dictionary).duplicate()
			frame["menu_request"] = int(menu.get(peer, 0))
			clients[peer].set_input(_controls(frame))
		server.tick(DT)
		for peer in PEERS: clients[peer].tick(DT)
		for packet in server.take_outbound():
			clients[int(packet["peer"])].deliver(0, packet["bytes"], packet["bits"])
		for peer in PEERS:
			for packet in clients[peer].take_outbound():
				server.deliver(peer, packet["bytes"], packet["bits"])


func _ask(peer: int, kind: int) -> void:
	menu[peer] = (int(menu.get(peer, 0)) + 1) % 8
	inputs[peer] = {"kind_wanted": kind}


func _pilot(world, client_id: int) -> Dictionary:
	for row in world.pilot_states():
		if int(row["client"]) == client_id: return row
	return {}


func _vehicles(kind: int) -> Array:
	var out: Array = []
	for row in server.vehicle_states():
		if int(row["kind"]) == kind: out.append(row)
	return out


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("cockpit_world_registered", false, "build with -WithCockpit")
		_finish(); return
	server = ClassDB.instantiate("CockpitWorld")
	server.set_tick_rate(60.0)
	_check("server_starts", server.start(0), "authoritative world")
	for peer in PEERS:
		var client = ClassDB.instantiate("CockpitWorld")
		client.set_tick_rate(60.0)
		clients[peer] = client
		inputs[peer] = {}
		menu[peer] = 0
		_check("client_%d_starts" % peer, client.start(peer), "replication client")
	_advance(90)
	var ids: Array[int] = []
	for peer in PEERS: ids.append(int(clients[peer].local_client_id()))
	_check("three_clients_handshake", ids.all(func(id: int): return id > 0), "%s" % [ids])
	for i in range(PEERS.size()):
		server.spawn_pilot(ids[i], POD, Vector3(float(i) * 30.0, 20.0, -200.0), 0.0)
	var free_segway: int = int(server.spawn_vehicle(SEGWAY, Vector3(0.0, 0.8, 0.0), 0.0))
	server.add_issue_place(SEGWAY, Vector3(100.0, 0.8, 0.0), 0.0, Vector3.ZERO)
	server.add_issue_place(SEGWAY, Vector3(120.0, 0.8, 0.0), 0.0, Vector3.ZERO)
	_advance(30)

	# Existing free craft wins and no new entity is created.
	_ask(1, SEGWAY); _advance(2); inputs[1] = {}; _advance(12)
	_check("a_free_craft_is_preferred", int(_pilot(server, ids[0]).get("vehicle", 0)) == free_segway
		and _vehicles(SEGWAY).size() == 1, "%d segway(s), A in %d" % [_vehicles(SEGWAY).size(),
		int(_pilot(server, ids[0]).get("vehicle", 0))])

	# With the only existing seat full, two same-tick presses receive two separately issued craft.
	_ask(2, SEGWAY); _ask(3, SEGWAY); _advance(2); inputs[2] = {}; inputs[3] = {}; _advance(12)
	var b_vehicle: int = int(_pilot(server, ids[1]).get("vehicle", 0))
	var c_vehicle: int = int(_pilot(server, ids[2]).get("vehicle", 0))
	_check("two_same_tick_requests_issue_two_craft", _vehicles(SEGWAY).size() == 3
		and b_vehicle != free_segway and c_vehicle != free_segway and b_vehicle != c_vehicle,
		"vehicles %s; B %d C %d" % [_vehicles(SEGWAY), b_vehicle, c_vehicle])

	# Every registered place is now occupied. A new named request is refused and counted.
	var refused_before: int = int(server.refused_boardings())
	_ask(1, SEGWAY); _advance(2); inputs[1] = {}; _advance(12)
	_check("a_blocked_issue_is_refused_and_counted", int(server.refused_boardings()) == refused_before + 1
		and int(_pilot(server, ids[0]).get("vehicle", 0)) == free_segway,
		"refusals %d, A still in %d" % [server.refused_boardings(), free_segway])

	# Moving B to a deliberately non-issued pod empties B's issued craft; the next sweep retires it.
	var spare: int = int(server.spawn_vehicle(POD, Vector3(500.0, 20.0, 0.0), 0.0))
	_check("server_can_move_b_to_a_spare", server.seat_client(ids[1], spare, 0), "pod %d" % spare)
	_advance(4)
	_check("an_empty_issued_craft_is_swept", server.vehicle_state(b_vehicle).is_empty()
		and _vehicles(SEGWAY).size() == 2, "%d segways remain" % _vehicles(SEGWAY).size())
	_finish()


func _finish() -> void:
	print("[issue] RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)
