@tool
extends VehicleControl
class_name DirectorCamera
## A CAMERA ON A HANDLE, floating in the cockpit, that puts its own view on the desktop.
##
## Asked for on 2026-09-15: *"it's very important that I can record my play sessions, so i want the
## ability to make the 'desktop' show a different view than what is in the vr headset. I want a
## floating camera that i can position in my cockpit, and grab it with my hand and move it."*
##
## It is a part in `ControlCatalogue`, so it is placed and saved like every other piece of cockpit
## furniture, and it is bolted to a station -- which means it flies with the aeroplane. A camera that
## stayed where the runway was would be a camera pointed at the sea a minute later.
##
## ---------------------------------------------------------------------------------
## WHAT IT COSTS, WHICH IS WHY THERE IS A SWITCH ON IT
## ---------------------------------------------------------------------------------
##
## The desktop window is normally a MIRROR of what the headset is drawing: one camera, drawn once,
## shown twice. A different view is a second camera and a SECOND FULL PASS over the world, and this is
## the one thing in the game that deliberately costs frames.
##
## `tests/director_cost.gd` measured it before any of this was built: **0.60 to 0.70 ms a frame** on an
## RTX 5080 under D3D12 and the Mobile renderer, against a 2.05 ms baseline, with the level's
## seventy-nine vehicles in the world. That is inside the budget, so it ships -- OFF BY DEFAULT, with a
## button to turn it on and a red light that says you are paying for it. The light is not decoration.
##
## AND SHRINKING THE RECORDING DOES NOT HELP, which was the surprise. 960x540 cost 0.596 ms and
## 1920x1080 cost 0.617: a fiftieth of a millisecond for a ninth of the pixels. The per-pixel half does
## fall -- the second viewport's own GPU timer goes 0.740 to 0.411 -- and the frame does not get
## faster, because what it is waiting on is the CPU half: a second cull and a second render list over
## every vehicle and the whole island, which is 0.47 to 0.50 ms at any size. So `Monitor` records at
## the window's own size and there is no render-scale knob here. The only saving is the switch.
##
## ---------------------------------------------------------------------------------
## WHICH FINGER DOES WHAT, AND WHY THAT IS TWO CONTROLS AND NOT ONE
## ---------------------------------------------------------------------------------
##
## The body is GRABBED with a fist and carried. The buttons are PINCHED with a fingertip. A control
## answers exactly one finger (`VehicleControl.taken_by`), so this is two controls: the camera, which
## is what you pick up, and a `CameraKeypad` bolted to its back, which is what you press. The keypad is
## a CHILD of the camera, so it travels with it; `CockpitStation.controls()` finds it through
## `carries()`.
##
## THAT IS NOT A WORKAROUND, IT IS THE POINT. Two controls a hand's-breadth apart is the arrangement
## `tests/fit.gd` forbids in an authored cockpit, because a hand between two grips is ambiguous -- and
## here it is not ambiguous at all, because item 14's rule settles it: a closing fist sees only grabbed
## parts and a closing trigger sees only pinched ones. This is that rule's best case, and the whole
## reason item 20 waited for item 14.
##
## REJECTED: ONE CONTROL THAT ANSWERS BOTH FINGERS. It would need `taken_by` to return two answers, and
## every one of the twenty-odd control classes below that line would have had to learn there are two
## gestures -- which is exactly the cost item 14 avoided paying.
##
## ---------------------------------------------------------------------------------
## CARRIED IN FLIGHT, NOT ONLY IN THE BUILDER
## ---------------------------------------------------------------------------------
##
## Every other part in the bin is dragged about only while the cockpit builder is on; in flight a hand
## WORKS it instead. This one is picked up while flying, because "grab it with my hand and move it" is
## how you frame a shot and the builder is a mode you cannot be in while doing anything worth
## recording. `carried_by_hand()` says so, and `PilotRig._work_the_controls` reads it beside
## `placing()` -- so the machinery is `offer_hand_to_place`, which already existed and already knows
## how to pivot a thing about the hand that lifted it.
##
## THE HAND CARRYING IT IS NOT ALSO BRAKING OR FIRING. `bindings()` takes the trigger away while it is
## held, for the same reason the builder's carry does: an empty left hand brakes with that finger and a
## gun grip fires with it, and neither is something to be doing while moving a camera about the
## cockpit. It costs nothing when the camera is on its mount, because the table only applies to the
## hand actually holding it.
##
## THE OTHER HAND PRESSES THE KEYS. One hand holds one control -- `PilotRig._held_by` -- so the hand
## carrying the camera cannot also pinch its keypad. That is how a camera works in life, and it falls
## out of a rule that was already there rather than being arranged.

