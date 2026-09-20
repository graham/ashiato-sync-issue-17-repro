extends Node
## Deterministic authority and wire gate for the multiplayer builder. The existing
## two_peers/lobby_peers suites own process/socket admission; this drives builder documents
## through the real selective-repeat stream and strict semantic validator.

class FakeServer:
	extends RefCounted
	var seats := PackedInt64Array([20, 21])
	func client_of_peer(peer: int) -> int: return {2: 20, 3: 21}.get(peer, 0)
	func vehicle_seats(_entity: int) -> PackedInt64Array: return seats

var failures: PackedStringArray = []
func _check(label: String, ok: bool, detail: String) -> void:
	print("[builder_authority] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: failures.append(label)


func _ready() -> void:
	_check("package_hashes_ignore_checkout_line_endings",
		CraftPackage._hash("{\n  \"seat\": 0\n}") == CraftPackage._hash("{\r\n  \"seat\": 0\r\n}"),
		"LF and CRLF are the same JSON document")
	_check("a_child_process_test_flag_keeps_packages_out_of_player_files",
		CraftPackage.folder_for(PackedStringArray(), PackedStringArray(["--builder-test-files=1"])) \
			== CraftPackage.TEST_ROOT + CockpitLayout.test_slot(), "bare -- arguments are user arguments")
	var server := FakeServer.new()
	_check("only_the_actual_occupant_owns_a_station",
		BuilderAuthority.occupant_may_edit(server, 2, 0, 99, 0)
		and not BuilderAuthority.occupant_may_edit(server, 2, 0, 99, 1), "peer 2 maps to client 20")
	var most_bytes := 0; var most_kind := -1
	for kind in VehicleCatalogue.pilotable_kinds():
		if kind == Sim.Kind.SEGWAY: continue
		var snapshot := _snapshot(kind, 99)
		var bytes := BuilderAuthority.encode(snapshot)
		if bytes.size() > most_bytes: most_bytes = bytes.size(); most_kind = kind
		_check("%s_snapshot_survives_encode_decode_validation" % Sim.kind_name(kind),
			BuilderAuthority.envelope_is_valid(bytes), "%d bytes" % bytes.size())
	_check("the_largest_all_seat_snapshot_fits_the_long_message",
		most_bytes <= LongTransfer.MOST_BYTES, "%s %d/%d bytes" % [Sim.kind_name(most_kind), most_bytes, LongTransfer.MOST_BYTES])
	_cross_the_real_stream(_snapshot(Sim.Kind.PLANE, 99))
	_refusals()
	var inside := BuilderRoom.inside(); var worst := Vector3.ZERO
	for kind in VehicleCatalogue.pilotable_kinds():
		if kind == Sim.Kind.SEGWAY: continue
		var visual := BuilderRoom.conservative_visual_half(kind); worst = worst.max(visual)
	_check("every_offered_craft_fits_inside_the_builder_room",
		worst.x < inside.x and worst.y < inside.y and worst.z < inside.z,
		"visual half %s, room half %s" % [worst, inside])
	var most_seats := 0
	for offered in VehicleCatalogue.pilotable_kinds():
		if offered != Sim.Kind.SEGWAY:
			most_seats = maxi(most_seats, (Sim.geometry_of(offered).get("seat_poses", []) as Array).size())
	_check("the_builder_board_offers_every_seat_of_the_largest_craft",
		BuilderMenu.offered_seat_capacity() == most_seats, "%d seat buttons" % most_seats)
	print("[builder_authority] RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _snapshot(kind: int, entity: int) -> Dictionary:
	var layouts := {}; var revisions := {}
	for seat in range((Sim.geometry_of(kind).get("seat_poses", []) as Array).size()):
		var loaded := AuthoredCraftPackages.read_station(kind, seat)
		if loaded.has("error"): continue
		layouts[str(seat)] = loaded["station"]
		revisions[str(seat)] = seat + 1
	return {"op": BuilderAuthority.RELAY, "entity": entity, "kind": kind, "seat": -1,
		"version": "test_1", "revision": 0, "layouts": layouts, "revisions": revisions}


func _cross_the_real_stream(document: Dictionary) -> void:
	var sender := LongTransfer.new(); var receiver := LongTransfer.new(); var down: Array = []; var up: Array = []
	var bytes := BuilderAuthority.encode(document)
	sender.send(2, &"layout", bytes, 15000, 0)
	for now in range(0, 15000, 10):
		sender.pump(now, func(_peer: int, packet: PackedByteArray): down.append(packet))
		for packet in down: receiver.receive(2, packet, now, func(_p: int, _k: StringName): return true,
			func(_kind: StringName, payload: PackedByteArray): return BuilderAuthority.envelope_is_valid(payload))
		down.clear()
		receiver.pump(now, func(_peer: int, packet: PackedByteArray): up.append(packet))
		for packet in up: sender.receive(2, packet, now)
		up.clear()
		if not receiver.completed.is_empty(): break
	var arrived := BuilderAuthority.decode(receiver.completed[0]["bytes"]) if receiver.completed.size() == 1 else {}
	_check("an_authoritative_snapshot_crosses_the_real_long_message_validator",
		receiver.completed.size() == 1 and BuilderAuthority.envelope_is_valid(receiver.completed[0]["bytes"])
		and int(arrived.get("entity", 0)) == int(document["entity"])
		and (arrived.get("layouts", {}) as Dictionary).size() == (document["layouts"] as Dictionary).size(),
		"%d delivery" % receiver.completed.size())


func _refusals() -> void:
	var loaded := AuthoredCraftPackages.read_station(Sim.Kind.BOAT, 0)
	var layout := (loaded["station"] as Dictionary).duplicate(true)
	var controls := layout["controls"] as Array
	var bad := (controls[0] as Dictionary).duplicate(true); bad["part"] = "FlapsLever"; controls[0] = bad
	_check("a_disallowed_device_is_refused", BuilderAuthority.validate_layout(Sim.Kind.BOAT, 0, layout) != "", "flaps on boat")
	layout = (loaded["station"] as Dictionary).duplicate(true); controls = layout["controls"] as Array
	bad = (controls[0] as Dictionary).duplicate(true); bad["at"] = [999.0, 1.0, 0.0]; controls[0] = bad
	_check("an_out_of_bounds_device_is_refused", BuilderAuthority.validate_layout(Sim.Kind.BOAT, 0, layout).contains("outside"), "x=999")
	var malformed := _snapshot(Sim.Kind.PLANE, 99); malformed["entity"] = 3.25
	_check("fractional_envelope_ids_are_refused", not BuilderAuthority.envelope_is_valid(BuilderAuthority.encode(malformed)), "entity 3.25")
