extends RefCounted
class_name WindSea
## THE WIND-SEA: the short waves both ocean shaders paint over the simulation's swell, worked out from the wind and handed
## to a sea's material. A normal, a roughness and foam; never a height (`world/shaders/ocean_detail.gdshaderinc`).
##
## Asked for on 2026-09-15: "ocean's are often much more tumultous and have more varied waves, it's usually darker and has
## more ripples". The sea painted two chop wavelets of typed direction, length and height, and read as a glassy lake near
## the eye with corduroy to the horizon (godotgames-drafts/2026-09-15/cockpit-ocean/before). The simulation's swell is
## not short of height -- 0.42 m and 0.34 m waves, Hs about 1.5 m -- but of SLOPE: its slope variance is 0.0002, where a
## real sea's, measured from sun glitter by Cox and Munk, is 0.003 + 0.00512 U, or 0.044 at 8 m/s.
##
## SO NOTHING HERE IS A TYPED HEIGHT. The wind decides the slope variance, a share of it is left to the ripples no finish
## draws (roughness), what the swell already carries is taken off, and the rest is shared equally among `MOST` waves from
## `LONGEST` down by `RATIO`, the equilibrium range of a wind-sea, where each octave of wavelength adds about the same
## slope. Each wave's height is what gives its share, and its speed is the one deep water gives its length, √(g k): typed
## speeds put a 38 m wave and a 1 m wave at one pace, and the old fine sea read as one sheet sliding.
##
## WHOLE WAVES IN THE TILE. Each wave vector is rounded to a whole number of waves across `TILE`, in both axes, so the
## shader's wrap is seamless (the swell's two seams: agents.md, "A wrap is seamless only if the swell is periodic in it").
##
## WHITECAPS BY THE WIND. The share of sea covered in foam is Monahan and O'Muircheartaigh's 3.84e-6 U^3.41 -- 0.09 % at
## 5 m/s, 1.8 % at 12 -- and the curvature a crest must pass to break is solved for that share, treating the breaking waves'
## summed curvature as normally distributed.

## The tile every wave is whole across, metres.
const TILE: float = 512.0
## The longest painted wave, metres, and each next one's length as a share of the one before.
const LONGEST: float = 38.0
const RATIO: float = 0.615
## How many waves are worked out. PLAIN paints the first eight, FINE all ten (`WAVES_PAINTED` in each shader); the
## shader counts the slope of the ones it does not paint into its roughness itself.
const MOST: int = 10
## Each wave's heading off the swell's, degrees: spread and out of order, so no two neighbours in length lie alike.
const SPREAD: PackedFloat32Array = [0.0, -35.0, 50.0, -62.0, 20.0, -15.0, 68.0, -48.0, 8.0, -28.0]
## The share of the slope variance left to ripples shorter than any wave painted, as roughness.
const UNPAINTED_SHARE: float = 0.3
## Waves longer than this, metres, are the ones whose crests break into whitecaps. Every one of them must be a sine both
## finishes paint (`WAVES_PAINTED`, 4: 38 m to 8.8 m), because the threshold is solved for their summed curvature; at 3 m
## the 5.4 and 3.3 m waves were counted, and they became noise ripples (after5).
const BREAKING_LONGER_THAN: float = 6.0
## Waves shorter than this, metres, are the ones gusts roughen.
const GUSTY_BELOW: float = 4.0
const GRAVITY: float = 9.81

