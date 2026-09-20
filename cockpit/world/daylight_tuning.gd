extends RefCounted
class_name DaylightTuning
## EVERY NUMBER THE TIME OF DAY IS TUNED BY, IN ONE PLACE: what colour the light, the sky and the fog are, how many
## windows are lit and how bright the air's markers are -- as LOOKS keyed by where the sun stands, and blended between.
##
## A CLOCK, AND THE THREE PRESETS ARE POINTS ON IT (2026-09-18). "Allow for time of day changes, so we can cleanly have
## the sun and moon move over time and handle special cases like twilight ... change the time to arbitrary times of day
## from the ipad (not just the three we have now)". The time of day is a clock now (`Orrery`, and the session's in `Net`),
## the sun and the moon stand where the clock puts them, and what the world looks like is `look_at(minutes)`: the three
## presets below, each the look at one height of the sun, blended by the true sun's elevation in between. So the look is
## decided by the SUN, not by a name -- a winter afternoon with the sun 7 degrees up is EVENING's light, and twilight is
## what lies between EVENING's sun and NIGHT's dark, whatever the clock says.
##
## THE PRESETS ARE WHERE THEY WERE. DAY and EVENING are the looks at their own suns' elevations, and `Orrery`'s sky is
## solved so that those suns stand exactly where these presets put them; at the clock's DAY, EVENING and NIGHT the look is
## the preset, key for key (tests/daytime.gd). What the three were tuned FOR is below, unchanged: "so we can test day,
## evening and night" (2026-09-13), and the three are still the points a probe compares.
##
## THE DECISION: A FILE, NOT A SLIDER, the same one `TownTuning` and `ForestTuning` make. What a player decides is the time;
## what somebody making dusk convincing needs is every number beside the reason it has the value it has.
##
## DAY IS THE SKY AS IT WAS BEFORE THERE WAS A CHOICE: the colours written in `world/sky.tscn`,
## Godot's own fog light colour (which the scene never set), the scene's aerial perspective, a white sun
## at energy 1, and the sun where the scene's DirectionalLight3D stood -- read off its basis, (0.42, 0.57,
## 0.71) towards the sun, which is 34.8 degrees up and 30.6 degrees round from +Z towards +X.
##
## A sun is placed by ELEVATION (degrees above the horizon) and AZIMUTH (degrees round from +Z towards +X; a compass
## bearing is 180 minus it), which are the two numbers a person tuning a low evening sun actually thinks in. They are
## what `Orrery` was solved against; the sun itself comes from the clock.

enum When { DAY, EVENING, NIGHT }

## What a level starts on when nobody has asked. `--time=` on the command line is the asking.
const START: int = When.DAY

## THE AMBIENT IS ALWAYS THE SKY'S, AND `ambient_sky` IS HOW MUCH OF IT: 1 lights the ground with the sky above it, 0 with
## `ambient_colour` alone. Godot mixes the two by `Environment.ambient_light_sky_contribution` (render_scene_data_rd.cpp:
## `mix(colour * energy, sky, contribution)`), so a sky source at 0 is exactly the colour source NIGHT had, and dusk can
## pass from one to the other. Until 2026-09-18 this was `ambient_source`, SKY or COLOR, which cannot be half of each.

