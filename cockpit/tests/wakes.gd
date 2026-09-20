extends Node
## WHO WAKES AND WHO SPRAYS, ASKED OF THE LEVEL'S OWN YARDS ABOUT CRAFT THE SIMULATION IS MOVING.
##
##   Godot --headless --path cockpit res://tests/wakes.tscn
##
## Headless, so it cannot say whether a wake LOOKS like one -- that is `wake_shot`, which renders. What it holds is the
## rule the user gave (2026-09-17): a moving ship wakes and a stopped one does not; an aircraft within 3 m of the water
## and faster than 80 km/h sprays, and one at 4 m, or at 20 m/s, does not; the tanker afloat and moving wakes. And
## (2026-09-18) the WALL of spray: a fast skimmer raises one behind it, with height; a flying boat fast on its hull
## raises one; the same flying boat slow on the water has its wake and NO wall and no spray.
##
## DRIVEN FROM REAL STATE. Every craft is put on the sea through the server, which is the only way anything gets there,
## and every answer is read off `WakeYard` and `SprayYard` as the level drew them -- never off `WakeTuning`'s functions,
## which is what the yards call: a test that asked the rule would pass with the yards unplugged. Heights are of the
## craft's LOWEST point over the water, worked out here from the hull box, as the rule is: an origin at 2 m is a hull
## already in the sea.
##
## Read RESULT=, not the exit code.

## Where each craft is put, apart, on open sea.
const APART: float = 400.0
## How long the yards are given to look: a few samples of the wake, and a moment of spray before an unpiloted aeroplane
## has sunk far.
const WAKE_FOR: float = 2.0
const SPRAY_FOR: float = 0.25
## How long a flying boat is left on the water before it is looked at: long enough to lay wake and wall, short enough
## that neither has slowed past its rule.
const ON_THE_WATER_FOR: float = 1.0

var _failures: PackedStringArray = []
var _level: FlightLevel = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[wakes] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(120):
		await get_tree().physics_frame
	if _level.wakes == null or _level.spray == null or Sim.server == null:
		_check("the_level_has_wakes_spray_and_a_server", false, "wakes %s, spray %s, server %s" % [_level.wakes,
			_level.spray, Sim.server])
		_finish()
		return
	var sea: Vector3 = Terrain.open_sea_near(Vector3.ZERO, 20.0)
	_check("there_is_open_sea", sea != Vector3.INF, "%s" % sea)
	if sea == Vector3.INF:
		_finish()
		return
	var outward: Vector3 = Vector3(sea.x, 0.0, sea.z).normalized()
	var along: Vector3 = outward.cross(Vector3.UP).normalized()
	var out_at: Vector3 = sea + outward * 1500.0
	await _a_moving_ship_wakes_and_a_stopped_one_does_not(out_at, along)
	await _an_aircraft_low_and_fast_sprays_and_one_high_or_slow_does_not(out_at + outward * APART * 2.0, along)
	await _the_tanker_afloat_and_moving_wakes(out_at + outward * APART * 5.0, along)
	await _a_flying_boat_fast_on_the_water_raises_a_wall_and_slow_only_wakes(out_at + outward * APART * 8.0, along)
	_level.queue_free()
	await get_tree().process_frame
	Sim.stop()
	_finish()


## ---- the wakes -----------------------------------------------------------------------

