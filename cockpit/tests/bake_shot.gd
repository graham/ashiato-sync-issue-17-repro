extends Node3D
## WHAT A CASTING SAVES, AND WHETHER IT STILL MOVES: one craft drawn twice in a bare room -- once as its parts, once poured
## into a `Casting` -- counted by the renderer's own draw counters and photographed from the same camera. RESEARCH PROBE
## for `research/static_bake.md`. NOT headless: headless draws nothing and every counter reads 0.
##
##   Godot --xr-mode off --desktop-only --path cockpit res://tests/bake_shot.tscn -- --kind=cessna --out=<dir> [--shadows]
##
## THE TWO VIEWS ARE BUILT THE SAME WAY, `setup(0, kind)` as `named_parts` builds them, and stand at the same spot; only one
## is shown at a time. The cast one is poured straight after it is built, at its neutral pose, as a game would pour it.
##
## THE MOVING SURFACES ARE DRIVEN THROUGH THE REAL PATH: a server and a client `CockpitWorld` over a loopback, a pilot in
## a Cessna working the stick, rudder, throttle and flap lever (`tests/skyhawk.gd`'s own loop), and each tick BOTH views
## handed the client's bus and linkage through `VehicleView.draw_the_skyhawk_from`, exactly as `draw` does. Nothing here
## sets a transform. The cast view is then judged against the parts view it was cast from, pixel for pixel, posed.
##
## WHAT IS COUNTED, AND WHY SHOWN MINUS HIDDEN: the frame's draw calls include the floor and the sky, so each view's cost is
## its frame with it shown less the frame with both hidden, averaged over FRAMES frames, split into the camera's pass and
## the shadow pass (`VIEWPORT_RENDER_INFO_TYPE_VISIBLE` / `_SHADOW`).

const FRAMES := 60
const DT := 1.0 / 120.0
## A pixel differs if any channel is further apart than this, 0..1.
const PIXEL_DIFFERS := 0.10

var out := ""
var kind: int = Sim.Kind.CESSNA
var kind_name := "cessna"
var shadows := false
var camera: Camera3D
var sun: DirectionalLight3D
var parts_view: Node3D
var cast_view: Node3D
## THE HANGAR ONLY: the same pieces drawn the way the game draws them, one MultiMesh of coloured unit boxes.
var batch_view: Node3D = null
var casting: Casting
var failures: PackedStringArray = []
var stamp := ""
## `--far=<metres>`: stand everything that far out along x and z, to ask whether the double build draws a casting
## differently from its parts away from the origin.
var far: float = 0.0
## `--many=<n>`: n Cessnas as parts and n cast, in a grid, and time the frame with each set shown in turn.
var many: int = 0
## `--no-pose`: with `--many`, never pose the castings after the pour: what the engine's skinning costs on its own.
var no_pose: bool = false
## `--preview`: build each view as `fighter_inspector_shot` does -- `preview_kind`, `_show_in_editor()`, `_show_body(false)` --
## which fits the cabin: the build behind the first "+76 draw calls" for the Cessna.
var preview: bool = false
## `--cabin-unshadowed`: on the CAST view only, also switch shadow casting off on every mesh inside a control, station
## or shell -- the one-line alternative to a bake, measured beside it.
var cabin_unshadowed: bool = false
## `--unshadow-only`: the cast view is NOT poured, only unshadowed: the one-line setting measured on its own.
var unshadow_only: bool = false


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--kind="): kind_name = argument.trim_prefix("--kind=").to_lower()
		elif argument == "--shadows": shadows = true
		elif argument.begins_with("--far="): far = float(argument.trim_prefix("--far="))
		elif argument.begins_with("--many="): many = int(argument.trim_prefix("--many="))
		elif argument == "--no-pose": no_pose = true
		elif argument == "--preview": preview = true
		elif argument == "--cabin-unshadowed": cabin_unshadowed = true
		elif argument == "--unshadow-only": unshadow_only = true; cabin_unshadowed = true
	for candidate in range(Sim.Kind.size()):
		if Sim.kind_name(candidate) == kind_name: kind = candidate
	if out.is_empty(): out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	stamp = _stamp()
	_room()
	var geometry_before: Dictionary = Sim.geometry_of(kind).duplicate(true)
	if many > 0:
		await _many()
		print("[bake_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL %s" % ", ".join(failures), out])
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	if kind_name == "hangar":
		await _hangar()
		print("[bake_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL %s" % ", ".join(failures), out])
		get_tree().quit(0 if failures.is_empty() else 1)
		return

	parts_view = _view("PartsView")
	var pattern_triangles: int = _visible_triangles(parts_view, false)
	var pattern_meshes: int = _visible_meshes(parts_view, false)
	cast_view = _view("CastView")
	var started: int = Time.get_ticks_usec()
	if unshadow_only:
		casting = Casting.new()
		add_child(casting)
	else:
		casting = Casting.pour(_pour_root(cast_view))
	if cabin_unshadowed:
		var unshadowed: int = 0
		for found in cast_view.find_children("*", "GeometryInstance3D", true, false):
			if Casting._owned(found):
				(found as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				unshadowed += 1
		print("[bake_shot] shadow casting switched off on %d cabin meshes of the second view%s" % [unshadowed,
			" (NOT poured)" if unshadow_only else ""])
	var pour_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	print("[bake_shot] %s: %d visible meshes, %d triangles as parts; poured %d parts into %d instances, %d surfaces, %d triangles, %d bones, in %.1f ms"
		% [kind_name, pattern_meshes, pattern_triangles, casting.parts.size(), casting.instances.size(), casting.surfaces(),
			casting.triangles(), casting.parts.size(), pour_ms])
	_inventory(parts_view, "parts")
	_inventory(cast_view, "cast")
	_check("the_casting_draws_every_triangle_the_parts_drew_and_no_more",
		casting.triangles() == _poured_triangles(),
		"%d triangles poured from %d visible parts, %d in the casting" % [_poured_triangles(), casting.parts.size(), casting.triangles()])
	_check("pouring_changed_nothing_the_simulation_owns", geometry_before == Sim.geometry_of(kind),
		"Sim.geometry_of(%s) compared before and after" % kind_name)

	camera = Camera3D.new(); camera.fov = 40.0; camera.current = true; add_child(camera)
	var views: Array = _cameras()
	# NEUTRAL, straight after the build.
	var neutral: Array = []
	for index in range(views.size()):
		neutral.append(await _pair("neutral-%d" % index, views[index]))
	await _count()

	# THE PREVIEW AND THE UNSHADOW-ONLY RUNS ARE FOR COUNTING: the preview's cabin carries its own parts named like the
	# airframe's (the first preview run could not find a `Rudder` twin), and an unpoured view has no casting to fly.
	if kind == Sim.Kind.CESSNA and not preview and not unshadow_only:
		var flown: Dictionary = await _fly()
		for index in range(views.size()):
			await _pair("flown-%d" % index, views[index])
		_check("the_cast_surfaces_moved_with_the_parts_through_the_bus_and_the_stick", bool(flown["moved"]),
			flown["detail"])
		await _drift_check()
	print("[bake_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL %s" % ", ".join(failures), out])
	get_tree().quit(0 if failures.is_empty() else 1)


