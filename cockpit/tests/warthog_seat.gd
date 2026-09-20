extends Node
## Headless: THE A-10C'S GAU-8 WORKS -- fired by the pilot through the level, the rig and the desk's own keys, against the
## real simulation, and held to the barrel the model draws on the centreline. Read RESULT=, not the exit code.
##
##   Godot --headless --fixed-fps 120 --path cockpit res://tests/warthog_seat.tscn
##
## THE USER'S WORDS: "make sure the gun in the front works and that landing gear works (and control surfaces work with
## VAT)". So, from the pilot's seat of an A-10C in the level:
## - THE SURFACES ON THE KEYS: the stick's roll and pitch and the pedals, each held on its own desk key, move only their
##   own drawn surfaces the right way (read off the drawn vertices of the airframe the VIEW draws); the flaps lever's and
##   the speed brake handle's channels move the flaps and split the decelerons; and the gear key runs the gear through
##   its cycle, the nose doors moving before any leg, and the legs down at the end;
## - the seat is fitted for the gun: a lock sight, a master arm switch, and a stick whose trigger fires a gun;
## - SAFE, the trigger fires no round;
## - ARMED, two seconds of the trigger (the SPACE key, both codes set) are the GAU-8's fixed 3,900 rounds a minute, every
##   round born at the drawn muzzle and leaving along the drawn bore at 1,013 m/s over the aeroplane's own velocity;
## - AND THE BARRELS TURN while it fires, and run down after: the drawn cluster's barrels are read off their vertices;
## - the drum counts down on this machine, runs dry at exactly what was left, fires nothing dry, and is full again after
##   its rearm.
## AND ONE CHECK TO THE CENTIMETRE, where nothing is moving: an A-10C parked on the ground in a world of its own, armed and
## fired through its pilot's control frame (`set_pilot_input`, the frame the wire carries from a seated rig), every round
## born within `PARKED_MUZZLE` of `WarthogAirframe.gun_port()` in the craft's frame. In flight a round is born on the tick
## before the one read, a metre and more away, so the flying check can only be as good as `MUZZLE_ACROSS`.
##
## THE MUZZLE IS THE MODEL'S, NOT THE LOADOUT'S (lane/jetarms: held to the loadout, a gun moved in C++ agrees with itself).
## Nothing here calls `fire_gun`: every round is counted from the simulation's own shot records with this client's name.

## THE GAU-8's RATE, typed here on purpose as the thing the loadout is checked AGAINST: "a fixed rate of 3,900 rpm"
## (Wikipedia, "GAU-8 Avenger", from TO 1A-10A-1).
const GAU8_PER_SECOND: float = 3900.0 / 60.0
## Its armour-piercing round's muzzle velocity, m/s (the same article).
const GAU8_MUZZLE: float = 1013.0
## ITS DRUM, 1,174 rounds (the same article).
const GAU8_DRUM: int = 1174
## Bore-sighted 2 degrees below the line of flight (the same article).
const GAU8_DEPRESSION: float = deg_to_rad(2.0)
## In flight: how far a round may be born from the drawn muzzle across and up, and along, in the aeroplane's frame (the
## pose it was born from may be the tick before the one read -- see lane/jetarms).
const MUZZLE_ACROSS: float = 0.25
const MUZZLE_ALONG: float = 2.0
## PARKED: to the centimetre. The wire rounds a birth position to 0.01 m an axis, half of that each way.
const PARKED_MUZZLE: float = 0.01
const TICK: float = 1.0 / 120.0
const CLIENT: int = 61

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _sections: int = 0
## In, the surfaces, the gear, the gun, the barrels, the drum, parked.
const SECTIONS: int = 7


