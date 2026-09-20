@tool
extends RefCounted
class_name Destroyer
## A 155 m ARLEIGH BURKE FLIGHT IIA, NEAR: a low haze-grey hull with a knuckle and a raked stem, the canted deckhouse
## carrying its four SPY faces, the lattice mast, two funnels, the gun forward, the VLS blocks fore and aft, and the two
## side-by-side hangars over the flight deck -- one vertex-coloured mesh on the shape's parts.
##
## THE PARTS ARE THE AUTHORITY (`DestroyerDraft` until the kind is C++). References in `craft/destroyer/sources.md`.
##
## WHAT MAKES IT READ AS A BURKE, in the order it matters:
## 1. THE FOUR SPY FACES ON CANTED CORNERS of one deckhouse. SPY-1D puts all four on a single deckhouse (PUBLISHED),
##    unlike SPY-1A/B's two, and each face is a PUBLISHED 3.66 m octagon. Get the faces' place and rake right and the
##    silhouette is a Burke from any angle; get them wrong and it is a generic warship.
## 2. THE TWO HANGARS AFT, which is Flight IIA and not Flight I or II.
## 3. The low freeboard, the long flush deck and the knuckle running forward.
##
## THE ONE NUMBER WITH NO EVIDENCE BEHIND IT IS THE CANT, and it is the most looked-at feature on the ship. The published
## octagon cannot measure it: a face on a canted corner is foreshortened TWICE, in width by the cant and in height by its
## rake, which is one observable against two unknowns. Measuring it on the broadside fails on resolution -- 62 px
## unforeshortened, ~44 px canted, in a region where an array and a locker look alike. `SPY_CANT` IS AN ESTIMATE AND IS
## SAID TO BE ONE; it wants an overhead or plan view (`sources.md`, outstanding requirements).
##
## THE SHIP TYPE AND NOT THE SHIP: haze grey, no pennant number, no name, no insignia.

const HAZE := Color(0.46, 0.49, 0.52)
const DECK := Color(0.33, 0.35, 0.36)
const BOOT := Color(0.13, 0.14, 0.16)
const BOTTOM := Color(0.28, 0.10, 0.09)
const DARK := Color(0.26, 0.28, 0.30)
const GLASS := Color(0.10, 0.12, 0.15)
const STEEL := Color(0.38, 0.40, 0.42)
const SOOT := Color(0.09, 0.09, 0.10)
const ARRAY := Color(0.30, 0.32, 0.35)
const WHITE := Color(0.82, 0.82, 0.80)
## THE SILHOUETTE'S PAINT: a warship is haze grey at every distance, so this is close to `ShipHull.PAINT` and exists only
## so the flight deck reads darker than the hull at range.
const FAR: Dictionary = {
	"hull": HAZE,
	"deck": DECK,
	"island": HAZE,
	"bridge": Color(0.50, 0.52, 0.54),
}

