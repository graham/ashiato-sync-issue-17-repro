extends Node3D

## WHAT ONE AEROPLANE COSTS TO DRAW, measured against two others in the SAME ROOM, in the SAME
## PROCESS, at the SAME RANGES. Scratch probe for `lane/phantomfast`, where the user's report was
## that the F-4E is expensive to render and that "the dithering" is what costs.
##
## ONE PROCESS, THREE CRAFT. Three separate runs cannot be subtracted from one another: the driver,
## the window, the shader cache and whatever else is on the GPU differ between them. Everything here
## is built once, and each kind is measured by SHOWING it and HIDING it against the same empty room
## a few frames apart, which is the shape `tests/fighter_inspector_shot.gd --measure` established.
##
## AND AT TWO RANGES, which is the point. A texture with no mip chain costs nothing much when it
## fills the screen and a great deal when it does not, so a near-only measurement is exactly the one
## that would miss it. NEAR is the inspector's own exterior pose; FAR is inside `DETAIL_RANGE` (800 m)
## so the same parts are drawn at both and the comparison is not secretly a LOD test.

## THE VARIANTS, in the order they are built and measured. The three Phantoms are the same aeroplane
## dressed three ways, so the difference between them is the wear layer and nothing else; the Tomcat
## and the F-35 are the controls -- comparable fighters that carry no texture at all.
const KINDS: Array[String] = ["phantom", "phantom-flat", "phantom-bare", "tomcat", "lightning"]
const NEAR_AT := Vector3(14.0, 7.0, 18.0)
## THE RANGE A PLAYER ACTUALLY SEES ANOTHER AIRCRAFT AT -- formation or gun-camera distance, and the
## worst case for this artefact. Aliasing off four-texel bands gets worse as the airframe shrinks and
## then stops being visible once it is a few pixels wide, so the peak is in the middle and neither the
## near nor the far pose would have found it.
const MID_AT := Vector3(58.7, 29.3, 75.5)
const FAR_AT := Vector3(170.0, 85.0, 220.0)
const MEASURED_FRAMES: int = 120

var _camera: Camera3D
var _frames: Dictionary = {}
var _out: String = ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.24, 0.28, 0.33)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 1.1
	env.ambient_light_color = Color(0.55, 0.57, 0.60)
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8, -0.55, 0.0)
	light.light_energy = 1.4
	add_child(light)

	for kind_name in KINDS:
		var frame: Node3D = null
		match kind_name:
			"phantom", "phantom-flat":
				frame = PhantomAirframe.new()
			"phantom-bare":
				frame = PhantomAirframe.new()
				frame.set("wear", false)
			"tomcat":
				frame = TomcatAirframe.new()
			"lightning":
				frame = LightningAirframe.new()
		add_child(frame)
		frame.call("dress")
		if kind_name == "phantom-flat":
			_take_its_mipmaps_away(frame)
		frame.visible = false
		_frames[kind_name] = frame
		_count(kind_name, frame)

	_camera = Camera3D.new()
	_camera.fov = 48
	_camera.current = true
	_camera.far = 4000.0
	add_child(_camera)

	var viewport: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	await _at_range("near", NEAR_AT, viewport)
	await _at_range("mid", MID_AT, viewport)
	await _at_range("far", FAR_AT, viewport)
	print("RESULT=PASS %d kinds at 2 ranges" % KINDS.size())
	get_tree().quit(0)


## THE STATE BEFORE THE FIX, REBUILT AT RUNTIME so that the before and the after are measured in ONE
## process, against the same empty room, seconds apart. `phantom-flat` wears the same sheet with its
## mip chain STRIPPED, which is exactly how the F-4 was drawn before this lane.
##
## WHY THE CONTROL IS THE STRIPPED ONE AND NOT THE MIPMAPPED ONE. Written the other way round -- build
## the aeroplane, then add mipmaps to a copy -- the control is whatever the source happens to do today,
## so the moment the fix lands the "before" silently becomes the "after" and the comparison measures
## nothing. Stripping keeps the before reproducible for as long as this probe exists.
##
## A NEW `ImageTexture`, NOT a mutation of the old one. `PhantomAirframe._baked` is a static shared by
## every Phantom ever built, so clearing its mipmaps in place would strip the real `phantom` too.
func _take_its_mipmaps_away(frame: Node3D) -> void:
	for found in frame.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		var standard := part.material_override as StandardMaterial3D
		if standard == null or not standard.detail_enabled or standard.detail_albedo == null:
			continue
		var image: Image = standard.detail_albedo.get_image()
		if image == null or not image.has_mipmaps():
			continue
		image.clear_mipmaps()
		standard.detail_albedo = ImageTexture.create_from_image(image)


