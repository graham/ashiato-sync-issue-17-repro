extends Node
## Headless: HANGAR 03 IS THE SHEET'S HANGAR, measured off the vertices it actually drew.
##
##   Godot --headless --path cockpit res://tests/hangar.tscn
##
## THE POINT OF THIS SUITE IS THAT IT DOES NOT ASK THE MODEL FOR ITS DIMENSIONS. Every number below comes from the welded
## mesh -- the vertex positions and their colours -- and is compared against the numbers on the user's concept sheet
## (`structures/hangar_03/sources.md`): 32 m across the door face, 40 m deep, 12.0 m to the top of the roof spine, a
## 24 x 8 m clear opening, ribs on 10 m bays, three bays across the faces. A builder that drew a 30 m wall while its
## constant said 32 would pass a test that asked the constant and fails this one.
##
## THE FOOTPRINT IS MEASURED ABOVE THE SERVICE HOUSINGS, not from the whole mesh's bounding box: the housings and the
## hazard lockers stand outside the 32 x 40 m envelope on purpose, as they do on the sheet, and a box round the lot
## measures the cabinets instead of the building. The tallest of them is 2.2 m, so everything from 2.5 m up is building.
## A NARROW BAND A FEW METRES UP MEASURES NOTHING AT ALL: a box's vertices are its eight corners, and a rib's corners
## are at the ground and at the eave. The first draft of this suite banded 3 m to 8 m and found no ribs whatever.
##
## AND THE OPENING IS CHECKED BOTH WAYS: nothing is drawn inside it, and something IS drawn immediately outside it. A
## check that only looked for emptiness would pass on a hangar with no front wall at all.
##
## THE FIGHTER IS DRIVEN THROUGH. `FighterAirframe`'s own drawn box is stepped along the centreline from the apron to
## the back of the hangar and tested against every static box `SkyfrontHangar.boxes()` hands the simulation; the
## clearances it has at the narrowest point are printed, because "it fits" is a number, not an opinion.
##
## Read RESULT=, not the exit code.

## The sheet's numbers, written here so the suite states what it believes rather than importing it.
const SPAN_SAID: float = 32.0
const DEEP_SAID: float = 40.0
const SPINE_SAID: float = 12.0
const EAVE_SAID: float = 9.2
const OPENING_WIDE_SAID: float = 24.0
const OPENING_HIGH_SAID: float = 8.0
const BAY_SAID: float = 10.0
const FACE_BAYS_SAID: int = 3
## How far a measured dimension may be from the sheet's: the brief's 2%.
const TOLERANCE: float = 0.02

var _failures: PackedStringArray = []
var _vertices: PackedVector3Array = PackedVector3Array()
var _colours: PackedColorArray = PackedColorArray()
var _hangar: SkyfrontHangar = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[hangar] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _near(measured: float, said: float) -> bool:
	return absf(measured - said) <= said * TOLERANCE


func _ready() -> void:
	_stand_one_up()
	_the_footprint_is_the_sheet_s()
	_the_height_is_twelve_to_the_spine()
	_the_opening_is_twenty_four_by_eight()
	_the_ribs_stand_on_ten_metre_bays()
	_the_towers_stand_at_the_corners()
	_every_face_is_wound_outwards()
	_the_markings_are_on_it()
	_the_walls_are_solid_and_the_opening_is_not()
	_a_fighter_fits_through_the_door()
	_a_longer_hangar_is_a_parameter()
	_the_level_stands_it_on_an_apron()
	_what_it_costs_to_draw()
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _stand_one_up() -> void:
	_hangar = SkyfrontHangar.new()
	_hangar.name = "Hangar"
	add_child(_hangar)
	var shell: MeshInstance3D = _hangar.shell
	if shell == null or shell.mesh == null:
		_check("it_draws_a_shell", false, "no mesh")
		return
	var arrays: Array = shell.mesh.surface_get_arrays(0)
	_vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	_colours = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	_check("it_draws_a_shell", _vertices.size() > 0, "%d vertices, %d colours" % [_vertices.size(), _colours.size()])


