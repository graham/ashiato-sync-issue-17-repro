extends Node
## Headless: does everything that goes into the open sea come to rest on the seabed, rather than fall through the world?
##
##   Godot --headless --path cockpit res://tests/seabed.tscn          (the island)
##   Godot --headless --path cockpit res://tests/seabed_alpine.tscn   (the generated ground)
##   powershell -File tests\run_all.ps1 -Only seabed
##
## THE BUG. Neither world's open sea had a floor the physics could touch. The island's sea is not solid by design -- a
## water bomber skims it and `is_scooping` asks a ray to find nothing -- and the generated ground builds no height field
## for a cell whose every sample is at or below -40 m, so its seabed at -150 m was a number the height function answered
## and the collision did not have. Anything that went in fell for ever: dropped unflown from 40 m over open sea, an
## airliner reached -2,306 m in 40 s and a tank -3,821 m, identically on both worlds, and the wire clamped 25,545
## coordinates on the way (lane/sinking, 2026-09-16). The wire's floor is -200 m because the seabed was taken to be at
## -150 with 50 m under it for a hull, so every craft past it was drawn at -200 m by every other machine and the level
## raised "the wire clamped" once a second. It was found only by `chatter` running with the voice model, whose two
## unflown aeroplanes stalled into the island's sea fifty seconds after their spawn; without the model that suite ends in
## 3.5 s. This suite needs no model and runs the fall on purpose.
##
## WHAT IT HOLDS, on the level it is given (`level_id`), one process a world:
## - ONE OF EVERY KIND, dropped unflown from 40 m over open sea as deep as the seabed, the drop points asked of
##   `Terrain.open_sea_near` and kept `SPACING` apart, and the world watched for `WATCH_SECONDS`;
## - NOTHING IN THE WORLD GOES BELOW THE SEABED, on any tick, by the origin the server holds -- every vehicle, not only
##   the dropped ones. This is the check, and a wire clamp is only its symptom: a later change to the wire's floor would
##   quietly turn a clamp check green over the same hole, so the clamp count is held as well and second;
## - EVERY CRAFT THAT SANK IS AT REST ON THE SEABED at the end, so a floor that merely slowed the fall does not pass;
## - AND SOMETHING SANK, or the drop proved nothing.
##
## THE SEABED IS ASKED OF THE GROUND, as `far_out` asks it: a `GroundField` on `GroundTuning.values()` -- the generated
## ground's own function, the alpine world's bedrock -- read at its corner, which is open sea at its deepest
## (`ground_core.hpp`, `kSeabedMetres`, which is not bound to GDScript). Not of the floor this suite is holding.
## - AND THE FLOOR IS HELD TO IT on both worlds: the open sea under every drop must SOUND as deep as that seabed, within
##   `SOUNDING_AGREES`, by `water_depth_at`, the question the ships ask. On the island that sounding is the floor's own
##   height; on the generated ground it is the ground's. So moving either the floor or the ground's seabed turns this red.
##   Before the floor the island's open sea sounded inf.
##
## RED ON MAIN, this suite as written, before any floor existed (2026-09-16), identically on both worlds: 14 of the 22
## kinds sank, the first under the seabed a train at -150.36 m on tick 748, the deepest that train at -4,005.46 m doing
## 248 m/s after 30 s, none at rest; 34,363 wire clamps on the island and 34,380 on the generated ground. Through run_all,
## `seabed` failed four checks in 18.3 s -- the island's open sea sounding inf as well -- and `seabed_alpine` three in
## 28.1 s, its sounding already the ground's 149.98 m. `chatter`, left to run with the model, had clamped 31 to 63
## times over its own two craft; the same two, spawned as it spawns them in a probe with no voice, clamped 37 times, and
## eight kinds dropped from 40 m clamped 25,545 in 40 s.
##
## THROUGH A LEVEL CHANGE, on the island's run: island -> lobby -> island, the host's own `Net.change_level` out and the
## briefing room's launch board pressed back, each a scene reload that `_build`s a new simulation. After it the worlds are
## new objects and each was given ONE floor (`Seabed.floors_in`, looked up by path so this suite still runs where no
## floor exists), and an airliner dropped over open sea again comes to rest on the seabed. Asked for by team-lead because
## "after every restart" cuts both ways: a floor laid into a world that kept its last one would be two floors.
##
## Read RESULT=, not the exit code.

