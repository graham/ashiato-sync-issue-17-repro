extends Node3D
class_name OilField
## WHERE THE OIL PLATFORMS STAND, AND THE PICTURE OF THEM: a fixed steel-jacket production platform out at sea on every
## world, standing on the sea floor, flaring, and lit at night. The platform itself is `OilPlatform`; this is where it
## goes and what the world gives it.
##
## THE DECISION: ONE LIST OF PLACES FEEDS BOTH HALVES, as `PowerStation`'s does. `boxes()` hands `Terrain.boxes()` the
## platform's solid and `draw_platforms` draws it, and both read `sites()`, so the picture and the physics cannot disagree
## about where a platform is -- `sky.gd` says why that matters: scenery drawn where the simulation has none "looks
## exactly like a networking fault".
##
## THE DEPTH IS ASKED, NEVER TYPED. A jacket runs from the sea floor to its top frame, so the one number that decides how
## tall it is belongs to the world: on the island the open sea's floor is `Seabed.depth()`, a static box at -150 m laid
## under the whole wire; on the generated ground it is the ground's own function under the site. A typed depth would stand
## the island's platform on nothing, or bury the alpine one's feet, and every dimension check would still pass.
##
## WHERE, AND WHY THERE. The island's platform stands 3.3 km off its NORTH coast, while everything that sails on the
## island is laid out to the south: the carrier at z +9,200, the submarine +12,200, the battleship +9,600, the two boats
## +7,600 (`Terrain.spawns`). Inside the boats' spread (1.7 island half-widths), so the placed reach and the level's soft
## boundary do not move. On the generated ground the site is the nearest open sea as deep as its row asks to an anchor
## away from the carrier's coast, and a site that comes back deeper than a fixed jacket is built for is refused in words. A world
## with no sea at all (the test field, the gliders' level) builds none and says nothing.
## `tests/oil_platform.gd` holds every site clear of every ship's spawn by SHIPPING_CLEAR.
##
## AND SHIPS ARE KEPT OFF IT, AS FAR AS GDSCRIPT CAN: no ship's waypoint is kept within KEEP_CLEAR of a platform
## (`Terrain.waypoints`), and every spawn is far off. What it cannot do is stop a LEG between two kept points passing
## the jacket: the AI's legs sound the sea's depth, and on the generated ground that is the ground's function, which
## never sees a static box. Sounding a leg against the platforms is a C++ change, filed in the lane's learnings.

## THE PLATFORMS. `island` is where it stands on the island, metres east and SOUTH of the middle (the world's x and z);
## `anchor` is where the generated ground's search for open sea starts and `water` how deep that sea must be.
##
## THE GENERATED GROUND'S SITE WAS CHOSEN BY PROBING IT (2026-09-18), and RE-PROBED AT 10 M ON 2026-09-19 (the user: "let's
## make it so that the restriction is 10 meters, we can fake it ... so that oil rigs can be more easily placed"). Asked for
## 60 m from (9000, -9000) the search stopped at the shelf's very edge, 11 km off, 23 km out and on a floor that fell 1.9 m
## across the base. Asked for 120 m from (8000, -8000) it gave (17307, -19115), 19.1 km out. Asked for 10 m from the same
## anchor it now gives (15168, -15908): 15.9 km out on the larger axis, inside the level's placed reach of 22.3 km, so
## inside the soft boundary, 38.7 km from the alpine fleet (laid out round (-5000, 17000)), on a floor 10.0 m down under the
## middle and 12.5 m under the deepest foot -- a gentle bed, not a shelf lip -- so the anchor did not need to move.
const PLATFORMS: Array[Dictionary] = [
	{"name": &"north_alpha", "island": Vector2(6000.0, -10500.0), "anchor": Vector2(8000.0, -8000.0), "water": MIN_DEPTH},
]
## HOW FAR OUT FROM ITS MIDDLE THE JACKET'S FEET STAND, metres along and across, for sounding the floor under them: the
## base at the deepest water this model is built for, rounded out.
const FEET := Vector2(46.0, 44.0)
## THE WATER A JACKET IS DRAWN FOR, metres. The floor is 10 m, and it is FAKED: the user's word, 2026-09-19, so that a
## platform can be placed on more worlds. A real fixed jacket does not stand in so little water ([W] Ula and Valhall stand in
## 70, Thistle in 162), but `OilPlatform.frame_levels` gives a shallow one a single bay and the deck stays 22 m over the sea,
## so it draws sensibly. Deeper than MAX_DEPTH this model's bays have not been looked at.
const MIN_DEPTH: float = 10.0
const MAX_DEPTH: float = 250.0
## How far every platform stands from every ship's spawn, metres, held by the suite.
const SHIPPING_CLEAR: float = 2500.0
## THE SAFETY ZONE, metres: no ship's waypoint is kept closer than this to a platform (`Terrain.waypoints`). A real
## installation's is 500 m; this is twice that, because a waypoint is where a ship aims, not where it stops.
const KEEP_CLEAR: float = 1000.0
## The layer the platforms are drawn on.
const LAYER: String = "oil_platforms"
## THE FLARE'S FLAME: four overlapping tongues, each a quad `flare.gdshader` tears, sways and pulses on its own clock --
## the fire yard's flame, blended rather than added, so it is orange against a daylit sky. Each row is width, height,
## seed and how far across the stack it stands, metres. The first pictures drew three narrow tongues that read as "a
## static crystal shard" (team-lead, 2026-09-18); four rounded ones swaying out of step read as a flame.
const FLAME: Array[Vector4] = [Vector4(10.0, 19.0, 0.0, 0.0), Vector4(8.0, 15.0, 0.37, 1.2),
	Vector4(7.0, 12.0, 0.71, -1.0), Vector4(9.0, 10.0, 0.19, 0.4)]