const DAY: Dictionary = {
	"sun_elevation": 34.8,
	"sun_azimuth": 30.6,
	"sun_colour": Color(1.0, 1.0, 1.0),
	"sun_energy": 1.0,
	# FROM THE SKY, which is what the scene had by default: the ground lit by the blue above it.
	"ambient_sky": 1.0,
	"ambient_colour": Color(0.0, 0.0, 0.0),
	"ambient_energy": 1.0,
	"sky_top": Color(0.28, 0.45, 0.75),
	"sky_horizon": Color(0.72, 0.79, 0.86),
	"ground_bottom": Color(0.19, 0.22, 0.2),
	"ground_horizon": Color(0.6, 0.63, 0.62),
	"fog_colour": Color(0.518, 0.553, 0.608),
	"fog_aerial_perspective": 0.3,
	# HOW MUCH OF THE DEPTH FOG IS LAID OVER THE SKY: Godot's default 1, which the scene never set. Every preset keeps it; the
	# twilight looks take it down, because at 1 the fog replaces the sky at the horizon and hides the dusk glow
	# (`DUSK_GLOW`) that says where the sun went (sunset1, 2026-09-18: 19:45 a flat grey-pink all round).
	"fog_sky_affect": 1.0,
	# THE CLEAR AIR: the depth fog's density at every height -- the scene's own 0.00016 by day. The low mist lies in the world
	# on the ground under it (`MistLayer`, every number in `MistTuning`). Until 2026-09-15 it was eased in here by the eye's
	# height (`mist_density` low, `mist_above` over `mist_top`), and made a city, a valley and open ground one wall
	# (godotgames-drafts/2026-09-15/cockpit-mist/survey).
	"clear_air": 0.00016,
	# No window is lit by day: a lit window in sunlight is a window nobody can see is lit.
	"windows_lit": 0.0,
	"window_glow": 0.0,
	# THE AIR'S MARKERS -- the rings on the ground round a thermal and the wisps climbing it (`LiftYard`) -- as
	# bright as they were drawn. They are unshaded, so nothing but this number dims them when the light goes.
	"markers": 1.0,
	# AN AIRCRAFT'S LIGHTS, as a share of their night brightness: by day small coloured points, not beacons -- "less
	# visible in day", asked for on 2026-09-13. The runway's are not dimmed. See VehicleLights.show_daylight.
	"aircraft_lights": 0.45,
	# AND BY DISTANCE: full brightness and size out to VehicleLights.DIM_FROM, easing by `aircraft_dim_to` to
	# `aircraft_far_bright` of the brightness and `aircraft_far_least` of the least angle a light holds -- so a far
	# aeroplane by day is a speck that fades rather than a dot that stays: "the lights on planes are still too bright in
	# the daytime, dim them at distance more" (2026-09-13). Measured in agents.md, "An aircraft's lights by distance".
	# KEEPING 0.7, NOT 0.35: the brightness is what takes a far light out of sight (red pixels a light at 2.6 km 0.98 to
	# 0.00 at any of 0.35, 0.7 and 1), and shrinking it under a pixel let FINE's multisampling wash its reddest pixel to
	# 0.196 against PLAIN's 0.259 at 0.35; 0.247 at 0.7.
	"aircraft_dim_to": 2000.0,
	"aircraft_far_bright": 0.12,
	"aircraft_far_least": 0.7,
	# HOW BRIGHTLY A BIG EXPLOSION LIGHTS WHAT IS NEAR IT, as the energy of `BurstYard`'s two lights. None by day: a flash
	# lighting a sunlit field is a light nobody sees, and a light switched on is a light the renderer shades every mesh
	# it reaches with. See BurstTuning's LIGHT_*.
	"burst_light": 0.0,
	# THE MOON'S FACE IN THE SKY, how bright: none. The sky draws a moon along the light, so only a preset whose light IS
	# the moon may have one; by day the light is the sun. See NightSkyTuning, and NIGHT's.
	"moon_bright": 0.0,
}

