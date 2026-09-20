extends Node
## THE MOON, LOOKED AT: where the sky draws it, which side of it is lit, whether it is gone by day, and pictures of it close
## and at a headset's scale, on both finishes.
##
##   Godot --path cockpit --resolution 1600x900 res://tests/moon_shot.tscn -- --level=watch --out=C:/somewhere
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (seeing_the_game.md). What headless can hold -- the
## moon's brightness and the true sun reaching both skies through the time of day -- tests/scenery.gd holds. This asks the
## drawn picture the questions only a picture answers:
##
## - THE MOON IS WHERE THE LIGHT COMES FROM. At NIGHT the camera looks a little off the level's own DirectionalLight3D,
##   zoomed to `CLOSE_FOV`, with the true sun put behind the eye for a full disc. The bright disc's centroid is held to where
##   the light's direction projects, within `CENTRE_PX`, and its width to the drawn diameter, within `WIDTH_SHARE`. Then the
##   light itself is turned `TURN_DEGREES` round the vertical and the disc asked again: a moon drawn along a direction of its
##   own -- even night's own -- stays behind.
## - THE LIT SIDE FACES THE SUN. The true sun a quarter turn to the moon's right, then to its left, then as a crescent, and at
##   the preset's own: the lit pixels' centroid stands off the disc's centre towards where the sun's direction projects,
##   by at least `LIT_OFFSET_SHARE` of the radius.
## - IT IS TWICE THE SIZE IT WAS (2026-09-17, "make the moon twice as large at night"). The lit disc's width in pixels, over
##   the pixels a degree spans where it stands (from the camera's own projection, not from NightSkyTuning), is held to
##   twice the 0.78 degrees it was drawn until then, within `TWICE_SHARE`. The old moon measured 157 px here, 0.785 degrees.
## - BY DAY THERE IS NO MOON where night's was.
## - ON FINE, THE CIRRUS COVERS IT. Night's cirrus is too faint and too sparse to be found in front of the moon from any pose
##   (a row of `scenery_shot`'s `moon_at_<metres>` found none), so the sheet's cover is painted to `CIRRUS_FULL`, the eye is
##   carried across the streaks, and the deepest the lit disc's mean luminance falls against no cirrus at all is held to at
##   most `CIRRUS_DIMS`. A moon drawn over the half-resolution pass instead of under it keeps its brightness everywhere.
##   Painted cover alone was not enough: the sheet still breaks along its length over kilometres, and the first version,
##   from one pose, read 100 per cent with the moon correctly under it.
##
## - A PUFF CLOUD IN FRONT HIDES IT. The level's own puffs, shown again for this one look: the eye is put below the cloud with
##   the most puffs, looking through the most of it (`_behind_a_cloud`), and the disc's mean luminance with the puffs
##   drawn is held to at most `CLOUD_DIMS` of what it is with them hidden. Needs the puffs: not under `--clouds=none`.
##
## THE SUN IS PAINTED ONTO THE SKY MATERIAL for the phases no time of day has, and the preset's is put back after; the light is
## turned through its node, which is what the sky reads. The rest of the sky is left to the level; vehicles, the lift yard and
## the clouds are hidden for every look but the cloud's, so nothing but the sky is in front of the moon.
##
## Pictures in `--out`: `moon-<finish>-close-<phase>.png` at `CLOSE_FOV`, and `moon-<finish>-headset.png` with
## `moon-<finish>-headset-x8.png`, a crop round the moon drawn at the headset's pixels a degree (`tests/builder.gd`'s
## HEADSET_PIXELS_PER_DEGREE), at 1:1 and blown up eight times with no filtering.
##
## Prints RESULT=PASS, or RESULT=FAIL and the checks that failed.

