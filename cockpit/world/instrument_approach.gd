extends RefCounted
class_name InstrumentApproach
## AN INSTRUMENT APPROACH TO ONE RUNWAY END, for a large or fast aeroplane: vectors to a long final, the glideslope met
## from below at the final approach fix, and few, gentle turns. Pure geometry, like `TrafficPattern`, whose runway end,
## speeds and final it shares; it steers nothing.
##
## The user, 2026-09-19: "make sure large planes use something more similar to a IFR approach which requires far less
## turning and supports the large turning radius of a large plane." `research/traffic_pattern.md` section 9 has the
## sources, every one cited by paragraph:
## - [AIM] 5-4-3 and 5-4-5: vectors to the final approach course, and the glide slope met at its intercept altitude,
##   which is the final approach fix;
## - [7110.65] 5-9-1: intercept at least 2 miles outside the approach gate, at no more than 30 degrees;
## - [P/CG] "approach gate": 1 mile outside the FAF, and no closer than 5 miles from the threshold;
## - [IPH] chapter 4: the intermediate segment aligned within 30 degrees; a 3-degree path is 300 ft to the mile;
## - [IFH]: a standard-rate turn is 3 degrees a second.
##
## WHO FLIES IT: every kind over 14 CFR 1.1's 12,500 lb, the same line that gives them a 1,500 ft pattern. By the shape
## table that is the airliner, the transports (gunship, tanker, Mercury), the Hawkeye and the jets (fighter, Tomcat,
## Falcon, Prowler); the Cessna, the light twin, the Savoia and the glider fly the VFR pattern.
##
## THE TURNS ARE SIZED ON WHAT THE AEROPLANE FLIES. A bank buys this game's aeroplanes only part of a coordinated turn
## (0.34 for the airliner, 0.63 for the Hawkeye: `TrafficPattern.turn`), so the radius every vector is laid out with is
## the flown one, at the bank chosen here: no more than `BANK_MOST`, no more than the kind's own limit, and never more
## than flies a standard-rate turn.

const NM: float = 1852.0
## The final approach fix, where the glideslope is met: 5 NM from the threshold, its height the 3-degree path's there
## (about 1,640 ft, inside the 1,500 to 3,000 ft the ILS intercept is usually published at).
const FAF_OUT: float = 5.0 * NM
## The approach gate ([P/CG]): a mile outside the FAF, and never nearer than 5 NM to the threshold.
const GATE_PAST_FAF: float = 1.0 * NM
const GATE_NEAREST: float = 5.0 * NM
## Established on the final course at least 2 miles outside the gate ([7110.65] 5-9-1 a), on an intercept of no more
## than 30 degrees (TBL 5-9-1).
const OUTSIDE_THE_GATE: float = 2.0 * NM
const INTERCEPT: float = deg_to_rad(30.0)
## Gentle turns: no more than 25 degrees of bank, and never more than a standard rate of turn ([IFH]: 3 degrees a second).
const BANK_MOST: float = deg_to_rad(25.0)
const STANDARD_RATE: float = deg_to_rad(3.0)
## The legs of the vectors, in flown turn radii: the intercept leg, long enough to settle on after its 60-degree turn and
## before its 30-degree one; the base leg, long enough for a 90-degree turn onto it and a 60 off it; and how far out along
## the downwind the base is begun past the intercept leg's start.
const INTERCEPT_RADII: float = 2.0
const BASE_RADII: float = 2.5
## A straight-in wants this much room past the intercept, in turn radii, as well as the intercept itself.
const STRAIGHT_IN_ROOM_RADII: float = 2.0

var pattern: TrafficPattern = null
var bank: float = BANK_MOST
var radius: float = 0.0
var speed: float = 0.0


## THE APPROACH FOR THE AEROPLANE `pattern` WAS MADE FOR, on the same runway end, at the same flown turn.
static func make(pattern: TrafficPattern, numbers: Dictionary) -> InstrumentApproach:
	var a := InstrumentApproach.new()
	a.pattern = pattern
	a.speed = pattern.base_speed
	var most: float = minf(BANK_MOST, float(numbers.get("bank", BANK_MOST)))
	# LAID ON NO LESS THAN `AirportTraffic.TURN_UNKNOWN` OF A COORDINATED TURN, whatever the gauge says. The 747 gauged 0.28
	# on its departure turn, a 3.8 km flown radius at 25 degrees, and its vectors to 36 put the downwind 13.3 km east of the
	# runway -- 19.4 km out, past the island's warning at 17.3 and on its turn-back at 19.3 (airport_shot --scene=trip,
	# lane/airport 2026-09-19). A heavy that turns worse than it is laid for flies each corner wide and rejoins the next leg
	# by the carrot's pursuit. The turn a bank buys is the flight model's to mend (lane/pattern's finding).
	var turn: float = maxf(pattern.turn, AirportTraffic.TURN_UNKNOWN)
	# THE BANK THAT FLIES A STANDARD-RATE TURN, AS FLOWN: the flown rate is `turn` of g tan(bank) / v.
	var standard: float = atan(STANDARD_RATE * a.speed / (9.81 * turn))
	a.bank = minf(most, standard)
	a.radius = TrafficPattern.turn_radius(a.speed, a.bank) / turn
	return a


