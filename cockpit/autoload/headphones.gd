extends Node
class_name PilotHeadphones
## WHAT THE PILOT HEARS: the game's own sound, and a voice on the radio. Two switches on the
## clipboard's AUDIO tab, and both start OFF.
##
## "An audio panel in the iPad (default to all off), one for game sound another for using
## kokoro to play audio" (2026-09-13). Before this the only switch was `--audio`, and it
## decided whether sound players were BUILT -- so a flight started silent stayed silent, and
## every player sat on Master where nothing could tell the engine from a radio.
##
## ---------------------------------------------------------------------------------
## TWO BUSES, AND GAME SOUND IS ONE OF THEM
## ---------------------------------------------------------------------------------
##
## `Game` carries every player the game builds -- `VehicleSound`'s engine note and its
## reports. `Radio` carries the voice, through `RadioBus`'s band-pass and drive. GAME SOUND
## mutes `Game` and touches nothing else, so a player can have the tower with no engine, or
## the engine with no tower. Players are built wherever there is an audio device and the MUTE
## is the switch: building them only when the switch was on would leave a craft somebody sat
## in with the sound off silent after the switch went on, until they sat down again.
##
## `--audio` is the same word it always was and now says where GAME SOUND starts.
##
## ---------------------------------------------------------------------------------
## THE VOICE IS A LIBRARY LOADED ON DEMAND
## ---------------------------------------------------------------------------------
##
## kokoro-gd is Kokoro-82M text-to-speech in C++ over ONNX Runtime (`../kokoro-gd/`). Three
## things decide how it is reached, and each rules out the obvious way:
##
## NOT AN EXTENSION GODOT FINDS BY ITSELF. A `.gdextension` the importer discovers is loaded
## at every boot, and on a machine with no library for its platform and precision Godot prints
## "No GDExtension library found for current OS and architecture" as an ERROR -- which the
## suite runner fails a suite for. Its libraries are built on Windows only so far. So the file
## sits under a `.gdignore`, this node reads it, works out the library Godot would pick for
## this machine, and hands it to `GDExtensionManager` only when that file is there.
##
## NOT AN AUTOLOAD SCENE, which is what kokoro-gd's README says to add. A scene whose root is a
## `KokoroServer` fails to load when the class is absent, and it would start the worker thread
## at boot. So nothing here names a kokoro class as a type: `tests/lint.gd` compiles this file
## on machines where the class does not exist. They are reached through `ClassDB`.
##
## NOT COMMITTED. The two kokoro libraries and ONNX Runtime (17 MB between them) are ignored in
## `addons/kokoro_gd/bin`, and `../kokoro-gd/scripts/build.ps1` copies them there. A fresh clone
## cannot speak without the 325 MB model either, which is fetched by a script, so committed
## libraries would buy nothing and put third-party binaries in the history again at every ONNX
## Runtime release (decided 2026-09-13). So a clone has NO library, which is exactly the state
## the refusals below are for, and the sentence under the switch names the command that fixes it.
##
## THE SMALL NATIVE LIBRARY IS PREPARED DURING BOOT WHEN THE COMPLETE OPTIONAL INSTALL IS PRESENT. Loading a
## GDExtension is synchronous and a cold Windows load cost 15--29 ms, so doing it on the first switch pull drops a
## headset frame. The model remains lazy: VOICE on builds a `KokoroServer` and
## loads it; VOICE off clears the radio, puts the tower's player away and frees the server,
## which releases the model. A freed server cannot be started again (its shutdown flag is never
## reset), so each VOICE on builds a new one -- and one still loading is not freed until it
## finishes, because freeing it joins the worker thread and the main thread would wait out the load.
##
## THE PLAYER GOES WITH THE SERVER. VOICE off used to free the server and leave the tower's
## `AudioStreamPlayer` playing its `RadioChannel` on the Radio bus, and every run that did so
## printed "1 ObjectDB instance was leaked at exit" with an orphan StringName `Radio`, the bus's
## name. A throwaway probe on 2026-09-13 put it there and nowhere else: VOICE on and off leaked,
## with or without a lambda on the server's signals; a bare server freed on its own did not, and
## neither did a bare channel. A player left mixing silence for a voice that is off was waste anyway.
##
## NOT REPLICATED, and never remembered between runs: what a player has in their ears is
## theirs, and every run starts with both switches off.
##
## ---------------------------------------------------------------------------------
## ONE FREQUENCY, AND IT IS BUSY UNTIL A LINE HAS RUN OUT
## ---------------------------------------------------------------------------------
##
## The tower's radio check and the aircraft chattering on it (`TowerFrequency`) share the one channel, so the
## frequency cannot talk over itself: kokoro speaks a channel's lines one after another. What the chatter
## must not do is QUEUE behind a line, piling up lines that come out late or holding the radio check back, so
## it asks `on_air` first and says nothing while any line is still out. Lines are queued at a priority
## (`priority`): the radio check at NORMAL, chatter at LOW, which the worker takes in that order.
##
## A LINE IS OUT until kokoro says the audio thread played its last sample (`utterance_finished`) or that it could
## not be spoken (`synthesis_failed`). That is the whole rule, headless too: Godot's Dummy driver, which `--headless`
## uses, runs the mix at real time on 4.7.2, and every line of the first chatter runs finished that way (2026-09-14).
##
## A RULE FOR A STALL THAT DID NOT HAPPEN WAS TAKEN OUT. The design read kokoro-gd's DESIGN.md -- "Godot's Dummy
## driver never pumps the audio thread" -- and so expected a headless ring that never drained and a worker stopped
## for good by the second line, and a line was also called over once its frames had had time to play, with the ring
## cleared. It never fired in thirteen lines, because the premise was false here. What is left is
## `RadioTuning.GIVE_UP`: a line out that long is let go of, so a player that was stopped or a channel that stopped
## being mixed cannot keep the frequency busy for good. Nothing tests it; see agents.md, "THE FREQUENCY TALKS".

