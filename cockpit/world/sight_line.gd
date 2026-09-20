extends RefCounted
class_name SightLine
## CAN THIS POINT SEE THAT ONE, OR IS THERE GROUND IN THE WAY: the one question that decides whether flying low
## through a canyon hides you.
##
## WHY IT IS ITS OWN FILE, AND WHY IT IS FOUR LINES. Radar (`world/radar_set.gd`) needs to know whether a contact is
## masked by terrain; `lane/rivers` is cutting canyons whose stated purpose is concealment. Those are two lanes asking
## one question, and the way that goes wrong is each answering it. So there is one function, it is here, and it is
## named for what it is asked rather than for who asks it.
##
## ---------------------------------------------------------------------------------------------------
## IT IS NOT NEW ARITHMETIC. IT IS A NAME FOR ARITHMETIC THAT WAS ALREADY HERE.
## ---------------------------------------------------------------------------------------------------
##
## `CockpitWorld.ground_leg_is_clear` has answered this since the generated ground landed, and it covers BOTH grounds
## -- `Bedrock`'s height fields and `Massif`'s mountain triangles -- through one shared max-pyramid
## (`ashiato-gd/src/cockpit/height_pyramid.hpp`). Grepping for `line_of_sight`, `can_see` or `occlu` finds nothing,
## which is how two surveys in one night each concluded cockpit had no such thing: **it is named for a flight leg,
## because the autopilots were the first to need it.**
##
## So nothing here re-derives a ray against the terrain, and nothing here should ever start to. Writing a second
## sampler -- walking `Terrain.highest_near` along the ray, which is what both surveys proposed -- would have been
## slower, coarser, and a second opinion about what the ground is.
##
## ---------------------------------------------------------------------------------------------------
## THE BIAS, WHICH MATTERS MORE FOR HIDING THAN IT DID FOR FLYING
## ---------------------------------------------------------------------------------------------------
##
## The pyramid's own contract (`height_pyramid.hpp`): *"it may call a clear leg blocked and never the other way."*
## A leg is clear when its lower end stands above the highest ground under its footprint; if not it is halved, down
## to one 32 m square, and a piece still not clear is blocked.
##
## For an autopilot that is fail-safe: it may refuse a route that would have been fine, and it will never fly one
## into a hill. **Read as sight it says: it may call a VISIBLE contact HIDDEN, and it will never call a hidden one
## visible.** That is the right way round for concealment -- a pilot who has taken cover is never wrongly exposed by
## a rounding -- and it is worth saying out loud because it is not neutral: **terrain conceals slightly MORE than
## geometry alone would.** The grain is the pyramid's 32 m square.
##
## THAT IS ALSO THE ANSWER TO "CONCEALED FROM WHAT?" A craft is hidden from radar exactly when it is hidden from the
## same pyramid the AI flies its legs by. One authority, two questions, so a canyon that hides you cannot also be a
## canyon the traffic routes itself through as though it were open sky.
##
## ---------------------------------------------------------------------------------------------------
## CLEARANCE AND OVERHEAD ARE BOTH ZERO, AND THAT IS THE DIFFERENCE FROM A LEG
## ---------------------------------------------------------------------------------------------------
##
## `clearance` widens the leg's footprint and `overhead` is how far above the ground it must pass; an aeroplane's
## autopilot asks for 90 m of each because it wants ROOM. Sight wants neither: a sight line is blocked only when the
## rock is actually in it, and a radar beam passing ten metres over a ridge has seen past it. Asking sight at an
## autopilot's clearance would hide every contact flying low over open farmland.
##
## WHAT IT COSTS: 0.7 to 0.8 microseconds for a 3 km leg, measured in the generated ground's phase 1, 12 to 130 times
## cheaper than asking Box3D (`bedrock.hpp`). A radar sweep of ninety contacts is therefore well under a tenth of a
## millisecond, which is why `RadarSet` asks it per contact per sweep and does not cache.
##
## WHICH WORLD TO ASK IS THE CALLER'S, AND IT SHOULD BE THE SERVER'S. The ground is built identically in every world
## (`Sim._worlds`, "the one place the 'build it identically in both' rule is written down"), so a client gets the same
## answer -- but a detection is the authority's (rule 10), and a client asking it of itself is a client deciding what
## it is allowed to see.


## WHETHER THE GROUND LEAVES THE LINE FROM `from` TO `to` OPEN, asked of `world` -- a `CockpitWorld`, and on a host it
## should be `Sim.server`.
##
## TRUE WITH NO WORLD, NO GROUND OR NO METHOD, which is the same answer `Terrain._ground_clears` gives and is the only
## safe default: a level with no terrain built conceals nothing, and a radar that went blind because the ground was
## missing would be a sensor failing closed with no way to tell.
static func is_clear(world: Object, from: Vector3, to: Vector3) -> bool:
	if world == null or not world.has_method("ground_leg_is_clear"):
		return true
	return bool(world.ground_leg_is_clear(from, to, 0.0, 0.0))


## THE SAME QUESTION WITH THE EYE LIFTED, for a head that sits on a mast or a hill: `head_m` metres are added to
## `from`'s height before the line is drawn. A radar aerial is not at the ground's surface, and putting the eye at
## surface level makes every radar on flat ground blind at any range, because the ground is in its own line.
static func is_clear_from_height(world: Object, from: Vector3, to: Vector3, head_m: float) -> bool:
	return is_clear(world, from + Vector3(0.0, head_m, 0.0), to)
