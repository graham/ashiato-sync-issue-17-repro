extends Node
## THE DIORAMA'S ARITHMETIC: that the board is the terrain, that a piece stands where its contact is, and that the
## board draws what it is handed and nothing else.
##
##   Godot --headless --path cockpit res://tests/diorama.tscn
##
## `tests/diorama_shot.gd` is the picture, because legibility is not a thing a headless run can see (CLAUDE.md rule 2).
## This is the part that CAN fail silently: a scale, an index and a projection, all of which look perfectly plausible
## when they are wrong.
##
## ---------------------------------------------------------------------------------------------------
## THE FIVE THINGS THIS IS ACTUALLY GUARDING
## ---------------------------------------------------------------------------------------------------
##
## 1. **THE SCALE IS ONE NUMBER AND IT IS INVERTIBLE** (rule 4). `DioramaScale` is the only place the world is shrunk,
##    and a projection that does not come back is one that has quietly grown a second factor. Held in both directions,
##    **at two different extents**, because an identity error is invisible at N=1 by construction
##    (`docs/testing.md` §5, "one of a thing").
##
## 2. **THE BOARD IS THE TERRAIN.** Every sample of the baked board is held against `Terrain.surface_height` at that
##    texel's own centre, through the scale and back again. **Including a deliberately ASYMMETRIC point**, which is the
##    check that matters: `heights` is indexed `j * TEXELS + i`, and an i/j transpose is invisible on anything
##    symmetrical and produces a board that is the island's own reflection -- drawn confidently, with every contact in
##    the wrong valley.
##
## 3. **A PIECE STANDS AT ITS CONTACT'S ALTITUDE**, and the stalk is its height above the drawn ground. That is the one
##    fact this board has that `ui/menus/map_canvas.gd` cannot show, so it is the one worth a check with two contacts
##    at the same place and different heights -- one of them would prove nothing.
##
## 4. **IT DRAWS WHAT IT IS HANDED AND FETCHES NOTHING** (rule 5), which on this screen is not tidiness. `ControlStation`
##    draws `RadarWatch.contacts()` -- the SENSOR's picture -- and `docs/crew.md` records that hiding behind a ridge
##    genuinely keeps you off it. A board that reached for `Sim.current` would hand the controller omniscience back and
##    **look better while doing it**. So: contacts that exist in no simulation anywhere are still drawn, and an empty
##    list draws nothing, with a world standing right there full of aircraft.
##
## 5. **WHAT HAPPENS BETWEEN SWEEPS IS ONE OF EXACTLY TWO HONEST THINGS.** Radar speaks once a second. The board either
##    HOLDS -- nothing on it is ever a position the sensor did not report -- or DEAD RECKONS, advancing each contact
##    along the course and speed that contact itself reported. Both are held here, with two contacts on courses 90
##    degrees apart, because one contact proves a piece moved and two prove it moved along its OWN heading rather than
##    along a fixed axis.
##
## Read RESULT=, not the exit code.

## How far out to look for somewhere the island is not symmetrical, so an i/j transpose in the board's index cannot
## hide. Found by the run rather than typed: see `_somewhere_lopsided`.
const LOPSIDED_SEARCH: float = 6000.0
## How close a board height has to be to the terrain's, metres. The board stores float32 and the scale is about
## 1:12,000, so a millimetre on the board is 12 m of world: 0.5 m is far tighter than anything that could round.
const HEIGHT_SLACK_M: float = 0.5
## How close a round trip has to come back, world metres.
const TRIP_SLACK_M: float = 0.5

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[diorama] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_the_scale_comes_back()
	_the_board_is_the_terrain()
	_a_piece_stands_where_its_contact_is()
	_it_draws_what_it_is_handed()
	_holding_and_dead_reckoning()
	_every_kind_has_a_shape()
	_finish()


