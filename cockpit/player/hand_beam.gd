extends MeshInstance3D
class_name HandBeam
## A HAND'S POINTER: a thin beam out of the front of a controller, stopped at the nearest glass it meets, and the
## trigger pressing what it is on.
##
## ONE BEAM FOR EVERY GLASS. The clipboard, the snap board and whatever panels a level hands the rig -- the desk's two
## screens -- are all a `TouchPanel`, and all this does is ask each where the ray meets it (`TouchPanel.reach`), take the
## nearest, and aim that one alone (`TouchPanel.aim`). Lifted out of `PilotRig._point_a_hand` on 2026-09-14, when the
## user asked for the desk's monitors to be pointed at "like the ipad". They already could, but only while no board was
## up: the rig aimed the board ALONE while it was up, so with the clipboard out the monitors behind it could not be
## pointed at at all, and each board kept its own copy of the press-once state.
##
## NEAREST, AND ONLY THAT ONE. A ray through the clipboard that would also land on a monitor behind it presses the
## clipboard, because that is the glass in front, and nothing behind it hears a thing. The one that was pointed at last
## frame and is not now is told to `leave`, so a button does not stay lit under a beam that has gone.
##
## ONE PULL IS ONE PRESS, kept HERE and not per glass. A trigger already held when the beam arrives on a glass presses
## nothing -- sweeping a squeezed trigger across a page is not a way to press everything on it -- and that has to hold
## when the beam arrives from ANOTHER glass too. Two boards each keeping their own edge could not know that: a pull held
## on the clipboard and swept onto a monitor was, to the monitor, a pull that had just gone down.
##
## IT DRAWS AND IT ANNOUNCES NOTHING. Which hand points, and when there is a beam at all, is the rig's business; what a
## press means is the page's.

## How long the beam is drawn when it is not on any glass, in metres: long enough to see which way it points, short
## enough not to reach across the cockpit. KEPT, rather than hiding the beam off the glass: a pointer that vanishes the
## moment it leaves the page is one you cannot use to find the page again (`TouchPanel.point_at` says the same).
const REACH: float = 0.6

## WHICH GLASS AND WHEN TO PRESS are `GlassPointer`'s, since 2026-09-14, when a desk's mouse needed the same answers.
## This draws the rod.
var _pointer: GlassPointer = GlassPointer.new()


func _init() -> void:
	name = "Pointer"
	var rod := BoxMesh.new()
	rod.size = Vector3(0.002, 0.002, 1.0)
	mesh = rod
	# Unshaded and a little see-through, so it reads as a pointer and not as a stick, and it casts no shadow.
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(0.55, 0.85, 1.0, 0.7)
	material_override = glow
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## POINT, from `from` along `along` (world space), at the nearest of `glasses`; press there if `pulled` has just gone
## down. Returns the glass the beam is on, or null. Drawn along the parent's -Z, which is the way a controller points.
func point(from: Vector3, along: Vector3, pulled: bool, glasses: Array[TouchPanel]) -> TouchPanel:
	var length: float = _pointer.point(from, along, pulled, glasses)
	if length < 0.0:
		length = REACH
	visible = true
	position = Vector3(0.0, 0.0, -length * 0.5)
	scale = Vector3(1.0, 1.0, length)
	return _pointer.on()


## No beam this frame. The glass it was on is let go of, and the next pull starts fresh.
func put_away() -> void:
	visible = false
	_pointer.let_go()


## The glass the beam is on, or null. For the rig, which holds the clipboard's highlight press off while it is on any.
func on_glass() -> TouchPanel:
	return _pointer.on() if visible else null
