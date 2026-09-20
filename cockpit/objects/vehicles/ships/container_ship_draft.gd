@tool
extends RefCounted
class_name ContainerShipDraft
## TWO CONTAINER SHIPS' SHAPES, AS THE SIMULATION WILL HAVE THEM -- DRAFTS, AND A SECOND COPY OF A NUMBER UNTIL THEY MOVE.
##
## MOVES TO `cockpit_world.cpp` WHEN THE KINDS EXIST; DELETE THIS COPY. Until then the models and their suite need ships to
## be drawn from, so this is `kind_geometry`'s own dictionary for them, part for part what a `*_shape()` is to list with
## `outline_part`, `box_part`, `seat_in` and `finish_hull`. Two copies of one shape are the thing rule 4 forbids, so this
## one is on a clock: `tests/merchant_models.gd` fails the day the simulation names a kind `container_feeder` or
## `container_large` and this file is still here.
##
## TWO SHIPS IN ONE FILE, BECAUSE THEY ARE ONE RESEARCH EFFORT AND ONE BOX. `craft/container_ship/sources.md` holds both,
## and the ISO container is the same object on each: stating it twice is how the two would come to disagree.
##
## THE FEEDER is the KRISO Container Ship's hull form, 3,600 TEU, 230.0 m Lpp and 32.20 m in the beam (PUBLISHED). It is a
## published hull form and NOT A SHIP AFLOAT -- none was ever built -- and it is here because it is the only container ship
## in its size band whose TURNING CIRCLE has been measured and published: tactical diameter 3.16 ship lengths, advance
## 3.04, transfer 1.36, at 35 degrees of rudder from 14.5 knots (MEASURED; sources.md, "The turning circle").
##
## THE LARGE ONE is a Maersk Triple-E, 18,270 TEU, 399.2 m by 58.6 m by 16.0 m of draught (PUBLISHED). Its turn is an
## ESTIMATE bounded by IMO MSC.137(76)'s ceiling of five ship lengths, and it is the figure on these two ships carrying the
## least evidence.
##
## THE TWO ARE DIFFERENT SHIPS AND NOT ONE SHIP AT TWO SIZES. The feeder is the conventional arrangement, everything aft in
## one island. The large one is the TWO-ISLAND arrangement that makes a Triple-E recognisable in silhouette: the
## accommodation block well forward of midships, the engine casing and its TWIN funnels a hundred and eighty metres abaft
## it, and container bays running between and around them. If the two read alike from a mile off, the model has failed.
##
## FRAME: origin midships on the design waterline, +X starboard, -Z to the bow, as every ship here.

## THE ISO 668 BOX, which is exact. These are definitions, not measurements: a container ship drawn with the wrong box
## reads wrong to anybody who has ever seen one. Width and height are shared; the two lengths are the twenty and the forty.
const BOX_WIDE: float = 2.438
const BOX_HIGH: float = 2.591
const BOX_HIGH_CUBE: float = 2.896
const BOX_20: float = 6.058
const BOX_40: float = 12.192
## THE GAP BETWEEN STACKS ACROSS THE SHIP: lashing rods and the cell guides' clearance. DERIVED, and derived from the one
## place a real ship states it exactly -- a Panamax carries THIRTEEN rows in a 32.20 m beam, and thirteen ISO boxes are
## 13 x 2.438 = 31.694 m, so the twelve gaps between them share 0.506 m and each is 0.042 m.
##
## IT WAS 0.10 m FIRST, AND THAT LOST A ROW. At a tenth of a metre the thirteen rows want 32.89 m of a 32.20 m beam, so
## the feeder drew twelve and `merchant_models` caught it against the published thirteen. A gap guessed at a round number
## is a gap that decides the cargo, which is not a thing an estimate should be allowed to do.
const LASH: float = 0.042
## AND ALONG IT, between one forty-foot bay and the next.
const BAY_GAP: float = 0.60

