extends Node3D
## WHAT MOVES A CESSNA'S CONTROL SURFACES FASTEST ONCE ITS PARTS ARE ONE MESH: the parts as they are, `Casting` posed every
## frame (what `bake` timed), `Casting` posed only when a hinge moved (`CastingOnChange`), and `HingeCasting`, which has no
## skeleton and turns each surface about its hinge in the vertex shader. RESEARCH PROBE for `research/vertex_animation.md`.
## NOT headless: headless draws nothing.
##
##   Godot --xr-mode off --desktop-only --path cockpit res://tests/vat_shot.tscn -- --out=<dir> [--shadows]
##   Godot ... res://tests/vat_shot.tscn -- --many=100 --variant=posed|onchange|hinge [--moving] [--shadows]
##
## WITHOUT --many, IT CHECKS THEY STILL MOVE, through the real path: a server and a client `CockpitWorld` over a loopback,
## a pilot working stick, rudder and both flap notches (`bake_shot`'s loop, from `tests/skyhawk.gd`), and every view
## handed the client's bus and linkage through `VehicleView.draw_the_skyhawk_from`. Nothing here sets a surface. Then each
## casting is photographed against the parts from the same camera, neutral and flown, with the empty room as the datum
## (`bake_shot._pair`). `CastingOnChange` is also checked in the engine's own skinning to the millimetre. `HingeCasting`
## moves its vertices on the GPU, which nothing here can read back, so the pictures are its check.
##
## `--freeze` IS THE MUTANT: the hinge casting is never handed a swing after the pour, and the flown pictures must go red.
##
## WITH --many, IT TIMES: n Cessnas as parts against n as the chosen variant, shown in turn, six pairs with the order
## alternated, as `bake_shot --many` does. `--moving` works every craft's stick, rudder and flaps every frame through the
## airframe's own setters (on both sets, timed apart as `drive`); without it they are parked and nothing moves.

const FRAMES := 60
const ROUNDS := 6
const DT := 1.0 / 120.0
const PIXEL_DIFFERS := 0.10
const SURFACES := ["FlapPort", "FlapStarboard", "AileronPort", "AileronStarboard", "ElevatorPort", "ElevatorStarboard",
	"Rudder", "TrimTab"]

var out := ""
var shadows := false
var many: int = 0
var variant := "hinge"
var moving := false
var freeze := false
## `--samples=<n>`: rows a feature gets in the VAT.
var samples: int = VatCasting.SAMPLES
## `--kind=fighter`: the fighter's gear and hook through the VAT instead of the Cessna's surfaces.
var kind_name := "cessna"
var camera: Camera3D
var parts_view: VehicleView
var failures: PackedStringArray = []
var stamp := ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument == "--shadows": shadows = true
		elif argument.begins_with("--many="): many = int(argument.trim_prefix("--many="))
		elif argument.begins_with("--variant="): variant = argument.trim_prefix("--variant=")
		elif argument == "--moving": moving = true
		elif argument == "--freeze": freeze = true
		elif argument.begins_with("--samples="): samples = int(argument.trim_prefix("--samples="))
		elif argument.begins_with("--kind="): kind_name = argument.trim_prefix("--kind=")
	if out.is_empty(): out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	stamp = _stamp()
	_room()
	print("[vat_shot] %s, renderer %s" % [stamp, RenderingServer.get_current_rendering_method()])
	if many > 0:
		await _many()
	elif kind_name == "fighter":
		await _gear()
	else:
		await _still_moves()
	print("[vat_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL %s" % ", ".join(failures), out])
	get_tree().quit(0 if failures.is_empty() else 1)


## THE PROPELLER SPINS AND ITS DISC FADES: neither is a hinge, so every casting here leaves them to draw themselves,
## the same for all three, so the comparison is like for like.
static func _not_a_hinge(part: MeshInstance3D) -> bool:
	return String(part.name) in ["Propeller", "PropellerDisc"]


static func _hinges_of(view: VehicleView) -> Dictionary:
	return ((view._skyhawk as SkyhawkAirframe)._hinges as Dictionary)


func _view(called: String, kind: int = Sim.Kind.CESSNA) -> VehicleView:
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	view.name = called
	add_child(view)
	view.setup(0, kind)
	return view


