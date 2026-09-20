extends Button
class_name GuardedButton
## A BUTTON WITH A GUARD OVER IT: the first press lifts the guard, the second one means it.
##
## The switch that throws away a session, or the whole game, is pressed by a fingertip or a beam waved at a panel -- a
## good deal easier to brush against than a mouse is to misclick. So one press only ARMS it, the label says so, and a
## few seconds of not meaning it puts the guard back. An aircraft's guarded switch is the same idea for the same reason.
##
## LIFTED OUT OF `ClipboardPage` on 2026-09-14, where the clipboard's MAIN MENU had it as two members and three
## functions, when the desk wanted a QUIT button with exactly the same behaviour. A second copy would have been a second
## `MEANT_IT` to keep in step with the first; this is the one.
##
## IT ANNOUNCES AND DOES NOT ACT. `meant` is emitted on the second press; what that means -- leave the level, quit the
## game -- is the page's business, and the page's owner's after that.

## The second press, inside `MEANT_IT` of the first.
signal meant()

## HOW LONG IT STAYS ARMED, in seconds, counted down on the FRAME CLOCK.
##
## Not `Time.get_ticks_msec`, which is the wall, and the two part company the moment anything drives frames faster or
## slower than real time -- a headless suite at `--fixed-fps 120` runs four seconds of game in a fortieth of a second of
## wall, so a countdown measured against the wall never finishes and the test that asks whether this disarms sits there
## until the deadline kills it.
const MEANT_IT: float = 4.0

var plain_text: String = ""
var armed_text: String = ""
## The board's own two colours unless a page paints it with its own. See `paint`.
var plain_colour: Color = BoardStyle.PALE
var armed_colour: Color = BoardStyle.AMBER

var _armed: bool = false
var _armed_for: float = 0.0


## WHAT IT SAYS, guarded and armed. Shown from the moment it exists, not from `_ready`: the clipboard's MAIN MENU was
## labelled as it was built, before its page was in the tree, and a button with no words until it is added is not
## that.
func _init(plain: String = "", armed: String = "") -> void:
	plain_text = plain
	armed_text = armed
	pressed.connect(_on_pressed)
	_show(false)


## IN A PAGE'S OWN COLOURS, for a page that is not the board's. Shown at once, armed or not.
func paint(plain: Color, armed: Color) -> void:
	plain_colour = plain
	armed_colour = armed
	_show(_armed)


func is_armed() -> bool:
	return _armed


func _on_pressed() -> void:
	if _armed:
		_show(false)
		meant.emit()
		return
	_show(true)
	_armed_for = MEANT_IT


func _process(delta: float) -> void:
	_armed_for -= delta
	if _armed_for <= 0.0:
		_show(false)


## WHAT IT SAYS AND IN WHICH COLOUR.
##
## ARMED IS AMBER IN EVERY STATE A BUTTON CAN BE DRAWN IN, not only its plain one. A hovered Button draws its words in
## `font_hover_color`, and a beam always hovers what it points at, so with only `font_color` overridden the armed words
## came out in the theme's white exactly while somebody was aiming at them (the first picture of Quit, 2026-09-14).
## Disarmed, those overrides are taken off again, so an unarmed button hovers, presses and takes focus as it did.
const ARMED_STATES: Array[StringName] = [&"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color",
	&"font_focus_color"]

func _show(armed: bool) -> void:
	_armed = armed
	set_process(armed)
	text = armed_text if armed else plain_text
	add_theme_color_override("font_color", armed_colour if armed else plain_colour)
	for state in ARMED_STATES:
		if armed:
			add_theme_color_override(state, armed_colour)
		else:
			remove_theme_color_override(state)