## SOLAS V/22: FROM THE CONNING POSITION THE SEA MUST BE IN SIGHT WITHIN TWO SHIP LENGTHS OF THE BOW, OR 500 m, WHICHEVER
## IS LESS. On a container ship this is not a check applied after the fact -- it is the rule that DECIDES how high the deck
## stacks may be, and the reason the large ship's bridge stands where it does. `ContainerShip.tiers_at` works the sight
## line forward from the drawn eye and steps the stacks down towards the bow, which is what a loaded box boat actually
## looks like. Typed here because both the shape and the model need it.
const SOLAS_AHEAD: float = 500.0


## THE TWO SHIPS' PUBLISHED FIGURES, one row each. Every size the model draws comes from here or is worked out from here;
## nothing downstream types a metre of its own.
##
## `height_over_keel` is PUBLISHED on the large ship only (73 m) and is what sets its masthead, rather than the masthead
## being typed and the published height quietly ignored: the mast top is `height_over_keel - draught - deck` over the deck.
## The feeder has no published height, so its masthead is an ESTIMATE and says so.
const CLASSES: Dictionary = {
	"container_feeder": {
		"length": 235.0, "beam": 32.20, "draught": 10.80, "depth": 19.0,
		"teu": 3600, "service_knots": 24.0, "rows": 13,
		"tactical_lengths": 3.16, "advance_lengths": 3.04, "transfer_lengths": 1.36,
		"height_over_keel": 0.0, "masthead_over_deck": 34.0,
		"islands": "aft",
		"house_from_stern": 62.0, "house_depth": 18.0, "house_wide": 24.0,
		"house_roof": 21.0, "bridge_deck": 21.0, "wheelhouse_roof": 25.0, "wheelhouse_wide": 27.0,
		"funnel_top": 29.0,
	},
	"container_large": {
		"length": 399.2, "beam": 58.6, "draught": 16.0, "depth": 30.0,
		"teu": 18270, "service_knots": 19.0, "rows": 23,
		"tactical_lengths": 3.5, "advance_lengths": 3.2, "transfer_lengths": 1.5,
		"height_over_keel": 73.0, "masthead_over_deck": 0.0,
		"islands": "split",
		"house_from_bow": 120.0, "house_depth": 22.0, "house_wide": 36.0,
		"house_roof": 26.0, "bridge_deck": 26.0, "wheelhouse_roof": 31.0, "wheelhouse_wide": 42.0,
		"casing_from_stern": 75.0, "casing_depth": 32.0, "casing_wide": 30.0,
		"casing_roof": 17.0, "funnel_top": 27.0,
	},
}
## Ten thousand tonnes, the capital-ship cap the Ford and the tanker have. A laden Triple-E is about 250,000 t and a laden
## feeder about 55,000, and the reason holds for both: the handling is tuned to the cap, and a body a quarter of a million
## times a one-tonne Cessna is a mass ratio the solver should not be handed (agents.md, "The mass stays ten thousand
## tonnes"). The draught is where the keel is drawn, not what the mass is.
const MASS: float = 10000000.0


## HOW MANY CONTAINERS COULD POSSIBLY FIT ACROSS A BEAM: the beam divided by the ISO box's exact 2.438 m. A BOUND, NOT THE
## ANSWER -- and the lane tried it as the answer first, which is the finding.
##
## THE DERIVATION AND THE PUBLISHED FIGURE DISAGREE ON THE TRIPLE-E, AND THE SHIP IS RIGHT. 58.6 / 2.438 is 24.03, so
## twenty-four boxes would fit across the beam with 7 cm to spare -- and Maersk publishes TWENTY-THREE. The missing row is
## the lashing-bridge walkway, which a hull's beam cannot tell you about: 23 rows occupy 56.07 m and leave 2.53 m of deck
## for people and gear. On the feeder the two agree, because 32.20 / 2.438 is 13.21 and thirteen is what a Panamax carries
## -- the beam itself came from the canal's 32.31 m lock, so the box and the ship were fitted to each other there.
##
## SO `rows` IS A FIGURE IN THE CLASS TABLE, PUBLISHED where a source states it and DERIVED only where it agrees, and this
## function is the sanity bound the suite holds it against: a ship may not carry more rows than will physically fit.
## Believing the derivation cost the first run of `merchant_models` a red, which is the cheapest way to learn it.
static func rows_that_fit(beam: float) -> int:
	return int(floor(beam / BOX_WIDE))


