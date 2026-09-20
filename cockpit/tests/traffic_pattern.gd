extends Node
## AIRPORT LIFE, HEADLESS: the traffic pattern's geometry against the FAA's numbers worked out by hand here, then (as
## the lane builds them) real autopilots flying it through the real mixers and physics.
##
##   Godot --headless --fixed-fps 120 --xr-mode off --path cockpit res://tests/traffic_pattern.tscn
##
## THE DATUM IS THE RESEARCH, NOT THE CODE: every number a check compares against is typed from
## `research/traffic_pattern.md` or worked out in this file from the kind's stall, cruise and bank, never asked of
## `TrafficPattern` itself -- asking it what it does would agree with any mistake in it.
##
## Read RESULT=, not the exit code.

## A runway laid by hand: 900 m, its middle at the origin, landed on northward (toward -Z) from its southern end.
const LENGTH: float = 900.0
## A Cessna-like aeroplane, typed: the stall and cruise the library gave on 2026-09-19, its autopilot's 0.9 rad bank
## limit, and a tonne. The pattern is sized from these alone.
const STALL: float = 38.0
const CRUISE: float = 55.1
const MASS: float = 1100.0
## 1,000 ft and 1,500 ft ([AIM] 4-3-3 a), 300 ft ([AFH] 9), half a mile ([AFH] 8).
const FEET: float = 0.3048
const TOLERANCE: float = 0.5

var _failed := false
var _said: Array[String] = []
## `-- --set=... --kind=...`: see `TuningCard`. Empty, and nothing is retuned. lane/cessnafm flew the Cessna's circuits
## on its lifting surfaces with `--set=surfaces=1 --kind=cessna` before switching them on.
var _card: TuningCard = TuningCard.from_command_line()
var _sections := 0
var _sections_done := 0


func _ready() -> void:
	_geometry()
	_airfields()
	if not Sim.is_available():
		_check("the_extension_is_there", false, "no CockpitWorld")
		_finish()
		return
	await _start()
	if not _card.is_empty():
		print("[traffic_pattern] %s" % _card.clip_on())
	# FLAT GROUND, THEIR OWN, and the runway laid on it by hand at the origin: a check pinned to the island's mountains is a
	# check the next reshape of them breaks.
	Sim.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(7200.0, 400.0, 7200.0))
	_traffic = AirportTraffic.new()
	_traffic.recording = true
	# AND THE TRAFFIC IS TOLD SO: the level's ground is the island's, and this world's is the slab.
	_traffic.highest_ground = func(_at: Vector3, _room: float) -> float: return 0.0
	add_child(_traffic)
	await _abeam_arrival()
	await _straight_in()
	await _two_at_once()
	await _out_and_away()
	await _large_aeroplane_on_instruments()
	await _hawkeye_straight_in()
	_finish()


## ---- 3. AN ARRIVAL JOINING DOWNWIND ---------------------------------------------------------------------------------

var _traffic: AirportTraffic = null


## A HAND-LAID AIRFIELD at the origin, landed on northward from its southern threshold, on the side asked.
func _field(side: String) -> Dictionary:
	return {"id": "test_%s" % side, "frame": Terrain.runway_frame(Vector3.ZERO, 0.0, LENGTH, 45.0),
		"ends": {"threshold": {"pattern": side}, "far_end": {"pattern": side}}, "in_use": "threshold"}


## A CESSNA put into the air at `at`, level, flying along `going` at its cruise, with its autopilot on.
func _cessna(at: Vector3, going: Vector3) -> int:
	var dir: Vector3 = going.normalized()
	var yaw: float = atan2(-dir.x, -dir.z)
	return Sim.spawn_ai_vehicle(Sim.Kind.CESSNA, at, yaw, dir * CRUISE)


## FLY until `done` answers true or `seconds` of simulation pass. Returns the seconds flown.
func _fly(done: Callable, seconds: float) -> float:
	var ticks: int = int(seconds * 120.0)
	for i in range(ticks):
		await get_tree().physics_frame
		if done.call():
			return float(i) / 120.0
	return seconds


func _abeam_arrival() -> void:
	_sections += 1
	var field: Dictionary = _field("left")
	# ON THE DOWNWIND LINE, 2 km before abeam mid-field, at pattern height, flying the downwind's way (south): the
	# pattern it will fly is sized as the traffic sizes it, so the aeroplane is put on it after it is made.
	var entity: int = _cessna(Vector3(0.0, 400.0, 0.0), Vector3.BACK)
	_traffic.arrive(entity, field, Sim.Kind.CESSNA, "", &"downwind")
	var me: Dictionary = _traffic.record_of(entity)
	var p: TrafficPattern = me["pattern"]
	Sim.server.despawn_vehicle(entity)
	_traffic.pilots.erase(entity)
	entity = _cessna(p.point(LENGTH * 0.5 + 2000.0, p.offset) + Vector3.UP * p.height, -p.along)
	_traffic.arrive(entity, field, Sim.Kind.CESSNA, "", &"downwind")
	me = _traffic.record_of(entity)
	p = me["pattern"]
	var flown: float = await _fly(func() -> bool: return me["phase"] == &"stopped" or int(me["go_arounds"]) > 0, 360.0)
	var track: Array = me["track"]
	# DOWNWIND AT PATTERN HEIGHT, from mid-field to abeam the threshold ([AIM] FIG 4-3-3 key 2), and on the LEFT: west of
	# a northward runway, the offset out.
	var worst_height := 0.0
	var worst_out := 0.0
	var level_samples := 0
	for look in track:
		if look["phase"] == &"downwind" and p.ahead_of(look["at"]) >= 0.0 and p.ahead_of(look["at"]) <= LENGTH * 0.5:
			level_samples += 1
			worst_height = maxf(worst_height, absf((look["at"] as Vector3).y - 304.8))
			worst_out = maxf(worst_out, absf((look["at"] as Vector3).x - (-p.offset)))
	_check("an_abeam_arrival_holds_pattern_height_on_downwind_to_15_m", level_samples > 20 and worst_height <= 15.0,
		"%d looks, worst %.1f m off 304.8" % [level_samples, worst_height])
	_check("its_downwind_is_on_the_left_the_offset_out_to_150_m", level_samples > 20 and worst_out <= 150.0,
		"worst %.0f m off x = %.0f" % [worst_out, -p.offset])
	var legs: Array = me["legs"]
	var order_ok: bool = legs.find(&"downwind") >= 0 and legs.find(&"base") > legs.find(&"downwind") \
		and legs.find(&"final") > legs.find(&"base")
	_check("it_turns_base_then_final", order_ok, "legs %s" % str(legs))
	_judge_final(me, p, "the_arrival", flown)
	_traffic.release(entity)
	Sim.server.despawn_vehicle(entity)
	_sections_done += 1