## HOW WIDE, HOW TALL AND HOW DEEP THE BODY IS, in metres. Small enough to hold, big enough that the
## keypad on the back is three keys a fingertip can tell apart.
const BODY := Vector3(0.10, 0.075, 0.16)
## The handle on top: where the fist closes. A camera is held by a handle and not by its body, and
## `_grab_point` is the difference between a hand that can pick this up and one that hovers over it.
const HANDLE_ABOVE: float = 0.055
## The lens, out of the front (-Z), and the tally light above it.
const LENS_RADIUS: float = 0.028
const LENS_LENGTH: float = 0.055
const TALLY_RADIUS: float = 0.010

## THE FIELD OF VIEW, IN DEGREES, and how far the buttons move it.
##
## 60 to start with, which is about what a person reads as "a normal shot": wide enough to see a
## cockpit, narrow enough not to bend it. The ends are 20 -- a long lens picking one aircraft out of a
## formation -- and 100, which is as wide as this can go before the cockpit walls bow.
##
## TEN DEGREES A PRESS, so the whole range is eight presses. A finer step would be more presses than
## anybody will make with a fingertip in mid-air, and a coarser one cannot frame anything.
const FOV_START: float = 60.0
const FOV_LEAST: float = 20.0
const FOV_MOST: float = 100.0
const FOV_STEP: float = 10.0

## IT TURNED ON OR OFF. What `Monitor` is told about, and what the red light is drawn from.
signal switched(camera: DirectorCamera, on: bool)
## Its field of view changed. `degrees` is the new one.
signal framed(camera: DirectorCamera, degrees: float)

## WHETHER IT IS RECORDING. FALSE TO START WITH, and that is the measurement's doing rather than
## caution: see the cost note at the top.
var on: bool = false
var fov: float = FOV_START

var _tally: MeshInstance3D = null
var _keypad: CameraKeypad = null
## WHERE THE LENS IS, as a node rather than as an offset. `Monitor` stands its own camera here every
## frame, and a node means the body's mesh can be redrawn without moving the picture.
var _lens: Marker3D = null


func label_text() -> String:
	return "DIRECTOR\nCAMERA"


## AND THE KEYPAD IS SET UP WITH IT.
##
## A control builds its meshes in `setup`, which the station calls on its own CHILDREN -- and the
## keypad is a grandchild, so without this nobody ever calls it. A keypad that was never set up still
## answers a fingertip, because `_key_under` works off `_key_places()` and that is pure arithmetic;
## what it has is no MESHES. Three invisible keys that work perfectly, and a power key that never
## lights.
##
## THAT IS EXACTLY WHAT SHIPPED FOR AN HOUR, and `tests/director.gd` was green the whole time, because
## every check it makes is about what a key DOES. `tests/director_shot.gd` found it on its first run:
## the camera would not switch on at all through `CameraKeypad.press`, which refuses an index outside
## `_keys`, and `_keys` was empty. The suite now counts the keys that were drawn as well.
func setup(seat_index: int) -> void:
	super(seat_index)
	if _keypad != null:
		_keypad.setup(seat_index)


