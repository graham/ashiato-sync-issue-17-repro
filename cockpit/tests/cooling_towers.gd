extends Node
## THE COOLING TOWERS' SHAPE, ASKED OF THE DRAWN TRIANGLES.
##
## WHAT THIS SUITE IS FOR. A hyperboloid of one sheet is instantly recognisable and instantly wrong if the
## waist is in the wrong place, and a waist in the wrong place is exactly the fault that every plausible
## number in the file will sit still for. So the checks that matter here do not ask `CoolingTower` what its
## throat height is -- that would be the file agreeing with itself. They take the MESH, bucket its vertices
## into rings, and ask where the narrowest ring actually came out.
##
## THE REFERENCE FIGURES BELOW ARE TYPED, not computed from the builder's constants. Working them out from
## `CoolingTower.SHELL_HEIGHT_FT` and friends would bound the very numbers they are bounding, which is the
## tautology `testing_godot_headless.md` is about: a check that shares its subject's frame of reference
## cannot catch the frame being wrong. They come from `world/cooling_tower.gd`'s [FCT] line, converted by
## hand: 296 / 244 / 124 / 131 feet at 0.3048 m a foot.
##
## AND ONE CHECK IS ANCHORED COMPLETELY OUTSIDE THE GAME. `the_shape_agrees_with_the_photograph` holds the
## builder's waist constant against a number measured off a Commons photograph of the Eggborough towers --
## a reference that never saw Baglan Bay's published dimensions and could not have been influenced by them.
## That is the strongest arbitration available here and it is cheap, because the measurement was a ratio and
## carries no scale of its own.

## The published envelope in metres, typed. See the doc block for why these are not derived.
const SHELL_HEIGHT: float = 90.2208
const RING_BEAM_RADIUS: float = 37.1856
const THROAT_RADIUS: float = 18.8976
const TOP_RADIUS: float = 19.9644
## The waist, solved by hand from those four: b = 90.2208 / (sqrt(1.967742^2 - 1) + sqrt(1.056452^2 - 1)).
const WAIST_CONSTANT: float = 44.3254
const THROAT_HEIGHT: float = 75.1183
## Where the waist sits as a fraction of the shell's own height. THE NUMBER THIS WHOLE MODEL IS JUDGED ON.
## [FCT]'s four dimensions give 0.8326; [PS]'s four give 0.8110 for Ferrybridge C; the [EGG] silhouette,
## taken with the base at the ratio those two agree on, gives about 0.81.
const THROAT_SHARE: float = 0.8326
const THROAT_SHARE_LOW: float = 0.80
const THROAT_SHARE_HIGH: float = 0.85
## MEASURED off the [EGG] photograph: left edge, 299 rows, rms residual 0.38 px. It is a pure ratio.
const MEASURED_B_OVER_THROAT: float = 2.4465
## What the published envelope solves to when its height is read as the SHELL, ring beam to lip. The other
## two readings of the same sentence give 2.1116 (columns inside the 296 ft) and 2.5797 (columns on top of
## it), and only one of those three is more than 10 per cent from the measurement -- see the check.
const SHELL_B_OVER_THROAT: float = 2.3456

## THE BUDGET, AND WHAT IT IS AND IS NOT. Team-lead asked the right question of this number, and the honest
## answer is in two halves, because the tower turns out not to be triangle-bound at all.
##
## WHAT IS ACTUALLY SCARCE IS THE DRAW CALL, NOT THE TRIANGLE. A tower is 840 triangles in ONE surface.
## Against `aircraft_model_fidelity_plan.md`'s first-LOD budget of 100,000 triangles and 20 draw calls, a
## hundred and nineteen towers fit the triangles and TWENTY exhaust the draws. So the answer to "how many
## towers can the world hold" is the draw count, by a factor of six, and the thing to write down for
## whoever wants an eight-tower station is: past a handful they must become one MultiMesh, and the
## triangle count is not what will stop them.
##
## SO THIS IS A TRIPWIRE, NOT A FRAME BUDGET, AND IT SAYS SO. 850 is ten above what the model draws, and it
## is here to catch somebody quietly subdividing the shell -- raising `SIDES` from 20 to 32 puts it at
## 1,344 and this goes red. It is NOT a claim about what a frame can afford. "Less than one fighter" is a
## rhetorical anchor, and a pair of static towers and a flying fighter are not interchangeable loads; the
## real constraint, what a frame costs with the towers in it, is UNMEASURED, and `tests/scenery_shot.gd`
## with a view added at the station is the probe that would measure it. Named here rather than implied,
## because `hitch` has been red on main all day at 0.599 ms against 0.55 allowed while the budget it
## actually guards is 8.33 ms, and a tripwire mistaken for a budget is how that happens.
const MOST_TRIANGLES: int = 850
## The F/A-18F's whole exterior, measured (`modelling_here.md` section 8). Kept because it is a real number
## somebody measured and it puts 840 in proportion -- not because a tower and a fighter are the same load.
const HORNET_EXTERIOR_TRIANGLES: int = 1700
## The first-LOD draw-call budget from `aircraft_model_fidelity_plan.md`, which is what actually runs out.
const FIRST_LOD_DRAWS: int = 20
## The first-LOD triangle budget from the same place, which does not.
const FIRST_LOD_TRIANGLES: int = 100000

