extends Node
## Headless: IS THE GLIDER A DUO DISCUS? The airframe `SailplaneAirframe` draws, held to Schempp-Hirth's published figures
## and to itself, off the DRAWN vertices in the craft's frame.
##
## WHY THIS EXISTS. On 2026-09-18 the user asked for a better sailplane "like the photos on this page" -- Pajno's Rondine
## -- "a two seater as well, with joysticks in both, the seat is even more reclined than the f16". The DG-1001 it replaced
## was drawn by `VehicleView` from primitives and held by `tests/soaring.gd`, which this suite replaces and whose lessons
## it keeps: nothing anonymous (a stub gun once met the DG's published height), and a height carried by the part it names.
##
## THE REFERENCE IS TYPED HERE, not read from the airframe, so the two can disagree: the published envelope [SH 1.4.3]
## and a named-part roster. A check that asked `SailplaneAirframe.SPAN` how wide the drawn wing should be would pass for
## any wing at all.
##
## MUTANTS (run 2026-09-18 by a runner that asserts its anchor once, prints "applied" and restores the whole file; each
## red here on its own check):
##   the sailplane seat's recline typed as the F-16's 30 .......... the_sailplane_seat_reclines_further_than_the_f16s_...
##   an armrest added to every chair ............................. the_sailplane_seat_has_no_armrests

const GLIDER: int = 17
## [SH 1.4.3], the Duo Discus flight manual's technical data.
const SPAN: float = 20.00
const LENGTH: float = 8.62
const WING_AREA: float = 16.40
const FUSELAGE_WIDTH: float = 0.71
## THE OVERALL HEIGHT, 1.60 m (Wikipedia, "Schempp-Hirth Duo Discus", XL specifications; the flight manual gives the
## fuselage's 1.00 only). PARKED: on the main wheel and the tail wheel, which is how a height is measured on a hangar
## floor. The manual draws the aeroplane LEVEL, with the tail wheel 0.29 m off the ground, so a level box would read
## 1.91 at the tailplane's top -- and more at the winglets, whose wing on the ground rests on a tip.
const PARKED_HEIGHT: float = 1.60
## THE SEAT'S RECLINE, degrees aft of vertical: Technical Soaring Vol 19 No 2 p 52, a modern glider's seat back at 45
## (`PilotSeat`'s [TS19]); the F-16's ACES II is 30. Typed here, apart from `PilotSeat.PRESETS`.
const SEAT_RECLINE: float = 45.0
const F16_RECLINE: float = 30.0
## Every published dimension within this share. The drawn length is 8.605 m off the drawing at the span's scale.
const TOLERANCE: float = 0.02
## THE PARTS THAT MAKE IT RECOGNISABLY THIS AEROPLANE, counted by name.
const PARTS: Array[String] = ["Fuselage", "CanopyFrame", "WingPort", "WingStarboard", "WingletPort", "WingletStarboard",
	"AileronPort", "AileronStarboard", "AirbrakePort", "AirbrakeStarboard", "AirbrakePortLower", "AirbrakeStarboardLower",
	"Fin", "Rudder", "Tailplane", "Elevator", "MainWheel", "NoseWheel", "TailWheel"]

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[sailplane] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


const PEER_FRONT: int = 11
const PEER_BACK: int = 12
const POD: int = 9


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.setup(0, GLIDER)
	var airframe := view.find_child("Sailplane", true, false) as SailplaneAirframe
	_check("the_glider_is_drawn_by_the_duo_discus_airframe", airframe != null, "SailplaneAirframe under the view")
	if airframe == null:
		_finish()
		return
	var parts: Dictionary = _drawn_parts(view)
	_probe(parts)
	_it_is_the_published_size(parts)
	_every_part_is_named(view, parts)
	_every_face_is_wound_outwards(view)
	_the_wing_is_the_published_area(parts)
	_the_surfaces_move(airframe)
	_parked_it_is_the_published_height(parts)
	_the_native_box_is_hidden_and_the_budget_kept(view, parts)
	_the_seat_reclines_further_than_the_f16s_and_has_no_armrests()
	_the_surfaces_a_flight_model_would_read_are_a_sailplanes()
	_the_seats_are_where_the_airframe_puts_the_eyes(airframe)
	_every_seat_has_a_stick_pedals_and_an_airbrake()
	_everything_the_stations_draw_is_inside_the_pod()
	await _either_seat_flies_the_surfaces()
	_finish()


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)


