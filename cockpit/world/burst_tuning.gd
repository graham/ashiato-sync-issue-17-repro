extends RefCounted
class_name BurstTuning
## EVERY NUMBER A BIG EXPLOSION IS DRAWN BY, IN ONE PLACE: how big it is against the simulation's own number for what
## went off, and how the flash, the fireball, the sparks, the debris, the ring and the smoke each run.
##
## TWO THINGS GO OFF THIS WAY: a missile's warhead, and a heavy shell -- the gunship's 40 mm and 105 mm and a tank's
## explosive rounds. Everything smaller (7.62, 12.7, 25 mm, a sabot dart) stays a `Burst`: a gun firing thirty rounds
## a second that each threw a fireball and fourteen seconds of smoke would put a wall in front of the gunner in one
## second, and a machine gun hit is a puff of dirt.
##
## THE DECISION: THE PICTURE IS SIZED FROM THE SIMULATION, AND NOTHING HERE SIZES THE SIMULATION. A missile's only
## radius is its proximity fuse (`fuse_m` in the missile table: 12 m radar, 6 m heat); a shell's is its calibre
## (`calibre_mm` in the round table: 40, 105, 120). The fireball's radius is that number times a multiplier here, and
## every other size is a multiple of the fireball. A heat missile's burst is half a radar missile's because its fuse
## is, and a 40 mm shell's is under half a 105's because its bore is. Changing a number in this file changes what an
## explosion looks like on this machine and nothing any other machine has to agree with -- nothing here is damage, and
## no blast radius in the simulation reads it.
##
## WHAT WENT WRONG BEFORE: every explosion was `Burst`, a row of `Ammunition.LOOK` with bigger numbers in it -- a 9 m
## ball for a missile and 11 m for a 105, five smoke spheres and some box sparks, gone in under four seconds, every
## piece a StandardMaterial whose colour was written every frame. From the cockpit at a kilometre it was an orange dot.
## Asked for on 2026-09-13: "let's make missile explosions larger and higher quality", and then "the larger guns on the
## gunship should make large explosions ... with lots of fire and smoke, as long as they are not a weird perf hit".
##
## EVERY TIME IS SECONDS ON `BurstYard`'s CLOCK; every "per metre" is per metre of fireball radius.

## THE RULE A MISSILE'S SIZE COMES FROM, asked for on 2026-09-13: the SMALLEST missile's fireball at its widest is at
## least `LARGER_THAN_BEFORE` times the ball every missile drew before, which was `Burst` scaling a unit sphere to the
## missile look's "fireball" of 9 -- 9 m across. So the metres of fireball radius per metre of fuse are worked out from
## those two and the smallest `fuse_m` in the simulation's missile table (6 m, heat): 2.25, which is a 27 m ball for
## heat and 54 m for radar. The shaders place and swell the puffs so the LIT ball at its widest is about twice the radius
## across.
const LARGER_THAN_BEFORE: float = 3.0
const BEFORE_ACROSS: float = 9.0

## THE RULE A HEAVY SHELL'S SIZE COMES FROM, the same rule as a missile's: EVERY heavy round's fireball at its widest is
## at least three times the ball `Burst` drew for it (its `Ammunition.LOOK` "fireball", which stays in the table as the
## record of before). The metres of radius per millimetre of bore are worked out from whichever heavy round that rule
## binds hardest -- the 105: 11 m across at 105 mm -- times `SHELLS_LARGER_THAN_BEFORE`. That is 3.8 rather than 3.0
## because the size agreed on 2026-09-13 is a 105 42 m across, and 3.0 would have made it 33; the rule is the floor,
## this number is the choice above it, and the suite checks every heavy round against the floor. A 40 mm then comes out
## 16 m across (3.6 before) and a tank's HE 48 m (7.5). Linear in the calibre and not in its cube, because what the eye
## reads as the size of a blast goes with the cube root of the charge, and the charge with the cube of the bore.
const SHELLS_LARGER_THAN_BEFORE: float = 3.8
static var _per_mm: float = -1.0

## THE FLASH: a white disc this many fireball radii across at its widest, gone in `FLASH_S`. Not a full-screen white:
## the first night picture of a disc three times as wide was the whole screen.
const FLASH_ACROSS: float = 1.8
const FLASH_S: float = 0.12

