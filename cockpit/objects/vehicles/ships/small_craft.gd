@tool
extends RefCounted
class_name SmallCraft
## FOUR SMALL BOATS, NEAR: a modern cruising sloop, a classic long-keel cutter, a stern trawler and a fifty-foot flybridge
## motor yacht -- one vertex-coloured mesh each, on the shape's parts.
##
## THE PARTS ARE THE AUTHORITY (`SmallCraftDraft` until the kinds are C++): length, beam, keel, deck, the coachroof, the
## wheelhouse and the flybridge are theirs, and this adds what nothing collides with -- rigs, sails, rails, windows,
## rudders and gear. `craft/small_craft/sources.md` says where every figure came from and, for these four, how much of it
## is estimated.
##
## THE TWO SAILING BOATS MUST NOT READ ALIKE, and most of the work here is spent on that. The sloop is a modern production
## cruiser: plumb stem, fin keel, spade rudder, a wheel, and a transom nearly her full beam. The cutter is a 1979 Chuck
## Paine boat: raked stem, long keel with a cutaway forefoot, rudder hung on the keel, a tiller, bulwarks, and a canoe
## transom that comes to 0.36 m across. They are opposite shapes above and below the water, and drawing them as one boat
## at two sizes would waste one of them.
##
## SAILS ARE QUADRILATERALS AND NOT TRIANGLES, deliberately. A Bermuda mainsail has a headboard and a real sail is a quad;
## drawn as a triangle it wants two coincident corners at the head, which is a degenerate face that `_wound_outwards`
## cannot judge and that the welder may drop. Each sail is two `Plating.facing` quads back to back with explicit outward
## normals, so both sides are drawn and both are wound outwards.
##
## THE BOAT TYPE AND NOT THE BOAT. No builder's name, sail number, hull graphic or house style. The liveries are invented.

const BOOT := Color(0.10, 0.11, 0.13)
const ANTIFOUL := Color(0.38, 0.14, 0.13)
const TEAK := Color(0.52, 0.38, 0.22)
const SAIL := Color(0.90, 0.89, 0.85)
const SAIL_SHADE := Color(0.80, 0.79, 0.76)
const SPAR := Color(0.72, 0.73, 0.74)
const GLASS := Color(0.12, 0.16, 0.20)
const STEEL := Color(0.40, 0.42, 0.44)
const RAIL := Color(0.82, 0.82, 0.80)
const RUST := Color(0.44, 0.24, 0.14)

