extends Node
## Headless: does a hand-built place read, refuse, load on a thread and draw the way `AuthoredChunks` says -- and does the
## yard never build a prepared cell before its load has finished?
##
##   Godot --headless --path cockpit res://tests/authored_chunks.tscn
##
## The places under `res://world/chunks/` are content: a folder a place, `_`-prefixed folders skipped by the scan. The
## game has none yet. `_template` is a working place this suite loads by name, and the `_test_*` fixtures beside it are
## broken on purpose. Every check is against something the reader did not compute:
##
## - THE SCAN leaves out every `_` folder, checked against the folder listing itself.
## - THE TEMPLATE'S BOX is where `Terrain.nose_from_yaw` -- the one answer to "which way is a yaw" -- says a box behind
##   the place's origin stands, not where the reader's own turn puts it.
## - EACH FIXTURE is refused for its own reason: bad JSON, no scene, a yaw that is not a quarter turn, and a scene with a
##   collision object in it.
## - THE CONTRACT: a spy layer records every readiness answer it gives, and its build fails the suite if the last answer
##   for that cell was not READY. That holds however fast a load happens to finish, which a timing check would not.
## - THE REAL PATH: `add_to_yard` with the template, the eye flown within its reach: its scene is requested on a thread,
##   stood at the place's transform with nothing in it that collides, and freed once the eye is far away.
## - A FAILED LOAD is warned about and never built.
## - THE IMPORT RULES: every texture under `world/chunks/` is VRAM compressed with mipmaps, read out of its `.import`.
##
## Read RESULT=, not the exit code.

const TEMPLATE: String = "res://world/chunks/_template"
const FRAME: float = 1.0 / 90.0
const REACH: float = 24000.0

var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[authored_chunks] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_the_scan_skips_every_underscore_folder()
	_the_template_is_read_and_its_box_stands_where_the_yaw_puts_it()
	_each_broken_place_is_refused_for_its_own_reason()
	await _the_yard_never_builds_a_prepared_cell_before_it_is_ready()
	await _the_template_streams_in_on_a_thread_and_out_again()
	await _a_failed_load_is_never_built()
	_every_texture_under_the_chunks_imports_compressed_with_mipmaps()
	_check("every_section_of_the_suite_ran", _sections == 7, "%d of 7" % _sections)
	_finish()


## ---- the scan ---------------------------------------------------------------------------------------

func _the_scan_skips_every_underscore_folder() -> void:
	var folders: PackedStringArray = DirAccess.get_directories_at(AuthoredChunks.FOLDER)
	var places: Array[Dictionary] = AuthoredChunks.catalogue()
	var hidden: int = 0
	var listed_hidden: PackedStringArray = []
	for folder in folders:
		if folder.begins_with("_"):
			hidden += 1
	for place in places:
		if String(place["id"]).begins_with("_"):
			listed_hidden.append(String(place["id"]))
	var visible: int = folders.size() - hidden
	_check("the_scan_reads_every_place_and_skips_every_underscore_folder",
		listed_hidden.is_empty() and places.size() <= visible and hidden >= 5,
		"%d folders, %d skipped by name, %d places read%s" % [folders.size(), hidden, places.size(),
			"" if listed_hidden.is_empty() else ", read anyway: %s" % [str(listed_hidden)]])
	_sections += 1


## ---- the template -------------------------------------------------------------------------------------

