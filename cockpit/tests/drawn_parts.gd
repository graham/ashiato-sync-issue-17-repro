extends RefCounted
class_name DrawnParts
## WHICH OF A CRAFT'S DRAWN PARTS ARE ATTACHED TO IT: the one algorithm behind every "is this one
## object?" check in the suite, so that it is written once.
##
## THERE ARE TWO SUCH CHECKS AND THEY ARE NOT THE SAME CHECK. `tests/aircraft_fidelity.gd` and
## `tests/joined_parts.gd` read DRAWN VERTICES and expect ONE group per craft: is the thing a player
## sees a single object? `tests/buildings_gallery_shot.gd`'s `_nothing_floats` reads the plan's
## COLLISION BOXES across a whole air base and expects one group per BUILDING: is the thing the
## simulation collides with laid out as the plan says? Different datum, different expected count,
## different scope -- a drawn part can float off a building whose walls are exactly where they
## should be, and the reverse. They share an algorithm, and this is it.
##
## WHAT IT FINDS IS OPEN AIR, AND NOT MISSING STRUCTURE. `lane/audit` drew that line on 2026-09-17
## and this suite's first known-failures list proved it the hard way: the Chinook was put on it from
## a visual report of "no aft pylon", and all twenty-four of its parts touch. A rotor standing on a
## fuselage that should have a pylon between them is a fault of SHAPE. This measures gaps; a check
## that claimed both would be lying about one of them.

## HOW CLOSE TWO DRAWN PARTS HAVE TO BE TO COUNT AS JOINED, in metres.
##
## A JOINT'S SLACK AND NOT A FEATURE SIZE. Every airframe here is built from parts that OVERLAP where
## they meet, so the real question is whether two solids share space; this only forgives a part laid
## exactly against another. It is less than a third of the thinnest part on any aircraft (the water
## bomber's fin, 0.18 m), and the fault it was written for was 1.80 m of open air -- widening it
## would not have made that pass, it would have taken about thirty-six doublings.
const JOINED_WITHIN: float = 0.05


## EVERY DRAWN PART OF `root` THAT IS NOT JOINED TO ITS BIGGEST PART, with how far off and from what.
##
## `[{"name", "gap", "nearest"}]`, worst first. Empty means one object.
##
## THE BIGGEST PART IS THE TRUNK, and everything else has to reach it. Not "part 0": child order is
## an accident of the order somebody wrote the builder in, and a hull that happened to be added last
## would make the whole craft the stray.
static func adrift(root: Node3D) -> Array:
	var names: PackedStringArray = []
	var boxes: Array[AABB] = []
	for found in root.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if part.mesh == null or not part.is_visible_in_tree() or inside_a_named_part(part):
			continue
		var box: AABB = drawn_box(part, root)
		if box.size.length() <= 0.0:
			continue
		names.append(String(root.get_path_to(part)))
		boxes.append(box)
	if boxes.size() < 2:
		return []
	var trunk: int = 0
	for index in range(boxes.size()):
		if boxes[index].get_volume() > boxes[trunk].get_volume():
			trunk = index
	var reached: Dictionary = {trunk: true}
	var walking: Array[int] = [trunk]
	while not walking.is_empty():
		var here: int = walking.pop_back()
		for index in range(boxes.size()):
			if reached.has(index) or gap(boxes[here], boxes[index]) > JOINED_WITHIN:
				continue
			reached[index] = true
			walking.append(index)
	var out: Array = []
	for index in range(boxes.size()):
		if reached.has(index):
			continue
		var nearest: float = INF
		var to: String = "?"
		for other in reached:
			var apart: float = gap(boxes[index], boxes[other])
			if apart < nearest:
				nearest = apart
				to = names[other]
		out.append({"name": names[index], "gap": nearest, "nearest": to})
	out.sort_custom(func(a, b): return float(a["gap"]) > float(b["gap"]))
	return out


## How many drawn parts `adrift` would look at, for a message that says what it measured.
static func count(root: Node3D) -> int:
	var total: int = 0
	for found in root.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if part.mesh != null and part.is_visible_in_tree() and not inside_a_named_part(part):
			total += 1
	return total


## THE BOX A PART'S DRAWN VERTICES FILL, in `frame`'s own space.
##
## FROM THE VERTICES AND NOT FROM `transform * get_aabb()`. A turned part's bounding box grows every
## time it is rotated, and nacelles, floats and spinners are all turned a quarter turn about x -- so a
## box taken that way would call parts joined that are nowhere near each other.
static func drawn_box(part: MeshInstance3D, frame: Node3D) -> AABB:
	var into: Transform3D = frame.global_transform.affine_inverse() * part.global_transform
	var box := AABB()
	var started: bool = false
	for surface in range(part.mesh.get_surface_count()):
		var arrays: Array = part.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] \
			if arrays[Mesh.ARRAY_VERTEX] != null else PackedVector3Array()
		for vertex in vertices:
			var at: Vector3 = into * vertex
			if not started:
				box = AABB(at, Vector3.ZERO)
				started = true
			else:
				box = box.expand(at)
	return box


## HOW FAR APART TWO BOXES ARE, in metres, and 0 when they overlap: the straight-line distance, so a
## part clear on one axis alone is as adrift as one clear on three.
static func gap(one: AABB, other: AABB) -> float:
	var apart := Vector3.ZERO
	for axis in range(3):
		apart[axis] = maxf(0.0, maxf(one.position[axis] - other.end[axis],
			other.position[axis] - one.end[axis]))
	return apart.length()


## IS THIS MESH INSIDE SOMETHING SOMEBODY ALREADY NAMED AND MEASURES ELSEWHERE?
##
## A control, a station or a shell. Their internals are their own business -- `tests/fit.gd` holds the
## controls and `tests/stations.gd` holds each station to an immutable document -- and a lever on a
## pedestal is not a part of the craft's exterior. The first version of `named_parts` did not stop
## here and flagged fifteen boxes inside three named cockpit levers as faults; a check that produces a
## list of things that are not faults earns the reputation that gets it deleted.
##
## AND A CASTING IS SKIPPED, BY ITS `Casting.CAST_FROM` META, on the part or anything above it. A casting
## (`Casting`, `HingeCasting`, `VatCasting`) is the craft's parts poured into one mesh that overlaps every
## part it was poured from. So to a union of drawn boxes it joins a floating part back to the aeroplane,
## and to a name check it is one more mesh (`bake_shot.gd` measured the first; `vertex_animation.md`
## section 7 made the skip the hard precondition for shipping any casting). The PATTERN it was poured
## from stays visible, on render layer 0, and is what these suites go on measuring.
static func inside_a_named_part(part: Node) -> bool:
	if part.has_meta(Casting.CAST_FROM):
		return true
	var walk: Node = part.get_parent()
	while walk != null:
		if walk is VehicleControl or walk is CockpitStation or walk is CockpitShell 				or walk.has_meta(Casting.CAST_FROM):
			return true
		walk = walk.get_parent()
	return false
