extends Control
class_name FlatLobby
## A FLAT ROOM WITH THE PLAYERS IN IT, FOR CHECKING THAT VOICE WORKS. No world, no craft, no headset.
##
## The user asked for exactly this (2026-09-19): "I need a level, that doesn't use VR, that allows me to join a steam
## game (and host one) and i can just test voice and ai voice. So it will need a player lobby with text chat, and a
## player list and player names ... build this, take into account the idea that we need a new simpler lobby that is ONLY
## 2d so we can verify these things work, we'll need a different entry point and .bat so i can test it on other
## machines."
##
## SO THE POINT OF IT IS THAT IT IS SMALL. Every failure this room can have is a failure of the session, the roster, the
## chat or the voice -- never of a cockpit, a rig, a level's ground or an XR runtime. When a two-machine voice test fails
## here, there is nowhere else for the fault to be.
##
## ---------------------------------------------------------------------------------------------------
## WHY A `Control` AND NOT A `Node2D`
## ---------------------------------------------------------------------------------------------------
##
## This is the first flat scene in cockpit -- `rg "extends Node2D"` finds nothing else -- so there was a choice to make
## and it is worth writing down. the lobby lane (2026-09-15) listed "the mouse in 2D" as a problem nobody here has
## solved: a `Node2D` scene has to find the pointer, decide what it is over and route a press itself. A `Control` tree
## does all three already, and a lobby is a list, a log and some buttons -- which is what `Control` is for. It also means
## the whole room is authored like every other screen in this game (`SessionMenu`, `ClipboardPage`), so nothing here is a
## second way of doing UI.
##
## ---------------------------------------------------------------------------------------------------
## WHAT THIS ROOM DOES NOT OWN
## ---------------------------------------------------------------------------------------------------
##
## Nearly all of it. The room is a page that is handed its data and draws it (rule 5):
##
##   - HOST AND JOIN is `SessionMenu`, unchanged, which already does solo, Steam, a typed address, a code keypad and a
##     list of other people's games, and which ANNOUNCES rather than acts. This room acts on it the way `world/desk.gd`
##     does, and the mapping is deliberately the same one.
##   - THE PLAYER LIST is `Net.roster_cards()`. Names, the Steam persona, a typed name winning over it, duplicate names
##     given suffixes, colours, and who has gone -- all of it is already the host's published roster, already proven by
##     `tests/names_peers.gd`. This room draws it and keeps no list of its own.
##   - WHO JOINED AND WHO LEFT is `Net.noticed` and `Net.notice_words()`, which say it in words already.
##   - TEAMS are `Net.team_of` and `Net.set_team`, and the rules are `TeamBoard`'s.
##   - CHAT is `Net.say_in_chat` and `Net.chat_arrived`.
##
## ---------------------------------------------------------------------------------------------------
## TWO THINGS IT MUST DO THAT A LEVEL WOULD HAVE DONE FOR IT
## ---------------------------------------------------------------------------------------------------
##
## `Sim.start()`, AND WHY A LOBBY NEEDS A SIMULATION AT ALL. The roster is keyed by sync client id, and
## `Sim.local_client_id()` and `Sim.client_of_peer()` both answer 0 while `Sim.client` is null -- so a room that started
## no simulation would draw an empty player list however well the session worked. `Sim.start()` builds the replication
## client (and the host's server) and nothing else: no level, no ground, no craft, no pilot. The peer-to-client pairing
## the roster needs comes from sync's own connection events on the host (`Sim.client_of_peer`), not from any pilot, which
## is why this room needs no craft and nobody in a seat.
##
## `Net.level_loaded("")`, WHICH IS WHAT ADMITS A JOINER. Until a joiner says `loaded`, its host does not admit it
## (`Net.admits`), and an unadmitted peer's card -- and its chat -- are never taken. In a normal session
## `world/sky.gd` says it at the end of building a level; here there is no level to build, so this room says it as soon
## as it is up, with no ground hash, which is what a level with no ground says too.
##
## ---------------------------------------------------------------------------------------------------
## THE CHAT LOG IS `Label`s, ON PURPOSE
## ---------------------------------------------------------------------------------------------------
##
## A chat line is the only free text another machine's player typed that this game ever draws, and a `RichTextLabel`
## would hand it to a BBCode parser: `[img]` and `[color]` in somebody's message would then be markup this machine obeys.
## They are a `Label`'s `text`, so they are characters somebody typed. See `ChatLine`.

## Where the boot router sends anybody asking for this room, and what this room asks Godot for when it leaves.
const BACK := Doors.DESK

