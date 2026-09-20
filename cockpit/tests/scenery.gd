extends Node
## THE SCENERY HAS TWO FINISHES, AND THE THINGS THAT CHOOSE ONE ARE THE REAL CONTROLS.
##
##   Godot --headless --path cockpit res://tests/scenery.tscn
##
## Headless, so it cannot say whether anything LOOKS better -- that is `scenery_shot`, which
## renders. What it can say, and what nothing else would notice going wrong, is that the
## switch reaches the surfaces: a key that flips `Finish` while the sea keeps its old shader
## is a setting that does nothing, and it looks exactly like "fine is not much finer".
##
## Every press here is a KEY EVENT or a SWITCH TOGGLED, never a call to `Finish.choose`. A
## test that called the function the control calls would pass with the control unplugged.
##
## Read RESULT=, not the exit code.

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[scenery] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	await _the_key_on_the_desk_chooses_it()
	await _the_switch_on_the_board_chooses_it()
	await _the_lights_are_where_an_aircraft_carries_them()
	# LAST, because it starts a session and nothing after it would be starting from nothing.
	await _every_surface_in_the_world_wears_what_the_key_chose()
	_finish()


## ---- the world ---------------------------------------------------------------------------

## THE WHOLE WORLD, and one press of the real key. Every surface is asked what it is drawn with
## -- `FlightLevel.finish_worn`, which reads materials and visibility and never the tier -- and
## every one of them has to have followed.
func _every_surface_in_the_world_wears_what_the_key_chose() -> void:
	var level := (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(180):
		await get_tree().physics_frame
	var fine: bool = Finish.is_fine()
	var worn: Dictionary = level.finish_worn()
	_check("the_world_has_surfaces_with_two_finishes", worn.size() >= 3, "%s" % [worn])
	_check("and_every_one_wears_the_finish_that_is_on", _all_are(worn, fine),
		"%s, finish %s" % [worn, SceneryFinish.name_of(fine)])
	await _press_the_key()
	worn = level.finish_worn()
	_check("and_one_press_of_the_key_changes_every_one_of_them", _all_are(worn, not fine),
		"%s, finish %s" % [worn, SceneryFinish.name_of(Finish.is_fine())])
	await _press_the_key()
	worn = level.finish_worn()
	_check("and_a_second_puts_every_one_back", _all_are(worn, fine), "%s" % [worn])
	# ON THE SAME LEVEL: a second world is a second two hundred frames of boot for nothing.
	_the_towns_draw_windows_as_town_tuning_says(level)
	_the_runway_wears_the_runways_lights(level)
	await _the_beam_on_the_board_sets_the_time_of_day(level)
	await _a_running_clock_writes_in_steps_and_never_per_frame(level)
	await _a_time_of_day_dial_turns_the_sky_and_the_board_turns_it(level)
	await _an_aeroplane_above_the_band_leaves_a_contrail_and_one_below_does_not(level)
	await _a_contrail_fades_without_a_step_and_is_lit_by_the_time_of_day(level)
	_every_trail_is_culled_by_the_worlds_own_box(level)
	_the_plain_sea_is_a_sheet_carrying_the_standing_swell(level)
	level.queue_free()
	await get_tree().process_frame
	Sim.stop()


## ---- the contrails --------------------------------------------------------------------------

## EVERY TRAIL IN THE SKY IS CULLED BY A BOX THE SIZE OF THE WORLD, worked out from it: both yards' MultiMesh wears
## `TrailTuning.culling_box()`, which reaches past `GroundTuning.WORLD_HALF` on every side. A box typed beside the world's
## size is right until the world grows past it, and then every trail vanishes at once with nothing to say why. A node's
## `custom_aabb` is its own property, so headless reads it back (a MultiMesh's instances it does not).
## THE PLAIN SEA IS THE SHEET, AND BOTH SEAS CARRY THE SWELL HULLS FLOAT ON. The plain sea was a 48 km PlaneMesh with four
## vertices, so on the finish a headset starts on every hull heaved +-0.76 m on the simulated swell through a flat plane
## (team-lead, the brig's waterline pictures, 2026-09-15). It now wears SeaSwell's eye-following sheet, and every ocean
## material is handed the simulation's standing swell: asked of the level's own nodes and materials, against
## `Sim.swell_shape` and not a typed number.
func _the_plain_sea_is_a_sheet_carrying_the_standing_swell(level: FlightLevel) -> void:
	var sea := level.get_node_or_null("Sea") as MeshInstance3D
	var swell := level.get("swell") as SeaSwell
	var standing: Dictionary = Sim.swell_shape()
	var vertices: int = 0
	if sea != null and sea.mesh is ArrayMesh and (sea.mesh as ArrayMesh).get_surface_count() > 0:
		vertices = (sea.mesh as ArrayMesh).surface_get_array_len(0)
	var shared: bool = sea != null and swell != null and sea.mesh == swell.mesh
	# In a headset the vertex shader runs once per eye, so twice this a frame, against eight for the quad.
	_check("the_plain_sea_wears_the_eye_following_sheet_and_not_a_four_cornered_quad", shared and vertices > 1000,
		"%d vertices (%d a frame in a headset), the same mesh as the fine sea: %s" % [vertices, vertices * 2, shared])
	var seas: Array[MeshInstance3D] = []
	if sea != null:
		seas.append(sea)
	if swell != null:
		seas.append(swell)
	var wrong: Array[String] = []
	for one in seas:
		var wet := one.material_override as ShaderMaterial
		# A PARAMETER NEVER HANDED OVER READS BACK null, which float() and a typed Vector2 refuse with a script error that
		# ends this function before its last two checks (found by the plain_sea_not_carried mutant). Read each as a
		# Variant, and count anything that is not a number as not handed.
		var handed_height: Variant = wet.get_shader_parameter("standing_height") if wet != null else null
		var handed_first: Variant = wet.get_shader_parameter("standing_first") if wet != null else null
		var height: float = float(handed_height) if handed_height is float else -1.0
		var first: Vector2 = handed_first if handed_first is Vector2 else Vector2.ZERO
		if standing.is_empty() or height <= 0.0 or absf(height - float(standing["height"])) > 0.0001 \
				or first.distance_to(standing["first"] as Vector2) > 0.000001:
			wrong.append("%s (%.3f m, %s)" % [one.name, height, first])
	_check("and_both_seas_are_handed_the_simulations_standing_swell", seas.size() == 2 and wrong.is_empty(),
		"%d seas; not handed it: %s; the simulation's %.3f m along %s" % [seas.size(), wrong,
			float(standing.get("height", -1.0)), standing.get("first", Vector2.ZERO)])
	_check("and_the_sheet_follows_the_eye_on_either_finish", swell != null and swell.is_processing(),
		"SeaSwell processing %s while %s" % [swell.is_processing() if swell != null else false,
			"visible" if swell != null and swell.is_visible_in_tree() else "hidden"])


func _every_trail_is_culled_by_the_worlds_own_box(level: FlightLevel) -> void:
	var box: AABB = TrailTuning.culling_box()
	var world_half: float = float(GroundTuning.WORLD_HALF)
	_check("the_trail_box_reaches_past_the_worlds_edge", box.position.x < -world_half and box.end.x > world_half
		and box.position.z < -world_half and box.end.z > world_half, "%s against half %.0f" % [box, world_half])
	for yard in [level.missiles, level.contrails]:
		var trail: MultiMeshInstance3D = (yard as Node).get("_trail") as MultiMeshInstance3D if yard != null else null
		_check("and_%s_is_culled_by_it" % ("the_missile_yard" if yard == level.missiles else "the_contrail_yard"),
			trail != null and trail.custom_aabb.is_equal_approx(box),
			"%s" % [trail.custom_aabb if trail != null else "no trail"])
## AN AEROPLANE ABOVE THE BAND LEAVES A CONTRAIL, ONE BELOW IT LEAVES NONE, AND A CONTRAIL LASTS LESS THAN A MISSILE'S
## TRAIL -- asked of the level's own yard, laying behind two aeroplanes the simulation is flying.
##
## Put in the sky through the server, which is the only way anything gets there, level at their own cruise, and found by
## where this machine has them: the yard lays from what is drawn, so this reads what the yard read. Their heights are
## either side of `TrailTuning`'s band, a hundred metres clear of it. The lives are read off the materials the two yards
## draw with and held to `TrailTuning` -- a yard that wore a number of its own would pass beside the constants.
func _an_aeroplane_above_the_band_leaves_a_contrail_and_one_below_does_not(level: FlightLevel) -> void:
	var yard: ContrailYard = level.contrails
	if yard == null or level.missiles == null or Sim.server == null:
		_check("the_level_has_contrails_and_a_server_to_fly_them", false,
			"contrails %s, missiles %s, server %s" % [yard, level.missiles, Sim.server])
		return
	var line: Dictionary = Terrain.runway_axis()
	var along: Vector3 = line["along"]
	var across: Vector3 = line["across"]
	var threshold: Vector3 = line["threshold"]
	var clear: float = TrailTuning.CONTRAIL_BAND * 0.5 + 100.0
	var high_at: Vector3 = threshold + across * 1500.0 + Vector3.UP * (TrailTuning.CONTRAIL_ALTITUDE + clear)
	var low_at: Vector3 = threshold - across * 1500.0 + Vector3.UP * (TrailTuning.CONTRAIL_ALTITUDE - clear)
	var yaw: float = atan2(-along.x, -along.z)
	var speed: float = Terrain.cruise_for(Sim.Kind.PLANE)
	var high: int = Sim.spawn_vehicle(Sim.Kind.PLANE, high_at, yaw, along * speed)
	var low: int = Sim.spawn_vehicle(Sim.Kind.PLANE, low_at, yaw, along * speed)
	# SIX SAMPLES A TRAIL, on the yard's own clock, and a little over.
	var flown: float = 0.0
	while flown < TrailTuning.CONTRAIL_SAMPLE_EVERY * 6.0 + 0.05:
		await get_tree().process_frame
		flown += get_process_delta_time()
	var high_drawn: int = _nearest_drawn(high_at + along * speed * flown)
	var low_drawn: int = _nearest_drawn(low_at + along * speed * flown)
	var high_y: float = ((Sim.current.get(high_drawn, {}) as Dictionary).get("position", Vector3.ZERO) as Vector3).y
	var low_y: float = ((Sim.current.get(low_drawn, {}) as Dictionary).get("position", Vector3.ZERO) as Vector3).y
	_check("an_aeroplane_above_the_contrail_height_leaves_a_contrail",
		high_drawn != 0 and yard.strength_of(high_drawn) > 0.9 and yard.segments_behind(high_drawn) > 0,
		"at %.0f m: strength %.2f, %d segments" % [high_y, yard.strength_of(high_drawn),
			yard.segments_behind(high_drawn)])
	_check("and_one_below_it_is_followed_and_leaves_none",
		low_drawn != 0 and low_drawn != high_drawn and yard.strength_of(low_drawn) == 0.0
			and yard.segments_behind(low_drawn) == 0,
		"at %.0f m: strength %.2f, %d segments" % [low_y, yard.strength_of(low_drawn), yard.segments_behind(low_drawn)])
	var fine: bool = Finish.is_fine()
	var missile_lasts: float = level.missiles.trail_lasts()
	_check("and_a_missile_trail_lasts_what_trail_tuning_says",
		is_equal_approx(missile_lasts, TrailTuning.missile_life(fine)),
		"%.2f s on %s, tuning %.2f" % [missile_lasts, SceneryFinish.name_of(fine), TrailTuning.missile_life(fine)])
	_check("and_a_contrail_lasts_its_share_of_that_and_less",
		yard.lasts() > 0.0 and yard.lasts() < missile_lasts
			and is_equal_approx(yard.lasts(), missile_lasts * TrailTuning.CONTRAIL_SHARE),
		"contrail %.2f s, missile trail %.2f s" % [yard.lasts(), missile_lasts])
	Sim.server.despawn_vehicle(high)
	Sim.server.despawn_vehicle(low)


## A CONTRAIL FADES WITHOUT A STEP WHERE ONE SEGMENT MEETS THE NEXT, AND IS LIT BY THE TIME OF DAY -- asked for on
## 2026-09-14: "reducing the brightness of the contrails at night ... fade in and out more evenly".
##
## NO STEP AT A JOIN. An aeroplane put just under the top of the band, sinking, lays a trail whose strength falls by
## about half in two seconds. Each segment hands the drawer a strength at each of its ends, and where one segment ends
## the next begins: the two must be one strength laid at one moment. THE BOUND IS 1/255: every factor of a trail's alpha
## is between 0 and 1, so strengths that differ by d at a join move no pixel's alpha by more than d, and a step under one
## level of an 8-bit target is a step nobody can see. Until 2026-09-14 a segment carried ONE strength, the mean of its
## two ends, so neighbours stepped by half of what the strength moved over two samples.
##
## HEADLESS HAS NO SHADER TO ASK, and its drawer keeps no custom data (a dummy MultiMesh reads back zeros), so this reads
## what the yard handed the drawer, end by end (`ContrailYard.laid_behind`). That the shaders fade by those ends, and by
## each point's own age rather than its segment's, is shown in pictures: agents.md, "A contrail comes and goes along its
## length".
##
## DIMMER AT NIGHT BY THE LIGHT A CLOUD HAS. The light a contrail wears, set through the level's own `choose_time`, is
## the sun and sky `LiftYard.cloud_light` lights a cloud with at that time, over day's: exactly white by day, so the day
## look is untouched, and at night the clouds' own ratio -- so a trail is never brighter against the night than the
## clouds round it.
func _a_contrail_fades_without_a_step_and_is_lit_by_the_time_of_day(level: FlightLevel) -> void:
	var yard: ContrailYard = level.contrails
	if yard == null or Sim.server == null:
		return
	var was: int = level.time_of_day()
	level.choose_time(DaylightTuning.When.DAY)
	var day: Variant = yard.light()
	level.choose_time(DaylightTuning.When.NIGHT)
	var night: Variant = yard.light()
	level.choose_time(was)
	var wanted: Vector3 = _cloud_lit(DaylightTuning.When.NIGHT) / _cloud_lit(DaylightTuning.When.DAY)
	_check("a_contrail_by_day_is_lit_white",
		typeof(day) == TYPE_VECTOR3 and (day as Vector3).is_equal_approx(Vector3.ONE), "day %s" % [day])
	_check("and_at_night_dimmer_by_the_light_a_cloud_has",
		typeof(night) == TYPE_VECTOR3 and (night as Vector3).distance_to(wanted) < 0.001
			and (night as Vector3).dot(LUMINANCE) < 0.5 * Vector3.ONE.dot(LUMINANCE),
		"night %s, a cloud's night over its day %s" % [night, wanted])

	var line: Dictionary = Terrain.runway_axis()
	var along: Vector3 = line["along"]
	# PUT UP ABOVE THE BAND AND READ ONCE IT IS HALF WAY THROUGH, so the last segments kept are the steep part of it. An
	# aeroplane put up sinking holds its height at first and only then goes down: put up in the band and read 2.5 s
	# later, it laid 0.81 then eleven of 0.80, and 2 of 11 segments had a strength that moved along them (2026-09-14).
	var above: float = TrailTuning.CONTRAIL_ALTITUDE + TrailTuning.CONTRAIL_BAND * 0.75
	var from: Vector3 = (line["threshold"] as Vector3) + (line["across"] as Vector3) * 900.0 + Vector3.UP * above
	var speed: float = Terrain.cruise_for(Sim.Kind.PLANE)
	var craft: int = Sim.spawn_vehicle(Sim.Kind.PLANE, from, atan2(-along.x, -along.z), along * speed + Vector3.DOWN * 10.0)
	var flown: float = 0.0
	var at: Vector3 = from
	var drawn: int = 0
	while flown < 20.0 and (drawn == 0 or at.y > TrailTuning.CONTRAIL_ALTITUDE):
		await get_tree().process_frame
		flown += get_process_delta_time()
		drawn = _nearest_drawn(at + along * speed * get_process_delta_time())
		if drawn != 0:
			at = (Sim.current[drawn] as Dictionary).get("position", at) as Vector3
	var laid: Array = yard.laid_behind(drawn) if drawn != 0 else []
	var joins: int = 0
	var moving: int = 0
	var worst: float = 0.0
	var strengths: PackedStringArray = []
	for one in laid:
		strengths.append("%.2f" % float((one as Dictionary)["to_strength"]))
	for k in range(laid.size() - 1):
		var older: Dictionary = laid[k]
		var newer: Dictionary = laid[k + 1]
		if not is_equal_approx(float(older["to_laid"]), float(newer["from_laid"])):
			continue
		joins += 1
		worst = maxf(worst, absf(float(older["to_strength"]) - float(newer["from_strength"])))
		if absf(float(older["to_strength"]) - float(older["from_strength"])) > 1.0 / 255.0:
			moving += 1
	_check("a_contrail_has_no_step_where_one_segment_meets_the_next",
		joins >= 6 and moving >= 3 and worst <= 1.0 / 255.0,
		"at %.0f m after %.1f s: %d joins, %d segments whose strength moves along them, the largest step %.4f against %.4f; laid %s"
			% [at.y, flown, joins, moving, worst, 1.0 / 255.0, ", ".join(strengths)])
	Sim.server.despawn_vehicle(craft)


const LUMINANCE := Vector3(0.2126, 0.7152, 0.0722)


## THE LIGHT A CLOUD'S SUNLIT, SKY-LIT SIDE HAS AT A TIME OF DAY, as the renderer holds it: `cloud_light`'s colours
## reach the cloud shaders through `source_color` uniforms, which the renderer takes to linear.
static func _cloud_lit(which: int) -> Vector3:
	var light: Dictionary = LiftYard.cloud_light(DaylightTuning.look_of(which))
	var lit: Color = (light["sun_light"] as Color).srgb_to_linear() + (light["sky_light"] as Color).srgb_to_linear()
	return Vector3(lit.r, lit.g, lit.b)


## The entity this machine has nearest a point, within 200 m, or 0.
static func _nearest_drawn(near: Vector3) -> int:
	var best: int = 0
	var nearest: float = 200.0
	for entity in Sim.current:
		var away: float = ((Sim.current[entity] as Dictionary).get("position", Vector3.ZERO) as Vector3).distance_to(near)
		if away < nearest:
			nearest = away
			best = int(entity)
	return best


## ---- the lights ------------------------------------------------------------------------------

## THE RUNWAY'S LIGHTS WEAR THE RUNWAY'S MATERIAL, AND AN AEROPLANE'S THE AIRCRAFT'S: asked of the nodes the level drew,
## never of the two materials alone. Since fd842f5 (2026-09-13) `VehicleLights.build` took an `on_aircraft` flag and
## ignored it, so the runway wore the aircraft material -- smaller, dimmed by day and dithered -- while this file's checks
## on `runway_paint()` passed, because they read a material nothing was drawn with. Found 2026-09-14 when a still picture
## of the runway, every vehicle hidden, changed with a change to the aircraft lights.
func _the_runway_wears_the_runways_lights(level: FlightLevel) -> void:
	var runway := level.get_node_or_null("RunwayLights") as MultiMeshInstance3D
	var aircraft: MultiMeshInstance3D = null
	for node in level.find_children("Lights", "MultiMeshInstance3D", true, false):
		if node != runway:
			aircraft = node as MultiMeshInstance3D
			break
	_check("the_runway_wears_the_runways_lights_and_an_aeroplane_the_aircrafts",
		runway != null and runway.material_override == VehicleLights.runway_paint()
			and aircraft != null and aircraft.material_override == VehicleLights.paint(),
		"runway %s, an aeroplane %s" % [
			"missing" if runway == null else ("runway's" if runway.material_override == VehicleLights.runway_paint()
				else "the aircraft's" if runway.material_override == VehicleLights.paint() else "another"),
			"missing" if aircraft == null else ("aircraft's" if aircraft.material_override == VehicleLights.paint()
				else "another")])


## ---- the towns -------------------------------------------------------------------------------

## EVERY WINDOW NUMBER ON BOTH TOWN MATERIALS IS TOWNTUNING'S FOR THAT FINISH, read back off the materials. Until
## 2026-09-13 none of bay, window size and window fade were handed over, so both finishes drew the shader's own defaults
## and FINE's numbers in TownTuning reached nothing -- a tuning file whose numbers do nothing looks exactly like tuning
## that makes no difference. The least pixels a window must span, which stops the shimmer, is the same on both.
func _the_towns_draw_windows_as_town_tuning_says(level: FlightLevel) -> void:
	var materials: Array[ShaderMaterial] = level.towns._materials() if level.towns != null else []
	var wanted: Array[Dictionary] = [
		{"bay": TownTuning.PLAIN_BAY, "window_wide": TownTuning.PLAIN_WINDOW_WIDE,
			"window_tall": TownTuning.PLAIN_WINDOW_TALL, "windows_to": TownTuning.PLAIN_WINDOWS_TO,
			"window_pixels_least": TownTuning.WINDOW_PIXELS_LEAST, "light_pixels_least": TownTuning.LIGHT_PIXELS_LEAST},
		{"bay": TownTuning.FINE_BAY, "window_wide": TownTuning.FINE_WINDOW_WIDE,
			"window_tall": TownTuning.FINE_WINDOW_TALL, "windows_to": TownTuning.FINE_WINDOWS_TO,
			"window_pixels_least": TownTuning.WINDOW_PIXELS_LEAST, "light_pixels_least": TownTuning.LIGHT_PIXELS_LEAST}]
	var wrong: Array[String] = []
	for f in range(mini(materials.size(), wanted.size())):
		for uniform in wanted[f]:
			var read: Variant = materials[f].get_shader_parameter(uniform)
			if read == null or not is_equal_approx(float(read), float(wanted[f][uniform])):
				wrong.append("%s %s reads %s, not %s" % [["PLAIN", "FINE"][f], uniform, read, wanted[f][uniform]])
	_check("the_towns_draw_windows_as_town_tuning_says_on_both_finishes", materials.size() == 2 and wrong.is_empty(),
		"%d materials%s" % [materials.size(), "" if wrong.is_empty() else ": " + "; ".join(wrong)])


## ---- the time of day ---------------------------------------------------------------------

## THE RIGHT HAND'S BEAM PRESSES THE TIME TAB AND THEN EVENING, AND THE LEVEL'S SKY IS EVENING'S -- written once.
##
## Through `force_hand` and `force_input`, the seams a headset's hand and trigger arrive by, so it is the rig's own
## `_point_a_hand`, `Clipboard.aim` and the buttons deciding, and the level's `choose_time` answering what the page
## announced. The hand is re-posed on EVERY frame of a pull: a forced hand is a world pose, and the rig is sat in a
## craft the simulation moves, so a pose set once is a pose the board is carried away from.
##
## The sun is read back off the light -- its energy, and its elevation and azimuth from its own basis -- and the fog
## off the environment, and held to `DaylightTuning.EVENING` as written there, never to anything `Daylight` works
## out. Then sixty frames, and nothing is written again: `Daylight.writes` does not move, and no value does either.
func _the_beam_on_the_board_sets_the_time_of_day(level: FlightLevel) -> void:
	var rig: PilotRig = level.rig
	if rig == null or level.daylight == null:
		_check("the_level_has_a_rig_and_a_time_of_day", false, "rig %s, daylight %s" % [rig, level.daylight])
		return
	var board: Clipboard = rig.clipboard
	var page: ClipboardPage = board.page()
	board.show_board(true)
	page.show_tab(ClipboardPage.Tab.CRAFT)
	await get_tree().process_frame
	var started: int = level.time_of_day()
	var seat_was: Vector3 = rig.global_position
	await _beam_presses(rig, _button_reading(page, "TIME"))
	_check("the_beam_turns_the_board_to_the_time_tab", page.tab() == ClipboardPage.Tab.TIME,
		"on %s; the rig moved %.3f m meanwhile" % [ClipboardPage.Tab.keys()[page.tab()],
			rig.global_position.distance_to(seat_was)])
	await _beam_presses(rig, _button_reading(page, "EVENING"))
	var evening: Dictionary = DaylightTuning.EVENING
	_check("and_then_evening_and_the_levels_time_is_evening",
		started != DaylightTuning.When.EVENING and level.time_of_day() == DaylightTuning.When.EVENING,
		"started %s, now %s" % [DaylightTuning.name_of(started), DaylightTuning.name_of(level.time_of_day())])
	var lit: Button = _button_reading(page, "EVENING")
	var day: Button = _button_reading(page, "DAY")
	_check("and_the_board_shows_evening_and_only_evening",
		lit != null and lit.button_pressed and day != null and not day.button_pressed,
		"EVENING %s, DAY %s" % [lit.button_pressed if lit != null else null,
			day.button_pressed if day != null else null])

	var sun := level.get_node("DirectionalLight3D") as DirectionalLight3D
	var air: Environment = (level.get_node("WorldEnvironment") as WorldEnvironment).environment
	var shining: Vector3 = -sun.global_basis.z.normalized()
	var elevation: float = rad_to_deg(asin(-shining.y))
	var azimuth: float = fposmod(rad_to_deg(atan2(-shining.x, -shining.z)), 360.0)
	_check("and_the_sun_stands_and_shines_as_evening_says",
		absf(sun.light_energy - float(evening["sun_energy"])) < 0.0001
			and absf(elevation - float(evening["sun_elevation"])) < 0.01
			and absf(azimuth - float(evening["sun_azimuth"])) < 0.01,
		"energy %.3f, elevation %.2f, azimuth %.2f; evening %.3f, %.2f, %.2f" % [sun.light_energy, elevation, azimuth,
			evening["sun_energy"], evening["sun_elevation"], evening["sun_azimuth"]])
	_check("and_the_fog_is_evenings_colour", air.fog_light_color.is_equal_approx(evening["fog_colour"]),
		"%s against %s" % [air.fog_light_color, evening["fog_colour"]])
	var windows: Array[float] = level.towns.windows_lit() if level.towns != null else []
	_check("and_the_towns_light_evenings_share_of_windows",
		windows.size() == 2 and windows.all(func(w: float): return is_equal_approx(w, float(evening["windows_lit"]))),
		"%s against %s on both finishes" % [windows, evening["windows_lit"]])
	# AND THE TOWN'S LAMPS AT EVENING'S SHARE OF NIGHT'S WINDOWS, by the level's own call, and flashing on the tick the level
	# hands over each frame -- read off the material, against the tick this frame was stepped to.
	var lamps: ShaderMaterial = level.towns.lamp_material() if level.towns != null else null
	var lamps_share: Variant = lamps.get_shader_parameter("lamps") if lamps != null else null
	await get_tree().process_frame
	var phase: Variant = lamps.get_shader_parameter("flash_phase") if lamps != null else null
	var ticked: float = TownView.flash_phase(Engine.get_physics_frames(), Sim.tick_dt())
	var tick_share: float = Sim.tick_dt() * TownTuning.OBSTRUCTION_FLASHES_A_MINUTE / 60.0
	_check("and_the_towns_lamps_show_evenings_share_and_flash_on_the_tick",
		lamps_share != null and is_equal_approx(float(lamps_share), TownView.lamps_for(float(evening["windows_lit"])))
			and float(evening["windows_lit"]) > 0.0 and phase != null
			and absf(angle_difference(float(phase) * TAU, ticked * TAU)) / TAU <= tick_share * 2.0 + 0.000001,
		"lamps %s against %.3f; flash phase %s against the tick's %.4f" % [lamps_share,
			TownView.lamps_for(float(evening["windows_lit"])), phase, ticked])
	var lamp_bright: Variant = VehicleLights.paint().get_shader_parameter("daylight")
	_check("and_the_aircraft_lights_are_evenings_brightness",
		lamp_bright == evening["aircraft_lights"],
		"%s against %s" % [lamp_bright, evening["aircraft_lights"]])
	# AND THE CLOUDS ARE LIT BY THAT SUN. The fine cloud is unshaded and lights itself from uniforms the level writes
	# once per change, so a cloud left on day's light at evening is a white heap in an orange sky with nothing to say so.
	# Held to the LIGHT NODE's own direction and to EVENING's numbers as written, not to `LiftYard.cloud_light`.
	# BOTH FINISHES: PLAIN's clouds are lit the same way now, and the suite has worn both by this point.
	var cloud_suns: Array = level.lift.cloud_lit_with("towards_sun") if level.lift != null else []
	var cloud_colours: Array = level.lift.cloud_lit_with("sun_light") if level.lift != null else []
	var evening_sun: Color = (evening["sun_colour"] as Color) * float(evening["sun_energy"])
	var lit_right: bool = cloud_suns.size() == 2 and cloud_colours.size() == 2
	for i in range(mini(cloud_suns.size(), cloud_colours.size())):
		lit_right = lit_right and cloud_suns[i] is Vector3 and (cloud_suns[i] as Vector3).is_equal_approx(-shining) \
			and cloud_colours[i] is Color and (cloud_colours[i] as Color).is_equal_approx(evening_sun)
	_check("and_the_clouds_are_lit_by_evenings_sun_on_both_finishes", lit_right,
		"towards %s against %s, colour %s against %s (PLAIN, FINE)" % [cloud_suns, -shining, cloud_colours,
			evening_sun])

	var writes: int = level.daylight.writes
	var lamp_writes: int = VehicleLights.writes
	var cloud_writes: int = level.lift.light_writes if level.lift != null else 0
	var values: String = _the_sky_as_it_is(sun, air)
	for i in range(60):
		await get_tree().process_frame
	var still: bool = _the_sky_as_it_is(sun, air) == values
	_check("and_sixty_frames_on_nothing_has_been_written_again",
		level.daylight.writes == writes and VehicleLights.writes == lamp_writes and still
			and (level.lift == null or level.lift.light_writes == cloud_writes),
		"%d sky, %d light and %d cloud writes in 60 frames, values %s" % [level.daylight.writes - writes,
			VehicleLights.writes - lamp_writes,
			(level.lift.light_writes - cloud_writes) if level.lift != null else 0,
			"unchanged" if still else "CHANGED"])
	# ANY TIME, BY THE BEAM (2026-09-18): +1H on the same tab moves the level's clock an hour on from EVENING, the readout says
	# the new time and the sky's words, and EVENING's button goes out -- the level's answer, not the page's guess.
	var evening_at: float = level.clock()
	await _beam_presses(rig, _button_reading(page, "+1H"))
	var words := page.find_child("ClockWords", true, false) as Label
	var hour_on: float = fposmod(evening_at + 60.0, Orrery.DAY_LONG)
	_check("and_plus_an_hour_by_the_beam_moves_the_levels_clock_an_hour",
		absf(level.clock() - hour_on) < 0.05 and words != null and words.text.begins_with(Orrery.words(hour_on))
			and not _button_reading(page, "EVENING").button_pressed,
		"the level at %s from %s; the readout '%s'; EVENING lit %s" % [Orrery.words(level.clock()),
			Orrery.words(evening_at), words.text if words != null else "none",
			_button_reading(page, "EVENING").button_pressed])
	level.choose_time(DaylightTuning.When.EVENING)
	board.show_board(false)
	_an_aircraft_light_fades_with_distance_by_day_and_not_at_night(level)
	_the_moon_is_in_both_skies_at_night_and_in_neither_by_day(level)
	_the_moon_is_twice_the_size_it_was(level)
	_the_stars_are_out_at_night_and_in_by_day_and_at_evening(level)


## A RUNNING CLOCK WRITES IN STEPS, NEVER PER FRAME (2026-09-18). "Once, never per frame" was `Daylight`'s rule when there
## were three presets; with a clock the sun moves, and the rule is that the world is told in steps (`Daylight.STEP_DEGREES`,
## `STEP_GAP`). So the clock is run through the level's own `choose_rate` at 3,600 times -- an hour a real second, the
## fastest there is, fifteen degrees of sun in 120 frames -- and held to: at least one step (the clock runs), no more steps
## than the gap allows in that time and one more, and no more writes than those steps times `Daylight.writes_per_step`.
## Then the clock goes back to the time and rate it had. Frames are 1/120 s each under the gate's --fixed-fps, which is
## the delta `Daylight` counts its gap in.
const AN_HOUR_A_SECOND: float = 3600.0


func _a_running_clock_writes_in_steps_and_never_per_frame(level: FlightLevel) -> void:
	var daylight: Daylight = level.daylight
	var clock_was: float = Net.clock_now()
	var rate_was: float = Net.clock_rate
	var steps: int = daylight.steps
	var writes: int = daylight.writes
	var frames: int = 120
	var seconds: float = 0.0
	level.choose_rate(AN_HOUR_A_SECOND)
	for i in range(frames):
		await get_tree().process_frame
		seconds += get_process_delta_time()
	var stepped: int = daylight.steps - steps
	var written: int = daylight.writes - writes
	var most_steps: int = int(floor(seconds / Daylight.STEP_GAP)) + 1
	_check("a_running_clock_writes_in_steps_and_never_per_frame",
		stepped >= 1 and stepped <= most_steps and written <= stepped * Daylight.writes_per_step(),
		"%d steps and %d writes in %d frames (%.2f s) at %dx; at most %d steps of %d writes" % [stepped, written, frames,
			seconds, int(AN_HOUR_A_SECOND), most_steps, Daylight.writes_per_step()])
	# AND THE TIME-LAPSE, a day in ten seconds (2026-09-18): a step every frame and no more -- the frames and the one the
	# rate's own choice may show -- each no more than `writes_per_step`, and what a step costs said, the mean and the worst.
	steps = daylight.steps
	writes = daylight.writes
	var usec: int = daylight.step_usec
	level.choose_rate(Net.CLOCK_RATE_LAPSE)
	for i in range(frames):
		await get_tree().process_frame
	stepped = daylight.steps - steps
	written = daylight.writes - writes
	_check("and_a_time_lapse_steps_every_frame_and_no_more",
		stepped >= frames - 1 and stepped <= frames + 1 and written <= stepped * Daylight.writes_per_step(),
		"%d steps and %d writes in %d frames at %dx; a step %.0f us on the mean, the worst ever %d us; by part, mean/worst: %s" % [
			stepped, written, frames, int(Net.CLOCK_RATE_LAPSE), float(daylight.step_usec - usec) / maxf(float(stepped), 1.0),
			daylight.step_usec_worst, daylight.costs_said()])
	level.choose_rate(rate_was)
	level.choose_clock(clock_was)


## BY DAY A FAR AIRCRAFT LIGHT FADES AND SHRINKS; AT NIGHT IT IS AS IT WAS. "The lights on planes are still too bright in
## the daytime, dim them at distance more" (2026-09-13): the fade with distance and how much of its least angle a far
## light keeps are the time of day's, read back off the aircraft material after the level's own `choose_time` -- the call
## the TIME tab lands on, which the beam has just been seen to reach. Night is held to the values the lights had before
## there was a day fade, typed here, because "as it was" is the claim; the runway's never fade by time at all.
func _an_aircraft_light_fades_with_distance_by_day_and_not_at_night(level: FlightLevel) -> void:
	var paint: ShaderMaterial = VehicleLights.paint()
	var runway: ShaderMaterial = VehicleLights.runway_paint()
	var started: int = level.time_of_day()
	var read: Dictionary = {}
	for time in [DaylightTuning.When.DAY, DaylightTuning.When.NIGHT]:
		level.choose_time(time)
		read[time] = [paint.get_shader_parameter("dim_to"), paint.get_shader_parameter("far_bright"),
			paint.get_shader_parameter("far_least"), runway.get_shader_parameter("dim_to"),
			runway.get_shader_parameter("far_least")]
	level.choose_time(started)
	var day: Dictionary = DaylightTuning.DAY
	var night: Dictionary = DaylightTuning.NIGHT
	var by_day: Array = read[DaylightTuning.When.DAY]
	var at_night: Array = read[DaylightTuning.When.NIGHT]
	_check("by_day_a_far_aircraft_light_fades_and_shrinks",
		by_day[0] == day["aircraft_dim_to"] and by_day[1] == day["aircraft_far_bright"]
			and by_day[2] == day["aircraft_far_least"] and float(by_day[2]) < 1.0
			and float(by_day[0]) < float(night["aircraft_dim_to"]),
		"dim_to %s, far_bright %s, far_least %s; DAY says %s, %s, %s" % [by_day[0], by_day[1], by_day[2],
			day["aircraft_dim_to"], day["aircraft_far_bright"], day["aircraft_far_least"]])
	_check("and_at_night_it_is_as_it_was",
		at_night[0] == 5000.0 and at_night[1] == 0.35 and at_night[2] == 1.0
			and at_night[0] == night["aircraft_dim_to"] and at_night[1] == night["aircraft_far_bright"]
			and at_night[2] == night["aircraft_far_least"],
		"dim_to %s, far_bright %s, far_least %s at night" % at_night.slice(0, 3))
	_check("and_the_runway_lights_never_fade_by_the_time_of_day",
		by_day[3] == 5000.0 and by_day[4] == 1.0 and at_night[3] == 5000.0 and at_night[4] == 1.0,
		"runway dim_to %s and far_least %s by day, %s and %s at night" % [by_day[3], by_day[4], at_night[3], at_night[4]])


## THE MOON IS IN BOTH SKIES AT NIGHT, LIT FROM WHERE THE SUN TRULY IS, AND IN NEITHER BY DAY (2026-09-15). What reaches the
## skies is how bright the moon is, where it stands and the true sun its phase is taken from -- read back off BOTH materials,
## because a headset starts on PLAIN and a moon on FINE's sky alone is a moon nobody in a headset sees. After the level's own
## `choose_time`, which the beam has been seen to reach. By day the true sun is held to the light node's own direction.
##
## AT NIGHT, TO THE NUMBERS THE CLOCK WAS SOLVED FOR (2026-09-18, `Orrery`'s note), written here and not asked of `Orrery`:
## the moon 40 degrees up at compass 139.54, and the light coming from it; the true sun 26.9 degrees under the horizon, 150
## degrees from the moon, so a waning gibbous 93 per cent lit. Until 2026-09-18 the true sun was typed in NIGHT, 30 down at
## azimuth 285, and the moon stood along the light at compass 40.
## Where the disc is DRAWN, and which side of it is lit, only a picture says: tests/moon_shot.gd.
const NIGHT_MOON_UP: float = 40.0
const NIGHT_MOON_BEARING: float = 139.54
const NIGHT_SUN_UP: float = -26.87
const NIGHT_SUN_FROM_MOON: float = 150.0
func _the_moon_is_in_both_skies_at_night_and_in_neither_by_day(level: FlightLevel) -> void:
	var skies: Array = [level.daylight.plain_sky, level.daylight.fine_sky]
	var sun := level.get_node("DirectionalLight3D") as DirectionalLight3D
	var started: int = level.time_of_day()
	var read: Dictionary = {}
	for time in [DaylightTuning.When.DAY, DaylightTuning.When.NIGHT]:
		level.choose_time(time)
		var rows: Array = []
		for paint in skies:
			var material := paint as ShaderMaterial
			rows.append([material.get_shader_parameter("moon_bright"), material.get_shader_parameter("true_sun"),
				material.get_shader_parameter("moon_direction")] if material != null else [null, null, null])
		read[time] = {"light": sun.global_basis.z.normalized(), "skies": rows}
	level.choose_time(started)
	var night: Dictionary = DaylightTuning.NIGHT
	var wrong: Array[String] = []
	for i in range(skies.size()):
		var sky_name: String = ["PLAIN", "FINE"][i]
		var at_night: Array = read[DaylightTuning.When.NIGHT]["skies"][i]
		var by_day: Array = read[DaylightTuning.When.DAY]["skies"][i]
		if at_night[0] == null or float(at_night[0]) <= 0.0 or not is_equal_approx(float(at_night[0]), float(night["moon_bright"])):
			wrong.append("%s moon at night %s, NIGHT says %s" % [sky_name, at_night[0], night["moon_bright"]])
		if not at_night[1] is Vector3 or not at_night[2] is Vector3:
			wrong.append("%s true sun at night %s, moon %s" % [sky_name, at_night[1], at_night[2]])
		else:
			var towards: Vector3 = at_night[1]
			var moon: Vector3 = at_night[2]
			var elevation: float = rad_to_deg(asin(clampf(towards.y, -1.0, 1.0)))
			var apart: float = rad_to_deg(towards.angle_to(moon))
			var moon_up: float = rad_to_deg(asin(clampf(moon.y, -1.0, 1.0)))
			var moon_bearing: float = fposmod(rad_to_deg(atan2(moon.x, -moon.z)), 360.0)
			if absf(elevation - NIGHT_SUN_UP) > 0.05 or absf(apart - NIGHT_SUN_FROM_MOON) > 0.05:
				wrong.append("%s true sun at night %.2f up and %.2f from the moon, wanted %.2f and %.2f" % [sky_name,
					elevation, apart, NIGHT_SUN_UP, NIGHT_SUN_FROM_MOON])
			if absf(moon_up - NIGHT_MOON_UP) > 0.05 or absf(moon_bearing - NIGHT_MOON_BEARING) > 0.05 \
					or not moon.is_equal_approx(read[DaylightTuning.When.NIGHT]["light"]):
				wrong.append("%s moon at night %.2f up at compass %.2f, the light from %s; wanted %.1f at %.1f, the light" % [
					sky_name, moon_up, moon_bearing, read[DaylightTuning.When.NIGHT]["light"], NIGHT_MOON_UP,
					NIGHT_MOON_BEARING])
		if by_day[0] == null or float(by_day[0]) != 0.0:
			wrong.append("%s moon by day %s" % [sky_name, by_day[0]])
		if not by_day[1] is Vector3 or not (by_day[1] as Vector3).is_equal_approx(read[DaylightTuning.When.DAY]["light"]):
			wrong.append("%s true sun by day %s, the light comes from %s" % [sky_name, by_day[1],
				read[DaylightTuning.When.DAY]["light"]])
	var face: Texture2D = null
	for paint in skies:
		face = (paint as ShaderMaterial).get_shader_parameter("moon_face") if paint != null else null
		if face == null or face.get_width() != 512:
			wrong.append("a sky's moon face is %s" % face)
	_check("the_moon_is_in_both_skies_at_night_lit_from_the_true_sun_and_in_neither_by_day", wrong.is_empty(),
		"moon %s at night on PLAIN and FINE, true sun %s; by day %s" % [
			[read[DaylightTuning.When.NIGHT]["skies"][0][0], read[DaylightTuning.When.NIGHT]["skies"][1][0]],
			read[DaylightTuning.When.NIGHT]["skies"][0][1],
			[read[DaylightTuning.When.DAY]["skies"][0][0], read[DaylightTuning.When.DAY]["skies"][1][0]]]
			+ ("" if wrong.is_empty() else ": " + "; ".join(wrong)))


## THE MOON IS TWICE AS LARGE AS IT WAS (2026-09-17): "make the moon twice as large at night". The angular radius BOTH
## skies are handed at night, read back off the materials after the level's own `choose_time`, is held to twice the size
## the moon was drawn until then -- 0.78 degrees across, 1.5 times the real 0.52, 157 px in moon_shot's close view -- which
## is written here as a number and not asked of NightSkyTuning, so putting `MOON_ENLARGED` back, or a sky that kept a
## radius of its own, fails. The drawn disc's width in pixels is tests/moon_shot.gd's.
const MOON_DIAMETER_DEGREES_UNTIL_2026_09_17: float = 0.78


func _the_moon_is_twice_the_size_it_was(level: FlightLevel) -> void:
	var started: int = level.time_of_day()
	level.choose_time(DaylightTuning.When.NIGHT)
	var across: Array = []
	for paint in [level.daylight.plain_sky, level.daylight.fine_sky]:
		var radius: Variant = (paint as ShaderMaterial).get_shader_parameter("moon_radius") if paint != null else null
		across.append(rad_to_deg(float(radius)) * 2.0 if radius != null else 0.0)
	level.choose_time(started)
	var wanted: float = MOON_DIAMETER_DEGREES_UNTIL_2026_09_17 * 2.0
	_check("the_moon_is_twice_the_size_it_was_on_both_skies",
		absf(float(across[0]) - wanted) <= wanted * 0.01 and absf(float(across[1]) - wanted) <= wanted * 0.01,
		"PLAIN's moon %.3f degrees across, FINE's %.3f, wanted %.2f: twice the %.2f it was" % [across[0], across[1], wanted,
			MOON_DIAMETER_DEGREES_UNTIL_2026_09_17])


## THE STARS ARE OUT AT NIGHT AND IN BY DAY AND AT EVENING, ON BOTH SKIES (2026-09-15), read back after the level's own
## `choose_time`: 0 with DAY's sun 34.8 degrees up and EVENING's 7 up, and all of them with NIGHT's 30 down. Held to those
## three facts, not to `NightSkyTuning.stars_seen`, so a fade that forgot the sun would be caught. Whether they are DRAWN,
## how wide, and whether they twinkle as the head turns, only a picture says: tests/star_shot.gd.
func _the_stars_are_out_at_night_and_in_by_day_and_at_evening(level: FlightLevel) -> void:
	var skies: Array = [level.daylight.plain_sky, level.daylight.fine_sky]
	var started: int = level.time_of_day()
	var read: Dictionary = {}
	for time in [DaylightTuning.When.DAY, DaylightTuning.When.EVENING, DaylightTuning.When.NIGHT]:
		level.choose_time(time)
		var row: Array = []
		for paint in skies:
			row.append((paint as ShaderMaterial).get_shader_parameter("stars") if paint != null else null)
		read[time] = row
	level.choose_time(started)
	var wrong: Array[String] = []
	for i in range(skies.size()):
		var sky_name: String = ["PLAIN", "FINE"][i]
		for time in [DaylightTuning.When.DAY, DaylightTuning.When.EVENING]:
			var seen: Variant = read[time][i]
			if seen == null or float(seen) != 0.0:
				wrong.append("%s %s %s" % [sky_name, DaylightTuning.name_of(time), seen])
		var at_night: Variant = read[DaylightTuning.When.NIGHT][i]
		if at_night == null or float(at_night) < 0.999:
			wrong.append("%s NIGHT %s" % [sky_name, at_night])
	_check("the_stars_are_out_at_night_and_in_by_day_and_at_evening_on_both_skies", wrong.is_empty(),
		"stars on PLAIN and FINE: day %s, evening %s, night %s%s" % [read[DaylightTuning.When.DAY],
			read[DaylightTuning.When.EVENING], read[DaylightTuning.When.NIGHT],
			"" if wrong.is_empty() else ": " + "; ".join(wrong)])


## ---- the time-of-day dial ------------------------------------------------------------------

## A TIME-OF-DAY DIAL, PUT IN BY THE BUILDER'S OWN CALL, TURNS THE SKY -- AND THE BOARD TURNS IT.
##
## Two dials, put in with `PilotRig.add_control` as the parts bin does, the second then carried a metre and a half along
## the station where no hand is anywhere near it. The beam presses NIGHT on the TIME tab and both turn. The right hand
## takes hold of the near one and rolls it a stop, and the level, the board and one detent say EVENING. A wrist resting
## on the edge between two stops changes nothing, and let go it stays. Every frame of the hand is re-posed, as the beam's
## are: a forced hand is a world pose, and the craft the rig sits in is moved by the simulation.
func _a_time_of_day_dial_turns_the_sky_and_the_board_turns_it(level: FlightLevel) -> void:
	var rig: PilotRig = level.rig
	if rig == null:
		return
	var page: ClipboardPage = rig.clipboard.page()
	var station := rig.get("_my_station") as Node3D
	rig.add_control(&"TimeOfDayDial")
	rig.add_control(&"TimeOfDayDial")
	for i in range(3):
		await get_tree().process_frame
	var near := station.get_node_or_null("TimeOfDayDial") as TimeOfDayDial if station != null else null
	var far := station.get_node_or_null("TimeOfDayDial2") as TimeOfDayDial if station != null else null
	if near == null or far == null:
		_check("the_rig_puts_two_time_of_day_dials_in", false, "near %s, far %s, station %s" % [near, far, station])
		return
	far.position.x += 1.5
	_check("a_time_of_day_dial_put_in_shows_the_time_that_is_on",
		near.at_stop() == level.time_of_day() and far.at_stop() == level.time_of_day(),
		"level %s, the dials on %s and %s" % [DaylightTuning.name_of(level.time_of_day()), near.stop_name(),
			far.stop_name()])

	rig.clipboard.show_board(true)
	await get_tree().process_frame
	if page.tab() != ClipboardPage.Tab.TIME:
		await _beam_presses(rig, _button_reading(page, "TIME"))
	await _beam_presses(rig, _button_reading(page, "NIGHT"))
	var night: int = DaylightTuning.When.NIGHT
	_check("and_night_pressed_on_the_board_turns_both_dials_near_a_hand_or_not",
		level.time_of_day() == night and near.at_stop() == night and far.at_stop() == night,
		"level %s, near dial %s, far dial %s" % [DaylightTuning.name_of(level.time_of_day()), near.stop_name(),
			far.stop_name()])
	rig.clipboard.show_board(false)
	await get_tree().process_frame

	# THE RIGHT HAND, since the board is in the left. Taken hold of at NIGHT, so a roll of one stop's throw is EVENING and
	# the edge between EVENING and DAY is a stop and a half.
	#
	# PINCHED, NOT GRABBED, since 2026-09-15: a `DetentDial` answers `Bind.Take.PINCH` (`taken_by`), so the trigger takes
	# it and a closing fist does not. This suite forced a GRIP and went red on three checks with "held false" -- the hand
	# was never on the dial at all. It is the same change that moved `feel`'s latch section and rewrote `shared_controls`
	# and `clipboard`; `scenery` was the one nobody ran. See agents.md, "grab a joystick, pinch a switch".
	var per_stop: float = DetentDial.SWEEP / float(near.stops.size() - 1)
	var evening: int = DaylightTuning.When.EVENING
	rig.forget_pulses()
	rig.force_input(1, Bind.TRIGGER, 1.0)
	await _hold_the_dial(rig, near, 0.0, 3)
	var held: bool = near.is_held()
	await _hold_the_dial(rig, near, per_stop, 4)
	_check("and_a_hand_rolling_it_a_stop_makes_the_level_and_the_board_evening_with_one_click",
		held and level.time_of_day() == evening and page.time_shown() == evening
			and _time_button_pressed(page, "EVENING") and not _time_button_pressed(page, "NIGHT")
			and rig.pulses(&"detent") == 1,
		"held %s, level %s, board %s, %d click(s)" % [held, DaylightTuning.name_of(level.time_of_day()),
			DaylightTuning.name_of(page.time_shown()), rig.pulses(&"detent")])

	# A WRIST RESTING ON THE EDGE. Two degrees either side of halfway between EVENING and DAY, ten times over.
	var writes: int = level.daylight.writes
	var clicks: int = rig.pulses(&"detent")
	var edge: float = per_stop * 1.5
	for i in range(10):
		await _hold_the_dial(rig, near, edge - deg_to_rad(2.0), 1)
		await _hold_the_dial(rig, near, edge + deg_to_rad(2.0), 1)
	_check("and_a_wrist_resting_on_the_edge_between_two_stops_changes_nothing",
		level.daylight.writes == writes and rig.pulses(&"detent") == clicks and near.at_stop() == evening
			and level.time_of_day() == evening,
		"%d sky writes and %d clicks over ten wobbles of 2 degrees either side of the edge, on %s, level %s" % [
			level.daylight.writes - writes, rig.pulses(&"detent") - clicks, near.stop_name(),
			DaylightTuning.name_of(level.time_of_day())])

	await _hold_the_dial(rig, near, per_stop, 2)
	rig.force_input(1, Bind.TRIGGER, 0.0)
	await _hold_the_dial(rig, near, per_stop, 3)
	# AND NO LATCH TO UNDO. The grip latches -- a tap pins the hand to what it holds -- and this suite used to have to tap
	# a second time to get free of it. A PINCH never latches: any release is a full release, because a switch is something
	# you hold only until it is at the setting you want (agents.md, `Bind.Take`). So letting the trigger go is the whole
	# of it, and if the dial is still held after that, something is wrong rather than merely latched.
	_check("and_a_pinch_released_lets_the_dial_go_without_a_second_tap", not near.is_held(),
		"held %s one frame after the trigger was let go" % near.is_held())
	_check("and_let_go_it_stays_on_evening",
		not near.is_held() and near.at_stop() == evening and level.time_of_day() == evening,
		"held %s, on %s, level %s" % [near.is_held(), near.stop_name(), DaylightTuning.name_of(level.time_of_day())])
	rig.force_grip(1, -1.0)
	rig.force_hand(1, null)
	await get_tree().process_frame


## THE RIGHT HAND ON `dial`'s grip, rolled `roll` about its axis, put there afresh on each of `frames` frames.
func _hold_the_dial(rig: PilotRig, dial: VehicleControl, roll: float, frames: int) -> void:
	for i in range(frames):
		rig.force_hand(1, dial.global_transform * Transform3D(Basis(Vector3.UP, roll), dial._grab_point()))
		await get_tree().process_frame


## Whether the page's time button reading `text` is pressed, shown or not: the board is put away while a hand works the dial.
static func _time_button_pressed(page: ClipboardPage, text: String) -> bool:
	for node in page.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text:
			return button.button_pressed
	return false


## ONE PULL OF THE RIGHT TRIGGER with the right hand's beam on `target`: at rest, down, up again, and the hand put on
## the glass afresh before every frame of it.
func _beam_presses(rig: PilotRig, target: Control) -> void:
	if target == null:
		_check("there_is_a_button_to_point_at", false, "none on show")
		return
	for trigger in [0.0, 0.0, 1.0, 1.0, 0.0, 0.0]:
		_aim_the_right_hand_at(rig, target)
		rig.force_input(1, Bind.TRIGGER, trigger)
		await get_tree().process_frame
	rig.force_input(1, Bind.TRIGGER, null)
	rig.force_hand(1, null)
	await get_tree().process_frame


## The right hand thirty centimetres out along the glass's normal, looking at the middle of `target`.
func _aim_the_right_hand_at(rig: PilotRig, target: Control) -> void:
	var panel: TouchPanel = rig.clipboard.panel()
	var screen := panel.get("_screen") as SubViewport
	var centre: Vector2 = target.get_global_rect().get_center()
	var on_glass := Vector3((centre.x / float(screen.size.x) - 0.5) * panel.size.x,
		(0.5 - centre.y / float(screen.size.y)) * panel.size.y, 0.0)
	var aimed_at: Vector3 = panel.to_global(on_glass)
	var hand_at: Vector3 = aimed_at + panel.global_basis.z.normalized() * 0.30
	rig.force_hand(1, Transform3D(Basis.looking_at(aimed_at - hand_at, panel.global_basis.y.normalized()), hand_at))


## The visible button on the page that reads `text`, or null.
static func _button_reading(page: ClipboardPage, text: String) -> Button:
	for node in page.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree() and button.text == text:
			return button
	return null


## Every value the time of day writes, as one string, read off the light, the environment and the sky.
static func _the_sky_as_it_is(sun: DirectionalLight3D, air: Environment) -> String:
	# WHICHEVER SKY IS WORN: PLAIN's ProceduralSkyMaterial by its properties, FINE's cirrus sky by its shader parameters.
	var worn: Material = air.sky.sky_material if air.sky != null else null
	var colours: Array = []
	for field in ["sky_top_color", "sky_horizon_color", "ground_bottom_color", "ground_horizon_color"]:
		colours.append(worn.get(field) if worn is ProceduralSkyMaterial
			else ((worn as ShaderMaterial).get_shader_parameter(field) if worn is ShaderMaterial else null))
	return var_to_str([sun.global_basis, sun.light_color, sun.light_energy, air.ambient_light_source,
		air.ambient_light_color, air.ambient_light_energy, air.fog_light_color, air.fog_aerial_perspective] + colours)


static func _all_are(worn: Dictionary, fine: bool) -> bool:
	for surface in worn:
		if bool(worn[surface]) != fine:
			return false
	return not worn.is_empty()


## ---- the lights -------------------------------------------------------------------------

## RED ON THE LEFT AND GREEN ON THE RIGHT is the one thing about nav lights a pilot reads --
## it says which way a machine at night is crossing -- and swapping them is invisible to every
## check except one that asks which side each is on.
func _the_lights_are_where_an_aircraft_carries_them() -> void:
	# FROM A DRAWN AEROPLANE, as the game hangs them: the lights stand on the airframe it draws (VehicleLights.for_view).
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.setup(0, Sim.Kind.PLANE)
	var plane: Array[Dictionary] = view.lamps()
	var skin: PackedVector3Array = VehicleLights.skin_of(view)
	var drawn := AABB(skin[0] if not skin.is_empty() else Vector3.ZERO, Vector3.ZERO)
	for vertex in skin:
		drawn = drawn.expand(vertex)
	remove_child(view)
	view.free()
	var red_left: bool = false
	var green_right: bool = false
	# ON ITS DRAWN TIPS: at or past the outermost drawn point either side, within `VehicleLights.ON_SKIN`. Until 2026-09-17
	# this asked for them past the simulation's `span`, which is where the box-placed lights stood and not the wing.
	for light in plane:
		var at: Vector3 = light["position"]
		if light["colour"] == VehicleLights.RED and at.x <= drawn.position.x and at.x > drawn.position.x - VehicleLights.ON_SKIN:
			red_left = true
		if light["colour"] == VehicleLights.GREEN and at.x >= drawn.end.x and at.x < drawn.end.x + VehicleLights.ON_SKIN:
			green_right = true
	_check("an_aeroplane_is_red_on_the_left_and_green_on_the_right_on_its_drawn_wingtips",
		red_left and green_right, "%d lights, drawn from %.2f to %.2f m across" % [plane.size(), drawn.position.x, drawn.end.x])
	var kinds_lit: PackedStringArray = []
	for kind in range(Sim.Kind.size()):
		if VehicleLights.carries_lights(kind):
			kinds_lit.append(Sim.kind_name(kind))
	_check("and_nothing_that_drives_or_sails_carries_them",
		not kinds_lit.has(Sim.kind_name(Sim.Kind.CAR))
			and not kinds_lit.has(Sim.kind_name(Sim.Kind.BOAT))
			and kinds_lit.has(Sim.kind_name(Sim.Kind.HELI))
			and kinds_lit.has(Sim.kind_name(Sim.Kind.CHINOOK)),
		"lit: %s" % ", ".join(kinds_lit))

	# THE PAPI'S INNERMOST LIGHT IS SET HIGHEST, which is what makes "two red, two white" mean
	# on the glidepath rather than the opposite. Checked as an order, since the numbers are
	# a table anybody may retune.
	var papi: Array[float] = []
	var nearest: Array[float] = []
	var centre: Vector3 = Terrain.RUNWAY_AT
	for light in Terrain.runway_lights():
		if int(light.get("pattern", 0)) == VehicleLights.Pattern.PAPI:
			papi.append(float(light["papi"]))
			nearest.append(absf(((light["position"] as Vector3) - centre).dot(
				Terrain.runway_axis()["across"] as Vector3)))
	var ordered: bool = papi.size() == 4
	for i in range(1, papi.size()):
		ordered = ordered and nearest[i] > nearest[i - 1] and papi[i] < papi[i - 1]
	_check("the_papi_is_four_lights_set_highest_nearest_the_runway", ordered,
		"angles %s at %s m from the centreline" % [papi, nearest])

	# AND THE FINISH REACHES THEM. One material for every set of lights in the world, so this
	# is the whole of it: press the key, and the shader on that material is the other one.
	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	var paint: ShaderMaterial = VehicleLights.paint()
	# EVERY LIGHT'S NUMBERS COME FROM ONE PLACE: set on the material from `VehicleLights`, read back off it. A number
	# typed into the shader's uniform default instead leaves the material's own parameter unset, which reads back null
	# here -- and the aircraft and the runway are different materials, so neither can take the other's size.
	var runway: ShaderMaterial = VehicleLights.runway_paint()
	var fine_now: bool = Finish.is_fine()
	_check("the_aircraft_lights_are_sized_and_edged_by_vehicle_lights",
		paint.get_shader_parameter("size_scale") == VehicleLights.AIRCRAFT_SIZE
			and paint.get_shader_parameter("least_scale") == VehicleLights.AIRCRAFT_LEAST
			and paint.get_shader_parameter("fine_core") == VehicleLights.AIRCRAFT_FINE_CORE
			and paint.get_shader_parameter("rim_dither") == (VehicleLights.AIRCRAFT_RIM_FINE if fine_now
				else VehicleLights.AIRCRAFT_RIM_PLAIN),
		"size %s least %s rim %s" % [paint.get_shader_parameter("size_scale"),
			paint.get_shader_parameter("least_scale"), paint.get_shader_parameter("rim_dither")])
	_check("and_the_runway_keeps_its_own_size_and_brightness",
		runway != paint and runway.get_shader_parameter("size_scale") == VehicleLights.RUNWAY_SIZE
			and runway.get_shader_parameter("least_scale") == VehicleLights.RUNWAY_SIZE
			and runway.get_shader_parameter("fine_core") == VehicleLights.RUNWAY_FINE_CORE
			and runway.get_shader_parameter("daylight") == 1.0 and runway.get_shader_parameter("rim_dither") == 0.0,
		"size %s least %s daylight %s rim %s" % [runway.get_shader_parameter("size_scale"),
			runway.get_shader_parameter("least_scale"), runway.get_shader_parameter("daylight"),
			runway.get_shader_parameter("rim_dither")])
	var before: Shader = paint.shader
	_check("the_lights_wear_the_finish_that_is_on",
		before == (VehicleLights.FINE if Finish.is_fine() else VehicleLights.PLAIN),
		"%s on %s" % [before.resource_path, SceneryFinish.name_of(Finish.is_fine())])
	await _press_the_key()
	_check("and_the_key_changes_their_shader", paint.shader != before
		and paint.shader == (VehicleLights.FINE if Finish.is_fine() else VehicleLights.PLAIN),
		"%s after" % paint.shader.resource_path)
	await _press_the_key()
	rig.queue_free()
	await get_tree().process_frame


## ---- the controls ---------------------------------------------------------------------

func _the_key_on_the_desk_chooses_it() -> void:
	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame

	var row: Dictionary = {}
	for one in PilotRig.desk_keys():
		if String(one["action"]) == SceneryFinish.ACTION:
			row = one
	_check("the_desk_has_a_key_for_the_finish", not row.is_empty()
		and not String(row.get("does", "")).is_empty(),
		"%s" % [row if not row.is_empty() else "no row for %s in desk_keys" % SceneryFinish.ACTION])

	var heard: Array = []
	var listen := func(fine: bool): heard.append(fine)
	Finish.changed.connect(listen)
	var before: bool = Finish.is_fine()
	await _press_the_key()
	_check("and_pressing_it_changes_the_finish", Finish.is_fine() != before,
		"%s before, %s after" % [SceneryFinish.name_of(before), SceneryFinish.name_of(Finish.is_fine())])
	_check("and_says_so_once", heard == [not before], "heard %s" % [heard])
	# AND THE SAMPLES FOLLOW IT, read back off the viewport that is actually drawn.
	_check("and_the_multisampling_follows_it", get_tree().root.msaa_3d
			== (SceneryFinish.FINE_MSAA if Finish.is_fine() else SceneryFinish.PLAIN_MSAA),
		"msaa_3d %d on %s" % [get_tree().root.msaa_3d, SceneryFinish.name_of(Finish.is_fine())])
	var board := _fine_switch(rig)
	_check("and_the_board_shows_what_the_key_chose",
		board != null and board.button_pressed == Finish.is_fine(),
		"switch %s, finish %s" % [board.button_pressed if board != null else "missing",
			SceneryFinish.name_of(Finish.is_fine())])
	await _press_the_key()
	_check("and_pressing_it_again_puts_it_back", Finish.is_fine() == before
		and heard == [not before, before], "heard %s" % [heard])
	Finish.changed.disconnect(listen)
	rig.queue_free()
	await get_tree().process_frame


func _the_switch_on_the_board_chooses_it() -> void:
	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	rig.clipboard.show_board(true)
	await get_tree().process_frame
	var board := _fine_switch(rig)
	_check("the_board_has_a_fine_scenery_switch", board != null,
		"a CheckButton reading FINE SCENERY")
	if board == null:
		rig.queue_free()
		return
	var before: bool = Finish.is_fine()
	# THE SWITCH, FLICKED. Setting `button_pressed` is what a click does to a CheckButton and
	# it emits `toggled`, which is the signal the page announces on.
	board.button_pressed = not before
	await get_tree().process_frame
	_check("and_flicking_it_changes_the_finish", Finish.is_fine() != before,
		"%s after" % SceneryFinish.name_of(Finish.is_fine()))
	board.button_pressed = before
	await get_tree().process_frame
	_check("and_flicking_it_back_restores_it", Finish.is_fine() == before,
		"%s after" % SceneryFinish.name_of(Finish.is_fine()))
	rig.queue_free()
	await get_tree().process_frame


## THE KEY THE ACTION IS BOUND TO, pressed and let go. Read off the InputMap rather than
## typed here, so a key moved in `DESK_KEYS` moves this test's finger with it -- and with
## both codes set, which is the form a real keyboard delivers.
func _press_the_key() -> void:
	var code: Key = KEY_NONE
	for event in InputMap.action_get_events(SceneryFinish.ACTION):
		var key := event as InputEventKey
		if key != null:
			code = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if code == KEY_NONE:
		_check("the_finish_action_is_bound_to_a_key", false, "nothing bound")
		return
	for down in [true, false]:
		var press := InputEventKey.new()
		press.keycode = code
		press.physical_keycode = code
		press.pressed = down
		Input.parse_input_event(press)
		await get_tree().process_frame


func _fine_switch(rig: PilotRig) -> CheckButton:
	var page: ClipboardPage = rig.clipboard.page()
	if page == null:
		return null
	for node in page.find_children("*", "CheckButton", true, false):
		if String((node as CheckButton).text) == "FINE SCENERY":
			return node as CheckButton
	return null


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
