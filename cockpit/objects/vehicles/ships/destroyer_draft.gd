@tool
extends RefCounted
class_name DestroyerDraft
## THE DESTROYER'S SHAPE, AS THE SIMULATION WILL HAVE IT -- A DRAFT, AND A SECOND COPY OF A NUMBER UNTIL IT MOVES.
##
## MOVES TO `cockpit_world.cpp` WHEN THE KIND EXISTS; DELETE THIS COPY. The kind (`destroyer`, 27) is C++ and the slot is
## this lane's (team-lead, 2026-09-17); `tests/merchant_models.gd` fails the day the simulation names a kind `destroyer`
## and this file is still here. Kinds 28 to 30 remain after it, and the fifth new kind forces the wire's kind field from
## five bits to six.
##
## THE SHIP IS AN ARLEIGH BURKE FLIGHT IIA at USS Oscar Austin's size (DDG-79, Bath Iron Works, 2000;
## `craft/destroyer/sources.md`). FLIGHT IIA AND NOT FLIGHT I OR II, and the difference is visible from any angle: this
## is the first flight with the TWO SIDE-BY-SIDE HELICOPTER HANGARS aft and the enlarged flight deck over the transom.
##
## WHAT IS PUBLISHED AND WHAT IS MEASURED, because on this ship the two are cleanly separated:
## - PUBLISHED: 155.30 m overall (509 ft 6 in), 20.12 m in the beam (66 ft), 143.56 m on the waterline (471 ft, ONE
##   source), and the SPY array's 3.66 m octagon (12 ft).
## - THE PUBLISHED 9.45 m DRAUGHT IS TO THE SONAR DOME, NOT THE KEEL, and the model must not float to it. Measured off an
##   orthographic profile, the hull's bottom is 6.63 m under the water and the dome 9.53 m, against a published 9.45 m:
##   the dome is 0.8 % off and the hull bottom 29.8 % off. A HULL DRAWN TO 9.45 m WOULD SIT 2.9 m TOO DEEP AND EVERY
##   SIZE CHECK WOULD PASS, because its box would be right (cockpit-fleet3, 2026-09-17).
## - MEASURED on a broadside, against a waterline FITTED over five stations: freeboard 5.87 m amidships, 8.59 m at the
##   stem and 5.10 m at the transom -- a sheer that falls monotonically aft, which is the check that found two bad picks.
##
## THE DECKHOUSE IS THE SHIP. A Burke is not a hull with a box on it: the superstructure carries the four SPY faces and
## sets the silhouette. Its plan is drawn with CANTED CORNERS, because the faces sit on them -- and THE CANT ITSELF IS AN
## ESTIMATE, the one dimension here with no measurement behind it at all. See `Destroyer.SPY_CANT`.

const NAME: String = "destroyer"
## 9,300 t: PUBLISHED full load for DDG-79 (9,200 long tons). The class row says 9,500 long tons and destroyerhistory
## 9,157: a 3.7 % spread, and the named ship's own figure is used because a number attached to the ship beats one
## attached to its class. THERE IS NO GEOMETRIC ROUTE TO SETTLE THIS, unlike the tanker's freeboard, so it is a stated
## choice rather than a fact.
const MASS: float = 9300000.0

## PUBLISHED [S1, S2].
const LENGTH: float = 155.30
const BEAM: float = 20.12
const WATERLINE_LENGTH: float = 143.56
## MEASURED [B4], and NOT the published 9.45 m, which is to the sonar dome.
const DRAUGHT: float = 6.63
const DOME_DEPTH: float = 9.53
## MEASURED [B7], above the design waterline: the main deck at three stations. The sheer falls aft.
const FREEBOARD_STEM: float = 8.59
const FREEBOARD_MID: float = 5.87
const FREEBOARD_STERN: float = 5.10
## MEASURED [B7]: the masthead, the tallest thing on the ship.
const MASTHEAD: float = 45.29
## THE DECKHOUSE, in steps over the main deck. ESTIMATES from the broadside's proportions: the 0.207 m-a-pixel drawing
## cannot carry a 2 m step and the broadside's superstructure is low-contrast, so these are read as fractions of the
## masthead rather than measured directly. Stated as estimates in `sources.md`.
const HOUSE_01: float = 3.0
const HOUSE_02: float = 6.0
const BRIDGE_DECK: float = 9.0
const BRIDGE_ROOF: float = 12.2
## THE HANGAR aft: two side-by-side boxes, the Flight IIA feature. ESTIMATE, sized to take an MH-60 (about 5.5 m to the
## rotor head folded), with the roof a deck above the hangar floor.
const HANGAR_ROOF: float = 6.4
## WHERE THINGS ARE ALONG THE SHIP, as metres from the bow. ESTIMATES off the broadside's proportions.
const GUN_FROM_BOW: float = 26.0
const HOUSE_FROM_BOW: float = 33.0
## 62 m, not 46: at 46 the house stopped at 79 m and the after funnel stood on bare deck 13 m behind it, which in
## elevation read as three disconnected boxes rather than one superstructure (screenshots, 2026-09-17). A Burke's
## deckhouse is continuous from the forward VLS to the hangars and that is most of what its profile is.
const HOUSE_RUNS: float = 62.0
const HANGAR_FROM_BOW: float = 104.0
const HANGAR_RUNS: float = 20.0
const FLIGHT_DECK_FROM_BOW: float = 124.0
## THE DECKHOUSE'S PLAN: how far its side stands inboard of the ship's, and how long its canted corners are.
const HOUSE_INBOARD: float = 1.6
const CORNER: float = 4.2


