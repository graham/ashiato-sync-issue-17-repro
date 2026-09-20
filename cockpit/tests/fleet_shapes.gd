extends Node
## Headless: THE US NAVY FLEET'S E-2D HAWKEYE AND VIRGINIA-CLASS SUBMARINE, held to their fact sheets and to what their C++
## added: the Hawkeye's stated inertia and its wing fold.
##
##   Godot --headless --path cockpit res://tests/fleet_shapes.tscn
##
## Asked for on 2026-09-15: both craft "true to the real thing including its size". The sheets are research-hawkeye.md and
## research-submarine.md in godotgames-drafts/2026-09-15/cockpit-fleet; the figures typed here are theirs, the independent
## statement the shape table is checked against, as tests/boat_seats.gd types its draughts.
##
## WHAT IT HOLDS:
##   - both are their real size (the Hawkeye's length, span, mass and crew; the submarine's length, beam, the watch's eye
##     over the sea and the depth Terrain puts it in);
##   - THE HAWKEYE'S BODY HAS THE INERTIA ITS SHAPE STATES, asked of Box3D (`body_mass`), with the mass and centre the box
##     gave it, after a spawn, a flight, a rollback on a client and a respawn. Its fuselage box rolled with 17,700 kg m^2 and
##     settled in 0.02 s; the stated figures are an estimate from component masses, since none is published;
##   - every other kind that is one box keeps the box's own moments, m/3 (b^2 + c^2) on the half-extents;
##   - a full stick answers as that inertia says: settled at rate * (K/I) / (K/I + c) and in a time constant 1 / (K/I + c),
##     with K the authority and c the damping, all asked;
##   - a Hawkeye put down on something is spawned folded and one put into the air spread (nobody is aboard to fold it);
##   - the wings fold only with weight on the wheels, folding sets nothing else, and a Hawkeye taken from the pilot's seat
##     is launched with them spread;
##   - A HAWKEYE PARKED OFF THE CENTRE LINE OF A TURNING CARRIER STAYS ON ITS SPOT: the deck under a wheel moves at its own
##     point's velocity, the ship's middle's and its turn across the arm;
##   - THE AIRFRAME IS DRAWN AS THE SHEET SAYS, from its drawn vertices: folded, the wings are no wider than Jane's 8.94 m and
##     hang under the rotodome; spread, the wingtip lights stand on the drawn tips, not the plank's.
##   - the gunship's procedural exterior is a 39.7 m-span AC-130 silhouette with four six-blade engines, a sensor ball and
##     three port weapon apertures, while every native seat anchor remains exactly where CockpitWorld published it.
##
## Read RESULT=, not the exit code.

const TICK_HZ: float = 60.0
const DT: float = 1.0 / TICK_HZ
const CLIENT: int = 40

## From the sheets.
const HAWKEYE_LENGTH: float = 17.60
const HAWKEYE_SPAN: float = 24.56
const HAWKEYE_HEIGHT: float = 5.58
const HAWKEYE_EMPTY: float = 18363.0
const HAWKEYE_FULL: float = 26082.0
const SUBMARINE_LENGTH: float = 114.9
const SUBMARINE_BEAM: float = 10.36
## The officer of the deck's eye over the sea, DERIVED on the sheet from the sail's measured height.
const SUBMARINE_EYE: float = 8.21
## Its draught (29 ft) and the keel room every resting ship is given (`Terrain.SHIP_KEEL_ROOM`).
const SUBMARINE_DEPTH: float = 8.84 + 8.0

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[fleet_shapes] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var probe: Object = _world(0) if ClassDB.class_exists("CockpitWorld") else null
	var has: bool = probe != null and probe.has_method("body_mass") and int(probe.kind_count()) == Sim.Kind.size()
	_check("the_extension_has_both_craft_and_reads_a_body_back", has, "body_mass, %d kinds" % [
		probe.kind_count() if probe != null else 0])
	if probe != null:
		_let_go(probe)
	if not has:
		_finish()
		return
	_the_hawkeye_is_its_real_size()
	_the_submarine_is_its_real_size()
	_the_hawkeye_body_has_its_stated_inertia_and_every_other_box_its_own()
	_the_stated_inertia_survives_flight_a_rollback_and_a_respawn()
	_a_full_stick_answers_as_the_inertia_says()
	_the_wings_fold_only_on_the_wheels()
	_a_craft_parked_off_the_centre_line_of_a_turning_carrier_stays_on_its_spot()
	_the_folded_wings_hang_under_the_rotodome_and_the_lights_stand_on_the_tips()
	_the_drawn_hawkeye_fits_its_public_envelope_and_culls_only_small_fittings()
	_the_gunship_draws_an_ac130_airframe_around_unchanged_seat_anchors()
	_finish()


## ---- sizes ------------------------------------------------------------------------------------------------------------