## `--dump-tracks=<folder>` after `--`: every flight's looks written there as text, one line a look, for working out why a
## check failed. Nothing is written without it.
func _dump(me: Dictionary, p: TrafficPattern, who: String) -> void:
	var folder: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--dump-tracks="):
			folder = argument.trim_prefix("--dump-tracks=")
	if folder == "":
		return
	var file := FileAccess.open(folder.path_join("%s.txt" % who), FileAccess.WRITE)
	if file == null:
		return
	file.store_line("tick phase ahead out y asked speed climb bank_deg heading_deg turn")
	for look in me["track"]:
		var at: Vector3 = look["at"]
		var v: Vector3 = look["v"]
		file.store_line("%d %s %.0f %.0f %.1f %.1f %.1f %.2f %.1f %.3f %.3f" % [int(look["tick"]), look["phase"],
			p.ahead_of(at), p.out_of(at), at.y, float(look.get("asked", -1.0)), v.length(), v.y,
			rad_to_deg(float(look.get("bank", 0.0))), rad_to_deg(atan2(v.x, -v.z)), float(look.get("turn", -1.0))])


## A STABILISED FINAL ([AFH] 9): a 3-degree path, on the centreline, at the final speed, by the 300 ft gate.
func _judge_final(me: Dictionary, p: TrafficPattern, who: String, flown: float) -> void:
	_dump(me, p, who)
	var gates: Array = me["gates"]
	_check("%s_reaches_the_300_ft_gate" % who, not gates.is_empty(), "after %.0f s, legs %s" % [flown, str(me["legs"])])
	if gates.is_empty():
		return
	# THE PATH ANGLE BELOW THE GATE, from the gate to the low pass: height lost over ground covered.
	var gate: Dictionary = gates[-1]
	var gate_at: Vector3 = gate["at"]
	var low: Dictionary = gate.get("low", {})
	var low_at: Vector3 = low.get("at", gate_at)
	var run: float = p.ahead_of(low_at) - p.ahead_of(gate_at)
	var angle: float = rad_to_deg(atan2(gate_at.y - low_at.y, run)) if run > 1.0 else -1.0
	_check("%s_is_on_a_3_degree_final_to_1_degree" % who, absf(angle - 3.0) <= 1.0,
		"%.2f degrees from the gate down to %.0f m, over %.0f m" % [angle, low_at.y, run])
	_judge_landing(me, p, who, gate)
	var off_line: float = absf(p.out_of(gate_at))
	var speed: float = (gate["v"] as Vector3).length()
	# +10/-5 kt of the landing speed ([AFH] 9), 5.1 and 2.6 m/s.
	_check("%s_is_stabilised_at_the_gate" % who,
		off_line <= 30.0 and speed <= p.final_speed + 5.1 and speed >= p.final_speed - 2.6,
		"%.1f m off the centreline, %.1f m/s against %.1f" % [off_line, speed, p.final_speed])


## THE LANDING: it touched down, softly, between the threshold and mid-field, on the runway; the crash rule counts it
## as a landing (combat's `hull_state`, nothing destroyed); and it came to a stop on the runway.
##
## THE SINK LIMIT is 10 ft/s, 3.05 m/s: the limit descent velocity light aeroplanes are designed to land at (14 CFR
## 23.473(d), before the 2017 rewrite). The crash rule destroys at 8.5 m/s.
const TOUCH_SINK_MOST: float = 3.05


func _judge_landing(me: Dictionary, p: TrafficPattern, who: String, gate: Dictionary) -> void:
	if gate.has("went_around"):
		_check("%s_lands" % who, false, "went around at the gate: %s" % gate["went_around"])
		return
	var landed: Dictionary = me.get("landed", {})
	var touch_at: Vector3 = landed.get("touch_at", Vector3.INF)
	var sink: float = float(landed.get("touch_sink", INF))
	var into: float = p.ahead_of(touch_at) if touch_at != Vector3.INF else -INF
	_check("%s_touches_down_softly_in_the_first_half_of_the_runway" % who,
		bool(landed.get("touched", false)) and sink <= TOUCH_SINK_MOST and into >= 0.0 and into <= p.length * 0.5,
		"touched %s at %.0f m in, %.2f m/s down, %.1f m/s along" % [landed.get("touched", false), into, sink,
			float(landed.get("touch_speed", 0.0))])
	var entity: int = int(me.get("entity", 0))
	var hull: Dictionary = Sim.server.hull_state(entity) if entity != 0 else {}
	var state: Dictionary = Sim.server.vehicle_state(entity) if entity != 0 else {}
	var stopped_at: Vector3 = state.get("position", Vector3.INF)
	# AND IT TAXIS CLEAR, off the side away from the pattern, beyond the runway's edge and a wing, before the far end
	# and the taxi's own run past it.
	_check("%s_is_a_landing_not_a_crash_and_taxis_clear_of_the_runway" % who,
		not hull.is_empty() and not bool(hull.get("destroyed", true)) and me["phase"] == &"stopped"
		and p.out_of(stopped_at) <= -AirportTraffic.RUNWAY_CLEAR
		and p.ahead_of(stopped_at) <= p.length + AirportTraffic.TAXI_OFF,
		"destroyed %s, phase %s, stopped %.0f m in and %.1f m out (the pattern is +)" % [hull.get("destroyed", "?"),
			me["phase"], p.ahead_of(stopped_at), p.out_of(stopped_at)])