## THE FIREBALL: puffs that swell out in `FIREBALL_GROW_S` and cool from white through orange to a dull red in about
## `FIREBALL_COOL_S`, rising at `FIREBALL_RISE` m/s. PLAIN draws the first `FIREBALL_PUFFS_PLAIN` of them.
const FIREBALL_PUFFS: int = 9
const FIREBALL_PUFFS_PLAIN: int = 5
const FIREBALL_GROW_S: float = 0.45
## WHITE-HOT FOR A MOMENT, THEN FIRE: `FIREBALL_COOL_S` is how long a puff is white, and `FIREBALL_BURN_S` how long it
## goes on burning orange down to a dull red before it goes out. One clock for both made a ball that was pale
## yellow-white for most of its life and "not fire" (team-lead, from the pictures, 2026-09-14).
const FIREBALL_COOL_S: float = 0.18
const FIREBALL_BURN_S: float = 2.2
## AND ON THE GROUND SOME OF IT STAYS: the puffs past the shader's `LINGER_FROM` settle beside the impact and flicker
## as small fires for this long. No quad is added for them.
const GROUND_FIRE_S: float = 5.0
const FIREBALL_RISE: float = 4.0

## THE SPARKS: streaks thrown out at up to `SPARK_SPEED_PER_M` m/s per metre of fireball, slowed by the air and falling,
## for up to `SPARK_S`. PLAIN draws the first `SPARKS_PLAIN`.
const SPARKS: int = 48
const SPARKS_PLAIN: int = 20
const SPARK_SPEED_PER_M: float = 2.5
const SPARK_S: float = 1.6

## THE DEBRIS, on FINE: dark chunks, glowing for their first moments, thrown slower and falling further.
const DEBRIS: int = 10
const DEBRIS_SPEED_PER_M: float = 1.0
const DEBRIS_S: float = 3.5

## THE RING, on FINE and IN THE AIR ONLY: a pale shell thrown out to `RING_OUT` fireball radii in `RING_S`. On the
## ground its lower half is under the ground, and the first picture of a 105 on a runway was a grey rainbow over it.
const RING_OUT: float = 2.5
const RING_S: float = 0.4

## THE SMOKE: lit puffs that open out to `SMOKE_GROW` fireball radii, rise, drift with the wind at that height and thin
## away over `SMOKE_S_*`. PLAIN draws fewer and they go sooner.
const SMOKE_PUFFS: int = 16
const SMOKE_PUFFS_PLAIN: int = 8
const SMOKE_GROW: float = 1.0
## HOW FAST THE SMOKE CLIMBS at first, in fireball radii a second, easing off over about six seconds; each puff by its
## own share, so it stands as a column. It was 3 m/s flat, and a 105's smoke sat on the ground as one ball.
const SMOKE_RISE: float = 0.6
const SMOKE_S_FINE: float = 14.0
const SMOKE_S_PLAIN: float = 9.0
## THE SMOKE'S COLOUR, as a colour picker gives it -- the shader reads it as sRGB. 0.24 was near-black once converted
## (about 0.05 linear), and the first picture of the smoke was a black ball.
const SMOKE_TONE := Color(0.52, 0.50, 0.47)
const SMOKE_OPACITY: float = 0.7
## A SMALLER BURST'S SMOKE GOES SOONER: the whole `SMOKE_S_*` at this fireball radius and above, and a share of it in
## proportion below, never less than `SMOKE_LEAST`. A 40 mm stream at a hundred rounds a minute with fourteen seconds
## of smoke each would be twenty-three bursts at once, twice the pool; at five seconds it is nine.
const SMOKE_FULL_AT_M: float = 15.0
const SMOKE_LEAST: float = 0.35