## `kind_geometry(27)` as it will be.
static func geometry() -> Dictionary:
	var bow: float = -LENGTH * 0.5
	var stern: float = LENGTH * 0.5
	var half: float = BEAM * 0.5
	var parts: Array = []
	# THE HULL, one part, fine at both ends. A destroyer's stem rakes forward over the water and its transom is square,
	# so the plan is widest a little abaft amidships.
	# EIGHT CORNERS IS WHAT A `HullPart` HOLDS, and the first draft of this outline used nine: a stem point plus four a
	# side. The stem point is dropped and the entry carried by the two forward corners, which is what `kMaxPlanCorners`
	# allows and what the suite caught the same minute (cockpit-fleet3, 2026-09-17).
	parts.append(_part("hull", PackedVector2Array([
		Vector2(half * 0.10, bow),
		Vector2(half, bow + 62.0),
		Vector2(half, stern - 26.0),
		Vector2(half * 0.80, stern),
		Vector2(-half * 0.80, stern),
		Vector2(-half, stern - 26.0),
		Vector2(-half, bow + 62.0),
		Vector2(-half * 0.10, bow),
	]), -DRAUGHT, FREEBOARD_MID))
	# THE DECKHOUSE, a step at a time, each one inboard of the last. THE CORNERS ARE CANTED because the SPY faces sit on
	# them: an eight-sided plan, not a rectangle, and that is what makes the ship read as a Burke from ahead.
	var house_mid: float = bow + HOUSE_FROM_BOW + HOUSE_RUNS * 0.5
	parts.append(_canted("island", 0.0, house_mid, half - HOUSE_INBOARD, HOUSE_RUNS * 0.5, CORNER,
		FREEBOARD_MID, FREEBOARD_MID + HOUSE_02))
	parts.append(_canted("island", 0.0, house_mid - 2.0, half - HOUSE_INBOARD - 2.2, HOUSE_RUNS * 0.5 - 5.0, 3.0,
		FREEBOARD_MID + HOUSE_02, FREEBOARD_MID + BRIDGE_DECK))
	# THE BRIDGE, its front across the house and its wings out towards the ship's side.
	var bridge: Dictionary = _box("bridge", 0.0, bow + HOUSE_FROM_BOW + 9.0, half - HOUSE_INBOARD - 2.6, 4.6,
		FREEBOARD_MID + BRIDGE_DECK, FREEBOARD_MID + BRIDGE_ROOF)
	parts.append(bridge)
	# THE TWO HANGARS, side by side: the Flight IIA feature. Two boxes with a gap on the centreline, not one wide box,
	# because from astern the pair of doors is what the ship is recognised by.
	var hangar_mid: float = bow + HANGAR_FROM_BOW + HANGAR_RUNS * 0.5
	for side in [-1.0, 1.0]:
		parts.append(_box("island", side * 4.3, hangar_mid, 3.6, HANGAR_RUNS * 0.5,
			FREEBOARD_MID, FREEBOARD_MID + HANGAR_ROOF))
	# THE FLIGHT DECK over the stern, and the main deck under everything, both as `deck` parts so a helm stands on them.
	parts.append(_box("deck", 0.0, (bow + FLIGHT_DECK_FROM_BOW + stern) * 0.5, half * 0.86,
		(stern - bow - FLIGHT_DECK_FROM_BOW) * 0.5, FREEBOARD_MID - 0.2, FREEBOARD_MID))
	# THREE SEATS on the bridge: the captain, the officer of the deck and the helm.
	var seats: Array = [
		CrudeCarrierDraft.seat_in(bridge, -2.4, 0.8, 0.0, "pilot"),
		CrudeCarrierDraft.seat_in(bridge, 2.4, 0.8, 0.0, "copilot"),
		CrudeCarrierDraft.seat_in(bridge, 0.0, 5.2, 0.0, "operator"),
	]
	return CrudeCarrierDraft.finish({"name": NAME, "model_name": "boat", "mass": MASS, "pilotable": true,
		"waterline": 0.0, "seat_poses": seats, "parts": parts})


static func _part(role: String, outline: PackedVector2Array, bottom: float, top: float) -> Dictionary:
	return {"part": role, "solid": role != "bridge" and role != "station", "bottom": bottom, "top": top,
		"outline": outline}


static func _box(role: String, x: float, z: float, hx: float, hz: float, bottom: float, top: float) -> Dictionary:
	return _part(role, PackedVector2Array([Vector2(x - hx, z - hz), Vector2(x + hx, z - hz), Vector2(x + hx, z + hz),
		Vector2(x - hx, z + hz)]), bottom, top)


## A BOX WITH ITS FOUR CORNERS CUT, which is what a Burke's deckhouse is in plan: eight sides, and the SPY faces stand on
## four of them. `cut` is how far the cut comes in along each side. Eight corners is exactly what a `HullPart` holds.
static func _canted(role: String, x: float, z: float, hx: float, hz: float, cut: float, bottom: float,
		top: float) -> Dictionary:
	return _part(role, PackedVector2Array([
		Vector2(x - hx + cut, z - hz), Vector2(x + hx - cut, z - hz),
		Vector2(x + hx, z - hz + cut), Vector2(x + hx, z + hz - cut),
		Vector2(x + hx - cut, z + hz), Vector2(x - hx + cut, z + hz),
		Vector2(x - hx, z + hz - cut), Vector2(x - hx, z - hz + cut),
	]), bottom, top)
