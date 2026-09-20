extends Node
## Headless: kind `jumbo`, the Boeing 747-400, is a distinct, selectable, networked and pilotable craft, the size the
## drawing says. Read RESULT=, not the process exit code.
##
## IT WAS `mercury`, an E-6B, until 2026-09-19 (lane/liners): drawn since as a 747-400 (`Boeing747Airframe`), and the
## simulation's shape -- the box, the span, the mass, the four stations -- with it. The kind's number is the Mercury's.

## BOEING'S PRINTED FIGURES (ACAPS D6-58326-1, 2.2.1, and 1.2's weights): the length and height, the empty weight and the
## most it may take off at. The span is the drawn one at its winglets' tips, 64.9 m, against the 64.44 the ACAPS prints
## for the jig shape, so it is held to one per cent (`craft/jumbo/sources.md`).
const LENGTH := 70.67
const SPAN := 64.44
const OEW := 178755.0
const MTOW := 396893.0
const DRAWN_LENGTH := 70.67
const DRAWN_SPAN := 64.44
const DRAWN_HEIGHT := 19.41
const DT := 1.0 / 120.0
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[jumbo] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var ready: bool = ClassDB.class_exists("CockpitWorld")
	var probe: Object = ClassDB.instantiate("CockpitWorld") if ready else null
	ready = ready and int(probe.kind_count()) == Sim.Kind.size()
	_check("the_native_library_and_game_agree_on_the_new_kind", ready,
		"native %d, game %d" % [probe.kind_count() if probe != null else 0, Sim.Kind.size()])
	if probe != null:
		probe.teardown()
	if not ready:
		_finish()
		return
	_the_public_shape_and_station_roles_are_explicit()
	_the_model_reads_as_a_747_at_public_scale()
	_the_cockpit_package_loads_every_station()
	_the_pilot_can_launch_a_parked_jumbo()
	_the_aircraft_answers_both_flight_decks_controls()
	_the_network_can_select_and_fly_it()
	_finish()


func _the_public_shape_and_station_roles_are_explicit() -> void:
	var g: Dictionary = Sim.geometry_of(Sim.Kind.JUMBO)
	var e: Vector3 = g.get("extents", Vector3.ZERO)
	var poses: Array = g.get("seat_poses", [])
	var roles: Array[String] = []
	for pose in poses:
		roles.append(String((pose as Dictionary).get("station", "")))
	var inside: bool = true
	for pose in poses:
		var at: Vector3 = (pose as Dictionary).get("position", Vector3.ZERO)
		inside = inside and absf(at.x) < e.x and absf(at.y) < e.y and absf(at.z) < e.z
	_check("the_jumbo_has_boeings_dimensions_and_mass_and_four_honest_station_roles",
		absf(e.z * 2.0 - LENGTH) < 0.01 and absf(float(g.get("span", 0.0)) * 2.0 - SPAN) < SPAN * 0.01
			and float(g.get("mass", 0.0)) > OEW and float(g.get("mass", 0.0)) <= MTOW
			and roles == ["pilot", "copilot", "operator", "operator"] and inside
			and bool(g.get("pilotable", false)) and VehicleCatalogue.pilotable(Sim.Kind.JUMBO),
		"%.1f m long, %.1f m span, %.0f kg, roles %s, inside %s" % [e.z * 2.0,
			float(g.get("span", 0.0)) * 2.0, float(g.get("mass", 0.0)), roles, inside])
	var schema: Dictionary = Sim.schema_of(Sim.Kind.JUMBO)
	var channels: Array[String] = []
	for entry in schema.get("channels", []):
		channels.append(String((entry as Dictionary).get("name", "")))
	_check("and_its_bus_has_flight_and_mission_channels_without_fictional_weapons",
		"throttle" in channels and "flaps" in channels and "gear" in channels
			and "mission display page" in channels and "communications mode" in channels
			and not "weapon" in channels and not "master arm" in channels,
		", ".join(channels))


