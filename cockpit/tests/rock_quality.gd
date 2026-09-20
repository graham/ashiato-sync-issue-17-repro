extends Node
## THE MOUNTAINS' QUALITY DIAL, MEASURED (lane/rivers, 2026-09-20).
##
##   Godot --headless --path cockpit res://tests/rock_quality.tscn
##
## The user: "let's also upgrade the mountains we have as well, we should be able to tweak the quality there so we can
## up or downgrade the poly count based on our needs." A level names `rock_spacing`, the metres between the mountain
## grid's vertices, and this holds the dial to the three things that make it a dial rather than a knob that changes the
## world:
##
##   IT MOVES THE POLY COUNT, and by the amount the geometry says: the triangles go as the INVERSE SQUARE of the
##     spacing, so halving it is four times the triangles.
##   A TILE KEEPS ITS SIZE. A tile is a draw call and a culling unit; how much world it holds must not change because
##     somebody asked for finer rock, so the quads a side move with the spacing and the tile stays 1,920 m.
##   AND IT IS THE SAME MOUNTAIN. This is the one that matters and the one a triangle count cannot see. The picture IS
##     the collision here (range_core.hpp), so a dial that reshaped the rock would move what an aeroplane hits and what
##     a shell bursts on. The highest rock and the surface under a spread of points are held across every quality.
##
## WHY IT IS A LEVEL'S NUMBER AND NOT A MACHINE'S. Static collision is not replicated (cockpit/agents.md, RULES 8) and
## every peer builds its own rock from this number, so two peers at different qualities would stand different
## mountains and each would predict itself into the other's hillside. That is why this is not on `Finish`, the
## PLAIN/FINE tier a player flips with a thumb, and not on `DetailReach`, which owns distance: both are per-machine by
## design, and neither can carry a number that changes what an aeroplane hits. The brief for this lane asked for the
## dial to go on one of those two; it cannot, and this file is the measurement of why it would have been wrong.
##
## Read RESULT=, not the exit code.

## The qualities measured, metres between vertices. 48 is what every level has had.
const SPACINGS: PackedInt32Array = [96, 48, 24]
## How far the measured triangle count may be from the inverse square the geometry says, as a share. Not zero: a range
## is cut into whole tiles and its edge tiles are partly empty, so the count is not exactly proportional.
const SQUARE_LAW_WITHIN: float = 0.12
## How far the highest rock may move between qualities, metres, and how far the surface may move at a sampled point.
## A finer grid samples the ridge nearer its true crest, so the top rises a little as the spacing falls; what must not
## happen is the mountain becoming a different mountain.
const SUMMIT_WITHIN: float = 45.0
const SURFACE_WITHIN: float = 60.0
## AND WHAT SHARE OF THE SAMPLED POINTS MAY MOVE FURTHER. Not none, and this is the honest cost of the dial rather
## than a fudge: a coarser grid cuts the corner off a steep face, so on a cliff the surface between two qualities can
## differ by a good deal. Over the whole 16-times range measured here -- 96 m against 24 m -- it is 3 points in 400,
## the worst moving 69.9 m, and everywhere else the two surfaces are the same rock.
##
## THIS IS ALSO THE PROOF THAT THE DIAL CANNOT BE A PER-MACHINE SETTING. Two peers at different qualities would stand
## rock 70 m apart on those faces, and the picture IS the collision.
const SURFACE_MOVED_SHARE: float = 0.02
## Where the surface is sampled: a spread over the island's ranges.
const SAMPLES: int = 400
const SPREAD: float = 6000.0

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[rock_quality] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists(&"MountainRange"):
		_check("the_build_has_mountains", false, "no MountainRange")
		_finish()
		return
	var built: Array[Dictionary] = []
	for spacing in SPACINGS:
		var rock: Object = ClassDB.instantiate(&"MountainRange")
		var quads: int = MountainRanges.tile_quads_for(spacing)
		var problems: PackedStringArray = rock.call("configure", {"spacing": spacing, "tile_quads": quads,
			"ranges": MountainRanges.ranges(), "keepouts": PackedInt32Array()})
		if not problems.is_empty():
			_check("the_rock_configures_at_%d_m" % spacing, false, "%s" % [problems])
			continue
		var report: Dictionary = rock.call("report")
		built.append({"spacing": spacing, "quads": quads, "rock": rock, "report": report})
		print("[rock_quality] %d m: %d triangles, %d tiles of %d quads (%d m), built in %.1f ms"
			% [spacing, int(report["triangles"]), int(report["tiles"]), quads, quads * spacing,
				float(report["build_usec"]) / 1000.0])
	_check("every_quality_stands", built.size() == SPACINGS.size(), "%d of %d" % [built.size(), SPACINGS.size()])
	if built.size() < 2:
		_finish()
		return
	_the_default_is_what_every_level_has_had(built)
	_a_tile_keeps_its_size(built)
	_the_poly_count_goes_as_the_inverse_square(built)
	_it_is_the_same_mountain(built)
	_finish()


