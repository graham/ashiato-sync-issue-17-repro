extends Node
## Headless: THE SIGNAL LAMP ON THE WIRE -- a lamp channel at every seat of every kind, the package contract untouched by
## them, and a flash from one aircraft seen by a player in another 1.5 km away: how many ticks it takes, where the far
## machine puts the lamp, and what it costs in bytes.
##
##   Godot --headless --xr-mode off --fixed-fps 120 --path cockpit res://tests/lamp_wire.tscn
##
## WHAT IS REAL HERE. A server and two client CockpitWorlds over the in-process one-tick link `many_devices` and
## `command_burst` use: the SIGNALLER flying a plane from its left seat, and the WATCHER flying another plane 1.5 km
## off its nose. The signaller's lamp is a real `SignalLamp` put in the signaller's right hand and flashed through
## `SignalLamp.ask` and `DeviceSignalRouter.route`, with `Sim.client` pointed at the signaller's world for the length of
## it (as `many_devices` does); the watcher's is a real `SignalLamp` drawn the way `Sky._show_their_lamp` draws one:
## `apply` from the craft's bus and `follow` from the signaller's pilot state as the watcher's world has it. The hand
## that aims it is on the signaller's input frame, as the rig sends it. `tests/lamp_peers.gd` does the same between
## two real processes over a real socket, through the desk's keys.
##
## WHAT IT HOLDS, each checked:
##   * every kind is fitted with one lamp channel per seat, audience craft, and a generic channel fitted beside them
##     survives a refit;
##   * the package contract: fitting the lamps leaves `CraftPackage._contract_hash` where it was, every authored package
##     still reads, and moving a seat still moves the hash;
##   * a colour pressed on the signaller's lamp is on the WATCHER's copy of the craft's bus within `MOST_TICKS`, for each
##     colour and for dark again, and no two colours are ever on it at once (it is one value);
##   * the watcher's lamp is in the signaller's right hand, pointing where that hand points, within 2 cm and 2 degrees;
##   * the HOST can read off the bus that the lamp is held (`SignalLamp.is_held_value`), which is what a distance LOD on
##     far pilots' poses would ask before it stopped sending that hand; and with the watcher 1.5 km off, a 20-degree
##     swing of the lit lamp's hand still reaches the watcher's lamp within 2 degrees;
##   * let go, the holder goes to nobody and the watcher's lamp stays where the hand let go of it;
##   * WITH THE FAR-POSE LOD ON (250/350 m, the watcher 1,500 m off): the signaller's hands are masked until a lamp is up,
##     live while it is -- the server told by `SignalLamp.keep_held_lamps_live`, the same call `Sim` makes after every
##     server tick -- and masked again once it is let go, so a swing of the empty hand never reaches the watcher;
##   * and the bytes: down to the watcher a tick, quiet against flashing, and per change;
##   * AND SINCE THE LAMP BECAME A PART (lane/lampopt, 2026-09-19): no lamp at the seat on the watcher's bus until one is
##     placed; a lamp made by the parts bin's factory says `FITTED` and the watcher has it within `MOST_TICKS` (3 ticks);
##     binned, the seat's 0 reaches the watcher as "no lamp" within `MOST_TICKS` (3). The fifth bit moved the cost from
##     17.6 to 18.0 B a change down and 11.9 to 12.0 up.
##
## MUTANTS, each applied alone and reverted (2026-09-18):
##   * the lamp's state never put on the bus (`SignalLamp._tell_the_craft` returning before it moves the value):
##       FAIL the_watcher_sees_red_within_a_few_ticks (red after never, in 60 ticks)
##       FAIL and_the_watchers_lamp_is_red_in_the_signallers_right_hand (lit dark, holder 0, 1.1038 m and 19.16 degrees)
##   * the lamp channels not fitted (`SignalLamp.fit_every_kind` returning 0 before fitting anything):
##       FAIL every_seat_of_every_kind_has_a_lamp_channel_everybody_sees (pod seat 0 {  }, ...)
##   * `CraftPackage._contract_hash` hashing the whole schema again, generic channels and all:
##       FAIL fitting_the_lamps_leaves_the_package_contract_where_it_was (moved: pod, plane, boat, ... all 32)
##       FAIL and_every_authored_package_still_reads (pod: craft package simulation contract is stale; ...)
##   * `SignalLamp.keep_held_lamps_live` never telling the server (returning before it reads anything):
##       FAIL and_a_lit_lamps_aim_still_follows_the_hand_on_a_watcher_1500_m_off (38.02 degrees from the hand ...)
##       FAIL with_the_pose_lod_on_because_the_server_was_told_the_lamp_is_up (masked true; live [])
##
## Read RESULT=, not the exit code.

