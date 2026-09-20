extends RefCounted
class_name TownTuning
## EVERY NUMBER A TOWN IS TUNED BY, FOR BOTH FINISHES, IN ONE PLACE.
##
## THE DECISION: A FILE, NOT A SLIDER. What a player in a headset can decide is "this is too slow"
## -- that is `Finish` -- and what somebody making FINE look convincing needs is every number that
## changes the picture or its price, together, beside the reason it has the value it has. So the
## window size, the storey height, the fade distances and the light spacing are here and nowhere
## else; the shaders are handed them as uniforms by whatever draws a town, and the generator reads
## the ones that decide a building's shape.
##
## TWO KINDS OF NUMBER, and they are kept apart below because they answer to different things:
##
##   SHAPE, which is the same on both finishes and on every machine, because a building is also a
##   collision box -- change one and the world every peer builds changes with it.
##
##   PICTURE, per finish, which nobody else's machine ever sees -- change one and only the drawing
##   moves.
##
## What a PLACE is like (how tall its centre is, how many towers) is `TownCatalogue`'s.

## ---- shape: the same on every machine and both finishes -----------------------------------

## One storey, floor to floor, metres. Every building's height is a whole number of these, which
## is what lets the window rows in the shader end at the roof instead of being cut through.
const STOREY: float = 3.6
## How ragged a town's edge is, as a fraction of its radius either way. A circle of blocks reads
## as a stamp from the air.
const RAGGED: float = 0.15
## The alley between two lots in one block, metres. Not a street: nobody flies down it.
const ALLEY: float = 6.0
## How far a building stands back from the edge of its lot, least and most, metres.
const LOT_MARGIN_MIN: float = 1.0
const LOT_MARGIN_MAX: float = 4.0
## How likely a block is to be split into four lots rather than kept as one, at the centre and at
## the radius. A downtown block is many buildings; a suburban one is a few.
const SPLIT_NEAR: float = 0.85
const SPLIT_FAR: float = 0.45
## A building no taller than this with a footprint no wider than PITCHED_WIDE gets a pitched roof.
const PITCHED_HIGH: float = 15.0
const PITCHED_WIDE: float = 14.0
## Share of the flat roofs taller than PLANT_HIGH that carry a plant room.
const PLANT_SHARE: float = 0.6
const PLANT_HIGH: float = 20.0
## THE MOST BUILDINGS THE ISLAND MAY HAVE. A count limit, so it DROPS rather than clamps, and says
## so: see `TownPlan.build`. Set against the tick measurement in agents.md.
const MOST_BUILDINGS: int = 1600

## ---- roads: paint, the same on both finishes ----------------------------------------------

## A road between towns, kerb to kerb, metres.
const ROAD_WIDTH: float = 9.0
## How much ground either side of a road is kept clear of rock and buildings.
const ROAD_VERGE: float = 3.0
## How far apart the road is sampled when it is checked against the clearances, metres. Under the
## road's own half-width plus verge, so no box can sit between two samples.
const ROAD_SAMPLE: float = 7.0
## A link that meets a clearance is tried again through a dogleg this far to either side of its
## middle, at one, two and three times.
const DOGLEG_STEP: float = 450.0
## How many links beyond the spanning tree, so there is a loop to fly along; and the longest one.
const EXTRA_LINKS: int = 2
const EXTRA_LINK_LONGEST: float = 4200.0
## Where the paint sits. Under the runway's asphalt top (0.12) so the two never share a plane, and
## the streets a little over the roads, so a road running into the end of an avenue does not
## flicker against it.
const ROAD_TOP: float = 0.07
## ROADS ON THE GENERATED GROUND (increment B5, `TownPlan.roads_on_the_ground`). The grid a road is routed on, metres. The
## steepest step between two of its points, as the rise over the level run between them: 12 %. The 8 % agents.md set out for
## B5 left one airfield strip, at (5363, 600), with no road to it; at 12 % every place is joined and no piece passes 29.6 %.
## How long a piece of road is, metres -- GroundView's own sample spacing, so a pitched piece follows the ground's facets
## about as closely as the ground is drawn. The steepest a piece may rise between its own two ends, over its run: the ground
## between grid points climbs far more than the grid saw, so a route is found again round every step that would. How far
## off a strip's long side a road meets it, metres.
const ROAD_GRID: float = 256.0
const ROAD_GRADE: float = 0.12
const ROAD_PIECE: float = 16.0
const ROAD_CLIFF: float = 0.30
const ROAD_STRIP_SIDE: float = 60.0
## How far round a link's road may go, as its routing cost over the straight distance (a level metre costs 1, the steepest
## step 2): past it the pair is left to a longer pair that reaches, not joined by a road three times the way round.
const ROAD_DETOUR: float = 3.0
const STREET_TOP: float = 0.09
const ASPHALT := Color(0.16, 0.16, 0.17)

