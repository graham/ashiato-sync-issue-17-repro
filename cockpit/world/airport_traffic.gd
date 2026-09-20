extends Node
class_name AirportTraffic
## AIRPORT LIFE: aeroplanes that fly an airfield's traffic pattern -- the entry, downwind, base and final, a go-around --
## as the FAA describes it (`research/traffic_pattern.md`), steered by the host.
##
## Asked for on 2026-09-19: "research landing patterns for airports ... build a ai mode that can honor this (while
## avoiding other planes). This same mode should be able to taxi and takeoff from an airport and start it's "fly to
## random waypoints" mode."
##
## THE HOST'S TACTICS AND NOTHING ELSE, as the attackers are (lane/combat): every aeroplane here is an ordinary
## autopilot, flown by the same mixers as all the island's traffic -- the levers a player's hands move -- and this only
## says where to go, how high and how fast (`steer_ai`), and how steeply to bank (`set_ai_manners`). Where each leg
## lies and how high each point on it is are `TrafficPattern`'s; which side and which runway end are the airfield file's
## (`Airfield`). Nothing here types a distance a pattern could compute.
##
## ON THE ROTA, NOT EVERY TICK: a pilot looks at where he is about ten times a second, and the mixers hold the last ask
## in between -- the same pace the attackers think at. One chore kind, "pattern", one chore an aeroplane.
##
## HOW A LEG IS FLOWN: a CARROT on the leg's line `CARROT_RADII` turn radii ahead of the aeroplane's foot on it, which
## is pure pursuit: it joins the line on a curve about a turn wide and then tracks it. A turn onto the next leg is begun
## one turn radius before the corner, so the curve ends on the new line rather than past it.
##
## THE HEIGHT IS ASKED FOR WHERE THE AEROPLANE WILL BE `LEAD_S` FROM NOW. The mixer's altitude loop turns a height error
## into a climb rate at 0.45 a second (`AircraftMixer::altitude_outer`), so a target sliding down a glide path at a
## steady sink is chased from behind by sink / 0.45: 3.8 m/s of descent flown 8 m high. Asking for the height one time
## constant ahead cancels that lag.

## WHERE A LOOK'S TIME GOES, for the stress probe and for nothing else: laps round the parts of `_think` that walk other
## aeroplanes or ask the ground, and a count of how many times each ran. Nothing unless a probe has started the stopwatch
## (`world/stopwatch.gd`): off, `start` returns 0 and `lap` given a 0 returns without reading the clock.
const STOPWATCH := preload("res://world/stopwatch.gd")
## Block name -> how many times it ran since `take_tally`. Counted only while the stopwatch runs, so the microseconds a
## block cost can be divided by the number of times it was paid for.
static var _tally: Dictionary = {}

## HOW NEAR THE CLIMB RULE CAME TO FIRING: the LEAST SLACK any look had between the climb it needs to clear the ground
## ahead and the climb its remaining run buys, in metres, and how many looks fired. A rule that never fires may be a
## sky with nothing in the way or a rule that has quietly stopped watching, and only the slack tells the two apart.
## Cutting the rate the ground is asked at is exactly the change that could turn one into the other, so it is measured
## rather than argued about. Counted only while the stopwatch runs.
static var _climb_slack: float = INF
static var _climb_fired: int = 0


static func _count(block: StringName) -> void:
	_tally[block] = int(_tally.get(block, 0)) + 1


## Every block's count since this was last asked, and a clean sheet.
static func take_tally() -> Dictionary:
	var counted: Dictionary = _tally
	_tally = {}
	return counted


## The climb rule's least slack and how often it fired since this was last asked, and a clean sheet. `slack` is INF
## where no look was taken at all, which is not the same as a look that found room.
static func take_climb_watch() -> Dictionary:
	var out: Dictionary = {"slack": _climb_slack, "fired": _climb_fired}
	_climb_slack = INF
	_climb_fired = 0
	return out


## How often each aeroplane is looked at, and how late it may be looked at, in ticks: a tenth of a second at 120 Hz,
## never later than a fifth.
const THINK_TICKS: int = 12
const THINK_LIMIT: int = 24
## The rota's share: twice what the kind asks for, derived as the built-in kinds are (see `ChoreRota`).
const THINK_SHARE: float = 2.0 / float(THINK_TICKS)
## The carrot on a leg, in turn radii ahead of the aeroplane's foot on it.
const CARROT_RADII: float = 1.5
## 100 ft on the final, where a landing's path is sampled for the record, below the 300 ft gate.
const LOW_PASS: float = 30.48
## The stabilised gate's limits ([AFH] 9): lined up within half the runway's width, and +10/-5 kt of the landing speed.
const LINED_UP: float = 22.5
const FAST_BY: float = 5.14
const SLOW_BY: float = 2.57
## Below this a landing has become a taxi, metres a second: the air base's taxi limit (tests/airbase_taxi.gd drives at
## no more than 8.5).
const TAXI_SPEED: float = 8.5

## ---- SEQUENCING ([AIM] 4-3-4, 4-3-5; [AFH] 8 and 9) ----
##
## Every aeroplane landing on one runway end is in one CIRCUIT, ordered by how far it still has to fly to touch down
## along the path it will fly (`_path_left`). The one just nearer is the one it FOLLOWS.
##
## SPACING IS A TIME, `SPACING_S` of the follower's own final speed: what a landing takes to get off the runway -- the
## flare, the roll-out and the taxi clear -- with a margin. A follower on downwind that would be closer than that
## behind its leader by turning base now EXTENDS the downwind instead ("advise a pilot on an extended downwind when to
## turn base leg", [AIM] 4-3-2), and turns when the gap is there. Nobody orbits: a 360 in the pattern is the one thing
## [AIM] 4-3-5 says not to do.
##
## AN ENTRANT YIELDS to traffic already on the downwind ("give way ... to aircraft already established on downwind",
## [AFH] 8): if joining would put it within `SPACING_S` of one there, it turns away along its entry, flies out and comes
## back on the 45 ([AFH] 8: "continue to turn away from the downwind, fly a safe distance away, and return for another
## attempt").
##
## AND THE RUNWAY: at 100 ft ([AFH] 8, "if there is traffic on the runway ... an early go-around may be in order"),
## a follower goes around if the runway is not clear; at the 300 ft gate it goes around if it is closer to its leader
## than `CLOSEST_S` -- overtaking ([AFH] 9). A landed aeroplane taxis off to the side of the runway away from the
## pattern and holds there; the runway is clear once it stands `RUNWAY_CLEAR` from the centreline.
const SPACING_S: float = 45.0
const CLOSEST_S: float = 20.0
## How far off the centreline a landed aeroplane taxis, beyond the runway's edge, and when it is clear of it: the edge
## plus the widest light wing's half (the Cessna's 5.5 m) and a margin.
const TAXI_OFF: float = 60.0
const RUNWAY_CLEAR: float = 40.0
## HOW FAR APART LANDED AEROPLANES HOLD beside the runway, metres: a light wing's span (the Cessna's 11 m) three times over
## and a margin for where a taxi stops. Two that touched at the same point both taxied to the same spot the first time,
## and the second drove into the first (pattern_shot, 2026-09-19).
const SPOT_APART: float = 40.0
## How far out along its entry an entrant that has yielded flies before it comes back, in turn radii.
const TURN_AWAY_RADII: float = 4.0
## ---- DEPARTING ([AIM] 4-3-2, 4-3-3 FIG key 6; [AC] 11.6-11.8) ----
##
## From a parking spot: along the base's taxi route to the hold bar at the threshold in use (`AirbasePlan.route`), at
## `TAXI_SPEED` on the straight and `TAXI_TURNING` within `TAXI_SLOWING` of a bend, and holding short there until the
## runway is clear -- nobody on it, and nobody on final nearer than `DEPARTURE_CLEAR_S`. Then onto the centreline, and
## the autopilot's own take-off down the line to the far end. Straight ahead until beyond the departure end and within
## 300 ft of pattern height, and past `DEPARTURE_PAST`; then the 45-degree departure turn to the pattern's side, and
## after `DEPART_OUT` of that it is handed back to the random-waypoint wander -- or, sent somewhere, flies there.
const TAXI_TURNING: float = 4.0
## How near its mark a craft stops on a stand, metres: nose-in at a gate, as a marshaller would wave it to.
const PARKED_WITHIN: float = 1.0
## The speed asked for onto a stand: this share of the metres still to go each second, and never slower than a creep.
const PARKING_EASE: float = 0.25
const PARKING_CREEP: float = 0.6
## THE TURN OFF THE TAXILANE ONTO A STAND IS CUT AS A CHORD, from this far before the stand's mouth on the taxilane to as
## far along its lead-in, metres: a square corner put the first 747 on its lead-in 12.7 m wide at 17 degrees, and with 80 m
## of lead-in it parked 3.5 m to one side of its line (a shorter carrot oscillated, to 8.5 m).
const STAND_CHORD: float = 30.0
const TAXI_SLOWING: float = 30.0
const TAXI_REACHED: float = 8.0
const TAXI_LOOK: float = 12.0
const TAXI_LOOK_HEAVY: float = 30.0
const DEPARTURE_CLEAR_S: float = 60.0
## Where on the centreline it lines up, metres past the threshold: the length of a light aeroplane, off the piano keys.
const LINE_UP_AT: float = 15.0
## Lined up is the nose within `ALIGNED` of the runway's heading, turned onto it along a carrot `ALIGN_LOOK` ahead; the
## roll tracks a carrot `ROLL_LOOK` ahead on the centreline.
const ALIGNED: float = deg_to_rad(4.0)
const ALIGN_LOOK: float = 30.0
const ROLL_LOOK: float = 150.0
## Two miles of 45-degree departure before it is on its own ([AC] 11.8: "exit with a 45-degree turn").
const DEPART_OUT: float = 3704.0
## EN ROUTE BETWEEN TWO FIELDS: at least `ENROUTE_CLEAR` over the highest ground within `ENROUTE_ROOM` of the straight
## line, sampled every `ENROUTE_STEP`, and never below pattern height -- reached in STAGES as the look-ahead walks the
## leg (`_high_ground_ahead`) rather than worked out over the whole leg at once; within `ARRIVE_WITHIN` of the field it is
## going to, the arrival takes over ("descend to pattern altitude ... well clear of the pattern", [AC] 11.2), with the
## entry chosen from where it is then. 8 km is about the 10 miles [AC] 9.11.2 has pilots announce themselves at, cut to
## an island 14 km across.
const ENROUTE_CLEAR: float = 300.0
## CLIMBING BEFORE THE HIGH GROUND. Out of the circuit it looks `CLIMB_LOOK` along its track -- asked of the ground on
## distance flown and decided every look, see `_high_ground_ahead` -- and if
## the ground there wants more height than a steady `CLIMB_CAN` would gain before it gets there, it CIRCLES where it is,
## climbing, until it has that height, and then goes on. The first trip from the island strip held pattern height
## along its 45-degree departure straight at the southern ring, and the look-ahead's escape climb, 9.7 m/s begun 1.2 km
## short of the ridge, hit it 22 m low at 100 knots (pattern_shot --scene=trip, 2026-09-19). `CLIMB_CAN` is below the
## 3.5-3.8 m/s the Cessna climbed at on that departure, so the rule is never a race it can lose.
const CLIMB_LOOK: float = 3000.0
const CLIMB_CAN: float = 3.0
const CLIMB_EVERY_S: float = 1.0
const ENROUTE_ROOM: float = 600.0
## HOW FAR APART THE CORRIDOR IS SAMPLED along the line, metres: THE WIDTH OF THE BOX each sample asks for, so that
## consecutive boxes TILE the corridor instead of overlapping it, and derived from the room rather than typed beside it.
##
## It was 500 m against a 600 m room, so every box overlapped its neighbour by 700 of its 1,200 m and the corridor was
## sampled 2.4 TIMES OVER. That is not free here: `Terrain.highest_near` on a generated ground asks the level's rock by
## pyramid AND the ground by a grid every `Terrain.SEA_SEARCH_STEP` (16 m), which for this room is 75 by 75 = 5,625
## ground texels and 3.6 ms A BOX. A 3 km look was seven boxes and 25 ms, and 94 per cent of everything the airport
## pilots did (`tests/testfield_stress.gd`, 100 aircraft, 2026-09-19). Four boxes cover the same track.
##
## A box half the step wide covers the line between two centres in the worst case, which is a track along an axis; a
## diagonal track is covered to 1.41 times that, so the union loses a little of the corridor's WIDTH at each join on a
## diagonal. The tall ground is unaffected either way, because a range is caught by the pyramid over the whole box
## whatever the grid does, and there is `ENROUTE_CLEAR` of margin over whatever is found.
const ENROUTE_STEP: float = 2.0 * ENROUTE_ROOM
const ARRIVE_WITHIN: float = 8000.0

