extends RefCounted
class_name WakeTuning
## EVERY NUMBER THE SHIPS' WAKES AND THE LOW-PASS SPRAY ARE DRAWN WITH, AND THE TWO RULES THAT SAY WHO GETS WHICH.
##
## Asked for on 2026-09-17: "boats/ships that are moving should have a noticeable wake ... churned water, lighter and
## white", and "planes that are within 3 meters of the water that are moving faster than 80kph [should] have a dramatic
## kick up of whitewater" -- a Porco Rosso seaplane throwing a rooster tail. Both are pictures only: nothing here is on
## the wire or touches a force. See `WakeYard` and `SprayYard`, and research/wakes.md for what real wakes look like and
## what was rejected.
##
## ONE KNOB, ONE NUMBER. The user tunes these from pictures, so each thing that can be said about the look -- "wider",
## "whiter", "lasts longer", "higher" -- is one constant here, and nothing downstream types a number beside it.
##
## THE RULES ARE BY WHERE A CRAFT IS, NOT BY WHAT IT IS CALLED. A craft wakes when the bottom of its hull is in the water
## and it is moving; it sprays when its lowest point is within `SPRAY_HEIGHT` of the water and it is going faster than
## `SPRAY_SPEED` -- whatever kind it is. So the tanker does both without being named (it floats on its hull, and it
## skims), and a new flying boat gets both for free. Measured from the hull box's corners and the wingtips, never from
## the origin, which on the carrier is 11.9 m above its keel.

## ---- who gets which ------------------------------------------------------------

## THE LOW-PASS RULE, as the user gave it: within 3 m of the water, faster than 80 km/h. One number each.
const SPRAY_HEIGHT: float = 3.0
const SPRAY_SPEED: float = 80.0 / 3.6
## HOW THE SPRAY GROWS PAST THE THRESHOLD, so it does not switch on like a lamp: full at this speed, and full when the
## lowest point is this close to the water (half strength at the edge of `SPRAY_HEIGHT`, none past it).
const SPRAY_SPEED_FULL: float = 45.0
## A BOAT'S ROOSTER TAIL, SIZED BY ITS HULL (lane/boats, 2026-09-18: "a fast boat should throw a visible rooster tail at
## its top speed"). A hull ON the water -- its lowest point within `WAKE_TOUCH` of the surface -- that is past
## `SPRAY_SPEED` sprays with the strength its LENGTH says, whatever its speed past the threshold: a hull this long throws
## the full wall (`SHEET_HEIGHT`), and a shorter one that share of it. A boat tops out at 25 m/s, where the aircraft's
## curve (full at `SPRAY_SPEED_FULL`) gave every hull the same 0.38 whatever its size. THE ONE KNOB for "the boats'
## spray higher": lower it. Aircraft, and a flying boat lifted clear of the water, keep their curve.
const HULL_SPRAY_FULL_LENGTH: float = 24.0
const SPRAY_CLOSE_FULL: float = 0.5

## A HULL IS IN THE WATER when its bottom is no higher than this above the surface: the chop and the heave put a floating
## hull's bottom a few centimetres either side of the still water under it.
const WAKE_TOUCH: float = 0.3
## ...and not under it altogether: a hull whose TOP is this far under the surface is a submarine at depth, which leaves no
## wake anybody can see.
const WAKE_DEEPEST_TOP: float = 1.5
## HOW A WAKE GROWS WITH SPEED, in metres a second over the water: nothing below `WAKE_SPEED_FROM`, which is a ship
## holding station in the swell, and full at `WAKE_SPEED_FULL`.
const WAKE_SPEED_FROM: float = 0.8
const WAKE_SPEED_FULL: float = 7.0
## A STREAK ON THE WATER UNDER ANYTHING THAT SPRAYS, as strong as this share of its spray: the white line a seaplane
## skimming the sea draws under itself. The same churn a hull leaves, from the same drawer.
const WAKE_SKIM_STREAK: float = 0.6
## A STREAK IS A SHORT FOAM SCAR, NOT A WAKE: it lasts this many seconds and is at least this many metres wide.
const WAKE_SKIM_LIFE: float = 1.2
const WAKE_SKIM_WIDTH: float = 3.0

