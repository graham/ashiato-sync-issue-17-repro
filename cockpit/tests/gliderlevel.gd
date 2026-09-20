extends Node
## Headless: does the glider level stand -- sixteen kilometres of ridge country with its own thermals, a cloud over each
## of them and a sky full of cumulus to fly round, and nothing to fly but a glider?
##
##   Godot --headless --path cockpit res://tests/gliderlevel.tscn
##
## The user, 2026-09-19: "I'd like you to build a smaller level 16km that has our ridge mountains and is designed to be
## flown by gliders, so we'll need lift zones that the gliders can fly to, make sure we have good clouds as well so that
## we have to find our way around the clouds themselves ... The goal is to experiment with what the game is like with
## just gliders." `levels/gliders` is the generated ground with no sea, the island's kind of ridges as data, its own
## thermals as data (`LevelChart.lift`), twice the game's low cloud (`cloud_cover`) and a craft list of one.
##
## THE LEVEL IS ASKED FOR AS A PLAYER ASKS: `Net.choose_level`, then the real flight level is added, as tests/testfield.gd
## does. Every check is against something the level did not compute itself:
##
## - ON THE DESK: the drawer lists it, usable, with its thermals, its cloud cover and its one craft read from the file.
## - THE SAME ON EVERY MACHINE: both worlds stand the same ground (their `ground_report`s field for field and hash for
##   hash), and both worlds' air rises the same at every thermal's core, at the strength the file gives it.
## - SIXTEEN KILOMETRES: the edge band, worked out by `WorldEdge` from what the ground placed, starts between BAND_START.x
##   and BAND_START.y from the middle, and still fits the wire's last resort.
## - THE RIDGES STAND: every range the file lays rises at least MOUNTAIN_RELIEF over the ground round it, and the
##   simulation's own ray meets its top.
## - THE THERMALS ARE THE FILE'S AND A GLIDER CAN USE THEM: `Terrain.lift_zones` is the file's zones and nothing else,
##   named, in its order, the first "the start"; each stands on dry land clear of the rock, its column THERMAL_TOP tall or
##   more; each lifts a CIRCLING glider by CLIMB_LEAST or better where its circle sits; and every one is within a glide of
##   another from its top, arriving HOP_SPARE over the ground, the whole set joined up.
## - A CLOUD OVER EVERY THERMAL, AND TWICE THE SKY: each zone has its cumulus, based at the column's top; and the sky holds
##   `cloud_cover` times the low clouds the same plan holds at the game's cover, with the decks above untouched.
## - GLIDERS ONLY: the rig's own CRAFT page, as the level handed it its rows, offers the glider and nothing else and says
##   why in the file's words; the same rows asked with no list offer more, so the check can fail. And nothing stands in the
##   world that a player could walk into from a seat button except the level's own air traffic (`AirTraffic`), which is
##   tests/gliderlevel_traffic.gd's to hold.
## - THE WINCH (`GliderWinch`, the user: "Any player that joins or crashes should be respawned at the first zone at 1000
##   feet"): alone, this machine's player is launched in a glider over the start's middle, LAUNCH_OVER over the ground
##   under it, at the glider's cruise. Then the player crashes THROUGH THE STICK -- the real W key held, nose down, into
##   the ground -- and the host's `CrewRespawn` puts them back over the start at the same height, in a fresh glider that
##   is first seen within a few ticks' travel of where it was asked for: not on an apron, because the level registers no
##   issue place for the kind it launches. (With another player, over ENet: tests/gliderlevel_peers.gd.)
## - A ROBOT GLIDER SOARS: an unmanned glider flown by `SoaringPilot` through the ordinary autopilot climbs at least
##   ROBOT_CLIMB in the start's thermal, leaves it under the cloud, glides to another thermal and climbs at least
##   ROBOT_SECOND there. Printed: how long each took, and the climb rate. It is started ROBOT_UNDER the cloud base rather
##   than at the launch height, which is the same flying with the first twelve minutes of climb taken out: a climb of
##   1.4 m/s from 1,000 ft to the cloud is a quarter of an hour of simulation, and the suite holds the behaviour, not the
##   patience.
##
## Read RESULT=, not the exit code.