## The legs of the circuit proper, in which an aeroplane is sequenced.
const IN_THE_CIRCUIT: Array[StringName] = [&"downwind", &"base", &"final", &"straight_in", &"rollout", &"clearing",
	&"vacating"]
## One time constant of the mixer's altitude loop, 1 / 0.45 s.
const LEAD_S: float = 1.0 / 0.45
## THE TURN GAUGE. Every aeroplane here measures how much of a coordinated turn its bank buys it (`TrafficPattern.turn`)
## whenever it is banked past `GAUGE_BANK`, and keeps a running mean with `GAUGE_WEIGHT` on each new look; the kind
## keeps the last one measured, for the next of its kind to start from. Before anything of a kind has turned, a pattern
## is sized on `turn_expected`, which on the lumped wing is `TURN_UNKNOWN`: the Cessna measured 0.53 in a steady turn (2026-09-19), and a guess below the truth
## makes a first circuit wide rather than tight. Why a bank buys less turn here than in the air: see TrafficPattern.
const GAUGE_BANK: float = deg_to_rad(10.0)
const GAUGE_WEIGHT: float = 0.1
## A turn is steady when its bank changes by less than this, radians a second.
const GAUGE_STEADY: float = deg_to_rad(2.0)
const TURN_UNKNOWN: float = 0.5
## The legs flown before the circuit is joined, while the pattern may still be resized on the gauge.
const BEFORE_THE_CIRCUIT: Array[StringName] = [&"to_entry", &"crossing", &"outbound", &"straight_in"]
## The measured turn of each kind, as last gauged.
static var turn_of_kind: Dictionary = {}

## HOW MUCH OF A COORDINATED TURN A KIND'S BANK WILL BUY BEFORE ANY OF IT HAS BEEN GAUGED: the last one gauged; or 1,
## the book's, for a kind flying on its lifting surfaces, whose autopilot turns at 0.99 of g tan(bank) / v at 20 to 45
## degrees (`tests/cessna_book.gd`); or `TURN_UNKNOWN` for the lumped wing. Sized on 0.5, the surface Cessna's first
## circuit turned final 548 m out for a 212 m turn and reached its gate 145 m off the centreline (lane/cessnafm).
static func turn_expected(kind: int) -> float:
	if turn_of_kind.has(kind):
		return float(turn_of_kind[kind])
	if Sim.server != null and bool(Sim.server.lifting_surfaces(kind).get("switched_on", false)):
		return 1.0
	return TURN_UNKNOWN


## Every aeroplane flying airport life: host entity -> its state. See `_think`.
var pilots: Dictionary = {}
## Keep every look at an aeroplane in its record's `track`, for a test or a picture.
var recording: bool = false
## HOW FINELY THE GROUND IS SAMPLED FOR THE CLIMB LOOK, metres: four of `Terrain.SEA_SEARCH_STEP`, derived from it
## rather than typed beside it so the two move together.
##
## WHY THIS QUESTION TOLERATES A COARSER ANSWER THAN THE SEA SEARCH DOES. The look asks whether a steady climb clears
## the ground ahead with `ENROUTE_CLEAR` -- THREE HUNDRED METRES -- of air over it. At `SEA_SEARCH_STEP` the box is
## 5,625 texels and 3.6 ms; at four times the step it is 352 and 225 microseconds, because the cost is quadratic in the
## step. And the level's RANGES are unaffected either way: `highest_near` answers those from a pyramid over the whole
## box, exact at any spacing, so what a coarser grid can miss is a bump in the relief of FIELDS, narrower than 64 m,
## tall enough to eat 300 m of margin. That is not a thing farmland does.
##
## WHY IT IS NOT COARSER STILL: 128 m would be another fourfold saving and is not needed. At 64 m the whole spike this
## was written for -- TWO climb looks landing on one tick, 2 x 16.6 ms, which is what the rota's budget cannot prevent
## because it counts chores and not microseconds -- costs 2.2 ms and fits the 8.33 ms tick with room to spare. The
## least coarse step that solves the problem is the one to take, and the rest is left in reserve.
const CLIMB_GRID: float = Terrain.SEA_SEARCH_STEP * 4.0

## THE HIGHEST GROUND WITHIN A DISTANCE OF A POINT, `(at: Vector3, room: float) -> float`: the level's, unless a test
## flying over ground of its own says otherwise -- a check pinned to the island's mountains is one the next reshape of
## them breaks.
##
## BOUND WITH `CLIMB_GRID` RATHER THAN PASSED, so this stays a TWO-argument Callable. `Terrain.highest_near` takes an
## optional third argument for the sampling step and `Callable.bind` appends it, which means the three tests that
## replace this with a flat-ground lambda of their own (`airport`, `traffic_pattern`, `warbird_circuit`) keep working
## untouched. Passing the step through the call site instead would have broken all three on arity.
var highest_ground: Callable = Terrain.highest_near.bind(CLIMB_GRID)
var _on_rota: bool = false


## ---- what the level asks for -------------------------------------------------------------------------------------

## LAND `entity` ON `field` (an `Airfield`), from `end` (the one in use unless given): the entry is chosen from where it
## is and where it is going, unless `joining` names the leg it is already on (a test's aeroplane put on downwind, or
## one a tower has told to join). Host only. Returns false if there is no host or no such autopilot.
func arrive(entity: int, field: Dictionary, kind: int, end: String = "", joining: StringName = &"") -> bool:
	if Sim.server == null or field.is_empty():
		return false
	var turn: float = turn_expected(kind)
	var pattern: TrafficPattern = Airfield.pattern_for(field, kind, end, turn)
	var state: Dictionary = Sim.server.vehicle_state(entity)
	if state.is_empty():
		return false
	var entry: StringName = pattern.entry_for(state["position"], state["velocity"])
	var phase: StringName = &"straight_in" if entry == &"straight_in" \
		else (&"to_entry" if entry == &"forty_five" else &"crossing")
	# A LARGE AEROPLANE FLIES AN INSTRUMENT APPROACH, not the VFR pattern (the user, 2026-09-19: "something more
	# similar to a IFR approach which requires far less turning"): vectors to a long final, or a straight-in.
	var numbers: Dictionary = Airfield.numbers_of(kind)
	var ifr: InstrumentApproach = null
	var fixes := PackedVector3Array()
	if InstrumentApproach.flies_it(numbers):
		ifr = InstrumentApproach.make(pattern, numbers)
		fixes = ifr.vectors_for(state["position"], state["velocity"])
		entry = &"instrument"
		phase = &"straight_in" if fixes.is_empty() else &"vectors"
	if joining != &"":
		phase = joining
	pilots[entity] = {"entity": entity, "kind": kind, "field": String(field["id"]), "pattern": pattern, "phase": phase, "entry": entry,
		"track": [], "legs": [phase], "gates": [], "past_gate": false, "go_arounds": 0, "turn": turn,
		"field_data": field, "end": end, "last_heading": NAN, "last_tick": 0, "base_at": NAN, "asked": INF,
		"extended": 0.0, "turned_away": 0, "began": {phase: Engine.get_physics_frames()},
		"ifr": ifr, "fixes": fixes, "fix_next": 0, "fix_from": state["position"]}
	Sim.server.set_ai_manners(entity, {"bank": ifr.bank if ifr != null else pattern.bank})
	_put_on_the_rota(entity)
	return true


