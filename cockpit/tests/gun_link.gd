extends Node
## Headless: A GUN WORKED BY A CLIENT, ACROSS A LINK WITH A DELAY IN IT.
##
##   Godot --headless --path cockpit res://tests/gun_link.tscn
##
## THE BUG THIS WAS WRITTEN FOR, reported from a session: "in multiplayer, when a client player
## holds on to the machine guns they spin for a unknown reason, they don't work properly, but they
## do work for the server."
##
## WHAT A PINTLE GUN ACTUALLY IS, IN CONTROL TERMS. `PintleGun._drag` is a PROPORTIONAL SERVO. It
## measures the angle between the hand and the grips IN THE GUN'S OWN FRAME, multiplies by `FOLLOW`
## and asks the mount for that as a traverse RATE. The mount is a pure integrator: `aim_turret` does
## `turret_yaw -= roll * slew * dt` and nothing else. A proportional controller round an integrator
## is stable only while the loop is FAST compared with the lag in it -- and the lag here was the
## whole network, because `aim_turrets()` is `is_server_` only, so the angle the client measured its
## error against was the angle the SERVER last told it about.
##
## The loop's own time constant is 1 / (FOLLOW * slew) = 1 / (6 * 3) = 56 ms, so a round trip of
## anything like that size rings; and because the demand saturates at +/-1 the ringing is not a
## small wobble but the mount swinging at its full slew rate, back and forth, for as long as a hand
## is on it. That is the reported SPIN, and the measurement below says it in degrees.
##
## SO THE MEASUREMENT IS THE DELAY ITSELF, and the first half of this suite is a sweep. A gunner
## grabs the grips, swings the gun `SWING` radians and then HOLDS THEIR HAND PERFECTLY STILL, which
## is a gunner who has finished laying the gun. A gun that works stops. The same gunner is run over
## links of 0, 2, 4 and 8 ticks each way.
##
## RED and GREEN, on the cockpit of 2026-09-15, either side of `PintleGun.lead`. Degrees from the
## hand at the end, and degrees the mount travelled in the second after the hand stopped moving:
##
##   link             round trip     RED                  GREEN
##   0 ticks             0 ms        0.0 off,   1.8 moved     0.0 off,  1.5 moved
##   2 ticks            33 ms        0.1 off,   1.8 moved     0.0 off,  1.7 moved
##   4 ticks            67 ms        6.1 off, 121.0 moved     0.2 off,  1.8 moved
##   8 ticks           133 ms       20.5 off, 141.0 moved     0.5 off,  1.1 moved
##  16 ticks           267 ms       34.0 off, 162.0 moved     0.4 off,  2.0 moved
##
## The RED column says the fault exactly: 162 degrees a second against a slew rate of 172 is a mount
## running at nineteen twentieths of full speed with nobody moving their hand. Note where the edge
## is -- a host's own client hands its packets straight across and passes, and everybody who joined
## it does not -- which is exactly "they work for the server". And the GREEN column is flat, which
## is the claim worth making: the delay is not in the loop any more, so the numbers stop depending
## on it rather than merely getting better.
##
## 1.5 degrees of travel over a link with no delay in it at all is the FLOOR of this measurement,
## not a residue of the fault: the mount moves 1.4 degrees a tick, so a gun sitting on its target
## still dithers by about a step, and a second of that is what the last column is made of.
##
## AND THE SECOND HALF IS THE OTHER KIND OF GUN, which was asked about in the same breath: "the
## cannons in planes that are controlled by joysticks don't seem to work." A gunship's three guns
## are laid with a JOYSTICK rather than by hand, and a joystick's deflection does not depend on
## where the gun is, so there is no loop to be unstable -- it should work at any delay. This half
## says whether it does: a client at a joystick gun station traverses its own mount and fires it,
## over the same links. It is a DIFFERENT question from the first half and it is here so that
## nobody fixes the first fault twice.
##
## WHAT IS REAL HERE AND WHAT IS NOT. The controller is the real `PintleGun`, driven through
## `offer_hand` -- the seam `PilotRig` drives it through -- and the mount is the real `aim_turret`
## inside a real server `CockpitWorld`, reached over a real replicated link between two real worlds.
## The only thing modelled is the WIRE, and it is modelled the way `addon/tests/cockpit_loopback`
## models it: a list of packets with a due tick. What is NOT here is the rig (`tests/gunners.gd`
## drives that end to end) and the render-frame interpolation in `Sim.vehicle_turrets`, which adds
## up to one more tick of lag on top of everything measured below -- so the real game is slightly
## worse than these numbers, never better.
##
## Read RESULT=, not the exit code.

