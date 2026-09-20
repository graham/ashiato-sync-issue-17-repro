@tool
extends VehicleControl
class_name CollectiveLever
## A COLLECTIVE: the lever at a helicopter pilot's left hand, PULLED UP rather than pushed
## forward.
##
## It is not a throttle and it does not move like one. A throttle slides fore and aft along
## a quadrant and asks an engine for more power; a collective is an arm hinged at the floor
## beside the seat, and raising it increases the pitch of every rotor blade at once -- which
## is where the name comes from, and why the machine climbs the moment you lift it. The
## engine underneath is held at governed speed and is not what the pilot's hand is on.
##
## Mechanically that makes it the same one latched axis as a throttle, moved in a completely
## different direction, and the direction is the whole point: a hand that pulls UP for lift
## and pushes DOWN to descend is the muscle memory a helicopter needs. Sliding a knob
## forward for it teaches the wrong thing.
##
## Latched, like every lever: it stays where it is put, which is why it lives on the command
## bus rather than on the input frame. Let go of a collective in the hover and the
## helicopter stays in the hover.

## How long the arm is from its hinge to the grip, in metres.
const ARM: float = 0.34
## How far it swings from fully down to fully up, in radians.
const SWING: float = 0.60

## How far the grip actually rises over that swing. What the hand has to travel.
static func rise() -> float:
	return ARM * sin(SWING)

var _arm: MeshInstance3D = null
var _grip: MeshInstance3D = null


## A COLLECTIVE IS THE HAND THAT IS ALREADY ON THE POWER, which is what the throttle table
## is for -- and a helicopter simply is not fitted with most of what it offers, so those
## buttons do nothing rather than something wrong. See ThrottleLever.throttle_bindings.
func bindings() -> Dictionary:
	return ThrottleLever.throttle_bindings()


## It is not a throttle and it does not behave like one -- see the note at the top of
## this file -- and a label that only said COLLECTIVE would leave that to be discovered.
func label_text() -> String:
	return "COLLECTIVE\nCLIMB"


func _build() -> void:
	control_name = "collective"
	scope = Scope.SEAT
	var mount := BoxMesh.new()
	mount.size = Vector3(0.07, 0.09, 0.09)
	_make_mesh(mount, Color(0.13, 0.14, 0.16), Vector3.ZERO)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.035, 0.035, ARM)
	_arm = _make_mesh(arm, Color(0.20, 0.21, 0.24), Vector3.ZERO)
	var grip := CapsuleMesh.new()
	grip.radius = 0.026
	grip.height = 0.13
	_grip = _make_mesh(grip, Color(0.72, 0.62, 0.22), Vector3.ZERO)
	# The grip is a twist grip on a real one, lying along the arm rather than across it.
	_grip.rotation = Vector3(PI * 0.5, 0.0, 0.0)


## HOW FAR IT IS RAISED, as a rotation. Down is level and forward; up swings the grip
## toward the pilot's shoulder.
func _raised() -> Basis:
	return Basis(Vector3.RIGHT, SWING * clampf(value.y, 0.0, 1.0))


## The grip at the end of the arm, which is the only part of a collective anybody holds.
func _grab_point() -> Vector3:
	return _raised() * Vector3(0.0, 0.0, -ARM)


func _redraw() -> void:
	if _grip == null:
		return
	var swung: Basis = _raised()
	_arm.transform = Transform3D(swung, swung * Vector3(0.0, 0.0, -ARM * 0.5))
	_grip.transform = Transform3D(swung * Basis(Vector3.RIGHT, PI * 0.5),
		swung * Vector3(0.0, 0.0, -ARM))


## STRAIGHT UP AND DOWN, and only that. The grip also swings a little fore and aft as the
## arm goes over, but a pilot pulling a collective moves their hand vertically and it is
## the vertical travel that has to mean something -- taking the arc into account would make
## the lever fight the hand near the top of its swing, where the arc is mostly horizontal.
func _drag(at: Vector3) -> void:
	var travel: Vector3 = _hand_travel(at)
	var wanted := Vector2(0.0, clampf(_grab_value().y + travel.y / rise(), 0.0, 1.0))
	_settle(wanted)