## TAXI `entity` FROM ITS PARKING SPOT ON `field` AND TAKE OFF, from the end in use (or `end`); then depart, and hand
## it back to the random-waypoint wander -- or, if `then_to` is another airfield, fly there and land. The spot is
## `spot_id` of the base laid round the field's runway (`AirbasePlan`), or the nearest spot to where it stands; a field
## with no base lines up from where it is. Host only.
func depart(entity: int, field: Dictionary, kind: int, spot_id: String = "", end: String = "",
		then_to: Dictionary = {}) -> bool:
	if Sim.server == null or field.is_empty():
		return false
	var state: Dictionary = Sim.server.vehicle_state(entity)
	if state.is_empty():
		return false
	var turn: float = turn_expected(kind)
	var p: TrafficPattern = Airfield.pattern_for(field, kind, end, turn)
	var me: Dictionary = _new_record(entity, field, kind, end, p, turn, &"taxi", &"departure")
	me["route"] = _taxi_route(field, p, state["position"], spot_id)
	me["route_next"] = 0
	me["then_to"] = then_to
	if (me["route"] as PackedVector3Array).is_empty():
		_become(me, &"line_up")
	pilots[entity] = me
	# ON ITS BRAKES AT ONCE: an autopilot with its wheels on the ground takes off on its own, and the first look at it
	# on the rota is up to a fifth of a second away.
	_steer(entity, state["position"], p.field, 0.0, {"wheels": "hold"})
	Sim.server.set_ai_manners(entity, {"bank": p.bank})
	_put_on_the_rota(entity)
	return true


## FLY `entity` TO `field` AND LAND THERE: en route above the ground between, then the arrival. Host only.
func fly_to(entity: int, field: Dictionary, kind: int, end: String = "") -> bool:
	if Sim.server == null or field.is_empty() or Sim.server.vehicle_state(entity).is_empty():
		return false
	var turn: float = turn_expected(kind)
	var p: TrafficPattern = Airfield.pattern_for(field, kind, end, turn)
	var me: Dictionary = _new_record(entity, field, kind, end, p, turn, &"enroute", &"enroute")
	pilots[entity] = me
	Sim.server.set_ai_manners(entity, {"bank": p.bank})
	_put_on_the_rota(entity)
	return true


## A PILOT'S RECORD, the same shape whatever it was asked to do. `entry` is how it came (or is going) to the field.
func _new_record(entity: int, field: Dictionary, kind: int, end: String, p: TrafficPattern, turn: float,
		phase: StringName, entry: StringName) -> Dictionary:
	return {"entity": entity, "kind": kind, "field": String(field["id"]), "pattern": p, "phase": phase,
		"entry": entry, "track": [], "legs": [phase], "gates": [], "past_gate": false, "go_arounds": 0, "turn": turn,
		"field_data": field, "end": end, "last_heading": NAN, "last_tick": 0, "base_at": NAN, "asked": INF,
		"extended": 0.0, "turned_away": 0, "began": {phase: Engine.get_physics_frames()}}


## THE BASE LAID ROUND A FIELD'S RUNWAY, or one serving it as well as its own (an airport's crossing runway): the field's
## own `base` if a test handed it one, or {}.
func _base_of(field: Dictionary) -> Dictionary:
	var base: Dictionary = field.get("base", {})
	if base.is_empty() and field.has("index"):
		base = AirbasePlan.on_runway(int(field["index"]))
	return base


## WHICH RUNWAY A FIELD IS, as a base's holds and exits name it: the airfield id that laid it, or "" for a world's own.
static func _runway_id(field: Dictionary) -> String:
	return String((field.get("frame", {}) as Dictionary).get("field", ""))


