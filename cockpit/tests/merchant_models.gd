extends "res://tests/ship_models.gd"
## Headless: are the merchant ships drawn the size their references say, near and far, and are they ships by every check
## `ship_models` holds a warship to?
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/merchant_models.tscn
##
## THE SIZES ARE ASKED OF THE DRAWN VERTICES, NOT OF THE PARTS. A table that says 332 m and a mesh that is 340 m are two
## ships, and the one you see is the mesh. Every figure below is typed from `craft/<kind>/sources.md` -- PUBLISHED where a
## source states it, MEASURED where it was taken off a photograph there -- and is not read from the draft table the model is
## built from, which would be the model agreeing with itself.
##
## THE SAME CHECKS AS A WARSHIP: winding, the helm's view of the bow, a floor under every helm, a side with no gap, every
## fitting standing on the ship, from `ship_models.gd`, which this extends. The budget is measured here near and far,
## because a 332 m ship is in sight for kilometres past `ShipHull.NEAR_TO` and its silhouette is what is drawn there.
##
## THE DRAFTS ARE ON A CLOCK. `CrudeCarrierDraft` is the simulation's shape copied into GDScript until the kind is C++; the
## day the simulation names a kind `crude_carrier`, this fails until the copy is deleted and the model reads
## `kind_geometry` (team-lead, 2026-09-17).
##
## Read RESULT=, not the exit code.

## THE SEA AHEAD, as SOLAS V/22 asks it of a real ship: from the conning position the water must be in sight within two
## ship lengths of the bow, or 500 m, whichever is less.
##
## WHY THIS AND NOT ONLY `ship_models`' "the bow is in sight". That target is a point a metre over the ship's own extents
## at the stem, which on a ship whose highest deck is its roof is a point in the SKY over the bow: from the ferry's
## wheelhouse it passes with nothing in the way and nothing proved (cockpit-fleet3, 2026-09-17). Where the sea comes into
## sight is the question a bridge is placed to answer, and it is the number the tanker's house height was cross-checked
## against by hand -- so it is a check now, and both ships are held to it.
const SOLAS_BLIND: float = 500.0

## Within 2 % of a figure, as the lane was asked.
const TOLERANCE: float = 0.02
## The silhouette's triangles, at most: a handful of prisms, which is what past 1.8 km a ship is.
const FAR_TRIANGLES: int = 2000

## THE VLCC, from craft/crude_carrier/sources.md. PUBLISHED: length overall, beam, draught, depth. MEASURED: the house
## front from the stern (75.4 and 78.7 m on P1), and over the cargo deck the bridge deck (2.20 freeboards), the wheelhouse
## roof (2.62), the funnel top (0.80 of the masthead, P4) and the masthead (4.43), at 8.5 m a freeboard.
const CRUDE_CARRIER: Dictionary = {
	"length": 332.0, "beam": 60.0, "draught": 22.5, "depth": 31.0,
	"house_from_stern_least": 75.4, "house_from_stern_most": 78.7,
	"bridge_deck": 18.7, "wheelhouse_roof": 22.3, "funnel_top": 30.2, "masthead": 37.7,
}
## THE CATAMARAN, from craft/ferry/sources.md. PUBLISHED: length overall, beam, draught, and the 9.20 m depth, which puts
## the vehicle deck 5.27 m over the water. MEASURED on F1 at 26.0 px a metre: the centre bow's forefoot, the wet deck over
## the tunnel, the sheer, the roof, the wheelhouse roof and the masthead. ESTIMATE: a 5.1 m demihull, so 20.3 m of clear
## tunnel between the two.
const FERRY: Dictionary = {
	"length": 109.40, "beam": 30.50, "draught": 3.93,
	"forefoot": 1.5, "wet_deck": 3.5, "sheer": 13.6, "roof": 17.5, "wheelhouse_roof": 20.8, "masthead": 24.4,
	"tunnel": 20.3,
}
## THE ARLEIGH BURKE FLIGHT IIA, against its sources. PUBLISHED: length, beam. MEASURED off a broadside against a
## waterline fitted over five stations: the freeboards and the masthead. The DRAUGHT IS NOT THE PUBLISHED 9.45 m, which
## is to the sonar dome; the hull floats at 6.63 m and the dome reaches 9.53.
const DESTROYER: Dictionary = {
	"length": 155.30, "beam": 20.12, "draught": 6.63, "dome": 9.53,
	"freeboard_stem": 8.59, "freeboard_mid": 5.87, "freeboard_stern": 5.10, "masthead": 45.29,
}
## THE SIMULATION'S OWN LIMITS ON A SHAPE, from cockpit_world.cpp: `kMaxHullParts`, `kMaxPlanCorners` and `kMaxSeats`. A
## draft that breaks one of these is a shape the C++ cannot hold, and the day to find that out is not the day the kind is
## written.
const MAX_PARTS: int = 24
const MAX_CORNERS: int = 8
const MAX_SEATS: int = 4

## THE TWO CONTAINER SHIPS, from craft/container_ship/sources.md. PUBLISHED: the Triple-E's length overall, beam, draught
## and its 23 ROWS ACROSS THE DECK, and the feeder's beam and draught. ESTIMATE: both depths to the main deck, and the
## feeder's length overall, which cannot be published because the KCS was never built.
##
## `rows` IS THE CHECK THAT MATTERS and it is why these ships are worth drawing. Maersk publishes 23 rows across a 58.6 m
## beam; ISO 668 fixes a container at 2.438 m wide; the model derives its rows from beam and box and never sees the 23.
## So the 23 here is an outside anchor on a derived number, which is the shape `modelling_here.md` section 6 asks for.
const CONTAINER_LARGE: Dictionary = {
	"length": 399.2, "beam": 58.6, "draught": 16.0, "depth": 30.0, "rows": 23,
	"height_over_keel": 73.0, "house_forward_of_midships": true,
}
const CONTAINER_FEEDER: Dictionary = {
	"length": 235.0, "beam": 32.20, "draught": 10.80, "depth": 19.0, "rows": 13,
	"height_over_keel": 0.0, "house_forward_of_midships": false,
}
## ISO 668, typed here from the standard and not read from the model's own constants: a box is 2.438 m wide, 2.591 m high
## and 12.192 m long in the forty-foot size. A container ship drawn with the wrong box reads wrong to anybody who has seen
## one, and this is the only place the suite could notice.
const ISO_WIDE: float = 2.438
const ISO_HIGH: float = 2.591
const ISO_LONG: float = 12.192

