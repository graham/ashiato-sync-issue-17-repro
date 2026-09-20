extends Control
class_name BuilderMenu

signal chose_craft(kind: int)
signal chose_version(version: String)
signal chose_save()
signal chose_board(seat: int)
signal toggled_model_layer(layer: StringName, shown: bool)

const AMBER := Color(0.95, 0.66, 0.18)
const PALE := Color(0.82, 0.86, 0.90)
var craft_buttons: Dictionary = {}
var version_edit: LineEdit = null
var _said: Label = null
var _front: VBoxContainer = null
var _pad: VersionPad = null


func _ready() -> void:
	var back := ColorRect.new()
	back.color = Color(0.05, 0.06, 0.08)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 22; column.offset_top = 18; column.offset_right = -22; column.offset_bottom = -18
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title := Label.new(); title.text = "COCKPIT BUILDER"; title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", AMBER); column.add_child(title)
	_front = VBoxContainer.new(); _front.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(_front)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; _front.add_child(scroll)
	var kinds := GridContainer.new(); kinds.columns = 3; kinds.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(kinds)
	for kind in VehicleCatalogue.pilotable_kinds():
		if kind == Sim.Kind.SEGWAY: continue
		var button := Button.new(); button.text = Sim.kind_name(kind).to_upper(); button.custom_minimum_size = Vector2(0, 48); button.toggle_mode = true
		button.pressed.connect(func(): chose_craft.emit(kind)); kinds.add_child(button); craft_buttons[kind] = button
	var row := HBoxContainer.new(); _front.add_child(row)
	var label := Label.new(); label.text = "VERSION"; label.add_theme_font_size_override("font_size", 22); row.add_child(label)
	version_edit = LineEdit.new(); version_edit.text = CraftPackage.DEFAULT_VERSION; version_edit.max_length = BuilderAuthority.MOST_VERSION_BYTES
	version_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; version_edit.editable = false; row.add_child(version_edit)
	var rename := Button.new(); rename.text = "CHANGE"; rename.pressed.connect(func(): show_pad(true)); row.add_child(rename)
	var save := Button.new(); save.text = "SAVE ALL SEATS"; save.custom_minimum_size = Vector2(0, 52); save.pressed.connect(func(): chose_save.emit()); _front.add_child(save)
	var layers := HBoxContainer.new(); _front.add_child(layers)
	for layer in [&"exterior", &"interior", &"overlays"]:
		var toggle := Button.new(); toggle.text = String(layer).to_upper(); toggle.toggle_mode = true
		toggle.button_pressed = true; toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.toggled.connect(func(shown: bool): toggled_model_layer.emit(layer, shown))
		layers.add_child(toggle)
	var seats := GridContainer.new(); seats.name = "Seats"; seats.columns = 4; _front.add_child(seats)
	for seat in range(offered_seat_capacity()):
		var board := Button.new(); board.name = "Seat%d" % seat; board.text = "BOARD %d" % (seat + 1)
		board.custom_minimum_size = Vector2(0, 46); board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		board.pressed.connect(func(): chose_board.emit(seat)); seats.add_child(board)
	_pad = VersionPad.new(); _pad.visible = false; _pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pad.applied.connect(func(text: String): chose_version.emit(text); show_pad(false)); _pad.back.connect(func(): show_pad(false)); column.add_child(_pad)
	_said = Label.new(); _said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _said.add_theme_color_override("font_color", PALE); column.add_child(_said)


func show_selection(kind: int, version: String, words: String = "") -> void:
	for candidate in craft_buttons:
		(craft_buttons[candidate] as Button).button_pressed = int(candidate) == kind
	if version_edit != null and not version_edit.has_focus(): version_edit.text = version
	var seat_count := (Sim.geometry_of(kind).get("seat_poses", []) as Array).size()
	var seat_row := _front.get_node_or_null("Seats") as GridContainer if _front != null else null
	if seat_row != null:
		for seat in range(seat_row.get_child_count()): seat_row.get_child(seat).visible = seat < seat_count
	say(words)


static func offered_seat_capacity() -> int:
	var most := 0
	for kind in VehicleCatalogue.pilotable_kinds():
		if kind != Sim.Kind.SEGWAY:
			most = maxi(most, (Sim.geometry_of(kind).get("seat_poses", []) as Array).size())
	return most


func say(words: String) -> void:
	if _said != null: _said.text = words


func show_pad(on: bool) -> void:
	_front.visible = not on; _pad.visible = on
	if on: _pad.show_version(version_edit.text)
