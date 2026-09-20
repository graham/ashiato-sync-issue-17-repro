extends PilotRig
class_name MarshalRig
## THE SAME PLAYER, STANDING UP.
##
## `PilotRig` is inherited rather than copied, and that is the whole design of this file. It
## already knows how to enter XR exactly once (a bug that cost a whole render target the
## first time it was got wrong), which tracker is which hand, how to bind the actions and
## how to fall back to a desktop camera. None of that is about cockpits, and none of it is
## worth having a second, subtly different copy of.
##
## TWO things are different about a marshaller, and they are the only two methods here that
## override anything:
##
##   `_seat_the_head`   does NOTHING. A pilot is SAT DOWN: the play space drops until the
##                      player's eyes are where the cockpit was authored for them, which is
##                      right in a cockpit and wrong on a deck. A marshaller stands on the
##                      floor at their own height, and the zones are measured from their own
##                      shoulders, so moving the floor would move every target with it.
##
##   `_place_desktop_rig`  puts the hands where the MOUSE says instead of on the controls.
##                      Without it a desktop player has both hands welded in front of their
##                      face and can make exactly one signal: none.
##
## Everything else is inherited and works: `_work_the_controls` finds no `VehicleControl` in
## reach and returns on its first line, and `Sim.set_input` with no session merges a
## dictionary nobody reads.

## A STANDING adult's eyes, not `CockpitStation.EYE_HEIGHT`, which is a seated 1.35.
const STAND_EYE: float = 1.62
## How far down a crouch goes. Enough to put a hand on the deck, which is a real signal:
## the catapult officer touches the deck before pointing at the bow.
const CROUCH: float = 0.62
## Mouse to arms, in radians per pixel. Slower than the head, because an arm has further to
## travel across a zone than the eye does across a screen.
const AIM_SENS: float = 0.0035
## How far out a hand may be pushed, in reaches. Past 1.0 because `knee` is further from the
## shoulders than a straight arm sideways is.
const NEAR: float = 0.35
const FAR: float = 1.25

## Where each hand is pointing: azimuth from straight ahead, elevation, and how far out. In
## the BODY frame, and mirrored for the left hand -- so "both hands" means both arms doing
## the same thing, which is what nearly every signal in the book asks for.
var _aim: Array[Vector3] = [Vector3(0.5, -0.9, 0.95), Vector3(0.5, -0.9, 0.95)]


func _ready() -> void:
	super()
	# NO FLIGHT HUD. It is head-locked, it is inherited, and with no vehicle to report on it
	# hangs the words "waiting for a seat" in the middle of a flight deck. A marshaller is
	# not waiting for a seat; a marshaller has the better job.
	if hud != null:
		hud.visible = false
	# AND LOOKING SLIGHTLY DOWN, on a monitor. A marshaller watches a nosewheel and their
	# own hands, both of which are below the horizon; a desktop view pinned level starts
	# with the board off the bottom of the screen. In a headset this does nothing -- the
	# neck is the neck.
	_look_pitch = deg_to_rad(-11.0)


## A MARSHALLER STANDS. See the note at the top: this is the seated-pilot behaviour, deleted.
func _seat_the_head() -> void:
	pass


## THE MOUSE IS YOUR ARMS.
##
##   move the mouse        both arms sweep together, mirrored
##   hold Q / hold E       one arm only, the other stays where you left it
##   wheel                 how far out the hands are held
##   left button           clench your fists
##   shift                 turn the hands to point up -- a thumbs-up
##   ctrl                  crouch, which is the only way to reach the deck
##   right button          look around instead of moving your arms
##
## It is not a headset and it is not meant to feel like one. It exists so that every signal
## in the book can be made, watched and debugged on a monitor -- and so the levels can be
## played at all by somebody who has not got the hardware out.
func _place_desktop_rig() -> void:
	var eye: float = STAND_EYE - (CROUCH if Input.is_key_pressed(KEY_CTRL) else 0.0)
	desktop_camera.position = Vector3(0.0, eye, 0.0)
	desktop_camera.rotation = Vector3(_look_pitch, _look_yaw, 0.0)

	# The same frame the reader builds: the head dropped by a neck, yaw only. Built here as
	# well rather than asked for, because the rig must not depend on a level having put a
	# reader in the scene -- and it is three lines.
	var shoulders := Transform3D(Basis(Vector3.UP, _look_yaw),
		Vector3(0.0, eye - SignalZones.NECK, 0.0))
	var pointing_up: bool = Input.is_key_pressed(KEY_SHIFT)
	for hand in range(2):
		var node: XRController3D = left_hand if hand == SignalZones.LEFT else right_hand
		var aim: Vector3 = _aim[hand]
		var side: float = 1.0 if hand == SignalZones.RIGHT else -1.0
		var away: Vector3 = _direction(aim.x * side, aim.y)
		var at: Vector3 = away * aim.z * SignalZones.NOMINAL_REACH
		# The hand POINTS where the arm is reaching, unless the wrist is turned up. Which
		# way a hand is pointing is all a controller can say about a thumbs-up, and the
		# reader reads exactly this.
		var facing: Vector3 = Vector3.UP if pointing_up else away
		node.transform = shoulders * Transform3D(_looking(facing), at)


