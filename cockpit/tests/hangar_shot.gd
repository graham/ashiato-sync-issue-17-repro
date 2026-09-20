extends Node
## HANGAR 03, PHOTOGRAPHED THE WAY THE CONCEPT SHEET DRAWS IT: the hero three-quarter, the three elevations, the rear
## three-quarter, the roof from above, the lit interior, and the fighter standing in the open door.
##
##   Godot --xr-mode off --path cockpit --resolution 1600x900 res://tests/hangar_shot.tscn -- --desktop-only --out=DIR
##
## NOT HEADLESS: headless has no rendering device and every picture comes back a black rectangle. A PROBE, because
## whether a building reads like the sheet it was drawn from has no assertion; `tests/hangar.gd` holds every dimension,
## the clear opening, the bays, the solid and the markings.
##
## IT PHOTOGRAPHS THE REAL LEVEL, not a stage of its own: `Net.choose_level("hangar_yard")` and the production
## `world/sky.tscn` underneath this probe, which is how `builder_shot` and `lobby_shot` do it. So the light, the sky, the
## apron, the hangar and the parked fighter in these pictures are the ones a player walks into, and a level that failed
## to stand its hangar up would photograph an empty apron rather than a pretty lie.
##
## THE ELEVATIONS ARE ORTHOGRAPHIC, because the sheet's are: a perspective "front elevation" cannot be laid over a
## drawing and argued with. The hero and the three-quarters are perspective, as the sheet's are. The elevations, the
## roof and the rear three-quarter are lit by a shadowless fill down the camera's own line of sight, because the sun
## stands over the door face and left the rear and the left side reading as dark slabs of a white-and-yellow building.
##
## WHAT IT ACTUALLY ASSERTS, none of which is "the picture looks right": that the viewport DREW with this probe's
## camera, that the building covers a floor share of the frame, and that the spine's deck reads light enough for the
## roof's "03" to show. The first two exist because nine pictures of a Segway's desk once passed under RESULT=PASS
## (`modelling_here.md`, "Traps in taking the picture"); the third because a lid over the deck is invisible to every
## vertex check. It also writes `frames.json`, which is where the building landed on screen in each picture, so
## `tools/hangar_comparison.py` crops each render to the building by measurement rather than by a typed-in box.
##
## Read RESULT=, not the exit code.

const LEVEL := preload("res://world/sky.tscn")
## Physics frames to wait for the level to stand up: ten seconds at 120 Hz.
const PATIENCE: int = 1200
## Frames a view is held before its picture, so the light and the sky have settled.
const SETTLE: int = 6
## THE LEAST OF THE FRAME THE BUILDING MAY COVER and still count as a picture of it. The interior view is the tightest
## of the nine and the doorway elevation the loosest crop, so this is a floor that catches "the hangar is not in this
## picture at all" rather than a framing rule -- the framing is judged by eye.
const LEAST_COVER: float = 0.06
## How many times a view is taken before the probe accepts that something else owns the viewport.
const ATTEMPTS: int = 4
## How light the spine's armoured deck must read for a dark "03" to show on it at all.
const DECK_IS_LIGHT: float = 0.5
## How hard the drawing fill is driven. Enough to bring a shaded wall up to its own paint, not enough to flatten the
## panel shading that makes the building read as a solid.
const FILL_ENERGY: float = 0.85

var _out: String = ""
## THE PICTURE NUMBER, counted here rather than typed into each call. Screenshots are numbered per lane
## (`cockpit-hangar-01-...` upward), and a number typed beside each name is a roster that goes out of step the first
## time a view is inserted in the middle -- `CLAUDE.md` rule 4, one number in one place.
var _shot: int = 0
## Where the building landed on the screen in each picture, keyed by file name, written out as `frames.json`.
var _frames: Dictionary = {}
var _saved: PackedStringArray = []
var _failed: PackedStringArray = []
var _level: FlightLevel = null
var _camera: Camera3D = null
var _filler: DirectionalLight3D = null
var _fill_wanted: bool = false


