extends Node
## Headless contract for the F-14D Tomcat airframe AND ITS SWING WING: the published span at three sweeps, the pivot
## recovered from the drawn wing, one object at every sweep, the wing clear of every other solid at every sweep, the
## crew inside the canopy, the height over the ground, named parts, winding and the budget. AND ITS STICK-DRIVEN
## SURFACES (2026-09-18): spoilers, stabilators and rudders, one axis at a time, from a stick on a real wire, riding the
## wing, locked out past 57 degrees, clear of every other solid, and played from the VAT where the parts are. Read RESULT=.
##
## THE AIRFRAME ON ITS OWN, off `Sim.Kind.TOMCAT`'s geometry, so every sweep can be posed and measured without a world.
## `joined_parts.gd`, `named_parts.gd` and `shell_room.gd` now ask the fleet's questions of the Tomcat as a craft too;
## these ask them at every sweep, which no fleet suite does.
##
## THE ENVELOPE AS CONSTANTS AT THE TOP, typed, never read out of the airframe: a check that asks the constant the mesh
## was built from asks nothing. [PUB] is Grumman's published envelope; [D] is measured off the F-14D drawing by
## `craft/tomcat/measure_drawing.py`, which reads the drawing and not the airframe.
const LENGTH := 19.10          # [PUB] 62 ft 8 in
const SPAN_SPREAD := 19.54     # [PUB] 64 ft 1.5 in at 20 degrees
const SPAN_SWEPT := 11.65      # [PUB] 38 ft 2.5 in at 68 degrees
const SPAN_OVERSWEPT := 10.15  # [PUB] 33 ft 3.5 in at 75 degrees -- the pivot was NOT solved from this one
const HEIGHT := 4.88           # [PUB] 16 ft, fin tip over the ground with the gear down
const PIVOT := Vector2(11.22, 3.00)  # [D] (station, out)
const WING_UNDER := 2.50       # [D] the wing's underside over the ground, off the rear view's wing root
## EVERY SWEEP THE WING IS ASKED AT: both stops, the deck's overswept stop, and one between that is none of them.
const SWEEPS: Array[float] = [20.0, 44.0, 68.0, 75.0]
## The parts that make it a Tomcat, by name: the twin nacelles and fins, the glove, the swing wing, the chin pod, the gun.
const ROSTER: Array[String] = ["Fuselage", "CentreBody", "Spine", "ChinPod", "Gun", "NoseGear",
	"NacelleStarboard", "NacellePort", "NozzleStarboard", "NozzlePort", "GloveStarboard", "GlovePort",
	"FinStarboard", "FinPort", "StabilatorStarboard", "StabilatorPort", "VentralFinStarboard", "VentralFinPort",
	"MainGearStarboard", "MainGearPort", "WingStarboard", "WingPort",
	"SpoilersStarboard", "SpoilersPort", "RudderStarboard", "RudderPort"]
## THE SURFACES THAT FOLLOW THE STICK, by part.
const SURFACES: Array[String] = ["SpoilersStarboard", "SpoilersPort", "StabilatorStarboard", "StabilatorPort",
	"RudderStarboard", "RudderPort"]
## THE SWEEPS THE SURFACES ARE ASKED AT: both stops, the deck's, one between, 55 -- the last sweep at which the
## spoilers still rise their whole travel -- and 69, halfway through the tailplanes' fade as the wing oversweeps.
const SURFACE_SWEEPS: Array[float] = [20.0, 44.0, 55.0, 68.0, 69.0, 75.0]
## THE STICK STATES they are asked at, as (roll, pitch, rudder): each axis alone both ways, then everything over at once.
const STICKS: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0),
	Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, -1, 1), Vector3(-1, 1, -1)]
## A sweep well past the 57-degree lockout, typed, for the drawing of it.
const LOCKED_OUT_AT := 68.0
const TOMCAT_KIND := 25
const PEER := 2
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[tomcat] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_the_simulation_owns_the_tomcat_and_only_the_pilot_flies()
	var frame := TomcatAirframe.new()
	add_child(frame)
	frame.dress()
	_every_visible_mesh_is_a_named_part(frame)
	_the_drawn_aeroplane_is_the_published_length(frame)
	_the_fin_tip_is_the_published_height_over_the_tyres(frame)
	_the_span_is_the_published_span_at_each_published_sweep(frame)
	_the_wing_turns_about_its_drawn_pivot_by_the_angle_asked(frame)
	_the_wing_is_at_its_drawn_height_over_the_tyres(frame)
	_the_sweep_is_a_pure_function_of_the_angle(frame)
	_the_aeroplane_is_one_object_at_every_sweep(frame)
	_the_wing_passes_through_nothing_at_any_sweep(frame)
	_the_crew_and_their_room_are_inside_the_canopy(frame)
	_every_face_is_wound_outwards(frame)
	_the_exterior_meets_the_first_lod_budget(frame)
	_the_surfaces_follow_the_stick_one_axis_at_a_time()
	_the_stick_on_a_real_wire_moves_the_surfaces()
	_the_spoilers_ride_the_swing_wing(frame)
	_the_surfaces_pass_through_nothing_at_any_sweep(frame)
	await _the_vat_draws_the_sweep_where_the_parts_are(frame)
	await _the_vat_draws_every_surface_where_the_parts_are(frame)
	frame.queue_free()
	_finish()


## THE SIMULATION OWNS THE TOMCAT NOW, and says what the airframe was drafted with. This was the clock on the draft --
## red the day `Sim.Kind` named TOMCAT while `TomcatAirframe` still carried its own copy of the geometry -- and it went
## red on 2026-09-17 when the kind was added, as it was written to. Now it holds the kind to the envelope typed here:
## the box, the spread span, two seats, and WHICH OF THEM FLIES, read off each pose's own `flies` and never inferred.
func _the_simulation_owns_the_tomcat_and_only_the_pilot_flies() -> void:
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.TOMCAT)
	var box: Vector3 = geometry.get("extents", Vector3.ZERO)
	var poses: Array = geometry.get("seat_poses", [])
	var flies: Array = []
	for pose in poses:
		flies.append(bool((pose as Dictionary).get("flies", true)))
	_check("the_simulation_owns_the_tomcat_and_only_the_pilot_flies",
		box.is_equal_approx(Vector3(2.2, 1.3, 9.55)) and absf(float(geometry.get("span", 0.0)) - 9.77) < 0.001
			and flies == [true, false],
		"extents %s, half span %.2f, seats fly %s" % [box, float(geometry.get("span", 0.0)), flies])


