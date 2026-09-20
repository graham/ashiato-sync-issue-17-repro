extends Node
## Headless: can a join code be typed on the desk's session screen -- with a fingertip or the beam in a headset, with a
## keyboard on a desk -- and does pressing JOIN join, or say why not where the player is looking?
##
##   Godot --headless --path cockpit res://tests/code_pad.tscn
##
## Asked for on 2026-09-14: "a join code for steam players so they can join a game via a join code rather than having
## to be invited or searching for a game."
##
## THROUGH THE RIG'S SEAMS, the way tests/desk_screens.gd presses the desk: `force_hand` puts the right hand in front of
## a key and `force_input` pulls its trigger, so every key press arrives the way a headset's does. Keys typed on a
## keyboard arrive as `InputEventKey` with both `keycode` and `physical_keycode` set (CLAUDE.md, rule 9), through
## `Input.parse_input_event`, which is where a real keyboard's events enter too.
##
## ON PAPER, like tests/steam_join.gd, and it survives its own scene change the same way: JOIN flies into the world.
##
## Read RESULT=, not the exit code.

const HAND_OFF: float = 0.30
const PATIENCE: int = 600
## THIS CHECKOUT'S PORTS (`TestPorts`), each asked silently at load whether anything holds it: fixed numbers were the
## same sockets in every lane. One held, and the suite says PORT BUSY at once rather than timing out.
static var JOIN_PORT: int = TestPorts.first_free(47964, 1)
## The port the game joined off the LIST is carried on. Off every other suite's, as the note on `JOIN_PORT` says.
static var BROWSE_PORT: int = TestPorts.first_free(47965, 1)
const CODE: String = "K7MQ2X"
## The code on the game this suite joins off the list; a different one, so a row's code cannot be confused with the
## keypad's.
const LISTED_CODE: String = "R4TN8W"
const THEIR_HOST: int = 76561190000000900

var _failures: PackedStringArray = []
var _sections: int = 0
var _desk: DeskRoom = null
var _rig: PilotRig = null
var _sessions: TouchPanel = null
var _menu: SessionMenu = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[code_pad] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if JOIN_PORT == 0 or BROWSE_PORT == 0:
		print("RESULT=FAIL port_busy %s" % (TestPorts.busy(47964, 1) + " / " + TestPorts.busy(47965, 1)))
		get_tree().quit(1)
		return
	if get_tree().current_scene != self:
		_run()
		return
	var watcher := Node.new()
	watcher.name = "CodePadWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	var no_steam := PaperLobbyDirectory.new()
	no_steam.said_unavailable = "Steam is not in this build."
	await _sit_at_the_desk(no_steam)
	if _menu == null:
		_finish()
		return
	await _the_session_screen_opens_a_keypad_of_every_symbol_a_code_has()
	await _keys_pressed_with_the_beam_spell_the_code_and_no_more()
	await _a_keyboard_types_into_the_field_and_into_nothing_else()
	await _a_code_refused_is_said_on_the_pad_and_the_pad_stays()
	await _a_code_typed_on_the_pad_joins_and_flies()
	await _a_look_round_lists_who_is_playing_and_a_row_joins_one()
	_check("every_section_of_the_suite_ran", _sections == 6, "%d of 6" % _sections)
	_finish()


## SIT DOWN AT THE DESK with `paper` standing where Steam stands. Called again by the last section, which starts from
## the world the one before it flew into.
func _sit_at_the_desk(paper: PaperLobbyDirectory) -> void:
	Net.lobbies = paper
	get_tree().change_scene_to_file("res://world/desk.tscn")
	for i in range(PATIENCE):
		await get_tree().process_frame
		if get_tree().current_scene is DeskRoom:
			break
	await _frames(6)
	_desk = get_tree().current_scene as DeskRoom
	_rig = _desk.get("_rig") as PilotRig if _desk != null else null
	_sessions = _desk.get("_panel") as TouchPanel if _desk != null else null
	_menu = _sessions.shown() as SessionMenu if _sessions != null else null
	_check("the_desk_has_a_rig_and_a_session_screen", _rig != null and _menu != null, "rig %s, menu %s" % [_rig, _menu])


## ---- 1 ----------------------------------------------------------------------------------------------------------------