## ---- 4. ALREADY ON FINAL FROM A LONG WAY OUT ---------------------------------------------------------------------------

func _straight_in() -> void:
	_sections += 1
	var field: Dictionary = _field("left")
	var p: TrafficPattern = Airfield.pattern_for(field, Sim.Kind.CESSNA)
	# 9 km out on the extended centreline, at pattern height, flying north toward the runway. Nothing it is judged on
	# depends on the turn: the height and the line are the final's.
	var entity: int = _cessna(p.point(-9000.0, 60.0) + Vector3.UP * p.height, p.along)
	_traffic.arrive(entity, field, Sim.Kind.CESSNA)
	var me: Dictionary = _traffic.record_of(entity)
	var flown: float = await _fly(func() -> bool: return me["phase"] == &"stopped" or int(me["go_arounds"]) > 0, 360.0)
	var legs: Array = me["legs"]
	_check("a_lined_up_arrival_flies_straight_in_with_no_pattern",
		me["entry"] == &"straight_in" and not legs.has(&"downwind") and not legs.has(&"base"),
		"entry %s, legs %s" % [me["entry"], str(legs)])
	_judge_final(me, p, "the_straight_in", flown)
	_traffic.release(entity)
	Sim.server.despawn_vehicle(entity)
	_sections_done += 1


## ---- 5. TWO AT ONCE ------------------------------------------------------------------------------------------------

## THE CLOSEST TWO AEROPLANES IN ONE CIRCUIT MAY COME IN THE AIR, metres: a quarter of a nautical mile. No rule
## publishes a VFR pattern separation; this is a number neither aeroplane's own turns could close by accident (the
## Cessna's flown radius is 580 m), and cutting in beside one on the downwind comes well inside it.
const SEPARATION_LEAST: float = 463.0


func _two_at_once() -> void:
	_sections += 1
	var field: Dictionary = _field("left")
	# A: ON THE DOWNWIND, 1.5 km short of mid-field. B: ON THE 45, timed to reach the join at the same moment -- the
	# entrant that would cut in beside an aeroplane established on the downwind ([AFH] 8).
	var probe: int = _cessna(Vector3(0.0, 400.0, 0.0), Vector3.BACK)
	_traffic.arrive(probe, field, Sim.Kind.CESSNA, "", &"downwind")
	var p: TrafficPattern = _traffic.record_of(probe)["pattern"]
	_traffic.pilots.erase(probe)
	Sim.server.despawn_vehicle(probe)
	var a: int = _cessna(p.point(LENGTH * 0.5 + 1500.0, p.offset) + Vector3.UP * p.height, -p.along)
	_traffic.arrive(a, field, Sim.Kind.CESSNA, "", &"downwind")
	var line: Vector3 = (p.abeam_midfield() - p.entry_start()).normalized()
	var b: int = _cessna(p.abeam_midfield() - line * 1500.0 + Vector3.UP * p.height, line)
	_traffic.arrive(b, field, Sim.Kind.CESSNA, "", &"entry")
	var one: Dictionary = _traffic.record_of(a)
	var two: Dictionary = _traffic.record_of(b)
	var closest: Array = [INF, ""]
	var both_down := func() -> bool:
		var sa: Dictionary = Sim.server.vehicle_state(a)
		var sb: Dictionary = Sim.server.vehicle_state(b)
		var airborne: Array[StringName] = [&"rollout", &"clearing", &"stopped"]
		if not sa.is_empty() and not sb.is_empty() and not airborne.has(one["phase"]) and not airborne.has(two["phase"]):
			var apart: float = ((sa["position"] as Vector3) - (sb["position"] as Vector3)).length()
			if apart < float(closest[0]):
				closest[0] = apart
				closest[1] = "%s / %s" % [one["phase"], two["phase"]]
		return one["phase"] == &"stopped" and two["phase"] == &"stopped"
	var flown: float = await _fly(both_down, 600.0)
	_dump(one, p, "two_first")
	_dump(two, p, "two_second")
	# AND THEY HOLD APART ON THE GROUND: two that touch at the same point once taxied to the same spot.
	var held_apart: float = ((Sim.server.vehicle_state(a).get("position", Vector3.ZERO) as Vector3)
		- (Sim.server.vehicle_state(b).get("position", Vector3.INF) as Vector3)).length()
	_check("two_arrivals_at_once_both_land_and_taxi_clear_apart",
		one["phase"] == &"stopped" and two["phase"] == &"stopped" and held_apart >= AirportTraffic.SPOT_APART * 0.8,
		"after %.0f s: first %s, second %s, %.0f m apart on the ground (legs %s)" % [flown, one["phase"], two["phase"],
			held_apart, str(two["legs"])])
	_check("neither_touches_down_on_a_runway_the_other_is_on",
		String(one.get("shared_runway", "?")) == "" and String(two.get("shared_runway", "?")) == "",
		"first: %s; second: %s" % [str(one.get("shared_runway", "never touched")),
			str(two.get("shared_runway", "never touched"))])
	_check("they_never_come_within_a_quarter_mile_in_the_air", float(closest[0]) >= SEPARATION_LEAST,
		"closest %.0f m, as %s" % [float(closest[0]), closest[1]])
	# THE SECOND GAVE WAY: turned away on the 45, extended its downwind, or went around -- and never touched down while
	# the first was still on the runway.
	var yielded: bool = int(two["turned_away"]) > 0 or float(two["extended"]) > 0.0 or int(two["go_arounds"]) > 0
	var first_clear_tick: int = int((one["began"] as Dictionary).get(&"stopped", -1))
	var second_touch_tick: int = int((two["began"] as Dictionary).get(&"rollout", -1))
	_check("the_second_gives_way_and_lands_only_once_the_runway_is_clear",
		yielded and first_clear_tick > 0 and second_touch_tick > first_clear_tick,
		"turned away %d, extended %.0f m, go-arounds %d; first clear at tick %d, second touched by tick %d" % [
			int(two["turned_away"]), float(two["extended"]), int(two["go_arounds"]), first_clear_tick,
			second_touch_tick])
	for entity in [a, b]:
		_traffic.release(entity)
		Sim.server.despawn_vehicle(entity)
	_sections_done += 1


