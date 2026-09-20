extends Node
## Headless contract for the EA-6B Prowler airframe: the published envelope, the raked ground a Prowler parks on, the
## folded width, the wing planform against the printed area, winding, and the budget. Read RESULT=.
##
## The authoritative envelope and crew layout now come from the native PROWLER kind. The procedural airframe consumes
## that geometry, while this suite independently measures its vertices and holds its crew roles and moving surfaces.
##
## THE ENVELOPE AS CONSTANTS AT THE TOP, so the reference is visible in one place. All of it is PRINTED on the NAVAIR
## Standard Aircraft Characteristics three-view of December 1971; `craft/prowler/sources.md` cites each one and
## `craft/prowler/measure_sac.py` re-derives every measured figure from the drawing without reading the write-up.
const LENGTH := 18.009      # 709 in, the length with the fuselage datum level, which is the frame the model is built in
const PARKED_LENGTH := 18.098  # 712.5 in, the same aeroplane measured along the ground it parks on
const SPAN := 16.154        # 636 in
const FOLDED := 7.595       # 299 in
const HEIGHT := 4.953       # 195 in, over the ground UNDER THE FIN, not in the level frame -- see the check
const WING_AREA := 49.14    # 528.9 sq ft, excluding fillets
const ASPECT_RATIO := 5.31
const TAILPLANE := 6.198    # 244 in
const TRACK := 3.315        # 130.5 in
const WHEELBASE := 5.235    # 206.11 in
const GEAR_RAKE_DEGREES := 5.81
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[prowler] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_the_native_kind_owns_the_envelope_and_four_crew_roles()
	var frame := ProwlerAirframe.new()
	add_child(frame)
	frame.dress()
	_the_drawn_aeroplane_is_the_published_length_and_span(frame)
	_the_printed_overall_height_is_measured_over_the_ground_it_parks_on(frame)
	_the_gear_is_raked_because_a_prowler_parks_nose_up(frame)
	_the_parked_length_is_the_other_printed_length(frame)
	_the_named_parts_that_make_it_a_prowler_are_drawn(frame)
	var assembled := _the_game_build_has_one_airframe_and_four_working_stations()
	_the_front_seats_have_a_clear_vr_head_box(assembled)
	_the_control_surfaces_follow_one_axis_at_a_time(frame)
	await _the_vat_draws_the_fold_and_three_axes_where_the_parts_are(frame)
	_the_wing_planform_reproduces_the_printed_area_and_aspect_ratio(frame)
	_the_folded_wings_are_the_printed_width_across(frame)
	_every_face_is_wound_outwards(frame)
	_the_exterior_meets_the_first_lod_budget(frame)
	assembled.queue_free()
	frame.queue_free()
	_finish()


## ONE OWNER for scale and stations: the native kind. Front-left and front-right can fly as the requested game
## concession; the two rear ECMO seats cannot. The real crew-role distinction is documented in sources.md.
func _the_native_kind_owns_the_envelope_and_four_crew_roles() -> void:
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.PROWLER)
	var half: Vector3 = geometry.get("extents", Vector3.ZERO)
	var seats: Array = geometry.get("seat_poses", [])
	var roles: Array = []
	for pose in seats:
		roles.append(bool((pose as Dictionary).get("flies", false)))
	_check("the_native_kind_owns_the_envelope_and_four_crew_roles",
		Sim.kind_name(Sim.Kind.PROWLER) == "prowler" and absf(half.z * 2.0 - LENGTH) < 0.01
			and absf(float(geometry.get("span", 0.0)) * 2.0 - SPAN) < 0.01 and roles == [true, true, false, false],
		"kind %s, %.3f m long x %.3f m span, flies %s" % [Sim.kind_name(Sim.Kind.PROWLER), half.z * 2.0,
			float(geometry.get("span", 0.0)) * 2.0, roles])