## THE CESSNA'S VISUAL SCENE if it has one -- the airframe a package installs -- else the whole view: what gets poured.
func _pour_root(view: VehicleView) -> Node3D:
	return view


func _view(called: String) -> VehicleView:
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	view.name = called
	if preview:
		view = (load("res://objects/vehicles/craft_%s.tscn" % kind_name) as PackedScene).instantiate() as VehicleView
		view.name = called
		add_child(view)
		view.preview_kind = kind
		view._show_in_editor()
		view._show_body(false)
	else:
		add_child(view)
		view.setup(0, kind)
	view.position = Vector3(far, 0.0, far)
	return view


func _room() -> void:
	var environment := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.24, 0.28, 0.33)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_energy = 1.1
	env.ambient_light_color = Color(0.55, 0.57, 0.60)
	environment.environment = env; add_child(environment)
	sun = DirectionalLight3D.new(); sun.rotation = Vector3(-0.8, -0.55, 0.0); sun.light_energy = 1.4
	sun.shadow_enabled = shadows
	add_child(sun)
	var rest: float = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y)
	var floor := MeshInstance3D.new(); var slab := BoxMesh.new(); slab.size = Vector3(80, 0.15, 80)
	floor.mesh = slab; floor.position = Vector3(far, -rest - 0.075, far); floor.name = "Floor"; add_child(floor)
	var label := Label.new(); label.text = "%s  %s  %s%s" % [stamp, kind_name, "shadows" if shadows else "no shadows",
		"  %.0f m out" % far if far != 0.0 else ""]
	label.position = Vector2(12, 8); label.add_theme_font_size_override("font_size", 18)
	var layer := CanvasLayer.new(); layer.add_child(label); add_child(layer)


## Two cameras fitted to the drawn craft: a three-quarter from behind and above (flaps, elevators, rudder) and one from
## ahead and to port.
func _cameras() -> Array:
	var box: AABB = _drawn_box(parts_view)
	# THE BOX IS IN THE VIEW'S FRAME and the camera is placed in the world's: the Cessna stands at the origin, so the two
	# agreed until the hangar, 1 km out, photographed an empty room.
	var centre: Vector3 = parts_view.global_transform * box.get_center()
	var reach: float = box.size.length() * 0.62
	return [[centre + Vector3(0.55, 0.45, 0.70).normalized() * reach * 1.9, centre],
		[centre + Vector3(-0.70, 0.30, -0.65).normalized() * reach * 1.9, centre]]