## The camera's vertical field of view looking closely at the moon, degrees: about 200 pixels a degree on a 900-pixel window.
const CLOSE_FOV: float = 4.5
## How far off the moon the close camera looks, degrees right and up, so a moon drawn at the middle of the view is caught.
const OFF_RIGHT: float = 0.9
const OFF_UP: float = 0.5
## How far the disc's centroid may be from where the light projects, pixels, and its width from the drawn diameter, as a share.
const CENTRE_PX: float = 3.0
const WIDTH_SHARE: float = 0.06
## How far the light is turned for the second look.
const TURN_DEGREES: float = 3.0
## A pixel brighter than this (0..1, as saved) is the moon's lit face; the night sky round it is under 0.1.
const LIT_LUMINANCE: float = 0.25
## How far towards the sun the lit centroid must stand, as a share of the disc's radius. A 93 per cent gibbous moon's stands
## about a tenth of the radius off; a quarter's about four tenths.
const LIT_OFFSET_SHARE: float = 0.04
## Frames after a change before a picture: the radiance cubemap and the half-resolution pass settle in one or two.
const SETTLE: int = 8
const OVER_THE_RUNWAY: float = 300.0
## The cirrus cover painted for the cirrus look, and the share of its clear-sky mean luminance the covered disc may keep.
const CIRRUS_FULL: float = 1.0
const CIRRUS_DIMS: float = 0.85
## How far the eye is carried across the streaks between cirrus looks, metres, and how many looks.
const CIRRUS_STEP: float = 1500.0
const CIRRUS_STEPS: int = 8
## THE SIZE THE MOON WAS DRAWN UNTIL 2026-09-17, degrees across, written here and not asked of NightSkyTuning, and how far the
## measured width may be from twice it, as a share. A pixel either way at the close view's 200 px a degree is 0.3 per cent.
const DIAMETER_UNTIL_2026_09_17: float = 0.78
const TWICE_SHARE: float = 0.03
## The cloud look: how far back along the moonlight from a puff the eye stands, metres, the field of view, and the share of
## its clear luminance the disc may keep behind the cloud.
const CLOUD_BACK: float = 1500.0
const CLOUD_FOV: float = 30.0
const CLOUD_DIMS: float = 0.5

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://moon_shot"
var _from: Vector3 = Vector3.ZERO
var _toward: Vector3 = Vector3.FORWARD
var _fov: float = 70.0
var _placing: bool = false


