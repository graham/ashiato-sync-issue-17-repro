extends Node
## Headless: does the game start with both ears off, and does the voice either come on or say
## why it cannot -- without an engine error either way?
##
##   Godot --headless --path cockpit res://tests/headphones.tscn
##
## THREE REFUSALS AND ONE SUCCESS. The refusals are the half every machine runs: no library, no
## model, and a voice turned off while it is still loading. Each has to leave a sentence for the
## board and nothing on stderr, because the runner fails a suite that prints an engine error and
## a player's clipboard is the only place the reason would ever be read. The success needs the
## library AND the 325 MB model on this machine; where either is missing it says SKIP and why,
## and counts itself as skipped rather than passed.
##
## WHAT IT CANNOT HEAR. Whether it sounds like a tower is a windowed run with `--audio` and a pair of ears.
## What is checked is that a line was QUEUED on the tower's channel and reached its ring without a synthesis
## failure, and that VOICE off put the tower's radio away. This file used to say Godot's Dummy audio driver
## never runs the mix, after kokoro-gd's DESIGN.md; on 4.7.2 here, `--headless` does mix, at real time, and
## kokoro raises `utterance_started` and `utterance_finished` for every line -- which tests/chatter.gd
## reads (2026-09-14).
##
## BUT IT CAN SEE THE SOUND. `RadioChannel.get_transmitted()` counts every sample the worker put on the
## channel, with its loudest and its RMS, whether or not anything mixed it -- so "the radio check became
## more than a second of speech" is a number here, reached by the AUDIO tab's own switch pulled with the
## right hand's beam, as a player does it. "The speech features are testable" (2026-09-13).
##
## THE MODEL IS NOT LOADED UNTIL ASKED. A complete install prepares only the small native library during boot so the
## first switch pull cannot lose a headset frame; the first section runs before anything can build a server.
##
##   powershell -File tests\run_all.ps1 -Only headphones
##
## Read RESULT=, not the exit code.

var _failures: PackedStringArray = []
var _skipped: PackedStringArray = []
var _sections: int = 0

## HOW LONG A MODEL MAY TAKE TO LOAD, in WALL seconds. The one wall clock in this suite, and
## deliberately: the load happens on the extension's worker thread, which runs in real time
## however fast `--fixed-fps` drives the frames.
const LOAD_SECONDS: float = 60.0
## How long a queued line is given to be synthesised before a failure would have arrived.
const SPEAK_SECONDS: float = 10.0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[headphones] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _skip(label: String, why: String) -> void:
	print("[headphones] SKIP %s (%s)" % [label, why])
	_skipped.append(label)


func _ready() -> void:
	_both_ears_start_off()
	await _the_voice_is_not_loaded_until_asked()
	await _no_library_is_a_sentence()
	await _no_model_is_a_sentence()
	await _the_tower_answers_a_radio_check()
	await _off_while_loading_lets_go_of_the_model()
	await _the_beam_on_voice_speaks_the_radio_check()
	_finish()


## ---- native code ready, model still lazy -------------------------------------------------

## HOW LONG THE GAME RUNS WITH VOICE OFF before checking that boot built no server, in frames.
const BOOT_FRAMES: int = 60

## A COMPLETE OPTIONAL INSTALL PREPARES THE SMALL NATIVE LIBRARY AT BOOT, when a long frame is still part of loading,
## while leaving the expensive model and worker absent. This keeps the first in-game switch pull under a headset
## frame. A machine without the library remains valid, so the invariant here is the absent server/model rather than
## the presence of a class. First in the suite because every later section turns VOICE on.
func _the_voice_is_not_loaded_until_asked() -> void:
	await _frames(BOOT_FRAMES)
	_check("with_voice_off_the_model_and_worker_are_not_loaded", not Headphones.voice_on()
		and Headphones.server() == null and Headphones.radio() == null,
		"after %d frames: voice %s, server %s, radio %s" % [BOOT_FRAMES, Headphones.voice,
			Headphones.server(), Headphones.radio()])
	_sections += 1


## ---- the switch on the board, and the sound it makes -------------------------------------

