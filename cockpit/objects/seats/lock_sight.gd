@tool
extends Node3D
class_name LockSight
## WHAT A PILOT WITH MISSILES LOOKS THROUGH: the seeker's circle, a diamond on whatever it has, how far the lock has
## got, and whether it will let you launch.
##
## FITTED TO THE SEATS THE SIMULATION SAYS CAN LAUNCH, exactly as a `GunSight` is fitted to the seats whose mount has
## a gun: see `CockpitStation._fit_the_missiles`, which reads `missile_schema(kind).launch_seats` rather than a list
## kept here.
##
## IT DRAWS AND NEVER DECIDES. Every word and every mark on it comes from the lock state the simulation publishes
## for this seat -- `phase`, `progress`, `bearing`, `range`, and `why`, which says whether a launch would be taken and
## if not, why not. A sight that worked out "locked" or "can launch" for itself would be a sight that says SHOOT
## a tick before the server agrees, and a pilot who believed it would press the button on a refusal.
##
## THE DIAMOND IS ON THE AIRCRAFT YOU CAN SEE. `bearing` and `range` are worked out on this machine from where the
## locked target is DRAWN -- the simulation sends which vehicle, as this machine's own entity id, and the bearing is
## taken from its drawn place -- so the mark sits on the aeroplane rather than a round trip away from it. `bearing` is
## in the aircraft's frame and goes onto the glass through the aircraft's attitude. While the target has not reached
## this machine the row has no `bearing` at all, and there is no diamond to draw.

## How far in front of the eyes the glass sits. Further than the gun sight: a head-up display is focused out, and
## the pilot reads the instruments under it.
const AT: float = 0.60
## The largest the seeker's circle is drawn, as a radius on the glass. A radar's wide cone would otherwise fill it.
const WIDEST: float = 0.11
const DIAMOND: float = 0.012

const AMBER := Color(1.0, 0.72, 0.22, 0.9)
const GREEN := Color(0.45, 0.95, 0.55, 0.9)
const RED := Color(1.0, 0.30, 0.22, 0.9)

## The phases, in the simulation's order. See lock_states' `phase`.
enum Phase { NONE, SEARCHING, LOCKING, LOCKED, LOST }

var _ring: MeshInstance3D = null
var _diamond: MeshInstance3D = null
var _bar: MeshInstance3D = null
var _board: Label3D = null
var _cross: Node3D = null
var _paint: Dictionary = {}
var _cone: float = -1.0
## ON THE HELMET, NOT ON THE GLASS: a station whose seeker is the crewman's head (`missile_schema`'s `helmet`, the
## AH-64D's Hellfires, lane/apache step 4) draws its circle in front of his EYE, wherever he looks, because that is where
## the seeker is looking -- a circle on the glass ahead of the seat would be a circle round the one place a helmet lock is
## not. `follow` puts it there every drawn frame; nothing about what it SAYS changes.
var helmet: bool = false:
	set(value):
		helmet = value
		top_level = value


