extends Control
class_name SessionMenu
## HOW A SESSION IS STARTED: solo, over Steam, or over an address you type in.
##
## THREE VIEWS OF ONE SCREEN, not three panels: the buttons, the keypad a code is typed on (2026-09-14) and the list of
## games somebody else is hosting (2026-09-15). What `Net` says about any of them -- a code refused, a game that filled
## up -- is one line, `_said`, under all three, because an answer is read where the thing it answers was pressed.
##
## An ordinary Control tree, which is the point of `TouchPanel` -- this is authored and read
## like any other Godot UI, and the fact that it will be pressed with a fingertip in a
## headset is not something this file has to know.
##
## It ANNOUNCES rather than acts. Pressing a button emits `chose`, and whoever put the menu
## up decides what that means: the desk in the main menu starts a session and loads the
## world, and the same menu pulled up mid-flight would mean something different. A menu that
## called `Net.host()` itself would be a menu that could only ever be used in one place.
##
## WHICH LEVEL is not asked here any more. It was a row of buttons above "Fly on your own" from the morning of 2026-09-15,
## a button's width each with one summary line under the row, and it moved to a monitor of its own that afternoon
## (`ChartMenu`): the user asked for one, and a third level would have made the row's buttons too narrow to name it.
##
## THE SMALLEST WORDS ARE 20 PX, and the rest scaled with them (2026-09-15). The screen shrank from 62 to 48.5 cm to fit
## three on the desk, and a page pixel became 0.64 headset pixels at the seated eye (tests/builder.gd's 20 px a degree)
## where it had been 0.89: the 16 px line under the title went from 14.2 headset px to 10.2. At 20 it is 12.8, a little
## better than the old desk. Builder's minimum for a word is 20 headset px, which needs 32 px here; see agents.md.

signal chose(what: String, detail: String)

const AMBER := Color(0.95, 0.76, 0.28)
const PALE := Color(0.86, 0.90, 0.92)

var _address: LineEdit = null
var _said: Label = null
var _front: VBoxContainer = null
var _pad: CodePad = null
var _games: GameList = null


