extends Node
## Windowed and OFFSCREEN: does the compute mist lay itself on BOTH views of a headset's one multiview pass, each through its own
## projection? The watch level drawn through a SubViewport with `use_xr`, fed by a scripted two-view XR interface (`TwoEyes`) --
## never the live headset runtime: `--xr-mode off` keeps OpenXR out, and this interface draws nowhere but the SubViewport.
##
##   Godot --path cockpit --xr-mode off res://tests/mist_multiview.tscn -- --level=watch --mist-pass=compute --eyes=normal --out=DIR
##
## WHY IT IS NEEDED (team-lead, 2026-09-15): the compute mist lays itself on with one framebuffer per view on that view's slice of
## the colour texture (MistEffect._lay_on), and a headless check of the projections (tests/mist.gd) cannot see a framebuffer. So
## this renders two views for real and reads MistEffect.views_drawn, and saves the SubViewport's picture, for `--mist-pass=compute`
## against `--mist-pass=spatial` (the engine's own multiview path) with the same eyes.
##
## THE EYES ARE FAR APART ON PURPOSE: 40 m, converging at 3 km, so the two views of a town three kilometres off differ by far
## more than a pixel and a view drawn with the other's projection shows. `--eyes=swapped` exchanges them, so whatever picture the
## viewport hands back, both eyes' mist is compared across the two runs.
##
## Prints `RESULT=`; judge by it, and grep the log for engine errors (a framebuffer the engine refused would print one).
##
## RUN IT WITH OPENXR OFF BY SETTING, NOT BY FLAG: `--xr-mode off` turns the renderer's multiview shader variants off, and under it
## this drew nothing (agents.md, the --xr-mode off trap). An override.cfg in a scratch tree, `[xr] openxr/enabled=false` and
## `shaders/enabled=true`, with team-lead's guards.
##
## ITS OWN ARTEFACT, NOT THE MIST'S: with `--eyes=swapped` the engine prints "Condition p_top <= p_bottom is true" once a frame,
## on the spatial pass as on the compute mist -- a frustum `create_perspective_hmd` builds from the swapped eye. The pictures are
## still compared (2026-09-15: compute against spatial, swapped eyes, mean 0.01/255).

const WARM: int = 240
const DRAWN: int = 90
const SIZE := Vector2i(960, 540)

var _failures: PackedStringArray = []
var _level: Node = null
var _out: String = "user://mist_multiview"
var _eyes: String = "normal"


class TwoEyes extends XRInterfaceExtension:
	var swapped: bool = false
	var _ready_now: bool = false
	const EYE_APART: float = 40.0
	const CONVERGE: float = 3000.0

	func _get_name() -> StringName:
		return &"mist_two_eyes"

	func _get_capabilities() -> int:
		return XRInterface.XR_STEREO

	func _is_initialized() -> bool:
		return _ready_now

	func _initialize() -> bool:
		_ready_now = true
		return true

	func _uninitialize() -> void:
		_ready_now = false

	func _get_render_target_size() -> Vector2:
		return Vector2(SIZE)

	func _get_view_count() -> int:
		return 2

	func _get_camera_transform() -> Transform3D:
		return Transform3D()

	func _eye_of(view: int) -> int:
		var left: bool = (view == 0) != swapped
		return 1 if left else 2

	func _get_transform_for_view(view: int, cam_transform: Transform3D) -> Transform3D:
		var side: float = -0.5 if _eye_of(view) == 1 else 0.5
		return cam_transform * Transform3D(Basis(), Vector3(side * EYE_APART, 0.0, 0.0))

	func _get_projection_for_view(view: int, aspect: float, z_near: float, z_far: float) -> PackedFloat64Array:
		var p := Projection.create_perspective_hmd(70.0, aspect, z_near, z_far, false, _eye_of(view), EYE_APART, CONVERGE)
		var out := PackedFloat64Array()
		for column in range(4):
			var c: Vector4 = p[column]
			out.append_array([c.x, c.y, c.z, c.w])
		return out

	func _pre_draw_viewport(_render_target: RID) -> bool:
		return true

	func _get_tracking_status() -> int:
		return XRInterface.XR_NORMAL_TRACKING


