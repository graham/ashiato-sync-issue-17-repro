extends Node
## A server and TWO clients in one process, wired to each other through a delayed link.
##
##   Godot --path addon --headless res://tests/vr_loopback.tscn
##
## This is the test the VR foundation exists to pass, and it asks the questions the
## driving loopback cannot, because they are about people rather than cars:
##
##   1. do a player's own hands answer immediately, before the server can have replied?
##      (that is prediction; without it your hands lag your real hands by the ping)
##   2. does a seated player's world pose come from the VEHICLE, so that flying the thing
##      carries the pilot with it exactly rather than approximately?
##   3. does a quaternion attitude survive the wire -- can an aircraft actually bank, and
##      does the pilot bank with it?
##   4. can one player take an object out of another player's hand?
##
## Two clients rather than one because a handoff needs two people, and because "the second
## player sees the first" is the whole reason any of this exists.
##
## Packets are carried by this script, so it runs headless with no sockets and no Steam.
## The real game hands the same byte arrays to SteamMultiplayerPeer instead.
##
## Read RESULT=, not the exit code.

## The rate every world in this test simulates at. Set explicitly rather than left to the
## default, because the whole point of the setting is that peers must agree on it -- a test
## that ticked at one rate while the world was configured for another would be measuring a
## simulation nobody will ever run.
const TICK_HZ: float = 60.0
const DT: float = 1.0 / TICK_HZ
## One-way delay in ticks. 4 each way at 60 Hz is ~133 ms round trip: a bad-but-real
## connection, and far more than enough that unpredicted input would be obviously late.
const LINK_DELAY_TICKS: int = 4
const PEER_A: int = 1
const PEER_B: int = 2

## Button bits, matching kButton* in vr_world.cpp.
const GRAB_LEFT: int = 1
const GRAB_RIGHT: int = 2
const USE: int = 4
const SEAT: int = 8

## Kinds, matching kKind* in vr_world.cpp.
const CRATE: int = 0
const CAR: int = 2
const PLANE: int = 3

var _failures: PackedStringArray = []
## [[deliver_at_tick, target, from_peer, bytes, bits], ...] where target 0 is the server.
var _in_flight: Array = []
var _tick: int = 0

var server
var client_a
var client_b
## What client B should keep doing while A walks somewhere. Defaults to standing still;
## set to a grab pose so B does not drop the crate the moment A sets off towards it.
var _hold_for_b: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[vr] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## A complete input frame. Everything defaults to a person standing still with their
## hands in front of them, so a test only states what it is actually changing.
func _pose(overrides: Dictionary = {}) -> Dictionary:
	var input: Dictionary = {
		"head": Vector3(0.0, 1.6, 0.0),
		"head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, 1.2, -0.35),
		"left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, 1.2, -0.35),
		"right_basis": Quaternion.IDENTITY,
		"stick_left": Vector2.ZERO,
		"stick_right": Vector2.ZERO,
		"trigger_left": 0.0,
		"trigger_right": 0.0,
		"grip_left": 0.0,
		"grip_right": 0.0,
		"buttons": 0,
		"gesture_left": 0,
		"gesture_right": 0,
	}
	for key in overrides:
		input[key] = overrides[key]
	return input


func _pump() -> void:
	for packet in server.take_outbound():
		_in_flight.append([_tick + LINK_DELAY_TICKS, int(packet["peer"]), 0,
			packet["bytes"], packet["bits"]])
	for packet in client_a.take_outbound():
		_in_flight.append([_tick + LINK_DELAY_TICKS, 0, PEER_A, packet["bytes"], packet["bits"]])
	for packet in client_b.take_outbound():
		_in_flight.append([_tick + LINK_DELAY_TICKS, 0, PEER_B, packet["bytes"], packet["bits"]])

	var still_flying: Array = []
	for entry in _in_flight:
		if entry[0] > _tick:
			still_flying.append(entry)
			continue
		match int(entry[1]):
			0: server.deliver(entry[2], entry[3], entry[4])
			PEER_A: client_a.deliver(0, entry[3], entry[4])
			PEER_B: client_b.deliver(0, entry[3], entry[4])
	_in_flight = still_flying


func _advance(ticks: int, input_a: Dictionary = {}, input_b: Dictionary = {}) -> void:
	for i in range(ticks):
		if not input_a.is_empty():
			client_a.set_input(input_a)
		if not input_b.is_empty():
			client_b.set_input(input_b)
		_tick += 1
		server.tick(DT)
		client_a.tick(DT)
		client_b.tick(DT)
		_pump()


