extends Node
## Headless: the brig drawn is the brig simulated, and its sails do what the rigging says.
##
##   Godot --headless --path cockpit res://tests/brig.tscn
##
## A PICTURE CANNOT BE JUDGED HEADLESS, and this does not try: how the sails LOOK is the windowed pictures'. What a suite
## can hold is the arithmetic between the rigging and the drawing. The yards hang where the simulation's rig table says
## a lever sets them, each sail is handed its group's fill and the side the wind blows it to, and nothing a sail is
## given comes from anywhere but the rigging. The truths are the simulation's own table (`kind_geometry`'s `rig`) and the
## physical meaning of a lever, not a copy of the drawing's formula: let go, a yard lies athwartships; hauled right in, it
## lies at the rig's closest angle off the keel, on the side its lever's sign names.
##
## Read RESULT=, not the exit code.

const EPSILON: float = 0.02

var _failures: PackedStringArray = []
var _sections: int = 0
const SECTIONS: int = 3


func _check(label: String, ok: bool, detail: String) -> void:
	print("[brig] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.PIRATE)
	var rig: Dictionary = geometry.get("rig", {})
	var brig := BrigRig.build(rig, geometry.get("extents", Vector3.ONE))
	add_child(brig)
	_it_is_built_from_the_simulations_rig(brig, rig)
	_the_yards_lie_where_the_levers_set_them(brig, rig)
	_the_sails_fill_to_leeward_as_the_rigging_says(brig)
	brig.queue_free()
	_finish()


func _finish() -> void:
	_check("every_section_ran_to_its_end", _sections == SECTIONS, "%d of %d" % [_sections, SECTIONS])
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _it_is_built_from_the_simulations_rig(brig: BrigRig, rig: Dictionary) -> void:
	var sails: Array = rig.get("sails", [])
	var meshes: int = brig.find_children("*", "MeshInstance3D", true, false).size()
	_check("the_simulation_describes_four_sail_groups_and_a_waterline",
		sails.size() == 4 and rig.has("waterline"), "%d groups, waterline %s" % [sails.size(), rig.get("waterline")])
	_check("and_the_drawing_has_a_pivot_for_each_and_is_a_ship_not_a_box",
		brig.find_children("Pivot*", "Node3D", true, false).size() == sails.size() and meshes >= 30,
		"%d pivots, %d meshes" % [brig.find_children("Pivot*", "Node3D", true, false).size(), meshes])
	_sections += 1


## LET GO, ATHWARTSHIPS; HAULED IN, THE CLOSEST ANGLE, ON THE LEVER'S SIDE. Every square group, at both signs.
func _the_yards_lie_where_the_levers_set_them(brig: BrigRig, rig: Dictionary) -> void:
	var sails: Array = rig.get("sails", [])
	var wrong: PackedStringArray = []
	for group in [BrigRig.FORE_SQUARE, BrigRig.MAIN_SQUARE]:
		var closest: float = float((sails[group] as Dictionary)["closest"])
		var name: String = "fore" if group == BrigRig.FORE_SQUARE else "main"
		brig.trim({name: 0.0, "set": 1.0, "fill": [0, 0, 0, 0], "apparent_angle": 1.5})
		var loose: Vector3 = brig.spar_direction(group)
		# Athwartships: along x, nothing of z.
		if absf(loose.z) > EPSILON:
			wrong.append("%s let go lies %.1f degrees off athwartships" % [name, rad_to_deg(asin(absf(loose.z)))])
		for sign in [-1.0, 1.0]:
			brig.trim({name: sign, "set": 1.0, "fill": [0, 0, 0, 0], "apparent_angle": 1.5})
			var hauled: Vector3 = brig.spar_direction(group)
			# The angle between the yard's line and the keel (z), whichever end of the yard is looked at.
			var off_keel: float = acos(clampf(absf(hauled.z), 0.0, 1.0))
			# The aft end of the yard swings to the lever's side: the end with +z has x of the lever's sign.
			var aft_end: Vector3 = hauled if hauled.z > 0.0 else -hauled
			if absf(off_keel - closest) > EPSILON or signf(aft_end.x) != sign:
				wrong.append("%s at %+.0f: %.1f degrees off the keel against %.1f, aft end to x %+.2f" % [name, sign,
					rad_to_deg(off_keel), rad_to_deg(closest), aft_end.x])
	_check("a_yard_let_go_lies_athwartships_and_one_hauled_in_lies_at_the_rigs_closest_angle_on_its_levers_side",
		wrong.is_empty(), "%s" % ["both masts, both sides" if wrong.is_empty() else wrong])
	_sections += 1


## A SAIL IS HANDED ITS GROUP'S FILL, TIMES THE SAIL SET, AND BLOWS TO LEEWARD: the wind brought round to the other side
## of the bow puts every sail's belly on the other face.
func _the_sails_fill_to_leeward_as_the_rigging_says(brig: BrigRig) -> void:
	var fills: Array = [0.8, 0.6, 0.4, 0.2]
	var sheets: Array = brig.find_children("Sail*", "MeshInstance3D", true, false)
	var off: PackedStringArray = []
	var flipped: int = 0
	brig.trim({"fore": -1.0, "main": -1.0, "set": 0.5, "fill": fills, "apparent_angle": 1.2})
	var sides: Dictionary = {}
	for sheet in sheets:
		var node := sheet as MeshInstance3D
		var group: int = int(String(node.name).substr(4, 1))
		var got: float = float(node.get_instance_shader_parameter("fill"))
		if absf(got - float(fills[group]) * 0.5) > 0.001:
			off.append("%s fill %.3f against %.3f" % [node.name, got, float(fills[group]) * 0.5])
		sides[node.name] = float(node.get_instance_shader_parameter("leeward"))
	# The same trim with the wind on the other bow: the yards stay where they are, the wind's side changes.
	brig.trim({"fore": -1.0, "main": -1.0, "set": 0.5, "fill": fills, "apparent_angle": -1.2})
	for sheet in sheets:
		var node := sheet as MeshInstance3D
		if float(node.get_instance_shader_parameter("leeward")) == -float(sides[node.name]):
			flipped += 1
	_check("every_sail_is_handed_its_groups_fill_times_the_sail_set", off.is_empty() and sheets.size() >= 6,
		"%d sails%s" % [sheets.size(), "" if off.is_empty() else ": %s" % off])
	_check("and_bellies_the_other_way_when_the_wind_crosses_the_bow", flipped == sheets.size(),
		"%d of %d sails changed face" % [flipped, sheets.size()])
	_sections += 1
