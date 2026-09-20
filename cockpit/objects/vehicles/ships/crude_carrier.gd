@tool
extends RefCounted
class_name CrudeCarrier
## A VERY LARGE CRUDE CARRIER, NEAR: a black hull full to the deck, a green cargo deck with its pipe run and catwalk, the
## manifold and hose cranes amidships, and the white house aft with bridge wings out to the ship's side -- one
## vertex-coloured mesh on the shape's parts.
##
## THE PARTS ARE THE AUTHORITY (`CrudeCarrierDraft` until the kind is C++): length, beam, keel, decks, the house, the
## wheelhouse, the funnel and the mast are theirs, and this adds what nothing collides with. A size here that is in no part
## says where it came from; the references are in `craft/crude_carrier/sources.md` (P1 to P5, the US Navy's photographs
## of the Sirius Star).
##
## NOT `Superstructure.build_into`, which paints every island haze grey and every deck non-skid: a warship's. The hull is
## `HullLoft` with a merchant ship's paint and a VLCC's lines -- a block coefficient near 0.8, so the sections stay full to
## the bilge and only the ends come in -- and the house is built here in its own white.
##
## THE SHIP TYPE AND NOT THE SHIP. No funnel mark, no name, no operator's colours: a black hull, a red bottom, a green deck
## and a white house are what most tankers wear.

const HULL := Color(0.11, 0.12, 0.14)
const RED := Color(0.42, 0.13, 0.11)
const DECK := Color(0.27, 0.40, 0.30)
const PIPE := Color(0.19, 0.31, 0.22)
const WHITE := Color(0.86, 0.86, 0.83)
const GLASS := Color(0.10, 0.12, 0.15)
const STEEL := Color(0.34, 0.36, 0.38)
const FUNNEL := Color(0.30, 0.32, 0.35)
const SOOT := Color(0.06, 0.06, 0.07)
const YELLOW := Color(0.85, 0.70, 0.15)
const ORANGE := Color(0.95, 0.48, 0.10)
## THE SILHOUETTE'S PAINT, per part role, for `ShipHull.far_mesh`: the black hull, the green deck, the white house, and the
## wheelhouse a shade darker so its band reads as windows past `ShipHull.NEAR_TO`.
const FAR: Dictionary = {
	"hull": HULL,
	"deck": DECK,
	"island": WHITE,
	"bridge": Color(0.55, 0.56, 0.56),
}

## THE HULL'S SECTIONS, top down under the deck plate: `[share, width, stem_in, stern_in]`, the share being how far down to
## the keel the row is (0 the waterline, -1 the keel) and the ends in metres, taken in only at the ship's own bow and stern.
## A VLCC's block coefficient is about 0.8, so the side is vertical to three quarters of the draught, the bilge turns in the
## last 6.5 m and the bottom is flat at 0.88 of the beam; the stem comes in 9 m by the keel over the bulb, and the counter
## 32 m, where the rudder hangs (P3, P5; ESTIMATE).
##
## AS SHARES AND NOT AS HEIGHTS. Typed as metres, the keel row said -22.5 whatever the shape's keel was: a draught changed
## in the table moved the part and left the drawn hull where it was, and the mutant that changed it was caught only by the
## depth check (tests/merchant_models.gd, 2026-09-17).
const ROWS: Array = [
	[0.0, 1.00, 0.5, 2.0],
	[-0.356, 1.00, 1.5, 9.0],
	[-0.711, 1.00, 3.5, 19.0],
	[-0.911, 0.97, 6.0, 27.0],
	[-1.0, 0.88, 9.0, 32.0],
]
## HOW MANY STATIONS EACH HULL LENGTH IS LOFTED ON, and how far apart the rails' posts stand. THE LOW-POLY LOOK IS
## DELIBERATE (the user, 2026-09-17: "a somewhat lower poly look ... not too many very round edges ... a better old school
## feel"), and the E-2D's airframe is the reference: 8 rows by 20 sides. Six stations to a length puts a knuckle every 4 m
## through the entry and every 33 m along the parallel body, and the four lengths meet at hard chines. DO NOT SUBDIVIDE
## THIS: the sizes are measured and the facets are the style.
const STATIONS_PER_LENGTH: int = 6
const POST_SPACING: float = 6.0
## THE HOUSE'S DECK HEIGHT, a tier's window band apart: 0.44 freeboards on P2, at 8.5 m a freeboard (sources.md).
const DECK_HEIGHT: float = 3.7
## THE BULB forward of the stem under the water, THE RUDDER and THE PROPELLER under the counter: the hull's own, not
## fittings standing on a top, so they are not reported. ESTIMATES, and AS SHARES OF THE DRAUGHT, so that a keel moved in
## the shape table takes them with it: a 7 m bulb whose middle is four fifths of the way down, a rudder 12 m in chord
## hanging from a fifth of the draught to nine tenths of it, and a single screw 10 m across at two thirds.
const BULB_HALF: float = 3.5
const BULB_LONG: float = 12.0
const BULB_DEEP: Vector2 = Vector2(-0.80, -0.40)
const RUDDER_Z: Vector2 = Vector2(148.0, 160.0)
const RUDDER_DEEP: Vector2 = Vector2(-0.89, -0.27)
const PROPELLER_Z: float = 145.0
const PROPELLER_DEEP: float = -0.64
const PROPELLER_RADIUS: float = 5.0

