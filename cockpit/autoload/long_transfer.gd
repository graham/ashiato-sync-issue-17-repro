class_name LongTransfer
extends RefCounted
## Bounded reliability for documents on Net's existing unreliable packet carriers.
## Godot's reliable RPC preserves order at a significant performance cost; this small
## selective-repeat stream lets simulation packets keep priority.

const MAGIC: int = 0x4c
const VERSION: int = 1
const DATA: int = 0
const ACK: int = 1
const HEADER_BYTES: int = 22
const ACK_BYTES: int = 14
const CHUNK_BYTES: int = 384
const MOST_BYTES: int = 64 * 1024
const MOST_CHUNKS: int = 171
const WINDOW: int = 4
const ACK_MSEC: int = 50
const RETRY_MSEC: int = 200
const MOST_BACKOFF: int = 1600
const PER_PEER_BYTES_SECOND: int = 12 * 1024
const HOST_BYTES_SECOND: int = 48 * 1024

const KINDS: Dictionary = {
	&"layout": {"code": 1, "most": MOST_BYTES, "life": 15000, "host_only": false},
	# Seven seconds of 8 kHz IMA ADPCM is about 28 KiB. The enclosing document
	# ceiling stays 64 KiB; clips deliberately expire before layouts do.
	&"clip": {"code": 2, "most": 32 * 1024, "life": 3000, "host_only": true},
}

var host: bool = false
var next_id: int = 1
var outgoing: Dictionary = {} # peer -> transfer
var waiting: Dictionary = {} # peer -> Array[transfer]
var incoming: Dictionary = {} # peer -> transfer
var completed: Array[Dictionary] = []
var refused: int = 0
var wire_sent: int = 0
var wire_received: int = 0
var _peer_tokens: Dictionary = {}
var _global_tokens: float = 0.0
var _budget_at: int = -1
var _peer_cursor: int = 0


func send(peer: int, kind: StringName, bytes: PackedByteArray, stale_msec: int, now: int) -> String:
	if peer <= 0:
		return "A long message needs a peer."
	if not KINDS.has(kind):
		return "There is no long-message kind called %s." % kind
	var rule: Dictionary = KINDS[kind]
	if bytes.is_empty() or bytes.size() > int(rule["most"]) or bytes.size() > MOST_BYTES:
		return "A %s long message must be 1 to %d bytes." % [kind, mini(int(rule["most"]), MOST_BYTES)]
	if stale_msec <= 0 or stale_msec > int(rule["life"]):
		return "A %s long message may live for at most %d ms." % [kind, int(rule["life"])]
	if next_id == 0:
		return "This process has used every long-message transfer id."
	# A consumer may repeat READY until its first snapshot arrives. Replacing an
	# identical in-flight snapshot on every request prevents a multi-chunk document
	# from ever reaching its final chunk. Keep the transfer and its ACK progress.
	if outgoing.has(peer):
		var active := outgoing[peer] as Dictionary
		if StringName(active["kind"]) == kind and (active["bytes"] as PackedByteArray) == bytes:
			return ""
	var transfer := _new_transfer(kind, bytes, stale_msec, now)
	# A newer replaceable document supersedes an older one before it spends another byte.
	if outgoing.has(peer) and StringName((outgoing[peer] as Dictionary)["kind"]) == kind:
		outgoing[peer] = transfer
		return ""
	var queue: Array = waiting.get(peer, [])
	for i in range(queue.size() - 1, -1, -1):
		if StringName((queue[i] as Dictionary)["kind"]) == kind:
			queue.remove_at(i)
	queue.append(transfer)
	waiting[peer] = queue
	_start_next(peer)
	return ""


func _new_transfer(kind: StringName, bytes: PackedByteArray, stale_msec: int, now: int) -> Dictionary:
	var id := next_id
	next_id = 0 if next_id == 0xffffffff else next_id + 1
	return {"kind": kind, "id": id, "bytes": bytes.duplicate(), "total": bytes.size(),
		"count": ceili(float(bytes.size()) / CHUNK_BYTES), "crc": crc32(bytes),
		"expires": now + stale_msec, "acked": {}, "sent_at": {}, "tries": {}}


