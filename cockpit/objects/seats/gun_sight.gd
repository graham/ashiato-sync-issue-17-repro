@tool
extends Node3D
class_name GunSight
## WHAT A GUNNER LOOKS THROUGH: a reticle, the round that is loaded, and how far away the
## ground is where the gun is pointing.
##
## FITTED TO THE SEAT, NOT AUTHORED INTO A COCKPIT. Which seats have guns is a fact about
## the CRAFT -- three of a gunship's four, one of a tank's three -- and the same station
## scene is used by every seat in a craft. So this is added by `CockpitStation.fit` to the
## seats whose mount actually carries a gun, exactly as the two multi-function displays are
## added to the seats that do not fly. See the note there.
##
## THE RANGE IS THE INTERESTING NUMBER, and it is the one thing a sight can tell a gunner
## that they cannot see for themselves. It is where the BARREL meets the ground -- not the
## distance to whatever is in the middle of the reticle, which would need a rangefinder --
## so it says the same thing a tank's gunner reads off a stadia line: if you fire now, it
## lands about there.

## How far in front of the eyes the glass sits. Close enough to look through, far enough
## not to be inside somebody's face.
## Far enough forward to be clear of the instrument panel and at eye height rather than
## hand height: a sight is a thing you look THROUGH, and one sitting on the coaming is one
## you look over the top of.
const AT: float = 0.52
const RING: float = 0.055
## WHERE THE GLASS STANDS, in the space of whatever this is fitted to.
##
## In front of the eyes unless something says otherwise, which is a sight bolted to the
## cockpit. A gun that SWINGS carries its own -- see CockpitStation._fit_the_gun -- and then
## this is a place on the receiver instead, so that the reticle goes where the barrel goes.
##
## INFINITE FOR "NOBODY HAS SAID", rather than the eye height written out here: a constant
## defaulted from `CockpitStation.EYE_HEIGHT` would be evaluated at PARSE time, and a
## station scene half way through loading itself is the cycle that broke every cockpit in
## the game once already. See the note on EYE_HEIGHT.
var stands_at := Vector3.INF

var _ring: MeshInstance3D = null
var _cross: Array[MeshInstance3D] = []
var _board: Label3D = null
## Which mount this sight belongs to, so a three-gun aeroplane's three sights each show
## their own gun.
var mount: int = 0


func _ready() -> void:
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glass.albedo_color = Color(0.45, 0.95, 0.55, 0.85)

	_ring = MeshInstance3D.new()
	var hoop := TorusMesh.new()
	hoop.inner_radius = RING
	hoop.outer_radius = RING + 0.004
	hoop.rings = 24
	_ring.mesh = hoop
	# A torus lies flat; the reticle has to stand up and face the eyes.
	_ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_ring.material_override = glass
	add_child(_ring)

	# The cross, in four pieces with a gap in the middle: an unbroken cross hides the one
	# thing the gunner is trying to look at.
	for i in range(4):
		var arm := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.0025, 0.0025, RING * 0.7)
		arm.mesh = bar
		arm.material_override = glass
		var out: float = RING * 0.65
		match i:
			0: arm.position = Vector3(0.0, out, 0.0); arm.rotation = Vector3(PI * 0.5, 0, 0)
			1: arm.position = Vector3(0.0, -out, 0.0); arm.rotation = Vector3(PI * 0.5, 0, 0)
			2: arm.position = Vector3(out, 0.0, 0.0); arm.rotation = Vector3(0, 0, PI * 0.5)
			3: arm.position = Vector3(-out, 0.0, 0.0); arm.rotation = Vector3(0, 0, PI * 0.5)
		add_child(arm)
		_cross.append(arm)

	_board = Label3D.new()
	_board.font_size = 40
	_board.pixel_size = 0.00035
	_board.position = Vector3(0.0, -RING - 0.035, 0.0)
	_board.modulate = Color(0.55, 0.95, 0.62)
	_board.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_board.text = "no gun"
	add_child(_board)
	position = stands_at if stands_at.is_finite() \
		else Vector3(0.0, CockpitStation.EYE_HEIGHT, -AT)


## WHAT THE GUN IS DOING, once a frame. `aim` is the mount's own two angles as the wire
## carries them, and `craft` is the vehicle's pose, which is what turns a gun angle into a
## place on the ground.
func show_gun(aim: Vector2, ammo: String, craft: Transform3D) -> void:
	if _board == null:
		return
	# The barrel, in the craft's frame and then in the world's. The same expression the
	# simulation fires along -- see `fire_gun` -- because a sight that agreed with a
	# different formula would be a sight that lies.
	var along := Vector3(-sin(aim.x) * cos(aim.y), sin(aim.y), -cos(aim.x) * cos(aim.y))
	var heading: Vector3 = craft.basis * along
	var from: Vector3 = craft.origin
	var says: String = ammo.to_upper()
	# WHERE IT MEETS THE GROUND. Only if it is pointing DOWN at all: a gun aimed at the sky
	# has no range, and a sight that answered "17 kilometres" for it would be worse than
	# one that says nothing.
	if heading.y < -0.01 and from.y > 0.0:
		var reach: float = from.y / -heading.y
		says += "   %d m" % int(round((heading * reach).length()))
	else:
		says += "   ---"
	_board.text = says
