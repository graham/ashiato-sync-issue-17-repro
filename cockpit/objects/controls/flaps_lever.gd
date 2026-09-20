@tool
extends VehicleControl
class_name FlapsLever
## THE FLAP GATE: a lever that stops at NOTCHES rather than anywhere the hand leaves it.
##
## Flaps are not a continuous setting on this aeroplane and the lever must not pretend they
## are. `craft_schema` fits the channel with a range of 3, which is four positions -- up,
## and three stages down -- and the simulation divides the command by that range to get the
## fraction the flight model reads. A handle resting between two of them would be asking
## for a setting the aircraft cannot hold, and the number on the panel would disagree with
## the number in the physics.
##
## So the hand drags it smoothly and it settles on the nearest notch. That is what a real
## gate does, and it is the same promise the gear lever makes for its two positions.
##
## THE ONE CONTROL HERE WHOSE VALUE THE FLIGHT MODEL ALREADY READ. Flaps have been on the
## bus and in the lift and drag terms all along -- `levers.flaps * h.flap_lift`, and again
## in `flap_drag` -- with no way to work them from the cockpit except a page on a screen.
## This is the handle that was missing, not the physics.
##
## A CENTRE-CONSOLE CONTROL, on the aircraft rather than in a seat: either pilot calls for
## flaps, which is exactly what the second pilot is there for on an approach.

## How far the handle travels, in metres, from up to fully down.
const TRAVEL: float = 0.14
## A white bar at each notch, so the gate is visible without moving the handle.
const NOTCH_WIDTH: float = 0.030

var _knob: MeshInstance3D = null
var _notches: Array[MeshInstance3D] = []


func _build() -> void:
	control_name = "flaps"
	scope = Scope.CRAFT
	channel = Sim.Channel.FLAPS
	# THREE, which is FOUR positions. Set from craft_schema by whoever builds the console,
	# because a kind could be fitted with a different gate; this is the aeroplane's.
	channel_range = 3
	var rail := BoxMesh.new()
	rail.size = Vector3(0.028, TRAVEL + 0.05, 0.014)
	_make_mesh(rail, Color(0.10, 0.11, 0.13), Vector3.ZERO)
	_build_the_gate()
	# WHITE AND SQUARE, which is what a flap handle is: the shape is the label, and it is
	# deliberately nothing like the gear lever's wheel a few centimetres away.
	var knob := BoxMesh.new()
	knob.size = Vector3(0.044, 0.026, 0.030)
	_knob = _make_mesh(knob, Color(0.88, 0.88, 0.86), Vector3.ZERO)


## ONE BAR PER NOTCH, at the position the handle will settle to. Rebuilt when the gate
## changes, because the console sets `channel_range` from the craft after `_build` has run.
func _build_the_gate() -> void:
	for bar in _notches:
		bar.queue_free()
	_notches.clear()
	for step in range(channel_range + 1):
		var bar := BoxMesh.new()
		bar.size = Vector3(NOTCH_WIDTH, 0.004, 0.016)
		var at := Vector3(0.0, TRAVEL * (0.5 - float(step) / float(maxi(channel_range, 1))),
			0.006)
		_notches.append(_make_mesh(bar, Color(0.62, 0.63, 0.60), at))


## HOW MANY NOTCHES THIS GATE HAS, from the craft's own schema.
##
## Called after `_build`, so the bars have to be laid out again. A lever showing four
## detents on an aeroplane fitted with two is a lever that will be reached for in the wrong
## place, in the dark, on an approach.
func set_gate(notches: int) -> void:
	channel_range = maxi(notches, 1)
	if _knob != null:
		_build_the_gate()
		_redraw()


## 0 is up, at the top of the rail; 1 is fully down, at the bottom.
func _grab_point() -> Vector3:
	return Vector3(0.0, TRAVEL * (0.5 - clampf(value.y, 0.0, 1.0)), 0.0)


func _redraw() -> void:
	if _knob == null:
		return
	_knob.position = _grab_point()


## The hand's vertical travel, settled onto the nearest notch.
##
## Down the rail is more flap, which is the way a quadrant works and the way the lever
## looks: the handle ends up nearest the floor with the most drag hanging off the wing.
func _drag(at: Vector3) -> void:
	var pushed: float = -_hand_travel(at).y / TRAVEL
	var dragged: float = clampf(_grab_value().y + pushed, 0.0, 1.0)
	var gate: float = float(maxi(channel_range, 1))
	_settle(Vector2(0.0, roundf(dragged * gate) / gate))


## WHICH NOTCH IT IS IN, counting from 0 at up. What a panel shows beside the word FLAPS.
func notch() -> int:
	return command_value()


func throttle() -> float:
	return 0.0