const FLAME_SHADER: Shader = preload("res://world/shaders/flare.gdshader")
## THE SMOKE off the flame's top: a thin dark trail, width and height in metres. [M] Montrose flares black smoke that
## trails further than the flame is long.
const SMOKE := Vector2(7.0, 60.0)
const SMOKE_SHADER: Shader = preload("res://world/shaders/flare_smoke.gdshader")
## THE FLARE'S REFLECTION ON THE SEA, by time of day (DAY, EVENING, NIGHT): the strength handed to the ocean shaders'
## glint (`sea_glint.gdshaderinc`), its colour, and the flame's radius in metres, which widens the reflection as a 10 m
## flame's would be. Until 2026-09-18 this was a 120 m additive disc of noise laid on the water, which the user saw as a
## blotchy orange floor under the flame rather than a reflection.
const FLARE_GLINT: Array[float] = [0.0, 1500.0, 4000.0]
const FLARE_GLINT_COLOUR := Color(1.0, 0.62, 0.30)
const FLARE_GLINT_RADIUS: float = 6.0
## AND FOUR DECK LAMPS', each a small streak of its own: strength by time of day and radius, at `glint_lamps()`.
const LAMP_GLINT: Array[float] = [0.0, 80.0, 220.0]
const LAMP_GLINT_COLOUR := Color(1.0, 0.86, 0.62)
const LAMP_GLINT_RADIUS: float = 0.8
## THE FLAME AT NIGHT. The user, 2026-09-18: "can you add a flame burning, might be really cool at night". So by time of
## day (DAY, EVENING, NIGHT) the flame burns hotter than white (`heat`, into the HDR range), a halo this many metres
## across glows round it in the air, and the underside of its smoke takes its colour. These, its reflection on the sea
## (FLARE_GLINT) and the flare lamp in `OilPlatform.floods()` are what make it the landmark it is from kilometres off.
const FLAME_HEAT: Array[float] = [1.0, 1.7, 2.8]
const HALO_ACROSS: float = 70.0
const HALO_SHADER: Shader = preload("res://world/shaders/flare_halo.gdshader")
const HALO_STRENGTH: Array[float] = [0.0, 0.55, 1.0]
const SMOKE_UNDERLIT: Array[float] = [0.0, 0.5, 0.85]
## THE SMOKE'S OWN COLOUR by time of day (DAY, EVENING, NIGHT): soot-dark by day, a dull red-brown after dark.
const SMOKE_COLOUR: Array[Color] = [Color(0.16, 0.15, 0.14), Color(0.22, 0.13, 0.08), Color(0.26, 0.11, 0.05)]
## HOW MUCH THE FLAME AND ITS SMOKE LEAN in a metre-a-second of wind, and how much they lean with none: a flare's gas
## leaves the tip fast and a little outboard. The game's wind is `Terrain.WIND`, zero by the user's choice.
const LEAN_PER_WIND: float = 0.08
const LEAN_STILL := Vector3(-0.12, 0.0, -0.05)
## THE FLARE'S LIGHT and the deck's floodlight by time of day (DAY, EVENING, NIGHT), and how far each reaches.
const FLARE_ENERGY: Array[float] = [0.0, 3.0, 8.0]
const FLARE_RANGE: float = 190.0
const DECK_ENERGY: Array[float] = [0.0, 1.2, 2.6]
const DECK_RANGE: float = 75.0
## How brightly the quarters' windows glow, as a share of the towns' `window_glow`.
const WINDOW_SHARE: float = 1.0