## EVERY VISIBLE MESH'S VERTEX BOX IN THE CRAFT'S FRAME, printed before anything is judged: a probe before a picture.
func _probe(parts: Dictionary) -> void:
	var triangles: int = 0
	for name in parts:
		var box: AABB = _bounds_of(parts[name] as PackedVector3Array)
		triangles += (parts[name] as PackedVector3Array).size() / 3
		print("[sailplane] part %-24s x %+6.2f..%+6.2f  y %+6.2f..%+6.2f  z %+6.2f..%+6.2f  %d tris" % [name,
			box.position.x, box.end.x, box.position.y, box.end.y, box.position.z, box.end.z,
			(parts[name] as PackedVector3Array).size() / 3])
	print("[sailplane] %d triangles in %d visible meshes" % [triangles, parts.size()])


## SPAN AND LENGTH within 2 per cent of the published figures, and the pod no wider than the published fuselage plus
## that share; the span belongs to the winglets' outer faces and the length to the nose and the rudder.
func _it_is_the_published_size(parts: Dictionary) -> void:
	var whole: AABB = _merged(parts)
	_check("the_span_is_the_published_20_m", absf(whole.size.x - SPAN) <= SPAN * TOLERANCE,
		"drawn %.3f m against %.2f" % [whole.size.x, SPAN])
	_check("the_length_is_the_published_8_62_m", absf(whole.size.z - LENGTH) <= LENGTH * TOLERANCE,
		"drawn %.3f m against %.2f" % [whole.size.z, LENGTH])
	var pod: AABB = _bounds_of(parts.get("Fuselage", PackedVector3Array()) as PackedVector3Array)
	_check("the_pod_is_the_published_width", absf(pod.size.x - FUSELAGE_WIDTH) <= FUSELAGE_WIDTH * TOLERANCE * 2.0,
		"drawn %.3f m against %.2f" % [pod.size.x, FUSELAGE_WIDTH])


## EVERY PART THE ROSTER NAMES IS DRAWN, AND NO DRAWN PART IS ANONYMOUS: Godot renames a duplicate `@MeshInstance3D@N`.
func _every_part_is_named(view: VehicleView, parts: Dictionary) -> void:
	var missing: PackedStringArray = []
	for name in PARTS:
		if not parts.has(name) and view.find_child(name, true, false) == null:
			missing.append(name)
	var anonymous: PackedStringArray = []
	for name in parts:
		if String(name).begins_with("@"):
			anonymous.append(String(name))
	_check("every_named_part_is_drawn", missing.is_empty(), "missing %s" % [missing] if not missing.is_empty()
		else "%d named" % PARTS.size())
	_check("no_part_is_anonymous", anonymous.is_empty(), "%s" % [anonymous])


## NO FACE IS WOUND AGAINST ITS OWN NORMAL, which is how a face goes invisible (`tests/ship_models.gd`).
func _every_face_is_wound_outwards(view: VehicleView) -> void:
	var wrong: int = 0
	var total: int = 0
	var worst: String = ""
	for found in view.find_child("Sailplane", true, false).find_children("*", "MeshInstance3D", true, false):
		var mesh := (found as MeshInstance3D).mesh as ArrayMesh
		if mesh == null:
			continue
		for s in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(s)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count: int = indices.size() if not indices.is_empty() else points.size()
			for i in range(0, count - 2, 3):
				var a: int = indices[i] if not indices.is_empty() else i
				var b: int = indices[i + 1] if not indices.is_empty() else i + 1
				var c: int = indices[i + 2] if not indices.is_empty() else i + 2
				var face: Vector3 = (points[c] - points[a]).cross(points[b] - points[a])
				if face.length_squared() < 1e-12:
					continue
				total += 1
				if face.dot(normals[a]) <= 0.0:
					wrong += 1
					worst = String(found.name)
	_check("every_face_is_wound_outwards", wrong == 0 and total > 0,
		"%d of %d faces wound against their normal%s" % [wrong, total, "" if worst.is_empty() else ", e.g. " + worst])


