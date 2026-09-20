extends Node
## Headless: does every ship the levels drive sail only where the water floats it -- every leg it chooses deep enough the
## whole way for its own keel, and never a second aground -- on every world the desk offers?
##
##   Godot --headless --path cockpit res://tests/ship_legs.tscn
##
## THE BUG IT HOLDS (carrier lane step 4c, 2026-09-15). Every Model::Boat kind chose its legs by boxes alone, and on the
## generated ground a pool filtered for a launch's depth sent the capital ships across land: in four minutes on alpine all
## three of the carrier's legs and both of the battleship's crossed ground (0.00 m of water), and the carrier sailed up the
## shelf at 10 m/s and sat beached with its origin 10.31 m out of the water, heeled 5.7 degrees, its route still set. The
## island's sea has no floor, so the island never showed it.
##
## WHAT IS HELD, per world (every chart the desk offers, flown the way a player flies it, as tests/level_swap.gd does) and
## per kind the levels drive (`DRIVEN`):
## - EVERY LEG HAS ITS NEED THE WHOLE WAY. A leg is noticed the tick a ship's `route` changes in `vehicle_states`, from where
##   the ship is then to the route, and sounded every `SOUND_STEP` metres -- a quarter of the simulation's own step, so this
##   is not its own test run twice -- with `water_depth_at` against `ai_leg_rules(kind)["need"]`. A kind with no leg chosen
##   fails: a check that passes on ships that never chose passes on anything.
## - NO DRIVEN SHIP RUNS AGROUND. Once a simulated second, a ship that has had a route must have at least its draught of
##   water under it. A sounded leg over deep water can still be sailed off by the swell or a turn; this is what a player sees.
## - THE LEVEL DRIVES NO GUNBOAT. The gunboats are parked spawns, so there are no gunboat legs to hold; if a level starts
##   driving one this fails, and a gunboat row goes into `DRIVEN` instead of passing as "none shallow".
## - THE KEEL CLEARANCE IS HELD, by a leg built by hand on alpine: a straight `LEG` whose shallowest water lies strictly
##   between the carrier's draught and its need, found by sweeping round the carrier's spawn and printed.
##   `sea_leg_is_deep` must refuse it at the need and take it at the draught, and the need must be the draught and the keel
##   clearance, all three asked of the simulation. The level's traffic never chooses such a leg -- after the fix its
##   shallowest had 20.00 m against a 14.90 m need -- and `ai_leg_rules` first worked "need" out beside `leg_need`, so a
##   `leg_need` that dropped the clearance passed every other check here (4c's mutant c).
## - THE DRAUGHT IS TERRAIN'S. `ai_leg_rules(kind)["draught"]` + Terrain.SHIP_KEEL_ROOM is Terrain.ship_depth(kind) for
##   every ship kind, so terrain.gd can read the draught from the simulation and nothing it places moves; and a leg's need
##   is more than the draught, so the keel room is there.
##
## Read RESULT=, not the exit code.