## ---- 6. OUT: TAXI, TAKE OFF, DEPART, AND ON ITS OWN ----------------------------------------------------------------

## The working template base, laid round the hand-made runway: its taxiways, its apron and its hold bars.
const TEMPLATE_BASE: String = "res://world/airbases/_template"
## How far off the taxi route's centreline a taxiing aeroplane may stray, metres: half a taxiway (UFC 3-260-01's 22.9 m
## wide), which keeps its wheels on the pavement.
const TAXI_STRAY: float = 11.4


func _out_and_away() -> void:
	_sections += 1
	var frame: Dictionary = Terrain.runway_frame(Vector3.ZERO, 0.0, LENGTH, 45.0)
	var base: Dictionary = AirbasePlan.lay(AirbasePlan.read_base(TEMPLATE_BASE), frame)
	var field: Dictionary = _field("left")
	field["base"] = base
	var spot: Dictionary = {}
	for id in base.get("spots", {}):
		if String(id).begins_with("apron") and AirbasePlan.fits(base["spots"][id], Sim.Kind.CESSNA):
			spot = base["spots"][id]
			break
	_check("the_template_base_has_an_apron_spot_a_cessna_fits", not spot.is_empty(),
		"spots %s" % str((base.get("spots", {}) as Dictionary).keys()))
	if spot.is_empty():
		_sections_done += 1
		return
	# SOMEWHERE TO WANDER TO, a long way off, once it is on its own.
	for at in [Vector3(-6000.0, 500.0, -6000.0), Vector3(6000.0, 500.0, -6000.0)]:
		Sim.server.add_ai_waypoint(Sim.Kind.CESSNA, at)
	var extents: Vector3 = Sim.geometry_of(Sim.Kind.CESSNA).get("extents", Vector3.ONE)
	var parked_at: Vector3 = AirbasePlan.standing_on_spot(base, spot, Sim.Kind.CESSNA) + Vector3.UP * (extents.y + 0.3)
	var entity: int = Sim.spawn_ai_vehicle(Sim.Kind.CESSNA, parked_at, float(spot["yaw"]), Vector3.ZERO)
	_traffic.depart(entity, field, Sim.Kind.CESSNA, String(spot["id"]))
	var me: Dictionary = _traffic.record_of(entity)
	var p: TrafficPattern = me["pattern"]
	var route: PackedVector3Array = me["route"]
	# IN A DICTIONARY, because a lambda captures a local by value: kept in two floats, this watch reported 0.0 m and
	# 0.0 m/s on a taxi that had happened, and passed.
	var seen := {"fastest": 0.0, "stray": 0.0}
	var watch := func() -> bool:
		var state: Dictionary = Sim.server.vehicle_state(entity)
		if not _traffic.pilots.has(entity) or state.is_empty():
			return true
		if me["phase"] == &"taxi":
			seen["fastest"] = maxf(float(seen["fastest"]), (state["velocity"] as Vector3).length())
			var off: float = _off_route(route, state["position"])
			if off > float(seen["stray"]):
				seen["stray"] = off
				seen["where"] = "at route point %d of %d, %.1f m/s" % [int(me["route_next"]), route.size(),
					(state["velocity"] as Vector3).length()]
		return false
	var flown: float = await _fly(watch, 420.0)
	var fastest_taxi: float = seen["fastest"]
	var worst_stray: float = seen["stray"]
	_dump(me, p, "out_and_away")
	var legs: Array = me["legs"]
	_check("it_taxis_its_route_on_the_pavement_at_taxi_speed",
		route.size() >= 2 and worst_stray <= TAXI_STRAY and fastest_taxi <= AirportTraffic.TAXI_SPEED + 1.0,
		"%d route points, worst %.1f m off it (%s), fastest %.1f m/s" % [route.size(), worst_stray,
			str(seen.get("where", "")), fastest_taxi])
	var order: Array[StringName] = [&"taxi", &"hold_short", &"line_up", &"take_off", &"departure", &"departing"]
	var in_order := true
	for k in range(order.size() - 1):
		if legs.find(order[k]) < 0 or legs.find(order[k + 1]) < legs.find(order[k]):
			in_order = false
	_check("it_holds_short_lines_up_takes_off_and_departs_in_that_order", in_order, "legs %s" % str(legs))
	var lift: Vector3 = me.get("lift_off", Vector3.INF)
	_check("it_lifts_off_within_the_runway", lift != Vector3.INF and p.ahead_of(lift) >= 0.0
		and p.ahead_of(lift) <= p.length and absf(p.out_of(lift)) <= 22.5,
		"lift-off %.0f m past the threshold, %.1f m off the centreline" % [p.ahead_of(lift) if lift != Vector3.INF else -1.0,
			p.out_of(lift) if lift != Vector3.INF else -1.0])
	# STRAIGHT AHEAD UNTIL PAST THE DEPARTURE END AND NEAR PATTERN HEIGHT ([AC] 11.6, [AIM] 4-3-2): no departing turn
	# before half a mile beyond the far end and within 300 ft of pattern height, and on the centreline until then.
	var turned_at: Vector3 = Vector3.INF
	var worst_wide := 0.0
	for look in me["track"]:
		if look["phase"] == &"departure":
			worst_wide = maxf(worst_wide, absf(p.out_of(look["at"])))
		if look["phase"] == &"departing" and turned_at == Vector3.INF:
			turned_at = look["at"]
	_check("it_climbs_straight_out_to_half_a_mile_past_the_end_and_pattern_height_before_turning",
		turned_at != Vector3.INF and p.ahead_of(turned_at) >= p.length + 926.0
		and turned_at.y >= p.field + p.height - 91.44 and worst_wide <= 60.0,
		"turned %.0f m past the threshold at %.0f m; worst %.0f m off the centreline before" % [
			p.ahead_of(turned_at) if turned_at != Vector3.INF else -1.0, turned_at.y if turned_at != Vector3.INF else -1.0,
			worst_wide])
	# AND THEN ON ITS OWN: let go by the traffic, and -- given a few seconds to choose one -- flying a leg of the ordinary
	# random-waypoint wander.
	await _fly(func() -> bool: return false, 5.0)
	var going: Dictionary = Sim.server.ai_destination(entity)
	_check("it_is_handed_back_to_the_random_waypoint_wander",
		not _traffic.pilots.has(entity) and not going.is_empty() and bool(going.get("has_route", false)),
		"after %.0f s: flying airport life %s, destination %s" % [flown, _traffic.pilots.has(entity), str(going)])
	Sim.server.despawn_vehicle(entity)
	_sections_done += 1