## ---- the wake's look -----------------------------------------------------------

## HOW LONG A WAKE LASTS, seconds, as a share of the ship's length -- a carrier's lies on the sea for a mile and a launch's
## for a few boat-lengths -- between a floor and a ceiling.
const WAKE_LIFE_PER_METRE: float = 0.35
const WAKE_LIFE_LEAST: float = 14.0
const WAKE_LIFE_MOST: float = 110.0
## THE CHURNED WATER astern: white foam as wide as the hull at the stern, spreading this many metres a second each side,
## gone after this share of the wake's life. `WAKE_WHITENESS` is how opaque it is right at the stern, 0 to 1.
const WAKE_CHURN_SPREAD: float = 0.35
const WAKE_CHURN_SHARE: float = 0.7
const WAKE_WHITENESS: float = 0.9
## THE KELVIN WEDGE: the V of divergent waves at 19.47 degrees either side of the track, whatever the speed (Kelvin,
## 1887: arcsin(1/3)). `WAKE_ARM_STRENGTH` is how strongly its crests and troughs are drawn, 0 to 1, and
## `WAKE_ARM_WIDTH` how wide the band of them is, as a share of the wedge's half-width.
const WAKE_KELVIN_DEGREES: float = 19.47
const WAKE_ARM_STRENGTH: float = 0.3
const WAKE_ARM_WIDTH: float = 0.06
## The curved transverse waves inside the V, whose length is set by the speed (2 pi v^2 / g): faint.
const WAKE_TRANSVERSE_STRENGTH: float = 0.05
## THE BOW WAVE: white water piled at the stem and running aft along the sides, as strong as this at full speed.
const WAKE_BOW_STRENGTH: float = 0.9

## HOW OFTEN A PIECE OF WAKE IS LAID behind each ship, seconds. Between laying, the newest piece grows to the stern every
## frame, so the churn is always joined to the hull.
const WAKE_SAMPLE_EVERY: float = 0.5
## FURTHER THAN THIS FROM THE EYE, metres, a hull's newest piece and its bow wave are moved only when a piece is laid,
## not every frame: the half-second gap it leaves at the stern is a few metres at a distance where a hull is a few
## pixels. Every frame for every moving hull was 0.20 ms of the watch level's frame with twenty ships under way.
const WAKE_NEAR: float = 2000.0
## HOW OFTEN EVERY CRAFT IN THE SKY IS LOOKED AT, seconds, to find the ones that wake or spray; between looks each yard
## touches only those. Looking at all 101 vehicles of the watch level every frame cost 0.18 ms for the wakes and 0.17 ms
## for the spray -- GDScript's price for a dictionary walk -- whatever each look then did (2026-09-17).
const LOOK_EVERY: float = 0.1
## THE MOST PIECES ALIVE AT ONCE, for every ship in the sky: the drawer's size. A carrier at 15 m/s lays 220 in its
## 110 s; twenty ships of the watch level's mix need about 1,500.
const WAKE_SEGMENTS: int = 4096
## HOW HIGH THE WAKE IS DRAWN OVER THE WATER IT FOLLOWS, and how far it is pulled toward the eye, in metres, so it never
## fights the sea for the same depth. The sea under it is worked out by the same sums the sea is drawn with.
const WAKE_LIFT: float = 0.06
const WAKE_PULL: float = 0.35
## HOW FAR ALONG ITS TRACK A SHIP HAS GONE is kept modulo this many metres, so the crests' phase stays in float32's
## centimetres however far it sails: one seam in the pattern every four kilometres.
const WAKE_TRACK_WRAP: float = 4096.0

## ---- the spray's look ----------------------------------------------------------

