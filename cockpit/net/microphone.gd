class_name Microphone
extends Node
## THE THING THAT LISTENS, AND NOTHING ELSE. It opens an input device, cuts what it hears into frame-sized pieces, and
## ANNOUNCES them. It does not know that a network exists, what a team is, or who is allowed to hear it.
##
## ---------------------------------------------------------------------------------------------------
## THIS IS THE SEAM, AND IT IS NAMED ON PURPOSE
## ---------------------------------------------------------------------------------------------------
##
## The voice pipeline is a chain:
##
##   THIS -> `VoiceFrame.encode` -> `Net`'s voice envelope -> the host's routing and team filter -> decode -> play
##
## Steam's own capture, if it is ever wanted, replaces **this object and nothing else**. `tests/voice_probe.gd` measured
## what that would mean: `getVoice` hands back compressed bytes and `decompressVoice` turns them into PCM, so either
## this class grows a second source that decompresses to PCM and everything downstream is untouched, or the compressed
## bytes travel as they are and `VoiceFrame.Codec.STEAM` says so. **Keeping that door open costs nothing, which is why
## it is a separate object rather than a few lines inside the sender.**
##
## ---------------------------------------------------------------------------------------------------
## AND IT IS THE SEAM A TEST DRIVES
## ---------------------------------------------------------------------------------------------------
##
## Whether a microphone on this desk hears anything is a property of the desk (`tests/voice_probe.gd`: every device
## here reads silence). A headless suite therefore cannot start at a real microphone -- so it starts at the last place
## the real path is still the real path, which is `feed`: the same signal, the same frames, the same encoder, the same
## wire. The only thing a test replaces is the physical air.
##
## ---------------------------------------------------------------------------------------------------
## THE MICROPHONE IS OPEN ONLY WHILE SOMEBODY IS LISTENING
## ---------------------------------------------------------------------------------------------------
##
## `audio/driver/enable_input` is read by `AudioServer::set_input_device_active(true)`, which
## `AudioStreamPlaybackMicrophone::start()` calls when the stream begins playing -- NOT by the audio driver at start-up,
## whatever the editor's "requires restart" label says (working_with_godot.md, and measured: 0 input-buffer advances
## with the setting off against 22,793,280 with it set at runtime). So `open` sets it in THIS PROCESS and `close` stops
## the player, which calls `set_input_device_active(false)`. The flight sim opens no microphone; this one is open while
## a button is held and shut the rest of the time.

## A frame's worth of samples, announced. `rate` is the device's, not the wire's -- resampling belongs to the encoder,
## which is the one place that knows what the wire wants.
signal heard(samples: PackedFloat32Array, rate: int)

## The bus the input is captured on. Muted: a microphone sent to the speakers beside it howls.
const BUS: StringName = &"Microphone"
const SETTING: String = "audio/driver/enable_input"

## How many device samples make one wire frame, at the device's rate. 20 ms.
var _frame_samples: int = 0
var _capture: AudioEffectCapture = null
var _player: AudioStreamPlayer = null
var _spare: PackedFloat32Array = PackedFloat32Array()
var _open: bool = false
## Frames announced since this object was made, for a harness and for the lobby's own report line.
var frames_heard: int = 0
## What the last frame's loudest sample was, 0.0 to 1.0. The local "am I actually being heard" answer, and never the
## thing a lamp on ANOTHER player is lit from -- that is the host's to say.
var loudest: float = 0.0


func _ready() -> void:
	set_process(false)


## OPEN AN INPUT DEVICE IN THIS PROCESS. Returns "" or why not. Safe to call twice.
func open() -> String:
	if _open:
		return ""
	if not bool(ProjectSettings.get_setting(SETTING, false)):
		ProjectSettings.set_setting(SETTING, true)
	var index: int = AudioServer.get_bus_index(BUS)
	if index < 0:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, &"Master")
		AudioServer.set_bus_mute(index, true)
	if _capture == null:
		_capture = AudioEffectCapture.new()
		_capture.buffer_length = 1.0
		AudioServer.add_bus_effect(index, _capture)
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.name = "MicrophoneInput"
		_player.bus = BUS
		_player.stream = AudioStreamMicrophone.new()
		add_child(_player)
	_capture.clear_buffer()
	_spare.clear()
	_player.play()
	# THE DRIVER'S OWN INPUT BUFFER IS THE INSTRUMENT, not the bus. A bus delivers frames whether or not a device ever
	# opened -- they are simply zeros -- so a frame count off the capture effect cannot tell a working microphone from a
	# refused one in a silent room. This is only a first look; `heard` says nothing about whether the air is quiet.
	_frame_samples = maxi(1, int(round(float(AudioServer.get_mix_rate()) / 50.0)))
	_open = true
	set_process(true)
	return ""


## SHUT IT. `AudioStreamPlaybackMicrophone::stop()` calls `set_input_device_active(false)`, so the device closes here.
func close() -> void:
	if not _open:
		return
	_open = false
	set_process(false)
	if _player != null:
		_player.stop()
	if _capture != null:
		_capture.clear_buffer()
	_spare.clear()


func is_open() -> bool:
	return _open


## WHETHER THE DRIVER IS REALLY CAPTURING, asked of the driver rather than of the bus. See the note in `open`.
func the_driver_is_listening() -> bool:
	return AudioServer.get_input_frames_available() > 0


func _process(_delta: float) -> void:
	if not _open or _capture == null:
		return
	var ready: int = _capture.get_frames_available()
	if ready > 0:
		for stereo in _capture.get_buffer(ready):
			_spare.append((stereo.x + stereo.y) * 0.5)
	_announce_whole_frames(int(AudioServer.get_mix_rate()))


## THE HARNESS'S AIR. Hand it samples at `rate` and it cuts and announces them exactly as a device's would be -- same
## signal, same frames, same everything downstream. A suite starts here because a microphone is the desk's property.
func feed(samples: PackedFloat32Array, rate: int) -> void:
	_frame_samples = maxi(1, int(round(float(rate) / 50.0)))
	_spare.append_array(samples)
	_announce_whole_frames(rate)


## ONLY WHOLE FRAMES GO OUT, and the remainder waits for the next buffer. A short frame would still encode, and every
## short frame is a click at the far end.
func _announce_whole_frames(rate: int) -> void:
	while _spare.size() >= _frame_samples and _frame_samples > 0:
		var frame: PackedFloat32Array = _spare.slice(0, _frame_samples)
		_spare = _spare.slice(_frame_samples)
		var peak: float = 0.0
		for sample in frame:
			peak = maxf(peak, absf(sample))
		loudest = peak
		frames_heard += 1
		heard.emit(frame, rate)