## ---- 7. A LARGE AEROPLANE FLIES AN INSTRUMENT APPROACH --------------------------------------------------------------

## The bank limit ([IFH]'s standard rate or less, the lead's 25 degrees), with what a rate loop overshoots by on the
## way into a turn; the flown turn no tighter than this share of the radius the vectors were laid out on; and on the
## glideslope, never above it by more than this.
const IFR_BANK_MOST: float = 25.0
const BANK_OVERSHOOT: float = 2.0
const RADIUS_SHARE: float = 0.8
const ABOVE_GLIDESLOPE: float = 15.0
## A standard rate measured over a second of 0.1 s looks, with the look's own jitter.
const STANDARD_RATE_SLACK: float = 1.1


func _large_aeroplane_on_instruments() -> void:
	_sections += 1
	# THE CATEGORY, FROM THE SHAPE TABLE: the airliner (the 737/747 remodels' kind) over 12,500 lb, the Cessna under.
	var airliner: Dictionary = Airfield.numbers_of(Sim.Kind.AIRLINER)
	var cessna: Dictionary = Airfield.numbers_of(Sim.Kind.CESSNA)
	_check("large_aeroplanes_fly_instruments_and_light_ones_the_pattern",
		InstrumentApproach.flies_it(airliner) and not InstrumentApproach.flies_it(cessna),
		"airliner %.0f kg, Cessna %.0f kg, the line at %.0f" % [float(airliner["mass"]), float(cessna["mass"]),
			TrafficPattern.LARGE_MASS])
	var field: Dictionary = _field("left")
	# ABEAM THE RUNWAY ON ITS RIGHT, 5 km out, flying the wrong way (south, away from the landing direction) at 600 m:
	# the aeroplane that needs vectoring, not one lined up already.
	var h: Dictionary = Sim.handling_of(Sim.Kind.AIRLINER)
	var speed: float = float(h["cruise"])
	var at := Vector3(5000.0, 600.0, 0.0)
	var entity: int = Sim.spawn_ai_vehicle(Sim.Kind.AIRLINER, at, PI, Vector3(0.0, 0.0, speed))
	_traffic.arrive(entity, field, Sim.Kind.AIRLINER)
	var me: Dictionary = _traffic.record_of(entity)
	var flown: float = await _fly(func() -> bool: return me["phase"] == &"stopped" or int(me["go_arounds"]) > 0 \
		or bool(Sim.server.hull_state(entity).get("destroyed", false)), 1800.0)
	var p: TrafficPattern = me["pattern"]
	_dump(me, p, "instrument")
	var ifr: InstrumentApproach = me.get("ifr")
	var legs: Array = me["legs"]
	_check("the_large_aeroplane_is_vectored_to_a_final_not_flown_round_the_pattern",
		ifr != null and legs.has(&"vectors") and legs.has(&"final") and not legs.has(&"downwind") \
			and not legs.has(&"base") and bool(me["past_gate"]),
		"after %.0f s, legs %s" % [flown, str(legs)])
	if ifr == null:
		_sections_done += 1
		Sim.server.despawn_vehicle(entity)
		return
	# THE TURNS: never banked past the limit; never faster than a standard rate ([IFH], 3 degrees a second), over any
	# second; and in a STEADY turn -- level, the bank held at the approach's own through the whole second -- never tighter than
	# the radius the vectors were laid out on. A turn's rate is not steady while the aeroplane levels off from a descent
	# in it: the first airliner turned at 2.3 degrees a second for a second, 1,772 m, as its pull-up added lift, against a
	# steady 1.23 (3,350 m) either side.
	var worst_bank := 0.0
	var fastest_rate := 0.0
	var tightest := INF
	var track: Array = me["track"]
	for i in range(track.size()):
		var look: Dictionary = track[i]
		if not (look["phase"] in [&"vectors", &"final", &"straight_in"]):
			continue
		worst_bank = maxf(worst_bank, absf(rad_to_deg(float(look["bank"]))))
		if i >= 10:
			var before: Dictionary = track[i - 10]
			var v0: Vector3 = before["v"]
			var v1: Vector3 = look["v"]
			var turned: float = absf(wrapf(atan2(v1.x, -v1.z) - atan2(v0.x, -v0.z), -PI, PI))
			var seconds: float = float(int(look["tick"]) - int(before["tick"])) / 120.0
			if seconds <= 0.0:
				continue
			fastest_rate = maxf(fastest_rate, turned / seconds)
			var steady := true
			for k in range(i - 10, i + 1):
				if absf(absf(float(track[k]["bank"])) - ifr.bank) > deg_to_rad(1.0) 						or absf((track[k]["v"] as Vector3).y) > 0.5:
					steady = false
			# THE VECTORS ARE WHAT WAS LAID OUT ON THE RADIUS: on the final, its flaps out as a speed brake add lift, and the
			# same bank turns it tighter onto the course (2,603 m against 2,966 on the vectors, 2026-09-19).
			if steady and turned > deg_to_rad(1.0) and look["phase"] == &"vectors":
				tightest = minf(tightest, Vector2(v1.x, v1.z).length() / (turned / seconds))
	_check("its_bank_never_passes_25_degrees", worst_bank <= IFR_BANK_MOST + BANK_OVERSHOOT,
		"worst %.1f degrees; the approach asks for %.1f" % [worst_bank, rad_to_deg(ifr.bank)])
	_check("it_never_turns_faster_than_standard_rate", rad_to_deg(fastest_rate) <= 3.0 * STANDARD_RATE_SLACK,
		"fastest %.2f degrees a second" % rad_to_deg(fastest_rate))
	_check("no_steady_turn_is_tighter_than_the_radius_it_was_planned_for",
		tightest != INF and tightest >= ifr.radius * RADIUS_SHARE,
		"tightest steady turn %.0f m against %.0f m planned" % [tightest, ifr.radius])
	# ESTABLISHED FAR OUT: on the centreline within 50 m and its heading within 5 degrees, no nearer than the FAF
	# (5 NM); and from there on the glideslope's height or below it, met from below.
	var established := Vector3.INF
	var worst_above := -INF
	for look in track:
		var here: Vector3 = look["at"]
		var going: Vector3 = look["v"]
		if established == Vector3.INF and look["phase"] in [&"final", &"straight_in"] and absf(p.out_of(here)) <= 50.0 \
				and Vector2(going.x, going.z).normalized().dot(Vector2(p.along.x, p.along.z)) >= cos(deg_to_rad(5.0)):
			established = here
		if established != Vector3.INF and not bool(look.get("past_gate", false)):
			worst_above = maxf(worst_above, here.y - ifr.final_height(here))
	_check("it_is_established_on_the_final_course_outside_the_final_approach_fix",
		established != Vector3.INF and -p.ahead_of(established) >= InstrumentApproach.FAF_OUT,
		"established %.1f NM out" % (-p.ahead_of(established) / 1852.0 if established != Vector3.INF else -1.0))
	_check("it_meets_the_glideslope_from_below", worst_above <= ABOVE_GLIDESLOPE,
		"at most %.1f m above the glideslope's height once established" % worst_above)
	var gates: Array = me["gates"]
	_check("the_large_aeroplane_is_stabilised_at_300_ft", not gates.is_empty() \
		and not (gates[-1] as Dictionary).has("went_around"),
		"gate %s" % (str(gates[-1]) if not gates.is_empty() else "never reached"))
	_judge_a_large_landing(me, p, entity, "the_airliner")
	_traffic.release(entity)
	Sim.server.despawn_vehicle(entity)
	_sections_done += 1


