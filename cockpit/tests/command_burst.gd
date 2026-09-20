extends Node
## Headless: A JOINER'S COMMANDS ARRIVE IN A BURST, AND THE LAST ONE STILL LANDS.
##
##   Godot --headless --path cockpit res://tests/command_burst.tscn
##
## THE BUG THIS WAS WRITTEN FOR (2026-09-17, `sweep_peers` red on main after the puff clouds made both machines heavier):
## the RIO dragged the F-14's sweep handle from 76 degrees to 30 on the joiner, the handle moved, the command was sent --
## and the wings never moved on either machine. Under load, the other way round, both machines ended at 52.6 degrees, a
## value from the MIDDLE of the RIO's drag that nobody had let go at.
##
## THE MECHANISM. A dragged lever sends a new command every `command_ride_frames()` ticks (4 at 120 Hz). The server acts
## on a command when the frame's `command_seq` differs from the last one it saw from that client, and sync hands it only
## the NEWEST input frame due, skipping older ones that arrived late alongside it. So a joiner whose frames reach the
## server in a burst has its middle commands skipped -- which is fine, the newest carries the latest value -- UNLESS the
## sequence wrapped. It was two bits: four commands skipped read as NO CHANGE, the let-go value sat on every later frame
## with a sequence the server thought it had already acted on, and it was lost for good. Five skipped read as one.
##
## SO THIS HOLDS A REAL CLIENT'S PACKETS while it sends N commands through `send_command`, exactly as a hand on a lever
## does -- one each time the last has ridden its frames -- and then lets them all through at once. The check is that the
## server's `sweep_command` is the last value sent, for N = 1..5, 8 and 256. On the two-bit bus 1, 2, 3 and 5 landed, and 4
## and 8 left the server on the value before the burst (10): the wrap, exactly. On the eight-bit bus all but 256 land; on
## the sixteen-bit bus (busbits, 2026-09-18) all seven.
##
## Over the in-process link `gun_link` uses: two CockpitWorlds, the packets carried by hand in `_pump`.
##
## Read RESULT=, not the exit code.

const DT: float = 1.0 / 120.0
const TICK_HZ: float = 120.0
const PEER: int = 2
const POD: int = 0
const TOMCAT: int = 25
## The RIO's seat: a seat that does not fly, as the joiner's was.
const RIO_SEAT: int = 1
## `Sim.Channel.SWEEP`, typed here because a headless suite with no autoloads may not have Sim: checked against it below.
const SWEEP: int = 16
## How many ticks each command is given before the next is sent: one more than it rides (1/30 s = 4 ticks), so each
## send finds the last one already on the frames and is not folded into it.
const TICKS_PER_COMMAND: int = 5
## How many commands are held back at once. 4 and 8 are the wrap on a two-bit sequence, 256 on the eight-bit one that
## followed it (busbits, 2026-09-18: red with `kCommandSeqBits` set back to 8); the others are the controls.
const BURSTS: Array[int] = [1, 2, 3, 4, 5, 8, 256]
## The user asked for a sequence of at least sixteen bits: `kCommandSeqBits`, read through `bus_limits`.
const LEAST_SEQ_BITS: int = 16
const BEFORE: int = 10

var _failures: PackedStringArray = []
var _server: RefCounted = null
var _client: RefCounted = null
var _tick: int = 0
## [[due_tick, to_the_server, peer, bytes, bits], ...]
var _in_flight: Array = []
## While true the client's packets wait at the client's end of the link, as a loaded joiner's do.
var _holding: bool = false


func _check(label: String, ok: bool, detail: String) -> void:
	print("[command_burst] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld is not registered")
		_finish()
		return
	_check("the_sweep_channel_is_the_one_sim_names", SWEEP == Sim.Channel.SWEEP,
		"%d here, %d in Sim" % [SWEEP, Sim.Channel.SWEEP])
	var seq_bits: int = int(Sim.bus_limits().get("seq_bits", 0))
	_check("the_sequence_is_at_least_sixteen_bits", seq_bits >= LEAST_SEQ_BITS, "%d bits" % seq_bits)
	for burst in BURSTS:
		_a_burst_of_commands_ends_on_the_last_one(burst)
	_a_channel_the_wire_cannot_name_is_refused_not_misrouted()
	_finish()


## A CHANNEL PAST THE WIRE'S TOP IS REFUSED, NOT FOLDED ONTO A LOW ONE (busbits, 2026-09-18). `send_command` masked the
## channel to the wire's five bits, so SWEEP + 32 left the client as SWEEP and the server swept the wings; and the value
## to eight, so 296 arrived as 40. Red before the fix: the wings went to 200, and the 296 landed as 40. It sends to SWEEP
## plus however many channels the wire can name, so it is the same test at whatever width `kCommandChannelBits` is.
func _a_channel_the_wire_cannot_name_is_refused_not_misrouted() -> void:
	var hull: int = _stand_the_rio_up()
	if hull == 0:
		return
	_client.send_command(SWEEP, BEFORE)
	_advance(40)
	var past: int = SWEEP + int(Sim.bus_limits().get("channels", 32))
	var taken: bool = bool(_client.send_command(past, 200))
	_advance(40)
	var after: int = int(_server.craft_systems(hull).get("sweep_command", -1))
	_check("a_channel_past_the_wire_is_refused_by_the_sender", not taken, "send_command(%d) answered %s" % [past, taken])
	_check("and_does_not_land_on_the_channel_it_would_mask_to", after == BEFORE,
		"sent 200 to channel %d; the server's sweep is %d" % [past, after])
	_client.send_command(SWEEP, 256 + 40)
	_advance(40)
	var clamped: int = int(_server.craft_systems(hull).get("sweep_command", -1))
	_check("a_value_past_the_wire_is_clamped_not_wrapped", clamped == 255, "sent 296; the server has %d" % clamped)
	_teardown()