const DT: float = 1.0 / 120.0
const TICK_HZ: float = 120.0
const SIGNALLER_PEER: int = 2
const WATCHER_PEER: int = 3
const PLANE: int = Sim.Kind.PLANE
const SEAT: int = 0
## How far apart the two aircraft are, metres, the watcher off the signaller's nose.
const APART: float = 1500.0
## THE MOST TICKS A FLASH MAY TAKE TO REACH THE WATCHER over a one-tick link: up on the signaller's input frame, the
## server's tick, down on the craft's page. Three is the floor; the rest is room for the frame the press lands on.
const MOST_TICKS: int = 6

var _failures: PackedStringArray = []
var _server: RefCounted = null
var _signaller: RefCounted = null
var _watcher: RefCounted = null
var _tick: int = 0
var _in_flight: Array = []
var _bytes_down: Dictionary = {}
## The signaller's right hand, in its seat's frame, as the input frame carries it.
var _hand := Transform3D.IDENTITY


func _check(label: String, ok: bool, detail: String) -> void:
	print("[lamp_wire] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld is not registered")
		_finish()
		return
	_the_contract_does_not_move_for_the_lamps()
	_every_seat_of_every_kind_has_a_lamp_channel()
	await _a_flash_crosses_to_another_aircraft()
	_finish()


## ---- the package contract ----------------------------------------------------------------------

## FITTING THE LAMPS LEAVES EVERY PACKAGE'S CONTRACT WHERE IT WAS, AND MOVING A SEAT STILL MOVES IT.
func _the_contract_does_not_move_for_the_lamps() -> void:
	var bare: Dictionary = {}
	for kind in range(Sim.Kind.size()):
		Sim.fit_channels(kind, [])
		bare[kind] = CraftPackage._contract_hash(kind)
	var fitted: int = SignalLamp.fit_every_kind()
	var moved: PackedStringArray = []
	var unreadable: PackedStringArray = []
	for kind in range(Sim.Kind.size()):
		if CraftPackage._contract_hash(kind) != String(bare[kind]):
			moved.append(Sim.kind_name(kind))
		var package: Dictionary = AuthoredCraftPackages.read(kind)
		if package.has("error"):
			unreadable.append("%s: %s" % [Sim.kind_name(kind), package["error"]])
	_check("fitting_the_lamps_leaves_the_package_contract_where_it_was", moved.is_empty() and fitted > 0,
		"%d lamp channels fitted; moved: %s" % [fitted, ", ".join(moved) if not moved.is_empty() else "none"])
	_check("and_every_authored_package_still_reads", unreadable.is_empty(),
		"all %d" % Sim.Kind.size() if unreadable.is_empty() else "; ".join(unreadable))
	# A REAL CONTRACT CHANGE STILL MOVES IT: the plane's first seat 5 cm to the left.
	var seats: Array = (Sim.geometry_of(PLANE).get("seat_poses", []) as Array).duplicate(true)
	var before: String = CraftPackage._contract_hash(PLANE)
	var shifted: Array = []
	for i in range(seats.size()):
		var pose: Dictionary = (seats[i] as Dictionary).duplicate()
		if i == 0:
			pose["position"] = (pose["position"] as Vector3) + Vector3(-0.05, 0.0, 0.0)
		shifted.append({"position": pose["position"], "yaw": float(pose.get("yaw", 0.0)),
			"station": String(pose.get("station", "pilot"))})
	var answer: Dictionary = Sim.fit_seats(PLANE, shifted)
	var after: String = CraftPackage._contract_hash(PLANE)
	Sim.fit_seats(PLANE, [])
	_check("and_moving_a_seat_still_moves_it", int(answer.get("fitted", 0)) == seats.size() and after != before
		and CraftPackage._contract_hash(PLANE) == before,
		"fit_seats %s; hash %s -> %s -> %s" % [str(answer), before.left(8), after.left(8),
			CraftPackage._contract_hash(PLANE).left(8)])


