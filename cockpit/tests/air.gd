extends Node
## Headless: is the air moving, does it hold a glider up, and can you see where it does?
##
##   Godot --headless --path cockpit res://tests/air.tscn
##
## THE AIR IS THE LEAST VISIBLE THING IN THIS GAME AND THE HARDEST TO ARGUE ABOUT. Wind is a
## drift you only notice by comparing where you pointed with where you went; a thermal is a
## number that does not exist until an aeroplane is inside it. Neither can be judged from a
## screenshot, and both are worth measuring against the back of an envelope: a glider sinks
## at a metre and a half a second, so a three-metre thermal is a metre-and-a-half climb, and
## anything else means one of the two numbers is wrong.
##
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
const GLIDER: int = 17
const PLANE: int = 1
const CAR: int = 3

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[air] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_the_wind_is_a_field_and_not_a_force()
	await _an_aeroplane_flies_in_the_air_and_not_over_the_ground()
	await _a_glider_sinks_and_a_thermal_holds_it_up()
	await _and_a_fire_makes_its_own()
	_the_sky_is_marked_where_the_lift_is()
	_every_cloud_has_one_base_and_a_shape_of_its_own()
	_the_islands_clouds_are_not_one_family()
	_no_cloud_spreads_past_its_thermal()
	_every_fog_cloud_stands_where_its_lumps_do()
	_every_cloud_is_lit_through_its_own_envelope()
	_every_clouds_edge_is_a_falloff_and_not_a_stipple()
	await _a_cloud_near_the_eye_is_fog_and_its_lumps_give_way()
	await _the_eye_in_a_cloud_is_whited_out_and_the_markers_go()
	await _a_level_with_no_fog_asked_for_builds_none_and_whites_out_on_both_finishes()
	_finish()


## ---- the wind ---------------------------------------------------------------------------

## THE WIND IS A PROPERTY OF THE AIR AT A PLACE, not a force on anything.
##
## Which is why it is asked for by height and not by vehicle: it is stronger higher up, and
## that shear is the one thing about wind a pilot has to fly around. It is also why it is not
## replicated -- see `wind_at`. Every peer is told the same two numbers when the world is
## built and nothing changes them.
func _the_wind_is_a_field_and_not_a_force() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.start(0)
	_check("a_world_with_no_weather_has_still_air",
		(world.wind(0.0) as Vector3).length() < 0.001
			and (world.wind(1000.0) as Vector3).length() < 0.001,
		"%v at the surface" % world.wind(0.0))
	world.set_wind(Vector3(6.0, 0.0, 0.0), 0.5)
	var surface: Vector3 = world.wind(0.0)
	var aloft: Vector3 = world.wind(1000.0)
	_check("the_wind_is_what_it_was_set_to", absf(surface.x - 6.0) < 0.01,
		"%.1f m/s at the surface" % surface.x)
	_check("and_there_is_half_as_much_again_a_kilometre_up",
		absf(aloft.x - 9.0) < 0.05, "%.1f m/s at 1000 m" % aloft.x)
	# AND IT IS HORIZONTAL. A wind with a vertical component would be a thermal that covered
	# the whole world, which is a thing gliders would enjoy and aeroplanes would not.
	_check("and_none_of_it_is_upwards", absf(aloft.y) < 0.001,
		"%.3f m/s of vertical" % aloft.y)
	# THE LIFT ZONES ARE THE OTHER HALF, and they are asked for at a POINT because that is
	# what a thermal is: somewhere in particular, with an edge.
	world.add_lift_zone(Vector3(0.0, 0.0, 0.0), 200.0, 4.0, 1000.0)
	_check("a_thermal_is_strongest_in_its_core",
		absf(float(world.rising(Vector3(0.0, 200.0, 0.0))) - 4.0) < 0.1,
		"%.1f m/s in the middle" % world.rising(Vector3(0.0, 200.0, 0.0)))
	_check("and_weaker_towards_the_edge",
		float(world.rising(Vector3(140.0, 200.0, 0.0))) > 0.2
			and float(world.rising(Vector3(140.0, 200.0, 0.0))) < 2.0,
		"%.1f m/s at 140 m out of 200" % world.rising(Vector3(140.0, 200.0, 0.0)))
	_check("and_nothing_outside_it",
		float(world.rising(Vector3(260.0, 200.0, 0.0))) < 0.001,
		"%.2f m/s at 260 m out" % world.rising(Vector3(260.0, 200.0, 0.0)))
	# AND A TOP, which is what a cloudbase is: the height the climb stops. A column with a
	# hard ceiling would be one you hit; this one fades out over its last hundred and fifty
	# metres, so the top of a thermal is a place you stop climbing.
	_check("and_a_top_that_fades_rather_than_a_ceiling_you_hit",
		float(world.rising(Vector3(0.0, 940.0, 0.0))) < 2.5
			and float(world.rising(Vector3(0.0, 940.0, 0.0))) > 0.5
			and float(world.rising(Vector3(0.0, 1010.0, 0.0))) < 0.001,
		"%.1f m/s just under the top, %.2f just over" % [
			world.rising(Vector3(0.0, 940.0, 0.0)),
			world.rising(Vector3(0.0, 1010.0, 0.0))])
	world.teardown()


## AN AEROPLANE FLIES IN THE AIR, AND THE AIR IS GOING SOMEWHERE.
##
## The sharpest statement of it: an aeroplane doing ten metres a second over the ground in a
## ten-metre tailwind has NO AIRSPEED AT ALL. It is a brick. And the same aeroplane doing ten
## metres a second in still air is flying, a little. If the two fall at the same rate then
## the wind is a real force on the aircraft, which is wrong -- a uniform wind is a change of
## reference frame, and an aeroplane moving WITH the air cannot tell it from being parked in
## still air.
##
## So: three aeroplanes, all dropped with the engine off and left alone for three seconds.
##
## AND NOT A CAR. A crosswind on a lorry is a model this game does not have, and handing the
## air to something whose drag is against the ground would put a headwind into its rolling
## resistance -- which is not what a headwind does to a car.
func _an_aeroplane_flies_in_the_air_and_not_over_the_ground() -> void:
	# ALL THREE ALONG THE NOSE, which is -Z. A wing lifts from air coming at it head on and
	# not from air coming at it sideways, so an aeroplane going forty metres a second
	# SIDEWAYS falls exactly as fast as a parked one -- correct, and not the thing being
	# measured here.
	var becalmed: float = await _how_far_does_it_fall(Vector3(0.0, 0.0, -10.0),
		Vector3(0.0, 0.0, -10.0))
	var parked: float = await _how_far_does_it_fall(Vector3.ZERO, Vector3.ZERO)
	# AND ONE WITH REAL AIRSPEED. Forty metres a second rather than ten, because ten is
	# nothing to a wing whose stall is twenty-three: an aeroplane falling at ten with ten
	# knots across it is stalled either way, and what that measures is the drag.
	var moving: float = await _how_far_does_it_fall(Vector3.ZERO, Vector3(0.0, 0.0, -40.0))
	_check("an_aeroplane_moving_with_the_air_is_an_aeroplane_standing_still",
		absf(becalmed - parked) < 1.0,
		"it fell %.1f m going downwind at the speed of the wind, and %.1f m parked in still air"
			% [becalmed, parked])
	_check("and_an_aeroplane_with_airspeed_is_an_aeroplane_that_is_flying",
		moving < parked - 3.0,
		"it fell %.1f m with forty metres a second of airspeed against %.1f m with none"
			% [moving, parked])

	# AND THE GROUND GOES PAST AT A DIFFERENT RATE EITHER WAY. Two identical aeroplanes at
	# one throttle, one flying upwind and one down: the same airspeed, and twice the wind
	# between them over the ground. This is the number a pilot actually notices.
	var downwind: Dictionary = await _fly_one_leg(Vector3(10.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 0.0))
	var upwind: Dictionary = await _fly_one_leg(Vector3(10.0, 0.0, 0.0),
		Vector3(-1.0, 0.0, 0.0))
	_check("two_aeroplanes_at_one_throttle_fly_at_one_airspeed",
		absf(float(downwind["airspeed"]) - float(upwind["airspeed"])) < 1.5,
		"%.1f m/s downwind against %.1f up" % [downwind["airspeed"], upwind["airspeed"]])
	_check("and_cross_the_ground_twice_the_wind_apart",
		absf(float(downwind["over_ground"]) - float(upwind["over_ground"]) - 20.0) < 2.0,
		"%.1f m/s over the ground downwind against %.1f up, wanted 20 between them" % [
			downwind["over_ground"], upwind["over_ground"]])
	# AND THE NOSE FINDS THE AIR. The fin is what does it, and it is the reason an aeroplane
	# with nobody in it is not simply blown sideways: left alone it ends up pointing into the
	# relative wind and flying a crab, which is what a real one does.
	# STARTED WITHOUT THE CRAB, which is the interesting case: an aeroplane that has just
	# been put into a crosswind, flying along its own nose over the ground and therefore
	# sideways through the air.
	var across: Dictionary = await _fly_one_leg(Vector3(10.0, 0.0, 0.0),
		Vector3(0.0, 0.0, -1.0), false)
	_check("and_an_aeroplane_left_alone_turns_its_nose_into_a_crosswind",
		absf(float(across["heading_change"])) > 2.0
			and absf(float(across["heading_change"])) < 25.0,
		"the nose came round %.1f degrees" % across["heading_change"])

	# AND THE SAME WIND OVER A CAR DOES NOTHING AT ALL.
	var road: Object = ClassDB.instantiate("CockpitWorld")
	road.set_tick_rate(120.0)
	road.start(0)
	road.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(7200.0, 400.0, 7200.0))
	road.set_wind(Vector3(20.0, 0.0, 0.0), 0.0)
	var car: int = int(road.spawn_vehicle(CAR, Vector3(0.0, 0.7, 0.0), 0.0, Vector3.ZERO))
	for i in range(int(8.0 / TICK)):
		road.tick(TICK)
	var stayed: Vector3 = (road.vehicle_state(car) as Dictionary).get("position",
		Vector3.ZERO)
	_check("and_a_parked_car_is_not_blown_down_the_road", absf(stayed.x) < 1.0,
		"%.2f m in eight seconds of a twenty-metre-a-second gale" % stayed.x)
	road.teardown()
	await get_tree().process_frame