## THE FEATURES A VAT BAKES, each the airframe's own setter and getter. The one list this lane writes: in a game it
## would be the airframe's to publish (`features()`), beside the setters it names.
static func _features_of(view: VehicleView) -> Array:
	var sky := view._skyhawk as SkyhawkAirframe
	if sky != null:
		return [
			{"name": "flaps", "set": sky.set_flaps, "get": sky.flaps_amount, "low": 0.0, "high": 1.0},
			{"name": "ailerons", "set": sky.set_ailerons, "get": func() -> float: return sky.stick_amounts().x, "low": -1.0, "high": 1.0},
			{"name": "elevator", "set": sky.set_elevator, "get": func() -> float: return sky.stick_amounts().y, "low": -1.0, "high": 1.0},
			{"name": "rudder", "set": sky.set_rudder, "get": func() -> float: return sky.stick_amounts().z, "low": -1.0, "high": 1.0},
			{"name": "trim", "set": sky.set_trim, "get": sky.trim_amount, "low": -1.0, "high": 1.0}]
	var fighter := view._fighter as FighterAirframe
	if fighter != null:
		return [
			{"name": "gear", "set": fighter.set_gear, "get": fighter.gear_amount, "low": 0.0, "high": 1.0},
			# THE HOOK ASKS FOR FEWER ROWS: one plain swing, not the gear's two-stage sequence. Each feature is its own
			# table in the one texture, so it can be held to the millimetre with a quarter of the gear's rows.
			{"name": "hook", "set": fighter.set_hook, "get": fighter.hook_amount, "low": 0.0, "high": 1.0, "samples": 33}]
	return []


## ---- does it still move -------------------------------------------------------------------------------------------

