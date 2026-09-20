extends Node
## CAPE INTERNATIONAL, HEADLESS: the island's airliner airport (lane/airport, 2026-09-19) against the standards it cites,
## the 747 it is laid for, and the island it stands on.
##
##   Godot --headless --fixed-fps 120 --xr-mode off --path cockpit res://tests/airport.tscn
##
## The user, 2026-09-19: "we'll need a model like the airbase but a civilian airport (with multiple runways, sometimes that
## cross one another, they will need to be long enough for the 747 and 737 to takeoff and land."
##
## THE DATUM IS THE STANDARD, NOT THE FILE. Every clearance here is typed from FAA AC 150/5300-13B (change 1) for a
## design group V, taxiway design group 5, category D aeroplane, with its table, and the runway length from Boeing's
## planning document. The file's `standards` block is what the plan lays from; were this suite to read it back, a file that
## cited a smaller number would lay an airport that passed (the trap tests/airbase.gd names, lane/linersfix).
##
## THE 747 FLIES HERE: its take-off and its landing on a runway as long as the file's, on flat ground of this suite's own,
## through the real autopilot and mixers (`AirportTraffic`) -- the distances the runway is long enough for are the ones
## the game's 747 actually uses, not a table's.
##
## Read RESULT=, not the exit code.

const BASE_ID: String = "cape_international"
const LONG: String = "cape_09_27"
const CROSSING: String = "cape_18_36"
## AC 150/5300-13B: table G-11 (C/D/E-V), runway width 150 ft, centreline to parallel taxiway 400 ft, to holding position
## 280 ft (precision approach), object free area 800 ft wide.
const FEET: float = 0.3048
const RUNWAY_WIDTH: float = 150.0 * FEET
const RUNWAY_TO_TAXIWAY: float = 400.0 * FEET
const RUNWAY_TO_HOLD: float = 280.0 * FEET
const RUNWAY_OFA_HALF: float = 400.0 * FEET
## Tables 4-1 and 4-2, ADG V / TDG 5: taxiway 75 ft wide; taxiway centreline to taxiway 249.5 ft, to an object 142.5 ft;
## taxilane centreline to an object 135 ft. Table 5-1: parked wingtip to wingtip 25 ft.
const TAXIWAY_WIDTH: float = 75.0 * FEET
const TAXIWAY_TO_TAXIWAY: float = 249.5 * FEET
const TAXIWAY_TO_OBJECT: float = 142.5 * FEET
const TAXILANE_TO_OBJECT: float = 135.0 * FEET
const PARKED_WINGTIPS: float = 25.0 * FEET
## Paragraph 4.8.5: an acute-angled exit meets the runway at 30 degrees.
const EXIT_ANGLE: float = 30.0
## BOEING D6-58326-1 rev F, 3.3.4: the 747-400 takes off in about 11,100 ft at its 875,000 lb on a hot day at sea level.
const JUMBO_WORST_TAKE_OFF: float = 11100.0 * FEET
## 14 CFR 25.113: the take-off distance is 115 per cent of the distance to 35 ft; 14 CFR 121.195(b): a landing must stop
## within 60 per cent of the runway.
const TAKE_OFF_FACTOR: float = 1.15
const SCREEN_HEIGHT: float = 35.0 * FEET
const LANDING_SHARE: float = 0.6
## The airliner's measured turn (a bank buys 0.34 of a coordinated turn, lane/pattern 2026-09-19), which sizes the
## instrument approach's vectors; and the world's soft edge, which every approach in use must lie inside.
const MEASURED_TURN: float = 0.34
## The mountains compared on a grid this fine, metres, over the whole island.
const ROCK_STEP: float = 25.0

var _failed := false
var _said: Array[String] = []
var _traffic: AirportTraffic = null


func _ready() -> void:
	if not Sim.is_available():
		_check("the_extension_is_there", false, "no CockpitWorld")
		_finish()
		return
	await _start()
	var long: Dictionary = Airfield.named(LONG)
	var crossing: Dictionary = Airfield.named(CROSSING)
	_check("both_runways_are_on_the_island", not long.is_empty() and not crossing.is_empty(),
		"%s %s, %s %s" % [LONG, not long.is_empty(), CROSSING, not crossing.is_empty()])
	var base: Dictionary = {}
	for laid in AirbasePlan.bases():
		if String(laid["id"]) == BASE_ID:
			base = laid
	_check("the_airport_is_laid_on_the_island", not base.is_empty(), "last refusal: %s" % AirbasePlan.last_refusal)
	if long.is_empty() or crossing.is_empty() or base.is_empty():
		_finish()
		return
	_the_runways(long["frame"], crossing["frame"])
	_the_clearances(base, long["frame"], crossing["frame"])
	_the_stands(base)
	_the_routes(base, long, crossing)
	_the_paint(long["frame"], crossing["frame"])
	_the_rock()
	var every: Array[Dictionary] = Airfield.here()
	_every_airfield_is_walked(every)
	_the_approaches_lie_inside_the_world(every)
	_the_finals_clear_the_rock(every)
	await _the_747_fits_the_runway(float(long["frame"]["length"]))
	await _a_747_lands_on_36_while_a_737_waits_for_09(base, long, crossing)
	_finish()


## ---- the runways ------------------------------------------------------------------------------------------------

