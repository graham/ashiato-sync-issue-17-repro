extends Node
## Real two-peer RoomControlPage transport proof.  Every state change below starts at a
## client `room_control_submit`, travels in ControlInput packets, is authorised by the
## server's seated-Segway room check, then comes back through ordinary page replication.
## There are no direct server endpoint writes in this harness.

const POD := 0
const SEGWAY := 21
const REVISION := 1
const DT := 1.0 / 60.0
const DENSITIES: PackedInt32Array = [100, 250, 500]

var server: Object
var alpha: Object
var bravo: Object
var clients: Dictionary = {}
var failures: PackedStringArray = []
var packets := 0
var payload_bytes := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	print("[room_load_proof] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures.append(label)


func _controls() -> Dictionary:
	return {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0}


func _expected(count: int, salt: int) -> PackedByteArray:
	var values := PackedByteArray()
	values.resize(count)
	for index in count:
		# Never zero: a missed endpoint cannot hide in a zero-filled page.
		values[index] = 1 + ((index * 37 + salt * 19) % 255)
	return values


func _pump(ticks: int, capture_alpha: Array = []) -> void:
	for _step in ticks:
		for client in clients.values():
			client.set_input(_controls())
		server.tick(DT)
		for client in clients.values():
			client.tick(DT)
		for packet in server.take_outbound():
			packets += 1
			payload_bytes += int(ceil(float(int(packet["bits"])) / 8.0))
			var target: Object = clients.get(int(packet["peer"]))
			if target != null:
				target.deliver(0, packet["bytes"], packet["bits"])
		for peer in clients:
			var source: Object = clients[peer]
			for packet in source.take_outbound():
				packets += 1
				payload_bytes += int(ceil(float(int(packet["bits"])) / 8.0))
				if int(peer) == 1 and capture_alpha != null:
					capture_alpha.append({"bytes": packet["bytes"], "bits": packet["bits"]})
				server.deliver(int(peer), packet["bytes"], packet["bits"])


func _configure(world: Object, count: int) -> bool:
	return world.room_control_configure("alpha", REVISION, count) \
		and world.room_control_configure("bravo", REVISION, count)


func _stand_up(count: int) -> bool:
	server = ClassDB.instantiate("CockpitWorld")
	alpha = ClassDB.instantiate("CockpitWorld")
	bravo = ClassDB.instantiate("CockpitWorld")
	clients = {1: alpha, 2: bravo}
	server.start(0)
	alpha.start(1)
	bravo.start(2)
	for world in [server, alpha, bravo]:
		world.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(400.0, 2.0, 400.0))
	_pump(100)
	if int(alpha.local_client_id()) != 1 or int(bravo.local_client_id()) != 2:
		return false
	for world in [server, alpha, bravo]:
		if not _configure(world, count):
			return false
	var alpha_segway: int = server.spawn_vehicle(SEGWAY, Vector3(-16.0, 0.5, 0.0), 0.0, Vector3.ZERO)
	var bravo_segway: int = server.spawn_vehicle(SEGWAY, Vector3(16.0, 0.5, 0.0), 0.0, Vector3.ZERO)
	server.spawn_pilot(1, POD, Vector3(60.0, 4.0, 60.0), 0.0, Vector3.ZERO)
	server.spawn_pilot(2, POD, Vector3(-60.0, 4.0, -60.0), 0.0, Vector3.ZERO)
	_pump(40)
	if not bool(server.seat_client(1, alpha_segway, 0)) or not bool(server.seat_client(2, bravo_segway, 0)):
		return false
	_pump(60)
	return true


func _tear_down() -> void:
	for client in clients.values():
		client.teardown()
	clients = {}
	if server != null:
		server.teardown()
	server = null
	alpha = null
	bravo = null


func _state(world: Object, room: String) -> PackedByteArray:
	return world.room_control_state(room, REVISION) as PackedByteArray


