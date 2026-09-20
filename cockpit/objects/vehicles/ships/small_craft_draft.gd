@tool
extends RefCounted
class_name SmallCraftDraft
## FOUR SMALL CRAFT'S SHAPES, AS THE SIMULATION WILL HAVE THEM -- DRAFTS, AND A SECOND COPY OF A NUMBER UNTIL THEY MOVE.
##
## MOVES TO `cockpit_world.cpp` WHEN THE KINDS EXIST; DELETE THIS COPY. `tests/merchant_models.gd` fails the day the
## simulation names a kind `cruising_sloop`, `stern_trawler` or `motor_yacht` and this file is still here, as it does for
## the tanker, the ferry, the destroyer and the two container ships.
##
## A CRUISING SLOOP of the Bénéteau Oceanis 40.1's size, A STERN TRAWLER of Ile Vertime's, and a fifty-foot flybridge
## MOTOR YACHT of the Princess F50's. `craft/small_craft/sources.md` holds all three, the alternative trawler that was
## rejected for publishing no draught, and the two readings of the Princess that disagree.
##
## THESE ARE THE BOATS THAT MAKE A HARBOUR LOOK INHABITED, and they are sized against each other as much as against their
## own references: 12.87 m, 22.50 m and 15.55 m, which is the spread a marina actually holds.
##
## THE SLOOP'S DRAUGHT IS NOT ITS HULL'S. A published 2.27 m is to the bottom of the fin keel; the canoe body draws about
## 0.65 m (ESTIMATE) and the fin carries the rest. So the keel is its own `hull` part reaching the published figure, and a
## hull drawn 2.27 m deep would be a boat nobody has ever seen. It is a part and not a fitting because it is the deepest
## thing on the boat and it is what the boat would sit on.
##
## NOTHING HERE IS MEASURED. No readable three-view or scaled photograph of any of the three was found, so every figure is
## either a published envelope or a proportion reasoned from one, and `sources.md` says which is which. That is a weaker
## footing than the tanker's or the container ships' and it is stated rather than left to be inferred.
##
## FRAME: origin midships on the design waterline, +X starboard, -Z to the bow, as every boat here.

## The deck plate's thickness.
const PLATE: float = 0.10

## THE THREE BOATS' PUBLISHED FIGURES, one row each. `freeboard` and every height above the deck are ESTIMATES; the
## envelope figures are published. Masses are the real boats' displacements, which at this size the solver can hold
## honestly -- unlike the capital ships, nothing here needs a cap.
const CLASSES: Dictionary = {
	"cruising_sloop": {
		"length": 12.87, "beam": 4.18, "draught": 2.27, "canoe_draught": 0.65, "freeboard": 1.15,
		"mass": 7985.0, "air_draught": 18.33, "knots": 0.0,
	},
	"stern_trawler": {
		"length": 22.50, "beam": 7.90, "draught": 3.20, "freeboard": 2.00,
		"mass": 173000.0, "shelter": 2.10, "wheelhouse": 2.60, "knots": 10.0,
	},
	"motor_yacht": {
		"length": 15.55, "beam": 4.34, "draught": 1.25, "freeboard": 1.55,
		"mass": 23200.0, "saloon": 1.90, "flybridge": 1.50, "knots": 34.0,
	},
	# THE LEIGH 30, asked for by the user by name (2026-09-19). A 1979 Chuck Paine cutter built by Morris Yachts at Bass
	# Harbor, Maine, nineteen of them. It is here BECAUSE it is nothing like the Oceanis: where the modern boat has a
	# plumb stem, a fin keel and a transom nearly its full beam, this one has a raked stem, a LONG keel with a cutaway
	# forefoot, a CANOE TRANSOM that comes almost to a point, a rudder hung on the keel and a tiller. Two sailing boats
	# that read as the same boat would have been a waste of one of them.
	"classic_cutter": {
		"length": 9.14, "waterline": 7.11, "beam": 2.97, "draught": 1.40, "canoe_draught": 0.75,
		"freeboard": 1.05, "bulwark": 0.16, "mass": 4128.0, "ballast": 1996.0,
		"foretriangle": 11.13, "air_draught": 13.10, "knots": 0.0,
	},
}


