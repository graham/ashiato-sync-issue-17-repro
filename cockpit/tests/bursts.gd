extends Node
## Headless: A BIG EXPLOSION COSTS NOTHING TO SET OFF -- no node, no material, no resource made at the moment one goes
## off -- and the pool, the lights and the sizes keep to their rules.
##
##   Godot --headless --path cockpit res://tests/bursts.tscn
##
## THE REAL YARD, IN THE REAL LEVEL. The explosions are set off through the level's own `ShotYard` and `MissileYard`,
## from a landed round row and a missile end, because the thing that could allocate is the path from a row to a burst
## and not `BurstYard.set_off` on its own.
##
## HOW IT CAN FAIL: `Performance`'s object, node and resource counts are read before and after thirty explosions. A
## `ShaderMaterial.new()` in `BurstYard.set_off` -- the bug this exists to catch, and the one it was proved against --
## is thirty more resources. A pool grown on demand, the way `Burst`'s is, is thirty more nodes.
##
## WHAT HEADLESS CANNOT SEE: whether a burst compiles a pipeline the first time it is drawn. `tests/fx_shot.gd` times
## the very first explosion after load, windowed, on the stock editor.
##
## Read RESULT=, not the exit code.

const EXPLOSIONS: int = 30
const HOWITZER: int = 6
const RIFLE: int = 7

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _fake: int = 800000