## THE WING'S PLAN AREA, off the drawn wing panels' upper faces and the ailerons', against the published 16.40 m2 (the
## root chord carried to the centreline, as a reference area is). Airbrakes are slots, not area.
func _the_wing_is_the_published_area(parts: Dictionary) -> void:
	var area: float = 0.0
	for side in ["Port", "Starboard"]:
		for name in ["Wing" + side, "Aileron" + side]:
			area += _plan_area(parts.get(name, PackedVector3Array()) as PackedVector3Array)
	# From the centreline to the root: the drawn panel's root chord, carried in.
	var root_chord: float = SailplaneAirframe.wing_edges(SailplaneAirframe.WING_ROOT_OUT).y \
		- SailplaneAirframe.wing_edges(SailplaneAirframe.WING_ROOT_OUT).x
	area += 2.0 * SailplaneAirframe.WING_ROOT_OUT * root_chord
	_check("the_wing_is_the_published_area", absf(area - WING_AREA) <= WING_AREA * TOLERANCE,
		"drawn %.3f m2 against %.2f; chord scale %.4f off the drawing's %.2f" % [area, WING_AREA,
			SailplaneAirframe.chord_scale(), SailplaneAirframe.measured_area()])


## PARKED ON ITS TWO WHEELS, the tailplane stands at the published 1.60 m: the drawn level aeroplane is turned nose-up
## about the main wheel's contact until the tail wheel touches, and the highest point of the fin and tailplane is read
## off after. TWO DRAWN THINGS, THE WHEELS AND THE FIN, AGREEING WITH A PUBLISHED THIRD: none of the three set out to
## produce it (`modelling_here.md` section 3).
func _parked_it_is_the_published_height(parts: Dictionary) -> void:
	var main: AABB = _bounds_of(parts.get("MainWheel", PackedVector3Array()) as PackedVector3Array)
	var tail: AABB = _bounds_of(parts.get("TailWheel", PackedVector3Array()) as PackedVector3Array)
	var contact := Vector2(main.get_center().z, main.position.y)
	var touch := Vector2(tail.get_center().z, tail.position.y)
	# Tail DOWN: the angle that brings the tail wheel's bottom onto the main wheel's ground line.
	var tilt: float = atan2(touch.y - contact.y, touch.x - contact.x)
	var top: float = -INF
	var who: String = ""
	for name in ["Fin", "Rudder", "Tailplane", "Elevator"]:
		for p in (parts.get(name, PackedVector3Array()) as PackedVector3Array):
			var d := Vector2(p.z, p.y) - contact
			var parked: float = d.x * sin(-tilt) + d.y * cos(-tilt)
			if parked > top:
				top = parked
				who = name
	_check("parked_on_its_wheels_the_tail_stands_at_the_published_height",
		absf(top - PARKED_HEIGHT) <= PARKED_HEIGHT * TOLERANCE,
		"%.3f m to the top of the %s against %.2f, sitting %.2f degrees tail-down" % [top, who, PARKED_HEIGHT,
			rad_to_deg(tilt)])


