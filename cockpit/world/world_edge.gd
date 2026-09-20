extends RefCounted
class_name WorldEdge
## WHERE A LEVEL ENDS, SOFTLY: how far out a craft may fly before its pilot is warned, and before it is turned back.
##
## Asked for on 2026-09-15: "the world edge gets a SOFT boundary: warn, then turn the craft back." Past the wire's range
## (±32,768 m) every machine but the server was sent a craft clamped at the edge, and a joined pilot's own client held its
## aeroplane there while the server flew it on: 1,032 m apart after 10 s, with 18 to 24 rollbacks a second (agents.md,
## "At the world's horizontal edge"). So a level stops short of the wire, and the turn is flown in the simulation's shared
## step on every world alike (`CockpitWorld.set_boundary`).
##
## THE BAND IS WORKED OUT, NOT TYPED (team-lead, 2026-09-15):
## - it STARTS past everything placed on the level, by `CLEAR_OF_PLACES`, so a pilot landing at an edge airfield is
##   never turned away from it: `Terrain.placed_reach()`, the level's own answer;
## - it is as DEEP as the widest turn any powered wing needs at its top speed, flown at its own autopilot's bank limit
##   (`CockpitWorld.worst_turn_radius()`), so the turn-back has the whole of it by the time the craft is a turn's width in;
## - and a craft carried a further turn's width past that must still be inside the last resort's band at the wire's edge
##   (`CockpitWorld.boundary()["guard_from"]`). A level whose band will not fit is refused, in words, when it is built.
##
## DISTANCES ARE PER AXIS, as the wire clamps: a square whose half-width is a radius contains the circle of that radius,
## so a placed reach given as a radius is a safe per-axis start (cockpit-terrain, 2026-09-15).

## How far past the farthest placed thing the band starts, metres: an approach to an edge airfield, flown out and turned.
const CLEAR_OF_PLACES: float = 2000.0
## How long before the band a pilot is warned, as seconds of the fastest wing's top speed: time to turn by hand.
const WARN_SECONDS: float = 20.0


## THE BAND FOR A LEVEL: {start, depth, warn_from, error}. `placed` is the level's placed reach, `turn` the worst turn
## radius, `guard_from` where the wire's last resort begins, `fastest` the top speed the warning is timed on. `error` is
## "" when the band fits, and a sentence otherwise.
static func band_for(placed: float, turn: float, guard_from: float, fastest: float) -> Dictionary:
	var start: float = placed + CLEAR_OF_PLACES
	var depth: float = turn
	var out: Dictionary = {"start": start, "depth": depth, "warn_from": maxf(start - fastest * WARN_SECONDS, placed),
		"error": ""}
	var needs: float = start + depth + turn
	if needs > guard_from:
		out["error"] = "the world's edge will not fit: everything placed reaches %.1f km, a turn back needs %.1f km more, and the wire's last resort begins at %.1f km" % [
			placed / 1000.0, (needs - placed) / 1000.0, guard_from / 1000.0]
	return out


## HOW FAR OUT A POINT IS, per axis.
static func out(at: Vector3) -> float:
	return maxf(absf(at.x), absf(at.z))


## WHAT A PILOT AT `at` IS TOLD, or "": past the band's start, that they are being turned back; inside the warning, how
## far there is left. Words for the HUD's first line and for the tower.
static func warning(at: Vector3, band: Dictionary) -> String:
	if band.is_empty() or String(band.get("error", "")) != "":
		return ""
	var past: float = out(at)
	if past >= float(band["start"]):
		return "WORLD EDGE · TURNING YOU BACK"
	if past >= float(band["warn_from"]):
		return "WORLD EDGE IN %.1f KM · TURN BACK" % ((float(band["start"]) - past) / 1000.0)
	return ""
