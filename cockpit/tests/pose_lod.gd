extends Node
## Headless: A FAR PLAYER'S HEAD AND HANDS ARE NOT SENT, AND A NEAR ONE'S ARE, LIVE.
##
##   Godot --headless --xr-mode off --fixed-fps 120 --path cockpit res://tests/pose_lod.tscn
##
## THE POSE LOD (lane/ashiato-latest step 3, 2026-09-18), `CockpitWorld.set_pose_lod`, OFF BY DEFAULT. A pilot's
## PilotState -- three tracked poses and two grips, about 240 bits, not delta-coded, a change on every tick in VR -- is left
## out of what a client is sent for a pilot whose craft is more than `far_m` from that client's own, and put back inside
## `near_m`. Nothing else is masked. `learnings/2026-09-18-upstream.md` has why, and the trap it is shaped around: sync does
## not ask again about an entity a client has acknowledged until it changes, so a STEP component masked while far can
## stay stale for good. Poses move every tick and heal; lights, seats and bus pages are never masked.
##
## WHAT IS REAL. A server and two or three client CockpitWorlds over an exact one-tick link, pilots in real craft with
## tracked poses that move every tick, and each client's own sync trace (`component_received`) for what reached it. The
## rule is also asked directly (`pose_masked`), and every count has a control with the LOD off beside it, so a check
## that counts nothing cannot pass.
##
## WHAT IT HOLDS:
##   1. far poses are not sent, the far pilot is still listed (PilotOwner went), and the far craft still arrives;
##   2. a pilot coming near is drawn live -- its poses start arriving inside `near_m` plus the decision bucket and the
##      link, and match what the server has -- and going away again masks it once, with no flapping;
##   3. the stale-seat trap: a far pilot who changes seat is drawn in the new seat, because the seat is read off the
##      craft's Seats and never off the masked PilotState;
##   4. crew are never masked, at any setting;
##   5. a far craft's lights still arrive; and a pilot held live (`set_pose_live`, a signal lamp in hand) has live hand
##      poses at any distance, and loses them again when let go;
##   6. the boundary holds its hysteresis, and a bad setting is refused.
##
## Read RESULT=, not the exit code.

const DT: float = 1.0 / 120.0
const TICK_HZ: float = 120.0
const LINK: int = 1
## A two-seat aeroplane: the copilot seat is what the crew and seat checks sit in.
const PLANE: int = 1
const NEAR_M: float = 250.0
const FAR_M: float = 350.0
const ALT: float = 1500.0
## sync's decision bucket (`entity_replication_decision_interval_frames`), a link each way and a tick of slack: how many
## ticks late the first live pose may be, at the closing speed, beyond `near_m`.
const OPEN_TICKS: int = 4 + 2 * LINK + 2
## The wire's step for a pose position is 2 mm (`cw::reach`); a received head matches a server head to this.
const POSE_MATCH_M: float = 0.003
const MEASURE: int = 240
## Our own channel for lights (`Sim.Channel.LIGHTS`), read from Sim rather than typed.
var LIGHTS: int = Sim.Channel.LIGHTS

var _failures: PackedStringArray = []
var _server: RefCounted = null
var _clients: Array = []
var _tick: int = 0
var _in_flight: Array = []
## Client indices whose poses stand still (a desktop player) instead of moving every tick.
var _still: Dictionary = {}
## Per client index: its own local entity -> PilotState records received THIS tick. Filled by `_run`.
var _pose_rx: Array = []
var _vehicle_rx: Array = []
## The server's own head for every pilot, by client, for the last HISTORY ticks: a received pose matches one of them.
const HISTORY: int = 40
var _server_heads: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[pose_lod] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("cockpit_world_is_registered", false, "the ashiato extension did not load")
		_finish()
		return
	var probe: RefCounted = ClassDB.instantiate("CockpitWorld")
	for method in ["set_pose_lod", "pose_lod", "set_pose_live", "pose_masked"]:
		_check("the_world_has_%s" % method, probe.has_method(method), "bound on CockpitWorld")
	if not _failures.is_empty():
		_finish()
		return
	_check("a_new_world_starts_with_the_lod_off", not bool(probe.pose_lod().get("enabled", true)), str(probe.pose_lod()))
	_far()
	_approach()
	_seat()
	_crew()
	_boundary()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## ---- 1 and 5: far poses, the far craft, lights, and a lamp in hand -------------------------------------------------