## 5. BETWEEN SWEEPS: HOLD, OR DEAD RECKON. Both are honest and they are honest in different ways, so both are held.
##
## The claim being checked is narrow and worth stating exactly: **a reckoned piece is at the place its OWN reported
## course and speed put it after the reported age, and nowhere else.** Not eased, not smoothed, not averaged with
## anything, and not moved at all when the board is holding.
func _holding_and_dead_reckoning() -> void:
	var board := DioramaBoard.new()
	add_child(board)
	board.build(Terrain.GROUND_HALF.x, Vector2.ZERO)

	# TWO CONTACTS ON COURSES 90 DEGREES APART, which is what makes the direction check mean anything: one contact
	# proves the piece moved, two prove it moved along the heading it was given rather than along some fixed axis.
	var north_at := Vector3(0.0, 1500.0, 0.0)
	var east_at := Vector3(-3000.0, 1500.0, 2000.0)
	var quick: float = 250.0
	var rows: Array = [
		_a_row(Sim.Kind.FIGHTER, north_at, 0.0, false, "NORTH 1"),
		_a_row(Sim.Kind.FIGHTER, east_at, PI * 0.5, false, "EAST 2"),
	]
	for row in rows:
		(row as Dictionary)["speed"] = quick

	# HOLDING: a whole second of age moves nothing at all.
	board.reckoning = false
	board.show_contacts(rows, 0.0)
	var fresh: Vector3 = board.piece_report(0)["at"]
	board.show_contacts(rows, 0.95)
	var later: Vector3 = board.piece_report(0)["at"]
	_check("holding_between_sweeps_moves_nothing",
		fresh.distance_to(later) < 1.0e-9 and board.reckoned_most_m == 0.0,
		"moved %.9f board m over 0.95 s of age, carried %.1f m" % [fresh.distance_to(later), board.reckoned_most_m])

	# RECKONING: each contact is carried along ITS OWN course by speed times age, and the two courses are 90 apart.
	board.reckoning = true
	board.show_contacts(rows, 1.0)
	var carried_north: Vector3 = board.piece_report(0)["world"]
	var carried_east: Vector3 = board.piece_report(1)["world"]
	# COURSE 000 IS TOWARDS -Z and course 090 is towards +X -- `RadarSet.row_of` writes the heading as
	# `atan2(nose.x, -nose.z)`, so this is the convention the number was made in. Getting it backwards sails every
	# contact on the board in reverse, which looks entirely deliberate.
	var want_north := Vector3(north_at.x, north_at.y, north_at.z - quick)
	var want_east := Vector3(east_at.x + quick, east_at.y, east_at.z)
	_check("a_reckoned_contact_is_carried_along_its_own_course",
		Vector2(carried_north.x - want_north.x, carried_north.z - want_north.z).length() < TRIP_SLACK_M
			and Vector2(carried_east.x - want_east.x, carried_east.z - want_east.z).length() < TRIP_SLACK_M,
		"north to (%.0f, %.0f) wanting (%.0f, %.0f); east to (%.0f, %.0f) wanting (%.0f, %.0f)" % [
			carried_north.x, carried_north.z, want_north.x, want_north.z,
			carried_east.x, carried_east.z, want_east.x, want_east.z])
	_check("the_board_says_how_far_it_carried_anything", absf(board.reckoned_most_m - quick) < TRIP_SLACK_M,
		"%.1f m at %.0f m/s over 1.0 s" % [board.reckoned_most_m, quick])

	# IT IS FLAT: the row carries no vertical rate, so the altitude is the one that was reported and is not guessed at.
	_check("a_reckoned_contact_keeps_the_altitude_it_reported", absf(carried_north.y - north_at.y) < TRIP_SLACK_M,
		"%.0f m against the reported %.0f m" % [carried_north.y, north_at.y])

	# IT SNAPS AND DOES NOT EASE. A fresh page has no age, so the piece is back on a reported position in one call --
	# this is the check that the smoothing is done by ARITHMETIC ON THE AGE and not by tweening towards a target, which
	# would hide the size of the guess's error from the operator.
	board.show_contacts(rows, 0.0)
	var snapped: Vector3 = board.piece_report(0)["world"]
	_check("a_new_page_snaps_the_piece_back_rather_than_easing_it",
		Vector2(snapped.x - north_at.x, snapped.z - north_at.z).length() < TRIP_SLACK_M,
		"back to (%.0f, %.0f) from a carried (%.0f, %.0f) in one call" % [
			snapped.x, snapped.z, carried_north.x, carried_north.z])

	# AND A CONTACT THAT IS NOT MOVING IS NOT CARRIED, however old the picture gets. A moored boat that crept across
	# the harbour because the board was reckoning would be the feature discrediting itself.
	var moored: Array = [_a_row(Sim.Kind.BOAT, Vector3(4000.0, 0.0, 4000.0), 1.2, false, "MOORED 3")]
	(moored[0] as Dictionary)["speed"] = 0.0
	board.show_contacts(moored, 3.0)
	var still: Vector3 = board.piece_report(0)["world"]
	_check("a_stopped_contact_is_not_carried_anywhere",
		Vector2(still.x - 4000.0, still.z - 4000.0).length() < TRIP_SLACK_M and board.reckoned_most_m == 0.0,
		"at (%.0f, %.0f) after 3.0 s of age" % [still.x, still.z])
	board.queue_free()


