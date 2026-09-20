extends Node
## Headless: the world's soft edge turns every craft back inside the wire, the same on a predicting client as on the
## server, and the last resort at the wire's edge never has to act on a craft the turn-back has hold of.
##
##   Godot --headless --path cockpit res://tests/world_edge.tscn [-- --kind=p51 --probe]
##
## Asked for on 2026-09-15: "the world edge gets a SOFT boundary: warn, then turn the craft back", server-authoritative,
## identical on predicting clients, AI and traffic included. Before it, a joined pilot flying +X past 32,768 m was held at
## about 32.8 km by its own client while the server flew it on: 1,032 m apart after 10 s, 18 to 24 rollbacks a second,
## about 190 wire clamps a second (agents.md, "At the world's horizontal edge").
##
## EACH POWERED WING IS FLOWN OUT BY ITS OWN PILOT on a client, in one process with its server over a same-tick link, as
## tests/far_out.gd flies one. The pilot flies straight out as a person would: full throttle, holding 1,500 m and its wings
## level. A pilot with the stick let go was the first version, and a heavy wing sank for 150 s through the empty world's
## floor and past the wire's, which made clamps that were nothing to do with the edge (2026-09-15). What is read, per kind:
## - how far past the band's start it went on the server, held to team-lead's rule: inside the band's start, its depth
##   and the widest turn (`WorldEdge.band_for`), and never at the last resort;
## - that it ended heading home;
## - that the wire clamped nothing and the last resort never fired, on either world;
## - that the client drew its own craft on the server's path, and rolled back, no worse than THE SAME PILOT FLYING THE SAME
##   BANK FOR AS LONG FAR INSIDE: a turn draws a predicted craft off the server's path by its lead, and a straight line
##   does not, so the measure is a turn against a turn, never a typed number.
##
## AND AN AUTOPILOT, flown out by nothing but itself, turns back too; A BRIG put past the band's start with its waypoints
## beyond it turns back without the last resort; AND A CRAFT NOBODY FLIES, drifting at the wire, is stopped by the last
## resort, which is the one place it should act.
##
## Read RESULT=, not the exit code.

const TICK_HZ: float = 60.0
const DT: float = 1.0 / TICK_HZ
const POD: int = 0
const PLANE: int = 1
## Where the test band starts: well inside the wire, with room for the widest turn twice over and the last resort.
const START: float = 18000.0
## How long a kind is given to be turned back and heading home, seconds.
const FLIGHT_SECONDS: float = 150.0
## The height the pilot holds, metres.
const HOLD_HEIGHT: float = 1500.0
## The steepest nose angle the pilot will ask for, radians, and how hard it closes on it (see `_pilot`).
const NOSE_MOST: float = 0.15
const NOSE_GAIN: float = 3.0
## How much worse than the same turn far inside a flight out may draw and roll back: half again, and a margin for a
## number small enough to be counting noise.
const WORSE_BY: float = 1.5
const PATH_MARGIN_M: float = 2.0
const ROLLBACK_MARGIN: int = 5
## AND THE BUDGET A FLIGHT OUT MAY ROLL BACK AT WHATEVER THE TURN INSIDE COST, rollbacks a second. The turn-back's
## controls are worked out FROM THE POSITION, and the client's predicted position is not the server's to the metre, so
## the two blend slightly differently and the client rolls back -- a cost a steady bank far inside does not have at all.
## The ratio alone was passing on a noisy baseline: when the pilot here learned to fly an attitude (see `_pilot`) the
## inside turns went quiet -- 27 rollbacks over 150 s for the light aeroplane where the flights out still cost 126 -- and
## six kinds went red for a cost that had not moved. Measured 2026-09-19, the worst flight out of any kind is 139 over
## 150 s, 0.93 a second. ONE a second is the budget, and the bug this suite exists for was EIGHTEEN TO TWENTY-FOUR a
## second (see the file's head), so a check that passes here still catches that by a factor of twenty.
const ROLLBACKS_A_SECOND_MOST: float = 1.0

var _failures: PackedStringArray = []
## `--probe`: where the craft is and what its attitude is, every second of a flight. READ ONCE, because
## `OS.get_cmdline_user_args()` builds an array every call and this is asked inside a loop that runs 9,000 times a
## flight and 36 flights a run: asking it per tick took the suite from 34 s to over 180 and timed it out (lane/warbirds2,
## 2026-09-19).
var _probe: bool = OS.get_cmdline_user_args().has("--probe")


