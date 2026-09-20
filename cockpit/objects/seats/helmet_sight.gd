@tool
extends Node3D
class_name HelmetSight
## WHAT A GUNNER WHOSE GUN FOLLOWS HIS HEAD SEES: a fixed cross where he is LOOKING -- the command -- and a ring where
## the GUN actually points. When the ring sits on the cross the gun is on, and the sight says so.
##
## The AH-64's IHADSS, which the user asked for in so many words: "this gun should follow where they look and be able to
## fire in that direction ... not instantly, there is some slew delay." The lag is the simulation's (`slew_to_the_head`
## in the C++): this only DRAWS it, the cross fixed in the view and the ring chasing it across the glass at the mount's
## rate, so a gunner can see the barrel arrive before he fires, and see that a burst fired early goes where the ring is.
##
## IT FOLLOWS THE EYE, NOT THE AIRCRAFT. A helmet display is on the helmet: both marks are drawn `AT` in front of the
## camera that is drawing, whichever way it points -- a headset or the desk's mouse look -- so the cross never leaves the
## middle of the view. The RING is where the barrel's round goes: the point `helmet_range` down the barrel from the
## trunnion (the same point the simulation lays the gun on), seen from the eye. So with the gun caught up, the ring is
## ON the cross, not a parallax's worth beside it.
##
## IT DRAWS AND NEVER DECIDES. The station hands it the eye, the craft and where the mount is laid -- the gunner's own
## PREDICTED aim, the simulation's (`CockpitStation._laid`) -- and it asks nothing of anybody. A sight that reached for
## the rig or the turret would be a sight that could not stand on a bench with no aircraft behind it.

## How far in front of the eye both marks are drawn, metres: past a headset's near plane and nearer than any glass.
const AT: float = 1.0
## The cross's arms and the ring's radius, on that plane: about one and a half degrees.
const CROSS: float = 0.022
const RING: float = 0.016
## How thick the cross's arms and the ring's hoop are drawn, on that plane: two and a half millimetres, about three pixels
## on a 1600-wide desk view. The first 1.5 mm read as a hairline that video compression took away.
const LINE: float = 0.0025
## HOW NEAR IS ON, radians between the look and the round's point: ten milliradians, three metres at 300 m.
const ON: float = 0.010

const AMBER := Color(1.0, 0.72, 0.22, 0.95)
const GREEN := Color(0.45, 0.95, 0.55, 0.95)

## The mount this sight shows, and what the simulation says it is: `Sim.gun_of(kind, mount)`.
var mount: int = 0
var gun: Dictionary = {}

var _cross: MeshInstance3D = null
var _ring: MeshInstance3D = null
var _word: Label3D = null
var _paint: Dictionary = {}
## WHETHER THE GUN IS ON, as last drawn: for a reader, and for `tests/helmet_gun.gd`.
var on: bool = false
## WHERE THE RING WAS LAST DRAWN, in this sight's frame (the eye's): for a reader, and for the suite.
var ring_at: Vector3 = Vector3.ZERO


func _ready() -> void:
	# ON THE HELMET, NOT ON THE STATION: `follow` puts it at the eye every frame.
	top_level = true
	for pair in [["amber", AMBER], ["green", GREEN]]:
		var glass := StandardMaterial3D.new()
		glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		# OVER EVERYTHING, as a display projected on the visor is: never behind the canopy frame or the nose.
		glass.no_depth_test = true
		# BOTH FACES. The cross's quads wind the way that faces AWAY from the eye in Godot's convention, and the first reel
		# (2026-09-18) drew the word GUN over an empty middle: the cross was being culled, every frame, from the one side
		# anybody ever sees it from.
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass.render_priority = 10
		glass.albedo_color = pair[1]
		_paint[pair[0]] = glass
	_cross = MeshInstance3D.new()
	_cross.name = "LookCross"
	var arms := ArrayMesh.new()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for bar in [Vector2(CROSS * 2.0, LINE), Vector2(LINE, CROSS * 2.0)]:
		var h := Vector2(bar) * 0.5
		for corner in [[-1, -1], [1, -1], [1, 1], [-1, -1], [1, 1], [-1, 1]]:
			tool.add_vertex(Vector3(h.x * corner[0], h.y * corner[1], 0.0))
	tool.commit(arms)
	_cross.mesh = arms
	_cross.position = Vector3(0.0, 0.0, -AT)
	_cross.material_override = _paint["amber"]
	add_child(_cross)
	_ring = MeshInstance3D.new()
	_ring.name = "GunRing"
	var hoop := TorusMesh.new()
	hoop.inner_radius = RING - LINE
	hoop.outer_radius = RING
	hoop.rings = 24
	hoop.ring_segments = 3
	_ring.mesh = hoop
	_ring.material_override = _paint["amber"]
	add_child(_ring)
	_word = Label3D.new()
	_word.name = "Word"
	_word.pixel_size = 0.0009
	_word.font_size = 24
	_word.no_depth_test = true
	_word.render_priority = 11
	_word.modulate = AMBER
	_word.position = Vector3(0.0, -CROSS * 2.2, -AT)
	_word.text = "GUN"
	add_child(_word)


## ONE FRAME: the eye's position and orientation, the craft's transform, and where the mount is laid (yaw, pitch in the
## craft's frame, the simulation's sense: yaw positive to port). Everything drawn is worked out from those four.
func follow(eye: Vector3, look: Basis, craft: Transform3D, laid: Vector2) -> void:
	if _ring == null:
		return
	global_transform = Transform3D(look.orthonormalized(), eye)
	var along := Vector3(-sin(laid.x) * cos(laid.y), sin(laid.y), -cos(laid.x) * cos(laid.y))
	var trunnion: Vector3 = craft * (gun.get("at", Vector3.ZERO) as Vector3)
	var point: Vector3 = trunnion + craft.basis * along * float(gun.get("helmet_range", 800.0))
	var toward: Vector3 = (point - eye).normalized()
	var local: Vector3 = global_transform.basis.inverse() * toward
	# BEHIND THE EYE THE GUN CANNOT BE DRAWN: a head turned past the stops, looking back past the barrel.
	_ring.visible = local.z < -0.05
	if _ring.visible:
		ring_at = local / -local.z * AT
		_ring.position = ring_at
		# A torus lies flat; stood up to face the eye.
		_ring.basis = Basis(Vector3.RIGHT, PI * 0.5)
	on = _ring.visible and toward.angle_to(-global_transform.basis.z) < ON
	var paint: Material = _paint["green" if on else "amber"]
	_cross.material_override = paint
	_ring.material_override = paint
	_word.text = "GUN ON" if on else "GUN"
	_word.modulate = GREEN if on else AMBER
