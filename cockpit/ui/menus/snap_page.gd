extends Control
class_name SnapPage
## THE SNAP BOARD'S PAGE: which snaps are on, how fine each is, which axes position snaps on, which of the two the
## joystick works, and a way to put the board back where it started.
##
## Asked for on 2026-09-13: "we might want snap to grid to be for rotation angles, or for x/y/z coordinates. So let's make
## a menu we can bring up for a given device while in creator mode." Three rows and a button, and nothing on it that the
## joystick cannot also reach, so the board and the thumb can never be saying two different things.
##
## A PAGE ANNOUNCES; THE RIG DECIDES. Every control here emits a `chose_*` signal and moves nothing: the rig changes its
## PlacingGrid and hands the grid back through `show_grid`, and the page draws what it was handed. That is ClipboardPage's
## contract, and it is why pressing ROTATION and clicking the joystick in cannot leave the switch showing the wrong one.
##
## ITS SIZES AND COLOURS ARE BoardStyle'S, so it reads like the clipboard it sits beside: the same writing, the same
## size of thing to press.

signal chose_rotation_on(on: bool)
signal chose_rotation_step(by: int)
signal chose_position_on(on: bool)
signal chose_position_step(by: int)
signal chose_axis(axis: int, on: bool)
signal chose_stick(quantity: int)
signal chose_reset_position()

var _rotation_on: CheckButton = null
var _rotation_step: Label = null
var _position_on: CheckButton = null
var _position_step: Label = null
var _axes: Array[Button] = []
var _stick_rotation: Button = null
var _stick_position: Button = null
var _reset: Button = null


func _ready() -> void:
	# EVERY SWITCH ON THIS BOARD WEARS BoardStyle'S, set here once and on no control. See `BoardStyle.theme`.
	theme = BoardStyle.theme()
	var back := ColorRect.new()
	back.color = BoardStyle.BOARD
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 14.0
	column.offset_top = 12.0
	column.offset_right = -14.0
	column.offset_bottom = -12.0
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	# ---- rotation ----
	_rotation_on = _a_switch("ROTATION SNAP", func(on: bool): chose_rotation_on.emit(on))
	column.add_child(_rotation_on)
	var turning: Array = _a_stepper(func(by: int): chose_rotation_step.emit(by))
	column.add_child(turning[0])
	_rotation_step = turning[1]

	# ---- position ----
	_position_on = _a_switch("POSITION SNAP", func(on: bool): chose_position_on.emit(on))
	column.add_child(_position_on)
	var moving: Array = _a_stepper(func(by: int): chose_position_step.emit(by))
	column.add_child(moving[0])
	_position_step = moving[1]
	var axes := HBoxContainer.new()
	axes.add_theme_constant_override("separation", 6)
	for axis in range(3):
		var which: int = axis
		var toggle := Button.new()
		toggle.name = "Axis%s" % ["X", "Y", "Z"][axis]
		toggle.text = ["X", "Y", "Z"][axis]
		toggle.toggle_mode = true
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.custom_minimum_size = Vector2(0.0, BoardStyle.reach(36.0))
		toggle.add_theme_font_size_override("font_size", BoardStyle.pressed_text(18))
		toggle.toggled.connect(func(on: bool): chose_axis.emit(which, on))
		axes.add_child(toggle)
		_axes.append(toggle)
	column.add_child(axes)

	# ---- what the joystick works ----
	var heading := Label.new()
	heading.text = "THE JOYSTICK ADJUSTS"
	heading.add_theme_font_size_override("font_size", BoardStyle.text(15))
	heading.add_theme_color_override("font_color", BoardStyle.DIM)
	column.add_child(heading)
	var either := HBoxContainer.new()
	either.add_theme_constant_override("separation", 6)
	# ONE OF TWO, NEVER BOTH: a ButtonGroup, so the page itself cannot show the stick on rotation and on position at once.
	var group := ButtonGroup.new()
	_stick_rotation = _a_choice("ROTATION", group, func(): chose_stick.emit(PlacingGrid.Quantity.ROTATION))
	_stick_position = _a_choice("POSITION", group, func(): chose_stick.emit(PlacingGrid.Quantity.POSITION))
	either.add_child(_stick_rotation)
	either.add_child(_stick_position)
	column.add_child(either)

	# ---- where the board is ----
	_reset = Button.new()
	_reset.name = "ResetPosition"
	_reset.text = "RESET POSITION"
	_reset.custom_minimum_size = Vector2(0.0, BoardStyle.reach(36.0))
	_reset.add_theme_font_size_override("font_size", BoardStyle.pressed_text(17))
	_reset.pressed.connect(func(): chose_reset_position.emit())
	column.add_child(_reset)


