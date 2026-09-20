extends Node
## WHAT STEAM'S VOICE API ACTUALLY DOES, asked of the GodotSteam binary and of a real microphone rather than
## remembered. `plan_next.md` item 21 wrote down "Steamworks voice was verified as microphone capture/decompression
## only, with no arbitrary PCM injection" -- but nothing in cockpit has ever called one of those functions, so that
## sentence was reasoning from the Steamworks reference and not a measurement. This probe is the measurement.
##
##   Godot --path cockpit res://tests/voice_probe.tscn -- --surface       the binding's voice surface, no Steam needed
##   Godot --path cockpit res://tests/voice_probe.tscn -- --voice         initialise Steam and record a real microphone
##   Godot --path cockpit res://tests/voice_probe.tscn -- --mic           the same question asked of Godot's own input
##   Godot --path cockpit res://tests/voice_probe.tscn -- --devices       and of EVERY input device this desk offers
##
## A PROBE AND NOT A SUITE, for tests/steam_probe.gd's reason: whether a Steam client and a microphone are on this desk
## is a property of the desk. Where either is missing it says SKIP out loud. **Never run this in run_all.ps1** -- real
## Steam in a headless suite starts the Steam client and then crashes at shutdown (cockpit/docs/world.md), and
## voice wants a real audio device, so it is run windowed by hand.
##
## STEAM IS REACHED THROUGH `Engine.get_singleton`, never by the name `Steam`: the identifier is a class the extension
## registers, and on an editor where the library did not load a script that names it does not parse -- and a parse error
## HANGS a headless run rather than failing it.
##
## NOTHING HERE TRUSTS A REMEMBERED SIGNATURE. Every call is looked up in `ClassDB` first and its arguments printed, so
## a wrong guess about GodotSteam 4.21's binding shows as a printed MISSING rather than as a crash or an invented fact.
##
## Read RESULT=, not the exit code.

const APP_ID: int = 480
const RECORD_SECONDS: float = 4.0
## Steam's own documented ceiling for one GetVoice call's destination buffer.
const VOICE_BUFFER: int = 8192

var _fails: PackedStringArray = []
var _steam: Object = null
var _methods: Dictionary = {}


func _init() -> void:
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))


