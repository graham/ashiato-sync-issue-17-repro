extends Node
## Headless: DOES EVERY CREW MEMBER SEE THE FACE OF EVERY SCREEN IN THEIR OWN STATION?
##
##   Godot --headless --path cockpit res://tests/screens_face.tscn
##
## `lane/osprey` wrote this check for the V-22 alone (tests/osprey.gd, "and each sees the face of every screen in their
## station"), after copying the Little Bird's display and map into it and finding them laid FACE DOWN: `facing` +43
## degrees about x carries a panel's +z face to (0, -0.68, 0.73), 97 degrees from the eye. The Little Bird's own glass
## carried the same +43 and +52 and was reported, not changed, and nothing held any other craft. This holds all of
## them.
##
## EVERY KIND, BUILT AND MANNED AS THE GAME DOES IT (`setup`, then `man` with every seat and this machine in seat 0).
## For each seat, from its eye (`CockpitStation.EYE_HEIGHT` over the seat's anchor), for each `TouchPanel` in that
## seat's station:
##   - the glass's +z face turns at most `MOST_TURNED` degrees from the eye, and
##   - a straight line from the eye to the middle and to four points 80 per cent of the way to its corners meets
##     nothing else drawn before it reaches the glass.
## Every craft is looked at from inside, with the airframe in, because the thing that hid the V-22's first display was
## the shell's firewall bar, which a station-only check would not have seen.
##
## THE SEGMENT, NOT THE RAY, AND ONLY THROUGH MESHES ITS BOX CROSSES. osprey fired a ray through every triangle the
## craft draws, which is fine for one craft and some minutes for thirty. A blocker must lie between the eye and the
## glass, so each segment is tested only against meshes whose drawn box it crosses, and stopped a millimetre short of
## the glass. A part drawn only at a distance (`visibility_range_begin` above zero -- a ship's far silhouette) is
## never in the way of somebody sitting in it, and is left out, as tests/shell_room.gd leaves it out.
##
## Read RESULT=, not the exit code.

## HOW FAR A SCREEN MAY TURN FROM THE EYE and still be read, as in tests/osprey.gd.
const MOST_TURNED: float = 60.0

## THE SCREENS KNOWN TO BE PARTLY OR WHOLLY HIDDEN FROM THEIR OWN SEAT, "kind/seat/panel" -> what is in the way, as
## found on 2026-09-19 when this check first ran over every craft. A WORK QUEUE, NOT AN EXEMPTION: each is a bug handed
## to team-lead, and a line that stops being true fails here so it is taken out. Every one of them FACES its eye: only
## the sight line is excused, never the facing, which is what the Little Bird and the Apache got wrong.
const KNOWN: Dictionary = {
	"boat/0/MapScreen": "two corners behind the other helm seat's map glass",
	"boat/1/MapScreen": "two corners behind the other helm seat's map glass",
	"boat/2/MfdLeft": "one corner behind the boat's own near hull",
	"boat/2/MfdRight": "one corner behind the boat's own near hull",
	"boat/3/MfdLeft": "one corner behind the boat's own near hull",
	"boat/3/MfdRight": "one corner behind the boat's own near hull",
	"submarine/0/MapScreen": "two corners behind the other seat's map glass",
	"submarine/1/MapScreen": "two corners behind the other seat's map glass",
	"osprey/2/Display": "one upper corner behind the MFD beside it",
	"osprey/3/Display": "one upper corner behind the MFD beside it",
	"cessna/0/MapScreen": "wholly behind the Skyhawk's drawn airframe (looked at: pilot's-eye picture, 2026-09-19)",
	"cessna/1/MapScreen": "wholly behind the Skyhawk's drawn airframe",
	"cessna/0/Display": "two outboard corners behind the Skyhawk's drawn airframe",
	"cessna/1/Display": "two outboard corners behind the Skyhawk's drawn airframe",
	"tank/0/MapScreen": "one corner behind the turret's barrel",
	"tank/0/Display": "three points behind the turret's barrel",
	"prowler/0/MfdLeft": "one upper corner behind the Prowler's own body",
	"prowler/1/MfdLeft": "one upper corner behind the Prowler's own body",
	"prowler/2/MfdLeft": "one upper corner behind the Prowler's own body",
	"prowler/3/MfdLeft": "one upper corner behind the Prowler's own body",
}

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[screens_face] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	CockpitStation.use_saved_layouts = false
	_every_crew_member_sees_the_face_of_every_screen_in_their_station()
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _every_crew_member_sees_the_face_of_every_screen_in_their_station() -> void:
	var wrong: PackedStringArray = []
	var stale: PackedStringArray = []
	var screens: int = 0
	var segments: int = 0
	var craft: int = 0
	var known_seen: int = 0
	var refused: PackedStringArray = []
	var began: int = Time.get_ticks_msec()
	for kind in Sim.Kind.values():
		var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
		add_child(view)
		view.setup(0, kind)
		# THE STATION THE GAME BUILDS IS THE PACKAGE'S, and one whose JSON fails its manifest hash is replaced by the seat
		# scene with only a warning (`VehicleView.man`). A mutant of one and not the other would then measure the wrong
		# station here and stay green (lane/osprey), so a refused package fails this check.
		for seat in range(view.seats.size()):
			var loaded: Dictionary = AuthoredCraftPackages.read_station(kind, seat)
			if loaded.has("error"):
				refused.append("%s seat %d: %s" % [Sim.kind_name(kind), seat, loaded["error"]])
		var every: Array = []
		for seat in range(view.seats.size()):
			every.append(seat)
		view.man(every, 0)
		var solids: Array = _solids(view)
		var counted: int = screens
		for seat in range(view.seats.size()):
			var anchor: Node3D = view.seat_anchor(seat)
			var eye: Vector3 = anchor.global_transform * Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
			for found in anchor.find_children("*", "TouchPanel", true, false):
				var screen := found as TouchPanel
				if not screen.is_visible_in_tree():
					continue
				screens += 1
				var key: String = "%s/%d/%s" % [Sim.kind_name(kind), seat, _panel_name(screen, anchor)]
				var problems: PackedStringArray = []
				var glass: Transform3D = screen.global_transform
				var to_eye: Vector3 = (eye - glass.origin).normalized()
				var turned: float = rad_to_deg(acos(clampf(glass.basis.z.normalized().dot(to_eye), -1.0, 1.0)))
				if turned > MOST_TURNED:
					problems.append("turned %.0f degrees from the eye" % turned)
				var own: Dictionary = {}
				for mesh in screen.find_children("*", "MeshInstance3D", true, false):
					own[mesh] = true
				var blocked: PackedStringArray = []
				for corner in [Vector2.ZERO, Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(-0.4, 0.4), Vector2(0.4, 0.4)]:
					var at: Vector3 = glass * Vector3(corner.x * screen.size.x, corner.y * screen.size.y, 0.0)
					segments += 1
					var hit: String = _first_in_the_way(solids, own, eye, at)
					if not hit.is_empty():
						blocked.append("%s by %s" % [corner, hit])
				if not blocked.is_empty():
					problems.append("hidden at %s" % ", ".join(blocked))
				if KNOWN.has(key) and turned <= MOST_TURNED:
					known_seen += 1
					if problems.is_empty():
						stale.append("%s is listed as hidden and is in plain sight now" % key)
					continue
				if not problems.is_empty():
					wrong.append("%s %s" % [key, "; ".join(problems)])
		if screens > counted:
			craft += 1
		remove_child(view)
		view.free()
	_check("every_crew_member_sees_the_face_of_every_screen_in_their_station",
		wrong.is_empty() and stale.is_empty() and refused.is_empty() and known_seen == KNOWN.size() and screens >= 200,
		"%d screens in %d craft, %d segments, %d of %d known ones still partly hidden, %d ms: %s" % [screens, craft,
			segments, known_seen, KNOWN.size(), Time.get_ticks_msec() - began,
			"every one faces its eye, and every other is in plain sight"
				if wrong.is_empty() and stale.is_empty() and refused.is_empty()
				else "\n      " + "\n      ".join(wrong + stale + refused)])