## ---- the channels ------------------------------------------------------------------------------

func _every_seat_of_every_kind_has_a_lamp_channel() -> void:
	var wrong: PackedStringArray = []
	var total: int = 0
	for kind in range(Sim.Kind.size()):
		var seats: int = (Sim.geometry_of(kind).get("seat_poses", []) as Array).size()
		for seat in range(seats):
			total += 1
			var found: Dictionary = {}
			for row in Sim.schema_of(kind).get("channels", []) as Array:
				if int((row as Dictionary).get("channel", -1)) == SignalLamp.channel_for(seat):
					found = row
			if found.is_empty() or int(found.get("range", 0)) != SignalLamp.RANGE \
					or String(found.get("audience", "")) != "craft":
				wrong.append("%s seat %d %s" % [Sim.kind_name(kind), seat, str(found)])
	_check("every_seat_of_every_kind_has_a_lamp_channel_everybody_sees", wrong.is_empty() and total > 60,
		"%d seats" % total if wrong.is_empty() else ", ".join(wrong.slice(0, 6)))
	# A GENERIC CHANNEL SOMEBODY ELSE FITTED SURVIVES THE LAMPS BEING FITTED AGAIN.
	var first: int = int(Sim.bus_limits().get("first_generic_channel", 32))
	Sim.fit_channels(PLANE, [{"channel": first, "name": "a panel switch", "range": 1, "audience": "crew"}])
	SignalLamp.fit_kind(PLANE)
	var kept: bool = false
	var lamps: int = 0
	for row in Sim.schema_of(PLANE).get("channels", []) as Array:
		if int((row as Dictionary).get("channel", -1)) == first:
			kept = true
		if SignalLamp.is_lamp_channel(int((row as Dictionary).get("channel", -1))):
			lamps += 1
	_check("and_a_generic_channel_fitted_beside_them_survives", kept and lamps == 4, "kept %s, %d lamps" % [kept, lamps])
	Sim.fit_channels(PLANE, [])
	SignalLamp.fit_kind(PLANE)


## ---- a flash, from one aircraft to another ----------------------------------------------------