## WHERE THE MIDDLES OF A ROW OF PIECES ARE, along one plan axis: every matching vertex's coordinate, grouped into
## clusters no more than `apart` wide, each reported as the mean of its own members.
##
## A cluster's FIRST vertex is not its middle -- a rib's bolt plate is 1.25 m off the rib's own centreline, so a rib
## found by its plate first reads 1.25 m out of place and the bay spacing with it. The mean of the cluster is stable
## whichever vertex the walk met first.
func _clusters(values: PackedFloat32Array, apart: float) -> Array[float]:
	var sorted: PackedFloat32Array = values.duplicate()
	sorted.sort()
	var out: Array[float] = []
	var group: PackedFloat32Array = PackedFloat32Array()
	for value in sorted:
		if not group.is_empty() and value - group[group.size() - 1] > apart:
			out.append(_mean(group))
			group = PackedFloat32Array()
		group.append(value)
	if not group.is_empty():
		out.append(_mean(group))
	return out


func _mean(values: PackedFloat32Array) -> float:
	var total: float = 0.0
	for value in values:
		total += value
	return total / float(maxi(1, values.size()))


## Every vertex whose height is between `low` and `high`, as a plan-space span in x and in z.
func _span_between(low: float, high: float) -> Dictionary:
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for point in _vertices:
		if point.y < low or point.y > high:
			continue
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.z)
		max_z = maxf(max_z, point.z)
	return {"x": max_x - min_x, "z": max_z - min_z, "min_x": min_x, "max_x": max_x, "min_z": min_z, "max_z": max_z}


func _the_footprint_is_the_sheet_s() -> void:
	# ABOVE THE SERVICE HOUSINGS, which are the only things the sheet stands outside the envelope: the tallest of them is
	# the 2.2 m hazard locker, so everything from 2.5 m up is building. A box round the WHOLE mesh would measure the
	# cabinets; a narrow band a few metres up would measure nothing at all, because a box's vertices are its corners and
	# a rib's corners are at the ground and at the eave.
	var measured: Dictionary = _span_between(2.5, 99.0)
	_check("it_is_thirty_two_metres_across_the_door_face", _near(float(measured["x"]), SPAN_SAID),
		"%.2f m, said %.1f" % [measured["x"], SPAN_SAID])
	_check("it_is_forty_metres_deep", _near(float(measured["z"]), DEEP_SAID),
		"%.2f m, said %.1f" % [measured["z"], DEEP_SAID])
	_check("and_it_is_centred_on_its_own_origin",
		absf(float(measured["min_x"]) + float(measured["max_x"])) < 0.1 \
			and absf(float(measured["min_z"]) + float(measured["max_z"])) < 0.1,
		"x %.2f..%.2f, z %.2f..%.2f" % [measured["min_x"], measured["max_x"], measured["min_z"], measured["max_z"]])


func _the_height_is_twelve_to_the_spine() -> void:
	# THE STRUCTURE IS TOLD FROM THE PAINT BY THE ALPHA IN ITS OWN VERTICES: the shell's shader takes COLOR.a as how much
	# riveted panel detail a surface carries, and the railings and the painted lines are the ones that carry none. So
	# "how high is the roof" is asked of the roof, not of the handrail standing on it.
	var spine_top: float = -INF
	var eave_top: float = -INF
	var highest: float = -INF
	var highest_of_all: float = -INF
	var wall_face: float = SkyfrontHangar.SPAN * 0.5 - SkyfrontHangar.RIB_PROUD
	var wall_end: float = SkyfrontHangar.depth_of(SkyfrontHangar.BAYS_DEFAULT) * 0.5 - SkyfrontHangar.RIB_PROUD
	for index in range(_vertices.size()):
		var point: Vector3 = _vertices[index]
		var painted: bool = index < _colours.size() and _colours[index].a < 0.1
		highest_of_all = maxf(highest_of_all, point.y)
		if not painted:
			highest = maxf(highest, point.y)
		if not painted and absf(point.x) <= SkyfrontHangar.SPINE_WIDE * 0.5 + 0.2 \
				and absf(point.z) <= SkyfrontHangar.SPINE_LONG * 0.5 + 0.2:
			spine_top = maxf(spine_top, point.y)
		# THE TOP OF THE WALL, MEASURED AT THE CORNER WHERE THE SIDE WALL MEETS THE END WALL. The wall panels are one
		# box a band, so their only vertices are at those corners -- and the corner is the one place on the wall plane
		# where no rib, no tower head and no painted hip stripe can answer for the wall instead. All three did.
		if absf(absf(point.x) - wall_face) > 0.06 or absf(absf(point.z) - wall_end) > 0.06:
			continue
		eave_top = maxf(eave_top, point.y)
	_check("the_roof_spine_tops_out_at_twelve_metres", _near(spine_top, SPINE_SAID),
		"%.2f m, said %.1f" % [spine_top, SPINE_SAID])
	_check("the_wall_tops_out_at_the_eave", _near(eave_top, EAVE_SAID), "%.2f m, said %.1f" % [eave_top, EAVE_SAID])
	_check("and_the_masts_are_the_highest_structure_on_it", _near(highest, SkyfrontHangar.MAST_TOP),
		"highest structure %.2f m, masts %.1f" % [highest, SkyfrontHangar.MAST_TOP])
	_check("and_only_the_spine_s_own_railing_stands_over_them",
		highest_of_all <= SkyfrontHangar.SPINE_TOP + SkyfrontHangar.RAIL_TALL + 0.15,
		"highest of all %.2f m" % highest_of_all)


