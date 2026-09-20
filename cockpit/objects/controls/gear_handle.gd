@tool
extends VehicleControl
class_name GearHandle
## THE FIGHTER'S GEAR HANDLE: a wheel on the end of an arm, on the left console, that you
## swing down for gear down -- and that lights up to tell you they are there.
##
## ---------------------------------------------------------------------------------
## WHY THIS IS NOT `GearLever`
## ---------------------------------------------------------------------------------
##
## `GearLever` is a knob in a vertical slot, which is what a transport has on the pedestal
## between the two pilots: it is shared, it is in the middle, and either pilot calls for
## gear. A fighter has one pilot and no pedestal. The handle goes on the LEFT console where
## the throttle hand already is, it is an ARM rather than a slider so that it can be found
## and thrown without looking down, and the throw is a swing because that is what an arm on
## a pivot does.
##
## Both are correct, for different aeroplanes. Keeping them as two classes rather than one
## with a flag is the same call the project already makes between a flap gate and a throttle
## quadrant: the shape IS the difference, and a shape behind an export is a shape nobody
## finds.
##
## ---------------------------------------------------------------------------------
## DOWN IS DOWN, AND THE KNOB IS A WHEEL, AND THE WHEEL LIGHTS UP
## ---------------------------------------------------------------------------------
##
## The first two are the rules `GearLever` already keeps and they are worth keeping
## identically: swinging the handle toward the floor puts the wheels out, and the thing on
## the end is shaped like the thing it lowers. A pilot glancing at it is CHECKING THE GEAR
## rather than reading a label.
##
## The third is the one that is particular to this handle. A fighter's is translucent with a
## lamp behind it, and that lamp is how the aircraft answers back: the handle says what you
## ASKED for, and the light says what you GOT. Here they cannot disagree yet -- the gear is
## a bit on the bus with no transit -- so the lamp follows the bus, which is still worth
## having, because what it reports is the SHARED state and not this hand's local idea of it.
## A copilot lowering the gear lights this handle.
##
## TWO POSITIONS AND NO HALFWAY, for the reason `GearLever` gives: the flight model reads
## the gear as a drag term that is either there or not, so a handle that could rest in the
## middle would be promising a position the aeroplane cannot hold.

## How long the arm is, in metres, from pivot to the middle of the wheel.
const ARM: float = 0.085
## Where the arm points with the gear UP and with it DOWN, in radians about the across axis.
##
## NOT VERTICAL TO HORIZONTAL. Up is a little forward of straight up so the handle is never
## edge-on from the seat, and down is past horizontal so that "down" is unmistakably down
## even seen from the corner of an eye.
const UP_AT: float = -0.35
const DOWN_AT: float = 1.30
## How far past halfway the hand must swing before it flips.
const SNAP: float = 0.5

var _arm: Node3D = null
var _wheel: MeshInstance3D = null


func label_text() -> String:
	return "GEAR\nUP / DOWN"


func _build() -> void:
	control_name = "gear"
	scope = Scope.CRAFT
	channel = Sim.Channel.GEAR
	# ONE, because the bus carries a bit. See craft_schema: Fitted{"gear", 1}.
	channel_range = 1
	# THE MOUNTING BLOCK the arm pivots in, so it reads as bolted to a console rather than
	# growing out of one.
	var block := BoxMesh.new()
	block.size = Vector3(0.030, 0.026, 0.034)
	_make_mesh(block, Color(0.11, 0.12, 0.14), Vector3(0.0, 0.013, 0.0))
	_arm = Node3D.new()
	_arm.name = "Arm"
	_arm.position = Vector3(0.0, 0.020, 0.0)
	add_child(_arm)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.008
	shaft.bottom_radius = 0.010
	shaft.height = ARM
	shaft.radial_segments = 12
	_under(_arm, shaft, Color(0.20, 0.21, 0.24), Vector3(0.0, ARM * 0.5, 0.0))
	# THE WHEEL. Round, lying in the plane it would roll in, and big enough that a hand
	# closing on the console in the dark cannot mistake it for anything else in the cockpit.
	var tyre := CylinderMesh.new()
	tyre.top_radius = 0.027
	tyre.bottom_radius = 0.027
	tyre.height = 0.016
	tyre.radial_segments = 18
	_wheel = _under(_arm, tyre, Color(0.88, 0.88, 0.86), Vector3(0.0, ARM, 0.0))
	_wheel.rotation = Vector3(0.0, 0.0, PI * 0.5)


static func _under(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.45
	node.material_override = material
	parent.add_child(node)
	return node


## Where the arm points for a value of 0 (up) to 1 (down), in radians about +X.
func _swung(at: float) -> float:
	return lerpf(UP_AT, DOWN_AT, clampf(at, 0.0, 1.0))


## THE WHEEL, WHEREVER THE ARM HAS SWUNG IT TO. Not the pivot: the hand closes round the
## thing on the end, and on this handle those are eight centimetres apart -- which is half
## the reach, so a grab measured from the pivot would miss the handle entirely when it was
## down.
func _grab_point() -> Vector3:
	var over: float = _swung(value.y)
	return Vector3(0.0, 0.020 + cos(over) * ARM, -sin(over) * ARM)


func _redraw() -> void:
	if _arm == null:
		return
	_arm.rotation = Vector3(_swung(value.y), 0.0, 0.0)
	# LIT WHEN THEY ARE DOWN. See the note at the top: the handle says what was asked for and
	# the lamp says what the aircraft did about it.
	var down: bool = is_down()
	_tint(_wheel, Color(0.42, 0.92, 0.45) if down else Color(0.88, 0.88, 0.86))
	var lamp := _wheel.material_override as StandardMaterial3D
	lamp.emission_enabled = down
	lamp.emission = Color(0.20, 0.85, 0.28)
	lamp.emission_energy_multiplier = 1.5 if down else 0.0


## THE HAND'S SWING, snapped to one end.
##
## Read as vertical travel rather than as an angle about the pivot, which is the same thing
## over a throw this size and is the reading that does not fall apart when the hand is not
## exactly on the arc -- and a hand is never exactly on the arc.
##
## Pushing the handle toward the floor raises the value, because 1 on the bus is gear down.
func _drag(at: Vector3) -> void:
	var swung: float = -_hand_travel(at).y / (ARM * 1.4)
	var asked: float = clampf(_grab_value().y + swung, 0.0, 1.0)
	_settle(Vector2(0.0, 1.0 if asked > SNAP else 0.0))


## Whether the gear is selected DOWN, which is what 1 on the bus means.
func is_down() -> bool:
	return value.y >= 0.5


func throttle() -> float:
	return 0.0