func _far() -> void:
	_stand_up(2)
	var a: int = int(_clients[0].local_client_id())
	var b: int = int(_clients[1].local_client_id())
	_check("far_two_clients_joined", a > 0 and b > 0, "%d and %d" % [a, b])
	_server.set_pose_lod(true, NEAR_M, FAR_M)
	var flying_a: Dictionary = _server.spawn_pilot(a, PLANE, Vector3(0.0, ALT, 0.0), 0.0, Vector3(0.0, 0.0, -60.0))
	var flying_b: Dictionary = _server.spawn_pilot(b, PLANE, Vector3(3000.0, ALT, 0.0), 0.0, Vector3(0.0, 0.0, -60.0))
	_run(240)
	var b_pilot_on_a: int = _pilot_entity(0, b)
	var b_craft_on_a: int = _vehicle_of(0, b)
	_check("the_far_pilot_is_still_listed", b_pilot_on_a != 0 and b_craft_on_a != 0,
		"B's pilot %d and craft %d on A" % [b_pilot_on_a, b_craft_on_a])
	_check("the_rule_masks_the_far_pair_both_ways", _server.pose_masked(a, b) and _server.pose_masked(b, a),
		"A<-B %s, B<-A %s" % [_server.pose_masked(a, b), _server.pose_masked(b, a)])
	var far: Dictionary = _count(0, b_pilot_on_a, b_craft_on_a, MEASURE)
	_check("far_poses_are_not_sent", int(far["poses"]) == 0, "%d PilotState records in %d ticks" % [far["poses"], MEASURE])
	_check("the_far_craft_still_arrives", int(far["vehicle"]) >= MEASURE / 2,
		"%d VehicleState records in %d ticks" % [far["vehicle"], MEASURE])
	_check("and_is_listed_unposed", not bool(_pilot_row(0, b).get("posed", true)), str(_pilot_row(0, b).get("posed")))

	# LIGHTS: a craft switch, never masked. Asked of A's own copy of B's craft.
	_clients[1].send_command(LIGHTS, 1)
	_run(120)
	_check("a_far_crafts_lights_still_arrive", bool(_clients[0].craft_systems(b_craft_on_a).get("lights", false)),
		str(_clients[0].craft_systems(b_craft_on_a)))

	# A LAMP IN HAND: held live, B's hands reach A at 3 km, every tick, and match the server's.
	_server.set_pose_live(b, true)
	_run(12)
	var live: Dictionary = _count(0, b_pilot_on_a, b_craft_on_a, MEASURE)
	_check("a_pilot_held_live_has_live_poses_far_away", int(live["poses"]) >= MEASURE * 9 / 10,
		"%d PilotState records in %d ticks at %.0f m" % [live["poses"], MEASURE, _distance(flying_a, flying_b)])
	_check("and_they_are_the_servers", _matches_server(0, b), _match_detail(0, b))
	_server.set_pose_live(b, false)
	_run(12)
	var let_go: Dictionary = _count(0, b_pilot_on_a, b_craft_on_a, MEASURE)
	_check("let_go_they_stop_again", int(let_go["poses"]) == 0, "%d PilotState records" % let_go["poses"])

	# THE CONTROL: off, the same pair is sent every tick, so the zeros above were the LOD and not the counting.
	_server.set_pose_lod(false, NEAR_M, FAR_M)
	_run(12)
	var off: Dictionary = _count(0, b_pilot_on_a, b_craft_on_a, MEASURE)
	_check("off_the_same_far_poses_are_sent", int(off["poses"]) >= MEASURE * 9 / 10,
		"%d PilotState records in %d ticks" % [off["poses"], MEASURE])
	_tear_down()


## ---- 2: coming near, and going away again ---------------------------------------------------------------------------

