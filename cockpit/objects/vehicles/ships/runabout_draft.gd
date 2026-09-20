@tool
extends RefCounted
class_name RunaboutDraft
## A TRIPLE-COCKPIT MAHOGANY RUNABOUT'S SHAPE, AS THE SIMULATION WILL HAVE IT -- A DRAFT, AND A SECOND COPY OF A NUMBER
## UNTIL IT MOVES.
##
## MOVES TO `cockpit_world.cpp` AS `runabout_shape()` WHEN THE KIND EXISTS; DELETE THIS FILE THEN. `tests/runabout.gd`
## fails the day the simulation names a kind `runabout` and this copy is still here, exactly as the tanker's, the
## ferry's, the destroyer's and the four small craft's do. The shared C++ is a queue of one and the modelling did not
## need to wait for it, which is the only reason this file exists.
##
## THE BOAT IS A CHRIS-CRAFT 27 FT CUSTOM RUNABOUT, model Custom 309, 1932-1941; sixty-two were built.
## `craft/runabout/sources.md` holds every figure, its tag and its source, and `craft/runabout/measure_photos.py`
## re-derives the colours from the reference photographs without reading either.
##
## THREE PUBLISHED NUMBERS AND THE REST REASONED, and the file says which at every line. Length 8.230 m, beam 2.184 m
## and a 0.711 m draught are published [S]. Nothing else about this boat is: no weight or displacement for any pre-war
## Chris-Craft runabout was readable anywhere, and no free-licensed photograph of a genuine triple-cockpit boat exists
## that this lane could find, so the cockpit stations come from the PUBLISHED ARRANGEMENT rather than from a picture.
##
## THE PUBLISHED DRAUGHT IS NOT THIS HULL'S DRAUGHT, and getting that wrong is the single likeliest way to ruin the
## boat. 28 in under an 8.2 m hard-chine planing hull is the bottom of the propeller or the rudder shoe, not the bottom
## of the planking. What says so is a boat neither source was comparing with: Wikipedia's Gar Wood Speedster, a
## contemporary American mahogany runabout by a different builder, publishes 16 ft x 5.4 ft x 1.4 ft draught. As a
## fraction of length that is 0.0875 against this boat's 0.0864 -- 1.3 per cent apart, from two references that never
## saw each other -- which says both are measured to the running gear. So `DRAUGHT` below is the CANOE BODY, an
## ESTIMATE at a little under half the published figure, and the published 0.711 m is carried as `GEAR_DRAUGHT` for
## whatever later hangs a shaft and a rudder under her.
##
## THE ENGINE SITS BETWEEN THE MIDDLE AND THE AFT COCKPITS, which is the opposite of what this lane was briefed and is
## what every source says ([SO], and [S] is consistent). It is also what makes the type recognisable: the long unbroken
## run of deck on a triple-cockpit runabout is AFT of the two forward cockpits, not forward of them, and a boat drawn
## the other way round reads as an ordinary two-cockpit utility with a hole in its foredeck.
##
## FRAME: origin amidships on the design waterline, +X starboard, -Z to the bow, as every boat here.

## The deck's thickness. A wooden deck, not a ship's plate, so it is thinner than `SmallCraftDraft.PLATE`.
const PLATE: float = 0.06

## PUBLISHED [S]: Sierra Boat Company's 1934 Custom 309 -- "27' long and 7' 2" wide and has a 28" draft".
const LENGTH: float = 8.230
const BEAM: float = 2.184
## PUBLISHED [S], and NOT the hull's -- see the doc block. Kept because it is the real figure and something will want it.
const GEAR_DRAUGHT: float = 0.711
## ESTIMATE: the canoe body, reasoned from the two references' agreeing draught-to-length ratios saying the published
## figure is to the running gear. Nothing is checked against this.
const DRAUGHT: float = 0.34
## ESTIMATE: freeboard amidships. The photographs cannot settle it -- none of the three reference boats' lengths is
## published, so there is no scale to measure a freeboard at -- and `sources.md` records the attempt and why it failed
## rather than leaving a number that looks measured.
const FREEBOARD: float = 0.50
## ESTIMATE: how far the sheer rises at the stem and at the transom over its height amidships. A runabout's sheer sweeps
## up forward and is very nearly flat aft, which is the whole line of the boat.
const SHEER := Vector2(0.29, 0.05)

## ESTIMATE: mass. No weight or displacement is published for any pre-war Chris-Craft runabout that this session could
## read -- see `sources.md`, "What could not be found at all". Reasoned from the hull's volume to the chine at the
## published double-planked mahogany-on-white-oak construction, plus an engine of the period.
const MASS: float = 2050.0