## SIX LIVERIES A BOAT, so a marina holds a fleet and not a photocopy -- the user's ask, 2026-09-19. KEYED BY BOAT,
## because what looks right on a working trawler does not look right on a motor yacht: a yacht's hull is white or a dark
## blue and a trawler's is whatever the yard had, so the four palettes are different palettes rather than one applied
## four times.
##
## ONE DICTIONARY OF NAMED ROLES per scheme, chosen by index. The drawing code indexes `paint["hull"]` and holds no
## colour of its own, so a livery is DATA a caller chooses and never a second copy of the model.
##
## INVENTED NAMES AND INVENTED COLOURS, named after what they look like. No builder's house style, no sail number, no
## hull graphic. `cove` is the stripe along the sheer; `canvas` is sail covers, sprayhoods and awnings.
const LIVERIES: Dictionary = {
	"cruising_sloop": [
		{"name": "white", "hull": Color(0.88, 0.88, 0.86), "house": Color(0.86, 0.86, 0.84),
			"cove": Color(0.20, 0.32, 0.48), "canvas": Color(0.20, 0.28, 0.38)},
		{"name": "navy", "hull": Color(0.12, 0.18, 0.32), "house": Color(0.88, 0.88, 0.86),
			"cove": Color(0.80, 0.78, 0.72), "canvas": Color(0.16, 0.20, 0.30)},
		{"name": "flint", "hull": Color(0.42, 0.45, 0.48), "house": Color(0.88, 0.88, 0.86),
			"cove": Color(0.24, 0.26, 0.28), "canvas": Color(0.26, 0.28, 0.30)},
		{"name": "cream", "hull": Color(0.86, 0.82, 0.70), "house": Color(0.90, 0.89, 0.86),
			"cove": Color(0.36, 0.30, 0.20), "canvas": Color(0.40, 0.34, 0.24)},
		{"name": "oxblood", "hull": Color(0.34, 0.12, 0.14), "house": Color(0.89, 0.88, 0.85),
			"cove": Color(0.82, 0.78, 0.70), "canvas": Color(0.28, 0.14, 0.16)},
		{"name": "seafoam", "hull": Color(0.62, 0.74, 0.72), "house": Color(0.90, 0.90, 0.88),
			"cove": Color(0.18, 0.34, 0.34), "canvas": Color(0.22, 0.36, 0.36)},
	],
	"classic_cutter": [
		{"name": "bottle", "hull": Color(0.10, 0.24, 0.20), "house": Color(0.88, 0.87, 0.83),
			"cove": Color(0.78, 0.66, 0.30), "canvas": Color(0.30, 0.26, 0.20)},
		{"name": "gaff blue", "hull": Color(0.13, 0.22, 0.38), "house": Color(0.88, 0.87, 0.83),
			"cove": Color(0.80, 0.70, 0.34), "canvas": Color(0.24, 0.24, 0.24)},
		{"name": "pilot black", "hull": Color(0.08, 0.09, 0.10), "house": Color(0.86, 0.85, 0.80),
			"cove": Color(0.74, 0.64, 0.28), "canvas": Color(0.26, 0.24, 0.20)},
		{"name": "buff", "hull": Color(0.78, 0.70, 0.52), "house": Color(0.88, 0.87, 0.82),
			"cove": Color(0.32, 0.26, 0.16), "canvas": Color(0.34, 0.30, 0.22)},
		{"name": "claret", "hull": Color(0.36, 0.13, 0.17), "house": Color(0.87, 0.86, 0.81),
			"cove": Color(0.76, 0.68, 0.34), "canvas": Color(0.28, 0.20, 0.20)},
		{"name": "oyster", "hull": Color(0.84, 0.83, 0.78), "house": Color(0.90, 0.89, 0.85),
			"cove": Color(0.24, 0.32, 0.30), "canvas": Color(0.30, 0.32, 0.30)},
	],
	"stern_trawler": [
		{"name": "harbour", "hull": Color(0.16, 0.28, 0.40), "house": Color(0.86, 0.86, 0.83),
			"cove": Color(0.84, 0.62, 0.16), "canvas": Color(0.30, 0.34, 0.36)},
		{"name": "kelp", "hull": Color(0.14, 0.26, 0.19), "house": Color(0.86, 0.86, 0.82),
			"cove": Color(0.84, 0.66, 0.18), "canvas": Color(0.28, 0.32, 0.28)},
		{"name": "vermilion", "hull": Color(0.50, 0.17, 0.12), "house": Color(0.88, 0.87, 0.83),
			"cove": Color(0.90, 0.86, 0.78), "canvas": Color(0.32, 0.26, 0.24)},
		{"name": "tar", "hull": Color(0.10, 0.11, 0.13), "house": Color(0.85, 0.85, 0.82),
			"cove": Color(0.86, 0.60, 0.14), "canvas": Color(0.28, 0.28, 0.28)},
		{"name": "ochre", "hull": Color(0.56, 0.42, 0.14), "house": Color(0.87, 0.86, 0.82),
			"cove": Color(0.18, 0.28, 0.36), "canvas": Color(0.32, 0.30, 0.22)},
		{"name": "slate grey", "hull": Color(0.36, 0.40, 0.43), "house": Color(0.86, 0.86, 0.83),
			"cove": Color(0.82, 0.60, 0.16), "canvas": Color(0.30, 0.32, 0.34)},
	],
	"motor_yacht": [
		{"name": "pearl", "hull": Color(0.90, 0.90, 0.89), "house": Color(0.88, 0.88, 0.87),
			"cove": Color(0.24, 0.30, 0.36), "canvas": Color(0.22, 0.24, 0.28)},
		{"name": "graphite", "hull": Color(0.26, 0.28, 0.31), "house": Color(0.88, 0.88, 0.87),
			"cove": Color(0.72, 0.72, 0.74), "canvas": Color(0.20, 0.22, 0.24)},
		{"name": "midnight", "hull": Color(0.10, 0.14, 0.26), "house": Color(0.89, 0.89, 0.88),
			"cove": Color(0.76, 0.74, 0.68), "canvas": Color(0.16, 0.20, 0.28)},
		{"name": "champagne", "hull": Color(0.82, 0.78, 0.68), "house": Color(0.90, 0.90, 0.88),
			"cove": Color(0.38, 0.34, 0.26), "canvas": Color(0.34, 0.32, 0.26)},
		{"name": "silver", "hull": Color(0.70, 0.72, 0.74), "house": Color(0.90, 0.90, 0.89),
			"cove": Color(0.22, 0.26, 0.30), "canvas": Color(0.26, 0.28, 0.30)},
		{"name": "ice blue", "hull": Color(0.66, 0.76, 0.82), "house": Color(0.91, 0.91, 0.90),
			"cove": Color(0.16, 0.26, 0.34), "canvas": Color(0.20, 0.28, 0.34)},
	],
}

