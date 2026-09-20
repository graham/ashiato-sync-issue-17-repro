extends Node
## Headless: HOW MUCH DO THE ISLAND'S RANGES DIFFER FROM ONE ANOTHER? A measurement of the thing the eye complains about.
##
##   Godot --headless --path cockpit res://tests/ridge_variety.tscn
##
## THE USER'S COMPLAINT (2026-09-19) was that the mountains do not look varied or natural enough. The generator
## (ashiato-gd/src/cockpit/range_core.hpp) is already a spline generator with noise in it, so the question is not "is it
## generated" but "how far apart are the eleven ranges it generates". This probe asks the REAL LIBRARY -- the same
## `MountainRange` the island builds -- for each range on its own, and measures its CHARACTER:
##
## - THE CREST ALONG THE RIDGE: how tall, how rough, how many summits a kilometre and how far apart they stand.
## - THE FLANK ACROSS THE RIDGE: the height at each fraction of the way out to the foot, as a share of the crest. This is
##   the range's PROFILE, and two ranges with the same profile curve are the same mountain at different sizes.
## - THE TWO FLANKS AGAINST EACH OTHER: how differently a range falls one side from the other.
## - THE GULLIES: how many a kilometre cut the flank half way down, and how deep.
##
## Then the SPREAD of each of those across the eleven ranges. A spread near zero is the finding: every range is a
## different sample of ONE process, which reads as one mountain repeated however much the noise differs.
##
## The ridge line is re-sampled here in floats only to decide WHERE to look; every height read is the library's own, so
## nothing here is a tautology about a port.
##
## Read RESULT=, not the exit code. This probe PASSES whatever it measures -- it is a measurement, and the numbers are
## the point. The checks that HOLD these numbers belong with the change that moves them, not before it.

## Stations along each ridge, metres apart, and how many steps out to the foot each cross-section takes.
const STATION_METRES: float = 100.0
const FLANK_STEPS: int = 32
## The fractions of the way out to the foot the profile is reported at.
const PROFILE_AT: Array[float] = [0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875]
## A local maximum along the crest counts as a SUMMIT when it stands this far above the lower of the two saddles beside it.
const SUMMIT_PROMINENCE: float = 20.0
## A dip along a contour counts as a GULLY when it cuts this share of the relief along that contour. See `_cuts_in`.
const GULLY_SHARE: float = 0.25
## THE CONTOURS THE GULLIES ARE COUNTED ON, as fractions of the way out to the foot. Water gathers as it falls, so a
## real mountainside carries fewer and larger valleys at the bottom than at the top -- `range_core.hpp`'s kValleySizes
## -- and these three are how that is held.
##
## WHY NOT NEARER THE FOOT. The three were 0.25, 0.5 and 0.8 first, and the outermost counted nothing useful: four
## fifths of the way out the ground stands at about a thirtieth of the crest, where the flank's LUMP noise -- 12% of
## the height on a 160 m cell -- is bigger than any gully, and the counter dutifully read sixteen dips a circuit on a
## lone mountain with seven spurs. Gullies live between about a sixth and three fifths of the way out; that is where
## they are counted (2026-09-19).
const GULLY_CONTOURS: Array[float] = [0.2, 0.35, 0.55]

## How many gullies a flank's top contour must carry before its gathering is reported at all: a flank with three
## gullies on it gives a ratio that swings by a half on one count either way, and the two lone mountains have no ridge
## to count along at all.
const ENOUGH_GULLIES_TO_JUDGE: float = 6.0
## Samples of the spline between two control points, as range_core.cpp's kSteps.
const SPLINE_STEPS: int = 12

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[ridge_variety] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists(&"MountainRange"):
		_check("the_extension_has_mountains", false, "no MountainRange")
		_finish()
		return
	var every: Array[Dictionary] = []
	for one in MountainRanges.ranges():
		every.append(_character_of(one))
	_report(every)
	_finish()


func _finish() -> void:
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## ---- the ridge line, in floats, to decide where to look --------------------------------------------------------------

