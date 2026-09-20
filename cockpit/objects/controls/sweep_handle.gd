@tool
extends VehicleControl
class_name SweepHandle
## THE WING SWEEP HANDLE: a T-handle in a slot along the console, forward for the wings spread and aft for them swept.
##
## A SWING-WING AEROPLANE'S, and only one whose bus is fitted with `Sim.Channel.SWEEP` -- the F-14. For the same reason
## the flap gate and the hook handle are fitted by channel: a handle for a channel the craft has not got is a dead handle,
## and a dead handle is the cockpit lying about what it can do.
##
## FORWARD IS FORWARD. The handle's travel runs fore and aft because the wings' does: pushed to the front of the slot the
## wings are spread at 20 degrees, pulled to the back they are at 75, OVERSWEPT, the deck position. A painted line across
## the slot marks 68, the last in-flight stop, so a hand sees where full sweep is without reading anything. The real F-14
## carries its handle on the pilot's throttle quadrant; this one is fitted at BOTH seats, pilot and RIO, because the user
## asked for both crew to have it (2026-09-17) -- which the real RIO could not.
##
## A CRAFT CONTROL WITH TRAVEL, like the nacelle lever: the channel carries 0 to 255, and every handle aboard is drawn
## from the bus (`world/sky.gd`, by scope), so the RIO's handle slides when the pilot moves theirs. A hand here only
## PROPOSES; the server decides, and what comes back is what both handles show (`VehicleView.propose`, house rule 5).
##
## LATCHED, because the sweep is a configuration the aeroplane is in, not a demand held against a spring.

## How far the knob travels, in metres, fore and aft.
const TRAVEL: float = 0.16
## THE WINGS' RANGE, as `TomcatAirframe` builds it: the handle's travel is linear in the sweep angle.
const SWEEP_LOW: float = TomcatAirframe.SWEEP_FORWARD
const SWEEP_HIGH: float = TomcatAirframe.SWEEP_OVER
## The last in-flight stop, painted across the slot.
const MARKED: float = TomcatAirframe.SWEEP_AFT

var _knob: Array[MeshInstance3D] = []
var _offsets: Array[Vector3] = []


func label_text() -> String:
	return "WING SWEEP\nFWD 20 / AFT 75"


func _build() -> void:
	control_name = "wing sweep"
	scope = Scope.CRAFT
	channel = Sim.Channel.SWEEP
	channel_range = 255
	# THE SLOT, so the ends of the travel are visible without moving the handle.
	var slot := BoxMesh.new()
	slot.size = Vector3(0.018, 0.012, TRAVEL + 0.05)
	_make_mesh(slot, Color(0.10, 0.11, 0.13), Vector3.ZERO)
	# THE 68-DEGREE LINE, painted across the slot where full in-flight sweep puts the knob.
	var mark := BoxMesh.new()
	mark.size = Vector3(0.050, 0.013, 0.004)
	_make_mesh(mark, Color(0.92, 0.92, 0.88), Vector3(0.0, 0.0, _travel_at(fraction_of(MARKED))))
	# THE T-HANDLE: a stem up out of the slot and a crossbar a hand closes on, the bar white-banded at its ends.
	var stem := BoxMesh.new()
	stem.size = Vector3(0.014, 0.05, 0.014)
	_knob.append(_make_mesh(stem, Color(0.20, 0.21, 0.23), Vector3.ZERO))
	_offsets.append(Vector3(0.0, 0.025, 0.0))
	var bar := BoxMesh.new()
	bar.size = Vector3(0.070, 0.022, 0.022)
	_knob.append(_make_mesh(bar, Color(0.08, 0.08, 0.09), Vector3.ZERO))
	_offsets.append(Vector3(0.0, 0.055, 0.0))
	for side in [-1.0, 1.0]:
		var band := BoxMesh.new()
		band.size = Vector3(0.012, 0.024, 0.024)
		_knob.append(_make_mesh(band, Color(0.92, 0.92, 0.88), Vector3.ZERO))
		_offsets.append(Vector3(side * 0.030, 0.055, 0.0))
	_redraw()


## WHERE ALONG THE SLOT a fraction of the travel puts the knob: forward (-Z) at 0, aft at 1.
static func _travel_at(fraction: float) -> float:
	return TRAVEL * (clampf(fraction, 0.0, 1.0) - 0.5)


## THE SWEEP ANGLE a fraction of the handle's travel asks for, in degrees.
static func sweep_of(fraction: float) -> float:
	return lerpf(SWEEP_LOW, SWEEP_HIGH, clampf(fraction, 0.0, 1.0))


## THE FRACTION OF THE TRAVEL that asks for `degrees` of sweep.
static func fraction_of(degrees: float) -> float:
	return clampf(inverse_lerp(SWEEP_LOW, SWEEP_HIGH, degrees), 0.0, 1.0)


func _grab_point() -> Vector3:
	return Vector3(0.0, 0.055, _travel_at(value.y))


func _redraw() -> void:
	for index in range(_knob.size()):
		if _knob[index] != null:
			_knob[index].position = _offsets[index] + Vector3(0.0, 0.0, _travel_at(value.y))


## THE HAND'S FORE-AND-AFT TRAVEL: pulled aft (+Z) sweeps the wings back. Continuous, not snapped -- a sweep is any angle
## in its range, and the wing is drawn at whatever it is handed.
func _drag(at: Vector3) -> void:
	var pulled: float = _hand_travel(at).z / TRAVEL
	_settle(Vector2(0.0, clampf(_grab_value().y + pulled, 0.0, 1.0)))


## Where the handle asks the wings to be, in degrees.
func sweep() -> float:
	return sweep_of(value.y)


## Not a throttle. The rig asks every control this, and a handle that opens nothing says so.
func throttle() -> float:
	return 0.0