## HOW FAR ONE AEROPLANE FALLS in three seconds, dropped with the engine off into a given
## wind at a given velocity over the ground. Three seconds, because what is being measured is
## whether the wing is working at all -- not where the aeroplane ends up.
func _how_far_does_it_fall(wind: Vector3, going: Vector3) -> float:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.set_wind(wind, 0.0)
	var craft: int = int(world.spawn_vehicle(PLANE, Vector3(0.0, 900.0, 0.0), 0.0, going))
	for i in range(int(3.0 / TICK)):
		world.tick(TICK)
	var fell: float = 900.0 - float((world.vehicle_state(craft) as Dictionary)
		.get("position", Vector3.ZERO).y)
	world.teardown()
	await get_tree().process_frame
	return fell


## ONE AEROPLANE, ONE SHORT LEG, IN A GIVEN WIND, pointed along `nose`. Comes back with the
## airspeed it settled at, its speed over the ground, and how far the nose came round on its
## own -- which for a leg across the wind is the whole question.
##
## FOUR SECONDS AND NO MORE. An aeroplane nobody is flying goes and does something of its
## own within ten, and a measurement taken through that is measuring the pitch stability.
func _fly_one_leg(wind: Vector3, nose: Vector3, trimmed: bool = true) -> Dictionary:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(7200.0, 400.0, 7200.0))
	world.set_wind(wind, 0.0)
	# The yaw convention is the game's: a nose is (-sin, 0, -cos) of it.
	var facing: Vector3 = nose.normalized()
	var yaw: float = atan2(-facing.x, -facing.z)
	# SPAWNED ALREADY CRABBING unless asked otherwise: seventy metres a second of AIRSPEED
	# along the nose, which over the ground is that plus the wind. An aeroplane put into the
	# air with seventy over the GROUND in a wind is one that starts out sideslipping, which
	# is a different measurement and the one the crosswind check wants.
	var made: Dictionary = world.spawn_pilot(60, PLANE, Vector3(0.0, 600.0, 0.0), yaw,
		facing * 70.0 + (wind if trimmed else Vector3.ZERO))
	var craft: int = int(made.get("vehicle", 0))
	var pilot: int = int(made.get("pilot", 0))
	world.set_pilot_input(pilot, {"throttle": 0.35})
	for i in range(int(4.0 / TICK)):
		world.tick(TICK)
	var state: Dictionary = world.vehicle_state(craft)
	var travel: Vector3 = state.get("velocity", Vector3.ZERO)
	var pointing: Vector3 = Basis(state.get("basis", Quaternion()) as Quaternion) \
		* Vector3.FORWARD
	world.teardown()
	await get_tree().process_frame
	# ALONG THE WIND'S OWN AXIS, and not the magnitude of the velocity. An aeroplane settling
	# into trim is also climbing or sinking a little, and a speed that includes that vertical
	# is a speed with something in it that has nothing to do with the wind.
	var axis: Vector3 = wind.normalized()
	return {
		"over_ground": absf(travel.dot(axis)),
		"airspeed": absf((travel - wind).dot(axis)),
		"heading_change": rad_to_deg(angle_difference(yaw,
			atan2(-pointing.x, -pointing.z))),
	}


## ---- and the thing it is all for ---------------------------------------------------------

## A GLIDER SINKS, AND A THERMAL HOLDS IT UP.
##
## Two runs of the same aeroplane over the same ground, differing in one thing: whether there
## is a column of rising air where it is flying. The first is the number the aircraft is
## designed around -- about a metre and a half a second of sink at its best glide -- and the
## second is what four metres a second of lift does about it.
##
## Nobody is flying either. A glider left alone holds its attitude and sinks, which is what
## makes the sink rate a property of the aeroplane rather than of the pilot.
func _a_glider_sinks_and_a_thermal_holds_it_up() -> void:
	var still: float = await _how_fast_does_it_sink(0.0)
	var lifted: float = await _how_fast_does_it_sink(4.0)
	_check("a_glider_sinks_in_still_air", still < -0.6 and still > -3.0,
		"%.2f m/s" % still)
	_check("and_climbs_in_a_thermal_that_goes_up_faster_than_it_comes_down",
		lifted > 0.5, "%.2f m/s in a four-metre thermal" % lifted)
	# AND THE DIFFERENCE IS THE THERMAL. Not "it climbs" -- an aeroplane can climb for all
	# sorts of reasons, including being pointed upwards -- but that the CHANGE is about what
	# the air is doing. Four metres of lift, and the aircraft is four metres a second better
	# off than it was.
	_check("and_the_difference_between_them_is_the_air",
		absf((lifted - still) - 4.0) < 1.2,
		"%.2f m/s better off in a four-metre thermal" % (lifted - still))