const LEVEL: String = "gliders"
const PATIENCE: int = 3000
const TICKS: float = 32.0
## Where the band may start, metres from the middle per axis: "a smaller level 16km", give or take a kilometre.
const BAND_START := Vector2(7000.0, 9000.0)
const MOUNTAIN_RELIEF: float = 300.0
## WHAT A THERMAL IS FOR, AS THE GLIDER ACTUALLY FLIES: circling at `SoaringPilot.CIRCLE_SPEED` it sits `CIRCLE_OUT` from
## the middle and sinks `CIRCLE_SINK` (measured, see that file), so the air there must rise by that much and CLIMB_LEAST
## more, or the thermal is one nothing can climb in. Between thermals it glides at `SoaringPilot.GLIDE`.
const CLIMB_LEAST: float = 1.0
const GLIDE: float = SoaringPilot.GLIDE
## How high over the ground a glide from one thermal's top must still be when it reaches the next's edge, metres: a
## circuit's height, so a pilot who finds no lift there can still land.
const HOP_SPARE: float = 300.0
## How far under the cloud base a glider leaves a thermal, metres: nobody climbs into the cloud to go on.
const UNDER_THE_BASE: float = 100.0
## The user's 1,000 ft, and how close to it a launch must be asked, metres.
const LAUNCH_OVER: float = 304.8
const LAUNCH_WITHIN: float = 0.5
## How long a crash dive is given to meet the ground, and a respawn to happen after it, seconds of simulation.
const DIVE_SECONDS: float = 40.0
const RESPAWN_PATIENCE: float = CrewRespawn.SECONDS + 6.0
## How far from where it was asked for a respawned glider may first be seen, metres: two ticks at cruise, and a margin.
const FIRST_SEEN_WITHIN: float = 5.0
## What the robot glider must climb in the start's thermal and in the next, metres, how far under the cloud base it starts,
## and how long it is given.
const ROBOT_CLIMB: float = 300.0
const ROBOT_SECOND: float = 100.0
const ROBOT_UNDER: float = 500.0
const ROBOT_SECONDS: float = 1200.0

var _failures: PackedStringArray = []
var _sections: int = 0
var _finished: bool = false
var _level: FlightLevel = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[gliderlevel] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
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
	_check("the_glider_level_can_be_chosen", chosen == "", "'%s'" % chosen)
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
	_check("the_glider_level_stands_and_comes_up", _level.ground_built_msec >= 0.0 and Sim.is_ready and field != null,
		"after %d frames: the ground stood in both worlds in %.0f ms" % [frames, _level.ground_built_msec])
	if field == null or Sim.server == null or Sim.client == null:
		_finish()
		return
	for i in range(30):
		await get_tree().process_frame
	_both_worlds_stand_on_the_same_ground_and_air()
	_the_level_is_sixteen_kilometres()
	_the_ridges_stand(field)
	_the_thermals_are_the_files_and_a_glider_can_use_them()
	_a_cloud_over_every_thermal_and_twice_the_sky()
	_gliders_only()
	_the_solo_arrival_is_launched_over_the_start()
	await _a_crash_through_the_stick_launches_the_crew_back_over_the_start()
	await _a_robot_glider_climbs_at_the_start_and_glides_on()
	_no_fires_burn_and_the_key_is_the_only_reason()
	var sections: int = _sections_written()
	_check("every_section_of_the_suite_ran", _sections == sections, "%d of %d" % [_sections, sections])
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
	_check("the_drawer_lists_the_glider_level_usable", found != null and found.usable() and found.lift.size() >= 6
		and found.cloud_cover > 1.0 and found.craft == [Sim.Kind.GLIDER] and not found.mountains.is_empty()
		and not found.fleet,
		"%s" % ("not listed" if found == null else "%s: %d thermals, cloud cover %.1f, craft %s, %d ranges, refusal '%s'" % [
			found.name, found.lift.size(), found.cloud_cover, found.craft, found.mountains.size(), found.refusal]))
	_sections += 1


