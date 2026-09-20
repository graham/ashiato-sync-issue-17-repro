extends VBoxContainer
class_name GameList
## WHO ELSE IS PLAYING: every cockpit game Steam knows of, one row each, with a JOIN on the ones you can join.
##
## Asked for on 2026-09-15: "can you also add a button to look for other players." The join code (2026-09-14) is for a
## friend who read theirs out to you; this is the other half -- a player with nobody to ask, looking for anybody at all.
##
## IT ANNOUNCES. A row's JOIN emits `chose_game` with the lobby, LOOK AGAIN emits `again` and BACK emits `back`; the
## session screen decides what any of them means, the same way `CodePad` never joins anything itself.
##
## A LISTING, NOT A JUDGE. `Net.look_for_games` reads Steam's answer into rows and works out which can be joined and
## why not (`Net._read_the_games`); this draws what it is handed, in the order it is handed them. A row this page
## decided about would be a second copy of those checks, and the two would disagree the first time one changed.
##
## EVERY GAME IS ON THE LIST, the ones you cannot join with the reason where their JOIN would be. A game missing from
## the list is a bug report about the list; a game that says "The host is on a different build." is an answer.
##
## SIX ROWS AND A MORE BUTTON, rather than a scrolling list. The board in the cockpit scrolls with the thumb of the hand
## holding it (`ClipboardPage.bindings`); a screen standing on the desk has no thumb, and a scroll bar two millimetres
## wide is not something a beam from a seat drags. So the rest are a press away: MORE says which page of how many, and
## wraps round to the first -- so every game on the list is reachable, which is the objection that keeps the crew page
## from paging (`ClipboardPage.MAY_SCROLL`) and is answered here by the button. `ROWS` is what fits, measured.

## Pressed JOIN on a row: put me in that game. The lobby, because a code can be held by two lobbies and a row is one.
signal chose_game(lobby: int)
## Pressed LOOK AGAIN: ask Steam again.
signal again()
## Pressed BACK: away from the list.
signal back()

## HOW MANY GAMES ARE ON SHOW AT ONCE. Measured on the desk's middle screen (tests/code_pad.gd, 2026-09-15) with the
## longest sentence `Net` says wrapped under the list: six rows of `ROW_TALL`, the heading and the three buttons put the
## whole screen at 652 px of the 716 it has, and a seventh at 718. A seventh does not LOOK like it does not fit -- a VBox
## asked for more room than it has shortens its children rather than running off the glass, and Godot clamps a Control's
## size up to its own minimum, so both "the list fits its room" and "the column fits its size" stay true at any number of
## rows. The suite measures what the column ASKS FOR against the glass less its margins, which is the one number that
## does not move. `Net.MOST_LISTED` is how many are held.
const ROWS: int = 6
## How tall a row is: two lines of the smallest words this screen has, so a wrapped refusal does not change the layout.
const ROW_TALL: float = 60.0
## THE SMALLEST WORDS ON THIS SCREEN ARE 20 PX, as `SessionMenu`'s note says, and the rest are scaled with them.
const SMALL: int = 20
const BIG: int = 22

const AMBER := Color(0.95, 0.76, 0.28)
const PALE := Color(0.86, 0.90, 0.92)

var _title: Label = null
var _rows: VBoxContainer = null
var _more: Button = null
## What `show_games` was last handed, and which page of `ROWS` of it is up.
var _games: Array = []
var _page: int = 0


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_title = Label.new()
	_title.text = "Looking for games…"
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", PALE)
	add_child(_title)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_rows)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	add_child(actions)
	for pair in [["BACK", func() -> void: back.emit()], ["LOOK AGAIN", func() -> void: again.emit()]]:
		var action := Button.new()
		action.text = String(pair[0])
		action.custom_minimum_size = Vector2(0.0, 56.0)
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.add_theme_font_size_override("font_size", BIG)
		action.focus_mode = Control.FOCUS_NONE
		action.pressed.connect(pair[1])
		actions.add_child(action)
	_more = Button.new()
	_more.text = "MORE"
	_more.custom_minimum_size = Vector2(0.0, 56.0)
	_more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_more.add_theme_font_size_override("font_size", BIG)
	_more.focus_mode = Control.FOCUS_NONE
	_more.visible = false
	_more.pressed.connect(func() -> void: turn_the_page())
	actions.add_child(_more)


