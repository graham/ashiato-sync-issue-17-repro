extends Control
class_name ChartMenu
## WHICH LEVEL THE NEXT SESSION FLIES, on a screen of its own at the desk.
##
## Asked for on 2026-09-15: "I'd like to have a monitor so I can choose different levels (since we now have the starter
## island and the terrain level, and we'll probably have more in the future)." Until then the levels were a row of
## buttons squeezed above "Fly on your own" on the session screen, a button's width each and no room for a summary,
## which does not grow past three. This screen gives every level `ChartDrawer` found in `levels/` a row of its own, its
## name and its summary under it, so a folder added there is a row here with no code touched.
##
## Handed its levels and drawn, like the session screen beside it: a press emits `chose` and changes nothing. The desk
## asks `Net.choose_level` and hands the answer back through `show_levels`, and a refusal through `say`.
##
## THE CHOSEN ONE IS AMBER IN EVERY STATE A BUTTON IS DRAWN IN -- hovered, pressed and focused too -- because a beam
## always hovers what it points at, and a colour set only for the plain state vanished exactly while aimed at (the quit
## button, 2026-09-14). Not a toggle: a toggle flips itself on a press, before anyone has decided.
##
## THE SMALLEST WORDS ARE 20 PX, like the session screen's and for its reason (see `SessionMenu`): 12.8 headset px at the
## seated eye. First drawn at 16, which read 10.2.
##
## AND THE PAGE FITS HOWEVER MANY LEVELS THE GAME HAS, which it did not until 2026-09-17. Every row was a fixed 64 px
## button with its summary under it, so the list grew with the folder: the SIXTH level pushed the page 224 px off its
## own glass, `desk_screens` went red on two checks, and the second of them was the interesting one -- a beam aimed at
## a row that was no longer on the screen pressed nothing, so choosing that level silently did nothing at all. A level
## is content, scanned from a folder (building_a_game_here.md, rule 7), so the page has to survive somebody adding one.
##
## THE ROWS SHRINK, AND THEN THE SUMMARIES GO. A row is sized from the room there is and the number of levels, down to
## a floor that keeps the words legible; when even the floor will not fit them all, the summaries are dropped and the
## names alone are listed, because a name you can press beats a description you cannot reach. Rejected: a scroll, which
## a beam has nothing to drag and which would have left rows off the glass anyway; and pages, which hide a level behind
## a button nobody knows to press.

signal chose(id: String)

## The session screen's colours, asked rather than copied, so the three monitors stay one family.
const AMBER := SessionMenu.AMBER
const PALE := SessionMenu.PALE
## Every colour a Button draws its words in. See "THE CHOSEN ONE" above.
const WORD_COLOURS: Array[String] = ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color",
	"font_focus_color"]

## HOW TALL A ROW'S BUTTON MAY BE, and the smallest words it may be drawn with -- 20 px, the floor every page at this
## desk is held to (12.8 headset px at the seated eye).
##
## HOW SHORT A BUTTON CAN ACTUALLY BE IS NOT A NUMBER TYPED HERE: it is whatever the theme makes of that font, and
## `custom_minimum_size` is a floor rather than a cap, so a button asked to be 35 px tall with 28 px words is 44. The
## first version of this assumed 34 and the twelve-level page came out 130 px too tall, because every row was bigger
## than the arithmetic that placed it. `_shortest_row` asks a real Button instead.
const BUTTON_TALLEST: float = 64.0
const WORDS_BIGGEST: int = 28
const WORDS_SMALLEST: int = 20
## What a summary line, the gap inside a row and the gap between rows cost, measured on the desk's own 1024 x 760 page.
const SUMMARY_TALL: float = 26.0
const ROW_INSIDE: float = 2.0
const ROW_APART: float = 14.0
## AND HOW CLOSE ROWS SIT WHEN THE SUMMARIES HAVE GONE. A list of names alone does not need a summary's breathing room,
## and the tighter gap is what lets twelve rows stand at the legible floor instead of eleven.
const ROW_APART_TIGHT: float = 6.0
## WHAT THE PAGE SPENDS ON EVERYTHING THAT IS NOT THE LIST: the title, the blurb, the two gaps, the line at the foot
## and the margins. It is a constant because the list has to be sized BEFORE it is laid out, and it is MEASURED rather
## than added up: the list begins at y = 131 on a 760 px glass, the gap under it is 12, and the line at the foot is 65
## because it wraps to two lines -- which is the part that was got wrong the first time, when 28 was assumed for a
## label that says "Nothing chosen: hosting flies The lobby, on your own flies The island. Joining flies the host's
## level." Three lines of it would be 90, so the reserve is generous by a line.
const ROOM_TAKEN: float = 251.0
## AND A FEW PIXELS THAT ARE NEVER SPENT. Sizing the rows to the last pixel of the room puts the foot of the page
## exactly on the edge of the glass, where a rounded font metric or a themed border is enough to tip it over. Ten
## pixels is cheaper than finding out which.
const ROOM_SLACK: float = 10.0
## The page's own height when it is asked before the layout has happened. DeskRoom draws every screen at 1024 x 760.
const GLASS_TALL: float = 760.0