func _the_runways(long: Dictionary, crossing: Dictionary) -> void:
	for frame in [long, crossing]:
		_check("runway_%s_is_as_wide_as_the_standard" % frame["field"], float(frame["width"]) >= RUNWAY_WIDTH - 0.01,
			"%.2f m against %.2f" % [float(frame["width"]), RUNWAY_WIDTH])
		_check("runway_%s_is_long_enough_for_a_747_at_its_heaviest_on_a_hot_day" % frame["field"],
			float(frame["length"]) >= JUMBO_WORST_TAKE_OFF, "%.0f m against %.0f" % [float(frame["length"]), JUMBO_WORST_TAKE_OFF])
	var at: Vector3 = Terrain.runways_cross(long, crossing)
	_check("the_two_runways_cross", at != Vector3.INF, str(at))
	if at == Vector3.INF:
		return
	# FROM THE THRESHOLDS IN USE: 09 lands from 09/27's far end, 36 from 18/36's threshold.
	var from_09: float = (at - (long["far_end"] as Vector3)).length()
	var from_36: float = (at - (crossing["threshold"] as Vector3)).length()
	_check("they_cross_well_down_both_runways_from_the_ends_in_use", from_09 > 1500.0 and from_36 > 1500.0,
		"%.0f m from 09's threshold, %.0f m from 36's" % [from_09, from_36])


## ---- the clearances ----------------------------------------------------------------------------------------------

