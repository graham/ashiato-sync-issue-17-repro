extends RefCounted
class_name SignalZones
## WHERE A HAND HAS TO BE, and the one piece of arithmetic this whole position rests on.
##
## A marshalling signal is not a gesture to be recognised. It is a PATH THROUGH PLACES: the
## hand is above the shoulder, or straight out at ninety degrees, or crossed over the head,
## and a signal is the order those places are visited in. That is deliberate and it is the
## same decision `VehicleControl` already made about a lever -- a hand takes hold of whatever
## is within `REACH` of the grip, and nothing anywhere asks what shape the hand is in.
##
## The gain is that every part of it can be looked at. A zone can be drawn, so a player can
## be SHOWN where to put their hands. A signal can be walked by a test with no headset and no
## input. And a near miss is a near miss for a reason you can name -- "the left hand was
## nowhere" -- rather than a number from a classifier that was 0.61 when it wanted 0.7.
##
## ---------------------------------------------------------------------------------
## IN BODY UNITS, NOT IN METRES
## ---------------------------------------------------------------------------------
##
## Everything here is expressed in REACHES: one reach is the distance from the middle of the
## shoulders to the controller with the arm straight out sideways. A zone at x = 0.98 is
## "arm straight out", for a player of any size, and the same table fits somebody of 1.5 m
## and somebody of 2.0 m. Metres cannot do that: "hands at 1.6 m" is overhead for one player
## and chest height for another, and the second one can never make the signal at all.
##
## The table is authored for the RIGHT hand and mirrored in x for the left, because the two
## are mirror images of each other in every signal in the book -- including the ones where
## the hands cross, which is why `crossed` has a NEGATIVE x and ends up over the other
## shoulder.

## Hands, in the order `PilotRig` reads them. Not an enum: the rig indexes 0 and 1 and this
## has to be the same two numbers.
const LEFT: int = 0
const RIGHT: int = 1

## A hand that is not in any zone at all. Most frames are this one.
const NOWHERE: StringName = &""

## SHOULDERS TO HAND, ARM STRAIGHT OUT. The unit everything below is in.
##
## 0.78 m is a 1.75 m adult, and it is only ever the fallback: `SignalReader.calibrate`
## measures the player's own and keeps it, because the whole point of body units is that a
## short player and a tall one make the same signal.
const NOMINAL_REACH: float = 0.78

## HEAD DOWN TO THE MIDDLE OF THE SHOULDERS. The body frame's origin is the tracked head
## dropped by this, which is the closest thing to a torso a rig with two controllers and a
## headset has.
const NECK: float = 0.22

## AND THE FLOOR TO THE SHOULDERS, for the one zone that is measured from the DECK.
##
## `deck` is where the catapult officer's hand goes, and it is the only zone that is not
## about the body: it is a real place, on the real deck, and reaching it means genuinely
## crouching down to it. Written in shoulder-relative units it could never be touched at
## all -- crouch and the zone comes down with you, staying exactly as far below your
## shoulders as it always was, which is a target that recedes for ever. So a zone may say
## `floor`, and then its height is above the DECK and the crouch is the whole point.
const NOMINAL_SHOULDER: float = 1.45

## HOW MUCH ROOM THERE IS TO BE WRONG, as one multiplier on every zone's radius.
##
## ONE NUMBER FOR ALL OF THEM, and that is what makes it safe to turn up. `zone_at` picks
## the nearest zone by the RATIO of distance to radius, so scaling every radius by the same
## factor leaves every comparison BETWEEN two zones exactly where it was. What widens is
## only how far out a hand still counts as being in a zone at all -- which is precisely the
## thing a player is asking about when they say a signal is fiddly.
##
## Turned up from 1.0 after the deck was played in a headset. The zones are generous on
## paper and a good deal less generous when you are also walking, watching a wingtip and
## trying to remember which arm goes out. A signal is a big movement made to somebody thirty
## metres away; it was never meant to be a precision task.
const SLACK: float = 1.3