## 1. THE SCALE, BOTH WAYS, AT TWO EXTENTS.
func _the_scale_comes_back() -> void:
	# TWO SCALES, NOT ONE, and deliberately far apart: an indoor level's extent and the island's. A factor that had
	# silently become a constant would pass every check at one extent and none at two.
	var small := DioramaScale.new(250.0, Vector2.ZERO)
	var island := DioramaScale.new(Terrain.GROUND_HALF.x, Vector2.ZERO)
	# AND ONE OFF-CENTRE, because `centre` is non-zero on an indoor level (`LevelMap.configure`) and an offset that was
	# applied in one direction and not the other comes back perfectly at the origin.
	var offset := DioramaScale.new(4000.0, Vector2(1200.0, -800.0))

	var worst: float = 0.0
	var where: String = ""
	for scale_of in [small, island, offset]:
		for point in [Vector3(0.0, 0.0, 0.0), Vector3(123.4, 500.0, -77.7), Vector3(-2000.0, -30.0, 900.0),
				Vector3(scale_of.half_extent, 10000.0, -scale_of.half_extent)]:
			var back: Vector3 = scale_of.from_board(scale_of.to_board(point))
			var off: float = back.distance_to(point)
			if off > worst:
				worst = off
				where = "%s at 1:%d" % [point, roundi(scale_of.world_metres_per_board_metre())]
	_check("the_scale_comes_back_from_the_board", worst < TRIP_SLACK_M, "worst %.4f m, %s" % [worst, where])

	# AND THE OTHER DIRECTION: a place on the board, out to the world and back. Both are asserted because only one of
	# them catches a factor that is right and an offset that is not.
	var worst_board: float = 0.0
	for scale_of in [small, island, offset]:
		for board in [Vector3.ZERO, Vector3(0.6, 0.05, -0.6), Vector3(-0.31, -0.002, 0.44)]:
			var back: Vector3 = scale_of.to_board(scale_of.from_board(board))
			worst_board = maxf(worst_board, back.distance_to(board))
	_check("the_board_comes_back_from_the_world", worst_board < 1.0e-5, "worst %.9f board m" % worst_board)

	# THE EXTENT REALLY IS THE BOARD'S EDGE: the corner of the covered world lands on the corner of the board. This is
	# what ties `DioramaScale.BOARD_HALF` to the thing a camera is framed against.
	var corner: Vector3 = island.to_board(Vector3(island.half_extent, Terrain.SEA_LEVEL, island.half_extent))
	_check("the_worlds_corner_is_the_boards_corner",
		absf(corner.x - DioramaScale.BOARD_HALF) < 1.0e-6 and absf(corner.z - DioramaScale.BOARD_HALF) < 1.0e-6
			and absf(corner.y) < 1.0e-6,
		"%s against %.3f" % [corner, DioramaScale.BOARD_HALF])

	# AND THE TWO SCALES ARE ACTUALLY DIFFERENT, which is the check that makes the two-of-a-thing above mean anything:
	# if `factor()` ignored `half_extent` every assertion so far would still pass.
	_check("a_smaller_world_is_a_bigger_scale", island.factor() < small.factor() * 0.5,
		"1:%d against 1:%d" % [roundi(island.world_metres_per_board_metre()),
			roundi(small.world_metres_per_board_metre())])