## A LOW WARM SUN WITH LONG SHADOWS, from the west. Seven degrees up throws a shadow eight times the height
## of what casts it, which is the whole look of an evening from the air. The sky is still the ambient, so
## the horizon colours the shade.
##
## LIGHTER THAN IT WAS: the first evening (2026-09-13) had a horizon of (0.93, 0.62, 0.42), fog of (0.76,
## 0.58, 0.46) and the scene's aerial perspective of 0.3, and the far mountains washed out into an orange
## haze. The horizon and the fog are paler and less orange now, and the aerial perspective is a third of
## day's, so a ridge ten kilometres off is still a ridge.
const EVENING: Dictionary = {
	"sun_elevation": 7.0,
	"sun_azimuth": 250.0,
	"sun_colour": Color(1.0, 0.72, 0.48),
	"sun_energy": 0.95,
	"ambient_sky": 1.0,
	"ambient_colour": Color(0.0, 0.0, 0.0),
	"ambient_energy": 0.9,
	"sky_top": Color(0.22, 0.30, 0.52),
	"sky_horizon": Color(0.86, 0.70, 0.58),
	"ground_bottom": Color(0.13, 0.12, 0.11),
	"ground_horizon": Color(0.52, 0.46, 0.42),
	"fog_colour": Color(0.66, 0.60, 0.58),
	"fog_aerial_perspective": 0.1,
	"fog_sky_affect": 1.0,
	# Thicker and lower at evening. See DAY's note. 0.0005, the density chosen by looking in the first evening trial
	# (godotgames-drafts/2026-09-14/cockpit-clouds/p2e-haze-trial): at 0.001 the island from 300 m up was mostly gone.
	# 0.00015 as night's, not 0.00018 (2026-09-15): the low sun's thicker air is the mist's evening haze now (`MistTuning`), and
	# at 0.00018 the clear air alone held evening under the 12 km at 2 m team-lead asked for.
	"clear_air": 0.00015,
	# THE FIRST LIGHTS ON, under half of what night has, so a town at dusk reads as somewhere people are.
	"windows_lit": 0.22,
	"window_glow": 1.2,
	"markers": 0.6,
	"aircraft_lights": 0.75,
	# Between day's and night's.
	"aircraft_dim_to": 3500.0,
	"aircraft_far_bright": 0.25,
	"aircraft_far_least": 0.85,
	# A glow on the ground under a burst at dusk, a third of night's.
	"burst_light": 1.5,
	# No moon: the light is the sun. See DAY's note.
	"moon_bright": 0.0,
}

## DARK, AND STILL READABLE. A dim cool moon high in the south-east gives the ground a direction to be lit
## from, so a ridge and a building have a light side and a dark side; the ambient is a COLOUR rather than
## the sky, because a near-black sky as the ambient is a near-black world and silhouettes vanish into it.
##
## THE MARKERS AT AN EIGHTH: at full brightness the pale wisps and the yellow rings were the brightest things
## on the island at night (2026-09-13), which is backwards for a pale smudge of rising air.
const NIGHT: Dictionary = {
	# THE MOON, 40 degrees up at compass 139.6 -- where `Orrery` puts it at the clock's NIGHT. Until 2026-09-18 this said 140
	# and meant the south-east, but read as azimuth it stood at compass 40, in the north-east, where no moon can stand from
	# the sky's latitude (see Orrery's note). Neither number is read to place anything; they say what this look was tuned under.
	"sun_elevation": 40.0,
	"sun_azimuth": 40.4,
	"sun_colour": Color(0.62, 0.72, 1.0),
	"sun_energy": 0.14,
	"ambient_sky": 0.0,
	"ambient_colour": Color(0.16, 0.20, 0.30),
	"ambient_energy": 0.55,
	"sky_top": Color(0.006, 0.010, 0.026),
	"sky_horizon": Color(0.045, 0.060, 0.095),
	"ground_bottom": Color(0.010, 0.012, 0.016),
	"ground_horizon": Color(0.040, 0.050, 0.070),
	"fog_colour": Color(0.035, 0.045, 0.075),
	"fog_aerial_perspective": 0.3,
	"fog_sky_affect": 1.0,
	# Thinner than evening at night: a dark fog dims the lights it lies over. See DAY's note.
	"clear_air": 0.00015,
	"windows_lit": 0.55,
	"window_glow": 2.2,
	"markers": 0.12,
	"aircraft_lights": 1.0,
	# THE LIGHTS AS THEY WERE before a day's fade: the shader's own fade from 300 m to a third by 5 km, and no shrinking.
	# Lights are how an aeroplane is found at night.
	"aircraft_dim_to": 5000.0,
	"aircraft_far_bright": 0.35,
	"aircraft_far_least": 1.0,
	# The ground and anything flying near lit orange for the moment of the flash.
	"burst_light": 4.0,
	# THE MOON'S FACE, drawn where the light comes from, this bright: its albedo, NightSkyTuning's tint and this, before the
	# tonemapper. The light is the moon at night, so the sky draws the face along it (`world/shaders/sky_night.gdshaderinc`).
	"moon_bright": 3.0,
	# THE TRUE SUN is under the horizon, 26.9 degrees down at the clock's NIGHT, which is what gives the moon its phase: the
	# lit side faces it, 150 degrees from the moon, a waning gibbous 93 per cent lit. `Orrery` works it out; until 2026-09-18
	# it was typed here, 30 degrees down at azimuth 285.
}