func _both_worlds_stand_on_the_same_ground_and_air() -> void:
	var server: Dictionary = Sim.server.ground_report()
	var client: Dictionary = Sim.client.ground_report()
	var same: bool = not server.is_empty() and int(server.get("fields", 0)) > 0
	for key in ["fields", "land_cells", "split_cells", "unheld_fields", "bytes", "hash"]:
		same = same and server.get(key) == client.get(key)
	# THE AIR AT EVERY CORE, 400 m up, in both worlds: what a wing in either feels, against the strength the file wrote.
	var words: PackedStringArray = []
	var alike: int = 0
	for zone in Terrain.lift_zones():
		var core: Vector3 = (zone["position"] as Vector3) + Vector3.UP * 400.0
		var up_server: float = float(Sim.server.rising(core))
		var up_client: float = float(Sim.client.rising(core))
		if is_equal_approx(up_server, up_client) and absf(up_server - float(zone["strength"])) < 0.05:
			alike += 1
		else:
			words.append("%s: %.2f and %.2f, wanted %.2f" % [zone.get("name", "?"), up_server, up_client, zone["strength"]])
	_check("both_worlds_stand_on_the_same_ground_and_the_same_air",
		same and alike == Terrain.lift_zones().size() and alike > 0,
		"ground %s, %.1f MB a world; %d of %d cores rise alike at their strength %s" % [server.get("hash", "?"),
			float(server.get("bytes", 0)) / 1048576.0, alike, Terrain.lift_zones().size(), words])
	_sections += 1


func _the_level_is_sixteen_kilometres() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	var fastest: float = 0.0
	for row in world.turn_radii():
		fastest = maxf(fastest, float((row as Dictionary)["speed"]))
	var worst: float = float(world.worst_turn_radius())
	var guard_from: float = float((world.boundary() as Dictionary)["guard_from"])
	var band: Dictionary = WorldEdge.band_for(Terrain.placed_reach(), worst, guard_from, fastest)
	var margin: float = guard_from - (float(band["start"]) + 2.0 * worst)
	var start: float = float(band["start"])
	_check("the_level_is_sixteen_kilometres_and_its_edge_fits",
		String(band["error"]) == "" and margin > 0.0 and start >= BAND_START.x and start <= BAND_START.y,
		"placed within %.0f m, the band from %.0f m (%.1f km across), warned from %.0f m, %.0f m deep; fits the last resort at %.0f m by %.0f m%s" % [
			Terrain.placed_reach(), start, 2.0 * start / 1000.0, band["warn_from"], band["depth"], guard_from, margin,
			"" if String(band["error"]) == "" else "; " + String(band["error"])])
	_sections += 1


func _the_ridges_stand(field: Object) -> void:
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
		var below: float = float(Sim.server.first_solid_below(peak + Vector3.UP * 50.0, 200.0))
		var hit: float = peak.y + 50.0 - below if below >= 0.0 else -INF
		var stands: bool = best - ground >= MOUNTAIN_RELIEF and absf(hit - best) < 2.0
		standing += 1 if stands else 0
		words.append("salt %d: top %.0f m at (%.0f, %.0f), %.0f m over the ground, the simulation's ground there %.1f" % [
			int(range["salt"]), best, peak.x, peak.z, best - ground, hit])
	_check("every_ridge_stands_in_the_rock_and_the_collision",
		rock != null and not ranges.is_empty() and standing == ranges.size(),
		"; ".join(words) if rock != null else "no rock on this level")
	_sections += 1


