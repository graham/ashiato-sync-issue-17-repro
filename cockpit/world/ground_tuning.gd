extends RefCounted
class_name GroundTuning
## THE THREE NUMBERS THE GROUND IS MADE FROM, and the only place they are written: how wide the world is, how tall its
## ranges stand, and which world of that shape it is. `GroundField` (ashiato-gd/src/cockpit/ground_field.hpp) requires
## all three and defaults none, so a value typed beside it somewhere else is a second world, not a fallback.
##
## THE USER'S ANSWERS SET THESE (2026-09-14, godotgames-drafts/2026-09-14/cockpit-terrain/report.md, questions 1, 2 and
## 4): **64 km**, sixty-four cells of 1,024 m, so ±32,768 m on the wire; **alpine, peaks to 3,000 m**; and **a fixed
## world**, the same seed in every session. Today's island stays as a world of its own. WHICH WORLD A SESSION STANDS ON is
## its level's (`LevelChart.world`), and a level on the generated ground may name its own three numbers (`problems_with`).
##
## CHANGING ONE CHANGES THE WORLD ON EVERY PEER THAT RUNS THIS FILE, and on no peer that does not: a session's peers must
## agree on all three, exactly as they agree on the tick rate. `tests/ground_field.gd` pins its own copy of the world its
## hashes were recorded on (phase 1's 32,000 / 1,350 / 0) rather than reading these, so a new default here does not look
## like a broken function.

## Half the world square's side, metres: thirty-two cells of `WorldMap.CELL`. The wire's `ground` quantiser has to reach it.
const WORLD_HALF: int = 32768
## How tall the ridged ranges stand at full strength, metres. The highest ground stands about 110 m above it, from the
## lowland and the hills under the ranges.
const PEAK_HEIGHT: int = 3000
## FIXED: one world, the same every session. Not chosen at hosting.
const SEED: int = 0


static func values() -> Dictionary:
	return {"world_half": WORLD_HALF, "peak_height": PEAK_HEIGHT, "seed": SEED}


## THE WORLDS THE FLIGHT LEVEL CAN STAND ON. ISLAND is today's: `Terrain.boxes()` on a flat slab 14.4 km across. ALPINE is
## the ground the three numbers above make, `GroundField`'s 64 km of it. ROOM is the island's slab with NO COUNTRY ON IT
## AT ALL -- no scenery, no woods, no lift, no waypoints, no traffic, no sea and no mist -- for a level that is a room
## somebody stands in rather than a country they fly over: the lobby's briefing room (`BriefingRoom`, plan.md item 2).
##
## A ROOM IS A WORLD RATHER THAN A SCENE because the lobby is a LEVEL (the user, 2026-09-15): a level is what the whole
## session agrees about through `Net.level` and the hello, so segways replicate, the crew page lists them, and joining a
## game already in progress is the ordinary join. A bare scene would need a second copy of all of that.
enum World { ISLAND, ALPINE, ROOM }

## WHETHER A WORLD IS MADE FROM THE THREE NUMBERS ABOVE. The island is boxes on a slab and a room is four walls on one:
## neither takes a ground number, and a level that names one is refused for having it (`LevelChart`).
static func takes_numbers(world: int) -> bool:
	return world == World.ALPINE


## A WORLD BY ITS NAME, as a level file spells it (lower case), or -1. `LevelChart.worlds()` is the list.
static func world_named(named: String) -> int:
	return int(World.keys().find(named.to_upper()))


## WHAT IS WRONG WITH A LEVEL'S GROUND NUMBERS, in `GroundField`'s own words, or nothing. ASKED OF THE GROUND ITSELF, not
## checked beside it: `GroundField.configure` holds every key's range, and a range copied here would be a second one. A
## level file's numbers arrive as JSON floats and the ground takes ints, so whole numbers are made ints first
## (`whole_numbers`); a fraction stays a float and is refused as one.
static func problems_with(ground: Dictionary) -> PackedStringArray:
	if not ClassDB.class_exists(&"GroundField"):
		return PackedStringArray(["this build has no GroundField"])
	var field: Object = ClassDB.instantiate(&"GroundField")
	return field.call("configure", whole_numbers(ground))


## A level file's numbers as the ground takes them: every float with no fraction an int, everything else as it was.
static func whole_numbers(ground: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in ground:
		var value: Variant = ground[key]
		out[key] = int(value) if value is float and float(value) == floorf(float(value)) else value
	return out


## THE GROUND A LEVEL STANDS ON, as `GroundField.configure` takes it: the level's own numbers (`LevelChart.ground`), and
## the pads its own airfield files ask for when it has any (`Airfield.pads_for`; lane/testfield, 2026-09-19). The pads are
## not in the level file because they are the airfield files' numbers; a second copy there could disagree with them.
static func for_level(level: LevelChart) -> Dictionary:
	var values: Dictionary = whole_numbers(level.ground)
	var pads: Array[Dictionary] = Airfield.pads_for(level.id)
	if not pads.is_empty():
		values["pads"] = pads
	# AND THE RIVERS IT LAYS, as the ground function takes them -- without `depth`, which is the canyon walls' number
	# and not the cut's (`Watercourse`). These ARE in the level file, unlike the pads, because a river is the level's
	# own line and nothing else knows it.
	if not level.rivers.is_empty():
		values["rivers"] = Watercourse.ground_rivers(level.rivers)
	return values