## The presets by `When`, in the enum's order.
const PRESETS: Array[Dictionary] = [DAY, EVENING, NIGHT]

## ---- TWILIGHT: two looks between EVENING and NIGHT, which are not presets and have no button ---------------------------
## "Handle special cases like twilight" (2026-09-18). EVENING's sun is 7 degrees up and NIGHT's 27 down, and a straight
## blend between them passes through a grey middle: a sky neither warm nor blue, and an evening light gone brown. So two
## looks stand between, each at the sun's height that names it, and each says what it is LIKE over the three presets, which
## is how the mist and the flare -- tables with three columns -- pass through them. Tuned by looking, on the sunset
## sequence (godotgames-drafts/2026-09-18/cockpit-daytime).

## SUNSET: the sun on the horizon, deep orange and low, the horizon hot and the zenith going violet. Its light fades with the
## sun's height (`SUN_FULL` to `SUN_GONE`), so what this look's sun colour does is colour the last of it.
const SUNSET: Dictionary = {
	"sun_colour": Color(1.0, 0.56, 0.30),
	"sun_energy": 0.9,
	"ambient_sky": 1.0,
	"ambient_colour": Color(0.0, 0.0, 0.0),
	"ambient_energy": 0.8,
	"sky_top": Color(0.17, 0.21, 0.40),
	"sky_horizon": Color(0.94, 0.60, 0.42),
	"ground_bottom": Color(0.10, 0.09, 0.09),
	"ground_horizon": Color(0.46, 0.38, 0.34),
	"fog_colour": Color(0.58, 0.47, 0.44),
	"fog_aerial_perspective": 0.1,
	"fog_sky_affect": 0.4,
	"clear_air": 0.00015,
	# THE LIGHTS COMING ON: between EVENING's first and NIGHT's.
	"windows_lit": 0.35,
	"window_glow": 1.6,
	"markers": 0.4,
	"aircraft_lights": 0.85,
	"aircraft_dim_to": 4000.0,
	"aircraft_far_bright": 0.3,
	"aircraft_far_least": 0.9,
	"burst_light": 2.5,
	"moon_bright": 0.0,
}

## THE BLUE HOUR: the sun 6 degrees down, the end of civil twilight. No sunlight on anything; the sky a deep blue over a
## pale band where the sun went (`DUSK_GLOW`), the ground lit by that sky half and by NIGHT's blue-grey half, and most of
## the windows lit.
const BLUE_HOUR: Dictionary = {
	"sun_colour": Color(0.62, 0.72, 1.0),
	"sun_energy": 0.0,
	"ambient_sky": 0.5,
	"ambient_colour": Color(0.15, 0.18, 0.29),
	"ambient_energy": 0.65,
	"sky_top": Color(0.05, 0.08, 0.19),
	"sky_horizon": Color(0.30, 0.28, 0.36),
	"ground_bottom": Color(0.03, 0.03, 0.04),
	"ground_horizon": Color(0.15, 0.15, 0.19),
	"fog_colour": Color(0.13, 0.14, 0.21),
	"fog_aerial_perspective": 0.2,
	"fog_sky_affect": 0.5,
	"clear_air": 0.00015,
	"windows_lit": 0.48,
	"window_glow": 2.0,
	"markers": 0.2,
	"aircraft_lights": 1.0,
	"aircraft_dim_to": 5000.0,
	"aircraft_far_bright": 0.35,
	"aircraft_far_least": 1.0,
	"burst_light": 3.5,
	"moon_bright": 0.0,
}


## ---- THE LOOK AT ANY TIME: the presets blended by the true sun's elevation --------------------------------------------

