extends Node
## Headless: HIT POINTS ACROSS A LINK -- a client's trigger proposes, the host disposes, the client draws what the host
## decided, and a kill on the client's own PREDICTED craft never comes back to life across a rollback (lane/combat).
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/hull_link.tscn [-- --link=4]
##
## A server and a client `CockpitWorld` and a link the test carries the packets over, as `tests/shell_prediction.gd` does.
## THE CLIENT FLIES a light aeroplane and fires its minigun through its own input frame: the weapon selector to the gun
## and the master arm by the bus commands a hand sends, then the trigger. The server alone flies the rounds and takes the
## points off (`Hull`); the client is only ever told.
##
## WHAT IS HELD:
## - every round the SERVER says struck the pod takes the round's damage, asked of the library, off the SERVER's hull;
## - the CLIENT'S hull for that pod reaches the same byte, the same stages in the same order, and destroyed;
## - the CLIENT'S OWN aeroplane, destroyed by the host while the client is still flying it (stick moving, so its
##   prediction is corrected every few ticks), reads destroyed on the client within a link and a few ticks, and never
##   reads whole again; its predicted pose stops where the host froze it.
##
## MUTANT: `Hull`'s `should_roll_back` answering false. The client then never learns its own predicted craft was HIT --
## a predicted entity is only told on a rollback -- and the smoke row goes red. The kill rows stay green under it, and
## that was measured, not assumed: a wreck is frozen, and the frozen pose rolls the client back on its own.
##
## Read RESULT=, not the exit code.

const TICK_HZ: float = 120.0
const DT: float = 1.0 / TICK_HZ
const PEER: int = 2
## How far ahead of the muzzle the pod is hung, metres.
const RANGE: float = 70.0
## How long the client holds the trigger, seconds.
const BURST_S: float = 0.5

var _failures: PackedStringArray = []
var _server: Object = null
var _client: Object = null
var _in_flight: Array = []
var _tick: int = 0
var _link: int = 4


func _check(label: String, ok: bool, detail: String) -> void:
	print("[hull_link] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld") or not ClassDB.class_has_method("CockpitWorld", "hull_states"):
		_finish()
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--link="):
			_link = int(argument.trim_prefix("--link="))
	_server = ClassDB.instantiate("CockpitWorld")
	_client = ClassDB.instantiate("CockpitWorld")
	for world in [_server, _client]:
		world.set_tick_rate(TICK_HZ)
	_server.start(0)
	_client.start(PEER)
	for world in [_server, _client]:
		world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(7200.0, 400.0, 7200.0))
	_idle(90)
	var me: int = int(_client.local_client_id())
	_check("the_client_handshook", me > 0, "client %d" % me)
	if me <= 0:
		_finish()
		return
	var made: Dictionary = _server.spawn_pilot(me, Sim.Kind.PLANE, Vector3(0.0, 600.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -60.0))
	var plane: int = int(made.get("vehicle", 0))
	_idle(_link * 2 + 30)
	# THE GUN ON THE SELECTOR AND THE MASTER ARM ON, as the pilot's hand sends them.
	_command(Sim.Channel.WEAPON, 2)
	_command(Sim.Channel.MASTER, 1)
	_the_client_shoots_and_the_host_decides(me, plane)
	_a_kill_on_the_clients_own_craft_is_stable(plane)
	_the_client_is_put_back_in_the_air_and_flies_it(me, plane)
	for world in [_client, _server]:
		world.teardown()
	_finish()


