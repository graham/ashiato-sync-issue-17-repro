extends Node3D
## THE HARRIER, LOOKED AT. Four orthographic views and a three-quarter, in a stage of this probe's own, so the shape
## can be argued with instead of asserted.
##
##   <editor>.console.exe --path cockpit --xr-mode off --resolution 1600x900 res://tests/harrier_shot.tscn -- --out=<folder>
##
## CLAUDE.md rule 2 exists because of models, and this lane has already paid for it once tonight: the exhaust was
## green through six checks and drew nothing at all, and then drew a white wall. Nine green checks on an airframe say
## its dimensions are right and NOTHING about whether it looks like the aeroplane.
##
## ASSERT WHAT IS IN THE FRAME, not that `save_png` returned OK (`modelling_here.md` section 7): each view projects
## the aeroplane's own drawn corners and requires them to cover a share of the picture, so a camera pointing at empty
## sky cannot pass. The commit and the date are burned into every frame, because a gallery goes stale and nothing in
## it says so.

const VIEWS: Array = [
	# THE AXES ARE THE CAMERA'S OWN PLACE, not the direction it looks: the camera stands at `middle + axis * range` and
	# looks back at the aeroplane. Forward is -Z here, so a camera on +Z is BEHIND the aeroplane and photographs its
	# tail. The first run of this had "side" on +Z and filed a rear view under that name -- a mislabelled picture is
	# worse than a missing one, because a reader judges the shape from it.
	["side", Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)],
	["plan", Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, -1.0)],
	["front", Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0)],
	["rear", Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 0.0)],
	["three-quarter", Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0)],
]

## THE SILHOUETTES, AND WHY THEY HAVE THEIR OWN SCALE. `craft/harrier/overlay_views.py` lays these over [SAC] page
## 2's own three views at x1.000 with no fitting, so the only figure that has to be agreed is the scale, and it is
## the DRAWING's: `measure_sac.py` sets 19.1889 px/ft off the published 30.33 ft span and nothing else, which is
## 62.956 px a metre. One pixel here is one pixel there and 15.9 mm on the aeroplane.
##
## FIFTEEN GREEN SUITES SHIPPED AN AEROPLANE THAT DID NOT LOOK LIKE A HARRIER, and this is the instrument that
## answers the question none of them asked. Ten other craft in this project have one (`craft/*/overlay_views.py`);
## the Harrier was measured harder than any of them -- three scripts, nine published figures recovered inside two
## per cent -- and was the only one whose drawn OUTLINE had never been compared with the drawing's.
const SILHOUETTE_PX_PER_METRE: float = 62.956
const SILHOUETTE := Color(0.82, 0.16, 0.55)
## THE CAMERA STANDS WHERE THE DRAUGHTSMAN DID. [SAC]'s side view puts the nose at the LEFT, so the camera is on
## the PORT side (-X) and not the starboard one the shaded gallery uses -- a mirrored silhouette would have to be
## flipped somewhere, and the honest place is here rather than in the script that scores it.
const SILHOUETTES: Array = [
	["side", Vector2i(1000, 440), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)],
	# THE PLAN VIEW IS TALL, NOT WIDE, and that is `keep_aspect = KEEP_WIDTH` speaking. `camera.size` is the frame's
	# WIDTH in metres, and in plan the aeroplane's 14.122 m of LENGTH runs up the screen while its 9.245 m of span
	# runs across it. At 1000 x 700 the frame was 15.88 m wide and 11.12 m tall, so the nose and the tail were cut
	# off -- and a cropped outline scored against a whole one reports a disagreement that belongs to the camera.
	["plan", Vector2i(700, 960), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, -1.0)],
	["front", Vector2i(760, 440), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0)],
]