## Which level this run stands on: "island" or "alpine", a level id `Net.choose_level` takes. Set by the scene.
@export var level_id: String = "island"

## How far above the sea each craft is let go, metres: high enough that an aeroplane is in the air, low enough that the
## fall is short.
const DROP_HEIGHT: float = 40.0
## How far apart the drop points are asked for, metres: past the longest hull, so no two craft land on each other.
const SPACING: float = 600.0
## THE LAYOUT IS FROZEN AT TWENTY-SEVEN KINDS: the first drop is where it was when there were 27 of them, and a kind added
## since lands east of the last. The row was centred on however many kinds there were, `-0.5 * SPACING * N`, so adding a
## kind moved EVERY drop by 300 m -- and a check whose craft land somewhere else when an unrelated craft is added is not
## measuring what it says. littlebird's kind will append the same way. A short list -- the one airliner after the level
## change -- is centred exactly as before, because the freeze only bites past 27.
const FROZEN_AT_KINDS: int = 27
## AND NO TWO DROPS CLOSER THAN THIS, metres, AFTER `Terrain.open_sea_near` HAS SNAPPED THEM. The row asks for points
## `SPACING` apart, but the snap moves each to the nearest open sea, and on alpine it piled them up: the light helicopter
## came down 3 m from the train and slid on it at 0.08 m/s, over `AT_REST`, which read as the helicopter failing to come to
## rest (2026-09-18, the F-16's lane, when a new kind shifted the row); the F-16 came down 6 m from the submarine and sat on
## it at +2.3 m, never sinking, so it was not measured at all. A drop that lands this close to an earlier one is asked for
## again further out. Half of `SPACING`: past the longest hull's half-length, and still findable on alpine's sea.
const CLEAR_OF: float = 300.0
## How many times a crowded drop is asked for again, on a square spiral out from where it was first asked for, one
## `SPACING` a ring, before it is dropped anyway. Walking one way only found no clear sea on alpine: the battleship and the
## gunship still came down 8 m apart after twelve steps south.
const RETRIES: int = 48
## How long the world is watched, simulated seconds. The slowest to sink, the segway, passed -140 m 15.5 s after its
## drop onto a trial floor (2026-09-16); twice that, to come to rest.
const WATCH_SECONDS: float = 30.0
## How long the one airliner is watched after the level change: it passed -140 m 6.5 s after its drop.
const AFTER_THE_CHANGE_SECONDS: float = 15.0
## At rest: slower than this, metres a second. Every sunk craft on a trial floor read under 0.001 m/s after 60 s.
const AT_REST: float = 0.05
## ON THE SEABED: its origin no higher above the seabed's top than the craft's own hull box stands -- on its belly or on
## its side, whichever is taller (`_stands`, from `Sim.geometry_of(kind)["extents"]`, the box the physics collides) -- and
## within this many metres of that. It was one constant, 5 m, "the airliner rests highest, 2.6 m above it", until
## lane/liners drew the 747 at its real size (2026-09-19): its hull stands 5.025 m and it lay still 5.02 m up, flat on its
## own box, and read as not on the bed. A constant is the tallest hull somebody remembered; the table is the tallest there is.
const ON_THE_BED: float = 0.5
## Sunk: lower than this fraction of the seabed's depth at the end. A floating hull rolls a few metres under; nothing
## that floats is anywhere near half way down.
const SUNK_FRACTION: float = 0.5
## How far a ship's sounding of the open sea (`water_depth_at`) may be from the seabed, metres. With the floor: the island
## sounds 150.00 at every open-sea point and the generated ground 149.98 (2026-09-16).
const SOUNDING_AGREES: float = 1.0
## How many physics frames a level is given to come up.
const PATIENCE: int = 6000
## Where the floor lives, looked up by path rather than by class name: see the level change's note above.
const SEABED_SCRIPT: String = "res://world/seabed.gd"

