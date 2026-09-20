extends Node
class_name SoaringPilot
## HOW AN UNMANNED GLIDER SOARS: glide to a thermal, circle in its core while the air carries it up, leave under the cloud,
## and glide on to the next one within reach. The host's tactics for the glider level's AI gliders and for the suite's
## robot glider (lane/gliderlevel, 2026-09-19), steering the ordinary autopilot through `steer_ai` exactly as
## `AirportTraffic` and `Attackers` steer theirs: where to fly and how fast, and nothing else. It still flies through the
## mixer -- the stick a player's hand moves -- and a glider's mixer holds its speed with that stick and lets the height be
## whatever the air makes it (`AircraftMixer`, `powered = false`).
##
## lane/glider found there was no glider AI (learnings/2026-09-17-glider.md): an aeroplane's 3 km minimum leg skipped the
## nearest thermal, and `kArrived`, 220 m, counted a glider arrived before it reached any lift. So this does not use legs
## at all. It picks the thermal itself and flies to it by steering, and it decides it has arrived by being inside the core.
## ARRIVAL MEANS CLIMBING, which was lane/glider's recommendation: a thermal is left when the climb is used up (under the
## cloud base) or when it stops carrying the glider (under WEAK_CLIMB for WEAK_SECONDS).
##
## THE CIRCLE is flown by steering at a point LEAD round a CIRCLE_RADIUS circle ahead of the glider, moved every look: the
## heading loop banks toward it, the point runs away round the circle, and the glider turns after it for as long as it is
## told to. Every glider circles LEFT, as a gaggle does so that two in one thermal do not meet head on. Where the circle
## actually sits and what it costs were MEASURED rather than chosen; see CIRCLE_SPEED. The core is
## `R (1 - sqrt(CIRCLE_SINK / S))`, the radius inside which the air rises faster than a CIRCLING glider sinks -- which is
## not its straight-and-level sink, and using that would have called a thermal workable that nothing can climb in.
##
## HOST ONLY. A glider a person boards is theirs: the autopilot hands over, and this lets go of it. And a glider in `held`
## is one `AirTraffic` is steering out of a player's way; this leaves its stick alone until it is given back.

## How often each glider is looked at, physics ticks: ten times a second at 120 Hz, for the circle's point.
const LOOK_TICKS: int = 12
## How far round the circle ahead of the glider the point it steers at stands, radians.
const LEAD: float = 0.9
## THE CIRCLE, AND IT IS MEASURED RATHER THAN CHOSEN (tests/zz_soar_probe, 2026-09-19, six circles flown on this level in
## still air): asked for 27 m/s round a 110 m circle, this glider flies 29.3 m/s, sits CIRCLE_OUT (129 m) from the middle
## and sinks CIRCLE_SINK (2.66 m/s). Slower is worse, not better -- at 24 m/s it sinks 3.15 -- because this glider's sink
## FALLS with speed the whole way to its cruise (1.20 m/s at 40 m/s, 2.69 at 22), which is not a real sailplane's polar
## and is the flight model's to fix (todo/gliderlevel--the-gliders-polar-is-backwards.md). Faster than this it cannot
## hold a circle: asked for 34 m/s round 140 m it sat 291 m out.
const CIRCLE_SPEED: float = 27.0
const CIRCLE_RADIUS: float = 110.0
const CIRCLE_OUT: float = 129.0
const CIRCLE_SINK: float = 2.66
## The most it banks in the circle, radians: the autopilot's own limit for a glider.
const CIRCLE_BANK: float = 0.9
## A thermal is joined once the glider is this share of its radius from the middle.
const JOIN_INSIDE: float = 0.5
## A thermal is left this far under its cloud base, metres: nobody climbs into the cloud to go on.
const LEAVE_UNDER: float = 150.0
## ... or when it has carried the glider less than WEAK_CLIMB m/s over the last WEAK_SECONDS, after at least that long.
const WEAK_CLIMB: float = 0.2
const WEAK_SECONDS: float = 40.0
## THE NEXT THERMAL: the nearest one reachable at GLIDE:1 arriving ARRIVE_OVER over the ground, not one of the last
## REMEMBERED visited. A glider between thermals flies at its cruise, where the same probe measured 33:1 at 40.3 m/s;
## GLIDE is the kept figure, a quarter under that, so a leg is chosen with something in hand.
const GLIDE: float = 25.0
const ARRIVE_OVER: float = 300.0
const REMEMBERED: int = 3
## What a thermal must beat for a circling glider to climb in it: the sink in the circle above. `core_of` is the radius
## inside which it does.
const SINK: float = CIRCLE_SINK

## entity -> {phase: "glide"|"climb", zone, visited: Array, climbs: Array of {zone, name, from, to, seconds},
## heights: Array of [seconds, y] in the current climb, joined_at: seconds, entered_y: the height it joined at}
var gliders: Dictionary = {}
## Gliders somebody else is steering this moment, by entity: `AirTraffic` holds one while it breaks off for a player, and
## two hands on one stick is a glider that does neither thing. It keeps its thermal and its climb while it is held.
var held: Dictionary = {}
var _ticks: int = 0


