extends Node
## WHAT THE SERVER'S 2D CONSOLE LOOKS LIKE, because a headless run cannot tell whether it is legible or whether it is
## on screen at all (CLAUDE.md rule 2, and this workshop has shipped bugs that were green in every test).
##
##   Godot --path cockpit res://tests/server_shot.tscn
##
## `tests/server_peers.gd` proves the numbers are the right numbers, over a real socket, with a real machine joining.
## This proves a person standing at the machine can READ them. Neither says anything about the other.
##
## IN A SubViewport AND NEVER THE DESKTOP. A ddagrab of the desktop once caught another application on the user's
## screen (2026-09-18), so every picture in this project comes off a viewport this process owns.
##
## TWO PICTURES, because the two states a server is in look nothing alike and only one of them is ever photographed by
## accident:
##
##   1. EMPTY, the state a server spends most of its life in and the one somebody stares at wondering whether it is
##      working. It has to say "simulating" and "nobody yet" clearly enough that a person can tell a live empty server
##      from a dead one WITHOUT reading the log -- which is the whole reason the panel exists rather than just the
##      `SERVER_CONSOLE` line.
##   2. BUSY, with players on teams.
##
## THE ROSTER IS STAGED, AND RE-STAGED BEFORE EVERY REDRAW. A host in a session republishes its roster from its own
## cards every frame (`Net._keep_the_roster`), so staging it once is not enough -- that is how `lobby2d_shot` first
## came out with every row reading "PLAYER 1", and it solves it by leaving `Net.is_in_session` FALSE. That is not open
## to this picture: a photograph of a server captioned SOLO is a lie about the only thing its top line says, and the
## first version of this shot photographed exactly that. So the session is real and `_apply` runs in `_save`.
##
## THE NUMBERS ON IT ADD UP, on purpose. 93 craft is the island's own traffic with nobody aboard; the busy picture has
## four joiners, so four pilots and 97 craft. Numbers on a photograph get read, and a picture whose own arithmetic is
## wrong teaches somebody something false about what the panel means. The names are test names, never a real Steam
## account's.
##
## Read RESULT=, not the exit code.

const EMPTY_SHOT: String = "user://server_console_empty.png"
const BUSY_SHOT: String = "user://server_console_busy.png"
const WIDTH: int = 1600
const HEIGHT: int = 900
## A port for the listening socket this picture needs (see `_ready`). Inside `server_peers`' own block, because this
## probe never runs in a gate and never beside that suite -- `docs.gd` lists it as a probe for exactly that reason.
##
## NAMED `FIRST_PORT` BECAUSE `lint` ALLOWS ONLY THAT NAME, AND `LAST_PORT`, to carry a literal out of the suites'
## block (`WANTED_DECLARED`). Under any other name it is a typed port to the rule, and as `SHOT_PORT` it turned
## `and_every_suite_takes_its_ports_from_the_authority` red on main. The port and its reasoning are unchanged.
##
## THE RULE IS NARROWER THAN "DO NOT TYPE A PORT", which is why two lanes each had to learn it: a literal in the
## block is allowed, and only its NAME decides. `lane/phantom` found it by gating MAIN rather than a branch -- it is
## a rule about the whole tests folder, so no lane's own gate would ever name it.
const FIRST_PORT: int = 48296