## Walk client A to within `stop` metres of a world point, and report whether it got
## there. Everything a player does has to happen within arm's reach of them, and the
## reach is a real limit -- the wire format quantises a hand offset over +/- 2 m, so a
## test that teleports an arm across the room is testing nothing and silently clamps.
func _walk_a_to(avatar_a: int, target: Vector3, stop: float, max_ticks: int) -> bool:
	for i in range(max_ticks / 6):
		var here: Vector3 = server.avatar_state(avatar_a).get("position", Vector3.ZERO)
		var delta: Vector3 = target - here
		delta.y = 0.0
		if delta.length() <= stop:
			_advance(20, _pose(), _hold_for_b)
			return true
		# Avatar yaw stays 0 throughout this test, so the body frame and the world frame
		# agree: stick x strafes along +X and stick y walks along -Z.
		var aim: Vector3 = delta.normalized()
		_advance(6, _pose({"stick_left": Vector2(aim.x, -aim.z)}), _hold_for_b)
	_advance(20, _pose(), _hold_for_b)
	var final_delta: Vector3 = target - server.avatar_state(avatar_a).get(
		"position", Vector3.ZERO)
	final_delta.y = 0.0
	return final_delta.length() <= stop


## The floor, built identically in all three worlds. It is not replicated -- both sides
## build it from the same data -- so a world that built it differently would predict its
## player through it.
func _build_world(world) -> void:
	world.add_static_box(Vector3(0.0, -0.5, 0.0), Vector3(60.0, 0.5, 60.0))


