@tool
extends VehicleControl
class_name MfdPanel
## A MULTI-FUNCTION DISPLAY: a screen with a ring of keys round the bezel.
##
## `CraftDisplay` already said this was coming -- "an MFD is a screen with buttons down each
## side" -- and until now the cockpit had the screen without the buttons, which makes it a
## gauge. The buttons are the difference between an instrument you read and an instrument
## you WORK.
##
## ---------------------------------------------------------------------------------
## WHY THE KEYS ARE ROUND THE EDGE AND NOT ON THE GLASS
## ---------------------------------------------------------------------------------
##
## The glass is touchable already -- `TouchPanel` takes a fingertip and the board in your
## left hand is worked exactly that way -- so buttons drawn on the screen would have been
## less code than these.
##
## They would also have been the wrong thing, twice over. A finger on the glass is a finger
## covering the thing it is selecting, which on a 14 cm panel is most of the panel. And a
## button on a screen has no edge: in a headset, with no force feedback and a hand that is
## never quite where you believe it is, the only way to hit a target reliably is for the
## target to be a physical object your fingers can find by running along the bezel. That is
## why real ones are built this way, and the reasons transfer exactly.
##
## ---------------------------------------------------------------------------------
## LINE SELECT KEYS MEAN WHATEVER THE PAGE SAYS THEY MEAN
## ---------------------------------------------------------------------------------
##
## A key is not wired to a function. It is wired to a POSITION -- third down the left side
## -- and the page draws a word beside it saying what it does right now. That is the whole
## idea of a multi-function display and it is the reason eighteen keys are enough for an
## aircraft with a hundred things to select.
##
## SO WHAT GOES ON THE BUS IS WHICH KEY, and the page on the glass decides what that means.
## The channel is DISPLAY, it is edge-sent like every other command -- see
## `PilotRig._send_what_moved` -- and nothing here has an opinion about what page 7 is.

## HOW BIG THE GLASS IS, and how wide the bezel round it.
##
## SMALL ENOUGH THAT EVERY KEY IS WITHIN REACH OF THE MIDDLE. `PilotRig._nearest_to` picks
## the control whose grip is closest to the hand, and a control has ONE grip point -- this
## one's is the centre of the glass. So the far corner key has to be inside
## `VehicleControl.REACH` of that centre or the panel simply cannot be worked from there.
## The corners sit about 0.135 m out, against a reach of 0.16.
const GLASS := Vector2(0.15, 0.12)
const BEZEL: float = 0.026

## HOW MANY KEYS DOWN EACH SIDE AND ALONG THE TOP AND BOTTOM.
##
## Five and four: the shape of nearly every real one, and not symmetry for its own sake. The
## sides get more because a list reads down, and the top and bottom get fewer because those
## are where modes and pages go rather than list entries.
const KEYS_SIDE: int = 5
const KEYS_ENDS: int = 4

const KEY := Vector3(0.018, 0.007, 0.014)
## How close a fingertip has to be to a key to be on THAT key rather than its neighbour.
## Half the gap between them, so there is no dead ground and no overlap.
const KEY_REACH: float = 0.011

## WHICH PAGE THE GLASS SHOWS.
##
## LOADED AND NOT PRELOADED. A `preload` is resolved at parse time, and this class is
## reachable from `ControlCatalogue`, which is reachable from `CockpitLayout`, which
## `CockpitStation` uses -- and the station is what puts pages on screens. That is exactly
## the ring that made every station scene fail to load with "Busy" once before. `load` is
## resolved when a panel is actually built, and the result is cached, so it costs nothing
## and cannot close a ring.
const PAGE_PATH: String = "res://objects/seats/mfd_page.tscn"

## A key was pressed. `which` is its index, counting from the top of the left side and going
## round. What it MEANS is the page's business -- see the note above.
signal key_pressed(panel: MfdPanel, which: int)

