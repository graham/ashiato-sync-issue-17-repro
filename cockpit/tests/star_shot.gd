extends Node
## THE STARS, LOOKED AT: how many there are at night and by day, how wide the brightest are drawn, and whether each keeps
## its light as the head turns -- on both finishes, windowed.
##
##   Godot --path cockpit --resolution 1600x900 res://tests/star_shot.tscn -- --level=watch --clouds=none --out=C:/somewhere
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device. That the stars are asked for at night and not by
## day -- the number `Daylight` writes -- is held headless by tests/scenery.gd. This asks the picture:
##
## - AT NIGHT THERE ARE STARS: at least `STARS_LEAST` bright points in the high sky, away from the moon.
## - BY DAY AND AT EVENING THERE ARE NONE, from the same pose.
## - NONE IS NARROWER THAN A PIXEL: the `WIDTH_STARS` brightest, each measured by the spread of its light over a 7 x 7 box,
##   have a sigma of at least `SIGMA_LEAST` pixels.
## - NONE TWINKLES AS THE HEAD TURNS: the camera turns `DRIFT_PX` a frame for `DRIFT_FRAMES` frames, each of the `TRACK_STARS`
##   brightest is followed -- its direction read off the first frame and projected afresh each frame, so the box moves with it
##   exactly -- and the light in its box, less the sky, is held to a coefficient of variation under `SHIMMER_MOST` at the
##   median star.
##
## Pictures in `--out`: `stars-<finish>-<time>.png`, and `stars-<finish>-night-crop.png`, a 200 x 120 crop at 1:1 round the
## brightest star, with `-x4` blown up with no filtering.
##
## Prints RESULT=PASS, or RESULT=FAIL and the checks that failed.

const ELEVATION: float = 60.0
## Looking away from the moon: its azimuth plus this.
const AWAY_FROM_MOON: float = 180.0
const FOV: float = 60.0
const SETTLE: int = 8
## A STAR is a pixel brighter than its eight neighbours and this much brighter than the ring of pixels three away round it:
## a point, not an edge. Against the frame's median, the first run found 217 "stars" in PLAIN's day sky and 527 in FINE's --
## the sun's glow and the cirrus.
const OVER_RING: float = 0.04
const STARS_LEAST: int = 150
const WIDTH_STARS: int = 20
const SIGMA_LEAST: float = 0.6
const TRACK_STARS: int = 30
const DRIFT_PX: float = 0.25
const DRIFT_FRAMES: int = 60
const SHIMMER_MOST: float = 0.08
## How far inside the picture a followed star must start, pixels.
const EDGE_PX: int = 40

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://star_shot"
var _from: Vector3 = Vector3.ZERO
var _toward: Vector3 = Vector3.FORWARD
var _placing: bool = false


