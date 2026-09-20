@tool
extends VehicleControl
class_name PlungerThrottle
## THE PLUNGER in the middle of a light aeroplane's panel: pushed IN for power and pulled
## OUT to close it.
##
## Not a lever on a quadrant. A Cessna's throttle is a shaft through the instrument panel
## with a knob on the end, and it moves along its own length toward and away from the
## pilots -- which is why both of them can reach it and why it lives in the middle of the
## panel rather than by anybody's hip.
##
## THE SENSE IS BACKWARDS FROM EVERYTHING ELSE and that is the aircraft, not a mistake. In
## goes to full power, out closes it, so the knob is CLOSEST to the pilot when the engine is
## doing least. A lever that opened as you pulled it toward you would be a different
## aeroplane.
##
## Latched, like every throttle: it stays where it is put, which is why it is on the command
## bus and why letting go of it in the cruise leaves you in the cruise.

## How far it travels, in metres, from shut to fully in.
const TRAVEL: float = 0.11
## How long the shaft is behind the knob.
const SHAFT: float = 0.14

var _knob: MeshInstance3D = null
var _shaft: MeshInstance3D = null


## A PLUNGER IS A THROTTLE, and the hand on it wants the flaps and the gear exactly as the
## hand on a quadrant lever does. See ThrottleLever.throttle_bindings.
func bindings() -> Dictionary:
	return ThrottleLever.throttle_bindings()


func _build() -> void:
	control_name = "throttle"
	scope = Scope.SEAT
	var plate := BoxMesh.new()
	plate.size = Vector3(0.075, 0.075, 0.014)
	_make_mesh(plate, Color(0.12, 0.13, 0.15), Vector3.ZERO)
	var rod := CylinderMesh.new()
	rod.top_radius = 0.011
	rod.bottom_radius = 0.011
	rod.height = SHAFT
	_shaft = _make_mesh(rod, Color(0.55, 0.56, 0.58), Vector3.ZERO)
	_shaft.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	var knob := CylinderMesh.new()
	knob.top_radius = 0.030
	knob.bottom_radius = 0.026
	knob.height = 0.030
	# BLACK, which is what a throttle knob is, and the reason every other knob in a light
	# aeroplane is a different colour and shape: you find them by feel.
	_knob = _make_mesh(knob, Color(0.08, 0.08, 0.09), Vector3.ZERO)
	_knob.rotation = Vector3(PI * 0.5, 0.0, 0.0)


## HOW FAR OUT THE KNOB IS. Shut is fully out, toward the pilot, which is +Z.
func _out() -> float:
	return SHAFT * (1.0 - clampf(value.y, 0.0, 1.0)) + 0.02


func _grab_point() -> Vector3:
	return Vector3(0.0, 0.0, _out())


func _redraw() -> void:
	if _knob == null:
		return
	var out: float = _out()
	_knob.position = Vector3(0.0, 0.0, out)
	_shaft.position = Vector3(0.0, 0.0, out * 0.5)


## PUSHED AND PULLED ALONG ITS OWN LENGTH. Only the fore-and-aft travel of the hand counts:
## a knob on a shaft does not go anywhere else, and reading a sideways nudge as power would
## make it a control that answers movements it cannot make.
func _drag(at: Vector3) -> void:
	var travel: Vector3 = _hand_travel(at)
	# Pushing IN is -Z and opens it, so the sign is the opposite of the lever's.
	var wanted := Vector2(0.0, clampf(_grab_value().y - travel.z / TRAVEL, 0.0, 1.0))
	_settle(wanted)
