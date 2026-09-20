extends Node
## Headless: THE AH-64's HELLFIRES LOCK WHAT A CREWMAN LOOKS AT, AND FLY TO IT. Read RESULT=.
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/helmet_lock.tscn
##
## The user, word for word: "it should have missiles too, but the targeting is done via the helmet, not fixed forward like
## the plane." Team-lead's rulings: SHIPS AND AIRCRAFT, never a land vehicle; BOTH seats lock, each with his own helmet;
## no fixed-forward mode.
##
## WHAT IS REAL. A server and two client `CockpitWorld`s over a 4-tick link (tests/helmet_gun.gd's harness): the gunner
## in the front seat, the pilot in the back. The simulation's own seeker (`work_the_seekers`) and launch (`launch_from`),
## on the server, worked by what each machine sends: its crewman's input frame -- his HEAD (`head`, `head_basis`, what `PilotRig.read_controls` fills from a
## headset or the desk's mouse look), the LOCK and LAUNCH buttons, and the master arm as a bus command. Nothing here calls
## `launch_missile`. The Apache stands on a pad 20 m over the sea, engines off; the crew are seated as players are.
##
## THE CHECKS:
##   LOOK     the gunner looks at a patrol boat 45 degrees off the nose, presses LOCK, and the seeker locks IT.
##   AWAY     the same boat, the gunner looking 12 degrees beside it: LOCK finds nothing.
##   BOTH     the pilot, in the back seat, looks at an aircraft 30 degrees the other side and locks IT, with his own
##            head, while the gunner's lock stays on the boat.
##   LAND     a car on the shore, looked at squarely: never locking, never locked.
##   FLIES    master arm on, the gunner's LAUNCH, and the Hellfire leaves TOWARD the boat -- within its seeker's gimbal of
##            the line to it, where one sent along the nose would be 45 degrees off -- and strikes it. AND ACROSS THE
##            NOSE: a boat 30 degrees to starboard, which a missile from the first loaded rail (port) would reach only
##            through the Apache's own nose, is struck too, and the Apache is not.
##
## THE MUTANT it must go red on (learnings/2026-09-18-apache.md): the seeker looking along the NOSE instead of the head.

const TICK: float = 1.0 / 120.0
const TICK_HZ: float = 120.0
const LINK: int = 4
const GUNNER_PEER: int = 2
const PILOT_PEER: int = 3
const POD: int = 0
## THE PAD the Apache stands on: its top face this high over the sea, and only a little bigger than the aircraft. The
## first had a 60 m clifftop, and every Hellfire flew into it: a missile thrown off a rail two metres up, a metre a
## second down, meets a flat roof within 20 m. From the air it meets nothing, and nor does it off the edge of a pad.
const CLIFF: float = 20.0
const PAD: Vector3 = Vector3(4.0, 5.0, 9.0)
## THE BOAT, 1.5 km out on this bearing (degrees to port of the nose), and how far beside it the "away" look is.
const BOAT_OUT: float = 1500.0
const BOAT_BEARING: float = 45.0
const AWAY_DEG: float = 12.0
## AND A BOAT THIS FAR TO STARBOARD, where the first loaded rail is on the PORT wing: a missile thrown from there toward
## it crosses the Apache's own nose. The first Hellfire reel (2026-09-18) did exactly that, and the Apache burned.
const ACROSS_DEG: float = 30.0
## THE AIRCRAFT, 2 km out, this far to starboard and this high.
const PLANE_OUT: float = 2000.0
const PLANE_BEARING: float = -30.0
const PLANE_HEIGHT: float = 300.0
## THE CAR on the shore, 900 m out, 20 degrees to port.
const CAR_OUT: float = 900.0
const CAR_BEARING: float = 20.0
## The Hellfire row's 1.0 s lock and a margin; how long the missile is given to arrive.
const LOCK_S: float = 2.0
const FLY_S: float = 12.0