## THE CARGO DECK'S GEAR, on the deck and reported as fittings. The pipe run and the catwalk along the centreline from the
## forecastle to the house (P4), the manifold athwartships amidships with a hose crane each side of it (P1, P4), and a
## foremast (P4). Places along the ship are ESTIMATES, the manifold's at mid-length being the assumption P1's measurement of
## the house rests on -- but for the foremast, which P4 shows at the stem head, 2 to 4 m aft of the stem. First drawn 14 m
## aft of it, it stood on the centreline between the wheelhouse and the bow, and hid the stem from both seats
## (tests/merchant_models.gd, 2026-09-17).
const RUN_FROM: float = -150.0
const RUN_TO: float = 85.0
const CATWALK_HIGH: float = 2.5
const MANIFOLD_Z: float = 0.0
const MANIFOLD_HALF: float = 24.0
const CRANES: Array[Vector2] = [Vector2(-18.0, 8.0), Vector2(18.0, 8.0)]
const CRANE_HIGH: float = 8.0
const FOREMAST := Vector2(0.0, -163.0)
const FOREMAST_HIGH: float = 12.0
## MOORING WINCHES, two forward and two aft (P2, P3, P5).
const WINCHES: Array[Vector2] = [Vector2(-9.0, -140.0), Vector2(9.0, -140.0), Vector2(-12.0, 138.0),
	Vector2(12.0, 138.0)]
const WINCH := Vector3(3.0, 2.0, 4.5)
## TWO HELICOPTER WINCHING CIRCLES, painted either side of the pipe run forward of the manifold (P4): paint, not a fitting.
const WINCHING: Array[Vector2] = [Vector2(-17.0, -60.0), Vector2(17.0, -60.0)]
const WINCHING_RADIUS: float = 10.0
## THE FREE-FALL LIFEBOAT on its ramp over the stern, on the centreline (P5), launched at 35 degrees.
const LIFEBOAT_Z: float = 157.0
const LIFEBOAT := Vector3(3.0, 3.0, 9.0)
## DRAUGHT MARKS amidships on both sides: a tick every metre up the flat of the side to the deck.
const MARK_WIDE: float = 1.2
const MARK_HIGH: float = 0.15


