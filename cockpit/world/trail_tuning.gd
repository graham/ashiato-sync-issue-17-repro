extends RefCounted
class_name TrailTuning
## EVERY NUMBER A TRAIL IN THE SKY IS TUNED BY, IN ONE PLACE: how long a missile's smoke lasts, and how an aircraft's
## contrail is made from it.
##
## THE DECISION: A CONTRAIL IS A SHARE OF A MISSILE'S TRAIL, NOT A NUMBER OF ITS OWN. Asked for on 2026-09-13 --
## contrails for planes above 300 m, "shorter than missiles" -- and a contrail given its own lifetime typed beside the
## missile's is a contrail that stops being shorter the day somebody lengthens the missile's. So the missile's life is
## here, and a contrail lasts `CONTRAIL_SHARE` of it on whichever finish is worn.
##
## WHAT WENT WRONG BEFORE: the missile's life was the `life` uniform's default in `contrail.gdshader` (14 s) and
## `contrail_fine.gdshader` (22 s), which only the GPU could read -- headless, the dummy renderer has no shader to ask,
## so a test could not hold a contrail shorter than a number it could not see. It is written onto both trail materials
## once, by `MissileYard`, and the shaders keep no default for it.
##
## 300 METRES IS WORLD Y, which is height above the sea (`Terrain.SEA_LEVEL` is 0 and there is no floating origin), not
## height above the ground. Real contrails form at eight kilometres; this island's traffic cruises between 260 and 880 m
## (`Terrain.waypoints`), so the height is the one the user asked for rather than the atmosphere's.

## How long a missile's trail lasts, in seconds, on each finish: FINE's smoke lingers, PLAIN's is cheaper to fill a sky
## with. The numbers the shaders had as defaults until 2026-09-13.
const MISSILE_LIFE_PLAIN: float = 14.0
const MISSILE_LIFE_FINE: float = 22.0

## AN AIRCRAFT'S CONTRAIL LASTS THIS SHARE OF A MISSILE'S TRAIL: 4.2 s PLAIN and 6.6 s FINE.
const CONTRAIL_SHARE: float = 0.3

## THE HEIGHT A CONTRAIL APPEARS AT, and the band it fades in over, in metres of world Y. Faded rather than switched, so
## an aeroplane climbing through 300 m draws a trail that thickens out of nothing instead of one that pops on.
const CONTRAIL_ALTITUDE: float = 300.0
const CONTRAIL_BAND: float = 40.0

## AND ONLY WHILE IT IS FLYING, in m/s of ground speed. An aeroplane parked on a hilltop above the band, or hanging at the
## top of a stall, leaves no trail. A fade too, so a slow one leaves a faint one. Under every winged cruise the simulation
## reports (2026-09-14, `tests/contrail_shot.gd --views=lengths`): the Cessna 49.4, the tanker 52.0, the airliner 65.1,
## the aeroplane 71.9, the Osprey 74.3 -- so every one of them cruising leaves a whole trail.
const CONTRAIL_SPEED_FROM: float = 20.0
const CONTRAIL_SPEED_TO: float = 35.0

## A TILTROTOR'S NACELLES, on the `tilt` channel's 0 (forward) to 1 (up): its trail is gone by the time they are half way
## to hovering, because a tiltrotor hovering is a helicopter and helicopters leave none.
const CONTRAIL_TILT_FROM: float = 0.25
const CONTRAIL_TILT_TO: float = 0.5

## HOW OFTEN AN AIRCRAFT LAYS A SEGMENT, in seconds. Longer than a missile's 0.08 because a contrail segment is laid and
## never touched: nothing grows behind the wingtip, so between samples an aircraft costs a lookup, and the gap behind the
## aeroplane is where a real contrail has not condensed yet.
const CONTRAIL_SAMPLE_EVERY: float = 0.2
## HOW A CONTRAIL COMES IN BEHIND THE AIRCRAFT, in seconds of age, worked out at every pixel by the trail shaders: nothing
## for the first `CONTRAIL_SAMPLE_EVERY` -- so the segment just laid is nothing at its newer end and a trail's head never
## arrives in a piece -- then smoothly in over `CONTRAIL_FORMING`, which at the aeroplane's 80 m/s cruise is 80 m.
## WAS 0.5, and a whole segment thickened in by the age of its newer end: two neighbours laid 0.2 s apart stood 0.4 of
## the way apart, and "it's a little obvious they are chunky" (2026-09-14).
const CONTRAIL_FORMING: float = 1.0
## HOW MANY CONTRAIL SEGMENTS THE WHOLE SKY HOLDS, the oldest taken back first. A trail on FINE is 6.6 / 0.2 = 33
## segments and an aircraft lays two, so 2048 is 31 aircraft trailing at once. Measured 2026-09-14 with the island's own
## traffic and twenty winged aircraft added (93 machines, past the 52 the wire keeps fresh): 28 trailing kept 1,638 in
## use on FINE and 1,224 on PLAIN (`tests/contrail_shot.gd --views=contrail_cost`). Past 31, what is taken back is the
## oldest and faintest end of a trail, so a trail shortens rather than a new one failing to appear.
const CONTRAIL_SEGMENTS: int = 2048


## A missile trail's life, in seconds, for a finish.
static func missile_life(fine: bool) -> float:
	return MISSILE_LIFE_FINE if fine else MISSILE_LIFE_PLAIN


## How strongly an aircraft at this height leaves a contrail, 0 to 1, before its speed and its nacelles.
static func contrail_at_height(height: float) -> float:
	return smoothstep(CONTRAIL_ALTITUDE - CONTRAIL_BAND * 0.5, CONTRAIL_ALTITUDE + CONTRAIL_BAND * 0.5, height)


## HOW FAR PAST THE WORLD'S EDGE A TRAIL'S QUADS CAN STILL REACH, metres: a segment laid at the edge spreads, and the shaders
## widen a far trail to hold its least angle (77 m at 64 km). One ground cell, which is more than either.
const REACH_PAST_EDGE: float = 1024.0
## THE LOWEST AND HIGHEST A TRAIL IS DRAWN, metres of world Y: below the sea for a missile that dives, and far above any
## ceiling the simulation flies to.
const SKY_FLOOR: float = -1000.0
const SKY_TOP: float = 19000.0


## THE BOX A TRAIL YARD'S MULTIMESH IS CULLED BY, worked out from the world's own size. Every vertex is placed by the shader,
## so the box Godot would work out from the instances knows nothing of how wide a trail has spread, and the yards give the
## whole sky. Until 2026-09-14 both typed it as ±40 km: right for the ±32.8 km map, and the day the map passed 40 km on an
## axis every trail in the sky would have been culled at once (godotgames-drafts/2026-09-14/cockpit-precision/report.md).
static func culling_box() -> AABB:
	var half: float = float(GroundTuning.WORLD_HALF) + REACH_PAST_EDGE
	return AABB(Vector3(-half, SKY_FLOOR, -half), Vector3(half * 2.0, SKY_TOP - SKY_FLOOR, half * 2.0))