## HOW FAST A GLIDER GOES UP OR DOWN, averaged over a long enough run to mean something, with
## a column of `strength` under it. Positive is a climb.
func _how_fast_does_it_sink(strength: float) -> float:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(7200.0, 400.0, 7200.0))
	if strength > 0.0:
		# Wide, so that an aeroplane flying straight stays inside it for the whole run: what
		# is being measured here is the climb, not the gunner's-eye accuracy of circling.
		world.add_lift_zone(Vector3(0.0, 0.0, -600.0), 1500.0, strength, 2000.0)
	var made: Dictionary = world.spawn_pilot(61, GLIDER, Vector3(0.0, 600.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -33.0))
	var craft: int = int(made.get("vehicle", 0))
	# SETTLE FIRST. An aeroplane put into the air at an arbitrary attitude spends the first
	# few seconds finding its own trim, and a sink rate measured through that is measuring
	# the pitch stability.
	for i in range(int(6.0 / TICK)):
		world.tick(TICK)
	var was: float = float((world.vehicle_state(craft) as Dictionary).get("position",
		Vector3.ZERO).y)
	for i in range(int(20.0 / TICK)):
		world.tick(TICK)
	var now: float = float((world.vehicle_state(craft) as Dictionary).get("position",
		Vector3.ZERO).y)
	world.teardown()
	await get_tree().process_frame
	return (now - was) / 20.0


## AND A FIRE MAKES ITS OWN, which is the two features meeting.
##
## A fire is a column of hot air with a flame at the bottom of it. The smoke standing over it
## is the best-marked thermal in the world, and a glider can work one -- which also means a
## water bomber has to fly a drop run through rising air, and that is a thing to know before
## it surprises somebody at fifty feet.
func _and_a_fire_makes_its_own() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	var quiet: float = float(world.rising(Vector3(0.0, 200.0, 0.0)))
	var fire: int = int(world.light_fire(Vector3(0.0, 0.0, 0.0), 1.0))
	world.tick(TICK)
	var over_it: float = float(world.rising(Vector3(0.0, 200.0, 0.0)))
	var beside_it: float = float(world.rising(Vector3(400.0, 200.0, 0.0)))
	_check("still_air_over_an_unlit_hillside", absf(quiet) < 0.001, "%.2f m/s" % quiet)
	_check("and_a_column_of_it_over_a_fire", over_it > 3.0,
		"%.1f m/s over a fire at full strength" % over_it)
	_check("and_none_of_it_four_hundred_metres_away", absf(beside_it) < 0.001,
		"%.2f m/s" % beside_it)
	# AND IT GOES WITH THE FIRE. A fire that is half out makes half the lift, which is what
	# makes this the same number the smoke column is drawn from rather than a second one.
	_check("and_it_dies_down_with_the_fire", fire != 0, "fire %d" % fire)
	world.teardown()


## ---- and seeing it ------------------------------------------------------------------------

## THE SKY IS THE MAP.
##
## Rising air is invisible, and a game where it is invisible is one where a glider pilot
## flies in circles hoping. Real pilots read the sky: a thermal grows a CUMULUS on top of
## itself and that cloud is a sign saying "lift, here, up to about this height".
##
## So the thing to check is that there is exactly one marker per zone and that it is drawn
## where the lift actually is -- a cloud over air that is not going up is worse than no cloud
## at all, because somebody will fly to it.
func _the_sky_is_marked_where_the_lift_is() -> void:
	var zones: Array[Dictionary] = Terrain.lift_zones()
	_check("the_island_has_lift_on_it", zones.size() >= 10,
		"%d columns of rising air" % zones.size())
	var yard := LiftYard.new()
	add_child(yard)
	yard.show_lift(zones, Terrain.WIND)
	_check("and_every_column_is_marked_in_the_sky", yard.columns() == zones.size(),
		"%d markers for %d columns" % [yard.columns(), zones.size()])

	# AND THE WISPS CAN BE FADED ONE AT A TIME, which is a check on a SETTING and not on a
	# picture, because getting it wrong is silent and this is the only place it shows.
	#
	# A wisp is brightest in the middle of its climb and goes out at the top -- that is what
	# makes a column read as rising air rather than as a string of beads -- and every one of
	# them is an instance in one MultiMesh, so the fade is `set_instance_color`. A MultiMesh
	# refuses to start carrying colours once it has instances in it, and `use_colors` was
	# being set AFTER `instance_count`. The call failed, every fade after it failed, and the
	# whole effect had never worked: two million lines of "Can't set instance color on a
	# Multimesh that isn't using colors" on a stream nothing read, and a sky full of beads.
	var wisps: MultiMesh = yard._wisps.multimesh
	_check("and_a_wisp_can_be_faded_on_its_own", wisps.use_colors
		and wisps.instance_count == zones.size() * LiftYard.WISPS,
		"colours %s across %d instances" % [wisps.use_colors, wisps.instance_count])
	# AND A WISP IS A MARK FOR SOMEBODY NEAR THE COLUMN, NOT A DISC OVER THE WHOLE ISLAND: whole close to, gone far off,
	# asked of the one function the per-frame fade is written through. And it is HIDDEN BEHIND A MOUNTAIN: transparent and
	# unshaded, it still tests depth against the rock, so a wisp drawn in front of a peak is a wisp in front of it.
	var near: float = LiftYard.wisp_alpha(0.5, LiftYard.WISP_SEEN.x * 0.5)
	var far: float = LiftYard.wisp_alpha(0.5, LiftYard.WISP_SEEN.y + 100.0)
	_check("and_a_wisp_is_whole_near_its_column_and_gone_far_off", is_equal_approx(near, 1.0) and far < 0.001,
		"%.3f at %.0f m, %.3f at %.0f m" % [near, LiftYard.WISP_SEEN.x * 0.5, far, LiftYard.WISP_SEEN.y + 100.0])
	var paint := yard._wisps.material_override as ShaderMaterial
	var code: String = paint.shader.code if paint != null and paint.shader != null else ""
	_check("and_a_wisp_behind_a_mountain_is_hidden_by_it", paint != null and code.length() > 0
		and not code.contains("depth_test_disabled") and paint.render_priority == 0,
		"shader %s, depth test %s, render_priority %s" % [paint.shader.resource_path if paint != null else null,
			"off" if code.contains("depth_test_disabled") else "on", paint.render_priority if paint != null else null])
	# AND ONE TOO FAR OFF TO SEE IS NOT DRAWN AT ALL: asked of the batch after a frame, from a real camera -- first two
	# hundred kilometres above the island, where every wisp is past the fade, then standing in the first column.
	var eye := Camera3D.new()
	add_child(eye)
	eye.current = true
	eye.global_position = Vector3(0.0, 200000.0, 0.0)
	yard._process(0.0)
	var drawn_far: int = wisps.visible_instance_count
	eye.global_position = (zones[0]["position"] as Vector3) + Vector3(0.0, 50.0, 0.0)
	yard._process(0.0)
	var drawn_near: int = wisps.visible_instance_count
	_check("and_a_wisp_too_far_off_to_see_is_not_drawn", drawn_far == 0 and drawn_near > 0,
		"%d of %d drawn from 200 km up, %d from inside the first column" % [drawn_far, wisps.instance_count, drawn_near])
	eye.queue_free()
	# THE COLOURS THEMSELVES CANNOT BE READ BACK IN HERE. Headless has a dummy rendering
	# server, so `get_instance_color` answers white whatever was written to it -- which is
	# why this checks the SETTING rather than the result. What checks the result is the
	# error gate in run_all.sh: with `use_colors` off, every fade in `_process` prints
	# "Can't set instance color on a Multimesh that isn't using colors", and a suite that
	# prints engine errors now fails whatever its own checks said.

	# AND THE MARKERS ARE WHERE THE SIMULATION'S LIFT IS. One table feeds the air and the
	# picture -- exactly as one list of boxes feeds the collision and the mountains -- so
	# this asks the simulation what the air is doing under each cloud it drew.
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.start(0)
	world.set_wind(Terrain.WIND, Terrain.WIND_SHEAR)
	for zone in zones:
		world.add_lift_zone(zone["position"], float(zone["radius"]),
			float(zone["strength"]), float(zone["top"]))
	var dry: Array[String] = []
	for zone in zones:
		var at: Vector3 = zone["position"]
		var half: float = float(zone["top"]) * 0.5
		if float(world.rising(Vector3(at.x, half, at.z))) < 1.0:
			dry.append("%v" % at)
	_check("and_there_is_lift_under_every_one_of_them", dry.is_empty(),
		"%s" % ["all of them" if dry.is_empty() else dry.slice(0, 3)])
	# AND THE RIDGE IS ON THE WINDWARD SIDE, OR NOWHERE. Ridge lift is air pushed UP a slope
	# by the wind, so it stands on the side of the ring the wind blows into and there is
	# nothing on the lee. With no wind at all -- `Terrain.WIND`, since 2026-09-14 -- nothing
	# pushes air up any slope, so there is no ridge lift anywhere.
	var into: Vector3 = -Terrain.WIND.normalized()
	var ridges: int = 0
	var wrong_side: int = 0
	for zone in zones:
		var at: Vector3 = zone["position"]
		if float(zone["top"]) > Terrain.RIDGE_TOP + 1.0:
			continue
		ridges += 1
		if at.normalized().dot(into) < 0.2:
			wrong_side += 1
	if Terrain.WIND.length() < 0.01:
		_check("and_in_still_air_no_ridge_gives_lift", ridges == 0,
			"%d ridge zones with no wind to make them" % ridges)
	else:
		_check("and_the_ridge_lift_is_on_the_side_the_wind_blows_into", wrong_side == 0,
			"%d ridge zones in the lee" % wrong_side)
	world.teardown()
	yard.queue_free()