## THE RIPPLE MAPS: two normal maps made of noise when a sea is first built, which the shader reads for every ripple shorter
## than the sines -- the exception to "no textures anywhere", because seven octaves of noise worked out per pixel cost a
## headset's two eyes up to +1.09 ms against a +0.3 ms budget (agents.md, "WHAT THE PAINTED SEA MAY COST"). Seamless fractal
## noise (`FastNoiseLite.get_seamless_image`, the generator `NoiseTexture2D` wraps, made here so its slope can be measured
## before it is handed), turned into a normal map and mipmapped. Nothing is imported.
## Pixels a side.
const RIPPLE_MAP_SIZE: int = 1024
## Each map's tile in metres, long and short: at a non-integer ratio, so their repeats never line up. THE LONG MAP'S LONGEST
## OCTAVE LIES UNDER THE SINES: at 51.7 m it began at 6.5 m, too little noise at the sines' own scale, and their lattice
## came back as a crosshatch in the glitter from 60 m and 200 m, gone with the sines off (drafts cockpit-ocean, after-A8b
## against diag-A8-nosines). And 51.7 over 7.3 is 7.08, a repeat that nearly lines up (tests/wind_sea.gd).
const RIPPLE_MAP_TILES: PackedFloat32Array = [96.3, 7.3]
## The short map is read a second time at this many times its tile.
const RIPPLE_MAP_AGAIN: float = 1.37
## Each map's octaves. Eight cells a tile at the longest, each next half the one before, gain a half: every octave carries the
## same slope. The long map's run from 12 m to 1.5 m; the short map's from 0.9 m to 3 cm.
const RIPPLE_MAP_OCTAVES: PackedInt32Array = [4, 6]
const RIPPLE_MAP_CELLS_A_TILE: float = 8.0
## How steep the normal map is drawn from the noise's height. Only its shape is used: its slope is measured and scaled.
const RIPPLE_MAP_BUMP: float = 8.0
const RIPPLE_MAP_SEEDS: PackedInt32Array = [31, 57]
static var _ripple_maps: Dictionary = {}


## THE TWO RIPPLE MAPS, made once and kept: {"textures": [long, short], "variances": [long, short]}, each variance the
## decoded slope variance of its full-size image.
static func ripple_maps() -> Dictionary:
	if not _ripple_maps.is_empty():
		return _ripple_maps
	var textures: Array[ImageTexture] = []
	var variances := PackedFloat32Array()
	for i in range(RIPPLE_MAP_TILES.size()):
		var noise := FastNoiseLite.new()
		noise.seed = RIPPLE_MAP_SEEDS[i]
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = RIPPLE_MAP_OCTAVES[i]
		noise.fractal_lacunarity = 2.0
		noise.fractal_gain = 0.5
		noise.frequency = RIPPLE_MAP_CELLS_A_TILE / float(RIPPLE_MAP_SIZE)
		var image: Image = noise.get_seamless_image(RIPPLE_MAP_SIZE, RIPPLE_MAP_SIZE, false, false, 0.1, true)
		image.convert(Image.FORMAT_RGBA8)
		image.bump_map_to_normal_map(RIPPLE_MAP_BUMP)
		variances.append(decoded_slope_variance(image))
		image.generate_mipmaps(true)
		textures.append(ImageTexture.create_from_image(image))
	_ripple_maps = {"textures": textures, "variances": variances}
	return _ripple_maps


## A NORMAL MAP'S SLOPE VARIANCE AS THE SHADER DECODES IT: (-red, green) over blue, each channel from 0..1 to -1..1, both
## directions together, over every seventh texel of its full-size image (`ocean_detail.gdshaderinc`, `ripple_map_slope`).
static func decoded_slope_variance(image: Image) -> float:
	var sum := Vector2.ZERO
	var square: float = 0.0
	var count: int = 0
	for y in range(0, image.get_height(), 7):
		for x in range(0, image.get_width(), 7):
			var colour: Color = image.get_pixel(x, y)
			var n := Vector3(colour.r * 2.0 - 1.0, colour.g * 2.0 - 1.0, colour.b * 2.0 - 1.0)
			var slope := Vector2(-n.x, n.y) / maxf(n.z, 0.2)
			sum += slope
			square += slope.length_squared()
			count += 1
	var mean: Vector2 = sum / float(maxi(count, 1))
	return square / float(maxi(count, 1)) - mean.length_squared()


## THE SPEED A READ OF A MAP DRIFTS DOWN THE WIND: deep water's for a wave as long as its middle octave's cell.
static func ripple_map_drift(tile: float, octaves: int) -> float:
	var middle: float = tile / RIPPLE_MAP_CELLS_A_TILE * pow(0.5, 0.5 * float(octaves - 1))
	return sqrt(GRAVITY * middle / TAU)