func _check(label: String, ok: bool, detail: String) -> void:
	print("[warthog_seat] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	# THE CENTIMETRE FIRST, in a world of its own, before the level's world starts.
	_parked_every_round_is_born_at_the_drawn_muzzle()
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(240):
		await get_tree().physics_frame
	var rig: PilotRig = _level.rig
	if await _the_pilot_gets_in(rig):
		await _the_surfaces_follow_the_keys(rig)
		await _the_gear_key_runs_the_gear(rig)
		await _the_gun(rig)
		await _the_barrels_turn_while_it_fires(rig)
		await _the_drum(rig)
	_check("every_section_of_the_suite_ran", _sections == SECTIONS, "%d of %d" % [_sections, SECTIONS])
	_finish()


## ---- parked, to the centimetre ------------------------------------------------------------------------------------

## AN A-10C ON THE GROUND, ARMED AND FIRED FOR A SECOND through its pilot's frame, in a CockpitWorld of its own. Every
## round's birth, turned into the craft's frame at the tick it was born, within a centimetre of the muzzle the model
## draws on the centreline; every one leaving along the drawn bore, 2 degrees below the nose.
func _parked_every_round_is_born_at_the_drawn_muzzle() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(40000.0, 400.0, 40000.0))
	var hy: float = float((Sim.geometry_of(Sim.Kind.WARTHOG).get("extents", Vector3.ONE) as Vector3).y)
	var made: Dictionary = world.spawn_pilot(CLIENT, Sim.Kind.WARTHOG, Vector3(0.0, hy + 0.05, 0.0), 0.0, Vector3.ZERO)
	var craft: int = int(made.get("vehicle", 0))
	var pilot: int = int(made.get("pilot", 0))
	var input: Dictionary = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 1.0, "trigger": 0.0}
	for i in range(240):
		world.set_pilot_input(pilot, input)
		world.tick(TICK)
	# MASTER ARM, as the switch sends it: a bus command.
	input["command_channel"] = Sim.Channel.MASTER
	input["command_value"] = 1
	input["command_seq"] = 1
	for i in range(30):
		world.set_pilot_input(pilot, input)
		world.tick(TICK)
	# The model, dressed from the kind's own geometry, is the reference: its `gun_port()` and its bore.
	var frame := WarthogAirframe.new()
	add_child(frame)
	frame.dress()
	var port: Vector3 = frame.gun_port()
	var bore: Vector3 = WarthogAirframe.gun_axis()
	frame.queue_free()
	# THE BORE IS MEASURED DEAD TRUE, AND SCATTER IS NOT BROKEN HERE: the gun's own scatter (2 mrad, held by
	# `tests/gun_scatter.gd`) is wider than this check's milliradian, and it is the bore and the muzzle being asked about.
	world.set_gun_scatter_scale(0.0)
	var seen: Dictionary = {}
	for row in world.shot_states():
		seen[int((row as Dictionary).get("entity", 0))] = true
	var born: int = 0
	var names: Dictionary = {}
	var worst: float = 0.0
	var worst_bore: float = 0.0
	var slowest: float = INF
	var fastest: float = 0.0
	input["trigger"] = 1.0
	for i in range(120):
		world.set_pilot_input(pilot, input)
		world.tick(TICK)
		var state: Dictionary = world.vehicle_state(craft)
		var basis := Basis(state["basis"] as Quaternion)
		var at: Vector3 = state["position"]
		var moving: Vector3 = state.get("velocity", Vector3.ZERO)
		for row in world.shot_states():
			var shot: Dictionary = row
			var entity: int = int(shot.get("entity", 0))
			if seen.has(entity):
				continue
			seen[entity] = true
			born += 1
			names[String(shot.get("ammo_name", ""))] = true
			var local: Vector3 = basis.inverse() * ((shot["from"] as Vector3) - at)
			worst = maxf(worst, local.distance_to(port))
			var own: Vector3 = basis.inverse() * ((shot["velocity"] as Vector3) - moving)
			worst_bore = maxf(worst_bore, own.angle_to(bore))
			slowest = minf(slowest, own.length())
			fastest = maxf(fastest, own.length())
	world.teardown()
	_check("parked_every_round_is_born_at_the_drawn_muzzle_to_the_centimetre", born > 0 and worst <= PARKED_MUZZLE,
		"%d rounds in a second, the worst born %.4f m from the drawn muzzle %s (within %.2f)" % [born, worst, port,
			PARKED_MUZZLE])
	_check("parked_its_rounds_are_the_30_mm_row", names.keys() == ["30mm"], "rounds named %s" % [names.keys()])
	_check("parked_and_leaves_along_the_drawn_bore_2_degrees_down_at_1013", born > 0 and worst_bore <= 0.001
		and absf(slowest - GAU8_MUZZLE) <= 1.0 and absf(fastest - GAU8_MUZZLE) <= 1.0,
		"worst %.5f rad off the drawn bore (%.2f deg below the nose); %.1f to %.1f m/s" % [worst_bore,
			rad_to_deg(GAU8_DEPRESSION), slowest, fastest])
	_sections += 1


