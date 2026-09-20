extends RefCounted
class_name AuthoredChunks
## THE HAND-BUILT PLACES: a folder a place under `res://world/chunks/`, read at boot, each with the boxes the simulation is
## given for it and the scenes that draw it.
##
## WHY IT EXISTS. The user plans some hand-built airfields, imported models and textures beside the generated island. A
## generated kilometre is a function of numbers; an authored one is a file, and a file is loaded -- on a thread, so a
## pilot flying into an airfield's reach does not wait on the disk (see `SceneryYard` and the design, section 6b, in the
## drafts folder beside the repository).
##
## CONTENT IS A FOLDER SCANNED AT BOOT (building_a_game_here.md): the folder name is the id, a folder whose name starts
## with `_` is skipped, and a place that cannot be read disables itself with a warning rather than being half a place.
## `_template` is a working place the tests load by name.
##
## A PLACE IS `chunk.json`, `near.tscn` and optionally `far.tscn`. The manifest states its own frame and units:
##
##   {"at": [x, y, z],            metres, in the world: where the place's own origin stands
##    "yaw": 90,                  degrees, a vehicle's yaw; a multiple of 90, see below
##    "reach": 6000,              metres from the eye the near scene is drawn; absent is the level's own far distance
##    "boxes": [{"position": [x, y, z], "half_extents": [x, y, z]}, ...]}   metres, in the place's own frame
##
## COLLISION IS THE MANIFEST'S BOXES, NEVER THE SCENE'S. Static collision is built identically on every peer at boot
## (agents.md, rule 8), and a scene is loaded when it comes within reach of one machine's eye -- a shape in it would be
## solid on the machine that had loaded it and air on the one that had not, and a client predicts itself into the
## difference. So the boxes go to the simulation with the island's, and a scene with a collision object in it is
## refused where it is built (`refusal_in`).
##
## A YAW IS A MULTIPLE OF 90 DEGREES, because `Sim.add_static_box` has no rotation: a place turned by 45 degrees would
## collide somewhere other than where it is drawn. A quarter turn swaps a box's x and z, which is exact.

const FOLDER: String = "res://world/chunks"
## How far off a whole number of quarter turns a yaw may be and still count as one, degrees.
const QUARTER_SLACK: float = 0.001


## EVERY PLACE THE GAME HAS, read, in id order. A place that cannot be read is left out with a warning.
static func catalogue() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(FOLDER):
		return out
	var ids: PackedStringArray = DirAccess.get_directories_at(FOLDER)
	ids.sort()
	for id in ids:
		if id.begins_with("_"):
			continue
		var place: Dictionary = read_place(FOLDER.path_join(id))
		if not place.is_empty():
			out.append(place)
	return out


## ONE PLACE, READ, or {} with a warning saying why not. Public so a test can hand it a broken one by path.
##
## Returns `{id, at, yaw, quarter_turns, reach, boxes, near, far}`: `boxes` in the WORLD, turned and moved, as the island's
## are (`{position, half_extents, group, place}`); `reach` -1 for "the level's far distance"; `far` "" for none.
static func read_place(path: String) -> Dictionary:
	var id: String = path.get_file()
	var manifest := FileAccess.open(path.path_join("chunk.json"), FileAccess.READ)
	if manifest == null:
		push_warning("[chunks] %s has no chunk.json; it is not placed" % id)
		return {}
	# A JSON INSTANCE, NOT `JSON.parse_string`: the instance hands back an error code and a line, which is a warning a
	# person can act on, where a failed one-line parse is only a null.
	var json := JSON.new()
	if json.parse(manifest.get_as_text()) != OK or not (json.data is Dictionary):
		push_warning("[chunks] %s: chunk.json is not a JSON object (line %d: %s); it is not placed"
			% [id, json.get_error_line(), json.get_error_message()])
		return {}
	var data: Dictionary = json.data
	var at: Variant = _vector(data.get("at"))
	if at == null:
		push_warning("[chunks] %s: `at` is not three numbers; it is not placed" % id)
		return {}
	# THE DEFAULTS, HERE, AT THE CALL SITE: no yaw is facing north, and no reach is the level's own far distance (-1).
	var yaw: float = float(data.get("yaw", 0.0)) if (data.get("yaw", 0.0) is float or data.get("yaw", 0.0) is int) else NAN
	if is_nan(yaw):
		push_warning("[chunks] %s: `yaw` is not a number; it is not placed" % id)
		return {}
	var turns_exact: float = yaw / 90.0
	if absf(turns_exact - round(turns_exact)) * 90.0 > QUARTER_SLACK:
		push_warning("[chunks] %s: a yaw of %.3f degrees is not a whole number of quarter turns, and a static box has no rotation; it is not placed" % [id, yaw])
		return {}
	var turns: int = posmod(int(round(turns_exact)), 4)
	var reach: float = -1.0
	if data.has("reach"):
		if not (data["reach"] is float or data["reach"] is int) or float(data["reach"]) <= 0.0:
			push_warning("[chunks] %s: `reach` is not a positive number of metres; it is not placed" % id)
			return {}
		reach = float(data["reach"])
	var near: String = path.path_join("near.tscn")
	if not ResourceLoader.exists(near):
		push_warning("[chunks] %s has no near.tscn; it is not placed" % id)
		return {}
	var far: String = path.path_join("far.tscn")
	if not ResourceLoader.exists(far):
		far = ""
	var boxes: Array[Dictionary] = []
	var listed: Variant = data.get("boxes", [])
	if not (listed is Array):
		push_warning("[chunks] %s: `boxes` is not a list; it is not placed" % id)
		return {}
	for i in range((listed as Array).size()):
		var entry: Variant = (listed as Array)[i]
		var position: Variant = _vector(entry.get("position") if entry is Dictionary else null)
		var half: Variant = _vector(entry.get("half_extents") if entry is Dictionary else null)
		if position == null or half == null or (half as Vector3).x <= 0.0 or (half as Vector3).y <= 0.0 \
				or (half as Vector3).z <= 0.0:
			push_warning("[chunks] %s: box %d needs a position and three positive half_extents; it is not placed" % [id, i])
			return {}
		boxes.append({
			"position": (at as Vector3) + _turned(position, turns),
			"half_extents": _turned(half, turns).abs(),
			"group": Terrain.Group.AUTHORED,
			"place": id,
		})
	return {"id": id, "at": at, "yaw": yaw, "quarter_turns": turns, "reach": reach, "boxes": boxes, "near": near,
		"far": far}