## HOW HIGH THE ROOSTER TAIL IS THROWN, metres a second upward at full strength, and how far to the sides.
const SPRAY_RISE: float = 18.0
const SPRAY_FLING: float = 5.0
## How much of the aircraft's own speed the spray keeps as it leaves the water: a little, so it streams out behind.
const SPRAY_CARRY: float = 0.25
## HOW QUICKLY THE AIR TAKES A PUFF'S SPEED AWAY, per second. At 0.9 an 18 m/s throw topped out at about 4 m, which is a
## splash; at 0.35 it reaches about 7 m, which is a rooster tail.
const SPRAY_DRAG: float = 0.35
## How big a puff is when it is thrown and when it falls back, in metres across, and how white, 0 to 1.
const SPRAY_SIZE_FROM: float = 0.35
const SPRAY_SIZE_TO: float = 4.0
const SPRAY_WHITENESS: float = 0.85
## HOW MUCH A YOUNG PUFF IS DRAWN OUT ALONG ITS FLIGHT, seconds of its speed: the jets of a rooster tail, not balls.
const SPRAY_STREAK: float = 0.22
## HOW MANY PUFFS A SECOND one aircraft throws at full strength, and the drawer's size for every aircraft at once. Many and
## small, so they overlap into a sheet: 140 a second of puffs up to 5.5 m read as separate cotton balls (pictures 05, 06).
## SINCE THE WALL (round 2, 2026-09-18) the puffs are only the splash at the hull and a few drops over the wall's top: at
## 420 a second their speckled jets drew a grey fuzz along the wall's crisp edge and dotted arcs over it from behind.
const SPRAY_PER_SECOND: float = 160.0
## WHICH SORT OF PUFF, as shares: JETS thrown high (drops over the wall), MIST (large and faint); the rest are SHEETS
## thrown low and out to the sides, the splash at the hull.
const SPRAY_JET_SHARE: float = 0.2
const SPRAY_MIST_SHARE: float = 0.05
const SPRAY_PUFFS: int = 6144
## The most seconds a puff can be in the air, whatever it was thrown with.
const SPRAY_LIFE_MOST: float = 3.0


## ---- the wall of spray behind a fast skimmer (round 2, 2026-09-18) ------------------

## Asked for on 2026-09-18 with a Porco Rosso still for the look: behind a seaplane skimming fast, ONE SOLID CURTAIN of
## white spray several times its height, flat and bright on its face, crisp and billowing along its top in cartoon-cloud
## lobes, pale blue at its base and under each lobe. A shaped sheet (SprayYard's "Sheets", spray_sheet.gdshader), not
## particles and not a mist. The puffs above stay for the splash at the hull only.