var out: String = ""
var _frame: HarrierAirframe = null
var _camera: Camera3D = null
var _caption: Label = null
var _failures: PackedStringArray = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	_stage()
	await get_tree().process_frame
	await get_tree().process_frame
	for view in VIEWS:
		await _shoot(String(view[0]), view[1] as Vector3, view[2] as Vector3)
	# AND THE THINGS THAT MOVE, which a still of a parked aeroplane cannot show.
	_frame.set_nozzle(_frame.stop_at(HarrierAirframe.HOVER_STOP_DEG))
	await _shoot("nozzles-hover-stop", Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0))
	_frame.set_nozzle(1.0)
	await _shoot("nozzles-braking-stop", Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0))
	_frame.set_nozzle(0.0)
	_frame.set_gear(0.0)
	await _shoot("gear-up", Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0))
	_frame.set_gear(1.0)
	_frame.set_flaps(1.0)
	await _shoot("flaps-down", Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, -1.0))
	_frame.set_flaps(0.0)
	# AND THE THREE SILHOUETTES the overlay is laid from, at [SAC]'s own scale so no fitting is needed.
	for shape in SILHOUETTES:
		await _silhouette(String(shape[0]), shape[1] as Vector2i, shape[2] as Vector3, shape[3] as Vector3)
	print("RESULT=%s%s into %s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures), out])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _stage() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.86, 0.88, 0.91)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# AMBIENT_SOURCE_COLOR READS `ambient_light_color`, WHICH DEFAULTS TO BLACK, so setting only the energy lights
	# nothing and the model comes back looking like a vertex-colour bug (`modelling_here.md` section 7).
	env.ambient_light_color = Color(0.72, 0.75, 0.80)
	env.ambient_light_energy = 0.9
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, 138.0, 0.0)
	sun.light_energy = 1.5
	add_child(sun)
	_frame = HarrierAirframe.new()
	add_child(_frame)
	_frame.dress()
	_camera = Camera3D.new()
	_camera.current = true
	add_child(_camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(18.0, 14.0)
	_caption.add_theme_color_override("font_color", Color(0.06, 0.07, 0.09))
	_caption.add_theme_font_size_override("font_size", 22)
	layer.add_child(_caption)


## ONE VIEW. An orthographic camera along `look`, or a three-quarter when it is zero, fitted to the drawn vertices.
func _shoot(named: String, look: Vector3, up_hint: Vector3) -> void:
	var box: AABB = _bounds()
	var middle: Vector3 = box.position + box.size * 0.5
	var radius: float = box.size.length() * 0.5
	if look == Vector3.ZERO:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_camera.fov = 32.0
		_camera.global_position = middle + Vector3(1.0, 0.42, 1.25).normalized() * radius * 3.1
		_camera.look_at(middle, Vector3.UP)
	else:
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.size = maxf(box.size.x, maxf(box.size.y, box.size.z)) * 1.12
		_camera.global_position = middle + look.normalized() * (radius * 4.0)
		_camera.look_at(middle, Vector3.UP if absf(look.y) < 0.9 else up_hint)
	var stamp: String = _stamp()
	_caption.text = "AV-8B Harrier II  %s   %.3f x %.3f x %.3f m   %s" % [named, box.size.x, box.size.y, box.size.z, stamp]
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = out.path_join("cockpit-harrier-%s.png" % named)
	image.save_png(path)
	# WHAT IS ACTUALLY IN THE FRAME: the eight projected corners of the drawn box, as a share of the picture.
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for i in range(8):
		var corner: Vector2 = _camera.unproject_position(box.get_endpoint(i))
		low = low.min(corner)
		high = high.max(corner)
	var size: Vector2 = get_viewport().get_visible_rect().size
	var share: float = ((high.x - low.x) * (high.y - low.y)) / maxf(size.x * size.y, 1.0)
	var inside: bool = share > 0.05 and share < 1.6
	if not inside:
		_failures.append(named)
	print("[harrier_shot] %s %s covers %.1f per cent of the frame -> %s"
		% ["PASS" if inside else "FAIL", named, share * 100.0, path])


## ONE ORTHOGRAPHIC SILHOUETTE at `SILHOUETTE_PX_PER_METRE`, flat and unshaded, in its own SubViewport so the
## gallery's caption layer and its shaded environment cannot get into the picture.
##
## THE GEAR IS DOWN AND THE FLAPS ARE UP, because that is how [SAC] page 2 draws the aeroplane -- on its wheels, on
## a ground line raked 6.5 degrees. Drawing this one gear-up, as the F-35B's silhouettes are, would compare a clean
## aeroplane with a parked one and blame the difference on the airframe.
func _silhouette(named: String, size: Vector2i, from: Vector3, up: Vector3) -> void:
	var stage := SubViewport.new()
	stage.size = size
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# OWN_WORLD_3D OR THE STAGE IS NOT A STAGE. Without it the SubViewport shares the gallery's World3D, so its
	# WorldEnvironment reaches into that one instead of standing up its own -- the first run came back with all three
	# silhouettes covering 100.0 per cent of the frame, which is the gallery's grey sky photographed through a window
	# that had no world behind it. The edge-touch assertion caught it; a saved PNG and an OK return would not have.
	stage.own_world_3d = true
	add_child(stage)
	BuildStamp.attach_to(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	environment.environment = env
	stage.add_child(environment)
	var frame := HarrierAirframe.new()
	stage.add_child(frame)
	frame.dress()
	var flat := StandardMaterial3D.new()
	flat.albedo_color = SILHOUETTE
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for node in frame.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = flat
		for slot in range((node as MeshInstance3D).get_surface_override_material_count()):
			(node as MeshInstance3D).set_surface_override_material(slot, null)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = float(size.x) / SILHOUETTE_PX_PER_METRE
	camera.near = 0.05
	camera.far = 400.0
	camera.current = true
	stage.add_child(camera)
	camera.global_position = from.normalized() * 60.0
	camera.look_at(Vector3.ZERO, up)
	for _tick in range(4):
		await RenderingServer.frame_post_draw
	var path: String = out.path_join("cockpit-harrier-silhouette-%s.png" % named)
	var image: Image = stage.get_texture().get_image()
	image.save_png(path)
	# ASSERT WHAT IS IN THE FRAME: a silhouette that touched an edge was cropped, and a cropped outline compared
	# against a whole one reports a disagreement that is the camera's and not the aeroplane's.
	var painted: int = 0
	var touched: bool = false
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).r < 0.9:
				painted += 1
				if x == 0 or y == 0 or x == image.get_width() - 1 or y == image.get_height() - 1:
					touched = true
	var share: float = float(painted) / float(size.x * size.y)
	var ok: bool = share > 0.02 and not touched
	if not ok:
		_failures.append("silhouette-" + named)
	print("[harrier_shot] %s silhouette %s covers %.1f per cent%s -> %s"
		% ["PASS" if ok else "FAIL", named, share * 100.0, " TOUCHES AN EDGE" if touched else "", path])
	stage.queue_free()


func _bounds() -> AABB:
	var box := AABB()
	var first: bool = true
	for node in _frame.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var into: Transform3D = mesh.global_transform
		for p in (mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var at: Vector3 = into * p
			if first:
				box = AABB(at, Vector3.ZERO)
				first = false
			else:
				box = box.expand(at)
	return box


## THE BUILD, THE LANE AND THE WORKTREE, from `BuildPlate.line()` rather than from git calls of this probe's own.
## `lane/stamps` (2026-09-19) made that one line carry which lane and which worktree made a picture, and a probe that
## rolls its own stamp gets the commit and misses both -- so a reader cannot tell whose tree a shape came off.
## One line, one place.
func _stamp() -> String:
	var where: String = BuildPlate.where()
	return BuildPlate.line() + ("" if where.is_empty() else "  " + where)
