extends Node
## Headless: does the test field stand, with no sea anywhere, its edge band fitting, and every runway end it offers a final
## on clear to 10 NM?
##
##   Godot --headless --path cockpit res://tests/testfield.tscn
##
## The user, 2026-09-19: "Could we have a larger map (with no ocean) that has runways on either side for better testing?",
## then "with two large airports a military base and a small civilian airport." `levels/testfield` is 65.5 km of generated
## farmland at peak 300 with its coast pushed past the corners (`coast` 96) and its sites kept inside 20.5 km, and its
## runways are its own airfield files (`"world": "testfield"`), which the ground makes room for as PADS
## (`Airfield.pads_for`, `GroundTuning.for_level`).
##
## THE LEVEL IS ASKED FOR AS A PLAYER ASKS: `Net.choose_level("testfield")`, then the real flight level is added, as
## tests/terrain_level.gd does for alpine. Every check is against something the level did not compute:
##
## - ON THE DESK: the drawer lists the level, usable, with the ground numbers its file names.
## - ITS AIR IS ITS OWN: the depth fog is the time of day's clear air times the level's `haze`, the mist's haze and stratus
##   the same share of the presets, and every camera draws to the level's `reach` -- while the island's file says neither.
## - IT STANDS: both worlds build the same ground (their `ground_report`s field for field and hash for hash), and how long
##   the ground took and how many bytes it holds are printed.
## - NO SEA ANYWHERE: `has_sea` is false, a 256 m lattice over the whole wire square finds no sea's water, `open_sea_near`
##   finds none, and neither sea sheet is drawn.
## - THE EDGE BAND FITS: `WorldEdge.band_for` at the level's placed reach and the widest turn has no error, and its margin
##   to the last resort is printed.
## - THE RUNWAYS ARE THE FILES': six, none of the ground's own strips, each flat along its centreline at the level of its
##   pad, and their airports as far apart as step 0 said.
## - EVERY FINAL THE MAP OFFERS IS CLEAR: off every runway end whose 10 NM point lies inside the band's start, the ground
##   within 600 m of the extended centreline stands nowhere above the threshold plus 1 m in 34 out -- asked of the ground
##   the level stands on, not of the pad arithmetic. And exactly one end offers no final, East 27, whose 10 NM point is
##   past the wire; it is named in words.
##
## - THE AIRPORTS ARE LAID AND KEEP THEIR CLEARANCES: West, East and the air base are laid from their own files, and the
##   island's fighter base and Cape International are not. Each base holds the standard its own file cites, measured here
##   between rectangles this file works out: every parallel taxiway off every runway it serves, every wall and the tower
##   off every taxiway and taxilane, no wall in any served runway's object free area, and every stand fitting its craft
##   with a route to a hold bar. Every slab stands on its pad's level.
##
## - NO SHIP IS OFFERED, AND THE PAGE SAYS WHY: the rig's own CRAFT page, as the level handed it its rows, has no button
##   for a kind in the ships group and shows `VehicleCatalogue.NO_SEA_NOTE`; the same rows asked for a level with a sea
##   have ships in them, so the check can fail.
##
## - THE BASIC TRAFFIC FLIES ITS TRIPS: the level itself reads `levels/testfield/traffic.json` and sends its `basic`
##   list -- a 747 from West's remote stand to East's 09 and a Cessna round the small field --
##   and each one, flown by `AirportTraffic` through the levers, lands where it was sent and comes to a stop there within
##   TRIP_PATIENCE_S of simulation. Printed: how long each took and how many times it went around.
##
## - THE MOUNTAINS STAND: the level's own four ranges, the island's kind of rock (`LevelChart.mountains`), are in the
##   rock the level stands, each rising at least MOUNTAIN_RELIEF over the ground round it, and the simulation's own
##   collision finds the rock at each range's highest point. The finals check above samples the ground WITH the rock.
##
## - THE TAXIING TRAFFIC CROSSES THE GROUND'S SEAMS UNHARMED: after 90 s the 747 and the fighter the level sent from
##   their stands are whole and 100 m or more along their taxi. Before the ground's shapes were told not to make
##   speculative contacts (bedrock.cpp), both were destroyed 45 to 50 s in, every run, "struck its nose first at 4.1 m/s"
##   where two of Bedrock's 1,024 m height fields meet.
##
## - A FAST IMPACT ON A SEAM IS JUDGED AS ONE MID-CELL: speculative contact is what keeps a fast impact honest, and the
##   ground's shapes no longer make it. So piloted fighters are driven straight down into the air base's flat pad at 60
##   and at 120 m/s, on the corner where four 1,024 m fields meet and on one field's middle, and every one is stopped at
##   the ground (never more than IMPACT_SINK under it) and destroyed by the ground. A dive at 45 degrees was tried first
##   and never arrived: a craft is spawned level, so its wing pulled it out 65 m up.
##
## Read RESULT=, not the exit code.

const LEVEL: String = "testfield"
const PATIENCE: int = 3000
const TICKS: float = 32.0
## A final: 10 NM out, 600 m either side, sampled every FINAL_STEP along and FINAL_ACROSS across.
const FINAL: float = 18520.0
const FINAL_HALF: float = 600.0
const FINAL_STEP: float = 40.0
const FINAL_ACROSS: float = 50.0
## The runways step 0 laid, and the one end that can take no final.
const RUNWAYS: Array[String] = ["testfield_base_09_27", "testfield_east_09_27", "testfield_east_18_36",
	"testfield_ga_09_27", "testfield_west_36l", "testfield_west_36r"]