## 2. THE BOARD IS THE TERRAIN, at the texel centres the sampler documents, through the scale, both ways.
func _the_board_is_the_terrain() -> void:
	var board := DioramaBoard.new()
	add_child(board)
	var cost: Dictionary = board.build(Terrain.GROUND_HALF.x, Vector2.ZERO)
	print("[diorama] board %d texels at %.0f m, 1:%d, %.0f mm relief over %.0f m, sampled in %.1f ms, built in %.1f ms" % [
		int(cost["texels"]), float(cost["spacing_m"]), roundi(float(cost["one_to"])), float(cost["relief_mm"]),
		float(cost["highest_m"]) - float(cost["lowest_m"]), float(cost["sample_msec"]), float(cost["build_msec"])])

	# THE ISLAND HAS RELIEF TO CHECK AGAINST. Without this the height checks below would pass gloriously on a flat
	# board, which is the tautology this suite would otherwise be (`testing_godot_headless.md`).
	_check("the_board_has_relief_on_it", float(cost["highest_m"]) - float(cost["lowest_m"]) > 100.0,
		"%.0f m from %.0f to %.0f" % [float(cost["highest_m"]) - float(cost["lowest_m"]),
			float(cost["lowest_m"]), float(cost["highest_m"])])

	var worst: float = 0.0
	var where := Vector2.ZERO
	var checked: int = 0
	# EVERY SEVENTH TEXEL, over the whole grid rather than a handful near the middle: the middle of the island is open
	# water and a board that was flat everywhere else would sail through a spot check there.
	for j in range(0, DioramaBoard.TEXELS, 7):
		for i in range(0, DioramaBoard.TEXELS, 7):
			var x: float = board.corner.x + (float(i) + 0.5) * board.spacing
			var z: float = board.corner.y + (float(j) + 0.5) * board.spacing
			var truth: float = Terrain.surface_height(Vector3(x, 0.0, z))
			if truth == -INF or truth == INF:
				continue
			# THROUGH THE SCALE AND BACK: the board answers in BOARD metres, and the whole point is that the two agree
			# after the conversion the drawing actually uses.
			var drawn_m: float = board.scale_of.from_board(Vector3(0.0, board.surface_board_y(x, z), 0.0)).y
			checked += 1
			if absf(drawn_m - truth) > worst:
				worst = absf(drawn_m - truth)
				where = Vector2(x, z)
	_check("the_drawn_board_is_the_terrains_own_surface", checked > 100 and worst < HEIGHT_SLACK_M,
		"%d points, worst %.3f m at %s" % [checked, worst, where])

	# THE TRANSPOSE CHECK, and it is the one worth having. See the doc block.
	var lopsided: Dictionary = _somewhere_lopsided(board)
	if lopsided.is_empty():
		_check("the_board_is_not_its_own_reflection", false, "found nowhere asymmetric to test at")
	else:
		var at: Vector2 = lopsided["at"]
		var here: float = float(lopsided["here"])
		var swapped: float = float(lopsided["swapped"])
		var drawn: float = board.scale_of.from_board(Vector3(0.0, board.surface_board_y(at.x, at.y), 0.0)).y
		_check("the_board_is_not_its_own_reflection",
			absf(drawn - here) < HEIGHT_SLACK_M and absf(drawn - swapped) > HEIGHT_SLACK_M * 4.0,
			"at (%.0f, %.0f) board %.1f m, terrain %.1f m, transposed would be %.1f m" % [at.x, at.y, drawn, here, swapped])
	board.queue_free()


