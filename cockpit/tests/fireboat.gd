extends Node3D
## THE FIREBOAT, HELD TO WHAT IS DRAWN -- not to the numbers that were typed.
##
## Every check below reads the TRANSFORMED VERTICES of the meshes actually in the tree, never
## `transform * mesh.get_aabb()`: a box round a box grows every time it is turned, and that read the folded Hawkeye
## 0.86 m too wide (`modelling_here.md` section 6).
##
## THE REFERENCE IS PUBLISHED AND IT IS AT THE TOP, in one place, so it can be read against `craft/fireboat/sources.md`
## by eye. Nothing here is derived from `fireboat_shape`; that is the thing under test.
##
## WHAT THIS SUITE CANNOT SEE, said out loud because a green suite is not a picture: whether she LOOKS like a fireboat,
## whether the deckhouse is the right height (every height above the deck is an ESTIMATE -- her superstructure is white
## against the Manhattan skyline and cannot be measured off the reference), and whether the livery reads. Those wanted
## the craft gallery, and `sources.md` says which figures carry the least evidence.
##
## Read RESULT=, not the exit code.

## THE PUBLISHED ENVELOPE. [W] Wikipedia, "Three Forty Three", infobox, via action=raw.
const LENGTH: float = 42.672
const BEAM: float = 10.973
const DRAUGHT: float = 2.743
## How close the drawn hull must come to it. Two per cent, as every model here is held.
const TOLERANCE: float = 0.02
## Four engines, four stacks: the photographs and the published "4 x MTU 2,000 hp" agree, and neither was asked.
const STACKS: int = 4
## Three monitors, two forward and one aft, which is what the user asked for. The real boat has eleven.
const MONITORS: int = 3
## The first exterior LOD's budget (`aircraft_model_fidelity_plan.md`), and what a boat of this size should cost. The
## measured fleet for scale: patrol boat 6,328 triangles, battleship 9,798, launch 11,466.
const MOST_TRIANGLES: int = 16000
const MOST_SURFACES: int = 6
## How far apart two vertex colours must be in SOME channel to be told apart after `SurfaceTool.commit` quantises them
## to eight bits. `modelling_here.md` section 4: two colours 0.03 apart survive; closer than that may not.
const COLOUR_APART: float = 0.03

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[fireboat] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	# THE LIBRARY AND THE GAME AGREE ON THE KIND FIRST, and bail if not: everything after it is noise.
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld missing")
		_finish()
		return
	var kind: int = Sim.Kind.FIREBOAT
	var geometry: Dictionary = Sim.geometry_of(kind)
	_check("the_simulation_has_a_fireboat", String(geometry.get("name", "")) == "fireboat",
		"kind %d is '%s'" % [kind, geometry.get("name", "")])
	if String(geometry.get("name", "")) != "fireboat":
		_finish()
		return

	var view := (load("res://objects/vehicles/craft_fireboat.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.setup(0, kind)

	_the_drawn_hull_is_the_published_boat(view)
	_she_floats_where_she_looks_as_if_she_floats(view, geometry)
	_four_stacks_over_the_casing(view, kind, geometry)
	_every_colour_in_her_can_be_told_from_every_other(kind, geometry)
	_the_exterior_meets_its_budget(kind, geometry)
	_the_asset_boundary_cannot_change_native_geometry(kind)
	_both_helms_are_in_the_wheelhouse(geometry)
	_three_monitors_two_forward_and_one_aft(kind)
	_each_monitor_is_drawn_on_its_mount(view)
	_a_monitor_throws_water_and_fires_nothing(kind)
	_one_operator_per_monitor(geometry)
	view.queue_free()
	_finish()


## THE DRAWN BOAT IS THE PUBLISHED BOAT, within two per cent, measured off the near model's own vertices.
##
## THE BEAM IS MEASURED OFF THE HULL'S OWN COLOUR, not off the whole drawn box, and that is a DATUM decision rather
## than a convenience. A published beam is the MOULDED beam; the D-section rubbing fenders are bolted to the outside of
## it and stand 0.22 m proud, so a box round everything reads 11.4 m against a published 10.97 and calls a correct hull
## 4 per cent fat. `modelling_here.md` section 2 twice over: a real figure quoted against the wrong place on the
## object, and the shape blamed for it. Identifying the hull by its paint is what section 6 permits and what keeping
## the palette 0.03 apart is for.
##
## THE LENGTH IS MEASURED OVER EVERYTHING, because nothing is bolted forward of the stem or abaft the transom.
func _the_drawn_hull_is_the_published_boat(view: VehicleView) -> void:
	var box: AABB = _near_bounds(view)
	var skin: float = _hull_beam(view)
	_check("the_drawn_hull_is_the_published_boat",
		absf(box.size.z - LENGTH) <= LENGTH * TOLERANCE and absf(skin - BEAM) <= BEAM * TOLERANCE,
		"drawn %.2f long, hull skin %.2f in the beam (everything drawn, %.2f); published %.2f x %.2f"
		% [box.size.z, skin, box.size.x, LENGTH, BEAM])
	# AND THE FENDERS ARE OUTSIDE IT, both sides alike. Built from a corner rather than a centre they came out 0.24 m
	# proud to starboard and 0.10 m sunk into the hull to port, which no dimension check can see because the drawn beam
	# is whatever the wider side says. This one can: it asks whether the widest thing drawn is the same distance out on
	# each side of the centreline.
	var reach: Vector2 = _widest_each_side(view)
	_check("and_what_is_bolted_outside_her_is_bolted_on_both_sides",
		absf(reach.x + reach.y) <= 0.02 and reach.y - skin * 0.5 > 0.05,
		"widest drawn: %.3f m to port, %.3f m to starboard; hull half-beam %.3f" % [reach.x, reach.y, skin * 0.5])


## HER DRAUGHT IS DRAWN, not merely declared: the lowest drawn point of the hull is the published draught below the
## design waterline, which is the origin. A boat drawn shallower than she floats shows her bottom in a swell.
func _she_floats_where_she_looks_as_if_she_floats(view: VehicleView, geometry: Dictionary) -> void:
	var box: AABB = _near_bounds(view)
	var hull_bottom: float = INF
	for part in (geometry.get("parts", []) as Array):
		if String(part.get("part", "")) == "hull":
			hull_bottom = minf(hull_bottom, float(part.get("bottom", 0.0)))
	_check("she_floats_where_she_looks_as_if_she_floats",
		absf(box.position.y + DRAUGHT) <= 0.12 and absf(hull_bottom + DRAUGHT) <= 0.01,
		"lowest drawn %.3f m, the hull part's bottom %.3f m, published draught %.3f m"
		% [box.position.y, hull_bottom, -DRAUGHT])


## FOUR STACKS, DECLARED AND DRAWN, AND THE TWO MUST AGREE. `exhaust_ports` is what `tests/exhaust.gd` reads; if it
## returned four ports over a boat with no funnels drawn, the ratchet would be satisfied by a promise.
##
## THE CHECK IS ANCHORED OUTSIDE THE DECLARATION: each declared port must have DRAWN GEOMETRY under it, found in the
## mesh, rather than the ports merely being four of something.
func _four_stacks_over_the_casing(view: VehicleView, kind: int, geometry: Dictionary) -> void:
	var ports: Array = view.exhaust_ports()
	_check("she_declares_one_exhaust_port_per_engine", ports.size() == STACKS,
		"%d ports declared, %d engines" % [ports.size(), STACKS])
	if ports.size() != STACKS:
		return
	# EVERY PORT STANDS OVER THE CASING: the TALLEST island, because a funnel housing stands higher than accommodation.
	#
	# WORKED OUT HERE RATHER THAN ASKED OF `Fireboat.casing_of`, so the check does not share its subject's frame
	# (`modelling_here.md` section 6). This suite's first draft said "island 1" -- an index -- which was already wrong
	# by the time it ran: the deckhouse had been split in two and the casing had moved to slot 2, so the check would
	# have looked for funnels on the wheelhouse base and the two mistakes would have cancelled into a pass.
	var casing: Dictionary = {}
	for part in (geometry.get("parts", []) as Array):
		if String(part.get("part", "")) != "island":
			continue
		if casing.is_empty() or float(part.get("top", 0.0)) > float(casing.get("top", 0.0)):
			casing = part
	if casing.is_empty():
		_check("every_port_stands_over_the_casing_roof", false, "no island to stand a funnel on")
		return
	var roof: float = float(casing["top"])
	var over: Rect2 = Wheelhouse.outline_rect(casing["outline"]).grow(1.2)
	var wrong: PackedStringArray = []
	for port in ports:
		var at: Vector3 = (port as Dictionary)["at"]
		if at.y <= roof or not over.has_point(Vector2(at.x, at.z)):
			wrong.append("(%.1f, %.1f, %.1f)" % [at.x, at.y, at.z])
	_check("every_port_stands_over_the_casing_roof", wrong.is_empty(),
		"casing roof %.2f m, %d ports clear of it%s" % [roof, ports.size() - wrong.size(),
			"" if wrong.is_empty() else "; adrift: %s" % ", ".join(wrong)])
	# AND THERE IS STEEL UNDER EACH ONE. The stacks are drawn as fittings; a port with nothing beneath it is a promise.
	var fittings: Array = ShipHull.models(kind, geometry).get("fittings", []) as Array
	var standing: int = 0
	for port in ports:
		var at: Vector3 = (port as Dictionary)["at"]
		for box in fittings:
			var f: AABB = box
			if f.position.x - 0.4 <= at.x and at.x <= f.end.x + 0.4 \
					and f.position.z - 0.8 <= at.z and at.z <= f.end.z + 0.8 \
					and f.end.y >= roof + 1.0:
				standing += 1
				break
	_check("and_a_drawn_stack_stands_under_each_port", standing == STACKS,
		"%d of %d ports have drawn steel beneath them" % [standing, STACKS])


## EVERY DISTINCT COLOUR IN HER MESH IS TELLABLE FROM EVERY OTHER, in the mesh, because a mesh is where a check has to
## tell two parts apart. `modelling_here.md` section 6: a fleet-wide palette comparison asks whether two colours could
## EVER collide, which is the wrong question -- two colours in two different vehicles have nothing to do with each
## other. This walks her own drawn vertices and needs no roster of parts and no exemption.
func _every_colour_in_her_can_be_told_from_every_other(kind: int, geometry: Dictionary) -> void:
	var mesh: ArrayMesh = ShipHull.models(kind, geometry).get("near") as ArrayMesh
	if mesh == null:
		_check("every_colour_in_her_can_be_told_from_every_other", false, "no near mesh")
		return
	var seen: Array[Color] = []
	for surface in range(mesh.get_surface_count()):
		var colours: PackedColorArray = mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
		for c in colours:
			var known := false
			for k in seen:
				if absf(k.r - c.r) < 0.004 and absf(k.g - c.g) < 0.004 and absf(k.b - c.b) < 0.004:
					known = true
					break
			if not known:
				seen.append(c)
	var clashes: PackedStringArray = []
	for i in range(seen.size()):
		for j in range(i + 1, seen.size()):
			var a: Color = seen[i]
			var b: Color = seen[j]
			if maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b)) < COLOUR_APART:
				clashes.append("(%.2f,%.2f,%.2f)~(%.2f,%.2f,%.2f)" % [a.r, a.g, a.b, b.r, b.g, b.b])
	_check("every_colour_in_her_can_be_told_from_every_other", clashes.is_empty(),
		"%d distinct colours, %d too close%s" % [seen.size(), clashes.size(),
			"" if clashes.is_empty() else ": %s" % ", ".join(clashes)])


