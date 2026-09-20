extends RefCounted
class_name NightSkyTuning
## THE MOON AS THE SKY DRAWS IT: how big, the face it wears, how soft its terminator is and how much earthshine the dark
## side keeps. Both skies read these (`world/shaders/sky_night.gdshaderinc`, painted by `Daylight.sky_material`).
##
## Asked for on 2026-09-15: "can you make sure the moon at night has a moon decal, that way it looks like the real moon".
## BEFORE: at night the DirectionalLight is the moon (`DaylightTuning.NIGHT`), and both skies drew it as they draw the sun,
## Godot's procedural light disc and glow in the light's colour. At night's energy of 0.14 that was a faint blue smudge with
## no face and no phase.
##
## WHERE THE MOON STANDS IS NOT A NUMBER HERE. `Orrery` puts it in the sky from the clock (2026-09-18), and the skies draw
## the disc along that direction (`moon_direction`), which is the light's own when the moon is the light. HOW BRIGHT IT IS
## is the time of day's (`DaylightTuning.look_at`'s `moon_bright`), and WHERE THE SUN IS, which sets its phase, is
## `Orrery.sun` at the same clock.
##
## THE FACE is NASA's: the Scientific Visualization Studio's CGI Moon Kit (https://svs.gsfc.nasa.gov/4720), its
## `lroc_color_2k.jpg`, the Lunar Reconnaissance Orbiter Camera's colour mosaic, credited "NASA's Scientific Visualization
## Studio". PUBLIC DOMAIN: the SVS help page (https://svs.gsfc.nasa.gov/help/) says "All of our content is in the public
## domain (unless otherwise noted)", and the kit notes nothing otherwise. The map is equirectangular; the near side was
## baked from it once, off the game, into `world/textures/moon_near_side.png` -- an orthographic view from Earth, lunar
## north up, 512 px, each pixel 3 x 3 samples, and past the limb the limb's own colour, so the mips never average in black.
## A DISC, NOT THE MAP: sampled on the sky, a latitude-longitude map pinches at the poles and seams at the limb, and its
## mip level jumps where the longitude wraps. The far side is never seen from Earth, and the moon always shows one face.

const MOON_FACE_PATH: String = "res://world/textures/moon_near_side.png"

## THE MOON'S SIZE IN THE SKY. The real one is 0.52 degrees across; `MOON_ENLARGED` is how much bigger it is drawn, and the
## one number the disc's size comes from: the sky's `moon_radius`, the stars it hides and how far out its halo is drawn all
## follow `moon_radius()`. 1.5 until 2026-09-17 (0.78 degrees, 14.8 px at a headset's 20 px a degree), then 3.0 when asked
## for "make the moon twice as large at night": 1.56 degrees, 29.6 px. The moon is only drawn at night (DaylightTuning's
## `moon_bright` is 0 by day and at evening), so this is its one size. Its surface brightness is unchanged, so a disc four
## times the area gives four times the light, as a nearer moon would; the halo stays 2 degrees wide, because it stands for
## the glow of the air round the moon and not for the moon itself. Held from pixels by tests/moon_shot.gd, and from the
## number the skies are handed by tests/scenery.gd, both against the old size written down there and not against this.
const MOON_DIAMETER_DEGREES: float = 0.52
const MOON_ENLARGED: float = 3.0

## The colour the face is multiplied by: a little warm of white, the grey-cream the full moon reads as by eye, and not the
## night light's blue, which is a colour for what the moon LIGHTS.
const MOON_TINT := Color(1.0, 0.96, 0.9)
## HOW SOFT THE TERMINATOR IS, as the cosine of the sun's angle to the surface either side of it: 0.05 is about three degrees
## of lunar longitude, so a gibbous moon's shadow edge is a line and not a blur.
const MOON_TERMINATOR: float = 0.05
## EARTHSHINE: the share of the lit face's brightness the dark side keeps with a full Earth over it (a thin crescent), and
## less as the moon waxes and the Earth, seen from the moon, wanes.
const EARTHSHINE: float = 0.02
## THE HALO ROUND THE MOON, in place of the light's glow: its brightness at the disc's edge as a share of the moonlight's colour
## and energy, and the angle outside the disc over which it falls by e. The procedural light glow it replaces reached 30
## degrees and filled a close view with blue (moon-plain-close-gibbous, first probe run, 2026-09-15).
const MOON_HALO: float = 0.5
const MOON_HALO_DEGREES: float = 2.0


## The moon's angular radius in the sky, in radians, as drawn.
static func moon_radius() -> float:
	return deg_to_rad(MOON_DIAMETER_DEGREES * MOON_ENLARGED) * 0.5


## ---- THE STARS (`world/shaders/sky_stars.gdshaderinc`) ----------------------------------------------------------------------
## Asked for with the moon: "have a shader that allows their to be stars".

## The sky's cube has this many cells along a face's edge, 0.94 degrees each, and a star in this share of them: 96 and 0.14
## are about 7,700 over the whole sky and 3,900 above the horizon, the naked eye's count on a dark night.
## 96, NOT 256: a star is asked for only in the cell the pixel is in, so it must fit inside a quarter of a cell (`STAR_MARGIN`)
## at three sigmas. At 256 cells a quarter is 0.088 degrees, and at a 60-degree view 1,260 rows tall three sigmas are 0.13:
## every star faded out, and the first star probe (2026-09-15, stars1) found no star at all -- its "stars" were the letters
## of the observer's label. At 96 a quarter is 0.23 degrees, room for a pixel of up to 0.08 degrees.
const STAR_CELLS: float = 96.0
const STAR_SHARE: float = 0.14
## How steeply a star's brightness falls with its hash: pow(hash, this), so most are faint and a few are bright.
const STAR_POWER: float = 6.0
## The brightest star's peak, before the tonemapper, drawn at a pixel of a twentieth of a degree.
const STAR_BRIGHT: float = 1.5
## A star's sigma in this eye's pixels, and how far from its cell's edges its centre is kept, as a share of the cell.
const STAR_PIXELS: float = 0.9
const STAR_MARGIN: float = 0.25
## The height of the view over which the stars come up out of the horizon's haze, as the view direction's y.
const STAR_HORIZON: float = 0.3
## How far round the moon its light dims the stars, degrees by which that dimming falls by e, and how much of the faintest
## end a fully lit moon washes out across the whole sky.
const STAR_MOON_NEAR_DEGREES: float = 8.0
const STAR_MOON_WASH: float = 0.25
## The two ends of a star's colour: blue-white and orange.
const STAR_BLUE := Color(0.78, 0.86, 1.0)
const STAR_ORANGE := Color(1.0, 0.78, 0.55)
## WHEN THE STARS COME OUT, by the true sun's elevation: none while it is above `STARS_FROM` degrees, all by `STARS_ALL`,
## astronomical twilight's -18. Of the three presets only NIGHT (the sun 27 degrees down) shows them; EVENING's sun is 7
## degrees up, and on the clock they come out through the blue hour.
const STARS_FROM: float = -4.0
const STARS_ALL: float = -18.0


## How much of the star field a sky shows with the true sun `elevation` degrees above the horizon: 0 with it up, 1 in the dark.
static func stars_seen(elevation: float) -> float:
	return 1.0 - smoothstep(STARS_ALL, STARS_FROM, elevation)