func _the_thermals_are_the_files_and_a_glider_can_use_them() -> void:
	var laid: Array[Dictionary] = _level.level.lift
	var zones: Array[Dictionary] = Terrain.lift_zones()
	var words: PackedStringArray = []
	# IN THE FILE'S ORDER AND NAMED, the first "the start".
	var in_order: bool = zones.size() == laid.size() and laid.size() > 0 and String(laid[0]["name"]) == "the start"
	for i in range(mini(laid.size(), zones.size())):
		var at: Vector2 = laid[i]["at"]
		var p: Vector3 = zones[i]["position"]
		in_order = in_order and String(zones[i].get("name", "")) == String(laid[i]["name"]) \
			and is_equal_approx(p.x, at.x) and is_equal_approx(p.z, at.y) \
			and is_equal_approx(float(zones[i]["radius"]), float(laid[i]["radius"]))
	_check("the_thermals_are_the_files_in_its_order_and_the_first_is_the_start", in_order,
		"%d laid, %d zones in all, first '%s'" % [laid.size(), zones.size(), zones[0].get("name", "?") if not zones.is_empty() else "none"])
	# ON DRY LAND, CLEAR OF THE ROCK, TALL ENOUGH, AND WORTH CIRCLING IN.
	var sound: int = 0
	var climbs: PackedStringArray = []
	for zone in zones:
		var p: Vector3 = zone["position"]
		var r: float = float(zone["radius"])
		var dry: bool = Terrain.water_height(p) == -INF
		var clear: bool = Terrain.rock_clears(p, Vector3(r, 0.0, r))
		var tall: bool = float(zone["top"]) - p.y >= Terrain.THERMAL_TOP - 0.5
		# THE AIR WHERE THE CIRCLE SITS, less what the circle costs: what a glider's vario would read.
		var rising: float = float(zone["strength"]) * pow(1.0 - SoaringPilot.CIRCLE_OUT / r, 2.0)
		var climb: float = rising - SoaringPilot.CIRCLE_SINK
		climbs.append("%s %+.1f" % [zone.get("name", "?"), climb])
		if dry and clear and tall and climb >= CLIMB_LEAST:
			sound += 1
		else:
			words.append("%s: dry %s, clear of the rock %s, %.0f m tall, climbing %+.2f m/s" % [zone.get("name", "?"), dry,
				clear, float(zone["top"]) - p.y, climb])
	_check("every_thermal_stands_on_dry_land_clear_of_the_rock_and_is_worth_circling_in",
		sound == zones.size() and sound > 0,
		"%d of %d sound, each climbing at least %.1f m/s at %.0f m out against a %.2f m/s circling sink: %s%s" % [sound,
			zones.size(), CLIMB_LEAST, SoaringPilot.CIRCLE_OUT, SoaringPilot.CIRCLE_SINK, ", ".join(climbs),
			"" if words.is_empty() else "; %s" % words])
	# WITHIN A GLIDE OF ANOTHER, AND ALL JOINED UP: from under a zone's cloud base, the glide to another's edge at GLIDE:1
	# arrives HOP_SPARE or more over the highest ground at that edge.
	var reaches: Dictionary = {}
	var longest_hop: float = 0.0
	for a in range(zones.size()):
		reaches[a] = []
		var from: Vector3 = zones[a]["position"]
		var height: float = float(zones[a]["top"]) - UNDER_THE_BASE
		for b in range(zones.size()):
			if a == b:
				continue
			var to: Vector3 = zones[b]["position"]
			var run: float = maxf(0.0, Vector2(to.x - from.x, to.z - from.z).length() - float(zones[b]["radius"]))
			var arrive: float = height - run / GLIDE
			if arrive - Terrain.highest_near(to, float(zones[b]["radius"])) >= HOP_SPARE:
				(reaches[a] as Array).append(b)
	var seen: Dictionary = {0: true}
	var queue: Array = [0]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for b in reaches[at]:
			if not seen.has(b):
				seen[b] = true
				queue.append(b)
	var nearest: PackedStringArray = []
	for a in range(zones.size()):
		var best: float = INF
		for b in range(zones.size()):
			if a != b:
				var d: float = Vector2((zones[a]["position"] as Vector3).x - (zones[b]["position"] as Vector3).x,
					(zones[a]["position"] as Vector3).z - (zones[b]["position"] as Vector3).z).length()
				best = minf(best, d)
		longest_hop = maxf(longest_hop, best)
		nearest.append("%s %.1f km" % [zones[a].get("name", "?"), best / 1000.0])
	_check("every_thermal_is_a_glide_from_another_and_they_are_all_joined_up",
		seen.size() == zones.size() and zones.size() > 1,
		"%d of %d reached from the start at %.0f:1, arriving %.0f m over the ground; nearest neighbours %s" % [seen.size(),
			zones.size(), GLIDE, HOP_SPARE, ", ".join(nearest)])
	_sections += 1


