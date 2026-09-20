extends Node
## DO THE SKY'S OTHER BILLBOARDS STAY STILL ON A STILL CRAFT FAR FROM THE ORIGIN: a contrail segment, a burst's flash and
## a missile's plume, drawn by their real shaders, riding a craft that creeps.
##
##   Godot --path cockpit --fixed-fps 60 res://tests/billboards_shot.tscn
##
## NOT HEADLESS -- it reads back what the GPU drew. `shake_shot` does the same for a panel and a runway light; this is its
## companion for every other shader that stood up a quad with `skip_vertex_transform` and `VIEW_MATRIX * centre`, which a
## precision=double Godot hands the GPU in float32 (agents.md, "What the double build does and does not steady").
##
## THE SET. A craft creeps by 0.37 mm a frame for 90 frames, carrying an eye and three things 6 to 10 m ahead of it, each in
## its own screen box, the boxes checked apart: a contrail segment (contrail.gdshader, one MultiMesh instance with an origin,
## as ContrailYard lays one), a burst's flash (heavy_burst_fire.gdshader, one instance with no origin, as BurstYard lays
## them) and a missile's plume (missile_motor.gdshader on a plain quad, as MissileYard hangs one). Their clocks are held --
## `now` and `born` fixed, and Engine.time_scale 0 for the plume's TIME -- and every pixel is compared, so what
## changes is where each is drawn. At the origin every count has to be 0, or the measure is measuring something else.
##
## NEAR, BECAUSE THAT IS WHERE THE GRID SHOWS. float32's step is 0.49 mm at 9.46 km and 3.9 mm past 32 km; seen from 8 m
## that is a twentieth and a third of a pixel. A burst 40 m off in a first version of this probe never moved at 9.46 km on
## either editor, and would not have in the game: what steps is what is near the eye -- the plume of a missile just
## launched, the trail of the aeroplane in front, a burst beside you -- and the further out the world goes, the further
## from the eye that reaches. Hence the places: the origin, the carrier (9.46 km) and 60 km, for a 30-70 km world.
##
## THE VERDICTS: at 9.46 and 60 km on the double editor none of the three moves. Stock is not judged out there -- its craft
## is float32, so it moves in whole steps and every child rounds the same way each frame, and 60 km is past any use of it.
##
## Embers and flames are not in the set: an ember climbs and a flame's outline moves with TIME, which is held here only by
## time_scale and which their placement does not read differently. They take the same lines from
## world/shaders/billboard.gdshaderinc as the three measured here.

const PLACES: Array[float] = [0.0, 9460.0, 60000.0]
const CREEP: float = 0.00037
const FRAMES: int = 90
const SETTLE: int = 30
const EYE := Vector3(0.24, 0.94, -0.34)
const HALF: int = 100
## A pixel counts as drawn above this, in any channel, against black.
const LIT: float = 0.04

var _failures: PackedStringArray = []
var _craft: Node3D = null
var _eye: Camera3D = null
## name -> [the Node3D drawn, where on the craft its middle is].
var _things: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[billboards] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		_check("there_is_a_window", false, "headless draws nothing; run it windowed")
		_finish()
		return
	var double: bool = OS.has_feature("double")
	print("[billboards] %s, %s precision" % [Engine.get_version_info()["string"], "double" if double else "single"])
	Engine.time_scale = 0.0
	RenderingServer.set_default_clear_color(Color.BLACK)
	_craft = Node3D.new()
	add_child(_craft)
	_eye = Camera3D.new()
	_eye.position = EYE
	_craft.add_child(_eye)
	_eye.make_current()
	var contrail_at: Vector3 = EYE + Vector3(-3.0, 1.2, -8.0)
	var burst_at: Vector3 = EYE + Vector3(3.0, 1.2, -10.0)
	var plume_at: Vector3 = EYE + Vector3(0.0, -1.5, -6.0)
	_things["contrail"] = [_a_contrail_segment(contrail_at), contrail_at]
	_things["burst"] = [_a_burst_flash(burst_at), burst_at]
	_things["plume"] = [_a_plume(plume_at), plume_at]
	for pair in _things.values():
		_craft.add_child(pair[0])
	for place in PLACES:
		var drawn: Dictionary = await _creep_at(place)
		for name in drawn.keys():
			var frames: int = drawn[name]["frames"]
			print("[billboards] at %.0f m: %s changed on %d of %d frames (%d px lit)"
				% [place, name, frames, FRAMES, drawn[name]["lit"]])
			if place == 0.0:
				_check("the_%s_is_drawn_and_still_at_the_origin" % name, frames == 0 and drawn[name]["lit"] > 20,
					"%d frames, %d px" % [frames, drawn[name]["lit"]])
			elif double:
				_check("nor_does_the_%s_move_at_%.0f_m_on_double" % [name, place], frames == 0, "%d frames changed" % frames)
	Engine.time_scale = 1.0
	_finish()


## ONE SEGMENT, laid a second before the held clock, as ContrailYard._set_segment lays one. Thin, so its edges cross the box.
func _a_contrail_segment(at: Vector3) -> MultiMeshInstance3D:
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.use_colors = true
	var strip := QuadMesh.new()
	strip.size = Vector2(1.0, 1.0)
	many.mesh = strip
	many.instance_count = 1
	# Short enough that both ends are inside the box: a strip's long edges only show a step across them. The basis is the
	# yards' own, which the shader inverts.
	many.set_instance_transform(0, Transform3D(MissileYard.segment_basis(Vector3(1.0, 0.0, 0.0)), at))
	many.set_instance_custom_data(0, Color(9.0, 9.0, 0.3, 1.0))
	many.set_instance_color(0, Color(1.0, 1.0, 1.0, 1.0))
	var paint := ShaderMaterial.new()
	paint.shader = load("res://world/shaders/contrail.gdshader") as Shader
	for parameter in [["now", 10.0], ["life", 60.0], ["opacity", 1.0], ["start_width", 0.3], ["spread", 0.0]]:
		paint.set_shader_parameter(parameter[0], parameter[1])
	var node := MultiMeshInstance3D.new()
	node.multimesh = many
	node.material_override = paint
	node.extra_cull_margin = 512.0
	return node


