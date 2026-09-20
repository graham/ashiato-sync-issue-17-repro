@tool
extends VehicleControl
class_name RotaryKnob
## A KNOB YOU TURN: continuous, from one stop to the other, and it stays where it is put.
##
## The first control in this cockpit that is neither a lever nor a button. A cockpit is
## mostly knobs -- radio volume, brightness, course, heading bug, fuel flow -- and every one
## of them is the same object: a cylinder standing proud of a panel with a line painted down
## one side, which you take between two fingers and roll.
##
## ---------------------------------------------------------------------------------
## TURNED, NOT SHOVED
## ---------------------------------------------------------------------------------
##
## A hand sliding across a knob does nothing at all. What moves it is the WRIST rolling
## about the knob's own axis, which is exactly the distinction `SteeringWheel` already
## draws, and it is the reason knobs work so well in a headset: there is no travel to run
## out of. A lever has a rail and the rail has ends, so a hand that drifts off the rail
## loses the control; a knob has an angle, and an angle is something a wrist has whether or
## not the arm is anywhere in particular.
##
## AND IT IS THE SAME GESTURE AS THE TRIM WHEEL, deliberately. Take hold, roll, let go, take
## a fresh grip and roll again -- so a long travel costs no room, and a knob with a 270
## degree sweep can be walked all the way round in two comfortable turns of a wrist.
##
## ---------------------------------------------------------------------------------
## WHAT IT DOES IS A PROPERTY OF THE INSTANCE, NOT OF THE CLASS
## ---------------------------------------------------------------------------------
##
## Unlike the flap gate or the gear handle, a knob is not one thing. `channel` and
## `channel_range` are exported and this sets a default it expects to be overruled -- by a
## station scene, or by a saved layout, which carries the channel for exactly this reason.
## See CockpitLayout.

## HOW FAR IT TURNS FROM ONE STOP TO THE OTHER, in radians.
##
## 270 degrees, which is what nearly every real panel knob has and is not an accident: it
## leaves a gap at the bottom so the pointer can never be ambiguous about which end it is
## at, and it is about as far as two fingers can roll in one go.
const SWEEP: float = 4.712

## How big it is, and how far it stands out of the panel.
const RADIUS: float = 0.021
const HEIGHT: float = 0.026
## How many ticks are painted round it. Enough to read a position off without counting.
const TICKS: int = 9

var _body: Node3D = null


func label_text() -> String:
	return "KNOB\n%s" % Sim.channel_name(channel).to_upper()


func _build() -> void:
	control_name = "knob"
	scope = Scope.CRAFT
	# A DEFAULT AND NOT A DECISION. See the note above: a knob is whatever it is wired to.
	if channel < 0:
		channel = Sim.Channel.RADIO
		channel_range = 255
	# THE COLLAR IT TURNS IN, which is what makes it look set INTO something rather than
	# stuck on. A knob floating a centimetre off the console reads as debris.
	var collar := CylinderMesh.new()
	collar.top_radius = RADIUS + 0.006
	collar.bottom_radius = RADIUS + 0.008
	collar.height = 0.008
	collar.radial_segments = 24
	_make_mesh(collar, Color(0.11, 0.12, 0.14), Vector3(0.0, 0.004, 0.0))
	_paint_the_scale()
	# THE PART THAT TURNS, as its own node, so `_redraw` rotates the knob and not the panel
	# it is set into. Everything below hangs off this.
	_body = Node3D.new()
	_body.name = "Body"
	_body.position = Vector3(0.0, 0.008, 0.0)
	add_child(_body)
	var barrel := CylinderMesh.new()
	barrel.top_radius = RADIUS * 0.86
	barrel.bottom_radius = RADIUS
	barrel.height = HEIGHT
	barrel.radial_segments = 20
	_under(_body, barrel, Color(0.20, 0.21, 0.24), Vector3(0.0, HEIGHT * 0.5, 0.0))
	# THE LINE DOWN ONE SIDE, which is the entire instrument. A knob without one is a knob
	# whose position you can only discover by turning it, and half of what a hand learns in
	# a cockpit is where things were left.
	var mark := BoxMesh.new()
	mark.size = Vector3(0.005, HEIGHT + 0.002, RADIUS * 1.05)
	_under(_body, mark, Color(0.93, 0.82, 0.30),
		Vector3(0.0, HEIGHT * 0.5, -RADIUS * 0.55))


## THE TICKS ROUND THE COLLAR, which do not turn. The line on the knob moves against these,
## so where it IS, is something you read rather than remember.
func _paint_the_scale() -> void:
	for step in range(TICKS):
		var about: float = _pointing(float(step) / float(TICKS - 1))
		var tick := BoxMesh.new()
		# The ends are longer, because the two positions a hand reaches for without looking
		# are hard over one way and hard over the other.
		var ends: bool = step == 0 or step == TICKS - 1
		tick.size = Vector3(0.0025, 0.002, 0.012 if ends else 0.007)
		var out: float = RADIUS + 0.013
		var at := Vector3(sin(about) * out, 0.002, -cos(about) * out)
		var bar := _make_mesh(tick, Color(0.72, 0.74, 0.72) if ends
			else Color(0.45, 0.47, 0.46), at)
		bar.rotation = Vector3(0.0, about, 0.0)


static func _under(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.5
	node.material_override = material
	parent.add_child(node)
	return node


## WHERE THE POINTER IS, in radians about the knob's axis, for a value of 0 to 1.
##
## Centred on straight ahead, so half is twelve o'clock and the two stops are symmetrical
## about it -- which is what makes a centre-detented knob readable at a glance.
##
## POSITIVE IS CLOCKWISE SEEN FROM ABOVE, which is the direction everybody turns a knob to
## turn something up, and is therefore a NEGATIVE rotation about +Y.
func _pointing(at: float) -> float:
	return (clampf(at, 0.0, 1.0) - 0.5) * SWEEP


## THE TOP OF IT, which is where two fingers go.
func _grab_point() -> Vector3:
	return Vector3(0.0, HEIGHT * 0.7, 0.0)


func _redraw() -> void:
	if _body == null:
		return
	_body.rotation = Vector3(0.0, -_pointing(value.y), 0.0)


## A HAND SLIDING ACROSS IT DOES NOTHING. Only the wrist.
##
## `_turned_about` measures the roll about the knob's own axis and nothing else, so an arm
## swinging past does not move it -- which matters more here than on a wheel, because a
## console of knobs is a place a hand is constantly passing over.
func _turn(facing: Basis) -> void:
	var wanted: float = clampf(
		_grab_value().y - _turned_about(Vector3.UP, facing) / SWEEP, 0.0, 1.0)
	_settle(Vector2(0.0, wanted))


## NOT A THROTTLE. The rig asks every control for all five axes and a knob answers none of
## them: what it does, it does on the bus. See `channel`.
func throttle() -> float:
	return 0.0


## PINCHED, NOT GRABBED. The doc block above says it without meaning to: "a cylinder standing
## proud of a panel with a line painted down one side, which you take BETWEEN TWO FINGERS and
## roll." The trigger is the nearest a hand controller has to two fingers. See `Bind.Take`.
func taken_by() -> int:
	return Bind.Take.PINCH


## READ, NOT PUSHED ALONG AN AXIS: turned to face the seat when the builder adds one. See `VehicleControl.faces_the_eye`.
func faces_the_eye() -> bool:
	return true
