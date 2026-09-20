extends Node
## A server and TWO clients in one process, across a delayed link.
##
##   Godot --path addon --headless res://tests/cockpit_loopback.tscn
##
## The cockpit module exists to make one promise: a pilot's view is locked to their
## vehicle and nothing about the vehicle's speed can shake it. That promise is structural
## rather than tuned, so the test checks the structure:
##
##   1. a pilot has NO world pose on the wire, at any speed
##   2. a hand held still has an unchanging seat-local pose while the vehicle is flying
##   3. the vehicle answers the stick immediately on the machine flying it
##   4. everybody else sees it, banked, through the wire
##   5. a pilot is always in a seat
##   6. every control moves the aircraft the way it says it does
##
## Packets are carried by this script, so it runs headless with no sockets and no Steam.
##
## Read RESULT=, not the exit code.

## Every world simulates at this. Set explicitly rather than left to the default, because
## the whole point of the setting is that peers must agree: a test ticking at one rate
## against a world configured for another measures a simulation nobody will ever run.
const TICK_HZ: float = 60.0
const DT: float = 1.0 / TICK_HZ
## One-way delay in ticks. 4 each way is ~133 ms round trip: a bad-but-real connection.
const LINK_DELAY_TICKS: int = 4
const PEER_A: int = 1
const PEER_B: int = 2

## Kinds, matching kKind* in cockpit_world.cpp.
const POD: int = 0
const PLANE: int = 1
const BOAT: int = 2
const CAR: int = 3
const HELI: int = 4
const TRAIN: int = 5
const AIRLINER: int = 6
const GUNSHIP: int = 15

## Movement models, matching Model in cockpit_world.cpp.
const M_HOVER: int = 0
const M_AIRPLANE: int = 1
const M_HELICOPTER: int = 2
const M_CAR: int = 3
const M_BOAT: int = 4

## Button bits, matching kButton* in cockpit_world.cpp.
const SEAT: int = 1
const USE: int = 2
## Matching kButtonFire: the trigger, as a level.
const FIRE: int = 16
const LOCK: int = 64
const LAUNCH: int = 128
## Bus channel, matching Channel::Lights in cockpit_world.cpp.
const CHANNEL_LIGHTS: int = 12
## Bus channel, matching Channel::CrewToggle: the button in front of a seat, which toggles.
const CHANNEL_CREW_TOGGLE: int = 14
## Bus channels, matching Channel::Weapon and Channel::Master.
const WEAPON: int = 8
const MASTER: int = 13
const GLIDER: int = 17
## A third client, started late, for the reference that has not arrived yet.
##
## AND ITS PEER IS THE WIDEST ONE GODOT HANDS OUT. `MultiplayerPeer::generate_unique_id` masks its hash to 0x7FFFFFFF and
## never returns 0 or 1 (the host), so a client's peer is 2 to 2^31-1; A is the host's 1 and B the smallest client, 2. The
## peer rides PilotOwner in 32 bits, and a field is only proved by its extreme value (working_with_godot.md, "A value that
## does not fit its field").
const PEER_C: int = 2147483647
## Matching kSeeker* and kWhy* in cockpit_components.hpp.
const SEEKER_NONE: int = 0
const SEEKER_SEARCHING: int = 1
const SEEKER_LOCKING: int = 2
const SEEKER_LOCKED: int = 3
const SEEKER_LOST: int = 4
const WHY_READY: int = 0
const WHY_NOT_ARMED: int = 3
const WHY_NO_LOCK: int = 4
const WHY_EMPTY: int = 5
## Matching kCueMissileLaunch and kCueMissileEnd.
const CUE_MISSILE_LAUNCH: int = 1
const CUE_MISSILE_END: int = 2
## Matching kSurfaceFused, and kKindTower -- a building, which is where it was put.
const SURFACE_FUSED: int = 5
const TOWER: int = 11

var _failures: PackedStringArray = []
## [[deliver_at_tick, target, from_peer, bytes, bits], ...] where target 0 is the server.
var _in_flight: Array = []
## Bytes the server handed each peer in the tick just pumped: peer -> bytes. Cleared every tick.
var _sent_to: Dictionary = {}
var _tick: int = 0

var server
var client_a
var client_b
## Only while the late-joiner test runs; null otherwise, and every use checks.
var client_c = null
## pilot entity -> the control frame to write into it each tick, for vehicles this test
## flies itself rather than through one of the two real clients.
var _server_inputs: Dictionary = {}
var _next_spare: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[cockpit] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## A complete control frame: sticks centred, hands where a seated person's hands are.
func _controls(overrides: Dictionary = {}) -> Dictionary:
	var input: Dictionary = {
		"throttle": 0.0,
		"pitch": 0.0,
		"roll": 0.0,
		"rudder": 0.0,
		"brake": 0.0,
		"head": Vector3(0.0, 0.0, 0.0),
		"head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30),
		"left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30),
		"right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0,
		"grip_right": 0.0,
		"buttons": 0,
		# THE TRIGGER, EXPLICITLY AT REST. An input is merged into what the world already holds, so a frame with no
		# "trigger" left the last pull standing: "letting go" of a door gun kept it firing, and the wire probe's quiet
		# window had a gun going in it (2026-09-14).
		"trigger": 0.0,
	}
	for key in overrides:
		input[key] = overrides[key]
	return input


## CLIENT A'S PACKETS HANDED OVER IN BUNCHES: above 1, they reach the server only on ticks that are
## a multiple of this, so several of A's input frames arrive together and late. sync then takes the
## newest frame due and SKIPS the ones before it, which is what a jittery link does to a command
## that rides only one frame. Resending does not help: every unacknowledged frame is in every
## packet, so nothing is lost, only skipped. 1 is an ordinary link.
var _client_release_every: int = 1


func _pump() -> void:
	for packet in server.take_outbound():
		_in_flight.append([_tick + LINK_DELAY_TICKS, int(packet["peer"]), 0,
			packet["bytes"], packet["bits"]])
		_sent_to[int(packet["peer"])] = int(_sent_to.get(int(packet["peer"]), 0)) \
			+ (packet["bytes"] as PackedByteArray).size()
	for packet in client_a.take_outbound():
		var due: int = _tick + LINK_DELAY_TICKS
		if _client_release_every > 1:
			due = ((due + _client_release_every - 1) / _client_release_every) * _client_release_every
		_in_flight.append([due, 0, PEER_A, packet["bytes"], packet["bits"]])
	for packet in client_b.take_outbound():
		_in_flight.append([_tick + LINK_DELAY_TICKS, 0, PEER_B, packet["bytes"], packet["bits"]])
	if client_c != null:
		for packet in client_c.take_outbound():
			_in_flight.append([_tick + LINK_DELAY_TICKS, 0, PEER_C, packet["bytes"], packet["bits"]])

	var still_flying: Array = []
	for entry in _in_flight:
		if entry[0] > _tick:
			still_flying.append(entry)
			continue
		match int(entry[1]):
			0: server.deliver(entry[2], entry[3], entry[4])
			PEER_A: client_a.deliver(0, entry[3], entry[4])
			PEER_B: client_b.deliver(0, entry[3], entry[4])
			PEER_C:
				if client_c != null:
					client_c.deliver(0, entry[3], entry[4])
	_in_flight = still_flying


func _advance(ticks: int, input_a: Dictionary = {}, input_b: Dictionary = {}) -> void:
	for i in range(ticks):
		if not input_a.is_empty():
			client_a.set_input(input_a)
		if not input_b.is_empty():
			client_b.set_input(input_b)
		for pilot_entity in _server_inputs:
			server.set_pilot_input(pilot_entity, _server_inputs[pilot_entity])
		_tick += 1
		_sent_to.clear()
		server.tick(DT)
		client_a.tick(DT)
		client_b.tick(DT)
		if client_c != null:
			client_c.tick(DT)
		_pump()


## Ground, built identically in every world. Not replicated -- both sides build it from
## the same data -- so a world that built it differently would predict its pilot into it.
func _build_world(world) -> void:
	world.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(400.0, 2.0, 400.0))
	# A CATCH FLOOR under the whole wire, 100 m above its floor, asked of the wire. A craft a test leaves in the air falls
	# off the 400 m box, and before this it fell through the wire's floor and clamped on every tick of every test after:
	# 11 craft and 2 missiles, 232,202 coordinates in one run (2026-09-14).
	var wire: Dictionary = world.wire_range()
	var edge: float = float(wire["ground_max"])
	world.add_static_box(Vector3(0.0, float(wire["height_min"]) + 95.0, 0.0), Vector3(edge, 5.0, edge))


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		# A REFUSAL IS A FAILURE, NOT A PASS. This printed its complaint and then finished with no
		# failure recorded, so the whole suite reported RESULT=PASS in 0.3 s without instantiating a
		# single CockpitWorld -- against 12.7 s when the extension is actually there. It is the suite
		# a lane is told to run to PROVE the rebuilt DLL reached the addon project, and it was the one
		# suite that could not prove it: on 2026-09-17 `ashiato-gd/addon/.godot/extension_list.cfg` was
		# missing, every CockpitWorld class was absent, and this went green. Seven of the eight suites
		# that guard on this class already fail; this was the eighth.
		print("[cockpit] CockpitWorld not registered; build with -WithCockpit")
		_failures.append("cockpit_world_is_registered")
		_finish()
		return

	server = ClassDB.instantiate("CockpitWorld")
	client_a = ClassDB.instantiate("CockpitWorld")
	client_b = ClassDB.instantiate("CockpitWorld")
	for world in [server, client_a, client_b]:
		world.set_tick_rate(TICK_HZ)
	_check("tick_rate_is_settable", is_equal_approx(float(server.tick_rate()), TICK_HZ),
		"all three worlds at %.0f Hz" % float(server.tick_rate()))
	_check("server_starts", server.start(0), "client_id 0 means server")
	_check("clients_start", client_a.start(PEER_A) and client_b.start(PEER_B), "two clients")
	for world in [server, client_a, client_b]:
		_build_world(world)

	# NO add_client(). Registering a client by hand and then pushing updates at it before
	# it has handshaked is a hard crash inside sync: the client has no session to decode
	# against. The client introduces itself; the server accepts by default.
	_advance(90)

	var id_a: int = client_a.local_client_id()
	var id_b: int = client_b.local_client_id()
	_check("both_clients_handshook", server.connected_clients().size() == 2,
		"server sees %s" % [server.connected_clients()])
	_check("clients_were_assigned_ids", id_a > 0 and id_b > 0 and id_a != id_b,
		"a=%d b=%d" % [id_a, id_b])
	# WHICH CLIENT CAME IN ON WHICH PEER, from the server and not from anybody's word for it. The host
	# needs it to remove a client whose socket closed, and it used to be a Godot RPC in which each joiner
	# announced its own id. A peer nobody arrived on is 0.
	var mapped: bool = server.has_method("client_of_peer")
	_check("the_server_knows_which_client_came_in_on_which_peer",
		mapped and int(server.client_of_peer(PEER_A)) == id_a and int(server.client_of_peer(PEER_B)) == id_b
			and int(server.client_of_peer(99)) == 0,
		"peer %d -> %s, peer %d -> %s, peer 99 -> %s" % [PEER_A,
			server.client_of_peer(PEER_A) if mapped else "not bound", PEER_B,
			server.client_of_peer(PEER_B) if mapped else "not bound",
			server.client_of_peer(99) if mapped else "not bound"])
	if id_a <= 0 or id_b <= 0:
		_finish()
		return

	# ---- every player is in a vehicle, from the moment they exist --------------------
	# NO CRASH RULE (lane/combat): this aeroplane is dropped from 40 m into a world with no ground, to be flown by two sticks
	# while it falls, and an empty world's sea has no floor -- judged, it is a wreck before the sticks are tried.
	if server.has_method("set_crashes"):
		server.set_crashes(false)
	var a: Dictionary = server.spawn_pilot(id_a, PLANE, Vector3(0.0, 40.0, 0.0), 0.0)
	var b: Dictionary = server.spawn_pilot(id_b, POD, Vector3(30.0, 40.0, 0.0), 0.0)
	_check("pilots_spawned_in_vehicles",
		int(a.get("pilot", 0)) != 0 and int(a.get("vehicle", 0)) != 0
			and int(b.get("pilot", 0)) != 0,
		"A pilot %s in vehicle %s" % [a.get("pilot", 0), a.get("vehicle", 0)])
	_check("the_pilot_is_in_seat_zero",
		int(server.vehicle_seats(int(a["vehicle"]))[0]) == id_a,
		"seats %s" % [server.vehicle_seats(int(a["vehicle"]))])

	_advance(60, _controls(), _controls())
	_check("both_vehicles_reached_both_clients",
		client_a.vehicle_states().size() == 2 and client_b.vehicle_states().size() == 2,
		"A sees %d, B sees %d" % [client_a.vehicle_states().size(),
			client_b.vehicle_states().size()])
	_check("both_pilots_reached_both_clients",
		client_a.pilot_states().size() == 2 and client_b.pilot_states().size() == 2,
		"A sees %d pilot(s)" % client_a.pilot_states().size())

	# ---- 1. a pilot has no world pose ------------------------------------------------
	#
	# Not "the world pose is correct" -- there is no world pose to be correct. Everything
	# a pilot publishes is inside their seat, which is what makes their view unshakeable
	# at any speed: there is no second position to arrive late or disagree.
	var sample: Dictionary = client_b.pilot_states()[0]
	_check("a_pilot_publishes_only_seat_local_poses",
		not sample.has("position") and sample.has("head") and sample.has("vehicle"),
		"keys are %s" % [sample.keys()])

	# ---- 2. THE PROMISE: a still hand is still, at speed ------------------------------
	#
	# A's hands are held at a fixed seat-local pose while the aircraft accelerates from
	# rest to whatever full throttle gives it. Watched from B, over the wire, through
	# buffered interpolation. If a pilot's pose were composed into world space anywhere,
	# this is where it would shake.
	var held_left := Vector3(-0.22, -0.30, -0.44)
	var held_right := Vector3(0.31, -0.28, -0.36)
	var flying: Dictionary = _controls({
		"throttle": 1.0, "left": held_left, "right": held_right})
	_advance(30, flying, _controls())

	var seen: Array[Vector3] = []
	var speeds: Array[float] = []
	for i in range(180):
		_advance(1, flying, _controls())
		var them: Dictionary = _pilot_of(client_b, id_a)
		if not them.is_empty():
			seen.append(them.get("left", Vector3.ZERO))
		var craft: Dictionary = _vehicle_of(client_b, PLANE)
		if not craft.is_empty():
			speeds.append((craft.get("velocity", Vector3.ZERO) as Vector3).length())

	var fastest: float = 0.0
	for speed in speeds:
		fastest = maxf(fastest, speed)
	var wobble: float = 0.0
	for pose in seen:
		wobble = maxf(wobble, pose.distance_to(held_left))
	_check("the_aircraft_got_moving", fastest > 25.0, "reached %.1f m/s" % fastest)
	# 2 mm is the quantiser step for a hand offset, so this is "exact to the wire's
	# resolution". Not "close enough": there is nothing in the model that could add more.
	_check("a_still_hand_is_still_at_speed", wobble <= 0.003,
		"hand moved %.5f m in the seat while doing %.0f m/s" % [wobble, fastest])

	# ---- 3. prediction: the stick answers before the link could carry it --------------
	# OFF ITS WHEELS FIRST. On the ground the stick is nothing (`steer_on_the_ground`), and the aeroplane is on the
	# ground until `ground_speed`, 62 m/s. At 44 kN it passed that inside section 2's 210 ticks; at the 20 kN a light
	# twin has had since lane/handling (2026-09-17) it was doing 58.8 and read 0.0 degrees of roll. What this section
	# holds is prediction in the air, so the aeroplane is given the air to do it in.
	_advance(90, flying, _controls())
	var before: Quaternion = _vehicle_of(client_a, PLANE).get("basis", Quaternion.IDENTITY)
	_advance(LINK_DELAY_TICKS - 1, _controls({"throttle": 1.0, "roll": 1.0,
		"left": held_left, "right": held_right}), _controls())
	var after: Quaternion = _vehicle_of(client_a, PLANE).get("basis", Quaternion.IDENTITY)
	_check("the_stick_answers_immediately", before.angle_to(after) > 0.02,
		"%.1f degrees of roll in %d ticks, before the server could reply"
			% [rad_to_deg(before.angle_to(after)), LINK_DELAY_TICKS - 1])

	# ---- 4. and everybody else sees it ------------------------------------------------
	_advance(90, _controls({"throttle": 1.0, "roll": 1.0,
		"left": held_left, "right": held_right}), _controls())
	var mine: Quaternion = _vehicle_of(client_a, PLANE).get("basis", Quaternion.IDENTITY)
	var theirs: Quaternion = _vehicle_of(client_b, PLANE).get("basis", Quaternion.IDENTITY)
	_check("the_bank_reached_the_other_client",
		theirs.angle_to(Quaternion.IDENTITY) > 0.3 and theirs.angle_to(mine) < 1.0,
		"B sees %.0f degrees, A sees %.0f" % [rad_to_deg(theirs.angle_to(Quaternion.IDENTITY)),
			rad_to_deg(mine.angle_to(Quaternion.IDENTITY))])

	var resims: Dictionary = client_a.resim_stats()
	_check("prediction_settles", int(resims.get("count", 0)) < _tick / 6,
		"%d rollbacks over %d ticks" % [int(resims.get("count", 0)), _tick])

	# ---- 5. one button per question --------------------------------------------------
	#
	# The seat button walks the seats of the craft you are ALREADY IN, and does nothing
	# else. Choosing the craft is the other button's job. The version before this searched
	# neighbouring vehicles for a free seat within four metres, so it changed seat or
	# changed aircraft depending on what happened to be parked nearby.
	#
	# A pilot is ALWAYS in a seat: there is no on-foot state to fall out into, so with
	# nowhere to go it leaves them exactly where they were rather than nowhere.
	var cabin: int = int(a["vehicle"])
	_check("every_craft_carries_a_crew", server.vehicle_seats(cabin).size() >= 4,
		"the aeroplane has %d seats" % server.vehicle_seats(cabin).size())
	_advance(2, _controls({"buttons": SEAT}), _controls())
	_advance(40, _controls(), _controls())
	var moved_up: PackedInt64Array = server.vehicle_seats(cabin)
	_check("the_seat_button_walks_the_seats_of_this_craft",
		int(moved_up[0]) == -1 and int(moved_up[1]) == id_a,
		"seat 0 empty, A now in seat 1: %s" % [moved_up])
	_check("and_never_leaves_the_craft",
		int(_pilot_of(server, id_a).get("vehicle", 0)) == cabin,
		"still in vehicle %d" % int(_pilot_of(server, id_a).get("vehicle", 0)))

	# Round the houses and back to the front, because it wraps.
	for lap in range(3):
		_advance(2, _controls({"buttons": SEAT}), _controls())
		_advance(20, _controls(), _controls())
	_advance(30, _controls(), _controls())
	var wrapped: PackedInt64Array = server.vehicle_seats(cabin)
	_check("the_seats_wrap_round_to_the_front", int(wrapped[0]) == id_a,
		"back in the pilot's seat: %s" % [wrapped])

	_test_every_button_crosses_the_wire(int(a["pilot"]), cabin)
	_test_the_missile_table()
	_test_control_signs()
	_test_movement_models()
	_test_the_flight_path_follows_the_nose()
	_test_the_brake_reaches_zero()
	_test_the_car_and_the_boat()
	_test_taking_command_of_the_next_machine()
	_test_only_the_crew_see_the_cockpit()
	_test_two_players_in_one_craft()
	_test_taking_over_an_autopilot()
	_test_a_flight_holds_its_slots()
	_test_the_command_bus()
	_test_the_master_arm_is_the_crafts()
	_test_two_sets_of_controls()
	_test_driving_a_train()
	_test_a_gunner_works_their_own_gun()
	# NEAR THE END, because it leaves a launcher flying at a hill it builds; the missiles use a
	# launcher of their own, a long way from it.
	_test_the_seekers()
	_test_the_missiles()
	# LAST, because it replaces client A's pilot twice.
	_test_every_command_arrives()
	# AFTER EVERYTHING, because it spawns and despawns a score of machines. Run beside the brake
	# test, the crew tests further down lost four checks: their pods get three presses of "take
	# the next craft", which walks the machines in entity order, and twenty entities made and
	# destroyed ahead of them moved the aeroplane they were aiming for out of reach.
	_test_an_aeroplane_on_the_ground()
	# AND LAST OF ALL, because it takes client A out of whatever it was flying and puts it in a
	# helicopter's door.
	_test_a_held_trigger_fires_at_the_guns_rate_over_the_wire()
	_what_full_auto_costs_the_wire()
	_finish()


## ---- what full-auto fire costs the wire ----------------------------------------------------
##
## A PROBE, NOT A CHECK: numbers for whoever is looking at sync's per-tick send budget
## (`bandwidth_limit_bytes_per_tick`, 1024). A round is a replicated birth record and its
## impact, so a sustained stream of them is a sustained stream of entity creations on every
## client's packet. Three door guns firing at once -- client A's over the wire and two more
## worked on the server -- then, where the library has them, the same with a gunboat's two
## rail guns in place of the second helicopter. Bytes the server sends client A per tick, over
## three seconds quiet and three firing; and how many ticks sat at the budget.
func _what_full_auto_costs_the_wire() -> void:
	var second: Dictionary = server.spawn_pilot(_spare_client(), HELI, Vector3(2640.0, 400.0, 2600.0),
		0.0, Vector3.ZERO)
	_probe_three_guns("three_door_guns", int(second.get("vehicle", 0)), 2)
	const GUNBOAT: int = 9
	if bool(server.gun_schema(GUNBOAT, 0).get("fitted", false)):
		var boat: Dictionary = server.spawn_pilot(_spare_client(), GUNBOAT, Vector3(2700.0, 1.0, 2600.0),
			0.0, Vector3.ZERO)
		_probe_three_guns("a_door_gun_and_two_ship_guns", int(boat.get("vehicle", 0)), 1)
	else:
		print("[cockpit] wire probe: this library has no ship guns; only the door guns were measured")


func _probe_three_guns(called: String, craft: int, first_seat: int) -> void:
	var gunners: Array = []
	for seat in [first_seat, first_seat + 1]:
		var gunner: Dictionary = server.spawn_pilot(_spare_client(), POD, Vector3(2800.0, 60.0, 2800.0),
			0.0, Vector3.ZERO)
		server.seat_client(_client_of(gunner), craft, seat)
		gunners.append(gunner)
	_advance(LINK_DELAY_TICKS * 2 + 30, _controls(), _controls())
	var quiet: Dictionary = _bytes_to_a_over(180, _controls())
	for gunner in gunners:
		_seat_input(gunner, {"trigger": 1.0, "buttons": FIRE})
	var seen: Dictionary = {}
	for row in server.shot_states():
		seen[int(row["entity"])] = true
	var firing: Dictionary = _bytes_to_a_over(180, _controls({"trigger": 1.0, "buttons": FIRE}), seen)
	for gunner in gunners:
		_seat_input(gunner, {})
	_advance(LINK_DELAY_TICKS * 2 + 60, _controls(), _controls())
	print("[cockpit] wire probe %s: quiet mean %.0f max %d bytes/tick, %d ticks at >= 1024 | firing mean %.0f max %d bytes/tick, %d ticks at >= 1024, %d rounds in %.1f s | client A was handed %d of them, %.1f ticks after the server made them on average, %d at worst (the link is %d) | server out %s bytes/s"
		% [called, quiet["mean"], quiet["max"], quiet["at_budget"], firing["mean"], firing["max"],
			firing["at_budget"], firing["rounds"], 180.0 * DT, firing["delivered"], firing["late_mean"],
			firing["late_worst"], LINK_DELAY_TICKS, server.net_status().get("bytes_out_per_second", "?")])


## Bytes the server sent client A each tick over `ticks`, with A holding `input`: mean, max, ticks at
## the budget, rounds born (counted against `seen`), and how many of those rounds client A was handed
## and how many ticks after the server made them.
##
## A ROUND IS MATCHED ACROSS THE TWO WORLDS BY WHERE IT LEFT THE MUZZLE, because entity numbers are
## each world's own. The birth record is quantised on the wire, so "the same round" is the nearest
## client row within half a metre of the same muzzle with the same ammunition. When the per-tick
## budget is already full, what a stream of rounds costs is not bytes -- a tick cannot send more than
## the budget -- but how long a birth record waits for room.
func _bytes_to_a_over(ticks: int, input: Dictionary, seen: Dictionary = {}) -> Dictionary:
	var total: int = 0
	var most: int = 0
	var at_budget: int = 0
	var rounds: int = 0
	var waiting: Array = []
	var claimed: Dictionary = {}
	for row in client_a.shot_states():
		claimed[int(row["entity"])] = true
	var delivered: int = 0
	var late_total: int = 0
	var late_worst: int = 0
	for i in range(ticks + LINK_DELAY_TICKS * 4 + 60):
		var firing: bool = i < ticks
		_advance(1, input if firing else _controls(), _controls())
		var sent: int = int(_sent_to.get(PEER_A, 0))
		if firing:
			total += sent
			most = maxi(most, sent)
			if sent >= 1024:
				at_budget += 1
			for row in server.shot_states():
				var entity: int = int(row["entity"])
				if not seen.has(entity):
					seen[entity] = true
					rounds += 1
					waiting.append({"from": row["from"], "ammo": int(row["ammo"]), "made": _tick})
		for row in client_a.shot_states():
			var there: int = int(row["entity"])
			if claimed.has(there):
				continue
			for w in range(waiting.size()):
				var round_now: Dictionary = waiting[w]
				if int(round_now["ammo"]) == int(row["ammo"]) \
						and (round_now["from"] as Vector3).distance_to(row["from"] as Vector3) < 0.5:
					claimed[there] = true
					var late: int = _tick - int(round_now["made"])
					delivered += 1
					late_total += late
					late_worst = maxi(late_worst, late)
					waiting.remove_at(w)
					break
	return {"mean": float(total) / float(ticks), "max": most, "at_budget": at_budget, "rounds": rounds,
		"delivered": delivered, "late_mean": float(late_total) / float(maxi(delivered, 1)),
		"late_worst": late_worst}


