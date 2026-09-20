@tool
extends VehicleControl
class_name CrewButton
## A BUTTON THAT DOES NOTHING BUT CHANGE COLOUR, one in front of every seat.
##
## It is deliberately the smallest possible piece of craft-local shared state: no physics,
## no external effect, nothing to get right except that everybody aboard sees the same
## thing. Anybody may press anybody's, and it toggles.
##
## If this works then so does every switch shaped like it -- which is the entire reason for
## building it before building any of them.

## A press is a COMMAND, not a level. See the sequence number on ControlInput: holding a
## finger on it does not send it a hundred and twenty times a second.
signal pressed(control: CrewButton)

const PRESS_DEPTH: float = 0.008

@export var lit: bool = false

var _cap: MeshInstance3D = null
var _armed: bool = true


## "Crew button" is its category. What it DOES is turn the cabin light on for everybody
## aboard, and that is what somebody deciding whether to press it wants to know.
func label_text() -> String:
	return "CABIN LIGHT"


func _build() -> void:
	control_name = "crew button"
	scope = Scope.CRAFT
	var housing := CylinderMesh.new()
	housing.top_radius = 0.032
	housing.bottom_radius = 0.034
	housing.height = 0.014
	_make_mesh(housing, Color(0.10, 0.10, 0.12), Vector3.ZERO)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.026
	cap.bottom_radius = 0.026
	cap.height = 0.014
	_cap = _make_mesh(cap, Color(0.30, 0.32, 0.34), Vector3(0.0, 0.012, 0.0))


func _redraw() -> void:
	if _cap == null:
		return
	_cap.position = Vector3(0.0, 0.012 - (PRESS_DEPTH if is_held() else 0.0), 0.0)
	_tint(_cap, Color(0.95, 0.72, 0.15) if lit else Color(0.30, 0.32, 0.34))
	var material := _cap.material_override as StandardMaterial3D
	material.emission_enabled = lit
	material.emission = Color(0.85, 0.55, 0.08)
	material.emission_energy_multiplier = 1.6 if lit else 0.0


## What the wire says, which is the only authority on whether it is lit.
func light(on: bool) -> void:
	if lit == on:
		return
	lit = on
	_redraw()


## The cap, which is the part a finger lands on.
func _grab_point() -> Vector3:
	return Vector3(0.0, 0.012, 0.0)


## PINCH TO PRESS IT: a fingertip on the cap AND the trigger pulled.
##
## Touch alone used to be enough, and a hand simply resting near the console toggled the
## cabin every time it drifted within a few centimetres. A press is a deliberate act, so it
## asks for the same squeeze every other control does.
##
## And it must RE-ARM before it fires again -- release the grip, or take the hand away --
## or one held squeeze toggles at the tick rate.
func offer_hand(hand: int, at: Vector3, pinch: float,
		_facing: Basis = Basis.IDENTITY) -> void:
	var on_it: bool = at.distance_to(_grab_point()) < REACH
	if on_it and pinch >= GRAB_ON and _armed:
		_armed = false
		held_by = hand
		_redraw()
		pressed.emit(self)
	elif (not on_it or pinch <= GRAB_OFF) and not _armed:
		_armed = true
		held_by = -1
		_redraw()


func release() -> void:
	held_by = -1
	_armed = true
	_redraw()


## PINCHED, NOT GRABBED. A button is pressed with a fingertip; closing a fist to press one
## is how a hand pressing this also took hold of the lever beside it. See `Bind.Take`.
func taken_by() -> int:
	return Bind.Take.PINCH


## READ, NOT PUSHED ALONG AN AXIS: turned to face the seat when the builder adds one. See `VehicleControl.faces_the_eye`.
func faces_the_eye() -> bool:
	return true
