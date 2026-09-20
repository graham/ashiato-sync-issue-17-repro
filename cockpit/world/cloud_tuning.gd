extends RefCounted
class_name CloudTuning
## EVERY NUMBER A CUMULUS IS SHAPED AND LIT BY, IN ONE PLACE: how many lumps, how big, how tall a strong
## thermal's cloud grows, how dark its base is, and how much of the sun comes through a thin edge.
##
## THE DECISION: A FILE, NOT A SLIDER, the one `DaylightTuning` and `ForestTuning` make. What colour the light
## on a cloud is comes from `DaylightTuning` -- the sun, the sky and the ambient a preset already names -- and
## nothing here repeats it; these are only the shares of those numbers a cloud takes.
##
## WHAT WENT WRONG BEFORE (2026-09-13 day screenshots): every cloud in the sky was the same nine lumps in the same
## ring -- `l % 3` and `(l * 7) % 5` -- scaled by its zone, so a sky of thirty-one clouds read as one cloud
## stamped thirty-one times; each lump was cut flat at ITS OWN bottom, so a cloud had nine bases at nine heights;
## and a lit white albedo under a wrap-lit sun gave a white blob whose base was barely greyer than its top.

## Lumps a cloud is made of, the same count for every cloud so the sky stays one MultiMesh. What varies is how big
## each is and where it sits.
##
## TWENTY-FOUR, not eleven, so a cloud can have crown bumps and shreds as well as a core, towers and a skirt (asked for on
## 2026-09-14: "more detail, spheres ... real clouds are more distorted and shredded"). What that costs is in agents.md.
const LUMPS: int = 24

## WHAT KIND OF CLOUD A THERMAL GROWS, one row a kind. `weight` is how often it is drawn among the kinds whose `strength`
## range holds the thermal's; the rest is its shape:
##   `flatten`     height of a lump against its width, drawn between the two;
##   `spread`      the cloud's reach against the usual `CLOUD_SPREAD` of the thermal's radius;
##   `elongation`  how much longer the cloud is than wide in plan, drawn between the two, along its own heading;
##   `towers`      how many towers stand on the core, drawn between the two;
##   `tower_tall`  a tower's height against its width;
##   `tower_step`  how far up the lump below a tower's centre starts, as a share of that lump's height (`TOWER_STEP` if unset);
##   `lean`        how far each tower steps off the one below, as a share of its width;
##   `shear`       how far the cloud's top is carried sideways, metres a metre of height;
##   `crown`       bumps set on the upper side of the core and towers;
##   `shreds`      small stretched lumps broken away from the rim, and from the tower tops on a tall cloud;
##   `ragged`      0 to 1, how far out and how uneven the skirt is;
##   `core`        the core's width against the reach, drawn between the two.
## Every other lump of the twenty-four is skirt.
const TYPES: Array[Dictionary] = [
	{"name": "humilis", "weight": 3.0, "strength": Vector2(0.0, 4.2), "flatten": Vector2(0.50, 0.65), "spread": 1.0,
		"elongation": Vector2(1.4, 1.9), "towers": Vector2i(0, 0), "tower_tall": 0.6, "lean": 0.10, "shear": 0.0,
		"crown": 3, "shreds": 3, "ragged": 0.35, "core": Vector2(0.50, 0.70)},
	{"name": "mediocris", "weight": 3.0, "strength": Vector2(2.4, 4.8), "flatten": Vector2(0.70, 0.90), "spread": 0.95,
		"elongation": Vector2(1.1, 2.0), "towers": Vector2i(1, 2), "tower_tall": 0.95, "tower_step": 0.35, "lean": 0.20, "shear": 0.08,
		"crown": 5, "shreds": 2, "ragged": 0.30, "core": Vector2(0.62, 0.85)},
	{"name": "congestus", "weight": 6.0, "strength": Vector2(4.6, 99.0), "flatten": Vector2(0.85, 1.0), "spread": 0.75,
		"elongation": Vector2(1.0, 1.2), "towers": Vector2i(3, 5), "tower_tall": 1.1, "tower_step": 0.35, "lean": 0.30,
		"shear": 0.20, "crown": 6, "shreds": 3, "ragged": 0.10, "core": Vector2(0.65, 0.90)},
	{"name": "fractus", "weight": 1.5, "strength": Vector2(0.0, 3.4), "flatten": Vector2(0.35, 0.50), "spread": 0.95,
		"elongation": Vector2(1.4, 2.0), "towers": Vector2i(0, 1), "tower_tall": 0.6, "lean": 0.35, "shear": 0.30,
		"crown": 1, "shreds": 9, "ragged": 1.0, "core": Vector2(0.35, 0.55)},
	{"name": "spread", "weight": 1.0, "strength": Vector2(2.0, 4.5), "flatten": Vector2(0.30, 0.40), "spread": 1.2,
		"elongation": Vector2(1.5, 2.2), "towers": Vector2i(0, 1), "tower_tall": 0.5, "lean": 0.15, "shear": 0.10,
		"crown": 2, "shreds": 4, "ragged": 0.55, "core": Vector2(0.45, 0.60)},
]