var _laid: Array[Dictionary] = []
var _drawn: Array[Node3D] = []
## The look the platforms were last lit by (`DaylightTuning.look_at`), or {} before the level has said.
var _look: Dictionary = {}
## The platform and the look whose glints the ocean shaders were last handed, so they are handed again only on a change.
var _glint_from: Node3D = null
var _glint_when: int = -2


## EVERY REFUSAL `sites()` has warned of, so a suite can ask whether a world was warned about without reading the log.
static var refusals: PackedStringArray = []


## A SITE NOT BUILT, WARNED OF and kept in `refusals`.
static func refuse(message: String) -> void:
	refusals.append(message)
	push_warning(message)


## EVERY PLATFORM ON THIS WORLD, as `{"name", "position", "depth"}`: the position on the sea's surface over the jacket's
## middle, the depth positive metres of water. Static and pure apart from the authorities it asks, so a suite can check it
## without building anything. A site that is not open sea, or is too shallow or deep, is warned about and dropped.
static func sites() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for platform in PLATFORMS:
		var at: Vector3
		var depth: float
		if Terrain.standing_on() == null:
			var p: Vector2 = platform["island"]
			at = Vector3(p.x, Terrain.SEA_LEVEL, p.y)
			# THE ISLAND'S SEA FLOOR IS THE SEABED BOX, not the ground: past the slab `ground_height` is -INF.
			depth = Terrain.SEA_LEVEL - Seabed.depth() if Terrain.water_height(at) != -INF else 0.0
		else:
			# A WORLD WITH NO SEA HAS NO PLATFORM, QUIETLY: a dry level is not a fault, and nothing could be found there.
			if not Terrain.has_sea():
				print_verbose("OilField: this world has no sea, so '%s' is not built." % platform["name"])
				continue
			var anchor: Vector2 = platform["anchor"]
			at = Terrain.open_sea_near(Vector3(anchor.x, 0.0, anchor.y), float(platform["water"]))
			if at == Vector3.INF:
				refuse("OilField: no open sea %.0f m deep on this world, so '%s' is not built." % [
					float(platform["water"]), platform["name"]])
				continue
			at.y = Terrain.water_height(at)
			# ON THE DEEPEST FLOOR UNDER THE BASE, so a leg on a sloping bed is sunk into it rather than standing proud
			# of it: a buried foot is invisible, a floating one is a jacket hanging in the sea.
			var floor: float = Terrain.ground_height(at)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					floor = minf(floor, Terrain.ground_height(at + Vector3(sx * FEET.x, 0.0, sz * FEET.y)))
			depth = at.y - floor
		if depth < MIN_DEPTH or depth > MAX_DEPTH:
			refuse("OilField: '%s' would stand in %.1f m of water, outside %.0f-%.0f m, so it is not built."
				% [platform["name"], depth, MIN_DEPTH, MAX_DEPTH])
			continue
		out.append({"name": platform["name"], "position": at, "depth": depth})
	return out


## A SHIP'S WAYPOINTS WITH EVERY POINT INSIDE A PLATFORM'S SAFETY ZONE DROPPED. On both worlds today it drops nothing --
## the nearest ship point is 1,183 m off the island's platform and 8,258 m off the alpine one -- and it is here so a
## platform moved, or a pool respread, cannot send a ship at the jacket without anybody noticing.
static func keep_clear(pool: Array[Vector3]) -> Array[Vector3]:
	var places: Array[Dictionary] = sites()
	var kept: Array[Vector3] = []
	for at in pool:
		var clear: bool = true
		for site in places:
			var p: Vector3 = site["position"]
			clear = clear and Vector2(at.x - p.x, at.z - p.z).length() >= KEEP_CLEAR
		if clear:
			kept.append(at)
	return kept


## EVERY PLATFORM'S SOLID, for `Terrain.boxes()`, grouped `Group.OILRIG`, which nothing else draws.
static func boxes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for site in sites():
		for box in OilPlatform.collision_boxes(site["position"], float(site["depth"])):
			box["group"] = Terrain.Group.OILRIG
			out.append(box)
	return out


