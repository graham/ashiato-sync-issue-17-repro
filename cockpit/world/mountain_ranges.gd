extends RefCounted
class_name MountainRanges
## THE ISLAND'S MOUNTAINS, AS DATA: every range's ridge line, its crests and its feet, and the envelope each is held in --
## the numbers `MountainRange` (ashiato-gd/src/cockpit/range_core.hpp) turns into the triangles that are both what is drawn
## and what is hit. Written here and nowhere else.
##
## A RANGE is a ridge through a few control points, each `Vector4i(x, z, crest, foot)` in whole metres: where the ridge
## passes, the crest's height there before the noise, and how far out the foot reaches either side. Its ENVELOPE is `peak`,
## the highest any crest may stand, and `saddle`, the lowest. A LONE MOUNTAIN is a range with one point; its spurs radiate.
##
## THE RING is not typed point by point but worked out from a few numbers: RING_ARCS ranges round the island, each a spline
## along the circle, with a PASS between each two -- on the bearings in RING_PASSES, three of which carry the fires that
## stood out towards the ring, so a fire there burns in a pass rather than punching a crater in a ridge. A pass is low
## ground you fly through, the thing the old ring's gaps between peaks were for; `tests/smoke.gd` measures the tightest.
##
## WHAT IT REPLACED (cockpit-mountains, 2026-09-18): thirty ring peaks and eighteen inland ones, each a stack of boxes --
## 583 boxes, the "stepped pyramid" look the user asked to be rid of. See `Terrain` and range_core.hpp for why the new shape
## is triangles rather than a skin over the boxes.
##
## CHANGING A NUMBER HERE CHANGES THE ISLAND ON EVERY PEER THAT RUNS THIS FILE, exactly as a change to `Terrain` does, and
## moves the hash `tests/mountains.gd` records.

## Metres between the grid's vertices before the jitter, and quads a side of a tile: 48 m facets, 1,920 m tiles.
const SPACING: int = 48
const TILE_QUADS: int = 40

## THE PHYSICAL SIZE OF A TILE, metres, which is the constant and not the quad count. A tile is a draw call and a
## culling unit, and how much world it holds should not change because somebody asked for finer rock -- so when the
## spacing moves, the quads a side move with it and the tile stays 1,920 m (`tile_quads_for`).
const TILE_METRES: int = SPACING * TILE_QUADS

## WHAT A LEVEL MAY ASK FOR, metres between vertices. The triangle count goes as the INVERSE SQUARE of this, so the
## ends of this range are 16 times apart: at 24 m the island's ranges are four times the triangles they are at 48, and
## at 96 a quarter of them. Below 12 m a range of this size stops being a picture and starts being a memory budget;
## above 192 the facets are wider than the ridges they are meant to shape.
const SPACING_LEAST: int = 12
const SPACING_MOST: int = 192


## QUADS A SIDE OF A TILE AT A SPACING, so a tile holds `TILE_METRES` of world whatever the rock's quality is. At the
## default spacing this is exactly `TILE_QUADS`, so a level that asks for nothing gets the rock it always had.
static func tile_quads_for(spacing: int) -> int:
	return maxi(int(round(float(TILE_METRES) / float(maxi(spacing, 1)))), 4)

## THE RING: how many ranges, round what radius, and how far a control point wanders in or out of it.
const RING_ARCS: int = 6
const RING_RADIUS: float = 5250.0
const RING_WANDER: float = 260.0
## Control points in each arc, end to end.
const RING_POINTS: int = 5
## THE PASSES, compass-style bearings in degrees from +x towards +z, and how wide each is as an angle between the two arcs'
## end points. The fires at bearings 219, 348 and 48 stand in three of them.
const RING_PASSES: Array[float] = [48.0, 108.0, 165.0, 219.0, 285.0, 348.0]
const RING_PASS_DEGREES: float = 16.0
## How far a hash moves each control point's crest, as a share of that arc's own middle crest.
const RING_CREST_WANDER: float = 0.21