## ---- a held trigger, over the wire ------------------------------------------------------
##
## THE TRIGGER IS A LEVEL, AND IT HAS TO SURVIVE THE LINK. Client A takes a helicopter's left
## door gun and holds the trigger for three seconds over the delayed link; what is counted is
## the SERVER's own rounds that name client A as their shooter. Sync sends each input frame more
## than once and reuses the last one when a frame is late, so a trigger read as an edge
## anywhere on that path is a gun that fires once, or once per copy; read as a level it is the
## gun's rate. And letting go has to be seen too, or the count would pass on a bit stuck high.
func _test_a_held_trigger_fires_at_the_guns_rate_over_the_wire() -> void:
	var door: Dictionary = server.spawn_pilot(_spare_client(), HELI, Vector3(2600.0, 400.0, 2600.0),
		0.0, Vector3.ZERO)
	var heli: int = int(door.get("vehicle", 0))
	_check("client_a_takes_a_door_gun", heli != 0 and server.seat_client(PEER_A, heli, 2),
		"seat 2 of %d" % heli)
	_advance(LINK_DELAY_TICKS * 2 + 6, _controls(), _controls())
	var reload: float = float(server.gun_schema(HELI, 0).get("reload", 1.0))
	var seen: Dictionary = {}
	for row in server.shot_states():
		seen[int(row["entity"])] = true
	var held: Dictionary = _controls({"trigger": 1.0, "buttons": FIRE})
	var ticks: int = int(3.0 / DT)
	var rounds: int = 0
	for i in range(ticks):
		_advance(1, held, _controls())
		rounds += _new_rounds_by(PEER_A, seen)
	var wanted: float = float(ticks) * DT / reload
	_check("a_trigger_held_over_the_link_fires_the_guns_rate", absf(float(rounds) - wanted) <= 1.5,
		"%d rounds in %.1f s, wanted %.1f" % [rounds, float(ticks) * DT, wanted])
	var after: int = 0
	var late: int = 0
	for i in range(LINK_DELAY_TICKS * 2 + int(reload / DT) + 40):
		_advance(1, _controls(), _controls())
		var fresh: int = _new_rounds_by(PEER_A, seen)
		after += fresh
		if i > LINK_DELAY_TICKS * 2 + int(reload / DT) + 2:
			late += fresh
	_check("and_letting_go_over_the_link_stops_it", late == 0 and after <= 2,
		"%d rounds in the link's delay and one reload after letting go, %d after that" % [after - late, late])


func _new_rounds_by(client: int, seen: Dictionary) -> int:
	var count: int = 0
	for row in server.shot_states():
		var entity: int = int(row["entity"])
		if seen.has(entity):
			continue
		seen[entity] = true
		if int(row.get("shooter", -1)) == client:
			count += 1
	return count


## ---- every command a client sends reaches the craft, in order, once -------------------------
##
## A command rides on the input frame, and the library used to hold ONE: a second send in the
## same frame overwrote the first, and four wrapped its two-bit sequence back to where the
## server already was, so none arrived. A new pilot for the same client also started the
## server's count at 0, so the last command the client ever sent was applied again to a craft
## it had never touched. Each check here was run red on that library first.
func _test_every_command_arrives() -> void:
	var id_a: int = client_a.local_client_id()
	var flying: Dictionary = _controls({"throttle": 1.0})
	var craft: int = int(_pilot_of(server, id_a).get("vehicle", 0))
	if craft == 0 or int(_pilot_of(server, id_a).get("seat", -1)) != 0:
		_check("a_pilot_is_flying_something_to_command", false, "pilot %s" % [_pilot_of(server, id_a)])
		return

	# (a) FIVE CHANNELS IN ONE FRAME, each reaching the craft, in the order they were sent.
	var burst: Array = _five_switches(server.craft_systems(craft))
	for command in burst:
		client_a.send_command(int(command["channel"]), int(command["value"]))
	var landed: Array = _when_each_lands(craft, burst, 180, flying)
	_check("five_commands_sent_on_one_frame_all_reach_the_craft_in_order", _in_order(landed),
		"ticks each landed on, in the order sent (-1 never): %s" % [landed])

	# (b) ONE COMMAND A FRAME OVER A LINK THAT BUNCHES FRAMES, which is what a queue of one command
	# per tick produces. With A's frames handed over two at a time the server takes the newer of
	# each pair and skips the other, so a command that rode one frame is lost every other time; a
	# command that rides its own frames for `kCommandRideSeconds` is not. Three at a time is
	# printed beside it, to show where two frames of riding at 60 Hz stop being enough.
	for bunch in [2, 3]:
		var here: int = int(_pilot_of(server, id_a).get("vehicle", 0))
		var one_a_frame: Array = _five_switches(server.craft_systems(here))
		_client_release_every = bunch
		_advance(40, flying, _controls())
		var arrived: Array = _one_a_tick_and_watch(here, one_a_frame, 240, flying)
		_client_release_every = 1
		_advance(40, flying, _controls())
		if bunch == 2:
			_check("one_command_a_frame_over_a_link_that_bunches_frames_all_reach_the_craft",
				_in_order(arrived), "frames handed over two at a time; ticks each landed on: %s" % [arrived])
		else:
			print("[cockpit] NOTE frames handed over three at a time; ticks each landed on: %s" % [arrived])

	# (e) TWO QUICK PRESSES OF A BUTTON THAT TOGGLES ARE TWO COMMANDS. The crew button flips the
	# crew light on receipt, so it is never folded into one the way a lever's positions are: two
	# presses on one frame flip it twice, and it ends where it started.
	var crew_light_was: bool = bool(server.craft_systems(craft).get("crew_light", false))
	client_a.send_command(CHANNEL_CREW_TOGGLE, 0)
	client_a.send_command(CHANNEL_CREW_TOGGLE, 0)
	var flips: int = 0
	var shown: bool = crew_light_was
	for i in range(120):
		_advance(1, flying, _controls())
		var now_lit: bool = bool(server.craft_systems(craft).get("crew_light", false))
		if now_lit != shown:
			flips += 1
			shown = now_lit
	_check("two_quick_presses_of_a_button_that_toggles_are_two_toggles",
		flips == 2 and shown == crew_light_was,
		"the crew light flipped %d time(s), from %s to %s" % [flips, crew_light_was, shown])

	# (d) A FULL QUEUE REFUSES, AND KEEPS WHAT IT ALREADY HAD. Four more different channels than the queue holds, on one
	# frame: the first `queue_cap` are taken, the last four refused. Gear and flaps are among the first four, so a queue
	# that dropped its OLDEST to make room would leave the gear up. THE CAP IS THE LIBRARY'S, read through `bus_limits`:
	# it was sixteen, every channel the bus had, and is a panel's worth since the generic channels (busbits, 2026-09-18).
	var limits: Dictionary = ClassDB.class_call_static(&"CockpitWorld", &"bus_limits")
	var cap: int = int(limits.get("queue_cap", 16))
	var accepted: Array = []
	var wanted: Dictionary = {1: 3, 3: 1, 9: 5, 10: 2}
	for channel in range(cap + 4):
		# THROUGH call(), so a send_command that returns nothing reads as null here and fails
		# the check below, rather than stopping the script.
		accepted.append(client_a.call("send_command", channel, int(wanted.get(channel, 0))))
	var took_first: bool = true
	for i in range(cap):
		took_first = took_first and accepted[i] is bool and bool(accepted[i])
	var refused_rest: bool = true
	for i in range(cap, cap + 4):
		refused_rest = refused_rest and accepted[i] is bool and not bool(accepted[i])
	_check("a_command_past_the_queue_cap_is_refused", took_first and refused_rest,
		"cap %d; send_command took the first %s and answered %s past it" % [cap, took_first, str(accepted.slice(cap))])
	# AND THE WHOLE QUEUE DRAINS before anything else is asked of it: one command a ride, so the checks below are not
	# waiting behind five hundred of these.
	var ride: int = maxi(1, int(ceil(float(limits.get("ride_seconds", 1.0 / 30.0)) * TICK_HZ - 1e-6)))
	_advance(maxi(240, cap * ride + 60), flying, _controls())
	var controls_now: Dictionary = server.craft_controls(craft)
	var systems_now: Dictionary = server.craft_systems(craft)
	_check("and_the_ones_it_kept_all_reach_the_craft",
		bool(controls_now.get("gear", false)) and float(controls_now.get("flaps", 0.0)) > 0.9
			and int(systems_now.get("radio", -1)) == 5 and int(systems_now.get("display", -1)) == 2,
		"gear %s, flaps %.2f, radio %s, display %s" % [controls_now.get("gear"),
			float(controls_now.get("flaps", 0.0)), systems_now.get("radio"), systems_now.get("display")])

	# (c) A NEW PILOT FOR THE SAME CLIENT IS NOT HANDED THE LAST COMMAND AGAIN. Twice, one more
	# command apart: a count that restarts at 0 misses the replay only when the client's own
	# count happens to be 0 too, and it cannot be 0 both times.
	var replayed: Array = []
	for attempt in range(2):
		var here: int = int(_pilot_of(server, id_a).get("vehicle", 0))
		client_a.send_command(CHANNEL_LIGHTS, 1)
		_advance(90, flying, _controls())
		var lit_before: bool = bool(server.craft_systems(here).get("lights", false))
		# THE PILOT THAT GOES, BY THE ENTITY ITS ROW NAMES: a `pilot_states()` row calls it `entity`. A respawn that did not
		# happen -- the old pilot left in the world beside a new one -- is not the case this check is about.
		var old_pilot: int = int(_pilot_of(server, id_a).get("entity", 0))
		server.despawn_pilot(old_pilot)
		_advance(20, flying, _controls())
		var old_gone: bool = true
		for row in server.pilot_states():
			if int((row as Dictionary).get("entity", 0)) == old_pilot:
				old_gone = false
		var made: Dictionary = server.spawn_pilot(id_a, PLANE,
			Vector3(9000.0 + 400.0 * attempt, 900.0, 9000.0), 0.0, Vector3(0.0, 0.0, -60.0))
		var fresh: int = int(made.get("vehicle", 0))
		_advance(180, flying, _controls())
		replayed.append({"lit_before": lit_before, "fresh": fresh,
			"fresh_lit": bool(server.craft_systems(fresh).get("lights", true)),
			"old_pilot": old_pilot, "old_gone": old_gone, "new_pilot": int(made.get("pilot", 0))})
	var none_replayed: bool = true
	for attempt in replayed:
		none_replayed = none_replayed and bool(attempt["lit_before"]) and int(attempt["fresh"]) != 0 \
			and not bool(attempt["fresh_lit"]) and int(attempt["old_pilot"]) != 0 and bool(attempt["old_gone"]) \
			and int(attempt["new_pilot"]) != 0 and int(attempt["new_pilot"]) != int(attempt["old_pilot"])
	_check("a_new_pilot_for_the_same_client_is_not_handed_the_last_command_again", none_replayed,
		"two respawns after a lights-on: %s" % [replayed])


## Five system switches, each moved to a value it does not have now.
func _five_switches(systems: Dictionary) -> Array:
	return [
		{"channel": WEAPON, "key": "weapon", "value": (int(systems.get("weapon", 0)) + 1) % 4},
		{"channel": 9, "key": "radio", "value": (int(systems.get("radio", 0)) + 1) % 16},
		{"channel": 10, "key": "display", "value": (int(systems.get("display", 0)) + 1) % 6},
		{"channel": CHANNEL_LIGHTS, "key": "lights", "value": 0 if bool(systems.get("lights", false)) else 1},
		{"channel": MASTER, "key": "master", "value": 0 if bool(systems.get("master", false)) else 1},
	]


## The tick on which each command's value first shows on the server's craft, in the order given;
## -1 for one that never did within `ticks`.
func _when_each_lands(craft: int, commands: Array, ticks: int, input: Dictionary) -> Array:
	var landed: Array = []
	for command in commands:
		landed.append(-1)
	for i in range(ticks):
		_advance(1, input, _controls())
		var systems: Dictionary = server.craft_systems(craft)
		for c in range(commands.size()):
			if int(landed[c]) >= 0:
				continue
			var now = systems.get(String(commands[c]["key"]))
			var value: int = int(now) if not (now is bool) else (1 if bool(now) else 0)
			if value == int(commands[c]["value"]):
				landed[c] = _tick
	return landed


## Client A sends the commands one a tick, from the first tick, while the server's craft is watched;
## the tick each value first shows, in the order given, -1 for one that never did within `ticks`.
func _one_a_tick_and_watch(craft: int, commands: Array, ticks: int, input: Dictionary) -> Array:
	var landed: Array = []
	for command in commands:
		landed.append(-1)
	for i in range(ticks):
		if i < commands.size():
			client_a.send_command(int(commands[i]["channel"]), int(commands[i]["value"]))
		_advance(1, input, _controls())
		var systems: Dictionary = server.craft_systems(craft)
		for c in range(commands.size()):
			if int(landed[c]) >= 0 or c > i:
				continue
			var now = systems.get(String(commands[c]["key"]))
			var value: int = int(now) if not (now is bool) else (1 if bool(now) else 0)
			if value == int(commands[c]["value"]):
				landed[c] = _tick
	return landed


## Every entry landed, and each no earlier than the one before it.
func _in_order(landed: Array) -> bool:
	for i in range(landed.size()):
		if int(landed[i]) < 0 or (i > 0 and int(landed[i]) < int(landed[i - 1])):
			return false
	return true


## ---- a gunner works THEIR gun, not whichever one is first ---------------------------
##
## A gunship carries three guns down its left side -- the 25 mm forward of the 40 mm forward
## of the 105 -- and a gun position for each, in that order. Which gun a seat works has to
## be a property of the SEAT and nothing else.
##
## It was not. The simulation counted the OCCUPIED turret seats ahead of this one, so a
## gunner sitting alone got mount 0 wherever they sat, and the gun under their hands changed
## the moment somebody else sat down in front of them. The cockpit counted POSITIONALLY when
## it fitted the sight, so the same lone gunner in the back watched the 105's reticle while
## traversing the 25 mm. From the cockpit both bugs look like one: every seat works the same
## gun.
##
## THE TEST SITS ONE GUNNER IN THE LAST SEAT, which is the case that told the two rules
## apart. Seat 3 of a gunship is the 105, and the 105 is mount 2.
func _test_a_gunner_works_their_own_gun() -> void:
	var ship: Dictionary = server.spawn_pilot(_spare_client(), GUNSHIP,
		Vector3(-3000.0, 900.0, -3000.0), 0.0, Vector3(0.0, 0.0, -110.0))
	var hull: int = int(ship.get("vehicle", 0))
	_check("a_gunship_is_flying", hull != 0, "entity %d" % hull)
	if hull == 0:
		return

	# THE RULE ITSELF, asked of the simulation -- which is what the cockpit now asks too,
	# instead of keeping a copy. Seat 0 flies and works no gun at all.
	var mounts: Array[int] = []
	for seat in range(4):
		mounts.append(int(server.seat_mount(GUNSHIP, seat)))
	_check("each_gun_position_names_its_own_mount", mounts == [-1, 0, 1, 2],
		"seats 0..3 work mounts %s" % [mounts])

	# ONE GUNNER, IN THE LAST SEAT, and nobody else aboard but the pilot.
	var gunner: Dictionary = server.spawn_pilot(_spare_client(), POD,
		Vector3(-3200.0, 60.0, -3200.0), 0.0, Vector3.ZERO)
	var who: int = _client_of(gunner)
	_check("and_a_gunner_took_the_last_of_them", server.seat_client(who, hull, 3),
		"client %d into seat 3 of %d" % [who, hull])
	_advance(20)

	var before: Array = server.vehicle_state(hull).get("turrets", []) as Array
	# HARD OVER FOR A SECOND AND A HALF. `roll` is what traverses a mount -- the same stick
	# that flies from the front seats -- and the gunship's guns train only a few degrees, so
	# this is long enough to hit the stop and no longer.
	_seat_input(gunner, {"roll": 1.0})
	_advance(90)
	_seat_input(gunner, {})
	var after: Array = server.vehicle_state(hull).get("turrets", []) as Array
	if before.size() < 3 or after.size() < 3:
		_check("the_gunship_reports_every_mount", false,
			"%d before, %d after" % [before.size(), after.size()])
		return

	var moved: Array[int] = []
	for mount in range(3):
		if absf(angle_difference((after[mount] as Vector2).x,
				(before[mount] as Vector2).x)) > 0.01:
			moved.append(mount)
	_check("a_gunner_in_the_last_seat_traverses_the_last_gun", moved == [2],
		"mounts that moved: %s" % [moved])
	# AND NOT THE FIRST ONE, which is the failure said out loud. It is the same fact as the
	# line above and it is worth its own name, because "moved == [2]" going red tells you
	# something is wrong and this tells you WHAT.
	_check("and_not_the_gun_at_the_front_of_the_hold", not moved.has(0),
		"the 25 mm %s" % ["moved" if moved.has(0) else "stayed where it was"])

	# AND IT STAYS THEIR GUN WHEN THE HOLD FILLS UP. Under the old rule this is where the
	# gun changed hands: a second gunner boarding ahead of them pushed this one along a
	# mount, mid-burst, with no way to tell from the cockpit.
	var mate: Dictionary = server.spawn_pilot(_spare_client(), POD,
		Vector3(-3400.0, 60.0, -3400.0), 0.0, Vector3.ZERO)
	server.seat_client(_client_of(mate), hull, 1)
	_advance(20)
	var settled: Array = server.vehicle_state(hull).get("turrets", []) as Array
	_seat_input(gunner, {"roll": -1.0})
	_advance(60)
	_seat_input(gunner, {})
	var again: Array = server.vehicle_state(hull).get("turrets", []) as Array
	var moved_now: Array[int] = []
	for mount in range(3):
		if absf(angle_difference((again[mount] as Vector2).x,
				(settled[mount] as Vector2).x)) > 0.01:
			moved_now.append(mount)
	_check("and_it_is_still_their_gun_when_the_hold_fills_up", moved_now == [2],
		"with a second gunner aboard, mounts that moved: %s" % [moved_now])


## ---- every button on the frame reaches the server ----------------------------------
##
## `ControlInput.buttons` is a byte in C++ and was SIX BITS on the wire, and a bit past the
## end of a field is not an error anybody sees: it is dropped on the way out. That is how the
## trigger once worked in every test that fired the gun on the server and did nothing when a
## player pulled it. Lock and launch are bits six and seven, so they would have gone the same
## way.
##
## DRIVEN THROUGH A REAL CLIENT, over the delayed link, and read back from what the SERVER's
## simulation saw -- `buttons_seen` -- rather than from what a button went on to do. Nothing
## reads these two bits yet; the check must not wait for something to.
##
## Held for a whole round trip and more, because sync sends each input frame more than once and
## a single-tick press proves less about the field than it does about the redundancy.
func _test_every_button_crosses_the_wire(pilot: int, cabin: int) -> void:
	var both: int = LOCK | LAUNCH
	var held: Dictionary = _controls({"buttons": both})
	_advance(LINK_DELAY_TICKS * 2 + 6, held, _controls())
	var seen: int = int(server.buttons_seen(pilot))
	_check("lock_and_launch_reach_the_server", (seen & both) == both,
		"sent %d, the server's simulation saw %d" % [both, seen])

	# AND THE FIELDS AFTER THEM STILL LINE UP. A serialiser and deserialiser that disagree
	# about the width shift everything read after it, and the command bus rides at the end of
	# the frame. This passes before the widening as well as after; it is here to fail if the
	# two halves are ever widened unequally.
	client_a.send_command(CHANNEL_LIGHTS, 1)
	_advance(LINK_DELAY_TICKS * 2 + 6, held, _controls())
	_check("and_the_bus_command_behind_them_still_arrives",
		bool(server.craft_systems(cabin).get("lights", false)),
		"lights on the server: %s" % [server.craft_systems(cabin).get("lights", false)])

	# AND LETTING GO IS SEEN TOO, or the first check would pass on a bit stuck high.
	client_a.send_command(CHANNEL_LIGHTS, 0)
	_advance(LINK_DELAY_TICKS * 2 + 6, _controls(), _controls())
	seen = int(server.buttons_seen(pilot))
	_check("and_letting_go_clears_them", (seen & both) == 0,
		"after release the server saw %d" % seen)


## ---- the missile table: read by the cockpit, never retyped ---------------------------
##
## A missile is a row, and the cockpit builds its switches and hangs its missiles from what
## the simulation says rather than from a copy. So what is checked is that the rows mean what
## they claim, that the aeroplane's stations can actually be SELECTED on its own bus, and that
## a misspelt key is refused rather than taken as absent -- the handling table's lesson.
func _test_the_missile_table() -> void:
	var rows: Dictionary = {}
	for row in server.missile_types():
		rows[String(row.get("name", ""))] = row
	_check("there_is_a_radar_missile_and_a_heat_seeker",
		rows.has("radar") and rows.has("heat")
			and String(rows["radar"].get("seeker_name", "")) == "radar"
			and String(rows["heat"].get("seeker_name", "")) == "heat",
		"rows %s" % [rows.keys()])
	if not (rows.has("radar") and rows.has("heat")):
		return
	# THE DIFFERENCE BETWEEN THEM IS BEHAVIOUR, not a label: a radar missile will not leave
	# without a lock and needs the launcher to keep it; a heat-seeker needs neither.
	_check("radar_needs_a_lock_and_heat_does_not",
		bool(rows["radar"]["needs_lock"]) and bool(rows["radar"]["semi_active"])
			and not bool(rows["heat"]["needs_lock"]) and not bool(rows["heat"]["semi_active"]),
		"radar %s/%s, heat %s/%s" % [rows["radar"]["needs_lock"], rows["radar"]["semi_active"],
			rows["heat"]["needs_lock"], rows["heat"]["semi_active"]])

	var plane: Dictionary = server.missile_schema(PLANE)
	var stations: Array = plane.get("stations", [])
	var names: Array = []
	for station in stations:
		names.append("%s x%d" % [station["name"], (station["pylon_ids"] as Array).size()])
	# AND THE MINIGUN AS A THIRD STATION ON NO RAILS (cockpit plan item 4): a gun on the same selector, after the
	# missiles so heat and radar keep their numbers.
	_check("the_plane_carries_heat_and_radar_on_two_rails_each",
		names == ["heat x2", "radar x2", "guns x0"], "stations %s" % [names])

	# EVERY STATION CAN BE SELECTED. The Weapon selector is how one is chosen, so a station
	# numbered past that channel's range on the plane's OWN bus is a missile nobody can pick.
	# Two tables, written separately, asked whether they agree.
	var weapon_range: int = -1
	for channel in server.craft_schema(PLANE).get("channels", []):
		if String(channel["name"]) == "weapon":
			weapon_range = int(channel["range"])
	var unreachable: Array = []
	for station in stations:
		if int(station["station"]) > weapon_range:
			unreachable.append(int(station["station"]))
	_check("every_station_is_on_the_weapon_selector",
		weapon_range >= 0 and unreachable.is_empty(),
		"weapon range %d, stations out of reach %s" % [weapon_range, unreachable])

	var owner: Dictionary = {}
	var shared: Array = []
	for station in stations:
		for id in station["pylon_ids"]:
			if owner.has(id):
				shared.append(id)
			owner[id] = true
	_check("no_rail_belongs_to_two_stations_and_none_is_left_over",
		shared.is_empty() and owner.size() == (plane.get("pylons", []) as Array).size(),
		"shared %s, %d of %d rails in a station" % [shared, owner.size(),
			(plane.get("pylons", []) as Array).size()])
	_check("the_two_pilots_launch_and_the_back_seats_do_not",
		plane.get("launch_seats", []) == [0, 1], "launch seats %s" % [plane.get("launch_seats")])
	var pod: Dictionary = server.missile_schema(POD)
	_check("a_pod_carries_nothing_and_nobody_in_it_launches",
		(pod.get("stations", []) as Array).is_empty()
			and (pod.get("launch_seats", []) as Array).is_empty(),
		"pod %s" % [pod])

	# EVERY KEY READS BACK AS SENT. Each one is moved to a value it did not have, all at once,
	# so two keys wired to the same field -- the later write clobbering the earlier -- show as
	# a key that did not take.
	var radar_id: int = int(rows["radar"]["id"])
	var original: Dictionary = server.missile_type(radar_id)
	var wanted: Dictionary = {}
	for key in original:
		if key in ["id", "name", "seeker_name"]:
			continue
		var value = original[key]
		if value is bool:
			wanted[key] = not value
		elif key == "seeker":
			wanted[key] = 1 - int(value)
		else:
			wanted[key] = float(value) + 1.25
	var accepted: bool = server.set_missile_type(radar_id, wanted)
	var now: Dictionary = server.missile_type(radar_id)
	var wrong: Array = []
	for key in wanted:
		var sent = wanted[key]
		var took: bool = (now.get(key) == sent) if (sent is bool or key == "seeker") \
			else is_equal_approx(float(now.get(key, -1.0)), float(sent))
		if not took:
			wrong.append(key)
	# The keys the cockpit's own note names, so a reader that quietly lost them fails here
	# rather than passing over an empty row.
	var named: bool = wanted.has("burn_s") and wanted.has("nav_gain") and wanted.has("fuse_m") \
		and wanted.has("turn_g") and wanted.has("cone") and wanted.has("lock_s")
	_check("every_missile_key_reads_back_as_sent", accepted and named and wrong.is_empty(),
		"accepted %s, %d keys, did not take: %s" % [accepted, wanted.size(), wrong])

	# AND A MISSPELT ONE IS REFUSED, WITH NOTHING APPLIED. The good key beside it must not
	# land either: a row that is half what was asked for says nothing about which half.
	var gain: float = float(server.missile_type(radar_id)["nav_gain"])
	var refused: bool = not server.set_missile_type(radar_id,
		{"nav_gain": gain + 2.0, "nav_gian": 9.0})
	var kept: bool = is_equal_approx(float(server.missile_type(radar_id)["nav_gain"]), gain)
	_check("a_misspelt_missile_key_is_refused_and_nothing_applies", refused and kept,
		"refused %s, nav_gain %s -> %s" % [refused, gain, server.missile_type(radar_id)["nav_gain"]])

	var restore: Dictionary = original.duplicate()
	for key in ["id", "name", "seeker_name"]:
		restore.erase(key)
	_check("and_the_row_goes_back_to_how_it_was",
		server.set_missile_type(radar_id, restore) and server.missile_type(radar_id) == original,
		"row %s" % [server.missile_type(radar_id)])


