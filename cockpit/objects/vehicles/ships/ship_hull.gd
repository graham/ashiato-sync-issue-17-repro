@tool
extends RefCounted
class_name ShipHull
## A SHIP, DRAWN FROM THE PARTS THE SIMULATION BUILDS IT FROM -- a silhouette for far away and a model for near.
##
## Every ship used to be a box -- one `BoxMesh` the size of the hull -- sized from `extents` and nothing else. A carrier is
## not a box: its deck is nearly twice as wide as its hull at the waterline, it is angled off to port, and its island is on
## the starboard edge far aft. So the simulation's shape table lists a ship as PARTS (`kind_geometry`'s "parts": an outline
## in plan stood between two heights, and what the part is for), and this draws exactly those. What you see is what an
## aeroplane lands on and what a helm is placed in, because it is the same list.
##
## TWO PICTURES, ONE SHIP. The FAR one is the parts as prisms, one mesh and one draw call, and it is all a ship is past
## `NEAR_TO`. The NEAR one is the ship's own model (`Carrier`, and a builder per ship) with its paint, its fittings and its
## bridge. Godot's visibility ranges swap them, with `MARGIN` of overlap so the swap does not flicker at the boundary.
##
## BUILT ONCE PER KIND, NOT PER SHIP. Forty-four launches share one mesh, and nothing here runs per frame: the meshes are
## static and the nodes carry no script.

## Where the near model gives way to the silhouette, metres from the eye, and how much the two overlap. At 1.8 km a carrier
## is about 190 pixels long on a 1600-pixel, 70-degree view: its paint is a few pixels and its prisms are the ship.
const NEAR_TO: float = 1800.0
const MARGIN: float = 100.0

## What each part is painted in the silhouette. Haze grey for the hull and superstructure, the dark non-skid of a flight
## deck, and a bridge a shade darker so its band reads as windows from a distance.
const PAINT: Dictionary = {
	"hull": Color(0.45, 0.48, 0.51),
	"deck": Color(0.21, 0.22, 0.23),
	"island": Color(0.47, 0.50, 0.53),
	"bridge": Color(0.16, 0.19, 0.22),
}

static var _made: Dictionary = {}


## THE SHIP AS A NODE: a `Far` silhouette and, for a ship that has one, a `Near` model. Null for a kind with no parts.
## VehicleView calls this in place of step 1's `silhouette(geometry)`, which it replaces; the far mesh is `far_mesh`, a
## different name on purpose, so an old call cannot land on a function of the same name that takes parts.
static func dress(kind: int, geometry: Dictionary, livery: int = 0) -> Node3D:
	var made: Dictionary = models(kind, geometry, livery)
	if made.is_empty():
		return null
	var ship := Node3D.new()
	ship.name = "Ship"
	var far := MeshInstance3D.new()
	far.name = "Far"
	far.mesh = made["far"]
	far.material_override = painted()
	ship.add_child(far)
	if made.get("near") != null:
		far.visibility_range_begin = NEAR_TO
		far.visibility_range_begin_margin = MARGIN
		var near := MeshInstance3D.new()
		near.name = "Near"
		near.mesh = made["near"]
		near.material_override = painted()
		near.visibility_range_end = NEAR_TO
		near.visibility_range_end_margin = MARGIN
		ship.add_child(near)
	return ship