## HOW MUCH FASTER THE STEAM MUST CLIMB than the column somebody tuned to read as smoke. See the check.
const STEAM_BEATS_SMOKE_BY: float = 2.0

## THE SOLID, TYPED. 33 boxes a tower, and the worst distance a body may get into the drawn shell before
## one of them stops it, in metres -- both measured off a sweep of every band and every bearing before the
## arrangement was chosen, and both typed here so the sweep does not have to be trusted.
const SOLID_BOXES: int = 33
const DEEPEST_CLIP: float = 11.1
## The island files this many static boxes without the station (`tests/world_map.gd`), so 66 is 6.5 % on top.
const ISLAND_BOXES: int = 1014

## FLYING ONE INTO IT. `tests/airbase.gd`'s arrangement, which is the only thing here that proves a body is
## actually stopped rather than that a Dictionary reached a list.
const FLY_HZ: float = 120.0
const FLY_SECONDS: float = 10.0
const FLY_THROTTLE: float = 0.6
## WHERE THE FIGHTER STARTS, metres short of the tower's axis and metres above the pond -- and both numbers
## were set by a failure rather than chosen. The first run started 320 m out at 30 m, and the aeroplane
## reached the tower at **1.6 m**, having sunk 28 m on the way: at 0.6 throttle with no pitch input it is
## descending, not flying. So it went clean through the column bay UNDER the shell, 514 m out the far side,
## and the check reported "the towers do not stop a fighter" when what it had actually measured was the 9 m
## gap that `CoolingTower` deliberately leaves open.
##
## A CHECK THAT FLIES SOMETHING HAS TO SAY WHERE THE THING WENT, or its failure cannot be read. The height
## and the lateral offset at the tower's own station are printed on every run for exactly that reason --
## they are what turned "the collision is broken" into "the aeroplane was 1.6 m up" in one line.
const FLY_FROM: float = 150.0
const FLY_HEIGHT: float = 60.0
## How far to the side the control run is flown. Clear of the pond, so it must pass.
const FLY_ASIDE: float = 220.0

var failures: PackedStringArray = []