## THE LOOKS, BY THE TRUE SUN'S ELEVATION, highest first: the elevation at which each is the whole look, the look, and what
## it is LIKE as weights over DAY, EVENING and NIGHT -- which is how a table of this project's that is keyed by the three
## (`MistTuning`, `OilField`'s flare) is blended at any time, with `blend`, and never with a curve of its own.
##
## DAY FROM 20 DEGREES UP: the old DAY's sun is 34.8 up, and noon at the sky's date is 44.2, so the whole day from mid
## morning is DAY's look and only the sun moves. Below 20 the light goes gold toward EVENING's at 7; below that, down to
## NIGHT's at 12 degrees under the horizon -- nautical twilight's end, when the last of the glow has gone from the west --
## through SUNSET with the sun on the horizon and the BLUE HOUR 6 degrees under it (below). Morning is the same looks
## backwards: the sky here has no side for east and west but the sun's, and the glow stands wherever the sun is.
const DAY_FROM: float = 20.0
const NIGHT_FROM: float = -12.0
const LOOKS: Array = [
	[DAY_FROM, DAY, Vector3(1.0, 0.0, 0.0)],
	[7.0, EVENING, Vector3(0.0, 1.0, 0.0)],
	[0.0, SUNSET, Vector3(0.0, 0.7, 0.3)],
	[-6.0, BLUE_HOUR, Vector3(0.0, 0.3, 0.7)],
	[NIGHT_FROM, NIGHT, Vector3(0.0, 0.0, 1.0)],
]

## THE LIGHT IS THE SUN WHILE THE SUN IS UP, AND THE MOON WHILE IT IS DOWN -- one DirectionalLight3D either way, so a
## shadow costs what it always did. The sun's light fades from its look's whole energy at `SUN_FULL` degrees up to none at
## `SUN_GONE`, as the air it comes through thickens to the horizon; the moon's comes up from none at `MOON_FROM` to its
## whole by `NIGHT_FROM`. The light is handed from one to the other at `SUN_GONE`, where both are dark, so the turn of
## the light's direction from the sun to the moon is never seen.
const SUN_FULL: float = 6.0
const SUN_GONE: float = -1.0
const MOON_FROM: float = -4.0
## THE MOON'S FACE IN THE SKY: drawn whenever the moon is over the horizon (none under it, all of it a degree up), pale by
## day -- `MOON_BY_DAY` of NIGHT's `moon_bright`, a day moon on the blue -- and whole as the sun goes down between
## `MOON_FACE_FROM` and `MOON_FACE_ALL`. So it is SEEN TO RISE, as the user asked of the time-lapse (2026-09-18: "a
## sunrise/sunset/moonrise"): this moon comes up at 18:52 in the east-north-east while the sun is still 7 degrees up.
## DAY AND EVENING KEEP NO MOON because the moon is down at both: 5.5 degrees under the horizon at 10:28, and 0.15 under it
## at 18:51, a minute before it rises (tests/daytime.gd holds each preset's `moon_bright` of 0, so a sky moved to put the
## moon up at either goes red).
const MOON_FACE_FROM: float = 3.0
const MOON_FACE_ALL: float = -8.0
const MOON_BY_DAY: float = 0.25
## THE GLOW ON THE HORIZON WHERE THE SUN IS, round sunset and dawn: added to the sky low down in the sun's direction, its
## colour times its strength, none with the sun `DUSK_GLOW_HIGH` degrees up (EVENING's sun has its own glow, the light's) or
## `DUSK_GLOW_LOW` down (NIGHT has none), and whole between `DUSK_GLOW_FULL`. The sky's gradient is the same all round the
## horizon, so without it the west after sunset is as dark as the east. `world/shaders/sky_night.gdshaderinc`'s
## `dusk_glow_seen`; zero at DAY, EVENING and NIGHT, so no preset changes.
const DUSK_GLOW := Color(1.0, 0.42, 0.18)
const DUSK_GLOW_STRENGTH: float = 1.1
const DUSK_GLOW_HIGH: float = 6.0
const DUSK_GLOW_FULL := Vector2(-4.0, 0.0)
const DUSK_GLOW_LOW: float = -12.0
## HOW MUCH OF NIGHT'S AMBIENT A NIGHT WITH NO MOON KEEPS. NIGHT's was tuned under a moon 93 per cent lit, 40 degrees up; with
## the moon down the world is darker, but never the black it would be with no ambient at all -- the rule NIGHT's own note
## gives, that a ridge and a building must still read.
const MOONLESS_AMBIENT: float = 0.6
## HOW NEAR ITS OWN SUN A LOOK HOLDS WHOLE, degrees. The clock is said to a thousandth of a minute (`Net._anchor_the_clock`),
## which moves the sun up to three ten-thousandths of a degree off a named point; without this the look at EVENING was
## 0.75000000000355 of EVENING's aircraft lights (tests/scenery.gd) rather than EVENING's. The sun crosses it in two and a
## half seconds of a real-time clock.
const LOOK_HOLD: float = 0.01
## THE KEYS OF A PRESET THAT ARE NOT LOOKS: where the sun stood when it was tuned. Kept for `Orrery` to be solved against.
const NOT_BLENDED: Array[String] = ["sun_elevation", "sun_azimuth"]