## THE STATIC COST of a kind: what it puts in the tree before a frame is drawn.
func _count(kind_name: String, frame: Node3D) -> void:
	var parts: int = 0
	var surfaces: int = 0
	var vertices: int = 0
	var materials: Dictionary = {}
	var mipped: int = 0
	var flat: int = 0
	# THE OVERDRAW CANDIDATE, counted here because the slot is expensive and this costs nothing. A
	# see-through surface is drawn over whatever is behind it and cannot be depth-rejected; a
	# cull-disabled one is drawn twice. Both are paid per covered pixel, which is what "expensive at
	# close range but not at long range" looks like from the outside.
	var see_through: int = 0
	var two_sided: int = 0
	for found in frame.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if part.mesh == null:
			continue
		parts += 1
		surfaces += part.mesh.get_surface_count()
		for s in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(s)
			if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
				vertices += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var mat: Material = part.material_override if part.material_override != null else part.mesh.surface_get_material(s)
			if mat == null:
				continue
			materials[mat.get_instance_id()] = true
			var standard := mat as StandardMaterial3D
			if standard == null:
				continue
			if standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				see_through += 1
			if standard.cull_mode == BaseMaterial3D.CULL_DISABLED:
				two_sided += 1
			for texture in [standard.albedo_texture, standard.detail_albedo]:
				if texture == null:
					continue
				var image: Image = (texture as Texture2D).get_image()
				if image != null and image.has_mipmaps():
					mipped += 1
				else:
					flat += 1
	print("[craft_draw_cost] %s STATIC: %d parts, %d surfaces, %d vertices, %d materials, textures %d mipmapped / %d flat, %d see-through surfaces, %d two-sided"
		% [kind_name, parts, surfaces, vertices, materials.size(), mipped, flat, see_through, two_sided])


## EVERY KIND AT ONE RANGE, each against the same empty room.
func _at_range(label: String, from: Vector3, viewport: RID) -> void:
	_camera.global_position = from
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	for kind_name in KINDS:
		var frame: Node3D = _frames[kind_name]
		frame.visible = true
		var shown: Dictionary = await _average(viewport)
		if _out != "":
			var shot: Image = get_viewport().get_texture().get_image()
			shot.save_png(_out.path_join("%s-%s.png" % [kind_name, label]))
			_save_a_crop(shot, "%s-%s-close" % [kind_name, label])
		frame.visible = false
		var hidden: Dictionary = await _average(viewport)
		print("[craft_draw_cost] %s %s: +%.0f draw calls, +%.0f primitives, +%.3f ms CPU, +%.3f ms GPU (empty room %.0f / %.0f / %.3f / %.3f)"
			% [kind_name, label, shown["draws"] - hidden["draws"], shown["primitives"] - hidden["primitives"],
				shown["cpu"] - hidden["cpu"], shown["gpu"] - hidden["gpu"],
				hidden["draws"], hidden["primitives"], hidden["cpu"], hidden["gpu"]])


## THE SAME PIXELS, BIG ENOUGH TO SEE. At 290 m the aeroplane is about ninety pixels across, which is
## where the artefact is worst and where a full-frame still shows it least.
##
## CROPPED AND SCALED WITH NEAREST, NOT PHOTOGRAPHED WITH A LONGER LENS. A narrow field of view would
## put more pixels on the airframe, which is the very thing that makes the aliasing go away -- a
## telephoto shot at 290 m samples the sheet like a wide shot at 70 m and would quietly hide what it
## was taken to show. Cropping changes no pixel, and INTERPOLATE_NEAREST enlarges without inventing
## any, so what is in the picture is exactly what the renderer produced.
func _save_a_crop(shot: Image, named: String) -> void:
	var nose: Vector2 = _camera.unproject_position(Vector3(0.0, 0.0, -9.6))
	var tail: Vector2 = _camera.unproject_position(Vector3(0.0, 0.0, 9.6))
	var span: float = maxf(nose.distance_to(tail), 16.0) * 1.6
	var middle: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var box := Rect2i(Vector2i(middle - Vector2(span, span * 0.5) * 0.5), Vector2i(int(span), int(span * 0.5)))
	box = box.intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	if box.size.x < 8 or box.size.y < 8:
		return
	var crop: Image = shot.get_region(box)
	var grow: int = clampi(int(900.0 / float(box.size.x)), 1, 8)
	if grow > 1:
		crop.resize(box.size.x * grow, box.size.y * grow, Image.INTERPOLATE_NEAREST)
	crop.save_png(_out.path_join("%s.png" % named))


func _average(viewport: RID) -> Dictionary:
	for frame in range(10):
		await RenderingServer.frame_post_draw
	var sums := {"draws": 0.0, "primitives": 0.0, "cpu": 0.0, "gpu": 0.0}
	for frame in range(MEASURED_FRAMES):
		await RenderingServer.frame_post_draw
		sums["draws"] += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		sums["primitives"] += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		sums["cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(viewport)
		sums["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
	for key in sums:
		sums[key] = float(sums[key]) / MEASURED_FRAMES
	return sums