func _ready() -> void:
	for pair in [["amber", AMBER], ["green", GREEN], ["red", RED]]:
		var glass := StandardMaterial3D.new()
		glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glass.albedo_color = pair[1]
		_paint[pair[0]] = glass

	_ring = MeshInstance3D.new()
	_ring.name = "Seeker"
	_ring.mesh = _hoop(0.05)
	# A torus lies flat; the circle has to stand up and face the eyes.
	_ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_ring.material_override = _paint["amber"]
	add_child(_ring)

	_diamond = MeshInstance3D.new()
	_diamond.name = "Diamond"
	var box := BoxMesh.new()
	box.size = Vector3(DIAMOND, DIAMOND, 0.001)
	_diamond.mesh = box
	_diamond.rotation = Vector3(0.0, 0.0, PI * 0.25)
	_diamond.material_override = _paint["amber"]
	_diamond.visible = false
	add_child(_diamond)

	_bar = MeshInstance3D.new()
	_bar.name = "Progress"
	var strip := BoxMesh.new()
	strip.size = Vector3(1.0, 0.003, 0.001)
	_bar.mesh = strip
	_bar.material_override = _paint["amber"]
	_bar.visible = false
	add_child(_bar)

	# THE GUN CROSS: where the rounds go, on the boresight -- the minigun fires along the aircraft's nose, and at the
	# ranges a rifle round is any use the glass-to-gun parallax is a few centimetres at a hundred metres. Two bars, each
	# with a gap in the middle so the target stays visible through the centre of it.
	_cross = Node3D.new()
	_cross.name = "GunCross"
	_cross.visible = false
	for bar in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0)]:
		var arm := MeshInstance3D.new()
		var piece := BoxMesh.new()
		piece.size = Vector3(0.018, 0.003, 0.001) if bar.y == 0.0 else Vector3(0.003, 0.018, 0.001)
		arm.mesh = piece
		arm.position = bar * 0.016
		arm.material_override = _paint["green"]
		_cross.add_child(arm)
	add_child(_cross)

	_board = Label3D.new()
	_board.name = "Board"
	_board.font_size = 40
	_board.pixel_size = 0.00035
	_board.position = Vector3(0.0, -WIDEST - 0.04, 0.0)
	_board.modulate = Color(0.55, 0.95, 0.62)
	_board.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_board.text = "no missiles"
	add_child(_board)
	# ONLY WHERE NOTHING HAS PUT IT YET. A station rebuilt from its craft package places the sight from the document
	# before it enters the tree, and on the CB90 that is raised along the box (`look_along`); resetting it here put it
	# back at the aeroplane's 1.35 m and `stations` found the runtime differing from its document (lane/boats).
	if position == Vector3.ZERO:
		position = Vector3(0.0, CockpitStation.EYE_HEIGHT, -AT)


## ONE DRAWN FRAME OF A HELMET SIGHT: `AT` in front of the eye, square to the look. The diamond's projection in
## `show_lock` assumes the eye is `AT` behind the glass, and here it is, exactly.
func follow(eye: Vector3, look: Basis) -> void:
	var facing: Basis = look.orthonormalized()
	global_transform = Transform3D(facing, eye + facing * Vector3(0.0, 0.0, -AT))


## THE GLASS ALONG THE LAUNCHER, `pitch` radians above the nose: where the seeker looks, so its circle is drawn where
## it can see and the diamond lands on the aircraft it has. The eye stays `AT` behind the glass, which is what the
## diamond's projection assumes. Zero, the aeroplane's, leaves it where `_ready` put it.
func look_along(pitch: float) -> void:
	position = Vector3(0.0, CockpitStation.EYE_HEIGHT + AT * sin(pitch), -AT * cos(pitch))
	rotation = Vector3(pitch, 0.0, 0.0)