## EVERY PLACE A HAND CAN BE, in reaches, for the RIGHT hand.
##
## `at` is x out to the hand's own side, y up from the middle of the shoulders, z FORWARD --
## note that this is the opposite sign to Godot's -Z, and it is converted in `place`. Reading
## a table of body positions where "in front of you" is negative is how a zone ends up behind
## somebody's back.
##
## `r` is how big the zone is, also in reaches: about 0.23 m at a nominal reach, which is
## roughly what `VehicleControl.REACH` allows a hand round a lever. Generous on purpose. A
## signal is a big arm movement made across a windy deck to somebody thirty metres away, and
## a player asked to hit a five-centimetre target with a controller is a player watching
## their own hands instead of the aeroplane.
const ZONES: Dictionary = {
	&"side": {"at": Vector3(0.32, -0.90, 0.02), "r": 0.30,
		"says": "arm at your side"},
	&"down45": {"at": Vector3(0.68, -0.60, 0.10), "r": 0.28,
		"says": "arm out and down at 45"},
	&"waist": {"at": Vector3(0.30, -0.54, 0.44), "r": 0.26,
		"says": "in front, waist height"},
	&"knee": {"at": Vector3(0.34, -1.02, 0.40), "r": 0.28,
		"says": "down at your knee"},
	&"chest": {"at": Vector3(0.26, -0.12, 0.46), "r": 0.26,
		"says": "in front of your chest"},
	&"head": {"at": Vector3(0.42, 0.34, 0.30), "r": 0.26,
		"says": "up beside your head"},
	&"overhead": {"at": Vector3(0.24, 0.92, 0.04), "r": 0.30,
		"says": "straight up above you"},
	&"out90": {"at": Vector3(0.98, 0.02, 0.04), "r": 0.30,
		"says": "straight out to the side"},
	&"forward": {"at": Vector3(0.20, 0.00, 0.96), "r": 0.30,
		"says": "straight out in front"},
	&"brow": {"at": Vector3(0.04, 0.46, 0.12), "r": 0.20,
		"says": "at your brow"},
	&"across": {"at": Vector3(-0.42, 0.16, 0.28), "r": 0.24,
		"says": "at your other shoulder"},
	&"crossed": {"at": Vector3(-0.22, 0.80, 0.12), "r": 0.26,
		"says": "crossed above your head"},
	&"deck": {"at": Vector3(0.34, 0.15, 0.50), "r": 0.30, "floor": true,
		"says": "down on the deck -- crouch to it"},
}


## WHERE THAT ZONE IS FOR THAT HAND, in the body frame, in metres.
##
## The left hand is the right hand's table mirrored in x, and z is negated because the table
## reads forward-positive and Godot's forward is -Z.
static func place(zone: StringName, hand: int, reach: float = NOMINAL_REACH,
		shoulder: float = NOMINAL_SHOULDER) -> Vector3:
	var row: Dictionary = ZONES.get(zone, {})
	if row.is_empty():
		return Vector3.ZERO
	var at: Vector3 = row["at"]
	var up: float = at.y * reach
	if bool(row.get("floor", false)):
		up = at.y * reach - shoulder
	return Vector3(at.x * (1.0 if hand == RIGHT else -1.0) * reach, up, -at.z * reach)


static func radius(zone: StringName, reach: float = NOMINAL_REACH) -> float:
	return core(zone, reach) * SLACK


## THE SAME ZONE WITHOUT THE SLACK, which is what anything measuring a MOVEMENT inside a
## zone has to use.
##
## `SLACK` says how forgiving a target is about being hit. It has nothing to say about how
## big a circle drawn inside that target has to be, and letting it -- which is what happened
## first -- makes turning up the forgiveness turn UP the size of the circle the run-up signal
## demands. Forgiveness that makes a signal harder is not forgiveness.
static func core(zone: StringName, reach: float = NOMINAL_REACH) -> float:
	var row: Dictionary = ZONES.get(zone, {})
	return (float(row["r"]) * reach) if not row.is_empty() else 0.0


## WHICH ZONE THIS HAND IS IN, or NOWHERE.
##
## Nearest by a RATIO rather than by distance, so a small zone next to a big one still wins
## inside itself. `brow` is deliberately tighter than everything round it -- a salute is a
## precise thing and a hand vaguely near the head is not one -- and by plain distance the
## roomy `head` beside it would have swallowed it.
##
## `local` is in the body frame: see `SignalReader`, which is the node that holds it.
static func zone_at(local: Vector3, hand: int, reach: float = NOMINAL_REACH,
		shoulder: float = NOMINAL_SHOULDER) -> StringName:
	var best: StringName = NOWHERE
	var closest: float = 1.0
	for zone in ZONES:
		var span: float = radius(zone, reach)
		if span <= 0.0:
			continue
		var ratio: float = local.distance_to(place(zone, hand, reach, shoulder)) / span
		if ratio < closest:
			closest = ratio
			best = zone
	return best


## Every zone name, in the order the table lists them. For the ghosts and for the tests.
static func names() -> Array:
	return ZONES.keys()


## What to tell a player who has to put a hand there.
static func says(zone: StringName) -> String:
	return String((ZONES.get(zone, {}) as Dictionary).get("says", "nowhere"))
