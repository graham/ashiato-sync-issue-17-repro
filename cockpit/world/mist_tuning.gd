extends RefCounted
class_name MistTuning
## EVERY NUMBER THE LOW MIST IS TUNED BY, IN ONE PLACE: how dense the ground haze is at each time of day and how fast it thins
## with height, where the low stratus lies and how much of the sky it covers, and what colour both are.
##
## THE DECISION: A FILE, NOT A SLIDER, as `DaylightTuning` and `CloudTuning` are. Keyed by `DaylightTuning.When`, and
## nothing here repeats a colour a time of day already names: the sun's colour is `DaylightTuning`'s.
##
## WHAT WENT WRONG BEFORE (the survey, godotgames-drafts/2026-09-15/cockpit-mist/survey): the mist was the environment's depth
## fog with its density eased by the eye's height, so it was one wall -- the same over a city, a valley and open ground, with no
## top to see from above, and at night fog so dark there was no mist at all.

## Asked for on 2026-09-15: "near-ground mist or low clouds that is thinner and creates more atmosphere". Three presets, EVENING
## standing for dawn and dusk alike: denser and warmer at the low sun, thinner by day, blue-grey at night, never none.
##
## THE COLOUR IS THE HORIZON SKY's (`DaylightTuning`'s `sky_horizon`), not typed here (step2-try5, mist_under-plain-night): night's
## own (0.10, 0.12, 0.17) was forty times the night sky, so a patch overhead taking a tenth of the light lifted the whole sky
## from 0.03 to 0.15. The horizon is the sky seen through the most air, which is what mist is.
##
## LIGHTER AGAIN, AND BROKEN UP (team-lead after the merge, 2026-09-15: at least 12 km at 2 m at evening, with thinner and thicker
## places): every haze density down, evening's clear air night's, and the breakup wider and deeper -- 12.5 km at 2 m at every
## time of day, day's haze still the thinnest.
##
## LIGHTER STILL (step2-try5, and team-lead from the user's answer: "town lights and terrain should read well past today's ~8 km"):
## visibility to 5% over open ground two metres up was 9.2 km by day and 7.2 at evening; now 10.7, 9.3 and 10.3 at night (tests/visibility probe, 2026-09-15),
## day still the thinnest. Evening's stratus lies higher and rarer: from the grass its patch overhead was still an arc.
##
## LIGHTER AGAIN (step2-try4, and the user's own words, 2026-09-15: "lighter, not too thick, it shouldn't be uniform"): the
## evening valley still read as one sea of fog, so every haze density came down by about a third and evening's and night's
## stratus with it.
##
## THINNER THAN THE FIRST NUMBERS (step2-try1, 2026-09-15): at evening 0.0011 haze and 0.004 stratus buried the valley and the
## city in one warm sheet, and by day 0.0025 stratus seen edge-on drew a bright white line along the whole horizon.
##
## AND RARER, SMALLER, SOFTER STRATUS (step2-try2): by day the patches striped the peaks at their own height, and at evening one
## patch overhead, seen from the grass, had an edge a kilometre long that read as an arc drawn across the sky. The cover ramps
## are wider and higher, so fewer patches show and each fades in over more of the noise, and `STRATUS_SCALE` is smaller.
const DAY: Dictionary = {
	"haze_density": 0.00015, "haze_height": 45.0, "dome_density": 0.00020, "pool_gain": 1.0,
	"stratus_density": 0.0010, "stratus_height": 260.0, "stratus_width": 40.0, "stratus_cover": Vector2(0.72, 0.95),
	"sun_glow": 0.35,
}
const EVENING: Dictionary = {
	"haze_density": 0.00017, "haze_height": 60.0, "dome_density": 0.00035, "pool_gain": 2.4,
	"stratus_density": 0.0010, "stratus_height": 220.0, "stratus_width": 45.0, "stratus_cover": Vector2(0.70, 0.93),
	# 0.35, as by day, not 0.9 then 0.5: the haze toward the low sun glowed brighter than the sky along the whole horizon
	# (step2-try6-haze, and step2-try9 mist_city-fine-evening).
	"sun_glow": 0.35,
}
const NIGHT: Dictionary = {
	"haze_density": 0.00017, "haze_height": 55.0, "dome_density": 0.00040, "pool_gain": 3.2,
	"stratus_density": 0.0010, "stratus_height": 200.0, "stratus_width": 40.0, "stratus_cover": Vector2(0.60, 0.87),
	"sun_glow": 0.25,
}
const PRESETS: Array[Dictionary] = [DAY, EVENING, NIGHT]