## EVERY VISIBLE MESH IS A NAMED PART, and the roster that makes it a Tomcat is all there. A duplicate name inside a side
## loop is renamed `@MeshInstance3D@N` by Godot without a word (`tests/named_parts.gd`), and this airframe builds
## eighteen of its parts in one.
func _every_visible_mesh_is_a_named_part(frame: Node3D) -> void:
	var anonymous: PackedStringArray = []
	var names: Dictionary = {}
	for node in frame.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		names[String(drawn.name)] = true
		if String(drawn.name).begins_with("@") or drawn.mesh == null:
			anonymous.append(String(drawn.name))
	var missing: PackedStringArray = []
	for want in ROSTER:
		if not names.has(want):
			missing.append(want)
	_check("every_visible_mesh_is_a_named_part", anonymous.is_empty() and missing.is_empty(),
		"%d meshes; anonymous or empty %s; missing from the roster %s" % [names.size(), anonymous, missing])


func _the_drawn_aeroplane_is_the_published_length(frame: TomcatAirframe) -> void:
	var box := _drawn_bounds(frame)
	_check("the_drawn_aeroplane_is_the_published_length", absf(box.size.z - LENGTH) <= LENGTH * 0.01,
		"drawn %.3f m nose to tail, published %.2f" % [box.size.z, LENGTH])


## THE HEIGHT, OVER THE GROUND THE TYRES STAND ON. The ground is the lowest drawn point of the three gear legs, not the
## builder's `height(0)`: asking the builder where the ground is would read the published figure back whatever the gear
## did. And the three tyres must agree, or the aeroplane is not parked level.
func _the_fin_tip_is_the_published_height_over_the_tyres(frame: TomcatAirframe) -> void:
	var contacts: Array[float] = []
	for which in ["NoseGear", "MainGearStarboard", "MainGearPort"]:
		contacts.append(_drawn_bounds(frame.find_child(which, true, false) as Node3D, frame).position.y)
	var ground: float = contacts.min()
	var box := _drawn_bounds(frame)
	var tallest: float = box.end.y - ground
	var spread: float = contacts.max() - contacts.min()
	_check("the_fin_tip_is_the_published_height_over_the_tyres",
		absf(tallest - HEIGHT) <= HEIGHT * 0.02 and spread < 0.01 and absf(box.position.y - ground) < 0.001,
		"fin tip %.3f m over the tyres, published %.2f; the three contacts agree to %.3f m; nothing drawn below them: %s"
			% [tallest, HEIGHT, spread, absf(box.position.y - ground) < 0.001])


## THE SPAN AT EACH PUBLISHED SWEEP, from the drawn vertices. The pivot's station was solved from the 20-degree span, so
## that one is a consistency check; the 68-degree figure is measured on [D] and the 75-degree one was never used at all
## -- it is the model PREDICTING a number it was not given.
func _the_span_is_the_published_span_at_each_published_sweep(frame: TomcatAirframe) -> void:
	var detail: PackedStringArray = []
	var ok := true
	for pair in [[20.0, SPAN_SPREAD], [68.0, SPAN_SWEPT], [75.0, SPAN_OVERSWEPT]]:
		frame.set_sweep(pair[0])
		var span: float = _drawn_bounds(frame).size.x
		ok = ok and absf(span - float(pair[1])) <= float(pair[1]) * 0.02
		detail.append("%.0f deg %.2f m against %.2f" % [pair[0], span, pair[1]])
	frame.set_sweep(20.0)
	_check("the_span_is_the_published_span_at_each_published_sweep", ok, ", ".join(detail))


## THE WING TURNS ABOUT ITS DRAWN PIVOT, BY THE ANGLE ASKED. Both are recovered from the drawn starboard wing's vertices
## at two sweeps -- the rigid turn that carries one set onto the other has a fixed point and an angle -- and held to the
## pivot typed above from [D]. Nothing here asks the pivot node where it is: a panel built about the wrong point turns
## about the wrong point whatever the node says.
func _the_wing_turns_about_its_drawn_pivot_by_the_angle_asked(frame: TomcatAirframe) -> void:
	var detail: PackedStringArray = []
	var ok := true
	for pair in [[20.0, 68.0], [20.0, 44.0], [44.0, 75.0]]:
		frame.set_sweep(pair[0])
		var before := _plan_points(frame, "WingStarboard")
		frame.set_sweep(pair[1])
		var after := _plan_points(frame, "WingStarboard")
		var turn := _rigid_turn(before, after)
		var fixed: Vector2 = turn["fixed"]
		var station: float = fixed.y + 9.55
		var angle: float = rad_to_deg(float(turn["angle"]))
		var asked: float = float(pair[1]) - float(pair[0])
		ok = ok and absf(station - PIVOT.x) < 0.02 and absf(fixed.x - PIVOT.y) < 0.02 and absf(angle - asked) < 0.1
		detail.append("%.0f->%.0f: turned %.2f deg about station %.3f, %.3f out" % [pair[0], pair[1], angle, station, fixed.x])
	frame.set_sweep(20.0)
	_check("the_wing_turns_about_its_drawn_pivot_by_the_angle_asked", ok, "; ".join(detail))