func check(label: String, ok: bool, detail: String = "") -> void:
	print("[cooling_towers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures.append(label)


func _ready() -> void:
	var mesh: ArrayMesh = CoolingTower.build()
	var points: PackedVector3Array = _vertices(mesh)
	_the_published_envelope_comes_back_in_metres()
	_the_waist_is_where_three_references_agree_it_is()
	_the_shape_agrees_with_the_photograph()
	_the_narrowest_drawn_ring_is_the_throat(points)
	_the_drawn_profile_refits_to_the_same_hyperbola(points)
	_the_drawn_bounds_are_the_published_envelope(points)
	_a_tower_stands_on_raked_columns(points)
	_every_face_is_wound_outwards(mesh)
	_a_tower_is_one_draw_and_nobody_has_subdivided_it(mesh)
	_the_steam_climbs_faster_than_the_rate_tuned_to_read_as_smoke()
	_the_plume_is_whole_on_the_frame_it_is_first_drawn()
	_every_collision_box_is_inside_the_drawn_shell(points)
	_a_body_cannot_get_far_into_a_tower_before_it_is_stopped()
	_the_station_is_solid_and_says_what_it_costs()
	_a_fighter_flown_at_a_tower_does_not_come_out_the_other_side()
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL " + ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


## ---- the envelope --------------------------------------------------------------------------------

func _the_published_envelope_comes_back_in_metres() -> void:
	var ok: bool = absf(CoolingTower.shell_height() - SHELL_HEIGHT) < 0.002 \
		and absf(CoolingTower.ring_beam_radius() - RING_BEAM_RADIUS) < 0.002 \
		and absf(CoolingTower.throat_radius() - THROAT_RADIUS) < 0.002 \
		and absf(CoolingTower.top_radius() - TOP_RADIUS) < 0.002
	check("the_published_envelope_comes_back_in_metres", ok,
		"shell %.3f ring beam r %.3f throat r %.3f top r %.3f" % [CoolingTower.shell_height(),
			CoolingTower.ring_beam_radius(), CoolingTower.throat_radius(), CoolingTower.top_radius()])


## THE HEADLINE. Both halves have to hold: the band, which is what a reader can argue with, and the exact
## figure, which is what a one-line mutant moves. A band alone cannot catch a small error and a figure alone
## says nothing about how much room there is round it (`modelling_here.md` section 3, the Arleigh Burke's
## hull depth: a two-metre band on a number near thirteen rejects a blunder, it does not confirm a pick).
func _the_waist_is_where_three_references_agree_it_is() -> void:
	var share: float = CoolingTower.throat_height() / CoolingTower.shell_height()
	check("the_waist_is_where_three_references_agree_it_is",
		share > THROAT_SHARE_LOW and share < THROAT_SHARE_HIGH and absf(share - THROAT_SHARE) < 0.002,
		"waist at %.4f of the shell, against %.4f typed and the band %.2f to %.2f"
			% [share, THROAT_SHARE, THROAT_SHARE_LOW, THROAT_SHARE_HIGH])
	check("the_waist_is_the_height_the_envelope_solves_to",
		absf(CoolingTower.throat_height() - THROAT_HEIGHT) < 0.01
			and absf(CoolingTower.waist_constant() - WAIST_CONSTANT) < 0.01,
		"throat %.3f m (typed %.3f), b %.3f m (typed %.3f)" % [CoolingTower.throat_height(), THROAT_HEIGHT,
			CoolingTower.waist_constant(), WAIST_CONSTANT])


## THE ONE CHECK ANCHORED OUTSIDE THE GAME AND OUTSIDE THE SOURCE -- AND THE BAND IS NOT THE WHOLE OF IT.
## Ten per cent rejects the reading of [FCT]'s "height 296 ft." that takes the columns to be inside it, which
## comes out at 2.112 and 13.7 per cent away. It does NOT reject the reading that adds the columns on TOP of
## it: that is 2.580 and only 5.4 per cent away, inside the band, and a mutant that made exactly that change
## left this check green (mutant 1, 2026-09-17). A band on a number cannot separate two readings that both
## land near it -- the Arleigh Burke's hull depth again -- so the typed figure is checked as well, and it is
## the figure that pins the datum. The band is here to say how much room a reader has to argue about the
## measurement; the figure is here to fail.
func _the_shape_agrees_with_the_photograph() -> void:
	var ratio: float = CoolingTower.waist_constant() / CoolingTower.throat_radius()
	var apart: float = absf(ratio - MEASURED_B_OVER_THROAT) / MEASURED_B_OVER_THROAT
	check("the_shape_agrees_with_the_photograph", apart < 0.10 and absf(ratio - SHELL_B_OVER_THROAT) < 0.01,
		"b / r_throat is %.4f (typed %.4f) against %.4f measured off the Eggborough silhouette, %.1f%% apart"
			% [ratio, SHELL_B_OVER_THROAT, MEASURED_B_OVER_THROAT, apart * 100.0])


## ---- what was actually drawn ---------------------------------------------------------------------

## ASKED OF THE TRIANGLES, NOT OF THE FORMULA. Bucket every drawn vertex above the ring beam by height,
## take the widest point of each bucket, and find the narrowest bucket. If the builder drew a cone, an
## egg-timer or a chimney, this is where it shows -- and none of the numbers above would have moved.
func _the_narrowest_drawn_ring_is_the_throat(points: PackedVector3Array) -> void:
	var rings: Dictionary = {}
	for p in points:
		if p.y < CoolingTower.COLUMN_HEIGHT + 0.01:
			continue
		var key: int = int(round((p.y - CoolingTower.COLUMN_HEIGHT) * 1000.0))
		var r: float = Vector2(p.x, p.z).length()
		rings[key] = maxf(float(rings.get(key, 0.0)), r)
	var narrow_key: int = -1
	var narrow_r: float = 1e9
	for key in rings:
		if float(rings[key]) < narrow_r:
			narrow_r = float(rings[key])
			narrow_key = int(key)
	var at: float = float(narrow_key) * 0.001
	var share: float = at / SHELL_HEIGHT
	check("the_narrowest_drawn_ring_is_the_throat",
		share > THROAT_SHARE_LOW and share < THROAT_SHARE_HIGH
			and absf(narrow_r - THROAT_RADIUS) < THROAT_RADIUS * 0.02,
		"narrowest drawn ring %.2f m across at %.2f m, which is %.4f of the shell"
			% [narrow_r * 2.0, at, share])


## REFIT THE HYPERBOLA FROM THE DRAWN RINGS, by the same closed-form least squares the photograph was
## measured with: r^2 is linear in (1, y, y^2) for a hyperboloid of one sheet and for nothing else. A cone
## or a pair of straight frusta comes back with a residual this cannot hide.
func _the_drawn_profile_refits_to_the_same_hyperbola(points: PackedVector3Array) -> void:
	var rings: Dictionary = {}
	for p in points:
		if p.y < CoolingTower.COLUMN_HEIGHT + 0.01:
			continue
		var key: int = int(round((p.y - CoolingTower.COLUMN_HEIGHT) * 1000.0))
		var r: float = Vector2(p.x, p.z).length()
		rings[key] = maxf(float(rings.get(key, 0.0)), r)
	var ys: Array[float] = []
	var rs: Array[float] = []
	for key in rings:
		ys.append(float(key) * 0.001)
		rs.append(float(rings[key]))
	if ys.size() < 4:
		check("the_drawn_profile_refits_to_the_same_hyperbola", false, "only %d rings drawn" % ys.size())
		return
	var fit: Dictionary = _fit_hyperbola(ys, rs)
	var throat_ok: bool = absf(float(fit["throat_radius"]) - THROAT_RADIUS) < THROAT_RADIUS * 0.01
	var at_ok: bool = absf(float(fit["throat_height"]) - THROAT_HEIGHT) < SHELL_HEIGHT * 0.01
	var b_ok: bool = absf(float(fit["b"]) - WAIST_CONSTANT) < WAIST_CONSTANT * 0.01
	check("the_drawn_profile_refits_to_the_same_hyperbola",
		throat_ok and at_ok and b_ok and float(fit["rms"]) < 0.05,
		"drawn rings refit to r_throat %.3f m at %.2f m with b %.3f m, rms %.4f m over %d rings"
			% [fit["throat_radius"], fit["throat_height"], fit["b"], fit["rms"], ys.size()])


## MEASURED FROM DRAWN VERTICES, never `transform * get_aabb()` -- a box round a box grows every time it is
## turned (`modelling_here.md` section 6).
func _the_drawn_bounds_are_the_published_envelope(points: PackedVector3Array) -> void:
	var low: float = 1e9
	var high: float = -1e9
	var widest: float = 0.0
	for p in points:
		low = minf(low, p.y)
		high = maxf(high, p.y)
		widest = maxf(widest, Vector2(p.x, p.z).length())
	var overall: float = CoolingTower.COLUMN_HEIGHT + SHELL_HEIGHT
	var pond: float = RING_BEAM_RADIUS + CoolingTower.POND_MARGIN
	check("the_drawn_bounds_are_the_published_envelope",
		absf(low) < 0.01 and absf(high - overall) < 0.05 and absf(widest - pond) < 0.05,
		"drawn from y %.2f to %.2f (overall %.2f) and out to %.2f m (pond %.2f)"
			% [low, high, overall, widest, pond])


## THE COLUMNS ARE NOT DECORATION: they are what puts daylight under a 90 m shell, and a tower drawn with
## its ring beam on the ground reads as a chimney whatever its waist does. So the check is that something is
## drawn BELOW the ring beam, out at about the ring beam's own radius, and that the shell's widest ring is
## at the ring beam rather than at the ground.
func _a_tower_stands_on_raked_columns(points: PackedVector3Array) -> void:
	var under: int = 0
	for p in points:
		var r: float = Vector2(p.x, p.z).length()
		if p.y > 0.5 and p.y < CoolingTower.COLUMN_HEIGHT - 0.5 and r > RING_BEAM_RADIUS * 0.9 \
				and r < RING_BEAM_RADIUS + CoolingTower.POND_MARGIN - 1.0:
			under += 1
	var widest_shell: float = 0.0
	var widest_at: float = 0.0
	for p in points:
		if p.y < CoolingTower.COLUMN_HEIGHT - 0.01:
			continue
		var r: float = Vector2(p.x, p.z).length()
		if r > widest_shell:
			widest_shell = r
			widest_at = p.y
	check("a_tower_stands_on_raked_columns",
		under >= CoolingTower.COLUMNS * 2 and absf(widest_at - CoolingTower.COLUMN_HEIGHT) < 0.01
			and absf(widest_shell - RING_BEAM_RADIUS) < 0.01,
		"%d column vertices under the ring beam; the shell is widest (%.2f m) at %.2f m"
			% [under, widest_shell, widest_at])


## A face wound backwards is invisible and nothing else will find it (`tests/ship_models.gd:_wound_outwards`).
## TWO CHECKS, BECAUSE THE OBVIOUS ONE IS A TAUTOLOGY AND A MUTANT PROVED IT. `_wound_outwards` asks whether
## each face's winding agrees with the normal stored beside it -- and `CoolingTower._face` chooses that normal
## FROM that winding, so the two can only agree. Flipping the one comparison in `_face` turns every triangle
## in the tower inside out and this suite printed RESULT=PASS (mutant 3, 2026-09-17). The check that catches
## it has to be anchored on something outside the builder's own bookkeeping, and here that is the tower's
## axis: the SHELL is convex about the axis everywhere, so no face of it may look inwards.
##
## THE SHELL ONLY, AND THE FIRST VERSION OF THIS CHECK FIRED ON EVERY MUTANT INCLUDING THE INNOCENT ONES,
## which is exactly as useless as firing on none. It asked the whole mesh -- and a raked column is a prism
## whose INNER face genuinely looks at the axis, as does the pond wall seen from inside, so 1 face in 6 was
## "inward" whatever the builder did. Above the ring beam the only thing drawn is the shell (the legs stop
## at `COLUMN_HEIGHT` exactly and the pond wall is 2.2 m tall), so the selection is a height and not a label.
func _every_face_is_wound_outwards(mesh: ArrayMesh) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var disagree: int = 0
	var inward: int = 0
	var shell: int = 0
	var total: int = 0
	for i in range(0, points.size() - 2, 3):
		var face: Vector3 = (points[i + 2] - points[i]).cross(points[i + 1] - points[i])
		total += 1
		if face.dot(normals[i]) < 0.0:
			disagree += 1
		var middle: Vector3 = (points[i] + points[i + 1] + points[i + 2]) / 3.0
		if middle.y <= CoolingTower.COLUMN_HEIGHT + 0.01:
			continue
		shell += 1
		var outward: Vector3 = Vector3(middle.x, 0.0, middle.z)
		if outward.length_squared() > 1e-9 and face.normalized().dot(outward.normalized()) < -0.01:
			inward += 1
	check("no_shell_face_looks_into_the_tower", inward == 0 and shell == CoolingTower.SIDES * CoolingTower.RINGS * 2,
		"%d of the %d shell faces above the ring beam, out of %d drawn" % [inward, shell, total])
	check("every_stored_normal_agrees_with_its_winding", disagree == 0 and total > 0,
		"%d of %d" % [disagree, total])


func _a_tower_is_one_draw_and_nobody_has_subdivided_it(mesh: ArrayMesh) -> void:
	var surfaces: int = mesh.get_surface_count()
	var triangles: int = 0
	for s in range(surfaces):
		triangles += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	check("a_tower_is_one_draw_and_nobody_has_subdivided_it",
		surfaces == 1 and triangles <= MOST_TRIANGLES,
		"%d triangles in %d surface, tripwire %d. The DRAW CALL runs out first: %d towers fit the first-LOD triangle budget and %d exhaust its %d draws. Two towers is %d triangles against the F/A-18F exterior's measured %d -- a proportion, not a frame cost."
			% [triangles, surfaces, MOST_TRIANGLES, FIRST_LOD_TRIANGLES / maxi(triangles, 1),
				FIRST_LOD_DRAWS, FIRST_LOD_DRAWS, triangles * 2, HORNET_EXTERIOR_TRIANGLES])


## THE ONE PIECE OF TUNING IN THIS PROJECT THAT ALREADY DECIDED WHERE SMOKE ENDS AND STEAM BEGINS.
## `FireYard.RISE_SECONDS` is 38 s, with the comment "slow enough to read as smoke rather than steam", so
## the other side of that line is a thing that can be asked for rather than guessed at.
##
## AND IT IS ASKED AS A RATE, WHICH IS THE WHOLE OF THE CHECK. 38 s is for a 260 m column and this plume is
## 179 m, so the two DURATIONS are not comparable and holding one against the other would have compared
## two different heights. Metres a second is what both files actually mean: the fire climbs at 6.8 m/s,
## which is the speed somebody decided reads as smoke. At the 22 s this plume was first written with it
## managed 8.1 m/s -- nineteen per cent faster, which is not visibly anything.
##
## BOTH SIDES ARE ASKED OF THEIR OWN FILE'S CONSTANTS, so neither can be moved without this noticing.
func _the_steam_climbs_faster_than_the_rate_tuned_to_read_as_smoke() -> void:
	var smoke: float = FireYard.COLUMN_HEIGHT / FireYard.RISE_SECONDS
	var steam: float = (CoolingTower.overall_height() * TowerPlume.CLIMBS) / TowerPlume.RISE_SECONDS
	check("the_steam_climbs_faster_than_the_rate_tuned_to_read_as_smoke",
		steam > smoke * STEAM_BEATS_SMOKE_BY,
		"steam %.1f m/s against the fire column's %.1f m/s, %.2f times over, wanted %.1f"
			% [steam, smoke, steam / smoke, STEAM_BEATS_SMOKE_BY])


## NO WARM-UP: THE PLUME IS WHOLE ON THE FIRST FRAME IT IS DRAWN. That is a thing a gallery needs to know
## and a property a later change could quietly remove. `lane/buildings` is photographing every building in
## the game, and a particle plume needs frames to develop -- a probe that screenshots on frame one gets an
## empty sky over the tower and no error at all.
##
## ASKED AS A STATIONARY PROPERTY, not as "it looks fine at zero": the puffs already span the whole column
## at `t = 0`, AND the plume's total strength is the same at every moment of the cycle. A plume that filled
## in over a few seconds would pass the first half of that and fail the second.
func _the_plume_is_whole_on_the_frame_it_is_first_drawn() -> void:
	var lip: float = CoolingTower.overall_height()
	var height: float = lip * TowerPlume.CLIMBS
	var strengths: Array[float] = []
	var lowest: float = 1.0
	var highest: float = 0.0
	for step in range(9):
		var at: float = TowerPlume.RISE_SECONDS * float(step) / 8.0
		var total: float = 0.0
		for i in range(TowerPlume.PUFFS):
			var puff: Dictionary = TowerPlume.puff_at(i, at, lip, CoolingTower.top_radius(), height,
				Vector3.ZERO)
			total += float(puff["alpha"])
			if step == 0:
				lowest = minf(lowest, float(puff["climbed"]))
				highest = maxf(highest, float(puff["climbed"]))
		strengths.append(total)
	var least: float = strengths[0]
	var most: float = strengths[0]
	for total in strengths:
		least = minf(least, total)
		most = maxf(most, total)
	var spread: float = (most - least) / maxf(least, 0.0001)
	check("the_plume_is_whole_on_the_frame_it_is_first_drawn",
		lowest < 0.001 and highest > 1.0 - 1.5 / float(TowerPlume.PUFFS) and spread < 0.02,
		"at t=0 the puffs already span %.3f to %.3f of the column, and the plume's total strength varies %.2f%% across a whole cycle, so there is nothing to wait for"
			% [lowest, highest, spread * 100.0])


## THE SOLID IS HELD AGAINST THE TRIANGLES, WITH NO ARITHMETIC IN BETWEEN. Every collision box corner must
## be inside the drawn mesh, and "the drawn mesh" here means the actual vertices: the rings are bucketed out
## of `points` exactly as the shape checks above do it, and a box is compared against the two rings its own
## band lies between -- which are drawn rings, because `collision_boxes` cuts on `ring_heights()`.
##
## THE TEST IS THE POLYGON'S, NOT THE CIRCLE'S. What is drawn is a twenty-sided prism, so a corner is inside
## when its projection on every edge normal is within the ring's inradius. Testing against the circle would
## pass a box that pokes through four of the flats.
##
## WHICH WAY THIS IS ALLOWED TO BE WRONG IS THE WHOLE POINT. A box inside the shell means a pilot clips the
## skin before the collision registers; a box outside it is an invisible wall in open air. This asserts the
## second can never happen, which is the half that can be stated as a property. `DEEPEST_CLIP` below bounds
## the first.
func _every_collision_box_is_inside_the_drawn_shell(points: PackedVector3Array) -> void:
	var rings: Dictionary = {}
	for p in points:
		if p.y < CoolingTower.COLUMN_HEIGHT + 0.01:
			continue
		var key: int = int(round(p.y * 1000.0))
		rings[key] = maxf(float(rings.get(key, 0.0)), Vector2(p.x, p.z).length())
	var outside: int = 0
	var worst: float = 0.0
	var corners: int = 0
	var inradius: float = cos(PI / float(CoolingTower.SIDES))
	for box in CoolingTower.collision_boxes():
		var middle: Vector3 = box["position"]
		var half: Vector3 = box["half_extents"]
		# The drawn rings this box's own band sits between, taken from the buckets and never computed.
		var narrowest: float = INF
		for key in rings:
			var y: float = float(key) * 0.001
			if y >= middle.y - half.y - 0.001 and y <= middle.y + half.y + 0.001:
				narrowest = minf(narrowest, float(rings[key]))
		if narrowest == INF:
			outside += 1
			continue
		var allowed: float = narrowest * inradius
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				corners += 1
				var corner := Vector2(sx * half.x, sz * half.z)
				# Inside a regular SIDES-gon of circumradius `narrowest`: every edge normal agrees.
				var furthest: float = 0.0
				for k in range(CoolingTower.SIDES):
					var normal := Vector2(cos(TAU * (float(k) + 0.5) / float(CoolingTower.SIDES)),
						sin(TAU * (float(k) + 0.5) / float(CoolingTower.SIDES)))
					furthest = maxf(furthest, corner.dot(normal))
				if furthest > allowed + 0.001:
					outside += 1
				worst = maxf(worst, furthest - allowed)
	check("every_collision_box_is_inside_the_drawn_shell", outside == 0 and corners > 0,
		"%d of %d box corners outside the drawn %d-gon; the furthest reaches %.3f m past its ring's flats"
			% [outside, corners, CoolingTower.SIDES, worst])
	check("the_polygon_allowance_matches_the_tessellation",
		absf(CoolingTower.SOLID_POLY - cos(PI / float(CoolingTower.SIDES))) < 0.0001,
		"SOLID_POLY %.5f against cos(PI / %d) = %.5f"
			% [CoolingTower.SOLID_POLY, CoolingTower.SIDES, cos(PI / float(CoolingTower.SIDES))])


## THE OTHER HALF OF THE APPROXIMATION, BOUNDED. Sweep every band and every bearing and find the furthest a
## body can get inside the shell before a box stops it. This is the number that would grow silently if
## somebody simplified the solid, and it is the reason the arrangement is three boxes a band and not one.
func _a_body_cannot_get_far_into_a_tower_before_it_is_stopped() -> void:
	var boxes: Array[Dictionary] = CoolingTower.collision_boxes()
	var deepest: float = 0.0
	for box in boxes:
		var middle: Vector3 = box["position"]
		var half: Vector3 = box["half_extents"]
		var mine: Array[Vector2] = []
		for other in boxes:
			var at: Vector3 = other["position"]
			if absf(at.y - middle.y) < 0.001:
				mine.append(Vector2((other["half_extents"] as Vector3).x,
					(other["half_extents"] as Vector3).z))
		# The shell is narrowest at a band end, so both ends are swept.
		for end in [middle.y - half.y, middle.y + half.y]:
			var shell: float = CoolingTower.radius_at(end - CoolingTower.COLUMN_HEIGHT)
			for step in range(181):
				var bearing: float = deg_to_rad(float(step) * 0.5)
				var reach: float = 0.0
				for size in mine:
					reach = maxf(reach, minf(size.x / maxf(absf(cos(bearing)), 1e-9),
						size.y / maxf(absf(sin(bearing)), 1e-9)))
				deepest = maxf(deepest, shell - minf(reach, shell))
	check("a_body_cannot_get_far_into_a_tower_before_it_is_stopped", deepest <= DEEPEST_CLIP,
		"the worst is %.2f m into a shell %.1f m across at its widest, against %.1f m allowed"
			% [deepest, CoolingTower.ring_beam_radius() * 2.0, DEEPEST_CLIP])


## THE STATION IS SOLID, AND WHAT IT COSTS IS A NUMBER RATHER THAN A FEELING. Both halves matter: a tower
## the simulation has never heard of is flown through, and a count nobody wrote down is how a piece of
## scenery quietly doubles the island's static boxes.
##
## AND IT IS CLEAR OF EVERY CLEARANCE, ASKED OF `Terrain` RATHER THAN TRUSTED. The towers go into the box
## list unfiltered, as the air bases and the gates do, so nothing would otherwise stop a later edit to the
## station's offset putting a 99 m shell on a runway approach.
func _the_station_is_solid_and_says_what_it_costs() -> void:
	var per_tower: int = CoolingTower.collision_boxes().size()
	var station: Array[Dictionary] = PowerStation.boxes()
	var sites: int = PowerStation.sites().size()
	check("the_station_is_solid_and_says_what_it_costs",
		per_tower == SOLID_BOXES and station.size() == SOLID_BOXES * sites and sites > 0,
		"%d boxes a tower, %d for %d towers, which is %.1f%% on top of the island's %d"
			% [per_tower, station.size(), sites,
				100.0 * float(station.size()) / float(ISLAND_BOXES), ISLAND_BOXES])
	# EVERY KEY IS ASKED FOR RATHER THAN DEFAULTED, and this is why. The first version of this check read
	# `clear.get("radius", 0.0)`. A clearance has no "radius" -- it has `half_extents` -- so every one of
	# the 628 of them was treated as a point, and the check only ever asked whether a tower's centre was
	# within 37 m of a clearance's centre. It passed, of course. That is CLAUDE.md rule 8 exactly: an
	# optional whose default lands on the floor is invisible to every counter, and the counter here was
	# "628 clearances asked of Terrain", which read like evidence.
	var fouled: PackedStringArray = []
	var malformed: int = 0
	var clearances: Array[Dictionary] = Terrain.clearances()
	var tall: float = CoolingTower.overall_height()
	var wide: float = CoolingTower.ring_beam_radius() + CoolingTower.POND_MARGIN
	for clear in clearances:
		if not clear.has("position") or not clear.has("half_extents"):
			malformed += 1
			continue
		var middle: Vector3 = clear["position"]
		var half: Vector3 = clear["half_extents"]
		for site in PowerStation.sites():
			var at: Vector3 = site["position"]
			# The tower is a cylinder from its pond to its lip; the clearance is a box. Nearest point on
			# the box to the axis, in plan, against the tower's widest radius -- and the heights must
			# overlap too, or a clearance 120 m up over a runway would foul a tower that is not there.
			var near := Vector2(
				clampf(at.x, middle.x - half.x, middle.x + half.x) - at.x,
				clampf(at.z, middle.z - half.z, middle.z + half.z) - at.z)
			var over: bool = at.y < middle.y + half.y and at.y + tall > middle.y - half.y
			if near.length() < wide and over:
				fouled.append("%s#%d is %.0f m into a %s clearance"
					% [site["station"], int(site["index"]), wide - near.length(),
						clear.get("why", &"?")])
	check("no_tower_stands_in_a_clearance", fouled.is_empty() and malformed == 0 and not clearances.is_empty(),
		"%d clearances asked of Terrain, %d without a position and half_extents%s"
			% [clearances.size(), malformed, "" if fouled.is_empty() else "; " + ", ".join(fouled)])


## THE ONLY CHECK HERE THAT PROVES A BODY IS STOPPED. Everything above proves that boxes of the right shape
## are in the right list; none of it proves the simulation does anything with them, and "a Dictionary
## reached a list" is precisely the shape of the carriage bug -- the ids were in `sky.gd` and every lookup
## returned nothing. So a fighter is flown at a tower in a bare `CockpitWorld` given the island's slab and
## every box `Terrain.boxes()` lists, which is the list the level walks for `Sim.add_static_box`. The
## arrangement is `tests/airbase.gd:_the_walls_stop_a_fighter_driven_into_them`.
##
## AND IT FLIES A CONTROL, WHICH IS THE HALF THAT MAKES IT ABLE TO FAIL. "The aeroplane did not come out the
## far side" is also what a spawn that never moved looks like, and what a world that refused the kind looks
## like. The same aeroplane on the same heading, offset clear of the pond, must pass the tower's station --
## so the run that stops has to stop for the reason claimed.
func _a_fighter_flown_at_a_tower_does_not_come_out_the_other_side() -> void:
	var sites: Array[Dictionary] = PowerStation.sites()
	if sites.is_empty() or not Sim.is_available():
		check("a_fighter_flown_at_a_tower_does_not_come_out_the_other_side", false,
			"%d sites, simulation available %s" % [sites.size(), Sim.is_available()])
		return
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(FLY_HZ)
	world.start(0)
	world.add_static_box(Vector3(0.0, -Terrain.GROUND_HALF.y, 0.0), Terrain.GROUND_HALF)
	var solid: Array[Dictionary] = Terrain.boxes()
	var ours: int = 0
	for box in solid:
		world.add_static_box(box["position"], box["half_extents"])
		ours += 1 if int(box.get("group", -1)) == Terrain.Group.TOWER else 0
	# STRAIGHT AT THE AXIS ALONG +X, and the same run again offset well clear of it.
	var at: Vector3 = sites[0]["position"]
	var yaw: float = PI * 0.5
	var pace: float = 140.0
	var runs: Array = [["at the tower", 0.0], ["clear of it", FLY_ASIDE]]
	var inputs: Dictionary = {}
	var client: int = 60
	for run in runs:
		client += 1
		var start := Vector3(at.x - FLY_FROM, at.y + FLY_HEIGHT, at.z + float(run[1]))
		var seat: Dictionary = world.spawn_pilot(client, Sim.Kind.FIGHTER, start, yaw,
			Vector3(pace, 0.0, 0.0))
		run.append(int(seat.get("vehicle", 0)))
		run.append(-INF)
		run.append(INF)
		run.append(0.0)
		run.append(0.0)
		inputs[int(seat.get("pilot", 0))] = {
			"throttle": FLY_THROTTLE, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
			"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
			"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
			"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
			"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0}
	for tick in range(int(FLY_SECONDS * FLY_HZ)):
		for pilot in inputs:
			world.set_pilot_input(pilot, inputs[pilot])
		world.tick(1.0 / FLY_HZ)
		for run in runs:
			var state: Dictionary = world.vehicle_state(run[2])
			var where: Vector3 = state.get("position", Vector3.ZERO)
			var reached: float = where.x - at.x
			run[3] = maxf(float(run[3]), reached)
			# WHERE IT WAS WHEN IT PASSED THE TOWER'S STATION, which is what says whether a run that went
			# through went through the SHELL or over the top of it.
			if absf(reached) < absf(float(run[4])):
				run[4] = reached
				run[5] = where.y - at.y
				run[6] = where.z - at.z
	var stopped: float = float(runs[0][3])
	var past: float = float(runs[1][3])
	check("a_fighter_flown_at_a_tower_does_not_come_out_the_other_side",
		ours == SOLID_BOXES * sites.size() and stopped < 0.0 and past > CoolingTower.ring_beam_radius(),
		("%d tower boxes in the solid list; flown at the axis it reached %.1f m past it (under 0 means it "
			+ "never crossed) and was %.1f m up and %.1f m to the side at its station, where the shell is "
			+ "%.1f m in radius; the control run offset %.0f m reached %.1f m past")
			% [ours, stopped, float(runs[0][5]), float(runs[0][6]),
				CoolingTower.radius_at(maxf(float(runs[0][5]) - CoolingTower.COLUMN_HEIGHT, 0.0)),
				FLY_ASIDE, past])


## ---- the helpers ---------------------------------------------------------------------------------

func _vertices(mesh: ArrayMesh) -> PackedVector3Array:
	var out: PackedVector3Array = []
	for s in range(mesh.get_surface_count()):
		out.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	return out


## LEAST SQUARES OF r^2 AGAINST (1, y, y^2), solved by 3x3 normal equations. The hyperboloid of one sheet is
## exactly `r^2 = A + B y + C y^2` with `C = (r_throat / b)^2`, `y_throat = -B / 2C` and
## `r_throat^2 = A - C y_throat^2`, so the fit is closed form and has nothing to converge to wrongly. This
## is the same arithmetic the Eggborough silhouette was measured with, which is the point: if the builder
## and the photograph are measured by one method, a disagreement between them is about the tower.
func _fit_hyperbola(ys: Array[float], rs: Array[float]) -> Dictionary:
	var m := PackedFloat64Array()
	m.resize(12)
	for i in range(ys.size()):
		var y: float = ys[i]
		var basis: Array[float] = [1.0, y, y * y]
		var value: float = rs[i] * rs[i]
		for a in range(3):
			for b in range(3):
				m[a * 4 + b] += basis[a] * basis[b]
			m[a * 4 + 3] += basis[a] * value
	# Gauss-Jordan on the 3x4 augmented matrix.
	for col in range(3):
		var pivot: int = col
		for row in range(col + 1, 3):
			if absf(m[row * 4 + col]) > absf(m[pivot * 4 + col]):
				pivot = row
		if pivot != col:
			for c in range(4):
				var swap: float = m[col * 4 + c]
				m[col * 4 + c] = m[pivot * 4 + c]
				m[pivot * 4 + c] = swap
		var lead: float = m[col * 4 + col]
		if absf(lead) < 1e-12:
			return {"throat_radius": 0.0, "throat_height": 0.0, "b": 0.0, "rms": 1e9}
		for c in range(4):
			m[col * 4 + c] /= lead
		for row in range(3):
			if row == col:
				continue
			var factor: float = m[row * 4 + col]
			for c in range(4):
				m[row * 4 + c] -= factor * m[col * 4 + c]
	var a0: float = m[3]
	var a1: float = m[7]
	var a2: float = m[11]
	if a2 <= 0.0:
		return {"throat_radius": 0.0, "throat_height": 0.0, "b": 0.0, "rms": 1e9}
	var at: float = -a1 / (2.0 * a2)
	var throat2: float = a0 + a1 * at + a2 * at * at
	if throat2 <= 0.0:
		return {"throat_radius": 0.0, "throat_height": 0.0, "b": 0.0, "rms": 1e9}
	var throat: float = sqrt(throat2)
	var squared: float = 0.0
	for i in range(ys.size()):
		var predicted: float = sqrt(maxf(a0 + a1 * ys[i] + a2 * ys[i] * ys[i], 0.0))
		squared += pow(rs[i] - predicted, 2.0)
	return {"throat_radius": throat, "throat_height": at, "b": throat / sqrt(a2),
		"rms": sqrt(squared / float(ys.size()))}