## THE SILHOUETTE'S PAINT, per part role. At these sizes a boat is past `ShipHull.NEAR_TO` almost at once and is a few
## prisms; what has to survive is the hull's colour and something pale on top.
const FAR: Dictionary = {
	"hull": Color(0.60, 0.61, 0.60),
	"deck": Color(0.72, 0.72, 0.70),
	"island": Color(0.85, 0.85, 0.83),
	"bridge": Color(0.55, 0.58, 0.60),
}

## THE HULL'S SECTIONS, top down under the deck: `[share, width, stem_in, stern_in]`, the ends as fractions of length.
## A DISPLACEMENT SAILING HULL is slack-bilged and narrow on the bottom -- 0.36 of the beam at the canoe body's lowest
## point -- where A PLANING MOTOR HULL is hard-chined and stays wide to the keel, 0.80, because flat after sections are
## what lift it. The trawler sits between them and full, as a working boat does.
## FULLER THAN THEY WERE, because the first set left a hole. At a keel row 0.36 of the beam with the stem tucked 0.08 of
## the length aft, the sloop had no skin at all 0.60 m under the water 2.4 m abaft her stem -- `_the_side_is_whole`
## found it at one station of five. A cruising yacht's forefoot is not that fine.
const ROWS_SAIL: Array = [
	[0.0, 1.00, 0.006, 0.012],
	[-0.45, 0.96, 0.018, 0.045],
	[-0.78, 0.82, 0.034, 0.085],
	[-1.0, 0.52, 0.050, 0.120],
]
const ROWS_PLANING: Array = [
	[0.0, 1.00, 0.006, 0.004],
	[-0.50, 0.98, 0.020, 0.010],
	[-0.85, 0.92, 0.038, 0.018],
	[-1.0, 0.80, 0.052, 0.026],
]
## A ROW MAY NOT BE TUCKED IN FURTHER THAN ITS OWN HULL LENGTH IS LONG, and that is the rule this table broke. At a
## stern tuck of 0.150 of the length the trawler's keel row came 3.375 m forward of her transom -- into a hull part only
## 3.0 m long -- so the after rows folded back through the part's forward face and eight faces came out wound against
## their own normals, all of them between the -0.80 row and the keel at exactly the part's boundary. The tuck is 0.105
## now, which is 2.36 m of a 3.0 m run. The same sum holds on the other three tables and none of them was close.
const ROWS_WORK: Array = [
	[0.0, 1.00, 0.012, 0.016],
	[-0.45, 0.99, 0.034, 0.055],
	[-0.80, 0.88, 0.062, 0.085],
	[-1.0, 0.62, 0.090, 0.105],
]
## Stations to a hull length, and the facets on a spar. THE LOW-POLY LOOK IS DELIBERATE (the user, 2026-09-17), and the
## E-2D's airframe is the reference. DO NOT SUBDIVIDE: the sizes are published and the facets are the style.
const STATIONS_PER_LENGTH: int = 6
const SPAR_SIDES: int = 8