func _all_match(a: PackedByteArray, b: PackedByteArray, c: PackedByteArray, wanted: PackedByteArray) -> bool:
	return a == wanted and b == wanted and c == wanted


func _wait_for(alpha_values: PackedByteArray, bravo_values: PackedByteArray, limit: int) -> Dictionary:
	var began := Time.get_ticks_usec()
	for tick in limit:
		_pump(1)
		if _all_match(_state(server, "alpha"), _state(alpha, "alpha"), _state(bravo, "alpha"), alpha_values) \
			and _all_match(_state(server, "bravo"), _state(alpha, "bravo"), _state(bravo, "bravo"), bravo_values):
			return {"converged": true, "ticks": tick + 1,
				"usec": Time.get_ticks_usec() - began}
	return {"converged": false, "ticks": limit, "usec": Time.get_ticks_usec() - began}


func _two_peer_and_adversarial() -> void:
	_check("two_peer_setup", _stand_up(100), "two concurrent seated clients")
	if server == null:
		return
	var zeros := PackedByteArray(); zeros.resize(100)
	var first_packets: Array = []
	_check("alpha_request_admitted", alpha.room_control_submit("alpha", REVISION, 7, 101), "client queue")
	_pump(50, first_packets)
	var alpha_once := zeros.duplicate(); alpha_once[7] = 101
	_check("alpha_converges_for_both_peers", _all_match(_state(server, "alpha"), _state(alpha, "alpha"),
		bravo.room_control_state("alpha", REVISION), alpha_once), "observer is seated in bravo")
	_check("bravo_remains_unchanged", _all_match(_state(server, "bravo"), _state(alpha, "bravo"),
		_state(bravo, "bravo"), zeros), "no cross-room write")
	_check("bad_revision_refused_locally", not alpha.room_control_submit("alpha", REVISION + 1, 7, 5), "schema admission")
	_check("bad_endpoint_refused_locally", not alpha.room_control_submit("alpha", REVISION, 100, 5), "range admission")
	_check("cross_room_request_enters_input_stream", alpha.room_control_submit("bravo", REVISION, 7, 5), "server must decide location")
	_pump(50)
	_check("cross_room_refused_by_server", _all_match(_state(server, "bravo"), _state(alpha, "bravo"),
		_state(bravo, "bravo"), zeros), "authority did not cross rooms")
	_check("newer_request", alpha.room_control_submit("alpha", REVISION, 7, 202), "sequence advances")
	_pump(50)
	for packet in first_packets:
		server.deliver(1, packet["bytes"], packet["bits"])
	_pump(30)
	var newer := zeros.duplicate(); newer[7] = 202
	_check("replayed_packet_cannot_revive_old_state", _state(server, "alpha") == newer, "server sequence gate")
	var metrics: Dictionary = server.room_control_metrics()
	# The replay assertion above reaches the normal packet decoder.  Sync may discard its
	# duplicate before CockpitWorld sees it, so a world-level dedup count of zero is valid;
	# record the counter rather than inventing a second delivery path to make it non-zero.
	_check("server_reports_actual_refusal", int(metrics.get("refused", 0)) >= 1, "%s" % [metrics])
	_tear_down()


