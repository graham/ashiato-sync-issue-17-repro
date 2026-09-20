extends Node
## Headless: THE AH-64's CHIN GUN FOLLOWS THE GUNNER'S HEAD, LATE, AND FIRES WHERE THE BARREL IS. Read RESULT=.
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/helmet_gun.tscn
##
## The user's request, word for word: "the front player can control a gun mounted on the chin, this gun should follow
## where they look and be able to fire in that direction ... making sure it fires in the right direction, that it
## follows the head position (not instantly, there is some slew delay)."
##
## WHAT IS REAL. A server and two client `CockpitWorld`s and a link this suite carries the packets over, 4 ticks each way
## (tests/shell_prediction.gd's harness): the GUNNER in the Apache's front seat, the PILOT in its back seat. The gunner's
## HEAD goes in through his own input frame -- `set_input`'s `head` and `head_basis`, which is what `PilotRig.read_controls`
## fills from a headset or the desk's mouse look -- and nothing here calls the simulation's gun. What is read back is
## what each machine publishes: the server's mount, the pilot's copy of it, the gunner's own predicted aim, and the
## rounds the server makes.
##
## THE CHECKS, each a thing the user asked for or the brief named:
##   LAG        the head turned 60 degrees in one frame; the barrel follows at the mount's slew (80 deg/s in azimuth,
##              60 in elevation, the ESTIMATE in `gun_of`), measured as the slope across the middle of the move, and
##              a quarter second in it is still less than halfway -- not instant -- and it then reaches the look.
##   STOPS      a head turned 150 degrees leaves the barrel at the TM's 100; 80 degrees down leaves it at 60; up, 11.
##   PEERS      the pilot's machine draws the same barrel as the server, to the wire's quantum; and the gunner's own
##              machine predicts it to the aim's quantum, with NO rollback while his head sweeps.
##   ALONG      a round fired while the barrel is still on its way leaves along the BARREL, at the barrel's own
##              bearing, and nowhere near the head's.
##   HIT/MISS   a wall where the barrel points is hit; a wall where the head points, which the barrel has not reached,
##              is not.
##
## THE MUTANTS it must go red on, each a real way to get this wrong (learnings/2026-09-18-apache.md): the mount snapped
## to the look; the round fired along the look; the head laid unquantised on the gunner's machine; the stops left off.

const TICK_HZ: float = 120.0
const DT: float = 1.0 / TICK_HZ
const LINK: int = 4
const GUNNER_PEER: int = 2
const PILOT_PEER: int = 3
const POD: int = 0
## The mount's rates and stops as the brief and the TM give them, typed here so the suite does not ask the gun table
## what the gun table says. 80 and 60 deg/s; 100 degrees either side; 11 up and 60 down.
const SLEW_YAW: float = 80.0
const SLEW_PITCH: float = 60.0
const YAW_STOP: float = 100.0
const UP_STOP: float = 11.0
const DOWN_STOP: float = 60.0
## The slope is held to this share of the rate; the barrel "reaches" the look within this many degrees.
const RATE_WITHIN: float = 0.03
const REACHED_DEG: float = 0.5
## THE WALLS: 150 m out, 8 m across, on the bearing the barrel is caught at and on the look's.
const WALL_OUT: float = 150.0
const BARREL_BEARING: float = 30.0
const LOOK_BEARING: float = 60.0

var _failures: PackedStringArray = []
var _server: RefCounted = null
var _gunner: RefCounted = null
var _pilot: RefCounted = null
var _tick: int = 0
var _in_flight: Array = []
var _apache: int = 0
var _gunner_id: int = 0
var _head: Quaternion = Quaternion.IDENTITY
var _trigger: float = 0.0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[helmet_gun] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL no CockpitWorld")
		get_tree().quit(1)
		return
	var gun: Dictionary = Sim.gun_of(Sim.Kind.APACHE, 0)
	var poses: Array = Sim.geometry_of(Sim.Kind.APACHE).get("seat_poses", [])
	_check("the_front_seat_flies_and_works_the_helmet_gun",
		poses.size() == 2 and bool((poses[1] as Dictionary).get("flies", false))
			and bool((poses[1] as Dictionary).get("gun", false)) and Sim.mount_of_seat(Sim.Kind.APACHE, 1) == 0
			and Sim.mount_of_seat(Sim.Kind.APACHE, 0) < 0 and bool(gun.get("helmet", false))
			and bool(gun.get("predicted", false)),
		"seat 1 %s, mount %d; seat 0 mount %d; the gun helmet %s, predicted %s" % [poses[1] if poses.size() > 1 else {},
			Sim.mount_of_seat(Sim.Kind.APACHE, 1), Sim.mount_of_seat(Sim.Kind.APACHE, 0), gun.get("helmet"),
			gun.get("predicted")])
	if not _aboard():
		_finish()
		return
	_the_barrel_follows_the_look_late_at_the_slew_and_reaches_it()
	_the_barrel_stops_at_the_stops()
	_the_pilot_draws_the_same_barrel_and_the_gunner_predicts_it_without_rolling_back()
	_a_round_leaves_along_the_barrel_and_hits_where_the_barrel_points()
	_finish()


