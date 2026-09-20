@tool
extends RefCounted
class_name Ferry
## A 109 m WAVE-PIERCING CATAMARAN FERRY, NEAR: two slender white hulls with a blue boot-top, the centre bow between them,
## the wet deck over the tunnel, a band of passenger windows, an open roof deck, the wheelhouse on top of it and the
## exhausts at the after corners -- one vertex-coloured mesh on the shape's parts.
##
## THE PARTS ARE THE AUTHORITY (`FerryDraft` until the kind is C++). The references are in `craft/ferry/sources.md`
## (F1 to F3, photographs of HSC Express 3).
##
## TWO HULLS, SO THE LOFT IS RUN TWICE, each about its own axis (`HullLoft.build`'s `centre_x`, added for this ship). A
## demihull is not a ship's hull with the middle taken out: it is fine, wall-sided above the water and carries its own
## stem, and the tunnel between the two is the thing you see under the bow.
##
## THE SHIP TYPE AND NOT THE SHIP: no operator's colours, funnel mark or name.

const WHITE := Color(0.88, 0.88, 0.87)
const BLUE := Color(0.13, 0.26, 0.47)
const BOTTOM := Color(0.10, 0.11, 0.13)
const GREY := Color(0.44, 0.46, 0.48)
const DARK := Color(0.20, 0.21, 0.23)
const GLASS := Color(0.09, 0.11, 0.14)
const STEEL := Color(0.34, 0.36, 0.38)
const SOOT := Color(0.07, 0.07, 0.08)
const DECK := Color(0.42, 0.43, 0.42)
const ORANGE := Color(0.95, 0.48, 0.10)
## THE SILHOUETTE'S PAINT for `ShipHull.far_mesh`: white sides, a grey deck, and a darker band for the wheelhouse.
const FAR: Dictionary = {
	"hull": WHITE,
	"deck": DECK,
	"island": WHITE,
	"bridge": Color(0.48, 0.50, 0.52),
}

## A DEMIHULL'S SECTIONS, as shares of its own keel: wall-sided from the sheer to the water, then fining away to a keel
## less than a fifth of the hull's beam, which is what a 40-knot catamaran runs on. The stem rakes 8 m aft by the keel;
## the transom is square (ESTIMATE, F1 and F2).
const ROWS: Array = [
	[0.0, 1.00, 3.0, 0.0],
	[-0.45, 0.86, 5.0, 0.0],
	[-0.80, 0.55, 6.5, 0.0],
	[-1.0, 0.18, 8.0, 0.0],
]
## HOW MANY STATIONS A DEMIHULL IS LOFTED ON, and how far apart the roof rail's posts stand. THE LOW-POLY LOOK IS
## DELIBERATE (the user, 2026-09-17), with the E-2D's airframe as the reference: few rows, few sides, flat plating and hard
## knuckles. Ten stations over 107 m is a knuckle every 11 m, and the four rows give the section one chine at the turn of
## the bilge. DO NOT SUBDIVIDE THIS: the sizes are measured and the facets are the style.
const STATIONS: int = 10
const POST_SPACING: float = 5.0
## THE EXHAUSTS at the after corners of the roof, standing on it (F1, F2), and the mast on the wheelhouse roof.
const EXHAUST_X: float = 11.5
const EXHAUST_FROM_STERN: float = 12.0
const EXHAUST := Vector3(1.9, 5.0, 2.6)
const MAST_HALF: float = 0.35
## THE LIFERAFT STATIONS, one each side on the roof deck abreast the wheelhouse: an orange canister on a white cradle (F2).
const RAFTS_FROM_BOW: float = 52.0
const RAFT := Vector3(1.2, 1.1, 3.6)


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
				HullLoft.build(tool, outline, rows_for(top, bottom), r.get_center().x, [WHITE, BLUE, BOTTOM], STATIONS)
				# THE SHEER, PLATED. A loft is sides, ends and a keel with nothing across its top, and the superstructure
				# stands 1.2 m inboard of the ship's side: the strip between them was a hole into the hull, and the check
				# that looks for the sheer found nothing there at all (tests/merchant_models.gd, 2026-09-17).
				Plating.paint(tool, outline, top - Superstructure.SHEER_DROP, DECK)
				# THE LINE OF THE VEHICLE DECK on the hull's side. Without it a demihull is one white slab 13.6 m tall from
				# the water to the sheer, and the ship read as a barge in elevation
				# (screenshots/2026-09-17/cockpit-fleet3-02-ferry-side.png, 2026-09-17). The real side has the break there.
				Plating.band(tool, r, FerryDraft.DEPTH - FerryDraft.DRAUGHT - 0.12,
					FerryDraft.DEPTH - FerryDraft.DRAUGHT + 0.12, GREY, 0.0)
			"island":
				# WHICH ISLAND THIS IS, BY WHERE ITS FLOOR IS, and not by how far forward it stands: the centre bow's floor
				# is its forefoot over the water, the cross structure's is the wet deck, the superstructure's is the sheer.
				# Asked as "is it forward of a quarter of the ship", the cross structure and the superstructure both began
				# forward of that line and were painted the centre bow's dark grey: from the bow the ship was a black slab
				# (screenshots/2026-09-17/cockpit-fleet3-02-ferry-bow.png, 2026-09-17).
				var forefoot: bool = is_equal_approx(bottom, FerryDraft.FOREFOOT)
				Plating.prism(tool, outline, bottom, top, DARK if forefoot else WHITE)
				panels.append(AABB(Vector3(r.position.x, bottom, r.position.y), Vector3(r.size.x, top - bottom, r.size.y)))
				if is_equal_approx(bottom, FerryDraft.SHEER):
					Plating.band(tool, r, FerryDraft.WINDOWS.x, FerryDraft.WINDOWS.y, GLASS, 1.4)
			"deck":
				_roof(tool, outline, bottom, top, r)
			"bridge":
				panels.append_array(Wheelhouse.build(tool, part, ["fore", "port", "starboard"], WHITE, STEEL))
	_on_the_roof(tool, parts, panels, fittings)
	return {"mesh": Plating.weld(tool), "panels": panels, "fittings": fittings}


