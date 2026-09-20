extends Node
class_name TrafficPlan
## A LEVEL'S AIRPORT LIFE, AS DATA: which aeroplanes stand where at the start, where each flies, and that each turns round
## and flies back when it has parked. The host's, like `AirportTraffic`, which flies every one of them: this only says
## what to ask it for, and when.
##
## Asked for on 2026-09-19 with the test field: "let's have the basic test in testfield, but also have a stress test that
## increases the amount of ai traffic on that map (not by default but runnable on request)". So a level folder may hold a
## `traffic.json` beside its `level.json`, with a `basic` list flown by default and a `stress` list flown instead when the
## command line says `--traffic=stress` after the bare `--`. A level with no file has no airport life, which is every
## level before this one.
##
## A FLIGHT IS `{kind, from, to, spot?}`: a `Sim.Kind` name, the airfield file it leaves from and the one it lands at (the
## same one for circuits), and the stand it starts on at the base laid round `from` -- or, with no `spot` or no base, the
## threshold of the end in use, lined up. It departs at once, flies to `to` and lands; once it has PARKED (or stopped
## clear of the runway where a field has no stands) for TURNAROUND_S it departs again for where it came from, for ever.
##
## NOT IN THE LEVEL FILE, because it is not something every machine must agree on: AI traffic is the host's, and a
## joiner sees the aeroplanes it replicates. A level file's hash is what a joiner is checked against, and a traffic list
## in it would refuse a joiner over a flight it never flies itself.
##
## A FLIGHT MAY SAY `count` (the stress list's do): that many of it, the first as above and the rest put in the air
## along the way from `from` to `to`, spread evenly, at cruise and heading there, each then flying there and landing --
## so a hundred aeroplanes are not a hundred on one stand. `--traffic-scale=K` after the bare `--` multiplies every count,
## which is how the stress test is ramped (tests/testfield_stress.gd).
##
## A MALFORMED FLIGHT IS LEFT OUT WITH A WARNING in its own words (rule 7): a kind this build has not got, an airfield the
## level has not got, a stand the base has not got.

const FILE: String = "traffic.json"
const LISTS: Array[String] = ["basic", "stress"]
## How long an aeroplane stands at its stand, or clear of the runway, before it flies back, seconds of simulation.
const TURNAROUND_S: float = 30.0
## How often the plan looks at its flights, physics ticks: once a second at 120 Hz. Nothing here is urgent.
const LOOK_TICKS: int = 120
## How far above its stand a craft is put, metres over its own half height, so its wheels settle rather than start in it.
const STAND_CLEARANCE: float = 0.3
## A copy put in the air stands this far over the highest ground within AIR_ROOM of it, metres.
const AIR_OVER: float = 700.0
const AIR_ROOM: float = 3000.0
## Where a circuit's copies are put in the air round their field, metres out, and how much a hash turns each.
const CIRCUIT_OUT: float = 6000.0
## THE SEMICIRCULAR RULE, as 14 CFR 91.159 and ICAO's tables have it: a copy tracking east (0 to 179 degrees magnetic)
## is put EAST_ABOVE higher than one tracking west, and copies on one route are spread over LAYERS levels LAYER apart.
## Without it the stress list's first run put its eastbound and westbound 747 copies on one line at one height, and two
## of them met head-on at 142 and 150 m/s (tests/testfield_stress.gd, 2026-09-19).
const EAST_ABOVE: float = 300.0
const LAYER: float = 150.0
const LAYERS: int = 3

## Why the last flight refused was refused, for a test.
static var last_refusal: String = ""

## Every flight flown: `{entity, kind, from, to, legs, landings, departures, parked_s}` by entity. `landings` counts each
## arrival that came down to taxi speed at its destination.
var flights: Dictionary = {}
var traffic: AirportTraffic = null
var _ticks: int = 0


## WHICH LIST THE COMMAND LINE ASKS FOR: `--traffic=stress` after the bare `--`, or `basic`.
static func asked_for() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--traffic="):
			return argument.trim_prefix("--traffic=")
	return "basic"