## Which panel this is, by the station child it hangs under: "Display", "MapScreen", "Mfd0" and so on.
func _panel_name(screen: Node, anchor: Node) -> String:
	var node: Node = screen
	while node.get_parent() != null and node.get_parent().get_parent() != anchor:
		node = node.get_parent()
	return String(node.name)


## Every drawn mesh with its global box, once per craft.
func _solids(view: Node) -> Array:
	var out: Array = []
	for node in view.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree() or mesh.visibility_range_begin > 0.0:
			continue
		out.append([mesh, mesh.global_transform * mesh.get_aabb()])
	return out


## The first mesh (not one of `own`) a segment from `from` to a millimetre short of `to` passes through, by name
## and its parent's; empty if none.
func _first_in_the_way(solids: Array, own: Dictionary, from: Vector3, to: Vector3) -> String:
	var short: Vector3 = to - (to - from).normalized() * 0.001
	var best: float = INF
	var name_of: String = ""
	for pair in solids:
		var mesh := pair[0] as MeshInstance3D
		if own.has(mesh):
			continue
		var box: AABB = (pair[1] as AABB).grow(0.001)
		if not box.has_point(from) and not box.intersects_segment(from, short):
			continue
		var into: Transform3D = mesh.global_transform
		for surface in range(mesh.mesh.get_surface_count()):
			if mesh.mesh is ArrayMesh and (mesh.mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var material: Material = mesh.get_active_material(surface)
			if _see_through(material):
				continue
			var both_sides: bool = material is BaseMaterial3D 				and (material as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var pts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count: int = index.size() if not index.is_empty() else pts.size()
			for i in range(0, count - 2, 3):
				var a: Vector3 = into * pts[index[i] if not index.is_empty() else i]
				var b: Vector3 = into * pts[index[i + 1] if not index.is_empty() else i + 1]
				var c: Vector3 = into * pts[index[i + 2] if not index.is_empty() else i + 2]
				# A FACE THE RENDERER CULLS IS NOT IN THE WAY: seen from inside, the back of an airframe's skin is not
				# drawn, and the Cessna's panel is seen straight through it (`(c - a) x (b - a)` points out of a front
				# face, as tests/osprey.gd winds them).
				if not both_sides and (c - a).cross(b - a).dot(from - a) <= 0.0:
					continue
				var hit = Geometry3D.segment_intersects_triangle(from, short, a, b, c)
				if hit != null and ((hit as Vector3) - from).length() < best:
					best = ((hit as Vector3) - from).length()
					name_of = _last_three(mesh)
	return name_of


## GLASS IS LOOKED THROUGH. A windscreen between the eye and a screen is how a helm's panel is seen from its seat on the
## boat and the submarine, and a surface drawn blended is glass here.
func _see_through(material: Material) -> bool:
	var drawn := material as BaseMaterial3D
	return drawn != null and drawn.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED


## A mesh by the last three names on its path: enough to say whose it is without the view's whole tree.
func _last_three(node: Node) -> String:
	var names: PackedStringArray = []
	while node != null and names.size() < 3:
		names.insert(0, String(node.name))
		node = node.get_parent()
	return "/".join(names)
