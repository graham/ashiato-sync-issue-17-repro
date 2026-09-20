extends RefCounted
class_name ExhaustTuning
## EVERY NUMBER THE THRUST EXHAUST IS DRAWN WITH, AND THE RULE THAT SAYS WHO GETS ONE.
##
## Asked for on 2026-09-19, with the Harrier: "I'd like you to also try modelling a thrust 'smoke' on this model as
## well. We haven't done that before and it seems important for this model." They are right that it had not been done
## -- before this there was no exhaust, no downwash and no ground wash anywhere in the game -- and right that it
## matters most on a Harrier, because in the hover four nozzles are blasting the ground.
##
## ONE KNOB, ONE NUMBER, in `WakeTuning`'s voice. Everything that can be said about the look -- "longer", "hotter",
## "more dust", "it reaches further down" -- is one constant here, and nothing downstream types a number beside it.
##
## THE RULE IS BY WHAT A PORT IS AND WHERE ITS AXIS GOES, NEVER BY WHAT THE CRAFT IS CALLED. That is `WakeTuning`'s
## rule and it is the whole reason this is a feature rather than an effect: a craft declares its ports by growing
## `exhaust_ports()` (see `ExhaustYard`), and the yard reads the PORT. So the F-35B's lift fan, the Osprey's
## proprotors and a helicopter's disc get the ground wash the day somebody types their ports, without a line here
## changing and without a roster to go stale.
##
## PURELY A PICTURE. Nothing here is on the wire and nothing pushes. Every machine derives the same plume from the
## replicated command bus and the pose it is already drawing, exactly as `ContrailYard` derives a contrail.

## ---- what a port is ------------------------------------------------------------------------------------------

## THE THREE KINDS OF THING THAT BLOWS. A kind decides which of the three layers are drawn at all, which is how one
## yard serves a jet pipe and a rotor disc without either being a special case.
## - JET: hot gas. A core, a haze and a ground bloom.
## - FAN: cold air off a compressor or a lift fan. No core -- there is no flame -- a fainter haze, and a full bloom,
##   because cold air moves as much dust as hot air does.
## - ROTOR: a disc of moving air. No core, no haze, and a wide bloom. A proprotor makes no visible gas at all; what
##   it makes is the thing on the ground.
enum Kind { JET, FAN, ROTOR }

## ---- the core: the visible burn just outside a hot nozzle ------------------------------------------------------

## HOW LONG A JET CORE IS, in nozzle radii, at full throttle. A dry turbofan shows a short pale tongue and nothing
## like a rocket motor's: `missile_motor.gdshader` draws a plume many calibres long, and copying that length was the
## first thing that looked wrong.
const CORE_LENGTH_RADII: float = 2.6
## Below this throttle a core is not drawn at all. An engine at idle does not glow.
const CORE_FROM_THROTTLE: float = 0.35
## How bright the core is at full throttle, into the renderer's HDR range at night as the flare's flame is.
const CORE_BRIGHTNESS: float = 1.4
## THE NARROWEST A CORE IS EVER DRAWN, as a fraction of its distance from the eye -- about two pixels.
## `missile_motor` holds this angle for the same reason: a two-metre plume is under a pixel at four kilometres, and an
## aircraft in the circuit is found by its exhaust.
const CORE_LEAST_ANGLE: float = 0.0016

## ---- the haze: the "thrust smoke" itself -----------------------------------------------------------------------

## HOW FAR THE HAZE REACHES BEHIND A PORT, in nozzle radii, at full throttle, and how much it widens over that reach.
const HAZE_LENGTH_RADII: float = 14.0
const HAZE_SPREAD: float = 2.8
## HOW THICK IT IS AT ITS DENSEST, 0 to 1. THIS IS THE NUMBER TO TURN when somebody says the exhaust is too much or
## too little, and it is deliberately tiny: disturbed air is nearly invisible, and the first build at 0.25 read as a
## smoke screen towed behind the aeroplane.
const HAZE_THICKNESS: float = 0.055
## A COLD PORT'S HAZE, as a share of a hot one's. Fan air is clean; what little shows is density, not soot.
const HAZE_COLD_SHARE: float = 0.45
## THE COLOUR OF DISTURBED, FAINTLY SOOTY AIR. Neutral and slightly dark, because this shader is BLENDED and not
## additive -- see the note in `exhaust_haze.gdshader`, which is `flare.gdshader`'s reason: added to a bright sky a
## pale plume comes out white, and hot exhaust is if anything DARKER than the sky behind it.
const HAZE_TONE := Color(0.30, 0.30, 0.31)
## Below this throttle no haze is drawn.
const HAZE_FROM_THROTTLE: float = 0.12

