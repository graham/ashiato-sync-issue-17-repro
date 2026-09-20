extends Node3D
## Windowed: the ground as `GroundView` draws it, photographed from two distances, as it is and with each level tinted --
## so the places two levels meet can be looked at before any level stands a world on the ground.
##
##   Godot --path cockpit --resolution 1600x900 res://tests/ground_view_shot.tscn -- --out=C:/some/folder
##
## A probe, not a suite: headless has no picture (seeing_the_game.md). It lays the game's world (`GroundTuning`) into a
## `SceneryYard` with a sky, a sun and a flat sea at 0, fills the yard round each eye, waits for the workers and a few
## drawn frames, and saves each view twice: `<view>.png` as drawn and `<view>_levels.png` with every cell's colour
## multiplied by its level's tint (16 m red, 32 m yellow, 64 m green, 128 m blue). The views look along the highest range
## from its south, where the ground is steepest and the gaps between levels deepest:
##
## - `near`: 400 m over the ground two cells out, looking at the range, so the 16 m, 32 m and 64 m boundaries fall
##   across the picture;
## - `far`: 3 km over the ground six cells out, looking down on the range, so every level is in frame.
##
## Prints RESULT=PASS and the files it wrote, or RESULT=FAIL and why.

const FAR: float = 24000.0
const CELL: int = 1024
const TINTS: Array[Color] = [Color(1.0, 0.45, 0.45), Color(1.0, 0.9, 0.35), Color(0.45, 1.0, 0.5), Color(0.45, 0.6, 1.0)]
## Frames drawn before a view is saved, after the yard has built it.
const SETTLE_FRAMES: int = 12

var _camera: Camera3D = null
var _field: Object = null
var _yard: SceneryYard = null
var _view: GroundView = null


func _ready() -> void:
	if not ClassDB.class_exists("GroundField"):
		print("RESULT=FAIL the extension has no GroundField")
		get_tree().quit()
		return
	var out: String = "user://ground_view_shot"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) if out.begins_with("user://") else out)
	_field = ClassDB.instantiate("GroundField")
	_field.call("configure", GroundTuning.values())
	_stage()
	_yard = SceneryYard.new()
	_yard.set_process(false)
	add_child(_yard)
	_view = GroundView.new()
	add_child(_view)
	var cells: int = _view.show_ground(_field, _yard, FAR)
	var peak: Vector2i = _highest_cell()
	print("[ground_view_shot] %d cells; the highest is %s" % [cells, peak])
	var written: PackedStringArray = []
	var middle := Vector3(float(peak.x * CELL + CELL / 2), 0.0, float(peak.y * CELL + CELL / 2))
	var views: Array = [["near", Vector3(0.0, 0.0, 2.0 * CELL), 400.0, 0.0],
		["far", Vector3(0.0, 0.0, 6.0 * CELL), 3000.0, -1500.0]]
	for row in views:
		var at: Vector3 = middle + (row[1] as Vector3)
		var ground: float = float(_field.call("height_ticks_at", int(at.x), int(at.z))) / 32.0
		var eye := Vector3(at.x, maxf(ground, 0.0) + float(row[2]), at.z)
		var target := Vector3(middle.x, maxf(float(_field.call("height_ticks_at", int(middle.x), int(middle.z))) / 32.0
			+ float(row[3]), 0.0), middle.z)
		written.append_array(await _shoot(String(row[0]), eye, target, out))
	print("RESULT=PASS wrote %s" % ", ".join(written))
	get_tree().quit()


## A sky, a sun, a sea at 0 and the camera.
func _stage() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -30.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90000.0, 90000.0)
	sea.mesh = plane
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.10, 0.22, 0.33)
	water.roughness = 0.2
	sea.material_override = water
	add_child(sea)
	_camera = Camera3D.new()
	_camera.near = 1.0
	_camera.far = FAR + 6000.0
	_camera.fov = 70.0
	add_child(_camera)
	_camera.make_current()


func _highest_cell() -> Vector2i:
	var best := Vector2i.ZERO
	var best_height: int = -(1 << 30)
	for cell in _yard.cells_of(GroundView.LAYER):
		var heights: PackedInt32Array = _field.call("heights", cell.x * CELL, cell.y * CELL, 9, 9, 128)
		heights.sort()
		if heights[heights.size() - 1] > best_height:
			best_height = heights[heights.size() - 1]
			best = cell
	return best


## One view, as drawn and with its levels tinted. Returns the files written.
func _shoot(label: String, eye: Vector3, target: Vector3, out: String) -> PackedStringArray:
	_camera.global_position = eye
	_camera.look_at(target, Vector3.UP)
	_yard.fill_around(eye)
	for i in range(SETTLE_FRAMES):
		_yard.watch(eye, 0.0)
		_yard.catch_up()
		await get_tree().process_frame
	var written: PackedStringArray = []
	written.append(await _save(out, label))
	var plain: Dictionary = {}
	var counts: Array[int] = [0, 0, 0, 0]
	for node in _view.get_children():
		var mesh_node := node as MeshInstance3D
		if mesh_node == null:
			continue
		var level: int = node.get_meta(&"level")
		counts[level] += 1
		plain[mesh_node] = mesh_node.material_override
		# A DUPLICATE OF THE CELL'S OWN MATERIAL, so the tinted picture keeps the cell's normal map.
		var tinted := (mesh_node.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		var tint: Color = TINTS[level]
		tinted.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
		mesh_node.material_override = tinted
	for i in range(3):
		await get_tree().process_frame
	written.append(await _save(out, label + "_levels"))
	for mesh_node in plain:
		(mesh_node as MeshInstance3D).material_override = plain[mesh_node]
	print("[ground_view_shot] %s from %s toward %s: %s cells at 16, 32, 64 and 128 m" % [label, eye.snappedf(1.0),
		target.snappedf(1.0), counts])
	return written


func _save(out: String, name: String) -> String:
	await RenderingServer.frame_post_draw
	var path: String = out.path_join(name + ".png")
	var image: Image = get_viewport().get_texture().get_image()
	var error: int = image.save_png(path)
	if error != OK:
		print("RESULT=FAIL could not save %s (error %d)" % [path, error])
	return path
