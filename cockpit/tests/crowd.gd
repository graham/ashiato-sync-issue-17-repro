extends Node
## Headless: HOW MANY CLIENTS, AT WHAT PING, AND HOW OFTEN DOES ANYBODY MISPREDICT?
##
##   Godot --headless --path cockpit res://tests/crowd.tscn -- --clients=8 --ping=100
##   tests/crowd.sh                      the whole sweep, as a table
##
## A PROBE, NOT A SUITE. It has no pass and no fail, because the answer is a number and
## the number depends on what you are willing to pay for. It is not in tests/suites.txt.
##
## WHAT IS ACTUALLY BEING MEASURED, because "how many players" is three questions wearing
## one coat:
##
##   THE WIRE. Bytes per second the server has to push, and bytes per second each client
##   has to swallow. This is the one that stops you first, and it is the one that is
##   quadratic: with no interest management every client is told about every entity, so
##   the server's outbound is clients times entities. Twice the players is four times the
##   traffic.
##
##   THE SERVER'S OWN TICK. Wall-clock microseconds to advance the server one frame with
##   N clients attached, measured on its own rather than with the client worlds included.
##   Serialisation is per client per entity, so this is quadratic too.
##
##   THE MISPREDICTS. How often a client has to rewind and replay, and how far back. This
##   is the one people mean by "does it feel right", and it is the one that depends on the
##   ping rather than on the player count -- which is exactly why it is worth measuring
##   separately from the other two.
##
## THE LINK IS FAKE AND THAT IS THE POINT. Every packet goes into a queue with a delivery
## tick on it, so the ping is exact, repeatable, and costs no sockets. Jitter spreads the
## delivery tick; loss drops the packet. Nothing here touches ENet, so a sweep of six
## client counts runs in one process in under a minute.
##
## WHAT IT DOES NOT MEASURE: the cost of ENet itself, kernel send time, or the per-packet
## IP and UDP headers -- 28 bytes a packet on IPv4, which at this tick rate is NOT small.
## Packets per second is reported so that arithmetic can be done rather than guessed at.

## Kinds, matching kKind* in cockpit_world.cpp.
const PLANE: int = 1

## How long to fly before the measurement starts. Handshake, spawn, and enough frames for
## the clocks to settle and the interpolation buffers to fill: measuring across the join is
## measuring the join.
const WARMUP_SECONDS: float = 3.0

var clients_wanted: int = 8
var ping_ms: float = 100.0
var measure_seconds: float = 8.0
var tick_hz: float = 120.0
var ai_craft: int = 0
var use_holding_stack: bool = false
var loss_percent: float = 0.0
var jitter_ms: float = 0.0
## How far into the past this client draws the entities it is INTERPOLATING, in frames, and
## whether sync is allowed to size that itself. Automatic is the shipping default and it
## sizes from measured JITTER -- see `auto_buffered_frame_lag_jitter_multiplier` -- which is
## the right input for a link that wobbles and the wrong one for an entity that is simply
## not being sent very often.
var buffer_frames: int = 3
var auto_buffer: bool = true

var _server: Object = null
var _clients: Array = []
var _flight: Array = []
var _tick: int = 0
var _rng := RandomNumberGenerator.new()

## Per client, over the measurement window.
var _down_bytes: Array[int] = []
var _up_bytes: Array[int] = []
var _down_packets: Array[int] = []
var _up_packets: Array[int] = []
var _down_payload: Array[int] = []
var _up_payload: Array[int] = []
var _dropped: int = 0
var _server_usec: int = 0
var _client_usec: int = 0
var _measuring: bool = false
var _largest_down: Array[int] = []
var _largest_up: Array[int] = []
var _largest_down_tick: Array[int] = []
var _largest_up_tick: Array[int] = []
var _server_tick_samples: PackedFloat32Array = []
var _buffers: PackedInt32Array = []
var _starved := 0
var _truncated_at_start: Array[int] = []
## WHAT THE SERVER WROTE for client 0, from sync's `component_sent` trace. Up to ashiato-sync 90f50bf that was written
## BEFORE the budget check, every dirty candidate every tick, sent or not, and so it is labelled "serialised" wherever it
## is reported. Since 8fa08cf sync defers it until the record is in a packet, so the "serialised" columns now count
## records SENT; the names stay so that older logs still compare.
var _last_sent: Dictionary = {}
var _worst_update_gap := 0
var _sent_events := 0
## WHAT CLIENT 0 RECEIVED, from its own `received_frames` (the server frame of each craft's newest VehicleState record):
## local entity -> that frame, for every craft client 0 draws and does not predict at the start of the window. Every gap
## and rate a report calls an "update" comes from here. `_receipt_near` marks the craft within the sphere's radius of
## client 0's own craft at the start of the window.
var _receipt_last: Dictionary = {}
var _receipt_counts: Dictionary = {}
var _receipt_near: Dictionary = {}
var _receipt_gaps: PackedInt32Array = []
var _receipt_near_worst := 0
var _receipt_far_worst := 0
var _trace_dropped_at_start := 0
var _stack_ids: Dictionary = {}
var _stack: HoldingStack = null
var last_report: Dictionary = {}
var trace_one_client: bool = true
var force_trace: bool = false
## THE GAME'S PRIORITY SPHERE ON THE SERVER, with `--sphere=on`: `Sim.priority_sphere`, which is Sim.PRIORITY_* with any
## `--priority-*` flags over it, so a cell prices the prioritizer the game runs. Off otherwise, which is a bare
## CockpitWorld's own default. See agents.md, "THE PRIORITY SPHERE".
var sphere_on: bool = OS.get_cmdline_user_args().has("--sphere=on")
## HEADS AND HANDS THAT MOVE, `--tracked`: every client's three poses change every tick, as a VR player's do. Off, they
## hold still, as they always did here, and PilotState is sent once and never again -- so without this flag no cell has
## ever priced the pose stream (lane/ashiato-latest step 3, 2026-09-18).
var tracked_poses: bool = OS.get_cmdline_user_args().has("--tracked")
## THE POSE LOD, `--pose-lod=on`: the server leaves a far pilot's PilotState out (CockpitWorld.set_pose_lod, 250 m in,
## 350 m out). Off by default here as in the game.
var pose_lod_on: bool = OS.get_cmdline_user_args().has("--pose-lod=on")
## THE REFUSAL BOUND, `--refusals=N` (CockpitWorld.set_budget_refusals): how many records a starved client may be
## refused in a tick before sync stops looking. Not given, the world's own default (2) stands; 0 is unbounded, which is
## how sync behaved before 8fa08cf. Step 2 of lane/ashiato-latest's A/B.
var budget_refusals: int = -1
## A PER-CLIENT BUDGET, bytes a second, set before the server starts; 0 leaves CockpitWorld's own default. For a cell that
## is starved on purpose.
var send_budget_bps: int = 0
var _priority_calls_at_start: int = 0
var _priority_ticks_at_start: int = 0