var _screen: CraftDisplay = null
var _keys: Array[MeshInstance3D] = []
## WHICH KEY THIS SQUEEZE HAS ALREADY PRESSED, or -1 for none.
##
## An index rather than the `CrewButton`'s plain "armed" flag, and the index is what lets a
## finger WALK. See `offer_hand`.
var _pressed_at: int = -1


func label_text() -> String:
	return "MFD\nDISPLAY"


## How many keys this panel has. Two sides and two ends.
static func key_count() -> int:
	return KEYS_SIDE * 2 + KEYS_ENDS * 2


func _build() -> void:
	control_name = "mfd"
	# THE PILOT'S, and that is a change: it was the craft's, so a key pressed on this panel moved
	# every MFD panel's lit key aboard, because DISPLAY is one selector for the whole aircraft.
	# Which key a person last pressed on the screen in front of them is theirs -- the page on the
	# glass already chooses itself locally (MfdPage), and a copilot's panel lighting up under the
	# pilot's finger said something about their screen that was not true. Still wired to DISPLAY,
	# so a layout can make one the craft's again with "scope": "craft".
	scope = Scope.PILOT
	channel = Sim.Channel.DISPLAY
	# ONE PER KEY, so a craft-scoped panel's bus carries which was pressed. See the note at the
	# top: what a key means is the page's business.
	channel_range = maxi(key_count() - 1, 1)
	var case := BoxMesh.new()
	case.size = Vector3(GLASS.x + BEZEL * 2.0, GLASS.y + BEZEL * 2.0, 0.022)
	_make_mesh(case, Color(0.09, 0.10, 0.12), Vector3(0.0, 0.0, -0.011))
	_build_the_keys()
	_screen = CraftDisplay.new()
	_screen.name = "Glass"
	_screen.page = load(PAGE_PATH) as PackedScene
	_screen.size = GLASS
	# 3800 pixels a metre, which is what the console screens settled on. See CraftDisplay:
	# the viewport redraws on demand at about 5 Hz, so this is cheap.
	_screen.pixels = 576
	# NO BEZEL OF ITS OWN. The panel IS the bezel, and two of them leaves a screen sunk in a
	# frame inside a frame.
	_screen.bezel = false
	_screen.position = Vector3(0.0, 0.0, 0.001)
	add_child(_screen)


## THE RING OF KEYS, in one order: down the left, along the bottom, up the right, back along
## the top.
##
## ROUND RATHER THAN IN FOUR LISTS, because an index that walks the bezel is one a page can
## reason about -- "the key opposite this one" is arithmetic -- and because it means adding
## a key to a side does not renumber the other three.
func _build_the_keys() -> void:
	for at in _key_places():
		var cap := BoxMesh.new()
		# The side keys stand proud across, the end keys along, so a finger running down an
		# edge meets them square on whichever edge it is running down.
		var side: bool = absf(at.x) > absf(at.y)
		cap.size = Vector3(KEY.z, KEY.x, KEY.y) if side else KEY
		_keys.append(_make_mesh(cap, Color(0.26, 0.28, 0.30), at))


## WHERE EVERY KEY IS, in this panel's own frame, in bezel order.
##
## Static-ish and derived rather than written out, so the two counts above are the only
## numbers that decide the layout -- and `_pressed_key` and `_build_the_keys` cannot
## disagree about where key 11 is, because neither of them knows.
func _key_places() -> Array:
	var out: Array = []
	var half_x: float = GLASS.x * 0.5 + BEZEL * 0.5
	var half_y: float = GLASS.y * 0.5 + BEZEL * 0.5
	for step in range(KEYS_SIDE):
		out.append(Vector3(-half_x, _spread(step, KEYS_SIDE, GLASS.y) * -1.0, 0.004))
	for step in range(KEYS_ENDS):
		out.append(Vector3(_spread(step, KEYS_ENDS, GLASS.x), -half_y, 0.004))
	for step in range(KEYS_SIDE):
		out.append(Vector3(half_x, _spread(step, KEYS_SIDE, GLASS.y), 0.004))
	for step in range(KEYS_ENDS):
		out.append(Vector3(_spread(step, KEYS_ENDS, GLASS.x) * -1.0, half_y, 0.004))
	return out