## THE EXTERIOR IS INSIDE ITS BUDGET, and the number is printed so the next lane can compare against something.
func _the_exterior_meets_its_budget(kind: int, geometry: Dictionary) -> void:
	var made: Dictionary = ShipHull.models(kind, geometry)
	var near: ArrayMesh = made.get("near") as ArrayMesh
	var far: ArrayMesh = made.get("far") as ArrayMesh
	var triangles: int = 0
	for surface in range(near.get_surface_count()):
		triangles += (near.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_check("the_exterior_meets_its_budget",
		triangles <= MOST_TRIANGLES and near.get_surface_count() <= MOST_SURFACES,
		"near %d triangles in %d surface(s), far %d surface(s); budget %d triangles"
		% [triangles, near.get_surface_count(), far.get_surface_count(), MOST_TRIANGLES])
	_check("and_she_reports_the_fittings_she_stands_on_the_ship",
		(made.get("fittings", []) as Array).size() >= 20,
		"%d fittings" % (made.get("fittings", []) as Array).size())


## LOADING THE MODEL CANNOT MOVE THE SIMULATION. `modelling_here.md` section 1: take a deep copy of the geometry, build
## the boat, and require the geometry to be untouched -- the model is presentation and the boundary is real.
func _the_asset_boundary_cannot_change_native_geometry(kind: int) -> void:
	var before: Dictionary = Sim.geometry_of(kind).duplicate(true)
	var view := (load("res://objects/vehicles/craft_fireboat.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.setup(0, kind)
	var after: Dictionary = Sim.geometry_of(kind)
	_check("the_asset_boundary_cannot_change_native_geometry", before == after,
		"extents %s, %d parts, %d seats" % [after.get("extents", Vector3.ZERO),
			(after.get("parts", []) as Array).size(), after.get("seats", 0)])
	view.queue_free()


## BOTH HELMS ARE IN THE WHEELHOUSE, side by side and facing forward -- which is the user's "at least 2 pilots", and is
## the thing a seat table gets wrong silently.
func _both_helms_are_in_the_wheelhouse(geometry: Dictionary) -> void:
	var seats: Array = geometry.get("seat_poses", []) as Array
	var room: Dictionary = Superstructure.part_of(geometry.get("parts", []) as Array, "bridge")
	if seats.size() < 2 or room.is_empty():
		_check("both_helms_are_in_the_wheelhouse", false,
			"%d seats, %s bridge" % [seats.size(), "no" if room.is_empty() else "a"])
		return
	var r: Rect2 = Wheelhouse.outline_rect(room["outline"])
	var inside: int = 0
	var apart: float = 0.0
	var places: Array[Vector3] = []
	for seat in seats:
		var at: Vector3 = seat.get("position", Vector3.ZERO)
		places.append(at)
		if r.has_point(Vector2(at.x, at.z)) and at.y >= float(room["bottom"]) - 0.05:
			inside += 1
	if places.size() >= 2:
		apart = absf(places[0].x - places[1].x)
	_check("both_helms_are_in_the_wheelhouse", inside == seats.size() and apart > 1.0,
		"%d of %d seats inside the wheelhouse, %.2f m apart across" % [inside, seats.size(), apart])


## THE NEAR MODEL'S OWN BOUNDS, from its transformed vertices. The FAR silhouette is skipped: it is the parts as prisms
## and measuring both together would let a wrong hull hide behind a right box.
func _near_bounds(view: VehicleView) -> AABB:
	var box := AABB()
	var any := false
	for child in view.find_children("Near", "MeshInstance3D", true, false):
		var drawn := child as MeshInstance3D
		if drawn.mesh == null:
			continue
		var into: Transform3D = view.global_transform.affine_inverse() * drawn.global_transform
		for surface in range(drawn.mesh.get_surface_count()):
			var vertices: PackedVector3Array = drawn.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point in vertices:
				var at: Vector3 = into * point
				box = box.expand(at) if any else AABB(at, Vector3.ZERO)
				any = true
	return box


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % " ".join(_failures)))
	get_tree().quit()


## THE HULL SKIN'S BEAM, found by the paint the lofted skin carries. `HullLoft` paints the topsides, the boot-top band
## and the antifouling from the palette it is handed, so the three of them together ARE the hull and nothing else in
## the mesh wears them. Anything bolted on -- fenders, the rub strake, bollards -- is a different colour and is left
## out, which is the whole point.
func _hull_beam(view: VehicleView) -> float:
	var wants: Array[Color] = [Fireboat.HULL_RED, Fireboat.BOOT, Fireboat.ANTIFOUL]
	var least: float = INF
	var most: float = -INF
	for child in view.find_children("Near", "MeshInstance3D", true, false):
		var drawn := child as MeshInstance3D
		if drawn.mesh == null:
			continue
		var into: Transform3D = view.global_transform.affine_inverse() * drawn.global_transform
		for surface in range(drawn.mesh.get_surface_count()):
			var arrays: Array = drawn.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			if colours.size() != points.size():
				continue
			for i in range(points.size()):
				var c: Color = colours[i]
				var mine := false
				for want in wants:
					if absf(c.r - want.r) < 0.01 and absf(c.g - want.g) < 0.01 and absf(c.b - want.b) < 0.01:
						mine = true
						break
				if not mine:
					continue
				var at: Vector3 = into * points[i]
				least = minf(least, at.x)
				most = maxf(most, at.x)
	return 0.0 if least > most else most - least


## HOW FAR THE WIDEST DRAWN THING REACHES EACH SIDE OF THE CENTRELINE, as (port, starboard). Two numbers rather than
## one width, because a width cannot tell a symmetric boat from a lopsided one.
func _widest_each_side(view: VehicleView) -> Vector2:
	var port: float = 0.0
	var starboard: float = 0.0
	for child in view.find_children("Near", "MeshInstance3D", true, false):
		var drawn := child as MeshInstance3D
		if drawn.mesh == null:
			continue
		var into: Transform3D = view.global_transform.affine_inverse() * drawn.global_transform
		for surface in range(drawn.mesh.get_surface_count()):
			var points: PackedVector3Array = drawn.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point in points:
				var at: Vector3 = into * point
				port = minf(port, at.x)
				starboard = maxf(starboard, at.x)
	return Vector2(port, starboard)


## THREE MONITORS, TWO FORWARD AND ONE AFT, which is what the user asked for in those words. Held against the
## SIMULATION'S table rather than against the model, because `gun_of` is what decides where they are and everything
## else follows it.
func _three_monitors_two_forward_and_one_aft(kind: int) -> void:
	var forward: int = 0
	var aft: int = 0
	var wrong: PackedStringArray = []
	for mount in range(MONITORS):
		var gun: Dictionary = Sim.gun_of(kind, mount)
		if not bool(gun.get("fitted", false)):
			wrong.append("mount %d is not fitted" % mount)
			continue
		if not bool(gun.get("water", false)):
			wrong.append("mount %d is not a water mount" % mount)
		var at: Vector3 = gun.get("at", Vector3.ZERO)
		if at.z < 0.0:
			forward += 1
		else:
			aft += 1
	# AND NO FOURTH. `kMaxTurrets` is 3, so a fourth could not exist -- but a mount that reports fitted past the
	# three would mean the table had been edited into a state the wire cannot carry.
	_check("three_monitors_two_forward_and_one_aft",
		wrong.is_empty() and forward == 2 and aft == 1,
		"%d forward, %d aft%s" % [forward, aft, "" if wrong.is_empty() else "; " + ", ".join(wrong)])
	# THE TRAVEL IS A MONITOR'S, not a gun's: it elevates well up and depresses a little, and it must not be able to
	# train right round onto its own wheelhouse.
	var first: Dictionary = Sim.gun_of(kind, 0)
	# THE ELEVATION IS ONE FIELD, NOT TWO. `gun_schema` publishes `pitch_range` as a Vector2 of (low, high); asking it
	# for `pitch_low` got 0.0 twice and the check read "elevation 0.00 to 0.00 rad" -- a monitor that cannot elevate,
	# reported by a test that was reading a key nobody writes. A `get` with a default cannot tell a missing field from
	# a field that is genuinely zero, which is worth remembering every time one is written.
	var travel: Vector2 = first.get("pitch_range", Vector2.ZERO)
	_check("and_a_monitor_trains_and_elevates_like_a_monitor",
		travel.y > 1.2 and travel.x < 0.0
			and float(first.get("yaw_span", 9.0)) < 3.0 and float(first.get("slew", 9.0)) < 1.0,
		"elevation %.2f to %.2f rad (%.0f to %.0f deg), train +/-%.2f, slew %.2f rad/s"
		% [travel.x, travel.y, rad_to_deg(travel.x), rad_to_deg(travel.y),
			first.get("yaw_span", 0.0), first.get("slew", 0.0)])


## EACH MONITOR IS DRAWN ON ITS MOUNT, and stands on a pedestal. `modelling_here.md` section 6: assert what is DRAWN,
## not only what is computed -- the simulation declaring three mounts says nothing about three nozzles existing.
func _each_monitor_is_drawn_on_its_mount(view: VehicleView) -> void:
	var drawn: int = 0
	var stood: int = 0
	# SEARCHED RECURSIVELY, because the mounts are children of `Body` and not of the view itself. A direct
	# `get_node_or_null("Turret0")` came back null and the check reported "0 of 3 mounts carry a Monitor" on a boat
	# that was drawing all three -- the test looking in the wrong place, read as the model being empty.
	for mount in range(MONITORS):
		var turret: Node = view.find_child("Turret%d" % mount, true, false)
		if turret != null and turret.find_child("Monitor", true, false) != null:
			drawn += 1
		if view.find_child("Turret%dPedestal" % mount, true, false) != null:
			stood += 1
	_check("each_monitor_is_drawn_on_its_mount", drawn == MONITORS,
		"%d of %d mounts carry a Monitor mesh" % [drawn, MONITORS])
	# THE PEDESTAL IS A SIBLING AND NOT A CHILD, which is the whole reason it is checked separately: drawn as a child
	# it would lie over on its side every time the crew depressed the monitor, and no dimension check would see it.
	_check("and_each_stands_on_a_pedestal_that_does_not_elevate", stood == MONITORS,
		"%d of %d pedestals, and each is a sibling of its mount" % [stood, MONITORS])


## A MONITOR THROWS WATER AND FIRES NOTHING, DRIVEN THROUGH THE REAL PATH. `Sim.fire_gun` is the call a trigger ends
## up at, and it is bound straight to GDScript -- which is exactly why the gate lives in `fire_round` and not at the
## seat's dispatch, where it was written first and would have left this hole open.
##
## THE MUTANT: delete `if (gun.water) return 0;` from `fire_round` and this goes red, because a fireboat starts
## putting tracer out of a fire hose.
func _a_monitor_throws_water_and_fires_nothing(kind: int) -> void:
	# A WORLD OF ITS OWN, as `tests/air.gd` does, so the check does not depend on a session being up.
	var sea: Object = ClassDB.instantiate("CockpitWorld")
	sea.set_tick_rate(120.0)
	sea.start(0)
	var vehicle: int = int(sea.spawn_vehicle(kind, Vector3(0.0, 0.0, 0.0), 0.0, Vector3.ZERO))
	if vehicle == 0:
		_check("a_monitor_throws_water_and_fires_nothing", false, "could not spawn a fireboat")
		return
	sea.tick(1.0 / 120.0)
	var rounds: PackedStringArray = []
	for mount in range(MONITORS):
		var round_id: int = int(sea.fire_gun_pulled(vehicle, mount, 1.0))
		if round_id != 0:
			rounds.append("mount %d fired round %d" % [mount, round_id])
	# AND THE CONTROL, WITHOUT WHICH THIS CHECK CANNOT FAIL: the same call on a craft whose mount is a real gun must
	# return a round. Otherwise `fire_gun_pulled` returning 0 for some unrelated reason -- no world, no ammunition,
	# a reload not elapsed -- would read as "the monitor refused" and the check would pass for ever while the gate
	# it is testing did nothing (`testing_godot_headless.md`, the tautology trap).
	var gunboat: int = int(sea.spawn_vehicle(Sim.Kind.GUNBOAT, Vector3(400.0, 0.0, 0.0), 0.0, Vector3.ZERO))
	sea.tick(1.0 / 120.0)
	var control: int = int(sea.fire_gun_pulled(gunboat, 0, 1.0))
	_check("and_a_real_gun_on_the_same_call_does_fire", control != 0,
		"the gunboat's mount 0 returned round %d on the identical call" % control)
	_check("a_monitor_throws_water_and_fires_nothing", rounds.is_empty(),
		"three monitors, trigger fully pulled%s" % ["; " + ", ".join(rounds) if not rounds.is_empty() else ", no round"])


## ONE OPERATOR PER MONITOR, and the helms are not among them. The turret seats take mounts in SEAT ORDER, so the
## count and the order both matter: a craft with two turret seats and three monitors leaves one nozzle unworked.
func _one_operator_per_monitor(geometry: Dictionary) -> void:
	var seats: Array = geometry.get("seat_poses", []) as Array
	var flying: int = 0
	var operators: int = 0
	for seat in seats:
		if String(seat.get("station", "")) == "turret":
			operators += 1
		elif bool(seat.get("flies", false)):
			flying += 1
	_check("one_operator_per_monitor", operators == MONITORS and flying >= 2,
		"%d seats: %d who fly her, %d monitor operators, %d monitors"
		% [seats.size(), flying, operators, MONITORS])
	# SHE IS THE FIRST CRAFT HERE WITH MORE THAN FOUR SEATS, so say the number out loud: if a later change silently
	# capped seats again this is where it would show.
	_check("and_she_carries_more_than_four_seats", seats.size() == 5,
		"%d seats, the first craft past four since lane/seats retired the cap" % seats.size())