var _list: VBoxContainer = null
var _said: Label = null
## The button each level id was drawn as, for the look of the chosen one and for a suite to press.
var level_buttons: Dictionary = {}


## THE LEVELS TO OFFER, AND WHICH IS CHOSEN. Each is a `LevelChart`, in the order handed over: `ChartDrawer.charts()`
## puts the default first and the rest by id, so a row does not move when a level is added.
##
## `by_choice` IS WHETHER ANYBODY HAS CHOSEN YET (`Net.level_chosen`), and it is not decoration. Since 2026-09-15 the
## level a session starts on depends on which button is pressed -- hosting starts in the lobby, playing alone on the
## island (`Net.suit_the_session`) -- and this screen cannot know which is coming. So with nothing chosen it marks
## NOTHING as chosen, names the default on each of the two rows it belongs to, and says at the foot what each button
## will fly. Marking `Net.level` anyway would tell a player they had picked the island while HOST was about to fly the
## lobby. `defaults` is {"host": id, "solo": id}, handed over rather than worked out here: this screen draws what it is
## given (building_a_game_here.md, rule 5).
func show_levels(charts: Array, chosen: String, by_choice: bool = true, defaults: Dictionary = {}) -> void:
	if _list == null:
		return
	for old in _list.get_children():
		_list.remove_child(old)
		old.queue_free()
	level_buttons.clear()
	_said.text = ""
	# HOW BIG A ROW CAN BE, from the room there is and the number of levels. See "AND THE PAGE FITS" above.
	var room: float = maxf(size.y, GLASS_TALL) - ROOM_TAKEN - ROOM_SLACK
	var each_row: float = room / float(maxi(charts.size(), 1))
	var shortest: float = _shortest_row()
	var with_summary: float = each_row - ROW_APART - ROW_INSIDE - SUMMARY_TALL
	var summaries: bool = with_summary >= shortest
	var apart: float = ROW_APART if summaries else ROW_APART_TIGHT
	var words: int = WORDS_BIGGEST if summaries else WORDS_SMALLEST
	var button_tall: float = clampf(with_summary if summaries else each_row - apart, shortest, BUTTON_TALLEST)
	_list.add_theme_constant_override("separation", int(apart))
	# AND IF THEY STILL WILL NOT FIT, SAY SO RATHER THAN RUNNING OFF THE GLASS. At the legible floor and the tight gap
	# this page holds about a dozen levels; past that a row would be drawn where nobody could press it, which is how
	# the sixth level broke this screen in the first place. Showing fewer and saying how many were left out is a
	# visible limit; drawing them all and losing the last ones is an invisible one.
	var holds: int = int(floorf(room / (shortest + ROW_APART_TIGHT)))
	var left_out: int = maxi(charts.size() - holds, 0)
	var showing: Array = charts.slice(0, holds) if left_out > 0 else charts
	for each in showing:
		var chart := each as LevelChart
		var id: String = chart.id
		var here: bool = by_choice and id == chosen
		# WHAT THIS ROW IS THE DEFAULT FOR, when nothing has been chosen: one row can be both.
		var stands_for: PackedStringArray = []
		if not by_choice:
			if id == String(defaults.get("host", "")):
				stands_for.append("hosting")
			if id == String(defaults.get("solo", "")):
				stands_for.append("on your own")
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var press := Button.new()
		press.text = "%s   ·   chosen" % chart.name if here else ("%s   ·   %s" % [chart.name,
			" and ".join(stands_for)] if not stands_for.is_empty() else chart.name)
		press.custom_minimum_size = Vector2(0.0, button_tall)
		press.alignment = HORIZONTAL_ALIGNMENT_LEFT
		press.add_theme_font_size_override("font_size", words)
		press.pressed.connect(func(): chose.emit(id))
		row.add_child(press)
		if summaries:
			var about := Label.new()
			about.text = chart.summary
			about.add_theme_font_size_override("font_size", 20)
			about.add_theme_color_override("font_color", AMBER if here else PALE.darkened(0.3))
			# ONE LINE. A wrapped summary makes a row as tall as its longest sentence, which is how the height of this
			# page came to depend on how chatty somebody's level.json was.
			about.clip_text = true
			about.custom_minimum_size = Vector2(0.0, SUMMARY_TALL)
			row.add_child(about)
		if here:
			for colour in WORD_COLOURS:
				press.add_theme_color_override(colour, AMBER)
			_said.text = "The next session flies %s. Joining flies the host's level." % chart.name
		_list.add_child(row)
		level_buttons[id] = press
	if left_out > 0:
		_said.text = "%d levels: this page holds %d. The rest need a bigger screen or pages." % [charts.size(), holds]
		return
	# AND WHEN NOBODY HAS CHOSEN, what each button will do, since no row may claim to be the choice.
	if not by_choice:
		_said.text = "Nothing chosen: %s flies %s, %s flies %s. Joining flies the host's level." % [
			"hosting", _named(charts, String(defaults.get("host", ""))),
			"on your own", _named(charts, String(defaults.get("solo", "")))]