func _ready() -> void:
	_read_arguments()
	if not ClassDB.class_exists("CockpitWorld"):
		print("[crowd] CockpitWorld not registered; build with -WithCockpit")
		get_tree().quit()
		return
	_rng.seed = 20260910
	_stand_everything_up()
	if _clients.is_empty():
		print("[crowd] no clients handshook; giving up")
		_tear_down()
		get_tree().quit()
		return
	_fly(int(WARMUP_SECONDS * tick_hz))
	_start_measuring()
	_fly(int(measure_seconds * tick_hz))
	_report()
	_tear_down()
	get_tree().quit()


## One deterministic ladder cell, reused by bulk_load and bulk_probe. Link is one-way
## ticks; craft are always created through HoldingStack.
func run_bulk_cell(craft: int, peers: int, link: int, settle_ticks: int = 600,
		measure_ticks: int = 1200) -> Dictionary:
	clients_wanted = peers
	ai_craft = craft
	use_holding_stack = true
	ping_ms = float(link * 2) / tick_hz * 1000.0
	measure_seconds = float(measure_ticks) / tick_hz
	_clients.clear()
	_flight.clear()
	_down_bytes.clear()
	_up_bytes.clear()
	_down_packets.clear()
	_up_packets.clear()
	_down_payload.clear()
	_up_payload.clear()
	_largest_down.clear()
	_largest_up.clear()
	_largest_down_tick.clear()
	_largest_up_tick.clear()
	_tick = 0
	_stack = null
	last_report = {}
	_stand_everything_up()
	_fly(settle_ticks)
	_start_measuring()
	_fly(measure_ticks)
	_report()
	var out := last_report.duplicate(true)
	_tear_down()
	_server = null
	_clients.clear()
	return out


## ---- the knobs ---------------------------------------------------------------------

func _read_arguments() -> void:
	for arg in OS.get_cmdline_user_args():
		var bits: PackedStringArray = arg.lstrip("-").split("=")
		if bits.size() != 2:
			continue
		var value: float = float(bits[1])
		match bits[0]:
			"clients": clients_wanted = int(value)
			"ping": ping_ms = value
			"seconds": measure_seconds = value
			"tick": tick_hz = value
			"ai": ai_craft = int(value)
			"stack":
				ai_craft = int(value)
				use_holding_stack = true
			"loss": loss_percent = value
			"jitter": jitter_ms = value
			# CLAMPED, because 64 is not a large buffer, it is a core dump: sync's
			# capacity is 64 and it validates by throwing, out of `start`, where the
			# binding does not catch it.
			"buffer": buffer_frames = clampi(int(value), 1, 63)
			"auto": auto_buffer = value != 0.0
			# BYTES A SECOND PER CLIENT, and large enough to lift the cap: a cell at the default 245 kB/s shows a saving
			# as fresher craft, never as fewer bytes, because the budget is already full.
			"budget": send_budget_bps = int(value)
			"refusals": budget_refusals = int(value)


## HALF THE PING EACH WAY, in ticks, and never less than one.
##
## A zero-tick link is not a fast link, it is a link that does not exist: the packet is
## delivered inside the same frame it was sent, the client's prediction is never wrong,
## and every rollback number comes back zero for a reason that has nothing to do with the
## code being good.
func _one_way_ticks() -> int:
	return maxi(1, int(round(ping_ms * 0.5 * 0.001 * tick_hz)))


## ---- the session -------------------------------------------------------------------

