extends Node
## Headless: THE PILOT'S CHAIR -- every preset of `PilotSeat` builds its parts inside its budget, has no armrests,
## leans back by what its source says, keeps its headbox behind the head, and leaves the body envelope clear.
##
##   Godot --headless --path cockpit res://tests/pilot_seat.tscn
##
## MEASURED OFF THE DRAWN TRIANGLES, never off the parameters: the recline is the angle of the back cushion's front face
## worked out from its three corners, so a preset whose recline was typed wrong, or a builder that ignored it, goes red.
## The reference angles below are the SOURCES' figures, typed here on purpose, apart from `PilotSeat.PRESETS` -- a check
## that read the table it is checking would be the table agreeing with itself.
##
## THE BODY ENVELOPE IS `seat_room`'s, not a copy of it: this suite loads `tests/seat_room.gd` and fires ITS rays with
## ITS clearances, against the chair's triangles alone. So if the envelope grows, the chair is held to the new one.
##
## IN THE CRAFT (step 2, 2026-09-18): every craft scene whose `VehicleCatalogue` entry names a chair is built as the
## game builds it, every seat manned, and each chair on each seat anchor is held to two things, both off drawn
## triangles:
##   - UNDER THE SKIN: from every vertex of the chair a ray up, down, to port and to starboard each meets the craft's
##     own drawing within `COVER` -- the canopy over it, the tub under it and the sides beside it. The F/A-18's canopy
##     is an open shell (`shell_room`'s OPEN list), so containment by parity cannot be asked; four covered sides can.
##   - HIDING NOTHING: from the seat's eye, the straight line to the middle of every part the station draws -- the
##     pedals, the stick, the throttle, every display -- and the level and chin sight lines ahead are not crossed by the
##     chair before they arrive. The pedals are the one it caught: see `PilotSeat`'s pan depths.
##
## MUTANTS (run 2026-09-18; each applied, each red here):
##   armrests added to every preset .............................. no_armrests
##   aces2_f16 typed with a recline of 0 ......................... the_recline_is_the_sources
##   head_gap negative, the headbox in front of the eye .......... the_headbox_is_behind_the_head
##   the craft's headroom ignored (the headbox out through the canopy) the_fitted_chairs_are_under_the_skin
##   the Mk 14's pan back to 0.42 m deep ......................... the_fitted_chairs_hide_nothing_from_the_eye
##   the Little Bird's chairs on the anchor, not its raised floor . the_fitted_chairs_are_under_the_skin
##   a helicopter seat's back as wide as its bucket (the collective) the_fitted_chairs_hide_nothing_from_the_eye
##
## Read RESULT=, not the exit code.

## THE SOURCES' RECLINE, degrees aft of vertical. [W16]/[WA2]/[WMB]/[WUH] as in `PilotSeat`'s doc block.
const SOURCE_RECLINE: Dictionary = {
	"aces2_f16": 30.0,       # F-16: "reclined at an unusual tilt-back angle of 30 degrees" [W16]
	"aces2": 13.0,           # F-15: "most fighters have a tilted seat at 13-15 degrees" [W16], the low end
	"mk14": 14.0,            # F-14D, F/A-18: the same 13-15 [W16], the middle
	"us16e": 18.0,           # F-35: ESTIMATE between the Mk 14's and the F-16's, from photographs (PilotSeat [WMB2])
	"heli_armoured": 10.0,   # "very upright", 5-15 degrees (the brief) -- ESTIMATE
	"light": 12.0,           # ESTIMATE
	"transport": 12.0,       # ESTIMATE
	"sailplane": 45.0,       # a modern glider's seat back, drawn at 45 degrees in Technical Soaring 19/2 p52 [TS19]
}
## "A couple of degrees".
const RECLINE_TOLERANCE: float = 2.0
## WHERE AN ARMREST WOULD BE: an upward face at seated elbow height, outboard of a torso, ahead of the back. A seated
## elbow rests 0.18 to 0.30 m over the pan (ANSUR II). MEASURED OVER EACH PRESET'S OWN PAN: this was 0.54 to 0.80 m over
## the anchor while every pan was 0.36 to 0.45 there, and the sailplane's pan at 0.75 (2026-09-18) read as ten armrest
## faces -- the pan itself. The band over a 0.45 m pan is the old one.
const ELBOW_LOW: float = 0.09
const ELBOW_HIGH: float = 0.35
const TORSO_HALF: float = 0.12
## THE BACK OF A HEAD, behind the eye: a head is about 0.20 m long with the eye 0.02 in from the front; a helmet adds
## a little. Nothing of a headbox may come nearer the eye than this, measured along the view.
const HEAD_BACK: float = 0.12
## HOW FAR A RAY FROM A CHAIR'S VERTEX MAY GO BEFORE IT MUST MEET THE CRAFT: a cockpit is under a metre and a half
## across and a little under two tall -- the F/A-18's front seat is 1.65 m from the top of its headbox to the belly --
## so a side of the chair that meets nothing in 2.2 m is out in the air.
const COVER: float = 2.2
## THE SIGHT LINES AHEAD, degrees below the level: the level view and the chin view a pilot flies by.
const LOOKS_DOWN: Array[float] = [0.0, -15.0, -30.0]
const LOOKS_ACROSS: Array[float] = [-30.0, 0.0, 30.0]
## CRAFT THAT FLY WITH A SIDE OPEN, where a ray from a chair OUT through the doorway meets nothing and that is right:
## their chairs are held up and down only -- INBOARD TOO WAS TRIED, and a ray from the starboard pilot's chair runs
## across the cabin and out of the port doorway, measured 2026-09-18. Named with the reason, as `shell_room`'s
## OPEN list is.
const OPEN_SIDED: Dictionary = {
	"littlebird": "the MH-6M flies doors off, both sides; across the cabin and out through a doorway is sky",
}