## THE DRAWN BOUNDS, from transformed vertices and never from `transform * mesh.get_aabb()`, which grows every time a
## part is turned: a box round a box read the folded Hawkeye 0.86 m too wide (`lane/fleet2`).
##
## NOTE WHAT IS NOT ASSERTED HERE: the drawn HEIGHT. In the level frame the aeroplane measures 6.28 m from its nose
## tyre to its fin tip, because the nose tyre hangs half a metre below the mains. The published 4.95 m is a height above
## the ground and belongs in the next check, against the ground.
func _the_drawn_aeroplane_is_the_published_length_and_span(frame: Node3D) -> void:
	var box := _drawn_bounds(frame)
	_check("the_drawn_aeroplane_is_the_published_length_and_span",
		absf(box.size.z - LENGTH) <= LENGTH * 0.02 and absf(box.size.x - SPAN) <= SPAN * 0.02,
		"drawn %.3f m long x %.3f m span, published %.3f x %.3f" % [box.size.z, box.size.x, LENGTH, SPAN])


## THE HEIGHT, ANCHORED TO THE GROUND RATHER THAN TO THE AEROPLANE. This is the check the whole file exists for.
##
## A Prowler parks nose-up 5.8 degrees, so "how high is the fin" has no answer in the craft's own level frame -- it
## depends entirely on what you measure from. Measured from the model's own origin, or from its lowest drawn point, or
## from its own bounding box, the answer is wrong and CONSISTENTLY wrong, which is exactly the failure
## `testing_godot_headless.md` calls "a check that shares its subject's frame of reference cannot catch the frame being
## wrong". The ground is the thing outside: the fin top is measured against `ground_at` THE FIN'S OWN STATION, which is
## how the drawing's 195 in is dimensioned and how a deck crew would measure it.
##
## AND THE GROUND COMES FROM THE DRAWN TYRES, not from the builder's `ground_at`. The first version of this check asked
## `ground_at` where the ground was, which is the builder's own function -- so it read 195 in back whatever the builder
## had done, and a mutant that levelled the gear entirely left it green. The ground is the line through the two tyre
## contacts. That is the aeroplane's own definition of the ground and it is the one thing here that is outside both.
func _the_printed_overall_height_is_measured_over_the_ground_it_parks_on(frame: Node3D) -> void:
	var box := _drawn_bounds(frame)
	var fin_station: float = (ProwlerAirframe.FIN_TIP.x + ProwlerAirframe.FIN_TIP.y) * 0.5
	# THE GROUND FROM THE DRAWN TYRES, not from `ground_at`. Asking the builder's own function where the ground is puts
	# this check back inside the frame it is supposed to be judging: it would then read 195 in back however the ground
	# was placed, including from the wrong end of a raked plane. The ground is the line through the two tyre contacts,
	# which is the only definition the aeroplane itself can be held to.
	var nose_contact: float = _lowest_under(frame, ProwlerAirframe.NOSE_GEAR_STATION)
	var main_contact: float = _lowest_under(frame, ProwlerAirframe.MAIN_GEAR_STATION)
	var per_inch: float = (main_contact - nose_contact) 		/ (ProwlerAirframe.MAIN_GEAR_STATION - ProwlerAirframe.NOSE_GEAR_STATION)
	var under_fin: float = nose_contact + per_inch * (fin_station - ProwlerAirframe.NOSE_GEAR_STATION)
	var over_ground: float = box.position.y + box.size.y - under_fin
	_check("the_printed_overall_height_is_measured_over_the_ground_it_parks_on",
		absf(over_ground - HEIGHT) <= HEIGHT * 0.02,
		"fin top %.3f m over the line through both drawn tyres at station %.0f, published %.3f m; in the level frame the model spans %.3f m"
			% [over_ground, fin_station, HEIGHT, box.size.y])


## THE RAKE ITSELF, asserted so nobody levels it later thinking they are fixing a bug. Every other airframe here puts
## its tyre bottoms on one datum and that is right for every other airframe here; it is wrong for this one, and a
## convention that is wrong for one aircraft gets "restored" by somebody who knows the convention and not the aeroplane.
##
## Measured from the DRAWN tyres, not from the constant: the constant is what the builder used, so a check that read it
## back would pass through any mistake in how the gear is placed.
func _the_gear_is_raked_because_a_prowler_parks_nose_up(frame: Node3D) -> void:
	var nose := _lowest_under(frame, ProwlerAirframe.NOSE_GEAR_STATION)
	var main := _lowest_under(frame, ProwlerAirframe.MAIN_GEAR_STATION)
	var drop: float = main - nose
	var wheelbase: float = (ProwlerAirframe.MAIN_GEAR_STATION - ProwlerAirframe.NOSE_GEAR_STATION) * ProwlerAirframe.IN
	var rake: float = rad_to_deg(atan(drop / wheelbase))
	_check("the_gear_is_raked_because_a_prowler_parks_nose_up",
		drop > 0.4 and absf(rake - GEAR_RAKE_DEGREES) < 0.4 and absf(wheelbase - WHEELBASE) < 0.05,
		"the nose tyre sits %.3f m below the mains over a %.3f m wheelbase, which is %.2f degrees nose-up (measured %.2f)"
			% [drop, wheelbase, rake, GEAR_RAKE_DEGREES])