func _the_hawkeye_is_its_real_size() -> void:
	var g: Dictionary = Sim.geometry_of(Sim.Kind.HAWKEYE)
	var extents: Vector3 = g.get("extents", Vector3.ZERO)
	var poses: Array = g.get("seat_poses", [])
	var wrong: Array[String] = []
	if absf(extents.z * 2.0 - HAWKEYE_LENGTH) > 0.01:
		wrong.append("%.2f m long" % (extents.z * 2.0))
	if absf(float(g.get("span", 0.0)) * 2.0 - HAWKEYE_SPAN) > 0.01:
		wrong.append("%.2f m in span" % (float(g.get("span", 0.0)) * 2.0))
	if float(g.get("mass", 0.0)) < HAWKEYE_EMPTY or float(g.get("mass", 0.0)) > HAWKEYE_FULL:
		wrong.append("%.0f kg" % float(g.get("mass", 0.0)))
	if poses.size() != 4:
		wrong.append("%d seats" % poses.size())
	else:
		var a: Vector3 = poses[0]["position"]
		var b: Vector3 = poses[1]["position"]
		# SIDE BY SIDE: the same station along and mirrored across. THE MISSION CREW TURNED TO PORT: a yaw of +90 degrees
		# turns -Z, the nose, to -X, which is port.
		if String(poses[0]["station"]) != "pilot" or String(poses[1]["station"]) != "copilot" \
				or absf(a.z - b.z) > 0.01 or absf(a.x + b.x) > 0.01:
			wrong.append("pilots at %s and %s" % [a, b])
		for seat in [2, 3]:
			if String(poses[seat]["station"]) != "turret" or absf(angle_difference(float(poses[seat]["yaw"]), PI * 0.5)) > 0.01:
				wrong.append("seat %d is a %s facing %.2f" % [seat, poses[seat]["station"], float(poses[seat]["yaw"])])
	_check("the_hawkeye_is_its_real_size_with_its_pilots_side_by_side_and_its_operators_facing_port", wrong.is_empty(),
		"%.2f m long, %.2f m span, %.0f kg, %d seats%s" % [extents.z * 2.0, float(g.get("span", 0.0)) * 2.0,
			float(g.get("mass", 0.0)), poses.size(), "" if wrong.is_empty() else ": %s" % [wrong]])


func _the_submarine_is_its_real_size() -> void:
	var g: Dictionary = Sim.geometry_of(Sim.Kind.SUBMARINE)
	var extents: Vector3 = g.get("extents", Vector3.ZERO)
	var poses: Array = g.get("seat_poses", [])
	var eye: float = -INF
	if not poses.is_empty():
		eye = (poses[0]["position"] as Vector3).y + CockpitStation.EYE_HEIGHT - float(g.get("waterline", 0.0))
	var depth: float = Terrain.ship_depth(Sim.Kind.SUBMARINE)
	_check("the_submarine_is_its_real_size_and_its_watch_stands_where_the_sheet_says",
		absf(extents.z * 2.0 - SUBMARINE_LENGTH) < 0.05 and absf(extents.x * 2.0 - SUBMARINE_BEAM) < 0.05
			and absf(eye - SUBMARINE_EYE) < 0.02 and absf(depth - SUBMARINE_DEPTH) < 0.02,
		"%.2f m long against %.1f, %.2f m in the beam against %.2f, the eye %.2f m over the sea against %.2f, placed in %.2f m of water against %.2f" % [
			extents.z * 2.0, SUBMARINE_LENGTH, extents.x * 2.0, SUBMARINE_BEAM, eye, SUBMARINE_EYE, depth, SUBMARINE_DEPTH])


## ---- the stated inertia -----------------------------------------------------------------------------------------------

## What is wrong with a body's mass against its shape's: the shape's mass, the middle of its box, and on each axis the
## stated moment or, where none is stated, the box's own. Empty when it is right. `inertia` is (pitch, yaw, roll).
func _mass_wrong(world: Object, entity: int, kind: int) -> String:
	var g: Dictionary = Sim.geometry_of(kind)
	var got: Dictionary = world.body_mass(entity)
	if got.is_empty():
		return "no body"
	var mass: float = float(g["mass"])
	# b AND c ARE THE HALF-EXTENTS of the other two axes (`extents` is hx, hy, hz); the full-size form is m/12 (B^2 + C^2).
	var e: Vector3 = g["extents"]
	var box := Vector3(mass / 3.0 * (e.y * e.y + e.z * e.z), mass / 3.0 * (e.x * e.x + e.z * e.z),
		mass / 3.0 * (e.x * e.x + e.y * e.y))
	var stated: Vector3 = g.get("inertia", Vector3.ZERO)
	var want := Vector3(stated.x if stated.x > 0.0 else box.x, stated.y if stated.y > 0.0 else box.y,
		stated.z if stated.z > 0.0 else box.z)
	var inertia: Vector3 = got["inertia"]
	var out: Array[String] = []
	if absf(float(got["mass"]) - mass) > mass * 1e-5:
		out.append("mass %.1f against %.1f" % [float(got["mass"]), mass])
	if (got["centre"] as Vector3).length() > 0.001:
		out.append("centre %s" % [got["centre"]])
	for axis in 3:
		if absf(inertia[axis] - want[axis]) > want[axis] * 1e-4:
			out.append("%s %.0f against %.0f" % [["pitch", "yaw", "roll"][axis], inertia[axis], want[axis]])
	return ", ".join(out)


