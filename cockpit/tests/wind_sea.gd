extends Node
## Headless: the wind-sea both ocean shaders paint is a real sea's slope, whole in its tile, and foams as much as the wind
## says -- measured by sampling the waves `WindSea.hand` gives a material, never by repeating the formulas that made them.
##
##   Godot --headless --path cockpit res://tests/wind_sea.tscn
##
## WHAT IS HELD, each at 5, 8.5 and 12 m/s (the ships' weather runs 5 to 12):
## - every wave vector is a whole number of waves across the tile in both axes, and no two share one;
## - the painted slope, sampled at 40,000 points of the tile, plus the unpainted share and the simulation's swell, is Cox and
##   Munk's measured slope variance, 0.003 + 0.00512 U, within 3 %;
## - the painted height wrapped as the shader wraps it is the unwrapped height, across x = 0, z = 0, the tile's edge and
##   30 km out, and steps less than a millimetre in a centimetre anywhere along those lines;
## - each wave moves at deep water's speed for its length, 1.249 √λ m/s (the rule seamen use), within 1 %;
## - the share of sampled sea whose breaking waves pass the handed curvature is Monahan and O'Muircheartaigh's whitecap
##   cover, 3.84e-6 U^3.41, within a third.
##
## Read RESULT=, not the exit code.

const WINDS: PackedFloat32Array = [5.0, 8.5, 12.0]
const SAMPLES: int = 40000

var _failures: PackedStringArray = []
var _sections: int = 0
const SECTIONS: int = 6