## EACH ARC ITS OWN KIND OF MOUNTAIN. Until 2026-09-19 all six were one formula with a different salt -- one crest lerp,
## one foot lerp, one envelope -- and `tests/ridge_variety.gd` found what that cost: as a share of its own crest, every
## range on the island fell away from its ridge through the same seven numbers, agreeing across the eleven to within 4%,
## and from beside the runway the ring read as an even rampart right across the horizon. So each arc is typed now:
##
##   `peak`, `saddle`  its envelope: the highest and the lowest its crest may stand.
##   `crest`           the crest along its middle and at its two ends, metres. The ends are where the passes are.
##   `foot`            how far the foot reaches out, likewise. A small foot under a big crest is a blade; a big foot
##                     under a small crest is a swell of hills. THE RATIO IS THE CHARACTER, not either number -- and
##                     THE FEET ARE PENNED IN FROM BOTH SIDES, 560 m to 760 m, and the character comes mostly from the
##                     crest and the envelope instead. Wider than 760 and the ring's outer edge reaches Cape
##                     International, which sits OUTBOARD of it: the first go put the swells at 1,060 m and
##                     `tests/airport.gd` caught rock 113 m through 09/27's glide path 4.2 km out. Narrower than about
##                     560 and the ring stops being continuous: the second go cut the blade to 380 m and
##                     `Terrain.ring_gaps` found a 23 m sliver of clear bearings where there should be mountain, which
##                     `smoke` reads as a pass and wants over 120 m. Both were measured on 2026-09-19.
##   `wander`          how far its control points wander in and out of the circle, metres.
##
## WHERE EACH KIND IS. The low broad ones are north and north-east, over Cape International and the railway, where a
## pilot wants to see across rather than up; the tall and the narrow ones are east, south and west. The massif stands on
## the west arc, over open sea.
##
## HEIGHT WAS NOT WHAT THREATENED THE AIRPORT -- BREADTH WAS, and it cost two goes to learn. Cape International sits
## OUTBOARD of the ring, at about 8.4 km from the middle against the ring's 5.25 km, so what reaches it is the ring's
## outer edge, which is set by the FOOT and not by the crest. Moving the island's 820 m massif off the north-east arc
## changed `tests/airport.gd`'s reading by one metre; bringing every foot back under the old ring's 760 m is what
## cleared it. See `foot` above.
const RING_CHARACTER: Array[Dictionary] = [
	# 56 to 100 -- A LOW BROAD SWELL, barely a mountain: hills three times as wide as they are tall, which a light
	# aeroplane climbs over rather than turning round. The island's north-eastern inland range stands inside it.
	{"peak": 330, "saddle": 70, "crest": Vector2(240.0, 120.0), "foot": Vector2(700.0, 430.0), "wander": 300.0},
	# 116 to 157 -- A KNOT: high, broad, and wandering far in and out of the circle. RING_BRANCHES hangs an arm off its
	# middle, so it reads as a massif with ridges leaving it rather than as a piece of a circle. The main runway looks
	# across the island at it, and NOTHING LANDS OVER IT -- see the note on approaches above.
	{"peak": 700, "saddle": 190, "crest": Vector2(530.0, 290.0), "foot": Vector2(760.0, 440.0), "wander": 300.0},
	# 173 to 211 -- THE HIGH MASSIF, the island's roof: tall, and narrow for its height, so it stands up instead of
	# spreading. The one arc that reads as a mountain rather than as high ground, and it stands over open sea.
	{"peak": 820, "saddle": 210, "crest": Vector2(660.0, 300.0), "foot": Vector2(640.0, 380.0), "wander": 260.0},
	# 227 to 277 -- THE LONG EVEN RIDGE, nearest to what the whole ring used to be, kept deliberately so the island
	# still has one of them to compare the others against. It is the low one here because CAPE INTERNATIONAL'S 09/27
	# FINAL CROSSES IT: the approach runs 4.1 km out from a threshold on the far side of the island and passes over
	# this arc's outer flank at about 5.8 km from the middle, bearing 266 (`tests/ridge_culprit.gd`).
	{"peak": 540, "saddle": 160, "crest": Vector2(410.0, 230.0), "foot": Vector2(720.0, 420.0), "wander": 220.0},
	# 293 to 340 -- FOOTHILLS, AND THEY ARE FOOTHILLS BECAUSE CAPE INTERNATIONAL IS OUT HERE. The cape stands at about
	# 8.4 km from the middle, OUTBOARD of the ring's 5.25 km, and this arc's far end is the last rock before its
	# runways: low crest, low envelope and a tight wander, so nothing of it reaches the glide paths. See the note above.
	{"peak": 400, "saddle": 90, "crest": Vector2(300.0, 160.0), "foot": Vector2(700.0, 430.0), "wander": 200.0},
	# 356 to 40 -- A BLADE, as tall as the old ring and little more than half as wide, so its flanks stand at the angle
	# the profile wants rather than the angle a wide foot forces on them.
	{"peak": 620, "saddle": 150, "crest": Vector2(480.0, 190.0), "foot": Vector2(560.0, 330.0), "wander": 180.0},
]

