extends Node
## Headless: A WARBIRD'S COCKPIT SEEN FROM ITS OWN SEAT (lane/warbirds2). The warthog lane's view checks (`tests/warthog.gd`,
## "the pilot sees over the nose"), for every warbird kind, read off the view the game builds and never off the airframe
## alone. From the eye `WarbirdAirframe.eye()` puts under the drawn canopy:
## - OVER THE NOSE: every ray the glass leaves open, down to 12 degrees under the eye and 20 either side, is still open with
##   the cockpit in. IN THE AIRFRAME'S LEVEL FRAME, which is its attitude in cruise; on the ground at its three-point rake
##   the long nose hides the runway ahead, as it really does, and that is left alone (the brief);
## - THE SCREENS face the eye and are seen on their glass;
## - BELOW THE GLASS the eye meets the coaming (`WarbirdAirframe._coaming`), never the inside of the hollow nose;
## - EVERY CONTROL AND SCREEN is inside the drawn skin and seen against it, never against the sky;
## - THE ROOM the kit promises (`cabin_room`) is inside the drawn skin, canopy counted in (`encloses`).
## Read RESULT=, not the exit code.

## THE KINDS, and the least number of open rays over the nose each must keep (a fighter's long nose leaves fewer).
const KINDS: Dictionary = {"p51": {"open_least": 40}, "p47": {"open_least": 40}}

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	for kind in Sim.Kind.values():
		var name: String = Sim.kind_name(kind)
		if KINDS.has(name):
			_look_from_the_seat(kind, name, KINDS[name])
	_finish()