const DT: float = 1.0 / 120.0
const TICK_HZ: float = 120.0
const PEER: int = 2
const RIGHT: int = 1

## Kinds, matching Sim.Kind and kKind* in cockpit_world.cpp.
const POD: int = 0
const HELI: int = 4
const GUNSHIP: int = 15

## The left door gunner's seat on a helicopter, and the first gun position on a gunship. Which
## MOUNT each works is asked of the simulation, never written down here.
const DOOR_SEAT: int = 2
const GUNSHIP_SEAT: int = 1
## THE FIGHTER, AND ITS SECOND PILOT'S SEAT: a seat that flies it and so works its weapon selector, taken by the client
## because the first is the spare client's who spawned it.
const PLANE: int = 1
const COPILOT_SEAT: int = 1
## `Sim.BUTTON_LAUNCH`, the bit a headset's trigger puts on the frame beside the pull on the fighter.
const BUTTON_LAUNCH: int = 128

## HOW FAR THE GUNNER SWINGS THE GUN, in radians. About twenty degrees: far enough that the servo
## saturates on the way and small enough to stay well inside the door gun's 2.6 rad arc.
const SWING: float = 0.35

## How long the hand is held still after the swing, in seconds, and how much of the end of that is
## measured. A gun that has settled moves nothing at all in the last second; a gun that is hunting
## covers its whole swing several times over.
const HOLD_S: float = 3.0
const WATCH_S: float = 1.0

## WHAT "SETTLED" MEANS, in degrees. The mount moves `slew * DT` = 1.4 degrees a tick, so a gun
## sitting on its target still dithers by about one step and a whole second of that is the floor --
## measured at 1.8 degrees over a link with no delay in it at all. Ten degrees is five times that
## floor and a fourteenth of the worst RED reading, which is the margin this check actually has.
## Five degrees of final error is a seventh of the swing.
const SETTLED_TRAVEL_DEG: float = 10.0
const SETTLED_ERROR_DEG: float = 5.0

## The links to sweep, in ticks of one-way delay. 0 is a host's own client, which hands its packets
## straight across; 2 is a very good connection; 4 is `cockpit_loopback`'s "bad but real" link, at
## 67 ms round trip; 8 is a transatlantic one; and 16 is a third of a second, which is worse than
## anybody should be playing over and is here because the point of the fix is that the delay stopped
## being in the loop at all -- a check that stopped at the worst REALISTIC link would not say that.
const DELAYS: Array[int] = [0, 2, 4, 8, 16]

## How hard the joystick gunner pushes, how long for, and how far their mount has to move before it
## counts as having moved. A gunship's guns train 0.35 rad either side of rest, so a second at full
## deflection is against the stop and the check is "did it get there", not "how fast".
const PUSH_S: float = 1.0
const MOVED_RAD: float = 0.05

var _failures: PackedStringArray = []
var _server: RefCounted = null
var _client: RefCounted = null
var _tick: int = 0
## [[due_tick, to_the_server, peer, bytes, bits], ...]
var _in_flight: Array = []
var _next_spare: int = 0
## Whether the one-off checks about the craft themselves have been made. They are facts about the
## simulation rather than about the link, so they are asked once and not once per delay.
var _said: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[gun_link] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## Once each, however many links they are asked over.
func _check_once(label: String, ok: bool, detail: String) -> void:
	if _said.has(label):
		return
	_said[label] = true
	_check(label, ok, detail)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld is not registered")
		_finish()
		return
	for delay in DELAYS:
		_a_hand_swung_gun_stops_when_the_hand_does(delay)
	for delay in DELAYS:
		_a_joystick_gunner_works_their_own_gun(delay)
	for delay in DELAYS:
		_a_client_pilot_fires_the_fighters_minigun(delay)
	_finish()


