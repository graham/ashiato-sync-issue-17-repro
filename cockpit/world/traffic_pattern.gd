extends RefCounted
class_name TrafficPattern
## THE CIRCUIT ROUND ONE RUNWAY END, for one kind of aircraft: where each leg is, how high, how fast, and how far from
## touching down any point on it is. Pure geometry: it steers nothing and asks nothing of a running world.
##
## Asked for on 2026-09-19: aircraft that enter "a traffic pattern either on the right or left, usually 1000 feet above
## the airport, descending as they move through downwind, base and final", or fly straight in when they are "already on
## final". `research/traffic_pattern.md` has the FAA's words and every paragraph number; this file is those rules turned
## into points, and each constant says which rule it is.
##
## THE FRAME is the runway's (`Terrain.runway_frame`), landed on toward `along` from `threshold`. `side` is +1 for a
## right-hand pattern and -1 for a left-hand one, the default ([AIM] 4-3-3 b), so the downwind lies at `side * offset`
## across the runway: `across` is to the right looking along it.
##
## THE SIZE IS THE AIRCRAFT'S, NOT A TABLE. The downwind is as far out as two medium-bank turns with a base leg between
## them need at the kind's own downwind speed -- a turn radius is v^2 / (g tan bank) -- and never nearer than the
## handbook's middle, three quarters of a mile. A light aeroplane's circuit comes out at 0.75 NM and an airliner's
## at 1.5, and a retuned engine resizes both, because the speeds are multiples of the stall and cruise the simulation derives.
##
## WHAT WENT WRONG FIRST: a 3-degree path from pattern height is 5.8 km of final, which is no pattern at all. Real pilots
## come down through the downwind and base at 500 to 1,000 fpm, which is steeper than the final; so the height here holds
## level to abeam the threshold, then falls straight down the remaining path to the 300 ft final join, then follows
## 3 degrees ([AFH] 8 and 9).

## Pattern height over the field for propeller aircraft, and for large or turbine aircraft: 1,000 and 1,500 ft ([AIM]
## 4-3-3 a).
const HEIGHT_LIGHT: float = 304.8
const HEIGHT_LARGE: float = 457.2
## "Large aircraft" is 14 CFR 1.1's: more than 12,500 lb maximum take-off weight. This game has no engine type in its
## tables, and every turbine kind it flies is heavier than this.
const LARGE_MASS: float = 5670.0
## A MEDIUM BANK in the circuit ([AFH] 8: "a medium-bank turn onto the base leg"): 30 to 45 degrees, the handbook's
## medium band, and never past the kind's own autopilot limit. Within it, as much as it takes to fly the downwind at
## `OFFSET_WANTED`, because in this game a bank buys less turn than it would in the air.
const BANK: float = deg_to_rad(30.0)
const BANK_MOST: float = deg_to_rad(45.0)
## Half a nautical mile, the near edge of the handbook's downwind: "approximately 1/2 to 1 mile out" ([AFH] 8); and the
## middle of that band, which a circuit is sized for when its bank allows.
const HALF_MILE: float = 926.0
const OFFSET_WANTED: float = 1389.0
## Turn radii the downwind stands off: the base turn, the final turn, and half a radius of straight base between them.
const OFFSET_RADII: float = 2.5
## Speeds as multiples of the stall: the downwind no faster than 1.6 (the handbook's 70-90 kt on a 172 that stalls at
## 48), base 1.4 VSO, final 1.3 VSO ([AFH] 9) plus a margin, because the mixer allows no climb at all at 1.3 x the
## stall (`AircraftMixer::slow_margin`) and a final that cannot climb cannot correct a low path.
const DOWNWIND_STALLS: float = 1.6
const BASE_STALLS: float = 1.4
const FINAL_STALLS: float = 1.35
## The glide path and where it aims: 3 degrees ([AFH] 9), at the island strip's PAPI, 300 m in.
const GLIDE: float = deg_to_rad(3.0)
const AIM_IN: float = 300.0
## The stabilised gate and the final join: 300 ft ([AFH] 9, "an immediate go-around ... below 300 ft AGL").
const GATE: float = 91.44
## ABOUT A THOUSAND FEET OF STRAIGHT FINAL before the join, so an aeroplane that rolls out of its final turn a little wide has
## room to settle onto the centreline before the 300 ft gate. With the turn ending AT the join, the surface Cessna -- whose
## circuit is sized on a full-rate turn -- rolled out 35 m wide and reached the gate 24 m off, over the 22.5 allowed,
## still converging on its carrot (lane/cessnafm). A quarter mile made the typed Cessna's descent 484 fpm, under the
## handbook's 500.
const FINAL_STRAIGHT: float = 300.0
## The departure climbs to at least half a mile past the far end ([AIM] 4-3-2, [AC] appendix A).
const DEPARTURE_PAST: float = 926.0
## The 45-degree entry starts this far out along its own line from the mid-field point it aims at: two turn radii, so
## the turn onto downwind is flown off the entry rather than cut.
const ENTRY_RADII: float = 3.0
## The far-side teardrop ([AFH] 8, figure 8-3A): cross 500 ft above and go about 2 miles out before coming back.
const TEARDROP_ABOVE: float = 152.4
const TEARDROP_OUT: float = 3704.0
## A straight-in: within this of the extended centreline, seen from the aim point, and its track this near the
## runway's, and at least this far out so it has room to settle on the path.
const STRAIGHT_IN_CONE: float = deg_to_rad(30.0)
const STRAIGHT_IN_TRACK: float = deg_to_rad(45.0)
const STRAIGHT_IN_FAR: float = 5000.0