## How much of the haze the world noise takes away where it is lowest, and its cycles a metre. 0.9 over 1,500 m, not 0.6 over
## 600 (team-lead off step2-try11 mist_city at evening, 2026-09-15: "heavy and flat grey-brown over the first few km", and the
## user's "not uniform"): clear gaps and thicker banks kilometres across, not a fine mottle that averages to a film.
const HAZE_BREAKUP: float = 0.9
const HAZE_SCALE: float = 1.0 / 1500.0
## 1/900, not 1/1400: patches 900 m across rather than 1,400, so no one edge overhead runs the width of the sky (step2-try2).
const STRATUS_SCALE: float = 1.0 / 900.0
## HOW FAR ALONG A RAY THE STRATUS REACHES, metres: gone past this, whole within a fifth of it (`M_STRATUS_NEAR` in
## mist.gdshaderinc), a long ramp. Past a few kilometres the band is seen edge-on, a line a pixel or two tall, and whole to 7 km
## those lines drew a white strip through the foot of every peak (step2-try6-stratus, mist_city-fine-evening); whole to 4 km
## and gone by 6.4, the ramp's end drew an arc across the night sky under a patch (step2-try8, grass-plain-night).
const STRATUS_REACH: float = 8000.0
## THE MOST OPTICAL DEPTH ONE RAY TAKES FROM THE STRATUS: seen edge-on from near its own height the band ran kilometres along a
## ray and summed to an opaque white line along the horizon and across every peak, even with the ray's reach capped (step2-try4).
## 0.5 lets a layer edge-on take at most two fifths of what is behind it -- one patch's worth.
const STRATUS_MOST_TAU: float = 0.5
## Metres a second the patterns wander. There is no wind (`Terrain.WIND`), and a mist that never moved read as painted on.
const DRIFT: float = 0.6
## How far over the highest ground a ray is followed through the mist: over the stratus's top at every time of day.
const CEILING: float = 700.0
## HOW FAR ALONG ANY RAY THE MIST IS FOLLOWED, metres: inside the camera's 24 km far plane and a little under the chart's span.
## NOT UNLIMITED: a sky pixel's ray, with no surface to end at, ran 40 km through the haze while the ground just under the horizon
## ended at the island's edge, and the step between them drew a bright white band along the whole horizon through every peak's
## foot, on both finishes (step2-try3, mist_city-plain-evening and fields-fine-day). Past this the clear-air depth fog carries it.
## BESIDE cockpit-terrain's coming `ViewTuning.REACH` (24 km, the far plane, and a per-player setting): when that lands this becomes
## a named share of the live reach, written by the level when it changes, not a second number.
const REACH: float = 14000.0
## How tight the glow round the sun is, and how many steps along a ray each finish takes.
const SUN_TIGHTNESS: float = 6.0
## ONE ON BOTH, NOT FOUR AND EIGHT, THEN ONE AND FOUR (team-lead's option 0, 2026-09-15): FINE at one step -- the closed form
## over the whole ray, with the stratus's second octave -- looked the same as four in the evening valley bar a little less breakup
## at the far edge (step2-try4-fine-one-step against step2-try4), and costs +0.11 to +0.13 ms against four steps' +0.19 to +0.22.
## Before that: priced 2026-09-15, every step about +0.045 ms GPU at 1600x900 x1.40 on top of +0.06 (PLAIN)
## and +0.10 to +0.13 (FINE) for the pass itself; at four and eight the pass cost +0.24 and +0.45 to +0.55, and a headset pays a
## march per pixel of both eyes. One step is exact in height over flat ground. See world/shaders/mist.gdshaderinc.
const STEPS_PLAIN: int = 1
const STEPS_FINE: int = 1
## How much darker a low stratus's underside is than its top, which is the horizon sky's colour: a little volume, far less than a
## cloud's.
const STRATUS_MODELLING: float = 0.25
## THE CHART OF THE GROUND UNDER THE MIST (`MistChart`): texels across, metres across, and how far the eye may go from its
## middle before it is baked again round the eye, on a worker.
const CHART_TEXELS: int = 128
const CHART_SPAN: float = 16384.0
const CHART_RECENTRE: float = 4096.0
## THE VALLEY POOLS (step 4, asked for on 2026-09-15: "especially around cities or around low mountains"): the haze is thicker
## where the ground lies below the ground round it -- cold air draining downhill and lying in the valleys and bowls -- by up to
## `pool_gain` more (per time of day, above: least by day, most at night), reached where the ground is `POOL_DEPTH` metres below
## its surroundings. The surroundings are the chart's RELIEF (`MistChart.relief_of`): a box blur `RELIEF_TEXELS` texels each way,
## twice, about a Gaussian of 1.3 km at 128 m a texel. Only the haze pools; the stratus deck stays where it lies. Over flat
## ground relief is 0 and nothing changes, so the island's pictures are the step before's.
## TWELVE TEXELS AND THESE GAINS, NOT FOUR AND HALF THEM (step4-trial on alpine, 2026-09-15): at a 470 m blur only narrow floors
## read as low (7% of a chart 60 m under its surroundings) and the evening valley changed by 1.5/255; at 1.3 km the broad low
## ground between the ranges does (21-40%), and with the gains doubled the evening lowland fills with lighter broken haze
## along the valleys (mean 4.5, p99 15 on mist_valley) while the first city moves by 1.6. Relief found by tests/relief_probe
## off the generated ground itself.
const RELIEF_TEXELS: int = 12
const POOL_DEPTH: float = 60.0


