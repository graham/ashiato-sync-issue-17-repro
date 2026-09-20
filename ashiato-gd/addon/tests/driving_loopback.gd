extends Node
## A server and a client in one process, wired to each other through a delayed link.
##
##   Godot --path addon --headless res://tests/driving_loopback.tscn
##
## This is the test the whole driving foundation exists to pass. It drives a car on the
## client, ships the input to the server, ships authoritative state back, and asks the
## three questions that decide whether the game will feel right:
##
##   1. does the client's own car MOVE IMMEDIATELY, before the server has replied?
##      (that is prediction; without it, steering waits a round trip)
##   2. does the server converge on the same place the client predicted?
##      (if not, the two simulations disagree and it will rubber-band forever)
##   3. does a rollback leave the car somewhere sane rather than teleporting?
##
## Packets are carried by this script rather than by the extension, which is why this can
## run headless with no sockets and no Steam. The real game hands the same byte arrays to
## SteamMultiplayerPeer instead.
##
## Read RESULT=, not the exit code.

const DT: float = 1.0 / 60.0
## One-way delay in ticks. 4 ticks each way is ~133 ms round trip -- a bad-but-real
## connection, and enough that unpredicted input would be obviously late.
const LINK_DELAY_TICKS: int = 4
const CLIENT_ID: int = 1

var _failures: PackedStringArray = []
## [[deliver_at_tick, to_server, bytes], ...]
var _in_flight: Array = []
var _tick: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[driving] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _pump(server, client) -> void:
	# Collect anything either side wants to send, and stamp it with an arrival tick.
	for packet in server.take_outbound():
		_in_flight.append([_tick + LINK_DELAY_TICKS, false, packet["bytes"], packet["bits"]])
	for packet in client.take_outbound():
		_in_flight.append([_tick + LINK_DELAY_TICKS, true, packet["bytes"], packet["bits"]])

	var still_flying: Array = []
	for entry in _in_flight:
		if entry[0] <= _tick:
			if entry[1]:
				server.deliver(CLIENT_ID, entry[2], entry[3])
			else:
				client.deliver(0, entry[2], entry[3])
		else:
			still_flying.append(entry)
	_in_flight = still_flying


func _advance(server, client, ticks: int) -> void:
	for i in range(ticks):
		_tick += 1
		server.tick(DT)
		client.tick(DT)
		_pump(server, client)