## HOW HIGH THE WALL RISES, metres, at full strength: the Savoia stands about 3.5 m, and the still shows a wall several
## times that. It rises to its height over about `SHEET_RISE` seconds (a time constant), so it fans up from the hull.
## "THE SPLASH SIZE IS A LITTLE HIGH, MAKE IT A BIT SMALLER" (the user, 2026-09-18): 11 m where it was 15, the Savoia's
## wall about three times its own height rather than four. A boat's is its share of this (`HULL_SPRAY_FULL_LENGTH`).
const SHEET_HEIGHT: float = 11.0
const SHEET_RISE: float = 0.25
## HOW LONG A PIECE OF WALL STANDS, seconds: at 45 m/s, 1.6 s is a wall 70 m long. In its last `SHEET_DISSOLVE` share it
## is eaten into holes and shrinking lobes, not faded: a cel sheet goes by its edges, never by turning grey.
const SHEET_LIFE: float = 1.6
const SHEET_DISSOLVE: float = 0.45
## HOW WIDE THE WALL OPENS, metres from the track to its top on each side, at full strength, and how many metres a second
## it goes on opening as it stands. The wall is a V across the track: a face to see from the side, two from behind.
const SHEET_WIDTH: float = 3.0
const SHEET_SPREAD: float = 2.5
## THE BILLOWS ALONG THE TOP EDGE: how long one lobe is along the track, in metres, at full height, and how much the lobes
## swell as they stand, per second. `SHEET_CRISP` is how many metres the edge takes to go from sheet to air: small is a
## drawn line, large is soft.
const SHEET_LOBE: float = 4.0
const SHEET_BILLOW: float = 0.5
const SHEET_CRISP: float = 0.04
## HOW RAGGED: the share of the upper wall eaten into small holes, 0 to 1.
const SHEET_HOLES: float = 0.18
## THE COLOURS: the lit face, near white; and the shade at its base, under each lobe and on a face turned from the sun,
## pale blue-grey as the still has it. Both are multiplied by the time of day's light (ContrailYard.light_at).
const SHEET_FACE: Color = Color(0.97, 0.98, 1.0)
const SHEET_SHADOW: Color = Color(0.60, 0.76, 0.87)
## HOW HIGH THE SHADED BASE REACHES, as a share of the wall's height; and how thick the shaded crescent under each lobe
## is, as a share of the lobe's radius (0 is none, 0.5 is half the lobe in shade).
const SHEET_BASE: float = 0.28
const SHEET_LOBE_SHADE: float = 0.4
## THE THIN WHITE LINE WHERE THE WALL MEETS THE WATER at the hull, 0 to 1, and how many metres tall it is.
const SHEET_CONTACT: float = 1.0
const SHEET_CONTACT_HEIGHT: float = 0.45
## HOW OFTEN A PIECE OF WALL IS LAID, seconds: at 45 m/s a piece is 2.3 m of track. Between laying, the newest piece
## reaches to the hull every frame, so the wall is always joined to it. And the drawer's size for every skimmer at once.
const SHEET_EVERY: float = 0.05
## THE WIDEST THE KEEL LINE IS, metres from the track each side: the hull, but never a carrier's flight deck.
const SHEET_HULL_HALF: float = 1.2
## HOW QUICKLY THE WALL GROWS TO A CRAFT'S STRENGTH, seconds from nothing to full: a run of spray starts as a ramp, not
## as a cliff (the first pictures ended the wall in a vertical edge where the craft began to spray).
const SHEET_RAMP: float = 0.35
const SHEET_PIECES: int = 2048

## ---- the rules ---------------------------------------------------------------------

## THE LOW POINTS OF A KIND, in its drawn body's frame: the four bottom corners of its hull box, and its wingtips if it has
## wings. Whichever is lowest after the craft's attitude is where it is nearest the water -- a bank puts a wingtip there.
static func low_points(kind: int, geometry: Dictionary) -> Array[Vector3]:
	var half: Vector3 = geometry.get("extents", Vector3.ONE) as Vector3
	var points: Array[Vector3] = [Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z),
		Vector3(-half.x, -half.y, half.z), Vector3(half.x, -half.y, half.z)]
	points.append_array(wingtips(kind, geometry))
	return points


## A KIND'S WINGTIPS FOR THE SPRAY RULE, in its drawn body's frame, with no view to measure: the tips its airframe
## publishes, or else the span the flight model flies with, at the height the old plank wing stood.
##
## THIS USED TO BE `VehicleLights.wingtips`, and `lane/beacons` removed it on 2026-09-17 on the same day this yard
## called it: lights are now measured off the drawn skin, which needs a view, and a rule decided per kind has none.
## The two branches merged without a textual conflict and main stopped parsing ("Static function wingtips() not found
## in base VehicleLights"). The span estimate is kept HERE, for a threshold of 3 m, not for anything drawn: a wingtip
## the flight model puts half a metre from the drawn one moves where spray starts by half a metre in a bank.
static func wingtips(kind: int, geometry: Dictionary) -> Array[Vector3]:
	var published: Array[Vector3] = VehicleLights.published_wingtips(kind, geometry)
	if not published.is_empty() or not VehicleLights.has_a_wing(kind):
		return published
	var half: Vector3 = geometry.get("extents", Vector3.ONE) as Vector3
	var span: float = float(geometry.get("span", 0.0))
	var high: bool = VehicleCatalogue.body(kind) == VehicleCatalogue.Body.HIGH_WING
	var wing := Vector3(0.0, half.y * (1.05 if high else -0.35), half.z * 0.1)
	return [wing + Vector3(-(span + 0.15), 0.0, 0.0), wing + Vector3(span + 0.15, 0.0, 0.0)]