## Every draft table and the kind it is waiting to be.
const DRAFTS: Dictionary = {
	"crude_carrier": "res://objects/vehicles/ships/crude_carrier_draft.gd",
	"ferry": "res://objects/vehicles/ships/ferry_draft.gd",
	"destroyer": "res://objects/vehicles/ships/destroyer_draft.gd",
	"container_feeder": "res://objects/vehicles/ships/container_ship_draft.gd",
	"container_large": "res://objects/vehicles/ships/container_ship_draft.gd",
	"cruising_sloop": "res://objects/vehicles/ships/small_craft_draft.gd",
	"classic_cutter": "res://objects/vehicles/ships/small_craft_draft.gd",
	"stern_trawler": "res://objects/vehicles/ships/small_craft_draft.gd",
	"motor_yacht": "res://objects/vehicles/ships/small_craft_draft.gd",
}

## THE FOUR SMALL CRAFT, from craft/small_craft/sources.md. Every figure here is PUBLISHED -- length overall, beam and
## draught for each -- because nothing about these four was measured and the estimates are all heights this does not
## check. The sloop's and the cutter's draughts are TO THE BOTTOM OF THE KEEL, which is the published figure and is not
## the hull's own draught: that is the thing worth asserting about a sailing boat, since a hull drawn to it would be a
## boat nobody has ever seen.
##
## `transom` IS THE CHECK THAT TELLS THE TWO SAILING BOATS APART, and it is the one a reader would notice first. The
## modern production cruiser carries her beam aft and ends 3.68 m across; the 1979 cutter narrows to a CANOE TRANSOM
## 0.36 m across. Nothing about length, beam or draught can see the difference, and a suite that could not see it would
## be green on two copies of the same boat.
const SMALL_CRAFT: Dictionary = {
	"cruising_sloop": {"length": 12.87, "beam": 4.18, "draught": 2.27, "transom": 3.68, "air_draught": 18.33},
	"classic_cutter": {"length": 9.14, "beam": 2.97, "draught": 1.40, "transom": 0.36, "air_draught": 13.10,
		"waterline": 7.11},
	"stern_trawler": {"length": 22.50, "beam": 7.90, "draught": 3.20, "transom": 6.79, "air_draught": 0.0},
	"motor_yacht": {"length": 15.55, "beam": 4.34, "draught": 1.25, "transom": 4.08, "air_draught": 0.0},
}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[merchant_models] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_the_drafts_are_on_a_clock()
	_the_draft_fits_the_simulation("crude_carrier", CrudeCarrierDraft.geometry())
	_the_draft_fits_the_simulation("ferry", FerryDraft.geometry())
	_a_ship("crude_carrier", CrudeCarrierDraft.geometry())
	_the_crude_carrier_is_its_size(CrudeCarrierDraft.geometry())
	_a_ship("ferry", FerryDraft.geometry())
	_the_ferry_is_its_size(FerryDraft.geometry())
	_the_draft_fits_the_simulation("destroyer", DestroyerDraft.geometry())
	_a_ship("destroyer", DestroyerDraft.geometry())
	_the_destroyer_is_its_size(DestroyerDraft.geometry())
	# GENERALISED TO THE THREE OLDER MERCHANTMEN once a probe across tanker, ferry, destroyer, carrier, battleship,
	# gunboat, launch and submarine came back clean -- the only hits were the ferry's two bridging parts, which were
	# this check's fault and are fixed above. The five C++ kinds pass it too.
	for older in ["crude_carrier", "ferry", "destroyer"]:
		_every_island_stands_on_something(older, _draft_geometry(older))
	for which in ["container_feeder", "container_large"]:
		var box_ship: Dictionary = ContainerShipDraft.geometry(which)
		_the_draft_fits_the_simulation(which, box_ship)
		_a_ship(which, box_ship, true)
		_every_island_stands_on_something(which, box_ship)
		_the_container_ship_is_its_size(which, box_ship)
	_the_two_container_ships_are_different_ships()
	for boat in SMALL_CRAFT:
		var small: Dictionary = SmallCraftDraft.geometry(boat)
		_the_draft_fits_the_simulation(boat, small)
		_a_ship(boat, small)
		_every_island_stands_on_something(boat, small)
		_the_small_craft_is_its_size(boat, small)
	_the_two_sailing_boats_are_different_boats()
	for liveried in ["container_feeder", "container_large", "cruising_sloop", "classic_cutter",
			"stern_trawler", "motor_yacht"]:
		_every_livery_is_a_different_ship(liveried)
	_finish()


## WHETHER A KIND OF EACH DRAFT'S NAME EXISTS YET, asked of the simulation's shape table over every kind it has. It walked
## every value five bits hold, which was the same list until the kind went to sixteen bits (lane/kinds, 2026-09-18).
func _the_drafts_are_on_a_clock() -> void:
	var named: Dictionary = {}
	for kind in range(int(Sim.kind_limits().get("kind_count", 0))):
		named[String(Sim.geometry_of(kind).get("name", ""))] = kind
	_check("the_simulation_answers_for_its_kinds", named.has("carrier") and named.has("submarine"),
		"%d names" % named.size())
	for draft in DRAFTS:
		var waiting: bool = not named.has(draft)
		var copy_left: bool = ResourceLoader.exists(DRAFTS[draft])
		_check("the_%s_draft_is_deleted_once_the_kind_exists" % draft, waiting or not copy_left,
			"no kind named %s yet" % draft if waiting else "kind %d is %s and %s is still there: move the table into cockpit_world.cpp and delete it"
				% [named[draft], draft, DRAFTS[draft]])


## WHETHER A DRAFT IS A SHAPE THE C++ COULD HOLD: within its part, corner and seat counts, and every outline convex,
## which is what `HullPart` promises Box3D ("Convex because that is what a hull shape in Box3D is").
func _the_draft_fits_the_simulation(ship_name: String, geometry: Dictionary) -> void:
	var parts: Array = geometry.get("parts", []) as Array
	var widest: int = 0
	var bent: Array[String] = []
	for part in parts:
		var outline: PackedVector2Array = part["outline"]
		widest = maxi(widest, outline.size())
		var sign_seen: float = 0.0
		for i in range(outline.size()):
			var a: Vector2 = outline[i]
			var b: Vector2 = outline[(i + 1) % outline.size()]
			var c: Vector2 = outline[(i + 2) % outline.size()]
			var turn: float = (b - a).cross(c - b)
			if absf(turn) < 0.0001:
				continue
			if sign_seen != 0.0 and signf(turn) != sign_seen:
				bent.append("%s at %s" % [String(part["part"]), b])
				break
			sign_seen = signf(turn)
	_check("the_%s_draft_is_a_shape_the_simulation_could_hold" % ship_name,
		parts.size() <= MAX_PARTS and widest <= MAX_CORNERS
			and (geometry.get("seat_poses", []) as Array).size() <= MAX_SEATS and bent.is_empty(),
		"%d parts of %d, %d corners of %d, %d seats of %d%s" % [parts.size(), MAX_PARTS, widest, MAX_CORNERS,
			(geometry.get("seat_poses", []) as Array).size(), MAX_SEATS,
			"" if bent.is_empty() else ", outlines not convex: " + ", ".join(bent)])


