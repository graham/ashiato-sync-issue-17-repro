extends Node
## Headless: the three jets' guns and missiles -- the F/A-18F, the F-14D and the F-16 -- fired by the pilot, through the
## level, the rig and the desk's own keys, against the real simulation (lane/jetarms, 2026-09-18).
##
##   Godot --headless --path cockpit res://tests/jet_arms.tscn
##
## THE USER'S WORDS: "yes, guns for sure, and missiles." lane/kinds found that `loadout_of` had no case for any of the
## three, while their models drew gun ports and pylons. So for each jet, from the pilot's seat:
##
## - SAFE, the trigger fires no round and the launch key launches nothing, and the seat is told "not armed";
## - ARMED, a second of the trigger is the M61's 6,000 rounds a minute, every round born at THIS jet's muzzle and
##   leaving along its bore at 1,050 m/s over the jet's own velocity, and none of them strikes the jet that fired it;
## - the drum counts down on every machine, runs dry at the jet's real count, fires nothing dry, and is full again
##   after its rearm time;
## - each missile station locks an aircraft down the nose and launches from its own rails, and the missile flies to
##   the target and fuses on it; the radar station refuses a launch without a lock;
## - and a station's rails run out: two launches empty them and the third is refused as empty.
##
## Nothing here calls `fire_gun` or `launch_missile`: every press is a key event with both codes set, and every count is
## of rounds and missiles with this client's name on them, as the simulation reports them.
##
## Read RESULT=, not the exit code.

const JETS: Array = [Sim.Kind.FIGHTER, Sim.Kind.TOMCAT, Sim.Kind.FALCON, Sim.Kind.PHANTOM]
## THE M61's RATE, a round a second: 6,000 a minute (Wikipedia, "M61 Vulcan"). Typed here on purpose, as the
## thing the loadout is checked AGAINST: read from the loadout, a wrong rate would agree with itself.
const M61_PER_SECOND: float = 100.0
## THE PGU-28's muzzle velocity, m/s (the same article).
const M61_MUZZLE: float = 1050.0
## HOW FAR A ROUND MAY BE BORN FROM THE MUZZLE, across and up in the jet's own frame: the wire rounds a position to a
## few centimetres, and the pose the round was born from may be the tick before the one read here, which at 150 m/s
## and a few degrees of angle of attack is a tenth of a metre up. Another jet's muzzle is more than half a metre away.
const MUZZLE_ACROSS: float = 0.25
## ...and along the nose, where one tick of flight is a metre and a quarter.
const MUZZLE_ALONG: float = 2.0

var _failures: PackedStringArray = []
var _level: FlightLevel = null
## `-- --shot=<dir>`, windowed: where the pictures of each jet go -- its missiles on the rails, the gun firing, a launch
## and a missile on its way -- taken by a camera set beside the jet for the moment and then stood down. Headless has
## no rendering device and takes none.
var _shot_dir: String = ""
var _camera: Camera3D = null
## `--reel`, with `--shot=` and Godot's `--write-movie`: no stills; a camera stays current the whole pass, chasing
## the jet over the pilot's shoulder and then the missile, so the movie writer records one continuous reel.
var _reel: bool = false
var _chasing: Node3D = null
var _chase_offset: Vector3 = Vector3.ZERO
var _chase_look: Vector3 = Vector3.ZERO
var _sections: int = 0
## Four sections a jet: in, the gun, the drum, the missiles. PER JET, and multiplied by `JETS.size()` where it is
## used: it read `4 * 3`, so adding a fourth jet failed with `16 of 12` and the number to fix was in a different
## place from the roster that moved it. It cannot be `const SECTIONS = 4 * JETS.size()` -- GDScript refuses that as
## not a constant expression, and the refusal is a PARSE ERROR, which hangs rather than fails (400 s to find out).
const SECTIONS_A_JET: int = 4


