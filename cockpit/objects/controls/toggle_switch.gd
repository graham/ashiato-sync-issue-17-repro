@tool
extends VehicleControl
class_name ToggleSwitch
## A BAT SWITCH: the little metal lever you flick with one finger, and it stays flicked.
##
## The most common object in any cockpit and the last one this game had. A `CrewButton` is a
## momentary press -- it does a thing and springs back. A switch is a POSITION: it is on or
## it is off, it says which from across the cockpit, and a glance down a row of them is how
## anybody checks an aircraft is configured.
##
## FORWARD IS ON, which is the convention on every panel that has ever been laid out this
## way round and is worth copying exactly rather than inventing. It also happens to be the
## one that matches the rest of this cockpit: the throttle opens forward, the flap gate goes
## down for more flap, and a control that is a PICTURE of what it does is a control nobody
## has to read.
##
## FLICKED, NOT TURNED. It is a tiny lever and the honest gesture is the one a finger makes:
## push it away from you or pull it back. So it reads hand TRAVEL like the levers and not
## wrist roll like the knobs -- and over a throw this short, a wrist reading would fire on
## any hand that so much as hovered.
##
## AND IT SNAPS. There is no halfway. `GearLever` makes the same promise for the same
## reason: a switch resting between its two positions is a switch that has lied to
## somebody, and what it lied about is whether the pumps are on.
##
## THREE-WAY IS THE SAME OBJECT. Some switches have a middle -- BOTH, AUTO, NORM -- so this
## takes the number of positions rather than assuming two, and the middle is just another
## stop to settle on.

## How far the top of the bat moves, front to back, in metres. Small: this is a switch and
## not a lever, and the distance is the whole of what tells a hand which it has hold of.
const THROW: float = 0.030
## How long the bat is and how thick.
const BAT: float = 0.026
const BAT_RADIUS: float = 0.0038
## How far over it leans at the ends of its travel, in radians. Not flat: a switch lying
## along the panel is one a finger cannot get under.
const LEAN: float = 0.62

## HOW MANY POSITIONS. Two is a switch; three is a switch with a middle. Exported because
## the answer is a fact about what it is wired to, like the flap gate's notches.
@export var positions: int = 2:
	set(value):
		positions = maxi(value, 2)
		channel_range = positions - 1
		if _bat != null:
			_redraw()

var _bat: Node3D = null


func label_text() -> String:
	return "SWITCH\n%s" % Sim.channel_name(channel).to_upper()


func _build() -> void:
	control_name = "switch"
	scope = Scope.CRAFT
	if channel < 0:
		channel = Sim.Channel.LIGHTS
	channel_range = maxi(positions - 1, 1)
	# THE PLATE IT IS SET IN, with the guard ridge round it that stops a sleeve catching the
	# bat. That ridge is on every real panel and it is not decoration -- but here it is,
	# because nothing in this game has sleeves. It is shape that says "switch" at a glance.
	var plate := BoxMesh.new()
	plate.size = Vector3(0.026, 0.006, THROW + 0.026)
	_make_mesh(plate, Color(0.11, 0.12, 0.14), Vector3(0.0, 0.003, 0.0))
	_bat = Node3D.new()
	_bat.name = "Bat"
	_bat.position = Vector3(0.0, 0.006, 0.0)
	add_child(_bat)
	var stem := CylinderMesh.new()
	stem.top_radius = BAT_RADIUS * 0.8
	stem.bottom_radius = BAT_RADIUS
	stem.height = BAT
	stem.radial_segments = 10
	_under(_bat, stem, Color(0.78, 0.79, 0.80), Vector3(0.0, BAT * 0.5, 0.0))
	# A BALL ON THE END, which is what a finger actually meets and what makes the thing
	# findable without looking at it.
	var tip := SphereMesh.new()
	tip.radius = BAT_RADIUS * 1.9
	tip.height = BAT_RADIUS * 3.8
	tip.radial_segments = 10
	tip.rings = 6
	_under(_bat, tip, Color(0.86, 0.87, 0.88), Vector3(0.0, BAT, 0.0))


static func _under(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.4
	node.material_override = material
	parent.add_child(node)
	return node


## WHICH WAY IT IS LEANING, in radians about the across axis, for a value of 0 to 1.
##
## 1 is ON and leans FORWARD, which is -Z, which is a NEGATIVE rotation about +X.
func _leaning(at: float) -> float:
	return -(clampf(at, 0.0, 1.0) - 0.5) * 2.0 * LEAN


## THE BALL ON TOP, where it currently is. A finger lands on the tip and not on the plate,
## and the tip is somewhere different depending on which way the switch is thrown.
func _grab_point() -> Vector3:
	var over: float = _leaning(value.y)
	return Vector3(0.0, 0.006 + cos(over) * BAT, -sin(over) * BAT)


func _redraw() -> void:
	if _bat == null:
		return
	_bat.rotation = Vector3(_leaning(value.y), 0.0, 0.0)


## THE FINGER'S FORE-AND-AFT TRAVEL, settled on the nearest position.
##
## Forward is on: pushing the bat away from you raises the value, so -Z counts up. Snapped
## for the reason at the top -- there is no halfway on a switch.
func _drag(at: Vector3) -> void:
	var pushed: float = -_hand_travel(at).z / THROW
	var flicked: float = clampf(_grab_value().y + pushed, 0.0, 1.0)
	var gaps: float = float(maxi(channel_range, 1))
	_settle(Vector2(0.0, roundf(flicked * gaps) / gaps))


## Whether it is thrown to the last position, which on a two-way switch is ON.
func is_on() -> bool:
	return command_value() >= channel_range


## Which position it is in, counting from 0. What a panel shows.
func at_position() -> int:
	return command_value()


func throttle() -> float:
	return 0.0


## PINCHED, NOT GRABBED. It is a bat the size of a fingernail and the gesture is the one a
## finger makes -- which is also the gesture already written at the top of this file, "FLICKED,
## NOT TURNED". A whole fist closing over a switch is a fist covering the switch. See
## `Bind.Take`.
func taken_by() -> int:
	return Bind.Take.PINCH


## READ, NOT PUSHED ALONG AN AXIS: turned to face the seat when the builder adds one. See `VehicleControl.faces_the_eye`.
func faces_the_eye() -> bool:
	return true