func _check(label: String, ok: bool, detail: String) -> void:
	print("[stars] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_viewport().scaling_3d_scale = PilotRig.RENDER_SCALE
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	for i in range(30):
		await get_tree().process_frame
	for node_name in ["Vehicles", "Lift", "Clouds", "Contrails"]:
		var node := _level.get_node_or_null(node_name) as Node3D
		if node != null:
			node.visible = false
	var words := _level.get_node_or_null("Ui") as CanvasLayer
	if words != null:
		words.visible = false
	# AND THE OBSERVER'S OWN BOARD, which it draws on a CanvasLayer of its own: its letters are bright points on a dark sky,
	# and the first run counted them as 93 stars that never moved as the camera turned.
	for child in _level.observer.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	var night: Dictionary = DaylightTuning.NIGHT
	var azimuth: float = deg_to_rad(float(night["sun_azimuth"]) + AWAY_FROM_MOON)
	var up: float = deg_to_rad(ELEVATION)
	_from = Terrain.RUNWAY_AT + Vector3.UP * 300.0
	var look := Vector3(cos(up) * sin(azimuth), sin(up), cos(up) * cos(azimuth))
	_toward = _from + look * 1000.0
	_placing = true
	var finish: Node = get_node("/root/Finish")
	for fine in [false, true]:
		finish.call("choose", fine)
		await _frames(SETTLE)
		await _look_at_the_stars("fine" if fine else "plain", look)
	_finish()


func _process(_delta: float) -> void:
	if not _placing or _level == null or _level.observer == null:
		return
	var eye: Camera3D = _level.observer
	eye.fov = FOV
	if eye.has_method("look_from"):
		eye.call("look_from", _from, _toward)
	else:
		eye.global_position = _from
		eye.look_at(_toward, Vector3.UP)


func _look_at_the_stars(finish_name: String, look: Vector3) -> void:
	var counts: Dictionary = {}
	for time in [DaylightTuning.When.DAY, DaylightTuning.When.EVENING, DaylightTuning.When.NIGHT]:
		_level.choose_time(time)
		_toward = _from + look * 1000.0
		var picture: Image = await _picture()
		var found: Array = _stars_in(picture)
		counts[time] = found.size()
		_save(picture, "stars-%s-%s" % [finish_name, DaylightTuning.name_of(time).to_lower()])
		if time != DaylightTuning.When.NIGHT:
			continue
		_check("%s_at_night_there_are_stars" % finish_name, found.size() >= STARS_LEAST,
			"%d stars in the high sky (wanted at least %d)" % [found.size(), STARS_LEAST])
		# THE BRIGHTEST, BY WIDTH.
		var narrow: Array[String] = []
		var sigmas: PackedFloat32Array = []
		for star in found.slice(0, WIDTH_STARS):
			var sigma: float = _spread(picture, star["at"])
			sigmas.append(sigma)
			if sigma < SIGMA_LEAST:
				narrow.append("%s at %.2f px" % [star["at"], sigma])
		_check("%s_no_bright_star_is_narrower_than_a_pixel" % finish_name, narrow.is_empty() and not sigmas.is_empty(),
			"sigmas of the %d brightest: %s%s" % [sigmas.size(), _rounded(sigmas), "" if narrow.is_empty() else "; narrow: " + ", ".join(narrow)])
		if not found.is_empty():
			var brightest: Vector2i = found[0]["at"]
			var crop: Image = picture.get_region(Rect2i(brightest - Vector2i(100, 60), Vector2i(200, 120)))
			_save(crop, "stars-%s-night-crop" % finish_name)
			var blown: Image = crop.duplicate() as Image
			blown.resize(800, 480, Image.INTERPOLATE_NEAREST)
			_save(blown, "stars-%s-night-crop-x4" % finish_name)
		await _measure_the_shimmer(finish_name, _away_from_the_edges(picture, found).slice(0, TRACK_STARS), look)
	_check("%s_by_day_and_at_evening_there_are_none" % finish_name,
		counts[DaylightTuning.When.DAY] == 0 and counts[DaylightTuning.When.EVENING] == 0,
		"%d by day, %d at evening, %d at night" % [counts[DaylightTuning.When.DAY], counts[DaylightTuning.When.EVENING],
			counts[DaylightTuning.When.NIGHT]])


## THE HEAD TURNS: each star followed by its own direction, and the light in its box held steady. The check says how far the
## stars moved on screen and how many frames each series holds, so a turn that never happened, or a series that stayed
## empty, cannot pass as steady: the first version appended each frame's light to a COPY of a PackedFloat32Array taken out
## of an untyped Array, every series stayed empty, and every star read a variation of exactly 0.000.
func _measure_the_shimmer(finish_name: String, tracked: Array, look: Vector3) -> void:
	var eye: Camera3D = _level.observer
	var directions: Array[Vector3] = []
	for star in tracked:
		directions.append(eye.project_ray_normal(Vector2(star["at"]) + Vector2(0.5, 0.5)))
	# TURNED ABOUT THE CAMERA'S OWN UP, so a star in the middle of the view crosses DRIFT_PX a frame. About the world's up, with
	# the camera pitched 60 degrees, the first version moved the brightest star 37.7 px in 60 frames against 14.8 asked.
	var turn_axis: Vector3 = eye.global_basis.y.normalized()
	var pixel: float = deg_to_rad(FOV) / float(get_viewport().get_visible_rect().size.y)
	var lights: Array[Array] = []
	for i in range(tracked.size()):
		lights.append([])
	var first_at: Array[Vector2] = []
	var last_at: Array[Vector2] = []
	for frame in range(DRIFT_FRAMES):
		_toward = _from + look.rotated(turn_axis, pixel * DRIFT_PX * float(frame)) * 1000.0
		var picture: Image = await _picture(1)
		var sky: float = _sky_level(picture)
		last_at.clear()
		for i in range(tracked.size()):
			var at: Vector2 = eye.unproject_position(_from + directions[i] * 1000.0)
			last_at.append(at)
			lights[i].append(_box_light(picture, at, sky))
		if frame == 0:
			first_at = last_at.duplicate()
	var variations: PackedFloat32Array = []
	var means: PackedFloat32Array = []
	var frames_read: int = DRIFT_FRAMES
	for series in lights:
		variations.append(_variation(series))
		means.append(_mean(series))
		frames_read = mini(frames_read, series.size())
	var moved: float = first_at[0].distance_to(last_at[0]) if not first_at.is_empty() and not last_at.is_empty() else 0.0
	var sorted: PackedFloat32Array = variations.duplicate()
	sorted.sort()
	var median: float = sorted[sorted.size() / 2] if not sorted.is_empty() else INF
	var worst: float = sorted[sorted.size() - 1] if not sorted.is_empty() else INF
	var mean_sorted: PackedFloat32Array = means.duplicate()
	mean_sorted.sort()
	var wanted_move: float = DRIFT_PX * float(DRIFT_FRAMES - 1)
	_check("%s_no_star_twinkles_as_the_head_turns" % finish_name,
		median <= SHIMMER_MOST and frames_read == DRIFT_FRAMES and moved >= wanted_move * 0.5 and moved <= wanted_move * 2.0
			and (mean_sorted[0] if not mean_sorted.is_empty() else 0.0) > 0.0,
		"the brightest star moved %.1f px over %d frames (wanted %.1f, off-centre half to twice), each series %d frames, the dimmest box's mean light %.3f; the light in each of %d stars' boxes varies by %.3f at the median and %.3f at the worst (wanted at most %.3f)" % [
			moved, DRIFT_FRAMES, wanted_move, frames_read, mean_sorted[0] if not mean_sorted.is_empty() else 0.0,
			tracked.size(), median, worst, SHIMMER_MOST])


## The stars at least `EDGE_PX` inside the picture, so none drifts out of it while it is followed.
func _away_from_the_edges(picture: Image, found: Array) -> Array:
	var inside: Array = []
	for star in found:
		var at: Vector2i = star["at"]
		if at.x >= EDGE_PX and at.y >= EDGE_PX and at.x < picture.get_width() - EDGE_PX and at.y < picture.get_height() - EDGE_PX:
			inside.append(star)
	return inside


## Every star in the picture, brightest first: [{at, light}], light above its ring.
func _stars_in(picture: Image) -> Array:
	var found: Array = []
	# NOT UNDER THE BUILD STAMP in the lower right (`BuildStamp`, 2026-09-18): it is in every picture on purpose, and its
	# letters are drawn over whatever is behind them, so they would count as stars: bright points on a dark sky.
	var stamp: Rect2i = BuildStamp.pixels().grow(3)
	for y in range(3, picture.get_height() - 3):
		for x in range(3, picture.get_width() - 3):
			if stamp.has_point(Vector2i(x, y)):
				continue
			var l: float = _luminance(picture.get_pixel(x, y))
			# A QUICK NO: the four ring pixels straight out, where most of the sky fails.
			var above_ring: float = minf(minf(l - _luminance(picture.get_pixel(x + 3, y)), l - _luminance(picture.get_pixel(x - 3, y))),
				minf(l - _luminance(picture.get_pixel(x, y + 3)), l - _luminance(picture.get_pixel(x, y - 3))))
			if above_ring < OVER_RING:
				continue
			var peak: bool = true
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if (dx != 0 or dy != 0) and _luminance(picture.get_pixel(x + dx, y + dy)) >= l:
						peak = false
			if not peak:
				continue
			var ring: float = 0.0
			for i in range(-3, 3):
				ring += _luminance(picture.get_pixel(x + i, y - 3)) + _luminance(picture.get_pixel(x + 3, y + i))
				ring += _luminance(picture.get_pixel(x - i, y + 3)) + _luminance(picture.get_pixel(x - 3, y - i))
			ring /= 24.0
			if l - ring >= OVER_RING:
				found.append({"at": Vector2i(x, y), "light": l - ring})
	found.sort_custom(func(a: Dictionary, b: Dictionary): return float(a["light"]) > float(b["light"]))
	return found


## The sky's level: the median luminance of a sparse sample of the picture.
func _sky_level(picture: Image) -> float:
	var samples: PackedFloat32Array = []
	var stamp: Rect2i = BuildStamp.pixels()
	for y in range(0, picture.get_height(), 17):
		for x in range(0, picture.get_width(), 17):
			if not stamp.has_point(Vector2i(x, y)):
				samples.append(_luminance(picture.get_pixel(x, y)))
	samples.sort()
	return samples[samples.size() / 2]


## How widely a star's light spreads, as a sigma in pixels, from its second moment over a 7 x 7 box less the sky.
func _spread(picture: Image, at: Vector2i) -> float:
	var sky: float = _sky_level(picture)
	var total: float = 0.0
	var moment: float = 0.0
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var p := at + Vector2i(dx, dy)
			if p.x < 0 or p.y < 0 or p.x >= picture.get_width() or p.y >= picture.get_height():
				continue
			var l: float = maxf(_luminance(picture.get_pixelv(p)) - sky, 0.0)
			total += l
			moment += l * float(dx * dx + dy * dy)
	return sqrt(moment / maxf(total, 0.0001) * 0.5)


func _box_light(picture: Image, at: Vector2, sky: float) -> float:
	var total: float = 0.0
	var centre := Vector2i(at.floor())
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var p := centre + Vector2i(dx, dy)
			if p.x < 0 or p.y < 0 or p.x >= picture.get_width() or p.y >= picture.get_height():
				continue
			total += maxf(_luminance(picture.get_pixelv(p)) - sky, 0.0)
	return total


static func _mean(series: Array) -> float:
	var total: float = 0.0
	for v in series:
		total += float(v)
	return total / float(maxi(series.size(), 1))


## The coefficient of variation of a series: its standard deviation over its mean. INF for an empty series or a zero mean.
static func _variation(series: Array) -> float:
	if series.is_empty():
		return INF
	var mean: float = _mean(series)
	if mean <= 0.0:
		return INF
	var spread: float = 0.0
	for v in series:
		spread += (float(v) - mean) * (float(v) - mean)
	return sqrt(spread / float(series.size())) / mean


static func _rounded(values: PackedFloat32Array) -> String:
	var parts: PackedStringArray = []
	for v in values:
		parts.append("%.2f" % v)
	return ", ".join(parts)


static func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func _picture(frames: int = SETTLE) -> Image:
	await _frames(frames)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _save(picture: Image, name: String) -> void:
	var path: String = _out.path_join(name + ".png")
	_check("saved_%s" % name, picture.save_png(path) == OK, path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	_placing = false
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