func _the_opening_is_twenty_four_by_eight() -> void:
	var face_z: float = SkyfrontHangar.depth_of(SkyfrontHangar.BAYS_DEFAULT) * 0.5 - SkyfrontHangar.RIB_PROUD
	# NOTHING IS DRAWN INSIDE THE OPENING, a hand's width in from its edges and the door plane.
	var inside: int = 0
	for point in _vertices:
		if absf(point.z - face_z) > 0.6:
			continue
		if absf(point.x) < OPENING_WIDE_SAID * 0.5 - 0.15 and point.y > 0.2 and point.y < OPENING_HIGH_SAID - 0.15:
			inside += 1
	_check("the_opening_is_clear", inside == 0, "%d vertices inside 24.0 x 8.0 m at the door plane" % inside)
	# AND THE WALL IS THERE IMMEDIATELY OUTSIDE IT: a jamb beside it and a head beam over it.
	var jamb: int = 0
	var head: int = 0
	for point in _vertices:
		if absf(point.z - face_z) > 0.8:
			continue
		if absf(point.x) > OPENING_WIDE_SAID * 0.5 + 0.05 and absf(point.x) < OPENING_WIDE_SAID * 0.5 + 1.4 \
				and point.y > 1.0 and point.y < 7.0:
			jamb += 1
		if absf(point.x) < OPENING_WIDE_SAID * 0.5 - 1.0 and point.y > OPENING_HIGH_SAID + 0.05 \
				and point.y < EAVE_SAID - 0.05:
			head += 1
	_check("a_jamb_stands_either_side_of_it", jamb > 0, "%d vertices in the jamb band" % jamb)
	_check("and_a_head_beam_crosses_over_it", head > 0, "%d vertices over the lintel" % head)
	# The opening the level and the simulation are told about is the one that was drawn.
	var said: Dictionary = SkyfrontHangar.opening()
	var half: Vector3 = said["half_extents"]
	_check("and_the_opening_it_declares_is_that_opening",
		_near(half.x * 2.0, OPENING_WIDE_SAID) and _near(half.y * 2.0, OPENING_HIGH_SAID),
		"%.1f x %.1f m" % [half.x * 2.0, half.y * 2.0])