## WHETHER A KIND FLIES THIS rather than the VFR pattern: over 14 CFR 1.1's 12,500 lb.
static func flies_it(numbers: Dictionary) -> bool:
	return float(numbers.get("mass", 0.0)) > TrafficPattern.LARGE_MASS


## ---- the fixed points, in metres past the threshold's line (negative: out on the approach) ------------------------

func faf_out() -> float:
	return FAF_OUT


func gate_out() -> float:
	return maxf(FAF_OUT + GATE_PAST_FAF, GATE_NEAREST)


## WHERE IT IS ESTABLISHED on the final course: 2 miles outside the gate.
func established_out() -> float:
	return gate_out() + OUTSIDE_THE_GATE


## The glideslope's height at the FAF, above the field: level at this until the path comes down to meet it.
func intercept_height() -> float:
	return (FAF_OUT + TrafficPattern.AIM_IN) * tan(TrafficPattern.GLIDE)


## THE HEIGHT ON THE FINAL at `at`, world y: level at the intercept height, and down the 3-degree path from where it meets
## it -- met from below ([AIM] 5-4-5).
func final_height(at: Vector3) -> float:
	var to_aim: float = maxf(TrafficPattern.AIM_IN - pattern.ahead_of(at), 0.0)
	return pattern.field + minf(intercept_height(), to_aim * tan(TrafficPattern.GLIDE))


## A point `ahead` past the threshold's line and `right` metres to the right of the centreline looking along it, at the
## intercept height.
func point(ahead: float, right: float) -> Vector3:
	return pattern.threshold + pattern.along * ahead + pattern.across * right \
		+ Vector3.UP * (pattern.field + intercept_height() - pattern.threshold.y)


## Metres right of the centreline, looking along the landing direction.
func right_of(at: Vector3) -> float:
	return (at - pattern.threshold).dot(pattern.across)


## ---- the vectors --------------------------------------------------------------------------------------------------

## THE VECTORS FROM `at` MOVING `velocity` TO THE FINAL COURSE, as fixes to fly through in order; empty for a
## straight-in, which intercepts the final course directly. Every leg is long enough for the turns at its ends at this
## approach's flown radius, and every turn onto the final is 30 degrees.
##
## A straight-in when it is out beyond where it must be established, moving toward the runway, and far enough out that
## a 30-degree intercept from where it is meets the centreline before that point with room to settle. Otherwise the
## radar pattern a controller gives: a downwind outbound on the side it is on, a base leg in, and a 30-degree intercept
## to the final course at `established_out`, or further out if it is already beyond that.
func vectors_for(at: Vector3, velocity: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var ahead: float = pattern.ahead_of(at)
	var right: float = right_of(at)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var inbound: bool = flat.length() > 1.0 and flat.normalized().dot(pattern.along) > cos(deg_to_rad(90.0) - 0.01)
	var meets_at: float = ahead + absf(right) / tan(INTERCEPT) + radius * STRAIGHT_IN_ROOM_RADII
	if inbound and meets_at <= -established_out():
		return out
	var side: float = 1.0 if right >= 0.0 else -1.0
	var meet: float = minf(-established_out(), ahead - radius * STRAIGHT_IN_ROOM_RADII)
	var run: float = radius * INTERCEPT_RADII
	var j_ahead: float = meet - run * cos(INTERCEPT)
	var j_right: float = side * run * sin(INTERCEPT)
	var b_right: float = j_right + side * radius * BASE_RADII
	# DOWNWIND: from abeam where it is (never nearer the runway than a turn short of the far end), out to the base.
	var d_ahead: float = maxf(minf(ahead, pattern.length + radius), j_ahead + radius)
	out.append(point(d_ahead, b_right))
	out.append(point(j_ahead, b_right))
	out.append(point(j_ahead, j_right))
	out.append(point(meet, 0.0))
	return out
