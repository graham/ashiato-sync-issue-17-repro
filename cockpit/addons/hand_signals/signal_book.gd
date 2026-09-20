extends RefCounted
class_name SignalBook
## EVERY SIGNAL, AS DATA. One table, and the only place a movement is written down.
##
## The signals themselves are not invented here. They are the standard ones -- ICAO Annex 2,
## Appendix 1, which is what the marshaller at any airliner's nose is using, plus the deck
## signals a carrier launch runs on. So the descriptions in `says` are worth keeping accurate:
## a player who learns these has learned the real thing, which is most of the appeal of
## standing on the deck rather than sitting in the seat.
##
## ---------------------------------------------------------------------------------
## FOUR SHAPES OF SIGNAL, AND THE RATE IS PART OF THE MESSAGE
## ---------------------------------------------------------------------------------
##
##   HOLD    one pose, kept still for a moment          identify, hold position, tension
##   ONCE    poses in order, inside a time limit        stop, cut engines, salute
##   CYCLE   poses alternating, over and over           come ahead, turn, slow down
##   CIRCLE  a hand going round inside one zone         run up the engines
##
## CYCLE exists because half of marshalling is analogue: "the speed of the signal indicates
## the desired speed of aircraft movement" is in the standard itself. Beckon slowly and the
## aeroplane creeps; beckon hard and it comes. So a cycling signal carries a NUMBER, and the
## number is how fast you are waving.
##
## And the difference between a normal stop and an EMERGENCY stop is nothing but speed --
## the same arms, crossed over the same head. `not_before` and `within` are what tell them
## apart, which is exactly what tells them apart on a real apron.
##
## ---------------------------------------------------------------------------------
## HOW A STEP IS WRITTEN
## ---------------------------------------------------------------------------------
##
##   ["chest", "out90"]        left hand in `chest`, right hand in `out90`
##   ["*", "head+open"]        left hand ANYWHERE, right in `head` with an open hand
##   ["side|down45", "brow"]   left in EITHER of two zones
##
## The flags after `+` are the two things a controller knows about a hand that its position
## does not say: `open` or `fist` is the grip trigger, `up` or `down` is which way the palm
## is pointing. They are what make "raise your hand, then clench it" -- which is how brakes
## are set on every apron in the world -- a signal rather than an approximation of one.

enum Mode { HOLD, ONCE, CYCLE, CIRCLE }

## What the grip has to be doing. DONT_CARE on almost every step: a signal is made with the
## arms, and asking for a hand shape the player cannot see themselves make is unkind.
enum Grip { DONT_CARE, OPEN, FIST }
enum Palm { DONT_CARE, UP, DOWN }

## How long a cycling signal may go quiet before it counts as over. Longer than the slowest
## beckon anybody makes (a 0.4 Hz wave is 1.25 s a half-cycle) or the aeroplane stops every
## time the marshaller's arms pass through the middle.
const LAPSE: float = 1.4

## HOW LONG A TWO-POSE SIGNAL MAY TAKE, in seconds, where the SPEED IS NOT THE MESSAGE.
##
## Most signals are a pose and then another pose, and how quickly you get between them means
## nothing at all -- so the limit is only there to stop two unrelated poses minutes apart
## being read as one signal. It was between 1.2 and 2.5 seconds, which is ample sitting still
## and is not ample at all while walking backwards down a stand watching a wingtip, and the
## failure it produces is the worst kind: the player did the right thing and nothing happened.
##
## THE TWO STOPS ARE NOT THIS AND MUST NOT BECOME IT. A normal stop and an emergency stop are
## the same arms over the same head and NOTHING tells them apart but speed -- see the note at
## the top of this file -- so they keep their own numbers and their own reasons.
const UNHURRIED: float = 4.0

