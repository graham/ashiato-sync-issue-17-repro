extends Node
class_name BootRouter
## WHERE THE GAME STARTS, and the one place that decides which scene that is.
##
## The main scene is this rather than any of the levels, because "which level" is a question
## with four answers and a command line is how the other three get asked:
##
##   (nothing)                the desk, where you choose a session
##   --level=world            straight into the world, as it always did
##   --level=seat  --kind=X   one cockpit on a bench, physics on
##   --level=crew  --kind=X   every seat in one craft, no physics
##   --level=fly   --kind=X   one craft flying ITSELF in an empty sky, watched from
##                            outside, with its trim written down
##   --level=hall             every cockpit in the game in a row, and nothing else at all
##   --level=watch            the whole world with NOBODY in it, from a camera that flies
##   --level=tower            the same, with buttons: tell the aircraft under the camera what to do
##   --level=deck             marshal a jet onto a catapult, by hand signal, from the deck
##   --level=stand            and an airliner onto a gate, the same way
##   --level=signals          every marshalling signal there is, to learn them in
##   --level=voice            a flat 2D lobby -- players, teams, chat and voice -- with no world and no headset
##   --level=server           the world, served and NOT played: no rig, no seat, no camera, a 2D console
##   --level=control          a controller's station: a RADAR plot, the roster and teams, no craft, no headset
##
## And a SESSION, before any door, read by `LaunchOrder`; each goes to the world once `Net` says the session is up:
##
##   --host[=PORT]            host over ENet
##   --join=ADDRESS[:PORT]    join over ENet
##   --steam-host             host over Steam, and print STEAM_CODE=
##   --steam-join=CODE        join a Steam game by the code its host reads out
##   +connect_lobby ID        what Steam passes when an accepted invite starts the game
##
## A spelling in that namespace that is not one of these prints BOOT_ERROR= and quits.
##
## And WHICH LEVEL the world stands on, with a host, solo or a door: `--world=island`. A level `ChartDrawer` does not
## have, or `--world=` beside a join, prints BOOT_ERROR= and quits too.
##
## The bench also takes `--seat=N`. Everything after `--` is Godot's, so a full line reads
##
##   Godot --path cockpit -- --level=seat --kind=osprey --seat=1
##
## A router rather than four main scenes because the alternative is remembering which .tscn
## is which, and because a level should not have to know it might have been launched
## directly. Every one of these scenes still runs on its own if you open it in the editor.

# THE DESK'S PATH LIVES ON `Doors`, which is also where the way BACK to it lives, and
# which depends on nothing. See the note there: the way back cannot live on this file,
# because everything that would call it is already underneath this file.
const DESK := Doors.DESK
const WORLD := "res://world/sky.tscn"
const BENCH := "res://tests/bench.tscn"
const HALL := "res://world/hall.tscn"
## THE FLAT ROOM WITH THE PLAYERS IN IT, and no world at all: `--level=voice`. See `world/flat_lobby.gd`.
const FLAT_LOBBY := "res://world/flat_lobby.tscn"
## How long `--hold-until` waits for its file before refusing to boot: a harness that never lets go is a harness that
## died, and a process waiting on it for ever would outlive it holding nothing but a core.
const HOLD_PATIENCE_MSEC: int = 60000
# The marshalling levels are a different game on the same ground: nobody is flying
# anything and what a player does is move their hands. They keep their own door list -- see
# MarshallingLevel.DOORS -- so this file names none of them.


