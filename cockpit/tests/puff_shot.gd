extends Node3D
## THE PUFF CLOUDS, AS A PERSON SEES THEM: each of the six kinds on its own, close to, flown into from behind an aeroplane,
## and a layered sky with an aeroplane in it for scale. A PROTOTYPE'S PICTURES (lane/clouds2, 2026-09-17), for the user to
## choose from: "show me images of those clouds so i can give you guidance".
##
##   tools\gate_run.ps1 -Probe puff_shot
##   tools\gate_run.ps1 -Probe puff_shot -Extra "--only=fly"      (one group: kinds, close, fly, sky)
##
## NOT HEADLESS: headless has no rendering device and the picture comes back black. tests/puff_sky.gd holds what can be
## asserted -- the bands, the ground, the eye inside a cloud -- and this renders what cannot: does it READ as a cloud.
##
## A SubViewport with its OWN World3D for each picture, as falcon_shot does, so no two stages share an environment. The
## ground is one flat plane at 0 and the sky the engine's procedural one: the clouds are the only thing on trial.
##
## Read RESULT=, not the exit code.

const SIZE := Vector2i(1600, 900)
## Where the sun is: the light's own rotation, and so the clouds' `towards_sun`.
const SUN_ROTATION := Vector3(-0.75, -2.3, 0.0)

