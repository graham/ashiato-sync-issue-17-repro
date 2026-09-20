extends Node
## Headless: the two-seat carrier fighter is selectable, networked and pilotable, while its
## optional scene remains presentation-only. Dimensions and crew come from the Navy fact file.
## Read RESULT=, not the process exit code.

## The native hull's length, and the Navy fact file's figures the drawing is measured against. 60.3 ft is 18.38 m.
const LENGTH := 18.5
const NAVY_LENGTH := 18.38
const SPAN := 13.68
const HEIGHT := 4.87
## REFERENCE FIGURES, each typed from its source and never read from the airframe that draws them (see
## craft/fighter/sources.md): [HARV] NASA's F-18 HARV three-view, scaled x1.118 where the Super Hornet's wing is bigger;
## [SHP] a Super Hornet gear-down profile; 30 in main tyres, 11.5 in wide.
const FIN_CANT := 20.0
const FOLD_OUT := 4.45
## THE LEGACY LEX EDGE off [HARV]'s plan view, column by column: [metres forward of the wing's root leading edge, metres
## off the centreline]. The Super Hornet's is this scaled x1.118 about its own root leading edge, 9.30 m aft of the nose
## [SHP]. Asserted at three stations, because one station passed a straight strake 0.1 m narrow everywhere else.
const HARV_LEX: Array = [[0.03, 1.436], [1.07, 1.333], [2.10, 1.195], [3.13, 0.989], [4.16, 0.860], [4.85, 0.731]]
const WING_SCALE := 1.118
const ROOT_LE_STATION := 9.30
const LEX_STATIONS: Array[float] = [8.20, 7.09, 5.60]
## THE DORSAL LINE off [SHP]'s profile, column by column: [metres aft of the nose, metres over the ground].
const SHP_TOP: Array = [[8.20, 3.15], [9.30, 3.12], [12.80, 2.88]]
const MAIN_TRACK := 3.11
## [SHP]'s wheels by the centroid of their dark tyre pixels: 5.87 and 12.31 m aft of the nose.
const WHEELBASE := 6.44
const MAIN_TYRE := 0.76
const MAIN_TYRE_WIDE := 0.29
const PARTS: Array[String] = ["Airframe", "Canopy", "CockpitTub", "FinPort", "FinStarboard", "Details", "NoseGear",
	"MainGearPort", "MainGearStarboard", "MainDoorPort", "MainDoorStarboard", "NoseDoorPort", "NoseDoorStarboard", "Hook"]
const SURFACES: Array[String] = ["LeadingEdgeFlapInboard", "LeadingEdgeFlapOutboard", "TrailingEdgeFlap", "Aileron",
	"Rudder", "Stabilator", "LauncherRail", "Intake", "Nozzle", "WingInboard", "WingOutboard"]
const GEAR_PARTS: Array[String] = ["NoseGear", "MainGearPort", "MainGearStarboard", "MainDoorPort", "MainDoorStarboard",
	"NoseDoorPort", "NoseDoorStarboard"]
const MTOW := 29937.0
const DT := 1.0 / 120.0
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[fighter] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
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
	_the_original_model_reads_as_a_fighter_at_public_scale()
	_the_asset_boundary_and_builder_inspector_are_independent_of_simulation()
	_a_craft_drawn_through_its_visual_scene_keeps_its_lights_and_guns()
	_the_exterior_meets_the_first_lod_budget()
	_the_cockpit_package_loads_every_station()
	_the_seats_put_both_crews_eyes_where_the_photograph_has_them()
	_the_hook_is_a_physical_channel_on_the_carrier_aeroplanes()
	_the_pilot_can_launch_a_parked_fighter()
	_the_aircraft_answers_both_flight_decks_controls()
	_the_network_can_select_and_fly_it()
	_the_gear_is_drawn_from_each_machines_bus_on_the_frame_it_changes()
	await _the_drawn_gear_follows_the_bus_in_a_live_session()
	_finish()


func _the_public_shape_and_station_roles_are_explicit() -> void:
	var g: Dictionary = Sim.geometry_of(Sim.Kind.FIGHTER)
	var e: Vector3 = g.get("extents", Vector3.ZERO)
	var poses: Array = g.get("seat_poses", [])
	var roles: Array[String] = []
	for pose in poses:
		roles.append(String((pose as Dictionary).get("station", "")))
	var inside: bool = true
	for pose in poses:
		var at: Vector3 = (pose as Dictionary).get("position", Vector3.ZERO)
		inside = inside and absf(at.x) < e.x and absf(at.y) < e.y and absf(at.z) < e.z
	_check("the_fighter_has_public_dimensions_mass_and_tandem_station_roles",
		absf(e.z * 2.0 - LENGTH) < 0.01 and absf(float(g.get("span", 0.0)) * 2.0 - SPAN) < 0.01
			and float(g.get("mass", 0.0)) > 15000.0 and float(g.get("mass", 0.0)) <= MTOW
			and roles == ["pilot", "operator"] and inside
			and bool(g.get("pilotable", false)) and VehicleCatalogue.pilotable(Sim.Kind.FIGHTER),
		"%.1f m long, %.1f m span, %.0f kg, roles %s, inside %s" % [e.z * 2.0,
			float(g.get("span", 0.0)) * 2.0, float(g.get("mass", 0.0)), roles, inside])
	var schema: Dictionary = Sim.schema_of(Sim.Kind.FIGHTER)
	var channels: Array[String] = []
	for entry in schema.get("channels", []):
		channels.append(String((entry as Dictionary).get("name", "")))
	_check("and_its_bus_has_flight_weapon_and_display_channels",
		"throttle" in channels and "flaps" in channels and "gear" in channels
			and "display page" in channels and "weapon" in channels and "master arm" in channels,
		", ".join(channels))


