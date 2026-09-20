extends Node
## Headless: is the air base laid the way its file says, does it keep the published clearances it cites, and does a base
## that cannot be laid refuse itself for its own reason?
##
##   Godot --headless --xr-mode off --path cockpit res://tests/airbase.tscn
##
## The bases under `res://world/airbases/` are content: a folder a base, `_`-prefixed folders skipped by the scan.
## `fighter_base` is the island's; `_template` is a working base this suite lays by name, and the `_test_*` fixtures beside
## it are broken on purpose. Every check is against something the plan did not compute:
##
## - THE FILE, COUNTED HERE: the walls a revetment block and a hangar are made of and the spots a base has are counted
##   from the JSON by this file's own arithmetic, and every spot's route reaches every runway join by a search this file
##   does over the edges `AirbasePlan` derived.
## - THE STANDARDS, MEASURED HERE: the parallel taxiway's pavement outside the runway's clearance zone, every wall and the
##   tower's footprint the taxiway obstacle clearance from every taxiway centreline and a wingtip's clearance from every
##   taxilane's widest user, taxilanes the published distance from parallel taxiways, and each parked kind fitting its
##   spot -- distances between rectangles this file works out, against the numbers the file cites.
## - THE REFUSALS: bad JSON, a revetment block with no taxilane in front of it, a runway that is not a quarter turn, and
##   ground that is not level, each named by the words of its own warning (`AirbasePlan.last_refusal`).
##
## Read RESULT=, not the exit code.

const BASE: String = "res://world/airbases/fighter_base"
const TEMPLATE: String = "res://world/airbases/_template"
## The widest craft the apron and its taxilane are laid out for: the airliner, the 737, whose drawn wings are 35.8 m since
## lane/liners (2026-09-19; they were 30). Held here, not read from the file's `apron_craft`: the plan spaces the spots and
## stands the revetments off the ramp from that name, and a file that named a narrower craft would lay a base this suite
## must still find too tight for an airliner.
const APRON_DESIGN_KIND: int = Sim.Kind.AIRLINER
## And the craft the revetment bays are built round.
const BAY_DESIGN_KIND: int = Sim.Kind.FIGHTER
## THE WALL CHECK: the tick rate, how long the fighters are driven, and on what throttle; how far past a wall's inner face
## a nose may be and still be stopped by it (a hull's box against a wall's, plus a tick of travel), and how near the face
## it must have come to show it was driven there at all.
const WALL_HZ: float = 120.0
const WALL_SECONDS: float = 30.0
const WALL_THROTTLE: float = 0.5
const WALL_GIVE: float = 0.25
const WALL_REACHED: float = 1.5
## How far over the pavement a sightline's target stands, metres: the nosewheel of a taxiing aeroplane, near enough.
const SIGHT_OVER: float = 0.5

var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[airbase] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	Terrain.stand_on(null)
	var manifest: Dictionary = AirbasePlan.read_base(BASE)
	var laid: Dictionary = {} if manifest.is_empty() else AirbasePlan.lay(manifest, Terrain.runways()[int(manifest["runway"])])
	_the_base_is_laid_as_its_file_says(manifest, laid)
	_the_base_keeps_the_clearances_it_cites(laid)
	_a_base_that_cannot_be_laid_refuses_itself_for_its_own_reason()
	_the_grass_is_kept_off_every_slab_near_any_eye_on_the_base(laid)
	_the_walls_stop_a_fighter_driven_into_them(laid)
	_the_towers_seats_see_both_runway_ends_and_every_taxiway_junction(laid)
	_the_island_lays_its_base_by_index_as_before(laid)
	_check("every_section_of_the_suite_ran", _sections == 7, "%d of 7" % _sections)
	_finish()


## ---- the file, counted --------------------------------------------------------------------------------------------