## THE BOAT'S OWN DICTIONARY, `kind_geometry(n)` as it will be. `which` is a key of `CLASSES`.
static func geometry(which: String) -> Dictionary:
	assert(CLASSES.has(which), "no small craft named %s" % which)
	match which:
		"cruising_sloop":
			return _sloop()
		"stern_trawler":
			return _trawler()
		"classic_cutter":
			return _cutter()
		_:
			return _motor_yacht()


## A CLASSIC LONG-KEEL CUTTER, the Leigh 30's shape: a raked stem, a canoe transom that comes nearly to a point, and a
## keel running most of the boat's length with the rudder hung on its after edge.
##
## THE CANOE TRANSOM IS THE WHOLE POINT OF DRAWING HER. A modern production cruiser carries its beam right aft and ends
## in a transom almost as wide as the boat; this one narrows from amidships all the way to a stern 0.36 m across. In plan
## the two are opposite shapes, and that is what a reader will see in a marina before they see anything else.
static func _cutter() -> Dictionary:
	var c: Dictionary = CLASSES["classic_cutter"]
	var length: float = float(c["length"])
	var half: float = float(c["beam"]) * 0.5
	var bow: float = -length * 0.5
	var stern: float = length * 0.5
	var keel_bottom: float = -float(c["draught"])
	var canoe: float = -float(c["canoe_draught"])
	var deck: float = float(c["freeboard"])
	# HIGH FREEBOARD EXTENDED BY BULWARKS, which Wikipedia names as a feature of the boat: the deck is at the freeboard
	# and the bulwark stands proud of it, so the drawn topsides are taller than the freeboard figure alone.
	var rail: float = deck + float(c["bulwark"])
	var parts: Array = []
	# THE ENTRY under a raked stem. The rake is a profile matter and lives in the hull rows; in plan the bow is simply
	# fine, and the half-beam steps out 0.62, 0.52 and 0.34 m -- decreasing, so the outline is convex by a margin.
	var fore := PackedVector2Array([
		Vector2(-0.10, bow), Vector2(0.10, bow), Vector2(0.72, bow + 0.95), Vector2(1.24, bow + 1.90),
		Vector2(1.44, bow + 2.85), Vector2(-1.44, bow + 2.85), Vector2(-1.24, bow + 1.90), Vector2(-0.72, bow + 0.95)])
	var middle := PackedVector2Array([Vector2(-half, bow + 2.85), Vector2(half, bow + 2.85),
		Vector2(half, stern - 2.60), Vector2(-half, stern - 2.60)])
	# THE CANOE TRANSOM: narrowing all the way aft to 0.36 m across, where a modern boat would be 2.6 m wide.
	var aft := PackedVector2Array([
		Vector2(half, stern - 2.60), Vector2(half * 0.90, stern - 1.40), Vector2(half * 0.55, stern - 0.50),
		Vector2(0.18, stern), Vector2(-0.18, stern), Vector2(-half * 0.55, stern - 0.50),
		Vector2(-half * 0.90, stern - 1.40), Vector2(-half, stern - 2.60)])
	for outline in [fore, middle, aft]:
		parts.append(_part("hull", outline, canoe, rail - PLATE))
		parts.append(_part("deck", outline, rail - PLATE, rail))
	# THE LONG KEEL, running from a cutaway forefoot to well aft and reaching the PUBLISHED 1.40 m. It is 4.8 m long
	# against the sloop's 1.8 m fin, which is the difference between the two kinds of boat under water.
	parts.append(_box("hull", 0.0, 0.30, 0.24, 2.40, keel_bottom, canoe))
	# THE COACHROOF, and a cockpit with a tiller rather than a wheel -- so the helm sits aft of the well, on the quarter,
	# rather than behind a pedestal in the middle of it.
	parts.append(_box("island", 0.0, -0.60, half * 0.62, 1.70, rail, rail + 0.48))
	var cockpit: Dictionary = _box("bridge", 0.0, 2.30, half * 0.62, 1.25, rail - 0.42, rail + 0.30)
	parts.append(cockpit)
	var seats: Array = [
		seat_in(cockpit, -0.72, 1.85, 0.0, "pilot"),
		seat_in(cockpit, 0.72, 1.85, 0.0, "copilot"),
	]
	return finish({"name": "classic_cutter", "model_name": "boat", "mass": float(c["mass"]), "pilotable": true,
		"waterline": 0.0, "seat_poses": seats, "parts": parts})