func _approach() -> void:
	_stand_up(2)
	var a: int = int(_clients[0].local_client_id())
	var b: int = int(_clients[1].local_client_id())
	_server.set_pose_lod(true, NEAR_M, FAR_M)
	# Head on, 150 m apart sideways and 150 m up, closing at 120 m/s from 1.4 km: past each other in about twelve seconds.
	var flying_a: Dictionary = _server.spawn_pilot(a, PLANE, Vector3(0.0, ALT, 0.0), 0.0, Vector3(0.0, 0.0, -60.0))
	var flying_b: Dictionary = _server.spawn_pilot(b, PLANE, Vector3(150.0, ALT + 150.0, -1400.0), PI,
		Vector3(0.0, 0.0, 60.0))
	_run(60)
	var b_pilot_on_a: int = _pilot_entity(0, b)
	var opened_at := -1.0
	var opened_tick := -1
	var closed_at := -1.0
	var opens := 0
	var closes := 0
	var was_masked: bool = _server.pose_masked(a, b)
	var start_masked := was_masked
	var start_d: float = _distance(flying_a, flying_b)
	var nearest := INF
	var matched := false
	for i in range(2400):
		_run(1)
		var d: float = _distance(flying_a, flying_b)
		nearest = minf(nearest, d)
		var masked: bool = _server.pose_masked(a, b)
		if was_masked and not masked:
			opens += 1
		if masked and not was_masked:
			closes += 1
			closed_at = d
		was_masked = masked
		if opened_tick < 0 and int(_pose_rx[0].get(b_pilot_on_a, 0)) > 0:
			opened_tick = _tick
			opened_at = d
		# LIVE, a few ticks after the first record: the buffered client draws a pose from a little in the past.
		if opened_tick > 0 and _tick == opened_tick + 20:
			matched = _matches_server(0, b)
		if closes > 0 and d > FAR_M + 200.0:
			break
	var closing_m_per_tick: float = 120.0 * DT
	_check("the_pair_starts_masked", start_masked, "at %.0f m" % start_d)
	_check("they_came_near", nearest < NEAR_M, "nearest %.0f m" % nearest)
	_check("the_first_live_pose_arrives_inside_near_m", opened_at > 0.0
			and opened_at <= NEAR_M + OPEN_TICKS * closing_m_per_tick,
		"first PilotState at %.1f m, allowed %.1f" % [opened_at, NEAR_M + OPEN_TICKS * closing_m_per_tick])
	_check("and_not_while_still_far", opened_at >= NEAR_M - OPEN_TICKS * closing_m_per_tick - 1.0,
		"first PilotState at %.1f m" % opened_at)
	_check("the_pose_drawn_is_the_live_one", matched, _match_detail(0, b))
	_check("going_away_masks_it_again_past_far_m", closes == 1 and closed_at > FAR_M - 1.0,
		"%d closings, at %.1f m" % [closes, closed_at])
	_check("once_each_way_no_flapping", opens == 1 and closes == 1, "%d opened, %d closed" % [opens, closes])
	_tear_down()


## ---- 3: the stale-seat trap -------------------------------------------------------------------------------------------

func _seat() -> void:
	_stand_up(2)
	_still[1] = true
	var a: int = int(_clients[0].local_client_id())
	var b: int = int(_clients[1].local_client_id())
	_server.set_pose_lod(true, NEAR_M, FAR_M)
	_server.spawn_pilot(a, PLANE, Vector3(0.0, ALT, 0.0), 0.0, Vector3(0.0, 0.0, -60.0))
	var flying_b: Dictionary = _server.spawn_pilot(b, PLANE, Vector3(3000.0, ALT, 0.0), 0.0, Vector3(0.0, 0.0, -60.0))
	_run(120)
	var moved: bool = _server.seat_client(b, int(flying_b["vehicle"]), 1)
	_run(120)
	var row: Dictionary = _pilot_row(0, b)
	_check("the_far_pilot_moved_seat", moved, "seat_client")
	_check("the_trap_stale_seat", int(row.get("seat", -99)) == 1,
		"drawn in seat %d; the masked wire copy says %d; poses masked %s" % [int(row.get("seat", -99)),
			int(row.get("pilot_seat", -99)), _server.pose_masked(a, b)])
	_still.clear()
	_tear_down()


## ---- 4: crew -----------------------------------------------------------------------------------------------------------

func _crew() -> void:
	_stand_up(3)
	var a: int = int(_clients[0].local_client_id())
	var b: int = int(_clients[1].local_client_id())
	var c: int = int(_clients[2].local_client_id())
	# The tightest setting there is: everybody at any distance at all is far.
	_server.set_pose_lod(true, 0.0, 0.0)
	var flying_a: Dictionary = _server.spawn_pilot(a, PLANE, Vector3(0.0, ALT, 0.0), 0.0, Vector3(0.0, 0.0, -60.0))
	_server.spawn_pilot(b, PLANE, Vector3(3000.0, ALT, 0.0), 0.0, Vector3(0.0, 0.0, -60.0))
	# C comes in with a craft of its own, as every player does, and then climbs into A's copilot seat.
	_server.spawn_pilot(c, PLANE, Vector3(-3000.0, ALT, 0.0), 0.0, Vector3(0.0, 0.0, -60.0))
	_run(30)
	_check("c_takes_the_copilot_seat", _server.seat_client(c, int(flying_a["vehicle"]), 1), "seat_client")
	_run(120)
	var c_pilot_on_a: int = _pilot_entity(0, c)
	var crew: Dictionary = _count(0, c_pilot_on_a, 0, MEASURE)
	_check("crew_never_masked", int(crew["poses"]) >= MEASURE * 9 / 10 and not _server.pose_masked(a, c)
			and not _server.pose_masked(c, a),
		"%d of C's PilotState records on A in %d ticks; A<-C masked %s" % [crew["poses"], MEASURE,
			_server.pose_masked(a, c)])
	_check("while_the_stranger_is_masked", _server.pose_masked(a, b), "A<-B %s" % _server.pose_masked(a, b))
	_tear_down()