func _the_ribs_stand_on_ten_metre_bays() -> void:
	# A RIB'S OUTER FACE IS THE ENVELOPE ITSELF: gather the z of every vertex standing on the 32 m line, and cluster.
	# The corner towers reach the same line, so the ends are left out and what remains is the ribs between them.
	var rib_face: float = SkyfrontHangar.SPAN * 0.5
	var half_deep: float = SkyfrontHangar.depth_of(SkyfrontHangar.BAYS_DEFAULT) * 0.5
	var found := PackedFloat32Array()
	for point in _vertices:
		if point.y < 0.2 or point.y > SkyfrontHangar.EAVE + 0.6 or absf(absf(point.x) - rib_face) > 0.06:
			continue
		if absf(point.z) >= half_deep - SkyfrontHangar.TOWER - 0.5:
			continue
		found.append(point.z)
	var inner: Array[float] = _clusters(found, 1.8)
	_check("there_is_a_rib_at_every_bay_joint", inner.size() == SkyfrontHangar.BAYS_DEFAULT - 1,
		"%d ribs between the towers, wanted %d (%s)" % [inner.size(), SkyfrontHangar.BAYS_DEFAULT - 1, inner])
	var spacings: PackedFloat32Array = PackedFloat32Array()
	var even: bool = true
	for index in range(1, inner.size()):
		var step: float = inner[index] - inner[index - 1]
		spacings.append(step)
		even = even and absf(step - BAY_SAID) < 0.1
	_check("and_the_bays_are_ten_metres", even and not spacings.is_empty(), "spacings %s m, said %.1f" % [spacings, BAY_SAID])
	# AND THREE BAYS ACROSS THE REAR FACE: two ribs, at the thirds of the span.
	var across := PackedFloat32Array()
	for point in _vertices:
		if point.y < 0.2 or point.y > SkyfrontHangar.EAVE + 0.6 or absf(point.z + half_deep) > 0.06:
			continue
		if absf(point.x) >= SkyfrontHangar.SPAN * 0.5 - SkyfrontHangar.TOWER - 0.5:
			continue
		across.append(point.x)
	var face_places: Array[float] = _clusters(across, 1.8)
	var step_said: float = SkyfrontHangar.SPAN / float(FACE_BAYS_SAID)
	var right_places: bool = face_places.size() == FACE_BAYS_SAID - 1
	for index in range(face_places.size()):
		var wanted: float = -SkyfrontHangar.SPAN * 0.5 + float(index + 1) * step_said
		right_places = right_places and absf(face_places[index] - wanted) < 0.2
	_check("the_face_has_three_bays_across_it", right_places,
		"ribs at %s, wanted every %.2f m" % [face_places, step_said])


func _the_towers_stand_at_the_corners() -> void:
	var found: int = 0
	var half_deep: float = SkyfrontHangar.depth_of(SkyfrontHangar.BAYS_DEFAULT) * 0.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var corner := Vector2(sx * SkyfrontHangar.SPAN * 0.5, sz * half_deep)
			var tall: float = -INF
			for point in _vertices:
				if Vector2(point.x, point.z).distance_to(corner) > SkyfrontHangar.TOWER:
					continue
				tall = maxf(tall, point.y)
			if tall > SkyfrontHangar.EAVE + 1.0:
				found += 1
	_check("a_tower_stands_at_each_of_the_four_corners", found == 4, "%d corners carry one" % found)


## EVERY FACE FACES OUT. A quad wound the wrong way is invisible and nothing else will find it: the ships' own suite
## counts these because two hangar openings and a band of windows were drawn inside out before `Plating.facing` existed
## (modelling_here.md, section 6). A building is mostly boxes, and the pieces at risk are the roof plates, the paint on
## the slopes and every glyph, all of which are placed by where they face.
func _every_face_is_wound_outwards() -> void:
	var arrays: Array = _hangar.shell.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var wrong: int = 0
	var total: int = 0
	for index in range(0, points.size() - 2, 3):
		var face: Vector3 = (points[index + 2] - points[index]).cross(points[index + 1] - points[index])
		if face.length_squared() < 1e-10:
			continue
		total += 1
		if face.dot(normals[index]) <= 0.0:
			wrong += 1
	_check("every_face_of_the_hangar_is_wound_outwards", wrong == 0 and total > 0,
		"%d of %d faces wound against their normal" % [wrong, total])


