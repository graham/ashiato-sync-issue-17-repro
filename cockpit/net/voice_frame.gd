class_name VoiceFrame
extends RefCounted
## ONE SHORT BLOCK OF AUDIO WITH A LABEL ON IT: who is speaking, what kind of audio it is, and which codec carried it.
##
## The user asked for the label (2026-09-19): *"can there be more than one channel of audio from server to client? I
## might want to play human audio, and ai audio on different channels, or i may need to mix them myself."*
##
## ---------------------------------------------------------------------------------------------------
## A CHANNEL IS A LABEL ON A FRAME, NOT A SEPARATE CONNECTION
## ---------------------------------------------------------------------------------------------------
##
## Every frame says `speaker` and `kind`, so the machine that receives it decides what to do: play the two on separate
## buses, mix them, mute one, or duck one under the other. **None of that needs a wire change**, which is the whole
## point of putting the label in the frame rather than building a second transport.
##
## And the same field does two jobs, deliberately: the speaking lamp reads `speaker`, the same field the audio is
## labelled with, so **the indicator and the sound cannot disagree**. A lamp fed from anywhere else is a second opinion
## about who is talking.
##
## `codec` is here so the door to Steam's own capture stays cheap. Steam's `getVoice` hands back COMPRESSED bytes and
## `decompressVoice` turns them back into PCM (`tests/voice_probe.gd` measured the call surface); carrying those bytes
## unchanged needs nothing but a second value in this byte. Today there is one codec and it is the clip codec.
##
## ---------------------------------------------------------------------------------------------------
## WHY EACH FRAME STANDS ALONE
## ---------------------------------------------------------------------------------------------------
##
## These travel on the unreliable carrier and may be dropped, reordered or delivered twice. So every frame carries its
## own ADPCM seed -- the first sample and the step index -- and decodes without reference to the frame before it. A lost
## frame costs 20 ms of audio and nothing else; a stream that shared predictor state across frames would be corrupted
## from the loss to the end of the transmission.
##
## THE SIZE IS CHOSEN SO A FRAME IS ONE PACKET. 20 ms at 8 kHz is 160 samples: 80 bytes of nibbles plus a 14-byte
## header, about 94 bytes, against `Net.HELLO_MOST_BYTES` of 512. At fifty frames a second that is ~4.7 kB/s, beside the
## 4,003 bytes/s `tests/radio_clip.gd` measured for the same codec carrying a spoken line.
##
## Rejected: Opus, which is better and which this does not need -- the clip codec is already here, already measured at
## 25.98 dB speech-band SNR, and using it means one decoder on every machine for both kinds of audio.

## The sample rate every frame is at, which is the clip codec's. One number, in one place: `RadioClip.RATE`.
const RATE: int = RadioClip.RATE
## Samples in a frame. 20 ms: short enough that losing one is not heard as a gap, long enough that the header is not
## most of the packet.
const SAMPLES: int = RATE / 50
const HEADER_BYTES: int = 14
const VERSION: int = 1

## WHAT KIND OF AUDIO THIS IS. The receiver's routing question, and the user's "human audio, and ai audio".
enum Kind {
	## Somebody's microphone, live.
	LIVE = 0,
	## Generated on the host -- the Kokoro tower voice. Carried here only if a generated line is ever streamed; today it
	## travels as a bounded clip document instead (see `Intercom`, "two carriers, one labelled arrival point").
	GENERATED = 1,
}

## WHICH CODEC CARRIED THE SAMPLES.
enum Codec {
	## The clip codec: 4-bit IMA ADPCM at 8 kHz, `RadioClip`'s tables.
	CLIP_ADPCM = 0,
	## Steam's own compressed voice, decoded with `decompressVoice`. Not built; the value exists so that building it is a
	## source swap rather than a wire change.
	STEAM = 1,
}

## WHO A FRAME IS FOR. The SENDER's intent, which the host reads and then enforces -- it is never what decides who
## actually receives the frame. The host decides that, from the roster's teams, because a client that could choose its
## own audience could send to a team it is not on.
enum Audience {
	EVERYONE = 0,
	TEAM = 1,
}