func _ready() -> void:
	var back := ColorRect.new()
	back.color = Color(0.06, 0.07, 0.09)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 28.0
	column.offset_top = 22.0
	column.offset_right = -28.0
	column.offset_bottom = -22.0
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	# THE FRONT OF THE SCREEN, and a keypad that takes its place. Two views of one screen rather than a second panel,
	# because the words `Net` says -- `_said`, below both -- have to be under the keypad as much as under the buttons:
	# a code refused is read where it was typed.
	_front = VBoxContainer.new()
	_front.add_theme_constant_override("separation", 10)
	column.add_child(_front)

	var title := Label.new()
	title.text = "COCKPIT"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", AMBER)
	_front.add_child(title)

	var blurb := Label.new()
	blurb.text = "Fly, drive, sail or drive a train. Bring somebody."
	blurb.add_theme_font_size_override("font_size", 20)
	blurb.add_theme_color_override("font_color", PALE.darkened(0.35))
	_front.add_child(blurb)
	_front.add_child(_gap(4))

	_button(_front, "Fly on your own", func(): chose.emit("solo", ""))
	_button(_front, "Host a game", func(): chose.emit("host", ""))
	_button(_front, "Host over Steam", func(): chose.emit("steam", ""))
	# THE TWO WAYS INTO SOMEBODY ELSE'S STEAM GAME, SIDE BY SIDE IN ONE ROW.
	#
	# JOIN BY THE CODE A STEAM HOST READS OUT (asked for on 2026-09-14). The keypad is this screen's own, so a headset
	# types on the same glass it hosts from. LOOK FOR PLAYERS (asked for on 2026-09-15: "can you also add a button to
	# look for other players") is the same thing for a player with nobody to ask a code of.
	#
	# ONE ROW BECAUSE THEY ARE A PAIR, not because of the height: measured on 2026-09-15 (tests/code_pad.gd), the front
	# of this screen wants 610 px of the 716 it has with the longest sentence `Net` says wrapped under it, so a fifth
	# stacked button's 66 px would have fitted. The three above are three different games to be in; these two are one
	# game -- somebody else's -- reached two ways, and a column of five reads as five unrelated choices.
	var ways := HBoxContainer.new()
	ways.add_theme_constant_override("separation", 8)
	_front.add_child(ways)
	for pair in [["Join with a code", func() -> void: show_pad(true)],
			["Look for players", func() -> void: chose.emit("browse", "")]]:
		var way := Button.new()
		way.text = String(pair[0])
		way.custom_minimum_size = Vector2(0.0, 56.0)
		way.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		way.add_theme_font_size_override("font_size", 24)
		way.pressed.connect(pair[1])
		ways.add_child(way)
	_front.add_child(_gap(6))

	var joining := HBoxContainer.new()
	joining.add_theme_constant_override("separation", 8)
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.custom_minimum_size = Vector2(300.0, 54.0)
	_address.add_theme_font_size_override("font_size", 22)
	joining.add_child(_address)
	var go := Button.new()
	go.text = "Join"
	go.custom_minimum_size = Vector2(150.0, 54.0)
	go.add_theme_font_size_override("font_size", 22)
	go.pressed.connect(func(): chose.emit("join", _address.text))
	joining.add_child(go)
	_front.add_child(joining)

	_pad = CodePad.new()
	_pad.visible = false
	_pad.typed.connect(func(code: String): chose.emit("code", code))
	_pad.back.connect(func(): show_pad(false))
	column.add_child(_pad)

	# AND THE LIST OF GAMES, a third view of the one screen for the same reason the keypad is a second: what `Net` says
	# about a game -- that it filled up, that its host has gone -- belongs under the row it is about, and `_said` is
	# under all three.
	_games = GameList.new()
	_games.visible = false
	_games.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_games.chose_game.connect(func(lobby: int): chose.emit("game", str(lobby)))
	_games.again.connect(func(): chose.emit("browse", ""))
	_games.back.connect(func(): show_games(false))
	column.add_child(_games)

	column.add_child(_gap(10))
	_said = Label.new()
	_said.text = ""
	# AS BIG AS THE KEYPAD'S OWN LABEL, asked rather than typed: it is where a refused code is explained, and at the old
	# 15 px it read smaller than the heading over the field it was about.
	_said.add_theme_font_size_override("font_size", CodePad.LABEL_SIZE)
	_said.add_theme_color_override("font_color", AMBER)
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_said)

	# THE WAY OUT OF THE PROGRAM, asked for on 2026-09-13: "make sure that we have a quit button on the main menu to
	# actually quit out of the game." On this screen and not the one beside it, because every button on WHERE TO is a door
	# somewhere, and this is the one that goes nowhere. At the foot, past a gap, and GUARDED like the clipboard's MAIN
	# MENU: the first press only arms it, because a beam swept across a menu is easy to press by accident.
	column.add_child(_gap(16))
	var quit := GuardedButton.new("Quit", "PRESS AGAIN TO QUIT")
	quit.paint(PALE, AMBER)
	quit.custom_minimum_size = Vector2(0.0, 56.0)
	quit.add_theme_font_size_override("font_size", 24)
	quit.meant.connect(func(): chose.emit("quit", ""))
	column.add_child(quit)


## THE KEYPAD IN PLACE OF THE BUTTONS, or the buttons back. The keypad starts empty each time it is shown.
func show_pad(on: bool) -> void:
	if _pad == null:
		return
	if on and _games != null:
		_games.visible = false
	_front.visible = not on
	_pad.visible = on
	if on:
		_pad.clear()
		say("")


func showing_pad() -> bool:
	return _pad != null and _pad.visible


## THE LIST OF GAMES IN PLACE OF THE BUTTONS, or the buttons back. Shown looking for them; whoever put the menu up
## hands the answer over with `list_games`.
func show_games(on: bool) -> void:
	if _games == null:
		return
	if on and _pad != null:
		_pad.visible = false
	_front.visible = not on
	_games.visible = on
	if on:
		_games.looking()


func showing_games() -> bool:
	return _games != null and _games.visible


## WHAT STEAM ANSWERED WITH: `Net.games_listed`'s rows, repeated. The list is only drawn while it is up -- a screen
## showing the buttons has nothing to say about games nobody asked for.
func list_games(games: Array) -> void:
	if _games != null:
		_games.show_games(games)


## The list itself, for whoever needs to ask it what is on show.
func games() -> GameList:
	return _games


## What the session had to say for itself. The menu never decides this; it repeats it.
func say(text: String) -> void:
	if _said != null:
		_said.text = text


func _button(into: VBoxContainer, text: String, when: Callable) -> void:
	var press := Button.new()
	press.text = text
	press.custom_minimum_size = Vector2(0.0, 56.0)
	press.add_theme_font_size_override("font_size", 24)
	press.pressed.connect(when)
	into.add_child(press)


func _gap(height: float) -> Control:
	var space := Control.new()
	space.custom_minimum_size = Vector2(0.0, height)
	return space
