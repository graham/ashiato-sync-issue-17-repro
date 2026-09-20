extends RefCounted
class_name FinalWalk
## THE GLIDE PATH DOWN EVERY FIELD'S FINAL, walked against the rock: one walk for every suite that asks it, so the check
## is the same on the island and on a level, and the fields it walks are the authority's (`Airfield.here()`), never a
## list a test remembered.
##
## `tests/airport.gd` had this check for a month and handed it `[long, crossing]`, the two Cape International runways, so
## `island_strip`'s final stood 38 m inside the second lone mountain from 2026-09-18 and no suite said so (lane/throughrock,
## 2026-09-19). A suite that checks the fields somebody remembered cannot find the field somebody forgot.

## THE ROOM EITHER SIDE OF THE CENTRELINE THE GAME KEEPS CLEAR: not a published surface, the game's own margin, wider than
## an autopilot strays on a final. At x 5,900, the first sketch's 36, the ring's east flank stood 5 m above the path 600 m
## to the west 1.3 km out; 200 m east it clears (lane/airport, 2026-09-19).
const ROOM: float = 600.0
const ACROSS_STEP: float = 50.0
const ALONG_STEP: float = 100.0


## WHAT THE INSTRUMENT FINAL INTO `field` (from the end in use) CLEARS, walked from the threshold out to where the aeroplane
## is established, `ROOM` either side. `least` is the smallest clearance anywhere on it, metres, and `at` says where;
## `over_rock` is the smallest with rock actually beneath, which is the terrain margin (the least anywhere is usually the
## threshold's own crossing height, fixed approach geometry with no rock under it: lane/ridges, 2026-09-19).
## Every kind that flies an instrument approach gets the same final (`InstrumentApproach.established_out` is the same
## for all of them), so the JUMBO's stands for the lot.
static func of(field: Dictionary, rock: Object) -> Dictionary:
	var p: TrafficPattern = Airfield.pattern_for(field, Sim.Kind.JUMBO)
	var ifr := InstrumentApproach.make(p, Airfield.numbers_of(Sim.Kind.JUMBO))
	var least := INF
	var at_says := ""
	var over_rock := INF
	var out := 0.0
	while out <= ifr.established_out():
		var across := -ROOM
		while across <= ROOM:
			var at: Vector3 = p.point(-out, across)
			var stands: float = float(rock.call("surface_at", at.x, at.z))
			var clear: float = ifr.final_height(at) - p.field - stands
			if clear < least:
				least = clear
				at_says = "%.0f m out, %.0f m across" % [out, across]
			if stands > 1.0:
				over_rock = minf(over_rock, clear)
			across += ACROSS_STEP
		out += ALONG_STEP
	return {"least": least, "at": at_says, "over_rock": over_rock}