## THE NEAR MODEL: `{"mesh", "panels", "fittings"}`. `livery` indexes this boat's own `LIVERIES` row and defaults to the
## first, so a caller that knows nothing about liveries gets a boat.
static func build(geometry: Dictionary, _helm: String = "open", livery: int = 0) -> Dictionary:
	var which: String = String(geometry.get("name", "cruising_sloop"))
	var schemes: Array = LIVERIES.get(which, LIVERIES["cruising_sloop"]) as Array
	var paint: Dictionary = schemes[clampi(livery, 0, schemes.size() - 1)]
	var c: Dictionary = SmallCraftDraft.CLASSES[which]
	var rows: Array = ROWS_SAIL
	if which == "motor_yacht":
		rows = ROWS_PLANING
	elif which == "stern_trawler":
		rows = ROWS_WORK
	# THE OVERHANGS, DERIVED FROM TWO PUBLISHED FIGURES AND NOT DRAWN BY EYE. A classic boat floats on much less than
	# her length: the Leigh 30 is 9.14 m overall and 7.11 m on the waterline, so 2.03 m of her -- more than a fifth --
	# is raked stem forward and overhanging counter aft. Drawn without it she sat on her whole length and read as a
	# barge with a mast in it, which is exactly what the first picture showed.
	#
	# Split 44 per cent forward and 56 aft, because a counter overhangs further than a stem rakes. The modern boats
	# have no `waterline` figure and get none of this, which is right: a plumb-bowed production cruiser very nearly
	# does float on her whole length.
	var overhang := Vector2.ZERO
	if c.has("waterline"):
		var gap: float = (float(c["length"]) - float(c["waterline"])) / float(c["length"])
		overhang = Vector2(gap * 0.44, gap * 0.56)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: Array = geometry.get("parts", []) as Array
	var panels: Array[AABB] = []
	var fittings: Array[AABB] = []
	var length: float = float(c["length"])
	var bow: float = INF
	var stern: float = -INF
	var widest: float = 0.0
	for part in parts:
		if String(part["part"]) != "hull":
			continue
		var r: Rect2 = Wheelhouse.outline_rect(part["outline"])
		bow = minf(bow, r.position.y)
		stern = maxf(stern, r.end.y)
		widest = maxf(widest, r.size.x)
	for part in parts:
		var outline: PackedVector2Array = part["outline"]
		var bottom: float = float(part["bottom"])
		var top: float = float(part["top"])
		var r: Rect2 = Wheelhouse.outline_rect(outline)
		match String(part["part"]):
			"hull":
				# THE KEEL IS A HULL PART TOO, and it is not lofted: a fin or a long keel is a blade, not a set of
				# sections, and running `HullLoft` over it would round its bottom into a canoe. Told apart by being
				# narrow -- under a third of the widest hull part -- rather than by being named.
				if r.size.x < widest * 0.34:
					# ANTIFOULED, not hull-coloured: a keel lives under the water and is painted like the bottom. In
					# the sloop's white it drew as two pale blades hanging under a white boat.
					Plating.prism(tool, outline, bottom, top, ANTIFOUL, true)
				else:
					HullLoft.build(tool, outline, _rows_for(rows, top, bottom, length,
						is_equal_approx(r.position.y, bow), is_equal_approx(r.end.y, stern), overhang), 0.0,
						[paint["hull"], BOOT, ANTIFOUL], STATIONS_PER_LENGTH)
			"deck":
				_deck(tool, outline, bottom, top, r, which, paint)
			"island":
				Plating.prism(tool, outline, bottom, top, paint["house"], false)
				_house_windows(tool, r, bottom, top, which)
				panels.append(AABB(Vector3(r.position.x, bottom, r.position.y),
					Vector3(r.size.x, top - bottom, r.size.y)))
			"bridge":
				panels.append_array(_helm_station(tool, part, r, which, paint, fittings))
	match which:
		"cruising_sloop":
			_sloop_rig(tool, c, bow, stern, parts, paint, fittings)
			_underwater_blade(tool, c, stern - 1.4, 0.10, 1.1, float(c["draught"]) * 0.82, paint)
		"classic_cutter":
			_cutter_rig(tool, c, bow, stern, parts, paint, fittings)
		"stern_trawler":
			_trawler_gear(tool, c, bow, stern, parts, paint, fittings)
		"motor_yacht":
			_motor_gear(tool, c, bow, stern, parts, paint, fittings)
	return {"mesh": Plating.weld(tool), "panels": panels, "fittings": fittings}


## THE ROWS OF ONE HULL LENGTH IN METRES, its top first, with the end tuck-ins turned from fractions into metres against
## this boat's own length -- the one place that conversion happens.
static func _rows_for(rows: Array, top: float, bottom: float, length: float, fines_at_bow: bool,
		fines_at_stern: bool, overhang := Vector2.ZERO) -> Array:
	var out: Array = [[top, 1.0, 0.0, 0.0]]
	for row in rows:
		out.append([-float(row[0]) * bottom, float(row[1]),
			(float(row[2]) + overhang.x) * length if fines_at_bow else 0.0,
			(float(row[3]) + overhang.y) * length if fines_at_stern else 0.0])
	return out