func _the_template_is_read_and_its_box_stands_where_the_yaw_puts_it() -> void:
	var place: Dictionary = AuthoredChunks.read_place(TEMPLATE)
	if place.is_empty():
		_check("the_template_is_read", false, "read_place gave nothing")
		_sections += 1
		return
	# THE MANIFEST, read here with JSON, not through the reader.
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEMPLATE.path_join("chunk.json")))
	var at := Vector3(float(manifest["at"][0]), float(manifest["at"][1]), float(manifest["at"][2]))
	var yaw: float = deg_to_rad(float(manifest["yaw"]))
	var local: Array = manifest["boxes"][0]["position"]
	var half: Array = manifest["boxes"][0]["half_extents"]
	# Where a point `local.z` metres BEHIND the origin, `local.x` to the right and `local.y` up stands, by the vehicles'
	# own convention: the nose is -Z turned by the yaw (`Terrain.nose_from_yaw`), right is the nose turned a quarter.
	var nose: Vector3 = Terrain.nose_from_yaw(yaw)
	var right := Vector3(-nose.z, 0.0, nose.x)
	var wanted: Vector3 = at + right * float(local[0]) + Vector3.UP * float(local[1]) - nose * float(local[2])
	# A quarter turn swaps the footprint's two sides.
	var turns: int = posmod(int(round(float(manifest["yaw"]) / 90.0)), 4)
	var wanted_half := Vector3(float(half[0]), float(half[1]), float(half[2])) if turns % 2 == 0 \
		else Vector3(float(half[2]), float(half[1]), float(half[0]))
	var box: Dictionary = place["boxes"][0] if (place["boxes"] as Array).size() == 1 else {}
	var placed: bool = not box.is_empty() and (box["position"] as Vector3).distance_to(wanted) < 0.01 \
		and (box["half_extents"] as Vector3).distance_to(wanted_half) < 0.01
	_check("the_templates_box_stands_where_its_yaw_puts_it_and_its_sides_swap_with_a_quarter_turn",
		placed and int(box.get("group", -1)) == Terrain.Group.AUTHORED and float(place["reach"]) == float(manifest["reach"]),
		"%s half %s, wanted %s half %s; group %s, reach %.0f" % [box.get("position"), box.get("half_extents"), wanted,
			wanted_half, box.get("group"), float(place.get("reach", -2.0))])
	var scene: Node = (load(String(place["near"])) as PackedScene).instantiate()
	_check("and_its_near_scene_has_nothing_in_it_that_collides", AuthoredChunks.refusal_in(scene) == "",
		"refusal: '%s'" % AuthoredChunks.refusal_in(scene))
	scene.free()
	_sections += 1


## ---- the broken ones ---------------------------------------------------------------------------------

func _each_broken_place_is_refused_for_its_own_reason() -> void:
	var refused: PackedStringArray = []
	var accepted: PackedStringArray = []
	for id in ["_test_bad_json", "_test_no_scene", "_test_yaw_45"]:
		if AuthoredChunks.read_place(AuthoredChunks.FOLDER.path_join(id)).is_empty():
			refused.append(id)
		else:
			accepted.append(id)
	_check("a_place_with_bad_json_no_scene_or_a_yaw_off_a_quarter_turn_is_not_placed", accepted.is_empty(),
		"refused %s%s" % [str(refused), "" if accepted.is_empty() else ", accepted: %s" % [str(accepted)]])
	var collision: Dictionary = AuthoredChunks.read_place(AuthoredChunks.FOLDER.path_join("_test_collision"))
	var why: String = ""
	if not collision.is_empty():
		var scene: Node = (load(String(collision["near"])) as PackedScene).instantiate()
		why = AuthoredChunks.refusal_in(scene)
		scene.free()
	_check("and_a_scene_with_a_collision_object_in_it_is_refused_where_it_is_built",
		not collision.is_empty() and why.contains("StaticBody3D"), "'%s'" % why)
	_sections += 1


## ---- the contract -----------------------------------------------------------------------------------

func _the_yard_never_builds_a_prepared_cell_before_it_is_ready() -> void:
	var yard := SceneryYard.new()
	add_child(yard)
	yard.set_process(false)
	var cell := Vector2i(0, 0)
	var bounds: Dictionary = {cell: AABB(Vector3(10.0, 0.0, 10.0), Vector3(100.0, 10.0, 100.0))}
	var said: Dictionary = {}
	var state: Dictionary = {"asked": 0, "early": 0, "built": 0}
	# READY on the fourth time of asking, WAITING before: a load that takes a few frames.
	var readiness := func(c: Vector2i) -> int:
		state["asked"] = int(state["asked"]) + 1
		var answer: int = SceneryYard.Readiness.READY if int(state["asked"]) >= 4 else SceneryYard.Readiness.WAITING
		said[c] = answer
		return answer
	var build := func(c: Vector2i) -> Array[Node3D]:
		if int(said.get(c, -1)) != SceneryYard.Readiness.READY:
			state["early"] = int(state["early"]) + 1
		state["built"] = int(state["built"]) + 1
		var out: Array[Node3D] = [Node3D.new()]
		return out
	yard.add_prepared_layer("Spy", bounds, REACH, yard, build, func(_c: Vector2i) -> void: pass, readiness,
		func(_c: Vector2i) -> void: pass)
	yard.fill_around(Vector3.ZERO)
	var built_by_fill: int = int(state["built"])
	for i in range(20):
		yard.watch(Vector3.ZERO, FRAME)
		await get_tree().process_frame
	_check("the_yard_never_builds_a_prepared_cell_until_its_readiness_says_ready",
		int(state["early"]) == 0 and int(state["built"]) == 1 and built_by_fill == 0,
		"asked %d times, built %d, %d before READY, %d by fill_around" % [int(state["asked"]), int(state["built"]),
			int(state["early"]), built_by_fill])
	yard.queue_free()
	_sections += 1


