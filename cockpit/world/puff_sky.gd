extends Node3D
class_name PuffSky
## A LAYERED SKY OF PUFF CLOUDS: cumulus low, stratocumulus over them, altocumulus in the middle and cirrus high, with clear
## air between the layers so an aeroplane can fly through a cloud, round it, or between two decks. A PROTOTYPE (lane/clouds2,
## 2026-09-17) beside `LiftYard`'s clouds; see `PuffCloud` for why a puff, and research/clouds_2.md for the rest.
##
## ONE BATCH A KIND. Every puff of a kind is one instance of one MultiMesh, drawn with that kind's material, so a whole sky is
## six draw calls however many clouds it holds. The kind's row in `PuffCloud.KINDS` is written onto its material once.
##
## EVERY PEER DRAWS ONE SKY. `level_sky` is static and pure, fed by the world's own seed and `Terrain.lift_zones()`, which
## every peer generates alike (no cloud is on the wire, as no lift zone is); what the host decides is whether there are
## clouds at all, `Net.clouds_on`, as it did for LiftYard's (tests/sky_peers.gd). Wired into FlightLevel on 2026-09-17,
## after the user saw the six kinds: "all clouds look good".
##
## A THERMAL KEEPS ITS CLOUD. Every lift zone grows a flat-based cumulus if it is strong and a cumulus if it is not, its base
## at the column's top and as wide as `LiftYard.CLOUD_SPREAD` spreads the column, so the sky is still the glider pilot's map
## (see the note at the top of LiftYard); LiftYard keeps the wisps and the rings and draws no lumps when these are worn.

const SHADER: Shader = preload("res://world/shaders/puff.gdshader")
## THE CHEAPER, WORSE ONE: no depth texture read, the engine's depth test instead. Kept to price the depth copy against; see
## world/shaders/puff.gdshaderinc.
const SHADER_DEPTH_TESTED: Shader = preload("res://world/shaders/puff_depth_tested.gdshader")
## A unit sphere's mesh a little larger than the sphere, so its back faces cover every pixel of the sphere the shader
## draws: a 16 by 8 sphere's flat faces come in to cos(pi / 16) * cos(pi / 16), 0.96, of its radius.
const MESH_RADIUS: float = 1.08
## The metres a puff's cloud reach is carried in, as a share of: the instance colour is eight bits a channel, so a reach
## of up to this is carried to about 20 m. The shader's `reach_unit`, written from here.
const REACH_UNIT: float = 5000.0

## HOW MANY OF EACH KIND A PLANNED SKY HOLDS in an area `half` metres each way from the middle, per 100 square kilometres.
const PER_100_KM2: Dictionary = {
	"cumulus": 6.0, "flat_based": 3.0, "towering": 1.0, "stratocumulus": 1.2, "altocumulus": 1.0, "cirrus": 0.8,
}

## HOW THE TOWERS ARE GROUPED: about this many to a wall, each WALL_STEP of the narrowest tower's width along from the last,
## so their masses overlap and the wall has no gaps down to its base.
const WALL_TOWERS: int = 4
const WALL_STEP: float = 0.6

## THE LOW CLOUDS, the kinds a level's `cloud_cover` multiplies (lane/gliderlevel, 2026-09-19: "make sure we have good clouds as
## well so that we have to find our way around the clouds themselves"): the layers a glider flies among. The decks above them
## stay the game's, since nothing that soars reaches them.
const LOW: Array[String] = ["cumulus", "flat_based", "towering"]