## A CUMULUS HAS ONE FLAT BASE, AND NO TWO ARE THE SAME HEAP.
##
## The base is the height the air stopped holding its water, which is the top of the lift zone -- so every lump of a
## cloud is held to the ZONE's top, read off `Terrain.lift_zones()`, never to anything `cloud_lumps` worked out. And
## every lump that is not a tower must dip below it, or the shader has nothing to cut level and the cloud is a row of
## balls sat on a line. The first fine cloud cut each lump at its own bottom: nine bases at nine heights.
##
## No two alike, because the sky before this was one nine-lump layout stamped over thirty-one zones -- every ridge
## cloud the same shape at the same size. A cloud's shape is its lumps' sizes against its zone's radius, sorted.
func _every_cloud_has_one_base_and_a_shape_of_its_own() -> void:
	var zones: Array[Dictionary] = Terrain.lift_zones()
	var off_the_base: Array[String] = []
	var hanging: int = 0
	var shapes: Dictionary = {}
	var repeats: int = 0
	var narrowest: float = INF
	for zone in zones:
		var top: float = float(zone["top"])
		var lumps: Array[Dictionary] = LiftYard.cloud_lumps(zone, Terrain.WIND)
		var sizes: Array[float] = []
		var towers: int = 0
		for piece in lumps:
			var custom: Color = piece["custom"]
			if absf(custom.r - top) > 0.01:
				off_the_base.append("%.1f against %.1f" % [custom.r, top])
			var shape: Transform3D = piece["transform"]
			var bottom: float = shape.origin.y - shape.basis.y.length() * 0.5
			if bottom > top + 0.01:
				towers += 1
			sizes.append(shape.basis.x.length() / float(zone["radius"]))
		# Towers, crown bumps and shreds torn from a tower's top stand above the base by design; no more than the most any
		# kind in `CloudTuning.TYPES` has (`CloudTuning.most_aloft`) may miss it, so every other lump reaches down to be cut level.
		if towers > CloudTuning.most_aloft():
			hanging += 1
		sizes.sort()
		narrowest = minf(narrowest, sizes[-1] / maxf(sizes[0], 0.0001))
		var key: String = ",".join(PackedStringArray(sizes.map(func(s: float): return "%.2f" % s)))
		if shapes.has(key):
			repeats += 1
		shapes[key] = true
	_check("and_every_lump_of_a_cloud_stands_on_its_zones_top", off_the_base.is_empty() and hanging == 0,
		"%d lumps off the base %s, %d clouds with lumps hanging above it" % [off_the_base.size(),
			off_the_base.slice(0, 3), hanging])
	_check("and_no_two_clouds_are_the_same_heap", repeats == 0 and narrowest >= 2.0,
		"%d repeated layouts in %d clouds; the most even cloud's biggest lump is %.2f times its smallest"
			% [repeats, zones.size(), narrowest])


## THE ISLAND'S CLOUDS ARE NOT ONE FAMILY. Asked for on 2026-09-14: "can you make the shapes different cloud to cloud" --
## every cloud had its own seed and still read as stacked round domes of one proportion. Measured on the laid-out lumps,
## never on seeds or types: for every cloud its height over its widest plan extent, and how much longer it is than wide in
## plan (the longest extent over the extent across it, among eight headings). Each cloud falls in a class -- TALL (height at
## least `TALL_RATIO` of its width), FLAT (at most `FLAT_RATIO`), LONG (elongated at least `LONG_RATIO`) or HEAP -- and the
## island must have a spread of height to width and most of those classes in it. How many lumps have broken away (not
## joined to the body that holds the biggest lump through lumps closer than their radii) is printed beside, and not a class:
## today's heaps already scatter one to seven small puffs clear of their body, and the first two measures that classed it
## called thirteen and then sixteen of twenty heaps ragged.
const TALL_RATIO: float = 0.75
const FLAT_RATIO: float = 0.30
const LONG_RATIO: float = 1.8
const RATIO_SPREAD_LEAST: float = 0.15
const CLASSES_LEAST: int = 4


func _the_islands_clouds_are_not_one_family() -> void:
	var zones: Array[Dictionary] = Terrain.lift_zones()
	var ratios: Array[float] = []
	var classes: Dictionary = {}
	var lines: PackedStringArray = []
	for zone in zones:
		var lumps: Array[Dictionary] = LiftYard.cloud_lumps(zone, Terrain.WIND)
		var shape: Dictionary = cloud_shape_measured(lumps, float(zone["top"]))
		var ratio: float = shape["height_over_width"]
		ratios.append(ratio)
		var named: String = "HEAP"
		if ratio >= TALL_RATIO:
			named = "TALL"
		elif ratio <= FLAT_RATIO:
			named = "FLAT"
		elif float(shape["elongation"]) >= LONG_RATIO:
			named = "LONG"
		classes[named] = int(classes.get(named, 0)) + 1
		# THE KIND IS PRINTED FOR WHOEVER TUNES `CloudTuning.TYPES`, and nothing here judges by it.
		lines.append("%s (%s, strength %.1f) h/w %.2f long %.2f shreds %d" % [named, LiftYard.cloud_type(zone)["name"],
			float(zone["strength"]), ratio, shape["elongation"], shape["broken_away"]])
	var mean: float = 0.0
	for r in ratios:
		mean += r
	mean /= maxf(float(ratios.size()), 1.0)
	var spread: float = 0.0
	for r in ratios:
		spread += (r - mean) * (r - mean)
	spread = sqrt(spread / maxf(float(ratios.size()), 1.0))
	print("[air] cloud shapes: %s" % "; ".join(lines))
	_check("and_the_islands_clouds_are_not_one_family", spread >= RATIO_SPREAD_LEAST and classes.size() >= CLASSES_LEAST,
		"height/width spread %.3f (wanted %.2f), classes %s (wanted %d kinds), over %d clouds" % [spread,
			RATIO_SPREAD_LEAST, classes, CLASSES_LEAST, zones.size()])


