extends RefCounted
class_name Watercourse
## A LEVEL'S RIVERS, AND WHAT A CANYON IS MADE OF (lane/rivers, 2026-09-20). One declaration in the level file becomes
## three things that must agree, and this is the only place that works out how:
##
##   THE BED AND THE WATER, cut by the ground function itself (`GroundField`'s `rivers`, ground_core.hpp). The keys it
##     takes are `points`, `width`, `corridor` and `draught`, and `ground_rivers` hands it exactly those.
##   THE CANYON'S WALLS, two ranges either side through `MountainRange`, whose crests are the river's OWN WATER LEVEL
##     plus the depth asked for -- read back off the ground function with `water_ticks_at`, never recomputed here.
##   THE CORRIDOR KEPT CLEAR, a chain of keep-outs along the centre line so no rock stands in the flyable floor.
##
## WHY THE DEPTH IS THE WALLS' AND NOT THE CUT'S. The user asked for canyons "200-300 metres deep ... and a high
## mountain on both sides". Cutting a 250 m slot into ground that stands 100 m above the sea puts its floor under the
## sea, and most of the generated lowland is under 130 m. So the ground cuts only enough to seat the water, and the
## DEPTH IS THE HEIGHT OF THE RIM OVER THE WATER. That is one number, and both the crest and the check read it.
##
## ONE NUMBER, ONE PLACE, and here that is the whole point of the file: the corridor is worked out from the river's
## width, the wall's offset and foot from the depth, the keep-out's floor from the water's own level. A level says how
## wide the water is and how deep the canyon is, and everything else is derived. A level that typed its corridor beside
## its width would be a level whose canyon could stop being flyable when somebody widened the river.

## The keys a level's river may have. `points` and nothing else is a legal river: every number has a default.
const KEYS: PackedStringArray = ["points", "width", "depth", "corridor", "draught"]
## The keys the ground function takes, which are the ones it needs to cut a bed. `depth` is not among them.
const GROUND_KEYS: PackedStringArray = ["points", "width", "corridor", "draught"]

## THE WATER'S WIDTH, metres, and what a level may ask for. 50 m is the user's number.
const WIDTH_DEFAULT: int = 50
const WIDTH := Vector2i(4, 600)
## THE CANYON'S DEPTH FROM ITS RIM TO THE WATER, metres, and what a level may ask for. 250 m is the middle of the
## user's "200-300 metres"; the range reaches either side of it so a map may have a gorge and a shallow valley both.
const DEPTH_DEFAULT: int = 250
const DEPTH := Vector2i(60, 1200)
## HOW DEEP THE WATER STANDS OVER ITS BED, metres.
const DRAUGHT_DEFAULT: int = 4

## HALF THE FLYABLE CORRIDOR, AS A MULTIPLE OF THE RIVER'S WIDTH. At 2.5 a 50 m river has 125 m of clear floor either
## side of its middle -- a 250 m gap between the walls, which against a 250 m depth is a canyon about as wide as it is
## deep. The one hard rule is that the corridor reaches past the water's own half-width, and that is checked in the
## ground function, because a corridor inside the water would fold the carve.
const CORRIDOR_WIDTHS: float = 2.5

## HOW FAR OUT THE RIDGE STANDS PER METRE OF DEPTH, and this number is NOT free. Rock may climb out of a keep-out at
## `Mountains::kClearRise`, six fifths of a metre a metre -- fifty degrees -- and no steeper, so a ridge put `depth`
## metres outside the corridor (a 45 degree wall) cannot be more than 1.2 x that run above the keep-out's edge no
## matter what crest it is given. That is what actually capped the first canyon: at 1.0 the mean rim was 191 m of a
## 260 m ask, and raising the crest from 1.3 x the depth to 1.6 x moved it only to 200 m, because the crest was never
## the binding constraint. At 1.35 the ridge stands far enough out that the talus reaches the crest before it does.
##
## THE FLOOR DOES NOT WIDEN WITH IT. The corridor is what is cut and the talus starts at its edge either way; moving
## the ridge out gives the canyon a wider rim, not a wider bottom.
const WALL_RUN_PER_RISE: float = 1.6

