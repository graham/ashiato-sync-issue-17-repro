extends Node
## Headless: A GUNNER ON THE CB90 SHOOTS A CRAFT DOWN -- every round that hits takes the table's damage on the host,
## the craft smokes thin and then thick on this machine's drawing, and at nothing it is destroyed, frozen, drawn as a
## wreck with a fireball, written in the host's log and never boarded again (lane/combat, 2026-09-18).
##
##   Godot --headless --path cockpit res://tests/hulls.tscn
##
## THE REAL PATH. The player asks for a CB90 the way the clipboard does, is seated at the port after gun by the server,
## closes the right hand on the gun's grip and pulls the controller's trigger through `force_input`. Nothing here calls
## `fire_gun` or `apply_damage`. The target is a pod -- it hovers where it is put, 50 points, three 12.7 mm hits -- put
## on the line the gun's first round flew, so the gun is not aimed by the test at all: the hand holds it where it rests.
##
## WHAT IS COMPARED: the host's hit points after every tick against the rounds the HOST says struck the pod, times the
## round's damage asked of the library (`round_damage`), never a number typed here. The stages are the client world's
## (`Sim.hulls`), which is what the drawing reads, and the smoke is the level's own `DamageYard`.
##
## Read RESULT=, not the exit code.

const RIGHT: int = 1
## How far down the gun's line the target is put, metres: close, so the swell rolling the boat under the gun cannot
## swing the stream off a 1.7 m pod.
const RANGE: float = 35.0
## The longest the gunner holds on, seconds, before the suite gives up on the pod.
const LONGEST_S: float = 8.0

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _craft: int = 0
var _lost: Array[Dictionary] = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[hulls] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld") or not ClassDB.class_has_method("CockpitWorld", "hull_states"):
		_check("the_library_has_hit_points", false, "no hull_states")
		_finish()
		return
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	for i in range(240):
		await get_tree().physics_frame
	Sim.craft_lost.connect(func(kill: Dictionary) -> void: _lost.append(kill))
	await _a_gunner_shoots_a_craft_down(_level.rig)
	_finish()


func _a_gunner_shoots_a_craft_down(rig: PilotRig) -> void:
	var control: VehicleControl = await _sit_at(rig, Sim.Kind.CB90, 2, "stick")
	_check("the_player_is_at_the_cb90s_port_after_gun", control != null, "%s" % [control])
	if control == null:
		return
	rig.force_grip(RIGHT, 1.0)
	await _hand_on(rig, control, 8)
	# ONE ROUND, to find the gun's line: where the server's round left and which way.
	var line: Dictionary = await _one_round(rig, control)
	_check("the_gun_fires_a_round_to_sight_by", not line.is_empty(), "%s" % [line])
	if line.is_empty():
		return
	var along: Vector3 = (line["velocity"] as Vector3).normalized()
	var at: Vector3 = (line["from"] as Vector3) + along * RANGE
	var target: int = int(Sim.server.spawn_vehicle(Sim.Kind.POD, at, 0.0, Vector3.ZERO))
	var whole: float = float(Sim.server.kind_hull(Sim.Kind.POD))
	var damage: float = float(ClassDB.class_call_static(&"CockpitWorld", &"round_damage", Sim.gun_of(Sim.Kind.CB90, 0)
		.get("ammo", 9)))
	_check("a_pod_has_hit_points_and_a_12_7mm_round_takes_some", whole > 0.0 and damage > 0.0,
		"pod %.0f points, 12.7 mm %.0f" % [whole, damage])
	for i in range(30):
		await _hand_on(rig, control, 1)

	# HOLD ON, and after every tick compare the host's points with the hits the host counted.
	var hits: Dictionary = {}
	var mismatch: String = ""
	var stage_seen: Dictionary = {}
	var smoke_seen: Dictionary = {}
	var fireballs_before: int = _level.damage.fireballs
	var ticks: int = int(LONGEST_S / Sim.tick_dt())
	rig.force_input(RIGHT, Bind.TRIGGER, 1.0)
	var destroyed_at: Vector3 = Vector3.INF
	for i in range(ticks):
		await _hand_on(rig, control, 1)
		for row in Sim.server.shot_states():
			var shot: Dictionary = row
			if int(shot.get("surface", 0)) == 3 and int(shot.get("shooter", -1)) == Sim.local_client_id() \
					and ((shot["impact"] as Vector3) - at).length() < 6.0:
				hits[int(shot["entity"])] = true
		var hull: Dictionary = Sim.server.hull_state(target)
		var wanted: float = maxf(0.0, whole - damage * float(hits.size()))
		if mismatch.is_empty() and absf(float(hull.get("points", -1.0)) - wanted) > 0.01:
			mismatch = "after %d hits: %.2f points, wanted %.2f" % [hits.size(), float(hull.get("points", -1.0)), wanted]
		var mine: int = _drawn_entity(at)
		var stage: int = int(Sim.hull_of(mine).get("stage", 0))
		stage_seen[stage] = true
		if mine != 0:
			smoke_seen[_level.damage.smoking(mine)] = true
		if bool(hull.get("destroyed", false)):
			destroyed_at = Sim.server.vehicle_state(target).get("position", Vector3.ZERO)
			break
	rig.force_input(RIGHT, Bind.TRIGGER, 0.0)
	_check("every_round_that_hits_takes_the_tables_damage_on_the_host", mismatch.is_empty() and hits.size() > 0,
		"%d hits of %.0f on %.0f points%s" % [hits.size(), damage, whole, "" if mismatch.is_empty() else "; " + mismatch])
	_check("it_smokes_thin_then_thick_on_this_machines_drawing", smoke_seen.has(1) and smoke_seen.has(2),
		"stages seen %s, smoke laid at %s" % [stage_seen.keys(), smoke_seen.keys()])
	var hull: Dictionary = Sim.server.hull_state(target)
	_check("and_at_nothing_left_it_is_destroyed", bool(hull.get("destroyed", false)),
		"%s" % [hull])
	if not bool(hull.get("destroyed", false)):
		return
	for i in range(int(1.0 / Sim.tick_dt())):
		await get_tree().physics_frame
	var still: Vector3 = Sim.server.vehicle_state(target).get("position", Vector3.ZERO)
	_check("and_the_wreck_stays_where_it_died", (still - destroyed_at).length() < 0.01,
		"moved %.3f m in a second" % (still - destroyed_at).length())
	var mine: int = _drawn_entity(at)
	_check("and_this_machine_draws_a_fireball_and_a_wreck", _level.damage.fireballs > fireballs_before
		and mine != 0 and _level.damage.is_wrecked(mine),
		"fireballs %d -> %d, wrecked %s" % [fireballs_before, _level.damage.fireballs, _level.damage.is_wrecked(mine)])
	var mine_lost: Array = _lost.filter(func(k: Dictionary) -> bool: return int(k.get("victim", 0)) == target)
	var kill: Dictionary = mine_lost.back() if not mine_lost.is_empty() else {}
	_check("and_the_host_logs_who_did_it", int(kill.get("victim", 0)) == target and String(kill.get("cause_name", ""))
		== "gun" and int(kill.get("by", -1)) == Sim.local_client_id() and String(kill.get("by_kind_name", "")) == "cb90",
		"%s" % [kill.get("words", kill)])
	_check("and_nobody_boards_a_wreck", not bool(Sim.server.seat_client(Sim.local_client_id(), target, 0)), "")
	Sim.server.apply_damage(target, 10.0)
	await get_tree().physics_frame
	var twice: int = _lost.filter(func(k: Dictionary) -> bool: return int(k.get("victim", 0)) == target).size()
	_check("and_a_wreck_is_not_killed_twice", twice == 1, "%d losses of the pod" % twice)