## THE NATIVE COLLISION BOX IS NOT DRAWN, and the exterior keeps inside the first-LOD budget `aircraft_fidelity` holds
## every reference aircraft to: 100,000 triangles, 12 material slots, 40 draw calls.
func _the_native_box_is_hidden_and_the_budget_kept(view: VehicleView, parts: Dictionary) -> void:
	var hull := view.find_child("Hull", true, false) as MeshInstance3D
	_check("the_native_collision_box_is_not_drawn", hull != null and not hull.is_visible_in_tree(),
		"Hull hidden behind the airframe")
	var triangles: int = 0
	var draws: int = 0
	for found in view.find_child("Sailplane", true, false).find_children("*", "MeshInstance3D", true, false):
		var mesh := (found as MeshInstance3D).mesh
		if mesh == null:
			continue
		draws += mesh.get_surface_count()
		for s in range(mesh.get_surface_count()):
			triangles += mesh.surface_get_array_len(s) / 3
	_check("the_exterior_keeps_the_first_lod_budget", triangles <= 100000 and draws <= 40,
		"%d triangles in %d draw surfaces" % [triangles, draws])


## THE SIMULATION'S SEATS ARE WHERE THE AIRFRAME PUTS THE EYES: each seat's anchor `CockpitStation.EYE_HEIGHT` under the
## eye `SailplaneAirframe.crew_eyes` derives from the canopy, to a centimetre. The C++ table (`glider_shape`) is typed,
## as every shape is; this is what keeps it from drifting off the glass.
func _the_seats_are_where_the_airframe_puts_the_eyes(airframe: SailplaneAirframe) -> void:
	var poses: Array = Sim.geometry_of(GLIDER).get("seat_poses", []) as Array
	var eyes: Array = airframe.crew_eyes()
	var said: PackedStringArray = []
	var ok: bool = poses.size() == 2 and eyes.size() == 2
	for i in range(mini(poses.size(), eyes.size())):
		var eye: Vector3 = ((poses[i] as Dictionary).get("position", Vector3.ZERO) as Vector3) \
			+ Vector3.UP * CockpitStation.EYE_HEIGHT
		var off: float = eye.distance_to(eyes[i] as Vector3)
		ok = ok and off < 0.01 and bool((poses[i] as Dictionary).get("flies", false))
		said.append("seat %d eye %s, the canopy's %s, %.3f m apart, flies %s" % [i, eye, eyes[i], off,
			(poses[i] as Dictionary).get("flies", false)])
	var gap: float = absf(((poses[1] as Dictionary)["position"] as Vector3).z - ((poses[0] as Dictionary)["position"] as Vector3).z) \
		if poses.size() == 2 else 0.0
	_check("both_seats_are_under_the_canopy_where_the_airframe_puts_the_eyes", ok and gap > 0.8 and gap < 1.2,
		"%s; %.2f m apart in tandem" % ["; ".join(said), gap])


