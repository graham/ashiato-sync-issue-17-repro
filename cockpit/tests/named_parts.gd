extends Node
## EVERY VISIBLE MESH ON EVERY CRAFT IS A NAMED PART. Read RESULT= rather than the exit code.
##
## ---------------------------------------------------------------------------------
## THE RULE, AND THE MECHANISM NOBODY KNEW
## ---------------------------------------------------------------------------------
##
## `lane/glider` stated this rule on 2026-09-17 and nothing enforced it: **an auto-named mesh
## cannot be found by name, cannot be held to a feature contract, and does not read in a
## screenshot review as something somebody put there.** Three lanes then hit it independently in
## one afternoon -- a sailplane whose published height was being carried by an anonymous stub gun
## mount, four unnamed meshes on the first craft `lane/tank` was pointed at, and two on the water
## bomber.
##
## THE MECHANISM IS A DUPLICATE NAME, AND IT IS SILENT. `_add_airframe_part` sets `drawn.name`
## and adds the node; **Godot renames a second child given a name already in use to
## `@MeshInstance3D@9`** and says nothing. On the water bomber `_add_airframe_part` was called
## twice with `"WaterBomberPropeller"` and twice with `"WaterBomberFloatStrut"` -- inside a
## `for side in [-1.0, 1.0]` loop, which is how almost every airframe here is built. **A part
## built in a side loop needs the side in its name, and one built in an inner loop needs the
## index too.** That is the actionable half of this suite, and the message says it.
##
## ---------------------------------------------------------------------------------
## WHY A SEPARATE CHECK FROM THE JOIN CHECK, WHICH ALREADY PRINTS SOME OF THESE
## ---------------------------------------------------------------------------------
##
## `aircraft_fidelity._every_drawn_part_is_joined_to_the_aeroplane` names the parts that are
## adrift, and anonymous ones show up there when they happen to be adrift. **An anonymous mesh
## that is correctly attached is invisible to everything**, which is most of them: the ones on
## the water bomber were four propeller blades and two struts, all of them bolted exactly where
## they should be. A fault that is only visible when a second, unrelated fault is present is a
## fault nobody will ever finish.
##
## AND EVERY KIND, NOT EVERY AIRCRAFT. This is a fleet rule and it is in its own suite for that
## reason: `aircraft_fidelity` holds seven aeroplanes to their three-views, and a ship, a tank or
## a tower has exactly the same claim on being made of parts somebody named.

## THE CRAFT WITH ANONYMOUS MESHES ON THEM, as measured on 2026-09-17, with the count.
##
## THIS LIST MAY ONLY SHRINK, AND IT CANNOT ROT: a craft on it that turns out to be clean is
## reported as an error rather than ignored, so the entry has to be deleted by whoever fixes the
## craft. That property has already earned its keep once -- the same ratchet in
## `aircraft_fidelity` caught its own first entry, a craft put on it from a visual report that
## turned out not to have the fault at all.
##
## A RATCHET RATHER THAN A RED LINE, because these belong to craft three lanes own and a gate
## that is red for a fault the lane in front of it cannot fix teaches everybody that a red line
## in the gate is normal. `names_shot` came out of `suites.txt` on this same day for exactly that.
##
## THE TANK WAS ON THIS LIST TOO, AND THE RATCHET TOOK IT OFF. `lane/tank` renamed every road wheel
## on its own branch; when it merged on 2026-09-17 the tank came back clean, this suite went red
## naming the stale entry -- "delete these entries: tank" -- and the line was deleted in the next
## commit. That is the whole design, observed once: the list shrinks only when the fault is gone, and
## it cannot be forgotten, because a stale entry is an error rather than a comfort.
##
## AND THEN THE TRAIN, WHICH WAS LEFT FOR ITS OWN LANE on purpose -- `lane/train` held the C++ slot
## and was rebuilding the locomotive, and renaming its parts from here would have been a merge
## conflict delivered mid-task. It had grown by the time it was fixed: the rebuild into a cab unit
## put twelve parts in loops -- eight wheels, two trucks, two cab side windows -- and a repeated name
## keeps its FIRST child and renames the rest, so nine were anonymous. Removing this entry BEFORE
## the parts were named sent the suite red listing exactly those nine, which is how the fix was
## known to be seen; naming them by truck, axle and side turned it green. (The comment written here
## before that run said eleven. The run said nine, and the run is what is recorded.)
const UNNAMED: Dictionary = {}

