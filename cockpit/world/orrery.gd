extends RefCounted
class_name Orrery
## WHERE THE SUN AND THE MOON ARE AT A TIME OF DAY: the sky's clockwork, worked out from the clock and never typed per
## time of day. Static and pure, so a suite, the level, the board and every peer ask the same sums.
##
## Asked for on 2026-09-18: "allow for time of day changes, so we can cleanly have the sun and moon move over time and
## handle special cases like twilight". Until then the sky had three presets and a sun typed into each (`DaylightTuning`).
##
## THE CLOCK is minutes since midnight, 0 to 1440, and it runs AN HOUR AHEAD OF THE SUN (`CLOCK_AHEAD`), as a summer
## clock does: the sun is due south at 13:00. The day never turns into another -- the date is fixed (`SUN_DECLINATION`),
## so tomorrow's sun is today's -- and the moon keeps its age (`MOON_LAG`), so it rises and sets with the sky and does not
## wander a day's worth through the stars at midnight.
##
## THE SUN'S PATH is the textbook one: elevation and bearing from the latitude, the sun's declination and the hour angle,
## the same three numbers an almanac uses. Nothing here is fitted per time of day. What IS fitted, once, are the three
## constants, so that two of the old presets fall exactly on the path:
##
##   DAY     the sun 34.8 degrees up at compass 149.4 (the scene's own DirectionalLight3D, `DaylightTuning.DAY`)
##   EVENING the sun 7.0 degrees up at compass 290.0 (`DaylightTuning.EVENING`)
##
## FOUND BY BISECTION (godotgames-drafts/2026-09-18/cockpit-daytime/solve.py): with the latitude held at 53 N -- the North
## of England, whose midnight sun at this date is 29.8 degrees down, NIGHT's own 30 -- the declination at which DAY and
## EVENING need the same turn of the sky is +7.1725 (mid April, or late August), and that turn is 17.3587 degrees.
## DAY then falls at 10:28 on the clock and EVENING at 18:51; the sun sets at 19:44 and noon stands 44.2 degrees up.
##
## THE SKY IS TURNED 17.4 DEGREES AGAINST THE ISLAND'S GRID (`SKY_TURN`). The island's compass says north is -Z
## (`RadioPhrases.compass`), and with north held there NO real path goes through both presets and still has a dark night:
## the best miss is 5.2 degrees (latitude 59, declination 11), and the exact one is latitude 66.5, declination 14, whose sun
## never goes below 9.4 degrees down -- a white night with no stars and no NIGHT. So the sky's true north lies 17.4
## degrees east of the grid's, as a map's grid north stands off true north, and every shadow DAY and EVENING cast stays
## where it was. REJECTED: moving DAY's and EVENING's suns 4 to 5 degrees.
##
## THE MOON rides the same sky, `MOON_LAG` degrees of hour angle behind the sun and at its own declination, so it rises in
## the east, stands south and sets in the west, and its phase is the real angle between it and the sun. NIGHT's moon was
## typed 40 degrees up at compass 40, in the north-east, which no moon can reach from 53 N (it needs a declination of 64 to
## 70 degrees, and the moon never passes 28.6); its own note says "high in the south-east", so the azimuth's convention had
## been read the wrong way round. At NIGHT (23:30) this moon stands 40.0 degrees up at compass 139.6, a waning gibbous 16.4
## days old and 93 per cent lit, 150 degrees from a sun 26.9 degrees down: the brightness, the height and the phase NIGHT
## was tuned for, in the south-east its note meant.

## The latitude the sky is seen from, degrees north.
const LATITUDE: float = 53.0
## The sun's declination, degrees: the date, fixed. See the note at the top for how it was found.
const SUN_DECLINATION: float = 7.1725
## How far the sky's true north lies clockwise (to the east) of the island's grid north, degrees: a bearing worked out
## in the sky is this much MORE on the island's compass. See the note at the top.
const SKY_TURN: float = 17.3587
## HOW FAR THE CLOCK RUNS AHEAD OF THE SUN, minutes: a summer clock, the sun due south at 13:00.
const CLOCK_AHEAD: float = 60.0
## THE MOON: its declination, degrees, and how far it stands behind the sun in hour angle, degrees -- 199.79, a moon 16.4
## days past new (12.19 degrees a day). Solved with the sun's constants: 40.0 degrees up at compass 139.6 at NIGHT.
const MOON_DECLINATION: float = 15.5334
const MOON_LAG: float = 199.7927

## A day, in minutes.
const DAY_LONG: float = 1440.0

## THE NAMED POINTS ON THE CLOCK, and what each is named by. Two are the old presets' own suns -- the sun at DAY's
## elevation in the morning, at EVENING's in the evening -- so the preset's number stays the one authority; two more are
## twilight, named by the sun's depth; and NIGHT, whose light is the moon, is named by the clock.
enum Point { DAWN, DAY, EVENING, DUSK, NIGHT }
## DAWN: the sun 3 degrees down in the morning, civil twilight, the east pale and the stars going.
const DAWN_ELEVATION: float = -3.0
## DUSK: the sun 4 degrees down in the evening, the blue hour, the first stars out.
const DUSK_ELEVATION: float = -4.0
## NIGHT: half past eleven, the moon 40 degrees up in the south-east (see the note at the top).
const NIGHT_CLOCK: float = 23.0 * 60.0 + 30.0