func _asked(name: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--%s=" % name):
			return argument.trim_prefix("--%s=" % name)
	return ""


func _ready() -> void:
	_out = _asked("out")
	if _out.is_empty():
		_out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(_out)
	var refusal: String = Net.choose_level(HangarYard.LEVEL_ID)
	if refusal != "":
		print("[hangar_shot] RESULT=FAIL %s" % refusal)
		get_tree().quit(1)
		return
	_level = LEVEL.instantiate() as FlightLevel
	add_child(_level)
	var yard: HangarYard = null
	for _frame in range(PATIENCE):
		yard = _level.get("hangar_yard") as HangarYard
		if yard != null and yard.hangar != null and yard.hangar.shell != null:
			break
		await get_tree().physics_frame
	if yard == null or yard.hangar == null:
		print("[hangar_shot] RESULT=FAIL the hangar yard did not stand up (level %s)"
			% [_level.level.id if _level.level != null else "-"])
		get_tree().quit(1)
		return
	# THE STATUS LINE IS NOT PART OF THE BUILDING. `Ui` is a CanvasLayer and not a CanvasItem, so it is hidden by name
	# rather than by cast (modelling_here.md, section 7).
	var overlay: Node = _level.get_node_or_null("Ui")
	if overlay != null:
		overlay.set("visible", false)
	_camera = Camera3D.new()
	_camera.name = "ShotCamera"
	_level.add_child(_camera)
	_take_the_view()
	for path in _camera_paths():
		print("[hangar_shot] camera in the tree: %s" % path)
	for child in _level.get_children():
		print("[hangar_shot] level child: %s (%s)" % [child.name, child.get_class()])
	var deep: float = SkyfrontHangar.depth_of(HangarYard.HANGAR_BAYS)
	var half_deep: float = deep * 0.5
	var high: float = SkyfrontHangar.SPINE_TOP

	# 1. THE HERO: the sheet's own three-quarter, from the door's right, door open and the fighter inside.
	await _picture("hero-three-quarter-front", Vector3(30.0, 9.0, 58.0), Vector3(0.0, 5.0, 6.0), 40.0)
	# 2-4. THE THREE ELEVATIONS, orthographic, each framed on the building and nothing else.
	await _elevation("front-elevation-door-open", Vector3(0.0, high * 0.5, half_deep + 70.0), 20.0)
	await _elevation("rear-elevation", Vector3(0.0, high * 0.5, -half_deep - 70.0), 20.0)
	await _elevation("side-elevation-left", Vector3(-SkyfrontHangar.SPAN * 0.5 - 70.0, high * 0.5, 0.0), 24.0)
	# 5. THE REAR THREE-QUARTER, from above the far corner as the sheet has it.
	_fill(true)
	await _picture("rear-three-quarter", Vector3(-44.0, 15.0, -44.0), Vector3(0.0, 5.0, 0.0), 40.0)
	_fill(false)
	# 6. THE ROOF FROM ABOVE, orthographic, length across the frame as the sheet's top view draws it.
	await _roof("top-view-roof", 38.0)
	_the_spine_deck_reads_light()
	# 7. THE LIT INTERIOR, from the back of the bay looking out past the parked fighter.
	await _picture("interior-from-the-back", Vector3(9.5, 3.2, -18.0), Vector3(-2.0, 3.2, 10.0), 72.0)
	# 8. AND THE FIGHTER IN THE DOORWAY, where the clearances are there to be read.
	await _the_fighter_in_the_doorway()
	var sidecar := FileAccess.open(_out.path_join("frames.json"), FileAccess.WRITE)
	if sidecar != null:
		sidecar.store_string(JSON.stringify(_frames, "	"))
		sidecar.close()
	print("[hangar_shot] saved %d: %s" % [_saved.size(), ", ".join(_saved)])
	print("[hangar_shot] RESULT=%s into %s" % ["PASS" if _failed.is_empty() else "FAIL %s" % ", ".join(_failed), _out])
	get_tree().quit(0 if _failed.is_empty() else 1)


## THE SPINE DECK IS LIGHT, AND ITS NUMBER READS ON IT -- asked of the RENDERED PIXELS, because no vertex check can see
## this. The sheet's top view draws a light armoured deck with a dark "03" on it. The deck was buried: the spine's
## "gunmetal rim on top" was a solid box the full size of the deck, laid over the light panel, with the number's own
## gunmetal glyphs 0.07 m above it -- dark paint on a dark slab, invisible, while every dimension check stayed green.
##
## A BOX'S ONLY VERTICES ARE ITS EIGHT CORNERS, so a plate covering the deck puts nothing in the middle of it and a
## "nothing is drawn over the centre" vertex check passes over the fault in both directions. The pixel is the datum
## (`modelling_here.md`: where something physically ended up -- the landing point, the drawn vertex, the PIXEL).
func _the_spine_deck_reads_light() -> void:
	var picture: Image = get_viewport().get_texture().get_image()
	var frame: Rect2 = Rect2(Vector2.ZERO, Vector2(picture.get_size()))
	var darkest: float = 1.0
	var where: String = ""
	# Four points on the deck, clear of the "03" -- the glyphs are 4.4 m tall across X and about 6 m of text along Z.
	for x in [-3.8, 3.8]:
		for z in [-4.5, 4.5]:
			var at: Vector3 = _level.get_node("HangarYard").global_position + Vector3(x, SkyfrontHangar.SPINE_TOP, z)
			var on_screen: Vector2 = _camera.unproject_position(at)
			if not frame.has_point(on_screen):
				_failed.append("spine-deck (%.1f, %.1f) is off the frame" % [x, z])
				return
			var lit: float = picture.get_pixelv(Vector2i(on_screen)).get_luminance()
			if lit < darkest:
				darkest = lit
				where = "(%.1f, %.1f)" % [x, z]
	if darkest < DECK_IS_LIGHT:
		_failed.append("the spine deck is dark: luminance %.2f at %s" % [darkest, where])
		print("[hangar_shot] FAILED the spine deck reads dark -- luminance %.2f at %s, so the roof \"03\" cannot show"
			% [darkest, where])
		return
	print("[hangar_shot] the spine deck reads light: luminance %.2f at its darkest %s" % [darkest, where])


## EVERY Camera3D IN THE TREE, by path, for the diagnostic line.
func _camera_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for camera in _cameras_under(get_tree().root):
		paths.append("%s%s" % [camera.get_path(), " <-- MINE" if camera == _camera else ""])
	return paths


## Every Camera3D under `node`, recursively.
func _cameras_under(node: Node) -> Array[Camera3D]:
	var found: Array[Camera3D] = []
	var camera := node as Camera3D
	if camera != null:
		found.append(camera)
	for child in node.get_children():
		found.append_array(_cameras_under(child))
	return found


## TAKE THE VIEW, AND KEEP IT. The level arrives its players in a Segway (`level.json`'s `"arrive": "segway"`), and that
## craft's seat camera makes itself current AFTER this probe adds its own -- so the first nine pictures taken here were
## all the same shot of the Segway's desk, with `RESULT=PASS` over them, because the only thing being asserted was that
## `save_png` returned OK. Every other camera is switched off by hand and this one made current again before each
## picture, rather than once at setup.
func _take_the_view() -> void:
	for camera in _cameras_under(get_tree().root):
		if camera != _camera:
			camera.current = false
	_camera.current = true


## A DRAWING'S LIGHT, NOT THE WORLD'S -- for the views that are laid beside a drawing and argued with.
##
## The sun stands in one place, so it lights the door face and leaves the rear and the left side in its shade: the rear
## and side elevations came back as dark blue-grey slabs, and the sheet's own panels are white and yellow. A picture
## that misreports the paint is worse than no picture, and "the colours are important" is the brief. So the elevations,
## the roof and the rear three-quarter get a shadowless fill along the camera's own line of sight, which is how an
## elevation on a sheet is lit; the hero, the interior and the doorway keep the world's light, because those are meant
## to look like the place rather than like a drawing of it.
## Asked for here, AIMED IN `_save` -- the camera is moved by the caller after this is asked for on the three-quarter,
## and a fill aimed down the camera's previous line of sight lights the wrong wall.
func _fill(on: bool) -> void:
	_fill_wanted = on


## A perspective picture from `from`, looking at `at`.
func _picture(named: String, from: Vector3, at: Vector3, fov: float) -> void:
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = fov
	_camera.global_position = from
	_camera.look_at(at, Vector3.UP)
	await _save(named)


## An orthographic elevation from `from`, looking at the building's middle.
func _elevation(named: String, from: Vector3, size: float) -> void:
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = size
	_camera.global_position = from
	_camera.look_at(Vector3(0.0, from.y, 0.0), Vector3.UP)
	_fill(true)
	await _save(named)
	_fill(false)


## THE ROOF, STRAIGHT DOWN, with the building's LENGTH across the frame -- which is how the sheet's top view is drawn, so
## the two can be laid side by side. A camera looking down needs its up told to it: `look_at` with `Vector3.UP` on a
## straight-down view is degenerate.
func _roof(named: String, size: float) -> void:
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = size
	_camera.global_position = Vector3(0.0, 90.0, 0.0)
	_camera.look_at(Vector3.ZERO, Vector3(1.0, 0.0, 0.0))
	_fill(true)
	await _save(named)
	_fill(false)


## THE FIGHTER STOOD IN THE OPEN DOOR, and what it clears: a second airframe, parked on the door plane by the level's own
## parking helper, so the picture and the printed numbers are of the same aircraft the suite measures.
func _the_fighter_in_the_doorway() -> void:
	var yard: HangarYard = _level.get("hangar_yard") as HangarYard
	var door_z: float = SkyfrontHangar.depth_of(HangarYard.HANGAR_BAYS) * 0.5 - SkyfrontHangar.RIB_PROUD
	var craft: Node3D = HangarYard.park_a_fighter(Vector3(0.0, 0.0, door_z), PI)
	if craft == null:
		_failed.append("fighter-in-the-doorway")
		return
	yard.add_child(craft)
	craft.position.y -= HangarYard.lowest_drawn(craft)
	print("[hangar_shot] the door is %.1f x %.1f m; the F/A-18F is %.2f m in span and %.2f m high, so it clears %.2f m "
		% [SkyfrontHangar.OPENING_WIDE, SkyfrontHangar.OPENING_HIGH, FighterAirframe.SPAN, FighterAirframe.HEIGHT,
			(SkyfrontHangar.OPENING_WIDE - FighterAirframe.SPAN) * 0.5]
		+ "at each wingtip and %.2f m over the fin" % (SkyfrontHangar.OPENING_HIGH - FighterAirframe.HEIGHT))
	await _picture("fighter-in-the-doorway", Vector3(26.0, 6.0, 44.0), Vector3(0.0, 3.2, door_z), 44.0)
	await _elevation("fighter-in-the-doorway-front", Vector3(0.0, 4.5, door_z + 70.0), 16.0)
	yard.remove_child(craft)
	craft.queue_free()


## SAVE THE PICTURE, HAVING FIRST PROVED IT IS A PICTURE OF THE HANGAR.
##
## THE DATUM IS OUTSIDE THE CAMERA (`testing_godot_headless.md`, "Anchor the check outside the thing it is checking").
## `_camera.current = true` is the thing under test, so asking `_camera.is_current()` would be the tautology that let
## nine pictures of the Segway's desk through. The viewport is asked which camera it actually DREW with, and the
## building's own drawn corners are projected into the frame: a view that photographs the apron, the sky or somebody
## else's cockpit fails here rather than being saved and admired.
func _save(named: String) -> void:
	# THE SEAT TAKES THE VIEW BACK DURING THE SETTLE, not only at setup: the arriving Segway's rig is reparented under
	# `Vehicles/VehicleView/Seat0` a few frames in, and its `DesktopCamera` makes itself current then. Asserting once
	# before the settle left picture 1 -- and only picture 1, which is worse -- drawn from the seat. So the view is taken
	# and re-checked until the viewport agrees, rather than taken once and hoped over.
	if _filler == null:
		_filler = DirectionalLight3D.new()
		_filler.name = "ShotFill"
		_filler.shadow_enabled = false
		_filler.light_energy = FILL_ENERGY
		_level.add_child(_filler)
	_filler.visible = _fill_wanted
	if _fill_wanted:
		_filler.global_transform = _camera.global_transform
	var drew: Camera3D = null
	for _attempt in range(ATTEMPTS):
		_take_the_view()
		for _frame in range(SETTLE):
			await RenderingServer.frame_post_draw
		drew = get_viewport().get_camera_3d()
		if drew == _camera:
			break
	if drew != _camera:
		_failed.append("%s (drawn by %s, not the shot camera)" % [named, drew.get_path() if drew != null else "nothing"])
		print("[hangar_shot] FAILED %s: the viewport drew with %s" % [named, drew.get_path() if drew != null else "-"])
		return
	var covered: float = _share_of_the_frame_the_hangar_covers()
	if covered < LEAST_COVER:
		_failed.append("%s (the hangar covers %.1f%% of the frame)" % [named, covered * 100.0])
		print("[hangar_shot] FAILED %s: the hangar covers only %.1f%% of the frame" % [named, covered * 100.0])
		return
	_shot += 1
	var path: String = _out.path_join("cockpit-hangar-%02d-%s.png" % [_shot, named])
	var error: int = get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		_failed.append(named)
		print("[hangar_shot] FAILED %s (%s)" % [path, error_string(error)])
		return
	_saved.append(named)
	# WHERE THE BUILDING ACTUALLY LANDED, written beside the pictures, so the comparison sheet crops each render to the
	# building by MEASUREMENT rather than by a typed-in box per view that would go stale the first time a camera moved
	# (CLAUDE.md, rule 4: ask the authority, do not keep a roster).
	var rect: Rect2 = _hangar_on_screen()
	_frames[path.get_file()] = {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}
	print("[hangar_shot] saved %s (the hangar covers %.0f%% of the frame)" % [path, covered * 100.0])


## WHERE THE BUILDING LANDS ON THE SCREEN, in pixels -- from its own drawn corners rather than from a box round a box:
## the eight corners of a turned AABB grow with every rotation (`modelling_here.md`, section 7). The hangar's welded
## shell is axis-aligned in its own space and its owner is unrotated, so its corners are its corners, but they are
## projected one by one and the extent taken in screen space, which is what "on screen" actually means.
##
## An empty rect means the building is not in front of the camera at all. A camera INSIDE the shell gets the whole frame:
## the interior view is looking at the building whichever way it faces, and a projected extent there is meaningless.
func _hangar_on_screen() -> Rect2:
	var frame := Rect2(Vector2.ZERO, Vector2(get_viewport().get_visible_rect().size))
	var yard: HangarYard = _level.get("hangar_yard") as HangarYard
	if yard == null or yard.hangar == null or yard.hangar.shell == null:
		return Rect2()
	var shell: MeshInstance3D = yard.hangar.shell
	var box: AABB = shell.mesh.get_aabb()
	if box.has_point(shell.global_transform.affine_inverse() * _camera.global_position):
		return frame
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var ahead: int = 0
	for corner in range(8):
		var at: Vector3 = shell.global_transform * box.get_endpoint(corner)
		if _camera.is_position_behind(at):
			continue
		ahead += 1
		var on_screen: Vector2 = _camera.unproject_position(at)
		low = low.min(on_screen)
		high = high.max(on_screen)
	if ahead == 0:
		return Rect2()
	return Rect2(low, high - low)


## How much of the frame that rect covers, once clipped to the frame.
func _share_of_the_frame_the_hangar_covers() -> float:
	var frame := Rect2(Vector2.ZERO, Vector2(get_viewport().get_visible_rect().size))
	var shown: Rect2 = _hangar_on_screen().intersection(frame)
	return (shown.size.x * shown.size.y) / (frame.size.x * frame.size.y)