## THE WIND THE SEA IS PAINTED FOR: the middle of the ships' weather, `Terrain.weather()`, which the brigs sail in and
## which wanders between its `low` and `high`. The sea is painted for it once, when a sea is built; nothing follows the
## wander frame by frame, and nothing is written each frame.
static func ships_wind() -> float:
	var weather: Dictionary = Terrain.weather()
	return 0.5 * (float(weather["low"]) + float(weather["high"]))


## A REAL SEA'S SLOPE VARIANCE in a wind of `wind` m/s, both directions together (Cox and Munk).
static func slope_variance(wind: float) -> float:
	return 0.003 + 0.00512 * maxf(wind, 0.0)


## THE SHARE OF SEA WHITECAPS COVER in a wind of `wind` m/s (Monahan and O'Muircheartaigh 1980).
static func whitecap_cover(wind: float) -> float:
	return 3.84e-6 * pow(maxf(wind, 0.0), 3.41)


## The slope variance the simulation's standing swell already carries, from the shape it hands the seas.
static func swell_slope_variance(standing: Dictionary) -> float:
	if standing.is_empty():
		return 0.0
	var first: float = (standing["first"] as Vector2).length() * float(standing["height"])
	var second: float = (standing["second"] as Vector2).length() * float(standing["second_height"])
	var variance: float = 0.5 * (first * first + second * second)
	# AND THE WIND-SEA THE BOATS FEEL (C1), each (x, z, height): its slope is the painted spectrum's to not repeat.
	for wave in (standing.get("wind_waves", []) as Array):
		var steep: float = Vector2((wave as Vector3).x, (wave as Vector3).y).length() * (wave as Vector3).z
		variance += 0.5 * steep * steep
	return variance


## THE WAVES, longest first: each `{k: Vector2, height: float, speed: float}`, k in radians a metre, whole across `TILE`.
static func waves(wind: float, standing: Dictionary) -> Array[Dictionary]:
	var total: float = slope_variance(wind)
	var painted: float = maxf(total * (1.0 - UNPAINTED_SHARE) - swell_slope_variance(standing), 0.0)
	var share: float = painted / float(MOST)
	var heading: Vector2 = Terrain.SWELL_HEADING.normalized()
	var out: Array[Dictionary] = []
	var taken: Array[Vector2i] = []
	var wavelength: float = LONGEST
	for i in range(MOST):
		var along: Vector2 = heading.rotated(deg_to_rad(SPREAD[i]))
		var whole := Vector2i(roundi(along.x * TILE / wavelength), roundi(along.y * TILE / wavelength))
		# Two waves on one lattice vector would be one wave twice as steep; step to the next whole vector along.
		while whole == Vector2i.ZERO or taken.has(whole):
			whole += Vector2i(signi(roundi(along.x)) if absf(along.x) >= absf(along.y) else 0,
				signi(roundi(along.y)) if absf(along.y) > absf(along.x) else 0)
			if whole == Vector2i.ZERO:
				whole = Vector2i(1, 0)
		taken.append(whole)
		var k: Vector2 = Vector2(whole) * TAU / TILE
		var number: float = k.length()
		out.append({"k": k, "height": sqrt(2.0 * share) / number, "speed": sqrt(GRAVITY * number)})
		wavelength *= RATIO
	return out


## Samples of the sea the whitecap threshold is read from, and the ones already worked out, by wind.
const WHITECAP_SAMPLES: int = 60000
static var _thresholds: Dictionary = {}