## PUT A HAND AT A POINT IN THE BODY FRAME, by working the aim backwards out of it.
##
## The mouse gives an azimuth, an elevation and a reach; a zone is a position. This is the
## conversion between the two, and it exists so a test can drive the desktop rig to a NAMED
## zone and then ask the reader what it thinks the hand is in -- which is the one loop that
## a test putting hands straight into the reader cannot check, because both ends of it would
## be wrong together.
func point_at(hand: int, at: Vector3) -> void:
	var out: float = at.length() / SignalZones.NOMINAL_REACH
	var flat: float = maxf(Vector2(at.x, at.z).length(), 0.0001)
	var side: float = 1.0 if hand == SignalZones.RIGHT else -1.0
	_aim[hand] = Vector3(atan2(at.x * side, -at.z), atan2(at.y, flat),
		clampf(out, NEAR, FAR))


## Azimuth from straight ahead and elevation, as a unit vector. Forward is -Z, so a hand
## straight out in front is azimuth zero.
static func _direction(azimuth: float, elevation: float) -> Vector3:
	return Vector3(sin(azimuth) * cos(elevation), sin(elevation),
		-cos(azimuth) * cos(elevation))


## A basis whose -Z points that way, which is the convention every pose in Godot uses and
## the one the reader's palm test reads.
static func _looking(facing: Vector3) -> Basis:
	var up: Vector3 = Vector3.UP if absf(facing.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	return Basis.looking_at(facing, up)


## THE GRIP, WHICH DESKTOP OTHERWISE HAS NOT GOT.
##
## `read_controls` zeroes both grips and then fills them from the controllers, so on a
## monitor they are always zero and half the book -- everything with a fist in it -- can
## never be made. The left mouse button is the fist.
func read_controls() -> Dictionary:
	var frame: Dictionary = super()
	if using_desktop:
		var squeezed: float = 1.0 if Input.is_mouse_button_pressed(
			MOUSE_BUTTON_LEFT) else 0.0
		# Whichever arms the mouse is moving, so holding one arm still with Q or E holds
		# its hand open too. Which is what the standard asks for: the free arm is DOWN and
		# doing nothing while the other one sets the brakes.
		for hand in _moving():
			if hand == SignalZones.LEFT:
				grip_left = squeezed
			else:
				grip_right = squeezed
	return frame


func _unhandled_input(event: InputEvent) -> void:
	if using_desktop and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion \
				and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_sweep((event as InputEventMouseMotion).relative)
			get_viewport().set_input_as_handled()
			return
		var click := event as InputEventMouseButton
		if click != null and click.pressed and (click.button_index == MOUSE_BUTTON_WHEEL_UP
				or click.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_stretch(0.06 if click.button_index == MOUSE_BUTTON_WHEEL_UP else -0.06)
			get_viewport().set_input_as_handled()
			return
	super(event)


func _sweep(by: Vector2) -> void:
	for hand in _moving():
		var aim: Vector3 = _aim[hand]
		_aim[hand] = Vector3(
			clampf(aim.x + by.x * AIM_SENS, deg_to_rad(-140.0), deg_to_rad(140.0)),
			clampf(aim.y - by.y * AIM_SENS, deg_to_rad(-95.0), deg_to_rad(95.0)),
			aim.z)


func _stretch(by: float) -> void:
	for hand in _moving():
		var aim: Vector3 = _aim[hand]
		_aim[hand] = Vector3(aim.x, aim.y, clampf(aim.z + by, NEAR, FAR))


## Which arms the mouse is moving. Both, unless one is being held still on purpose.
func _moving() -> Array[int]:
	if Input.is_key_pressed(KEY_Q):
		return [SignalZones.LEFT]
	if Input.is_key_pressed(KEY_E):
		return [SignalZones.RIGHT]
	return [SignalZones.LEFT, SignalZones.RIGHT]