var out := ""
var only := ""
var failures: PackedStringArray = []
var saved := 0
## `--puff-depth=tested` draws the cheaper shader, which reads no depth texture (see world/shaders/puff.gdshaderinc).
var cut_at_the_world := true
## `--tag=` names the pictures: cockpit-<tag>-NN-... (clouds2's were "clouds2", the default; clouds3 takes before and after).
var tag := "clouds2"
## `--finish=plain` wears PLAIN's one octave of noise (`PuffSky.wear(false)`); FINE by default, as clouds2 timed it.
var fine := true
## `--time-views=a,b` times only the named views, on the cut shader alone, so a short slot can time one case A/B/A.
var time_views: PackedStringArray = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
		if argument == "--puff-depth=tested":
			cut_at_the_world = false
		if argument.begins_with("--time-views="):
			time_views = argument.trim_prefix("--time-views=").split(",", false)
		if argument == "--finish=plain":
			fine = false
		if argument.begins_with("--tag="):
			tag = argument.trim_prefix("--tag=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)

	if _wanted("kinds"):
		await _kinds()
	if _wanted("close"):
		await _close()
	if _wanted("fly"):
		await _fly()
	if _wanted("sky"):
		await _sky()
	if _wanted("wall"):
		await _wall()
	if _wanted("look"):
		await _look_is_lit()
	# TIMING is never part of the default run: it wants a MEASUREMENT hold (tools\gate_run.ps1 -Perf).
	if only == "time":
		await _time()

	var ok := failures.is_empty() and saved > 0
	print("[puff_shot] %d pictures into %s" % [saved, out])
	print("[puff_shot] RESULT=%s" % ("PASS" if ok else "FAIL %s" % [failures]))
	get_tree().quit(0 if ok else 1)


func _wanted(group: String) -> bool:
	return only.is_empty() or only == group


## EACH KIND ON ITS OWN, stood at the origin, from where that kind is usually seen.
func _kinds() -> void:
	var cu := PuffCloud.lay_out("cumulus", Vector3.ZERO, 11)
	await _look("01-A-cumulus-from-800m", [cu], _level_with(cu, -800.0, 0.3), _middle(cu))
	var tcu := PuffCloud.lay_out("towering", Vector3.ZERO, 12)
	await _look("02-B-towering-cumulus-from-5km", [tcu], _level_with(tcu, -5000.0, 0.15), _middle(tcu) + Vector3(0, 300, 0))
	var fb := PuffCloud.lay_out("flat_based", Vector3.ZERO, 13)
	var under := Vector3(-500.0, fb["base"] - 300.0, -1900.0)
	await _look("03-C-flat-based-cumulus-from-under-its-base", [fb], under, _middle(fb))
	var sc := PuffCloud.lay_out("stratocumulus", Vector3.ZERO, 14)
	await _look("04-D-stratocumulus-sheet-from-below", [sc], Vector3(-2600.0, 1300.0, -2600.0),
		Vector3(0.0, sc["base"], 0.0))
	await _look("05-D-stratocumulus-sheet-from-above", [sc], Vector3(-3000.0, sc["base"] + 1400.0, -3000.0),
		Vector3(0.0, sc["base"], 0.0))
	var ac := PuffCloud.lay_out("altocumulus", Vector3.ZERO, 15)
	await _look("06-E-altocumulus-from-3km", [ac], Vector3(-2500.0, 3000.0, -2500.0), Vector3(0.0, ac["base"], 0.0))
	var ci := PuffCloud.lay_out("cirrus", Vector3.ZERO, 16)
	await _look("07-F-cirrus-from-2km", [ci], Vector3(-2500.0, 2000.0, -6000.0), Vector3(0.0, ci["base"], 0.0))


## CLOSE TO: a cumulus 300 m off its side, and under its base.
func _close() -> void:
	var cu := PuffCloud.lay_out("cumulus", Vector3.ZERO, 11)
	await _look("08-A-cumulus-close-300m", [cu], _level_with(cu, -(_reach(cu) + 300.0), 0.4), _middle(cu))
	var fb := PuffCloud.lay_out("flat_based", Vector3.ZERO, 13)
	await _look("09-C-flat-based-close-under-the-base", [fb], Vector3(-300.0, fb["base"] - 120.0, -900.0),
		_middle(fb) + Vector3(0, 0, 200))


## FLOWN INTO: an aeroplane on a straight line through the middle of a cumulus, the camera 28 m behind and 6 m over it,
## at six places along the line from well outside to the far side.
func _fly() -> void:
	var cu := PuffCloud.lay_out("flat_based", Vector3.ZERO, 13)
	var middle := _middle(cu)
	var along := Vector3(0.0, 0.0, 1.0)
	var places := [-1500.0, -800.0, -520.0, -380.0, -150.0, 250.0, 700.0, 1300.0]
	var n := 10
	for place in places:
		var craft_at: Vector3 = middle + along * float(place)
		var inside := PuffSky.densest_at([cu], craft_at)
		await _look("%02d-fly-into-C-%+dm-density-%.4f" % [n, int(place), inside], [cu],
			craft_at - along * 28.0 + Vector3(0, 6, 0), craft_at + along * 60.0, craft_at, along)
		n += 1


## A LAYERED SKY: the plan's every kind over 24 km, the eye between the cumulus tops and the stratocumulus, an aeroplane
## in front for scale; and the same sky from the ground.
func _sky() -> void:
	var sky := PuffSky.plan(7, 12000.0)
	var craft := Vector3(0.0, 1750.0, -9000.0)
	await _look("20-layered-sky-between-the-decks", sky, craft + Vector3(-18.0, 4.0, -26.0), craft + Vector3(400, 150, 1000),
		craft, Vector3(0, 0, 1))
	await _look("21-layered-sky-from-the-ground", sky, Vector3(0.0, 30.0, -9000.0), Vector3(1000.0, 1800.0, 0.0))
	await _look("22-layered-sky-climbing-through-the-stratocumulus", sky, Vector3(0.0, 2600.0, -6000.0),
		Vector3(2000.0, 2200.0, 3000.0))
	await _look("23-layered-sky-over-the-top-at-6km", sky, Vector3(0.0, 6000.0, -12000.0), Vector3(0.0, 1500.0, 2000.0))


## A WALL OF TOWERING CUMULUS OVER THE SEA, as the user's reference frames it (a film still of a flying boat low over a
## deep blue sea, heading for a wall of cumulus with bright sunlit crowns, blue-grey shaded flanks and dark flat bases):
## the eye low over the water, the Savoia small in frame ahead of it, the sun high behind the eye and to its right; and the
## same wall with the sun behind it, for the silver lining. clouds3, 2026-09-18.
const WALL_SUN_BEHIND_THE_EYE := Vector3(-0.7, -2.1, 0.0)
const WALL_SUN_BEHIND_THE_WALL := Vector3(-0.35, 0.3, 0.0)
const SEA_COLOUR := Color(0.03, 0.12, 0.32)


static func wall_sky() -> Array:
	var sky: Array = []
	var dice := RandomNumberGenerator.new()
	dice.seed = 31
	# THE TOWERS AS THE LEVEL GROUPS THEM (`PuffSky.wall`), three walls laid across the view, their seeds the ones the row of
	# sixteen before them had, so a before picture and an after one differ by the grouping and the shape alone. The row took
	# two draws a tower from `dice`, and the heaps in front are drawn after it: the walls draw from their own, and the row's
	# thirty-two draws are still taken, so every heap stands where it stood.
	var walls_dice := RandomNumberGenerator.new()
	walls_dice.seed = 32
	for i in range(32):
		dice.randf()
	for w in range(3):
		var seeds: Array = []
		for t in range(5):
			seeds.append(100 + w * 5 + t)
		sky.append_array(PuffSky.wall(Vector3(-8500.0 + w * 8000.0 + walls_dice.randf_range(-600, 600), 0.0,
			9500.0 + walls_dice.randf_range(-600, 1200)), seeds, Callable(), walls_dice.randf_range(-0.2, 0.2)))
	for i in range(12):
		sky.append(PuffCloud.lay_out("flat_based", Vector3(-11000.0 + i * 1900.0 + dice.randf_range(-500, 500), 0.0,
			7000.0 + dice.randf_range(-600, 600)), 200 + i))
	for i in range(6):
		sky.append(PuffCloud.lay_out("cumulus", Vector3(-6000.0 + i * 2500.0 + dice.randf_range(-700, 700), 0.0,
			4200.0 + dice.randf_range(-800, 800)), 300 + i))
	return sky


func _wall() -> void:
	var sky := wall_sky()
	var craft := Vector3(0.0, 70.0, 0.0)
	var heading := Vector3(0.15, 0.0, 1.0).normalized()
	await _look("30-wall-over-the-sea-sun-behind-the-eye", sky, craft + Vector3(3.0, 6.0, -45.0),
		craft + Vector3(0.0, 1200.0, 7000.0), craft, heading, {"sun": WALL_SUN_BEHIND_THE_EYE, "ground": SEA_COLOUR,
			"craft": "savoia", "fov": 50.0})
	await _look("31-wall-over-the-sea-sun-behind-the-wall", sky, craft + Vector3(3.0, 6.0, -45.0),
		craft + Vector3(0.0, 1200.0, 7000.0), craft, heading, {"sun": WALL_SUN_BEHIND_THE_WALL, "ground": SEA_COLOUR,
			"craft": "savoia", "fov": 50.0})
	await _look("32-wall-one-tower-close", sky, Vector3(-2000.0, 900.0, 3000.0), Vector3(-2600.0, 2300.0, 9000.0),
		Vector3.INF, Vector3.FORWARD, {"sun": WALL_SUN_BEHIND_THE_EYE, "ground": SEA_COLOUR, "fov": 50.0})
	# AND AT THE LEVEL'S OTHER TIMES: the sky, sun and fog of `DaylightTuning`, the clouds lit by `PuffSky.show_daylight`,
	# as the flight level lights them. Every colour in the cloud is a share of the sun's and the sky's, so evening and night
	# must come out of the same knobs.
	for when in [DaylightTuning.When.EVENING, DaylightTuning.When.NIGHT]:
		await _look("%d-wall-over-the-sea-%s" % [33 + when - DaylightTuning.When.EVENING,
			String(DaylightTuning.When.keys()[when]).to_lower()], sky, craft + Vector3(3.0, 6.0, -45.0),
			craft + Vector3(0.0, 1200.0, 7000.0), craft, heading, {"time": when, "ground": SEA_COLOUR, "craft": "savoia",
				"fov": 50.0})


## DOES A HEAP READ AS LIT FROM ONE SIDE? The one thing about the look that can be asserted from pixels (clouds3,
## 2026-09-18). A towering cumulus side-on from 4 km, level with its middle, the sun low on the RIGHT of the picture and a
## little behind the eye. The cloud's pixels are found by drawing the stage twice, with and without it, and its box is
## cut into bands: the right quarter faces the sun and the left quarter is in shade, the top eighth is the crown and the
## bottom eighth the foot. What the user's reference has and clouds2 did not: the sunlit side brighter than the shaded one
## by LIT_OVER_SHADE, the crown brighter than the foot by CROWN_OVER_FOOT, and the shade blue-grey, its blue over its red by
## SHADE_BLUE. Each is measured in the picture as a person sees it, sky and haze and all. clouds2's shader measured 0.028,
## 0.143 and 0.094 here and fails all three; clouds3's first look measured 0.238, 0.402 and 0.181.
const LOOK_SUN := Vector3(-0.85, 0.35, -0.4)
const LIT_OVER_SHADE: float = 0.12
const CROWN_OVER_FOOT: float = 0.25
const SHADE_BLUE: float = 0.14


func _look_is_lit() -> void:
	var tower := PuffCloud.lay_out("towering", Vector3.ZERO, 12)
	var middle := _middle(tower)
	var mid_height := float(tower["base"]) + float(tower["thickness"]) * 0.5
	var eye := Vector3(middle.x, mid_height, middle.z - 4000.0)
	var at := Vector3(middle.x, mid_height, middle.z)
	var options := {"towards_sun": LOOK_SUN, "fov": 50.0}
	var shots: Array[Image] = []
	var stamp := Rect2i()
	for sky in [[], [tower]]:
		var stage := _build(SIZE, sky, eye, at, Vector3.INF, Vector3.FORWARD, options)
		for frame_wait in range(4):
			await RenderingServer.frame_post_draw
		shots.append(stage.get_texture().get_image())
		stamp = BuildStamp.pixels_in(stage)
		stage.queue_free()
	var clear := shots[0]
	var cloudy := shots[1]
	cloudy.convert(Image.FORMAT_RGB8)
	clear.convert(Image.FORMAT_RGB8)
	var path := out.path_join("cockpit-%s-40-look-lit-from-the-right.png" % tag)
	if cloudy.save_png(path) == OK:
		saved += 1
	# THE CLOUD'S PIXELS: those the cloud changes by more than 0.08 in any channel.
	var box := Rect2i()
	var first := true
	var mask := {}
	for y in range(0, SIZE.y, 2):
		for x in range(0, SIZE.x, 2):
			# NOT THE BUILD STAMP: its see-through letters take the colour of whatever is behind them.
			if stamp.has_point(Vector2i(x, y)):
				continue
			var a := cloudy.get_pixel(x, y)
			var b := clear.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > 0.08:
				mask[Vector2i(x, y)] = true
				var here := Rect2i(x, y, 1, 1)
				box = here if first else box.merge(here)
				first = false
	if mask.size() < 2000:
		failures.append("look: the cloud covers only %d sampled pixels" % mask.size())
		return
	var lit := _band_mean(cloudy, mask, Rect2i(box.position.x + box.size.x * 3 / 4, box.position.y + box.size.y / 4,
		box.size.x / 4, box.size.y / 2))
	var shade := _band_mean(cloudy, mask, Rect2i(box.position.x, box.position.y + box.size.y / 4, box.size.x / 4,
		box.size.y / 2))
	var crown := _band_mean(cloudy, mask, Rect2i(box.position.x, box.position.y, box.size.x, box.size.y / 8))
	var foot := _band_mean(cloudy, mask, Rect2i(box.position.x, box.end.y - box.size.y / 8, box.size.x, box.size.y / 8))
	var lum := func(c: Color) -> float: return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	var lit_over_shade: float = lum.call(lit) - lum.call(shade)
	var crown_over_foot: float = lum.call(crown) - lum.call(foot)
	var shade_blue := shade.b - shade.r
	print("[puff_shot] LOOK cloud %d px in %s; lit %s shade %s crown %s foot %s" % [mask.size(), box, lit, shade, crown, foot])
	print("[puff_shot] LOOK lit over shade %.3f (least %.2f), crown over foot %.3f (least %.2f), shade blue over red %.3f (least %.2f)"
		% [lit_over_shade, LIT_OVER_SHADE, crown_over_foot, CROWN_OVER_FOOT, shade_blue, SHADE_BLUE])
	if lit_over_shade < LIT_OVER_SHADE:
		failures.append("look: the sunlit side is only %.3f brighter than the shaded side" % lit_over_shade)
	if crown_over_foot < CROWN_OVER_FOOT:
		failures.append("look: the crown is only %.3f brighter than the foot" % crown_over_foot)
	if shade_blue < SHADE_BLUE:
		failures.append("look: the shade's blue is only %.3f over its red" % shade_blue)


## The mean colour of the cloud's pixels (`mask`) inside `band`.
func _band_mean(picture: Image, mask: Dictionary, band: Rect2i) -> Color:
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for key in mask:
		if band.has_point(key):
			sum += picture.get_pixelv(key)
			n += 1
	return sum / float(maxi(n, 1)) if n > 0 else Color(0, 0, 0, 0)


## WHAT IT COSTS: GPU time, from the engine's own timer on the stage's viewport, over `TIME_FRAMES` frames after
## `TIME_WARM`, for three views -- the layered sky's view with no clouds, with the sky, and from inside a cloud -- on both
## shaders, at two sizes, interleaved round by round so a slow patch on a shared machine lands on every case alike.
##
##   tools\gate_run.ps1 -Probe puff_shot -Perf -Extra "--only=time"
const TIME_WARM: int = 30
const TIME_FRAMES: int = 120
const TIME_ROUNDS: int = 3
const TIME_SIZES: Array[Vector2i] = [Vector2i(1600, 900), Vector2i(2880, 1620)]


func _time() -> void:
	var sky := PuffSky.plan(7, 12000.0)
	var craft := Vector3(0.0, 1750.0, -9000.0)
	var cloud := PuffCloud.lay_out("flat_based", Vector3.ZERO, 13)
	var middle := PuffCloud.middle_of(cloud)
	var deck := PuffCloud.lay_out("altocumulus", Vector3.ZERO, 15)
	var views := [
		{"name": "no-clouds", "sky": [], "from": craft + Vector3(-18.0, 4.0, -26.0), "to": craft + Vector3(400, 150, 1000)},
		{"name": "layered-sky", "sky": sky, "from": craft + Vector3(-18.0, 4.0, -26.0), "to": craft + Vector3(400, 150, 1000)},
		{"name": "inside-a-cloud", "sky": [cloud], "from": middle, "to": middle + Vector3(0, 0, 500)},
		# AND THE SAME, WITH THE PUFFS HOLDING THE EYE GIVEN WAY as the level gives them (`PuffSky.show_eye_in_cloud`, from the
		# eye's own depth): the case the fade was put in to pay for.
		{"name": "inside-given-way", "sky": [cloud], "from": middle, "to": middle + Vector3(0, 0, 500), "give_way": true},
		# UNDER AN ALTOCUMULUS DECK, LOOKING UP INTO IT (clouds3, step 4): the deck fills the frame, and every puff of it is
		# overdraw -- the worst case for step 4's bigger, overlapping puffs, which is the case a headset pays for.
		{"name": "deck-overhead", "sky": [deck], "from": Vector3(0.0, float(deck["base"]) - 1000.0, 0.0),
			"to": Vector3(0.0, float(deck["base"]), 350.0)},
	]
	if not time_views.is_empty():
		views = views.filter(func(view: Dictionary) -> bool: return time_views.has(view["name"]))
	var times := {}
	for round in range(TIME_ROUNDS):
		for size in TIME_SIZES:
			for cut in ([true] if not time_views.is_empty() else [true, false]):
				for view in views:
					cut_at_the_world = cut
					var key := "%s %dx%d %s" % [view["name"], size.x, size.y, "cut" if cut else "tested"]
					var stage := _build(size, view["sky"], view["from"], view["to"])
					if view.get("give_way", false):
						var puffs := stage.find_children("*", "PuffSky", true, false)[0] as PuffSky
						var depth: float = puffs.eye_in(view["from"])["depth"]
						puffs.show_eye_in_cloud(depth)
						if round == 0 and size == TIME_SIZES[0] and cut:
							print("[puff_shot] inside-given-way: eye depth %.2f, given way %.2f" % [depth, PuffSky.give_way(depth)])
					var rid := stage.get_viewport_rid()
					RenderingServer.viewport_set_measure_render_time(rid, true)
					for w in range(TIME_WARM):
						await RenderingServer.frame_post_draw
					var got: Array = times.get(key, [])
					var draws := 0
					for f in range(TIME_FRAMES):
						await RenderingServer.frame_post_draw
						got.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
						draws = RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
							RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
					times[key] = got
					times[key + " draws"] = [draws]
					stage.queue_free()
	for key in times:
		if String(key).ends_with(" draws"):
			continue
		var got: Array = times[key]
		got.sort()
		print("[puff_shot] TIME %-40s median %.3f ms  p95 %.3f ms  (%d frames, %d draw calls)" % [key,
			got[got.size() / 2], got[int(got.size() * 0.95)], got.size(), times[key + " draws"][0]])
		saved += 1


## The middle of a cloud's puffs, and how far its farthest puff reaches out from there, in plan.
func _middle(cloud: Dictionary) -> Vector3:
	var sum := Vector3.ZERO
	for puff in cloud["puffs"]:
		sum += puff["centre"]
	return sum / float((cloud["puffs"] as Array).size())


func _reach(cloud: Dictionary) -> float:
	var middle := _middle(cloud)
	var most := 0.0
	for puff in cloud["puffs"]:
		var c: Vector3 = puff["centre"]
		most = maxf(most, Vector2(c.x - middle.x, c.z - middle.z).length() + maxf(puff["radii"].x, puff["radii"].z))
	return most


## A place `back` metres along -z from the cloud's middle, `up` of its thickness above its base.
func _level_with(cloud: Dictionary, back: float, up: float) -> Vector3:
	var middle := _middle(cloud)
	return Vector3(middle.x - back * 0.35, float(cloud["base"]) + float(cloud["thickness"]) * up, middle.z + back)


## ONE PICTURE: `sky` drawn from `from` looking at `target`, with an aeroplane at `craft` flying along `heading` if one is
## given.
func _look(name: String, sky: Array, from: Vector3, target: Vector3, craft := Vector3.INF,
		heading := Vector3.FORWARD, options := {}) -> void:
	var stage := _build(SIZE, sky, from, target, craft, heading, options)
	for frame_wait in range(4):
		await RenderingServer.frame_post_draw
	var path := out.path_join("cockpit-%s-%s.png" % [tag, name])
	var error := stage.get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(name)
	else:
		saved += 1
	var clouds := stage.find_children("*", "PuffSky", true, false)[0] as PuffSky
	print("[puff_shot] %s %s (%d puffs, %d batches)" % ["saved" if error == OK else "FAILED", path, clouds.puff_count(),
		clouds.batch_count()])
	stage.queue_free()


## A STAGE: its own world, the sky, the sun, a flat ground, `sky`'s clouds, an aeroplane at `craft` if one is given, and a
## camera from `from` to `target`.
func _build(size: Vector2i, sky: Array, from: Vector3, target: Vector3, craft := Vector3.INF,
		heading := Vector3.FORWARD, options := {}) -> SubViewport:
	var stage := SubViewport.new()
	stage.size = size
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.own_world_3d = true
	add_child(stage)
	# THE BUILD STAMP IN THE LOWER RIGHT, as in every picture the game takes (`BuildStamp`, 2026-09-18): this stage is a
	# viewport of its own, which the root's stamp is not drawn into.
	BuildStamp.attach_to(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_paint := ProceduralSkyMaterial.new()
	sky_paint.sky_top_color = Color(0.22, 0.42, 0.78)
	sky_paint.sky_horizon_color = Color(0.66, 0.74, 0.84)
	sky_paint.ground_horizon_color = Color(0.66, 0.74, 0.84)
	sky_paint.ground_bottom_color = Color(0.30, 0.34, 0.30)
	var sky_res := Sky.new()
	sky_res.sky_material = sky_paint
	env.sky = sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.78)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.75, 0.85)
	env.fog_density = 0.00005
	env.fog_sky_affect = 0.0
	if options.has("time"):
		var p: Dictionary = DaylightTuning.preset(int(options["time"]))
		sky_paint.sky_top_color = p["sky_top"]
		sky_paint.sky_horizon_color = p["sky_horizon"]
		sky_paint.ground_horizon_color = p["ground_horizon"]
		sky_paint.ground_bottom_color = p["ground_bottom"]
		env.fog_light_color = p["fog_colour"]
		env.ambient_light_color = (p["sky_top"] as Color).lerp(p["sky_horizon"], 0.5)
	environment.environment = env
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = options.get("sun", SUN_ROTATION)
	light.light_energy = 1.2
	stage.add_child(light)
	if options.has("towards_sun"):
		light.look_at(light.global_position - (options["towards_sun"] as Vector3), Vector3.UP)
	if options.has("time"):
		var towards := DaylightTuning.towards_the_sun(int(options["time"]))
		light.look_at(light.global_position - towards, Vector3.UP if absf(towards.y) < 0.99 else Vector3.FORWARD)
		light.light_color = DaylightTuning.look_of(int(options["time"]))["sun_colour"]
		light.light_energy = DaylightTuning.look_of(int(options["time"]))["sun_energy"]

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120000.0, 120000.0)
	ground.mesh = plane
	var field := StandardMaterial3D.new()
	field.albedo_color = options.get("ground", Color(0.30, 0.38, 0.22))
	ground.material_override = field
	stage.add_child(ground)

	var clouds := PuffSky.new()
	clouds.cut_at_the_world = cut_at_the_world
	stage.add_child(clouds)
	clouds.show_clouds(sky)
	clouds.wear(fine)
	if options.has("time"):
		clouds.show_daylight(DaylightTuning.look_of(int(options["time"])))
	else:
		clouds.show_sun(light.global_transform.basis.z, Color(1.0, 0.97, 0.92), Color(0.56, 0.64, 0.78))

	if craft != Vector3.INF:
		var frame: Node3D = SavoiaAirframe.new() if options.get("craft", "") == "savoia" else FalconAirframe.new()
		frame.call("dress")
		stage.add_child(frame)
		frame.global_position = craft
		# The airframe's nose is along -z.
		frame.look_at(craft + heading, Vector3.UP)

	var camera := Camera3D.new()
	camera.fov = options.get("fov", 70.0)
	camera.near = 0.2
	camera.far = 80000.0
	camera.current = true
	stage.add_child(camera)
	camera.global_position = from
	camera.look_at(target, Vector3.UP)

	return stage