## THE MOST A CLOUD MAY SPREAD IN PLAN: its fog's box, either way across, against its thermal's radius. Past this a cloud is
## shrunk in plan about its middle (`LiftYard.cloud_lumps`), towers and all. 4.5 because the eleven-lump clouds reached 4.47;
## the first kinds laid a flat cloud out at 11.2, a 3.1 km streak (tests/air.gd).
const PLAN_MOST: float = 4.5

## The most lumps any kind can stand above its cloud's base -- towers, crown bumps and shreds from tower tops -- worked out
## from `TYPES`, for the air suite's rule that every other lump reaches down to the base.
static func most_aloft() -> int:
	var most: int = 0
	for kind in TYPES:
		most = maxi(most, (kind["towers"] as Vector2i).y + int(kind["crown"]) + int(kind["shreds"]))
	return most

## Each tower as a share of the lump it stands on, so a tower tapers as it climbs, and how far up the lump below it the
## tower's centre starts, as a share of that lump's height. The first towers were a share of the whole cloud's reach,
## stacked a little under half a lump apart, and from the clouds view (2026-09-14) a strong thermal's cloud read as a
## column of beads.
## (0.70, 0.88) since the cloud kinds: at (0.62, 0.82) a congestus's fourth tower was a third of its core, a bead.
const TOWER_SIZE := Vector2(0.70, 0.88)
const TOWER_STEP: float = 0.30
## THE SKIRT: every other lump, round the core. Sizes drawn with a square, so most are small and a few are big,
## which is what stops two clouds of one zone size looking alike.
const SKIRT_REACH := Vector2(0.30, 0.85)
const SKIRT_SIZE := Vector2(0.18, 0.62)
## How far below the base a lump's own centre may sit, as a share of its height. Everything under the base is cut
## off level by the shader, so a lump sunk into it gives the cloud a wide flat bottom rather than a row of balls.
const SINK := Vector2(0.10, 0.30)