## THE ARRANGEMENT, bow to stern, as fractions of the length from the stem. PUBLISHED as an ORDER [SO] -- helm forward
## behind the windscreen, then the middle cockpit, then the engine, then the aft cockpit -- and ESTIMATED as lengths,
## because no free-licensed photograph of a triple-cockpit boat was found to measure them off. Each row is
## [name, from, to].
const ARRANGEMENT: Array = [
	["foredeck", 0.000, 0.287],
	["helm", 0.287, 0.427],
	["middle", 0.445, 0.585],
	["engine", 0.600, 0.795],
	["aft", 0.795, 0.922],
	["quarterdeck", 0.922, 1.000],
]

## How wide a cockpit opening is, as a fraction of the half-beam there: what is left after the side decks, which on a
## boat of this type are generous and are most of why it reads as a runabout rather than as an open boat.
const COCKPIT_WIDE: float = 0.66
## How far a cockpit's sole sits below the deck, and how far its coaming stands above it.
const SOLE_BELOW: float = 0.42
const COAMING: float = 0.055


## THE BOAT'S OWN DICTIONARY, `kind_geometry(n)` as it will be.
static func geometry() -> Dictionary:
	var half: float = BEAM * 0.5
	var bow: float = -LENGTH * 0.5
	var stern: float = LENGTH * 0.5
	var deck: float = FREEBOARD
	var parts: Array = []
	# THE HULL IN THREE PARTS, as every boat here: a fine entry, a full middle, and a transom that stays wide because
	# the after sections of a planing hull have to be flat to lift. The forefoot's plan is drawn round, not chopped:
	# a Chris-Craft's stem is a raked curve with a chrome cutwater down it, and a vee cut straight to a point reads as
	# a dinghy.
	#
	# THE FORWARD PART ENDS AT THE FULL BEAM AND NOT SHORT OF IT. It ended at 1.02 where the middle part begins at
	# 1.092, while `half_beam_at` -- which every drawn thing asks -- interpolated to 1.092 at that same station. So
	# for the metre before the parts met, the DRAWN hull stood 7 cm outside the shape that collides and floats. No
	# check here could see it: `no_deck_plank_hangs_over_her_side` compares the deck against the drawn SKIN, and the
	# skin and the deck were both wrong together. It was found by writing the C++ shape and having to say what the
	# plan actually is.
	var fore := PackedVector2Array([
		Vector2(-0.03, bow), Vector2(0.03, bow), Vector2(0.40, bow + 0.62), Vector2(0.78, bow + 1.36),
		Vector2(half, bow + 2.36), Vector2(-half, bow + 2.36), Vector2(-0.78, bow + 1.36),
		Vector2(-0.40, bow + 0.62)])
	var middle := PackedVector2Array([Vector2(-half, bow + 2.36), Vector2(half, bow + 2.36),
		Vector2(half, stern - 1.52), Vector2(-half, stern - 1.52)])
	# THE TRANSOM IS 0.86 OF THE BEAM and rounded at its corners, which is what a runabout's is; a full-beam square
	# transom belongs on a workboat.
	var aft := PackedVector2Array([
		Vector2(half, stern - 1.52), Vector2(half, stern - 0.52), Vector2(half * 0.86, stern),
		Vector2(-half * 0.86, stern), Vector2(-half, stern - 0.52), Vector2(-half, stern - 1.52)])
	for outline in [fore, middle, aft]:
		parts.append(_part("hull", outline, -DRAUGHT, deck - PLATE))
		parts.append(_part("deck", outline, deck - PLATE, deck))
	# THE THREE COCKPITS AS WELLS IN THE DECK, not as houses standing on it. Nothing else in this game is shaped like
	# this: every other boat's helm is a room with walls and a roof, and a runabout's is a hole with a bench in it. The
	# forward one is the `bridge`, because it is where the wheel is; the other two are `station`s, which is what an
	# open position with no controls is called here.
	var helm: Dictionary = {}
	for row in ARRANGEMENT:
		var name: String = String(row[0])
		if name == "foredeck" or name == "quarterdeck" or name == "engine":
			continue
		var from: float = bow + LENGTH * float(row[1])
		var to: float = bow + LENGTH * float(row[2])
		var well: Dictionary = _box(("bridge" if name == "helm" else "station"), 0.0, (from + to) * 0.5,
			_cockpit_half(from, to, half), (to - from) * 0.5, deck - SOLE_BELOW, deck + COAMING)
		well["cockpit"] = name
		parts.append(well)
		if name == "helm":
			helm = well
	var middle_well: Dictionary = _well_named(parts, "middle")
	var aft_well: Dictionary = _well_named(parts, "aft")
	# THE HELM IS TO STARBOARD, and two of the three reference photographs agree on it: in both, the bow is to the
	# right of the frame, which is the starboard side, and the driver is at the near side of the boat with the wheel
	# in front of them. It also happens to be what every other boat here does (`Launch`, 0.40 m to starboard).
	var seats: Array = [
		seat_in(helm, 0.38, 0.30, 0.0, "pilot"),
		seat_in(helm, -0.38, 0.30, 0.0, "copilot"),
		seat_in(middle_well, 0.38, 0.30, 0.0, "operator"),
		seat_in(aft_well, 0.00, 0.28, 0.0, "operator"),
	]
	return finish({"name": "runabout", "model_name": "boat", "mass": MASS, "pilotable": true,
		"waterline": 0.0, "seat_poses": seats, "parts": parts})


