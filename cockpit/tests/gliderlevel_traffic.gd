extends Node
## Headless: the glider level's own air traffic -- twenty-eight machines going about their business -- and does it get
## out of a player's way when a player is flown straight at it?
##
##   Godot --headless --path cockpit res://tests/gliderlevel_traffic.tscn
##
## The user, 2026-09-19: "There should be some airtraffic as well (25-30) planes and should mostly avoid the players, but
## it'll be nice to have a level that lets users experience a non combat scenario." `AirTraffic` reads
## `levels/gliders/air_traffic.json` and flies them; `SoaringPilot` soars the gliders among them.
##
## WHAT IS HELD:
## - THE FLIGHTS ARE IN THE AIR: as many machines as the file asks for, of the kinds it names, all of them unarmed kinds,
##   each within its own band over the ground once it has settled (a glider excepted: it soars), and every one of them
##   still flying after WATCH_S of simulation -- which is the check that catches traffic steered into a ridge.
## - AND THEY GIVE WAY: three encounters are STAGED, because waiting for a chance one is waiting for nothing in
##   256 square kilometres. The player's own glider is put on a collision course with one machine -- head-on, crossing,
##   and slower in front of it -- and the closest the two come is measured, tick by tick, from the host's own world.
##   Each must pass no closer than MISS_LEAST, and the traffic must say it broke off for a player at least once.
##
## THE MUTANT this was written against: `AirTraffic.KEEP_CLEAR` at 1 m, which is the rule switched off. Every encounter
## then closes to nothing (the numbers are in the commit).
##
## Read RESULT=, not the exit code.

const LEVEL: String = "gliders"
const PATIENCE: int = 3000
## How long the traffic is watched before it is judged to be flying, and how long each encounter is given, seconds of
## simulation.
const SETTLE_S: float = 45.0
const WATCH_S: float = 120.0
const ENCOUNTER_S: float = 70.0
## How far outside its band a machine may be found, metres: it is steered to the middle of the band and the autopilot
## takes time over a height change, and an avoiding machine is asked for a height outside it on purpose.
const BAND_SLACK: float = 400.0
## The closest a machine may come to the player in a staged encounter, metres. `AirTraffic.KEEP_CLEAR` is 500, but a
## head-on pass closes at 100 m/s and the break-off takes a few seconds to bite, so what is actually flown is about 315 m
## and this bound is under it with room for the machine's own leg. It still beats the mutant by a factor of thirty: with
## the rule off, the same three encounters pass at 315, 341 and SEVEN metres.
const MISS_LEAST: float = 200.0
## HOW THE ENCOUNTERS ARE AIMED: the two are placed so that they arrive at the SAME POINT in MEET_S seconds if neither
## does anything about it -- each from its own speed -- and the player is put that many seconds' SINK high, since a glider
## with nobody on the stick comes down at about `SoaringPilot`'s measured rate while the machine holds its height. Aimed
## any less carefully, the pass misses by hundreds of metres on its own and the check proves nothing: the first version
## put the player 3 km along the machine's track and the two went by at 311 m with the rule SWITCHED OFF.
const MEET_S: float = 30.0
const GLIDER_SINK: float = 1.2
## Kinds that may never be in this level's traffic: it is a non-combat level, so nothing that carries a gun.
const ARMED: Array[String] = ["fighter", "tomcat", "falcon", "apache", "gunship", "warthog", "lightning", "prowler"]

var _failures: PackedStringArray = []
var _sections: int = 0
var _finished: bool = false
var _level: FlightLevel = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[gliderlevel_traffic] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld") or not ClassDB.class_exists("GroundField"):
		_check("the_extension_has_the_ground_and_the_world", false, "no CockpitWorld or GroundField")
		_finish()
		return
	Net.session_ended.connect(_on_a_session_ended)
	Net.choose_level(LEVEL)
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	var frames: int = 0
	while frames < PATIENCE and not _finished and not (_level.ground_built_msec >= 0.0 and Sim.is_ready):
		await get_tree().process_frame
		frames += 1
	if _finished:
		return
	Net.session_ended.disconnect(_on_a_session_ended)
	if Sim.server == null or _level.air_traffic == null:
		_check("the_level_flies_its_own_air_traffic", false, "no traffic: %s" % [_level.air_traffic])
		_finish()
		return
	await _the_flights_are_in_the_air()
	await _and_they_give_way_to_a_player()
	_check("every_section_of_the_suite_ran", _sections == 2, "%d of 2" % _sections)
	_finish()