func _a_flash_crosses_to_another_aircraft() -> void:
	var hull: int = _stand_up()
	if hull == 0:
		return
	var channel: int = SignalLamp.channel_for(SEAT)
	var was: RefCounted = Sim.client
	Sim.client = _signaller
	DeviceSignalRouter.reset_for_test()
	# THE SIGNALLER'S LAMP, in its right hand, aimed a little up and left -- at nothing in particular, so the watcher's
	# copy has somewhere definite to be.
	var far_hull: int = _hull_on(_watcher, hull)
	# NO LAMP AT THE SIGNALLER'S SEAT UNTIL ONE IS PLACED (lane/lampopt, 2026-09-19): the watcher's bus says so.
	_advance(10)
	var before: int = int(_watcher.bus_values(far_hull).get(channel, -1))
	_check("before_a_lamp_is_placed_the_watcher_sees_none_at_that_seat", not SignalLamp.is_fitted_value(before),
		"the channel is %d on the watcher" % before)
	# PLACED: made by the parts bin's own factory, and the seat says on the wire that it has one -- the value the rig
	# proposes (`PilotRig._say_whether_i_have_a_lamp`), sent here through the router as every lamp change is.
	var near := Node3D.new()
	add_child(near)
	var lamp := ControlCatalogue.make(&"SignalLamp") as SignalLamp
	near.add_child(lamp)
	lamp.setup(SEAT)
	lamp._tell_the_craft()
	DeviceSignalRouter.route(PLANE, SEAT, lamp)
	var placed_took: int = -1
	for t in range(60):
		_advance(1)
		if SignalLamp.is_fitted_value(int(_watcher.bus_values(far_hull).get(channel, -1))):
			placed_took = t + 1
			break
	_check("a_placed_lamp_reaches_the_watcher_within_a_few_ticks", placed_took > 0 and placed_took <= MOST_TICKS,
		"fitted after %s ticks" % (str(placed_took) if placed_took > 0 else "never, in 60"))
	_hand = Transform3D(Basis(Vector3.UP, 0.3) * Basis(Vector3.RIGHT, 0.15), Vector3(0.22, 1.02, -0.36))
	lamp.held_by = 1
	lamp.holder = SignalLamp.RIGHT
	# AND THE WATCHER'S COPY OF IT, made because the wire said so and drawn as the sky draws one.
	var far := Node3D.new()
	add_child(far)
	var seen := SignalLamp.new()
	far.add_child(seen)
	seen.setup(SEAT)
	# THE FAR-POSE LOD ON, 250 m near and 350 m far, with the watcher 1,500 m off: the signaller's hands are not sent to it
	# until a lamp is up. The server is told held-ness by `SignalLamp.keep_held_lamps_live`, which `_advance` calls after
	# every server tick exactly as `Sim` does.
	var lod: bool = _server.has_method("set_pose_lod") and bool(_server.set_pose_lod(true, 250.0, 350.0))
	SignalLamp.forget_the_live_lamps()
	_advance(30)
	var me: int = int(_signaller.local_client_id())
	var them: int = int(_watcher.local_client_id())
	_check("with_the_pose_lod_on_the_signallers_hands_are_not_sent_while_no_lamp_is_up",
		lod and bool(_server.pose_masked(them, me)), "lod %s, masked %s" % [lod, lod and bool(_server.pose_masked(them, me))])

	# RED, THEN WHITE OVER IT, THEN RED AGAIN AS WHITE COMES UP, THEN DARK: the newest press wins, one value on the bus.
	var steps: Array = [[SignalLamp.RED, true], [SignalLamp.WHITE, true], [SignalLamp.WHITE, false], [SignalLamp.RED, false]]
	var wanted: Array = [SignalLamp.RED, SignalLamp.WHITE, SignalLamp.RED, SignalLamp.DARK]
	var names: Array = ["red", "white_over_it", "red_again", "dark"]
	for i in range(steps.size()):
		lamp.ask(int(steps[i][0]), bool(steps[i][1]))
		DeviceSignalRouter.route(PLANE, SEAT, lamp)
		var took: int = -1
		for t in range(60):
			_advance(1)
			var at: int = int(_watcher.bus_values(far_hull).get(channel, -1))
			if at >= 0 and (at & 3) == int(wanted[i]):
				took = t + 1
				break
		_check("the_watcher_sees_%s_within_a_few_ticks" % names[i], took > 0 and took <= MOST_TICKS,
			"%s after %s ticks" % [SignalLamp.colour_name(int(wanted[i])), str(took) if took > 0 else "never, in 60"])
		# DRAWN AS THE SKY DRAWS IT, and while lit, in the signaller's right hand.
		_advance(10)
		seen.apply(seen.from_command(int(_watcher.bus_values(far_hull).get(channel, 0))))
		seen.follow(_their_state(_watcher))
		if i == 0:
			var expected: Transform3D = _hand * SignalLamp.IN_THE_PALM
			var off: float = seen.transform.origin.distance_to(expected.origin)
			var turned: float = rad_to_deg((-seen.transform.basis.z).angle_to(-expected.basis.z))
			_check("and_the_watchers_lamp_is_red_in_the_signallers_right_hand",
				seen.lit == SignalLamp.RED and seen.holder == SignalLamp.RIGHT and off < 0.02 and turned < 2.0,
				"lit %s, holder %d, %.4f m and %.2f degrees from the hand" % [SignalLamp.colour_name(seen.lit), seen.holder,
					off, turned])
			# THE HOST CAN READ THAT IT IS HELD, which is what a distance LOD on far pilots' poses would ask before it
			# stopped sending this hand (team-lead, 2026-09-18). See `SignalLamp.is_held_value`.
			var on_the_host: int = int(_server.bus_values(hull).get(channel, -1))
			_check("the_host_reads_off_the_bus_that_the_lamp_is_held", SignalLamp.is_held_value(on_the_host)
				and not SignalLamp.is_held_value(0), "the server's copy of the channel is %d" % on_the_host)
			# AND THE AIM KEEPS UP AT THIS RANGE: the hand swings 20 degrees while lit, and the watcher's lamp -- 1.5 km away,
			# which is past any near sphere -- swings with it, from the pilot state alone.
			var apart: float = _apart_on(_watcher)
			_hand = Transform3D(Basis(Vector3.UP, deg_to_rad(20.0)) * _hand.basis, _hand.origin)
			_advance(30)
			seen.follow(_their_state(_watcher))
			var swung: float = rad_to_deg((-seen.transform.basis.z).angle_to(-(_hand * SignalLamp.IN_THE_PALM).basis.z))
			_check("and_a_lit_lamps_aim_still_follows_the_hand_on_a_watcher_%d_m_off" % int(round(apart / 100.0) * 100.0),
				apart > 1000.0 and swung < 2.0, "%.0f m apart; %.2f degrees from the hand after it swung 20" % [apart, swung])
			_check("with_the_pose_lod_on_because_the_server_was_told_the_lamp_is_up",
				not bool(_server.pose_masked(them, me)) and (_server.pose_lod()["live"] as Array).has(me),
				"masked %s; live %s" % [_server.pose_masked(them, me), _server.pose_lod()["live"]])
	# LET GO: the holder goes to nobody, and the far lamp stays where the hand let it go -- the hand then moves away.
	var let_go_at: Transform3D = seen.transform
	lamp.held_by = -1
	lamp._on_released()
	DeviceSignalRouter.route(PLANE, SEAT, lamp)
	_hand = Transform3D(Basis.IDENTITY, Vector3(0.3, 0.9, 0.1))
	_advance(20)
	seen.apply(seen.from_command(int(_watcher.bus_values(far_hull).get(channel, 0))))
	seen.follow(_their_state(_watcher))
	_check("let_go_the_watchers_lamp_stays_where_the_hand_left_it",
		seen.holder == SignalLamp.NOBODY and seen.lit == SignalLamp.DARK
			and seen.transform.origin.distance_to(let_go_at.origin) < 0.001,
		"holder %d, lit %s, %.4f m from where it was let go" % [seen.holder, SignalLamp.colour_name(seen.lit),
			seen.transform.origin.distance_to(let_go_at.origin)])
	# AND LET GO, THE HANDS STOP BEING SENT: masked again, and a swing of the empty hand never reaches the watcher.
	_advance(30)
	var heard: Transform3D = _right_hand_of(_their_state(_watcher))
	_hand = Transform3D(Basis(Vector3.UP, 1.0) * _hand.basis, _hand.origin + Vector3(0.0, 0.1, 0.0))
	_advance(30)
	var moved_far: float = rad_to_deg((-_right_hand_of(_their_state(_watcher)).basis.z).angle_to(-heard.basis.z))
	_check("let_go_with_the_pose_lod_on_the_hands_stop_being_sent", bool(_server.pose_masked(them, me))
		and not (_server.pose_lod()["live"] as Array).has(me) and moved_far < 0.5,
		"masked %s; the watcher's copy of the hand turned %.2f degrees for a 57-degree swing" % [
			_server.pose_masked(them, me), moved_far])
	_server.set_pose_lod(false, 250.0, 350.0)

	_what_a_flash_costs(lamp)
	# BINNED: the lamp gone and the seat's channel back to 0, which is what the rig proposes once its station has no lamp
	# (`PilotRig._say_whether_i_have_a_lamp`), and the watcher's bus says there is none.
	lamp.held_by = -1
	lamp._on_released()
	DeviceSignalRouter.route(PLANE, SEAT, lamp)
	_advance(10)
	lamp.queue_free()
	Sim.send_command(channel, 0)
	DeviceSignalRouter.forget_channel(channel)
	var gone_took: int = -1
	for t in range(60):
		_advance(1)
		var now: int = int(_watcher.bus_values(far_hull).get(channel, -1))
		# -1 IS NONE TOO: a zero channel is left out of `bus_values`, and `is_fitted_value` reads it as no lamp, as the sky does.
		if not SignalLamp.is_fitted_value(now):
			gone_took = t + 1
			break
	_check("binned_the_watcher_sees_no_lamp_there_within_a_few_ticks", gone_took > 0 and gone_took <= MOST_TICKS,
		"gone after %s ticks" % (str(gone_took) if gone_took > 0 else "never, in 60"))
	Sim.client = was
	near.queue_free()
	far.queue_free()
	_teardown()