func _a_cloud_over_every_thermal_and_twice_the_sky() -> void:
	var clouds: Array = _level.puffs.clouds if _level.puffs != null else []
	var by_key: Dictionary = {}
	var low: Dictionary = {}
	var high: Dictionary = {}
	for cloud in clouds:
		if (cloud as Dictionary).has("key"):
			by_key[cloud["key"]] = cloud
			continue
		var bucket: Dictionary = low if PuffSky.LOW.has(String(cloud["kind"])) else high
		bucket[cloud["kind"]] = int(bucket.get(cloud["kind"], 0)) + 1
	var based: int = 0
	var words: PackedStringArray = []
	for zone in Terrain.lift_zones():
		var cloud: Dictionary = by_key.get(LiftYard.cloud_key(zone), {})
		if not cloud.is_empty() and absf(float(cloud["base"]) - float(zone["top"])) < 1.0:
			based += 1
		else:
			words.append("%s: %s" % [zone.get("name", "?"), "no cloud" if cloud.is_empty() else "base %.0f against a top of %.0f" % [
				cloud["base"], zone["top"]]])
	_check("every_thermal_has_its_cloud_based_at_its_top", based == Terrain.lift_zones().size() and based > 0,
		"%d of %d %s" % [based, Terrain.lift_zones().size(), words])
	# THE SAME PLAN AT THE GAME'S COVER, asked of the same function with the same seed and reach, for the counts to hold
	# the level's against.
	var cover: float = _level.level.cloud_cover
	var plain: Dictionary = {}
	var plain_high: Dictionary = {}
	var half: float = minf(float(GroundTuning.WORLD_HALF) + PuffSky.SKY_PAST_THE_LAND, PuffSky.SKY_REACH)
	for cloud in PuffSky.plan(FlightLevel.PUFF_SEED, half):
		var bucket: Dictionary = plain if PuffSky.LOW.has(String(cloud["kind"])) else plain_high
		bucket[cloud["kind"]] = int(bucket.get(cloud["kind"], 0)) + 1
	var covered: bool = not low.is_empty() and high == plain_high
	for kind in PuffSky.LOW:
		covered = covered and absi(int(low.get(kind, 0)) - roundi(float(plain.get(kind, 0)) * cover)) <= 1
	_check("the_sky_holds_cover_times_the_low_clouds_and_the_same_decks_above", covered,
		"cover %.1f: low %s against the game's %s; above %s against %s" % [cover, low, plain, high, plain_high])
	_sections += 1


