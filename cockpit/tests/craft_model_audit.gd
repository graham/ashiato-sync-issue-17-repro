extends Node
## Headless: WHICH CRAFT NOBODY HAS MODELLED YET, computed from the triangles each one draws rather than read off a
## gallery photograph or a roster somebody typed. Read RESULT=, not the process exit code.
##
## THE QUESTION IS NOT "WHICH MODEL LOOKS LIKE A CRATE", and that distinction cost this lane its first hour.
## `lane/audit` was asked for "a list of craft not yet updated, so models aren't boxy", and a measure of boxiness gets
## two craft in this fleet wrong in opposite directions:
##
##   - THE GLIDER IS THE LEAST BOXY CRAFT IN THE GAME and is not a counter-example. Rounded pod, bubble canopy, T-tail,
##     built against DG Aviation's published 8.6 m envelope. Its one remaining fault is flat untapered wings, which no
##     boxiness score can see, because a plank is not a box.
##   - THE POD IS DRAWN FROM ROUNDED PRIMITIVES AND HAS NO HULL AT ALL -- an open scaffold of struts around empty air,
##     where its builder's own doc block promises "a rounded pressure hull and a distinct dark canopy". A measure that
##     counted curved surfaces would have scored it well.
##
## SO THE MEASURE IS: HOW MUCH OF THE BODY THIS CRAFT DRAWS IS FLAT SLABS SQUARE TO ITS OWN AXES. A craft nobody has
## modelled is a stack of boxes bolted to the simulation's own cuboid and reads near 1.00. A craft somebody sat down
## and lofted reads low however simple it is, because a loft has no square faces to find. `HULL` is the sharper half of
## the same question and the one that names the worst offenders outright: how much of the body lies ON the collision
## cuboid's own six faces -- that is the simulation's box, re-rendered, with a boom and a rotor stuck on it.
##
## IT RANKS AND SHOWS; IT DOES NOT PASS AND FAIL AT A FIGURE NOBODY RE-MEASURED. `ship_models` allows 250,000 triangles
## per ship while the destroyer draws 1,396, and `hitch` fails at 0.599 ms against a budget protecting 8.33 ms; both are
## limits that are not the thing they protect. There is no "a craft may be at most 0.6 flat" here and there should never
## be one, because nobody has measured what number a good model has. The table below is the output. What IS checked is
## that the ranking means something: that it is not an artefact of its own tolerance, that it separates craft with their
## own named airframe from craft drawn by a generic builder, and that the rows are twenty-five different craft.
##
## THE ANCHOR COMES FROM OUTSIDE THE THING IT JUDGES, which is the rule `lane/skyhawk` paid for: `fighter.gd` and
## `skyhawk.gd` measure an airframe against its three-view and never look at the station; `fit.gd` and `stations.gd`
## measure the station against the pilot and never look at the aeroplane; both halves were green while every craft drawn
## as itself had its station standing outside its own skin. So nothing here is read from the model's own claims. The
## BODY is defined by the simulation's collision extents, which the model did not choose. The shell question is put to
## `VehicleView.cabin_room()`, the one authority for it, and not answered a second time in this file.

