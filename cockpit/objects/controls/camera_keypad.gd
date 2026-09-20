@tool
extends VehicleControl
class_name CameraKeypad
## THE THREE KEYS ON THE BACK OF THE DIRECTOR'S CAMERA: power, wider, narrower.
##
## Asked for on 2026-09-15: *"Make the actual system have a button to turn it on and off and a red
## light if it's on, and some fov buttons so i can modify those things by clicking small buttons with
## the pinch gesture we built earlier."*
##
## ONE CONTROL WITH THREE KEYS, NOT THREE CONTROLS. `MfdPanel` settled this already -- eighteen line
## select keys round one bezel -- and the reason is `PilotRig._nearest_to`, which picks the control
## whose GRIP is nearest the hand and knows nothing about what is drawn on it. Three separate controls
## three centimetres apart would make the rig's choice a matter of millimetres, which is exactly the
## thing item 14's rule exists to stop being how anything is decided. Here the rig chooses the KEYPAD,
## and the keypad asks which key the fingertip is on -- a question it can answer exactly, because it
## knows where its own keys are.
##
## PINCHED, LIKE EVERY OTHER KEY IN THE GAME. A fist closed over a 16 mm key is a fist over all three
## of them. `taken_by` says so, and that is also what keeps this and the camera it is bolted to out of
## each other's way: the camera is grabbed and this is pinched, so a closing fist never sees these keys
## and a closing trigger never sees the handle. See `DirectorCamera`.
##
## SQUEEZE TO PRESS, LET GO OR MOVE ON BEFORE PRESSING AGAIN. `MfdPanel`'s bargain, for its two
## reasons: a tracked hand is never quite still, so touch alone would turn the recording on every time
## it drifted past; and a held pinch that did not have to re-arm would run the field of view from end
## to end in a tenth of a second. Remembering WHICH key was pressed rather than just that one was is
## what lets a finger walk from WIDER to NARROWER without opening.
##
## IT ANNOUNCES AND DOES NOTHING. Which key means what is the camera's business -- this emits an index.
## The same rule as the MFD's line select keys, and for the same reason: a key wired to a function is a
## key that has to be rewired when the function moves.

## The keys, in the order they are laid out: left to right across the back, seen from behind.
##
## POWER IN THE MIDDLE, which is deliberate. A finger that has to find one of these without looking
## finds the middle one first, and the middle one is the one that matters -- the two beside it only
## change how wide a shot is, and pressing the wrong one of those costs ten degrees.
enum { WIDER, POWER, NARROWER }

## HOW BIG A KEY IS and how far apart they sit, in metres.
const KEY := Vector3(0.016, 0.012, 0.006)
const KEY_APART: float = 0.030
## How close a fingertip has to be to count as on THAT key rather than its neighbour. Half the gap, so
## there is no dead ground between two keys and no overlap.
const KEY_REACH: float = 0.015
## How far down a key goes when it is pressed.
const PRESS_DEPTH: float = 0.003

## A key was pressed. `which` is one of the enum above.
signal pressed_key(pad: CameraKeypad, which: int)

var _keys: Array[MeshInstance3D] = []
## WHICH KEY THIS SQUEEZE HAS ALREADY PRESSED, or -1 for none. An index and not a plain armed flag, so
## a finger can walk from one key to the next without opening. `MfdPanel._pressed_at`.
var _pressed_at: int = -1
## Whether the power key is lit, which is the camera's answer and not this keypad's. See
## `light_the_power`.
var _powered: bool = false


func label_text() -> String:
	return "CAMERA\nKEYS"


func _build() -> void:
	control_name = "camera keys"
	# YOURS ALONE, like the camera it is on. Nothing here goes on the wire.
	scope = Scope.PILOT
	channel = -1
	var plate := BoxMesh.new()
	plate.size = Vector3(KEY_APART * 3.0, KEY.y * 2.4, 0.006)
	_make_mesh(plate, Color(0.16, 0.17, 0.19), Vector3.ZERO)
	for at in _key_places():
		var cap := BoxMesh.new()
		cap.size = KEY
		_keys.append(_make_mesh(cap, Color(0.26, 0.28, 0.30), at))


