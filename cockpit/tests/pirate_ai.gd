extends Node
## Headless: the sea the brigs are sent about, and the water they need under them.
##
##   Godot --headless --path cockpit res://tests/pirate_ai.tscn
##
## THE PIRATE LANE'S STEP 3: what the level hands the simulation, and the sailor that uses it -- a chore on the rota that
## beats, tacks and keeps off the shoals (`CockpitWorld.sail_chore`), in worlds ticked by hand, then the level's own.
##
## NOTHING HERE READS A NUMBER BACK FROM WHERE IT WAS TYPED. The pool is asked of `Terrain.waypoints` and held to the ring
## `Terrain` says and to open sea as `open_sea_near` finds it; the depth a brig needs is held to a brig floated in a world
## and measured, not to the formula that computes it; the sailor is held to where it got, what the water under it was, and
## how often it decided; the weather is asked of both of the level's worlds after it boots.
##
## Read RESULT=, not the exit code.

## A brig left to settle in still air on the standing swell: long enough for heave to die away.
const SETTLE_SECONDS: float = 40.0
const MEASURE_SECONDS: float = 10.0
## How near the floated draught must be to the one `Terrain.pirate_depth` works from, metres.
const DRAUGHT_TOLERANCE: float = 0.3

var _failures: PackedStringArray = []
var _sections: int = 0
const SECTIONS: int = 8