func _the_markings_are_on_it() -> void:
	var tower_x: float = SkyfrontHangar.front_tower_middle()
	var tower_z: float = SkyfrontHangar.depth_of(SkyfrontHangar.BAYS_DEFAULT) * 0.5
	var number_on_the_pillar: int = 0
	var number_on_the_roof: int = 0
	var sign_panel: int = 0
	for index in range(_vertices.size()):
		var point: Vector3 = _vertices[index]
		if absf(point.z - tower_z) < 0.2 and absf(point.x - tower_x) < SkyfrontHangar.front_tower_wide() * 0.5 \
				and point.y > 5.2 and point.y < 7.2:
			number_on_the_pillar += 1
		if point.y > SkyfrontHangar.SPINE_TOP + 0.08 and absf(point.x) < SkyfrontHangar.ROOF_DIGITS * 0.6 \
				and absf(point.z) < SkyfrontHangar.ROOF_DIGITS:
			number_on_the_roof += 1
		if absf(point.z - tower_z) < 0.2 and absf(point.x + tower_x) < SkyfrontHangar.SIGN_WIDE \
				and point.y > 4.2 and point.y < 8.6:
			sign_panel += 1
	_check("the_number_is_on_the_door_pillar", number_on_the_pillar > 0, "%d vertices" % number_on_the_pillar)
	_check("the_number_is_on_the_roof", number_on_the_roof > 0, "%d vertices" % number_on_the_roof)
	_check("the_pad_sign_is_on_the_other_pillar", sign_panel > 0, "%d vertices" % sign_panel)
	# EVERY CHARACTER THE MARKINGS ASK FOR HAS A GLYPH: a number with a character this model cannot draw would paint
	# nothing at all, silently, which is the invisible default rule 8 is about.
	var missing: PackedStringArray = []
	for text in [_hangar.hangar_number, _hangar.pad_sign]:
		for index in range(text.length()):
			if (_hangar.call("_glyph_blocks", text[index]) as Array).is_empty():
				missing.append(text[index])
	_check("and_every_character_in_them_has_a_glyph", missing.is_empty(), "missing %s" % [missing])
	# The small print is laid out with the project's font, not with blocks, and says what the sheet says.
	var brand := _hangar.get_node_or_null("Brand") as Label3D
	var promise := _hangar.get_node_or_null("Promise") as Label3D
	_check("the_brand_and_its_line_are_on_the_pillar",
		brand != null and brand.text == "SKYFRONT" and promise != null and promise.text.contains("BRIGHTER"),
		"%s / %s" % [brand.text if brand != null else "-", promise.text.replace("\n", " ") if promise != null else "-"])


## Whether a box centred at `at` with `half` extents touches any of the solid boxes.
func _hits(solid: Array[Dictionary], at: Vector3, half: Vector3) -> bool:
	for box in solid:
		var centre: Vector3 = box["position"]
		var extents: Vector3 = box["half_extents"]
		if absf(centre.x - at.x) < extents.x + half.x and absf(centre.y - at.y) < extents.y + half.y \
				and absf(centre.z - at.z) < extents.z + half.z:
			return true
	return false


func _the_walls_are_solid_and_the_opening_is_not() -> void:
	var solid: Array[Dictionary] = SkyfrontHangar.boxes()
	var half_deep: float = SkyfrontHangar.depth_of(SkyfrontHangar.BAYS_DEFAULT) * 0.5
	var probe := Vector3(0.2, 0.2, 0.2)
	_check("the_simulation_is_given_the_building", solid.size() >= 12, "%d static boxes" % solid.size())
	# A point in each wall, and one in the roof over the middle: all solid.
	var walls: Dictionary = {
		"left wall": Vector3(-(SkyfrontHangar.SPAN * 0.5 - SkyfrontHangar.RIB_PROUD - 0.25), 4.0, 0.0),
		"right wall": Vector3(SkyfrontHangar.SPAN * 0.5 - SkyfrontHangar.RIB_PROUD - 0.25, 4.0, 0.0),
		"rear wall": Vector3(0.0, 4.0, -(half_deep - SkyfrontHangar.RIB_PROUD - 0.25)),
		"door flank": Vector3(OPENING_WIDE_SAID * 0.5 + 1.2, 4.0, half_deep - SkyfrontHangar.RIB_PROUD - 0.25),
		"head beam": Vector3(0.0, OPENING_HIGH_SAID + 0.6, half_deep - SkyfrontHangar.RIB_PROUD - 0.25),
		"roof": Vector3(0.0, SkyfrontHangar.EAVE + 0.2, 0.0),
	}
	var open: PackedStringArray = []
	for named in walls:
		if not _hits(solid, walls[named], probe):
			open.append(named)
	_check("every_wall_the_sheet_draws_is_solid", open.is_empty(), "open: %s" % [open])
	# And the opening itself is clear, all the way across and all the way up.
	var blocked: PackedStringArray = []
	for across in [-11.0, -6.0, 0.0, 6.0, 11.0]:
		for up in [0.6, 4.0, 7.4]:
			var at := Vector3(across, up, half_deep - SkyfrontHangar.RIB_PROUD)
			if _hits(solid, at, probe):
				blocked.append("%.0f m across, %.1f m up" % [across, up])
	_check("and_the_opening_is_clear_through_the_wall", blocked.is_empty(), "blocked at %s" % [blocked])