## DRAW THE GRID YOU WERE HANDED. `set_pressed_no_signal` throughout, or drawing the state would look like somebody
## pressing it and send the choice round again.
func show_grid(grid: PlacingGrid) -> void:
	if _rotation_on == null or grid == null:
		return
	_rotation_on.set_pressed_no_signal(grid.rotation_on)
	_rotation_step.text = "%d°" % grid.rotation_step
	_position_on.set_pressed_no_signal(grid.position_on)
	_position_step.text = "%s cm" % String.num(grid.position_step * 100.0, 1)
	_axes[0].set_pressed_no_signal(grid.on_x)
	_axes[1].set_pressed_no_signal(grid.on_y)
	_axes[2].set_pressed_no_signal(grid.on_z)
	_stick_rotation.set_pressed_no_signal(grid.stick_adjusts == PlacingGrid.Quantity.ROTATION)
	_stick_position.set_pressed_no_signal(grid.stick_adjusts == PlacingGrid.Quantity.POSITION)


## THE CONTROL CALLED `named`, for a test aiming a beam at it. Found by name, so a test says "RotationSnap" and not "the
## second child of the column".
func control_named(named: String) -> Control:
	return find_child(named, true, false) as Control


func _a_switch(words: String, said: Callable) -> CheckButton:
	var switch := CheckButton.new()
	switch.name = words.to_pascal_case()
	switch.text = words
	switch.custom_minimum_size = Vector2(0.0, BoardStyle.reach(36.0))
	# AS WIDE AS ITS WORDS AND ITS PILL, from the left, as the clipboard's switches are (2026-09-14): across the whole board
	# the pill stood about 340 px from its words. Nothing else is written beside it here, so it could not be taken for another
	# switch's; it is left-aligned so both boards read the same. See `ClipboardPage._ready`, the row of switches.
	switch.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	switch.add_theme_font_size_override("font_size", BoardStyle.pressed_text(18))
	switch.toggled.connect(said)
	return switch


## A ROW OF − THE STEP +. Returns the row and the label that shows the step.
func _a_stepper(said: Callable) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var finer := Button.new()
	finer.name = "Finer"
	finer.text = "−"
	finer.custom_minimum_size = Vector2(BoardStyle.reach(48.0), BoardStyle.reach(36.0))
	finer.add_theme_font_size_override("font_size", BoardStyle.pressed_text(22))
	finer.pressed.connect(func(): said.call(-1))
	row.add_child(finer)
	var shows := Label.new()
	shows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shows.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shows.add_theme_font_size_override("font_size", BoardStyle.text(20))
	shows.add_theme_color_override("font_color", BoardStyle.PALE)
	row.add_child(shows)
	var coarser := Button.new()
	coarser.name = "Coarser"
	coarser.text = "+"
	coarser.custom_minimum_size = Vector2(BoardStyle.reach(48.0), BoardStyle.reach(36.0))
	coarser.add_theme_font_size_override("font_size", BoardStyle.pressed_text(22))
	coarser.pressed.connect(func(): said.call(1))
	row.add_child(coarser)
	return [row, shows]


func _a_choice(words: String, group: ButtonGroup, said: Callable) -> Button:
	var choice := Button.new()
	choice.name = "Stick%s" % words.capitalize()
	choice.text = words
	choice.toggle_mode = true
	choice.button_group = group
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.custom_minimum_size = Vector2(0.0, BoardStyle.reach(36.0))
	choice.add_theme_font_size_override("font_size", BoardStyle.pressed_text(17))
	choice.pressed.connect(said)
	return choice
