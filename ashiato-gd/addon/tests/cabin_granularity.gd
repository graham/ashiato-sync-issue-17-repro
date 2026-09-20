extends Node
## PROBE: what a crew's cockpit costs on the wire, per client, with a full gunship aboard.
##
##   Godot --path addon --headless res://tests/cabin_granularity.tscn
##
## Written to settle one question with numbers (team-lead, 2026-09-14): is a crew's shared cockpit
## one entity per crew member, or one per crewed craft sent to everybody seated in it? Run once on
## each build and compare the rows.
##
## A server and five clients in one process over a one-tick link. A, B, C and D fill the four seats
## of one gunship; E flies alone. Then two measurements:
##
##   1. CREW WORKING. For WORK_TICKS the pilot holds a stick moving on a slow sine and the crew take
##      turns with the radio and the master arm. Bytes a tick the server handed each client, and the
##      bits the server's own trace says it serialised for each client, per component.
##   2. CHURN. The gunship has no fifth seat, so D gives E its seat: D leaves, E boards, E leaves, D
##      boards again, CHURN_ROUNDS times. Wire ids started and destroyed per client, from the server's
##      trace (entity_started_syncing, entity_destroyed).
##
## A probe and not a suite: it prints numbers and has no verdict. The verdicts it informs are
## `crew_cabin`'s. Read RESULT=, not the exit code.

const TICK_HZ: float = 60.0
const DT: float = 1.0 / TICK_HZ
const LINK_TICKS: int = 1
const WORK_TICKS: int = 600
const CHURN_ROUNDS: int = 5
const POD: int = 0
const GUNSHIP: int = 15
const USE: int = 2
const RADIO: int = 9
const MASTER: int = 13
## What carries a crew's cockpit on either build: the vehicle's crew-shared components before, and the
## cabin's after. Anything else on the wire is the sky, and is the same on both.
const CREW_COMPONENTS: Array[String] = ["CraftSystems", "CrewControls", "CabinOwner", "CabinSystems"]

var server
var worlds: Array = []
var _ids: Array[int] = []
var _tick: int = 0
var _in_flight: Array = []
var _bytes_to: Dictionary = {}
## client id -> component -> bits
var _bits_to: Dictionary = {}
## client id -> [started, destroyed]
var _churn_of: Dictionary = {}
var _counting_churn: bool = false
var _inputs: Array = [{}, {}, {}, {}, {}]


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


## world index -> that client's menu request number, on every frame; bumped once per JOIN. See `ControlInput::menu_request`.
var _menu_requests: Dictionary = {}


## ONE JOIN ON WORLD `n`'s FRAMES, as the CREW page presses one: the number moves on and the player rides beside it.
func _ask_to_join(n: int, client: int) -> void:
	_menu_requests[n] = (int(_menu_requests.get(n, 0)) + 1) % 8
	_inputs[n] = {"join_wanted": client}


func _advance(ticks: int) -> void:
	for i in range(ticks):
		for n in range(worlds.size()):
			var frame: Dictionary = (_inputs[n] as Dictionary).duplicate()
			frame["menu_request"] = int(_menu_requests.get(n, 0))
			worlds[n].set_input(_controls(frame))
		_tick += 1
		server.tick(DT)
		for world in worlds:
			world.tick(DT)
		for packet in server.take_outbound():
			var peer: int = int(packet["peer"])
			_in_flight.append([_tick + LINK_TICKS, peer, 0, packet["bytes"], packet["bits"]])
			_bytes_to[peer] = int(_bytes_to.get(peer, 0)) + (packet["bytes"] as PackedByteArray).size()
		for n in range(worlds.size()):
			for packet in worlds[n].take_outbound():
				_in_flight.append([_tick + LINK_TICKS, 0, n + 1, packet["bytes"], packet["bits"]])
		var still: Array = []
		for entry in _in_flight:
			if int(entry[0]) > _tick:
				still.append(entry)
			elif int(entry[1]) == 0:
				server.deliver(int(entry[2]), entry[3], entry[4])
			else:
				worlds[int(entry[1]) - 1].deliver(0, entry[3], entry[4])
		_in_flight = still
		for event in server.take_trace_events():
			var type: String = String(event["type"])
			var client: int = int(event["client"])
			if type == "component_sent" and String(event["component"]) in CREW_COMPONENTS:
				var row: Dictionary = _bits_to.get_or_add(client, {})
				row[String(event["component"])] = int(row.get(String(event["component"]), 0)) + int(event["bits"])
			elif _counting_churn and (type == "entity_started_syncing" or type == "entity_destroyed"):
				var churn: Array = _churn_of.get_or_add(client, [0, 0])
				churn[0 if type == "entity_started_syncing" else 1] += 1


func _seats(craft: int) -> PackedInt64Array:
	return server.vehicle_seats(craft)