## ONE RANGE'S RIDGE, SAMPLED: [{at: Vector2, along: Vector2, foot: float}], the Catmull-Rom of `range_core.cpp` walked in
## floats. Only the PLACES are taken from here; every height is the library's.
static func _ridge_of(one: Dictionary) -> Array[Dictionary]:
	var points: PackedInt32Array = one["points"]
	var n: int = points.size() / 4
	var walk: Array[Dictionary] = []
	if n == 1:
		return walk
	for i in range(n - 1):
		var i0: int = 0 if i == 0 else i - 1
		var i3: int = mini(i + 2, n - 1)
		for k in range(SPLINE_STEPS):
			var t: float = float(k) / float(SPLINE_STEPS)
			walk.append({"at": Vector2(_spline(points, i0, i, i + 1, i3, 0, t), _spline(points, i0, i, i + 1, i3, 1, t)),
				"foot": _spline(points, i0, i, i + 1, i3, 3, t)})
		if i + 2 == n:
			walk.append({"at": Vector2(float(points[4 * (n - 1)]), float(points[4 * (n - 1) + 1])),
				"foot": float(points[4 * (n - 1) + 3])})
	# THE TANGENT AT EACH SAMPLE, from its neighbours.
	for k in range(walk.size()):
		var before: Vector2 = (walk[maxi(k - 1, 0)]["at"] as Vector2)
		var after: Vector2 = (walk[mini(k + 1, walk.size() - 1)]["at"] as Vector2)
		var along: Vector2 = after - before
		walk[k]["along"] = along.normalized() if along.length() > 0.0 else Vector2.RIGHT
	return walk


static func _spline(points: PackedInt32Array, a: int, b: int, c: int, d: int, which: int, t: float) -> float:
	var p0: float = float(points[4 * a + which])
	var p1: float = float(points[4 * b + which])
	var p2: float = float(points[4 * c + which])
	var p3: float = float(points[4 * d + which])
	if which >= 2:
		# The crest and the foot are carried straight between the two points, as range_core.cpp carries them.
		return p1 + (p2 - p1) * t
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)


## ---- one range's character ------------------------------------------------------------------------------------------