## THE BOOK.
##
## `mode`, `steps` and whichever of the timing fields that mode uses. `rate` is the cycles
## per second that map to nothing and to everything, for the signals that carry a number.
const SIGNALS: Dictionary = {
	&"identify": {
		"title": "Identify the stand",
		"says": "Both arms straight up above your head. This is your stand.",
		"mode": Mode.HOLD, "dwell": 0.7,
		"steps": [["overhead", "overhead"]],
	},
	&"hold_position": {
		"title": "Hold position",
		"says": "Both arms out and down at forty-five degrees. Stand by.",
		"mode": Mode.HOLD, "dwell": 0.7,
		"steps": [["down45", "down45"]],
	},
	&"come_ahead": {
		"title": "Come ahead",
		"says": "Both arms bent, hands beckoning from your chest to your head. "
			+ "The faster you wave, the faster it comes.",
		"mode": Mode.CYCLE, "cycles": 2, "rate": Vector2(0.4, 1.8),
		"steps": [["chest", "chest"], ["head", "head"]],
	},
	# TURN LEFT IS THE PILOT'S LEFT, and it is the RIGHT arm that goes out.
	#
	# You are facing the aircraft, so your right hand is on the pilot's left, and the
	# aeroplane turns towards the arm that is standing still. Getting this backwards is the
	# classic way to walk a wingtip into a jet bridge, which is why it is written down twice:
	# here, and in the level that reads it.
	&"turn_left": {
		"title": "Turn left",
		"says": "Right arm straight out and still. Beckon with your left hand.",
		"mode": Mode.CYCLE, "cycles": 2, "rate": Vector2(0.4, 1.8),
		"steps": [["chest", "out90"], ["head", "out90"]],
	},
	&"turn_right": {
		"title": "Turn right",
		"says": "Left arm straight out and still. Beckon with your right hand.",
		"mode": Mode.CYCLE, "cycles": 2, "rate": Vector2(0.4, 1.8),
		"steps": [["out90", "chest"], ["out90", "head"]],
	},
	&"slow_down": {
		"title": "Slow down",
		"says": "Both arms down, patting the air from your waist to your knees.",
		"mode": Mode.CYCLE, "cycles": 2, "rate": Vector2(0.4, 1.8),
		"steps": [["waist", "waist"], ["knee", "knee"]],
	},
	# PUSHED BACK, which is the recovery from an overshoot as well as a signal in its own
	# right. Without it a marshaller who stops an aeroplane two metres past the bar has no
	# way to fix it, and the accuracy the whole level is scored on becomes a thing you get
	# right or start again.
	&"move_back": {
		"title": "Move back",
		"says": "Both hands in front at your waist, rolling forwards, pushing her back.",
		"mode": Mode.CYCLE, "cycles": 2, "rate": Vector2(0.4, 1.8),
		"steps": [["waist", "waist"], ["chest", "chest"]],
	},
	&"normal_stop": {
		"title": "Stop",
		"says": "Arms straight out to the sides, then raised SLOWLY until they cross "
			+ "above your head.",
		"mode": Mode.ONCE, "not_before": 0.35, "within": 3.0,
		"steps": [["out90", "out90"], ["crossed", "crossed"]],
	},
	&"emergency_stop": {
		"title": "Emergency stop",
		"says": "Arms thrown up and crossed above your head, fast.",
		"mode": Mode.ONCE, "within": 0.5,
		"steps": [["side|down45|waist|chest", "side|down45|waist|chest"],
			["crossed", "crossed"]],
	},
	# THE OTHER ARM IS AT YOUR SIDE, and that is not decoration.
	#
	# Without it, `set_brakes` is "the right hand is beside the head with a closed fist",
	# which is a place the come-ahead beckon passes through twice a second. One squeeze of
	# the grip while waving an aeroplane in and its brakes go on. The standard has the free
	# arm down for exactly this reason -- a signal is meant to be unmistakable at thirty
	# metres -- and putting it in the table costs nothing.
	&"set_brakes": {
		"title": "Set brakes",
		"says": "Left arm at your side. Right hand up by your head, open, then clench it.",
		"mode": Mode.ONCE, "within": UNHURRIED,
		"steps": [["side|down45", "head+open"], ["side|down45", "head+fist"]],
	},
	&"release_brakes": {
		"title": "Release brakes",
		"says": "Left arm at your side. Right fist up by your head, then open it.",
		"mode": Mode.ONCE, "within": UNHURRIED,
		"steps": [["side|down45", "head+fist"], ["side|down45", "head+open"]],
	},
	&"chocks_in": {
		"title": "Chocks inserted",
		"says": "Both arms above your head, jabbing inwards until your hands cross.",
		"mode": Mode.CYCLE, "cycles": 2, "rate": Vector2(0.4, 1.8),
		"steps": [["overhead", "overhead"], ["crossed", "crossed"]],
	},
	&"cut_engines": {
		"title": "Cut engines",
		"says": "Right hand at your left shoulder, drawn across your throat.",
		"mode": Mode.ONCE, "within": UNHURRIED,
		"steps": [["*", "across"], ["*", "head"]],
	},
	&"all_clear": {
		"title": "All clear",
		"says": "Left arm at your side, right fist at your chest, thumb up.",
		"mode": Mode.HOLD, "dwell": 0.6,
		"steps": [["side|down45", "chest+fist+up"]],
	},
	&"spread_wings": {
		"title": "Spread wings",
		"says": "Both hands together at your chest, sweeping out to full stretch.",
		# NOT `UNHURRIED`, AND THIS IS THE EXCEPTION THAT PROVES WHY THERE IS A LIST.
		#
		# Chest, then arms straight out, is also the first half of what a marshaller's arms do
		# on the way to a normal stop -- which goes out90 then crossed. Give this four seconds
		# and every stop signal is read as "spread the wings" on the way past. The short
		# window IS what tells them apart, exactly as it is for the two stops.
		"mode": Mode.ONCE, "within": 1.6,
		"steps": [["chest", "chest"], ["out90", "out90"]],
	},
	&"take_tension": {
		"title": "Take tension",
		"says": "Left hand up and open -- off the brakes. Right arm straight at the bow.",
		"mode": Mode.HOLD, "dwell": 0.9,
		"steps": [["head+open", "forward"]],
	},
	&"run_up": {
		"title": "Run up engines",
		"says": "Right hand circling hard above your head.",
		"mode": Mode.CIRCLE, "hand": SignalZones.RIGHT, "zone": &"overhead",
		"turns": 2.0, "rate": Vector2(0.5, 2.0),
		"steps": [["*", "overhead"]],
	},
	&"salute": {
		"title": "Return the salute",
		"says": "Right hand to your brow, then away.",
		"mode": Mode.ONCE, "within": UNHURRIED,
		"steps": [["*", "brow"], ["*", "side|forward"]],
	},
	&"touch_deck": {
		"title": "Touch the deck",
		"says": "Crouch, touch the deck, then point at the bow. And she goes.",
		"mode": Mode.ONCE, "within": UNHURRIED,
		"steps": [["*", "deck"], ["*", "forward"]],
	},
}

