extends RefCounted
class_name CastingOnChange
## A `Casting` POSED ONLY WHEN A HINGE MOVED, and then only the bones that ride on a hinge. RESEARCH PROOF OF CONCEPT
## (`research/vertex_animation.md`), the first of the two fixes `research/static_bake.md` named for a casting's cost.
##
## WHY: `Casting.pose` reads all seventeen parts' `global_transform`s and sets seventeen bones every frame, about 25 µs a
## Cessna, whether or not anything moved -- and a parked or cruising craft moves nothing most frames. Here a frame costs
## a compare per hinge. When a hinge has moved, only the bones of the parts on a hinge (the part, or anything under it)
## are posed, from the same `root`-relative transform `Casting.pose` uses, so a posed bone is exactly what `Casting`
## would have set.
##
## WHAT MOVES IS THE AIRFRAME'S OWN RECORD, `SkyhawkAirframe._hinges`, the dictionary its `_swing` reads -- not a list
## written here. A part that moves in some other way (the propeller) is not followed; leave it out of the pour.

var casting: Casting
## {node, bone} for every part on a hinge, the hinged node itself or below it.
var riders: Array[Dictionary] = []
## The hinged nodes, and the local transform each had when last looked at.
var hinges: Array[Node3D] = []
var last: Array[Transform3D] = []


static func following(poured: Casting, hinged: Dictionary) -> CastingOnChange:
	var watch := CastingOnChange.new()
	watch.casting = poured
	for node in hinged:
		if is_instance_valid(node):
			watch.hinges.append(node)
			watch.last.append((node as Node3D).transform)
	for entry in poured.parts:
		var part: Node = entry["node"]
		for hinge in watch.hinges:
			if part == hinge or hinge.is_ancestor_of(part):
				watch.riders.append({"node": part, "bone": int(entry["bone"])})
				break
	return watch


## POSE THE RIDERS IF ANY HINGE MOVED. Returns how many bones were set.
func pose() -> int:
	var moved: bool = false
	for index in range(hinges.size()):
		var now: Transform3D = hinges[index].transform
		if now != last[index]:
			last[index] = now
			moved = true
	if not moved:
		return 0
	var into: Transform3D = casting.root.global_transform.affine_inverse()
	for rider in riders:
		casting.skeleton.set_bone_pose(int(rider["bone"]), into * (rider["node"] as Node3D).global_transform)
	return riders.size()