## HOW FAR OFF AN AXIS A FACE MAY LEAN AND STILL COUNT AS SQUARE, in degrees. It is not a threshold anybody tuned: a
## face is square to the craft or it is not, and `_the_ranking_is_not_an_artefact_of_its_own_tolerance` re-runs the whole
## fleet at ONE degree and at TEN and requires the order it produces to survive both.
const FLAT_DEGREES := 5.0
const LOOSE_DEGREES := 10.0
const TIGHT_DEGREES := 1.0
## HOW FAR OUT OF THE COLLISION HULL A TRIANGLE MAY REACH AND STILL BE PART OF THE BODY. The wings, rotors and booms
## this excludes are not decoration -- they are the rest of the aeroplane -- but they are drawn by a different decision
## from the fuselage and would drown it: the glider's 20 m wing is forty times the volume of the pod it hangs on.
const BODY_REACH := 1.15
## HOW CLOSE TO THE COLLISION CUBOID'S OWN FACE A TRIANGLE MUST LIE TO COUNT AS THAT FACE, as a fraction of the extent.
const FACE_TOLERANCE := 0.04
## Triangles smaller than this contribute nothing and are dropped, in square metres, so a degenerate strip cannot swing
## a fraction. Measured: dropping them moves no craft's FLAT by more than 0.002.
const SPECK := 1e-6
var _failures: PackedStringArray = []
var _rows: Array = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[craft_model_audit] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var ready: bool = ClassDB.class_exists("CockpitWorld")
	_check("the_native_library_is_loaded", ready, "CockpitWorld %s" % ready)
	if not ready:
		_finish()
		return
	_rows = _measure_every_craft(FLAT_DEGREES)
	_the_rows_are_twenty_five_different_craft()
	_the_body_filter_keeps_a_body_and_drops_the_wings()
	_the_ranking_is_not_an_artefact_of_its_own_tolerance()
	_a_craft_with_its_own_airframe_outranks_one_drawn_by_a_generic_builder()
	_print_the_list()
	_finish()


## EVERY KIND IN THE GAME, BUILT AND MEASURED, in one pass. Built through `preview_kind` and `_show_in_editor()` with no
## world running, which is how `tests/skyhawk.gd` asks all twenty-five for their `cabin_room()`.
##
## NOT SPAWNED AND LOOKED UP BY ID. `hawkeye_shot.gd` photographed a patrol boat eight times by keying `Sim.current` on
## the id a spawn returned -- which is the SERVER's -- and on 2026-09-17 `lane/train` found no railway carriage was being
## drawn ANY MORE for the same reason. The true version is the stronger warning: the carriages HAD been drawn -- a
## gallery picture from 10:42 that day has five of them -- and had stopped by 14:20. The client creates entities as
## records ARRIVE and the server creates them as it SPAWNS, so a server id used against the client registry is right
## only while the two orders happen to agree. A bug that never worked is found the first time somebody looks; one that
## works until an unrelated change reorders the spawns empties every train in the game on a commit that went nowhere
## near the railway. An audit that reports on one craft twenty-five times is green and
## useless, so this builds each kind directly and `_the_rows_are_twenty_five_different_craft` proves they differ.
func _measure_every_craft(degrees: float) -> Array:
	var rows: Array = []
	for kind in range(Sim.Kind.size()):
		var view := (load("res://objects/vehicles/craft_plane.tscn") as PackedScene).instantiate() as VehicleView
		add_child(view)
		view.preview_kind = kind
		view._show_in_editor()
		var extents: Vector3 = Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3
		var row: Dictionary = _measure(view, extents, degrees)
		row["kind"] = kind
		row["name"] = Sim.kind_name(kind)
		# ASKED OF THE AUTHORITY, NOT ANSWERED AGAIN HERE. `VehicleView.cabin_room()` is the one place that says whether
		# a craft encloses its crew, and `because` is the word to branch on -- never the English in `why_not`.
		var said: Dictionary = view.cabin_room()
		row["encloses"] = bool(said.get("drawn", false))
		row["because"] = String(said.get("because", "?"))
		rows.append(row)
		view.queue_free()
	return rows


