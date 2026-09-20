extends Control
class_name LevelMenu
## WHICH PLACE TO GO, as opposed to which session to be in.
##
## The screen beside the session one at the desk. Everything on it was already reachable
## from a command line -- `--level=hall`, `--level=seat --kind=osprey` -- and a command line
## is a poor thing to reach for with a headset on. This is the same list of doors with the
## same names, pressed with a finger.
##
## Two questions, one screen: WHERE, and WHICH CRAFT. The craft only matters to three of the
## doors, so it sits underneath them and stays selected between presses rather than being
## asked for again each time.
##
## Announces rather than acts, like `SessionMenu` next to it: what a button MEANS is the
## room's business, so the same page could sit in a cockpit and mean something else.
##
## THE SMALLEST WORDS ARE 20 PX, like the session screen's and for its reason (see `SessionMenu`): 12.8 headset px at the
## seated eye, where the 14 px craft buttons had read 8.9 after the screens shrank. The doors went from 17 to 24 and the
## rows sit closer, so the whole page still stands on its glass (tests/desk_screens.gd). This is the fullest page on the
## desk. Builder's 20 headset px would need 32 px words here, and at that size the craft picker needs a view of its own.

signal chose(level: String, kind: int)

const AMBER := Color(0.95, 0.76, 0.28)
const PALE := Color(0.86, 0.90, 0.92)

var _kind: int = 0
var _kind_buttons: Array[Button] = []
var _said: Label = null


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
	column.add_theme_constant_override("separation", 5)
	add_child(column)

	var title := Label.new()
	title.text = "WHERE TO"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", AMBER)
	column.add_child(title)

	_door(column, "The world", "world", "everything, flying")
	# THE TOWER: the world with nobody in it and a row of buttons, so a vehicle can be tried out on a MONITOR rather
	# than in a headset -- the user's own reason for asking for it (2026-09-19). Above the craft picker because it
	# commands whatever the camera is already looking at, so it means nothing to this page's chosen craft.
	_door(column, "The tower", "tower", "tell the aircraft what to do, and watch")
	_door(column, "Hall of cockpits", "hall", "every seat in a row, nothing else")
	# THE OTHER JOB. Not flying anything: standing on the ground, moving an aeroplane with
	# your hands. The craft picker below means nothing to these, which is why they sit above
	# it with the world and the hall.
	_door(column, "Carrier deck", "deck", "marshal a jet onto the catapult")
	_door(column, "Airliner stand", "stand", "walk her onto the bar and open the door")
	_door(column, "Signals", "signals", "every marshalling signal, to learn them in")
	column.add_child(_gap(8))

	var which := Label.new()
	which.text = "AND WHICH CRAFT"
	which.add_theme_font_size_override("font_size", 22)
	which.add_theme_color_override("font_color", PALE.darkened(0.3))
	column.add_child(which)

	# EVERY KIND, as a wrapped row of small buttons. Not a dropdown: a popup opens a real
	# window when the panel is a SubViewport with embedded subwindows off, which in a
	# headset is a window you cannot see and cannot dismiss.
	#
	# IN A SCROLLER, SO THIS PAGE STOPS GROWING WITH THE KINDS. The grid wraps, so every kind added here made the page
	# a little taller, and at THIRTY-SEVEN -- the P-47D-30, 2026-09-19 -- it wrapped onto a row that put the bottom
	# label 764 px down a 750 px glass and `tests/desk_screens.gd` went red for a page that had outgrown its screen.
	# A scroller's own minimum height is nothing, so the page's height is now the doors and the labels and never the
	# kinds. It takes whatever room is left (`SIZE_EXPAND_FILL`), which today is more than the grid wants, so nothing
	# scrolls and the page looks exactly as it did.
	var scroller := ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	for kind in range(Sim.Kind.size()):
		var pick := Button.new()
		pick.text = Sim.kind_name(kind)
		pick.custom_minimum_size = Vector2(0.0, 38.0)
		pick.add_theme_font_size_override("font_size", 20)
		pick.toggle_mode = true
		pick.button_pressed = kind == _kind
		var chosen: int = kind
		pick.pressed.connect(func(): _pick(chosen))
		grid.add_child(pick)
		_kind_buttons.append(pick)
	scroller.add_child(grid)
	column.add_child(scroller)
	column.add_child(_gap(6))

	_door(column, "One cockpit, on a bench", "seat", "with the physics running")
	# LAYING A COCKPIT OUT, straight from the menu. The same bench, with the builder switched on and the
	# board open at BUILD: grab a control to move it, add parts from the list, SAVE writes it as JSON.
	_door(column, "Build a cockpit", "build", "move the controls, then SAVE it as JSON")
	_door(column, "The whole crew of one", "crew", "every seat, no physics")
	_door(column, "One craft flying itself", "fly", "watched from outside, in trim")

	column.add_child(_gap(6))
	_said = Label.new()
	_said.text = "Craft: %s" % Sim.kind_name(_kind)
	_said.add_theme_font_size_override("font_size", 20)
	_said.add_theme_color_override("font_color", AMBER)
	column.add_child(_said)


func _pick(kind: int) -> void:
	_kind = kind
	for i in range(_kind_buttons.size()):
		_kind_buttons[i].button_pressed = i == kind
	if _said != null:
		_said.text = "Craft: %s" % Sim.kind_name(kind)


func _door(into: VBoxContainer, text: String, level: String, note: String) -> void:
	var press := Button.new()
	press.text = "%s   ·   %s" % [text, note]
	press.custom_minimum_size = Vector2(0.0, 42.0)
	press.add_theme_font_size_override("font_size", 24)
	press.alignment = HORIZONTAL_ALIGNMENT_LEFT
	press.pressed.connect(func(): chose.emit(level, _kind))
	into.add_child(press)


func _gap(height: float) -> Control:
	var space := Control.new()
	space.custom_minimum_size = Vector2(0.0, height)
	return space