const NO_FINAL: String = "testfield_east_09_27 threshold"
## The bases the level lays, and the two the island's files lay on runways this level has not got.
const BASES: Array[String] = ["testfield_air_base", "testfield_east", "testfield_west"]
## How long the basic flights are given to land where they were sent, seconds of simulation: the 747's 35 km at about
## 100 m/s is six minutes in the air, with a taxi out and an instrument approach either side of it.
const TRIP_PATIENCE_S: float = 1800.0
const BASIC_FLIGHTS: int = 2
## How far a range must rise above the ground round it, metres, to count as a mountain and not a hill.
const MOUNTAIN_RELIEF: float = 300.0
## How long the taxiing traffic is watched, seconds of simulation, and how far each must have taxied from its stand.
const TAXI_WATCH_S: int = 90
const TAXI_AT_LEAST: float = 100.0
## How far under the ground a craft driven into it may be found, metres: its own half height and a tick of travel.
const IMPACT_SINK: float = 3.0
## How long before it meets the ground a driven craft is put in the air, seconds.
const IMPACT_LEAD_S: float = 2.5
const IMPACT_CLIENT: int = 900

## THE TRIPS ARE THEIR OWN SUITE, `testfield_traffic.tscn`, this script with `trips` on: three aeroplanes flying 20 to
## 36 km airport to airport take 25 to 40 minutes of simulation at 2.6 times real time, which no ordinary suite should
## wait on. With `trips` on it stands the level and flies the trips and nothing else.
@export var trips: bool = false

var _failures: PackedStringArray = []
var _sections: int = 0
var _finished: bool = false
var _level: FlightLevel = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[testfield] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var can: bool = ClassDB.class_exists("CockpitWorld") and ClassDB.class_exists("GroundField")
	_check("the_extension_has_the_ground_and_the_world", can, "engine %s, double=%s" % [
		Engine.get_version_info()["string"], OS.has_feature("double")])
	if not can:
		_finish()
		return
	_the_level_is_on_the_desk()
	Net.session_ended.connect(_on_a_session_ended)
	var chosen: String = Net.choose_level(LEVEL)
	_check("the_test_field_can_be_chosen", chosen == "", "'%s'" % chosen)
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	var frames: int = 0
	while frames < PATIENCE and not _finished and not (_level.ground_built_msec >= 0.0 and Sim.is_ready):
		await get_tree().process_frame
		frames += 1
	if _finished:
		return
	Net.session_ended.disconnect(_on_a_session_ended)
	var field: Object = Terrain.standing_on()
	_check("the_test_field_stands_and_comes_up", _level.ground_built_msec >= 0.0 and Sim.is_ready and field != null,
		"after %d frames: the ground stood in both worlds in %.0f ms" % [frames, _level.ground_built_msec])
	if field == null or Sim.server == null or Sim.client == null:
		_finish()
		return
	for i in range(30):
		await get_tree().process_frame
	if trips:
		await _the_basic_traffic_flies_its_trips()
		_check("the_trips_ran", _sections == 2, "%d of 2, the desk's and the trips'" % _sections)
		_finish()
		return
	_the_air_is_the_levels()
	_both_worlds_stand_on_the_same_ground()
	_there_is_no_sea(field)
	_a_world_with_no_sea_asks_for_no_ship_and_warns_of_none()
	_the_edge_band_fits()
	_the_runways_are_the_files(field)
	_every_final_is_clear(field)
	_every_glide_path_clears_the_rock()
	_the_mountains_stand(field)
	_the_airports_are_laid_and_keep_their_clearances(field)
	await _a_craft_taxis_across_a_ground_seam()
	await _a_fast_impact_on_a_seam_is_judged_as_one_mid_cell()
	_no_ship_is_offered_and_the_page_says_why()
	# EVERY SECTION BUT THE TRIPS, which are `testfield_traffic`'s.
	var sections: int = _sections_written() - 1
	_check("every_section_of_the_suite_ran", sections > 0 and _sections == sections, "%d of %d" % [_sections, sections])
	_finish()


func _sections_written() -> int:
	var written: int = 0
	for line in (get_script() as GDScript).source_code.split("\n"):
		if line.strip_edges() == "_sections += 1":
			written += 1
	return written


func _the_level_is_on_the_desk() -> void:
	var found: LevelChart = null
	for chart in ChartDrawer.charts():
		if (chart as LevelChart).id == LEVEL:
			found = chart
	_check("the_drawer_lists_the_test_field_usable", found != null and found.usable()
		and int(found.ground.get("coast", 0)) == 96 and int(found.ground.get("sites_within", 0)) == 20500,
		"%s" % ("not listed" if found == null else "%s, ground %s, refusal '%s'" % [found.name, found.ground,
			found.refusal]))
	_sections += 1