func _stand_everything_up() -> void:
	var boxes: Array[Dictionary] = Terrain.boxes()
	var grid := BoxGrid.new(boxes)
	_server = ClassDB.instantiate("CockpitWorld")
	# Tracing every component for eight clients changes the server timing being priced.
	# The ladder traces its two-peer cells (one selected client) and derives the wider
	# cells from that measured update cost, exactly as plan_next prescribes when tracing
	# is itself material load.
	trace_one_client = force_trace or clients_wanted <= 2
	_server.set_tracing(trace_one_client)
	_server.set_tick_rate(tick_hz)
	if send_budget_bps > 0:
		_server.set_send_budget(send_budget_bps)
	if budget_refusals >= 0 and _server.has_method("set_budget_refusals"):
		_server.set_budget_refusals(budget_refusals)
	_server.start(0)
	# NO HIT POINTS AND NO CRASHES (lane/combat): a crowd measured for its wire must stay the crowd it was. A craft its own
	# guns destroyed goes silent, frozen, and the rotation audit (bulk_load) read the silence as a craft starved.
	if _server.has_method("set_damage"):
		_server.set_damage(false)
		_server.set_crashes(false)
	if sphere_on and _server.has_method("set_priority_sphere"):
		var asked: Dictionary = Sim.priority_sphere
		_server.set_priority_sphere(bool(asked["enabled"]), float(asked["radius_m"]), float(asked["inside"]),
			float(asked["outside"]), int(asked["falloff"]))
	if pose_lod_on and _server.has_method("set_pose_lod"):
		_server.set_pose_lod(true, 250.0, 350.0)
	_ground(_server, boxes, grid)
	for i in range(clients_wanted):
		var world: Object = ClassDB.instantiate("CockpitWorld")
		world.set_tick_rate(tick_hz)
		# BEFORE `start`, because that is when the client is built and these are options on
		# it rather than settings it re-reads.
		world.set_interpolation(buffer_frames, auto_buffer)
		# CLIENT 0 COUNTS WHAT IT RECEIVES, without a Dictionary per trace event, so the count costs its own tick little and
		# the server's nothing. See `_measure_receipts`.
		if i == 0 and world.has_method("set_receipts_only"):
			world.set_tracing(true)
			world.set_receipts_only(true)
		# Peer ids start at 1: 0 is the server, in both directions.
		world.start(i + 1)
		_ground(world, boxes, grid)
		_clients.append(world)
		_down_bytes.append(0)
		_up_bytes.append(0)
		_down_packets.append(0)
		_up_packets.append(0)
		_down_payload.append(0)
		_up_payload.append(0)
		_largest_down.append(0)
		_largest_up.append(0)
		_largest_down_tick.append(0)
		_largest_up_tick.append(0)
	# THE HANDSHAKE IS NOT INSTANT and it is not `add_client` either -- registering a
	# client by hand and then pushing updates at it before it has introduced itself is a
	# hard crash inside sync. The client introduces itself; the server accepts.
	_fly(int(1.5 * tick_hz))
	# A PLANE EACH, spread round a circle so nobody spawns inside anybody.
	var seated: int = 0
	for i in range(_clients.size()):
		var id: int = int(_clients[i].local_client_id())
		if id <= 0:
			continue
		var about: float = TAU * float(i) / float(maxi(_clients.size(), 1))
		var at := Vector3(cos(about) * 400.0, 300.0 + float(i % 8) * 40.0,
			sin(about) * 400.0)
		# FLYING ALREADY. An aeroplane put into the air at a standstill falls, stalls
		# within a few ticks and mushes into the ground at full power, which is correct
		# behaviour for a wing and useless as a load test.
		_server.spawn_pilot(id, PLANE, at, about + PI * 0.5,
			Vector3(cos(about + PI * 0.5), 0.0, sin(about + PI * 0.5)) * 60.0)
		seated += 1
	# AND A POPULATION, which is what makes this a world rather than a lobby. These have
	# nobody in them and fly themselves, and they cost every client exactly what another
	# player's aeroplane costs -- the wire does not know the difference.
	if use_holding_stack:
		_stack = HoldingStack.new()
		_stack.setup(_server)
		# ASK FOR WHAT THE STACK WILL ACTUALLY GIVE. `set_count` CLAMPS to `HoldingStack.MOST`, and this loop used to
		# wait for `count()` to reach `ai_craft`: above the cap that condition can never be true, so the probe did not
		# fail, it HUNG -- nothing printed, no RESULT=, killed by a deadline that reads like a parse error (CLAUDE.md,
		# rule 1). Measured on 2026-09-17 at 201 craft against a cap of 200: still running after 60 s with an empty log.
		if ai_craft > HoldingStack.MOST:
			push_warning("[crowd] %d craft asked for; the stack holds %d, and that is what will be measured"
				% [ai_craft, HoldingStack.MOST])
			ai_craft = HoldingStack.MOST
		_stack.set_count(ai_craft)
		# AND STOP WHEN IT STOPS GROWING, whatever the reason. A stack can also refuse for its own reasons -- no room
		# under the wire, a simulation that will not spawn -- and it says so through `said`. A loop that waits for a
		# number the thing has stopped moving towards is the same hang in a different disguise.
		var standing := -1
		while _stack.count() < ai_craft and _stack.count() != standing:
			standing = _stack.count()
			_stack.step()
			_fly(1)
		if _stack.count() < ai_craft:
			push_warning("[crowd] the stack stood %d of the %d asked for and stopped growing"
				% [_stack.count(), ai_craft])
			ai_craft = _stack.count()
	else:
		for i in range(ai_craft):
			var about: float = TAU * float(i) / float(maxi(ai_craft, 1)) + 0.37
			var at := Vector3(cos(about) * 900.0, 400.0 + float(i % 12) * 30.0,
				sin(about) * 900.0)
			_server.spawn_vehicle(PLANE, at, about + PI * 0.5,
				Vector3(cos(about + PI * 0.5), 0.0, sin(about + PI * 0.5)) * 60.0)
	print("[crowd] %d client(s) seated, %d AI craft, %.0f Hz, %.0f ms ping (%d tick(s) each way), buffer %d%s"
		% [seated, ai_craft, tick_hz, ping_ms, _one_way_ticks(), buffer_frames,
			" (automatic)" if auto_buffer else ""])


## Ground, built identically in every world. Not replicated -- every peer builds it from
## the same data -- so a world that built it differently would predict itself into it.
func _ground(world: Object, boxes: Array[Dictionary], grid: BoxGrid) -> void:
	world.add_static_box(Vector3(0.0, -Terrain.GROUND_HALF.y, 0.0), Terrain.GROUND_HALF)
	for box in boxes:
		world.add_static_box(box["position"], box["half_extents"])
	for spot in Terrain.waypoints(Sim.Kind.PLANE, grid):
		world.add_ai_waypoint(PLANE, spot)


## ---- flying ------------------------------------------------------------------------

