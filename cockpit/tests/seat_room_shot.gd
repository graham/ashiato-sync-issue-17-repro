extends Node3D
## Windowed: THE PLAYER ENVELOPE `seat_room` MEASURES, drawn at a seat, so a tight seat can be SEEN.
##
##   Godot --path cockpit res://tests/seat_room_shot.tscn -- --seats=cessna/0,uh60/0 --out=<dir>
##
## A PICTURE OF A MEASUREMENT, NOT A MEASUREMENT: `tests/seat_room.gd` is the number and this only draws it. At each seat
## the head clearance (0.20 either side of the eye, 0.25 over it, 0.30 ahead) and the shoulder clearance (0.30 either side
## of the centreline) are drawn as boxes in the seat's own frame, twice: SOLID RED with the depth test on, so whatever of
## the envelope is OUTSIDE the craft's skin shows red from outside, and a faint outline with the depth test off, so the
## whole of it can be placed. Then three pictures per seat:
##
##   -side      from outboard, 4 m off, level with the eye: red through the roof or the side is the room that is missing.
##   -front     from ahead and a little above.
##   -eye       FROM THE EYE, looking ahead, with every drawn surface made double-sided -- an exterior skin is drawn to be
##              seen from outside and is invisible from within, which is a picture of room that is not there.
##
## NOT HEADLESS. RESULT= is only whether every picture saved. The craft is built from outside with `_show_in_editor()` and
## painted with `_show_body(false)`, never ghosted.

const HEAD_UP: float = 0.25
const HEAD_SIDE: float = 0.20
const HEAD_FORE: float = 0.30
const SHOULDER: float = 0.30

var out: String = ""
var camera: Camera3D
var failures: PackedStringArray = []


func _ready() -> void:
	CockpitStation.use_saved_layouts = false
	var seats: PackedStringArray = ["cessna/0", "uh60/0", "tanker/0", "glider/1", "fighter/0"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
		elif argument.begins_with("--seats="):
			seats = argument.trim_prefix("--seats=").split(",")
	if out.is_empty():
		out = ProjectSettings.globalize_path("user://seat_room_shot")
	DirAccess.make_dir_recursive_absolute(out)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.72, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.65)
	env.ambient_light_energy = 1.0
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8, -0.55, 0.0)
	light.light_energy = 1.3
	add_child(light)
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.current = true
	add_child(camera)
	for entry in seats:
		var kind_name: String = entry.get_slice("/", 0)
		var seat: int = int(entry.get_slice("/", 1))
		await _one(kind_name, seat)
	print("[seat_room_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL " + ", ".join(failures), out])
	get_tree().quit(0 if failures.is_empty() else 1)


func _one(kind_name: String, seat: int) -> void:
	var scene := load("res://objects/vehicles/craft_%s.tscn" % kind_name) as PackedScene
	if scene == null:
		failures.append("%s: no scene" % kind_name)
		return
	var view := scene.instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	view._show_body(false)
	if seat >= view.seats.size():
		failures.append("%s: no seat %d" % [kind_name, seat])
		view.queue_free()
		return
	var anchor: Node3D = view.seat_anchor(seat)
	var eye := Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
	var shoulder_y: float = CockpitStation.EYE_HEIGHT - CockpitStation.NECK
	var marks := Node3D.new()
	marks.name = "Envelope"
	anchor.add_child(marks)
	# The head: x +/-HEAD_SIDE, from 0.12 under the eye to HEAD_UP over it, 0.10 behind it to HEAD_FORE ahead.
	_box(marks, AABB(Vector3(-HEAD_SIDE, eye.y - 0.12, -HEAD_FORE), Vector3(HEAD_SIDE * 2.0, 0.12 + HEAD_UP, HEAD_FORE + 0.10)))
	# The shoulders: x +/-SHOULDER, 0.16 deep and 0.16 tall about the shoulder line.
	_box(marks, AABB(Vector3(-SHOULDER, shoulder_y - 0.08, -0.08), Vector3(SHOULDER * 2.0, 0.16, 0.16)))
	await get_tree().process_frame
	var eye_world: Vector3 = anchor.global_transform * eye
	var basis: Basis = anchor.global_transform.basis.orthonormalized()
	var outboard: Vector3 = basis.x * (1.0 if (view.global_transform.affine_inverse() * eye_world).x >= 0.0 else -1.0)
	var tag: String = "%s-seat%d" % [kind_name, seat]
	camera.fov = 40.0
	await _capture("%s-side.png" % tag, eye_world + outboard * 4.0 + Vector3.UP * 0.3, eye_world)
	await _capture("%s-front.png" % tag, eye_world - basis.z * 4.5 + Vector3.UP * 1.6 + outboard * 1.0, eye_world)
	_double_sided(view)
	marks.visible = false
	camera.fov = 90.0
	await _capture("%s-eye.png" % tag, eye_world, eye_world - basis.z * 5.0 + Vector3.UP * 0.2)
	view.queue_free()
	await get_tree().process_frame


func _box(parent: Node3D, box: AABB) -> void:
	for pass_through in [false, true]:
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = box.size
		mesh.mesh = cube
		mesh.position = box.get_center()
		var paint := StandardMaterial3D.new()
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		paint.cull_mode = BaseMaterial3D.CULL_DISABLED
		if pass_through:
			paint.no_depth_test = true
			paint.albedo_color = Color(1.0, 0.85, 0.1, 0.18)
		else:
			paint.albedo_color = Color(0.95, 0.05, 0.05, 0.85)
		mesh.material_override = paint
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mesh)


## Every drawn surface seen from both sides, so a skin drawn for the outside is a wall from within.
func _double_sided(view: Node) -> void:
	var stack: Array[Node] = [view]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		if mesh.material_override is BaseMaterial3D:
			var both := (mesh.material_override as BaseMaterial3D).duplicate() as BaseMaterial3D
			both.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.material_override = both
		else:
			for surface in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(surface) as BaseMaterial3D
				if material != null:
					var copy := material.duplicate() as BaseMaterial3D
					copy.cull_mode = BaseMaterial3D.CULL_DISABLED
					mesh.set_surface_override_material(surface, copy)


func _capture(filename: String, from: Vector3, at: Vector3) -> void:
	camera.global_position = from
	camera.look_at(at, Vector3.UP if absf((at - from).normalized().y) < 0.98 else Vector3.FORWARD)
	for i in range(6):
		await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = out.path_join(filename)
	if image == null or image.save_png(path) != OK:
		failures.append(filename)
	else:
		print("[seat_room_shot] saved %s" % path)