const AMBER := Color(0.95, 0.76, 0.28)
const PALE := Color(0.86, 0.90, 0.92)
const DIM := Color(0.45, 0.50, 0.55)
const BACKING := Color(0.06, 0.07, 0.09)
const PANEL := Color(0.10, 0.12, 0.15)
## A lamp nobody is behind, and the one that says somebody is talking.
##
## LIT IS AMBER AND NOT THE SPEAKER'S OWN COLOUR, which is what it was until the picture was looked at (rule 2). Every
## row already carries that player's colour as a swatch one space to the right, so a lamp in the same colour made the
## talking row read as two identical bars and there was no telling which one was the lamp. The row says WHO by being
## that player's row; the lamp only has to say WHETHER, and it should say it in a colour nothing else on the row uses.
const LAMP_OFF := Color(0.16, 0.18, 0.21)
const LAMP_ON := Color(1.0, 0.86, 0.35)
const TITLE_SIZE: int = 26
const TEXT_SIZE: int = 18

var _menu: SessionMenu = null
var _room: Control = null
var _players: VBoxContainer = null
var _log: VBoxContainer = null
var _log_scroll: ScrollContainer = null
var _entry: LineEdit = null
var _send_button: Button = null
## The host's TEAM button for each player, by client id, so the harness can press the one a person would.
var _team_buttons: Dictionary = {}
## How many report ticks this machine has been in the room, which is the clock the harness's hands run on.
var _ticks: int = 0
## Set once the flags below have been acted on, so a room does not say the same line every second for ever.
var _hands_done: bool = false
var _intercom: Intercom = null
var _talk_all: Button = null
var _talk_team: Button = null
var _speak_row: HBoxContainer = null
var _speak_line: LineEdit = null
var _say_team: Button = null
## The lamp on each player's row, by client id, so a talking change repaints the lamps without rebuilding every row --
## a rebuilt row loses a button somebody is holding down.
var _lamps: Dictionary = {}
## EVERY LINE ON THE LOG, oldest first, as FACTS rather than as sentences: {"kind": "chat"|"notice", "player", "n",
## "text"}. The labels are built from this, and rebuilt whenever the roster changes.
##
## WHY IT IS KEPT AT ALL, instead of writing a Label and forgetting: a line can arrive BEFORE the name of whoever typed
## it. Measured 2026-09-19 -- a joiner's first line reached the host before the host had that player's card, and the host
## drew "PLAYER 3: radio check" and left it saying that for ever. `Net.name_of` is asked again on every redraw, so the
## board corrects itself the moment the card lands.
var _lines: Array[Dictionary] = []
## Line number -> the name this machine last REPORTED for it, so a correction is reported once and not every second.
var _named: Dictionary = {}
var _session_line: Label = null
var _said_line: Label = null
var _hint: Label = null
var _going: bool = false
## Set once this machine has stood up its simulation and told its host it is in, so neither is done twice.
var _up: bool = false


func _ready() -> void:
	var back := ColorRect.new()
	back.color = BACKING
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_build_the_room()
	_build_the_menu()
	Net.roster_changed.connect(_draw_the_players)
	Net.roster_changed.connect(_redraw_the_log)
	# THE LAMPS ARE REPAINTED, NOT REBUILT. `talking_changed` fires whenever anybody starts or stops, which is several
	# times a second in a busy room; rebuilding the rows there would take the TEAM button out from under a finger.
	Net.talking_changed.connect(_light_the_lamps)
	_intercom = Intercom.new()
	_intercom.name = "Intercom"
	add_child(_intercom)
	_intercom.heard.connect(func(speaker: int, kind: int, samples: int) -> void:
		if OS.get_cmdline_user_args().has("--report=1"):
			print("LOBBY_VOICE speaker=%d kind=%d samples=%d from=%s" % [speaker, kind, samples,
				Net.name_of(speaker)]))
	Net.chat_arrived.connect(_on_chat)
	Net.noticed.connect(_on_notice)
	Net.session_message.connect(_say)
	var ticker := Timer.new()
	ticker.wait_time = 1.0
	ticker.autostart = true
	ticker.timeout.connect(func() -> void:
		_ticks += 1
		_report()
		_the_hands())
	add_child(ticker)
	Net.session_ended.connect(func(why: String) -> void: _on_session_ended(why))
	# ALREADY IN A SESSION, because `--host`, `--join=`, `--steam-host` or `--steam-join=` was on the command line and the
	# boot router started it before opening any door. That is the case the two-machine test and the .bat both use.
	if Net.is_in_session:
		_enter_the_room()
	else:
		_show(false)


func _build_the_menu() -> void:
	_menu = SessionMenu.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.chose.connect(_on_chose)
	add_child(_menu)
	# ONLY ONTO THE LIST THAT IS SHOWING, which is `world/desk.gd`'s guard: a search the player has already pressed BACK
	# out of must not pull the game list back up under them when Steam finally answers.
	Net.games_listed.connect(func(games: Array) -> void:
		if _menu != null and _menu.showing_games():
			_menu.list_games(games))


