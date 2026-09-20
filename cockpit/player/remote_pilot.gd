extends Node3D
class_name RemotePilot
## Somebody else, drawn inside their own vehicle.
##
## A child of a SEAT ANCHOR, with the replicated seat-local poses applied directly to its
## local transforms. No world space anywhere, and no interpolation here: sync already
## interpolated this pilot between the two frames that actually arrived, and anything this
## file added would be a second, worse smoothing fighting the first.
##
## Because it is parented to the seat, a remote pilot cannot drift out of their cockpit
## however fast the cockpit is going. That is the same guarantee the local rig has, for
## the same reason, and it is worth having on both sides: a passenger watching the pilot's
## hands shake would be just as wrong as their own shaking.

@onready var head: MeshInstance3D = $Head
@onready var visor: MeshInstance3D = $Head/Visor
@onready var left_hand: MeshInstance3D = $LeftHand
@onready var right_hand: MeshInstance3D = $RightHand
@onready var label: Label3D = $Label

var client_id: int = -1


func setup(sync_client: int, display_name: String) -> void:
	client_id = sync_client
	_refresh_identity(display_name)
	if not Net.roster_changed.is_connected(_refresh_identity):
		Net.roster_changed.connect(_refresh_identity)


func _refresh_identity(fallback_name: String = "") -> void:
	label.text = Net.name_of(client_id) if client_id > 0 else fallback_name
	var colour: Color = Net.colour_of(client_id)
	for mesh in [head, left_hand, right_hand]:
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 0.55
		mesh.material_override = material
	label.modulate = colour


func apply(state: Dictionary) -> void:
	head.transform = Transform3D(
		Basis(state.get("head_basis", Quaternion.IDENTITY) as Quaternion),
		state.get("head", Vector3.ZERO))
	left_hand.transform = Transform3D(
		Basis(state.get("left_basis", Quaternion.IDENTITY) as Quaternion),
		state.get("left", Vector3.ZERO))
	right_hand.transform = Transform3D(
		Basis(state.get("right_basis", Quaternion.IDENTITY) as Quaternion),
		state.get("right", Vector3.ZERO))
	label.position = head.position + Vector3(0.0, 0.3, 0.0)
	# Fingers, from the analog squeeze. Cheap, and the difference between an avatar and a
	# mannequin: a hand that closes when theirs does reads as a person.
	left_hand.scale = Vector3.ONE * lerpf(1.0, 0.72, float(state.get("grip_left", 0.0)))
	right_hand.scale = Vector3.ONE * lerpf(1.0, 0.72, float(state.get("grip_right", 0.0)))
