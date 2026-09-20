extends Node
## Headless: is the C++ ground the ground phase 1 proved, to the bit, and does every tuned number change it?
##
##   Godot --headless --path cockpit res://tests/ground_field.tscn
##
## THE GROUND IS NOT REPLICATED (agents.md, RULES 8), so two peers whose ground differs by one tick of 1/32 m are two
## peers predicting into different hillsides, and nothing on screen says so. Phase 1 built the same integer function in
## stock GDScript, double GDScript and C++ and got the same SHA-256 from all three (godotgames-drafts/2026-09-14/
## cockpit-terrain/report.md, 3.2). The hashes below are this library's since each noise octave got its own lattice
## (2026-09-14: every octave had a corner at the origin, and the alpine world's highest ground was a needle standing on
## it), and again since the valley floors were rounded and the airfields became four to six (the 1,350 m world here has
## 11 towns, 15 lakes and 5 strips: 205 ints, from 178), recorded from the stock editor's build and matched by the
## double editor's. Run this on both: each loads its own build of the library, and each must print the same.
##
## - THE RECORDED WORLD. 9,584 points -- a 97 by 97 lattice over the square, both sides of zero and of lattice edges,
##   and round every lake and site -- hashed as the points, their heights, their water, and the catalogue.
## - THE BULK ANSWER IS THE POINT ANSWER. `heights()` over a grid equals `height_ticks_at` at every sample; the scenery
##   will be drawn from the first and the collision checked against the second.
## - A WORKER THREAD GETS THE SAME GROUND, because the scenery builds cells on worker threads.
## - EVERY TUNED NUMBER MOVES THE WORLD: another seed, lower ranges, a smaller square -- a knob that changes nothing is a
##   knob somebody will tune for an afternoon.
## - THE REFUSALS: an unknown key, a missing key, a value out of range and a value of the wrong type are each reported.
## - THE OPTIONAL KEYS (lane/testfield, 2026-09-19): `coast`, `sites_within` and `pads`, named at the values every recorded
##   world was built with, give the recorded hashes; at the test field's they take the sea away, keep every site inside
##   the reach, flatten an airport and cut its approaches to 34:1; and a malformed pad leaves no ground.
##
## Read RESULT=, not the exit code.

## The world the hashes were recorded on. Pinned here, not read from `GroundTuning`: the game's defaults are the user's
## to change, and a new default must not look like a broken function.
const RECORDED: Dictionary = {"world_half": 32000, "peak_height": 1350, "seed": 0}
const POINTS_SHA: String = "23302eaa43c3e49b8c993bd7d1c2defdca2e14db00b41091b72d53aa8b64f3b0"
const HEIGHTS_SHA: String = "f541846479110d5f55fecede39e9e1eb7419ecd59578007c26fd2b21096f71cd"
const WATER_SHA: String = "2fa4993c96077dc4af6566cbaa4b688105ab42a34b93e8731377b4755388f7e8"
const CATALOGUE_SHA: String = "55782c712ac5def877882d567c423dbbe07e928bc700c761ddb48556b6c92473"
const CATALOGUE_INTS: int = 205

var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[ground_field] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var exists: bool = ClassDB.class_exists("GroundField")
	_check("the_extension_has_a_ground_field", exists, "engine %s, double=%s" % [
		Engine.get_version_info()["string"], OS.has_feature("double")])
	if not exists:
		_finish()
		return
	var ground: Object = ClassDB.instantiate("GroundField")
	var began: int = Time.get_ticks_usec()
	var problems: PackedStringArray = ground.call("configure", RECORDED)
	_check("the_recorded_world_configures_with_no_complaint", problems.is_empty() and ground.call("is_configured"),
		"%s in %.1f ms" % [problems, float(Time.get_ticks_usec() - began) / 1000.0])
	_the_recorded_world(ground)
	_the_bulk_answer_is_the_point_answer(ground)
	await _a_worker_thread_gets_the_same_ground(ground)
	_every_tuned_number_moves_the_world()
	_the_refusals()
	_the_optional_keys()
	_check("every_section_of_the_suite_ran", _sections == 6, "%d of 6" % _sections)
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