func _load_density(count: int) -> void:
	_check("density_%d_setup" % count, _stand_up(count), "two room peers")
	if server == null:
		return
	var alpha_values := _expected(count, 3)
	var bravo_values := _expected(count, 11)
	packets = 0
	payload_bytes = 0
	var admitted := true
	for index in count:
		admitted = alpha.room_control_submit("alpha", REVISION, index, alpha_values[index]) and admitted
		admitted = bravo.room_control_submit("bravo", REVISION, index, bravo_values[index]) and admitted
	_check("density_%d_all_requests_admitted" % count, admitted, "two client queues")
	var measured: Dictionary = _wait_for(alpha_values, bravo_values, count * 4 + 500)
	var metrics: Dictionary = server.room_control_metrics()
	var page_count := int(metrics.get("page_count", -1))
	_check("density_%d_converges" % count, bool(measured.get("converged", false)), "%s" % [measured])
	_check("density_%d_server_accepts_every_distinct_endpoint" % count, int(metrics.get("accepted", -1)) == count * 2,
		"%s" % [metrics])
	_check("density_%d_page_count" % count, page_count == 2 * int(ceil(float(count) / 32.0)), "%d pages" % page_count)
	_check("density_%d_real_packets" % count, packets > 0 and payload_bytes > 0,
		"%d packets, %d payload bytes, %d ticks, %d usec" % [packets, payload_bytes,
			int(measured.get("ticks", -1)), int(measured.get("usec", -1))])
	print("[room_load_proof] density=%d accepted=%d deduplicated=%d refused=%d pages=%d packets=%d payload_bytes=%d convergence_ticks=%d tick_wall_usec=%d" % [
		count, int(metrics.get("accepted", 0)), int(metrics.get("deduplicated", 0)), int(metrics.get("refused", 0)),
		page_count, packets, payload_bytes, int(measured.get("ticks", -1)), int(measured.get("usec", -1))])
	_tear_down()


func _queue_saturation_and_late_join() -> void:
	_check("saturation_setup", _stand_up(500), "one alpha client has 500 legitimate endpoints")
	if server == null:
		return
	# 500 Alpha + 13 forged Bravo addresses fill the 512 request backlog behind the
	# currently-riding item.  The next distinct request must be refused, not overwrite one.
	var admitted := 0
	for index in 500:
		if alpha.room_control_submit("alpha", REVISION, index, 1 + (index % 255)):
			admitted += 1
	for index in 13:
		if alpha.room_control_submit("bravo", REVISION, index, 200):
			admitted += 1
	_check("queue_saturation_refuses_next_distinct_request", not alpha.room_control_submit("bravo", REVISION, 13, 200),
		"%d admitted before refusal" % admitted)
	var client_metrics: Dictionary = alpha.room_control_metrics()
	_check("queue_saturation_is_visible_in_metrics", int(client_metrics.get("refused", 0)) >= 1,
		"%s" % [client_metrics])
	# Drain the legitimate batch, then attach a fresh peer.  It has never made a request;
	# any state it sees came from the regular replicated baseline, not an API write.
	_pump(3000)
	var late: Object = ClassDB.instantiate("CockpitWorld")
	clients[3] = late
	late.start(3)
	late.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(400.0, 2.0, 400.0))
	_check("late_join_schema", _configure(late, 500), "same immutable registry")
	_pump(160)
	_check("late_join_snapshot_has_authoritative_alpha", _state(late, "alpha") == _state(server, "alpha"),
		"ordinary page baseline")
	_check("late_join_snapshot_keeps_bravo_isolated", _state(late, "bravo") == _state(server, "bravo"),
		"ordinary page baseline")
	late.teardown()
	clients.erase(3)
	# Remove the original sync client, then reconnect on the same peer/client id.  This is
	# deliberately different from the late join above: `remove_client` clears server-side
	# sequence state so an old stream cannot poison the replacement client's first request.
	_check("server_removes_departed_client", server.remove_client(1), "forget sequence state before id reuse")
	alpha.teardown()
	clients.erase(1)
	var reconnected: Object = ClassDB.instantiate("CockpitWorld")
	clients[1] = reconnected
	reconnected.start(1)
	reconnected.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(400.0, 2.0, 400.0))
	_check("reconnect_schema", _configure(reconnected, 500), "same registry on reused id")
	_pump(160)
	_check("reconnect_receives_authoritative_baseline", _state(reconnected, "alpha") == _state(server, "alpha")
		and _state(reconnected, "bravo") == _state(server, "bravo"), "replacement peer converges")
	reconnected.teardown()
	clients.erase(1)
	_tear_down()


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "build with -WithCockpit")
	else:
		_two_peer_and_adversarial()
		for count in DENSITIES:
			_load_density(count)
		_queue_saturation_and_late_join()
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL %s" % ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