func _the_session_screen_opens_a_keypad_of_every_symbol_a_code_has() -> void:
	# THE BUTTONS FIT, WITH THE LONGEST THING `Net` SAYS WRAPPED UNDER THEM. The front of this screen gained a button on
	# 2026-09-15 ("Look for players") and is the one view here that nothing else measured.
	_menu.say("That game is flying %s, a level this game does not have." % Net.level)
	await _frames(4)
	var front_column := _menu.find_children("*", "CodePad", true, false)[0].get_parent() as Control
	var glass := _sessions.get("_screen") as SubViewport
	var front_wants: float = front_column.get_combined_minimum_size().y
	var front_room: float = float(glass.size.y) + front_column.offset_bottom - front_column.offset_top
	_check("the_session_screen_fits_its_buttons_with_the_longest_refusal_under_them", front_wants <= front_room + 0.5,
		"%.0f px wanted in %.0f px" % [front_wants, front_room])
	_menu.say("")
	await _frames(2)
	var open := _button("Join with a code")
	_check("the_session_screen_has_a_join_with_a_code_button", open != null, "%s" % [open])
	if open == null:
		_sections += 1
		return
	await _pull_on(open)
	var pad: Control = _pad()
	_check("and_one_pull_on_it_shows_a_keypad", pad != null and pad.is_visible_in_tree()
		and _button("Host over Steam") == null, "pad %s" % [pad])
	var symbols: String = ""
	var screen := _sessions.get("_screen") as SubViewport
	var off_the_glass: PackedStringArray = []
	for key in _keys():
		symbols += key.text
		if not Rect2(Vector2.ZERO, Vector2(screen.size)).encloses(key.get_global_rect()):
			off_the_glass.append(key.text)
	_check("with_a_key_for_every_symbol_a_code_has_and_no_other", symbols == JoinCode.ALPHABET,
		"'%s'" % symbols)
	var join := _button("JOIN")
	_check("and_every_key_and_JOIN_on_the_glass", off_the_glass.is_empty() and join != null
		and Rect2(Vector2.ZERO, Vector2(screen.size)).encloses(join.get_global_rect()), "off %s" % [off_the_glass])
	_sections += 1


## ---- 2 ----------------------------------------------------------------------------------------------------------------

func _keys_pressed_with_the_beam_spell_the_code_and_no_more() -> void:
	await _pull_on(_button("CLEAR"))
	for symbol in CODE + "Z":
		await _pull_on(_key(symbol))
	_check("six_keys_pulled_spell_the_code_as_it_is_shown_and_a_seventh_is_not_taken",
		_shown() == JoinCode.spell(CODE), "'%s'" % _shown())
	await _pull_on(_button("DELETE"))
	_check("and_delete_takes_the_last_one_off", _shown() == JoinCode.spell(CODE.substr(0, 5)), "'%s'" % _shown())
	await _pull_on(_key(CODE[5]))
	_sections += 1


## ---- 3 ----------------------------------------------------------------------------------------------------------------

## A KEYBOARD, ON A DESK. The field takes focus from a pull, and then the keys: lower case and a dash, which JoinCode
## folds. And an M typed into the field must not raise the clipboard, which the rig polls M for.
func _a_keyboard_types_into_the_field_and_into_nothing_else() -> void:
	await _pull_on(_button("CLEAR"))
	var field := _field()
	await _pull_on(field)
	_check("a_pull_on_the_code_field_gives_it_focus", field != null and field.has_focus(), "focus %s" %
		[field.has_focus() if field != null else "no field"])
	var board_was: bool = _rig.clipboard.is_up()
	for c in "k7m-q2x":
		await _type(c)
	_check("and_a_keyboard_then_types_into_it", _shown().to_upper() == "K7M-Q2X", "'%s'" % _shown())
	_check("and_while_it_does_the_m_does_not_raise_the_clipboard", _rig.clipboard.is_up() == board_was,
		"board up %s, was %s" % [_rig.clipboard.is_up(), board_was])
	_check("and_the_panel_says_somebody_is_typing", TouchPanel.is_typing(), "typing %s" % TouchPanel.is_typing())

	# THE ADDRESS FIELD HAD THE SAME GAP, and is fixed by the same keys.
	await _pull_on(_button("BACK"))
	var address := _address()
	await _pull_on(address)
	var before: String = address.text if address != null else ""
	for c in ".9":
		await _type(c)
	_check("and_the_address_field_takes_keys_too", address != null and address.text.length() == before.length() + 2,
		"'%s' after '%s'" % [address.text if address != null else "", before])
	await _pull_on(_button("Join with a code"))
	_sections += 1


## ---- 4 ----------------------------------------------------------------------------------------------------------------