func _check(label: String, ok: bool, detail: String) -> void:
	print("[jet_arms] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(240):
		await get_tree().physics_frame
	_check("the_library_counts_a_drum", Sim.client != null and Sim.client.has_method("gun_rounds"), "gun_rounds")
	if Sim.client == null or not Sim.client.has_method("gun_rounds"):
		_finish()
		return
	var rig: PilotRig = _level.rig
	# A TANKER, parked in the sky beside the island, whose water rides the byte the jets' drums ride
	# (`CraftSystems::load`: the gun count on a jet, the fuel/water load on a tanker). Its load is held where it was
	# once the jets have fired and emptied their drums: see `_the_tankers_load_is_its_own`.
	var tanker: int = int(Sim.server.spawn_vehicle(Sim.Kind.TANKER, Vector3(2000.0, 900.0, 2000.0), 0.0, Vector3.ZERO))
	var tanker_before: float = float(Sim.server.tank_load(tanker))
	# `-- --jet=<name>` flies one jet alone, for a quicker look; the gate flies all three.
	var only: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--jet="):
			only = argument.trim_prefix("--jet=")
		if argument.begins_with("--shot="):
			_shot_dir = argument.trim_prefix("--shot=")
		if argument == "--reel":
			_reel = true
	# `--shot=`: THE PICTURE PASS, and nothing else -- see `_pictures_of`.
	if _shot_dir != "":
		for kind in JETS:
			if only == "" or only == _name_of(kind):
				await _pictures_of(rig, kind, _name_of(kind))
		print("RESULT=PICTURES")
		get_tree().quit()
		return
	for kind in JETS:
		var name: String = _name_of(kind)
		if only != "" and only != name:
			_sections += 4
			continue
		if not await _the_pilot_gets_into(rig, kind, name):
			continue
		await _the_gun(rig, kind, name)
		await _the_drum(rig, kind, name)
		await _the_missiles(rig, kind, name)
	_the_tankers_load_is_its_own(tanker, tanker_before)
	_check("every_section_of_the_suite_ran", _sections == SECTIONS_A_JET * JETS.size(),
		"%d of %d" % [_sections, SECTIONS_A_JET * JETS.size()])
	_finish()


## THE TANKER'S LOAD IS ITS OWN. The jets' drums ride the byte its water rides, so a drum that wrote to the wrong craft --
## or a tank that read a drum -- would move it; and a tanker has no counted gun, so it answers -1 for rounds.
func _the_tankers_load_is_its_own(tanker: int, before: float) -> void:
	var after: float = float(Sim.server.tank_load(tanker))
	_check("a_tankers_load_is_untouched_by_the_jets_drums", tanker != 0 and before > 0.99 and absf(after - before) < 0.001
		and int(Sim.server.gun_rounds(tanker)) == -1, "tanker %d: load %.3f before, %.3f after; rounds %d" % [tanker,
			before, after, int(Sim.server.gun_rounds(tanker)) if tanker != 0 else -9])
	Sim.server.despawn_vehicle(tanker)


## ---- getting in ------------------------------------------------------------------------

## INTO THE JET'S FRONT SEAT, as the clipboard asks for one, and the seat is fitted for what the simulation says it
## carries: a lock sight, a master arm switch, a stick that launches and whose trigger also fires the gun.
func _the_pilot_gets_into(rig: PilotRig, kind: int, name: String) -> bool:
	rig.ask_for_kind(kind)
	var view: VehicleView = null
	for i in range(900):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and view.kind == kind and rig.seat_index() == 0:
			break
	var ok: bool = view != null and view.kind == kind and rig.seat_index() == 0
	_check("%s_the_player_gets_into_its_pilot_seat" % name, ok,
		"kind %s, seat %d" % [view.kind if view != null else "-", rig.seat_index()])
	if not ok:
		return false
	for i in range(30):
		await get_tree().physics_frame
	var schema: Dictionary = Sim.missile_schema(kind)
	var names: PackedStringArray = []
	for entry in (schema.get("stations", []) as Array):
		names.append(String((entry as Dictionary).get("name", "")))
	_check("%s_carries_heat_radar_and_guns" % name, names.size() == 3 and names.has("heat") and names.has("guns")
		and (names.has("radar") or names.has("active radar")), ", ".join(names))
	var station: CockpitStation = view.station_for(0)
	var stick := station.controls().get("stick") as FlightStick if station != null else null
	_check("%s_its_pilot_has_a_lock_sight_a_master_arm_and_a_stick_that_launches_and_fires" % name,
		station != null and station.find_child("LockSight", true, false) is LockSight
		and station.get_node_or_null("MasterArm") is ToggleSwitch and stick != null and stick.launches
		and stick.fires_a_gun, "station %s, stick %s" % [station, stick])
	# THE BACK SEAT, on the two-seaters: a repeater of the pilot's sight, and no launch of its own.
	if kind != Sim.Kind.FALCON:
		var back: CockpitStation = view.station_for(1)
		_check("%s_its_back_seat_repeats_the_pilots_sight_and_launches_nothing" % name, back != null
			and back.find_child("LockSight", true, false) is LockSight and not back.launches()
			and back.get_node_or_null("MasterArm") == null, "station %s" % back)
	_sections += 1
	return true


## ---- the gun ---------------------------------------------------------------------------

func _the_gun(rig: PilotRig, kind: int, name: String) -> void:
	var view: VehicleView = rig.vehicle_view()
	var guns: Dictionary = _station_named(kind, "guns")
	await _disarm(view)
	await _select_station(view, int(guns.get("station", -1)))
	_check("%s_the_station_key_reaches_the_guns" % name,
		int(Sim.client.craft_systems(view.entity).get("weapon", -1)) == int(guns.get("station", -2)),
		"weapon %s" % Sim.client.craft_systems(view.entity).get("weapon"))
	var safe: Dictionary = await _burst(view, 60)
	_check("%s_safe_the_trigger_fires_nothing" % name, int(safe["born"]) == 0, "%d round(s)" % int(safe["born"]))
	await _arm(view)
	var burst: Dictionary = await _burst(view, 120)
	var born: int = int(burst["born"])
	# A SECOND AT 120 Hz: the first round on the key's first tick and one every 1.2 ticks after it. One either way is
	# where in the second the tick edges fall; 7,200 a minute -- a round every tick -- is twenty over.
	_check("%s_a_second_of_the_trigger_is_6000_a_minute" % name, absf(float(born) - M61_PER_SECOND) <= 2.0,
		"%d rounds in 120 ticks, wanted %.0f" % [born, M61_PER_SECOND])
	var at: Vector3 = _drawn_gun_port(view)
	_check("%s_every_round_is_born_at_the_gun_port_its_model_draws" % name, born > 0 and float(burst["worst_across"]) <= MUZZLE_ACROSS
		and float(burst["worst_along"]) <= MUZZLE_ALONG,
		"worst %.2f m across, %.2f m along, from the muzzle at %s; first round at %s in the jet's frame" % [
			float(burst["worst_across"]), float(burst["worst_along"]), at, burst["first_local"]])
	_check("%s_and_leaves_along_its_bore_at_1050" % name, born > 0 and float(burst["worst_bore"]) <= 0.01
		and absf(float(burst["slowest"]) - M61_MUZZLE) <= 2.0 and absf(float(burst["fastest"]) - M61_MUZZLE) <= 2.0,
		"worst %.4f rad off the nose, %.1f to %.1f m/s over the jet's own" % [float(burst["worst_bore"]),
			float(burst["slowest"]), float(burst["fastest"])])
	# NONE STRIKES THE JET THAT FIRED IT: a muzzle inside the collision box is a round whose first ray cast starts there.
	for i in range(60):
		await get_tree().physics_frame
	var self_hits: int = 0
	var mine: Vector3 = _server_state(view).get("position", Vector3.ZERO) as Vector3
	for row in Sim.server.shot_states():
		var shot: Dictionary = row
		if burst["ids"].has(int(shot.get("entity", 0))) and int(shot.get("surface", 0)) == 3 \
				and (shot.get("impact", Vector3.INF) as Vector3).distance_to(mine) < 40.0:
			self_hits += 1
	_check("%s_and_no_round_strikes_the_jet_that_fired_it" % name, self_hits == 0, "%d" % self_hits)
	_sections += 1


## HOLD THE FIRE KEY FOR `frames` physics frames and watch every round the SERVER makes with this client's name on it,
## measured against the server's own pose of this jet: where it was born in the jet's frame, how far off the nose it
## left, and how fast over the jet's own velocity.
func _burst(view: VehicleView, frames: int) -> Dictionary:
	var out: Dictionary = {"born": 0, "ids": {}, "worst_across": 0.0, "worst_along": 0.0, "worst_bore": 0.0,
		"slowest": INF, "fastest": 0.0, "first_local": Vector3.INF}
	var seen: Dictionary = {}
	for row in Sim.server.shot_states():
		seen[int((row as Dictionary).get("entity", 0))] = true
	var muzzle: Vector3 = _drawn_gun_port(view)
	var code: Key = _key_of("fire")
	_key(code, true)
	for i in range(frames + 30):
		if i == frames:
			_key(code, false)
		await get_tree().physics_frame
		var state: Dictionary = _server_state(view)
		if state.is_empty():
			continue
		var basis := Basis(state["basis"] as Quaternion)
		var position: Vector3 = state["position"]
		var velocity: Vector3 = state.get("velocity", Vector3.ZERO)
		for row in Sim.server.shot_states():
			var shot: Dictionary = row
			var entity: int = int(shot.get("entity", 0))
			if seen.has(entity):
				continue
			seen[entity] = true
			if int(shot.get("shooter", -1)) != Sim.local_client_id():
				continue
			out["born"] = int(out["born"]) + 1
			(out["ids"] as Dictionary)[entity] = true
			# THIS TICK'S POSE OR THE LAST ONE'S, whichever the round came from: the nearer.
			var from: Vector3 = shot["from"]
			var here: Vector3 = basis.inverse() * (from - position) - muzzle
			var then: Vector3 = basis.inverse() * (from - (position - velocity * Sim.tick_dt())) - muzzle
			var local: Vector3 = here if here.length() < then.length() else then
			if not (out["first_local"] as Vector3).is_finite():
				out["first_local"] = local + muzzle
			out["worst_across"] = maxf(float(out["worst_across"]), Vector2(local.x, local.y).length())
			out["worst_along"] = maxf(float(out["worst_along"]), absf(local.z))
			var own: Vector3 = (shot["velocity"] as Vector3) - velocity
			out["worst_bore"] = maxf(float(out["worst_bore"]), own.angle_to(-basis.z))
			out["slowest"] = minf(float(out["slowest"]), own.length())
			out["fastest"] = maxf(float(out["fastest"]), own.length())
	return out


## ---- the drum --------------------------------------------------------------------------

## THE COUNT GOES DOWN ON EVERY MACHINE, RUNS OUT AT THE JET'S DRUM, AND COMES BACK. The server's count is exact; this
## machine's is the share on the wire, and agrees to within one step of it.
func _the_drum(rig: PilotRig, kind: int, name: String) -> void:
	var view: VehicleView = rig.vehicle_view()
	var guns: Dictionary = _station_named(kind, "guns")
	var drum: int = int(guns.get("rounds", 0))
	# THE NUMBERS ARE TYPED HERE ON PURPOSE and not read from the loadout: a test that asks the code under test what
	# it should be is a tautology. The F-4E's 640 is the published figure for the mark with the internal gun.
	var wanted: int = {Sim.Kind.FIGHTER: 412, Sim.Kind.TOMCAT: 675, Sim.Kind.FALCON: 500,
		Sim.Kind.PHANTOM: 640}[kind]
	_check("%s_carries_its_real_drum" % name, drum == wanted, "%d rounds, wanted %d" % [drum, wanted])
	var server_id: int = _server_id(view)
	var left: int = int(Sim.server.gun_rounds(server_id))
	for i in range(30):
		await get_tree().physics_frame
	var here: int = int(Sim.client.gun_rounds(view.entity))
	_check("%s_the_count_went_down_by_what_was_fired_and_this_machine_reads_it" % name,
		left > 0 and left < drum and absi(here - left) <= ceili(float(drum) / 255.0) + 1,
		"server %d, this machine %d, of %d" % [left, here, drum])
	# EMPTY IT: the key held until the server says none are left, counting every round.
	var fired: int = 0
	var code: Key = _key_of("fire")
	var seen: Dictionary = {}
	for row in Sim.server.shot_states():
		seen[int((row as Dictionary).get("entity", 0))] = true
	_key(code, true)
	for i in range(1200):
		await get_tree().physics_frame
		fired += _new_rounds(seen)
		if int(Sim.server.gun_rounds(server_id)) == 0:
			break
	_key(code, false)
	for i in range(3):
		await get_tree().physics_frame
		fired += _new_rounds(seen)
	_check("%s_it_runs_dry_after_exactly_what_was_left" % name,
		int(Sim.server.gun_rounds(server_id)) == 0 and fired == left, "fired %d of %d left" % [fired, left])
	var dry: Dictionary = await _burst(view, 60)
	for i in range(10):
		await get_tree().physics_frame
	_check("%s_dry_the_trigger_fires_nothing_and_every_machine_reads_empty" % name, int(dry["born"]) == 0
		and int(Sim.client.gun_rounds(view.entity)) == 0, "%d round(s), this machine reads %d" % [int(dry["born"]),
			int(Sim.client.gun_rounds(view.entity))])
	# AND FULL AGAIN after its rearm time, counted from the last round.
	var rearm: float = float(guns.get("rearm_s", 0.0))
	for i in range(int((rearm + 0.5) * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
	_check("%s_and_it_is_full_again_after_its_rearm" % name, int(Sim.server.gun_rounds(server_id)) == drum
		and int(Sim.client.gun_rounds(view.entity)) == drum, "server %d, this machine %d, after %.1f s" % [
			int(Sim.server.gun_rounds(server_id)), int(Sim.client.gun_rounds(view.entity)), rearm + 0.5])
	_sections += 1


func _new_rounds(seen: Dictionary) -> int:
	var count: int = 0
	for row in Sim.server.shot_states():
		var entity: int = int((row as Dictionary).get("entity", 0))
		if seen.has(entity):
			continue
		seen[entity] = true
		if int((row as Dictionary).get("shooter", -1)) == Sim.local_client_id():
			count += 1
	return count


## ---- the missiles ----------------------------------------------------------------------

## EACH MISSILE STATION LOCKS AN AIRCRAFT AND LAUNCHES FROM ITS OWN RAILS, AND THE MISSILE FLIES TO IT. The radar
## station first refuses a launch without a lock; then two launches empty its rails and a third is refused as empty.
func _the_missiles(rig: PilotRig, kind: int, name: String) -> void:
	var view: VehicleView = rig.vehicle_view()
	var heat: Dictionary = _station_named(kind, "heat")
	var radar: Dictionary = _station_named(kind, "radar")
	if radar.is_empty():
		radar = _station_named(kind, "active radar")
	# SAFE REFUSES: the heat station, a target on the nose and a lock, and the launch key launches nothing.
	await _disarm(view)
	await _select_station(view, int(heat.get("station", -1)))
	var target: int = _put_a_target_on_the_nose(view, 1200.0)
	await _lock_within(view, 3.0)
	var before: int = _mine().size()
	await _hold("launch", 3)
	for i in range(30):
		await get_tree().physics_frame
	_check("%s_safe_the_launch_key_launches_nothing_and_says_why" % name, _mine().size() == before
		and String(_server_lock().get("why_name", "")).contains("arm"),
		"%d missile(s); why %s" % [_mine().size() - before, _server_lock().get("why_name", "-")])
	# AND THE BACK SEAT'S REPEATER SAYS WHAT THE PILOT'S SIGHT SAYS, with the lock in it.
	var back: CockpitStation = view.station_for(1)
	if back != null and back.find_child("LockSight", true, false) is LockSight:
		var says: String = ""
		for i in range(60):
			await get_tree().process_frame
			says = (back.find_child("LockSight", true, false) as LockSight).says()
			if says.contains("LOCKED"):
				break
		_check("%s_the_back_seat_sees_the_pilots_lock" % name, says.begins_with("PILOT'S SIGHT") and says.contains("LOCKED"),
			says.replace("
", " | "))
	await _arm(view)
	await _launch_and_follow(view, name, "heat", heat, target)
	await _the_rails_are_drawn_as_the_bus_says(view, name)
	await _let_go_of_the_lock()
	# THE RADAR STATION REFUSES WITHOUT A LOCK.
	await _select_station(view, int(radar.get("station", -1)))
	before = _mine().size()
	await _hold("launch", 3)
	for i in range(30):
		await get_tree().physics_frame
	_check("%s_the_radar_station_refuses_a_launch_without_a_lock" % name, _mine().size() == before,
		"%d missile(s); why %s" % [_mine().size() - before, _server_lock().get("why_name", "-")])
	# 800 m, NOT 1,500: nobody is flying this jet, and a hands-off Tomcat drifts round a turn. At 1,500 m its Sparrow --
	# SEMI-ACTIVE, blind the moment the launcher's lock goes -- lost the target out of the 1.0 rad gimbal 5.4 s after
	# launch, a second short, and hit the ground. That is the row working, and a pilot would have held the nose on it.
	_despawn(target)
	target = _put_a_target_on_the_nose(view, 800.0)
	var locked: bool = await _lock_within(view, 4.0)
	if not locked:
		print("[jet_arms] %s radar lock not taken: %s" % [name, _lock_detail(view, target)])
	await _launch_and_follow(view, name, String(radar.get("name", "")), radar, target)
	_despawn(target)
	await _let_go_of_the_lock()
	# THE RAILS RUN OUT: the heat station, whose rows need no lock, fired twice half a second apart -- inside the rails'
	# own rearm time -- empties both its rails, and a third press is refused as empty.
	await _select_station(view, int(heat.get("station", -1)))
	var pylons: int = 0
	for id in (heat.get("pylon_ids", []) as Array):
		pylons |= 1 << int(id)
	for i in range(int(6.0 * Engine.physics_ticks_per_second)):
		if (int(Sim.client.craft_systems(view.entity).get("stores", 0)) & pylons) == pylons:
			break
		await get_tree().physics_frame
	before = _mine().size()
	for launch in range(2):
		await _hold("launch", 3)
		for i in range(80):
			await get_tree().physics_frame
	var stores: int = int(Sim.client.craft_systems(view.entity).get("stores", -1))
	_check("%s_two_launches_empty_the_heat_rails" % name, _mine().size() == before + 2 and (stores & pylons) == 0,
		"%d more, stores %d, heat rails %d" % [_mine().size() - before, stores, pylons])
	before = _mine().size()
	await _hold("launch", 3)
	for i in range(30):
		await get_tree().physics_frame
	_check("%s_and_a_third_is_refused_as_empty" % name, _mine().size() == before
		and String(_server_lock().get("why_name", "")).contains("empty"),
		"%d missile(s); why %s" % [_mine().size() - before, _server_lock().get("why_name", "-")])
	await _let_go_of_the_lock()
	_sections += 1


## ONE LAUNCH ON THE SELECTED STATION AT `target`: the missile is this station's row, off one of its rails, and flies
## to the target -- its closest approach inside the row's fuse, and it ends on a fuse or a strike.
func _launch_and_follow(view: VehicleView, name: String, row_name: String, station: Dictionary, target: int) -> void:
	var before: Array = _mine()
	var ids: Dictionary = {}
	for row in before:
		ids[int((row as Dictionary).get("entity", 0))] = true
	var phase: String = String(_server_lock().get("phase_name", "-"))
	var locked_on: int = int(_server_lock().get("target", 0))
	await _hold("launch", 3)
	var entity: int = 0
	for i in range(60):
		await get_tree().physics_frame
		for row in Sim.server.missile_states():
			var one: Dictionary = row
			if int(one.get("client", -1)) == Sim.local_client_id() and not ids.has(int(one.get("entity", 0))):
				entity = int(one.get("entity", 0))
		if entity != 0:
			break
	var row: Dictionary = _server_missile(entity)
	_check("%s_%s_launches_on_a_lock" % [name, row_name.replace(" ", "_")], entity != 0
		and String(row.get("type_name", "")) == row_name
		and (station.get("pylon_ids", []) as Array).has(int(row.get("pylon", -1))),
		"lock %s; missile %d, row %s, pylon %s of %s" % [phase, entity, row.get("type_name", "-"),
			row.get("pylon", "-"), station.get("pylon_ids", [])])
	if entity == 0:
		return
	var type: Dictionary = Sim.missile_type(int(station.get("type", 0)))
	print("[jet_arms] %s %s launched: %s" % [name, row_name, _lock_detail(view, target)])
	_check("%s_%s_launched_on_a_lock_that_is_the_target_this_test_spawned" % [name, row_name.replace(" ", "_")], locked_on == target,
		"lock on %d, test target %d" % [locked_on, target])
	var lost_at: float = -1.0
	var flown: float = 0.0
	var closest: float = INF
	var surface: int = -1
	for i in range(int(20.0 * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
		row = _server_missile(entity)
		if row.is_empty():
			break
		flown += Sim.tick_dt()
		if lost_at < 0.0 and int(_server_lock().get("phase", 0)) != LockSight.Phase.LOCKED:
			lost_at = flown
			print("[jet_arms] %s %s: the launcher's lock went at %.2f s: %s" % [name, row_name, flown,
				_lock_detail(view, target)])
		var them: Dictionary = Sim.server.vehicle_state(target)
		if not them.is_empty():
			closest = minf(closest, (row["position"] as Vector3).distance_to(them["position"] as Vector3))
		if not bool(row.get("flying", true)):
			surface = int(row.get("surface", -1))
			var own: Vector3 = _server_state(view).get("position", Vector3.ZERO) as Vector3
			print("[jet_arms] %s %s ended at age %.2f s, %.0f m from its launcher, guided %s, hit %s" % [name, row_name,
				float(row.get("age", 0.0)), (row["position"] as Vector3).distance_to(own), row.get("guided"),
				row.get("target_hit")])
			break
	_check("%s_and_the_%s_flies_to_the_target_and_fuses_on_it" % [name, row_name.replace(" ", "_")],
		closest <= float(type.get("fuse_m", 0.0)) + 2.0 and (surface == 5 or surface == 3),
		"closest %.1f m against a %.0f m fuse, ended on surface %d" % [closest, float(type.get("fuse_m", 0.0)), surface])


## THE MISSILES DRAWN ON THE RAILS ARE THE BUS'S: every rail the model hangs a missile on is shown exactly while its bit is
## set -- checked with one just fired, so an empty rail is among them.
func _the_rails_are_drawn_as_the_bus_says(view: VehicleView, name: String) -> void:
	var stores: HungStores = view.hung_stores()
	var hung: int = 0
	var drawn: int = -1
	var bus: int = -1
	for i in range(30):
		await get_tree().process_frame
		if stores == null:
			break
		hung = 0
		for rail in stores.rails():
			if rail != null:
				hung |= 1 << int(String(rail.name).trim_prefix("Store"))
		drawn = stores.drawn()
		bus = int(Sim.client.craft_systems(view.entity).get("stores", -1))
		if drawn == (bus & hung) and bus & hung != hung:
			break
	_check("%s_the_rails_are_drawn_loaded_and_empty_as_the_bus_says" % name, stores != null and hung == 0xF
		and drawn == (bus & hung) and (bus & hung) != hung, "hung %d, drawn %d, bus %d" % [hung, drawn, bus])


## ---- helpers ---------------------------------------------------------------------------

## THE GUN PORT THE JET'S MODEL DRAWS, in the craft's frame -- the airframe's own `gun_port()`, turned into the view's
## frame. NOT the loadout's muzzle: held to the loadout, a gun moved to the wrong place in C++ would agree with itself.
func _drawn_gun_port(view: VehicleView) -> Vector3:
	var frame: Node3D = view._visual_scene
	if view._tomcat != null:
		frame = view._tomcat
	if view._falcon != null:
		frame = view._falcon
	if view._phantom != null:
		frame = view._phantom
	if frame == null or not frame.has_method("gun_port"):
		_check("%s_its_model_draws_a_gun_port" % _name_of(view.kind), false, "airframe %s" % frame)
		return Vector3.INF
	return view.global_transform.affine_inverse() * frame.global_transform * (frame.call("gun_port") as Vector3)


## WHERE THE TARGET IS FROM THIS SEAT'S SEEKER, for a lock that did not come: the row, the range and angle off the
## server's nose, and the jet's own height and pitch.
func _lock_detail(view: VehicleView, target: int) -> String:
	var mine: Dictionary = _server_state(view)
	var theirs: Dictionary = Sim.server.vehicle_state(target)
	if mine.is_empty() or theirs.is_empty():
		return "no state (target %d)" % target
	var nose: Vector3 = -Basis(mine["basis"] as Quaternion).z
	var to: Vector3 = (theirs["position"] as Vector3) - (mine["position"] as Vector3)
	return "row %s; target %.0f m, %.3f rad off the nose; jet at %.0f m, nose %.1f deg up" % [_server_lock(), to.length(),
		nose.angle_to(to), (mine["position"] as Vector3).y, rad_to_deg(asin(clampf(nose.y, -1.0, 1.0)))]


func _station_named(kind: int, wanted: String) -> Dictionary:
	for entry in (Sim.missile_schema(kind).get("stations", []) as Array):
		if String((entry as Dictionary).get("name", "")) == wanted:
			return entry
	return {}


func _name_of(kind: int) -> String:
	return {Sim.Kind.FIGHTER: "fighter", Sim.Kind.TOMCAT: "tomcat", Sim.Kind.FALCON: "falcon",
		Sim.Kind.PHANTOM: "phantom"}.get(kind, str(kind))


func _arm(view: VehicleView) -> void:
	if not bool(Sim.client.craft_systems(view.entity).get("master", false)):
		await _hold("master_arm", 2)
		for i in range(30):
			await get_tree().physics_frame


func _disarm(view: VehicleView) -> void:
	if bool(Sim.client.craft_systems(view.entity).get("master", false)):
		await _hold("master_arm", 2)
		for i in range(30):
			await get_tree().physics_frame


## THE STATION KEY, PRESSED UNTIL THE SELECTOR IS ON `wanted`: four presses is more than round the three.
func _select_station(view: VehicleView, wanted: int) -> void:
	for press in range(4):
		if int(Sim.client.craft_systems(view.entity).get("weapon", -1)) == wanted:
			return
		await _hold("weapon_station", 2)
		for i in range(30):
			await get_tree().physics_frame


func _server_id(view: VehicleView) -> int:
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", -1)) == Sim.local_client_id():
			return int((pilot as Dictionary).get("vehicle", 0))
	return 0


func _server_state(view: VehicleView) -> Dictionary:
	var id: int = _server_id(view)
	return Sim.server.vehicle_state(id) if id != 0 else {}


func _server_lock() -> Dictionary:
	for row in Sim.server.lock_states():
		if int((row as Dictionary).get("client", -1)) == Sim.local_client_id():
			return row
	return {}


func _server_missile(entity: int) -> Dictionary:
	for row in Sim.server.missile_states():
		if int((row as Dictionary).get("entity", 0)) == entity:
			return row
	return {}


## An unpiloted light twin on the server's own nose, `out` metres ahead and a little above, going the same way at the
## same speed, so it stays in the cone for as long as a lock takes. Returns the SERVER's entity.
func _put_a_target_on_the_nose(view: VehicleView, out: float) -> int:
	var mine: Dictionary = _server_state(view)
	var at: Vector3 = mine.get("position", view.global_position) as Vector3
	var facing := Basis(mine.get("basis", view.global_basis.get_rotation_quaternion()) as Quaternion)
	var nose: Vector3 = -facing.z
	var moving: Vector3 = mine.get("velocity", Vector3.ZERO) as Vector3
	var where: Vector3 = at + nose * out + facing.y * 20.0
	var target: int = int(Sim.server.spawn_vehicle(Sim.Kind.PLANE, where, atan2(-nose.x, -nose.z), moving))
	_clear_the_air_ahead(at, nose, target)
	return target


## CLEAR AIR AHEAD OF THE NOSE, so that the lock the test takes is the target it spawned and nobody else's. The island stands a
## hundred and forty AI machines that wander it, and the seeker takes the contact nearest its boresight, not the nearest one:
## on 2026-09-19 a fleet helicopter 2,149 m out and 0.007 rad off the nose beat this test's own jet at 769 m and 0.042 rad,
## the Sparrow flew to the helicopter and "closest 87.2 m against a 12 m fuse" measured a target it was never flying at. The
## helicopter had moved because the fleet's waypoints come from the terrain grid, which the mountains rework changed. Every
## machine but the jet and the target inside this cone is despawned; the cone is wider than any gimbal on the jets tested.
const CLEAR_CONE_RAD: float = 0.6
const CLEAR_RANGE_M: float = 6000.0

func _clear_the_air_ahead(at: Vector3, nose: Vector3, keep: int) -> void:
	for v in Sim.server.vehicle_states():
		var entity: int = int((v as Dictionary)["entity"])
		var to: Vector3 = ((v as Dictionary)["position"] as Vector3) - at
		if entity == keep or to.length() < 30.0 or to.length() > CLEAR_RANGE_M or nose.angle_to(to) > CLEAR_CONE_RAD:
			continue
		if Sim.server.despawn_vehicle(entity):
			print("[jet_arms] cleared %s %d, %.0f m out and %.3f rad off the nose" % [Sim.kind_name(int((v as Dictionary)["kind"])),
				entity, to.length(), nose.angle_to(to)])


func _despawn(target: int) -> void:
	if target != 0:
		Sim.server.despawn_vehicle(target)


## Up to `seconds` for this seat's lock to reach LOCKED, pressing LOCK when it is not on its way.
func _lock_within(view: VehicleView, seconds: float) -> bool:
	if int(_server_lock().get("phase", 0)) < LockSight.Phase.LOCKING:
		await _hold("lock", 3)
	for i in range(int(seconds * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
		if int(_server_lock().get("phase", 0)) == LockSight.Phase.LOCKED:
			return true
	return false


## A SEEKER WITH NOTHING DESIGNATED: a press breaks a lock that is on its way or held.
func _let_go_of_the_lock() -> void:
	var phase: int = int(_server_lock().get("phase", 0))
	if phase == LockSight.Phase.LOCKING or phase == LockSight.Phase.LOCKED:
		await _hold("lock", 3)
	for i in range(30):
		await get_tree().physics_frame


## Every missile this client launched, as of the last tick, on the server.
func _mine() -> Array:
	var out: Array = []
	for row in Sim.server.missile_states():
		if int((row as Dictionary).get("client", -1)) == Sim.local_client_id():
			out.append(row)
	return out


## ---- pictures ------------------------------------------------------------------------------

## THE REEL'S CAMERA, every drawn frame, on whatever it is chasing: `_chase_offset` and `_chase_look` in that node's
## frame, with the node's own up.
func _process(_delta: float) -> void:
	if not _reel or _camera == null or _chasing == null or not is_instance_valid(_chasing):
		return
	var frame: Transform3D = _chasing.global_transform
	_camera.global_position = frame * _chase_offset
	_camera.look_at(frame * _chase_look, frame.basis.y)
	_camera.make_current()


## FOLLOW `node` IN THE REEL from `offset`, looking at `look`, both in its frame.
func _chase(node: Node3D, offset: Vector3, look: Vector3) -> void:
	if _camera == null:
		_camera = Camera3D.new()
		_camera.far = 20000.0
		_camera.fov = 55.0
		get_tree().root.add_child(_camera)
	_chasing = node
	_chase_offset = offset
	_chase_look = look


## A PICTURE FROM `offset` IN THE JET'S DRAWN FRAME, looking at `look` in it, when a window and `--shot=` were given.
## In a reel it is where the chase camera goes instead, and nothing is saved.
func _picture(label: String, view: VehicleView, offset: Vector3, look: Vector3) -> void:
	if _shot_dir == "" or DisplayServer.get_name() == "headless" or view == null:
		return
	if _reel:
		_chase(view, offset, look)
		return
	await _take(label, view.global_transform * offset, view.global_transform * look, view.global_basis.y, view)


## THE PICTURE PASS, windowed, one jet: taken in the first seconds after it is boarded, while a jet nobody is flying is
## still flying level -- a hands-off Tomcat is nose down and rolling within twenty seconds, which is why these are not
## taken in the course of the checks. Its missiles on the rails; the gun firing, seen over the pilot's shoulder; a
## Sidewinder leaving its rail; and the Sidewinder on its way, with its target, from abeam of the pair. Every press is
## the pilot's own key; the target is a light twin put on the nose, as the checks put one.
func _pictures_of(rig: PilotRig, kind: int, name: String) -> void:
	rig.ask_for_kind(kind)
	var view: VehicleView = null
	for i in range(900):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and view.kind == kind and rig.seat_index() == 0:
			break
	if view == null or view.kind != kind:
		print("[jet_arms] no %s to picture" % name)
		return
	for i in range(20):
		await get_tree().physics_frame
	await _picture("%s-rails" % name, view, Vector3(-9.0, -1.8, 8.0), Vector3(0.0, 0.2, 0.0))
	await _arm(view)
	await _select_station(view, int(_station_named(kind, "guns").get("station", -1)))
	var code: Key = _key_of("fire")
	_key(code, true)
	for i in range(50):
		await get_tree().physics_frame
	await _picture("%s-gun" % name, view, Vector3(-4.5, 2.0, 12.0), Vector3(0.0, 0.0, -40.0))
	_key(code, false)
	_nearest_tracer(view)
	await _select_station(view, int(_station_named(kind, "heat").get("station", -1)))
	var target: int = _put_a_target_on_the_nose(view, 700.0)
	await _lock_within(view, 3.0)
	_key(_key_of("launch"), true)
	for i in range(14):
		await get_tree().physics_frame
	_key(_key_of("launch"), false)
	await _picture("%s-launch" % name, view, Vector3(-7.0, 1.5, 11.0), Vector3(0.0, -0.5, -20.0))
	# ON ITS WAY, while its motor still burns: from behind it and off to one side, looking past it at the target, so the
	# plume, the trail and the aeroplane it is after are in one frame. Taken 0.8 s after launch; by the time it is close
	# to the target the motor has burnt out and a Sidewinder at 150 m is two pixels.
	var flown: float = 0.0
	for i in range(600):
		await get_tree().physics_frame
		flown += Sim.tick_dt()
		if flown < 0.8:
			continue
		var drawn: int = _my_youngest_missile()
		var at: Vector3 = _level.missiles.drawn_at(drawn) if drawn != 0 else Vector3.INF
		var theirs: Dictionary = Sim.server.vehicle_state(target)
		if not at.is_finite() or theirs.is_empty():
			continue
		var there: Vector3 = theirs["position"] as Vector3
		var along: Vector3 = (there - at).normalized()
		var side: Vector3 = along.cross(Vector3.UP).normalized()
		print("[jet_arms] missile picture: %.0f m from its target" % at.distance_to(there))
		if _reel:
			# THE REEL RIDES THE MISSILE: a node the yard's drawn position is copied onto every frame, facing its way.
			var rider := Node3D.new()
			get_tree().root.add_child(rider)
			_chase(rider, Vector3(6.0, 2.5, 22.0), Vector3(0.0, 0.0, -60.0))
			for f in range(150):
				var now: Vector3 = _level.missiles.drawn_at(drawn)
				if not now.is_finite():
					break
				var ahead: Vector3 = (there - now).normalized()
				rider.global_transform = Transform3D(Basis.looking_at(ahead, Vector3.UP), now)
				await get_tree().process_frame
			_chase(view, Vector3(-6.0, 2.5, 18.0), Vector3(0.0, 0.0, -40.0))
			rider.queue_free()
			break
		await _take("%s-missile" % name, at - along * 22.0 + side * 7.0 + Vector3.UP * 3.0, there, Vector3.UP, view)
		break
	for i in range(240):
		await get_tree().physics_frame
	_despawn(target)


## HOW FAR AHEAD OF THE DRAWN GUN PORT THE NEAREST DRAWN TRACER IS, printed: the pilot's own rounds are drawn from their
## birth records, wound forward by the lag (`ShotYard`), so the stream starts some way off the nose. For the notes.
func _nearest_tracer(view: VehicleView) -> void:
	var port: Vector3 = view.global_transform * _drawn_gun_port(view)
	var nearest: float = INF
	for node in _level.shots.get_children():
		if node is MeshInstance3D and (node as MeshInstance3D).visible:
			nearest = minf(nearest, (node as Node3D).global_position.distance_to(port))
	print("[jet_arms] %s nearest drawn tracer %.0f m from the drawn gun port, late %.3f s" % [_name_of(view.kind),
		nearest, Sim.drawing_late()])


func _my_youngest_missile() -> int:
	var drawn: int = 0
	var youngest: float = INF
	for row in Sim.missiles:
		var one: Dictionary = row
		if int(one.get("client", -1)) == Sim.local_client_id() and bool(one.get("flying", false)) 				and float(one.get("age", INF)) < youngest:
			youngest = float(one.get("age", INF))
			drawn = int(one.get("entity", 0))
	return drawn


## THE PILOT'S SIGHT IS HIDDEN FOR THE PICTURE: its glass hangs in front of the pilot's eye and, from outside, its ring
## is a hoop floating beside the aeroplane.
func _take(label: String, from: Vector3, to: Vector3, up: Vector3, view: VehicleView) -> void:
	var hidden: Array = []
	for sight in view.find_children("*", "LockSight", true, false):
		if (sight as Node3D).visible:
			(sight as Node3D).visible = false
			hidden.append(sight)
	if _camera == null:
		_camera = Camera3D.new()
		_camera.far = 20000.0
		_camera.fov = 55.0
		get_tree().root.add_child(_camera)
	_camera.global_position = from
	_camera.look_at(to, up)
	_camera.make_current()
	await get_tree().process_frame
	_camera.global_position = from
	_camera.look_at(to, up)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var picture: String = _shot_dir.path_join("%s.png" % label)
	get_viewport().get_texture().get_image().save_png(picture)
	print("[jet_arms] picture %s" % picture)
	_camera.clear_current(true)
	for sight in hidden:
		(sight as Node3D).visible = true


## ---- the keyboard ------------------------------------------------------------------------

func _key_of(action: String) -> Key:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	_check("the_%s_action_is_bound_to_a_key" % action, false, "nothing bound")
	return KEY_NONE


func _key(code: Key, down: bool) -> void:
	if code == KEY_NONE:
		return
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = down
	Input.parse_input_event(press)


func _hold(action: String, frames: int) -> void:
	var code: Key = _key_of(action)
	_key(code, true)
	for i in range(frames):
		await get_tree().physics_frame
	_key(code, false)
	await get_tree().physics_frame


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL " + ", ".join(_failures))
	get_tree().quit()