## HOW STRONGLY AN AIRCRAFT SPRAYS, 0 to 1, from how far its lowest point is above the water and how fast it is going.
## Zero at or past `SPRAY_HEIGHT` or at or below `SPRAY_SPEED`; growing with speed to `SPRAY_SPEED_FULL` and with
## closeness to `SPRAY_CLOSE_FULL`. Below the water altogether is a hull on it, which sprays at its fullest.
static func spray_strength(clearance: float, speed: float) -> float:
	if clearance >= SPRAY_HEIGHT or not fast_enough_to_spray(speed):
		return 0.0
	var close: float = 1.0 - smoothstep(SPRAY_CLOSE_FULL, SPRAY_HEIGHT, clearance) * 0.5
	if clearance > SPRAY_HEIGHT * 0.8:
		# THE LAST FIFTH FADES TO NOTHING, so crossing 3 m does not switch the spray off in one frame.
		close *= 1.0 - smoothstep(SPRAY_HEIGHT * 0.8, SPRAY_HEIGHT, clearance)
	var fast: float = 0.35 + 0.65 * smoothstep(SPRAY_SPEED, SPRAY_SPEED_FULL, speed)
	return clampf(close * fast, 0.0, 1.0)


## HOW STRONGLY A CRAFT SPRAYS, knowing how long its hull is: a hull on the water past the threshold by its length (see
## `HULL_SPRAY_FULL_LENGTH`), anything clear of it by `spray_strength`. The threshold is the same for both.
static func hull_spray_strength(clearance: float, speed: float, hull_length: float) -> float:
	if clearance > WAKE_TOUCH:
		return spray_strength(clearance, speed)
	if not fast_enough_to_spray(speed):
		return 0.0
	return clampf(hull_length / HULL_SPRAY_FULL_LENGTH, 0.05, 1.0)


## WHETHER A CRAFT IS GOING FAST ENOUGH TO SPRAY AT ALL: the one place the speed half of the rule is asked, by
## `spray_strength` and by `SprayYard` before it measures a craft's height.
static func fast_enough_to_spray(speed: float) -> bool:
	return speed > SPRAY_SPEED


## HOW STRONGLY A HULL WAKES, 0 to 1, from where its bottom and top are against the water and its speed over it.
## A hull skimming the water fast enough to spray leaves a streak too, as `WAKE_SKIM_STREAK` of its spray.
static func wake_strength(bottom_clearance: float, top_clearance: float, speed: float) -> float:
	if top_clearance < -WAKE_DEEPEST_TOP:
		return 0.0
	var skimming: float = spray_strength(bottom_clearance, speed) * WAKE_SKIM_STREAK
	if bottom_clearance > WAKE_TOUCH:
		return skimming
	return maxf(smoothstep(WAKE_SPEED_FROM, WAKE_SPEED_FULL, speed), skimming)


## HOW LONG A SHIP'S WAKE LASTS, seconds, from its length in metres.
static func wake_life(length: float) -> float:
	return clampf(length * WAKE_LIFE_PER_METRE, WAKE_LIFE_LEAST, WAKE_LIFE_MOST)


## HOW HIGH THE WALL OF SPRAY BEHIND A CRAFT RISES, metres, from how strongly it sprays: nothing for a craft that does
## not spray, so a slow hull on the water keeps its wake and nothing else.
static func sheet_height(strength: float) -> float:
	return SHEET_HEIGHT * clampf(strength, 0.0, 1.0)