## ---- picture: both finishes -------------------------------------------------------------------

## HOW MANY PIXELS A PANE'S SMALLER SIDE MUST SPAN before a facade is drawn as panes rather than as the tone they
## average to. A window a pixel or so across has no edge left to smooth, only a yes or a no per pixel, and it turns on
## and off as the head moves: the shimmer of 2026-09-13. The range fade (WINDOWS_TO) cannot stand in for it, because a
## pixel is a size on the screen and not a distance: it arrives nearer at a grazing angle and at a lower render scale.
## Measured in agents.md, "Why the windows flickered".
const WINDOW_PIXELS_LEAST: float = 2.0
## HOW MANY PIXELS A LIT WINDOW'S SMALLER SIDE MUST SPAN before the lit pattern is drawn on a coarser grid -- two windows
## by two, then four by four -- rather than averaged: averaged, the town from 900 m at night was amber slabs
## (2026-09-13). Lights are bright on dark, so they need more pixels than panes do.
const LIGHT_PIXELS_LEAST: float = 3.0

## ---- picture: PLAIN ---------------------------------------------------------------------------

## A window, as a fraction of a storey tall and of a bay wide.
const PLAIN_WINDOW_TALL: float = 0.45
const PLAIN_WINDOW_WIDE: float = 0.55
## One bay of windows, metres across a facade.
const PLAIN_BAY: float = 3.2
## Past this the window grid fades to the facade's own colour, which is what it averages to anyway:
## a grid finer than a pixel does not average, it shimmers.
const PLAIN_WINDOWS_TO: float = 1400.0

## A LIT WINDOW, on PLAIN: one flat warm colour, the colour of a room with the lights on seen from outside.
## How many are lit, and how brightly, is the time of day's (`DaylightTuning`).
const PLAIN_WINDOW_LIGHT := Color(1.0, 0.76, 0.42)
## HOW BRIGHT A FAR TOWN'S WINDOWS ARE, against the average of its lit windows, on both finishes. Past the window
## fade a facade's glow is what its windows average to, and at full strength a town 2.5 km off at night drew as flat
## glowing orange blocks (2026-09-13): lit windows seen from far off are scattered points with dark wall between, and
## the eye reads the wall. So the averaged glow is a third of the arithmetic, and near windows are untouched.
const FAR_GLOW: float = 0.3

## ---- picture: the far lights, both finishes -----------------------------------------------------