func _still_moves() -> void:
	parts_view = _view("PartsView")
	var hinge_view := _view("HingeView")
	var change_view := _view("ChangeView")
	var vat_view := _view("VatView")
	var started: int = Time.get_ticks_usec()
	var hinge: HingeCasting = await HingeCasting.pour(hinge_view, _hinges_of(hinge_view), _not_a_hinge)
	var hinge_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	hinge.set_process(false)
	var poured: Casting = Casting.pour(change_view, _not_a_hinge)
	poured.set_process(false)
	var watch := CastingOnChange.following(poured, _hinges_of(change_view))
	started = Time.get_ticks_usec()
	var vat: VatCasting = await VatCasting.pour(vat_view, _features_of(vat_view), _not_a_hinge, samples)
	var vat_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	vat.set_process(false)
	print("[vat_shot] vat casting: %d parts, %d features x %d samples, texture %dx%d, %d surfaces, %d triangles, poured and baked in %.1f ms (the frames waited for shader code included); parts each feature moves: %s"
		% [vat.poured, vat.features.size(), vat.samples, vat.turn_image.get_width(), vat.turn_image.get_height(),
			vat.surfaces(), vat.triangles(), vat_ms, vat.moved_by])
	_check("the_vat_casting_holds_every_triangle_the_casting_does", vat.triangles() == poured.triangles(),
		"%d against %d" % [vat.triangles(), poured.triangles()])
	var trim_tab: int = vat.columns.find(vat_view.find_child("TrimTab", true, false))
	var tab_features: Vector2i = vat.features_of(trim_tab)
	_check("the_trim_tab_turns_on_trim_first_and_rides_the_elevator",
		trim_tab >= 0 and tab_features == Vector2i(4, 2), "inner, outer feature indices %s" % tab_features)
	print("[vat_shot] hinge casting: %d parts into %d instances, %d surfaces, %d triangles, %d hinges, in %.1f ms; casting: %d parts, %d surfaces, %d triangles; %d bones ride on hinges"
		% [hinge.poured, hinge.instances.size(), hinge.surfaces(), hinge.triangles(), hinge.hinges.size(), hinge_ms,
			poured.parts.size(), poured.surfaces(), poured.triangles(), watch.riders.size()])
	_check("the_hinge_casting_holds_every_triangle_the_casting_does", hinge.triangles() == poured.triangles(),
		"%d against %d" % [hinge.triangles(), poured.triangles()])
	_check("every_cessna_surface_is_a_hinge", hinge.hinges.size() == SURFACES.size(),
		"%d hinges from the airframe's record" % hinge.hinges.size())
	for drawn in hinge.instances:
		for surface in range(drawn.mesh.get_surface_count()):
			var material := drawn.mesh.surface_get_material(surface)
			_check("hinge_material_%s_%d_is_a_converted_shader" % [drawn.name, surface], material is ShaderMaterial,
				"%s" % material)
	camera = Camera3D.new(); camera.fov = 40.0; camera.current = true; add_child(camera)
	var cameras: Array = _cameras()
	var views: Array = [parts_view, hinge_view, change_view, vat_view]
	for index in range(cameras.size()):
		await _pair("neutral-%d" % index, cameras[index], views, hinge_view, "hinge")
		await _pair("neutral-%d" % index, cameras[index], views, change_view, "onchange")
		await _pair("neutral-%d" % index, cameras[index], views, vat_view, "vat")

	# FLY IT, and hand every view the client's bus and linkage each tick.
	var server := _world(0)
	var client := _world(1)
	for i in range(90):
		_step(server, client, _controls())
	server.spawn_pilot(1, Sim.Kind.CESSNA, Vector3(0.0, 1500.0, 0.0), 0.0, Vector3(0.0, 0.0, -50.0))
	var flaps_range: int = 0
	var trim_range: int = 0
	for row in (Sim.schema_of(Sim.Kind.CESSNA).get("channels", []) as Array):
		if int((row as Dictionary).get("channel", -1)) == Sim.Channel.FLAPS:
			flaps_range = int((row as Dictionary).get("range", 0))
		if int((row as Dictionary).get("channel", -1)) == Sim.Channel.TRIM:
			trim_range = int((row as Dictionary).get("range", 0))
	var swings: int = 0
	var poses: int = 0
	var swing_us: int = 0
	var pose_us: int = 0
	var ticks: int = 0
	for tick in range(260):
		if tick == 60 and flaps_range > 0: client.send_command(Sim.Channel.FLAPS, 1)
		if tick == 160 and flaps_range > 0: client.send_command(Sim.Channel.FLAPS, flaps_range)
		# THE TRIM WHEEL TO ITS STOP, so the trim tab swings about its own hinge while it rides on the elevator's.
		if tick == 110 and trim_range > 0: client.send_command(Sim.Channel.TRIM, trim_range)
		_step(server, client, _controls({"throttle": 0.7, "pitch": 0.6, "roll": -0.4, "rudder": 0.5}))
		var craft: int = 0
		for state in client.vehicle_states():
			if int((state as Dictionary).get("kind", -1)) == Sim.Kind.CESSNA:
				craft = int((state as Dictionary).get("entity", 0))
		if craft == 0:
			continue
		var bus: Dictionary = client.craft_controls(craft)
		var linkage: Dictionary = client.crew_controls(craft)
		var velocity: Vector3 = client.vehicle_state(craft).get("velocity", Vector3.ZERO)
		for view in views:
			(view as VehicleView).draw_the_skyhawk_from(bus, linkage, client.vehicle_seats(craft), velocity, tick * DT)
		ticks += 1
		var begun: int = Time.get_ticks_usec()
		if not freeze:
			swings += hinge.swing()
		swing_us += Time.get_ticks_usec() - begun
		begun = Time.get_ticks_usec()
		poses += watch.pose()
		pose_us += Time.get_ticks_usec() - begun
		if not freeze:
			vat.play()
	server.teardown(); client.teardown()
	if not (server is RefCounted): server.free()
	if not (client is RefCounted): client.free()
	print("[vat_shot] flown %d ticks: HingeCasting.swing %.1f us a call, %d hinge changes; CastingOnChange.pose %.1f us a call, %d bone poses"
		% [ticks, float(swing_us) / maxf(ticks, 1), swings, float(pose_us) / maxf(ticks, 1), poses])
	var swung: PackedStringArray = []
	for name in SURFACES:
		var part := parts_view.find_child(name, true, false) as Node3D
		if not part.quaternion.is_equal_approx(Quaternion.IDENTITY): swung.append(name)
	_check("the_flight_swung_every_surface", swung.size() == SURFACES.size(), "swung: %s" % ", ".join(swung))

	# THE ENGINE'S OWN SKINNING OF THE ON-CHANGE CASTING, trailing edge by trailing edge (`bake_shot._fly`'s check).
	for view in views: (view as Node3D).visible = view == change_view
	for frame in range(3): await RenderingServer.frame_post_draw
	var worst: float = 0.0
	var worst_part := ""
	var skinned: Dictionary = {}
	for drawn in poured.instances:
		skinned[drawn] = drawn.bake_mesh_from_current_skeleton_pose()
	for name in SURFACES:
		var truth: Vector3 = _trailing_edge(parts_view, name)
		var found: float = _nearest(skinned, change_view, truth)
		if found > worst:
			worst = found; worst_part = name
	_check("the_on_change_casting_puts_every_surface_where_its_part_is", worst < 0.0005,
		"worst trailing edge %.4f m from the part's (%s), in the engine's own skinning" % [worst, worst_part])

	# THE HINGE FORMULA ON THE CPU, the shader's arithmetic written again: NOT an independent check -- it shares every
	# assumption with the shader -- but it says in metres what the pictures say in pixels.
	worst = 0.0
	worst_part = ""
	for name in SURFACES:
		var truth: Vector3 = _trailing_edge(parts_view, name)
		var twin := hinge_view.find_child(name, true, false) as MeshInstance3D
		var local: PackedVector3Array = twin.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var furthest: int = _furthest_aft(local)
		var rest: Vector3 = _rest_point(hinge, twin, local[furthest])
		var turned: Vector3 = _turn_as_the_shader_does(hinge, twin, rest)
		if turned.distance_to(truth) > worst:
			worst = turned.distance_to(truth); worst_part = name
	_check("the_hinge_arithmetic_puts_every_surface_where_its_part_is", freeze or worst < 0.0005,
		"worst trailing edge %.4f m (%s), by the CPU copy of the shader's formula" % [worst, worst_part])

	for index in range(cameras.size()):
		await _pair("flown-%d" % index, cameras[index], views, hinge_view, "hinge")
		await _pair("flown-%d" % index, cameras[index], views, change_view, "onchange")
		await _pair("flown-%d" % index, cameras[index], views, vat_view, "vat")
	# THE VAT'S BLENDING ERROR, in metres: every vertex of every moving surface, played by the CPU copy of the shader,
	# against where the parts view draws it. Not independent of the shader, but it is the number the sample count buys.
	var amounts: Array = []
	for feature in vat.features: amounts.append(float((feature["get"] as Callable).call()))
	var vat_worst: float = 0.0
	var vat_part := ""
	for name in SURFACES:
		var column: int = vat.columns.find(vat_view.find_child(name, true, false))
		var truth_part := parts_view.find_child(name, true, false) as MeshInstance3D
		var local: PackedVector3Array = truth_part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var inner_outer: Vector2i = vat.features_of(column)
		for vertex in local:
			var truth: Vector3 = parts_view.global_transform.affine_inverse() * truth_part.global_transform * vertex
			var played: Vector3 = vat.played_point(column, vat.rest_poses[column] * vertex, inner_outer.x, inner_outer.y, amounts)
			if played.distance_to(truth) > vat_worst:
				vat_worst = played.distance_to(truth); vat_part = name
	_check("the_vat_puts_every_surface_vertex_within_a_millimetre_of_its_part", freeze or vat_worst < 0.001,
		"worst vertex %.5f m (%s) at %d samples a feature, by the CPU copy of the shader's formula" % [vat_worst, vat_part, vat.samples])