func _the_base_is_laid_as_its_file_says(manifest: Dictionary, laid: Dictionary) -> void:
	if laid.is_empty():
		_check("the_fighter_base_is_laid_on_the_island", false, "refused: %s" % AirbasePlan.last_refusal)
		_sections += 1
		return
	# THE WALLS, COUNTED FROM THE FILE: a block of n bays is n + 1 side walls and a back wall; a hangar is two sides, a
	# back and a roof, and a header over its door when the door is lower than the roof.
	var walls: int = 0
	var spots: int = 0
	for block in manifest["revetments"]:
		walls += int(block["bays"]) + 2
		spots += int(block["bays"])
	for hangar in manifest["hangars"]:
		var type: Dictionary = manifest["standards"]["hangar_types"][hangar["type"]]
		walls += 4 + (1 if float(type["door_height"]) < float(type["clear_height"]) else 0)
	for apron in manifest["aprons"]:
		spots += int(apron["spots"])
	var parked_fit: PackedStringArray = []
	for parked in manifest["parked"]:
		var spot: Dictionary = (laid["spots"] as Dictionary).get(parked["spot"], {})
		if spot.is_empty() or not AirbasePlan.fits(spot, Sim.Kind[parked["kind"]]):
			parked_fit.append("%s on %s" % [parked["kind"], parked["spot"]])
	_check("the_fighter_base_is_laid_with_the_walls_and_spots_its_file_describes",
		(laid["boxes"] as Array).size() == walls and (laid["spots"] as Dictionary).size() == spots and parked_fit.is_empty(),
		"%d boxes of %d counted, %d spots of %d counted%s" % [(laid["boxes"] as Array).size(), walls,
			(laid["spots"] as Dictionary).size(), spots,
			"" if parked_fit.is_empty() else ", parked craft that do not fit: %s" % ", ".join(parked_fit)])
	# THE ROUTES: from every spot, a breadth-first search over the derived edges reaches every runway join.
	var neighbours: Dictionary = {}
	for edge in laid["edges"]:
		for pair in [[edge[0], edge[1]], [edge[1], edge[0]]]:
			if not neighbours.has(pair[0]):
				neighbours[pair[0]] = []
			(neighbours[pair[0]] as Array).append(pair[1])
	var joins: Array = (laid["nodes"] as Dictionary).keys().filter(func(n: String) -> bool: return n.ends_with(".runway"))
	var stranded: PackedStringArray = []
	for spot_id in laid["spots"]:
		var reached: Dictionary = {laid["spots"][spot_id]["node"]: true}
		var frontier: Array = [laid["spots"][spot_id]["node"]]
		while not frontier.is_empty():
			var at: String = frontier.pop_back()
			for next in neighbours.get(at, []):
				if not reached.has(next):
					reached[next] = true
					frontier.append(next)
		for join in joins:
			if not reached.has(join):
				stranded.append("%s cannot reach %s" % [spot_id, join])
	_check("every_spot_taxis_to_every_runway_join_along_the_derived_route",
		stranded.is_empty() and joins.size() == _runway_joins_in(manifest),
		"%d spots, %d runway joins (%d in the file), %d nodes, %d edges%s" % [(laid["spots"] as Dictionary).size(),
			joins.size(), _runway_joins_in(manifest), (laid["nodes"] as Dictionary).size(), (laid["edges"] as Array).size(),
			"" if stranded.is_empty() else ": " + "; ".join(stranded.slice(0, 4))])
	_sections += 1


func _runway_joins_in(manifest: Dictionary) -> int:
	var count: int = 0
	for taxiway in manifest["taxiways"]:
		if taxiway["across"] is Array and JSON.stringify(taxiway["across"]).contains("runway_edge"):
			count += 1
	return count


## ---- the standards, measured -------------------------------------------------------------------------------------

