extends Node
## Headless contract for the distinct UH-60M-inspired craft: public dimensions, semantic
## model, immutable stations, piloting and replicated client input. Read RESULT=.

const LENGTH := 12.62
const ROTOR_DIAMETER := 16.36
const HEIGHT := 5.16
const MASS := 9979.0
const DT := 1.0 / 120.0
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[uh60] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: _failures.append(label)


func _ready() -> void:
	var probe: Object = ClassDB.instantiate("CockpitWorld") if ClassDB.class_exists("CockpitWorld") else null
	var ready := probe != null and int(probe.kind_count()) == Sim.Kind.size()
	_check("the_native_library_and_game_agree_on_the_new_kind", ready,
		"native %d, game %d" % [probe.kind_count() if probe != null else 0, Sim.Kind.size()])
	if probe != null: _let_go(probe)
	if not ready: _finish(); return
	_the_new_shape_preserves_the_legacy_helicopter()
	_the_airframe_has_the_black_hawk_fittings_and_public_envelope()
	_the_first_lod_has_a_bounded_cost()
	_the_package_loads_all_four_stations()
	_the_pilot_and_copilot_can_fly_it()
	_the_client_selects_and_flies_it_over_replication()
	_finish()


func _the_new_shape_preserves_the_legacy_helicopter() -> void:
	var old := Sim.geometry_of(Sim.Kind.HELI)
	var g := Sim.geometry_of(Sim.Kind.UH60)
	var e: Vector3 = g.get("extents", Vector3.ZERO)
	var poses: Array = g.get("seat_poses", [])
	var roles: Array[String] = []
	var yaws: Array[float] = []
	for pose in poses:
		roles.append(String((pose as Dictionary).get("station", "")))
		yaws.append(float((pose as Dictionary).get("yaw", 0.0)))
	_check("the_uh60_uses_the_army_dimensions_mass_and_four_crew_roles",
		absf(e.z*2.0-LENGTH) < 0.01 and absf(float(g.get("span",0.0))*2.0-ROTOR_DIAMETER) < 0.01
			and absf(float(g.get("mass",0.0))-MASS) < 0.5 and roles == ["pilot","copilot","turret","turret"]
			and absf(yaws[2]-PI/2.0) < 0.001 and absf(yaws[3]+PI/2.0) < 0.001,
		"%.2f m fuselage, %.2f m rotor, %.0f kg, %s" % [e.z*2.0, float(g.get("span",0.0))*2.0, float(g.get("mass",0.0)), roles])
	_check("and_the_legacy_light_helicopter_keeps_its_identity_and_geometry",
		String(old.get("name","")) == "helicopter" and (old.get("extents",Vector3.ZERO) as Vector3).is_equal_approx(Vector3(0.95,1.05,2.60))
			and absf(float(old.get("mass",0.0))-900.0) < 0.01 and int(old.get("seats",0)) == 4,
		"%s, %s, %.0f kg" % [old.get("name"), old.get("extents"), old.get("mass")])


