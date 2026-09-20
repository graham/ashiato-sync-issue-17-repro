extends Node
## THE WOODS: WHERE THEY ARE, WHAT GROWS IN THEM, THAT NOTHING IN THEM IS SOLID, AND THAT EVERY
## NUMBER ABOUT A TREE IS WRITTEN IN ONE PLACE.
##
##   Godot --headless --path cockpit res://tests/forest.tscn
##
## Headless, so it cannot say whether a forest LOOKS like one -- that is `scenery_shot`, on
## `forest_low` and `forest_high`. What it can say is everything a picture hides: a default that
## landed on a clamp's floor (a wood of three trees, in the right place), a tree standing in a
## runway approach, a tree the simulation thinks is a wall, and a number typed into a shader
## "just for now" that the tuning file then quietly stops reaching.
##
## THE GROUND IS ASKED OF `Terrain`, never restated here, and a tree is checked against the WHOLE
## keep-out list rather than the few boxes the planter narrowed it to -- a check that used the
## planter's own short list would agree with the planter about a box both of them had dropped.
##
## Read RESULT=, not the exit code.

## How much of each stand has to be ground a tree may stand on. A stand that is mostly carved away is
## a rectangle in the wrong place, and nothing but this number says so: the trees that are left all
## pass every other check. Four fifths, because the starting stands were placed on open ground and a
## corner clipping a fire's clearance is expected and a runway approach through the middle is not.
const LEAST_FREE: float = 0.8
## The lattice the free share is sampled on, in metres, and the half-size of the box tested at each
## point: about a tree, so the sample asks the question a tree will.
const SAMPLE_STEP: float = 20.0
const SAMPLE_HALF := Vector3(4.0, 12.0, 4.0)
## Every how-many-th tree is checked against the whole keep-out list. Every tree is fifteen thousand
## trees times eleven hundred boxes, about a minute of GDScript; one in seven is still two thousand
## trees spread over every chunk, and a planter that skipped its keep-outs fails on hundreds.
const TREE_SAMPLE: int = 7
## THE MOST CHUNKS THE STARTING WOODS MAY DRAW. Each chunk is one draw call, and the woods, the towns
## and the obstruction lights share at most 250 added draws in the worst view; the forest's share is
## eighty, which the two starting stands meet at 68 with 128 m chunks.
const MOST_CHUNKS: int = 80
## What a tuning number is multiplied by to see whether anything reads it. Not a round number, so a
## value that happens to be clamped or rounded back to where it was is unlikely.
const NUDGE: float = 1.37
## THE WOODS BEFORE THEY WERE THINNED, on the catalogue's stands, measured on HEAD c7a2e4e on 2026-09-14 -- asked for on
## 2026-09-13: "The forrest is too dense". And the most each finish may grow now: the count after, and five per cent. A
## number to beat and a ceiling, because "fewer" alone passes a wood thinned by one tree.
const TREES_BEFORE: Dictionary = {"plain": 5193, "fine": 11393}
const MOST_TREES: Dictionary = {"plain": 1986, "fine": 3956}
## How many slices of the band the edge check counts, outermost first.
const EDGE_SLICES: int = 6
## THE LEAST SHARE OF ITS TREES ANY PLACE IN THE MIDDLE OF A WOOD MAY KEEP. The promise the patches make -- thicker and
## thinner, never a glade (team-lead, 2026-09-13) -- written as the test's own number, not read back off the tuning, so a
## `patch_least` turned down to nothing fails here instead of passing beside itself.
const LEAST_PATCH: float = 0.5
## The side of a square of a wood's middle that must hold a tree, in metres.
const BARE_CELL: float = 50.0

const TUNING := preload("res://world/forest_tuning.gd")
const TREE_SHADER_SOURCE: String = "res://world/shaders/forest.gdshaderinc"
const FLOOR_SHADER_SOURCE: String = "res://world/shaders/forest_floor.gdshaderinc"
const GRASS_SHADERS: Array[String] = ["res://world/shaders/grass.gdshader",
	"res://world/shaders/grass_fine.gdshader"]

var _failures: PackedStringArray = []
var _sections: int = 0
const SECTIONS: int = 9