## HOW MUCH HIGHER THE RIDGE IS ASKED TO STAND THAN THE DEPTH WANTED. A `MountainRange` ridge is not a wall of a stated
## height: its crest carries noise inside its envelope, and between two control points it falls to a saddle and rises
## again. Asked for exactly the depth, the rim that came out measured 182 m of a 260 m canyon on the mean and 61 m at
## its worst (`tests/canyon.gd`, 2026-09-20). Asked for 1.3 times it, the same measurement is what the level asked for.
## The wall's OFFSET is still the depth, so the wall is a little steeper than 45 degrees rather than further out: a
## canyon wants a steep side, and moving the ridge out would have widened the gorge instead of deepening it.
const CREST_OVER_DEPTH: float = 1.3

## THE KEEP-OUTS ARE EXACTLY THE CORRIDOR'S WIDTH, AND A MARGIN WAS TRIED AND REJECTED (2026-09-20). What stands at the
## corridor's edge is not rock but the UNCUT GROUND: the carve stops at the corridor, so the natural hillside is still
## there, 44 to 122 m above the water at the stations that failed. Widening the keep-outs by one mountain spacing moved
## none of it -- the failing numbers came back identical to the metre -- and cost 16 m of the canyon's mean depth,
## because pushing the talus out lowers the rock everywhere the rim is measured. The cut floor IS the corridor and the
## walls rise from its edge, which is what a canyon is; the check measures the floor inside it.
const KEEPOUT_MARGIN: int = 0

## HOW FAR THE WALLS RUN PAST THE RIVER'S HEAD AND MOUTH, as a multiple of the depth. A `MountainRange` ridge tapers to
## nothing at its last control point, so walls that stopped exactly where the river's line stopped left the first and
## last stations with no wall at all: the rim at the head measured 9 m BELOW the water. A canyon does not stop dead at
## a waypoint, and two depths of overrun puts the taper outside the river.
const WALL_OVERRUN: float = 2.0

## HOW LONG A KEEP-OUT BOX IS ALONG THE RIVER, metres. A keep-out is an axis-aligned rectangle and a river is not, so a
## leg is covered by a chain of them, and what a chain of rectangles does to a diagonal is a staircase: at 120 m, with
## each box grown by the corridor's width in BOTH axes, the crenellation along the canyon's floor was about 25 m and
## read from the air as a saw blade down both sides (the first pictures of the gorge, 2026-09-20). Two things fixed it
## and neither costs anything visible: the box is the TIGHT bounds of that step's corridor rectangle rather than its
## centre line's bounds grown in both axes, and the step is 60 m.
const KEEPOUT_STEP: int = 60