## ONE DEMIHULL'S ROWS IN METRES, its top first: the sheer, then `ROWS` against that hull's own keel.
static func rows_for(top: float, bottom: float) -> Array:
	var out: Array = [[top, 1.0, 0.0, 0.0]]
	for row in ROWS:
		out.append([-float(row[0]) * bottom, float(row[1]), float(row[2]), float(row[3])])
	return out


## THE WATERJET OUTLETS in a demihull's transom, two to a hull: dark squares just under the water, which is what is there
## on a ship with no propeller and no rudder (F1).
static func _waterjets(tool: SurfaceTool, r: Rect2) -> void:
	for dx in [-1.1, 1.1]:
		var x: float = r.get_center().x + dx
		Plating.facing(tool, [Vector3(x - 0.7, -0.4, r.end.y + 0.03), Vector3(x + 0.7, -0.4, r.end.y + 0.03),
			Vector3(x + 0.7, -1.8, r.end.y + 0.03), Vector3(x - 0.7, -1.8, r.end.y + 0.03)], Vector3.BACK, DARK)


## THE ROOF: the deck people walk on, its plate, the side of the superstructure under it, and a rail all round.
static func _roof(tool: SurfaceTool, outline: PackedVector2Array, bottom: float, top: float, r: Rect2) -> void:
	Plating.paint(tool, outline, top, DECK)
	var ring: PackedVector2Array = Plating.upward(outline)
	tool.set_color(WHITE)
	for i in range(ring.size()):
		Plating.wall(tool, ring[i], ring[(i + 1) % ring.size()], bottom, top)
	for i in range(ring.size()):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % ring.size()]
		var inward: Vector2 = (r.get_center() - (a + b) * 0.5).normalized() * 0.25
		Plating.bar(tool, a + inward, b + inward, 0.05, top + 1.05, top + 1.1, GREY)
		var posts: int = maxi(int(a.distance_to(b) / POST_SPACING), 1)
		for k in range(posts + 1):
			var at: Vector2 = a.lerp(b, float(k) / float(posts)) + inward
			Plating.box(tool, Vector3(at.x, top + 0.55, at.y), Vector3(0.05, 1.1, 0.05), GREY)


## WHAT STANDS ON THE ROOF: the two exhausts at its after corners, the liferaft stations abreast the wheelhouse, and the
## mast on the wheelhouse roof. Each stands on the part under it and is reported as a fitting.
static func _on_the_roof(tool: SurfaceTool, parts: Array, panels: Array[AABB], fittings: Array[AABB]) -> void:
	var stern: float = FerryDraft.LENGTH * 0.5
	var bow: float = -stern
	for side in [-1.0, 1.0]:
		var at := Vector2(side * EXHAUST_X, stern - EXHAUST_FROM_STERN)
		var stack: AABB = _stand(tool, parts, at, EXHAUST, WHITE, panels, fittings)
		# THE SOOT CAP over each exhaust, and NOT over the masthead: at 2.4 m it stood 24.9 m up, half a metre higher than
		# the mast, which is the one thing on this ship whose height is measured (tests/merchant_models.gd, 2026-09-17).
		Plating.box(tool, Vector3(at.x, stack.end.y + 0.7, at.y), Vector3(1.1, 1.4, 1.1), SOOT)
		var raft := Vector2(side * (FerryDraft.BEAM * 0.5 - 2.0), bow + RAFTS_FROM_BOW)
		var cradle: AABB = _stand(tool, parts, raft, Vector3(RAFT.x, 0.5, RAFT.z), GREY, panels, fittings)
		Plating.box(tool, Vector3(raft.x, cradle.end.y + RAFT.y * 0.5, raft.y), Vector3(RAFT.x, RAFT.y, RAFT.z), ORANGE)
	# THE MAST on the wheelhouse roof, with a radar scanner turning on it and a masthead light above.
	var bridge: Dictionary = Superstructure.part_of(parts, "bridge")
	if bridge.is_empty():
		return
	var room: Rect2 = Wheelhouse.outline_rect(bridge["outline"])
	var foot: float = float(bridge["top"])
	var mast := AABB(Vector3(room.get_center().x - MAST_HALF, foot, room.get_center().y - MAST_HALF),
		Vector3(MAST_HALF * 2.0, FerryDraft.MASTHEAD - foot, MAST_HALF * 2.0))
	Plating.box(tool, mast.get_center(), mast.size, GREY)
	panels.append(mast)
	fittings.append(mast)
	Plating.box(tool, Vector3(room.get_center().x, foot + 1.6, room.get_center().y - 0.6), Vector3(3.2, 0.25, 0.5), GREY)


## A BOX STOOD ON THE SHIP at a plan point, drawn, and handed back as a panel and a fitting.
static func _stand(tool: SurfaceTool, parts: Array, at: Vector2, size: Vector3, tint: Color, panels: Array[AABB],
		fittings: Array[AABB]) -> AABB:
	var top: float = Superstructure.top_under(parts, at)
	var box := AABB(Vector3(at.x - size.x * 0.5, 0.0 if is_inf(top) else top, at.y - size.z * 0.5), size)
	Plating.box(tool, box.get_center(), box.size, tint)
	panels.append(box)
	fittings.append(box)
	return box