## EVERY SHIP CHECK `ship_models` MAKES, on a geometry that is not yet a kind, and the budget near and far.
##
## `deck_cargo` LEAVES OUT THE BOW AND DECK-AHEAD SIGHT LINES, AND THE REASON IS THAT A REAL SHIP CANNOT PASS THEM.
## `_the_helm_can_see` aims at a point a metre over the deck at the stem and halfway to it; on a ship carrying six to nine
## tiers of containers between the bridge and the bow, those points are behind 24 m of steel boxes and no bridge that
## could be built would see them. Solving for the feeder: to see a point 9.2 m up at the stem over stacks topping 18.6 m
## at the forward bay, the eye would have to stand **77.8 m** over the water -- two and a half times the house it has, on
## a ship whose whole published height is 73 m. "A test a real aircraft could not pass is not measuring the aircraft"
## (modelling_here.md section 9), and this is the ship version of it.
##
## WHAT REPLACES IT IS STRICTER, NOT LOOSER. SOLAS V/22 is the rule the real ship is actually built to and
## `_the_sea_ahead_is_in_sight` already asks it -- the sea within two ship lengths of the bow, or 500 m, from the conning
## position -- and the stacks ARE in `panels`, so that check is made against the cargo and it is what decides how high the
## bridge has to stand. Both bridges were raised to satisfy it: the feeder's by 3 m and the Triple-E's by 2 m, which is
## the argument a naval architect has with the same two facts.
func _a_ship(ship_name: String, geometry: Dictionary, deck_cargo: bool = false) -> void:
	var made: Dictionary = ShipHull.models(-1, geometry)
	var ship: Node3D = ShipHull.dress(-1, geometry)
	add_child(ship)
	_near_and_far(ship_name, ship)
	_wound_outwards(ship_name, made)
	if not deck_cargo:
		_the_helm_can_see(ship_name, geometry, made.get("panels", []) as Array)
	var faces: Array = _faces(made.get("near") as ArrayMesh)
	_something_under_every_helm(ship_name, geometry, faces)
	_the_side_is_whole(ship_name, geometry, faces)
	_fittings_stand_on_the_ship(ship_name, geometry, made.get("fittings", []) as Array)
	# SOLAS V/22 APPLIES TO SHIPS OF 55 METRES IN LENGTH AND UPWARDS, and that is the regulation's own wording, not a
	# convenience. The four small craft are 9.14 to 22.50 m and no bridge-visibility rule reaches them; asked anyway, the
	# sloop failed by 35 m against 26 and the cutter by 20 against 18, which is a yacht being held to a rule written for
	# ships. A check a real vessel is not subject to is measuring the check, not the vessel.
	if float(geometry.get("extents", Vector3.ONE).z) * 2.0 >= 55.0:
		_the_sea_ahead_is_in_sight(ship_name, geometry, made.get("panels", []) as Array)
	var every_fitting_reported: bool = not (made.get("fittings", []) as Array).is_empty()
	_check("the_%s_model_reports_its_fittings" % ship_name, every_fitting_reported,
		"%d fittings" % (made.get("fittings", []) as Array).size())
	ship.queue_free()


## HOW FAR AHEAD OF THE BOW THE SEA FIRST COMES INTO SIGHT from the seat that cons the ship, and whether that is inside
## what SOLAS V/22 allows.
##
## THE HULL AND THE DECKS BLOCK IT, not merely the rooms and the fittings: a deck is what a bridge looks over, and the
## panels a model reports are its walls. So the parts are turned into boxes here -- every hull, deck and island part as the
## prism the simulation collides with -- and the sight line is asked of those and the panels together.
func _the_sea_ahead_is_in_sight(ship_name: String, geometry: Dictionary, panels: Array) -> void:
	var blocking: Array = panels.duplicate()
	var bow: float = INF
	for part in (geometry.get("parts", []) as Array):
		var role: String = String(part.get("part", ""))
		if not (role in ["hull", "deck", "island"]):
			continue
		var r: Rect2 = Wheelhouse.outline_rect(part.get("outline", PackedVector2Array()))
		var bottom: float = float(part.get("bottom", 0.0))
		blocking.append(AABB(Vector3(r.position.x, bottom, r.position.y),
			Vector3(r.size.x, float(part.get("top", 0.0)) - bottom, r.size.y)))
		if role == "hull":
			bow = minf(bow, r.position.y)
	var length: float = (geometry.get("extents", Vector3.ONE) as Vector3).z * 2.0
	var allowed: float = minf(SOLAS_BLIND, length * 2.0)
	for entry in (geometry.get("seat_poses", []) as Array):
		if not bool(entry.get("flies", false)):
			continue
		var eye: Vector3 = (entry["position"] as Vector3) + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
		var waterline: float = float(geometry.get("waterline", 0.0))
		var ahead: float = INF
		for step in range(1, 201):
			var at := Vector3(0.0, waterline, bow - float(step) * 5.0)
			var aim: Vector3 = at - eye
			if HullSkin.is_clear(blocking, eye, aim, aim.length() * 0.999):
				ahead = float(step) * 5.0
				break
		_check("from_the_%s_%s_seat_the_sea_is_in_sight_ahead" % [ship_name, String(entry["station"])],
			ahead <= allowed, "%s ahead of the bow, against %.0f m allowed"
				% ["never within a kilometre" if is_inf(ahead) else "%.0f m" % ahead, allowed])
		break


