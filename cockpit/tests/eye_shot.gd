extends Node
## WHERE A SHADER THINKS THE EYE IS, AND A RUNWAY LIGHT DRAWN THE SAME SIZE HERE AND SEVEN KILOMETRES OUT.
##
##   Godot --path cockpit --fixed-fps 60 res://tests/eye_shot.tscn
##
## NOT HEADLESS -- it renders, and a headless picture is a black rectangle. Run it on BOTH editors: what it exists to
## catch is a difference between them.
##
## WHY IT EXISTS. On the double-precision editor the runway's approach lights drew as cream domes a hundred pixels and
## more across where the stock editor drew dots (2026-09-14). The cause is in Godot 4.7.2's Forward+ scene shader: a
## `precision=double` build overwrites the translation of the scene's inverse view matrix with MINUS the camera's
## origin (`render_scene_data_rd.cpp`, `split_double(-cam_transform.origin.x, ...)`), so the emulated-double
## `model + inv_view` sum comes out camera-relative -- and `CAMERA_POSITION_WORLD` is still renamed to that same
## `inv_view_matrix[3].xyz` (`scene_shader_forward_clustered.cpp`). On double it is minus the eye, in the vertex and
## the fragment stage alike. A light's size is `away * least_angle`, and `away` became the distance from the eye's
## mirror image, twice the distance from the origin.
##
## WHAT IT CHECKS, on each finish:
##   the_light_is_the_size_it_should_be_at_the_origin      a real runway light (VehicleLights, runway paint), 60 m off,
##                                                         against pi r^2 from its own radius and the camera's focal length
##   and_the_same_size_seven_kilometres_out                the same light and eye, moved together to (7000, 0, 7000)
##   the_house_eye_is_where_the_camera_is_here / _out_there  `eye.gdshaderinc`'s EYE_POSITION_WORLD, painted into a
##                                                         pixel as "within a metre of the camera" or not
## and REPORTS, without failing, whether `CAMERA_POSITION_WORLD` agrees -- that is Godot's, and says which build this is.
##
## The finish is chosen with `Finish.choose`, not the key: the switch is not what is under test here, and
## scenery_shot.gd already drives it through the key.

const OUT: String = "user://eye_shots"
## Where the far pair stands: out past the carrier's corner, where the double build's lights were widest.
const FAR := Vector3(7000.0, 0.0, 7000.0)
## Eye to light, metres, and the light's instance radius. Radius 4 draws a dot of about 20 px radius at 60 m.
const RANGE: float = 60.0
const LIGHT_RADIUS: float = 4.0
## How far the origin and far counts may differ, and how far the origin count may miss pi r^2.
const SAME_SIZE: float = 0.05
const EXPECTED_SIZE: float = 0.15
const SETTLE: int = 30

var _failures: PackedStringArray = []
var _eye: Camera3D = null
var _probe: MeshInstance3D = null
var _probe_paint: ShaderMaterial = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[eye] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		_check("there_is_a_window", false, "headless draws nothing; run it windowed")
		_finish()
		return
	print("[eye] %s, %s, window %s" % [Engine.get_version_info()["string"], RenderingServer.get_video_adapter_name(),
		DisplayServer.window_get_size()])
	RenderingServer.set_default_clear_color(Color.BLACK)
	_eye = Camera3D.new()
	add_child(_eye)
	_eye.make_current()
	_probe = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	_probe.mesh = quad
	_probe_paint = ShaderMaterial.new()
	_probe_paint.shader = load("res://tests/eye_probe.gdshader") as Shader
	_probe.material_override = _probe_paint
	add_child(_probe)
	var finish: Node = get_tree().root.get_node_or_null("Finish")
	for fine in [false, true]:
		if finish != null:
			finish.call("choose", fine)
		var name_of: String = "fine" if fine else "plain"
		var here: Dictionary = await _look(Vector3.ZERO, name_of + "-origin")
		var there: Dictionary = await _look(FAR, name_of + "-far")
		var expected: float = PI * pow(_drawn_radius_px(), 2.0)
		if not fine:
			_check("the_light_is_the_size_it_should_be_at_the_origin",
				absf(here["lit"] - expected) <= expected * EXPECTED_SIZE,
				"plain: %d px lit, pi r^2 %.0f" % [here["lit"], expected])
		_check("and_the_same_size_seven_kilometres_out_" + name_of,
			absf(there["lit"] - here["lit"]) <= maxf(here["lit"], 1.0) * SAME_SIZE,
			"%s: %d px at the origin, %d px at %s" % [name_of, here["lit"], there["lit"], FAR])
		_check("the_house_eye_is_where_the_camera_is_here_" + name_of, here["house_eye"], "origin")
		_check("the_house_eye_is_where_the_camera_is_out_there_" + name_of, there["house_eye"], str(FAR))
		print("[eye] engine %s CAMERA_POSITION_WORLD within a metre of the camera: origin %s, far %s"
			% [name_of, here["built_in_eye"], there["built_in_eye"]])
	_finish()


## ONE LOOK: the eye 60 m from a light at `place`, the probe quad off to one side in front of it, both drawn, read back.
func _look(place: Vector3, label: String) -> Dictionary:
	var at: Vector3 = place + Vector3(0.0, 2.0, 0.0)
	_eye.global_transform = Transform3D(Basis.IDENTITY, at + Vector3(0.0, 0.0, RANGE))
	var lights := VehicleLights.build([{"position": at, "colour": Color.WHITE, "radius": LIGHT_RADIUS}], 0, false)
	add_child(lights)
	# The probe quad 2 m in front of the eye and a metre and a half left, about 440 px off the light's dot on screen: its
	# first place, 195 px off, sat inside the counting box and added 6,084 green pixels to every light.
	_probe.global_transform = Transform3D(Basis.IDENTITY, _eye.global_position + Vector3(-1.5, 0.0, -2.0))
	_probe_paint.set_shader_parameter("truth", _eye.global_position)
	for i in range(SETTLE):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	picture.save_png("%s/%s.png" % [OUT, label])
	var probe_px: Vector2 = _eye.unproject_position(_probe.global_position)
	var probe: Color = picture.get_pixelv(Vector2i(probe_px))
	var lit: int = 0
	var box := Rect2i(Vector2i(_eye.unproject_position(at)) - Vector2i(300, 300), Vector2i(600, 600))
	box = box.intersection(Rect2i(Vector2i.ZERO, picture.get_size()))
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var c: Color = picture.get_pixel(x, y)
			# BLUE, because the light is white and the probe paints only red and green.
			if c.b > 0.1:
				lit += 1
	lights.queue_free()
	await get_tree().process_frame
	print("[eye] %s: %d px lit round the light, probe pixel %s" % [label, lit, probe])
	return {"lit": lit, "built_in_eye": probe.r > 0.5, "house_eye": probe.g > 0.5}


## The dot's radius on screen, in pixels, from the shader's own sums: the larger of its real size and its least angle,
## both halved by the runway's `size_scale`, pulled towards the eye by its radius, over the camera's focal length.
func _drawn_radius_px() -> float:
	var paint: ShaderMaterial = VehicleLights.runway_paint()
	var size_scale: float = float(paint.get_shader_parameter("size_scale"))
	var least_scale: float = float(paint.get_shader_parameter("least_scale"))
	var least_angle: float = 0.0016
	var radius: float = maxf(LIGHT_RADIUS * size_scale, RANGE * least_angle * least_scale)
	var focal: float = float(get_viewport().get_visible_rect().size.y) * 0.5 / tan(deg_to_rad(_eye.fov) * 0.5)
	return radius * focal / (RANGE - radius)


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