## A DECK: its plate, the sheer strake, and what stands round the edge -- BULWARKS on the boats that have them and wire
## guardrails on the boats that do not. The cutter's bulwark is a published feature of the boat and the trawler's is what
## a working deck needs; the two yachts carry stanchions and two wires, which is what a yacht carries.
static func _deck(tool: SurfaceTool, outline: PackedVector2Array, bottom: float, top: float, r: Rect2, which: String,
		paint: Dictionary) -> void:
	Plating.paint(tool, outline, top, TEAK if which == "classic_cutter" else paint["house"])
	var ring: PackedVector2Array = Plating.upward(outline)
	tool.set_color(paint["hull"])
	for i in range(ring.size()):
		Plating.wall(tool, ring[i], ring[(i + 1) % ring.size()], bottom, top)
	# A COVE LINE along the sheer: the one stripe almost every boat of every kind carries, and what stops the topsides
	# reading as a slab.
	var solid: bool = which == "classic_cutter" or which == "stern_trawler"
	for i in range(ring.size()):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % ring.size()]
		if is_equal_approx(a.y, b.y) and absf(a.x - b.x) > r.size.x * 0.8:
			continue
		var inward: Vector2 = (r.get_center() - (a + b) * 0.5).normalized() * 0.05
		Plating.bar(tool, a + inward, b + inward, 0.03, top - 0.22, top - 0.16, paint["cove"])
		if solid:
			Plating.bar(tool, a + inward, b + inward, 0.06, top, top + 0.26, paint["hull"])
		else:
			_guardrail(tool, a + inward * 3.0, b + inward * 3.0, top)


## STANCHIONS AND TWO WIRES, as a yacht's side deck has: a post every 1.6 m or so, and the wires between them.
static func _guardrail(tool: SurfaceTool, a: Vector2, b: Vector2, top: float) -> void:
	Plating.bar(tool, a, b, 0.018, top + 0.60, top + 0.63, RAIL)
	Plating.bar(tool, a, b, 0.018, top + 0.30, top + 0.33, RAIL)
	var posts: int = maxi(int(a.distance_to(b) / 1.6), 1)
	for i in range(posts + 1):
		var at: Vector2 = a.lerp(b, float(i) / float(posts))
		Plating.box(tool, Vector3(at.x, top + 0.32, at.y), Vector3(0.035, 0.64, 0.035), RAIL)


## THE WINDOWS IN A DECKHOUSE: a dark band round the sides, which is what reads as glass at any distance a boat this size
## is looked at from. A trawler's wheelhouse is glazed nearly all round; a coachroof has a long low strip.
static func _house_windows(tool: SurfaceTool, r: Rect2, bottom: float, top: float, which: String) -> void:
	# A MAST IS AN ISLAND PART AND IT DOES NOT HAVE WINDOWS. The trawler's mast and its two gantry legs are `island` parts
	# like the shelter deck, so painting a glass band on every island glazed a 0.44 m spar. Told apart by being big enough
	# to be a deckhouse rather than by being named, so a new deckhouse gets windows without anybody listing it.
	if r.size.x < 1.5 or r.size.y < 1.5:
		return
	var high: float = top - bottom
	var band: float = high * (0.45 if which == "stern_trawler" else 0.34)
	var at: float = top - high * (0.72 if which == "stern_trawler" else 0.58)
	Plating.band(tool, r, at, at + band, GLASS, 0.03)