## ---- the sun ----------------------------------------------------------------------------------------------------------

## THE SUN'S HOUR ANGLE at `minutes` on the clock, degrees: 0 at local noon, growing westward at 15 an hour.
static func sun_hour_angle(minutes: float) -> float:
	return (minutes - CLOCK_AHEAD - 720.0) / 4.0


## TOWARDS THE SUN at `minutes` on the clock: a unit vector in the world, whether the sun is up or not.
static func sun(minutes: float) -> Vector3:
	return _towards(SUN_DECLINATION, sun_hour_angle(minutes))


## TOWARDS THE MOON at `minutes` on the clock: a unit vector in the world, whether the moon is up or not.
static func moon(minutes: float) -> Vector3:
	return _towards(MOON_DECLINATION, sun_hour_angle(minutes) - MOON_LAG)


## HOW MUCH OF THE MOON'S FACE IS LIT, 0 (new) to 1 (full), from the angle between it and the sun as seen from here.
static func moon_lit_share(minutes: float) -> float:
	return 0.5 - 0.5 * sun(minutes).dot(moon(minutes))


## DEGREES ABOVE THE HORIZON of a direction.
static func elevation(towards: Vector3) -> float:
	return rad_to_deg(asin(clampf(towards.normalized().y, -1.0, 1.0)))


## THE COMPASS BEARING of a direction, degrees: 0 along -Z and growing to the right, `RadioPhrases.compass`'s.
static func bearing(towards: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(towards.x, -towards.z)), 360.0)


## A direction in the world from a declination and an hour angle, both degrees: the equatorial sky turned to the
## horizon at `LATITUDE`, then turned `SKY_TURN` onto the island's grid.
static func _towards(declination: float, hour_angle: float) -> Vector3:
	var phi: float = deg_to_rad(LATITUDE)
	var dec: float = deg_to_rad(declination)
	var h: float = deg_to_rad(hour_angle)
	var east: float = -cos(dec) * sin(h)
	var north: float = cos(phi) * sin(dec) - sin(phi) * cos(dec) * cos(h)
	var up: float = sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(h)
	# ONTO THE GRID: a bearing in the sky is SKY_TURN more on the island's compass.
	var turn: float = deg_to_rad(SKY_TURN)
	var grid_east: float = east * cos(turn) + north * sin(turn)
	var grid_north: float = north * cos(turn) - east * sin(turn)
	return Vector3(grid_east, up, -grid_north).normalized()


## ---- the clock ----------------------------------------------------------------------------------------------------------

## WHEN THE SUN STANDS `elevation` DEGREES UP, on the clock: in the morning when `rising`, else in the evening. -1 if it
## never does at this date (above the noon sun or below the midnight one).
static func when_the_sun_is(elevation_degrees: float, rising: bool) -> float:
	var phi: float = deg_to_rad(LATITUDE)
	var dec: float = deg_to_rad(SUN_DECLINATION)
	var c: float = (sin(deg_to_rad(elevation_degrees)) - sin(phi) * sin(dec)) / (cos(phi) * cos(dec))
	if absf(c) > 1.0:
		return -1.0
	var h: float = rad_to_deg(acos(c)) * (-1.0 if rising else 1.0)
	return fposmod(720.0 + CLOCK_AHEAD + h * 4.0, DAY_LONG)


## THE CLOCK AT A NAMED POINT, minutes.
static func point(which: int) -> float:
	match which:
		Point.DAWN:
			return when_the_sun_is(DAWN_ELEVATION, true)
		Point.DAY:
			return when_the_sun_is(float(DaylightTuning.DAY["sun_elevation"]), true)
		Point.EVENING:
			return when_the_sun_is(float(DaylightTuning.EVENING["sun_elevation"]), false)
		Point.DUSK:
			return when_the_sun_is(DUSK_ELEVATION, false)
	return NIGHT_CLOCK


## THE NAMED POINT NEAREST `minutes` round the clock, as a `Point`.
static func nearest_point(minutes: float) -> int:
	var best: int = Point.DAY
	var gap: float = INF
	for which in Point.values():
		var apart: float = absf(wrapf(minutes - point(which), -DAY_LONG * 0.5, DAY_LONG * 0.5))
		if apart < gap:
			gap = apart
			best = which
	return best


## A `Point` by its name, any case, or -1.
static func point_named(name: String) -> int:
	return Point.keys().find(name.to_upper())


static func point_name(which: int) -> String:
	return String(Point.keys()[clampi(which, 0, Point.size() - 1)])


## The clock as a person reads it: "17:45".
static func words(minutes: float) -> String:
	var whole: int = int(floorf(fposmod(minutes, DAY_LONG) + 0.5)) % int(DAY_LONG)
	return "%02d:%02d" % [whole / 60, whole % 60]


## "HH:MM" read back to minutes, or -1 if it is not a time. "24:00" is midnight.
static func minutes_of(text: String) -> float:
	var parts: PackedStringArray = text.strip_edges().split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return -1.0
	var hours: int = parts[0].to_int()
	var mins: int = parts[1].to_int()
	if hours < 0 or hours > 24 or mins < 0 or mins > 59 or (hours == 24 and mins != 0):
		return -1.0
	return fposmod(float(hours * 60 + mins), DAY_LONG)