func _the_client_shoots_and_the_host_decides(me: int, plane: int) -> void:
	# THE POD, ON THE GUN'S LINE: where the server has the nose now, carried on by the plane's own travel for the
	# link's delay, so it is on the line when the trigger reaches the server.
	var state: Dictionary = _server.vehicle_state(plane)
	var nose: Vector3 = Basis(state["basis"] as Quaternion) * Vector3.FORWARD
	var travel: Vector3 = (state["velocity"] as Vector3) * DT * float(_link + 2)
	var at: Vector3 = (state["position"] as Vector3) + travel + nose * RANGE
	var pod: int = int(_server.spawn_vehicle(Sim.Kind.POD, at, 0.0, Vector3.ZERO))
	var whole: float = float(_server.kind_hull(Sim.Kind.POD))
	var damage: float = float(ClassDB.class_call_static(&"CockpitWorld", &"round_damage", 7))
	var hits: Dictionary = {}
	var mismatch: String = ""
	var client_stages: Array[int] = []
	for i in range(int((BURST_S + 1.5) * TICK_HZ)):
		_advance({"trigger": 1.0 if i < int(BURST_S * TICK_HZ) else 0.0})
		for row in _server.shot_states():
			var shot: Dictionary = row
			if int(shot.get("surface", 0)) == 3 and int(shot.get("shooter", -1)) == me \
					and ((shot["impact"] as Vector3) - at).length() < 6.0:
				hits[int(shot["entity"])] = true
		var hull: Dictionary = _server.hull_state(pod)
		var wanted: float = maxf(0.0, whole - damage * float(hits.size()))
		if mismatch.is_empty() and absf(float(hull.get("points", -1.0)) - wanted) > 0.01:
			mismatch = "after %d hits %.2f, wanted %.2f" % [hits.size(), float(hull.get("points", -1.0)), wanted]
		var theirs: int = _client_entity_near(at, Sim.Kind.POD)
		var seen: Dictionary = _client.hull_state(theirs) if theirs != 0 else {}
		var stage: int = int(seen.get("stage", 0))
		if client_stages.is_empty() or client_stages.back() != stage:
			client_stages.append(stage)
	_check("every_round_the_host_says_struck_takes_the_tables_damage_off_the_hosts_hull",
		mismatch.is_empty() and hits.size() > 0, "%d hits of %.0f on %.0f%s" % [hits.size(), damage, whole,
			"" if mismatch.is_empty() else "; " + mismatch])
	var server_final: Dictionary = _server.hull_state(pod)
	var theirs_final: Dictionary = _client.hull_state(_client_entity_near(at, Sim.Kind.POD))
	_check("the_client_draws_what_the_host_decided_stage_by_stage",
		client_stages == [0, 1, 2, 3] or (client_stages.size() >= 2 and client_stages.back() == int(server_final.get("stage", -1))
			and _in_order(client_stages)),
		"client stages %s, host ends at %s, client at %s" % [client_stages, server_final.get("stage"),
			theirs_final.get("stage")])
	_check("and_both_agree_it_was_destroyed", bool(server_final.get("destroyed", false))
		and bool(theirs_final.get("destroyed", false)), "host %s, client %s" % [server_final.get("destroyed"),
		theirs_final.get("destroyed")])


## THE HOST DESTROYS THE CLIENT'S OWN AEROPLANE while the client is flying it with a moving stick: a predicted craft, whose
## world is corrected by rollback. It must read destroyed on the client and never whole again, and stay where it died.
func _a_kill_on_the_clients_own_craft_is_stable(plane: int) -> void:
	var mine: int = _client_entity_near(_server.vehicle_state(plane).get("position", Vector3.ZERO), Sim.Kind.PLANE)
	_check("the_client_has_its_own_aeroplane", mine != 0, "%d" % mine)
	# FIRST A HIT THAT DOES NOT STOP IT: half its points. Nothing about its pose changes, so the only thing that can
	# tell the client's prediction is `Hull`'s own rollback -- the row the mutant turns red. (A kill freezes the craft,
	# and the frozen pose alone rolls the client back and brings the Hull with it, so a kill cannot prove the rule.)
	_server.apply_damage(plane, float(_server.kind_hull(Sim.Kind.PLANE)) * 0.5)
	var smoked_at: int = -1
	for i in range(int(1.0 * TICK_HZ)):
		_advance({"pitch": 0.05, "throttle": 0.8})
		if smoked_at < 0 and int(_client.hull_state(mine).get("stage", 0)) == 1:
			smoked_at = i
	_check("the_client_sees_its_own_predicted_craft_smoke_within_a_link", smoked_at >= 0 and smoked_at <= _link * 2 + 10,
		"stage 1 seen %d ticks after the hit, link %d" % [smoked_at, _link])
	_server.apply_damage(plane, 10000.0)
	var died_at: Vector3 = _server.vehicle_state(plane).get("position", Vector3.ZERO)
	var seen_at: int = -1
	var flipped: int = 0
	var resims_before: int = int(_client.resim_stats().get("count", 0))
	var drift: float = 0.0
	for i in range(int(3.0 * TICK_HZ)):
		# A STICK THAT KEEPS MOVING, so the client's prediction keeps disagreeing with the host and keeps rolling back.
		_advance({"pitch": sin(float(i) * 0.2) * 0.8, "roll": cos(float(i) * 0.13) * 0.8, "throttle": 1.0})
		var destroyed: bool = bool(_client.hull_state(mine).get("destroyed", false))
		if destroyed and seen_at < 0:
			seen_at = i
		if seen_at >= 0 and not destroyed:
			flipped += 1
		if seen_at >= 0 and i > seen_at + _link + 10:
			var drawn: Dictionary = {}
			for row in _client.vehicle_states():
				if int((row as Dictionary)["entity"]) == mine:
					drawn = row
			drift = maxf(drift, ((drawn.get("position", died_at) as Vector3) - died_at).length())
	var resims: int = int(_client.resim_stats().get("count", 0)) - resims_before
	_check("the_client_learns_its_own_predicted_craft_was_destroyed_within_a_link",
		seen_at >= 0 and seen_at <= _link * 2 + 10, "seen %d ticks after, link %d" % [seen_at, _link])
	_check("and_it_never_reads_whole_again_across_the_rollbacks", seen_at >= 0 and flipped == 0,
		"%d ticks read whole after the kill, over %d resimulations" % [flipped, resims])
	_check("and_the_wreck_stays_where_the_host_froze_it", seen_at >= 0 and drift < 0.5,
		"drawn %.2f m from where it died" % drift)