## ONE PICTURE OF EACH VIEW FROM THE SAME CAMERA, and one of the empty room, and how many of the craft's pixels differ.
##
## THE CRAFT'S PIXELS ARE THE ONES WHERE THE PARTS PICTURE DIFFERS FROM THE EMPTY ROOM, so "N differ" is a share of the
## thing photographed and not of the floor. The first version guessed the craft as "not the floor's colour", counted the
## lit floor as craft, and put a casting that drew NOTHING at 5 per cent different.
func _pair(tag: String, at: Array) -> Dictionary:
	camera.global_position = at[0]
	camera.look_at(at[1], Vector3.UP)
	var images: Array[Image] = []
	for shown in [null, parts_view, cast_view]:
		parts_view.visible = shown == parts_view
		cast_view.visible = shown == cast_view
		for frame in range(4): await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		images.append(image)
		if shown == null:
			continue
		var path: String = out.path_join("bake-%s-%s-%s%s.png" % [kind_name, tag, "parts" if shown == parts_view else "cast",
			"-shadows" if shadows else ""])
		if image.save_png(path) != OK: failures.append("save " + path)
		print("[bake_shot] saved %s" % path)
	parts_view.visible = true
	cast_view.visible = false
	var subject: int = 0
	var differ: int = 0
	var total: float = 0.0
	# NOT UNDER THE BUILD STAMP in the lower right (`BuildStamp`, 2026-09-18): it is in every picture on purpose, and its
	# letters are drawn over whatever is behind them, so they would count as craft pixels wherever the craft is behind them, and differ with it.
	var stamp: Rect2i = BuildStamp.pixels()
	for y in range(40, images[0].get_height()):
		for x in range(images[0].get_width()):
			if stamp.has_point(Vector2i(x, y)):
				continue
			var empty: Color = images[0].get_pixel(x, y)
			var a: Color = images[1].get_pixel(x, y)
			var b: Color = images[2].get_pixel(x, y)
			if _apart(a, empty) <= PIXEL_DIFFERS and _apart(b, empty) <= PIXEL_DIFFERS:
				continue
			subject += 1
			total += _apart(a, b)
			if _apart(a, b) > PIXEL_DIFFERS: differ += 1
	var share: float = float(differ) / maxf(float(subject), 1.0)
	print("[bake_shot] PIXELS %s: %d craft pixels (either view differs from the empty room by over %.2f); %d of them differ between the parts and the cast view (%.2f%%), mean difference %.4f"
		% [tag, subject, PIXEL_DIFFERS, differ, 100.0 * share, total / maxf(float(subject), 1.0)])
	_check("the_cast_%s_picture_is_the_parts_picture" % tag, subject > 1000 and share < 0.02,
		"%d of %d craft pixels differ" % [differ, subject])
	return {"differ": differ, "subject": subject}


static func _apart(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))


## THE RENDERER'S OWN COUNTS for: both hidden, the parts view alone, the cast view alone.
func _count() -> void:
	var rid: RID = get_viewport().get_viewport_rid()
	camera.global_position = (_cameras()[0] as Array)[0]
	camera.look_at((_cameras()[0] as Array)[1], Vector3.UP)
	var states: Array = [["nothing", false, false, false], ["parts", true, false, false], ["cast", false, true, false]]
	if batch_view != null:
		states.append(["batch", false, false, true])
	var measured: Dictionary = {}
	for state in states:
		parts_view.visible = state[1]
		cast_view.visible = state[2]
		if batch_view != null: batch_view.visible = state[3]
		for frame in range(8): await RenderingServer.frame_post_draw
		var sums := {"total": 0.0, "camera": 0.0, "shadow": 0.0, "primitives": 0.0}
		for frame in range(FRAMES):
			await RenderingServer.frame_post_draw
			sums["total"] += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			sums["camera"] += RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
				RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
			sums["shadow"] += RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
				RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
			sums["primitives"] += RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
				RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		for key in sums: sums[key] = float(sums[key]) / FRAMES
		measured[state[0]] = sums
	parts_view.visible = true
	cast_view.visible = false
	var method: String = RenderingServer.get_current_rendering_method()
	var views_by_state: Dictionary = {"parts": parts_view, "cast": cast_view, "batch": batch_view}
	for state in measured:
		if state == "nothing": continue
		var here: Dictionary = measured[state]
		var none: Dictionary = measured["nothing"]
		# ON MOBILE THE COUNTER IS AN INSTANCE COUNT (render_forward_mobile.cpp sets DRAW_CALLS_IN_FRAME to the number of
		# instances, and Mobile never merges repeats), so the draws Mobile actually issues are the SURFACES of the visible
		# instances, printed beside it. Forward+ counts its own draws, per surface, with consecutive repeats merged.
		print("[bake_shot] DRAWS %s %s (%s, %s): renderer counter +%.0f in the frame, +%.0f in the camera's pass, +%.0f in the shadow pass, +%.0f primitives in the camera's pass (frame %.0f, empty room %.0f); %d surfaces on %d visible instances"
			% [kind_name, state, method, "shadows" if shadows else "no shadows", here["total"] - none["total"], here["camera"] - none["camera"],
				here["shadow"] - none["shadow"], here["primitives"] - none["primitives"], here["total"], none["total"],
				_surfaces_shown(views_by_state[state])[0], _surfaces_shown(views_by_state[state])[1]])
	var saved: float = (measured["parts"]["total"] as float) - (measured["cast"]["total"] as float)
	_check("the_casting_draws_in_fewer_calls_than_its_parts", saved > 0.0,
		"%.0f fewer calls a frame" % saved)