const PATIENCE: int = 2400
## Seconds of simulation each world is watched for. On 3490529c's library every ship chose its first leg at spawn -- the
## carrier's across land -- and the carrier was aground by s 71, so 100 s sees both. It was 240 s, and the suite took 171 s
## of wall clock quietly and was killed at run_all's 180 s deadline under a full gate's load (2026-09-15).
const WATCH_SECONDS: float = 100.0
## How often the ships are read, physics frames: a new route is noticed within a tenth of a second.
const LOOK_EVERY: int = 12
## Metres between soundings along a leg.
const SOUND_STEP: float = 25.0
## THE KINDS THE LEVELS DRIVE, whose legs and keels are held. Parked kinds are not here; see the gunboat check.
## The submarine, since cockpit-fleet's step 4 put one to sea: at step 1 its row met no submarine and read "0 legs".
const DRIVEN: Array[int] = [Sim.Kind.CARRIER, Sim.Kind.BATTLESHIP, Sim.Kind.BOAT, Sim.Kind.SUBMARINE]
## Every ship kind whose draught terrain works out, and every one watched. THE SUBMARINE TOO: the leg loop skips a kind not
## here before it counts, so a submarine row in DRIVEN alone read "0 legs" with one sailing (cockpit-fleet step 4).
const SHIPS: Array[int] = [Sim.Kind.CARRIER, Sim.Kind.BATTLESHIP, Sim.Kind.GUNBOAT, Sim.Kind.BOAT, Sim.Kind.SUBMARINE]
const WITHIN: float = 0.000001
## The hand-built leg: how far round the carrier's spawn the sweep looks, how finely, and how long the leg is.
const SWEEP_HALF: float = 3000.0
const SWEEP_STEP: float = 50.0
const LEG: float = 100.0

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[ship_legs] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	# A WATCHER THAT OUTLIVES THE SCENE: flying a level changes the current scene, so this re-adds itself under the root,
	# as tests/level_swap.gd does.
	if get_tree().current_scene != self:
		_run()
		return
	var watcher := Node.new()
	watcher.name = "ShipLegsWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld missing")
		_finish()
		return
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	# EVERY LEVEL WITH A SEA IN IT. A level whose world is a ROOM -- the lobby's briefing room -- has no water, no ships
	# and nowhere to sail one: every leg on it is refused, which is correct and says nothing at all about ship legs. So
	# an indoor level is COUNTED and skipped rather than silently left out, and the last check still holds that every
	# level the desk offers was one or the other. See `LevelChart.indoors`.
	var worlds: PackedStringArray = []
	var indoors: PackedStringArray = []
	# AND A LEVEL WHOSE GROUND HAS NO SEA -- the test field (lane/testfield, 2026-09-19) -- is counted and skipped the same
	# way, asked of its own ground before it is flown: sailed, it put no ship anywhere and failed every leg check on 0 legs,
	# which is correct and says nothing about ship legs, and it cost the suite a level's load and watch.
	var dry: PackedStringArray = []
	var no_fleet: PackedStringArray = []
	for chart in ChartDrawer.charts():
		if chart.indoors():
			indoors.append(chart.id)
			continue
		if GroundTuning.takes_numbers(GroundTuning.world_named(chart.world)):
			var ground: Object = ClassDB.instantiate("GroundField")
			ground.call("configure", GroundTuning.for_level(chart))
			if not Terrain.sea_in(ground):
				dry.append(chart.id)
				continue
		# A LEVEL WITH A SEA BUT NO FLEET -- the adriatic, `"fleet": false` since 2026-09-19 -- drives no ship at all: its
		# craft are the player's and its traffic file, where it has one, flies aeroplanes. Sailed, it chose no leg and
		# failed all four kinds on 0 legs, red on main from the day the level landed (lane/shiplegs, 2026-09-20: 0 legs and
		# 0 s waiting, so no ship ever had a route; not a shallow sea). Counted and skipped, asked of the level's own
		# `fleet` and not of a roster, so a level that flies ships still fails on 0 legs.
		if not chart.fleet:
			no_fleet.append(chart.id)
			continue
		worlds.append(chart.id)
	var drafts_checked: bool = false
	for id in worlds:
		var flew: bool = await _fly(id)
		_check("the_%s_level_comes_up" % id, flew, "the world %s" % ["came up" if flew else "never came up"])
		if not flew:
			continue
		if not drafts_checked:
			_the_draught_is_terrains()
			drafts_checked = true
		if id == "alpine":
			_the_keel_clearance_is_held()
			_a_boat_decision_costs_at_worst(id)
		await _watch(id)
		await _back_to_the_desk()
	_check("every_world_the_desk_offers_was_sailed_or_is_a_room_or_dry_or_flies_no_ships",
		worlds.size() + indoors.size() + dry.size() + no_fleet.size() == ChartDrawer.charts().size() and worlds.size() >= 2,
		"sailed %s, indoors %s, no sea %s, no fleet %s" % [worlds, indoors, dry, no_fleet])
	_finish()


## WHAT A BOAT'S DECISION COSTS AT WORST, on this world's biggest ship pool (team-lead, 2026-09-15). `choose_waypoint` sounds
## every point of a boat's pool once in each of two passes, so from each start every other point is sounded twice here,
## through the binding, stopping at the first shallow sounding as the simulation does. The worst start's time bounds one
## decision's soundings from above: binding calls included, the box sweep not. Printed, not held: a cost to read, not a rule.
func _a_boat_decision_costs_at_worst(world: String) -> void:
	var biggest: Array[Vector3] = []
	var biggest_kind: int = -1
	for kind in SHIPS:
		var pool: Array[Vector3] = Terrain.waypoints(kind, null)
		if pool.size() > biggest.size():
			biggest = pool
			biggest_kind = kind
	if biggest_kind < 0:
		print("[ship_legs] no ship pool on %s to time" % world)
		return
	var need: float = float(Sim.server.ai_leg_rules(biggest_kind).get("need", 0.0))
	var worst: int = 0
	for from in biggest:
		var began: int = Time.get_ticks_usec()
		for sweep in range(2):
			for to in biggest:
				if to != from:
					Sim.server.sea_leg_is_deep(from, to, need)
		worst = maxi(worst, Time.get_ticks_usec() - began)
	print("[ship_legs] a boat's decision on %s at worst: %.2f ms of soundings, the %s pool's %d points twice from the worst start, at %.2f m" % [
		world, float(worst) / 1000.0, Sim.kind_name(biggest_kind), biggest.size(), need])