func _ready() -> void:
	if not ClassDB.class_exists("VrWorld"):
		print("[vr] VrWorld not registered; build with -WithVr")
		_finish()
		return

	server = ClassDB.instantiate("VrWorld")
	client_a = ClassDB.instantiate("VrWorld")
	client_b = ClassDB.instantiate("VrWorld")
	for world in [server, client_a, client_b]:
		world.set_tick_rate(TICK_HZ)
	_check("tick_rate_is_settable",
		is_equal_approx(float(server.tick_rate()), TICK_HZ),
		"all three worlds at %.0f Hz" % float(server.tick_rate()))
	_check("server_starts", server.start(0), "client_id 0 means server")
	# Refused once a world is running: changing it would change the meaning of every frame
	# number already in the buffers and in prediction history.
	_check("tick_rate_is_refused_once_running",
		not server.set_tick_rate(30.0)
			and is_equal_approx(float(server.tick_rate()), TICK_HZ),
		"still %.0f Hz after asking for 30 mid-session" % float(server.tick_rate()))
	_check("clients_start", client_a.start(PEER_A) and client_b.start(PEER_B),
		"two clients")
	_check("roles_differ", server.is_server() and not client_a.is_server(), "one server")
	for world in [server, client_a, client_b]:
		_build_world(world)

	# NO add_client(). Registering a client by hand and then pushing updates at it before
	# it has handshaked is a hard crash inside sync: the client has no session to decode
	# against. The client introduces itself; the server accepts by default.
	_advance(90)

	var clients: PackedInt64Array = server.connected_clients()
	_check("both_clients_handshook", clients.size() == 2,
		"server sees %d client(s): %s" % [clients.size(), clients])
	var id_a: int = client_a.local_client_id()
	var id_b: int = client_b.local_client_id()
	_check("clients_were_assigned_ids", id_a > 0 and id_b > 0 and id_a != id_b,
		"a=%d b=%d" % [id_a, id_b])
	if id_a <= 0 or id_b <= 0:
		_finish()
		return

	# ---- avatars ---------------------------------------------------------------------
	var avatar_a: int = server.spawn_avatar(id_a, Vector3(0.0, 0.0, 0.0), 0.0)
	var avatar_b: int = server.spawn_avatar(id_b, Vector3(2.0, 0.0, 0.0), 0.0)
	_check("avatars_spawned", avatar_a != 0 and avatar_b != 0,
		"entities %d and %d" % [avatar_a, avatar_b])

	_advance(60, _pose(), _pose())
	_check("client_a_sees_two_avatars", client_a.avatar_entities().size() == 2,
		"%d avatar(s) known to A" % client_a.avatar_entities().size())

	var mine_a: int = _avatar_of(client_a, id_a)
	var theirs_on_a: int = _avatar_of(client_a, id_b)
	_check("client_a_can_tell_them_apart", mine_a != 0 and theirs_on_a != 0 and mine_a != theirs_on_a,
		"mine=%d theirs=%d" % [mine_a, theirs_on_a])

	# ---- 1. prediction: hands must answer before a round trip can complete ------------
	#
	# The hand is moved to a position it has never been in, and read back on the client
	# after fewer ticks than the one-way delay. If the client were waiting for the server
	# it could not possibly know about this yet.
	var reached := Vector3(0.55, 1.05, -0.62)
	_advance(1, _pose({"right": reached}), _pose())
	var predicted: Dictionary = client_a.avatar_state(mine_a)
	var predicted_hand: Vector3 = predicted.get("right_local", Vector3.ZERO)
	_check("own_hand_is_predicted", predicted_hand.distance_to(reached) < 0.01,
		"local hand at %.3v after 1 tick, wanted %.3v" % [predicted_hand, reached])

	# And the same hand on the OTHER client must still be at the old place, because the
	# packet carrying it has not arrived. If this passes trivially the link is not
	# actually delaying anything and the test above proves nothing.
	var late: Vector3 = client_b.avatar_state(_avatar_of(client_b, id_a)).get(
		"right_local", Vector3.ZERO)
	_check("other_players_lag_the_link", late.distance_to(reached) > 0.05,
		"B still sees A's hand at %.3v" % late)

	# ...and catches up once the packets land.
	_advance(30, _pose({"right": reached}), _pose())
	var caught_up: Vector3 = client_b.avatar_state(_avatar_of(client_b, id_a)).get(
		"right_local", Vector3.ZERO)
	_check("other_players_catch_up", caught_up.distance_to(reached) < 0.02,
		"B now sees A's hand at %.3v" % caught_up)

	# ---- 2. walking, and the server agreeing about where it ended up ------------------
	var start_pos: Vector3 = client_a.avatar_state(mine_a).get("position", Vector3.ZERO)
	_advance(90, _pose({"stick_left": Vector2(0.0, 1.0)}), _pose())
	var walked: Vector3 = client_a.avatar_state(mine_a).get("position", Vector3.ZERO)
	var distance: float = Vector2(walked.x - start_pos.x, walked.z - start_pos.z).length()
	_check("walking_moves_the_avatar", distance > 1.5,
		"%.2f m in 1.5 s" % distance)

	var on_server: Vector3 = server.avatar_state(avatar_a).get("position", Vector3.ZERO)
	_check("server_agrees_where_a_walked_to", on_server.distance_to(walked) < 0.6,
		"client %.2v vs server %.2v (%.3f m apart, client leads by the link delay)" %
			[walked, on_server, on_server.distance_to(walked)])

	# ---- 2a. forward is the CHEST, never the head ------------------------------------
	#
	# The player looks ninety degrees to their left and pushes the stick forward. They must
	# travel along the body's nose, not along their gaze. Head-relative locomotion is a
	# defensible design and it is not this one: an avatar here is an invisible vehicle
	# whose facing is turned with the right stick, and the head is free to look anywhere
	# without steering.
	#
	# Worth a test rather than a comment because the head pose IS on the wire, right next
	# to the sticks, and using it is a one-line mistake that feels almost right.
	var look_left := Quaternion(Vector3.UP, PI * 0.5)
	var body_before: Vector3 = server.avatar_state(avatar_a).get("position", Vector3.ZERO)
	_advance(60, _pose({"head_basis": look_left, "stick_left": Vector2(0.0, 1.0)}), _pose())
	var body_after: Vector3 = server.avatar_state(avatar_a).get("position", Vector3.ZERO)
	var travelled: Vector3 = body_after - body_before
	travelled.y = 0.0

	# The avatar has never turned, so its nose is -Z. Looking left points the head at -X.
	var along_nose: float = travelled.dot(Vector3(0.0, 0.0, -1.0))
	var along_gaze: float = travelled.dot(Vector3(-1.0, 0.0, 0.0))
	_check("forward_is_the_chest_not_the_head",
		along_nose > 0.8 and absf(along_gaze) < 0.15,
		"%.2f m along the nose, %.2f m along the gaze" % [along_nose, along_gaze])

	# ---- 2b. hands must not move the player ------------------------------------------
	#
	# A hand is a kinematic body, so it wins every contact absolutely. Nothing suppressed
	# it against the player's OWN capsule, so bringing your hands back to your chest shoved
	# your own body backwards and it looked exactly like walking. Reported as "when my
	# hands move back I walk backwards", which is a precise description of the mechanism.
	#
	# LET THE PLAYER STOP FIRST. The first version of this measured 0.385 m and blamed the
	# hands; the control below measured the same 0.385 m with the hands held still,
	# because the avatar was still coasting to a halt from the walking test above. A
	# measurement taken from a moving start says nothing about what moved it.
	_advance(120, _pose(), _pose())

	var control_before: Vector3 = server.avatar_state(avatar_a).get("position", Vector3.ZERO)
	_advance(150, _pose(), _pose())
	var control_after: Vector3 = server.avatar_state(avatar_a).get("position", Vector3.ZERO)
	var drift: float = Vector2(control_after.x - control_before.x,
		control_after.z - control_before.z).length()
	_check("a_standing_player_stays_put", drift < 0.02,
		"drifted %.4f m over 2.5 s doing nothing" % drift)

	# Now sweep the hands right through where the body is, hard, with the sticks at zero.
	var before_hands: Vector3 = server.avatar_state(avatar_a).get("position", Vector3.ZERO)
	for i in range(6):
		_advance(10, _pose({
			"left": Vector3(-0.2, 1.3, -0.55), "right": Vector3(0.2, 1.3, -0.55)}), _pose())
		_advance(10, _pose({
			"left": Vector3(-0.05, 1.2, 0.02), "right": Vector3(0.05, 1.2, 0.02)}), _pose())
	_advance(30, _pose(), _pose())
	var after_hands: Vector3 = server.avatar_state(avatar_a).get("position", Vector3.ZERO)
	var shoved: float = Vector2(after_hands.x - before_hands.x,
		after_hands.z - before_hands.z).length()
	_check("hands_do_not_move_the_player", shoved < 0.05,
		"waving through my own chest moved me %.3f m" % shoved)

	# ---- 3. grabbing, and handing over ------------------------------------------------
	#
	# Deliberately BEFORE anybody takes off. Getting out of a climbing aeroplane is a
	# legitimate thing to do and the player falls, which is correct -- but it also left
	# A nowhere near the crate for the rest of the test, so the handoff was measured
	# against a player in freefall.
	# The crate is spawned beside B and allowed to FALL AND SETTLE first. Grabbing it in
	# mid-air worked in an earlier version of this test and proved nothing: the crate had
	# been in the air for three quarters of a second by the time the grab arrived, and it
	# was two metres below the hand reaching for it.
	var b_pos: Vector3 = server.avatar_state(avatar_b).get("position", Vector3.ZERO)
	var crate: int = server.spawn_body(CRATE, b_pos + Vector3(0.3, 1.0, -0.4), 0.0)
	_check("crate_spawned", crate != 0, "entity=%d" % crate)
	_advance(90, _pose(), _pose())

	var settled: Vector3 = server.body_state(crate).get("position", Vector3.ZERO)
	_check("the_crate_landed", absf((server.body_state(crate).get(
		"velocity", Vector3.ZERO) as Vector3).y) < 0.2,
		"resting at %.2v" % settled)

	# B reaches DOWN to where the crate actually is. Yaw is zero, so the avatar's frame
	# and the world's agree and the offset is a plain subtraction.
	var reach_b: Vector3 = settled - server.avatar_state(avatar_b).get("position", Vector3.ZERO)
	_advance(2, _pose(), _pose({"right": reach_b}))
	_advance(2, _pose(), _pose({
		"buttons": GRAB_RIGHT, "grip_right": 1.0, "right": reach_b}))
	_advance(30, _pose(), _pose({
		"buttons": GRAB_RIGHT, "grip_right": 1.0, "right": reach_b}))
	var held: Dictionary = server.body_state(crate)
	_check("b_picked_the_crate_up", int(held.get("holder", -1)) == id_b,
		"holder=%s hand=%s" % [held.get("holder", "?"), held.get("hand", "?")])

	# It follows the hand: B lifts their hand and the crate comes up with it.
	# The crate keeps the GRIP it was picked up with, so what has to stay constant is the
	# offset between hand and object -- not the distance to the hand's centre, which is
	# wherever on the crate B happened to take hold of it.
	#
	# Both measurements are taken with the crate CLEAR OF THE FLOOR and settled. Measuring
	# the grip while it was still lying on the ground measured a grip the carry could not
	# reach yet -- the floor was holding the crate out of position -- and the invariant
	# then looked like it was drifting by 8 cm when nothing had moved.
	var crate_before: Vector3 = server.body_state(crate).get("position", Vector3.ZERO)
	var lifted := Vector3(0.45, 1.45, -0.35)
	_advance(45, _pose(), _pose({
		"buttons": GRAB_RIGHT, "grip_right": 1.0, "right": lifted}))
	var grip_before: float = (server.body_state(crate).get("position", Vector3.ZERO) as Vector3) 		.distance_to(server.avatar_state(avatar_b).get("right", Vector3.ZERO))

	# Now carry it somewhere else and check the grip is the grip it was.
	_advance(45, _pose(), _pose({
		"buttons": GRAB_RIGHT, "grip_right": 1.0, "right": Vector3(-0.5, 1.3, -0.6)}))
	var crate_after: Vector3 = server.body_state(crate).get("position", Vector3.ZERO)
	var hand_now: Vector3 = server.avatar_state(avatar_b).get("right", Vector3.ZERO)
	var grip_after: float = crate_after.distance_to(hand_now)
	_check("the_crate_follows_the_hand",
		crate_after.distance_to(crate_before) > 0.3 and absf(grip_after - grip_before) < 0.03,
		"crate moved %.2f m and held its grip to within %.3f m" %
			[crate_after.distance_to(crate_before), absf(grip_after - grip_before)])

	# A walks over and takes it out of B's hand. A has to genuinely get within arm's
	# reach: hand offsets are quantised over +/- 2 m, so an arm stretched across the room
	# is silently clamped and the grab quietly tests nothing.
	var b_holding: Dictionary = _pose({
		"buttons": GRAB_RIGHT, "grip_right": 1.0, "right": lifted})
	var crate_here: Vector3 = server.body_state(crate).get("position", Vector3.ZERO)
	_hold_for_b = b_holding
	_check("a_walked_over_to_b", _walk_a_to(avatar_a, crate_here, 1.0, 300),
		"stopped %.2f m from the crate" %
			server.avatar_state(avatar_a).get("position", Vector3.ZERO).distance_to(
				crate_here))

	# Everything settles before the reach is measured. Walking up to somebody shoves
	# them: A's capsule pushed B, B's hand went with them, and the crate in it moved a
	# metre between the measurement and the grab -- so A closed their hand on empty air a
	# metre from where the crate had been. Aiming at a stale position is not a thing the
	# game does, it was a thing the test did.
	_advance(60, _pose(), b_holding)

	var reach_local: Vector3 = _reach_from(avatar_a, crate)
	_advance(20, _pose({"left": reach_local}), b_holding)
	# Re-aimed once the arm has arrived, because moving it may itself have nudged things.
	reach_local = _reach_from(avatar_a, crate)
	_advance(10, _pose({"left": reach_local}), b_holding)
	var gap: float = (server.avatar_state(avatar_a).get("left", Vector3.ZERO) as Vector3) \
		.distance_to(server.body_state(crate).get("position", Vector3.ZERO))
	_check("a_s_hand_reached_the_crate", gap < 0.2,
		"hand is %.3f m from it" % gap)

	# A KEEPS the button down. grip_left is the analog squeeze that drives the avatar's
	# fingers; GRAB_LEFT is the button the server edge-detects, and dropping it is a
	# release. Holding the one without the other took the crate and then immediately let
	# go of it, which reads as "the handoff did not work".
	var a_grabbing: Dictionary = _pose({
		"buttons": GRAB_LEFT, "grip_left": 1.0, "left": reach_local})
	_advance(40, a_grabbing, b_holding)

	var handed: Dictionary = server.body_state(crate)
	_check("a_took_it_out_of_b_s_hand", int(handed.get("holder", -1)) == id_a,
		"holder is now %s (was %d)" % [handed.get("holder", "?"), id_b])

	# One holder, always. This is the property the data model was chosen to guarantee:
	# a crate has ONE holder field, so two players holding it is not a state that can be
	# written down, let alone reached.
	_check("only_one_holder_exists", int(handed.get("holder", -1)) != id_b,
		"b no longer holds it")

	# And letting go gives it back to gravity. A lifts it clear of the floor first, still
	# holding the button, so there is somewhere for it to fall to.
	var raised := Vector3(-0.4, 1.5, -0.4)
	_advance(40, _pose({"buttons": GRAB_LEFT, "grip_left": 1.0, "left": raised}), _pose())
	var dropped_from: Vector3 = server.body_state(crate).get("position", Vector3.ZERO)
	_check("still_held_before_the_drop",
		int(server.body_state(crate).get("holder", -1)) == id_a,
		"holder=%s at %.2v" % [server.body_state(crate).get("holder", "?"), dropped_from])
	# Button released.
	_advance(60, _pose(), _pose())
	var fallen: Vector3 = server.body_state(crate).get("position", Vector3.ZERO)
	_check("releasing_drops_it", fallen.y < dropped_from.y - 0.15
			and int(server.body_state(crate).get("holder", -1)) < 0,
		"fell %.2f m after release" % (dropped_from.y - fallen.y))

	# ---- 4. seats: the pilot's pose must come from the aircraft -----------------------
	#
	# Placed so that SEAT 0 lands where the player is standing, rather than at a distance
	# that happens to be under the reach. The seat offset is asked of the simulation --
	# writing the same numbers down here is how a test ends up passing against geometry
	# the game does not have.
	# Parked CLEAR of the player, not on top of them. Spawning it so that seat 0 landed
	# exactly where the player stood put the aircraft's hull inside their capsule, Box3D
	# shoved the two apart over the next second, and the player ended up out of reach of
	# the seat they were standing in. The player walks to the aeroplane, like a person.
	var stood: Vector3 = server.avatar_state(avatar_a).get("position", Vector3.ZERO)
	var plane_origin: Vector3 = stood + Vector3(5.0, 0.75, 0.0)
	var plane: int = server.spawn_body(PLANE, plane_origin, 0.0)
	_check("plane_spawned", plane != 0, "entity=%d" % plane)
	_advance(45, _pose(), _pose())

	# Walk to a spot BESIDE the hull, not to the seat itself. The seat is inside the
	# aeroplane, so walking at it means walking into it -- and a person really can shove a
	# 750 kg aircraft, so the player pushed it across the field and chased it, never
	# getting close enough to climb in. Standing next to it is what a person does.
	var geometry: Dictionary = server.kind_geometry(PLANE)
	var half_width: float = (geometry["extents"] as Vector3).x
	var seat_here: Vector3 = server.seat_pose(plane, 0).get("position", Vector3.ZERO)
	var stand_at: Vector3 = server.body_state(plane).get("position", Vector3.ZERO) \
		+ Vector3(-(half_width + 0.75), 0.0, 0.0)
	_check("walked_to_the_aircraft", _walk_a_to(avatar_a, stand_at, 0.6, 300),
		"stopped %.2f m from seat 0" %
			server.avatar_state(avatar_a).get("position", Vector3.ZERO).distance_to(seat_here))

	# Press and release, because the seat toggle is edge-triggered on the server -- a held
	# button replayed during a rollback would otherwise climb in and out repeatedly.
	_advance(2, _pose({"buttons": SEAT}), _pose())
	_advance(45, _pose(), _pose())

	var seated: Dictionary = server.avatar_state(avatar_a)
	_check("player_took_a_seat", seated.get("seated", false),
		"seat %s of entity %s" % [seated.get("seat", "?"), seated.get("vehicle", "?")])

	var seats: PackedInt64Array = server.body_seats(plane)
	_check("the_seat_map_names_them", seats.size() > 0 and int(seats[0]) == id_a,
		"seats=%s, expected client %d in seat 0" % [seats, id_a])

	# The replicated fact reached the other client, and it reached client A too -- which
	# matters more, because A is PREDICTING this avatar and a predicted entity only adopts
	# a server value when something forces a reconciliation.
	_check("seat_replicated_to_both",
		client_a.avatar_state(mine_a).get("seated", false)
			and client_b.avatar_state(_avatar_of(client_b, id_a)).get("seated", false),
		"a=%s b=%s" % [client_a.avatar_state(mine_a).get("seated", false),
			client_b.avatar_state(_avatar_of(client_b, id_a)).get("seated", false)])

	# ---- 4b. hands must not move the vehicle you are sitting in ----------------------
	#
	# THE case the on-foot version missed. Seated, the player's hands are inside the hull
	# of the thing they are flying, so a hand that could exert a force shoved the aircraft
	# around from the cockpit. Suppressing hand-versus-own-capsule fixed standing up and
	# did nothing here, because the hull is not the capsule -- which is why a hand now
	# exerts no force on anything at all and only reports what it is inside.
	# Measured with the aircraft PARKED. The first version of this ran after the flight
	# leg and measured 93 m, which was the aeroplane still travelling under its own
	# momentum -- the same mistake as measuring a walking player's hands.
	_advance(60, _pose(), _pose())
	var hull_before: Vector3 = server.body_state(plane).get("position", Vector3.ZERO)
	var attitude_before: Quaternion = server.body_state(plane).get("basis", Quaternion.IDENTITY)
	# Seat-LOCAL hand poses, and they have to be inside the hull to test anything. The
	# first version swept between y=1.0 and y=1.4 above a seat that sits 0.10 up in a hull
	# half a metre tall, so the hands were waving in the air above the aeroplane and the
	# test passed without touching it. Asked of the simulation's own geometry now.
	var hull: Vector3 = server.kind_geometry(PLANE)["extents"]
	var seat0: Vector3 = (server.kind_geometry(PLANE)["seat_poses"] as Array)[0]["position"]
	# Two poses either side of the seat, both comfortably within the hull.
	var deep := Vector3(0.0, -seat0.y, 0.1)
	var wide := Vector3(hull.x * 0.4, hull.y * 0.5, -0.25)
	for i in range(6):
		_advance(10, _pose({"left": -wide, "right": wide}), _pose())
		_advance(10, _pose({"left": deep, "right": deep}), _pose())
	_advance(30, _pose(), _pose())
	var hull_after: Vector3 = server.body_state(plane).get("position", Vector3.ZERO)
	var attitude_after: Quaternion = server.body_state(plane).get("basis", Quaternion.IDENTITY)
	_check("hands_do_not_move_the_vehicle",
		hull_after.distance_to(hull_before) < 0.05
			and attitude_before.angle_to(attitude_after) < 0.05,
		"waving in the cockpit moved it %.3f m and %.1f degrees" % [
			hull_after.distance_to(hull_before),
			rad_to_deg(attitude_before.angle_to(attitude_after))])

	# A hand still KNOWS what it is inside, which is what a drag or a lever will need.
	_advance(20, _pose({"right": deep}), _pose())
	var touching: PackedInt64Array = server.hand_overlaps(avatar_a, 1)
	_check("a_hand_reports_what_it_is_inside", touching.size() > 0,
		"right hand overlaps %s" % [touching])

	# THE seat test. Fly the aircraft and check the pilot went with it EXACTLY -- not
	# approximately, which is what a second replicated pose would give. The pilot's pose
	# is derived from the aircraft's, so the offset between them cannot drift at all.
	var seat_before: Dictionary = server.seat_pose(plane, 0)
	var pilot_before: Vector3 = server.avatar_state(avatar_a).get("position", Vector3.ZERO)
	var offset_before: Vector3 = pilot_before - (seat_before.get("position", Vector3.ZERO) as Vector3)
	# Where the aeroplane actually is now, not where it was spawned: the player may well
	# have nudged it on their way past, and a distance measured from the spawn point would
	# be measuring that nudge as flight.
	var takeoff_from: Vector3 = server.body_state(plane).get("position", Vector3.ZERO)

	_advance(150, _pose({"trigger_right": 1.0, "stick_left": Vector2(0.0, 0.18)}), _pose())

	var flown: Dictionary = server.body_state(plane)
	var flown_pos: Vector3 = flown.get("position", Vector3.ZERO)
	var flown_distance: float = flown_pos.distance_to(takeoff_from)
	# Under POWER, not under gravity: an unpiloted aircraft tumbling off a kerb also
	# travels several metres, and an earlier version of this test passed on exactly that.
	# Forward travel along its own nose is the thing that cannot happen by falling.
	var nose: Vector3 = (flown.get("basis", Quaternion.IDENTITY) as Quaternion) * Vector3(0, 0, -1)
	var forward_travel: float = (flown_pos - takeoff_from).dot(nose)
	_check("the_aircraft_flew", forward_travel > 4.0,
		"%.1f m along its own nose (%.1f m total)" % [forward_travel, flown_distance])

	var seat_after: Dictionary = server.seat_pose(plane, 0)
	var pilot_after: Vector3 = server.avatar_state(avatar_a).get("position", Vector3.ZERO)
	var offset_after: Vector3 = pilot_after - (seat_after.get("position", Vector3.ZERO) as Vector3)
	_check("the_pilot_stayed_bolted_in", offset_before.distance_to(offset_after) < 0.001,
		"seat offset moved %.6f m over 2 s of flight" %
			offset_before.distance_to(offset_after))

	# ---- 5. quaternion attitude: can it bank, and does the pilot bank with it? --------
	var level: Quaternion = server.body_state(plane).get("basis", Quaternion.IDENTITY)
	_advance(60, _pose({"trigger_right": 1.0, "stick_left": Vector2(1.0, 0.0)}), _pose())
	var banked: Quaternion = server.body_state(plane).get("basis", Quaternion.IDENTITY)
	var bank_angle: float = level.angle_to(banked)
	_check("the_aircraft_banks", bank_angle > 0.2,
		"%.1f degrees of attitude change from full aileron" % rad_to_deg(bank_angle))

	var pilot_basis: Quaternion = server.avatar_state(avatar_a).get("basis", Quaternion.IDENTITY)
	_check("the_pilot_banks_with_it", pilot_basis.angle_to(banked) < 0.01,
		"pilot attitude is %.2f degrees off the aircraft's" %
			rad_to_deg(pilot_basis.angle_to(banked)))

	# The bank survived the wire. A yaw-only wire format would show zero here, which is
	# exactly what this module changed from the driving module and why.
	_advance(30, _pose({"trigger_right": 1.0}), _pose())
	var banked_on_b: Quaternion = _body_basis_on(client_b, plane)
	_check("the_bank_reached_the_other_client",
		banked_on_b != Quaternion.IDENTITY
			and banked_on_b.angle_to(Quaternion.IDENTITY) > 0.1,
		"B sees %.1f degrees of attitude" %
			rad_to_deg(banked_on_b.angle_to(Quaternion.IDENTITY)))

	# Get out again, so the grab tests happen on foot.
	_advance(2, _pose({"buttons": SEAT}), _pose())
	_advance(60, _pose(), _pose())
	_check("player_left_the_seat", not server.avatar_state(avatar_a).get("seated", true),
		"seats now %s" % [server.body_seats(plane)])

	# ---- 5c. drawing BETWEEN ticks ----------------------------------------------------
	#
	# sync advances its display clock only inside tick(), and Godot's physics step is not
	# locked to its render frame -- two ticks land in one drawn frame and none in the next.
	# Drawn at the tick, the pose therefore advances by two frames' worth and then by
	# nothing. Standing still that is invisible; in a moving vehicle it is the chair
	# juddering underneath you, and the hands and head with it.
	#
	# set_render_time() puts drawing a whole tick behind the simulation and walks across
	# that tick by real time. What this checks is the property that matters: EVEN SPACING.
	# A pose that moves the same distance for each equal slice of real time is smooth; one
	# that moves in three big steps and holds is not, and both would pass a test that only
	# asked whether the position changed.
	var mover: int = 0
	for entity in client_b.body_entities():
		if client_b.body_kind(entity) == PLANE:
			mover = int(entity)
	if mover == 0:
		_check("drawing_is_evenly_spaced", false, "no moving body to sample")
	else:
		var steps: int = 8
		var points: Array[Vector3] = []
		for i in range(steps + 1):
			client_b.set_render_time(float(i) / float(steps) * DT)
			points.append(_sampled_position(client_b, mover))
		client_b.set_render_time(0.0)

		var gaps: Array[float] = []
		for i in range(steps):
			gaps.append(points[i].distance_to(points[i + 1]))
		var total: float = points[0].distance_to(points[steps])
		var smallest: float = gaps[0]
		var largest: float = gaps[0]
		for slice_size in gaps:
			smallest = minf(smallest, slice_size)
			largest = maxf(largest, slice_size)

		# A whole tick of travel has to actually happen, or the evenness below is the
		# evenness of a stationary object.
		_check("drawing_covers_a_whole_tick", total > 0.05,
			"%.4f m across one tick at %d samples" % [total, steps])
		# Every eighth of a tick within a few percent of every other. The clamping version
		# of this produced gaps of 0.033, 0.033, 0.000, 0.000 -- a ratio of infinity.
		_check("drawing_is_evenly_spaced",
			smallest > 0.0 and largest / smallest < 1.25,
			"slice sizes range %.5f to %.5f m (ratio %.2f)" %
				[smallest, largest, largest / maxf(smallest, 1e-9)])

	# ---- 6. rollback happened, and did not run away ------------------------------------
	var resims: Dictionary = client_a.resim_stats()
	_check("prediction_settles", int(resims.get("count", -1)) >= 0
			and int(resims.get("count", 0)) < _tick / 4,
		"%d rollbacks over %d ticks" % [int(resims.get("count", 0)), _tick])

	_finish()