func _the_air_is_the_levels() -> void:
	var chart: LevelChart = _level.level
	var air: Environment = (_level.get_node("WorldEnvironment") as WorldEnvironment).environment
	var wanted_fog: float = float(_level.daylight.look["clear_air"]) * chart.haze
	var mist_haze: float = -1.0
	var wanted_mist: float = -1.0
	if _level.mist != null:
		mist_haze = _level.mist.haze
		wanted_mist = chart.haze
	var eyes: Array[String] = []
	var short: Array[String] = []
	for eye in _level.find_children("*", "Camera3D", true, false):
		if (eye as Camera3D).get_viewport() != _level.get_viewport():
			continue
		eyes.append(String(eye.name))
		if not is_equal_approx((eye as Camera3D).far, chart.reach):
			short.append("%s %.0f m" % [eye.name, (eye as Camera3D).far])
	var island: LevelChart = ChartDrawer.chart("island")
	_check("the_test_fields_air_is_its_own_and_the_islands_is_not_changed",
		chart.haze < 1.0 and is_equal_approx(air.fog_density, wanted_fog) and is_equal_approx(mist_haze, wanted_mist)
		and chart.reach >= 40000.0 and short.is_empty() and not eyes.is_empty()
		and island != null and is_equal_approx(island.haze, 1.0) and is_equal_approx(island.reach, 0.0),
		"haze %.2f: fog %.6f wanted %.6f, mist's share %.2f; %d eyes to %.0f m, short %s; the island's haze %.2f, reach %.0f" % [
			chart.haze, air.fog_density, wanted_fog, mist_haze, eyes.size(), chart.reach, short,
			island.haze if island != null else -1.0, island.reach if island != null else -1.0])
	_sections += 1


func _both_worlds_stand_on_the_same_ground() -> void:
	var server: Dictionary = Sim.server.ground_report()
	var client: Dictionary = Sim.client.ground_report()
	var same: bool = not server.is_empty() and int(server.get("fields", 0)) > 0
	for key in ["fields", "land_cells", "split_cells", "unheld_fields", "bytes", "hash"]:
		same = same and server.get(key) == client.get(key)
	_check("both_worlds_stand_on_the_same_ground", same, "server %s; %.1f MB a world" % [server,
		float(server.get("bytes", 0)) / 1048576.0])
	_sections += 1


func _there_is_no_sea(field: Object) -> void:
	var half: int = int((field.call("tuning") as Dictionary)["world_half"])
	var step: int = 256
	var n: int = 2 * half / step + 1
	var sea: int = 0
	var lakes: int = 0
	var lowest: int = 1 << 30
	for j in range(n):
		var row := PackedInt32Array()
		for i in range(n):
			row.append_array([-half + i * step, -half + j * step])
		var waters: PackedInt32Array = field.call("waters_at", row)
		var heights: PackedInt32Array = field.call("heights_at", row)
		for k in range(waters.size()):
			lowest = mini(lowest, heights[k])
			if waters[k] == 0 and heights[k] < 0:
				sea += 1
			elif waters[k] > Terrain.GROUND_TICKS_PER_METRE * -1000.0 and waters[k] >= heights[k] and waters[k] != 0:
				lakes += 1
	var sheet := _level.get_node_or_null("Sea") as Node3D
	var drawn: bool = (sheet != null and sheet.visible) or (_level.swell != null and _level.swell.visible)
	var coast: Vector3 = Terrain.open_sea_near(Vector3.ZERO, 1.0)
	_check("there_is_no_sea_anywhere_on_the_test_field",
		sea == 0 and not Terrain.has_sea() and coast == Vector3.INF and not drawn,
		"%d of %d samples of a %d m lattice are sea, %d are a lake's; lowest ground %.1f m; has_sea %s, open sea %s, a sea sheet drawn %s" % [
			sea, n * n, step, lakes, float(lowest) / TICKS, Terrain.has_sea(), coast, drawn])
	_sections += 1


## WARNS OF NOTHING IT NEVER ASKED FOR, AND PLACES NOTHING: a world with no sea drops the table's ships and the aircraft
## parked on them, and its brigs' pool is empty, all without a warning. lane/noplace, 2026-09-19: every spawn table built
## here printed "the hawkeye parked on ford is not placed: its carrier ford was not placed on this world" and the glider
## level, the same, "only 0 of 0 brig pool points have a leg with water the whole way". Warnings are counted through an
## engine Logger, so a mutant that restores either message fails this.
class WarningCounter extends Logger:
	var said: PackedStringArray = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array) -> void:
		if error_type == ERROR_TYPE_WARNING:
			said.append(rationale if rationale != "" else code)


func _a_world_with_no_sea_asks_for_no_ship_and_warns_of_none() -> void:
	var counter := WarningCounter.new()
	OS.add_logger(counter)
	var table: Array[Dictionary] = Terrain.spawns()
	var pool: Array[Vector3] = Terrain._waypoints_on_the_ground(Sim.Kind.PIRATE)
	# THE ISLAND'S BASES ARE NOT THIS LEVEL'S: laid again, under the logger, they are left out without a "no runway" warning
	# (the fighter base's `"runway": 0` printed "no runway 0.0", the cape's "cape_09_27", on every level with its own files).
	AirbasePlan._laid_ready = false
	AirbasePlan.bases()
	AirbasePlan._laid_ready = false
	OS.remove_logger(counter)
	var ships: Array[String] = []
	for spawn in table:
		if Terrain.is_a_ship(int(spawn["kind"])) or spawn.get("place", &"") == &"carrier":
			ships.append("%s %s" % [Sim.kind_name(int(spawn["kind"])), spawn.get("name", &"")])
	var complaints: PackedStringArray = []
	for line in counter.said:
		if "not placed" in line or "brig pool" in line or "has no runway" in line:
			complaints.append(line)
	_check("a_world_with_no_sea_places_no_ship_and_warns_of_none",
		not Terrain.has_sea() and ships.is_empty() and pool.is_empty() and complaints.is_empty(),
		"has_sea %s; %d spawns, ships or things parked on them %s; brig pool %d; warnings about them %s" % [
			Terrain.has_sea(), table.size(), ships, pool.size(), complaints])
	# AND A RUNWAY NO FILE NAMES IS STILL A MISTAKE, said: the same check on a base naming one, by a name that is nobody's.
	var strayed: bool = AirbasePlan._is_another_worlds("no_such_runway_anywhere")
	var another: bool = AirbasePlan._is_another_worlds("cape_09_27") and AirbasePlan._is_another_worlds(0.0)
	_check("a_runway_no_airfield_file_names_is_not_another_worlds",
		not strayed and another, "a nobody's name is another world's %s; the island's own two are %s" % [strayed, another])
	_sections += 1