## DEFERRED, every one of them. `_ready` runs while the tree is still adding this scene,
## and a scene change from in there tries to take it out again mid-add:
##
##   Parent node is busy adding/removing children, `remove_child()` can't be called
##
## The router has nothing to do before the frame ends anyway, so it asks for the swap and
## lets the tree finish what it was doing first.
## EVERY DOOR THIS ROUTER ANSWERS TO, AS A TABLE.
##
## It was a `match` with the aliases written out in its arms, which is a list nothing can
## read: `tests/docs.gd` has to be able to ask whether a `--level=` word in `agents.md` is a
## word this router accepts, and the only alternative to a table is that test keeping its own
## copy -- which is the shape that lets the two disagree. `MarshallingLevel.DOORS` has been a
## table for exactly this reason since the day it was written, and this now matches it.
##
## THE ALIASES ARE THE POINT, not padding. A person typing a command line should not have to
## remember whether the observer is `watch` or `nobody`, and the cost of accepting both is a
## row. `watch`, `observe` and `nobody` reach the same scene as `world`; `sky.gd` reads the
## flag again for itself and builds an observer instead of a rig -- see `_nobody_is_playing`.
const DOORS: Dictionary = {
	"menu": DESK,
	"desk": DESK,
	"world": WORLD,
	"sky": WORLD,
	"watch": WORLD,
	"observe": WORLD,
	"nobody": WORLD,
	# THE TOWER: `watch` with a row of buttons. Same scene, same camera, no rig -- what it adds is that the aircraft
	# under the camera can be TOLD things (climb, land at the nearest field), through the same `steer_ai` the island's
	# own airliners are flown by. Asked for by the user on 2026-09-19 so that vehicles can be tested on a monitor
	# rather than in a headset. See `tower_panel.gd`.
	"tower": WORLD,
	"hall": HALL,
	"cockpits": HALL,
	"seats": HALL,
	# The bench reads --kind and --seat off the same command line for itself, so there is
	# nothing to hand over: it is told which scene and finds the rest.
	"seat": BENCH,
	"crew": BENCH,
	"bench": BENCH,
	"fly": BENCH,
	"trim": BENCH,
	# THE 2D VOICE LOBBY, which is not a level and has no world: a flat room for checking that names, chat and voice
	# work between two machines. `voice` is what it is for; `lobby2d` and `flat` are what it is.
	"voice": FLAT_LOBBY,
	"lobby2d": FLAT_LOBBY,
	"flat": FLAT_LOBBY,
	# THE WORLD, SERVED AND NOT PLAYED. The same level every player flies -- so what it simulates is what they get --
	# with nobody in it and nothing looking at it: `Sky._nobody_is_playing` builds no rig, no seat and no XR, and
	# `Sky._the_server` builds a 2D console INSTEAD of the observer's camera. `server` is what it is for; `dedicated`
	# is what such a thing is usually called. See `world/server_console.gd` for what that is worth, measured.
	"server": WORLD,
	"dedicated": WORLD,
	# THE CONTROLLER'S STATION, the other job that is not flying: a radar plot of what the HOST says this machine can
	# see, the people in the session and their teams. No rig, no seat, no camera, and no craft -- `Sky._the_controller`
	# builds it on a layer of its own. `control` is what it is for; `awacs` and `tower2d` are what people call it.
	"control": WORLD,
	"awacs": WORLD,
	"tower2d": WORLD,
	# ONE COCKPIT WITH THE BUILDER ALREADY ON, to lay a cockpit out and SAVE it as JSON. The bench
	# reads `--level=build` for itself, like the rest of these.
	"build": BENCH,
}


