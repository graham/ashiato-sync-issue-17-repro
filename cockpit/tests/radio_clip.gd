extends Node
## Model-free proof of the clip carried by Item 9's bounded long-message pump.

var failed: Array[String] = []

func check(label: String, ok: bool, detail: String) -> void:
	print("[radio_clip] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: failed.append(label)

func _ready() -> void:
	var source := PackedFloat32Array()
	const SECONDS := 7
	for i in range(RadioClip.RATE * SECONDS):
		var t := float(i) / RadioClip.RATE
		source.append(0.55 * sin(TAU * 440.0 * t) + 0.2 * sin(TAU * 1200.0 * t))
	var bytes := RadioClip.encode(source, RadioClip.RATE, 17, 1200)
	var decoded := RadioClip.decode(bytes)
	check("a_speech_band_signal_round_trips", not decoded.has("why") and decoded.samples.size() == source.size(),
		"%d samples, %d bytes" % [decoded.get("samples", PackedInt32Array()).size(), bytes.size()])
	var noise := 0.0; var signal_power := 0.0
	var samples: PackedInt32Array = decoded.get("samples", PackedInt32Array())
	for i in range(mini(source.size(), samples.size())):
		var original := source[i]; var restored := samples[i] / 32768.0
		signal_power += original * original; noise += (original - restored) * (original - restored)
	var snr := 10.0 * log(signal_power / maxf(noise, 1e-12)) / log(10.0)
	check("ima_adpcm_keeps_the_radio_band_intelligible", snr >= 18.0, "SNR %.2f dB" % snr)
	check("the_wire_cost_is_about_four_kilobytes_a_second", bytes.size() <= 4100 * SECONDS,
		"%.1f bytes/s" % (bytes.size() / float(SECONDS)))
	var wave := RadioClip.stream(bytes)
	check("a_clip_becomes_a_mono_pcm_stream", wave != null and wave.mix_rate == RadioClip.RATE, "8 kHz PCM16")
	await _through_loss(bytes)
	_malformed_and_authority(bytes)
	print("RESULT=%s%s" % ["PASS" if failed.is_empty() else "FAIL ", ", ".join(failed)])
	get_tree().quit(0 if failed.is_empty() else 1)

func _through_loss(bytes: PackedByteArray) -> void:
	var sender := LongTransfer.new(); sender.host = true
	var receiver := LongTransfer.new(); receiver.host = false
	var attempts: Dictionary = {}; var now := 0
	check("the_clip_fits_the_bounded_carrier", sender.send(2, &"clip", bytes, 3000, now).is_empty(),
		"%d/%d bytes" % [bytes.size(), LongTransfer.KINDS[&"clip"]["most"]])
	while receiver.completed.is_empty() and now < 2900:
		var down: Array[PackedByteArray] = []; var up: Array[PackedByteArray] = []
		sender.pump(now, func(_peer: int, packet: PackedByteArray): down.append(packet))
		for packet in down:
			var key := "%d:%d" % [packet.decode_u32(4), packet.decode_u16(12)]
			attempts[key] = int(attempts.get(key, 0)) + 1
			if packet[2] == LongTransfer.DATA and packet.decode_u16(12) % 10 == 0 and attempts[key] == 1: continue
			receiver.receive(1, packet, now, func(peer: int, kind: StringName): return peer == 1 and kind == &"clip")
		receiver.pump(now, func(_peer: int, packet: PackedByteArray): up.append(packet))
		for packet in up: sender.receive(2, packet, now)
		now += 20
	check("a_clip_arrives_whole_through_ten_percent_loss", receiver.completed.size() == 1
		and receiver.completed[0].bytes == bytes, "%d ms, %d refusals" % [now, receiver.refused])
	await get_tree().process_frame

func _malformed_and_authority(bytes: PackedByteArray) -> void:
	var stale := LongTransfer.new(); stale.host = true
	stale.send(2, &"clip", bytes, 100, 0); stale.pump(101, func(_peer: int, _packet: PackedByteArray): pass)
	check("a_stale_clip_is_dropped_before_it_spends_a_byte", stale.outgoing.is_empty(),
		"%d wire bytes" % stale.wire_sent)
	var receiver := LongTransfer.new(); var sender := LongTransfer.new()
	sender.send(1, &"clip", bytes, 3000, 0)
	var packets: Array[PackedByteArray] = []
	sender.pump(0, func(_peer: int, packet: PackedByteArray): packets.append(packet))
	sender.pump(1000, func(_peer: int, packet: PackedByteArray): packets.append(packet))
	for packet in packets:
		receiver.receive(9, packet, 1000, func(_peer: int, _kind: StringName): return false)
	check("a_joiner_origin_clip_is_refused", receiver.refused > 0 and receiver.completed.is_empty(),
		"%d refusals" % receiver.refused)
	var broken := bytes.duplicate(); broken[0] = 0
	check("a_malformed_clip_is_rejected_semantically", not RadioClip.problem(broken).is_empty(), RadioClip.problem(broken))