## THE CURVATURE A BREAKING CREST PASSES, read off the waves themselves so the share of sea past it is `whitecap_cover`: the
## breaking waves' summed curvature k² a sin(k·p − ωt), sampled at seeded random points of the tile and times, and the
## threshold is the quantile that leaves that share above it. Worked out once a wind and kept.
##
## NOT A NORMAL DISTRIBUTION. The first version took the sum as normal with variance Σ ½ (k² a)² and solved ½ erfc for the
## tail; six sines have far lighter tails than a normal, and tests/wind_sea.gd sampled 0.04 % of the sea foaming at 8.5 m/s
## where Monahan's cover is 0.57 %, and none at all at 5 m/s.
static func whitecap_curvature(wind: float, standing: Dictionary) -> float:
	var cover: float = whitecap_cover(wind)
	if _thresholds.has(wind):
		return float(_thresholds[wind])
	var breaking: Array[Dictionary] = []
	for wave in waves(wind, standing):
		if TAU / (wave["k"] as Vector2).length() > BREAKING_LONGER_THAN:
			breaking.append(wave)
	if breaking.is_empty() or cover <= 0.0:
		return 1.0e9
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var curvatures := PackedFloat32Array()
	curvatures.resize(WHITECAP_SAMPLES)
	for s in range(WHITECAP_SAMPLES):
		var p := Vector2(rng.randf() * TILE, rng.randf() * TILE)
		var t: float = rng.randf() * 600.0
		var curvature: float = 0.0
		for wave in breaking:
			var k: Vector2 = wave["k"]
			curvature += k.length_squared() * float(wave["height"]) * sin(p.dot(k) - float(wave["speed"]) * t)
		curvatures[s] = curvature
	curvatures.sort()
	var threshold: float = curvatures[clampi(int(float(WHITECAP_SAMPLES) * (1.0 - cover)), 0, WHITECAP_SAMPLES - 1)]
	_thresholds[wind] = threshold
	return threshold


## HANDED TO A SEA'S MATERIAL, either finish: the waves, the unpainted roughness, and the whitecaps.
static func hand(material: ShaderMaterial, wind: float) -> void:
	if material == null:
		return
	var standing: Dictionary = Sim.swell_shape()
	var k := PackedVector2Array()
	var heights := PackedFloat32Array()
	var speeds := PackedFloat32Array()
	for wave in waves(wind, standing):
		k.append(wave["k"])
		heights.append(wave["height"])
		speeds.append(wave["speed"])
	material.set_shader_parameter("wind_sea_k", k)
	material.set_shader_parameter("wind_sea_height", heights)
	material.set_shader_parameter("wind_sea_speed", speeds)
	material.set_shader_parameter("wind_sea_tile", TILE)
	material.set_shader_parameter("wind_sea_unpainted", slope_variance(wind) * UNPAINTED_SHARE)
	material.set_shader_parameter("wind_sea_gusty_below", GUSTY_BELOW)
	material.set_shader_parameter("whitecap_longer_than", BREAKING_LONGER_THAN)
	material.set_shader_parameter("whitecap_curvature", whitecap_curvature(wind, standing))
	material.set_shader_parameter("whitecap_cover", whitecap_cover(wind))
	var maps: Dictionary = ripple_maps()
	var textures: Array = maps["textures"]
	var variances: PackedFloat32Array = maps["variances"]
	var again: float = RIPPLE_MAP_TILES[1] * RIPPLE_MAP_AGAIN
	material.set_shader_parameter("ripple_map_long", textures[0])
	material.set_shader_parameter("ripple_map_short", textures[1])
	material.set_shader_parameter("ripple_map_tile", Vector3(RIPPLE_MAP_TILES[0], RIPPLE_MAP_TILES[1], again))
	material.set_shader_parameter("ripple_map_variance", Vector2(variances[0], variances[1]))
	material.set_shader_parameter("ripple_map_octaves", Vector2(RIPPLE_MAP_OCTAVES[0], RIPPLE_MAP_OCTAVES[1]))
	material.set_shader_parameter("ripple_map_drift", Vector3(ripple_map_drift(RIPPLE_MAP_TILES[0], RIPPLE_MAP_OCTAVES[0]),
		ripple_map_drift(RIPPLE_MAP_TILES[1], RIPPLE_MAP_OCTAVES[1]), ripple_map_drift(again, RIPPLE_MAP_OCTAVES[1])))