## Either switch moved, or the voice finished loading or failed to. `said` is the line under
## the VOICE switch: what it is doing, or why it cannot.
signal changed(game_sound: bool, voice_on: bool, said: String)
## Host-side Kokoro output captured as raw mono PCM. RadioService encodes and
## distributes it; the synthesizer never becomes a second playback path.
signal rendered(samples: PackedFloat32Array, sample_rate: int, text: String)
signal render_failed(reason: String)

## THE FLAG THAT STARTS GAME SOUND ON. Off unless somebody asks, because nearly every run here
## is a suite or an agent looking at a window. The same word does the same job in racer and
## topdowntest. `VehicleSound.AUDIO_FLAG` is this.
const AUDIO_FLAG: String = "--audio"

const GAME_BUS: StringName = &"Game"
const RADIO_BUS: StringName = &"Radio"
const MUSIC_BUS: StringName = &"Music"
const CAPTURE_BUS: StringName = &"RadioCapture"

## The extension's configuration, under a `.gdignore` so the importer never loads it. See above.
const EXTENSION: String = "res://addons/kokoro_gd/bin/kokoro_gd.gdextension"

## WHERE THE MODEL IS. `KOKORO_MODELS`, when set, is the ONLY place looked: somebody who says
## where the model is means there, and a test can say "nowhere". Otherwise the folder
## kokoro-gd's own `scripts/fetch_models.sh` writes into, beside this game in the workshop, and
## then `user://kokoro` for a build with no workshop around it. Outside `res://` either way,
## because 325 MB does not belong in an export.
const MODELS_VARIABLE: String = "KOKORO_MODELS"
const USER_MODELS: String = "user://kokoro"
const EXE_MODELS: String = "kokoro/models"
## A folder counts only with all three in it. Checked here before the extension is asked, so a
## missing file is a sentence on the board rather than an error from inside the library.
const MODEL_FILES: Array[String] = ["kokoro_fp32.onnx", "voices.bin", "lexicon.txt"]

## THE TOWER'S VOICE, which is `RadioTuning`'s: one voice, and a second frequency is a second channel.
const TOWER_VOICE: String = RadioTuning.TOWER_VOICE
## WHAT IT SAYS WHEN VOICE COMES ON, which is how a player knows the switch worked. Every word
## is in the lexicon, so it raises no pronunciation warning (tests/headphones.gd checks).
const RADIO_CHECK: String = "Cockpit, tower, reading you five by five."


enum Voice { OFF, LOADING, ON }

var game_sound: bool = false
var voice: int = Voice.OFF
var said: String = ""

## The extension this node loads. A test points it at a file that is not there, to show the
## refusal; nothing else changes it.
var extension_path: String = EXTENSION
## ONNX Runtime's threads for the next server this builds. `RadioTuning.WORKER_THREADS`; tests/radio_shot.gd
## changes it to measure what each setting costs a frame.
var worker_threads: int = RadioTuning.WORKER_THREADS