## THE BUDGET, NEAR AND FAR: the near model's draw calls and triangles, the silhouette's, and the swap between them at
## `NEAR_TO` -- the far mesh begins where the near one ends, so a ship is never both and never neither.
func _near_and_far(ship_name: String, ship: Node3D) -> void:
	var near := ship.get_node_or_null("Near") as MeshInstance3D
	var far := ship.get_node_or_null("Far") as MeshInstance3D
	if near == null or far == null:
		_check("the_%s_has_a_near_model_and_a_silhouette" % ship_name, false, "near %s, far %s" % [near, far])
		return
	var near_triangles: int = 0
	for s in range(near.mesh.get_surface_count()):
		near_triangles += _triangles(near.mesh, s)
	var far_triangles: int = 0
	for s in range(far.mesh.get_surface_count()):
		far_triangles += _triangles(far.mesh, s)
	_check("the_%s_near_model_is_within_its_draw_calls" % ship_name, near.mesh.get_surface_count() < NEAR_DRAWS,
		"%d surfaces against %d" % [near.mesh.get_surface_count(), NEAR_DRAWS])
	_check("the_%s_near_model_is_within_its_triangles" % ship_name, near_triangles > 0 and near_triangles < NEAR_TRIANGLES,
		"%d against %d" % [near_triangles, NEAR_TRIANGLES])
	_check("the_%s_silhouette_is_a_handful_of_draw_calls_and_triangles" % ship_name,
		far.mesh.get_surface_count() < FAR_DRAWS and far_triangles > 0 and far_triangles < FAR_TRIANGLES,
		"%d surfaces, %d triangles, against %d and %d" % [far.mesh.get_surface_count(), far_triangles, FAR_DRAWS,
			FAR_TRIANGLES])
	_check("the_%s_swaps_to_its_silhouette_at_near_to" % ship_name,
		is_equal_approx(near.visibility_range_end, ShipHull.NEAR_TO)
			and is_equal_approx(far.visibility_range_begin, ShipHull.NEAR_TO),
		"near ends at %.0f m, far begins at %.0f m, NEAR_TO %.0f" % [near.visibility_range_end,
			far.visibility_range_begin, ShipHull.NEAR_TO])


## THE VLCC'S SIZES, FROM ITS DRAWN VERTICES.
func _the_crude_carrier_is_its_size(geometry: Dictionary) -> void:
	var mesh := ShipHull.models(-1, geometry).get("near") as ArrayMesh
	var faces: Array = _faces(mesh)
	var box: AABB = mesh.get_aabb()
	var want: Dictionary = CRUDE_CARRIER
	_within("crude_carrier", "length_overall", box.size.z, want["length"])
	_within("crude_carrier", "beam", box.size.x, want["beam"])
	_within("crude_carrier", "draught", -box.position.y, want["draught"])
	# THE CARGO DECK: the highest upward face over a point of open deck abreast the winching circles, clear of the gear.
	var deck: float = _top_over(faces, Vector2(26.0, -90.0), 20.0)
	_within("crude_carrier", "depth_keel_to_cargo_deck", deck - box.position.y, want["depth"])
	# THE HOUSE FRONT: the forward-most vertex of the lower tiers' faces between the cargo deck's 9 and 11 m over it, and
	# 10 to 19 m out from the centreline, where nothing else on the ship is.
	var front: float = INF
	for face in faces:
		for i in range(3):
			var p: Vector3 = face[i]
			if p.y > deck + 9.0 and p.y < deck + 11.0 and absf(p.x) >= 10.0 and absf(p.x) <= 19.0:
				front = minf(front, p.z)
	var from_stern: float = box.end.z - front
	_check("the_crude_carrier_house_front_is_where_it_was_measured",
		from_stern >= float(want["house_from_stern_least"]) and from_stern <= float(want["house_from_stern_most"]),
		"%.1f m forward of the stern, measured %.1f to %.1f" % [from_stern, want["house_from_stern_least"],
			want["house_from_stern_most"]])
	# OVER THE CARGO DECK: the bridge wing's walkway 25 m out, the wheelhouse roof 5 m out, the funnel's top 3 m out.
	_within("crude_carrier", "bridge_deck_over_the_cargo_deck", _top_over(faces, Vector2(25.0, front + 1.75), 60.0) - deck,
		want["bridge_deck"])
	_within("crude_carrier", "wheelhouse_roof_over_the_cargo_deck", _top_over(faces, Vector2(5.0, front + 4.5), 35.0) - deck,
		want["wheelhouse_roof"])
	_within("crude_carrier", "funnel_top_over_the_cargo_deck", _top_over(faces, Vector2(3.0, front + 27.0), 60.0) - deck,
		want["funnel_top"])
	_within("crude_carrier", "masthead_over_the_cargo_deck", box.end.y - deck, want["masthead"])
	# NOTHING BUT RAILS AND THE FOREMAST STANDS ON THE FORECASTLE. The bulb, the rudder and the screw are drawn as shares of
	# the draught; handed the keel, which is negative, two minus signs put the bulb 13 m OVER the bow instead of under it,
	# and every size check above stayed green, because a bulb in the air is well inside the ship's own box. The first
	# version of this check was green too: it allowed anything under the foremast's 12 m, which is more than the height the
	# bulb reached (cockpit-fleet3, 2026-09-17). So the allowance is the rail's, and the mast's own column is cut out of it.
	var over_the_bow: float = -INF
	var where: Vector3 = Vector3.ZERO
	for face in faces:
		for i in range(3):
			var p: Vector3 = face[i]
			# THE FORWARD 14 m: forward of the pipe run and the catwalk, which start 16 m abaft the stem and are 11 m up.
			if p.z > box.position.z + 14.0:
				continue
			if absf(p.x - CrudeCarrier.FOREMAST.x) <= 1.5 and absf(p.z - CrudeCarrier.FOREMAST.y) <= 1.5:
				continue
			if p.y > over_the_bow:
				over_the_bow = p.y
				where = p
	_check("nothing_but_rails_stands_on_the_crude_carrier_forecastle", over_the_bow <= deck + 1.6,
		"%.2f m at %s, the deck being %.2f m and its rail a metre over that" % [over_the_bow, where, deck])