## THE PICTURE, handed the yard the towns and the towers are drawn by.
func draw_platforms(map: WorldMap, reach: float, yard: SceneryYard) -> void:
	var by_cell: Dictionary = {}
	var bounds: Dictionary = {}
	for site in sites():
		var at: Vector3 = site["position"]
		var cell: Vector2i = WorldMap.cell_of(at)
		if not map.has_cell(cell):
			push_warning("OilField: '%s' is outside the filed ground at %s." % [site["name"], at])
			continue
		var mine: Array = by_cell.get(cell, [])
		mine.append(site)
		by_cell[cell] = mine
		_laid.append(site)
		var depth: float = float(site["depth"])
		var box := AABB(at + Vector3(-90.0, -depth, -60.0), Vector3(180.0, depth + OilPlatform.flare_tip().y + 20.0, 120.0))
		bounds[cell] = box if not bounds.has(cell) else (bounds[cell] as AABB).merge(box)
	if by_cell.is_empty():
		return
	yard.add_layer(LAYER, bounds, reach, self,
		func(cell: Vector2i) -> Array[Node3D]:
			var out: Array[Node3D] = []
			for site in (by_cell[cell] as Array):
				var platform: Node3D = one(float(site["depth"]))
				platform.name = "OilPlatform_%s" % site["name"]
				platform.position = site["position"]
				_drawn.append(platform)
				if not _look.is_empty():
					light_for(platform, _look)
				out.append(platform)
			return out)


## WHAT THIS NODE HAS UNDERTAKEN TO DRAW, in solid boxes, for `tests/smoke.gd`'s count of the picture against the physics.
func drawn_solid() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for site in _laid:
		out.append_array(OilPlatform.collision_boxes(site["position"], float(site["depth"])))
	return out


## THE TIME OF DAY, handed on to every platform drawn and kept for those drawn later: a look, whose "like" blends every
## table below that is keyed by DAY, EVENING and NIGHT (`DaylightTuning.blend`), so the flare comes up through dusk as the
## sky goes down, and whose "lamps" says whether the floods are on.
func show_daylight(look: Dictionary) -> void:
	_look = look
	for platform in _drawn:
		if is_instance_valid(platform):
			light_for(platform, look)


## ONE PLATFORM, READY TO STAND ANYWHERE, AND IT NEEDS NO LEVEL: the structure, the flame, its lights. A gallery wants
## `OilField.one(150.0)` and nothing else. The origin is on the sea's surface over the jacket's middle.
static func one(depth: float = 150.0) -> Node3D:
	var platform := Node3D.new()
	platform.name = "OilPlatform"
	var built: Dictionary = OilPlatform.build(depth)
	var structure := MeshInstance3D.new()
	structure.name = "Structure"
	structure.mesh = built["mesh"]
	structure.set_surface_override_material(0, OilPlatform.steel_material())
	structure.set_surface_override_material(1, OilPlatform.window_material(0.0))
	structure.set_meta(&"parts", built["parts"])
	structure.set_meta(&"depth", depth)
	platform.add_child(structure)
	# THE FLAME, at the flare stack's tip, leaning a little away from the platform as the wind carries it.
	var flare := Node3D.new()
	flare.name = "Flare"
	flare.position = OilPlatform.flare_tip()
	platform.add_child(flare)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.center_offset = Vector3(0.0, 0.5, 0.0)
	var paint := ShaderMaterial.new()
	paint.shader = FLAME_SHADER
	var lean: Vector3 = (Vector3.UP + LEAN_STILL + Terrain.WIND * LEAN_PER_WIND).normalized()
	for k in range(FLAME.size()):
		var size: Vector4 = FLAME[k]
		var tongue := MeshInstance3D.new()
		tongue.name = "Flame%d" % k
		tongue.mesh = quad
		tongue.material_override = paint
		tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tongue.basis = Basis(Vector3.RIGHT * size.x, lean * size.y, Vector3.BACK)
		tongue.position = Vector3(size.w, 0.0, size.w * 0.5)
		tongue.set_instance_shader_parameter("seed", size.z)
		flare.add_child(tongue)
	var smoke := MeshInstance3D.new()
	smoke.name = "Smoke"
	smoke.mesh = quad
	var soot := ShaderMaterial.new()
	soot.shader = SMOKE_SHADER
	smoke.material_override = soot
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rise: Vector3 = (Vector3.UP + LEAN_STILL * 2.0 + Terrain.WIND * LEAN_PER_WIND * 3.0).normalized()
	smoke.basis = Basis(Vector3.RIGHT * SMOKE.x, rise * SMOKE.y, Vector3.BACK)
	smoke.position = lean * float(FLAME[0].y) * 0.6
	flare.add_child(smoke)
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	halo.mesh = quad_centred()
	var bloom := ShaderMaterial.new()
	bloom.shader = HALO_SHADER
	halo.material_override = bloom
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.scale = Vector3.ONE * HALO_ACROSS
	halo.position = flame_middle() - OilPlatform.flare_tip()
	halo.visible = false
	flare.add_child(halo)
	var glow := OmniLight3D.new()
	glow.name = "FlareLight"
	glow.position = OilPlatform.flare_tip() + Vector3.UP * 6.0
	glow.light_color = Color(1.0, 0.62, 0.30)
	glow.omni_range = FLARE_RANGE
	glow.light_energy = 0.0
	glow.visible = false
	platform.add_child(glow)
	var flood := OmniLight3D.new()
	flood.name = "DeckLight"
	flood.position = Vector3(-4.0, OilPlatform.WEATHER_DECK + 12.0, 0.0)
	flood.light_color = Color(1.0, 0.88, 0.70)
	flood.omni_range = DECK_RANGE
	flood.light_energy = 0.0
	flood.visible = false
	platform.add_child(flood)
	var lights: VehicleLights = VehicleLights.build(OilPlatform.lights(), 7, false)
	lights.name = "Lights"
	platform.add_child(lights)
	var floods: VehicleLights = VehicleLights.build(OilPlatform.floods(), 11, false)
	floods.name = "Floods"
	floods.visible = false
	platform.add_child(floods)
	return platform


