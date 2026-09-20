extends Node
class_name AirTraffic
## A LEVEL'S AIR TRAFFIC THAT GOES NOWHERE IN PARTICULAR, and keeps out of the players' way: light aeroplanes, Cessnas,
## helicopters, airliners overhead and other people's gliders, wandering between points in the level's own square.
##
## The user, 2026-09-19: *"There should be some airtraffic as well (25-30) planes and should mostly avoid the players, but
## it'll be nice to have a level that lets users experience a non combat scenario."*
##
## NOT `TrafficPlan`, WHICH IS AIRPORT LIFE. That one flies a named aeroplane from one airfield file to another and turns
## it round on the stand (lane/testfield); this one has no airfields in it at all. They are separate because they answer
## different questions -- "who is flying the pattern at the small field" and "what else is in the sky" -- and a level may
## have either, both or neither.
##
## A LEVEL FOLDER MAY HOLD `air_traffic.json`:
##
##   {"summary": "...", "flights": [{"kind": "CESSNA", "count": 8, "band": [600, 1000]}, ...]}
##
## `band` is the height over the ground each flight wanders at, metres, low and high; a glider ignores it and soars
## (`SoaringPilot`). KEPT OUT OF `level.json` for `TrafficPlan`'s reason: AI traffic is the host's, a joiner sees what
## replicates, and a traffic list in the level file would refuse a joiner over flights it never flies. A malformed flight
## is left out with a warning in its own words (rule 7).
##
## AND IT AVOIDS THE PLAYERS, WHICH IS THE POINT. Twice a second every machine here works out its CLOSEST POINT OF
## APPROACH to every player-crewed craft over the next `LOOK_AHEAD` seconds, from both velocities. If that pass would come
## inside `KEEP_CLEAR` horizontally and `KEEP_CLEAR_UP` vertically -- or if it is already inside -- the machine turns away
## from the player's side by `BREAK_OFF` and, if it has an engine, asks for a height `STEP_ASIDE` away from theirs, and
## holds that until the pass is `CLEAR_AGAIN` times the distance. Nothing about it is a collision avoidance system
## between AI craft: they fly their own legs and the world is large.
##
## HOST ONLY, like every other tactics file here. It steers through `steer_ai`, the same hands `AirportTraffic` and
## `Attackers` are given, so every machine in it is flying the mixer a player's own stick drives.

const FILE: String = "air_traffic.json"
## How often the traffic is looked at, physics ticks: twice a second at 120 Hz. A pass is thirty seconds off when it is
## first seen, so this is not urgent work; it is `LOOK_TICKS` for the same reason `TrafficPlan`'s is.
const LOOK_TICKS: int = 60
## HOW CLOSE A PASS MAY BE PLANNED TO COME, metres horizontally and vertically, and how far ahead the pass is looked for,
## seconds. 500 m is about six seconds of closing speed on a head-on pass between two light aeroplanes, and the aim is
## "mostly avoid", not an airways separation standard.
const KEEP_CLEAR: float = 500.0
const KEEP_CLEAR_UP: float = 150.0
const LOOK_AHEAD: float = 30.0
## HOW HARD IT BREAKS OFF: the heading it turns away by, radians, how far ahead the turn is aimed, metres, and the height
## it asks for away from the player's, metres.
const BREAK_OFF: float = 1.05
const BREAK_AHEAD: float = 2500.0
const STEP_ASIDE: float = 200.0
## The pass has to open to this many times KEEP_CLEAR before the machine goes back to its own leg, so it does not flip
## between avoiding and not on one wing beat.
const CLEAR_AGAIN: float = 1.5
## How far from a waypoint counts as arrived, metres, and how far out the next one may be.
const ARRIVED: float = 900.0
const LEG_LEAST: float = 2500.0
## How far inside the level's own square the traffic flies: the edge band's start, less this, so nothing is ever steered
## into the turn-back.
const INSIDE_THE_EDGE: float = 1500.0
## What a flight may say, and the limits on it.
const KEYS: PackedStringArray = ["kind", "count", "band"]
const COUNT_MOST: int = 64
const BAND := Vector2(50.0, 12000.0)

## Why the last flight refused was refused, for a test.
static var last_refusal: String = ""

## entity -> {kind, band: Vector2, to: Vector3, avoiding: int (client, or 0), since: int}
var machines: Dictionary = {}
## How many times a machine has broken off for a player, and the closest a machine has been to one, metres.
var broke_off: int = 0
var closest: float = INF
var pilot: SoaringPilot = null
var _ticks: int = 0
var _legs: int = 0