## A taxiway's centreline as a segment in the world, and its kind.
func _segments(base: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line in base["taxiways"]:
		var frame: Dictionary = base["frame"]
		var a: Vector3
		var b: Vector3
		if line["along_runs"]:
			a = AirbasePlan.frame_point(frame, line["start"], line["fixed"])
			b = AirbasePlan.frame_point(frame, line["end"], line["fixed"])
		else:
			a = AirbasePlan.frame_point(frame, line["fixed"], line["start"])
			b = AirbasePlan.frame_point(frame, line["fixed"], line["end"])
		out.append({"id": line["id"], "kind": line["kind"], "a": a, "b": b, "joins": line["joins"]})
	return out


static func _to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var flat := Vector2(p.x, p.z)
	var fa := Vector2(a.x, a.z)
	var fb := Vector2(b.x, b.z)
	var t: float = clampf((flat - fa).dot(fb - fa) / maxf((fb - fa).length_squared(), 1e-6), 0.0, 1.0)
	return flat.distance_to(fa + (fb - fa) * t)


## How far a point is from a runway's centreline, and whether it is beside the runway rather than past an end.
static func _off_centreline(frame: Dictionary, p: Vector3) -> float:
	return absf((p - (frame["centre"] as Vector3)).dot(frame["across"]))


static func _beside(frame: Dictionary, p: Vector3) -> bool:
	return absf((p - (frame["centre"] as Vector3)).dot(frame["along"])) <= float(frame["length"]) * 0.5


func _the_clearances(base: Dictionary, long: Dictionary, crossing: Dictionary) -> void:
	var segments: Array[Dictionary] = _segments(base)
	_check("its_taxiways_are_as_wide_as_the_standard",
		float(base["standards"]["taxiway_width"]) >= TAXIWAY_WIDTH - 0.01, "%.2f m" % float(base["standards"]["taxiway_width"]))
	# EVERY TAXIWAY THAT RUNS BESIDE A RUNWAY, the standard's distance off it or more; every one that does not join a
	# runway keeps out of both runways' object free areas altogether.
	var nearest := {LONG: INF, CROSSING: INF}
	for s in segments:
		for frame in [long, crossing]:
			var parallel: bool = absf(((s["b"] as Vector3) - (s["a"] as Vector3)).normalized().dot(frame["along"])) > 0.99
			if parallel and _beside(frame, (s["a"] + s["b"]) * 0.5):
				nearest[frame["field"]] = minf(float(nearest[frame["field"]]), _off_centreline(frame, s["a"]))
	for field in nearest:
		_check("the_parallel_taxiway_stands_the_standard_off_runway_%s" % field,
			float(nearest[field]) >= RUNWAY_TO_TAXIWAY - 0.05, "nearest %.2f m against %.2f" % [float(nearest[field]),
				RUNWAY_TO_TAXIWAY])
	# THE HOLD BARS: each the standard's distance off the centreline of the runway it holds short of.
	var worst_hold := INF
	var holds: Dictionary = base["holds"]
	for name in holds:
		var frame: Dictionary = long if String(holds[name]["runway"]) == LONG else crossing
		worst_hold = minf(worst_hold, _off_centreline(frame, (base["nodes"][name] as Dictionary)["position"]))
	_check("every_hold_bar_is_280_ft_off_the_runway_it_holds_for", holds.size() >= 5 and worst_hold >= RUNWAY_TO_HOLD - 0.05,
		"%d holds, nearest %.2f m against %.2f" % [holds.size(), worst_hold, RUNWAY_TO_HOLD])
	var for_the_crossing := 0
	for name in holds:
		if String(holds[name]["runway"]) == CROSSING:
			for_the_crossing += 1
	_check("the_crossing_runway_has_hold_bars_of_its_own", for_the_crossing >= 2, "%d" % for_the_crossing)
	# PARALLEL TAXIWAY TO TAXILANE, centreline to centreline.
	var closest_pair := INF
	for s in segments:
		for t in segments:
			if s["kind"] == "taxiway" and t["kind"] == "taxilane":
				var ds: Vector3 = ((s["b"] as Vector3) - (s["a"] as Vector3)).normalized()
				var dt: Vector3 = ((t["b"] as Vector3) - (t["a"] as Vector3)).normalized()
				if absf(ds.dot(dt)) > 0.99:
					closest_pair = minf(closest_pair, _to_segment((t["a"] + t["b"]) * 0.5, s["a"], s["b"]))
	_check("a_taxilane_beside_a_taxiway_keeps_the_taxiway_separation", closest_pair >= TAXIWAY_TO_TAXIWAY - 0.05,
		"%.2f m against %.2f" % [closest_pair, TAXIWAY_TO_TAXIWAY])
	# EVERY BUILDING clear of every taxiway and taxilane by the standard's object clearance, and of both runways' object
	# free areas.
	var worst := {"taxiway": INF, "taxilane": INF, "ofa": INF}
	var worst_what := {"taxiway": "", "taxilane": "", "ofa": ""}
	for wall in base["walls"]:
		var frame: Dictionary = base["frame"]
		for a in wall["along"]:
			for c in wall["across"]:
				var corner: Vector3 = AirbasePlan.frame_point(frame, a, c)
				for s in segments:
					var d: float = _to_segment(corner, s["a"], s["b"])
					if d < float(worst[s["kind"]]):
						worst[s["kind"]] = d
						worst_what[s["kind"]] = "%s from %s" % [wall["of"], s["id"]]
				for runway in [long, crossing]:
					if _beside(runway, corner) and _off_centreline(runway, corner) < float(worst["ofa"]):
						worst["ofa"] = _off_centreline(runway, corner)
						worst_what["ofa"] = "%s from %s" % [wall["of"], runway["field"]]
	_check("every_building_keeps_the_taxiway_object_clearance", float(worst["taxiway"]) >= TAXIWAY_TO_OBJECT,
		"nearest %.1f m (%s) against %.1f" % [float(worst["taxiway"]), worst_what["taxiway"], TAXIWAY_TO_OBJECT])
	_check("every_building_keeps_the_taxilane_object_clearance", float(worst["taxilane"]) >= TAXILANE_TO_OBJECT,
		"nearest %.1f m (%s) against %.1f" % [float(worst["taxilane"]), worst_what["taxilane"], TAXILANE_TO_OBJECT])
	_check("no_building_stands_in_a_runway_object_free_area", float(worst["ofa"]) >= RUNWAY_OFA_HALF,
		"nearest %.1f m (%s) against %.1f" % [float(worst["ofa"]), worst_what["ofa"], RUNWAY_OFA_HALF])
	# THE HIGH-SPEED EXITS: 30 degrees to their runway, and each turned off SHORT OF THE CROSSING, so a landing that takes
	# one never rolls through the other runway.
	var at: Vector3 = Terrain.runways_cross(long, crossing)
	var exits: Array = base["exits"]
	var ok := exits.size() >= 3
	var words := PackedStringArray()
	for exit in exits:
		var frame: Dictionary = long if String(exit["runway"]) == LONG else crossing
		var start: Vector3 = (base["nodes"][exit["start"]] as Dictionary)["position"]
		var join: Vector3 = (base["nodes"][exit["join"]] as Dictionary)["position"]
		var going: Vector3 = ((join - start) * Vector3(1, 0, 1)).normalized()
		var angle: float = rad_to_deg(acos(clampf(absf(going.dot(frame["along"])), 0.0, 1.0)))
		var landing_from: Vector3 = frame["far_end"] if frame == long else frame["threshold"]
		var landing: Vector3 = ((at - landing_from) * Vector3(1, 0, 1)).normalized()
		var to_exit: float = (start - landing_from).dot(landing)
		var to_crossing: float = (at - landing_from).dot(landing)
		# ITS WHOLE LENGTH SHORT OF THE OTHER RUNWAY'S HOLD BARS, and leading AWAY from the landing's start, not back.
		var joins_at: float = (join - landing_from).dot(landing)
		ok = ok and absf(angle - EXIT_ANGLE) < 0.5 and joins_at > to_exit \
			and joins_at < to_crossing - RUNWAY_WIDTH * 0.5 - RUNWAY_TO_HOLD
		words.append("%s %.0f m in at %.1f degrees, the crossing %.0f m in" % [exit["id"], to_exit, angle, to_crossing])
	_check("every_high_speed_exit_is_30_degrees_and_short_of_the_crossing", ok, "; ".join(words))


## ---- the stands ---------------------------------------------------------------------------------------------------

func _the_stands(base: Dictionary) -> void:
	var spots: Dictionary = base["spots"]
	var counts := {"remote": 0, "heavy": 0, "narrow": 0}
	var fitting := true
	var words := PackedStringArray()
	for id in spots:
		var spot: Dictionary = spots[id]
		var apron: String = String(id).get_slice(".", 0)
		if counts.has(apron):
			counts[apron] = int(counts[apron]) + 1
		var kind: int = Sim.Kind.AIRLINER if apron == "narrow" else Sim.Kind.JUMBO
		if not AirbasePlan.fits(spot, kind):
			fitting = false
			words.append("%s does not fit a %s" % [id, Sim.Kind.keys()[kind]])
	_check("the_747_stands_fit_a_747_and_the_737_gates_a_737",
		fitting and int(counts["remote"]) >= 2 and int(counts["heavy"]) >= 2 and int(counts["narrow"]) >= 2,
		"%s %s" % [str(counts), "; ".join(words)])
	# NEIGHBOURS' WINGTIPS APART by the parking clearance, each at its own craft's drawn span.
	var worst := INF
	var ids: Array = spots.keys()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a: Dictionary = spots[ids[i]]
			var b: Dictionary = spots[ids[j]]
			if absf(float(a["nose"]) - float(b["nose"])) > 1.0:
				continue
			var half_a: float = AirbasePlan.half_span_of(Sim.Kind[a.get("craft", "JUMBO")])
			var half_b: float = AirbasePlan.half_span_of(Sim.Kind[b.get("craft", "JUMBO")])
			worst = minf(worst, absf(float(a["along"]) - float(b["along"])) - half_a - half_b)
	_check("parked_wingtips_are_25_ft_apart", worst >= PARKED_WINGTIPS, "closest %.2f m against %.2f" % [worst, PARKED_WINGTIPS])
	# A NOSE-IN GATE'S 747 keeps its tail the taxilane's object clearance off the taxilane: its whole hull behind its nose.
	var tail_room := INF
	for id in spots:
		var spot: Dictionary = spots[id]
		if not bool(spot.get("nose_in", false)):
			continue
		var kind: int = Sim.Kind[spot.get("craft", "JUMBO")]
		var length: float = (Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).z * 2.0
		var lane: Dictionary = base["nodes"][spot["mouth"]]
		tail_room = minf(tail_room, absf(float(spot["nose"]) - float(lane["across"])) - length)
	_check("a_nose_in_747s_tail_is_clear_of_the_taxilane", tail_room >= TAXILANE_TO_OBJECT,
		"tail %.1f m off the taxilane's centreline against %.1f" % [tail_room, TAXILANE_TO_OBJECT])


## ---- the routes ---------------------------------------------------------------------------------------------------

## EVERY REMOTE STAND TO THE HOLD AT EACH THRESHOLD IN USE, and every exit to every contact gate, by the plan's own route
## search -- and no route runs across a runway: the graph joins a runway only at a stub's end and an exit's start.
func _the_routes(base: Dictionary, long: Dictionary, crossing: Dictionary) -> void:
	var thresholds := {LONG: long["frame"]["far_end"], CROSSING: crossing["frame"]["threshold"]}
	var holds: Dictionary = base["holds"]
	var nearest_hold := {}
	for field in thresholds:
		var best := INF
		for name in holds:
			if String(holds[name]["runway"]) != field:
				continue
			var d: float = ((base["nodes"][name] as Dictionary)["position"] - (thresholds[field] as Vector3)).length()
			if d < best:
				best = d
				nearest_hold[field] = name
	_check("each_threshold_in_use_has_a_hold_bar_beside_it", nearest_hold.size() == 2, str(nearest_hold))
	var missing := PackedStringArray()
	var through_a_runway := PackedStringArray()
	var routes := 0
	for id in base["spots"]:
		var spot: Dictionary = base["spots"][id]
		if bool(spot.get("nose_in", false)):
			for exit in base["exits"]:
				var path: Array = AirbasePlan.route(base, exit["start"], spot["node"])
				routes += 1
				if path.is_empty():
					missing.append("%s to %s" % [exit["id"], id])
				elif path.slice(1).any(func(n: String) -> bool: return n.ends_with(".runway")):
					through_a_runway.append("%s to %s" % [exit["id"], id])
		else:
			for field in nearest_hold:
				var path: Array = AirbasePlan.route(base, spot["node"], nearest_hold[field])
				routes += 1
				if path.is_empty():
					missing.append("%s to %s" % [id, nearest_hold[field]])
				elif path.any(func(n: String) -> bool: return n.ends_with(".runway")):
					through_a_runway.append("%s to %s" % [id, nearest_hold[field]])
	_check("every_stand_is_routed_to_every_runway_in_use_and_every_exit_to_every_gate",
		routes > 10 and missing.is_empty(), "%d routes; missing %s" % [routes, ", ".join(missing)])
	_check("no_taxi_route_crosses_a_runway", through_a_runway.is_empty(), ", ".join(through_a_runway))
	# A DEPARTURE FROM EITHER END OF EITHER RUNWAY TAXIS TO ONE OF THAT RUNWAY'S OWN BARS, as AirportTraffic routes it: the
	# nearest bar to 18's threshold holds short of 09/27, 745 m away, not of 18/36.
	var traffic := AirportTraffic.new()
	var wrong := PackedStringArray()
	for field in [long, crossing]:
		for end in Airfield.ENDS:
			var p: TrafficPattern = Airfield.pattern_for(field, Sim.Kind.JUMBO, end)
			var route: PackedVector3Array = traffic._taxi_route(field, p, (base["spots"]["remote.1"] as Dictionary)["position"],
				"remote.1")
			var bar: String = ""
			for name in holds:
				if not route.is_empty() and ((base["nodes"][name] as Dictionary)["position"] as Vector3).distance_to(route[-1]) < 0.5:
					bar = name
			if bar == "" or String(holds[bar]["runway"]) != String(field["id"]):
				wrong.append("%s %s to %s" % [field["id"], end, bar if bar != "" else "nowhere"])
	traffic.free()
	_check("a_departure_from_any_end_holds_short_of_its_own_runway", wrong.is_empty(), ", ".join(wrong))


## ---- the paint ----------------------------------------------------------------------------------------------------

## WHERE THE RUNWAYS CROSS: the later one's asphalt lies under the earlier's, none of its stripes is painted on the
## other, and no light of either stands on the other.
func _the_paint(long: Dictionary, crossing: Dictionary) -> void:
	var frames: Array[Dictionary] = Terrain.runways()
	var first: Dictionary = long if frames.find(long) < frames.find(crossing) else crossing
	var second: Dictionary = crossing if first == long else long
	var over: Array[Dictionary] = Terrain.runway_marks_for(first, [])
	var under: Array[Dictionary] = Terrain.runway_marks_for(second, [first])
	var top_over: float = (over[0]["position"] as Vector3).y + (over[0]["half_extents"] as Vector3).y
	var top_under: float = (under[0]["position"] as Vector3).y + (under[0]["half_extents"] as Vector3).y
	var painted_on := 0
	for mark in under.slice(1):
		if Terrain.on_runway(first, mark["position"]):
			painted_on += 1
	_check("where_they_cross_the_later_runway_lies_under_the_earlier_unpainted",
		top_under < top_over - 0.005 and painted_on == 0, "tops %.3f under %.3f; %d marks on the other" % [top_under,
			top_over, painted_on])
	var lights_on := 0
	for pair in [[long, crossing], [crossing, long]]:
		for light in Terrain.runway_lights_for(pair[0], [pair[1]]):
			if Terrain.on_runway(pair[1], light["position"]):
				lights_on += 1
	_check("no_runway_light_stands_on_the_other_runway", lights_on == 0, "%d" % lights_on)


## ---- the island ----------------------------------------------------------------------------------------------------

## THE ROCK IS THE SAME WITH THE AIRPORT AS WITHOUT IT: the mountains made from every keep-out the island has, against the
## same with the airport's own (its two runways' protection and the air base's hull) left out, sampled every ROCK_STEP
## over the whole island. The site was chosen where no rock stands (lane/airport's rock map), and this holds it there.
func _the_rock() -> void:
	if not ClassDB.class_exists(&"MountainRange"):
		_check("the_mountains_are_there", false, "no MountainRange")
		return
	var lists: Dictionary = Terrain.mountain_keepout_lists()
	var with: PackedInt32Array = lists["keepouts"]
	var without := PackedInt32Array()
	var margins_without := PackedInt32Array()
	var margins: PackedInt32Array = lists["margins"]
	var rises_without := PackedInt32Array()
	var rises: PackedInt32Array = lists["rises"]
	var left_out := 0
	var clear: Array[Dictionary] = Terrain.clearances()
	# THE KEEP-OUTS ARE THE CLEARANCES FIRST, five ints each, then the towns and the woods (Terrain.mountain_keepouts).
	for k in range(with.size() / 5):
		var mine: bool = k < clear.size() and String(clear[k].get("place", "")) in [LONG, CROSSING, BASE_ID]
		if mine:
			left_out += 1
			continue
		without.append_array(with.slice(k * 5, k * 5 + 5))
		margins_without.append(margins[k])
		rises_without.append(rises[k])
	var values: Dictionary = Terrain.mountain_values()
	var a: Object = ClassDB.instantiate(&"MountainRange")
	a.call("configure", values)
	values["keepouts"] = without
	values["keepout_margins"] = margins_without
	values["keepout_rises"] = rises_without
	var b: Object = ClassDB.instantiate(&"MountainRange")
	b.call("configure", values)
	var points := PackedVector2Array()
	var half: float = Terrain.WORLD_HALF
	var x: float = -half
	while x <= half:
		var z: float = -half
		while z <= half:
			points.append(Vector2(x, z))
			z += ROCK_STEP
		x += ROCK_STEP
	var ha: PackedFloat32Array = a.call("surfaces_at", points)
	var hb: PackedFloat32Array = b.call("surfaces_at", points)
	var differ := 0
	var worst := 0.0
	for i in range(points.size()):
		if ha[i] != hb[i]:
			differ += 1
			worst = maxf(worst, absf(ha[i] - hb[i]))
	_check("the_airport_moves_no_rock", left_out >= 3 and differ == 0,
		"%d of the airport's keep-outs left out; %d of %d points differ, by up to %.1f m" % [left_out, differ,
			points.size(), worst])


## THE GLIDE PATH CLEARS THE ROCK beside EVERY FINAL THE WORLD HAS: `Airfield.here()`, walked by `FinalWalk`, `FinalWalk.ROOM`
## either side of the centreline from the threshold out to where the 747 is established. This was handed `[long, crossing]`
## until 2026-09-19 and never saw `island_strip`, whose final stood 38 m inside a mountain.


func _the_finals_clear_the_rock(fields: Array) -> void:
	var rock: Object = Terrain.mountains()
	if rock == null:
		return
	for field in fields:
		var walked: Dictionary = FinalWalk.of(field, rock)
		_check("the_glide_path_into_%s_clears_the_rock_within_600_m_of_the_centreline" % field["id"], float(walked["least"]) > 0.0,
			"least %.0f m, %s" % [float(walked["least"]), walked["at"]])


## THE WALK IS OVER EVERY FIELD THE FILES LAY ON THIS WORLD, counted against the folder itself and not against `Airfield`:
## the folders on disk (less the `_` ones) are the files, so a field dropped by the scan, or by `here()`, is a number that
## no longer agrees. The level's own fields are `testfield.gd`'s to walk, on the level's own ground.
func _every_airfield_is_walked(every: Array[Dictionary]) -> void:
	var folders := 0
	for id in DirAccess.get_directories_at(Airfield.FOLDER):
		if not id.begins_with("_"):
			folders += 1
	var island := 0
	var ids := PackedStringArray()
	for field in every:
		ids.append(String(field["id"]))
	for field in Airfield.catalogue():
		if String(field["world"]) == "island":
			island += 1
	_check("every_airfield_folder_is_read", Airfield.catalogue().size() == folders, "%d read of %d folders" % [
		Airfield.catalogue().size(), folders])
	_check("every_airfield_on_the_island_is_walked", every.size() == island and island >= 4,
		"%d walked of %d the files lay on the island: %s" % [every.size(), island, ", ".join(ids)])


## EVERY APPROACH IN USE LIES INSIDE THE WORLD: a 747's instrument final is established 8 NM out and its vectors are laid on
## its flown turn, and all of it must be short of where the world's soft edge begins to turn aeroplanes back
## (`WorldEdge`: the placed reach and `CLEAR_OF_PLACES`, per axis).
##
## IT HOLDS EACH FIELD TO THE LARGEST AEROPLANE THE GAME WILL SEND THERE, WHICH IS A QUESTION NOBODY HAS ANSWERED. Today
## that is every aeroplane over 12,500 lb at every field (`InstrumentApproach.flies_it` keys on mass alone), so a 747 could be
## vectored onto a 900 m strip on a final that ends 20.5 and 24.0 km out against an edge at 19.3. The check is not widened to
## pass, and it is not asked of a 900 m strip: it walks the fields a 747 can take off from (`JUMBO_WORST_TAKE_OFF`), and
## says in its detail which fields it left out and how far out their finals would end, so the gap is on the page every
## run. What ought to happen to the ones left out is `todo/throughrock--who-is-sent-to-which-field.md`.
func _the_approaches_lie_inside_the_world(fields: Array) -> void:
	var edge: float = Terrain.placed_reach() + WorldEdge.CLEAR_OF_PLACES
	var words := PackedStringArray()
	var left_out := PackedStringArray()
	var inside := true
	var walked := 0
	for field in fields:
		var p: TrafficPattern = Airfield.pattern_for(field, Sim.Kind.JUMBO, "", MEASURED_TURN)
		var ifr := InstrumentApproach.make(p, Airfield.numbers_of(Sim.Kind.JUMBO))
		var established: Vector3 = p.point(-ifr.established_out() - 2.0 * ifr.radius, 0.0)
		var km: float = WorldEdge.out(established) / 1000.0
		if float((field["frame"] as Dictionary)["length"]) < JUMBO_WORST_TAKE_OFF:
			left_out.append("%s %.1f km" % [field["id"], km])
			continue
		walked += 1
		inside = inside and WorldEdge.out(established) < edge
		words.append("%s: %.1f km out per axis" % [field["id"], km])
	_check("every_final_in_use_starts_inside_the_worlds_edge", inside and walked > 0,
		"%s; the edge starts at %.1f km; NOT ASKED of runways under a 747's take-off (nothing yet stops a 747 being sent to them): %s" % [
			", ".join(words), edge / 1000.0, ", ".join(left_out)])


## ---- the 747 on the runway ------------------------------------------------------------------------------------------

## A RUNWAY AS LONG AS THE FILE'S, on flat ground of this suite's own at the origin: a 747 takes off from it, and one lands
## on it straight in from 11 NM, flown by AirportTraffic through the real mixers. The runway is long enough when the take-off
## to 35 ft, with 14 CFR 25.113's 15 per cent, and the landing from the threshold to a stop, over 14 CFR 121.195's 60 per
## cent, both fit.
func _the_747_fits_the_runway(length: float) -> void:
	Sim.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(7200.0, 400.0, 7200.0))
	_traffic = AirportTraffic.new()
	_traffic.recording = true
	_traffic.highest_ground = func(_at: Vector3, _room: float) -> float: return 0.0
	add_child(_traffic)
	var field := {"id": "suite", "frame": Terrain.runway_frame(Vector3.ZERO, 0.0, length, RUNWAY_WIDTH),
		"ends": {"threshold": {"pattern": "left"}, "far_end": {"pattern": "left"}}, "in_use": "threshold"}
	var frame: Dictionary = field["frame"]
	var along: Vector3 = frame["along"]
	var extents: Vector3 = Sim.geometry_of(Sim.Kind.JUMBO).get("extents", Vector3.ONE)
	# THE TAKE-OFF, from a standstill 60 m past the threshold.
	var start: Vector3 = (frame["threshold"] as Vector3) + along * 60.0 + Vector3.UP * (extents.y + 0.3)
	var entity: int = Sim.spawn_ai_vehicle(Sim.Kind.JUMBO, start, atan2(-along.x, -along.z), Vector3.ZERO)
	_traffic.depart(entity, field, Sim.Kind.JUMBO)
	var me: Dictionary = _traffic.record_of(entity)
	var seen := {"screen": INF, "rolled_from": INF}
	await _fly(func() -> bool:
		var s: Dictionary = Sim.server.vehicle_state(entity)
		if s.is_empty():
			return true
		var ahead: float = ((s["position"] as Vector3) - (frame["threshold"] as Vector3)).dot(along)
		if me["phase"] == &"take_off" and seen["rolled_from"] == INF:
			seen["rolled_from"] = ahead
		if seen["rolled_from"] != INF and (s["position"] as Vector3).y - extents.y > SCREEN_HEIGHT:
			seen["screen"] = ahead
		return seen["screen"] != INF or ahead > length + 2000.0, 240.0)
	var take_off: float = (float(seen["screen"]) - float(seen["rolled_from"])) * TAKE_OFF_FACTOR
	_check("the_747_takes_off_within_the_runway_with_the_regulations_margin", take_off <= length,
		"%.0f m to 35 ft from the start of its roll, x %.2f = %.0f m of %.0f" % [float(seen["screen"]) - float(seen["rolled_from"]),
			TAKE_OFF_FACTOR, take_off, length])
	_traffic.release(entity)
	Sim.server.despawn_vehicle(entity)
	# THE LANDING, straight in from 11 NM at its cruise.
	var p: TrafficPattern = Airfield.pattern_for(field, Sim.Kind.JUMBO)
	var speed: float = float(Sim.handling_of(Sim.Kind.JUMBO)["cruise"])
	entity = Sim.spawn_ai_vehicle(Sim.Kind.JUMBO, p.point(-20300.0, 0.0) + Vector3.UP * 600.0, atan2(-p.along.x, -p.along.z),
		p.along * speed)
	_traffic.arrive(entity, field, Sim.Kind.JUMBO)
	me = _traffic.record_of(entity)
	var stop := {"at": INF}
	await _fly(func() -> bool:
		var s: Dictionary = Sim.server.vehicle_state(entity)
		if s.is_empty():
			return true
		# THE ROLL ENDS WHERE IT IS DOWN TO A TAXI (`AirportTraffic.TAXI_SPEED`), which is where it turns off.
		if me["phase"] == &"clearing" and stop["at"] == INF:
			stop["at"] = (me["pattern"] as TrafficPattern).ahead_of(s["position"])
		return stop["at"] != INF or int(me["go_arounds"]) > 0 or bool(Sim.server.hull_state(entity).get("destroyed", false)),
		900.0)
	var slowed: float = float(stop["at"])
	_check("the_747_lands_and_stops_within_60_per_cent_of_the_runway",
		slowed != INF and slowed <= length * LANDING_SHARE and int(me["go_arounds"]) == 0,
		"stopped %.0f m past the threshold against %.0f; touched %.1f m/s down; legs %s" % [slowed, length * LANDING_SHARE,
			float((me.get("landed", {}) as Dictionary).get("touch_sink", -1.0)), str(me["legs"])])
	_traffic.release(entity)
	Sim.server.despawn_vehicle(entity)


