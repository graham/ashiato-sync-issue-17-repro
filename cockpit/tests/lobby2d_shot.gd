extends Node
## WHAT THE FLAT VOICE LOBBY LOOKS LIKE, because a headless run cannot tell whether it is legible or whether it is on
## screen at all (CLAUDE.md rule 2, and this workshop has shipped bugs that were green in every test).
##
##   Godot --path cockpit res://tests/lobby2d_shot.tscn
##
## THE ROOM IS DRAWN FROM DATA HANDED TO IT, as `tests/crew_shot.gd` draws the CREW page: `Net.roster` is set here, the
## teams with it, and the log filled by the same signal a real line arrives on. So this is a picture of the PAGE and says
## nothing about the network -- `tests/lobby2d_peers.gd` is what proves three machines agree, and this is what proves a
## person can read the result.
##
## IN A SubViewport AND NEVER THE DESKTOP. A ddagrab of the desktop once caught another application on the user's screen
## (2026-09-18), so every picture in this project comes off a viewport this process owns.
##
## The roster here is TEST NAMES on purpose, never a real Steam account's.
##
## Read RESULT=, not the exit code.

const SHOT: String = "user://lobby2d.png"
## AND THE ONE THAT MATTERS: somebody talking, with their lamp lit, while a player on another team sits dark.
const TALKING_SHOT: String = "user://lobby2d_talking.png"
const WIDTH: int = 1600
const HEIGHT: int = 900


func _ready() -> void:
	var glass := SubViewport.new()
	glass.size = Vector2i(WIDTH, HEIGHT)
	glass.transparent_bg = false
	glass.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(glass)
	BuildStamp.attach_to(glass)

	# THE SESSION AS A HOST SEES IT: `is_host` so the rows carry the TEAM buttons a host presses, and a transport and a
	# code so the line under the title says what it says in a real Steam session.
	var was_host: bool = Net.is_host
	var was_in: bool = Net.is_in_session
	var was_transport: String = Net.transport
	var was_roster: Dictionary = Net.roster
	Net.is_host = true
	Net.transport = "steam"
	Net.session_code = "K7QF2M"
	var built: int = int(Net.identity()["built"])
	# THREE PLAYERS ON TWO TEAMS AND ONE ON NEITHER, which is the arrangement the feature exists for: a team with
	# somebody outside it. The names are the shapes real ones come in -- a typed name, a Steam handle, a name with a
	# space in it.
	Net.roster = {
		1: {"player": 1, "name": "GRAHAM", "colour": 0, "built": built, "team": 1},
		2: {"player": 2, "name": "kestrel_77", "colour": 2, "built": built, "team": 2},
		3: {"player": 3, "name": "Sam Flies", "colour": 5, "built": built, "team": 0},
	}

	# NOT IN A SESSION, and drawn through `show_the_room` rather than by entering one. A host in a session republishes
	# its roster from its own cards every frame (`Net._keep_the_roster`), so a staged roster put in front of a room that
	# thinks it has joined is overwritten before the shutter opens: the first version of this picture came out with one
	# row reading "PLAYER 1" and a log crediting PLAYER 1, 2 and 3 for lines three named players had typed.
	Net.is_in_session = false
	var room := preload("res://world/flat_lobby.tscn").instantiate()
	glass.add_child(room)
	await get_tree().process_frame
	room.size = Vector2(WIDTH, HEIGHT)
	room.show_the_room()

	# THE TALK, put on through the signal a real line arrives on, so the picture shows the same words the same way.
	Net.chat_arrived.emit({"n": 1, "player": 1, "text": "radio check, can everybody hear me"})
	Net.chat_arrived.emit({"n": 2, "player": 2, "text": "loud and clear"})
	Net.chat_arrived.emit({"n": 3, "player": 3, "text": "nothing here yet -- am i on a team?"})
	Net.chat_arrived.emit({"n": 4, "player": 1, "text": "putting you on GREEN now"})

	var saved: int = await _save(glass, SHOT)

	# THE PICTURE THAT MATTERS: kestrel_77 on BLUE is talking, so their lamp wears their own colour, and the two players
	# who are not talking sit dark. `Net.talking` is what the row reads -- the host's answer, which is the only thing a
	# lamp is ever painted from -- so staging it here is staging exactly what a real session would deliver.
	Net.talking = [2]
	room.show_the_room()
	var lit: int = await _save(glass, TALKING_SHOT)
	Net.talking = []

	Net.roster = was_roster
	Net.is_host = was_host
	Net.is_in_session = was_in
	Net.transport = was_transport
	Net.session_code = ""
	var both: bool = saved == OK and lit == OK
	print("[lobby2d_shot] RESULT=%s" % ("PASS" if both else "FAIL saving the pictures: %s, %s"
		% [error_string(saved), error_string(lit)]))
	get_tree().quit(0 if both else 1)


func _save(glass: SubViewport, path: String) -> int:
	for i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = glass.get_texture().get_image()
	var saved: int = picture.save_png(path)
	print("[lobby2d_shot] %d x %d, saved %s to %s" % [picture.get_width(), picture.get_height(),
		error_string(saved), ProjectSettings.globalize_path(path)])
	return saved