var _server: Node = null
## When the model was asked for, on the wall clock -- it loads on the extension's own thread, in real time.
var _loading_since: int = 0
var _channel: AudioStream = null
var _player: AudioStreamPlayer = null
## The utterance id of the last line put on the radio, or 0. For the tests.
var _line: int = 0

## EVERY LINE STILL OUT, utterance id -> when it was queued on the wall clock. See "ONE FREQUENCY".
var _out: Dictionary = {}
var _capture: AudioEffectCapture = null
var _render_channel: AudioStream = null
var _render_player: AudioStreamPlayer = null
var _render_line: int = 0
var _render_text: String = ""
var _render_samples := PackedFloat32Array()
var _clip_players: Array[AudioStreamPlayer] = []
var played_clips: int = 0
var last_clip_samples: int = 0


func _ready() -> void:
	_make_the_buses()
	_prepare_voice_library()
	game_sound = asked_for(OS.get_cmdline_user_args()) or asked_for(OS.get_cmdline_args())
	_mute_the_game()
	print("[headphones] game sound %s%s, voice off" % ["on" if game_sound else "off",
		" (asked for on the command line)" if game_sound else ""])


## Was sound asked for on this command line? Pure, so the rule is one check in a suite.
static func asked_for(args: PackedStringArray) -> bool:
	return args.has(AUDIO_FLAG)


## ---- game sound ----------------------------------------------------------------------

func choose_game_sound(on: bool) -> void:
	if on == game_sound:
		return
	game_sound = on
	_mute_the_game()
	print("[headphones] game sound %s" % ("on" if on else "off"))
	_tell()


func _make_the_buses() -> void:
	if AudioServer.get_bus_index(GAME_BUS) == -1:
		var index: int = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, GAME_BUS)
		AudioServer.set_bus_send(index, &"Master")
	if AudioServer.get_bus_index(MUSIC_BUS) == -1:
		var music_index: int = AudioServer.bus_count
		AudioServer.add_bus(music_index)
		AudioServer.set_bus_name(music_index, MUSIC_BUS)
		AudioServer.set_bus_send(music_index, &"Master")
	RadioBus.create(RADIO_BUS)


func _mute_the_game() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(GAME_BUS), not game_sound)


## ---- the voice -----------------------------------------------------------------------

func choose_voice(on: bool) -> void:
	if on:
		_turn_the_voice_on()
	else:
		_turn_the_voice_off()


func voice_on() -> bool:
	return voice != Voice.OFF


## LOAD ONLY THE NATIVE CODE DURING THE INITIAL BOOT, before a player can be flying. Godot documents
## `GDExtensionManager.load_extension` as a synchronous load by absolute resource path. The 325 MB model and its
## worker remain absent until VOICE is selected. An incomplete optional install is ignored here so a fresh clone
## retains its quiet, actionable refusal when the switch is eventually pulled.
func _prepare_voice_library() -> void:
	if not why_there_is_no_voice().is_empty() or GDExtensionManager.is_extension_loaded(extension_path):
		return
	var status := GDExtensionManager.load_extension(extension_path)
	if status != GDExtensionManager.LOAD_STATUS_OK and status != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		print("[headphones] voice library could not be prepared (status %d)" % status)


func _turn_the_voice_on() -> void:
	if voice != Voice.OFF:
		return
	# A joiner only needs the decoder, which is built into Godot. Kokoro and its
	# 356 MB data are host-only; this is the production proof that a client with
	# neither model nor extension can hear a generated transmission.
	if Net.is_networked() and not Net.is_host:
		voice = Voice.ON
		said = "Radio on. The host generates voice."
		_tell()
		return
	# TURNED BACK ON BEFORE THE LAST ONE FINISHED LOADING: that server is still the one.
	if _server != null:
		voice = Voice.ON if bool(_server.call("is_ready")) else Voice.LOADING
		said = "On." if voice == Voice.ON else "Loading the voice model..."
		_tell()
		return
	var why: String = why_there_is_no_voice()
	if not why.is_empty():
		said = why
		print("[headphones] no voice: %s" % why)
		_tell()
		return
	var status: int = GDExtensionManager.load_extension(extension_path) \
		if not GDExtensionManager.is_extension_loaded(extension_path) else GDExtensionManager.LOAD_STATUS_OK
	if not ClassDB.class_exists(&"KokoroServer"):
		said = "Voice library did not load (status %d)." % status
		print("[headphones] no voice: %s" % said)
		_tell()
		return
	var folder: String = models_folder()
	_server = ClassDB.instantiate(&"KokoroServer") as Node
	_server.name = "Kokoro"
	# READ WHEN THE MODEL LOADS, so it is set before `load_models` or not at all.
	_server.set("worker_threads", worker_threads)
	add_child(_server)
	_server.connect("model_state_changed", _on_model_state)
	_server.connect("utterance_finished", _on_line_finished)
	_server.connect("synthesis_failed", _on_line_failed)
	_loading_since = Time.get_ticks_msec()
	_server.call("load_models", folder)
	voice = Voice.LOADING
	said = "Loading the voice model..."
	print("[headphones] voice loading from %s on %d thread(s)" % [folder, worker_threads])
	_tell()