func _build() -> void:
	control_name = "director camera"
	# YOURS ALONE. Nothing about a camera pointed at your own cockpit is the aircraft's business, and
	# nothing about it goes on the wire: no channel, and `Scope.PILOT` so `PilotRig._send_what_moved`
	# leaves it be. A crewmate's recording is not a shared setting.
	scope = Scope.PILOT
	channel = -1
	var shell := BoxMesh.new()
	shell.size = BODY
	_make_mesh(shell, Color(0.12, 0.13, 0.15), Vector3.ZERO)

	var post := CylinderMesh.new()
	post.top_radius = 0.008
	post.bottom_radius = 0.008
	post.height = HANDLE_ABOVE - BODY.y * 0.5
	_make_mesh(post, Color(0.18, 0.19, 0.21),
		Vector3(0.0, (BODY.y * 0.5 + HANDLE_ABOVE) * 0.5, 0.0))
	var grip := CylinderMesh.new()
	grip.top_radius = 0.015
	grip.bottom_radius = 0.015
	grip.height = 0.070
	var bar: MeshInstance3D = _make_mesh(grip, Color(0.22, 0.23, 0.25),
		Vector3(0.0, HANDLE_ABOVE, 0.0))
	# ACROSS THE AEROPLANE, so the handle lies under a hand held palm-down rather than standing on
	# end under a fist that would have to be turned sideways to close on it.
	bar.rotation = Vector3(0.0, 0.0, PI * 0.5)

	var barrel := CylinderMesh.new()
	barrel.top_radius = LENS_RADIUS
	barrel.bottom_radius = LENS_RADIUS
	barrel.height = LENS_LENGTH
	var lens: MeshInstance3D = _make_mesh(barrel, Color(0.08, 0.08, 0.09),
		Vector3(0.0, 0.0, -(BODY.z + LENS_LENGTH) * 0.5))
	lens.rotation = Vector3(PI * 0.5, 0.0, 0.0)

	var bulb := SphereMesh.new()
	bulb.radius = TALLY_RADIUS
	bulb.height = TALLY_RADIUS * 2.0
	# ON THE FRONT, FACING THE SUBJECT. A tally light is for the person being filmed, and the person
	# being filmed here is whoever is in the seat the lens is pointed at.
	_tally = _make_mesh(bulb, Color(0.20, 0.06, 0.06),
		Vector3(0.0, BODY.y * 0.5 - TALLY_RADIUS, -BODY.z * 0.5 - TALLY_RADIUS))

	_lens = Marker3D.new()
	_lens.name = "Lens"
	_lens.position = Vector3(0.0, 0.0, -BODY.z * 0.5)
	add_child(_lens)

	_keypad = CameraKeypad.new()
	_keypad.name = "Keys"
	# ON THE BACK, AND PLACED FROM HERE. The keypad does not know what a camera is -- if it named
	# `DirectorCamera` to ask how deep the body is, the two classes would refer to each other in a
	# ring, which in this project is the failure that only shows up in the editor (`agents.md`).
	_keypad.position = Vector3(0.0, 0.0, BODY.z * 0.5 + 0.004)
	add_child(_keypad)
	_keypad.pressed_key.connect(_on_key)


## THE MONITOR HAS ONE WINDOW, AND MAY BE TAKEN OFF THIS CAMERA BY ANOTHER ONE -- or by the player
## closing the window. Either way this camera has stopped recording, so its light must go out. The
## monitor ANNOUNCES where it is looking and each camera decides what that means about itself; the
## monitor never reaches into a cockpit it knows nothing about.
##
## Not in the editor, where there are no autoloads and no window to put anything in.
func _ready() -> void:
	super()
	if not Engine.is_editor_hint():
		Monitor.now_watching.connect(_on_now_watching)


func _exit_tree() -> void:
	# A CAMERA THAT IS BINNED WHILE RECORDING TAKES ITS WINDOW WITH IT. The builder's bin frees the
	# node, and a window left up would be a second pass over the world with nothing pointing it.
	if not Engine.is_editor_hint() and on:
		on = false
		Monitor.look_away()


## ---- the switch and the lens -------------------------------------------------------------

## TURN IT ON OR OFF. The one place the monitor is told anything.
##
## Returns whether it is on afterwards, which is not always what was asked: a monitor that cannot put
## a window up says so, and a camera that claimed to be recording into nothing would be a red light
## lying about the one thing it is for.
func turn(wanted: bool) -> bool:
	if wanted == on:
		return on
	if wanted:
		on = Monitor.watch(_lens, fov)
	else:
		# OFF BEFORE THE MONITOR IS TOLD, and the order is the whole of it. `look_away` announces that it
		# is watching nothing, this camera hears its own announcement through `_on_now_watching`, and
		# with `on` still true it would switch itself off a second time and emit `switched` twice. A
		# listener that counted presses would count two.
		on = false
		Monitor.look_away()
	_redraw()
	switched.emit(self, on)
	return on


