extends Node3D
class_name WreckPieces
## A DESTROYED CRAFT BREAKS INTO PIECES THAT FALL (lane/combat, 2026-09-18): "after taking enough damage, it should
## explode into pieces."
##
## A PICTURE, NOT A SIMULATION. The pieces are this machine's: they are not on the wire and not in the rollback, and
## nothing collides with them. The kill is the server's fact (`Hull`); what it looks like as it comes apart is drawn
## by each machine from what it already has -- the craft's own meshes where it was drawn, and the velocity it was
## last drawn with -- and seeded from the craft's entity so two machines throw them the same way.
##
## THE CRAFT'S OWN PARTS. The largest few meshes the view is drawn with (its wings, fuselage, tail, rotor: whatever
## a kind is built from), each put where it was and given the craft's momentum, an outward kick away from the
## craft's middle and a tumble. A scripted ballistic fall -- gravity and a little drag -- rather than rigid bodies,
## because a body would be a physics object on a world whose physics is the simulation's.
##
## THEY SMOKE WHILE THEY FALL (the thin smoke), and they stop on what is under them: they come to rest on the ground,
## and on water they sink and go. Every piece is gone `LASTS` after it was thrown.

## How many pieces a craft comes apart into at most: the largest meshes by the volume of their boxes.
const MOST: int = 6
## Seconds a piece is kept.
const LASTS: float = 25.0
## The kick away from the craft's middle, metres a second, and the extra kick upward.
const KICK: Vector2 = Vector2(4.0, 12.0)
const LIFT: Vector2 = Vector2(2.0, 7.0)
## How fast a piece tumbles, radians a second.
const TUMBLE: Vector2 = Vector2(1.0, 4.0)
## The share of its speed a piece keeps each second: a wing is not a bullet.
const DRAG: float = 0.75
## How long a piece smokes, seconds, and how fast one sinks, metres a second.
const SMOKES_FOR: float = 5.0
const SINK: float = 1.2

## The yard the pieces smoke through (its `puff_at`), or null for no smoke. A Node and not a DamageYard: the yard makes
## this and hands itself back, and typed both ways the pair is a cycle `lint` cannot compile ("Value of type ... cannot be
## assigned to a variable of type DamageYard").
var smoke: Node = null

## Each piece: {"node": MeshInstance3D, "v": Vector3, "spin": Vector3, "age": float, "state": "air"|"ground"|"water"}.
var _pieces: Array[Dictionary] = []
## How many craft have been broken up, and pieces thrown, for the tests.
var broken: int = 0
var thrown: int = 0


## BREAK `view` UP, thrown with `velocity`. Its meshes are copied, not moved: the view is hidden as a wreck and reaped
## by the level when the craft is retired, and a piece must outlive it.
func break_up(view: VehicleView, velocity: Vector3) -> void:
	if view == null or not is_instance_valid(view):
		return
	var parts: Array[MeshInstance3D] = _largest_parts(view)
	if parts.is_empty():
		return
	broken += 1
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(view.entity)
	var middle: Vector3 = view.global_position
	for part in parts:
		var piece := MeshInstance3D.new()
		piece.name = "WreckPiece"
		piece.mesh = part.mesh
		piece.material_override = part.material_override
		for s in range(part.get_surface_override_material_count()):
			piece.set_surface_override_material(s, part.get_surface_override_material(s))
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(piece)
		piece.global_transform = part.global_transform
		var away: Vector3 = (piece.global_transform * part.mesh.get_aabb().get_center()) - middle
		if away.length() < 0.1:
			away = Vector3(dice.randf_range(-1.0, 1.0), 0.3, dice.randf_range(-1.0, 1.0))
		var v: Vector3 = velocity * dice.randf_range(0.7, 0.95) + away.normalized() * dice.randf_range(KICK.x, KICK.y) \
			+ Vector3.UP * dice.randf_range(LIFT.x, LIFT.y)
		var axis := Vector3(dice.randf_range(-1.0, 1.0), dice.randf_range(-1.0, 1.0), dice.randf_range(-1.0, 1.0))
		var spin: Vector3 = (axis.normalized() if axis.length() > 0.01 else Vector3.UP) * dice.randf_range(TUMBLE.x, TUMBLE.y)
		_pieces.append({"node": piece, "v": v, "spin": spin, "age": 0.0, "state": "air", "id": view.entity * 16 + thrown})
		thrown += 1
	set_process(true)


## THE LARGEST MESHES THE VIEW DRAWS, visible ones, not the local rig's branch: up to `MOST`.
static func _largest_parts(view: VehicleView) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node in view.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null or not _drawn(mesh, view):
			continue
		if _in_a_rig(mesh, view):
			continue
		found.append(mesh)
	found.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool:
		return _volume(a) > _volume(b))
	return found.slice(0, MOST)


## Whether a mesh is drawn, up to the view: hidden anywhere on the way is not. Asked before the view is hidden as a wreck.
static func _drawn(mesh: Node3D, view: Node3D) -> bool:
	var at: Node = mesh
	while at != null and at != view:
		var shown := at as Node3D
		if shown != null and not shown.visible:
			return false
		at = at.get_parent()
	return true


static func _in_a_rig(mesh: Node, view: Node) -> bool:
	var at: Node = mesh
	while at != null and at != view:
		if at is PilotRig or at is RemotePilot:
			return true
		at = at.get_parent()
	return false


static func _volume(mesh: MeshInstance3D) -> float:
	var box: AABB = mesh.mesh.get_aabb()
	var scaled: Vector3 = box.size * mesh.global_transform.basis.get_scale()
	return absf(scaled.x * scaled.y * scaled.z) + 0.001 * scaled.length()


func _process(delta: float) -> void:
	if _pieces.is_empty():
		set_process(false)
		return
	var kept: Array[Dictionary] = []
	for piece in _pieces:
		var node := piece["node"] as MeshInstance3D
		piece["age"] = float(piece["age"]) + delta
		if float(piece["age"]) > LASTS or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			continue
		_fall(piece, node, delta)
		kept.append(piece)
	_pieces = kept


func _fall(piece: Dictionary, node: MeshInstance3D, delta: float) -> void:
	var state: String = piece["state"]
	var at: Vector3 = node.global_position
	if state == "ground":
		return
	if state == "water":
		node.global_position = at + Vector3.DOWN * SINK * delta
		return
	var v: Vector3 = piece["v"]
	v += Vector3.DOWN * 9.81 * delta
	v *= pow(DRAG, delta)
	piece["v"] = v
	at += v * delta
	var spin: Vector3 = piece["spin"]
	node.global_transform = Transform3D(Basis(spin.normalized(), spin.length() * delta) * node.global_transform.basis,
		at) if spin.length() > 0.0001 else Transform3D(node.global_transform.basis, at)
	if smoke != null and float(piece["age"]) < SMOKES_FOR and fmod(float(piece["age"]), 0.12) < delta:
		smoke.call("puff_at", at, int(piece["id"]))
	var water: float = Terrain.water_height(at)
	var ground: float = Terrain.ground_height(at)
	if water > -INF and at.y <= water and water >= ground:
		piece["state"] = "water"
	elif ground > -INF and at.y <= ground:
		node.global_position = Vector3(at.x, ground, at.z)
		piece["state"] = "ground"


## How many pieces are in the air, on the ground and in the water, for the tests.
func counts() -> Dictionary:
	var out := {"air": 0, "ground": 0, "water": 0}
	for piece in _pieces:
		out[piece["state"]] = int(out[piece["state"]]) + 1
	return out
