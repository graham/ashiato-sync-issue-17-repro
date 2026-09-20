extends Control
class_name RosterPage
## The briefing room's identity board. Buttons announce; Net validates and decides.

signal chose(name: String, colour: int)

var field: LineEdit
var swatches: Array[Button] = []
var rows: VBoxContainer
var status: Label
var selected: int = 0


func _ready() -> void:
	var back := ColorRect.new()
	back.color = Color(0.045, 0.055, 0.075)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 20.0
	column.offset_top = 16.0
	column.offset_right = -20.0
	column.offset_bottom = -16.0
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	var title := Label.new()
	title.text = "CREW ROSTER"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", SessionMenu.AMBER)
	column.add_child(title)
	rows = VBoxContainer.new()
	rows.custom_minimum_size.y = 172.0
	column.add_child(rows)
	field = LineEdit.new()
	field.name = "Name"
	field.max_length = Net.NAME_MOST
	field.placeholder_text = "YOUR NAME"
	field.text_submitted.connect(func(_text: String) -> void: submit())
	field.add_theme_font_size_override("font_size", 24)
	column.add_child(field)
	var colours := HBoxContainer.new()
	colours.add_theme_constant_override("separation", 6)
	column.add_child(colours)
	for index in range(PlayerColours.PALETTE.size()):
		var swatch := Button.new()
		swatch.name = "Colour%d" % index
		swatch.text = str(index + 1)
		swatch.custom_minimum_size = Vector2(0.0, 48.0)
		swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swatch.add_theme_color_override("font_color", PlayerColours.PALETTE[index])
		swatch.pressed.connect(func() -> void: selected = index; submit())
		colours.add_child(swatch)
		swatches.append(swatch)
	var keys := GridContainer.new()
	keys.columns = 9
	keys.add_theme_constant_override("h_separation", 3)
	keys.add_theme_constant_override("v_separation", 3)
	column.add_child(keys)
	for symbol in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
		var key := Button.new()
		key.text = symbol
		key.custom_minimum_size = Vector2(0.0, 34.0)
		key.focus_mode = Control.FOCUS_NONE
		key.pressed.connect(func() -> void: type_key(symbol))
		keys.add_child(key)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	for pair in [["DELETE", func() -> void: type_key("")], ["SAVE", func() -> void: submit()]]:
		var button := Button.new()
		button.text = pair[0]
		button.custom_minimum_size = Vector2(0.0, 46.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(pair[1])
		actions.add_child(button)
	status = Label.new()
	status.add_theme_color_override("font_color", SessionMenu.AMBER)
	column.add_child(status)
	var mine: Dictionary = Net.local_card()
	field.text = String(mine["name"])
	selected = int(mine["colour"])
	Net.roster_changed.connect(refresh)
	refresh()


func type_key(symbol: String) -> void:
	field.text = field.text.left(maxi(0, field.text.length() - 1)) if symbol == "" else (field.text + symbol).left(Net.NAME_MOST)
	field.caret_column = field.text.length()


func submit() -> void:
	chose.emit(field.text, selected)


func say(words: String) -> void:
	status.text = words


func refresh() -> void:
	for old in rows.get_children():
		rows.remove_child(old)
		old.queue_free()
	for card in Net.roster_cards():
		var line := Label.new()
		line.text = String(card["name"]).to_upper()
		line.add_theme_font_size_override("font_size", 21)
		line.add_theme_color_override("font_color", PlayerColours.at(int(card["colour"]), int(card["player"])))
		rows.add_child(line)
