@tool
extends VehicleControl
class_name DropLever
## THE TANK DOORS on a water bomber: a red handle between the pilots, pulled to drop.
##
## THIS IS NOT A BUTTON, and the difference is the whole of what a drop run feels like. Six
## tonnes of water does not leave in an instant -- it takes five seconds with the doors open
## -- so what the pilot is doing is HOLDING the aeroplane over a fire while the load goes,
## and the control that says that is a handle that stays where it is put. A button would
## make the drop an event rather than a run.
##
## PULLED BACK IS OPEN, which is the way every emergency handle in an aircraft works and the
## reason this one is a handle rather than a switch: the hand movement is unmistakable, and
## it can be found without looking at fifty feet.
##
## ON THE CONSOLE, BETWEEN THE SEATS, because it belongs to the AIRCRAFT and not to either
## pilot -- like the flaps and the gear beside it. Either of them may pull it, which is what
## a crew is for: one flies the run and the other drops.
##
## RED, AND THE ONLY RED THING IN THIS COCKPIT. Everything else on the console is grey.

## How far the handle travels, in metres, from shut at the front to open pulled back.
const TRAVEL: float = 0.13
## How far the hand has to drag before it flips. A door that could be left half open would
## be promising a position the aeroplane does not have -- the bus carries one bit.
const SNAP: float = 0.5
## How far up the handle the grip is: this is a lever on a pivot at the console, and what a
## hand closes round is the knob on top of it.
const STALK: float = 0.16

var _arm: MeshInstance3D = null
var _knob: MeshInstance3D = null


func label_text() -> String:
	return "TANK DOORS"


func _build() -> void:
	control_name = "drop"
	scope = Scope.CRAFT
	channel = Sim.Channel.DROP
	# ONE, because the bus carries a bit: shut or open. See craft_schema.
	channel_range = 1
	var base := BoxMesh.new()
	base.size = Vector3(0.05, 0.03, TRAVEL + 0.06)
	_make_mesh(base, Color(0.10, 0.11, 0.13), Vector3.ZERO)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.022, STALK, 0.022)
	_arm = _make_mesh(arm, Color(0.18, 0.19, 0.21), Vector3.ZERO)
	# A T-HANDLE. Every handle in a cockpit is found by feel before it is found by eye, and
	# the shape of this one says "pull" from any angle.
	var grip := BoxMesh.new()
	grip.size = Vector3(0.10, 0.030, 0.034)
	_knob = _make_mesh(grip, Color(0.86, 0.21, 0.15), Vector3.ZERO)
	_redraw()


## THE KNOB, at the top of the arm and leaning with it. Forward when the doors are shut,
## back toward the crew when they are open.
func _grab_point() -> Vector3:
	return Vector3(0.0, STALK, TRAVEL * (clampf(value.y, 0.0, 1.0) - 0.5))


func _redraw() -> void:
	if _knob == null:
		return
	var top: Vector3 = _grab_point()
	_knob.position = top
	_arm.position = top * 0.5


## PULLED BACK IS OPEN. +Z is toward the crew, so a hand that drags the handle toward itself
## is asking for the water -- and that is the one thing about this control nobody should
## have to think about at fifty feet.
func _drag(at: Vector3) -> void:
	var pulled: float = _hand_travel(at).z / TRAVEL
	var dragged: float = clampf(_grab_value().y + pulled, 0.0, 1.0)
	_settle(Vector2(0.0, 1.0 if dragged > SNAP else 0.0))


## Whether the doors are open, which is what 1 on the bus means.
func is_open() -> bool:
	return value.y >= 0.5


## Not a throttle. Every control answers all five axes; this one opens nothing.
func throttle() -> float:
	return 0.0