## A LARGE AEROPLANE'S LANDING: its gear down when it touched, on a runway nobody else was on; it STAYS down -- the
## roll-out's back stick lifted an airliner 80 m off the runway again at 64 m/s -- and it stops and taxis clear, not
## destroyed.
const STAYS_DOWN: float = 5.0


func _judge_a_large_landing(me: Dictionary, p: TrafficPattern, entity: int, who: String) -> void:
	var landed: Dictionary = me.get("landed", {})
	var touch_tick: int = int((me["began"] as Dictionary).get(&"rollout", -1))
	var highest_after := -INF
	for look in me["track"]:
		if touch_tick >= 0 and int(look["tick"]) > touch_tick:
			highest_after = maxf(highest_after, (look["at"] as Vector3).y - p.field)
	var hull: Dictionary = Sim.server.hull_state(entity)
	_check("%s_lands_gear_down_stays_down_and_stops" % who,
		touch_tick >= 0 and bool(me.get("gear_at_touch", false)) and highest_after <= STAYS_DOWN
		and me["phase"] == &"stopped" and not bool(hull.get("destroyed", true)),
		"touched %s with the gear %s at %.1f m/s down, %.1f along; highest after %.1f m; phase %s, destroyed %s" % [
			touch_tick >= 0, "down" if bool(me.get("gear_at_touch", false)) else "UP",
			float(landed.get("touch_sink", -1.0)), float(landed.get("touch_speed", -1.0)), highest_after, me["phase"],
			hull.get("destroyed", "?")])
	_check("%s_touches_down_on_a_runway_nobody_else_is_on" % who, touch_tick >= 0
		and String(me.get("shared_runway", "?")) == "", "shared: %s" % str(me.get("shared_runway", "never touched")))


## ---- 8. A HAWKEYE: A SLIPPERY ONE, STRAIGHT IN ------------------------------------------------------------------

func _hawkeye_straight_in() -> void:
	_sections += 1
	var field: Dictionary = _field("left")
	var p: TrafficPattern = Airfield.pattern_for(field, Sim.Kind.HAWKEYE)
	# 11 NM out on the extended centreline, at 600 m, flying in at its cruise: without its flaps and gear out it reached
	# the gate at 76 m/s against 65 and went around (2026-09-19).
	var speed: float = float(Sim.handling_of(Sim.Kind.HAWKEYE)["cruise"])
	var at: Vector3 = p.point(-20300.0, 0.0) + Vector3.UP * 600.0
	var entity: int = Sim.spawn_ai_vehicle(Sim.Kind.HAWKEYE, at, atan2(-p.along.x, -p.along.z), p.along * speed)
	_traffic.arrive(entity, field, Sim.Kind.HAWKEYE)
	var me: Dictionary = _traffic.record_of(entity)
	var flown: float = await _fly(func() -> bool: return me["phase"] == &"stopped" or int(me["go_arounds"]) > 0 \
		or bool(Sim.server.hull_state(entity).get("destroyed", false)), 900.0)
	p = me["pattern"]
	_dump(me, p, "hawkeye")
	var gates: Array = me["gates"]
	var gate: Dictionary = gates[-1] if not gates.is_empty() else {}
	var ifr: InstrumentApproach = me.get("ifr")
	_check("the_hawkeye_flies_it_straight_in_and_is_stabilised_at_300_ft",
		ifr != null and me["entry"] == &"instrument" and not gate.is_empty() and not gate.has("went_around"),
		"after %.0f s, legs %s, gate %s" % [flown, str(me["legs"]), str(gate)])
	_judge_a_large_landing(me, p, entity, "the_hawkeye")
	_traffic.release(entity)
	Sim.server.despawn_vehicle(entity)
	_sections_done += 1