## ---- the two runways in use at once (lane/airport step 2) ---------------------------------------------------------

## THE CROSSING RUNWAY RULE, FLOWN ([7110.65] 3-9-8 b): a 737 taxis from a remote stand to the hold for 09 while a 747 is
## put on 36's final, 4 NM out, as the 737 nears its hold, so it reaches the bar with the 747 still on its final,
## the threshold. It must hold short until the 747 has come down to a taxi short of the intersection, then go.
## The 747 turns off at the first exit ahead, taxis to a free 747 gate and stops nose-in on its mark, never on 09/27.
## On this suite's own flat slab (it covers the whole island), at the real airport's places.
const FINAL_OUT: float = 4.0 * 1852.0
const ON_THE_MARK: float = 3.0


func _a_747_lands_on_36_while_a_737_waits_for_09(base: Dictionary, long: Dictionary, crossing: Dictionary) -> void:
	var intersection: Vector3 = Terrain.runways_cross(long["frame"], crossing["frame"])
	var remote: Dictionary = base["spots"].get("remote.1", {})
	_check("there_is_a_remote_stand_for_the_737", not remote.is_empty(), str((base["spots"] as Dictionary).keys()))
	if remote.is_empty():
		return
	var e737: Vector3 = Sim.geometry_of(Sim.Kind.AIRLINER).get("extents", Vector3.ONE)
	var parked_at: Vector3 = AirbasePlan.standing_on_spot(base, remote, Sim.Kind.AIRLINER) + Vector3.UP * (e737.y + 0.3)
	var b737: int = Sim.spawn_ai_vehicle(Sim.Kind.AIRLINER, parked_at, float(remote["yaw"]), Vector3.ZERO)
	_traffic.depart(b737, long, Sim.Kind.AIRLINER, "remote.1")
	var liner: Dictionary = _traffic.record_of(b737)
	var hold_at: Vector3 = (liner["route"] as PackedVector3Array)[-1] if not (liner["route"] as PackedVector3Array).is_empty() \
		else Vector3.INF
	var p36: TrafficPattern = Airfield.pattern_for(crossing, Sim.Kind.JUMBO)
	var seen := {"b747": 0, "held_s": 0.0, "held_for": "", "conflicts": [], "on_09": 0, "tick": 0}
	var jumbo: Array = [{}]
	var watch := func() -> bool:
		seen["tick"] = int(seen["tick"]) + 1
		var s737: Dictionary = Sim.server.vehicle_state(b737)
		if s737.is_empty():
			return true
		# THE 747 ON 36'S FINAL once the 737 is within 600 m of its hold, a minute of taxi.
		if int(seen["b747"]) == 0 and hold_at != Vector3.INF and _flat_distance(s737["position"], hold_at) < 600.0:
			var at: Vector3 = p36.point(-FINAL_OUT, 0.0)
			var ifr := InstrumentApproach.make(p36, Airfield.numbers_of(Sim.Kind.JUMBO))
			at.y = ifr.final_height(at)
			var entity: int = Sim.spawn_ai_vehicle(Sim.Kind.JUMBO, at, atan2(-p36.along.x, -p36.along.z), p36.along * p36.final_speed)
			seen["b747"] = entity
			_traffic.arrive(entity, crossing, Sim.Kind.JUMBO, "", &"final")
			jumbo[0] = _traffic.record_of(entity)
		if liner["phase"] == &"hold_short":
			seen["held_s"] = float(seen["held_s"]) + 1.0 / 120.0
			if String(liner.get("holding_for", "")) != "":
				seen["held_for"] = liner["holding_for"]
		var j: Dictionary = jumbo[0]
		if not j.is_empty():
			var s747: Dictionary = Sim.server.vehicle_state(int(seen["b747"]))
			# THE RULE, WATCHED: while the 737 is on 09 short of the intersection, the 747 is neither on its final nor
			# rolling fast toward the intersection.
			var p09: TrafficPattern = liner["pattern"]
			# `-- --trace`: both aeroplanes once a second, where each is along its own runway. It is how the first version of
			# this check was caught passing a rule-less 737 that rolled with the 747 on short final: its conflicts went into a
			# cast PackedStringArray, which is a copy, and were never kept.
			if int(seen["tick"]) % 120 == 0 and OS.get_cmdline_user_args().has("--trace"):
				print("[trace] 737 %s %.0f  747 %s %.0f %.1f" % [liner["phase"], p09.ahead_of(s737["position"]), j["phase"],
					p36.ahead_of(s747.get("position", Vector3.ZERO)), (s747.get("velocity", Vector3.ZERO) as Vector3).length()])
			if liner["phase"] in [&"line_up", &"align", &"take_off"] and p09.ahead_of(s737["position"]) < p09.ahead_of(intersection) \
					and not s747.is_empty():
				# ON ITS FINAL OR STILL ROLLING, or turning off by a way that lies past the intersection. Turning off short of it
				# is clear ([7110.65] 3-9-8 b 2), and the check below holds that it really did leave the runway there.
				var turning_off_past: bool = j["phase"] == &"vacating" and p36.ahead_of(j.get("off_at", Vector3.INF)) \
					> p36.ahead_of(intersection) - RUNWAY_TO_HOLD
				var roll_done_short: bool = (s747["velocity"] as Vector3).length() < AirportTraffic.TAXI_SPEED \
					and p36.ahead_of(s747["position"]) < p36.ahead_of(intersection) - RUNWAY_TO_HOLD
				if j["phase"] in [&"final", &"straight_in"] or (j["phase"] == &"rollout" and not roll_done_short) \
						or turning_off_past:
					(seen["conflicts"] as Array).append("737 %s at %.0f m while the 747 was %s at %.1f m/s" % [
						liner["phase"], p09.ahead_of(s737["position"]), j["phase"], (s747["velocity"] as Vector3).length()])
			# AND THE 747 NEVER ON RUNWAY 09/27 once it is down.
			if j["phase"] in [&"vacating", &"taxi_in", &"parked"] and not s747.is_empty() \
					and Terrain.on_runway(long["frame"], s747["position"], 5.0):
				seen["on_09"] = int(seen["on_09"]) + 1
		var done_737: bool = liner["phase"] in [&"departing", &"departure"] and liner.has("lift_off") \
			and (liner["pattern"] as TrafficPattern).ahead_of(s737["position"]) > (liner["pattern"] as TrafficPattern).ahead_of(intersection)
		var done_747: bool = not j.is_empty() and (j["phase"] == &"parked" or int(j["go_arounds"]) > 0 \
			or bool(Sim.server.hull_state(int(seen["b747"])).get("destroyed", false)))
		return done_737 and done_747
	await _fly(watch, 1500.0)
	var j: Dictionary = jumbo[0]
	_check("the_737_holds_short_for_the_747_on_the_crossing_runway", float(seen["held_s"]) > 5.0 \
		and String(seen["held_for"]).contains(str(seen["b747"])),
		"held %.0f s, last for \"%s\"" % [float(seen["held_s"]), seen["held_for"]])
	_check("the_737_never_rolls_short_of_the_intersection_with_the_747_on_final_or_rolling",
		(seen["conflicts"] as Array).is_empty() and liner.has("lift_off"),
		"lifted off %s; %d conflicts %s" % [liner.has("lift_off"), (seen["conflicts"] as Array).size(),
			(seen["conflicts"] as Array)[0] if not (seen["conflicts"] as Array).is_empty() else ""])
	if j.is_empty():
		_check("the_747_was_put_on_final", false, "the 737 never came within 600 m of its hold: phase %s" % liner["phase"])
		return
	var s747: Dictionary = Sim.server.vehicle_state(int(seen["b747"]))
	var gate: Dictionary = (base["spots"] as Dictionary).get(String(j.get("gate", "")), {})
	var mark: Vector3 = AirbasePlan.standing_on_spot(base, gate, Sim.Kind.JUMBO) if not gate.is_empty() else Vector3.INF
	var off: float = _flat_distance(s747.get("position", Vector3.ZERO), mark) if mark != Vector3.INF else INF
	var facing: float = rad_to_deg(absf(wrapf(Basis(s747.get("basis", Quaternion.IDENTITY) as Quaternion).get_euler().y
		- float(gate.get("yaw", 0.0)), -PI, PI))) if not gate.is_empty() else 180.0
	var line: Vector3 = Terrain.nose_from_yaw(float(gate.get("yaw", 0.0)))
	# `-- --stand-track`: the 747's last eight seconds onto its stand, against its lead-in line, for working out a miss.
	if OS.get_cmdline_user_args().has("--stand-track"):
		for look in (j["track"] as Array).slice(-80):
			var rel: Vector3 = (look["at"] as Vector3) - mark
			print("[stand] %s along %.1f aside %.1f speed %.1f heading-off %.0f" % [look["phase"], rel.dot(line),
				rel.dot(Vector3(-line.z, 0.0, line.x)), (look["v"] as Vector3).length(),
				rad_to_deg(Vector3(look["v"].x, 0, look["v"].z).signed_angle_to(line, Vector3.UP)) if (look["v"] as Vector3).length() > 0.3 else 0.0])
	var miss: Vector3 = (s747.get("position", Vector3.ZERO) as Vector3) - mark if mark != Vector3.INF else Vector3.ZERO
	_check("the_747_lands_on_36_turns_off_and_parks_nose_in_at_a_747_gate",
		j["phase"] == &"parked" and bool(gate.get("nose_in", false)) and AirbasePlan.fits(gate, Sim.Kind.JUMBO) \
			and off <= ON_THE_MARK and facing <= 10.0 and bool(j.get("gear_at_touch", false)),
		"legs %s; gate %s, %.1f m off its mark (%.1f along its line, %.1f aside), facing %.0f degrees off; gear %s" % [
			str(j["legs"]), j.get("gate", "none"), off, miss.dot(line), miss.dot(Vector3(-line.z, 0.0, line.x)), facing,
			"down" if bool(j.get("gear_at_touch", false)) else "UP"])
	var off_at: Vector3 = j.get("off_at", Vector3.INF)
	_check("the_747_turns_off_short_of_the_intersection_and_never_onto_09",
		off_at != Vector3.INF and p36.ahead_of(off_at) < p36.ahead_of(intersection) and int(seen["on_09"]) == 0,
		"off %.0f m past 36's threshold, the intersection %.0f m; %d looks on 09/27" % [p36.ahead_of(off_at) if off_at != Vector3.INF
			else -1.0, p36.ahead_of(intersection), int(seen["on_09"])])
	for entity in [b737, int(seen["b747"])]:
		_traffic.release(entity)
		Sim.server.despawn_vehicle(entity)


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _fly(done: Callable, seconds: float) -> void:
	for i in range(int(seconds * 120.0)):
		await get_tree().physics_frame
		if done.call():
			return


func _start() -> void:
	var waiting: Array = [not Sim.is_ready]
	if bool(waiting[0]):
		Sim.sim_ready.connect(func(): waiting[0] = false, CONNECT_ONE_SHOT)
	Net.play_solo()
	Sim.start()
	var patience := 600
	while bool(waiting[0]) and patience > 0:
		patience -= 1
		await get_tree().physics_frame


func _finish() -> void:
	print("RESULT=%s%s" % ["FAIL " if _failed else "PASS", ", ".join(_said)])
	get_tree().quit(1 if _failed else 0)


func _check(name: String, passed: bool, detail: String) -> void:
	print("[airport] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
	if not passed:
		_failed = true
		_said.append(name)