## THE FLIGHTS OF ONE LIST OF A LEVEL'S FILE, checked for shape against this build and this level, or [] with a warning.
static func read(level_id: String, list: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var path: String = ChartDrawer.FOLDER.path_join(level_id).path_join(FILE)
	if not FileAccess.file_exists(path):
		return out
	if not LISTS.has(list):
		_refuse(level_id, "there is no traffic list '%s': %s" % [list, ", ".join(LISTS)])
		return out
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		_refuse(level_id, "traffic.json is not a JSON object (line %d: %s)" % [json.get_error_line(), json.get_error_message()])
		return out
	var flights_read: Variant = (json.data as Dictionary).get(list, [])
	if not (flights_read is Array):
		_refuse(level_id, "its '%s' is not a list of flights" % list)
		return out
	for flight in flights_read:
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
		if not ["kind", "from", "to", "spot", "count"].has(String(key)):
			return "'%s' is not a key a flight has" % key
	if not Sim.Kind.has(String(f.get("kind", ""))):
		return "a flight's kind '%s' is not one this build has" % f.get("kind", "")
	if f.has("count") and (not (f["count"] is float or f["count"] is int) or int(f["count"]) < 1
			or float(f["count"]) != float(int(f["count"]))):
		return "a flight's count is not a whole number from 1"
	for end in ["from", "to"]:
		if Airfield.named(String(f.get(end, ""))).is_empty():
			return "a flight's %s '%s' is not an airfield on this level" % [end, f.get(end, "")]
	return ""


static func _refuse(level_id: String, why: String) -> void:
	last_refusal = why
	push_warning("[traffic] %s: %s; that flight is left out" % [level_id, why])


## HOW MANY TIMES EACH COUNT IS FLOWN: `--traffic-scale=K` after the bare `--`, or 1.
static func scale_asked() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--traffic-scale="):
			return maxi(1, int(argument.trim_prefix("--traffic-scale=")))
	return 1


## PUT EVERY FLIGHT ON ITS STAND AND SEND IT, and each further copy in the air on its way. Host only; `traffic` is the
## level's `AirportTraffic`.
func start(level_id: String, list: String, flying: AirportTraffic) -> void:
	traffic = flying
	var scale: int = scale_asked()
	# ONE AEROPLANE LINED UP ON A RUNWAY AT A TIME: a field with no stand lines a flight up at the end in use, and the
	# stress list's second Cessna at the small field was put in the same place and took off beside the first.
	var lined_up: Dictionary = {}
	for flight in read(level_id, list):
		var copies: int = int(flight.get("count", 1)) * scale
		var from_id: String = String(flight["from"])
		var standless: bool = String(flight.get("spot", "")) == ""
		if standless and lined_up.has(from_id):
			_send_airborne(flight, 0.5 / float(copies), 0)
		else:
			_send(flight)
			if standless:
				lined_up[from_id] = true
		for k in range(1, copies):
			_send_airborne(flight, float(k) / float(copies), k)
	print("[traffic] %s: %d flights of '%s' on their way, scale %d" % [level_id, flights.size(), list, scale])


## ONE COPY IN THE AIR, `share` of the way from `from` to `to` (or round `to` for a circuit), at cruise, heading there,
## told to fly there and land.
func _send_airborne(flight: Dictionary, share: float, copy: int) -> void:
	var kind: int = Sim.Kind[String(flight["kind"])]
	var from: Dictionary = Airfield.named(String(flight["from"]))
	var to: Dictionary = Airfield.named(String(flight["to"]))
	var a: Vector3 = (from["frame"] as Dictionary)["centre"]
	var b: Vector3 = (to["frame"] as Dictionary)["centre"]
	var at: Vector3
	if a.distance_to(b) < 1.0:
		var angle: float = TAU * share
		at = b + Vector3(cos(angle), 0.0, sin(angle)) * CIRCUIT_OUT
	else:
		at = a.lerp(b, share)
	var heading: Vector3 = Vector3(b.x - at.x, 0.0, b.z - at.z).normalized()
	at.y = Terrain.highest_near(at, AIR_ROOM) + AIR_OVER + (EAST_ABOVE if heading.x >= 0.0 else 0.0) \
		+ LAYER * float(copy % LAYERS)
	var entity: int = Sim.spawn_ai_vehicle(kind, at, AirbasePlan.yaw_facing(heading), heading * Terrain.cruise_for(kind))
	if entity == 0:
		_refuse(String(flight["to"]), "the simulation would not put a %s in the air there" % flight["kind"])
		return
	flights[entity] = {"entity": entity, "kind": kind, "from": String(flight["from"]), "to": String(flight["to"]),
		"legs": 1, "landings": 0, "departures": 0, "parked_s": 0.0, "landed_at": []}
	traffic.fly_to(entity, to, kind)


func _send(flight: Dictionary) -> void:
	var kind: int = Sim.Kind[String(flight["kind"])]
	var from: Dictionary = Airfield.named(String(flight["from"]))
	var to: Dictionary = Airfield.named(String(flight["to"]))
	var base: Dictionary = AirbasePlan.on_runway(int(from["index"]))
	var spot_id: String = String(flight.get("spot", ""))
	var extents: Vector3 = Sim.geometry_of(kind).get("extents", Vector3.ONE)
	var at: Vector3
	var yaw: float
	if spot_id != "" and not base.is_empty() and (base["spots"] as Dictionary).has(spot_id):
		var spot: Dictionary = base["spots"][spot_id]
		at = AirbasePlan.standing_on_spot(base, spot, kind)
		yaw = float(spot["yaw"])
	else:
		if spot_id != "":
			_refuse(String(flight["from"]), "there is no stand '%s' at %s; it lines up on the runway instead" % [spot_id,
				flight["from"]])
			spot_id = ""
		# LINED UP ON THE END IN USE, a little way down the runway, facing along it.
		var frame: Dictionary = from["frame"]
		var landing_far: bool = String(from["in_use"]) == "far_end"
		var along: Vector3 = -(frame["along"] as Vector3) if landing_far else frame["along"]
		at = (frame[String(from["in_use"])] as Vector3) + along * 60.0
		yaw = AirbasePlan.yaw_facing(along)
	at += Vector3.UP * (extents.y + STAND_CLEARANCE)
	var entity: int = Sim.spawn_ai_vehicle(kind, at, yaw, Vector3.ZERO)
	if entity == 0:
		_refuse(String(flight["from"]), "the simulation would not put a %s there" % flight["kind"])
		return
	flights[entity] = {"entity": entity, "kind": kind, "from": String(flight["from"]), "to": String(flight["to"]),
		"legs": 1, "landings": 0, "departures": 1, "parked_s": 0.0, "landed_at": []}
	traffic.depart(entity, from, kind, spot_id, "", to)


## ONCE A SECOND, TURN ROUND WHATEVER HAS STOOD LONG ENOUGH: a flight whose pilot has parked, or come to rest clear of
## the runway at a field with no stands, at its destination.
func _physics_process(_delta: float) -> void:
	_ticks += 1
	if _ticks % LOOK_TICKS != 0 or traffic == null or Sim.server == null:
		return
	for entity in flights:
		var flight: Dictionary = flights[entity]
		var pilot: Dictionary = traffic.record_of(int(entity))
		if pilot.is_empty():
			continue
		var phase: StringName = pilot["phase"]
		var down: bool = phase == &"parked" or phase == &"stopped"
		if not down or String(pilot["field"]) != String(flight["to"]):
			flight["parked_s"] = 0.0
			continue
		if float(flight["parked_s"]) == 0.0:
			flight["landings"] = int(flight["landings"]) + 1
			(flight["landed_at"] as Array).append(String(flight["to"]))
		flight["parked_s"] = float(flight["parked_s"]) + float(LOOK_TICKS) / float(Engine.physics_ticks_per_second)
		if float(flight["parked_s"]) < TURNAROUND_S:
			continue
		# AND BACK THE WAY IT CAME, from wherever it stands now: the nearest stand to it, as `depart` finds it.
		var home: String = flight["from"]
		flight["from"] = flight["to"]
		flight["to"] = home
		flight["parked_s"] = 0.0
		flight["legs"] = int(flight["legs"]) + 1
		flight["departures"] = int(flight["departures"]) + 1
		traffic.depart(int(entity), Airfield.named(String(flight["from"])), int(flight["kind"]), "", "",
			Airfield.named(String(flight["to"])))