var _failures: PackedStringArray = []
var _server: RefCounted = null
var _gunner: RefCounted = null
var _pilot: RefCounted = null
var _tick: int = 0
var _in_flight: Array = []
var _apache: int = 0
## Each crewman's SYNC CLIENT ID, which is what the server's lock rows are keyed by.
var _gunner_id: int = 0
var _pilot_id: int = 0
var _gunner_in: Dictionary = {}
var _pilot_in: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[helmet_lock] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_the_hellfires_are_the_helmets()
	_the_gunner_locks_what_he_looks_at()
	_the_pilot_locks_by_his_own_helmet()
	_never_a_land_vehicle()
	_the_hellfire_flies_to_the_boat(BOAT_BEARING, "")
	_the_hellfire_flies_to_the_boat(-ACROSS_DEG, "_across_the_nose")
	_finish()


## ---- the table -------------------------------------------------------------------------------------------------------

## THE STATION IS THE SIMULATION'S, and says what the ruling says: one Hellfire station, the helmet's, eight rails, both
## seats launching; and the row sees ships and not the ground.
func _the_hellfires_are_the_helmets() -> void:
	var schema: Dictionary = Sim.missile_schema(Sim.Kind.APACHE)
	var stations: Array = schema.get("stations", []) as Array
	var station: Dictionary = stations[0] if stations.size() == 1 else {}
	var row: Dictionary = Sim.missile_type(int(station.get("type", -1)))
	_check("one_helmet_station_of_eight_hellfires", String(station.get("name", "")) == "hellfire"
		and bool(station.get("helmet", false)) and (station.get("pylon_ids", []) as Array).size() == 8,
		"stations %s" % str(stations.map(func(s): return [s.get("name"), s.get("helmet"), (s.get("pylon_ids", []) as Array).size()])))
	_check("both_seats_launch", (schema.get("launch_seats", []) as Array) == [0, 1], "launch seats %s" % str(schema.get("launch_seats")))
	_check("ships_and_aircraft_never_the_ground", bool(row.get("ships", false)) and not bool(row.get("ground", true))
		and not bool(row.get("semi_active", true)), "ships %s, ground %s, semi-active %s" % [row.get("ships"), row.get("ground"),
			row.get("semi_active")])


## ---- LOOK and AWAY -----------------------------------------------------------------------------------------------------

func _the_gunner_locks_what_he_looks_at() -> void:
	if not _begin():
		return
	var boat: int = _a_boat()
	_step(0.5)
	# AWAY FIRST: looking beside it, a press finds nothing, and the seeker stays searching.
	_look(_gunner_in, _bearing_to(boat) + Vector2(AWAY_DEG, 0.0))
	_step(0.3)
	var away: Dictionary = _press_lock(_gunner_in, _gunner_id)
	_check("looking_beside_the_boat_locks_nothing", String(away.get("phase_name", "")) != "locking"
		and String(away.get("phase_name", "")) != "locked" and int(away.get("target", 0)) != boat,
		"phase %s on %d, %.0f degrees beside the boat" % [away.get("phase_name", "none"), int(away.get("target", 0)), AWAY_DEG])
	# AND AT IT: the same press, the head on the boat.
	_look(_gunner_in, _bearing_to(boat))
	_step(0.3)
	var row: Dictionary = _press_lock(_gunner_in, _gunner_id)
	_check("the_gunner_locks_the_boat_he_looks_at", String(row.get("phase_name", "")) == "locked" and int(row.get("target", 0)) == boat,
		"phase %s on %d (the boat %d, %.0f degrees off the nose)" % [row.get("phase_name", "none"), int(row.get("target", 0)), boat,
			BOAT_BEARING])
	_end()


## ---- BOTH ---------------------------------------------------------------------------------------------------------------