var _failures: PackedStringArray = []
var _worst: PackedStringArray = []


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL the native library is not loaded")
		get_tree().quit(1)
		return
	var total: int = 0
	var anonymous: Dictionary = {}
	var clean: PackedStringArray = []
	for kind in range(Sim.Kind.size()):
		var label: String = Sim.kind_name(kind)
		var found: PackedStringArray = _anonymous_parts(kind)
		total += 1
		if found.is_empty():
			clean.append(label)
		else:
			anonymous[label] = found
	_report(anonymous, clean, total)
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## EVERY VISIBLE MESH THIS CRAFT DRAWS THAT NOBODY NAMED, in the order the scene holds them.
##
## BUILT THE WAY THE GAME BUILDS IT -- `preview_kind` then `_show_in_editor()` then
## `_show_body(true)` -- so what is walked is the craft a player sees and not a scene file.
func _anonymous_parts(kind: int) -> PackedStringArray:
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene) \
		.instantiate() as VehicleView
	add_child(view)
	# FROM OUTSIDE, THE WAY A PLAYER SEES THE CRAFT -- `setup`, as `aircraft_fidelity` builds it.
	# NOT `_show_body(true)`, which is the GHOSTED view from INSIDE the craft and hides airframe.
	# This suite was first written with it, and so measured a partial Chinook -- ten parts led by a
	# gun mount -- and passed; `tests/joined_parts.gd` found that on its first run.
	view.setup(0, kind)
	var found: PackedStringArray = []
	for child in view.find_children("*", "MeshInstance3D", true, false):
		var part := child as MeshInstance3D
		if part.mesh == null or not part.is_visible_in_tree() or _inside_a_named_part(part):
			continue
		if _is_anonymous(String(part.name)):
			# WHERE IT HANGS, and not just what it is called. An anonymous name is the same string
			# every time and tells nobody which line built it; its PARENT is the part of the craft
			# it belongs to, and that is what somebody has to go and edit.
			var under: Node = part.get_parent()
			found.append("%s under %s (a %s, %d triangles, at %s)" % [part.name,
				"the craft" if under == view else String(under.name),
				part.mesh.get_class(), _triangles(part), part.position])
	# FREED NOW AND NOT QUEUED. This builds twenty-five craft in one `_ready` and then quits;
	# `queue_free` defers to the end of the frame that never comes, and the run ends with
	# "25 RID allocations were leaked at exit" -- which the runner fails a suite for, and
	# rightly, because a suite that leaks is a suite whose measurements came from a scene the
	# engine was still holding.
	remove_child(view)
	view.free()
	return found


## A NAME GODOT MADE UP, OR A CLASS NAME LEFT AS ONE.
##
## Two shapes and they are different faults. `@MeshInstance3D@9` is the engine renaming a
## DUPLICATE, which is the silent one and the common one. A bare `MeshInstance3D` or
## `MeshInstance3D2` is a node somebody added and never named, which at least looks wrong in the
## scene tree. Both are caught; the message says which, because the fix is different.
func _is_anonymous(name: String) -> bool:
	if name.begins_with("@"):
		return true
	# AND A NAME WITH A BRACKET IN IT, which is an ARRAY that went through `%s`. I shipped four of
	# these while fixing the rest: `"UtilityTwin%sPropellerBlade%s" % [["Port"], ["A"]]` nests the
	# arguments one list too deep, each `%s` stringifies a list, and the node came out called
	# `UtilityTwin[_Port_]PropellerBlade[_A_]`. It is not anonymous and it passed this suite for an
	# hour. A name nobody chose is a name nobody chose, whichever way the machine garbled it.
	if name.contains("["):
		return true
	return name == "MeshInstance3D" or (name.begins_with("MeshInstance3D")
		and name.trim_prefix("MeshInstance3D").is_valid_int())


