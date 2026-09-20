extends Node
## SHIPS' WAKES AND LOW-PASS SPRAY, PHOTOGRAPHED: a ship under way from above and astern and from low beside, and an
## aeroplane and the tanker skimming the sea, frozen mid-spray. For the user to tune from (2026-09-17).
##
##   Godot --path cockpit --resolution 1600x900 res://tests/wake_shot.tscn -- --level=watch --clouds=none --out=C:/somewhere
##   ... -- --level=watch --views=wake_above,wake_low,spray_behind,spray_side --kinds=gunboat,carrier --finishes=plain,fine
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device. Whether a wake is a wake is for eyes; who
## wakes and who sprays is held headless by tests/wakes.gd.
##
##   wake_above / wake_low      the first ship of each `--kinds` under way in the watch level, from above and astern and
##                              from low beside, the camera riding with the ship; the level runs, so the wake is live.
##   wake_far                   the same ship from high astern, far enough to see the whole wake and its Kelvin V.
##   tanker_afloat              the water bomber put on open sea at TAXI m/s and left to run on its hull for TAXI_FOR
##                              seconds, from above and astern: the tanker "acts like a boat" when it is on the water.
##   cost                       ONLY WHEN ASKED, under a measurement slot: the level's ships topped up to 20 under way and
##                              5 aeroplanes skimming among them; the processor's lap and the GPU frame with the wakes
##                              and spray shown against hidden, frozen, alternated three times.
##   lake                       ON `--world=alpine` ONLY: the first lake the ground catalogues, drawn as water by
##                              LakeSheets, with the tanker put on it taxiing at TAXI m/s, from above and astern.
##   spray_behind / spray_side  an unpiloted aeroplane (then the tanker) put SKIM metres over open sea at SKIM_SPEED,
##                              flown FLY seconds, FROZEN -- the simulation and the level stop, which stops the clock every
##                              puff is aged on -- and photographed from behind and above, and from low beside.
##   spray_ahead                the same, from low beside and a little AHEAD, looking back along the wall of spray: the
##                              Porco Rosso still the wall was drawn from (2026-09-18). `--skim=<m>` sets how high the
##                              lowest point is put, `--skim-speed=<m/s>` how fast and `--fly=<s>` for how long;
##                              `--sheet=off` hides the wall and `--puffs=off` the puffs.
##   spray_above                the same, from straight overhead: the V of the wall seen in plan.
##
## Pictures go to `--out` (default `user://wake_shots`), `<view>-<what>-<finish>.png`.

const OUT := "user://wake_shots"
## Frames the level runs before the first picture, so the wakes behind the ships are long.
const WARM: int = 900
const SETTLE: int = 8
const KINDS: Dictionary = {"boat": Sim.Kind.BOAT, "gunboat": Sim.Kind.GUNBOAT, "carrier": Sim.Kind.CARRIER,
	"battleship": Sim.Kind.BATTLESHIP, "submarine": Sim.Kind.SUBMARINE, "pirate": Sim.Kind.PIRATE}
## The skimmers, in turn: the light aeroplane, the water bomber and the Savoia flying boat.
const SKIMMERS: Dictionary = {"plane": Sim.Kind.PLANE, "tanker": Sim.Kind.TANKER, "savoia": Sim.Kind.SAVOIA}
## How high the lowest point of a skimmer is put over the water, how fast, and how long it flies before the picture.
const SKIM: float = 2.2
const SKIM_SPEED: float = 45.0
const FLY: float = 1.2
## How fast the tanker is put on the water, and how long it runs on its hull before the picture.
const TAXI: float = 9.0
const TAXI_FOR: float = 6.0