func _look_from_the_seat(kind: int, name: String, rules: Dictionary) -> void:
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.setup(0, kind)
	view.man([0], 0)
	var found: Array = view.find_children("*", "WarbirdAirframe", true, false)
	if found.is_empty():
		_check("%s_is_drawn_by_its_warbird_airframe" % name, false, "no WarbirdAirframe in its view")
		view.queue_free()
		return
	var airframe: WarbirdAirframe = found[0]
	var eye: Vector3 = view.seat_anchor(0).position + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
	var drawn_eye: Vector3 = (view.global_transform.affine_inverse() * airframe.global_transform) * airframe.eye()
	_check("%s_the_seat_puts_the_eye_where_the_airframe_draws_it" % name, eye.distance_to(drawn_eye) < 0.02,
		"the seat's eye %s, the drawn %s, %.3f m apart" % [eye.snapped(Vector3.ONE * 0.001),
			drawn_eye.snapped(Vector3.ONE * 0.001), eye.distance_to(drawn_eye)])

	# OVER THE NOSE, past the cockpit.
	var blocked: PackedStringArray = []
	var open: int = 0
	for step in range(1, 13):
		var down: float = 1.0 * step
		for yaw in [-20.0, -15.0, -10.0, -5.0, 0.0, 5.0, 10.0, 15.0, 20.0]:
			var along: Vector3 = (Vector3.FORWARD.rotated(Vector3.RIGHT, -deg_to_rad(down))).rotated(Vector3.UP,
				deg_to_rad(yaw))
			var glass_alone: String = _first_hit_in(view, eye, along, airframe)
			if glass_alone != "Fuselage/1" and glass_alone != "nothing":
				continue
			open += 1
			var with_cockpit: String = _first_hit_in(view, eye, along, null)
			if with_cockpit != "Fuselage/1" and with_cockpit != "nothing":
				blocked.append("%.0f down %+.0f: %s" % [down, yaw, with_cockpit])
	_check("%s_the_pilot_sees_over_the_nose_past_the_cockpit" % name,
		blocked.is_empty() and open >= int(rules["open_least"]),
		"%d rays the glass leaves open from the eye, %s" % [open, "every one still open with the cockpit in"
			if blocked.is_empty() else "blocked by the cockpit: " + ", ".join(blocked.slice(0, 6))])

	# THE SCREENS.
	var hidden: PackedStringArray = []
	var screens: int = 0
	var anchor: Node3D = view.seat_anchor(0)
	for panel in anchor.find_children("*", "TouchPanel", true, false):
		var screen := panel as TouchPanel
		screens += 1
		var own: Dictionary = {}
		for mesh in screen.find_children("*", "MeshInstance3D", true, false):
			own[String(mesh.name)] = true
		var into: Transform3D = view.global_transform.affine_inverse() * screen.global_transform
		var turned: float = rad_to_deg(acos(clampf(into.basis.z.normalized().dot((eye - into.origin).normalized()), -1.0, 1.0)))
		if turned > 60.0:
			hidden.append("%s turned %.0f degrees from the eye" % [screen.get_parent().name, turned])
		for corner in [Vector2.ZERO, Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(-0.4, 0.4), Vector2(0.4, 0.4)]:
			var at: Vector3 = into * Vector3(corner.x * screen.size.x, corner.y * screen.size.y, 0.0)
			var hit: String = _first_hit_in(view, eye, (at - eye).normalized(), null)
			if not own.has(hit.get_slice("/", hit.get_slice_count("/") - 2)):
				hidden.append("%s at %s: %s" % [screen.get_parent().name, corner, hit])
	_check("%s_and_sees_the_face_of_every_screen_in_the_station" % name, hidden.is_empty() and screens >= 1,
		"%d screens, %s" % [screens, "every one on its glass, facing the eye" if hidden.is_empty()
			else "hidden: " + ", ".join(hidden.slice(0, 6))])

	# BELOW THE GLASS, THE COAMING AND NOT THE HOLLOW NOSE.
	var into_nose: PackedStringArray = []
	var cockpit: Dictionary = {}
	for mesh in anchor.find_children("*", "MeshInstance3D", true, false):
		cockpit[String(mesh.name) if not String(mesh.name).begins_with("@") else String(view.get_path_to(mesh))] = true
	for step in range(0, 11):
		for yaw in [-15.0, -10.0, -5.0, 0.0, 5.0, 10.0, 15.0]:
			var ray: Vector3 = (Vector3.FORWARD.rotated(Vector3.RIGHT, -deg_to_rad(5.0 * step))).rotated(Vector3.UP,
				deg_to_rad(yaw))
			var met: String = _first_hit_in(view, eye, ray, null)
			var fine: bool = met == "Fuselage/1" or met == "nothing" or met.begins_with("Coaming/")
			if fine or cockpit.has(met.substr(0, met.rfind("/"))):
				continue
			into_nose.append("%d down %+.0f: %s" % [5 * step, yaw, met])
	_check("%s_and_sees_the_coaming_and_not_into_the_nose" % name, into_nose.is_empty(),
		"77 rays from the eye, %s" % ["every one on the glass, the coaming or the cockpit" if into_nose.is_empty()
			else "into the nose: " + ", ".join(into_nose.slice(0, 8))])

	# EVERY CONTROL AND SCREEN INSIDE THE SKIN AND SEEN AGAINST IT.
	var tris: Array = _skin(airframe)
	var into_frame: Transform3D = airframe.global_transform.affine_inverse()
	var out_of_skin: PackedStringArray = []
	var fitted: int = 0
	for thing in anchor.find_children("*", "", true, false):
		var at: Vector3
		if thing is VehicleControl:
			at = (thing as VehicleControl).global_transform * (thing as VehicleControl)._grab_point()
		elif thing is TouchPanel:
			at = (thing as Node3D).global_position
		else:
			continue
		fitted += 1
		var local: Vector3 = into_frame * at + Vector3(0.0007, 0.0, 0.0007)
		var eye_in_frame: Vector3 = into_frame * (view.global_transform * eye)
		var behind: String = _first_hit(airframe, local, (local - eye_in_frame).normalized())
		var inside: bool = _inside_of(tris, local)
		if not inside or behind == "Fuselage/1" or behind == "nothing":
			var from_eye: Vector3 = (view.global_transform.affine_inverse() * at) - eye
			out_of_skin.append("%s %s from the eye, %s, seen against %s" % [thing.name,
				from_eye.snapped(Vector3.ONE * 0.01), "inside" if inside else "OUTSIDE the skin", behind])
	_check("%s_and_every_control_and_screen_he_reaches_is_inside_the_canopy" % name,
		out_of_skin.is_empty() and fitted >= 6,
		"%d controls and screens, %s" % [fitted, "every one inside the drawn skin and seen against it"
			if out_of_skin.is_empty() else "wrong: " + ", ".join(out_of_skin)])

	# THE ROOM.
	var room: AABB = airframe.cabin_room()["room"]
	_check("%s_the_room_it_promises_is_inside_the_drawn_skin" % name, airframe.encloses(room),
		"the room %s, craft-local" % [room])
	view.queue_free()