## THE FLIGHTS OF A LEVEL'S FILE, checked against this build, or [] with a warning.
static func read(level_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var path: String = ChartDrawer.FOLDER.path_join(level_id).path_join(FILE)
	if not FileAccess.file_exists(path):
		return out
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		_refuse(level_id, "%s is not a JSON object (line %d: %s)" % [FILE, json.get_error_line(), json.get_error_message()])
		return out
	var flights: Variant = (json.data as Dictionary).get("flights", [])
	if not (flights is Array):
		_refuse(level_id, "its 'flights' is not a list")
		return out
	for flight in flights:
		var why: String = _wrong_with(flight)
		if why != "":
			_refuse(level_id, why)
			continue
		out.append(flight)
	return out


static func _wrong_with(flight: Variant) -> String:
	if not (flight is Dictionary):
		return "a flight is not an object"
	var f: Dictionary = flight
	for key in f:
		if not KEYS.has(String(key)):
			return "'%s' is not a key a flight has: %s" % [key, ", ".join(KEYS)]
	if not Sim.Kind.has(String(f.get("kind", ""))):
		return "a flight's kind '%s' is not one this build has" % f.get("kind", "")
	if not (f.get("count") is float or f.get("count") is int) or int(f["count"]) < 1 or int(f["count"]) > COUNT_MOST \
			or float(f["count"]) != float(int(f["count"])):
		return "a flight's count is not a whole number from 1 to %d" % COUNT_MOST
	var band: Variant = f.get("band")
	if not (band is Array) or (band as Array).size() != 2:
		return "a flight has no band of two heights"
	for height in band:
		if not (height is float or height is int) or float(height) < BAND.x or float(height) > BAND.y:
			return "a flight's band is not two heights from %d m to %d m over the ground" % [int(BAND.x), int(BAND.y)]
	if float((band as Array)[0]) > float((band as Array)[1]):
		return "a flight's band is upside down"
	return ""


static func _refuse(level_id: String, why: String) -> void:
	last_refusal = why
	push_warning("[air traffic] %s: %s; that flight is left out" % [level_id, why])


## PUT EVERY FLIGHT IN THE AIR, spread over the level's square by the same hash the waypoints use, each at a height in its
## own band and flying at its kind's cruise. Host only. `soaring` flies the gliders among them.
func start(level_id: String, soaring: SoaringPilot) -> int:
	pilot = soaring
	var reach: float = _reach()
	var made: int = 0
	for flight in read(level_id):
		var kind: int = int(Sim.Kind[String(flight["kind"])])
		var band := Vector2(float((flight["band"] as Array)[0]), float((flight["band"] as Array)[1]))
		for i in range(int(flight["count"])):
			var at: Vector3 = _spread(made * 3 + 11, reach)
			var yaw: float = TAU * Terrain.hash01(made * 7 + 3, 977)
			at.y = Terrain.highest_near(at, 1000.0) + lerpf(band.x, band.y, Terrain.hash01(made, 617))
			var entity: int = Sim.spawn_ai_vehicle(kind, at, yaw, Terrain.nose_from_yaw(yaw) * Terrain.cruise_for(kind))
			if entity == 0:
				continue
			machines[entity] = {"kind": kind, "band": band, "to": _a_leg(at, reach), "avoiding": 0, "since": 0}
			if kind == Sim.Kind.GLIDER and pilot != null:
				pilot.fly(entity)
			made += 1
	print("[air traffic] %d machines in the air on %s" % [made, level_id])
	return made


func _physics_process(_delta: float) -> void:
	if Sim.server == null or machines.is_empty():
		return
	_ticks += 1
	if _ticks % LOOK_TICKS != 0:
		return
	var players: Array[Dictionary] = _players()
	var reach: float = _reach()
	for entity in machines.keys():
		var state: Dictionary = Sim.server.vehicle_state(int(entity))
		if state.is_empty() or bool((Sim.server.hull_state(int(entity)) as Dictionary).get("destroyed", false)):
			machines.erase(entity)
			if pilot != null:
				pilot.gliders.erase(entity)
			continue
		_look(int(entity), machines[entity], state, players, reach)


## ONE MACHINE'S LOOK: break off for a player whose pass would be too close, or fly its own leg.
func _look(entity: int, record: Dictionary, state: Dictionary, players: Array[Dictionary], reach: float) -> void:
	var at: Vector3 = state["position"]
	var velocity: Vector3 = state["velocity"]
	var them: Dictionary = _too_close(at, velocity, players)
	if not them.is_empty():
		if int(record["avoiding"]) == 0:
			broke_off += 1
		record["avoiding"] = int(them["client"])
		_break_off(entity, record, at, velocity, them)
		if pilot != null and pilot.gliders.has(entity):
			pilot.held[entity] = true
		return
	if int(record["avoiding"]) != 0:
		record["avoiding"] = 0
		if pilot != null:
			pilot.held.erase(entity)
	# A GLIDER FLIES ITSELF from here: it is soaring, not wandering.
	if int(record["kind"]) == Sim.Kind.GLIDER:
		return
	var to: Vector3 = record["to"]
	if Vector2(at.x - to.x, at.z - to.z).length() < ARRIVED:
		to = _a_leg(at, reach)
		record["to"] = to
	var band: Vector2 = record["band"]
	var height: float = Terrain.highest_near(at, 1000.0) + lerpf(band.x, band.y, 0.5)
	Sim.server.steer_ai(entity, {"toward": to, "altitude": height, "speed": Terrain.cruise_for(int(record["kind"])),
		"cruise_floor": true})


## THE PLAYER WHOSE PASS IS TOO CLOSE, or {}: the worst of them by how near the closest point of approach comes.
func _too_close(at: Vector3, velocity: Vector3, players: Array[Dictionary]) -> Dictionary:
	var worst: Dictionary = {}
	var nearest: float = INF
	for player in players:
		var apart: Vector3 = at - (player["position"] as Vector3)
		var closing: Vector3 = velocity - (player["velocity"] as Vector3)
		var seconds: float = 0.0
		if closing.length_squared() > 0.01:
			seconds = clampf(-apart.dot(closing) / closing.length_squared(), 0.0, LOOK_AHEAD)
		var pass_by: Vector3 = apart + closing * seconds
		var flat: float = Vector2(pass_by.x, pass_by.z).length()
		closest = minf(closest, apart.length())
		var room: float = float(player.get("room", 1.0))
		if flat < KEEP_CLEAR * room and absf(pass_by.y) < KEEP_CLEAR_UP * room and flat < nearest:
			nearest = flat
			worst = player.duplicate()
			worst["pass_by"] = pass_by
	return worst


## TURN AWAY FROM THEIR SIDE AND, WITH AN ENGINE, STEP ASIDE IN HEIGHT: away from the side the pass is going by on, so a
## machine never turns across a player's nose, and to a height away from theirs.
func _break_off(entity: int, record: Dictionary, at: Vector3, velocity: Vector3, them: Dictionary) -> void:
	var heading: float = atan2(-velocity.x, -velocity.z)
	var pass_by: Vector3 = them["pass_by"]
	var nose: Vector3 = Terrain.nose_from_yaw(heading)
	var right := Vector3(-nose.z, 0.0, nose.x)
	# THE SIDE THE PLAYER IS ON, in this machine's own frame: turn the other way.
	var side: float = -1.0 if Vector2(pass_by.x, pass_by.z).dot(Vector2(right.x, right.z)) >= 0.0 else 1.0
	var away: float = heading + side * BREAK_OFF
	var to: Vector3 = at + Terrain.nose_from_yaw(away) * BREAK_AHEAD
	var steer: Dictionary = {"toward": to, "speed": Terrain.cruise_for(int(record["kind"])), "cruise_floor": true}
	if int(record["kind"]) != Sim.Kind.GLIDER:
		var theirs: float = (them["position"] as Vector3).y
		var band: Vector2 = record["band"]
		var floor_height: float = Terrain.highest_near(at, 1000.0)
		steer["altitude"] = clampf(theirs + (STEP_ASIDE if at.y >= theirs else -STEP_ASIDE),
			floor_height + band.x, floor_height + band.y)
	Sim.server.steer_ai(entity, steer)


## EVERY PLAYER-CREWED CRAFT, as `{client, position, velocity, room}`: what the traffic keeps clear of. `room` is 1 for a
## player and `CLEAR_AGAIN` for one a machine is already avoiding, which is the hysteresis.
func _players() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var avoided: Dictionary = {}
	for record in machines.values():
		if int((record as Dictionary)["avoiding"]) != 0:
			avoided[int((record as Dictionary)["avoiding"])] = true
	var seen: Dictionary = {}
	for pilot_state in Sim.server.pilot_states():
		var client: int = int((pilot_state as Dictionary).get("client", 0))
		var vehicle: int = int((pilot_state as Dictionary).get("vehicle", 0))
		if client == 0 or vehicle == 0 or seen.has(vehicle):
			continue
		if bool((Sim.server.hull_state(vehicle) as Dictionary).get("destroyed", false)):
			continue
		seen[vehicle] = true
		var state: Dictionary = Sim.server.vehicle_state(vehicle)
		out.append({"client": client, "position": state.get("position", Vector3.ZERO),
			"velocity": state.get("velocity", Vector3.ZERO), "room": CLEAR_AGAIN if avoided.has(client) else 1.0})
	return out


## A LEG FROM `at`: a point inside the level's square at least LEG_LEAST away, spread by the waypoints' own hash so the
## traffic does not walk a lattice.
func _a_leg(at: Vector3, reach: float) -> Vector3:
	for i in range(8):
		_legs += 1
		var to: Vector3 = _spread(_legs * 13 + 5, reach)
		if Vector2(to.x - at.x, to.z - at.z).length() >= LEG_LEAST:
			return to
	return _spread(_legs, reach)


func _spread(index: int, reach: float) -> Vector3:
	return Vector3((Terrain.hash01(index, 2237) - 0.5) * 2.0 * reach, 0.0,
		(Terrain.hash01(index, 2239) - 0.5) * 2.0 * reach)


## HOW FAR OUT THE TRAFFIC FLIES: inside the level's edge band by INSIDE_THE_EDGE, so nothing is ever steered into the
## turn-back. Asked of the world's own boundary rather than the level file, which does not know where the band starts.
func _reach() -> float:
	var band: Dictionary = Sim.server.boundary() if Sim.server != null and Sim.server.has_method("boundary") else {}
	var start: float = float(band.get("start", 0.0))
	if start <= 0.0:
		start = Terrain.placed_reach() + WorldEdge.CLEAR_OF_PLACES
	return maxf(start - INSIDE_THE_EDGE, LEG_LEAST)