var _failures: PackedStringArray = []


## Whether `drawn` hangs under a `top_level` node inside `station`: a sight that follows the eye, not the seat.
static func _on_the_helmet(drawn: Node, station: Node) -> bool:
	var at: Node = drawn
	while at != null and at != station:
		if at is Node3D and (at as Node3D).top_level:
			return true
		at = at.get_parent()
	return false


func _check(label: String, ok: bool, detail: String) -> void:
	print("[pilot_seat] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var seats: Dictionary = {}
	for name in PilotSeat.PRESETS:
		seats[name] = PilotSeat.of(String(name))
	_every_preset_builds_its_parts_within_budget(seats)
	_no_armrests(seats)
	_the_recline_is_the_sources(seats)
	_the_headbox_is_behind_the_head(seats)
	_the_body_envelope_is_clear(seats)
	for seat in seats.values():
		(seat as Node).free()
	_in_every_craft_that_names_one()
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)


## EVERY PRESET IS ONE SURFACE, WITH THE PARTS ITS KIND OF SEAT HAS, INSIDE THE BUDGET.
func _every_preset_builds_its_parts_within_budget(seats: Dictionary) -> void:
	var bad: PackedStringArray = []
	var counts: PackedStringArray = []
	for name in seats:
		var seat: MeshInstance3D = seats[name]
		var parts: Dictionary = seat.get_meta("parts", {})
		var p: Dictionary = PilotSeat.preset(String(name))
		var wanted: PackedStringArray = ["back", "shell", "pan", "bucket"]
		if String(p["headbox"]) != "none":
			wanted.append("headbox")
		if bool(p["rails"]):
			wanted.append("rails")
		if bool(p["side_armour"]):
			wanted.append("armour")
		if String(p["handle"]) != "none":
			wanted.append("handle")
		if bool(p["harness"]):
			wanted.append("harness")
		wanted.append("tracks" if bool(p["tracks"]) else "survival_kit" if bool(p["survival_kit"]) else "pedestal")
		var missing: PackedStringArray = []
		for part in wanted:
			if not parts.has(part) or int((parts[part] as Array)[1]) == 0:
				missing.append(part)
		var triangles: int = seat.mesh.surface_get_array_len(0) / 3 if seat.mesh != null else 0
		counts.append("%s %d" % [name, triangles])
		if not missing.is_empty() or triangles > PilotSeat.BUDGET or seat.mesh.get_surface_count() != 1:
			bad.append("%s: missing [%s], %d triangles, %d surfaces" % [name, ", ".join(missing), triangles,
				seat.mesh.get_surface_count()])
	_check("every_preset_builds_its_parts_within_budget", bad.is_empty() and seats.size() == SOURCE_RECLINE.size(),
		"%d presets, one surface each, at most %d triangles: %s" % [seats.size(), PilotSeat.BUDGET, ", ".join(counts)]
			if bad.is_empty() else "; ".join(bad))