## THE GAMES STEAM ANSWERED WITH, drawn from the first page. A fresh answer starts at the first page on purpose: the
## lobbies are not the same lobbies, and page 3 of a list that has changed under you is a page about nothing.
func show_games(games: Array) -> void:
	_games = games
	_page = 0
	_draw()


## THE NEXT `ROWS` OF THEM, round to the first again after the last.
func turn_the_page() -> void:
	if pages() <= 1:
		return
	_page = (_page + 1) % pages()
	_draw()


func pages() -> int:
	return maxi(1, ceili(float(_games.size()) / float(ROWS)))


## Which page is up, counting from 0, for the tests.
func page_shown() -> int:
	return _page


## WAITING FOR STEAM: the list goes away rather than standing stale, because a row still on the glass is a game still
## being offered, and the answer on its way may not have it in.
func looking() -> void:
	_games = []
	_page = 0
	_draw()
	_title.text = "Looking for games…"


func _draw() -> void:
	for old in _rows.get_children():
		_rows.remove_child(old)
		old.queue_free()
	if _games.is_empty():
		_title.text = "No games found."
		_more.visible = false
		return
	# WHAT THE LIST IS, AND WHICH PAGE -- not how many there are, which `Net` says in the line under it. The first shot
	# (2026-09-15) read "6 game(s)" over "6 game(s), 3 you can join.", which is the same sentence twice.
	_title.text = "Who is playing" if pages() == 1 \
		else "Who is playing · page %d of %d" % [_page + 1, pages()]
	_more.visible = pages() > 1
	for index in range(_page * ROWS, mini((_page + 1) * ROWS, _games.size())):
		_rows.add_child(_a_game(_games[index] as Dictionary))


## ONE GAME: what it is flying and how full it is, the code its host would read out, and a JOIN or the reason there is
## none. The code is on the row because a player who finds a friend's game this way can then pass the code to a third.
func _a_game(game: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "Game%d" % int(game.get("lobby", 0))
	row.custom_minimum_size = Vector2(0.0, ROW_TALL)
	row.add_theme_constant_override("separation", 10)

	var what := Label.new()
	what.name = "What"
	what.text = "%s · %d of %d players" % [String(game.get("level_name", "?")).to_upper(),
		int(game.get("players", 0)), int(game.get("most", 0))]
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	what.size_flags_stretch_ratio = 3.0
	what.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	what.add_theme_font_size_override("font_size", BIG)
	what.add_theme_color_override("font_color", PALE)
	row.add_child(what)

	var code := Label.new()
	code.name = "Code"
	# A lobby with no readable code on it is a game this build could not have made; it is still joinable, and still
	# worth listing, so the column says there is nothing to read out rather than nothing at all.
	code.text = JoinCode.spell(String(game.get("code", ""))) if String(game.get("code", "")) != "" else "no code"
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# NARROWER THAN THE COLUMN BESIDE IT. A code is seven characters and never wraps; a refusal is a sentence, and at
	# 2.0 each "That game is flying nowhere, a level this game does not have." took three lines and stood taller than
	# its row (the first shot, 2026-09-15). At 1.3 against 2.7 it is two.
	code.size_flags_stretch_ratio = 1.3
	code.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	code.add_theme_font_size_override("font_size", BIG)
	code.add_theme_color_override("font_color", AMBER)
	row.add_child(code)

	var why: String = String(game.get("why", ""))
	if why == "":
		var join := Button.new()
		join.name = "Join%d" % int(game.get("lobby", 0))
		join.text = "JOIN"
		join.custom_minimum_size = Vector2(160.0, 52.0)
		join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		join.size_flags_stretch_ratio = 2.7
		join.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		join.add_theme_font_size_override("font_size", BIG)
		join.focus_mode = Control.FOCUS_NONE
		var lobby: int = int(game.get("lobby", 0))
		join.pressed.connect(func() -> void: chose_game.emit(lobby))
		row.add_child(join)
		return row
	var refused := Label.new()
	refused.name = "Why"
	refused.text = why
	refused.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refused.size_flags_stretch_ratio = 2.7
	refused.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	refused.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refused.add_theme_font_size_override("font_size", SMALL)
	refused.add_theme_color_override("font_color", AMBER)
	row.add_child(refused)
	return row