## THE NEAR MODEL: `{"mesh", "panels", "fittings"}`, as every ship's own builder hands back. `helm` is the catalogue's.
static func build(geometry: Dictionary, _helm: String = "glazed") -> Dictionary:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: Array = geometry.get("parts", []) as Array
	var panels: Array[AABB] = []
	var fittings: Array[AABB] = []
	var bow: float = INF
	var stern: float = -INF
	for part in parts:
		if String(part["part"]) == "hull":
			var ends: Rect2 = Wheelhouse.outline_rect(part["outline"])
			bow = minf(bow, ends.position.y)
			stern = maxf(stern, ends.end.y)
	for part in parts:
		var outline: PackedVector2Array = part["outline"]
		var bottom: float = float(part["bottom"])
		var top: float = float(part["top"])
		var r: Rect2 = Wheelhouse.outline_rect(outline)
		match String(part["part"]):
			"hull":
				HullLoft.build(tool, outline, rows_for(top, bottom, is_equal_approx(r.position.y, bow),
					is_equal_approx(r.end.y, stern)), 0.0, [HULL, RED, RED], STATIONS_PER_LENGTH)
			"deck":
				_deck(tool, parts, outline, bottom, top, r)
			"island":
				Plating.prism(tool, outline, bottom, top, WHITE, false)
				panels.append(AABB(Vector3(r.position.x, bottom, r.position.y), Vector3(r.size.x, top - bottom, r.size.y)))
			"bridge":
				panels.append_array(Wheelhouse.build(tool, part, ["fore", "port", "starboard"], WHITE, STEEL))
	_the_house(tool, parts)
	_under_the_water(tool, CrudeCarrierDraft.DRAUGHT - float(geometry.get("waterline", 0.0)))
	_cargo_deck(tool, parts, panels, fittings)
	_marks(tool, geometry)
	return {"mesh": Plating.weld(tool), "panels": panels, "fittings": fittings}


## THE ROWS OF ONE HULL LENGTH IN METRES, its top first: the deck plate's underside, then `ROWS` against this length's own
## keel, with the ends taken in only where this length is the ship's bow or stern.
static func rows_for(top: float, bottom: float, fines_at_bow: bool, fines_at_stern: bool) -> Array:
	var out: Array = [[top, 1.0, 0.0, 0.0]]
	for row in ROWS:
		out.append([-float(row[0]) * bottom, float(row[1]), float(row[2]) if fines_at_bow else 0.0,
			float(row[3]) if fines_at_stern else 0.0])
	return out


## A DECK: its plate painted green on top, the sheer strake in the hull's black down its sides, and a rail along every edge
## that is the ship's side -- not the edges where one length meets the next at the same height.
static func _deck(tool: SurfaceTool, parts: Array, outline: PackedVector2Array, bottom: float, top: float,
		r: Rect2) -> void:
	Plating.paint(tool, outline, top, DECK)
	var ring: PackedVector2Array = Plating.upward(outline)
	tool.set_color(HULL)
	for i in range(ring.size()):
		Plating.wall(tool, ring[i], ring[(i + 1) % ring.size()], bottom, top)
	for i in range(ring.size()):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % ring.size()]
		# AN ATHWARTSHIPS EDGE WHERE ANOTHER DECK GOES ON at this height or higher is a joint and has no rail: the cargo deck's
		# lengths meet at one, and the deck round the house meets the step up to the cargo deck at another. The cargo deck's
		# own aft edge, the top of that step, keeps its rail.
		if is_equal_approx(a.y, b.y) and _goes_on(parts, a.y, top, r):
			continue
		var inward: Vector2 = (r.get_center() - (a + b) * 0.5).normalized() * 0.15
		Plating.bar(tool, a + inward, b + inward, 0.06, top + 0.94, top + 1.0, WHITE)
		var length: float = a.distance_to(b)
		var posts: int = maxi(int(length / POST_SPACING), 1)
		for k in range(posts + 1):
			var at: Vector2 = a.lerp(b, float(k) / float(posts)) + inward
			Plating.box(tool, Vector3(at.x, top + 0.47, at.y), Vector3(0.05, 0.94, 0.05), WHITE)