func _the_hawkeye_body_has_its_stated_inertia_and_every_other_box_its_own() -> void:
	var world: Object = _world(0)
	var hawkeye: int = int(world.spawn_vehicle(Sim.Kind.HAWKEYE, Vector3(0.0, 1500.0, 0.0), 0.0, Vector3(0.0, 0.0, -120.0)))
	var wrong: String = _mass_wrong(world, hawkeye, Sim.Kind.HAWKEYE)
	var got: Dictionary = world.body_mass(hawkeye)
	_check("the_hawkeye_body_has_the_inertia_its_shape_states_and_the_mass_and_centre_its_box_gave_it", wrong == "",
		"%s, mass %.0f kg, centre %s" % [wrong if wrong != "" else "pitch, yaw, roll %s" % [got.get("inertia")],
			float(got.get("mass", 0.0)), got.get("centre")])
	var others: Array[String] = []
	var boxes: int = 0
	for kind in range(Sim.Kind.size()):
		var g: Dictionary = Sim.geometry_of(kind)
		# These long/high-performance aircraft declare measured representative moments;
		# their own suites hold those values and their flight response.
		if kind in [Sim.Kind.HAWKEYE, Sim.Kind.JUMBO, Sim.Kind.FIGHTER] or not (g.get("parts", []) as Array).is_empty():
			continue
		var stated: Vector3 = g.get("inertia", Vector3.ZERO)
		var entity: int = int(world.spawn_vehicle(kind, Vector3(3000.0 * float(kind + 1), 1500.0, 9000.0), 0.0, Vector3.ZERO))
		# A KIND ON ITS SURFACES IS WEIGHED AS AN AEROPLANE, not as its box (lane/cessnafm, 2026-09-19): its mass centre is
		# moved to the centre of gravity and its inertia is the component-mass one the wing reports, so its body is held
		# to `lifting_surfaces(kind)`, the one place that says it. The box moments it used to have are what made a
		# surface aeroplane's damping answer inside a tick (`tests/surfaces.gd`'s stiffness guard).
		var wing: Dictionary = world.lifting_surfaces(kind)
		if bool(wing.get("switched_on", false)):
			var body: Vector3 = world.body_mass(entity).get("inertia", Vector3.ZERO)
			var own: Vector3 = wing.get("inertia", Vector3.ZERO)
			if own == Vector3.ZERO or not body.is_equal_approx(own):
				others.append("%s: on its surfaces, body inertia %s against the wing's %s" % [Sim.kind_name(kind), body, own])
			boxes += 1
			continue
		var off: String = _mass_wrong(world, entity, kind)
		# Hawkeye was once the only one-box craft with stated moments. Mercury now has them too; `_mass_wrong` already
		# selects each stated axis over the box fallback, so a non-zero declaration is expected rather than an error.
		if off != "":
			others.append("%s: %s, stated %s" % [Sim.kind_name(kind), off, stated])
		boxes += 1
	_check("and_every_other_one_box_kind_keeps_its_declared_or_box_moments", boxes > 0 and others.is_empty(),
		"%d kinds%s" % [boxes, "" if others.is_empty() else ": %s" % [others]])
	_let_go(world)


## A PAIR: a rollback resimulates the SAME body and a respawn builds a new one, and Box3D puts a box's inertia back in any of
## the six places it recomputes a mass. The client flies its Hawkeye through rolls until it has rolled back, and its body is
## read then; the server's own Hawkeye after 600 ticks; and a new one after the first is despawned.
func _the_stated_inertia_survives_flight_a_rollback_and_a_respawn() -> void:
	var server: Object = _world(0)
	var client: Object = _world(1)
	for i in range(90):
		_step_pair(server, client)
	var mine: int = int(client.local_client_id())
	server.spawn_pilot(mine, Sim.Kind.HAWKEYE, Vector3(0.0, 1500.0, 0.0), -PI * 0.5, Vector3(120.0, 0.0, 0.0))
	var own: int = -1
	var craft: int = -1
	var rolled_from: int = -1
	for i in range(900):
		if own < 0 and (client.vehicle_states() as Array).size() == 1:
			own = int(client.vehicle_states()[0]["entity"])
		if craft < 0 and (server.vehicle_states() as Array).size() == 1:
			craft = int(server.vehicle_states()[0]["entity"])
		client.set_input(_controls({"throttle": 0.8, "roll": sin(float(i) * 0.05), "pitch": 0.2 * cos(float(i) * 0.03)}))
		_step_pair(server, client)
		if i == 120:
			rolled_from = int(client.resim_stats().get("count", 0))
	var rolled: int = int(client.resim_stats().get("count", 0)) - maxi(rolled_from, 0)
	var after_flight: String = _mass_wrong(server, craft, Sim.Kind.HAWKEYE)
	var after_rollback: String = _mass_wrong(client, own, Sim.Kind.HAWKEYE)
	server.despawn_vehicle(craft)
	server.tick(DT)
	var again: int = int(server.spawn_vehicle(Sim.Kind.HAWKEYE, Vector3(0.0, 1500.0, 4000.0), 0.0, Vector3(0.0, 0.0, -120.0)))
	var after_respawn: String = _mass_wrong(server, again, Sim.Kind.HAWKEYE)
	_check("and_it_is_still_that_inertia_after_a_flight_a_rollback_and_a_respawn",
		rolled > 0 and after_flight == "" and after_rollback == "" and after_respawn == "",
		"%d rollbacks on the client; after 900 ticks of flight: %s; on the client after them: %s; respawned: %s" % [
			rolled, _said(after_flight), _said(after_rollback), _said(after_respawn)])
	_let_go(server)
	_let_go(client)


## ---- the stick ------------------------------------------------------------------------------------------------------

