extends Node
## Headless: is every ship's model within its budget, wound the right way out, whole, and can its helm see its bow?
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/ship_models.tscn
##
## THE BUDGET, per ship, as a headset has it: the near model under `NEAR_DRAWS` draw calls and `NEAR_TRIANGLES` triangles,
## the silhouette under `FAR_DRAWS`. A draw call here is a surface on a mesh instance, which is what the renderer submits
## for each pass; what a real frame adds, shadows and all, is measured windowed by tests/ship_shot.gd.
##
## WOUND THE RIGHT WAY OUT. Every face of these meshes is wound by hand (`Plating`), and a face wound backwards is invisible
## from outside and a hole in the ship -- which in a picture looks like a darker patch and in a headset like a missing
## wall. So every triangle's winding is checked against its own normal: Godot's front faces are clockwise as seen, so
## `(c - a) x (b - a)` must point the way the vertex normal does.
##
## THE VIEW FROM THE HELM, as arithmetic against the model's own panels (`HullSkin.is_clear`): from the eye of every seat
## that flies, the bow and the deck ahead are in sight, and nothing solid is within a head's reach of the eye.
##
## WHOLE, as two things the pictures of step 3 found and every other check here passed (tests/ship_shot.gd, 2026-09-15):
## SOMETHING TO STAND ON under every helm -- the launch's hull was lofted sides and a keel with no top, and its helm stood
## over the sea -- and A SIDE WITH NO GAP along the ship -- the battleship's two hull lengths were each fined away at their
## joint, and left a 12 m notch in its side at the forecastle's break.
##
## ON THE SHIP, for the fittings a ship's own model adds (`Battleship`, `PatrolBoat`, `Launch`): each one's foot on the top
## of a hull, deck, island or bridge part under its middle, and that middle inside no hull, deck or island part. The step 4
## drafts typed their heights from the research over step 3's decks, and turrets, mounts and launchers stood inside the
## forecastle or in the air.
##
## Read RESULT=, not the exit code.

const NEAR_DRAWS: int = 60
const NEAR_TRIANGLES: int = 250000
const FAR_DRAWS: int = 5
## A head, as a sphere round the eye: a little more than a helmet.
const HEAD: float = 0.25
## How far under a room's floor the thing stood on may be: a deck's plating, not a hull's bottom.
const FLOOR_BELOW: float = 0.35
## How far under the floor THE GEOMETRY ITSELF names the drawn plating may lie. The launch's jockey-seat frame is 0.02 m
## of plate under its part's top, which is plating; the 0.08 m the submarine's helm read when its seat was slid onto its
## floor quad's diagonal is a face missed, not plating.
const FLOOR_PLATE: float = 0.05
## Where along the ship its side is walked, as shares of its length from the bow, and how often. The ends are left out:
## a stem and a transom are meant to come in.
const SIDE_FROM: float = 0.15
const SIDE_TO: float = 0.85
const SIDE_STEP: float = 2.0
## How far a fitting's foot may be from the top it stands on: a deck's paint and a hull's plating lie a few cm off it.
const FOOT: float = 0.06
## THE SHIPS WITH A MODEL OF THEIR OWN, which must report their fittings: a builder that reports none is not checked, and
## that is a failure rather than a pass.
const STANDING: Array[String] = ["battleship", "gunboat", "boat", "submarine", "cb90", "fireboat"]
## EVERY SHIP WITH PARTS. The launch, the patrol boat and the battleship were chairs on boxes until step 3 of the carrier
## lane; each now has a helm in a room, and each is held to the same budget, winding and view.
const SHIPS: Dictionary = {"carrier": 12, "battleship": 13, "gunboat": 9, "boat": 2, "submarine": 20,
	"cb90": Sim.Kind.CB90, "fireboat": Sim.Kind.FIREBOAT}

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[ship_models] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for ship_name in SHIPS:
		var kind: int = SHIPS[ship_name]
		var geometry: Dictionary = Sim.geometry_of(kind)
		var view := (load("res://objects/vehicles/craft_%s.tscn" % ship_name) as PackedScene).instantiate() as VehicleView
		add_child(view)
		view.setup(0, kind)
		_the_budget(ship_name, view)
		var made: Dictionary = ShipHull.models(kind, geometry)
		_wound_outwards(ship_name, made)
		_the_helm_can_see(ship_name, geometry, made.get("panels", []) as Array)
		var faces: Array = _faces(made.get("near") as ArrayMesh)
		_something_under_every_helm(ship_name, geometry, faces)
		_the_side_is_whole(ship_name, geometry, faces)
		_fittings_stand_on_the_ship(ship_name, geometry, made.get("fittings", []) as Array)
		view.queue_free()
	_finish()