## A LAUNCH UNDER WAY LEAVES A WAKE AND HAS A BOW WAVE; THE SAME LAUNCH STOPPED BESIDE IT HAS NEITHER.
func _a_moving_ship_wakes_and_a_stopped_one_does_not(at: Vector3, along: Vector3) -> void:
	var yaw: float = atan2(-along.x, -along.z)
	var moving: int = Sim.spawn_vehicle(Sim.Kind.BOAT, at, yaw, along * 10.0)
	var stopped: int = Sim.spawn_vehicle(Sim.Kind.BOAT, at + along.cross(Vector3.UP) * APART, yaw, Vector3.ZERO)
	await _seconds(WAKE_FOR)
	var under_way: int = _nearest_drawn(at + along * 10.0 * WAKE_FOR, 60.0)
	var still: int = _nearest_drawn(at + along.cross(Vector3.UP) * APART, 60.0)
	_check("a_launch_under_way_leaves_a_wake_and_a_bow_wave",
		under_way != 0 and _level.wakes.strength_of(under_way) > 0.5 and _level.wakes.pieces_behind(under_way) >= 2
			and _level.wakes.has_a_bow_wave(under_way),
		"%s: waking %.2f, %d pieces, bow wave %s" % [_speed_of(under_way), _level.wakes.strength_of(under_way),
			_level.wakes.pieces_behind(under_way), _level.wakes.has_a_bow_wave(under_way)])
	_check("and_one_stopped_is_followed_and_leaves_none",
		still != 0 and still != under_way and _level.wakes.strength_of(still) == 0.0
			and _level.wakes.pieces_behind(still) == 0 and not _level.wakes.has_a_bow_wave(still),
		"%s: waking %.2f, %d pieces" % [_speed_of(still), _level.wakes.strength_of(still),
			_level.wakes.pieces_behind(still)])
	Sim.server.despawn_vehicle(moving)
	Sim.server.despawn_vehicle(stopped)


## THE TANKER ON THE WATER, MOVING, WAKES -- as a boat, without being named anywhere as one.
func _the_tanker_afloat_and_moving_wakes(at: Vector3, along: Vector3) -> void:
	var tanker: int = Sim.spawn_vehicle(Sim.Kind.TANKER, at + Vector3.UP * 0.5, atan2(-along.x, -along.z), along * 9.0)
	await _seconds(WAKE_FOR)
	var drawn: int = _nearest_drawn(at + along * 9.0 * WAKE_FOR, 80.0)
	var state: Dictionary = Sim.current.get(drawn, {})
	var afloat: bool = drawn != 0 and absf((state.get("position", Vector3.ZERO) as Vector3).y) < 3.0
	_check("the_tanker_afloat_and_moving_wakes",
		afloat and _level.wakes.strength_of(drawn) > 0.3 and _level.wakes.pieces_behind(drawn) >= 2
			and _level.wakes.has_a_bow_wave(drawn),
		"%s at %.2f m: waking %.2f, %d pieces, bow wave %s" % [_speed_of(drawn),
			(state.get("position", Vector3.ZERO) as Vector3).y, _level.wakes.strength_of(drawn),
			_level.wakes.pieces_behind(drawn), _level.wakes.has_a_bow_wave(drawn)])
	Sim.server.despawn_vehicle(tanker)


## ---- the spray -----------------------------------------------------------------------