## A CRUISING SLOOP: a fine entry, the maximum beam carried well aft and a broad transom, which is what a modern
## production cruiser's plan looks like and is most of what tells it from a boat of thirty years ago.
static func _sloop() -> Dictionary:
	var c: Dictionary = CLASSES["cruising_sloop"]
	var length: float = float(c["length"])
	var half: float = float(c["beam"]) * 0.5
	var bow: float = -length * 0.5
	var stern: float = length * 0.5
	var keel_bottom: float = -float(c["draught"])
	var canoe: float = -float(c["canoe_draught"])
	var deck: float = float(c["freeboard"])
	var parts: Array = []
	# THE ENTRY, its half-beam stepping out by 0.73, 0.65 and 0.42 m over three equal steps aft -- decreasing by a margin,
	# because an outline that is convex only just is an outline Box3D will refuse (see ContainerShipDraft's `fore`).
	var fore := PackedVector2Array([
		Vector2(-0.12, bow), Vector2(0.12, bow), Vector2(0.85, bow + 1.3), Vector2(1.50, bow + 2.6),
		Vector2(1.92, bow + 3.9), Vector2(-1.92, bow + 3.9), Vector2(-1.50, bow + 2.6), Vector2(-0.85, bow + 1.3)])
	var middle := PackedVector2Array([Vector2(-half, bow + 3.9), Vector2(half, bow + 3.9),
		Vector2(half, stern - 2.0), Vector2(-half, stern - 2.0)])
	var aft := PackedVector2Array([
		Vector2(half, stern - 2.0), Vector2(half, stern - 0.8), Vector2(half * 0.88, stern),
		Vector2(-half * 0.88, stern), Vector2(-half, stern - 0.8), Vector2(-half, stern - 2.0)])
	for outline in [fore, middle, aft]:
		parts.append(_part("hull", outline, canoe, deck - PLATE))
		parts.append(_part("deck", outline, deck - PLATE, deck))
	# THE FIN KEEL, reaching the PUBLISHED 2.27 m: a blade a quarter of a metre thick under the middle of the boat. It is
	# the deepest thing the sloop has and the reason its published draught is not its hull's.
	parts.append(_box("hull", 0.0, -0.3, 0.13, 0.9, keel_bottom, canoe))
	# THE COACHROOF over the saloon, and THE COCKPIT abaft it -- an open well whose sole is 0.45 m below the side deck,
	# which is where the helm sits and what `_something_under_every_helm` finds under it.
	parts.append(_box("island", 0.0, -1.0, half * 0.65, 2.2, deck, deck + 0.55))
	var cockpit: Dictionary = _box("bridge", 0.0, 3.2, half * 0.72, 1.8, deck - 0.45, deck + 0.40)
	parts.append(cockpit)
	var seats: Array = [
		seat_in(cockpit, -1.1, 2.6, 0.0, "pilot"),
		seat_in(cockpit, 1.1, 2.6, 0.0, "copilot"),
	]
	return finish({"name": "cruising_sloop", "model_name": "boat", "mass": float(c["mass"]), "pilotable": true,
		"waterline": 0.0, "seat_poses": seats, "parts": parts})