## THE HALF-WIDTH OF A COCKPIT OPENING between two stations: `COCKPIT_WIDE` of the hull's half-width at the NARROWER
## of the two ends, so the opening is inside the deck at both ends of itself. Taken at the middle instead, the forward
## cockpit's opening ran outboard of the sheer at its forward end, where the boat is still narrowing.
static func _cockpit_half(from: float, to: float, half: float) -> float:
	return minf(half_beam_at(from), half_beam_at(to)) * COCKPIT_WIDE


## THE HULL'S HALF-WIDTH AT A STATION, from the plan outline the parts are built on rather than from a second copy of
## it. Everything that has to sit inside the deck asks this, so there is one answer to "how wide is she here".
static func half_beam_at(z: float) -> float:
	var half: float = BEAM * 0.5
	var bow: float = -LENGTH * 0.5
	var stern: float = LENGTH * 0.5
	var full_from: float = bow + 2.36
	var full_to: float = stern - 1.52
	if z <= bow:
		return 0.03
	if z < full_from:
		# The three drawn forward stations, interpolated: the same points `geometry()` builds `fore` from.
		var stations: Array = [[bow, 0.03], [bow + 0.62, 0.40], [bow + 1.36, 0.78], [full_from, half]]
		for i in range(stations.size() - 1):
			var a: Array = stations[i]
			var b: Array = stations[i + 1]
			if z <= float(b[0]):
				return lerpf(float(a[1]), float(b[1]), (z - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-6))
		return half
	if z <= full_to:
		return half
	if z >= stern:
		return half * 0.86
	if z <= stern - 0.52:
		return half
	return lerpf(half, half * 0.86, (z - (stern - 0.52)) / 0.52)


## HOW FAR THE SHEER STANDS ABOVE ITS HEIGHT AMIDSHIPS AT A STATION: a parabola in each half, which is the same curve
## `HullLoft.build` raises its top row by, asked here so the deck planking, the coamings and the fittings all sit on
## ONE sheer line rather than on four copies of one.
static func sheer_rise_at(z: float) -> float:
	var t: float = clampf((z + LENGTH * 0.5) / LENGTH, 0.0, 1.0)
	var from_mid: float = absf(t - 0.5) * 2.0
	return (SHEER.x if t < 0.5 else SHEER.y) * from_mid * from_mid


## THE COCKPIT WELL WITH THAT NAME, out of the parts the geometry just built.
static func _well_named(parts: Array, which: String) -> Dictionary:
	for part in parts:
		if String(part.get("cockpit", "")) == which:
			return part
	return {}


static func _part(role: String, outline: PackedVector2Array, bottom: float, top: float) -> Dictionary:
	return {"part": role, "solid": role != "bridge" and role != "station", "bottom": bottom, "top": top,
		"outline": outline}


static func _box(role: String, x: float, z: float, hx: float, hz: float, bottom: float, top: float) -> Dictionary:
	return _part(role, PackedVector2Array([Vector2(x - hx, z - hz), Vector2(x + hx, z - hz),
		Vector2(x + hx, z + hz), Vector2(x - hx, z + hz)]), bottom, top)


static func seat_in(room: Dictionary, across: float, aft: float, yaw: float, station: String) -> Dictionary:
	return CrudeCarrierDraft.seat_in(room, across, aft, yaw, station)


static func finish(geometry: Dictionary) -> Dictionary:
	return SmallCraftDraft.finish(geometry)