## AN AEROPLANE WHOSE LOWEST POINT IS 2 M OVER THE WATER AT 30 M/S SPRAYS; ONE AT 4 M, AND ONE AT 2 M AND 20 M/S, DO NOT.
## Three at once, apart, so the yard sees all three on the same frames.
func _an_aircraft_low_and_fast_sprays_and_one_high_or_slow_does_not(at: Vector3, along: Vector3) -> void:
	var yaw: float = atan2(-along.x, -along.z)
	var across: Vector3 = along.cross(Vector3.UP)
	var lowest: float = _lowest_below_origin(Sim.Kind.PLANE)
	var water: float = Terrain.water_height(at)
	var low_fast: Vector3 = Vector3(at.x, water + 2.0 + lowest, at.z)
	var high_fast: Vector3 = low_fast + across * APART + Vector3.UP * 2.0
	var low_slow: Vector3 = low_fast - across * APART
	var crafts: Array[int] = [Sim.spawn_vehicle(Sim.Kind.PLANE, low_fast, yaw, along * 30.0),
		Sim.spawn_vehicle(Sim.Kind.PLANE, high_fast, yaw, along * 30.0),
		Sim.spawn_vehicle(Sim.Kind.PLANE, low_slow, yaw, along * 20.0)]
	await _seconds(SPRAY_FOR)
	var sprays: int = _nearest_drawn(low_fast + along * 30.0 * SPRAY_FOR, 30.0)
	var high: int = _nearest_drawn(high_fast + along * 30.0 * SPRAY_FOR, 30.0)
	var slow: int = _nearest_drawn(low_slow + along * 20.0 * SPRAY_FOR, 30.0)
	# MEASURED FROM THE LOWEST POINT, NOT THE ORIGIN: what the yard says is the craft's height less its hull's depth
	# below its origin, to the 15 cm an unpiloted aeroplane's pitch moves a corner. Measured from the origin, the light
	# aeroplane's 0.7 m would still be under 3 m and spray, so the height alone could not tell (the mutant said so).
	var pose_y: float = ((Sim.current.get(sprays, {}) as Dictionary).get("position", Vector3.ZERO) as Vector3).y
	var expected: float = pose_y - lowest - water
	_check("an_aeroplane_2_m_over_the_water_at_30_m_s_sprays",
		sprays != 0 and absf(_level.spray.clearance_of(sprays) - expected) < 0.15
			and _level.spray.clearance_of(sprays) < WakeTuning.SPRAY_HEIGHT
			and _level.spray.strength_of(sprays) > 0.0 and _level.spray.thrown_by(sprays) > 0,
		"%s, lowest point %.2f m over the water (%.2f from its pose): spraying %.2f, %d puffs" % [_speed_of(sprays),
			_level.spray.clearance_of(sprays), expected, _level.spray.strength_of(sprays), _level.spray.thrown_by(sprays)])
	# THE WALL BEHIND IT: pieces laid, and a height handed to the drawer that is the spray's strength's share of the
	# tallest wall -- a wall of no height is no wall, and one at full height whatever the strength would not grow.
	_check("and_raises_a_wall_of_spray_behind_it",
		sprays != 0 and _level.spray.walls_laid_by(sprays) >= 2 and _level.spray.wall_height_of(sprays) > 1.0
			and _level.spray.wall_height_of(sprays) <= WakeTuning.SHEET_HEIGHT * _level.spray.strength_of(sprays) + 0.01,
		"%s: %d pieces of wall, rising to %.2f m at spraying %.2f" % [_speed_of(sprays),
			_level.spray.walls_laid_by(sprays), _level.spray.wall_height_of(sprays), _level.spray.strength_of(sprays)])
	_check("and_one_4_m_over_it_does_not",
		high != 0 and _level.spray.clearance_of(high) > WakeTuning.SPRAY_HEIGHT
			and _level.spray.strength_of(high) == 0.0 and _level.spray.thrown_by(high) == 0
			and _level.spray.walls_laid_by(high) == 0 and _level.spray.wall_height_of(high) == 0.0,
		"%s, lowest point %.2f m: spraying %.2f, %d puffs, %d pieces of wall" % [_speed_of(high),
			_level.spray.clearance_of(high), _level.spray.strength_of(high), _level.spray.thrown_by(high),
			_level.spray.walls_laid_by(high)])
	# LOW, from its pose: the yard does not measure a craft too slow to spray.
	var slow_low: float = ((Sim.current.get(slow, {}) as Dictionary).get("position", Vector3.ZERO) as Vector3).y \
		- lowest - water
	_check("and_one_2_m_over_it_at_20_m_s_does_not",
		slow != 0 and slow_low < WakeTuning.SPRAY_HEIGHT
			and _level.spray.strength_of(slow) == 0.0 and _level.spray.thrown_by(slow) == 0
			and _level.spray.walls_laid_by(slow) == 0 and _level.spray.wall_height_of(slow) == 0.0,
		"%s, lowest point %.2f m: spraying %.2f, %d puffs, %d pieces of wall" % [_speed_of(slow), slow_low,
			_level.spray.strength_of(slow), _level.spray.thrown_by(slow), _level.spray.walls_laid_by(slow)])
	for craft in crafts:
		Sim.server.despawn_vehicle(craft)