func _the_base_keeps_the_clearances_it_cites(laid: Dictionary) -> void:
	if laid.is_empty():
		_sections += 1
		return
	var standards: Dictionary = laid["standards"]
	var width: float = standards["taxiway_width"]
	var faults: PackedStringArray = []
	var apron_half_span: float = _half_span(APRON_DESIGN_KIND)
	# Everything that stands up: the walls, and the tower's footprint off the shape table.
	var obstacles: Array = []
	for wall in laid["walls"]:
		obstacles.append({"name": "%s %s" % [wall["part"], wall["of"]], "along": wall["along"], "across": wall["across"]})
	var tower_half: float = (Sim.geometry_of(Sim.Kind.TOWER).get("extents", Vector3.ONE) as Vector3).x
	obstacles.append({"name": "the tower",
		"along": [float(laid["tower"]["along"]) - tower_half, float(laid["tower"]["along"]) + tower_half],
		"across": [float(laid["tower"]["across"]) - tower_half, float(laid["tower"]["across"]) + tower_half]})
	var measured: int = 0
	for line in laid["taxiways"]:
		var centre: Dictionary = _centreline_rect(line)
		if line["kind"] == "taxiway" and line["along_runs"]:
			# A PARALLEL TAXIWAY'S PAVEMENT OUTSIDE THE RUNWAY'S LATERAL CLEARANCE ZONE.
			if absf(float(line["fixed"])) - width * 0.5 < float(standards["runway_clear_zone"]):
				faults.append("taxiway %s's pavement is %.1f m from the runway centreline, inside %.1f" % [line["id"],
					absf(float(line["fixed"])) - width * 0.5, float(standards["runway_clear_zone"])])
			measured += 1
			for other in laid["taxiways"]:
				if other["kind"] == "taxilane" and other["along_runs"] \
						and absf(float(other["fixed"]) - float(line["fixed"])) < float(standards["taxiway_to_taxilane"]):
					faults.append("taxilane %s is %.1f m from taxiway %s" % [other["id"],
						absf(float(other["fixed"]) - float(line["fixed"])), line["id"]])
				measured += 1
		# EVERY OBSTACLE clear of a taxiway by the taxiway clearance, and of a taxilane by its widest user's wingtip.
		var wanted: float = float(standards["taxiway_obstacle_clearance"]) if line["kind"] == "taxiway" \
			else apron_half_span + float(standards["wingtip_to_taxilane"])
		for obstacle in obstacles:
			var gap: float = _rect_gap(centre, obstacle)
			if gap < wanted:
				faults.append("%s is %.1f m from %s %s's centreline, wanted %.1f" % [obstacle["name"], gap, line["kind"],
					line["id"], wanted])
			measured += 1
	# EVERY SPOT FITS ITS DESIGN CRAFT: a bay the fighter, an apron spot the airliner.
	for spot_id in laid["spots"]:
		var spot: Dictionary = laid["spots"][spot_id]
		var kind: int = BAY_DESIGN_KIND if spot["bay_of"] != "" else APRON_DESIGN_KIND
		if not AirbasePlan.fits(spot, kind):
			faults.append("a %s does not fit spot %s (half span room %.2f, length room %.2f)" % [Sim.kind_name(kind),
				spot_id, float(spot["half_span_room"]), float(spot["length_room"])])
		measured += 1
	_check("the_fighter_base_keeps_the_published_clearances_it_cites", faults.is_empty() and measured > 100,
		"%d distances measured%s" % [measured, "" if faults.is_empty() else ": " + "; ".join(faults.slice(0, 4))])
	_sections += 1


func _half_span(kind: int) -> float:
	var geometry: Dictionary = Sim.geometry_of(kind)
	return maxf(float(geometry.get("span", 0.0)), (geometry.get("extents", Vector3.ONE) as Vector3).x)


## A centreline as a rectangle of no width, in the frame.
func _centreline_rect(line: Dictionary) -> Dictionary:
	var fixed: float = line["fixed"]
	if line["along_runs"]:
		return {"along": [line["start"], line["end"]], "across": [fixed, fixed]}
	return {"along": [fixed, fixed], "across": [line["start"], line["end"]]}


## The shortest distance between two rectangles of the frame, 0 where they overlap.
func _rect_gap(a: Dictionary, b: Dictionary) -> float:
	var along_gap: float = maxf(0.0, maxf(float(a["along"][0]) - float(b["along"][1]), float(b["along"][0]) - float(a["along"][1])))
	var across_gap: float = maxf(0.0, maxf(float(a["across"][0]) - float(b["across"][1]),
		float(b["across"][0]) - float(a["across"][1])))
	return Vector2(along_gap, across_gap).length()