## CHOCKS REMOVED IS NOT IN THE BOOK, and the reason is worth keeping.
##
## It is the same two poses as `chocks_in` in the other order -- jabbed outwards instead of
## inwards -- and a cycle between two zones is the same cycle whichever end you start at. A
## matcher can only tell them apart by which zone the hands ARRIVED in first, which means
## carrying an arming rule about where the hands came from through every signal in the book
## to disambiguate one that no level currently asks for.
##
## When a departure level wants it -- pushback needs chocks out, then brakes released -- the
## honest fix is an `anchor` field on the signal saying "arm only from outside these zones",
## applied to that pair alone. Not a general rule, because a general rule deadlocks a cycling
## signal whose player pauses halfway through it.

static var _parsed: Dictionary = {}


## THE BOOK, IN THE FORM THE READER WANTS: zone names resolved, flags split out.
##
## Parsed once and kept. The table above is written to be read by a person; this is written
## to be compared against a hand sixty times a second, and doing that string-splitting per
## frame would be the only expensive thing in the whole position.
static func book() -> Dictionary:
	if not _parsed.is_empty():
		return _parsed
	for id in SIGNALS:
		var row: Dictionary = SIGNALS[id]
		var steps: Array = []
		for step in (row["steps"] as Array):
			steps.append([_hand(String(step[0])), _hand(String(step[1]))])
		var out: Dictionary = row.duplicate()
		out["id"] = id
		out["steps"] = steps
		out["zones"] = _zones_of(steps)
		_parsed[id] = out
	return _parsed


static func of(id: StringName) -> Dictionary:
	return book().get(id, {})


static func title(id: StringName) -> String:
	return String((of(id) as Dictionary).get("title", String(id)))


static func says(id: StringName) -> String:
	return String((of(id) as Dictionary).get("says", ""))


## Every id, in the order the table lists them.
static func ids() -> Array:
	return book().keys()


## WHAT THIS SIGNAL IS WORTH, from how fast it is being made. 0 at the slow end of its rate
## band and 1 at the fast end; a signal that carries no number always answers 1.
static func strength(id: StringName, hertz: float) -> float:
	var band: Vector2 = (of(id) as Dictionary).get("rate", Vector2.ZERO)
	if band == Vector2.ZERO or band.y <= band.x:
		return 1.0
	return clampf((hertz - band.x) / (band.y - band.x), 0.0, 1.0)


## "chest", "*", "side|down45", "head+open", "chest+fist+up" -> what the reader compares.
static func _hand(spec: String) -> Dictionary:
	var grip: int = Grip.DONT_CARE
	var palm: int = Palm.DONT_CARE
	var parts: PackedStringArray = spec.split("+")
	for i in range(1, parts.size()):
		match parts[i]:
			"open": grip = Grip.OPEN
			"fist": grip = Grip.FIST
			"up": palm = Palm.UP
			"down": palm = Palm.DOWN
			_: push_error("[marshalling] unknown hand flag '%s' in '%s'" % [parts[i], spec])
	var zones: Array[StringName] = []
	if parts[0] != "*":
		for entry in parts[0].split("|"):
			var zone := StringName(entry)
			if not SignalZones.ZONES.has(zone):
				push_error("[marshalling] no such zone '%s' in '%s'" % [entry, spec])
			zones.append(zone)
	return {"zones": zones, "grip": grip, "palm": palm}


## Every zone this signal mentions, for the ghosts and for the ambiguity test.
static func _zones_of(steps: Array) -> Array[StringName]:
	var seen: Array[StringName] = []
	for step in steps:
		for hand in step:
			for zone in (hand["zones"] as Array[StringName]):
				if not seen.has(zone):
					seen.append(zone)
	return seen