func _the_airframe_has_the_black_hawk_fittings_and_public_envelope() -> void:
	var scene := load("res://objects/vehicles/craft_uh60.tscn") as PackedScene
	var view := scene.instantiate() as VehicleView if scene != null else null
	if view == null: _check("the_uh60_has_a_preview", false, "scene missing"); return
	add_child(view); view.preview_kind = Sim.Kind.UH60; view._show_in_editor()
	var frame := view.get_node_or_null("Body/UH60Airframe") as Uh60Airframe
	var names: Array[String] = []
	if frame != null:
		for child in frame.find_children("*", "MeshInstance3D", true, false): names.append(String(child.name))
	# THE ENVELOPE, EACH NUMBER FROM WHAT IT IS OF. FM 3-04's 12.62 m is the FUSELAGE, so it is measured without the
	# rotors; 16.36 m is the ROTOR, so it is the main rotor's reach from its own shaft, twice; 5.16 m is the height to the
	# top of the tail rotor, so it is everything, wheels to tip. The first version measured all three off one box round
	# the whole exterior, which is why its rotor had to be parked in a lopsided "shallow X" -- four blades 0.55 rad apart
	# instead of a quarter turn -- so that the blades reached the diameter across and not the fuselage's length along.
	var fuselage := _bounds(frame.exterior, ["MainRotor", "TailRotor"]) if frame != null else AABB()
	var whole := _bounds(frame.exterior) if frame != null else AABB()
	var reach: float = _reach(frame.main_rotor) if frame != null else 0.0
	var four_main: int = int(frame.main_rotor.get_meta(&"blades", 0)) if frame != null else 0
	var four_tail: int = int(frame.tail_rotor.get_meta(&"blades", 0)) if frame != null else 0
	var required := ["CabinFuselage", "SteppedCockpitNose", "TailBoom", "PortEngineHousing",
		"StarboardEngineHousing", "FoldingStabilator", "PortSlidingDoorFrame",
		"StarboardSlidingDoorFrame", "PortMainWheel", "StarboardMainWheel", "TailWheel", "MainRotorBlades",
		"TailRotorBlades", "SweptTailFin"]
	var missing: Array[String] = []
	for label in required:
		if not label in names: missing.append(label)
	_check("the_semantic_airframe_has_twin_engines_doors_wheels_stabilator_and_both_four_blade_rotors",
		missing.is_empty() and four_main == 4 and four_tail == 4,
		"main %d, tail %d, missing %s" % [four_main, four_tail, missing])
	_check("and_the_drawn_envelope_is_within_two_percent_of_the_public_dimensions",
		absf(reach * 2.0 - ROTOR_DIAMETER) <= ROTOR_DIAMETER*0.02
			and absf(whole.size.y-HEIGHT) <= HEIGHT*0.02 and absf(fuselage.size.z-LENGTH) <= LENGTH*0.02,
		"%.2f m rotor x %.2f m high x %.2f m fuselage" % [reach * 2.0, whole.size.y, fuselage.size.z])
	view.queue_free()


func _the_first_lod_has_a_bounded_cost() -> void:
	var frame := Uh60Airframe.new(); frame.dress(Sim.geometry_of(Sim.Kind.UH60)); add_child(frame)
	var draws := 0; var triangles := 0; var ranged := 0; var materials: Dictionary = {}
	for child in frame.exterior.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		draws += mesh_node.mesh.get_surface_count(); materials[mesh_node.material_override] = true
		if mesh_node.visibility_range_end > 0.0: ranged += 1
		for surface in range(mesh_node.mesh.get_surface_count()):
			var arrays := mesh_node.mesh.surface_get_arrays(surface)
			var indexes: Variant = arrays[Mesh.ARRAY_INDEX]
			var points := (indexes as PackedInt32Array).size() if indexes is PackedInt32Array else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			triangles += points / 3
	_check("the_first_exterior_lod_stays_inside_the_vr_asset_budget",
		draws <= 32 and triangles <= 100000 and materials.size() <= 12 and ranged >= 8,
		"%d draws, %d triangles, %d materials, %d culled fittings" % [draws,triangles,materials.size(),ranged])
	frame.queue_free()


func _the_package_loads_all_four_stations() -> void:
	var package := AuthoredCraftPackages.read(Sim.Kind.UH60)
	var wrong: Array[String] = []
	for seat in range(4):
		var made := AuthoredCraftPackages.make_station(Sim.Kind.UH60, seat)
		if made.has("error"): wrong.append("seat %d: %s" % [seat,made["error"]]); continue
		var station := made.get("station") as CockpitStation
		if station == null or station.controls().is_empty(): wrong.append("seat %d has no controls" % seat)
		if station != null: station.free()
	_check("the_immutable_package_and_every_station_load_from_json", not package.has("error") and wrong.is_empty(),
		String(package.get("error","four stations")) if wrong.is_empty() else "; ".join(wrong))


func _the_pilot_and_copilot_can_fly_it() -> void:
	var world := _world(0)
	var made: Dictionary = world.spawn_pilot(40, Sim.Kind.UH60, Vector3(0,500,0), 0.0, Vector3.ZERO)
	var pilot := int(made.get("pilot",0)); var craft := int(made.get("vehicle",0))
	for i in range(240): world.set_pilot_input(pilot, _controls({"throttle":0.72,"pitch":0.35,"roll":0.18})); world.tick(DT)
	var other: Dictionary = world.spawn_pilot(41, Sim.Kind.POD, Vector3(300,100,0), 0.0, Vector3.ZERO)
	var seated := bool(world.seat_client(41, craft, 1))
	var state: Dictionary = world.vehicle_state(craft)
	_check("the_pilot_flies_while_the_copilot_can_take_the_second_flying_station",
		seated and (state.get("velocity",Vector3.ZERO) as Vector3).length() > 2.0
			and (state.get("spin",Vector3.ZERO) as Vector3).length() > 0.03 and _finite(state),
		"copilot %s/%s, speed %.2f, spin %.3f" % [seated,other.get("pilot"),(state.get("velocity",Vector3.ZERO) as Vector3).length(),(state.get("spin",Vector3.ZERO) as Vector3).length()])
	_let_go(world)