## ---- in the level ----------------------------------------------------------------------------------------------------

## INTO THE A-10C'S SEAT, as the clipboard asks for one, and the seat fitted for the gun.
func _the_pilot_gets_in(rig: PilotRig) -> bool:
	rig.ask_for_kind(Sim.Kind.WARTHOG)
	var view: VehicleView = null
	for i in range(900):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and view.kind == Sim.Kind.WARTHOG and rig.seat_index() == 0:
			break
	var ok: bool = view != null and view.kind == Sim.Kind.WARTHOG and rig.seat_index() == 0
	_check("the_player_gets_into_the_a10s_seat", ok, "kind %s, seat %d" % [view.kind if view != null else "-",
		rig.seat_index()])
	if not ok:
		return false
	for i in range(30):
		await get_tree().physics_frame
	var guns: Dictionary = _guns()
	_check("it_carries_the_gau8_and_its_drum", not guns.is_empty() and int(guns.get("rounds", 0)) == GAU8_DRUM
		and (Sim.missile_schema(Sim.Kind.WARTHOG).get("stations", []) as Array).size() == 1,
		"stations %s" % Sim.missile_schema(Sim.Kind.WARTHOG).get("stations", []))
	var station: CockpitStation = view.station_for(0)
	var stick := station.controls().get("stick") as FlightStick if station != null else null
	_check("its_pilot_has_a_sight_a_master_arm_and_a_stick_that_fires_the_gun",
		station != null and station.find_child("LockSight", true, false) is LockSight
		and station.get_node_or_null("MasterArm") is ToggleSwitch and stick != null and stick.fires_a_gun,
		"station %s, stick %s" % [station, stick])
	_sections += 1
	return true


func _the_gun(rig: PilotRig) -> void:
	var view: VehicleView = rig.vehicle_view()
	await _disarm(view)
	var safe: Dictionary = await _burst(view, 60)
	_check("safe_the_trigger_fires_nothing", int(safe["born"]) == 0, "%d round(s)" % int(safe["born"]))
	await _arm(view)
	var burst: Dictionary = await _burst(view, 240)
	var born: int = int(burst["born"])
	# TWO SECONDS AT 120 Hz: 130 rounds, one a 1.85 ticks. Two either way is where in the two seconds the tick edges fall;
	# the original gun's 4,200 a minute would be 140, its 2,100 70, and a reload rounded up to two ticks 120.
	_check("two_seconds_of_the_trigger_are_3900_a_minute", absf(float(born) - GAU8_PER_SECOND * 2.0) <= 2.0,
		"%d rounds in 240 ticks, wanted %.0f" % [born, GAU8_PER_SECOND * 2.0])
	_check("every_round_is_born_at_the_muzzle_the_model_draws", born > 0
		and float(burst["worst_across"]) <= MUZZLE_ACROSS and float(burst["worst_along"]) <= MUZZLE_ALONG,
		"worst %.3f m across, %.2f m along, from the drawn muzzle %s; the first at %s in the aeroplane's frame" % [
			float(burst["worst_across"]), float(burst["worst_along"]), _drawn_port(view), burst["first_local"]])
	_check("and_leaves_along_the_drawn_bore_at_1013", born > 0 and float(burst["worst_bore"]) <= 0.01
		and absf(float(burst["slowest"]) - GAU8_MUZZLE) <= 2.0 and absf(float(burst["fastest"]) - GAU8_MUZZLE) <= 2.0,
		"worst %.4f rad off the drawn bore, %.1f to %.1f m/s over the aeroplane's own" % [float(burst["worst_bore"]),
			float(burst["slowest"]), float(burst["fastest"])])
	_sections += 1