var threshold := Vector3.ZERO
var far_end := Vector3.ZERO
var along := Vector3.FORWARD
var across := Vector3.RIGHT
var side: float = -1.0
var length: float = 900.0
var width: float = 45.0
var field: float = 0.0
var height: float = HEIGHT_LIGHT
var offset: float = HALF_MILE
var bank: float = BANK
var radius: float = 0.0
## HOW MUCH OF A COORDINATED TURN THIS KIND GETS FROM A BANK: its flown turn rate over g tan(bank) / v. Measured, not
## assumed, by whoever flies it (`AirportTraffic` gauges every turn): a steady turn under the autopilot, 2026-09-19,
## gave the Cessna 0.53, the light twin 0.60, the Hawkeye 0.63, the tanker 0.54 and the airliner 0.34, each the same at
## 20, 30 and 45 degrees. The lumped wing's sideslip and the mixer's slip loop take the rest; that is the flight model
## as it is, and the pattern is sized on the turn the aeroplane actually flies. 1 is the textbook.
var turn: float = 1.0
var downwind_speed: float = 55.0
var base_speed: float = 50.0
var final_speed: float = 48.0
var stall: float = 38.0


## THE PATTERN FOR `kind` ONTO `frame`'S RUNWAY, landing from the frame's threshold (`reversed` false) or from its far
## end, on the `side` given (-1 left, +1 right). `numbers` is what the kind flies on -- `stall`, `cruise`, `bank` (its
## autopilot's own limit), `mass`, and `turn` (see the variable; 1 if not given) -- so a test can hand it any
## aeroplane; `Airfield.numbers_of` asks the simulation.
static func make(frame: Dictionary, reversed: bool, pattern_side: float, numbers: Dictionary) -> TrafficPattern:
	var p := TrafficPattern.new()
	var a: Vector3 = frame["along"]
	p.along = -a if reversed else a
	p.threshold = frame["far_end"] if reversed else frame["threshold"]
	p.far_end = frame["threshold"] if reversed else frame["far_end"]
	p.across = Vector3(-p.along.z, 0.0, p.along.x)
	p.side = signf(pattern_side) if pattern_side != 0.0 else -1.0
	p.length = float(frame["length"])
	p.width = float(frame["width"])
	p.field = (frame["centre"] as Vector3).y
	p.stall = float(numbers["stall"])
	var cruise: float = float(numbers["cruise"])
	p.height = HEIGHT_LARGE if float(numbers.get("mass", 0.0)) > LARGE_MASS else HEIGHT_LIGHT
	p.downwind_speed = minf(cruise, p.stall * DOWNWIND_STALLS)
	p.base_speed = minf(p.downwind_speed, p.stall * BASE_STALLS)
	p.final_speed = minf(p.base_speed, p.stall * FINAL_STALLS)
	p.turn = clampf(float(numbers.get("turn", 1.0)), 0.05, 1.0)
	# THE BANK THAT FLIES THE WANTED DOWNWIND, held to the medium band and the kind's own limit.
	var most: float = minf(BANK_MOST, float(numbers.get("bank", BANK_MOST)))
	var wanted: float = atan(p.downwind_speed * p.downwind_speed
		/ (9.81 * p.turn * OFFSET_WANTED / OFFSET_RADII))
	p.bank = clampf(wanted, minf(BANK, most), most)
	p.radius = turn_radius(p.downwind_speed, p.bank) / p.turn
	# NEVER NEARER THAN THE WANTED THREE QUARTERS OF A MILE, where the medium band's steepest bank would allow it: the
	# surface Cessna turns at its bank's full rate and would have flown a half-mile downwind, and the island's airfields
	# choose each end's side for circuits a wanted downwind out -- the south shore strip's crossed 22 points of land.
	p.offset = maxf(OFFSET_WANTED, p.radius * OFFSET_RADII)
	return p