## ---- 6: the boundary, asked directly -----------------------------------------------------------------------------------

func _boundary() -> void:
	_stand_up(2)
	var a: int = int(_clients[0].local_client_id())
	var b: int = int(_clients[1].local_client_id())
	# Side by side, 300 m apart, flying the same way: the distance holds while the thresholds move round it.
	_server.spawn_pilot(a, PLANE, Vector3(0.0, ALT, 0.0), 0.0, Vector3(0.0, 0.0, -60.0))
	_server.spawn_pilot(b, PLANE, Vector3(300.0, ALT, 0.0), 0.0, Vector3(0.0, 0.0, -60.0))
	var steps: Array = [[250.0, 350.0, false, "300 m, inside far_m: open"],
		[250.0, 290.0, true, "past far_m 290: masked"],
		[280.0, 320.0, true, "between near_m and far_m: stays masked"],
		[310.0, 350.0, false, "inside near_m 310: open"],
		[250.0, 320.0, false, "between again: stays open"]]
	var got: Array = []
	var ok := true
	for step in steps:
		_server.set_pose_lod(true, float(step[0]), float(step[1]))
		_run(20)
		var masked: bool = _server.pose_masked(a, b)
		got.append("%s=%s" % [step[3], masked])
		ok = ok and masked == bool(step[2])
	_check("the_boundary_holds_its_hysteresis", ok, ", ".join(got))
	var before: Dictionary = _server.pose_lod()
	_check("near_above_far_is_refused", not _server.set_pose_lod(true, 400.0, 300.0), "set_pose_lod(true, 400, 300)")
	_check("nan_is_refused", not _server.set_pose_lod(true, NAN, 300.0), "set_pose_lod(true, NaN, 300)")
	_check("and_a_refusal_changes_nothing", _server.pose_lod().hash() == before.hash(),
		"%s against %s" % [_server.pose_lod(), before])
	_tear_down()


## ---- the harness -------------------------------------------------------------------------------------------------------

func _stand_up(clients: int) -> void:
	_server = ClassDB.instantiate("CockpitWorld")
	_server.set_tick_rate(TICK_HZ)
	_server.start(0)
	_clients.clear()
	_in_flight.clear()
	_pose_rx.clear()
	_vehicle_rx.clear()
	_server_heads.clear()
	_tick = 0
	for i in range(clients):
		var world: RefCounted = ClassDB.instantiate("CockpitWorld")
		world.set_tick_rate(TICK_HZ)
		# BEFORE start: the tracer is attached as the world is built.
		world.set_tracing(true)
		world.start(i + 2)
		_clients.append(world)
		_pose_rx.append({})
		_vehicle_rx.append({})
	_run(int(1.5 * TICK_HZ))


func _tear_down() -> void:
	for world in _clients:
		world.teardown()
	_server.teardown()
	_clients.clear()
	_server = null


## Every client's tracked poses: moving every tick, a little differently each, unless it is standing still.
func _input_for(i: int) -> Dictionary:
	var input: Dictionary = {"throttle": 0.6, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0, "buttons": 0,
		"trigger": 0.0}
	var phase: float = 0.0 if _still.has(i) else float(_tick) * 0.07 + float(i)
	input["head"] = Vector3(sin(phase) * 0.10, cos(phase * 0.7) * 0.06, sin(phase * 0.4) * 0.05)
	input["left"] = Vector3(-0.3 + sin(phase * 1.1) * 0.12, -0.25 + cos(phase) * 0.10, -0.3)
	input["right"] = Vector3(0.3 + cos(phase * 0.9) * 0.12, -0.25 + sin(phase) * 0.10, -0.3)
	input["head_basis"] = Quaternion(Vector3.UP, phase * 0.2)
	input["left_basis"] = Quaternion(Vector3.RIGHT, phase * 0.3)
	input["right_basis"] = Quaternion(Vector3.FORWARD, phase * 0.25)
	return input