## THE COMPUTE MIST ON PLAIN (MistEffect): the mist worked out at half the resolution a side and laid on by one blended triangle.
## ON (team-lead's DECISION, 2026-09-15, after one bracketed slot against the spatial pass): at 4K it cost +0.46 to +0.63 ms
## against the spatial pass's +0.92 to +1.50, a saving of 0.47 to 0.87 on every view -- for a headset's two eyes, estimated,
## +0.34 against +0.81. Its first lay-on, a compute upsample, cost more than the spatial pass and was off until the blend
## replaced it (agents.md, "the half-resolution compute mist"). FINE keeps the spatial pass either way (MSAA).
const COMPUTE_ON_PLAIN: bool = true
## How far apart a pixel's depth and a half-resolution texel's may be, as a share of the nearer, and still be one surface in the
## lay-on's edge path (world/shaders/mist_lay.glsl) and the half pass's edge mask (mist_half.glsl): past it the texel is someone
## else's, and weighted out.
const COMPUTE_EDGE: float = 0.02
## How far a sky pixel's ray is taken, metres, on both passes: it has no surface to end at. Past `REACH` the mist stops anyway.
const SKY_REACH: float = 40000.0

## THE TOWNS' HAZE DOMES (step 3, asked for on 2026-09-15: "especially around cities"): over each town (`TownCatalogue.towns()`,
## its seated centre and radius) extra haze, `dome_density` per metre at the town's ground (per time of day, above), falling by
## e every `DOME_HEIGHT` metres and across `DOME_SPREAD` radii as a Gaussian -- a town's own warmth, smoke and dust, thicker at
## the low sun and at night. At most `MOST_TOWNS` (the shader's `M_MOST_TOWNS`, held equal by tests/mist.gd).
const MOST_TOWNS: int = 8
const DOME_HEIGHT: float = 80.0
const DOME_SPREAD: float = 1.4
## HOW MUCH OF THE TOWN'S WINDOW LIGHT THE DOME PUTS BACK AT NIGHT: the glow's colour is a lit window's (TownTuning.PLAIN_WINDOW_LIGHT)
## times the share of windows lit and their glow (DaylightTuning `windows_lit` and `window_glow`, what TownView lights them by),
## times this. Windows only while TownTuning.STREET_LIGHTS_ON is false: a glow over dark streets would light a town the player
## sees unlit. By day `windows_lit` is 0, so there is none.
const TOWN_GLOW: float = 0.20


static func preset(time: int) -> Dictionary:
	return PRESETS[clampi(time, 0, PRESETS.size() - 1)]


## THE MIST AT A LOOK (`DaylightTuning.look_at`): the three presets blended by what the look is like, key by key
## (`DaylightTuning.blend`), so the mist at dusk lies between EVENING's and NIGHT's by the same weights the sky does.
static func at(look: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in DAY.keys():
		out[key] = DaylightTuning.blend([DAY[key], EVENING[key], NIGHT[key]], look["like"])
	return out