## EVERYTHING BOTH STATIONS DRAW IS INSIDE THE POD, asked of the airframe's own `encloses`: the same sections the pod is
## drawn from. A 0.71 m pod is narrower than anything the stations were first laid out for; the signal lamp's holster hung
## 0.45 m out through its side until this was asked (2026-09-19). Every drawn mesh of each station -- controls, screens,
## the crew board, the holstered lamp -- by its drawn box in the craft's frame, less the footwell's floor and bar, which
## `tests/shell_room.gd` holds.
func _everything_the_stations_draw_is_inside_the_pod() -> void:
	var view := (load("res://objects/vehicles/craft_glider.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var frame := view.find_child("Sailplane", true, false) as SailplaneAirframe
	var into: Transform3D = view.global_transform.affine_inverse()
	var out: PackedStringArray = []
	var held: int = 0
	for seat in range(view.seats.size()):
		var station: CockpitStation = view.station_for(seat)
		for found in station.find_children("*", "MeshInstance3D", true, false):
			var mesh := found as MeshInstance3D
			if mesh.mesh == null or not mesh.is_visible_in_tree() or mesh.get_parent() is CockpitShell:
				continue
			# A LABEL'S QUAD OR A BEAM'S GLARE is not a solid: a lamp's glare quad is 2 cm and drawn only when lit.
			if mesh.mesh.get_aabb().size.length() < 0.005:
				continue
			var local: Transform3D = into * mesh.global_transform
			var own: AABB = mesh.mesh.get_aabb()
			var box := AABB(local * own.get_endpoint(0), Vector3.ZERO)
			for corner in range(1, 8):
				box = box.expand(local * own.get_endpoint(corner))
			held += 1
			if not frame.encloses(box):
				var owner: Node = mesh
				while owner.get_parent() != station:
					owner = owner.get_parent()
				out.append("seat %d %s/%s %s" % [seat, owner.name, mesh.name, box])
	view.queue_free()
	_check("everything_both_stations_draw_is_inside_the_pod", out.is_empty() and held > 20,
		"%d parts inside" % held if out.is_empty() else "%d of %d outside: %s" % [out.size(), held, "; ".join(out)])


## BOTH SEATS HAVE A STICK, RUDDER PEDALS AND AN AIRBRAKE LEVER, as the game builds the stations for a manned craft.
func _every_seat_has_a_stick_pedals_and_an_airbrake() -> void:
	var view := (load("res://objects/vehicles/craft_glider.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var said: PackedStringArray = []
	var ok: bool = view.seats.size() == 2
	for seat in range(view.seats.size()):
		var anchor: Node3D = view.seat_anchor(seat)
		var stick := anchor.find_child("Stick", true, false) as FlightStick
		var pedals := anchor.find_child("Pedals", true, false) as RudderPedals
		var brakes := anchor.find_child("Airbrakes", true, false) as AirbrakeLever
		ok = ok and stick != null and pedals != null and brakes != null
		said.append("seat %d: stick %s, pedals %s, airbrakes %s" % [seat, stick != null, pedals != null, brakes != null])
	view.queue_free()
	_check("both_seats_have_a_stick_pedals_and_an_airbrake_lever", ok, "; ".join(said))


## EITHER SEAT FLIES IT, AND THE SURFACES SAY SO. A server and two client worlds on a one-tick wire: the front client
## spawned into the glider, the back one seated in its rear seat. Each in turn holds the stick right and back through
## its input frame -- the last thing a human touches -- while the other sits still, and what THAT client's world hands
## back as the linkage is drawn by a view: the ailerons and the elevator must turn. Nothing between the frame and the
## drawn hinges is called by this check.
func _either_seat_flies_the_surfaces() -> void:
	var server: Object = ClassDB.instantiate("CockpitWorld")
	var clients: Dictionary = {PEER_FRONT: ClassDB.instantiate("CockpitWorld"), PEER_BACK: ClassDB.instantiate("CockpitWorld")}
	server.set_tick_rate(120.0)
	server.start(0)
	for peer in clients:
		(clients[peer] as Object).set_tick_rate(120.0)
		(clients[peer] as Object).start(peer)
	var frames: Dictionary = {PEER_FRONT: {}, PEER_BACK: {}}
	_pump(server, clients, frames, 90)
	var front_id: int = int((clients[PEER_FRONT] as Object).local_client_id())
	var back_id: int = int((clients[PEER_BACK] as Object).local_client_id())
	var made: Dictionary = server.spawn_pilot(front_id, GLIDER, Vector3(0.0, 800.0, 0.0), 0.0, Vector3(0.0, 0.0, -28.0))
	var glider: int = int(made.get("vehicle", 0))
	server.spawn_pilot(back_id, POD, Vector3(300.0, 50.0, 300.0), 0.0, Vector3.ZERO)
	_pump(server, clients, frames, 30)
	var seated: bool = glider != 0 and bool(server.seat_client(back_id, glider, 1))
	_pump(server, clients, frames, 30)
	var view := (load("res://objects/vehicles/craft_glider.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var frame := view.find_child("Sailplane", true, false) as SailplaneAirframe
	var said: PackedStringArray = []
	var ok: bool = seated and frame != null
	for flyer in [PEER_FRONT, PEER_BACK]:
		for peer in frames:
			frames[peer] = {}
		frames[flyer] = {"roll": 1.0, "pitch": 1.0}
		_pump(server, clients, frames, 40)
		var world: Object = clients[flyer]
		var craft: int = 0
		for state in world.vehicle_states():
			if int((state as Dictionary).get("kind", -1)) == GLIDER:
				craft = int((state as Dictionary).get("entity", 0))
		var linkage: Dictionary = world.crew_controls(craft) if craft != 0 else {}
		view.draw_the_sailplane_from({}, linkage)
		var aileron: float = frame.deflection("AileronStarboard") if frame != null else 0.0
		var elevator: float = frame.deflection("Elevator") if frame != null else 0.0
		var here: bool = aileron > 0.15 and elevator > 0.15
		ok = ok and here
		said.append("%s seat: linkage %s -> aileron %.2f rad, elevator %.2f rad" % ["front" if flyer == PEER_FRONT else "back",
			linkage.get("linked_stick", "none"), aileron, elevator])
		view.draw_the_sailplane_from({}, {})
	for world in [server] + clients.values():
		(world as Object).teardown()
	view.queue_free()
	_check("either_seats_stick_moves_the_ailerons_and_the_elevator", ok,
		"back seat seated %s; %s" % [seated, "; ".join(said)])


## A ONE-TICK WIRE, as `many_seats`': each client's input frame, every world ticked, every packet delivered.
func _pump(server: Object, clients: Dictionary, frames: Dictionary, ticks: int) -> void:
	for i in range(ticks):
		for peer in clients:
			var frame: Dictionary = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
				"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
				"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
				"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
				"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0}
			frame.merge(frames.get(peer, {}) as Dictionary, true)
			(clients[peer] as Object).set_input(frame)
		server.tick(1.0 / 120.0)
		for peer in clients:
			(clients[peer] as Object).tick(1.0 / 120.0)
		for packet in server.take_outbound():
			var to: int = int(packet["peer"])
			if clients.has(to):
				(clients[to] as Object).deliver(0, packet["bytes"], packet["bits"])
		for peer in clients:
			for packet in (clients[peer] as Object).take_outbound():
				server.deliver(peer, packet["bytes"], packet["bits"])


## THE SURFACES A SURFACE-DRIVEN FLIGHT MODEL WOULD READ (`SailplaneAirframe.surfaces()`, from the drawn tables), printed
## and held to what sailplanes have: a tailplane volume S_t l_t / (S c) of 0.35 to 0.8 and a fin volume S_v l_v / (S b)
## of 0.015 to 0.05 (Thomas, Fundamentals of Sailplane Design: 0.4 to 0.6 and about 0.02 to 0.03 are typical). Numbers
## that another lane will build a flight model from are held here rather than typed there (2026-09-19; the flight-model
## work is paused, and these wait for it).
func _the_surfaces_a_flight_model_would_read_are_a_sailplanes() -> void:
	var s: Dictionary = SailplaneAirframe.surfaces()
	var tail_volume: float = float(s["tailplane_area"]) * float(s["tailplane_arm"]) / (WING_AREA * float(s["mac"]))
	var fin_volume: float = float(s["fin_area"]) * float(s["fin_arm"]) / (WING_AREA * SPAN)
	print("[sailplane] surfaces %s" % s)
	_check("the_surfaces_a_flight_model_would_read_are_a_sailplanes",
		tail_volume > 0.35 and tail_volume < 0.8 and fin_volume > 0.015 and fin_volume < 0.05,
		"tailplane %.2f m2 on a %.2f m arm, volume %.2f; fin and rudder %.2f m2 on %.2f m, volume %.3f; ailerons %.2f m2 each"
			% [s["tailplane_area"], s["tailplane_arm"], tail_volume, s["fin_area"], s["fin_arm"], fin_volume,
				s["aileron_area_each"]])


## THE SAILPLANE'S CHAIR, off its drawn back cushion: leaning further back than the F-16's measured the same way, at the
## source's 45 degrees, and with no face at elbow height beside the torso that an arm could rest on.
func _the_seat_reclines_further_than_the_f16s_and_has_no_armrests() -> void:
	var glider := PilotSeat.of("sailplane")
	var falcon := PilotSeat.of("aces2_f16")
	var lean: float = _lean(glider)
	var f16: float = _lean(falcon)
	_check("the_sailplane_seat_reclines_further_than_the_f16s_at_its_sources_angle",
		lean > f16 + 5.0 and absf(lean - SEAT_RECLINE) <= 2.0 and absf(f16 - F16_RECLINE) <= 2.0,
		"the sailplane's back leans %.1f degrees (source %.0f), the F-16's %.1f (source %.0f)" % [lean, SEAT_RECLINE, f16,
			F16_RECLINE])
	var arms: int = 0
	var which: Dictionary = {}
	var pan: float = float(PilotSeat.preset("sailplane")["pan_height"])
	var ranges: Dictionary = glider.get_meta("parts", {})
	for part in ranges:
		var points: PackedVector3Array = PilotSeat.part_triangles(glider, String(part))
		var box := _bounds_of(points)
		print("[sailplane] chair part %-12s x %+.2f..%+.2f  y %+.2f..%+.2f  z %+.2f..%+.2f" % [part, box.position.x,
			box.end.x, box.position.y, box.end.y, box.position.z, box.end.z])
	for part in ranges:
		var points: PackedVector3Array = PilotSeat.part_triangles(glider, String(part))
		for i in range(0, points.size() - 2, 3):
			var n: Vector3 = (points[i + 1] - points[i]).cross(points[i + 2] - points[i])
			if n.length_squared() < 1e-12:
				continue
			var c: Vector3 = (points[i] + points[i + 1] + points[i + 2]) / 3.0
		# An armrest: a level face 0.09 to 0.35 m over the pan (a seated elbow, ANSUR II; `tests/pilot_seat.gd`'s band),
		# outboard of a 0.24 m torso, ahead of the eye line.
			if absf(n.normalized().y) > 0.7 and c.y > pan + 0.09 and c.y < pan + 0.35 and absf(c.x) > 0.12 and c.z < 0.0:
				arms += 1
				which[part] = true
	_check("the_sailplane_seat_has_no_armrests", arms == 0, "%d level faces at elbow height beside the torso, ahead of the eye %s"
		% [arms, which.keys()])
	glider.free()
	falcon.free()


func _lean(seat: MeshInstance3D) -> float:
	var back: PackedVector3Array = PilotSeat.part_triangles(seat, "back")
	var best := Vector3.ZERO
	var biggest: float = 0.0
	for i in range(0, back.size() - 2, 3):
		var normal: Vector3 = (back[i + 1] - back[i]).cross(back[i + 2] - back[i])
		if normal.length_squared() < 1e-12:
			continue
		var area: float = normal.length()
		normal = normal.normalized()
		# The cushion's FACE is its largest side (`tests/pilot_seat.gd`: at 45 degrees its top points ahead as far).
		if normal.z > 0.0:
			normal = -normal
		if normal.z < -0.05 and area > biggest + 1e-6:
			biggest = area
			best = normal
	return rad_to_deg(atan2(best.y, -best.z))


## THE SURFACES TURN ON THEIR HINGES, the right way: stick right raises the starboard aileron, stick back raises the
## elevator's trailing edge, right rudder swings the rudder's trailing edge to starboard, the airbrakes rise out of the
## wing. Read off the drawn vertices of each surface's trailing edge, not off the hinge's angle.
func _the_surfaces_move(airframe: SailplaneAirframe) -> void:
	var before: Dictionary = _trailing(airframe)
	airframe.set_ailerons(1.0)
	airframe.set_elevator(1.0)
	airframe.set_rudder(1.0)
	airframe.set_airbrakes(1.0)
	var after: Dictionary = _trailing(airframe)
	airframe.set_ailerons(0.0)
	airframe.set_elevator(0.0)
	airframe.set_rudder(0.0)
	airframe.set_airbrakes(0.0)
	var moved: Dictionary = {}
	for name in before:
		moved[name] = (after[name] as Vector3) - (before[name] as Vector3)
	_check("stick_right_raises_the_starboard_aileron_and_lowers_the_port",
		(moved["AileronStarboard"] as Vector3).y > 0.03 and (moved["AileronPort"] as Vector3).y < -0.03,
		"trailing edges moved %+.3f and %+.3f m" % [(moved["AileronStarboard"] as Vector3).y, (moved["AileronPort"] as Vector3).y])
	_check("stick_back_raises_the_elevator", (moved["Elevator"] as Vector3).y > 0.03,
		"trailing edge moved %+.3f m" % (moved["Elevator"] as Vector3).y)
	_check("right_rudder_swings_the_rudder_to_starboard", (moved["Rudder"] as Vector3).x > 0.05,
		"trailing edge moved %+.3f m" % (moved["Rudder"] as Vector3).x)
	_check("the_airbrakes_rise_out_of_the_wing", (moved["AirbrakePort"] as Vector3).y > SailplaneAirframe.AIRBRAKE_RISE * 0.9,
		"paddle top moved %+.3f m" % (moved["AirbrakePort"] as Vector3).y)


## THE AFTMOST (or, for a paddle, the highest) DRAWN VERTEX OF EACH MOVING SURFACE, in the airframe's frame.
func _trailing(airframe: SailplaneAirframe) -> Dictionary:
	var out: Dictionary = {}
	for name in ["AileronPort", "AileronStarboard", "Elevator", "Rudder", "AirbrakePort"]:
		var mesh := airframe.find_child(name, true, false) as MeshInstance3D
		if mesh == null:
			out[name] = Vector3.ZERO
			continue
		var into: Transform3D = airframe.global_transform.affine_inverse() * mesh.global_transform
		var best := Vector3(0.0, -INF, -INF)
		var sum := Vector3.ZERO
		var count: int = 0
		var points: PackedVector3Array = mesh.mesh.get_faces()
		var far: float = -INF
		var high: float = -INF
		for p in points:
			far = maxf(far, (into * p).z)
			high = maxf(high, (into * p).y)
		for p in points:
			var q: Vector3 = into * p
			if name.begins_with("Airbrake") and q.y > high - 0.001:
				sum += q
				count += 1
			elif not name.begins_with("Airbrake") and q.z > far - 0.02:
				sum += q
				count += 1
		out[name] = sum / maxf(float(count), 1.0)
	return out


## ---- helpers --------------------------------------------------------------------------------------------------------

func _drawn_parts(view: VehicleView) -> Dictionary:
	var out: Dictionary = {}
	for found in view.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if part.mesh == null or not part.is_visible_in_tree():
			continue
		var into: Transform3D = view.global_transform.affine_inverse() * part.global_transform
		var here := PackedVector3Array()
		for at in part.mesh.get_faces():
			here.append(into * at)
		if not here.is_empty():
			out[part.name] = here
	return out


func _merged(parts: Dictionary) -> AABB:
	var all := PackedVector3Array()
	for name in parts:
		all.append_array(parts[name] as PackedVector3Array)
	return _bounds_of(all)


func _bounds_of(points: PackedVector3Array) -> AABB:
	if points.is_empty():
		return AABB()
	var box := AABB(points[0], Vector3.ZERO)
	for at in points:
		box = box.expand(at)
	return box


## THE PLAN AREA OF A PANEL: the upward-facing triangles projected onto the ground.
func _plan_area(points: PackedVector3Array) -> float:
	var area: float = 0.0
	for i in range(0, points.size() - 2, 3):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var c: Vector3 = points[i + 2]
		var n: Vector3 = (b - a).cross(c - a)
		if absf(n.y) < 1e-9:
			continue
		# get_faces() is in the mesh's winding; count every face whose normal points up, in either winding.
		var up: bool = ((c - a).cross(b - a)).y > 0.0
		if up:
			area += absf(n.y) * 0.5
	return area