func _check(label: String, ok: bool, detail: String) -> void:
	print("[bursts] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	for i in range(240):
		await get_tree().physics_frame
	var yard: BurstYard = _level.bursts
	_check("the_level_has_one_burst_yard_and_hands_it_to_both", yard != null and _level.shots.bursts == yard
		and _level.missiles.bursts == yard, "%s" % [yard])
	if yard == null:
		_finish()
		return
	_check("and_it_has_warmed_up_by_the_time_anybody_is_flying", yard.warmed(), "warmed %s" % yard.warmed())
	_the_size_follows_the_simulation(yard)
	await _nothing_is_made_when_one_goes_off(yard)
	await _the_lights_keep_to_two_and_none_by_day(yard)
	await _a_barrage_then_a_volley_gives_way_oldest_first(yard)
	_finish()


## A 105 IS ITS CALIBRE TIMES THE TUNING, A MISSILE ITS FUSE, AND A BULLET IS NOT ONE AT ALL.
func _the_size_follows_the_simulation(yard: BurstYard) -> void:
	var bore: float = BurstTuning.calibre_mm(HOWITZER)
	_check("the_simulation_gives_the_105_its_calibre", is_equal_approx(bore, 105.0), "%.1f mm" % bore)
	_land(HOWITZER, Vector3(0.0, 300.0, 0.0))
	_check("a_105_lands_as_a_big_explosion_its_calibre_times_the_tuning",
		is_equal_approx(yard.newest_fireball(), bore * BurstTuning.fireball_per_mm()),
		"%.2f m, wanted %.1f x %.3f" % [yard.newest_fireball(), bore, BurstTuning.fireball_per_mm()])
	# EVERY HEAVY ROUND AT LEAST THREE TIMES THE BALL IT USED TO DRAW, which is the rule the size comes from.
	var small: Array[String] = []
	for ammo in Ammunition.LOOK:
		if not BurstTuning.is_heavy(int(ammo)):
			continue
		var across: float = BurstTuning.fireball_for_round(int(ammo)) * 2.0
		var before: float = float(Ammunition.look(int(ammo)).get("fireball", 0.0))
		if across < 3.0 * before - 0.01 or across <= 0.0:
			small.append("%s %.1f m against %.1f" % [Ammunition.look(int(ammo))["name"], across, before])
	_check("and_every_heavy_round_is_at_least_three_times_the_ball_it_used_to_draw", small.is_empty(),
		"%s" % ["105 %.1f m across" % (BurstTuning.fireball_for_round(HOWITZER) * 2.0) if small.is_empty() else small])
	var before: float = yard.newest_fireball()
	_land(RIFLE, Vector3(40.0, 300.0, 0.0))
	_check("and_a_machine_gun_round_is_not_a_big_explosion", yard.newest_fireball() == before
		and not BurstTuning.is_heavy(RIFLE), "newest still %.2f m" % yard.newest_fireball())
	# THE SMALLEST MISSILE AT THREE TIMES THE OLD NINE METRES, from its own fuse.
	var smallest: float = INF
	for kind in Sim.Kind.values():
		for station in (Sim.missile_schema(kind).get("stations", []) as Array):
			var fuse: float = float(Sim.missile_type(int((station as Dictionary).get("type", -1))).get("fuse_m", 0.0))
			if fuse > 0.0:
				smallest = minf(smallest, fuse)
	_check("the_smallest_missile_bursts_three_times_as_wide_as_before",
		BurstTuning.fireball_for_fuse(smallest) * 2.0 >= BurstTuning.LARGER_THAN_BEFORE * BurstTuning.BEFORE_ACROSS - 0.01,
		"fuse %.1f m -> %.1f m across" % [smallest, BurstTuning.fireball_for_fuse(smallest) * 2.0])


## THIRTY EXPLOSIONS AND NOT ONE THING MADE: no object created at the moment one goes off, and the pool, the nodes and
## the resources what they were.
##
## COUNTED AS CREATIONS, NOT AS WHAT IS LEFT. The first version read `Performance`'s live node and resource counts before
## and after, and was proved against a `ShaderMaterial.new()` in `BurstYard.set_off` -- which it PASSED, "+0 resources",
## because a material made and dropped inside the call is freed again before anybody counts (2026-09-14). That is the
## allocation at burst time the whole design exists to avoid, and a count of survivors cannot see it. So the thirty go
## off synchronously, with no frame between them, and the number of objects Godot created meanwhile is read off the
## instance-id serial: every Object takes the next value of one global counter, which is the id's bits above its 24-bit
## slot. Rows are Dictionaries, which are not Objects, so they do not count.
func _nothing_is_made_when_one_goes_off(yard: BurstYard) -> void:
	# ONE FIRST, so anything a first explosion legitimately settles -- a script's static cache of the calibres -- is
	# settled before the counting starts.
	_land(HOWITZER, Vector3(0.0, 280.0, 60.0))
	await get_tree().process_frame
	# THE COUNTER COUNTS, or this check is measuring nothing: five objects made between two readings is five.
	var calibrated: int = _object_serial()
	var kept: Array = []
	for i in range(5):
		kept.append(RefCounted.new())
	var five: int = _object_serial() - calibrated - 1
	_check("the_object_serial_counts_what_is_made", five == 5, "%d counted for 5 made" % five)
	var serial: int = _object_serial()
	for i in range(EXPLOSIONS):
		if i % 2 == 0:
			_land(HOWITZER, Vector3(float(i) * 30.0, 300.0, -400.0))
		else:
			_fake += 1
			_level.missiles.call("_end", _fake, MissileYard.FUSED, Vector3(float(i) * 30.0, 900.0, -400.0), 0)
	var made: int = _object_serial() - serial - 1
	_check("thirty_explosions_create_no_object_at_all", made == 0,
		"%d object(s) created by %d explosions" % [made, EXPLOSIONS])
	await get_tree().process_frame
	# ONE ROUND, ONE EXPLOSION, HOWEVER LONG ITS LANDED RECORD LINGERS. Drawn through the yard's own `draw_shots` for five
	# frames running, as the level draws `Sim.shots` while the simulation keeps a landed round before retiring it.
	for burst_node in yard.get_children():
		if burst_node is HeavyBurst:
			(burst_node as HeavyBurst).put_away()
	_fake += 1
	var lingering: Dictionary = {"entity": _fake, "from": Vector3(0.0, 350.0, -700.0), "velocity": Vector3.DOWN * 300.0,
		"ammo": HOWITZER, "drag": 0.0, "surface": Ammunition.GROUND, "flying": false, "impact": Vector3(0.0, 300.0, -700.0),
		"shooter": -1, "mount": 0}
	for i in range(5):
		_level.shots.draw_shots([lingering], Vector3.ZERO, 1.0 / 60.0)
	_check("a_landed_round_drawn_five_frames_goes_off_once", yard.going() == 1, "%d going" % yard.going())
	_level.shots.draw_shots([], Vector3.ZERO, 1.0 / 60.0)
	var pool: int = yard.pool()
	var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var resources: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var most: int = 0
	for i in range(EXPLOSIONS):
		if i % 2 == 0:
			_land(HOWITZER, Vector3(float(i) * 30.0, 300.0, 0.0))
		else:
			_fake += 1
			_level.missiles.call("_end", _fake, MissileYard.FUSED, Vector3(float(i) * 30.0, 900.0, 0.0), 0)
		most = maxi(most, yard.going())
		await get_tree().process_frame
	_check("thirty_explosions_never_grow_the_pool", yard.pool() == pool and pool == BurstTuning.AT_ONCE,
		"pool %d, cap %d" % [yard.pool(), BurstTuning.AT_ONCE])
	_check("and_never_draw_more_than_the_cap", most <= BurstTuning.AT_ONCE and most > 1,
		"at most %d going" % most)
	var made_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - nodes
	var made_resources: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) - resources
	_check("and_make_no_node", made_nodes <= 0, "%+d nodes" % made_nodes)
	_check("and_make_no_material_or_other_resource", made_resources <= 0, "%+d resources" % made_resources)
	print("[bursts] objects %+d across %d explosions (not judged: rows are dictionaries)"
		% [int(Performance.get_monitor(Performance.OBJECT_COUNT)) - objects, EXPLOSIONS])