## ONE TICK FOR EVERYBODY, with every client working its stick.
##
## THE STICK MOVES ON PURPOSE. A client holding still agrees with the server and never
## rolls back, which would make this report a rollback rate of zero and mean nothing. Each
## one flies its own phase of a slow roll, so every client is continuously asking for
## something the server has not heard about yet -- which is the condition rollback exists
## for and the honest worst case for a player who is actually flying.
func _fly(ticks: int) -> void:
	var dt: float = 1.0 / tick_hz
	for n in range(ticks):
		for i in range(_clients.size()):
			_clients[i].set_input(_stick(i, _tick))
		if _measuring:
			_watch()
		var began: int = Time.get_ticks_usec()
		_server.tick(dt)
		var after_server: int = Time.get_ticks_usec()
		for world in _clients:
			world.tick(dt)
		if _measuring:
			_server_usec += after_server - began
			_server_tick_samples.append(float(after_server - began))
			_client_usec += Time.get_ticks_usec() - after_server
		_tick += 1
		_pump()
		if _measuring:
			_measure_trace()
			_measure_receipts()
			if not _clients.is_empty():
				_buffers.append(int(_clients[0].timing().get("buffer_frames", -1)))


func _stick(who: int, at_tick: int) -> Dictionary:
	var phase: float = float(at_tick) / tick_hz + float(who) * 0.8
	if tracked_poses:
		# The same motion input_window's tracked flight uses: a head and two hands that never hold still.
		var p: float = float(at_tick) * 0.07 + float(who)
		return {
			"throttle": 0.75,
			"pitch": sin(phase * 0.7) * 0.35,
			"roll": sin(phase * 0.45) * 0.8,
			"rudder": 0.0,
			"brake": 0.0,
			"head": Vector3(sin(p) * 0.10, cos(p * 0.7) * 0.06, sin(p * 0.4) * 0.05),
			"head_basis": Quaternion(Vector3.UP, p * 0.2),
			"left": Vector3(-0.3 + sin(p * 1.1) * 0.12, -0.25 + cos(p) * 0.10, -0.3),
			"left_basis": Quaternion(Vector3.RIGHT, p * 0.3),
			"right": Vector3(0.3 + cos(p * 0.9) * 0.12, -0.25 + sin(p) * 0.10, -0.3),
			"right_basis": Quaternion(Vector3.FORWARD, p * 0.25),
			"grip_left": 0.5 + 0.5 * sin(p * 0.5),
			"grip_right": 0.5 + 0.5 * cos(p * 0.5),
			"buttons": 0,
		}
	return {
		"throttle": 0.75,
		"pitch": sin(phase * 0.7) * 0.35,
		"roll": sin(phase * 0.45) * 0.8,
		"rudder": 0.0,
		"brake": 0.0,
		"head": Vector3(0.0, 0.0, 0.0),
		"head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30),
		"left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30),
		"right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0,
		"grip_right": 0.0,
		"buttons": 0,
	}


## ---- the fake link -------------------------------------------------------------------

## EVERY PACKET, INTO A QUEUE WITH A DELIVERY TICK ON IT.
##
## The whole network model, and it is deliberately this small: a delay in ticks is exact
## and repeatable in a way a real socket is not, so two runs at the same client count
## produce the same numbers and a difference between them is a change in the code.
##
## `entry` is [deliver_at, target, from_peer, bytes, bits] and target -1 means the server.
func _pump() -> void:
	var delay: int = _one_way_ticks()
	var down_this_tick: Array[int] = []
	var up_this_tick: Array[int] = []
	for i in range(_clients.size()):
		down_this_tick.append(0)
		up_this_tick.append(0)
	for packet in _server.take_outbound():
		var peer: int = int(packet["peer"])
		var to: int = peer - 1
		if to < 0 or to >= _clients.size():
			continue
		if _post(_tick + delay, to, 0, packet["bytes"], packet["bits"]) and _measuring:
			_down_bytes[to] += _wire_bytes(packet)
			_down_payload[to] += int(ceil(float(int(packet["bits"])) / 8.0))
			_down_packets[to] += 1
			_largest_down[to] = maxi(_largest_down[to], (packet["bytes"] as PackedByteArray).size())
			down_this_tick[to] += _wire_bytes(packet)
	for i in range(_clients.size()):
		for packet in _clients[i].take_outbound():
			if _post(_tick + delay, -1, i + 1, packet["bytes"], packet["bits"]) and _measuring:
				_up_bytes[i] += _wire_bytes(packet)
				_up_payload[i] += int(ceil(float(int(packet["bits"])) / 8.0))
				_up_packets[i] += 1
				_largest_up[i] = maxi(_largest_up[i], (packet["bytes"] as PackedByteArray).size())
				up_this_tick[i] += _wire_bytes(packet)
	if _measuring:
		for i in range(_clients.size()):
			_largest_down_tick[i] = maxi(_largest_down_tick[i], down_this_tick[i])
			_largest_up_tick[i] = maxi(_largest_up_tick[i], up_this_tick[i])

	var still_flying: Array = []
	for entry in _flight:
		if int(entry[0]) > _tick:
			still_flying.append(entry)
			continue
		if int(entry[1]) < 0:
			_server.deliver(entry[2], entry[3], entry[4])
		else:
			_clients[int(entry[1])].deliver(0, entry[3], entry[4])
	_flight = still_flying


## True if the packet was sent rather than dropped. Loss is counted BEFORE the bandwidth
## is, because a packet that never arrives still cost the sender its bytes -- and a report
## that hid them would flatter a lossy link.
func _post(at: int, to: int, from_peer: int, bytes: PackedByteArray, bits: int) -> bool:
	if loss_percent > 0.0 and _rng.randf() * 100.0 < loss_percent:
		_dropped += 1
		return true
	var when: int = at
	if jitter_ms > 0.0:
		when += int(round(_rng.randf() * jitter_ms * 0.001 * tick_hz))
	_flight.append([when, to, from_peer, bytes, bits])
	return true


