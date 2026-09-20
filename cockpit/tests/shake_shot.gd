extends Node
## DOES A STILL COCKPIT STAY STILL ON SCREEN FAR FROM THE ORIGIN: the frame-to-frame difference a still picture cannot show.
##
##   Godot --path cockpit --fixed-fps 60 res://tests/shake_shot.tscn
##
## NOT HEADLESS -- it reads back what the GPU drew, which is the half `tests/jitter.gd` cannot see: jitter.gd does the
## Transform3D sums on the processor, where a double build is exact, and reads 0 mm at every distance on it.
##
## THE SET: a craft, the eye 0.94 m up in it, a panel 0.5 m in front of the eye, and a runway light 3 m in front and well
## off to the side. The craft creeps along a diagonal by `CREEP` a frame carrying all three, so the
## picture should never change. Every frame is read back and held to the one before, in a box round each; a pixel that
## changes is the grid. At the origin and at the carrier's distance, 9460 m.
##
## WHAT IT SAYS, 2026-09-14, RTX 5080, Forward+ (agents.md, "What the double build does and does not steady"): on double
## the panel changed on 0 of 90 frames at the origin and at 9460 m -- an ordinary mesh, which a double build hands the GPU
## camera-relative, is steady far out -- and so does the light, since beacon.gdshaderinc places itself through
## MODELVIEW_MATRIX. Before that it took skip_vertex_transform and `VIEW_MATRIX * centre`, float32 on the GPU on both
## builds, and changed on 58 of 90 frames at 9460 m: `nor_does_a_runway_light_on_double` went red on that first.
## STOCK reads 0 for both only because its craft's own position is float32: the craft moves in whole steps and every child
## rounds the same way each frame. Stock is not steadier; this set cannot see its grid.
##
## WHAT WENT WRONG FIRST. The light stood 8 px outside the panel's counting box, FINE's halo reached into it, and the
## light's steps were read as the panel's -- "58 of 90 frames" -- and written into agents.md as "the GPU still draws on
## float32's grid". Moved clear, the panel reads 0 on the same editor. The boxes are now held apart by a check.
##
## THE VERDICTS: on the double build, neither the panel nor the light moves at the carrier.

const FAR: float = 9460.0
## 0.37 mm a frame: more than float32's 0.49 mm step at 9 km would be a whole step, and 0.1 mm, the first creep tried,
## is less than one -- on the stock editor the craft then never moved at all, and read 0 changed frames for it.
const CREEP: float = 0.00037
const FRAMES: int = 90
const SETTLE: int = 30
const EYE := Vector3(0.24, 0.94, -0.34)

var _failures: PackedStringArray = []
## `--creep=metres` overrides CREEP, to try a creep that is a whole float32 step.
var _creep: float = CREEP
var _craft: Node3D = null
var _eye: Camera3D = null
var _panel: MeshInstance3D = null
var _light: VehicleLights = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[shake] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		_check("there_is_a_window", false, "headless draws nothing; run it windowed")
		_finish()
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--creep="):
			_creep = float(argument.get_slice("=", 1))
	var double: bool = OS.has_feature("double")
	print("[shake] %s, %s precision, creep %.8f m a frame" % [Engine.get_version_info()["string"], "double" if double else "single", _creep])
	RenderingServer.set_default_clear_color(Color.BLACK)
	_craft = Node3D.new()
	add_child(_craft)
	_eye = Camera3D.new()
	_eye.position = EYE
	_craft.add_child(_eye)
	_eye.make_current()
	_panel = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.08, 0.01)
	_panel.mesh = box
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = Color(1.0, 0.0, 0.0)
	_panel.material_override = paint
	# Turned a little, so its edges cross pixels at an angle and any sub-pixel move shows as a changed edge pixel.
	_panel.transform = Transform3D(Basis(Vector3.FORWARD, 0.31), EYE + Vector3(-0.05, -0.03, -0.5))
	_craft.add_child(_panel)
	for place in [0.0, FAR]:
		var drawn: Dictionary = await _creep_at(place)
		var where: String = "%.0f m" % place
		print("[shake] at %s: panel changed on %d of %d frames (%d px in all), light on %d frames (%d px)"
			% [where, drawn["panel_frames"], FRAMES, drawn["panel_px"], drawn["light_frames"], drawn["light_px"]])
		if double and place == FAR:
			_check("a_still_panel_does_not_move_at_the_carrier_on_double", drawn["panel_frames"] == 0,
				"%d frames changed" % drawn["panel_frames"])
			_check("nor_does_a_runway_light_on_double", drawn["light_frames"] == 0,
				"%d frames changed" % drawn["light_frames"])
	_finish()


func _creep_at(out_there: float) -> Dictionary:
	var start := Vector3(out_there * 0.7, 500.0, out_there * 0.7)
	if _light != null:
		_light.queue_free()
	# Up and to the right, about 260 px from the panel on screen: at (0.3, 0.0, -3.0) FINE's halo reached the panel's box.
	var at: Vector3 = EYE + Vector3(1.2, 0.6, -3.0)
	_light = VehicleLights.build([{"position": at, "colour": Color.WHITE, "radius": 0.2}], 0, false)
	_craft.add_child(_light)
	_craft.global_position = start
	for i in range(SETTLE):
		await get_tree().process_frame
	var panel_box := _box_round(_panel.global_position, 90)
	var light_box := _box_round(_craft.global_transform * at, 30)
	# Grown by the FINE halo's reach, which is what the first version of this probe forgot.
	_check("the_light_is_clear_of_the_panels_box_at_%.0f_m" % out_there, not panel_box.intersects(light_box.grow(60)),
		"panel %s, light %s" % [panel_box, light_box])
	var before: Image = null
	var out := {"panel_frames": 0, "panel_px": 0, "light_frames": 0, "light_px": 0}
	for frame in range(FRAMES):
		_craft.global_position = start + Vector3(_creep, 0.0, _creep) * float(frame)
		await RenderingServer.frame_post_draw
		var now: Image = get_viewport().get_texture().get_image()
		if before != null:
			var panel_px: int = _changed(before, now, panel_box)
			var light_px: int = _changed(before, now, light_box)
			out["panel_frames"] += 1 if panel_px > 0 else 0
			out["panel_px"] += panel_px
			out["light_frames"] += 1 if light_px > 0 else 0
			out["light_px"] += light_px
		before = now
	return out


func _box_round(world: Vector3, half: int) -> Rect2i:
	var centre := Vector2i(_eye.unproject_position(world))
	return Rect2i(centre - Vector2i(half, half), Vector2i(half * 2, half * 2)).intersection(
		Rect2i(Vector2i.ZERO, get_viewport().get_texture().get_size()))


func _changed(a: Image, b: Image, box: Rect2i) -> int:
	var n: int = 0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