var _level: FlightLevel = null
var _views: PackedStringArray = ["wake_above", "wake_low", "wake_far", "tanker_afloat", "spray_behind", "spray_side"]
var _kinds: PackedStringArray = ["gunboat", "carrier"]
var _skimmers: PackedStringArray = ["plane", "tanker"]
var _finishes: PackedStringArray = ["plain"]
var _skim: float = SKIM
var _skim_speed: float = SKIM_SPEED
var _sheet_shown: bool = true
var _fly: float = FLY
var _puffs_shown: bool = true
var _out: String = OUT
## `--time=<day|evening|night|...>`: the time of day every picture is taken at. Day unless asked.
var _time: int = DaylightTuning.When.DAY
var _failures: PackedStringArray = []
## The camera, in a ship's frame, re-placed every frame because the ship is under way; or a fixed world pose.
var _ship: VehicleView = null
var _from_local: Vector3 = Vector3.ZERO
var _toward_local: Vector3 = Vector3.ZERO
var _pose: Array = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[wake_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"views":
				_views = parts[1].split(",", false)
			"kinds":
				_kinds = parts[1].split(",", false)
			"skimmers":
				_skimmers = parts[1].split(",", false)
			"finishes":
				_finishes = parts[1].split(",", false)
			"skim":
				_skim = float(parts[1])
			"skim-speed":
				_skim_speed = float(parts[1])
			"sheet":
				_sheet_shown = parts[1] != "off"
			"fly":
				_fly = float(parts[1])
			"puffs":
				_puffs_shown = parts[1] != "off"
			"out":
				_out = parts[1]
			"time":
				var which: int = DaylightTuning.When.keys().find(parts[1].to_upper())
				if which >= 0:
					_time = which
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_viewport().scaling_3d_scale = PilotRig.RENDER_SCALE
	print("[wake_shot] %s, %s precision, %s on %s, window %s" % [Engine.get_version_info()["string"],
		"double" if OS.has_feature("double") else "single", RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(), DisplayServer.window_get_size()])
	# `--world=`, AS THE BOOT ROUTER READS IT: this probe loads the level itself, past the router that would.
	var world: Dictionary = ChartDrawer.asked_in(OS.get_cmdline_user_args(), "solo")
	if String(world["id"]) != "":
		Net.choose_level(String(world["id"]))
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	var words := _level.get_node_or_null("Ui") as CanvasLayer
	if words != null:
		words.visible = false
	_level.choose_time(_time)
	await _frames(WARM)
	# WHAT IS UNDER WAY, so a picture of a ship standing still is known for one.
	for entity in Sim.current:
		var state: Dictionary = Sim.current[entity]
		var speed: float = (state.get("velocity", Vector3.ZERO) as Vector3).length()
		if Terrain.is_a_ship(int(state.get("kind", -1))) or int(state.get("kind", -1)) == Sim.Kind.PIRATE:
			print("[wake_shot] afloat: %s %d at %.1f m/s, waking %.2f" % [Sim.kind_name(int(state["kind"])), int(entity),
				speed, _level.wakes.strength_of(int(entity))])
	var finish: Node = get_node("/root/Finish")
	for finish_name in _finishes:
		finish.call("choose", finish_name == "fine")
		await _frames(SETTLE)
		for view in _views:
			if view.begins_with("wake_"):
				for kind_name in _kinds:
					await _a_wake(view, kind_name, finish_name)
		if "tanker_afloat" in _views:
			await _tanker_afloat(finish_name)
		if "lake" in _views:
			await _on_a_lake(finish_name)
		if "cost" in _views:
			await _what_it_costs(finish_name)
		for view in _views:
			if view.begins_with("spray_"):
				for skimmer in _skimmers:
					await _a_spray(view, skimmer, finish_name)
	_finish()


## ---- a wake ---------------------------------------------------------------------------

func _a_wake(view: String, kind_name: String, finish_name: String) -> void:
	_ship = _under_way(int(KINDS.get(kind_name, -1)))
	_check("there_is_a_%s_under_way" % kind_name, _ship != null, "")
	if _ship == null:
		return
	var half: Vector3 = Sim.geometry_of(_ship.kind).get("extents", Vector3.ONE)
	var length: float = half.z * 2.0
	match view:
		"wake_above":
			# ABOVE AND ASTERN, to one side, looking forward and down past the stern at the ship: the churn runs from under
			# the eye to the hull and the arms open toward the camera.
			_from_local = Vector3(length * 0.45, length * 0.55 + 12.0, length * 1.6 + 25.0)
			_toward_local = Vector3(0.0, 0.0, length * 0.2)
		"wake_low":
			_from_local = Vector3(length * 0.9 + 15.0, 4.0, length * 1.1 + 10.0)
			_toward_local = Vector3(0.0, 0.0, length * 0.9)
		"wake_far":
			_from_local = Vector3(length * 0.3, length * 0.9 + 40.0, length * 3.2 + 90.0)
			_toward_local = Vector3(0.0, 0.0, length * 1.2)
	await _frames(SETTLE)
	var entity: int = _ship.entity
	var state: Dictionary = Sim.current.get(entity, {})
	print("[wake_shot] %s %s: %.1f m/s, waking %.2f, %d pieces behind, bow wave %s" % [view, kind_name,
		(state.get("velocity", Vector3.ZERO) as Vector3).length(), _level.wakes.strength_of(entity),
		_level.wakes.pieces_behind(entity), _level.wakes.has_a_bow_wave(entity)])
	await _save("%s-%s-%s" % [view, kind_name, finish_name])
	_ship = null


## The first craft of a kind moving faster than 3 m/s, or the fastest one.
func _under_way(kind: int) -> VehicleView:
	var best: int = 0
	var fastest: float = -1.0
	for entity in Sim.current:
		var state: Dictionary = Sim.current[entity]
		if int(state.get("kind", -1)) != kind:
			continue
		var speed: float = (state.get("velocity", Vector3.ZERO) as Vector3).length()
		if speed > fastest:
			fastest = speed
			best = int(entity)
	return _level.view_of(best) if best != 0 else null


## ---- the tanker on the water ---------------------------------------------------------

func _tanker_afloat(finish_name: String) -> void:
	var sea: Vector3 = Terrain.open_sea_near(Vector3.ZERO, 20.0)
	if sea == Vector3.INF:
		_check("there_is_open_sea", false, "")
		return
	var outward: Vector3 = Vector3(sea.x, 0.0, sea.z).normalized()
	var along: Vector3 = outward.cross(Vector3.UP).normalized()
	var start: Vector3 = sea + outward * 600.0 + Vector3.UP * 0.5
	var craft: int = Sim.spawn_vehicle(Sim.Kind.TANKER, start, atan2(-along.x, -along.z), along * TAXI)
	await _frames(2)
	_ship = _level.view_of(_drawn_entity_nearest(start))
	var length: float = (Sim.geometry_of(Sim.Kind.TANKER).get("extents", Vector3.ONE) as Vector3).z * 2.0
	_from_local = Vector3(length * 0.6, length * 0.7 + 6.0, length * 1.8 + 12.0)
	_toward_local = Vector3(0.0, 0.0, length * 0.4)
	var seconds: float = 0.0
	while seconds < TAXI_FOR:
		await get_tree().process_frame
		seconds += get_process_delta_time()
	var entity: int = _ship.entity if _ship != null else 0
	var state: Dictionary = Sim.current.get(entity, {})
	print("[wake_shot] tanker_afloat: %.1f m/s, %.2f m up, waking %.2f, %d pieces behind, bow wave %s, spraying %.2f" % [
		(state.get("velocity", Vector3.ZERO) as Vector3).length(), (state.get("position", Vector3.ZERO) as Vector3).y,
		_level.wakes.strength_of(entity), _level.wakes.pieces_behind(entity), _level.wakes.has_a_bow_wave(entity),
		_level.spray.strength_of(entity)])
	await _save("tanker_afloat-%s" % finish_name)
	# AND THE SAME FRAME WITH NEITHER YARD DRAWN, so whatever dark is left on the water there is not ours.
	_freeze()
	_level.wakes.visible = false
	_level.spray.visible = false
	await _save("tanker_afloat_bare-%s" % finish_name)
	# AND EACH OF THE WAKE'S TWO DRAWERS ALONE, to say which draws what.
	_level.wakes.visible = true
	(_level.wakes.get_node("BowWaves") as Node3D).visible = false
	await _save("tanker_afloat_trail_only-%s" % finish_name)
	(_level.wakes.get_node("BowWaves") as Node3D).visible = true
	(_level.wakes.get_node("Wakes") as Node3D).visible = false
	await _save("tanker_afloat_bow_only-%s" % finish_name)
	(_level.wakes.get_node("Wakes") as Node3D).visible = true
	_level.wakes.visible = true
	_level.spray.visible = true
	_run()
	_ship = null
	Sim.server.despawn_vehicle(craft)
	await _frames(SETTLE)


## ---- what it costs --------------------------------------------------------------------

## HOW MANY MOVING HULLS AND SKIMMING AIRCRAFT the cost is measured at: the brief's 20 ships and 5 aircraft.
const COST_SHIPS: int = 20
const COST_SKIMMERS: int = 5
const COST_FRAMES: int = 120
const COST_ROUNDS: int = 3


## WHAT THE WAKES AND THE SPRAY COST: the level's own moving ships topped up with launches to COST_SHIPS under way, and
## COST_SKIMMERS aeroplanes put 1.5 m over the sea at 45 m/s among them. The processor's share is the stopwatch's `wakes`
## lap over COST_FRAMES running frames; the GPU's is the frame with both yards shown against both hidden, frozen so the
## same puffs and pieces are drawn in every round, alternating COST_ROUNDS times, each the median of COST_FRAMES frames.
func _what_it_costs(finish_name: String) -> void:
	var sea: Vector3 = Terrain.open_sea_near(Vector3.ZERO, 20.0)
	if sea == Vector3.INF:
		return
	var outward: Vector3 = Vector3(sea.x, 0.0, sea.z).normalized()
	var along: Vector3 = outward.cross(Vector3.UP).normalized()
	var middle: Vector3 = sea + outward * 900.0
	var under_way: int = 0
	for entity in Sim.current:
		var state: Dictionary = Sim.current[entity]
		if Terrain.is_a_ship(int(state.get("kind", -1))) and (state.get("velocity", Vector3.ZERO) as Vector3).length() > 1.0:
			under_way += 1
	var spawned: Array[int] = []
	var added: int = maxi(COST_SHIPS - under_way, 0)
	for i in range(added):
		var at: Vector3 = middle + along * (float(i % 5) - 2.0) * 120.0 + outward * (float(i / 5) - 1.5) * 120.0
		var heading: Vector3 = along.rotated(Vector3.UP, float(i) * 0.7)
		spawned.append(Sim.spawn_vehicle(Sim.Kind.BOAT, at, atan2(-heading.x, -heading.z), heading * 10.0))
	var lowest: float = (Sim.geometry_of(Sim.Kind.PLANE).get("extents", Vector3.ONE) as Vector3).y
	for i in range(COST_SKIMMERS):
		var at: Vector3 = middle - along * 250.0 + outward * (float(i) - 2.0) * 60.0 + Vector3.UP * (lowest + 1.5)
		spawned.append(Sim.spawn_vehicle(Sim.Kind.PLANE, at, atan2(-along.x, -along.z), along * 45.0))
	_pose = [middle - along * 350.0 + Vector3.UP * 160.0 - outward * 150.0, middle]
	# `--sheet=off` PRICES THE SPRAY WITHOUT ITS WALL: the same scene, so the two runs' deltas are the wall's share.
	(_level.spray.get_node("Sheets") as Node3D).visible = _sheet_shown
	await _frames(30)
	var watch: Script = load("res://world/stopwatch.gd") as Script
	watch.call("run", true)
	watch.call("take")
	var laps: PackedFloat64Array = []
	var spray_laps: PackedFloat64Array = []
	for i in range(COST_FRAMES):
		await get_tree().process_frame
		var took: Dictionary = watch.call("take")
		laps.append(float(took.get(&"wakes", 0)) / 1000.0)
		spray_laps.append(float(took.get(&"spray", 0)) / 1000.0)
	watch.call("run", false)
	_freeze()
	var viewport: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var shown: PackedFloat64Array = []
	var hidden: PackedFloat64Array = []
	var counted: Dictionary = {}
	for round in range(COST_ROUNDS):
		for on in [true, false]:
			_level.wakes.visible = on
			_level.spray.visible = on
			await _frames(10)
			var gpu: PackedFloat64Array = []
			for i in range(COST_FRAMES):
				await RenderingServer.frame_post_draw
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
			(shown if on else hidden).append(_median(gpu))
			if round == 0:
				counted[on] = Vector2i(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	_level.wakes.visible = true
	_level.spray.visible = true
	await _save("cost-%s" % finish_name)
	var deltas: PackedFloat64Array = []
	for i in range(COST_ROUNDS):
		deltas.append(shown[i] - hidden[i])
	var added_draws: Vector2i = (counted.get(true, Vector2i.ZERO) as Vector2i) - (counted.get(false, Vector2i.ZERO) as Vector2i)
	print("[wake_shot] cost %s: %d draw calls and %d primitives added;" % [finish_name, added_draws.x, added_draws.y])
	print("[wake_shot] cost %s: %d ships under way (%d added), %d skimmers; wakes lap median %.3f ms, spray lap %.3f ms; GPU shown %s hidden %s ms, deltas %s ms; %d wake pieces laid" % [
		finish_name, under_way + added, added, COST_SKIMMERS, _median(laps), _median(spray_laps), shown, hidden, deltas,
		_level.wakes.pieces_laid()])
	_run()
	for craft in spawned:
		Sim.server.despawn_vehicle(craft)
	_pose = []
	await _frames(SETTLE)


static func _median(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


## ---- a lake --------------------------------------------------------------------------

func _on_a_lake(finish_name: String) -> void:
	var field: Object = Terrain.standing_on()
	var lakes: Array = ((field.call("catalogue") as Dictionary).get("lakes", []) as Array) if field != null else []
	var centre := Vector3.INF
	var widest: float = 0.0
	for entry in lakes:
		var at := Vector3(float(int(entry["x"])), 0.0, float(int(entry["z"])))
		var level: float = Terrain.water_height(at)
		if level > -INF and float(entry.get("water_radius", 0)) > widest:
			widest = float(entry.get("water_radius", 0))
			centre = Vector3(at.x, level, at.z)
	_check("there_is_a_lake", centre != Vector3.INF, "pass --world=alpine after the bare --")
	if centre == Vector3.INF:
		return
	var along := Vector3(1.0, 0.0, 0.0)
	var start: Vector3 = centre - along * minf(widest * 0.4, 150.0) + Vector3.UP * 0.5
	var craft: int = Sim.spawn_vehicle(Sim.Kind.TANKER, start, atan2(-along.x, -along.z), along * TAXI)
	# FROM THE SHORE FIRST, whether or not the tanker is found: the lake itself is the picture.
	_pose = [start - along * 60.0 + Vector3(0.0, 30.0, 45.0), start + along * 40.0]
	await _frames(4)
	var found: int = _drawn_entity_nearest(start)
	print("[wake_shot] lake: tanker spawned %d, drawn nearest %d" % [craft, found])
	_ship = _level.view_of(found) if found != 0 else null
	var length: float = (Sim.geometry_of(Sim.Kind.TANKER).get("extents", Vector3.ONE) as Vector3).z * 2.0
	_from_local = Vector3(length * 1.2, length * 0.9 + 8.0, length * 2.2 + 15.0)
	_toward_local = Vector3(0.0, 0.0, length * 0.4)
	var seconds: float = 0.0
	while seconds < TAXI_FOR:
		await get_tree().process_frame
		seconds += get_process_delta_time()
	var entity: int = _ship.entity if _ship != null else 0
	var state: Dictionary = Sim.current.get(entity, {})
	print("[wake_shot] lake at %s, %.0f m across: tanker %.1f m/s at %.2f m, waking %.2f, %d lake sheets" % [centre,
		widest * 2.0, (state.get("velocity", Vector3.ZERO) as Vector3).length(),
		(state.get("position", Vector3.ZERO) as Vector3).y, _level.wakes.strength_of(entity),
		_level.lakes.lakes_drawn().size() if _level.lakes != null else 0])
	await _save("lake-%s" % finish_name)
	# AND AS IT WAS BEFORE 2026-09-17, the same frame with no sheet on the lake: the ground's colours at its level.
	_freeze()
	if _level.lakes != null:
		_level.lakes.visible = false
		await _save("lake_undrawn-%s" % finish_name)
		_level.lakes.visible = true
	# THE LAKE ITSELF, with nothing on it: from low on the shore and from above, each with and without its sheet.
	_ship = null
	var outward := Vector3(0.0, 0.0, 1.0)
	var views: Dictionary = {
		"lake_low": [centre + outward * widest * 0.3 + Vector3.UP * 5.0, centre - outward * widest],
		"lake_above": [centre + outward * widest * 1.3 + Vector3.UP * widest * 0.7, centre]}
	for called in views:
		_pose = views[called]
		await _frames(SETTLE)
		await _save("%s-%s" % [called, finish_name])
		if _level.lakes != null:
			_level.lakes.visible = false
			await _save("%s_undrawn-%s" % [called, finish_name])
			_level.lakes.visible = true
	_run()
	_pose = []
	Sim.server.despawn_vehicle(craft)
	await _frames(SETTLE)


## ---- a spray --------------------------------------------------------------------------

func _a_spray(view: String, skimmer: String, finish_name: String) -> void:
	var kind: int = int(SKIMMERS.get(skimmer, -1))
	var sea: Vector3 = Terrain.open_sea_near(Vector3.ZERO, 20.0)
	_check("there_is_open_sea", sea != Vector3.INF, "")
	if sea == Vector3.INF or kind < 0:
		return
	# OUT FROM THE COAST, flying along it, so the picture is sea to the horizon.
	var outward: Vector3 = Vector3(sea.x, 0.0, sea.z).normalized()
	if outward.length() < 0.5:
		outward = Vector3.FORWARD
	var along: Vector3 = outward.cross(Vector3.UP).normalized()
	var geometry: Dictionary = Sim.geometry_of(kind)
	var half: Vector3 = geometry.get("extents", Vector3.ONE)
	var start: Vector3 = sea + outward * 800.0 + Vector3.UP * (half.y + _skim)
	var craft: int = Sim.spawn_vehicle(kind, start, atan2(-along.x, -along.z), along * _skim_speed)
	var sheets: Node3D = _level.spray.get_node_or_null("Sheets") as Node3D
	if sheets != null:
		sheets.visible = _sheet_shown
	(_level.spray.get_node("Spray") as Node3D).visible = _puffs_shown
	var at: Vector3 = start
	var seconds: float = 0.0
	var drawn: int = 0
	while seconds < _fly:
		at = _drawn_nearest(start + along * _skim_speed * seconds, at)
		_pose = [at - along * 40.0 + Vector3.UP * 10.0 + outward * 20.0, at]
		await get_tree().process_frame
		seconds += get_process_delta_time()
	drawn = _drawn_entity_nearest(at)
	_freeze()
	var span: float = maxf(float(geometry.get("span", 0.0)), half.x)
	if view == "spray_behind":
		_pose = [at - along * (half.z * 2.0 + 45.0) + Vector3.UP * (12.0 + span * 0.3) + outward * (span + 12.0),
			at - along * 12.0]
	elif view == "spray_above":
		_pose = [at - along * 30.0 + Vector3.UP * 70.0 + outward * 0.5, at - along * 30.0]
	elif view == "spray_ahead":
		_pose = [at + outward * (span * 1.3 + 22.0) + Vector3.UP * 1.5 + along * 14.0, at - along * 16.0 + Vector3.UP * 3.5]
	else:
		_pose = [at + outward * (span * 2.0 + 35.0) + Vector3.UP * 2.5 - along * 10.0, at - along * 14.0]
	print("[wake_shot] %s %s: clearance %.2f m, spraying %.2f, %d puffs thrown, waking %.2f" % [view, skimmer,
		_level.spray.clearance_of(drawn), _level.spray.strength_of(drawn), _level.spray.thrown_by(drawn),
		_level.wakes.strength_of(drawn)])
	await _save("%s-%s-%s" % [view, skimmer, finish_name])
	_pose = []
	_run()
	Sim.server.despawn_vehicle(craft)
	await _frames(SETTLE)


func _drawn_nearest(expected: Vector3, fallback: Vector3) -> Vector3:
	var entity: int = _drawn_entity_nearest(expected)
	if entity == 0:
		return fallback
	return (Sim.current[entity] as Dictionary).get("position", fallback) as Vector3


func _drawn_entity_nearest(near: Vector3) -> int:
	var best: int = 0
	var nearest: float = 300.0
	for entity in Sim.current:
		var away: float = ((Sim.current[entity] as Dictionary).get("position", Vector3.ZERO) as Vector3).distance_to(near)
		if away < nearest:
			nearest = away
			best = int(entity)
	return best


func _freeze() -> void:
	Sim.set_physics_process(false)
	Sim.previous = Sim.current
	_level.set_physics_process(false)
	_level.set_process(false)


func _run() -> void:
	Sim.set_physics_process(true)
	_level.set_physics_process(true)
	_level.set_process(true)


## ---- the camera -----------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _level == null or _level.observer == null:
		return
	var eye: Camera3D = _level.observer
	if _ship != null and is_instance_valid(_ship):
		eye.fov = 55.0
		var pose: Transform3D = _ship.global_transform
		# LEVEL, not rolled with the ship: the camera rides the ship's heading only.
		var ahead: Vector3 = -pose.basis.z
		var level := Basis.looking_at(Vector3(ahead.x, 0.0, ahead.z).normalized(), Vector3.UP)
		var frame := Transform3D(level, pose.origin)
		eye.call("look_from", frame * _from_local, frame * _toward_local)
	elif not _pose.is_empty():
		eye.fov = 55.0
		eye.call("look_from", _pose[0], _pose[1])


func _save(called: String) -> void:
	for i in range(6):
		await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join(called + ".png")
	_check("saved_%s" % called, picture.save_png(path) == OK, ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	_ship = null
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