## ai_leg_rules' draught against terrain's own formula, and a need above it, for every ship kind.
func _the_draught_is_terrains() -> void:
	var wrong: Array = []
	for kind in SHIPS:
		var rules: Dictionary = Sim.server.ai_leg_rules(kind)
		var draught: float = float(rules.get("draught", -1.0))
		var need: float = float(rules.get("need", -1.0))
		var terrain: float = Terrain.ship_depth(kind)
		if absf(draught + Terrain.SHIP_KEEL_ROOM - terrain) > WITHIN or need <= draught:
			wrong.append([Sim.kind_name(kind), draught, need, terrain])
	_check("every_ships_draught_is_the_one_terrain_places_it_by_and_its_leg_needs_more", wrong.is_empty(),
		"%s" % ["draught + %.1f = ship_depth, need > draught, for all %d" % [Terrain.SHIP_KEEL_ROOM, SHIPS.size()]
			if wrong.is_empty() else "%s" % [wrong]])


## THE KEEL CLEARANCE, HELD BY A LEG BUILT BY HAND: the carrier's need is its draught and keel clearance as the simulation
## gives them, and a straight leg whose shallowest water lies between the two is refused at the need and taken at the draught.
func _the_keel_clearance_is_held() -> void:
	var rules: Dictionary = Sim.server.ai_leg_rules(Sim.Kind.CARRIER)
	var draught: float = float(rules.get("draught", 0.0))
	var clearance: float = float(rules.get("keel_clearance", 0.0))
	var need: float = float(rules.get("need", 0.0))
	_check("the_carriers_need_is_its_draught_and_its_keel_clearance",
		clearance > 0.0 and absf(need - (draught + clearance)) <= WITHIN,
		"need %.3f, draught %.3f, keel clearance %.3f" % [need, draught, clearance])
	var centre := Vector3.ZERO
	for spawn in Terrain.spawns():
		if int(spawn["kind"]) == Sim.Kind.CARRIER:
			centre = spawn["position"]
			break
	var tried: int = 0
	var in_band: int = 0
	var leg: Array = []
	var x: float = centre.x - SWEEP_HALF
	while x <= centre.x + SWEEP_HALF and leg.is_empty():
		var z: float = centre.z - SWEEP_HALF
		while z <= centre.z + SWEEP_HALF and leg.is_empty():
			tried += 1
			var here: float = float(Sim.server.water_depth_at(x, z))
			if here > draught and here < need:
				in_band += 1
				for i in range(8):
					var a: float = TAU * float(i) / 8.0
					var from := Vector3(x, 0.0, z)
					var to := Vector3(x + cos(a) * LEG, 0.0, z + sin(a) * LEG)
					var least: float = _shallowest(from, to)
					if float(Sim.server.water_depth_at(to.x, to.z)) >= need and least > draught and least < need:
						leg = [from, to, least]
						break
			z += SWEEP_STEP
		x += SWEEP_STEP
	if leg.is_empty():
		_check("a_leg_between_the_carriers_draught_and_its_need_was_found", false,
			"%d points swept every %.0f m within %.0f m of the carrier's spawn %s, %d with water between %.2f and %.2f m, none with a %.0f m leg to deeper water" % [
				tried, SWEEP_STEP, SWEEP_HALF, centre, in_band, draught, need, LEG])
		return
	var at_need: bool = bool(Sim.server.sea_leg_is_deep(leg[0], leg[1], need))
	var at_draught: bool = bool(Sim.server.sea_leg_is_deep(leg[0], leg[1], draught))
	_check("a_leg_shallower_than_the_carriers_need_is_refused_and_one_deeper_than_its_draught_taken",
		not at_need and at_draught,
		"leg %s -> %s, shallowest %.2f m (draught %.2f, need %.2f): at the need %s, at the draught %s; %d points swept, %d in the band" % [
			leg[0], leg[1], leg[2], draught, need, at_need, at_draught, tried, in_band])