## THE HELM STATION: a glazed wheelhouse on the trawler, an open cockpit on everything else. Returns the panels a sight
## line has to reckon with.
static func _helm_station(tool: SurfaceTool, part: Dictionary, r: Rect2, which: String, paint: Dictionary,
		fittings: Array[AABB]) -> Array[AABB]:
	var bottom: float = float(part["bottom"])
	var top: float = float(part["top"])
	if which == "stern_trawler":
		var made: Array[AABB] = Wheelhouse.build(tool, part, ["fore", "port", "starboard"], paint["house"], STEEL)
		Plating.band(tool, r, bottom + (top - bottom) * 0.30, bottom + (top - bottom) * 0.80, GLASS, 0.02)
		return made
	# AN OPEN COCKPIT: a sole to stand on, coamings round it, and benches. Nothing overhead, so nothing here blocks a
	# sight line -- which is why these boats have no panels and why their helms can see out.
	Plating.paint(tool, part["outline"], bottom, TEAK if which == "classic_cutter" else paint["house"])
	var ring: PackedVector2Array = Plating.upward(part["outline"])
	for i in range(ring.size()):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % ring.size()]
		Plating.bar(tool, a, b, 0.07, bottom, top, paint["house"])
	if which == "motor_yacht":
		# A RAKED WINDSCREEN on the flybridge, and a radar arch over it: the two things that say "flybridge" at a glance.
		Plating.box(tool, Vector3(r.get_center().x, top + 0.34, r.position.y + 0.10),
			Vector3(r.size.x * 0.92, 0.68, 0.10), GLASS)
		fittings.append(AABB(Vector3(r.position.x, top, r.position.y), Vector3(r.size.x, 0.70, 0.30)))
	return [] as Array[AABB]


## A MAST, A BOOM AND THE SAILS of a masthead sloop: one headsail on the forestay, and the mainsail on the after side of
## the mast. `air_draught` is PUBLISHED and is where the masthead goes; nothing about the rig is typed in metres here.
static func _sloop_rig(tool: SurfaceTool, c: Dictionary, bow: float, stern: float, parts: Array, paint: Dictionary,
		fittings: Array[AABB]) -> void:
	var deck: float = Superstructure.top_under(parts, Vector2(0.0, -1.0))
	var head: float = float(c["air_draught"])
	var foot: float = (bow + stern) * 0.5 - 1.2
	_spar(tool, Vector3(0.0, deck, foot), Vector3(0.0, head, foot), 0.16, 0.10)
	var boom: float = deck + 1.35
	var clew: float = foot + (stern - foot) * 0.62
	_spar(tool, Vector3(0.0, boom, foot + 0.2), Vector3(0.0, boom - 0.10, clew), 0.13, 0.11)
	_sail(tool, Vector3(0.0, boom, foot + 0.2), Vector3(0.0, head - 0.15, foot), 0.30, Vector3(0.0, boom - 0.10, clew))
	# THE HEADSAIL, tacked near the stem and hoisted to the masthead, which is what makes her a MASTHEAD sloop.
	var tack := Vector3(0.0, deck + 0.25, bow + 0.55)
	_sail(tool, tack, Vector3(0.0, head - 0.25, foot), 0.26, Vector3(0.0, boom - 0.05, foot + 2.2))
	fittings.append(AABB(Vector3(-0.18, deck, foot - 0.2), Vector3(0.36, head - deck, 0.4)))


## A CUTTER'S RIG: TWO HEADSAILS, a jib on the forestay and a staysail on an inner forestay, which is the definition of
## the type and the thing that tells her from the sloop at any distance where the sails are visible at all.
static func _cutter_rig(tool: SurfaceTool, c: Dictionary, bow: float, stern: float, parts: Array, paint: Dictionary,
		fittings: Array[AABB]) -> void:
	var deck: float = Superstructure.top_under(parts, Vector2(0.0, -0.6))
	var head: float = float(c["air_draught"])
	# THE MAST STANDS FURTHER AFT ON A CUTTER than on a sloop, which is what makes room for two headsails in front of it.
	var foot: float = (bow + stern) * 0.5 - 0.35
	_spar(tool, Vector3(0.0, deck, foot), Vector3(0.0, head, foot), 0.14, 0.09)
	var boom: float = deck + 1.20
	var clew: float = foot + (stern - foot) * 0.66
	_spar(tool, Vector3(0.0, boom, foot + 0.18), Vector3(0.0, boom - 0.08, clew), 0.11, 0.095)
	_sail(tool, Vector3(0.0, boom, foot + 0.18), Vector3(0.0, head - 0.12, foot), 0.26,
		Vector3(0.0, boom - 0.08, clew))
	# THE JIB, tacked at the stem, and THE STAYSAIL inboard of it on its own stay -- the foretriangle height is PUBLISHED
	# (11.13 m), so that is where the inner stay is set up and the sail is cut to it.
	_sail(tool, Vector3(0.0, deck + 0.22, bow + 0.35), Vector3(0.0, head - 0.20, foot), 0.22,
		Vector3(0.0, boom + 0.05, foot + 1.9))
	_sail(tool, Vector3(0.0, deck + 0.24, bow + 2.30), Vector3(0.0, float(c["foretriangle"]), foot), 0.18,
		Vector3(0.0, boom + 0.10, foot + 0.9))
	# A TILLER AND A KEEL-HUNG RUDDER, not a wheel and a spade: the rudder is on the keel's after edge, so it is drawn
	# where the keel ends rather than out under the counter.
	_underwater_blade(tool, c, 2.70, 0.09, 1.5, float(c["draught"]) * 0.92, paint)
	Plating.box(tool, Vector3(0.0, deck + 0.55, 2.05), Vector3(0.05, 0.05, 1.5), TEAK)
	fittings.append(AABB(Vector3(-0.16, deck, foot - 0.2), Vector3(0.32, head - deck, 0.4)))


