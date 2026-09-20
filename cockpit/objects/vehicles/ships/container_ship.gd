@tool
extends RefCounted
class_name ContainerShip
## A CONTAINER SHIP, NEAR: a hull with a fine entry and a transom, a flush weather deck under hatch covers, and the deck
## cargo -- bays of ISO boxes, rows across and tiers high, stepping down towards the bow -- with the house, the funnel and
## the mast where the class puts them. One vertex-coloured mesh on the shape's parts.
##
## THE PARTS ARE THE AUTHORITY (`ContainerShipDraft` until the kinds are C++): length, beam, keel, deck, the house, the
## wheelhouse, the casing and the mast are theirs, and this adds what nothing collides with. Sizes here that are in no part
## say where they came from; the references are in `craft/container_ship/sources.md`.
##
## TWO SHIPS FROM ONE BUILDER, because they differ in their figures and their island arrangement and in nothing else about
## how a box boat is drawn. The class table decides; this draws what it says.
##
## THE DECK CARGO IS WHAT A CONTAINER SHIP IS, and it is drawn from the ISO box outwards. Rows across come from the beam
## divided by 2.438 m, tiers from how much deck there is under them, bays from the 12.192 m forty-foot pitch. Nothing about
## the cargo is typed in metres.
##
## AND THE STACKS ARE NOT SHAPED BY THE SIGHT LINE, DELIBERATELY. It is tempting to step the forward bays down until SOLAS
## V/22 is satisfied, and it would be a tautology: `merchant_models.gd` checks the sea ahead from the conning position, and
## a model that derived its stack heights from that check could never fail it (`testing_godot_headless.md`, the tautology
## trap; `modelling_here.md` section 6, "hold the check to something outside the thing it is checking"). So the tiers come
## from the HULL -- a bay is as many rows wide as the deck is wide there, and as many tiers high as a stack that width will
## take -- and whether the master can see the sea over them is then a real question with a real answer. When that check
## fails, the bridge goes up or the cargo comes down, which is the argument a naval architect has too.
##
## THE SHIP TYPE AND NOT THE SHIP. No funnel mark, no line's name, no operator's colours. The liveries below are invented.

## THE HULL'S SECTIONS, top down under the deck plate: `[share, width, stem_in, stern_in]`, the share being how far down to
## the keel the row is (0 the waterline, -1 the keel) and the ends as FRACTIONS OF THE SHIP'S LENGTH, which is what lets
## one table serve a 235 m feeder and a 399 m Triple-E.
##
## A CONTAINER SHIP IS A FINER SHIP THAN A TANKER: block coefficient 0.651 PUBLISHED against a VLCC's 0.8, so the flat of
## the bottom is 0.72 of the beam where the tanker's is 0.88, and the bilge turns higher and harder. The counter comes in a
## long way because the run to a single screw is long.
##
## AS SHARES AND NOT AS HEIGHTS, for the reason the tanker's table gives: typed as metres the keel row says -10.8 whatever
## the shape's keel is, so a draught changed in the table moves the part and leaves the drawn hull where it was.
const ROWS: Array = [
	[0.0, 1.00, 0.002, 0.008],
	[-0.35, 1.00, 0.006, 0.035],
	[-0.70, 0.98, 0.015, 0.080],
	[-0.90, 0.90, 0.026, 0.115],
	[-1.0, 0.72, 0.038, 0.135],
]
## HOW MANY STATIONS EACH HULL LENGTH IS LOFTED ON. THE LOW-POLY LOOK IS DELIBERATE (the user, 2026-09-17: "a somewhat
## lower poly look ... not too many very round edges ... a better old school feel"), and the E-2D's airframe is the
## reference. Six to a length puts a knuckle every 3 m through the feeder's entry and every 20 m along its parallel body,
## and the four lengths meet at hard chines. DO NOT SUBDIVIDE THIS: the sizes are measured and the facets are the style.
const STATIONS_PER_LENGTH: int = 6
## The bulbous bow's facets, and the funnel's. Twelve and ten, against the Hawkeye's 20 on a nacelle round.
const BULB_SIDES: int = 12
const FUNNEL_SIDES: int = 10