func _press(n: int, overrides: Dictionary) -> void:
	_inputs[n] = overrides
	_advance(2)
	_inputs[n] = {}
	_advance(40)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_finish("FAIL CockpitWorld not registered")
		return
	server = ClassDB.instantiate("CockpitWorld")
	server.set_tick_rate(TICK_HZ)
	if not server.set_tracing(true):
		_finish("FAIL no tracing in this build")
		return
	server.start(0)
	server.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(8000.0, 2.0, 8000.0))
	for n in range(5):
		var world = ClassDB.instantiate("CockpitWorld")
		world.set_tick_rate(TICK_HZ)
		world.start(n + 1)
		world.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(8000.0, 2.0, 8000.0))
		worlds.append(world)
	_advance(90)
	for world in worlds:
		_ids.append(int(world.local_client_id()))
	if server.connected_clients().size() != 5:
		_finish("FAIL %d clients handshook" % server.connected_clients().size())
		return
	server.spawn_pilot(_ids[0], GUNSHIP, Vector3(0.0, 700.0, 0.0), 0.0, Vector3(0.0, 0.0, -50.0))
	for n in range(1, 5):
		server.spawn_pilot(_ids[n], POD, Vector3(-900.0 + 60.0 * n, 30.0, 900.0), 0.0, Vector3.ZERO)
	server.spawn_vehicle(POD, Vector3(900.0, 30.0, 900.0), 0.0)
	_inputs[0] = {"throttle": 0.7}
	_advance(60)
	var craft: int = int(_pilot_of(server, _ids[0]).get("vehicle", 0))
	for n in range(1, 4):
		_ask_to_join(n, _ids[0])
		_advance(2)
		_inputs[n] = {}
		_advance(60)
	print("[granularity] gunship seats %s; A %d B %d C %d D %d, outsider E %d" % [_seats(craft), _ids[0], _ids[1],
		_ids[2], _ids[3], _ids[4]])

	# ---- 1. the crew working --------------------------------------------------------------------------
	_bytes_to.clear()
	_bits_to.clear()
	var radio: int = 0
	for t in range(WORK_TICKS):
		_inputs[0] = {"throttle": 0.7, "roll": 0.6 * sin(float(t) * 0.05)}
		if t % 20 == 0:
			var who: int = t / 20 % 4
			radio = (radio + 1) % 8
			if t % 80 == 40:
				worlds[who].send_command(MASTER, t / 80 % 2)
			else:
				worlds[who].send_command(RADIO, radio)
		_advance(1)
	_inputs[0] = {"throttle": 0.7}
	print("[granularity] crew working, %d ticks, %d crew switch commands: bytes a tick from the server, and crew bits a tick serialised" % [
		WORK_TICKS, WORK_TICKS / 20])
	for n in range(5):
		var row: Dictionary = _bits_to.get(_ids[n], {})
		var parts: PackedStringArray = []
		var total: int = 0
		for component in CREW_COMPONENTS:
			if row.has(component):
				parts.append("%s %.1f" % [component, float(row[component]) / WORK_TICKS])
				total += int(row[component])
		print("[granularity]   %s client %d: %.1f bytes a tick; crew bits a tick %.1f (%s)" % [
			"ABCDE"[n], _ids[n], float(_bytes_to.get(n + 1, 0)) / WORK_TICKS, float(total) / WORK_TICKS,
			", ".join(parts)])

	# ---- 2. churn: D gives E its seat, and takes it back, CHURN_ROUNDS times ------------------------------
	_churn_of.clear()
	_counting_churn = true
	var boarded: int = 0
	for round in range(CHURN_ROUNDS):
		_press(3, {"buttons": USE})
		_ask_to_join(4, _ids[0])
		_advance(2)
		_inputs[4] = {}
		_advance(40)
		if _seats(craft).has(_ids[4]):
			boarded += 1
		_press(4, {"buttons": USE})
		_ask_to_join(3, _ids[0])
		_advance(2)
		_inputs[3] = {}
		_advance(40)
	_counting_churn = false
	print("[granularity] churn: %d rounds of D out, E in, E out, D in; E boarded %d times; wire ids started / destroyed per client" % [
		CHURN_ROUNDS, boarded])
	for n in range(5):
		var churn: Array = _churn_of.get(_ids[n], [0, 0])
		print("[granularity]   %s client %d: %d started, %d destroyed" % ["ABCDE"[n], _ids[n], int(churn[0]), int(churn[1])])
	_finish("PASS measured")


func _pilot_of(world, client_id: int) -> Dictionary:
	for pilot in world.pilot_states():
		if int(pilot["client"]) == client_id:
			return pilot
	return {}


func _finish(verdict: String) -> void:
	print("RESULT=%s" % verdict)
	get_tree().quit(0 if verdict.begins_with("PASS") else 1)