func _character_of(one: Dictionary) -> Dictionary:
	var alone: Object = ClassDB.instantiate(&"MountainRange")
	alone.call("configure", {"spacing": MountainRanges.SPACING, "tile_quads": MountainRanges.TILE_QUADS,
		"ranges": [one], "keepouts": PackedInt32Array()})
	var walk: Array[Dictionary] = _ridge_of(one)
	var lone: bool = walk.is_empty()
	if lone:
		# A LONE MOUNTAIN has no ridge: its stations are bearings round it, and "along the ridge" is round the summit.
		var points: PackedInt32Array = one["points"]
		var middle := Vector2(float(points[0]), float(points[1]))
		var foot: float = float(points[3])
		for k in range(48):
			var turn: float = TAU * float(k) / 48.0
			walk.append({"at": middle, "foot": foot, "along": Vector2(cos(turn), sin(turn))})
	var crests: PackedFloat32Array = []
	# THE PROFILE, summed over every station and both flanks; and the two flanks kept apart, to compare them.
	var profile: PackedFloat32Array = []
	profile.resize(FLANK_STEPS + 1)
	var profile_count: int = 0
	var asymmetry: float = 0.0
	var asymmetry_count: int = 0
	# THE CONTOURS, ONE LINE A CONTOUR AND A FLANK: the height there station by station along the ridge, from which the
	# gullies crossing that contour are counted. THE TWO FLANKS ARE KEPT APART. The first build put both in one array,
	# so consecutive entries alternated between the two sides of the mountain and every count was the alternation
	# rather than the gullies -- it read a steady 5 a km at every depth whatever the generator did (2026-09-19).
	var contours: Array[PackedFloat32Array] = []
	for _c in GULLY_CONTOURS:
		contours.append(PackedFloat32Array())
		contours.append(PackedFloat32Array())
	var half_way: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
	var steepest: float = 0.0
	var walked: float = 0.0
	var stations: Array[Dictionary] = []
	var last: Vector2 = walk[0]["at"]
	# A LONE MOUNTAIN's stations are its bearings, all at the same place, so every one of them is kept.
	if lone:
		stations.assign(walk)
	for k in range(0 if not lone else walk.size(), walk.size()):
		var at: Vector2 = walk[k]["at"]
		walked += at.distance_to(last)
		last = at
		if not stations.is_empty() and walked < STATION_METRES and k + 1 < walk.size():
			continue
		walked = 0.0
		stations.append(walk[k])
	for station in stations:
		var at: Vector2 = station["at"]
		var along: Vector2 = station["along"]
		var foot: float = station["foot"]
		var aside := Vector2(-along.y, along.x)
		var crest: float = float(alone.call("surface_at", at.x, at.y))
		if lone:
			crest = float(alone.call("surface_at", at.x, at.y))
		crests.append(crest)
		if crest < 1.0:
			continue
		var sides: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
		for s in range(2):
			var sign: float = 1.0 if s == 0 else -1.0
			for step in range(FLANK_STEPS + 1):
				var u: float = float(step) / float(FLANK_STEPS)
				var where: Vector2 = at + aside * sign * u * foot
				sides[s].append(float(alone.call("surface_at", where.x, where.y)))
		for s in range(2):
			# A LONE MOUNTAIN's second side is the same bearing again; only one flank is counted.
			if lone and s == 1:
				continue
			for step in range(FLANK_STEPS + 1):
				profile[step] += sides[s][step] / crest
			profile_count += 1
			half_way[s].append(sides[s][FLANK_STEPS / 2] / crest)
			for c in range(GULLY_CONTOURS.size()):
				# AS A SHARE OF THE CREST AT THIS STATION, which takes the ridge's own rise and fall out of the line:
				# without that, the relief along a contour is the crest's undulation -- a third of its height -- and a
				# gully six per cent deep never clears a threshold set against it (2026-09-19).
				contours[2 * c + s].append(sides[s][clampi(int(GULLY_CONTOURS[c] * float(FLANK_STEPS)), 0,
					FLANK_STEPS)] / crest)
			# THE STEEPEST FALL near the crest, over the first eighth of the way out, in degrees.
			var drop: float = sides[s][0] - sides[s][FLANK_STEPS / 8]
			var run: float = foot / 8.0
			steepest = maxf(steepest, rad_to_deg(atan2(maxf(drop, 0.0), run)))
		if not lone:
			asymmetry += absf(sides[0][FLANK_STEPS / 2] - sides[1][FLANK_STEPS / 2]) / crest
			asymmetry_count += 1
	for step in range(FLANK_STEPS + 1):
		profile[step] /= maxf(float(profile_count), 1.0)
	# THE SUMMITS along the crest, and the gullies along each contour, each flank counted on its own and the two added.
	var summits: Array[int] = _peaks_in(crests, SUMMIT_PROMINENCE)
	var gully_cuts: int = _cuts_in(half_way[0]) + (0 if lone else _cuts_in(half_way[1]))
	var by_contour := PackedFloat32Array()
	for c in range(GULLY_CONTOURS.size()):
		by_contour.append(float(_cuts_in(contours[2 * c]) + (0 if lone else _cuts_in(contours[2 * c + 1]))))
	var length: float = float(maxi(stations.size() - 1, 1)) * STATION_METRES
	var mean_crest: float = 0.0
	for c in crests:
		mean_crest += c
	mean_crest /= maxf(float(crests.size()), 1.0)
	var spread: float = 0.0
	for c in crests:
		spread += (c - mean_crest) * (c - mean_crest)
	spread = sqrt(spread / maxf(float(crests.size()), 1.0))
	return {
		"salt": int(one["salt"]),
		"peak": int(one["peak"]),
		"lone": lone,
		"length_km": length / 1000.0,
		"crest_mean": mean_crest,
		"crest_spread": spread / maxf(mean_crest, 1.0),
		"crest_top": _max_of(crests),
		"summits_per_km": float(summits.size()) / maxf(length / 1000.0, 0.001),
		"summit_spacing": length / maxf(float(summits.size()), 1.0),
		"profile": profile,
		"profile_at": _profile_at(profile),
		"steepest_deg": steepest,
		"asymmetry": asymmetry / maxf(float(asymmetry_count), 1.0),
		"gullies_per_km": float(gully_cuts) / maxf(length / 1000.0, 0.001),
		"gullies_by_contour": by_contour,
	}