## WHERE EVERY KEY IS, in this keypad's own frame. Derived from the two constants above, so
## `_pressed_key` and `_build` cannot disagree about where key 2 is -- neither of them knows.
func _key_places() -> Array:
	return [Vector3(-KEY_APART, 0.0, 0.004), Vector3(0.0, 0.0, 0.004),
		Vector3(KEY_APART, 0.0, 0.004)]


## THE MIDDLE OF THE PLATE, which is the power key. The one point the rig measures a hand against when
## it decides which control the hand is nearest to, so it has to be the middle of the keypad and not
## any one key. See `MfdPanel._grab_point`, which says the same.
func _grab_point() -> Vector3:
	return Vector3.ZERO


## WHERE ONE KEY IS, in this keypad's own frame. Public because anything that wants to put a fingertip
## on a key -- a test, a robot, a page that draws a hint -- has to be able to ask rather than work it
## out from the two constants, which is how two places come to disagree about where key 2 is.
func key_place(which: int) -> Vector3:
	var places: Array = _key_places()
	return places[which] as Vector3 if which >= 0 and which < places.size() else Vector3.ZERO


## HOW MANY KEYS HAVE ACTUALLY BEEN DRAWN.
##
## Not `_key_places().size()`, which is arithmetic and answers three whatever happened. This is the
## meshes, and the difference between the two is a whole bug: a keypad whose `setup` was never called
## still tells a fingertip which key it is on, because `_key_under` is arithmetic too -- so it works
## perfectly and is invisible. `tests/director.gd` asks this for that reason.
func keys_drawn() -> int:
	return _keys.size()


## WHICH KEY A FINGER AT `at` IS ON, or -1 for none of them.
func _key_under(at: Vector3) -> int:
	var places: Array = _key_places()
	var best: int = -1
	var closest: float = KEY_REACH
	for step in range(places.size()):
		var away: float = at.distance_to(places[step] as Vector3)
		if away < closest:
			closest = away
			best = step
	return best


func offer_hand(hand: int, at: Vector3, pinch: float,
		_facing: Basis = Basis.IDENTITY) -> void:
	var which: int = _key_under(at)
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
	_redraw()
	pressed_key.emit(self, which)


## PRESS A KEY WITHOUT A HAND. What the desk's keyboard and the tests reach for, and the same path a
## fingertip ends on -- so nothing can work one way for a key and another for a finger.
func press(which: int) -> void:
	if which < 0 or which >= _keys.size():
		return
	pressed_key.emit(self, which)


func release() -> void:
	held_by = -1
	_pressed_at = -1
	_redraw()


## THE POWER KEY IS LIT WHILE THE CAMERA IS RECORDING, and the camera is the one that says so. Told
## rather than asked, because a keypad that reached up to its parent to find out would be a keypad
## that only works when it is on a camera.
func light_the_power(on: bool) -> void:
	if _powered == on:
		return
	_powered = on
	_redraw()


func _redraw() -> void:
	for step in range(_keys.size()):
		var down: bool = step == _pressed_at
		var lit: bool = step == POWER and _powered
		_keys[step].position = _key_places()[step] - Vector3(0.0, 0.0, PRESS_DEPTH if down else 0.0)
		_tint(_keys[step], Color(0.95, 0.76, 0.22) if lit else Color(0.26, 0.28, 0.30))
		var material := _keys[step].material_override as StandardMaterial3D
		material.emission_enabled = lit
		material.emission = Color(0.85, 0.58, 0.10)
		material.emission_energy_multiplier = 1.4 if lit else 0.0


## PINCHED, NOT GRABBED. See the note at the top and `Bind.Take`.
func taken_by() -> int:
	return Bind.Take.PINCH


## NEVER PLACED ON ITS OWN. It is bolted to the back of a camera, and `ControlCatalogue` does not offer
## it: a keypad standing on a console with no camera behind it would be three keys wired to nothing.
## It does not know where the back of a camera IS either -- the camera positions it, so nothing here
## names `DirectorCamera` and the two classes do not refer to each other in a ring.
func throttle() -> float:
	return 0.0