# ---------------------------------------------------------------------------------------------------------------------

## THE LAG. The head is turned 60 degrees left in one frame; the SERVER's mount is sampled every tick.
func _the_barrel_follows_the_look_late_at_the_slew_and_reaches_it() -> void:
	_look(0.0, 0.0)
	_advance(TICK_HZ * 2.0)
	var start: Vector2 = _server_aim()
	_look(60.0, 0.0)
	var samples: Array = []
	for i in range(int(TICK_HZ * 2.0)):
		_advance(1)
		samples.append([float(i + 1) * DT, rad_to_deg(_server_aim().x)])
	var quarter: float = float(samples[int(TICK_HZ * 0.25)][1])
	var rate: float = _slope(samples, 60.0)
	var final: float = float(samples[-1][1])
	var reached_at: float = -1.0
	for s in samples:
		if absf(float(s[1]) - 60.0) < REACHED_DEG:
			reached_at = float(s[0])
			break
	_check("the_barrel_follows_the_look_late_at_its_azimuth_slew",
		absf(rate - SLEW_YAW) <= SLEW_YAW * RATE_WITHIN and quarter < 30.0 and absf(rad_to_deg(start.x)) < 0.1,
		"from %.2f deg the look went to 60: %.1f deg/s across the middle of the move (the mount's %.0f), %.1f deg a quarter second in"
			% [rad_to_deg(start.x), rate, SLEW_YAW, quarter])
	_check("and_reaches_the_look",
		absf(final - 60.0) < REACHED_DEG and reached_at > 0.6,
		"at %.2f deg after 2 s; within %.1f deg at %.2f s (60 deg at %.0f deg/s is %.2f s, plus the link)"
			% [final, REACHED_DEG, reached_at, SLEW_YAW, 60.0 / SLEW_YAW])
	# AND IN ELEVATION, at its own rate: the look 20 degrees down.
	_look(60.0, -20.0)
	samples.clear()
	for i in range(int(TICK_HZ * 1.5)):
		_advance(1)
		samples.append([float(i + 1) * DT, rad_to_deg(_server_aim().y)])
	var pitch_rate: float = -_slope(samples, -20.0)
	_check("and_follows_it_down_at_its_elevation_slew",
		absf(pitch_rate - SLEW_PITCH) <= SLEW_PITCH * RATE_WITHIN and absf(float(samples[-1][1]) + 20.0) < REACHED_DEG,
		"%.1f deg/s down (the mount's %.0f), at %.2f deg after 1.5 s" % [pitch_rate, SLEW_PITCH, float(samples[-1][1])])


## THE STOPS: past them, the barrel waits at them.
func _the_barrel_stops_at_the_stops() -> void:
	var said: PackedStringArray = []
	var ok: bool = true
	for case in [[150.0, 0.0, YAW_STOP, 0.0], [-150.0, 0.0, -YAW_STOP, 0.0], [0.0, -80.0, 0.0, -DOWN_STOP],
			[0.0, 30.0, 0.0, UP_STOP]]:
		_look(float(case[0]), float(case[1]))
		_advance(TICK_HZ * 4.0)
		var aim: Vector2 = _server_aim()
		var yaw: float = rad_to_deg(aim.x)
		var pitch: float = rad_to_deg(aim.y)
		var right: bool = absf(yaw - float(case[2])) < 0.2 and absf(pitch - float(case[3])) < 0.6
		ok = ok and right
		said.append("look %+.0f/%+.0f -> barrel %+.2f/%+.2f" % [case[0], case[1], yaw, pitch])
	_check("the_barrel_waits_at_the_tms_stops", ok, ", ".join(said))