## HOW HIGH A STACK MAY GO, and where that comes from. Deck stacks are limited by lashing and by stability long before
## they are limited by anything else; nine tiers over the hatch covers amidships is what a modern ship of this size
## carries and six is what a feeder carries (ESTIMATE, from the class's TEU against its deck area). A bay narrower than
## the full beam carries fewer, because the stack is only as stable as the deck under it is wide.
const TIERS_FULL: int = 9
const TIERS_FEEDER: int = 6
## How much narrower than the widest bay a bay may be before it loses a tier. ESTIMATE.
const TIER_PER_ROWS: float = 3.0

## SIX LIVERIES, SHARED BY BOTH SIZES, so that a fleet looks like a fleet and not a photocopy -- the user's ask,
## 2026-09-19. ONE DICTIONARY OF NAMED ROLES per scheme, chosen by index: the drawing code indexes `paint["hull"]` and
## holds no colour of its own, so a livery is DATA a caller chooses and never a second copy of the model (the airliners'
## `_t["livery"]` is the precedent, and `modelling_here.md` section 1's boundary is the reason).
##
## INVENTED NAMES AND INVENTED COLOURS, named after what they look like. No real line's hull colour, funnel mark, house
## style or name. `boot` is the boot-top at the waterline, `bottom` the antifouling, `band` the funnel's.
##
## CHOSEN BY INDEX AND CACHED BY IT. `ShipHull.models` keys its cache on name AND livery, because six liveries of one
## ship would otherwise collide on one entry and the first one built would be handed out six times, silently.
const LIVERIES: Array = [
	{"name": "slate", "hull": Color(0.13, 0.20, 0.28), "boot": Color(0.10, 0.11, 0.13),
		"bottom": Color(0.42, 0.14, 0.11), "house": Color(0.88, 0.88, 0.85), "funnel": Color(0.16, 0.24, 0.34),
		"band": Color(0.85, 0.62, 0.12)},
	{"name": "oxide", "hull": Color(0.44, 0.19, 0.13), "boot": Color(0.13, 0.10, 0.09),
		"bottom": Color(0.36, 0.13, 0.11), "house": Color(0.90, 0.89, 0.86), "funnel": Color(0.36, 0.16, 0.12),
		"band": Color(0.88, 0.84, 0.78)},
	{"name": "moss", "hull": Color(0.12, 0.26, 0.20), "boot": Color(0.09, 0.12, 0.10),
		"bottom": Color(0.40, 0.14, 0.12), "house": Color(0.89, 0.88, 0.84), "funnel": Color(0.14, 0.30, 0.23),
		"band": Color(0.82, 0.74, 0.30)},
	{"name": "ink", "hull": Color(0.09, 0.10, 0.12), "boot": Color(0.30, 0.10, 0.09),
		"bottom": Color(0.44, 0.15, 0.12), "house": Color(0.86, 0.86, 0.84), "funnel": Color(0.14, 0.15, 0.17),
		"band": Color(0.72, 0.18, 0.16)},
	{"name": "sand", "hull": Color(0.58, 0.54, 0.44), "boot": Color(0.22, 0.20, 0.16),
		"bottom": Color(0.38, 0.15, 0.12), "house": Color(0.91, 0.90, 0.87), "funnel": Color(0.50, 0.46, 0.37),
		"band": Color(0.24, 0.34, 0.46)},
	{"name": "plum", "hull": Color(0.28, 0.13, 0.22), "boot": Color(0.12, 0.08, 0.11),
		"bottom": Color(0.40, 0.14, 0.12), "house": Color(0.90, 0.88, 0.87), "funnel": Color(0.32, 0.15, 0.25),
		"band": Color(0.84, 0.80, 0.40)},
]
const DECK := Color(0.32, 0.31, 0.28)
const HATCH := Color(0.38, 0.37, 0.33)
const GLASS := Color(0.10, 0.12, 0.15)
const STEEL := Color(0.34, 0.36, 0.38)
const SOOT := Color(0.06, 0.06, 0.07)
const RAIL := Color(0.80, 0.80, 0.78)
## THE BOXES ON DECK, in the colours boxes actually come in. A deck of one colour reads as a painted block; a deck of these
## reads as cargo. Which box gets which is a hash of its own place, so the ship looks the same every time it is drawn.
const BOX_PAINT: Array = [
	Color(0.55, 0.20, 0.15), Color(0.18, 0.31, 0.47), Color(0.20, 0.38, 0.28),
	Color(0.58, 0.50, 0.36), Color(0.44, 0.44, 0.46), Color(0.62, 0.36, 0.14),
	Color(0.30, 0.26, 0.34), Color(0.70, 0.66, 0.58),
]

