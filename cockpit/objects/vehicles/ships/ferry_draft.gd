@tool
extends RefCounted
class_name FerryDraft
## THE CATAMARAN FERRY'S SHAPE, AS THE SIMULATION WILL HAVE IT -- A DRAFT, AND A SECOND COPY OF A NUMBER UNTIL IT MOVES.
##
## MOVES TO `cockpit_world.cpp` WHEN THE KIND EXISTS; DELETE THIS COPY. The kind (`ferry`, 26) is C++ and is queued behind
## this lane (team-lead, 2026-09-17); `tests/merchant_models.gd` fails the day the simulation names a kind `ferry` and this
## file is still here.
##
## THE SHIP IS A 109 m INCAT WAVE-PIERCING CATAMARAN of HSC Express 3's size (Incat Hull 088, 2017;
## `craft/ferry/sources.md`): 109.40 m overall, 30.50 m in the beam, 3.93 m of draught and 9.20 m from keel to the vehicle
## deck. No operator's livery or name.
##
## TWO HULLS AND WHAT SPANS THEM, which is the whole of what makes this shape different from every other ship here:
## - two `hull` parts, one per demihull, each 5.1 m across with 10.15 m of clear tunnel between them;
## - the CENTRE BOW between them forward, its forefoot 1.5 m over the water, which is what a wave-piercer pierces with;
## - the CROSS STRUCTURE over the tunnel, its underside (the wet deck) 3.5 m over the water, carrying the vehicle deck at
##   5.27 m -- the published 9.2 m depth less the 3.93 m draught.
## Under the waterline there is nothing on the centreline at all, and `tests/merchant_models.gd` holds that.
##
## THE BUOYANCY PROBES LAND OVER THE DEMIHULLS WITHOUT A C++ CHANGE. `sail_boat` puts its four probes at 0.75 of
## `afloat_hx`, which is this ship's 15.25 m: 11.4 m out, inside each demihull's 10.15 to 15.25 m. The roll stiffness of a
## catamaran therefore comes from where its hulls are. Whether that is enough is for the suite that measures the roll, and
## `Shape::probe_x` is the change if it is not (team-lead, 2026-09-17).

const NAME: String = "ferry"
## 2,800 t: the full-load displacement is not published, so this is 1,000 t deadweight (PUBLISHED) and a lightship
## ESTIMATED at 1,800 t. Real scale, well under the capital ships' cap.
const MASS: float = 2800000.0

const LENGTH: float = 109.40
const WATERLINE_LENGTH: float = 102.30
const BEAM: float = 30.50
const DRAUGHT: float = 3.93
const DEPTH: float = 9.20
## THE DEMIHULLS: 5.1 m across each (ESTIMATE, Incat's published 4.33 m on a 26 m beam scaled to 30.5 m), so their
## centres stand 12.7 m out and the tunnel between them is 20.3 m wide.
const HULL_BEAM: float = 5.10
## MEASURED on F1, over the waterline: the centre bow's forefoot, the wet deck at the after end of the tunnel, the sheer,
## the window band, the roof, the wheelhouse roof and the masthead.
const FOREFOOT: float = 1.5
const WET_DECK: float = 3.5
const SHEER: float = 13.6
const WINDOWS: Vector2 = Vector2(15.0, 16.5)
const ROOF: float = 17.5
const WHEELHOUSE_ROOF: float = 20.8
const MASTHEAD: float = 24.4
## The roof's plate, and how far the superstructure and the centre bow run (ESTIMATES: no photograph looks at them square).
const PLATE: float = 1.0
const HOUSE_FROM_BOW: float = 26.7
const HOUSE_TO_STERN: float = 4.7
const CENTRE_BOW_RUNS: float = 24.7
## The demihulls' stems stand 2.7 m abaft the centre bow's nose, which is the ship's forward extreme (F1).
const STEM_ABAFT: float = 2.7
## THE WHEELHOUSE on the roof, forward of amidships (F2), 11 m across and 8 m deep (ESTIMATE).
const WHEELHOUSE_FROM_BOW: float = 38.7