## FULL STICK OR PEDAL on one axis from level flight at 120 m/s, on a server world, read about the craft's own axes: the
## rate it settles at over the last quarter second of 1.5 s, and the time to 63 % of it. Returns {settled, t63, at_0_4}.
func _step(kind: int, axis: String) -> Dictionary:
	var world: Object = _world(0)
	var made: Dictionary = world.spawn_pilot(CLIENT, kind, Vector3(0.0, 2000.0, 0.0), 0.0, Vector3(0.0, 0.0, -120.0))
	var craft: int = int(made.get("vehicle", 0))
	var pilot: int = int(made.get("pilot", 0))
	var still: Dictionary = {"throttle": 0.7}
	for i in range(int(TICK_HZ)):
		world.set_pilot_input(pilot, _controls(still))
		world.tick(DT)
	var rates: Array[float] = []
	var held: Dictionary = {"throttle": 0.7}
	held[axis] = 1.0
	for i in range(int(1.5 * TICK_HZ)):
		world.set_pilot_input(pilot, _controls(held))
		world.tick(DT)
		var state: Dictionary = world.vehicle_state(craft)
		var basis := Basis(state["basis"] as Quaternion)
		var spin: Vector3 = state["spin"]
		var about: Vector3 = {"pitch": basis.x, "roll": -basis.z, "rudder": basis.y}[axis]
		rates.append(absf(spin.dot(about)))
	_let_go(world)
	var tail: int = int(0.25 * TICK_HZ)
	var settled: float = 0.0
	for i in range(rates.size() - tail, rates.size()):
		settled += rates[i] / float(tail)
	var t63: float = -1.0
	for i in range(rates.size()):
		if rates[i] >= settled * 0.63:
			t63 = float(i + 1) * DT
			break
	return {"settled": settled, "t63": t63, "at_0_4": rates[int(0.4 * TICK_HZ) - 1]}


## THE ARITHMETIC, asked of the simulation: the settled rate and the time constant a rate loop of authority K against an
## inertia I and Box3D's damping c gives (cockpit-chinook: within 3 % of every rotorcraft it measured).
func _predicted(asked: float, authority: float, inertia: float, damping: float) -> Dictionary:
	var k: float = authority / inertia
	return {"settled": asked * k / (k + damping), "t63": 1.0 / (k + damping)}


func _a_full_stick_answers_as_the_inertia_says() -> void:
	var probe: Object = _world(0)
	var h: Dictionary = probe.handling(Sim.Kind.HAWKEYE)
	var body: int = int(probe.spawn_vehicle(Sim.Kind.HAWKEYE, Vector3(0.0, 1500.0, 0.0), 0.0, Vector3.ZERO))
	var inertia: Vector3 = (probe.body_mass(body) as Dictionary).get("inertia", Vector3.ONE)
	_let_go(probe)
	var said: Array[String] = []
	var roll_ok: bool = false
	for row in [["pitch", "pitch_rate", inertia.x], ["roll", "roll_rate", inertia.z], ["rudder", "yaw_rate", inertia.y]]:
		var got: Dictionary = _step(Sim.Kind.HAWKEYE, row[0])
		var want: Dictionary = _predicted(float(h[row[1]]), float(h["control_authority"]), float(row[2]),
			float(h["angular_damping"]))
		print("[fleet_shapes] hawkeye %-6s settles at %.3f rad/s (arithmetic %.3f), 63 %% in %.2f s (arithmetic %.2f), %.3f rad/s at 0.4 s" % [
			row[0], got["settled"], want["settled"], got["t63"], want["t63"], got["at_0_4"]])
		said.append("%s %.3f rad/s in %.2f s" % [row[0], got["settled"], got["t63"]])
		if row[0] == "roll":
			roll_ok = absf(float(got["settled"]) - float(want["settled"])) <= float(want["settled"]) * 0.15 \
				and absf(float(got["t63"]) - float(want["t63"])) <= float(want["t63"]) * 0.3
	var airliner: Dictionary = _step(Sim.Kind.AIRLINER, "pitch")
	print("[fleet_shapes] airliner pitch settles at %.3f rad/s, 63 %% in %.2f s, %.3f rad/s at 0.4 s" % [
		airliner["settled"], airliner["t63"], airliner["at_0_4"]])
	# ROLL IS HELD TO THE ARITHMETIC, because roll is where the box was wrongest (17,700 against 190,000) and the fewest
	# aerodynamic torques act on it; pitch and yaw carry the stability and weathervane terms and are printed.
	_check("a_full_stick_rolls_the_hawkeye_as_its_stated_inertia_says", roll_ok,
		"%s; the airliner's pitch %.3f rad/s at 0.4 s" % [", ".join(said), airliner["at_0_4"]])


## ---- the fold -------------------------------------------------------------------------------------------------------