## THE BRANCH RIDGES: a ridge that leaves a parent range at a knot and runs inland. This is what the relief from above
## said was missing -- every range was a lens with a spine and even barbs down both sides, none branched, none met
## another (2026-09-19, `tests/ridge_relief.gd`). A branch SHARES its parent's control point, and the generator takes
## the HIGHEST range at any point, so the two join into one massif at the knot rather than standing apart.
##
## `{parent, at, bearing, length, crest, foot, peak, saddle}`: which arc it leaves and from which of that arc's control
## points, the bearing it runs off on (degrees from +x towards +z), how far, its crest and foot at the knot and at its
## far end, and its envelope. TYPED, NOT HASHED, so that a branch runs inland and never out to sea.
const RING_BRANCHES: Array[Dictionary] = [
	# Off the high massif, north-east into the middle of the island: the massif's inland arm.
	{"parent": 2, "at": 2, "bearing": 12.0, "length": 2300.0, "crest": Vector2(540.0, 250.0),
		"foot": Vector2(520.0, 340.0), "peak": 700, "saddle": 150},
	# Off the knot, south-east: the arm that makes it a knot instead of a piece of a circle.
	{"parent": 1, "at": 2, "bearing": 318.0, "length": 1900.0, "crest": Vector2(430.0, 200.0),
		"foot": Vector2(600.0, 380.0), "peak": 620, "saddle": 130},
	# A short shoulder off the long even ridge, so it is not even all the way along.
	{"parent": 3, "at": 1, "bearing": 68.0, "length": 1250.0, "crest": Vector2(330.0, 160.0),
		"foot": Vector2(420.0, 280.0), "peak": 520, "saddle": 110},
]
## Control points along a branch, and the salts branches take, clear of the arcs' own.
const BRANCH_POINTS: int = 3
const RING_BRANCH_SALT: int = 4150
const INLAND_BRANCH_SALT: int = 4250

## THE INLAND RANGES, one on each of `Terrain.INLAND_RANGES`' centres: a ridge this long, at these bearings (degrees from
## +x towards +z), with these crests and feet. Chosen, not hashed: each runs along the ring rather than at it, so between
## an inland range and the ring there is a valley to fly down, and the first hashed bearings ran the south-western range
## into the ring's north-western arc (2026-09-18 hillshade).
const INLAND_BEARINGS: Array[float] = [230.0, 132.0, 330.0]
## EACH INLAND RANGE ITS OWN KIND TOO, on the ring arcs' four keys and three of its own: how long it runs, how many
## control points it runs through and how far off straight it bends. The three were one formula and one envelope until
## 2026-09-19; see RING_CHARACTER for why that had to go.
const INLAND_CHARACTER: Array[Dictionary] = [
	# SOUTH-WEST -- a long low ridge on a broad foot: the one an aeroplane crosses rather than flies round.
	{"peak": 430, "saddle": 110, "crest": Vector2(330.0, 180.0), "foot": Vector2(880.0, 560.0),
		"length": 4200.0, "points": 5, "bend": 760.0},
	# NORTH-EAST -- a compact high massif, short and steep, with INLAND_BRANCHES' arm off it.
	{"peak": 760, "saddle": 220, "crest": Vector2(600.0, 330.0), "foot": Vector2(640.0, 400.0),
		"length": 2600.0, "points": 4, "bend": 420.0},
	# NORTH -- a narrow blade bent hard, so it shows a face from one side and an edge from the other.
	{"peak": 560, "saddle": 140, "crest": Vector2(450.0, 240.0), "foot": Vector2(430.0, 280.0),
		"length": 3400.0, "points": 4, "bend": 900.0},
]
## The branch off the north-eastern massif, as RING_BRANCHES are but hung on an inland range.
const INLAND_BRANCHES: Array[Dictionary] = [
	{"parent": 1, "at": 1, "bearing": 42.0, "length": 1700.0, "crest": Vector2(470.0, 220.0),
		"foot": Vector2(500.0, 330.0), "peak": 640, "saddle": 130},
]
## The envelope anything asks for that has none of its own; nothing on the island uses it now.
const INLAND_PEAK: int = 620
const INLAND_SADDLE: int = 170