## THE TAXI ROUTE from the spot `spot_id` (or the nearest to `at`) to the hold bar nearest the threshold in use, as
## positions; empty if the field has no base, or no route.
func _taxi_route(field: Dictionary, p: TrafficPattern, at: Vector3, spot_id: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	var base: Dictionary = _base_of(field)
	if base.is_empty():
		return out
	var spots: Dictionary = base["spots"]
	var spot: Dictionary = spots.get(spot_id, {})
	if spot.is_empty():
		var nearest: float = INF
		for id in spots:
			var d: float = _flat((spots[id] as Dictionary)["position"] - at).length()
			if d < nearest:
				nearest = d
				spot = spots[id]
	var nodes: Dictionary = base["nodes"]
	var hold: String = ""
	var nearest_hold: float = INF
	# THE HOLD OF THIS RUNWAY, nearest its threshold in use: at an airport with two runways the nearest bar to 09's
	# threshold may hold short of the other one (lane/airport).
	var runway: String = _runway_id(field)
	for name in base.get("holds", {}):
		if String((base["holds"][name] as Dictionary)["runway"]) != runway:
			continue
		var d: float = _flat((nodes[name] as Dictionary)["position"] - p.threshold).length()
		if d < nearest_hold:
			nearest_hold = d
			hold = name
	if spot.is_empty() or hold == "":
		return out
	for name in AirbasePlan.route(base, String(spot["node"]), hold):
		out.append((nodes[name] as Dictionary)["position"])
	return out


## LET GO of `entity`: back to its own legs.
func release(entity: int) -> void:
	if pilots.erase(entity) and Sim.server != null:
		Sim.server.steer_ai(entity, {})
		Sim.server.remove_chore("pattern", entity)


func _put_on_the_rota(entity: int) -> void:
	if not _on_rota:
		_on_rota = bool(Sim.server.add_chore_kind("pattern", THINK_TICKS, THINK_LIMIT, THINK_SHARE, _think))
	Sim.server.add_chore("pattern", entity)


## ---- one aeroplane, ten times a second -----------------------------------------------------------------------------

## THE ROTA'S CALLBACK, timed as a whole so that the parts below can be read as shares of it. The parts nest inside it,
## so they add up to more than the whole where one calls another; `think` is the total.
func _think(entity: int, waited: int) -> void:
	var watch: int = STOPWATCH.start()
	if watch != 0:
		_count(&"think")
	_think_now(entity, waited)
	STOPWATCH.lap(&"think", watch)


func _think_now(entity: int, _waited: int) -> void:
	var me: Dictionary = pilots.get(entity, {})
	var watch: int = STOPWATCH.start()
	if watch != 0:
		_count(&"own_state")
	var state: Dictionary = Sim.server.vehicle_state(entity) if Sim.server != null else {}
	STOPWATCH.lap(&"own_state", watch)
	if me.is_empty() or state.is_empty():
		release(entity)
		return
	var p: TrafficPattern = me["pattern"]
	var at: Vector3 = state["position"]
	var v: Vector3 = state["velocity"]
	var flat_v := Vector3(v.x, 0.0, v.z)
	var soon: Vector3 = at + flat_v * LEAD_S
	var reach: float = p.radius * CARROT_RADII
	var phase: StringName = me["phase"]
	if STOPWATCH.running:
		_count(StringName("look:" + String(phase)))
	var basis := Basis(state["basis"] as Quaternion)
	var bank: float = atan2(-(basis * Vector3.RIGHT).y, maxf((basis * Vector3.UP).y, 0.05))
	_gauge_the_turn(me, flat_v, bank)
	# UNTIL IT JOINS THE CIRCUIT, the circuit is sized on the latest gauge.
	var ifr: InstrumentApproach = me.get("ifr")
	var replan: bool = ifr != null and phase == &"vectors" and int(me["fix_next"]) <= 1
	if (BEFORE_THE_CIRCUIT.has(phase) or replan) and absf(float(me["turn"]) - p.turn) > 0.02:
		p = Airfield.pattern_for(me["field_data"], int(me["kind"]), String(me["end"]), float(me["turn"]))
		me["pattern"] = p
		reach = p.radius * CARROT_RADII
		if ifr != null:
			# THE VECTORS RE-LAID FROM HERE, on the turn it has now measured, while there is still a base to fly.
			ifr = InstrumentApproach.make(p, Airfield.numbers_of(int(me["kind"])))
			me["ifr"] = ifr
			if phase == &"vectors":
				me["fixes"] = ifr.vectors_for(at, v)
				me["fix_next"] = 0
				me["fix_from"] = at
				if (me["fixes"] as PackedVector3Array).is_empty():
					_become(me, &"straight_in")
					phase = &"straight_in"
		Sim.server.set_ai_manners(entity, {"bank": ifr.bank if ifr != null else p.bank})
	if recording:
		(me["track"] as Array).append({"at": at, "v": v, "phase": phase, "tick": Engine.get_physics_frames(),
			"bank": bank, "turn": float(me["turn"])})
	match phase:
		# ON THE GROUND, OUT: along the route, holding short, lining up and taking off.
		# ALONG THE ROUTE'S SEGMENTS, by a carrot `TAXI_LOOK` ahead on the one it is on, and slow for `TAXI_SLOWING`
		# either side of every corner: steered at the next node and let go fast as soon as it passed one, the first
		# Cessna swung 19.8 m wide of the taxiway coming out of a bend at 8.8 m/s.
		&"taxi":
			if _follow_route(entity, me, at, p):
				_become(me, &"hold_short")
		&"hold_short":
			_steer(entity, at, p.field, 0.0, {"wheels": "hold"})
			var busy: String = _runway_busy_for_departure(me)
			me["holding_for"] = busy
			if busy == "":
				_become(me, &"line_up")
		# ONTO THE CENTRELINE, THEN ALONG IT until the nose is down the runway: arrived at the line-up point from the
		# stub, the first Cessna was still pointing across the runway and lifted off 30.7 m to one side of it.
		&"line_up":
			var spot_on: Vector3 = p.point(LINE_UP_AT, 0.0)
			_steer(entity, spot_on, p.field, TAXI_TURNING, {"wheels": "taxi"})
			if _flat(spot_on - at).length() < TAXI_REACHED * 0.75:
				_become(me, &"align")
		&"align":
			_steer(entity, _carrot(p.threshold, p.along, at, ALIGN_LOOK), p.field, TAXI_TURNING, {"wheels": "taxi"})
			if flat_v.length() > 1.0 and flat_v.normalized().dot(p.along) > cos(ALIGNED):
				_become(me, &"take_off")
		# THE ROLL, tracking the centreline: the autopilot's take-off steers for the place it is given, and the place is a
		# carrot `ROLL_LOOK` ahead on the centreline, moved on every look.
		&"take_off":
			_steer(entity, _carrot(p.threshold, p.along, at, ROLL_LOOK), p.field + p.height, p.downwind_speed,
				{"wheels": "take_off"})
			if not bool(Sim.server.ai_wheels(entity).get("on_wheels", true)) and at.y - p.field > 10.0:
				me["lift_off"] = at
				_become(me, &"departure")
		# THE DEPARTURE LEG: straight ahead up the extended centreline, climbing to pattern height.
		&"departure":
			_steer(entity, _carrot(p.threshold, p.along, at, reach), p.field + p.height, p.downwind_speed)
			if p.ahead_of(at) >= p.length + TrafficPattern.DEPARTURE_PAST \
					and at.y >= p.field + p.height - TrafficPattern.GATE:
				me["depart_from"] = at
				# A HEAVY GOING ON TO ANOTHER FIELD IS VECTORED FROM HERE, not flown round the VFR 45: two miles of it put a
				# 747 bound for 36 heading north-east over the sea, and its turn back onto the vectors, at 3.8 km flown, swung
				# it 18.4 km out, past the island's warning (airport_shot --scene=trip, lane/airport).
				var then_to: Dictionary = me.get("then_to", {})
				if not then_to.is_empty() and InstrumentApproach.flies_it(Airfield.numbers_of(int(me["kind"]))):
					_carry_on_to(entity, me, then_to)
					return
				_become(me, &"departing")
		# THE 45-DEGREE DEPARTURE TURN to the pattern's side, and then on its own.
		&"departing":
			var out_along: Vector3 = (p.along + p.across * p.side).normalized()
			var from: Vector3 = me["depart_from"]
			_steer(entity, _carrot(from, out_along, at, reach), p.field + p.height, p.downwind_speed)
			if _high_ground_ahead(me, at, flat_v):
				return
			if _flat(at - from).length() > DEPART_OUT:
				var then_to: Dictionary = me.get("then_to", {})
				if then_to.is_empty():
					release(entity)
					return
				_carry_on_to(entity, me, then_to)
				return
		# CIRCLING TO CLIMB, left-handed round a point beside where it began, until it has the height the ground ahead
		# wants; then on its way -- en route if it is going somewhere, or on its own.
		&"climb_out":
			var centre: Vector3 = me["climb_centre"]
			var radial: Vector3 = _flat(at - centre).normalized()
			var ahead_on_circle: Vector3 = radial.rotated(Vector3.UP, CIRCLE_LEAD)
			_steer(entity, centre + ahead_on_circle * p.radius * CIRCLE_RADII, float(me["climb_to"]), p.downwind_speed)
			if at.y >= float(me["climb_to"]) - TrafficPattern.GATE * 0.3:
				var then_to: Dictionary = me.get("then_to", {})
				if me["legs"].has(&"enroute") or not then_to.is_empty():
					if then_to.is_empty():
						_become(me, &"enroute")
					else:
						_carry_on_to(entity, me, then_to)
						return
				else:
					release(entity)
					return
		# EN ROUTE to another field, above everything between, until it is near enough to choose its entry.
		&"enroute":
			var aim: Vector3 = p.point(p.length * 0.5, 0.0)
			# THE CRUISE HEIGHT STARTS AT PATTERN HEIGHT AND RISES OUT OF THE LOOK-AHEAD, and is no longer a query of
			# its own over the whole leg. See `_high_ground_ahead`. The look is taken BEFORE the steer so the height
			# this look found is the height this look flies at, rather than the one before it.
			if not me.has("cruise_at"):
				me["cruise_at"] = p.field + p.height
			if _high_ground_ahead(me, at, flat_v):
				return
			_steer(entity, aim, float(me["cruise_at"]), p.downwind_speed)
			if _flat(aim - at).length() < ARRIVE_WITHIN:
				var track: Array = me["track"]
				arrive(entity, me["field_data"], int(me["kind"]), String(me["end"]))
				(pilots[entity] as Dictionary)["track"] = track
				(pilots[entity] as Dictionary)["legs"] = (me["legs"] as Array) + (pilots[entity]["legs"] as Array)
				return
		# THE 45: level at pattern height to where the entry line starts, then along it to mid-field downwind.
		&"to_entry":
			var start: Vector3 = p.entry_start()
			_steer(entity, start, p.field + p.height, p.downwind_speed)
			if _downwind_conflict(me, _seconds_to_join(me, at, flat_v.length())):
				me["turned_away"] = int(me["turned_away"]) + 1
				_become(me, &"turn_away")
			elif _flat(at - start).length() < reach:
				_become(me, &"entry")
		&"entry":
			var join: Vector3 = p.abeam_midfield()
			var line: Vector3 = _flat(join - p.entry_start()).normalized()
			_steer(entity, _carrot(p.entry_start(), line, at, reach), p.field + p.height, p.downwind_speed)
			if _downwind_conflict(me, _seconds_to_join(me, at, flat_v.length())):
				me["turned_away"] = int(me["turned_away"]) + 1
				_become(me, &"turn_away")
			elif (join - at).dot(line) < p.radius:
				_become(me, &"downwind")
		# YIELDING ON THE 45: back out along the entry line, then round onto it again.
		&"turn_away":
			var away: Vector3 = p.entry_start() + _flat(p.entry_start() - p.abeam_midfield()).normalized() \
				* p.radius * TURN_AWAY_RADII
			_steer(entity, away, p.field + p.height, p.downwind_speed)
			if _flat(at - away).length() < reach:
				_become(me, &"to_entry")
		# THE TEARDROP ([AFH] 8-3A): over mid-field 500 ft above, out about two miles on the pattern side coming down to
		# pattern height, then round onto the 45.
		&"crossing":
			var over: Vector3 = p.point(p.length * 0.5, 0.0)
			_steer(entity, over, p.field + p.height + TrafficPattern.TEARDROP_ABOVE, p.downwind_speed)
			if _flat(at - over).length() < reach or p.out_of(at) > 0.0:
				_become(me, &"outbound")
		&"outbound":
			var out: Vector3 = p.point(p.length * 0.5, p.offset + TrafficPattern.TEARDROP_OUT)
			_steer(entity, out, p.field + p.height, p.downwind_speed)
			if p.out_of(at) > p.offset + TrafficPattern.TEARDROP_OUT - reach:
				_become(me, &"to_entry")
		&"downwind":
			_steer(entity, _carrot(p.abeam_midfield(), -p.along, at, reach),
				_no_higher(me, p.height_at(&"downwind", soon)), p.downwind_speed)
			if p.ahead_of(at) <= p.base_ahead() + p.radius:
				# TURN BASE NOW, OR EXTEND: the path left if it turned here, against its leader's plus the spacing.
				var turning_here: float = p.ahead_of(at) - p.radius
				var gap: float = _gap_to_leader(me, p.path_to_touchdown(&"downwind", at, turning_here), p)
				if gap >= SPACING_S * p.final_speed:
					me["base_at"] = turning_here
					me["extended"] = maxf(p.base_ahead() - turning_here, 0.0)
					_become(me, &"base")
		&"base":
			var toward: Vector3 = -p.across * p.side
			var corner: Vector3 = p.point(float(me["base_at"]), p.offset)
			_steer(entity, _carrot(corner, toward, at, reach),
				_no_higher(me, p.height_at(&"base", soon, float(me["base_at"]))), p.base_speed)
			if p.out_of(at) <= p.radius:
				_become(me, &"final")
		# VECTORS TO THE FINAL COURSE: through each fix in turn, the turn at each begun a turn's lead short of it (r tan of
		# half the turn), so the curve ends on the next leg and is flown at the approach's radius, never tighter.
		&"vectors":
			var fixes: PackedVector3Array = me["fixes"]
			var next: int = int(me["fix_next"])
			var from: Vector3 = me["fix_from"] if next == 0 else fixes[next - 1]
			var fix: Vector3 = fixes[next]
			var leg: Vector3 = _flat(fix - from)
			var left_on_leg: float = _flat(fix - at).dot(leg.normalized()) if leg.length() > 1.0 else 0.0
			var lead: float = 0.0
			if next + 1 < fixes.size():
				var after: Vector3 = _flat(fixes[next + 1] - fix)
				lead = ifr.radius * tan(0.5 * absf(leg.normalized().signed_angle_to(after.normalized(), Vector3.UP)))
			else:
				lead = ifr.radius * tan(0.5 * InstrumentApproach.INTERCEPT)
			_steer(entity, _carrot(from, leg, at, ifr.radius) if next > 0 else fix, fix.y, ifr.speed)
			if left_on_leg <= lead:
				me["fix_next"] = next + 1
				if next + 1 >= fixes.size():
					_become(me, &"final")
		&"final", &"straight_in":
			# LEVEL UNTIL THE 3-DEGREE PATH COMES DOWN TO MEET IT, then down it: a long final from pattern height, or an
			# extended circuit's lower one, is never asked to climb back up to its path. On an instrument approach the
			# level is the glideslope's intercept height, and the path is met from below ([AIM] 5-4-5).
			var height: float = _no_higher(me, minf(p.height_at(&"final", soon), p.field + p.height)) if ifr == null \
				else ifr.final_height(soon)
			if ifr != null:
				# THE FINAL COURSE INTERCEPTED AT NO MORE THAN 30 DEGREES ([7110.65] 5-9-1): the carrot is as far ahead as
				# the offset over tan 30.
				reach = maxf(ifr.radius, absf(p.out_of(at)) / tan(InstrumentApproach.INTERCEPT))
			if phase == &"straight_in" and p.ahead_of(at) >= p.ahead_of(p.final_join()):
				_become(me, &"final")
			# ON AN APPROACH, the look-ahead's escape climb is not flown: a 3-degree path sees the runway along its
			# velocity, and that is where it is meant to go. Below the gate the wheels are told it is a landing.
			var wheels: String = "land" if bool(me["past_gate"]) else "fly"
			_steer(entity, _carrot(p.threshold, p.along, at, reach), height, p.final_speed,
				{"approach": true, "wheels": wheels})
			if at.y - p.field <= TrafficPattern.GATE and not bool(me["past_gate"]):
				me["past_gate"] = true
				(me["gates"] as Array).append({"at": at, "v": v, "tick": Engine.get_physics_frames()})
				var why: String = _unstable(p, at, v)
				var behind: float = _gap_to_leader(me, p.path_to_touchdown(&"final", at), p)
				if why == "" and behind < CLOSEST_S * p.final_speed:
					why = "%.0f s behind the one ahead" % (behind / p.final_speed)
				if why != "":
					(me["gates"][-1] as Dictionary)["went_around"] = why
					_go_around(me)
			if bool(me["past_gate"]) and at.y - p.field <= LOW_PASS and (me["gates"] as Array).size() > 0 \
					and not (me["gates"][-1] as Dictionary).has("low"):
				(me["gates"][-1] as Dictionary)["low"] = {"at": at, "v": v, "tick": Engine.get_physics_frames()}
				var on_it: String = _runway_taken(me)
				if on_it != "":
					(me["gates"][-1] as Dictionary)["went_around"] = on_it
					_go_around(me)
			if bool(Sim.server.ai_wheels(entity).get("touched", false)):
				_become(me, &"rollout")
		# THE ROLL-OUT: along the centreline to the far end, braking, until it is down to a taxi.
		&"rollout":
			_steer(entity, p.far_end, p.field, 0.0, {"wheels": "land"})
			if flat_v.length() < TAXI_SPEED:
				me["landed"] = Sim.server.ai_wheels(entity)
				# OFF AT THE NEXT EXIT AND IN TO A GATE, where the field has an airport round it; otherwise off to the side.
				if _plan_the_taxi_in(me, p, at):
					_become(me, &"vacating")
				else:
					me["off_at"] = _free_spot(me, p, p.ahead_of(at) + TAXI_OFF)
					_become(me, &"clearing")
		# ALONG THE RUNWAY TO THE EXIT AND OFF IT, then on to the gate: on the runway (it still counts as on it, for anybody
		# landing behind or crossing) until it is the hold bar's distance off the centreline.
		&"vacating", &"taxi_in":
			var done: bool = _follow_route(entity, me, at, p)
			if phase == &"vacating" and absf(p.out_of(at)) >= _clear_distance(me):
				_become(me, &"taxi_in")
			if done:
				_become(me, &"parked")
		&"parked":
			_steer(entity, at, p.field, 0.0, {"wheels": "hold"})
		# TAXIING CLEAR, off the side away from the pattern, then holding there.
		&"clearing":
			var off: Vector3 = me["off_at"]
			_steer(entity, off, p.field, TAXI_SPEED, {"wheels": "taxi"})
			if _flat(at - off).length() < 5.0:
				_become(me, &"stopped")
		&"stopped":
			_steer(entity, at, p.field, 0.0, {"wheels": "hold"})
		# THE GO-AROUND ([AC] 11.6): straight ahead along the runway, climbing to pattern height; the crosswind turn is
		# beyond the departure end and within 300 ft of pattern height ([AC] 11.7), and then the circuit again.
		&"go_around":
			_steer(entity, _carrot(p.threshold, p.along, at, reach), p.field + p.height, p.downwind_speed)
			if p.ahead_of(at) > p.length and at.y > p.field + p.height - TrafficPattern.GATE:
				if ifr != null:
					# AN INSTRUMENT ARRIVAL THAT GOES AROUND IS VECTORED ROUND AGAIN ([AIM] 5-4-21's missed approach, then
					# vectors for another), never into the VFR circuit it does not fly.
					me["fixes"] = ifr.vectors_for(at, v)
					me["fix_next"] = 0
					me["fix_from"] = at
					_become(me, &"vectors" if not (me["fixes"] as PackedVector3Array).is_empty() else &"straight_in")
				else:
					_become(me, &"crosswind")
		&"crosswind":
			var corner: Vector3 = p.point(p.ahead_of(at), 0.0)
			_steer(entity, _carrot(corner, p.across * p.side, at, reach), p.field + p.height, p.downwind_speed)
			if p.out_of(at) >= p.offset - p.radius:
				_become(me, &"downwind")


## ALONG `me["route"]` BY A CARROT: `TAXI_LOOK` ahead on the segment it is on, at `TAXI_SPEED`, slowing to `TAXI_TURNING`
## for `TAXI_SLOWING` either side of every corner. Steered at the next node and let go fast as soon as it passed one, the
## first Cessna swung 19.8 m wide of the taxiway coming out of a bend at 8.8 m/s. True once the last node is reached; the
## last leg of a taxi to a gate is flown slow all the way and ends within `PARKED_WITHIN` of the stand.
func _follow_route(entity: int, me: Dictionary, at: Vector3, p: TrafficPattern) -> bool:
	var watch: int = STOPWATCH.start()
	if watch != 0:
		_count(&"follow_route")
	var done: bool = _follow_route_now(entity, me, at, p)
	STOPWATCH.lap(&"follow_route", watch)
	return done


func _follow_route_now(entity: int, me: Dictionary, at: Vector3, p: TrafficPattern) -> bool:
	var route: PackedVector3Array = me["route"]
	if route.is_empty():
		return true
	var next: int = int(me["route_next"])
	var last: bool = next >= route.size() - 1
	var target: Vector3 = route[mini(next, route.size() - 1)]
	var to_go: float = _flat(target - at).length()
	var from_last: float = _flat(at - route[maxi(next - 1, 0)]).length()
	# SLOW OUT OF A STAND, never along the runway to an exit: a landing reaches its first node at taxi speed already.
	var slow: bool = (next == 0 and not me.has("gate")) or (to_go < TAXI_SLOWING and not last) or from_last < TAXI_SLOWING \
		or (last and me.has("gate"))
	var toward: Vector3 = target
	if next > 0:
		var leg: Vector3 = _flat(target - route[next - 1])
		var look: float = _taxi_look(me)
		toward = _carrot(route[next - 1], leg, at, look)
		# ON A STAND'S LEAD-IN THE CARROT RUNS ON PAST THE MARK: steered at the mark itself, the last metres swung the nose
		# after any sideways offset, and the first 747 parked 27 degrees off its line (tests/airport.gd, lane/airport).
		var on_a_stand: bool = last and me.has("gate") and leg.length() >= 1.0
		var beyond: float = (toward - route[next - 1]).dot(leg.normalized()) - leg.length() if leg.length() >= 1.0 else 0.0
		if not on_a_stand and (leg.length() < 1.0 or beyond > 0.0):
			toward = target
			# THE CARROT GOES ROUND THE CORNER, as it does in the air: what it has left past the node is laid along the next
			# leg, so the nose starts round before the taxiway does. Held at the node, every craft turned only AFTER the
			# taxiway had (the user, 2026-09-19: "it's only turning AFTER the taxiway turns").
			if not last and beyond > 0.0:
				var onward: Vector3 = _flat(route[next + 1] - target)
				if onward.length() >= 1.0:
					toward = target + onward.normalized() * minf(beyond, onward.length())
	var speed: float = TAXI_TURNING if slow else TAXI_SPEED
	# ONTO A STAND, CREEPING: slower the nearer its mark, as a marshaller's arms close. At a steady 4 m/s the first 747 ran
	# 4.3 m past its mark on the brakes (tests/airport.gd, lane/airport).
	if last and me.has("gate"):
		speed = clampf(to_go * PARKING_EASE, PARKING_CREEP, TAXI_TURNING)
	_steer(entity, toward, p.field, speed, {"wheels": "taxi"})
	# ONTO A STAND: stopped on its mark, or once it is past it.
	var reached: float = PARKED_WITHIN if last and me.has("gate") else TAXI_REACHED
	# PAST A NODE ALONG THE LEG IT CAME IN ON COUNTS AS REACHED: a 747 swinging wide through the square corner from the east
	# link onto the apron lane never came within TAXI_REACHED of the node, and circled it for three minutes (airport_shot
	# --scene=trip, lane/airport). The last node of a departure's route, the hold bar, is still reached only by standing on it.
	var past: bool = next > 0 and _flat(at - target).dot(_flat(target - route[next - 1])) > 0.0
	if to_go < reached or (past and (not last or me.has("gate"))):
		me["route_next"] = next + 1
		return next + 1 >= route.size()
	return false


## HOW FAR AHEAD A TAXIING CRAFT'S CARROT RIDES, and so how early it leads a corner: `TAXI_LOOK` for a light aeroplane,
## `TAXI_LOOK_HEAVY` for a kind that flies the instrument approach, whose turn on the ground is as much wider as its span.
func _taxi_look(me: Dictionary) -> float:
	return TAXI_LOOK_HEAVY if InstrumentApproach.flies_it(Airfield.numbers_of(int(me["kind"]))) else TAXI_LOOK


## HOW FAR OFF THE CENTRELINE A LANDED AEROPLANE IS CLEAR OF ITS RUNWAY: the airport's hold bar where it has one -- a 747
## 40 m off, the old `RUNWAY_CLEAR`, still has its wingtip over the edge -- and `RUNWAY_CLEAR` where it has none.
func _clear_distance(me: Dictionary) -> float:
	var base: Dictionary = _base_of(me["field_data"])
	return maxf(RUNWAY_CLEAR, float((base.get("standards", {}) as Dictionary).get("hold_bar", 0.0)))


## THE TAXI IN, planned where the roll-out comes down to a taxi: along the runway to the first way off it ahead -- a
## high-speed exit's start or a stub's join on THIS runway -- and from there by `AirbasePlan.route` to the nearest free
## nose-in gate its kind fits, ending where it stands with its nose on the gate's line. False where the field has no
## airport round it, no way off ahead or no gate free; the old clearing to the side is flown then.
func _plan_the_taxi_in(me: Dictionary, p: TrafficPattern, at: Vector3) -> bool:
	var watch: int = STOPWATCH.start()
	if watch != 0:
		_count(&"plan_the_taxi_in")
	var planned: bool = _plan_the_taxi_in_now(me, p, at)
	STOPWATCH.lap(&"plan_the_taxi_in", watch)
	return planned


func _plan_the_taxi_in_now(me: Dictionary, p: TrafficPattern, at: Vector3) -> bool:
	var field: Dictionary = me["field_data"]
	var base: Dictionary = _base_of(field)
	if base.is_empty():
		return false
	var runway: String = _runway_id(field)
	var nodes: Dictionary = base["nodes"]
	var ways_off: Array[String] = []
	for exit in base.get("exits", []):
		if String(exit["runway"]) == runway:
			ways_off.append(exit["start"])
	for name in base.get("holds", {}):
		if String(base["holds"][name]["runway"]) == runway:
			ways_off.append(base["holds"][name]["join"])
	var here: float = p.ahead_of(at)
	var off: String = ""
	for name in ways_off:
		var ahead: float = p.ahead_of((nodes[name] as Dictionary)["position"])
		if ahead >= here - TAXI_REACHED and ahead <= p.length \
				and (off == "" or ahead < p.ahead_of((nodes[off] as Dictionary)["position"])):
			off = name
	if off == "":
		return false
	var kind: int = int(me["kind"])
	var best: Array = []
	var gate: String = ""
	for id in base["spots"]:
		var spot: Dictionary = base["spots"][id]
		if not bool(spot.get("nose_in", false)) or not AirbasePlan.fits(spot, kind) or _gate_taken(me, id):
			continue
		var path: Array = AirbasePlan.route(base, off, spot["node"])
		if not path.is_empty() and (best.is_empty() or _route_length(nodes, path) < _route_length(nodes, best)):
			best = path
			gate = id
	if gate == "":
		return false
	var route := PackedVector3Array()
	for k in range(best.size() - 1):
		route.append((nodes[best[k]] as Dictionary)["position"])
	# THE MOUTH'S CORNER AS A CHORD (STAND_CHORD): a point on the taxilane before it, and one on the lead-in after it.
	var mark: Vector3 = AirbasePlan.standing_on_spot(base, base["spots"][gate], kind)
	if route.size() >= 2:
		var mouth: Vector3 = route[route.size() - 1]
		var before: Vector3 = route[route.size() - 2]
		var chord_in: float = minf(STAND_CHORD, _flat(mouth - before).length() * 0.5)
		var chord_out: float = minf(STAND_CHORD, _flat(mark - mouth).length() * 0.5)
		route[route.size() - 1] = mouth + _flat(before - mouth).normalized() * chord_in
		route.append(mouth + _flat(mark - mouth).normalized() * chord_out)
	route.append(mark)
	me["route"] = route
	me["route_next"] = 0
	me["gate"] = gate
	me["off_at"] = route[mini(1, route.size() - 1)]
	return true


func _gate_taken(me: Dictionary, id: String) -> bool:
	for other in pilots.values():
		if other != me and String(other.get("gate", "")) == id:
			return true
	return false


static func _route_length(nodes: Dictionary, path: Array) -> float:
	var metres: float = 0.0
	for k in range(path.size() - 1):
		metres += _flat((nodes[path[k + 1]] as Dictionary)["position"] - (nodes[path[k]] as Dictionary)["position"]).length()
	return metres


## HOW MUCH TURN THE BANK IS BUYING: the heading's rate since the last look, against g tan(bank) / v. Only while
## banked past `GAUGE_BANK`, where the ratio means something.
func _gauge_the_turn(me: Dictionary, flat_v: Vector3, bank: float) -> void:
	var tick: int = Engine.get_physics_frames()
	var heading: float = atan2(flat_v.x, -flat_v.z)
	var last: float = float(me["last_heading"])
	var dt: float = float(tick - int(me["last_tick"])) / float(Engine.physics_ticks_per_second)
	me["last_heading"] = heading
	me["last_tick"] = tick
	var speed: float = flat_v.length()
	# ONLY IN A STEADY TURN: rolling in, the bank is already there and the turn is not, and those looks read low. The
	# first airliner's gauge settled at 0.35 while it flew its 25-degree turns at 0.60, and its vectors were laid out
	# 70 per cent wider than it flew them.
	var steady: bool = absf(bank - float(me.get("last_bank", bank))) < GAUGE_STEADY * dt
	me["last_bank"] = bank
	if is_nan(last) or dt <= 0.0 or dt > 1.0 or absf(bank) < GAUGE_BANK or speed < 1.0 or not steady:
		return
	var rate: float = absf(wrapf(heading - last, -PI, PI)) / dt
	var coordinated: float = 9.81 * tan(absf(bank)) / speed
	var sample: float = clampf(rate / coordinated, 0.05, 1.0)
	me["turn"] = lerpf(float(me["turn"]), sample, GAUGE_WEIGHT)
	turn_of_kind[int(me["kind"])] = me["turn"]


## WHY AN APPROACH IS NOT STABILISED AT THE GATE, or "" if it is ([AFH] 9): on the centreline within `LINED_UP`, and at
## the landing speed within +10/-5 kt. An approach that is not goes around: "an immediate go-around should be initiated
## if the approach becomes unstabilized below 300 ft AGL".
func _unstable(p: TrafficPattern, at: Vector3, v: Vector3) -> String:
	var off: float = absf(p.out_of(at))
	var speed: float = v.length()
	if off > LINED_UP:
		return "%.0f m off the centreline" % off
	if speed > p.final_speed + FAST_BY or speed < p.final_speed - SLOW_BY:
		return "%.1f m/s against %.1f" % [speed, p.final_speed]
	return ""


func _go_around(me: Dictionary) -> void:
	me["go_arounds"] = int(me["go_arounds"]) + 1
	_become(me, &"go_around")


## ON TO ANOTHER FIELD after a departure, keeping the record's track and legs, so a picture can draw the whole flight.
func _carry_on_to(entity: int, me: Dictionary, field: Dictionary) -> void:
	var kind: int = int(me["kind"])
	var track: Array = me["track"]
	var legs: Array = me["legs"]
	fly_to(entity, field, kind)
	var next: Dictionary = pilots[entity]
	next["track"] = track
	next["legs"] = legs + (next["legs"] as Array)
	next["from_field"] = me["field"]
	next["lift_off"] = me.get("lift_off", Vector3.INF)


## Circling to climb: how far round the circle ahead the carrot is (a left-hand circle), and the circle's radius in the
## flown turn radii.
const CIRCLE_LEAD: float = deg_to_rad(50.0)
const CIRCLE_RADII: float = 1.5


## HOW MUCH OF THE LOOK'S REACH IS FLOWN BEFORE THE GROUND IS ASKED AGAIN, and how far the nose may swing before it is
## asked regardless of that. THE ASKING AND THE DECIDING ARE TWO DIFFERENT RATES: the look reaches `CLIMB_LOOK` ahead,
## so asking every `CLIMB_EVERY_S` re-sampled the same corridor forty times over at 70 m/s -- one ask is seven boxes of
## 5,625 ground texels, 25 ms, and 94 per cent of everything the airport pilots did (`tests/testfield_stress.gd`, 100
## aircraft, 2026-09-19). A turn invalidates a corridor outright, because it no longer lies ahead of the aeroplane.
const CLIMB_LOOK_AGAIN: float = 1.0 / 3.0
const CLIMB_TURNED: float = deg_to_rad(20.0)
## SO THE ASK REACHES THAT MUCH FURTHER THAN THE RULE NEEDS, and the aeroplane still knows the whole of `CLIMB_LOOK`
## ahead of it at the moment before it asks again. Asking only `CLIMB_LOOK` and letting what it knew shrink was the
## first cut, and it cost an aeroplane a third of its warning at the worst moment: the one `climb_out` the traffic flew
## at 50 aircraft stopped happening (tests/testfield_stress.gd, 2026-09-19). One extra box buys the rule back exactly.
const CLIMB_ASK: float = CLIMB_LOOK * (1.0 + CLIMB_LOOK_AGAIN)


## IS THERE GROUND ALONG ITS TRACK THAT A STEADY CLIMB WILL NOT CLEAR IN TIME? If so, `me` begins circling to climb
## (`climb_out`) and this answers true.
##
## THE GROUND IS ASKED ON DISTANCE FLOWN AND THE DECISION IS TAKEN EVERY LOOK. The ask is dear and its answer stays good
## while the aeroplane is still inside the corridor it asked about and still pointing down it, so it is repeated only
## after `CLIMB_LOOK_AGAIN` of the reach is flown or the track has swung `CLIMB_TURNED`, never oftener than
## `CLIMB_EVERY_S`. The DECISION is then taken at the rota's own rate, which is ten times a second rather than the one
## it used to be, against two things that both move as the aeroplane flies:
##
## THE SAMPLES ARE KEPT ONE BY ONE, not reduced to a worst height, and the rule reads the window `CLIMB_LOOK` ahead of
## WHERE THE AEROPLANE IS NOW: a box behind it drops out, and a box past its reach is not counted yet. Held as one
## number, an aeroplane would have gone on circling to clear a ridge it had already passed; read as the whole array, it
## would have climbed for ground `CLIMB_ASK` away that the old rule could not see at all. So the rule sees the same
## corridor it always saw, sampled from a grid that is pinned to the ask rather than to the aeroplane, and the ask is
## made `CLIMB_LOOK_AGAIN` of the reach further out so that window is always covered.
func _high_ground_ahead(me: Dictionary, at: Vector3, flat_v: Vector3) -> bool:
	var tick: int = Engine.get_physics_frames()
	if flat_v.length() < 1.0:
		return false
	var going: Vector3 = flat_v.normalized()
	var flown: float = INF
	var swung: float = INF
	if me.has("look_from"):
		flown = _flat(at - (me["look_from"] as Vector3)).length()
		swung = absf((me["look_along"] as Vector3).signed_angle_to(going, Vector3.UP))
	if (flown >= CLIMB_LOOK * CLIMB_LOOK_AGAIN or swung >= CLIMB_TURNED) \
			and tick >= int(me.get("next_look", 0)):
		me["next_look"] = tick + int(CLIMB_EVERY_S * Engine.physics_ticks_per_second)
		me["look_from"] = at
		me["look_along"] = going
		me["look_ground"] = _ground_along(at, at + going * CLIMB_ASK)
		flown = 0.0
		# AND THE CRUISE HEIGHT RISES WITH WHAT THIS LOOK FOUND, which is why a cruise is no longer a query of its own.
		#
		# `enroute` used to work its cruise height out ONCE, over the WHOLE leg, on the tick it joined it: up to 35 km
		# at `ENROUTE_STEP`, thirty-odd boxes of 5,625 ground texels each, and a single tick of 36 to 152 ms --
		# EIGHTEEN TIMES the whole 8.33 ms budget. The rota bounds how many chores a tick serves and cannot bound what
		# one of them costs, so no budget was ever going to catch it.
		#
		# The look already walks the ground `CLIMB_ASK` ahead, all the way down the leg, as the aeroplane flies it. So
		# the cruise is taken from what the look found and costs nothing at all. It only ever RISES: a cruise that came
		# back down as high ground passed behind would porpoise down the leg, and nothing is gained by descending.
		# WHAT CHANGES IN THE AIR is that the climb comes in stages as the leg unrolls instead of all at once at the
		# start -- the aeroplane levels at pattern height, then steps up as each range comes within the look -- which
		# is what an aeroplane with a chart does anyway. Each stage has `CLIMB_ASK` of warning, and where that is not
		# enough to out-climb what is coming, `_high_ground_ahead` still circles it up as it always did.
		if me.has("cruise_at"):
			var found: float = 0.0
			for h in (me["look_ground"] as PackedFloat32Array):
				found = maxf(found, h)
			me["cruise_at"] = maxf(float(me["cruise_at"]), found + ENROUTE_CLEAR)
	if not me.has("look_ground"):
		return false
	var ground: PackedFloat32Array = me["look_ground"]
	var spacing: float = CLIMB_ASK / float(maxi(1, ground.size() - 1))
	var need: float = 0.0
	for i in range(ground.size()):
		# A BOX COUNTS WHILE IT OVERLAPS THE `CLIMB_LOOK` AHEAD OF THE AEROPLANE: not once the aeroplane is
		# `ENROUTE_ROOM` past its centre, and not yet while its centre is more than that beyond the rule's reach.
		var along: float = float(i) * spacing
		if along + ENROUTE_ROOM >= flown and along - ENROUTE_ROOM <= flown + CLIMB_LOOK:
			need = maxf(need, ground[i])
	need += ENROUTE_CLEAR
	# WHAT A STEADY CLIMB BUYS over the run the rule looks along, against what the ground ahead asks for.
	var buys: float = CLIMB_LOOK / flat_v.length() * CLIMB_CAN
	if STOPWATCH.running:
		_climb_slack = minf(_climb_slack, buys - (need - at.y))
	if need - at.y <= buys:
		return false
	if STOPWATCH.running:
		_climb_fired += 1
	var p: TrafficPattern = me["pattern"]
	# THE CIRCLE LIES TO THE LEFT OF ITS TRACK, so it is flown left-handed from where it is.
	me["climb_centre"] = at + Vector3(going.z, 0.0, -going.x) * p.radius * CIRCLE_RADII
	me["climb_to"] = maxf(need, float(me.get("cruise_at", need)))
	_become(me, &"climb_out")
	return true


## THE HIGHEST GROUND NEAR EACH SAMPLE ALONG THE LINE, one entry a sample, evenly spaced from `from` to `to` no more
## than `ENROUTE_STEP` apart. Sample by sample and not one number, so a caller that flies along the line afterwards can
## drop the samples it has passed (`_high_ground_ahead`).
func _ground_along(from: Vector3, to: Vector3) -> PackedFloat32Array:
	var watch: int = STOPWATCH.start()
	var out := PackedFloat32Array()
	var run: float = _flat(to - from).length()
	var steps: int = maxi(1, ceili(run / ENROUTE_STEP))
	for i in range(steps + 1):
		var at: Vector3 = from.lerp(to, float(i) / float(steps))
		out.append(float(highest_ground.call(at, ENROUTE_ROOM)))
	if watch != 0:
		# COUNTED IN SAMPLES AS WELL AS IN CALLS: a look 3 km along a track and a cruise leg 35 km long are one call and
		# thirty times the ground query, and it was the second of those that cost a 152 ms tick.
		_tally[&"ground_samples"] = int(_tally.get(&"ground_samples", 0)) + steps + 1
		_count(&"ground_along")
	STOPWATCH.lap(&"ground_along", watch)
	return out


## WHY `me` MAY NOT LINE UP YET, or "": somebody on the runway, or somebody on final or a straight-in who will be there
## within `DEPARTURE_CLEAR_S`.
func _runway_busy_for_departure(me: Dictionary) -> String:
	var watch: int = STOPWATCH.start()
	if watch != 0:
		_count(&"runway_busy_for_departure")
	var why: String = _runway_busy_for_departure_now(me)
	STOPWATCH.lap(&"runway_busy_for_departure", watch)
	return why


func _runway_busy_for_departure_now(me: Dictionary) -> String:
	var p: TrafficPattern = me["pattern"]
	for other in _circuit_of(me):
		if other == me:
			continue
		match other["phase"]:
			&"rollout", &"line_up", &"align", &"take_off":
				return "%d is %s" % [int(other["entity"]), other["phase"]]
			&"clearing", &"vacating":
				var state: Dictionary = Sim.server.vehicle_state(int(other["entity"]))
				if not state.is_empty() and absf(p.out_of(state["position"])) < _clear_distance(me):
					return "%d is %s" % [int(other["entity"]), other["phase"]]
			&"final", &"straight_in", &"base":
				if _path_left(other) < DEPARTURE_CLEAR_S * p.final_speed:
					return "%d is on %s" % [int(other["entity"]), other["phase"]]
	return _crossing_busy(me, true)


## ---- a runway that crosses another ([7110.65] 3-9-8, 3-10-4) ------------------------------------------------------
##
## FAA Order JO 7110.65BB, simplified: on intersecting runways a departure may not begin its roll, and an arrival may not
## cross the threshold, until whoever is using the other runway is clear of the intersection:
## - a departure on it has passed the intersection (3-9-8 b 1, 3-10-4 b 1);
## - a landing on it has passed the intersection, or has come down to a taxi short of it -- "completed the landing roll
##   and will hold short" or "observed turning off before" it (3-9-8 b 2, 3-10-4 b 2);
## - and for a departure, nobody on the other runway's final will be at its threshold within `DEPARTURE_CLEAR_S`, as on
##   its own runway.
## Short of the intersection is the hold bar's distance before it, measured along the other runway: the hold of a
## crossing runway is where its traffic stops. No land-and-hold-short: the island's airport has no tower to clear one.
## `me`'s runway is that of its field; `departing` says which of the two questions it is asking.
func _crossing_busy(me: Dictionary, departing: bool) -> String:
	var watch: int = STOPWATCH.start()
	if watch != 0:
		_count(&"crossing_busy")
	var why: String = _crossing_busy_now(me, departing)
	STOPWATCH.lap(&"crossing_busy", watch)
	return why


func _crossing_busy_now(me: Dictionary, departing: bool) -> String:
	var mine: Dictionary = (me["field_data"] as Dictionary).get("frame", {})
	for other in pilots.values():
		if other == me or String(other["field"]) == String(me["field"]):
			continue
		var theirs: Dictionary = (other["field_data"] as Dictionary).get("frame", {})
		var at: Vector3 = Terrain.runways_cross(mine, theirs) if not mine.is_empty() and not theirs.is_empty() else Vector3.INF
		if at == Vector3.INF:
			continue
		var state: Dictionary = Sim.server.vehicle_state(int(other["entity"]))
		if state.is_empty():
			continue
		var op: TrafficPattern = other["pattern"]
		var where: float = op.ahead_of(state["position"])
		var crossing: float = op.ahead_of(at)
		var clear: float = _clear_distance(me)
		var passed: bool = where > crossing + clear
		var short: bool = where < crossing - clear
		var slow: bool = (state["velocity"] as Vector3).length() < TAXI_SPEED
		match other["phase"]:
			&"line_up", &"align", &"take_off", &"departure":
				if not passed:
					return "%d is departing across the intersection" % int(other["entity"])
			&"rollout":
				if not passed and not (short and slow):
					return "%d is landing across the intersection" % int(other["entity"])
			# ITS ROLL DONE AND TURNING OFF: clear of the intersection when the way off it is taking lies short of it
			# ("observed turning off before the intersection"). Judged by its speed instead, a 747 taxiing to its exit at
			# 8.5 to 8.6 m/s flickered across the taxi-speed line and was clear one look and busy the next.
			&"vacating":
				var off_at: Vector3 = other.get("off_at", Vector3.INF)
				if not passed and (off_at == Vector3.INF or op.ahead_of(off_at) > crossing - clear):
					return "%d is turning off across the intersection" % int(other["entity"])
			&"final", &"straight_in", &"base":
				if departing and _path_left(other) < DEPARTURE_CLEAR_S * op.final_speed:
					return "%d is on %s for the crossing runway" % [int(other["entity"]), other["phase"]]
	return ""


## ---- the circuit ------------------------------------------------------------------------------------------------

## WHERE A LANDED AEROPLANE HOLDS: off the side away from the pattern, `from` metres past the threshold, or further along
## by `SPOT_APART` for every spot another aeroplane of the circuit is already making for or standing on.
func _free_spot(me: Dictionary, p: TrafficPattern, from: float) -> Vector3:
	var watch: int = STOPWATCH.start()
	if watch != 0:
		_count(&"free_spot")
	var along: float = from
	var taken := true
	while taken:
		taken = false
		for other in _circuit_of(me):
			if other != me and other.has("off_at") and absf(p.ahead_of(other["off_at"]) - along) < SPOT_APART:
				along += SPOT_APART
				taken = true
	STOPWATCH.lap(&"free_spot", watch)
	return p.point(along, -(p.width * 0.5 + TAXI_OFF))


## EVERY AEROPLANE LANDING ON THE SAME RUNWAY END as `me`, itself included.
func _circuit_of(me: Dictionary) -> Array[Dictionary]:
	var watch: int = STOPWATCH.start()
	if watch != 0:
		_count(&"circuit_of")
	var out: Array[Dictionary] = []
	for other in pilots.values():
		if String(other["field"]) == String(me["field"]) and String(other["end"]) == String(me["end"]):
			out.append(other)
	STOPWATCH.lap(&"circuit_of", watch)
	return out


## HOW FAR `me` STILL HAS TO FLY TO TOUCH DOWN, along the path it will fly; 0 on the runway; INF when it is not in the
## circuit yet (entering, going around), so it follows everyone and nobody follows it.
func _path_left(me: Dictionary) -> float:
	var watch: int = STOPWATCH.start()
	if watch != 0:
		_count(&"path_left")
	var left: float = INF
	var state: Dictionary = Sim.server.vehicle_state(int(me["entity"]))
	if not state.is_empty():
		var p: TrafficPattern = me["pattern"]
		var at: Vector3 = state["position"]
		match me["phase"]:
			&"downwind":
				left = p.path_to_touchdown(&"downwind", at)
			&"base":
				left = p.path_to_touchdown(&"base", at, float(me["base_at"]))
			&"final", &"straight_in":
				left = p.path_to_touchdown(&"final", at)
			&"rollout", &"clearing", &"vacating":
				left = 0.0
	STOPWATCH.lap(&"path_left", watch)
	return left


## THE ONE `me` FOLLOWS: the nearest to touching down of those nearer than it, or {}. One still on the runway counts.
func _leader_of(me: Dictionary) -> Dictionary:
	var watch: int = STOPWATCH.start()
	if watch != 0:
		_count(&"leader_of")
	var mine: float = _path_left(me)
	var best: Dictionary = {}
	var best_path: float = -1.0
	for other in _circuit_of(me):
		if other == me or other["phase"] == &"stopped":
			continue
		var theirs: float = _path_left(other)
		if theirs < mine and theirs > best_path:
			best = other
			best_path = theirs
	STOPWATCH.lap(&"leader_of", watch)
	return best


## HOW FAR BEHIND ITS LEADER `me` WOULD BE with `mine` metres still to fly, in metres of path; INF with nobody ahead.
## A leader on the runway is as far ahead as it will take to get off it, at `me`'s final speed.
func _gap_to_leader(me: Dictionary, mine: float, p: TrafficPattern) -> float:
	var leader: Dictionary = _leader_of(me)
	if leader.is_empty():
		return INF
	var theirs: float = _path_left(leader)
	if theirs == 0.0:
		return mine - _clearing_left_s(leader) * p.final_speed
	return mine - theirs


## Seconds before a landed aeroplane is clear of the runway: the rest of its taxi off, at taxi speed, or half the
## spacing while it is still rolling out and has not chosen where to go.
func _clearing_left_s(other: Dictionary) -> float:
	var state: Dictionary = Sim.server.vehicle_state(int(other["entity"]))
	if state.is_empty() or not other.has("off_at"):
		return SPACING_S * 0.5
	return _flat((other["off_at"] as Vector3) - (state["position"] as Vector3)).length() / TAXI_SPEED


## WHY THE RUNWAY IS NOT CLEAR FOR `me`, or "": another aeroplane of its circuit rolling out, lining up or taking off,
## or taxiing off and still within `RUNWAY_CLEAR` of the centreline.
func _runway_taken(me: Dictionary) -> String:
	var watch: int = STOPWATCH.start()
	if watch != 0:
		_count(&"runway_taken")
	var why: String = _runway_taken_now(me)
	STOPWATCH.lap(&"runway_taken", watch)
	return why


func _runway_taken_now(me: Dictionary) -> String:
	var p: TrafficPattern = me["pattern"]
	for other in _circuit_of(me):
		if other == me or not (other["phase"] in [&"rollout", &"clearing", &"vacating", &"line_up", &"align", &"take_off"]):
			continue
		var state: Dictionary = Sim.server.vehicle_state(int(other["entity"]))
		if not state.is_empty() and absf(p.out_of(state["position"])) < _clear_distance(me):
			return "the runway is not clear: %d is %s on it" % [int(other["entity"]), other["phase"]]
	var crossing: String = _crossing_busy(me, false)
	return "the crossing runway is not clear: %s" % crossing if crossing != "" else ""


## WOULD JOINING THE DOWNWIND IN `arriving_s` PUT `me` WITHIN THE SPACING of one already on it, or of another entrant
## that gets there first? One on the downwind short of mid-field reaches the join point at its own speed; one past it,
## and the base and final beyond, are ahead of an entrant and are followed rather than cut in on. Between two entrants
## the later one gives way, which is also what keeps two aeroplanes making for the same 45 apart.
func _downwind_conflict(me: Dictionary, arriving_s: float) -> bool:
	var watch: int = STOPWATCH.start()
	if watch != 0:
		_count(&"downwind_conflict")
	var clash: bool = _downwind_conflict_now(me, arriving_s)
	STOPWATCH.lap(&"downwind_conflict", watch)
	return clash


func _downwind_conflict_now(me: Dictionary, arriving_s: float) -> bool:
	var p: TrafficPattern = me["pattern"]
	for other in _circuit_of(me):
		if other == me:
			continue
		var state: Dictionary = Sim.server.vehicle_state(int(other["entity"]))
		if state.is_empty():
			continue
		var speed: float = maxf((state["velocity"] as Vector3).length(), 1.0)
		match other["phase"]:
			&"downwind":
				var their_s: float = (p.ahead_of(state["position"]) - p.length * 0.5) / speed
				if absf(their_s - arriving_s) < SPACING_S:
					return true
			&"to_entry", &"entry":
				var theirs: float = _seconds_to_join(other, state["position"], speed)
				if theirs <= arriving_s and arriving_s - theirs < SPACING_S:
					return true
	return false


## SECONDS UNTIL `me` JOINS THE DOWNWIND at mid-field from `at`: along the entry line if it is on it, or to the entry's
## start and then along it.
func _seconds_to_join(me: Dictionary, at: Vector3, speed: float) -> float:
	var p: TrafficPattern = me["pattern"]
	var line: float = _flat(p.abeam_midfield() - p.entry_start()).length()
	if me["phase"] == &"entry":
		return _flat(p.abeam_midfield() - at).length() / maxf(speed, 1.0)
	return (_flat(p.entry_start() - at).length() + line) / maxf(speed, 1.0)


## THE HEIGHT ASKED FOR, NEVER ABOVE WHAT WAS LAST ASKED on this approach: an extended downwind or a long final is
## flown level until its path comes down to meet it, never climbed back up to. Reset by a go-around.
func _no_higher(me: Dictionary, height: float) -> float:
	var asked: float = minf(float(me["asked"]), height)
	me["asked"] = asked
	return asked


## ONTO A NEW LEG, written down in the order flown. Joining a downwind is a new approach, with a gate still ahead of it.
func _become(me: Dictionary, phase: StringName) -> void:
	me["phase"] = phase
	(me["legs"] as Array).append(phase)
	# WHEN EACH LEG WAS LAST BEGUN, in physics ticks: for a check that asks whether one aeroplane touched down before
	# another was clear of the runway.
	(me["began"] as Dictionary)[phase] = Engine.get_physics_frames()
	# AT THE TOUCH, what a check needs and cannot see afterwards: whether its gear was down, and whether anybody else of
	# its circuit was on the runway.
	if phase == &"rollout" and Sim.server != null:
		me["gear_at_touch"] = bool(Sim.server.craft_controls(int(me["entity"])).get("gear", true))
		me["shared_runway"] = _runway_taken(me)
	# EVERY NEW APPROACH HAS A GATE AHEAD OF IT: a downwind, or an instrument arrival's vectors or straight-in. Reset only
	# on the downwind, a Hawkeye that went around from its fast first approach landed its second at 76 m/s unchecked.
	if phase in [&"downwind", &"vectors", &"straight_in"]:
		me["past_gate"] = false
		me["base_at"] = NAN
	if phase == &"go_around" or phase == &"to_entry":
		me["asked"] = INF


func _steer(entity: int, toward: Vector3, altitude: float, speed: float, more: Dictionary = {}) -> void:
	var watch: int = STOPWATCH.start()
	if watch != 0:
		_count(&"steer")
	var steer := {"toward": toward, "altitude": altitude, "speed": speed}
	steer.merge(more)
	Sim.server.steer_ai(entity, steer)
	STOPWATCH.lap(&"steer", watch)
	var me: Dictionary = pilots.get(entity, {})
	if recording and not me.is_empty() and not (me["track"] as Array).is_empty():
		var look: Dictionary = me["track"][-1]
		look["asked"] = altitude
		look["toward"] = toward


## THE CARROT: the foot of `at` on the line through `from` along `direction`, and `reach` further along it.
static func _carrot(from: Vector3, direction: Vector3, at: Vector3, reach: float) -> Vector3:
	var d: Vector3 = _flat(direction).normalized()
	return from + d * (_flat(at - from).dot(d) + reach)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## ---- for the tests and the pictures ---------------------------------------------------------------------------------

func record_of(entity: int) -> Dictionary:
	return pilots.get(entity, {})