## THE FLAME'S MIDDLE, in the platform's frame: where its halo stands and what the sea reflects.
static func flame_middle() -> Vector3:
	var lean: Vector3 = (Vector3.UP + LEAN_STILL + Terrain.WIND * LEAN_PER_WIND).normalized()
	return OilPlatform.flare_tip() + lean * float(FLAME[0].y) * 0.4


## THE FOUR DECK LAMPS THE SEA REFLECTS, in the platform's frame: of the floods on the lowest deck, the one nearest each
## corner of it, so the four streaks stand under the lit block's ends from wherever it is seen. Read off
## `OilPlatform.floods()`, so a lamp moved there moves its reflection.
static func glint_lamps() -> Array[Vector3]:
	var lowest: float = INF
	var row: Array[Vector3] = []
	for lamp in OilPlatform.floods():
		lowest = minf(lowest, (lamp["position"] as Vector3).y)
	for lamp in OilPlatform.floods():
		if is_equal_approx((lamp["position"] as Vector3).y, lowest):
			row.append(lamp["position"])
	var out: Array[Vector3] = []
	var span := AABB(row[0], Vector3.ZERO)
	for p in row:
		span = span.expand(p)
	for corner in [Vector2(span.position.x, span.position.z), Vector2(span.end.x, span.position.z),
			Vector2(span.end.x, span.end.z), Vector2(span.position.x, span.end.z)]:
		var best: Vector3 = row[0]
		for p in row:
			if Vector2(p.x, p.z).distance_to(corner) < Vector2(best.x, best.z).distance_to(corner):
				best = p
		out.append(best)
	return out


## WHAT THE OCEAN SHADERS ARE HANDED FOR ONE PLATFORM AT ONE TIME OF DAY (`sea_glint.gdshaderinc`'s globals), or for
## none when `platform` is null: the flare's middle and radius, its colour times strength with 1 in alpha when it is lit,
## the four lamps as a Projection's columns, and their colour. Pure, so a suite can read it without a renderer.
static func glint_numbers(platform: Node3D, look: Dictionary) -> Dictionary:
	var like: Vector3 = look.get("like", Vector3(1.0, 0.0, 0.0))
	var flare: float = float(DaylightTuning.blend(FLARE_GLINT, like)) if platform != null else 0.0
	var lamp: float = float(DaylightTuning.blend(LAMP_GLINT, like)) if platform != null else 0.0
	var origin: Vector3 = platform.global_position if platform != null else Vector3.ZERO
	var middle: Vector3 = origin + flame_middle()
	var columns: Array[Vector4] = []
	for p in glint_lamps():
		var at: Vector3 = origin + p
		columns.append(Vector4(at.x, at.y, at.z, LAMP_GLINT_RADIUS))
	var warm: Color = FLARE_GLINT_COLOUR * flare
	var deck: Color = LAMP_GLINT_COLOUR * lamp
	return {
		&"sea_glint_flare": Vector4(middle.x, middle.y, middle.z, FLARE_GLINT_RADIUS),
		&"sea_glint_flare_colour": Vector4(warm.r, warm.g, warm.b, 1.0 if flare > 0.0 else 0.0),
		&"sea_glint_lamps": Projection(columns[0], columns[1], columns[2], columns[3]),
		&"sea_glint_lamps_colour": Vector4(deck.r, deck.g, deck.b, 1.0 if lamp > 0.0 else 0.0),
	}