func _check(label: String, ok: bool, detail: String) -> void:
	print("[forest] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_an_entry_means_what_it_says()
	_a_stand_has_a_frame_of_its_own()
	_every_stand_is_on_open_ground()
	_every_tree_stands_where_a_tree_may()
	_the_edge_of_a_wood_thins_out()
	_a_wood_is_patchy_and_never_bare()
	_every_tuning_number_is_read_from_the_tuning_file()
	_no_shader_keeps_a_number_of_its_own()
	await _in_the_world_a_wood_is_only_a_picture()
	_check("every_section_of_the_suite_ran", _sections == SECTIONS,
		"%d of %d" % [_sections, SECTIONS])
	_finish()


## ---- the catalogue ---------------------------------------------------------------------

func _an_entry_means_what_it_says() -> void:
	var read: Array[Dictionary] = Forests.stands()
	_check("every_stand_in_the_catalogue_is_read", read.size() == Forests.STANDS.size()
		and read.size() >= 1, "%d of %d" % [read.size(), Forests.STANDS.size()])

	# THE DEFAULTS, AND NOT THE FLOORS. An entry that names only where and how big gets the density,
	# mix and heading this file says it does -- asserted as values, because "in range" is exactly
	# what a default that fell to the bottom of the range would also be.
	var bare: Dictionary = Forests.read_stand({"centre": Vector2(0.0, 0.0),
		"size": Vector2(100.0, 200.0)}, 99)
	_check("an_entry_that_says_nothing_else_takes_the_written_defaults", not bare.is_empty()
		and is_equal_approx(float(bare["density"]), Forests.DEFAULT_DENSITY)
		and is_equal_approx(float(bare["mix"]), Forests.DEFAULT_MIX)
		and is_equal_approx(float(bare["heading"]), Forests.DEFAULT_HEADING)
		and Forests.DEFAULT_DENSITY > 0.0,
		"%s" % [bare])

	# REFUSALS. Not half a forest: nothing, and a warning.
	var no_size: Dictionary = Forests.read_stand({"centre": Vector2(0.0, 0.0)}, 98)
	var no_ground: Dictionary = Forests.read_stand({"centre": Vector2(0.0, 0.0),
		"size": Vector2(0.0, 300.0)}, 97)
	_check("and_one_with_no_size_or_no_ground_grows_nothing", no_size.is_empty()
		and no_ground.is_empty(), "no size %s, zero width %s" % [no_size, no_ground])
	var greedy: Dictionary = Forests.read_stand({"centre": Vector2(0.0, 0.0),
		"size": Vector2(100.0, 100.0), "density": 9.0, "mix": -1.0}, 96)
	_check("and_a_density_or_mix_past_its_limit_is_held_to_it",
		is_equal_approx(float(greedy.get("density", -1.0)), Forests.MOST_DENSITY)
		and is_equal_approx(float(greedy.get("mix", -1.0)), 0.0),
		"asked 9.0 and -1.0, read %s and %s" % [greedy.get("density"), greedy.get("mix")])
	_sections += 1


## A STAND'S LONG SIDE POINTS WHERE A VEHICLE WITH THE SAME YAW WOULD. Checked against
## `Terrain.nose_from_yaw` at a quarter turn, where a swapped sign or a swapped axis cannot hide the
## way it does at zero -- the diagonal-spawn bug in terrain.gd was exactly that.
func _a_stand_has_a_frame_of_its_own() -> void:
	var turned: Dictionary = Forests.read_stand({"centre": Vector2(100.0, -50.0),
		"size": Vector2(40.0, 400.0), "heading": 90.0}, 95)
	var along: Vector3 = turned["along"]
	_check("a_stand_headed_a_quarter_turn_runs_the_way_a_vehicle_at_that_yaw_faces",
		along.is_equal_approx(Terrain.nose_from_yaw(PI * 0.5)) and absf(along.x + 1.0) < 0.001,
		"along %v" % along)
	# Its far end is inside it; the same distance across is not.
	var far_end: Vector3 = Vector3(100.0, 0.0, -50.0) + along * 190.0
	var off_side: Vector3 = Vector3(100.0, 0.0, -50.0) + (turned["across"] as Vector3) * 190.0
	_check("and_it_is_long_along_its_heading_and_narrow_across_it",
		Forests.contains(turned, far_end) and not Forests.contains(turned, off_side),
		"190 m along %s, 190 m across %s" % [Forests.contains(turned, far_end),
			Forests.contains(turned, off_side)])
	var local := Vector2(-13.0, 170.0)
	_check("and_a_point_goes_into_its_frame_and_back_unchanged",
		Forests.local_of(turned, Forests.world_of(turned, local)).is_equal_approx(local),
		"%v" % Forests.local_of(turned, Forests.world_of(turned, local)))
	_sections += 1


## ---- the ground ------------------------------------------------------------------------

## EVERY STAND IS INSIDE THE RING OF PEAKS, AND MOSTLY ON GROUND A TREE MAY STAND ON.
func _every_stand_is_on_open_ground() -> void:
	# The innermost the ring's rock reaches, asked of the ranges rather than typed.
	var ring_inside: float = MountainRanges.ring_inside()
	var island: Array[Dictionary] = Terrain.boxes()
	var keepouts: Array[Dictionary] = Terrain.ground_keepouts(island, Terrain.roads(island))
	var outside: PackedStringArray = []
	var crowded: PackedStringArray = []
	var shares: PackedStringArray = []
	for stand in Forests.stands():
		var half: Vector2 = stand["half"]
		for corner in [Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(half.x, -half.y),
				Vector2(-half.x, -half.y)]:
			if Forests.world_of(stand, corner).length() >= ring_inside:
				outside.append(String(stand["name"]))
				break
		var tried: int = 0
		var free: int = 0
		var x: float = -half.x + SAMPLE_STEP * 0.5
		while x < half.x:
			var y: float = -half.y + SAMPLE_STEP * 0.5
			while y < half.y:
				tried += 1
				if Terrain.is_clear(keepouts, Forests.world_of(stand, Vector2(x, y))
						+ Vector3.UP * SAMPLE_HALF.y, SAMPLE_HALF):
					free += 1
				y += SAMPLE_STEP
			x += SAMPLE_STEP
		var share: float = float(free) / maxf(float(tried), 1.0)
		shares.append("%s %.2f of %d" % [stand["name"], share, tried])
		if share < LEAST_FREE:
			crowded.append(String(stand["name"]))
	# EVERY CLEARANCE SAYS WHAT IT IS KEEPING CLEAR, so the towns' roads can cross the railway and nothing
	# else. A record with no `why` would be a keep-out a filter cannot see, and a road would go through it.
	var kinds: Dictionary = {}
	var untagged: int = 0
	for keep in Terrain.clearances():
		var why: StringName = keep.get("why", &"")
		if not why in [&"spawn", &"fire", &"runway", &"rail", &"gate", &"airbase"]:
			untagged += 1
		kinds[why] = int(kinds.get(why, 0)) + 1
	_check("every_clearance_says_which_of_the_six_things_it_keeps_clear",
		untagged == 0 and kinds.size() == 6, "%s, %d untagged" % [kinds, untagged])
	_check("every_stand_is_inside_the_ring_of_peaks", outside.is_empty(),
		"ring's inside edge %.0f m%s" % [ring_inside, "" if outside.is_empty() else ": %s" % outside])
	_check("and_at_least_%d_percent_of_each_is_ground_a_tree_may_stand_on" % int(LEAST_FREE * 100.0),
		crowded.is_empty() and not shares.is_empty(), ", ".join(shares))
	_sections += 1


## ---- the trees -------------------------------------------------------------------------

## EVERY TREE IS INSIDE ITS OWN STAND AND CLEAR OF EVERYTHING A TREE MAY NOT STAND IN, ON BOTH
## FINISHES; AND PLAIN'S WOOD IS FINE'S WITH TREES TAKEN OUT, NEVER A DIFFERENT WOOD.
func _every_tree_stands_where_a_tree_may() -> void:
	var stands: Array[Dictionary] = Forests.stands()
	var by_name: Dictionary = {}
	for stand in stands:
		by_name[String(stand["name"])] = stand
	var island: Array[Dictionary] = Terrain.boxes()
	var keepouts: Array[Dictionary] = Terrain.ground_keepouts(island, Terrain.roads(island))
	var fine: Dictionary = TUNING.for_tier(true, {})
	var plain: Dictionary = TUNING.for_tier(false, {})
	var forests: Dictionary = {
		"plain": Woodland.plant(stands, keepouts, plain, fine),
		"fine": Woodland.plant(stands, keepouts, fine, fine),
	}
	for finish_name in forests:
		var tuning: Dictionary = plain if finish_name == "plain" else fine
		var trees: int = 0
		var checked: int = 0
		var strays: PackedStringArray = []
		var standing_in: PackedStringArray = []
		for chunk in forests[finish_name]:
			var stand: Dictionary = by_name[String(chunk["stand"])]
			for tree in chunk["trees"]:
				trees += 1
				var foot: Vector3 = tree["position"]
				if not Forests.contains(stand, foot):
					strays.append("%v" % foot)
				if trees % TREE_SAMPLE != 0:
					continue
				checked += 1
				var height: float = float(tree["height"])
				var width: float = float(tuning["conifer_width" if float(tree["conifer"]) > 0.5
					else "broadleaf_width"])
				var radius: float = height * width * 0.5
				if not Terrain.is_clear(keepouts, foot + Vector3.UP * height * 0.5,
						Vector3(radius, height * 0.5, radius)):
					standing_in.append("%v" % foot)
		_check("the_%s_woods_have_trees" % finish_name, trees > 1000,
			"%d trees in %d chunks" % [trees, (forests[finish_name] as Array).size()])
		_check("and_the_%s_woods_have_fewer_trees_than_before_they_were_thinned" % finish_name,
			trees < int(TREES_BEFORE[finish_name]) and trees <= int(MOST_TREES[finish_name]),
			"%d trees, %d before, at most %d" % [trees, TREES_BEFORE[finish_name], MOST_TREES[finish_name]])
		_check("and_every_%s_tree_is_inside_its_own_stand" % finish_name, strays.is_empty(),
			"%d of %d outside%s" % [strays.size(), trees,
				"" if strays.is_empty() else ", first %s" % strays[0]])
		_check("and_none_stands_in_a_clearance_or_a_solid_box_on_%s" % finish_name,
			standing_in.is_empty() and checked > 100,
			"%d of %d checked against all %d keep-outs%s" % [standing_in.size(), checked, keepouts.size(),
				"" if standing_in.is_empty() else ", first %s" % standing_in[0]])
		_check("and_the_%s_woods_draw_in_at_most_%d_chunks" % [finish_name, MOST_CHUNKS],
			(forests[finish_name] as Array).size() <= MOST_CHUNKS,
			"%d chunks" % (forests[finish_name] as Array).size())

	# AND A STAND THAT DOES CROSS SOMETHING IS CARVED ROUND IT. The starting stands sit on open ground
	# -- every sample point above is free -- so on their own they would pass beside a planter that never
	# looked at a keep-out at all, and one did (the first RED run of this suite). This one is laid over
	# the inner south gate's corridor and the edge of the runway's approach clearance, both asked of
	# Terrain, and is planted twice: on the island, and on nothing.
	var crossing: Dictionary = Forests.read_stand({"name": "across_the_gate", "centre": Vector2(0.0, 900.0),
		"size": Vector2(300.0, 300.0)}, 91)
	var one: Array[Dictionary] = [crossing]
	var nothing: Array[Dictionary] = []
	var carved: int = 0
	var inside_something: int = 0
	for chunk in Woodland.plant(one, keepouts, fine, fine):
		for tree in chunk["trees"]:
			carved += 1
			var height: float = float(tree["height"])
			var width: float = float(fine["conifer_width" if float(tree["conifer"]) > 0.5
				else "broadleaf_width"])
			var radius: float = height * width * 0.5
			if not Terrain.is_clear(keepouts, (tree["position"] as Vector3) + Vector3.UP * height * 0.5,
					Vector3(radius, height * 0.5, radius)):
				inside_something += 1
	var bare: int = 0
	for chunk in Woodland.plant(one, nothing, fine, fine):
		bare += (chunk["trees"] as Array).size()
	_check("a_stand_laid_across_a_gate_and_a_runway_approach_is_carved_round_them",
		carved > 0 and float(carved) < float(bare) * 0.95 and inside_something == 0,
		"%d trees on the island against %d on bare ground, %d inside a keep-out" % [carved, bare,
			inside_something])

	# PLAIN IS A SUBSET OF FINE, BY POSITION.
	var fine_feet: Dictionary = {}
	for chunk in forests["fine"]:
		for tree in chunk["trees"]:
			fine_feet[_key_of(tree["position"])] = true
	var missing: int = 0
	var plain_trees: int = 0
	for chunk in forests["plain"]:
		for tree in chunk["trees"]:
			plain_trees += 1
			if not fine_feet.has(_key_of(tree["position"])):
				missing += 1
	_check("and_every_plain_tree_is_a_fine_tree_in_the_same_place", missing == 0 and plain_trees > 0,
		"%d of %d plain trees not in the fine wood" % [missing, plain_trees])
	_sections += 1


static func _key_of(at: Vector3) -> String:
	return "%.2f,%.2f" % [at.x, at.z]


## ---- the edge --------------------------------------------------------------------------

## THE EDGE OF A WOOD THINS OUT, SMOOTHLY, AND THE THINNING DOES NOT DRAW A SECOND RECTANGLE.
##
## Asked for by the user: "dither the amount of trees near the edge so that the falloff makes it a bit
## smoother", and on 2026-09-13 for more of it. A bare 800 m stand is planted with the band's wander off
## and its patches and clumps on, and its trees are counted in `EDGE_SLICES` rings of the band by distance
## in from the nearest side: each ring holds fewer trees a hectare than the one inside it, the outermost
## under a tenth of the middle's, and the trees there are shorter. Then with the wander on, the chance of
## keeping a tree half a band in has to move along a side -- and with it off, it must not, or the first
## half proves nothing.
func _the_edge_of_a_wood_thins_out() -> void:
	var fine: Dictionary = TUNING.for_tier(true, {})
	var straight: Dictionary = TUNING.for_tier(true, {"edge_wander": 0.0})
	var band: float = float(fine["edge_band"])
	var stand: Dictionary = Forests.read_stand({"name": "edge_wood", "centre": Vector2.ZERO,
		"size": Vector2(800.0, 800.0)}, 89)
	var one: Array[Dictionary] = [stand]
	var nothing: Array[Dictionary] = []
	var half: Vector2 = stand["half"]
	var counts: Array[int] = []
	var tall: Array[float] = []
	counts.resize(EDGE_SLICES)
	counts.fill(0)
	tall.resize(EDGE_SLICES)
	tall.fill(0.0)
	var core: int = 0
	var core_tall: float = 0.0
	for chunk in Woodland.plant(one, nothing, straight, straight):
		for tree in chunk["trees"]:
			var local: Vector2 = Forests.local_of(stand, tree["position"])
			var inward: float = minf(half.x - absf(local.x), half.y - absf(local.y))
			if inward >= band:
				core += 1
				core_tall += float(tree["height"])
				continue
			var slice: int = clampi(int(inward / band * float(EDGE_SLICES)), 0, EDGE_SLICES - 1)
			counts[slice] += 1
			tall[slice] += float(tree["height"])
	var area := func(inward: float) -> float:
		return (half.x * 2.0 - inward * 2.0) * (half.y * 2.0 - inward * 2.0)
	var core_density: float = float(core) / float(area.call(band))
	var shares: Array[float] = []
	var falls: bool = core > 0
	for slice in range(EDGE_SLICES):
		var ring: float = float(area.call(band * float(slice) / float(EDGE_SLICES))) \
			- float(area.call(band * float(slice + 1) / float(EDGE_SLICES)))
		shares.append(float(counts[slice]) / ring / maxf(core_density, 0.000001))
		if slice > 0:
			falls = falls and shares[slice] > shares[slice - 1]
	falls = falls and shares[0] < 0.10
	_check("a_wood_thins_ring_by_ring_towards_its_edge_to_under_a_tenth_of_its_middle",
		falls, "trees a hectare against the middle's, outermost ring first: %s (middle %d trees)" % [
			", ".join(PackedStringArray(shares.map(func(s): return "%.2f" % s))), core])
	var outer_trees: int = 0
	var outer_tall: float = 0.0
	for slice in range(EDGE_SLICES / 2):
		outer_trees += counts[slice]
		outer_tall += tall[slice]
	var edge_tall: float = outer_tall / maxf(float(outer_trees), 1.0)
	var middle_tall: float = core_tall / maxf(float(core), 1.0)
	_check("and_the_trees_at_the_edge_are_shorter",
		outer_trees > 0 and edge_tall < middle_tall * (1.0 - float(fine["edge_shrink"]) * 0.3),
		"%.1f m in the outer half of the band, %.1f m in the middle" % [edge_tall, middle_tall])

	# ALL FOUR SIDES OF THE SQUARE STAND, every `SAMPLE_STEP`. The wander is noise over one band's length along a side,
	# and with the band doubled to 140 m (2026-09-13) one side of this stand sampled a band apart left four places to
	# find it in: 0.18..0.37, under the check's 0.2, with the wander plainly there.
	var wandering: Array[float] = []
	var level: Array[float] = []
	var along: float = -half.y + band
	while along < half.y - band:
		for at in [Vector2(half.x - band * 0.5, along), Vector2(-half.x + band * 0.5, along),
				Vector2(along, half.y - band * 0.5), Vector2(along, -half.y + band * 0.5)]:
			wandering.append(Woodland.edge_keep(stand, at, fine, fine))
			level.append(Woodland.edge_keep(stand, at, straight, straight))
		along += SAMPLE_STEP
	_check("and_where_the_thinning_starts_wanders_along_a_side",
		wandering.max() - wandering.min() > 0.2 and level.max() - level.min() < 0.001,
		"half a band in, the chance runs %.2f..%.2f with the wander and %.2f..%.2f without, over %d places" % [
			wandering.min(), wandering.max(), level.min(), level.max(), wandering.size()])
	_sections += 1


## ---- the middle ------------------------------------------------------------------------

## A WOOD IS THICKER IN SOME PLACES THAN OTHERS, AND NEVER BARE IN THE MIDDLE.
##
## Asked for on 2026-09-13 with the thinning -- "less dense" -- and decided then as patches, not glades. A bare 1000 m
## stand, its middle taken as everything past the widest the band can wander to (at 800 m that middle was 7 squares by 7,
## too few to say "no square"). The chance `Woodland.thinning` keeps
## there is read on a 20 m grid and has to move by a quarter and never fall under `LEAST_PATCH`; and the stand is planted
## on FINE with nothing to carve round, and every `BARE_CELL` square of its middle has to hold a tree.
func _a_wood_is_patchy_and_never_bare() -> void:
	var fine: Dictionary = TUNING.for_tier(true, {})
	var stand: Dictionary = Forests.read_stand({"name": "patch_wood", "centre": Vector2.ZERO,
		"size": Vector2(1000.0, 1000.0)}, 88)
	var half: Vector2 = stand["half"]
	var middle: float = float(fine["edge_band"]) * (1.0 + float(fine["edge_wander"]))
	var least: float = INF
	var most: float = -INF
	var sampled: int = 0
	var x: float = -half.x + middle
	while x <= half.x - middle:
		var y: float = -half.y + middle
		while y <= half.y - middle:
			var kept: float = Woodland.thinning(stand, Vector2(x, y), fine)
			least = minf(least, kept)
			most = maxf(most, kept)
			sampled += 1
			y += SAMPLE_STEP
		x += SAMPLE_STEP
	_check("a_wood_is_thicker_in_some_places_than_others", sampled > 100 and most - least >= 0.25,
		"the chance kept runs %.2f..%.2f over %d places in the middle" % [least, most, sampled])
	_check("and_nowhere_in_its_middle_keeps_under_%d_percent_of_its_trees" % int(LEAST_PATCH * 100.0),
		sampled > 100 and least >= LEAST_PATCH, "least %.2f" % least)

	var one: Array[Dictionary] = [stand]
	var nothing: Array[Dictionary] = []
	var across: int = int(floor((half.x - middle) * 2.0 / BARE_CELL))
	var cells: Dictionary = {}
	for chunk in Woodland.plant(one, nothing, fine, fine):
		for tree in chunk["trees"]:
			var local: Vector2 = Forests.local_of(stand, tree["position"])
			var cell := Vector2i(int(floor((local.x + half.x - middle) / BARE_CELL)),
				int(floor((local.y + half.y - middle) / BARE_CELL)))
			if cell.x >= 0 and cell.y >= 0 and cell.x < across and cell.y < across:
				cells[cell] = int(cells.get(cell, 0)) + 1
	var fewest: int = 1 << 30
	var busiest: int = 0
	for i in range(across):
		for j in range(across):
			var here: int = int(cells.get(Vector2i(i, j), 0))
			fewest = mini(fewest, here)
			busiest = maxi(busiest, here)
	_check("and_no_%d_metre_square_of_its_middle_is_bare" % int(BARE_CELL),
		across * across >= 50 and fewest > 0,
		"%d squares: fewest %d trees, most %d" % [across * across, fewest, busiest])
	_sections += 1


## ---- one number, one place -------------------------------------------------------------

## CHANGE EVERY TUNING NUMBER IN TURN, AND THE WOOD HAS TO CHANGE WITH IT.
##
## "The wood" is everything the numbers can reach: the trees planted in a small stand, the tree
## shader's parameters, the floor's, the mesh, and a chunk as it would be drawn. A number nothing
## reads is a detail control that does nothing, and a number some script typed a copy of instead of
## reading it fails here the moment the tuning is changed.
func _every_tuning_number_is_read_from_the_tuning_file() -> void:
	var stand: Dictionary = Forests.read_stand({"name": "test_wood", "centre": Vector2(40.0, -40.0),
		"size": Vector2(260.0, 300.0), "heading": 20.0, "mix": 0.5}, 90)
	for fine in [false, true]:
		var base: Dictionary = TUNING.for_tier(fine, {})
		var was: String = _what_the_wood_is(stand, base, fine)
		var idle: PackedStringArray = []
		var tried: int = 0
		for key in base:
			var value: Variant = base[key]
			var nudged: Variant = null
			if value is Color:
				var colour: Color = value
				nudged = Color(colour.r * 0.7 + 0.1, colour.g * 0.7 + 0.1, colour.b * 0.7 + 0.1)
			elif value is float or value is int:
				# A zero is moved off zero, a whole number up by one (a count of tiers or sides, which a
				# multiply would round straight back), and anything else is multiplied.
				var number: float = float(value)
				if is_zero_approx(number):
					nudged = 1.0
				elif is_equal_approx(number, roundf(number)):
					nudged = number + 1.0
				else:
					nudged = number * NUDGE
			else:
				continue
			tried += 1
			if _what_the_wood_is(stand, TUNING.for_tier(fine, {key: nudged}), fine) == was:
				idle.append(String(key))
		_check("every_%s_tuning_number_changes_the_wood" % SceneryFinish.name_of(fine),
			idle.is_empty() and tried >= 20,
			"%d numbers tried%s" % [tried, "" if idle.is_empty() else ", these changed nothing: %s" % idle])
	_sections += 1


## Everything a tuning number can reach, written down, for one small stand.
func _what_the_wood_is(stand: Dictionary, tuning: Dictionary, fine: bool) -> String:
	var lattice: Dictionary = tuning if fine else TUNING.for_tier(true, {})
	var one: Array[Dictionary] = [stand]
	var nothing: Array[Dictionary] = []
	var chunks: Array[Dictionary] = Woodland.plant(one, nothing, tuning, lattice)
	var trees: Array = []
	for chunk in chunks:
		trees.append_array(chunk["trees"])
	var mesh: ArrayMesh = Woodland.tree_mesh(tuning)
	var drawn: Array = []
	if not chunks.is_empty():
		var node: MultiMeshInstance3D = Woodland.chunk_node(chunks[0], mesh,
			Woodland.paint_for(tuning, fine), tuning)
		drawn = [node.visibility_range_end, node.extra_cull_margin, node.multimesh.instance_count]
		node.free()
	# THE PATCHES AND THE CLUMPS AS NUMBERS, on a grid over the stand. A scale nudged by a metre moves the noise less than
	# any tree's rank needs to cross: `patch_scale`, 110 to 111, changed no tree in this stand (2026-09-14) while plainly
	# read. What the planter keeps a tree by is what a number has to reach.
	var kept: Array = []
	var half: Vector2 = stand["half"]
	for gx in range(-2, 3):
		for gy in range(-2, 3):
			kept.append(Woodland.thinning(stand, Vector2(half.x * 0.4 * float(gx), half.y * 0.4 * float(gy)), lattice))
	return var_to_str([chunks.size(), trees, kept, Woodland.tree_parameters(tuning, fine),
		Woodland.floor_parameters(one, tuning, fine), mesh.surface_get_array_len(0), drawn])


## NO FOREST SHADER HAS A NUMBER OF ITS OWN FOR ANYTHING THE TUNING DECIDES. Every uniform in the tree
## and floor includes is declared with no initialiser -- so an unset one is visibly unset, not quietly
## a guess -- every one the planter hands over is declared, and every declared one is used; and the
## floor's arrays are the length the tuning's `most_stands` says, and a catalogue past it is counted.
func _no_shader_keeps_a_number_of_its_own() -> void:
	# Each include, the uniforms it must declare, and the shaders a uniform may be USED in: the floor's
	# colour and strength are declared in its include and mixed in by the grass shaders that include it.
	for pair in [[TREE_SHADER_SOURCE, Woodland.TREE_UNIFORMS + Woodland.WIND_UNIFORMS, []],
			[FLOOR_SHADER_SOURCE, Woodland.FLOOR_UNIFORMS + Woodland.FINE_FLOOR_UNIFORMS, GRASS_SHADERS]]:
		var path: String = pair[0]
		var source: String = FileAccess.get_file_as_string(path)
		var and_where_used: String = source
		for includer in pair[2]:
			and_where_used += "\n" + FileAccess.get_file_as_string(String(includer))
		var declared := RegEx.new()
		declared.compile("(?m)^\\s*uniform\\s+\\w+\\s+(\\w+)(\\[\\d+\\])?\\s*(:[^=;]*)?(=[^;]*)?;")
		var names: PackedStringArray = []
		var initialised: PackedStringArray = []
		var unused: PackedStringArray = []
		for hit in declared.search_all(source):
			var name: String = hit.get_string(1)
			names.append(name)
			if not hit.get_string(4).is_empty():
				initialised.append(name)
			var said := RegEx.new()
			said.compile("\\b%s\\b" % name)
			if said.search_all(and_where_used).size() < 2:
				unused.append(name)
		var missing: PackedStringArray = []
		for name in pair[1]:
			if not names.has(String(name)):
				missing.append(String(name))
		_check("no_uniform_in_%s_has_a_value_of_its_own" % path.get_file(),
			initialised.is_empty() and names.size() >= 3,
			"%d uniforms%s" % [names.size(), "" if initialised.is_empty() else ", initialised: %s" % initialised])
		_check("and_every_one_is_used_and_every_tuning_uniform_is_declared_in_%s" % path.get_file(),
			unused.is_empty() and missing.is_empty(),
			"unused %s, not declared %s" % [unused, missing])
	var floor_source: String = FileAccess.get_file_as_string(FLOOR_SHADER_SOURCE)
	var length := RegEx.new()
	length.compile("uniform\\s+vec4\\s+forest_frame\\[(\\d+)\\]")
	var found: RegExMatch = length.search(floor_source)
	var plain_cap: int = int(TUNING.for_tier(false, {})["most_stands"])
	var fine_cap: int = int(TUNING.for_tier(true, {})["most_stands"])
	_check("and_the_floor_holds_as_many_stands_as_the_tuning_says",
		found != null and int(found.get_string(1)) == plain_cap and plain_cap == fine_cap,
		"shader %s, tuning %d plain and %d fine" % [found.get_string(1) if found != null else "none",
			plain_cap, fine_cap])

	# AND A CATALOGUE PAST THAT IS COUNTED, not silently cut: one stand more than the cap is one stand with
	# no floor, said so, and the real catalogue has none.
	var many: Array[Dictionary] = []
	for i in range(plain_cap + 1):
		many.append(Forests.read_stand({"centre": Vector2(float(i) * 50.0, 0.0),
			"size": Vector2(20.0, 20.0)}, 70 + i))
	var tuning: Dictionary = TUNING.for_tier(false, {})
	var painted: Dictionary = Woodland.floor_parameters(many, tuning, false)
	_check("and_a_catalogue_with_one_stand_past_the_cap_is_told_one_has_no_floor",
		Woodland.stands_past_the_floor(many, tuning) == 1
		and Woodland.stands_past_the_floor(Forests.stands(), tuning) == 0
		and int(painted["forest_count"]) == plain_cap
		and (painted["forest_frame"] as Array).size() == plain_cap,
		"%d stands: %d past the cap, floor count %d; the catalogue's %d: %d past" % [many.size(),
			Woodland.stands_past_the_floor(many, tuning), int(painted["forest_count"]),
			Forests.stands().size(), Woodland.stands_past_the_floor(Forests.stands(), tuning)])
	_sections += 1


## ---- in the world ----------------------------------------------------------------------

## THE WHOLE LEVEL: the woods are grown, they wear the finish, they cost nothing per frame, and the
## SIMULATION -- the authority on what is solid -- flies straight through them.
func _in_the_world_a_wood_is_only_a_picture() -> void:
	var boxes_before: int = Terrain.boxes().size()
	var level := (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(30):
		await get_tree().physics_frame
	var woods: Woodland = level.woodland
	_check("the_level_grows_the_woods", woods != null and woods.get_script() != null
		and int(woods.planted.get("plain_trees", 0)) > 1000
		and int(woods.planted.get("fine_trees", 0)) > int(woods.planted.get("plain_trees", 0)),
		"%s" % [woods.planted if woods != null else "no woodland"])
	_check("and_growing_them_added_no_box_to_the_island", Terrain.boxes().size() == boxes_before,
		"%d boxes before, %d after" % [boxes_before, Terrain.boxes().size()])

	# NOTHING SOLID, NOTHING PER FRAME, NO SHADOWS.
	var chunks: int = 0
	var shadowed: int = 0
	var solid: int = 0
	var busy: int = 0
	if woods != null:
		busy += 1 if woods.is_processing() or woods.is_physics_processing() else 0
		for node in woods.find_children("*", "", true, false):
			if node is CollisionObject3D or node is CollisionShape3D:
				solid += 1
			if node.is_processing() or node.is_physics_processing():
				busy += 1
			if node is MultiMeshInstance3D:
				chunks += 1
				if (node as MultiMeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					shadowed += 1
	_check("and_no_chunk_casts_a_shadow_or_holds_a_body_or_runs_a_frame",
		chunks > 0 and shadowed == 0 and solid == 0 and busy == 0,
		"%d chunks, %d shadowed, %d bodies, %d processing" % [chunks, shadowed, solid, busy])

	# THE FINISH, asked of the level the way the scenery suite asks every surface.
	var worn: Dictionary = level.finish_worn()
	_check("and_the_level_says_which_finish_the_woods_wear",
		worn.has("forest") and bool(worn["forest"]) == Finish.is_fine(),
		"worn %s, finish %s" % [worn.get("forest"), SceneryFinish.name_of(Finish.is_fine())])

	# THE AUTHORITY FLIES THROUGH A WOOD, and not through a tower: the same question, asked of the
	# simulation, both ways, or "clear" would mean nothing.
	if Sim.server == null:
		_check("there_is_a_simulation_to_ask", false, "no server")
	else:
		var through: PackedStringArray = []
		for stand in Forests.stands():
			var centre: Vector3 = stand["centre"]
			var along: Vector3 = stand["along"]
			var half: Vector2 = stand["half"]
			var from: Vector3 = centre - along * half.y * 0.9 + Vector3.UP * 8.0
			var to: Vector3 = centre + along * half.y * 0.9 + Vector3.UP * 8.0
			if not Sim.server.leg_is_clear(from, to, 2.0, 0.0):
				through.append(String(stand["name"]))
		_check("the_simulation_finds_a_leg_through_the_middle_of_every_wood_clear", through.is_empty(),
			"%s" % ["all %d stands, 8 m up, end to end" % Forests.stands().size() if through.is_empty()
				else "blocked through %s" % through])
		var tower: Dictionary = {}
		for box in Terrain.boxes():
			if int(box["group"]) == Terrain.Group.CONCRETE and (box["position"] as Vector3).y > 20.0:
				tower = box
				break
		var at: Vector3 = tower.get("position", Vector3.ZERO)
		_check("and_the_same_leg_through_a_tower_is_not",
			not tower.is_empty() and not Sim.server.leg_is_clear(
				Vector3(at.x - 200.0, 8.0, at.z), Vector3(at.x + 200.0, 8.0, at.z), 2.0, 0.0),
			"a 400 m leg through the tower at %v" % at)
	level.queue_free()
	await get_tree().process_frame
	Sim.stop()
	_sections += 1


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