## THE ISLAND STILL LAYS ITS BASE BY INDEX (lane/testfield, 2026-09-19): `AirbasePlan.runway_index` now answers -1 for an
## index on a level laid from its own airfield files, so the fighter base (`"runway": 0`) stays off the test field. On the
## island an index is still the island's runway, and the base `bases()` lays there is the one laid above by hand, piece
## for piece.
func _the_island_lays_its_base_by_index_as_before(laid: Dictionary) -> void:
	var found: Dictionary = {}
	for base in AirbasePlan.bases():
		if String(base["id"]) == "fighter_base":
			found = base
	var same: bool = not found.is_empty() and not laid.is_empty() and int(found["runway"]) == 0 \
		and (found["pavement"] as Array).size() == (laid["pavement"] as Array).size() \
		and (found["walls"] as Array).size() == (laid["walls"] as Array).size() \
		and (found["hull"] as AABB).is_equal_approx(laid["hull"]) and AirbasePlan.runway_index(0) == 0
	_check("the_island_lays_its_fighter_base_on_runway_0_exactly_as_before", same,
		"on runway %s, %d pavement and %d walls against %d and %d laid by hand" % [found.get("runway", "none"),
			(found.get("pavement", []) as Array).size(), (found.get("walls", []) as Array).size(),
			(laid.get("pavement", []) as Array).size(), (laid.get("walls", []) as Array).size()])
	_sections += 1


## ---- the refusals ---------------------------------------------------------------------------------------------------

func _a_base_that_cannot_be_laid_refuses_itself_for_its_own_reason() -> void:
	var wrong: PackedStringArray = []
	var said: PackedStringArray = []
	var island: Dictionary = Terrain.runway_axis()
	var template: Dictionary = AirbasePlan.read_base(TEMPLATE)
	var template_laid: bool = not template.is_empty() and not AirbasePlan.lay(template, island).is_empty()
	var cases: Array = [
		["_test_bad_json", "not a JSON object", func() -> bool:
			return AirbasePlan.read_base(AirbasePlan.FOLDER.path_join("_test_bad_json")).is_empty()],
		["_test_no_taxilane", "opens onto no taxilane", func() -> bool:
			var base: Dictionary = AirbasePlan.read_base(AirbasePlan.FOLDER.path_join("_test_no_taxilane"))
			return not base.is_empty() and AirbasePlan.lay(base, island).is_empty()],
		["the template on a runway at 30 degrees", "not a quarter turn", func() -> bool:
			var frame: Dictionary = Terrain.runway_frame(island["centre"], deg_to_rad(30.0), island["length"], island["width"])
			return AirbasePlan.lay(template, frame).is_empty()],
		["the template on a runway 50 m over the slab", "the ground under", func() -> bool:
			var frame: Dictionary = Terrain.runway_frame((island["centre"] as Vector3) + Vector3.UP * 50.0, island["bearing"],
				island["length"], island["width"])
			return AirbasePlan.lay(template, frame).is_empty()],
	]
	for case in cases:
		AirbasePlan.last_refusal = ""
		var refused: bool = (case[2] as Callable).call()
		said.append("%s: '%s'" % [case[0], AirbasePlan.last_refusal])
		if not refused or not AirbasePlan.last_refusal.contains(case[1]):
			wrong.append(case[0])
	_check("a_base_that_cannot_be_laid_refuses_itself_for_its_own_reason_and_the_template_lays",
		wrong.is_empty() and template_laid,
		"template %s; %s%s" % ["laid" if template_laid else "REFUSED: " + AirbasePlan.last_refusal, "; ".join(said),
			"" if wrong.is_empty() else "; wrong: %s" % ", ".join(wrong)])
	_sections += 1


## ---- the grass --------------------------------------------------------------------------------------------------

## The blades are hidden from a slab only if it is one of the few the shader is handed (`GrassBlades.PAVEMENT_SLOTS`).
## Every 5 m over the base and its surroundings, the slabs within the blades' reach are counted here, and the busiest
## place must not have more than the shader takes -- or a clump grows through the concrete there.
func _the_grass_is_kept_off_every_slab_near_any_eye_on_the_base(laid: Dictionary) -> void:
	if laid.is_empty():
		_sections += 1
		return
	var reach: float = GrassBlades.REACH + GrassBlades.PAVEMENT_MARGIN
	var hull := AABB()
	var first: bool = true
	for slab in laid["pavement"]:
		var box := AABB((slab["position"] as Vector3) - (slab["half_extents"] as Vector3), (slab["half_extents"] as Vector3) * 2.0)
		hull = box if first else hull.merge(box)
		first = false
	hull = hull.grow(reach)
	var busiest: int = 0
	var where := Vector3.ZERO
	var x: float = hull.position.x
	while x <= hull.end.x:
		var z: float = hull.position.z
		while z <= hull.end.z:
			var near: int = 0
			for slab in laid["pavement"]:
				var middle: Vector3 = slab["position"]
				var half: Vector3 = (slab["half_extents"] as Vector3) + Vector3.ONE * GrassBlades.PAVEMENT_MARGIN
				if absf(middle.x - x) <= half.x + reach and absf(middle.z - z) <= half.z + reach:
					near += 1
			if near > busiest:
				busiest = near
				where = Vector3(x, 0.0, z)
			z += 5.0
		x += 5.0
	_check("the_grass_shader_takes_every_slab_near_the_busiest_place_on_the_base", busiest <= GrassBlades.PAVEMENT_SLOTS,
		"%d slabs of %d within reach at (%.0f, %.0f); the shader takes %d" % [busiest, (laid["pavement"] as Array).size(),
			where.x, where.z, GrassBlades.PAVEMENT_SLOTS])
	_sections += 1


