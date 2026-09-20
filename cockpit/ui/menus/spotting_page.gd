extends VBoxContainer
class_name SpottingPage
## THE CLIPBOARD'S SPOTTING SIZE: how much bigger far aircraft are drawn for you, and inside what distance they are
## their true size. It announces; `PilotRig` keeps the setting in its `Spectacles` and shows it back.
##
## Asked for on 2026-09-18: "Make sure the ipad has clear options around this." So the page says, before anything is
## pressed, what the setting does and that it is nobody else's; every row has its current choice lit; and under each row
## is a sentence that says what that choice does NOW, in numbers somebody can check against the sky -- a fighter at ten
## kilometres, and the distance inside which nothing is changed.
##
## BUTTONS AND NOT A SLIDER. A strength is one of four words and a distance one of four steps, each pressed exactly by a
## beam from a seat or by a robot; a slider is a drag, and a drag with a fingertip in a headset lands where it lands.
##
## THE HIGHLIGHT IS THE RIG'S, as TIME's is the level's: a press announces and puts the buttons back to what was last
## shown, and `show_spectacles` is what moves it.

signal chose_strength(strength: int)
signal chose_near(metres: float)

const AMBER := BoardStyle.AMBER
const PALE := BoardStyle.PALE
const DIM := BoardStyle.DIM

const HEADLINE: String = "SPOTTING SIZE"
const WHAT_IT_DOES: String = "Draws distant aircraft bigger so they are easier to see. Only you see this: " \
	+ "nobody else's view changes, and nothing about flying, aiming or hitting changes."

var _strengths: Array[Button] = []
var _nears: Array[Button] = []
var _strength_words: Label = null
var _near_words: Label = null
var _shown_strength: int = Spectacles.DEFAULT_STRENGTH
var _shown_near: float = Spectacles.DEFAULT_NEAR
## The pair last handed in, kept so a page shown before it was built still says what it is set to.
var _pair: Spectacles = null


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = HEADLINE
	title.add_theme_font_size_override("font_size", BoardStyle.text(22))
	title.add_theme_color_override("font_color", AMBER)
	add_child(title)
	add_child(_words(WHAT_IT_DOES, PALE, 18))

	add_child(_words("HOW MUCH BIGGER", DIM, 17))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for i in range(Spectacles.STRENGTH_WORDS.size()):
		var which: int = i
		var pick: Button = _pick(Spectacles.STRENGTH_WORDS[i], "Strength%s" % Spectacles.STRENGTH_WORDS[i].capitalize())
		pick.pressed.connect(func():
			chose_strength.emit(which)
			_mark())
		row.add_child(pick)
		_strengths.append(pick)
	_strength_words = _words("", PALE, 18)
	_strength_words.name = "StrengthWords"
	add_child(_strength_words)

	add_child(_words("NORMAL SIZE WITHIN", DIM, 17))
	var nears := HBoxContainer.new()
	nears.add_theme_constant_override("separation", 8)
	add_child(nears)
	for metres in Spectacles.NEAR_STEPS:
		var at: float = metres
		var pick: Button = _pick(Spectacles.km_words(at).to_upper(), "Near%d" % int(at))
		pick.pressed.connect(func():
			chose_near.emit(at)
			_mark())
		nears.add_child(pick)
		_nears.append(pick)
	_near_words = _words("", PALE, 18)
	_near_words.name = "NearWords"
	add_child(_near_words)
	show_spectacles(_pair if _pair != null else Spectacles.new())


## WHAT THE RIG'S SPECTACLES ARE SET TO, handed in. Moves the highlights and rewrites both sentences.
func show_spectacles(pair: Spectacles) -> void:
	_pair = pair
	_shown_strength = pair.strength
	_shown_near = pair.near_m
	if _strength_words != null:
		_strength_words.text = pair.words()
		_near_words.text = pair.near_words()
	_mark()


## What is shown, for the tests: {"strength": int, "near_m": float, "says": the strength's sentence}.
func shown() -> Dictionary:
	return {"strength": _shown_strength, "near_m": _shown_near,
		"says": _strength_words.text if _strength_words != null else ""}


## THE BUTTON FOR A STRENGTH (0..3) or a near step, for a test to aim a beam at.
func strength_button(which: int) -> Button:
	return _strengths[which]


func near_button(metres: float) -> Button:
	return _nears[Spectacles.NEAR_STEPS.find(metres)]


func _mark() -> void:
	for i in range(_strengths.size()):
		_strengths[i].set_pressed_no_signal(i == _shown_strength)
	for i in range(_nears.size()):
		_nears[i].set_pressed_no_signal(is_equal_approx(Spectacles.NEAR_STEPS[i], _shown_near))
	# THE DISTANCE ROW IS DIM WHILE THE STRENGTH IS OFF: it still works, and a limit chosen now is kept, but it does
	# nothing until something is magnified, and a lit row that did nothing would read as broken.
	for pick in _nears:
		pick.modulate = Color(1, 1, 1, 1) if _shown_strength != Spectacles.Strength.OFF else Color(1, 1, 1, 0.55)


func _pick(words: String, named: String) -> Button:
	var pick := Button.new()
	pick.name = named
	pick.text = words
	pick.toggle_mode = true
	pick.custom_minimum_size = Vector2(0.0, BoardStyle.reach(52.0))
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.add_theme_font_size_override("font_size", BoardStyle.pressed_text(20))
	pick.add_theme_color_override("font_pressed_color", AMBER)
	pick.add_theme_color_override("font_hover_pressed_color", AMBER)
	return pick


func _words(text: String, colour: Color, pixels: int) -> Label:
	var line := Label.new()
	line.text = text
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", BoardStyle.text(pixels))
	line.add_theme_color_override("font_color", colour)
	return line