## THE SILHOUETTE'S PAINT, per part role, for `ShipHull.far_mesh`. Past `ShipHull.NEAR_TO` a box boat is its hull, its
## cargo and its house, and the cargo is the middle colour of the deck.
const FAR: Dictionary = {
	"hull": Color(0.13, 0.20, 0.28),
	"deck": Color(0.42, 0.38, 0.34),
	"island": Color(0.88, 0.88, 0.85),
	"bridge": Color(0.55, 0.56, 0.56),
}


## THE NEAR MODEL: `{"mesh", "panels", "fittings"}`, as every ship's own builder hands back. `helm` is the catalogue's;
## `livery` indexes `LIVERIES` and defaults to the first, so a caller that knows nothing about liveries gets a ship.
static func build(geometry: Dictionary, _helm: String = "glazed", livery: int = 0) -> Dictionary:
	var paint: Dictionary = LIVERIES[clampi(livery, 0, LIVERIES.size() - 1)]
	var which: String = String(geometry.get("name", "container_feeder"))
	var c: Dictionary = ContainerShipDraft.CLASSES.get(which, ContainerShipDraft.CLASSES["container_feeder"])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: Array = geometry.get("parts", []) as Array
	var panels: Array[AABB] = []
	var fittings: Array[AABB] = []
	var length: float = float(c["length"])
	var draught: float = float(c["draught"])
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
				HullLoft.build(tool, outline, rows_for(top, bottom, length,
					is_equal_approx(r.position.y, bow), is_equal_approx(r.end.y, stern)), 0.0,
					[paint["hull"], paint["boot"], paint["bottom"]], STATIONS_PER_LENGTH)
			"deck":
				_deck(tool, outline, bottom, top, r, paint)
			"island":
				Plating.prism(tool, outline, bottom, top, paint["house"], false)
				panels.append(AABB(Vector3(r.position.x, bottom, r.position.y),
					Vector3(r.size.x, top - bottom, r.size.y)))
			"bridge":
				panels.append_array(Wheelhouse.build(tool, part, ["fore", "port", "starboard"],
					paint["house"], STEEL))
	_the_bulb(tool, parts, bow, draught, paint)
	_the_cargo(tool, geometry, c, panels, fittings)
	_the_funnels(tool, parts, paint)
	_marks(tool, parts, draught, paint)
	return {"mesh": Plating.weld(tool), "panels": panels, "fittings": fittings}


## THE ROWS OF ONE HULL LENGTH IN METRES, its top first: the deck plate's underside, then `ROWS` against this length's own
## keel, with the ends taken in only where this length is the ship's bow or stern. The end fractions become metres here,
## against the ship's own length, which is the one place that conversion happens.
static func rows_for(top: float, bottom: float, length: float, fines_at_bow: bool, fines_at_stern: bool) -> Array:
	var out: Array = [[top, 1.0, 0.0, 0.0]]
	for row in ROWS:
		out.append([-float(row[0]) * bottom, float(row[1]),
			float(row[2]) * length if fines_at_bow else 0.0,
			float(row[3]) * length if fines_at_stern else 0.0])
	return out