## ON THE GROUND, FROM THE CO-PILOT'S SEAT, which flies and does not launch the aircraft as the pilot's does; then from the
## pilot's seat, which launches a parked aeroplane (`launch_if_grounded`); then in the air.
func _the_wings_fold_only_on_the_wheels() -> void:
	var world: Object = _world(0)
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(3000.0, 400.0, 3000.0))
	var e: Vector3 = Sim.geometry_of(Sim.Kind.HAWKEYE)["extents"]
	var hawkeye: int = int(world.spawn_vehicle(Sim.Kind.HAWKEYE, Vector3(0.0, e.y + 0.3, 0.0), 0.0, Vector3.ZERO))
	var made: Dictionary = world.spawn_pilot(CLIENT, Sim.Kind.POD, Vector3(1500.0, 300.0, 0.0), 0.0, Vector3.ZERO)
	var pilot: int = int(made.get("pilot", 0))
	for i in range(120):
		world.tick(DT)
	# PUT DOWN, IT IS SPAWNED FOLDED; PUT INTO THE AIR, SPREAD: a level's parked Hawkeye has nobody aboard to fold it.
	var flying: int = int(world.spawn_vehicle(Sim.Kind.HAWKEYE, Vector3(2000.0, 1500.0, 0.0), 0.0, Vector3(0.0, 0.0, -120.0)))
	var at_spawn: Dictionary = world.craft_controls(hawkeye)
	var in_the_air: Dictionary = world.craft_controls(flying)
	_check("the_hawkeye_is_spawned_folded_when_put_down_and_spread_when_put_into_the_air",
		bool(at_spawn.get("gear", false)) and bool(at_spawn.get("fold", false)) and not bool(in_the_air.get("fold", true)),
		"put down: gear %s, fold %s; put into the air: fold %s" % [at_spawn.get("gear"), at_spawn.get("fold"),
			in_the_air.get("fold")])
	# THE SWITCH ITSELF, from the co-pilot's seat: spread the spawned fold, then fold it again, so the command is what is
	# proven and not the spawn.
	var seated: bool = bool(world.seat_client(CLIENT, hawkeye, 1))
	world.set_pilot_input(pilot, _controls({"command_channel": Sim.Channel.FOLD, "command_value": 0, "command_seq": 1}))
	for i in range(30):
		world.tick(DT)
	var spread: Dictionary = world.craft_controls(hawkeye)
	world.set_pilot_input(pilot, _controls({"command_channel": Sim.Channel.FOLD, "command_value": 1, "command_seq": 2}))
	for i in range(30):
		world.tick(DT)
	var parked: Dictionary = world.craft_controls(hawkeye)
	_check("the_hawkeye_folds_its_wings_on_its_wheels_and_nothing_else_moves",
		seated and not bool(spread.get("fold", true)) and bool(parked.get("gear", false)) and bool(parked.get("fold", false))
			and not bool(parked.get("spoilers", false)),
		"seated as co-pilot %s: spread %s, then gear %s, fold %s, spoilers %s" % [seated, not bool(spread.get("fold", true)),
			parked.get("gear"), parked.get("fold"), parked.get("spoilers")])
	# THE BUILDER'S SEAT IS REAL BUT IS NOT A LAUNCH BUTTON. This is deliberately a
	# different API from ordinary seating; weakening `seat_client` would make every craft
	# selector stop launching parked aircraft.
	var builder_hawkeye := int(world.spawn_vehicle(Sim.Kind.HAWKEYE,
		Vector3(800.0, e.y + 0.3, 0.0), 0.0, Vector3.ZERO))
	var builder_pilot: Dictionary = world.spawn_pilot(CLIENT + 1, Sim.Kind.POD,
		Vector3(1800.0, 300.0, 0.0), 0.0, Vector3.ZERO)
	var authored := bool(world.seat_client_parked(CLIENT + 1, builder_hawkeye, 0))
	for i in range(30):
		world.tick(DT)
	var builder_state: Dictionary = world.vehicle_state(builder_hawkeye)
	var builder_controls: Dictionary = world.craft_controls(builder_hawkeye)
	_check("the_builder_seats_a_pilot_without_launching_the_parked_craft",
		authored and not builder_state.is_empty() and (builder_state["position"] as Vector3).y < 10.0
			and bool(builder_controls.get("fold", false)),
		"seated %s, y %.2f, folded %s, pilot %s" % [authored,
			(builder_state.get("position", Vector3.ZERO) as Vector3).y,
			builder_controls.get("fold"), builder_pilot])
	var client_world: Object = _world(CLIENT)
	_check("a_client_cannot_seat_anybody_through_the_builder_api",
		not bool(client_world.seat_client_parked(CLIENT, builder_hawkeye, 0)),
		"client world refused server authority")
	_let_go(client_world)
	var launched: bool = bool(world.seat_client(CLIENT, hawkeye, 0))
	for i in range(30):
		world.tick(DT)
	var taken: Dictionary = world.craft_controls(hawkeye)
	var up: float = float((world.vehicle_state(hawkeye)["position"] as Vector3).y)
	world.set_pilot_input(pilot, _controls({"command_channel": Sim.Channel.FOLD, "command_value": 1, "command_seq": 3}))
	for i in range(30):
		world.tick(DT)
	var aloft: Dictionary = world.craft_controls(hawkeye)
	_check("and_is_launched_spread_from_the_pilots_seat_and_will_not_fold_in_the_air",
		launched and up > 20.0 and not bool(taken.get("fold", true)) and not bool(aloft.get("fold", true)),
		"taken from the pilot's seat %s, at %.0f m: fold %s; asked to fold in the air: fold %s" % [launched, up,
			taken.get("fold"), aloft.get("fold")])
	_let_go(world)


## ---- the airframe -------------------------------------------------------------------------------------------------