func _triangles(part: MeshInstance3D) -> int:
	var count: int = 0
	for surface in range(part.mesh.get_surface_count()):
		var arrays: Array = part.mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
			if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] \
			if arrays[Mesh.ARRAY_VERTEX] != null else PackedVector3Array()
		count += (indices.size() / 3) if not indices.is_empty() else (vertices.size() / 3)
	return count


## IS THIS MESH INSIDE SOMETHING SOMEBODY ALREADY NAMED?
##
## THE RULE IS ABOUT PARTS OF THE CRAFT, NOT ABOUT EVERY TRIANGLE IN THE SCENE, and the first
## version of this suite did not make that distinction and was wrong about it. It reported the
## water bomber as drawing fifteen anonymous meshes, and all fifteen were the little boxes INSIDE
## `ConsoleFlaps`, `ConsoleGear` and `ConsoleDrop` -- three levers on the pedestal that are
## themselves named, that `tests/fit.gd` holds to their names and `tests/stations.gd` holds to an
## immutable document. **A named part's own internals are its business.** What this suite is for
## is a part of the CRAFT that nobody named: a mesh hanging off the aeroplane with no named owner
## anywhere above it, which is the thing a screenshot review cannot ask about and a feature
## contract cannot find.
##
## So the walk stops at the first named owner: a control, a station, a shell. Anything under one
## of those has an owner with a name, and the name of the box inside a lever is not a fleet
## concern. Anything NOT under one is the craft itself, and has to be named.
##
## ASKED OF `DrawnParts`, NOT WRITTEN AGAIN HERE. This was a second copy of the same walk, and the two had
## to agree: when the casting skip went into one, a copy would have left this suite counting every
## casting mesh on a craft that ships one.
func _inside_a_named_part(part: Node) -> bool:
	return DrawnParts.inside_a_named_part(part)


func _report(anonymous: Dictionary, clean: PackedStringArray, total: int) -> void:
	var surprises: PackedStringArray = []
	var fixed: PackedStringArray = []
	for craft in anonymous:
		if not UNNAMED.has(craft):
			surprises.append("%s draws %d: %s" % [craft, (anonymous[craft] as PackedStringArray).size(),
				", ".join(anonymous[craft] as PackedStringArray)])
	for craft in UNNAMED:
		if not anonymous.has(craft):
			fixed.append("%s (%s)" % [craft, UNNAMED[craft]])
	_check("every_visible_mesh_on_every_craft_is_a_part_somebody_named", surprises.is_empty(),
		"%d of %d craft are clean and %d are on the known list"
			% [clean.size(), total, anonymous.size()]
			if surprises.is_empty() else
			"%s -- Godot renames a DUPLICATE to @MeshInstance3D@N without a word, so a part built "
			% "; ".join(surprises)
			+ "in a `for side` loop needs the side in its name and one in an inner loop the index")
	# A CRAFT ON THE LIST THAT IS CLEAN IS AN ERROR, which is what makes this a ratchet rather
	# than an exemption: the entry has to go in the commit that fixes the craft.
	_check("and_no_craft_on_the_known_list_has_quietly_been_fixed_without_it_being_taken_off",
		fixed.is_empty(),
		"all %d still have them" % UNNAMED.size() if fixed.is_empty()
			else "delete these entries: %s" % ", ".join(fixed))
	for craft in anonymous:
		if UNNAMED.has(craft):
			print("[named_parts] KNOWN %s: %s" % [craft, ", ".join(anonymous[craft] as PackedStringArray)])


func _check(label: String, okay: bool, detail: String) -> void:
	print("[named_parts] %s %s (%s)" % ["PASS" if okay else "FAIL", label, detail])
	if not okay:
		_failures.append(label)