var _failures: PackedStringArray = []
var _finished: bool = false


func _check(label: String, ok: bool, detail: String) -> void:
	print("[seabed] %s %s %s (%s)" % ["PASS" if ok else "FAIL", level_id, label, detail])
	if not ok:
		_failures.append(label)


## A WATCHER UNDER THE ROOT, as `level_swap` has one: the level is the current scene, and a level change reloads the
## current scene, which would free a suite that was it.
func _ready() -> void:
	if get_tree().current_scene != self:
		_run()
		return
	var watcher := Node.new()
	watcher.name = "SeabedWatch"
	watcher.set_script(get_script())
	watcher.set("level_id", level_id)
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld missing")
		_finish()
		return
	var chosen: String = Net.choose_level(level_id)
	_check("the_level_can_be_chosen", chosen == "", "'%s'" % chosen)
	Net.session_ended.connect(_on_a_session_ended)
	get_tree().change_scene_to_file.call_deferred("res://world/sky.tscn")
	if not await _level_is_up(level_id):
		return
	var seabed: float = _the_seabed()
	var wire: Dictionary = Sim.server.wire_range()
	_check("the_seabed_is_the_ground_s_and_above_the_wire_s_floor", seabed < 0.0 and seabed > float(wire["height_min"]),
		"seabed %.2f m, wire floor %.1f m" % [seabed, float(wire["height_min"])])
	var kinds: Array = Sim.Kind.keys()
	await _nothing_goes_below_the_seabed(seabed, kinds, WATCH_SECONDS)
	if level_id == "island":
		await _through_a_level_change(seabed)
	_finish()


## WAITS FOR A LEVEL to be the current scene with its simulation up (and on the generated ground, its ground built), then a
## second more. False, with the check failed, if it never comes.
func _level_is_up(id: String) -> bool:
	var frames: int = 0
	while frames < PATIENCE and not _finished:
		var level := get_tree().current_scene as FlightLevel
		if level != null and level.level != null and level.level.id == id and Sim.is_ready and Sim.server != null \
				and (level.level.world == "island" or level.room != null or level.ground_built_msec >= 0.0):
			break
		await get_tree().physics_frame
		frames += 1
	if _finished:
		return false
	var up := get_tree().current_scene as FlightLevel
	var ok: bool = up != null and up.level != null and up.level.id == id and Sim.is_ready
	_check("the_%s_level_comes_up" % id, ok, "after %d physics frames" % frames)
	if not ok:
		_finish()
		return false
	for i in range(Engine.physics_ticks_per_second):
		await get_tree().physics_frame
	return true


## THE OPEN SEA'S FLOOR, metres, asked of the ground's own function at its deepest point: see the note at the top.
func _the_seabed() -> float:
	var ground: Object = ClassDB.instantiate("GroundField")
	ground.call("configure", GroundTuning.values())
	var half: int = int(GroundTuning.values()["world_half"])
	return float(int(ground.call("height_ticks_at", half, half))) / 32.0


## THE `n`TH STEP OF A SQUARE SPIRAL round the origin, in rings: 8 cells on ring 1, 16 on ring 2, and so on.
static func _spiral(n: int) -> Vector3:
	var ring: int = 1
	var left: int = n
	while left >= 8 * ring:
		left -= 8 * ring
		ring += 1
	var side: int = left / (2 * ring)
	var along: int = left % (2 * ring) - ring + 1
	match side:
		0: return Vector3(float(along), 0.0, float(-ring))
		1: return Vector3(float(ring), 0.0, float(along))
		2: return Vector3(float(-along), 0.0, float(ring))
		_: return Vector3(float(-ring), 0.0, float(-along))


## WHETHER A DROP POINT IS WITHIN `CLEAR_OF` OF ANY CRAFT ALREADY DROPPED, measured flat.
func _crowded(at: Vector3, dropped: Dictionary) -> bool:
	for entity in dropped:
		var there: Vector3 = Sim.server.vehicle_state(entity)["position"]
		if Vector2(there.x - at.x, there.z - at.z).length() < CLEAR_OF:
			return true
	return false