## THE DRAWN WING, MEASURED FROM ITS VERTICES in the airframe's frame, never a rotated box round a box, which read the folded
## aircraft as 9.67 m across against 8.81 m (cockpit-fleet's draft). Hinged at the quarter chord the folded panels stood as
## walls to 5.9 m, through the rotodome, with every other number right; only a picture showed it, so the tops are held here.
## And the lights: `VehicleLights.published_wingtips` is where the nav lights and the contrails stand, and on a plank's numbers they
## were 0.64 m low and forward of the drawn tips.
func _the_folded_wings_hang_under_the_rotodome_and_the_lights_stand_on_the_tips() -> void:
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.HAWKEYE)
	var frame := HawkeyeAirframe.new()
	frame.dress(geometry)
	add_child(frame)
	frame.fold(1.0)
	var folded: Dictionary = _panel_reach(frame)
	var underside: float = HawkeyeAirframe.rotodome_top(geometry) - HawkeyeAirframe.ROTODOME_THICK
	_check("the_hawkeyes_folded_wings_are_no_wider_than_its_sheet_and_hang_under_the_rotodome",
		float(folded["across"]) <= HawkeyeAirframe.FOLDED_WIDTH and float(folded["top"]) < underside,
		"%.2f m across against %.2f, the panels' tops at %.2f m against the rotodome's underside at %.2f m" % [
			folded["across"], HawkeyeAirframe.FOLDED_WIDTH, folded["top"], underside])
	frame.fold(0.0)
	var spread: Dictionary = _panel_reach(frame)
	var lights: Array[Vector3] = VehicleLights.published_wingtips(Sim.Kind.HAWKEYE, geometry)
	var off: float = INF
	if lights.size() == 2:
		off = maxf((lights[0] - (spread["port_tip"] as Vector3)).length(), (lights[1] - (spread["starboard_tip"] as Vector3)).length())
	_check("and_its_wingtip_lights_stand_on_the_drawn_tips", off < 0.15,
		"the lights %s, the drawn tips' middles %s and %s, %.2f m apart at the worst" % [lights, spread["port_tip"],
			spread["starboard_tip"], off])
	frame.queue_free()


## Where the two wing panels reach, from their vertices in the airframe's frame: {across (full width), top, port_tip,
## starboard_tip}, a tip being the middle of the box round the wing skin's outermost vertices on that side (not the boot's).
func _panel_reach(frame: HawkeyeAirframe) -> Dictionary:
	var across: float = 0.0
	var top: float = -INF
	var tips: Dictionary = {}
	for pivot in frame.get_children():
		var mesh := (pivot as Node).get_node_or_null("Panel") as MeshInstance3D
		if mesh == null:
			continue
		var side: String = "starboard_tip" if (pivot as Node3D).position.x > 0.0 else "port_tip"
		var xform: Transform3D = (pivot as Node3D).transform * mesh.transform
		var arrays: Array = (mesh.mesh as ArrayMesh).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var skin: Array[Vector3] = []
		var outermost: float = 0.0
		for i in vertices.size():
			var p: Vector3 = xform * vertices[i]
			across = maxf(across, absf(p.x) * 2.0)
			top = maxf(top, p.y)
			# THE WING'S OWN SKIN, not the black de-icing boot along its leading edge: a mean over both put the tip's middle
			# 0.27 m toward the leading edge of the drawn chord's middle, and this check's first run failed on that alone.
			if colours.is_empty() or colours[i].r > 0.3:
				skin.append(p)
				outermost = maxf(outermost, absf(p.x))
		# The middle of the BOX round the tip, not a mean: a mean counts however many vertices the weld left at each corner.
		var tip := AABB()
		var first: bool = true
		for p in skin:
			if absf(p.x) > outermost - 0.05:
				tip = AABB(p, Vector3.ZERO) if first else tip.expand(p)
				first = false
		tips[side] = tip.get_center()
	return {"across": across, "top": top, "port_tip": tips.get("port_tip", Vector3.ZERO),
		"starboard_tip": tips.get("starboard_tip", Vector3.ZERO)}


## THE PUBLIC FIGURES ARE OVERALL dimensions, so the actual vertices must fit them, not only the simulation's collision
## box. This caught a refuelling probe 1.5 m beyond the sourced nose and a model 0.70 m short because it had no landing
## gear. Small fittings have one deliberate Mobile-safe visibility range; losing a wing, tail or dome at range would fail.
func _the_drawn_hawkeye_fits_its_public_envelope_and_culls_only_small_fittings() -> void:
	var frame := HawkeyeAirframe.new()
	frame.dress(Sim.geometry_of(Sim.Kind.HAWKEYE))
	add_child(frame)
	frame.fold(0.0)
	var box: AABB = _drawn_box(frame)
	var wanted := Vector3(HAWKEYE_SPAN, HAWKEYE_HEIGHT, HAWKEYE_LENGTH)
	var error := Vector3(absf(box.size.x - wanted.x) / wanted.x, absf(box.size.y - wanted.y) / wanted.y,
		absf(box.size.z - wanted.z) / wanted.z)
	_check("the_drawn_hawkeye_fits_its_published_span_height_and_overall_length",
		error.x <= 0.02 and error.y <= 0.02 and error.z <= 0.02,
		"drawn %.2f wide x %.2f high x %.2f long; public %.2f x %.2f x %.2f; relative error %s" % [box.size.x,
			box.size.y, box.size.z, wanted.x, wanted.y, wanted.z, error])
	var details := frame.get_node_or_null("Details") as MeshInstance3D
	var silhouette: Array[MeshInstance3D] = []
	for path in ["Body", "Rotodome", "WingPort/Panel", "WingStarboard/Panel"]:
		var mesh := frame.get_node_or_null(path) as MeshInstance3D
		if mesh != null:
			silhouette.append(mesh)
	var silhouette_unculled: bool = silhouette.size() == 4
	var silhouette_triangles: int = 0
	for mesh in silhouette:
		silhouette_unculled = silhouette_unculled and mesh.visibility_range_end == 0.0
		silhouette_triangles += _triangle_count(mesh)
	var detail_triangles: int = _triangle_count(details)
	_check("and_only_probe_propellers_intakes_and_gear_leave_at_the_manual_lod_range",
		details != null and is_equal_approx(details.visibility_range_end, HawkeyeAirframe.DETAIL_RANGE)
			and details.visibility_range_end_margin > 0.0
			and details.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			and details.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and silhouette_unculled
			and detail_triangles >= 100 and silhouette_triangles > detail_triangles,
		"one details draw with %d triangles ends at %.0f +/- %.0f, fade %d, shadows %d; %d triangles in 4 silhouette meshes remain" % [
			detail_triangles,
			details.visibility_range_end if details != null else -1.0,
			details.visibility_range_end_margin if details != null else -1.0,
			details.visibility_range_fade_mode if details != null else -1,
			details.cast_shadow if details != null else -1, silhouette_triangles])
	frame.queue_free()


