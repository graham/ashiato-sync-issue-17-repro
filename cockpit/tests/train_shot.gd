extends Node
## THE TRAIN, PHOTOGRAPHED ON ITS OWN RAILWAY, because a suite cannot see whether a rake reads
## as a train.
##
##   Godot --xr-mode off --desktop-only --path cockpit res://tests/train_shot.tscn -- --level=watch
##   tools\gate_run.ps1 -Probe train_shot -Extra "--level=watch"
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device. `tests/train_models.gd`
## holds every dimension of the boxcar and the rake's length; whether eight to ten cars behind a
## locomotive READ as a freight train has no assertion and is what these pictures are for.
##
## THE FOUR IT TAKES:
##   1. the whole rake from the air, three-quarters on, fitted to its own drawn length;
##   2. **the same rake broadside and ORTHOGRAPHIC, at a stated pixel scale in the filename**,
##      which is the picture a reader can lay over the reference photograph and dispute. "It
##      looks right" cannot be argued with; a scale can;
##   3. one car close, three-quarters on, where the door, the roof's peak and the trucks are;
##   4. one car broadside and orthographic at the same stated scale.
##
## WHAT IT CHECKS ANYWAY. Not that `save_png` returned OK -- `lane/hangar` saved nine pictures of
## the wrong thing under `RESULT=PASS` that way. It projects the rake's own drawn corners and
## requires them to cover a share of the frame, and it asks the VIEWPORT which camera it drew
## with rather than asking the camera whether it thinks it is current, which is the tautology.
##
## Read RESULT=, not the exit code.

## Frames the level is given to seed its fleet and lay its railway before anything is looked at.
const WARM: int = 240
## Frames a subject is held in frame before its picture.
const SETTLE: int = 45
const FOV: float = 45.0
## How far round from broadside the three-quarter views stand, degrees, and how far above.
const AROUND: float = 34.0
const ELEVATION: float = 18.0
## How much of the window across the subject is fitted to.
const FILL: float = 0.80
## The least of the frame the subject's own projected corners must cover, or the picture is of
## something else. A long thin rake seen broadside fills a band, not a box, so this is low.
const COVERS_AT_LEAST: float = 0.10