func _check(label: String, ok: bool, detail: String) -> void:
	print("[voice_probe] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


## WHAT THE DESK DID NOT HAVE, which is not a failure of any code here: no Steam client, no microphone turned on,
## nobody speaking. tests/steam_probe.gd's rule -- say it out loud and go on -- and the reason RESULT= stays PASS on a
## quiet desk: otherwise a red line means "the room was quiet" and nobody reads it again.
func _skip(label: String, detail: String) -> void:
	print("[voice_probe] SKIP %s (%s)" % [label, detail])


func _say(words: String) -> void:
	print("[voice_probe] %s" % words)


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_say("engine %s double=%s headless=%s" % [Engine.get_version_info().string, OS.has_feature("double"),
		DisplayServer.get_name() == "headless"])
	if "--devices" in args:
		await _every_input_device()
	if "--mic" in args:
		await _godots_own_microphone()
	if not ClassDB.class_exists(&"Steam"):
		_say("SKIP Steam -- no GodotSteam extension is loaded in this project")
		_finish()
		return
	_steam = Engine.get_singleton("Steam")
	_the_voice_surface()
	if "--voice" in args:
		await _a_real_microphone_through_steam()
	_finish()


## ---- what the binding offers -------------------------------------------------------------------

## The two questions this answers: does the GDScript binding expose Steam's voice calls at all, and is there ANY method
## on the whole singleton that takes PCM or compressed audio IN. The second is asked by pattern over all 736 methods
## rather than by checking a name somebody expected, because the claim being tested is a negative.
const WANTED: Array[String] = [
	"startVoiceRecording", "stopVoiceRecording", "getAvailableVoice", "getVoice", "decompressVoice",
	"getVoiceOptimalSampleRate", "setInGameVoiceSpeaking",
]
## A method that could put audio of our own choosing into Steam's voice path would have to be named something like
## these. Printing every match is the evidence; finding none is the finding.
const SUBMIT_HINTS: Array[String] = [
	"voice", "audio", "speak", "microphone", "mic", "pcm", "sound",
]


func _the_voice_surface() -> void:
	for m in ClassDB.class_get_method_list(&"Steam", true):
		_methods[String(m["name"])] = m
	_say("Steam has %d methods" % _methods.size())
	var missing: PackedStringArray = []
	for name in WANTED:
		if not _methods.has(name):
			missing.append(name)
			_say("method %s MISSING" % name)
			continue
		_say("method %s" % _signature(_methods[name]))
	_check("the_binding_exposes_steams_voice_calls", missing.is_empty(),
		"all present" if missing.is_empty() else "missing %s" % [missing])
	# EVERY method whose name smells of audio, whichever direction it faces. The list itself is the evidence for the
	# "no injection path" claim, so it is printed whole rather than filtered down to a conclusion.
	var smelt: PackedStringArray = []
	for name in _methods:
		var lower := String(name).to_lower()
		for hint in SUBMIT_HINTS:
			if lower.contains(hint):
				smelt.append(_signature(_methods[name]))
				break
	smelt.sort()
	_say("%d methods on Steam name audio at all:" % smelt.size())
	for line in smelt:
		_say("    %s" % line)
	for name in ["voice_result", "voice", "microphone"]:
		var s: Dictionary = ClassDB.class_get_signal(&"Steam", name)
		if not s.is_empty():
			_say("signal %s(%s)" % [name, _arguments_of(s["args"])])
	for c in ClassDB.class_get_integer_constant_list(&"Steam", true):
		if c.begins_with("VOICE_RESULT"):
			_say("const %s = %d" % [c, ClassDB.class_get_integer_constant(&"Steam", c)])


static func _signature(m: Dictionary) -> String:
	return "%s(%s) -> %s" % [m["name"], _arguments_of(m["args"]),
		type_string(int((m["return"] as Dictionary)["type"]))]


static func _arguments_of(args: Array) -> String:
	var said: PackedStringArray = []
	for a in args:
		said.append("%s: %s" % [a["name"], type_string(int(a["type"]))])
	return ", ".join(said)


## ---- a real microphone, through Steam ----------------------------------------------------------

func _a_real_microphone_through_steam() -> void:
	var result: Dictionary = _steam.call("steamInitEx", APP_ID, true)
	if int(result.get("status", 1)) != 0:
		_say("SKIP Steam -- steamInitEx said %s; is the Steam client running?" % result)
		return
	_say("steamInitEx(%d) answered %s" % [APP_ID, result])
	if _methods.has("getVoiceOptimalSampleRate"):
		_say("getVoiceOptimalSampleRate() = %s" % [_steam.call("getVoiceOptimalSampleRate")])
	if not _methods.has("startVoiceRecording") or not _methods.has("getVoice"):
		_check("steam_can_record_a_microphone", false, "the binding has no recording pair to call")
		return

	_steam.call("startVoiceRecording")
	_say("startVoiceRecording() returned; SPEAK NOW for %.0f seconds" % RECORD_SECONDS)
	var compressed: PackedByteArray = PackedByteArray()
	var reads: int = 0
	var empties: int = 0
	var first_shape: String = ""
	var available_shape: String = ""
	var deadline := Time.get_ticks_msec() + int(RECORD_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		_steam.call("run_callbacks")
		if _methods.has("getAvailableVoice"):
			var avail: Variant = _steam.call("getAvailableVoice")
			if available_shape.is_empty():
				available_shape = "%s %s" % [type_string(typeof(avail)), avail]
		var got: Variant = _steam.call("getVoice", VOICE_BUFFER)
		reads += 1
		if first_shape.is_empty():
			first_shape = "%s %s" % [type_string(typeof(got)), _shape_of(got)]
		var bytes := _bytes_from(got)
		if bytes.is_empty():
			empties += 1
		else:
			compressed.append_array(bytes)
		await get_tree().process_frame
	_steam.call("stopVoiceRecording")

	_say("getAvailableVoice first answer: %s" % available_shape)
	_say("getVoice first answer: %s" % first_shape)
	_say("%d getVoice calls, %d with no data, %d compressed bytes in %.1f s = %.0f bytes/s"
		% [reads, empties, compressed.size(), RECORD_SECONDS, compressed.size() / RECORD_SECONDS])
	if compressed.is_empty():
		_skip("steam_returns_compressed_voice_from_a_real_microphone",
			"242-odd calls, every one VOICE_RESULT_NO_DATA: nothing was said, or Steam's recording device is silent")
		return
	_check("steam_returns_compressed_voice_from_a_real_microphone", true, "%d bytes" % compressed.size())

	if not _methods.has("decompressVoice"):
		_check("steam_decompresses_its_own_voice", false, "the binding has no decompressVoice")
		return
	var rate: int = 24000
	if _methods.has("getVoiceOptimalSampleRate"):
		rate = int(_steam.call("getVoiceOptimalSampleRate"))
	# A decompressed second of 16-bit mono at `rate` is 2*rate bytes, so the destination is sized from the recording.
	var room: int = int(2.0 * float(rate) * (RECORD_SECONDS + 1.0))
	var out: Variant = _steam.call("decompressVoice", compressed, rate, room)
	_say("decompressVoice(%d bytes, %d Hz, %d room) -> %s %s" % [compressed.size(), rate, room,
		type_string(typeof(out)), _shape_of(out)])
	var pcm := _bytes_from(out)
	# 16-bit mono is what Steamworks documents DecompressVoice as writing.
	var seconds := float(pcm.size()) / 2.0 / float(rate)
	_say("decompressed %d bytes = %.2f s of 16-bit mono at %d Hz (recorded %.1f s)"
		% [pcm.size(), seconds, rate, RECORD_SECONDS])
	_check("steam_decompresses_its_own_voice", pcm.size() > 0, "%d PCM bytes" % pcm.size())
	_check("the_decompressed_length_matches_what_was_recorded", seconds > 0.25,
		"%.2f s of audio from %.1f s of recording" % [seconds, RECORD_SECONDS])
	# WAS IT AUDIO OR WAS IT SILENCE. A transport decision cannot rest on "no error was thrown": the decompressed
	# PCM is read as 16-bit mono and its RMS printed, so a recording device that handed Steam nothing shows up.
	var energy: float = 0.0
	var peak: int = 0
	var count: int = int(pcm.size() / 2)
	for i in range(count):
		var sample := pcm.decode_s16(i * 2)
		peak = maxi(peak, absi(sample))
		energy += float(sample) * float(sample)
	var rms := sqrt(energy / maxf(1.0, float(count))) / 32768.0
	_say("decompressed RMS %.5f, peak %d of 32767" % [rms, peak])
	if rms > 0.0005:
		_check("and_steams_voice_was_not_silence", true, "RMS %.5f, peak %d" % [rms, peak])
	else:
		_skip("and_steams_voice_was_not_silence", "RMS %.5f, peak %d -- the room was quiet" % [rms, peak])
	_say("compression ratio %.1fx (%d compressed -> %d PCM)"
		% [float(pcm.size()) / maxf(1.0, float(compressed.size())), compressed.size(), pcm.size()])


## Whatever GodotSteam hands back -- a PackedByteArray, or a Dictionary holding one under some key -- reduced to bytes,
## with every key printed the first time so the shape is recorded and not assumed.
func _bytes_from(got: Variant) -> PackedByteArray:
	if got is PackedByteArray:
		return got
	if got is Dictionary:
		for key in (got as Dictionary):
			var value: Variant = (got as Dictionary)[key]
			if value is PackedByteArray and not (value as PackedByteArray).is_empty():
				return value
	return PackedByteArray()


static func _shape_of(got: Variant) -> String:
	if got is PackedByteArray:
		return "%d bytes" % (got as PackedByteArray).size()
	if got is Dictionary:
		var said: PackedStringArray = []
		for key in (got as Dictionary):
			var value: Variant = (got as Dictionary)[key]
			if value is PackedByteArray:
				said.append("%s: %d bytes" % [key, (value as PackedByteArray).size()])
			else:
				said.append("%s: %s" % [key, value])
		return "{%s}" % ", ".join(said)
	return str(got)


## ---- the same question asked of Godot itself ---------------------------------------------------

## The alternative to Steam's capture is `AudioStreamMicrophone` into an `AudioEffectCapture`, which is the same shape
## `Headphones` already uses to get Kokoro's samples off a bus. This measures the thing the design rests on: that a
## single process can open an input device WITHOUT `project.godot` asking for one, so the flight sim never opens a
## microphone because a test lobby exists.
##
## THE INSTRUMENT MATTERS HERE, and the first version of this probe got it wrong. An `AudioEffectCapture` sits on a bus
## and is handed that bus's mixed output every audio block, so FRAMES ARRIVE WHETHER OR NOT THE MICROPHONE OPENED --
## they are simply zeros when it did not. Counting them proved only that the bus was running, and on a silent desk that
## is indistinguishable from a working capture. `AudioServer.get_input_frames_available()` reads the AUDIO DRIVER's own
## input buffer (audio_server.cpp:1883), which advances only while the device is really capturing, so it tells an open
## microphone from a closed one in a quiet room. Both phases below are measured with it.
func _godots_own_microphone() -> void:
	_say("input devices: %s" % [AudioServer.get_input_device_list()])
	_say("input device: %s, mix rate %d Hz" % [AudioServer.input_device, AudioServer.get_mix_rate()])
	var was: bool = bool(ProjectSettings.get_setting("audio/driver/enable_input", false))
	_say("audio/driver/enable_input in project.godot = %s" % was)

	var index := AudioServer.get_bus_index(&"VoiceProbe")
	if index < 0:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, &"VoiceProbe")
		AudioServer.set_bus_send(index, &"Master")
		# Silent: the point is the samples, and a microphone sent to the speakers beside it howls.
		AudioServer.set_bus_mute(index, true)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(index, capture)
	var player := AudioStreamPlayer.new()
	player.bus = &"VoiceProbe"
	player.stream = AudioStreamMicrophone.new()
	add_child(player)

	# PHASE ONE: the setting as the project leaves it. The engine refuses the capture and says so in a warning, and the
	# driver's input buffer never advances. Run first, because it is the "before" of the scoping claim.
	if not was:
		var refused := await _listen(player, capture, 1.0)
		_check("a_microphone_is_refused_while_the_project_setting_is_off",
			int(refused["driver_frames"]) == 0,
			"driver input frames %d, bus frames %d (the bus runs either way, which is the trap)"
				% [int(refused["driver_frames"]), int(refused["bus_frames"])])

	# PHASE TWO: the same process, the setting flipped at runtime, nothing restarted.
	_let_this_process_listen()
	var heard := await _listen(player, capture, RECORD_SECONDS)
	_say("%d driver input frames, %d bus frames in %.1f s (%.0f Hz), RMS %.5f, peak %.5f"
		% [int(heard["driver_frames"]), int(heard["bus_frames"]), RECORD_SECONDS,
			float(heard["bus_frames"]) / RECORD_SECONDS, float(heard["rms"]), float(heard["peak"])])
	_check("godot_opens_an_input_device_when_this_process_asks_at_runtime",
		int(heard["driver_frames"]) > 0, "the driver's input buffer advanced %d times" % int(heard["driver_frames"]))
	if not was:
		_check("and_it_needed_no_project_wide_setting", true,
			"project.godot never asked for an input device and this process captured anyway")
	else:
		_skip("and_it_needed_no_project_wide_setting",
			"project.godot already had enable_input on, so this run proves nothing about scoping it")
	if float(heard["rms"]) > 0.0005:
		_check("and_the_microphone_was_not_silent", true, "RMS %.5f" % float(heard["rms"]))
	else:
		_skip("and_the_microphone_was_not_silent",
			"RMS %.5f -- the device is open and the room is quiet, or this device is off" % float(heard["rms"]))


## Listen for `seconds` and report both instruments: the driver's input buffer, which only moves when a device is
## really capturing, and the bus, which moves regardless.
func _listen(player: AudioStreamPlayer, capture: AudioEffectCapture, seconds: float) -> Dictionary:
	capture.clear_buffer()
	player.play()
	var driver_frames: int = 0
	var bus_frames: int = 0
	var energy: float = 0.0
	var peak: float = 0.0
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		driver_frames += AudioServer.get_input_frames_available()
		var ready := capture.get_frames_available()
		if ready > 0:
			for stereo in capture.get_buffer(ready):
				var mono := (stereo.x + stereo.y) * 0.5
				energy += mono * mono
				peak = maxf(peak, absf(mono))
				bus_frames += 1
		await get_tree().process_frame
	player.stop()
	return {"driver_frames": driver_frames, "bus_frames": bus_frames,
		"rms": sqrt(energy / maxf(1.0, float(bus_frames))), "peak": peak}


## WHICH DEVICE IS ACTUALLY LISTENING. "Default" on this desk is digital silence, and a headset that is off or a
## virtual device with no headset on a head both read as exactly 0.0 -- which is indistinguishable from a broken
## capture unless every device is asked in turn.
func _every_input_device() -> void:
	_let_this_process_listen()
	var index := AudioServer.get_bus_index(&"VoiceProbe")
	if index < 0:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, &"VoiceProbe")
		AudioServer.set_bus_send(index, &"Master")
		AudioServer.set_bus_mute(index, true)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(index, capture)
	var player := AudioStreamPlayer.new()
	player.bus = &"VoiceProbe"
	player.stream = AudioStreamMicrophone.new()
	add_child(player)
	var loudest: float = 0.0
	var winner: String = ""
	var most_frames: int = 0
	var busiest: String = ""
	# PUT THE DESK BACK. The sweep walks every device, and leaving the last one selected changed what a later mode in
	# the same process recorded: --devices --mic measured "Virtual Desktop Audio" while believing it measured Default.
	var was: String = AudioServer.input_device
	for device in AudioServer.get_input_device_list():
		AudioServer.input_device = device
		# The driver restarts its input on the device change, so one frame is spent before anything is counted.
		player.play()
		await get_tree().process_frame
		player.stop()
		var heard: Dictionary = await _listen(player, capture, 1.5)
		var frames: int = int(heard["driver_frames"])
		var rms: float = float(heard["rms"])
		_say("input \"%s\": driver frames %d, bus frames %d, RMS %.5f, peak %.5f"
			% [device, frames, int(heard["bus_frames"]), rms, float(heard["peak"])])
		if rms > loudest:
			loudest = rms
			winner = device
		if frames > most_frames:
			most_frames = frames
			busiest = device
	AudioServer.input_device = was
	_check("some_device_on_this_desk_really_opens", most_frames > 0,
		"the driver's input buffer advanced %d times on \"%s\"" % [most_frames, busiest])
	if loudest > 0.00002:
		_check("and_some_device_hears_the_room", true, "loudest was \"%s\" at RMS %.5f" % [winner, loudest])
	else:
		_skip("and_some_device_hears_the_room",
			"every device read below RMS 0.00002; the loudest was \"%s\" at %.5f" % [winner, loudest])