func _the_edge_band_fits() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	var fastest: float = 0.0
	for row in world.turn_radii():
		fastest = maxf(fastest, float((row as Dictionary)["speed"]))
	var worst: float = float(world.worst_turn_radius())
	var guard_from: float = float((world.boundary() as Dictionary)["guard_from"])
	var band: Dictionary = WorldEdge.band_for(Terrain.placed_reach(), worst, guard_from, fastest)
	var margin: float = guard_from - (float(band["start"]) + 2.0 * worst)
	_check("the_edge_band_fits", String(band["error"]) == "" and margin > 0.0,
		"placed within %.0f m, the band from %.0f m, warned from %.0f m, %.0f m deep; fits the last resort at %.0f m by %.0f m%s" % [
			Terrain.placed_reach(), band["start"], band["warn_from"], band["depth"], guard_from, margin,
			"" if String(band["error"]) == "" else "; " + String(band["error"])])
	_sections += 1


func _the_runways_are_the_files(field: Object) -> void:
	var catalogue: Dictionary = field.call("catalogue")
	var ours: Array[String] = []
	var off_level: Array[String] = []
	for frame in Terrain.runways():
		ours.append(String(frame.get("field", "a strip of the ground's own")))
		var centre: Vector3 = frame["centre"]
		var along: Vector3 = frame["along"]
		var worst: float = 0.0
		for k in range(21):
			var at: Vector3 = centre + along * float(frame["length"]) * (float(k) / 20.0 - 0.5)
			worst = maxf(worst, absf(float(int(field.call("height_ticks_at", roundi(at.x), roundi(at.z)))) / TICKS
				- centre.y))
		if worst > 1.0 / TICKS:
			off_level.append("%s %.2f m" % [frame.get("field", "?"), worst])
	ours.sort()
	_check("the_runways_are_the_six_files_on_flat_pads",
		ours == RUNWAYS and off_level.is_empty() and (catalogue["airfields"] as Array).is_empty()
		and (catalogue["pads"] as Array).size() == 4,
		"%s; %d pads at %s; off level: %s" % [ours, (catalogue["pads"] as Array).size(),
			(catalogue["pads"] as Array).map(func(p: Dictionary) -> String: return "%.1f m" % (float(p["level"]) / 1024.0)),
			off_level])
	var fields: Dictionary = {}
	for field_here in Airfield.here():
		fields[String(field_here["id"])] = (field_here["frame"] as Dictionary)["centre"]
	var names := {"west": "testfield_west_36l", "east": "testfield_east_18_36", "base": "testfield_base_09_27",
		"small field": "testfield_ga_09_27"}
	var apart: Array[String] = []
	var keys: Array = names.keys()
	for a in range(keys.size()):
		for b in range(a + 1, keys.size()):
			if fields.has(names[keys[a]]) and fields.has(names[keys[b]]):
				var d: float = Vector2((fields[names[keys[a]]] as Vector3).x - (fields[names[keys[b]]] as Vector3).x,
					(fields[names[keys[a]]] as Vector3).z - (fields[names[keys[b]]] as Vector3).z).length()
				apart.append("%s-%s %.1f km" % [keys[a], keys[b], d / 1000.0])
	_check("every_airfield_is_here_and_the_trips_are_real", apart.size() == 6, ", ".join(apart))
	_sections += 1


func _every_final_is_clear(field: Object) -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	var fastest: float = 0.0
	for row in world.turn_radii():
		fastest = maxf(fastest, float((row as Dictionary)["speed"]))
	var band: Dictionary = WorldEdge.band_for(Terrain.placed_reach(), float(world.worst_turn_radius()),
		float((world.boundary() as Dictionary)["guard_from"]), fastest)
	var clear: Array[String] = []
	var blocked: Array[String] = []
	var no_final: Array[String] = []
	for frame in Terrain.runways():
		var along: Vector3 = frame["along"]
		var across: Vector3 = frame["across"]
		for end in ["threshold", "far_end"]:
			var at: Vector3 = frame[end]
			# THE FINAL RUNS OUT FROM THE END IT LANDS ON, away from the runway.
			var out: Vector3 = -along if end == "threshold" else along
			var name: String = "%s %s" % [frame.get("field", "?"), end]
			if WorldEdge.out(at + out * FINAL) >= float(band["start"]):
				no_final.append(name)
				continue
			var worst: float = -INF
			var s: float = 0.0
			while s <= FINAL:
				var t: float = -FINAL_HALF
				while t <= FINAL_HALF:
					var p: Vector3 = at + out * s + across * t
					# THE GROUND AND THE ROCK ON IT: the level's mountains too (`Terrain.ground_height`).
					var ground: float = Terrain.ground_height(p)
					worst = maxf(worst, ground - (at.y + s / 34.0))
					t += FINAL_ACROSS
				s += FINAL_STEP
			if worst > 1.0 / TICKS:
				blocked.append("%s %.1f m above 34:1" % [name, worst])
			else:
				clear.append("%s (%.1f m under)" % [name, -worst])
	_check("every_final_the_map_offers_is_clear_to_10_nm_at_34_to_1", blocked.is_empty() and clear.size() == 11,
		"%d clear: %s; blocked: %s" % [clear.size(), ", ".join(clear), blocked])
	_check("exactly_one_end_offers_no_final_east_27_past_the_wire", no_final == [NO_FINAL],
		"no final inside the band's start at %.0f m: %s" % [band["start"], no_final])
	_sections += 1


