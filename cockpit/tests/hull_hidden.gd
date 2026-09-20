extends Node
## Headless: DOES THE OLD SKIN STAY GONE WHEN A CREW BOARDS, AND WHEN THEY LEAVE?
##
##   Godot --headless --path cockpit res://tests/hull_hidden.tscn
##
## EVERY CRAFT DRAWN WHOLE BY SOMETHING ELSE HIDES THE SCENE'S `Hull`, the simulation's box or the glazed greenhouse
## `HullSkin` cuts from it. Until 2026-09-19 thirteen branches of `VehicleView.setup` did that with `_hull.visible =
## false` alone and left the hull in `_body`, and `_show_body`, which runs whenever the crew changes, sets every mesh in
## `_body` visible again. `lane/osprey` found the V-22's greenhouse standing across its pilots' view over the nose.
## Measured here on main 8d21e9a4, with the V-22 and the tanker already mended: of 22 kinds that hide their hull, 18
## stood the old box back up OUTSIDE the airframe the moment their crew got out (a kind with no glazing plan hides the
## whole body while boarded, then shows all of it), and the airliner and the E-6B stood their glazed greenhouse up
## inside the jetliner for everybody aboard. Only the Cessna and the F/A-18 held, because a package's visual scene
## keeps the procedural skin hidden. One helper, `_retire_the_hull`, now does it for every branch.
##
## SO THIS DRIVES THE REAL PATH: every kind the simulation knows is built as the game builds it (`setup`), then manned
## through `man` with this machine in seat 0, which is what boarding calls, then emptied through `man` again, which is
## what getting out calls. A hull hidden after `setup` must be hidden after each. Nothing here asks which branch a
## kind took: it asks the node.
##
## AND IT SAYS HOW MANY IT HELD, because "no hidden hull came back" is also true of a run in which no hull was hidden.
## Fewer than `AT_LEAST_HIDDEN` hidden hulls is a failure too.
##
## Read RESULT=, not the exit code.

## HOW MANY KINDS HIDE THE HULL, as counted on 2026-09-19: 22 of 33. A floor, not a roster: more is fine.
const AT_LEAST_HIDDEN: int = 22

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[hull_hidden] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	CockpitStation.use_saved_layouts = false
	_no_hidden_hull_comes_back_when_a_crew_boards_or_leaves()
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _no_hidden_hull_comes_back_when_a_crew_boards_or_leaves() -> void:
	var came_back: PackedStringArray = []
	var held: PackedStringArray = []
	var built: int = 0
	for kind in Sim.Kind.values():
		var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
		add_child(view)
		view.setup(0, kind)
		built += 1
		var hull := view.find_child("Hull", true, false) as MeshInstance3D
		if hull == null or hull.visible:
			view.queue_free()
			remove_child(view)
			continue
		held.append(Sim.kind_name(kind))
		var every: Array = []
		for seat in range(view.seats.size()):
			every.append(seat)
		view.man(every, 0)
		if hull.visible:
			came_back.append("%s when its crew boarded" % Sim.kind_name(kind))
		view.man([], -1)
		if hull.visible:
			came_back.append("%s when its crew got out" % Sim.kind_name(kind))
		remove_child(view)
		view.queue_free()
	_check("no_hidden_hull_comes_back_when_a_crew_boards_or_leaves",
		came_back.is_empty() and held.size() >= AT_LEAST_HIDDEN,
		"%d kinds built, %d hide their hull (%s), %s" % [built, held.size(), ", ".join(held),
			"none shown again, boarded or emptied" if came_back.is_empty()
				else "SHOWN AGAIN: " + ", ".join(came_back)])