## A PLACE WHERE THE ISLAND IS NOT ITS OWN MIRROR: `surface_height(x, z)` and `surface_height(z, x)` far enough apart
## that an i/j transpose in the board's index could not be mistaken for rounding. Searched rather than typed, because a
## coordinate typed here would go stale the first time anybody moves a mountain (`tests/sight_line.gd` finds the summit
## the same way and for the same reason).
##
## **IT INSISTS THE POINT ITSELF STANDS HIGH**, not merely that its mirror does, and the first run is why: the widest
## gap on the island was a sea-level spot at (-3750, 1500) whose reflection is 481 m of rock. The check passed, and it
## would have passed just as happily against a `surface_board_y` that returned zero for everything. Asking for high
## ground on BOTH sides of the comparison makes the assertion say what its name says.
##
## **AND IT SEARCHES TEXEL CENTRES, WHICH THE SECOND RUN TAUGHT IT.** Snapping the search to the board's own grid was
## worth 32.5 m: at (1500, -3750) the terrain is 480.9 m and the board answered 448.4, and the board was not wrong --
## `surface_board_y` answers with the NEAREST of 150 m samples, so on a mountainside it is up to a texel's worth of
## slope away from a point sample. Comparing a grid against a point measures the grid's resolution, not its index. At a
## texel centre the two are the same number to the millimetre, which is what this check is actually about.
func _somewhere_lopsided(board: DioramaBoard) -> Dictionary:
	var best: Dictionary = {}
	var score: float = 0.0
	for j in range(DioramaBoard.TEXELS):
		for i in range(DioramaBoard.TEXELS):
			var x: float = board.corner.x + (float(i) + 0.5) * board.spacing
			var z: float = board.corner.y + (float(j) + 0.5) * board.spacing
			if absf(x) > LOPSIDED_SEARCH or absf(z) > LOPSIDED_SEARCH:
				continue
			var here: float = Terrain.surface_height(Vector3(x, 0.0, z))
			var swapped: float = Terrain.surface_height(Vector3(z, 0.0, x))
			if here == -INF or swapped == -INF or here == INF or swapped == INF:
				continue
			# THE WORTH OF A CANDIDATE is the smaller of "how high this point is" and "how far its mirror is from it":
			# a tall point whose mirror matches proves nothing, and so does a big gap down at sea level.
			var worth: float = minf(here, absf(here - swapped))
			if worth > score:
				score = worth
				best = {"at": Vector2(x, z), "here": here, "swapped": swapped}
	return best if score > HEIGHT_SLACK_M * 10.0 else {}