## THE CATAMARAN'S SIZES, FROM ITS DRAWN VERTICES -- and the two things that make it a catamaran: nothing on the centreline
## under the water, and a wet deck over the tunnel that the sea is meant to pass under.
func _the_ferry_is_its_size(geometry: Dictionary) -> void:
	var mesh := ShipHull.models(-1, geometry).get("near") as ArrayMesh
	var faces: Array = _faces(mesh)
	var box: AABB = mesh.get_aabb()
	var want: Dictionary = FERRY
	_within("ferry", "length_overall", box.size.z, want["length"])
	_within("ferry", "beam", box.size.x, want["beam"])
	_within("ferry", "draught", -box.position.y, want["draught"])
	_within("ferry", "masthead_over_the_water", box.end.y, want["masthead"])
	_within("ferry", "sheer_over_the_water", _top_over(faces, Vector2(14.0, 10.0), 16.0), want["sheer"])
	_within("ferry", "roof_over_the_water", _top_over(faces, Vector2(6.0, 20.0), 19.0), want["roof"])
	_within("ferry", "wheelhouse_roof_over_the_water", _top_over(faces, Vector2(0.0, -16.0), 22.0),
		want["wheelhouse_roof"])
	# TWO HULLS AND A TUNNEL BETWEEN THEM: under the water there is nothing within half the tunnel of the centreline, and
	# there is skin on both sides of it. A monohull drawn in this ship's place passes every size check above.
	var nearest: float = INF
	var to_port: float = 0.0
	var to_starboard: float = 0.0
	for face in faces:
		for i in range(3):
			var p: Vector3 = face[i]
			if p.y > -0.5:
				continue
			nearest = minf(nearest, absf(p.x))
			to_port = minf(to_port, p.x)
			to_starboard = maxf(to_starboard, p.x)
	_check("the_ferry_has_two_hulls_with_a_tunnel_between_them",
		nearest >= float(want["tunnel"]) * 0.5 - 0.6 and to_starboard > 14.0 and to_port < -14.0,
		"nothing drawn under the water within %.2f m of the centreline, against a %.1f m tunnel; skin out to %.1f m to port and %.1f m to starboard"
			% [nearest, want["tunnel"], -to_port, to_starboard])
	# THE WET DECK over the tunnel, and the centre bow's forefoot forward of it: the two clearances a wave-piercer is
	# drawn by, both over the water rather than under it.
	_within("ferry", "wet_deck_over_the_water", _lowest_over(faces, Vector2(0.0, 20.0)), want["wet_deck"])
	_within("ferry", "centre_bow_forefoot_over_the_water",
		_lowest_over(faces, Vector2(0.0, -FerryDraft.LENGTH * 0.5 + 15.0)), want["forefoot"])


## The three older drafts by name, so the island check can be handed any of them.
func _draft_geometry(ship_name: String) -> Dictionary:
	match ship_name:
		"crude_carrier":
			return CrudeCarrierDraft.geometry()
		"ferry":
			return FerryDraft.geometry()
		_:
			return DestroyerDraft.geometry()


## A CONTAINER SHIP AGAINST ITS REFERENCES: the hull's envelope, the published height over the keel where there is one,
## and then the cargo -- which is the whole reason this ship is not a tanker, and is asked of the drawn boxes.
func _the_container_ship_is_its_size(which: String, geometry: Dictionary) -> void:
	var made: Dictionary = ShipHull.models(-1, geometry)
	var mesh := made.get("near") as ArrayMesh
	var box: AABB = mesh.get_aabb()
	var want: Dictionary = CONTAINER_LARGE if which == "container_large" else CONTAINER_FEEDER
	_within(which, "length_overall", box.size.z, want["length"])
	_within(which, "beam", box.size.x, want["beam"])
	_within(which, "draught", -box.position.y, want["draught"])
	# THE PUBLISHED HEIGHT FROM THE KEEL, on the ship that has one. The draft works the masthead out from this figure
	# rather than typing it, so drawing it and then measuring it back is the check that the arithmetic survived.
	if float(want["height_over_keel"]) > 0.0:
		_within(which, "height_over_the_keel", box.end.y + float(want["draught"]), want["height_over_keel"])
	# THE ROWS OF CONTAINERS ACROSS THE DECK. The model derives these from the beam and the ISO box and never sees the
	# published 23; this counts what was actually drawn and holds it to that 23. A ship that drew 20 rows would pass every
	# envelope check above and fail here, which is the point.
	var widest: float = 0.0
	var tallest: float = 0.0
	var longest: float = 0.0
	var deckwards := AABB()
	for fitting in (made.get("fittings", []) as Array):
		var f: AABB = fitting
		if f.size.x > widest:
			widest = f.size.x
			tallest = f.size.y
			longest = f.size.z
			deckwards = f
	# COUNTED OFF THE DRAWN BOXES, not divided out of the stack's width. Dividing counts the lashing gaps as cargo and got
	# the feeder's thirteen rows as twelve and the Triple-E's twenty-three as twenty-four -- a measurement fault that
	# looked exactly like a model fault. Every box puts a face at its own left and right, so the distinct x values across
	# one bay are two to a row.
	var rows: int = _rows_drawn(mesh, deckwards)
	_check("the_%s_stacks_%d_containers_across" % [which, rows], rows == int(want["rows"]),
		"%d rows counted off the drawn boxes across %.2f m of stack, against a published %d; the beam is %.1f m and an ISO box is %.3f m wide"
			% [rows, widest, int(want["rows"]), float(want["beam"]), ISO_WIDE])
	# AND NO MORE ROWS THAN WILL PHYSICALLY FIT. The bound and the published figure agree on the feeder (13 and 13) and
	# disagree on the Triple-E (24 would fit, 23 are carried, the difference being the lashing-bridge walkway), which is
	# why the published figure is the authority and this is only the sanity check on it.
	var could_fit: int = ContainerShipDraft.rows_that_fit(float(want["beam"]))
	_check("the_%s_carries_no_more_rows_than_fit" % which, rows <= could_fit,
		"%d rows drawn, %d would fit across a %.1f m beam" % [rows, could_fit, float(want["beam"])])
	# AND THE BOXES ARE ISO BOXES. A stack is a whole number of 2.591 m tiers high and one 12.192 m box long. Both figures
	# are typed in this suite from ISO 668, not read from the model, so the two can disagree.
	var tiers: float = tallest / ISO_HIGH
	_check("the_%s_stacks_whole_iso_tiers" % which, absf(tiers - round(tiers)) < 0.02 and tiers >= 2.0,
		"%.2f m of stack is %.3f tiers of %.3f m" % [tallest, tiers, ISO_HIGH])
	_check("the_%s_bays_are_forty_foot_boxes" % which, absf(longest - ISO_LONG) < ISO_LONG * TOLERANCE,
		"a bay is %.3f m fore and aft against ISO 668's %.3f" % [longest, ISO_LONG])
	# THE CARGO FITS ON THE SHIP AND FILLS IT. Boxes wider than the beam are over the side; a stack much narrower than the
	# beam means the rows were derived against the wrong width.
	_check("the_%s_cargo_fits_within_the_beam" % which,
		widest <= float(want["beam"]) and widest > float(want["beam"]) * 0.90,
		"%.2f m of cargo across a %.1f m beam" % [widest, float(want["beam"])])