## How far `at` is from the nearest segment of a route, metres, in plan.
static func _off_route(route: PackedVector3Array, at: Vector3) -> float:
	var best: float = INF
	var flat := Vector2(at.x, at.z)
	for i in range(route.size() - 1):
		var a := Vector2(route[i].x, route[i].z)
		var b := Vector2(route[i + 1].x, route[i + 1].z)
		var t: float = clampf((flat - a).dot(b - a) / maxf((b - a).length_squared(), 1e-6), 0.0, 1.0)
		best = minf(best, flat.distance_to(a + (b - a) * t))
	return best


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


## ---- 2. THE ISLAND'S TWO AIRFIELDS, FROM THEIR FILES ----------------------------------------------------------------

func _airfields() -> void:
	_sections += 1
	var runways: Array[Dictionary] = Terrain.runways()
	var first: Dictionary = Airfield.named("island_strip")
	var shore: Dictionary = Airfield.named("south_shore")
	# THE COUNT IS THE FILES', never typed: "two runways" went red when Cape International's two joined (lane/airport).
	var shore_index: int = int(shore.get("index", -1))
	_check("the_island_has_two_runways_and_the_first_is_still_its_own",
		runways.size() == 1 + Airfield.new_runways("island").size() and runways.size() >= 2
		and (runways[0]["centre"] as Vector3).is_equal_approx(Terrain.RUNWAY_AT)
		and int(first.get("index", -1)) == 0 and shore_index > 0 and shore_index < runways.size()
		and (runways[shore_index]["centre"] as Vector3).is_equal_approx(Vector3(4400.0, 0.0, 6200.0)),
		"%d runways; island_strip on %s, south_shore on %s" % [runways.size(), first.get("index"), shore.get("index")])
	# THE SHORE STRIP'S CIRCUITS ARE OUT OVER THE SEA, whichever end is in use: that is the reason each end has the side
	# it has. Every downwind point from abeam the far end to the base turn lies past the island's edge, where there is
	# no land (`Terrain.land_height` is -INF).
	var dry := PackedStringArray()
	for end in Airfield.ENDS:
		var p: TrafficPattern = Airfield.pattern_for(shore, Sim.Kind.CESSNA, end)
		for step in range(11):
			var ahead: float = lerpf(p.length, TrafficPattern.AIM_IN - p.final_length(), float(step) / 10.0)
			var at: Vector3 = p.point(ahead, p.offset)
			if Terrain.land_height(at) != -INF:
				dry.append("%s at %s" % [end, at])
	_check("the_shore_strips_downwinds_lie_over_the_sea_at_both_ends", dry.is_empty(),
		"%d downwind points over land%s" % [dry.size(), "" if dry.is_empty() else ": " + dry[0]])
	_sections_done += 1


## ---- 1. THE SHAPE, WITHOUT A WORLD ----------------------------------------------------------------------------------