func _a_code_refused_is_said_on_the_pad_and_the_pad_stays() -> void:
	await _pull_on(_button("CLEAR"))
	for symbol in CODE.substr(0, 5):
		await _pull_on(_key(symbol))
	await _pull_on(_button("JOIN"))
	await _frames(10)
	var words: String = JoinCode.why_not(CODE.substr(0, 5))
	_check("a_short_code_joined_is_refused_in_words_on_the_screen", _said_on_screen(words), "wanted '%s'" % words)
	_check("and_the_player_is_still_at_the_pad_to_fix_it", get_tree().current_scene == _desk and _pad() != null
		and _pad().is_visible_in_tree() and not bool(_desk.get("_going")), "going %s" % _desk.get("_going"))

	await _pull_on(_key(CODE[5]))
	await _pull_on(_button("JOIN"))
	await _frames(10)
	_check("and_a_whole_code_with_no_steam_says_so", _said_on_screen("Steam is not in this build."), "")
	_sections += 1


## ---- 5 ----------------------------------------------------------------------------------------------------------------

func _a_code_typed_on_the_pad_joins_and_flies() -> void:
	var paper := PaperLobbyDirectory.new()
	Net.lobbies = paper
	for stage in Net.PATIENCE:
		Net.patience[stage] = 2.0
	var server := ENetMultiplayerPeer.new()
	server.create_server(JOIN_PORT, Net.MAX_PLAYERS)
	paper.put({"game": Net.GAME_TAG, "code": CODE, "build": Net.build(), "compatibility": Net.compatibility(),
		"host": str(THEIR_HOST),
		"level": Net.level, "level_hash": ChartDrawer.chart(Net.level).content_hash}, 1, Net.MAX_PLAYERS,
		THEIR_HOST, JOIN_PORT)
	await _pull_on(_button("CLEAR"))
	for symbol in CODE:
		await _pull_on(_key(symbol))
	await _pull_on(_button("JOIN"))
	var flew: bool = false
	for i in range(PATIENCE):
		server.poll()
		_answer_as_the_host()
		if get_tree().current_scene is FlightLevel:
			flew = true
			break
		await get_tree().physics_frame
	_check("the_code_typed_on_the_pad_joins_that_game_and_the_desk_flies_into_it",
		flew and Net.transport == "steam" and Net.session_code == CODE and not Net.is_host,
		"flew %s, transport %s, code '%s'" % [flew, Net.transport, Net.session_code])
	Sim.stop()
	Net.leave("suite")
	for i in range(10):
		server.poll()
		await get_tree().physics_frame
	server.close()
	_sections += 1


## ---- 6 ----------------------------------------------------------------------------------------------------------------