## ---- the ground bloom: what the hover does to the ground -------------------------------------------------------

## HOW FAR A PORT'S AXIS MAY REACH TO THE SURFACE and still raise anything, in metres. Past this the plume has spread
## and slowed too much to move dust. A Harrier hovering at 15 m still marks the ground; at 60 m it does not.
const BLOOM_REACH: float = 45.0
## ...and how strongly, by that distance: full at `BLOOM_CLOSE`, nothing at `BLOOM_REACH`.
const BLOOM_CLOSE: float = 8.0
## THE PLUME MUST BE POINTING AT THE GROUND, not merely near it. The cosine between the port's axis and the way down;
## below this the wash slides along the surface instead of striking it. A Harrier in the cruise never blooms.
const BLOOM_LEAST_DOWN: float = 0.35
## Below this throttle nothing is raised.
const BLOOM_FROM_THROTTLE: float = 0.20

## HOW MANY PUFFS A PORT THROWS A SECOND at full strength, and how long each lasts. The processor's whole cost is the
## throwing: a puff is written once and flown by the GPU from its age, as `SprayYard`'s are.
const BLOOM_PUFFS_A_SECOND: float = 11.0
const BLOOM_LIFE: float = 1.4
## A puff's radius when it is thrown and how much it grows over its life, metres.
const BLOOM_START_SIZE: float = 0.45
const BLOOM_GROW: float = 2.0
## HOW FAST A PUFF RUNS OUTWARD from where the plume struck, metres a second, and how fast it lifts as it goes.
## Outward and then up is what a jet striking the ground actually does, and it is why the picture everybody knows is
## a RING and not a cloud.
const BLOOM_OUTWARD: float = 11.0
const BLOOM_LIFT: float = 1.1
## THE RING'S INNER RADIUS, in multiples of the port's own radius: a puff is not thrown from the point of impact but
## from the edge of the jet's footprint, which is what leaves the dark centre in every photograph of a hovering jet.
const BLOOM_RING_RADII: float = 1.6

## THE FOUNTAIN. Where two or more ports strike close together, the outward flows collide between them and go
## straight back UP -- which on a real Harrier is what the LIDS strakes and fence exist to trap. Puffs thrown within
## this many metres of another port's impact rise instead of running out.
## NASA studied this exact aeroplane in ground effect (`craft/harrier/sources.md`, the two YAV-8B papers); the shape
## here is the photographs' and the number is an ESTIMATE.
const FOUNTAIN_WITHIN: float = 3.0
const FOUNTAIN_LIFT: float = 3.4

## WHAT IS RAISED, BY WHAT WAS HIT, and never by what the craft is: `Terrain.water_height` finite under the strike
## means spray, otherwise it is dust off the ground. Opacity, and how white or brown.
const SPRAY_TONE := Color(0.92, 0.94, 0.95)
const DUST_TONE := Color(0.62, 0.56, 0.45)
const BLOOM_OPACITY: float = 0.14

## ---- how the strength is worked out ----------------------------------------------------------------------------

## HOW STRONGLY THIS PORT IS BLOWING, 0 to 1, from the throttle on the replicated bus. Not a curve worth tuning
## separately per layer: each layer has its own threshold above, and this is the one common ramp.
static func blowing(throttle: float) -> float:
	return clampf(throttle, 0.0, 1.0)


## HOW MUCH A PORT'S GROUND WASH IS WORTH at `metres` from the surface, 0 to 1: full close in, nothing past the reach.
static func bloom_by_height(metres: float) -> float:
	if metres > BLOOM_REACH or metres < 0.0:
		return 0.0
	return clampf(1.0 - (metres - BLOOM_CLOSE) / (BLOOM_REACH - BLOOM_CLOSE), 0.0, 1.0)


## WHICH LAYERS A KIND OF PORT DRAWS: [core, haze, bloom]. The one place that branches on `Kind`, so a new kind of
## blowing thing is one row here rather than an `if` in three shaders.
static func layers_of(kind: int) -> Array:
	match kind:
		Kind.JET:
			return [true, true, true]
		Kind.FAN:
			return [false, true, true]
		_:
			return [false, false, true]