## WHAT THE PACKET COSTS ON THE WIRE, not what it holds. `bits` is the payload; a UDP
## datagram over IPv4 carries 20 bytes of IP header and 8 of UDP in front of it, and ENet
## adds its own. At 120 packets a second per direction that is 3.4 kB/s of header per
## client before a single byte of game state, which is not a rounding error.
const HEADER_BYTES: int = 28 + 8

func _wire_bytes(packet: Dictionary) -> int:
	return int(ceil(float(int(packet["bits"])) / 8.0)) + HEADER_BYTES


## ---- the report ----------------------------------------------------------------------

func _start_measuring() -> void:
	for i in range(_clients.size()):
		_down_bytes[i] = 0
		_up_bytes[i] = 0
		_down_packets[i] = 0
		_up_packets[i] = 0
		_down_payload[i] = 0
		_up_payload[i] = 0
		_largest_down[i] = 0
		_largest_up[i] = 0
		_largest_down_tick[i] = 0
		_largest_up_tick[i] = 0
	_dropped = 0
	_server_usec = 0
	_client_usec = 0
	_server_tick_samples.clear()
	_buffers.clear()
	_starved = 0 if trace_one_client else -1
	_last_sent.clear()
	_stack_ids.clear()
	if _stack != null:
		for entity in _stack.entities():
			_stack_ids[entity] = true
	_worst_update_gap = 0
	_sent_events = 0
	_receipt_last.clear()
	_receipt_counts.clear()
	_receipt_near.clear()
	_receipt_gaps.clear()
	_receipt_near_worst = 0
	_receipt_far_worst = 0
	if not _clients.is_empty() and _clients[0].has_method("received_frames"):
		var frames: Dictionary = (_clients[0].received_frames() as Dictionary).get("frames", {})
		var radius: float = float(Sim.priority_sphere.get("radius_m", 0.0)) if sphere_on else -1.0
		var mine := Vector3(INF, INF, INF)
		for state in _clients[0].vehicle_states():
			if bool((state as Dictionary).get("predicted", false)):
				mine = (state as Dictionary)["position"]
		for state in _clients[0].vehicle_states():
			var row: Dictionary = state
			if bool(row.get("predicted", false)):
				continue
			var entity := int(row["entity"])
			_receipt_last[entity] = int(frames.get(entity, -1))
			_receipt_counts[entity] = 0
			_receipt_near[entity] = (row["position"] as Vector3).distance_to(mine) <= radius
	_trace_dropped_at_start = int(_server.trace_events_dropped()) \
		if _server.has_method("trace_events_dropped") else 0
	_truncated_at_start.clear()
	for world in _clients:
		_truncated_at_start.append(int(world.timing().get("input_packets_truncated", 0)))
	if trace_one_client:
		_server.take_trace_events()
	_watched = 0
	_watched_at = Vector3.ZERO
	_steps = []
	_frozen = 0
	_resim_at_start = []
	for world in _clients:
		_resim_at_start.append(world.resim_stats().duplicate())
	if _server.has_method("priority_sphere"):
		var asked: Dictionary = _server.priority_sphere()
		_priority_calls_at_start = int(asked["calls"])
		_priority_ticks_at_start = int(asked["ticks"])
	_measuring = true

var _resim_at_start: Array = []
## One remote vehicle on client 0, sampled every tick: where it was drawn, and the size of
## each step it took.
var _watched: int = 0
var _watched_at: Vector3 = Vector3.ZERO
var _steps: PackedFloat32Array = []
var _frozen: int = 0


func _measure_trace() -> void:
	if not trace_one_client:
		return
	var sent_this_tick: Dictionary = {}
	for event in _server.take_trace_events():
		var kind := String(event.get("type", ""))
		if kind == "input_starved":
			_starved += 1
		elif kind == "component_sent" and int(event.get("client", -1)) == int(_clients[0].local_client_id()):
			var entity := int(event.get("entity", 0))
			if not _stack_ids.is_empty() and not _stack_ids.has(entity):
				continue
			sent_this_tick[entity] = true
			if _last_sent.has(entity):
				_worst_update_gap = maxi(_worst_update_gap, _tick - int(_last_sent[entity]))
			_last_sent[entity] = _tick
	_sent_events += sent_this_tick.size()


## EVERY RECORD CLIENT 0 RECEIVED THIS TICK, and the gap in server frames since that craft's last one.
func _measure_receipts() -> void:
	if _receipt_last.is_empty():
		return
	var frames: Dictionary = (_clients[0].received_frames() as Dictionary).get("frames", {})
	for entity in _receipt_last:
		var frame := int(frames.get(entity, -1))
		var last := int(_receipt_last[entity])
		if frame == last:
			continue
		if last >= 0:
			var gap := frame - last
			_receipt_gaps.append(gap)
			if bool(_receipt_near[entity]):
				_receipt_near_worst = maxi(_receipt_near_worst, gap)
			else:
				_receipt_far_worst = maxi(_receipt_far_worst, gap)
		_receipt_counts[entity] = int(_receipt_counts[entity]) + 1
		_receipt_last[entity] = frame


