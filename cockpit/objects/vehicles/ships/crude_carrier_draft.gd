@tool
extends RefCounted
class_name CrudeCarrierDraft
## THE CRUDE CARRIER'S SHAPE, AS THE SIMULATION WILL HAVE IT -- A DRAFT, AND A SECOND COPY OF A NUMBER UNTIL IT MOVES.
##
## MOVES TO `cockpit_world.cpp` WHEN THE KIND EXISTS; DELETE THIS COPY. The kind (`crude_carrier`, 25) is C++, scheduled in
## the C++ queue after this lane (team-lead, 2026-09-17). Until then the model and its suite need a ship to be drawn from,
## so this is `kind_geometry`'s own dictionary for it, part for part what `crude_carrier_shape()` is to list with
## `outline_part`, `box_part`, `seat_in` and `finish_hull`. Two copies of one shape are the thing rule 4 forbids, so this one
## is on a clock: `tests/merchant_models.gd` fails the day the simulation names a kind `crude_carrier` and this file is
## still here.
##
## THE SHIP IS A VLCC OF THE SIRIUS STAR'S SIZE (DSME, 2008; `craft/crude_carrier/sources.md`): 332 m overall, 60 m in the
## beam, 22.5 m of draught, 31 m from keel to deck. No operator's livery or name: the ship type, with a named vessel as its
## dimensional reference.
##
## FRAME: origin midships on the design waterline, +X starboard, -Z to the bow, as every ship here.
##
## THE DECK STEPS DOWN AT THE HOUSE. The cargo deck is 8.5 m over the water (depth 31 less draught 22.5, PUBLISHED); the
## deck round and abaft the house is 2.6 m lower (MEASURED on P2 and P3, the hull's top edge stepping down 60 px against a
## 193 px freeboard).
##
## THE HOUSE, MEASURED (sources.md, "The tanker's scale"): its front 77 m forward of the stern (75.4 and 78.7 on two
## photographs), five decks and a wheelhouse, the navigation bridge deck 18.7 m over the cargo deck, the wheelhouse roof
## 22.3 m and the masthead 37.7 m; 36.4 m across its lower tiers, a wheelhouse 15.3 m across, and bridge wings out to the
## ship's side. The fore-and-aft lengths of the tiers and the funnel are ESTIMATES: no photograph looks at them square.

const NAME: String = "crude_carrier"
## Ten thousand tonnes, the capital-ship cap the Ford has. The real ship laden is about 360,000 t (318,000 DWT PUBLISHED
## and a lightship ESTIMATED at 42,000 t), and the carrier's reason holds: the handling is tuned to it, and a body a
## hundred thousand times a one-tonne Cessna is a mass ratio the solver should not be handed (agents.md, "The mass stays
## ten thousand tonnes"). The draught is where the keel is drawn, not what the mass is.
const MASS: float = 10000000.0

const LENGTH: float = 332.0
const BEAM: float = 60.0
const DRAUGHT: float = 22.5
const DEPTH: float = 31.0
## The cargo deck's plate, and the step down to the deck round the house.
const PLATE: float = 1.0
const STEP: float = 2.6
## The house front, measured from the stern, and its heights over the cargo deck.
const HOUSE_FROM_STERN: float = 77.0
const BRIDGE_DECK: float = 18.7
const WHEELHOUSE_ROOF: float = 22.3
const MASTHEAD: float = 37.7
## THE TIER ROOF THE UPPER HOUSE STANDS ON: C deck's, 11.2 m over the cargo deck (1.32 freeboards on P2), which is where
## the wide lower block's roof is on the head-on photograph (P4, 10.9 m).
const LOWER_ROOF: float = 11.2
## Where the bridge wings' girder hangs from: 3.0 m of plate under the bridge deck (P4, 28 px at 9.2 px a metre).
const WING_DEPTH: float = 3.0
## THE FUNNEL'S TOP, 30.2 m over the cargo deck: 0.80 of the masthead's height on P4 (270 px against 337).
const FUNNEL_TOP: float = 30.2