## ---- the real path -----------------------------------------------------------------------------------

func _the_template_streams_in_on_a_thread_and_out_again() -> void:
	var place: Dictionary = AuthoredChunks.read_place(TEMPLATE)
	var yard := SceneryYard.new()
	add_child(yard)
	yard.set_process(false)
	var places: Array[Dictionary] = [place]
	AuthoredChunks.add_to_yard(yard, places, REACH, yard)
	var near_eye: Vector3 = (place["at"] as Vector3) + Vector3(0.0, 300.0, 2000.0)
	yard.fill_around(near_eye)
	var requested: int = ResourceLoader.load_threaded_get_status(String(place["near"]))
	var frames: int = 0
	var node: Node3D = null
	while frames < 600 and node == null:
		yard.watch(near_eye, FRAME)
		await get_tree().process_frame
		frames += 1
		node = yard.get_node_or_null("Place_%s" % place["id"]) as Node3D
	var where_ok: bool = node != null and node.transform.is_equal_approx(AuthoredChunks.transform_of(place))
	var clean: bool = node != null and AuthoredChunks.refusal_in(node) == ""
	_check("the_template_is_requested_on_a_thread_and_stood_at_its_own_transform_with_nothing_that_collides",
		requested != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE and where_ok and clean,
		"status after fill_around %d, built after %d frames, at %s" % [requested, frames,
			node.transform.origin if node != null else "nowhere"])
	# AND OUT AGAIN: sixty kilometres off, the plan that says so taken from its worker, and two frames for the queue_free
	# to land.
	for i in range(3):
		yard.watch(near_eye + Vector3(60000.0, 0.0, 0.0), FRAME)
		yard.catch_up()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("and_let_go_and_freed_once_the_eye_is_far_away", not is_instance_valid(node) and yard.let_go >= 1,
		"let go %d, node %s" % [yard.let_go, "alive" if is_instance_valid(node) else "freed"])
	yard.queue_free()
	_sections += 1


## ---- a failure ---------------------------------------------------------------------------------------

func _a_failed_load_is_never_built() -> void:
	var yard := SceneryYard.new()
	add_child(yard)
	yard.set_process(false)
	var state: Dictionary = {"built": 0}
	var bounds: Dictionary = {Vector2i(0, 0): AABB(Vector3.ZERO, Vector3(50.0, 10.0, 50.0))}
	yard.add_prepared_layer("Broken", bounds, REACH, yard,
		func(_c: Vector2i) -> Array[Node3D]:
			state["built"] = int(state["built"]) + 1
			var out: Array[Node3D] = []
			return out,
		func(_c: Vector2i) -> void: pass,
		func(_c: Vector2i) -> int: return SceneryYard.Readiness.FAILED,
		func(_c: Vector2i) -> void: pass)
	yard.fill_around(Vector3.ZERO)
	for i in range(10):
		yard.watch(Vector3.ZERO, FRAME)
		await get_tree().process_frame
	_check("a_cell_whose_load_failed_is_never_built", int(state["built"]) == 0 and yard.built_count() == 0,
		"built %d, cells built %d" % [int(state["built"]), yard.built_count()])
	yard.queue_free()
	_sections += 1


## ---- the import rules ----------------------------------------------------------------------------------

func _every_texture_under_the_chunks_imports_compressed_with_mipmaps() -> void:
	var imports: PackedStringArray = []
	var stack: Array[String] = [AuthoredChunks.FOLDER]
	while not stack.is_empty():
		var folder: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(folder):
			stack.append(folder.path_join(sub))
		for file in DirAccess.get_files_at(folder):
			if file.ends_with(".import"):
				imports.append(folder.path_join(file))
	var textures: int = 0
	var wrong: PackedStringArray = []
	for path in imports:
		var config := ConfigFile.new()
		if config.load(path) != OK:
			wrong.append("%s: unreadable" % path)
			continue
		if String(config.get_value("remap", "importer", "")) != "texture":
			continue
		textures += 1
		var compress: int = int(config.get_value("params", "compress/mode", -1))
		var mipmaps: bool = bool(config.get_value("params", "mipmaps/generate", false))
		if compress != 2 or not mipmaps:
			wrong.append("%s: compress/mode %d, mipmaps %s" % [path.get_file(), compress, mipmaps])
	_check("every_texture_under_the_chunks_is_vram_compressed_with_mipmaps", wrong.is_empty() and textures >= 1,
		"%d textures%s" % [textures, "" if wrong.is_empty() else ": %s" % [str(wrong)]])
	_sections += 1


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