## WHAT IT COSTS: FIVE SECONDS QUIET AGAINST FIVE SECONDS OF MORSE -- the lamp in the hand, red for fifteen ticks and dark
## for fifteen, twenty times -- down to the watcher and up from the signaller. Everything else in the two windows is the
## same two parked aeroplanes, so the difference is the lamp's.
const WINDOW: int = 600
const FLASHES: int = 20

func _what_a_flash_costs(lamp: SignalLamp) -> void:
	lamp.held_by = 1
	lamp.holder = SignalLamp.RIGHT
	lamp._tell_the_craft()
	DeviceSignalRouter.route(PLANE, SEAT, lamp)
	_advance(60)
	_measure_from()
	_advance(WINDOW)
	var quiet: Dictionary = _bytes_down.duplicate()
	_measure_from()
	for i in range(FLASHES):
		lamp.ask(SignalLamp.RED, true)
		DeviceSignalRouter.route(PLANE, SEAT, lamp)
		_advance(WINDOW / FLASHES / 2)
		lamp.ask(SignalLamp.RED, false)
		DeviceSignalRouter.route(PLANE, SEAT, lamp)
		_advance(WINDOW / FLASHES / 2)
	var busy: Dictionary = _bytes_down.duplicate()
	var changes: int = FLASHES * 2
	var down: float = float(int(busy[WATCHER_PEER]) - int(quiet[WATCHER_PEER])) / float(changes)
	var up: float = float(int(busy[0]) - int(quiet[0])) / float(changes)
	print("[lamp_wire] down to the watcher: %.1f B a tick quiet, %.1f B a tick flashing; %.1f B a change"
		% [float(quiet[WATCHER_PEER]) / WINDOW, float(busy[WATCHER_PEER]) / WINDOW, down])
	print("[lamp_wire] up from the signaller: %.1f B a tick quiet, %.1f B a tick flashing; %.1f B a change"
		% [float(quiet[0]) / WINDOW, float(busy[0]) / WINDOW, up])
	_check("a_flash_costs_the_watcher_well_under_a_hundred_bytes", down > 0.0 and down < 100.0,
		"%.1f B a change down, %.1f B up" % [down, up])