func _the_pilot_locks_by_his_own_helmet() -> void:
	if not _begin():
		return
	var boat: int = _a_boat()
	var plane: int = int(_server.spawn_vehicle(Sim.Kind.PLANE, _out(PLANE_BEARING, PLANE_OUT, PLANE_HEIGHT), 0.0,
		Vector3.ZERO))
	_step(0.5)
	_look(_gunner_in, _bearing_to(boat))
	_look(_pilot_in, _bearing_to(plane))
	_step(0.3)
	var gunner: Dictionary = _press_lock(_gunner_in, _gunner_id)
	var pilot: Dictionary = _press_lock(_pilot_in, _pilot_id)
	gunner = _lock_of(_gunner_id)
	_check("the_pilot_locks_the_aircraft_he_looks_at", String(pilot.get("phase_name", "")) == "locked"
		and int(pilot.get("target", 0)) == plane, "phase %s on %d (the aircraft %d, %.0f degrees to starboard)" % [
			pilot.get("phase_name", "none"), int(pilot.get("target", 0)), plane, -PLANE_BEARING])
	_check("and_the_gunner_keeps_his_boat", String(gunner.get("phase_name", "")) == "locked" and int(gunner.get("target", 0)) == boat,
		"gunner %s on %d (the boat %d)" % [gunner.get("phase_name", "none"), int(gunner.get("target", 0)), boat])
	_end()


## ---- LAND ---------------------------------------------------------------------------------------------------------------

func _never_a_land_vehicle() -> void:
	if not _begin():
		return
	var shore: Vector3 = _out(CAR_BEARING, CAR_OUT, 0.0)
	_server.add_static_box(shore + Vector3(0.0, -5.0, 0.0), Vector3(40.0, 5.0, 40.0))
	var car: int = int(_server.spawn_vehicle(Sim.Kind.CAR, shore + Vector3(0.0, 0.7, 0.0), 0.0, Vector3.ZERO))
	_step(0.5)
	_look(_gunner_in, _bearing_to(car))
	_step(0.3)
	var phases: Dictionary = {}
	_press(_gunner_in, Sim.BUTTON_LOCK)
	var t: float = 0.0
	while t < LOCK_S:
		_step(TICK * 4.0)
		t += TICK * 4.0
		phases[String(_lock_of(_gunner_id).get("phase_name", "none"))] = true
	_check("it_never_locks_a_land_vehicle", car != 0 and not phases.has("locking") and not phases.has("locked"),
		"phases %s over %.1f s, looking straight at a car %.0f m out" % [str(phases.keys()), t, CAR_OUT])
	_end()


## ---- FLIES --------------------------------------------------------------------------------------------------------------