## THE ROOM ITSELF: the players down the left, the talk down the right, and one line under both saying what happened.
func _build_the_room() -> void:
	_room = Control.new()
	_room.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_room)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 24.0
	column.offset_top = 18.0
	column.offset_right = -24.0
	column.offset_bottom = -18.0
	column.add_theme_constant_override("separation", 10)
	_room.add_child(column)

	var title := Label.new()
	title.text = "VOICE LOBBY"
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.add_theme_color_override("font_color", AMBER)
	column.add_child(title)

	_session_line = _a_label("", PALE)
	column.add_child(_session_line)

	var middle := HSplitContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.split_offset = 420
	column.add_child(middle)

	middle.add_child(_the_players_panel())
	middle.add_child(_the_talk_panel())

	# HOLD TO TALK. Two buttons and two keys, because the user asked for a button held down and a lobby is used with a
	# mouse as often as with the keyboard. `button_down` and `button_up` rather than `pressed`: a press is an event and
	# this is a state.
	var talk_row := HBoxContainer.new()
	talk_row.add_theme_constant_override("separation", 8)
	_talk_all = Button.new()
	_talk_all.text = "HOLD TO TALK TO EVERYONE  (T)"
	_talk_all.add_theme_font_size_override("font_size", TEXT_SIZE)
	_talk_all.button_down.connect(func() -> void: _hold(VoiceFrame.Audience.EVERYONE))
	_talk_all.button_up.connect(_let_go)
	talk_row.add_child(_talk_all)
	_talk_team = Button.new()
	_talk_team.text = "HOLD TO TALK TO YOUR TEAM  (G)"
	_talk_team.add_theme_font_size_override("font_size", TEXT_SIZE)
	_talk_team.button_down.connect(func() -> void: _hold(VoiceFrame.Audience.TEAM))
	_talk_team.button_up.connect(_let_go)
	talk_row.add_child(_talk_team)
	column.add_child(talk_row)

	# THE GENERATED LINE, and only a host has it: `Radio.why_not` refuses a client in words, and a button that is always
	# refused is a button that should not be on the screen. Two buttons for the two audiences, the same pair as the talk
	# row above, because a player should not have to learn a second idea of who is listening.
	_speak_row = HBoxContainer.new()
	_speak_row.add_theme_constant_override("separation", 8)
	_speak_line = LineEdit.new()
	_speak_line.placeholder_text = "A line for the tower to say"
	_speak_line.max_length = Radio.MOST_TEXT
	_speak_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speak_line.add_theme_font_size_override("font_size", TEXT_SIZE)
	_speak_line.text_submitted.connect(func(text: String) -> void: _speak(text, TeamBoard.NOBODY))
	_speak_row.add_child(_speak_line)
	var say_all := Button.new()
	say_all.text = "SAY TO EVERYONE"
	say_all.add_theme_font_size_override("font_size", TEXT_SIZE)
	say_all.pressed.connect(func() -> void: _speak(_speak_line.text, TeamBoard.NOBODY))
	_speak_row.add_child(say_all)
	_say_team = Button.new()
	_say_team.text = "SAY TO MY TEAM"
	_say_team.add_theme_font_size_override("font_size", TEXT_SIZE)
	_say_team.pressed.connect(func() -> void: _speak(_speak_line.text, Net.team_of(Sim.local_client_id())))
	_speak_row.add_child(_say_team)
	column.add_child(_speak_row)

	_hint = _a_label("", DIM)
	column.add_child(_hint)
	_said_line = _a_label("", AMBER)
	column.add_child(_said_line)

	var leave := Button.new()
	leave.text = "LEAVE"
	leave.add_theme_font_size_override("font_size", TEXT_SIZE)
	leave.pressed.connect(_leave)
	column.add_child(leave)


func _the_players_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 6)
	panel.add_child(inside)
	var heading := _a_label("PLAYERS", AMBER)
	inside.add_child(heading)
	_players = VBoxContainer.new()
	_players.add_theme_constant_override("separation", 4)
	inside.add_child(_players)
	return panel