## More than this much of the radio check reaching the channel is a line spoken, not a click. The line is 2.7 s of
## speech (kokoro-gd's DESIGN.md, measured with its CLI).
const SPOKEN_SECONDS: float = 1.0
## The quietest a spoken line's loudest sample may be. Speech from this model peaks in the tenths; silence and the
## trimmed pads either side of a line are hundredths at most.
const SPOKEN_PEAK: float = 0.05
## How many times VOICE goes off and on again through the switch.
const TOGGLES: int = 10

## VOICE ON WITH THE BEAM, AND THE TOWER'S RADIO CHECK BECOMES SOUND.
##
## The AUDIO tab's own switch, pulled with the right hand's beam and trigger (`_beam_presses`, the pull
## `tests/clipboard.gd` gives GAME SOUND), so it is the rig's wiring and the headphones' decision that turn the voice
## on -- not a call made on their behalf. Then: the ONNX Runtime in use is the one beside the library, not System32's;
## more than SPOKEN_SECONDS of speech with a peak over SPOKEN_PEAK reached the tower's channel; and VOICE goes off and
## on TOGGLES times through the same switch, coming back each time and still speaking on the last. An engine error or
## a leak on the way fails the suite in the runner. SKIPs, with the reason, where the library or the model is absent.
func _the_beam_on_voice_speaks_the_radio_check() -> void:
	var why: String = Headphones.why_there_is_no_voice()
	if not why.is_empty():
		_skip("the_beam_on_voice_speaks_the_radio_check", why)
		return
	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	var board: Clipboard = rig.clipboard
	var page: ClipboardPage = board.page()
	board.show_board(true)
	page.show_tab(ClipboardPage.Tab.AUDIO)
	await _frames(3)
	var voice := page.get("_voice") as CheckButton
	if voice == null:
		_check("the_audio_tab_has_a_voice_switch", false, "no _voice on %s" % [page])
		rig.queue_free()
		return

	await _beam_presses(rig, voice)
	var loaded: bool = await _wall_until(func() -> bool: return Headphones.voice == PilotHeadphones.Voice.ON,
		LOAD_SECONDS)
	_check("the_beam_on_voice_loads_the_model_and_the_switch_shows_it", loaded and voice.button_pressed,
		"voice %s, switch %s, said '%s'" % [Headphones.voice, voice.button_pressed, Headphones.said])
	if not loaded:
		await _beam_presses(rig, voice)
		rig.queue_free()
		await _frames(2)
		return

	var runtime: Dictionary = Headphones.server().call("get_runtime")
	var runtime_path: String = String(runtime.get("path", "")).replace("\\", "/").to_lower()
	_check("and_the_onnx_runtime_is_the_one_beside_the_library",
		runtime_path.ends_with("addons/kokoro_gd/bin/onnxruntime.dll") or not OS.has_feature("windows"),
		"%s" % [runtime])

	var first: Dictionary = await _spoken_on(Headphones.radio())
	_check("and_the_radio_check_is_more_than_a_second_of_speech",
		float(first.get("seconds", 0.0)) > SPOKEN_SECONDS and float(first.get("peak", 0.0)) > SPOKEN_PEAK,
		"%s" % [first])

	var came_back: int = 0
	for i in range(TOGGLES):
		await _beam_presses(rig, voice)
		await _frames(2)
		if Headphones.voice_on() or voice.button_pressed:
			break
		await _beam_presses(rig, voice)
		if await _wall_until(func() -> bool: return Headphones.voice == PilotHeadphones.Voice.ON, LOAD_SECONDS):
			came_back += 1
	_check("and_%d_times_off_and_on_it_comes_back_each_time" % TOGGLES, came_back == TOGGLES and voice.button_pressed,
		"%d of %d, voice %s, said '%s'" % [came_back, TOGGLES, Headphones.voice, Headphones.said])
	var last: Dictionary = await _spoken_on(Headphones.radio())
	_check("and_on_the_last_it_still_speaks", float(last.get("seconds", 0.0)) > SPOKEN_SECONDS
		and float(last.get("peak", 0.0)) > SPOKEN_PEAK, "%s" % [last])

	await _beam_presses(rig, voice)
	await _frames(2)
	_check("and_the_last_pull_lets_go_of_the_model", not Headphones.voice_on() and not voice.button_pressed
		and Headphones.server() == null and Headphones.radio() == null, "voice %s" % Headphones.voice)
	board.show_board(false)
	rig.queue_free()
	await _frames(2)
	_sections += 1