## THE WEATHER DECK: hatch covers over the holds, the sheer strake down the side in the hull's own colour, and a rail
## along every edge that is the ship's side.
static func _deck(tool: SurfaceTool, outline: PackedVector2Array, bottom: float, top: float, r: Rect2,
		paint: Dictionary) -> void:
	Plating.paint(tool, outline, top, DECK)
	var ring: PackedVector2Array = Plating.upward(outline)
	tool.set_color(paint["hull"])
	for i in range(ring.size()):
		Plating.wall(tool, ring[i], ring[(i + 1) % ring.size()], bottom, top)
	# A HATCH COVER over the middle of this length, inset from the side by the walkway the lashings need. KEPT THIN -- a
	# 0.12 m plate rather than the 0.60 m cover a real ship has -- because the container stacks stand on the DECK part
	# under it, and a cover the true thickness would have the bottom tier standing in it.
	var inset: float = minf(r.size.x * 0.10, 2.4)
	if r.size.x > 6.0 and r.size.y > 8.0:
		Plating.box(tool, Vector3(r.get_center().x, top + 0.06, r.get_center().y),
			Vector3(r.size.x - inset * 2.0, 0.12, r.size.y - 4.0), HATCH)
	for i in range(ring.size()):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % ring.size()]
		if is_equal_approx(a.y, b.y) and absf(a.x - b.x) > r.size.x * 0.8:
			continue
		var inward: Vector2 = (r.get_center() - (a + b) * 0.5).normalized() * 0.20
		Plating.bar(tool, a + inward, b + inward, 0.06, top + 0.94, top + 1.0, RAIL)


## THE BULBOUS BOW, which every modern box boat has and which is most of what tells a container ship's forefoot from a
## tanker's in a dry dock. It stands on the stem, under water, reaching forward of the stem head.
static func _the_bulb(tool: SurfaceTool, parts: Array, bow: float, draught: float, paint: Dictionary) -> void:
	var beam: float = 0.0
	for part in parts:
		if String(part["part"]) == "hull":
			beam = maxf(beam, Wheelhouse.outline_rect(part["outline"]).size.x)
	var radius: float = beam * 0.075
	var reach: float = radius * 2.6
	var centre: float = -draught * 0.62
	var ring := PackedVector2Array()
	for i in range(BULB_SIDES):
		var a: float = TAU * float(i) / float(BULB_SIDES)
		ring.append(Vector2(cos(a) * radius, sin(a) * radius))
	# THE BULB'S NOSE IS AT THE STEM, NOT FORWARD OF IT. Drawn reaching 6.3 m ahead of the hull outline it added its own
	# length to the ship: the feeder measured 241.28 m against a published 235.00 and `merchant_models` called it at
	# 2.67 %. Length overall IS measured to the extreme point, so if the bulb is the extreme point then the bulb is where
	# the length is -- the nose goes on the stem and the body runs aft from it.
	for i in range(BULB_SIDES):
		var p: Vector2 = ring[i]
		var q: Vector2 = ring[(i + 1) % BULB_SIDES]
		Plating.quad(tool, [
			Vector3(p.x, centre + p.y, bow + reach),
			Vector3(q.x, centre + q.y, bow + reach),
			Vector3(q.x * 0.28, centre + q.y * 0.28, bow),
			Vector3(p.x * 0.28, centre + p.y * 0.28, bow)], paint["bottom"])


