@tool
extends VehicleControl
class_name HookLever
## THE ARRESTING HOOK'S HANDLE: a striped bar in a vertical slot, down for the hook down.
##
## A CARRIER AEROPLANE'S, and only a carrier aeroplane's. It stands on the console of a craft whose bus is fitted with
## `Channel::Hook` -- the F/A-18F and the E-2D -- and nowhere else, for the same reason the flap gate and the gear lever
## do: a handle for a channel the aircraft has not got is a dead handle, which is worse than no handle.
##
## DOWN IS DOWN, as on the gear lever beside it, because both mean "put the thing out" and a crew that has learnt one has
## learnt the other. What tells them apart in the hand is the KNOB: the gear's is a wheel, because it lowers wheels; this
## is a bar banded in black and yellow, which is how a hook handle is painted. A hand reaching without looking finds the
## shape, never the label.
##
## TWO POSITIONS, not a travel, exactly as the gear lever has: the bus carries a bit. When the hook grows a transit --
## the simulation owning the travel, see cockpit/actuators_research.md -- this becomes a lever with real travel and the
## bit becomes a position, and nothing here has to change for that.
##
## A CRAFT CONTROL, not a seat's: either crew may put the hook down, which is what a console is for.

## How far the handle travels, in metres, from stowed at the top to down at the bottom.
const TRAVEL: float = 0.10
## How far past halfway the hand must drag before it flips. A handle left between two positions has lied to somebody.
const SNAP: float = 0.5

## The bar and its two painted bands, moved together.
var _knob: Array[MeshInstance3D] = []
var _offsets: Array[Vector3] = []


func _build() -> void:
	control_name = "hook"
	scope = Scope.CRAFT
	channel = Sim.Channel.HOOK
	# ONE, because the bus carries a bit. See craft_schema: Fitted{"hook", 1}.
	channel_range = 1
	# THE SLOT, so where the travel ends is visible without moving the handle.
	var slot := BoxMesh.new()
	slot.size = Vector3(0.028, TRAVEL + 0.06, 0.014)
	_make_mesh(slot, Color(0.10, 0.11, 0.13), Vector3.ZERO)
	var bar := BoxMesh.new()
	bar.size = Vector3(0.074, 0.026, 0.026)
	_knob.append(_make_mesh(bar, Color(0.11, 0.11, 0.12), Vector3.ZERO))
	_offsets.append(Vector3.ZERO)
	for side in [-1.0, 1.0]:
		var band := BoxMesh.new()
		band.size = Vector3(0.020, 0.028, 0.028)
		_knob.append(_make_mesh(band, Color(0.90, 0.72, 0.06), Vector3(side * 0.027, 0.0, 0.0)))
		_offsets.append(Vector3(side * 0.027, 0.0, 0.0))
	_redraw()


## 1 is the hook DOWN and puts the handle at the bottom of its slot; 0 stows it at the top.
func _grab_point() -> Vector3:
	return Vector3(0.0, TRAVEL * (0.5 - clampf(value.y, 0.0, 1.0)), 0.0)


func _redraw() -> void:
	for index in range(_knob.size()):
		if _knob[index] != null:
			_knob[index].position = _offsets[index] + _grab_point()


## The hand's VERTICAL travel, snapped to one end: down the slot raises the value, because 1 on the bus is hook down.
func _drag(at: Vector3) -> void:
	var pushed: float = -_hand_travel(at).y / TRAVEL
	var dragged: float = clampf(_grab_value().y + pushed, 0.0, 1.0)
	_settle(Vector2(0.0, 1.0 if dragged > SNAP else 0.0))


## Whether the hook is selected DOWN, which is what 1 on the bus means.
func is_down() -> bool:
	return value.y >= 0.5


## Not a throttle. The rig asks every control this, and a lever that opens nothing says so.
func throttle() -> float:
	return 0.0