## Where an avatar has to put its hand, in its own frame, to touch a body.
##
## Yaw is zero for both players throughout this test, so the avatar frame and the world
## frame agree and this is a subtraction. A game would rotate it into the body basis.
func _reach_from(avatar: int, body: int) -> Vector3:
	return (server.body_state(body).get("position", Vector3.ZERO) as Vector3) \
		- (server.avatar_state(avatar).get("position", Vector3.ZERO) as Vector3)


## Where a body is being DRAWN right now, as opposed to where the tick says it is.
func _sampled_position(world, entity: int) -> Vector3:
	for sample in world.sampled_bodies():
		if int(sample["entity"]) == entity:
			return sample.get("position", Vector3.ZERO)
	return Vector3.ZERO


func _avatar_of(world, client_id: int) -> int:
	for entity in world.avatar_entities():
		if world.avatar_owner(entity) == client_id:
			return int(entity)
	return 0


func _body_basis_on(world, _server_entity: int) -> Quaternion:
	# Entity ids are per-world: the server's plane is a different local entity on a
	# client, so it is found by KIND rather than by id. Confusing the two id spaces is a
	# mistake this codebase has made repeatedly.
	for entity in world.body_entities():
		if world.body_kind(entity) == PLANE:
			return world.body_state(entity).get("basis", Quaternion.IDENTITY)
	return Quaternion.IDENTITY


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)