## FLY `entity`, an unmanned glider on the host, from where it is: to `zone` (an index into `Terrain.lift_zones`), or to
## the nearest thermal when -1.
func fly(entity: int, zone: int = -1) -> void:
	gliders[entity] = {"phase": "glide", "zone": zone if zone >= 0 else _nearest(entity), "visited": [], "climbs": [],
		"heights": [], "joined_at": 0.0}
	if Sim.server != null:
		Sim.server.set_ai_manners(entity, {"bank": CIRCLE_BANK})


## THE CORE OF A ZONE: the radius inside which its air rises faster than a glider sinks, metres.
static func core_of(zone: Dictionary) -> float:
	return float(zone["radius"]) * (1.0 - sqrt(SINK / maxf(float(zone["strength"]), SINK)))


func _physics_process(_delta: float) -> void:
	if Sim.server == null or gliders.is_empty():
		return
	_ticks += 1
	if _ticks % LOOK_TICKS != 0:
		return
	var zones: Array[Dictionary] = Terrain.lift_zones()
	if zones.is_empty():
		return
	var now: float = float(_ticks) / float(Engine.physics_ticks_per_second)
	for entity in gliders.keys():
		var state: Dictionary = Sim.server.vehicle_state(int(entity))
		if state.is_empty() or bool((Sim.server.hull_state(int(entity)) as Dictionary).get("destroyed", false)):
			gliders.erase(entity)
			held.erase(entity)
			continue
		if held.has(entity):
			continue
		_look(int(entity), gliders[entity], state, zones, now)


func _look(entity: int, record: Dictionary, state: Dictionary, zones: Array[Dictionary], now: float) -> void:
	var at: Vector3 = state["position"]
	var zone: Dictionary = zones[int(record["zone"])]
	var middle: Vector3 = zone["position"]
	var cruise: float = Terrain.cruise_for(Sim.Kind.GLIDER)
	var out: float = Vector2(at.x - middle.x, at.z - middle.z).length()
	if String(record["phase"]) == "glide":
		if out <= maxf(float(zone["radius"]) * JOIN_INSIDE, CIRCLE_OUT * 1.5):
			record["phase"] = "climb"
			record["joined_at"] = now
			record["entered_y"] = at.y
			record["heights"] = [[now, at.y]]
		else:
			Sim.server.steer_ai(entity, {"toward": Vector3(middle.x, at.y, middle.z), "speed": cruise})
			return
	var heights: Array = record["heights"]
	heights.append([now, at.y])
	while heights.size() > 2 and float(heights[1][0]) < now - WEAK_SECONDS:
		heights.pop_front()
	var weak: bool = now - float(record["joined_at"]) >= WEAK_SECONDS and float(heights[0][0]) <= now - WEAK_SECONDS + 1.0 \
		and (at.y - float(heights[0][1])) / maxf(now - float(heights[0][0]), 1.0) < WEAK_CLIMB
	if at.y >= float(zone["top"]) - LEAVE_UNDER or weak:
		_leave(entity, record, at, zones, now)
		return
	# THE CIRCLE: a point LEAD round it ahead, anticlockwise from above (a left-hand turn).
	var radius: float = CIRCLE_RADIUS
	var radial := Vector2(at.x - middle.x, at.z - middle.z)
	var angle: float = atan2(radial.y, radial.x) if radial.length() > 1.0 else 0.0
	var ahead: float = angle - LEAD
	var point := Vector3(middle.x + cos(ahead) * radius, at.y, middle.z + sin(ahead) * radius)
	Sim.server.steer_ai(entity, {"toward": point, "speed": CIRCLE_SPEED})


func _leave(entity: int, record: Dictionary, at: Vector3, zones: Array[Dictionary], now: float) -> void:
	var zone: Dictionary = zones[int(record["zone"])]
	(record["climbs"] as Array).append({"zone": int(record["zone"]), "name": String(zone.get("name", "")),
		"from": float(record.get("entered_y", at.y)),
		"to": at.y, "seconds": now - float(record["joined_at"])})
	var visited: Array = record["visited"]
	visited.append(int(record["zone"]))
	while visited.size() > REMEMBERED:
		visited.pop_front()
	record["zone"] = next_thermal(at, zones, visited)
	record["phase"] = "glide"
	record["heights"] = []


## THE NEXT THERMAL FROM `at`: the nearest within a GLIDE:1 glide arriving ARRIVE_OVER over the highest ground at its
## edge, and not one of `visited`; the nearest not visited if none is in reach; the nearest of all if every one was.
static func next_thermal(at: Vector3, zones: Array[Dictionary], visited: Array) -> int:
	var best: int = -1
	var best_run: float = INF
	var fallback: int = -1
	var fallback_run: float = INF
	for i in range(zones.size()):
		if visited.has(i):
			continue
		var p: Vector3 = zones[i]["position"]
		var run: float = maxf(0.0, Vector2(p.x - at.x, p.z - at.z).length() - float(zones[i]["radius"]))
		if run < fallback_run:
			fallback_run = run
			fallback = i
		if at.y - run / GLIDE - Terrain.highest_near(p, float(zones[i]["radius"])) >= ARRIVE_OVER and run < best_run:
			best_run = run
			best = i
	if best >= 0:
		return best
	return fallback if fallback >= 0 else 0


func _nearest(entity: int) -> int:
	var at: Vector3 = (Sim.server.vehicle_state(entity) as Dictionary).get("position", Vector3.ZERO) if Sim.server != null \
		else Vector3.ZERO
	return next_thermal(at, Terrain.lift_zones(), [])