func _the_client_selects_and_flies_it_over_replication() -> void:
	var server := _world(0); var client := _world(1)
	for i in range(90): _pair(server,client)
	var made: Dictionary = server.spawn_pilot(1, Sim.Kind.UH60, Vector3(0,500,0), 0.0, Vector3.ZERO)
	var craft := int(made.get("vehicle",0))
	for i in range(180): _pair(server,client)
	for i in range(480): client.set_input(_controls({"throttle":0.75,"roll":0.45})); _pair(server,client)
	var server_state: Dictionary = server.vehicle_state(craft); var client_has := false
	for state in client.vehicle_states(): client_has = client_has or int((state as Dictionary).get("kind",-1)) == Sim.Kind.UH60
	_check("a_client_flies_its_uh60_and_its_controls_reach_the_server",
		client_has and not server_state.is_empty() and (server_state.get("velocity",Vector3.ZERO) as Vector3).length() > 2.0
			and (server_state.get("spin",Vector3.ZERO) as Vector3).length() > 0.03,
		"client sees %s, speed %.2f, spin %.3f" % [client_has,(server_state.get("velocity",Vector3.ZERO) as Vector3).length(),(server_state.get("spin",Vector3.ZERO) as Vector3).length()])
	_let_go(server); _let_go(client)


## THE BOX `root`'s DRAWN VERTICES FILL, in its own frame, leaving out anything under a child named in `leave`.
func _bounds(root: Node3D, leave: Array = []) -> AABB:
	var box := AABB(); var any := false
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var drawn := child as MeshInstance3D
		if not drawn.visible: continue
		var skip := false
		for name in leave:
			var under := root.get_node_or_null(NodePath(String(name)))
			skip = skip or (under != null and under.is_ancestor_of(drawn))
		if skip: continue
		var into := root.global_transform.affine_inverse() * drawn.global_transform
		for surface in range(drawn.mesh.get_surface_count()):
			for point in drawn.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				var at: Vector3 = into * point; box = box.expand(at) if any else AABB(at,Vector3.ZERO); any = true
	return box


## HOW FAR A ROTOR'S BLADES REACH FROM ITS SHAFT, from their drawn vertices in the rotor's own frame.
func _reach(rotor: Node3D) -> float:
	var blades := rotor.get_node_or_null(NodePath(String(rotor.name) + "Blades")) as MeshInstance3D
	if blades == null: return 0.0
	var far := 0.0
	for point in blades.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
		far = maxf(far, Vector2(point.x, point.z).length())
	return far


func _controls(overrides: Dictionary = {}) -> Dictionary:
	var input := {"throttle":0.0,"pitch":0.0,"roll":0.0,"rudder":0.0,"brake":0.0,"head":Vector3.ZERO,
		"head_basis":Quaternion.IDENTITY,"left":Vector3.ZERO,"left_basis":Quaternion.IDENTITY,"right":Vector3.ZERO,
		"right_basis":Quaternion.IDENTITY,"grip_left":0.0,"grip_right":0.0,"buttons":0,"trigger":0.0,"kind_wanted":Sim.NO_KIND}
	for key in overrides: input[key] = overrides[key]
	return input


func _world(id: int) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(id)
	return world


func _pair(server: Object, client: Object) -> void:
	server.tick(DT); client.tick(DT)
	for packet in server.take_outbound(): client.deliver(0,packet["bytes"],packet["bits"])
	for packet in client.take_outbound(): server.deliver(1,packet["bytes"],packet["bits"])


func _finite(state: Dictionary) -> bool:
	var p: Vector3 = state.get("position",Vector3(INF,INF,INF)); var v: Vector3 = state.get("velocity",Vector3(INF,INF,INF))
	return p.is_finite() and v.is_finite()


func _let_go(world: Object) -> void:
	world.teardown()
	if not (world is RefCounted):
		world.free()


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL", "" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