## ---- 5. a hand-swung gun, held by a client -------------------------------------------------

## ONE GUNNER, ONE LINK. A fresh pair of worlds with `delay` ticks of one-way lag, a client at the
## door gun, a hand on the grips that swings `SWING` and then holds perfectly still for `HOLD_S`.
func _a_hand_swung_gun_stops_when_the_hand_does(delay: int) -> void:
	var aboard: Dictionary = _stand_a_gunner_up(delay, HELI, DOOR_SEAT)
	if aboard.is_empty():
		return
	var mount: int = int(aboard["mount"])
	var gun: Dictionary = aboard["gun"]
	var hull: int = int(aboard["hull"])
	_check_once("the_door_gunners_seat_works_a_hand_swung_gun", bool(gun.get("pintle", false)),
		"seat %d works mount %d, pintle %s" % [DOOR_SEAT, mount, gun.get("pintle", false)])
	if not bool(gun.get("pintle", false)):
		_teardown()
		return

	var seat_yaw: float = float(_server.seat_pose(HELI, DOOR_SEAT).get("yaw", 0.0))
	# NOT ADDED TO THE TREE. A PintleGun in a scene runs `lead` from its own `_process`, and this
	# suite calls `lead` itself with the step the two worlds are ticking at -- in the tree it would
	# be integrated twice the moment anything here awaited a frame.
	var swivel := PintleGun.new()
	swivel.setup(DOOR_SEAT)
	swivel.mount = mount
	# FITTED THE WAY THE STATION FITS IT -- see CockpitStation._fit_the_gunners_stick. The mount rate
	# and stops are the simulation table read back through gun_schema, never typed in here.
	swivel.fit_the_mount(gun)
	# WHERE THE HAND IS. Taken hold of at the grips as the CLIENT sees them, and then held `SWING`
	# radians round about the craft's vertical -- one movement, and then perfectly still, which is
	# the whole of what this test asks.
	var start: Vector2 = _client_aim(HELI, mount)
	swivel.point_at(start, seat_yaw)
	var grips: Vector3 = swivel._grab_point()
	swivel.offer_hand(RIGHT, grips, 1.0)
	_check_once("and_the_hand_closes_on_the_grips", swivel.held_by == RIGHT,
		"held by %d, grips at %v" % [swivel.held_by, grips])
	var hand: Vector3 = Basis(Vector3.UP, SWING) * grips
	var wanted: float = start.x + SWING

	var trail: PackedFloat32Array = []
	for i in range(int(HOLD_S / DT)):
		# THE REAL LOOP, in the order the game runs it: draw the gun where this machine believes it
		# is, offer the hand to it, and put what it asks for on this machine's input frame.
		swivel.point_at(_client_aim(HELI, mount), seat_yaw)
		swivel.lead(DT)
		swivel.offer_hand(RIGHT, hand, 1.0)
		_advance(1, delay, _controls({
			"roll": swivel.value.x, "pitch": swivel.value.y, "grip_right": 1.0}))
		trail.append(_server_aim(hull, mount).x)

	var watched: int = mini(int(WATCH_S / DT), trail.size())
	var travel: float = 0.0
	for i in range(trail.size() - watched + 1, trail.size()):
		travel += absf(angle_difference(trail[i - 1], trail[i]))
	var ended: float = trail[trail.size() - 1] if trail.size() > 0 else 0.0
	var travel_deg: float = rad_to_deg(travel)
	var error_deg: float = absf(rad_to_deg(angle_difference(wanted, ended)))
	swivel.release()
	swivel.free()
	_teardown()

	print("[gun_link] measure: hand-swung over %d ticks (%.0f ms round trip): ended %.1f deg from"
		% [delay, float(delay) * 2.0 * DT * 1000.0, error_deg]
		+ " the hand, travelled %.1f deg in the last %.1f s" % [travel_deg, WATCH_S])
	_check("a_gunner_who_stops_moving_stops_the_gun_over_a_%d_tick_link" % delay,
		travel_deg <= SETTLED_TRAVEL_DEG and error_deg <= SETTLED_ERROR_DEG,
		"%.1f deg of travel in the last %.1f s and %.1f deg of error; wanted under %.0f and %.0f"
			% [travel_deg, WATCH_S, error_deg, SETTLED_TRAVEL_DEG, SETTLED_ERROR_DEG])


