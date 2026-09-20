@tool
extends ToggleSwitch
class_name GuardedToggleSwitch
## A TOGGLE SWITCH UNDER A HINGED SAFETY COVER.
##
## The cover is local presentation state. Opening it is not an aircraft command and never
## emits `moved`; only the ordinary switch underneath reaches DeviceSignalRouter. This is
## the useful split for MASTER ARM, fuel and emergency switches: every crew member agrees
## on the switch position, while whether this player has lifted a cover is a detail of the
## hand currently at this cockpit.
##
## One pinched gesture lifts or lowers the cover, then a separate pinch throws the exposed
## bat. A closed cover therefore cannot accidentally become an ON command merely because
## the hand used to uncover it travelled in the same direction as the switch.

const GUARD_LENGTH: float = 0.045
const GUARD_HALF_WIDTH: float = 0.021
const GUARD_HEIGHT: float = 0.036
const GUARD_BAR: float = 0.004
const GUARD_HINGE := Vector3(0.0, 0.008, -0.035)
const GUARD_OPEN_ANGLE: float = -1.571
const GUARD_TRAVEL: float = 0.035

var _guard: Node3D = null
var _guard_fraction: float = 0.0
var _guard_at_grab: float = 0.0
var _working_guard: bool = false


func label_text() -> String:
	return "GUARDED SWITCH\n%s" % Sim.channel_name(channel).to_upper()


func _build() -> void:
	super._build()
	control_name = "guarded switch"
	_guard = Node3D.new()
	_guard.name = "Guard"
	_guard.position = GUARD_HINGE
	add_child(_guard)

	# Three red bars make an open-bottomed cover: the switch remains readable through it,
	# while its silhouette says that a second action is required before the bat can move.
	var side := BoxMesh.new()
	side.size = Vector3(GUARD_BAR, GUARD_BAR, GUARD_LENGTH)
	_guard_part(side, Vector3(-GUARD_HALF_WIDTH, GUARD_HEIGHT, GUARD_LENGTH * 0.5))
	_guard_part(side, Vector3(GUARD_HALF_WIDTH, GUARD_HEIGHT, GUARD_LENGTH * 0.5))
	var bridge := BoxMesh.new()
	bridge.size = Vector3(GUARD_HALF_WIDTH * 2.0 + GUARD_BAR, GUARD_BAR, GUARD_BAR)
	_guard_part(bridge, Vector3(0.0, GUARD_HEIGHT, GUARD_LENGTH))

	# A visible hinge rather than a floating frame. Its axis is X, the same axis the cover
	# rotates around in `_redraw`.
	var hinge := CylinderMesh.new()
	hinge.top_radius = GUARD_BAR * 1.35
	hinge.bottom_radius = GUARD_BAR * 1.35
	hinge.height = GUARD_HALF_WIDTH * 2.0 + GUARD_BAR * 2.0
	hinge.radial_segments = 12
	var hinge_mesh := _guard_part(hinge, Vector3(0.0, 0.0, 0.0))
	hinge_mesh.rotation = Vector3(0.0, 0.0, PI * 0.5)


func _guard_part(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.08, 0.045)
	material.roughness = 0.38
	material.metallic = 0.18
	node.material_override = material
	_guard.add_child(node)
	return node


## True means the cover is fully open. Intermediate values exist only while a hand is
## moving it and are deliberately not serialized or replicated.
func guard_is_open() -> bool:
	return _guard_fraction >= 0.999


## The far red bridge is the part a fingertip lifts. Rotate its local point by the current
## hinge angle so hit testing follows the cover instead of staying where it was closed.
func _guard_grab_point() -> Vector3:
	var local := Vector3(0.0, GUARD_HEIGHT, GUARD_LENGTH)
	return GUARD_HINGE + Basis(Vector3.RIGHT, GUARD_OPEN_ANGLE * _guard_fraction) * local


func _switch_grab_point() -> Vector3:
	return super._grab_point()


## Closed, the cover is the only advertised grip. Open, advertise the midpoint between
## cover and bat: both real pieces remain inside VehicleControl.REACH, so a player can
## either close the cover or work the switch and `offer_hand` decides from the actual
## fingertip position.
func _grab_point() -> Vector3:
	var guard_point := _guard_grab_point()
	if _working_guard or not guard_is_open():
		return guard_point
	return (guard_point + _switch_grab_point()) * 0.5


func offer_hand(hand: int, at: Vector3, closed: float,
		facing: Basis = Basis.IDENTITY) -> void:
	if held_by < 0 and closed >= GRAB_ON:
		var guard_distance := at.distance_to(_guard_grab_point())
		var switch_distance := at.distance_to(_switch_grab_point())
		# With the cover closed there is no route to the bat. With it open, pinching the
		# red bridge rather than the silver tip selects the cover.
		_working_guard = not guard_is_open() or guard_distance < switch_distance
	super.offer_hand(hand, at, closed, facing)
	# A failed offer must not leave the next, unrelated hand interpreted as a cover drag.
	if held_by < 0:
		_working_guard = false


func _on_grabbed() -> void:
	if _working_guard:
		_guard_at_grab = _guard_fraction


func _drag(at: Vector3) -> void:
	if not _working_guard:
		super._drag(at)
		return
	# Lift and pull the bridge to open; push it down and forward to close. The weighted Z
	# term lets a controller make the motion comfortably without requiring a vertical-only
	# wrist path, while the visible part still rotates about its real hinge.
	var travel := _hand_travel(at)
	_guard_fraction = clampf(_guard_at_grab + (travel.y + travel.z * 0.5) / GUARD_TRAVEL,
		0.0, 1.0)
	_redraw()


func _on_released() -> void:
	if not _working_guard:
		return
	var was_open := guard_is_open()
	_guard_fraction = 1.0 if _guard_fraction >= 0.5 else 0.0
	_working_guard = false
	_redraw()
	if was_open != guard_is_open():
		bump(&"detent")


func _redraw() -> void:
	super._redraw()
	if _guard != null:
		_guard.rotation = Vector3(GUARD_OPEN_ANGLE * _guard_fraction, 0.0, 0.0)
