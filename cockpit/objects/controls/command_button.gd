@tool
extends VehicleControl
class_name CommandButton
## A GENERIC, ILLUMINATED COMMAND BUTTON for mission, autopilot and systems panels.
##
## `CrewButton` is deliberately one particular cabin-light command. This is the reusable
## panel part: pushing it proposes 1 on its bound channel, releasing it proposes 0, and its
## lamp shows the value returned by the craft. The cap's physical depression is local hand
## feedback; the lamp is the shared command value.
##
## A press and a release are two value changes through the ordinary `moved` signal and
## `DeviceSignalRouter`. No device-specific networking branch is needed, and a held finger
## produces no repeat traffic.

const PRESS_DEPTH: float = 0.008
const CAP := Vector3(0.048, 0.014, 0.040)

var _cap: MeshInstance3D = null
var _lamp: MeshInstance3D = null
var _armed: bool = true


func label_text() -> String:
	return "BUTTON\n%s" % Sim.channel_name(channel).to_upper()


func _build() -> void:
	control_name = "command button"
	scope = Scope.CRAFT
	if channel < 0:
		channel = Sim.Channel.LIGHTS
	channel_range = 1

	var housing := BoxMesh.new()
	housing.size = Vector3(0.060, 0.010, 0.052)
	_make_mesh(housing, Color(0.09, 0.10, 0.12), Vector3(0.0, 0.005, 0.0))

	var cap := BoxMesh.new()
	cap.size = CAP
	_cap = _make_mesh(cap, Color(0.24, 0.27, 0.30), Vector3(0.0, 0.017, 0.0))

	# A WIDE ANNUNCIATOR STRIP rather than making the whole cap glow. It stays readable in a
	# bank of buttons and separates "my finger is pushing it" from "the aircraft accepted it".
	var lamp := BoxMesh.new()
	lamp.size = Vector3(CAP.x * 0.72, 0.002, CAP.z * 0.32)
	_lamp = _make_mesh(lamp, Color(0.18, 0.20, 0.16), Vector3(0.0, 0.025, -0.006))


func _grab_point() -> Vector3:
	return Vector3(0.0, 0.024, 0.0)


func _redraw() -> void:
	if _cap == null or _lamp == null:
		return
	_cap.position.y = 0.017 - (PRESS_DEPTH if is_held() else 0.0)
	_lamp.position.y = 0.025 - (PRESS_DEPTH if is_held() else 0.0)
	var on: bool = command_value() > 0
	_tint(_lamp, Color(0.82, 0.94, 0.34) if on else Color(0.18, 0.20, 0.16))
	var material := _lamp.material_override as StandardMaterial3D
	material.emission_enabled = on
	material.emission = Color(0.62, 0.92, 0.18)
	material.emission_energy_multiplier = 1.5 if on else 0.0


## PINCH ONCE FOR DOWN, RELEASE ONCE FOR UP. A held pinch changes nothing after the first
## edge, so the command rate is bounded by human presses instead of the display frame rate.
func offer_hand(hand: int, at: Vector3, pinch: float,
		_facing: Basis = Basis.IDENTITY) -> void:
	var on_it: bool = at.distance_to(_grab_point()) < REACH
	if on_it and pinch >= GRAB_ON and _armed:
		_armed = false
		held_by = hand
		_settle(Vector2(0.0, 1.0))
		_redraw()
	elif (not on_it or pinch <= GRAB_OFF) and not _armed:
		held_by = -1
		_armed = true
		_settle(Vector2.ZERO)
		_redraw()


func release() -> void:
	var was_down: bool = held_by >= 0 or value.y > 0.0
	held_by = -1
	_armed = true
	if was_down:
		_settle(Vector2.ZERO)
	_redraw()


func throttle() -> float:
	return 0.0


func taken_by() -> int:
	return Bind.Take.PINCH


func faces_the_eye() -> bool:
	return true