## HAND THE OCEAN SHADERS THE GLINTS OF THE DRAWN PLATFORM NEAREST THE EYE. Only on a change: the platform nearest, or the
## time of day. One flare is reflected at a time; a second platform kilometres off is past the mist anyway.
func _process(_delta: float) -> void:
	var eye: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var nearest: Node3D = null
	for platform in _drawn:
		if not is_instance_valid(platform) or not platform.is_inside_tree():
			continue
		if nearest == null or (eye != null and eye.global_position.distance_squared_to(platform.global_position)
				< eye.global_position.distance_squared_to(nearest.global_position)):
			nearest = platform
	var when: int = int(_look.get("n", -1))
	if nearest != _glint_from or when != _glint_when:
		_glint_from = nearest
		_glint_when = when
		var numbers: Dictionary = glint_numbers(nearest, _look)
		for field in numbers.keys():
			RenderingServer.global_shader_parameter_set(field, numbers[field])


## AND NOTHING WHEN THIS WORLD GOES, so the next world's sea does not reflect a flare it has not got.
func _exit_tree() -> void:
	var none: Dictionary = glint_numbers(null, {})
	for field in none.keys():
		RenderingServer.global_shader_parameter_set(field, none[field])


## A 1 m QUAD CENTRED ON ITS ORIGIN, for the halo, which faces the eye from its middle.
static func quad_centred() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	return quad


## A PLATFORM LIT BY A LOOK: the flare's light and the deck's flood, off by day, and the windows' glow -- every number off
## its table blended by the look's "like", and the floods on as the look's "lamps" says. The windows' material is made once
## and then only re-lit, since a clock running fast lights a platform twice a second.
static func light_for(platform: Node3D, look: Dictionary) -> void:
	var like: Vector3 = look["like"]
	var flare_energy: float = float(DaylightTuning.blend(FLARE_ENERGY, like))
	var deck_energy: float = float(DaylightTuning.blend(DECK_ENERGY, like))
	var glow := platform.get_node_or_null("FlareLight") as OmniLight3D
	if glow != null:
		glow.light_energy = flare_energy
		glow.visible = flare_energy > 0.0
	var flood := platform.get_node_or_null("DeckLight") as OmniLight3D
	if flood != null:
		flood.light_energy = deck_energy
		flood.visible = deck_energy > 0.0
	# THE SMOKE IS LIT BY ITS OWN FLAME AT NIGHT: soot-dark by day, a dull red-brown after dark, orange underneath.
	var smoke := platform.get_node_or_null("Flare/Smoke") as MeshInstance3D
	if smoke != null:
		var soot := smoke.material_override as ShaderMaterial
		soot.set_shader_parameter("smoke_colour", DaylightTuning.blend(SMOKE_COLOUR, like))
		soot.set_shader_parameter("underlit_share", DaylightTuning.blend(SMOKE_UNDERLIT, like))
	var halo := platform.get_node_or_null("Flare/Halo") as MeshInstance3D
	if halo != null:
		var strength: float = float(DaylightTuning.blend(HALO_STRENGTH, like))
		halo.visible = strength > 0.0
		(halo.material_override as ShaderMaterial).set_shader_parameter("strength", strength)
	var tongue := platform.get_node_or_null("Flare/Flame0") as MeshInstance3D
	if tongue != null:
		(tongue.material_override as ShaderMaterial).set_shader_parameter("heat", DaylightTuning.blend(FLAME_HEAT, like))
	var floods := platform.get_node_or_null("Floods") as Node3D
	if floods != null:
		floods.visible = bool(look.get("lamps", int(look.get("time", 0)) != DaylightTuning.When.DAY))
	var structure := platform.get_node_or_null("Structure") as MeshInstance3D
	if structure != null:
		var shine: float = float(look.get("window_glow", 0.0)) * WINDOW_SHARE
		var glass := structure.get_surface_override_material(1) as StandardMaterial3D
		if glass == null:
			structure.set_surface_override_material(1, OilPlatform.window_material(shine))
		else:
			glass.emission_enabled = shine > 0.0
			glass.emission_energy_multiplier = shine