## WHAT ONE CRAFT DRAWS, in its own frame, weighted by area.
##
## FROM THE DRAWN VERTICES PUT INTO THE CRAFT'S FRAME, never `transform * get_aabb()`, which grows a box every time the
## thing it describes is turned and would report a banked wing as a bigger aeroplane.
##
## AND ONLY WHAT IS ON SCREEN. `_hull` stays in the tree for every craft and is hidden for most of them -- the tank,
## the train, the car, the tower and the pod all draw a body of their own OVER a collision cuboid that is switched off.
## Counting a hidden mesh would have scored every one of those a perfect 1.00 for a box nobody can see, and the five
## craft it would have flattered are five of the eight this file exists to name. A CHECK THAT CANNOT SEE THE DIFFERENCE
## BETWEEN "DRAWN AS A BOX" AND "HAS A BOX IN THE SCENE" IS NOT MEASURING THE MODEL.
func _measure(root: Node3D, extents: Vector3, degrees: float) -> Dictionary:
	var square := cos(deg_to_rad(degrees))
	var body_area := 0.0
	var flat_area := 0.0
	var hull_area := 0.0
	var whole_area := 0.0
	var body_tris := 0
	var whole_tris := 0
	var body_span := AABB()
	var whole_span := AABB()
	var reach: Vector3 = extents * BODY_REACH
	for triangle in _triangles_of(root):
		var a: Vector3 = triangle[0]
		var b: Vector3 = triangle[1]
		var c: Vector3 = triangle[2]
		var cross: Vector3 = (b - a).cross(c - a)
		var area: float = cross.length() * 0.5
		if area < SPECK:
			continue
		whole_area += area
		whole_tris += 1
		whole_span = _grow(whole_span, whole_tris == 1, [a, b, c])
		if not (_within(a, reach) and _within(b, reach) and _within(c, reach)):
			continue
		body_area += area
		body_tris += 1
		body_span = _grow(body_span, body_tris == 1, [a, b, c])
		var normal: Vector3 = cross / (area * 2.0)
		var axis: int = -1
		for at in range(3):
			if absf(normal[at]) >= square:
				axis = at
		if axis < 0:
			continue
		flat_area += area
		# ON THE COLLISION CUBOID'S OWN FACE: square to an axis AND standing at the extent, which is the simulation's
		# box re-rendered rather than a slab the model chose to put there.
		var offset: float = (a[axis] + b[axis] + c[axis]) / 3.0
		if extents[axis] > 0.0 and absf(absf(offset) - extents[axis]) <= extents[axis] * FACE_TOLERANCE:
			hull_area += area
	return {"flat": 0.0 if body_area <= 0.0 else flat_area / body_area,
		"hull": 0.0 if body_area <= 0.0 else hull_area / body_area,
		"body_area": body_area, "whole_area": whole_area, "body_span": body_span, "whole_span": whole_span,
		"body_tris": body_tris, "whole_tris": whole_tris, "extents": extents}


## A box grown over three points, started rather than expanded on the first one, because an AABB that starts at the
## origin contains the origin and every craft here is drawn around it.
func _grow(box: AABB, first: bool, points: Array) -> AABB:
	var out: AABB = AABB(points[0], Vector3.ZERO) if first else box
	for point in points:
		out = out.expand(point)
	return out


func _within(point: Vector3, reach: Vector3) -> bool:
	return absf(point.x) <= reach.x and absf(point.y) <= reach.y and absf(point.z) <= reach.z


## EVERY VISIBLE TRIANGLE UNDER A NODE, three vertices to an entry, in that node's frame.
func _triangles_of(root: Node3D) -> Array:
	var out: Array = []
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var drawn := child as MeshInstance3D
		if drawn.mesh == null or not _shown(root, drawn):
			continue
		var into := Transform3D.IDENTITY
		var cursor: Node3D = drawn
		while cursor != root and cursor != null:
			into = cursor.transform * into
			cursor = cursor.get_parent() as Node3D
		# `surface_get_primitive_type` IS ArrayMesh'S AND NOT Mesh'S: asked of a BoxMesh it raises "Nonexistent
		# function" and returns null, so a filter on it silently drops every box, cylinder and capsule -- which in this
		# file is exactly the set the answer is about. `tests/skyhawk.gd` paid for that one first.
		var built := drawn.mesh as ArrayMesh
		for surface in range(drawn.mesh.get_surface_count()):
			if built != null and built.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arrays: Array = drawn.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: Variant = arrays[Mesh.ARRAY_INDEX]
			var order := PackedInt32Array()
			if index != null and (index as PackedInt32Array).size() > 0:
				order = index as PackedInt32Array
			else:
				for at in range(vertices.size()):
					order.append(at)
			for at in range(0, order.size() - 2, 3):
				out.append([into * vertices[order[at]], into * vertices[order[at + 1]],
					into * vertices[order[at + 2]]])
	return out