## THE ROUND THE GUN FIRES FOR ONE PULLED FRAME, as the server made it: {from, velocity}, or {}.
func _one_round(rig: PilotRig, control: VehicleControl) -> Dictionary:
	var before: Dictionary = {}
	for row in Sim.server.shot_states():
		before[int((row as Dictionary)["entity"])] = true
	rig.force_input(RIGHT, Bind.TRIGGER, 1.0)
	await _hand_on(rig, control, 1)
	rig.force_input(RIGHT, Bind.TRIGGER, 0.0)
	for i in range(30):
		await _hand_on(rig, control, 1)
		for row in Sim.server.shot_states():
			var shot: Dictionary = row
			if not before.has(int(shot["entity"])) and int(shot.get("shooter", -1)) == Sim.local_client_id():
				return {"from": shot["from"], "velocity": shot["velocity"]}
	return {}


## This machine's entity for the craft the host put at `at`: the nearest pod it draws.
func _drawn_entity(at: Vector3) -> int:
	var best: int = 0
	var nearest: float = 30.0
	for entity in Sim.current:
		var state: Dictionary = Sim.current[entity]
		if int(state.get("kind", -1)) != Sim.Kind.POD:
			continue
		var far: float = ((state["position"] as Vector3) - at).length()
		if far < nearest:
			nearest = far
			best = int(entity)
	return best


## THIS PLAYER, AT `seat` OF A CRAFT OF `kind`, as `tests/gunners.gd` seats one.
func _sit_at(rig: PilotRig, kind: int, seat: int, role: String) -> VehicleControl:
	var view: VehicleView = rig.vehicle_view()
	if view == null or view.kind != kind:
		rig.ask_for_kind(kind)
		for i in range(900):
			await get_tree().physics_frame
			view = rig.vehicle_view()
			if view != null and view.kind == kind:
				break
	if view == null or view.kind != kind:
		return null
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", -1)) == Sim.local_client_id():
			_craft = int((pilot as Dictionary).get("vehicle", 0))
	if not (rig.seat_index() == seat or bool(Sim.server.seat_client(Sim.local_client_id(), _craft, seat))):
		return null
	for i in range(300):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and rig.seat_index() == seat and view.station_for(seat) != null:
			var control := view.station_for(seat).controls().get(role) as VehicleControl
			if control != null and control is PintleGun:
				return control
	return null


func _hand_on(rig: PilotRig, control: VehicleControl, frames: int) -> void:
	for i in range(frames):
		rig.force_hand(RIGHT, Transform3D(Basis.IDENTITY, control.grip_global()))
		await get_tree().physics_frame


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
