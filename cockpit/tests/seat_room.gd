extends Node
## Headless: IS THERE ROOM FOR A PERSON IN EVERY SEAT OF EVERY CRAFT?
##
##   Godot --headless --path cockpit res://tests/seat_room.tscn
##
## `shell_room` ANSWERS "IS THE SEAT INSIDE THE DRAWN CABIN". THIS ANSWERS "IS THERE ROOM FOR SOMEBODY IN IT", and the
## two are different questions: a seat can be perfectly inside a cabin whose roof is a hand's breadth over the eye. The
## user's own worry, 2026-09-17: the Cessna "might be too small to house two players". Nothing measured it.
##
## A REPORT, NOT A GATE. Every seat that is short of the envelope below is printed with the shortfall in metres and the
## part it ran into, on every run, and the suite still passes -- like `shell_room`'s OPEN list, because a permanently red
## suite teaches everybody that red is normal. It FAILS only when it did not measure what it says it measured: a craft
## scene it could not build, a craft with no seat, or a craft whose rays met no drawn triangle at all. Each of those is
## a report that has quietly gone vacuous, which is the one thing a report must never do.
##
## THE ENVELOPE, in the seat anchor's own frame (-Z forward, +X right, origin the play-space floor the tracker stands the
## eye `CockpitStation.EYE_HEIGHT` above). The game's own numbers are used where the game has them -- eye height,
## shoulder height, shoulder spacing -- because the rig puts the player THERE whatever a tape measure says. The rest are
## ANSUR II (US Army anthropometric survey, 2012) 95th-percentile men, rounded, plus the room a head in a headset moves
## through seated. Each one is a CLEARANCE: the distance a ray from that body point travels before it meets anything the
## craft draws.
##
##   head up     eye -> +Y    0.25  crown 0.13 above the eye (sitting height 0.97 less sitting eye height 0.85 at the
##                                  95th) + 0.02 of headset strap + 0.10 of a seated head bobbing and looking up.
##   head side   eye -> +/-X  0.20  half a headset's width (0.19 wide) + 0.10 of a head turning and leaning to look out.
##   head fore   eye -> -Z    0.30  a headset's depth ahead of the eyes (0.08) + a lean to read an instrument (0.20).
##   shoulders   (0, EYE - NECK, 0) -> +/-X   0.30  bideltoid breadth 0.53 at the 95th, halved, + 0.035 of elbow.
##   knees       (0, 0.55, 0) -> -Z  0.55  knee height seated ~0.60 over the floor; buttock-knee 0.66 less the hips
##                                  sitting ~0.10 behind the eye line -- the kneecap is ~0.55 ahead of the anchor.
##   neighbour   shoulder middle to the next seat's  0.53  one full bideltoid breadth: two players side by side
##                                  closer than this are wearing each other's arms.
##
## REACH IS NOT HERE: `tests/fit.gd` holds every grip to `CockpitStation.EASY_REACH` already, from the same shoulders.
##
## A RAY THAT MEETS NOTHING WITHIN `FAR` IS OPEN, and open is room: a gun tub, an open bridge, a tank commander's hatch.
## Whether an open seat is also OUTSIDE its craft is `shell_room`'s question and not re-asked here.
##
## WHAT THE RAYS MAY HIT is every visible mesh the craft draws, minus the stations (the station is built round the
## envelope, so it cannot be the datum -- see `shell_room`'s doc block for that trap), minus the controls the craft hangs
## off itself (grab targets, measured by `fit`), minus anything drawn only from far away (`ShipHull`'s `Far`). Measured
## from the drawn triangles in the craft's own frame, never `transform * get_aabb()`, and built with `_show_in_editor()`,
## the painted outside view -- never `_show_body(true)`, which ghosts the airframe.
##
## Read RESULT=, not the exit code.