## WHAT THE WORLD LOOKS LIKE AT `minutes` ON THE CLOCK: every key a preset has, blended, and --
##   "minutes"        the clock
##   "true_sun"       towards the sun, up or down (`Orrery.sun`); "sun_height" its elevation, degrees
##   "moon"           towards the moon; "moon_height" its elevation; "moon_lit" how much of its face is lit, 0 to 1
##   "towards_light"  which way the light comes FROM: the sun's, or the moon's when "light_is_moon"
##   "sun_colour", "sun_energy"  the LIGHT's, whichever it is (as they always were: at night the light is the moon)
##   "moon_light"     the moon's light as the sky draws its halo, a linear colour times energy
##   "stars"          how much of the star field is out (`NightSkyTuning.stars_seen`)
##   "like"           weights over DAY, EVENING and NIGHT, for `blend`
## Static and pure: the same look on every machine at the same clock.
static func look_at(minutes: float) -> Dictionary:
	var sun: Vector3 = Orrery.sun(minutes)
	var moon: Vector3 = Orrery.moon(minutes)
	var height: float = Orrery.elevation(sun)
	var look: Dictionary = _blended(height)
	# THE LIGHT: the sun's look, as it is at the lowest sunlit look, faded out toward the horizon; or the moon's.
	var moon_share: float = moonlight(minutes) / _night_moonlight()
	var is_moon: bool = height <= SUN_GONE
	var sun_seen := Vector3.ZERO
	if is_moon:
		look["sun_colour"] = NIGHT["sun_colour"]
		look["sun_energy"] = float(NIGHT["sun_energy"]) * moon_share * (1.0 - smoothstep(NIGHT_FROM, MOON_FROM, height))
	else:
		var sunlit: Dictionary = _blended(maxf(height, _lowest_sunlit()))
		look["sun_colour"] = sunlit["sun_colour"]
		look["sun_energy"] = float(sunlit["sun_energy"]) * smoothstep(SUN_GONE, SUN_FULL, height)
		sun_seen = sun_seen_as(sunlit["sun_colour"], float(sunlit["sun_energy"]))
	look["minutes"] = fposmod(minutes, Orrery.DAY_LONG)
	look["true_sun"] = sun
	look["sun_height"] = height
	look["moon"] = moon
	look["moon_height"] = Orrery.elevation(moon)
	look["moon_lit"] = Orrery.moon_lit_share(minutes)
	look["light_is_moon"] = is_moon
	look["towards_light"] = moon if is_moon else sun
	# THE SUN'S DISC AS THE SKY DRAWS IT: its look's colour and energy BEFORE the fade toward the horizon, which is the
	# light's own at every preset. The disc replaces the sky with the light it is handed (`sun_disk`), so handed the faded
	# light it drew a dark sun on a bright sunrise (dawn2, 06:20, 2026-09-18).
	look["sun_seen"] = sun_seen
	look["moon_bright"] = float(NIGHT["moon_bright"]) \
		* lerpf(MOON_BY_DAY, 1.0, 1.0 - smoothstep(MOON_FACE_ALL, MOON_FACE_FROM, height)) \
		* smoothstep(0.0, 1.0, float(look["moon_height"]))
	var moonlight_colour: Color = (NIGHT["sun_colour"] as Color).srgb_to_linear()
	var moon_energy: float = float(NIGHT["sun_energy"]) * moon_share
	look["moon_light"] = Vector3(moonlight_colour.r, moonlight_colour.g, moonlight_colour.b) * moon_energy
	var night: float = (look["like"] as Vector3).z
	look["ambient_energy"] = float(look["ambient_energy"]) * lerpf(1.0, lerpf(MOONLESS_AMBIENT, 1.0, moon_share), night)
	look["stars"] = NightSkyTuning.stars_seen(height)
	look["dusk_glow"] = dusk_glow(height)
	return look