## THE SAME BARREL ON EVERY MACHINE, AND NO ROLLBACK FROM THE HEAD. The head sweeps smoothly for 3 s -- the gunner's
## own world must not resimulate once for it -- and then rests; the pilot's copy and the gunner's prediction are read.
func _the_pilot_draws_the_same_barrel_and_the_gunner_predicts_it_without_rolling_back() -> void:
	_look(0.0, 0.0)
	_advance(TICK_HZ * 3.0)
	var before: int = int(_gunner.resim_stats().get("count", 0))
	for i in range(int(TICK_HZ * 3.0)):
		var t: float = float(i) * DT
		_look(40.0 * sin(t * 1.3), -10.0 + 8.0 * sin(t * 0.7))
		_advance(1)
	var resims: int = int(_gunner.resim_stats().get("count", 0)) - before
	_advance(TICK_HZ * 1.5)
	var server: Vector2 = _server_aim()
	var pilot: Vector2 = _aim_on(_pilot)
	var mine: Dictionary = _gunner.gunner_state(_gunner_id)
	var predicted: Vector2 = mine.get("aim", Vector2(99, 99)) as Vector2
	var of_server: Dictionary = _server.gunner_state(_gunner_id)
	var authority: Vector2 = of_server.get("aim", Vector2(-99, -99)) as Vector2
	_check("the_gunner_predicts_his_barrel_without_rolling_back_for_his_head",
		resims == 0 and predicted.distance_to(authority) < 0.0001,
		"%d resimulations while the head swept for 3 s; his predicted aim %s, the server's %s" % [resims, predicted,
			authority])
	_check("the_pilot_draws_the_same_barrel",
		absf(angle_difference(pilot.x, server.x)) < 0.004 and absf(pilot.y - server.y) < 0.004,
		"server %.4f/%.4f, the pilot's machine %.4f/%.4f (the wire's bearing quantum is 0.003)"
			% [server.x, server.y, pilot.x, pilot.y])


## ALONG THE BARREL, AND ONLY THERE. The head is turned to the second wall, 60 degrees left; while the barrel is still on
## its way, at the first wall's 30 degrees, one round is fired. It must leave at the barrel's bearing and hit the first
## wall; the second, where the gunner is looking, it must not reach.
func _a_round_leaves_along_the_barrel_and_hits_where_the_barrel_points() -> void:
	_look(0.0, 0.0)
	_advance(TICK_HZ * 2.5)
	# EVERY ROUND OF THIS GUNNER'S, RECORDED EACH TICK WHILE IT EXISTS: its first row (where and how it left) and its
	# last (where it ended). The server retires a round soon after it lands, so reading afterwards reads nothing.
	var seen: Dictionary = {}
	for row in _rounds():
		seen[int(row["entity"])] = {"first": row, "last": row, "old": true}
	_look(LOOK_BEARING, 0.0)
	var fired_at: float = INF
	for i in range(int(TICK_HZ * 2.5)):
		# THE TRIGGER WHEN THE GUNNER'S OWN BARREL CROSSES THE FIRST WALL: what he would do, watching the ring.
		var mine: Vector2 = _gunner.gunner_state(_gunner_id).get("aim", Vector2.ZERO) as Vector2
		_trigger = 1.0 if fired_at == INF and rad_to_deg(mine.x) >= BARREL_BEARING else 0.0
		if _trigger > 0.0:
			fired_at = rad_to_deg(mine.x)
		_advance(1)
		_trigger = 0.0
		for row in _rounds():
			var id: int = int(row["entity"])
			if not seen.has(id):
				seen[id] = {"first": row, "last": row, "old": false}
			else:
				(seen[id] as Dictionary)["last"] = row
	var fresh: Array = []
	var ended: Array = []
	for id in seen:
		var record: Dictionary = seen[id]
		if not bool(record["old"]):
			fresh.append(record["first"])
			ended.append(record["last"])
	var craft: Dictionary = _server.vehicle_state(_apache)
	var basis := Basis(craft.get("basis", Quaternion()) as Quaternion)
	var bearings: PackedStringArray = []
	var along: bool = not fresh.is_empty()
	var hit_a: int = 0
	var hit_b: int = 0
	for i in range(fresh.size()):
		var row: Dictionary = fresh[i]
		var local: Vector3 = basis.inverse() * ((row["velocity"] as Vector3) - (craft.get("velocity", Vector3.ZERO) as Vector3))
		var bearing: float = rad_to_deg(atan2(-local.x, -local.z))
		bearings.append("%.1f" % bearing)
		along = along and absf(bearing - fired_at) < 1.0 and absf(bearing - LOOK_BEARING) > 20.0
		var last: Dictionary = ended[i]
		var at: Vector3 = last["impact"] if not bool(last.get("flying", true)) else Vector3(INF, INF, INF)
		if _in_wall(at, BARREL_BEARING):
			hit_a += 1
		if _in_wall(at, LOOK_BEARING):
			hit_b += 1
	_check("a_round_leaves_along_the_barrel_not_the_look",
		fresh.size() == 1 and along,
		"%d round(s), fired with the gunner's barrel at %.1f deg and his look at %.0f: left at %s deg"
			% [fresh.size(), fired_at, LOOK_BEARING, ", ".join(bearings)])
	var ends: PackedStringArray = []
	for last in ended:
		ends.append("%s at %s" % ["flying" if bool((last as Dictionary).get("flying", true)) else "stopped",
			(last as Dictionary).get("impact", Vector3.ZERO)])
	_check("it_hits_where_the_barrel_points_and_misses_where_the_head_does", hit_a == fresh.size() and hit_a > 0 and hit_b == 0,
		"the wall at %.0f deg took %d, the wall at %.0f deg (the look) %d; the rounds ended %s" % [BARREL_BEARING, hit_a,
			LOOK_BEARING, hit_b, ", ".join(ends)])


