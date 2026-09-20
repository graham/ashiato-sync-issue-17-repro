@tool
extends VehicleControl
class_name ThrottleLever
## A THROTTLE, which is a lever and therefore LATCHED: it stays where you put it.
##
## That is the whole difference between a throttle and a stick, and it is why the throttle
## lives on the command bus as vehicle state while the stick does not. A stick springs back
## to centre when you let go; a lever does not, so its position has to be remembered
## somewhere, and the only somewhere everybody aboard can see is the wire.

## How far the lever travels, in metres, from closed to open.
const TRAVEL: float = 0.16

var _knob: MeshInstance3D = null


## THE THUMB WORKS THE FLAPS AND THE GEAR, which is where a hand that is already on the
## throttle can reach them without letting go of the power.
##
## The same two buttons trim the aeroplane when the hand is on the control column instead.
## That is the difference the per-control table exists for: the buttons have not changed and
## the aircraft has not changed, only what the hand is holding.
##
## STEPPED AND NOT SET, so one binding serves every aircraft. Flaps are four notches on an
## airliner and one switch on a gunship; `Bind.step` reads the range off the craft it is
## fitted to, so the button gives you the gate that aeroplane actually has.
##
## GEAR IS WRAPPED, which is how a two-position switch is toggled with one button: range 1
## wrapping means 0, 1, 0. On a Chinook the same channel is the ramp and on a tank it is the
## parking brake, and lowering all three from the throttle is right in every case.
func bindings() -> Dictionary:
	return throttle_bindings()


## STATIC, AND SHARED BY EVERY THROTTLE THERE IS. A quadrant lever, a Cessna's plunger and
## a helicopter's collective are three shapes of the same hand: the one that is already on
## the power when the flaps and the gear are wanted. Three copies of this table would drift
## apart, and the day one of them did, a pilot would find the gear had moved.
static func throttle_bindings() -> Dictionary:
	return {
		Bind.THUMB_HIGH: Bind.step(Sim.Channel.FLAPS, 1),
		Bind.THUMB_LOW: Bind.step(Sim.Channel.FLAPS, -1),
		Bind.STICK_CLICK: Bind.step(Sim.Channel.GEAR, 1, true),
	}


func _build() -> void:
	control_name = "throttle"
	scope = Scope.SEAT
	var base := BoxMesh.new()
	base.size = Vector3(0.05, 0.02, TRAVEL + 0.05)
	_make_mesh(base, Color(0.13, 0.14, 0.16), Vector3.ZERO)
	var knob := BoxMesh.new()
	knob.size = Vector3(0.04, 0.05, 0.045)
	_knob = _make_mesh(knob, Color(0.72, 0.62, 0.22), Vector3.ZERO)


## The knob, which slides along the quadrant as the lever moves.
func _grab_point() -> Vector3:
	return Vector3(0.0, 0.03, TRAVEL * (0.5 - value.y))


func _redraw() -> void:
	if _knob == null:
		return
	# 0 closed at the back, 1 open at the front. -Z is forward.
	_knob.position = Vector3(0.0, 0.03, TRAVEL * (0.5 - value.y))


## Fore and aft only. A throttle that answered sideways movement would be a stick.
func _drag(at: Vector3) -> void:
	var pushed: float = -_hand_travel(at).z / TRAVEL
	_settle(Vector2(0.0, clampf(_grab_value().y + pushed, 0.0, 1.0)))


## What the rig folds into its control frame: 0 to 1, the axis the wire already carries.