## LOOK FOR OTHER PLAYERS: the button, the list Steam answers with, the games on it that cannot be joined saying why,
## the page of the rest, and a JOIN on a row landing in that game.
##
## Asked for on 2026-09-15: "can you also add a button to look for other players."
##
## EIGHT LOBBIES on paper, four of them nothing this build could join, so the list has both kinds and runs to a second
## page -- `GameList.ROWS` is six. The one that IS joined is carried on a real ENet socket, as section 5's is, so the
## press goes all the way from the beam through `Net.join_game` into a session.
func _a_look_round_lists_who_is_playing_and_a_row_joins_one() -> void:
	var paper := PaperLobbyDirectory.new()
	var server := ENetMultiplayerPeer.new()
	server.create_server(BROWSE_PORT, Net.MAX_PLAYERS)
	# THE ONE WORTH JOINING, and the fullest, so it sorts to the top of the list.
	var theirs: int = paper.put(_lobby(LISTED_CODE, Net.level, Net.build()), 3, Net.MAX_PLAYERS, THEIR_HOST,
		BROWSE_PORT)
	# AND FOUR MORE THAT COULD BE JOINED, which is what makes the list longer than a page.
	for i in range(4):
		paper.put(_lobby("AAAAA%s" % JoinCode.ALPHABET[i], Net.level, Net.build()), 1, Net.MAX_PLAYERS, THEIR_HOST, 0)
	# AND THREE THAT COULD NOT, each for a different reason, each of which the row has to say.
	var full: int = paper.put(_lobby("BBBBBB", Net.level, Net.build()), Net.MAX_PLAYERS, Net.MAX_PLAYERS, THEIR_HOST, 0)
	var behind: int = paper.put(_lobby("CCCCCC", Net.level, "a release behind"), 1, Net.MAX_PLAYERS, THEIR_HOST, 0)
	var nowhere: int = paper.put(_lobby("DDDDDD", "nowhere", Net.build()), 1, Net.MAX_PLAYERS, THEIR_HOST, 0)
	# A LOBBY OF SOMEBODY ELSE'S GAME, which must not be on the list at all: the search is filtered on the game's tag.
	paper.put({"game": "somebody_else", "code": "EEEEEE"}, 1, 8, THEIR_HOST, 0)
	for stage in Net.PATIENCE:
		Net.patience[stage] = 2.0
	await _sit_at_the_desk(paper)
	if _menu == null:
		_sections += 1
		return

	var look := _button("Look for players")
	_check("the_session_screen_has_a_look_for_players_button", look != null, "%s" % [look])
	if look == null:
		_sections += 1
		return
	await _pull_on(look)
	_check("and_one_pull_on_it_puts_a_list_in_place_of_the_buttons", _menu.showing_games()
		and _button("Host over Steam") == null, "showing %s" % _menu.showing_games())
	await _frames(10)
	_check("and_it_asked_steam_for_this_games_lobbies_and_not_for_a_code",
		paper.searches == [{"game": Net.GAME_TAG}], "searched %s" % [paper.searches])

	# WHAT IS ON THE LIST. Eight of this game's lobbies and none of anybody else's, the joinable ones first.
	var list: GameList = _menu.games()
	_check("it_lists_every_cockpit_game_and_no_other_games_lobby", list != null and _games_shown(list).size() == 8
		and _pages(list) == 2, "%d games on %d page(s)" % [_games_shown(list).size() if list != null else -1,
			_pages(list) if list != null else -1])
	_check("and_the_one_with_the_most_players_that_can_be_joined_is_the_first_row",
		_row_words(0).contains("3 of %d players" % Net.MAX_PLAYERS)
			and _row_words(0).contains(JoinCode.spell(LISTED_CODE)) and _join_on_row(0) != null,
		"'%s'" % _row_words(0))
	# AND THE ONES THAT CANNOT BE JOINED SAY WHY, with no JOIN to press.
	_check("and_a_full_game_says_so_with_no_join_to_press", _row_words(5).contains("Full.")
		and _join_on_row(5) == null and _row_words(5).contains("%d of %d players" % [Net.MAX_PLAYERS, Net.MAX_PLAYERS]),
		"row 6 of page 1: '%s'" % _row_words(5))
	var reasons: PackedStringArray = []
	for index in range(_rows_shown().size()):
		reasons.append(_row_words(index))
	await _pull_on(_button("MORE"))
	await _frames(4)
	_check("and_more_turns_to_the_rest_of_them", list != null and list.page_shown() == 1
		and _rows_shown().size() == 2, "page %d, %d rows" % [list.page_shown() if list != null else -1,
			_rows_shown().size()])
	var second: String = "%s %s" % [_row_words(0), _row_words(1)]
	_check("and_the_two_that_could_not_be_joined_say_which_and_why",
		second.contains("The host is on a different build.") and second.contains("a level this game does not have"),
		"'%s'" % second)
	_check("and_nothing_on_the_second_page_offers_a_join", _join_on_row(0) == null and _join_on_row(1) == null,
		"builds %d, nowhere %d" % [behind, nowhere])
	# AND ROUND TO THE FIRST AGAIN, so every game on the list is reachable with one button.
	await _pull_on(_button("MORE"))
	await _frames(4)
	_check("and_more_again_comes_back_to_the_first_page", list != null and list.page_shown() == 0
		and _row_words(0).contains(JoinCode.spell(LISTED_CODE)), "page %d" % [list.page_shown() if list != null else -1])

	# NOTHING OFF THE GLASS, AT THE FULLEST THIS SCREEN EVER IS: a full page of rows, the heading and three buttons, with
	# the longest sentence `Net` says under them. The refusal line wraps to two at that length, and those 33 px are the
	# difference between a list that fits and one that squeezes Quit -- so they are measured rather than hoped for.
	_menu.say("That game is flying %s, a level this game does not have." % Net.level)
	await _frames(4)
	var screen := _sessions.get("_screen") as SubViewport
	var off: PackedStringArray = []
	for node in _menu.find_children("*", "Control", true, false):
		var control := node as Control
		if control.is_visible_in_tree() and not Rect2(Vector2.ZERO, Vector2(screen.size)).encloses(
				control.get_global_rect()):
			off.append("%s '%s' %s" % [control.get_class(), String(control.get("text")), control.get_global_rect()])
	# AND THE MEASUREMENT, printed whether it passes or not, because `GameList.ROWS` is a number somebody will want to
	# raise one day and the only honest answer to "can it be seven?" is how much room is left at six.
	# THE WHOLE COLUMN, not the list alone: a VBox given less than it asks for takes the difference off ALL its children,
	# so the list's own room GROWS as it squeezes the refusal line and Quit below it, and "the list fits its room" is
	# true at any number of rows.
	#
	# AND THE ROOM IS WORKED OUT FROM THE GLASS AND THE COLUMN'S MARGINS, not read off `size`: Godot clamps a Control's
	# size UP to its own minimum, so a column that wants more than the screen reports a size that has grown to match --
	# `wants` and `size.y` were both 718 at seven rows, which is not a measurement, it is the same number twice.
	var column := list.get_parent() as Control if list != null else null
	var wants: float = column.get_combined_minimum_size().y if column != null else 0.0
	var room: float = float(screen.size.y) + column.offset_bottom - column.offset_top if column != null else 0.0
	_check("and_the_whole_list_is_on_the_glass_with_the_way_out_under_it", off.is_empty(),
		"off the glass: %s (glass %d px)" % [", ".join(off.slice(0, 4)), screen.size.y])
	# AND NOTHING IS SQUEEZED TO MAKE IT FIT. A VBox given less than it asks for shortens its children rather than
	# running off the glass, so the edges alone passed at seven rows (2026-09-15); this is what says six.
	_check("and_the_screen_asks_for_no_more_room_than_it_has", wants <= room + 0.5,
		"%.0f px wanted in %.0f px, at %d rows" % [wants, room, GameList.ROWS])

	# AND A ROW'S JOIN JOINS THAT GAME. The real path: the beam, the button, `Net.join_game`, a socket, the world.
	await _pull_on(_join_on_row(0))
	var flew: bool = false
	for i in range(PATIENCE):
		server.poll()
		_answer_as_the_host()
		if get_tree().current_scene is FlightLevel:
			flew = true
			break
		await get_tree().physics_frame
	_check("a_join_on_a_row_joins_that_game_and_the_desk_flies_into_it",
		flew and Net.transport == "steam" and not Net.is_host and Net.session_code == LISTED_CODE
			and Net.lobby == theirs,
		"flew %s, transport %s, code '%s', lobby %d of %d" % [flew, Net.transport, Net.session_code, Net.lobby, theirs])
	_check("and_the_lobby_it_pressed_is_the_one_it_entered", paper.entries == [theirs] and paper.members(theirs) == 4,
		"entered %s, %d members, full was %d" % [paper.entries, paper.members(theirs), full])
	Sim.stop()
	Net.leave("suite")
	for i in range(10):
		server.poll()
		await get_tree().physics_frame
	server.close()
	_sections += 1