## THE HULL'S SECTIONS, as shares of its own keel: a fine warship form, wall-sided at the knuckle and fining hard to a
## narrow keel. The stem rakes 9 m aft by the keel and the transom is square (MEASURED in proportion off B4's underwater
## profile; the absolute depths are `DestroyerDraft.DRAUGHT`).
const ROWS: Array = [
	[0.0, 1.00, 2.0, 0.0],
	[-0.30, 0.92, 4.5, 0.0],
	[-0.65, 0.66, 7.0, 0.0],
	[-1.0, 0.16, 9.0, 0.0],
]
## HOW MANY STATIONS THE HULL IS LOFTED ON. THE LOW-POLY LOOK IS DELIBERATE (the user, 2026-09-17) with the E-2D's
## airframe as the reference: few rows, few sides, flat plating, hard knuckles. Fourteen stations over 155 m is a knuckle
## every 11 m, and the four rows give the section one chine at the turn of the bilge. DO NOT SUBDIVIDE THIS.
const STATIONS: int = 14
const POST_SPACING: float = 7.0
## THE SONAR DOME under the bow, which is what the published 9.45 m draught is measured to and the hull is not.
const DOME_FROM_BOW: float = 8.0
## NARROWER AND LONGER THAN THE FIRST VERSION, which hung under the bow as a detached brick in elevation
## (screenshots, 2026-09-17). A real dome is faired into the forefoot; this is still a box, because the house style is
## faceted, but a long slim one reads as part of the hull rather than as luggage.
const DOME := Vector3(3.2, 5.8, 26.0)
## THE SPY FACES: a PUBLISHED 3.66 m octagon, one on each canted corner of the lower deckhouse.
const SPY_FACE: float = 3.66
## THE FACE'S RAKE BACK FROM VERTICAL. **ESTIMATE** -- see the doc block above; no reference here can measure it.
const SPY_RAKE: float = 8.0
## HOW HIGH THE FACES' CENTRES STAND over the main deck. ESTIMATE, set so the octagon sits inside the lower deckhouse
## step rather than crossing its top edge.
const SPY_CENTRE: float = 3.9
## THE MAST, the funnels and the gun. ESTIMATES off the broadside's proportions.
const MAST_HALF: float = 0.55
const FUNNEL := Vector3(4.4, 5.2, 6.0)
const FUNNEL_FROM_BOW: float = 66.0
const FUNNEL_SPACING: float = 26.0
## THE 5-INCH MOUNT, 26 m from the stem: forward of the VLS, and far enough aft that the helm's line to the deck ahead
## passes OVER it rather than into it. At 20 m the mount stood exactly on that line and the check named it
## (tests/merchant_models.gd, 2026-09-17) -- which is the sight-line check doing the job a layout drawing would.
const GUN_MOUNT := Vector3(4.0, 2.2, 5.0)
const VLS_FORWARD_FROM_BOW: float = 31.0
const VLS_AFT_FROM_BOW: float = 96.0
const VLS := Vector3(7.2, 0.5, 5.0)


## THE NEAR MODEL: `{"mesh", "panels", "fittings"}`.
static func build(geometry: Dictionary, _helm: String = "glazed") -> Dictionary:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: Array = geometry.get("parts", []) as Array
	var panels: Array[AABB] = []
	var fittings: Array[AABB] = []
	for part in parts:
		var outline: PackedVector2Array = part["outline"]
		var bottom: float = float(part["bottom"])
		var top: float = float(part["top"])
		var r: Rect2 = Wheelhouse.outline_rect(outline)
		match String(part["part"]):
			"hull":
				HullLoft.build(tool, outline, rows_for(top, bottom), 0.0, [HAZE, BOOT, BOTTOM], STATIONS,
					Vector2(DestroyerDraft.FREEBOARD_STEM - DestroyerDraft.FREEBOARD_MID,
						DestroyerDraft.FREEBOARD_STERN - DestroyerDraft.FREEBOARD_MID), DECK)
				# THE MAIN DECK IS PLATED BY THE LOFT, not by `Plating.paint`. A loft is sides, ends and a keel with
				# nothing across its top (the trap `Ferry` paid for) -- but this deck is SHEARED, and one flat polygon
				# at one height would hide the sheer from the eye and from `_top_over`, which reads the highest
				# up-facing face and would have found the flat one.
				# THE SONAR DOME under the bow, which is the thing the PUBLISHED 9.45 m draught is measured to and the
				# hull is NOT. Drawn to DOME_DEPTH so the deepest point of the model is the dome and the hull floats
				# at its own 6.63 m: a hull drawn to the published figure would sit 2.9 m too deep with every size
				# check green (cockpit-fleet3, 2026-09-17).
				var nose: float = r.position.y + DOME_FROM_BOW
				Plating.box(tool, Vector3(0.0, -(DestroyerDraft.DOME_DEPTH + bottom) * 0.5 + bottom,
					nose + DOME.z * 0.5), Vector3(DOME.x, DestroyerDraft.DOME_DEPTH + bottom, DOME.z), BOTTOM)
				# THE KNUCKLE: a hard line down the ship's side, which is what a Burke has instead of a flared curve.
				Plating.band(tool, r, top - 2.1, top - 1.9, DARK, 0.0)
			"island":
				var hangar: bool = absf(top - bottom - DestroyerDraft.HANGAR_ROOF) < 0.01
				Plating.prism(tool, outline, bottom, top, HAZE)
				Plating.paint(tool, outline, top, DECK)
				panels.append(AABB(Vector3(r.position.x, bottom, r.position.y), Vector3(r.size.x, top - bottom, r.size.y)))
				if hangar:
					_hangar_door(tool, r, bottom, top)
				elif is_equal_approx(bottom, DestroyerDraft.FREEBOARD_MID):
					# THE FOUR SPY FACES, on the four canted corners of the LOWER deckhouse only.
					_spy_faces(tool, outline, bottom, panels, fittings)
			"deck":
				_flight_deck(tool, outline, top, r)
			"bridge":
				panels.append_array(Wheelhouse.build(tool, part, ["fore", "port", "starboard"], HAZE, STEEL))
	_on_the_deck(tool, parts, panels, fittings)
	return {"mesh": Plating.weld(tool), "panels": panels, "fittings": fittings}