## FLY IT: `tests/skyhawk.gd`'s loop, a pilot at 1,500 m working the stick, rudder, throttle and both flap notches, each
## tick both views handed the client's bus and linkage. Returns whether the cast surfaces ended where the parts did.
func _fly() -> Dictionary:
	var server := _world(0)
	var client := _world(1)
	for i in range(90):
		_step(server, client, _controls())
	var made: Dictionary = server.spawn_pilot(1, Sim.Kind.CESSNA, Vector3(0.0, 1500.0, 0.0), 0.0, Vector3(0.0, 0.0, -50.0))
	var flaps_range: int = 0
	for row in (Sim.schema_of(Sim.Kind.CESSNA).get("channels", []) as Array):
		if int((row as Dictionary).get("channel", -1)) == Sim.Channel.FLAPS:
			flaps_range = int((row as Dictionary).get("range", 0))
	var posed_us: int = 0
	var posed_calls: int = 0
	var bones_moved: int = 0
	var bus: Dictionary = {}
	var linkage: Dictionary = {}
	for tick in range(260):
		if tick == 60 and flaps_range > 0: client.send_command(Sim.Channel.FLAPS, 1)
		if tick == 160 and flaps_range > 0: client.send_command(Sim.Channel.FLAPS, flaps_range)
		_step(server, client, _controls({"throttle": 0.7, "pitch": 0.6, "roll": -0.4, "rudder": 0.5}))
		var craft: int = 0
		for state in client.vehicle_states():
			if int((state as Dictionary).get("kind", -1)) == Sim.Kind.CESSNA:
				craft = int((state as Dictionary).get("entity", 0))
		if craft == 0:
			continue
		bus = client.craft_controls(craft)
		linkage = client.crew_controls(craft)
		var velocity: Vector3 = client.vehicle_state(craft).get("velocity", Vector3.ZERO)
		for view in [parts_view, cast_view]:
			(view as VehicleView).draw_the_skyhawk_from(bus, linkage, client.vehicle_seats(craft), velocity, tick * DT)
		var started: int = Time.get_ticks_usec()
		bones_moved += casting.pose()
		posed_us += Time.get_ticks_usec() - started
		posed_calls += 1
	server.teardown(); client.teardown()
	if not (server is RefCounted): server.free()
	if not (client is RefCounted): client.free()
	# THE SKELETON IS ONLY UPDATED WHILE ITS VIEW IS SHOWN, so show it for a few frames before asking the engine to skin it.
	cast_view.visible = true
	for frame in range(3): await RenderingServer.frame_post_draw
	# WHERE EACH MOVING SURFACE'S TRAILING EDGE IS, on the parts view and in the engine's own skinning of the cast view
	# (`bake_mesh_from_current_skeleton_pose`), in the view's frame. The skinning is the engine's, not this file's
	# arithmetic, so a wrong bind or a bone posed from the wrong frame lands here.
	var worst: float = 0.0
	var worst_part := ""
	var swung: PackedStringArray = []
	var skinned: Dictionary = {}
	for drawn in casting.instances:
		skinned[drawn] = drawn.bake_mesh_from_current_skeleton_pose()
	for name in ["FlapPort", "FlapStarboard", "AileronPort", "AileronStarboard", "ElevatorPort", "ElevatorStarboard", "Rudder",
			"TrimTab"]:
		var part := parts_view.find_child(name, true, false) as MeshInstance3D
		var twin := cast_view.find_child(name, true, false) as MeshInstance3D
		if part == null or twin == null:
			worst = INF; worst_part = name + " missing"
			continue
		var local: PackedVector3Array = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var furthest: int = 0
		for i in range(local.size()):
			if local[i].z > local[furthest].z: furthest = i
		var truth: Vector3 = parts_view.global_transform.affine_inverse() * part.global_transform * local[furthest]
		var at_rest: Vector3 = _rest_of(part) * local[furthest]
		if truth.distance_to(at_rest) > 0.02: swung.append("%s %.2f m" % [name, truth.distance_to(at_rest)])
		var found: float = _nearest_skinned(skinned, truth)
		if found > worst:
			worst = found; worst_part = name
	cast_view.visible = false
	var moved: bool = worst < 0.005 and swung.size() >= 6
	return {"moved": moved,
		"detail": "flown %d ticks, spawned %s; bus flaps %.2f, stick %s, rudder %.2f; parts view swung %s; worst trailing edge on the cast view %.4f m from the parts view's (%s); Casting.pose %.1f us a call over %d calls, %d bone poses changed"
			% [260, made.get("vehicle", 0), float(bus.get("flaps", 0.0)), linkage.get("linked_stick", Vector2.ZERO),
				float(linkage.get("linked_rudder", 0.0)), ", ".join(swung), worst, worst_part,
				float(posed_us) / maxf(posed_calls, 1), posed_calls, bones_moved]}