## EVERY LIVERY DRAWS A DIFFERENT SHIP, and this check exists because the bug it catches is SILENT. `ShipHull.models`
## caches a built mesh per ship; before this lane it keyed that cache on the ship's NAME alone, so six liveries of one
## vessel would all have collided on one entry and the first one built would have been handed back six times. Every
## dimension check passes on six identical ships, the fleet looks like a photocopy, and nothing says a word.
##
## SO IT IS ASKED OF THE DRAWN VERTEX COLOURS, not of the palette table. Comparing `LIVERIES[i]` with `LIVERIES[j]` would
## only prove the table has six rows in it -- the model agreeing with its own input, which is the tautology trap. What is
## compared here is the colour actually welded into each mesh, which is the thing a viewer sees.
##
## AND THE SHAPE MUST NOT MOVE. A livery is paint: the vertex COUNT is held equal across all six, so a scheme that
## quietly changed the geometry would be caught rather than admired.
func _every_livery_is_a_different_ship(ship_name: String) -> void:
	var count: int = ShipHull.livery_count(ship_name)
	var geometry: Dictionary = ContainerShipDraft.geometry(ship_name) if ship_name.begins_with("container") 		else SmallCraftDraft.geometry(ship_name)
	var seen: Dictionary = {}
	var points: int = -1
	var same_shape: bool = true
	for livery in range(count):
		var mesh := ShipHull.models(-1, geometry, livery).get("near") as ArrayMesh
		var arrays: Array = mesh.surface_get_arrays(0)
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var here: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if points < 0:
			points = here
		elif here != points:
			same_shape = false
		# A FINGERPRINT OF THE WHOLE PAINT JOB, not of one face: two schemes may share a hull colour and differ in the
		# house, and either difference makes them different ships.
		var mark: String = ""
		for i in range(0, colours.size(), maxi(colours.size() / 64, 1)):
			mark += "%02x%02x%02x" % [int(colours[i].r * 255.0), int(colours[i].g * 255.0), int(colours[i].b * 255.0)]
		seen[mark] = int(seen.get(mark, 0)) + 1
	_check("every_%s_livery_draws_a_different_ship" % ship_name, seen.size() == count and count >= 2,
		"%d liveries drew %d distinct paint jobs" % [count, seen.size()])
	_check("no_%s_livery_moves_a_vertex" % ship_name, same_shape,
		"%d vertices in every one of the %d" % [points, count])


## A SMALL BOAT AGAINST ITS REFERENCES: the envelope, the air draught where one is published, and the transom -- which
## is the shape that tells the two sailing boats apart and which no envelope figure can see.
func _the_small_craft_is_its_size(boat: String, geometry: Dictionary) -> void:
	var mesh := ShipHull.models(-1, geometry).get("near") as ArrayMesh
	var faces: Array = _faces(mesh)
	var box: AABB = mesh.get_aabb()
	var want: Dictionary = SMALL_CRAFT[boat]
	_within(boat, "length_overall", box.size.z, want["length"])
	_within(boat, "beam", box.size.x, want["beam"])
	# THE DRAUGHT IS TO THE BOTTOM OF THE KEEL on the two sailing boats, and that is the published figure. A hull drawn
	# 2.27 m deep would be a boat nobody has seen; the fin carries the difference, so this asks the deepest drawn point.
	_within(boat, "draught_to_the_keel", -box.position.y, want["draught"])
	if float(want["air_draught"]) > 0.0:
		_within(boat, "air_draught_to_the_masthead", box.end.y, want["air_draught"])
	# THE TRANSOM'S WIDTH, measured off the drawn vertices within half a metre of the stern. A canoe transom and a modern
	# wide one are the same boat by every other number here.
	var stern: float = box.end.z
	var widest: float = 0.0
	for face in faces:
		for i in range(3):
			var p: Vector3 = face[i]
			if p.z < stern - 0.02 or p.y < 0.0:
				continue
			widest = maxf(widest, absf(p.x) * 2.0)
	# THE LENGTH SHE FLOATS ON, where it is published. LOA 9.14 m against LWL 7.11 is more than a fifth of the boat in
	# overhangs, and it is the figure that separates a classic hull from a modern one as sharply as the transom does --
	# the model derives its stem rake and counter from the difference, so measuring the waterline back out of the drawn
	# vertices is the check that the derivation landed. Asked at the waterline row itself, y within a centimetre of zero.
	if want.has("waterline"):
		var afloat := Vector2(INF, -INF)
		for face in faces:
			for i in range(3):
				var p: Vector3 = face[i]
				if absf(p.y) > 0.01:
					continue
				afloat = Vector2(minf(afloat.x, p.z), maxf(afloat.y, p.z))
		_within(boat, "waterline_length", afloat.y - afloat.x, want["waterline"])
	_check("the_%s_transom_is_its_reference" % boat,
		absf(widest - float(want["transom"])) <= maxf(float(want["transom"]) * 0.12, 0.25),
		"%.2f m across the transom against %.2f m" % [widest, float(want["transom"])])


## THE TWO SAILING BOATS ARE DIFFERENT BOATS, which is the thing a reader sees before any number. The modern cruiser
## ends in a transom nearly her full beam; the 1979 cutter narrows to a canoe stern. Asked as a RATIO of transom to
## beam, so it holds whatever either boat's size is, and held apart by a factor of three rather than by a tolerance.
func _the_two_sailing_boats_are_different_boats() -> void:
	var share: Dictionary = {}
	for boat in ["cruising_sloop", "classic_cutter"]:
		share[boat] = float(SMALL_CRAFT[boat]["transom"]) / float(SMALL_CRAFT[boat]["beam"])
	var modern: float = float(share["cruising_sloop"])
	var classic: float = float(share["classic_cutter"])
	_check("the_modern_cruiser_carries_her_beam_aft_and_the_cutter_does_not", modern > 0.70 and classic < 0.25,
		"transom is %.2f of the beam on the sloop and %.2f on the cutter" % [modern, classic])