## ---- the walls, driven into ----------------------------------------------------------------------------------

## A FIGHTER DRIVEN AT A REVETMENT'S BACK WALL AND AT A HANGAR'S, on full-ish throttle, stops at the wall. The world is a
## bare `CockpitWorld` given the island's slab and every box `Terrain.boxes()` lists -- the list the level walks for
## `Sim.add_static_box` -- so a base whose boxes did not reach that list, or a wall laid somewhere other than where the
## file says, lets the nose through. Where the inner face is is worked out here from the file's numbers, not the plan's.
func _the_walls_stop_a_fighter_driven_into_them(laid: Dictionary) -> void:
	if laid.is_empty():
		_sections += 1
		return
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(WALL_HZ)
	# Client 0 is the server, which is the only world that may seat a pilot.
	world.start(0)
	world.add_static_box(Vector3(0.0, -Terrain.GROUND_HALF.y, 0.0), Terrain.GROUND_HALF)
	var solid: Array[Dictionary] = Terrain.boxes()
	var ours: int = 0
	for box in solid:
		world.add_static_box(box["position"], box["half_extents"])
		ours += 1 if int(box.get("group", -1)) == Terrain.Group.AIRBASE else 0
	var frame: Dictionary = laid["frame"]
	var manifest: Dictionary = AirbasePlan.read_base(BASE)
	var standards: Dictionary = manifest["standards"]
	var extents: Vector3 = Sim.geometry_of(BAY_DESIGN_KIND).get("extents", Vector3.ONE)
	var runs: Array = []
	# THE REVETMENT: from the third bay of the second block's mouth on its taxilane, nose into the bay.
	var block: Dictionary = manifest["revetments"][1]
	var wall: float = standards["revetment_wall_thickness"]
	var bay_along: float = float(block["along"]) + wall + 2.0 * (float(block["bay_width"]) + wall) + float(block["bay_width"]) * 0.5
	# Its front as the plan laid it: the file names only the taxilane the bays open onto (`AirbasePlan.lay`).
	var front: float = float((laid["revetments"] as Array)[1]["front"])
	runs.append(["the back wall of revetment %s's third bay" % block["id"], bay_along, front - extents.z - 25.0,
		front + float(block["bay_depth"])])
	# THE HANGAR: from just inside the door of the file's second hangar, nose to its back wall.
	var hangar: Dictionary = manifest["hangars"][1]
	var type: Dictionary = standards["hangar_types"][hangar["type"]]
	var skin: float = maxf((float(type["width"]) - float(type["door_width"])) * 0.5, 0.3)
	runs.append(["the back wall of hangar %s" % hangar["id"], float(hangar["along"]), float(hangar["door"]) + extents.z + 3.0,
		float(hangar["door"]) + float(type["depth"]) - skin])
	var client: int = 40
	var inputs: Dictionary = {}
	for run in runs:
		client += 1
		var start: Vector3 = AirbasePlan.frame_point(frame, run[1], run[2]) + Vector3.UP * (extents.y + 0.3)
		var seat: Dictionary = world.spawn_pilot(client, BAY_DESIGN_KIND, start,
			AirbasePlan.yaw_facing(frame["across"]), Vector3.ZERO)
		run.append(int(seat.get("vehicle", 0)))
		run.append(-INF)
		inputs[int(seat.get("pilot", 0))] = {
			"throttle": WALL_THROTTLE, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
			"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
			"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
			"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
			"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0}
	for tick in range(int(WALL_SECONDS * WALL_HZ)):
		for pilot in inputs:
			world.set_pilot_input(pilot, inputs[pilot])
		world.tick(1.0 / WALL_HZ)
		for run in runs:
			var state: Dictionary = world.vehicle_state(run[4])
			var at: Vector3 = state.get("position", Vector3.ZERO)
			# THE NOSE ITSELF, through the craft's own rotation, not the centre plus half a length along the approach. A
			# fighter shoved into a wall at half throttle can slew: with a drag of 4.3 (lane/handling, 2026-09-17) it met
			# the revetment's back wall at 18.8 m/s, as at 8.5, then pivoted on its nose to 40 degrees of yaw over eight
			# seconds -- and the centre-plus-half-length point walked 1.56 m "through" a wall the nose never passed,
			# half a length times (1 - cos 40). What this check holds is that the wall stops the aeroplane.
			var nose_at: Vector3 = at + Basis(state.get("basis", Quaternion()) as Quaternion) * Vector3(0.0, 0.0, -extents.z)
			var nose_across: float = (nose_at - (frame["centre"] as Vector3)).dot(frame["across"])
			run[5] = maxf(float(run[5]), nose_across)
	var said: PackedStringArray = []
	var through: PackedStringArray = []
	for run in runs:
		said.append("%s: nose reached %.2f, inner face %.2f" % [run[0], run[5], run[3]])
		if float(run[5]) > float(run[3]) + WALL_GIVE or float(run[5]) < float(run[3]) - WALL_REACHED:
			through.append(run[0])
	_check("a_fighter_driven_into_a_revetment_and_a_hangar_stops_at_the_wall", through.is_empty() and ours > 0,
		"%d airbase boxes in the solid list; %s%s" % [ours, "; ".join(said),
			"" if through.is_empty() else "; wrong at: " + ", ".join(through)])
	_sections += 1


## ---- the tower's sightlines --------------------------------------------------------------------------------------

## FROM EVERY ONE OF THE TOWER'S FOUR SEATS, BOTH RUNWAY ENDS AND EVERY NODE ON A TAXIWAY OR TAXILANE ARE IN SIGHT: the
## line from the controller's eye to a point half a metre over the pavement meets the surface at no less than the angle
## the file cites (FAA Order 6480.4A, 0.80 degrees), and passes through no solid box in `Terrain.boxes()`.
##
## THE TOWER IS THE ONE THE SPAWN TABLE STANDS UP (`Terrain.spawns()`), not the file's place: the check is of where the
## level puts it. The eye is its seat pose off the shape table, turned by the spawn's yaw, plus the station's eye height
## (`CockpitStation.EYE_HEIGHT`). The segment and box test is a slab test worked out here.
##
## AND THROUGH NO DRAWN ROOF EITHER, WHICH IS NOT THE SAME QUESTION. `Terrain.boxes()` is what the SIMULATION collides
## with, and a hangar's solid roof is a flat box at its clear height; the gable and the barrel vault that a controller
## would actually be looking at are drawn several metres above it and are not in that list. Checking the solid boxes
## alone is a check in the same frame as the thing it is checking -- testing_godot_headless.md, "Anchor the check
## outside the thing it is checking" -- so the lines are run against the ROOF MESH'S OWN TRIANGLES as well, read out of
## `AirbaseView.roof_mesh` by their transformed vertices, which is the drawn geometry and nothing standing in for it.
## ON TODAY'S LAYOUT NO LINE GOES NEAR A HANGAR -- the tower is along the apron and the hangars are behind it -- so
## the margin below reads 0.00 and the roof test adds nothing until something moves. RED BY MOVING THE TOWER: put it
## at along 0, across 585, behind the hangar line, and of the four blind lines it reports TWO are named "through a
## drawn hangar roof" at 14.31 m up, and the solid boxes alone do not block either of them (measured 2026-09-17). The
## margin is printed every run so a roof grown taller shows as a number closing rather than as a suite that is green
## until the day it is not.
func _the_towers_seats_see_both_runway_ends_and_every_taxiway_junction(laid: Dictionary) -> void:
	if laid.is_empty():
		_sections += 1
		return
	var tower: Dictionary = {}
	for spawn in Terrain.spawns():
		if int(spawn["kind"]) == Sim.Kind.TOWER:
			tower = spawn
	var frame: Dictionary = laid["frame"]
	var expected: Vector3 = AirbasePlan.frame_point(frame, float(laid["tower"]["along"]), float(laid["tower"]["across"]))
	var on_the_base: bool = not tower.is_empty() 		and Vector2((tower["position"] as Vector3).x - expected.x, (tower["position"] as Vector3).z - expected.z).length() < 0.01
	var least: float = float(laid["standards"]["sightline_degrees"])
	var targets: Array = [["the threshold", frame["threshold"]], ["the far end", frame["far_end"]]]
	for name in laid["nodes"]:
		var node: Dictionary = laid["nodes"][name]
		if not (laid["spots"] as Dictionary).has(name):
			targets.append([name, node["position"]])
	var solid: Array[Dictionary] = Terrain.boxes()
	# EVERY TRIANGLE OF THE DRAWN ROOFS, in world space: `roof_mesh` builds them relative to an origin, so it is asked
	# for them relative to nothing. Read from the mesh rather than worked out here a second time from the same numbers.
	var roofs: PackedVector3Array = _roof_triangles(laid)
	var poses: Array = Sim.geometry_of(Sim.Kind.TOWER).get("seat_poses", [])
	var blind: PackedStringArray = []
	var flattest: float = INF
	var flattest_at: String = ""
	var eye_high: float = 0.0
	## How near a drawn roof the nearest sightline that passes over one comes, metres. Printed so a roof grown taller
	## shows as a shrinking margin before it shows as a failure.
	var over_a_roof: float = 0.0
	for seat in range(poses.size()):
		if tower.is_empty():
			break
		var eye: Vector3 = (tower["position"] as Vector3) + Basis(Vector3.UP, float(tower["yaw"])) 			* (poses[seat]["position"] as Vector3) + Vector3.UP * CockpitStation.EYE_HEIGHT
		eye_high = eye.y - (frame["centre"] as Vector3).y
		for target in targets:
			var at: Vector3 = (target[1] as Vector3) + Vector3.UP * SIGHT_OVER
			var run: float = Vector2(at.x - eye.x, at.z - eye.z).length()
			var angle: float = rad_to_deg(atan2(eye.y - (target[1] as Vector3).y, run))
			if angle < flattest:
				flattest = angle
				flattest_at = "seat %d to %s, %.0f m" % [seat, target[0], run]
			var blocker: String = _first_box_between(solid, eye, at)
			if blocker == "":
				blocker = _roof_hit(roofs, eye, at)
			over_a_roof = maxf(over_a_roof, _how_far_over_the_roofs(roofs, eye, at))
			if angle < least or blocker != "":
				blind.append("seat %d to %s (%.2f degrees%s)" % [seat, target[0], angle,
					"" if blocker == "" else ", through " + blocker])
	_check("the_towers_seats_see_both_runway_ends_and_every_taxiway_junction_at_the_published_angle",
		on_the_base and poses.size() == 4 and blind.is_empty(),
		"tower %s the base's place; eye %.2f m up; %d seats x %d targets; %d drawn roof triangles, nearest pass %.2f m over one; flattest %.2f degrees (%s), wanted %.2f%s" % [
			"at" if on_the_base else "NOT at", eye_high, poses.size(), targets.size(), roofs.size() / 3, over_a_roof,
			flattest, flattest_at, least,
			"" if blind.is_empty() else "; blind: " + "; ".join(blind.slice(0, 4))])
	_sections += 1


## EVERY TRIANGLE OF THE BASE'S DRAWN HANGAR ROOFS, in world space, as flat triples of vertices.
##
## From the mesh `AirbaseView` actually draws, built about the world's origin so its vertices come out where the roofs
## stand. Not rebuilt from the file here: a copy of the arithmetic would agree with the drawing about a ridge that was
## in the wrong place.
func _roof_triangles(laid: Dictionary) -> PackedVector3Array:
	var mesh: ArrayMesh = AirbaseView.roof_mesh(laid, Vector3.ZERO)
	var out := PackedVector3Array()
	if mesh == null or mesh.get_surface_count() == 0:
		return out
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# NOT INDEXED, AND THAT IS THE USUAL CASE. `SurfaceTool` only builds an index array if somebody asks it to, and
	# `roof_mesh` does not, so this is `null` rather than empty -- and reading it into a typed variable is an engine
	# error, which the runner fails a suite for however green its own checks are.
	var index: Variant = arrays[Mesh.ARRAY_INDEX]
	if index == null or (index as PackedInt32Array).is_empty():
		return points
	for i in (index as PackedInt32Array):
		out.append(points[i])
	return out


## The drawn roof a segment passes through, named by where it was hit, or "".
func _roof_hit(roofs: PackedVector3Array, from: Vector3, to: Vector3) -> String:
	for t in range(0, roofs.size() - 2, 3):
		var where: float = _hits_triangle(from, to, roofs[t], roofs[t + 1], roofs[t + 2])
		if where >= 0.0:
			return "a drawn hangar roof at %s" % [from + (to - from) * where]
	return ""


## HOW NEAR A DRAWN ROOF THIS SEGMENT PASSES, of the ones it passes OVER, and 0.0 if it passes over none.
##
## The margin, so a roof raised a metre shows as a number closing rather than as a suite that is green until the day it
## is not. Measured straight down from the segment onto each triangle's vertices, which for a roof drawn as a strip of
## quads is every point along its ridge.
func _how_far_over_the_roofs(roofs: PackedVector3Array, from: Vector3, to: Vector3) -> float:
	var flat_from := Vector2(from.x, from.z)
	var flat_to := Vector2(to.x, to.z)
	var run: Vector2 = flat_to - flat_from
	if run.length_squared() < 0.0001:
		return 0.0
	var nearest: float = 0.0
	for i in range(roofs.size()):
		var point: Vector3 = roofs[i]
		var along: float = clampf((Vector2(point.x, point.z) - flat_from).dot(run) / run.length_squared(), 0.0, 1.0)
		var sideways: float = (flat_from + run * along).distance_to(Vector2(point.x, point.z))
		if sideways > 1.0:
			continue
		var over: float = (from + (to - from) * along).y - point.y
		if over <= 0.0:
			continue
		if nearest == 0.0 or over < nearest:
			nearest = over
	return nearest


## WHERE A SEGMENT MEETS A TRIANGLE, as a fraction of the segment, or -1.0 if it misses. Moller-Trumbore.
func _hits_triangle(from: Vector3, to: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var ray: Vector3 = to - from
	var edge1: Vector3 = b - a
	var edge2: Vector3 = c - a
	var h: Vector3 = ray.cross(edge2)
	var det: float = edge1.dot(h)
	if absf(det) < 0.000001:
		return -1.0
	var inv: float = 1.0 / det
	var s: Vector3 = from - a
	var u: float = inv * s.dot(h)
	if u < 0.0 or u > 1.0:
		return -1.0
	var q: Vector3 = s.cross(edge1)
	var v: float = inv * ray.dot(q)
	if v < 0.0 or u + v > 1.0:
		return -1.0
	var where: float = inv * edge2.dot(q)
	return where if where >= 0.0 and where <= 1.0 else -1.0


## The first solid box a segment passes through, named by its group and middle, or "".
func _first_box_between(solid: Array[Dictionary], from: Vector3, to: Vector3) -> String:
	var ray: Vector3 = to - from
	for box in solid:
		var low: Vector3 = (box["position"] as Vector3) - (box["half_extents"] as Vector3)
		var high: Vector3 = (box["position"] as Vector3) + (box["half_extents"] as Vector3)
		var enter: float = 0.0
		var leave: float = 1.0
		var missed: bool = false
		for axis in range(3):
			if absf(ray[axis]) < 0.000001:
				if from[axis] < low[axis] or from[axis] > high[axis]:
					missed = true
					break
				continue
			var t1: float = (low[axis] - from[axis]) / ray[axis]
			var t2: float = (high[axis] - from[axis]) / ray[axis]
			enter = maxf(enter, minf(t1, t2))
			leave = minf(leave, maxf(t1, t2))
			if enter > leave:
				missed = true
				break
		if not missed:
			return "%s box at %s" % [Terrain.Group.keys()[int(box.get("group", 0))].to_lower(), box["position"]]
	return ""


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