## What `channel` has transmitted once more than SPOKEN_SECONDS of it has gone out, or after SPEAK_SECONDS of wall
## time, whichever is first. {} with no channel.
func _spoken_on(channel: AudioStream) -> Dictionary:
	if channel == null:
		return {}
	await _wall_until(func() -> bool:
		return float((channel.call("get_transmitted") as Dictionary).get("seconds", 0.0)) > SPOKEN_SECONDS,
		SPEAK_SECONDS)
	return channel.call("get_transmitted")


## ONE PULL OF THE RIGHT TRIGGER with the right hand's beam on `target`: at rest, down, up again, the hand re-posed on
## the glass every frame. The same pull `tests/clipboard.gd` gives the AUDIO tab and RESET HEAD.
func _beam_presses(rig: PilotRig, target: Control) -> void:
	for trigger in [0.0, 0.0, 1.0, 1.0, 0.0, 0.0]:
		var panel: TouchPanel = rig.clipboard.panel()
		var screen := panel.get("_screen") as SubViewport
		var centre: Vector2 = target.get_global_rect().get_center()
		var on_glass := Vector3((centre.x / float(screen.size.x) - 0.5) * panel.size.x,
			(0.5 - centre.y / float(screen.size.y)) * panel.size.y, 0.0)
		var aimed_at: Vector3 = panel.to_global(on_glass)
		var hand_at: Vector3 = aimed_at + panel.global_basis.z.normalized() * 0.30
		rig.force_hand(1, Transform3D(Basis.looking_at(aimed_at - hand_at, panel.global_basis.y.normalized()), hand_at))
		rig.force_input(1, Bind.TRIGGER, trigger)
		await get_tree().process_frame
	rig.force_input(1, Bind.TRIGGER, null)
	rig.force_hand(1, null)
	await get_tree().process_frame


## ---- at start ------------------------------------------------------------------------

## BOTH OFF, AND THE GAME BUS MUTED, with no `--audio` on this suite's command line.
func _both_ears_start_off() -> void:
	_check("this_run_did_not_ask_for_sound",
		not PilotHeadphones.asked_for(OS.get_cmdline_user_args())
			and not PilotHeadphones.asked_for(OS.get_cmdline_args()), "no %s" % PilotHeadphones.AUDIO_FLAG)
	_check("game_sound_starts_off", not Headphones.game_sound, "game_sound %s" % Headphones.game_sound)
	_check("and_so_does_the_voice", not Headphones.voice_on() and Headphones.server() == null,
		"voice %s, server %s" % [Headphones.voice, Headphones.server()])
	var game: int = AudioServer.get_bus_index(PilotHeadphones.GAME_BUS)
	var radio: int = AudioServer.get_bus_index(PilotHeadphones.RADIO_BUS)
	_check("there_is_a_game_bus_and_it_is_muted", game > 0 and AudioServer.is_bus_mute(game),
		"bus %d, mute %s" % [game, AudioServer.is_bus_mute(game) if game > 0 else null])
	_check("and_a_radio_bus_that_is_not", radio > 0 and radio != game and not AudioServer.is_bus_mute(radio),
		"bus %d" % radio)
	# ONE WORD FOR THE FLAG, asked of both places a caller might read it. Which bus the engine note
	# is on cannot be asked here: headless builds no player to ask. That is a windowed run's.
	_check("the_flag_is_the_one_word", VehicleSound.AUDIO_FLAG == PilotHeadphones.AUDIO_FLAG
		and PilotHeadphones.asked_for(PackedStringArray(["--level=fly", "--audio"])),
		"%s" % VehicleSound.AUDIO_FLAG)
	_sections += 1


## ---- the refusals --------------------------------------------------------------------