## A WORKING BOAT'S GEAR: the trawl gantry's crosshead over the ramp, the derrick on the mast, and the net drum on the
## shelter deck. Everything stands on what is under it, asked of the parts.
static func _trawler_gear(tool: SurfaceTool, c: Dictionary, bow: float, stern: float, parts: Array, paint: Dictionary,
		fittings: Array[AABB]) -> void:
	var shelter: float = float(c["freeboard"]) + float(c["shelter"])
	var half: float = float(c["beam"]) * 0.5
	# THE GANTRY'S CROSSHEAD, standing ON TOP of the two legs the shape already puts aft, not straddling their tops: at
	# the legs' own height its foot sat 0.13 m below them and `_fittings_stand_on_the_ship` called it airborne, which at
	# 0.13 m against a 0.06 m tolerance it was.
	var legs: float = shelter + 2.6
	Plating.box(tool, Vector3(0.0, legs + 0.13, stern - 2.2), Vector3(half * 1.56, 0.26, 0.26), paint["cove"])
	for side in [-1.0, 1.0]:
		Plating.box(tool, Vector3(side * half * 0.74, legs - 0.25, stern - 2.2), Vector3(0.5, 0.5, 0.20), STEEL)
	# THE NET DRUM across the shelter deck, which is most of what a stern trawler's after end looks like. It STANDS ON the
	# shelter deck, so its foot is that deck's top and it is the fitting this boat reports.
	Plating.box(tool, Vector3(0.0, shelter + 0.55, stern - 5.4), Vector3(half * 1.30, 1.10, 1.30), RUST)
	for side in [-1.0, 1.0]:
		Plating.box(tool, Vector3(side * half * 0.66, shelter + 0.75, stern - 5.4), Vector3(0.14, 1.32, 1.32), STEEL)
	# TRAWL WINCHES forward under the shelter, and the anchor on the stem.
	for side in [-1.0, 1.0]:
		Plating.box(tool, Vector3(side * half * 0.52, shelter + 0.45, bow + 9.5), Vector3(1.0, 0.9, 1.4), RUST)
	Plating.box(tool, Vector3(0.0, float(c["freeboard"]) + 0.5, bow + 0.9), Vector3(0.55, 0.5, 0.5), STEEL)
	# THE DRUM IS REPORTED AS THE FITTING AND THE CROSSHEAD IS NOT, which is a limit of the check and worth naming. A
	# gantry crosshead SPANS its two legs, so there is nothing at all under its middle -- and `_fittings_stand_on_the_ship`
	# asks what is under a fitting's centre. It reported the crosshead standing on nothing 2.6 m over the shelter deck,
	# which is exactly where a crosshead is and exactly what a bridging member looks like to a check that samples one
	# point. Nothing here spans anything else, so the drum answers instead.
	fittings.append(AABB(Vector3(-half * 1.30 * 0.5, shelter, stern - 6.05), Vector3(half * 1.30, 1.10, 1.30)))