## ---- 16. a gun laid with a joystick, worked by a client ------------------------------------

## THE OTHER KIND OF MOUNT, over the same links. A joystick's deflection says nothing about where
## the gun is, so a client pushing it should traverse its own gun at any delay at all -- and pulling
## the trigger should fire it. Driven at the seam the rig drives: the stick's own deflection on the
## input frame, and the fire bit beside it.
func _a_joystick_gunner_works_their_own_gun(delay: int) -> void:
	var aboard: Dictionary = _stand_a_gunner_up(delay, GUNSHIP, GUNSHIP_SEAT)
	if aboard.is_empty():
		return
	var mount: int = int(aboard["mount"])
	var gun: Dictionary = aboard["gun"]
	var hull: int = int(aboard["hull"])
	var me: int = int(aboard["client"])
	_check_once("the_gunships_first_gun_position_is_laid_with_a_joystick",
		not bool(gun.get("pintle", false)) and bool(gun.get("fitted", false)),
		"seat %d works mount %d, fitted %s, pintle %s"
			% [GUNSHIP_SEAT, mount, gun.get("fitted", false), gun.get("pintle", false)])

	var before: Vector2 = _server_aim(hull, mount)
	_advance(int(PUSH_S / DT), delay, _controls({"roll": 1.0}))
	var after: Vector2 = _server_aim(hull, mount)
	var swung: float = absf(angle_difference(before.x, after.x))
	_check("a_client_on_a_joystick_traverses_its_own_gun_over_a_%d_tick_link" % delay,
		swung > MOVED_RAD, "mount %d moved %.3f rad in %.1f s; wanted over %.2f"
			% [mount, swung, PUSH_S, MOVED_RAD])

	var seen: Dictionary = {}
	for row in _server.shot_states():
		seen[int(row["entity"])] = true
	var rounds: int = 0
	for i in range(int(PUSH_S / DT)):
		_advance(1, delay, _controls({"trigger": 1.0}))
		rounds += _new_rounds_by(me, seen)
	var reload: float = float(gun.get("reload", 1.0))
	var wanted: float = (PUSH_S - float(delay) * 2.0 * DT) / maxf(reload, 0.0001)
	_check("and_its_trigger_fires_it_over_a_%d_tick_link" % delay, float(rounds) >= wanted - 2.0,
		"%d rounds in %.1f s at one every %.3f s; wanted about %.0f" % [rounds, PUSH_S, reload, wanted])
	_teardown()


## ---- 4. the fighter's minigun, fired by a client -----------------------------------------------

