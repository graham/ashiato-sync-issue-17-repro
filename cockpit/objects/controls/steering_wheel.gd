@tool
extends VehicleControl
class_name SteeringWheel
## A HELM: the wheel a car, a boat or anything else with one lateral control is steered by.
##
## Turned rather than moved, and that is the whole of it. A car has no pitch axis and a boat
## has no roll axis, so a two-axis stick in front of either is a control that lies about
## what the vehicle can do -- half of it would move and nothing would happen.
##
## It is worked the same way the flight stick's rudder is: by the hand's ROTATION about the
## control's own axis, which here is the column the wheel is mounted on. Wheels are turned,
## not shoved.
##
## Springs back, gently. A car's wheel self-centres from the castor in its steering and a
## boat's does not, but a helm that stays hard over when you let go of it in a game is a
## helm that puts you in the sea while you are looking at something else.

## How far the wheel turns from centre to full lock, in radians. Most of a half-turn, which
## is a hand's worth without shuffling a grip.
const LOCK: float = 1.9
## How far out the rim is from the column, in metres.
const RIM: float = 0.17
## How fast it comes back to centre, in fractions per second. Slower than a stick: a wheel
## has weight in it.
const CENTRING: float = 3.0

var _wheel: Node3D = null
## THE MISSILES, AT A HELM THAT LAUNCHES THEM: set by `CockpitStation._fit_the_missiles` on a craft whose schema says
## this seat launches -- the CB90's helm and weapons officer (lane/boats, 2026-09-18). A boat's missiles are aimed with
## the boat, as an aeroplane's are, so the hands on the wheel are the hands on the switches: the light twin's stick
## binding, `FlightStick.missile_bindings`, which a wheel shares rather than copies.
var launches: bool = false
var missile_stations: Array = []


## A WHEEL HAS NOTHING UNDER THE HAND, until it launches: then the trigger launches, the upper thumb locks and the lower
## thumb walks the stations, as on the aeroplane's stick. A wheel has no trim, so none is bound.
func bindings() -> Dictionary:
	return FlightStick.missile_bindings(true, 0, missile_stations) if launches else {}


func label_text() -> String:
	return "WHEEL\nSTEERING"


func _build() -> void:
	control_name = "wheel"
	scope = Scope.SEAT
	centring = CENTRING
	var dull := StandardMaterial3D.new()
	dull.albedo_color = Color(0.14, 0.15, 0.17)
	dull.roughness = 0.7
	var column := CylinderMesh.new()
	column.top_radius = 0.022
	column.bottom_radius = 0.026
	column.height = RIM
	var shaft := _make_mesh(column, Color(0.15, 0.16, 0.19), Vector3(0.0, 0.0, -RIM * 0.5))
	shaft.rotation = Vector3(PI * 0.5, 0.0, 0.0)

	_wheel = Node3D.new()
	_wheel.position = Vector3(0.0, 0.0, -RIM)
	add_child(_wheel)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.115
	rim.outer_radius = 0.145
	var hoop := MeshInstance3D.new()
	hoop.mesh = rim
	hoop.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	hoop.material_override = dull
	_wheel.add_child(hoop)
	# Two spokes and a mark at the top, so which way it is turned is readable at a glance.
	for angle in [0.0, PI * 0.5]:
		var spoke := BoxMesh.new()
		spoke.size = Vector3(0.26, 0.018, 0.026)
		var bar := MeshInstance3D.new()
		bar.mesh = spoke
		bar.rotation = Vector3(0.0, 0.0, angle)
		bar.material_override = dull
		_wheel.add_child(bar)
	var pip := BoxMesh.new()
	pip.size = Vector3(0.03, 0.03, 0.03)
	var mark := MeshInstance3D.new()
	mark.mesh = pip
	var bright := StandardMaterial3D.new()
	bright.albedo_color = Color(0.85, 0.62, 0.18)
	mark.material_override = bright
	mark.position = Vector3(0.0, 0.13, 0.0)
	_wheel.add_child(mark)


## The rim, which is what a hand takes hold of.
func _grab_point() -> Vector3:
	return Vector3(0.0, 0.0, -RIM)


func _redraw() -> void:
	if _wheel == null:
		return
	# Turning the wheel right steers right, which is a positive value and a negative
	# rotation about the column: the column points at the driver, so its own axis is +Z.
	_wheel.rotation = Vector3(0.0, 0.0, -clampf(value.x, -1.0, 1.0) * LOCK)


## TURNED, not shoved. The axis is the column, so a hand sliding along the rim does nothing
## and a wrist rolling about it does everything -- which is what a wheel is.
func _turn(facing: Basis) -> void:
	var column := Vector3(0.0, 0.0, 1.0)
	var wanted: float = clampf(
		_grab_value().x - _turned_about(column, facing) / LOCK, -1.0, 1.0)
	if absf(wanted - value.x) < 0.001:
		return
	value = Vector2(wanted, 0.0)
	_redraw()
	moved.emit(self)


## STEERING, which reaches the simulation as roll: a car and a boat each have exactly one
## lateral control and read `roll + rudder` for it.
func roll() -> float:
	return clampf(value.x, -1.0, 1.0)


## And nothing else. A wheel has one axis, and reporting a second would be a control
## claiming an authority the vehicle underneath it does not have.
func pitch() -> float:
	return 0.0