## THE LIGHT A BURST THROWS ON WHAT IS NEAR IT, for `LIGHT_S`, reaching `LIGHT_REACH` fireball radii. Its energy is the
## time of day's (`DaylightTuning`'s "burst_light"), and nothing lights at all when that is 0, which by day it is.
const LIGHT_REACH: float = 5.0
const LIGHT_S: float = 0.3
const LIGHT_COLOUR := Color(1.0, 0.72, 0.42)
## HOW MANY OF THOSE LIGHTS AT ONCE, the newest winning. Written for the Mobile renderer, which shades every omni light
## on every mesh it reaches and caps how many a mesh takes (eight, by Godot's renderer comparison), so an eight-missile
## volley at night lights two, not eight. Forward+, the renderer since 2026-09-14, takes them by the cluster instead
## (512 a cluster, same page), and two has not been re-timed on it. They are the
## yard's two lights, moved to the newest bursts, and never a light per burst.
const LIGHTS_AT_ONCE: int = 2

## How many big explosions may be drawn at once. The next takes back the oldest, smoke and all.
const AT_ONCE: int = 12

static var _per_fuse: float = -1.0
static var _calibres: Dictionary = {}


## How long a burst of this fireball radius is drawn for on a finish: until its smoke has gone.
static func lasts(radius: float, fine: bool) -> float:
	var full: float = SMOKE_S_FINE if fine else SMOKE_S_PLAIN
	# NEVER GONE BEFORE ITS GROUND FIRE: a 40 mm's smoke on PLAIN is about three seconds, and its fires five.
	return maxf(full * clampf(radius / SMOKE_FULL_AT_M, SMOKE_LEAST, 1.0), GROUND_FIRE_S)


## Whether a round lands as a big explosion rather than a `Burst`. The renderer's table says which rounds are heavy,
## because which effect draws a round is how it looks; how big that effect is, is the simulation's calibre.
static func is_heavy(ammo: int) -> bool:
	return bool(Ammunition.look(ammo).get("heavy", false))


## The fireball's radius for a heavy round, from its calibre. 0 for a round the simulation gives no calibre, which
## draws no big burst rather than a guessed one.
static func fireball_for_round(ammo: int) -> float:
	return calibre_mm(ammo) * fireball_per_mm()


## METRES OF FIREBALL RADIUS PER MILLIMETRE OF BORE, from the rule above: the largest share any heavy round needs to be
## `SHELLS_LARGER_THAN_BEFORE` times its old ball, asked of the round table once. 0 with no table, which draws nothing.
static func fireball_per_mm() -> float:
	if _per_mm > 0.0:
		return _per_mm
	var most: float = 0.0
	for ammo in Ammunition.LOOK:
		var bore: float = calibre_mm(int(ammo))
		if is_heavy(int(ammo)) and bore > 0.0:
			most = maxf(most, float(Ammunition.look(int(ammo)).get("fireball", 0.0)) * 0.5 / bore)
	if most <= 0.0:
		return 0.0
	_per_mm = SHELLS_LARGER_THAN_BEFORE * most
	return _per_mm


## The fireball's radius for a missile type's fuse radius.
static func fireball_for_fuse(fuse_m: float) -> float:
	return fuse_m * fireball_per_fuse()


## A ROUND'S CALIBRE, IN MILLIMETRES, as the simulation's round table gives it. Asked once and kept: the table is the
## same for every gun, and the rows come with any kind's gun schema.
static func calibre_mm(ammo: int) -> float:
	if _calibres.is_empty():
		for row in (Sim.gun_of(Sim.Kind.TANK, 0).get("rounds", []) as Array):
			_calibres[int((row as Dictionary).get("ammo", -1))] = float((row as Dictionary).get("calibre_mm", 0.0))
	return float(_calibres.get(ammo, 0.0))


## METRES OF FIREBALL RADIUS PER METRE OF FUSE, from the rule above: asked of the simulation's own missile table once,
## through every type any kind carries. 0 when there is no table to ask, which draws no burst rather than a guessed one.
static func fireball_per_fuse() -> float:
	if _per_fuse > 0.0:
		return _per_fuse
	var smallest: float = INF
	for kind in Sim.Kind.values():
		for station in (Sim.missile_schema(kind).get("stations", []) as Array):
			var fuse: float = float(Sim.missile_type(int((station as Dictionary).get("type", -1))).get("fuse_m", 0.0))
			if fuse > 0.0:
				smallest = minf(smallest, fuse)
	if smallest == INF:
		return 0.0
	_per_fuse = LARGER_THAN_BEFORE * BEFORE_ACROSS / (2.0 * smallest)
	return _per_fuse