func _a_fighter_fits_through_the_door() -> void:
	var scene := load("res://objects/vehicles/fighter_airframe.tscn") as PackedScene
	if scene == null:
		_check("there_is_a_fighter_to_fly_in", false, "no fighter_airframe.tscn")
		return
	var craft := scene.instantiate() as Node3D
	add_child(craft)
	# THE FIGHTER'S OWN DRAWN SIZE, from its meshes: never the spec sheet, and never a number typed here.
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for child in craft.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var box: AABB = mesh_instance.mesh.get_aabb()
		var into: Transform3D = craft.global_transform.affine_inverse() * mesh_instance.global_transform
		for corner in range(8):
			var at: Vector3 = into * box.get_endpoint(corner)
			low = Vector3(minf(low.x, at.x), minf(low.y, at.y), minf(low.z, at.z))
			high = Vector3(maxf(high.x, at.x), maxf(high.y, at.y), maxf(high.z, at.z))
	var size: Vector3 = high - low
	_check("the_fighter_is_the_size_its_own_model_says",
		absf(size.x - FighterAirframe.SPAN) < 0.6 and absf(size.z - FighterAirframe.LENGTH) < 0.8,
		"drawn %.2f span x %.2f long x %.2f high" % [size.x, size.z, size.y])
	var wingtip_clear: float = (OPENING_WIDE_SAID - size.x) * 0.5
	var fin_clear: float = OPENING_HIGH_SAID - size.y
	_check("it_clears_the_twenty_four_metre_opening_at_the_wingtips", wingtip_clear > 1.0,
		"%.2f m each side of a %.2f m span" % [wingtip_clear, size.x])
	_check("and_it_clears_the_eight_metre_lintel", fin_clear > 1.0,
		"%.2f m over a %.2f m fin" % [fin_clear, size.y])
	# DRIVEN THROUGH: the craft's own box, stepped from the apron to the back wall, against every static box.
	var solid: Array[Dictionary] = SkyfrontHangar.boxes()
	var half: Vector3 = size * 0.5
	var sit: float = -low.y
	var half_deep: float = SkyfrontHangar.depth_of(SkyfrontHangar.BAYS_DEFAULT) * 0.5
	var struck: PackedStringArray = []
	var z: float = half_deep + 12.0
	# AS FAR IN AS THE BUILDING GOES: the rear wall's inner face, less the craft's own nose. A metre past that and the
	# nose is through the wall, which is the test failing on its own arithmetic rather than on the hangar.
	var deepest: float = -(half_deep - SkyfrontHangar.RIB_PROUD - SkyfrontHangar.WALL) + half.z + 0.2
	while z > deepest:
		if _hits(solid, Vector3(0.0, sit + half.y, z), half):
			struck.append("%.1f m" % z)
		z -= 0.5
	_check("and_it_can_be_driven_in_through_the_door", struck.is_empty(),
		"struck the building at %s" % [struck if struck.size() < 6 else "%d places" % struck.size()])
	craft.queue_free()