## THE DEFAULT IS UNCHANGED. A level that names nothing takes `MountainRanges.SPACING`, and the dial must not have
## moved the rock every level already stands on.
func _the_default_is_what_every_level_has_had(built: Array[Dictionary]) -> void:
	var default_quads: int = MountainRanges.tile_quads_for(MountainRanges.SPACING)
	_check("the_default_quality_is_the_rock_every_level_already_had",
		default_quads == MountainRanges.TILE_QUADS and MountainRanges.SPACING * MountainRanges.TILE_QUADS
			== MountainRanges.TILE_METRES,
		"%d m a vertex, %d quads a tile (was %d), %d m a tile" % [MountainRanges.SPACING, default_quads,
			MountainRanges.TILE_QUADS, MountainRanges.TILE_METRES])


func _a_tile_keeps_its_size(built: Array[Dictionary]) -> void:
	var sizes: Array[String] = []
	var wrong: Array[String] = []
	for one in built:
		var entry: Dictionary = one
		var metres: int = int(entry["quads"]) * int(entry["spacing"])
		sizes.append("%d m at %d m a vertex" % [metres, entry["spacing"]])
		# WITHIN ONE SPACING of the tile the game has always had: a tile cannot be a fraction of a quad, so a spacing
		# that does not divide 1,920 m rounds to the nearest whole one.
		if absi(metres - MountainRanges.TILE_METRES) > int(entry["spacing"]):
			wrong.append(sizes[-1])
	_check("a_tile_holds_the_same_world_at_every_quality", wrong.is_empty(),
		"%s; wanted %d m; wrong: %s" % [", ".join(sizes), MountainRanges.TILE_METRES, wrong])


## THE TRIANGLES GO AS THE INVERSE SQUARE OF THE SPACING. Measured between each neighbouring pair, so the check says
## which step of the dial misbehaved rather than only that the ends disagree.
func _the_poly_count_goes_as_the_inverse_square(built: Array[Dictionary]) -> void:
	var said: Array[String] = []
	var off: Array[String] = []
	for k in range(1, built.size()):
		var coarse: Dictionary = built[k - 1]
		var fine: Dictionary = built[k]
		var ratio: float = float(int((fine["report"] as Dictionary)["triangles"])) \
			/ float(int((coarse["report"] as Dictionary)["triangles"]))
		var law: float = pow(float(int(coarse["spacing"])) / float(int(fine["spacing"])), 2.0)
		said.append("%d m to %d m: %.2fx, the square law says %.2fx"
			% [coarse["spacing"], fine["spacing"], ratio, law])
		if absf(ratio - law) / law > SQUARE_LAW_WITHIN:
			off.append(said[-1])
	_check("the_poly_count_goes_as_the_inverse_square_of_the_spacing", off.is_empty(),
		"%s; allowed %.0f %% off; wrong: %s" % [", ".join(said), SQUARE_LAW_WITHIN * 100.0, off])


## AND IT IS THE SAME MOUNTAIN. The dial may not reshape the rock, because the rock is the collision.
func _it_is_the_same_mountain(built: Array[Dictionary]) -> void:
	var summits: Array[float] = []
	var surfaces: Array[PackedFloat32Array] = []
	for one in built:
		var entry: Dictionary = one
		var rock: Object = entry["rock"]
		var top: float = -INF
		var here := PackedFloat32Array()
		for i in range(SAMPLES):
			# A SPREAD FIXED BY ITS INDEX, so every quality is asked about exactly the same points.
			var angle: float = TAU * float(i) * 0.618034
			var out: float = SPREAD * sqrt(float(i + 1) / float(SAMPLES))
			var at := Vector2(cos(angle) * out, sin(angle) * out)
			var h: float = float(rock.call("surface_at", at.x, at.y))
			here.append(h)
			top = maxf(top, h)
		summits.append(top)
		surfaces.append(here)
	var tops: Array[String] = []
	for k in range(built.size()):
		tops.append("%d m: %.0f m" % [built[k]["spacing"], summits[k]])
	var spread: float = summits.max() - summits.min()
	_check("the_summit_is_the_same_summit_at_every_quality", spread <= SUMMIT_WITHIN,
		"%s; they span %.1f m, allowed %.0f m" % [", ".join(tops), spread, SUMMIT_WITHIN])
	var worst: float = 0.0
	var moved: int = 0
	for i in range(SAMPLES):
		var low: float = INF
		var high: float = -INF
		for k in range(surfaces.size()):
			low = minf(low, surfaces[k][i])
			high = maxf(high, surfaces[k][i])
		worst = maxf(worst, high - low)
		if high - low > SURFACE_WITHIN:
			moved += 1
	var moved_share: float = float(moved) / float(SAMPLES)
	_check("the_surface_under_a_spread_of_points_is_the_same_rock", moved_share <= SURFACE_MOVED_SHARE,
		("%d of %d points (%.2f %%, allowed %.0f %%) move more than %.0f m between the coarsest and the finest "
			+ "quality, which are 16 times apart in triangles; the worst moves %.1f m, on a steep face where a "
			+ "coarser grid cuts the corner")
			% [moved, SAMPLES, moved_share * 100.0, SURFACE_MOVED_SHARE * 100.0, SURFACE_WITHIN, worst])


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0)