## THE HULL'S ROWS IN METRES, its top first: the main deck, then `ROWS` against the hull's own keel.
static func rows_for(top: float, bottom: float) -> Array:
	var out: Array = [[top, 1.0, 0.0, 0.0]]
	for row in ROWS:
		out.append([-float(row[0]) * bottom, float(row[1]), float(row[2]), float(row[3])])
	return out


## THE FOUR SPY OCTAGONS, one per canted side of the deckhouse's plan. A canted side is any edge of the outline that is
## neither athwartships nor fore-and-aft; there are exactly four of them on `DestroyerDraft._canted`'s eight-sided plan,
## which is why the plan is drawn that way rather than as a rectangle.
static func _spy_faces(tool: SurfaceTool, outline: PackedVector2Array, bottom: float, panels: Array[AABB],
		fittings: Array[AABB]) -> void:
	var n: int = outline.size()
	for i in range(n):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % n]
		var edge: Vector2 = b - a
		# A CANTED EDGE runs in both x and z. The square sides run in one only.
		if absf(edge.x) < 0.5 or absf(edge.y) < 0.5:
			continue
		var mid: Vector2 = (a + b) * 0.5
		var out_dir: Vector2 = Vector2(edge.y, -edge.x).normalized()
		if mid.dot(out_dir) < 0.0:
			out_dir = -out_dir
		var across: Vector2 = edge.normalized() * (SPY_FACE * 0.5)
		var centre := Vector3(mid.x, bottom + SPY_CENTRE, mid.y) + Vector3(out_dir.x, 0.0, out_dir.y) * 0.12
		# THE OCTAGON, raked back by `SPY_RAKE`: its top edge leans in over its bottom edge by that angle.
		var lean: float = SPY_FACE * 0.5 * sin(deg_to_rad(SPY_RAKE))
		var rise: float = SPY_FACE * 0.5 * cos(deg_to_rad(SPY_RAKE))
		var inward := Vector3(-out_dir.x, 0.0, -out_dir.y) * lean
		var side := Vector3(across.x, 0.0, across.y)
		# Eight corners, as a flat octagon: the chamfer is a third of the face, which is what a 12 ft array looks like.
		var c: float = 0.33
		var corners: Array[Vector3] = [
			centre + side * c + Vector3(0, rise, 0) + inward,
			centre - side * c + Vector3(0, rise, 0) + inward,
			centre - side + Vector3(0, rise * c, 0) + inward * c,
			centre - side - Vector3(0, rise * c, 0) - inward * c,
			centre - side * c - Vector3(0, rise, 0) - inward,
			centre + side * c - Vector3(0, rise, 0) - inward,
			centre + side - Vector3(0, rise * c, 0) - inward * c,
			centre + side + Vector3(0, rise * c, 0) + inward * c,
		]
		tool.set_color(ARRAY)
		for k in range(1, corners.size() - 1):
			for v in [corners[0], corners[k], corners[k + 1]]:
				tool.set_normal(Vector3(out_dir.x, 0.0, out_dir.y))
				tool.add_vertex(v)
		var box := AABB(corners[0], Vector3.ZERO)
		for v in corners:
			box = box.expand(v)
		# A PANEL AND NOT A FITTING. An array face is the deckhouse's own skin; a fitting is a thing that STANDS on a
		# part, and `tests/ship_models.gd` holds every fitting's foot to the top of the part under it. Reported as a
		# fitting, the four faces read as "on nothing" at 7.96 m -- correctly, because nothing is under them.
		panels.append(box)