## NO ARMRESTS: no face looking up at elbow height, outboard of the torso, ahead of the eye line.
func _no_armrests(seats: Dictionary) -> void:
	var bad: PackedStringArray = []
	for name in seats:
		var points: PackedVector3Array = (seats[name] as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var pan: float = float(PilotSeat.preset(String(name))["pan_height"])
		var found: int = 0
		for i in range(0, points.size() - 2, 3):
			var a: Vector3 = points[i]
			var b: Vector3 = points[i + 1]
			var c: Vector3 = points[i + 2]
			var normal: Vector3 = (b - a).cross(c - a)
			if normal.length_squared() < 1e-12:
				continue
			var centre: Vector3 = (a + b + c) / 3.0
			if absf(normal.normalized().y) > 0.7 and centre.y > pan + ELBOW_LOW and centre.y < pan + ELBOW_HIGH \
					and absf(centre.x) > TORSO_HALF and centre.z < 0.0:
				found += 1
		if found > 0:
			bad.append("%s: %d faces" % [name, found])
	_check("no_armrests", bad.is_empty(),
		"no preset has a level face %.2f to %.2f m over its pan, more than %.2f m out, ahead of the eye line" % [ELBOW_LOW,
			ELBOW_HIGH, TORSO_HALF] if bad.is_empty() else "armrest-like faces: " + "; ".join(bad))


## THE RECLINE, measured off the back cushion's forward face and held to the SOURCE's figure.
func _the_recline_is_the_sources(seats: Dictionary) -> void:
	var bad: PackedStringArray = []
	var read: PackedStringArray = []
	for name in seats:
		var back: PackedVector3Array = PilotSeat.part_triangles(seats[name], "back")
		var best := Vector3.ZERO
		var biggest: float = 0.0
		for i in range(0, back.size() - 2, 3):
			var normal: Vector3 = (back[i + 1] - back[i]).cross(back[i + 2] - back[i])
			if normal.length_squared() < 1e-12:
				continue
			var area: float = normal.length()
			normal = normal.normalized()
			# The cushion is a closed box, and its FACE is its largest pair of sides. Picking the face whose normal points
			# furthest ahead read the sailplane's 45 degrees as -45 (2026-09-18): at 45 the cushion's top points ahead
			# exactly as far as its face does.
			if normal.z > 0.0:
				normal = -normal
			if normal.z < -0.05 and area > biggest + 1e-6:
				biggest = area
				best = normal
		var lean: float = rad_to_deg(atan2(best.y, -best.z))
		var want: float = float(SOURCE_RECLINE.get(name, -99.0))
		read.append("%s %.1f/%.0f" % [name, lean, want])
		if absf(lean - want) > RECLINE_TOLERANCE:
			bad.append("%s leans %.1f deg, the source says %.0f" % [name, lean, want])
	_check("the_recline_is_the_sources", bad.is_empty(),
		"measured/source: " + ", ".join(read) if bad.is_empty() else "; ".join(bad))


## THE HEADBOX IS BEHIND THE HEAD: every vertex of it further aft of the eye than the back of a head.
func _the_headbox_is_behind_the_head(seats: Dictionary) -> void:
	var bad: PackedStringArray = []
	var read: PackedStringArray = []
	var eye_z: float = 0.0
	for name in seats:
		var head: PackedVector3Array = PilotSeat.part_triangles(seats[name], "headbox")
		if head.is_empty():
			continue
		var nearest: float = INF
		for v in head:
			nearest = minf(nearest, v.z - eye_z)
		read.append("%s %.2f" % [name, nearest])
		if nearest < HEAD_BACK:
			bad.append("%s's headbox comes to %.2f m behind the eye" % [name, nearest])
	_check("the_headbox_is_behind_the_head", bad.is_empty() and not read.is_empty(),
		"nearest headbox point behind the eye, m: " + ", ".join(read) if bad.is_empty() else "; ".join(bad))


## EVERY CRAFT THAT NAMES A CHAIR, built with every seat manned; its chairs held under the skin and hiding nothing.
func _in_every_craft_that_names_one() -> void:
	CockpitStation.use_saved_layouts = false
	var room: Node = (load("res://tests/seat_room.gd") as GDScript).new()
	var expected: int = 0
	for kind in Sim.Kind.values():
		var named: PackedStringArray = VehicleCatalogue.chairs(int(kind), 4)
		if not named[0].is_empty():
			expected += 1
	var fitted: PackedStringArray = []
	var outside: PackedStringArray = []
	var hiding: PackedStringArray = []
	var worst_cover: float = 0.0
	var sights: int = 0
	var dir := DirAccess.open("res://objects/vehicles")
	for file in dir.get_files():
		if not (file.begins_with("craft_") and file.ends_with(".tscn")):
			continue
		var view := (load("res://objects/vehicles/" + file) as PackedScene).instantiate() as VehicleView
		add_child(view)
		view._show_in_editor()
		var name: String = file.trim_prefix("craft_").trim_suffix(".tscn")
		var into: Transform3D = view.global_transform.affine_inverse()
		var every: Array = room.call("_solids", view, into)
		var craft: Array = []
		for solid in every:
			if String(solid["name"]) != "Chair":
				craft.append(solid)
		for seat in range(view.seats.size()):
			var chair := view.seats[seat].get_node_or_null("Chair") as MeshInstance3D
			if chair == null:
				continue
			fitted.append("%s/%d %s" % [name, seat, chair.get_meta("preset", "")])
			var frame: Transform3D = into * chair.global_transform
			var faces: PackedVector3Array = chair.mesh.get_faces()
			var points := PackedVector3Array()
			var box := AABB(frame * faces[0], Vector3.ZERO)
			for v in faces:
				points.append(frame * v)
				box = box.expand(frame * v)
			var mine: Array = [{"faces": points, "box": box.grow(0.01), "name": "Chair"}]
			# UNDER THE SKIN: every vertex covered on four sides by the craft's own drawing.
			var loose: int = 0
			var where := Vector3.ZERO
			var way := Vector3.ZERO
			var seen: Dictionary = {}
			for v in points:
				if seen.has(v):
					continue
				seen[v] = true
				var sides: Array = [Vector3.UP, Vector3.DOWN]
				if not OPEN_SIDED.has(name):
					sides.append_array([frame.basis.x.normalized(), -frame.basis.x.normalized()])
				for along in sides:
					var gap: float = float((room.call("_cast", craft, v, along) as Array)[0])
					if gap > COVER:
						loose += 1
						where = v
						way = along
						break
					worst_cover = maxf(worst_cover, gap)
			if loose > 0:
				var local: Vector3 = frame.affine_inverse() * where
				outside.append("%s/%d: %d vertices uncovered, e.g. (%.2f, %.2f, %.2f) in the seat's frame, open along %s"
					% [name, seat, loose, local.x, local.y, local.z, way])
			# HIDING NOTHING: every part the station draws, and the sight lines ahead.
			var anchor: Transform3D = into * view.seat_anchor(seat).global_transform
			var eye: Vector3 = anchor * Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
			var station: CockpitStation = view.station_for(seat)
			var targets: Array = []
			if station != null:
				for mesh in station.find_children("*", "MeshInstance3D", true, false):
					var drawn := mesh as MeshInstance3D
					# NOT THE FOOTWELL'S FLOOR: a chair stands on it, by design, and a pilot sees its front.
					if drawn.get_parent() is CockpitShell and drawn.name == &"Floor":
						continue
					# NOT A HELMET'S SYMBOLOGY: a `top_level` sight (the Apache's HelmetSight and helmet LockSight,
					# lane/apache steps 3-4) is placed in front of the EYE each drawn frame, wherever the head looks,
					# so where it rests in this unflown station is no place a pilot looks for it. Measured 2026-09-19:
					# apache/0 "hides LockSight/Seeker at (0.00, 1.72, 3.28)" -- behind the seat, never drawn there.
					if _on_the_helmet(drawn, station):
						continue
					if drawn.mesh != null and drawn.is_visible_in_tree():
						targets.append([String(drawn.get_parent().name) + "/" + String(drawn.name),
							into * drawn.global_transform * drawn.mesh.get_aabb().get_center()])
			for target in targets:
				var to: Vector3 = target[1]
				var reach: float = eye.distance_to(to)
				var hit: Array = room.call("_cast", mine, eye, (to - eye).normalized())
				sights += 1
				if float(hit[0]) < reach - 0.01:
					var local: Vector3 = anchor.affine_inverse() * to
					var met: Vector3 = anchor.affine_inverse() * (eye + (to - eye).normalized() * float(hit[0]))
					hiding.append("%s/%d hides %s at (%.2f, %.2f, %.2f), crossing the chair at (%.2f, %.2f, %.2f)"
						% [name, seat, target[0], local.x, local.y, local.z, met.x, met.y, met.z])
			for down in LOOKS_DOWN:
				for across in LOOKS_ACROSS:
					var look: Vector3 = anchor.basis * (Basis(Vector3.UP, deg_to_rad(across))
						* Basis(Vector3.RIGHT, deg_to_rad(down)) * Vector3.FORWARD)
					var theirs: float = float((room.call("_cast", craft, eye, look) as Array)[0])
					var ours: float = float((room.call("_cast", mine, eye, look) as Array)[0])
					sights += 1
					if ours < theirs:
						hiding.append("%s/%d is first seen %.0f down, %.0f across" % [name, seat, -down, across])
		view.queue_free()
		remove_child(view)
		view.free()
	room.free()
	_check("the_fitted_chairs_are_under_the_skin", outside.is_empty() and fitted.size() >= expected and expected > 0,
		("%d chairs in %d kinds that name one [%s], every vertex covered on four sides (up and down if open-sided)"
			+ " within %.2f m")
			% [fitted.size(), expected, ", ".join(fitted), worst_cover] if outside.is_empty()
			else "; ".join(outside))
	_check("the_fitted_chairs_hide_nothing_from_the_eye", hiding.is_empty() and sights > 0,
		"%d sight lines from the eyes, none crossed by a chair" % sights if hiding.is_empty()
			else "; ".join(hiding))


## THE BODY ENVELOPE IS CLEAR: `seat_room`'s own rays, fired against the chair alone, each travel their clearance.
func _the_body_envelope_is_clear(seats: Dictionary) -> void:
	var room: Node = (load("res://tests/seat_room.gd") as GDScript).new()
	var eye := Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
	var shoulder := Vector3(0.0, CockpitStation.EYE_HEIGHT - CockpitStation.NECK, 0.0)
	var knee := Vector3(0.0, float(room.get("KNEE_HEIGHT")), 0.0)
	var rays: Array = [
		["head_up", eye, Vector3.UP, room.get("HEAD_UP")],
		["head_left", eye, Vector3.LEFT, room.get("HEAD_SIDE")],
		["head_right", eye, Vector3.RIGHT, room.get("HEAD_SIDE")],
		["head_fore", eye, Vector3.FORWARD, room.get("HEAD_FORE")],
		["shoulder_left", shoulder, Vector3.LEFT, room.get("SHOULDER")],
		["shoulder_right", shoulder, Vector3.RIGHT, room.get("SHOULDER")],
		["knees", knee, Vector3.FORWARD, room.get("KNEE_FORE")],
	]
	var bad: PackedStringArray = []
	var knees: PackedStringArray = []
	for name in seats:
		var seat: MeshInstance3D = seats[name]
		var faces: PackedVector3Array = seat.mesh.get_faces()
		var box := AABB(faces[0], Vector3.ZERO)
		for v in faces:
			box = box.expand(v)
		var solids: Array = [{"faces": faces, "box": box.grow(0.01), "name": "PilotSeat"}]
		for ray in rays:
			var hit: Array = room.call("_fan", solids, Transform3D.IDENTITY, ray[1], ray[2])
			var gap: float = float(hit[0])
			if ray[0] == "knees":
				knees.append("%s %s" % [name, "open" if gap >= float(room.get("FAR")) else "%.2f" % gap])
			if gap < float(ray[3]):
				bad.append("%s %s %.2f of %.2f" % [name, ray[0], gap, float(ray[3])])
	room.free()
	_check("the_body_envelope_is_clear", bad.is_empty(),
		"seat_room's seven rays clear of every chair; knees: " + ", ".join(knees) if bad.is_empty()
			else "the chair is in the envelope: " + "; ".join(bad))