func _ready() -> void:
	var asked: Dictionary = _arguments()
	if asked.has("player-name"):
		var colour: int = int(asked.get("player-colour", "0"))
		var profile_why: String = Net.set_profile(String(asked["player-name"]), colour, false)
		if profile_why != "":
			_refuse_to_boot(profile_why)
			return
	# A HOST MAY TAKE FEWER PLAYERS THAN `Net.MAX_PLAYERS`: `--players=N`. A number that is not one is refused, as a
	# bad name is, rather than hosting a session of some other size.
	if asked.has("players"):
		var players: String = String(asked["players"])
		var size_why: String = Net.choose_session_size(players.to_int()) if players.is_valid_int() \
			else "--players= wants a number of players, and '%s' is not one" % players
		if size_why != "":
			_refuse_to_boot(size_why)
			return
	var inspect_music := OS.get_cmdline_user_args().has("--music-list") or OS.get_cmdline_args().has("--music-list")
	var inspect_voice := OS.get_cmdline_user_args().has("--voice-test") or OS.get_cmdline_args().has("--voice-test")
	var speak_test := OS.get_cmdline_user_args().has("--speak-test") or OS.get_cmdline_args().has("--speak-test")
	if speak_test:
		await _speak_test()
		return
	if inspect_music or inspect_voice:
		var shelf := RecordShelf.new()
		add_child(shelf)
		await get_tree().process_frame
		if inspect_music:
			print("MUSIC_LIST=%s FOLDER=%s" % [",".join(shelf.ids()), shelf.folder])
		if inspect_voice:
			print("VOICE_MODELS=%s" % Headphones.models_folder())
		get_tree().quit()
		return
	# A SESSION ASKED FOR ON THE COMMAND LINE comes before any door: `--host`, `--join=`, `--steam-host`, `--steam-join=`
	# and Steam's own `+connect_lobby` (see `LaunchOrder`). A typo in that namespace ends the process with BOOT_ERROR=
	# rather than opening the desk a harness would wait at for ever.
	var order: Dictionary = LaunchOrder.read(OS.get_cmdline_user_args(), OS.get_cmdline_args(), Net.usual_port)
	if String(order["error"]) != "":
		_refuse_to_boot(String(order["error"]))
		return
	# AND WHICH LEVEL, for a host, a solo flight or a door into the world: `--world=<id>`. A level nobody has, or one named
	# beside a join -- a joiner flies the host's -- ends the process the same way. See `ChartDrawer.asked_in`.
	var world: Dictionary = ChartDrawer.asked_in(OS.get_cmdline_user_args(), String(order["mode"]))
	if String(world["error"]) != "":
		_refuse_to_boot(String(world["error"]))
		return
	if String(world["id"]) != "":
		Net.choose_level(String(world["id"]))
	if String(order["mode"]) != "none":
		_start_the_session.call_deferred(order)
		return
	var level: String = String(asked.get("level", "menu")).to_lower()
	# The marshalling levels first, because they answer for themselves: see
	# MarshallingLevel.DOORS, which is where their names and their scenes live.
	var on_foot: String = MarshallingLevel.scene_for(level)
	if on_foot != "":
		_go(on_foot)
		return
	# AND ANYTHING THIS ROUTER DOES NOT KNOW IS THE DESK. A typo should land somewhere a
	# person can read and press a button, not nowhere.
	_go(String(DOORS.get(level, DESK)))


## Export acceptance: load the executable-side model, generate through Kokoro,
## capture/encode/decode through the exact multiplayer path and report samples.
func _speak_test() -> void:
	Net.is_host = true; Net.is_in_session = true; Net.transport = "solo"
	var played := [0]
	Radio.clip_played.connect(func(_id: int, samples: int, _peer: int): played[0] = samples)
	Headphones.choose_voice(true)
	var until := Time.get_ticks_msec() + 45000
	while Headphones.voice != PilotHeadphones.Voice.ON and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	if Headphones.voice != PilotHeadphones.Voice.ON:
		print("SPEAK_ERROR=%s VOICE_MODELS=%s" % [Headphones.said, Headphones.models_folder()])
		get_tree().quit(1); return
	var why := Radio.speak("Cockpit tower export radio check.")
	while played[0] == 0 and why.is_empty() and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	if played[0] == 0:
		print("SPEAK_ERROR=%s" % (why if not why.is_empty() else Radio.status))
		get_tree().quit(1); return
	var wave := RadioClip.stream(Radio.last_clip)
	var audio_path := ProjectSettings.globalize_path("user://radio_export_test")
	var saved := wave.save_to_wav(audio_path) if wave != null else ERR_INVALID_DATA
	print("VOICE_SAMPLES=%d CLIP_BYTES=%d VOICE_MODELS=%s AUDIO=%s.wav SAVE=%s" % [played[0],
		Radio.last_clip.size(), Headphones.models_folder(), audio_path, error_string(saved)])
	get_tree().quit()


func _go(scene: String) -> void:
	get_tree().change_scene_to_file.call_deferred(scene)