## A PART'S POSE AS BUILT, from the airframe's own record of its hinge, in the view's frame.
func _rest_of(part: MeshInstance3D) -> Transform3D:
	var frame := (parts_view as VehicleView)._skyhawk as SkyhawkAirframe
	var hinge: Array = frame._hinges.get(part, [])
	var local := Transform3D(Basis.IDENTITY, hinge[0] if not hinge.is_empty() else part.position)
	return parts_view.global_transform.affine_inverse() * (part.get_parent() as Node3D).global_transform * local


func _nearest_skinned(skinned: Dictionary, point: Vector3) -> float:
	var best: float = INF
	for drawn in skinned:
		var mesh: ArrayMesh = skinned[drawn]
		var into: Transform3D = cast_view.global_transform.affine_inverse() * (drawn as Node3D).global_transform
		for surface in range(mesh.get_surface_count()):
			for vertex in (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				best = minf(best, (into * vertex).distance_to(point))
	return best


## DOES A CASTING HIDE A PART THAT HAS COME OFF? Two cases, and they come out differently, which is the finding.
##
## MOVED AFTER THE POUR: drop one strut 6 m on the cast view. `DrawnParts.adrift` reads a casting's vertex ARRAYS, which
## hold the pose it was poured at, so the casting's box stays where the aeroplane was built and the dropped strut is
## still found. (The first guess was that the casting would hide it; it does not.)
##
## BUILT IN THE WRONG PLACE, THEN POURED -- the tanker's floating tail, which is what the check exists for: a fresh view
## with its strut 6 m low BEFORE the pour, so the casting holds the stray strut's triangles inside one big box with the
## aeroplane's. Asked with the casting in the walk, the stray part is joined to the craft through the casting.
func _drift_check() -> void:
	var strut := cast_view.find_child("StrutPort", true, false) as Node3D
	if strut == null:
		return
	# THE VIEW MUST BE SHOWN: `adrift` walks only what is visible in the tree, and the first run of this check asked a
	# hidden view and found nothing adrift either way.
	cast_view.visible = true
	parts_view.visible = false
	strut.position += Vector3(0.0, -6.0, 0.0)
	casting.pose()
	var after_with: Array = DrawnParts.adrift(cast_view)
	for drawn in casting.instances: drawn.visible = false
	var after_without: Array = DrawnParts.adrift(cast_view)
	for drawn in casting.instances: drawn.visible = true
	strut.position -= Vector3(0.0, -6.0, 0.0)
	casting.pose()
	cast_view.visible = false
	var stray := _view("StrayView")
	(stray.find_child("StrutPort", true, false) as Node3D).position += Vector3(0.0, -6.0, 0.0)
	var poured := Casting.pour(stray)
	var before_with: Array = DrawnParts.adrift(stray)
	for drawn in poured.instances: drawn.visible = false
	var before_without: Array = DrawnParts.adrift(stray)
	remove_child(stray)
	stray.free()
	parts_view.visible = true
	print("[bake_shot] DRIFT a strut dropped 6 m AFTER the pour: DrawnParts.adrift finds %d adrift with the casting in the walk, %d without"
		% [after_with.size(), after_without.size()])
	print("[bake_shot] DRIFT a strut built 6 m low BEFORE the pour: DrawnParts.adrift finds %d adrift with the casting in the walk, %d without (%s)"
		% [before_with.size(), before_without.size(), ", ".join(before_without.map(func(a): return String(a["name"])))])
	_check("a_part_built_adrift_and_then_poured_is_hidden_by_the_casting_unless_the_walk_skips_it",
		before_without.size() > 0 and before_with.size() < before_without.size(),
		"%d found with the casting walked, %d with it skipped" % [before_with.size(), before_without.size()])


## ONE AIR BASE HANGAR, AS A BUILDING SOMEBODY AUTHORED IN THE EDITOR WOULD BE: every wall, roof slab, pilaster, plinth,
## fascia, panel line, door leaf, rib and window band `AirbaseView` lays for the base's first hangar, each its own
## `MeshInstance3D` with a `BoxMesh`, one shared `StandardMaterial3D` a colour. That is the "ton of pieces" -- and it is
## NOT how the game draws it: `AirbaseView` puts every piece of every building on the base into ONE MultiMesh of
## coloured unit boxes, drawn here as the third view. The pieces are the game's own (`structure_pieces`), not retyped.
func _hangar() -> void:
	var base: Dictionary = AirbasePlan.bases()[0]
	var hangar: Dictionary = base["hangars"][0]
	var frame: Dictionary = base["frame"]
	var back: float = float(hangar["door"]) + float(hangar["inward"]) * float(hangar["depth"])
	var centre: Vector3 = AirbasePlan.frame_point(frame, float(hangar["along"]), (float(hangar["door"]) + back) * 0.5)
	var reach: float = maxf(float(hangar["width"]), float(hangar["depth"])) * 0.5 + 2.0
	var pieces: Array[Dictionary] = []
	for piece in AirbaseView.structure_pieces(base):
		var at: Vector3 = piece["position"]
		if absf(at.x - centre.x) <= reach and absf(at.z - centre.z) <= reach:
			pieces.append(piece)
	var colours: Dictionary = {}
	for piece in pieces: colours[piece["colour"]] = true
	parts_view = _pieces("PartsHangar", pieces, centre)
	cast_view = _pieces("CastHangar", pieces, centre)
	var started: int = Time.get_ticks_usec()
	casting = Casting.pour(cast_view)
	var pour_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	var batch := AirbaseView.new()
	batch.position = centre
	batch.name = "BatchHangar"
	add_child(batch)
	var multimesh: MultiMeshInstance3D = batch._boxes(pieces, "Structures")
	batch.add_child(multimesh)
	batch_view = batch
	cast_view.visible = false
	batch_view.visible = false
	print("[bake_shot] hangar %s at %s on %s: %d pieces in %d colours; poured %d parts into %d instances, %d surfaces, %d triangles, in %.1f ms; the game's MultiMesh holds %d instances"
		% [hangar.get("id", "0"), centre, base["id"], pieces.size(), colours.size(), casting.parts.size(),
			casting.instances.size(), casting.surfaces(), casting.triangles(), pour_ms, multimesh.multimesh.instance_count])
	_check("the_casting_draws_every_triangle_the_parts_drew_and_no_more", casting.triangles() == _poured_triangles(),
		"%d poured, %d cast" % [_poured_triangles(), casting.triangles()])
	camera = Camera3D.new(); camera.fov = 40.0; camera.current = true; add_child(camera)
	var views: Array = _cameras()
	for index in range(views.size()):
		await _pair("neutral-%d" % index, views[index])
		camera.global_position = views[index][0]
		camera.look_at(views[index][1], Vector3.UP)
		parts_view.visible = false
		batch_view.visible = true
		for frame_count in range(4): await RenderingServer.frame_post_draw
		var path: String = out.path_join("bake-hangar-neutral-%d-multimesh%s.png" % [index, "-shadows" if shadows else ""])
		get_viewport().get_texture().get_image().save_png(path)
		print("[bake_shot] saved %s" % path)
		batch_view.visible = false
		parts_view.visible = true
	await _count()


func _pieces(called: String, pieces: Array[Dictionary], centre: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = called
	root.position = centre
	add_child(root)
	var materials: Dictionary = {}
	for index in range(pieces.size()):
		var piece: Dictionary = pieces[index]
		var colour: Color = piece["colour"]
		if not materials.has(colour):
			var paint := StandardMaterial3D.new()
			paint.albedo_color = colour
			paint.roughness = 0.92
			materials[colour] = paint
		var box := BoxMesh.new()
		box.size = (piece["half_extents"] as Vector3) * 2.0
		var drawn := MeshInstance3D.new()
		drawn.name = "Piece%03d" % index
		drawn.mesh = box
		drawn.material_override = materials[colour]
		drawn.position = (piece["position"] as Vector3) - centre
		root.add_child(drawn)
	return root


## N CESSNAS AS PARTS AGAINST N CAST, the frame timed with each set shown in turn, A/B/A/B, ROUNDS times, so a
## neighbour's load lands on both. What is timed: the viewport's measured render CPU and GPU, and the engine's process
## time (where every casting's pose runs). The cast set's pose is in its process time; the parts set has none.
const ROUNDS := 6
func _many() -> void:
	# UNCAPPED, so the wall time of a frame is what it costs and not the display's refresh.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var castings: Array[Casting] = []
	var columns: int = int(ceil(sqrt(float(many))))
	var spacing: float = 14.0
	var sets: Array = [[], []]
	for index in range(many * 2):
		var cast: bool = index >= many
		var view := _view("%s%d" % ["Cast" if cast else "Parts", index % many])
		var at: int = index % many
		view.position = Vector3(far + float(at % columns) * spacing, 0.0, far + float(at / columns) * spacing)
		if cast:
			# POSED BY THIS LOOP, NOT BY ITS OWN _process, so the pose can be timed on its own.
			var poured: Casting = Casting.pour(view)
			poured.set_process(false)
			castings.append(poured)
		(sets[1 if cast else 0] as Array).append(view)
	var middle := Vector3(far + float(columns - 1) * spacing * 0.5, 0.0, far + float(columns - 1) * spacing * 0.5)
	camera = Camera3D.new(); camera.fov = 50.0; camera.current = true; add_child(camera)
	camera.global_position = middle + Vector3(0.0, float(columns) * spacing * 0.9, float(columns) * spacing * 0.9)
	camera.look_at(middle, Vector3.UP)
	var rid: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	# EACH ROUND IS ONE PAIR, and the order ALTERNATES -- parts first on even rounds, cast first on odd -- so a warm-up or a
	# neighbour's burst does not land on one side every time. Each pair's difference is reported, then the median and the
	# spread, because a median of pairs that disagree by more than the effect is not a result.
	var keys: Array = ["cpu", "gpu", "pose", "wall"]
	var pairs: Array = []
	var draws: Array = [0.0, 0.0]
	for round in range(ROUNDS):
		var means: Array = [{}, {}]
		var order: Array = [0, 1] if round % 2 == 0 else [1, 0]
		for which in order:
			for view in sets[0]: (view as Node3D).visible = which == 0
			for view in sets[1]: (view as Node3D).visible = which == 1
			for frame in range(20): await RenderingServer.frame_post_draw
			var sum := {"cpu": 0.0, "gpu": 0.0, "pose": 0.0, "wall": 0.0}
			var begun: int = Time.get_ticks_usec()
			for frame in range(FRAMES):
				var posing: int = Time.get_ticks_usec()
				if which == 1 and not no_pose:
					for poured in castings: poured.pose()
				sum["pose"] += float(Time.get_ticks_usec() - posing) / 1000.0
				await RenderingServer.frame_post_draw
				sum["cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(rid)
				sum["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(rid)
				draws[which] += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME) / float(FRAMES * ROUNDS)
			sum["wall"] = float(Time.get_ticks_usec() - begun) / 1000.0
			for key in keys: means[which][key] = float(sum[key]) / FRAMES
		pairs.append(means)
		print("[bake_shot] PAIR %d (%s first): parts cpu %.3f gpu %.3f wall %.3f | cast cpu %.3f gpu %.3f pose %.3f wall %.3f ms"
			% [round, "parts" if order[0] == 0 else "cast", means[0]["cpu"], means[0]["gpu"], means[0]["wall"],
				means[1]["cpu"], means[1]["gpu"], means[1]["pose"], means[1]["wall"]])
	var path: String = out.path_join("bake-many-%d-%s%s.png" % [many, RenderingServer.get_current_rendering_method(),
		"-shadows" if shadows else ""])
	get_viewport().get_texture().get_image().save_png(path)
	for key in keys:
		var differences: Array = []
		for pair in pairs: differences.append(float(pair[1][key]) - float(pair[0][key]))
		differences.sort()
		var median: float = (differences[(differences.size() - 1) / 2] + differences[differences.size() / 2]) * 0.5
		print("[bake_shot] MANY %d %s (%s, %s%s): cast minus parts, median %+.3f ms, spread %+.3f to %+.3f over %d pairs"
			% [many, key, RenderingServer.get_current_rendering_method(), "shadows" if shadows else "no shadows",
				", never posed" if no_pose else "", median,
				differences[0], differences[differences.size() - 1], differences.size()])
	print("[bake_shot] MANY %d counter (instances on Mobile): parts %.0f, cast %.0f" % [many, draws[0], draws[1]])
	print("[bake_shot] saved %s" % path)


func _world(client_id: int) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(client_id)
	return world


func _step(server: Object, client: Object, input: Dictionary) -> void:
	client.set_input(input)
	server.tick(DT)
	client.tick(DT)
	for packet in server.take_outbound():
		if int(packet["peer"]) == 1: client.deliver(0, packet["bytes"], packet["bits"])
	for packet in client.take_outbound():
		server.deliver(1, packet["bytes"], packet["bits"])


func _controls(overrides: Dictionary = {}) -> Dictionary:
	var input := {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0,
		"brake": 0.0, "head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3.ZERO, "left_basis": Quaternion.IDENTITY, "right": Vector3.ZERO,
		"right_basis": Quaternion.IDENTITY, "grip_left": 0.0, "grip_right": 0.0,
		"buttons": 0, "trigger": 0.0, "kind_wanted": Sim.NO_KIND}
	for key in overrides: input[key] = overrides[key]
	return input


## EVERY VISIBLE, RENDERED GEOMETRY INSTANCE UNDER A VIEW, grouped by what it is: what the draw count is made of.
func _inventory(view: Node3D, tag: String) -> void:
	var rows: Dictionary = {}
	for found in view.find_children("*", "GeometryInstance3D", true, false):
		var drawn := found as GeometryInstance3D
		if not drawn.is_visible_in_tree() or drawn.layers == 0:
			continue
		var surfaces: int = 1
		if drawn is MeshInstance3D:
			surfaces = 0 if (drawn as MeshInstance3D).mesh == null else (drawn as MeshInstance3D).mesh.get_surface_count()
		var owner_name: String = _owner_of(drawn, view)
		var key: String = "%s %s" % [owner_name, drawn.get_class()]
		if not rows.has(key): rows[key] = [0, 0]
		rows[key][0] += 1
		rows[key][1] += surfaces
	var keys: Array = rows.keys()
	keys.sort_custom(func(a, b): return int(rows[a][1]) > int(rows[b][1]))
	var total: int = 0
	var lines: PackedStringArray = []
	for key in keys:
		total += int(rows[key][1])
		lines.append("%s x%d (%d surfaces)" % [key, rows[key][0], rows[key][1]])
	print("[bake_shot] INVENTORY %s %s: %d surfaces drawn: %s" % [kind_name, tag, total, "; ".join(lines)])


## [surfaces, instances] a view draws: every visible, rendered geometry instance and its surfaces (a MultiMesh's mesh's).
func _surfaces_shown(view: Node3D) -> Array:
	var surfaces: int = 0
	var instances: int = 0
	var was: bool = view.visible
	view.visible = true
	for found in view.find_children("*", "GeometryInstance3D", true, false):
		var drawn := found as GeometryInstance3D
		if not drawn.is_visible_in_tree() or drawn.layers == 0:
			continue
		var mesh: Mesh = null
		if drawn is MeshInstance3D: mesh = (drawn as MeshInstance3D).mesh
		elif drawn is MultiMeshInstance3D and (drawn as MultiMeshInstance3D).multimesh != null:
			mesh = (drawn as MultiMeshInstance3D).multimesh.mesh
		if mesh == null and (drawn is MeshInstance3D or drawn is MultiMeshInstance3D):
			continue
		instances += 1
		surfaces += 1 if mesh == null else mesh.get_surface_count()
	view.visible = was
	return [surfaces, instances]


## Which top-level part of the view a node hangs under, naming a control, station or shell if it is inside one.
func _owner_of(node: Node, view: Node) -> String:
	var walk: Node = node
	var top: String = String(node.name)
	while walk != null and walk != view:
		if walk is VehicleControl or walk is CockpitStation or walk is CockpitShell:
			return "%s(%s)" % [walk.get_class(), walk.name]
		top = String(walk.name)
		walk = walk.get_parent()
	return top


func _visible_meshes(view: Node3D, owned_too: bool) -> int:
	var count: int = 0
	for found in view.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if part.mesh != null and part.is_visible_in_tree() and part.layers != 0 and (owned_too or not Casting._owned(part)):
			count += 1
	return count


func _visible_triangles(view: Node3D, owned_too: bool) -> int:
	var count: int = 0
	for found in view.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if part.mesh != null and part.is_visible_in_tree() and part.layers != 0 and (owned_too or not Casting._owned(part)):
			for surface in range(part.mesh.get_surface_count()):
				count += Casting._triangles_in(part.mesh.surface_get_arrays(surface))
	return count


## The triangles in the parts the casting took, read off the parts themselves.
func _poured_triangles() -> int:
	var count: int = 0
	for entry in casting.parts:
		var mesh: Mesh = entry["mesh"]
		for surface in range(mesh.get_surface_count()):
			count += Casting._triangles_in(mesh.surface_get_arrays(surface))
	return count


func _drawn_box(view: Node3D) -> AABB:
	var box := AABB()
	var started := false
	for found in view.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if part.mesh == null or not part.is_visible_in_tree() or part.layers == 0:
			continue
		var one: AABB = DrawnParts.drawn_box(part, view)
		box = one if not started else box.merge(one)
		started = true
	return box


func _stamp() -> String:
	var head: Array = []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "--short", "HEAD"], head)
	var status: Array = []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "status", "--porcelain"], status)
	var dirty: bool = not status.is_empty() and not String(status[0]).strip_edges().is_empty()
	return "%s%s, %s" % [String(head[0]).strip_edges() if not head.is_empty() else "?", "+dirty" if dirty else "",
		Time.get_datetime_string_from_system(false, true)]


func _check(label: String, okay: bool, detail: String) -> void:
	print("[bake_shot] %s %s (%s)" % ["PASS" if okay else "FAIL", label, detail])
	if not okay: failures.append(label)