## Over a thermal this strong or stronger, a flat-based cumulus; under it, a fair-weather one.
const STRONG_THERMAL: float = 4.0
## HOW FAR THE LEVEL'S SKY REACHES from the world's middle, at most: a MultiMesh draws every instance it holds, so a sky over
## the whole 64 km alpine world would be about 40,000 puffs. Streaming it round the eye is the next step (learnings).
const SKY_REACH: float = 16000.0
## How much further than the land the sky reaches, so the island's coast has clouds offshore.
const SKY_PAST_THE_LAND: float = 5000.0
## "THE EYE IS IN A CLOUD", as a depth 0 to 1: the density a metre at which it is 1, a flat-based cumulus's core.
const WHOLLY_IN: float = 0.012
## HOW DEEP IN A CLOUD THE PUFFS HOLDING THE EYE GIVE WAY to the level's whiteout: whole at the first depth, gone by the second.
## Inside a cloud every puff holding the eye covers the screen in both eyes -- 1.333 ms at 2880x1620 against 0.321 for the
## whole layered sky (research/clouds_2.md) -- and the depth fog the level whites the view out with costs nothing more.
const GIVE_WAY := Vector2(0.35, 0.8)

## WHERE THE PUFFS ARE DRAWN AMONG THE SEE-THROUGH THINGS: straight after the low mist (`MistLayer`, at the least priority
## there is) and before every other one. A puff writes no depth and is not depth tested -- it ends each chord at the world's
## surface instead -- so a light or a trail drawn BEFORE it, even one in front of the cloud, is painted over: the first
## pictures in the level lost every aircraft's red light in front of the cloud_near and cloud_edge views at night
## (tests/scenery_shot.gd, 0.00 red px a light). Drawn first, a thing in front of a cloud is over it, as it should be, and
## the price is the other way round: a light or a contrail BEHIND a cloud shows through it. Open, in research/clouds_2.md.
const DRAWN_AT: int = Material.RENDER_PRIORITY_MIN + 1

## THE LOOK'S KNOBS: each `PuffCloud.KINDS` key and the shader uniform it is written to (see PuffCloud's note on KINDS).
const LOOK: Dictionary = {
	"crisp": "crisp", "bump": "bump", "relief": "lobe_relief", "body": "body", "shade_light": "shade_light",
	"terminator": "terminator", "top": "top_bright",
}
## THE SHADED SIDE'S TINT on the sky's light: a blue-grey, as the shade of a cumulus in a clear sky is, never a neutral grey.
const SHADE_COLOUR := Color(0.62, 0.84, 1.0)

var _batches: Dictionary = {}
var _fine: bool = true
## The look the puffs were last lit by, or {} before the level has said.
var _look: Dictionary = {}
var _eye_fade: float = 0.0
## Whether each chord is cut at the world's surface through the depth texture (the default), or depth tested. Set before
## `show_clouds`.
var cut_at_the_world: bool = true
var clouds: Array = []


## A LAYERED SKY from one seed: each kind scattered over the square `half` metres each way, each cloud stood over the ground
## `ground` answers (see `PuffCloud.lay_out`). `cover` multiplies how many of the LOW kinds there are; at 1, the default and
## every level but the glider level, the draws and the sky are exactly what they were.
static func plan(seed: int, half: float, ground: Callable = Callable(), cover: float = 1.0) -> Array[Dictionary]:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed
	var out: Array[Dictionary] = []
	var area := (half * 2.0 / 10000.0) * (half * 2.0 / 10000.0)
	for kind in PER_100_KM2:
		var count := maxi(1, roundi(float(PER_100_KM2[kind]) * area * (cover if LOW.has(kind) else 1.0)))
		var places: Array = []
		for c in range(count):
			var at := Vector3(dice.randf_range(-half, half), 0.0, dice.randf_range(-half, half))
			places.append([at, dice.randi()])
		# THE SAME DRAWS FOR EVERY KIND, whatever is done with them, so grouping the towers moved no other cloud in the sky.
		if kind == "towering":
			var walls := maxi(1, roundi(float(count) / float(WALL_TOWERS)))
			for w in range(walls):
				var seeds: Array = []
				for c in range(w, count, walls):
					seeds.append(places[c][1])
				out.append_array(wall(places[w][0], seeds, ground))
		else:
			for place in places:
				out.append(PuffCloud.lay_out(kind, place[0], place[1], ground))
	return out