## THE BASE, DARKER THE THICKER THE CLOUD: a small fair-weather puff has a pale grey underside, a tall one a dark one,
## because the light has further to come. Share of the shade colour kept, thin to thick, over the thickness range.
##
## DARKER THAN THE FIRST NUMBERS (0.95, 0.55), with the shares above: a thin cloud keeps 0.70 of its light at the base
## and a thick one 0.40, and the crown none of it, because the share fades to one at the top. On its own this was not
## enough; see `SUNLIT`.
const BASE_BRIGHT := Vector2(0.70, 0.40)
const THICK := Vector2(250.0, 1100.0)
## How much of the sun a sunlit crown takes, how much the side turned away still gets by scattering, and how much of
## the sky and the ground's light every part of it takes.
##
## LOWER THAN THE FIRST NUMBERS, WHICH WHITED THE CLOUD OUT. With the whole sun (1.0) and the whole sky on top of it, a
## day cloud summed past white nearly everywhere: worked from DAY's numbers, a sunlit side came to about 1.5 to 1.8 and
## even the base to about 0.87, so the render clipped a PLAIN cloud to one flat white shape with less modelling than the
## engine-lit sphere it replaced (clouds view, 2026-09-14).
##
## AND THEN MORE SUN AND LESS SKY, BECAUSE THE BASE STILL READ PALE. The next shares (0.75 sun, 0.25 turned away, 0.5 sky)
## left a day cloud's underside barely darker than its crown -- the lead's note on the pictures. Dimming the base alone
## (`BASE_BRIGHT`) did not fix it: from the clouds view the darkest tenth of cloud pixels against the brightest went only
## from 0.820 to 0.807, because it dimmed every low part of the cloud together, crowns included. The sky's light is what
## filled the shade in. At these, the same measure reads 0.752, the darkest tenth falls from 0.731 to 0.645 and the
## brightest stays at 0.858 -- a grey base under a white crown by day, and a darker lavender-brown under a warm one at
## evening.
const SUNLIT: float = 0.9
const AWAY: float = 0.2
const AMBIENT: float = 0.35
## THE UNDERSIDE IS LIT FROM BELOW: by the ground's horizon colour and the haze, this share of the way to the fog's.
const SHADE_FROM_FOG: float = 0.5
## THE SILVER LINING: a thin edge seen with the sun behind it glows. How strong, and how tight round the sun.
const LINING: float = 0.9
const LINING_TIGHTNESS: float = 6.0

## ---- A CLOUD LIT AS A VOLUME (`world/shaders/cloud_light.gdshaderinc`, through `LiftYard.cloud_envelope`) -----------------
##
## Asked for on 2026-09-15: "increase the volumetrics of the clouds". The survey (godotgames-drafts/2026-09-15/cockpit-mist/survey,
## cumulus_side) drew a day cumulus as white spheres with a sunlit side no brighter than its shaded one.

## How fast a cloud swallows the sun, per metre of its envelope the light crosses: a third of it left after 330 m.
const SUN_EXTINCTION: float = 1.0 / 300.0
## THE LIGHT THAT HAS SCATTERED MANY TIMES: this share of the sun, falling `SCATTER_REACH` as fast as the direct light, so a
## cloud's lee side and core are dim and never black. A kilometre in keeps 0.19 of the sun, where the direct light keeps 0.04.
## 0.45, not 0.35: at 0.35 the lower lumps of the clouds view's cloud from 150 m by day were slate-blue under a white fog
## flank beside them, a storm cloud's base on a fair-weather heap (step1-fade/after, cloud_at_150-fine-day: the darkest tenth
## of cloud pixels 123 of 255 against 161 before any volume).
const SCATTER_FLOOR: float = 0.45
const SCATTER_REACH: float = 0.25
## How much of the sky's light a lump surface buried deep in its envelope keeps: the crevices between towers.
const CORE_SHADE: float = 0.6
## How much sun a thin edge on the side turned from the sun passes through, times the sun that reaches it.
const TRANSLUCENT: float = 0.3
## The most clouds the lumps' shaders carry an envelope for: `world/shaders/cloud_envelopes.gdshaderinc`'s array length.
const MOST_CLOUDS: int = 64
## The least an envelope's radius may be, in metres, so a cloud of one small lump still has an inside.
const ENVELOPE_LEAST: float = 30.0

## ---- THE CLOUDS AS FOG NEAR THE EYE (`CloudBank`, FINE on Forward+ only) ----------------------------------------------