## ---- the fighter's gear and hook ------------------------------------------------------------------------------------

## THE GEAR AND HOOK THROUGH THE VAT. The ends go through the real draw function, `_draw_the_fighters_actuators`, handed a
## bus: the gear bit off and the hook bit on, then back. The gear has no in-between on the bus yet (it snaps, 1 or 0), so
## the in-betweens -- where the doors are open and the legs half way, the sequence a rigid-body VAT exists for -- are set
## through the airframe's own `set_gear`, on both views alike.
func _gear() -> void:
	(find_child("Floor", true, false) as Node3D).visible = false
	parts_view = _view("PartsView", Sim.Kind.FIGHTER)
	var vat_view := _view("VatView", Sim.Kind.FIGHTER)
	# THE NAV LIGHTS BLINK ON THE CLOCK, so a strobe lit in one picture and dark in the next reads as the VAT's fault: the
	# first run put 3.99% of the gear-down picture red on a white flash. They are not cast; hide them on both views.
	for view in [parts_view, vat_view]:
		for light in (view as Node).find_children("*", "MultiMeshInstance3D", true, false):
			(light as Node3D).visible = false
	var started: int = Time.get_ticks_usec()
	var vat: VatCasting = await VatCasting.pour(vat_view, _features_of(vat_view), Callable(), samples)
	var vat_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	vat.set_process(false)
	print("[vat_shot] fighter vat casting: %d parts, %d features x %d samples, texture %dx%d, %d surfaces, %d triangles, in %.1f ms; parts each feature moves: %s"
		% [vat.poured, vat.features.size(), vat.samples, vat.turn_image.get_width(), vat.turn_image.get_height(),
			vat.surfaces(), vat.triangles(), vat_ms, vat.moved_by])
	_check("the_gear_moves_parts", int(vat.moved_by.get("gear", 0)) >= 3, "%s" % vat.moved_by)
	_check("the_hook_moves_parts", int(vat.moved_by.get("hook", 0)) >= 1, "%s" % vat.moved_by)
	camera = Camera3D.new(); camera.fov = 40.0; camera.current = true; add_child(camera)
	var box: AABB = AABB()
	var first: bool = true
	for found in parts_view.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if part.mesh == null or not part.is_visible_in_tree(): continue
		var drawn: AABB = part.global_transform * part.get_aabb()
		box = drawn if first else box.merge(drawn)
		first = false
	var centre: Vector3 = box.get_center() + Vector3(0.0, -box.size.y * 0.25, 0.0)
	var reach: float = box.size.length() * 0.5
	var cameras: Array = [[centre + Vector3(0.85, -0.25, 0.45).normalized() * reach * 1.6, centre],
		[centre + Vector3(-0.55, -0.35, -0.75).normalized() * reach * 1.6, centre]]
	var views: Array = [parts_view, vat_view]
	for state in [{"tag": "up-hooked", "bus": {"gear": false, "hook": true}}, {"tag": "down", "bus": {"gear": true, "hook": false}}]:
		for view in views: (view as VehicleView)._draw_the_fighters_actuators(state["bus"])
		vat.play()
		for index in range(cameras.size()):
			await _pair("fighter-%s-%d" % [state["tag"], index], cameras[index], views, vat_view, "vat")
		_vat_error(vat, vat_view, "bus %s" % state["tag"])
	# OFF THE SAMPLE GRID FOR 33, 65 AND 129 ROWS: the first list held 0.5 and 0.75, which are rows, and read 0.00000 m
	# there -- a blending check that asked only where no blending happens.
	for amount in [0.1, 0.2, 0.3, 0.55, 0.8, 0.9]:
		for view in views: ((view as VehicleView)._fighter as FighterAirframe).set_gear(amount)
		vat.play()
		_vat_error(vat, vat_view, "gear %.2f" % amount)
		if amount == 0.3:
			for index in range(cameras.size()):
				await _pair("fighter-gear-0.30-%d" % index, cameras[index], views, vat_view, "vat")
	for view in views: ((view as VehicleView)._fighter as FighterAirframe).set_gear(1.0)
	for amount in [0.15, 0.45, 0.7]:
		for view in views: ((view as VehicleView)._fighter as FighterAirframe).set_hook(amount)
		vat.play()
		_vat_error(vat, vat_view, "hook %.2f" % amount)
	for view in views: ((view as VehicleView)._fighter as FighterAirframe).set_hook(0.0)
	var tables: PackedStringArray = []
	for feature in vat.features: tables.append("%s %d rows from row %d" % [feature["name"], feature["rows"], feature["first"]])
	print("[vat_shot] the fighter's tables: %s; texture %dx%d" % [", ".join(tables), vat.turn_image.get_width(),
		vat.turn_image.get_height()])
	vat.play()