## ---- a seat locks what its seeker can see -------------------------------------------
##
## Everything is driven the way a pilot drives it: the station and the master arm are bus
## commands sent from client A, and every LOCK is the button bit on A's own input frame, over
## the delayed link. The simulation picks the target; the test only puts aircraft where a
## seeker should, or should not, be able to see them, and asks which one it took.
##
## THE TARGET IS AN ENTITY REFERENCE, so the checks that read a client's lock compare against
## THAT CLIENT's id for the target -- and first check that its id and the server's differ,
## because a leaked server id would otherwise pass by coincidence.
func _test_the_seekers() -> void:
	var id_a: int = client_a.local_client_id()
	var mine: int = int(server.spawn_vehicle(PLANE, Vector3(12000.0, 900.0, 12000.0), 0.0,
		Vector3(0.0, 0.0, -60.0)))
	var seated: bool = mine != 0 and server.seat_client(id_a, mine, 0)
	_check("a_launcher_is_flying_with_client_a_at_the_controls", seated,
		"plane %d, client %d in seat 0" % [mine, id_a])
	if not seated:
		return
	var flying: Dictionary = _controls({"throttle": 1.0})
	var pressing: Dictionary = _controls({"throttle": 1.0, "buttons": LOCK})
	_advance(30, flying, _controls())
	var radar: int = _station_named("radar")
	var heat: int = _station_named("heat")

	# ---- the station and the master arm, as switches ---------------------------------
	client_a.send_command(WEAPON, radar)
	_advance(12, flying, _controls())
	var row: Dictionary = _lock_row(server, id_a)
	_check("an_unarmed_seat_says_so",
		int(row.get("why", -1)) == WHY_NOT_ARMED and String(row.get("type_name", "")) == "radar",
		"row %s" % [row])
	client_a.send_command(MASTER, 1)
	_advance(12, flying, _controls())
	row = _lock_row(server, id_a)
	_check("armed_a_radar_missile_still_waits_for_a_lock",
		int(row.get("why", -1)) == WHY_NO_LOCK and not bool(row.get("can_launch", true)),
		"row %s" % [row])

	# ---- a lock, taken by the button ---------------------------------------------------
	var first: Dictionary = _spawn_ahead(mine, 1500.0, 0.0, false, PLANE, true)
	var hull: int = int(first.get("vehicle", 0))
	_advance(10, flying, _controls())
	_advance(2, pressing, _controls())
	var locking_at: int = -1
	var locked_at: int = -1
	var designated: int = 0
	for i in range(240):
		_advance(1, flying, _controls())
		row = _lock_row(server, id_a)
		if locking_at < 0 and int(row.get("phase", -1)) == SEEKER_LOCKING:
			locking_at = _tick
			designated = int(row.get("target", 0))
		if int(row.get("phase", -1)) == SEEKER_LOCKED:
			locked_at = _tick
			break
	_check("the_lock_press_crosses_the_wire_and_designates_what_is_ahead",
		locking_at > 0 and designated == hull,
		"designated %d; the aircraft ahead is %d" % [designated, hull])
	var lock_ticks: float = float(server.missile_type(_type_named("radar"))["lock_s"]) / DT
	var took: int = locked_at - locking_at
	_check("a_lock_takes_lock_s",
		locked_at > 0 and took >= int(lock_ticks) - 1 and took <= int(lock_ticks) + 2,
		"LOCKING to LOCKED in %d ticks against %.1f" % [took, lock_ticks])
	row = _lock_row(server, id_a)
	_check("locked_and_armed_it_may_launch",
		bool(row.get("can_launch", false)) and int(row.get("why", -1)) == WHY_READY,
		"row %s" % [row])

	# ---- and client A sees it, in its own numbers ----------------------------------------
	_advance(LINK_DELAY_TICKS * 2 + 8, flying, _controls())
	var theirs: int = _same_vehicle_on(client_a, hull)
	_check("the_server_and_client_a_number_the_target_differently",
		theirs != 0 and theirs != hull, "server %d, client_a %d" % [hull, theirs])
	var seen: Dictionary = _lock_row(client_a, id_a)
	_check("client_a_sees_the_lock_on_its_own_id_for_the_target",
		int(seen.get("phase", -1)) == SEEKER_LOCKED and int(seen.get("target", 0)) == theirs,
		"row %s; client_a's id for the target %d" % [seen, theirs])
	var bearing: Vector3 = seen.get("bearing", Vector3.ZERO)
	var distance: float = float(seen.get("range", -1.0))
	_check("and_bearing_and_range_come_from_what_it_draws",
		bearing.dot(Vector3.FORWARD) > 0.99 and absf(distance - 1500.0) < 120.0,
		"bearing %s, range %.0f m" % [bearing, distance])

	# ---- a client that joins in the middle of a lock ------------------------------------
	#
	# PENDING ITSELF IS NOT FORCED: sync boosts a referenced entity's priority, so it arrives with the seeker.
	#
	# It is sent the world in pieces. sync raises the priority of an entity something else
	# refers to (ashiato-sync/src/server.cpp, `reference_priority_boost_pending`), so the
	# target's ENTITY arrives with the seeker -- but its COMPONENTS arrive a frame or two after
	# it. Measured on 2026-09-13, before the fix: client_c's first row named its own entity for
	# the target while that entity had no VehicleState and was not in client_c's
	# vehicle_states(). That is this check's first failure, and lock_states() now reads such a
	# target as none. What is held: no row ever names an id that is not a vehicle on this
	# world, or carries a bearing with nothing to point at; and once client_c knows which
	# vehicle is the target, the row names it by client_c's own id. The unresolved branch is
	# also driven for certain below, by taking the target away.
	client_c = ClassDB.instantiate("CockpitWorld")
	client_c.set_tick_rate(TICK_HZ)
	client_c.start(PEER_C)
	_build_world(client_c)
	var rows_seen: int = 0
	var wrong_world: int = 0
	var pointed_at_nothing: int = 0
	var resolved: Dictionary = {}
	var their_id: int = 0
	for i in range(900):
		_advance(1, flying, _controls())
		var late: Dictionary = _lock_row(client_c, id_a)
		if late.is_empty():
			continue
		rows_seen += 1
		var named: int = int(late.get("target", 0))
		if named == 0:
			if late.has("bearing") or late.has("range"):
				pointed_at_nothing += 1
			continue
		if not _is_vehicle_on(client_c, named):
			wrong_world += 1
		their_id = _same_vehicle_on(client_c, hull)
		if their_id != 0:
			resolved = late
			break
	_check("a_late_joiner_never_sees_another_worlds_id_or_a_bearing_at_nothing",
		rows_seen > 0 and wrong_world == 0 and pointed_at_nothing == 0,
		"%d rows; %d named an entity client_c does not have, %d had a bearing with no target"
			% [rows_seen, wrong_world, pointed_at_nothing])
	_check("and_it_names_the_target_by_its_own_id",
		their_id != 0 and int(resolved.get("target", 0)) == their_id,
		"row %s; client_c's id for the target %d" % [resolved, their_id])
	# EVERY MACHINE KNOWS WHO CAME IN ON WHICH PEER, not only the host -- including those who were here first.
	# The Godot RPC this replaced announced each machine's id ONCE, as it arrived, so a machine that joined later never
	# heard from anybody already there, the host included (cockpit-steam, over a real socket). The peer rides the
	# pilot's replicated PilotOwner now, which every machine receives whenever it arrives.
	var b_id: int = client_b.local_client_id()
	var asks: bool = client_c.has_method("client_of_peer") and client_a.has_method("client_of_peer") \
		and client_c.has_method("peer_of_client")
	_check("a_late_joiner_resolves_everybody_who_was_there_before_it",
		asks and int(client_c.client_of_peer(PEER_A)) == id_a and int(client_c.client_of_peer(PEER_B)) == b_id
			and int(client_c.peer_of_client(id_a)) == PEER_A,
		"on the late joiner: peer %d -> %s, peer %d -> %s, client %d -> peer %s" % [PEER_A,
			client_c.client_of_peer(PEER_A) if asks else "not bound", PEER_B,
			client_c.client_of_peer(PEER_B) if asks else "not bound", id_a,
			client_c.peer_of_client(id_a) if asks else "not bound"])
	_check("and_an_earlier_machine_resolves_the_others",
		asks and int(client_a.client_of_peer(PEER_B)) == b_id and int(client_b.client_of_peer(PEER_A)) == id_a,
		"A reads peer %d -> %s, B reads peer %d -> %s" % [PEER_B,
			client_a.client_of_peer(PEER_B) if asks else "not bound", PEER_A,
			client_b.client_of_peer(PEER_A) if asks else "not bound"])
	# A MACHINE WITH NO PILOT OF ITS OWN still reads everybody else's peer off their pilots -- checked above -- and answers
	# 0, "cannot say", for itself, while every other machine answers 0 for it. client_c has joined and has never been given
	# a pilot, which is the desk, or the moment between the handshake and a seat.
	var c_id: int = client_c.local_client_id()
	_check("a_machine_with_no_pilot_says_it_cannot_resolve_itself",
		asks and int(client_c.peer_of_client(c_id)) == 0 and int(client_a.client_of_peer(PEER_C)) == 0
			and int(client_a.peer_of_client(c_id)) == 0,
		"C asks for its own peer: %s; A asks who came in on peer %d: %s, and client %d's peer: %s" % [
			client_c.peer_of_client(c_id) if asks else "not bound", PEER_C,
			client_a.client_of_peer(PEER_C) if asks else "not bound", c_id,
			client_a.peer_of_client(c_id) if asks else "not bound"])
	# GIVEN A PILOT, THE WIDEST PEER ID GOES ROUND THE WIRE WHOLE, to every other machine and back to itself.
	var c_pilot: Dictionary = server.spawn_pilot(c_id, POD, Vector3(-1500.0, 40.0, 1500.0), 0.0, Vector3.ZERO)
	var resolved_after: int = -1
	for i in range(240):
		_advance(1, flying, _controls())
		if asks and int(client_a.client_of_peer(PEER_C)) == c_id and int(client_c.peer_of_client(c_id)) == PEER_C:
			resolved_after = i + 1
			break
	_check("the_widest_peer_id_round_trips_the_wire",
		asks and resolved_after >= 0 and int(client_a.peer_of_client(c_id)) == PEER_C
			and int(client_b.client_of_peer(PEER_C)) == c_id and int(server.peer_of_client(c_id)) == PEER_C,
		"peer %d after %d ticks: A reads client %s and peer %s, B reads client %s, C reads its own peer %s" % [PEER_C,
			resolved_after, client_a.client_of_peer(PEER_C) if asks else "not bound",
			client_a.peer_of_client(c_id) if asks else "not bound",
			client_b.client_of_peer(PEER_C) if asks else "not bound",
			client_c.peer_of_client(c_id) if asks else "not bound"])
	server.despawn_pilot(int(c_pilot.get("pilot", 0)))
	_advance(LINK_DELAY_TICKS + 4, flying, _controls())
	var c_mapped: bool = server.has_method("client_of_peer") \
		and int(server.client_of_peer(PEER_C)) == client_c.local_client_id()
	server.remove_client(client_c.local_client_id())
	_check("a_late_joiner_is_known_by_its_peer_and_forgotten_when_removed",
		client_c.local_client_id() > 0 and c_mapped and int(server.client_of_peer(PEER_C)) == 0,
		"peer %d mapped to client %d before removal: %s; after: %s" % [PEER_C, client_c.local_client_id(), c_mapped,
			server.client_of_peer(PEER_C) if server.has_method("client_of_peer") else "not bound"])
	client_c.teardown()
	client_c = null

	# ---- a second press lets go ----------------------------------------------------------
	_advance(2, pressing, _controls())
	_advance(LINK_DELAY_TICKS + 4, flying, _controls())
	row = _lock_row(server, id_a)
	_check("a_second_press_lets_go",
		int(row.get("phase", -1)) == SEEKER_SEARCHING and int(row.get("target", -1)) == 0,
		"row %s" % [row])

	# ---- and a target that goes away is LOST, and reads as nothing ---------------------
	#
	# Taken again, then taken out of the world. The server must lose it after the grace, and
	# on client A the reference stops resolving: every row from then on either names a vehicle
	# A still has, or names nothing and carries no bearing and no range.
	row = _designate(id_a, pressing, flying)
	var retaken: bool = int(row.get("target", 0)) == hull
	_despawn_spawned(first)
	var lost_seen: bool = false
	var unresolved: int = 0
	var stale: int = 0
	for i in range(LINK_DELAY_TICKS * 2 + 60):
		_advance(1, flying, _controls())
		lost_seen = lost_seen or int(_lock_row(server, id_a).get("phase", -1)) == SEEKER_LOST
		var mine_now: Dictionary = _lock_row(client_a, id_a)
		var named_now: int = int(mine_now.get("target", 0))
		if named_now == 0:
			unresolved += 1
			if mine_now.has("bearing") or mine_now.has("range"):
				stale += 1
		elif not _is_vehicle_on(client_a, named_now):
			stale += 1
	_check("a_target_that_goes_away_is_lost_and_reads_as_nothing",
		retaken and lost_seen and unresolved > 0 and stale == 0,
		"retaken %s, LOST seen %s, %d rows with no target, %d stale or pointing at nothing"
			% [retaken, lost_seen, unresolved, stale])

	# ---- heat takes the tailpipe; radar takes the nose ------------------------------------
	#
	# Two aircraft at the same range and the same throttle. The one flying AWAY is further off
	# the nose; the one flying TOWARDS the launcher is nearer it. A heat-seeker is looking up
	# the first one's exhaust and must take it; a radar must take the second.
	var tail: Dictionary = _spawn_ahead(mine, 1200.0, 50.0, false, PLANE, true)
	var head: Dictionary = _spawn_ahead(mine, 1200.0, -20.0, true, PLANE, true)
	client_a.send_command(WEAPON, heat)
	_advance(12, flying, _controls())
	var by_heat: Dictionary = _designate(id_a, pressing, flying)
	_check("heat_takes_the_hot_tailpipe_over_the_nearer_nose",
		int(by_heat.get("target", 0)) == int(tail.get("vehicle", -1)),
		"heat took %d; tail-on %d, head-on %d" % [int(by_heat.get("target", 0)),
			int(tail.get("vehicle", -1)), int(head.get("vehicle", -1))])
	client_a.send_command(WEAPON, radar)
	_advance(12, flying, _controls())
	var by_radar: Dictionary = _designate(id_a, pressing, flying)
	_check("radar_takes_the_one_nearest_the_nose",
		int(by_radar.get("target", 0)) == int(head.get("vehicle", -1)),
		"radar took %d; tail-on %d, head-on %d" % [int(by_radar.get("target", 0)),
			int(tail.get("vehicle", -1)), int(head.get("vehicle", -1))])
	_despawn_spawned(tail)
	_despawn_spawned(head)

	# ---- a glider has no engine ------------------------------------------------------------
	var glider: Dictionary = _spawn_ahead(mine, 1000.0, 0.0, false, GLIDER, false)
	client_a.send_command(WEAPON, heat)
	_advance(12, flying, _controls())
	var cold: Dictionary = _designate(id_a, pressing, flying)
	client_a.send_command(WEAPON, radar)
	_advance(12, flying, _controls())
	var echo: Dictionary = _designate(id_a, pressing, flying)
	_check("a_glider_is_invisible_to_heat_and_not_to_radar",
		int(cold.get("target", -1)) == 0 and int(cold.get("phase", -1)) == SEEKER_SEARCHING
			and int(echo.get("target", 0)) == int(glider.get("vehicle", -1)),
		"heat %s; radar %s" % [cold, echo])
	_despawn_spawned(glider)

	# ---- what a radar cannot see ------------------------------------------------------------
	var wide: Dictionary = _spawn_ahead(mine, 750.0, 1300.0, false, PLANE, false)
	var off_the_nose: Dictionary = _designate(id_a, pressing, flying)
	_check("sixty_degrees_off_the_nose_is_not_seen",
		int(off_the_nose.get("target", -1)) == 0
			and int(off_the_nose.get("phase", -1)) == SEEKER_SEARCHING,
		"row %s" % [off_the_nose])
	_despawn_spawned(wide)
	var far: Dictionary = _spawn_ahead(mine, 9000.0, 0.0, false, PLANE, false)
	var too_far: Dictionary = _designate(id_a, pressing, flying)
	_check("past_its_range_is_not_seen",
		int(too_far.get("target", -1)) == 0 and int(too_far.get("phase", -1)) == SEEKER_SEARCHING,
		"row %s" % [too_far])
	_despawn_spawned(far)

	# A HILL between them, built in every world because static geometry has to agree, and
	# the target 1500 m out -- exactly where the first lock was taken with nothing between.
	var now: Dictionary = server.vehicle_state(mine)
	var forward: Vector3 = Basis(now.get("basis", Quaternion.IDENTITY) as Quaternion) * Vector3.FORWARD
	var hill_at: Vector3 = (now.get("position", Vector3.ZERO) as Vector3) + forward * 600.0
	for world in [server, client_a, client_b]:
		world.add_static_box(hill_at, Vector3(400.0, 400.0, 400.0))
	var hidden: Dictionary = _spawn_ahead(mine, 1500.0, 0.0, false, PLANE, false)
	var behind: Dictionary = _designate(id_a, pressing, flying)
	_check("behind_a_hill_is_not_seen",
		int(behind.get("target", -1)) == 0 and int(behind.get("phase", -1)) == SEEKER_SEARCHING,
		"row %s" % [behind])
	_despawn_spawned(hidden)


## Whether this entity id is a vehicle ON THIS WORLD. A target id from another world would be
## a number that happens to name nothing here -- or, worse, something else.
func _is_vehicle_on(world, entity: int) -> bool:
	for vehicle in world.vehicle_states():
		if int(vehicle["entity"]) == entity:
			return true
	return false


## ---- a missile leaves the rail, burns, and steers --------------------------------------
##
## Launches are the LAUNCH bit on client A's own frame, over the link; the station and the
## master arm are bus commands. What flies is read back from the server's missile_states() and
## from client B's, which receives it like anybody watching. The steering itself is measured in
## worlds of its own, ticked by hand, because what is being asked is a question about the
## flight -- does it close on something crossing it -- and the network adds nothing to that.
## ---- a launched rail comes back `rearm_s` after it launched --------------------------------
##
## Asked for from the headset: a pilot testing missiles should not have to respawn to fire again.
## Each check was run against a library broken the way it guards against; see the commit.
func _test_rails_rearm(id_a: int) -> void:
	var heat_id: int = _type_named("heat")
	var radar_id: int = _type_named("radar")
	var rearm: float = float(server.missile_type(heat_id).get("rearm_s", -1.0))
	_check("a_rail_rearms_five_seconds_after_it_launched_by_default",
		is_equal_approx(rearm, 5.0)
			and is_equal_approx(float(server.missile_type(radar_id).get("rearm_s", -1.0)), 5.0),
		"heat rearm_s %s, radar rearm_s %s" % [server.missile_type(heat_id).get("rearm_s"),
			server.missile_type(radar_id).get("rearm_s")])
	var flying: Dictionary = _controls({"throttle": 1.0})
	var launching: Dictionary = _controls({"throttle": 1.0, "buttons": LAUNCH})
	var plane: int = _fresh_launcher(id_a, Vector3(12000.0, 900.0, -12000.0))
	client_a.send_command(MASTER, 1)
	_advance(12, flying, _controls())
	client_a.send_command(WEAPON, _station_named("heat"))
	_advance(12, flying, _controls())
	var plane_here: int = int(_pilot_of(client_a, id_a).get("vehicle", 0))
	var ticks: int = int(round(rearm / DT))
	var known: Dictionary = {}
	for row in _missiles_of(server, id_a):
		known[int(row["entity"])] = true

	# THE FIRST PRESS: rail 0 leaves, noted on the tick the server's `stores` loses it.
	var launched_at: int = -1
	for i in range(LINK_DELAY_TICKS + 8):
		_advance(1, launching if i < 2 else flying, _controls())
		if launched_at < 0 and int(server.craft_systems(plane).get("stores", -1)) == 14:
			launched_at = _tick
	_check("a_launched_rail_is_empty_straight_after_launch", launched_at >= 0,
		"server stores %d" % int(server.craft_systems(plane).get("stores", -1)))
	for row in _missiles_of(server, id_a):
		known[int(row["entity"])] = true
	_advance(int(float(server.missile_type(heat_id)["reload_s"]) / DT) + 4, flying, _controls())

	# THE SECOND PRESS, HELD: rail 1 leaves on the edge, and the button then stays down until
	# well after rail 0 is back. A launch read as a level would put rail 0 straight back in the
	# air; an edge waits for the next press.
	var second_at: int = -1
	var server_back: int = -1
	var client_saw_empty: bool = false
	var client_back: int = -1
	var fired_while_held: Array = []
	var hold_until: int = launched_at + ticks + LINK_DELAY_TICKS * 2 + 60
	while _tick < hold_until:
		_advance(1, launching, _controls())
		var on_server: int = int(server.craft_systems(plane).get("stores", -1))
		if second_at < 0 and on_server == 12:
			second_at = _tick
			for row in _missiles_of(server, id_a):
				known[int(row["entity"])] = true
		if server_back < 0 and second_at >= 0 and (on_server & 1) == 1:
			server_back = _tick
		var on_client: int = int(client_a.craft_systems(plane_here).get("stores", -1))
		if on_client >= 0 and (on_client & 1) == 0:
			client_saw_empty = true
		if client_back < 0 and client_saw_empty and server_back >= 0 and (on_client & 1) == 1:
			client_back = _tick
		if second_at >= 0:
			for row in _missiles_of(server, id_a):
				if not known.has(int(row["entity"])):
					known[int(row["entity"])] = true
					fired_while_held.append(row)
	_check("the_rail_is_loaded_again_at_rearm_s_on_the_server",
		server_back >= 0 and absi((server_back - launched_at) - ticks) <= 1,
		"launched tick %d, back tick %d: %d ticks against %d for %.2f s" % [launched_at, server_back,
			server_back - launched_at, ticks, rearm])
	_check("and_on_the_pilots_own_machine_within_a_round_trip",
		client_saw_empty and client_back >= 0 and client_back - server_back <= LINK_DELAY_TICKS * 2 + 8,
		"client A saw it empty %s, back on client A %d ticks after the server" % [client_saw_empty,
			client_back - server_back])
	_check("a_held_launch_does_not_fire_the_rearmed_rail",
		second_at >= 0 and fired_while_held.is_empty(),
		"second launch tick %d; %d missile(s) left while LAUNCH was held past the rearm: %s"
			% [second_at, fired_while_held.size(), fired_while_held])

	# LET GO AND PRESS AGAIN: the rearmed rail 0 is the lowest loaded, so it goes first.
	_advance(LINK_DELAY_TICKS + 4, flying, _controls())
	var again: Dictionary = _launch_and_find(id_a, "heat", launching, flying)
	_check("a_new_press_launches_from_the_rearmed_rail", int(again.get("pylon", -1)) == 0,
		"missile %s" % [again])

	# 0 IS NEVER: a rail stays empty for as long as anyone waits.
	for world in [server, client_a, client_b]:
		world.set_missile_type(heat_id, {"rearm_s": 0.0})
	var still: int = _fresh_launcher(id_a, Vector3(12000.0, 900.0, -9000.0))
	client_a.send_command(MASTER, 1)
	_advance(12, flying, _controls())
	client_a.send_command(WEAPON, _station_named("heat"))
	_advance(12, flying, _controls())
	_launch(launching, flying)
	var emptied: int = int(server.craft_systems(still).get("stores", -1))
	_advance(ticks + 120, flying, _controls())
	var later: int = int(server.craft_systems(still).get("stores", -1))
	_check("rearm_s_zero_leaves_a_launched_rail_empty", emptied == 14 and later == 14,
		"stores %d after the launch, %d after %.1f s" % [emptied, later, float(ticks + 120) * DT])
	for world in [server, client_a, client_b]:
		world.set_missile_type(heat_id, {"rearm_s": rearm})
	# Nothing below counts these launches' cues.
	client_a.take_cues()
	client_b.take_cues()