## HOW A STARVED ENTITY LOOKS, WHICH IS THE ONLY QUESTION A BUFFER ANSWERS.
##
## An entity that is not being sent often enough runs its interpolation buffer dry: the
## client has no future sample to walk towards, so the vehicle FREEZES, and then jumps when
## the next one lands. That is the failure a deeper buffer is meant to prevent, and it does
## not show up in a bandwidth number at all -- the bytes are identical either way.
##
## So: one remote vehicle, sampled every tick. A tick where it did not move at all is a
## tick the buffer had nothing to offer. The size of the worst step against the median step
## is how big the jump was when it finally arrived. Smooth is a ratio near one and no
## frozen ticks.
##
## It has to be an INTERPOLATED vehicle and not a predicted one. This client's own aircraft
## is predicted from its own input and is perfectly smooth by construction; measuring that
## would be measuring nothing.
func _watch() -> void:
	if _clients.is_empty():
		return
	var seen: Dictionary = {}
	var lowest: int = 0
	for row in _clients[0].vehicle_states():
		var vehicle: Dictionary = row
		if bool(vehicle["predicted"]):
			continue
		var id: int = int(vehicle["entity"])
		seen[id] = vehicle
		if lowest == 0 or id < lowest:
			lowest = id
	# THE LOWEST ID, AND THE SAME ONE ALL RUN. `vehicle_states` walks a hash map, so "the
	# first one" is a different aeroplane in every run and comparing two configurations
	# that way compares two aircraft. The lowest id is the first vehicle the server ever
	# made, which is a PLAYER's -- so it is always there, it is always flying, and it is the
	# one every configuration watches.
	if _watched == 0:
		_watched = lowest
	if not seen.has(_watched):
		return
	var at: Vector3 = (seen[_watched] as Dictionary)["position"]
	if _watched_at != Vector3.ZERO:
		var step: float = _watched_at.distance_to(at)
		_steps.append(step)
		if step < 0.0001:
			_frozen += 1
	_watched_at = at