## A WALL OF TOWERING CUMULUS: one tower for each of `seeds`, stood shoulder to shoulder along a heading drawn from the first
## seed, each WALL_STEP of a tower's width from the last and a little in front of or behind the line, so a line of towers
## reads as one wall of billowing cloud with its heads at different heights. Asked for by the user, off a film still (clouds3,
## 2026-09-18): the towers were standing in a row, one apart from the next.
## `heading` (radians about the vertical) lays the wall along a given way, for a picture composed round it; INF draws one.
static func wall(at: Vector3, seeds: Array, ground: Callable = Callable(), heading: float = INF) -> Array[Dictionary]:
	var dice := RandomNumberGenerator.new()
	dice.seed = int(seeds[0]) ^ 0x5eed
	var drawn := dice.randf() * TAU
	if heading == INF:
		heading = drawn
	var along := Vector3(cos(heading), 0.0, sin(heading))
	var across := Vector3(-along.z, 0.0, along.x)
	var width: float = (PuffCloud.KINDS["towering"]["width"] as Vector2).x
	var out: Array[Dictionary] = []
	for t in range(seeds.size()):
		var offset := (float(t) - float(seeds.size() - 1) * 0.5) * width * WALL_STEP
		var place := at + along * offset + across * dice.randf_range(-0.25, 0.25) * width
		out.append(PuffCloud.lay_out("towering", place, int(seeds[t]), ground))
	return out


## A THERMAL'S CLOUD for each lift zone: flat-based over a strong one, fair-weather over a weak one, its base at the column's
## top, as wide as the column spreads, seeded by where the zone is (as `LiftYard.cloud_lumps` is).
static func thermal_clouds(zones: Array, ground: Callable = Callable()) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for zone in zones:
		var at: Vector3 = zone["position"]
		var kind := "flat_based" if float(zone["strength"]) >= STRONG_THERMAL else "cumulus"
		var seed := int(Terrain.hash01(int(at.x) * 7919 + int(at.z), 211) * 2147483647.0)
		var cloud := PuffCloud.lay_out(kind, at, seed, ground, {"base": float(zone["top"]),
			"width": float(zone["radius"]) * LiftYard.CLOUD_SPREAD * 2.0})
		# ONE NAME FOR A THERMAL'S CLOUD, whichever clouds are worn: the key LiftYard and CloudBank know it by.
		cloud["key"] = LiftYard.cloud_key(zone)
		out.append(cloud)
	return out


## THE LEVEL'S SKY: a cloud over every thermal, and the layered plan from `seed` over the land and SKY_PAST_THE_LAND beyond it,
## never more than SKY_REACH from the middle.
static func level_sky(seed: int, land_half: float, zones: Array, ground: Callable = Callable(),
		cover: float = 1.0) -> Array[Dictionary]:
	var out := thermal_clouds(zones, ground)
	out.append_array(plan(seed, minf(land_half + SKY_PAST_THE_LAND, SKY_REACH), ground, cover))
	return out