func pump(now: int, emit: Callable, paused: Callable = Callable()) -> void:
	_refill(now)
	_expire(now)
	# Acks cost no document budget, but are coalesced to one per peer per 50 ms.
	for peer in incoming.keys():
		var receive: Dictionary = incoming[peer]
		if bool(receive.get("ack_dirty", false)) and now >= int(receive.get("ack_at", 0)):
			var packet := _ack_packet(receive)
			emit.call(int(peer), packet)
			wire_sent += packet.size()
			receive["ack_dirty"] = false
			receive["ack_at"] = now + ACK_MSEC
	var peers: Array = outgoing.keys()
	peers.sort()
	if not peers.is_empty():
		var shift := _peer_cursor % peers.size()
		peers = peers.slice(shift) + peers.slice(0, shift)
		_peer_cursor = (_peer_cursor + 1) % peers.size()
	for peer in peers:
		if paused.is_valid() and bool(paused.call(int(peer))):
			continue
		var transfer: Dictionary = outgoing[peer]
		var index := _next_chunk(transfer, now)
		if index < 0:
			continue
		var packet := _data_packet(transfer, index, now)
		var tokens := float(_peer_tokens.get(peer, 0.0))
		if tokens < packet.size() or _global_tokens < packet.size():
			continue
		_peer_tokens[peer] = tokens - packet.size()
		_global_tokens -= packet.size()
		emit.call(int(peer), packet)
		wire_sent += packet.size()
		transfer["sent_at"][index] = now
		transfer["tries"][index] = int(transfer["tries"].get(index, 0)) + 1


func receive(from_peer: int, packet: PackedByteArray, now: int, entitled: Callable = Callable(),
		payload_validator: Callable = Callable()) -> void:
	wire_received += packet.size()
	if packet.size() < 4 or packet[0] != MAGIC or packet[1] != VERSION:
		_refuse(from_peer, "bad magic, version, or short envelope")
		return
	if packet[2] == ACK:
		if packet.size() != ACK_BYTES:
			_warn_refusal(from_peer, "acknowledgement has the wrong size")
			outgoing.erase(from_peer)
			_start_next(from_peer)
			return
		_receive_ack(from_peer, packet)
	elif packet[2] == DATA:
		_receive_data(from_peer, packet, now, entitled, payload_validator)
	else:
		_refuse(from_peer, "unknown envelope kind")