## THE INSTRUMENT GLIDE PATH DOWN EVERY FIELD THE LEVEL HAS clears the level's rock, walked by the same `FinalWalk` the island's
## suite uses, over `Airfield.here()`: what the level's files lay, not a list typed here. The count is the files' own.
func _every_glide_path_clears_the_rock() -> void:
	var rock: Object = Terrain.mountains()
	var fields: Array[Dictionary] = Airfield.here()
	var words := PackedStringArray()
	var blocked := PackedStringArray()
	for laid in fields:
		var walked: Dictionary = FinalWalk.of(laid, rock)
		words.append("%s %.0f m" % [laid["id"], float(walked["least"])])
		if float(walked["least"]) <= 0.0:
			blocked.append("%s %.0f m at %s" % [laid["id"], float(walked["least"]), walked["at"]])
	_check("every_glide_path_on_the_level_clears_the_rock_within_600_m_of_the_centreline",
		rock != null and fields.size() == Airfield.new_runways(LEVEL).size() and blocked.is_empty(),
		"%d fields: %s; blocked: %s" % [fields.size(), ", ".join(words), ", ".join(blocked)])
	_sections += 1


func _a_craft_taxis_across_a_ground_seam() -> void:
	# THE LEVEL'S OWN TAXIING TRAFFIC, 90 s of it: every aeroplane it sent from a stand (the 747; the fighter too, until it
	# left the basic list). On the library before
	# the fix both were destroyed 45 to 50 s in, every run, at a seam; driven straight across one by hand, a fighter was
	# struck only some of the time, so the check is the taxi that always failed.
	var plan: TrafficPlan = _level.traffic_plan
	var starts: Dictionary = {}
	if plan != null:
		for entity in plan.flights:
			starts[entity] = (Sim.server.vehicle_state(int(entity)).get("position", Vector3.ZERO) as Vector3)
	var ticks: int = 0
	while plan != null and ticks < TAXI_WATCH_S * 120:
		await get_tree().physics_frame
		ticks += 1
	var words: PackedStringArray = []
	var taxied: int = 0
	var taxiing: int = 0
	if plan != null:
		for entity in plan.flights:
			var kind: int = int(plan.flights[entity]["kind"])
			if kind == Sim.Kind.CESSNA:
				continue
			taxiing += 1
			var state: Dictionary = Sim.server.vehicle_state(int(entity))
			var moved: float = ((state.get("position", Vector3.INF) as Vector3) - (starts[entity] as Vector3)).length() \
				if not state.is_empty() else 0.0
			var whole: bool = not state.is_empty() and not bool(Sim.server.hull_state(int(entity)).get("destroyed", true))
			taxied += 1 if whole and moved >= TAXI_AT_LEAST else 0
			words.append("%s %s, %.0f m from its stand, %s" % [Sim.kind_name(kind), "whole" if whole else "DESTROYED",
				moved, _level.airport_traffic.record_of(int(entity)).get("phase", "?")])
	_check("the_taxiing_traffic_crosses_the_ground_s_seams_unharmed", taxiing >= 1 and taxied == taxiing,
		"after %d s: %s" % [TAXI_WATCH_S, "; ".join(words) if plan != null else "no traffic"])
	_sections += 1


