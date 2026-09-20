@tool
extends VehicleControl
class_name AirbrakeLever
## THE AIRBRAKE LEVER in a sailplane: a blue handle on the left wall, pulled back to open the airbrakes.
##
## THE ONLY SPEED CONTROL A GLIDER HAS, and the one it lands with. A glider floats: at 45 to 1 it covers nearly a
## kilometre and a half from 30 m up, so the approach is flown high and the height is thrown away with the brakes, and
## that is a lever the left hand holds for the whole of the final approach. Pulled back is open, which is how every
## glider's is, and it is BLUE: the cockpit colour code sailplanes are certified to (EASA CS-22.780) makes the airbrake
## handle blue, the tow release yellow, the canopy release red and the trim green, so it is found without reading.
##
## IN BOTH SEATS, as the trim is: the channel is the aircraft's and either pilot may work it, and a trainer's back seat
## is where the instructor lands it from.
##
## TWO POSITIONS, because the bus carries one bit (`kSpoilerBit`): shut or open. A handle left halfway would promise a
## setting the aeroplane does not have, so it snaps, as the tank doors do (`DropLever`).

## How far the handle travels, in metres, from shut at the front to open pulled back.
const TRAVEL: float = 0.16
## How far the hand has to drag before it flips.
const SNAP: float = 0.5
## How far up the stalk the grip is.
const STALK: float = 0.12
const BLUE := Color(0.16, 0.36, 0.82)

var _arm: MeshInstance3D = null
var _knob: MeshInstance3D = null


func label_text() -> String:
	return "AIRBRAKES"


func _build() -> void:
	control_name = "airbrakes"
	scope = Scope.CRAFT
	channel = Sim.Channel.SPOILERS
	channel_range = 1
	var rail := BoxMesh.new()
	rail.size = Vector3(0.03, 0.02, TRAVEL + 0.05)
	_make_mesh(rail, Color(0.12, 0.13, 0.15), Vector3.ZERO)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.018, STALK, 0.018)
	_arm = _make_mesh(arm, Color(0.20, 0.21, 0.23), Vector3.ZERO)
	# A ROUND-ENDED BAR across the top, found by feel: the glider's brake handle is a fat blue grip.
	var grip := BoxMesh.new()
	grip.size = Vector3(0.06, 0.034, 0.034)
	_knob = _make_mesh(grip, BLUE, Vector3.ZERO)
	_redraw()


func _grab_point() -> Vector3:
	return Vector3(0.0, STALK, TRAVEL * (clampf(value.y, 0.0, 1.0) - 0.5))


func _redraw() -> void:
	if _knob == null:
		return
	var top: Vector3 = _grab_point()
	_knob.position = top
	_arm.position = top * 0.5


## PULLED BACK IS OPEN: +Z is toward the pilot.
func _drag(at: Vector3) -> void:
	var pulled: float = _hand_travel(at).z / TRAVEL
	var dragged: float = clampf(_grab_value().y + pulled, 0.0, 1.0)
	_settle(Vector2(0.0, 1.0 if dragged > SNAP else 0.0))


func is_open() -> bool:
	return value.y >= 0.5


func throttle() -> float:
	return 0.0