func _geometry() -> void:
	_sections += 1
	var frame: Dictionary = Terrain.runway_frame(Vector3.ZERO, 0.0, LENGTH, 45.0)
	var numbers := {"stall": STALL, "cruise": CRUISE, "bank": 0.9, "mass": MASS}
	var left: TrafficPattern = TrafficPattern.make(frame, false, -1.0, numbers)
	var right: TrafficPattern = TrafficPattern.make(frame, false, 1.0, numbers)
	# Landing north from the south end: the threshold is at z = +450 and the landing direction is -Z.
	_check("it_lands_from_the_threshold_toward_the_far_end",
		left.threshold.distance_to(Vector3(0, 0, 450)) < TOLERANCE and left.along.distance_to(Vector3(0, 0, -1)) < 1e-4,
		"threshold %s along %s" % [left.threshold, left.along])
	# 1,000 ft for a light aeroplane, 1,500 for a heavy one.
	var heavy: TrafficPattern = TrafficPattern.make(frame, false, -1.0, {"stall": STALL, "cruise": CRUISE, "bank": 0.9,
		"mass": 17000.0})
	_check("a_light_aeroplane_flies_it_at_1000_ft_and_a_large_one_at_1500",
		absf(left.height - 1000.0 * FEET) < 0.01 and absf(heavy.height - 1500.0 * FEET) < 0.01,
		"%.1f m and %.1f m" % [left.height, heavy.height])
	# THE DOWNWIND, BY HAND: downwind speed min(cruise, 1.6 stall) = 55.1; radius at 30 degrees 55.1^2 / (9.81 tan 30)
	# = 536 m; 2.5 radii = 1,340 m, which is more than half a mile, so that is the offset. Left of a northward
	# landing is west.
	var speed: float = minf(CRUISE, 1.6 * STALL)
	# Three quarters of a mile at the nearest ([AFH] 8's half to one mile, its middle), or 2.5 radii if that is wider.
	var want_offset: float = maxf(1852.0 * 0.75, 2.5 * speed * speed / (9.81 * tan(deg_to_rad(30.0))))
	var abeam: Vector3 = left.abeam_threshold()
	_check("a_left_hand_downwind_lies_west_of_a_northward_runway_half_a_mile_to_a_mile_out",
		abeam.distance_to(Vector3(-want_offset, 0, 450)) < TOLERANCE and want_offset >= 926.0 and want_offset <= 1852.0,
		"abeam threshold %s, offset %.0f m (%.2f NM)" % [abeam, want_offset, want_offset / 1852.0])
	_check("a_right_hand_downwind_lies_east",
		right.abeam_threshold().distance_to(Vector3(want_offset, 0, 450)) < TOLERANCE,
		"abeam threshold %s" % right.abeam_threshold())
	# THE HEIGHTS, BY HAND. Pattern height abeam the threshold and before it; 300 ft where the final is joined, which
	# is 300 ft / tan 3 = 1,744 m before the aim point 300 m in; 0 at the aim point; and 3 degrees in between.
	var join_out: float = 1000.0 * 0.3048 * 0.3 / tan(deg_to_rad(3.0))   # 300 ft
	var aim := Vector3(0, 0, 450 - 300)
	var join := aim + Vector3(0, 0, join_out)
	var h_abeam: float = left.height_at(&"downwind", abeam)
	var h_midfield: float = left.height_at(&"downwind", left.abeam_midfield())
	var h_join: float = left.height_at(&"final", join)
	var h_half: float = left.height_at(&"final", aim + Vector3(0, 0, 1000))
	var h_aim: float = left.height_at(&"final", aim)
	_check("it_holds_pattern_height_until_abeam_the_threshold",
		absf(h_midfield - 304.8) < TOLERANCE and absf(h_abeam - 304.8) < TOLERANCE,
		"mid-field %.1f, abeam %.1f" % [h_midfield, h_abeam])
	_check("it_joins_final_at_300_ft_on_a_3_degree_path",
		absf(h_join - 91.44) < TOLERANCE and absf(h_half - 1000.0 * tan(deg_to_rad(3.0))) < TOLERANCE
		and absf(h_aim) < TOLERANCE and left.final_join().distance_to(join) < TOLERANCE,
		"join %.1f m at %s, 1 km out %.1f, aim %.2f" % [h_join, left.final_join(), h_half, h_aim])
	# AND IT COMES DOWN THROUGH THE DOWNWIND AND BASE at a rate the handbook calls normal for a light aeroplane: 500 to
	# 1,000 fpm at the downwind speed. The path from abeam the threshold to the join is the rest of the downwind, the
	# base leg and nothing else, measured here along the legs' straight lines.
	# The base leg lies one turn radius and 300 m of straight final beyond the join, so the final turn ends
	# lined up with room before the gate: the path is the downwind to it, the base leg, and that radius and 300 m
	# back in along the final.
	var r: float = speed * speed / (9.81 * tan(deg_to_rad(30.0)))
	var straight: float = 300.0
	var drop_path: float = (join.z + r + straight - 450.0) + want_offset + r + straight
	var sink_fpm: float = (304.8 - 91.44) / drop_path * speed / FEET * 60.0
	var mid_base: Vector3 = Vector3(-want_offset * 0.5, 0, join.z + r + straight)
	var h_mid_base: float = left.height_at(&"base", mid_base)
	var want_mid_base: float = 91.44 + (304.8 - 91.44) * (want_offset * 0.5 + r + straight) / drop_path
	_check("it_descends_through_downwind_and_base_at_500_to_1000_fpm",
		sink_fpm >= 500.0 and sink_fpm <= 1000.0 and absf(h_mid_base - want_mid_base) < 1.0,
		"%.0f fpm over %.0f m; mid-base %.1f m, by hand %.1f" % [sink_fpm, drop_path, h_mid_base, want_mid_base])
	# THE ENTRY BY GEOMETRY. Straight in from 8 km south heading north; the 45 from the west (the pattern side); the
	# teardrop from the east; and 8 km south but heading east is NOT lined up, so it is not a straight-in.
	var lined := left.entry_for(Vector3(200, 300, 8000), Vector3(0, 0, -50))
	var west := left.entry_for(Vector3(-5000, 300, 0), Vector3(50, 0, 0))
	var east := left.entry_for(Vector3(5000, 300, 0), Vector3(-50, 0, 0))
	var crossing := left.entry_for(Vector3(200, 300, 8000), Vector3(50, 0, 0))
	var close_in := left.entry_for(Vector3(0, 300, 2500), Vector3(0, 0, -50))
	_check("the_entry_is_chosen_by_where_it_is_and_where_it_is_going",
		lined == &"straight_in" and west == &"forty_five" and east == &"teardrop" and crossing != &"straight_in"
		and close_in != &"straight_in",
		"lined up %s, west %s, east %s, crossing %s, close in %s" % [lined, west, east, crossing, close_in])
	# THE 45 ENTERS AT 45 DEGREES, AIMED AT MID-FIELD: its line from its start to abeam mid-field makes 45 degrees with
	# the downwind's direction (south, +Z, for a northward landing).
	var entry_line: Vector3 = (left.abeam_midfield() - left.entry_start()).normalized()
	var angle: float = rad_to_deg(entry_line.angle_to(Vector3(0, 0, 1)))
	_check("the_45_degree_entry_meets_downwind_at_45_degrees_abeam_midfield",
		absf(angle - 45.0) < 0.5 and left.abeam_midfield().distance_to(Vector3(-want_offset, 0, 0)) < TOLERANCE
		and entry_line.x > 0.0,
		"%.1f degrees, from %s" % [angle, left.entry_start()])
	# THE OTHER END: landing south from the northern end, still left-hand, puts the downwind EAST.
	var south: TrafficPattern = TrafficPattern.make(frame, true, -1.0, numbers)
	_check("the_other_end_flies_its_own_side",
		south.abeam_threshold().distance_to(Vector3(want_offset, 0, -450)) < TOLERANCE,
		"abeam %s" % south.abeam_threshold())
	_sections_done += 1


## ---- the suite's own bookkeeping -----------------------------------------------------------------------------------

func _finish() -> void:
	_check("every_section_ran_to_its_end", _sections_done == _sections, "%d of %d" % [_sections_done, _sections])
	print("RESULT=%s%s" % ["FAIL " if _failed else "PASS", ", ".join(_said)])
	get_tree().quit(1 if _failed else 0)


func _check(name: String, passed: bool, detail: String) -> void:
	print("[traffic_pattern] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
	if not passed:
		_failed = true
		_said.append(name)