## THE DECK CARGO, bay by bay: how many rows will stand across the deck there, how many tiers that width will carry, and
## a box of ISO size for each. Reported as fittings, and the stacks also go in `panels` because a stack of steel boxes is
## exactly as opaque as a deckhouse and the sight-line checks must see it.
static func _the_cargo(tool: SurfaceTool, geometry: Dictionary, c: Dictionary, panels: Array[AABB],
		fittings: Array[AABB]) -> void:
	var parts: Array = geometry.get("parts", []) as Array
	var deck: float = float(c["depth"]) - float(c["draught"])
	var beam: float = float(c["beam"])
	var most: int = int(c["rows"])
	var tiers_most: int = TIERS_FULL if String(c["islands"]) == "split" else TIERS_FEEDER
	var pitch: float = ContainerShipDraft.BOX_40 + ContainerShipDraft.BAY_GAP
	var across: float = ContainerShipDraft.BOX_WIDE + ContainerShipDraft.LASH
	var keep_out: Array[Rect2] = []
	for part in parts:
		if String(part["part"]) in ["island", "bridge"]:
			keep_out.append(Wheelhouse.outline_rect(part["outline"]))
	var bow: float = INF
	var stern: float = -INF
	for part in parts:
		if String(part["part"]) == "deck":
			var r: Rect2 = Wheelhouse.outline_rect(part["outline"])
			bow = minf(bow, r.position.y)
			stern = maxf(stern, r.end.y)
	# CARGO STOPS AT THE FORWARD FACE OF THE AFTMOST ISLAND, because nothing is stacked on the poop. Without it the feeder
	# put three bays of boxes on the deck ABAFT its own accommodation, where the mooring gear and the lifeboat live, and
	# the Triple-E put them on the engine casing's roof. Asked as "which island reaches furthest aft", so the split
	# arrangement stops at the casing and the conventional one at the house without either being named.
	var hindmost: float = stern
	var furthest: float = -INF
	for part in parts:
		if String(part["part"]) != "island":
			continue
		var r: Rect2 = Wheelhouse.outline_rect(part["outline"])
		if r.end.y > furthest:
			furthest = r.end.y
			hindmost = r.position.y
	var z: float = bow + float(c["length"]) * 0.10
	while z + pitch < minf(stern - float(c["length"]) * 0.06, hindmost - 2.0):
		var mid: float = z + pitch * 0.5
		var width: float = _deck_width_at(parts, mid)
		# HOW MANY ROWS THIS BAY'S DECK WILL TAKE: n boxes have n-1 gaps between them, not n. Dividing the whole width by
		# the pitch counts one gap too many, and on the feeder that is the whole difference between twelve rows and the
		# published thirteen -- thirteen rows want exactly 32.20 m of a 32.20 m beam and the extra gap put them over it.
		# This is the same arithmetic slip as the stack's own bounding box had, in a second place, which is what a shared
		# constant with an unshared formula gets you.
		var rows: int = mini(most, 1 + int(floor((width - ContainerShipDraft.BOX_WIDE) / across)))
		if rows >= 2 and not _inside_any(keep_out, mid):
			# TIERS FROM THE WIDTH OF THE DECK UNDER THE STACK, never from the sight line -- see the doc block.
			var tiers: int = clampi(tiers_most - int(floor(float(most - rows) / TIER_PER_ROWS)), 2, tiers_most)
			_a_bay(tool, mid, rows, tiers, deck, across, panels, fittings)
		z += pitch


## ONE BAY OF BOXES: `rows` across the centreline, `tiers` high, each an ISO forty-foot box of exact size.
static func _a_bay(tool: SurfaceTool, mid: float, rows: int, tiers: int, deck: float, across: float,
		panels: Array[AABB], fittings: Array[AABB]) -> void:
	var high: float = ContainerShipDraft.BOX_HIGH
	var wide: float = ContainerShipDraft.BOX_WIDE
	var long: float = ContainerShipDraft.BOX_40
	# THE STACK STANDS ON THE DECK ITSELF, and that is a check talking, not an aesthetic. Standing it on top of a 0.60 m
	# hatch cover put every one of the feeder's thirteen fittings 0.60 m over the deck part's top, and `ship_models`'
	# `FOOT` tolerance is 0.06: thirteen fittings "on nothing". A fitting stands on a PART (modelling_here.md section 5),
	# and the hatch cover is drawn by `_deck` as a plate thin enough for the bottom tier to sit over it.
	var foot: float = deck
	var first: float = -float(rows - 1) * 0.5 * across
	for row in range(rows):
		var x: float = first + float(row) * across
		for tier in range(tiers):
			var y: float = foot + high * (float(tier) + 0.5)
			var pick: int = abs(hash(Vector2i(int(mid), row * 31 + tier * 7))) % BOX_PAINT.size()
			Plating.box(tool, Vector3(x, y, mid), Vector3(wide, high, long), BOX_PAINT[pick])
	# THE STACK'S BOX IS THE BOXES, not the boxes plus a lashing gap on each end. Counting the gaps in made the feeder's
	# thirteen rows measure 12 and the Triple-E's twenty-three measure 24 in the suite, which looked like a model fault and
	# was an arithmetic one: `rows * (2.438 + lash)` is wider than the cargo actually is by one gap.
	var stack := AABB(Vector3(first - wide * 0.5, foot, mid - long * 0.5),
		Vector3(float(rows - 1) * across + wide, high * float(tiers), long))
	fittings.append(AABB(stack.position, stack.size))
	panels.append(stack)