## A HANGAR DOOR in the after face of a hangar box: the thing a Flight IIA is recognised by from astern.
static func _hangar_door(tool: SurfaceTool, r: Rect2, bottom: float, top: float) -> void:
	var z: float = r.end.y + 0.04
	var wide: float = r.size.x * 0.78
	var x: float = r.get_center().x
	Plating.facing(tool, [Vector3(x - wide * 0.5, top - 0.8, z), Vector3(x + wide * 0.5, top - 0.8, z),
		Vector3(x + wide * 0.5, bottom + 0.3, z), Vector3(x - wide * 0.5, bottom + 0.3, z)], Vector3.BACK, DARK)


## THE FLIGHT DECK: a darker deck with its landing circle, and a rail round three sides.
static func _flight_deck(tool: SurfaceTool, outline: PackedVector2Array, top: float, r: Rect2) -> void:
	Plating.paint(tool, outline, top, DECK)
	var centre := Vector2(r.get_center().x, r.get_center().y + 1.5)
	# TWELVE DASHES TO THE CIRCLE and an eight-sided spot in the middle: a circle on a deck is a ring of plate, not a
	# curve (the low-poly rule, as on both merchant ships).
	var radius: float = 5.4
	for i in range(12):
		var a: float = TAU * float(i) / 12.0
		var b: float = TAU * (float(i) + 0.62) / 12.0
		Plating.line(tool, centre + Vector2(cos(a), sin(a)) * radius, centre + Vector2(cos(b), sin(b)) * radius,
			0.35, top + 0.02, WHITE)
	var spot := PackedVector2Array()
	for i in range(8):
		var a: float = TAU * float(i) / 8.0
		spot.append(centre + Vector2(cos(a), sin(a)) * 1.5)
	Plating.paint(tool, spot, top + 0.02, WHITE)
	var ring: PackedVector2Array = Plating.upward(outline)
	for i in range(ring.size()):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % ring.size()]
		# The forward edge of the flight deck runs against the hangars: no rail there.
		if minf(a.y, b.y) < r.position.y + 0.5:
			continue
		var inward: Vector2 = (r.get_center() - (a + b) * 0.5).normalized() * 0.25
		Plating.bar(tool, a + inward, b + inward, 0.05, top + 1.05, top + 1.1, STEEL)
		var posts: int = maxi(int(a.distance_to(b) / POST_SPACING), 1)
		for k in range(posts + 1):
			var at: Vector2 = a.lerp(b, float(k) / float(posts)) + inward
			Plating.box(tool, Vector3(at.x, top + 0.55, at.y), Vector3(0.05, 1.1, 0.05), STEEL)