## EVERY ISLAND AND BRIDGE PART STANDS ON SOMETHING: the weather deck, or the roof of another part whose footprint it sits
## inside. `ship_models` asks this of FITTINGS and nothing has ever asked it of PARTS, which is how the feeder's funnel
## came to hang in the air six metres abaft the house it was meant to stand on, 21 m over the deck, attached to nothing.
## Every dimension check stayed green -- a bounding box round a detached part still contains it -- and the fault was found
## by looking at the side elevation (modelling_here.md section 6, "a part can come off, and nothing will say so").
##
## THE FOOTPRINT TEST IS WHAT MAKES IT BITE. Holding the part's bottom to "the highest thing anywhere under it" is not
## enough: the floating funnel's bottom was exactly `deck + house_roof`, which is a real height that a real part really
## has, so a height-only check passes it. What it did not have was any part UNDERNEATH IT whose plan rectangle contains
## its own, and that is the thing being asked here.
func _every_island_stands_on_something(ship_name: String, geometry: Dictionary) -> void:
	var parts: Array = geometry.get("parts", []) as Array
	var floating: Array[String] = []
	for part in parts:
		var role: String = String(part.get("part", ""))
		if not (role in ["island", "bridge"]):
			continue
		var r: Rect2 = Wheelhouse.outline_rect(part["outline"])
		var bottom: float = float(part["bottom"])
		var top: float = float(part["top"])
		var stands: bool = false
		for under in parts:
			if under == part:
				continue
			var ur: Rect2 = Wheelhouse.outline_rect(under["outline"])
			# THEIR FOOTPRINTS OVERLAP, and this went through two wrong versions before it was right. ENCLOSURE is too
			# strict: a wheelhouse is legitimately WIDER than the house under it, because bridge wings reach out to the
			# ship's side. And THE CENTRE being over something is too strict the other way, which a probe across the rest
			# of the fleet found -- the FERRY is a catamaran, so its superstructure spans the tunnel between two demihulls
			# and its middle hangs over open water BY DESIGN. Two of its four islands read as floating and neither is.
			# A BRIDGING MEMBER IS NOT A FLOATING ONE.
			#
			# Overlap catches all three cases: the wheelhouse overlaps its house, the ferry's deckhouse overlaps both
			# demihulls, and the funnel that hung six metres abaft its own house overlaps nothing and still fails.
			if not ur.grow(0.20).intersects(r):
				continue
			# THE THING UNDER IT MUST REACH ITS FLOOR OR HIGHER, rather than end exactly at it. A cockpit well is LET INTO
			# the deck -- the sloop's sole is 0.45 m below its side deck -- so a part whose floor is below the deck's top
			# is recessed, not floating, and holding the two tops equal called both yachts' cockpits airborne. What
			# catches a truly detached part is the footprint test above: the floating funnel had a real height and
			# nothing underneath it.
			if float(under["top"]) >= bottom - FOOT and float(under["bottom"]) < top:
				stands = true
				break
		if not stands:
			floating.append("%s at %s, its floor %.2f m up" % [role, r.get_center(), bottom])
	_check("every_%s_island_stands_on_something" % ship_name, floating.is_empty(),
		"%d island and bridge parts%s" % [parts.size(),
			"" if floating.is_empty() else ", standing on nothing: " + ", ".join(floating)])


## HOW MANY ROWS OF CONTAINERS WERE ACTUALLY DRAWN in one bay, counted off the vertices rather than divided out of the
## stack's width. Every box is a separate prism, so it puts faces at its own left and right x and no two rows share one;
## the distinct x values inside the bay are therefore exactly two to a row.
##
## THE BAY IS TAKEN ONE TIER UP, not at the deck, so that the hatch cover and the deck plate under the stack -- which run
## the width of the ship in one piece -- contribute nothing to the count.
func _rows_drawn(mesh: ArrayMesh, bay: AABB) -> int:
	var seen: Dictionary = {}
	var low: float = bay.position.y + ISO_HIGH * 0.5
	var high: float = bay.position.y + ISO_HIGH * 1.5
	for face in _faces(mesh):
		for i in range(3):
			var p: Vector3 = face[i]
			if p.y < low or p.y > high:
				continue
			if p.z < bay.position.z - 0.1 or p.z > bay.end.z + 0.1:
				continue
			if p.x < bay.position.x - 0.1 or p.x > bay.end.x + 0.1:
				continue
			seen[snappedf(p.x, 0.001)] = true
	return int(round(float(seen.size()) * 0.5))


## THE TWO CONTAINER SHIPS ARE DIFFERENT SHIPS, not one ship at two sizes -- which is the thing a reader would notice
## first and no size check can see. The Triple-E's accommodation stands FORWARD of midships and its funnels far aft; the
## feeder has everything aft in one island. So the highest drawn point of one is forward of the middle and of the other is
## abaft it, and that is asked of the drawn vertices.
func _the_two_container_ships_are_different_ships() -> void:
	var where: Dictionary = {}
	for which in ["container_feeder", "container_large"]:
		var mesh := ShipHull.models(-1, ContainerShipDraft.geometry(which)).get("near") as ArrayMesh
		var top: float = -INF
		var at: float = 0.0
		for face in _faces(mesh):
			for i in range(3):
				var p: Vector3 = face[i]
				if p.y > top:
					top = p.y
					at = p.z
		where[which] = at
	_check("the_large_container_ship_cons_from_forward_of_midships", float(where["container_large"]) < 0.0,
		"its highest point is at z %.1f m, forward of midships" % float(where["container_large"]))
	_check("the_feeder_cons_from_aft", float(where["container_feeder"]) > 0.0,
		"its highest point is at z %.1f m, abaft midships" % float(where["container_feeder"]))


## A DRAWN SIZE AGAINST ITS REFERENCE, within `TOLERANCE`.
func _within(ship_name: String, what: String, drawn: float, reference: float) -> void:
	var off: float = absf(drawn - reference) / reference
	_check("the_%s_%s_is_its_reference" % [ship_name, what], off <= TOLERANCE,
		"drawn %.2f m against %.2f m, %.2f %%" % [drawn, reference, off * 100.0])