## HOW MANY WINDOWS A SIDE ONE FAR LIGHT STANDS FOR, on every wall: four bays by four storeys. A point carries its windows'
## light, so this sets how many points there are and how much the yard keeps, not how bright a town is. At two, the island
## had 26,772 points and the 220 km memory flight (tests/scenery_memory.gd) peaked at 118.4, 127.5 and 123.7 MB by third,
## inside its five per cent by 0.6 MB; at four, 8,288 points and 83.4, 87.0 and 85.4 MB, against 67 MB before any far
## light (2026-09-15). Looked at: the towers at 1 km still read as lit window grids and the city at 2 km as points.
## Laid on PLAIN_BAY, which FINE_BAY equals; a FINE bay of its own would move the points and keep the light.
const FAR_LIGHT_WINDOWS: int = 4
## THE LEAST HALF-WIDTH OF A FAR LIGHT, pixels: a tent this wide sums to the same light wherever a pixel centre falls, so
## a point never flickers as it crosses pixels or differs between two eyes. Asked for at "at least about 1.5 px".
const FAR_LIGHT_PIXELS: float = 1.5
## THE FAINTEST PEAK A FAR LIGHT IS DRAWN AT before it is thinned instead of dimmed, in the linear light the tonemapper is
## handed. Night's sky and fog are about 0.005 there. 0.03, 0.015 and 0.01 drew the city at 10 and 15 km over the mist to
## the same hundredth (2026-09-15): out there a gathered point is brighter than any of them, so this binds only in thick
## fog. 0.015, the value the spacing was chosen at.
const FAR_LIGHT_LEAST: float = 0.015
## THE FEWEST PIXELS BETWEEN TWO FAR LIGHTS before they are gathered: only the share that would stand this far apart is
## drawn, each carrying the light of the ones it stands for. Every 2x2 cluster drawn put one 2.7 px from the next at
## 2 km, and a tower drew as a lit maze (2026-09-15). Chosen by looking, PLAIN at night over the mist: at 4 px the city
## was 65 points at 5 km and 3 at 15 km, brightest 0.250; at 3 px, 90 and 4, brightest 0.255, still points with dark
## between; at 2 px the far points dimmed to 0.166 and the 5 km town began to run together.
const FAR_LIGHT_SPACING: float = 3.0
## How far a far light stands out from its wall, metres: clear of the wall's own depth.
const FAR_LIGHT_OFF_WALL: float = 0.5
## HOW FAR A FAR LIGHT'S QUAD MAY REACH PAST ITS BATCH'S BOX, metres, so no point at the edge of the frame is culled with
## its box: a point at the camera's 24 km is 1.5 px of about 18 m at the desk's 75 degrees and 1,260 rows, and a headset's
## pixels are smaller. The engine sizes a batch's box from its instances' 2 m quads, not from where the shader puts them.
const FAR_LIGHT_CULL_MARGIN: float = 100.0

## ---- picture: lamps -- obstruction lights, both finishes -----------------------------------------