## THE RIVERS A LEVEL DECLARES, AS THE GROUND FUNCTION TAKES THEM: only the keys it knows, with the corridor worked out
## from the width where the level did not say. Never `depth`, which the ground does not cut.
static func ground_rivers(rivers: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for one in rivers:
		var river: Dictionary = one
		var laid: Dictionary = {"points": river["points"]}
		laid["width"] = int(river.get("width", WIDTH_DEFAULT))
		laid["corridor"] = corridor_half(river)
		laid["draught"] = int(river.get("draught", DRAUGHT_DEFAULT))
		out.append(laid)
	return out


## HALF THE CLEAR FLOOR EITHER SIDE OF THE CENTRE LINE, metres: what the level asked for, or the river's width times
## `CORRIDOR_WIDTHS`. Never less than the water's own half-width plus a metre, which the ground function refuses.
static func corridor_half(river: Dictionary) -> int:
	var width: int = int(river.get("width", WIDTH_DEFAULT))
	if river.has("corridor"):
		return int(river["corridor"])
	return maxi(int(round(float(width) * CORRIDOR_WIDTHS)), width / 2 + 1)


## THE DEPTH FROM THE RIM TO THE WATER, metres.
static func depth_of(river: Dictionary) -> int:
	return int(river.get("depth", DEPTH_DEFAULT))


## HOW FAR OUT FROM THE CENTRE LINE A WALL'S RIDGE RUNS, metres: past the corridor by the depth, so a wall at
## `WALL_RUN_PER_RISE` to one reaches its crest where the ridge is.
static func wall_offset(river: Dictionary) -> int:
	return corridor_half(river) + int(round(float(depth_of(river)) * WALL_RUN_PER_RISE))


## THE WATER'S LEVEL AT A POINT, metres, read off the ground function itself -- the authority, so nothing here repeats
## the rule that a river runs downhill. NAN where the field says no water stands there.
static func water_level_at(field: Object, x: int, z: int) -> float:
	if field == null:
		return NAN
	var ticks: int = int(field.call("water_ticks_at", x, z))
	if ticks <= ClassDB.class_get_integer_constant("GroundField", "NO_WATER"):
		return NAN
	return float(ticks) / 32.0


## THE TWO RANGES EITHER SIDE OF EVERY RIVER, as `MountainRange` takes them and `LevelChart.mountains` holds them: a
## ridge offset `wall_offset` to each side of the centre line, every control point's crest the WATER'S OWN LEVEL there
## plus the depth. `field` must already be configured with these rivers, or there is no water to read and no wall.
static func ranges_for(rivers: Array, field: Object) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in range(rivers.size()):
		var river: Dictionary = rivers[r]
		var points: Array = river["points"]
		if points.size() < 2:
			continue
		var depth: int = depth_of(river)
		var offset: int = wall_offset(river)
		var foot: int = clampi(depth, 16, 8000)
		# THE LINE THE WALLS FOLLOW, run on past both ends so their taper falls outside the river (`WALL_OVERRUN`).
		var line: Array = []
		var head := Vector2(float(int(points[0][0])), float(int(points[0][1])))
		var second := Vector2(float(int(points[1][0])), float(int(points[1][1])))
		var mouth := Vector2(float(int(points[-1][0])), float(int(points[-1][1])))
		var penultimate := Vector2(float(int(points[-2][0])), float(int(points[-2][1])))
		var overrun: float = float(depth) * WALL_OVERRUN
		line.append([int(round((head - (second - head).normalized() * overrun).x)),
			int(round((head - (second - head).normalized() * overrun).y))])
		line.append_array(points)
		line.append([int(round((mouth + (mouth - penultimate).normalized() * overrun).x)),
			int(round((mouth + (mouth - penultimate).normalized() * overrun).y))])
		for side in [-1, 1]:
			var laid := PackedInt32Array()
			var tallest: int = 0
			var lowest: int = 1 << 30
			for k in range(line.size()):
				var at := Vector2(float(int(line[k][0])), float(int(line[k][1])))
				# THE LINE'S DIRECTION HERE, from the neighbours, so a corner's two legs share one normal and the wall
				# does not step across it.
				var ahead: Vector2 = at
				var behind: Vector2 = at
				if k + 1 < line.size():
					ahead = Vector2(float(int(line[k + 1][0])), float(int(line[k + 1][1])))
				if k > 0:
					behind = Vector2(float(int(line[k - 1][0])), float(int(line[k - 1][1])))
				var along: Vector2 = ahead - behind
				if along.length() < 0.001:
					continue
				along = along.normalized()
				var across := Vector2(-along.y, along.x) * float(side)
				var ridge: Vector2 = at + across * float(offset)
				# THE CREST IS THE WATER'S OWN LEVEL PLUS THE DEPTH, asked at the control point and not at the ridge:
				# the ridge stands over whatever the ground does out there, and what a canyon's depth is measured from
				# is the water in the bottom of it.
				var water: float = water_level_at(field, int(at.x), int(at.y))
				if is_nan(water):
					# AN OVERRUN POINT STANDS PAST THE WATER, so it takes the level of the river's own end it runs on
					# from: the wall keeps the height it had rather than collapsing where the river stops.
					var end := Vector2(float(int(points[0][0])), float(int(points[0][1]))) if k == 0 						else Vector2(float(int(points[-1][0])), float(int(points[-1][1])))
					water = water_level_at(field, int(end.x), int(end.y))
					if is_nan(water):
						continue
				var crest: int = int(round(water + float(depth) * CREST_OVER_DEPTH))
				tallest = maxi(tallest, crest)
				lowest = mini(lowest, crest)
				laid.append_array([int(round(ridge.x)), int(round(ridge.y)), crest, foot])
			if laid.size() < 8:
				continue
			# THE ENVELOPE IS THE CRESTS THEMSELVES, with a little room: a wall is not a range of peaks and saddles, it
			# is a wall, and an envelope wider than its crests would let the noise cut a notch through it -- which on a
			# canyon is a hole in the side a pilot can see daylight through.
			out.append({"points": laid, "peak": tallest + depth / 8, "saddle": maxi(lowest - depth / 8, 1),
				"salt": 7700 + r * 31 + (0 if side < 0 else 17)})
	return out


## THE KEEP-OUTS ALONG EVERY RIVER, five ints each as `Terrain.mountain_keepouts` holds them -- x0, z0, x1, z1 and the
## floor in ticks -- so no rock stands in the corridor the walls are built round. A chain of boxes along each leg,
## `KEEPOUT_STEP` apart, each the bounds of that step's corridor, floored at the water's level there.
##
## THE FLOOR IS THE WATER'S, NOT THE GROUND'S. Floored at the ground, the rock would be capped at whatever hummock
## happened to stand in the corridor and the wall would start from it; floored at the water, the corridor is clear all
## the way down to the river and the wall rises out of the keep-out's edge as a talus.
static func keepouts_for(rivers: Array, field: Object) -> PackedInt32Array:
	var out := PackedInt32Array()
	for one in rivers:
		var river: Dictionary = one
		var points: Array = river["points"]
		if points.size() < 2:
			continue
		var half: int = corridor_half(river) + KEEPOUT_MARGIN
		for k in range(points.size() - 1):
			var a := Vector2(float(int(points[k][0])), float(int(points[k][1])))
			var b := Vector2(float(int(points[k + 1][0])), float(int(points[k + 1][1])))
			var legs: int = maxi(int(ceil(a.distance_to(b) / float(KEEPOUT_STEP))), 1)
			for s in range(legs):
				var from: Vector2 = a.lerp(b, float(s) / float(legs))
				var to: Vector2 = a.lerp(b, float(s + 1) / float(legs))
				var water: float = water_level_at(field, int(round((from.x + to.x) * 0.5)),
					int(round((from.y + to.y) * 0.5)))
				if is_nan(water):
					continue
				# THE TIGHT BOUNDS OF THIS STEP'S CORRIDOR: its four corners, not the centre line's bounds grown by
				# the corridor in both axes. On a 45 degree leg the loose version reached 0.41 x the corridor further
				# out on each axis than the corridor goes, and that difference IS the staircase.
				var out_n: Vector2 = (to - from).normalized()
				var side_n := Vector2(-out_n.y, out_n.x) * float(half)
				var lo: Vector2 = Vector2(minf(from.x, to.x), minf(from.y, to.y)) - side_n.abs()
				var hi: Vector2 = Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + side_n.abs()
				out.append_array([int(floor(lo.x)), int(floor(lo.y)), int(ceil(hi.x)), int(ceil(hi.y)),
					int(round(water * 32.0))])
		# AND A SQUARE AT EVERY BEND. A chain of boxes along two legs leaves a wedge uncovered on the OUTSIDE of the
		# corner where they meet, and rock grew in it: `tests/canyon.gd` found 241 m of it standing in the corridor at
		# (-11825, 3362) with every leg covered. One square of the corridor's own width at each control point fills it,
		# and at a bend that is where a pilot is turning and least wants a wall.
		for k in range(points.size()):
			var on := Vector2(float(int(points[k][0])), float(int(points[k][1])))
			var water_here: float = water_level_at(field, int(round(on.x)), int(round(on.y)))
			if is_nan(water_here):
				continue
			out.append_array([int(on.x) - half, int(on.y) - half, int(on.x) + half, int(on.y) + half,
				int(round(water_here * 32.0))])
	return out