## NO CLOUD SPREADS PAST ITS THERMAL: the box round every cloud's fog (`LiftYard.cloud_bounds`) is no longer in plan than
## `CloudTuning.PLAN_MOST` of its zone's radius. The first cloud kinds laid a flat cloud out 3.1 km long over a 279 m thermal,
## and it came on as fog while nearly all of it was a kilometre off, a blurred streak; eleven pairs of clouds' boxes overlapped,
## and the fly-in began inside a neighbour (d2-after, 2026-09-14). Eleven lumps a cloud reached 4.47 radii at most, and six
## pairs overlapped. The overlapping pairs are printed, not held: thermals stand where the terrain puts them.
func _no_cloud_spreads_past_its_thermal() -> void:
	var zones: Array[Dictionary] = Terrain.lift_zones()
	var boxes: Array[AABB] = []
	var worst: float = 0.0
	var worst_at: int = -1
	for i in range(zones.size()):
		var box: AABB = LiftYard.cloud_bounds(LiftYard.cloud_lumps(zones[i], Terrain.WIND))
		boxes.append(box)
		var across: float = maxf(box.size.x, box.size.z) / maxf(float(zones[i]["radius"]), 1.0)
		if across > worst:
			worst = across
			worst_at = i
	var overlaps: int = 0
	for i in range(boxes.size()):
		for j in range(i + 1, boxes.size()):
			if boxes[i].intersects(boxes[j]):
				overlaps += 1
	print("[air] clouds' boxes overlapping: %d pairs of %d clouds" % [overlaps, zones.size()])
	_check("and_no_cloud_spreads_past_its_thermal", worst <= CloudTuning.PLAN_MOST + 0.001,
		"the widest in plan is %.2f of its thermal's radius (cloud %d; at most %.2f)" % [worst, worst_at,
			CloudTuning.PLAN_MOST])


## ONE CLOUD'S SHAPE, MEASURED FROM ITS LUMPS: {height_over_width, elongation, broken_away}. Each lump is taken as the
## ellipsoid its transform draws (a unit sphere of radius 0.5 through the basis), so a stretched or turned lump counts as
## drawn.
static func cloud_shape_measured(lumps: Array[Dictionary], base: float) -> Dictionary:
	var top: float = base
	var widest: float = 0.0
	var narrowest: float = INF
	for k in range(8):
		var heading := Vector3(cos(PI * float(k) / 8.0), 0.0, sin(PI * float(k) / 8.0))
		var low: float = INF
		var high: float = -INF
		for lump in lumps:
			var t: Transform3D = lump["transform"]
			var reach: float = 0.5 * (absf(t.basis.x.dot(heading)) + absf(t.basis.y.dot(heading)) + absf(t.basis.z.dot(heading)))
			var along: float = t.origin.dot(heading)
			if reach <= 0.01:
				continue
			low = minf(low, along - reach)
			high = maxf(high, along + reach)
		widest = maxf(widest, high - low)
		narrowest = minf(narrowest, high - low)
	for lump in lumps:
		var t: Transform3D = lump["transform"]
		var half_up: float = 0.5 * (absf(t.basis.x.y) + absf(t.basis.y.y) + absf(t.basis.z.y))
		if half_up > 0.01:
			top = maxf(top, t.origin.y + half_up)
	# BROKEN AWAY: not joined, through lumps that touch, to the body the biggest lump is part of. A skirt lump that touches
	# only its neighbour is still the cloud; the first measure counted any lump with no neighbour inside two radii, and called
	# thirteen of today's twenty heaps ragged.
	var radii: Array[float] = []
	var biggest: int = -1
	for i in range(lumps.size()):
		var t: Transform3D = lumps[i]["transform"]
		var r: float = 0.5 * maxf(t.basis.x.length(), maxf(t.basis.y.length(), t.basis.z.length()))
		radii.append(r)
		if r > 0.01 and (biggest < 0 or r > radii[biggest]):
			biggest = i
	var joined: Dictionary = {biggest: true}
	var frontier: Array[int] = [biggest]
	while not frontier.is_empty():
		var at: int = frontier.pop_back()
		var at_origin: Vector3 = (lumps[at]["transform"] as Transform3D).origin
		for j in range(lumps.size()):
			if joined.has(j) or radii[j] <= 0.01:
				continue
			if at_origin.distance_to((lumps[j]["transform"] as Transform3D).origin) < radii[at] + radii[j]:
				joined[j] = true
				frontier.append(j)
	var broken: int = 0
	for i in range(lumps.size()):
		if radii[i] > 0.01 and not joined.has(i):
			broken += 1
	return {"height_over_width": (top - base) / maxf(widest, 1.0), "elongation": widest / maxf(narrowest, 1.0),
		"broken_away": broken}


## A CLOUD YOU CAN FLY INTO STANDS WHERE THE LUMPS STAND. `CloudBank` draws each cloud as a fog volume round
## `LiftYard.cloud_lumps`, on Forward+ with `--clouds=volumes`, so a fog cloud is marked where the lift is only if its box
## starts at the zone's top -- the base the check above holds -- and holds every lump above it, and its envelope is thick in
## the core and empty under the base. Asked of the static functions the bank and its shader agree with, because headless
## has no fog to look at.
func _every_fog_cloud_stands_where_its_lumps_do() -> void:
	var zones: Array[Dictionary] = Terrain.lift_zones()
	var off_the_base: Array[String] = []
	var outside: int = 0
	var thin_cores: int = 0
	var under_the_base: int = 0
	var clear_of_base: float = CloudTuning.FOG_BASE_SOFT * 2.0
	for zone in zones:
		var top: float = float(zone["top"])
		var lumps: Array[Dictionary] = LiftYard.cloud_lumps(zone, Terrain.WIND)
		var box: AABB = LiftYard.cloud_bounds(lumps)
		if absf(box.position.y - top) > 0.01:
			off_the_base.append("%.1f against %.1f" % [box.position.y, top])
		for piece in lumps:
			var at: Vector3 = (piece["transform"] as Transform3D).origin
			if not box.has_point(Vector3(at.x, maxf(at.y, top + clear_of_base), at.z)):
				outside += 1
		var core: Vector3 = (lumps[0]["transform"] as Transform3D).origin
		if LiftYard.shape_at(lumps, Vector3(core.x, maxf(core.y, top + clear_of_base), core.z)) < 0.9:
			thin_cores += 1
		if LiftYard.shape_at(lumps, Vector3(core.x, top - 1.0, core.z)) > 0.0:
			under_the_base += 1
	_check("and_every_fog_cloud_stands_on_its_zones_top_round_its_lumps", off_the_base.is_empty() and outside == 0,
		"%d boxes off the base %s, %d lumps outside their box, of %d clouds" % [off_the_base.size(),
			off_the_base.slice(0, 3), outside, zones.size()])
	_check("and_a_fog_cloud_is_thick_in_its_core_and_empty_under_its_base", thin_cores == 0 and under_the_base == 0,
		"%d thin cores, %d clouds with fog a metre under the base, of %d" % [thin_cores, under_the_base, zones.size()])