## THE RESPAWN, ACROSS THE LINK: the host moves the client's crew out of the wreck into a fresh light aeroplane
## (`respawn_crew`), and the client flies it on its own input -- a full stick back raises the fresh craft's nose on the
## HOST, which is what "the first of two same-tick seatings flies on dead input" (lightgun's S-2) would have failed.
## One pilot for the client throughout, on both machines.
func _the_client_is_put_back_in_the_air_and_flies_it(me: int, wreck: int) -> void:
	var asked: bool = bool(_server.respawn_crew(wreck, Vector3(0.0, 700.0, 400.0), 0.0, Vector3(0.0, 0.0, -60.0)))
	_check("the_host_asks_the_wrecks_crew_back_into_the_air", asked, "")
	_idle(_link * 2 + 10)
	var fresh: int = 0
	for pilot in _server.pilot_states():
		if int((pilot as Dictionary)["client"]) == me:
			fresh = int((pilot as Dictionary)["vehicle"])
	_check("and_the_client_is_in_a_fresh_craft_on_the_host", fresh != 0 and fresh != wreck
		and not bool(_server.hull_state(fresh).get("destroyed", true)), "%d, the wreck was %d" % [fresh, wreck])
	var mine_host: int = _server.pilot_states().filter(func(p: Dictionary) -> bool: return int(p["client"]) == me).size()
	var mine_here: int = _client.pilot_states().filter(func(p: Dictionary) -> bool: return int(p["client"]) == me).size()
	_check("as_one_pilot_on_both_machines", mine_host == 1 and mine_here == 1, "%d on the host, %d here" % [mine_host,
		mine_here])
	var before: Basis = Basis(_server.vehicle_state(fresh)["basis"] as Quaternion)
	for i in range(int(1.0 * TICK_HZ)):
		_advance({"pitch": 1.0, "throttle": 1.0})
	var after: Basis = Basis(_server.vehicle_state(fresh)["basis"] as Quaternion)
	var nose_up: float = rad_to_deg(asin(clampf((after * Vector3.FORWARD).y, -1.0, 1.0))
		- asin(clampf((before * Vector3.FORWARD).y, -1.0, 1.0)))
	_check("and_it_flies_on_the_clients_own_stick", nose_up > 5.0, "the nose rose %.1f degrees in a second on a full stick"
		% nose_up)


static func _in_order(stages: Array[int]) -> bool:
	for i in range(1, stages.size()):
		if stages[i] < stages[i - 1]:
			return false
	return true


## The client's entity for the craft of `kind` nearest `at`, 0 if it has none within 40 m.
func _client_entity_near(at: Vector3, kind: int) -> int:
	var best: int = 0
	var nearest: float = 40.0
	for row in _client.vehicle_states():
		var state: Dictionary = row
		if int(state.get("kind", -1)) != kind:
			continue
		var far: float = ((state["position"] as Vector3) - at).length()
		if far < nearest:
			nearest = far
			best = int(state["entity"])
	return best


func _command(channel: int, value: int) -> void:
	_client.send_command(channel, value)
	_idle(_link * 2 + 6)


func _idle(ticks: int) -> void:
	for i in range(ticks):
		_advance({})


func _advance(overrides: Dictionary) -> void:
	var input: Dictionary = {
		"throttle": 0.6, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0,
	}
	for key in overrides:
		input[key] = overrides[key]
	_client.set_input(input)
	_tick += 1
	_server.tick(DT)
	_client.tick(DT)
	_pump()


func _pump() -> void:
	for packet in _server.take_outbound():
		_in_flight.append([_tick + _link, false, int(packet["peer"]), packet["bytes"], packet["bits"]])
	for packet in _client.take_outbound():
		_in_flight.append([_tick + _link, true, PEER, packet["bytes"], packet["bits"]])
	var still: Array = []
	for entry in _in_flight:
		if entry[0] > _tick:
			still.append(entry)
			continue
		if bool(entry[1]):
			_server.deliver(entry[2], entry[3], entry[4])
		else:
			_client.deliver(0, entry[3], entry[4])
	_in_flight = still


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