func _the_model_reads_as_a_747_at_public_scale() -> void:
	var scene := load("res://objects/vehicles/craft_jumbo.tscn") as PackedScene
	var view := scene.instantiate() as VehicleView if scene != null else null
	if view == null:
		_check("the_jumbo_has_a_preview_model", false, "scene missing")
		return
	add_child(view)
	view.preview_kind = Sim.Kind.JUMBO
	view._show_in_editor()
	var frame := view.find_child("Boeing747", true, false) as JetlinerAirframe
	var engines := _named_parts(view, "Engine")
	var wings := _named_parts(view, "WingPort") + _named_parts(view, "WingStarboard")
	# THE UPPER DECK: the drawn fuselage's crown over the hump (station 15) stands at least 0.7 m over its crown aft of the
	# wing (station 45) -- read from the drawn vertices within a metre of each station.
	var hump: float = 0.0
	if frame != null:
		var fuselage := frame.find_child("Fuselage", true, false) as MeshInstance3D
		var crown := func(station: float) -> float:
			var top: float = -INF
			var z: float = frame.point(0.0, 0.0, station).z
			for p in fuselage.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				if absf((p as Vector3).z - z) < 1.0:
					top = maxf(top, (p as Vector3).y)
			return top
		hump = float(crown.call(15.0)) - float(crown.call(45.0))
	var bounds := _drawn_bounds(frame if frame != null else view)
	_check("the_model_has_four_engines_swept_wings_and_an_upper_deck",
		frame != null and engines == 4 and wings == 2 and hump > 0.7,
		"airframe %s, engines %d, wings %d, the hump %.2f m over the aft crown" % [frame != null, engines, wings, hump])
	_check("and_the_drawn_model_stays_within_two_percent_of_public_scale",
		absf(bounds.size.z - DRAWN_LENGTH) <= DRAWN_LENGTH * 0.02 and absf(bounds.size.x - DRAWN_SPAN) <= DRAWN_SPAN * 0.02
			and absf(bounds.size.y - DRAWN_HEIGHT) <= DRAWN_HEIGHT * 0.02,
		"drawn %.2f long x %.2f span x %.2f high" % [bounds.size.z, bounds.size.x, bounds.size.y])
	view.queue_free()


func _the_cockpit_package_loads_every_station() -> void:
	var package: Dictionary = AuthoredCraftPackages.read(Sim.Kind.JUMBO)
	var wrong: Array[String] = []
	for seat in range(4):
		var built: Dictionary = AuthoredCraftPackages.make_station(Sim.Kind.JUMBO, seat)
		if built.has("error"):
			wrong.append("seat %d: %s" % [seat, built["error"]])
			continue
		var station := built["station"] as CockpitStation
		if station == null or station.controls().is_empty():
			wrong.append("seat %d has no devices" % seat)
		if station != null:
			station.free()
	_check("the_versioned_builder_package_and_all_four_stations_load_from_json",
		not package.has("error") and wrong.is_empty(),
		String(package.get("error", "four stations")) if wrong.is_empty() else "; ".join(wrong))


func _the_pilot_can_launch_a_parked_jumbo() -> void:
	var world := _world(0)
	world.add_static_box(Vector3(0.0, -5.0, 0.0), Vector3(2000.0, 5.0, 2000.0))
	var e: Vector3 = Sim.geometry_of(Sim.Kind.JUMBO).get("extents", Vector3.ONE)
	var parked: int = int(world.spawn_vehicle(Sim.Kind.JUMBO, Vector3(0.0, e.y + 0.3, 0.0),
		0.0, Vector3.ZERO))
	var made: Dictionary = world.spawn_pilot(39, Sim.Kind.POD, Vector3(500.0, 100.0, 0.0),
		0.0, Vector3.ZERO)
	var seated: bool = bool(world.seat_client(39, parked, 0))
	for i in range(20):
		world.tick(DT)
	var state: Dictionary = world.vehicle_state(parked)
	_check("taking_the_pilot_seat_launches_the_parked_jumbo_in_a_flyable_state",
		seated and (state.get("position", Vector3.ZERO) as Vector3).y > 100.0
			and (state.get("velocity", Vector3.ZERO) as Vector3).length() > 50.0,
		"seated %s, altitude %.1f m, speed %.1f m/s, pilot %s" % [seated,
			(state.get("position", Vector3.ZERO) as Vector3).y,
			(state.get("velocity", Vector3.ZERO) as Vector3).length(), made.get("pilot")])
	_let_go(world)


func _the_aircraft_answers_both_flight_decks_controls() -> void:
	var world := _world(0)
	var made: Dictionary = world.spawn_pilot(40, Sim.Kind.JUMBO, Vector3(0.0, 1800.0, 0.0),
		0.0, Vector3(0.0, 0.0, -105.0))
	var pilot: int = int(made.get("pilot", 0))
	var craft: int = int(made.get("vehicle", 0))
	for i in range(120):
		world.set_pilot_input(pilot, _controls({"throttle": 0.72}))
		world.tick(DT)
	for i in range(120):
		world.set_pilot_input(pilot, _controls({"throttle": 0.78, "pitch": 1.0, "roll": 0.45}))
		world.tick(DT)
	var after: Dictionary = world.vehicle_state(craft)
	var pilot_spin: float = (after.get("spin", Vector3.ZERO) as Vector3).length()
	var copilot_ok: bool = bool(world.seat_client(40, craft, 1))
	for i in range(120):
		world.set_pilot_input(pilot, _controls({"throttle": 0.78, "rudder": 1.0}))
		world.tick(DT)
	var copilot_spin: float = (world.vehicle_state(craft).get("spin", Vector3.ZERO) as Vector3).length()
	var finite: bool = _finite_state(world.vehicle_state(craft))
	_check("the_pilot_and_copilot_can_fly_the_stable_aircraft",
		pilot_spin > 0.12 and copilot_ok and copilot_spin > 0.08 and finite,
		"pilot %.3f rad/s, copilot %.3f rad/s, finite %s" % [pilot_spin, copilot_spin, finite])
	_let_go(world)