## A CLOUD IS LIT AS A VOLUME, THROUGH ITS OWN ENVELOPE (asked for on 2026-09-15: "increase the volumetrics of the clouds").
## Three things, each able to fail on its own:
##   - the envelope is the cloud's: it holds the cloud's core lump, its radii reach no further than the cloud's box;
##   - the materials carry it: the lumps' batch array, at each cloud's place in the batch, and the fog cloud's own, are
##     `LiftYard.cloud_envelope` of that cloud's lumps, and the shaders' array is as long as `CloudTuning.MOST_CLOUDS`;
##   - and the sun it lets through falls into it: at every time of day, for every cloud, a point on the sunward side keeps
##     more of the sun than the middle, the middle more than the far side, and the sunward point most of it.
## The shader's light is the same arithmetic as `LiftYard.envelope_sun_depth` and `sun_through`; pictures judge the rest.
func _every_cloud_is_lit_through_its_own_envelope() -> void:
	var zones: Array[Dictionary] = Terrain.lift_zones()
	var yard := LiftYard.new()
	add_child(yard)
	yard.show_lift(zones, Terrain.WIND)
	var drawn_at: Variant = yard.cloud_lit_with("envelope_at")[0]
	var drawn_radii: Variant = yard.cloud_lit_with("envelope_radii")[0]
	var bank := CloudBank.new()
	add_child(bank)
	var not_its_own: Array[String] = []
	var not_drawn: int = 0
	var fog_wrong: int = 0
	var backwards: Array[String] = []
	for i in range(zones.size()):
		var lumps: Array[Dictionary] = LiftYard.cloud_lumps(zones[i], Terrain.WIND)
		var envelope: Dictionary = LiftYard.cloud_envelope(lumps)
		var centre: Vector3 = envelope["centre"]
		var radii: Vector3 = envelope["radii"]
		var box: AABB = LiftYard.cloud_bounds(lumps)
		var core: Vector3 = (lumps[0]["transform"] as Transform3D).origin
		var core_in: Vector3 = (core - centre) / radii
		if core_in.length() > 1.0 or radii.x > box.size.x or radii.z > box.size.z or radii.y > box.size.y + 400.0:
			not_its_own.append("cloud %d core at %.2f of the envelope, radii %s, box %s" % [i, core_in.length(), radii, box.size])
		if not (drawn_at is PackedVector4Array and drawn_radii is PackedVector4Array) or i >= (drawn_at as PackedVector4Array).size() \
				or Vector3(drawn_at[i].x, drawn_at[i].y, drawn_at[i].z).distance_to(centre) > 0.01 \
				or Vector3(drawn_radii[i].x, drawn_radii[i].y, drawn_radii[i].z).distance_to(radii) > 0.01:
			not_drawn += 1
		var key: Vector2i = bank.add_cloud(zones[i], Terrain.WIND)
		var paint: ShaderMaterial = bank._clouds[key]["paint"]
		if (paint.get_shader_parameter("envelope_centre") as Vector3).distance_to(centre) > 0.01 \
				or (paint.get_shader_parameter("envelope_radii") as Vector3).distance_to(radii) > 0.01:
			fog_wrong += 1
		for time in range(DaylightTuning.When.size()):
			var sun: Vector3 = DaylightTuning.towards_the_sun(time)
			# THE ENVELOPE'S OWN REACH TOWARDS THE SUN, so the two points are inside it whatever its proportions.
			var reach: float = 1.0 / (sun / radii).length()
			var lit: float = LiftYard.sun_through(LiftYard.envelope_sun_depth(envelope, centre + sun * reach * 0.8, sun))
			var middle: float = LiftYard.sun_through(LiftYard.envelope_sun_depth(envelope, centre, sun))
			var lee: float = LiftYard.sun_through(LiftYard.envelope_sun_depth(envelope, centre - sun * reach * 0.8, sun))
			if not (lit > middle and middle > lee and lit >= 0.5):
				backwards.append("cloud %d %s: sunward %.2f, middle %.2f, far side %.2f" % [i, DaylightTuning.name_of(time),
					lit, middle, lee])
	bank.queue_free()
	yard.queue_free()
	_check("and_every_cloud_has_an_envelope_of_its_own_lumps", not_its_own.is_empty(),
		"%d of %d wrong %s" % [not_its_own.size(), zones.size(), not_its_own.slice(0, 2)])
	_check("and_the_lumps_and_the_fog_are_lit_through_it", not_drawn == 0 and fog_wrong == 0,
		"%d of %d clouds' lumps and %d fog clouds with another envelope" % [not_drawn, zones.size(), fog_wrong])
	var source: String = FileAccess.get_file_as_string("res://world/shaders/cloud_envelopes.gdshaderinc")
	var length := RegEx.new()
	length.compile("uniform\\s+vec4\\s+envelope_at\\[(\\d+)\\]")
	var found: RegExMatch = length.search(source)
	_check("and_the_shaders_carry_as_many_envelopes_as_the_tuning_says_and_the_island_needs",
		found != null and int(found.get_string(1)) == CloudTuning.MOST_CLOUDS and zones.size() <= CloudTuning.MOST_CLOUDS,
		"shader %s, tuning %d, clouds %d" % [found.get_string(1) if found != null else "none", CloudTuning.MOST_CLOUDS,
			zones.size()])
	_check("and_the_sun_falls_off_into_every_cloud_at_every_time_of_day", backwards.is_empty(),
		"%d of %d wrong %s" % [backwards.size(), zones.size() * DaylightTuning.When.size(), backwards.slice(0, 2)])


## A CLOUD'S EDGE IS A BLENDED FALLOFF, NOT A STIPPLE (team-lead, 2026-09-15, off the survey's cumulus_side: "coarse
## salt-and-pepper stipple several pixels deep. In VR that will crawl and differ between eyes"). On both finishes the lumps'
## material has a rim pass after it, lit with exactly the numbers the core is lit with; and no lump shader cuts its coverage
## against a hash or anything read per pixel of the screen.
func _every_clouds_edge_is_a_falloff_and_not_a_stipple() -> void:
	var zones: Array[Dictionary] = Terrain.lift_zones()
	var yard := LiftYard.new()
	add_child(yard)
	yard.show_lift(zones, Terrain.WIND)
	yard.show_daylight(DaylightTuning.look_of(DaylightTuning.When.EVENING))
	yard._wear(true)
	var wrong: Array[String] = []
	for pair in [["plain", yard._plain_paint, LiftYard.CUMULUS_PLAIN_RIM], ["fine", yard._fine_paint, LiftYard.CUMULUS_RIM]]:
		var core: ShaderMaterial = pair[1]
		var rim: ShaderMaterial = core.next_pass as ShaderMaterial if core != null else null
		if rim == null or rim.shader != pair[2]:
			wrong.append("%s has no rim pass" % pair[0])
			continue
		for field in ["sun_light", "towards_sun", "sky_light", "shade_light", "envelope_at", "envelope_radii", "sun_extinction"]:
			if core.get_shader_parameter(field) != rim.get_shader_parameter(field):
				wrong.append("%s rim %s %s against core %s" % [pair[0], field, rim.get_shader_parameter(field),
					core.get_shader_parameter(field)])
	var stippled: Array[String] = []
	var unfiltered: Array[String] = []
	for path in ["res://world/shaders/cumulus_lump.gdshaderinc", "res://world/shaders/cumulus_plain_lump.gdshaderinc"]:
		# THE CODE, NOT ITS NOTES: the include's header quotes the stipple it replaced, and the first run of this check read that.
		var code: String = ""
		for line_of_code in FileAccess.get_file_as_string(path).split("\n"):
			if not line_of_code.strip_edges().begins_with("//"):
				code += line_of_code + "\n"
		var scissor: int = code.find("ALPHA_SCISSOR_THRESHOLD")
		var line: String = code.substr(scissor, code.find(";", scissor) - scissor) if scissor >= 0 else "none"
		if scissor < 0 or line.contains("hash") or line.contains("FRAGCOORD") or code.contains("hash31(floor("):
			stippled.append("%s: %s" % [path.get_file(), line])
		# FILTERED OVER THE PIXEL (team-lead off glassrim-zoom4): PLAIN has no MSAA, so the core's hard cut stair-stepped. The rim's
		# alpha is its ramp averaged over the pixel and the core is cut where that is whole (cloud_rim.gdshaderinc).
		if not (code.contains("#include \"res://world/shaders/cloud_rim.gdshaderinc\"") and code.contains("ALPHA = cloud_rim_alpha(")
				and line.contains("cut")):
			unfiltered.append(path.get_file())
	yard.queue_free()
	_check("and_every_clouds_edge_is_blended_on_both_finishes_and_lit_as_its_core", wrong.is_empty(), "%s" % [wrong])
	_check("and_no_lump_is_cut_against_a_hash", stippled.is_empty(), "%s" % [stippled])
	_check("and_every_lumps_edge_is_filtered_over_the_pixel", unfiltered.is_empty(), "%s" % [unfiltered])