## HOW MUCH LIGHT A CANDELA IS, in what the town's shaders draw with: luminance times square metres, which is what a far light
## carries (`town_lights.gdshaderinc`). One scale, from the windows the town already has: a PLAIN window is 1.76 by 1.62 m,
## 2.85 m2, glowing 2.2 at night, 6.3 of this light; a lit office window seen from outside is about 200 cd/m2 (so 570 cd),
## which puts a candela at 0.011. Every lamp is its candela times this, so an obstruction light and a window stay in the
## proportion they have in life, and a brighter town is one number.
const LIGHT_PER_CANDELA: float = 0.011
## A BUILDING TALLER THAN THIS CARRIES OBSTRUCTION LIGHTS, metres: ICAO Annex 14 Vol I 6.3.7, "an object ... greater than
## 45 m" takes medium-intensity lights, and FAA AC 70/7460-1M lights a structure over 150 ft (46 m) with L-864. The island
## has 13 (2026-09-15): ten towers of 118.8 to 212.4 m and three blocks of 46.8 to 50.4 m.
const OBSTRUCTION_HIGH: float = 45.0
## THE MOST METRES BETWEEN TWO LEVELS OF OBSTRUCTION LIGHTS on one building, from its top to the ground: ICAO 6.3.17, for
## medium-intensity Type B over 45 m, "spaced as equally as practicable ... not exceeding 52 m", the levels below the top
## alternately low-intensity Type B (steady) and medium-intensity Type B (flashing). Measured from the ground, not from the
## tops of nearby buildings, which 6.3.17 also allows.
const OBSTRUCTION_LEVELS_APART: float = 52.0
## HOW BRIGHT, candela, at night: Table 6-3, medium-intensity Type B 2,000 cd flashing red, low-intensity Type B 32 cd
## steady red. The table's vertical beam (3 % at 10 degrees below the horizontal) is NOT drawn: a pilot 900 m up and 5 km
## off looks at a roof 10 degrees down, where every medium light on the island would fall to 60 cd.
const OBSTRUCTION_MEDIUM_CANDELA: float = 2000.0
const OBSTRUCTION_LOW_CANDELA: float = 32.0
## HOW BIG THE LANTERN IS, metres across: the least a light is drawn at close to, before its pixel floor takes over.
const OBSTRUCTION_LANTERN: float = 0.4
## AVIATION RED, linear: the colour a red obstruction light is seen as.
const OBSTRUCTION_RED := Color(1.0, 0.06, 0.03)
## HOW OFTEN A MEDIUM LIGHT FLASHES, a minute: FAA AC 70/7460-1M's 30 for L-864s flashing together, inside ICAO Table 6-3's
## 20 to 60. Half a flash a second, a quarter of the 2 Hz under which a flash is not a strobe.
const OBSTRUCTION_FLASHES_A_MINUTE: float = 30.0
## HOW LONG A FLASH IS ON, seconds, and how long it takes to come on and go off inside that. Neither document read gives an
## on-time for a medium red; half a second of a two-second cycle, eased over a tenth, was chosen by looking.
const OBSTRUCTION_FLASH_ON: float = 0.5
const OBSTRUCTION_FLASH_EASE: float = 0.1
## THE BRIGHTEST PIXEL A LAMP IS DRAWN AT before it is drawn wider instead, and the widest it is drawn so, in pixels: a lamp
## close to is a small bright spot, not a disc of glare. See lamp.gdshaderinc.
const LAMP_PEAK_MOST: float = 4.0
const LAMP_GROW_MOST: float = 3.0
## A LAMP IS NOT LOST FOR BEING SPREAD OVER PIXELS. A point of light is seen by the illuminance it puts on the eye (Allard's
## law; ICAO Doc 9328 works out a light's visual range at night with a threshold of 1e-6 lux), not by how bright a pixel is,
## and a screen cannot show that: a 2,000 cd red at 10 km, spread over its 1.5 px tent, drew at 0.005 of linear light over
## the mist, and 7 red points were found in the city's box (2026-09-15). So a lamp whose illuminance IN CLEAR AIR -- candela
## over distance squared -- is over `LAMP_SEEN_LUX` is drawn at no less than `LAMP_SEEN_PEAK` before the fog, eased in over
## `LAMP_SEEN_BAND` times the threshold so none pops, and the fog's transmission then takes its share of that as of any
## light. THE FLOOR IS BEFORE THE FOG, NEVER AFTER: first built after it, a lamp over the threshold drew at the floor however
## thick the mist, which is a light shining through fog that stops it. One threshold, night's: the lamps are dark by day.
const LAMP_SEEN_LUX: float = 0.000001
const LAMP_SEEN_BAND: float = 4.0
const LAMP_SEEN_PEAK: float = 1.0

## ---- picture: lamps -- street lights, both finishes -------------------------------------------