func _report() -> void:
	_measuring = false
	var window: float = measure_seconds
	var live: int = _clients.size()
	if live == 0 or window <= 0.0:
		return
	var down_total: int = 0
	var up_total: int = 0
	var down_payload_total: int = 0
	var up_payload_total: int = 0
	var packets_total: int = 0
	var up_packets_total: int = 0
	for i in range(live):
		down_total += _down_bytes[i]
		up_total += _up_bytes[i]
		down_payload_total += _down_payload[i]
		up_payload_total += _up_payload[i]
		packets_total += _down_packets[i]
		up_packets_total += _up_packets[i]
	# ROLLBACKS, as a delta across the window rather than a total: the join itself causes a
	# burst of them and counting those would say more about spawning than about flying.
	var rewinds: int = 0
	var replayed: int = 0
	var worst: int = 0
	for i in range(live):
		var now: Dictionary = _clients[i].resim_stats()
		var was: Dictionary = _resim_at_start[i]
		rewinds += int(now["count"]) - int(was["count"])
		replayed += int(now["ticks"]) - int(was["ticks"])
		worst = maxi(worst, int(now["worst_span"]))
	var entities: int = _server.vehicle_states().size() + _server.pilot_states().size()
	var ticks: float = window * tick_hz

	print("[crowd] --- %d client(s), %.0f ms ping, %.0f Hz, %d replicated entities ---"
		% [live, ping_ms, tick_hz, entities])
	print("[crowd] server out      %8.1f kB/s total, %7.1f kB/s per client"
		% [float(down_total) / window / 1024.0, float(down_total) / window / 1024.0 / float(live)])
	print("[crowd] client out      %8.1f kB/s total, %7.1f kB/s per client"
		% [float(up_total) / window / 1024.0, float(up_total) / window / 1024.0 / float(live)])
	print("[crowd] packets         %8.1f /s down to each client, %.1f /s up from each"
		% [float(packets_total) / window / float(live),
			float(up_packets_total) / window / float(live)])
	print("[crowd] server tick     %8.3f ms of wall clock per frame" % [float(_server_usec) / ticks / 1000.0])
	print("[crowd] one client tick %8.3f ms of wall clock per frame"
		% [float(_client_usec) / ticks / 1000.0 / float(live)])
	print("[crowd] rollbacks       %8.2f /s per client, %.1f ticks replayed each, worst span %d"
		% [float(rewinds) / window / float(live),
			float(replayed) / float(maxi(rewinds, 1)), worst])
	# WHAT THE CLOCK ACTUALLY SETTLED ON, which is not what was asked for. In automatic
	# mode sync sizes the buffer from measured JITTER -- see `auto_buffered_frame_lag` --
	# so the number handed to `set_interpolation` is a starting point and this is the
	# answer. `latency_frames` is the link it measured for itself.
	var clock: Dictionary = _clients[0].timing()
	print("[crowd] the clock         buffer %d frames (target %d), latency %.1f frames, jitter %.2f"
		% [int(clock.get("buffer_frames", -1)), int(clock.get("buffer_target", -1)),
			float(clock.get("latency_frames", 0.0)), float(clock.get("jitter_frames", 0.0))])
	var smooth: Dictionary = _smoothness()
	var fastest_tick_ms := 0.0
	if not _server_tick_samples.is_empty():
		fastest_tick_ms = INF
		var block_size := maxi(1, _server_tick_samples.size() / 5)
		for block in range(5):
			var began := block * block_size
			var ended := mini(_server_tick_samples.size(), began + block_size)
			if began >= ended:
				continue
			var total := 0.0
			for i in range(began, ended):
				total += _server_tick_samples[i]
			fastest_tick_ms = minf(fastest_tick_ms, total / float(ended - began) / 1000.0)
	_server_tick_samples.sort()
	var tick_p99 := float(_server_tick_samples[mini(int(float(_server_tick_samples.size()) * 0.99),
		_server_tick_samples.size() - 1)]) / 1000.0 if not _server_tick_samples.is_empty() else 0.0
	var first_buffers: Array = []
	var last_buffers: Array = []
	var third := _buffers.size() / 3
	for i in range(third):
		first_buffers.append(_buffers[i])
		last_buffers.append(_buffers[_buffers.size() - third + i])
	first_buffers.sort()
	last_buffers.sort()
	var buffer_first := int(first_buffers[first_buffers.size() / 2]) if not first_buffers.is_empty() else -1
	var buffer_last := int(last_buffers[last_buffers.size() / 2]) if not last_buffers.is_empty() else -1
	var craft_seen := 1000000
	var truncated := 0
	for i in range(live):
		craft_seen = mini(craft_seen, _clients[i].vehicle_states().size())
		truncated += int(_clients[i].timing().get("input_packets_truncated", 0)) - _truncated_at_start[i]
	var largest_down := int(_largest_down.max()) if not _largest_down.is_empty() else 0
	var largest_up := int(_largest_up.max()) if not _largest_up.is_empty() else 0
	var largest_down_tick := int(_largest_down_tick.max()) if not _largest_down_tick.is_empty() else 0
	var largest_up_tick := int(_largest_up_tick.max()) if not _largest_up_tick.is_empty() else 0
	var budget := float(_server.net_status().get("send_budget_per_tick", 0.0))
	# THE RECEIPTS. The last gap of each craft is still open at the end of the window and counts, so a craft that stopped
	# arriving is as stale as it is and not as stale as its last closed gap.
	var receipts := 0
	var near_receipts := 0
	var near_count := 0
	var newest := int((_clients[0].received_frames() as Dictionary).get("newest", -1)) \
		if _clients[0].has_method("received_frames") else -1
	var gaps := _receipt_gaps.duplicate()
	var near_worst := _receipt_near_worst
	var far_worst := _receipt_far_worst
	for entity in _receipt_counts:
		receipts += int(_receipt_counts[entity])
		var open := newest - int(_receipt_last[entity]) if int(_receipt_last[entity]) >= 0 else int(ticks)
		if bool(_receipt_near[entity]):
			near_count += 1
			near_receipts += int(_receipt_counts[entity])
			near_worst = maxi(near_worst, open)
		else:
			far_worst = maxi(far_worst, open)
	gaps.sort()
	var watched := _receipt_counts.size()
	var far_count := watched - near_count
	var receipt_worst := maxi(near_worst, far_worst)
	var receipt_median := int(gaps[gaps.size() / 2]) if not gaps.is_empty() else -1
	var receipts_per_tick := float(receipts) / maxf(ticks, 1.0)
	# What a record really cost, and the gap a fair rotation of every watched craft through that many a tick gives.
	var measured_bytes_per_update := float(down_payload_total) / float(live) / float(maxi(1, receipts)) \
		if receipts > 0 else 0.0
	var predicted_gap := maxi(1, int(ceil(float(watched) / receipts_per_tick))) if receipts > 0 else -1
	var trace_dropped := int(_server.trace_events_dropped()) - _trace_dropped_at_start \
		if trace_one_client and _server.has_method("trace_events_dropped") else 0
	# WHAT THE PRIORITIZER COSTS: sync's calls a tick over the window, and one call's price from the world's own probe,
	# every seated client against every replicated entity, with the setting as it stands.
	var calls_a_tick := -1.0
	var ns_a_call := -1.0
	if _server.has_method("priority_sphere"):
		var asked: Dictionary = _server.priority_sphere()
		calls_a_tick = float(int(asked["calls"]) - _priority_calls_at_start) \
			/ float(maxi(1, int(asked["ticks"]) - _priority_ticks_at_start))
		ns_a_call = float(_server.priority_probe(20)["ns_per_call"])
	last_report = {"craft": ai_craft, "peers": live, "link": _one_way_ticks(),
		"down_kB_s_per_client": float(down_total) / window / 1024.0 / float(live),
		"down_packets_per_tick": float(packets_total) / ticks / float(live),
		"largest_down_B": largest_down,
		"largest_down_tick_B": largest_down_tick,
		"down_payload_B_tick": float(down_payload_total) / ticks / float(live),
		"up_kB_s_per_client": float(up_total) / window / 1024.0 / float(live),
		"largest_up_B": largest_up, "largest_up_tick_B": largest_up_tick,
		"up_payload_B_tick": float(up_payload_total) / ticks / float(live),
		"server_out_kB_s": float(down_total) / window / 1024.0,
		"budget_B_tick": budget,
		"worst_update_gap_ticks": receipt_worst,
		"receipt_gap_worst_ticks": receipt_worst,
		"receipt_gap_median_ticks": receipt_median,
		"receipts_per_s_per_craft": float(receipts) / window / float(maxi(1, watched)),
		"receipts_per_tick": receipts_per_tick,
		"watched_craft": watched,
		"near_craft": near_count, "far_craft": far_count,
		"near_gap_worst_ticks": near_worst, "far_gap_worst_ticks": far_worst,
		"near_receipts_per_s_per_craft": float(near_receipts) / window / float(maxi(1, near_count)),
		"far_receipts_per_s_per_craft": float(receipts - near_receipts) / window / float(maxi(1, far_count)),
		"serialised_gap_worst_ticks": _worst_update_gap,
		"predicted_gap_ticks": predicted_gap,
		"measured_bytes_per_update": measured_bytes_per_update,
		"serialised_events": _sent_events, "trace_dropped": trace_dropped,
		"buffer_first": buffer_first, "buffer_last": buffer_last,
		"rollbacks_per_s": float(rewinds) / window / float(live), "starved": _starved,
		"truncated": truncated, "server_tick_ms": fastest_tick_ms,
		"server_tick_mean_ms": float(_server_usec) / ticks / 1000.0,
		"server_tick_p99_ms": tick_p99, "craft_seen": craft_seen,
		"timing_valid": not trace_one_client,
		"out_of_band": _stack_out_of_band(), "lost": _stack_lost(), "dropped": _dropped,
		"sphere": sphere_on, "prioritizer_calls_tick": calls_a_tick, "prioritizer_ns_call": ns_a_call,
		"tracked": tracked_poses, "pose_lod": pose_lod_on,
		"pose_masked_pairs": int(_server.pose_lod().get("masked_pairs", 0)) if _server.has_method("pose_lod") else -1}
	print("BULK craft=%d peers=%d link=%d down_kB_s_per_client=%.1f down_pkts_per_tick=%.2f largest_down_B=%d largest_down_tick_B=%d up_kB_s_per_client=%.1f server_out_kB_s=%.1f budget_B_tick=%.0f worst_update_gap_ticks=%d median_gap_ticks=%d predicted_gap_ticks=%d receipts_s_craft=%.2f watched=%d near=%d far=%d near_gap=%d far_gap=%d near_receipts_s=%.2f far_receipts_s=%.2f bytes_update=%.1f serialised_gap=%d serialised=%d/%d buffer_frames=%d->%d rollbacks_per_s=%.2f starved=%d truncated=%d server_tick_ms=%.3f/%.3f craft_seen=%d out_of_band=%d lost=%d sphere=%s prioritizer_calls_tick=%.1f prioritizer_ns_call=%.1f tracked=%s pose_lod=%s pose_masked_pairs=%d" % [
		ai_craft, live, _one_way_ticks(), last_report.down_kB_s_per_client,
		last_report.down_packets_per_tick, largest_down, largest_down_tick,
		last_report.up_kB_s_per_client, last_report.server_out_kB_s, budget,
		receipt_worst, receipt_median, predicted_gap, last_report.receipts_per_s_per_craft, watched, near_count, far_count,
		near_worst, far_worst, last_report.near_receipts_per_s_per_craft, last_report.far_receipts_per_s_per_craft,
		measured_bytes_per_update, _worst_update_gap, _sent_events, trace_dropped,
		buffer_first, buffer_last, last_report.rollbacks_per_s, _starved, truncated,
		fastest_tick_ms, tick_p99, craft_seen, last_report.out_of_band, last_report.lost, "on" if sphere_on else "off",
		calls_a_tick, ns_a_call, "on" if tracked_poses else "off", "on" if pose_lod_on else "off",
		int(_server.pose_lod().get("masked_pairs", 0)) if _server.has_method("pose_lod") else -1])
	print("[crowd] a watched craft %8.1f%% of ticks frozen, 99th step %.1fx the median (%.4f m)"
		% [smooth["frozen_percent"], smooth["jump_ratio"], smooth["median_step"]])
	if loss_percent > 0.0:
		print("[crowd] dropped         %8d packet(s) at %.1f%% loss" % [_dropped, loss_percent])
	# ONE MACHINE-READABLE LINE, for the sweep in crowd.sh to make a table out of.
	print("CROWD clients=%d ping=%.0f tick=%.0f buffer=%d auto=%d entities=%d down_kBps=%.1f down_per_client_kBps=%.1f up_per_client_kBps=%.1f pkts_per_client=%.0f server_ms=%.3f rollbacks_per_s=%.2f replay_ticks=%.1f worst_span=%d frozen_pct=%.1f jump_ratio=%.1f clock_buffer=%d"
		% [live, ping_ms, tick_hz, buffer_frames, 1 if auto_buffer else 0, entities,
			float(down_total) / window / 1024.0,
			float(down_total) / window / 1024.0 / float(live),
			float(up_total) / window / 1024.0 / float(live),
			float(packets_total) / window / float(live),
			float(_server_usec) / ticks / 1000.0,
			float(rewinds) / window / float(live),
			float(replayed) / float(maxi(rewinds, 1)), worst,
			smooth["frozen_percent"], smooth["jump_ratio"],
			int(clock.get("buffer_frames", -1))])