## THE CLOUD NEAR THE EYE IS FOG AND ITS LUMPS GIVE WAY; A FAR ONE IS ALL MESH. A CloudBank and a LiftYard, wired the way the
## level wires them (the bank announces a share, the yard shows it), with a camera moved from far off to inside the first
## zone's cloud: the share drawn as fog and the share the lumps were told must be the same number, and the one
## `CloudBank.fog_share` gives for that distance -- all mesh far, all fog inside, between in the fade. On PLAIN every cloud is
## all mesh, and a zone that goes away takes its fog with it and leaves its lumps whole.
func _a_cloud_near_the_eye_is_fog_and_its_lumps_give_way() -> void:
	var finish: Node = get_node_or_null("/root/Finish")
	var was_fine: bool = finish != null and bool(finish.call("is_fine"))
	var zones: Array[Dictionary] = Terrain.lift_zones()
	var zone: Dictionary = zones[0]
	var key: Vector2i = LiftYard.cloud_key(zone)
	var box: AABB = LiftYard.cloud_bounds(LiftYard.cloud_lumps(zone, Terrain.WIND))
	var holder := Node3D.new()
	add_child(holder)
	var eye := Camera3D.new()
	holder.add_child(eye)
	eye.current = true
	var yard := LiftYard.new()
	holder.add_child(yard)
	yard.show_lift(zones, Terrain.WIND)
	var bank := CloudBank.new()
	var air := Environment.new()
	bank.air = air
	holder.add_child(bank)
	bank.fog_share_changed.connect(yard.show_fog_share)
	bank.gather(zones, Terrain.WIND)
	if finish != null:
		finish.call("choose", true)
	var mid: float = (CloudTuning.FOG_FADE.x + CloudTuning.FOG_FADE.y) * 0.5
	var readings: Array[String] = []
	var wrong: int = 0
	var froxels: Array[String] = []
	for place in [["far", box.get_center() + Vector3(5000.0, 0.0, 0.0)], ["inside", box.get_center()],
			["in_the_fade", Vector3(box.end.x + mid, box.get_center().y, box.get_center().z)]]:
		eye.global_position = place[1]
		for i in range(3):
			await get_tree().process_frame
		var wanted: float = CloudBank.fog_share(CloudBank.distance_to(box, place[1]))
		var drawn: float = bank.fog_share_drawn(key)
		var shown: float = yard.fog_share_shown(key)
		readings.append("%s wanted %.2f drawn %.2f lumps told %.2f" % [place[0], wanted, drawn, shown])
		if absf(drawn - wanted) > CloudBank.SHARE_STEP or absf(shown - wanted) > CloudBank.SHARE_STEP:
			wrong += 1
		froxels.append("%s %s" % [place[0], "on" if air.volumetric_fog_enabled else "off"])
	_check("and_a_cloud_is_fog_near_the_eye_and_mesh_far_from_it_and_its_lumps_are_told", wrong == 0
		and bank.fog_share_drawn(key) > 0.0 and bank.fog_share_drawn(key) < 1.0, "; ".join(readings))
	# ON PLAIN, ALL MESH, with the eye still in the fade.
	if finish != null:
		finish.call("choose", false)
	for i in range(3):
		await get_tree().process_frame
	froxels.append("plain in the fade %s" % ["on" if air.volumetric_fog_enabled else "off"])
	# THE ENVIRONMENT'S FROXELS RUN ONLY WHILE SOME CLOUD IS FOG: off far from every cloud and on PLAIN, on inside one.
	_check("and_the_froxels_run_only_while_a_cloud_is_fog",
		froxels == ["far off", "inside on", "in_the_fade on", "plain in the fade off"], ", ".join(froxels))
	_check("and_on_plain_every_cloud_is_all_mesh", bank.fog_share_drawn(key) == 0.0 and yard.fog_share_shown(key) == 0.0,
		"drawn %.2f, lumps told %.2f" % [bank.fog_share_drawn(key), yard.fog_share_shown(key)])
	# A ZONE THAT GOES, with the eye inside its cloud on FINE.
	if finish != null:
		finish.call("choose", true)
	eye.global_position = box.get_center()
	for i in range(3):
		await get_tree().process_frame
	var before: float = yard.fog_share_shown(key)
	bank.gather(zones.slice(1), Terrain.WIND)
	_check("and_a_zone_that_goes_takes_its_fog_and_leaves_its_lumps_whole", before >= 1.0
		and not bank.cloud_keys().has(key) and yard.fog_share_shown(key) == 0.0 and bank.volumes() == zones.size() - 1,
		"inside before %.2f, lumps told %.2f after, %d clouds of %d zones" % [before, yard.fog_share_shown(key),
			bank.volumes(), zones.size()])
	if finish != null:
		finish.call("choose", was_fine)
	holder.queue_free()


