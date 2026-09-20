extends Node
## ONE PICTURE OF EVERY DRAWN KIND OF CRAFT, so the fleet can be looked at during development.
##
##   Godot --xr-mode off --path cockpit --resolution 1600x900 res://tests/craft_gallery_shot.tscn -- --level=watch --finish=plain
##   cockpit\craft_gallery.bat --finish=plain         (Windows)     cockpit/craft_gallery.sh --finish=plain     (Linux)
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device. It brings up the level the game starts on (or
## `--world=<level id>`, chosen through `ChartDrawer.asked_in` and `Net.choose_level` exactly as boot does, because this
## builds the level itself and boot never reads the flag), lets the level seed its own fleet, and for each `Sim.Kind` takes
## the first craft of that kind it placed and photographs it from ahead and above, three-quarters
## on, at a distance that fits the drawn craft in the frame. The size is measured from the drawn meshes' vertices put into
## the craft's frame, not `transform * get_aabb()`, which grows a box every time it is turned. A kind the level does not
## place gets a deterministic local preview in the same level context. Only an explicitly undrawn kind (the segway) is
## skipped. THE LIVE CRAFT IS FOUND IN `Sim.current`, keyed by the ids the level draws, and never by
## a spawn's returned id, which is the server's (tests/hawkeye_shot.gd photographed a patrol boat eight times that way).
## `--level=watch` is what gives the level a camera and nobody in a seat. `--finish=plain|fine` (plain), `--time=day|evening|
## night` (day), `--out=<dir>` (the repo's `screenshots/<today>/`), `--only=<kind>[,<kind>...]` (every kind).
## Pictures: `cockpit-craft-<kind>.png`.

## Frames the seeded fleet is given to be up and drawn before anything is looked at.
const WARM: int = 240
## Frames a craft is held in frame before its picture, so the scenery and a ship's near model have come in round the eye.
const SETTLE: int = 60
## The camera's vertical field of view, degrees.
const FOV: float = 50.0
## How far above the craft's level the camera looks down from, degrees, and how far round from dead ahead, degrees.
## At 22 degrees a parked helicopter was its rotor disc and nothing under it. At 12, from 16 m off, the camera still stood
## 3.3 m over the box's middle and above the disc, which read as a table; so the rise is capped by `BELOW_THE_TOP` too.
const ELEVATION: float = 12.0
## The most the camera rises over the box's middle, as a share of the box's half-height: never over the craft's top.
const BELOW_THE_TOP: float = 0.9
const AROUND: float = 38.0
## How much of the window, across or up, the craft's box is fitted to.
const FILL: float = 0.7
## The nearest the camera stands, metres: a pod is a metre and a half across.
const CLOSEST: float = 6.0
## Vertices read from one surface when a drawn craft is measured; a larger surface is read at a stride.
const SAMPLES_PER_SURFACE: int = 6000

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = ""
var _fine: bool = false
## The craft being photographed, and where in its frame the camera looks at, and from how far.
var _view: VehicleView = null
var _centre_local: Vector3 = Vector3.ZERO
var _distance: float = 0.0
## Half the drawn box's height, metres, which caps how far over its middle the camera rises.
var _half_height: float = 0.0
var _only: String = ""


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		print("[craft_gallery] FAIL %s (%s)" % [label, detail])
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--finish="):
			var finish_asked: String = argument.trim_prefix("--finish=")
			_check("the_finish_is_plain_or_fine", finish_asked in ["plain", "fine"], finish_asked)
			_fine = finish_asked == "fine"
		elif argument.begins_with("--only="):
			_only = argument.trim_prefix("--only=").to_lower()
	if _out == "":
		# THE REPO'S OWN screenshots/<today>/, found from the project, which is `<repo>/cockpit`.
		var repo: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
		_out = repo.path_join("screenshots").path_join(Time.get_date_string_from_system())
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	# WHICH LEVEL, AS BOOT WOULD CHOOSE IT (tests/town_lights_shot.gd does the same, and says why).
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
	DirAccess.make_dir_recursive_absolute(_out)
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	# A GENERATED GROUND TAKES SECONDS TO STAND, and the fleet is seeded once it has.
	var waited: int = 0
	while Sim.current.is_empty() and waited < 6000:
		await _frames(1)
		waited += 1
	_check("the_level_seeded_a_fleet", not Sim.current.is_empty(), "after %d frames" % waited)
	await _frames(WARM)
	get_node("/root/Finish").call("choose", _fine)
	if Daylight.asked_on_the_command_line() < 0:
		_level.choose_time(DaylightTuning.When.DAY)
	# THE LEVEL'S WORDS OFF. `Ui` is a CanvasLayer, which is not a CanvasItem: cast to one it was null, and the first
	# pictures all carried the status line.
	var words: Node = _level.get_node_or_null("Ui")
	if words != null:
		words.set("visible", false)
	var board := _level.observer.get("_board") as CanvasItem
	if board != null:
		board.visible = false
	_level.observer.fov = FOV
	RenderingServer.frame_pre_draw.connect(_aim)
	print("[craft_gallery] level %s, %s finish, into %s" % [Net.level, "fine" if _fine else "plain", _out])

	var pictured: int = 0
	for kind in range(Sim.Kind.size()):
		if _only != "" and not (Sim.kind_name(kind) in _only.split(",")):
			continue
		var entity: int = _first_of(kind)
		var kind_name: String = Sim.kind_name(kind)
		if entity == 0:
			if not VehicleCatalogue.is_drawn(kind):
				print("[craft_gallery] SKIPPED %s: catalogue marks it undrawn" % kind_name)
				continue
			if await _photograph_preview(kind, kind_name):
				pictured += 1
			continue
		if await _photograph(entity, kind_name):
			pictured += 1
	_view = null
	print("[craft_gallery] %d kinds pictured" % pictured)
	_finish()


## THE FIRST CRAFT OF A KIND THE LEVEL PLACED: the lowest id of that kind in `Sim.current`, or 0.
func _first_of(kind: int) -> int:
	var first: int = 0
	for entity in Sim.current:
		if int((Sim.current[entity] as Dictionary).get("kind", -1)) == kind and (first == 0 or int(entity) < first):
			first = int(entity)
	return first


## A CATALOGUE KIND THE LEVEL DID NOT PLACE, built through the same VehicleView path in
## this level. It is visual evidence only and never enters simulation or replication.
func _photograph_preview(kind: int, kind_name: String) -> bool:
	var scene := load("res://objects/vehicles/vehicle_view.tscn") as PackedScene
	var view := scene.instantiate() as VehicleView if scene != null else null
	_check("%s_has_a_preview" % kind_name, view != null, "vehicle_view.tscn did not instantiate")
	if view == null:
		return false
	_level.add_child(view)
	view.preview_kind = kind
	view._show_in_editor()
	# A fixed patch of the test level keeps missing kinds in the same floor/scenery context
	# as the seeded fleet and far enough from live craft that neither model overlaps.
	view.global_position = Vector3(0.0, 80.0, 0.0)
	var saved := await _capture(view, 0, kind_name)
	if is_instance_valid(view):
		view.queue_free()
	await _frames(1)
	return saved


## GO TO ONE CRAFT, FIT IT IN THE FRAME AND SAVE IT: false, with the reason, when it could not be.
func _photograph(entity: int, kind_name: String) -> bool:
	# A VIEW FAR FROM THE EYE MAY NOT BE BUILT YET, so the camera goes to where the simulation has the craft first.
	var view: VehicleView = null
	for i in range(240):
		view = _level.view_of(entity)
		if view != null:
			break
		if Sim.current.has(entity):
			var at: Vector3 = (Sim.current[entity] as Dictionary).get("position", Vector3.ZERO)
			_level.observer.look_from(at + Vector3(0.0, 60.0, 120.0), at)
		await _frames(1)
	_check("%s_is_drawn" % kind_name, view != null, "entity %d has no view" % entity)
	if view == null:
		return false
	return await _capture(view, entity, kind_name)


func _capture(view: VehicleView, entity: int, kind_name: String) -> bool:
	_view = view
	_centre_local = Vector3.ZERO
	_distance = 60.0
	await _frames(SETTLE)
	if not is_instance_valid(view):
		_check("%s_stayed" % kind_name, false, "entity %d went away" % entity)
		return false
	var drawn: AABB = _drawn_bounds(view)
	var radius: float = drawn.size.length() * 0.5
	_centre_local = drawn.get_center()
	_half_height = drawn.size.y * 0.5
	_distance = maxf(radius / sin(deg_to_rad(FOV * 0.5)), CLOSEST)
	# AND FITTED BY WHAT THE BOX COVERS ON SCREEN. A sphere round a long hull is mostly sea: the carrier stood 416 m off and
	# filled a third of the picture. The box's eight corners are projected and the distance scaled until the wider of the
	# two spans is `FILL` of the window, twice, because a changed distance changes the perspective a little.
	for pass_number in range(2):
		await _frames(2)
		if not is_instance_valid(view):
			break
		var covers: float = _share_of_the_window(view, drawn)
		if covers > 0.0:
			_distance = maxf(_distance * covers / FILL, CLOSEST)
	await _frames(SETTLE)
	if not is_instance_valid(view):
		_check("%s_stayed" % kind_name, false, "entity %d went away" % entity)
		return false
	var path: String = _out.path_join("cockpit-craft-%s.png" % kind_name)
	var saved: bool = get_viewport().get_texture().get_image().save_png(path) == OK
	_check("%s_is_saved" % kind_name, saved, path)
	print("[craft_gallery] %s entity %d, radius %.1f m, distance %.1f m, %s" % [kind_name, entity, radius, _distance, path])
	return saved


## THE CAMERA, PUT WHERE THE CRAFT IS NOW, after every `_process` has moved the views and before the frame is drawn, so a
## fast aeroplane is not a frame behind its camera. In the craft's heading, not its whole basis: a banked aeroplane does
## not tip the camera over with it.
func _aim() -> void:
	if _view == null or not is_instance_valid(_view) or _level == null or _level.observer == null:
		return
	var pose: Transform3D = _view.global_transform
	var ahead: Vector3 = -pose.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	var right: Vector3 = ahead.cross(Vector3.UP)
	var round_from: Vector3 = ahead * cos(deg_to_rad(AROUND)) + right * sin(deg_to_rad(AROUND))
	# NEVER OVER THE CRAFT'S TOP: the rise is capped at `BELOW_THE_TOP` of the box's half-height, so a rotor disc on top
	# is seen edge-on and the body under it shows.
	var rise: float = minf(_distance * sin(deg_to_rad(ELEVATION)), _half_height * BELOW_THE_TOP)
	var centre: Vector3 = pose * _centre_local
	_level.observer.look_from(centre + round_from * _distance * cos(deg_to_rad(ELEVATION)) + Vector3.UP * rise, centre)


## HOW MUCH OF THE WINDOW THE CRAFT'S BOX COVERS from where the camera stands now: the larger of its share across and its
## share up, or 0 when a corner is behind the camera.
func _share_of_the_window(view: VehicleView, box: AABB) -> float:
	var camera: Camera3D = _level.observer
	var window: Vector2 = get_viewport().get_visible_rect().size
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for i in range(8):
		var corner: Vector3 = view.global_transform * box.get_endpoint(i)
		if camera.is_position_behind(corner):
			return 0.0
		var at: Vector2 = camera.unproject_position(corner)
		low = low.min(at)
		high = high.max(at)
	return maxf((high.x - low.x) / window.x, (high.y - low.y) / window.y)


## THE DRAWN CRAFT'S BOX IN ITS OWN FRAME, from the vertices of every visible mesh under it put through each mesh's
## transform into the craft's frame.
func _drawn_bounds(view: VehicleView) -> AABB:
	var into_craft: Transform3D = view.global_transform.affine_inverse()
	var box := AABB()
	var any: bool = false
	for node in view.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.mesh == null or not drawn.is_visible_in_tree():
			continue
		var into: Transform3D = into_craft * drawn.global_transform
		for surface in range(drawn.mesh.get_surface_count()):
			var vertices: PackedVector3Array = drawn.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var stride: int = maxi(1, vertices.size() / SAMPLES_PER_SURFACE)
			for i in range(0, vertices.size(), stride):
				var at: Vector3 = into * vertices[i]
				if any:
					box = box.expand(at)
				else:
					box = AABB(at, Vector3.ZERO)
					any = true
	if not any:
		var half: Vector3 = Sim.geometry_of(view.kind).get("extents", Vector3.ONE)
		box = AABB(-half, half * 2.0)
	return box


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	_view = null
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