func _receive_data(peer: int, p: PackedByteArray, now: int, entitled: Callable, payload_validator: Callable) -> void:
	if p.size() < HEADER_BYTES or p.size() > HEADER_BYTES + CHUNK_BYTES:
		_refuse(peer, "data envelope has the wrong size"); return
	var kind := _kind_for_code(p[3])
	var id := p.decode_u32(4)
	var total := p.decode_u32(8)
	var index := p.decode_u16(12)
	var count := p.decode_u16(14)
	var crc := p.decode_u32(16)
	var life := p.decode_u16(20)
	var payload := p.slice(HEADER_BYTES)
	if kind == &"" or id == 0 or total == 0 or total > MOST_BYTES or count == 0 or count > MOST_CHUNKS \
			or count != ceili(float(total) / CHUNK_BYTES) or index >= count or life == 0 \
			or life > int(KINDS[kind]["life"]) or total > int(KINDS[kind]["most"]) \
			or payload.size() != mini(CHUNK_BYTES, int(total) - int(index) * CHUNK_BYTES) \
			or (entitled.is_valid() and not bool(entitled.call(peer, kind))):
		_refuse(peer, "data header, size, lifetime, or authority is invalid"); return
	if incoming.has(peer):
		var old: Dictionary = incoming[peer]
		if int(old["id"]) != id:
			# IDs only rise during a sender process; late packets cannot replace newer work.
			if _id_is_newer(id, int(old["id"])):
				incoming.erase(peer)
			else:
				return
	if not incoming.has(peer):
		incoming[peer] = {"kind": kind, "id": id, "total": int(total), "count": int(count), "crc": crc,
			"expires": now + int(life), "chunks": {}, "ack_dirty": true, "ack_at": now}
	var transfer: Dictionary = incoming[peer]
	if StringName(transfer["kind"]) != kind or int(transfer["total"]) != total \
			or int(transfer["count"]) != count or int(transfer["crc"]) != crc:
		_refuse(peer, "chunk disagrees with its transfer header"); return
	if bool(transfer.get("complete", false)):
		transfer["ack_dirty"] = true
		return
	if not transfer["chunks"].has(index):
		transfer["chunks"][index] = payload
	transfer["ack_dirty"] = true
	if transfer["chunks"].size() == count:
		var bytes := PackedByteArray()
		for i in range(count):
			bytes.append_array(transfer["chunks"][i])
		if bytes.size() != total or crc32(bytes) != crc or not _valid_payload(kind, bytes, payload_validator):
			_refuse(peer, "completed document failed its size, CRC, or semantic validator"); return
		completed.append({"peer": peer, "kind": kind, "bytes": bytes, "id": id})
		# Release the 64 KiB reservation now, but retain a tiny receipt until the sender's
		# original deadline so a lost final ACK cannot deliver the document twice.
		transfer["chunks"] = {}
		transfer["complete"] = true
		transfer["ack_at"] = now


func _receive_ack(peer: int, p: PackedByteArray) -> void:
	if p.size() != ACK_BYTES or not outgoing.has(peer):
		return
	var transfer: Dictionary = outgoing[peer]
	if p[3] != int(KINDS[StringName(transfer["kind"])]["code"]) or p.decode_u32(4) != int(transfer["id"]):
		return
	var high := int(p.decode_u16(8)) - 1
	var mask := p.decode_u32(10)
	var count := int(transfer["count"])
	if high < -1 or high >= count:
		_warn_refusal(peer, "acknowledgement range is outside the transfer")
		outgoing.erase(peer); _start_next(peer); return
	for bit in range(32):
		if mask & (1 << bit) and high + 1 + bit >= count:
			_warn_refusal(peer, "acknowledgement mask is outside the transfer")
			outgoing.erase(peer); _start_next(peer); return
	for i in range(high + 1):
		transfer["acked"][i] = true
	for bit in range(32):
		if mask & (1 << bit):
			transfer["acked"][high + 1 + bit] = true
	if transfer["acked"].size() >= count:
		outgoing.erase(peer)
		_start_next(peer)


func _next_chunk(t: Dictionary, now: int) -> int:
	var first := 0
	while first < int(t["count"]) and t["acked"].has(first):
		first += 1
	for i in range(first, mini(first + WINDOW, int(t["count"]))):
		if t["acked"].has(i):
			continue
		if not t["sent_at"].has(i):
			return i
		var wait := mini(RETRY_MSEC * (1 << mini(int(t["tries"].get(i, 1)) - 1, 3)), MOST_BACKOFF)
		if now - int(t["sent_at"][i]) >= wait:
			return i
	return -1


func _data_packet(t: Dictionary, index: int, now: int) -> PackedByteArray:
	var p := PackedByteArray(); p.resize(HEADER_BYTES)
	p[0] = MAGIC; p[1] = VERSION; p[2] = DATA; p[3] = int(KINDS[StringName(t["kind"])]["code"])
	p.encode_u32(4, int(t["id"])); p.encode_u32(8, int(t["total"])); p.encode_u16(12, index)
	p.encode_u16(14, int(t["count"])); p.encode_u32(16, int(t["crc"]))
	p.encode_u16(20, clampi(int(t["expires"]) - now, 1, 65535))
	var start := index * CHUNK_BYTES
	p.append_array((t["bytes"] as PackedByteArray).slice(start, mini(start + CHUNK_BYTES, int(t["total"]))))
	return p