## THE DUSK GLOW at a true sun `height` degrees up, a linear colour times its strength. See `DUSK_GLOW`.
static func dusk_glow(height: float) -> Vector3:
	var strength: float = DUSK_GLOW_STRENGTH * smoothstep(DUSK_GLOW_LOW, DUSK_GLOW_FULL.x, height) \
		* (1.0 - smoothstep(DUSK_GLOW_FULL.y, DUSK_GLOW_HIGH, height))
	var linear: Color = DUSK_GLOW.srgb_to_linear()
	return Vector3(linear.r, linear.g, linear.b) * strength


## THE SKY IN WORDS, for the board's readout: what the sun's height makes it, by the names an almanac uses, and whether a
## moon is up at night. Sunrise and sunset are the sun's disc on the horizon (its top at -0.83 degrees, its bottom at +0.27).
static func sky_words(look: Dictionary) -> String:
	var height: float = float(look["sun_height"])
	var rising: bool = float(look["minutes"]) < 720.0 + Orrery.CLOCK_AHEAD
	if height >= DAY_FROM:
		return "DAY"
	if height >= 1.0:
		return "GOLDEN HOUR"
	if height >= -0.83:
		return "SUNRISE" if rising else "SUNSET"
	if height >= -6.0:
		return "CIVIL TWILIGHT"
	if height >= -12.0:
		return "NAUTICAL TWILIGHT"
	if height >= -18.0:
		return "ASTRONOMICAL TWILIGHT"
	return "MOONLIT NIGHT" if float(look["moon_height"]) > 0.0 else "NIGHT"


## A light's colour and energy as the sky shader's LIGHT0_COLOR * LIGHT0_ENERGY has them: linear, times the energy.
static func sun_seen_as(colour: Color, energy: float) -> Vector3:
	var linear: Color = colour.srgb_to_linear()
	return Vector3(linear.r, linear.g, linear.b) * energy


## NIGHT's moonlight, what every other is a share of: worked out once, since it never changes.
static var _night_moonlight_once: float = -1.0


static func _night_moonlight() -> float:
	if _night_moonlight_once < 0.0:
		_night_moonlight_once = moonlight(Orrery.NIGHT_CLOCK)
	return _night_moonlight_once


## HOW BRIGHTLY THE MOON LIGHTS THE GROUND, in no unit: how much of its face is lit, and none as it sinks into the thick air
## at the horizon. Only ever read as a share of NIGHT's (the moon 40 degrees up, 93 per cent lit), so NIGHT is itself; the
## engine does the cosine of the angle to each surface.
static func moonlight(minutes: float) -> float:
	var up: float = Orrery.elevation(Orrery.moon(minutes))
	return Orrery.moon_lit_share(minutes) * smoothstep(-1.0, 8.0, up)


## THE LOOK AT A PRESET'S POINT ON THE CLOCK: what a probe or a suite that thinks in DAY, EVENING and NIGHT hands a yard.
static func look_of(time: int) -> Dictionary:
	return look_at(clock_of(time))


## THE CLOCK AT A PRESET: `Orrery`'s named point of the same name.
static func clock_of(time: int) -> float:
	return Orrery.point(Orrery.point_named(name_of(time)))