## THE LONE MOUNTAINS: where, and how tall and wide. Each keeps the inland envelope's top.
## The second stands where the railway runs past its foot, which it does in a cutting (`Terrain`'s rail keep-outs).
## `Vector4i(x, z, crest, foot)` each, with its own envelope beside it in LONE_ENVELOPE -- `Vector2i(peak, saddle)` --
## so the two are not one cone drawn twice: the first is a steep horn on a tight foot, the second a wide low dome.
const LONE: Array[Vector4i] = [Vector4i(1500, -3700, 430, 520), Vector4i(-600, 3900, 250, 700)]
const LONE_ENVELOPE: Array[Vector2i] = [Vector2i(620, 180), Vector2i(330, 80)]

## Salts, one a range, clear of `Terrain`'s own.
const RING_SALT: int = 4100
const INLAND_SALT: int = 4200
const LONE_SALT: int = 4300


## EVERY RANGE, as `MountainRange.configure` takes them: `{salt, peak, saddle, points}`, points four ints a point.
static func ranges() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for arc in range(RING_ARCS):
		out.append(_ring_arc(arc))
	for b in range(RING_BRANCHES.size()):
		out.append(_branch(RING_BRANCHES[b], _ring_arc(int(RING_BRANCHES[b]["parent"])), RING_BRANCH_SALT + b))
	for r in range(Terrain.INLAND_RANGES.size()):
		out.append(_inland(r))
	for b in range(INLAND_BRANCHES.size()):
		out.append(_branch(INLAND_BRANCHES[b], _inland(int(INLAND_BRANCHES[b]["parent"])), INLAND_BRANCH_SALT + b))
	for k in range(LONE.size()):
		var lone: Vector4i = LONE[k]
		var envelope: Vector2i = LONE_ENVELOPE[k]
		out.append({"salt": LONE_SALT + k, "peak": envelope.x, "saddle": envelope.y,
			"points": PackedInt32Array([lone.x, lone.y, lone.z, lone.w])})
	return out


## EVERY RING ARC'S CONTROL POINTS AT THEIR CRESTS, as world points: where the ring's ridge is highest before the noise --
## for the ridge lift, which stands off them, and for a suite that wants a leg through rock.
static func ring_crests() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for arc in range(RING_ARCS):
		var points: PackedInt32Array = _ring_arc(arc)["points"]
		for k in range(0, points.size(), 4):
			out.append(Vector3(float(points[k]), float(points[k + 2]), float(points[k + 1])))
	return out


## HOW NEAR THE MIDDLE THE RING'S ROCK CAN REACH, metres: the least of every ring control point's distance from the middle
## less the farthest its foot can stand out (1.175 feet, range_core.hpp). For anything kept inside the ring, as the woods.
static func ring_inside() -> float:
	var inside: float = INF
	for arc in range(RING_ARCS):
		var points: PackedInt32Array = _ring_arc(arc)["points"]
		for k in range(0, points.size(), 4):
			inside = minf(inside, Vector2(float(points[k]), float(points[k + 1])).length() - float(points[k + 3]) * 1.175)
	return inside


## ONE ARC OF THE RING, from the pass before it to the pass after it: RING_POINTS along the circle, the crest highest in the
## middle and lowest at the ends, which are where the passes are.
static func _ring_arc(arc: int) -> Dictionary:
	var from: float = RING_PASSES[arc] + RING_PASS_DEGREES * 0.5
	var to: float = RING_PASSES[(arc + 1) % RING_PASSES.size()] - RING_PASS_DEGREES * 0.5
	if to < from:
		to += 360.0
	var salt: int = RING_SALT + arc
	var kind: Dictionary = RING_CHARACTER[arc]
	var its_crest: Vector2 = kind["crest"]
	var its_foot: Vector2 = kind["foot"]
	var points := PackedInt32Array()
	for k in range(RING_POINTS):
		var share: float = float(k) / float(RING_POINTS - 1)
		var bearing: float = deg_to_rad(lerpf(from, to, share))
		# THE MIDDLE OF THE ARC stands tallest and widest: 0 at the ends, 1 in the middle.
		var middle: float = sin(share * PI)
		var radius: float = RING_RADIUS + (Terrain.hash01(salt, 10 + k) - 0.5) * 2.0 * float(kind["wander"])
		# THE CREST WANDER IS A SHARE OF THE ARC'S OWN CREST, so a low arc is not given a tall arc's wander in metres:
		# typed in metres it moved the east swell's 240 m crest by 90 and its character with it.
		var crest: float = lerpf(its_crest.y, its_crest.x, middle) + (Terrain.hash01(salt, 20 + k) - 0.5) * 2.0 \
			* RING_CREST_WANDER * its_crest.x * middle
		var foot: float = lerpf(its_foot.y, its_foot.x, middle)
		points.append_array([roundi(cos(bearing) * radius), roundi(sin(bearing) * radius), roundi(crest), roundi(foot)])
	return {"salt": salt, "peak": int(kind["peak"]), "saddle": int(kind["saddle"]), "points": points}


