@tool
extends VehicleControl
class_name TrimWheel
## THE TRIM WHEEL: a wheel beside your hip that you ROLL, and that shows you where it is.
##
## Trim is where the elevator sits when nobody is touching the stick. Wind it forward and
## the nose drops and stays dropped; wind it back and the aeroplane holds a climb on its
## own. It is the difference between flying an approach and holding an approach.
##
## ---------------------------------------------------------------------------------
## IT DID NOTHING AT ALL, AND THAT IS WHY IT WAS HARD TO UNDERSTAND
## ---------------------------------------------------------------------------------
##
## `trim` was on the command bus from the beginning. It was replicated, both pilots could
## read it, a panel drew it -- and nothing in the flight model had ever heard of it. See
## `kTrimAuthority` in cockpit_world.cpp, which is where it finally reaches the elevator.
##
## No label fixes a control with no effect. The wheel is second; the effect is first.
##
## ---------------------------------------------------------------------------------
## A WHEEL AND NOT A LEVER
## ---------------------------------------------------------------------------------
##
## Every other latched control in this cockpit is a lever on a rail, and trim is the one
## that should not be. A wheel gives you TURNS: the hand rolls it, lets go, takes a fresh
## grip and rolls again, so a long travel costs no room at all -- which is exactly what a
## control wants when it has to be fine near the middle and still reach a long way out.
## Real aeroplanes use a wheel for this and it is not decoration.
##
## AND THE WHEEL IS ITS OWN INSTRUMENT. It carries a painted stripe and a fixed pointer, so
## where the trim IS, is something you read off the thing you are holding rather than off a
## screen on the other side of the cockpit. A control whose state you have to look up
## somewhere else is a control you never learn the feel of.

## THE NEUTRAL IS IN THE MIDDLE, which is the one thing about this channel that is not like
## the others. The bus carries 0..range and the simulation folds it onto -1..+1, so half of
## the travel is nose-down and half is nose-up and the centre is hands-off level.
const CENTRE: float = 0.5

## How big the wheel is, and how thick.
const RADIUS: float = 0.062
const RIM: float = 0.020
## HOW MANY TURNS FROM STOP TO STOP. Two and a half, which is what makes it a wheel rather
## than a knob: fine enough near the middle to hold a cruise, long enough that the ends are
## somewhere you have to wind to rather than somewhere you arrive by accident.
const TURNS: float = 2.5

var _rim: MeshInstance3D = null
var _stripe: MeshInstance3D = null
var _pointer: MeshInstance3D = null


func label_text() -> String:
	return "TRIM\nNOSE UP / DOWN"


func _build() -> void:
	control_name = "trim"
	scope = Scope.CRAFT
	channel = Sim.Channel.TRIM
	# The bus fits this at 255, and the console sets it from the craft; this is the default
	# for a wheel built with nobody to ask.
	channel_range = 255
	value = Vector2(0.0, CENTRE)
	# THE WHEEL, lying in the fore-and-aft plane so it rolls the way the nose moves: roll
	# the top of it forward and the nose goes down. A wheel mounted the other way round is
	# one every pilot winds the wrong way exactly once.
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = RIM
	disc.radial_segments = 20
	_rim = _make_mesh(disc, Color(0.16, 0.16, 0.19), Vector3.ZERO)
	_rim.rotation = Vector3(0.0, 0.0, PI * 0.5)
	# A PAINTED STRIPE, so the wheel says where it is. Without it a wheel is a disc, and a
	# disc turning is a thing you cannot see turn.
	var mark := BoxMesh.new()
	mark.size = Vector3(RIM + 0.004, RADIUS * 0.9, 0.008)
	_stripe = _make_mesh(mark, Color(0.92, 0.80, 0.26), Vector3.ZERO)
	# AND A FIXED POINTER BESIDE IT, because a stripe alone tells you the wheel moved and
	# not where it has got to. The pointer does not turn; the stripe lines up with it at
	# neutral, and that is the position a hand can find without looking.
	var nib := BoxMesh.new()
	nib.size = Vector3(RIM + 0.010, 0.016, 0.008)
	_pointer = _make_mesh(nib, Color(0.85, 0.86, 0.88),
		Vector3(0.0, RADIUS + 0.012, 0.0))


## The rim, which is where a hand takes hold of a wheel.
func _grab_point() -> Vector3:
	return Vector3(0.0, 0.0, 0.0)


func _redraw() -> void:
	if _stripe == null:
		return
	# THE WHOLE TRAVEL IS `TURNS` REVOLUTIONS, so the stripe sweeps round and round and the
	# ends are a long way apart in the hand while costing nothing in the cockpit.
	var turned: float = (clampf(value.y, 0.0, 1.0) - CENTRE) * TAU * TURNS
	_stripe.position = Vector3(0.0, cos(turned) * RADIUS * 0.55,
		sin(turned) * RADIUS * 0.55)
	_stripe.rotation = Vector3(-turned, 0.0, 0.0)


## ROLLED, NOT SLID. The hand's fore-and-aft travel across the rim is what turns it, which
## is the motion a wheel by your hip actually takes.
##
## Scaled by the rim so that moving your hand one rim-length turns it one radian: a wheel
## that needed a metre of hand travel per revolution would be a lever with a round handle.
func _drag(at: Vector3) -> void:
	var rolled: float = -_hand_travel(at).z / (RADIUS * TAU * TURNS)
	_settle(Vector2(0.0, clampf(_grab_value().y + rolled, 0.0, 1.0)))


## BACK TO HANDS-OFF LEVEL, for the binding that resets it. See `bindings`.
func centre() -> void:
	_settle(Vector2(0.0, CENTRE))


## WHERE THE TRIM IS, as -1 nose down to +1 nose up. What a panel shows and what the
## simulation folds the channel onto.
func setting() -> float:
	return (clampf(value.y, 0.0, 1.0) - CENTRE) * 2.0


## THE MINI JOYSTICK WINDS IT, AND PRESSING THAT JOYSTICK IN CENTRES IT.
##
## A hand already on the wheel does not need the binding; this is for the hand on the STICK,
## which is where trim is actually wanted -- you trim while you are flying, to take the load
## off the arm that is flying. See FlightStick, which binds the same two.
##
## Pressing the stick in to reset is the one gesture nobody has to be taught: it is what
## every thumbstick in every game does, and a trim you cannot quickly undo is a trim people
## are afraid to touch.
func bindings() -> Dictionary:
	return {
		Bind.STICK: Bind.axis("trim_rate", 1.0, 1),
		Bind.STICK_CLICK: Bind.command(Sim.Channel.TRIM, neutral(channel_range)),
	}


## HANDS-OFF LEVEL, as the command a channel `top` counts wide is sent. ONE PLACE: the stick typed 128 for this while the
## wheel worked it out, and the two agreed only because every trim channel happens to be 255 wide.
##
## Not quite zero on the aircraft: the server folds the byte as `v / 127.5 - 1`, so 128 is +0.0039 of trim. See
## agents.md, "A switch on the craft shows the craft".
static func neutral(top: int) -> int:
	return int(round(CENTRE * float(maxi(top, 0))))