func _the_original_model_reads_as_a_fighter_at_public_scale() -> void:
	var scene := load("res://objects/vehicles/craft_fighter.tscn") as PackedScene
	var view := scene.instantiate() as VehicleView if scene != null else null
	if view == null:
		_check("the_fighter_has_a_preview_model", false, "scene missing")
		return
	add_child(view)
	view.preview_kind = Sim.Kind.FIGHTER
	view._show_in_editor()
	var frame := view._visual_scene as FighterAirframe
	if frame == null:
		_check("the_fighter_draws_its_super_hornet_airframe", false, "visual scene %s" % view._visual_scene)
		view.queue_free()
		return
	var missing: Array[String] = []
	for part in PARTS:
		if frame.find_child(part, true, false) == null:
			missing.append(part)
	for side in ["Port", "Starboard"]:
		for surface in SURFACES:
			if not frame.surfaces.has(surface + side):
				missing.append(surface + side)
	_check("the_model_has_the_super_hornets_parts_and_separate_control_surfaces", missing.is_empty(),
		"%d parts and %d surfaces a side; missing %s" % [PARTS.size(), SURFACES.size(), missing])
	var flap: AABB = frame.surfaces.get("TrailingEdgeFlapStarboard", AABB())
	var aileron: AABB = frame.surfaces.get("AileronStarboard", AABB())
	var lef_in: AABB = frame.surfaces.get("LeadingEdgeFlapInboardStarboard", AABB())
	var lef_out: AABB = frame.surfaces.get("LeadingEdgeFlapOutboardStarboard", AABB())
	_check("and_the_flaps_and_ailerons_part_at_the_wing_fold",
		flap.end.x < aileron.position.x and lef_in.end.x < lef_out.position.x
			and absf((flap.end.x + aileron.position.x) * 0.5 - FOLD_OUT) < 0.25,
		"flap ends %.2f, aileron starts %.2f, leading-edge flaps part at %.2f / %.2f; the fold is %.2f m out"
			% [flap.end.x, aileron.position.x, lef_in.end.x, lef_out.position.x, FOLD_OUT])

	# THE ENVELOPE, on its wheels where a parked fighter actually rests.
	var rest := _parked_rest_height()
	var bounds := _drawn_bounds(frame)
	_check("and_the_drawn_model_stays_within_two_percent_of_public_scale",
		absf(bounds.size.z - NAVY_LENGTH) <= NAVY_LENGTH * 0.02 and absf(bounds.size.z - LENGTH) <= LENGTH * 0.02
			and absf(bounds.size.x - SPAN) <= SPAN * 0.02 and absf(bounds.size.y - HEIGHT) <= HEIGHT * 0.02,
		"drawn %.2f long x %.2f span x %.2f high; Navy %.2f x %.2f x %.2f, hull %.2f long" % [bounds.size.z,
			bounds.size.x, bounds.size.y, NAVY_LENGTH, SPAN, HEIGHT, LENGTH])
	_check("and_its_wheels_stand_where_a_parked_fighter_rests",
		absf(bounds.position.y + rest) < 0.03,
		"lowest drawn point %.3f m, a parked origin rests %.4f m over the ground" % [bounds.position.y, rest])

	# THE FINS, from the drawn vertices: the mid-plane at the root and at the tip.
	var cants: Array[float] = []
	for side in [1.0, -1.0]:
		var fin := frame.find_child("FinStarboard" if side > 0.0 else "FinPort", true, false) as MeshInstance3D
		var points := _vertices_in(frame, fin)
		var low := INF
		var high := -INF
		for p in points:
			low = minf(low, p.y)
			high = maxf(high, p.y)
		var root := _mean_between(points, low, low + 0.12)
		var tip := _mean_between(points, high - 0.12, high)
		cants.append(rad_to_deg(atan2(side * (tip.x - root.x), tip.y - root.y)))
	_check("and_its_fins_are_canted_twenty_degrees_outboard",
		absf(cants[0] - FIN_CANT) <= 1.0 and absf(cants[1] - FIN_CANT) <= 1.0,
		"starboard %.1f, port %.1f degrees outboard; reference %.0f" % [cants[0], cants[1], FIN_CANT])

	# THE LEX: none ahead of the windscreen, and on the legacy edge scaled about the wing root at three stations.
	var airframe := _vertices_in(frame, frame.find_child("Airframe", true, false) as MeshInstance3D)
	var strake_at_nose := _widest_near(airframe, 2.60, 1.75, 2.10, rest) - _widest_near(airframe, 2.60, 2.15, 2.30, rest)
	var lex_said: Array[String] = []
	var lex_ok := strake_at_nose < 0.15
	for at in LEX_STATIONS:
		var drawn := _widest_near(airframe, at, 1.85, 2.15, rest)
		var wanted := _reference_lex(ROOT_LE_STATION - at)
		lex_ok = lex_ok and absf(drawn - wanted) <= 0.06
		lex_said.append("%.2f m aft: %.2f m out, reference %.2f" % [at, drawn, wanted])
	_check("and_its_leading_edge_extensions_run_from_the_windscreen_to_the_wing_root",
		lex_ok, "at 2.6 m aft the chine is %.2f m wider than the shoulder; %s" % [strake_at_nose, "; ".join(lex_said)])

	# THE DORSAL LINE, the drawn top on the centreline against the Super Hornet profile's.
	var top_said: Array[String] = []
	var top_ok := true
	for row in SHP_TOP:
		var at: float = float(row[0])
		var z: float = at - FighterAirframe.LENGTH * 0.5
		var drawn := -INF
		for p in airframe:
			if absf(p.x) < 0.05 and absf(p.z - z) < 1.0:
				drawn = maxf(drawn, p.y + rest)
		top_ok = top_ok and absf(drawn - float(row[1])) <= 0.10
		top_said.append("%.1f m aft: %.2f m, profile %.2f" % [at, drawn, float(row[1])])
	_check("and_its_dorsal_line_runs_at_the_profiles_height_to_the_fins", top_ok, "; ".join(top_said))

	# THE GEAR: the carrier stance down, and nothing hanging with it up.
	var wheels := {}
	for part in ["NoseGear", "MainGearPort", "MainGearStarboard"]:
		var box := AABB()
		var first := true
		for p in _vertices_in(frame, frame.find_child(part, true, false) as MeshInstance3D):
			if p.y < -rest + 0.80:
				box = box.expand(p) if not first else AABB(p, Vector3.ZERO)
				first = false
		wheels[part] = box
	var starboard: AABB = wheels["MainGearStarboard"]
	var port: AABB = wheels["MainGearPort"]
	var nose: AABB = wheels["NoseGear"]
	# Each main wheel is the outermost thing on its leg, so its middle is half a tyre in from the outside.
	var track: float = (starboard.end.x - MAIN_TYRE_WIDE * 0.5) - (port.position.x + MAIN_TYRE_WIDE * 0.5)
	# THE WHEELBASE FROM THE CONTACT PATCHES: the lowest vertices of each tyre stand straight under its axle, where the middle
	# of everything below 0.8 m is pulled forward by the nose leg's launch bar and struts (it read 6.26 m for axles 6.44 apart).
	var wheelbase: float = _contact_z(frame, "MainGearStarboard", rest) - _contact_z(frame, "NoseGear", rest)
	_check("and_its_gear_down_has_the_carrier_stance",
		absf(track - MAIN_TRACK) < 0.08 and absf(wheelbase - WHEELBASE) < 0.15
			and absf(starboard.end.y - starboard.position.y - MAIN_TYRE) < 0.05,
		"track %.2f m (reference %.2f), wheelbase %.2f m (reference %.2f), main tyre %.2f m high (30 in)"
			% [track, MAIN_TRACK, wheelbase, WHEELBASE, starboard.end.y - starboard.position.y])
	# GEAR UP, judged against the DRAWN SKIN: the lowest points of every gear and door part, each against the airframe's
	# underside straight above or below it. A part with no skin over it at all is hanging out beside the aircraft.
	frame.set_gear(0.0)
	var hanging: Array[String] = []
	var skin := _vertices_in(frame, frame.find_child("Airframe", true, false) as MeshInstance3D)
	for part in GEAR_PARTS:
		var points := _vertices_in(frame, frame.find_child(part, true, false) as MeshInstance3D)
		var lowest: Array[Vector3] = []
		for p in points:
			lowest.append(p)
		lowest.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
		for p in lowest.slice(0, 6):
			var belly: float = _underside_at(skin, p.x, p.z)
			if p.y < belly - 0.035:
				hanging.append("%s at (%.2f, %.2f, %.2f) under a skin at %.2f" % [part, p.x, p.y, p.z, belly])
				break
	frame.set_gear(1.0)
	_check("and_gear_up_leaves_nothing_hanging_under_the_belly", hanging.is_empty(),
		"; ".join(hanging) if not hanging.is_empty() else "%d gear and door parts inside the belly line" % GEAR_PARTS.size())

	# THE HOOK: along the belly stowed, on the deck deployed, behind the wheels.
	var hook := frame.find_child("Hook", true, false) as MeshInstance3D
	frame.set_hook(0.0)
	var stowed := _lowest(_vertices_in(frame, hook))
	frame.set_hook(1.0)
	var deployed := _lowest(_vertices_in(frame, hook))
	frame.set_hook(0.0)
	_check("and_its_hook_stows_under_the_tail_and_reaches_the_deck_deployed",
		stowed.y + rest > 1.2 and absf(deployed.y + rest) < 0.06 and deployed.z > starboard.end.z + 3.0,
		"stowed lowest %.2f m over the ground, deployed %.3f m, %.1f m aft of the main wheels" % [stowed.y + rest,
			deployed.y + rest, deployed.z - starboard.end.z])

	# GEAR AND HOOK ARE PURE FUNCTIONS OF THEIR AMOUNT (actuators_research.md 3.7, test 11): 0.3 then 0.5 draws exactly what
	# 0.5 does, and 0.5 is between the two ends, measured from the drawn vertices of every moving part.
	var remembered: Array[String] = []
	var moving: Array[String] = GEAR_PARTS.duplicate()
	moving.append("Hook")
	for part in moving:
		var node := frame.find_child(part, true, false) as MeshInstance3D
		var setter: Callable = frame.set_hook if part == "Hook" else frame.set_gear
		# A door is open by a quarter of the gear's amount and stays open, so it is caught mid-swing lower down.
		var middle: float = 0.12 if part.contains("Door") else 0.5
		setter.call(middle)
		var straight := _vertices_in(frame, node)
		setter.call(middle * 0.6)
		setter.call(middle)
		var after := _vertices_in(frame, node)
		setter.call(0.0)
		var low_end := _vertices_in(frame, node)
		setter.call(1.0)
		var high_end := _vertices_in(frame, node)
		var same := straight.size() == after.size()
		var between := false
		for i in range(mini(straight.size(), after.size())):
			same = same and straight[i].is_equal_approx(after[i])
			between = between or (not straight[i].is_equal_approx(low_end[i]) and not straight[i].is_equal_approx(high_end[i]))
		if not same or not between:
			remembered.append("%s: same %s, between the ends %s" % [part, same, between])
	frame.set_gear(1.0)
	frame.set_hook(0.0)
	_check("and_its_gear_and_hook_are_pure_functions_of_their_amount", remembered.is_empty(),
		"; ".join(remembered) if not remembered.is_empty() else "%d moving parts: a lower amount then the middle one draws the middle one, and it is between 0 and 1"
			% moving.size())

	# THE CANOPY, round where a real crew's eyes are.
	var glass := _vertices_in(frame, frame.find_child("Canopy", true, false) as MeshInstance3D)
	var reports: Array[String] = []
	var covered := true
	for eye in [Vector2(FighterAirframe.PILOT_EYE_STATION, FighterAirframe.PILOT_EYE_HEIGHT),
			Vector2(FighterAirframe.WSO_EYE_STATION, FighterAirframe.WSO_EYE_HEIGHT)]:
		var z: float = eye.x - FighterAirframe.LENGTH * 0.5
		var y: float = eye.y - rest
		var top := -INF
		var sill := INF
		for p in glass:
			if absf(p.z - z) < 0.45:
				top = maxf(top, p.y)
				sill = minf(sill, p.y)
		reports.append("eye %.2f m up at %.2f m aft: glass %+.2f over it, sill %+.2f" % [eye.y, eye.x, top - y, sill - y])
		covered = covered and top - y >= 0.15 and y - sill >= 0.30
	_check("and_its_tandem_canopy_covers_both_reference_eyes", covered, "; ".join(reports))

	# THE LIGHTS AND CONTRAILS stand on the drawn airframe: the nav lights on the launcher rails' outer faces, the belly
	# beacon above the ground and under the belly, the top one over the spine.
	var geometry := Sim.geometry_of(Sim.Kind.FIGHTER)
	var tips: Array[Vector3] = VehicleLights.published_wingtips(Sim.Kind.FIGHTER, geometry)
	var rails: Array[AABB] = [frame.surfaces.get("LauncherRailPort", AABB()), frame.surfaces.get("LauncherRailStarboard", AABB())]
	var off_rail: Array[String] = []
	for index in range(2):
		var tip: Vector3 = tips[index] if tips.size() == 2 else Vector3.ZERO
		var rail: AABB = rails[index]
		var face: float = rail.position.x if index == 0 else rail.end.x
		if absf(absf(tip.x) - absf(face)) > 0.10 or tip.z < rail.position.z or tip.z > rail.end.z \
				or absf(tip.y - rail.get_center().y) > 0.15:
			off_rail.append("%s tip %s against a rail %s" % ["port" if index == 0 else "starboard", tip, rail])
	var lamps: Array[Dictionary] = VehicleLights.lamps_from(VehicleLights.published(Sim.Kind.FIGHTER, geometry))
	var lowest_lamp := INF
	var highest_lamp := -INF
	for lamp in lamps:
		lowest_lamp = minf(lowest_lamp, (lamp["position"] as Vector3).y)
		highest_lamp = maxf(highest_lamp, (lamp["position"] as Vector3).y)
	_check("and_its_lights_and_contrails_stand_on_the_drawn_wingtips_and_skin",
		off_rail.is_empty() and lowest_lamp > -rest + 0.5 and highest_lamp < bounds.end.y,
		"; ".join(off_rail) if not off_rail.is_empty() else "tips %s on the rails; lamps from %.2f to %.2f m over the ground, the fins' tops at %.2f"
			% [tips, lowest_lamp + rest, highest_lamp + rest, bounds.end.y + rest])
	view.queue_free()