func _test_the_missiles() -> void:
	var id_a: int = client_a.local_client_id()
	_test_rails_rearm(id_a)
	# RAILS THAT STAY EMPTY for everything below, which counts what is left on them over more
	# than five seconds. Rearming has its own section, just above, which runs first.
	for world in [server, client_a, client_b]:
		for row in world.missile_types():
			world.set_missile_type(int(row["id"]), {"rearm_s": 0.0})
	var flying: Dictionary = _controls({"throttle": 1.0})
	var launching: Dictionary = _controls({"throttle": 1.0, "buttons": LAUNCH})
	var pressing: Dictionary = _controls({"throttle": 1.0, "buttons": LOCK})
	var radar: int = _station_named("radar")
	var heat: int = _station_named("heat")

	# ---- the rail empties on the pilot's own machine, which PREDICTS that aeroplane -------
	#
	# A client learns an authoritative value for an aeroplane it predicts only on a rollback,
	# which is why `stores` asks for one on any difference.
	#
	# THIS CHECK CANNOT SHOW THAT RULE IS NEEDED, and it says so rather than pretending. It was
	# run with the rule deleted, twice: flying, and then PARKED in the hope that a parked
	# aeroplane is never corrected. Both passed. A flying aeroplane is corrected every few ticks
	# for reasons of its own, and even the parked one took 4 rollbacks in the forty ticks after
	# the launch -- and any rollback carries the whole of CraftSystems across, the emptied rail
	# with it. What it does hold is the thing a pilot sees: the rail goes empty on their own
	# machine within a round trip. The rule stays on the argument on CraftSystems -- an
	# authoritative value on a predicted entity arrives only on a rollback -- and on the
	# turret, which was once seen NOT to arrive for exactly that reason.
	var idle: Dictionary = _controls()
	var dropping: Dictionary = _controls({"buttons": LAUNCH})
	var parked: int = int(server.spawn_vehicle(PLANE, Vector3(-350.0, 1.2, 350.0), 0.0,
		Vector3.ZERO))
	server.seat_client(id_a, parked, 0)
	_advance(90, idle, _controls())
	client_a.send_command(MASTER, 1)
	_advance(12, idle, _controls())
	client_a.send_command(WEAPON, heat)
	_advance(72, idle, _controls())
	var rollbacks_before: int = int(client_a.resim_stats().get("count", 0))
	_launch(dropping, idle)
	var parked_here: int = int(_pilot_of(client_a, id_a).get("vehicle", 0))
	var parked_seen: int = -1
	for i in range(LINK_DELAY_TICKS * 2 + 30):
		_advance(1, idle, _controls())
		parked_seen = int(client_a.craft_systems(parked_here).get("stores", -1))
		if parked_seen == 14:
			break
	_check("the_rail_empties_on_the_pilots_own_machine",
		int(server.craft_systems(parked).get("stores", -1)) == 14 and parked_seen == 14,
		"server stores %d; client A's parked aeroplane reads %d; %d rollbacks meanwhile"
			% [int(server.craft_systems(parked).get("stores", -1)), parked_seen,
				int(client_a.resim_stats().get("count", 0)) - rollbacks_before])

	var plane: int = _fresh_launcher(id_a, Vector3(-12000.0, 900.0, 12000.0))
	client_a.send_command(MASTER, 1)
	_advance(12, flying, _controls())
	client_a.send_command(WEAPON, radar)
	_advance(12, flying, _controls())
	var full: int = int(server.craft_systems(plane).get("stores", -1))
	_check("a_fresh_aeroplane_carries_a_missile_on_every_rail", full == 15, "stores %d" % full)

	# ---- a radar missile will not leave without a lock ---------------------------------
	var before: int = _missiles_of(server, id_a).size()
	_launch(launching, flying)
	var refused: Dictionary = _lock_row(server, id_a)
	_check("a_radar_missile_will_not_leave_without_a_lock",
		_missiles_of(server, id_a).size() == before
			and int(server.craft_systems(plane).get("stores", -1)) == 15
			and int(refused.get("why", -1)) == WHY_NO_LOCK,
		"%d missiles, stores %d, why %s" % [_missiles_of(server, id_a).size(),
			int(server.craft_systems(plane).get("stores", -1)), refused.get("why_name", "")])

	# ---- a held LAUNCH is ONE missile, off the nose, from the first heat rail ---------------
	#
	# Held for three seconds -- six times the reload -- from a rack with BOTH its rails loaded,
	# so a launch read as a level instead of an edge puts a second missile in the air. The
	# first version held it with one rail left, where an edge and a level both come to one, and
	# passed with the edge taken out.
	client_a.send_command(WEAPON, heat)
	_advance(12, flying, _controls())
	var known_before: Dictionary = {}
	for row in _missiles_of(server, id_a):
		known_before[int(row["entity"])] = true
	var resims_before: int = int(client_a.resim_stats().get("count", 0))
	for i in range(180):
		var roll: float = 1.0 if (i / 30) % 2 == 0 else -1.0
		_advance(1, _controls({"throttle": 1.0, "roll": roll, "buttons": LAUNCH}), _controls())
	_advance(LINK_DELAY_TICKS + 4, flying, _controls())
	var resims: int = int(client_a.resim_stats().get("count", 0)) - resims_before
	var from_the_hold: Array = []
	for row in _missiles_of(server, id_a):
		if not known_before.has(int(row["entity"])):
			from_the_hold.append(row)
	_check("a_held_launch_is_one_missile_through_rollbacks",
		from_the_hold.size() == 1 and resims > 0,
		"%d missiles from a 180-tick hold with both heat rails loaded; %d rollbacks on client A"
			% [from_the_hold.size(), resims])
	var first: Dictionary = from_the_hold[0] if from_the_hold.size() == 1 else {}
	_check("a_heat_seeker_leaves_off_the_nose_from_the_first_heat_rail",
		String(first.get("type_name", "")) == "heat" and int(first.get("pylon", -1)) == 0
			and int(server.craft_systems(plane).get("stores", -1)) == 14,
		"missile %s, stores %d" % [first, int(server.craft_systems(plane).get("stores", -1))])

	# ---- the motor burns for its burn time, then it coasts --------------------------------
	var second: Dictionary = _launch_and_find(id_a, "heat", launching, flying)
	var burn: float = float(server.missile_type(_type_named("heat"))["burn_s"])
	var fastest: float = 0.0
	var fastest_at: float = -1.0
	var last_age: float = 0.0
	for i in range(int((burn + 1.0) / DT)):
		_advance(1, flying, _controls())
		var now: Dictionary = _missile_by_entity(server, int(second.get("entity", 0)))
		if now.is_empty() or not bool(now["flying"]):
			break
		last_age = float(now["age"])
		var speed: float = (now["velocity"] as Vector3).length()
		if speed > fastest:
			fastest = speed
			fastest_at = last_age
	_check("the_motor_burns_for_its_burn_time_then_it_coasts",
		last_age > burn + 0.5 and absf(fastest_at - burn) <= 2.0 * DT + 0.001,
		"fastest %.0f m/s at %.3f s, burn %.2f s, watched to %.2f s"
			% [fastest, fastest_at, burn, last_age])

	# ---- the missile names its rail on every machine --------------------------------------
	var on_b: Dictionary = {}
	for i in range(LINK_DELAY_TICKS * 2 + 12):
		_advance(1, flying, _controls())
		for row in client_b.missile_states():
			if int(row["client"]) == id_a and int(row["pylon"]) == 1:
				on_b = row
		if not on_b.is_empty():
			break
	_check("the_missile_names_its_rail_on_a_machine_that_only_watches",
		not on_b.is_empty() and String(on_b.get("type_name", "")) == "heat",
		"client B's row %s" % [on_b])
	_check("with_both_heat_rails_empty_the_seat_says_so",
		int(_lock_row(server, id_a).get("why", -1)) == WHY_EMPTY,
		"why %s" % [_lock_row(server, id_a).get("why_name", "")])
	var launches_a: Array = _launch_rails(client_a)
	var launches_b: Array = _launch_rails(client_b)
	# THREE LAUNCHES SO FAR: the parked aeroplane's rail 0, then this one's rails 0 and 1.
	_check("each_launch_is_one_cue_on_every_machine",
		launches_a == [0, 0, 1] and launches_b == [0, 0, 1],
		"rails cued on client A %s, on client B %s" % [launches_a, launches_b])

	# ---- `late` winds a watched missile forward to where the server has it NOW -------------
	#
	# A missile's row carries `late`, and the drawing adds velocity x late to the position.
	# Whether that lands on the server's present is MEASURED here rather than argued: client B
	# only watches, and every tick its wound-forward missile is compared with the server's
	# missile on the same tick. Three candidates are printed beside the row's own -- not wound at
	# all, the buffered lag alone, and the link latency plus the lag -- with sync's live timing,
	# so a formula that is wrong shows up as the one that misses.
	var watch_plane: int = _fresh_launcher(id_a, Vector3(-12000.0, 900.0, 4000.0))
	client_a.send_command(MASTER, 1)
	_advance(12, flying, _controls())
	client_a.send_command(WEAPON, heat)
	_advance(12, flying, _controls())
	var watched_known: Dictionary = {}
	for row in _missiles_of(server, id_a):
		watched_known[int(row["entity"])] = true
	_advance(2, launching, _controls())
	var watched_entity: int = 0
	var off_by_row: Array = []
	var off_unwound: Array = []
	var off_by_lag: Array = []
	var off_by_both: Array = []
	var along_by_lag: Array = []
	var off_by_lag_previous: Array = []
	var along_by_lag_previous: Array = []
	var last_there: Vector3 = Vector3.ZERO
	var has_previous: bool = false
	var lowest_buffer: int = 1000
	var timing_seen: Dictionary = {}
	for i in range(LINK_DELAY_TICKS * 2 + 150):
		_advance(1, flying, _controls())
		if watched_entity == 0:
			for row in _missiles_of(server, id_a):
				if not watched_known.has(int(row["entity"])):
					watched_entity = int(row["entity"])
		var truth: Dictionary = _missile_by_entity(server, watched_entity)
		if truth.is_empty() or not bool(truth["flying"]):
			has_previous = false
			continue
		# THE SERVER ONE TICK EARLIER, for the along-track bias -- see the printout below.
		var previous_there: Vector3 = last_there
		var previous_ok: bool = has_previous
		last_there = truth["position"]
		has_previous = true
		var seen_b: Dictionary = _missile_of_rail(client_b, id_a, int(truth["pylon"]), 2.4)
		if seen_b.is_empty() or not bool(seen_b["flying"]):
			continue
		timing_seen = client_b.timing()
		var at: Vector3 = seen_b["position"]
		var moving: Vector3 = seen_b["velocity"]
		var there: Vector3 = truth["position"]
		# IN TICKS OF TRAVEL, so the tolerance means the same thing at 150 m/s as at 450: the
		# comparison itself is only good to about a tick, because the client's picture of the
		# server's present is an estimate.
		var a_tick: float = maxf((truth["velocity"] as Vector3).length() * DT, 0.001)
		var lag_seconds: float = float(timing_seen.get("buffer_frames", 0)) * DT
		off_by_row.append((at + moving * float(seen_b["late"])).distance_to(there) / a_tick)
		off_unwound.append(at.distance_to(there) / a_tick)
		off_by_lag.append((at + moving * lag_seconds).distance_to(there) / a_tick)
		off_by_both.append((at + moving * (float(timing_seen.get("latency_frames", 0.0)) * DT
			+ lag_seconds)).distance_to(there) / a_tick)
		along_by_lag.append((at + moving * lag_seconds - there).dot(moving.normalized())
			/ a_tick)
		# THE ORDERING QUESTION. Lag-only sits a steady tick behind the server on the same
		# tick, and `_advance` ticks the server before the clients, so the same comparison
		# against the server one tick EARLIER is printed too: if the bias is the loop's
		# ordering, it is near zero there.
		if previous_ok:
			off_by_lag_previous.append((at + moving * lag_seconds).distance_to(previous_there)
				/ a_tick)
			along_by_lag_previous.append((at + moving * lag_seconds - previous_there)
				.dot(moving.normalized()) / a_tick)
		lowest_buffer = mini(lowest_buffer, int(timing_seen.get("buffer_frames", 0)))
	var by_row: float = _median(off_by_row)
	var unwound: float = _median(off_unwound)
	# The bar: within a tick and a half of travel, where a late that counted the link twice
	# measured 2.7 ticks and no winding at all measured 5.
	# AND THE LAG HAS TO HAVE MOVED. Measured against a buffer still at its configured value, a
	# formula using the configured buffer and one using the live lag are the same number, and
	# the check could not tell them apart. The configured value is asked for, not typed.
	var configured: int = int(client_b.net_status().get("buffer_frames", -1))
	_check("late_winds_a_watched_missile_to_where_the_server_has_it",
		off_by_row.size() >= 60 and by_row < 1.5 and unwound >= 3.0 * by_row
			and configured > 0 and lowest_buffer > configured,
		"%d ticks; median ticks of travel off the server: row's late %.2f, unwound %.2f, lag only %.2f (along track %+.2f), latency + lag %.2f; lag only against the server ONE TICK EARLIER %.2f (along track %+.2f); client B timing: latency %.2f frames, buffer %d frames, lowest %d against %d configured"
			% [off_by_row.size(), by_row, unwound, _median(off_by_lag), _median(along_by_lag),
				_median(off_by_both), _median(off_by_lag_previous),
				_median(along_by_lag_previous), float(timing_seen.get("latency_frames", -1.0)),
				int(timing_seen.get("buffer_frames", -1)), lowest_buffer, configured])

	# ---- proportional navigation, measured in a world of its own ---------------------------
	var at_60: float = _closest_approach(60.0, -1.0)
	var at_120: float = _closest_approach(120.0, -1.0)
	var blind: float = _closest_approach(60.0, 0.0)
	_check("proportional_navigation_closes_on_a_crossing_target", at_60 < 15.0,
		"closest approach %.1f m at 60 Hz" % at_60)
	_check("and_it_does_at_120_hz_too", at_120 < 15.0, "closest approach %.1f m at 120 Hz" % at_120)
	_check("and_with_no_navigation_gain_the_same_shot_misses", blind > 100.0,
		"closest approach %.1f m with N = 0" % blind)

	# ---- the fuse ------------------------------------------------------------------------------
	for hz in [60.0, 120.0]:
		var crossing: Dictionary = _fuse_crossing(hz)
		var ended: Dictionary = crossing.get("row", {})
		_check("the_fuse_bursts_beside_a_crossing_aeroplane_at_%d_hz" % int(hz),
			int(ended.get("surface", -1)) == SURFACE_FUSED
				and int(ended.get("target_hit", 0)) == int(crossing.get("target", -1))
				and float(crossing.get("gap", INF)) <= float(crossing.get("fuse", 0.0)) + 3.0,
			"ended on surface %d, hit %d (target %d), %.1f m from it with a %.1f m fuse"
				% [int(ended.get("surface", -1)), int(ended.get("target_hit", 0)),
					int(crossing.get("target", -1)), float(crossing.get("gap", INF)),
					float(crossing.get("fuse", 0.0))])

	# A PASS NO TICK CAME CLOSE TO. A building a missile flies past at 7.8 m, with an 8 m fuse and
	# a motor hot enough that each tick covers far more than the chord of the fuse -- so the
	# missile's sampled positions never come within the fuse, and only the closest approach
	# inside a tick can burst it. Straight flight: no navigation, and a building stays put.
	var past: Dictionary = _fuse_tower(7.8, 1500.0, 8.0, 60000.0, 12.0)
	var burst: Dictionary = past.get("row", {})
	_check("the_fuse_finds_a_pass_that_no_tick_came_within",
		int(burst.get("surface", -1)) == SURFACE_FUSED
			and float(past.get("sampled_min", 0.0)) > 8.0
			and int(burst.get("target_hit", 0)) == int(past.get("tower", -1)),
		"ended on surface %d, hit %d (tower %d); nearest sampled tick %.2f m, burst %.2f m out, %.0f m/s"
			% [int(burst.get("surface", -1)), int(burst.get("target_hit", 0)),
				int(past.get("tower", -1)), float(past.get("sampled_min", 0.0)),
				float(past.get("gap", INF)), float(past.get("speed", 0.0))])

	# AND IT IS NOT ARMED OFF THE RAIL. A building six metres beside the rail and fifteen ahead:
	# the missile passes it inside its twelve-metre fuse in its first tenth of a second, and must
	# still be flying at a second.
	var beside: Dictionary = _fuse_tower(6.0, 15.0, 12.0, 18000.0, 1.2)
	var still_flying: Dictionary = beside.get("row", {})
	_check("the_fuse_is_not_armed_off_the_rail",
		not still_flying.is_empty() and int(still_flying.get("surface", -1)) != SURFACE_FUSED
			and float(still_flying.get("age", 0.0)) >= 1.0,
		"last row: surface %d at %.2f s; nearest sampled tick %.2f m"
			% [int(still_flying.get("surface", -1)), float(still_flying.get("age", 0.0)),
				float(beside.get("sampled_min", 0.0))])

	# ---- a semi-active missile needs its launcher; a heat-seeker does not ---------------------
	plane = _fresh_launcher(id_a, Vector3(-12000.0, 900.0, 7000.0))
	client_a.send_command(MASTER, 1)
	_advance(12, flying, _controls())
	client_a.send_command(WEAPON, radar)
	_advance(12, flying, _controls())
	var quarry: Dictionary = _spawn_ahead(plane, 2000.0, 0.0, false, PLANE, true)
	_advance(10, flying, _controls())
	_designate(id_a, pressing, flying)
	_advance(int(float(server.missile_type(_type_named("radar"))["lock_s"]) / DT) + 10, flying,
		_controls())
	var radar_missile: Dictionary = _launch_and_find(id_a, "radar", launching, flying)
	_advance(20, flying, _controls())
	var guided_before: bool = bool(_missile_by_entity(server,
		int(radar_missile.get("entity", 0))).get("guided", false))
	_advance(2, pressing, _controls())
	var let_go_at: int = -1
	var blind_at: int = -1
	for i in range(LINK_DELAY_TICKS + 40):
		_advance(1, flying, _controls())
		if let_go_at < 0 and int(_lock_row(server, id_a).get("phase", -1)) != SEEKER_LOCKED:
			let_go_at = _tick
		var watched: Dictionary = _missile_by_entity(server, int(radar_missile.get("entity", 0)))
		if let_go_at > 0 and blind_at < 0 and not bool(watched.get("guided", true)):
			blind_at = _tick
			break
	_check("a_semi_active_missile_goes_blind_when_its_launcher_lets_go",
		guided_before and let_go_at > 0 and blind_at >= let_go_at
			and blind_at - let_go_at <= int(0.25 / DT),
		"guided before %s; the launcher let go at tick %d, the missile went blind at %d"
			% [guided_before, let_go_at, blind_at])

	client_a.send_command(WEAPON, heat)
	_advance(12, flying, _controls())
	_designate(id_a, pressing, flying)
	_advance(int(float(server.missile_type(_type_named("heat"))["lock_s"]) / DT) + 10, flying,
		_controls())
	var heat_missile: Dictionary = _launch_and_find(id_a, "heat", launching, flying)
	_advance(20, flying, _controls())
	_advance(2, pressing, _controls())
	_advance(LINK_DELAY_TICKS + 30, flying, _controls())
	var still: Dictionary = _missile_by_entity(server, int(heat_missile.get("entity", 0)))
	_check("a_heat_seeker_does_not_need_its_launcher",
		not heat_missile.is_empty() and bool(still.get("guided", false))
			and int(_lock_row(server, id_a).get("phase", -1)) != SEEKER_LOCKED,
		"heat missile %s, launcher's phase %s" % [still, _lock_row(server, id_a).get("phase_name")])
	_despawn_spawned(quarry)

	# ---- an ended missile stays for its last ticks, then goes -----------------------------------
	var heat_id: int = _type_named("heat")
	var life_was: float = float(server.missile_type(heat_id)["life_s"])
	server.set_missile_type(heat_id, {"life_s": 1.0})
	var short: Dictionary = _launch_and_find(id_a, "heat", launching, flying)
	var rail: int = int(short.get("pylon", -1))
	var ended_on_server: int = 0
	var gone_from_server: bool = false
	var ended_on_b: int = 0
	var gone_from_b: bool = false
	for i in range(int(1.0 / DT) + 90):
		_advance(1, flying, _controls())
		var s: Dictionary = _young_missile(server, id_a, rail)
		if s.is_empty():
			gone_from_server = gone_from_server or ended_on_server > 0
		elif not bool(s["flying"]):
			ended_on_server += 1
		var b: Dictionary = _young_missile(client_b, id_a, rail)
		if b.is_empty():
			gone_from_b = gone_from_b or ended_on_b > 0
		elif not bool(b["flying"]):
			ended_on_b += 1
	server.set_missile_type(heat_id, {"life_s": life_was})
	var linger_rows: Array = [ended_on_server, gone_from_server, ended_on_b, gone_from_b]
	_check("an_ended_missile_stays_for_its_last_ticks_then_goes",
		not short.is_empty() and ended_on_server >= 3 and gone_from_server
			and ended_on_b >= 3 and gone_from_b,
		"ended rows: server %d (gone %s), client B %d (gone %s)" % linger_rows)

	# ---- what a missile hit, on every machine, in that machine's own numbers --------------------
	#
	# A radar missile after a locked aeroplane flying away, the lock held, run to its end. The
	# server says what it burst beside; client B, which only watched, must name the same
	# aeroplane by CLIENT B's id for it -- checked to differ from the server's first -- and its
	# end cue must say it was the fuse.
	plane = _fresh_launcher(id_a, Vector3(-12000.0, 900.0, 2000.0))
	client_a.send_command(MASTER, 1)
	_advance(12, flying, _controls())
	client_a.send_command(WEAPON, radar)
	_advance(12, flying, _controls())
	var prey: Dictionary = _spawn_ahead(plane, 1500.0, 0.0, false, PLANE, true)
	_advance(10, flying, _controls())
	_designate(id_a, pressing, flying)
	_advance(int(float(server.missile_type(_type_named("radar"))["lock_s"]) / DT) + 10, flying,
		_controls())
	client_b.take_cues()
	client_a.take_cues()
	# THE LAUNCHING MACHINE IS TOLD TOO. Client A predicts the aeroplane the launch cue is on and
	# only watches the missile the end cue is on, which is two different roads through sync; the
	# game plays both on the pilot's own machine, so both are counted here and not only on B.
	var launch_cues_a: Array = []
	var end_values_a: Array = []
	var chaser: Dictionary = _launch_and_find(id_a, "radar", launching, flying)
	for cue in client_a.take_cues():
		if int(cue["what"]) == CUE_MISSILE_LAUNCH:
			launch_cues_a.append(cue)
	var prey_here: int = int(prey.get("vehicle", 0))
	var ended_here: Dictionary = {}
	var ended_there: Dictionary = {}
	var prey_there: int = 0
	var end_values: Array = []
	for i in range(int(12.0 / DT)):
		_advance(1, flying, _controls())
		for cue in client_b.take_cues():
			if int(cue["what"]) == CUE_MISSILE_END:
				end_values.append(int(cue["value"]))
		for cue in client_a.take_cues():
			match int(cue["what"]):
				CUE_MISSILE_LAUNCH:
					launch_cues_a.append(cue)
				CUE_MISSILE_END:
					end_values_a.append(int(cue["value"]))
		var on_server: Dictionary = _missile_by_entity(server, int(chaser.get("entity", 0)))
		if ended_here.is_empty() and not on_server.is_empty() and not bool(on_server["flying"]):
			ended_here = on_server
		prey_there = _same_vehicle_on(client_b, prey_here)
		if ended_there.is_empty() and prey_there != 0:
			var prey_at: Vector3 = Vector3.INF
			for vehicle in client_b.vehicle_states():
				if int(vehicle["entity"]) == prey_there:
					prey_at = vehicle["position"]
			for row in client_b.missile_states():
				if int(row["client"]) == id_a and not bool(row["flying"]) \
						and String(row["type_name"]) == "radar" \
						and (row["position"] as Vector3).distance_to(prey_at) < 60.0:
					ended_there = row
		if not ended_here.is_empty() and not ended_there.is_empty() and end_values.size() > 0:
			break
	_check("the_server_says_what_the_missile_burst_beside",
		int(ended_here.get("surface", -1)) == SURFACE_FUSED
			and int(ended_here.get("target_hit", 0)) == prey_here,
		"server row %s; the aeroplane is %d" % [ended_here, prey_here])
	_check("and_a_watching_machine_names_it_in_its_own_numbers",
		prey_there != 0 and prey_there != prey_here
			and int(ended_there.get("target_hit", 0)) == prey_there,
		"client B's row %s; client B numbers the aeroplane %d, the server %d"
			% [ended_there, prey_there, prey_here])
	_check("and_its_end_cue_says_the_fuse",
		end_values.has(SURFACE_FUSED), "end cues on client B carried %s" % [end_values])
	_check("the_launching_machine_is_told_of_the_launch_once",
		launch_cues_a.size() == 1 and (int(launch_cues_a[0]["value"]) >> 4) == _type_named("radar"),
		"launch cues on client A %s" % [launch_cues_a])
	_check("and_of_the_end_with_the_fuse",
		end_values_a.has(SURFACE_FUSED), "end cues on client A carried %s" % [end_values_a])
	_despawn_spawned(prey)


## A fresh aeroplane, every rail loaded, with this client in the pilot's seat.
func _fresh_launcher(client_id: int, at: Vector3) -> int:
	var plane: int = int(server.spawn_vehicle(PLANE, at, 0.0, Vector3(0.0, 0.0, -60.0)))
	server.seat_client(client_id, plane, 0)
	_advance(20, _controls({"throttle": 1.0}), _controls())
	return plane


func _launch(launching: Dictionary, flying: Dictionary) -> void:
	_advance(2, launching, _controls())
	_advance(LINK_DELAY_TICKS + 4, flying, _controls())


## Press LAUNCH and return the server's row for the missile that it put in the air, or {}.
func _launch_and_find(client_id: int, type_name: String, launching: Dictionary,
		flying: Dictionary) -> Dictionary:
	var known: Dictionary = {}
	for row in _missiles_of(server, client_id):
		known[int(row["entity"])] = true
	_launch(launching, flying)
	for row in _missiles_of(server, client_id):
		if not known.has(int(row["entity"])) and String(row["type_name"]) == type_name:
			return row
	return {}


func _missiles_of(world, client_id: int) -> Array:
	var out: Array = []
	for row in world.missile_states():
		if int(row["client"]) == client_id:
			out.append(row)
	return out


func _missile_by_entity(world, entity: int) -> Dictionary:
	for row in world.missile_states():
		if int(row["entity"]) == entity:
			return row
	return {}


## A missile of this client's off this rail that has flown no longer than `max_age`.
func _missile_of_rail(world, client_id: int, rail: int, max_age: float) -> Dictionary:
	for row in world.missile_states():
		if int(row["client"]) == client_id and int(row["pylon"]) == rail \
				and float(row["age"]) <= max_age:
			return row
	return {}


func _median(values: Array) -> float:
	if values.is_empty():
		return INF
	var sorted: Array = values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])


## A missile of this client's off this rail that has flown under a second and a bit -- the one
## just launched, and not an older one off the same numbered rail of another aeroplane.
func _young_missile(world, client_id: int, rail: int) -> Dictionary:
	for row in world.missile_states():
		if int(row["client"]) == client_id and int(row["pylon"]) == rail \
				and float(row["age"]) <= 1.2:
			return row
	return {}


## The rails named by every launch cue this world has been given since it was last asked,
## in order. Drains the cues.
func _launch_rails(world) -> Array:
	var rails: Array = []
	for cue in world.take_cues():
		if int(cue["what"]) == CUE_MISSILE_LAUNCH:
			rails.append(int(cue["value"]) & 0xF)
	rails.sort()
	return rails