func _check(label: String, ok: bool, detail: String) -> void:
	print("[multiview] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit()


func _ready() -> void:
	var asked_pass: String = MistLayer.pass_asked_on_the_command_line()
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() == 2 and parts[0] == "out":
			_out = parts[1]
		elif parts.size() == 2 and parts[0] == "eyes":
			_eyes = parts[1]
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	# WHICH LEVEL, AS BOOT WOULD CHOOSE IT (tests/scenery_shot.gd does the same).
	var world: Dictionary = ChartDrawer.asked_in(OS.get_cmdline_user_args(), "none")
	if String(world["error"]) != "":
		_check("the_level_asked_for_is_a_level", false, String(world["error"]))
		_finish()
		return
	if String(world["id"]) != "":
		var why: String = Net.choose_level(String(world["id"]))
		if why != "":
			_check("the_level_asked_for_is_chosen", false, why)
			_finish()
			return

	var eyes := TwoEyes.new()
	eyes.swapped = _eyes == "swapped"
	XRServer.add_interface(eyes)
	_check("the_two_eyes_start", eyes.initialize(), "a scripted XRInterfaceExtension, %s eyes" % _eyes)
	XRServer.primary_interface = eyes

	_level = (load("res://world/sky.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	if _level.get("observer") == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	await _wear_plain()
	for i in range(WARM):
		await get_tree().process_frame

	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.use_xr = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var origin := XROrigin3D.new()
	viewport.add_child(origin)
	var camera := XRCamera3D.new()
	origin.add_child(camera)
	camera.current = true
	# `mist_city` (tests/scenery_shot.gd): the first town from three kilometres south and 300 m up, looking at its middle.
	var town: Vector3 = TownCatalogue.towns()[0]["centre"]
	var at: Vector3 = town + Vector3(0.0, 300.0, 3000.0)
	var toward: Vector3 = town + Vector3(0.0, 40.0, 0.0)
	origin.global_transform = Transform3D(Basis.looking_at(toward - at, Vector3.UP), at)
	for i in range(DRAWN):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var mist: Node = _level.get("mist")
	var effect: MistEffect = mist.get("effect") if mist != null else null
	if asked_pass == "compute":
		_check("the_compute_mist_drew", effect != null and effect.laid > 0, "laid %d frames" % (effect.laid if effect != null else -1))
		_check("and_it_laid_itself_on_both_views", effect != null and effect.views_drawn == 2,
			"views drawn %d" % (effect.views_drawn if effect != null else -1))
	else:
		_check("the_spatial_mist_drew_with_no_compute_effect", effect == null or effect.laid == 0, "--mist-pass=%s" % asked_pass)
	var picture: Image = viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_out)
	var file: String = "%s/mist_city-%s-%s.png" % [_out, asked_pass, _eyes]
	_check("the_viewport_handed_back_a_picture", picture != null and not picture.is_empty() and picture.save_png(file) == OK,
		file if picture != null else "no image")
	_finish()


## PLAIN, as tests/scenery_shot.gd's `_wear` puts it on: the finish's own key, pressed and released, if FINE is on.
func _wear_plain() -> void:
	var finish: Node = get_node_or_null("/root/Finish")
	if finish == null or not bool(finish.call("is_fine")):
		return
	var code: Key = KEY_NONE
	for event in InputMap.action_get_events(String(finish.get("ACTION"))):
		var key := event as InputEventKey
		if key != null:
			code = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	for down in [true, false]:
		var press := InputEventKey.new()
		press.keycode = code
		press.physical_keycode = code
		press.pressed = down
		Input.parse_input_event(press)
		await get_tree().process_frame
	await get_tree().process_frame
	_check("the_finish_is_plain", not bool(finish.call("is_fine")), "Finish.is_fine() after its key")