func _the_hellfire_flies_to_the_boat(bearing: float, said: String) -> void:
	if not _begin():
		return
	var boat: int = _a_boat(bearing)
	_step(0.5)
	_look(_gunner_in, _bearing_to(boat))
	_step(0.3)
	var row: Dictionary = _press_lock(_gunner_in, _gunner_id)
	if String(row.get("phase_name", "")) != "locked":
		_check("a_hellfire_leaves_for_the_boat" + said, false, "no lock: %s" % row.get("phase_name", "none"))
		_end()
		return
	_gunner.send_command(Sim.Channel.MASTER, 1)
	_step(0.2)
	var before: int = (_server.missile_states() as Array).size()
	_press(_gunner_in, Sim.BUTTON_LAUNCH)
	var launched: Array = _server.missile_states() as Array
	if launched.size() <= before:
		_check("a_hellfire_leaves_for_the_boat" + said, false, "no missile; why %s" % _lock_of(_gunner_id).get("why_name", "?"))
		_end()
		return
	var missile: Dictionary = launched[launched.size() - 1]
	var entity: int = int(missile.get("entity", 0))
	var at: Vector3 = missile.get("position", Vector3.ZERO)
	var going: Vector3 = (missile.get("velocity", Vector3.ZERO) as Vector3).normalized()
	var toward: Vector3 = ((_server.vehicle_state(boat) as Dictionary).get("position", Vector3.ZERO) as Vector3 - at).normalized()
	# FROM THE WING ON THE BOAT'S SIDE: a rail on the other wing throws its missile across the Apache's own nose, and the
	# seeker's ray to the boat passes through the Apache on the way -- blind, unguided, falling, until it is clear.
	var rails: Array = Sim.missile_schema(Sim.Kind.APACHE).get("pylons", []) as Array
	var pylon: int = int(missile.get("pylon", -1))
	var rail_x: float = (rails[pylon] as Vector3).x if pylon >= 0 and pylon < rails.size() else 0.0
	_check("it_leaves_from_the_wing_on_the_boats_side" + said, rail_x != 0.0 and signf(rail_x) == -signf(bearing),
		"rail %d at x %+.2f, the boat %.0f degrees to %s" % [pylon, rail_x, absf(bearing), "port" if bearing > 0.0 else "starboard"])
	var gimbal: float = float(Sim.missile_type(int(missile.get("type", 0))).get("gimbal", 0.0))
	var off: float = going.angle_to(toward)
	_check("it_leaves_toward_the_boat_not_along_the_nose" + said, off < gimbal * 0.5,
		"%.1f degrees off the line to the boat, the seeker's gimbal %.1f; the nose is %.0f off it" % [rad_to_deg(off),
			rad_to_deg(gimbal), rad_to_deg(Vector3.FORWARD.angle_to(toward))])
	# UNTIL IT ENDS: a missile that has ended stays in the list a moment, not flying, naming what it struck.
	var closest: float = INF
	var t: float = 0.0
	var ended: Dictionary = {}
	while t < FLY_S and ended.is_empty():
		_step(TICK * 4.0)
		t += TICK * 4.0
		closest = minf(closest, _gap(entity, boat))
		for m in (_server.missile_states() as Array):
			if int((m as Dictionary).get("entity", 0)) == entity and not bool(m.get("flying", true)):
				ended = m
	_check("and_strikes_it" + said, int(ended.get("target_hit", 0)) == boat,
		"ended %s after %.1f s on %d (the boat %d) at %s, surface %d, closest sampled %.1f m" % [not ended.is_empty(), t,
			int(ended.get("target_hit", 0)), boat, ended.get("position", Vector3.ZERO), int(ended.get("surface", -1)), closest])
	_end()


## ---- the world, the crew and their frames ------------------------------------------------------------------------------

## THE CREW ABOARD: a server and two clients, the pad in every world, the Apache on it, and both players seated.
func _begin() -> bool:
	_end()
	_server = ClassDB.instantiate("CockpitWorld")
	_gunner = ClassDB.instantiate("CockpitWorld")
	_pilot = ClassDB.instantiate("CockpitWorld")
	for world in [_server, _gunner, _pilot]:
		world.set_tick_rate(TICK_HZ)
	_server.start(0)
	_gunner.start(GUNNER_PEER)
	_pilot.start(PILOT_PEER)
	for world in [_server, _gunner, _pilot]:
		world.add_static_box(Vector3(0.0, CLIFF - PAD.y, 0.0), PAD)
	_gunner_in = _frame()
	_pilot_in = _frame()
	_advance(90)
	_gunner_id = int(_gunner.local_client_id())
	_pilot_id = int(_pilot.local_client_id())
	var half: Vector3 = Sim.geometry_of(Sim.Kind.APACHE).get("extents", Vector3.ONE)
	_apache = int(_server.spawn_vehicle(Sim.Kind.APACHE, Vector3(0.0, CLIFF + half.y + 0.02, 0.0), 0.0, Vector3.ZERO))
	_server.spawn_pilot(_gunner_id, POD, Vector3(300.0, 4.0, 300.0), 0.0, Vector3.ZERO)
	_server.spawn_pilot(_pilot_id, POD, Vector3(320.0, 4.0, 300.0), 0.0, Vector3.ZERO)
	_advance(20)
	var seated: bool = _gunner_id > 0 and _pilot_id > 0 and bool(_server.seat_client(_gunner_id, _apache, 1))
	seated = seated and bool(_server.seat_client(_pilot_id, _apache, 0))
	_advance(LINK * 2 + 120)
	_check("the_crew_take_their_seats", seated and _apache != 0,
		"apache %d, gunner client %d, pilot client %d" % [_apache, _gunner_id, _pilot_id])
	return seated