## THE SHIP'S OWN DICTIONARY, `kind_geometry(n)` as it will be: name, model, extents, mass, seats, pilotable, seat poses,
## parts and waterline. `which` is a key of `CLASSES`.
static func geometry(which: String) -> Dictionary:
	assert(CLASSES.has(which), "no container ship class named %s" % which)
	var c: Dictionary = CLASSES[which]
	var length: float = float(c["length"])
	var beam: float = float(c["beam"])
	var draught: float = float(c["draught"])
	var deck: float = float(c["depth"]) - draught
	var bow: float = -length * 0.5
	var stern: float = length * 0.5
	var half: float = beam * 0.5
	var parts: Array = []
	# THE HULL IN FOUR LENGTHS, to the underside of the deck plate: the stem, the entry, the parallel middle body and the
	# run to the transom. FOUR AND NOT THREE for the reason the tanker's draft gives -- a part's outline holds eight corners
	# and four of them are a side, so one length forward makes a barge of the entry in plan.
	#
	# A CONTAINER SHIP IS A FINER SHIP THAN A TANKER. The feeder's block coefficient is a PUBLISHED 0.651 against a VLCC's
	# 0.8, so the entry runs a third of the length before the beam is full, where the tanker's is full in a sixth.
	var stem: float = bow + length * 0.077
	var shoulder: float = bow + length * 0.315
	var run: float = stern - length * 0.330
	# THE FLARE MUST BE CONVEX, and it is easy to draw one that is not. The first version stepped the half-beam out by
	# 0.123, 0.120 and 0.080 of the half-beam over three equal steps aft, which is decreasing -- but only just, and the
	# first two are within rounding of each other, so the cross product at the second corner came out at -0.14 against
	# +4.19 at the third and `merchant_models` refused the shape: Box3D's `HullPart` promises convex and meant it. The
	# steps are 0.153, 0.110 and 0.060 now, which is decreasing by a margin no arithmetic will close.
	var fore := PackedVector2Array([
		Vector2(-half * 0.037, bow), Vector2(half * 0.037, bow),
		Vector2(half * 0.19, bow + length * 0.026), Vector2(half * 0.30, bow + length * 0.051),
		Vector2(half * 0.36, stem), Vector2(-half * 0.36, stem),
		Vector2(-half * 0.30, bow + length * 0.051), Vector2(-half * 0.19, bow + length * 0.026)])
	var entry := PackedVector2Array([
		Vector2(-half * 0.36, stem), Vector2(half * 0.36, stem),
		Vector2(half * 0.72, bow + length * 0.17), Vector2(half, bow + length * 0.25),
		Vector2(half, shoulder), Vector2(-half, shoulder),
		Vector2(-half, bow + length * 0.25), Vector2(-half * 0.72, bow + length * 0.17)])
	var middle := PackedVector2Array([Vector2(-half, shoulder), Vector2(half, shoulder),
		Vector2(half, run), Vector2(-half, run)])
	# THE RUN TO A TRANSOM, which is what a container ship has where a tanker has a cruiser counter: the sections stay full
	# well aft and then cut off square at about 0.55 of the beam.
	var aft := PackedVector2Array([
		Vector2(half, run), Vector2(half, run + length * 0.16),
		Vector2(half * 0.84, stern - length * 0.055), Vector2(half * 0.55, stern),
		Vector2(-half * 0.55, stern), Vector2(-half * 0.84, stern - length * 0.055),
		Vector2(-half, run + length * 0.16), Vector2(-half, run)])
	var lengths: Array = [fore, entry, middle, aft]
	for outline in lengths:
		parts.append(_part("hull", outline, -draught, deck - PLATE))
	# THE DECKS the containers and a helicopter stand on: a metre of plate on each length. Flush fore and aft -- a container
	# ship's weather deck does not step down at the house the way a tanker's does, because the boxes run over the top of it.
	for outline in lengths:
		parts.append(_part("deck", outline, deck - PLATE, deck))
	var bridge: Dictionary = {}
	if String(c["islands"]) == "split":
		bridge = _split_islands(c, parts, bow, stern, deck, half)
	else:
		bridge = _one_island_aft(c, parts, stern, deck)
	# TWO SEATS IN THE WHEELHOUSE: the master, who has the con, and the officer of the watch. They are what SOLAS V/22 is
	# asked of -- without an eye there is no conning position and the sight line over the boxes cannot be checked at all.
	var seats: Array = [
		seat_in(bridge, -1.4, 1.4, 0.0, "pilot"),
		seat_in(bridge, 1.4, 1.4, 0.0, "copilot"),
	]
	return finish({"name": which, "model_name": "boat", "mass": MASS, "pilotable": true, "waterline": 0.0,
		"seat_poses": seats, "parts": parts})