func _ack_packet(t: Dictionary) -> PackedByteArray:
	var high := int(t["count"]) - 1 if bool(t.get("complete", false)) else -1
	while not bool(t.get("complete", false)) and t["chunks"].has(high + 1): high += 1
	var mask := 0
	for bit in range(32):
		if t["chunks"].has(high + 1 + bit): mask |= 1 << bit
	var p := PackedByteArray(); p.resize(ACK_BYTES)
	p[0] = MAGIC; p[1] = VERSION; p[2] = ACK; p[3] = int(KINDS[StringName(t["kind"])]["code"])
	p.encode_u32(4, int(t["id"])); p.encode_u16(8, high + 1); p.encode_u32(10, mask)
	return p


func _refill(now: int) -> void:
	if _budget_at < 0: _budget_at = now
	var elapsed := maxi(0, now - _budget_at)
	_budget_at = now
	_global_tokens = minf(HOST_BYTES_SECOND, _global_tokens + HOST_BYTES_SECOND * elapsed / 1000.0)
	for peer in outgoing.keys():
		_peer_tokens[peer] = minf(PER_PEER_BYTES_SECOND,
			float(_peer_tokens.get(peer, 0.0)) + PER_PEER_BYTES_SECOND * elapsed / 1000.0)


func _expire(now: int) -> void:
	for peer in outgoing.keys():
		if now >= int((outgoing[peer] as Dictionary)["expires"]):
			outgoing.erase(peer); _start_next(int(peer))
	for peer in incoming.keys():
		if now >= int((incoming[peer] as Dictionary)["expires"]): incoming.erase(peer)
	for peer in waiting.keys():
		var queue: Array = waiting[peer]
		queue = queue.filter(func(t: Dictionary) -> bool: return now < int(t["expires"]))
		if queue.is_empty(): waiting.erase(peer)
		else: waiting[peer] = queue


func forget_peer(peer: int) -> void:
	outgoing.erase(peer); waiting.erase(peer); incoming.erase(peer); _peer_tokens.erase(peer)


func clear() -> void:
	outgoing.clear(); waiting.clear(); incoming.clear(); completed.clear(); _peer_tokens.clear()
	_global_tokens = 0.0; _budget_at = -1; _peer_cursor = 0


func reserved_bytes() -> int:
	var result := 0
	for t in incoming.values():
		if not bool((t as Dictionary).get("complete", false)): result += int((t as Dictionary)["total"])
	return result


func _start_next(peer: int) -> void:
	if outgoing.has(peer) or not waiting.has(peer): return
	var queue: Array = waiting[peer]
	if not queue.is_empty(): outgoing[peer] = queue.pop_front()
	if queue.is_empty(): waiting.erase(peer)
	else: waiting[peer] = queue


func _warn_refusal(peer: int, why: String) -> void:
	refused += 1
	push_warning("[net] long message from peer %d refused: %s" % [peer, why])


func _refuse(peer: int, why: String) -> void:
	_warn_refusal(peer, why)
	incoming.erase(peer)


func _kind_for_code(code: int) -> StringName:
	for kind in KINDS:
		if int(KINDS[kind]["code"]) == code: return kind
	return &""


func _valid_payload(kind: StringName, bytes: PackedByteArray, validator: Callable) -> bool:
	var basic := not bytes.is_empty()
	if kind == &"layout":
		basic = JSON.parse_string(bytes.get_string_from_utf8()) is Dictionary
	elif kind == &"clip":
		basic = RadioClip.problem(bytes).is_empty()
	return basic and (not validator.is_valid() or bool(validator.call(kind, bytes)))


static func _id_is_newer(a: int, b: int) -> bool:
	return a > b


static func crc32(bytes: PackedByteArray) -> int:
	var crc: int = 0xffffffff
	for byte in bytes:
		crc ^= byte
		for _bit in range(8):
			crc = (crc >> 1) ^ (0xedb88320 if crc & 1 else 0)
	return (crc ^ 0xffffffff) & 0xffffffff