## The closest a radar missile gets to an aeroplane crossing its path, in a server-only world
## ticked by hand at `hz`. `gain` below zero leaves the navigation gain as the table has it.
##
## The launcher flies north at 150 m/s; the target starts 2.5 km ahead and 1.5 km to the left,
## flying east at 150 m/s under full throttle, so a missile that flies where it is pointed
## passes well behind it and only one that leads it arrives.
func _closest_approach(hz: float, gain: float) -> float:
	var world = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(hz)
	world.start(0)
	_build_world(world)
	if gain >= 0.0:
		world.set_missile_type(_type_named("radar"), {"nav_gain": gain})
	var launcher: int = int(world.spawn_vehicle(PLANE, Vector3(0.0, 1000.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -150.0)))
	var target: Dictionary = world.spawn_pilot(250, PLANE, Vector3(-1500.0, 1000.0, -2500.0),
		-PI / 2.0, Vector3(150.0, 0.0, 0.0))
	var dt: float = 1.0 / hz
	var missile: int = 0
	var closest: float = INF
	for i in range(int(25.0 * hz)):
		world.set_pilot_input(int(target.get("pilot", 0)), _controls({"throttle": 1.0}))
		world.tick(dt)
		if i == int(0.2 * hz):
			missile = int(world.launch_missile(launcher, _station_named("radar"),
				int(target.get("vehicle", 0))))
		if missile == 0:
			continue
		var row: Dictionary = _missile_by_entity(world, missile)
		if row.is_empty():
			break
		var there: Vector3 = world.vehicle_state(int(target.get("vehicle", 0))).get("position",
			Vector3.ZERO)
		closest = minf(closest, ((row["position"] as Vector3) - there).length())
		if not bool(row["flying"]):
			break
	world.teardown()
	return closest


## A radar missile at an aeroplane crossing its path, in a server-only world at `hz`, run to
## its end: the geometry of `_closest_approach`, with the navigation left as the table has it.
func _fuse_crossing(hz: float) -> Dictionary:
	var world = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(hz)
	world.start(0)
	_build_world(world)
	var launcher: int = int(world.spawn_vehicle(PLANE, Vector3(0.0, 1000.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -150.0)))
	var target: Dictionary = world.spawn_pilot(250, PLANE, Vector3(-1500.0, 1000.0, -2500.0),
		-PI / 2.0, Vector3(150.0, 0.0, 0.0))
	var aircraft: int = int(target.get("vehicle", 0))
	var dt: float = 1.0 / hz
	var missile: int = 0
	var last: Dictionary = {}
	var gap: float = INF
	for i in range(int(25.0 * hz)):
		world.set_pilot_input(int(target.get("pilot", 0)), _controls({"throttle": 1.0}))
		world.tick(dt)
		if i == int(0.2 * hz):
			missile = int(world.launch_missile(launcher, _station_named("radar"), aircraft))
		if missile == 0:
			continue
		var row: Dictionary = _missile_by_entity(world, missile)
		if row.is_empty():
			break
		last = row
		if not bool(row["flying"]):
			gap = (row["position"] as Vector3).distance_to(
				world.vehicle_state(aircraft).get("position", Vector3.INF))
			break
	var fuse: float = float(world.missile_type(_type_named("radar"))["fuse_m"])
	world.teardown()
	return {"row": last, "target": aircraft, "gap": gap, "fuse": fuse}


## A radar missile flying STRAIGHT past a building, in a server-only world at 60 Hz: no
## navigation, the building `offset` metres to the side of the rail's line and `ahead` metres
## down it, a fuse of `fuse` metres and a motor of `thrust` newtons. Runs `seconds` or to the
## end, and reports the last row, the nearest any sampled flying tick came, and how far out the
## end was.
func _fuse_tower(offset: float, ahead: float, fuse: float, thrust: float,
		seconds: float) -> Dictionary:
	var world = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(60.0)
	world.start(0)
	_build_world(world)
	world.set_missile_type(_type_named("radar"),
		{"thrust": thrust, "fuse_m": fuse, "nav_gain": 0.0, "ground": true})
	var station: int = _station_named("radar")
	var rail: Vector3 = Vector3.ZERO
	for row in server.missile_schema(PLANE).get("stations", []):
		if int(row["station"]) == station:
			rail = (row["pylons"] as Array)[0]
	var launcher: int = int(world.spawn_vehicle(PLANE, Vector3(0.0, 1000.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -150.0)))
	world.tick(1.0 / 60.0)
	world.tick(1.0 / 60.0)
	# THE BUILDING GOES ON THE LINE THE MISSILE WILL ACTUALLY FLY, worked out from the aeroplane
	# as it is on the launch tick. The first version placed it from the aeroplane as it was
	# spawned, and an unpiloted aeroplane has already moved its nose a fraction of a degree by
	# then -- metres, fifteen hundred metres out, and the pass it measured was at 11 m instead
	# of 7.8. The missile leaves the rail with the aeroplane's velocity and a two-metre-a-second
	# drop, pushes along that, and holds against gravity while it sees its target: a straight
	# line from the rail along the velocity it was given.
	var state: Dictionary = world.vehicle_state(launcher)
	var attitude := Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion)
	var from: Vector3 = (state.get("position", Vector3.ZERO) as Vector3) + attitude * rail
	var along: Vector3 = ((state.get("velocity", Vector3.ZERO) as Vector3)
		+ attitude * Vector3(0.0, -2.0, 0.0)).normalized()
	var aside: Vector3 = along.cross(Vector3.UP).normalized()
	var building_at: Vector3 = from + along * ahead + aside * offset
	var tower: int = int(world.spawn_vehicle(TOWER, building_at, 0.0, Vector3.ZERO))
	var missile: int = int(world.launch_missile(launcher, station, tower))
	var last: Dictionary = {}
	var sampled_min: float = INF
	var gap: float = INF
	var speed: float = 0.0
	for i in range(int(seconds * 60.0)):
		world.tick(1.0 / 60.0)
		if missile == 0:
			continue
		var row: Dictionary = _missile_by_entity(world, missile)
		if row.is_empty():
			break
		last = row
		var there: Vector3 = world.vehicle_state(tower).get("position", building_at)
		if not bool(row["flying"]):
			gap = (row["position"] as Vector3).distance_to(there)
			break
		speed = (row["velocity"] as Vector3).length()
		sampled_min = minf(sampled_min, (row["position"] as Vector3).distance_to(there))
	world.teardown()
	return {"row": last, "tower": tower, "sampled_min": sampled_min, "gap": gap, "speed": speed}


## One seat's row of lock_states() on one world, by the seat's client id.
func _lock_row(world, client_id: int) -> Dictionary:
	for row in world.lock_states():
		if int(row.get("client", -1)) == client_id:
			return row
	return {}


func _station_named(wanted: String) -> int:
	for station in server.missile_schema(PLANE).get("stations", []):
		if String(station["name"]) == wanted:
			return int(station["station"])
	return -1


func _type_named(wanted: String) -> int:
	for row in server.missile_types():
		if String(row["name"]) == wanted:
			return int(row["id"])
	return -1


## Press LOCK from client A and return the server's row once the press has landed. A seeker
## already locking or locked is let go first, so a press that DESIGNATES is what is measured
## rather than a press that breaks a lock and happens to read as SEARCHING.
func _designate(client_id: int, pressing: Dictionary, flying: Dictionary) -> Dictionary:
	_advance(4, flying, _controls())
	var before: int = int(_lock_row(server, client_id).get("phase", -1))
	if before == SEEKER_LOCKING or before == SEEKER_LOCKED:
		_advance(2, pressing, _controls())
		_advance(LINK_DELAY_TICKS + 4, flying, _controls())
	_advance(2, pressing, _controls())
	_advance(LINK_DELAY_TICKS + 4, flying, _controls())
	return _lock_row(server, client_id)


## An aircraft `distance` along the launcher's nose and `sideways` to its right, flying the
## launcher's way at its speed -- or straight at it, `head_on`. Piloted ones hold full
## throttle, because a heat-seeker is looking for an engine.
func _spawn_ahead(launcher: int, distance: float, sideways: float, head_on: bool, kind: int,
		piloted: bool) -> Dictionary:
	var state: Dictionary = server.vehicle_state(launcher)
	var basis := Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion)
	var forward: Vector3 = basis * Vector3.FORWARD
	var right: Vector3 = basis * Vector3.RIGHT
	var at: Vector3 = (state.get("position", Vector3.ZERO) as Vector3) + forward * distance \
		+ right * sideways
	var flat := Vector3(forward.x, 0.0, forward.z).normalized()
	var yaw: float = atan2(-flat.x, -flat.z) + (PI if head_on else 0.0)
	var speed: float = (state.get("velocity", Vector3.ZERO) as Vector3).length()
	var velocity: Vector3 = (-flat if head_on else flat) * speed
	if piloted:
		var spawned: Dictionary = server.spawn_pilot(_spare_client(), kind, at, yaw, velocity)
		_seat_input(spawned, {"throttle": 1.0})
		return spawned
	return {"vehicle": int(server.spawn_vehicle(kind, at, yaw, velocity))}


func _despawn_spawned(spawned: Dictionary) -> void:
	if spawned.has("pilot"):
		_server_inputs.erase(int(spawned["pilot"]))
		server.despawn_pilot(int(spawned["pilot"]))
	else:
		server.despawn_vehicle(int(spawned.get("vehicle", 0)))
	_advance(4, _controls({"throttle": 1.0}), _controls())


## ---- 6. every control moves the aircraft the way it says it does --------------------
##
## Sign errors are invisible in code review and obvious the moment somebody puts a headset
## on, which is exactly how the roll axis reached one inverted. It was applied about
## FORWARD, which is -Z, so the axis vector already carried a sign; negating on top of it
## turned "+1 is right wing down" into right wing up.
##
## Flown on the POD, which hovers and has control authority at zero airspeed, so what is
## measured is the control rather than the aerodynamics.
##
## LAST, because it takes six seconds and leaves A's aeroplane unflown throughout. Run
## earlier it put the aircraft on the ground before the prediction test, which then
## measured three ticks of aileron on a parked aeroplane and reported that prediction had
## stopped working.
func _test_control_signs() -> void:
	var pod: int = _local_entity(client_b, POD)
	_check("found_the_pod", pod != 0, "entity %d on B" % pod)
	if pod == 0:
		return

	# B is the pod's pilot, so B predicts it and answers its own stick immediately.
	_advance(50, _controls(), _controls({"roll": 1.0}))
	var rolled: Basis = Basis(_vehicle_of(client_b, POD).get(
		"basis", Quaternion.IDENTITY) as Quaternion)
	# The right wing is the body's +X. Right wing DOWN means its world Y is negative.
	_check("roll_right_puts_the_right_wing_down", rolled.x.y < -0.15,
		"right wing y = %.3f (negative is down)" % rolled.x.y)
	_advance(70, _controls(), _controls())

	_advance(50, _controls(), _controls({"pitch": 1.0}))
	var pitched: Basis = Basis(_vehicle_of(client_b, POD).get(
		"basis", Quaternion.IDENTITY) as Quaternion)
	# The nose is the body's -Z. Nose UP means its world Y is positive.
	_check("pitch_up_raises_the_nose", (-pitched.z).y > 0.15,
		"nose y = %.3f (positive is up)" % (-pitched.z).y)
	_advance(70, _controls(), _controls())

	_advance(50, _controls(), _controls({"rudder": 1.0}))
	var yawed: Basis = Basis(_vehicle_of(client_b, POD).get(
		"basis", Quaternion.IDENTITY) as Quaternion)
	# Starting yaw is zero, so the nose is -Z. Nose RIGHT means its world X is positive.
	_check("rudder_right_swings_the_nose_right", (-yawed.z).x > 0.1,
		"nose x = %.3f (positive is right)" % (-yawed.z).x)


## ---- 7. every vehicle moves in its own way ------------------------------------------
##
## Not "the numbers differ" -- the FORCES differ. A boat has buoyancy and no wing, a
## helicopter pushes along its rotor disc rather than its nose, a car cannot leave the
## ground and does not sideslip. Expressing all of that as one model with coefficients
## gives a model that is wrong for everything and tunable into being wrong for everything.
func _test_movement_models() -> void:
	_check("each_kind_declares_a_model",
		int(server.movement_model(PLANE)) == M_AIRPLANE
			and int(server.movement_model(HELI)) == M_HELICOPTER
			and int(server.movement_model(CAR)) == M_CAR
			and int(server.movement_model(BOAT)) == M_BOAT
			and int(server.movement_model(POD)) == M_HOVER,
		"plane=%s heli=%s car=%s boat=%s pod=%s" % [
			server.movement_model_name(PLANE), server.movement_model_name(HELI),
			server.movement_model_name(CAR), server.movement_model_name(BOAT),
			server.movement_model_name(POD)])

	# THE ONE THE FLIGHT MODEL EXISTS FOR: banking turns the aeroplane.
	#
	# Nothing in the simulation says "turn". Lift acts along the body's UP, so rolling
	# tilts the lift vector and its horizontal component is a centripetal force; the fin
	# then swings the nose into the new airflow. It only works if the lift is REAL, which
	# is what the first numbers got wrong -- the aircraft could not carry its own weight at
	# any speed it could reach, so there was no vector worth tilting.
	# Spawned ALREADY FLYING, nose-first at cruise. An aeroplane put into the air at a
	# standstill stalls before it can accelerate and mushes into the ground at full power;
	# that is correct behaviour and it is not what this test is about.
	var cruise_speed := Vector3(0.0, 0.0, -58.0)
	var pilot: Dictionary = server.spawn_pilot(_spare_client(), PLANE,
		Vector3(200.0, 300.0, 0.0), 0.0, cruise_speed)
	_advance(40, _controls(), _controls())

	# Fly it from the server, which is authoritative and needs no client to be aboard.
	var flown: int = int(pilot.get("vehicle", 0))
	_check("a_test_aircraft_is_flying", flown != 0, "entity %d" % flown)
	if flown == 0:
		return

	# Hold cruise, wings level, and let it settle into its own trim.
	_seat_input(pilot, {"throttle": 1.0})
	_advance(240, _controls(), _controls())
	var level: Dictionary = server.vehicle_state(flown)
	var cruise: float = (level.get("velocity", Vector3.ZERO) as Vector3).length()
	var sink: float = (level.get("velocity", Vector3.ZERO) as Vector3).y
	# The property that makes it an aircraft: it holds its height on the wing rather than
	# falling at a rate drag happens to limit.
	_check("the_aeroplane_can_carry_its_own_weight", cruise > 40.0 and sink > -6.0,
		"%.0f m/s, %.1f m/s vertical" % [cruise, sink])

	# Now bank it, hold the bank, and watch the HEADING.
	var before_nose: Vector3 = (level.get("basis", Quaternion.IDENTITY) as Quaternion) 		* Vector3(0, 0, -1)
	_seat_input(pilot, {"throttle": 1.0, "roll": 0.7})
	_advance(45, _controls(), _controls())
	_seat_input(pilot, {"throttle": 1.0, "roll": 0.0, "pitch": 0.25})
	_advance(150, _controls(), _controls())
	var turned: Dictionary = server.vehicle_state(flown)
	var after_nose: Vector3 = (turned.get("basis", Quaternion.IDENTITY) as Quaternion) 		* Vector3(0, 0, -1)
	var before_flat := Vector2(before_nose.x, before_nose.z).normalized()
	var after_flat := Vector2(after_nose.x, after_nose.z).normalized()
	var heading_change: float = absf(before_flat.angle_to(after_flat))
	_check("banking_turns_the_aeroplane", heading_change > 0.35,
		"heading moved %.0f degrees while banked" % rad_to_deg(heading_change))

	# A helicopter holds a hover on about half collective, which an aeroplane cannot do at
	# all. Different model, not a different coefficient.
	var chopper: Dictionary = server.spawn_pilot(_spare_client(), HELI,
		Vector3(-260.0, 60.0, 0.0), 0.0, Vector3.ZERO)
	_seat_input(chopper, {"throttle": 0.5})
	_advance(180, _controls(), _controls())
	var hovering: Dictionary = server.vehicle_state(int(chopper.get("vehicle", 0)))
	var drift: float = (hovering.get("velocity", Vector3.ZERO) as Vector3).y
	_check("a_helicopter_hovers_on_half_collective", absf(drift) < 6.0,
		"vertical speed %.2f m/s at half stick" % drift)

	# And a car stays parked, which is the property a near-frictionless hull does not have
	# on its own.
	var motor: Dictionary = server.spawn_pilot(_spare_client(), CAR,
		Vector3(-320.0, 0.7, 0.0), 0.0, Vector3.ZERO)
	_advance(120, _controls(), _controls())
	var parked_at: Vector3 = server.vehicle_state(
		int(motor.get("vehicle", 0))).get("position", Vector3.ZERO)
	_advance(120, _controls(), _controls())
	var still_at: Vector3 = server.vehicle_state(
		int(motor.get("vehicle", 0))).get("position", Vector3.ZERO)
	_check("a_car_stays_parked", parked_at.distance_to(still_at) < 0.05,
		"drifted %.4f m in two seconds" % parked_at.distance_to(still_at))
	_check("the_car_is_on_the_ground", still_at.y < 3.0,
		"resting at y = %.2f" % still_at.y)


## ---- 8. THE FLIGHT PATH FOLLOWS THE NOSE ---------------------------------------------
##
## The thing an aeroplane does that nothing else in this file does. A turn begins as a
## tilted lift vector, which accelerates the aircraft ACROSS its own nose; if nothing
## pulls the velocity round to meet the heading, the aeroplane slides sideways through the
## sky with its nose still pointing where it started. That is what this used to do, and
## the reason was that sideways drag is quadratic: it fades away exactly as the slip gets
## small, so the last few degrees never close.
##
## Measured as SIDESLIP -- the angle between where the aircraft is going and where it is
## pointing, taken in the middle of a turn where the error would be worst.
func _test_the_flight_path_follows_the_nose() -> void:
	var pilot: Dictionary = server.spawn_pilot(_spare_client(), PLANE,
		Vector3(0.0, 600.0, 300.0), 0.0, Vector3(0.0, 0.0, -58.0))
	var plane: int = int(pilot.get("vehicle", 0))
	if plane == 0:
		_check("a_second_test_aircraft_is_flying", false, "no vehicle")
		return
	_seat_input(pilot, {"throttle": 1.0})
	_advance(180, _controls(), _controls())

	var entering: Dictionary = server.vehicle_state(plane)
	_check("straight_and_level_flies_straight", absf(_sideslip(entering)) < 1.5,
		"%.2f degrees of sideslip with the wings level" % _sideslip(entering))

	# Roll in, then hold the bank with back stick. That is a turn: nothing in the
	# simulation is told to change heading.
	_seat_input(pilot, {"throttle": 1.0, "roll": 0.8})
	_advance(40, _controls(), _controls())
	_seat_input(pilot, {"throttle": 1.0, "roll": 0.0, "pitch": 0.35})
	_advance(70, _controls(), _controls())

	var mid: Dictionary = server.vehicle_state(plane)
	_check("the_flight_path_follows_the_nose_through_a_turn",
		absf(_sideslip(mid)) < 5.0,
		"%.2f degrees of sideslip mid-turn" % _sideslip(mid))
	_check("and_the_whole_velocity_vector_does_not_just_the_yaw",
		_crab(mid) < 14.0, "%.1f degrees between velocity and nose" % _crab(mid))

	# The other half of the claim: the TRACK turns as much as the NOSE does. An aeroplane
	# whose nose swung round while it kept sliding along the old heading would pass the
	# heading test in the model suite and still be wrong.
	var nose_before: float = _heading(_nose(mid))
	var track_before: float = _heading(mid.get("velocity", Vector3.ZERO))
	_advance(150, _controls(), _controls())
	var late: Dictionary = server.vehicle_state(plane)
	var nose_moved: float = absf(rad_to_deg(angle_difference(nose_before,
		_heading(_nose(late)))))
	var track_moved: float = absf(rad_to_deg(angle_difference(track_before,
		_heading(late.get("velocity", Vector3.ZERO)))))
	_check("turning_converts_the_forward_value", nose_moved > 20.0
		and absf(nose_moved - track_moved) < 8.0,
		"the nose swung %.0f degrees and the track swung %.0f" % [nose_moved, track_moved])


## ---- 9. THE BRAKE REACHES ZERO -------------------------------------------------------
##
## It used to stop trying below 0.3 m/s, because the force was constant and a constant
## force applied to something nearly stopped reverses it. The guard hid that by giving up
## first, so the left trigger could slow a vehicle right down and never park it.
##
## Clamping the force to what would make the velocity exactly zero this step fixes both
## halves at once: it stops AT zero, and there is no speed at which it is switched off.
func _test_the_brake_reaches_zero() -> void:
	var pilot: Dictionary = server.spawn_pilot(_spare_client(), POD,
		Vector3(0.0, 140.0, -360.0), 0.0, Vector3(0.0, 0.0, -25.0))
	var pod: int = int(pilot.get("vehicle", 0))
	if pod == 0:
		_check("a_test_pod_is_flying", false, "no vehicle")
		return
	_seat_input(pilot, {})
	_advance(20, _controls(), _controls())

	_seat_input(pilot, {"brake": 1.0})
	var ticks: int = 0
	while ticks < 600:
		_advance(10, _controls(), _controls())
		ticks += 10
		if (server.vehicle_state(pod).get("velocity", Vector3.ZERO) as Vector3).length() \
				< 0.001:
			break
	var stopped: Dictionary = server.vehicle_state(pod)
	var rest: float = (stopped.get("velocity", Vector3.ZERO) as Vector3).length()
	_check("the_brake_reaches_zero", rest < 0.001,
		"%.9f m/s after %.2f s on the brake" % [rest, ticks * DT])

	# And stays there. A brake that overshoots does not sit still under a held trigger --
	# it hunts either side of a stop, which is what the old guard was there to prevent.
	var where: Vector3 = stopped.get("position", Vector3.ZERO)
	_advance(120, _controls(), _controls())
	var after: Vector3 = server.vehicle_state(pod).get("position", Vector3.ZERO)
	_check("and_never_reverses", where.distance_to(after) < 0.001,
		"moved %.9f m in two more seconds of full brake" % where.distance_to(after))


## ---- 9b. AN AEROPLANE ON THE GROUND --------------------------------------------------
##
## Wheels, brakes, a nosewheel and a squat switch -- and every one of them relative to what
## the wheels are standing on, because a carrier's deck is doing fifteen metres a second.
##
## Each check was run red first, against the simulation before this: the hull dragging on the
## ground at 0.17 of weight, so a light aeroplane sat still at 880 N of thrust; a brake that
## stopped an aeroplane against the AIR and slid it 362 m off a carrier's stern; full rudder
## yawing a parked aeroplane at 0.01 rad/s; and gear that was drag and nothing else.
const CARRIER: int = 12
## Matching Channel::Gear in cockpit_world.cpp.
const CHANNEL_GEAR: int = 3