## The box around every spread-state mesh, in `root`'s frame. In that state these mesh nodes have only translations and
## identity bases, so their AABB endpoints are their vertex extrema (a folded panel would need the vertex walk above).
func _drawn_box(root: Node3D) -> AABB:
	var points: Array[Vector3] = []
	_collect_mesh_boxes(root, Transform3D.IDENTITY, points)
	var box := AABB(points[0], Vector3.ZERO)
	for point in points:
		box = box.expand(point)
	return box


func _collect_mesh_boxes(parent: Node3D, from_root: Transform3D, points: Array[Vector3]) -> void:
	for child_node in parent.get_children():
		var child := child_node as Node3D
		if child == null:
			continue
		var xform: Transform3D = from_root * child.transform
		var instance := child as MeshInstance3D
		if instance != null and instance.mesh != null:
			var local: AABB = instance.get_aabb()
			for corner in range(8):
				points.append(xform * local.get_endpoint(corner))
		_collect_mesh_boxes(child, xform, points)


func _triangle_count(instance: MeshInstance3D) -> int:
	if instance == null or instance.mesh == null:
		return 0
	var triangles: int = 0
	for surface in instance.mesh.get_surface_count():
		var arrays: Array = instance.mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
	return triangles


## THE AC-130 SILHOUETTE IS A CONTRACT, not a screenshot opinion. This asks the actual
## VehicleView for its named fittings and measures all of its mesh vertices in craft space.
## It also compares the seat nodes with CockpitWorld's poses, because a more detailed shell
## is useful only if improving it cannot quietly move a player or change their forward view.
##
## SINCE 2026-09-19 (lane/liners) THE GUNSHIP IS `HerculesAirframe`, an AC-130U on a C-130H measured off Lockheed Martin's
## General Arrangement: four T56 nacelles with FOUR-bladed propellers (the H's; the six-bladed ones this asked for were
## the J's), the three guns out of the port side, and the sensor turret. `tests/hercules.gd` holds the rest.
func _the_gunship_draws_an_ac130_airframe_around_unchanged_seat_anchors() -> void:
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.GUNSHIP)
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.setup(0, Sim.Kind.GUNSHIP)
	var frame := view.find_child("Hercules", true, false) as HerculesAirframe
	var bounds: AABB = _mesh_bounds_in(view)
	var engines: Array[Node] = view.find_children("Engine?", "MeshInstance3D", true, false)
	var propellers: Array[Node] = view.find_children("Propeller?", "MeshInstance3D", true, false)
	var guns: Array[Node] = view.find_children("Gun*", "MeshInstance3D", true, false).filter(
		func(n: Node) -> bool: return not String(n.name).ends_with("Port"))
	var seats_right: bool = view.seats.size() == (geometry.get("seat_poses", []) as Array).size()
	for i in range(view.seats.size()):
		var poses: Array = geometry.get("seat_poses", []) as Array
		if i >= poses.size() or view.seats[i].position.distance_to((poses[i] as Dictionary).get("position", Vector3.ZERO)) > 0.001:
			seats_right = false
	var span: float = bounds.size.x
	var length: float = bounds.size.z
	var fittings_right: bool = frame != null and frame.armed and engines.size() == 4 and propellers.size() == 4 \
		and guns.size() == 3 and view.find_children("SensorTurret", "MeshInstance3D", true, false).size() == 1
	_check("the_gunship_draws_a_hercules_sized_four_engine_airframe_with_its_sensor_and_port_battery",
		span >= 39.0 and span <= 42.0 and length >= 29.0 and length <= 34.0 and fittings_right,
		"%.2f m span, %.2f m long, airframe %s, %d engines, %d propellers, %d guns, sensor %s" % [
			span, length, frame != null, engines.size(), propellers.size(), guns.size(),
			view.find_children("SensorTurret", "MeshInstance3D", true, false).size()])
	_check("and_the_detailed_gunship_shell_does_not_move_any_native_seat_anchor", seats_right,
		"%d drawn anchors against %d native poses" % [view.seats.size(), (geometry.get("seat_poses", []) as Array).size()])
	view.queue_free()