## PACK ONE BLOCK. `samples` is at `source_rate`; anything longer than a frame is refused rather than truncated, because
## a caller that hands over more than it thinks has a bug worth seeing.
static func encode(samples: PackedFloat32Array, source_rate: int, speaker: int, kind: Kind, audience: Audience,
		sequence: int) -> PackedByteArray:
	if samples.is_empty() or source_rate < RATE or speaker < 0 or speaker > 65535:
		return PackedByteArray()
	var mono: PackedFloat32Array = RadioClip.to_the_clip_rate(samples, source_rate)
	if mono.is_empty() or mono.size() > SAMPLES:
		return PackedByteArray()
	var first: int = clampi(int(round(mono[0] * 32767.0)), -32768, 32767)
	var out := PackedByteArray()
	out.resize(HEADER_BYTES + ceili(float(mono.size() - 1) / 2.0))
	out[0] = VERSION
	out[1] = int(kind)
	out[2] = int(Codec.CLIP_ADPCM)
	out[3] = int(audience)
	out.encode_u16(4, speaker)
	out.encode_u16(6, sequence & 0xffff)
	out.encode_u16(8, mono.size())
	out.encode_s16(10, first)
	out[12] = 0
	out[13] = 0
	var predictor: int = first
	var index: int = 0
	for i in range(1, mono.size()):
		var sample: int = clampi(int(round(mono[i] * 32767.0)), -32768, 32767)
		var coded: Array[int] = RadioClip.encode_one(sample, predictor, index)
		predictor = int(coded[1])
		index = int(coded[2])
		var at: int = HEADER_BYTES + floori(float(i - 1) / 2.0)
		if (i - 1) & 1:
			out[at] |= int(coded[0]) << 4
		else:
			out[at] = int(coded[0])
	return out


## WHY THESE BYTES ARE NOT A FRAME, or "". Every field is checked before a byte is trusted, because this arrives from
## another machine (CLAUDE.md rule 8) -- and it arrives on the carrier that may deliver the same packet twice.
static func problem(bytes: PackedByteArray) -> String:
	if bytes.size() < HEADER_BYTES:
		return "A voice frame's header is short."
	if int(bytes[0]) != VERSION:
		return "A voice frame of version %d, and this build speaks %d." % [int(bytes[0]), VERSION]
	if int(bytes[1]) != Kind.LIVE and int(bytes[1]) != Kind.GENERATED:
		return "A voice frame of no kind this build has."
	if int(bytes[2]) != Codec.CLIP_ADPCM:
		return "A voice frame in a codec this build cannot decode."
	if int(bytes[3]) != Audience.EVERYONE and int(bytes[3]) != Audience.TEAM:
		return "A voice frame for no audience this build has."
	var count: int = int(bytes.decode_u16(8))
	if count <= 0 or count > SAMPLES:
		return "A voice frame of %d samples, and a frame holds 1 to %d." % [count, SAMPLES]
	if int(bytes[12]) > 88:
		return "A voice frame with an ADPCM step index outside the table."
	if bytes.size() != HEADER_BYTES + ceili(float(count - 1) / 2.0):
		return "A voice frame whose payload is not the size its sample count says."
	return ""


## UNPACK ONE, as {speaker, kind, codec, audience, sequence, samples} -- or {"why": ...}. `samples` is PCM16.
static func decode(bytes: PackedByteArray) -> Dictionary:
	var why: String = problem(bytes)
	if not why.is_empty():
		return {"why": why}
	var count: int = int(bytes.decode_u16(8))
	var predictor: int = int(bytes.decode_s16(10))
	var index: int = int(bytes[12])
	var pcm := PackedInt32Array()
	pcm.resize(count)
	pcm[0] = predictor
	for i in range(1, count):
		var byte: int = int(bytes[HEADER_BYTES + floori(float(i - 1) / 2.0)])
		var nibble: int = (byte >> 4) & 15 if (i - 1) & 1 else byte & 15
		var decoded: Array[int] = RadioClip.decode_one(nibble, predictor, index)
		predictor = int(decoded[0])
		index = int(decoded[1])
		pcm[i] = predictor
	return {"speaker": int(bytes.decode_u16(4)), "kind": int(bytes[1]), "codec": int(bytes[2]),
		"audience": int(bytes[3]), "sequence": int(bytes.decode_u16(6)), "samples": pcm}


## THE LABEL ALONE, without decoding the audio: what the host needs to decide who may hear this, and all it needs.
## A host that had to decode a frame to route it would be doing the listener's work on every frame of every speaker.
static func label(bytes: PackedByteArray) -> Dictionary:
	var why: String = problem(bytes)
	if not why.is_empty():
		return {"why": why}
	return {"speaker": int(bytes.decode_u16(4)), "kind": int(bytes[1]), "codec": int(bytes[2]),
		"audience": int(bytes[3]), "sequence": int(bytes.decode_u16(6))}


## THE HOST WRITES THE SPEAKER, always, from the peer the frame arrived on -- a sender does not get to say who it is.
## Done in place on the bytes rather than by decoding and re-encoding: the host relays frames, it does not listen to
## them.
static func stamp_the_speaker(bytes: PackedByteArray, speaker: int) -> PackedByteArray:
	var out: PackedByteArray = bytes.duplicate()
	if out.size() >= HEADER_BYTES and speaker >= 0 and speaker <= 65535:
		out.encode_u16(4, speaker)
	return out


## PCM16 as an `AudioStreamWAV` at the frame rate, which is what plays it.
static func stream(samples: PackedInt32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, samples[i])
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = RATE
	wave.stereo = false
	wave.data = data
	return wave