func _test_an_aeroplane_on_the_ground() -> void:
	var a: Dictionary = _controls({"throttle": 1.0})
	# TWO CLIENT IDS FOR THE WHOLE SECTION, reused: one for whatever aircraft is being tried and one
	# for the ship's helm. A seat holds its occupant in a byte, so a fresh spare id per spawn ran
	# the count past 255 and the crew tests later in this file found clients 1 and 2 in their seats.
	var crew: int = _spare_client()
	var helm: int = _spare_client()
	# AND NOTHING LEFT BEHIND. The crew tests further down have pods press "take the next craft"
	# and expect to board one particular aeroplane; an aircraft this section left lying on the
	# ground was a craft they could take instead, and four of their checks failed for it.
	var already: Dictionary = _vehicle_ids()

	# ---- TAXIING: on a deck, and on the island, alike -------------------------------------
	var still: Dictionary = _a_carrier(helm, Vector3(-6000.0, 0.0, 0.0), false)
	var deck: int = int(still.get("vehicle", 0))
	var light_on_deck: float = _taxi_distance(crew, PLANE, _on_deck(deck, PLANE, 60.0, 10.0), deck,
		0.05, 10.0)
	var heavy_on_deck: float = _taxi_distance(crew, AIRLINER, _on_deck(deck, AIRLINER, 60.0, -12.0),
		deck, 0.10, 10.0)
	_despawn_spawned(still)
	var light_on_island: float = _taxi_distance(crew, PLANE,
		Vector3(300.0, _half_height(PLANE) + 0.05, 350.0), 0, 0.05, 10.0)
	_check("a_light_aeroplane_taxis_freely_on_a_carrier_deck", light_on_deck >= 40.0,
		"%.1f m in 10 s at 5%% throttle" % light_on_deck)
	_check("and_so_does_an_airliner", heavy_on_deck >= 20.0,
		"%.1f m in 10 s at 10%% throttle" % heavy_on_deck)
	_check("and_a_deck_rolls_like_the_island",
		absf(light_on_island - light_on_deck) <= 0.1 * maxf(light_on_deck, 1.0),
		"%.1f m on the island against %.1f on the deck" % [light_on_island, light_on_deck])

	# ---- THE WHEEL BRAKES stop it -----------------------------------------------------------
	var braking: Dictionary = server.spawn_pilot(crew, PLANE,
		Vector3(250.0, _half_height(PLANE) + 0.05, 350.0), 0.0, Vector3(0.0, 0.0, -8.0))
	_seat_input(braking, {"brake": 1.0})
	var brake_from: Vector3 = _relative(int(braking.get("vehicle", 0)), 0)[0]
	var stopped_after: int = -1
	for tick in range(600):
		_advance(1, a, _controls())
		var moving: Vector3 = _relative(int(braking.get("vehicle", 0)), 0)[1]
		if Vector2(moving.x, moving.z).length() < 0.1:
			stopped_after = tick + 1
			break
	var brake_gone: Vector3 = _relative(int(braking.get("vehicle", 0)), 0)[0] - brake_from
	var stopping: float = Vector2(brake_gone.x, brake_gone.z).length()
	_check("the_wheel_brakes_stop_a_taxiing_aeroplane_inside_eight_metres",
		stopped_after > 0 and stopping <= 8.0,
		"%.1f m and %.2f s from 8 m/s" % [stopping, stopped_after * DT])
	_despawn_spawned(braking)

	# ---- AND HOLD IT ON A CARRIER UNDER WAY: braked, and chocked with nobody aboard ----------
	var under_way: Dictionary = _a_carrier(helm, Vector3(-6000.0, 0.0, 3000.0), true)
	var ship: int = int(under_way.get("vehicle", 0))
	var ship_speed: Vector3 = server.vehicle_state(ship).get("velocity", Vector3.ZERO)
	var held: Dictionary = server.spawn_pilot(crew, PLANE,
		_on_deck(ship, PLANE, 40.0, 12.0), 0.0, ship_speed)
	_seat_input(held, {"brake": 1.0})
	var parked: Dictionary = {"vehicle": int(server.spawn_vehicle(PLANE,
		_on_deck(ship, PLANE, -40.0, -12.0), 0.0, ship_speed))}
	_advance(60, a, _controls())
	var held_from: Vector3 = _on_the_ship(int(held.get("vehicle", 0)), ship)
	var parked_from: Vector3 = _on_the_ship(int(parked["vehicle"]), ship)
	_advance(1200, a, _controls())
	var held_drift: float = _on_the_ship(int(held.get("vehicle", 0)), ship).distance_to(held_from)
	var parked_drift: float = _on_the_ship(int(parked["vehicle"]), ship).distance_to(parked_from)
	_check("the_brakes_hold_an_aeroplane_still_on_a_carrier_under_way", held_drift < 0.5,
		"%.2f m in 20 s on a deck doing %.1f m/s" % [held_drift,
			(server.vehicle_state(ship).get("velocity", Vector3.ZERO) as Vector3).length()])
	_check("and_an_aeroplane_with_nobody_in_it_is_chocked", parked_drift < 0.5,
		"%.2f m in 20 s" % parked_drift)
	_despawn_spawned(held)
	_despawn_spawned(parked)
	_despawn_spawned(under_way)

	# ---- THE NOSEWHEEL at a crawl, and the fin at speed -------------------------------------
	var slow_yaw: float = _yaw_after_a_second(crew, PLANE, Vector3(200.0, 0.0, 350.0), 3.0)
	_check("full_rudder_on_the_ground_turns_a_slow_aeroplane", slow_yaw >= 0.4,
		"%.2f rad/s after a second at 3 m/s" % slow_yaw)
	var slow_heavy: float = _yaw_after_a_second(crew, AIRLINER, Vector3(120.0, 0.0, 300.0), 3.0)
	# 0.25 measured. Its tiller asks 0.3 and the aircraft bleeds speed through the second, so the
	# line is below that with room; the bug it catches read 0.00.
	_check("and_turns_an_airliner", slow_heavy >= 0.2,
		"%.2f rad/s after a second at 3 m/s" % slow_heavy)
	# WITH NO NOSEWHEEL AT ALL, set to zero: nothing at a crawl, and the fin alone at 40 m/s.
	# Without the first half the second proves nothing -- a nosewheel doing all the work at
	# every speed would pass it.
	var kept: float = float(server.handling(PLANE).get("ground_steer", 0.5))
	server.set_handling(PLANE, {"ground_steer": 0.0})
	var crawl_no_wheel: float = _yaw_after_a_second(crew, PLANE, Vector3(40.0, 0.0, 350.0), 0.5)
	var fast_no_wheel: float = _yaw_after_a_second(crew, PLANE, Vector3(-60.0, 0.0, 380.0), 40.0)
	server.set_handling(PLANE, {"ground_steer": kept})
	_check("at_take_off_speed_the_fin_steers_rather_than_the_nosewheel",
		crawl_no_wheel < 0.05 and fast_no_wheel >= 0.3,
		"%.2f rad/s at a crawl and %.2f at 40 m/s with the nosewheel switched off" % [
			crawl_no_wheel, fast_no_wheel])

	# ---- THE GEAR: down on the ground and staying there, and workable in the air ------------
	var standing: Dictionary = server.spawn_pilot(crew, PLANE,
		Vector3(-150.0, _half_height(PLANE) + 0.05, 350.0), 0.0, Vector3.ZERO)
	_seat_input(standing, {})
	_advance(10, a, _controls())
	var down_at_spawn: bool = _gear_of(int(standing.get("vehicle", 0)))
	_seat_input(standing, {"command_channel": CHANNEL_GEAR, "command_value": 0, "command_seq": 1})
	_advance(30, a, _controls())
	var still_down: bool = _gear_of(int(standing.get("vehicle", 0)))
	_check("an_aeroplane_put_on_the_ground_has_its_gear_down", down_at_spawn,
		"gear %s" % down_at_spawn)
	_check("and_the_squat_switch_will_not_raise_it_there", down_at_spawn and still_down,
		"gear %s after a gear-up command with its weight on its wheels" % still_down)
	_despawn_spawned(standing)
	# THE SAME COMMAND WORKS IN THE AIR, so the refusal above is the squat switch and not a
	# channel that does nothing.
	var aloft: Dictionary = server.spawn_pilot(crew, PLANE,
		Vector3(-200.0, 300.0, 200.0), 0.0, Vector3(0.0, 0.0, -60.0))
	_seat_input(aloft, {"throttle": 0.6})
	_advance(10, a, _controls())
	var up_at_spawn: bool = not _gear_of(int(aloft.get("vehicle", 0)))
	_seat_input(aloft, {"throttle": 0.6, "command_channel": CHANNEL_GEAR, "command_value": 1,
		"command_seq": 2})
	_advance(30, a, _controls())
	var lowered: bool = _gear_of(int(aloft.get("vehicle", 0)))
	_seat_input(aloft, {"throttle": 0.6, "command_channel": CHANNEL_GEAR, "command_value": 0,
		"command_seq": 3})
	_advance(30, a, _controls())
	var raised: bool = not _gear_of(int(aloft.get("vehicle", 0)))
	_check("an_aeroplane_put_into_the_air_has_its_gear_up_and_can_work_it",
		up_at_spawn and lowered and raised,
		"up at spawn %s, lowered %s, raised again %s" % [up_at_spawn, lowered, raised])
	_despawn_spawned(aloft)

	# ---- A GEAR-UP LANDING: a belly, sliding to a stop, that no rudder turns ---------------
	var belly: Dictionary = server.spawn_pilot(crew, PLANE,
		Vector3(-250.0, 4.5, 350.0), 0.0, Vector3(0.0, 0.0, -6.0))
	var sliding: int = int(belly.get("vehicle", 0))
	_seat_input(belly, {})
	_advance(1, a, _controls())
	var wheels_up: bool = not _gear_of(sliding)
	var touched: Vector3 = Vector3.INF
	var came_to_rest: bool = false
	for tick in range(600):
		_advance(1, a, _controls())
		var now: Array = _relative(sliding, 0)
		if touched == Vector3.INF and (now[0] as Vector3).y < _half_height(PLANE) + 0.3:
			touched = now[0]
		var drift: Vector3 = now[1]
		if touched != Vector3.INF and Vector2(drift.x, drift.z).length() < 0.1:
			came_to_rest = true
			break
	var landed_at: Vector3 = _relative(sliding, 0)[0]
	var slid: float = Vector2(landed_at.x - touched.x, landed_at.z - touched.z).length() \
		if touched != Vector3.INF else INF
	_seat_input(belly, {"rudder": 1.0})
	_advance(60, a, _controls())
	var belly_yaw: float = absf((server.vehicle_state(sliding).get("spin", Vector3.ZERO) as Vector3).y)
	_check("a_gear_up_landing_bellies_to_a_stop_within_a_few_metres",
		wheels_up and came_to_rest and slid <= 5.0,
		"gear up %s, slid %.1f m from touching down at 6 m/s" % [wheels_up, slid])
	_check("and_a_belly_does_not_steer", belly_yaw < 0.05,
		"%.3f rad/s after a second of full rudder" % belly_yaw)
	_despawn_spawned(belly)
	var left: Array = []
	for entity in _vehicle_ids():
		if not already.has(entity):
			left.append(entity)
			server.despawn_vehicle(entity)
	_advance(4, a, _controls())
	if not left.is_empty():
		print("[cockpit] the ground section cleared %d vehicle(s) its pilots left behind" % left.size())


## A capital ship with somebody driving it: under way at full throttle, or lying stopped.
func _a_carrier(client: int, at: Vector3, under_way: bool) -> Dictionary:
	var ship: Dictionary = server.spawn_pilot(client, CARRIER, at, 0.0,
		Vector3(0.0, 0.0, -12.0) if under_way else Vector3.ZERO)
	_seat_input(ship, {"throttle": 1.0 if under_way else 0.0})
	_advance(240, _controls({"throttle": 1.0}), _controls())
	return ship


## A point on a ship's deck, `along` metres towards its stern and `across` to starboard, with
## the aircraft's own hull just clear of it. Ships here point -Z at spawn and hold it.
func _on_deck(ship: int, kind: int, along: float, across: float) -> Vector3:
	var at: Vector3 = server.vehicle_state(ship).get("position", Vector3.ZERO)
	return at + Vector3(across, _half_height(CARRIER) + _half_height(kind) + 0.3, along)


func _half_height(kind: int) -> float:
	return (server.kind_geometry(kind).get("extents", Vector3.ONE) as Vector3).y


## Where a vehicle is and how fast it is going, relative to a ship (or the ground, for 0).
func _relative(vehicle: int, ship: int) -> Array:
	var state: Dictionary = server.vehicle_state(vehicle)
	var at: Vector3 = state.get("position", Vector3.ZERO)
	var moving: Vector3 = state.get("velocity", Vector3.ZERO)
	if ship != 0:
		var hull: Dictionary = server.vehicle_state(ship)
		at -= hull.get("position", Vector3.ZERO) as Vector3
		moving -= hull.get("velocity", Vector3.ZERO) as Vector3
	return [at, moving]


## Where a vehicle is IN THE SHIP'S OWN FRAME, so a ship yawing a fraction of a degree under a
## parked aeroplane forty metres from its middle does not read as the aeroplane moving.
func _on_the_ship(vehicle: int, ship: int) -> Vector3:
	var basis: Quaternion = server.vehicle_state(ship).get("basis", Quaternion.IDENTITY)
	return basis.inverse() * (_relative(vehicle, ship)[0] as Vector3)


## How far an aeroplane taxis in `seconds` at a throttle, from standing, over the ground or a deck.
func _taxi_distance(client: int, kind: int, at: Vector3, ship: int, throttle: float, seconds: float) -> float:
	var carried: Vector3 = server.vehicle_state(ship).get("velocity", Vector3.ZERO) \
		if ship != 0 else Vector3.ZERO
	var craft: Dictionary = server.spawn_pilot(client, kind, at, 0.0, carried)
	_seat_input(craft, {})
	_advance(60, _controls({"throttle": 1.0}), _controls())
	var start: Vector3 = _relative(int(craft.get("vehicle", 0)), ship)[0]
	_seat_input(craft, {"throttle": throttle})
	_advance(int(seconds * TICK_HZ), _controls({"throttle": 1.0}), _controls())
	var gone: Vector3 = _relative(int(craft.get("vehicle", 0)), ship)[0] - start
	_despawn_spawned(craft)
	return Vector2(gone.x, gone.z).length()


## The yaw rate full right rudder has built after one second, on the ground, from a speed.
func _yaw_after_a_second(client: int, kind: int, at: Vector3, speed: float) -> float:
	var craft: Dictionary = server.spawn_pilot(client, kind,
		Vector3(at.x, _half_height(kind) + 0.05, at.z), 0.0, Vector3(0.0, 0.0, -speed))
	_seat_input(craft, {"rudder": 1.0})
	_advance(60, _controls({"throttle": 1.0}), _controls())
	var yaw: float = absf((server.vehicle_state(int(craft.get("vehicle", 0))).get("spin",
		Vector3.ZERO) as Vector3).y)
	_despawn_spawned(craft)
	return yaw


## The gear is on the craft's CONTROLS, beside the flaps and the throttle. `craft_systems` has no
## "gear" key at all, and a first draft reading it saw the gear up on every aircraft whatever the
## simulation did -- which would have passed the squat switch for nothing.
func _gear_of(vehicle: int) -> bool:
	return bool(server.craft_controls(vehicle).get("gear", false))


## Every vehicle the server has, by entity.
func _vehicle_ids() -> Dictionary:
	var ids: Dictionary = {}
	for state in server.vehicle_states():
		ids[int(state.get("entity", 0))] = true
	return ids


## ---- 10. A CAR ON ITS TYRES, AND A BOAT ON ITS KEEL ----------------------------------
##
## Both are the same claim as the aeroplane's, in their own medium: a vehicle goes where
## it is pointing. A car that crabs is on ice and a boat that crabs has lost its keel, and
## in both cases the thing that fixes it is a lateral force that is still worth something
## at a small angle.
##
## The car's is a bicycle model -- a tyre at each axle making a force from its own slip
## angle, applied AT the axle -- so the yaw is a consequence of the front tyre being
## 1.4 m ahead of the centre of mass rather than a rate the code commanded.
func _test_the_car_and_the_boat() -> void:
	var driver: Dictionary = server.spawn_pilot(_spare_client(), CAR,
		Vector3(-100.0, 0.7, 300.0), 0.0, Vector3(0.0, 0.0, -24.0))
	var car: int = int(driver.get("vehicle", 0))
	if car == 0:
		_check("a_test_car_is_driving", false, "no vehicle")
		return
	_seat_input(driver, {"throttle": 0.35})
	_advance(60, _controls(), _controls())
	var rolling: Dictionary = server.vehicle_state(car)
	var straight: float = absf(_sideslip(rolling))

	_seat_input(driver, {"throttle": 0.35, "rudder": 1.0})
	_advance(150, _controls(), _controls())
	var cornering: Dictionary = server.vehicle_state(car)
	var swung: float = absf(rad_to_deg(angle_difference(_heading(_nose(rolling)),
		_heading(_nose(cornering)))))
	_check("full_lock_turns_the_car", swung > 40.0,
		"%.0f degrees of heading in two and a half seconds" % swung)
	_check("the_car_goes_where_it_points",
		straight < 1.0 and absf(_sideslip(cornering)) < 14.0,
		"%.2f degrees of slip straight, %.1f cornering" % [straight,
			_sideslip(cornering)])
	_check("the_car_stays_on_its_wheels",
		((cornering.get("basis", Quaternion.IDENTITY) as Quaternion)
			* Vector3.UP).y > 0.9,
		"up is %.3f" % ((cornering.get("basis", Quaternion.IDENTITY) as Quaternion)
			* Vector3.UP).y)

	# The boat, out past the edge of the ground box, where there is nothing but water.
	var skipper: Dictionary = server.spawn_pilot(_spare_client(), BOAT,
		Vector3(700.0, -0.2, 0.0), 0.0, Vector3.ZERO)
	var boat: int = int(skipper.get("vehicle", 0))
	if boat == 0:
		_check("a_test_boat_is_afloat", false, "no vehicle")
		return
	_seat_input(skipper, {"throttle": 1.0})
	_advance(900, _controls(), _controls())
	var running: Dictionary = server.vehicle_state(boat)
	var way: float = (running.get("velocity", Vector3.ZERO) as Vector3).length()
	# Hull drag alone would let this engine push it to about 60 m/s, which is not a boat.
	# The bow wave is what settles it in the thirties of knots.
	_check("the_hull_has_a_speed_it_cannot_be_powered_past", way > 10.0 and way < 26.0,
		"settled at %.1f m/s on full throttle" % way)
	_check("the_boat_floats",
		absf((running.get("position", Vector3.ZERO) as Vector3).y) < 1.5,
		"riding at y = %.2f" % (running.get("position", Vector3.ZERO) as Vector3).y)

	_seat_input(skipper, {"throttle": 1.0, "rudder": 1.0})
	_advance(180, _controls(), _controls())
	var turning: Dictionary = server.vehicle_state(boat)
	var helm: float = absf(rad_to_deg(angle_difference(_heading(_nose(running)),
		_heading(_nose(turning)))))
	_check("the_helm_turns_the_boat", helm > 25.0,
		"%.0f degrees of heading in three seconds of full helm" % helm)
	# A boat crabs more than a car does, and should -- but it tracks, it does not slide.
	# At twice this rudder it did not: the turn asked the keel for over a g, the keel
	# saturated, and the hull went sideways at 25 degrees of leeway.
	_check("the_boat_follows_its_bow", absf(_sideslip(turning)) < 8.0,
		"%.1f degrees of leeway through the turn" % _sideslip(turning))
	_check("the_boat_stays_upright",
		((turning.get("basis", Quaternion.IDENTITY) as Quaternion) * Vector3.UP).y > 0.9,
		"up is %.3f" % ((turning.get("basis", Quaternion.IDENTITY) as Quaternion)
			* Vector3.UP).y)


## ---- 11. TAKING COMMAND OF THE NEXT CRAFT --------------------------------------------
##
## The left-hand button, and one of a pair: this chooses the CRAFT, the right-hand one
## chooses the SEAT. It ignores distance, which the earlier reach-based control could not
## -- the aeroplanes in this world start a hundred metres away doing 58 m/s, so nobody
## could ever reach one, and a player who spawned in the pod stayed in the pod for ever.
## The pod is a hover model. It flies like a spaceship because it IS one, which is a hard
## thing to work out if you cannot get out of it.
##
## It cycles through craft with a FREE SEAT rather than craft standing EMPTY, so the walk
## goes through the occupied ones as a passenger; suite 12 is about that. Here the two
## parked machines are the targets, because their pilot's seats are free.
func _test_taking_command_of_the_next_machine() -> void:
	var id_b: int = client_b.local_client_id()
	# Two unoccupied machines to reach. Spawned last, so they carry the highest entity ids
	# and the cycle -- which walks forward and wraps -- arrives at them in this order.
	var parked_plane: int = int(server.spawn_vehicle(PLANE, Vector3(-350.0, 0.7, -350.0),
		0.0, Vector3.ZERO))
	var parked_car: int = int(server.spawn_vehicle(CAR, Vector3(-300.0, 0.7, -350.0), 0.0,
		Vector3.ZERO))
	_advance(40, _controls(), _controls())

	var before: int = int(_pilot_of(server, id_b).get("vehicle", 0))
	var presses: int = _press_until(id_b, parked_plane)
	var first: int = int(_pilot_of(server, id_b).get("vehicle", 0))
	_check("the_left_hand_button_takes_the_next_machine",
		first == parked_plane and first != before,
		"walked from vehicle %d to the parked aeroplane %d in %d press(es)" % [
			before, first, presses])
	if first != parked_plane:
		return
	# The pilot's seat when it is free, which is what makes the walk fly each machine
	# rather than ride in it.
	_check("an_empty_craft_hands_over_the_pilots_seat",
		int(server.vehicle_seats(first)[0]) == id_b,
		"seats %s" % [server.vehicle_seats(first)])

	# THE LAUNCH. The aeroplane it just handed over was parked, and an aeroplane cannot fly
	# out of a standstill -- it stalls before it accelerates. The spare aircraft in the
	# world glide down and stop within a minute of nobody flying them, so without this the
	# control hands you a wreck.
	var handed: Dictionary = server.vehicle_state(first)
	var speed: float = (handed.get("velocity", Vector3.ZERO) as Vector3).length()
	var up: Vector3 = (handed.get("basis", Quaternion.IDENTITY) as Quaternion) * Vector3.UP
	_check("taking_a_parked_aeroplane_launches_it",
		speed > 50.0 and (handed.get("position", Vector3.ZERO) as Vector3).y > 100.0,
		"handed over at %.0f m/s and y = %.0f" % [speed,
			(handed.get("position", Vector3.ZERO) as Vector3).y])
	_check("and_hands_it_over_the_right_way_up", up.y > 0.99, "up is %.3f" % up.y)

	# And it FLIES from there, which is the whole point of the control.
	_advance(200, _controls(), _controls({"throttle": 1.0}))
	var flying: Dictionary = server.vehicle_state(first)
	_check("and_it_flies_from_there",
		(flying.get("position", Vector3.ZERO) as Vector3).y > 60.0
			and absf(_sideslip(flying)) < 5.0,
		"y = %.0f, %.1f degrees of sideslip" % [
			(flying.get("position", Vector3.ZERO) as Vector3).y, _sideslip(flying)])

	# Further presses walk on rather than bouncing back to where they came from.
	var more: int = _press_until(id_b, parked_car)
	_check("repeated_presses_walk_the_list",
		int(_pilot_of(server, id_b).get("vehicle", 0)) == parked_car,
		"reached the parked car %d in %d more press(es)" % [parked_car, more])


## Press the take-the-next-craft button until the client lands in `wanted`, or give up.
## Pressed and released each time: the server edge-detects, so a held button moves you once.
func _press_until(client_id: int, wanted: int) -> int:
	var presses: int = 0
	while presses < 20 and int(_pilot_of(server, client_id).get("vehicle", 0)) != wanted:
		_advance(4, _controls(), _controls({"buttons": USE}))
		_advance(40, _controls(), _controls())
		presses += 1
	return presses


## ---- 12. A CREW, AND EVERY SEAT WIRED TO SOMETHING DIFFERENT -------------------------
##
## Two or more players in one craft at the same time, which works because
## `switch_vehicle` cycles through craft with a FREE SEAT rather than craft standing
## EMPTY: B walks the list until they reach the aeroplane A is flying and arrives in the
## next seat along, while A goes on flying it.
##
## And then the point of being aboard. Every seat sends a full control frame -- the wire
## does not know which seat sent it -- and the seat's STATION decides where that frame
## goes. The front two are dual controls and both fly; the back two swing the turret and
## have no authority over the craft at all.
## ONLY THE CREW SEE INTO THE COCKPIT.
##
## Where the levers are in a shared cockpit -- `CrewControls` -- is the largest
## per-vehicle payload after the pose, it goes every tick a hand is moving, and the only
## thing that can perceive it is somebody sitting in that cockpit. So it is withheld from
## everybody else, by the per-client component mask in CockpitWorld::start.
##
## THE NEGATIVE HALF IS WORTHLESS ON ITS OWN. "B does not see A's yoke" also passes if the
## component is broken, never published, or lost in the wire. So all three are checked
## against each other in the same breath:
##
##   the server HAS it        -- the value exists and A is really moving the stick
##   A, who is aboard, has it -- it still reaches the people it is for
##   B, who is not, does not  -- and that is the change
##
## The fourth leg, that B starts receiving it the moment they sit down, is at the end of
## _test_two_players_in_one_craft, where B is aboard the same aeroplane.
func _test_only_the_crew_see_the_cockpit() -> void:
	var id_a: int = client_a.local_client_id()
	var id_b: int = client_b.local_client_id()
	var theirs: int = int(_pilot_of(server, id_a).get("vehicle", 0))
	var b_is_in: int = int(_pilot_of(server, id_b).get("vehicle", 0))
	if theirs == 0 or theirs == b_is_in:
		_check("a_and_b_are_in_different_craft", false,
			"A in %d, B in %d" % [theirs, b_is_in])
		return

	# A holds the stick hard over, well past the 0.008 the publisher treats as movement,
	# and long enough for it to cross the link. B flies their own machine and never
	# touches A's.
	_advance(40, _controls({"throttle": 1.0, "roll": 1.0}), _controls())

	var on_server: float = absf(float((server.crew_controls(theirs)
		.get("linked_stick", Vector2.ZERO) as Vector2).x))
	_check("the_server_knows_where_the_pilots_stick_is", on_server > 0.5,
		"linked_x is %.2f on the server" % on_server)

	var a_here: int = _same_vehicle_on(client_a, theirs)
	var b_here: int = _same_vehicle_on(client_b, theirs)
	_check("both_clients_have_the_aeroplane_itself", a_here != 0 and b_here != 0,
		"A calls it %d, B calls it %d" % [a_here, b_here])
	if a_here == 0 or b_here == 0:
		return

	# B HAS THE VEHICLE, and is meant to: its pose is the aeroplane in the sky. What B
	# must not have is the inside of it.
	_check("a_vehicle_nobody_is_hiding_is_still_replicated",
		client_b.vehicle_state(b_here).has("position"),
		"B has the aeroplane's pose")

	var seen_by_crew: float = absf(float((client_a.crew_controls(a_here)
		.get("linked_stick", Vector2.ZERO) as Vector2).x))
	_check("the_crew_see_their_own_cockpit", seen_by_crew > 0.5,
		"the pilot's own client reads linked_x %.2f" % seen_by_crew)

	var seen_by_stranger: float = absf(float((client_b.crew_controls(b_here)
		.get("linked_stick", Vector2.ZERO) as Vector2).x))
	_check("and_nobody_else_does", seen_by_stranger < 0.01,
		"a client not aboard reads linked_x %.2f, where the cockpit says %.2f"
			% [seen_by_stranger, on_server])

	# AND THE REST OF THE VEHICLE IS UNTOUCHED. Withholding one component must not cost
	# the ones an outside observer genuinely needs -- the gear and flaps they can see
	# hanging off the wing, the turret tracking them.
	_check("the_bus_still_reaches_everybody",
		not client_b.craft_controls(b_here).is_empty()
			and not client_b.craft_systems(b_here).is_empty(),
		"B still has the craft's bus and systems")

	_advance(40, _controls({"throttle": 1.0}), _controls())