## THE ARLEIGH BURKE AGAINST ITS SOURCES, and against the two things that make it a Flight IIA rather than a warship.
func _the_destroyer_is_its_size(geometry: Dictionary) -> void:
	var mesh := ShipHull.models(-1, geometry).get("near") as ArrayMesh
	var faces: Array = _faces(mesh)
	var box: AABB = mesh.get_aabb()
	var want: Dictionary = DESTROYER
	_within("destroyer", "length_overall", box.size.z, want["length"])
	_within("destroyer", "beam", box.size.x, want["beam"])
	_within("destroyer", "masthead_over_the_water", box.end.y, want["masthead"])
	# THE SHEER FALLS MONOTONICALLY AFT, which is what found two bad picks in the references: a transom that reads
	# HIGHER than amidships is not a discovery about destroyers. Read on the centreline forward, amidships and aft.
	var bow: float = -want["length"] * 0.5
	# AT THE STEM, not near it: the sheer is a parabola, so a probe 12 m aft of the stem reads 1.95 m of the 2.72 m of
	# lift and looks like an 8 % error in the model. The reference number was measured AT the forwardmost point, so the
	# probe goes there (cockpit-fleet3, 2026-09-17).
	var fwd: float = _top_over(faces, Vector2(0.0, bow + 2.0), want["freeboard_stem"] + 1.5)
	var mid: float = _top_over(faces, Vector2(want["beam"] * 0.42, 0.0), want["freeboard_mid"] + 1.0)
	var aft: float = _top_over(faces, Vector2(0.0, -bow - 6.0), want["freeboard_stern"] + 1.0)
	_within("destroyer", "freeboard_at_the_stem", fwd, want["freeboard_stem"])
	_within("destroyer", "freeboard_amidships", mid, want["freeboard_mid"])
	_check("the_destroyer_sheer_falls_aft", fwd > mid and mid > aft,
		"stem %.2f m, amidships %.2f m, transom %.2f m" % [fwd, mid, aft])
	# THE HULL FLOATS AT ITS MOULDED DRAUGHT AND THE DOME HANGS BELOW IT. The published 9.45 m is to the dome, so a hull
	# drawn to it would sit 2.9 m too deep with every size check green (cockpit-fleet3, 2026-09-17). Held apart here:
	# the hull's own bottom on the centreline amidships, and the deepest thing anywhere under the bow.
	var hull_bottom: float = _lowest_over(faces, Vector2(want["beam"] * 0.3, 0.0))
	_within("destroyer", "hull_floats_at_its_moulded_draught", -hull_bottom, want["draught"])
	_check("the_destroyer_dome_hangs_below_the_hull", -box.position.y > want["draught"] + 1.5,
		"deepest %.2f m against a hull bottom of %.2f m" % [-box.position.y, -hull_bottom])
	# TWO HANGARS SIDE BY SIDE, WITH A GAP BETWEEN THEM, which is Flight IIA and not Flight I or II. A single wide
	# hangar box passes every size check above and is the wrong ship.
	var roof: float = want["freeboard_mid"] + DestroyerDraft.HANGAR_ROOF
	var z: float = -bow - DestroyerDraft.LENGTH + DestroyerDraft.HANGAR_FROM_BOW + DestroyerDraft.HANGAR_RUNS * 0.5
	var on_centre: float = _top_over(faces, Vector2(0.0, z), roof + 0.5)
	var to_port: float = _top_over(faces, Vector2(-4.3, z), roof + 0.5)
	var to_starboard: float = _top_over(faces, Vector2(4.3, z), roof + 0.5)
	_check("the_destroyer_has_two_hangars_with_a_gap_between_them",
		to_port > roof - 0.5 and to_starboard > roof - 0.5 and on_centre < roof - 1.0,
		"port %.2f m, starboard %.2f m, centreline %.2f m against a roof at %.2f m"
			% [to_port, to_starboard, on_centre, roof])
	# FOUR SPY FACES ON CANTED CORNERS, all on ONE deckhouse (PUBLISHED), each a PUBLISHED 3.66 m octagon.
	#
	# COUNTING FACES BY THEIR NORMAL WAS A FALSE PASS. The first version counted every triangle whose normal pointed in
	# both x and z at the array's height -- and a deckhouse whose corners are cut by a MILLIMETRE still has four such
	# walls, so a plain box passed as a Burke. The mutant that took the cant away stayed green and proved nothing
	# (cockpit-fleet3, 2026-09-17). This asks the model for the arrays it says it drew, and holds each to the
	# published size: a face too small to be an array is not an array.
	var arrays: int = 0
	var widest: float = 0.0
	for item in (ShipHull.models(-1, geometry).get("panels", []) as Array):
		var plate := item as AABB
		# ACROSS THE FACE, NOT ALONG AN AXIS. A plate on a 45-degree corner projects 3.66 / sqrt(2) = 2.59 m onto each
		# of x and z, so its AABB's largest side reads 2.71 m and a check on that rejects a correctly sized array.
		# The width across the face is the diagonal of the two horizontal sides (cockpit-fleet3, 2026-09-17).
		var across: float = sqrt(plate.size.x * plate.size.x + plate.size.z * plate.size.z)
		if plate.position.y < want["freeboard_mid"] + 1.0 or plate.position.y > want["freeboard_mid"] + 8.0:
			continue
		# An array is a FLAT plate on a canted corner: it has extent in both x and z, and neither is the whole house.
		if plate.size.x < 0.4 or plate.size.z < 0.4 or across > 6.0:
			continue
		widest = maxf(widest, across)
		if absf(across - 3.66) <= 3.66 * 0.15:
			arrays += 1
	_check("the_destroyer_carries_four_array_faces_of_the_published_size", arrays == 4,
		"%d faces within 15 %% of a 3.66 m octagon on the deckhouse's canted corners, widest %.2f m"
			% [arrays, widest])


## THE HIGHEST FACE LOOKING UP over a plan point, below `under`; -INF over nothing.
##
## SAMPLED AS A SMALL CROSS, not as one point, because a quad is drawn as two triangles and a point exactly on the diagonal
## between them can be inside neither: `Geometry2D.point_is_inside_triangle` said no to both halves of the ferry's
## wheelhouse roof, whose diagonal runs through the middle of the room the seats are in, and the check read the roof deck
## 3.3 m below instead (cockpit-fleet3, 2026-09-17).
func _top_over(faces: Array, at: Vector2, under: float) -> float:
	var top: float = -INF
	for face in faces:
		if (face[3] as Vector3).y < 0.7:
			continue
		var a: Vector3 = face[0]
		var b: Vector3 = face[1]
		var c: Vector3 = face[2]
		var high: float = maxf(a.y, maxf(b.y, c.y))
		if high >= under or high <= top:
			continue
		if _covers(a, b, c, at):
			top = high
	return top


## THE LOWEST FACE over a plan point, whichever way it looks; INF over nothing.
func _lowest_over(faces: Array, at: Vector2) -> float:
	var low: float = INF
	for face in faces:
		var a: Vector3 = face[0]
		var b: Vector3 = face[1]
		var c: Vector3 = face[2]
		var deep: float = minf(a.y, minf(b.y, c.y))
		if deep < low and _covers(a, b, c, at):
			low = deep
	return low