var _failures: PackedStringArray = []
var _out: String = ""
var _level: FlightLevel = null
## Where the camera is put on the next `frame_pre_draw`, and what it looks at.
## WHAT THE CAMERA IS LOOKING AT, and where it stands relative to it, worked out afresh on
## EVERY FRAME from where the subject IS. A train runs at 22 m/s: over the settle frames it
## moves sixteen metres, so a camera placed once from a box measured beforehand photographs the
## piece of railway the train has just left, and the first four pictures this probe took were
## of exactly that. The offset is in the SUBJECT's frame, level, because a loop means its
## heading is different every frame.
var _subject: Array = []
var _offset: Vector3 = Vector3.ZERO
var _aiming: bool = false
## The shadowless fill for an orthographic elevation. See `_light_the_elevation`.
var _fill: DirectionalLight3D = null
## A CAMERA STOOD AT A PLACE ON THE GROUND beside the locomotive rather than fitted round a box:
## `_stand` and `_look` are metres in the locomotive's own level frame (x to its right, y up from
## the RAILHEAD under its middle, z ahead of it), re-read every frame because it is moving.
var _standing: bool = false
var _stand: Vector3 = Vector3.ZERO
var _look: Vector3 = Vector3.ZERO
## `--clip=<seconds>`: instead of stills, stand beside the line ahead of the train and watch it go
## by, for a MovieWriter run (`--write-movie`, `--fixed-fps`). See `_clip`.
var _clip_seconds: float = 0.0
## `--jitter=<frames>`: measure how evenly the rake is drawn, against a REAL render clock. See `_measure_the_jitter`.
var _jitter_frames: int = 0
## The locomotive to its first car, one reading a drawn frame. See `_measure_the_jitter`.
var _gaps: Array[float] = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[train_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		if argument.begins_with("--clip="):
			_clip_seconds = argument.trim_prefix("--clip=").to_float()
		if argument.begins_with("--jitter="):
			_jitter_frames = argument.trim_prefix("--jitter=").to_int()
	if _out == "":
		var repo: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
		_out = repo.path_join("screenshots").path_join(Time.get_date_string_from_system())
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
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
	var waited: int = 0
	while Sim.current.is_empty() and waited < 6000:
		await _frames(1)
		waited += 1
	await _frames(WARM)
	if Daylight.asked_on_the_command_line() < 0:
		_level.choose_time(DaylightTuning.When.DAY)
	# `Ui` IS A CanvasLayer, NOT A CanvasItem, so a cast to one is null and the status line ends
	# up in every picture. `set` works on both.
	var words: Node = _level.get_node_or_null("Ui")
	if words != null:
		words.set("visible", false)
	var board := _level.observer.get("_board") as CanvasItem
	if board != null:
		board.visible = false
	RenderingServer.frame_pre_draw.connect(_aim)

	# The level builds a rake the first time it DRAWS one, which is a frame after the spawn.
	await _frames(8)
	var carriages: Dictionary = _level.get("_carriages")
	print("[train_shot] level %s, %d rake(s) drawn; the railway is %.0f m round"
		% [Net.level, carriages.size(),
			Sim.client.rail_length(0) if Sim.client != null else -1.0])
	_check("the_level_hung_a_rake_behind_a_locomotive", not carriages.is_empty(),
		"%d train(s) with carriages" % carriages.size())
	if carriages.is_empty():
		_finish()
		return
	var engine: int = int(carriages.keys()[0])
	var cars: Array = carriages[engine]
	_check("and_it_is_eight_to_ten_cars_long",
		cars.size() >= Terrain.TRAIN_CARS_LEAST and cars.size() <= Terrain.TRAIN_CARS_MOST,
		"%d cars behind locomotive %d" % [cars.size(), engine])
	var loco: VehicleView = _level.view_of(engine)
	print("[train_shot] locomotive %d, %d cars, into %s" % [engine, cars.size(), _out])
	# WHERE THE PLUME IN THESE PICTURES COMES FROM, said beside them, because it is not the
	# train's. Nothing in `objects/vehicles/` emits a particle -- there is no exhaust, no funnel
	# and no smokestack on any vehicle in this game -- and the column of smoke that appears over
	# the locomotive from the gallery's camera angle is one of the ISLAND'S FIRES, kilometres
	# behind it. A reader of the picture cannot tell those apart, so the number is printed.
	if loco != null:
		var nearest: float = INF
		for fire in Sim.fires:
			nearest = minf(nearest, loco.global_position.distance_to(fire["position"]))
		print("[train_shot] the nearest of %d island fires is %.0f m from the locomotive; "
			% [Sim.fires.size(), nearest]
			+ "no vehicle in this game emits smoke, so any plume in these pictures is one of those")

	var rake: Array[Node3D] = []
	if loco != null:
		rake.append(loco)
	for car in cars:
		rake.append(car as Node3D)

	if _jitter_frames > 0:
		await _measure_the_jitter(rake)
		_finish()
		return
	if _clip_seconds > 0.0:
		await _clip(rake)
		_finish()
		return
	await _shoot(rake, "02-a-rake-of-boxcars-on-the-island-railway", AROUND, ELEVATION, false)
	await _shoot(rake, "03-the-rake-broadside", 90.0, 2.0, true)
	await _shoot([rake[rake.size() / 2]], "04-one-boxcar-three-quarters-on", AROUND, ELEVATION, false)
	await _shoot([rake[rake.size() / 2]], "05-one-boxcar-broadside", 90.0, 0.0, true)
	# THE THREE A BEFORE-AND-AFTER IS JUDGED BY (lane/trains, 2026-09-19): where a person stands
	# beside the line, where an aeroplane sees it from, and where the wheel meets the rail. Each
	# camera stands at a fixed place in the LOCOMOTIVE's frame, measured up from the railhead
	# rather than from the box's middle, so a taller or longer locomotive is photographed from the
	# same spot on the ground and the pair can be laid side by side.
	await _shoot_from(rake[0], "06-trackside", Vector3(4.5, 1.7, 32.0), Vector3(0.0, 2.2, -8.0), 50.0)
	await _shoot_from(rake[0], "07-from-the-air", Vector3(30.0, 42.0, 34.0), Vector3(0.0, 0.0, -18.0), 50.0)
	await _shoot_from(rake[0], "08-wheels-on-the-rail", Vector3(4.2, 0.8, 9.0), Vector3(0.0, 0.5, 4.5), 60.0)
	_finish()


## ONE PICTURE of whatever nodes are handed in, fitted to their own drawn corners.
##
## `ortho` swaps the camera to an orthographic projection, which is what makes a picture
## comparable with a drawing: the scale is then one number for the whole frame, it is computed
## from the viewport's own height, and it goes in the FILENAME so a reader can lay the picture
## over a reference at a known ratio.
func _shoot(nodes: Array, what: String, around: float, elevation: float, ortho: bool) -> void:
	var camera: Camera3D = _level.observer
	var box: AABB = _box_of(nodes)
	if box.size == Vector3.ZERO:
		_check("%s_has_something_to_photograph" % what, false, "no drawn vertices")
		return
	var radius: float = box.size.length() * 0.5

	# WHERE THE CAMERA STANDS, IN THE SUBJECT'S OWN FRAME: x to its right, y up, z ahead of it.
	# Kept in its frame rather than the world's because the train is going round a loop while
	# this runs, so "broadside" is a different world direction on every frame.
	var round_from := Vector3(sin(deg_to_rad(around)), 0.0, -cos(deg_to_rad(around)))

	var scale_note: String = ""
	if ortho:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		# Fit the box's longest horizontal span across the frame, and say what a pixel is worth.
		var across: float = maxf(box.size.x, box.size.z) / FILL
		var viewport: Vector2 = Vector2(get_viewport().size)
		camera.size = across * (viewport.y / maxf(viewport.x, 1.0))
		var per_metre: float = viewport.y / maxf(camera.size, 0.001)
		scale_note = "-at-%.1f-px-a-metre" % per_metre
		_offset = round_from * (radius * 3.0 + 60.0)
		_offset.y = radius * 0.05
		# THE SUN LIGHTS ONE FACE AND A DRAWING LIGHTS ALL OF THEM. An elevation meant to be
		# laid beside a reference gets a shadowless fill along the camera's own line of sight;
		# without it the whole side away from the sun is a black slab and the door, the ribs
		# and the trucks -- everything the picture exists to show -- cannot be read at all.
		# The hero and three-quarter views keep the world's light, because those are meant to
		# look like the place rather than like a drawing of it.
		_light_the_elevation()
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = FOV
		var away: float = maxf(radius / sin(deg_to_rad(FOV * 0.5)), 12.0)
		_offset = round_from * away * cos(deg_to_rad(elevation))
		_offset.y = away * sin(deg_to_rad(elevation))
	_subject = nodes
	_aiming = true
	await _frames(SETTLE)
	# RE-MEASURED WHERE IT IS NOW. A train runs at 22 m/s, so over the settle frames it moves
	# sixteen metres, and corners taken before them belong to a piece of railway it has left.
	var corners: PackedVector3Array = _drawn_corners(nodes)

	# ASK THE VIEWPORT WHICH CAMERA IT DREW WITH. `camera.is_current()` asks the thing under
	# test; a seat that reparents a rig takes the view back during the settle frames and only
	# the first picture comes out wrong, which is worse than all of them being wrong.
	var drew: Camera3D = get_viewport().get_camera_3d()
	_check("%s_was_drawn_with_the_observer" % what, drew == camera,
		"%s" % [drew.name if drew != null else "no camera"])

	var covers: float = _share_of_the_frame(camera, corners)
	_check("%s_has_its_subject_in_the_frame" % what, covers >= COVERS_AT_LEAST,
		"its own corners cover %.3f of the frame, wanted %.2f" % [covers, COVERS_AT_LEAST])

	var path: String = _out.path_join("cockpit-train-%s%s.png" % [what, scale_note])
	var saved: bool = get_viewport().get_texture().get_image().save_png(path) == OK
	_check("%s_is_saved" % what, saved, path)
	print("[train_shot] %s: %d node(s), box %.1f x %.1f x %.1f m, covers %.3f of the frame, %s"
		% [what, nodes.size(), box.size.x, box.size.y, box.size.z, covers, path])
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	if _fill != null:
		_fill.visible = false
	_aiming = false
	_subject = []


## THE LOCOMOTIVE'S LEVEL FRAME ON THE GROUND: the railhead under the middle of its drawn box (the
## box's bottom is its wheels' bottom, which is the railhead), and its heading with the lean taken
## out, so a banked corner does not tip a camera stood on the ground.
func _ground_frame(lead: Node3D) -> Dictionary:
	var box: AABB = _box_of([lead])
	var middle: Vector3 = box.get_center()
	var ahead: Vector3 = -lead.global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	return {"base": Vector3(middle.x, box.position.y, middle.z), "ahead": ahead,
		"right": ahead.cross(Vector3.UP).normalized()}


## ONE PICTURE FROM A PLACE ON THE GROUND beside `lead`, looking at another: see `_stand`. No
## coverage check, because a camera standing beside a long thing has part of it behind the lens by
## design; what it asks instead is that the place it looks at is in front of the lens and in frame.
func _shoot_from(lead: Node3D, what: String, stand: Vector3, look: Vector3, fov: float) -> void:
	var camera: Camera3D = _level.observer
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = fov
	_subject = [lead]
	_stand = stand
	_look = look
	_standing = true
	_aiming = true
	await _frames(SETTLE)
	var drew: Camera3D = get_viewport().get_camera_3d()
	_check("%s_was_drawn_with_the_observer" % what, drew == camera,
		"%s" % [drew.name if drew != null else "no camera"])
	var frame: Dictionary = _ground_frame(lead)
	var target: Vector3 = (frame["base"] as Vector3) + (frame["right"] as Vector3) * look.x \
		+ Vector3.UP * look.y + (frame["ahead"] as Vector3) * look.z
	var window: Vector2 = Vector2(get_viewport().size)
	var seen: Vector2 = camera.unproject_position(target)
	var in_frame: bool = not camera.is_position_behind(target) and seen.x >= 0.0 \
		and seen.y >= 0.0 and seen.x <= window.x and seen.y <= window.y
	_check("%s_looks_at_the_locomotive" % what, in_frame, "at %s in a %s window" % [seen, window])
	var path: String = _out.path_join("cockpit-train-%s.png" % what)
	var saved: bool = get_viewport().get_texture().get_image().save_png(path) == OK
	_check("%s_is_saved" % what, saved, path)
	print("[train_shot] %s: stood at %s looking at %s in the locomotive's frame, %s"
		% [what, stand, look, path])
	_standing = false
	_aiming = false
	_subject = []


## HOW EVENLY THE RAKE IS DRAWN, measured against a REAL render clock -- which is the whole reason
## this lives in a windowed probe and not in a suite. Headless steps physics and drawing together,
## so a rake placed from the tick's own numbers reports perfect smoothness there; it is only when
## the display runs at its own rate that a car standing still through a tick and jumping at its end
## can be seen at all. `tests/track_drawn.gd` walks the interpolation by hand instead.
##
## For the locomotive and for the last car, each frame's step along the ground. A smooth rake's
## steps vary only with the frame times; a rake drawn from the tick's distance steps zero, zero,
## zero and then a whole tick's worth, so its LARGEST step over its smallest runs away.
func _measure_the_jitter(rake: Array[Node3D]) -> void:
	var watched: Array[Node3D] = [rake[0], rake[rake.size() - 1]]
	var names: Array[String] = ["the locomotive", "the last car"]
	# A CONTROL, drawn the way every other vehicle is: an aeroplane in the air. A number for the train's smoothness on
	# its own says nothing -- some of what any of them does is the frame clock, not the drawing -- and the question
	# worth answering is whether the train is as smooth as everything else in the game.
	for entity in Sim.current:
		if int((Sim.current[entity] as Dictionary).get("kind", -1)) != Sim.Kind.TRAIN:
			var other: VehicleView = _level.view_of(int(entity))
			if other != null and (Sim.current[entity] as Dictionary).get("position", Vector3.ZERO).y > 200.0:
				watched.append(other)
				names.append("an aeroplane in the air (the control)")
				break
	var was: Array[Vector3] = []
	var steps: Array = []
	for i in range(watched.size()):
		steps.append([] as Array[float])
	for node in watched:
		was.append(node.global_position)
	var frames: int = 0
	_gaps = []
	while frames < _jitter_frames:
		await _frames(1)
		frames += 1
		_gaps.append(rake[0].global_position.distance_to(rake[1].global_position))
		for i in range(watched.size()):
			var at: Vector3 = watched[i].global_position
			(steps[i] as Array[float]).append(was[i].distance_to(at))
			was[i] = at
	# THE COUPLING ITSELF, which is the measurement that means anything. A frame's step depends on
	# how long the frame was, so at 60 frames to 120 ticks every frame is exactly two ticks and a
	# rake drawn from the tick's own distance steps as evenly as anything else. What cannot hide is
	# the DISTANCE BETWEEN THE LOCOMOTIVE AND ITS FIRST CAR: the locomotive is drawn between two
	# simulated poses and the car was not, so the coupling stretches and closes within every tick,
	# and no frame rate makes that go away.
	var gaps: Array[float] = _gaps
	var least: float = INF
	var most: float = -INF
	for gap in gaps:
		least = minf(least, gap)
		most = maxf(most, gap)
	# AND HOW FAST IT CHANGES, which is what says whether what is left is judder or geometry. A coupling that jumps from
	# one frame to the next is the rake being drawn in steps; one that creeps is the two bodies' bogie chords cutting
	# corners by different amounts as the curvature changes under them, and nobody can see that.
	var worst_frame: float = 0.0
	var jumpy: int = 0
	for i in range(1, gaps.size()):
		var moved: float = absf(gaps[i] - gaps[i - 1])
		worst_frame = maxf(worst_frame, moved)
		if moved > 0.002:
			jumpy += 1
	print("[train_shot] jitter, the coupling between the locomotive and its first car over %d frames: "
		% gaps.size() + "%.4f to %.4f m, opening and closing by %.0f mm, worst %.1f mm in one frame"
		% [least, most, (most - least) * 1000.0, worst_frame * 1000.0]
		+ ", %d frames of %d moved it more than 2 mm" % [jumpy, gaps.size() - 1])
	for i in range(watched.size()):
		var all: Array[float] = steps[i]
		var total: float = 0.0
		var smallest: float = INF
		var largest: float = -INF
		var still: int = 0
		for step in all:
			total += step
			smallest = minf(smallest, step)
			largest = maxf(largest, step)
			if step < 0.001:
				still += 1
		var mean: float = total / maxf(float(all.size()), 1.0)
		var wobble: float = 0.0
		for step in all:
			wobble += absf(step - mean)
		print("[train_shot] jitter, %s over %d frames at %.0f fps: mean step %.4f m, %.4f to %.4f, "
			% [names[i], all.size(), Engine.get_frames_per_second(), mean, smallest, largest]
			+ "mean departure %.4f m (%.1f%% of a step), %d frames drawn where it did not move at all"
			% [wobble / maxf(float(all.size()), 1.0), 100.0 * wobble / maxf(total, 1e-9), still])
	_check("the_rake_was_watched_moving", true, "%d frames" % frames)


## A CLIP OF THE TRAIN GOING BY, for `--write-movie` at a fixed rate. The camera stands still on
## the ground 1.7 m up and `CLIP_SIDE` off the line, `CLIP_AHEAD` down the track from the
## locomotive -- a place picked off the RAILWAY, not off the train, so it stays put -- and turns
## to follow the locomotive's middle as the rake comes towards it and passes. It prints the frame
## it starts on so the loading can be cut off the front of the movie.
const CLIP_AHEAD: float = 120.0
const CLIP_SIDE: float = 9.0
## The rate the movie is written at, which the run must pass as `--fixed-fps` too.
const CLIP_FPS: float = 30.0
func _clip(rake: Array[Node3D]) -> void:
	var engine: int = int((_level.get("_carriages") as Dictionary).keys()[0])
	var state: Dictionary = Sim.client.rail_state(engine)
	var pose: Dictionary = Sim.client.rail_pose(int(state.get("track", 0)),
		float(state.get("distance", 0.0)) + CLIP_AHEAD, 0.0, 0.0)
	var along: Vector3 = pose["forward"]
	along.y = 0.0
	var side: Vector3 = along.normalized().cross(Vector3.UP).normalized()
	var stand: Vector3 = (pose["position"] as Vector3) + side * CLIP_SIDE + Vector3.UP * 1.7
	var camera: Camera3D = _level.observer
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 50.0
	var frames: int = int(_clip_seconds * CLIP_FPS)
	print("[train_shot] clip starts at frame %d: %d frames at %d fps, standing %.0f m ahead of the locomotive"
		% [Engine.get_frames_drawn(), frames, int(CLIP_FPS), CLIP_AHEAD])
	var following: Callable = func() -> void:
		var lead := rake[0]
		if is_instance_valid(lead):
			_level.observer.look_from(stand, _box_of([lead]).get_center())
	RenderingServer.frame_pre_draw.connect(following)
	await _frames(frames)
	RenderingServer.frame_pre_draw.disconnect(following)
	print("[train_shot] clip ends at frame %d" % Engine.get_frames_drawn())


## EVERY DRAWN VERTEX of the nodes handed in, in world space, at a stride. Not `get_aabb`, which
## grows a box every time it is turned.
func _drawn_corners(nodes: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for node in nodes:
		for found in (node as Node3D).find_children("*", "MeshInstance3D", true, false):
			var drawn := found as MeshInstance3D
			if drawn.mesh == null or not drawn.visible or drawn.visibility_range_begin > 0.0:
				continue
			_gather(out, drawn)
		if node is MeshInstance3D:
			_gather(out, node as MeshInstance3D)
	return out


func _gather(into: PackedVector3Array, drawn: MeshInstance3D) -> void:
	for s in range(drawn.mesh.get_surface_count()):
		var points: PackedVector3Array = drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		var stride: int = maxi(1, points.size() / 400)
		for i in range(0, points.size(), stride):
			into.append(drawn.global_transform * points[i])


## HOW MUCH OF THE FRAME the subject's own projected corners cover, across or up, or 0 when one
## of them is behind the lens.
func _share_of_the_frame(camera: Camera3D, corners: PackedVector3Array) -> float:
	var window: Vector2 = Vector2(get_viewport().size)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point in corners:
		if camera.projection == Camera3D.PROJECTION_PERSPECTIVE and camera.is_position_behind(point):
			return 0.0
		var on_screen: Vector2 = camera.unproject_position(point)
		low = low.min(on_screen)
		high = high.max(on_screen)
	var span: Vector2 = high - low
	return maxf(span.x / window.x, span.y / window.y)


## AIMED ON `frame_pre_draw`, after every `_process` has moved the views: a train at 22 m/s is a
## frame ahead of a camera placed in `_process`.
func _aim() -> void:
	if not _aiming or _level == null or _level.observer == null or _subject.is_empty():
		return
	var lead := _subject[0] as Node3D
	if not is_instance_valid(lead):
		return
	if _standing:
		var frame: Dictionary = _ground_frame(lead)
		var base: Vector3 = frame["base"]
		var side: Vector3 = frame["right"]
		var nose: Vector3 = frame["ahead"]
		var from: Vector3 = base + side * _stand.x + Vector3.UP * _stand.y + nose * _stand.z
		var to: Vector3 = base + side * _look.x + Vector3.UP * _look.y + nose * _look.z
		_level.observer.look_from(from, to)
		return
	var middle: Vector3 = _box_of(_subject).get_center()
	# YAW ONLY, taken from the leading vehicle's nose: a train leaning into a banked corner must
	# not tip the camera over with it.
	var ahead: Vector3 = -lead.global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	var right: Vector3 = ahead.cross(Vector3.UP).normalized()
	var where: Vector3 = middle + right * _offset.x + Vector3.UP * _offset.y - ahead * _offset.z
	_level.observer.look_from(where, middle)
	if _fill != null and _fill.visible:
		_fill.global_transform = Transform3D(Basis.looking_at(middle - where, Vector3.UP), where)


## THE DRAWN BOX of whatever is handed in, as it is right now.
func _box_of(nodes: Array) -> AABB:
	var corners: PackedVector3Array = _drawn_corners(nodes)
	if corners.is_empty():
		return AABB()
	var box := AABB(corners[0], Vector3.ZERO)
	for point in corners:
		box = box.expand(point)
	return box


## A SHADOWLESS FILL ALONG THE CAMERA'S LINE OF SIGHT, for an elevation and nothing else. Aimed
## in `_aim`, with the camera, because the camera moves with the train.
func _light_the_elevation() -> void:
	if _fill == null:
		_fill = DirectionalLight3D.new()
		_fill.name = "ElevationFill"
		_fill.shadow_enabled = false
		# GENTLE. At 1.2 on top of the sun the fill blew a 0.43 boxcar red out to a washed pink
		# and the picture stopped being comparable with the photograph it exists to be laid
		# beside. It is here to lift the shadowed side to readable, not to relight the world.
		_fill.light_energy = 0.55
		_fill.light_color = Color(1.0, 0.99, 0.96)
		add_child(_fill)
	_fill.visible = true


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	print("RESULT=%s" % ["PASS" if _failures.is_empty() else "FAIL"])
	if not _failures.is_empty():
		print("[train_shot] failed: %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
