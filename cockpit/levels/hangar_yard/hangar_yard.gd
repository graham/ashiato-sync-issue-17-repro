extends Node3D
class_name HangarYard
## THE HANGAR YARD: an apron with Hangar 03 standing on it, its door open and a fighter parked inside.
##
## Asked for on 2026-09-17 with the concept sheet: "build it and make a level where we can place it with some
## screenshots to show your work". The building itself is `objects/structures/skyfront_hangar.tscn`; this is the level
## fixture round it -- the concrete, the paint on it, the lighting the design is judged in, and the parked aircraft.
##
## A ROOM WORLD, because a room is the island's slab with no country on it (`GroundTuning.World`): no sea, no scenery,
## no generated ground, but the sky, the sun and the daylight still run, so an apron under an open sky costs a slab and
## nothing else. The level arrives its players in a Segway, which is how a player walks here (agents.md), so the hangar
## is seen at human scale and walked into rather than flown past.
##
## ONE LIST FOR THE PICTURE AND THE SIMULATION: `boxes()` is the hangar's own static boxes offset to where it stands,
## exactly as `BriefingRoom` and `DeviceYard` hand theirs over, and `Sky` puts every one of them into `Sim`. Nothing here
## is replicated and nothing here has authority over anything: it is a building and some paint.
##
## THE PARKED FIGHTER SITS ON THE FLOOR BECAUSE ITS OWN MODEL SAYS WHERE ITS WHEELS ARE. Its height over the apron is
## measured from the drawn vertices, not typed: `FighterAirframe` is the authority on its own size, and a number typed
## beside it would be wrong the first time the model changed (CLAUDE.md, rule 4).

const LEVEL_ID := "hangar_yard"
## Where the hangar stands, and which way its door faces: +Z, out across the apron. `Sim.add_static_box` has no
## rotation, so a level may move a hangar but not turn it (agents.md, "A yaw is a quarter turn or nothing").
const HANGAR_AT := Vector3(0.0, 0.0, 0.0)
const HANGAR_BAYS: int = 4
## The apron: from behind the hangar out past where a fighter would hold, and wide enough that its edge is never the
## subject of a picture.
const APRON_FROM := Vector2(-62.0, -42.0)
const APRON_TO := Vector2(62.0, 92.0)
const APRON_THICK: float = 0.3
## Where the fighter is parked inside, and which way it points: nose out of the door.
const PARKED_AT := Vector3(0.0, 0.0, -5.0)
## The apron's paint.
const PAINT_YELLOW := Color(0.820, 0.580, 0.120, 0.0)
const APRON_GREY := Color(0.585, 0.585, 0.595, 0.55)
const APRON_SEAM := Color(0.520, 0.520, 0.530, 0.55)

var hangar: SkyfrontHangar = null
var parked: Node3D = null


static func claims(chart: LevelChart) -> bool:
	return chart != null and chart.id == LEVEL_ID


## THE SOLID: the hangar's own boxes, where the hangar stands. The apron is the slab the room world already lays at
## y = 0, so the yard adds nothing under it.
static func boxes(_chart: LevelChart) -> Array[Dictionary]:
	return SkyfrontHangar.boxes(HANGAR_AT, HANGAR_BAYS)


func stand_in(_chart: LevelChart) -> void:
	_lay_the_apron()
	hangar = (load("res://objects/structures/skyfront_hangar.tscn") as PackedScene).instantiate() as SkyfrontHangar
	hangar.name = "Hangar"
	hangar.bays = HANGAR_BAYS
	hangar.position = HANGAR_AT
	add_child(hangar)
	parked = park_a_fighter(PARKED_AT, PI)
	if parked != null:
		add_child(parked)
	# AND SAT DOWN NOW, not in `_ready`: this node is already in the tree when a level stands it up, so its own `_ready`
	# has long since run and the craft it is being handed did not exist then. That left the fighter 1.37 m in the air
	# with every other check green (tests/hangar.gd, 2026-09-17).
	_sit_the_parked_craft_down()


## A FIGHTER PARKED ON THE APRON, sat on its own wheels: the model is asked how far its lowest drawn point is below its
## origin, and stood that far up. `yaw` is which way it points, radians about up; PI is nose out of the door.
static func park_a_fighter(at: Vector3, yaw: float) -> Node3D:
	var scene := load("res://objects/vehicles/fighter_airframe.tscn") as PackedScene
	if scene == null:
		push_error("[HangarYard] there is no fighter airframe to park")
		return null
	var craft := scene.instantiate() as Node3D
	craft.name = "ParkedFighter"
	craft.rotation.y = yaw
	craft.position = at
	craft.set_meta("sit_on_the_ground", true)
	return craft