## THE LOWEST DRAWN SKIN on a vertical line through (x, z), or INF where no triangle of it crosses the line.
func _underside_at(skin: PackedVector3Array, x: float, z: float) -> float:
	var lowest: float = INF
	var from := Vector3(x, -50.0, z)
	var to := Vector3(x, 50.0, z)
	for i in range(0, skin.size() - 2, 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(from, to, skin[i], skin[i + 1], skin[i + 2])
		if hit != null:
			lowest = minf(lowest, (hit as Vector3).y)
	return lowest


## THE SUPER HORNET'S LEX HALF-WIDTH `forward` metres ahead of its root leading edge: the legacy edge scaled x1.118.
func _reference_lex(forward: float) -> float:
	var legacy: float = forward / WING_SCALE
	for i in range(HARV_LEX.size() - 1):
		var a: Array = HARV_LEX[i]
		var b: Array = HARV_LEX[i + 1]
		if legacy <= float(b[0]) or i == HARV_LEX.size() - 2:
			var t: float = clampf((legacy - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
			return WING_SCALE * lerpf(float(a[1]), float(b[1]), t)
	return 0.0


## THE MIDDLE OF A GEAR PART'S GROUND CONTACT, along the aircraft: the mean station of its vertices within 3 cm of the ground.
func _contact_z(frame: Node3D, part: String, rest: float) -> float:
	var sum := 0.0
	var count := 0
	for p in _vertices_in(frame, frame.find_child(part, true, false) as MeshInstance3D):
		if p.y < -rest + 0.03:
			sum += p.z
			count += 1
	return sum / maxf(float(count), 1.0)


## WHERE A PARKED FIGHTER'S ORIGIN RESTS over flat ground, asked of the simulation rather than read off its hull.
func _parked_rest_height() -> float:
	var world := _world(0)
	world.add_static_box(Vector3(0.0, -5.0, 0.0), Vector3(2000.0, 5.0, 2000.0))
	var e: Vector3 = Sim.geometry_of(Sim.Kind.FIGHTER).get("extents", Vector3.ONE)
	var parked: int = int(world.spawn_vehicle(Sim.Kind.FIGHTER, Vector3(0.0, e.y + 0.3, 0.0), 0.0, Vector3.ZERO))
	for i in range(600):
		world.tick(DT)
	var rest: float = (world.vehicle_state(parked).get("position", Vector3.ZERO) as Vector3).y
	_let_go(world)
	return rest


func _vertices_in(root: Node3D, drawn: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	if drawn == null or drawn.mesh == null:
		return out
	var into := Transform3D.IDENTITY
	var cursor: Node3D = drawn
	while cursor != root and cursor != null:
		into = cursor.transform * into
		cursor = cursor.get_parent() as Node3D
	for surface in range(drawn.mesh.get_surface_count()):
		for point in (drawn.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			out.append(into * point)
	return out


func _mean_between(points: PackedVector3Array, low: float, high: float) -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for p in points:
		if p.y >= low and p.y <= high:
			sum += p
			count += 1
	return sum / maxf(float(count), 1.0)


## The widest drawn point within a hand's width of a station, between two heights over the ground.
func _widest_near(points: PackedVector3Array, station: float, low: float, high: float, rest: float) -> float:
	var z: float = station - FighterAirframe.LENGTH * 0.5
	var widest := 0.0
	for p in points:
		if absf(p.z - z) < 0.05 and p.y + rest >= low and p.y + rest <= high:
			widest = maxf(widest, absf(p.x))
	return widest


func _lowest(points: PackedVector3Array) -> Vector3:
	var lowest := Vector3(0.0, INF, 0.0)
	for p in points:
		if p.y < lowest.y:
			lowest = p
	return lowest


func _the_asset_boundary_and_builder_inspector_are_independent_of_simulation() -> void:
	var geometry := Sim.geometry_of(Sim.Kind.FIGHTER)
	var before := geometry.duplicate(true)
	var definition := ModelAssetDefinition.definition_for(Sim.Kind.FIGHTER)
	var wrong_units := definition.duplicate(true); wrong_units["units"] = "centimetres"
	var wrong_axes := definition.duplicate(true); wrong_axes["forward_axis"] = "+Z"
	var made := ModelAssetDefinition.instantiate_for(Sim.Kind.FIGHTER, geometry)
	var node := made.get("node") as Node3D
	var view := (load("res://objects/vehicles/craft_fighter.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view); view.preview_kind = Sim.Kind.FIGHTER; view._show_in_editor()
	var inspector := ModelInspector.new(); add_child(inspector); inspector.inspect(view)
	var markers := inspector.overlays.find_children("Seat*Eye", "MeshInstance3D", true, false).size()
	var socket_markers := inspector.overlays.find_children("Socket_*", "MeshInstance3D", true, false).size()
	inspector.show_exterior(false); inspector.show_interior(true); inspector.show_overlays(false)
	var layers_ok := not (view._visual_scene.get_node("Exterior") as Node3D).visible \
		and (view._visual_scene.get_node("Interior") as Node3D).visible and not inspector.overlays.visible
	var frame := view._visual_scene as FighterAirframe
	var drawn: Dictionary = frame.sockets() if frame != null else {}
	var declared: Dictionary = definition.get("sockets", {})
	var parted: Array[String] = []
	for socket in drawn:
		var want := ModelAssetDefinition._vector(drawn[socket])
		if not declared.has(socket) or not ModelAssetDefinition._vector(declared[socket]).is_equal_approx(want):
			parted.append("%s: package %s, airframe %s" % [socket, declared.get(socket), want])
	_check("and_the_packages_sockets_are_the_airframes_own_axles_hook_and_pylons",
		not drawn.is_empty() and parted.is_empty() and declared.size() == drawn.size(),
		"; ".join(parted) if not parted.is_empty() else "%d sockets agree" % drawn.size())
	_check("the_versioned_scene_loads_with_axes_dimensions_sockets_and_builder_layer_toggles",
		not definition.has("error") and ModelAssetDefinition.validate(wrong_units) != ""
			and ModelAssetDefinition.validate(wrong_axes) != "" and node != null
			and markers == 2 and socket_markers == 6 and layers_ok,
		"scene %s, seats %d, sockets %d, toggles %s" % [node != null, markers, socket_markers, layers_ok])
	_check("and_loading_the_visual_cannot_change_native_geometry_or_station_poses",
		before == Sim.geometry_of(Sim.Kind.FIGHTER),
		"native contract unchanged")
	if node != null: node.free()
	inspector.queue_free(); view.queue_free()
	# THE TANKER, which has no visual scene: the Cessna was the example until it got one (lane/skyhawk, 2026-09-17).
	var fallback := (load("res://objects/vehicles/craft_tanker.tscn") as PackedScene).instantiate() as VehicleView
	add_child(fallback); fallback.preview_kind = Sim.Kind.TANKER; fallback._show_in_editor()
	_check("and_a_craft_without_an_optional_visual_keeps_its_procedural_body",
		fallback._visual_scene == null and fallback.get_node_or_null("Body") != null,
		"visual %s, body %s" % [fallback._visual_scene, fallback.get_node_or_null("Body")])
	fallback.queue_free()


## A CRAFT DRAWN THROUGH ITS VISUAL SCENE KEEPS WHAT IS FITTED TO IT: for every kind whose package declares a `visual`,
## built as the level builds a view (vehicle_view.tscn, `setup`), the airframe scene, the lights and every gun or turret
## are drawn, and the procedural body the scene replaces -- the hull, the planks, the end markers -- is not. The install
## used to hide the whole `Body` node, and `_finish_setup` had already gathered the lights and the guns into it: the
## fighter's nav lights stood on the drawn rails and nothing drew them (found by lane/skyhawk).
func _a_craft_drawn_through_its_visual_scene_keeps_its_lights_and_guns() -> void:
	var wrong: Array[String] = []
	var looked: Array[String] = []
	for kind in range(Sim.Kind.size()):
		var definition: Dictionary = ModelAssetDefinition.definition_for(kind)
		if definition.is_empty() or definition.has("error"):
			continue
		var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
		add_child(view)
		view.setup(0, kind)
		looked.append(Sim.kind_name(kind))
		if view._visual_scene == null or not view._visual_scene.is_visible_in_tree():
			wrong.append("%s: its visual scene is not drawn" % Sim.kind_name(kind))
		var lights := view.find_child("Lights", true, false) as Node3D
		if VehicleLights.carries_lights(kind) \
				and (lights == null or not lights.is_visible_in_tree()):
			wrong.append("%s: its lights are not drawn (%s)" % [Sim.kind_name(kind), "missing" if lights == null
				else "under %s" % lights.get_parent().name])
		for fitted in view.find_children("Turret*", "Node3D", true, false) + view.find_children("NoseGun", "Node3D", true, false):
			if not (fitted as Node3D).is_visible_in_tree():
				wrong.append("%s: %s is not drawn" % [Sim.kind_name(kind), fitted.name])
		# AND STILL AFTER A CREW BOARDS AND LEAVES: ghosting repaints and re-shows the body meshes.
		for ghosted in [false, true, false]:
			view._show_body(ghosted)
			for skin in view._procedural_airframe():
				if skin.is_visible_in_tree():
					wrong.append("%s: the procedural %s is drawn under the visual scene (ghosted %s)"
						% [Sim.kind_name(kind), skin.name, ghosted])
		view.queue_free()
	_check("a_craft_drawn_through_its_visual_scene_keeps_its_lights_and_guns", wrong.is_empty() and not looked.is_empty(),
		"; ".join(wrong) if not wrong.is_empty() else "%s: scene, lights and guns drawn, procedural body hidden" % ", ".join(looked))


func _the_exterior_meets_the_first_lod_budget() -> void:
	var made := ModelAssetDefinition.instantiate_for(Sim.Kind.FIGHTER, Sim.geometry_of(Sim.Kind.FIGHTER))
	var root := made.get("node") as Node3D
	var exterior := root.get_node("Exterior") as Node3D if root != null else null
	var draws := 0
	var triangles := 0
	var materials: Dictionary = {}
	var ranged := 0
	if exterior != null:
		for child in exterior.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := child as MeshInstance3D; draws += mesh_node.mesh.get_surface_count()
			if mesh_node.visibility_range_end > 0.0: ranged += 1
			materials[mesh_node.material_override] = true
			for surface in range(mesh_node.mesh.get_surface_count()):
				var arrays := mesh_node.mesh.surface_get_arrays(surface)
				var index_value: Variant = arrays[Mesh.ARRAY_INDEX]
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var points := (index_value as PackedInt32Array).size() \
					if index_value is PackedInt32Array else vertices.size()
				triangles += points / 3
	_check("the_first_exterior_lod_stays_inside_the_measured_vr_asset_budget",
		draws <= 20 and triangles <= 100000 and materials.size() <= 12 and ranged >= 8,
		"%d draws, %d triangles, %d materials, %d distance-culled fittings" % [draws, triangles, materials.size(), ranged])
	if root != null: root.free()


func _the_cockpit_package_loads_every_station() -> void:
	var package: Dictionary = AuthoredCraftPackages.read(Sim.Kind.FIGHTER)
	var wrong: Array[String] = []
	for seat in range(2):
		var built: Dictionary = AuthoredCraftPackages.make_station(Sim.Kind.FIGHTER, seat)
		if built.has("error"):
			wrong.append("seat %d: %s" % [seat, built["error"]])
			continue
		var station := built["station"] as CockpitStation
		if station == null or station.controls().is_empty():
			wrong.append("seat %d has no devices" % seat)
		if station != null:
			station.free()
	_check("the_versioned_builder_package_and_both_stations_load_from_json",
		not package.has("error") and wrong.is_empty(),
		String(package.get("error", "two stations")) if wrong.is_empty() else "; ".join(wrong))


## THE SEATS SIT WHERE THE REAL CREW'S EYES ARE, and the canopy is drawn round those points. A seat is EYE_HEIGHT under
## its occupant's eyes and a parked fighter's origin rests `rest` over the ground, so this is the whole of the migration's
## claim: eye = seat + 1.35 - rest, against the photograph's 3.05 and 3.18 m.
func _the_seats_put_both_crews_eyes_where_the_photograph_has_them() -> void:
	var rest := _parked_rest_height()
	var poses: Array = Sim.geometry_of(Sim.Kind.FIGHTER).get("seat_poses", [])
	var wanted: Array[Vector2] = [Vector2(FighterAirframe.PILOT_EYE_STATION, FighterAirframe.PILOT_EYE_HEIGHT),
		Vector2(FighterAirframe.WSO_EYE_STATION, FighterAirframe.WSO_EYE_HEIGHT)]
	var said: Array[String] = []
	var right := poses.size() == 2
	for seat in range(mini(poses.size(), 2)):
		var at: Vector3 = (poses[seat] as Dictionary).get("position", Vector3.ZERO)
		var eye_height: float = at.y + CockpitStation.EYE_HEIGHT + rest
		var eye_station: float = at.z + FighterAirframe.LENGTH * 0.5
		right = right and absf(eye_height - wanted[seat].y) < 0.03 and absf(eye_station - wanted[seat].x) < 0.03
		said.append("seat %d: eye %.2f m up at %.2f m aft, reference %.2f / %.2f" % [seat, eye_height, eye_station,
			wanted[seat].y, wanted[seat].x])
	_check("the_seats_put_both_crews_eyes_where_the_photograph_has_them", right, "; ".join(said))


## THE HOOK CHANNEL IS PHYSICAL, on the four carrier aeroplanes -- the E-2D, F/A-18F, F-14D and EA-6B -- and on
## nothing else, and a flying seat's command sets the
## bit the drawing reads. The channel sits at 15, above the system half, so "physical" has to be a predicate rather than
## "below eight": before that change the command would have gone to the crew's switches and never reached the craft.
func _the_hook_is_a_physical_channel_on_the_carrier_aeroplanes() -> void:
	var fitted: Array[String] = []
	var wrong: Array[String] = []
	for kind in range(Sim.Kind.size()):
		for entry in (Sim.schema_of(kind).get("channels", []) as Array):
			var row: Dictionary = entry
			if int(row.get("channel", -1)) != Sim.Channel.HOOK:
				continue
			fitted.append(Sim.kind_name(kind))
			if not bool(row.get("physical", false)) or int(row.get("range", 0)) != 1:
				wrong.append("%s: physical %s, range %d" % [Sim.kind_name(kind), row.get("physical"), int(row.get("range", 0))])
	_check("the_hook_channel_is_physical_and_fitted_to_the_carrier_aeroplanes",
		fitted.has("fighter") and fitted.has("hawkeye") and fitted.has("tomcat") and fitted.has("prowler")
			and fitted.size() == 4 and wrong.is_empty(),
		"fitted to %s%s" % [", ".join(fitted), "" if wrong.is_empty() else "; wrong: " + "; ".join(wrong)])

	# THE COMMAND, from a flying seat, on the ground and in the air alike: a hook has no squat switch.
	var world := _world(0)
	world.add_static_box(Vector3(0.0, -5.0, 0.0), Vector3(2000.0, 5.0, 2000.0))
	var e: Vector3 = Sim.geometry_of(Sim.Kind.FIGHTER).get("extents", Vector3.ONE)
	var parked: int = int(world.spawn_vehicle(Sim.Kind.FIGHTER, Vector3(0.0, e.y + 0.3, 0.0), 0.0, Vector3.ZERO))
	var made: Dictionary = world.spawn_pilot(51, Sim.Kind.POD, Vector3(900.0, 40.0, 0.0), 0.0, Vector3.ZERO)
	var pilot: int = int(made.get("pilot", 0))
	var flown: Dictionary = world.spawn_pilot(52, Sim.Kind.FIGHTER, Vector3(0.0, 1500.0, 0.0), 0.0, Vector3(0.0, 0.0, -110.0))
	var flying: int = int(flown.get("vehicle", 0))
	var wso_seated: bool = bool(world.seat_client(51, flying, 1))
	for i in range(30):
		world.tick(DT)
	# The WSO's seat does not fly, so its ask is refused: the hook is the craft's, not a passenger's.
	world.set_pilot_input(pilot, _controls({"command_channel": Sim.Channel.HOOK, "command_value": 1, "command_seq": 1}))
	for i in range(30):
		world.tick(DT)
	var refused: Dictionary = world.craft_controls(flying)
	# And the pilot of the parked one, on its wheels, is not refused. (Taking the seat launches it -- see
	# `launch_if_grounded` -- so the command goes in first, while the wheels are still on the ground.)
	var deck_made: Dictionary = world.spawn_pilot(53, Sim.Kind.POD, Vector3(-900.0, 40.0, 0.0), 0.0, Vector3.ZERO)
	var seated: bool = bool(world.seat_client(53, parked, 0))
	var deck_pilot: int = int(deck_made.get("pilot", 0))
	world.set_pilot_input(deck_pilot, _controls({"command_channel": Sim.Channel.HOOK, "command_value": 1, "command_seq": 1}))
	for i in range(30):
		world.tick(DT)
	var down: Dictionary = world.craft_controls(parked)
	world.set_pilot_input(deck_pilot, _controls({"command_channel": Sim.Channel.HOOK, "command_value": 0, "command_seq": 2}))
	for i in range(30):
		world.tick(DT)
	var up: Dictionary = world.craft_controls(parked)
	_check("and_a_flying_seats_hook_command_sets_switches_bit_four_on_the_ground_too",
		wso_seated and seated and not bool(refused.get("hook", true)) and bool(down.get("hook", false))
			and (int(down.get("switches", 0)) & 16) == 16 and not bool(up.get("hook", true))
			and bool(down.get("gear", false)),
		"from the WSO's seat: %s (refused); from the pilot's seat on the deck: hook %s, switches %d, then %s; its gear stayed %s"
			% [refused.get("hook"), down.get("hook"), int(down.get("switches", 0)), up.get("hook"), down.get("gear")])
	_let_go(world)


func _the_pilot_can_launch_a_parked_fighter() -> void:
	var world := _world(0)
	world.add_static_box(Vector3(0.0, -5.0, 0.0), Vector3(2000.0, 5.0, 2000.0))
	var e: Vector3 = Sim.geometry_of(Sim.Kind.FIGHTER).get("extents", Vector3.ONE)
	var parked: int = int(world.spawn_vehicle(Sim.Kind.FIGHTER, Vector3(0.0, e.y + 0.3, 0.0),
		0.0, Vector3.ZERO))
	var made: Dictionary = world.spawn_pilot(39, Sim.Kind.POD, Vector3(500.0, 100.0, 0.0),
		0.0, Vector3.ZERO)
	var seated: bool = bool(world.seat_client(39, parked, 0))
	for i in range(20):
		world.tick(DT)
	var state: Dictionary = world.vehicle_state(parked)
	_check("taking_the_pilot_seat_launches_the_parked_fighter_in_a_flyable_state",
		seated and (state.get("position", Vector3.ZERO) as Vector3).y > 100.0
			and (state.get("velocity", Vector3.ZERO) as Vector3).length() > 35.0,
		"seated %s, altitude %.1f m, speed %.1f m/s, pilot %s" % [seated,
			(state.get("position", Vector3.ZERO) as Vector3).y,
			(state.get("velocity", Vector3.ZERO) as Vector3).length(), made.get("pilot")])
	_let_go(world)


func _the_aircraft_answers_both_flight_decks_controls() -> void:
	var world := _world(0)
	var made: Dictionary = world.spawn_pilot(40, Sim.Kind.FIGHTER, Vector3(0.0, 1800.0, 0.0),
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
	var wso_made: Dictionary = world.spawn_pilot(41, Sim.Kind.POD, Vector3(300.0, 500.0, 0.0), 0.0, Vector3.ZERO)
	var wso_ok: bool = bool(world.seat_client(41, craft, 1))
	for i in range(120):
		world.set_pilot_input(pilot, _controls({"throttle": 0.78, "rudder": 1.0}))
		world.tick(DT)
	var later_spin: float = (world.vehicle_state(craft).get("spin", Vector3.ZERO) as Vector3).length()
	var finite: bool = _finite_state(world.vehicle_state(craft))
	_check("the_pilot_flies_while_the_wso_occupies_the_tandem_operator_station",
		pilot_spin > 0.12 and wso_ok and later_spin > 0.08 and finite,
		"pilot %.3f rad/s, WSO %s/%s, later %.3f, finite %s" % [pilot_spin, wso_ok,
			wso_made.get("pilot"), later_spin, finite])
	_let_go(world)


func _the_network_can_select_and_fly_it() -> void:
	var server := _world(0)
	var client := _world(1)
	server.add_issue_place(Sim.Kind.FIGHTER, Vector3(500.0, 1200.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -105.0))
	for i in range(90):
		_step_pair(server, client)
	server.spawn_pilot(1, Sim.Kind.POD, Vector3(0.0, 500.0, 0.0), 0.0, Vector3.ZERO)
	for i in range(180):
		_step_pair(server, client)
	client.set_input(_controls({"buttons": Sim.BUTTON_KIND, "kind_wanted": Sim.Kind.FIGHTER,
		"menu_request": 1}))
	_step_pair(server, client)
	client.set_input(_controls({"kind_wanted": Sim.NO_KIND, "menu_request": 1}))
	var chosen: int = 0
	for i in range(600):
		client.set_input(_controls({"throttle": 0.8, "pitch": 0.75, "menu_request": 1}))
		_step_pair(server, client)
		for state in server.vehicle_states():
			if int((state as Dictionary).get("kind", -1)) == Sim.Kind.FIGHTER:
				chosen = int((state as Dictionary).get("entity", 0))
	var server_state: Dictionary = server.vehicle_state(chosen)
	var client_has: bool = false
	for state in client.vehicle_states():
		client_has = client_has or int((state as Dictionary).get("kind", -1)) == Sim.Kind.FIGHTER
	_check("a_client_can_select_the_fighter_and_its_controls_reach_the_server",
		chosen > 0 and client_has and (server_state.get("velocity", Vector3.ZERO) as Vector3).length() > 20.0
			and (server_state.get("spin", Vector3.ZERO) as Vector3).length() > 0.05,
		"entity %d, client sees it %s, speed %.1f, spin %.3f" % [chosen, client_has,
			(server_state.get("velocity", Vector3.ZERO) as Vector3).length(),
			(server_state.get("spin", Vector3.ZERO) as Vector3).length()])
	_let_go(server)
	_let_go(client)


## THE DRAWN GEAR FOLLOWS THE BUS, IN A LIVE SESSION: a solo Sim, two fighters the server issues -- one parked, one in the
## air -- each drawn by the level's own VehicleView, and a crew member in the flying one's seat sending the gear command.
## The bit is the server's, and the drawing is handed it straight, 1 or 0: how long the gear takes will be the
## simulation's (actuators_research.md 3.8), so this machine keeps no clock of its own for it.
func _the_drawn_gear_follows_the_bus_in_a_live_session() -> void:
	var waiting: Array = [not Sim.is_ready]
	if bool(waiting[0]):
		Sim.sim_ready.connect(func() -> void: waiting[0] = false, CONNECT_ONE_SHOT)
	Net.play_solo()
	Sim.start()
	for i in range(600):
		if not bool(waiting[0]):
			break
		await get_tree().physics_frame
	Sim.add_static_box(Vector3(0.0, -5.0, 0.0), Vector3(4000.0, 5.0, 4000.0))
	var e: Vector3 = Sim.geometry_of(Sim.Kind.FIGHTER).get("extents", Vector3.ONE)
	var parked_server: int = Sim.spawn_vehicle(Sim.Kind.FIGHTER, Vector3(0.0, e.y + 0.3, 0.0), 0.0)
	var flying_server: int = Sim.spawn_vehicle(Sim.Kind.FIGHTER, Vector3(2500.0, 1500.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -120.0))
	# A SPAWN'S ID IS THE SERVER'S; THE LEVEL DRAWS THE CLIENT'S. Found by kind and height in what this machine has.
	var parked_client: int = 0
	var flying_client: int = 0
	for i in range(240):
		await get_tree().physics_frame
		for entity in Sim.current:
			var state: Dictionary = Sim.current[entity]
			if int(state.get("kind", -1)) != Sim.Kind.FIGHTER:
				continue
			if (state.get("position", Vector3.ZERO) as Vector3).y > 500.0:
				flying_client = int(entity)
			else:
				parked_client = int(entity)
		if parked_client > 0 and flying_client > 0:
			break
	if parked_client == 0 or flying_client == 0:
		_check("a_live_session_draws_both_fighters", false, "parked %d, flying %d" % [parked_client, flying_client])
		Sim.stop()
		return
	var parked := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	var flying := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	add_child(parked)
	parked.setup(parked_client, Sim.Kind.FIGHTER)
	add_child(flying)
	flying.setup(flying_client, Sim.Kind.FIGHTER)
	_check("a_fighter_is_drawn_with_its_gear_where_the_bus_has_it_from_its_first_frame",
		parked._fighter != null and flying._fighter != null and parked._fighter.gear_amount() == 1.0
			and flying._fighter.gear_amount() == 0.0,
		"parked: bus gear %s, drawn %.2f; in the air: bus gear %s, drawn %.2f" % [
			Sim.client.craft_controls(parked_client).get("gear"), parked._fighter.gear_amount() if parked._fighter else -1.0,
			Sim.client.craft_controls(flying_client).get("gear"), flying._fighter.gear_amount() if flying._fighter else -1.0])

	# A CREW MEMBER IN THE FLYING ONE'S SEAT PUTS THE GEAR DOWN, through the command bus as a hand on the handle does.
	var who: int = 211
	var made: Dictionary = Sim.server.spawn_pilot(who, Sim.Kind.POD, Vector3(-3000.0, 40.0, 3000.0), 0.0, Vector3.ZERO)
	var seated: bool = bool(Sim.server.seat_client(who, flying_server, 0))
	var pilot: int = int(made.get("pilot", 0))
	var down := _controls({"throttle": 0.8, "command_channel": Sim.Channel.GEAR, "command_value": 1, "command_seq": 1})
	# EVERY DRAWN FRAME, the drawing must agree with the bus this machine holds, never lead it and never trail it.
	var disagreed: int = 0
	var frames: int = 0
	var bus_down: bool = false
	for i in range(240):
		Sim.server.set_pilot_input(pilot, down)
		await get_tree().process_frame
		parked.draw()
		flying.draw()
		var bit: bool = bool(Sim.client.craft_controls(flying_client).get("gear", false))
		bus_down = bus_down or bit
		frames += 1
		if flying._fighter.gear_amount() != (1.0 if bit else 0.0):
			disagreed += 1
	var legs: Basis = (flying._fighter.find_child("MainGearStarboard", true, false) as Node3D).basis
	_check("and_the_crews_gear_command_is_drawn_from_the_bus_on_every_frame",
		seated and bus_down and disagreed == 0 and flying._fighter.gear_amount() == 1.0
			and legs.is_equal_approx(Basis.IDENTITY) and parked._fighter.gear_amount() == 1.0,
		"seated %s, bus gear %s; the drawing disagreed with the bus on %d of %d frames; the main leg at its down pose %s"
			% [seated, bus_down, disagreed, frames, legs.is_equal_approx(Basis.IDENTITY)])
	parked.queue_free()
	flying.queue_free()
	Sim.server.despawn_pilot(pilot)
	Sim.stop()


## THE GEAR IS DRAWN FROM EACH MACHINE'S OWN BUS, ON THE FRAME THAT BUS CHANGES: a server and two client worlds over a
## loopback, the pilot's machine sending the gear command and a crew member's machine seated behind. Each machine's
## drawing is handed its own copy of the bus every tick, exactly as `VehicleView.draw` hands it, and must agree with it on
## every tick -- never a tick late and never part-way, because timed travel will be the simulation's, not a drawing's.
func _the_gear_is_drawn_from_each_machines_bus_on_the_frame_it_changes() -> void:
	var server := _world(0)
	var clients: Array = [_world(1), _world(2)]
	var made: Dictionary = server.spawn_pilot(1, Sim.Kind.FIGHTER, Vector3(0.0, 1800.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -110.0))
	var craft: int = int(made.get("vehicle", 0))
	server.spawn_pilot(2, Sim.Kind.POD, Vector3(3000.0, 600.0, 0.0), 0.0, Vector3.ZERO)
	var crew_seated: bool = bool(server.seat_client(2, craft, 1))
	var views: Array[VehicleView] = []
	for i in range(2):
		var view := (load("res://objects/vehicles/craft_fighter.tscn") as PackedScene).instantiate() as VehicleView
		add_child(view)
		view.preview_kind = Sim.Kind.FIGHTER
		view._show_in_editor()
		views.append(view)
	var flipped: Array[int] = [-1, -1]
	var disagreed: Array[int] = [0, 0]
	var seen: Array[int] = [0, 0]
	for tick in range(360):
		clients[0].set_input(_controls({"throttle": 0.8}))
		# THE PILOT'S MACHINE ASKS, once, as `Sim.send_command` does for a hand on the handle or the J key.
		if tick == 120:
			clients[0].send_command(Sim.Channel.GEAR, 1)
		clients[1].set_input(_controls())
		server.tick(DT)
		for client in clients:
			client.tick(DT)
		for packet in server.take_outbound():
			var to: int = int(packet["peer"]) - 1
			if to >= 0 and to < clients.size():
				clients[to].deliver(0, packet["bytes"], packet["bits"])
		for i in range(clients.size()):
			for packet in clients[i].take_outbound():
				server.deliver(i + 1, packet["bytes"], packet["bits"])
		for i in range(clients.size()):
			var entity: int = 0
			for state in clients[i].vehicle_states():
				if int((state as Dictionary).get("kind", -1)) == Sim.Kind.FIGHTER:
					entity = int((state as Dictionary).get("entity", 0))
			if entity == 0:
				continue
			var bus: Dictionary = clients[i].craft_controls(entity)
			if bus.is_empty():
				continue
			seen[i] += 1
			views[i]._draw_the_fighters_actuators(bus)
			var bit: bool = bool(bus.get("gear", false))
			if bit and flipped[i] < 0:
				flipped[i] = tick
			if views[i]._fighter == null or views[i]._fighter.gear_amount() != (1.0 if bit else 0.0):
				disagreed[i] += 1
	_check("the_gear_is_drawn_from_each_machines_bus_on_the_frame_it_changes",
		crew_seated and flipped[0] >= 120 and flipped[1] >= 120 and disagreed[0] == 0 and disagreed[1] == 0
			and seen[0] > 100 and seen[1] > 100,
		"crew seated %s; the pilot's machine: bus gear down at tick %d, drawing disagreed on %d of %d ticks; the crew's machine: down at tick %d, disagreed on %d of %d (command from tick 120)"
			% [crew_seated, flipped[0], disagreed[0], seen[0], flipped[1], disagreed[1], seen[1]])
	for view in views:
		view.queue_free()
	_let_go(server)
	for client in clients:
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