func _ready() -> void:
	var glass := SubViewport.new()
	glass.size = Vector2i(WIDTH, HEIGHT)
	glass.transparent_bg = false
	glass.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(glass)
	BuildStamp.attach_to(glass)

	var was_host: bool = Net.is_host
	var was_in: bool = Net.is_in_session
	var was_transport: String = Net.transport
	var was_roster: Dictionary = Net.roster
	var was_level: String = Net.level
	var was_ready: bool = Sim.is_ready
	var was_pilots: Array = Sim.pilots
	var was_port: int = Net.usual_port
	Net.is_host = true
	# IN A SESSION, because a picture of a server captioned SOLO is a lie about the only thing the top line says. The
	# first version left this false the way `lobby2d_shot` does and photographed exactly that. A host in a session
	# republishes its roster from its own cards (`Net._keep_the_roster`), which is why that shot leaves it false -- so
	# the roster here is re-staged immediately before every redraw instead. See `_save`.
	Net.is_in_session = true
	Net.transport = "enet"
	Net.level = "island"
	# AND A REAL LISTENING SOCKET, because `Net.is_networked()` asks Godot whether there is a multiplayer peer and
	# nothing else will satisfy it -- the panel says HOSTING or SOLO off that one answer. A flag could have been
	# faked; a peer is two lines and makes the sentence on the photograph TRUE. Closed again at the end.
	var port: int = TestPorts.first_free(FIRST_PORT, 4)
	var peer := ENetMultiplayerPeer.new()
	if port != 0 and peer.create_server(port, 4) == OK:
		multiplayer.multiplayer_peer = peer
		Net.usual_port = port
	# A SERVER THAT IS SIMULATING, which is the state worth photographing. `Sim.is_ready` is what the panel reads and
	# nothing here starts a simulation, so it is staged and put back, exactly as the `Net` fields around it are.
	Sim.is_ready = true

	# ---- 1. EMPTY -------------------------------------------------------------------------------
	_stage({}, 0)
	var console := ServerConsole.new()
	console.size = Vector2(WIDTH, HEIGHT)
	# AND A WORLD FOR IT TO COUNT. Handed in the way `Sky` hands it the real one, so the panel is exercised through
	# the same seam rather than having its numbers written onto it: with no server at all it draws "-1 craft", which
	# is honest and is not what a person is ever meant to be looking at.
	console.server = _a_world_with(93)
	glass.add_child(console)
	await get_tree().process_frame
	console.size = Vector2(WIDTH, HEIGHT)
	var empty: int = await _save(glass, EMPTY_SHOT)

	# ---- 2. BUSY --------------------------------------------------------------------------------
	# FOUR PLAYERS ON TWO TEAMS AND ONE ON NEITHER, which is the arrangement a controller's roster comes in: the names
	# are the shapes real ones take -- a typed name, a Steam handle, a name with a space in it.
	var built: int = int(Net.identity()["built"])
	# FOUR JOINERS, SO FOUR PILOTS AND FOUR MORE CRAFT THAN THE EMPTY PICTURE. The numbers on a photograph get read, so
	# they have to add up: 93 is the island's own traffic and the server flies none of it itself.
	_stage({
		1: {"player": 1, "name": "GRAHAM", "colour": 0, "built": built, "team": 1},
		2: {"player": 2, "name": "kestrel_77", "colour": 2, "built": built, "team": 1},
		3: {"player": 3, "name": "Sam Flies", "colour": 5, "built": built, "team": 2},
		4: {"player": 4, "name": "TOWER", "colour": 3, "built": built, "team": 0},
	}, 4)
	console.server = _a_world_with(93 + 4)
	var busy: int = await _save(glass, BUSY_SHOT)

	Net.roster = was_roster
	Net.is_host = was_host
	Net.is_in_session = was_in
	Net.transport = was_transport
	Net.level = was_level
	Sim.is_ready = was_ready
	Sim.pilots = was_pilots
	Net.usual_port = was_port
	multiplayer.multiplayer_peer = null
	_staged = {}
	var both: bool = empty == OK and busy == OK
	print("[server_shot] RESULT=%s" % ("PASS" if both else "FAIL saving the pictures: %s, %s"
		% [error_string(empty), error_string(busy)]))
	get_tree().quit(0 if both else 1)


## WHAT THIS PICTURE IS PRETENDING IS TRUE, kept so `_save` can put it back. A host in a session republishes its own
## roster every frame, so staging it once is not enough.
var _staged: Dictionary = {}


## Stage a roster and a pilot count, and apply them now.
func _stage(roster: Dictionary, pilots: int) -> void:
	_staged = {"roster": roster, "pilots": pilots}
	_apply()


func _apply() -> void:
	if _staged.is_empty():
		return
	Net.roster = _staged["roster"]
	# `Sim.pilots` is whatever the client last captured; the panel only counts it.
	var rows: Array = []
	for i in range(int(_staged["pilots"])):
		rows.append({"client": i + 1})
	Sim.pilots = rows


## A STAND-IN FOR THE SIMULATION'S SERVER, answering the two questions the panel asks it. Not a mock of the panel's
## own arithmetic: the panel still does all of it, and this only stands where a running world would.
class StagedWorld extends RefCounted:
	var _craft: int = 0
	var _tick_us: float = 0.0

	func vehicle_states() -> Array:
		var rows: Array = []
		for i in range(_craft):
			rows.append({"entity": i + 1})
		return rows

	func tick_breakdown() -> Dictionary:
		return {"total_us": _tick_us}


func _a_world_with(craft: int) -> RefCounted:
	var world := StagedWorld.new()
	world._craft = craft
	# A PLAUSIBLE TICK, so the line reads as it does in life. The island's real one is well under a millisecond.
	world._tick_us = 640.0
	return world


## THE PANEL IS REDRAWN BEFORE THE SHUTTER, not merely waited on. It redraws itself once a second off `_process`, and a
## dozen frames at whatever rate this process is running is not reliably a second: the first version of the busy
## picture came out showing "nobody yet" beside a roster of four.
func _save(glass: SubViewport, path: String) -> int:
	_apply()
	for console in glass.find_children("*", "Control", true, false):
		if console is ServerConsole:
			(console as ServerConsole)._draw_the_facts()
	for i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = glass.get_texture().get_image()
	var saved: int = picture.save_png(path)
	print("[server_shot] %d x %d, saved %s to %s" % [picture.get_width(), picture.get_height(),
		error_string(saved), ProjectSettings.globalize_path(path)])
	return saved
