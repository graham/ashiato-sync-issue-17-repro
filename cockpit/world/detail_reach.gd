extends RefCounted
class_name DetailReach
## HOW NEAR YOU HAVE TO BE BEFORE A SURFACE IS WORTH DRAWING IN DETAIL, AND THE ONE PLACE THAT KNOWS.
##
## A SECOND AXIS, AND NOT `Finish`'S. `Finish` is a tier: one word the player flips with a thumb, PLAIN or FINE, the
## same everywhere in the world at once. This is distance, and it is not a quality setting at all -- it is what stops a
## surface sparkling when its detail gets smaller than a pixel, which is far more obvious in a headset than on a
## monitor. The two compose: a runway wants its joints and its rubber on short final on EITHER tier, and FINE adds
## grain on top of the same joints rather than switching a different runway on.
##
## That axis already existed when this file was written -- `detail_fade(dist, full, gone)` in
## `terrain_noise.gdshaderinc`, with the comment that says exactly the above. What did not exist was anywhere to keep
## its numbers, and that is what this is.
##
## THE DECISION: ONE AUTHORITY FOR EVERY SURFACE, NOT ONE PER SURFACE. House rule 4 is one number, one place. When
## this was written there were TEN ranges typed literally into SIX shaders and one partial authority (`RockTuning`,
## which owns rock's and the mountains' and nothing else). A pavement-only authority beside it would have made two
## partial authorities and ten literals, which is house rule 4 broken in a tidier-looking new place. So this is named
## for the axis and not for the pavement, every surface belongs in it, and the ones not moved across yet are listed in
## `todo/detailshaders--migrate-detail-ranges.md` with their files and their values. The authority is INCOMPLETE, which
## is an honest state; two of them would not have been.
##
## NOT AN AUTOLOAD. `SceneryFinish` has to be both a class and an autoload because a constant elsewhere
## (`PilotRig.DESK_KEYS`) cannot read a constant off a node that does not exist until the game runs. Nothing here is
## state -- there is no tier to remember, only numbers -- so a static class is the whole of it, and it can be read from
## a const context for free.
##
## THE RANGES ARE IN METRES and are (full, gone): the detail is drawn whole nearer than `full`, fades across the band,
## and is not computed at all past `gone`. They are handed to a material as uniforms at build; no shader types one.

## THE ONE DIAL OVER ALL OF THEM. Every range below is multiplied by this, so pushing detail further out is one number
## and its cost is one measurement rather than a guess per surface. 1.0 is what the game ships at; the measurements in
## `learnings/2026-09-20-detailshaders.md` are taken at 1.0 and at 2.0 so the slope of that cost is known and not
## assumed.
const REACH: float = 1.0

## THE PAVEMENT'S GRAIN: the aggregate in the asphalt, centimetres across. Gone by 160 m because that is roughly where
## it stops being a pixel; drawing it further out buys nothing and is the exact thing that crawls in a headset.
const PAVEMENT_GRAIN := Vector2(30.0, 160.0)
## THE PAVEMENT'S WEAR: the paving-lane seams, the rubber in the touchdown zone and the staining. Metres across rather
## than centimetres, so it survives much further out -- and it has to, because the touchdown zone going dark is a cue a
## pilot uses from the whole way down the approach, not something noticed on the roll.
const PAVEMENT_WEAR := Vector2(300.0, 1400.0)


## THE GROUND'S TWO BANDS, which existed as literals in `grass.gdshader` and `grass_fine.gdshader` before this file
## did and are the reason it is named for the axis rather than for the pavement. The user asked for near detail on
## "the ground, the concrete and taxi ways, the runways as well"; the ground already had it, two bands deep, with a
## comment saying blades past the far edge are sub-pixel and "all they do is boil". What it did not have was a dial.
##
## CLUMPS are tens of metres across -- the mottling and the bare earth where the grass thins -- and survive to 3 km.
## BLADES are the near band, and 260 m is where they stop being a pixel.
const GROUND_CLUMPS := Vector2(600.0, 3000.0)
const GROUND_BLADES := Vector2(40.0, 260.0)


## THE GROUND'S RANGES, by the name of the uniform each is read as -- set on both grass materials at build by
## `Sky._build`. Same shape and same `reach` as the pavement's, so the one dial moves the ground and the runway
## together, which is what makes it a dial rather than two numbers that happen to be multiplied.
static func ground_numbers(reach: float = REACH) -> Dictionary:
	return {
		"clump_fade": GROUND_CLUMPS * reach,
		"blade_fade": GROUND_BLADES * reach,
	}


## EVERY RANGE THE TWO PAVEMENT SHADERS READ, by the name of the uniform each is read as -- set on the material once,
## at build, by whoever draws the pavement (`Sky._draw_runway`).
##
## `reach` IS EXPLICIT AT ITS OWN CALL SITE and defaults to the shipped `REACH`. The probe that measures what pushing
## the threshold out costs passes 2.0 here rather than editing the constant, so the measurement and the game read the
## same code path and the number it measured is named in the run that measured it.
static func pavement_numbers(reach: float = REACH) -> Dictionary:
	return {
		"grain_fade": PAVEMENT_GRAIN * reach,
		"wear_fade": PAVEMENT_WEAR * reach,
	}