## N COMMANDS SENT WHILE THE LINK HOLDS THEM, then let through together. The server must end on the last.
func _a_burst_of_commands_ends_on_the_last_one(burst: int) -> void:
	var hull: int = _stand_the_rio_up()
	if hull == 0:
		return
	# A FIRST COMMAND, landed normally, so the server has a sequence of this client's to compare with.
	_client.send_command(SWEEP, BEFORE)
	_advance(40)
	var before: int = int(_server.craft_systems(hull).get("sweep_command", -1))
	if before != BEFORE:
		_check("burst_of_%d_starts_from_a_command_that_landed" % burst, false, "server has %d, sent %d" % [before, BEFORE])
		_teardown()
		return
	var sent: Array[int] = []
	_holding = true
	for k in range(burst):
		# The same values as ever for the first eight, and kept inside 0-255 past them, where the value now clamps.
		var value: int = 30 + (25 * k) % 220
		_client.send_command(SWEEP, value)
		sent.append(value)
		_advance(TICKS_PER_COMMAND)
	# AND LONGER, so every frame that carried the burst is late when it arrives.
	_advance(12)
	_holding = false
	for entry in _in_flight:
		entry[0] = mini(int(entry[0]), _tick)
	_advance(60)
	var landed: int = int(_server.craft_systems(hull).get("sweep_command", -1))
	_check("a_burst_of_%d_commands_ends_on_the_last" % burst, landed == sent[-1],
		"sent %d, ending %s, after %d; the server has %d" % [sent.size(), str(sent.slice(-3)), BEFORE, landed])
	_teardown()


## TWO WORLDS, A TOMCAT FLOWN BY NOBODY IN PARTICULAR, AND THIS CLIENT IN ITS BACK SEAT. The hull, or 0 having said why.
func _stand_the_rio_up() -> int:
	_server = ClassDB.instantiate("CockpitWorld")
	_client = ClassDB.instantiate("CockpitWorld")
	_tick = 0
	_in_flight.clear()
	_holding = false
	for world in [_server, _client]:
		world.set_tick_rate(TICK_HZ)
	_server.start(0)
	_client.start(PEER)
	for world in [_server, _client]:
		world.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(400.0, 2.0, 400.0))
	_advance(90)
	var me: int = int(_client.local_client_id())
	if me <= 0:
		_check("the_client_handshook", false, "client id %d" % me)
		_teardown()
		return 0
	var craft: Dictionary = _server.spawn_pilot(201, TOMCAT, Vector3(0.0, 300.0, 0.0), 0.0, Vector3.ZERO)
	_server.spawn_pilot(me, POD, Vector3(60.0, 4.0, 60.0), 0.0, Vector3.ZERO)
	var hull: int = int(craft.get("vehicle", 0))
	_advance(20)
	if hull == 0 or not bool(_server.seat_client(me, hull, RIO_SEAT)):
		_check("the_client_takes_the_rios_seat", false, "client %d into seat %d of %d" % [me, RIO_SEAT, hull])
		_teardown()
		return 0
	_advance(40)
	return hull


func _controls() -> Dictionary:
	return {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0,
	}


func _advance(ticks: int) -> void:
	for i in range(ticks):
		_client.set_input(_controls())
		_tick += 1
		_server.tick(DT)
		_client.tick(DT)
		_pump()


## A ONE-TICK LINK, as `gun_link`'s delay 0, except that while `_holding` the client's packets are not due until it ends.
func _pump() -> void:
	for packet in _server.take_outbound():
		_in_flight.append([_tick, false, int(packet["peer"]), packet["bytes"], packet["bits"]])
	for packet in _client.take_outbound():
		_in_flight.append([1 << 60 if _holding else _tick, true, PEER, packet["bytes"], packet["bits"]])
	var still_flying: Array = []
	for entry in _in_flight:
		if entry[0] > _tick:
			still_flying.append(entry)
			continue
		if bool(entry[1]):
			_server.deliver(entry[2], entry[3], entry[4])
		else:
			_client.deliver(0, entry[3], entry[4])
	_in_flight = still_flying


func _teardown() -> void:
	if _client != null:
		_client.teardown()
	if _server != null:
		_server.teardown()
	_client = null
	_server = null
	_in_flight.clear()


func _finish() -> void:
	_teardown()
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