## ONE FRAME OF THE LOCK. `lock` is this seat's row of `lock_states`, or empty before the seat has ever asked for one.
## `station` is the selected station's name, `loaded` how many of its pylons still have a missile, `armed` the master
## arm, `cone` the selected type's seeker half-angle in radians, and `craft` the aircraft, whose attitude turns the
## lock's bearing into a place on the glass.
##
## `gun` is whether the selected station is a GUN (the fighter's minigun, plan item 4): the seeker's circle, the diamond
## and the bar go, a CROSS on the boresight takes their place, and the board says GUNS and whether the trigger will fire.
##
## `rounds` is what the gun's drum has left (`CockpitWorld.gun_rounds`), or -1 for a gun that keeps no count; and
## `heading`, when it is not empty, is a first line naming whose sight this repeats -- the back seat of a two-seat jet
## is shown the PILOT's lock (lane/jetarms, 2026-09-18), and says so.
func show_lock(lock: Dictionary, station: String, loaded: int, armed: bool, cone: float, craft: Node3D,
		gun: bool = false, rounds: int = -1, heading: String = "") -> void:
	if _board == null:
		return
	_cross.visible = gun
	_ring.visible = not gun
	if gun:
		_diamond.visible = false
		_bar.visible = false
		var said: PackedStringArray = [] if heading.is_empty() else [heading]
		said.append(("GUNS %d   %s" % [rounds, "ARMED" if armed else "SAFE"]) if rounds >= 0
			else "GUNS   %s" % ("ARMED" if armed else "SAFE"))
		# THE SERVER'S WORD, as for a missile: SHOOT when it would fire, and its reason when it would not.
		if lock.has("why"):
			said.append("SHOOT" if int(lock.get("why", 1)) == 0 else String(lock.get("why_name", "")).to_upper()
				.replace("_", " "))
		_board.text = "\n".join(said)
		return
	if not is_equal_approx(cone, _cone):
		_cone = cone
		_ring.mesh = _hoop(clampf(tan(clampf(cone, 0.0, 1.4)) * AT, 0.01, WIDEST))
	var phase: int = int(lock.get("phase", Phase.NONE))
	var colour: String = "green" if phase == Phase.LOCKED else ("red" if phase == Phase.LOST else "amber")
	_ring.material_override = _paint[colour]
	_diamond.material_override = _paint[colour]
	_bar.material_override = _paint[colour]

	# THE DIAMOND, through the aircraft's attitude and then the glass's, onto the plane of the glass as the eye sees it.
	var on_glass: bool = false
	if (phase == Phase.LOCKING or phase == Phase.LOCKED) and craft != null and lock.has("bearing"):
		var bearing: Vector3 = lock.get("bearing", Vector3.ZERO) as Vector3
		var seen: Vector3 = global_basis.inverse() * (craft.global_basis * bearing)
		if seen.z < -0.01:
			var mark := Vector3(seen.x, seen.y, 0.0) * (AT / -seen.z)
			on_glass = Vector2(mark.x, mark.y).length() <= WIDEST * 1.4
			_diamond.position = mark
	_diamond.visible = on_glass

	var progress: float = clampf(float(lock.get("progress", 0.0)), 0.0, 1.0)
	_bar.visible = phase == Phase.LOCKING
	_bar.scale = Vector3(maxf(progress * WIDEST * 2.0, 0.0001), 1.0, 1.0)
	_bar.position = Vector3(-WIDEST + progress * WIDEST, -WIDEST - 0.012, 0.0)

	var lines: PackedStringArray = [] if heading.is_empty() else [heading]
	lines.append("%s x%d   %s" % [station.to_upper(), loaded, "ARMED" if armed else "SAFE"])
	match phase:
		Phase.SEARCHING:
			lines.append("SEARCH")
		Phase.LOCKING:
			lines.append("LOCKING %d%%" % int(round(progress * 100.0)))
		Phase.LOCKED:
			lines.append("LOCKED   %.1f km" % (float(lock["range"]) / 1000.0) if lock.has("range") else "LOCKED")
		Phase.LOST:
			lines.append("LOST")
		_:
			lines.append("PRESS LOCK")
	# WHAT THE SERVER WILL SAY TO A LAUNCH, in its own words. Absent before the seat has a lock row at all.
	if lock.has("why"):
		lines.append("SHOOT" if int(lock.get("why", 1)) == 0 else String(lock.get("why_name", "")).to_upper()
			.replace("_", " "))
	_board.text = "\n".join(lines)


## The circle, `radius` across the glass.
static func _hoop(radius: float) -> TorusMesh:
	var hoop := TorusMesh.new()
	hoop.inner_radius = radius
	hoop.outer_radius = radius + 0.003
	hoop.rings = 32
	return hoop


## What the board says, for the tests.
func says() -> String:
	return _board.text if _board != null else ""


## Whether the gun cross is up in place of the seeker, for the tests.
func shows_the_gun_cross() -> bool:
	return _cross != null and _cross.visible and _ring != null and not _ring.visible


## Whether the diamond is on the glass, for the tests.
func shows_the_diamond() -> bool:
	return _diamond != null and _diamond.visible