## HOW BADLY THE WATCHED CRAFT STUTTERED. Percent of ticks it did not move at all, and the
## worst step it took against the median one.
##
## The median rather than the mean, because the mean is dragged up by the very jumps being
## measured -- a vehicle that freezes for eleven ticks and then moves eleven frames' worth
## has a perfectly ordinary mean step and is unwatchable.
func _smoothness() -> Dictionary:
	if _steps.size() < 8:
		return {"frozen_percent": 0.0, "jump_ratio": 0.0, "median_step": 0.0}
	var sorted: Array = []
	for step in _steps:
		sorted.append(step)
	sorted.sort()
	var median: float = float(sorted[sorted.size() / 2])
	# THE 99th AND NOT THE LARGEST. One rollback correction landing inside the window is a
	# single enormous step that says nothing about how the aeroplane looked for the other
	# five hundred frames, and a maximum is entirely at its mercy.
	var high: float = float(sorted[mini(int(float(sorted.size()) * 0.99), sorted.size() - 1)])
	return {
		"frozen_percent": 100.0 * float(_frozen) / float(_steps.size()),
		"jump_ratio": high / maxf(median, 0.000001),
		"median_step": median,
	}


func _stack_out_of_band() -> int:
	if _stack == null:
		return 0
	var outside := 0
	for entity in _stack.entities():
		var state: Dictionary = _server.vehicle_state(entity)
		if state.is_empty() or absf((state["position"] as Vector3).y - _stack.assigned_altitude(entity)) \
				> _stack.layer_spacing() * 0.5:
			outside += 1
	return outside


func _stack_lost() -> int:
	if _stack == null:
		return 0
	var lost := 0
	var stall := float(_server.handling(PLANE).get("stall_speed", 0.0))
	for entity in _stack.entities():
		var state: Dictionary = _server.vehicle_state(entity)
		if state.is_empty() or (state["velocity"] as Vector3).length() < stall:
			lost += 1
	return lost


func _tear_down() -> void:
	for world in _clients:
		world.teardown()
	if _server != null:
		_server.teardown()
	if _stack != null:
		_stack.free()
		_stack = null