## The nth of `many` keys spread evenly along `across`, centred.
static func _spread(step: int, many: int, across: float) -> float:
	if many <= 1:
		return 0.0
	return (float(step) / float(many - 1) - 0.5) * across * 0.86


## THE MIDDLE OF THE GLASS. See the note on GLASS: this is the one point the rig measures a
## hand against when deciding which control it is nearest to, so it has to be the middle of
## the panel rather than any one key.
func _grab_point() -> Vector3:
	return Vector3.ZERO


func _redraw() -> void:
	var lit: int = command_value()
	for step in range(_keys.size()):
		var on: bool = step == lit
		_tint(_keys[step], Color(0.95, 0.76, 0.22) if on else Color(0.26, 0.28, 0.30))
		var material := _keys[step].material_override as StandardMaterial3D
		material.emission_enabled = on
		material.emission = Color(0.85, 0.58, 0.10)
		material.emission_energy_multiplier = 1.4 if on else 0.0


## WHICH KEY A FINGER AT `at` IS ON, or -1 for none of them.
func _pressed_key(at: Vector3) -> int:
	var places: Array = _key_places()
	var best: int = -1
	var closest: float = KEY_REACH
	for step in range(places.size()):
		var away: float = at.distance_to(places[step] as Vector3)
		if away < closest:
			closest = away
			best = step
	return best


## SQUEEZE TO PRESS, AND LET GO BEFORE PRESSING AGAIN.
##
## The same bargain `CrewButton` makes, and for the same two reasons. Touch alone would mean
## a hand resting anywhere near the console selecting pages at random, because a tracked
## hand is never quite still. And a held squeeze that did not have to re-arm would select at
## the tick rate, which on a page selector means every page in the aircraft in a tenth of a
## second.
##
## AND WHAT RE-ARMS IT IS MOVING TO A DIFFERENT KEY, not only opening the hand. A finger
## dragged along the bezel presses each key it arrives at, which is how anybody actually
## works one of these -- and is why this remembers WHICH key it pressed rather than just
## that it pressed one.
func offer_hand(hand: int, at: Vector3, pinch: float,
		_facing: Basis = Basis.IDENTITY) -> void:
	var which: int = _pressed_key(at)
	if which < 0 or pinch <= GRAB_OFF:
		if _pressed_at >= 0:
			_pressed_at = -1
			held_by = -1
			_redraw()
		return
	if pinch < GRAB_ON or which == _pressed_at:
		return
	_pressed_at = which
	held_by = hand
	# BY MOVING, like every control. What happens next is the scope's business, not this
	# function's: a PILOT panel -- the default -- keeps the key lit here and tells nobody; a
	# panel a layout made the CRAFT's is proposed on the bus by `PilotRig._send_what_moved`.
	_settle(Vector2(0.0, float(which) / float(maxi(channel_range, 1))))
	_redraw()
	key_pressed.emit(self, which)


func release() -> void:
	held_by = -1
	_pressed_at = -1
	_redraw()


## WHICH KEY WAS LAST PRESSED. What the page reads, and what the bus carries.
func selected_key() -> int:
	return command_value()


## The screen itself, for anything that wants to feed it directly. `CockpitStation.show_state`
## finds it on its own -- it walks the whole station for CraftDisplays -- so nothing has to
## know an MFD is a control with a screen inside it rather than a screen.
func screen() -> CraftDisplay:
	return _screen


func throttle() -> float:
	return 0.0


## PINCHED, NOT GRABBED. Every reason the keys are physical objects round the bezel rather than
## targets drawn on the glass is a reason they are pressed with a fingertip: a key is found by
## running a finger along the edge, and a fist closed over an 8 mm key is a fist over four of
## them. See `Bind.Take`.
func taken_by() -> int:
	return Bind.Take.PINCH


## READ, NOT PUSHED ALONG AN AXIS: turned to face the seat when the builder adds one. See `VehicleControl.faces_the_eye`.
func faces_the_eye() -> bool:
	return true