## ONE TICK FOR EVERYBODY over an exact link, as priority_sphere's: a packet sent after tick T is delivered before the
## receiver's tick T + LINK. Each client's PilotState and VehicleState receipts for this tick land in `_pose_rx` and
## `_vehicle_rx`, and the server's heads in `_server_heads`.
func _run(ticks: int) -> void:
	for n in range(ticks):
		_tick += 1
		var waiting: Array = []
		for flight in _in_flight:
			if int(flight[0]) > _tick:
				waiting.append(flight)
			elif int(flight[1]) == 0:
				_server.deliver(int(flight[2]), flight[3], flight[4])
			else:
				_clients[int(flight[1]) - 2].deliver(0, flight[3], flight[4])
		_in_flight = waiting
		for i in range(_clients.size()):
			_clients[i].set_input(_input_for(i))
		_server.tick(DT)
		for world in _clients:
			world.tick(DT)
		for packet in _server.take_outbound():
			_in_flight.append([_tick + LINK, int(packet["peer"]), 0, packet["bytes"], packet["bits"]])
		for i in range(_clients.size()):
			for packet in _clients[i].take_outbound():
				_in_flight.append([_tick + LINK, 0, i + 2, packet["bytes"], packet["bits"]])
		_server.take_trace_events()
		for i in range(_clients.size()):
			var poses: Dictionary = {}
			var vehicles: Dictionary = {}
			for event in _clients[i].take_trace_events():
				if String(event.get("type", "")) != "component_received":
					continue
				var component := String(event.get("component", ""))
				var entity := int(event.get("entity", 0))
				if component == "PilotState":
					poses[entity] = int(poses.get(entity, 0)) + 1
				elif component == "VehicleState":
					vehicles[entity] = int(vehicles.get(entity, 0)) + 1
			_pose_rx[i] = poses
			_vehicle_rx[i] = vehicles
		for pilot in _server.pilot_states():
			var client := int(pilot["client"])
			var heads: Array = _server_heads.get(client, [])
			heads.append(pilot["head"])
			if heads.size() > HISTORY:
				heads.pop_front()
			_server_heads[client] = heads


## Records client `i` receives over `ticks`: PilotState for `pilot` and VehicleState for `craft`, both its local ids.
func _count(i: int, pilot: int, craft: int, ticks: int) -> Dictionary:
	var poses := 0
	var vehicle := 0
	for n in range(ticks):
		_run(1)
		poses += int(_pose_rx[i].get(pilot, 0))
		vehicle += int(_vehicle_rx[i].get(craft, 0))
	return {"poses": poses, "vehicle": vehicle}


func _pilot_row(i: int, client: int) -> Dictionary:
	for pilot in _clients[i].pilot_states():
		if int((pilot as Dictionary)["client"]) == client:
			return pilot
	return {}


func _pilot_entity(i: int, client: int) -> int:
	return int(_pilot_row(i, client).get("entity", 0))


func _vehicle_of(i: int, client: int) -> int:
	return int(_pilot_row(i, client).get("vehicle", 0))


## Whether client `i` draws `client`'s head where the server had it within the last HISTORY ticks, to the wire's step.
func _matches_server(i: int, client: int) -> bool:
	var row: Dictionary = _pilot_row(i, client)
	if not bool(row.get("posed", false)):
		return false
	var head: Vector3 = row["head"]
	for server_head in _server_heads.get(client, []):
		if head.distance_to(server_head) <= POSE_MATCH_M:
			return true
	return false


func _match_detail(i: int, client: int) -> String:
	var row: Dictionary = _pilot_row(i, client)
	var heads: Array = _server_heads.get(client, [])
	return "drawn head %s posed %s; server's newest %s" % [row.get("head", "?"), row.get("posed", "?"),
		heads[-1] if not heads.is_empty() else "?"]


func _distance(one: Dictionary, other: Dictionary) -> float:
	var at_one := Vector3(INF, INF, INF)
	var at_other := Vector3(INF, INF, INF)
	for vehicle in _server.vehicle_states():
		var entity := int((vehicle as Dictionary)["entity"])
		if entity == int(one["vehicle"]):
			at_one = (vehicle as Dictionary)["position"]
		elif entity == int(other["vehicle"]):
			at_other = (vehicle as Dictionary)["position"]
	return at_one.distance_to(at_other)