## A LOBBY AS SOMEBODY ELSE'S HOST WOULD HAVE WRITTEN IT. The level's hash is read off this game's own chart, so a level
## it does have is one it agrees about.
func _lobby(code: String, level: String, build: String) -> Dictionary:
	var chart: LevelChart = ChartDrawer.chart(level)
	return {"game": Net.GAME_TAG, "code": code, "build": build, "compatibility": Net.compatibility(),
		"host": str(THEIR_HOST), "level": level,
		"level_hash": chart.content_hash if chart != null else ""}


func _games_shown(list: GameList) -> Array:
	return list.get("_games") as Array


func _pages(list: GameList) -> int:
	return list.pages()


## THE ROWS ON THE PAGE THAT IS UP, in the order they are drawn.
func _rows_shown() -> Array:
	var list: GameList = _menu.games() if _menu != null else null
	if list == null:
		return []
	var rows: Array = []
	for node in (list.get("_rows") as Control).get_children():
		if (node as Control).is_visible_in_tree():
			rows.append(node)
	return rows


## Every word on a row, run together, so a check can ask what it says without knowing which label holds which part.
func _row_words(index: int) -> String:
	var rows: Array = _rows_shown()
	if index >= rows.size():
		return ""
	var said: PackedStringArray = []
	for node in (rows[index] as Control).find_children("*", "Label", true, false):
		said.append((node as Label).text)
	return " · ".join(said)


func _join_on_row(index: int) -> Button:
	var rows: Array = _rows_shown()
	if index >= rows.size():
		return null
	for node in (rows[index] as Control).find_children("*", "Button", true, false):
		if (node as Button).text == "JOIN":
			return node as Button
	return null