## HOW FAR A DRAWN NODE'S LOWEST VERTEX IS BELOW ITS ORIGIN, metres: asked of the meshes, so a model that changes shape
## still parks on its wheels. Returns 0.0 for a node that has drawn nothing.
##
## FROM THE TRANSFORMED VERTICES, NEVER `transform * get_aabb()`: a box round a box grows every time it is turned, which
## read the folded Hawkeye 0.86 m wider than it is (modelling_here.md, section 6).
static func lowest_drawn(node: Node) -> float:
	var lowest: float = 0.0
	var root: Node3D = node as Node3D
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var into: Transform3D = mesh_instance.global_transform
		if root != null:
			into = root.global_transform.affine_inverse() * into
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var points: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] \
				as PackedVector3Array
			for point in points:
				lowest = minf(lowest, (into * point).y)
	return lowest


## THE CONCRETE, AND THE PAINT ON IT: one welded mesh -- the slab, its expansion seams, the centreline out of the door,
## the hold line a fighter waits behind, and the bay outline the sheet's own apron has.
func _lay_the_apron() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var middle := (APRON_FROM + APRON_TO) * 0.5
	var size := APRON_TO - APRON_FROM
	Plating.box(tool, Vector3(middle.x, -APRON_THICK * 0.5, middle.y), Vector3(size.x, APRON_THICK, size.y),
		APRON_GREY)
	# EXPANSION SEAMS every 8 m, both ways: what tells the eye how big the apron is.
	var seam: float = 8.0
	var across: int = int(size.x / seam)
	for index in range(1, across):
		var x: float = APRON_FROM.x + float(index) * seam
		Plating.box(tool, Vector3(x, 0.01, middle.y), Vector3(0.08, 0.02, size.y), APRON_SEAM)
	var along: int = int(size.y / seam)
	for index in range(1, along):
		var z: float = APRON_FROM.y + float(index) * seam
		Plating.box(tool, Vector3(middle.x, 0.01, z), Vector3(size.x, 0.02, 0.08), APRON_SEAM)
	# THE CENTRELINE out of the door, and the hold line across it.
	var door_z: float = HANGAR_AT.z + SkyfrontHangar.depth_of(HANGAR_BAYS) * 0.5
	Plating.box(tool, Vector3(HANGAR_AT.x, 0.02, (door_z + APRON_TO.y) * 0.5 + 6.0),
		Vector3(0.3, 0.03, APRON_TO.y - door_z - 12.0), PAINT_YELLOW)
	Plating.box(tool, Vector3(HANGAR_AT.x, 0.02, door_z + 26.0), Vector3(30.0, 0.03, 0.4), PAINT_YELLOW)
	for side in [-1.0, 1.0]:
		Plating.box(tool, Vector3(HANGAR_AT.x + side * 15.0, 0.02, door_z + 22.0), Vector3(0.4, 0.03, 8.0),
			PAINT_YELLOW)
	# AND THE BAY OUTLINE round the hangar's own footprint, a metre off it.
	var half_span: float = SkyfrontHangar.SPAN * 0.5 + 2.5
	var half_deep: float = SkyfrontHangar.depth_of(HANGAR_BAYS) * 0.5 + 2.5
	for side in [-1.0, 1.0]:
		Plating.box(tool, Vector3(HANGAR_AT.x + side * half_span, 0.02, HANGAR_AT.z),
			Vector3(0.25, 0.03, half_deep * 2.0), PAINT_YELLOW)
	Plating.box(tool, Vector3(HANGAR_AT.x, 0.02, HANGAR_AT.z - half_deep), Vector3(half_span * 2.0, 0.03, 0.25),
		PAINT_YELLOW)
	var apron := MeshInstance3D.new()
	apron.name = "Apron"
	apron.mesh = Plating.weld(tool)
	apron.material_override = SkyfrontHangar.armour()
	add_child(apron)


## SIT EVERY PARKED CRAFT ON THE APRON, once its meshes are built: a model builds itself when it enters the tree, so its
## lowest vertex is not knowable until then. The mark is taken off as each one is sat down, so sitting twice -- which
## would bury the craft a second time -- cannot happen.
func _sit_the_parked_craft_down() -> void:
	for child in get_children():
		var craft := child as Node3D
		if craft == null or not craft.has_meta("sit_on_the_ground"):
			continue
		craft.position.y -= lowest_drawn(craft)
		craft.remove_meta("sit_on_the_ground")


func report() -> Dictionary:
	return {"level": LEVEL_ID, "hangar_at": HANGAR_AT, "bays": HANGAR_BAYS,
		"depth": SkyfrontHangar.depth_of(HANGAR_BAYS), "span": SkyfrontHangar.SPAN,
		"opening": SkyfrontHangar.opening(HANGAR_AT, HANGAR_BAYS), "boxes": boxes(null).size(),
		"parked_at": parked.position if parked != null else Vector3.ZERO}