## A STERN TRAWLER: beamy for her length, a shelter deck the full length of the working deck, and THE WHEELHOUSE FORWARD,
## which is the modern arrangement and the thing that tells this boat from a sixty-year-old side trawler at a glance.
static func _trawler() -> Dictionary:
	var c: Dictionary = CLASSES["stern_trawler"]
	var length: float = float(c["length"])
	var half: float = float(c["beam"]) * 0.5
	var bow: float = -length * 0.5
	var stern: float = length * 0.5
	var draught: float = -float(c["draught"])
	var deck: float = float(c["freeboard"])
	var shelter: float = deck + float(c["shelter"])
	var parts: Array = []
	var fore := PackedVector2Array([
		Vector2(-0.20, bow), Vector2(0.20, bow), Vector2(1.70, bow + 1.6), Vector2(2.90, bow + 3.2),
		Vector2(3.65, bow + 4.8), Vector2(-3.65, bow + 4.8), Vector2(-2.90, bow + 3.2), Vector2(-1.70, bow + 1.6)])
	var middle := PackedVector2Array([Vector2(-half, bow + 4.8), Vector2(half, bow + 4.8),
		Vector2(half, stern - 3.0), Vector2(-half, stern - 3.0)])
	# A TRANSOM WITH THE STERN RAMP IN IT, and a trawler's is nearly the full beam because the net comes up it.
	var aft := PackedVector2Array([
		Vector2(half, stern - 3.0), Vector2(half, stern - 1.0), Vector2(half * 0.86, stern),
		Vector2(-half * 0.86, stern), Vector2(-half, stern - 1.0), Vector2(-half, stern - 3.0)])
	for outline in [fore, middle, aft]:
		parts.append(_part("hull", outline, draught, deck - PLATE))
		parts.append(_part("deck", outline, deck - PLATE, deck))
	# THE SHELTER DECK over the working deck, from abaft the wheelhouse to the transom: what makes this a shelter-deck
	# boat rather than an open one, and what the crew work under.
	parts.append(_box("island", 0.0, 2.0, half * 0.94, 8.0, deck, shelter))
	# THE WHEELHOUSE FORWARD, standing on the shelter deck's forward end, nearly the full beam for the view.
	# AT 38 PER CENT OF THE LENGTH FROM THE BOW, not 29. Still emphatically a forward wheelhouse -- which is the modern
	# arrangement and the point of the boat -- but far enough aft that the skipper can see the foredeck over his own
	# sill. The sum: the eye sits 0.40 m above a 0.95 m sill, so it can look down past it at a slope of 0.40/d where d is
	# how far back from the glass it sits, and it NEEDS a slope of (eye - deck - 1) / half the distance to the stem. At
	# bow + 6.6 those two crossed at d < 0.39 m, which is closer to the glass than a head may sit without touching it.
	var wheelhouse: Dictionary = _box("bridge", 0.0, bow + 8.5, half * 0.82, 2.2, shelter,
		shelter + float(c["wheelhouse"]))
	parts.append(wheelhouse)
	# THE MAST on the wheelhouse roof, and THE GANTRY aft -- an A-frame over the ramp that the trawl blocks hang from.
	# THE MAST MOVED WITH THE WHEELHOUSE IT STANDS ON. Left at bow + 6.0 when the wheelhouse went aft to bow + 8.5, it
	# stood 6.70 m up on nothing at all -- the second floating part of this lane, caught this time by a check rather than
	# by a picture. A fitting that names the part it stands on would not drift; a metre typed twice will, every time.
	parts.append(_box("island", 0.0, bow + 8.0, 0.22, 0.22, shelter + float(c["wheelhouse"]),
		shelter + float(c["wheelhouse"]) + 4.2))
	for side in [-1.0, 1.0]:
		parts.append(_box("island", side * half * 0.74, stern - 2.2, 0.24, 0.24, shelter, shelter + 2.6))
	var seats: Array = [
		# THE HELM SITS AT THE GLASS, 0.5 m from the front wall and not 1.5. A trawler's wheelhouse stands FORWARD, so the
		# foredeck it has to see is only a few metres ahead and a long way below -- a 33-degree downward look, which no
		# eye gets through a vertical window with a 0.95 m sill unless it is close to it. Sitting the skipper back in the
		# middle of the room put the sight line into the sill and failed both foredeck checks.
		seat_in(wheelhouse, -1.0, 0.5, 0.0, "pilot"),
		seat_in(wheelhouse, 1.0, 0.5, 0.0, "copilot"),
	]
	return finish({"name": "stern_trawler", "model_name": "boat", "mass": float(c["mass"]), "pilotable": true,
		"waterline": 0.0, "seat_poses": seats, "parts": parts})


