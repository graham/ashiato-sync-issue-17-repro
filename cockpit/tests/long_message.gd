extends Node
## Deterministic packet-list check for the bounded document stream. Read RESULT=, not exit code.

const PEER := 2
var failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[long_message] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: failures.append(label)


func _ready() -> void:
	var full := _json_bytes(LongTransfer.MOST_BYTES)
	var result := _cross(full, &"layout", 15000, true)
	_check("a_64_kib_layout_survives_loss_reordering_and_duplication",
		bool(result.get("delivered", false)) and result.get("bytes") == full,
		"%d bytes in %d ms, %d packets" % [full.size(), result.get("at", -1), result.get("packets", 0)])
	_check("and_the_paced_stream_stays_inside_the_per_peer_ceiling",
		int(result.get("worst_second", 999999)) <= LongTransfer.PER_PEER_BYTES_SECOND,
		"worst rolling second %d / %d bytes" % [result.get("worst_second", -1), LongTransfer.PER_PEER_BYTES_SECOND])
	_check("and_completion_releases_the_reserved_document_bytes", int(result.get("reserved", -1)) == 0,
		"reserved %d" % result.get("reserved", -1))

	var tone := PackedFloat32Array(); tone.resize(RadioClip.RATE * 3); tone.fill(0.25)
	var clip := RadioClip.encode(tone, RadioClip.RATE, 1, 0)
	var heard_clip := _cross(clip, &"clip", 3000, true)
	_check("a_bounded_clip_arrives_before_its_deadline", bool(heard_clip.get("delivered", false))
		and int(heard_clip.get("at", 9999)) < 3000, "%d ms" % heard_clip.get("at", -1))

	_selective_repeat_and_limits()
	_refusals_and_cleanup()
	print("[long_message] RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _cross(bytes: PackedByteArray, kind: StringName, deadline: int, chaos: bool) -> Dictionary:
	var sender := LongTransfer.new()
	var receiver := LongTransfer.new()
	var down: Array = []
	var up: Array = []
	var sends: Array = [] # [at, wire bytes]
	var attempts: Dictionary = {}
	var why := sender.send(PEER, kind, bytes, deadline, 0)
	if why != "": return {"error": why}
	for now in range(0, deadline + 1, 10):
		sender.pump(now, func(_peer: int, packet: PackedByteArray) -> void:
			var key := "%d:%d" % [packet.decode_u32(4), packet.decode_u16(12)]
			attempts[key] = int(attempts.get(key, 0)) + 1
			# Lose the first copy of every thirteenth data chunk. Varying delay reverses neighbours;
			# every seventeenth is duplicated. The receiver must make all three ordinary.
			if chaos and packet[2] == LongTransfer.DATA and packet.decode_u16(12) % 13 == 0 and attempts[key] == 1:
				return
			var lag := 40 if not chaos else (70 if packet.decode_u16(12) % 2 == 0 else 20)
			down.append([now + lag, packet.duplicate()]); sends.append([now, packet.size()])
			if chaos and packet.decode_u16(12) % 17 == 0: down.append([now + lag + 30, packet.duplicate()])
		)
		receiver.pump(now, func(_peer: int, packet: PackedByteArray) -> void:
			# Lose some ACKs. Selective masks must keep already-heard chunks from being resent.
			if not chaos or int(now / 10) % 11 != 0: up.append([now + 25, packet.duplicate()])
		)
		_deliver(down, now, func(packet: PackedByteArray) -> void:
			receiver.receive(PEER, packet, now, func(_peer: int, _kind: StringName) -> bool: return true)
		)
		_deliver(up, now, func(packet: PackedByteArray) -> void: sender.receive(PEER, packet, now))
		if not receiver.completed.is_empty():
			var message: Dictionary = receiver.completed[0]
			return {"delivered": true, "bytes": message["bytes"], "at": now, "packets": sends.size(),
				"worst_second": _worst_second(sends), "reserved": receiver.reserved_bytes(),
				"attempts": attempts}
	return {"delivered": false, "at": deadline, "packets": sends.size(), "worst_second": _worst_second(sends),
		"reserved": receiver.reserved_bytes(), "attempts": attempts}


func _deliver(queue: Array, now: int, take: Callable) -> void:
	for i in range(queue.size() - 1, -1, -1):
		if int(queue[i][0]) <= now:
			var packet: PackedByteArray = queue[i][1]
			queue.remove_at(i)
			take.call(packet)


func _worst_second(sends: Array) -> int:
	var worst := 0
	for start in range(sends.size()):
		var total := 0
		for row in sends:
			if int(row[0]) >= int(sends[start][0]) and int(row[0]) < int(sends[start][0]) + 1000:
				total += int(row[1])
		worst = maxi(worst, total)
	return worst


func _refusals_and_cleanup() -> void:
	var sender := LongTransfer.new()
	var too_big := PackedByteArray(); too_big.resize(LongTransfer.MOST_BYTES + 1)
	_check("an_over_cap_document_is_refused_before_it_is_queued",
		sender.send(PEER, &"layout", too_big, 15000, 0) != "" and sender.outgoing.is_empty(),
		"%d queued" % sender.outgoing.size())

	var receiver := LongTransfer.new()
	var malformed := PackedByteArray([LongTransfer.MAGIC, LongTransfer.VERSION, LongTransfer.DATA, 1])
	receiver.receive(PEER, malformed, 0, func(_p: int, _k: StringName) -> bool: return true)
	_check("a_malformed_header_is_refused_before_allocation", receiver.refused == 1 and receiver.reserved_bytes() == 0,
		"refused %d, reserved %d" % [receiver.refused, receiver.reserved_bytes()])
	var ack_sender := LongTransfer.new(); ack_sender.send(PEER, &"layout", _json_bytes(300), 1000, 0)
	ack_sender.receive(PEER, PackedByteArray([LongTransfer.MAGIC, LongTransfer.VERSION, LongTransfer.ACK, 1]), 1)
	_check("a_malformed_ack_releases_the_matching_sender", ack_sender.refused == 1 and ack_sender.outgoing.is_empty(),
		"refused %d, outgoing %d" % [ack_sender.refused, ack_sender.outgoing.size()])

	var one := LongTransfer.new(); one.send(PEER, &"layout", _json_bytes(400), 1000, 0)
	var packets: Array = []
	one.pump(0, func(_p: int, _packet: PackedByteArray) -> void: pass)
	one.pump(40, func(_p: int, packet: PackedByteArray) -> void: packets.append(packet))
	if not packets.is_empty():
		receiver.receive(PEER, packets[0], 40, func(_p: int, _k: StringName) -> bool: return false)
	_check("an_unauthorised_kind_releases_every_reserved_byte", receiver.reserved_bytes() == 0,
		"reserved %d" % receiver.reserved_bytes())

	receiver = LongTransfer.new()
	var bad_sender := LongTransfer.new(); bad_sender.send(PEER, &"layout", _json_bytes(300), 1000, 0)
	var bad_packets: Array = []
	bad_sender.pump(0, func(_p: int, _packet: PackedByteArray) -> void: pass)
	bad_sender.pump(40, func(_p: int, packet: PackedByteArray) -> void: bad_packets.append(packet))
	if not bad_packets.is_empty():
		var corrupt: PackedByteArray = bad_packets[0].duplicate(); corrupt[corrupt.size() - 1] ^= 1
		receiver.receive(PEER, corrupt, 40, func(_p: int, _k: StringName) -> bool: return true)
	_check("a_bad_crc_is_refused_and_released", receiver.refused == 1 and receiver.reserved_bytes() == 0,
		"refused %d, reserved %d" % [receiver.refused, receiver.reserved_bytes()])

	receiver = LongTransfer.new()
	if not bad_packets.is_empty():
		receiver.receive(PEER, bad_packets[0], 40,
			func(_p: int, _k: StringName) -> bool: return true,
			func(_k: StringName, _bytes: PackedByteArray) -> bool: return false)
	_check("a_kind_specific_validator_may_refuse_well_formed_json_before_delivery",
		receiver.refused == 1 and receiver.completed.is_empty() and receiver.reserved_bytes() == 0,
		"refused %d, delivered %d, reserved %d" % [receiver.refused, receiver.completed.size(), receiver.reserved_bytes()])

	receiver = LongTransfer.new()
	if not packets.is_empty(): receiver.receive(PEER, packets[0], 40, func(_p: int, _k: StringName) -> bool: return true)
	receiver.pump(1100, func(_p: int, _packet: PackedByteArray) -> void: pass)
	_check("an_expired_reassembly_releases_its_reservation", receiver.reserved_bytes() == 0 and receiver.incoming.is_empty(),
		"reserved %d" % receiver.reserved_bytes())

	receiver = LongTransfer.new()
	if not packets.is_empty(): receiver.receive(PEER, packets[0], 40, func(_p: int, _k: StringName) -> bool: return true)
	receiver.forget_peer(PEER)
	_check("a_disconnect_releases_its_reassembly", receiver.reserved_bytes() == 0 and receiver.incoming.is_empty(), "")

	var replacement := LongTransfer.new()
	replacement.send(PEER, &"layout", _json_bytes(500), 1000, 0)
	replacement.send(PEER, &"layout", _json_bytes(600), 1000, 1)
	_check("a_newer_replaceable_kind_supersedes_the_old_transfer", replacement.outgoing.size() == 1
		and int((replacement.outgoing[PEER] as Dictionary)["total"]) == 600,
		"%d-byte active transfer" % int((replacement.outgoing[PEER] as Dictionary)["total"]))
	var repeated := LongTransfer.new(); var repeated_bytes := _json_bytes(600)
	repeated.send(PEER, &"layout", repeated_bytes, 1000, 0)
	var repeated_id := int((repeated.outgoing[PEER] as Dictionary)["id"])
	(repeated.outgoing[PEER] as Dictionary)["acked"][0] = true
	repeated.send(PEER, &"layout", repeated_bytes, 1000, 1)
	_check("an_identical_repeated_document_keeps_its_ack_progress",
		int((repeated.outgoing[PEER] as Dictionary)["id"]) == repeated_id
		and (repeated.outgoing[PEER] as Dictionary)["acked"].has(0),
		"transfer %d still owns acknowledged chunk zero" % repeated_id)


func _selective_repeat_and_limits() -> void:
	var sender := LongTransfer.new(); var receiver := LongTransfer.new()
	sender.send(PEER, &"layout", _json_bytes(1500), 5000, 0)
	var first: Array = []
	for now in [0, 40, 80, 120, 160]:
		sender.pump(now, func(_p: int, packet: PackedByteArray) -> void: first.append(packet))
	for packet in first:
		if (packet as PackedByteArray).decode_u16(12) != 1:
			receiver.receive(PEER, packet, 170, func(_p: int, _k: StringName) -> bool: return true)
	var acks: Array = []
	receiver.pump(170, func(_p: int, packet: PackedByteArray) -> void: acks.append(packet))
	for ack in acks: sender.receive(PEER, ack, 170)
	var retried: Array[int] = []
	sender.pump(300, func(_p: int, packet: PackedByteArray) -> void: retried.append(packet.decode_u16(12)))
	_check("a_selective_ack_retries_only_the_missing_chunk", retried == [1], "retried %s" % [retried])

	var once_sender := LongTransfer.new(); var once_receiver := LongTransfer.new(); var one_packet: Array = []
	once_sender.send(PEER, &"layout", _json_bytes(300), 1000, 0)
	once_sender.pump(0, func(_p: int, _packet: PackedByteArray) -> void: pass)
	once_sender.pump(40, func(_p: int, packet: PackedByteArray) -> void: one_packet.append(packet))
	if not one_packet.is_empty():
		once_receiver.receive(PEER, one_packet[0], 40, func(_p: int, _k: StringName) -> bool: return true)
		once_receiver.receive(PEER, one_packet[0], 300, func(_p: int, _k: StringName) -> bool: return true)
	_check("a_duplicate_final_chunk_delivers_the_document_once", once_receiver.completed.size() == 1
		and once_receiver.reserved_bytes() == 0, "%d deliveries, %d reserved" % [once_receiver.completed.size(),
		once_receiver.reserved_bytes()])

	var paused_sender := LongTransfer.new(); var paused_packets := [0]
	paused_sender.send(PEER, &"layout", _json_bytes(500), 1000, 0)
	paused_sender.pump(0, func(_p: int, _packet: PackedByteArray) -> void: paused_packets[0] += 1)
	paused_sender.pump(100, func(_p: int, _packet: PackedByteArray) -> void: paused_packets[0] += 1,
		func(_p: int) -> bool: return true)
	var while_paused: int = paused_packets[0]
	paused_sender.pump(200, func(_p: int, _packet: PackedByteArray) -> void: paused_packets[0] += 1)
	_check("the_pause_hook_spends_no_chunk_or_budget", while_paused == 0 and paused_packets[0] == 1,
		"%d paused, %d after resume" % [while_paused, paused_packets[0]])

	var host := LongTransfer.new(); var bytes_sent := [0]; var by_peer: Dictionary = {}
	for peer in range(2, 7): host.send(peer, &"layout", _json_bytes(20000), 5000, 0)
	for now in range(0, 1000, 10):
		host.pump(now, func(peer: int, packet: PackedByteArray) -> void:
			bytes_sent[0] += packet.size()
			by_peer[peer] = int(by_peer.get(peer, 0)) + packet.size()
			host.receive(peer, _ack_for(packet), now)
		)
	var least := 999999
	for peer in range(2, 7): least = mini(least, int(by_peer.get(peer, 0)))
	_check("five_peers_share_the_exact_host_byte_ceiling", bytes_sent[0] <= LongTransfer.HOST_BYTES_SECOND
		and bytes_sent[0] > 40000 and least > 7000,
		"%d / %d bytes, least peer %d" % [bytes_sent[0], LongTransfer.HOST_BYTES_SECOND, least])


func _ack_for(data: PackedByteArray) -> PackedByteArray:
	var ack := PackedByteArray(); ack.resize(LongTransfer.ACK_BYTES)
	ack[0] = LongTransfer.MAGIC; ack[1] = LongTransfer.VERSION; ack[2] = LongTransfer.ACK; ack[3] = data[3]
	ack.encode_u32(4, data.decode_u32(4)); ack.encode_u16(8, data.decode_u16(12) + 1); ack.encode_u32(10, 0)
	return ack


func _json_bytes(size: int) -> PackedByteArray:
	# ASCII makes bytes and letters the same count. Ten bytes of JSON framing.
	return ('{"pad":"%s"}' % "x".repeat(size - 10)).to_utf8_buffer()
