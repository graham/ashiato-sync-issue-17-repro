@tool
class_name RadioBus
extends RefCounted

## Builds the audio bus that gives a channel its radio colour.
##
## The band-pass, distortion and compression here are ordinary Godot bus effects,
## so once a bus exists you can tune it by ear in the editor and save the layout.
## This helper only supplies a sane starting point, because a shipped binary bus
## layout is not something you can read in a diff.
##
## The cues locked to utterance boundaries, the mic click and squelch tail, are
## not here: a bus effect cannot see where an utterance starts, so those live in
## the extension's mix callback instead.

## Communications voice band. Anything outside roughly 300 Hz to 3 kHz is what a
## radio throws away, and throwing it away is most of the effect.
const BAND_LOW_HZ := 300.0
const BAND_HIGH_HZ := 3000.0


## Creates `bus_name` routed to `send_to`, replacing it if it already exists.
static func create(bus_name: String, send_to: String = "Master") -> int:
	var existing: int = AudioServer.get_bus_index(bus_name)
	if existing != -1:
		return existing

	var index: int = AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, send_to)

	var high_pass := AudioEffectHighPassFilter.new()
	high_pass.cutoff_hz = BAND_LOW_HZ
	high_pass.resonance = 0.4
	AudioServer.add_bus_effect(index, high_pass)

	var low_pass := AudioEffectLowPassFilter.new()
	low_pass.cutoff_hz = BAND_HIGH_HZ
	low_pass.resonance = 0.4
	AudioServer.add_bus_effect(index, low_pass)

	# Light drive, not fuzz. Too much and callsigns stop being intelligible,
	# which defeats the point of the radio.
	var drive := AudioEffectDistortion.new()
	drive.mode = AudioEffectDistortion.MODE_OVERDRIVE
	drive.drive = 0.18
	drive.pre_gain = 2.0
	drive.post_gain = -3.0
	AudioServer.add_bus_effect(index, drive)

	# Radio audio is heavily levelled, which is why a distant aircraft is as loud
	# as a close one.
	var squash := AudioEffectCompressor.new()
	squash.threshold = -18.0
	squash.ratio = 6.0
	squash.attack_us = 20.0
	squash.release_ms = 120.0
	AudioServer.add_bus_effect(index, squash)

	var ceiling := AudioEffectHardLimiter.new()
	ceiling.ceiling_db = -0.5
	AudioServer.add_bus_effect(index, ceiling)

	return index


## Removes a bus created by create(). Safe to call when it does not exist.
static func destroy(bus_name: String) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index > 0:
		AudioServer.remove_bus(index)