## ---- the machinery ------------------------------------------------------------------------------------------------------

func _pad() -> Control:
	var found: Array = _menu.find_children("*", "CodePad", true, false)
	return found[0] as Control if not found.is_empty() else null


func _keys() -> Array[Button]:
	var out: Array[Button] = []
	var pad := _pad()
	if pad == null:
		return out
	for node in pad.find_children("*", "Button", true, false):
		var b := node as Button
		if b.text.length() == 1 and b.is_visible_in_tree():
			out.append(b)
	return out


func _key(symbol: String) -> Button:
	for key in _keys():
		if key.text == symbol:
			return key
	return null


func _field() -> LineEdit:
	var pad := _pad()
	if pad == null:
		return null
	var found: Array = pad.find_children("*", "LineEdit", true, false)
	return found[0] as LineEdit if not found.is_empty() else null


## THE ADDRESS FIELD: any visible text field that is not the keypad's. Not waiting on a keypad existing, because whether
## the address field could ever be typed into is its own question, and it was asked on a screen with no keypad at all.
func _address() -> LineEdit:
	var pad := _pad()
	for node in _menu.find_children("*", "LineEdit", true, false):
		if (node as LineEdit).is_visible_in_tree() and (pad == null or not pad.is_ancestor_of(node)):
			return node as LineEdit
	return null


func _shown() -> String:
	var field := _field()
	return field.text if field != null else ""


func _said_on_screen(words: String) -> bool:
	for node in _menu.find_children("*", "Label", true, false):
		if (node as Label).is_visible_in_tree() and (node as Label).text == words:
			return true
	return false


func _button(words: String) -> Button:
	for node in _menu.find_children("*", "Button", true, false):
		if (node as Button).is_visible_in_tree() and (node as Button).text == words:
			return node as Button
	return null


## ONE PULL OF THE RIGHT TRIGGER WITH THE BEAM ON `target`, worked out from its own rectangle on the page.
func _pull_on(target: Control) -> void:
	if target == null:
		_check("there_is_something_to_pull_on", false, "a control this suite looked for is not on the screen")
		return
	var screen := _sessions.get("_screen") as SubViewport
	var pixel: Vector2 = target.get_global_rect().get_center()
	var on_glass := Vector3((pixel.x / float(screen.size.x) - 0.5) * _sessions.size.x,
		(0.5 - pixel.y / float(screen.size.y)) * _sessions.size.y, 0.0)
	var aimed_at: Vector3 = _sessions.to_global(on_glass)
	var hand_at: Vector3 = aimed_at + _sessions.global_basis.z.normalized() * HAND_OFF
	_rig.force_hand(1, Transform3D(Basis.looking_at(aimed_at - hand_at, _sessions.global_basis.y.normalized()), hand_at))
	await _frames(2)
	_rig.force_input(1, Bind.TRIGGER, 1.0)
	await _frames(2)
	_rig.force_input(1, Bind.TRIGGER, 0.0)
	await _frames(2)
	_rig.force_input(1, Bind.TRIGGER, null)


## ONE KEY DOWN AND UP ON A KEYBOARD, with `keycode`, `physical_keycode` and the character it types.
func _type(c: String) -> void:
	var code: Key = OS.find_keycode_from_string(c.to_upper()) if c != "-" and c != "." else (KEY_MINUS if c == "-" else KEY_PERIOD)
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.unicode = c.unicode_at(0) if down else 0
		key.pressed = down
		Input.parse_input_event(key)
		await _frames(1)


func _frames(how_many: int) -> void:
	for i in range(how_many):
		await get_tree().process_frame


func _finish() -> void:
	Sim.stop()
	Net.leave("suite over")
	Net.lobbies = SteamLobbyDirectory.new()
	Net.patience = Net.PATIENCE.duplicate()
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## THE HOST'S HELLO, said for a host that is a bare socket. A real host names its level before a joiner is in the
## session (Net's "THE HELLO"); this one cannot speak, so the suite says it for it once the joiner is waiting.
func _answer_as_the_host() -> void:
	if Net.transport != "none" and not Net.is_in_session and String(Net.get("_stage")) == "hello":
		var chart: LevelChart = ChartDrawer.chart(Net.level)
		Net.hear_hello(1, JSON.stringify({"say": "level", "protocol": Net.PROTOCOL, "level": chart.id,
			"hash": chart.content_hash, "name": chart.name}).to_utf8_buffer())