## A FIFTY-FOOT FLYBRIDGE MOTOR YACHT: a planing hull with a hard chine, a saloon under a raked windscreen and the
## flybridge over it, which is the whole shape of the type.
static func _motor_yacht() -> Dictionary:
	var c: Dictionary = CLASSES["motor_yacht"]
	var length: float = float(c["length"])
	var half: float = float(c["beam"]) * 0.5
	var bow: float = -length * 0.5
	var stern: float = length * 0.5
	var draught: float = -float(c["draught"])
	var deck: float = float(c["freeboard"])
	var saloon_roof: float = deck + float(c["saloon"])
	var parts: Array = []
	var fore := PackedVector2Array([
		Vector2(-0.14, bow), Vector2(0.14, bow), Vector2(0.95, bow + 1.4), Vector2(1.65, bow + 2.8),
		Vector2(2.05, bow + 4.2), Vector2(-2.05, bow + 4.2), Vector2(-1.65, bow + 2.8), Vector2(-0.95, bow + 1.4)])
	var middle := PackedVector2Array([Vector2(-half, bow + 4.2), Vector2(half, bow + 4.2),
		Vector2(half, stern - 1.6), Vector2(-half, stern - 1.6)])
	# A PLANING BOAT'S TRANSOM IS NEARLY ITS FULL BEAM, because the after sections have to stay flat to lift.
	var aft := PackedVector2Array([
		Vector2(half, stern - 1.6), Vector2(half, stern - 0.5), Vector2(half * 0.94, stern),
		Vector2(-half * 0.94, stern), Vector2(-half, stern - 0.5), Vector2(-half, stern - 1.6)])
	for outline in [fore, middle, aft]:
		parts.append(_part("hull", outline, draught, deck - PLATE))
		parts.append(_part("deck", outline, deck - PLATE, deck))
	parts.append(_box("island", 0.0, -0.4, half * 0.90, 3.4, deck, saloon_roof))
	var flybridge: Dictionary = _box("bridge", 0.0, -0.9, half * 0.74, 2.3, saloon_roof,
		saloon_roof + float(c["flybridge"]))
	parts.append(flybridge)
	var seats: Array = [
		# FORWARD ON THE FLYBRIDGE for the same reason as the trawler's: the saloon roof reaches 0.6 m further forward
		# than the flybridge does, so a helm set back in the middle looks along its own roof rather than over it.
		seat_in(flybridge, -0.8, 0.4, 0.0, "pilot"),
		seat_in(flybridge, 0.8, 0.4, 0.0, "copilot"),
	]
	return finish({"name": "motor_yacht", "model_name": "boat", "mass": float(c["mass"]), "pilotable": true,
		"waterline": 0.0, "seat_poses": seats, "parts": parts})


## `outline_part`: a part with a convex outline, as `kind_geometry` hands one out.
static func _part(role: String, outline: PackedVector2Array, bottom: float, top: float) -> Dictionary:
	return {"part": role, "solid": role != "bridge" and role != "station", "bottom": bottom, "top": top,
		"outline": outline}


## `box_part`: a part `hx` by `hz` either side of (x, z).
static func _box(role: String, x: float, z: float, hx: float, hz: float, bottom: float, top: float) -> Dictionary:
	return _part(role, PackedVector2Array([Vector2(x - hx, z - hz), Vector2(x + hx, z - hz),
		Vector2(x + hx, z + hz), Vector2(x - hx, z + hz)]), bottom, top)


## `seat_in`: `CrudeCarrierDraft`'s, shared by every draft here rather than copied a sixth time.
static func seat_in(room: Dictionary, across: float, aft: float, yaw: float, station: String) -> Dictionary:
	return CrudeCarrierDraft.seat_in(room, across, aft, yaw, station)


## `finish_hull`: the tanker's, part for part -- `extents.y` is the DECK HEIGHT and not a half-height.
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
