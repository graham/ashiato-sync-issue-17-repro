extends Node
## EVERY CUE ON A CROWDED AEROPLANE REACHES ITS PILOT, EXACTLY ONCE.
##
##   Godot --path addon --headless res://tests/cue_crowd.tscn
##
## A cue is a moment on the wire, and sync forgets it when the client acknowledges a packet. It
## once forgot a cue the moment the client acknowledged a packet OLDER than the cue: cockpit
## stamped every cue with the frame whose packet had already gone, so when the aeroplane was not
## in the very next packet the ack for the old one erased the cue unsent. A loopback with a
## handful of entities puts the aeroplane in every packet and never saw it. The flight level,
## with its traffic under a 1024-byte budget, lost 305 of 308 cues on the pilot's own aeroplane
## and every launch cue from the seat.
##
## So this crowds the budget on purpose: eighty aeroplanes flying alongside the launcher, so its
## record misses packets, at the game's settings (120 Hz, packets carried the instant they are
## made, three frames of interpolation). The launches are the pilot's own LAUNCH bit, and a
## MARKER cue is emitted on the launcher every ten ticks from outside the tick, the way a binding
## does. Every marker and both launch cues must arrive, and none twice. An empty sky runs the
## same script first, as the control that says the counting is right.
##
## Measured on the stamp this replaced: 48 of 72 markers and 1 of 2 launch cues in the crowd,
## 72 of 72 and 2 of 2 in the empty sky.
##
## Read RESULT=, not the exit code.

const HZ: float = 120.0
const PEER: int = 1
const PLANE: int = 1
const LAUNCH: int = 128
const WEAPON: int = 8
const MASTER: int = 13
const CUE_MISSILE_LAUNCH: int = 1
## A cue event no game uses, so a marker cannot be mistaken for anything real.
const CUE_MARKER: int = 7
const CROWD: int = 80

var _failures: PackedStringArray = []
var server
var client
var _tick: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[crowd] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _controls(buttons: int = 0) -> Dictionary:
	return {
		"throttle": 1.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": buttons,
	}


## THE GAME'S ORDER: input, server tick, client tick, then every packet carried across at once.
func _advance(ticks: int, input: Dictionary, cues: Array) -> void:
	for i in range(ticks):
		if not input.is_empty():
			client.set_input(input)
		_tick += 1
		server.tick(1.0 / HZ)
		client.tick(1.0 / HZ)
		for packet in server.take_outbound():
			client.deliver(0, packet["bytes"], packet["bits"])
		for packet in client.take_outbound():
			server.deliver(PEER, packet["bytes"], packet["bits"])
		for cue in client.take_cues():
			cues.append(cue)


func _station(wanted: String) -> int:
	for row in server.missile_schema(PLANE).get("stations", []):
		if String(row["name"]) == wanted:
			return int(row["station"])
	return -1