## Is this mesh on screen, all the way up to the craft? `visible` is per node and a shown child of a hidden parent is
## not drawn; `is_visible_in_tree()` cannot answer here because none of this is in a viewport.
func _shown(root: Node3D, drawn: MeshInstance3D) -> bool:
	var cursor: Node3D = drawn
	while cursor != null:
		if not cursor.visible:
			return false
		if cursor == root:
			return true
		cursor = cursor.get_parent() as Node3D
	return true


## TWENTY-FIVE DIFFERENT CRAFT, PROVED, and not one craft reported twenty-five times.
##
## Every row carries a fingerprint of what it actually measured. Two kinds that drew the same triangles in the same
## places would collapse to one fingerprint, which is what a lookup keyed on the wrong id does and what makes that bug
## invisible: the run is green, the table is full, and every line is the same aeroplane.
##
## THE FINGERPRINT IS TAKEN FROM THE DRAWING AND FROM NOTHING ELSE, and the first version was not. It read
## `whole_tris/body_tris/whole_area/body_area/extents`, and when this suite was deliberately sabotaged on 2026-09-17 to
## build a Cessna twenty-five times over, **it came back with twenty-five distinct fingerprints and passed**. The body
## figures and the extents are read from `Sim.geometry_of(kind)`, so they went on varying by kind while the aeroplane
## did not: the check was proving that twenty-five different kinds exist, which nobody doubted, rather than that
## twenty-five different craft were drawn. A fingerprint that mixes what was drawn with what the kind declares cannot
## notice that the wrong thing was drawn. Sabotaged again with the fingerprint above, it collapses to one and fails.
func _the_rows_are_twenty_five_different_craft() -> void:
	var seen: Dictionary = {}
	var duplicates: PackedStringArray = []
	var empty: PackedStringArray = []
	for row in _rows:
		var print_: String = "%d/%.4f/%s" % [row["whole_tris"], row["whole_area"], row["whole_span"]]
		if seen.has(print_):
			duplicates.append("%s and %s drew the same thing" % [row["name"], seen[print_]])
		seen[print_] = row["name"]
		if int(row["whole_tris"]) <= 0:
			empty.append(String(row["name"]))
	_check("and_the_rows_are_that_many_different_craft_rather_than_one_craft_that_many_times",
		duplicates.is_empty() and _rows.size() == Sim.Kind.size(),
		"%d kinds, %d distinct fingerprints, %d drawing nothing (%s)" % [_rows.size(), seen.size(),
			empty.size(), ", ".join(empty) if not empty.is_empty() else "none"]
			if duplicates.is_empty() else ", ".join(duplicates))


## THE BODY FILTER KEEPS A BODY AND DROPS THE WINGS, which is the half of this that could pass by doing nothing at all.
##
## A CHECK WHOSE JOB IS TO EXCLUDE SOMETHING CANNOT TELL YOU IT EXCLUDED EVERYTHING. That is how the railway carriage
## survived: three tests walked the carriage list to hide cars, and walking an empty dictionary hides nothing and
## passes. If `BODY_REACH` were mistyped small enough, every craft would measure zero body triangles, every FLAT would
## be 0.00, and a table of twenty-five perfectly-lofted aeroplanes would print with RESULT=PASS. So the filter is held
## to both sides at once: it kept a body on every craft that draws one, AND it threw the glider's wings away.
func _the_body_filter_keeps_a_body_and_drops_the_wings() -> void:
	var bodyless: PackedStringArray = []
	for row in _rows:
		if int(row["whole_tris"]) > 0 and int(row["body_tris"]) <= 0:
			bodyless.append(String(row["name"]))
	# THE GLIDER IS THE PROOF BECAUSE ITS WING IS THE EXTREME CASE: a 20 m span on a 8.6 m pod, so a filter that kept
	# the wing would be obvious in one number. Measured against the wing itself rather than against a percentage,
	# because a percentage is a threshold nobody derived and the span is a fact about the aeroplane.
	var glider: Dictionary = _row("glider")
	var whole: AABB = glider.get("whole_span", AABB()) as AABB
	var body: AABB = glider.get("body_span", AABB()) as AABB
	var extents: Vector3 = glider.get("extents", Vector3.ZERO) as Vector3
	var wing: float = whole.size.x
	var kept: float = body.size.x
	var allowed: float = extents.x * 2.0 * BODY_REACH
	var dropped: bool = wing > allowed * 2.0 and kept <= allowed + 0.01 and kept > 0.0
	_check("and_the_body_filter_kept_a_body_on_every_craft_and_still_threw_the_gliders_wings_away",
		bodyless.is_empty() and dropped,
		"the glider draws %.1f m across and its body measures %.2f m of that, inside the %.2f m the collision hull allows"
			% [wing, kept, allowed] if bodyless.is_empty() and dropped
			else "kept nothing on %s; the glider draws %.1f m across and kept %.2f m of %.2f m allowed"
			% [", ".join(bodyless), wing, kept, allowed])