## A SESSION ASKED FOR ON THE COMMAND LINE: start it, wait for `Net` to say it is up or why not, then go to the world.
##
## Nobody is at a desk to read a refusal, so it goes where a shell reads it -- BOOT_ERROR= -- and the process ends. Every
## session waits on `Net`'s own deadlines, one per stage, and since 2026-09-18 an ENet join has them too: this loop only
## waits for `Net` to say it is in or say why not, in the same words the desk shows.
func _start_the_session(order: Dictionary) -> void:
	var heard: Array = [""]
	Net.session_message.connect(func(text: String) -> void: heard[0] = text)
	# WHICH STEAM ACCOUNT THIS PROCESS IS, said before anything is asked of Steam and whether or not the session comes
	# up, because it is the first thing a two-machine run has to establish: two processes signed in as ONE account are
	# not two peers, and a run made that way proves nothing about a join. `unavailable` is what starts Steam, and
	# hosting or joining is about to call it anyway. Added 2026-09-15, when a one-machine repro had to tell the two apart.
	if String(order["mode"]).begins_with("steam") and Net.lobbies != null and Net.lobbies.unavailable() == "":
		print("STEAM_ID=%d" % Net.lobbies.me())
	# `--hold-until=<file>`, FOR A HARNESS: boot, read the order, say HOLDING, and start the session only once that file
	# exists. For a suite that needs a peer to arrive inside a window it does not control: `tests/notices.gd` proves a
	# player who connects DURING the 3 s level-change warning still gets the cue, and a process started at the press
	# took 5,577 ms just to boot under six lanes' load (2026-09-18), so it arrived after the change and the suite waited
	# out its deadline. Held, the process is booted before the press and connects after it, by construction.
	var hold: String = String(_arguments().get("hold-until", ""))
	if hold != "":
		print("HOLDING until %s" % hold)
		var held_since: int = Time.get_ticks_msec()
		while not FileAccess.file_exists(hold):
			if Time.get_ticks_msec() - held_since > HOLD_PATIENCE_MSEC:
				_refuse_to_boot("held for %d ms and %s never appeared" % [HOLD_PATIENCE_MSEC, hold])
				return
			await get_tree().process_frame
	match String(order["mode"]):
		"host":
			Net.host(int(order["port"]))
		"join":
			Net.join(String(order["address"]), int(order["port"]))
		"steam_host":
			Net.host_steam()
		"steam_code":
			Net.join_code(String(order["code"]))
		"steam_lobby":
			Net.join_lobby(int(order["lobby"]))
	while not Net.is_in_session:
		if Net.transport == "none":
			_refuse_to_boot(Net.parting_words if Net.parting_words != "" else String(heard[0]))
			return
		await get_tree().process_frame
	if Net.session_code != "":
		print("STEAM_CODE=%s" % Net.session_code)
	print("SESSION=%s %s" % [Net.transport, "host" if Net.is_host else "client"])
	# AND WHAT THE DESK WOULD HAVE SAID ON THE WAY IN, "Connected. Flying ...", which since protocol 37 says how far this
	# build is from the host's when they differ (`tests/handshake_peers.gd` reads it).
	if String(heard[0]) != "":
		print("SESSION_SAID=%s" % heard[0])
	# AND THROUGH THE DOOR THE COMMAND LINE ASKED FOR, which until 2026-09-19 was always the world: a session was
	# started and `--level=` was ignored, so `--host --level=voice` flew the island. The world is still what a session
	# with no door asked for, and `--level=world` is still the world, so nothing that worked reads differently; the flat
	# lobby needs `--host=PORT --level=voice` to arrive in the lobby, and so does its two-peer test.
	var door: String = String(_arguments().get("level", "")).to_lower()
	_go(String(DOORS.get(door, WORLD)) if door != "" else WORLD)


## NO, AND WHY, where a shell will see it, and the process ends. A flag-driven process has no menu and no operator.
func _refuse_to_boot(words: String) -> void:
	push_error("[boot] " + words)
	print("BOOT_ERROR=%s" % words)
	get_tree().quit(1)



## `--name=value` pairs from after the `--`. Anything that is not a pair is ignored rather
## than complained about: Godot's own arguments end up here too.
static func _arguments() -> Dictionary:
	var out: Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() == 2:
			out[parts[0].to_lower()] = parts[1]
	return out