## 3. A PIECE STANDS WHERE ITS CONTACT IS, AND AS HIGH AS IT IS.
func _a_piece_stands_where_its_contact_is() -> void:
	var board := DioramaBoard.new()
	add_child(board)
	board.build(Terrain.GROUND_HALF.x, Vector2.ZERO)

	# TWO CONTACTS AT ONE PLACE AND TWO HEIGHTS, which is the shape the altitude claim needs: at N=1 a board that
	# ignored altitude entirely would pass.
	var low := Vector3(1500.0, 200.0, -2200.0)
	var high := Vector3(1500.0, 2600.0, -2200.0)
	var rows: Array = [
		_a_row(Sim.Kind.CESSNA, low, 0.4, true, "LOW 1"),
		_a_row(Sim.Kind.AIRLINER, high, 1.9, false, "HIGH 2"),
	]
	board.show_contacts(rows)
	_check("every_contact_got_a_piece", board.pieces_shown == rows.size(),
		"%d piece(s) for %d row(s)" % [board.pieces_shown, rows.size()])

	var first: Dictionary = board.piece_report(0)
	var second: Dictionary = board.piece_report(1)
	var back_low: Vector3 = first["world"]
	_check("a_piece_stands_over_its_contacts_ground",
		Vector2(back_low.x - low.x, back_low.z - low.z).length() < TRIP_SLACK_M,
		"row at (%.0f, %.0f), piece at (%.0f, %.0f)" % [low.x, low.z, back_low.x, back_low.z])

	# THE HEIGHT ITSELF. The piece's world y back through the scale IS the contact's altitude.
	var back_high: Vector3 = second["world"]
	_check("a_piece_stands_at_its_contacts_altitude",
		absf(back_low.y - low.y) < TRIP_SLACK_M and absf(back_high.y - high.y) < TRIP_SLACK_M,
		"%.0f m against %.0f, and %.0f m against %.0f" % [back_low.y, low.y, back_high.y, high.y])

	# AND THE TWO REALLY DIFFER ON THE BOARD, which is the whole reason the board exists: 2,400 m apart in the world is
	# 2,400 m apart on the board through the same factor, and a flat plot would put these two markers on top of
	# each other.
	var apart_m: float = (back_high.y - back_low.y)
	var apart_mm: float = (second["at"] as Vector3).y * 1000.0 - (first["at"] as Vector3).y * 1000.0
	_check("altitude_is_visible_on_the_board_and_is_not_on_the_plot",
		absf(apart_m - (high.y - low.y)) < TRIP_SLACK_M and apart_mm > 50.0,
		"%.0f m apart, %.0f mm apart on a %.0f mm board" % [apart_m, apart_mm, DioramaScale.BOARD_HALF * 2000.0])

	# THE STALK IS THE HEIGHT ABOVE THE DRAWN GROUND, not above sea level: over the island's slab those are the same
	# number, so this is asserted against the board's OWN surface rather than against zero.
	var ground_m: float = board.scale_of.from_board(Vector3(0.0, board.surface_board_y(low.x, low.z), 0.0)).y
	_check("the_stalk_is_the_height_above_the_ground_under_it",
		bool(first["stalk"]) and absf(float(first["stalk_m"]) - (low.y - ground_m)) < TRIP_SLACK_M,
		"stalk %.0f m, contact %.0f m over ground %.0f m" % [float(first["stalk_m"]), low.y, ground_m])

	# TONE, which is the channel `world/radar_set.gd` names for `manned` now that the pieces are little MODELS and
	# solid-against-outline is gone with the flat plates (`DioramaBoard._pewter`). Two contacts, one of each, because a
	# check that only ever sees a manned contact cannot tell the two apart.
	_check("a_crewed_contact_is_brighter_than_an_empty_one",
		float(first["tone"]) > float(second["tone"]) * 1.2,
		"crewed %.3f against empty %.3f" % [float(first["tone"]), float(second["tone"])])

	# AND A BIGGER AEROPLANE IS A BIGGER PIECE, derived from the kind's own extents rather than a roster here (rule 4).
	#
	# **THIS IS MEASURED OFF THE DRAWN MESH AND NOT OFF THE SCALE APPLIED TO IT**, which matters more than it sounds.
	# A miniature is built at LIFE SIZE and shrunk, so a jumbo has a SMALLER scale factor than a Cessna -- when the
	# pieces stopped being unit plates this check went red with "airliner 0.0016 against cessna 0.0048" and was right
	# to, because both of those are perfectly plausible numbers and only their order gives the fault away.
	_check("a_bigger_kind_gets_a_bigger_piece", float(second["plate_wide"]) > float(first["plate_wide"]),
		"airliner %.4f against cessna %.4f board m, as drawn" % [
			float(second["plate_wide"]), float(first["plate_wide"])])

	# THE HEADING SURVIVES. `RadarSet.row_of` writes `atan2(nose.x, -nose.z)` and the piece is turned by it; a sign
	# error here points every aeroplane on the board backwards and looks entirely convincing.
	_check("a_piece_is_turned_to_its_contacts_heading", absf(float(first["heading"]) - 0.4) < 1.0e-4,
		"row 0.400 rad, piece %.3f rad" % float(first["heading"]))

	# A CONTACT THAT GOES OFF RADAR TAKES ITS PIECE WITH IT -- hidden, and the pool kept.
	board.show_contacts([rows[0]])
	var spare: Dictionary = board.piece_report(1)
	_check("a_contact_that_drops_off_radar_loses_its_piece",
		board.pieces_shown == 1 and not bool(spare["visible"]) and board.pool_size() == 2,
		"%d shown, spare visible=%s, pool %d" % [board.pieces_shown, spare["visible"], board.pool_size()])
	board.queue_free()