## How much wider and taller than its lumps a cloud's fog envelope is, so the noise has room to eat into it.
const FOG_SWELL: float = 1.15
## The density in the heart of a cloud, as the engine's extinction per metre: visibility near 100 m in a core.
const FOG_CORE_DENSITY: float = 0.04
## How much of the envelope the noise eats.
const FOG_EROSION: float = 0.6
## Cycles of noise a metre: a lump of texture about 160 m across.
const FOG_NOISE_SCALE: float = 1.0 / 160.0
## Metres a second the texture climbs, so a cloud boils in still air (`Terrain.WIND` is zero).
## 3 m/s, not 0.8: at 0.8 thirty seconds moved the texture 24 m against 160 m of noise and the cloud looked still
## (cloud_at_60, --strip over 1800 frames, 2026-09-14).
const FOG_CLIMB: float = 3.0
## How many metres over the base the fog takes to reach its density: a flat base, not a knife.
const FOG_BASE_SOFT: float = 25.0
## Where inside a lump (squared distance, 0 centre to 1 surface) the fog starts to thin.
## 0.30, not 0.35, for a little more edge for the billows to eat. 0.15 was tried: it merged a cloud's lumps into one smooth band
## that no longer had the mesh cloud's outline (d2-cap, cloud_at_300, 2026-09-14).
const FOG_LUMP_SOFT: float = 0.30
## How much of the erosion is billowy cells (a cell-distance noise, lumps bulging out) rather than smooth value noise.
const FOG_BILLOW: float = 0.45
## THE DETAIL NEAR THE EYE: a finer octave, this strong, whole within the first distance of the eye and gone by the second.
## Inside a few hundred metres a froxel is a few metres across and can show it; further out it would only crawl.
const FOG_NEAR_DETAIL: float = 0.35
const FOG_NEAR_REACH := Vector2(80.0, 320.0)
## THE FROXEL GRID, (width and height, depth), and how far from the eye it reaches in metres. FINE only: PLAIN draws no fog.
const FOG_FROXELS := Vector2i(128, 128)
const FOG_LENGTH: float = 3000.0
## WHERE A CLOUD TURNS FROM MESH TO FOG, as the eye's distance from its box in metres: all fog inside the first, all mesh
## past the second. Fog at 700 m was already a blur (cloud_near, 2026-09-14), so the fog is kept for the last few hundred.
const FOG_FADE := Vector2(150.0, 500.0)
const FOG_DETAIL_SPREAD: float = 2.0
## NO FORWARD SCATTER: at anisotropy 0 the engine's phase is 1 / (4 * PI) in every direction, which is what lets the fog's
## albedo be its colour divided by a light that does not depend on where the eye is (`world/shaders/cumulus_fog.gdshaderinc`).
const FOG_ANISOTROPY: float = 0.0
const FOG_REPROJECTION: float = 0.85

## ---- THE WHITEOUT WITH NO FOG TO FLY INTO (PLAIN, or FINE with no fog clouds; `Daylight.show_in_cloud`) -----------------

## How dense the depth fog is at the heart of a cloud: Godot's exponential depth fog takes 1 - exp(-density * distance) of the
## view, so 0.06 has 95 % of it gone by 50 m -- the brief's thick cumulus, 20 to 80 m.
const WHITEOUT_DENSITY: float = 0.06

## ---- CIRRUS, IN THE FINE SKY (`world/shaders/sky_fine.gdshader`, made by `Daylight.fine_sky_material`) ------------------

## How high the sheet is, in metres: cirrus stands at eight to twelve kilometres, far over the cumulus tops at 1.5 km.
const CIRRUS_HEIGHT: float = 9000.0
## How much of the sheet is streak, 0 to 1, and how opaque a streak is at its thickest.
const CIRRUS_COVER: float = 0.45
const CIRRUS_OPACITY: float = 0.7
## Cycles of noise a metre across the streaks, and how many times longer a streak is than it is wide, laid along
## `CIRRUS_HEADING` (a heading on the ground, x and z: there is no wind, so it is only which way the streaks lie).
const CIRRUS_SCALE: float = 0.0006
const CIRRUS_STRETCH: float = 5.0
const CIRRUS_HEADING := Vector2(0.8, 0.6)
## How far along the eye's ray the sheet is drawn before it has faded out, in metres, so the horizon is not one grey band.
const CIRRUS_REACH: float = 60000.0
## How much of the sun (or the moon: LIGHT0) and of the horizon's colour a streak takes.
const CIRRUS_SUN_SHARE: float = 0.5
const CIRRUS_SKY_SHARE: float = 0.6