func _right_hand_of(state: Dictionary) -> Transform3D:
	return Transform3D(Basis(state.get("right_basis", Quaternion.IDENTITY) as Quaternion),
		state.get("right", Vector3.ZERO) as Vector3)


## THE SIGNALLER'S PILOT STATE AS `world` HAS IT.
func _their_state(world: RefCounted) -> Dictionary:
	var them: int = int(_signaller.local_client_id())
	for state in world.pilot_states():
		if int((state as Dictionary).get("client", 0)) == them:
			return state
	return {}


## THE SIGNALLER'S PLANE ON ANOTHER WORLD: the plane the signaller is sitting in, by that world's own pilot states.
## Entity ids are per world, so it is found, not carried over.
func _hull_on(world: RefCounted, _hull: int) -> int:
	var them: int = int(_signaller.local_client_id())
	for state in world.pilot_states():
		if int((state as Dictionary).get("client", 0)) == them:
			return int((state as Dictionary).get("vehicle", 0))
	return 0


## HOW FAR APART THE TWO PLANES ARE, as `world` draws them.
func _apart_on(world: RefCounted) -> float:
	var at: Array = []
	for row in world.vehicle_states():
		if int((row as Dictionary).get("kind", -1)) == PLANE:
			at.append((row as Dictionary).get("position", Vector3.ZERO))
	return (at[0] as Vector3).distance_to(at[1] as Vector3) if at.size() == 2 else -1.0