## The deck plate's thickness, and the height of a rail.
const PLATE: float = 1.0


## THE CONVENTIONAL ARRANGEMENT: one island aft over the engine room, the funnel abaft the wheelhouse, the mast on its
## roof. Appends its parts and hands back the bridge part, which the seats stand in.
static func _one_island_aft(c: Dictionary, parts: Array, stern: float, deck: float) -> Dictionary:
	var front: float = stern - float(c["house_from_stern"])
	var depth: float = float(c["house_depth"])
	var wide: float = float(c["house_wide"]) * 0.5
	var wheel: float = float(c["wheelhouse_wide"]) * 0.5
	# The accommodation block, from the weather deck to its own roof.
	parts.append(_box("island", 0.0, front + depth * 0.5, wide, depth * 0.5, deck, deck + float(c["house_roof"])))
	# THE WHEELHOUSE, wider than the block under it and set at its front, because a bridge is built for the view: on a
	# modern ship it reaches very nearly the full beam so the officer of the watch can see his own ship's side.
	var bridge: Dictionary = _box("bridge", 0.0, front + 3.5, wheel, 3.5,
		deck + float(c["bridge_deck"]), deck + float(c["wheelhouse_roof"]))
	parts.append(bridge)
	# THE FUNNEL ON THE AFTER END OF THE HOUSE'S ROOF, AND INSIDE ITS FOOTPRINT. It stood at `front + depth + 6.0` first,
	# which is six metres ABAFT the block it was supposed to be standing on, so it hung in the air 21 m over the deck
	# attached to nothing -- and every check stayed green, because a funnel is a PART and `_fittings_stand_on_the_ship`
	# holds fittings. It was found by looking at the side elevation, which is modelling_here.md section 6's "a part can
	# come off, and nothing will say so" happening again. `_every_island_stands_on_something` now says so.
	parts.append(_box("island", 0.0, front + depth - 5.0, wide * 0.32, 4.0,
		deck + float(c["house_roof"]), deck + float(c["funnel_top"])))
	parts.append(_box("island", 0.0, front + 5.0, 0.6, 0.6,
		deck + float(c["wheelhouse_roof"]), deck + float(c["masthead_over_deck"])))
	return bridge