## A CLIENT FLYING THE FIGHTER SELECTS THE GUNS AND FIRES THEM, OVER THE LINK -- plan item 4, and item 16's sentence, "the
## cannons in planes that are controlled by joysticks don't seem to work", asked of the only plane with a stick and a
## gun. The minigun is no turret seat's mount: it is station 2 on the weapon selector, and the SERVER fires it for a
## pull at a seat that flies the craft only while the selector is on it. So the client does what a pilot does -- master
## arm and the station as commands on the bus, and the trigger on the frame -- and the rounds are counted twice: made
## by the server with this client's name on them, and ARRIVED on the client, which is what the pilot sees.
##
## And the same trigger on the heat station fires nothing, so the finger that launches a missile never sprays the sky.
func _a_client_pilot_fires_the_fighters_minigun(delay: int) -> void:
	var aboard: Dictionary = _stand_a_crew_member_up(delay, PLANE, COPILOT_SEAT)
	if aboard.is_empty():
		return
	var me: int = int(aboard["client"])
	var hull: int = int(aboard["hull"])
	var guns: Dictionary = {}
	for entry in (_server.missile_schema(PLANE).get("stations", []) as Array):
		if bool((entry as Dictionary).get("gun", false)):
			guns = entry
	_check_once("the_fighter_has_a_gun_station", not guns.is_empty(), "%s" % [_server.missile_schema(PLANE)])
	if guns.is_empty():
		_teardown()
		return
	_command(delay, Sim.Channel.MASTER, 1)
	_command(delay, Sim.Channel.WEAPON, int(guns["station"]))
	var systems: Dictionary = _server.craft_systems(hull)
	_check("a_client_arms_and_selects_the_guns_over_a_%d_tick_link" % delay,
		bool(systems.get("master", false)) and int(systems.get("weapon", -1)) == int(guns["station"]),
		"master %s, weapon %s" % [systems.get("master"), systems.get("weapon")])

	var seen: Dictionary = {}
	for row in _server.shot_states():
		seen[int(row["entity"])] = true
	var arrived: Dictionary = {}
	for row in _client.shot_states():
		arrived[int(row["entity"])] = true
	# THE TRIGGER AS A HEADSET'S STICK SENDS IT: the pull AND the launch bit, together, because that finger carries both
	# (`FlightStick.missile_bindings`). The server decides which acts, and this is the half where it must be the gun.
	var launched_seen: Dictionary = {}
	_new_missiles_by(me, launched_seen)
	var launched: int = 0
	var rounds: int = 0
	for i in range(int(PUSH_S / DT)):
		_advance(1, delay, _controls({"trigger": 1.0, "buttons": BUTTON_LAUNCH}))
		rounds += _new_rounds_by(me, seen)
		launched += _new_missiles_by(me, launched_seen)
	# LET THE LAST OF THEM REACH THE CLIENT, and count what did, off the client's own world.
	for i in range(delay * 2 + 30):
		_advance(1, delay, _controls())
		rounds += _new_rounds_by(me, seen)
	var reached: int = 0
	for row in _client.shot_states():
		if not arrived.has(int(row["entity"])) and int(row.get("shooter", -1)) == me:
			reached += 1
	var reload: float = float(guns.get("reload", 1.0))
	var wanted: float = (PUSH_S - float(delay) * 2.0 * DT) / maxf(reload, 0.0001)
	_check("and_its_trigger_fires_the_minigun_over_a_%d_tick_link" % delay, float(rounds) >= wanted - 2.0,
		"%d rounds in %.1f s at one every %.3f s; wanted about %.0f" % [rounds, PUSH_S, reload, wanted])
	# A ROUND LIVES FOUR SECONDS AND IS STILL FLYING, so every one the server made is still on the wire to be seen.
	_check("and_the_client_sees_every_round_it_fired_over_a_%d_tick_link" % delay,
		rounds > 0 and reached >= rounds - 2, "%d made by the server, %d arrived" % [rounds, reached])
	_check("and_the_same_trigger_on_the_guns_launches_no_missile_over_a_%d_tick_link" % delay,
		launched == 0, "%d missile(s) launched" % launched)

	# THE OTHER DIRECTION: the same finger, pull and launch together, on the heat station -- one missile, and no round.
	# A heat-seeker needs no lock, so nothing but the station stands between this trigger and a launch.
	_command(delay, Sim.Channel.WEAPON, int(_heat_station()))
	var on_heat: int = 0
	var on_heat_launched: int = 0
	for i in range(int(PUSH_S / DT)):
		_advance(1, delay, _controls({"trigger": 1.0, "buttons": BUTTON_LAUNCH}))
		on_heat += _new_rounds_by(me, seen)
		on_heat_launched += _new_missiles_by(me, launched_seen)
	_check("and_on_the_heat_station_the_same_trigger_fires_nothing_over_a_%d_tick_link" % delay, on_heat == 0,
		"%d round(s), weapon %s" % [on_heat, _server.craft_systems(hull).get("weapon")])
	_check("and_launches_one_missile_over_a_%d_tick_link" % delay, on_heat_launched == 1,
		"%d missile(s) launched" % on_heat_launched)

	# AND SAFE ON THE GUNS: master arm off, the gun selected, the same trigger -- nothing at all.
	_command(delay, Sim.Channel.WEAPON, int(guns["station"]))
	_command(delay, Sim.Channel.MASTER, 0)
	var safe: int = 0
	var safe_launched: int = 0
	for i in range(int(PUSH_S / DT)):
		_advance(1, delay, _controls({"trigger": 1.0, "buttons": BUTTON_LAUNCH}))
		safe += _new_rounds_by(me, seen)
		safe_launched += _new_missiles_by(me, launched_seen)
	systems = _server.craft_systems(hull)
	_check("and_safe_on_the_guns_the_trigger_fires_nothing_over_a_%d_tick_link" % delay,
		safe == 0 and safe_launched == 0 and not bool(systems.get("master", true))
			and int(systems.get("weapon", -1)) == int(guns["station"]),
		"%d round(s), %d missile(s); master %s, weapon %s" % [safe, safe_launched,
			systems.get("master"), systems.get("weapon")])
	_teardown()