func _check(label: String, ok: bool, detail: String) -> void:
	print("[world_edge] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var has: bool = ClassDB.class_exists("CockpitWorld") and ClassDB.class_exists("GroundField")
	_check("the_extension_is_loaded", has, "CockpitWorld")
	var probe: Object = _world(0) if has else null
	var ready: bool = probe != null and probe.has_method("set_boundary") and probe.has_method("worst_turn_radius")
	_check("the_simulation_has_a_boundary", ready, "set_boundary, worst_turn_radius")
	if not ready:
		_finish()
		return
	var radii: Array = probe.turn_radii()
	var worst: float = float(probe.worst_turn_radius())
	var guard_from: float = float((probe.boundary() as Dictionary)["guard_from"])
	_let_go(probe)
	_the_band_is_worked_out(radii, worst, guard_from)
	var band: Dictionary = WorldEdge.band_for(START - WorldEdge.CLEAR_OF_PLACES, worst, guard_from, _fastest(radii))
	_check("the_test_band_fits", String(band["error"]) == "", "%s" % [band])
	var only: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--kind="):
			only = argument.trim_prefix("--kind=")
	for row in radii:
		if only.is_empty() or only == Sim.kind_name(int((row as Dictionary)["kind"])):
			_a_pilot_flying_out_is_turned_back_the_same_on_both_worlds(row as Dictionary, band, worst, guard_from)
	_an_autopilot_flying_out_turns_back(band, worst)
	_a_pirate_sailing_out_turns_back_without_the_last_resort(band, guard_from)
	_a_submarine_sailing_out_turns_back_by_its_rudder(band, guard_from)
	_a_craft_nobody_flies_is_stopped_at_the_wire(guard_from)
	_the_pilot_is_warned_before_the_turn(band)
	_finish()


## ---- 1: the band -----------------------------------------------------------------------------------------------------

func _the_band_is_worked_out(radii: Array, worst: float, guard_from: float) -> void:
	var widest: float = 0.0
	for row in radii:
		var r: Dictionary = row
		print("[world_edge] %-9s top %6.1f m/s at %4.1f degrees of bank: a turn %6.0f m across" % [
			Sim.kind_name(int(r["kind"])), float(r["speed"]), rad_to_deg(float(r["bank"])), float(r["radius"])])
		widest = maxf(widest, float(r["radius"]))
	_check("every_powered_wing_says_how_wide_it_turns", not radii.is_empty() and is_equal_approx(widest, worst),
		"%d kinds, widest %.0f m, worst %.0f m" % [radii.size(), widest, worst])
	var too_far: Dictionary = WorldEdge.band_for(guard_from - worst, worst, guard_from, 100.0)
	_check("a_level_placed_too_near_the_wire_is_refused_in_words",
		String(too_far["error"]).begins_with("the world's edge will not fit"), "'%s'" % too_far["error"])


## ---- 2: a pilot, per kind -----------------------------------------------------------------------------------------

func _a_pilot_flying_out_is_turned_back_the_same_on_both_worlds(row: Dictionary, band: Dictionary, worst: float,
		guard_from: float) -> void:
	var kind: int = int(row["kind"])
	var name: String = Sim.kind_name(kind)
	var speed: float = float(row["speed"])
	var bank: float = float(row["bank"])
	# THE SAME PILOT FLYING THE SAME BANK FOR AS LONG, FAR INSIDE: the measure a turn-back is held to.
	var inside: Dictionary = _fly(kind, speed, Vector3(0.0, HOLD_HEIGHT, 0.0), {}, FLIGHT_SECONDS, bank)
	var outside: Dictionary = _fly(kind, speed, Vector3(float(band["start"]) - 1000.0, HOLD_HEIGHT, 0.0), band,
		FLIGHT_SECONDS, 0.0)
	var over: float = float(outside["furthest"]) - float(band["start"])
	var allowed: float = float(band["depth"]) + worst
	print("[world_edge] %-9s past the start by %6.0f m (depth %.0f + widest turn %.0f), home %s, clamps %d/%d, guards %d/%d, off the path %.2f m against %.2f inside, rollbacks %d against %d inside, lowest %.0f m" % [
		name, over, float(band["depth"]), worst, outside["heading_home"], outside["clamps"], inside["clamps"],
		outside["server_guards"], outside["client_guards"], outside["off_path"], inside["off_path"], outside["rolled"],
		inside["rolled"], outside["lowest"]])
	_check("a_%s_flown_out_is_turned_back_inside_the_band_and_a_turn" % name,
		over > 0.0 and over < allowed and float(outside["furthest"]) < guard_from,
		"%.0f m past the start against %.0f m" % [over, allowed])
	# CAME BACK INSIDE, not "heading home at the end": a fast wing flown home levelled crosses the middle and heads out the
	# far side inside 150 s, and the plane and the tiltrotor did (2026-09-15). And not "inside at the end" either: with the
	# wings levelled at sixty degrees off home a craft runs back along the edge, and whether the last tick of 150 s falls
	# in or out is a coin. The E-2D's 2,624 m turn made the band 26 m deeper, and the plane ended 32 m past the start and
	# the Hawkeye 1,858 m past it, each having been back inside; at 300 s the airliner, gunship and tanker ended out
	# instead (cockpit-fleet). So: back inside the band's start at some tick after its furthest point out.
	_check("and_comes_back_inside_the_band_%s" % name, float(outside["back_to"]) < float(band["start"]),
		"back to %.0f m out after its furthest, against the band's start at %.0f m; ends %.0f m out, heading home %s" % [
			outside["back_to"], band["start"], outside["ends_out"], outside["heading_home"]])
	_check("and_the_pilot_held_it_in_the_air_%s" % name, float(outside["lowest"]) > 0.0 and float(inside["lowest"]) > 0.0,
		"lowest %.0f m out, %.0f m inside" % [outside["lowest"], inside["lowest"]])
	_check("and_the_wire_clamped_nothing_%s" % name, int(outside["clamps"]) == 0 and int(inside["clamps"]) == 0,
		"%d out, %d inside" % [outside["clamps"], inside["clamps"]])
	_check("and_the_last_resort_never_fired_%s" % name,
		int(outside["server_guards"]) == 0 and int(outside["client_guards"]) == 0,
		"server %d, client %d" % [outside["server_guards"], outside["client_guards"]])
	_check("and_the_client_drew_its_own_%s_on_the_servers_path_as_well_as_in_a_turn_far_inside" % name,
		float(outside["off_path"]) <= maxf(float(inside["off_path"]) * WORSE_BY, float(inside["off_path"]) + PATH_MARGIN_M),
		"%.2f m against %.2f m inside" % [outside["off_path"], inside["off_path"]])
	var rollback_budget: int = int(ROLLBACKS_A_SECOND_MOST * FLIGHT_SECONDS)
	_check("and_rolled_back_no_more_than_in_a_turn_far_inside_%s" % name,
		int(outside["rolled"]) <= maxi(int(ceil(float(inside["rolled"]) * WORSE_BY)) + ROLLBACK_MARGIN,
			rollback_budget),
		"%d against %d inside over %.0f s, and a budget of %d" % [outside["rolled"], inside["rolled"], FLIGHT_SECONDS,
			rollback_budget])


## ONE FLIGHT: a server and a client over a same-tick link, both told the band, the client's own `kind` flown from `at`
## straight at +X at `speed` on full throttle for `seconds`, its pilot holding `HOLD_HEIGHT` and the bank `hold_bank`
## (0 for wings level).
func _fly(kind: int, speed: float, at: Vector3, band: Dictionary, seconds: float, hold_bank: float) -> Dictionary:
	var server: Object = _world(0)
	var client: Object = _world(1)
	for world in [server, client]:
		if not band.is_empty():
			world.set_boundary(float(band["start"]), float(band["depth"]))
	for i in range(90):
		_step_pair(server, client)
	var mine: int = int(client.local_client_id())
	var clamps_before: int = int(server.wire_clamps())
	server.spawn_pilot(mine, kind, at, -PI * 0.5, Vector3(speed, 0.0, 0.0))
	var craft: int = -1
	var own: int = -1
	var furthest: float = 0.0
	## The nearest the craft came to the middle AFTER its furthest point out.
	var back_to: float = INF
	var lowest: float = INF
	var worst_off: float = 0.0
	var path: Array[Vector3] = []
	var before: int = -1
	# THE KIND'S FULL-STICK PITCH RATE, ASKED ONCE A FLIGHT AND OF THIS FLIGHT'S OWN SERVER. `handling()` builds a whole
	# dictionary across the extension boundary and the pilot below runs every tick, so asking it per tick was half of
	# what timed this suite out; and `Sim.server` is the GAME's world, which this suite never starts -- it makes its own
	# pair with `_world()`, and asking the global one gives "Nonexistent function 'handling' in base 'Nil'".
	var full_rate: float = maxf(float(server.handling(kind).get("pitch_rate", 1.2)), 0.1)
	var ticks: int = int(seconds * TICK_HZ)
	for i in range(120 + ticks):
		if own < 0:
			var mine_drawn: Array = client.vehicle_states()
			own = int(mine_drawn[0]["entity"]) if mine_drawn.size() == 1 else -1
		client.set_input(_pilot(client, own, hold_bank, full_rate))
		_step_pair(server, client)
		if i < 120:
			continue
		if before < 0:
			before = int(client.resim_stats().get("count", 0))
		if craft < 0:
			var all: Array = server.vehicle_states()
			craft = int(all[0]["entity"]) if all.size() == 1 else -1
		var there: Vector3 = server.vehicle_state(craft).get("position", Vector3.ZERO)
		path.append(there)
		if WorldEdge.out(there) >= furthest:
			furthest = WorldEdge.out(there)
			back_to = furthest
		back_to = minf(back_to, WorldEdge.out(there))
		lowest = minf(lowest, there.y)
		if _probe and i % 60 == 0:
			var st: Dictionary = server.vehicle_state(craft)
			var bs := Basis(st["basis"] as Quaternion)
			print("[world_edge]   probe t %.1f out %.0f y %.0f v %.0f bank %.1f pitch %.1f" % [
				float(i - 120) / TICK_HZ, WorldEdge.out(there), there.y, (st["velocity"] as Vector3).length(),
				rad_to_deg(-asin(clampf(bs.x.y, -1.0, 1.0))), rad_to_deg(asin(clampf(-bs.z.y, -1.0, 1.0)))])
		var drawn: Array = client.vehicle_states()
		if drawn.size() == 1 and i > 240 and i % 30 == 0:
			worst_off = maxf(worst_off, _distance_to_path(drawn[0]["position"], path))
	var velocity: Vector3 = server.vehicle_state(craft).get("velocity", Vector3.ZERO)
	var last: Vector3 = path.back() if not path.is_empty() else Vector3.ZERO
	var out: Dictionary = {
		"furthest": furthest,
		"ends_out": WorldEdge.out(last),
		"back_to": back_to,
		"lowest": lowest,
		"heading_home": Vector2(velocity.x, velocity.z).dot(Vector2(-last.x, -last.z)) > 0.0,
		"clamps": int(server.wire_clamps()) - clamps_before,
		"server_guards": int(server.edge_guards()),
		"client_guards": int(client.edge_guards()),
		"off_path": worst_off,
		"rolled": int(client.resim_stats().get("count", 0)) - maxi(before, 0),
	}
	_let_go(server)
	_let_go(client)
	return out


## THE PILOT: full throttle, the stick held on `HOLD_HEIGHT` and on the bank asked for, from what this client draws of its
## own craft -- the picture a person flies by. A pitch loop on height and climb rate, a roll loop on bank.
##
## THE PITCH LOOP FLIES AN ATTITUDE, which is how a person flies, and that is not tidiness. Its first version read only
## the height and the climb rate and put the answer straight on the stick, and a stick on a surface kind asks the control
## law for a pitch RATE -- so the loop was always one integration behind the nose. Every aeroplane before the P-51D was
## slow enough and steady enough to survive it. The P-51D is flown out at its own 163 m/s and its tailplane is trimmed at
## its published 134 (`build_the_wing`), so it noses up the moment it is let go: the old loop chased the climb rate,
## overshot to 85 degrees nose up, lost 120 m/s in eleven seconds and mushed into the ground at its stall, every time
## (lane/warbirds2, 2026-09-19). An inner attitude loop cannot run away: the height and the climb rate ask for a NOSE
## ANGLE, capped, and the rate that closes it is divided by the kind's own full-stick rate.
func _pilot(client: Object, own: int, hold_bank: float, full_rate: float = 1.2) -> Dictionary:
	if own < 0:
		return _controls({"throttle": 1.0})
	var state: Dictionary = client.vehicle_state(own)
	var at: Vector3 = state.get("position", Vector3(0.0, HOLD_HEIGHT, 0.0))
	var velocity: Vector3 = state.get("velocity", Vector3.ZERO)
	var attitude: Variant = state.get("basis", Quaternion.IDENTITY)
	var right: Vector3 = (Basis(attitude as Quaternion) if attitude is Quaternion else attitude as Basis).x
	var bank: float = -asin(clampf(right.y, -1.0, 1.0))
	var forward: Vector3 = -(Basis(attitude as Quaternion) if attitude is Quaternion else attitude as Basis).z
	var nose: float = asin(clampf(forward.y, -1.0, 1.0))
	# THE ATTITUDE THE HEIGHT WANTS, radians, and then the rate that gets the nose there.
	var wanted_nose: float = clampf((HOLD_HEIGHT - at.y) * 0.0005 - velocity.y * 0.02, -NOSE_MOST, NOSE_MOST)
	var pitch: float = clampf((wanted_nose - nose) * NOSE_GAIN / full_rate, -1.0, 1.0)
	var roll: float = clampf((hold_bank - bank) * 2.0, -1.0, 1.0)
	return _controls({"throttle": 1.0, "pitch": pitch, "roll": roll})


## ---- 3: an autopilot -------------------------------------------------------------------------------------------------

func _an_autopilot_flying_out_turns_back(band: Dictionary, worst: float) -> void:
	var world: Object = _world(0)
	world.set_boundary(float(band["start"]), float(band["depth"]))
	world.add_ai_waypoint(PLANE, Vector3(float(band["start"]) + 6000.0, HOLD_HEIGHT, 0.0))
	world.add_ai_waypoint(PLANE, Vector3(float(band["start"]) + 7000.0, HOLD_HEIGHT, 3000.0))
	var craft: int = int(world.spawn_ai_vehicle(PLANE, Vector3(float(band["start"]) - 500.0, HOLD_HEIGHT, 0.0), -PI * 0.5,
		Vector3(70.0, 0.0, 0.0)))
	var furthest: float = 0.0
	for i in range(int(FLIGHT_SECONDS * TICK_HZ)):
		world.tick(DT)
		furthest = maxf(furthest, WorldEdge.out(world.vehicle_state(craft).get("position", Vector3.ZERO)))
	var over: float = furthest - float(band["start"])
	_check("an_autopilot_sent_past_the_edge_is_turned_back_too",
		over > 0.0 and over < float(band["depth"]) + worst and int(world.edge_guards()) == 0,
		"%.0f m past the start, %d guards" % [over, world.edge_guards()])
	_let_go(world)


## ---- 3b: a pirate --------------------------------------------------------------------------------------------------

## A SAILING SHIP PUT PAST THE EDGE TURNS BACK TOO, and needs the last resort no more than a wing does (team-lead,
## 2026-09-15: "AI ships (Kind.PIRATE, Model.SAIL) sail too and must respect it"). A brig points no closer than fifty
## degrees to the wind (cockpit-pirate), so a turn-back that held its rudder straight at the middle could put it in
## irons with the middle upwind and let it drift out. It starts past the band's start, heading out, with its own
## waypoints beyond the band so its autopilot keeps asking to go out; the first version started it short of the band, and
## a slow brig that never reached it passed for nothing (2026-09-15).
##
## ON A WIND, and the hardest one first. A world told no weather has still air (tests/sailing.gd), and the first version
## of this section sailed a brig on none: it coasted 218 m from its 6 m/s and stopped, and passed for nothing
## (2026-09-15). So each brig sails a steady 8 m/s: FROM THE WEST, which puts the middle dead upwind of a brig past the +X
## edge, and FROM THE NORTH, across its way home.
func _a_pirate_sailing_out_turns_back_without_the_last_resort(band: Dictionary, guard_from: float) -> void:
	for wind in [{"name": "the_middle_dead_upwind", "from": PI * 1.5}, {"name": "a_wind_across_the_way_home", "from": 0.0}]:
		_a_pirate_on_a_wind(band, guard_from, String(wind["name"]), float(wind["from"]))


func _a_pirate_on_a_wind(band: Dictionary, guard_from: float, name: String, from_bearing: float) -> void:
	var world: Object = _world(0)
	world.set_weather({"from": from_bearing, "low": 8.0, "high": 8.0, "veer": 0.0, "seed": 1})
	world.set_boundary(float(band["start"]), float(band["depth"]))
	var start: float = float(band["start"])
	var past: float = start + float(band["depth"]) + 4000.0
	world.add_ai_waypoint(Sim.Kind.PIRATE, Vector3(past, 0.0, 0.0))
	world.add_ai_waypoint(Sim.Kind.PIRATE, Vector3(past, 0.0, 3000.0))
	var at: Vector3 = Vector3(start + 300.0, 0.0, 0.0)
	# A COMPASS HEADING OF EAST, nose along +X: `spawn_vehicle`'s yaw is minus the heading (tests/sailing.gd, `_ship`).
	var ship: int = int(world.spawn_ai_vehicle(Sim.Kind.PIRATE, at, -PI * 0.5, Vector3(6.0, 0.0, 0.0)))
	var furthest: float = 0.0
	var sailed: float = 0.0
	var was: Vector3 = at
	var now: Vector3 = at
	for i in range(int(FLIGHT_SECONDS * 2.0 * TICK_HZ)):
		world.tick(DT)
		now = world.vehicle_state(ship).get("position", now)
		sailed += Vector2(now.x - was.x, now.z - was.z).length()
		was = now
		furthest = maxf(furthest, WorldEdge.out(now))
	var way: float = float((world.sail_report(ship) as Dictionary).get("way", -1.0)) if ship != 0 else -1.0
	var over: float = furthest - start
	var ends: float = WorldEdge.out(now) - start
	print("[world_edge] pirate, %s: sailed %.0f m, furthest %.0f m past the start, ends %.0f m past it with %.1f m/s of way, guards %d" % [
		name, sailed, over, ends, way, world.edge_guards()])
	_check("a_pirate_with_%s_makes_way" % name, ship != 0 and sailed > 200.0, "sailed %.0f m" % sailed)
	_check("and_is_turned_back_before_the_last_resort_with_%s" % name,
		over > 0.0 and furthest < guard_from and int(world.edge_guards()) == 0,
		"%.0f m past the start, %d guards" % [over, world.edge_guards()])
	_check("and_ends_further_in_than_it_got_with_%s" % name, ends < over - 100.0,
		"ends %.0f m past the start, got %.0f m past it" % [ends, over])
	_let_go(world)


## A SUBMARINE SAILED OUT AT ITS HULL SPEED PUTS ITS RUDDER OVER, as every boat does (`turn_back_from_the_edge`), and comes
## back before the last resort. Ships do not size the band, so nothing else showed that a 115 m hull on a 47.4 m rudder arm
## turns inside it (cockpit-fleet, 2026-09-15). Its autopilot is sent to waypoints past the edge, so only the edge turns it,
## and the two settle where the turn-back's weight, which grows with depth into the band, outweighs the autopilot: HELD
## INSIDE THE BAND is the claim, not "ends further in", which a boat still steering for a waypoint outside never does (the
## first run held it 761 m past the start for the whole 300 s, a brig on a wind drifts home).
func _a_submarine_sailing_out_turns_back_by_its_rudder(band: Dictionary, guard_from: float) -> void:
	var world: Object = _world(0)
	world.set_boundary(float(band["start"]), float(band["depth"]))
	var start: float = float(band["start"])
	var past: float = start + float(band["depth"]) + 4000.0
	world.add_ai_waypoint(Sim.Kind.SUBMARINE, Vector3(past, 0.0, 0.0))
	world.add_ai_waypoint(Sim.Kind.SUBMARINE, Vector3(past, 0.0, 3000.0))
	var at: Vector3 = Vector3(start - 1000.0, 0.0, 0.0)
	var boat: int = int(world.spawn_ai_vehicle(Sim.Kind.SUBMARINE, at, -PI * 0.5, Vector3(8.0, 0.0, 0.0)))
	var furthest: float = 0.0
	var now: Vector3 = at
	for i in range(int(FLIGHT_SECONDS * 2.0 * TICK_HZ)):
		world.tick(DT)
		now = world.vehicle_state(boat).get("position", now)
		furthest = maxf(furthest, WorldEdge.out(now))
	var over: float = furthest - start
	var ends: float = WorldEdge.out(now) - start
	print("[world_edge] submarine: furthest %.0f m past the start, ends %.0f m past it, guards %d" % [over, ends,
		world.edge_guards()])
	_check("a_submarine_sailed_out_is_held_inside_the_band_by_its_rudder",
		boat != 0 and over > 0.0 and furthest < start + float(band["depth"]) and int(world.edge_guards()) == 0,
		"%.0f m past the start of a %.0f m band, ends %.0f m past it, %d guards" % [over, band["depth"], ends,
			world.edge_guards()])
	_let_go(world)


## ---- 4: nobody flying ----------------------------------------------------------------------------------------------

func _a_craft_nobody_flies_is_stopped_at_the_wire(guard_from: float) -> void:
	var world: Object = _world(0)
	var edge: float = float((world.wire_range() as Dictionary)["ground_max"])
	var clamps_before: int = int(world.wire_clamps())
	var craft: int = int(world.spawn_vehicle(POD, Vector3(guard_from - 100.0, 400.0, 0.0), 0.0, Vector3(60.0, 0.0, 0.0)))
	var furthest: float = 0.0
	for i in range(int(20.0 * TICK_HZ)):
		world.tick(DT)
		furthest = maxf(furthest, WorldEdge.out(world.vehicle_state(craft).get("position", Vector3.ZERO)))
	_check("a_craft_nobody_flies_is_stopped_before_the_wire_and_the_last_resort_says_so",
		furthest < edge and int(world.edge_guards()) > 0 and int(world.wire_clamps()) == clamps_before,
		"furthest %.1f m against the edge %.0f m, %d guards, %d clamps" % [furthest, edge, world.edge_guards(),
			int(world.wire_clamps()) - clamps_before])
	_let_go(world)


## ---- 5: the words ------------------------------------------------------------------------------------------------------

func _the_pilot_is_warned_before_the_turn(band: Dictionary) -> void:
	var start: float = float(band["start"])
	var warn_from: float = float(band["warn_from"])
	_check("nothing_is_said_well_inside", WorldEdge.warning(Vector3(warn_from - 10.0, 0.0, 0.0), band) == "", "")
	_check("a_pilot_nearing_the_edge_is_told_how_far",
		WorldEdge.warning(Vector3(0.0, 0.0, -(start - 1500.0)), band).begins_with("WORLD EDGE IN 1.5 KM")
			or warn_from > start - 1500.0,
		"'%s'" % WorldEdge.warning(Vector3(0.0, 0.0, -(start - 1500.0)), band))
	_check("and_past_the_start_that_they_are_being_turned_back",
		WorldEdge.warning(Vector3(start + 10.0, 0.0, 0.0), band) == "WORLD EDGE · TURNING YOU BACK", "")


## ---- the machinery -------------------------------------------------------------------------------------------------

## A PILOT'S INPUT FRAME with nothing held but what is asked: tests/far_out.gd's.
func _controls(overrides: Dictionary = {}) -> Dictionary:
	var input: Dictionary = {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0,
	}
	for key in overrides:
		input[key] = overrides[key]
	return input


## HOW FAR A DRAWN POINT IS FROM THE SERVER'S PATH, over the last `LOOK_BACK` ticks of it: a predicted craft is drawn a
## lead ahead of the server's latest, never seconds behind, and the whole path of a 150 s flight is 9,000 segments.
const LOOK_BACK: int = 240


func _distance_to_path(point: Vector3, path: Array[Vector3]) -> float:
	var best: float = INF
	for i in range(maxi(path.size() - LOOK_BACK, 0), path.size() - 1):
		var from: Vector3 = path[i]
		var along: Vector3 = path[i + 1] - from
		var length_squared: float = along.length_squared()
		var t: float = 0.0 if length_squared <= 0.0 else clampf((point - from).dot(along) / length_squared, 0.0, 1.0)
		best = minf(best, point.distance_to(from + along * t))
	if path.size() == 1:
		best = point.distance_to(path[0])
	return best


func _fastest(radii: Array) -> float:
	var most: float = 0.0
	for row in radii:
		most = maxf(most, float((row as Dictionary)["speed"]))
	return most


func _world(client_id: int) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(TICK_HZ)
	world.start(client_id)
	return world


func _let_go(world: Object) -> void:
	world.teardown()
	if not (world is RefCounted):
		world.free()


func _step_pair(server: Object, client: Object) -> void:
	server.tick(DT)
	client.tick(DT)
	for packet in server.take_outbound():
		client.deliver(0, packet["bytes"], packet["bits"])
	for packet in client.take_outbound():
		server.deliver(1, packet["bytes"], packet["bits"])


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