## Follow every ship for WATCH_SECONDS: its legs as it chooses them, and the water under it each second.
func _watch(world: String) -> void:
	var legs: Dictionary = {}
	var aground: Dictionary = {}
	var driven_gunboats: int = 0
	var last_route: Dictionary = {}
	var driven: Dictionary = {}
	# Physics frames each driven ship spent with no route after its first: the retry wait, reported beside its legs.
	var waited: Dictionary = {}
	var ticks: int = int(WATCH_SECONDS * float(Engine.physics_ticks_per_second))
	var each_second: int = Engine.physics_ticks_per_second
	for t in range(ticks):
		await get_tree().physics_frame
		if t % LOOK_EVERY != 0:
			continue
		for state in Sim.server.vehicle_states():
			var kind: int = int(state["kind"])
			if not (kind in SHIPS):
				continue
			var entity: int = int(state["entity"])
			var at: Vector3 = state["position"]
			if not bool(state.get("has_route", false)) and driven.has(entity):
				waited[entity] = int(waited.get(entity, 0)) + LOOK_EVERY
			if bool(state.get("has_route", false)):
				if kind == Sim.Kind.GUNBOAT and not driven.has(entity):
					driven_gunboats += 1
				driven[entity] = kind
				var route: Vector3 = state["route"]
				if not (last_route.has(entity) and (last_route[entity] as Vector3).distance_to(route) < 1.0):
					last_route[entity] = route
					if not legs.has(kind):
						legs[kind] = []
					(legs[kind] as Array).append([at, route])
			if driven.has(entity) and t % each_second == 0:
				var draught: float = float(Sim.server.ai_leg_rules(kind).get("draught", 0.0))
				var water: float = float(Sim.server.water_depth_at(at.x, at.z))
				if water < draught:
					if not aground.has(kind):
						aground[kind] = []
					(aground[kind] as Array).append([entity, t / each_second, snappedf(water, 0.01), at])
	for kind in DRIVEN:
		var need: float = float(Sim.server.ai_leg_rules(kind).get("need", 0.0))
		var chosen: Array = legs.get(kind, [])
		var shallow: Array = []
		for leg in chosen:
			var least: float = _shallowest(leg[0], leg[1])
			if least < need:
				shallow.append([leg[0], leg[1], snappedf(least, 0.01)])
		var kind_label: String = Sim.kind_name(kind)
		# HOW LONG ITS SHIPS WAITED WITH NO LEG, so a ship idling in the retry wait is seen, not read as sailing well.
		var waited_longest: float = 0.0
		var waited_total: float = 0.0
		for entity in driven:
			if int(driven[entity]) == kind:
				var seconds: float = float(waited.get(entity, 0)) / float(Engine.physics_ticks_per_second)
				waited_total += seconds
				waited_longest = maxf(waited_longest, seconds)
		_check("every_%s_leg_has_its_need_the_whole_way_%s" % [kind_label, world], not chosen.is_empty() and shallow.is_empty(),
			"%d legs at %.2f m, %d shallower%s; %.0f s waiting for a leg, the longest %.0f s" % [chosen.size(), need,
				shallow.size(), "" if shallow.is_empty() else ": %s" % [shallow.slice(0, 3)], waited_total, waited_longest])
		var beached: Array = aground.get(kind, [])
		_check("no_driven_%s_runs_aground_%s" % [kind_label, world], beached.is_empty(),
			"%d seconds aground%s" % [beached.size(), "" if beached.is_empty() else ", first %s" % [beached[0]]])
	_check("the_%s_level_drives_no_gunboat" % world, driven_gunboats == 0,
		"%d gunboats with a route; if a level drives them, a gunboat row belongs in DRIVEN" % driven_gunboats)


func _shallowest(from: Vector3, to: Vector3) -> float:
	var run := Vector2(to.x - from.x, to.z - from.z)
	var steps: int = maxi(1, int(run.length() / SOUND_STEP))
	var least: float = INF
	for i in range(steps + 1):
		var u: float = float(i) / float(steps)
		least = minf(least, float(Sim.server.water_depth_at(from.x + run.x * u, from.z + run.y * u)))
	return least


## THE WAY A PLAYER FLIES A LEVEL, as tests/level_swap.gd: at the desk, the level's button, then "Fly on your own".
func _fly(id: String) -> bool:
	if not get_tree().current_scene is DeskRoom:
		await _back_to_the_desk()
	var desk := get_tree().current_scene as DeskRoom
	var panel := desk.get("_panel") as TouchPanel if desk != null else null
	var menu := panel.shown() as SessionMenu if panel != null else null
	var shelf := desk.get("_charts") as TouchPanel if desk != null else null
	var charts := shelf.shown() as ChartMenu if shelf != null else null
	if menu == null or charts == null or not charts.level_buttons.has(id):
		return false
	(charts.level_buttons[id] as Button).pressed.emit()
	for node in menu.find_children("*", "Button", true, false):
		if (node as Button).text == "Fly on your own":
			(node as Button).pressed.emit()
			break
	return await _wait_for(func() -> bool:
		var level := get_tree().current_scene as FlightLevel
		return level != null and level.level != null and level.level.id == id and Sim.is_ready)


func _back_to_the_desk() -> void:
	Doors.to_the_desk()
	await _wait_for(func() -> bool:
		var desk := get_tree().current_scene as DeskRoom
		return desk != null and desk.get("_menu") != null)


func _wait_for(until: Callable) -> bool:
	for i in range(PATIENCE):
		if until.call():
			return true
		await get_tree().physics_frame
	return until.call()


func _finish() -> void:
	Sim.stop()
	Net.leave("suite over")
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