## NO LIBRARY: VOICE stays off, the board is told so, and nothing is loaded. Proved by pointing
## the node at a configuration that is not there, which is what a machine without the addon
## looks like to it. The real proof -- the bin folder moved away and the game booted -- is in
## agents.md, "A VOICE ON THE RADIO", because a suite cannot move its own addon.
func _no_library_is_a_sentence() -> void:
	var told: Array = []
	var listen := func(game: bool, voice: bool, said: String): told.append([voice, said])
	Headphones.changed.connect(listen)
	Headphones.extension_path = "res://addons/kokoro_gd/bin/nowhere.gdextension"
	Headphones.choose_voice(true)
	await _frames(2)
	Headphones.extension_path = PilotHeadphones.EXTENSION
	Headphones.changed.disconnect(listen)
	_check("with_no_library_voice_stays_off", not Headphones.voice_on() and Headphones.server() == null,
		"voice %s" % Headphones.voice)
	_check("and_the_board_is_told_why_and_what_fixes_it", told.size() == 1 and not bool(told[0][0])
		and String(told[0][1]).begins_with("No voice library") and String(told[0][1]).contains("kokoro-gd"),
		"told %s" % [told])
	_sections += 1


## NO MODEL: the same, with the model looked for where `KOKORO_MODELS` says and nothing there.
func _no_model_is_a_sentence() -> void:
	if Headphones.why_there_is_no_voice().begins_with("No voice library"):
		_skip("no_model_is_a_sentence", "no library on this machine, so the model is never looked for")
		return
	var nowhere: String = ProjectSettings.globalize_path("user://no_voice_model_here")
	OS.set_environment(PilotHeadphones.MODELS_VARIABLE, nowhere)
	Headphones.choose_voice(true)
	await _frames(2)
	var said: String = Headphones.said
	OS.unset_environment(PilotHeadphones.MODELS_VARIABLE)
	_check("with_no_model_voice_stays_off", not Headphones.voice_on() and Headphones.server() == null,
		"voice %s" % Headphones.voice)
	_check("and_the_board_names_where_it_looked_and_what_fixes_it",
		said == "No voice model at %s: %s" % [nowhere, PilotHeadphones.FETCH_MODEL], "said '%s'" % said)
	_sections += 1


## ---- the voice ------------------------------------------------------------------------

## VOICE ON: the model loads, the tower's radio check is queued on its channel, and nothing
## fails to synthesise. VOICE OFF: the channel is cleared and the server that held the model goes.
func _the_tower_answers_a_radio_check() -> void:
	var why: String = Headphones.why_there_is_no_voice()
	if not why.is_empty():
		_skip("the_tower_answers_a_radio_check", why)
		return
	Headphones.choose_voice(true)
	_check("voice_on_starts_loading", Headphones.voice == PilotHeadphones.Voice.LOADING
		and ClassDB.class_exists(&"KokoroServer"), "voice %s, said '%s'" % [Headphones.voice, Headphones.said])
	var loaded: bool = await _wall_until(func() -> bool: return Headphones.voice != PilotHeadphones.Voice.LOADING,
		LOAD_SECONDS)
	_check("and_the_model_loads", loaded and Headphones.voice == PilotHeadphones.Voice.ON,
		"voice %s, said '%s'" % [Headphones.voice, Headphones.said])
	if Headphones.voice != PilotHeadphones.Voice.ON:
		Headphones.choose_voice(false)
		return
	var server: Node = Headphones.server()
	var failed: Array = []
	server.connect("synthesis_failed", func(id: int, reason: String): failed.append([id, reason]))
	_check("and_the_tower_answers_on_its_channel", Headphones.last_line() > 0 and Headphones.radio() != null,
		"utterance %d on %s" % [Headphones.last_line(), Headphones.radio()])
	# EVERY WORD IS IN THE LEXICON. A word that is not falls to letter-to-sound rules and the
	# extension raises a warning; the phonemes are checked here instead of listened for.
	var ipa: String = String(server.call("phonemize", PilotHeadphones.RADIO_CHECK))
	_check("and_every_word_of_it_can_be_said", not ipa.is_empty() and bool(server.call("has_voice",
		PilotHeadphones.TOWER_VOICE)), "'%s' in %s" % [ipa, PilotHeadphones.TOWER_VOICE])
	# ON AIR: synthesised and published into the channel's ring, which is what `is_transmitting` reads. Waited for in
	# wall time, and VOICE goes off the MOMENT it is true, while the line still has seconds to run -- so a radio that
	# was not cleared is still transmitting when it is asked. Waited out to the end instead, the line had drained by the
	# time VOICE went off, and the check passed with `clear()` deleted (2026-09-13).
	var channel: AudioStream = Headphones.radio()
	var on_air: bool = await _wall_until(func() -> bool: return bool(channel.call("is_transmitting")), SPEAK_SECONDS)
	_check("and_it_synthesises_onto_the_radio_without_failing", on_air and failed.is_empty(),
		"on air %s, failures %s" % [on_air, failed])

	var player: Node = Headphones.get_node_or_null(^"Tower")
	# Asked BEFORE VOICE goes off: a freed object compares equal to null in Godot 4, so `player != null` asked after
	# the player has been freed is false, and the check read as failing on the very thing it was checking for.
	var had_a_player: bool = player != null
	Headphones.choose_voice(false)
	await _frames(2)
	# PUT AWAY, NOT MERELY CLEARED. `is_transmitting` cannot say this: it reads a squelch flag the AUDIO thread closes at
	# the end of a tail, and a player that has been stopped is never mixed again, so the flag stays open for good --
	# measured 2026-09-13, true two frames after `clear()` with the player put away, and true without `clear()` too.
	# What VOICE off promises is that the tower's player and channel are gone, which is also what stopped an object
	# leaking at exit (see PilotHeadphones, "THE PLAYER GOES WITH THE SERVER").
	_check("voice_off_puts_the_tower_radio_away", had_a_player and Headphones.radio() == null
		and not is_instance_valid(player), "radio %s, player was %s" % [Headphones.radio(), player])
	_check("and_lets_go_of_the_model", not Headphones.voice_on() and Headphones.server() == null
		and not is_instance_valid(server), "voice %s, server %s" % [Headphones.voice, Headphones.server()])
	var after: int = Headphones.say("Anybody there?", PilotHeadphones.TOWER_VOICE,
		PilotHeadphones.priority(&"PRIORITY_NORMAL"), RadioTuning.CHECK_SPEED)
	_check("and_says_nothing_more", after == 0, "queued %d" % after)

	# AND ON AGAIN IS A NEW SERVER ON A NEW CHANNEL, because a freed server cannot be started again.
	Headphones.choose_voice(true)
	var again: bool = await _wall_until(func() -> bool: return Headphones.voice != PilotHeadphones.Voice.LOADING,
		LOAD_SECONDS)
	_check("and_on_again_the_tower_speaks_on_a_new_channel", again and Headphones.voice == PilotHeadphones.Voice.ON
		and Headphones.radio() != null and Headphones.radio() != channel and Headphones.last_line() > 0
		and Headphones.server() != null and Headphones.server() != server,
		"voice %s, radio %s (was %s), utterance %d" % [Headphones.voice, Headphones.radio(), channel,
			Headphones.last_line()])
	Headphones.choose_voice(false)
	await _frames(2)
	_sections += 1


