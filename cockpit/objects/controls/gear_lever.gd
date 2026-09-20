@tool
extends VehicleControl
class_name GearLever
## THE UNDERCARRIAGE LEVER: a handle in a vertical slot with a wheel on the end of it.
##
## DOWN IS DOWN, which is the whole design. Push the handle to the bottom of its slot and
## the wheels come out; pull it to the top and they stow. Every aeroplane does it this way
## round and it is worth copying exactly, because the lever is then a PICTURE of the
## aircraft: a pilot glancing at it is checking the gear rather than reading a label.
##
## A slot and not an arc, unlike the nacelles beside it. The nacelle lever swings because
## the nacelles do, and a hand on it is doing what the aircraft is doing. Nothing about an
## undercarriage is an arc from the pilot's point of view -- it is in or it is out -- so the
## honest shape is the one that says up and down and nothing else.
##
## TWO POSITIONS, not a travel. The gear is a switch on the bus -- one bit, and the flight
## model reads it as a drag term that is either there or not -- so a handle that could rest
## halfway would be promising a position the aeroplane cannot hold. It follows the hand
## while it is dragged and settles at one end. When the gear grows a transit this becomes a
## lever with real travel and the bit becomes a float; until then the snap is the honest
## thing.
##
## A CENTRE-CONSOLE CONTROL: it belongs to the aircraft rather than to a seat, so either
## pilot may put the gear down. That is what a crew is for.

## How far the handle travels, in metres, from stowed at the top to down at the bottom.
const TRAVEL: float = 0.11
## How far past halfway the hand must drag before it flips. A gear lever that could be left
## between its two positions is a gear lever that has lied to somebody.
const SNAP: float = 0.5

var _knob: MeshInstance3D = null


func _build() -> void:
	control_name = "gear"
	scope = Scope.CRAFT
	channel = Sim.Channel.GEAR
	# ONE, because the bus carries a bit. See craft_schema: Fitted{"gear", 1}.
	channel_range = 1
	# THE SLOT, so where the travel ends is visible without moving the handle.
	var slot := BoxMesh.new()
	slot.size = Vector3(0.030, TRAVEL + 0.06, 0.014)
	_make_mesh(slot, Color(0.10, 0.11, 0.13), Vector3.ZERO)
	# A WHEEL, and not a ball. Every knob in a cockpit is found by feel, and the one that
	# puts the wheels down is shaped like one.
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.032
	wheel.bottom_radius = 0.032
	wheel.height = 0.018
	_knob = _make_mesh(wheel, Color(0.86, 0.86, 0.84), Vector3.ZERO)
	# Lying in the plane it would roll in, across the aeroplane.
	_knob.rotation = Vector3(0.0, 0.0, PI * 0.5)


## 1 is gear DOWN and puts the handle at the bottom of the slot; 0 stows it at the top.
func _grab_point() -> Vector3:
	return Vector3(0.0, TRAVEL * (0.5 - clampf(value.y, 0.0, 1.0)), 0.0)


func _redraw() -> void:
	if _knob == null:
		return
	_knob.position = _grab_point()


## The hand's VERTICAL travel, snapped to one end.
##
## Down the slot raises the value, because 1 on the bus is gear down. A hand that pushes the
## handle toward the floor is asking for the wheels, which is the one thing about this
## control nobody should have to think about.
func _drag(at: Vector3) -> void:
	var pushed: float = -_hand_travel(at).y / TRAVEL
	var dragged: float = clampf(_grab_value().y + pushed, 0.0, 1.0)
	_settle(Vector2(0.0, 1.0 if dragged > SNAP else 0.0))


## Whether the gear is selected DOWN, which is what 1 on the bus means.
func is_down() -> bool:
	return value.y >= 0.5


## Not a throttle. The rig asks every control this and a lever that opens nothing says so.
func throttle() -> float:
	return 0.0