## Missiles the server has launched since the last look that name `client` as their launcher, by entity -- a count of
## those still in the air goes DOWN when an earlier one ends, which is not a launch un-happening.
func _new_missiles_by(client: int, seen: Dictionary) -> int:
	var count: int = 0
	for row in _server.missile_states():
		var entity: int = int((row as Dictionary).get("entity", 0))
		if seen.has(entity):
			continue
		seen[entity] = true
		if int((row as Dictionary).get("client", -1)) == client:
			count += 1
	return count


## The heat station's number, off the server's schema.
func _heat_station() -> int:
	for entry in (_server.missile_schema(PLANE).get("stations", []) as Array):
		if String((entry as Dictionary).get("name", "")) == "heat":
			return int((entry as Dictionary).get("station", -1))
	return -1


## ONE COMMAND ON THE BUS, as a client sends it: `send_command`, which stamps it on this machine's frames, and long
## enough for it to cross. The `command_*` keys of `set_input` are a SERVER-driven seat's and are not what a client uses.
func _command(delay: int, channel: int, value: int) -> void:
	_client.send_command(channel, value)
	_advance(delay * 2 + 20, delay, _controls())


## ---- the two worlds, and a client in a gunner's seat ----------------------------------------

## A SERVER AND A CLIENT `delay` TICKS APART, a craft of `kind` flown by nobody in particular, and
## this client sat down at `seat`. {} if any of that could not be done, having said which.
func _stand_a_gunner_up(delay: int, kind: int, seat: int) -> Dictionary:
	var aboard: Dictionary = _stand_a_crew_member_up(delay, kind, seat)
	if aboard.is_empty():
		return {}
	var mount: int = int(_server.seat_mount(kind, seat))
	if mount < 0:
		_check_once("seat_%d_of_kind_%d_works_a_gun" % [seat, kind], false, "mount %d" % mount)
		_teardown()
		return {}
	aboard["mount"] = mount
	aboard["gun"] = _server.gun_schema(kind, mount)
	return aboard