func _a_longer_hangar_is_a_parameter() -> void:
	var longer := SkyfrontHangar.new()
	longer.bays = 6
	add_child(longer)
	var arrays: Array = longer.shell.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var min_z: float = INF
	var max_z: float = -INF
	var min_x: float = INF
	var max_x: float = -INF
	for point in points:
		if point.y < 2.5:
			continue
		min_z = minf(min_z, point.z)
		max_z = maxf(max_z, point.z)
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
	_check("six_bays_is_a_sixty_metre_hangar", absf((max_z - min_z) - 60.0) < 60.0 * TOLERANCE,
		"%.2f m deep on six bays" % (max_z - min_z))
	_check("and_it_is_still_thirty_two_metres_across", absf((max_x - min_x) - SPAN_SAID) < SPAN_SAID * TOLERANCE,
		"%.2f m across" % (max_x - min_x))
	_check("and_its_solid_grew_with_it", SkyfrontHangar.boxes(Vector3.ZERO, 6).size() > SkyfrontHangar.boxes().size(),
		"%d boxes on six bays against %d on four" % [SkyfrontHangar.boxes(Vector3.ZERO, 6).size(),
			SkyfrontHangar.boxes().size()])
	longer.queue_free()


func _the_level_stands_it_on_an_apron() -> void:
	var chart: LevelChart = ChartDrawer.chart(HangarYard.LEVEL_ID)
	_check("the_hangar_yard_is_a_level_the_desk_can_offer", chart != null,
		"chart %s" % ["read" if chart != null else "missing"])
	if chart == null:
		return
	_check("and_it_is_a_room_a_player_walks_into", chart.world == "room" and chart.arrive_kind == Sim.Kind.SEGWAY,
		"world %s, arrive %s" % [chart.world, Sim.kind_name(chart.arrive_kind)])
	_check("and_the_yard_claims_it", HangarYard.claims(chart), "claims %s" % HangarYard.LEVEL_ID)
	# THE SPAWN IS ON THE APRON AND OUTSIDE THE BUILDING, which is the thing a level gets wrong.
	var spawn: Vector3 = chart.spawn_at
	var solid: Array[Dictionary] = HangarYard.boxes(chart)
	_check("the_spawn_is_clear_of_the_building", not _hits(solid, Vector3(spawn.x, 1.0, spawn.z), Vector3(0.6, 1.0, 0.6)),
		"spawn %.1f, %.1f" % [spawn.x, spawn.z])
	_check("and_it_stands_on_the_apron_looking_at_the_door",
		spawn.z > SkyfrontHangar.depth_of(HangarYard.HANGAR_BAYS) * 0.5 and spawn.z < HangarYard.APRON_TO.y,
		"%.1f m out from the origin, apron to %.1f" % [spawn.z, HangarYard.APRON_TO.y])
	# AND THE PARKED FIGHTER IS INSIDE THE BUILDING, CLEAR OF IT: the thing a screenshot would show and a suite should.
	var yard := HangarYard.new()
	add_child(yard)
	yard.stand_in(chart)
	var craft: Node3D = yard.parked
	_check("a_fighter_is_parked_inside", craft != null and absf(craft.position.z) < SkyfrontHangar.depth_of(
		HangarYard.HANGAR_BAYS) * 0.5 - 2.0, "parked at %s" % [craft.position if craft != null else "nowhere"])
	if craft != null:
		var sits: float = HangarYard.lowest_drawn(craft)
		_check("and_it_sits_on_the_floor_rather_than_in_it", absf(craft.position.y + sits) < 0.05,
			"origin %.2f m up, lowest drawn %.2f m" % [craft.position.y, sits])
	yard.queue_free()


func _what_it_costs_to_draw() -> void:
	var meshes: int = 0
	var labels: int = 0
	var triangles: int = 0
	for child in _hangar.find_children("*", "", true, false):
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			meshes += 1
			var mesh: Mesh = (child as MeshInstance3D).mesh
			for surface in range(mesh.get_surface_count()):
				triangles += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		elif child is Label3D:
			labels += 1
	var lights: int = _hangar.find_children("*", "OmniLight3D", true, false).size()
	print("[hangar] budget: %d meshes, %d labels, %d lights, %d triangles" % [meshes, labels, lights, triangles])
	_check("it_draws_in_the_budget", meshes + labels <= 16 and triangles <= 30000,
		"%d draws and %d triangles, allowed 16 and 30000" % [meshes + labels, triangles])