## A MOTOR YACHT'S GEAR: the bathing platform on the transom, which every boat of the type has, and the anchor forward.
static func _motor_gear(tool: SurfaceTool, c: Dictionary, bow: float, stern: float, parts: Array, paint: Dictionary,
		fittings: Array[AABB]) -> void:
	var deck: float = float(c["freeboard"])
	var half: float = float(c["beam"]) * 0.5
	# THE BATHING PLATFORM, TUCKED INSIDE THE PUBLISHED LENGTH. Hung 0.42 m abaft the transom it reached 0.84 m past the
	# hull and drew the boat 16.39 m against a published 15.55 -- 5.4 per cent, and length overall is measured to the
	# extreme point, so a platform outside the hull IS the length. It sits within the transom instead.
	#
	# AND IT STANDS ON THE TRANSOM, not in the air: its fitting box is reported at the hull's own after face, because
	# `_fittings_stand_on_the_ship` holds a fitting to the top of a part under it and a platform hung off the stern has
	# no part under it at all.
	Plating.box(tool, Vector3(0.0, deck - 1.05, stern - 0.42), Vector3(half * 1.50, 0.12, 0.84), TEAK)
	Plating.box(tool, Vector3(0.0, deck + 0.18, bow + 0.7), Vector3(0.40, 0.36, 0.60), STEEL)


## A SPAR: a faceted tapered tube from `from` to `to`, eight sides, as low-poly as the Hawkeye's nacelle rounds.
static func _spar(tool: SurfaceTool, from: Vector3, to: Vector3, wide: float, thin: float) -> void:
	var along: Vector3 = (to - from).normalized()
	var side: Vector3 = along.cross(Vector3.RIGHT if absf(along.x) < 0.9 else Vector3.UP).normalized()
	var other: Vector3 = along.cross(side).normalized()
	for i in range(SPAR_SIDES):
		var a: float = TAU * float(i) / float(SPAR_SIDES)
		var b: float = TAU * float(i + 1) / float(SPAR_SIDES)
		var pa: Vector3 = side * cos(a) + other * sin(a)
		var pb: Vector3 = side * cos(b) + other * sin(b)
		Plating.quad(tool, [from + pa * wide * 0.5, from + pb * wide * 0.5,
			to + pb * thin * 0.5, to + pa * thin * 0.5], SPAR)


## A SAIL, drawn as a QUADRILATERAL with a headboard rather than as a triangle: tack, head forward, head aft, clew. Two
## faces back to back with explicit outward normals, so both sides are drawn and both are wound outwards -- a triangle
## would want two coincident corners at the head, which is a degenerate face the welder may drop and no winding check can
## judge.
##
## THE SAIL IS GIVEN A LITTLE BELLY by throwing the clew off the centreline, because a sail drawn dead flat in the
## centreplane reads as a sheet of card and is invisible edge-on.
## THE SAIL MUST BE PLANAR, and this is the whole of why it is built the way it is. `Plating.quad` works out ONE normal
## for a quadrilateral and hands both its triangles that normal, so a TWISTED quad always yields a face wound against its
## own normal -- eleven of the sloop's 1,404 faces, on the first run, from four sails. Throwing the clew out in x while
## offsetting the headboard in x, y and z twists it.
##
## So the belly is put in by displacing the CLEW ALONE, which tilts the whole sail plane about the luff and keeps it flat,
## and the headboard is laid along the foot's own direction so that it lies in that same plane by construction. And the
## belly is a fraction of the FOOT, not of the luff: at 0.14 of a 17 m luff the sloop's mainsail stood 2.4 m outboard and
## put her drawn beam 6.3 per cent over her published one.
static func _sail(tool: SurfaceTool, tack: Vector3, head: Vector3, headboard: float, clew: Vector3) -> void:
	var blown := Vector3(clew.x + 0.10 * tack.distance_to(clew), clew.y, clew.z)
	var along: Vector3 = (blown - tack).normalized()
	var head_aft: Vector3 = head + along * headboard
	Plating.facing(tool, [tack, head, head_aft, blown], Vector3.RIGHT, SAIL)
	Plating.facing(tool, [blown, head_aft, head, tack], Vector3.LEFT, SAIL_SHADE)


## A BLADE UNDER THE WATER -- a spade rudder, or a rudder hung on a keel's after edge. `at` is its station, `thick` its
## thickness, `chord` its fore-and-aft length and `deep` how far below the waterline it reaches.
static func _underwater_blade(tool: SurfaceTool, _c: Dictionary, at: float, thick: float, chord: float, deep: float,
		_paint: Dictionary) -> void:
	Plating.box(tool, Vector3(0.0, -deep * 0.5, at), Vector3(thick, deep, chord), ANTIFOUL)