const HEAD_UP: float = 0.25
const HEAD_SIDE: float = 0.20
const HEAD_FORE: float = 0.30
const SHOULDER: float = 0.30
const KNEE_HEIGHT: float = 0.55
const KNEE_FORE: float = 0.55
const NEIGHBOUR: float = 0.53
## How far a ray looks, in metres. Beyond this the seat is open on that side.
const FAR: float = 4.0
## Moved off the exact axis so a ray does not run down a vertex or an edge on the centreline -- see `shell_room.NUDGE`.
const NUDGE: float = 0.0007
## A BODY PART IS A VOLUME, NOT A POINT. Each clearance is the least of five parallel rays: the point itself and four
## offset this far either way across the ray. Measured on the first run (2026-09-17): single rays from the eye went
## straight out of the airliner's and the plane's side windows -- a head beside a window opening reads as "open" when
## the glass is 3 cm away. A fan at 0.08 m is a head's half-breadth, and a window narrower than that stops it.
const FAN: float = 0.08

var _failures: PackedStringArray = []
var _tight: PackedStringArray = []
var _seats_seen: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[seat_room] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	CockpitStation.use_saved_layouts = false
	var only: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):
			only = arg.trim_prefix("--kind=")
	var craft: PackedStringArray = _craft_names()
	var measured: PackedStringArray = []
	var blind: PackedStringArray = []
	var seatless: PackedStringArray = []
	for name in craft:
		if not only.is_empty() and name != only:
			continue
		var result: String = _measure(name)
		match result:
			"ok": measured.append(name)
			"blind": blind.append(name)
			"seatless": seatless.append(name)
			_: blind.append("%s (%s)" % [name, result])
	print("[seat_room] ---- seats short of the envelope, worst first ----")
	_tight.sort()
	_tight.reverse()
	for line in _tight:
		print("[seat_room]   " + line)
	_check("every_craft_scene_was_built_and_measured",
		blind.is_empty() and seatless.is_empty() and not measured.is_empty(),
		"%d craft, %d seats, %d clearances short of the envelope (a report, not a failure)"
			% [measured.size(), _seats_seen, _tight.size()] if blind.is_empty() and seatless.is_empty()
			else "met no drawn triangle: [%s]; no seat: [%s]" % [", ".join(blind), ", ".join(seatless)])
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _craft_names() -> PackedStringArray:
	var names: PackedStringArray = []
	var dir := DirAccess.open("res://objects/vehicles")
	if dir == null:
		return names
	for file in dir.get_files():
		if file.begins_with("craft_") and file.ends_with(".tscn"):
			names.append(file.trim_prefix("craft_").trim_suffix(".tscn"))
	names.sort()
	return names