func _check(label: String, ok: bool, detail: String) -> void:
	print("[pirate_ai] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	# EACH SECTION COUNTS ITSELF ON ITS LAST LINE: a GDScript error ends the function and the caller carries on.
	_the_pool_rings_the_island_on_open_sea()
	_a_brig_is_sent_only_where_its_floated_keel_clears()
	_a_brig_beats_to_its_waypoints_and_keeps_off_a_shoal()
	_a_brig_with_only_a_short_leg_still_hops()
	_the_angle_it_beats_at_makes_good_to_windward()
	_five_brigs_sail_inside_their_budget()
	_a_brig_rolls_back_upright_with_its_own_period()
	# LAST, because it starts a session.
	await _the_level_gives_both_worlds_the_weather()
	_finish()


func _finish() -> void:
	_check("every_section_ran_to_its_end", _sections == SECTIONS, "%d of %d" % [_sections, SECTIONS])
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


## THE BRIGS' POOL RINGS THE ISLAND, WELL OFF IT, ON OPEN SEA. Every point is further out than the ring's inner edge and
## no further than `Terrain.placed_reach()`, so the level's boundary band starts past every brig; every point is open sea
## as `Terrain.open_sea_near` answers it for a brig's depth (it hands the point straight back); there are points in all
## four quarters, so a brig beating about has somewhere upwind whichever way the wind is; and there are enough of them to
## be a patrol.
func _the_pool_rings_the_island_on_open_sea() -> void:
	var pool: Array[Vector3] = Terrain.waypoints(Sim.Kind.PIRATE, BoxGrid.new(Terrain.boxes()))
	var inner: float = Terrain.WORLD_HALF + Terrain.PIRATE_SEA_INNER
	var outer: float = Terrain.placed_reach()
	var depth: float = Terrain.pirate_depth()
	var inside: Array[Vector3] = []
	var beyond: Array[Vector3] = []
	var not_sea: Array[Vector3] = []
	var quarters: Dictionary = {}
	for at in pool:
		if maxf(absf(at.x), absf(at.z)) <= inner:
			inside.append(at)
		if Vector2(at.x, at.z).length() > outer:
			beyond.append(at)
		var sea: Vector3 = Terrain.open_sea_near(at, depth)
		if sea == Vector3.INF or Vector2(sea.x - at.x, sea.z - at.z).length() > 1.0:
			not_sea.append(at)
		quarters[Vector2i(signi(int(at.x)), signi(int(at.z)))] = true
	_check("the_brigs_have_a_pool_big_enough_to_patrol", pool.size() >= Terrain.PIRATE_POOL / 2,
		"%d points of %d tried" % [pool.size(), Terrain.PIRATE_POOL])
	_check("and_none_is_inside_the_rings_inner_edge", inside.is_empty(),
		"%d inside %.0f m: %s" % [inside.size(), inner, inside.slice(0, 3)])
	_check("and_none_past_the_placed_reach_where_the_boundary_band_begins", beyond.is_empty(),
		"%d past %.0f m" % [beyond.size(), outer])
	_check("and_every_one_is_open_sea_deep_enough_for_a_brig", not_sea.is_empty(),
		"%d not open sea %.1f m deep: %s" % [not_sea.size(), depth, not_sea.slice(0, 3)])
	var every_quarter: bool = quarters.has(Vector2i(1, 1)) and quarters.has(Vector2i(1, -1)) \
		and quarters.has(Vector2i(-1, 1)) and quarters.has(Vector2i(-1, -1))
	_check("and_they_lie_all_round_the_island", every_quarter, "quarters %s" % [quarters.keys()])
	# AND THE BRIGS START ON IT: every spawn one of the pool's own points, so inside the reach and on open sea too.
	var spawns: Array[Dictionary] = Terrain.pirates(BoxGrid.new(Terrain.boxes()))
	var strays: Array[Vector3] = []
	for one in spawns:
		var at: Vector3 = one["position"]
		var on_pool: bool = false
		for point in pool:
			on_pool = on_pool or Vector2(point.x - at.x, point.z - at.z).length() < 1.0
		if not on_pool or int(one["kind"]) != Sim.Kind.PIRATE or (one["velocity"] as Vector3).length() < 1.0:
			strays.append(at)
	_check("and_the_brigs_start_on_it_under_way", spawns.size() == Terrain.PIRATE_FLEET and strays.is_empty(),
		"%d spawns of %d, %d not a moving brig on the pool: %s" % [spawns.size(), Terrain.PIRATE_FLEET, strays.size(), strays])
	_sections += 1


## THE DEPTH A BRIG IS SENT TO IS ITS FLOATED KEEL AND THE KEEL ROOM. A brig is spawned in a world of its own in still air,
## left to settle, and its keel is measured under the swell beneath it -- the hull's half height less its centre's
## height over `swell_height_at` there, which is the draught the simulation floats it at. `Terrain.pirate_depth` must be
## that draught and `Terrain.SHIP_KEEL_ROOM`, to a few centimetres; a depth worked out from the wrong numbers is a brig
## sent over water that will not float it.
func _a_brig_is_sent_only_where_its_floated_keel_clears() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	var at := Vector3(-11000.0, 0.0, 3000.0)
	var ship: int = int(world.spawn_ai_vehicle(Sim.Kind.PIRATE, at, 0.0, Vector3.ZERO))
	world.hold_course(ship, 0.0)
	var half: float = float((world.kind_geometry(Sim.Kind.PIRATE).get("extents", Vector3.ZERO) as Vector3).y)
	for i in range(int(SETTLE_SECONDS * 120.0)):
		world.tick(1.0 / 120.0)
	var keel_sum: float = 0.0
	var samples: int = 0
	for i in range(int(MEASURE_SECONDS * 120.0)):
		world.tick(1.0 / 120.0)
		if i % 12 != 0:
			continue
		var place: Vector3 = (world.vehicle_state(ship) as Dictionary).get("position", Vector3.ZERO)
		keel_sum += half - (place.y - float(world.swell_height_at(place.x, place.z)))
		samples += 1
	var draught: float = keel_sum / maxf(float(samples), 1.0)
	var wanted: float = Terrain.pirate_depth()
	_check("a_brig_floats_with_a_keel_under_the_swell", samples > 0 and draught > 1.0 and draught < 2.0 * half,
		"%.2f m of draught over %d samples, hull half height %.2f m" % [draught, samples, half])
	_check("and_the_depth_it_is_sent_to_is_that_keel_and_the_keel_room",
		absf(wanted - Terrain.SHIP_KEEL_ROOM - draught) < DRAUGHT_TOLERANCE,
		"pirate_depth %.2f m = keel room %.1f m + %.2f m, floated %.2f m" % [wanted, Terrain.SHIP_KEEL_ROOM,
			wanted - Terrain.SHIP_KEEL_ROOM, draught])
	world.teardown()
	if not (world is RefCounted):
		world.free()
	_sections += 1


## A BRIG BEATS TO ITS WAYPOINTS AND KEEPS OFF A SHOAL, sailed by nothing but its sailor. A world of its own, a steady wind
## from the north, and a pool of two points 1.8 km apart, one dead upwind of the other, so every other leg is a beat: the
## brig is put in the water beside the lower one, where the upper is the only leg long enough. A static box stands out of
## the sea ON THE LINE between them, so every beat's boards cross it and one must sound it ahead and turn away: the first
## version put it 420 m off the beat, the brig tacked short of it (111 m) and turned for it 0 times, so a sailor that never
## sounded ahead passed. It must reach its waypoints, tack beating up, turn for the shoal at least once, never put its
## hull over water shallower than its draught nor across the shoal, and decide about once in the sail chore's target --
## not every tick. Positions sampled every second.
##
## THE TIME IS A CEILING; the run stops at the third leg. The beat makes about 0.8 m/s good (the VMG section), so the
## 1.85 km up is some 38 minutes and the run back ten more: the first version's 45 minutes ended one waypoint short.
const SAIL_MINUTES: float = 75.0
const SAIL_WIND: float = 9.0

func _a_brig_beats_to_its_waypoints_and_keeps_off_a_shoal() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.set_weather({"from": 0.0, "low": SAIL_WIND, "high": SAIL_WIND, "veer": 0.0, "seed": 1})
	var lower := Vector3(-11000.0, 0.0, 2000.0)
	var upper := lower + Vector3(0.0, 0.0, -1800.0)
	world.add_ai_waypoint(Sim.Kind.PIRATE, lower)
	world.add_ai_waypoint(Sim.Kind.PIRATE, upper)
	var shoal := lower + Vector3(0.0, -5.0, -900.0)
	var shoal_half := Vector3(100.0, 6.0, 100.0)
	world.add_static_box(shoal, shoal_half)
	var ship: int = int(world.spawn_ai_vehicle(Sim.Kind.PIRATE, lower + Vector3(0.0, 0.0, 300.0), -PI * 0.5, Vector3(3.0, 0.0, 0.0)))
	var geometry: Dictionary = world.kind_geometry(Sim.Kind.PIRATE)
	var draught: float = float((geometry.get("rig", {}) as Dictionary).get("waterline", 0.0)) \
		+ float((geometry.get("extents", Vector3.ZERO) as Vector3).y)
	var shallowest: float = INF
	var nearest_shoal: float = INF
	var report: Dictionary = {}
	var ticks: int = 0
	var limit: int = int(SAIL_MINUTES * 60.0 * 120.0)
	while ticks < limit:
		world.tick(1.0 / 120.0)
		ticks += 1
		if ticks % 120 != 0:
			continue
		var at: Vector3 = (world.vehicle_state(ship) as Dictionary).get("position", Vector3.ZERO)
		shallowest = minf(shallowest, float(world.water_depth_at(at.x, at.z)))
		nearest_shoal = minf(nearest_shoal, Vector2(maxf(absf(at.x - shoal.x) - shoal_half.x, 0.0),
			maxf(absf(at.z - shoal.z) - shoal_half.z, 0.0)).length())
		report = world.sailor_report(ship)
		if int(report.get("legs", 0)) >= 3:
			break
	var minutes: float = float(ticks) / 120.0 / 60.0
	_check("a_brig_sails_to_its_waypoints_by_itself", int(report.get("legs", 0)) >= 3,
		"%d legs begun in %.1f minutes (the third is begun on reaching the second waypoint)" % [int(report.get("legs", 0)), minutes])
	_check("and_beating_up_to_the_upper_one_it_tacks", int(report.get("tacks", 0)) >= 2,
		"%d tacks, %d gybes, beating at %.0f degrees off the wind" % [int(report.get("tacks", 0)), int(report.get("gybes", 0)),
			rad_to_deg(float(report.get("close_hauled", 0.0)))])
	_check("and_its_hull_never_goes_over_the_shoal", nearest_shoal > 0.0 and shallowest >= draught and int(report.get("shoals", 0)) >= 1,
		"nearest the shoal's edge %.0f m, shallowest water under it %.1f m against a %.2f m draught, %d shoal turns" % [
			nearest_shoal, shallowest, draught, int(report.get("shoals", 0))])
	var decisions: int = int(report.get("decisions", 0))
	var expected: float = float(ticks) / 60.0
	_check("and_it_decides_on_the_rota_about_twice_a_second_not_every_tick",
		decisions > 0 and absf(float(decisions) - expected) <= expected * 0.15,
		"%d decisions in %d ticks, against %.0f at one a half second" % [decisions, ticks, expected])
	world.teardown()
	if not (world is RefCounted):
		world.free()
	_sections += 1


## A BRIG WITH ONLY A SHORT LEG STILL HOPS. A pool of two points further apart than the sailing rules' hop and nearer than
## a ship's shortest leg, both asked of the simulation (`ai_leg_rules`), in a world of its own with a steady wind: put in
## the water on one of them, the brig must begin a leg to the other within a minute, by `choose_sea_waypoint`'s last pass.
## Without that pass it holds its heading for ever: one of the alpine level's brigs was spawned in a corner of the shelf
## with a wet leg of 800 m and none of 1,500 and began no leg (terrain_level, 2026-09-15), and the mutant that took the
## pass away lived once the pool filter moved the level's brigs, because nothing else asks for a hop.
const HOP_SECONDS: float = 60.0

func _a_brig_with_only_a_short_leg_still_hops() -> void:
	var world: Object = _sailing_world(9.0)
	var rules: Dictionary = world.ai_leg_rules(Sim.Kind.PIRATE)
	var hop: float = float(rules.get("hop", 0.0))
	var shortest: float = float(rules.get("shortest", 0.0))
	var apart: float = (hop + shortest) * 0.5
	var here := Vector3(-11000.0, 0.0, 6000.0)
	world.add_ai_waypoint(Sim.Kind.PIRATE, here)
	world.add_ai_waypoint(Sim.Kind.PIRATE, here + Vector3(apart, 0.0, 0.0))
	var ship: int = int(world.spawn_ai_vehicle(Sim.Kind.PIRATE, here, -PI * 0.5, Vector3(3.0, 0.0, 0.0)))
	var report: Dictionary = {}
	for i in range(int(HOP_SECONDS * 120.0)):
		world.tick(1.0 / 120.0)
		if i % 120 == 0:
			report = world.sailor_report(ship)
			if int(report.get("legs", 0)) >= 1:
				break
	_check("a_brig_with_only_a_short_leg_still_hops",
		hop > 0.0 and hop < shortest and int(report.get("legs", 0)) >= 1 and bool(report.get("has_waypoint", false)),
		"%d legs, waypoint %s, the other point %.0f m off (hop %.0f m, shortest %.0f m)" % [int(report.get("legs", 0)),
			report.get("waypoint", Vector3.ZERO), apart, hop, shortest])
	world.teardown()
	if not (world is RefCounted):
		world.free()
	_sections += 1


## THE ANGLE IT BEATS AT MAKES GOOD TO WINDWARD. The sailor beats at `close_hauled`, derived from the rig and not from the
## polar; so a brig is held at that angle off a steady wind, and at 50, 60, 75 and 90 degrees, and its speed made good
## straight upwind over the last minute of two and a half is compared: the chosen angle must make at least 80 per cent of
## the best of them. The polar's own numbers are tests/sailing.gd's; this holds the sailor to them.
const VMG_SECONDS: float = 150.0
const VMG_MEASURED: float = 60.0

func _the_angle_it_beats_at_makes_good_to_windward() -> void:
	var probe: Object = _sailing_world(10.0)
	var sailor: int = int(probe.spawn_ai_vehicle(Sim.Kind.PIRATE, Vector3(-11000.0, 0.0, 6000.0), 0.0, Vector3.ZERO))
	var close: float = float((probe.sailor_report(sailor) as Dictionary).get("close_hauled", 0.0))
	probe.teardown()
	if not (probe is RefCounted):
		probe.free()
	var made_good: Dictionary = {}
	for angle in [deg_to_rad(50.0), deg_to_rad(60.0), close, deg_to_rad(75.0), deg_to_rad(90.0)]:
		var world: Object = _sailing_world(10.0)
		var nose := Vector3(sin(angle), 0.0, -cos(angle))
		var ship: int = int(world.spawn_ai_vehicle(Sim.Kind.PIRATE, Vector3(-11000.0, 0.0, 6000.0), -angle, nose * 3.0))
		world.hold_course(ship, angle)
		var sum: float = 0.0
		var samples: int = 0
		for i in range(int(VMG_SECONDS * 120.0)):
			world.tick(1.0 / 120.0)
			if i >= int((VMG_SECONDS - VMG_MEASURED) * 120.0) and i % 12 == 0:
				sum -= float(((world.vehicle_state(ship) as Dictionary).get("velocity", Vector3.ZERO) as Vector3).z)
				samples += 1
		made_good[angle] = sum / maxf(float(samples), 1.0)
		world.teardown()
		if not (world is RefCounted):
			world.free()
	var best: float = 0.0
	for angle in made_good:
		best = maxf(best, float(made_good[angle]))
	var lines: Array[String] = []
	for angle in made_good:
		lines.append("%.0f deg %.2f m/s" % [rad_to_deg(float(angle)), float(made_good[angle])])
	_check("the_angle_the_sailor_beats_at_makes_good_most_of_the_best_to_windward",
		close > 0.0 and float(made_good.get(close, 0.0)) >= 0.8 * best and best > 0.0,
		"beats at %.0f deg, making %.2f m/s upwind against the best %.2f: %s" % [rad_to_deg(close),
			float(made_good.get(close, 0.0)), best, ", ".join(lines)])
	_sections += 1


func _sailing_world(wind: float) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.set_weather({"from": 0.0, "low": wind, "high": wind, "veer": 0.0, "seed": 1})
	return world


## FIVE BRIGS SAIL INSIDE THEIR BUDGET: under 50 microseconds a ship a tick and 300 for all five, their forces, their
## helmsmen and their sailors together (`tick_breakdown`: the vehicle job and the rota), with Box3D's own step printed
## beside it. Measured after a settling minute, over one more, on a pool of four points round them in the wandering wind.
const BUDGET_SHIPS: int = 5
const BUDGET_PER_SHIP_USEC: float = 50.0
const BUDGET_ALL_USEC: float = 300.0

func _five_brigs_sail_inside_their_budget() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.set_weather(Terrain.weather())
	var middle := Vector3(-12000.0, 0.0, 0.0)
	for corner in [Vector3(-2000.0, 0.0, -2000.0), Vector3(2000.0, 0.0, -2000.0), Vector3(2000.0, 0.0, 2000.0), Vector3(-2000.0, 0.0, 2000.0)]:
		world.add_ai_waypoint(Sim.Kind.PIRATE, middle + corner)
	for i in range(BUDGET_SHIPS):
		var at: Vector3 = middle + Vector3(float(i - 2) * 300.0, 0.0, 0.0)
		world.spawn_ai_vehicle(Sim.Kind.PIRATE, at, -PI * 0.5, Vector3(3.0, 0.0, 0.0))
	for i in range(60 * 120):
		world.tick(1.0 / 120.0)
	world.set_tick_breakdown(true)
	for i in range(60 * 120):
		world.tick(1.0 / 120.0)
	var cost: Dictionary = world.tick_breakdown()
	world.set_tick_breakdown(false)
	var spent: float = float(cost.get("vehicles", 0.0)) + float(cost.get("chores", 0.0))
	print("[pirate_ai] five brigs: vehicles %.1f usec, chores %.1f usec, Box3D step %.1f usec a tick, over %d ticks" % [
		float(cost.get("vehicles", 0.0)), float(cost.get("chores", 0.0)), float(cost.get("step", 0.0)), int(cost.get("ticks", 0))])
	_check("five_brigs_sail_inside_their_budget", spent > 0.0 and spent <= BUDGET_ALL_USEC and spent / BUDGET_SHIPS <= BUDGET_PER_SHIP_USEC,
		"%.1f usec a tick for %d brigs, %.1f a ship (budget %.0f and %.0f)" % [spent, BUDGET_SHIPS, spent / BUDGET_SHIPS,
			BUDGET_ALL_USEC, BUDGET_PER_SHIP_USEC])
	world.teardown()
	if not (world is RefCounted):
		world.free()
	_sections += 1


## A BRIG ROLLS BACK UPRIGHT WITH ITS OWN PERIOD, which is what a sea's waves must not drive at (cockpit-ocean's wind waves,
## 2026-09-15). Held on a beam reach in a 12 m/s wind until its heel is steady, then the wind taken away, it rolls back
## through upright and beyond. Expected from the simulation's own construction, as `sail_report` gives it: the probes are
## spread so the roll stiffness is the weight times the metacentric height (`roll_stiffness`), Box3D gives the body its
## inertia about the keel (`roll_inertia`), and T = 2 pi sqrt(I / K). Held within a quarter of that.
##
## THE SWELL IS TAKEN AWAY BY A TWIN. The first version timed the heel's crossings of its own mean and read 12.27 s from 4
## crossings against 4.6 s: once the free roll had died the crossings were the standing swell's, whose two waves are about
## 11 and 10 s long, and the 4.6 s it was held to was typed in, not asked of the simulation. So a second world sails
## the same seconds in still air, and at the moment of release a twin is put in it where the heeled brig is, going as it
## goes: both then ride the same swell, and the heel one has more than the other is the free roll. Only crossings while
## that difference is still a twentieth of where it started are counted, so the last of it settling does not add crossings
## (at a tenth the free roll gave 3, the fewest the check takes).
const ROLL_HEEL_SECONDS: float = 90.0
const ROLL_FREE_SECONDS: float = 60.0

func _a_brig_rolls_back_upright_with_its_own_period() -> void:
	var world: Object = _sailing_world(12.0)
	var still: Object = _sailing_world(0.0)
	var angle: float = deg_to_rad(90.0)
	var nose := Vector3(sin(angle), 0.0, -cos(angle))
	var ship: int = int(world.spawn_ai_vehicle(Sim.Kind.PIRATE, Vector3(-11000.0, 0.0, 6000.0), -angle, nose * 3.0))
	world.hold_course(ship, angle)
	for i in range(int(ROLL_HEEL_SECONDS * 120.0)):
		world.tick(1.0 / 120.0)
		still.tick(1.0 / 120.0)
	var heeled_report: Dictionary = world.sail_report(ship)
	var heeled: float = float(heeled_report.get("heel", 0.0))
	var state: Dictionary = world.vehicle_state(ship)
	world.set_weather({"from": 0.0, "low": 0.0, "high": 0.0, "veer": 0.0, "seed": 1})
	var twin: int = int(still.spawn_ai_vehicle(Sim.Kind.PIRATE, state.get("position", Vector3.ZERO), -angle,
		state.get("velocity", Vector3.ZERO)))
	still.hold_course(twin, angle)
	var differences: PackedFloat32Array = []
	for i in range(int(ROLL_FREE_SECONDS * 120.0)):
		world.tick(1.0 / 120.0)
		still.tick(1.0 / 120.0)
		differences.append(float((world.sail_report(ship) as Dictionary).get("heel", 0.0))
			- float((still.sail_report(twin) as Dictionary).get("heel", 0.0)))
	var last_big: int = 0
	for i in range(differences.size()):
		if absf(differences[i]) > absf(differences[0]) * 0.05:
			last_big = i
	var crossings: Array[float] = []
	for i in range(1, last_big + 1):
		if differences[i - 1] * differences[i] < 0.0:
			crossings.append(float(i) / 120.0)
	var period: float = 0.0
	if crossings.size() >= 3:
		period = 2.0 * (crossings[crossings.size() - 1] - crossings[0]) / float(crossings.size() - 1)
	var inertia: float = float(heeled_report.get("roll_inertia", 0.0))
	var stiffness: float = float(heeled_report.get("roll_stiffness", 0.0))
	var expected: float = TAU * sqrt(inertia / stiffness) if stiffness > 0.0 and inertia > 0.0 else 0.0
	print("[pirate_ai] roll: heeled %.1f deg in 12 m/s on a beam reach; free of the swell, %d crossings in %.1f s; I %.0f kg m^2, K %.0f N m/rad" % [
		rad_to_deg(heeled), crossings.size(), float(last_big) / 120.0, inertia, stiffness])
	_check("a_brig_rolls_back_upright_with_the_period_its_stiffness_and_inertia_give",
		expected > 0.0 and crossings.size() >= 3 and absf(period - expected) <= expected * 0.25,
		"period %.2f s from %d crossings, expected %.2f s; heeled %.1f deg first" % [period, crossings.size(), expected,
			rad_to_deg(heeled)])
	world.teardown()
	still.teardown()
	if not (world is RefCounted):
		world.free()
	if not (still is RefCounted):
		still.free()
	_sections += 1

## THE LEVEL GIVES BOTH ITS WORLDS THE WEATHER. A wind is a function of the frame and the seed, so every world told the
## same weather sails the same wind with nothing sent -- and a world that was not told is in still air. Asked of the
## server's world and the client's after the level boots, field by field, against `Terrain.weather()`; and the wind blowing
## there is inside its own limits, so what was handed over is a wind and not a zero.
func _the_level_gives_both_worlds_the_weather() -> void:
	var level := (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(180):
		await get_tree().physics_frame
	var wanted: Dictionary = Terrain.weather()
	var worlds: Dictionary = {"server": Sim.server, "client": Sim.client}
	for name in worlds:
		var world: Object = worlds[name]
		if world == null:
			_check("the_%s_world_is_there" % name, false, "no %s world after 180 frames" % name)
			continue
		var told: Dictionary = world.weather()
		var apart: Array[String] = []
		for field in ["low", "high", "veer", "seed"]:
			if absf(float(told.get(field, -1.0)) - float(wanted[field])) > 0.0001:
				apart.append("%s %s against %s" % [field, told.get(field), wanted[field]])
		if absf(float(told.get("from_base", -1.0)) - float(wanted["from"])) > 0.0001:
			apart.append("from %s against %s" % [told.get("from_base"), wanted["from"]])
		_check("the_%s_world_sails_the_levels_weather" % name, apart.is_empty(), "%s" % [apart if not apart.is_empty() else told])
		var speed: float = float(told.get("speed", 0.0))
		_check("and_the_wind_in_the_%s_world_is_blowing_inside_its_limits" % name,
			speed >= float(wanted["low"]) - 0.001 and speed <= float(wanted["high"]) + 0.001,
			"%.2f m/s, limits %.1f to %.1f" % [speed, float(wanted["low"]), float(wanted["high"])])
	level.queue_free()
	await get_tree().process_frame
	Sim.stop()
	_sections += 1