func _check(label: String, ok: bool, detail: String) -> void:
	print("[moon] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
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
	print("[moon] %s, %s precision, %s on %s, window %s, 3D scale %.2f" % [Engine.get_version_info()["string"],
		"double" if OS.has_feature("double") else "single", RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(), DisplayServer.window_get_size(), get_viewport().scaling_3d_scale])
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
	for node_name in ["Vehicles", "Lift", "Clouds", "Contrails", "Puffs"]:
		var node := _level.get_node_or_null(node_name) as Node3D
		if node != null:
			node.visible = false
	var words := _level.get_node_or_null("Ui") as CanvasLayer
	if words != null:
		words.visible = false
	_placing = true
	var finish: Node = get_node("/root/Finish")
	for fine in [false, true]:
		finish.call("choose", fine)
		await _frames(SETTLE)
		await _look_at_the_moon("fine" if fine else "plain")
	_finish()


func _process(_delta: float) -> void:
	if not _placing or _level == null or _level.observer == null:
		return
	var eye: Camera3D = _level.observer
	eye.fov = _fov
	if eye.has_method("look_from"):
		eye.call("look_from", _from, _toward)
	else:
		eye.global_position = _from
		eye.look_at(_toward, Vector3.UP)


func _look_at_the_moon(finish_name: String) -> void:
	_level.choose_time(DaylightTuning.When.NIGHT)
	var light := _level.get_node("DirectionalLight3D") as DirectionalLight3D
	var air: Environment = (_level.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky := air.sky.sky_material as ShaderMaterial
	var worn_right: bool = sky == (_level.daylight.fine_sky if finish_name == "fine" else _level.daylight.plain_sky)
	_check("%s_wears_its_own_sky" % finish_name, worn_right, "%s" % sky)
	var preset_sun: Vector3 = sky.get_shader_parameter("true_sun")
	var night_basis: Basis = light.global_basis
	_from = Terrain.RUNWAY_AT + Vector3.UP * OVER_THE_RUNWAY

	# WHERE THE LIGHT COMES FROM, and where it comes from once turned.
	for turn in [0.0, TURN_DEGREES]:
		light.global_basis = Basis(Vector3.UP, deg_to_rad(turn)) * night_basis
		var moon: Vector3 = light.global_basis.z.normalized()
		sky.set_shader_parameter("true_sun", -moon)
		var picture: Image = await _shoot(moon, CLOSE_FOV, OFF_RIGHT, OFF_UP)
		var centre: Vector2 = _projected(moon)
		var radius: float = _projected_radius(moon)
		var disc: Dictionary = _lit_disc(picture, centre, radius)
		var off: float = (disc["centroid"] as Vector2).distance_to(centre) if int(disc["count"]) > 0 else INF
		var width: float = float(disc["width"])
		_check("%s_the_moon_is_drawn_where_the_light_comes_from_turned_%d_degrees" % [finish_name, int(turn)],
			off <= CENTRE_PX and absf(width - radius * 2.0) <= radius * 2.0 * WIDTH_SHARE,
			"%d lit px, centroid %s, the light projects to %s: %.2f px off; %.1f px wide against %.1f drawn" % [
				disc["count"], disc["centroid"], centre.round(), off, width, radius * 2.0])
		if turn == 0.0:
			_save(picture, "moon-%s-close-full" % finish_name)
			var per_degree_here: float = _projected((moon * cos(deg_to_rad(1.0))
				+ moon.cross(Vector3.UP).normalized() * sin(deg_to_rad(1.0)))).distance_to(centre)
			var measured: float = width / per_degree_here
			var wanted: float = DIAMETER_UNTIL_2026_09_17 * 2.0
			_check("%s_the_moon_is_twice_the_size_it_was" % finish_name, absf(measured - wanted) <= wanted * TWICE_SHARE,
				"%.1f lit px across at %.1f px a degree: %.3f degrees, wanted %.2f, twice the %.2f it was" % [
					width, per_degree_here, measured, wanted, DIAMETER_UNTIL_2026_09_17])
	light.global_basis = night_basis

	# THE LIT SIDE FACES THE SUN.
	var moon_now: Vector3 = light.global_basis.z.normalized()
	var right: Vector3 = moon_now.cross(Vector3.UP).normalized()
	var phases: Array = [["quarter-right", right], ["quarter-left", -right],
		["crescent", (moon_now * cos(deg_to_rad(40.0)) + right * sin(deg_to_rad(40.0))).normalized()],
		["gibbous", preset_sun]]
	for phase in phases:
		var sun: Vector3 = phase[1]
		sky.set_shader_parameter("true_sun", sun)
		var picture: Image = await _shoot(moon_now, CLOSE_FOV, OFF_RIGHT, OFF_UP)
		var centre: Vector2 = _projected(moon_now)
		var radius: float = _projected_radius(moon_now)
		var disc: Dictionary = _lit_disc(picture, centre, radius)
		var along: Vector3 = (sun - moon_now * sun.dot(moon_now)).normalized()
		var sun_way: Vector2 = (_projected((moon_now + along * 0.001).normalized()) - centre).normalized()
		var lit_off: float = ((disc["centroid"] as Vector2) - centre).dot(sun_way) if int(disc["count"]) > 0 else -INF
		_check("%s_the_%s_moon_is_lit_on_the_side_facing_the_sun" % [finish_name, phase[0]],
			lit_off >= radius * LIT_OFFSET_SHARE,
			"%d lit px; the lit centroid stands %.1f px towards the sun (wanted %.1f), the sun's way on screen %s" % [
				disc["count"], lit_off, radius * LIT_OFFSET_SHARE, sun_way.snappedf(0.01)])
		_save(picture, "moon-%s-close-%s" % [finish_name, phase[0]])
	sky.set_shader_parameter("true_sun", preset_sun)

	# ON FINE, UNDER THE CIRRUS. The sheet painted to full cover still breaks along its length over cells kilometres across,
	# so one pose can look through a gap: the eye is carried across the streaks `CIRRUS_STEP` at a time, and at each place the
	# disc is seen with the sheet's opacity at nothing and at its own. The deepest dimming found is held to `CIRRUS_DIMS`.
	if finish_name == "fine":
		var cover_was: Variant = sky.get_shader_parameter("cirrus_cover")
		var opacity_was: Variant = sky.get_shader_parameter("cirrus_opacity")
		var along_streaks: Vector2 = CloudTuning.CIRRUS_HEADING.normalized()
		var across_streaks := Vector3(-along_streaks.y, 0.0, along_streaks.x)
		var home: Vector3 = _from
		var deepest: float = INF
		var deepest_at: float = 0.0
		var readings: PackedStringArray = []
		var deepest_picture: Image = null
		sky.set_shader_parameter("cirrus_cover", CIRRUS_FULL)
		for step in range(CIRRUS_STEPS):
			_from = home + across_streaks * CIRRUS_STEP * float(step)
			sky.set_shader_parameter("cirrus_opacity", 0.0)
			var clear: Image = await _shoot(moon_now, CLOSE_FOV, OFF_RIGHT, OFF_UP)
			sky.set_shader_parameter("cirrus_opacity", opacity_was)
			var covered: Image = await _shoot(moon_now, CLOSE_FOV, OFF_RIGHT, OFF_UP)
			var centre: Vector2 = _projected(moon_now)
			var radius: float = _projected_radius(moon_now)
			var share: float = _mean_luminance(covered, centre, radius * 0.9) / maxf(_mean_luminance(clear, centre, radius * 0.9), 0.0001)
			readings.append("%.0f%%" % (100.0 * share))
			if share < deepest:
				deepest = share
				deepest_at = CIRRUS_STEP * float(step)
				deepest_picture = covered
		_from = home
		sky.set_shader_parameter("cirrus_cover", cover_was)
		sky.set_shader_parameter("cirrus_opacity", opacity_was)
		_check("fine_the_cirrus_covers_the_moon", deepest <= CIRRUS_DIMS,
			"the disc keeps %.0f%% of its clear-sky luminance under the sheet at cover %.1f, %.0f m across the streaks (wanted at most %.0f%%); every %.0f m: %s" % [
				100.0 * deepest, CIRRUS_FULL, deepest_at, 100.0 * CIRRUS_DIMS, CIRRUS_STEP, ", ".join(readings)])
		if deepest_picture != null:
			_save(deepest_picture, "moon-fine-close-behind-cirrus")

	# AT A HEADSET'S SCALE: the moon as many pixels across as a headset draws it.
	var per_degree: float = float(load("res://tests/builder.gd").get("HEADSET_PIXELS_PER_DEGREE"))
	var height: float = float(get_viewport().get_visible_rect().size.y)
	var headset: Image = await _shoot(moon_now, height / per_degree, 0.0, 0.0)
	var middle: Vector2 = _projected(moon_now)
	var across: float = _projected_radius(moon_now) * 2.0
	print("[moon] %s at %.0f px a degree: the moon is %.1f px across (%.2f degrees, %.1f times the real 0.52)" % [
		finish_name, per_degree, across, rad_to_deg(NightSkyTuning.moon_radius()) * 2.0, NightSkyTuning.MOON_ENLARGED])
	var crop: Image = headset.get_region(Rect2i(Vector2i(middle.round()) - Vector2i(24, 24), Vector2i(48, 48)))
	_save(crop, "moon-%s-headset" % finish_name)
	var blown: Image = crop.duplicate() as Image
	blown.resize(crop.get_width() * 8, crop.get_height() * 8, Image.INTERPOLATE_NEAREST)
	_save(blown, "moon-%s-headset-x8" % finish_name)

	# BEHIND A PUFF CLOUD.
	await _behind_a_cloud(finish_name, moon_now)

	# BY DAY: nothing where night's moon was.
	_level.choose_time(DaylightTuning.When.DAY)
	var by_day: Image = await _shoot(moon_now, CLOSE_FOV, OFF_RIGHT, OFF_UP)
	var day_centre: Vector2 = _projected(moon_now)
	var day_radius: float = _projected_radius(moon_now)
	var spread: float = _luminance_spread(by_day, day_centre, day_radius)
	_check("%s_by_day_there_is_no_moon_where_nights_was" % finish_name, spread < 0.03,
		"luminance across night's disc spreads %.3f by day" % spread)
	_save(by_day, "moon-%s-close-day" % finish_name)
	_level.choose_time(DaylightTuning.When.NIGHT)


## THE MOON BEHIND THE LEVEL'S BIGGEST PUFF CLOUD. A cloud's middle can be a gap between its puffs, and the first version, aimed
## there, looked through one (65 per cent kept). So every puff of the cloud is tried: the eye `CLOUD_BACK` metres back along
## the moonlight from its centre, in clear air and above the ground, and the one whose line to the moon crosses the most cloud
## by the puffs' own `optical_depth_between` is taken. The puffs hidden and then shown, and the disc's mean luminance held to
## `CLOUD_DIMS` of its clear one. The eye goes back where it was and the puffs are hidden again after.
func _behind_a_cloud(finish_name: String, moon: Vector3) -> void:
	var puffs := _level.get_node_or_null("Puffs") as PuffSky
	if puffs == null or puffs.clouds.is_empty():
		_check("%s_a_cloud_in_front_hides_the_moon" % finish_name, false, "no puff clouds: run without --clouds=none")
		return
	var biggest: Dictionary = puffs.clouds[0]
	for cloud in puffs.clouds:
		if (cloud["puffs"] as Array).size() > (biggest["puffs"] as Array).size():
			biggest = cloud
	var best: Vector3 = Vector3.INF
	var deepest: float = 0.0
	for puff in biggest["puffs"]:
		var eye: Vector3 = (puff["centre"] as Vector3) - moon * CLOUD_BACK
		if puffs.density_at(eye) > 0.0 or eye.y < PuffSky.ground_under(eye) + 50.0:
			continue
		var depth: float = puffs.optical_depth_between(eye, eye + moon * CLOUD_BACK * 2.0, 24)
		if depth > deepest:
			deepest = depth
			best = eye
	if best == Vector3.INF:
		_check("%s_a_cloud_in_front_hides_the_moon" % finish_name, false, "no clear place below the biggest cloud")
		return
	var home: Vector3 = _from
	_from = best
	puffs.visible = false
	var clear: Image = await _shoot(moon, CLOUD_FOV, 0.0, 0.0)
	puffs.visible = true
	var covered: Image = await _shoot(moon, CLOUD_FOV, 0.0, 0.0)
	puffs.visible = false
	var centre: Vector2 = _projected(moon)
	var radius: float = _projected_radius(moon)
	var lit: float = _mean_luminance(clear, centre, radius * 0.9)
	var share: float = _mean_luminance(covered, centre, radius * 0.9) / maxf(lit, 0.0001)
	_check("%s_a_cloud_in_front_hides_the_moon" % finish_name, lit > LIT_LUMINANCE and share <= CLOUD_DIMS,
		"through %.1f of optical depth of a %d-puff cloud from %.0f m up: the disc keeps %.0f%% of its clear luminance %.3f (wanted at most %.0f%%)" % [
			deepest, (biggest["puffs"] as Array).size(), _from.y, 100.0 * share, lit, 100.0 * CLOUD_DIMS])
	_save(clear, "moon-%s-cloud-clear" % finish_name)
	_save(covered, "moon-%s-cloud-in-front" % finish_name)
	_from = home


## Aim at `moon` turned `right` and `up` degrees off it, at `fov` degrees, and return the picture once it has settled.
func _shoot(moon: Vector3, fov: float, right_degrees: float, up_degrees: float) -> Image:
	var right: Vector3 = moon.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(moon).normalized()
	var aim: Vector3 = (moon + right * tan(deg_to_rad(right_degrees)) + up * tan(deg_to_rad(up_degrees))).normalized()
	_toward = _from + aim * 1000.0
	_fov = fov
	await _frames(SETTLE)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


## Where a direction from the eye lands on the screen.
func _projected(direction: Vector3) -> Vector2:
	return (_level.observer as Camera3D).unproject_position(_from + direction * 1000.0)


## How many pixels the moon's drawn radius spans on the screen, along `direction`.
func _projected_radius(direction: Vector3) -> float:
	var right: Vector3 = direction.cross(Vector3.UP).normalized()
	var r: float = NightSkyTuning.moon_radius()
	return _projected(direction * cos(r) + right * sin(r)).distance_to(_projected(direction))


## The pixels brighter than `LIT_LUMINANCE` in a box round `centre`: how many, their centroid, and how wide they run.
func _lit_disc(picture: Image, centre: Vector2, radius: float) -> Dictionary:
	var reach: int = int(ceil(radius * 1.6))
	var count: int = 0
	var sum := Vector2.ZERO
	var left: int = 1 << 30
	var right: int = -(1 << 30)
	for y in range(maxi(int(centre.y) - reach, 0), mini(int(centre.y) + reach, picture.get_height())):
		for x in range(maxi(int(centre.x) - reach, 0), mini(int(centre.x) + reach, picture.get_width())):
			if _luminance(picture.get_pixel(x, y)) > LIT_LUMINANCE:
				count += 1
				sum += Vector2(x + 0.5, y + 0.5)
				left = mini(left, x)
				right = maxi(right, x)
	return {"count": count, "centroid": sum / float(maxi(count, 1)), "width": float(right - left + 1) if count > 0 else 0.0}


## The mean luminance inside a circle round `centre`.
func _mean_luminance(picture: Image, centre: Vector2, radius: float) -> float:
	var sum: float = 0.0
	var count: int = 0
	var reach: int = int(radius)
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var at := Vector2i(int(centre.x) + x, int(centre.y) + y)
			if Vector2(x, y).length() > radius or at.x < 0 or at.y < 0 or at.x >= picture.get_width() or at.y >= picture.get_height():
				continue
			sum += _luminance(picture.get_pixelv(at))
			count += 1
	return sum / float(maxi(count, 1))


## How far apart the darkest and brightest pixels inside the disc's circle are.
func _luminance_spread(picture: Image, centre: Vector2, radius: float) -> float:
	var least: float = 1.0
	var most: float = 0.0
	var reach: int = int(radius)
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			if Vector2(x, y).length() > radius:
				continue
			var at := Vector2i(int(centre.x) + x, int(centre.y) + y)
			if at.x < 0 or at.y < 0 or at.x >= picture.get_width() or at.y >= picture.get_height():
				continue
			var l: float = _luminance(picture.get_pixelv(at))
			least = minf(least, l)
			most = maxf(most, l)
	return most - least


static func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func _save(picture: Image, name: String) -> void:
	var path: String = _out.path_join(name + ".png")
	_check("saved_%s" % name, picture.save_png(path) == OK, path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	_placing = false
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