## THE STREET LIGHTS ARE SWITCHED OFF, since 2026-09-15: "The streetlights take up too many resources, let's remove them from
## the cities (but keep them around we will use them at some point)" -- the user, flying PC VR on PLAIN. Off, `TownView` makes
## nothing of theirs: no lit street filed, no lamps', poles' or pools' batch, buffer, mesh or material, and no railway asked.
## The windows' far lights and the obstruction lights on tall buildings stay. Every number below is kept for the day they are
## turned on again (agents.md, "Street lights"); tests/night_lights.gd drives them on through `TownView.street_lights_in_tests`.
const STREET_LIGHTS_ON: bool = false
## A STREET AT LEAST THIS WIDE IS A MAIN ROAD, metres, and its lamps stand `STREET_LIGHT_TALL` high; a narrower one's
## `STREET_LIGHT_LOW`. The catalogue's streets are 32 m in a city and 14 m in a town.
const STREET_LIGHT_WIDE: float = 20.0
const STREET_LIGHT_TALL: float = 10.0
const STREET_LIGHT_LOW: float = 8.0
## HOW FAR APART, as mounting heights: the rule of thumb road lighting is laid out by (spacing about 3.5 to 4 times the
## height for uniformity on a lit street), so 36 m in a city and 28.8 m in a town, inside the 30 to 40 m asked for. Laid at
## an even pitch of whole lamps a block, half a pitch in from each junction: three in a city's 96 m block and two in a
## town's 64 m, 32 m either way -- 3.2 and 4 mounting heights.
const STREET_LIGHT_SPACING_PER_HEIGHT: float = 3.6
## ON WHICH SIDES, by the street's width over the mounting height: one side up to 1, staggered up to 1.5, opposite beyond
## (CIE 115's usual arrangements). A city street is 3.2 heights wide and a town street 1.75: both opposite.
const STREET_LIGHT_ONE_SIDE: float = 1.0
const STREET_LIGHT_STAGGERED: float = 1.5
## HOW FAR IN FROM THE STREET'S EDGE THE POLE STANDS, and how far its arm reaches over the street, metres.
const STREET_LIGHT_KERB: float = 0.8
const STREET_LIGHT_ARM: float = 1.8
## HOW MUCH CLEAR STREET A POLE LEAVES A CROSSING STREET, metres past its edge, on a street that does not keep the corners
## (a street along z: see `TownView.street_lights_along`), and a railway track, metres either side.
const STREET_LIGHT_JUNCTION_CLEAR: float = 4.0
const STREET_LIGHT_RAIL_CLEAR: float = 8.0
## HOW BRIGHT, candela, straight down: a 100 W LED street lantern of about 12,000 lumens peaks near 6,000 cd.
const STREET_LIGHT_CANDELA: float = 6000.0
## HOW MUCH OF THAT IT SHOWS SIDEWAYS AND FROM ABOVE: a semi-cut-off lantern's glass seen from off its beam.
const STREET_LIGHT_SIDE_SHARE: float = 0.15
## High-pressure sodium, linear: the orange of a lit street seen from the air.
const STREET_LIGHT_COLOUR := Color(1.0, 0.62, 0.26)
const STREET_LIGHT_LANTERN: float = 0.6
## THE STREET'S REFLECTANCE, and how far a pool reaches, in mounting heights: dark asphalt is 0.07 to 0.1.
const ROAD_REFLECTANCE: float = 0.08
const POOL_REACH: float = 2.5
## WHERE A POOL HANDS ITS LIGHT TO ITS LAMP, metres: from 0.55 of this to all of it (lamp_pool.gdshaderinc). A pool 25 m
## across is 20 px wide at 1.5 km on the desk, and a sliver at a grazing angle.
const POOL_TO: float = 1500.0
## HOW FAR A POLE IS DRAWN, metres from the eye to its kilometre: an 18 cm pole is a sixth of a pixel at 1 km.
const POLES_TO: float = 1000.0
## A POOL LIES THIS FAR OVER THE STREET'S TOP, metres, and is pulled towards the eye by this share of its distance, so the
## street's own surface does not win the depth test far off: half a metre at 1 km.
const POOL_LIFT: float = 0.03
const POOL_PULL: float = 0.0005
## A pole's colour: painted grey steel.
const STREET_POLE_COLOUR := Color(0.24, 0.25, 0.26)

## ---- picture: the night's adaptation ---------------------------------------------------------

## HOW BRIGHT THE MOON LIGHTS A STREET, lux: a gibbous moon, 93 % lit, 40 degrees up (NIGHT's), about half of a full moon
## overhead's 0.25 lux. A real, dark-adapted eye's reference for what an unlit street looks like at night.
const MOONLIGHT_LUX: float = 0.12
## STEVENS' POWER LAW FOR BRIGHTNESS: seen brightness goes as luminance to about the third power for an extended target, so a
## street a thousand times brighter looks ten times as bright, not a thousand.
const BRIGHTNESS_EXPONENT: float = 1.0 / 3.0