# ---------------------------------------------------------------------------------------------------------------------

## A slope in degrees a second, fitted by least squares over the middle of a move from its first sample to `to`: the
## samples between 20 and 80 per cent of the way, so neither the link's start nor the arrival bends it.
func _slope(samples: Array, to: float) -> float:
	var from: float = float(samples[0][1])
	var xs: Array = []
	var ys: Array = []
	for s in samples:
		var share: float = (float(s[1]) - from) / (to - from) if absf(to - from) > 0.001 else 0.0
		if share > 0.2 and share < 0.8:
			xs.append(float(s[0]))
			ys.append(float(s[1]))
	if xs.size() < 3:
		return 0.0
	var mx: float = 0.0
	var my: float = 0.0
	for i in range(xs.size()):
		mx += xs[i]
		my += ys[i]
	mx /= xs.size()
	my /= xs.size()
	var num: float = 0.0
	var den: float = 0.0
	for i in range(xs.size()):
		num += (xs[i] - mx) * (ys[i] - my)
		den += (xs[i] - mx) * (xs[i] - mx)
	return num / den if den > 0.0 else 0.0


## THE GUNNER'S LOOK: `yaw` degrees to port, `pitch` up, as a headset reports it in the seat's frame.
func _look(yaw: float, pitch: float) -> void:
	_head = Quaternion(Vector3.UP, deg_to_rad(yaw)) * Quaternion(Vector3.RIGHT, deg_to_rad(pitch))


func _server_aim() -> Vector2:
	var turrets: Array = _server.vehicle_state(_apache).get("turrets", []) as Array
	return turrets[0] as Vector2 if not turrets.is_empty() else Vector2(99, 99)


func _aim_on(world: RefCounted) -> Vector2:
	for row in world.vehicle_states():
		if int((row as Dictionary).get("kind", -1)) == Sim.Kind.APACHE:
			var turrets: Array = (row as Dictionary).get("turrets", []) as Array
			return turrets[0] as Vector2 if not turrets.is_empty() else Vector2(99, 99)
	return Vector2(99, 99)


func _rounds() -> Array:
	var out: Array = []
	for row in _server.shot_states():
		if int((row as Dictionary).get("shooter", -1)) == _gunner_id:
			out.append(row)
	return out


## WHETHER A POINT IS ON THE WALL ON `bearing` (degrees to port of the Apache's nose): inside the box `_aboard` builds
## there -- a static box is square to the world, so the wall is the box round an 8 m by 2 m slab turned to face the gun --
## with a 0.3 m margin for where on its face the round stopped.
func _in_wall(at: Vector3, bearing: float) -> bool:
	var d: Vector3 = (at - _wall_centre(bearing)).abs()
	var half: Vector3 = _wall_half(bearing) + Vector3(0.3, 0.3, 0.3)
	return d.x < half.x and d.y < half.y and d.z < half.z