## EVERY PLACE'S BOXES, in the world, for the level to give the simulation with the island's.
static func boxes(places: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for place in places:
		out.append_array(place["boxes"])
	return out


## THE GROUND EACH PLACE KEEPS CLEAR OF GENERATED SCENERY, as `Terrain.clearances()` records: the hull of its boxes and
## `room` metres round it, `why` &"authored". A place with no boxes keeps a `room`-sized square round its origin.
static func clearances(places: Array[Dictionary], room: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for place in places:
		var hull := AABB(place["at"], Vector3.ZERO)
		for box in place["boxes"]:
			var half: Vector3 = box["half_extents"]
			hull = hull.merge(AABB((box["position"] as Vector3) - half, half * 2.0))
		hull = hull.grow(room)
		out.append({"position": hull.get_center(), "half_extents": hull.size * 0.5, "why": &"authored"})
	return out


## HAND EVERY PLACE TO THE YARD, one prepared layer a place, each with the one cell its `at` stands in: loaded on a thread
## when the cell is first wanted, asked about each frame, and built only once its scene reads LOADED -- because
## `ResourceLoader.load_threaded_get` on a load that has not finished blocks like `load()` (Godot's background loading
## page), and the yard never calls a build before `readiness` says READY. `default_reach` is for a place that names none.
## Returns the layers' indices, in the places' order.
static func add_to_yard(yard: SceneryYard, places: Array[Dictionary], default_reach: float, parent: Node3D) -> Array[int]:
	var out: Array[int] = []
	for place in places:
		var cell: Vector2i = WorldMap.cell_of(place["at"])
		var hull := AABB(place["at"], Vector3.ZERO)
		for box in place["boxes"]:
			var half: Vector3 = box["half_extents"]
			hull = hull.merge(AABB((box["position"] as Vector3) - half, half * 2.0))
		var bounds: Dictionary = {cell: hull}
		var reach: float = float(place["reach"]) if float(place["reach"]) > 0.0 else default_reach
		var near: String = place["near"]
		out.append(yard.add_prepared_layer("Place_%s" % place["id"], bounds, reach, parent,
			func(_cell: Vector2i) -> Array[Node3D]: return build_place(place),
			func(_cell: Vector2i) -> void: request(near),
			func(_cell: Vector2i) -> int: return readiness_of(near),
			func(_cell: Vector2i) -> void: pass))
	return out


## START LOADING A SCENE ON A THREAD. Reused from the cache while anything still holds it; a request that cannot even
## start is warned about, and its readiness then reads FAILED.
static func request(path: String) -> void:
	var err: Error = ResourceLoader.load_threaded_request(path, "PackedScene", false, ResourceLoader.CACHE_MODE_REUSE)
	if err != OK:
		push_warning("[chunks] %s could not be requested (error %d)" % [path, err])


## WHERE A THREADED LOAD HAS GOT TO, in the yard's words.
static func readiness_of(path: String) -> int:
	match ResourceLoader.load_threaded_get_status(path):
		ResourceLoader.THREAD_LOAD_LOADED:
			return SceneryYard.Readiness.READY
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return SceneryYard.Readiness.WAITING
		_:
			return SceneryYard.Readiness.FAILED


## ONE PLACE'S NEAR SCENE, BUILT: taken from its finished threaded load, instanced, refused if anything in it could collide,
## and stood where the manifest puts it. An empty list, with a warning, for a scene that cannot be drawn.
static func build_place(place: Dictionary) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var id: String = place["id"]
	var packed := ResourceLoader.load_threaded_get(place["near"]) as PackedScene
	if packed == null:
		push_warning("[chunks] %s: near.tscn did not load as a scene; it is not drawn" % id)
		return out
	var scene: Node = packed.instantiate()
	var refusal: String = refusal_in(scene)
	var node := scene as Node3D
	if refusal != "" or node == null:
		push_warning("[chunks] %s: %s; it is not drawn" % [id, refusal if refusal != "" else "near.tscn's root is not a Node3D"])
		scene.free()
		return out
	node.name = "Place_%s" % id
	node.transform = transform_of(place)
	out.append(node)
	return out


## WHY A BUILT SCENE MAY NOT BE DRAWN, or "" if it may: the first collision object or shape in it, by path.
static func refusal_in(scene: Node) -> String:
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D:
			return "%s is a %s, and collision is the manifest's boxes" % [scene.get_path_to(node), node.get_class()]
		for child in node.get_children():
			stack.append(child)
	return ""


## Where a place's scene stands in the world: at `at`, turned by its quarter turns about the vertical.
static func transform_of(place: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(90.0 * float(place["quarter_turns"]))), place["at"])


static func _turned(v: Vector3, turns: int) -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(90.0 * float(turns))) * v


static func _vector(value: Variant) -> Variant:
	if not (value is Array) or (value as Array).size() != 3:
		return null
	for n in (value as Array):
		if not (n is float or n is int):
			return null
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