func _turn_the_voice_off() -> void:
	if voice == Voice.OFF:
		return
	_put_the_radio_away()
	_put_the_render_away()
	var loading: bool = voice == Voice.LOADING
	voice = Voice.OFF
	said = ""
	# One still loading is freed when it finishes: see "NOT UNTIL VOICE IS TURNED ON".
	if not loading:
		_free_the_server()
	print("[headphones] voice off")
	_tell()


func _on_model_state(state: int, error: String) -> void:
	if state == ClassDB.class_get_integer_constant(&"KokoroServer", &"STATE_READY"):
		if voice == Voice.OFF:
			_free_the_server()
			return
		voice = Voice.ON
		said = "On."
		print("[headphones] voice on, the model loaded in %.1f s" % ((Time.get_ticks_msec() - _loading_since) / 1000.0))
		say(RADIO_CHECK, TOWER_VOICE, priority(&"PRIORITY_NORMAL"), RadioTuning.CHECK_SPEED)
		_tell()
	elif state == ClassDB.class_get_integer_constant(&"KokoroServer", &"STATE_FAILED"):
		_free_the_server()
		var wanted: bool = voice != Voice.OFF
		voice = Voice.OFF
		said = "Voice model did not load: %s" % error if wanted else ""
		print("[headphones] voice model did not load: %s" % error)
		_tell()


## PUT A LINE ON THE RADIO, in `voice_name`, at `priority` (`priority(&"PRIORITY_NORMAL")` and the rest) and
## `speed`, and answer its utterance id. Nothing, and 0, when the voice is not on: a `RadioChannel` with no server
## pushes an error, and a line nobody can hear is not worth queueing. It does not ask `on_air` -- a line somebody
## asked for is said -- so anything that talks unprompted asks first.
func say(text: String, voice_name: String, priority_value: int, speed: float) -> int:
	if voice != Voice.ON or _server == null:
		return 0
	if _channel == null:
		_channel = ClassDB.instantiate(&"RadioChannel") as AudioStream
		_channel.set("channel_name", "Tower")
		_player = AudioStreamPlayer.new()
		_player.name = "Tower"
		_player.bus = RADIO_BUS
		_player.stream = _channel
		add_child(_player)
		_player.play()
	_channel.call("set_server", _server)
	_line = int(_channel.call("queue", text, voice_name, speed, priority_value))
	if _line > 0:
		_out[_line] = Time.get_ticks_msec()
	return _line


## A `RadioChannel` priority by its constant's name, asked of the class so the number is kokoro's. NORMAL's 2
## when the class is not there, which is also when nothing can be said.
static func priority(name: StringName) -> int:
	if not ClassDB.class_exists(&"RadioChannel"):
		return 2
	return ClassDB.class_get_integer_constant(&"RadioChannel", name)


## IS A LINE STILL OUT on the frequency: queued, being read, or playing. See "ONE FREQUENCY".
func on_air() -> bool:
	return not _out.is_empty()


func _on_line_finished(_channel_name: String, utterance: int) -> void:
	if utterance == _render_line:
		_finish_render()
	_out.erase(utterance)


func _on_line_failed(utterance: int, reason: String) -> void:
	if utterance == _render_line:
		_render_line = 0; _render_text = ""; _render_samples.clear()
		render_failed.emit(reason)
	_out.erase(utterance)
	print("[headphones] a line was not spoken: %s" % reason)