## EVERY VERTEX OF EVERY PART, played by the CPU copy of the VAT shader, against where the parts view draws it.
func _vat_error(vat: VatCasting, vat_view: Node3D, label: String) -> void:
	var amounts: Array = []
	for feature in vat.features: amounts.append(float((feature["get"] as Callable).call()))
	var worst: float = 0.0
	var worst_part := ""
	for column in range(vat.columns.size()):
		var twin: MeshInstance3D = vat.columns[column]
		var path: NodePath = vat_view.get_path_to(twin)
		var truth_part := parts_view.get_node_or_null(path) as MeshInstance3D
		if truth_part == null: continue
		var inner_outer: Vector2i = vat.features_of(column)
		if inner_outer.x < 0: continue
		for vertex in (truth_part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var truth: Vector3 = parts_view.global_transform.affine_inverse() * truth_part.global_transform * vertex
			var played: Vector3 = vat.played_point(column, vat.rest_poses[column] * vertex, inner_outer.x, inner_outer.y, amounts)
			if played.distance_to(truth) > worst:
				worst = played.distance_to(truth); worst_part = String(twin.name)
	_check("the_fighter_vat_within_a_millimetre_at_%s" % label.replace(" ", "_"), worst < 0.001,
		"worst vertex %.5f m (%s) at %d samples" % [worst, worst_part, vat.samples])


static func _furthest_aft(local: PackedVector3Array) -> int:
	var furthest: int = 0
	for i in range(local.size()):
		if local[i].z > local[furthest].z: furthest = i
	return furthest


## A surface's aftmost vertex where the parts view draws it now, in the view's frame.
func _trailing_edge(view: VehicleView, name: String) -> Vector3:
	var part := view.find_child(name, true, false) as MeshInstance3D
	var local: PackedVector3Array = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	return view.global_transform.affine_inverse() * part.global_transform * local[_furthest_aft(local)]


## Where the hinge casting stored this vertex: the part at rest, in the root's frame.
func _rest_point(hinge: HingeCasting, part: MeshInstance3D, vertex: Vector3) -> Vector3:
	var chain: Array = []
	var walk: Node = part
	while walk != hinge.root:
		chain.push_front(walk)
		walk = walk.get_parent()
	var at := Transform3D.IDENTITY
	for node in chain:
		var entry: Dictionary = _entry_of(hinge, node)
		at = at * (Transform3D(Basis.IDENTITY, entry["built_at"]) if not entry.is_empty() else (node as Node3D).transform)
	return at * vertex


func _turn_as_the_shader_does(hinge: HingeCasting, part: Node, rest: Vector3) -> Vector3:
	var own: Dictionary = _entry_of(hinge, part)
	var up: Dictionary = {}
	for entry in hinge.hinges:
		if int(entry["slot"]) == int(own["parent"]): up = entry
	var v: Vector3 = rest
	for entry in [own, up]:
		if (entry as Dictionary).is_empty():
			continue
		var w: Vector4 = entry["last"]
		var at: Vector3 = entry["at"]
		v = at + (v - at).rotated(entry["axis"], w.w) + Vector3(w.x, w.y, w.z)
	return v


static func _entry_of(hinge: HingeCasting, node: Node) -> Dictionary:
	for entry in hinge.hinges:
		if entry["node"] == node: return entry
	return {}


func _nearest(skinned: Dictionary, view: Node3D, point: Vector3) -> float:
	var best: float = INF
	for drawn in skinned:
		var mesh: ArrayMesh = skinned[drawn]
		var into: Transform3D = view.global_transform.affine_inverse() * (drawn as Node3D).global_transform
		for surface in range(mesh.get_surface_count()):
			for vertex in (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				best = minf(best, (into * vertex).distance_to(point))
	return best


## ---- the pictures ---------------------------------------------------------------------------------------------------

func _room() -> void:
	var environment := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.24, 0.28, 0.33)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_energy = 1.1
	env.ambient_light_color = Color(0.55, 0.57, 0.60)
	environment.environment = env; add_child(environment)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(-0.8, -0.55, 0.0); sun.light_energy = 1.4
	sun.shadow_enabled = shadows
	add_child(sun)
	var rest: float = float((Sim.geometry_of(Sim.Kind.CESSNA).get("extents", Vector3.ONE) as Vector3).y)
	var floor := MeshInstance3D.new(); var slab := BoxMesh.new(); slab.size = Vector3(160, 0.15, 160)
	floor.mesh = slab; floor.position = Vector3(0.0, -rest - 0.075, 0.0); floor.name = "Floor"; add_child(floor)
	var label := Label.new(); label.text = "%s  %s  %s%s" % [stamp, kind_name, "shadows" if shadows else "no shadows",
		"  %d x %s%s" % [many, variant, " moving" if moving else " parked"] if many > 0 else ""]
	label.position = Vector2(12, 8); label.add_theme_font_size_override("font_size", 18)
	var layer := CanvasLayer.new(); layer.add_child(label); add_child(layer)


## A three-quarter from behind and above (flaps, elevators, rudder) and one from ahead and to port, fitted to the craft.
func _cameras() -> Array:
	var box: AABB = AABB()
	var first: bool = true
	for found in parts_view.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if part.mesh == null or not part.is_visible_in_tree(): continue
		var drawn: AABB = part.global_transform * part.get_aabb()
		box = drawn if first else box.merge(drawn)
		first = false
	var centre: Vector3 = box.get_center()
	var reach: float = box.size.length() * 0.62
	return [[centre + Vector3(0.55, 0.45, 0.70).normalized() * reach * 1.9, centre],
		[centre + Vector3(-0.70, 0.30, -0.65).normalized() * reach * 1.9, centre]]


## The parts and one casting from the same camera, and the empty room, and how many craft pixels differ.
func _pair(tag: String, at: Array, views: Array, cast_view: Node3D, what: String) -> void:
	camera.global_position = at[0]
	camera.look_at(at[1], Vector3.UP)
	var images: Array[Image] = []
	for shown in [null, parts_view, cast_view]:
		for view in views: (view as Node3D).visible = view == shown
		for frame in range(4): await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		images.append(image)
		if shown == null: continue
		var path: String = out.path_join("vat-%s-%s-%s%s%s.png" % [tag, what, "parts" if shown == parts_view else "cast",
			"-shadows" if shadows else "", "-frozen" if freeze else ""])
		if image.save_png(path) != OK: failures.append("save " + path)
	var subject: int = 0
	var differ: int = 0
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
			if _apart(a, empty) <= PIXEL_DIFFERS and _apart(b, empty) <= PIXEL_DIFFERS: continue
			subject += 1
			if _apart(a, b) > PIXEL_DIFFERS: differ += 1
	var share: float = float(differ) / maxf(float(subject), 1.0)
	print("[vat_shot] PIXELS %s %s: %d craft pixels, %d differ (%.2f%%)" % [what, tag, subject, differ, 100.0 * share])
	_check("the_%s_%s_picture_is_the_parts_picture" % [what, tag], subject > 1000 and share < 0.02,
		"%d of %d craft pixels differ" % [differ, subject])


static func _apart(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))