## THE WING IS WHERE [D] DRAWS IT, VERTICALLY, over the ground the tyres stand on. This is the check that tells the
## right fix for a wing clipping a nacelle from the TEMPTING WRONG ONE: lifting the whole wing clears the nacelle, and
## the glove's slot is built round the wing's plane so it follows it up, and every other check stays green. Measured
## on the mutant: lifting the wing 0.12 m over a nacelle raised into its path turned only this line red.
func _the_wing_is_at_its_drawn_height_over_the_tyres(frame: TomcatAirframe) -> void:
	var ground: float = _drawn_bounds(frame.find_child("NoseGear", true, false) as Node3D, frame).position.y
	var detail: PackedStringArray = []
	var ok := true
	for sweep in [20.0, 68.0]:
		frame.set_sweep(sweep)
		var under: float = _drawn_bounds(frame.find_child("WingStarboard", true, false) as Node3D, frame).position.y - ground
		ok = ok and absf(under - WING_UNDER) < 0.03
		detail.append("%.0f deg: underside %.3f m over the tyres, drawn %.2f" % [sweep, under, WING_UNDER])
	frame.set_sweep(20.0)
	_check("the_wing_is_at_its_drawn_height_over_the_tyres", ok, "; ".join(detail))


## A PURE FUNCTION OF THE ANGLE: the same angle arrived at from anywhere draws the same wing.
func _the_sweep_is_a_pure_function_of_the_angle(frame: TomcatAirframe) -> void:
	frame.set_sweep(50.0)
	var direct := _plan_points(frame, "WingPort")
	frame.set_sweep(75.0)
	frame.set_sweep(30.0)
	frame.set_sweep(50.0)
	var wandered := _plan_points(frame, "WingPort")
	var worst: float = 0.0
	for i in range(direct.size()):
		worst = maxf(worst, direct[i].distance_to(wandered[i]))
	frame.set_sweep(10.0)
	var clamped: float = frame.sweep()
	frame.set_sweep(20.0)
	_check("the_sweep_is_a_pure_function_of_the_angle", worst < 1e-5 and is_equal_approx(clamped, 20.0),
		"50 degrees direct and via 75 and 30 differ by %.7f m; 10 degrees is clamped to %.1f" % [worst, clamped])


## ONE OBJECT AT EVERY SWEEP. `DrawnParts.adrift` is the fleet's join check; a wing that swung clear of its glove at one
## angle would make a group of its own there and nowhere else, which is why it is asked at every angle and not once.
func _the_aeroplane_is_one_object_at_every_sweep(frame: TomcatAirframe) -> void:
	var detail: PackedStringArray = []
	var ok := true
	for sweep in SWEEPS:
		frame.set_sweep(sweep)
		var adrift: Array = DrawnParts.adrift(frame)
		ok = ok and adrift.is_empty()
		detail.append("%.0f deg: %s" % [sweep, "joined" if adrift.is_empty() else str(adrift)])
	frame.set_sweep(20.0)
	_check("the_aeroplane_is_one_object_at_every_sweep", ok,
		"%d parts; %s" % [DrawnParts.count(frame), "; ".join(detail)])


## THE WING PASSES THROUGH NOTHING, AT ANY SWEEP -- the fuselage, the glove, the nacelles, the fins, the stabilators.
##
## Asked BOTH WAYS AND ALONG EVERY EDGE, because each lesser version was tried and missed a case. A point just inside
## every face of the wing must be inside no other part: that catches the wing going into a body. And no other part's
## EDGE, sampled every 4 cm, may pass inside the wing, and no wing edge inside another part. The first version asked
## only for other parts' VERTICES, and a mutant that stood both fins 2 m further forward -- straight through the
## overswept wing -- stayed green: a fin is eight vertices, none of which is anywhere near where its leading edge
## slices the wing. "Inside" is ray parity, fired up and
## down only and both required odd (`modelling_here.md` section 6, the three traps), and each part is asked on its own,
## because two closed parts overlapping make a point inside both read as outside their union.
##
## The glove's slot is outside the glove's solids, so the root stub sliding in it is outside everything, and the fully
## swept panel lying over the nacelles is above them. A wing clipped into the fuselage is the case this exists for.
func _the_wing_passes_through_nothing_at_any_sweep(frame: TomcatAirframe) -> void:
	var detail: PackedStringArray = []
	var ok := true
	var parts: Dictionary = {}
	for node in frame.find_children("*", "MeshInstance3D", true, false):
		parts[String(node.name)] = node
	for sweep in SWEEPS:
		frame.set_sweep(sweep)
		var hits: PackedStringArray = []
		var soups: Dictionary = {}
		for named in parts:
			soups[named] = _soup(parts[named], frame)
		for wing in ["WingStarboard", "WingPort"]:
			var wing_soup: PackedVector3Array = soups[wing]
			var wing_box := _box_of(wing_soup)
			var probes := _just_inside(wing_soup)
			probes.append_array(_along_edges(wing_soup, AABB(wing_box.position - Vector3.ONE * 50.0, Vector3.ONE * 100.0)))
			for named in parts:
				if named.begins_with("Wing"):
					continue
				var other: PackedVector3Array = soups[named]
				var other_box := _box_of(other)
				if not other_box.grow(0.01).intersects(wing_box):
					continue
				var inside: int = 0
				for p in probes:
					if other_box.has_point(p) and _inside(other, p):
						inside += 1
				var reverse: int = 0
				for q in _along_edges(other, wing_box):
					if wing_box.has_point(q) and _inside(wing_soup, q):
						reverse += 1
				if inside > 0 or reverse > 0:
					hits.append("%s/%s %d+%d" % [wing, named, inside, reverse])
		ok = ok and hits.is_empty()
		detail.append("%.0f deg: %s" % [sweep, "clear" if hits.is_empty() else ", ".join(hits)])
	frame.set_sweep(20.0)
	_check("the_wing_passes_through_nothing_at_any_sweep", ok, "; ".join(detail))