func _ready() -> void:
	if not ClassDB.class_exists("DrivingWorld"):
		print("[driving] DrivingWorld not registered; build with -WithDriving")
		_finish()
		return

	var server = ClassDB.instantiate("DrivingWorld")
	var client = ClassDB.instantiate("DrivingWorld")
	_check("server_starts", server.start(0), "client_id 0 means server")
	_check("client_starts", client.start(CLIENT_ID), "client_id %d" % CLIENT_ID)
	_check("roles_differ", server.is_server() and not client.is_server(), "one of each")

	# NO add_client(). Registering a client by hand and then pushing updates at it before
	# it has handshaked is a hard crash inside sync -- the client has no session to decode
	# against. The client introduces itself; the server accepts by default.
	var car: int = server.spawn_car(CLIENT_ID, Vector3(0, 0.5, 0))
	_check("car_spawned", car != 0, "entity=%d" % car)

	# Let the handshake complete and the car replicate down before touching the throttle.
	_advance(server, client, 60)
	var status: Dictionary = client.net_status()
	_check("client_completed_handshake", status.get("connected", false),
		"state=%s id=%s, server sees %s client(s)" %
			[status.get("state", "?"), status.get("client_id", "?"),
			 server.net_status().get("clients", "?")])

	var seen: PackedInt64Array = client.car_entities()
	_check("car_reached_the_client", seen.size() > 0,
		"%d car(s) known to the client" % seen.size())

	# ---- 1. prediction: the client must react before the server can possibly reply ----
	#
	# Measured from a ROLLING start, not a standstill. From rest a car covers well under a
	# millimetre in three ticks, so testing there measures the accelerator curve rather
	# than whether prediction is happening at all.
	var client_cars: PackedInt64Array = client.car_entities()
	client.set_input(1.0, 0.0, false)
	_advance(server, client, 60)

	var rolling: Dictionary = client.car_state(client_cars[0])
	var rolling_pos: Vector3 = rolling.get("position", Vector3())
	var rolling_speed: float = (rolling.get("velocity", Vector3()) as Vector3).length()
	_check("car_is_rolling", rolling_speed > 0.5, "%.2f m/s before the prediction test" % rolling_speed)

	# Now yank the wheel. The client should turn IMMEDIATELY; the server cannot even have
	# heard about this input yet, let alone sent back a correction.
	var yaw_before: float = rolling.get("yaw", 0.0)
	client.set_input(1.0, 1.0, false)
	_advance(server, client, LINK_DELAY_TICKS - 1)

	var predicted: Dictionary = client.car_state(client_cars[0])
	var predicted_yaw_change: float = absf(predicted.get("yaw", 0.0) - yaw_before)
	var predicted_move: float = (predicted.get("position", rolling_pos) as Vector3).distance_to(rolling_pos)

	_check("client_predicts_before_the_server_answers",
		predicted_move > 0.01 or predicted_yaw_change > 0.001,
		"moved %.4f m and turned %.5f rad in %d ticks; round trip is %d" %
			[predicted_move, predicted_yaw_change, LINK_DELAY_TICKS - 1, LINK_DELAY_TICKS * 2])
	var start_pos: Vector3 = Vector3(0, 0.5, 0)

	# ---- 2. the server must agree, or it rubber-bands ----
	# Hold the throttle long enough for input to reach the server, be simulated, and come
	# back as authoritative state.
	_advance(server, client, 60)

	var server_state: Dictionary = server.car_state(car)
	var server_pos: Vector3 = server_state.get("position", Vector3())
	var server_move: float = server_pos.distance_to(start_pos)
	_check("server_simulated_the_client_input", server_move > 0.5,
		"server car travelled %.3f m, so the input crossed the link" % server_move)

	var client_now: Dictionary = {}
	if client_cars.size() > 0:
		client_now = client.car_state(client_cars[0])
	var client_pos: Vector3 = client_now.get("position", Vector3())
	var disagreement: float = client_pos.distance_to(server_pos)

	# The client is AHEAD of the server by roughly the one-way delay, so it should not
	# match exactly -- it should be close, and ahead rather than behind. A car at these
	# speeds covers well under a car length in that window.
	print("[driving] client %.3f m from server after a second of driving" % disagreement)
	_check("prediction_tracks_the_server", disagreement < 6.0,
		"%.3f m apart, budget 6.0 (client leads by ~%d ticks)" % [disagreement, LINK_DELAY_TICKS])

	_check("both_sides_are_moving", server_move > 0.5 and client_pos.length() > 0.0,
		"server %.2f m, client at %s" % [server_move, client_pos])

	# ---- 3. a correction must not teleport the car ----
	# Let go of the throttle and let the two settle; if rollback were mishandled the car
	# would jump somewhere unrelated rather than coasting to a stop.
	var before_release: Vector3 = client_pos
	client.set_input(0.0, 0.0, false)
	_advance(server, client, 45)

	var settled: Dictionary = {}
	if client_cars.size() > 0:
		settled = client.car_state(client_cars[0])
	var settled_pos: Vector3 = settled.get("position", Vector3())
	var coast: float = settled_pos.distance_to(before_release)
	_check("corrections_do_not_teleport", coast < 40.0,
		"car moved %.3f m while coasting to a stop, not a jump" % coast)
	_check("car_stays_on_the_ground", absf(settled_pos.y) < 5.0,
		"y=%.3f, still on the track" % settled_pos.y)

	# ---- steering, so the yaw path is exercised too ----
	client.set_input(1.0, 1.0, false)
	_advance(server, client, 60)
	var turned: Dictionary = server.car_state(car)
	_check("steering_changes_heading", absf(turned.get("yaw", 0.0)) > 0.01,
		"server yaw %.4f rad" % turned.get("yaw", 0.0))

	# ---- 4. smooth presentation: fractional-tick sampling and error blending ----
	#
	# These go together. set_fractional_tick_sampled() REFUSES a component that cannot
	# compute, apply and blend out an error -- sampling a car between frames is pointless
	# if a correction would teleport it anyway -- so a false here means CarState is
	# missing the error hooks and the renderer is back to lerping two ECS ticks by hand.
	var timing: Dictionary = client.timing()
	_check("carstate_is_sampled", timing.get("sampling_marked", false),
		"set_fractional_tick_sampled accepted CarState, so it has the error hooks")

	var sampled: Array = client.sampled_cars()
	_check("sampling_returns_cars", sampled.size() > 0,
		"%d car(s) sampled at the current fractional frame" % sampled.size())
	if sampled.size() > 0:
		var first: Dictionary = sampled[0]
		_check("sample_has_a_value", first.get("sampled", false),
			"a real value, not a placeholder")
		_check("own_car_is_predicted", first.get("predicted", false),
			"our car samples from the PREDICTED timeline, not the buffered one")

	_check("timing_is_reported",
		timing.get("packets_received", 0) > 0 and timing.has("buffer_frames"),
		"latency %.1f frames, buffer %s, lead %s" %
			[timing.get("latency_frames", 0.0), timing.get("buffer_frames", "?"),
			 timing.get("prediction_lead", "?")])

	server.teardown()
	client.teardown()
	_finish()


func _finish() -> void:
	print("[driving] RESULT=%s" % (
		"PASS" if _failures.is_empty() else "FAIL %s" % [_failures]))
	get_tree().quit(0 if _failures.is_empty() else 1)