func _the_talk_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 6)
	panel.add_child(inside)
	inside.add_child(_a_label("TALK", AMBER))
	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log = VBoxContainer.new()
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_constant_override("separation", 2)
	_log_scroll.add_child(_log)
	inside.add_child(_log_scroll)
	var row := HBoxContainer.new()
	_entry = LineEdit.new()
	_entry.placeholder_text = "Say something"
	_entry.max_length = ChatLine.MOST_CHARS
	_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry.add_theme_font_size_override("font_size", TEXT_SIZE)
	_entry.text_submitted.connect(func(text: String) -> void: _send(text))
	row.add_child(_entry)
	_send_button = Button.new()
	_send_button.text = "SEND"
	_send_button.add_theme_font_size_override("font_size", TEXT_SIZE)
	_send_button.pressed.connect(func() -> void: _send(_entry.text))
	row.add_child(_send_button)
	inside.add_child(row)
	return panel


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10.0)
	return style


func _a_label(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", TEXT_SIZE)
	label.add_theme_color_override("font_color", colour)
	return label


## THE TWO KEYS. `_unhandled_key_input` IS THE FOCUS GATE (CLAUDE.md rule 9): a `LineEdit` with focus consumes its own
## keys, so typing "get the tower" in the chat box does not transmit four bursts of voice. That is the gate working by
## construction rather than by a flag somebody has to remember to check.
##
## NOT `V`, which this project has trained everybody to press for the headset. T for talk, G for group.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	var audience: int = -1
	if key.physical_keycode == KEY_T or key.keycode == KEY_T:
		audience = VoiceFrame.Audience.EVERYONE
	elif key.physical_keycode == KEY_G or key.keycode == KEY_G:
		audience = VoiceFrame.Audience.TEAM
	if audience < 0:
		return
	get_viewport().set_input_as_handled()
	if key.pressed:
		_hold(audience)
	else:
		_let_go()


func _hold(audience: int) -> void:
	var why: String = _intercom.start_talking(audience)
	if why.is_empty():
		_say("Talking to %s..." % ("your team" if audience == VoiceFrame.Audience.TEAM else "everyone"))
	else:
		_say(why)


func _let_go() -> void:
	if _intercom.is_talking():
		_intercom.stop_talking()
		_say("")


## ---- the session ---------------------------------------------------------------------------------

## ACT ON WHAT THE MENU ANNOUNCED. The same mapping `world/desk.gd` uses, because it is the same menu answering the same
## question; the difference is where it goes afterwards, which is nowhere -- this room stays put and fills in.
func _on_chose(what: String, detail: String) -> void:
	if _going:
		return
	match what:
		"solo":
			Net.play_solo()
			_enter_the_room()
		"host":
			Net.host()
			if Net.is_in_session:
				_enter_the_room()
		"steam":
			Net.host_steam()
			await _enter_once_the_session_is_up()
		"join":
			var where: Dictionary = LaunchOrder.read_address(detail, Net.usual_port)
			if String(where["error"]) != "":
				_say("That address %s." % where["error"])
				return
			Net.join(String(where["address"]), int(where["port"]))
			await _enter_once_the_session_is_up()
		"code":
			Net.join_code(detail)
			await _enter_once_the_session_is_up()
		"browse":
			_menu.show_games(true)
			Net.look_for_games()
		"game":
			Net.join_game(int(detail))
			await _enter_once_the_session_is_up()
		"quit":
			_leave()


## Wait for `Net` to say the session is up, or to say why it never will be. `Net` owns every deadline here -- a room with
## a clock of its own would be a second answer to "how long do we wait".
func _enter_once_the_session_is_up() -> void:
	while not Net.is_in_session:
		if Net.transport == "none":
			_say(Net.parting_words if Net.parting_words != "" else "The session did not come up.")
			return
		await get_tree().process_frame
	_enter_the_room()


## THE SESSION IS UP: stand up the simulation the roster is keyed by, tell the host this machine is in, and draw.
##
## THE DRAWING IS A SEPARATE FUNCTION FROM THE JOINING (`show_the_room`) so that a picture can be taken of the room
## without a session: `tests/lobby2d_shot.gd` hands it a roster and photographs it, and if it went through here instead
## the host's own `Net._keep_the_roster` would republish a roster of one card over the top of the staged one every frame
## -- which it did, and the picture came out with a single row reading "PLAYER 1".
func _enter_the_room() -> void:
	if not _up:
		_up = true
		# NOBODY IS FLYING IN HERE, and that has to be said before the simulation is stood up: otherwise the host gives
		# every arriving player a pod at a level spawn with no ground under it and they fall for ever. See
		# `Sim.seat_players`, which was measured falling through -5275 m.
		# THE VOICE IS ON IN HERE, because this is the room for testing it. `Headphones` starts OFF everywhere else, and
		# `play_clip` refuses a clip while it is OFF -- so without this a generated line is sent, carried, validated and
		# then silently not played, which is exactly what the first run of `tests/intercom_peers.gd` measured: the host
		# printed "Sent to 2 players" and no machine announced a thing.
		#
		# ON A LISTENER THIS COSTS NOTHING IT NEED NOT SPEND: a machine with no model never reaches Voice.ON, and
		# `play_clip` only asks that the voice is not OFF, which is why `tests/radio_peers.gd`'s client plays a clip with
		# no model and no library present.
		Headphones.choose_voice(true)
		Sim.seat_players = false
		if not Sim.start():
			_say("The simulation library is missing, so there are no player numbers. Build ashiato-gd.")
		# NO GROUND, because there is no level here. Said unconditionally, host and client alike: a host sets its own
		# `_built_here` with the same call, and a client is not admitted until it has said this.
		Net.level_loaded("")
	show_the_room()
	# EVERYTHING SAID BEFORE THIS ROOM EXISTED. The boot router starts the session and only then opens the door, so a
	# `chatline` can land while `Net` is up and this scene is not: those lines are in `Net.chat_log` and had never been
	# drawn (measured 2026-09-19 -- the host's first line was invisible on both joiners).
	for line in Net.chat_log:
		_remember({"kind": "chat", "n": int(line["n"]), "player": int(line["player"]), "text": String(line["text"])})


## DRAW THE ROOM AS IT STANDS, with whatever `Net` currently says is in it. Public, because a picture is taken of it.
func show_the_room() -> void:
	_show(true)
	_draw_the_session()
	_draw_the_players()
	_redraw_the_log()


func _on_session_ended(why: String) -> void:
	_up = false
	_say(why if why != "" else "The session ended.")
	_show(false)


func _leave() -> void:
	if _going:
		return
	if Net.is_in_session or Net.transport != "none":
		_going = true
		Net.leave("left the voice lobby")
		_going = false
		return
	get_tree().change_scene_to_file.call_deferred(BACK)


func _show(in_a_session: bool) -> void:
	_room.visible = in_a_session
	_menu.visible = not in_a_session


## ---- what is drawn -------------------------------------------------------------------------------

func _draw_the_session() -> void:
	var words: PackedStringArray = ["HOST" if Net.is_host else "JOINED", "over %s" % Net.transport]
	if Net.session_code != "":
		words.append("code %s" % Net.session_code)
	# ONLY ONCE THERE IS SOMEBODY TO NAME. `Sim.local_client_id()` is 0 until sync has numbered this machine, and
	# `Net.name_of(0)` is the string "PLAYER 0" -- a player number nobody has, written where a player's own name goes.
	var me: int = Sim.local_client_id()
	words.append("as %s" % Net.name_of(me) if me > 0 else "joining...")
	_session_line.text = " * ".join(words)
	_hint.text = "The host assigns teams. " + ("Press TEAM on a row to move somebody." if Net.is_host
		else "Only the host can change teams.")
	if _speak_row != null:
		_speak_row.visible = Net.is_host


## ONE ROW PER PLAYER, REBUILT FROM THE ROSTER. Rebuilt rather than patched because the roster is the whole truth and a
## row kept from the last draw is a row that can outlive the player in it -- which is the stale-player bug this list
## exists to not have.
func _draw_the_players() -> void:
	if _players == null:
		return
	for row in _players.get_children():
		row.queue_free()
	_team_buttons.clear()
	_lamps.clear()
	for card in Net.roster_cards():
		var client: int = int(card["player"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		# THE SPEAKING LAMP, always there and dark until step 3 lights it from what the host says. Always drawn, because
		# the user asked for a lamp that is always visible -- a lamp that appears when somebody talks is one you cannot
		# tell from a lamp that is broken.
		var lamp := ColorRect.new()
		lamp.custom_minimum_size = Vector2(16, 16)
		lamp.color = LAMP_ON if Net.is_talking(client) else LAMP_OFF
		lamp.name = "Lamp"
		row.add_child(lamp)
		_lamps[client] = lamp

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(10, 16)
		swatch.color = Net.colour_of(client)
		row.add_child(swatch)

		var name_label := _a_label(Net.name_of(client), PALE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var team: int = Net.team_of(client)
		if Net.is_host:
			var button := Button.new()
			button.text = TeamBoard.name_of(team)
			button.add_theme_font_size_override("font_size", TEXT_SIZE)
			button.pressed.connect(func() -> void: _cycle_team(client))
			row.add_child(button)
			_team_buttons[client] = button
		else:
			row.add_child(_a_label(TeamBoard.name_of(team), DIM if team == TeamBoard.NOBODY else PALE))
		_players.add_child(row)


## WHO IS LIT. `Net.is_talking` is the HOST's answer, carried to every machine -- never "am I receiving frames from
## them", which would leave a team-talker dark on every machine outside their team.
func _light_the_lamps() -> void:
	for client in _lamps:
		var lamp := _lamps[client] as ColorRect
		if is_instance_valid(lamp):
			lamp.color = LAMP_ON if Net.is_talking(int(client)) else LAMP_OFF
	if OS.get_cmdline_user_args().has("--report=1"):
		# WHAT THE ROW ACTUALLY SHOWS, read back off the ColorRects rather than off `Net.talking`.
		#
		# IT USED TO PRINT `Net.talking` AND THAT WAS A TAUTOLOGY: a mutant that painted every lamp from "have I played
		# any frames" -- a local guess, the exact bug the lamp is designed not to be -- passed the whole suite, because the
		# evidence being read was the host's published fact and not the paint. The two are only equal when the code is
		# right, which is the thing under test.
		var lit: PackedStringArray = []
		for client in _lamps:
			var drawn := _lamps[client] as ColorRect
			if is_instance_valid(drawn) and drawn.color != LAMP_OFF:
				lit.append(str(client))
		lit.sort()
		print("LOBBY_LAMPS lit=%s talking=%s" % ["-" if lit.is_empty() else "+".join(lit), Net.talking])


## THE HOST'S ONE BUTTON PER PLAYER. It asks `Net`, which refuses in words if it is not the host's to ask -- rather than
## this room deciding it is allowed, which is the same fact kept in two places.
func _cycle_team(client: int) -> void:
	var why: String = Net.set_team(client, TeamBoard.next(Net.team_of(client)))
	if why.is_empty():
		_draw_the_players()
	else:
		_say(why)


func _send(text: String) -> void:
	var why: String = Net.say_in_chat(text)
	if why.is_empty():
		_entry.text = ""
		_say("")
	else:
		_say(why)


## ASK THE TOWER TO SAY SOMETHING. `Radio` refuses in words -- not the host, no voice model, too many words, a control
## character -- and the words go on the line under the room, where the answer to a press belongs.
func _speak(text: String, to_team: int) -> void:
	var why: String = Radio.speak(text, to_team)
	if why.is_empty():
		_speak_line.text = ""
		_remember({"kind": "notice", "n": 0, "player": 0,
			"text": "the tower is saying \"%s\"%s" % [text.strip_edges(),
				"" if to_team == TeamBoard.NOBODY else " to %s" % TeamBoard.name_of(to_team)]})
	else:
		_say(why)


func _on_chat(line: Dictionary) -> void:
	_remember({"kind": "chat", "n": int(line["n"]), "player": int(line["player"]), "text": String(line["text"])})


## PUT A LINE ON THE LOG AND REPORT IT ONCE. Both the arrival and the catch-up at entry come through here, so what a
## harness reads and what a person sees are the same set of lines -- they were not, and a joiner that received chat
## before this scene existed drew those lines with no report against them.
func _remember(line: Dictionary) -> void:
	_lines.append(line)
	while _lines.size() > ChatLine.MOST_KEPT:
		var dropped: Dictionary = _lines.pop_front()
		_named.erase(int(dropped.get("n", 0)))
	if String(line["kind"]) == "chat" and OS.get_cmdline_user_args().has("--report=1"):
		# THE TEXT IS LAST, because it is the one field with spaces in it: a harness reading key=value pairs takes
		# everything after `text=` as the message. Who said it is its own line, for the same reason -- a name has spaces
		# in it too ("PLAYER 3").
		print("LOBBY_CHAT n=%d player=%d text=%s" % [int(line["n"]), int(line["player"]), String(line["text"])])
	_redraw_the_log()


## JOINED AND LEFT, in the words `Net` already writes for them, on the same log as the talk: this is the room where
## somebody is watching for a player to appear, so it belongs where they are looking.
func _on_notice() -> void:
	var words: String = Net.notice_words()
	if not words.is_empty():
		_remember({"kind": "notice", "n": 0, "player": 0, "text": words})
	_draw_the_players()


## THE WHOLE LOG, FROM THE FACTS, with every name asked of the roster as it stands NOW. Rebuilt rather than patched for
## the reason the player list is rebuilt: a label kept from the last draw is a label that can still be naming somebody by
## a number after their card has arrived.
func _redraw_the_log() -> void:
	if _log == null:
		return
	for label in _log.get_children():
		_log.remove_child(label)
		label.queue_free()
	for line in _lines:
		if String(line["kind"]) == "notice":
			_write("-- %s" % String(line["text"]), DIM)
			continue
		var player: int = int(line["player"])
		var name: String = Net.name_of(player)
		_write("%s: %s" % [name, String(line["text"])], PALE)
		# AND SAY SO WHEN IT CHANGES. A line first drawn as "PLAYER 3" and redrawn as "ALICE" is the board correcting
		# itself, which is a fact worth reporting exactly once -- `tests/lobby2d_peers.gd` asserts on the last one.
		if OS.get_cmdline_user_args().has("--report=1") and String(_named.get(int(line["n"]), "")) != name:
			_named[int(line["n"])] = name
			print("LOBBY_NAMED n=%d player=%d name=%s" % [int(line["n"]), player, name])
	_scroll_to_the_bottom()


## A LINE ON THE LOG. `Label`, never BBCode: see the note at the top.
func _write(words: String, colour: Color) -> void:
	if _log == null:
		return
	var label := _a_label(words, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_child(label)


func _scroll_to_the_bottom() -> void:
	# The bar's range is only as long as the box once the box has been laid out again.
	await get_tree().process_frame
	if _log_scroll != null:
		_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


## A LINE FOR A HARNESS, with `--report=1` after the bare `--`, in the shape `world/sky.gd`'s SESSION_REPORT uses: once a
## second, everything a two-peer test needs to know about this machine's view of the room. A test reads the LATEST one,
## so a value that has not settled yet is not mistaken for a value that never will.
func _report() -> void:
	if not OS.get_cmdline_user_args().has("--report=1"):
		return
	var who: PackedStringArray = []
	for card in Net.roster_cards():
		who.append("%d:%s:%d" % [int(card["player"]), String(card["name"]), Net.team_of(int(card["player"]))])
	print("LOBBY_REPORT me=%d host=%s players=%d who=%s chat=%d said=%d talking=%s live=%d generated=%d frames=%d samples=%d mic=%d" % [
		Sim.local_client_id(), "yes" if Net.is_host else "no", Net.roster_cards().size(), ",".join(who),
		Net.chat_log.size(), _log.get_child_count() if _log != null else -1,
		"-" if Net.talking.is_empty() else "+".join(PackedStringArray(Net.talking.map(func(c): return str(c)))),
		_intercom.frames_of_kind(VoiceFrame.Kind.LIVE), _intercom.frames_of_kind(VoiceFrame.Kind.GENERATED),
		_intercom.played_frames, _intercom.played_samples, _intercom.microphone.frames_heard])


## ---- THE HARNESS'S HANDS -------------------------------------------------------------------------
##
## Two flags, and they press the SAME BUTTONS A PERSON PRESSES (CLAUDE.md rule 3: start a test at the last thing a human
## touches). `--say=` puts the words in the entry field and presses SEND; `--press-team=` presses a row's TEAM button. So
## what the two-peer test drives is the room, not `Net.say_in_chat` and `Net.set_team` underneath it -- a test that called
## those directly would still pass with the buttons wired to nothing.
##
##   --say=<words>                 say it once, from the entry field, through the SEND button
##   --press-team=<NAME>[:<n>]     press that player's TEAM button n times (once by default), host only
##   --hands-at=<players>          wait until this many players are listed before doing either (default 1)
##   --talk=all|team[:<ms>]        hold the talk button for <ms> (400 by default) and speak a tone into the microphone
##   --tower=all|team              publish a generated line to that audience, host only
##
## THE TONE GOES IN AT THE CAPTURE SEAM (`Microphone.feed`), which is the last place the real path is still the real
## path. Whether a microphone on this desk hears anything is a property of the desk -- `tests/voice_probe.gd` found every
## device on it reading silence -- so a headless suite cannot start at the air. It starts one step later and everything
## after it is the shipping code: the same frames, the same encoder, the same envelope, the same host routing.
##
## BY NAME AND NOT BY CLIENT ID, and it waits. The first version pressed `--press-team=2:2` on the third tick, and both
## went wrong at once (measured 2026-09-19): sync numbered the SECOND joiner 2, so the id named the wrong player, and at
## three seconds no joiner was on the roster at all, so there was no row and nothing was pressed. A name is what a person
## reads off the row they are aiming at, and waiting for the row is what a person does.
func _the_hands() -> void:
	if _hands_done or not Net.is_in_session:
		return
	var wanted: int = 1
	var asked: PackedStringArray = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hands-at="):
			wanted = maxi(argument.substr(11).to_int(), 1)
		elif argument.begins_with("--say=") or argument.begins_with("--press-team=") or argument.begins_with("--talk=") \
				or argument.begins_with("--tower="):
			asked.append(argument)
	if asked.is_empty():
		_hands_done = true
		return
	if Net.roster_cards().size() < wanted:
		return
	# AND IF THE HANDS ARE GOING TO TALK TO A TEAM, WAIT UNTIL THIS MACHINE IS ON ONE. The host assigns teams, and a
	# joiner learns its own from the roster the host then publishes -- so hands that fire on the same tick as the host's
	# ask to talk to a team they have not been put on yet and are refused, correctly, with words. Measured: ALICE's first
	# run printed "refused: You are not on a team yet" while the host's log showed it had just pressed her TEAM button.
	# A person would wait to see themselves on the team and press again; so does this. The refusal itself is exercised in
	# `tests/lobby2d.gd`, where it is the point rather than a race.
	for argument in asked:
		if argument.begins_with("--talk=team") and not TeamBoard.holds(Net.team_of(Sim.local_client_id())):
			return
	_hands_done = true
	for argument in asked:
		if argument.begins_with("--say="):
			_entry.text = argument.substr(6)
			_send_button.pressed.emit()
			print("LOBBY_HANDS said=%s" % argument.substr(6))
			continue
		if argument.begins_with("--tower="):
			# THE TOWER'S OWN VOICE, WITHOUT KOKORO. The model is a property of the desk, and this is a test of the ROUTING:
			# `Radio.publish_pcm` is the same function `Headphones.rendered` calls with Kokoro's samples, so a tone through
			# it travels the identical encode, carry, validate and play path. What is not covered here is the synthesis
			# itself, which `radio_peers` and the export's `--speak-test` already hold.
			var team: int = Net.team_of(Sim.local_client_id()) if argument.substr(8) == "team" else TeamBoard.NOBODY
			var tone := PackedFloat32Array()
			tone.resize(RadioClip.RATE)
			var phase: float = 0.0
			for i in range(tone.size()):
				tone[i] = sin(phase) * 0.4
				phase += TAU * 660.0 / float(RadioClip.RATE)
			var refusal: String = Radio.publish_pcm(tone, RadioClip.RATE, "a tower tone", team)
			print("LOBBY_HANDS tower=%s team=%d sent_to=%d %s" % [argument.substr(8), team, Radio.sent_to,
				"refused: %s" % refusal if not refusal.is_empty() else "published"])
			continue
		if argument.begins_with("--talk="):
			var asked_for: PackedStringArray = argument.substr(7).split(":")
			var audience: int = VoiceFrame.Audience.TEAM if String(asked_for[0]) == "team" else VoiceFrame.Audience.EVERYONE
			var msec: int = String(asked_for[1]).to_int() if asked_for.size() > 1 else 400
			_speak_a_tone(audience, msec)
			continue
		var parts: PackedStringArray = argument.substr(13).split(":")
		var who: String = String(parts[0])
		var times: int = String(parts[1]).to_int() if parts.size() > 1 else 1
		var client: int = _client_called(who)
		if client <= 0 or not _team_buttons.has(client):
			print("LOBBY_HANDS no_row_for=%s listed=%d host=%s" % [who, Net.roster_cards().size(),
				"yes" if Net.is_host else "no"])
			continue
		for i in range(times):
			(_team_buttons[client] as Button).pressed.emit()
		print("LOBBY_HANDS pressed_team_of=%s times=%d now=%d" % [who, times, Net.team_of(client)])


## HOLD THE BUTTON AND SPEAK A TONE FOR `msec`. The tone is a 440 Hz sine at a third of full scale, fed in 20 ms
## pieces on the frame clock, so what the encoder sees is the shape a microphone would have given it. A tone rather than
## noise because a test that asserts on energy should fail on silence and pass on something a person could hear.
func _speak_a_tone(audience: int, msec: int) -> void:
	var why: String = _intercom.start_talking(audience)
	print("LOBBY_HANDS talk=%s for=%dms %s" % ["team" if audience == VoiceFrame.Audience.TEAM else "all", msec,
		"refused: %s" % why if not why.is_empty() else "holding"])
	if not why.is_empty():
		return
	var rate: int = VoiceFrame.RATE
	var per_frame: int = int(rate / 50)
	var frames: int = maxi(1, int(round(float(msec) / 20.0)))
	var phase: float = 0.0
	for f in range(frames):
		var block := PackedFloat32Array()
		block.resize(per_frame)
		for i in range(per_frame):
			block[i] = sin(phase) * 0.33
			# Phase is INTEGRATED, never recomputed from t * frequency: working_with_godot.md, "Synthesising audio".
			phase += TAU * 440.0 / float(rate)
		_intercom.microphone.feed(block, rate)
		await get_tree().process_frame
	_intercom.stop_talking()
	print("LOBBY_HANDS talked_frames=%d mic_frames=%d" % [frames, _intercom.microphone.frames_heard])


## WHICH PLAYER IS CALLED THAT, off the roster, or 0. The names the host publishes are what the rows are labelled with,
## so this is the same answer a person reading the list would give.
func _client_called(name: String) -> int:
	for card in Net.roster_cards():
		if String(card["name"]) == name:
			return int(card["player"])
	return 0


func _say(words: String) -> void:
	if _said_line != null:
		_said_line.text = words
	if not words.is_empty():
		print("[lobby2d] %s" % words)