## DRAW `sky`: one MultiMesh a kind, every puff an instance carrying its cloud's base, thickness, seed and density.
func show_clouds(sky: Array) -> void:
	clouds = sky
	for batch in _batches.values():
		(batch as Node).queue_free()
	_batches.clear()
	var by_kind: Dictionary = {}
	for cloud in sky:
		if not by_kind.has(cloud["kind"]):
			by_kind[cloud["kind"]] = []
		(by_kind[cloud["kind"]] as Array).append(cloud)
	for kind in by_kind:
		var count := 0
		for cloud in by_kind[kind]:
			count += (cloud["puffs"] as Array).size()
		var many := MultiMesh.new()
		many.transform_format = MultiMesh.TRANSFORM_3D
		many.use_custom_data = true
		many.use_colors = true
		many.mesh = _sphere()
		many.instance_count = count
		var i := 0
		for cloud in by_kind[kind]:
			var custom := Color(cloud["base"], cloud["thickness"], fmod(float(cloud["seed"]) / 997.0, 1.0), cloud["density"])
			var middle := PuffCloud.middle_of(cloud)
			var reach := PuffCloud.reach_of(cloud)
			for puff in cloud["puffs"]:
				many.set_instance_transform(i, PuffCloud.puff_transform(puff))
				many.set_instance_custom_data(i, custom)
				# WHERE THE PUFF IS IN ITS CLOUD, for the shader to light the cloud as one: see puff.gdshader.
				var offset: Vector3 = ((puff["centre"] as Vector3) - middle) / reach
				many.set_instance_color(i, Color(clampf(offset.x * 0.5 + 0.5, 0.0, 1.0), clampf(offset.y * 0.5 + 0.5, 0.0, 1.0),
					clampf(offset.z * 0.5 + 0.5, 0.0, 1.0), clampf(reach / REACH_UNIT, 0.0, 1.0)))
				i += 1
		var batch := MultiMeshInstance3D.new()
		batch.name = kind
		batch.multimesh = many
		batch.material_override = material_for(kind, cut_at_the_world)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
		_batches[kind] = batch
	_write_everything()


## THE MATERIAL A KIND IS DRAWN WITH: the shader and the kind's own numbers from its row.
static func material_for(kind: String, cut := true) -> ShaderMaterial:
	var row: Dictionary = PuffCloud.KINDS[kind]
	var paint := ShaderMaterial.new()
	paint.shader = SHADER if cut else SHADER_DEPTH_TESTED
	paint.set_shader_parameter("firm", row["firm"])
	paint.set_shader_parameter("noise_cell", row["noise_cell"])
	paint.set_shader_parameter("base_shade", row["shade"])
	paint.set_shader_parameter("flat_layer", row.get("layer", false))
	paint.set_shader_parameter("reach_unit", REACH_UNIT)
	for knob in LOOK:
		paint.set_shader_parameter(LOOK[knob], row[knob])
	paint.set_shader_parameter("shade_colour", SHADE_COLOUR)
	paint.render_priority = DRAWN_AT
	return paint


## SHOW THE SUN on every kind: where it is and its colour, and the sky's. The probe's; a level says `show_daylight`.
func show_sun(towards: Vector3, sun: Color, sky: Color) -> void:
	_set_on_all("towards_sun", towards.normalized())
	_set_on_all("sun_light", sun)
	_set_on_all("sky_light", sky)


## THE TIME OF DAY, from the numbers LiftYard's clouds are lit by (`LiftYard.cloud_light`), so a puff at evening is the
## colour a lump was: the sun, where it is, the sky's light, and the shade's under the base. Written once per change.
func show_daylight(look: Dictionary) -> void:
	_look = look
	_write_everything()


## THE FINISH: PLAIN takes one octave of noise, FINE all of it.
func wear(fine: bool) -> void:
	_fine = fine
	_write_everything()


## HOW DEEP IN A CLOUD THE EYE IS (the level's `eye_in_cloud` depth), and so how far the puffs holding it have given way.
func show_eye_in_cloud(depth: float) -> void:
	_eye_fade = give_way(depth)
	_set_on_all("eye_gone", _eye_fade)


## How far the puffs holding the eye have given way at `depth`, and so how much of the whiteout the level's depth fog carries.
static func give_way(depth: float) -> float:
	return smoothstep(GIVE_WAY.x, GIVE_WAY.y, depth)