## v^2 / (g tan bank), metres: a coordinated turn's radius. The flown one is this over `turn`.
static func turn_radius(speed: float, bank_angle: float) -> float:
	return speed * speed / (9.81 * tan(bank_angle))


## ---- the points -------------------------------------------------------------------------------------------------

## Where the glide path meets the runway: `AIM_IN` past the threshold.
func aim_point() -> Vector3:
	return threshold + along * AIM_IN


## How far before the aim point the final is joined: where 3 degrees stands at the gate.
func final_length() -> float:
	return GATE / tan(GLIDE)


## A point `ahead` metres past the threshold along the runway's line (negative is out on the approach) and `out`
## metres to the pattern side, at the field's height.
func point(ahead: float, out: float) -> Vector3:
	return threshold + along * ahead + across * (side * out)


## Where the final is joined, on the extended centreline.
func final_join() -> Vector3:
	return point(AIM_IN - final_length(), 0.0)


## Downwind abeam the threshold: where the descent starts ([AC] 11.4).
func abeam_threshold() -> Vector3:
	return point(0.0, offset)


## Downwind abeam mid-field: where the 45-degree entry joins ([AC] 11.3).
func abeam_midfield() -> Vector3:
	return point(length * 0.5, offset)


## HOW FAR PAST THE THRESHOLD'S LINE THE BASE LEG LIES (negative: out on the approach): one turn radius beyond the final
## join, so the turn onto final ends ON the centreline at the join and the aeroplane is lined up by the 300 ft gate
## ([AFH] 9) rather than still turning through it. With the base leg at the join itself, the first Cessna reached the
## gate 320 m off the centreline, mid-turn, at 5.6 degrees.
func base_ahead() -> float:
	return AIM_IN - final_length() - radius - FINAL_STRAIGHT


## Where the base leg starts: on the downwind, level with `base_ahead`.
func base_turn() -> Vector3:
	return point(base_ahead(), offset)


## Where a departure may turn: half a mile past the far end, on the centreline.
func departure_turn() -> Vector3:
	return point(length + DEPARTURE_PAST, 0.0)


## Where a 45-degree entry starts: on a line at 45 degrees to the downwind that meets it at `abeam_midfield`. The
## downwind is flown toward -along, so the entry comes from further along and further out: its track is -along turned
## 45 degrees in toward the runway.
func entry_start() -> Vector3:
	return abeam_midfield() + (along + across * side).normalized() * (radius * ENTRY_RADII)