## A SERVER, THE SIGNALLER IN ONE PLANE AND THE WATCHER IN ANOTHER, `APART` metres off its nose. The signaller's hull.
func _stand_up() -> int:
	_server = ClassDB.instantiate("CockpitWorld")
	_signaller = ClassDB.instantiate("CockpitWorld")
	_watcher = ClassDB.instantiate("CockpitWorld")
	for world in [_server, _signaller, _watcher]:
		world.set_tick_rate(TICK_HZ)
	_server.start(0)
	_signaller.start(SIGNALLER_PEER)
	_watcher.start(WATCHER_PEER)
	for world in [_server, _signaller, _watcher]:
		world.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(4000.0, 2.0, 4000.0))
	_advance(90)
	var me: int = int(_signaller.local_client_id())
	var them: int = int(_watcher.local_client_id())
	if me <= 0 or them <= 0:
		_check("both_clients_handshook", false, "client ids %d and %d" % [me, them])
		_teardown()
		return 0
	var mine: Dictionary = _server.spawn_pilot(me, PLANE, Vector3(0.0, 2.0, 0.0), 0.0, Vector3.ZERO)
	_server.spawn_pilot(them, PLANE, Vector3(0.0, 2.0, -APART), PI, Vector3.ZERO)
	var hull: int = int(mine.get("vehicle", 0))
	_advance(60)
	if hull == 0 or _hull_on(_watcher, hull) == 0:
		_check("the_watcher_sees_the_signallers_plane", false, "hull %d" % hull)
		_teardown()
		return 0
	return hull


func _controls() -> Dictionary:
	return {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 1.0,
		"head": Vector3(0.0, 1.35, 0.0), "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, 0.95, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, 0.95, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0,
	}


func _advance(ticks: int) -> void:
	for i in range(ticks):
		var mine: Dictionary = _controls()
		mine["right"] = _hand.origin
		mine["right_basis"] = _hand.basis.get_rotation_quaternion()
		mine["grip_right"] = 1.0
		_signaller.set_input(mine)
		_watcher.set_input(_controls())
		_tick += 1
		_server.tick(DT)
		SignalLamp.keep_held_lamps_live(_server)
		_signaller.tick(DT)
		_watcher.tick(DT)
		_pump()


func _measure_from() -> void:
	_bytes_down = {SIGNALLER_PEER: 0, WATCHER_PEER: 0, 0: 0}


## A ONE-TICK LINK, as `many_devices`'s: everything sent this tick is delivered before the next.
func _pump() -> void:
	for packet in _server.take_outbound():
		var peer: int = int(packet["peer"])
		_bytes_down[peer] = int(_bytes_down.get(peer, 0)) + (packet["bytes"] as PackedByteArray).size()
		_in_flight.append([_tick, peer, 0, packet["bytes"], packet["bits"]])
	for packet in _signaller.take_outbound():
		_bytes_down[0] = int(_bytes_down.get(0, 0)) + (packet["bytes"] as PackedByteArray).size()
		_in_flight.append([_tick, 0, SIGNALLER_PEER, packet["bytes"], packet["bits"]])
	for packet in _watcher.take_outbound():
		_in_flight.append([_tick, 0, WATCHER_PEER, packet["bytes"], packet["bits"]])
	var still_flying: Array = []
	for entry in _in_flight:
		if int(entry[0]) > _tick:
			still_flying.append(entry)
			continue
		match int(entry[1]):
			0:
				_server.deliver(int(entry[2]), entry[3], entry[4])
			SIGNALLER_PEER:
				_signaller.deliver(0, entry[3], entry[4])
			WATCHER_PEER:
				_watcher.deliver(0, entry[3], entry[4])
	_in_flight = still_flying


func _teardown() -> void:
	for world in [_signaller, _watcher, _server]:
		if world != null:
			world.teardown()
	_signaller = null
	_watcher = null
	_server = null
	_in_flight.clear()


func _finish() -> void:
	_teardown()
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