## HOW WIDE THE DECK IS at a station, asked of the drawn deck parts rather than of the beam, so a bay over the entry is
## narrower than a bay amidships without anybody typing where the entry ends.
static func _deck_width_at(parts: Array, z: float) -> float:
	var width: float = 0.0
	for part in parts:
		if String(part["part"]) != "deck":
			continue
		var outline: PackedVector2Array = part["outline"]
		var r: Rect2 = Wheelhouse.outline_rect(outline)
		if z < r.position.y or z > r.end.y:
			continue
		width = maxf(width, HullLoft.half_width(outline, z) * 2.0)
	return width


## Whether a station falls inside any of the rectangles an island stands on.
static func _inside_any(keep_out: Array[Rect2], z: float) -> bool:
	for r in keep_out:
		if z >= r.position.y - 2.0 and z <= r.end.y + 2.0:
			return true
	return false


## THE FUNNELS, one or two, faceted on ten sides, standing on whatever island part reaches highest under them -- asked of
## the parts by `Superstructure.top_under`, never typed, which is the most expensive rule in the ship lineage.
static func _the_funnels(tool: SurfaceTool, parts: Array, paint: Dictionary) -> void:
	for part in parts:
		if String(part["part"]) != "island":
			continue
		var r: Rect2 = Wheelhouse.outline_rect(part["outline"])
		# A funnel is an island part taller than it is long and standing clear of the weather deck.
		if r.size.y > 12.0 or float(part["top"]) - float(part["bottom"]) < 6.0:
			continue
		var top: float = float(part["top"])
		Plating.box(tool, Vector3(r.get_center().x, top - 0.6, r.get_center().y),
			Vector3(r.size.x * 1.08, 1.2, r.size.y * 1.08), SOOT)
		Plating.box(tool, Vector3(r.get_center().x, top - 4.0, r.get_center().y),
			Vector3(r.size.x * 1.02, 3.0, r.size.y * 0.5), paint["band"])


## DRAUGHT MARKS amidships on both sides: a tick every metre up the flat of the side, as every ship carries.
static func _marks(tool: SurfaceTool, parts: Array, draught: float, _paint: Dictionary) -> void:
	var half: float = 0.0
	var mid: float = 0.0
	for part in parts:
		if String(part["part"]) != "hull":
			continue
		var r: Rect2 = Wheelhouse.outline_rect(part["outline"])
		if r.size.x > half:
			half = r.size.x * 0.5
			mid = r.get_center().y
	for metre in range(2, int(draught), 2):
		for side in [-1.0, 1.0]:
			# KEPT CLOSE TO THE SKIN: draught marks are painted on a real ship, not bolted to it, and a mark standing proud
			# is beam the ship has not got. At 0.05 m out and 0.10 m thick they put the drawn beam 0.2 m over its
			# reference; at 0.03 and 0.06 they cost 0.12 m, which is 0.37 % on the feeder.
			Plating.box(tool, Vector3(side * (half + 0.03), -draught + float(metre), mid),
				Vector3(0.06, 0.16, 1.2), RAIL)