## WHAT STANDS ON THE DECK: the gun forward, the two VLS blocks, the funnels, the mast and the sonar dome under the bow.
static func _on_the_deck(tool: SurfaceTool, parts: Array, panels: Array[AABB], fittings: Array[AABB]) -> void:
	var bow: float = -DestroyerDraft.LENGTH * 0.5
	# THE 5-INCH GUN, on the forecastle: a mount with a barrel over it.
	var gun: AABB = _stand(tool, parts, Vector2(0.0, bow + DestroyerDraft.GUN_FROM_BOW), GUN_MOUNT, HAZE, panels,
		fittings)
	Plating.box(tool, Vector3(0.0, gun.end.y - 0.4, gun.get_center().z - 3.6), Vector3(0.5, 0.5, 5.4), DARK)
	# THE TWO VLS BLOCKS, flush with the deck: a grid of hatches forward of the house and abaft it.
	for from_bow in [VLS_FORWARD_FROM_BOW, VLS_AFT_FROM_BOW]:
		var at := Vector2(0.0, bow + from_bow)
		var top: float = Superstructure.top_under(parts, at)
		if is_inf(top):
			continue
		var block := AABB(Vector3(at.x - VLS.x * 0.5, top, at.y - VLS.z * 0.5), VLS)
		Plating.box(tool, block.get_center(), block.size, DARK)
		for row in range(3):
			for col in range(4):
				var cell := Vector3(at.x + (float(col) - 1.5) * 1.7, top + VLS.y + 0.02,
					at.y + (float(row) - 1.0) * 1.8)
				Plating.box(tool, cell, Vector3(1.4, 0.08, 1.5), STEEL)
		panels.append(block)
		fittings.append(block)
	# THE TWO FUNNELS, canted-sided like the deckhouse, with soot caps.
	for from_bow in [FUNNEL_FROM_BOW, FUNNEL_FROM_BOW + FUNNEL_SPACING]:
		var at := Vector2(0.0, bow + from_bow)
		var stack: AABB = _stand(tool, parts, at, FUNNEL, HAZE, panels, fittings)
		Plating.box(tool, Vector3(at.x, stack.end.y + 0.35, at.y), Vector3(FUNNEL.x * 0.8, 0.7, FUNNEL.z * 0.8), SOOT)
	# THE MAST, on the bridge roof, up to the MEASURED masthead.
	var bridge: Dictionary = Superstructure.part_of(parts, "bridge")
	if bridge.is_empty():
		return
	var room: Rect2 = Wheelhouse.outline_rect(bridge["outline"])
	var foot: float = float(bridge["top"])
	var mast := AABB(Vector3(room.get_center().x - MAST_HALF, foot, room.get_center().y - MAST_HALF + 2.0),
		Vector3(MAST_HALF * 2.0, DestroyerDraft.MASTHEAD - foot, MAST_HALF * 2.0))
	# A MAST WITH BULK. Drawn as one thin column it read as a whip antenna rather than a mast
	# (screenshots/2026-09-17/cockpit-fleet3-04-destroyer-bow.png): a Burke's is a heavy tapered tower with legs. So it
	# is a wide lower trunk, a narrower upper, and two raked legs -- three boxes, which is what the low-poly rule allows
	# and enough for the silhouette to read at a mile.
	var head: float = DestroyerDraft.MASTHEAD
	var waist: float = foot + (head - foot) * 0.45
	var cx: float = room.get_center().x
	var cz: float = room.get_center().y + 2.0
	Plating.box(tool, Vector3(cx, (foot + waist) * 0.5, cz), Vector3(2.6, waist - foot, 2.2), STEEL)
	Plating.box(tool, Vector3(cx, (waist + head) * 0.5, cz), Vector3(1.0, head - waist, 0.9), STEEL)
	for side in [-1.0, 1.0]:
		Plating.box(tool, Vector3(cx + side * 1.9, (foot + waist) * 0.5, cz + 1.4),
			Vector3(0.45, waist - foot, 0.45), STEEL)
	panels.append(mast)
	fittings.append(mast)
	# TWO YARDARMS across it, which is what makes a mast read as one at a distance.
	for up in [0.50, 0.68]:
		var y: float = foot + (head - foot) * up
		Plating.box(tool, Vector3(cx, y, cz), Vector3(9.0, 0.22, 0.4), STEEL)


## A BOX STOOD ON THE SHIP at a plan point, drawn, and handed back as a panel and a fitting.
static func _stand(tool: SurfaceTool, parts: Array, at: Vector2, size: Vector3, tint: Color, panels: Array[AABB],
		fittings: Array[AABB]) -> AABB:
	var top: float = Superstructure.top_under(parts, at)
	var box := AABB(Vector3(at.x - size.x * 0.5, 0.0 if is_inf(top) else top, at.y - size.z * 0.5), size)
	Plating.box(tool, box.get_center(), box.size, tint)
	panels.append(box)
	fittings.append(box)
	return box
