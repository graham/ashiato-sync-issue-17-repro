class_name Seabed
extends RefCounted
## THE OPEN SEA'S FLOOR, AS SOMETHING THE PHYSICS CAN TOUCH: one static box under the whole wire, its top at the seabed and
## its bottom at the wire's floor, laid in every world by the level with the rest of the country.
##
## WHY IT IS HERE. Neither world's open sea had a floor. The island's sea is not solid by design -- a water bomber skims it,
## and `is_scooping` asks a ray to find nothing -- and the generated ground builds no height field for a cell whose every
## sample is at or below -40 m, so its seabed at -150 m was a number `ground_height_at` answered and the collision did not
## have. Anything that went into the sea fell for ever: dropped unflown from 40 m, a train reached -4,005 m in 30 s, and the
## wire clamped 34,363 coordinates on the way, identically on both worlds. The wire's floor is -200 m because the seabed
## was taken to be at -150 with 50 m under it for a hull resting on it; past it every other machine drew the craft at
## -200 m, and the level raised "the wire clamped" once a second. `chatter` found it by accident, running long enough with
## the voice model for its own two unflown aeroplanes to stall into the sea (lane/sinking, 2026-09-16). tests/seabed.gd holds
## it on both worlds.
##
## THIS IS A CATCH, NOT THE DESIGN OF A WRECK. It stops an infinite fall and nothing else. A craft on it lies still at
## -147 to -150 m -- with a player still in it, if there was one, who is a player at -150 m -- and nothing here decides what
## a ditching is, what happens to the crew, or whether a wreck should be removed. Aircraft feel no water at all: the airliner
## went through the surface without losing a metre a second. Both are filed on the plan as design questions for the user.
##
## THE NUMBERS ARE ASKED, NOT TYPED. The seabed is the generated ground's own function -- the alpine world's bedrock -- at
## its corner, which is open sea at its deepest, as `far_out` asks it; the reach and the bottom are the wire's
## (`wire_range`). The box is the whole 50 m between the two, which no fall measured here passes through in a tick.
## - NOT READ FROM C++: the constant under it, `kSeabedMetres` in `ground_core.hpp`, is not bound to GDScript, and binding it
##   is a library change for this one number.
## - HELD TO THE GROUND BY A CHECK instead: tests/seabed.gd sounds the open sea under every drop with `water_depth_at` on both
##   worlds and wants the seabed within a metre. On the island that sounding meets this box (150.00 m); on the generated
##   ground it is the ground's (149.98 m). Move either and that suite is red.
##
## WHAT IT CHANGES, MEASURED BEFORE IT WENT IN (25,920 answers over an 81 x 81 grid, server and client): on the island,
## `water_depth_at` over open sea reads 150.0 m where it read inf, because its sounding reaches 200 m under the sea;
## `sea_leg_is_deep` refuses a leg only for a need past 150 m, and every need in the game is a keel's worth. Nothing else
## changed. The generated ground's `water_depth_at` is the ground's function and never sees a box.
##
## REJECTED: a floor below the sounding's reach, with its top at -201 m. Every answer stayed byte-identical, and five of
## eight kinds came to rest with their origins at -200.15 to -200.40 m, past the wire's floor: 24,180 clamps in 60 s. A craft
## rests 0.6 to 2.6 m above what it lies on, so there is no height that keeps both.

## The seabed's depth, metres, asked once: negative, under the sea.
static var _depth: float = NAN
## HOW MANY FLOORS EACH LIVE WORLD WAS GIVEN, by the world's instance id, for `floors_in`. Only the worlds `Sim` holds now
## are kept, so a level changed a hundred times holds two entries.
static var _laid: Dictionary = {}


static func depth() -> float:
	if is_nan(_depth):
		var ground: Object = ClassDB.instantiate("GroundField")
		ground.call("configure", GroundTuning.values())
		var half: int = int(GroundTuning.values()["world_half"])
		_depth = float(int(ground.call("height_ticks_at", half, half))) / 32.0
	return _depth


## LAY IT in every world this machine runs, after `Sim.start`. Built identically on every peer and not replicated, like
## every other static box.
##
## ONCE PER WORLD, AND NOT MADE IDEMPOTENT, because it does not need to be: the level lays it from `_build`, which calls
## `Sim.start` first, and `Sim.start` stops the old worlds and instantiates new ones every time, so a rebuild or a level
## change never finds a world that already has a floor. tests/seabed.gd holds that through island -> lobby -> island by
## the real level change, and measured it on 2026-09-16: both worlds' instance ids were new after the round trip, each
## had been laid one floor (`floors_in` 1 and 1), and an airliner dropped again rested at -147.40 m with 0 clamps.
static func lay() -> void:
	var world: RefCounted = Sim.client if Sim.client != null else Sim.server
	if world == null:
		return
	var wire: Dictionary = world.wire_range()
	var top: float = depth()
	var bottom: float = float(wire["height_min"])
	var edge: float = float(wire["ground_max"])
	Sim.add_static_box(Vector3(0.0, (top + bottom) * 0.5, 0.0), Vector3(edge, (top - bottom) * 0.5, edge))
	var live: Dictionary = {}
	for each in [Sim.client, Sim.server]:
		if each != null:
			live[each.get_instance_id()] = int(_laid.get(each.get_instance_id(), 0)) + 1
	_laid = live


## HOW MANY FLOORS THIS WORLD HAS BEEN GIVEN: 0 for a world `lay` never saw, or one `Sim` no longer holds.
static func floors_in(world: Object) -> int:
	return int(_laid.get(world.get_instance_id(), 0)) if world != null else 0