## `kind_geometry(26)` as it will be.
static func geometry() -> Dictionary:
	var bow: float = -LENGTH * 0.5
	var stern: float = LENGTH * 0.5
	var half: float = BEAM * 0.5
	var inner: float = half - HULL_BEAM
	var deck: float = DEPTH - DRAUGHT
	var stem: float = bow + STEM_ABAFT
	var house: float = bow + HOUSE_FROM_BOW
	var parts: Array = []
	# THE TWO DEMIHULLS, keel to sheer. Each is its own part and neither is on the centreline, which is why `HullLoft` takes
	# an axis to loft about.
	for side in [-1.0, 1.0]:
		var centre: float = side * (half - HULL_BEAM * 0.5)
		var out: float = side * half
		var into: float = side * inner
		var nose: float = centre + side * 0.4
		var tail: float = centre - side * 0.4
		parts.append(_part("hull", PackedVector2Array([Vector2(tail, stem), Vector2(nose, stem),
			Vector2(out, stem + 14.0), Vector2(out, stern), Vector2(into, stern), Vector2(into, stem + 14.0)]),
			-DRAUGHT, SHEER))
	# THE CENTRE BOW between them, its forefoot over the water: solid, and not a hull, because nothing about it floats.
	parts.append(_part("island", PackedVector2Array([Vector2(-1.5, bow), Vector2(1.5, bow),
		Vector2(inner, bow + 10.0), Vector2(inner, bow + CENTRE_BOW_RUNS), Vector2(-inner, bow + CENTRE_BOW_RUNS),
		Vector2(-inner, bow + 10.0)]), FOREFOOT, deck))
	# THE CROSS STRUCTURE over the tunnel, from the wet deck to the sheer, closing the ship between the hulls abaft the
	# centre bow.
	parts.append(_box("island", 0.0, (bow + CENTRE_BOW_RUNS + stern) * 0.5, inner,
		(stern - bow - CENTRE_BOW_RUNS) * 0.5, WET_DECK, SHEER))
	# THE SUPERSTRUCTURE on the sheer, a little inboard of the ship's side, and the roof over it as the deck people walk on.
	var house_half: float = half - 1.2
	var house_middle: float = (house + stern - HOUSE_TO_STERN) * 0.5
	var house_long: float = (stern - HOUSE_TO_STERN - house) * 0.5
	parts.append(_box("island", 0.0, house_middle, house_half, house_long, SHEER, ROOF - PLATE))
	parts.append(_box("deck", 0.0, house_middle, house_half, house_long, ROOF - PLATE, ROOF))
	# THE WHEELHOUSE on the roof, forward of amidships.
	var bridge: Dictionary = _box("bridge", 0.0, bow + WHEELHOUSE_FROM_BOW, 5.5, 4.0, ROOF, WHEELHOUSE_ROOF)
	parts.append(bridge)
	# THREE SEATS AT THE CONSOLES: the master, the officer of the watch, and the engineer beside them.
	var seats: Array = [
		CrudeCarrierDraft.seat_in(bridge, -1.6, 1.5, 0.0, "pilot"),
		CrudeCarrierDraft.seat_in(bridge, 1.6, 1.5, 0.0, "copilot"),
		CrudeCarrierDraft.seat_in(bridge, 0.0, 4.6, 0.0, "operator"),
	]
	return CrudeCarrierDraft.finish({"name": NAME, "model_name": "boat", "mass": MASS, "pilotable": true,
		"waterline": 0.0, "seat_poses": seats, "parts": parts})


static func _part(role: String, outline: PackedVector2Array, bottom: float, top: float) -> Dictionary:
	return {"part": role, "solid": role != "bridge" and role != "station", "bottom": bottom, "top": top,
		"outline": outline}


static func _box(role: String, x: float, z: float, hx: float, hz: float, bottom: float, top: float) -> Dictionary:
	return _part(role, PackedVector2Array([Vector2(x - hx, z - hz), Vector2(x + hx, z - hz), Vector2(x + hx, z + hz),
		Vector2(x - hx, z + hz)]), bottom, top)