func _gliders_only() -> void:
	var page: ClipboardPage = null
	if _level.rig != null and _level.rig.clipboard != null:
		page = _level.rig.clipboard.get("_page") as ClipboardPage
	var offered: PackedStringArray = []
	var note: String = ""
	if page != null:
		var grid: HFlowContainer = page.get("_craft_grid")
		for button in grid.get_children():
			offered.append((button as Button).text)
		var label: Label = page.get("_craft_note")
		note = label.text if label != null and label.visible else ""
	var wanted_note: String = VehicleCatalogue.craft_note(false, _level.level.craft, _level.level.craft_why)
	var unlisted: int = VehicleCatalogue.craft_rows_for(false).size()
	# AND NOTHING ELSE STANDS IN THE WORLD except the level's own air traffic: no parked jet from the spawn table, which is
	# one of every movement model and would be a jet a player could walk into from a seat button. The traffic itself is
	# the level's own (`AirTraffic`, its `air_traffic.json`), and tests/gliderlevel_traffic.gd holds what is in it.
	var machines: Dictionary = _level.air_traffic.machines if _level.air_traffic != null else {}
	var others: PackedStringArray = []
	for vehicle in Sim.server.vehicle_states():
		var kind: int = int((vehicle as Dictionary).get("kind", -1))
		if kind != Sim.Kind.GLIDER and VehicleCatalogue.pilotable(kind) \
				and not machines.has(int((vehicle as Dictionary).get("entity", 0))):
			others.append(Sim.kind_name(kind))
	_check("only_the_glider_is_offered_and_the_page_says_why_and_nothing_else_stands",
		page != null and offered.size() == 1 and note == wanted_note and note.contains("soaring") and unlisted > 10
		and others.is_empty(),
		"offered %s, the note '%s'; with no list %d are offered; %d machines of the level's own air traffic; other craft standing: %s" % [
			offered, note, unlisted, machines.size(), others])
	_sections += 1


func _kind_of(entity: int) -> int:
	for vehicle in Sim.server.vehicle_states():
		if int((vehicle as Dictionary).get("entity", 0)) == entity and entity != 0:
			return int((vehicle as Dictionary).get("kind", -1))
	return -1


func _my_craft() -> int:
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", 0)) == Sim.local_client_id():
			return int((pilot as Dictionary).get("vehicle", 0))
	return 0


## WHERE A LAUNCH WAS ASKED FOR, in words and against the rule: over the start's middle, LAUNCH_OVER over its ground, at
## the glider's cruise, beside nobody. Words beginning "WRONG" when it breaks the rule.
func _over_the_start(launch: Dictionary) -> String:
	if launch.is_empty():
		return "WRONG: no launch"
	var start: Vector3 = GliderWinch.first_thermal().get("position", Vector3.INF)
	var at: Vector3 = launch["position"]
	var off: float = Vector2(at.x - start.x, at.z - start.z).length()
	var over: float = at.y - Terrain.ground_height(at)
	var speed: float = (launch["velocity"] as Vector3).length()
	var ok: bool = off < 1.0 and absf(over - LAUNCH_OVER) < LAUNCH_WITHIN and int(launch["beside"]) == -1 \
		and absf(speed - Terrain.cruise_for(Sim.Kind.GLIDER)) < 0.5
	return ("" if ok else "WRONG: ") + "%.1f m from the start's middle, %.2f m over its ground, %.1f m/s, beside %d" % [off,
		over, speed, int(launch["beside"])]


func _the_solo_arrival_is_launched_over_the_start() -> void:
	var mine: Dictionary = {}
	for launch in Sim.winch_launches:
		if int(launch["client"]) == Sim.local_client_id():
			mine = launch
	var craft: int = _my_craft()
	var state: Dictionary = Sim.server.vehicle_state(craft) if craft != 0 else {}
	var at: Vector3 = state.get("position", Vector3.ZERO)
	var words: String = _over_the_start(mine)
	var kind: int = _kind_of(craft)
	_check("alone_a_player_is_launched_in_a_glider_over_the_start_at_1000_ft",
		not words.begins_with("WRONG") and kind == Sim.Kind.GLIDER and at.y - Terrain.ground_height(at) > 200.0,
		"asked %s; the craft a %s, now %.0f m over the ground" % [words, Sim.kind_name(kind),
			at.y - Terrain.ground_height(at)])
	_sections += 1