func _the_lights_keep_to_two_and_none_by_day(yard: BurstYard) -> void:
	_level.choose_time(DaylightTuning.When.DAY)
	await get_tree().process_frame
	for i in range(4):
		_land(HOWITZER, Vector3(float(i) * 50.0, 300.0, 200.0))
	_check("by_day_an_explosion_lights_nothing", yard.lights_on() == 0, "%d lights" % yard.lights_on())
	_level.choose_time(DaylightTuning.When.NIGHT)
	await get_tree().process_frame
	for i in range(8):
		_fake += 1
		_level.missiles.call("_end", _fake, MissileYard.FUSED, Vector3(float(i) * 60.0, 900.0, 300.0), 0)
	_check("at_night_eight_missiles_light_two", yard.lights_on() == BurstTuning.LIGHTS_AT_ONCE,
		"%d lights" % yard.lights_on())
	for i in range(int(BurstTuning.LIGHT_S / (1.0 / 60.0)) + 30):
		await get_tree().process_frame
	_check("and_they_go_out_after_their_moment", yard.lights_on() == 0, "%d lights" % yard.lights_on())


## A TEN-ROUND BARRAGE, THEN EIGHT MISSILES, AND WHAT THE POOL OF TWELVE GAVE UP.
##
## Asked on 2026-09-14: a burst lives as long as its smoke and its ground fire, so a busy sky runs the pool out -- and a
## burst taken back in the middle of its fireball pops. Ten 105s half a second apart through the level's shot yard, as
## `tests/fx_shot`'s barrage fires them, then a volley of eight at once. Checked: ten fit without taking anything back;
## the volley takes back exactly the six it has to; and every one it takes is the oldest going at the time, never a
## fresh fireball. A burst that has gone out is taken before one still going (checked on its own below).
func _a_barrage_then_a_volley_gives_way_oldest_first(yard: BurstYard) -> void:
	for burst_node in yard.get_children():
		if burst_node is HeavyBurst:
			(burst_node as HeavyBurst).put_away()
	var before: int = yard.stolen()
	var frames_between: int = int(0.5 / (1.0 / 60.0))
	for i in range(10):
		_land(HOWITZER, Vector3(float(i) * 40.0, 300.0, 900.0))
		for f in range(frames_between):
			await get_tree().process_frame
	var after_barrage: int = yard.stolen() - before
	_check("a_ten_round_barrage_fits_the_pool_without_taking_anything_back", after_barrage == 0 and yard.going() == 10,
		"%d taken back, %d going" % [after_barrage, yard.going()])
	var wrong: Array[String] = []
	for i in range(8):
		var oldest_born: float = INF
		for burst_node in yard.get_children():
			var going := burst_node as HeavyBurst
			if going != null and going.visible and going.born < oldest_born:
				oldest_born = going.born
		var free: bool = yard.going() < yard.pool()
		_fake += 1
		_level.missiles.call("_end", _fake, MissileYard.FUSED, Vector3(float(i) * 60.0, 900.0, 1200.0), 0)
		# THE ONE IT TOOK: when none was free, the burst now newest must have been set off over the oldest.
		if not free:
			var still_there: bool = false
			for burst_node in yard.get_children():
				var going := burst_node as HeavyBurst
				if going != null and going.visible and is_equal_approx(going.born, oldest_born):
					still_there = true
			if still_there:
				wrong.append("missile %d kept the oldest (born %.2f) and took a younger one" % [i, oldest_born])
	var taken: int = yard.stolen() - before
	print("[bursts] pool of %d: a ten-round barrage then eight missiles took back %d burst(s) still going" % [yard.pool(), taken])
	_check("and_eight_missiles_after_it_take_back_only_the_ones_they_must", taken == 6, "%d taken back, wanted 6" % taken)
	_check("and_each_one_taken_back_was_the_oldest_going", wrong.is_empty(), "%s" % ["oldest first" if wrong.is_empty() else wrong])
	# A BURST THAT HAS GONE OUT IS TAKEN FIRST: one put away in the middle of a full pool is the one the next reuses.
	var middle: HeavyBurst = null
	var seen: int = 0
	for burst_node in yard.get_children():
		if burst_node is HeavyBurst and (burst_node as HeavyBurst).visible:
			seen += 1
			if seen == 6:
				middle = burst_node as HeavyBurst
	var stolen_before: int = yard.stolen()
	if middle != null:
		middle.put_away()
	_land(HOWITZER, Vector3(0.0, 300.0, 1500.0))
	_check("and_a_burst_that_has_gone_out_is_reused_before_one_still_going",
		middle != null and middle.visible and yard.stolen() == stolen_before,
		"reused the idle one: %s, taken back: %d" % [middle != null and middle.visible, yard.stolen() - stolen_before])


## THE SERIAL OF THE NEXT OBJECT GODOT CREATES, read off a probe object's instance id: the validator bits above the
## 24-bit slot, with the RefCounted flag in the top bit masked off. The probe is one creation itself.
static func _object_serial() -> int:
	var probe := RefCounted.new()
	return (probe.get_instance_id() >> 24) & ((1 << 39) - 1)


## A ROUND LANDING, as the level's shot yard is handed one: a birth row and then its impact row.
func _land(ammo: int, at: Vector3) -> void:
	_fake += 1
	var row: Dictionary = {"entity": _fake, "from": at + Vector3.UP * 50.0, "velocity": Vector3.DOWN * 300.0,
		"ammo": ammo, "drag": 0.0, "surface": Ammunition.GROUND, "flying": false, "impact": at, "shooter": -1}
	_level.shots.call("_land", _fake, row)


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