## THE CREW AND THEIR ROOM ARE INSIDE WHAT IS DRAWN. Ten craft fail the fleet's version of this. Both eyes -- pilot and
## RIO in tandem -- must be inside the Fuselage, and so must a grid over all six faces of the room the airframe promises.
func _the_crew_and_their_room_are_inside_the_canopy(frame: TomcatAirframe) -> void:
	var skin := _soup(frame.get_node("Fuselage") as MeshInstance3D, frame)
	var eyes_in: int = 0
	for eye in frame.crew_eyes():
		if _inside(skin, eye):
			eyes_in += 1
	var room: AABB = frame.cabin_room()["room"]
	var outside: int = 0
	var asked: int = 0
	for i in range(5):
		for j in range(5):
			for k in range(5):
				if i != 0 and i != 4 and j != 0 and j != 4 and k != 0 and k != 4:
					continue
				var p: Vector3 = room.position + room.size * Vector3(i / 4.0, j / 4.0, k / 4.0)
				asked += 1
				if not _inside(skin, p):
					outside += 1
	_check("the_crew_and_their_room_are_inside_the_canopy", eyes_in == 2 and outside == 0,
		"%d of 2 eyes inside the fuselage; %d of %d points on the promised room outside it" % [eyes_in, outside, asked])


func _every_face_is_wound_outwards(frame: Node3D) -> void:
	var wrong: int = 0
	var total: int = 0
	for node in frame.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
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
	_check("every_face_is_wound_outwards", wrong == 0 and total > 0, "%d of %d faces wound against their normal" % [wrong, total])