## The profile read at PROFILE_AT, by straight interpolation of the FLANK_STEPS samples.
static func _profile_at(profile: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for u in PROFILE_AT:
		var f: float = u * float(FLANK_STEPS)
		var i: int = clampi(int(f), 0, FLANK_STEPS - 1)
		out.append(lerpf(profile[i], profile[i + 1], f - float(i)))
	return out


## The local maxima of `values` standing `prominence` above the lower saddle either side of them.
static func _peaks_in(values: PackedFloat32Array, prominence: float) -> Array[int]:
	var out: Array[int] = []
	for k in range(1, values.size() - 1):
		if values[k] < values[k - 1] or values[k] < values[k + 1]:
			continue
		var left: float = values[k]
		var i: int = k
		while i > 0 and values[i - 1] <= values[i] + 0.001:
			i -= 1
			left = minf(left, values[i])
		var right: float = values[k]
		var j: int = k
		while j + 1 < values.size() and values[j + 1] <= values[j] + 0.001:
			j += 1
			right = minf(right, values[j])
		if values[k] - maxf(left, right) >= prominence:
			out.append(k)
	return out


## HOW MANY GULLIES CROSS ONE CONTOUR of one flank: the local minima of the height along it that cut at least
## GULLY_SHARE of THE RELIEF ALONG THAT CONTOUR -- its own highest less its own lowest -- below the shoulder beside them.
##
## WHY THE RELIEF AND NOT THE MEAN, and not the crest. Against the CREST it counts nothing far out, where the ground
## stands at a thirtieth of the crest and no gully can be a twentieth of it deep. Against the contour's own MEAN it
## counts how DEEP the gullies are rather than how MANY: a gully is cut to its full depth only about half way out
## (range_core.cpp's `head` lets nothing cut on the upper tenth), so the same gullies clear a fixed threshold lower down
## and not higher up, and every range read as though it GAINED gullies downhill -- 2.9 a km at a fifth of the way out
## against 6.7 at a half, on an island whose gullies are strictly parallel (2026-09-19, three goes at this measure).
## Against the contour's own RELIEF the threshold grows with the cut, so what is counted is how many comparable valleys
## there are, which is the question.
static func _cuts_in(along_contour: PackedFloat32Array) -> int:
	if along_contour.size() < 3:
		return 0
	var top: float = along_contour[0]
	var bottom: float = along_contour[0]
	for v in along_contour:
		top = maxf(top, v)
		bottom = minf(bottom, v)
	var relief: float = top - bottom
	if relief <= 0.01:
		return 0
	var flipped := PackedFloat32Array()
	for v in along_contour:
		flipped.append(-v)
	return _peaks_in(flipped, GULLY_SHARE * relief).size()


## ---- the table, and the spread across the island ----------------------------------------------------------------------

func _report(every: Array[Dictionary]) -> void:
	print("[ridge_variety] %d ranges, each built alone; %.0f m between stations, %d steps out to the foot" % [
		every.size(), STATION_METRES, FLANK_STEPS])
	print("[ridge_variety] salt  peak  len_km  crest_m  rough  smt/km  spacing_m  steep_deg  asym  gully/km  "
		+ "profile at %s" % str(PROFILE_AT))
	for c in every:
		print("[ridge_variety] %4d %5d %7.2f %8.0f %6.3f %7.2f %10.0f %10.1f %5.3f %9.2f  %s" % [
			c["salt"], c["peak"], c["length_km"], c["crest_mean"], c["crest_spread"], c["summits_per_km"],
			c["summit_spacing"], c["steepest_deg"], c["asymmetry"], c["gullies_per_km"],
			_four(c["profile_at"])])
	# THE SPREAD ACROSS THE ISLAND: for each measure, the mean over the eleven ranges and the coefficient of variation.
	# This is the finding. A character that is the same for every range shows as a spread near zero.
	print("[ridge_variety] --- how far apart the ranges are; cv = spread / mean over the ranges ---")
	for key in ["crest_mean", "crest_spread", "summits_per_km", "summit_spacing", "steepest_deg", "asymmetry",
			"gullies_per_km"]:
		var values := PackedFloat32Array()
		for c in every:
			values.append(float(c[key]))
		print("[ridge_variety]   %-16s mean %9.3f  cv %.3f  (%s)" % [key, _mean(values), _cv(values), _four_of(values)])
	# AND THE PROFILE CURVE, the shape of the flank itself: each fraction of the way out, across the ranges.
	print("[ridge_variety] --- the flank profile, share of the crest at each fraction out to the foot ---")
	var profile_spread := PackedFloat32Array()
	for i in range(PROFILE_AT.size()):
		var values := PackedFloat32Array()
		for c in every:
			values.append((c["profile_at"] as PackedFloat32Array)[i])
		if is_equal_approx(PROFILE_AT[i], 0.5):
			profile_spread.append(_cv(values))
		print("[ridge_variety]   u=%.3f  mean %.4f  cv %.4f  spread %.4f  (%s)" % [PROFILE_AT[i], _mean(values),
			_cv(values), _spread(values), _four_of(values)])
	# THE GULLIES GATHERING DOWN THE FLANK, counted on each contour: high, half way, low.
	print("[ridge_variety] --- gullies crossing each contour, per km of ridge; water gathers, so the last should be the fewest ---")
	var gathered := PackedFloat32Array()
	var gathered_salts := PackedInt32Array()
	for c in every:
		var counts: PackedFloat32Array = c["gullies_by_contour"]
		var km: float = maxf(float(c["length_km"]), 0.001)
		var high: float = counts[0]
		var low: float = counts[counts.size() - 1]
		var share: float = low / maxf(high, 1.0)
		# ONLY A FLANK WITH GULLIES ON IT IS JUDGED. A range that carries two or three on its top contour gives a ratio
		# that swings by a half on one count either way, and the two lone mountains have no ridge to count along at all.
		if high >= ENOUGH_GULLIES_TO_JUDGE:
			gathered.append(share)
			gathered_salts.append(int(c["salt"]))
		var parts: PackedStringArray = []
		for i in range(counts.size()):
			parts.append("u=%.2f %5.2f" % [GULLY_CONTOURS[i], counts[i] / km])
		print("[ridge_variety]   salt %4d  %s  -> %.2f of the top's%s" % [int(c["salt"]), ", ".join(parts), share,
			"" if high >= ENOUGH_GULLIES_TO_JUDGE else "  (too few to judge)"])
	var worst: float = _max_of(gathered)
	var worst_salt: int = -1
	for k in range(gathered.size()):
		if is_equal_approx(gathered[k], worst):
			worst_salt = gathered_salts[k]
			break
	print("[ridge_variety] half way out the flank profile differs across the ranges by %.3f of its mean; the worst of"
		% (profile_spread[0] if profile_spread.size() > 0 else 0.0)
		+ " the %d ranges with gullies enough to judge, salt %d, keeps %.2f of its crest's gullies at its foot"
		% [gathered.size(), worst_salt, worst])


static func _max_of(values: PackedFloat32Array) -> float:
	var top: float = 0.0
	for v in values:
		top = maxf(top, v)
	return top


static func _mean(values: PackedFloat32Array) -> float:
	var total: float = 0.0
	for v in values:
		total += v
	return total / maxf(float(values.size()), 1.0)


static func _spread(values: PackedFloat32Array) -> float:
	var mean: float = _mean(values)
	var total: float = 0.0
	for v in values:
		total += (v - mean) * (v - mean)
	return sqrt(total / maxf(float(values.size()), 1.0))


static func _cv(values: PackedFloat32Array) -> float:
	return _spread(values) / maxf(absf(_mean(values)), 0.0001)


static func _four(values: PackedFloat32Array) -> String:
	var parts: PackedStringArray = []
	for v in values:
		parts.append("%.3f" % v)
	return "[" + ", ".join(parts) + "]"


static func _four_of(values: PackedFloat32Array) -> String:
	var parts: PackedStringArray = []
	for v in values:
		parts.append("%.2f" % v)
	return ", ".join(parts)