## The box around every MeshInstance3D below `root`, transformed back into root space.
## Hidden presentation meshes are excluded: the gunship's native collision box is kept as
## the Hull node but deliberately hidden behind its round exterior.
func _mesh_bounds_in(root: Node3D) -> AABB:
	var bounds := AABB()
	var first: bool = true
	var inverse: Transform3D = root.global_transform.affine_inverse()
	for found in root.find_children("*", "MeshInstance3D", true, false):
		var instance := found as MeshInstance3D
		if instance.mesh == null or not instance.is_visible_in_tree():
			continue
		var box: AABB = instance.mesh.get_aabb()
		var xform: Transform3D = inverse * instance.global_transform
		for corner in range(8):
			var point: Vector3 = xform * box.get_endpoint(corner)
			bounds = AABB(point, Vector3.ZERO) if first else bounds.expand(point)
			first = false
	return bounds


## ---- plumbing -------------------------------------------------------------------------------------------------------

## ---- the deck under way ----------------------------------------------------------------------------------------------

## How long the carrier is watched turning with the Hawkeye on its deck, seconds, how far round it must have come for the
## watch to be a turn, degrees, and how far across the deck the Hawkeye may move in the ship's frame, metres: a fifth of
## terrain_level's REST_SLID, since here nothing but the turn moves it.
const DECK_TURN_SECONDS: float = 40.0
const DECK_TURNED_AT_LEAST: float = 20.0
const DECK_SLID_AT_MOST: float = 1.0


## A CRAFT PARKED OFF THE CENTRE LINE OF A TURNING CARRIER STAYS ON ITS SPOT. The carrier sails itself round to a waypoint
## astern (with no bedrock the sea has no floor, so its leg is deep); a Hawkeye is stood on its deck at CarrierPlan.PARKED
## by `Terrain.parked_on`, 92 m from the middle, and its spot in the ship's frame is read once it has settled and again after
## the turn. The deck under a wheel moved at the ship's middle's velocity until cockpit-fleet step 4, and on the turning Ford
## that slid a parked Hawkeye 6.64 m across the deck.
func _a_craft_parked_off_the_centre_line_of_a_turning_carrier_stays_on_its_spot() -> void:
	var world: Object = _world(0)
	world.add_ai_waypoint(Sim.Kind.CARRIER, Vector3(0.0, Terrain.SEA_LEVEL, 4000.0))
	var carrier: int = int(world.spawn_ai_vehicle(Sim.Kind.CARRIER, Vector3(0.0, Terrain.SEA_LEVEL + 4.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -12.0)))
	for i in range(int(TICK_HZ * 5.0)):
		world.tick(DT)
	var ship: Dictionary = world.vehicle_state(carrier)
	var parked: Dictionary = Terrain.parked_on({"name": &"deck", "yaw": _heading(ship), "position": ship["position"],
		"velocity": ship["velocity"]}, Sim.Kind.HAWKEYE)
	var hawkeye: int = int(world.spawn_vehicle(Sim.Kind.HAWKEYE, parked["position"], float(parked["yaw"]), parked["velocity"]))
	for i in range(int(TICK_HZ * 3.0)):
		world.tick(DT)
	var before: Vector3 = _in_the_ship(world, carrier, hawkeye)
	var heading_before: float = _heading(world.vehicle_state(carrier))
	for i in range(int(TICK_HZ * DECK_TURN_SECONDS)):
		world.tick(DT)
	var after: Vector3 = _in_the_ship(world, carrier, hawkeye)
	var turned: float = rad_to_deg(absf(angle_difference(heading_before, _heading(world.vehicle_state(carrier)))))
	var slid: float = Vector2(after.x - before.x, after.z - before.z).length()
	_check("a_craft_parked_off_the_centre_line_of_a_turning_carrier_stays_on_its_spot",
		hawkeye != 0 and turned >= DECK_TURNED_AT_LEAST and slid <= DECK_SLID_AT_MOST,
		"the carrier turned %.1f degrees in %.0f s; the Hawkeye %.1f m from its middle moved %.2f m across the deck (%s -> %s); the carrier's centre of mass at %s in its frame" % [
			turned, DECK_TURN_SECONDS, Vector2(before.x, before.z).length(), slid, before, after,
			world.body_mass(carrier).get("centre", Vector3.ZERO)])
	_let_go(world)


## Where `craft` is in `ship`'s frame now.
func _in_the_ship(world: Object, ship: int, craft: int) -> Vector3:
	var s: Dictionary = world.vehicle_state(ship)
	var c: Dictionary = world.vehicle_state(craft)
	return Transform3D(Basis(s["basis"] as Quaternion), s["position"] as Vector3).affine_inverse() * (c["position"] as Vector3)


## A vehicle's heading from its state, radians, as a spawn's yaw is: 0 has the nose to -Z.
func _heading(state: Dictionary) -> float:
	var nose: Vector3 = (state["basis"] as Quaternion) * Vector3.FORWARD
	return atan2(-nose.x, -nose.z)


func _said(wrong: String) -> String:
	return "as stated" if wrong == "" else wrong


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


func _world(client_id: int) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(TICK_HZ)
	world.start(client_id)
	return world


func _let_go(world: Object) -> void:
	world.teardown()
	if not (world is RefCounted):
		world.free()


func _step_pair(server: Object, client: Object) -> void:
	server.tick(DT)
	client.tick(DT)
	for packet in server.take_outbound():
		client.deliver(0, packet["bytes"], packet["bits"])
	for packet in client.take_outbound():
		server.deliver(1, packet["bytes"], packet["bits"])


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