## THE SAVOIA ON ITS HULL: at 35 m/s it raises the wall, as close to the water as it can be, so as strongly as its speed
## allows; at 6 m/s beside it, it wakes and raises nothing -- "slow should just be the wake" (the user, 2026-09-18). An
## unpiloted flying boat on the water slows quickly (30 m/s was 25.4 two seconds later), so it is looked at after one.
func _a_flying_boat_fast_on_the_water_raises_a_wall_and_slow_only_wakes(at: Vector3, along: Vector3) -> void:
	var yaw: float = atan2(-along.x, -along.z)
	var across: Vector3 = along.cross(Vector3.UP)
	var water: float = Terrain.water_height(at)
	# THE HULL'S BOTTOM A HAND'S WIDTH IN THE WATER, from its pose: on it, not over it.
	var on: float = water + _lowest_below_origin(Sim.Kind.SAVOIA) - 0.1
	var fast_at := Vector3(at.x, on, at.z)
	var slow_at: Vector3 = fast_at + across * APART
	var crafts: Array[int] = [Sim.spawn_vehicle(Sim.Kind.SAVOIA, fast_at, yaw, along * 35.0),
		Sim.spawn_vehicle(Sim.Kind.SAVOIA, slow_at, yaw, along * 6.0)]
	await _seconds(ON_THE_WATER_FOR)
	var fast: int = _nearest_drawn(fast_at + along * 35.0 * ON_THE_WATER_FOR, 60.0)
	var slow: int = _nearest_drawn(slow_at + along * 6.0 * ON_THE_WATER_FOR, 40.0)
	_check("a_flying_boat_fast_on_its_hull_raises_the_wall",
		fast != 0 and _level.spray.clearance_of(fast) < WakeTuning.SPRAY_CLOSE_FULL
			and _level.spray.walls_laid_by(fast) >= 2 and _level.spray.wall_height_of(fast) > 1.0,
		"%s, lowest point %.2f m: spraying %.2f, %d pieces of wall rising to %.2f m" % [_speed_of(fast),
			_level.spray.clearance_of(fast), _level.spray.strength_of(fast), _level.spray.walls_laid_by(fast),
			_level.spray.wall_height_of(fast)])
	_check("and_slow_on_it_only_wakes",
		slow != 0 and slow != fast and _level.wakes.strength_of(slow) > 0.05 and _level.wakes.pieces_behind(slow) >= 1
			and _level.spray.walls_laid_by(slow) == 0 and _level.spray.wall_height_of(slow) == 0.0
			and _level.spray.thrown_by(slow) == 0,
		"%s: waking %.2f with %d pieces, %d pieces of wall, %d puffs" % [_speed_of(slow),
			_level.wakes.strength_of(slow), _level.wakes.pieces_behind(slow), _level.spray.walls_laid_by(slow),
			_level.spray.thrown_by(slow)])
	for craft in crafts:
		Sim.server.despawn_vehicle(craft)


## HOW FAR A KIND'S LOWEST POINT IS BELOW ITS ORIGIN, level: the hull box's bottom, or a wingtip if one hangs lower.
func _lowest_below_origin(kind: int) -> float:
	var geometry: Dictionary = Sim.geometry_of(kind)
	var lowest: float = ((geometry.get("extents", Vector3.ONE)) as Vector3).y
	for tip in WakeTuning.wingtips(kind, geometry):
		lowest = maxf(lowest, -(tip as Vector3).y)
	return lowest


## ---- helpers -------------------------------------------------------------------------

func _seconds(seconds: float) -> void:
	var gone: float = 0.0
	while gone < seconds:
		await get_tree().process_frame
		gone += get_process_delta_time()


## The entity this machine draws nearest a point, within `within` metres, or 0: the id the yards know it by.
func _nearest_drawn(near: Vector3, within: float) -> int:
	var best: int = 0
	var nearest: float = within
	for entity in Sim.current:
		var away: float = ((Sim.current[entity] as Dictionary).get("position", Vector3.ZERO) as Vector3).distance_to(near)
		if away < nearest:
			nearest = away
			best = int(entity)
	return best


func _speed_of(entity: int) -> String:
	var state: Dictionary = Sim.current.get(entity, {})
	return "%s %d at %.1f m/s" % [Sim.kind_name(int(state.get("kind", -1))), entity,
		(state.get("velocity", Vector3.ZERO) as Vector3).length()]


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