## THE SHORTEST A ROW'S BUTTON CAN BE DRAWN, asked of a real Button with the smallest words this screen allows rather
## than typed as a constant beside them. A theme's padding is not this file's to know, and the number that matters is
## the one the theme will actually enforce (CLAUDE.md, rule 4: ask the authority, do not keep a roster).
func _shortest_row() -> float:
	var probe := Button.new()
	probe.text = "A level"
	probe.add_theme_font_size_override("font_size", WORDS_SMALLEST)
	var tall: float = probe.get_combined_minimum_size().y
	probe.queue_free()
	return maxf(tall, float(WORDS_SMALLEST))


## What a level is called, or its id when this build has not got it.
func _named(charts: Array, id: String) -> String:
	for each in charts:
		if (each as LevelChart).id == id:
			return (each as LevelChart).name
	return id


## Why a choice was refused, in `Net`'s words. The next `show_levels` puts the chosen level's line back.
func say(text: String) -> void:
	if _said != null:
		_said.text = text


func _ready() -> void:
	var back := ColorRect.new()
	back.color = Color(0.06, 0.07, 0.09)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 22.0
	column.offset_top = 18.0
	column.offset_right = -22.0
	column.offset_bottom = -18.0
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	var title := Label.new()
	title.text = "WHICH LEVEL"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", AMBER)
	column.add_child(title)

	var blurb := Label.new()
	blurb.text = "Chosen before a session starts, and kept until you choose again."
	blurb.add_theme_font_size_override("font_size", 20)
	blurb.add_theme_color_override("font_color", PALE.darkened(0.35))
	column.add_child(blurb)
	column.add_child(_gap(8))

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	column.add_child(_list)

	column.add_child(_gap(12))
	_said = Label.new()
	_said.add_theme_font_size_override("font_size", 22)
	_said.add_theme_color_override("font_color", AMBER)
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_said)


func _gap(height: float) -> Control:
	var space := Control.new()
	space.custom_minimum_size = Vector2(0.0, height)
	return space