## THE HOUSE'S DETAIL on the parts `geometry` gives it: a band of windows on every tier's four faces, the wing girder's
## braces and posts, the wings' rails, the funnel's black top and exhausts, and the mast's radar yard.
static func _the_house(tool: SurfaceTool, parts: Array) -> void:
	var deck: float = CrudeCarrierDraft.DEPTH - CrudeCarrierDraft.DRAUGHT
	for part in parts:
		if String(part["part"]) != "island":
			continue
		var r: Rect2 = Wheelhouse.outline_rect(part["outline"])
		var bottom: float = float(part["bottom"])
		var top: float = float(part["top"])
		# A TIER is an island at least 10 m across; the girder is 3 m deep and the funnel and mast are narrower.
		if r.size.x >= 10.0 and top - bottom > 4.0:
			var levels: int = maxi(roundi((top - bottom) / DECK_HEIGHT), 1)
			for level in range(levels):
				var floor_at: float = bottom + (top - bottom) * float(level) / float(levels)
				Plating.band(tool, r, floor_at + 1.1, floor_at + 2.1, GLASS)
		elif r.size.x >= CrudeCarrierDraft.BEAM - 0.1:
			# THE WINGS: a rail along the front and back of the walkway on the girder's top, and the braces under it --
			# a post at 16.8 m either side and a diagonal from 25 m out down to the lower tiers' roof edge (P4).
			var z: float = r.get_center().y
			for edge in [r.position.y + 0.1, r.end.y - 0.1]:
				Plating.bar(tool, Vector2(r.position.x, edge), Vector2(r.end.x, edge), 0.06, top + 0.94, top + 1.0, WHITE)
			var roof: float = deck + CrudeCarrierDraft.LOWER_ROOF
			for side in [-1.0, 1.0]:
				Plating.box(tool, Vector3(side * 16.8, (roof + bottom) * 0.5, z), Vector3(0.9, bottom - roof, 1.2), WHITE)
				var from := Vector2(side * 25.0, bottom)
				var to := Vector2(side * 18.2, roof)
				var run: Vector2 = to - from
				Plating.box(tool, Vector3((from.x + to.x) * 0.5, (from.y + to.y) * 0.5, z),
					Vector3(0.9, run.length(), 1.0), WHITE, Basis(Vector3.BACK, atan2(-run.x, run.y)))
		elif r.size.x >= 4.0:
			# THE FUNNEL: two metres of soot at the top and three exhausts standing out of it (P2, P3).
			Plating.prism(tool, _grown(part["outline"], 0.05), top - 2.0, top, SOOT, false)
			for dx in [-1.6, 0.0, 1.6]:
				Plating.box(tool, Vector3(dx, top + 1.2, r.get_center().y + 1.0), Vector3(0.9, 2.4, 0.9), SOOT)
		else:
			# THE MAST: a radar yard across it three metres under its top, and a scanner on the yard.
			var y: float = top - 3.0
			Plating.box(tool, Vector3(0.0, y, r.get_center().y), Vector3(5.0, 0.3, 0.6), WHITE)
			Plating.box(tool, Vector3(0.0, y + 0.5, r.get_center().y - 1.0), Vector3(4.2, 0.35, 0.35), STEEL)


## WHETHER A DECK OTHER THAN THE ONE IN `r` STARTS OR ENDS AT `z`, at `top` or higher.
static func _goes_on(parts: Array, z: float, top: float, r: Rect2) -> bool:
	for part in parts:
		if String(part["part"]) != "deck":
			continue
		var other: Rect2 = Wheelhouse.outline_rect(part["outline"])
		if other == r:
			continue
		if (is_equal_approx(other.position.y, z) or is_equal_approx(other.end.y, z)) and float(part["top"]) >= top - 0.01:
			return true
	return false


## An outline grown by `by` either way in plan, for a band painted over a prism's walls.
static func _grown(outline: PackedVector2Array, by: float) -> PackedVector2Array:
	var r: Rect2 = Wheelhouse.outline_rect(outline).grow(by)
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## THE BULB, THE RUDDER AND THE SCREW, in the red of the bottom.
static func _under_the_water(tool: SurfaceTool, draught: float) -> void:
	var bow: float = -CrudeCarrierDraft.LENGTH * 0.5
	Plating.box(tool, Vector3(0.0, draught * (BULB_DEEP.x + BULB_DEEP.y) * 0.5, bow + BULB_LONG * 0.5),
		Vector3(BULB_HALF * 2.0, draught * (BULB_DEEP.y - BULB_DEEP.x), BULB_LONG), RED)
	Plating.box(tool, Vector3(0.0, draught * (RUDDER_DEEP.x + RUDDER_DEEP.y) * 0.5, (RUDDER_Z.x + RUDDER_Z.y) * 0.5),
		Vector3(1.5, draught * (RUDDER_DEEP.y - RUDDER_DEEP.x), RUDDER_Z.y - RUDDER_Z.x), RED)
	for turn in [0.0, PI / 3.0, PI * 2.0 / 3.0]:
		Plating.box(tool, Vector3(0.0, draught * PROPELLER_DEEP, PROPELLER_Z), Vector3(PROPELLER_RADIUS * 2.0, 1.4, 0.5),
			STEEL, Basis(Vector3.BACK, turn))