static func _sha(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


## THE POINTS, built exactly as phase 1's `tests/terrain_probe.gd` built them, from this field's own catalogue: a
## catalogue that moved moves the points, which the points' own hash then says.
static func points(catalogue: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in range(97):
		for j in range(97):
			out.append(-32000 + i * 667)
			out.append(-31990 + j * 659)
	for x in [-17, -16, -15, -1, 0, 1, 15, 16, 17, 4095, 4096, -4096, -4097, 65535, -65536]:
		for z in [-1, 0, 1, -4097, 4096]:
			out.append(x)
			out.append(z)
	for lake in catalogue["lakes"]:
		for d in [0, 150, 333, 600]:
			out.append(int(lake["x"]) + d)
			out.append(int(lake["z"]) - d / 2)
	for site in (catalogue["towns"] as Array) + (catalogue["airfields"] as Array):
		for d in [0, 200, 450, 700, 1000]:
			out.append(int(site["x"]) - d)
			out.append(int(site["z"]) + d)
	return out


func _the_recorded_world(ground: Object) -> void:
	_sections += 1
	var at: PackedInt32Array = points(ground.call("catalogue"))
	var began: int = Time.get_ticks_usec()
	var heights: PackedInt32Array = ground.call("heights_at", at)
	var took_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	var water: PackedInt32Array = ground.call("waters_at", at)
	var catalogue: PackedInt32Array = ground.call("catalogue_ints")
	_check("the_points_are_the_recorded_points", _sha(at.to_byte_array()) == POINTS_SHA,
		"%d points, sha256 %s" % [at.size() / 2, _sha(at.to_byte_array())])
	_check("every_height_is_the_recorded_height", _sha(heights.to_byte_array()) == HEIGHTS_SHA,
		"sha256 %s; %.3f ms for %d, first five %s" % [_sha(heights.to_byte_array()), took_ms, heights.size(),
			heights.slice(0, 5)])
	_check("the_water_is_the_recorded_water", _sha(water.to_byte_array()) == WATER_SHA,
		"sha256 %s" % _sha(water.to_byte_array()))
	_check("the_catalogue_is_the_recorded_catalogue",
		_sha(catalogue.to_byte_array()) == CATALOGUE_SHA and catalogue.size() == CATALOGUE_INTS,
		"%d ints, sha256 %s" % [catalogue.size(), _sha(catalogue.to_byte_array())])


func _the_bulk_answer_is_the_point_answer(ground: Object) -> void:
	_sections += 1
	var lake: Dictionary = (ground.call("catalogue")["lakes"] as Array)[0]
	var wrong: int = 0
	var asked: int = 0
	# Round the first lake, and across both axes' zero, at a spacing that is not a power of two as well as one that is.
	for corner in [[int(lake["x"]) - 256, int(lake["z"]) - 256, 16], [-150, -150, 13]]:
		var grid: PackedInt32Array = ground.call("heights", corner[0], corner[1], 33, 25, corner[2])
		for j in range(25):
			for i in range(33):
				asked += 1
				if grid[j * 33 + i] != int(ground.call("height_ticks_at", corner[0] + i * corner[2],
						corner[1] + j * corner[2])):
					wrong += 1
	_check("heights_over_a_grid_are_height_ticks_at_each_sample", wrong == 0 and asked == 1650,
		"%d of %d differ" % [wrong, asked])


func _a_worker_thread_gets_the_same_ground(ground: Object) -> void:
	_sections += 1
	var at: PackedInt32Array = points(ground.call("catalogue"))
	var from_worker: Array = []
	var task: int = WorkerThreadPool.add_task(func() -> void: from_worker.append(ground.call("heights_at", at)))
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	var got: String = _sha((from_worker[0] as PackedInt32Array).to_byte_array()) if not from_worker.is_empty() else ""
	_check("a_worker_thread_gets_the_recorded_heights", got == HEIGHTS_SHA, "sha256 %s" % got)


## The highest ground and the share of land over the square on a 512 m lattice.
static func _survey(ground: Object) -> Dictionary:
	var half: int = int(ground.call("tuning")["world_half"])
	var n: int = 2 * half / 512 + 1
	var grid: PackedInt32Array = ground.call("heights", -half, -half, n, n, 512)
	var highest: int = -(1 << 30)
	var land: int = 0
	for h in grid:
		highest = maxi(highest, h)
		land += 1 if h > 0 else 0
	return {"highest": float(highest) / 32.0, "land_km2": float(land) * 0.512 * 0.512,
		"sha": _sha(grid.to_byte_array())}


func _every_tuned_number_moves_the_world() -> void:
	_sections += 1
	var recorded: Object = ClassDB.instantiate("GroundField")
	recorded.call("configure", RECORDED)
	var base: Dictionary = _survey(recorded)
	var seeded: Object = ClassDB.instantiate("GroundField")
	seeded.call("configure", {"world_half": 32000, "peak_height": 1350, "seed": 1})
	var other: Dictionary = _survey(seeded)
	_check("another_seed_is_another_world",
		other["sha"] != base["sha"] and (seeded.call("catalogue_ints") as PackedInt32Array) != recorded.call("catalogue_ints"),
		"seed 0: highest %.0f m, %.0f km2 of land; seed 1: %.0f m, %.0f km2" % [base["highest"], base["land_km2"],
			other["highest"], other["land_km2"]])
	var lower: Object = ClassDB.instantiate("GroundField")
	lower.call("configure", {"world_half": 32000, "peak_height": 700, "seed": 0})
	var low: Dictionary = _survey(lower)
	_check("lower_ranges_are_lower", float(low["highest"]) < float(base["highest"]) - 300.0,
		"peak_height 1350: highest %.0f m; 700: %.0f m" % [base["highest"], low["highest"]])
	var smaller: Object = ClassDB.instantiate("GroundField")
	smaller.call("configure", {"world_half": 20000, "peak_height": 1350, "seed": 0})
	var small: Dictionary = _survey(smaller)
	_check("a_smaller_square_holds_a_smaller_island", float(small["land_km2"]) < float(base["land_km2"]) * 0.6,
		"world_half 32000: %.0f km2 of land; 20000: %.0f km2" % [base["land_km2"], small["land_km2"]])


func _the_refusals() -> void:
	_sections += 1
	var ground: Object = ClassDB.instantiate("GroundField")
	var said: PackedStringArray = ground.call("configure", {"world_half": 32000, "peak_height": 1350, "seed": 0,
		"peak_hieght": 900})
	_check("an_unknown_key_is_reported_and_the_rest_still_configures",
		said.size() == 1 and said[0].contains("peak_hieght") and ground.call("is_configured"), "%s" % said)
	said = ground.call("configure", {"world_half": 32000, "peak_height": 1350})
	_check("a_missing_key_is_reported_and_leaves_no_ground",
		said.size() == 1 and said[0].contains("seed") and not ground.call("is_configured"), "%s" % said)
	said = ground.call("configure", {"world_half": 32000, "peak_height": 9999, "seed": 0})
	_check("a_value_out_of_range_is_clamped_and_reported",
		said.size() == 1 and said[0].contains("clamped to 3000") and int(ground.call("tuning")["peak_height"]) == 3000,
		"%s, tuning %s" % [said, ground.call("tuning")])
	said = ground.call("configure", {"world_half": 32000.0, "peak_height": 1350, "seed": 0})
	_check("a_value_of_the_wrong_type_is_reported_and_leaves_no_ground",
		said.size() == 1 and said[0].contains("not an int") and not ground.call("is_configured"), "%s" % said)


## THE TEST FIELD'S KIND OF GROUND, on alpine's square at peak 300: an airport pad 800 m by 4 km with an approach off each
## end, as `levels/testfield` lays its western one.
const PAD := {"rect": [-18400, -2000, -17600, 2000], "margin": 800,
	"funnels": [[-18000, 2000, 1, 18520, 600], [-18000, -2000, 3, 18520, 600]]}


func _the_optional_keys() -> void:
	_sections += 1
	# NAMED AT THEIR DEFAULTS, the recorded world, to the bit: the keys are additive.
	var named: Object = ClassDB.instantiate("GroundField")
	var said: PackedStringArray = named.call("configure", {"world_half": 32000, "peak_height": 1350, "seed": 0,
		"coast": 21, "sites_within": 0, "pads": []})
	var at: PackedInt32Array = points(named.call("catalogue"))
	var heights: String = _sha((named.call("heights_at", at) as PackedInt32Array).to_byte_array())
	var water: String = _sha((named.call("waters_at", at) as PackedInt32Array).to_byte_array())
	var catalogue: String = _sha((named.call("catalogue_ints") as PackedInt32Array).to_byte_array())
	_check("the_optional_keys_at_their_defaults_are_the_recorded_world",
		said.is_empty() and heights == HEIGHTS_SHA and water == WATER_SHA and catalogue == CATALOGUE_SHA,
		"%s; heights %s, water %s, catalogue %s" % [said, heights.left(12), water.left(12), catalogue.left(12)])
	# NO SEA: with the coast at 96 32nds every sample of the square is land and none is the sea's water.
	var island: Object = ClassDB.instantiate("GroundField")
	island.call("configure", {"world_half": 32768, "peak_height": 300, "seed": 0})
	var inland: Object = ClassDB.instantiate("GroundField")
	inland.call("configure", {"world_half": 32768, "peak_height": 300, "seed": 0, "coast": 96, "sites_within": 20500})
	var seas: Array[int] = []
	var lowest: Array[float] = []
	for ground in [island, inland]:
		var n: int = 2 * 32768 / 512 + 1
		var grid := PackedInt32Array()
		for j in range(n):
			for i in range(n):
				grid.append(-32768 + i * 512)
				grid.append(-32768 + j * 512)
		var waters: PackedInt32Array = ground.call("waters_at", grid)
		var lands: PackedInt32Array = ground.call("heights_at", grid)
		var sea: int = 0
		var low: int = 1 << 30
		for k in range(waters.size()):
			sea += 1 if waters[k] == 0 and lands[k] < 0 else 0
			low = mini(low, lands[k])
		seas.append(sea)
		lowest.append(float(low) / 32.0)
	_check("a_coast_at_96_leaves_no_sea_in_the_square", seas[1] == 0 and seas[0] > 1000,
		"sea samples on a 512 m lattice: coast 21 %d, coast 96 %d; lowest ground %.1f m and %.1f m" % [
			seas[0], seas[1], lowest[0], lowest[1]])
	# SITES WITHIN THE REACH: every town, lake and strip centre inside 20.5 km.
	var farthest: float = 0.0
	var sites: int = 0
	for group in ["towns", "lakes", "airfields"]:
		for site in inland.call("catalogue")[group]:
			sites += 1
			farthest = maxf(farthest, Vector2(float(site["x"]), float(site["z"])).length())
	_check("sites_within_keeps_every_site_inside_it", farthest <= 20500.0 and sites > 10,
		"%d sites, the farthest %.0f m from the middle" % [sites, farthest])
	# A PAD: flat at one level over its rectangle, no ground above 34:1 along either approach, and it bites where the
	# ground without it stands above that.
	var tuned: Dictionary = {"world_half": 32768, "peak_height": 300, "seed": 0, "coast": 96, "sites_within": 20500,
		"pads": [PAD]}
	var padded: Object = ClassDB.instantiate("GroundField")
	said = padded.call("configure", tuned)
	var pads: Array = padded.call("catalogue")["pads"]
	var level: int = int(pads[0]["level"]) / 32 if pads.size() == 1 else 0
	var off_level: int = 0
	for x in range(-18400, -17599, 50):
		for z in range(-2000, 2001, 100):
			off_level += 0 if int(padded.call("height_ticks_at", x, z)) == level else 1
	var over: Array[int] = [0, 0]
	var worst: float = -INF
	for side in [-1, 1]:
		for along in range(0, 18521, 40):
			for across in range(-600, 601, 50):
				var x: int = -18000 + across
				var z: int = side * (2000 + along)
				var cap: float = float(level) / 32.0 + float(along) / 34.0
				var with_pad: float = float(padded.call("height_ticks_at", x, z)) / 32.0
				var without: float = float(inland.call("height_ticks_at", x, z)) / 32.0
				worst = maxf(worst, with_pad - cap)
				over[0] += 1 if with_pad > cap + 1.0 / 32.0 else 0
				over[1] += 1 if without > cap + 1.0 / 32.0 else 0
	_check("a_pad_is_flat_and_its_approaches_clear_34_to_1",
		said.is_empty() and pads.size() == 1 and off_level == 0 and over[0] == 0 and over[1] > 0,
		"%s; level %.2f m, %d samples of the rectangle off it; along both finals %d samples above 34:1 with the pad, %d without; worst %.2f m" % [
			said, float(level) / 32.0, off_level, over[0], over[1], worst])
	# NO CUT STEEPER THAN THE NATURAL GROUND OR 1 IN 8 (lane/testfield, 2026-09-19): the pad and its funnels only ever take
	# the lower of the ground and a cone rising 1 in 8 off their edges (and 1 in 34 along a final), or for the pad the
	# ground held within 1 in 8 of its level, so between two samples 16 m apart the ground may change by no more than the
	# bare ground did there or by the cone's own rise, and a tick of rounding. The first cut was a 400 m smoothstep that
	# stood up to 49.9 degrees where a 300 m ridge crossed a final, and read from the air as a scar.
	var cone_rise: float = 16.0 * sqrt(1.0 / 64.0 + 1.0 / (34.0 * 34.0)) + 1.0 / 32.0
	var nx: int = 376
	var nz: int = 2876
	var padded_grid: PackedInt32Array = padded.call("heights", -21000, -23000, nx, nz, 16)
	var bare_grid: PackedInt32Array = inland.call("heights", -21000, -23000, nx, nz, 16)
	# THE SAME GROUND ON BOTH SIDES OF THE COMPARISON, bar the pad: a padded world catalogues its towns and lakes off the
	# pad and its finals and finds no strips of its own, so near any site of EITHER catalogue the bare ground is not the
	# ground the pad was laid on, and a town's or a strip's own blend there read as the pad's.
	var near_sites: Array[Vector3] = []
	for world in [padded, inland]:
		var listed: Dictionary = world.call("catalogue")
		for town in listed["towns"]:
			near_sites.append(Vector3(float(town["x"]), float(town["z"]), float(int(town["r"]) + int(town["margin"]) + 32)))
		for lake in listed["lakes"]:
			near_sites.append(Vector3(float(lake["x"]), float(lake["z"]), float(int(lake["water_radius"]) + 220)))
		for strip in listed["airfields"]:
			near_sites.append(Vector3(float(strip["x"]), float(strip["z"]),
				float(maxi(int(strip["half_long"]), int(strip["half_wide"])) + int(strip["margin"]) + 32)))
	var steeper: int = 0
	var cut: int = 0
	var skipped: int = 0
	var worst_degrees: float = 0.0
	for j in range(nz - 1):
		for i in range(nx - 1):
			var k: int = j * nx + i
			if padded_grid[k] == bare_grid[k]:
				continue
			var here := Vector2(-21000.0 + 16.0 * i, -23000.0 + 16.0 * j)
			var near_a_site: bool = false
			for site in near_sites:
				if here.distance_to(Vector2(site.x, site.y)) < site.z:
					near_a_site = true
					break
			if near_a_site:
				skipped += 1
				continue
			cut += 1
			for step in [1, nx]:
				var made: float = absf(float(padded_grid[k + step] - padded_grid[k])) / 32.0
				var natural: float = absf(float(bare_grid[k + step] - bare_grid[k])) / 32.0
				worst_degrees = maxf(worst_degrees, rad_to_deg(atan(made / 16.0)))
				if made > maxf(natural, cone_rise) + 1.0 / 32.0:
					steeper += 1
	_check("no_cut_is_steeper_than_the_ground_was_or_1_in_8",
		steeper == 0 and cut > 1000,
		"%d samples moved on a 16 m grid (%d more beside a site, not compared), %d steeper than the bare ground and the cone; the steepest step %.1f degrees" % [
			cut, skipped, steeper, worst_degrees])
	var crowding: int = 0
	for group in ["towns", "lakes", "airfields"]:
		for site in padded.call("catalogue")[group]:
			var sx: float = float(site["x"])
			var sz: float = float(site["z"])
			crowding += 1 if absf(sx + 18000.0) < 1400.0 and absf(sz) < 20520.0 else 0
	_check("no_site_is_catalogued_on_a_pad_or_its_approaches_and_a_padded_world_finds_no_strips",
		crowding == 0 and (padded.call("catalogue")["airfields"] as Array).is_empty(),
		"%d sites in the corridor, %d strips" % [crowding, (padded.call("catalogue")["airfields"] as Array).size()])
	# THE REFUSALS OF THE NEW KEYS.
	var refused: Object = ClassDB.instantiate("GroundField")
	said = refused.call("configure", {"world_half": 32768, "peak_height": 300, "seed": 0,
		"pads": [{"rect": [0, 0, 100], "margin": 100}]})
	_check("a_malformed_pad_is_reported_and_leaves_no_ground",
		said.size() == 1 and said[0].contains("rect") and not refused.call("is_configured"), "%s" % said)
	said = refused.call("configure", {"world_half": 32768, "peak_height": 300, "seed": 0, "coast": 500})
	_check("a_coast_out_of_range_is_clamped_and_reported",
		said.size() == 1 and said[0].contains("clamped to 128") and int(refused.call("tuning")["coast"]) == 128,
		"%s" % said)
	said = refused.call("configure", {"world_half": 32768, "peak_height": 300, "seed": 0, "sites_within": 1.5})
	_check("an_optional_key_of_the_wrong_type_leaves_no_ground",
		said.size() == 1 and said[0].contains("not an int") and not refused.call("is_configured"), "%s" % said)