## The landing direction as a compass heading (0 along -Z, increasing to the right: every mixer's convention).
func heading() -> float:
	return atan2(along.x, -along.z)


## ---- where an aircraft is, relative to it -------------------------------------------------------------------------

## Metres past the threshold along the runway's line, and metres out to the PATTERN side (negative is the other side).
func ahead_of(at: Vector3) -> float:
	return (at - threshold).dot(along)


func out_of(at: Vector3) -> float:
	return (at - threshold).dot(across) * side


## HOW AN ARRIVAL AT `at` MOVING `velocity` COMES IN: &"straight_in", &"forty_five" or &"teardrop".
##
## Straight in when it is out on the approach side, inside `STRAIGHT_IN_CONE` of the extended centreline as seen from
## the aim point, at least `STRAIGHT_IN_FAR` out, and already tracking within `STRAIGHT_IN_TRACK` of the runway: the
## aircraft the user described as "already on final from a long distance away". Otherwise the 45 on the pattern side,
## and the teardrop from the other.
func entry_for(at: Vector3, velocity: Vector3) -> StringName:
	var rel: Vector3 = at - aim_point()
	rel.y = 0.0
	var out_on_approach: float = -rel.dot(along)
	var flat_v := Vector3(velocity.x, 0.0, velocity.z)
	if out_on_approach >= STRAIGHT_IN_FAR and absf(atan2(rel.dot(across), out_on_approach)) <= STRAIGHT_IN_CONE \
			and flat_v.length() > 1.0 and flat_v.normalized().dot(along) >= cos(STRAIGHT_IN_TRACK):
		return &"straight_in"
	return &"forty_five" if out_of(at) >= 0.0 else &"teardrop"


## ---- how high ---------------------------------------------------------------------------------------------------

## THE PATH LENGTH STILL TO FLY FROM `at` TO THE AIM POINT, if it is on downwind, base or final (legs by name): the
## straight lines between the pattern's corners, which is what the descent is spread along. `base_at` is where the base
## leg lies, metres past the threshold's line (`base_ahead` unless the downwind was EXTENDED for spacing, when it is
## wherever the turn was begun): the final then starts further out, and the path is longer by as much.
func path_to_touchdown(leg: StringName, at: Vector3, base_at: float = NAN) -> float:
	var base_line: float = base_ahead() if is_nan(base_at) else base_at
	var final_run: float = AIM_IN - base_line
	var base_run: float = offset
	match leg:
		&"final":
			return maxf(AIM_IN - ahead_of(at), 0.0)
		&"base":
			return maxf(out_of(at), 0.0) + final_run
		_:
			# Downwind is flown toward -along, from wherever it is to the base turn.
			return maxf(ahead_of(at) - base_line, 0.0) + base_run + final_run


## THE HEIGHT TO BE AT on `leg` at `at`, metres of world y: level at pattern height until abeam the threshold, then
## straight down the remaining path to the gate at the final join, then 3 degrees to the aim point. `base_at` as for
## `path_to_touchdown`; the descent is spread over the circuit as planned, so an extended one comes down no steeper.
func height_at(leg: StringName, at: Vector3, base_at: float = NAN) -> float:
	var still: float = path_to_touchdown(leg, at, base_at)
	var join: float = final_length()
	if still <= join:
		return field + still * tan(GLIDE)
	var from_abeam: float = path_to_touchdown(&"downwind", abeam_threshold(), base_at)
	if still >= from_abeam:
		return field + height
	var share: float = (still - join) / maxf(from_abeam - join, 1.0)
	return field + GATE + (height - GATE) * share


## The speed wanted on a leg.
func speed_on(leg: StringName) -> float:
	match leg:
		&"final":
			return final_speed
		&"base":
			return base_speed
		_:
			return downwind_speed