## ---- the timing ---------------------------------------------------------------------------------------------------

## N PARTS AGAINST N OF THE VARIANT, A/B pairs with the order alternated. Keys: render cpu and gpu (the viewport's
## measured times), drive (the airframe setters, both sets), pose (the variant's own update, cast set only), wall.
func _many() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var columns: int = int(ceil(sqrt(float(many))))
	var spacing: float = 14.0
	var sets: Array = [[], []]
	var frames: Array = [[], []]
	var updates: Array = []
	var watchers: Array = []
	for index in range(many * 2):
		var cast: bool = index >= many
		var view := _view("%s%d" % ["Cast" if cast else "Parts", index % many])
		var at: int = index % many
		view.position = Vector3(float(at % columns) * spacing, 0.0, float(at / columns) * spacing)
		if cast:
			match variant:
				"posed":
					var poured: Casting = Casting.pour(view, _not_a_hinge)
					poured.set_process(false)
					updates.append(poured.pose)
				"onchange":
					var poured: Casting = Casting.pour(view, _not_a_hinge)
					poured.set_process(false)
					# HELD HERE: a Callable does not keep a RefCounted alive, and the first run posed a freed watcher.
					var watch := CastingOnChange.following(poured, _hinges_of(view))
					watchers.append(watch)
					updates.append(watch.pose)
				"hinge":
					var hinge: HingeCasting = await HingeCasting.pour(view, _hinges_of(view), _not_a_hinge)
					hinge.set_process(false)
					updates.append(hinge.swing)
				"vat":
					var vat: VatCasting = await VatCasting.pour(view, _features_of(view), _not_a_hinge, samples)
					vat.set_process(false)
					updates.append(vat.play)
				_:
					failures.append("unknown variant " + variant)
					return
		(sets[1 if cast else 0] as Array).append(view)
		(frames[1 if cast else 0] as Array).append(view._skyhawk)
	var middle := Vector3(float(columns - 1) * spacing * 0.5, 0.0, float(columns - 1) * spacing * 0.5)
	camera = Camera3D.new(); camera.fov = 50.0; camera.current = true; add_child(camera)
	camera.global_position = middle + Vector3(0.0, float(columns) * spacing * 0.9, float(columns) * spacing * 0.9)
	camera.look_at(middle, Vector3.UP)
	var rid: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var keys: Array = ["cpu", "gpu", "drive", "pose", "wall"]
	var pairs: Array = []
	var clock: int = 0
	for round in range(ROUNDS):
		var means: Array = [{}, {}]
		var order: Array = [0, 1] if round % 2 == 0 else [1, 0]
		for which in order:
			for view in sets[0]: (view as Node3D).visible = which == 0
			for view in sets[1]: (view as Node3D).visible = which == 1
			var sum := {"cpu": 0.0, "gpu": 0.0, "drive": 0.0, "pose": 0.0, "wall": 0.0}
			var begun: int = 0
			for frame in range(20 + FRAMES):
				if frame == 20:
					begun = Time.get_ticks_usec()
					for key in sum: sum[key] = 0.0
				var driving: int = Time.get_ticks_usec()
				if moving:
					clock += 1
					var t: float = float(clock) * 0.05
					var i: int = 0
					for frame_of in frames[which]:
						var airframe := frame_of as SkyhawkAirframe
						airframe.set_ailerons(sin(t + i))
						airframe.set_elevator(cos(t * 0.7 + i))
						airframe.set_rudder(sin(t * 1.3 + i))
						airframe.set_flaps(0.5 + 0.5 * sin(t * 0.2 + i))
						i += 1
				sum["drive"] += float(Time.get_ticks_usec() - driving) / 1000.0
				var posing: int = Time.get_ticks_usec()
				if which == 1:
					for update in updates: (update as Callable).call()
				sum["pose"] += float(Time.get_ticks_usec() - posing) / 1000.0
				await RenderingServer.frame_post_draw
				sum["cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(rid)
				sum["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(rid)
			sum["wall"] = float(Time.get_ticks_usec() - begun) / 1000.0
			for key in keys: means[which][key] = float(sum[key]) / FRAMES
		pairs.append(means)
		print("[vat_shot] PAIR %d (%s first): parts cpu %.3f gpu %.3f drive %.3f wall %.3f | %s cpu %.3f gpu %.3f drive %.3f pose %.3f wall %.3f ms"
			% [round, "parts" if order[0] == 0 else variant, means[0]["cpu"], means[0]["gpu"], means[0]["drive"],
				means[0]["wall"], variant, means[1]["cpu"], means[1]["gpu"], means[1]["drive"], means[1]["pose"],
				means[1]["wall"]])
	var path: String = out.path_join("vat-many-%d-%s-%s%s%s.png" % [many, variant, RenderingServer.get_current_rendering_method(),
		"-moving" if moving else "", "-shadows" if shadows else ""])
	get_viewport().get_texture().get_image().save_png(path)
	for key in keys:
		var differences: Array = []
		for pair in pairs: differences.append(float(pair[1][key]) - float(pair[0][key]))
		differences.sort()
		var median: float = (differences[(differences.size() - 1) / 2] + differences[differences.size() / 2]) * 0.5
		var absolute: Array = []
		for pair in pairs: absolute.append(float(pair[0][key]))
		absolute.sort()
		print("[vat_shot] MANY %d %s %s (%s, %s, %s): %s minus parts, median %+.3f ms, spread %+.3f to %+.3f over %d pairs; parts median %.3f"
			% [many, variant, key, RenderingServer.get_current_rendering_method(), "shadows" if shadows else "no shadows",
				"moving" if moving else "parked", variant, median, differences[0], differences[differences.size() - 1],
				differences.size(), absolute[absolute.size() / 2]])
	print("[vat_shot] saved %s" % path)


## ---- the loopback, as bake_shot runs it -----------------------------------------------------------------------------

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


func _stamp() -> String:
	var head: Array = []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "--short", "HEAD"], head)
	return "%s, %s" % [String(head[0]).strip_edges() if not head.is_empty() else "?",
		Time.get_datetime_string_from_system(false, true)]


func _check(label: String, okay: bool, detail: String) -> void:
	print("[vat_shot] %s %s (%s)" % ["PASS" if okay else "FAIL", label, detail])
	if not okay: failures.append(label)