## THE MESHES FOR A KIND, built the first time they are asked for: `{"far", "near", "panels", "fittings"}`, or {} with no
## parts.
## `livery` PICKS A COLOUR SCHEME and IS PART OF THE CACHE KEY, which is the whole reason this signature changed. The
## cache holds one built mesh per ship NAME; six liveries of one vessel would all have collided on that one entry and the
## first one built would have been handed out six times, silently. A livery is data the caller chooses, so the caller's
## choice has to reach the key. Default 0, so every existing call gets exactly the ship it got before.
static func models(kind: int, geometry: Dictionary, livery: int = 0) -> Dictionary:
	# THE CACHE IS KEYED BY NAME AND LIVERY; THE DISPATCH IS ON THE NAME ALONE. They must not be the same string, and
	# making them one was a bug that lived for about a minute: `match key` against "container_feeder#3" matches no arm
	# and falls quietly through to the generic `Superstructure.build`, so every liveried ship would have come back as a
	# plain grey box with no complaint from anything.
	var ship_name: String = String(geometry.get("name", ""))
	var key: String = ship_name if livery == 0 else "%s#%d" % [ship_name, livery]
	if _made.has(key):
		return _made[key]
	var parts: Array = geometry.get("parts", []) as Array
	if parts.is_empty():
		return {}
	var detail: Dictionary = {}
	# A SHIP WITH A MODEL OF ITS OWN is built by it; any other ship with parts is drawn from them. Every one but the
	# carrier's is handed the helm the catalogue says the kind has -- behind glass, or at an open console -- rather than
	# typing it: the step 4 drafts each typed theirs. The arm is the shape table's `name`; the cache key adds the livery.
	var helm: String = VehicleCatalogue.helm(kind)
	# A MERCHANT SHIP IS NOT HAZE GREY at any distance: its silhouette takes its own builder's paint (`FAR`).
	var far_paint: Dictionary = PAINT
	match ship_name:
		"carrier":
			detail = Carrier.build(geometry)
		"battleship":
			detail = Battleship.build(geometry, helm)
		"gunboat":
			detail = PatrolBoat.build(geometry, helm)
		"boat":
			detail = Launch.build(geometry, helm)
		# A CB90 FAST ASSAULT CRAFT: hard chines, the bow ramp, the waterjets and the missile box (lane/boats).
		"cb90":
			detail = CombatBoat.build(geometry, helm)
		# A FIREBOAT on the FDNY Three Forty Three: red over white, a rub strake round a bluff bow, four raked stacks
		# and the monitors she fights with (lane/fireboat, 2026-09-19).
		"fireboat":
			detail = Fireboat.build(geometry, helm)
			far_paint = Fireboat.FAR
		# A SUBMARINE IS ROUND, which Superstructure's ship lines are not: see Submarine.
		"submarine":
			detail = Submarine.build(geometry, helm)
		# A VLCC, drawn from `CrudeCarrierDraft` until the kind is C++ (cockpit-fleet3).
		"crude_carrier":
			detail = CrudeCarrier.build(geometry, helm)
			far_paint = CrudeCarrier.FAR
		# A WAVE-PIERCING CATAMARAN, drawn from `FerryDraft` until the kind is C++ (cockpit-fleet3).
		"ferry":
			detail = Ferry.build(geometry, helm)
			far_paint = Ferry.FAR
		# AN ARLEIGH BURKE FLIGHT IIA, drawn from `DestroyerDraft` until the kind is C++ (cockpit-fleet3).
		"destroyer":
			detail = Destroyer.build(geometry, helm)
			far_paint = Destroyer.FAR
		# TWO CONTAINER SHIPS, drawn from `ContainerShipDraft` until the kinds are C++ (lane/seaport). One builder for both:
		# a 235 m feeder with everything aft, and a 399 m Triple-E with its accommodation forward and its funnels far aft.
		"container_feeder", "container_large":
			detail = ContainerShip.build(geometry, helm, livery)
			far_paint = ContainerShip.FAR
		# A TRIPLE-COCKPIT MAHOGANY RUNABOUT, drawn from `RunaboutDraft` until the kind is C++ (lane/chriscraft,
		# 2026-09-20). A Chris-Craft 27 ft Custom Runabout: varnished mahogany, a planked deck with walnut king plank
		# and white caulked seams, and chrome everywhere. `craft/runabout/sources.md`.
		"runabout":
			detail = Runabout.build(geometry, helm)
			far_paint = Runabout.FAR
		# FOUR SMALL BOATS, drawn from `SmallCraftDraft` until the kinds are C++ (lane/seaport): a modern cruising sloop,
		# a classic long-keel cutter, a stern trawler and a flybridge motor yacht -- the boats a marina is made of.
		"cruising_sloop", "classic_cutter", "stern_trawler", "motor_yacht":
			detail = SmallCraft.build(geometry, helm, livery)
			far_paint = SmallCraft.FAR
		_:
			detail = Superstructure.build(geometry, helm)
	# `fittings`: the box each of a ship's own fittings stands on the ship by, which tests/ship_models.gd holds to a part.
	# `ports`: where a ship's exhaust leaves her, for `VehicleView.exhaust_ports`. Empty for a ship whose builder does
	# not say, which is every one of them but the fireboat today.
	var made: Dictionary = {"far": far_mesh(parts, far_paint), "near": detail.get("mesh"),
		"panels": detail.get("panels", [] as Array[AABB]), "fittings": detail.get("fittings", [] as Array[AABB]),
		"ports": detail.get("ports", [])}
	_made[key] = made
	return made


## THE PARTS AS PRISMS, one mesh. `stations` are left out: an open gun position is not something a silhouette has.
## `paint` is a colour per role, `PAINT` for a warship.
static func far_mesh(parts: Array, paint: Dictionary = PAINT) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var role: String = String(part.get("part", "hull"))
		if paint.has(role):
			Plating.prism(tool, part.get("outline", PackedVector2Array()) as PackedVector2Array,
				float(part.get("bottom", 0.0)), float(part.get("top", 0.0)), paint[role])
	return Plating.weld(tool)


## The one material every ship mesh is drawn with: its colour is in its vertices, AS sRGB, which is how every colour in
## these files was chosen. Without the flag Godot takes vertex colour as linear and a haze grey comes out near white.
static func painted() -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = true
	paint.roughness = 0.85
	return paint


## HOW MANY LIVERIES A SHIP HAS, asked of whichever builder owns it. One for a ship with no palette of its own, which is
## every warship and the three older merchantmen: they wear what they wear.
static func livery_count(ship_name: String) -> int:
	if ship_name == "container_feeder" or ship_name == "container_large":
		return ContainerShip.LIVERIES.size()
	if SmallCraft.LIVERIES.has(ship_name):
		return (SmallCraft.LIVERIES[ship_name] as Array).size()
	return 1


## A LIVERY FROM A SEED, so that whatever places a fleet hands over any integer it likes -- a spawn index, a position
## hash, a world seed -- and gets a valid scheme for that ship without knowing how many it has. A fleet of six drawn from
## six consecutive seeds is six different boats; a fleet drawn from one seed is six of the same, which is also sometimes
## what is wanted.
static func livery_for(ship_name: String, seed: int) -> int:
	var count: int = livery_count(ship_name)
	return 0 if count <= 1 else absi(seed) % count