## A LINE OUT FOR `RadioTuning.GIVE_UP` IS LET GO OF, and says so. See "ONE FREQUENCY".
func _process(_delta: float) -> void:
	_drain_capture()
	_clip_players = _clip_players.filter(func(player: AudioStreamPlayer) -> bool:
		if is_instance_valid(player) and player.playing: return true
		if is_instance_valid(player): player.queue_free()
		return false)
	if _out.is_empty():
		return
	var stale: int = Time.get_ticks_msec() - int(RadioTuning.GIVE_UP * 1000.0)
	for utterance in _out.keys():
		if int(_out[utterance]) < stale:
			_out.erase(utterance)
			print("[headphones] line %d was never heard to finish; the frequency is free again" % utterance)


func _free_the_server() -> void:
	if _server != null:
		_server.queue_free()
		_server = null


## THE TOWER'S RADIO, CLEARED AND PUT AWAY: whatever is queued or staged is dropped, then the player is stopped and
## freed and the channel let go of. The next VOICE on builds both again in `say`. See "THE PLAYER GOES WITH THE SERVER".
func _put_the_radio_away() -> void:
	if _channel != null:
		_channel.call("clear")
	if _player != null:
		_player.stop()
		_player.queue_free()
		_player = null
	_channel = null
	_out.clear()


## THE HOST'S CAPTURE CHANNEL GOES WITH THE SERVER TOO. The network-radio path introduced a second channel after the
## original voice lifetime gate was written. Leaving it pointed at a server which VOICE off had freed made the next
## VOICE on queue into the old stopped worker, and turning voice off during synthesis kept that capture player alive.
func _put_the_render_away() -> void:
	if _render_channel != null:
		_render_channel.call("clear")
	if _render_player != null:
		_render_player.stop()
		_render_player.queue_free()
	_render_player = null
	_render_channel = null
	_render_line = 0
	_render_text = ""
	_render_samples.clear()
	if _capture != null:
		_capture.clear_buffer()


func _tell() -> void:
	changed.emit(game_sound, voice_on(), said)


## ---- is there a voice to be had ------------------------------------------------------

## WHY VOICE CANNOT COME ON, in a sentence for the board that names what is missing and the command that
## fixes it, or "" when it can. Every sentence starts "No voice", which is what the tests look for.
func why_there_is_no_voice() -> String:
	var build: String = BUILD_WINDOWS if OS.has_feature("windows") else BUILD_ELSEWHERE
	var library: String = library_for_this_machine()
	if library.is_empty():
		return "No voice library for this machine: %s" % build
	if not FileAccess.file_exists(library):
		return "No voice library (%s): %s" % [library.get_file(), build]
	for needed in libraries_it_needs():
		if not FileAccess.file_exists(needed):
			return "No voice library (%s): %s" % [needed.get_file(), build]
	if models_folder().is_empty():
		return "No voice model at %s: %s" % [places_for_the_model()[0], FETCH_MODEL]
	return ""


## The commands the sentences name, as a player at this workshop types them.
const BUILD_WINDOWS: String = "run kokoro-gd/scripts/build.ps1"
const BUILD_ELSEWHERE: String = "build kokoro-gd on this machine (scripts/build.sh)"
const FETCH_MODEL: String = "run kokoro-gd/scripts/fetch_models.sh"


## THE LIBRARY GODOT WOULD LOAD HERE, read out of the `.gdextension` the way Godot reads it:
## every tag of an entry must be a feature of this build, and the entry naming the most tags
## wins. Asked of the file rather than typed here, so the two cannot disagree about a name.
func library_for_this_machine() -> String:
	var entry: Variant = _best_entry("libraries")
	return String(entry) if entry is String else ""


## The shared libraries the extension needs beside it: ONNX Runtime.
func libraries_it_needs() -> PackedStringArray:
	var needs: PackedStringArray = []
	var entry: Variant = _best_entry("dependencies")
	if entry is Dictionary:
		for path in (entry as Dictionary):
			needs.append(String(path))
	return needs


func _best_entry(section: String) -> Variant:
	var config := ConfigFile.new()
	if config.load(extension_path) != OK or not config.has_section(section):
		return null
	var best: Variant = null
	var best_tags: int = -1
	for key in config.get_section_keys(section):
		var tags: PackedStringArray = key.split(".")
		var fits: bool = true
		for tag in tags:
			if not OS.has_feature(tag):
				fits = false
				break
		if fits and tags.size() > best_tags:
			best_tags = tags.size()
			best = config.get_value(section, key)
	return best