## HOW MUCH BRIGHTER THAN ITS LUMINANCE A LIT STREET IS DRAWN, for an eye adapted to the night: the NIGHT preset's own
## moonlit street, as it is drawn, taken as what a real moonlit street (`MOONLIGHT_LUX` on `ROAD_REFLECTANCE`) looks like,
## and a street under a lamp drawn as much brighter than that as it LOOKS -- its luminance over the moonlit street's, to
## `BRIGHTNESS_EXPONENT` -- then divided by what the one `LIGHT_PER_CANDELA` scale would draw it at.
##
## WHY NOT 1. The windows set that scale, a lit window's 200 cd/m2 at their glow of 2.2, and on it a street's 1.5 cd/m2
## under its lamp drew at 0.017 of linear light, which nobody could see from 300 m (2026-09-15): the night here is not drawn
## to a photometer, so light on the ground has to be drawn to the eye. Worked out from the preset, never typed, so a darker
## or brighter NIGHT moves it. About 13 today. The same law puts a 200 cd/m2 window at about 1.1 against its tuned 2.2, so
## the windows are drawn about twice as bright as this eye would see them; theirs is the town lane's tuning and is kept.
##
## WORKED OUT, NOT CHOSEN: an eye-chosen 8 was built first and rejected for being a free number (team-lead, 2026-09-15); 16 and
## 32 had washed the avenue out to haze in the same pictures.
static func night_adaptation() -> float:
	var night: Dictionary = DaylightTuning.NIGHT
	var ambient: Color = night["ambient_colour"]
	var moon: Color = night["sun_colour"]
	# THE MOONLIT STREET AS NIGHT DRAWS IT, linear: the asphalt's albedo under the ambient colour and the moon's light on the flat.
	var drawn: float = ASPHALT.get_luminance() * (ambient.get_luminance() * float(night["ambient_energy"])
		+ moon.get_luminance() * float(night["sun_energy"]) * sin(deg_to_rad(float(night["sun_elevation"]))))
	var moonlit: float = ROAD_REFLECTANCE * MOONLIGHT_LUX / PI
	var under_a_lamp: float = ROAD_REFLECTANCE * STREET_LIGHT_CANDELA / (PI * STREET_LIGHT_TALL * STREET_LIGHT_TALL)
	var seen: float = drawn * pow(under_a_lamp / moonlit, BRIGHTNESS_EXPONENT)
	return seen / (LIGHT_PER_CANDELA * under_a_lamp)


## ---- picture: FINE ----------------------------------------------------------------------------

## A LIT WINDOW, on FINE: each one somewhere between a warm lamp and a cool screen, by a hash of the window,
## and between LIGHT_LEAST and 1 of the glow, so a lit facade is rooms rather than a lit panel.
const FINE_WINDOW_WARM := Color(1.0, 0.70, 0.36)
const FINE_WINDOW_COOL := Color(0.78, 0.86, 1.0)
## The share of lit windows that are the cool colour rather than the warm one.
const FINE_WINDOW_COOL_SHARE: float = 0.25
const FINE_WINDOW_LIGHT_LEAST: float = 0.45

const FINE_WINDOW_TALL: float = 0.52
const FINE_WINDOW_WIDE: float = 0.62
const FINE_BAY: float = 3.2
const FINE_WINDOWS_TO: float = 2200.0
## How deep a window frame reads, as a fraction of a bay. Shading, not geometry.
const FINE_FRAME_DEPTH: float = 0.08
## The ground floor band: a storey of different colour and bigger openings.
const FINE_GROUND_BAND: bool = true
## FINE's roof dressing is drawn INSIDE the collision box, never outside it: a setback steps in by
## at most this, in the top SETBACK_FROM of the height. See agents.md for why that is the rule.
const FINE_SETBACK_MOST: float = 4.0
const FINE_SETBACK_FROM: float = 0.7