## ONE CRAFT: every seat's envelope, and every pair of seats against each other.
func _measure(name: String) -> String:
	var scene := load("res://objects/vehicles/craft_%s.tscn" % name) as PackedScene
	var view := scene.instantiate() as VehicleView if scene != null else null
	if view == null:
		return "no scene"
	add_child(view)
	view._show_in_editor()
	var into: Transform3D = view.global_transform.affine_inverse()
	var solids: Array = _solids(view, into)
	if view.seats.is_empty():
		view.queue_free()
		return "seatless"
	var hits: int = 0
	var shoulders: Array = []
	for seat in range(view.seats.size()):
		_seats_seen += 1
		var frame: Transform3D = into * view.seat_anchor(seat).global_transform
		var eye := Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
		var shoulder := Vector3(0.0, CockpitStation.EYE_HEIGHT - CockpitStation.NECK, 0.0)
		var knee := Vector3(0.0, KNEE_HEIGHT, 0.0)
		var rays: Array = [
			["head_up", eye, Vector3.UP, HEAD_UP],
			["head_left", eye, Vector3.LEFT, HEAD_SIDE],
			["head_right", eye, Vector3.RIGHT, HEAD_SIDE],
			["head_fore", eye, Vector3.FORWARD, HEAD_FORE],
			["shoulder_left", shoulder, Vector3.LEFT, SHOULDER],
			["shoulder_right", shoulder, Vector3.RIGHT, SHOULDER],
			["knees", knee, Vector3.FORWARD, KNEE_FORE],
			# NO REQUIREMENT, AND THE EVIDENCE THE RAYS REACHED THE CRAFT: what is under the seat. A seat with nothing
			# under it within FAR is standing in the air, and every seat in the game is expected to have a floor.
			["floor", Vector3(0.0, 0.30, 0.0), Vector3.DOWN, 0.0],
		]
		var line: PackedStringArray = []
		for ray in rays:
			var from: Vector3 = frame * (ray[1] as Vector3)
			var along: Vector3 = (frame.basis * (ray[2] as Vector3)).normalized()
			var hit: Array = _fan(solids, frame, from, along)
			var gap: float = float(hit[0])
			var part: String = String(hit[1])
			var need: float = float(ray[3])
			if gap < FAR:
				hits += 1
			line.append("%s %s" % [ray[0], "open" if gap >= FAR else "%.2f(%s)" % [gap, part]])
			if gap < need:
				_tight.append("%5.2f short  %-10s seat %d  %-14s %.2f of %.2f, into %s"
					% [need - gap, name, seat, ray[0], gap, need, part])
		var at: Vector3 = frame * eye
		print("[seat_room] %-10s seat %d  eye (%.2f, %.2f, %.2f)  %s" % [name, seat, at.x, at.y, at.z, "  ".join(line)])
		shoulders.append(frame * shoulder)
	_and_at_the_airframes_own_eyes(name, view, solids)
	var room: Dictionary = view.cabin_room()
	if bool(room.get("drawn", false)):
		var box: AABB = room["room"]
		var eye_y: float = (into * view.seat_anchor(0).global_transform * Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)).y
		print("[seat_room] %-10s cabin_room %.2f wide x %.2f high x %.2f long, roof %.2f over seat 0's eye (%s)"
			% [name, box.size.x, box.size.y, box.size.z, box.end.y - eye_y, room.get("source", "")])
	for a in range(shoulders.size()):
		for b in range(a + 1, shoulders.size()):
			var apart: float = (shoulders[a] as Vector3).distance_to(shoulders[b] as Vector3)
			if apart < NEIGHBOUR:
				_tight.append("%5.2f short  %-10s seat %d  neighbour      %.2f of %.2f, from seat %d's shoulders"
					% [NEIGHBOUR - apart, name, a, apart, NEIGHBOUR, b])
	view.queue_free()
	return "ok" if hits > 0 or _all_open_is_honest(name) else "blind"


## AND AT THE EYES THE AIRFRAME WAS DRAWN ROUND, where it publishes them. The Cessna's seat poses are still the rear
## seats' (see `SkyhawkAirframe.cabin_room`), so its seats measure a place nobody should sit; an airframe that names its
## reference eyes (`EYE_STATION`, `EYE_HEIGHT`, `EYE_OUT` and `station()`/`height()` into the craft's frame) is also
## measured THERE, with the same envelope hung off that eye -- which says whether moving the seats is enough or the cabin
## itself has to grow. Printed, not added to the shortfall list: nobody sits there yet.
func _and_at_the_airframes_own_eyes(name: String, view: VehicleView, solids: Array) -> void:
	var air: Node3D = view.get("_visual_scene") as Node3D
	if air == null or air.get_script() == null:
		return
	var consts: Dictionary = (air.get_script() as Script).get_script_constant_map()
	if not (consts.has("EYE_STATION") and consts.has("EYE_HEIGHT") and consts.has("EYE_OUT")) or not air.has_method("height") or not air.has_method("station"):
		return
	var eye_y: float = float(air.call("height", float(consts["EYE_HEIGHT"])))
	var eye_z: float = float(air.call("station", float(consts["EYE_STATION"])))
	var frame := Transform3D.IDENTITY
	for side in [-1.0, 1.0]:
		var eye := Vector3(side * float(consts["EYE_OUT"]), eye_y, eye_z)
		var line: PackedStringArray = []
		for ray in [["head_up", eye, Vector3.UP, HEAD_UP], ["head_out", eye, Vector3(side, 0, 0), HEAD_SIDE],
				["head_fore", eye, Vector3.FORWARD, HEAD_FORE],
				["shoulder_out", eye + Vector3(0, -CockpitStation.NECK, 0), Vector3(side, 0, 0), SHOULDER]]:
			var hit: Array = _fan(solids, frame, ray[1] as Vector3, ray[2] as Vector3)
			var gap: float = float(hit[0])
			line.append("%s %s%s" % [ray[0], "open" if gap >= FAR else "%.2f(%s)" % [gap, hit[1]],
				"" if gap >= float(ray[3]) else " SHORT %.2f" % (float(ray[3]) - gap)])
		print("[seat_room] %-10s reference eye %s (%.2f, %.2f, %.2f)  %s" % [name,
			"port" if side < 0.0 else "starboard", eye.x, eye.y, eye.z, "  ".join(line)])