func _the_budget(ship_name: String, view: VehicleView) -> void:
	var near_draws: int = 0
	var near_triangles: int = 0
	var far_draws: int = 0
	for node in view.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var far: bool = mesh_node.visibility_range_begin > 0.0
		var surfaces: int = mesh_node.mesh.get_surface_count()
		if far:
			far_draws += surfaces
		elif mesh_node.visibility_range_end <= 0.0 or mesh_node.visibility_range_end > ShipHull.NEAR_TO * 0.5:
			near_draws += surfaces
			for s in range(surfaces):
				near_triangles += _triangles(mesh_node.mesh, s)
		# NO SCRIPT ON STATIC DETAIL: a model that runs per frame costs every frame for as long as the ship is in the sky.
		if mesh_node.get_script() != null:
			_check("%s_detail_runs_no_script" % ship_name, false, "%s has one" % mesh_node.name)
	_check("the_%s_near_model_is_within_its_draw_calls" % ship_name, near_draws < NEAR_DRAWS,
		"%d surfaces against %d" % [near_draws, NEAR_DRAWS])
	# EACH CHECK NAMES ITS SHIP. With one ship "and_its_triangles" was enough; with four, a failure has to say whose.
	_check("the_%s_near_model_is_within_its_triangles" % ship_name, near_triangles < NEAR_TRIANGLES and near_triangles > 0,
		"%d against %d" % [near_triangles, NEAR_TRIANGLES])
	_check("the_%s_silhouette_is_a_handful_of_draw_calls" % ship_name, far_draws > 0 and far_draws < FAR_DRAWS,
		"%d surfaces against %d" % [far_draws, FAR_DRAWS])


func _wound_outwards(ship_name: String, made: Dictionary) -> void:
	for which in ["far", "near"]:
		var mesh := made.get(which) as ArrayMesh
		if mesh == null:
			continue
		var wrong: int = 0
		var total: int = 0
		for s in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(s)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in range(0, points.size() - 2, 3):
				var face: Vector3 = (points[i + 2] - points[i]).cross(points[i + 1] - points[i])
				if face.length_squared() < 1e-10:
					continue
				total += 1
				if face.dot(normals[i]) <= 0.0:
					wrong += 1
		_check("every_face_of_the_%s_%s_model_is_wound_outwards" % [ship_name, which], wrong == 0 and total > 0,
			"%d of %d faces wound against their normal" % [wrong, total])