func _test_two_players_in_one_craft() -> void:
	var id_a: int = client_a.local_client_id()
	var id_b: int = client_b.local_client_id()
	var theirs: int = int(_pilot_of(server, id_a).get("vehicle", 0))
	if theirs == 0:
		_check("a_is_still_flying_something", false, "no vehicle")
		return

	# B walks the list until they reach A's aeroplane. An aircraft with somebody in seat 0
	# and three seats spare is always a candidate, so this arrives.
	var presses: int = 0
	while presses < 16 and int(_pilot_of(server, id_b).get("vehicle", 0)) != theirs:
		_advance(2, _controls({"throttle": 1.0}), _controls({"buttons": USE}))
		_advance(24, _controls({"throttle": 1.0}), _controls())
		presses += 1
	var joined: int = int(_pilot_of(server, id_b).get("vehicle", 0))
	_check("a_second_player_can_board_an_occupied_craft", joined == theirs,
		"B reached A's aircraft %d after %d presses" % [joined, presses])
	if joined != theirs:
		return

	var crew: PackedInt64Array = server.vehicle_seats(theirs)
	_check("the_pilot_keeps_the_pilots_seat", int(crew[0]) == id_a, "seats %s" % [crew])
	_check("the_second_player_takes_the_next_station",
		int(_pilot_of(server, id_b).get("seat", 0)) == 1 and crew.has(id_b),
		"B is in seat %d" % int(_pilot_of(server, id_b).get("seat", 0)))
	_check("that_station_is_the_copilots",
		_station_of(PLANE, 1) == "copilot" and _flies(PLANE, 1)
			and _station_of(PLANE, 2) == "turret" and not _flies(PLANE, 2),
		"seat 1 is %s, seat 2 is %s" % [_station_of(PLANE, 1), _station_of(PLANE, 2)])

	# Both of them, in the same aircraft, on BOTH clients. A crew that only exists on the
	# server is not a crew anybody can fly with.
	var aboard_a: int = _crew_seen_by(client_a, id_a, id_b)
	var aboard_b: int = _crew_seen_by(client_b, id_a, id_b)
	_check("both_clients_see_both_of_them_in_it", aboard_a == 2 and aboard_b == 2,
		"A sees %d of the crew in one vehicle, B sees %d" % [aboard_a, aboard_b])

	# ---- THE COPILOT CAN FLY -----------------------------------------------------
	#
	# A holds the throttle and nothing else; B rolls. The aeroplane rolls, because dual
	# controls means both seats are on the linkage and neither has to be handed anything.
	#
	# Measured as the ROLL RATE rather than the bank angle, because bank is periodic: held
	# for a second at this roll rate the aeroplane goes right round, and an angle read at
	# the end of that says nothing at all. The rate is unambiguous.
	_advance(50, _controls({"throttle": 1.0}), _controls({"roll": 1.0}))
	var copilots: float = _roll_rate(server.vehicle_state(theirs))
	_check("the_copilots_stick_flies_the_aircraft", copilots > 0.7,
		"rolling right at %.2f rad/s on the copilot's stick alone" % copilots)

	# ---- AND SITTING DOWN OPENS THE COCKPIT --------------------------------------
	#
	# The fourth leg of _test_only_the_crew_see_the_cockpit, and the one that makes the
	# other three mean anything: B could not see this cockpit a moment ago, and can now,
	# because B is IN it. Without this, "B does not see A's yoke" would pass just as well
	# if the linkage were broken outright.
	#
	# B is the one rolling, so the linkage is theirs -- but it is read here from A's
	# machine as well, because the point of publishing it is that each seat can watch the
	# other's controls move.
	_advance(20, _controls({"throttle": 1.0}), _controls({"roll": 1.0}))
	var b_here: int = _same_vehicle_on(client_b, theirs)
	var a_here: int = _same_vehicle_on(client_a, theirs)
	var now_seen: float = absf(float((client_b.crew_controls(b_here)
		.get("linked_stick", Vector2.ZERO) as Vector2).x)) if b_here != 0 else 0.0
	var pilot_sees: float = absf(float((client_a.crew_controls(a_here)
		.get("linked_stick", Vector2.ZERO) as Vector2).x)) if a_here != 0 else 0.0
	_check("sitting_down_opens_the_cockpit", now_seen > 0.5,
		"the new copilot reads linked_x %.2f, having read 0.00 from outside" % now_seen)
	_check("and_the_other_seat_watches_it_move", pilot_sees > 0.5,
		"the pilot reads the copilot's stick at %.2f" % pilot_sees)

	_advance(60, _controls({"throttle": 1.0}), _controls())

	# ---- AND THE AEROPLANE GETS THE AVERAGE --------------------------------------
	#
	# Which is what two columns on one linkage physically do: they move together, so what
	# the aeroplane gets is one position rather than two demands. Pull three quarters of
	# the way against each other and it does a quarter of something.
	_advance(50, _controls({"throttle": 1.0, "roll": 1.0}), _controls({"roll": -0.25}))
	var contested: float = _roll_rate(server.vehicle_state(theirs))
	_check("the_aeroplane_gets_the_average_of_the_two",
		contested > 0.15 and contested < copilots,
		"full against a quarter gives %.2f rad/s, where one stick alone gives %.2f"
			% [contested, copilots])
	_advance(60, _controls({"throttle": 1.0}), _controls())

	# ---- THE BACK SEAT IS WIRED TO SOMETHING ELSE ENTIRELY -----------------------
	#
	# B moves back one seat, which is a turret station. The same stick that was flying the
	# aeroplane a moment ago now swings a barrel and does not touch the flight controls.
	_advance(2, _controls({"throttle": 1.0}), _controls({"buttons": SEAT}))
	_advance(50, _controls({"throttle": 1.0}), _controls())
	_check("the_seat_button_moves_them_back_a_station",
		int(_pilot_of(server, id_b).get("seat", 0)) == 2
			and int(_pilot_of(server, id_b).get("vehicle", 0)) == theirs,
		"B is in seat %d of the same aircraft" % int(
			_pilot_of(server, id_b).get("seat", 0)))

	var aimed: float = _turret_of(server, theirs).x
	_advance(90, _controls({"throttle": 1.0}), _controls({"roll": 1.0}))
	var still: Dictionary = server.vehicle_state(theirs)
	_check("a_turret_station_swings_the_turret",
		absf(angle_difference(_turret_of(server, theirs).x, aimed)) > 0.5,
		"the barrel swung %.0f degrees" % rad_to_deg(absf(angle_difference(
			_turret_of(server, theirs).x, aimed))))
	_check("and_does_not_touch_the_flight_controls",
		absf(_roll_rate(still)) < 0.3,
		"the aeroplane is rolling at %.2f rad/s with the gunner hard over"
			% _roll_rate(still))

	# The turret is on the wire like everything else on a vehicle, so both clients can see
	# where the gunner is looking.
	var truth: float = _turret_of(server, theirs).x
	_check("where_the_gunner_is_looking_reaches_everybody",
		absf(angle_difference(_turret_of(client_a, theirs).x, truth)) < 0.3
			and absf(angle_difference(_turret_of(client_b, theirs).x, truth)) < 0.3,
		"server %.2f, A %.2f, B %.2f rad" % [truth, _turret_of(client_a, theirs).x,
			_turret_of(client_b, theirs).x])
	_advance(60, _controls({"throttle": 1.0}), _controls())

	# ---- AND NOT JUST A PAIR: the whole crew --------------------------------------
	#
	# Four seats is the limit, and it is a wire limit rather than a gameplay one: Seats is
	# four occupant bytes in the packet. Two more players board the same aeroplane using
	# the same button, so it carries a pilot, a copilot and two turret stations at once.
	var crowd: Array = []
	for i in range(2):
		crowd.append(server.spawn_pilot(_spare_client(), POD,
			Vector3(-200.0 - 40.0 * i, 60.0, -200.0), 0.0, Vector3.ZERO))
	_advance(40, _controls({"throttle": 1.0}), _controls())
	for rider in crowd:
		var who: int = _client_of(rider)
		for attempt in range(3):
			if int(_pilot_of(server, who).get("vehicle", 0)) == theirs:
				break
			_seat_input(rider, {"buttons": USE})
			_advance(4, _controls({"throttle": 1.0}), _controls())
			_seat_input(rider, {})
			_advance(50, _controls({"throttle": 1.0}), _controls())

	var full: PackedInt64Array = server.vehicle_seats(theirs)
	var occupied: int = 0
	var distinct: Dictionary = {}
	for who in full:
		if int(who) != -1:
			occupied += 1
			distinct[int(who)] = true
	_check("a_craft_carries_a_whole_crew", occupied == 4 and distinct.size() == 4,
		"four players in one aeroplane, one per seat: %s" % [full])
	_check("the_pilot_is_still_the_pilot", int(full[0]) == id_a,
		"seat 0 is still A: %s" % [full])
	_check("and_it_is_still_flying_normally",
		(server.vehicle_state(theirs).get("velocity", Vector3.ZERO) as Vector3).length()
			> 30.0 and absf(_sideslip(server.vehicle_state(theirs))) < 6.0,
		"%.0f m/s at %.1f degrees of sideslip with four aboard" % [
			(server.vehicle_state(theirs).get("velocity", Vector3.ZERO)
				as Vector3).length(),
			_sideslip(server.vehicle_state(theirs))])

	# All four on both clients, because a crew that only exists on the server is not one
	# anybody can fly with.
	_check("every_client_sees_the_whole_crew",
		_riders_in(client_a, theirs) == 4 and _riders_in(client_b, theirs) == 4,
		"A sees %d aboard, B sees %d" % [_riders_in(client_a, theirs),
			_riders_in(client_b, theirs)])

	# And with the aircraft full, the button leaves it alone rather than throwing somebody
	# out to make room.
	var stayed: int = int(_pilot_of(server, _client_of(crowd[0])).get("vehicle", 0))
	var newcomer: Dictionary = server.spawn_pilot(_spare_client(), POD,
		Vector3(-320.0, 60.0, -200.0), 0.0, Vector3.ZERO)
	_seat_input(newcomer, {"buttons": USE})
	_advance(4, _controls({"throttle": 1.0}), _controls())
	_seat_input(newcomer, {})
	_advance(50, _controls({"throttle": 1.0}), _controls())
	# FULL, AND THE WATCHED CREW MEMBER ABOARD, or "nobody was displaced" is true of a craft with room and a crowd member
	# still sitting in their own pod.
	_check("a_full_craft_turns_people_away",
		occupied == 4 and distinct.size() == 4 and stayed == theirs
			and int(_pilot_of(server, _client_of(newcomer)).get("vehicle", 0)) != theirs
			and int(_pilot_of(server, _client_of(crowd[0])).get("vehicle", 0)) == stayed,
		"the fifth went to vehicle %d instead, and nobody was displaced" % int(
			_pilot_of(server, _client_of(newcomer)).get("vehicle", 0)))


## How fast the aircraft is rolling, in rad/s about its own nose. Positive is right wing
## dropping, which is what a roll input of +1 asks for.
##
## Used instead of the bank ANGLE wherever a control is held for more than a moment: bank
## is periodic, so an aeroplane held in a roll goes right round and the angle at the end
## says nothing.
func _roll_rate(state: Dictionary) -> float:
	var nose: Vector3 = (state.get("basis", Quaternion.IDENTITY) as Quaternion) \
		* Vector3(0.0, 0.0, -1.0)
	return (state.get("spin", Vector3.ZERO) as Vector3).dot(nose)


## Where one world thinks a vehicle's turret is pointing.
##
## Entity ids are PER-WORLD -- the server's aeroplane is a different number on a client --
## and the two worlds agree on exactly one thing about a vehicle: the client ids of the
## people sitting in it. So the crew is the bridge, not the id, and not the kind either:
## by this point in the run there are several aeroplanes and matching on kind finds the
## wrong one, which is how this check first reported a turret that had not moved.
func _turret_of(world, server_entity: int) -> Vector2:
	if world == server:
		return server.vehicle_state(server_entity).get("turret", Vector2.ZERO)
	for state in server.pilot_states():
		if int(state.get("vehicle", 0)) != server_entity:
			continue
		var here: int = int(_pilot_of(world, int(state["client"])).get("vehicle", 0))
		if here != 0:
			return world.vehicle_state(here).get("turret", Vector2.ZERO)
	return Vector2.ZERO


## What the stick in front of one seat of one kind is wired to.
func _station_of(kind: int, seat: int) -> String:
	return String(server.seat_pose(kind, seat).get("station", "?"))


func _flies(kind: int, seat: int) -> bool:
	return bool(server.seat_pose(kind, seat).get("flies", false))


## Which client id a server-spawned pilot belongs to.
func _client_of(spawned: Dictionary) -> int:
	var pilot: int = int(spawned.get("pilot", 0))
	for state in server.pilot_states():
		if int(state["entity"]) == pilot:
			return int(state["client"])
	return 0


## How many pilots one world sees in a given vehicle.
func _riders_in(world, vehicle_entity: int) -> int:
	# Entity ids are per-world, so the vehicle is found by matching what its OWN pilots say
	# rather than by id. The server's number is the one the crew agree on.
	var wanted: Dictionary = {}
	for state in server.pilot_states():
		if int(state.get("vehicle", 0)) == vehicle_entity:
			wanted[int(state["client"])] = true
	var count: int = 0
	for state in world.pilot_states():
		if wanted.has(int(state["client"])):
			count += 1
	return count


## How many of the two named clients one world sees in the SAME vehicle.
func _crew_seen_by(world, first: int, second: int) -> int:
	var where: int = 0
	for pilot in world.pilot_states():
		if int(pilot["client"]) == first:
			where = int(pilot.get("vehicle", 0))
	if where == 0:
		return 0
	var count: int = 0
	for pilot in world.pilot_states():
		var who: int = int(pilot["client"])
		if (who == first or who == second) and int(pilot.get("vehicle", 0)) == where:
			count += 1
	return count


## ---- 13. TAKING AN AUTOPILOT'S VEHICLE, AND GIVING IT BACK --------------------------
##
## An AI vehicle is an ordinary replicated vehicle with every seat empty. The take-the-next
## craft button walks into one like any other, and from that moment a human in seat 0 wins:
## `drive_vehicle` reads their stick and never asks the autopilot. Leaving hands it back.
##
## The handover is where the bugs live, in both directions. Going in, the destination has
## to come OFF the wire, because a vehicle somebody is flying is not going anywhere in
## particular and a beacon standing in a field is worse than none. Coming out, the
## autopilot must not resume from the integrators it had when it was interrupted: it may be
## a long way from where it last knew it was, at an attitude it did not choose, and picking
## up where it left off puts a lurch in exactly the moment the player is watching from the
## seat behind.
func _test_taking_over_an_autopilot() -> void:
	var id_b: int = client_b.local_client_id()
	# Two places to drive between, and a car to do it, on ground the loopback already has.
	server.add_ai_waypoint(CAR, Vector3(-300.0, 0.7, -300.0))
	server.add_ai_waypoint(CAR, Vector3(300.0, 0.7, 300.0))
	var robot: int = int(server.spawn_ai_vehicle(CAR, Vector3(-320.0, 0.7, -320.0), 0.0,
		Vector3.ZERO))
	_check("an_ai_vehicle_spawns", robot != 0, "entity %d" % robot)
	if robot == 0:
		return
	_advance(120, _controls(), _controls())

	var rolling: Dictionary = server.vehicle_state(robot)
	_check("it_picks_a_destination_and_drives", bool(rolling.get("has_route", false))
			and (rolling.get("velocity", Vector3.ZERO) as Vector3).length() > 1.0,
		"heading for %v at %.1f m/s" % [rolling.get("route", Vector3.ZERO),
			(rolling.get("velocity", Vector3.ZERO) as Vector3).length()])
	_check("and_the_destination_is_on_the_wire",
		_route_seen_by(client_a, robot) or _route_seen_by(client_b, robot),
		"a client can see where it is going without asking the server")
	_check("and_every_seat_on_it_is_free",
		int(server.vehicle_seats(robot)[0]) == -1,
		"seats %s" % [server.vehicle_seats(robot)])

	# B walks into it.
	var presses: int = _press_until(id_b, robot)
	_check("a_player_can_take_an_autopilots_vehicle",
		int(_pilot_of(server, id_b).get("vehicle", 0)) == robot,
		"boarded after %d press(es)" % presses)
	if int(_pilot_of(server, id_b).get("vehicle", 0)) != robot:
		return

	# Held hard over, one way, by a human. The autopilot would not do this.
	_advance(150, _controls(), _controls({"throttle": 1.0, "rudder": 1.0}))
	var driven: Dictionary = server.vehicle_state(robot)
	_check("the_autopilot_hands_over_to_the_human",
		not bool(driven.get("has_route", false)),
		"no destination while somebody is flying it")
	_check("and_the_human_is_actually_driving_it",
		(driven.get("spin", Vector3.ZERO) as Vector3).length() > 0.2,
		"turning at %.2f rad/s under full lock" % (driven.get("spin", Vector3.ZERO)
			as Vector3).length())

	# And out again.
	_advance(4, _controls(), _controls({"buttons": USE}))
	_advance(180, _controls(), _controls())
	var handed_back: Dictionary = server.vehicle_state(robot)
	_check("leaving_hands_it_back_to_the_autopilot",
		int(_pilot_of(server, id_b).get("vehicle", 0)) != robot
			and bool(handed_back.get("has_route", false)),
		"back on a route to %v" % handed_back.get("route", Vector3.ZERO))
	var before: Vector3 = handed_back.get("position", Vector3.ZERO)
	_advance(240, _controls(), _controls())
	_check("and_it_drives_off_again",
		before.distance_to(server.vehicle_state(robot).get("position", Vector3.ZERO))
			> 20.0,
		"moved %.0f m in two seconds" % before.distance_to(
			server.vehicle_state(robot).get("position", Vector3.ZERO)))


## Can this world see where the given server vehicle is going? Entity ids are per-world, so
## the vehicle is found by kind -- there is only one car in this corner of the test.
func _route_seen_by(world, server_entity: int) -> bool:
	var kind: int = -1
	for vehicle in server.vehicle_states():
		if int(vehicle["entity"]) == server_entity:
			kind = int(vehicle["kind"])
	for vehicle in world.vehicle_states():
		if int(vehicle["kind"]) == kind and bool(vehicle.get("has_route", false)):
			return true
	return false


## ---- 14. FOUR AEROPLANES IN FINGER FOUR ---------------------------------------------
##
## A follower holds a slot in the LEADER'S frame and never steers at it. Flying at a
## bearing is what an autopilot chasing a point does, and here it fails in a way that only
## shows up in the air: a lead turn swings the slot into the follower's rear hemisphere, a
## bearing controller sees 170 degrees of error, and it answers with a full circle.
##
## So the heading bug is the leader's heading plus a CLAMPED intercept -- and the clamp and
## the aim point are both SCHEDULED on how far across the follower is. A single look-ahead
## cannot do it: short enough to drag one back from two hundred metres and the intercept
## saturates for anything over about fifty, which is bang-bang control. Full cut, overshoot,
## full cut back. Measured before the scheduling, that was 61 m of crosstrack error against
## 18 m along track and 0 m vertically -- not a follower failing to catch up, one swinging
## through its slot.
func _test_a_flight_holds_its_slots() -> void:
	# Two places to fly between, far enough apart that the flight spends the run turning.
	for at in [Vector3(-2400.0, 700.0, 0.0), Vector3(2400.0, 700.0, 600.0),
			Vector3(0.0, 760.0, -2400.0)]:
		server.add_ai_waypoint(PLANE, at)
	var cruise := Vector3(0.0, 0.0, -58.0)
	var lead: int = int(server.spawn_ai_vehicle(PLANE, Vector3(0.0, 700.0, 1800.0), 0.0,
		cruise))
	_check("a_flight_leader_takes_off", lead != 0, "entity %d" % lead)
	if lead == 0:
		return

	# Finger four: one on the right, two stepped away to the left.
	var slots: Array[Vector3] = [Vector3(48.0, -8.0, 58.0), Vector3(-48.0, -8.0, 58.0),
		Vector3(-98.0, -16.0, 120.0)]
	var wing: Array[int] = []
	for slot in slots:
		# Born in place. Yaw is zero, so the leader's frame is the world's.
		var at := Vector3(slot.x, 700.0 + slot.y, 1800.0 + slot.z)
		var follower: int = int(server.spawn_ai_vehicle(PLANE, at, 0.0, cruise))
		wing.append(follower)
		_check("a_wingman_joins", server.set_ai_leader(follower, lead, slot),
			"entity %d in slot %v" % [follower, slot])

	# A formation with nobody deciding where it goes is not a formation, and nothing about
	# it looks wrong from outside.
	_check("a_circular_formation_is_refused",
		not server.set_ai_leader(lead, wing[0], Vector3.ZERO),
		"the leader may not follow its own wingman")

	# Long enough to fly at least one leg and turn onto the next.
	_advance(2400, _controls(), _controls())

	var worst: float = 0.0
	var total: float = 0.0
	var across: float = 0.0
	var along: float = 0.0
	var vertical: float = 0.0
	for i in range(wing.size()):
		var gap: Vector3 = _slot_gap(lead, slots[i], wing[i])
		total += gap.length()
		worst = maxf(worst, gap.length())
		across += absf(gap.x)
		vertical += absf(gap.y)
		along += absf(gap.z)
	var mean: float = total / float(wing.size())
	_check("the_flight_holds_its_slots", mean < 45.0 and worst < 90.0,
		"average %.0f m out (%.0f across, %.0f along, %.0f vertical), worst %.0f m" % [
			mean, across / 3.0, along / 3.0, vertical / 3.0, worst])
	_check("and_nobody_flew_a_circle_to_get_there",
		_all_pointing_with(lead, wing),
		"every wingman is within a quarter turn of the leader's heading")


## How far a follower is from its slot, IN THE LEADER'S FRAME: x across, y up, z behind.
func _slot_gap(lead: int, slot: Vector3, follower: int) -> Vector3:
	var leader: Dictionary = server.vehicle_state(lead)
	var at: Vector3 = server.vehicle_state(follower).get("position", Vector3.ZERO)
	var forward: Vector3 = (leader.get("basis", Quaternion.IDENTITY) as Quaternion) \
		* Vector3(0.0, 0.0, -1.0)
	forward.y = 0.0
	if forward.length_squared() < 1e-6:
		return Vector3.ZERO
	forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var want: Vector3 = (leader.get("position", Vector3.ZERO) as Vector3) \
		+ right * slot.x + Vector3(0.0, slot.y, 0.0) - forward * slot.z
	var gap: Vector3 = at - want
	return Vector3(gap.dot(right), gap.y, -gap.dot(forward))


## THE ANTI-360, checked directly: a follower that answered a lead turn by flying a circle
## is pointing somewhere else entirely by the time anybody looks.
func _all_pointing_with(lead: int, wing: Array[int]) -> bool:
	var leader_heading: float = _heading(_nose(server.vehicle_state(lead)))
	for follower in wing:
		if absf(angle_difference(leader_heading,
				_heading(_nose(server.vehicle_state(follower))))) > PI * 0.5:
			return false
	return true


## ---- 15. THE COMMAND BUS -------------------------------------------------------------
##
## A crew shares more than a stick. Gear, flaps, a throttle lever, which weapon is
## selected, which radio channel -- all of it has to reach everyone aboard, and none of it
## belongs in ControlInput, which is one pilot's momentary demand and is deliberately never
## replicated to anybody.
##
## So the bus lives on the VEHICLE, in TWO components, and the split is the one that
## matters: whether the SIMULATION reads it.
##
##   CraftControls -- gear, flaps, throttle. The physics reads these, so a client
##                    predicting this vehicle predicts them too and a disagreement is worth
##                    a rollback like any other state that moves the aeroplane.
##   CraftSystems  -- weapon, radio, lights. Nothing outside the cockpit can tell, so
##                    resimulating the world because one changed would be paying a physics
##                    price for a switch.
##
## That is the whole reason for two components: should_roll_back cannot be answered
## differently for two halves of one.
func _test_the_command_bus() -> void:
	var id_a: int = client_a.local_client_id()
	var id_b: int = client_b.local_client_id()
	var craft: int = int(_pilot_of(server, id_a).get("vehicle", 0))
	if craft == 0:
		_check("a_crew_has_a_craft", false, "nobody is flying anything")
		return

	# WHAT THIS KIND OF CRAFT HAS, which is not what every kind has. The wire only ever
	# carries a channel number and a value; everything that makes one mean "flaps" and
	# another "collective trim" is in the schema.
	var plane_bus: Dictionary = server.craft_schema(PLANE)
	var heli_bus: Dictionary = server.craft_schema(HELI)
	_check("a_craft_says_what_it_is_fitted_with",
		(plane_bus.get("channels", []) as Array).size() > 4,
		"the aeroplane has %d channels: %s" % [
			(plane_bus.get("channels", []) as Array).size(),
			_channel_names(plane_bus)])
	_check("and_different_craft_are_fitted_differently",
		_has_channel(plane_bus, "flaps") and not _has_channel(heli_bus, "flaps")
			and _has_channel(heli_bus, "hover hold"),
		"the aeroplane has flaps and the helicopter does not: %s" %
			_channel_names(heli_bus))

	# A is in the pilot's seat and B is aboard somewhere. By this point in the run the
	# aeroplane is FULL -- suite 12 put two more aboard -- so B is in a turret station,
	# which is exactly the pair of seats this suite wants: one that may work the gear and
	# one that may not.
	#
	# BOUNDED waits. An unbounded one in a test is not a failing test, it is a hung one,
	# and a hung test tells you nothing at all about what went wrong.
	for attempt in range(20):
		if int(_pilot_of(server, id_b).get("vehicle", 0)) == craft:
			break
		_advance(4, _controls(), _controls({"buttons": USE}))
		_advance(40, _controls(), _controls())
	var crew: PackedInt64Array = server.vehicle_seats(craft)
	_check("the_crew_is_aboard",
		int(crew[0]) == id_a and crew.has(id_b)
			and int(_pilot_of(server, id_b).get("seat", 0)) != 0,
		"A flying it, B aboard in seat %d: %s" % [
			int(_pilot_of(server, id_b).get("seat", 0)), crew])

	# ---- the physical half ---------------------------------------------------------
	#
	# The COPILOT puts the gear down and the flaps out. Both are flying stations, so both
	# may, and the aeroplane is a different aeroplane afterwards.
	var clean: Dictionary = server.craft_controls(craft)
	_command(client_a, 3, 1)          # gear down
	_advance(60, _controls({"throttle": 1.0}), _controls())
	_command(client_a, 1, 3)          # full flap
	_advance(60, _controls({"throttle": 1.0}), _controls())
	var dirty: Dictionary = server.craft_controls(craft)
	_check("the_pilot_can_work_the_gear_and_flaps",
		bool(dirty.get("gear", false)) and float(dirty.get("flaps", 0.0)) > 0.9
			and not bool(clean.get("gear", true)),
		"gear %s, flaps %.2f" % [dirty.get("gear", false), dirty.get("flaps", 0.0)])

	# EVERYONE ABOARD SEES IT, off the wire, without asking the server.
	_check("and_the_whole_crew_sees_it",
		_bus_seen_by(client_a, craft) and _bus_seen_by(client_b, craft),
		"both clients have the gear down and the flaps out")

	# AND THE AEROPLANE FLIES DIFFERENTLY. Gear and flaps hanging out is drag, which is
	# the whole point of calling this half physical.
	var dragging: float = _settled_speed(craft)
	_command(client_a, 3, 0)
	_command(client_a, 1, 0)
	_advance(60, _controls({"throttle": 1.0}), _controls())
	var clean_speed: float = _settled_speed(craft)
	_check("and_it_is_a_different_aeroplane_with_them_out",
		clean_speed > dragging + 4.0,
		"%.0f m/s clean against %.0f m/s with the gear and flaps out" % [clean_speed,
			dragging])

	# ---- the internal half ---------------------------------------------------------
	#
	# A gunner may change weapons from the back seat. A gunner may NOT put the gear down.
	_command(client_b, 8, 2)           # weapon
	_command(client_b, 9, 7)           # radio
	_advance(80, _controls({"throttle": 1.0}), _controls())
	var systems: Dictionary = server.craft_systems(craft)
	_check("a_back_seat_can_work_the_internal_systems",
		int(systems.get("weapon", 0)) == 2 and int(systems.get("radio", 0)) == 7,
		"weapon %d, radio %d" % [systems.get("weapon", 0), systems.get("radio", 0)])
	_check("and_that_reaches_the_whole_crew_too",
		int(_systems_seen_by(client_a, craft).get("weapon", -1)) == 2
			and int(_systems_seen_by(client_b, craft).get("weapon", -1)) == 2,
		"both clients have weapon 2 selected")

	var before_gear: bool = bool(server.craft_controls(craft).get("gear", false))
	_command(client_b, 3, 1)
	_advance(80, _controls({"throttle": 1.0}), _controls())
	_check("but_a_back_seat_may_not_work_the_gear",
		bool(server.craft_controls(craft).get("gear", false)) == before_gear,
		"the gear is still %s from a turret station" % before_gear)

	# A channel this craft is not fitted with is REFUSED rather than quietly ignored.
	var untouched: Dictionary = server.craft_systems(craft)
	_command(client_b, 11, 1)          # hover hold: a helicopter thing
	_advance(60, _controls({"throttle": 1.0}), _controls())
	_check("a_channel_the_craft_does_not_have_does_nothing",
		int(server.craft_systems(craft).get("mode", -1))
			== int(untouched.get("mode", -1)),
		"an aeroplane has no hover hold")