## The first mesh and surface a ray meets among everything a view draws (or only what `within` draws), as "Name/surface",
## in the view's frame. `tests/warthog.gd`'s.
func _first_hit_in(view: Node3D, from: Vector3, direction: Vector3, within: Node) -> String:
	var best: float = INF
	var name_of: String = "nothing"
	for node in (within if within != null else view).find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var into := view.global_transform.affine_inverse() * mesh.global_transform
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var pts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count: int = index.size() if not index.is_empty() else pts.size()
			for i in range(0, count - 2, 3):
				var a: Vector3 = into * pts[index[i] if not index.is_empty() else i]
				var b: Vector3 = into * pts[index[i + 1] if not index.is_empty() else i + 1]
				var c: Vector3 = into * pts[index[i + 2] if not index.is_empty() else i + 2]
				var hit = Geometry3D.ray_intersects_triangle(from, direction, a, b, c)
				if hit != null and ((hit as Vector3) - from).length() < best:
					best = ((hit as Vector3) - from).length()
					var hung: String = String(mesh.name) if not String(mesh.name).begins_with("@") else String(view.get_path_to(mesh))
					name_of = "%s/%d" % [hung, surface]
	return name_of


## The first mesh and surface a ray meets in the airframe's own frame, as "Name/surface".
func _first_hit(frame: Node3D, from: Vector3, direction: Vector3) -> String:
	var best: float = INF
	var name_of: String = "nothing"
	for node in frame.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var into := frame.global_transform.affine_inverse() * mesh.global_transform
		for surface in range(mesh.mesh.get_surface_count()):
			var pts: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for i in range(0, pts.size() - 2, 3):
				var hit = Geometry3D.ray_intersects_triangle(from, direction, into * pts[i], into * pts[i + 1], into * pts[i + 2])
				if hit != null and ((hit as Vector3) - from).length() < best:
					best = ((hit as Vector3) - from).length()
					name_of = "%s/%d" % [mesh.name, surface]
	return name_of


## Every exterior triangle a ray can meet for the inside test: the fuselage, whose second surface is the canopy.
func _skin(frame: Node3D) -> Array:
	var tris: Array = []
	var mesh := frame.find_child("Fuselage", true, false) as MeshInstance3D
	var into := frame.global_transform.affine_inverse() * mesh.global_transform
	for surface in range(mesh.mesh.get_surface_count()):
		var pts: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for i in range(0, pts.size() - 2, 3):
			tris.append([into * pts[i], into * pts[i + 1], into * pts[i + 2]])
	return tris


static func _inside_of(tris: Array, p: Vector3) -> bool:
	var up: int = 0
	var down: int = 0
	for t in tris:
		if Geometry3D.ray_intersects_triangle(p, Vector3.UP, t[0], t[1], t[2]) != null:
			up += 1
		if Geometry3D.ray_intersects_triangle(p, Vector3.DOWN, t[0], t[1], t[2]) != null:
			down += 1
	return up % 2 == 1 and down % 2 == 1


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[warbird_cockpit] %s %s (%s)" % ["PASS" if ok else "FAIL", name, detail])


func _finish() -> void:
	print("[warbird_cockpit] %d passed, %d failed" % [_passed, _failed])
	print("RESULT=%s" % ("PASS" if _failed == 0 else "FAIL"))
	get_tree().quit(0 if _failed == 0 else 1)