func _the_helm_can_see(ship_name: String, geometry: Dictionary, panels: Array) -> void:
	var half: Vector3 = geometry.get("extents", Vector3.ONE)
	for entry in (geometry.get("seat_poses", []) as Array):
		if not bool(entry.get("flies", false)):
			continue
		var eye: Vector3 = (entry["position"] as Vector3) + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
		var station: String = String(entry["station"])
		# THE BOW: a point on the deck near the stem, a metre up; and THE DECK AHEAD, halfway there. NEAR is 4 m aft of the
		# stem, or 15% of the way from the stem to the eye on a boat too short for that: on the 5.6 m launch, 4 m aft of the
		# stem was behind its helm, and "the bow is in sight" passed whatever stood in front of it. A window post in the
		# line of one is a helm that leans a hand's width, so the EYE is moved -- 12 cm either side and 5 cm up and down,
		# which is how far a seated head moves without the body -- and one clear line counts. The first version moved the
		# TARGET instead, by a hundredth of the range: 2 m at the bow and a millimetre at the glass, so a 10 cm post a
		# metre from the copilot's eye blocked every ray of the bundle and failed a view a person gets by leaning.
		var targets: Dictionary = {
			"bow": Vector3(0.0, half.y + 1.0, -half.z + minf(4.0, (eye.z + half.z) * 0.15)),
			"deck_ahead": Vector3(0.0, half.y + 1.0, lerpf(-half.z, eye.z, 0.5)),
		}
		for target in targets:
			var at: Vector3 = targets[target]
			var seen: bool = false
			for dx in [-0.12, 0.0, 0.12]:
				for dy in [-0.05, 0.0, 0.05]:
					var from: Vector3 = eye + Vector3(dx, dy, 0.0)
					var aim: Vector3 = at - from
					if HullSkin.is_clear(panels, from, aim, aim.length() * 0.98):
						seen = true
			# A VIEW THAT IS BLOCKED SAYS BY WHAT: the first panel on the straight line from the eye, which is what a failure
			# is fixed by. Without it the battleship's first step 4 failure named an eye and nothing in its way.
			_check("from_the_%s_%s_seat_the_%s_is_in_sight" % [ship_name, station, target], seen,
				"eye at %s%s" % [eye, "" if seen else ", in the way: " + _first_in_the_way(panels, eye, at)])
		var touching: Array[String] = []
		for panel in panels:
			var box := panel as AABB
			var nearest := Vector3(clampf(eye.x, box.position.x, box.end.x), clampf(eye.y, box.position.y, box.end.y),
				clampf(eye.z, box.position.z, box.end.z))
			if nearest.distance_to(eye) < HEAD:
				touching.append("%s" % box)
		_check("and_nothing_touches_the_%s_%s_head" % [ship_name, station], touching.is_empty(),
			"%s" % ["clear" if touching.is_empty() else touching])


## THE NEAREST PANEL ON THE STRAIGHT LINE from `from` to `to`, as its box and how far along the line it is; "nothing" if
## the line is clear and only a leaning eye was blocked.
func _first_in_the_way(panels: Array, from: Vector3, to: Vector3) -> String:
	var nearest: float = INF
	var found: String = "nothing on the straight line"
	for panel in panels:
		var box := panel as AABB
		var hit: Variant = box.intersects_segment(from, to)
		if hit == null:
			continue
		var along: float = from.distance_to(hit as Vector3)
		if along < nearest:
			nearest = along
			found = "%s at %.1f m" % [box, along]
	return found


## SOMETHING TO STAND ON: under every seat that flies, a face of the near model that looks up, lies under the seat in
## plan, and is between the room's floor and `FLOOR_BELOW` under it -- AT THE HEIGHT THE GEOMETRY ITSELF PUTS THE FLOOR,
## within `FLOOR_PLATE`, so a face the sampling missed cannot pass as a lower deck that happened to be within reach.
##
## THE DATUM IS THE PARTS, NOT THE MESH. Asking only "is there a face somewhere under the seat" is answered by whatever
## lies within `FLOOR_BELOW`, so a floor the sampling failed to see reads as a pass with the plate below it quoted: the
## submarine's helm said 6.78 m for a floor its own parts put at 6.86 (cockpit-fleet3, 2026-09-17). The part that carries
## the seat is drawn from the research and knows nothing of how the plating was triangulated, which is what makes it a
## datum (`testing_godot_headless.md`, "Anchor the check outside the thing it is checking").
func _something_under_every_helm(ship_name: String, geometry: Dictionary, faces: Array) -> void:
	for entry in (geometry.get("seat_poses", []) as Array):
		if not bool(entry.get("flies", false)):
			continue
		var seat: Vector3 = entry["position"]
		var plan := Vector2(seat.x, seat.z)
		var under: float = -INF
		for face in faces:
			if (face[3] as Vector3).y < 0.7:
				continue
			var a: Vector3 = face[0]
			var b: Vector3 = face[1]
			var c: Vector3 = face[2]
			var top: float = maxf(a.y, maxf(b.y, c.y))
			if top > seat.y + 0.05 or top < seat.y - FLOOR_BELOW:
				continue
			if _covers(a, b, c, plan):
				under = maxf(under, top)
		# WHERE THE SHIP'S OWN PARTS PUT THE FLOOR under this seat: the highest solid part that covers it in plan and
		# whose top is within reach under it. A room is not a floor, so `bridge` and `station` are left out.
		var by_the_parts: float = -INF
		for part in (geometry.get("parts", []) as Array):
			var role: String = String(part.get("part", ""))
			if role == "bridge" or role == "station":
				continue
			if not Geometry2D.is_point_in_polygon(plan, part.get("outline", PackedVector2Array())):
				continue
			var top: float = float(part.get("top", 0.0))
			if top <= seat.y + 0.05 and top >= seat.y - FLOOR_BELOW:
				by_the_parts = maxf(by_the_parts, top)
		var deep: bool = by_the_parts > -INF and under > -INF and under < by_the_parts - FLOOR_PLATE
		_check("under_the_%s_%s_seat_is_a_floor" % [ship_name, String(entry["station"])], under > -INF and not deep,
			"seat at %.2f m, %s" % [seat.y, "nothing under it" if under == -INF
				else "floor drawn at %.2f m against the parts' %.2f m" % [under, by_the_parts] if deep
				else "floor at %.2f m" % under])