## The first place the model is, as an absolute path, or "".
func models_folder() -> String:
	for place in places_for_the_model():
		var whole: bool = true
		for file in MODEL_FILES:
			if not FileAccess.file_exists(place.path_join(file)):
				whole = false
				break
		if whole:
			return place
	return ""


func places_for_the_model() -> PackedStringArray:
	var asked: String = OS.get_environment(MODELS_VARIABLE)
	if not asked.is_empty():
		return PackedStringArray([asked])
	var places := PackedStringArray([OS.get_executable_path().get_base_dir().path_join(EXE_MODELS),
		ProjectSettings.globalize_path(USER_MODELS)])
	# The sibling checkout is a workshop convenience, never an export contract.
	var resource_root := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	var executable_root := OS.get_executable_path().get_base_dir().simplify_path().trim_suffix("/")
	if resource_root != executable_root:
		places.insert(1, ProjectSettings.globalize_path("res://").path_join("../kokoro-gd/models").simplify_path())
	return places


## Render one host-requested line onto a bus whose capture effect receives the
## samples before its -80 dB output gain. AudioEffectCapture is explicitly the
## Godot API intended for transmitting bus PCM over a network.
func render(text: String, voice_name: String = TOWER_VOICE, speed: float = RadioTuning.CHATTER_SPEED) -> String:
	if voice != Voice.ON or _server == null or not bool(_server.call("is_ready")):
		return "The host voice model is not ready."
	if _render_line != 0:
		return "The radio is already rendering a line."
	_make_capture_bus()
	_capture.clear_buffer(); _render_samples.clear(); _render_text = text
	if _render_channel == null:
		_render_channel = ClassDB.instantiate(&"RadioChannel") as AudioStream
		_render_channel.set("channel_name", "NetworkTower")
		_render_channel.set("fx_enabled", false)
		_render_channel.call("set_server", _server)
		_render_player = AudioStreamPlayer.new()
		_render_player.name = "RadioCapture"
		_render_player.bus = CAPTURE_BUS; _render_player.stream = _render_channel
		add_child(_render_player); _render_player.play()
	_render_line = int(_render_channel.call("queue", text, voice_name, speed, priority(&"PRIORITY_NORMAL")))
	if _render_line <= 0:
		_render_line = 0; _render_text = ""
		return "The voice library refused that line."
	return ""


func _make_capture_bus() -> void:
	var index := AudioServer.get_bus_index(CAPTURE_BUS)
	if index < 0:
		index = AudioServer.bus_count; AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, CAPTURE_BUS); AudioServer.set_bus_send(index, &"Master")
		AudioServer.set_bus_volume_db(index, -80.0)
	_capture = AudioEffectCapture.new(); _capture.buffer_length = RadioClip.MOST_SECONDS
	AudioServer.add_bus_effect(index, _capture)


func _drain_capture() -> void:
	if _capture == null or _render_line == 0: return
	var available := _capture.get_frames_available()
	if available <= 0: return
	for stereo in _capture.get_buffer(available):
		_render_samples.append((stereo.x + stereo.y) * 0.5)


func _finish_render() -> void:
	_drain_capture()
	var samples := _render_samples.duplicate(); var text := _render_text
	_render_line = 0; _render_text = ""; _render_samples.clear()
	if samples.is_empty(): render_failed.emit("The voice rendered no audio samples.")
	else: rendered.emit(samples, int(AudioServer.get_mix_rate()), text)


## Every peer, including the host, plays this decoded stream on the Radio bus.
func play_clip(bytes: PackedByteArray) -> bool:
	if voice == Voice.OFF: return false
	var stream := RadioClip.stream(bytes)
	if stream == null: return false
	var player := AudioStreamPlayer.new(); player.bus = RADIO_BUS; player.stream = stream
	player.name = "NetworkRadioClip"; add_child(player); player.play()
	_clip_players.append(player); played_clips += 1
	last_clip_samples = int(RadioClip.decode(bytes).samples.size())
	return true


## The utterance id of the last line put on the radio, or 0.
func last_line() -> int:
	return _line


## The channel the tower speaks on, or null before the voice has first come on.
func radio() -> AudioStream:
	return _channel


## The server loading or holding the model, or null.
func server() -> Node:
	return _server