## 4. IT DRAWS WHAT IT IS HANDED AND FETCHES NOTHING. See the doc block -- on this screen that is the feature.
func _it_draws_what_it_is_handed() -> void:
	var board := DioramaBoard.new()
	add_child(board)
	board.build(Terrain.GROUND_HALF.x, Vector2.ZERO)

	# A WORLD FULL OF AEROPLANES, STANDING RIGHT THERE. If the board ever reached for a simulation instead of its rows,
	# this is what it would find, and the empty-list check below would go red.
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120)
	world.start(0)
	for i in range(24):
		world.spawn_ai_vehicle(Sim.Kind.PLANE, Vector3(400.0 * float(i) - 4000.0, 900.0, 600.0), 0.0, Vector3.ZERO)
	world.tick(1.0 / 120.0)
	var in_the_world: int = (world.vehicle_states() as Array).size()

	board.show_contacts([])
	_check("an_empty_picture_draws_an_empty_board", board.pieces_shown == 0,
		"%d piece(s) drawn with %d craft in a world beside it" % [board.pieces_shown, in_the_world])

	# AND CONTACTS THAT EXIST IN NO SIMULATION ANYWHERE ARE STILL DRAWN, which is the other half of the same claim: the
	# board is a display and the rows are the truth it was given.
	var invented: Array = [
		_a_row(Sim.Kind.BOAT, Vector3(-6000.0, 0.0, 6000.0), 0.0, false, "NOWHERE 1"),
		_a_row(Sim.Kind.HELI, Vector3(6000.0, 120.0, -6000.0), 3.0, true, "NOWHERE 2"),
		_a_row(Sim.Kind.TOMCAT, Vector3(0.0, 8000.0, 0.0), 1.0, true, "NOWHERE 3"),
	]
	board.show_contacts(invented)
	_check("contacts_in_no_simulation_are_still_drawn", board.pieces_shown == invented.size(),
		"%d of %d drawn" % [board.pieces_shown, invented.size()])

	# A CONTACT PAST THE EDGE OF THE WORLD THE BOARD COVERS IS STILL ON THE TABLE, standing off the rim in open space.
	#
	# **THE FLAT PLOT CANNOT DO THIS AND SAYS SO.** `RadarSet.REACH_M` is 60 km and `LevelMap.half_extent` on the island
	# is 7.2 km, so a contact out past the map is projected off the canvas and CLIPPED -- `ControlStation._off_the_plot`
	# exists only to count them and say the number out loud, and `../../todo/flatcrew--contacts-past-the-edge-of-the-
	# plot.md` is the note asking for edge markers. A board has no canvas edge to clip against: the piece simply stands
	# where it is, beyond the water, which is both where it is and what it looks like.
	var far_out := Vector3(Terrain.GROUND_HALF.x * 2.4, 3000.0, 0.0)
	board.show_contacts([_a_row(Sim.Kind.AIRLINER, far_out, 0.0, false, "FAR 9")])
	var distant: Dictionary = board.piece_report(0)
	var out_at: Vector3 = distant["at"]
	_check("a_contact_past_the_maps_edge_stands_off_the_rim_instead_of_being_clipped",
		bool(distant["visible"]) and absf(out_at.x) > DioramaScale.BOARD_HALF * 1.5,
		"contact %.1f km out (map is %.1f km), piece %.3f board m from the middle of a %.2f m board" % [
			far_out.x / 1000.0, Terrain.GROUND_HALF.x / 1000.0, out_at.x, DioramaScale.BOARD_HALF * 2.0])
	board.show_contacts(invented)

	# A SHIP ON THE WATER GETS NO STALK, because a peg of no length is ink saying nothing -- and a helicopter at 120 m
	# does get one, so this is not merely "no stalks anywhere".
	var boat: Dictionary = board.piece_report(0)
	var heli: Dictionary = board.piece_report(1)
	_check("a_ship_has_no_stalk_and_a_helicopter_does",
		not bool(boat["stalk"]) and bool(heli["stalk"]),
		"boat stalk=%s, helicopter stalk=%s at %.0f m" % [boat["stalk"], heli["stalk"], float(heli["stalk_m"])])
	board.queue_free()