func _wall_half(bearing: float) -> Vector3:
	var b: float = deg_to_rad(bearing)
	return Vector3(4.0 * absf(cos(b)) + 1.0 * absf(sin(b)), 5.0, 4.0 * absf(sin(b)) + 1.0 * absf(cos(b)))


func _wall_centre(bearing: float) -> Vector3:
	var b: float = deg_to_rad(bearing)
	return Vector3(-sin(b) * WALL_OUT, 5.0, -cos(b) * WALL_OUT)


## THE CREW ABOARD: the server, the gunner and the pilot, a floor in every world, two walls, the Apache on the floor and
## both players in their seats.
func _aboard() -> bool:
	_server = ClassDB.instantiate("CockpitWorld")
	_gunner = ClassDB.instantiate("CockpitWorld")
	_pilot = ClassDB.instantiate("CockpitWorld")
	for world in [_server, _gunner, _pilot]:
		world.set_tick_rate(TICK_HZ)
	_server.start(0)
	_gunner.start(GUNNER_PEER)
	_pilot.start(PILOT_PEER)
	for world in [_server, _gunner, _pilot]:
		world.add_static_box(Vector3(0.0, -10.0, 0.0), Vector3(12000.0, 10.0, 12000.0))
		for bearing in [BARREL_BEARING, LOOK_BEARING]:
			# A wall across the line of fire: 8 m wide, 2 m thick, 10 m tall, as its square box.
			world.add_static_box(_wall_centre(bearing), _wall_half(bearing))
	_advance(90)
	_gunner_id = int(_gunner.local_client_id())
	var pilot_id: int = int(_pilot.local_client_id())
	if _gunner_id <= 0 or pilot_id <= 0:
		_check("both_clients_handshook", false, "gunner %d, pilot %d" % [_gunner_id, pilot_id])
		return false
	var half: Vector3 = Sim.geometry_of(Sim.Kind.APACHE).get("extents", Vector3.ONE)
	_apache = int(_server.spawn_vehicle(Sim.Kind.APACHE, Vector3(0.0, half.y + 0.02, 0.0), 0.0, Vector3.ZERO))
	_server.spawn_pilot(_gunner_id, POD, Vector3(300.0, 4.0, 300.0), 0.0, Vector3.ZERO)
	_server.spawn_pilot(pilot_id, POD, Vector3(320.0, 4.0, 300.0), 0.0, Vector3.ZERO)
	_advance(20)
	var seated: bool = bool(_server.seat_client(_gunner_id, _apache, 1)) and bool(_server.seat_client(pilot_id, _apache, 0))
	_advance(LINK * 2 + 240)
	_check("the_gunner_and_the_pilot_take_their_seats", seated and _apache > 0, "apache %d" % _apache)
	return seated


func _advance(ticks: float) -> void:
	for i in range(int(ticks)):
		_gunner.set_input(_controls(_head, _trigger))
		_pilot.set_input(_controls(Quaternion.IDENTITY, 0.0))
		_tick += 1
		_server.tick(DT)
		_gunner.tick(DT)
		_pilot.tick(DT)
		_pump()


## THE FRAME A SEATED PLAYER SENDS, with the head at a seated eye over the anchor and turned by `head`.
func _controls(head: Quaternion, trigger: float) -> Dictionary:
	return {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0), "head_basis": head,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": trigger,
	}


func _pump() -> void:
	for packet in _server.take_outbound():
		_in_flight.append([_tick + LINK, int(packet["peer"]), false, packet["bytes"], packet["bits"]])
	for pair in [[_gunner, GUNNER_PEER], [_pilot, PILOT_PEER]]:
		for packet in (pair[0] as RefCounted).take_outbound():
			_in_flight.append([_tick + LINK, int(pair[1]), true, packet["bytes"], packet["bits"]])
	var still: Array = []
	for entry in _in_flight:
		if int(entry[0]) > _tick:
			still.append(entry)
			continue
		if bool(entry[2]):
			_server.deliver(int(entry[1]), entry[3], entry[4])
		elif int(entry[1]) == GUNNER_PEER:
			_gunner.deliver(0, entry[3], entry[4])
		elif int(entry[1]) == PILOT_PEER:
			_pilot.deliver(0, entry[3], entry[4])
	_in_flight = still


func _finish() -> void:
	for world in [_gunner, _pilot, _server]:
		if world != null:
			world.teardown()
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
