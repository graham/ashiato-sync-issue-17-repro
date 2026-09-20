extends Node
## WHAT A CASTING WOULD SAVE ON EVERY CRAFT, counted from the tree: RESEARCH PROBE for `research/static_bake.md`.
## Headless; read RESULT= rather than the exit code.
##
## THE MOBILE RENDERER ISSUES ONE DRAW PER SURFACE OF EVERY VISIBLE INSTANCE and never merges repeats
## (`render_forward_mobile.cpp`), so on cockpit's renderer the camera pass's draws ARE the surfaces counted here. Its own
## draw counter cannot say so: it reports the number of instances. `tests/bake_shot.gd` checked the count on two objects
## against the renderer (Forward+'s counter, which does count draws); this extends it to the fleet without rendering 29 craft.
##
## EACH CRAFT IS BUILT AS `named_parts` BUILDS IT, `setup(0, kind)`, from outside, and poured with `Casting.pour`. Counted:
## - `instances` and `surfaces`: every visible, rendered geometry instance under the view, and its surfaces;
## - `cast`: the same after the pour;
## - `left`: what the casting would not take, by why -- inside a control, station or shell; hidden when poured; not a
##   MeshInstance3D (a MultiMesh, a Label3D, a sprite);
## - `materials`: distinct materials among the parts it took, and how many survive flattening;
## - the pour's time, and one `pose()` averaged over 100 calls with nothing moving -- GDScript, on a shared machine, so a
##   size and not a budget.

var _failures: PackedStringArray = []


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL the native library is not loaded")
		get_tree().quit(1)
		return
	var sums := {"surfaces": 0, "cast": 0}
	var rows: Array[String] = []
	for kind in range(Sim.Kind.size()):
		var row: Dictionary = _survey(kind)
		sums["surfaces"] += int(row["surfaces"])
		sums["cast"] += int(row["cast"])
		rows.append("%-14s %4d inst %4d surf -> %3d inst %3d surf | poured %3d parts, %2d materials -> %d, in %.1f ms, posed in %.1f us | not poured: %s"
			% [Sim.kind_name(kind), row["instances"], row["surfaces"], row["cast_instances"], row["cast"], row["poured"],
				row["materials"], row["cast_materials"], row["pour_ms"], row["pose_us"], row["left"]])
		rows.append("%-14s   cast = %d casting surfaces + left drawing %s; parts that left the casting: %s"
			% ["", row["casting_surfaces"], row["remains"], row["left_casting"]])
		sums["casting"] = int(sums.get("casting", 0)) + int(row["casting_surfaces"])
		if int(row["cast"]) > int(row["surfaces"]):
			_failures.append("%s draws more cast than as parts" % Sim.kind_name(kind))
	for line in rows:
		print("[bake_survey] %s" % line)
	print("[bake_survey] FLEET: %d surfaces as parts, %d cast (%d of them the castings' own, %d left drawing), over %d kinds"
		% [sums["surfaces"], sums["cast"], sums["casting"], int(sums["cast"]) - int(sums["casting"]), Sim.Kind.size()])
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _survey(kind: int) -> Dictionary:
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.setup(0, kind)
	var before: Array = _tally(view)
	var left: Dictionary = {"owned": 0, "hidden": 0, "other": 0}
	for found in view.find_children("*", "GeometryInstance3D", true, false):
		var drawn := found as GeometryInstance3D
		if not (drawn is MeshInstance3D):
			if drawn.is_visible_in_tree(): left["other"] += 1
			continue
		if (drawn as MeshInstance3D).mesh == null:
			continue
		if Casting._owned(drawn):
			if drawn.is_visible_in_tree(): left["owned"] += 1
		elif not drawn.is_visible_in_tree():
			left["hidden"] += 1
	var materials: Dictionary = {}
	var started: int = Time.get_ticks_usec()
	var casting := Casting.pour(view)
	var pour_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	var posing: int = Time.get_ticks_usec()
	for i in range(100):
		casting.pose()
	var pose_us: float = float(Time.get_ticks_usec() - posing) / 100.0
	for entry in casting.parts:
		for material in entry["material"]:
			materials[material] = true
	var after: Array = _tally(view)
	# WHAT THE CAST COUNT IS MADE OF: the casting's own surfaces, and each thing it left drawing, by class and top part.
	var remains: Dictionary = {}
	for found in view.find_children("*", "GeometryInstance3D", true, false):
		var drawn := found as GeometryInstance3D
		if not drawn.is_visible_in_tree() or drawn.layers == 0 or drawn.has_meta(Casting.CAST_FROM):
			continue
		# AN EMPTY MeshInstance3D DRAWS NOTHING, and `_tally` skips it: the first breakdown counted the craft's mesh-less
		# `Hull` nodes as "left drawing" and made twelve of the fleet's draws up.
		if (drawn is MeshInstance3D and (drawn as MeshInstance3D).mesh == null) 				or (drawn is MultiMeshInstance3D and (drawn as MultiMeshInstance3D).multimesh == null):
			continue
		var top: Node = drawn
		while top.get_parent() != view: top = top.get_parent()
		var label: String = "%s %s %s(%s)" % [top.name, drawn.get_class(), drawn.name, (drawn as MeshInstance3D).mesh.get_class() if drawn is MeshInstance3D else drawn.get_class()]
		remains[label] = int(remains.get(label, 0)) + 1
	var cast_materials: Dictionary = {}
	for drawn in casting.instances:
		for surface in range(drawn.mesh.get_surface_count()):
			cast_materials[drawn.mesh.surface_get_material(surface)] = true
	var row := {"instances": before[1], "surfaces": before[0], "cast_instances": after[1], "cast": after[0],
		"poured": casting.parts.size(), "materials": materials.size(), "cast_materials": cast_materials.size(),
		"casting_surfaces": casting.surfaces(), "left_casting": ", ".join(casting.left), "remains": remains,
		"pour_ms": pour_ms, "pose_us": pose_us,
		"left": "%d in controls/stations/shells, %d hidden, %d not meshes" % [left["owned"], left["hidden"], left["other"]]}
	remove_child(view)
	view.free()
	return row


## [surfaces, instances] drawn under a view: every visible geometry instance not on layer 0, and its surfaces.
func _tally(view: Node3D) -> Array:
	var surfaces: int = 0
	var instances: int = 0
	for found in view.find_children("*", "GeometryInstance3D", true, false):
		var drawn := found as GeometryInstance3D
		if not drawn.is_visible_in_tree() or drawn.layers == 0:
			continue
		var mesh: Mesh = null
		if drawn is MeshInstance3D: mesh = (drawn as MeshInstance3D).mesh
		elif drawn is MultiMeshInstance3D and (drawn as MultiMeshInstance3D).multimesh != null:
			mesh = (drawn as MultiMeshInstance3D).multimesh.mesh
		if mesh == null and (drawn is MeshInstance3D or drawn is MultiMeshInstance3D):
			continue
		instances += 1
		surfaces += 1 if mesh == null else mesh.get_surface_count()
	return [surfaces, instances]