func _a_crash_through_the_stick_launches_the_crew_back_over_the_start() -> void:
	var wreck: int = _my_craft()
	var respawned_before: int = _level.respawner.respawned if _level.respawner != null else -1
	_key(KEY_W, true)
	var hz: int = Engine.physics_ticks_per_second
	var ticks: int = 0
	var lowest: float = INF
	while ticks < int(DIVE_SECONDS * hz) and not bool((Sim.server.hull_state(wreck) as Dictionary).get("destroyed", false)):
		await get_tree().physics_frame
		ticks += 1
		var at: Vector3 = (Sim.server.vehicle_state(wreck) as Dictionary).get("position", Vector3.ZERO)
		lowest = minf(lowest, at.y - Terrain.ground_height(at))
	_key(KEY_W, false)
	var hull: Dictionary = Sim.server.hull_state(wreck)
	var crashed: bool = bool(hull.get("destroyed", false))
	var dived_s: float = float(ticks) / float(hz)
	var fresh: int = 0
	var first_seen: Vector3 = Vector3.INF
	ticks = 0
	while crashed and ticks < int(RESPAWN_PATIENCE * hz):
		await get_tree().physics_frame
		ticks += 1
		var now: int = _my_craft()
		if now != 0 and now != wreck:
			fresh = now
			first_seen = (Sim.server.vehicle_state(now) as Dictionary).get("position", Vector3.INF)
			break
	var launch: Dictionary = _level.respawner.last_launch if _level.respawner != null else {}
	var words: String = _over_the_start(launch)
	var seen_off: float = first_seen.distance_to(launch.get("position", Vector3.ZERO)) if fresh != 0 else INF
	var kind: int = _kind_of(fresh)
	_check("a_crash_flown_through_the_stick_puts_the_player_back_over_the_start_at_1000_ft",
		crashed and fresh != 0 and _level.respawner.respawned == respawned_before + 1 and not words.begins_with("WRONG")
		and seen_off < FIRST_SEEN_WITHIN and kind == Sim.Kind.GLIDER,
		"W held %.1f s: destroyed %s (%s), %.0f m over the ground at the lowest; a fresh %s %.1f s after it, asked %s, first seen %.2f m from there" % [
			dived_s, crashed, hull, lowest, Sim.kind_name(kind), float(ticks) / float(hz), words, seen_off])
	_sections += 1