func _check(label: String, ok: bool, detail: String) -> void:
	print("[wind_sea] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_every_wave_is_whole_across_the_tile_and_no_two_share_a_vector()
	_the_painted_slope_is_a_real_seas_slope()
	_the_wrap_leaves_no_seam()
	_each_wave_moves_at_deep_waters_speed()
	_whitecaps_cover_what_the_wind_says()
	_the_ripple_maps_are_seamless_mipmapped_and_measured()
	_finish()


func _finish() -> void:
	_check("every_section_ran_to_its_end", _sections == SECTIONS, "%d of %d" % [_sections, SECTIONS])
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


## WHAT A SEA'S MATERIAL IS HANDED, read back off the material: the thing the shader receives.
func _handed(wind: float) -> Dictionary:
	var wet := ShaderMaterial.new()
	WindSea.hand(wet, wind)
	var out: Dictionary = {}
	for name in ["wind_sea_k", "wind_sea_height", "wind_sea_speed", "wind_sea_tile", "wind_sea_unpainted",
			"whitecap_longer_than", "whitecap_curvature", "whitecap_cover"]:
		out[name] = wet.get_shader_parameter(name)
	return out


func _every_wave_is_whole_across_the_tile_and_no_two_share_a_vector() -> void:
	for wind in WINDS:
		var handed: Dictionary = _handed(wind)
		var k: PackedVector2Array = handed["wind_sea_k"] if handed["wind_sea_k"] is PackedVector2Array else PackedVector2Array()
		var tile: float = float(handed["wind_sea_tile"]) if handed["wind_sea_tile"] != null else 0.0
		var worst: float = 0.0
		var seen: Dictionary = {}
		for one in k:
			var waves: Vector2 = one * tile / TAU
			worst = maxf(worst, maxf(absf(waves.x - roundf(waves.x)), absf(waves.y - roundf(waves.y))))
			seen[Vector2i(roundi(waves.x), roundi(waves.y))] = true
		_check("every_wave_is_whole_across_the_tile_at_%.1f_mps" % wind,
			k.size() == WindSea.MOST and tile > 0.0 and worst < 0.001 and seen.size() == k.size(),
			"%d waves, %d distinct, worst %.5f of a wave off whole across %.0f m" % [k.size(), seen.size(), worst, tile])
	_sections += 1


## Sampled over the tile: the painted slope's variance, both directions together, plus the share left unpainted and the
## swell's own slope variance sampled over its tile the same way.
func _the_painted_slope_is_a_real_seas_slope() -> void:
	var standing: Dictionary = Sim.swell_shape()
	for wind in WINDS:
		var handed: Dictionary = _handed(wind)
		var k: PackedVector2Array = handed["wind_sea_k"]
		var heights: PackedFloat32Array = handed["wind_sea_height"]
		var tile: float = float(handed["wind_sea_tile"])
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var painted: float = _sampled_slope_variance(k, heights, tile, rng)
		var swell: float = 0.0
		if not standing.is_empty():
			# THE SWELL AND THE WIND-SEA THE BOATS FEEL (C1): every standing wave the simulation hands the sea, each as
			# (x, z, height) for the wind-sea.
			var swell_k := PackedVector2Array([standing["first"], standing["second"]])
			var swell_heights := PackedFloat32Array([float(standing["height"]), float(standing["second_height"])])
			for wave in (standing.get("wind_waves", []) as Array):
				swell_k.append(Vector2((wave as Vector3).x, (wave as Vector3).y))
				swell_heights.append((wave as Vector3).z)
			swell = _sampled_slope_variance(swell_k, swell_heights, float(standing["tile"]), rng)
		var total: float = painted + float(handed["wind_sea_unpainted"]) + swell
		var cox_munk: float = 0.003 + 0.00512 * wind
		_check("the_sea_carries_cox_and_munks_slope_at_%.1f_mps" % wind, absf(total / cox_munk - 1.0) < 0.03,
			"painted %.4f + unpainted %.4f + swell %.5f = %.4f against %.4f" % [painted,
				float(handed["wind_sea_unpainted"]), swell, total, cox_munk])
	_sections += 1


func _sampled_slope_variance(k: PackedVector2Array, heights: PackedFloat32Array, tile: float,
		rng: RandomNumberGenerator) -> float:
	var sum := Vector2.ZERO
	var square: float = 0.0
	for s in range(SAMPLES):
		var p := Vector2(rng.randf() * tile, rng.randf() * tile)
		var slope := Vector2.ZERO
		for i in range(k.size()):
			slope += k[i] * cos(p.dot(k[i])) * heights[i]
		sum += slope
		square += slope.length_squared()
	var mean: Vector2 = sum / float(SAMPLES)
	return square / float(SAMPLES) - mean.length_squared()


## THE SHADER'S WRAP, `p - tile * floor(p / tile)`, against the unwrapped position, in double-precision GDScript: across
## both axes, the tile's edge, and far out.
func _the_wrap_leaves_no_seam() -> void:
	var handed: Dictionary = _handed(8.5)
	var k: PackedVector2Array = handed["wind_sea_k"]
	var heights: PackedFloat32Array = handed["wind_sea_height"]
	var tile: float = float(handed["wind_sea_tile"])
	# A SEAM IS A STEP THE WRAP ADDS, not the sea's own rise across the centimetre: the wind-sea is steep on purpose, and a
	# millimetre-in-a-centimetre bound copied from the swell's check (whose slope is 1.5 degrees) read its own slope, 5.4 mm,
	# as a seam. So each pair straddling a line is stepped wrapped and unwrapped, and the two steps must agree.
	var added: float = 0.0
	var apart: float = 0.0
	var rise: float = 0.0
	for line in [0.0, tile, -tile, 30000.0]:
		for along in range(-40, 41):
			for across_x in [true, false]:
				var a := Vector2(line - 0.005, float(along) * 37.0) if across_x else Vector2(float(along) * 37.0, line - 0.005)
				var b := a + (Vector2(0.01, 0.0) if across_x else Vector2(0.0, 0.01))
				var unwrapped_a: float = _height(a, k, heights)
				var unwrapped_b: float = _height(b, k, heights)
				var wrapped_a: float = _height(Vector2(a.x - tile * floor(a.x / tile), a.y - tile * floor(a.y / tile)), k, heights)
				var wrapped_b: float = _height(Vector2(b.x - tile * floor(b.x / tile), b.y - tile * floor(b.y / tile)), k, heights)
				apart = maxf(apart, maxf(absf(unwrapped_a - wrapped_a), absf(unwrapped_b - wrapped_b)))
				added = maxf(added, absf((wrapped_b - wrapped_a) - (unwrapped_b - unwrapped_a)))
				rise = maxf(rise, absf(unwrapped_a))
	_check("the_wrapped_sea_is_the_unwrapped_sea_on_both_sides_of_every_seam", apart < 0.0001 and rise > 0.01,
		"%.6f m apart at worst, heights reach %.3f m" % [apart, rise])
	_check("and_the_wrap_adds_no_step_across_a_seam", added < 0.00001, "%.7f m added at worst" % added)
	_sections += 1


func _height(p: Vector2, k: PackedVector2Array, heights: PackedFloat32Array) -> float:
	var h: float = 0.0
	for i in range(k.size()):
		h += sin(p.dot(k[i])) * heights[i]
	return h


func _each_wave_moves_at_deep_waters_speed() -> void:
	var handed: Dictionary = _handed(8.5)
	var k: PackedVector2Array = handed["wind_sea_k"]
	var speeds: PackedFloat32Array = handed["wind_sea_speed"]
	var worst: float = 0.0
	var longest: float = 0.0
	var shortest: float = 1.0e9
	for i in range(k.size()):
		var wavelength: float = TAU / k[i].length()
		longest = maxf(longest, wavelength)
		shortest = minf(shortest, wavelength)
		worst = maxf(worst, absf((speeds[i] / k[i].length()) / (1.249 * sqrt(wavelength)) - 1.0))
	_check("each_wave_moves_at_deep_waters_speed_for_its_length", k.size() > 0 and worst < 0.01,
		"worst %.2f %% off, %.1f m to %.2f m" % [worst * 100.0, longest, shortest])
	_sections += 1


## THE RIPPLE MAPS, as a material is handed them: both are mipmapped textures; each wraps with no seam, its step across the
## wrap no larger than its steps inside; the slope variance handed is the image's own, read back off the texture at a
## different stride than the one that measured it; and the tiles do not divide into each other, so their repeats never
## line up.
func _the_ripple_maps_are_seamless_mipmapped_and_measured() -> void:
	var wet := ShaderMaterial.new()
	WindSea.hand(wet, 8.5)
	var tiles: Variant = wet.get_shader_parameter("ripple_map_tile")
	var variances: Variant = wet.get_shader_parameter("ripple_map_variance")
	var names: PackedStringArray = ["ripple_map_long", "ripple_map_short"]
	for i in range(names.size()):
		var texture := wet.get_shader_parameter(names[i]) as Texture2D
		var image: Image = texture.get_image() if texture != null else null
		_check("the_%s_is_a_mipmapped_texture" % names[i], image != null and image.has_mipmaps() and image.get_width() >= 256,
			"%s" % ["none" if image == null else "%dx%d, %d mipmaps" % [image.get_width(), image.get_height(),
				image.get_mipmap_count()]])
		if image == null:
			continue
		var size: int = image.get_width()
		var across_wrap: float = 0.0
		var inside: float = 0.0
		for j in range(0, size, 3):
			across_wrap = maxf(across_wrap, _normal_step(image.get_pixel(size - 1, j), image.get_pixel(0, j)))
			across_wrap = maxf(across_wrap, _normal_step(image.get_pixel(j, size - 1), image.get_pixel(j, 0)))
			var k: int = (j * 7 + 11) % (size - 1)
			inside = maxf(inside, _normal_step(image.get_pixel(k, j), image.get_pixel(k + 1, j)))
			inside = maxf(inside, _normal_step(image.get_pixel(j, k), image.get_pixel(j, k + 1)))
		_check("and_the_%s_wraps_with_no_seam" % names[i], inside > 0.0 and across_wrap <= inside * 1.25,
			"worst step across the wrap %.4f, inside %.4f" % [across_wrap, inside])
		var sum := Vector2.ZERO
		var square: float = 0.0
		var count: int = 0
		for y in range(3, size, 5):
			for x in range(2, size, 5):
				var c: Color = image.get_pixel(x, y)
				var n := Vector3(c.r * 2.0 - 1.0, c.g * 2.0 - 1.0, c.b * 2.0 - 1.0)
				var slope := Vector2(-n.x, n.y) / maxf(n.z, 0.2)
				sum += slope
				square += slope.length_squared()
				count += 1
		var measured: float = square / float(count) - (sum / float(count)).length_squared()
		var handed: float = (variances as Vector2)[i] if variances is Vector2 else 0.0
		_check("and_the_%s_is_handed_its_own_slope_variance" % names[i], measured > 0.0 and absf(handed / measured - 1.0) < 0.05,
			"handed %.5f, read back %.5f" % [handed, measured])
	var t: Vector3 = tiles if tiles is Vector3 else Vector3.ZERO
	var worst: float = 1.0
	for pair in [[t.x, t.y], [t.x, t.z], [t.z, t.y]]:
		var ratio: float = maxf(pair[0], pair[1]) / maxf(minf(pair[0], pair[1]), 0.001)
		worst = minf(worst, absf(ratio - roundf(ratio)))
	_check("and_no_two_tiles_divide_into_each_other", t.y > 0.0 and worst > 0.1,
		"tiles %.2f, %.2f, %.2f m, nearest a whole ratio by %.3f" % [t.x, t.y, t.z, worst])
	_sections += 1


func _normal_step(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g)


## The breaking waves' curvature sampled at random points and times; the share past the handed threshold.
func _whitecaps_cover_what_the_wind_says() -> void:
	for wind in WINDS:
		var handed: Dictionary = _handed(wind)
		var k: PackedVector2Array = handed["wind_sea_k"]
		var heights: PackedFloat32Array = handed["wind_sea_height"]
		var speeds: PackedFloat32Array = handed["wind_sea_speed"]
		var tile: float = float(handed["wind_sea_tile"])
		var longer: float = float(handed["whitecap_longer_than"])
		var threshold: float = float(handed["whitecap_curvature"])
		var rng := RandomNumberGenerator.new()
		rng.seed = 23
		var past: int = 0
		for s in range(SAMPLES):
			var p := Vector2(rng.randf() * tile, rng.randf() * tile)
			var t: float = rng.randf() * 600.0
			var curvature: float = 0.0
			for i in range(k.size()):
				if TAU / k[i].length() > longer:
					curvature += k[i].length_squared() * heights[i] * sin(p.dot(k[i]) - speeds[i] * t)
			if curvature > threshold:
				past += 1
		var share: float = float(past) / float(SAMPLES)
		var monahan: float = 3.84e-6 * pow(wind, 3.41)
		_check("whitecaps_cover_what_monahan_measured_at_%.1f_mps" % wind, absf(share / monahan - 1.0) < 0.34,
			"%.3f %% of the sea past %.3f, against %.3f %%" % [share * 100.0, threshold, monahan * 100.0])
	_sections += 1