## THE TWO-ISLAND ARRANGEMENT, and the whole of why a Triple-E looks like a Triple-E: the accommodation forward of
## midships on its own block, the engine casing and TWIN funnels far aft over twin engines, and cargo between them.
##
## THE MASTHEAD IS NOT TYPED. It is `height_over_keel - draught - deck` over the deck, so the PUBLISHED 73 m from keel to
## the top of the ship is what sets it and is then a check on the drawn model, rather than a figure quoted in the research
## and quietly ignored by the shape.
static func _split_islands(c: Dictionary, parts: Array, bow: float, stern: float, deck: float, half: float) -> Dictionary:
	var front: float = bow + float(c["house_from_bow"])
	var depth: float = float(c["house_depth"])
	var wide: float = float(c["house_wide"]) * 0.5
	var wheel: float = float(c["wheelhouse_wide"]) * 0.5
	parts.append(_box("island", 0.0, front + depth * 0.5, wide, depth * 0.5, deck, deck + float(c["house_roof"])))
	var bridge: Dictionary = _box("bridge", 0.0, front + 4.0, wheel, 4.0,
		deck + float(c["bridge_deck"]), deck + float(c["wheelhouse_roof"]))
	parts.append(bridge)
	var mast_top: float = float(c["height_over_keel"]) - float(c["draught"]) - deck
	parts.append(_box("island", 0.0, front + 6.0, 0.7, 0.7, deck + float(c["wheelhouse_roof"]), deck + mast_top))
	# THE ENGINE CASING far aft, and its two funnels side by side: the Triple-E has twin engines on twin shafts, and two
	# uptakes abreast is the silhouette that says so.
	var casing_front: float = stern - float(c["casing_from_stern"]) - float(c["casing_depth"])
	var casing_depth: float = float(c["casing_depth"])
	var casing_wide: float = float(c["casing_wide"]) * 0.5
	parts.append(_box("island", 0.0, casing_front + casing_depth * 0.5, casing_wide, casing_depth * 0.5,
		deck, deck + float(c["casing_roof"])))
	var uptake: float = half * 0.28
	for side in [-1.0, 1.0]:
		parts.append(_box("island", side * uptake, casing_front + casing_depth * 0.62, casing_wide * 0.26, 4.5,
			deck + float(c["casing_roof"]), deck + float(c["funnel_top"])))
	return bridge


## `outline_part`: a part with a convex outline, as `kind_geometry` hands one out.
static func _part(role: String, outline: PackedVector2Array, bottom: float, top: float) -> Dictionary:
	return {"part": role, "solid": role != "bridge" and role != "station", "bottom": bottom, "top": top,
		"outline": outline}


## `box_part`: a part `hx` by `hz` either side of (x, z).
static func _box(role: String, x: float, z: float, hx: float, hz: float, bottom: float, top: float) -> Dictionary:
	return _part(role, PackedVector2Array([Vector2(x - hx, z - hz), Vector2(x + hx, z - hz),
		Vector2(x + hx, z + hz), Vector2(x - hx, z + hz)]), bottom, top)


## `seat_in`: a seat on a room's floor, `across` from its middle and `aft` behind its front wall. `CrudeCarrierDraft`'s,
## which `FerryDraft` already shares -- a fourth copy of six lines is four places for the seat convention to drift.
static func seat_in(room: Dictionary, across: float, aft: float, yaw: float, station: String) -> Dictionary:
	return CrudeCarrierDraft.seat_in(room, across, aft, yaw, station)


## `finish_hull`: the extents from the parts -- how far the solid parts reach, and the highest deck -- and the seat count.
## The tanker's, part for part: `extents.y` is the DECK HEIGHT and not a half-height, which is the simulation's own
## convention and not an obvious one.
static func finish(geometry: Dictionary) -> Dictionary:
	var reach := Vector2.ZERO
	var deck: float = -INF
	var hull_top: float = -INF
	for part in (geometry["parts"] as Array):
		if String(part["part"]) == "station":
			continue
		for p in (part["outline"] as PackedVector2Array):
			reach = Vector2(maxf(reach.x, absf(p.x)), maxf(reach.y, absf(p.y)))
		if String(part["part"]) == "deck":
			deck = maxf(deck, float(part["top"]))
		if String(part["part"]) == "hull":
			hull_top = maxf(hull_top, float(part["top"]))
	geometry["extents"] = Vector3(reach.x, deck if deck > -INF else hull_top, reach.y)
	geometry["seats"] = (geometry["seat_poses"] as Array).size()
	return geometry