## A CRAFT WHOSE EVERY RAY IS OPEN IS SUSPECT: it more likely means the drawing was not gathered than that the crew
## sit in empty air. None is expected; one appearing is a failure until somebody reads it and names it here.
func _all_open_is_honest(_name: String) -> bool:
	return false


## EVERY DRAWN PART, as triangles in the craft's frame, with a box to reject rays early.
func _solids(view: VehicleView, into: Transform3D) -> Array:
	var solids: Array = []
	var stack: Array[Node] = [view]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CockpitStation or node is VehicleControl:
			continue
		for child in node.get_children():
			stack.append(child)
		if not (node is MeshInstance3D):
			continue
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree() or mesh.visibility_range_begin > 0.0:
			continue
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		if faces.is_empty():
			continue
		var frame: Transform3D = into * mesh.global_transform
		var points := PackedVector3Array()
		points.resize(faces.size())
		var box := AABB(frame * faces[0], Vector3.ZERO)
		for i in faces.size():
			points[i] = frame * faces[i]
			box = box.expand(points[i])
		solids.append({"faces": points, "box": box.grow(0.01), "name": String(mesh.name)})
	return solids


## THE LEAST OF FIVE PARALLEL RAYS, the fan across the ray's direction in the seat's own frame. See `FAN`.
func _fan(solids: Array, frame: Transform3D, from: Vector3, along: Vector3) -> Array:
	var across: Vector3 = Vector3.UP if absf(along.dot(frame.basis.y.normalized())) < 0.9 else frame.basis.x.normalized()
	var other: Vector3 = along.cross(across).normalized()
	var best: Array = _cast(solids, from, along)
	for offset in [across * FAN, -across * FAN, other * FAN, -other * FAN]:
		var hit: Array = _cast(solids, from + offset, along)
		if float(hit[0]) < float(best[0]):
			best = hit
	return best


## THE NEAREST DRAWN TRIANGLE ALONG A RAY: [distance, part name], or [FAR, ""].
func _cast(solids: Array, at: Vector3, along: Vector3) -> Array:
	var from := at + Vector3(NUDGE, NUDGE * 0.5, NUDGE)
	var to := from + along * FAR
	var best: float = FAR
	var what: String = ""
	for solid in solids:
		if (solid["box"] as AABB).intersects_segment(from, to) == null \
				and not (solid["box"] as AABB).has_point(from):
			continue
		var faces: PackedVector3Array = solid["faces"]
		for i in range(0, faces.size() - 2, 3):
			var t: float = _hit(faces[i], faces[i + 1], faces[i + 2], from, along)
			if t > 0.0 and t < best:
				best = t
				what = String(solid["name"])
	return [best, what]


## Moller-Trumbore, both faces: a lining is drawn to be seen from inside and a skin from outside, and a head meets
## either.
func _hit(a: Vector3, b: Vector3, c: Vector3, from: Vector3, along: Vector3) -> float:
	var e1: Vector3 = b - a
	var e2: Vector3 = c - a
	var p: Vector3 = along.cross(e2)
	var det: float = e1.dot(p)
	if absf(det) < 1e-12:
		return -1.0
	var inv: float = 1.0 / det
	var s: Vector3 = from - a
	var u: float = s.dot(p) * inv
	if u < 0.0 or u > 1.0:
		return -1.0
	var q: Vector3 = s.cross(e1)
	var v: float = along.dot(q) * inv
	if v < 0.0 or u + v > 1.0:
		return -1.0
	return e2.dot(q) * inv