## One sky: `crowd` aeroplanes alongside the launcher, two launches, a marker every ten ticks.
## Returns what was sent and what arrived.
func _fly(crowd: int) -> Dictionary:
	_tick = 0
	server = ClassDB.instantiate("CockpitWorld")
	client = ClassDB.instantiate("CockpitWorld")
	for world in [server, client]:
		world.set_tick_rate(HZ)
	client.set_interpolation(3, true)
	server.start(0)
	client.start(PEER)
	# RAILS THAT STAY EMPTY. This counts the rails the two launches emptied, eight seconds after
	# the first, and rails rearm after five by default -- the rearm has its own checks in
	# cockpit_loopback. Found by the gate the day rearming landed: 1 rail emptied of 2.
	for world in [server, client]:
		for row in world.missile_types():
			world.set_missile_type(int(row["id"]), {"rearm_s": 0.0})
	var cues: Array = []
	var waited: int = 0
	while waited < int(HZ * 3.0) and not (int(client.local_client_id()) > 0 \
			and server.connected_clients().size() == 1):
		_advance(1, {}, cues)
		waited += 1
	var id: int = int(client.local_client_id())
	var home := Vector3(-12000.0, 900.0, 12000.0)
	for i in range(crowd):
		# CLOSE and MOVING: every one of them is dirty every tick and near enough to outrank
		# nothing by distance, so the launcher's own record has to wait its turn.
		server.spawn_vehicle(PLANE, home + Vector3(float(i % 10) * 40.0 - 200.0,
			60.0 + float(i / 10) * 30.0, float(i % 7) * 40.0), 0.0, Vector3(0.0, 0.0, -60.0))
	var made: Dictionary = server.spawn_pilot(id, PLANE, home, 0.0, Vector3(0.0, 0.0, -60.0))
	var plane: int = int(made.get("vehicle", 0))
	var fly: Dictionary = _controls()
	_advance(int(HZ * 3.0), fly, cues)
	client.send_command(MASTER, 1)
	_advance(int(HZ * 0.3), fly, cues)
	client.send_command(WEAPON, _station("heat"))
	_advance(int(HZ * 1.0), fly, cues)
	cues.clear()
	var stores_before: int = int(server.craft_systems(plane).get("stores", -1))
	var markers_sent: Dictionary = {}
	for shot in range(2):
		_advance(4, _controls(LAUNCH), cues)
		for i in range(int(HZ * 3.0)):
			if _tick % 10 == 0:
				# FROM OUTSIDE THE TICK, which is where every cue the cockpit emits comes from.
				if bool(server.emit_craft_cue(plane, CUE_MARKER, _tick % 256, 0.75)):
					markers_sent[_tick] = true
			_advance(1, fly, cues)
	# QUIET, so a cue still on its way at the end is not counted as lost.
	_advance(int(HZ * 2.0), fly, cues)
	var stores_after: int = int(server.craft_systems(plane).get("stores", -1))
	var markers_seen: Dictionary = {}
	var launches: int = 0
	for cue in cues:
		match int(cue["what"]):
			CUE_MARKER:
				var at: int = int(cue["frame"])
				markers_seen[at] = int(markers_seen.get(at, 0)) + 1
			CUE_MISSILE_LAUNCH:
				launches += 1
	var twice: int = 0
	for at in markers_seen:
		if int(markers_seen[at]) > 1:
			twice += 1
	var result := {
		"sent": markers_sent.size(), "arrived": markers_seen.size(), "twice": twice,
		"launches": launches, "rails_emptied": _bits(stores_before) - _bits(stores_after),
		"client_sees": client.vehicle_states().size(),
	}
	client.teardown()
	server.teardown()
	return result


func _bits(value: int) -> int:
	var n: int = 0
	for i in range(8):
		if value >= 0 and (value >> i) & 1 == 1:
			n += 1
	return n


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("cockpit_world_is_registered", false, "build with -WithCockpit")
		_finish()
		return
	for crowd in [0, CROWD]:
		var sky: Dictionary = _fly(crowd)
		var name: String = "an_empty_sky" if crowd == 0 else "a_crowded_sky"
		_check("%s_launches_two_missiles" % name, int(sky["rails_emptied"]) == 2,
			"%d rails emptied; the client sees %d vehicles" % [int(sky["rails_emptied"]), int(sky["client_sees"])])
		_check("%s_hands_the_pilot_every_marker" % name,
			int(sky["sent"]) > 0 and int(sky["arrived"]) == int(sky["sent"]),
			"%d of %d markers arrived" % [int(sky["arrived"]), int(sky["sent"])])
		_check("%s_hands_the_pilot_both_launch_cues" % name, int(sky["launches"]) == 2,
			"%d launch cues" % int(sky["launches"]))
		_check("%s_hands_over_no_cue_twice" % name, int(sky["twice"]) == 0,
			"%d markers arrived more than once" % int(sky["twice"]))
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