## A SIDE WITH NO GAP: a line in from starboard, just under the waterline, meets the skin at every `SIDE_STEP` metres of
## the ship's middle, at no less than a quarter of its widest half-beam.
func _the_side_is_whole(ship_name: String, geometry: Dictionary, faces: Array) -> void:
	var bow: float = INF
	var stern: float = -INF
	var widest: float = 0.0
	var keel: float = INF
	var hull_top: float = -INF
	for part in (geometry.get("parts", []) as Array):
		if String(part.get("part", "")) != "hull":
			continue
		keel = minf(keel, float(part.get("bottom", 0.0)))
		hull_top = maxf(hull_top, float(part.get("top", 0.0)))
		for p in (part.get("outline", PackedVector2Array()) as PackedVector2Array):
			bow = minf(bow, p.y)
			stern = maxf(stern, p.y)
			widest = maxf(widest, p.x)
	if bow == INF:
		_check("the_%s_side_is_whole_along_the_ship" % ship_name, false, "no hull part")
		return
	var waterline: float = float(geometry.get("waterline", 0.0))
	# A hair off round numbers, so a sample never lands exactly on a shared edge and falls between two triangles.
	# THE LINE RUNS JUST UNDER THE WATERLINE, OR AT THE HULL'S MIDDLE IF THAT IS LOWER. A surface ship's hull is widest near
	# the sea. A submarine's is round and widest at its axis, 3.66 m under the sea: 0.3 m under, its stern cone is narrower
	# than a quarter-beam from 18.9 m before its tail, inside the middle 70 %, which is a submarine lying awash aft rather
	# than a gap (cockpit-fleet, 2026-09-15). The middle is the WHOLE SHIP's hull parts', lowest bottom to highest top: per
	# part, the battleship's forecastle and main deck would sample at two heights (ruled by cockpit-carrier).
	var y: float = minf(waterline - minf(0.3, (waterline - keel) * 0.5), (keel + hull_top) * 0.5) + 0.0071
	var starboard: Array = []
	for face in faces:
		if maxf((face[0] as Vector3).x, maxf((face[1] as Vector3).x, (face[2] as Vector3).x)) > 0.0:
			starboard.append(face)
	var gaps: Array[String] = []
	var stations: int = 0
	var z: float = lerpf(bow, stern, SIDE_FROM) + 0.0137
	while z <= lerpf(bow, stern, SIDE_TO):
		stations += 1
		var hit: float = -INF
		for face in starboard:
			hit = maxf(hit, _x_at(Vector2(z, y), face[0], face[1], face[2]))
		if hit < widest * 0.25:
			gaps.append("%.0f" % z)
		z += SIDE_STEP
	_check("the_%s_side_is_whole_along_the_ship" % ship_name, gaps.is_empty() and stations > 0,
		"%d of %d stations %.2f m under the waterline, the ship's own height, with no skin%s" % [gaps.size(), stations, waterline - y,
			"" if gaps.is_empty() else ", at z " + ", ".join(gaps)])