## THE SAME, AT ANY SEAT: two worlds, a craft flown by a spare client, and this client sat down at `seat`.
## {"client", "hull"}, or {} having said what went wrong.
func _stand_a_crew_member_up(delay: int, kind: int, seat: int) -> Dictionary:
	_server = ClassDB.instantiate("CockpitWorld")
	_client = ClassDB.instantiate("CockpitWorld")
	_tick = 0
	_in_flight.clear()
	for world in [_server, _client]:
		world.set_tick_rate(TICK_HZ)
	_server.start(0)
	_client.start(PEER)
	for world in [_server, _client]:
		# A FLOOR, so an aircraft nobody is flying does not fall out of the wire's range and clamp
		# every coordinate in the world for the rest of the run. See cockpit_loopback._build_world.
		world.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(400.0, 2.0, 400.0))
	_advance(90, delay)

	var me: int = int(_client.local_client_id())
	if me <= 0:
		_check("the_client_handshook_over_a_%d_tick_link" % delay, false, "client id %d" % me)
		_teardown()
		return {}

	var craft: Dictionary = _server.spawn_pilot(_spare_client(), kind,
		Vector3(0.0, 300.0, 0.0), 0.0, Vector3.ZERO)
	_server.spawn_pilot(me, POD, Vector3(60.0, 4.0, 60.0), 0.0, Vector3.ZERO)
	var hull: int = int(craft.get("vehicle", 0))
	_advance(20, delay)
	var seated: bool = hull != 0 and bool(_server.seat_client(me, hull, seat))
	_check_once("a_client_takes_seat_%d_of_kind_%d" % [seat, kind], seated,
		"client %d into seat %d of %d" % [me, seat, hull])
	if not seated:
		_teardown()
		return {}
	_advance(delay * 2 + 40, delay)
	return {"client": me, "hull": hull}


## WHERE THIS MOUNT IS POINTING ON THE CLIENT, the way the cockpit asks: off the display, which is
## what `Sim.vehicle_turrets` interpolates between.
func _client_aim(kind: int, mount: int) -> Vector2:
	for row in _client.vehicle_states():
		if int(row.get("kind", -1)) != kind:
			continue
		var aimed: Array = row.get("turrets", []) as Array
		if mount < aimed.size():
			return aimed[mount] as Vector2
	return Vector2.ZERO


## And where it really is, on the machine that decides.
func _server_aim(hull: int, mount: int) -> Vector2:
	var aimed: Array = _server.vehicle_state(hull).get("turrets", []) as Array
	return (aimed[mount] as Vector2) if mount < aimed.size() else Vector2.ZERO


## Rounds the server has made since the last look that name `client` as their shooter.
func _new_rounds_by(client: int, seen: Dictionary) -> int:
	var count: int = 0
	for row in _server.shot_states():
		var entity: int = int(row["entity"])
		if seen.has(entity):
			continue
		seen[entity] = true
		if int(row.get("shooter", -1)) == client:
			count += 1
	return count


## A complete control frame: sticks centred, hands where a seated person's hands are.
func _controls(overrides: Dictionary = {}) -> Dictionary:
	var input: Dictionary = {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0,
	}
	for key in overrides:
		input[key] = overrides[key]
	return input


func _advance(ticks: int, delay: int, input: Dictionary = {}) -> void:
	for i in range(ticks):
		if not input.is_empty():
			_client.set_input(input)
		_tick += 1
		_server.tick(DT)
		_client.tick(DT)
		_pump(delay)


## THE LINK IS REALLY `delay + 1` TICKS EACH WAY. A packet is delivered in this pump, which runs after BOTH worlds have ticked,
## so the soonest it is read is the next tick: a 16-tick link here is 17 each way (lane/starve, 2026-09-16, which proved it
## off this very pump). Left as it is on purpose -- every figure these suites have recorded was measured through it.
func _pump(delay: int) -> void:
	for packet in _server.take_outbound():
		_in_flight.append([_tick + delay, false, int(packet["peer"]), packet["bytes"],
			packet["bits"]])
	for packet in _client.take_outbound():
		_in_flight.append([_tick + delay, true, PEER, packet["bytes"], packet["bits"]])
	var still_flying: Array = []
	for entry in _in_flight:
		if entry[0] > _tick:
			still_flying.append(entry)
			continue
		if bool(entry[1]):
			_server.deliver(entry[2], entry[3], entry[4])
		else:
			_client.deliver(0, entry[3], entry[4])
	_in_flight = still_flying


## A client id the server has not handed out, for the aircraft this test flies itself.
func _spare_client() -> int:
	_next_spare += 1
	return 200 + _next_spare


func _teardown() -> void:
	if _client != null:
		_client.teardown()
	if _server != null:
		_server.teardown()
	_client = null
	_server = null
	_in_flight.clear()


func _finish() -> void:
	_teardown()
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