## THE RANKING SURVIVES ITS ONLY CONSTANT, which is the answer to "what did somebody measure to arrive at this number".
##
## Nobody measured `FLAT_DEGREES`. There was nothing to measure: a face is square to the craft or it is not, and five
## degrees is a reading of "or it is not". So rather than defend the number, the fleet is measured again at ONE degree
## and at TEN -- a factor of ten apart -- and the ranking has to survive both.
##
## WHAT IS ASSERTED IS THAT THE TOLERANCE DOES NOT INVERT THE ANSWER: no craft in the slabbiest third at five degrees
## turns up in the best third at one or at ten, or the other way about. It is deliberately NOT "every craft holds its
## place", which is the first version and which failed: four craft sit within a place or two of the boundary between
## the best third and the middle and swap sides as the tolerance moves. That shuffle is real and it is not a defect --
## the cessna, the uh60, the tanker and the pod are genuinely close to one another -- and demanding they hold still
## would have made the tolerance the subject of the check instead of the aeroplanes.
func _the_ranking_is_not_an_artefact_of_its_own_tolerance() -> void:
	var here: PackedStringArray = _order(_rows)
	var tight: PackedStringArray = _order(_measure_every_craft(TIGHT_DEGREES))
	var loose: PackedStringArray = _order(_measure_every_craft(LOOSE_DEGREES))
	var third: int = maxi(1, here.size() / 3)
	var inverted: PackedStringArray = []
	for at in range(here.size()):
		var band: String = _band(here, here[at], third)
		if band == "middle":
			continue
		var other: String = "best" if band == "worst" else "worst"
		for named in [["1", tight], ["10", loose]]:
			if _band(named[1] as PackedStringArray, here[at], third) == other:
				inverted.append("%s is in the %s third at %.0f degrees and the %s third at %s" % [here[at], band,
					FLAT_DEGREES, other, named[0]])
	_check("and_the_ranking_is_a_reading_of_the_aeroplanes_rather_than_of_its_own_tolerance",
		inverted.is_empty(),
		"nothing crosses between the slabbiest %d and the best %d of %d as the tolerance moves from 1 to 10 degrees"
			% [third, third, here.size()] if inverted.is_empty() else ", ".join(inverted))