## EVERY FITTING STANDS ON THE SHIP: its foot within `FOOT` of the top of a hull, deck, island or bridge part under its
## middle, and its middle inside no hull, deck or island part -- a bridge part is a room, and a fitting inside one is not
## buried in it.
func _fittings_stand_on_the_ship(ship_name: String, geometry: Dictionary, fittings: Array) -> void:
	if fittings.is_empty():
		if ship_name in STANDING:
			_check("every_%s_fitting_stands_on_the_ship" % ship_name, false, "its model reported no fittings")
		return
	var wrong: Array[String] = []
	for item in fittings:
		var box := item as AABB
		var middle: Vector3 = box.get_center()
		var plan := Vector2(middle.x, middle.z)
		var stood: bool = false
		var buried: bool = false
		for part in (geometry.get("parts", []) as Array):
			var role: String = String(part.get("part", ""))
			if not (role in ["hull", "deck", "island", "bridge"]):
				continue
			if not Geometry2D.is_point_in_polygon(plan, part.get("outline", PackedVector2Array())):
				continue
			var top: float = float(part.get("top", 0.0))
			if absf(top - box.position.y) <= FOOT:
				stood = true
			if role != "bridge" and middle.y > float(part.get("bottom", 0.0)) and middle.y < top:
				buried = true
		if buried or not stood:
			wrong.append("%s at (%.1f, %.2f, %.1f)" % ["inside a part" if buried else "on nothing", middle.x,
				box.position.y, middle.z])
	_check("every_%s_fitting_stands_on_the_ship" % ship_name, wrong.is_empty(),
		"%d fittings%s" % [fittings.size(), "" if wrong.is_empty() else ": " + ", ".join(wrong)])


## WHETHER A TRIANGLE COVERS A PLAN POINT, sampled as a cross a third of a metre across rather than as one point.
##
## A QUAD IS TWO TRIANGLES AND A POINT ON THE DIAGONAL IS INSIDE NEITHER: `Geometry2D.point_is_inside_triangle` compares
## its cross products strictly, so a point exactly on the shared edge fails the winding test for both halves. Slide the
## submarine's helm 0.35 m onto the centreline -- which is where the diagonal of the quad that is its floor crosses, the
## two seats being placed symmetrically about that very point -- and the floor under it reads 6.78 m instead of 6.86.
## `_the_side_is_whole` dodges the same thing by nudging its samples off round numbers; this is the general answer, and
## `merchant_models` found it first on the ferry's wheelhouse roof, whose diagonal runs through the room its seats are in
## and which read 3.3 m low (cockpit-fleet3, 2026-09-17).
func _covers(a: Vector3, b: Vector3, c: Vector3, at: Vector2) -> bool:
	for off in [Vector2.ZERO, Vector2(0.17, 0.0), Vector2(-0.17, 0.0), Vector2(0.0, 0.17), Vector2(0.0, -0.17)]:
		if Geometry2D.point_is_inside_triangle(at + off, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)):
			return true
	return false


## Where a line along x through (z, y) = `p` crosses triangle abc, as its x; -INF if it misses.
static func _x_at(p: Vector2, a: Vector3, b: Vector3, c: Vector3) -> float:
	var a2 := Vector2(a.z, a.y)
	var b2 := Vector2(b.z, b.y)
	var c2 := Vector2(c.z, c.y)
	if not Geometry2D.point_is_inside_triangle(p, a2, b2, c2):
		return -INF
	var whole: float = (b2 - a2).cross(c2 - a2)
	if absf(whole) < 1e-9:
		return -INF
	var u: float = (b2 - p).cross(c2 - p) / whole
	var v: float = (c2 - p).cross(a2 - p) / whole
	return a.x * u + b.x * v + c.x * (1.0 - u - v)


## THE NEAR MODEL AS TRIANGLES, `[a, b, c, normal]`: Plating welds without an index, so every three vertices are a face.
func _faces(mesh: ArrayMesh) -> Array:
	var out: Array = []
	if mesh == null:
		return out
	for s in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in range(0, points.size() - 2, 3):
			out.append([points[i], points[i + 1], points[i + 2], normals[i]])
	return out


func _triangles(mesh: Mesh, surface: int) -> int:
	var arrays: Array = mesh.surface_get_arrays(surface)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if not indices.is_empty():
		return indices.size() / 3
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