func _a_fast_impact_on_a_seam_is_judged_as_one_mid_cell() -> void:
	var kind: int = Sim.Kind.FIGHTER
	# THE CORNER x 0, z -14,336, and a field's middle in x 512 m off it and 114 m off the z seam, both on the flat pad.
	var places: Array = [["seam", Vector3(0.0, 0.0, -14336.0)], ["mid-cell", Vector3(512.0, 0.0, -14450.0)]]
	var ways: Array = [["straight down at 60 m/s", Vector3(0.0, -60.0, 0.0)],
		["straight down at 120 m/s", Vector3(0.0, -120.0, 0.0)]]
	var runs: Array = []
	for place in places:
		for way in ways:
			var ground: float = Terrain.land_height(place[1])
			var velocity: Vector3 = way[1]
			# PUT WHERE IT MEETS THE GROUND AT THE PLACE ABOUT IMPACT_LEAD_S LATER: past the settling a new craft is given,
			# and with nobody flying it, so no autopilot pulls it out of the dive.
			var start: Vector3 = (place[1] as Vector3) - velocity * IMPACT_LEAD_S
			start.y = ground - velocity.y * IMPACT_LEAD_S
			# A PILOT IN IT, as tests/crashes.gd flies its drops: a craft nobody sits in is not judged by the crash rule. A
			# client number of the suite's own, well past any real one.
			var made: Dictionary = Sim.server.spawn_pilot(IMPACT_CLIENT + runs.size(), kind, start,
				AirbasePlan.yaw_facing(Vector3(1.0, 0.0, 0.0)), velocity)
			runs.append({"what": "%s %s" % [place[0], way[0]], "entity": int(made.get("vehicle", 0)),
				"pilot": int(made.get("pilot", 0)), "ground": ground, "lowest": INF})
	for tick in range(int((IMPACT_LEAD_S + 3.0) * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
		for run in runs:
			var state: Dictionary = Sim.server.vehicle_state(int(run["entity"]))
			if not state.is_empty():
				run["lowest"] = minf(float(run["lowest"]), (state["position"] as Vector3).y)
	var words: PackedStringArray = []
	var right: int = 0
	for run in runs:
		var hull: Dictionary = Sim.server.hull_state(int(run["entity"]))
		var below: float = float(run["ground"]) - float(run["lowest"])
		var judged: bool = bool(hull.get("destroyed", false)) and String(hull.get("cause_name", "")) == "ground"
		right += 1 if judged and below <= IMPACT_SINK else 0
		words.append("%s: %s, lowest %.1f m under the ground" % [run["what"],
			"destroyed by the ground" if judged else "NOT judged (%s)" % hull.get("cause_name", "no hull"), below])
		Sim.server.despawn_pilot(int(run["pilot"]))
		Sim.server.despawn_vehicle(int(run["entity"]))
	_check("a_fast_impact_on_a_seam_is_judged_as_one_mid_cell", right == runs.size(), "; ".join(words))
	_sections += 1


func _the_mountains_stand(field: Object) -> void:
	var rock: Object = Terrain.mountains()
	var words: PackedStringArray = []
	var standing: int = 0
	var ranges: Array[Dictionary] = _level.level.mountains
	for range in ranges:
		var points: PackedInt32Array = range["points"]
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for k in range(0, points.size(), 4):
			lo = Vector2(minf(lo.x, points[k] - points[k + 3]), minf(lo.y, points[k + 1] - points[k + 3]))
			hi = Vector2(maxf(hi.x, points[k] + points[k + 3]), maxf(hi.y, points[k + 1] + points[k + 3]))
		var top: float = float(rock.call("highest_over", lo.x, lo.y, hi.x, hi.y)) if rock != null else -INF
		# WHERE THE TOP IS, on a 32 m grid over the range's box, and the ground round it at the box's corners.
		var peak := Vector3.ZERO
		var best: float = -INF
		var x: float = lo.x
		while x <= hi.x and rock != null:
			var z: float = lo.y
			while z <= hi.y:
				var h: float = float(rock.call("surface_at", x, z))
				if h > best:
					best = h
					peak = Vector3(x, h, z)
				z += 32.0
			x += 32.0
		var ground: float = float(int(field.call("height_ticks_at", roundi(peak.x), roundi(peak.z)))) / TICKS
		# THE SIMULATION'S OWN RAY, from 50 m over the top: what a wheel or a wing would meet there.
		var below: float = float(Sim.server.first_solid_below(peak + Vector3.UP * 50.0, 200.0)) if Sim.server != null else -1.0
		var hit: float = peak.y + 50.0 - below if below >= 0.0 else -INF
		var stands: bool = best - ground >= MOUNTAIN_RELIEF and absf(hit - best) < 2.0
		standing += 1 if stands else 0
		words.append("salt %d: top %.0f m (pyramid %.0f), %.0f m over the ground, the simulation's ground there %.1f" % [
			int(range["salt"]), best, top, best - ground, hit])
	_check("the_level_s_four_ranges_stand_in_the_rock_and_the_collision",
		rock != null and ranges.size() == 4 and standing == 4, "; ".join(words) if rock != null else "no rock on this level")
	_sections += 1


func _the_airports_are_laid_and_keep_their_clearances(field: Object) -> void:
	var here: Array[String] = []
	var laid_by_id: Dictionary = {}
	for laid in AirbasePlan.bases():
		here.append(String(laid["id"]))
		laid_by_id[String(laid["id"])] = laid
	here.sort()
	_check("the_three_bases_are_laid_and_the_islands_are_not", here == BASES,
		"%s; last refusal '%s'" % [here, AirbasePlan.last_refusal])
	for id in BASES:
		if not laid_by_id.has(id):
			continue
		var laid: Dictionary = laid_by_id[id]
		var standards: Dictionary = laid["standards"]
		var faults: PackedStringArray = []
		var measured: int = 0
		var frame: Dictionary = laid["frame"]
		# THE RUNWAYS IT SERVES, each in the base's frame: its own, and every `also_runways` one.
		var served: Array[Dictionary] = []
		for key in laid["runways"]:
			served.append(laid["runways"][key])
		var off_runway: float = float(standards.get("runway_to_taxiway", standards.get("runway_clear_zone", 0.0)))
		var obstacles: Array = []
		for wall in laid["walls"]:
			obstacles.append({"name": "%s %s" % [wall["part"], wall["of"]], "along": wall["along"], "across": wall["across"]})
		var tower_half: float = (Sim.geometry_of(Sim.Kind.TOWER).get("extents", Vector3.ONE) as Vector3).x
		obstacles.append({"name": "the tower",
			"along": [float(laid["tower"]["along"]) - tower_half, float(laid["tower"]["along"]) + tower_half],
			"across": [float(laid["tower"]["across"]) - tower_half, float(laid["tower"]["across"]) + tower_half]})
		var apron_half: float = AirbasePlan.half_span_of(Sim.Kind.AIRLINER)
		for line in laid["taxiways"]:
			var centre: Dictionary = _centreline(line)
			# A TAXIWAY RUNNING BESIDE A SERVED RUNWAY stands the standard off it.
			if line["kind"] == "taxiway" and not bool(line["runway_join"]):
				for runway in served:
					if bool(runway["runs_along"]) == bool(line["along_runs"]):
						var gap: float = absf(float(line["fixed"]) - float(runway["centreline"]))
						if gap < off_runway - 0.05:
							faults.append("taxiway %s %.1f m off runway '%s', wanted %.1f" % [line["id"], gap,
								runway["field"], off_runway])
						measured += 1
			var wanted: float = float(standards["taxiway_obstacle_clearance"]) if line["kind"] == "taxiway" \
				else apron_half + float(standards["wingtip_to_taxilane"])
			for obstacle in obstacles:
				var gap: float = _gap(centre, obstacle)
				if gap < wanted:
					faults.append("%s %.1f m from %s %s, wanted %.1f" % [obstacle["name"], gap, line["kind"], line["id"],
						wanted])
				measured += 1
		# NO WALL IN A SERVED RUNWAY'S OBJECT FREE AREA: the airfield file's own half-width, or the pads' default.
		for runway in served:
			var named: Dictionary = Airfield.named(String(runway["field"]))
			var ofa: float = Airfield.OFA_HALF_DEFAULT
			if not named.is_empty() and named["runway"] is Dictionary:
				ofa = float(((named["runway"] as Dictionary).get("protection", {}) as Dictionary).get("ofa_half_width", ofa))
			for obstacle in obstacles:
				var across: Array = obstacle["across"] if bool(runway["runs_along"]) else obstacle["along"]
				var along: Array = obstacle["along"] if bool(runway["runs_along"]) else obstacle["across"]
				var lo: float = minf(float(across[0]), float(across[1]))
				var hi: float = maxf(float(across[0]), float(across[1]))
				var near: float = maxf(0.0, maxf(lo - float(runway["centreline"]), float(runway["centreline"]) - hi))
				var beside: bool = maxf(float(along[0]), float(along[1])) > minf(float(runway["threshold"]), float(runway["far_end"])) \
					and minf(float(along[0]), float(along[1])) < maxf(float(runway["threshold"]), float(runway["far_end"]))
				if beside and near < ofa:
					faults.append("%s %.1f m from runway '%s', inside its %.1f m object free area" % [obstacle["name"],
						near, runway["field"], ofa])
				measured += 1
		# EVERY STAND FITS ITS CRAFT AND HAS A ROUTE TO A HOLD BAR.
		var holds: Array = (laid["holds"] as Dictionary).keys()
		for spot_id in laid["spots"]:
			var spot: Dictionary = laid["spots"][spot_id]
			var kind: int = Sim.Kind.FIGHTER if String(spot.get("bay_of", "")) != "" \
				else Sim.Kind[String(spot.get("craft", "AIRLINER"))]
			if not AirbasePlan.fits(spot, kind):
				faults.append("a %s does not fit %s" % [Sim.kind_name(kind), spot_id])
			var reached: bool = false
			for hold in holds:
				if not AirbasePlan.route(laid, String(spot["node"]), String(hold)).is_empty():
					reached = true
					break
			if not reached:
				faults.append("stand %s reaches no hold bar" % spot_id)
			measured += 2
		# EVERY SLAB ON ITS PAD: the ground under each piece's middle is the runway's level.
		var level: float = (frame["centre"] as Vector3).y
		var worst: float = 0.0
		for piece in laid["pavement"]:
			var at: Vector3 = piece["position"]
			worst = maxf(worst, absf(float(int(field.call("height_ticks_at", roundi(at.x), roundi(at.z)))) / TICKS - level))
		if worst > 1.0 / TICKS:
			faults.append("pavement stands %.2f m off its pad's level" % worst)
		_check("%s_keeps_the_clearances_its_file_cites" % id, faults.is_empty() and measured > 50,
			"%d distances measured, %d holds, %d stands%s" % [measured, holds.size(), (laid["spots"] as Dictionary).size(),
				"" if faults.is_empty() else ": " + "; ".join(faults.slice(0, 5))])
	_sections += 1


func _no_ship_is_offered_and_the_page_says_why() -> void:
	var page: ClipboardPage = null
	if _level.rig != null and _level.rig.clipboard != null:
		page = _level.rig.clipboard.get("_page") as ClipboardPage
	var ships: Array[String] = []
	var buttons: int = 0
	var note: String = ""
	if page != null:
		var grid: HFlowContainer = page.get("_craft_grid")
		for button in grid.get_children():
			buttons += 1
			if String((button as Button).get_meta("group", "")) == "ships":
				ships.append((button as Button).text)
		var label: Label = page.get("_craft_note")
		note = label.text if label != null and label.visible else ""
	var with_sea: int = VehicleCatalogue.craft_rows_for(true).filter(
		func(row: Dictionary) -> bool: return String(row["group"]) == "ships").size()
	_check("no_ship_is_offered_on_a_level_with_no_sea_and_the_page_says_why",
		page != null and buttons > 10 and ships.is_empty() and note == VehicleCatalogue.NO_SEA_NOTE and with_sea > 0,
		"%d craft offered, ships %s, the note '%s'; a level with a sea offers %d ships" % [buttons, ships, note, with_sea])
	_sections += 1


func _the_basic_traffic_flies_its_trips() -> void:
	var plan: TrafficPlan = _level.traffic_plan
	var ticks: int = 0
	var most: int = int(TRIP_PATIENCE_S * float(Engine.physics_ticks_per_second))
	var began: int = Time.get_ticks_msec()
	var landed_at_s: Dictionary = {}
	while plan != null and ticks < most:
		await get_tree().physics_frame
		ticks += 1
		if ticks % 120 != 0:
			continue
		# ONCE A SIMULATED MINUTE, where each flight is: how fast the suite runs, and where one stuck.
		if ticks % (120 * 60) == 0 or (ticks < 7200 and ticks % 600 == 0):
			var where: PackedStringArray = []
			for entity in plan.flights:
				var state: Dictionary = Sim.server.vehicle_state(int(entity))
				var pilot: Dictionary = _level.airport_traffic.record_of(int(entity))
				where.append("%s %s at %s %.1f m/s%s" % [Sim.kind_name(int(plan.flights[entity]["kind"])),
					pilot.get("phase", "?"), (state.get("position", Vector3.ZERO) as Vector3).snapped(Vector3.ONE),
					(state.get("velocity", Vector3.ZERO) as Vector3).length(),
					(" holding for %s" % pilot["holding_for"] if String(pilot.get("holding_for", "")) != "" else "")
					+ (" DESTROYED %s" % Sim.server.hull_state(int(entity)) if bool(Sim.server.hull_state(int(entity)).get("destroyed", false)) else "")])
			print("[testfield] %d s of traffic in %.0f s: %s" % [ticks / 120, float(Time.get_ticks_msec() - began) / 1000.0,
				", ".join(where)])
		# LANDED IS DOWN ON THE RUNWAY IT WAS SENT TO: rolling out, turning off, taxiing in or stopped there.
		for entity in plan.flights:
			var pilot: Dictionary = _level.airport_traffic.record_of(int(entity))
			var down: bool = pilot.get("phase", &"") in [&"rollout", &"vacating", &"taxi_in", &"parked", &"clearing",
				&"stopped"] and String(pilot.get("field", "")) == String(plan.flights[entity]["to"])
			if (down or int(plan.flights[entity]["landings"]) > 0) and not landed_at_s.has(entity):
				landed_at_s[entity] = float(ticks) / float(Engine.physics_ticks_per_second)
		if landed_at_s.size() == plan.flights.size():
			break
	var words: PackedStringArray = []
	if plan != null:
		for entity in plan.flights:
			var flight: Dictionary = plan.flights[entity]
			var pilot: Dictionary = _level.airport_traffic.record_of(int(entity))
			var reasons: PackedStringArray = []
			for gate in pilot.get("gates", []):
				if String((gate as Dictionary).get("went_around", "")) != "":
					reasons.append(String(gate["went_around"]))
			words.append("%s to %s: %s after %s s, %d go-arounds%s, now %s" % [Sim.kind_name(int(flight["kind"])),
				(flight["landed_at"] as Array)[0] if not (flight["landed_at"] as Array).is_empty() else flight["to"],
				"landed" if landed_at_s.has(entity) else "NOT landed",
				"%.0f" % float(landed_at_s[entity]) if landed_at_s.has(entity) else "-",
				int(pilot.get("go_arounds", 0)), " (%s)" % ", ".join(reasons) if not reasons.is_empty() else "",
				pilot.get("phase", "?")])
	_check("the_basic_traffic_lands_where_it_was_sent",
		plan != null and plan.flights.size() == BASIC_FLIGHTS and landed_at_s.size() == BASIC_FLIGHTS,
		"%s; %.0f s of simulation in %.1f s" % ["; ".join(words) if plan != null else "the level started no traffic",
			float(ticks) / float(Engine.physics_ticks_per_second), float(Time.get_ticks_msec() - began) / 1000.0])
	_sections += 1


## A centreline as a rectangle of no width, in its base's frame.
func _centreline(line: Dictionary) -> Dictionary:
	var fixed: float = line["fixed"]
	if line["along_runs"]:
		return {"along": [line["start"], line["end"]], "across": [fixed, fixed]}
	return {"along": [fixed, fixed], "across": [line["start"], line["end"]]}


## The shortest distance between two rectangles of a frame, 0 where they overlap; each pair in either order.
func _gap(a: Dictionary, b: Dictionary) -> float:
	var a0: float = minf(float(a["along"][0]), float(a["along"][1]))
	var a1: float = maxf(float(a["along"][0]), float(a["along"][1]))
	var b0: float = minf(float(b["along"][0]), float(b["along"][1]))
	var b1: float = maxf(float(b["along"][0]), float(b["along"][1]))
	var c0: float = minf(float(a["across"][0]), float(a["across"][1]))
	var c1: float = maxf(float(a["across"][0]), float(a["across"][1]))
	var d0: float = minf(float(b["across"][0]), float(b["across"][1]))
	var d1: float = maxf(float(b["across"][0]), float(b["across"][1]))
	return Vector2(maxf(0.0, maxf(a0 - b1, b0 - a1)), maxf(0.0, maxf(c0 - d1, d0 - c1))).length()


func _on_a_session_ended(reason: String) -> void:
	if _finished:
		return
	_check("the_test_field_stands_and_comes_up", false, "the session ended while it loaded: %s" % reason)
	_finish()


func _finish() -> void:
	_finished = true
	Sim.stop()
	Net.leave("suite over")
	Net.choose_level(ChartDrawer.DEFAULT)
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
