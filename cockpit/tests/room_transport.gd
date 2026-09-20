extends Node
## A real ashiato-sync loopback: the request enters a seated Segway client's ControlInput,
## crosses server receive_packet(), then returns as RoomControlPage replication.  No server API
## writes the endpoint in this suite.
const POD := 0
const SEGWAY := 21
const DT := 1.0 / 60.0
const REVISION := 1
const COUNT := 100
var server: Object
var clients: Dictionary = {}
var failures: PackedStringArray = []

func controls() -> Dictionary:
	return {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0}

func check(label: String, ok: bool, detail: String = "") -> void:
	print("[room_transport] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: failures.append(label)

func state_is(values: Array, changed: Dictionary) -> bool:
	if values.size() != COUNT: return false
	for index in COUNT:
		if int(values[index]) != int(changed.get(index, 0)): return false
	return true

## Delivers every actual outgoing packet. `drive_client` is only used while establishing
## the normal pilot input stream; submissions below run idle to prove command riding.
func pump(ticks: int, drive_client: Object = null, remembered: Array = []) -> void:
	for _tick in ticks:
		if drive_client != null: drive_client.set_input(controls())
		server.tick(DT)
		for client in clients.values(): client.tick(DT)
		for packet in server.take_outbound():
			var recipient: Object = clients.get(int(packet["peer"]))
			if recipient != null: recipient.deliver(0, packet["bytes"], packet["bits"])
		for peer in clients:
			var sender: Object = clients[peer]
			for packet in sender.take_outbound():
				if int(peer) == 1 and remembered != null:
					remembered.append({"bytes": packet["bytes"], "bits": packet["bits"]})
				server.deliver(int(peer), packet["bytes"], packet["bits"])

func configure(world: Object) -> bool:
	return world.room_control_configure("alpha", REVISION, COUNT) and world.room_control_configure("bravo", REVISION, COUNT)

func _ready() -> void:
	server = ClassDB.instantiate("CockpitWorld")
	var pilot_client: Object = ClassDB.instantiate("CockpitWorld")
	clients[1] = pilot_client
	server.start(0); pilot_client.start(1)
	for world in [server, pilot_client]: world.add_static_box(Vector3(0, -2, 0), Vector3(400, 2, 400))
	pump(90)
	var me: int = pilot_client.local_client_id()
	check("client_handshake", me == 1, "client id %d" % me)
	check("room_schema", configure(server) and configure(pilot_client), "two 100-endpoint rooms")

	# Match the established crew path: make the local pilot, wait for the replication
	# record, then assign it to the already-authored Segway seat.
	var segway: int = server.spawn_vehicle(SEGWAY, Vector3(-16, 0.5, 0), 0.0, Vector3.ZERO)
	server.spawn_pilot(me, POD, Vector3(60, 4, 60), 0.0, Vector3.ZERO)
	pump(20, pilot_client)
	check("seat_ownership", bool(server.seat_client(me, segway, 0)), "Segway %d in alpha" % segway)
	pump(40, pilot_client)

	var first_packets: Array = []
	check("submit_alpha", pilot_client.room_control_submit("alpha", REVISION, 7, 201), "idle panel request")
	pump(40, null, first_packets)
	check("server_applies_only_alpha_endpoint", state_is(server.room_control_state("alpha", REVISION), {7: 201}), "endpoint 7 = 201")
	check("client_gets_alpha_page", state_is(pilot_client.room_control_state("alpha", REVISION), {7: 201}), "replicated")
	check("bravo_isolated", state_is(server.room_control_state("bravo", REVISION), {}) and state_is(pilot_client.room_control_state("bravo", REVISION), {}), "alpha seat cannot change bravo")
	check("wrong_revision_refused_at_admission", not pilot_client.room_control_submit("alpha", REVISION + 1, 7, 9), "stale schema")
	check("other_room_refused_by_server", pilot_client.room_control_submit("bravo", REVISION, 7, 9), "request admitted; server location check")
	pump(30)
	check("other_room_stays_unchanged", state_is(server.room_control_state("bravo", REVISION), {}), "server rejected alpha Segway request")

	check("newer_request", pilot_client.room_control_submit("alpha", REVISION, 7, 203), "sequence advances")
	pump(40)
	check("newer_request_wins", state_is(server.room_control_state("alpha", REVISION), {7: 203}), "endpoint changed exactly once")
	check("captured_real_client_packets", not first_packets.is_empty(), "%d packet(s)" % first_packets.size())
	# Replay already-delivered client transport packets after a newer command. This is the
	# normal server decode/packet path, and it must not revive the earlier value.
	for packet in first_packets: server.deliver(1, packet["bytes"], packet["bits"])
	pump(20)
	check("duplicate_packet_does_not_revive_old_value", state_is(server.room_control_state("alpha", REVISION), {7: 203}), "old packet ignored")

	# A late join has no local write; it receives every page from the normal server baseline.
	var late: Object = ClassDB.instantiate("CockpitWorld")
	clients[2] = late
	late.start(2); late.add_static_box(Vector3(0, -2, 0), Vector3(400, 2, 400))
	check("late_schema", configure(late), "same immutable schema")
	pump(100)
	check("late_join_gets_pages", state_is(late.room_control_state("alpha", REVISION), {7: 203}), "full 100 endpoint page set")
	check("late_join_room_isolation", state_is(late.room_control_state("bravo", REVISION), {}), "no alpha bleed")

	for world in clients.values(): world.teardown()
	server.teardown()
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL %s" % ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