## THE OTHER PRINTED LENGTH, which only exists because of the rake: 712.5 in is what a parked Prowler occupies along the
## deck, between two planes square to the ground through its nose and its tail. Reproducing BOTH printed lengths from
## one drawn aeroplane is what says the rake is real rather than a fudge that happens to make the fin come out right.
func _the_parked_length_is_the_other_printed_length(frame: Node3D) -> void:
	var box := _drawn_bounds(frame)
	var rake: float = atan(ProwlerAirframe.GEAR_RAKE)
	# Along the ground, which in this frame runs uphill towards the tail. The extent is taken over every drawn vertex,
	# not between two points the check chose: choosing the points is choosing the answer.
	var along := Vector3(0.0, sin(rake), cos(rake))
	var low: float = INF
	var high: float = -INF
	for child in frame.find_children("*", "MeshInstance3D", true, false):
		var drawn := child as MeshInstance3D
		if drawn.mesh == null:
			continue
		var into := frame.global_transform.affine_inverse() * drawn.global_transform
		for surface in range(drawn.mesh.get_surface_count()):
			for point in (drawn.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var d: float = (into * point).dot(along)
				low = minf(low, d)
				high = maxf(high, d)
	var parked: float = high - low
	_check("the_parked_length_is_the_other_printed_length",
		absf(parked - PARKED_LENGTH) <= PARKED_LENGTH * 0.02,
		"%.3f m along the ground it parks on, published %.3f m; level it measures %.3f m" % [parked, PARKED_LENGTH, box.size.z])


## THE SILHOUETTE CUES, counted by name. A Prowler is told from an A-6 by its fin-tip fairing and its long two-piece
## canopy, and from everything else by folding wings on a jet with no nacelles.
func _the_named_parts_that_make_it_a_prowler_are_drawn(frame: Node3D) -> void:
	var body := frame.get_node_or_null("Body") as MeshInstance3D
	var details := frame.get_node_or_null("Details") as MeshInstance3D
	var panels: int = 0
	for which in ["WingPort", "WingStarboard"]:
		var pivot := frame.get_node_or_null(which)
		if pivot != null and pivot.get_node_or_null("Panel") != null:
			panels += 1
	var named := ["CanopyGlass", "Alq99Centre", "Alq99Port", "Alq99Starboard", "AileronPort",
		"AileronStarboard", "StabilatorPort", "StabilatorStarboard", "RudderSurface"]
	var missing: PackedStringArray = []
	for part in named:
		if frame.find_child(part, true, false) == null:
			missing.append(part)
	_check("the_named_parts_that_make_it_a_prowler_are_drawn",
		body != null and body.mesh != null and details != null and details.mesh != null and panels == 2 and missing.is_empty(),
		"body %s, details %s, folding panels %d, missing %s" % [body != null, details != null, panels, missing])


## BUILD THE AIRCRAFT THROUGH THE GAME PATH. The first Prowler suite instantiated `ProwlerAirframe` directly, so it
## could not see `VehicleView._build_wing` adding a second generic Wing, Tailplane and Fin around the good model. It
## also could not see presentation-only cyan screen boxes colliding with the authored station package.
func _the_game_build_has_one_airframe_and_four_working_stations() -> VehicleView:
	var view := (load("res://objects/vehicles/craft_prowler.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.preview_kind = Sim.Kind.PROWLER
	view._show_in_editor()
	var leftovers := PackedStringArray()
	for part in ["Wing", "Tailplane", "Fin"]:
		if view.get_node_or_null(part) != null:
			leftovers.append(part)
	var station_detail := PackedStringArray()
	var stations_ok := true
	for seat in range(4):
		var station := view.station_for(seat)
		var mfds: int = station.find_children("*", "MfdPanel", true, false).size() if station != null else 0
		var maps: int = station.find_children("*", "MapScreen", true, false).size() if station != null else 0
		var has_stick: bool = station != null and station.find_child("Stick", true, false) != null
		var has_throttle: bool = station != null and station.find_child("Throttle", true, false) != null
		var has_rudder: bool = station != null and (station.find_child("Rudder", true, false) != null
			or station.find_child("Pedals", true, false) != null)
		var right_role: bool = has_stick and has_throttle and has_rudder if seat < 2 \
			else not has_stick and not has_throttle and not has_rudder
		stations_ok = stations_ok and station != null and mfds == 2 and maps == 0 and right_role
		station_detail.append("%d:%dMFD/%dmap/S%sT%sR%s" % [seat, mfds, maps, has_stick, has_throttle, has_rudder])
	_check("the_game_build_has_one_airframe_and_four_working_stations",
		view.find_child("Prowler", true, false) is ProwlerAirframe and leftovers.is_empty() and stations_ok,
		"generic leftovers %s; stations %s" % [leftovers, ", ".join(station_detail)])
	return view


## A VR CAMERA renders from two eyes and the head never stays on the seat's mathematical centre. Straight-ahead and
## modestly splayed horizon rays must therefore clear from a small head box around each front seat, through the whole
## assembled craft (real controls included). Transparent panes are deliberately omitted; opaque skin, frames, dummy
## presentation parts and misplaced instruments all still count.
func _the_front_seats_have_a_clear_vr_head_box(view: VehicleView) -> void:
	var solids := _opaque_triangles(view)
	var blocked := PackedStringArray()
	var offsets := [Vector3.ZERO, Vector3(-0.05, 0.0, 0.0), Vector3(0.05, 0.0, 0.0),
		Vector3(0.0, -0.04, 0.0), Vector3(0.0, 0.04, 0.0)]
	for seat in range(2):
		var anchor := view.seat_anchor(seat)
		var eye: Vector3 = view.to_local(anchor.global_position + Vector3.UP * CockpitStation.EYE_HEIGHT)
		for offset in offsets:
			# A long nose belongs BELOW the level sightline, not in it. This used to accept Body after 1.5 m and therefore
			# blessed the second bad version: the window was open, but the nose deck still filled its lower half.
			for elevation in [0.0, -8.0]:
				var forward := _cast_opaque(solids, eye + offset, _look(0.0, elevation), 8.0)
				if String(forward[1]) == "Body":
					blocked.append("seat%d nose Body crosses the %.0f degree sightline at %.2fm"
						% [seat, elevation, forward[0]])
		# Above the distant nose and below the real upper windscreen bow, both stereo eyes have open sky.
		for offset in [Vector3.ZERO, Vector3(-0.05, 0.0, 0.0), Vector3(0.05, 0.0, 0.0)]:
			var along := _look(0.0, 8.0)
			var hit := _cast_opaque(solids, eye + offset, along, 8.0)
			if not String(hit[1]).is_empty():
				blocked.append("seat%d %s along %s at %.2fm" % [seat, hit[1], along, hit[0]])
	_check("the_front_seats_have_a_clear_vr_head_box", blocked.is_empty(),
		"26 assembled-cockpit aperture rays clear, including eight degrees below level"
			if blocked.is_empty() else "; ".join(blocked))


static func _look(azimuth: float, elevation: float) -> Vector3:
	var az := deg_to_rad(azimuth)
	var el := deg_to_rad(elevation)
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)).normalized()


func _opaque_triangles(root: Node3D) -> Array:
	var solids: Array = []
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var into := root.global_transform.affine_inverse() * mesh.global_transform
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.material_override if mesh.material_override != null \
				else mesh.mesh.surface_get_material(surface)
			if material is BaseMaterial3D \
					and (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var points := PackedVector3Array()
			for point in (mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				points.append(into * point)
			if points.is_empty():
				continue
			var box := AABB(points[0], Vector3.ZERO)
			for point in points:
				box = box.expand(point)
			solids.append({"name": String(mesh.name), "faces": points, "box": box.grow(0.002)})
	return solids


func _cast_opaque(solids: Array, from: Vector3, along: Vector3, far: float) -> Array:
	var to := from + along * far
	var best := far
	var named := ""
	for solid in solids:
		if (solid["box"] as AABB).intersects_segment(from, to) == null \
				and not (solid["box"] as AABB).has_point(from):
			continue
		var faces: PackedVector3Array = solid["faces"]
		for i in range(0, faces.size() - 2, 3):
			var hit = Geometry3D.ray_intersects_triangle(from, along, faces[i], faces[i + 1], faces[i + 2])
			if hit != null:
				var distance: float = from.distance_to(hit as Vector3)
				if distance > 0.001 and distance < best:
					best = distance
					named = String(solid["name"])
	return [best, named]


## ROLL, PITCH AND YAW ONE AT A TIME. Each surface is sampled at a trailing-edge marker in frame space, so this catches
## a wrong hinge axis, wrong sign, or a surface accidentally parented outside the folding panel.
func _the_control_surfaces_follow_one_axis_at_a_time(frame: Node3D) -> void:
	var rest := _surface_markers(frame)
	var said: PackedStringArray = []
	var ok := true
	for pose in [[Vector2(1, 0), 0.0, "roll"], [Vector2(0, 1), 0.0, "pitch"], [Vector2.ZERO, 1.0, "yaw"]]:
		frame.follow_the_stick(pose[0], pose[1])
		var moved := _marker_delta(rest, _surface_markers(frame))
		var here: bool
		match pose[2]:
			"roll":
				here = moved["AileronStarboard"].y * moved["AileronPort"].y < -0.01 \
					and moved["StabilatorStarboard"].length() < 0.001 and moved["RudderSurface"].length() < 0.001
			"pitch":
				here = moved["StabilatorStarboard"].y * moved["StabilatorPort"].y > 0.01 \
					and moved["AileronStarboard"].length() < 0.001 and moved["RudderSurface"].length() < 0.001
			_:
				here = absf(moved["RudderSurface"].x) > 0.03 and moved["AileronStarboard"].length() < 0.001 \
					and moved["StabilatorStarboard"].length() < 0.001
		ok = ok and here
		said.append("%s %s" % [pose[2], moved])
		frame.follow_the_stick(Vector2.ZERO, 0.0)
	_check("the_control_surfaces_follow_one_axis_at_a_time", ok and _marker_delta(rest, _surface_markers(frame)).values().all(
		func(delta: Vector3) -> bool: return delta.length() < 0.0001), "; ".join(said))


func _surface_markers(frame: Node3D) -> Dictionary:
	var result := {}
	for pair in [["AileronStarboard", "AileronSurfaceStarboard"], ["AileronPort", "AileronSurfacePort"],
			["StabilatorStarboard", "StabilatorSurfaceStarboard"], ["StabilatorPort", "StabilatorSurfacePort"],
			["RudderSurface", "RudderSurface"]]:
		var named: String = pair[0]
		var part := frame.find_child(pair[1], true, false) as MeshInstance3D
		var vertices: PackedVector3Array = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var marker := vertices[0]
		for vertex in vertices:
			if vertex.z > marker.z:
				marker = vertex
		result[named] = frame.global_transform.affine_inverse() * part.global_transform * marker
	return result


func _marker_delta(rest: Dictionary, posed: Dictionary) -> Dictionary:
	var result := {}
	for named in rest:
		result[named] = (posed[named] as Vector3) - (rest[named] as Vector3)
	return result


## THE USER-FACING PATH IS A VAT, so hinges alone are not enough. Bake a second airframe and compare every vertex of
## each moving mesh with the parts at amounts deliberately between texture rows. The ailerons must carry two feature
## tags: their own hinge inside the outer wing's fold.
func _the_vat_draws_the_fold_and_three_axes_where_the_parts_are(parts: ProwlerAirframe) -> void:
	var cast := ProwlerAirframe.new()
	add_child(cast)
	cast.dress()
	var vat: VatCasting = await VatCasting.pour(cast, cast.features())
	var feature_names: Array = []
	for feature in vat.features:
		feature_names.append(feature["name"])
	var surfaces := ["Panel", "AileronSurfaceStarboard", "AileronSurfacePort", "StabilatorSurfaceStarboard",
		"StabilatorSurfacePort", "RudderSurface"]
	# fold, aileron, pitch, rudder -- all off the 65-row grid.
	var poses := [[0.371, 0.0, 0.0, 0.0], [0.0, 0.613, 0.0, 0.0], [0.0, 0.0, -0.427, 0.0],
		[0.0, 0.0, 0.0, 0.719], [0.833, -0.547, 0.391, -0.283]]
	var worst := 0.0
	var compared := 0
	for pose in poses:
		parts.fold(pose[0])
		parts.set_ailerons(pose[1])
		parts.set_stabilator(pose[2])
		parts.set_rudder(pose[3])
		for surface in surfaces:
			var truth_part := parts.find_child(surface, true, false) as MeshInstance3D
			# Both outer panels share this mesh name; compare the first here, while both named ailerons prove both branches.
			var cast_part := cast.find_child(surface, true, false) as MeshInstance3D
			var column: int = vat.columns.find(cast_part)
			var tags: Vector2i = vat.features_of(column)
			for vertex in (truth_part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var truth: Vector3 = parts.global_transform.affine_inverse() * truth_part.global_transform * vertex
				var played: Vector3 = vat.played_point(column, vat.rest_poses[column] * vertex, tags.x, tags.y, pose)
				worst = maxf(worst, played.distance_to(truth))
				compared += 1
	parts.fold(0.0)
	parts.follow_the_stick(Vector2.ZERO, 0.0)
	var aileron_column: int = vat.columns.find(cast.find_child("AileronSurfaceStarboard", true, false))
	var aileron_tags: Vector2i = vat.features_of(aileron_column)
	var aileron_names := [feature_names[aileron_tags.x], feature_names[aileron_tags.y]]
	var moved_ok := int(vat.moved_by.get("fold", 0)) == 4 and int(vat.moved_by.get("aileron", 0)) == 2 \
		and int(vat.moved_by.get("pitch", 0)) == 2 and int(vat.moved_by.get("rudder", 0)) == 1
	_check("the_vat_draws_the_fold_and_three_axes_where_the_parts_are",
		worst < 0.001 and aileron_names == ["aileron", "fold"] and moved_ok,
		"%d off-grid vertex comparisons, worst %.5f m; aileron tables %s; parts moved %s" % [compared, worst,
			aileron_names, vat.moved_by])
	cast.queue_free()


## THE WING AGAINST A NUMBER IT WAS NOT FITTED TO. The planform constants are a leading edge, a trailing edge and a
## taper read off the plan view; the reference area and the aspect ratio are PRINTED on the drawing. Asking the drawn
## wing to reproduce both is the structural cross-check that caught this lane's own worst mistake, when a two-point
## chord fit made the plan view look 4.2 per cent anisotropic and it is not.
func _the_wing_planform_reproduces_the_printed_area_and_aspect_ratio(frame: Node3D) -> void:
	var reach: float = frame.half_span_inches()
	var area_in2: float = (frame.wing_chord(0.0) + frame.wing_chord(reach)) * reach
	var area: float = area_in2 * ProwlerAirframe.IN * ProwlerAirframe.IN
	var ratio: float = (SPAN * SPAN) / maxf(area, 0.001)
	_check("the_wing_planform_reproduces_the_printed_area_and_aspect_ratio",
		absf(area - WING_AREA) <= WING_AREA * 0.03 and absf(ratio - ASPECT_RATIO) <= ASPECT_RATIO * 0.03,
		"%.2f m2 against the printed %.2f, aspect ratio %.2f against the printed %.2f" % [area, WING_AREA, ratio, ASPECT_RATIO])


## THE FOLD, against the printed folded width. Folded, the hinge is the widest part of the aeroplane, which is why the
## printed 299 in is twice the hinge station and why this check is worth having: it fails if the panels swing the wrong
## way, if the hinge moves, or if a panel keeps its spread span after being turned.
func _the_folded_wings_are_the_printed_width_across(frame: Node3D) -> void:
	frame.fold(1.0)
	var folded := _drawn_bounds(frame)
	var folded_widest := _widest_part(frame)
	frame.fold(0.0)
	var spread := _drawn_bounds(frame)
	_check("the_folded_wings_are_the_printed_width_across",
		absf(folded.size.x - FOLDED) <= FOLDED * 0.03 and absf(spread.size.x - SPAN) <= SPAN * 0.02,
		"%.3f m folded against the printed %.3f (%s widest), %.3f m spread against %.3f" % [folded.size.x, FOLDED,
			folded_widest, spread.size.x, SPAN])


func _widest_part(frame: Node3D) -> String:
	var found := ""
	var widest := 0.0
	for child in frame.find_children("*", "MeshInstance3D", true, false):
		var drawn := child as MeshInstance3D
		var into := frame.global_transform.affine_inverse() * drawn.global_transform
		for surface in range(drawn.mesh.get_surface_count()):
			for point in (drawn.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var x: float = absf((into * point).x)
				if x > widest:
					widest = x
					found = "%s at %.3f m" % [child.name, x]
	return found


## A FACE WOUND BACKWARDS IS INVISIBLE AND NOTHING ELSE WILL FIND IT. `ship_models.gd` counts these and requires zero;
## the Hawkeye's rotodome shipped 16 of 448 wound inwards before its own version of this check existed.
func _every_face_is_wound_outwards(frame: Node3D) -> void:
	var wrong: int = 0
	var total: int = 0
	for node in frame.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.mesh == null:
			continue
		for s in range(drawn.mesh.get_surface_count()):
			var arrays: Array = drawn.mesh.surface_get_arrays(s)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in range(0, points.size() - 2, 3):
				var face: Vector3 = (points[i + 2] - points[i]).cross(points[i + 1] - points[i])
				if face.length_squared() < 1e-10:
					continue
				total += 1
				if face.dot(normals[i]) <= 0.0:
					wrong += 1
	_check("every_face_is_wound_outwards", wrong == 0 and total > 0,
		"%d of %d faces wound against their normal" % [wrong, total])


## THE BUDGET for a first exterior LOD, from `aircraft_model_fidelity_plan.md`: at most 100,000 triangles, 12 material
## slots and 20 draw calls. It also requires at least one distance-culled fitting, so detail that should disappear does.
## THE SCOPE IS STATED IN THE DETAIL, because a triangle count means nothing without the subtree it counted: the F/A-18F
## is quoted at both 1,700 and 2,702 in `modelling_here.md` and the two are different subtrees of the same aeroplane.
func _the_exterior_meets_the_first_lod_budget(frame: Node3D) -> void:
	var triangles: int = 0
	var draws: int = 0
	var culled: int = 0
	for node in frame.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.mesh == null:
			continue
		if drawn.visibility_range_end > 0.0:
			culled += 1
		for s in range(drawn.mesh.get_surface_count()):
			draws += 1
			triangles += (drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_check("the_exterior_meets_the_first_lod_budget",
		triangles <= 100000 and draws <= 20 and culled >= 1,
		"the whole ProwlerAirframe subtree: %d triangles, %d draw surfaces, %d distance-culled" % [triangles, draws, culled])


## MEASURE FROM TRANSFORMED VERTICES, NEVER `transform * mesh.get_aabb()`: a box round a box grows every time it turns.
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


## THE LOWEST DRAWN POINT within a hand's width of one station, which is how a tyre's contact is found without asking
## the builder where it put it.
func _lowest_under(root: Node3D, station_in: float) -> float:
	var z: float = root.station(station_in)
	var lowest: float = INF
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var drawn := child as MeshInstance3D
		if drawn.mesh == null:
			continue
		var into := root.global_transform.affine_inverse() * drawn.global_transform
		for surface in range(drawn.mesh.get_surface_count()):
			for point in (drawn.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var at: Vector3 = into * point
				# The window has to be wider than the TYRE, not than the leg: at 0.25 m it found neither tyre --
				# both are wider than that in z -- and measured the two AXLES instead, which differ by more than the
				# contacts do because the tyres differ in size. It read 8.02 degrees of rake against a true 5.81.
				if absf(at.z - z) < 0.5 and at.y < lowest:
					lowest = at.y
	return lowest


func _fuselage_top_at(root: Node3D, station_in: float) -> float:
	return root.waterline(float((ProwlerAirframe.SECTIONS[0] as Array)[2])) if station_in <= 0.0 \
		else root.waterline(float((ProwlerAirframe.SECTIONS[-1] as Array)[2]))


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