## A CRAFT WITH ITS OWN AIRFRAME OUTRANKS ONE DRAWN BY A GENERIC BUILDER, which is the claim the whole measure rests on
## and the one that would be quietly wrong if FLAT were really a boxiness score.
##
## `HawkeyeAirframe`, `Uh60Airframe`, `FighterAirframe` and `SkyhawkAirframe` are four classes about four aeroplanes,
## 533 to 1,391 lines each, every dimension taken off a published three-view. `_build_car_body`, `_build_train_body` and
## `_build_tank_body` are short generic builders shared by whatever has no model of its own.
##
## THE LIGHT HELICOPTER IS IN NEITHER GROUP, since `lane/rotors` gave it `LightHelicopterAirframe` on 2026-09-17. It was
## the generic builder's fourth example -- the collision box painted yellow -- and it is no longer generic. But it cannot
## be put with the modelled four either, because THIS FILE'S BODY IS THE COLLISION BOX TIMES `BODY_REACH`, and the
## heli's cabin was drawn 2.44 m across round a 1.9 m box so that its door gunners fit: its whole skin falls outside the
## filter, and what the filter finds inside is its floor, its seats and its crew stations, which are boxes. It read 0.86,
## as slab as the carrier, for that reason alone. A body filter taken from the drawn fuselage would fix it.
##
## SO THE LINE IS DRAWN BY WHO WROTE THE BUILDER, NOT BY WHAT THIS FILE THINKS OF THE PICTURES, and every one of the
## four modelled craft has to come out below every one of the four generic ones. THE GLIDER IS DELIBERATELY IN NEITHER
## GROUP: it is drawn by a generic-looking `_build_sailplane_airframe` and is nonetheless one of the best-shaped craft
## in the game, so naming it either way would be assuming the answer.
func _a_craft_with_its_own_airframe_outranks_one_drawn_by_a_generic_builder() -> void:
	var modelled: PackedStringArray = ["hawkeye", "uh60", "fighter", "cessna"]
	var generic: PackedStringArray = ["car", "train", "tank"]
	var worst_modelled := -1.0
	var worst_name := ""
	var best_generic := 2.0
	var best_name := ""
	for name in modelled:
		var row: Dictionary = _row(name)
		if not row.is_empty() and float(row["flat"]) > worst_modelled:
			worst_modelled = float(row["flat"])
			worst_name = name
	for name in generic:
		var row: Dictionary = _row(name)
		if not row.is_empty() and float(row["flat"]) < best_generic:
			best_generic = float(row["flat"])
			best_name = name
	_check("and_every_craft_with_its_own_named_airframe_measures_less_slab_sided_than_every_craft_drawn_generically",
		worst_modelled >= 0.0 and best_generic <= 1.0 and worst_modelled < best_generic,
		"the slabbiest modelled craft is %s at %.2f, below the smoothest generic one, %s at %.2f" % [
			worst_name, worst_modelled, best_name, best_generic])


## The ranking itself: slabbiest body first, which is the order the list is read in.
func _order(rows: Array) -> PackedStringArray:
	var sorted: Array = rows.duplicate()
	sorted.sort_custom(func(a, b): return float(a["flat"]) > float(b["flat"]))
	var out := PackedStringArray()
	for row in sorted:
		out.append(String(row["name"]))
	return out


func _band(order: PackedStringArray, name: String, third: int) -> String:
	var at: int = order.find(name)
	if at < third:
		return "worst"
	if at >= order.size() - third:
		return "best"
	return "middle"


func _row(name: String) -> Dictionary:
	for row in _rows:
		if String(row["name"]) == name:
			return row
	return {}


## THE LIST. It prints on every run whether or not anything failed, because the answer somebody asked for is the table
## and not the word PASS -- and because a suite that only speaks when it is angry teaches everybody to read past it.
func _print_the_list() -> void:
	var sorted: Array = _rows.duplicate()
	sorted.sort_custom(func(a, b): return float(a["flat"]) > float(b["flat"]))
	print("[craft_model_audit] the fleet, slabbiest body first. FLAT is how much of the body inside the collision")
	print("[craft_model_audit] hull is drawn square to the craft's own axes; HULL is how much of it lies on the")
	print("[craft_model_audit] simulation's cuboid itself. SHELL is VehicleView.cabin_room().")
	print("[craft_model_audit]  #  craft         FLAT   HULL   body tris   of drawn   shell")
	var at := 0
	for row in sorted:
		at += 1
		var shell: String = "encloses" if bool(row["encloses"]) else String(row["because"])
		var share: float = 0.0 if float(row["whole_area"]) <= 0.0 \
			else float(row["body_area"]) / float(row["whole_area"]) * 100.0
		print("[craft_model_audit] %2d  %-12s  %.2f   %.2f   %9d   %5.1f%%   %s" % [at, String(row["name"]).to_lower(),
			float(row["flat"]), float(row["hull"]), int(row["body_tris"]), share, shell])


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