## HOW FAR THE `r`th INLAND RANGE'S FOOT REACHES at its widest, metres. Asked by anything stood off that range --
## `Terrain`'s inland thermals stand 1.2 feet out from the ridge -- so the answer comes from the range's own character
## rather than from a second copy of the number, which is what INLAND_FOOT was before the three ranges differed.
static func inland_foot(r: int) -> float:
	return (INLAND_CHARACTER[clampi(r, 0, INLAND_CHARACTER.size() - 1)]["foot"] as Vector2).x


## ONE BRANCH RIDGE, leaving `parent` at its `at`th control point and running off on its bearing. IT STARTS ON THE
## PARENT'S OWN POINT, at the parent's crest and foot there, so the two ranges agree exactly where they meet and the
## generator's max-of-ranges joins them into one massif instead of leaving a step between two mountains.
static func _branch(branch: Dictionary, parent: Dictionary, salt: int) -> Dictionary:
	var of_parent: PackedInt32Array = parent["points"]
	var knot: int = clampi(int(branch["at"]), 0, of_parent.size() / 4 - 1)
	var from := Vector2(float(of_parent[4 * knot]), float(of_parent[4 * knot + 1]))
	var bearing: float = deg_to_rad(float(branch["bearing"]))
	var along := Vector2(cos(bearing), sin(bearing))
	var its_crest: Vector2 = branch["crest"]
	var its_foot: Vector2 = branch["foot"]
	var points := PackedInt32Array()
	for k in range(BRANCH_POINTS):
		var share: float = float(k) / float(BRANCH_POINTS - 1)
		var at: Vector2 = from + along * share * float(branch["length"])
		# THE KNOT TAKES THE PARENT'S OWN CREST AND FOOT, so neither range steps over the other where they join; from
		# there the branch falls away to its own far end.
		var crest: float = float(of_parent[4 * knot + 2]) if k == 0 else lerpf(its_crest.x, its_crest.y, share)
		var foot: float = float(of_parent[4 * knot + 3]) if k == 0 else lerpf(its_foot.x, its_foot.y, share)
		points.append_array([roundi(at.x), roundi(at.y), roundi(crest), roundi(foot)])
	return {"salt": salt, "peak": int(branch["peak"]), "saddle": int(branch["saddle"]), "points": points}


## ONE INLAND RANGE, through its centre at a bearing the hash gives it.
static func _inland(r: int) -> Dictionary:
	var salt: int = INLAND_SALT + r
	var kind: Dictionary = INLAND_CHARACTER[r]
	var its_crest: Vector2 = kind["crest"]
	var its_foot: Vector2 = kind["foot"]
	var count: int = int(kind["points"])
	var centre: Vector3 = Terrain.INLAND_RANGES[r]
	var bearing: float = deg_to_rad(INLAND_BEARINGS[r])
	var along := Vector2(cos(bearing), sin(bearing))
	var aside := Vector2(-along.y, along.x)
	var points := PackedInt32Array()
	for k in range(count):
		var share: float = float(k) / float(count - 1)
		var middle: float = sin(share * PI)
		# A LITTLE OFF STRAIGHT, so a range bends -- by its own `bend`, which is what makes one of the three a blade
		# bent hard and another a long easy ridge.
		var at: Vector2 = Vector2(centre.x, centre.z) + along * (share - 0.5) * float(kind["length"]) \
			+ aside * (Terrain.hash01(salt, 10 + k) - 0.5) * float(kind["bend"])
		var crest: float = lerpf(its_crest.y, its_crest.x, middle)
		var foot: float = lerpf(its_foot.y, its_foot.x, middle)
		points.append_array([roundi(at.x), roundi(at.y), roundi(crest), roundi(foot)])
	return {"salt": salt, "peak": int(kind["peak"]), "saddle": int(kind["saddle"]), "points": points}