## THE BUDGET for a first exterior LOD (`aircraft_model_fidelity_plan.md`): at most 100,000 triangles and 30 draw calls
## -- one per named part, and this aeroplane has twenty-two -- with the small fittings distance-culled. Scope stated:
## the whole TomcatAirframe subtree.
func _the_exterior_meets_the_first_lod_budget(frame: Node3D) -> void:
	var triangles: int = 0
	var draws: int = 0
	var culled: int = 0
	for node in frame.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.visibility_range_end > 0.0:
			culled += 1
		for s in range(drawn.mesh.get_surface_count()):
			draws += 1
			triangles += (drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_check("the_exterior_meets_the_first_lod_budget", triangles <= 100000 and draws <= 30 and culled >= 3,
		"the whole TomcatAirframe subtree: %d triangles, %d draw surfaces, %d distance-culled" % [triangles, draws, culled])


## THE WING SWEEP AS A VERTEX ANIMATION TEXTURE, held to the parts it was baked from.
##
## A `VatCasting` is poured from a SECOND airframe with the airframe's own `features()`, and every vertex of both wings
## is played by the CPU copy of the shader's formula (`VatCasting.played_point`) and compared with where the first
## airframe's parts draw it, at sweeps chosen OFF THE GRID -- `vat`'s lesson: a blending check that asks at a row reads
## 0.00000 m whatever the row count. It is not independent of the shader, but it is the number the row count buys.
##
## AND IT PROVES vat's HARD PRECONDITION, which is the reason it lives in this suite: with a casting attached, the
## drawn-part checks must go on measuring the PATTERN. `DrawnParts.count` and `adrift` are asked before and after the
## pour and must agree -- a casting is one more mesh overlapping every part, which to a union of boxes joins anything.
func _the_vat_draws_the_sweep_where_the_parts_are(parts: TomcatAirframe) -> void:
	var cast := TomcatAirframe.new()
	add_child(cast)
	cast.dress()
	var before: int = DrawnParts.count(cast)
	var vat: VatCasting = await VatCasting.pour(cast, cast.features())
	var after: int = DrawnParts.count(cast)
	var adrift: Array = DrawnParts.adrift(cast)
	var worst: float = 0.0
	var worst_at: String = ""
	for sweep in [21.37, 33.71, 47.29, 60.83, 67.53, 74.61]:
		parts.set_sweep(sweep)
		for wing in ["WingStarboard", "WingPort"]:
			var truth_part := parts.find_child(wing, true, false) as MeshInstance3D
			var column: int = vat.columns.find(cast.find_child(wing, true, false))
			var tags: Vector2i = vat.features_of(column)
			for vertex in (truth_part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var truth: Vector3 = parts.global_transform.affine_inverse() * truth_part.global_transform * vertex
				var played: Vector3 = vat.played_point(column, vat.rest_poses[column] * vertex, tags.x, tags.y,
					[sweep, 0.0, 0.0, 0.0, 0.0])
				if played.distance_to(truth) > worst:
					worst = played.distance_to(truth)
					worst_at = "%s at %.2f deg" % [wing, sweep]
	parts.set_sweep(20.0)
	# FOUR PARTS RIDE THE SWEEP: the two wing panels and, on them, the two wings' spoilers.
	var moved: int = int(vat.moved_by.get("sweep", 0))
	_check("the_vat_draws_the_sweep_where_the_parts_are",
		moved == 4 and worst < 0.001 and after == before and adrift.is_empty(),
		"the sweep table moves %d parts (both wings and both wings' spoilers) in %d rows; worst wing vertex %.5f m off its part (%s), by the CPU copy of the shader; drawn parts %d before the pour and %d after, adrift after %s"
			% [moved, TomcatAirframe.SWEEP_ROWS, worst, worst_at, before, after, adrift])
	cast.queue_free()


## ---- the surfaces that follow the stick ----------------------------------------------------------------------------

## THE SURFACES FOLLOW THE STICK, ONE AXIS AT A TIME, drawn by a `VehicleView` of the kind handed a linkage as `draw`
## hands it one. The F-16 lane's lesson: pushing every axis at once hides a swapped one, because with both axes at 1 a
## swap changes nothing. So each axis alone, both ways, and every other surface must not have moved:
## - roll right: the STARBOARD spoilers rise and the port ones stay down; the starboard tailplane's trailing edge rises
##   and the port one's falls;
## - pitch up: both tailplanes' trailing edges rise, by the same amount, and no spoiler moves;
## - right pedal: both rudders' trailing edges go to starboard;
## - roll right with the wing at 68 degrees: no spoiler moves (the lockout), and the tailplanes still roll it;
## - centred again: everything back where it was built.
func _the_surfaces_follow_the_stick_one_axis_at_a_time() -> void:
	var view := (load("res://objects/vehicles/craft_tomcat.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var frame := view.find_child("Tomcat", true, false) as TomcatAirframe
	if frame == null:
		_check("the_surfaces_follow_the_stick_one_axis_at_a_time", false, "the view drew no TomcatAirframe")
		view.queue_free()
		return
	var rest: Dictionary = _trailing_edges(frame)
	var said: PackedStringArray = []
	var ok := true
	for pose in [[Vector2(1, 0), 0.0, "roll right"], [Vector2(-1, 0), 0.0, "roll left"], [Vector2(0, 1), 0.0, "pitch up"],
			[Vector2(0, -1), 0.0, "pitch down"], [Vector2.ZERO, 1.0, "right pedal"], [Vector2.ZERO, -1.0, "left pedal"]]:
		view.draw_the_tomcats_surfaces_from({"linked_stick": pose[0], "linked_rudder": pose[1]})
		var d: Dictionary = _moved(rest, _trailing_edges(frame))
		var stick: Vector2 = pose[0]
		var yaw: float = pose[1]
		var here := true
		here = here and (d["SpoilersStarboard"].y > 0.1 if stick.x > 0.5 else absf(d["SpoilersStarboard"].y) < 0.001)
		here = here and (d["SpoilersPort"].y > 0.1 if stick.x < -0.5 else absf(d["SpoilersPort"].y) < 0.001)
		# The tailplanes' trailing edges: pitch moves both one way, roll moves them apart, starboard up for right roll.
		here = here and _sign(d["StabilatorStarboard"].y) == signf(stick.y + stick.x) \
			and _sign(d["StabilatorPort"].y) == signf(stick.y - stick.x)
		if absf(stick.y) > 0.5:
			here = here and absf(d["StabilatorStarboard"].y - d["StabilatorPort"].y) < 0.001
		for rudder in ["RudderStarboard", "RudderPort"]:
			here = here and _sign(d[rudder].x) == signf(yaw)
		ok = ok and here
		said.append("%s%s: spoilers %+.2f/%+.2f, tails %+.2f/%+.2f, rudders %+.2f/%+.2f m" % [pose[2], "" if here else " WRONG",
			d["SpoilersStarboard"].y, d["SpoilersPort"].y, d["StabilatorStarboard"].y, d["StabilatorPort"].y,
			d["RudderStarboard"].x, d["RudderPort"].x])
	# THE LOCKOUT, drawn: the wing well past 57, the stick hard right.
	view.draw_the_tomcats_surfaces_from({})
	frame.set_sweep(LOCKED_OUT_AT)
	var swept_rest: Dictionary = _trailing_edges(frame)
	view.draw_the_tomcats_surfaces_from({"linked_stick": Vector2(1, 0)})
	var locked: Dictionary = _moved(swept_rest, _trailing_edges(frame))
	var lock_ok: bool = absf(locked["SpoilersStarboard"].y) < 0.001 and absf(locked["SpoilersPort"].y) < 0.001 \
		and locked["StabilatorStarboard"].y > 0.1 and locked["StabilatorPort"].y < -0.1
	said.append("roll right at %.0f deg%s: spoilers %+.3f/%+.3f, tails %+.2f/%+.2f m" % [LOCKED_OUT_AT,
		"" if lock_ok else " WRONG", locked["SpoilersStarboard"].y, locked["SpoilersPort"].y,
		locked["StabilatorStarboard"].y, locked["StabilatorPort"].y])
	view.draw_the_tomcats_surfaces_from({})
	frame.set_sweep(20.0)
	var back: Dictionary = _moved(rest, _trailing_edges(frame))
	var returned := true
	for part in back:
		returned = returned and (back[part] as Vector3).length() < 0.0001
	_check("the_surfaces_follow_the_stick_one_axis_at_a_time", ok and lock_ok and returned,
		"%s; centred again %s" % ["; ".join(said), returned])
	view.queue_free()


## THE STICK ON A REAL WIRE MOVES THE SURFACES: a server and a client world, the client seated as the Tomcat's pilot and
## flying it with the frame a seated player's rig sends (roll, then pitch, then the pedals), and what the CLIENT's world
## hands back as the linkage drawn by a view. The last thing a human touches here is the input frame; nothing between it
## and the drawn trailing edges is called by this check.
func _the_stick_on_a_real_wire_moves_the_surfaces() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("the_stick_on_a_real_wire_moves_the_surfaces", false, "no CockpitWorld")
		return
	var server: Object = ClassDB.instantiate("CockpitWorld")
	var client: Object = ClassDB.instantiate("CockpitWorld")
	for world in [server, client]:
		world.set_tick_rate(120.0)
	server.start(0)
	client.start(PEER)
	_wire(server, client, {}, 90)
	var me: int = int(client.local_client_id())
	server.spawn_pilot(me, TOMCAT_KIND, Vector3(0.0, 1500.0, 0.0), 0.0, Vector3(0.0, 0.0, -150.0))
	_wire(server, client, {}, 30)
	var craft: int = 0
	for state in client.vehicle_states():
		if int((state as Dictionary).get("kind", -1)) == TOMCAT_KIND:
			craft = int((state as Dictionary).get("entity", 0))
	var view := (load("res://objects/vehicles/craft_tomcat.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var frame := view.find_child("Tomcat", true, false) as TomcatAirframe
	var rest: Dictionary = _trailing_edges(frame)
	var said: PackedStringArray = []
	var ok: bool = craft != 0 and frame != null
	for pose in [[{"roll": 1.0}, "roll"], [{"pitch": 1.0}, "pitch"], [{"rudder": 1.0}, "rudder"]]:
		_wire(server, client, pose[0], 30)
		var linkage: Dictionary = client.crew_controls(craft)
		view.draw_the_tomcats_surfaces_from(linkage)
		var d: Dictionary = _moved(rest, _trailing_edges(frame))
		var here: bool
		match pose[1]:
			"roll":
				here = d["SpoilersStarboard"].y > 0.1 and d["StabilatorStarboard"].y > 0.1 and d["StabilatorPort"].y < -0.1 \
					and absf(d["RudderStarboard"].x) < 0.001
			"pitch":
				here = d["StabilatorStarboard"].y > 0.1 and d["StabilatorPort"].y > 0.1 \
					and absf(d["SpoilersStarboard"].y) < 0.001 and absf(d["SpoilersPort"].y) < 0.001
			_:
				here = d["RudderStarboard"].x > 0.03 and d["RudderPort"].x > 0.03 and absf(d["SpoilersStarboard"].y) < 0.001
		ok = ok and here
		said.append("%s: linkage stick %s rudder %.2f -> spoilers %+.2f/%+.2f, tails %+.2f/%+.2f, rudders %+.2f m" % [
			pose[1], linkage.get("linked_stick", "none"), float(linkage.get("linked_rudder", 0.0)), d["SpoilersStarboard"].y,
			d["SpoilersPort"].y, d["StabilatorStarboard"].y, d["StabilatorPort"].y, d["RudderStarboard"].x])
	for world in [server, client]:
		world.teardown()
		if not (world is RefCounted):
			world.free()
	view.queue_free()
	_check("the_stick_on_a_real_wire_moves_the_surfaces", ok, "client %d flies Tomcat %d; %s" % [me, craft, "; ".join(said)])


## THE SPOILERS RIDE THE SWING WING: raised, they are the same shape in the wing panel's own frame at every sweep to 55
## -- the hinge line swings with the panel -- and lying down they are there at every sweep to 75. A spoiler hinged to
## the fuselage would stay put while the wing swung out from under it.
func _the_spoilers_ride_the_swing_wing(frame: TomcatAirframe) -> void:
	var worst: float = 0.0
	var detail: PackedStringArray = []
	for amount in [1.0, 0.0]:
		frame.set_sweep(20.0)
		frame.set_spoilers(amount)
		var built: PackedVector3Array = _in_wing(frame, "SpoilersStarboard", "WingStarboard")
		for sweep in ([30.0, 44.0, 55.0] if amount > 0.0 else [44.0, 68.0, 75.0]):
			frame.set_sweep(sweep)
			var now: PackedVector3Array = _in_wing(frame, "SpoilersStarboard", "WingStarboard")
			var here: float = 0.0
			for i in range(built.size()):
				here = maxf(here, built[i].distance_to(now[i]))
			worst = maxf(worst, here)
			detail.append("%s at %.0f deg %.6f m" % ["raised" if amount > 0.0 else "down", sweep, here])
	frame.set_sweep(20.0)
	frame.set_spoilers(0.0)
	_check("the_spoilers_ride_the_swing_wing", worst < 1e-4,
		"the starboard spoilers' vertices in the wing panel's own frame move by at most %.6f m as the wing sweeps: %s"
			% [worst, ", ".join(detail)])


## THE SURFACES PASS THROUGH NOTHING, at every sweep and every stick state -- the wing's own check, asked of each moving
## surface against every other part, the wing included: a point just inside every face of the surface in no other part,
## and no edge of either, sampled every 4 cm, inside the other. What it is for: an all-moving tailplane's leading edge
## rising 0.7 m under a fully swept wing, a raised spoiler going into the glove, a rudder's foot into the nacelle.
func _the_surfaces_pass_through_nothing_at_any_sweep(frame: TomcatAirframe) -> void:
	var parts: Dictionary = {}
	for node in frame.find_children("*", "MeshInstance3D", true, false):
		parts[String(node.name)] = node
	var hits: PackedStringArray = []
	var asked: int = 0
	for sweep in SURFACE_SWEEPS:
		frame.set_sweep(sweep)
		for stick in STICKS:
			frame.follow_the_stick(Vector2(stick.x, stick.y), stick.z)
			asked += 1
			var soups: Dictionary = {}
			for named in parts:
				soups[named] = _soup(parts[named], frame)
			for surface in SURFACES:
				var own: PackedVector3Array = soups[surface]
				var own_box := _box_of(own)
				var probes := _just_inside(own)
				probes.append_array(_along_edges(own, AABB(own_box.position - Vector3.ONE * 50.0, Vector3.ONE * 100.0)))
				for named in parts:
					if named == surface:
						continue
					var other: PackedVector3Array = soups[named]
					var other_box := _box_of(other)
					if not other_box.grow(0.01).intersects(own_box):
						continue
					var inside: int = 0
					var first := Vector3.INF
					for p in probes:
						if other_box.has_point(p) and _inside(other, p):
							inside += 1
							first = p if first == Vector3.INF else first
					var reverse: int = 0
					for q in _along_edges(other, own_box):
						if own_box.has_point(q) and _inside(own, q):
							reverse += 1
							first = q if first == Vector3.INF else first
					if inside > 0 or reverse > 0:
						hits.append("%s/%s %d+%d at %.0f deg, stick %s, first at station %.2f, %.2f m up, %.2f out" % [
							surface, named, inside, reverse, sweep, stick, first.z + 9.55, first.y + 1.3, first.x])
	frame.set_sweep(20.0)
	frame.follow_the_stick(Vector2.ZERO, 0.0)
	_check("the_surfaces_pass_through_nothing_at_any_sweep", hits.is_empty(),
		"%d poses (%d sweeps x %d stick states), 6 surfaces against every other part: %s" % [asked, SURFACE_SWEEPS.size(),
			STICKS.size(), "clear" if hits.is_empty() else ", ".join(hits.slice(0, 12))])


## EVERY SURFACE AS A VERTEX ANIMATION TEXTURE, held to the parts: `the_vat_draws_the_sweep_where_the_parts_are`'s
## method for the stick's four features. Every vertex of every moving part, played by the CPU copy of the shader, against
## where the parts draw it -- ONE FEATURE AT A TIME first, both ways and OFF the grid (a swapped table reads right when
## every axis moves at once), then everything at once with the wing swept, where a spoiler is played through two tables,
## its own hinge inside the sweep. And which features each part answers to, read back off the cast mesh.
func _the_vat_draws_every_surface_where_the_parts_are(parts: TomcatAirframe) -> void:
	var cast := TomcatAirframe.new()
	add_child(cast)
	cast.dress()
	var vat: VatCasting = await VatCasting.pour(cast, cast.features())
	var names: Array = []
	for feature in vat.features:
		names.append(feature["name"])
	# [sweep, spoilers, pitch, roll, rudder], in `features()` order.
	var poses: Array = [
		[20.0, 0.37, 0.0, 0.0, 0.0], [20.0, -0.81, 0.0, 0.0, 0.0], [20.0, 0.0, 0.53, 0.0, 0.0], [20.0, 0.0, -0.29, 0.0, 0.0],
		[20.0, 0.0, 0.0, 0.61, 0.0], [20.0, 0.0, 0.0, -0.94, 0.0], [20.0, 0.0, 0.0, 0.0, 0.73], [20.0, 0.0, 0.0, 0.0, -0.46],
		[44.29, 0.67, 0.41, -0.58, 0.22], [33.71, -0.93, -0.66, 0.87, -0.41], [54.83, 0.99, 0.97, 0.99, 0.97],
		[71.13, 0.0, -0.87, -0.35, 0.58]]
	var worst: Dictionary = {}
	var worst_at: Dictionary = {}
	for pose in poses:
		parts.set_sweep(pose[0])
		parts.set_spoilers(pose[1])
		parts.set_stabilators(pose[2], pose[3])
		parts.set_rudders(pose[4])
		for surface in SURFACES + ["WingStarboard", "WingPort"]:
			var truth_part := parts.find_child(surface, true, false) as MeshInstance3D
			var column: int = vat.columns.find(cast.find_child(surface, true, false))
			var tags: Vector2i = vat.features_of(column)
			for vertex in (truth_part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var truth: Vector3 = parts.global_transform.affine_inverse() * truth_part.global_transform * vertex
				var played: Vector3 = vat.played_point(column, vat.rest_poses[column] * vertex, tags.x, tags.y, pose)
				var off: float = played.distance_to(truth)
				if off > float(worst.get(surface, -1.0)):
					worst[surface] = off
					worst_at[surface] = str(pose)
	parts.set_sweep(20.0)
	parts.follow_the_stick(Vector2.ZERO, 0.0)
	var tags_of: Dictionary = {}
	for surface in SURFACES:
		var t: Vector2i = vat.features_of(vat.columns.find(cast.find_child(surface, true, false)))
		tags_of[surface] = [names[t.x] if t.x >= 0 else "-", names[t.y] if t.y >= 0 else "-"]
	var tags_ok: bool = tags_of["SpoilersStarboard"] == ["spoilers", "sweep"] and tags_of["SpoilersPort"] == ["spoilers", "sweep"] \
		and tags_of["StabilatorStarboard"] == ["roll", "pitch"] and tags_of["StabilatorPort"] == ["roll", "pitch"] \
		and tags_of["RudderStarboard"] == ["rudder", "-"] and tags_of["RudderPort"] == ["rudder", "-"]
	var moved_ok: bool = int(vat.moved_by.get("spoilers", 0)) == 2 and int(vat.moved_by.get("pitch", 0)) == 2 \
		and int(vat.moved_by.get("roll", 0)) == 2 and int(vat.moved_by.get("rudder", 0)) == 2
	var all_worst: float = 0.0
	var report: PackedStringArray = []
	for surface in worst:
		all_worst = maxf(all_worst, float(worst[surface]))
		report.append("%s %.5f m at %s" % [surface, worst[surface], worst_at[surface]])
	_check("the_vat_draws_every_surface_where_the_parts_are", all_worst < 0.001 and tags_ok and moved_ok,
		"%d poses, every vertex of %d parts; worst %.5f m; %s; each surface's (inner, outer) tables %s; parts each feature moves %s; rows spoilers %d, tails and rudders %d"
			% [poses.size(), worst.size(), all_worst, "; ".join(report), tags_of, vat.moved_by, TomcatAirframe.SPOILER_ROWS,
				TomcatAirframe.SURFACE_ROWS])
	cast.queue_free()


## A step of the two-world wire: the client's input frame, both worlds ticked, packets carried each way.
func _wire(server: Object, client: Object, hands: Dictionary, ticks: int) -> void:
	var frame: Dictionary = {"throttle": 0.8, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0}
	for key in hands:
		frame[key] = hands[key]
	for i in range(ticks):
		client.set_input(frame)
		server.tick(1.0 / 120.0)
		client.tick(1.0 / 120.0)
		for packet in server.take_outbound():
			client.deliver(0, packet["bytes"], packet["bits"])
		for packet in client.take_outbound():
			server.deliver(PEER, packet["bytes"], packet["bits"])


## EACH SURFACE'S TRAILING EDGE, the mean of its aft-most drawn vertices, in the airframe's frame.
func _trailing_edges(frame: Node3D) -> Dictionary:
	var out: Dictionary = {}
	for part in SURFACES:
		var points := _soup(frame.find_child(part, true, false) as MeshInstance3D, frame)
		var aft: float = -INF
		for p in points:
			aft = maxf(aft, p.z)
		var sum := Vector3.ZERO
		var n: int = 0
		for p in points:
			if p.z > aft - 0.01:
				sum += p
				n += 1
		out[part] = sum / float(maxi(n, 1))
	return out


func _moved(rest: Dictionary, now: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for part in rest:
		out[part] = (now[part] as Vector3) - (rest[part] as Vector3)
	return out


## Which way a surface moved, to the centimetre: 0 for "did not".
static func _sign(metres: float) -> float:
	return 0.0 if absf(metres) < 0.01 else signf(metres)


## A PART'S DRAWN VERTICES IN ANOTHER PART'S OWN FRAME.
func _in_wing(frame: Node3D, part: String, wing: String) -> PackedVector3Array:
	var into: Transform3D = (frame.find_child(wing, true, false) as Node3D).global_transform.affine_inverse() \
		* (frame.find_child(part, true, false) as Node3D).global_transform
	var out := PackedVector3Array()
	for p in ((frame.find_child(part, true, false) as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		out.append(into * p)
	return out


## ---- measuring helpers ---------------------------------------------------------------------------------------------

## EVERY DRAWN VERTEX of `root` (or one part of it) in `frame`'s space, through transformed vertices and never
## `transform * get_aabb()`.
func _drawn_bounds(root: Node3D, frame: Node3D = null) -> AABB:
	var into_frame: Node3D = frame if frame != null else root
	var box := AABB()
	var any := false
	var nodes: Array = [root] if root is MeshInstance3D else root.find_children("*", "MeshInstance3D", true, false)
	for node in nodes:
		for p in _soup(node as MeshInstance3D, into_frame):
			box = box.expand(p) if any else AABB(p, Vector3.ZERO)
			any = true
	return box


## A PART'S TRIANGLES, three points each, in `frame`'s space.
func _soup(drawn: MeshInstance3D, frame: Node3D) -> PackedVector3Array:
	var into := frame.global_transform.affine_inverse() * drawn.global_transform
	var out := PackedVector3Array()
	for s in range(drawn.mesh.get_surface_count()):
		for p in (drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			out.append(into * p)
	return out


static func _box_of(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(p)
	return box


## A POINT JUST INSIDE EACH FACE: its centroid, 3 mm in against the face's outward normal.
static func _just_inside(soup: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(0, soup.size() - 2, 3):
		var normal: Vector3 = (soup[i + 2] - soup[i]).cross(soup[i + 1] - soup[i])
		if normal.length_squared() < 1e-10:
			continue
		out.append((soup[i] + soup[i + 1] + soup[i + 2]) / 3.0 - normal.normalized() * 0.003)
	return out


## POINTS ALONG EVERY EDGE of the soup's triangles that come near `box`, every 4 cm, ends included.
static func _along_edges(soup: PackedVector3Array, box: AABB) -> PackedVector3Array:
	var out := PackedVector3Array()
	var near := box.grow(0.05)
	for i in range(0, soup.size() - 2, 3):
		var tri := AABB(soup[i], Vector3.ZERO).expand(soup[i + 1]).expand(soup[i + 2])
		if not tri.intersects(near):
			continue
		for e in [[0, 1], [1, 2], [2, 0]]:
			var a: Vector3 = soup[i + e[0]]
			var b: Vector3 = soup[i + e[1]]
			var steps: int = maxi(1, ceili(a.distance_to(b) / 0.04))
			for k in range(steps + 1):
				out.append(a.lerp(b, float(k) / steps))
	return out


## INSIDE A CLOSED SOUP, by ray parity fired straight up AND straight down, both required odd. The ray is nudged 0.7 mm
## off the point in plan, so it does not run down a symmetric model's vertices (`modelling_here.md` section 6).
static func _inside(soup: PackedVector3Array, p: Vector3) -> bool:
	var q := Vector2(p.x + 0.00071, p.z + 0.00053)
	var above: int = 0
	var below: int = 0
	for i in range(0, soup.size() - 2, 3):
		var a: Vector3 = soup[i]
		var b: Vector3 = soup[i + 1]
		var c: Vector3 = soup[i + 2]
		var hit: Variant = _vertical_hit(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z), q, a.y, b.y, c.y)
		if hit == null:
			continue
		if float(hit) > p.y:
			above += 1
		else:
			below += 1
	return above % 2 == 1 and below % 2 == 1


## Where a vertical line through `q` meets a triangle, as a height, or null if it misses.
static func _vertical_hit(a: Vector2, b: Vector2, c: Vector2, q: Vector2, ya: float, yb: float, yc: float) -> Variant:
	var d: float = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
	if absf(d) < 1e-12:
		return null
	var u: float = ((b.y - c.y) * (q.x - c.x) + (c.x - b.x) * (q.y - c.y)) / d
	var v: float = ((c.y - a.y) * (q.x - c.x) + (a.x - c.x) * (q.y - c.y)) / d
	var w: float = 1.0 - u - v
	if u < 0.0 or v < 0.0 or w < 0.0:
		return null
	return u * ya + v * yb + w * yc


## A PART'S DRAWN VERTICES IN PLAN, as (x, z) in the craft's frame, in the mesh's own vertex order.
func _plan_points(frame: Node3D, part: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in _soup(frame.find_child(part, true, false) as MeshInstance3D, frame):
		out.append(Vector2(p.x, p.z))
	return out


## THE RIGID TURN carrying `before` onto `after` in plan: its angle from the change in direction between the two most
## distant vertices, and its fixed point solved from the centroids. Returns {"fixed": Vector2(x, z), "angle": radians}.
static func _rigid_turn(before: PackedVector2Array, after: PackedVector2Array) -> Dictionary:
	var far: int = 0
	for i in range(before.size()):
		if before[i].distance_to(before[0]) > before[far].distance_to(before[0]):
			far = i
	var angle: float = (after[far] - after[0]).angle() - (before[far] - before[0]).angle()
	angle = wrapf(angle, -PI, PI)
	var cb := Vector2.ZERO
	var ca := Vector2.ZERO
	for i in range(before.size()):
		cb += before[i]
		ca += after[i]
	cb /= before.size()
	ca /= after.size()
	# after = R (before - fixed) + fixed  ->  (I - R) fixed = after - R before, for the centroids.
	var r := Transform2D(angle, Vector2.ZERO)
	var rhs: Vector2 = ca - r * cb
	var m00: float = 1.0 - cos(angle)
	var m01: float = sin(angle)
	var m10: float = -sin(angle)
	var m11: float = 1.0 - cos(angle)
	var det: float = m00 * m11 - m01 * m10
	var fixed := Vector2((rhs.x * m11 - m01 * rhs.y) / det, (m00 * rhs.y - m10 * rhs.x) / det)
	# In plan the turn is about +Y, which takes +X towards -Z; Vector2 angles run from +X towards +Y, i.e. +Z. The sweep is
	# the turn's size, and a starboard wing sweeping aft turns from +X towards +Z.
	return {"fixed": fixed, "angle": angle}


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