## THE EYE IN A CLOUD IS WHITED OUT AND THE MARKERS GO. The level itself, on PLAIN with no fog clouds -- what a headset starts
## on -- with the camera the viewport draws with stood in the core of the first zone's cloud: the level says the eye is in
## that cloud nearly at full depth, the rings and wisps are drawn at nothing, and the depth fog is at the whiteout's density
## in the cloud's colour. Stood two kilometres over every cloud, all of it is back exactly as the time of day had it.
func _the_eye_in_a_cloud_is_whited_out_and_the_markers_go() -> void:
	var finish: Node = get_node_or_null("/root/Finish")
	var was_fine: bool = finish != null and bool(finish.call("is_fine"))
	if finish != null:
		finish.call("choose", false)
	# WITH THE FOG CLOUDS ASKED FOR, because since 2026-09-15 a level builds none unless somebody does (`CloudBank.asked_for`)
	# and this section is about what the fog does to the depth fog when it IS there. The default -- no bank on either
	# finish -- is `_a_cloud_with_no_fog_in_it_whites_the_view_out_on_both_finishes` below.
	CloudBank.also_wanted = true
	var level := (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(60):
		await get_tree().physics_frame
	if level.lift == null:
		_check("there_is_a_level_to_stand_in_a_cloud", false, "no clouds")
		level.queue_free()
		return
	var eye := Camera3D.new()
	level.add_child(eye)
	eye.current = true
	var zone: Dictionary = Terrain.lift_zones()[0]
	var lumps: Array[Dictionary] = LiftYard.cloud_lumps(zone, Terrain.WIND)
	var core: Vector3 = (lumps[0]["transform"] as Transform3D).origin
	core.y = maxf(core.y, float(zone["top"]) + CloudTuning.FOG_BASE_SOFT * 2.0)
	var air: Environment = (level.get_node("WorldEnvironment") as WorldEnvironment).environment
	# CLEAR, TAKEN WHERE IT IS COMPARED: two kilometres over the cloud, where the eye comes back to, since the low mist is
	# thicker at the level's first camera on the ground than it is up there.
	eye.global_position = core + Vector3(0.0, 2000.0, 0.0)
	for i in range(3):
		await get_tree().process_frame
	var clear: Array = [air.fog_density, air.fog_light_color, air.fog_aerial_perspective, level.lift.markers()]
	eye.global_position = core
	for i in range(3):
		await get_tree().process_frame
	var cloud_colour: Color = LiftYard.cloud_colour(level.daylight.look)
	_check("and_the_level_says_the_eye_is_in_that_cloud", level.eye_depth >= 0.9
		and level.eye_cloud == LiftYard.cloud_key(zone), "depth %.2f in %s, the zone's cloud is %s" % [level.eye_depth,
			level.eye_cloud, LiftYard.cloud_key(zone)])
	_check("and_the_rings_and_wisps_are_drawn_at_nothing_from_inside", level.lift.markers() <= 0.1 * float(clear[3]),
		"markers %.3f inside against %.3f clear" % [level.lift.markers(), clear[3]])
	var whited: bool = absf(air.fog_density - lerpf(float(clear[0]), CloudTuning.WHITEOUT_DENSITY, level.eye_depth)) < 0.001 \
		and air.fog_light_color.is_equal_approx((clear[1] as Color).lerp(cloud_colour, level.eye_depth))
	_check("and_on_plain_the_depth_fog_whites_the_view_out_in_the_clouds_colour", whited and air.fog_density > 0.05,
		"fog density %.4f (clear %.5f), light %s against the cloud's %s" % [air.fog_density, clear[0], air.fog_light_color,
			cloud_colour])
	# ON FINE WITH FOG CLOUDS THE FOG DOES THE WHITEOUT, and the depth fog is left as the time of day has it -- two whiteouts
	# at once is the view gone twice as fast. Then PLAIN again, still inside, so the eye leaves the cloud on PLAIN.
	if finish != null:
		finish.call("choose", true)
	for i in range(3):
		await get_tree().process_frame
	# REFUSED RATHER THAN FAILED ON A RENDERER WITH NO FOG VOLUMES. Since 2026-09-15 the game is on Mobile, where
	# `CloudBank.can_draw()` is false and no amount of asking builds a bank -- so there is no "with fog clouds" to check,
	# and a red line here would be the suite reporting the renderer as a bug. It stays for a Forward+ run
	# (`--rendering-method forward_plus`), which is the only place the case exists.
	if not CloudBank.can_draw():
		print("[air] SKIP and_on_fine_with_fog_clouds_the_depth_fog_is_left_alone: %s draws no fog volume"
			% RenderingServer.get_current_rendering_method())
	else:
		_check("and_on_fine_with_fog_clouds_the_depth_fog_is_left_alone", level.clouds != null
			and is_equal_approx(air.fog_density, float(clear[0])) and level.lift.markers() <= 0.1 * float(clear[3]),
			"fog clouds %s, fog density %.5f (clear %.5f), markers %.3f" % [level.clouds != null, air.fog_density,
				clear[0], level.lift.markers()])
	if finish != null:
		finish.call("choose", false)
	for i in range(3):
		await get_tree().process_frame
	eye.global_position = core + Vector3(0.0, 2000.0, 0.0)
	for i in range(3):
		await get_tree().process_frame
	var back: Array = [air.fog_density, air.fog_light_color, air.fog_aerial_perspective, level.lift.markers()]
	_check("and_out_of_it_every_one_is_back_as_it_was", level.eye_depth == 0.0 and is_equal_approx(back[0], clear[0])
		and (back[1] as Color).is_equal_approx(clear[1]) and is_equal_approx(back[2], clear[2])
		and is_equal_approx(back[3], clear[3]), "depth %.2f, %s against %s" % [level.eye_depth, back, clear])
	# THE DEPTH FOG IS CLEAR AIR AT EVERY HEIGHT, AT EVERY TIME OF DAY: out of every cloud, two metres over the surface and 900 m
	# up (under every cloud's base) it is the time of day's `clear_air`, through the level's own `choose_time` and camera. The
	# low mist lies in the world (`MistLayer`, tests/mist.gd); until 2026-09-15 it was eased in here by the eye's height, and the
	# whole view thickened as the eye came down (godotgames-drafts/2026-09-15/cockpit-mist/survey).
	var surface: float = Terrain.surface_height(core)
	var airs: Array[String] = []
	var air_wrong: int = 0
	for which in [DaylightTuning.When.EVENING, DaylightTuning.When.NIGHT, DaylightTuning.When.DAY]:
		level.choose_time(which)
		var p: Dictionary = DaylightTuning.preset(which)
		eye.global_position = Vector3(core.x, surface + 2.0, core.z)
		for i in range(3):
			await get_tree().process_frame
		var low: float = air.fog_density
		eye.global_position = Vector3(core.x, surface + 900.0, core.z)
		for i in range(3):
			await get_tree().process_frame
		var high: float = air.fog_density
		airs.append("%s low %.5f, high %.5f, against %.5f" % [DaylightTuning.name_of(which), low, high, p["clear_air"]])
		if absf(low - float(p["clear_air"])) > 0.000001 or absf(high - float(p["clear_air"])) > 0.000001:
			air_wrong += 1
	_check("and_the_depth_fog_is_clear_air_at_every_height_and_time_of_day", air_wrong == 0, "; ".join(airs))
	if finish != null:
		finish.call("choose", was_fine)
	level.queue_free()
	await get_tree().process_frame


## ---- no volumetrics, and the view still gone from inside ------------------------------------

## A LEVEL BUILDS NO FOG AND NO FROXEL GRID UNLESS SOMEBODY ASKS, AND YOU STILL CANNOT SEE OUT OF A CLOUD.
##
## Asked for on 2026-09-15: "disable all volumetrics and turn clouds back into solid objects, if we can preserve the fact
## that the user can't see out of them when inside that would be great." The section above is the fog doing the whiteout
## when it is asked for; this is the DEFAULT -- no bank on either finish, the environment's volumetric fog never switched
## on, and the depth fog whiting the view out on FINE as it always has on PLAIN.
##
## BOTH FINISHES, because FINE used to be the finish that had the fog: a FINE level that built no bank and also left the
## depth fog alone would be a cloud you fly into and see the island through, which is the bug this preserves against.
func _a_level_with_no_fog_asked_for_builds_none_and_whites_out_on_both_finishes() -> void:
	var finish: Node = get_node_or_null("/root/Finish")
	var was_fine: bool = finish != null and bool(finish.call("is_fine"))
	CloudBank.also_wanted = false
	var level := (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(60):
		await get_tree().physics_frame
	if level.lift == null:
		_check("there_is_a_level_to_stand_in_a_cloud_with_no_fog", false, "no clouds")
		level.queue_free()
		return
	_check("a_level_asked_for_no_fog_builds_no_cloud_bank", level.clouds == null, "%s" % [level.clouds])
	var eye := Camera3D.new()
	level.add_child(eye)
	eye.current = true
	var zone: Dictionary = Terrain.lift_zones()[0]
	var lumps: Array[Dictionary] = LiftYard.cloud_lumps(zone, Terrain.WIND)
	var core: Vector3 = (lumps[0]["transform"] as Transform3D).origin
	core.y = maxf(core.y, float(zone["top"]) + CloudTuning.FOG_BASE_SOFT * 2.0)
	var air: Environment = (level.get_node("WorldEnvironment") as WorldEnvironment).environment
	# AND THE CLOUDS ARE STILL THERE AS OBJECTS: the lumps are drawn whole, told a fog share of nothing, on both finishes.
	var readings: PackedStringArray = []
	var wrong: int = 0
	for fine in [false, true]:
		if finish != null:
			finish.call("choose", fine)
		eye.global_position = core + Vector3(0.0, 2000.0, 0.0)
		for i in range(3):
			await get_tree().process_frame
		var clear: float = air.fog_density
		eye.global_position = core
		for i in range(3):
			await get_tree().process_frame
		var cloud_colour: Color = LiftYard.cloud_colour(level.daylight.look)
		var whited: bool = air.fog_density > 0.05 and air.fog_light_color.is_equal_approx(cloud_colour)
		# DRAWN, by whichever clouds the level wears: the puffs since 2026-09-17, LiftYard's lumps on `--clouds=lumps`.
		var solid: bool = level.lift.fog_share_shown(LiftYard.cloud_key(zone)) == 0.0 and level.clouds_drawn()
		var froxels_off: bool = not air.volumetric_fog_enabled
		readings.append("%s: depth %.2f, fog %.4f (clear %.5f), lumps told %.2f, froxels %s" % [
			"fine" if fine else "plain", level.eye_depth, air.fog_density, clear,
			level.lift.fog_share_shown(LiftYard.cloud_key(zone)), "on" if air.volumetric_fog_enabled else "off"])
		if not (whited and solid and froxels_off and level.eye_depth >= 0.9):
			wrong += 1
	_check("and_on_both_finishes_the_cloud_is_solid_the_froxels_are_off_and_the_view_is_whited_out", wrong == 0,
		"; ".join(readings))
	if finish != null:
		finish.call("choose", was_fine)
	level.queue_free()
	await get_tree().process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
