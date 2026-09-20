@tool
extends VehicleControl
class_name ControlYoke
## A TRADITIONAL YOKE: a column you pull and a wheel you turn, one at each seat.
##
## Mechanically the same two axes as a stick and completely different to fly. A stick
## pivots at its base and answers a wrist; a yoke slides fore and aft on a column and turns
## about it, and takes two hands and a shoulder.
##
## Both yokes on a flight deck are on ONE LINKAGE, so both show the same position -- see
## `apply()` and the note on CrewControls. That is what lets a copilot sit with their hands
## in their lap and watch the yoke in front of them move with the pilot's.

## A YOKE IS A CONTROL COLUMN WITH A DIFFERENT SHAPE ROUND IT, so it flies with the same
## fingers. See FlightStick.column_bindings.
func bindings() -> Dictionary:
	return FlightStick.column_bindings(trim_range)


## HOW FAR THIS SEAT MAY TRIM THE CRAFT, or 0 where it may not. See `FlightStick.trim_range`.
var trim_range: int = 0


## How far the column travels fore and aft, in metres.
const TRAVEL: float = 0.16
## How far the wheel turns at full deflection, in radians.
const WHEEL: float = 1.25
## A yoke has friction and a light spring. It does not snap to centre the way a stick does,
## and it does not stay where it is put either.
const CENTRING: float = 2.2
## How far the RIM stands out from the mount, centred. What you hold is here, so this is
## how much further back than your hand the yoke has to be mounted.
const COLUMN: float = 0.17

var _column: MeshInstance3D = null
var _wheel: Node3D = null


## Same two axes as a stick, in a shape that hides it even better: a wheel reads as
## steering until you are told otherwise.
func label_text() -> String:
	return "YOKE\nPITCH / ROLL"


func _build() -> void:
	control_name = "yoke"
	scope = Scope.SEAT
	centring = CENTRING
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.022
	shaft.bottom_radius = 0.026
	shaft.height = 0.34
	_column = _make_mesh(shaft, Color(0.15, 0.16, 0.19), Vector3.ZERO)
	_column.rotation = Vector3(PI * 0.5, 0.0, 0.0)

	_wheel = Node3D.new()
	add_child(_wheel)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.10
	rim.outer_radius = 0.125
	var hoop := MeshInstance3D.new()
	hoop.mesh = rim
	hoop.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	var grip := StandardMaterial3D.new()
	grip.albedo_color = Color(0.10, 0.10, 0.12)
	grip.roughness = 0.7
	hoop.material_override = grip
	_wheel.add_child(hoop)
	var spoke := BoxMesh.new()
	spoke.size = Vector3(0.22, 0.02, 0.03)
	var bar := MeshInstance3D.new()
	bar.mesh = spoke
	bar.material_override = grip
	_wheel.add_child(bar)


## HOW FAR OUT THE RIM SITS at this deflection. Pulling BACK is nose up, so a positive
## pitch brings the wheel toward the pilot -- which is +Z, and therefore LESS far out along
## the column. Subtracting brought it toward the panel instead: the same inverted visual
## the stick had, on the control where it is most obvious.
func _out() -> float:
	return -COLUMN + TRAVEL * 0.5 * value.y


## The rim, which is what a hand actually takes hold of.
func _grab_point() -> Vector3:
	return Vector3(0.0, 0.0, _out())


func _redraw() -> void:
	if _wheel == null:
		return
	var out: float = _out()
	_column.position = Vector3(0.0, 0.0, out * 0.5)
	_wheel.position = Vector3(0.0, 0.0, out)
	# Turning the wheel right is a right roll, which is a positive value.
	_wheel.rotation = Vector3(0.0, 0.0, -value.x * WHEEL)


func _drag(at: Vector3) -> void:
	var travel: Vector3 = _hand_travel(at)
	var wanted := Vector2(
		clampf(_grab_value().x + travel.x / 0.16, -1.0, 1.0),
		# Pulling back is +Z here and nose up is +1.
		clampf(_grab_value().y + travel.z / TRAVEL, -1.0, 1.0))
	_settle(wanted)



