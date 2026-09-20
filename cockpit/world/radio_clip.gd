class_name RadioClip
extends RefCounted
## A bounded, self-describing radio clip. Speech is low-pass averaged while it is
## resampled to 8 kHz, then encoded as standard 4-bit IMA ADPCM. Godot has an
## IMA decoder in AudioStreamWAV but no runtime encoder, so the wire format keeps
## the tiny codec explicit and decodes to PCM16 for playback.

const RATE: int = 8000
# At 4 KiB/s, seven seconds remains below what the 12 KiB/s paced carrier can
# deliver (including ordinary retries) before its three-second stale deadline.
const MOST_SECONDS: float = 7.0
const HEADER_BYTES: int = 21
const MAGIC: Array[int] = [0x52, 0x43, 0x4c, 0x01] # RCL, version 1

const INDEX_TABLE: Array[int] = [-1, -1, -1, -1, 2, 4, 6, 8,
	-1, -1, -1, -1, 2, 4, 6, 8]
const STEP_TABLE: Array[int] = [
	7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31,
	34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143,
	157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544,
	598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878,
	2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894,
	6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818,
	18500, 20350, 22385, 24623, 27086, 29794, 32767]


static func encode(samples: PackedFloat32Array, source_rate: int, clip_id: int,
		spoken_frame: int) -> PackedByteArray:
	if samples.is_empty() or source_rate < RATE or clip_id <= 0 or spoken_frame < 0:
		return PackedByteArray()
	var mono := _resample(samples, source_rate)
	if mono.is_empty() or mono.size() > int(RATE * MOST_SECONDS):
		return PackedByteArray()
	var first := clampi(int(round(mono[0] * 32767.0)), -32768, 32767)
	var out := PackedByteArray(); out.resize(HEADER_BYTES + ceili(float(mono.size() - 1) / 2.0))
	for i in range(MAGIC.size()): out[i] = MAGIC[i]
	out.encode_u32(4, clip_id); out.encode_u32(8, spoken_frame)
	out.encode_u32(12, mono.size()); out.encode_u16(16, RATE)
	out.encode_s16(18, first); out[20] = 0
	var predictor := first
	var index := 0
	for i in range(1, mono.size()):
		var sample := clampi(int(round(mono[i] * 32767.0)), -32768, 32767)
		var coded := _encode_nibble(sample, predictor, index)
		predictor = int(coded[1]); index = int(coded[2])
		var at := HEADER_BYTES + floori(float(i - 1) / 2.0)
		if (i - 1) & 1: out[at] |= int(coded[0]) << 4
		else: out[at] = int(coded[0])
	return out


static func decode(bytes: PackedByteArray) -> Dictionary:
	var why := problem(bytes)
	if not why.is_empty(): return {"why": why}
	var count := int(bytes.decode_u32(12))
	var predictor := int(bytes.decode_s16(18))
	var index := int(bytes[20])
	var pcm := PackedInt32Array(); pcm.resize(count); pcm[0] = predictor
	for i in range(1, count):
		var byte := int(bytes[HEADER_BYTES + floori(float(i - 1) / 2.0)])
		var nibble := (byte >> 4) & 15 if (i - 1) & 1 else byte & 15
		var decoded := _decode_nibble(nibble, predictor, index)
		predictor = int(decoded[0]); index = int(decoded[1]); pcm[i] = predictor
	return {"id": int(bytes.decode_u32(4)), "spoken_frame": int(bytes.decode_u32(8)),
		"rate": RATE, "samples": pcm}


static func problem(bytes: PackedByteArray) -> String:
	if bytes.size() < HEADER_BYTES: return "Radio clip header is short."
	for i in range(MAGIC.size()):
		if bytes[i] != MAGIC[i]: return "Radio clip magic or version is wrong."
	var count := int(bytes.decode_u32(12)); var rate := int(bytes.decode_u16(16))
	if bytes.decode_u32(4) == 0 or count <= 0 or count > int(RATE * MOST_SECONDS) or rate != RATE:
		return "Radio clip id, rate, or duration is invalid."
	if bytes[20] > 88 or bytes.size() != HEADER_BYTES + ceili(float(count - 1) / 2.0):
		return "Radio clip ADPCM payload has the wrong size or state."
	return ""


static func stream(bytes: PackedByteArray) -> AudioStreamWAV:
	var decoded := decode(bytes)
	if decoded.has("why"): return null
	var samples: PackedInt32Array = decoded["samples"]
	var data := PackedByteArray(); data.resize(samples.size() * 2)
	for i in range(samples.size()): data.encode_s16(i * 2, samples[i])
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS; wave.mix_rate = RATE
	wave.stereo = false; wave.data = data
	return wave


## ---- THE CODEC, SHARED WITH THE LIVE VOICE FRAMES --------------------------------------------------
##
## `VoiceFrame` encodes 20 ms blocks of microphone audio with the SAME tables and the same arithmetic as a spoken clip.
## One codec for the generated line and for the microphone, so every machine has one decoder, and the 25.98 dB
## speech-band SNR measured for this one is the number for both. These three are public for that reason and no other;
## everything else here stays private.
static func to_the_clip_rate(samples: PackedFloat32Array, source_rate: int) -> PackedFloat32Array:
	return _resample(samples, source_rate)


## A sample into [nibble, predictor, index].
static func encode_one(sample: int, predictor: int, index: int) -> Array[int]:
	return _encode_nibble(sample, predictor, index)


## A nibble into [predictor, index].
static func decode_one(nibble: int, predictor: int, index: int) -> Array[int]:
	return _decode_nibble(nibble, predictor, index)


static func _resample(source: PackedFloat32Array, source_rate: int) -> PackedFloat32Array:
	if source_rate == RATE: return source.duplicate()
	var count := int(floor(float(source.size()) * RATE / source_rate))
	var out := PackedFloat32Array(); out.resize(count)
	# Box averaging is the low-pass required before decimation. Capture normally
	# arrives at 48 kHz, making this a six-sample finite impulse response filter.
	for i in range(count):
		var first := int(floor(float(i) * source_rate / RATE))
		var last := mini(source.size(), int(floor(float(i + 1) * source_rate / RATE)))
		var sum := 0.0
		for j in range(first, maxi(first + 1, last)): sum += source[j]
		out[i] = sum / maxi(1, last - first)
	return out


static func _encode_nibble(sample: int, predictor: int, index: int) -> Array[int]:
	var step := STEP_TABLE[index]; var difference := sample - predictor; var nibble := 0
	if difference < 0: nibble = 8; difference = -difference
	var delta := step >> 3
	if difference >= step: nibble |= 4; difference -= step; delta += step
	if difference >= step >> 1: nibble |= 2; difference -= step >> 1; delta += step >> 1
	if difference >= step >> 2: nibble |= 1; delta += step >> 2
	predictor = clampi(predictor - delta if nibble & 8 else predictor + delta, -32768, 32767)
	index = clampi(index + INDEX_TABLE[nibble], 0, 88)
	return [nibble, predictor, index]


static func _decode_nibble(nibble: int, predictor: int, index: int) -> Array[int]:
	var step := STEP_TABLE[index]; var delta := step >> 3
	if nibble & 4: delta += step
	if nibble & 2: delta += step >> 1
	if nibble & 1: delta += step >> 2
	predictor = clampi(predictor - delta if nibble & 8 else predictor + delta, -32768, 32767)
	index = clampi(index + INDEX_TABLE[nibble], 0, 88)
	return [predictor, index]