## ONE FLASH QUAD (code 0) with no origin, the node where the burst is, as BurstYard lays them; `born` just before `now`.
func _a_burst_flash(at: Vector3) -> MultiMeshInstance3D:
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	many.mesh = quad
	many.instance_count = 1
	var along := Vector3(1.0, 0.0, 0.0)
	many.set_instance_transform(0, Transform3D(Basis(along, Vector3(0.0, 0.001, 0.0), Vector3(0.0, 0.0, 0.001)), Vector3.ZERO))
	many.set_instance_custom_data(0, Color(0.0, 0.5, 0.5, 0.5))
	var paint := ShaderMaterial.new()
	paint.shader = load("res://world/shaders/heavy_burst_fire.gdshader") as Shader
	for parameter in [["now", 10.0], ["flash_across", 1.0], ["flash_s", 100.0], ["grow_s", 1.0], ["cool_s", 1.0],
			["burn_s", 1.0], ["ember_s", 1.0], ["rise", 0.0], ["spark_speed", 0.0], ["spark_s", 1.0], ["gravity", 0.0]]:
		paint.set_shader_parameter(parameter[0], parameter[1])
	var node := MultiMeshInstance3D.new()
	node.multimesh = many
	node.material_override = paint
	node.extra_cull_margin = 512.0
	node.position = at
	node.set_instance_shader_parameter("born", 9.9)
	node.set_instance_shader_parameter("size", 0.6)
	return node


## A PLUME on a plain quad, its Y column back along the missile and its X column across, as MissileYard hangs one.
func _a_plume(at: Vector3) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var node := MeshInstance3D.new()
	node.mesh = quad
	var paint := ShaderMaterial.new()
	paint.shader = load("res://world/shaders/missile_motor.gdshader") as Shader
	node.material_override = paint
	node.extra_cull_margin = 64.0
	node.transform = Transform3D(Basis(Vector3(0.15, 0.0, 0.0), Vector3(0.0, 0.0, 1.2), Vector3(0.0, 1.0, 0.0)), at)
	node.set_instance_shader_parameter("burn", 1.0)
	return node


func _creep_at(out_there: float) -> Dictionary:
	# UP AS WELL AS ACROSS, so every axis is out where the grid is coarse and every axis creeps: at a fixed 500 m the vertical
	# step stays 0.03 mm, and a thing whose edges are mostly horizontal shows nothing of a step along x.
	# 50 m up at the origin, not 500: float32's vertical step at 500 m is 0.03 mm, and a soft glow's edge pixels moved a
	# few 8-bit steps under it -- 8 and 22 of 90 frames at the origin before this was lowered.
	var start := Vector3(out_there * 0.6, 50.0 + out_there * 0.5, out_there * 0.6)
	_craft.global_position = start
	for i in range(SETTLE):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var boxes: Dictionary = {}
	for name in _things.keys():
		boxes[name] = _box_round(_craft.global_transform * (_things[name][1] as Vector3))
	var names: Array = boxes.keys()
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			_check("the_%s_and_%s_boxes_are_apart_at_%.0f_m" % [names[i], names[j], out_there],
				not (boxes[names[i]] as Rect2i).intersects(boxes[names[j]]), "%s %s" % [boxes[names[i]], boxes[names[j]]])
	var out: Dictionary = {}
	for name in names:
		out[name] = {"frames": 0, "lit": 0}
	var before: Image = null
	for frame in range(FRAMES):
		_craft.global_position = start + Vector3(CREEP, CREEP, CREEP) * float(frame)
		await RenderingServer.frame_post_draw
		var now: Image = get_viewport().get_texture().get_image()
		for name in names:
			var box: Rect2i = boxes[name]
			if before != null and _changed(before, now, box) > 0:
				out[name]["frames"] += 1
			if frame == FRAMES - 1:
				out[name]["lit"] = _lit(now, box)
		before = now
	return out


func _box_round(world: Vector3) -> Rect2i:
	var centre := Vector2i(_eye.unproject_position(world))
	return Rect2i(centre - Vector2i(HALF, HALF), Vector2i(HALF * 2, HALF * 2)).intersection(
		Rect2i(Vector2i.ZERO, get_viewport().get_texture().get_size()))


func _is_lit(c: Color) -> bool:
	return maxf(c.r, maxf(c.g, c.b)) > LIT


## EVERY PIXEL, by more than `STEP` in some channel: with time_scale 0 nothing here changes of itself, and a soft edge
## moved by a hundredth of a pixel still turns a few 8-bit values over.
const STEP: float = 3.0 / 255.0


func _changed(a: Image, b: Image, box: Rect2i) -> int:
	var n: int = 0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			if absf(p.r - q.r) > STEP or absf(p.g - q.g) > STEP or absf(p.b - q.b) > STEP:
				n += 1
	return n


func _lit(image: Image, box: Rect2i) -> int:
	var n: int = 0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			if _is_lit(image.get_pixel(x, y)):
				n += 1
	return n


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