## ---- the master arm is the craft's, on every machine aboard -------------------------------------------------
##
## THE MASTER ARM SWITCH IN FRONT OF EVERY SEAT SHOWS ONE THING, because the cockpit draws every one of them from the
## craft's systems (cockpit tests/shared_controls.gd, 770aa14) -- so what has to be true here is that the craft's
## systems ARE one thing on every machine aboard, whoever threw it.
##
## A BACK SEAT ARMS. Master is a system channel, which apply_command takes from any seat. The server has it; the
## PILOT'S machine has it -- which is the leg that matters, because it predicts this aeroplane and an authoritative value
## it cannot compute for itself only arrives on a rollback (CraftSystems' should_roll_back, on any flags difference) --
## and the back seat's own machine has it, drawn through its interpolation buffer. Then the pilot disarms, and every
## machine sees that.
##
## COUNTED FROM THE SEND, because send-to-display is what a person at the other seat sees. Expected at 60 Hz with a
## 4-tick link each way (ashiato-missile's review): the server about 5-6 ticks after the send, the pilot's rollback about
## 4-6 after that. The bound is 28, over twice that, because a crowded loopback does not put every aeroplane in every
## packet. Sent with `send_command` and not `_command`, which advances six ticks of its own. Run straight after
## `_test_the_command_bus`, which leaves A flying the plane and B aboard it in a turret seat; nothing after it depends on
## the master arm, and it is left where it was found.
func _test_the_master_arm_is_the_crafts() -> void:
	var id_a: int = client_a.local_client_id()
	var id_b: int = client_b.local_client_id()
	var craft: int = int(_pilot_of(server, id_a).get("vehicle", 0))
	var b_seat: int = int(_pilot_of(server, id_b).get("seat", 0))
	_check("the_crew_is_still_aboard_for_the_master_arm",
		craft != 0 and int(_pilot_of(server, id_b).get("vehicle", 0)) == craft and not _flies(PLANE, b_seat),
		"A in %d, B in seat %d of %d" % [craft, b_seat, int(_pilot_of(server, id_b).get("vehicle", 0))])
	if craft == 0 or int(_pilot_of(server, id_b).get("vehicle", 0)) != craft:
		return
	var was: bool = bool(server.craft_systems(craft).get("master", false))
	var bound: int = LINK_DELAY_TICKS * 2 + 20

	# ---- the back seat throws it --------------------------------------------------------
	var b_taken: bool = client_b.send_command(MASTER, 0 if was else 1)
	_check("the_back_seats_master_command_is_taken", b_taken,
		"send_command %s it" % ["accepted" if b_taken else "refused (the queue was full)"])
	var thrown: Dictionary = _ticks_until_every_machine_shows(craft, not was, 120)
	_check("a_back_seat_throws_the_master_arm_and_the_craft_takes_it", int(thrown["server"]) >= 0,
		"server shows %s %d ticks after the send" % [not was, thrown["server"]])
	_check("and_the_pilots_predicting_machine_shows_it_within_the_bound",
		int(thrown["a"]) >= 0 and int(thrown["a"]) <= bound,
		"%d ticks after the send, server at %d, bound %d, link %d each way" % [thrown["a"], thrown["server"], bound,
			LINK_DELAY_TICKS])
	_check("and_so_does_the_back_seats_own_within_the_bound",
		int(thrown["b"]) >= 0 and int(thrown["b"]) <= bound,
		"%d ticks after the send, bound %d" % [thrown["b"], bound])

	# ---- and the pilot throws it back ----------------------------------------------------
	var a_taken: bool = client_a.send_command(MASTER, 1 if was else 0)
	_check("the_pilots_master_command_is_taken", a_taken,
		"send_command %s it" % ["accepted" if a_taken else "refused (the queue was full)"])
	var back: Dictionary = _ticks_until_every_machine_shows(craft, was, 120)
	_check("the_pilot_throws_it_back_and_the_craft_takes_it", int(back["server"]) >= 0,
		"server shows %s %d ticks after the send" % [was, back["server"]])
	_check("and_the_back_seat_shows_that_within_the_bound", int(back["b"]) >= 0 and int(back["b"]) <= bound,
		"%d ticks after the send, bound %d" % [back["b"], bound])
	_check("and_the_pilots_own_machine_agrees", int(back["a"]) >= 0 and int(back["a"]) <= bound,
		"%d ticks after the send" % back["a"])


## THE TICK, COUNTED FROM NOW, AT WHICH THE SERVER, A AND B EACH FIRST SHOW MASTER AS `armed`, or -1 for a machine that
## never does within `limit`. A holds the throttle open; B's hands are in its lap.
func _ticks_until_every_machine_shows(craft: int, armed: bool, limit: int) -> Dictionary:
	var seen: Dictionary = {"server": -1, "a": -1, "b": -1}
	for tick in range(limit):
		if int(seen["server"]) < 0 and bool(server.craft_systems(craft).get("master", not armed)) == armed:
			seen["server"] = tick
		if int(seen["a"]) < 0 and bool(_systems_seen_by(client_a, craft).get("master", not armed)) == armed:
			seen["a"] = tick
		if int(seen["b"]) < 0 and bool(_systems_seen_by(client_b, craft).get("master", not armed)) == armed:
			seen["b"] = tick
		if int(seen["server"]) >= 0 and int(seen["a"]) >= 0 and int(seen["b"]) >= 0:
			break
		_advance(1, _controls({"throttle": 1.0}), _controls())
	return seen


## Send one command from a client, and let it reach the server.
func _command(world, channel: int, value: int) -> void:
	world.send_command(channel, value)
	_advance(6, _controls({"throttle": 1.0}), _controls({"throttle": 1.0}))


## What a client can see of a craft's physical bus, found by kind because entity ids are
## per-world.
func _bus_seen_by(world, server_entity: int) -> bool:
	var here: int = _same_vehicle_on(world, server_entity)
	if here == 0:
		return false
	var bus: Dictionary = world.craft_controls(here)
	return bool(bus.get("gear", false)) and float(bus.get("flaps", 0.0)) > 0.9


func _systems_seen_by(world, server_entity: int) -> Dictionary:
	var here: int = _same_vehicle_on(world, server_entity)
	return world.craft_systems(here) if here != 0 else {}


## The same vehicle, on another world. Its CREW is the bridge: entity ids are per-world and
## the client ids in the seats are the only thing both sides agree on.
func _same_vehicle_on(world, server_entity: int) -> int:
	for state in server.pilot_states():
		if int(state.get("vehicle", 0)) == server_entity:
			return int(_pilot_of(world, int(state["client"])).get("vehicle", 0))
	return 0


## Level flight speed after letting it settle.
func _settled_speed(entity: int) -> float:
	_advance(200, _controls({"throttle": 1.0}), _controls())
	return (server.vehicle_state(entity).get("velocity", Vector3.ZERO) as Vector3).length()


func _channel_names(schema: Dictionary) -> String:
	var names: PackedStringArray = []
	for entry in (schema.get("channels", []) as Array):
		names.append(String((entry as Dictionary)["name"]))
	return ", ".join(names)


func _has_channel(schema: Dictionary, wanted: String) -> bool:
	for entry in (schema.get("channels", []) as Array):
		if String((entry as Dictionary)["name"]) == wanted:
			return true
	return false


## ---- 16. TWO SETS OF CONTROLS, ONE AEROPLANE -----------------------------------------
##
## The goal this suite exists to prove, in three parts:
##
##   1. **Networked physics from two hands.** Both flying seats send their own axes and the
##      aeroplane gets the AVERAGE, so pulling opposite ways does very little and pulling
##      together does all of it.
##   2. **Each seat sees the other's controls.** Nobody receives anybody else's input, by
##      design, so the server publishes every seat's control POSITIONS and both clients
##      read them off the wire.
##   3. **Craft-local state everybody shares.** A button that does nothing but change
##      colour, one per seat, pressable by anybody. No physics, no external effect --
##      which is the point, because if that works then so does every switch shaped like it.
func _test_two_sets_of_controls() -> void:
	var id_a: int = client_a.local_client_id()
	var id_b: int = client_b.local_client_id()
	# A fresh aeroplane with room for both of them: the one from the earlier suites is
	# full, and this needs two FLYING seats rather than a pilot and a gunner.
	# EMPTY, and walked into. Spawning a second pilot for a client who already has one
	# leaves them owning two pilot entities, both of which carry an input frame -- and the
	# orphan goes on delivering the last command it was given.
	var craft: int = int(server.spawn_vehicle(PLANE, Vector3(0.0, 900.0, 2600.0), 0.0,
		Vector3(0.0, 0.0, -70.0)))
	_check("a_two_crew_aeroplane_is_flying", craft != 0, "entity %d" % craft)
	if craft == 0:
		return
	_advance(40, _controls(), _controls())
	for who in [id_a, id_b]:
		for attempt in range(24):
			if int(_pilot_of(server, who).get("vehicle", 0)) == craft:
				break
			_advance(4, _controls({"buttons": USE if who == id_a else 0}),
				_controls({"buttons": USE if who == id_b else 0}))
			_advance(30, _controls(), _controls())
	var crew: PackedInt64Array = server.vehicle_seats(craft)
	_check("both_pilots_are_in_flying_seats",
		int(crew[0]) == id_a and int(crew[1]) == id_b,
		"pilot and copilot: %s" % [crew])
	if int(crew[1]) != id_b:
		return

	# ---- 1. THE AVERAGE --------------------------------------------------------
	#
	# Opposite ways first. Two hands pulling against each other is very nearly no hands at
	# all, which is what an average means and what a linkage does.
	_advance(90, _controls({"throttle": 0.6, "roll": 1.0}),
		_controls({"throttle": 0.6, "roll": -1.0}))
	var fighting: float = _roll_rate(server.vehicle_state(craft))
	_advance(120, _controls({"throttle": 0.6}), _controls({"throttle": 0.6}))
	# Then together.
	_advance(90, _controls({"throttle": 0.6, "roll": 1.0}),
		_controls({"throttle": 0.6, "roll": 1.0}))
	var agreeing: float = _roll_rate(server.vehicle_state(craft))
	_check("two_pilots_pulling_against_each_other_cancel",
		absf(fighting) < 0.35,
		"%.2f rad/s with the sticks hard over in opposite directions" % fighting)
	_check("and_pulling_together_get_all_of_it", agreeing > 1.2,
		"%.2f rad/s with both sticks hard over the same way" % agreeing)
	_advance(150, _controls({"throttle": 0.6}), _controls({"throttle": 0.6}))

	# ONE PAIR OF HANDS GETS ALL OF IT. The average is over the hands actually ON the
	# controls, not over the seats -- a copilot sitting with their hands in their lap does
	# not halve the pilot. This used to assert half, which is what the aeroplane did and
	# was never what a linkage does.
	_advance(70, _controls({"throttle": 0.6, "roll": 1.0}), _controls({"throttle": 0.6}))
	var alone: float = _roll_rate(server.vehicle_state(craft))
	_check("and_one_pilot_alone_gets_all_of_it",
		alone > agreeing * 0.85,
		"%.2f rad/s from one stick against %.2f from two" % [alone, agreeing])
	_advance(150, _controls({"throttle": 0.6}), _controls({"throttle": 0.6}))

	# ---- 1b. THE LINKAGE ------------------------------------------------------
	#
	# Two yokes on one linkage have ONE position, not two, and every control connected to
	# it shows that position. It is deliberately the FLYING value rather than either
	# pilot's alone: a yoke that showed one seat's input while the aeroplane obeyed the
	# average would be lying about what the aircraft is doing, which is the one thing a
	# control position is for.
	#
	# This is what lets a copilot sit with their hands in their lap and watch the yoke in
	# front of them move with the pilot's.
	_advance(60, _controls({"throttle": 0.6, "roll": 0.8}), _controls({"throttle": 0.6}))
	var alone_on_it: Dictionary = _crew_of(client_b, craft)
	_check("one_pair_of_hands_moves_the_whole_linkage",
		absf((alone_on_it.get("linked_stick", Vector2.ZERO) as Vector2).x - 0.8) < 0.12,
		"the copilot's machine shows the linkage at %.2f across with only the pilot on it"
			% (alone_on_it.get("linked_stick", Vector2.ZERO) as Vector2).x)
	_check("and_says_whose_hands_are_on_it",
		int(alone_on_it.get("hands_on", 255)) == 0,
		"seat %d has it" % int(alone_on_it.get("hands_on", 255)))

	# And when both are flying, the PILOT is the one flying.
	_advance(60, _controls({"throttle": 0.6, "roll": 0.8}),
		_controls({"throttle": 0.6, "roll": -0.4}))
	_check("and_the_pilot_has_it_when_both_are_on_it",
		int(_crew_of(client_a, craft).get("hands_on", 255)) == 0,
		"seat %d has it with both hands on" % int(
			_crew_of(client_a, craft).get("hands_on", 255)))
	_advance(120, _controls({"throttle": 0.6}), _controls({"throttle": 0.6}))

	# ---- 2. EACH SEAT SEES THE OTHER'S CONTROLS -------------------------------
	_advance(60, _controls({"throttle": 0.85, "roll": 0.5}),
		_controls({"throttle": 0.2, "roll": -0.75}))
	var seen_by_a: Array = _controls_seen_by(client_a, craft)
	var seen_by_b: Array = _controls_seen_by(client_b, craft)
	_check("every_seat_publishes_where_its_controls_are",
		seen_by_a.size() >= 2 and seen_by_b.size() >= 2,
		"A sees %d sets, B sees %d" % [seen_by_a.size(), seen_by_b.size()])
	if seen_by_a.size() < 2 or seen_by_b.size() < 2:
		return
	# Each of them can read the OTHER seat's levers, which is the whole point: neither has
	# the other's input and neither needs it.
	_check("and_each_pilot_can_see_the_others_throttle",
		absf(float((seen_by_b[0] as Dictionary)["throttle"]) - 0.85) < 0.12
			and absf(float((seen_by_a[1] as Dictionary)["throttle"]) - 0.2) < 0.12,
		"B sees the pilot at %.2f, A sees the copilot at %.2f" % [
			float((seen_by_b[0] as Dictionary)["throttle"]),
			float((seen_by_a[1] as Dictionary)["throttle"])])
	_check("and_the_others_stick",
		absf(((seen_by_b[0] as Dictionary)["stick"] as Vector2).x - 0.5) < 0.15
			and absf(((seen_by_a[1] as Dictionary)["stick"] as Vector2).x + 0.75) < 0.15,
		"B sees the pilot at %.2f across, A sees the copilot at %.2f" % [
			((seen_by_b[0] as Dictionary)["stick"] as Vector2).x,
			((seen_by_a[1] as Dictionary)["stick"] as Vector2).x])
	_advance(120, _controls({"throttle": 0.6}), _controls({"throttle": 0.6}))

	# ---- 3. THE BUTTON --------------------------------------------------------
	#
	# It does nothing but change colour, and that is deliberate: it is the smallest piece
	# of craft-local shared state there is.
	# ONE LAMP, and every switch in the craft is wired to it. Which seat pressed does not
	# come into it -- that is what makes this shared state rather than four private ones.
	var dark: bool = bool(server.craft_systems(craft).get("crew_light", false))
	_command(client_a, 14, 0)          # the pilot presses the one in front of them
	_advance(40, _controls({"throttle": 0.6}), _controls({"throttle": 0.6}))
	var lit: bool = bool(server.craft_systems(craft).get("crew_light", false))
	_check("one_switch_lights_the_whole_craft", lit and not dark,
		"lit %s, was %s" % [lit, dark])
	_check("and_the_whole_crew_sees_it",
		_lamp_seen_by(client_a, craft) and _lamp_seen_by(client_b, craft),
		"A sees %s, B sees %s" % [_lamp_seen_by(client_a, craft),
			_lamp_seen_by(client_b, craft)])

	# ANYBODY may press it, from ANY seat: it is craft-local state, not a personal setting,
	# and there is no station gate on the internal half of the bus.
	_command(client_b, 14, 1)          # the copilot presses the one in front of THEM
	_advance(40, _controls({"throttle": 0.6}), _controls({"throttle": 0.6}))
	_check("and_any_seats_switch_turns_it_off_again",
		not bool(server.craft_systems(craft).get("crew_light", false)),
		"the copilot's switch turned off the lamp the pilot lit")

	# And none of it touched the aeroplane, which is what makes it the internal half.
	_check("and_none_of_it_flew_the_aeroplane",
		(server.vehicle_state(craft).get("velocity", Vector3.ZERO) as Vector3).length()
			> 30.0,
		"still flying at %.0f m/s" % (server.vehicle_state(craft).get("velocity",
			Vector3.ZERO) as Vector3).length())


## The whole crew-controls report on one world, linkage and all.
func _crew_of(world, server_entity: int) -> Dictionary:
	var here: int = _same_vehicle_on(world, server_entity)
	return world.crew_controls(here) if here != 0 else {}


## What one world can see of every seat's controls in a craft.
func _controls_seen_by(world, server_entity: int) -> Array:
	var here: int = _same_vehicle_on(world, server_entity)
	if here == 0:
		return []
	return world.crew_controls(here).get("seats", []) as Array


func _lamp_seen_by(world, server_entity: int) -> bool:
	var here: int = _same_vehicle_on(world, server_entity)
	if here == 0:
		return false
	return bool(world.craft_systems(here).get("crew_light", false))


## ---- 17. A TRAIN, AND A PLAYER DRIVING IT --------------------------------------------
##
## A train is a 1D problem wearing a 3D costume: one scalar position along the railway and
## one scalar speed, and the pose read back off the track from those two. So its replicated
## state is thirty bits rather than a hundred and sixty -- every peer builds the same
## railway and can work out the rest.
##
## It is an ordinary vehicle in every other respect: seats, a crew, a command bus, and the
## take-the-next-craft button walks into the cab like anything else.
func _test_driving_a_train() -> void:
	var id_b: int = client_b.local_client_id()
	# A short circular railway, laid on both worlds. It has to be BOTH: a train sends how
	# far along it has got, which means nothing to a machine with a different track.
	var radius: float = 600.0
	for world in [server, client_a, client_b]:
		for i in range(180):
			var angle: float = TAU * float(i) / 180.0
			# Dead level: a railway with no bank authored anywhere must come out level,
			# which is half of what the roll argument is here to prove.
			world.add_rail_point(0, Vector3(cos(angle) * radius, 4.0,
				sin(angle) * radius), 0.0)
		world.close_rail(0)
	var loop: float = float(server.rail_length(0))
	_check("a_railway_can_be_laid", loop > TAU * radius * 0.98,
		"%.0f m round, against %.0f m of circumference" % [loop, TAU * radius])

	var loco: int = int(server.spawn_train(0, 0.0, 0.0))
	_check("a_locomotive_stands_on_it", loco != 0, "entity %d" % loco)
	if loco == 0:
		return
	_advance(60, _controls(), _controls())
	var parked: Dictionary = server.vehicle_state(loco)
	_check("and_it_is_on_the_rails",
		absf(Vector2((parked["position"] as Vector3).x,
			(parked["position"] as Vector3).z).length() - radius) < 2.0,
		"%.1f m from the centre of a %.0f m circle" % [
			Vector2((parked["position"] as Vector3).x,
				(parked["position"] as Vector3).z).length(), radius])
	_check("and_a_stopped_train_stays_stopped",
		absf(float(server.rail_state(loco).get("speed", 1.0))) < 0.01,
		"%.3f m/s with nobody driving" % float(server.rail_state(loco).get("speed", 1.0)))

	# B WALKS INTO THE CAB and opens the regulator.
	var presses: int = _press_until(id_b, loco)
	_check("a_player_can_take_the_cab",
		int(_pilot_of(server, id_b).get("vehicle", 0)) == loco,
		"boarded after %d press(es)" % presses)
	if int(_pilot_of(server, id_b).get("vehicle", 0)) != loco:
		return

	_advance(600, _controls(), _controls({"throttle": 1.0}))
	var running: Dictionary = server.rail_state(loco)
	_check("and_drive_it", float(running.get("speed", 0.0)) > 4.0,
		"%.1f m/s after ten seconds of full regulator" % float(running.get("speed", 0.0)))
	_check("and_it_went_somewhere", float(running.get("distance", 0.0)) > 20.0,
		"%.0f m along the line" % float(running.get("distance", 0.0)))

	# AND THE BRAKE. Half a kilometre to stop is the point of a train, so this only has to
	# show it is slowing rather than that it has stopped.
	var fast: float = float(running.get("speed", 0.0))
	_advance(600, _controls(), _controls({"brake": 1.0}))
	var slowed: float = float(server.rail_state(loco).get("speed", 0.0))
	_check("and_stop_it", slowed < fast * 0.5,
		"%.1f m/s down from %.1f under full brake" % [slowed, fast])
	_check("and_the_brake_never_backs_it_up", slowed > -0.01,
		"%.3f m/s, which is not reverse" % slowed)

	# The whole point of replicating a distance rather than a pose: both clients put the
	# train in the same place without being sent one.
	var seen_a: Vector3 = _train_seen_by(client_a, loco)
	var seen_b: Vector3 = _train_seen_by(client_b, loco)
	var truth: Vector3 = server.vehicle_state(loco).get("position", Vector3.ZERO)
	_check("and_every_peer_works_out_where_it_is",
		seen_a.distance_to(truth) < 12.0 and seen_b.distance_to(truth) < 12.0,
		"A is %.1f m out, B is %.1f m out, from a distance and a railway" % [
			seen_a.distance_to(truth), seen_b.distance_to(truth)])


func _train_seen_by(world, server_entity: int) -> Vector3:
	for state in server.pilot_states():
		if int(state.get("vehicle", 0)) == server_entity:
			var here: int = int(_pilot_of(world, int(state["client"])).get("vehicle", 0))
			if here != 0:
				return world.vehicle_state(here).get("position", Vector3.ZERO)
	for vehicle in world.vehicle_states():
		if int(vehicle["kind"]) == TRAIN:
			return vehicle["position"]
	return Vector3.ZERO


## Where the nose points.
func _nose(state: Dictionary) -> Vector3:
	return (state.get("basis", Quaternion.IDENTITY) as Quaternion) * Vector3(0.0, 0.0, -1.0)


## Compass angle of a direction, ignoring how steeply it points.
func _heading(direction: Vector3) -> float:
	return atan2(direction.x, -direction.z)


## Degrees between where the vehicle is going and where it is pointing, measured across
## its own wings. Positive is travel to the right of the nose.
func _sideslip(state: Dictionary) -> float:
	var velocity: Vector3 = state.get("velocity", Vector3.ZERO)
	if velocity.length() < 0.5:
		return 0.0
	var right: Vector3 = (state.get("basis", Quaternion.IDENTITY) as Quaternion) * Vector3.RIGHT
	return rad_to_deg(asin(clampf(velocity.normalized().dot(right), -1.0, 1.0)))


## Degrees between velocity and nose in every axis at once, which includes the angle of
## attack the wing needs and is therefore never quite zero in flight.
func _crab(state: Dictionary) -> float:
	var velocity: Vector3 = state.get("velocity", Vector3.ZERO)
	if velocity.length() < 0.5:
		return 0.0
	return rad_to_deg(velocity.normalized().angle_to(_nose(state)))


## Drive one server-side vehicle by writing its pilot's control frame directly. The two
## real clients are busy flying their own; this is for vehicles the test spawned.
func _seat_input(spawned: Dictionary, controls: Dictionary) -> void:
	_server_inputs[int(spawned.get("pilot", 0))] = _controls(controls)


## Client ids the server has not handed out. Vehicles the test flies itself need a pilot,
## and a pilot needs an id that no real client will claim.
func _spare_client() -> int:
	_next_spare += 1
	return 200 + _next_spare


## One pilot's replicated state, by client id.
func _pilot_of(world, client_id: int) -> Dictionary:
	for pilot in world.pilot_states():
		if int(pilot["client"]) == client_id:
			return pilot
	return {}


## One vehicle's DISPLAY state. Entity ids are per-world -- the server's plane is a
## different local entity on a client -- so it is found by kind. Confusing the two id
## spaces is a mistake this codebase has made repeatedly.
func _vehicle_of(world, kind: int) -> Dictionary:
	for vehicle in world.vehicle_states():
		if int(vehicle["kind"]) == kind:
			return vehicle
	return {}


func _local_entity(world, kind: int) -> int:
	for vehicle in world.vehicle_states():
		if int(vehicle["kind"]) == kind:
			return int(vehicle["entity"])
	return 0


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