## THE BARRELS TURN WHILE IT FIRES: over a second of trigger the drawn cluster comes up to speed and its barrels move
## round, read off the GunBarrels mesh's vertices; a second after the trigger is let go they have stopped. This machine
## is the pilot's, and it knows the gun is firing the way a watcher's does: by the drum it is handed going down.
func _the_barrels_turn_while_it_fires(rig: PilotRig) -> void:
	var view: VehicleView = rig.vehicle_view()
	var frame: WarthogAirframe = view._warthog
	if frame == null:
		_check("the_view_draws_the_a10", false, "no WarthogAirframe on the view")
		return
	var barrels := frame.find_child("GunBarrels", true, false) as MeshInstance3D
	# A SECOND AND A HALF FIRST, for the last burst's run-down: the first run of this check read the barrels still turning
	# 0.07 m in 30 frames before the trigger, the tail of the burst before it.
	for i in range(int(1.5 * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
	var still_before: PackedVector3Array = _points(frame, barrels)
	for i in range(30):
		await get_tree().process_frame
	var idle: float = _moved(still_before, _points(frame, barrels))
	var code: Key = _key_of("fire")
	_key(code, true)
	var spin_most: float = 0.0
	var turned: float = 0.0
	var last: PackedVector3Array = _points(frame, barrels)
	# A SECOND OF TRIGGER: the drawn drive takes `WarthogAirframe.GUN_SPIN_UP` (half a second) to come up to speed.
	for i in range(120):
		await get_tree().physics_frame
		await get_tree().process_frame
		spin_most = maxf(spin_most, view.warthog_gun_spin())
		var now: PackedVector3Array = _points(frame, barrels)
		turned += _moved(last, now)
		last = now
	_key(code, false)
	for i in range(int(1.5 * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
	await get_tree().process_frame
	var after: PackedVector3Array = _points(frame, barrels)
	await get_tree().process_frame
	await get_tree().process_frame
	var stopped: float = _moved(after, _points(frame, barrels))
	_check("the_barrels_turn_while_it_fires_and_stop_after", idle < 0.0005 and spin_most > 0.9 and turned > 0.05
		and stopped < 0.0005 and view.warthog_gun_spin() < 0.01,
		"before: barrels moved %.4f m in 30 frames; firing: up to %.2f of full speed, the muzzles travelled %.3f m; after: %.4f m, spin %.2f"
			% [idle, spin_most, turned, stopped, view.warthog_gun_spin()])
	_sections += 1


## THE COUNT GOES DOWN ON THIS MACHINE, RUNS OUT AT WHAT WAS LEFT, AND COMES BACK.
func _the_drum(rig: PilotRig) -> void:
	var view: VehicleView = rig.vehicle_view()
	var server_id: int = _server_id()
	var left: int = int(Sim.server.gun_rounds(server_id))
	for i in range(30):
		await get_tree().physics_frame
	var here: int = int(Sim.client.gun_rounds(view.entity))
	_check("the_count_went_down_by_what_was_fired_and_this_machine_reads_it",
		left > 0 and left < GAU8_DRUM and absi(here - left) <= ceili(float(GAU8_DRUM) / 255.0) + 1,
		"server %d, this machine %d, of %d" % [left, here, GAU8_DRUM])
	var fired: int = 0
	var seen: Dictionary = {}
	for row in Sim.server.shot_states():
		seen[int((row as Dictionary).get("entity", 0))] = true
	var code: Key = _key_of("fire")
	_key(code, true)
	for i in range(int(25.0 * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
		fired += _new_rounds(seen)
		if int(Sim.server.gun_rounds(server_id)) == 0:
			break
	_key(code, false)
	for i in range(3):
		await get_tree().physics_frame
		fired += _new_rounds(seen)
	_check("it_runs_dry_after_exactly_what_was_left", int(Sim.server.gun_rounds(server_id)) == 0 and fired == left,
		"fired %d of %d left" % [fired, left])
	var dry: Dictionary = await _burst(view, 60)
	for i in range(10):
		await get_tree().physics_frame
	_check("dry_the_trigger_fires_nothing_and_this_machine_reads_empty", int(dry["born"]) == 0
		and int(Sim.client.gun_rounds(view.entity)) == 0, "%d round(s), this machine reads %d" % [int(dry["born"]),
			int(Sim.client.gun_rounds(view.entity))])
	var rearm: float = float(_guns().get("rearm_s", 0.0))
	for i in range(int((rearm + 0.5) * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
	_check("and_it_is_full_again_after_its_rearm", int(Sim.server.gun_rounds(server_id)) == GAU8_DRUM
		and int(Sim.client.gun_rounds(view.entity)) == GAU8_DRUM, "server %d, this machine %d, after %.1f s" % [
			int(Sim.server.gun_rounds(server_id)), int(Sim.client.gun_rounds(view.entity)), rearm + 0.5])
	_sections += 1


## HOLD THE FIRE KEY FOR `frames` physics frames and watch every round the SERVER makes with this client's name on it,
## against the server's own pose of the aeroplane: where it was born in the aeroplane's frame, off the DRAWN bore, how
## fast over the aeroplane's own velocity.
func _burst(view: VehicleView, frames: int) -> Dictionary:
	var out: Dictionary = {"born": 0, "worst_across": 0.0, "worst_along": 0.0, "worst_bore": 0.0, "slowest": INF,
		"fastest": 0.0, "first_local": Vector3.INF}
	var seen: Dictionary = {}
	for row in Sim.server.shot_states():
		seen[int((row as Dictionary).get("entity", 0))] = true
	var muzzle: Vector3 = _drawn_port(view)
	var bore: Vector3 = WarthogAirframe.gun_axis()
	var code: Key = _key_of("fire")
	_key(code, true)
	for i in range(frames + 30):
		if i == frames:
			_key(code, false)
		await get_tree().physics_frame
		var state: Dictionary = Sim.server.vehicle_state(_server_id())
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
			var from: Vector3 = shot["from"]
			var here: Vector3 = basis.inverse() * (from - position) - muzzle
			var then: Vector3 = basis.inverse() * (from - (position - velocity * Sim.tick_dt())) - muzzle
			var local: Vector3 = here if here.length() < then.length() else then
			if not (out["first_local"] as Vector3).is_finite():
				out["first_local"] = local + muzzle
			out["worst_across"] = maxf(float(out["worst_across"]), Vector2(local.x, local.y).length())
			out["worst_along"] = maxf(float(out["worst_along"]), absf(local.z))
			var own: Vector3 = (shot["velocity"] as Vector3) - velocity
			out["worst_bore"] = maxf(float(out["worst_bore"]), own.angle_to(basis * bore))
			out["slowest"] = minf(float(out["slowest"]), own.length())
			out["fastest"] = maxf(float(out["fastest"]), own.length())
	return out


## ---- the surfaces and the gear --------------------------------------------------------------------------------------

## EACH KEY MOVES ITS OWN SURFACES, AND ONLY THEM, THE RIGHT WAY, on the airframe the view draws: right roll (the right
## arrow) raises the right aileron's trailing edge and lowers the left's; nose up (S) raises both elevators'; right pedal
## (E) swings both rudders' to starboard. The flaps and the speed brake are their channels, as their handles send them
## (`VehicleControl` sends a command on its channel; the flaps lever is on the console the view fits, the speed brake
## handle beside the throttle): flaps down lowers all four flaps, the speed brake splits each aileron.
func _the_surfaces_follow_the_keys(rig: PilotRig) -> void:
	var view: VehicleView = rig.vehicle_view()
	var frame: WarthogAirframe = view._warthog
	var parts: Array = ["DeceleronUpperStarboard", "DeceleronUpperPort", "DeceleronLowerStarboard", "ElevatorStarboard",
		"ElevatorPort", "RudderStarboard", "RudderPort", "FlapInnerStarboard", "FlapOuterPort"]
	for i in range(60):
		await get_tree().physics_frame
	var rest: Dictionary = _trailing_edges(frame, parts)
	var moved: Dictionary = {}
	for action in ["roll_right", "pitch_up", "yaw_right"]:
		var code: Key = _key_of(action)
		_key(code, true)
		for i in range(45):
			await get_tree().physics_frame
		await get_tree().process_frame
		moved[action] = _deltas(_trailing_edges(frame, parts), rest)
		_key(code, false)
		for i in range(90):
			await get_tree().physics_frame
		await get_tree().process_frame
	var back: Dictionary = _deltas(_trailing_edges(frame, parts), rest)
	Sim.send_command(Sim.Channel.FLAPS, view.channel_range(Sim.Channel.FLAPS))
	Sim.send_command(Sim.Channel.SPOILERS, 1)
	for i in range(int(2.5 * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
	await get_tree().process_frame
	var lowered: Dictionary = _deltas(_trailing_edges(frame, parts), rest)
	Sim.send_command(Sim.Channel.FLAPS, 0)
	Sim.send_command(Sim.Channel.SPOILERS, 0)
	for i in range(int(2.0 * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
	var roll: Dictionary = moved["roll_right"]
	var pitch: Dictionary = moved["pitch_up"]
	var yaw: Dictionary = moved["yaw_right"]
	var y := func(d: Dictionary, part: String) -> float: return (d[part] as Vector3).y
	var ok: bool = y.call(roll, "DeceleronUpperStarboard") > 0.1 and y.call(roll, "DeceleronUpperPort") < -0.1 \
		and absf(y.call(roll, "ElevatorStarboard")) < 0.02 \
		and y.call(pitch, "ElevatorStarboard") > 0.1 and y.call(pitch, "ElevatorPort") > 0.1 \
		and absf(y.call(pitch, "DeceleronUpperStarboard")) < 0.02 \
		and (yaw["RudderStarboard"] as Vector3).x > 0.08 and (yaw["RudderPort"] as Vector3).x > 0.08 \
		and absf(y.call(yaw, "ElevatorStarboard")) < 0.02
	var levers: bool = y.call(lowered, "FlapInnerStarboard") < -0.1 and y.call(lowered, "FlapOuterPort") < -0.1 \
		and y.call(lowered, "DeceleronUpperStarboard") > 0.2 and y.call(lowered, "DeceleronLowerStarboard") < -0.2
	var centred := true
	for part in parts:
		centred = centred and (back[part] as Vector3).length() < 0.02
	_check("the_stick_and_pedal_keys_move_their_own_surfaces", ok and centred,
		"right roll: ailerons %+.2f / %+.2f, elevator %+.3f; nose up: elevators %+.2f / %+.2f, aileron %+.3f; right pedal: rudders %+.2f / %+.2f; let go, all back %s"
			% [y.call(roll, "DeceleronUpperStarboard"), y.call(roll, "DeceleronUpperPort"), y.call(roll, "ElevatorStarboard"),
				y.call(pitch, "ElevatorStarboard"), y.call(pitch, "ElevatorPort"), y.call(pitch, "DeceleronUpperStarboard"),
				(yaw["RudderStarboard"] as Vector3).x, (yaw["RudderPort"] as Vector3).x, centred])
	_check("the_flaps_and_the_speed_brake_move_theirs", levers,
		"flaps down: inner %+.2f, outer %+.2f; speed brake: the right aileron's halves %+.2f up and %+.2f down"
			% [y.call(lowered, "FlapInnerStarboard"), y.call(lowered, "FlapOuterPort"),
				y.call(lowered, "DeceleronUpperStarboard"), y.call(lowered, "DeceleronLowerStarboard")])
	_sections += 1


## THE GEAR KEY RUNS THE GEAR, IN ITS ORDER: from where it is, a press of J; on the drawn airframe the nose doors move
## first, the legs after them, and at the end the gear is where the bus says and the doors shut. Then J again, and it
## goes back the same way.
func _the_gear_key_runs_the_gear(rig: PilotRig) -> void:
	var view: VehicleView = rig.vehicle_view()
	var frame: WarthogAirframe = view._warthog
	var said: PackedStringArray = []
	var ok := true
	for leg in range(2):
		var want_down: bool = not bool(Sim.client.craft_controls(view.entity).get("gear", true))
		var doors_from: PackedVector3Array = _points(frame, frame.find_child("NoseDoorOuter", true, false) as MeshInstance3D)
		var leg_from: PackedVector3Array = _points(frame, frame.find_child("MainGearStarboard", true, false) as MeshInstance3D)
		await _hold("gear", 2)
		var door_first: float = -1.0
		var leg_first: float = -1.0
		var t0: int = Engine.get_physics_frames()
		for i in range(int((WarthogAirframe.GEAR_SECONDS + 1.5) * Engine.physics_ticks_per_second)):
			await get_tree().physics_frame
			if i % 6 != 0:
				continue
			await get_tree().process_frame
			var t: float = float(Engine.get_physics_frames() - t0) / float(Engine.physics_ticks_per_second)
			if door_first < 0.0 and _moved(doors_from, _points(frame, frame.find_child("NoseDoorOuter", true, false) as MeshInstance3D)) > 0.01:
				door_first = t
			if leg_first < 0.0 and _moved(leg_from, _points(frame, frame.find_child("MainGearStarboard", true, false) as MeshInstance3D)) > 0.01:
				leg_first = t
		var bus_down: bool = bool(Sim.client.craft_controls(view.entity).get("gear", true))
		var drawn: float = frame.gear()
		var doors_shut: bool = WarthogAirframe.well_doors_open(drawn) < 0.001
		var this_ok: bool = bus_down == want_down and absf(drawn - (1.0 if want_down else 0.0)) < 0.001 and doors_shut \
			and door_first >= 0.0 and leg_first > door_first
		ok = ok and this_ok
		said.append("%s: the nose doors moved at %.2f s, the legs at %.2f s, drawn %.2f, doors shut %s" % [
			"down" if want_down else "up", door_first, leg_first, drawn, doors_shut])
	_check("the_gear_key_runs_the_gear_doors_first", ok, "; ".join(said))
	_sections += 1


func _trailing_edges(frame: Node3D, parts: Array) -> Dictionary:
	var out: Dictionary = {}
	for part in parts:
		var pts := _points(frame, frame.find_child(part, true, false) as MeshInstance3D)
		var aft: float = -INF
		for p in pts:
			aft = maxf(aft, p.z)
		var sum := Vector3.ZERO
		var n: int = 0
		for p in pts:
			if p.z > aft - 0.01:
				sum += p
				n += 1
		out[part] = sum / float(n)
	return out


static func _deltas(now: Dictionary, rest: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for part in now:
		out[part] = (now[part] as Vector3) - (rest[part] as Vector3)
	return out


## ---- helpers -----------------------------------------------------------------------------------------------------------

## THE MUZZLE THE MODEL DRAWS, in the view's frame: `WarthogAirframe.gun_port()` through the drawn airframe's transform.
func _drawn_port(view: VehicleView) -> Vector3:
	var frame: WarthogAirframe = view._warthog
	if frame == null:
		return Vector3.INF
	return view.global_transform.affine_inverse() * frame.global_transform * frame.gun_port()


func _guns() -> Dictionary:
	for entry in (Sim.missile_schema(Sim.Kind.WARTHOG).get("stations", []) as Array):
		if String((entry as Dictionary).get("name", "")) == "guns":
			return entry
	return {}


func _points(frame: Node3D, mesh: MeshInstance3D) -> PackedVector3Array:
	var into := frame.global_transform.affine_inverse() * mesh.global_transform
	var out := PackedVector3Array()
	for p in (mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		out.append(into * p)
	return out


static func _moved(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var most: float = 0.0
	for i in range(mini(a.size(), b.size())):
		most = maxf(most, a[i].distance_to(b[i]))
	return most


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


func _server_id() -> int:
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", -1)) == Sim.local_client_id():
			return int((pilot as Dictionary).get("vehicle", 0))
	return 0


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
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit()