func _a_robot_glider_climbs_at_the_start_and_glides_on() -> void:
	var launch: Dictionary = GliderWinch.place(_level.level, Sim.Kind.GLIDER, [])
	var start: Dictionary = GliderWinch.first_thermal()
	var at: Vector3 = launch["position"]
	at.y = float(start["top"]) - ROBOT_UNDER
	var robot: int = Sim.spawn_ai_vehicle(Sim.Kind.GLIDER, at, float(launch["yaw"]), launch["velocity"])
	var pilot := SoaringPilot.new()
	pilot.name = "RobotSoaringPilot"
	_level.add_child(pilot)
	pilot.fly(robot, 0)
	var hz: int = Engine.physics_ticks_per_second
	var ticks: int = 0
	var began: int = Time.get_ticks_msec()
	var second_gain: float = 0.0
	var record: Dictionary = {}
	while ticks < int(ROBOT_SECONDS * hz) and pilot.gliders.has(robot):
		await get_tree().physics_frame
		ticks += 1
		if ticks % hz != 0:
			continue
		record = pilot.gliders[robot]
		var climbs: Array = record["climbs"]
		if climbs.size() >= 2:
			second_gain = float(climbs[1]["to"]) - float(climbs[1]["from"])
			break
		if climbs.size() >= 1 and String(record["phase"]) == "climb":
			var y: float = ((Sim.server.vehicle_state(robot) as Dictionary).get("position", Vector3.ZERO) as Vector3).y
			second_gain = y - float(record["entered_y"])
			if second_gain >= ROBOT_SECOND:
				break
		if ticks % (hz * 60) == 0:
			var p: Vector3 = (Sim.server.vehicle_state(robot) as Dictionary).get("position", Vector3.ZERO)
			print("[gliderlevel] robot at %d s: %s zone %d, %.0f m over the ground" % [ticks / hz, record["phase"],
				int(record["zone"]), p.y - Terrain.ground_height(p)])
	var climbs: Array = record.get("climbs", [])
	var first: Dictionary = climbs[0] if not climbs.is_empty() else {}
	var first_gain: float = float(first.get("to", 0.0)) - float(first.get("from", 0.0))
	var zones: Array[Dictionary] = Terrain.lift_zones()
	var next_zone: int = int(climbs[1]["zone"]) if climbs.size() >= 2 else int(record.get("zone", 0))
	var next_name: String = String(zones[next_zone].get("name", "?"))
	_check("a_robot_glider_climbs_in_the_start_and_leaves_it_under_the_cloud",
		String(first.get("name", "")) == "the start" and first_gain >= ROBOT_CLIMB,
		"climbed %.0f m in %.0f s (%.2f m/s) at '%s', leaving %.0f m over the ground" % [first_gain,
			float(first.get("seconds", 0.0)), first_gain / maxf(float(first.get("seconds", 1.0)), 1.0), first.get("name", "?"),
			float(first.get("to", 0.0)) - Terrain.ground_height(zones[0]["position"])])
	_check("and_glides_to_another_thermal_and_climbs_there",
		second_gain >= ROBOT_SECOND and next_name != "the start",
		"climbed %.0f m at '%s'; %.0f s simulated in %.0f s" % [second_gain, next_name, float(ticks) / float(hz),
			float(Time.get_ticks_msec() - began) / 1000.0])
	pilot.gliders.erase(robot)
	_sections += 1


func _no_fires_burn_and_the_key_is_the_only_reason() -> void:
	# THE LEVEL SAYS `"fires": false` (the user, 2026-09-19: "remove fires from the glider level"). By now the robot section
	# has run a good many seconds of the level's own clock, long enough for the ground's fires to have been lit and to have
	# spread: none is in either world, and there is no front to spread one. The mutant is the key ignored, which lights
	# the ground's fires again.
	var server_fires: int = (Sim.server.fire_states() as Array).size()
	var client_fires: int = Sim.fires.size()
	var wanted: int = Terrain.fires().size()
	_check("the_level_that_says_no_fires_has_none_in_either_world",
		not _level.level.fires and server_fires == 0 and client_fires == 0 and _level.front == null and wanted > 0,
		"the key %s; %d fires in the host's world, %d in a client's, a front %s; the ground would have placed %d" % [
			_level.level.fires, server_fires, client_fires, "built" if _level.front != null else "not built", wanted])
	# AND A LEVEL WITHOUT THE KEY STILL HAS THEM: this same file with the key taken out is a level that lights its fires,
	# and one that gives the key a non-boolean is refused, so the change cannot spread by default or by a typo.
	var data: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://levels/%s/%s" % [LEVEL, LevelChart.FILE]))
		as Dictionary)
	data.erase("fires")
	var keyless := LevelChart.new()
	keyless._take(data)
	data["fires"] = "no"
	var typo := LevelChart.new()
	typo._take(data)
	_check("a_level_without_the_key_keeps_its_fires_and_a_typo_is_refused",
		keyless.usable() and keyless.fires and not typo.usable(),
		"keyless: usable %s, fires %s; typo: '%s'" % [keyless.usable(), keyless.fires, typo.refusal])
	_sections += 1


func _key(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


func _on_a_session_ended(reason: String) -> void:
	if _finished:
		return
	_check("the_glider_level_stands_and_comes_up", false, "the session ended while it loaded: %s" % reason)
	_finish()


func _finish() -> void:
	_finished = true
	Sim.stop()
	Net.leave("suite over")
	Net.choose_level(ChartDrawer.DEFAULT)
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