## VOICE OFF BEFORE THE MODEL HAS LOADED: off at once, and the server is freed when the load
## finishes rather than on the spot, which would hold the main thread for the whole load.
func _off_while_loading_lets_go_of_the_model() -> void:
	if not Headphones.why_there_is_no_voice().is_empty():
		_skip("off_while_loading_lets_go_of_the_model", Headphones.why_there_is_no_voice())
		return
	Headphones.choose_voice(true)
	var loading: Node = Headphones.server()
	Headphones.choose_voice(false)
	_check("off_while_loading_is_off_at_once", not Headphones.voice_on() and loading != null,
		"voice %s" % Headphones.voice)
	var gone: bool = await _wall_until(func() -> bool: return Headphones.server() == null, LOAD_SECONDS)
	await _frames(2)
	_check("and_the_server_goes_when_it_has_loaded", gone and not is_instance_valid(loading),
		"server %s" % Headphones.server())
	_check("and_it_stays_off_with_nothing_to_say", Headphones.voice == PilotHeadphones.Voice.OFF
		and Headphones.said.is_empty(), "voice %s, said '%s'" % [Headphones.voice, Headphones.said])
	_sections += 1


## ---- helpers ---------------------------------------------------------------------------

func _frames(how_many: int) -> void:
	for i in range(how_many):
		await get_tree().process_frame


## Frames until `done` answers true or `seconds` of WALL time pass. True if it answered.
func _wall_until(done: Callable, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if done.call():
			return true
		await get_tree().process_frame
	return bool(done.call())


func _finish() -> void:
	print("[headphones] %d sections, %d skipped%s" % [_sections, _skipped.size(),
		"" if _skipped.is_empty() else ": " + ", ".join(_skipped)])
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
