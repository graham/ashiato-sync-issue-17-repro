extends VBoxContainer
class_name CodePad
## A KEYPAD FOR A JOIN CODE: the thirty-two symbols a code can have, a field that shows what is typed, and JOIN.
##
## Asked for on 2026-09-14: "a join code for steam players so they can join a game via a join code rather than having
## to be invited or searching for a game." A headset has no keyboard, so the code is typed on the session screen with a
## fingertip or the beam, one key at a time; a desk has a keyboard, so the field takes keys too.
##
## THE KEYS ARE THE ALPHABET, read off `JoinCode.ALPHABET`, so a key for a symbol no code has cannot exist, and a code
## typed here can only be wrong by length. A keyboard can type anything, and `JoinCode` says why that is not a code --
## this page never judges what it holds.
##
## IT ANNOUNCES. JOIN emits `typed` with the field as it stands and BACK emits `back`; the session screen decides.

signal typed(code: String)
signal back()

const KEYS_IN_A_ROW: int = 8
## HOW BIG THE WORDS ABOUT THE CODE ARE: the label over the field, and -- on the session screen -- the sentence under
## the keypad that says why a code was refused. One number, because the first shot of this page (2026-09-14) showed the
## refusal at the screen's old 15 px under a 24 px label, and a sentence a player has to act on read smaller than the
## heading over what they typed.
const LABEL_SIZE: int = 24

var _field: LineEdit = null


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "Type the host's code"
	title.add_theme_font_size_override("font_size", LABEL_SIZE)
	add_child(title)

	_field = LineEdit.new()
	_field.placeholder_text = JoinCode.spell(JoinCode.EXAMPLE)
	# A code with a dash and a space or two in it still reads; past that a keyboard is being leant on.
	_field.max_length = JoinCode.LENGTH + 3
	_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_field.custom_minimum_size = Vector2(0.0, 56.0)
	_field.add_theme_font_size_override("font_size", 30)
	_field.text_submitted.connect(func(_text: String) -> void: typed.emit(_field.text))
	add_child(_field)

	var keys := GridContainer.new()
	keys.columns = KEYS_IN_A_ROW
	keys.add_theme_constant_override("h_separation", 6)
	keys.add_theme_constant_override("v_separation", 6)
	add_child(keys)
	for symbol in JoinCode.ALPHABET:
		var key := Button.new()
		key.text = symbol
		key.custom_minimum_size = Vector2(0.0, 58.0)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.add_theme_font_size_override("font_size", 26)
		key.focus_mode = Control.FOCUS_NONE
		key.pressed.connect(func() -> void: press_key(symbol))
		keys.add_child(key)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	add_child(actions)
	for pair in [["BACK", func() -> void: back.emit()], ["DELETE", func() -> void: press_key("")],
			["CLEAR", func() -> void: clear()], ["JOIN", func() -> void: typed.emit(_field.text)]]:
		var action := Button.new()
		action.text = String(pair[0])
		action.custom_minimum_size = Vector2(0.0, 58.0)
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.add_theme_font_size_override("font_size", 22)
		action.focus_mode = Control.FOCUS_NONE
		action.pressed.connect(pair[1])
		actions.add_child(action)


## ONE KEY, OR DELETE WHEN `symbol` IS EMPTY. A symbol goes on the end, and the field keeps the code grouped as it is
## shown, so what a person has typed looks like what the host read out.
func press_key(symbol: String) -> void:
	var plain: String = _field.text.to_upper().replace(" ", "").replace("-", "")
	if symbol == "":
		plain = plain.substr(0, maxi(plain.length() - 1, 0))
	elif plain.length() < JoinCode.LENGTH:
		plain += symbol
	_field.text = JoinCode.spell(plain)
	_field.caret_column = _field.text.length()


func clear() -> void:
	_field.text = ""


func shown_code() -> String:
	return _field.text
