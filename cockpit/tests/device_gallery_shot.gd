extends Node
## ONE PICTURE OF EVERY DEVICE IN THE COCKPIT BUILDER'S PARTS BIN.
##
##   cockpit\device_gallery.bat
##   cockpit\device_gallery.bat --device=GuardedToggleSwitch --out=C:\somewhere
##
## This is a visual probe, not a headless suite. It builds each real `ControlCatalogue`
## part through its shipping setup path, puts it in a useful visible state, measures its
## rendered meshes, fits a common three-quarter camera and saves
## `cockpit-device-<part>.png`. The stage has no floor, because devices may extend below
## their origin and a floor can hide the part the gallery is meant to inspect.
## Carried controls, such as the DirectorCamera's keypad, appear with their parent.
## And the KIT every seat carries that the bin does not offer -- the signal lamp -- after the parts: see `_kit`.

const FOV: float = 42.0
const FILL: float = 0.62
const SETTLE_FRAMES: int = 4
## HOW HIGH THE DEVICE AND THE CAMERA STAND, in metres. The island map fixture below is drawn
## by this camera too, and its ground sits at about y = 0, so a lever or a pedal box that
## reaches below its origin was cut off by the grass. One metre clears every part in the bin.
## The camera is fitted to the device's bounds and moved with it, so the framing is unchanged.
const STAGE_HEIGHT: float = 1.0
const MapFixture := preload("res://tests/map_fixture.gd")
## DEVICES EVERY SEAT CARRIES THAT ARE NOT IN THE PARTS BIN, by class. None since 2026-09-19: the `SignalLamp` was
## the one, holstered at every seat, until lane/lampopt made it a part in `ControlCatalogue.PARTS`, which the gallery
## draws already. Kept, empty, for the next device a seat carries without its player choosing it.
static func _kit() -> Dictionary:
	return {}

var _out: String = ""
var _only: StringName = &""
var _failed: PackedStringArray = []
var _saved: int = 0
var _scheduled: int = 0
var _holder: Node3D = null
var _camera: Camera3D = null
var _caption: Label = null


func _ready() -> void:
	_parse_arguments()
	if DisplayServer.get_name() == "headless":
		_fail("rendering", "headless has no rendering device; run device_gallery.bat")
		_finish()
		return
	if not _only.is_empty() and not ControlCatalogue.has(_only) and not _kit().has(_only):
		_fail("requested_device_exists", "%s is not in ControlCatalogue.PARTS" % _only)
		_finish()
		return
	if DirAccess.make_dir_recursive_absolute(_out) != OK:
		_fail("output_directory", _out)
		_finish()
		return
	_build_stage()
	# The device room is centimetres wide and otherwise gives a kilometre-wide
	# map camera nothing to see. This layer is visible only to LevelMap.
	MapFixture.add_island(self)
	var parts: Array[StringName] = []
	for part in ControlCatalogue.PARTS:
		if _only.is_empty() or part == _only:
			parts.append(part)
	for part in _kit():
		if _only.is_empty() or part == _only:
			parts.append(part)
	_scheduled = parts.size()
	print("[device_gallery] %d devices into %s" % [_scheduled, _out])
	for part in parts:
		await _photograph(part)
	_finish()


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		var text := String(argument)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
		elif text.begins_with("--device="):
			_only = StringName(text.trim_prefix("--device="))
	if _out.is_empty():
		var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
		_out = repo.path_join("screenshots").path_join(Time.get_date_string_from_system())


func _build_stage() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.040, 0.065)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.58, 0.64, 0.72)
	environment.ambient_light_energy = 0.82
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	key.light_energy = 1.35
	key.shadow_enabled = true
	add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-0.35, 0.30 + STAGE_HEIGHT, 0.40)
	fill.omni_range = 2.0
	fill.light_energy = 1.2
	add_child(fill)

	_holder = Node3D.new()
	_holder.name = "Device"
	_holder.position = Vector3(0.0, STAGE_HEIGHT, 0.0)
	add_child(_holder)
	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.near = 0.003
	_camera.far = 20.0
	add_child(_camera)
	_camera.current = true

	var overlay := CanvasLayer.new()
	overlay.layer = 8
	add_child(overlay)
	_caption = Label.new()
	_caption.position = Vector2(34.0, 28.0)
	_caption.add_theme_font_size_override("font_size", 28)
	_caption.add_theme_color_override("font_color", Color(0.90, 0.96, 1.0))
	_caption.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_caption.add_theme_constant_override("shadow_offset_x", 2)
	_caption.add_theme_constant_override("shadow_offset_y", 2)
	overlay.add_child(_caption)


