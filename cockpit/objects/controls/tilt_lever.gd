@tool
extends VehicleControl
class_name TiltLever
## THE NACELLES: the one control on a tiltrotor that changes what kind of aircraft it is.
##
## Forward at the bottom of its travel and the machine is an aeroplane whose propellers
## happen to be enormous. Back at the top and it is a helicopter with a wing making nothing.
## Everything between is a continuous blend, which is why this is a lever with travel in it
## rather than a switch with two positions.
##
## It moves the way the nacelles do -- an arc, hinged like them -- so a hand on it is doing
## the same thing the aircraft is. That is worth the arithmetic: a slider would work and
## would say nothing.
##
## LATCHED, and it has to be. It lives on the command bus beside the flaps and the gear
## because it is a CONFIGURATION: it stays where it is put, the physics reads it, and both
## pilots have to be able to see it. A tiltrotor whose nacelles were a momentary demand
## would fall out of the sky the instant a packet went missing.

## How far the handle swings, in radians, matching the nacelles' own 97.5 degrees.
const SWING: float = 1.702
## How long the handle is from its hinge to the grip, in metres.
const ARM: float = 0.13

var _arm: MeshInstance3D = null
var _grip: MeshInstance3D = null
var _gate: MeshInstance3D = null


func label_text() -> String:
	return "NACELLES\nPLANE / HELI"


func _build() -> void:
	control_name = "nacelles"
	scope = Scope.CRAFT
	channel = Sim.Channel.TILT
	channel_range = 255
	var mount := BoxMesh.new()
	mount.size = Vector3(0.055, 0.05, 0.05)
	_make_mesh(mount, Color(0.13, 0.14, 0.16), Vector3.ZERO)
	# A quadrant behind it, so where the travel ENDS is visible without moving the handle.
	var gate := BoxMesh.new()
	gate.size = Vector3(0.012, ARM * 1.5, ARM * 1.5)
	_gate = _make_mesh(gate, Color(0.10, 0.11, 0.13),
		Vector3(-0.035, ARM * 0.35, -ARM * 0.35))
	var arm := BoxMesh.new()
	arm.size = Vector3(0.028, 0.028, ARM)
	_arm = _make_mesh(arm, Color(0.22, 0.23, 0.26), Vector3.ZERO)
	var grip := SphereMesh.new()
	grip.radius = 0.030
	grip.height = 0.060
	# Grey-green, and the only control in any of these cockpits that is.
	_grip = _make_mesh(grip, Color(0.44, 0.60, 0.44), Vector3.ZERO)


## HOW FAR ROUND IT IS. Forward is the bottom of the travel, so zero leaves the handle
## lying along the nose exactly as the nacelles do.
func _swung() -> Basis:
	return Basis(Vector3.RIGHT, SWING * clampf(value.y, 0.0, 1.0))


func _grab_point() -> Vector3:
	return _swung() * Vector3(0.0, 0.0, -ARM)


func _redraw() -> void:
	if _grip == null:
		return
	var swung: Basis = _swung()
	_arm.transform = Transform3D(swung, swung * Vector3(0.0, 0.0, -ARM * 0.5))
	_grip.transform = Transform3D(swung, swung * Vector3(0.0, 0.0, -ARM))


## ROUND THE ARC, measured as an ANGLE and not as a distance.
##
## The handle sweeps from lying forward to standing up, so near the bottom the hand is
## mostly moving fore and aft and near the top mostly up and down. Reading one axis of the
## hand's travel would make the lever fight the hand over half its range; reading the angle
## the hand has swung THROUGH does not care where in the arc it is.
func _drag(at: Vector3) -> void:
	var here: float = atan2(at.y, -at.z)
	var was: float = atan2(_grabbed_at.y, -_grabbed_at.z)
	var wanted := Vector2(0.0,
		clampf(_grab_value().y + (here - was) / SWING, 0.0, 1.0))
	_settle(wanted)


## Where the nacelles are, 0 forward and 1 up. NOT a throttle: this control opens nothing.
func tilt() -> float:
	return clampf(value.y, 0.0, 1.0)


func throttle() -> float:
	return 0.0