## A SEATED CREWMAN'S FRAME: hands still, head at the seated eye, looking ahead.
func _frame() -> Dictionary:
	return {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0, "buttons": 0, "trigger": 0.0,
		"head": Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0), "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY, "grip_left": 0.0, "grip_right": 0.0}


## THE HEAD TURNED TO (yaw to port, pitch up), degrees, in the seat's frame: yaw first, then pitch.
func _look(frame: Dictionary, degrees: Vector2) -> void:
	frame["head_basis"] = Quaternion(Vector3.UP, deg_to_rad(degrees.x)) * Quaternion(Vector3.RIGHT, deg_to_rad(degrees.y))


## THE BEARING AND ELEVATION OF A VEHICLE from the Apache's middle, degrees, the way `_look` takes them. The Apache faces
## -Z and stands still, so the craft's frame is the world's turned by nothing; at a kilometre the eye's metre from the
## middle is a twentieth of a degree.
func _bearing_to(vehicle: int) -> Vector2:
	var there: Vector3 = (_server.vehicle_state(vehicle) as Dictionary).get("position", Vector3.ZERO)
	var here: Vector3 = (_server.vehicle_state(_apache) as Dictionary).get("position", Vector3.ZERO)
	var d: Vector3 = there - here
	return Vector2(rad_to_deg(atan2(-d.x, -d.z)), rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length())))


## A POINT `out` metres from the Apache on `bearing` degrees to port, `up` metres high.
func _out(bearing: float, out: float, up: float) -> Vector3:
	var b: float = deg_to_rad(bearing)
	return Vector3(-sin(b) * out, up, -cos(b) * out)


func _a_boat(bearing: float = BOAT_BEARING) -> int:
	return int(_server.spawn_vehicle(Sim.Kind.GUNBOAT, _out(bearing, BOAT_OUT, 0.0), 0.0, Vector3.ZERO))


## ONE PRESS of a button, as an edge: held for four ticks, let go, and the link's round trip waited out.
func _press(frame: Dictionary, button: int) -> void:
	frame["buttons"] = button
	_advance(4)
	frame["buttons"] = 0
	_advance(4 + LINK * 2)


## LOCK PRESSED, and the seeker given its time: the seat's lock row when it is locked, or at the end of LOCK_S.
func _press_lock(frame: Dictionary, client: int) -> Dictionary:
	_press(frame, Sim.BUTTON_LOCK)
	var t: float = 0.0
	var row: Dictionary = _lock_of(client)
	while t < LOCK_S and String(row.get("phase_name", "")) != "locked":
		_advance(4)
		t += TICK * 4.0
		row = _lock_of(client)
	return row


func _lock_of(client: int) -> Dictionary:
	for row in (_server.lock_states() as Array):
		if int((row as Dictionary).get("client", -1)) == client:
			return row
	return {}


## HOW FAR A MISSILE IS FROM A VEHICLE, or INF when either is gone.
func _gap(missile: int, vehicle: int) -> float:
	var at: Vector3 = Vector3.INF
	for m in (_server.missile_states() as Array):
		if int((m as Dictionary).get("entity", 0)) == missile:
			at = (m as Dictionary).get("position", Vector3.ZERO)
	var there: Dictionary = _server.vehicle_state(vehicle)
	if at == Vector3.INF or there.is_empty():
		return INF
	return at.distance_to(there.get("position", Vector3.ZERO) as Vector3)


func _step(seconds: float) -> void:
	_advance(maxi(1, int(round(seconds / TICK))))


func _advance(ticks: int) -> void:
	for i in range(ticks):
		_gunner.set_input(_gunner_in)
		_pilot.set_input(_pilot_in)
		_tick += 1
		_server.tick(TICK)
		_gunner.tick(TICK)
		_pilot.tick(TICK)
		_pump()


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


func _end() -> void:
	for world in [_gunner, _pilot, _server]:
		if world != null:
			world.teardown()
	_server = null
	_gunner = null
	_pilot = null
	_in_flight = []
	_tick = 0


func _finish() -> void:
	_end()
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