func is_on() -> bool:
	return on


## WIDER OR NARROWER, one step, clamped. Announced whether or not it moved -- a press at the end of
## the travel is still a press, and a page that draws the number wants telling either way.
func frame_wider() -> void:
	_frame_at(fov + FOV_STEP)


func frame_narrower() -> void:
	_frame_at(fov - FOV_STEP)


func _frame_at(degrees: float) -> void:
	fov = clampf(degrees, FOV_LEAST, FOV_MOST)
	if on:
		Monitor.frame_at(fov)
	framed.emit(self, fov)


## WHERE THE LENS IS. What `Monitor` stands its camera on, and what a test reads to ask whether the
## desktop is looking somewhere else.
func lens() -> Node3D:
	return _lens


## The keypad on its back, for the tests and for anything that wants to press a key without a hand.
func keypad() -> CameraKeypad:
	return _keypad


func _on_key(_pad: CameraKeypad, which: int) -> void:
	match which:
		CameraKeypad.POWER:
			turn(not on)
		CameraKeypad.WIDER:
			frame_wider()
		CameraKeypad.NARROWER:
			frame_narrower()


## THE MONITOR IS LOOKING AT SOMETHING ELSE, OR AT NOTHING. Only this camera's business if it was the
## one being recorded: a second camera switched on takes the window, and this one's light must go out
## without either camera knowing the other exists.
func _on_now_watching(at: Node3D) -> void:
	if not on or at == _lens:
		return
	on = false
	_redraw()
	switched.emit(self, false)


## ---- how it is held, and what it looks like ------------------------------------------------

## THE RED LIGHT, AND IT IS READ FROM THE SWITCH rather than kept beside it. "A red light if it's on"
## was asked for, and a light with a flag of its own is a light that can disagree with the thing it is
## reporting.
func _redraw() -> void:
	if _tally != null:
		_tint(_tally, Color(0.95, 0.12, 0.10) if on else Color(0.20, 0.06, 0.06))
		var material := _tally.material_override as StandardMaterial3D
		material.emission_enabled = on
		material.emission = Color(0.90, 0.06, 0.04)
		material.emission_energy_multiplier = 3.0 if on else 0.0
	if _keypad != null:
		_keypad.light_the_power(on)


## THE HANDLE, not the body. See HANDLE_ABOVE.
func _grab_point() -> Vector3:
	return Vector3(0.0, HANDLE_ABOVE, 0.0)


## GRABBED WITH A FIST. It is a thing you pick up; the buttons on its back are what fingertips are
## for. See the note at the top and `Bind.Take`.
func taken_by() -> int:
	return Bind.Take.GRIP


## CARRIED WHILE FLYING, which no other part is. See the note at the top.
func carried_by_hand() -> bool:
	return true


## THE KEYPAD COMES WITH IT. `CockpitStation.controls()` splices this in, so a hand can reach the keys
## although they are a grandchild of the station rather than a child.
func carries() -> Array[VehicleControl]:
	var out: Array[VehicleControl] = []
	if _keypad != null:
		out.append(_keypad)
	return out


## THE HAND HOLDING IT IS DOING NOTHING ELSE WITH THAT FINGER. See the note at the top.
func bindings() -> Dictionary:
	return {Bind.TRIGGER: Bind.nothing()}


## TURNED TO FACE THE SEAT when the builder puts one down -- which for a camera means the LENS looks
## at the pilot, because the shot somebody places a camera in their own cockpit to get is themselves
## flying it. Turn it round afterwards by picking it up.
func faces_the_eye() -> bool:
	return true


## Nothing about a camera is a throttle. Said out loud because the base class reads `value.y` and a
## camera's value never means anything.
func throttle() -> float:
	return 0.0