## THE PRESETS BLENDED at a true sun `height` degrees up, with "like".
static func _blended(height: float) -> Dictionary:
	var upper: Array = LOOKS[0]
	var lower: Array = LOOKS[0]
	var t: float = 0.0
	if height <= float(LOOKS[LOOKS.size() - 1][0]):
		upper = LOOKS[LOOKS.size() - 1]
		lower = upper
	else:
		for i in range(LOOKS.size() - 1):
			if height <= float(LOOKS[i][0]) and height > float(LOOKS[i + 1][0]):
				upper = LOOKS[i]
				lower = LOOKS[i + 1]
				t = smoothstep(float(lower[0]) + LOOK_HOLD, float(upper[0]) - LOOK_HOLD, height)
				break
	var out: Dictionary = {}
	var high: Dictionary = upper[1]
	var low: Dictionary = lower[1]
	for key in high.keys():
		if key in NOT_BLENDED:
			continue
		out[key] = _mix(low[key], high[key], t)
	out["like"] = (lower[2] as Vector3).lerp(upper[2] as Vector3, t)
	return out


## The height of the lowest look whose light is the sun: below it the sun's colour stays that look's.
static func _lowest_sunlit() -> float:
	var lowest: float = INF
	for row in LOOKS:
		if float(row[0]) > SUN_GONE:
			lowest = minf(lowest, float(row[0]))
	return lowest


## ONE VALUE OF A TABLE KEYED BY `When`, AT A TIME: `values` in the enum's order, weighted by a look's "like". Floats,
## colours and vectors; anything else is taken from the heaviest weight. At a preset's own point "like" is one of the
## three axes, so the value is that column's exactly.
static func blend(values: Array, like: Vector3) -> Variant:
	var heaviest: int = 0 if like.x >= like.y and like.x >= like.z else (1 if like.y >= like.z else 2)
	if like[heaviest] >= 1.0:
		return values[heaviest]
	var a: Variant = values[0]
	var b: Variant = values[1]
	var c: Variant = values[2]
	match typeof(a):
		TYPE_FLOAT, TYPE_INT:
			return float(a) * like.x + float(b) * like.y + float(c) * like.z
		TYPE_COLOR:
			return (a as Color) * like.x + (b as Color) * like.y + (c as Color) * like.z
		TYPE_VECTOR2:
			return (a as Vector2) * like.x + (b as Vector2) * like.y + (c as Vector2) * like.z
		TYPE_VECTOR3:
			return (a as Vector3) * like.x + (b as Vector3) * like.y + (c as Vector3) * like.z
		TYPE_VECTOR4:
			return (a as Vector4) * like.x + (b as Vector4) * like.y + (c as Vector4) * like.z
	return values[heaviest]


## Two values of one key, `t` of the way from `a` to `b`. A value that cannot be blended is `a`'s until halfway.
static func _mix(a: Variant, b: Variant, t: float) -> Variant:
	if t <= 0.0:
		return a
	if t >= 1.0:
		return b
	match typeof(a):
		TYPE_FLOAT, TYPE_INT:
			return lerpf(float(a), float(b), t)
		TYPE_COLOR:
			return (a as Color).lerp(b as Color, t)
		TYPE_VECTOR2:
			return (a as Vector2).lerp(b as Vector2, t)
		TYPE_VECTOR3:
			return (a as Vector3).lerp(b as Vector3, t)
	return a if t < 0.5 else b


## A preset by `When`.
static func preset(time: int) -> Dictionary:
	return PRESETS[clampi(time, 0, PRESETS.size() - 1)]


## Which way the light comes from at a preset's point on the clock: a unit vector. At night this is the moon.
static func towards_the_sun(time: int) -> Vector3:
	return look_at(clock_of(time))["towards_light"]


## WHICH WAY IS TOWARDS THE SUN ITSELF at a preset's point on the clock, lit or not. What the moon's phase is taken from.
static func towards_the_true_sun(time: int) -> Vector3:
	return Orrery.sun(clock_of(time))


static func name_of(time: int) -> String:
	return String(When.keys()[clampi(time, 0, When.size() - 1)])