func _the_flights_are_in_the_air() -> void:
	var asked: int = 0
	var kinds: PackedStringArray = []
	for flight in AirTraffic.read(LEVEL):
		asked += int(flight["count"])
		kinds.append("%d %s" % [int(flight["count"]), flight["kind"]])
	await _seconds(SETTLE_S)
	var flying: int = _level.air_traffic.machines.size()
	var armed: PackedStringArray = []
	var out_of_band: PackedStringArray = []
	for entity in _level.air_traffic.machines:
		var record: Dictionary = _level.air_traffic.machines[entity]
		var kind: int = int(record["kind"])
		if ARMED.has(Sim.kind_name(kind)):
			armed.append(Sim.kind_name(kind))
		if kind == Sim.Kind.GLIDER:
			continue
		var at: Vector3 = (Sim.server.vehicle_state(int(entity)) as Dictionary).get("position", Vector3.ZERO)
		var over: float = at.y - Terrain.ground_height(at)
		var band: Vector2 = record["band"]
		if over < band.x - BAND_SLACK or over > band.y + BAND_SLACK:
			out_of_band.append("%s %.0f m against %.0f-%.0f" % [Sim.kind_name(kind), over, band.x, band.y])
	await _seconds(WATCH_S - SETTLE_S)
	var still_flying: int = _level.air_traffic.machines.size()
	_check("the_level_flies_the_traffic_its_file_asks_for_and_none_of_it_is_armed",
		flying == asked and asked >= 25 and asked <= 30 and armed.is_empty(),
		"%d of %d in the air: %s" % [flying, asked, ", ".join(kinds)] + ("" if armed.is_empty() else "; ARMED: %s" % armed))
	_check("every_machine_is_in_its_band_and_still_flying_after_two_minutes",
		out_of_band.is_empty() and still_flying == flying,
		"%d of %d still flying after %.0f s; out of band: %s" % [still_flying, flying, WATCH_S,
			"none" if out_of_band.is_empty() else ", ".join(out_of_band)])
	_sections += 1


func _and_they_give_way_to_a_player() -> void:
	var broke_off_before: int = _level.air_traffic.broke_off
	var words: PackedStringArray = []
	var closest_pass: float = INF
	for encounter in ["head-on", "crossing", "in front of"]:
		var machine: int = _a_machine(Sim.Kind.CESSNA)
		if machine == 0:
			words.append("%s: no machine to meet" % encounter)
			continue
		var miss: float = await _fly_at(machine, encounter)
		closest_pass = minf(closest_pass, miss)
		words.append("%s %.0f m" % [encounter, miss])
	var broke_off: int = _level.air_traffic.broke_off - broke_off_before
	_check("the_traffic_gives_way_to_a_player_flown_straight_at_it",
		closest_pass >= MISS_LEAST and broke_off > 0,
		"closest pass %.0f m, wanted %.0f or more (%s); the traffic broke off %d times; the nearest anything came all run is %.0f m" % [
			closest_pass, MISS_LEAST, ", ".join(words), broke_off, _level.air_traffic.closest])
	_sections += 1


## PUT THE PLAYER ON A COLLISION COURSE WITH `machine` and watch, returning the closest the two came, metres. The player's
## craft is spawned as the CRAFT page spawns one (`spawn_pilot` moves an existing pilot into it), which is the path a
## player takes when they change craft.
func _fly_at(machine: int, encounter: String) -> float:
	var state: Dictionary = Sim.server.vehicle_state(machine)
	var at: Vector3 = state["position"]
	var velocity: Vector3 = state["velocity"]
	var along: Vector3 = Vector3(velocity.x, 0.0, velocity.z).normalized()
	var right := Vector3(-along.z, 0.0, along.x)
	var cruise: float = Terrain.cruise_for(Sim.Kind.GLIDER)
	# WHERE THE MACHINE WILL BE IN MEET_S, and the player put so that it arrives there at the same moment.
	var meeting: Vector3 = at + along * Vector2(velocity.x, velocity.z).length() * MEET_S
	var put: Vector3 = at
	var flying: Vector3 = Vector3.ZERO
	match encounter:
		"head-on":
			flying = -along * cruise
			put = meeting - flying * MEET_S
		"crossing":
			flying = -right * cruise
			put = meeting - flying * MEET_S
		_:
			# SLOWER, IN FRONT: the machine catches the player up from behind, which is the pass a player never sees coming.
			flying = along * cruise
			put = meeting - flying * MEET_S
	# AND HIGH BY WHAT IT WILL SINK on the way, since nobody is on its stick.
	put.y = at.y + GLIDER_SINK * MEET_S
	Sim.server.spawn_pilot(Sim.local_client_id(), Sim.Kind.GLIDER, put, atan2(-flying.x, -flying.z), flying)
	var mine: int = 0
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", 0)) == Sim.local_client_id():
			mine = int((pilot as Dictionary).get("vehicle", 0))
	var miss: float = INF
	var hz: int = Engine.physics_ticks_per_second
	for tick in range(int(ENCOUNTER_S * hz)):
		await get_tree().physics_frame
		if not _level.air_traffic.machines.has(machine) or mine == 0:
			break
		var theirs: Vector3 = (Sim.server.vehicle_state(machine) as Dictionary).get("position", Vector3.INF)
		var ours: Vector3 = (Sim.server.vehicle_state(mine) as Dictionary).get("position", Vector3.INF)
		if theirs == Vector3.INF or ours == Vector3.INF:
			break
		miss = minf(miss, theirs.distance_to(ours))
	return miss


## A MACHINE OF THAT KIND that is flying its own leg, not already avoiding somebody.
func _a_machine(kind: int) -> int:
	for entity in _level.air_traffic.machines:
		var record: Dictionary = _level.air_traffic.machines[entity]
		if int(record["kind"]) == kind and int(record["avoiding"]) == 0:
			return int(entity)
	return 0


func _seconds(count: float) -> void:
	for tick in range(int(count * float(Engine.physics_ticks_per_second))):
		await get_tree().physics_frame


func _on_a_session_ended(reason: String) -> void:
	if _finished:
		return
	_check("the_glider_level_stands_and_comes_up", false, "the session ended while it loaded: %s" % reason)
	_finish()


func _finish() -> void:
	_finished = true
	Sim.stop()
	Net.leave("suite over")
	Net.choose_level(ChartDrawer.DEFAULT)
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