func _the_network_can_select_and_fly_it() -> void:
	var server := _world(0)
	var client := _world(1)
	server.add_issue_place(Sim.Kind.JUMBO, Vector3(500.0, 1200.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -105.0))
	for i in range(90):
		_step_pair(server, client)
	server.spawn_pilot(1, Sim.Kind.POD, Vector3(0.0, 500.0, 0.0), 0.0, Vector3.ZERO)
	for i in range(180):
		_step_pair(server, client)
	client.set_input(_controls({"buttons": Sim.BUTTON_KIND, "kind_wanted": Sim.Kind.JUMBO,
		"menu_request": 1}))
	_step_pair(server, client)
	client.set_input(_controls({"kind_wanted": Sim.NO_KIND, "menu_request": 1}))
	var chosen: int = 0
	for i in range(600):
		client.set_input(_controls({"throttle": 0.8, "pitch": 0.75, "menu_request": 1}))
		_step_pair(server, client)
		for state in server.vehicle_states():
			if int((state as Dictionary).get("kind", -1)) == Sim.Kind.JUMBO:
				chosen = int((state as Dictionary).get("entity", 0))
	var server_state: Dictionary = server.vehicle_state(chosen)
	var client_has: bool = false
	for state in client.vehicle_states():
		client_has = client_has or int((state as Dictionary).get("kind", -1)) == Sim.Kind.JUMBO
	_check("a_client_can_select_the_jumbo_and_its_controls_reach_the_server",
		chosen > 0 and client_has and (server_state.get("velocity", Vector3.ZERO) as Vector3).length() > 20.0
			and (server_state.get("spin", Vector3.ZERO) as Vector3).length() > 0.05,
		"entity %d, client sees it %s, speed %.1f, spin %.3f" % [chosen, client_has,
			(server_state.get("velocity", Vector3.ZERO) as Vector3).length(),
			(server_state.get("spin", Vector3.ZERO) as Vector3).length()])
	_let_go(server)
	_let_go(client)


func _drawn_bounds(root: Node3D) -> AABB:
	var box := AABB()
	var any := false
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var drawn := child as MeshInstance3D
		if drawn.mesh == null:
			continue
		var into := root.global_transform.affine_inverse() * drawn.global_transform
		for surface in range(drawn.mesh.get_surface_count()):
			var vertices: PackedVector3Array = drawn.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point in vertices:
				var at: Vector3 = into * point
				box = box.expand(at) if any else AABB(at, Vector3.ZERO)
				any = true
	return box


func _named_parts(root: Node, prefix: String) -> int:
	var count := 0
	for child in root.get_children():
		if child is MeshInstance3D and String(child.name).begins_with(prefix):
			count += 1
		count += _named_parts(child, prefix)
	return count


func _finite_state(state: Dictionary) -> bool:
	var p: Vector3 = state.get("position", Vector3(INF, INF, INF))
	var v: Vector3 = state.get("velocity", Vector3(INF, INF, INF))
	var q: Quaternion = state.get("basis", Quaternion(INF, INF, INF, INF))
	return p.is_finite() and v.is_finite() and is_finite(q.x) and is_finite(q.y) and is_finite(q.z) and is_finite(q.w)


func _controls(overrides: Dictionary = {}) -> Dictionary:
	var input := {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0,
		"brake": 0.0, "head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3.ZERO, "left_basis": Quaternion.IDENTITY, "right": Vector3.ZERO,
		"right_basis": Quaternion.IDENTITY, "grip_left": 0.0, "grip_right": 0.0,
		"buttons": 0, "trigger": 0.0, "kind_wanted": Sim.NO_KIND}
	for key in overrides:
		input[key] = overrides[key]
	return input


func _world(client_id: int) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(client_id)
	return world


func _step_pair(server: Object, client: Object) -> void:
	server.tick(DT)
	client.tick(DT)
	for packet in server.take_outbound():
		client.deliver(0, packet["bytes"], packet["bits"])
	for packet in client.take_outbound():
		server.deliver(1, packet["bytes"], packet["bits"])


func _let_go(world: Object) -> void:
	world.teardown()
	if not (world is RefCounted):
		world.free()


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