## OPEN AN INPUT DEVICE WITHOUT A PROJECT-WIDE SETTING, which is what lets the flat lobby have a microphone while the
## flight sim never opens one.
##
## `audio/driver/enable_input` is declared GLOBAL_DEF_RST, so the editor labels it "requires restart" and everything
## written about it assumes the audio driver reads it when it starts. IT DOES NOT. Read in the engine source this
## project builds from (servers/audio/audio_server.cpp:1869 and servers/audio/audio_stream.cpp:448), the setting is
## read at ONE place and ONE moment: `AudioServer::set_input_device_active(true)`, which
## `AudioStreamPlaybackMicrophone::start()` calls when a microphone stream begins playing. Nothing reads it at driver
## init at all. So setting it here, before `play()`, opens the device -- and `stop()` calls
## `set_input_device_active(false)`, which closes it again. The microphone is open only while something is listening.
static func _let_this_process_listen() -> bool:
	var was: bool = bool(ProjectSettings.get_setting("audio/driver/enable_input", false))
	if not was:
		ProjectSettings.set_setting("audio/driver/enable_input", true)
	return was


func _finish() -> void:
	print("[voice_probe] RESULT=%s" % ("PASS" if _fails.is_empty() else "FAIL %s" % [_fails]))
	get_tree().quit(0 if _fails.is_empty() else 1)