## `kind_geometry(25)` as it will be: name, model, extents, mass, seats, pilotable, seat poses, parts and waterline.
static func geometry() -> Dictionary:
	var deck: float = DEPTH - DRAUGHT
	var low_deck: float = deck - STEP
	var bow: float = -LENGTH * 0.5
	var stern: float = LENGTH * 0.5
	var half: float = BEAM * 0.5
	var house: float = stern - HOUSE_FROM_STERN
	var parts: Array = []
	# THE HULL IN FOUR LENGTHS, to the underside of the deck plate: the stem, the shoulder where the entry meets the parallel
	# middle body, that body, and the afterbody abaft the step.
	#
	# FOUR AND NOT THREE, because a part's outline holds eight corners and four of them are a side. With one length forward
	# the entry was a blunt wedge from a 12 m stem head straight to the full beam, and in plan the ship read as a barge
	# (screenshots/2026-09-17/cockpit-fleet3-01-crude-carrier-plan.png). Split in two it takes four points a side to the
	# shoulder, which is what a VLCC's waterline does: fine at the stem head, then full quickly (P4).
	var stem: float = bow + 26.0
	var shoulder: float = bow + 55.0
	var fore := PackedVector2Array([Vector2(-2.0, bow), Vector2(2.0, bow), Vector2(12.0, bow + 8.0),
		Vector2(20.0, bow + 18.0), Vector2(24.0, stem), Vector2(-24.0, stem), Vector2(-20.0, bow + 18.0),
		Vector2(-12.0, bow + 8.0)])
	var entry := PackedVector2Array([Vector2(-24.0, stem), Vector2(24.0, stem), Vector2(28.0, bow + 38.0),
		Vector2(half, bow + 48.0), Vector2(half, shoulder), Vector2(-half, shoulder), Vector2(-half, bow + 48.0),
		Vector2(-28.0, bow + 38.0)])
	var middle := PackedVector2Array([Vector2(-half, shoulder), Vector2(half, shoulder), Vector2(half, house),
		Vector2(-half, house)])
	var aft := PackedVector2Array([Vector2(half, house), Vector2(half, house + 36.0), Vector2(26.0, stern - 16.0),
		Vector2(22.0, stern), Vector2(-22.0, stern), Vector2(-26.0, stern - 16.0), Vector2(-half, house + 36.0),
		Vector2(-half, house)])
	for outline in [fore, entry, middle]:
		parts.append(_part("hull", outline, -DRAUGHT, deck - PLATE))
	parts.append(_part("hull", aft, -DRAUGHT, low_deck - PLATE))
	# THE DECKS a helicopter stands on: a metre of plate on each length.
	for outline in [fore, entry, middle]:
		parts.append(_part("deck", outline, deck - PLATE, deck))
	parts.append(_part("deck", aft, low_deck - PLATE, low_deck))
	# THE HOUSE: its lower tiers across 36.4 m from the deck round it to C deck's roof, 30 m long (ESTIMATE); the upper tiers
	# 14 m across (P4, 13 m) and 20 m long (ESTIMATE); the bridge wings' girder, from side to side under the bridge deck.
	parts.append(_box("island", 0.0, house + 15.0, 18.2, 15.0, low_deck, deck + LOWER_ROOF))
	parts.append(_box("island", 0.0, house + 10.0, 7.0, 10.0, deck + LOWER_ROOF, deck + BRIDGE_DECK))
	parts.append(_box("island", 0.0, house + 1.75, half, 1.75, deck + BRIDGE_DECK - WING_DEPTH, deck + BRIDGE_DECK))
	# THE WHEELHOUSE on the bridge deck, 15.3 m across (P4) and 9 m deep (ESTIMATE), its front on the house front.
	var bridge: Dictionary = _box("bridge", 0.0, house + 4.5, 7.65, 4.5, deck + BRIDGE_DECK, deck + WHEELHOUSE_ROOF)
	parts.append(bridge)
	# THE FUNNEL, a separate casing abaft the wheelhouse on C deck's roof (P1, P5), 8 m across and 10 m long (ESTIMATE);
	# and THE MAST on the wheelhouse roof.
	parts.append(_box("island", 0.0, house + 27.0, 4.0, 5.0, deck + LOWER_ROOF, deck + FUNNEL_TOP))
	parts.append(_box("island", 0.0, house + 6.5, 0.7, 0.7, deck + WHEELHOUSE_ROOF, deck + MASTHEAD))
	# TWO SEATS IN THE WHEELHOUSE: the master, who has the con, and the officer of the watch.
	var seats: Array = [
		seat_in(bridge, -1.2, 1.4, 0.0, "pilot"),
		seat_in(bridge, 1.2, 1.4, 0.0, "copilot"),
	]
	return finish({"name": NAME, "model_name": "boat", "mass": MASS, "pilotable": true, "waterline": 0.0,
		"seat_poses": seats, "parts": parts})


## `outline_part`: a part with a convex outline, as `kind_geometry` hands one out.
static func _part(role: String, outline: PackedVector2Array, bottom: float, top: float) -> Dictionary:
	return {"part": role, "solid": role != "bridge" and role != "station", "bottom": bottom, "top": top,
		"outline": outline}


## `box_part`: a part `hx` by `hz` either side of (x, z).
static func _box(role: String, x: float, z: float, hx: float, hz: float, bottom: float, top: float) -> Dictionary:
	return _part(role, PackedVector2Array([Vector2(x - hx, z - hz), Vector2(x + hx, z - hz), Vector2(x + hx, z + hz),
		Vector2(x - hx, z + hz)]), bottom, top)


## `seat_in`: a seat on a room's floor, `across` from its middle and `aft` behind its front wall. Shared with `FerryDraft`.
static func seat_in(room: Dictionary, across: float, aft: float, yaw: float, station: String) -> Dictionary:
	var r: Rect2 = Wheelhouse.outline_rect(room["outline"])
	return {"position": Vector3(r.get_center().x + across, float(room["bottom"]), r.position.y + aft), "yaw": yaw,
		"station": station, "flies": station == "pilot" or station == "copilot"}


## `finish_hull`: the extents from the parts -- how far the solid parts reach, and the highest deck -- and the seat count.
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
