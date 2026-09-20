extends VBoxContainer
class_name VersionPad

signal applied(version: String)
signal back()

const ALPHABET := "abcdefghijklmnopqrstuvwxyz0123456789_"
var field: LineEdit = null


func _ready() -> void:
	var title := Label.new(); title.text = "VERSION NAME"; title.add_theme_font_size_override("font_size", 28); add_child(title)
	field = LineEdit.new(); field.max_length = BuilderAuthority.MOST_VERSION_BYTES; field.custom_minimum_size.y = 52
	field.text_submitted.connect(func(_text: String): applied.emit(field.text)); add_child(field)
	var keys := GridContainer.new(); keys.columns = 8; add_child(keys)
	for symbol in ALPHABET:
		var key := Button.new(); key.text = symbol; key.custom_minimum_size = Vector2(0, 42); key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.focus_mode = Control.FOCUS_NONE; key.pressed.connect(func(): press_key(symbol)); keys.add_child(key)
	var actions := HBoxContainer.new(); add_child(actions)
	for pair in [["BACK", func(): back.emit()], ["DELETE", func(): press_key("")], ["CLEAR", func(): field.text = ""],
			["APPLY", func(): applied.emit(field.text)]]:
		var action := Button.new(); action.text = pair[0]; action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.custom_minimum_size.y = 48; action.pressed.connect(pair[1]); actions.add_child(action)


func press_key(symbol: String) -> void:
	if symbol.is_empty(): field.text = field.text.left(maxi(0, field.text.length() - 1))
	elif field.text.length() < BuilderAuthority.MOST_VERSION_BYTES: field.text += symbol
	field.caret_column = field.text.length()


func show_version(version: String) -> void:
	field.text = version
	field.caret_column = field.text.length()
