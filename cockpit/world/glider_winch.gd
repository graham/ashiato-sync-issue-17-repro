extends RefCounted
class_name GliderWinch
## WHERE A PLAYER ON A GLIDER LEVEL IS LAUNCHED: when they join, and when they are put back after a crash. One rule in one
## place, asked by both callers (`Sim._seat_new_clients` and `CrewRespawn`), so an arrival and a respawn cannot disagree.
##
## The user, 2026-09-19: "Any player that joins or crashes should be respawned at the first zone at 1000 feet (or if there
## are other players, within 100 meteres of that player) so they can start over." The numbers are the level's (`"launch":
## {"height": 304.8, "beside": 100}`, `LevelChart.launch`); the first zone is the level's first thermal, "the start".
##
## NAMED FOR THE WINCH because that is what it is: agents.md already calls the parked glider being taken and thrown into the
## air at flying speed "the winch this game already had and did not know it". This one chooses where it throws.
##
## THE RULE:
## - NOBODY ELSE ALOFT: over the first thermal's middle, `height` over the ground under it, at the glider's cruise along
##   the level's spawn heading. Inside the thermal, where a glider pilot starts a day.
## - SOMEBODY ELSE ALOFT: beside the one of them nearest the first thermal -- the same height and heading, `ABEAM` of
##   `beside` out to the side away from their turn and `BEHIND` of it back, 0.72 of `beside` in all (72 m at 100). The
##   side away from their turn, so an arrival is never put inside the circle a thermalling glider is flying; behind, so it
##   is not put in front of their nose. "Aloft" is a craft that is not a wreck and stands at least `ALOFT_OVER` over the
##   ground: a player who has landed is not a player to be launched beside.
##
## AND ALWAYS HANDED OVER FLYING, at the other player's speed or the kind's cruise, WHICHEVER IS GREATER. A craft handed
## to a crew below its own flying speed is rescued by the simulation: `launch_if_grounded` lifts it to `kLaunchAltitude`
## (800 m) over the highest ground within 1.5 km and points it level. Measured on 2026-09-19 with the other player gliding
## at 38 m/s: the respawn was asked for 310 m and the crew arrived at 1,176 m, 865 m over the player they were meant to be
## beside, with the winch's own words in the log saying it had asked for the right place. Nothing in GDScript can see that
## rescue happen; the only sign is where the craft turns up.
##
## HOST ONLY, like everything that places a craft. REJECTED: launching beside a random player (two arrivals at once would
## split for no reason), and beside the NEWEST arrival (the chain of arrivals would walk away from the thermals).

## How far out to the side and how far back an arrival is put beside another player, as shares of the level's `beside`:
## 0.6 and 0.4 make 0.72 of it, inside the user's 100 m at any `beside`, and 60 m abeam is two spans of a 20 m sailplane.
const ABEAM: float = 0.6
const BEHIND: float = 0.4
## How high over the ground a player's craft must be to count as aloft, metres.
const ALOFT_OVER: float = 50.0


## WHERE AND HOW A LAUNCH GOES on `level`: `{position, yaw, velocity, beside}` (`beside` the client it was put beside, or
## -1), or {} when the level has no winch. `kind` is what is launched; `others` is every other player's craft as
## `others_aloft` gives them.
static func place(level: LevelChart, kind: int, others: Array[Dictionary]) -> Dictionary:
	if level == null or level.launch.is_empty():
		return {}
	var start: Dictionary = first_thermal()
	var middle: Vector3 = start.get("position", level.spawn_at) as Vector3
	if not others.is_empty():
		var nearest: Dictionary = others[0]
		for other in others:
			if _flat(other["position"] - middle) < _flat(nearest["position"] - middle):
				nearest = other
		var velocity: Vector3 = nearest["velocity"]
		var yaw: float = atan2(-velocity.x, -velocity.z)
		var nose: Vector3 = Terrain.nose_from_yaw(yaw)
		var right := Vector3(-nose.z, 0.0, nose.x)
		# AWAY FROM THEIR TURN: a positive spin about the vertical is a turn to the left, so the arrival goes right.
		var side: float = 1.0 if float((nearest.get("spin", Vector3.ZERO) as Vector3).y) >= 0.0 else -1.0
		var beside: float = float(level.launch["beside"])
		var at: Vector3 = (nearest["position"] as Vector3) + right * side * ABEAM * beside - nose * BEHIND * beside
		at.y = (nearest["position"] as Vector3).y
		return {"position": at, "yaw": yaw, "velocity": flying(velocity, kind, yaw), "beside": int(nearest["client"])}
	var at := Vector3(middle.x, 0.0, middle.z)
	at.y = Terrain.ground_height(at) + float(level.launch["height"])
	return {"position": at, "yaw": level.spawn_yaw,
		"velocity": Terrain.nose_from_yaw(level.spawn_yaw) * Terrain.cruise_for(kind), "beside": -1}


## THE LEVEL'S FIRST THERMAL, "the start", as `Terrain.lift_zones` stood it, or {}.
static func first_thermal() -> Dictionary:
	var zones: Array[Dictionary] = Terrain.lift_zones()
	return zones[0] if not zones.is_empty() else {}


## EVERY OTHER PLAYER'S CRAFT THAT IS FLYING, as the host's world has them: `{client, position, velocity, spin}`, for
## `place`. `leaving_out` are clients not to count -- the one being launched, and a wreck's whole crew.
static func others_aloft(server: Object, leaving_out: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if server == null:
		return out
	var seen: Dictionary = {}
	for pilot in server.pilot_states():
		var client: int = int((pilot as Dictionary).get("client", 0))
		var vehicle: int = int((pilot as Dictionary).get("vehicle", 0))
		if client == 0 or vehicle == 0 or leaving_out.has(client) or seen.has(vehicle):
			continue
		if bool((server.hull_state(vehicle) as Dictionary).get("destroyed", false)):
			continue
		var state: Dictionary = server.vehicle_state(vehicle)
		var at: Vector3 = state.get("position", Vector3.ZERO)
		if at.y - Terrain.ground_height(at) < ALOFT_OVER:
			continue
		seen[vehicle] = true
		out.append({"client": client, "position": at, "velocity": state.get("velocity", Vector3.ZERO),
			"spin": state.get("spin", Vector3.ZERO)})
	return out


## A VELOCITY A CRAFT IS HANDED OVER AT: the one given, along its own direction, never slower than the kind's cruise; the
## nose's direction at cruise when it is barely moving. See the note at the top about the rescue this avoids.
static func flying(velocity: Vector3, kind: int, yaw: float) -> Vector3:
	var cruise: float = Terrain.cruise_for(kind)
	if velocity.length() < 1.0:
		return Terrain.nose_from_yaw(yaw) * cruise
	return velocity.normalized() * maxf(velocity.length(), cruise)


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