## 6. EVERY KIND LANDS ON THE BOARD WEARING SOMETHING. `VehicleCatalogue.group` is the authority (it reads the movement
## model the simulation declares), and this holds the board to having a shape for every group it can answer -- so a
## kind added in the C++ appears on the board rather than disappearing off it.
func _every_kind_has_a_shape() -> void:
	var board := DioramaBoard.new()
	add_child(board)
	board.build(Terrain.GROUND_HALF.x, Vector2.ZERO)
	var rows: Array = []
	var groups: Dictionary = {}
	for kind in range(Sim.Kind.size()):
		if kind in AirPicture.NOT_TRAFFIC:
			continue
		groups[VehicleCatalogue.group(kind)] = true
		rows.append(_a_row(kind, Vector3(float(kind) * 120.0 - 2000.0, 400.0, 0.0), 0.0, kind % 2 == 0,
			"KIND %d" % kind))
	board.show_contacts(rows)
	var blank: PackedStringArray = []
	var tiny: PackedStringArray = []
	for index in range(rows.size()):
		var report: Dictionary = board.piece_report(index)
		if not bool(report["visible"]):
			blank.append(String(rows[index]["name"]))
		if float(report["plate_wide"]) < DioramaBoard.TOKEN_SMALL * 0.5:
			tiny.append(String(rows[index]["name"]))
	_check("every_kind_that_is_traffic_gets_a_piece", blank.is_empty() and board.pieces_shown == rows.size(),
		"%d of %d drawn%s" % [board.pieces_shown, rows.size(),
			"" if blank.is_empty() else ", missing " + ", ".join(blank)])
	_check("no_kinds_piece_is_smaller_than_the_readable_floor", tiny.is_empty(),
		"%d kind(s) in %d group(s)%s" % [rows.size(), groups.size(),
			"" if tiny.is_empty() else ", too small: " + ", ".join(tiny)])
	board.queue_free()


## A CONTACT ROW IN `RadarSet.read`'s SHAPE, which is `AirPicture.contacts`' shape. Built here rather than swept,
## because what is under test is the DRAWING -- `tests/radar_set.gd` and `tests/radar_peers.gd` hold the sweep, and
## `tests/diorama_shot.gd` photographs a real one.
func _a_row(kind: int, at: Vector3, heading: float, manned: bool, name: String) -> Dictionary:
	return {"contact": -absi(hash(name)), "client": -1, "vehicle": 0, "kind": kind, "position": at,
		"heading": heading, "speed": 120.0, "yours": false, "name": name, "manned": manned,
		"colour": AirPicture.AI, "distance": -1.0}


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