## WHERE THE EYE IS, in cloud: {depth 0 to 1, key}: a thermal's cloud by its zone's `LiftYard.cloud_key`, any other by its
## middle to the metre in plan.
func eye_in(point: Vector3) -> Dictionary:
	var most := 0.0
	var key := Vector2i.ZERO
	for cloud in clouds:
		if not _might_hold(cloud, point):
			continue
		var here := PuffCloud.density_at(cloud, point)
		if here > most:
			most = here
			if cloud.has("key"):
				key = cloud["key"]
			else:
				var m := PuffCloud.middle_of(cloud)
				key = Vector2i(roundi(m.x), roundi(m.z))
	return {"depth": clampf(most / WHOLLY_IN, 0.0, 1.0), "key": key}


## A quick no: the point is outside the box round the cloud's puffs (worked out once, and kept on the cloud).
static func _might_hold(cloud: Dictionary, point: Vector3) -> bool:
	if not cloud.has("box"):
		var box := AABB()
		var first := true
		for puff in cloud["puffs"]:
			var r: Vector3 = puff["radii"]
			var reach := maxf(r.x, r.z)
			var piece := AABB((puff["centre"] as Vector3) - Vector3(reach, r.y, reach), Vector3(reach, r.y, reach) * 2.0)
			box = piece if first else box.merge(piece)
			first = false
		cloud["box"] = box
	return (cloud["box"] as AABB).has_point(point)


func _write_everything() -> void:
	_set_on_all("fine", _fine)
	_set_on_all("eye_gone", _eye_fade)
	if _look.is_empty():
		return
	var light: Dictionary = LiftYard.cloud_light(_look)
	_set_on_all("towards_sun", (light["towards_sun"] as Vector3).normalized())
	_set_on_all("sun_light", light["sun_light"])
	_set_on_all("sky_light", light["sky_light"])
	_set_on_all("base_light", light["shade_light"])


func _set_on_all(uniform: String, value: Variant) -> void:
	for batch in _batches.values():
		((batch as MultiMeshInstance3D).material_override as ShaderMaterial).set_shader_parameter(uniform, value)


## HOW MANY PUFFS each kind's batch draws, and how many batches, for the budget.
func puff_count() -> int:
	var n := 0
	for cloud in clouds:
		n += (cloud["puffs"] as Array).size()
	return n


func batch_count() -> int:
	return _batches.size()


## HOW MUCH CLOUD IS AT `point` per metre, over the whole sky: the densest cloud's, from `PuffCloud.density_at`. Asked of
## the camera the viewport draws with, it is "is the eye in a cloud"; zero is clear air.
func density_at(point: Vector3) -> float:
	return densest_at(clouds, point)


static func densest_at(sky: Array, point: Vector3) -> float:
	var most := 0.0
	for cloud in sky:
		if _might_hold(cloud, point):
			most = maxf(most, PuffCloud.density_at(cloud, point))
	return most


static func _sphere() -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = MESH_RADIUS
	sphere.height = MESH_RADIUS * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	return sphere


## WHETHER A LEVEL WEARS THE PUFFS, from what `--clouds=` asked for (`CloudBank.asked_on_the_command_line`): by default and
## on `--clouds=puffs`; not on `lumps` or `fog`, which are LiftYard's clouds and the fog laid out from them, nor on `none`.
static func worn_for(asked: String) -> bool:
	return asked == "" or asked == "puffs"


## THE GROUND UNDER A POINT for a cloud to clear: `Terrain.ground_height`, and the sea where there is no land (it answers
## -INF off the island's slab).
static func ground_under(at: Vector3) -> float:
	return maxf(Terrain.ground_height(at), Terrain.SEA_LEVEL)


## HOW MUCH CLOUD LIES BETWEEN TWO POINTS, as optical depth: the sum of `density_at` along the segment, in `steps` pieces,
## noise at its mean as the eye test takes it. A probe asks it of a light it is about to look for; 2 is 86 % of it gone.
func optical_depth_between(from: Vector3, to: Vector3, steps: int = 48) -> float:
	var total := 0.0
	var step := from.distance_to(to) / float(steps)
	for s in range(steps):
		total += densest_at(clouds, from.lerp(to, (float(s) + 0.5) / float(steps))) * step
	return total