## THE CARGO DECK'S GEAR: each piece stood on the deck under it, drawn, and reported as a fitting; the solid ones are panels.
static func _cargo_deck(tool: SurfaceTool, parts: Array, panels: Array[AABB], fittings: Array[AABB]) -> void:
	var deck: float = _foot(parts, Vector2(0.0, 0.0))
	# THE PIPE RUN: four pipes either side of the centreline, on stools.
	var run := AABB(Vector3(-3.5, deck, RUN_FROM), Vector3(7.0, 1.2, RUN_TO - RUN_FROM))
	fittings.append(run)
	for x in [-3.0, -1.8, 1.8, 3.0]:
		Plating.bar(tool, Vector2(x, RUN_FROM), Vector2(x, RUN_TO), 0.6, deck + 0.5, deck + 1.1, PIPE)
	for z in range(int(RUN_FROM), int(RUN_TO), 12):
		Plating.box(tool, Vector3(0.0, deck + 0.25, float(z)), Vector3(7.0, 0.5, 0.4), PIPE)
	# THE CATWALK over it on posts, a metre wide.
	var catwalk := AABB(Vector3(-0.6, deck, RUN_FROM), Vector3(1.2, CATWALK_HIGH, RUN_TO - RUN_FROM))
	fittings.append(catwalk)
	Plating.bar(tool, Vector2(0.0, RUN_FROM), Vector2(0.0, RUN_TO), 1.2, deck + CATWALK_HIGH - 0.1, deck + CATWALK_HIGH,
		STEEL)
	for z in range(int(RUN_FROM), int(RUN_TO), 12):
		Plating.box(tool, Vector3(0.0, deck + (CATWALK_HIGH - 0.1) * 0.5, float(z) + 6.0),
			Vector3(0.25, CATWALK_HIGH - 0.1, 0.25), STEEL)
	# THE MANIFOLD: four pipes athwartships to a valve block at each side.
	var manifold := AABB(Vector3(-MANIFOLD_HALF, deck, MANIFOLD_Z - 4.0), Vector3(MANIFOLD_HALF * 2.0, 1.6, 8.0))
	fittings.append(manifold)
	for dz in [-3.0, -1.0, 1.0, 3.0]:
		Plating.bar(tool, Vector2(-MANIFOLD_HALF, MANIFOLD_Z + dz), Vector2(MANIFOLD_HALF, MANIFOLD_Z + dz), 0.7,
			deck + 0.6, deck + 1.3, PIPE)
	for side in [-1.0, 1.0]:
		var valves := AABB(Vector3(side * MANIFOLD_HALF - 1.5, deck, MANIFOLD_Z - 4.0), Vector3(3.0, 1.6, 8.0))
		Plating.box(tool, valves.get_center(), valves.size, PIPE)
		panels.append(valves)
	# THE HOSE CRANES: a white post and a jib reaching inboard.
	for at in CRANES:
		var post := AABB(Vector3(at.x - 0.6, _foot(parts, at), at.y - 0.6), Vector3(1.2, CRANE_HIGH, 1.2))
		Plating.box(tool, post.get_center(), post.size, WHITE)
		# THE JIB, up and inboard from the head of the post, not a bar straight across it: drawn level it read as a goalpost
		# over the deck from the wheelhouse (screenshots/2026-09-17/cockpit-fleet3-01-crude-carrier-helm.png).
		var reach := Vector2(at.x * 0.55 - at.x, 3.4)
		Plating.box(tool, Vector3(at.x + reach.x * 0.5, post.end.y - 0.4 + reach.y * 0.5, at.y),
			Vector3(0.5, reach.length(), 0.5), WHITE, Basis(Vector3.BACK, atan2(-reach.x, reach.y)))
		panels.append(post)
		fittings.append(post)
	# THE FOREMAST.
	var foremast := AABB(Vector3(FOREMAST.x - 0.35, _foot(parts, FOREMAST), FOREMAST.y - 0.35),
		Vector3(0.7, FOREMAST_HIGH, 0.7))
	Plating.box(tool, foremast.get_center(), foremast.size, WHITE)
	Plating.box(tool, Vector3(FOREMAST.x, foremast.end.y - 1.5, FOREMAST.y), Vector3(2.4, 0.2, 0.3), WHITE)
	panels.append(foremast)
	fittings.append(foremast)
	# THE MOORING WINCHES.
	for at in WINCHES:
		var winch := AABB(Vector3(at.x - WINCH.x * 0.5, _foot(parts, at), at.y - WINCH.z * 0.5), WINCH)
		Plating.box(tool, winch.get_center(), winch.size, PIPE)
		panels.append(winch)
		fittings.append(winch)
	# THE WINCHING CIRCLES: a yellow ring of dashes and a white spot in the middle.
	for at in WINCHING:
		var y: float = _foot(parts, at) + 0.03
		# TWELVE DASHES AND AN EIGHT-SIDED SPOT: a circle on a deck is a ring of plate, not a curve.
		for i in range(12):
			var a0: float = TAU * float(i) / 12.0
			var a1: float = a0 + TAU / 24.0
			Plating.line(tool, at + Vector2(cos(a0), sin(a0)) * WINCHING_RADIUS,
				at + Vector2(cos(a1), sin(a1)) * WINCHING_RADIUS, 0.5, y, YELLOW)
		for i in range(8):
			var a0: float = TAU * float(i) / 8.0
			var a1: float = TAU * float(i + 1) / 8.0
			Plating.paint(tool, PackedVector2Array([at, at + Vector2(cos(a1), sin(a1)) * 2.5,
				at + Vector2(cos(a0), sin(a0)) * 2.5]), y + 0.01, WHITE)
	# THE FREE-FALL LIFEBOAT: a frame on the stern and the boat on it, nose down over the transom.
	var stand := Vector2(0.0, LIFEBOAT_Z)
	var frame := AABB(Vector3(-2.0, _foot(parts, stand), LIFEBOAT_Z - 5.0), Vector3(4.0, 4.5, 8.0))
	fittings.append(frame)
	panels.append(frame)
	for x in [-1.8, 1.8]:
		Plating.box(tool, Vector3(x, frame.position.y + 2.25, LIFEBOAT_Z - 4.5), Vector3(0.3, 4.5, 0.3), WHITE)
		Plating.box(tool, Vector3(x, frame.position.y + 2.6, LIFEBOAT_Z), Vector3(0.3, 0.3, 10.0), WHITE,
			Basis(Vector3.RIGHT, deg_to_rad(-35.0)))
	Plating.box(tool, Vector3(0.0, frame.position.y + 3.9, LIFEBOAT_Z), LIFEBOAT, ORANGE,
		Basis(Vector3.RIGHT, deg_to_rad(-35.0)))


## DRAUGHT MARKS: a white tick every metre on both sides amidships, just proud of the plating.
static func _marks(tool: SurfaceTool, geometry: Dictionary) -> void:
	var half: float = (geometry.get("extents", Vector3.ZERO) as Vector3).x
	var top: float = CrudeCarrierDraft.DEPTH - CrudeCarrierDraft.DRAUGHT - CrudeCarrierDraft.PLATE
	# ON THE FLAT OF THE SIDE ONLY: under 16 m the bilge has turned in and a mark would stand off the plating.
	var y: float = -16.0
	while y < top:
		for side in [-1.0, 1.0]:
			var x: float = side * (half + 0.02)
			Plating.facing(tool, [Vector3(x, y + MARK_HIGH, -MARK_WIDE), Vector3(x, y + MARK_HIGH, 0.0),
				Vector3(x, y, 0.0), Vector3(x, y, -MARK_WIDE)], Vector3(side, 0.0, 0.0), WHITE)
		y += 1.0


## The deck under a plan point, or the waterline over the sea, where a suite finds a fitting standing on nothing.
static func _foot(parts: Array, at: Vector2) -> float:
	var top: float = Superstructure.top_under(parts, at)
	return 0.0 if is_inf(top) else top