func _nothing_goes_below_the_seabed(seabed: float, kinds: Array, seconds: float, tag: String = "") -> void:
	var clamps_before: int = int(Sim.server.wire_clamps())
	var dropped: Dictionary = {}
	for i in range(kinds.size()):
		var first: float = -0.5 * SPACING * float(mini(kinds.size(), FROZEN_AT_KINDS))
		var near := Vector3(first + float(i) * SPACING, 0.0, -13000.0)
		var sea: Vector3 = Terrain.open_sea_near(near, -seabed)
		var asked: Vector3 = near
		for attempt in range(RETRIES):
			if sea == Vector3.INF or not _crowded(sea, dropped):
				break
			sea = Terrain.open_sea_near(asked + _spiral(attempt) * SPACING, -seabed)
		if sea == Vector3.INF:
			continue
		var entity: int = Sim.spawn_vehicle(int(Sim.Kind[kinds[i]]), sea + Vector3.UP * DROP_HEIGHT, 0.0, Vector3.ZERO)
		if entity != 0:
			dropped[entity] = kinds[i]
	var closest: float = INF
	var pair: String = "none"
	var entities: Array = dropped.keys()
	for a in range(entities.size()):
		for b in range(a + 1, entities.size()):
			var pa: Vector3 = Sim.server.vehicle_state(entities[a])["position"]
			var pb: Vector3 = Sim.server.vehicle_state(entities[b])["position"]
			var d: float = Vector2(pa.x - pb.x, pa.z - pb.z).length()
			if d < closest:
				closest = d
				pair = "%s and %s" % [dropped[entities[a]], dropped[entities[b]]]
	# PRINTED, NOT ASSERTED: on alpine the open sea is too small for every drop to keep `CLEAR_OF`, and a craft that comes
	# down on a floating ship is never counted as sunk -- so it is not measured at all. Open in `cockpit/agents.md`
	# ("the seabed suite's drops pile up on alpine"); a check here would be red on main too.
	print("[seabed] NOTE %s closest drops: %s, %.0f m apart (wanted %.0f)" % [level_id, pair, closest, CLEAR_OF])
	_check("one_of_each_kind_asked_for_is_dropped_over_open_sea%s" % tag, dropped.size() == kinds.size(),
		"%d of %d kinds: %s" % [dropped.size(), kinds.size(), dropped.values()])
	# THE SEA UNDER EVERY DROP IS AS DEEP AS THE SEABED, as the ships sound it: the one check that holds the floor's height
	# to the ground's. See the note at the top.
	var sounded: PackedStringArray = []
	for entity in dropped:
		var at: Vector3 = Sim.server.vehicle_state(entity)["position"]
		var depth: float = float(Sim.server.water_depth_at(at.x, at.z))
		if not (absf(depth + seabed) <= SOUNDING_AGREES):
			sounded.append("%s %.2f m" % [dropped[entity], depth])
	_check("the_open_sea_sounds_as_deep_as_the_seabed%s" % tag, sounded.is_empty(),
		"seabed %.2f m; soundings that disagree by more than %.1f m: %s" % [seabed, SOUNDING_AGREES, sounded])
	# EVERY VEHICLE IN THE WORLD, EVERY TICK, by the server's own origin.
	var deepest: float = INF
	var deepest_is: String = "nothing"
	var first_under: String = ""
	for f in range(int(seconds * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
		if _finished or Sim.server == null:
			return
		for vehicle in Sim.server.vehicle_states():
			var y: float = (vehicle["position"] as Vector3).y
			if y < deepest:
				deepest = y
				deepest_is = "%s %d" % [Sim.Kind.find_key(int(vehicle["kind"])), int(vehicle["entity"])]
			if y < seabed and first_under.is_empty():
				first_under = "%s %d at %.2f m on tick %d" % [Sim.Kind.find_key(int(vehicle["kind"])),
					int(vehicle["entity"]), y, f]
	_check("nothing_in_the_world_goes_below_the_seabed%s" % tag, first_under.is_empty(),
		"seabed %.2f m; deepest %s at %.2f m; first under it: %s" % [seabed, deepest_is, deepest,
			first_under if not first_under.is_empty() else "none"])
	var clamps: int = int(Sim.server.wire_clamps()) - clamps_before
	_check("and_the_wire_clamped_nothing%s" % tag, clamps == 0, "%d coordinates" % clamps)
	# EVERY CRAFT THAT SANK, AT REST ON THE BED.
	var sunk: PackedStringArray = []
	var restless: PackedStringArray = []
	for entity in dropped:
		var state: Dictionary = Sim.server.vehicle_state(entity)
		if state.is_empty():
			restless.append("%s gone" % dropped[entity])
			continue
		var at: Vector3 = state["position"]
		if at.y > seabed * SUNK_FRACTION:
			continue
		var speed: float = (state["velocity"] as Vector3).length()
		var stands: float = _stands(dropped[entity])
		sunk.append("%s %.2f m" % [dropped[entity], at.y])
		if speed > AT_REST or at.y - seabed > stands + ON_THE_BED or at.y < seabed:
			restless.append("%s at %.2f m doing %.3f m/s, its hull standing %.2f m" % [dropped[entity], at.y, speed,
				stands])
	_check("something_sank%s" % tag, not sunk.is_empty(), "%d sank" % sunk.size())
	_check("every_craft_that_sank_is_at_rest_on_the_seabed%s" % tag, not sunk.is_empty() and restless.is_empty(),
		"sunk %s; not resting on the bed: %s" % [sunk, restless])
	for entity in dropped:
		Sim.server.despawn_vehicle(entity)


## HOW HIGH A KIND'S ORIGIN STANDS OFF A FLOOR IT LIES ON, metres: the taller of its hull box's half-height and half-width,
## so a craft that came to rest on its side still counts. Asked of the shape table, never typed here.
func _stands(kind_name: String) -> float:
	var extents: Vector3 = Sim.geometry_of(int(Sim.Kind[kind_name])).get("extents", Vector3.ZERO)
	return maxf(extents.x, extents.y)


func _through_a_level_change(seabed: float) -> void:
	var worlds_before: Array[int] = [Sim.client.get_instance_id(), Sim.server.get_instance_id()]
	# OUT, BY THE HOST'S OWN CALL: the island has no board to press, and this is the call the board and the clipboard reach.
	var why: String = Net.change_level("lobby")
	_check("the_host_takes_the_session_to_the_lobby", why == "", "'%s'" % why)
	if why != "" or not await _level_is_up("lobby"):
		return
	# BACK, BY THE BRIEFING ROOM'S LAUNCH BOARD, its island button pressed as a press emits.
	var lobby := get_tree().current_scene as FlightLevel
	var charts := lobby.room.board.shown() as ChartMenu if lobby.room != null and lobby.room.board != null else null
	_check("the_briefing_room_has_an_island_button", charts != null and charts.level_buttons.has("island"),
		"%s" % [charts.level_buttons.keys() if charts != null else "no board"])
	if charts == null or not charts.level_buttons.has("island"):
		return
	(charts.level_buttons["island"] as Button).pressed.emit()
	if not await _level_is_up("island"):
		return
	var worlds_after: Array[int] = [Sim.client.get_instance_id(), Sim.server.get_instance_id()]
	var floors := PackedInt32Array()
	var laid: Script = load(SEABED_SCRIPT) as Script if ResourceLoader.exists(SEABED_SCRIPT) else null
	for world in [Sim.client, Sim.server]:
		floors.append(int(laid.call("floors_in", world)) if laid != null else 0)
	_check("after_island_lobby_island_the_worlds_are_new_and_each_has_one_floor",
		worlds_after[0] not in worlds_before and worlds_after[1] not in worlds_before and floors == PackedInt32Array([1, 1]),
		"client, server %s before and %s after; floors laid in each %s" % [worlds_before, worlds_after, floors])
	await _nothing_goes_below_the_seabed(seabed, ["AIRLINER"], AFTER_THE_CHANGE_SECONDS, "_after_the_level_change")


func _on_a_session_ended(reason: String) -> void:
	if _finished:
		return
	_check("the_session_stays_up", false, "the session ended: %s" % reason)
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	Sim.stop()
	Net.leave("suite over")
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