func _photograph(part: StringName) -> void:
	for child in _holder.get_children():
		_holder.remove_child(child)
		child.queue_free()
	await get_tree().process_frame
	var control: VehicleControl = (_kit()[part] as GDScript).new() as VehicleControl if _kit().has(part) \
		else ControlCatalogue.make(part)
	if control == null:
		_fail("%s_builds" % part, "ControlCatalogue.make returned null")
		return
	control.name = String(part)
	_holder.add_child(control)
	control.setup(0)
	_show_a_useful_state(control)
	await _frames(2)
	var bounds: AABB = _drawn_bounds(control)
	if bounds.size.length_squared() <= 0.000001:
		_fail("%s_has_drawn_bounds" % part, str(bounds))
		return
	_fit_camera(bounds)
	_caption.text = "%s\n%s\nW %.0f / H %.0f / D %.0f cm" % [
		ControlCatalogue.label_of(part), control.label_text().replace("\n", "  /  "),
		bounds.size.x * 100.0, bounds.size.y * 100.0, bounds.size.z * 100.0]
	await _frames(SETTLE_FRAMES)
	await RenderingServer.frame_post_draw
	if control is MapScreen:
		var canvas := (control as MapScreen).map_canvas()
		if canvas == null or not canvas.background_texture() is ImageTexture:
			_fail("MapScreen_has_a_frozen_background_texture", "missing after the render settled")
			return
	var slug: String = String(part).to_snake_case().replace("_", "-")
	var path: String = _out.path_join("cockpit-device-%s.png" % slug)
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	if error == OK:
		_saved += 1
		print("[device_gallery] %s -> %s" % [part, path])
	else:
		_fail("%s_is_saved" % part, "%s error %d" % [path, error])


## Show enough travel to explain the object without inventing any state outside the real
## control. Remote `apply` is used where possible because it redraws without emitting a
## command. Special display-only devices use their own presentation entry point.
func _show_a_useful_state(control: VehicleControl) -> void:
	if control is SignalLamp:
		(control as SignalLamp).ask(SignalLamp.RED, true)
	elif control is CrewButton:
		(control as CrewButton).light(true)
	elif control is GuardedToggleSwitch:
		var guarded := control as GuardedToggleSwitch
		guarded._guard_fraction = 1.0
		guarded.apply(guarded.from_command(guarded.channel_range))
	elif control is CommandButton:
		control.apply(control.from_command(1))
	elif control is ToggleSwitch:
		control.apply(control.from_command(control.channel_range))
	elif control is RudderPedals:
		(control as RudderPedals).show_rudder(0.72)
	elif control is TimeOfDayDial:
		(control as TimeOfDayDial).show_time(DaylightTuning.clock_of(DaylightTuning.When.EVENING))
	elif control is GunTrigger:
		control.hand_input(Bind.TRIGGER, true)
	elif control is MfdPanel:
		control.apply(control.from_command(mini(8, control.channel_range)))
	elif control is MapScreen:
		var chart := LevelChart.new()
		chart.world = "island"
		var map := LevelMap.new()
		control.add_child(map)
		map.configure(chart)
		map.rebuild()
		(control as MapScreen).show_map(map, [{"client": 2, "position": Vector3(1800, 0, -2200),
			"heading": 0.6, "yours": false, "name": "PLAYER 2", "colour": Color("ffbd59"),
			"distance": 2840.0}])
	else:
		control.apply(Vector2(0.32, 0.68))


func _fit_camera(bounds: AABB) -> void:
	# `bounds` is in the holder's frame, and the camera is not the holder's child, so the
	# centre is taken into the stage's frame first. That is what moves the camera up with it.
	var centre: Vector3 = _holder.transform * bounds.get_center()
	var radius: float = maxf(bounds.size.length() * 0.5, 0.025)
	var distance: float = maxf(radius / sin(deg_to_rad(FOV * 0.5)) / FILL, 0.12)
	var direction := Vector3(0.82, 0.62, 1.0).normalized()
	_camera.position = centre + direction * distance
	_camera.look_at(centre + Vector3(0.0, bounds.size.y * 0.04, 0.0), Vector3.UP)


## Rendered mesh bounds in the device holder's frame. This includes carried children and
## excludes the persistent lights outside `_holder`.
func _drawn_bounds(control: VehicleControl) -> AABB:
	var into_holder: Transform3D = _holder.global_transform.affine_inverse()
	var bounds := AABB()
	var any: bool = false
	for node in control.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.mesh == null or not drawn.is_visible_in_tree():
			continue
		var into: Transform3D = into_holder * drawn.global_transform
		var local: AABB = drawn.mesh.get_aabb()
		for corner in range(8):
			var point: Vector3 = into * local.get_endpoint(corner)
			if any:
				bounds = bounds.expand(point)
			else:
				bounds = AABB(point, Vector3.ZERO)
				any = true
	return bounds


func _frames(count: int) -> void:
	for frame in range(count):
		await get_tree().process_frame


func _fail(label: String, detail: String) -> void:
	_failed.append(label)
	print("[device_gallery] FAIL %s (%s)" % [label, detail])


func _finish() -> void:
	var ok: bool = _failed.is_empty() and _saved == _scheduled and _scheduled > 0
	print("[device_gallery] RESULT=%s %d of %d saved, %d failures, into %s" % [
		"PASS" if ok else "FAIL", _saved, _scheduled, _failed.size(), _out])
	get_tree().quit(0 if ok else 1)
