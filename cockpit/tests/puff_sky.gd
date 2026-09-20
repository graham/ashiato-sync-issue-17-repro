extends Node
## Headless: does the layered sky of puff clouds (`PuffSky`, `PuffCloud`) put every kind at its own height, with clear air
## between the layers, never in the ground, the same sky on every machine from one seed -- and does "the eye is in a cloud"
## begin and end where the cloud does?
##
##   tools\gate_run.ps1 -Suite puff_sky
##
## A PROTOTYPE'S RULES (lane/clouds2, 2026-09-17). The pictures are tests/puff_shot.gd's; this holds what can be asserted.
## Every check reads the same functions the drawing is fed by -- `PuffSky.plan`, `PuffCloud.lay_out`,
## `PuffCloud.density_at` -- because headless answers a default for every instance read back off a MultiMesh.
##
## Read RESULT=, not the exit code.

## A mountain for the ground: 2,600 m at (3000, 0, 3000), falling away over 2.5 km. Higher than every cumulus band.
const PEAK := Vector3(3000.0, 2600.0, 3000.0)
const PEAK_REACH: float = 2500.0

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[puff_sky] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_every_kind_stands_in_its_own_band()
	_the_layers_leave_clear_air_between_them()
	_no_cloud_stands_in_the_ground()
	_a_path_through_a_cloud_is_inside_it_and_a_path_under_its_base_is_not()
	_one_seed_is_one_sky_on_every_machine()
	await _the_sky_is_one_batch_a_kind()
	_every_thermal_keeps_its_cloud()
	_the_towers_stand_in_walls()
	_an_altocumulus_deck_is_rolls_not_bubbles()
	await _the_flight_level_wears_the_puffs()
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


static func mountain(at: Vector3) -> float:
	var d := Vector2(at.x - PEAK.x, at.z - PEAK.z).length()
	return PEAK.y * exp(-(d * d) / (PEAK_REACH * PEAK_REACH))


## EVERY KIND'S BASE IS IN ITS BAND over flat ground, as `PuffCloud.KINDS` writes it, and no puff hangs under its base.
func _every_kind_stands_in_its_own_band() -> void:
	var sky := PuffSky.plan(7, 12000.0)
	var wrong: PackedStringArray = []
	var kinds := {}
	for cloud in sky:
		var band: Vector2 = PuffCloud.KINDS[cloud["kind"]]["band"]
		kinds[cloud["kind"]] = true
		if float(cloud["base"]) < band.x or float(cloud["base"]) > band.y:
			wrong.append("%s base %.0f outside %s" % [cloud["kind"], cloud["base"], band])
	_check("every_kind_stands_in_its_own_band", wrong.is_empty() and kinds.size() == PuffCloud.KINDS.size(),
		"%d clouds of %d kinds%s" % [sky.size(), kinds.size(), "" if wrong.is_empty() else ": %s" % wrong.slice(0, 3)])


## CLEAR AIR BETWEEN THE LAYERS, `PuffCloud.CLEAR_AIR` of it: the top of every cumulus and flat-based heap is that far
## under the lowest stratocumulus base the band allows, the stratocumulus's top under the altocumulus band, and the altocumulus's under the cirrus band -- so an
## aeroplane can fly between two decks. The towering cumulus is the one kind that is meant to climb through them.
func _the_layers_leave_clear_air_between_them() -> void:
	var sky := PuffSky.plan(7, 12000.0)
	# Read off the bands, not off the rows' `under`: the rule is about the heights, whoever wrote which layer is above.
	var ceiling := {
		"cumulus": PuffCloud.KINDS["stratocumulus"]["band"].x,
		"flat_based": PuffCloud.KINDS["stratocumulus"]["band"].x,
		"stratocumulus": PuffCloud.KINDS["altocumulus"]["band"].x,
		"altocumulus": PuffCloud.KINDS["cirrus"]["band"].x,
	}
	var worst := {}
	var wrong: PackedStringArray = []
	for cloud in sky:
		if not ceiling.has(cloud["kind"]):
			continue
		var top := _top_of(cloud)
		worst[cloud["kind"]] = maxf(float(worst.get(cloud["kind"], -INF)), top)
		if top > float(ceiling[cloud["kind"]]) - PuffCloud.CLEAR_AIR + 0.5:
			wrong.append("%s top %.0f at or over %.0f" % [cloud["kind"], top, ceiling[cloud["kind"]]])
	var shown: PackedStringArray = []
	for kind in worst:
		shown.append("%s tops out at %.0f under %.0f" % [kind, worst[kind], ceiling[kind]])
	_check("the_layers_leave_clear_air_between_them", wrong.is_empty(),
		"%s%s" % [", ".join(shown), "" if wrong.is_empty() else "; %s" % wrong.slice(0, 3)])


## NO CLOUD IN THE GROUND: with a 2,600 m mountain under part of the sky, every cloud's base clears the highest ground under
## every puff by `PuffCloud.CLEARANCE`, and there is no cloud at any point of the ground under it.
func _no_cloud_stands_in_the_ground() -> void:
	var sky := PuffSky.plan(7, 12000.0, Callable(self, "mountain"))
	var lifted := 0
	var buried: PackedStringArray = []
	for cloud in sky:
		var band: Vector2 = PuffCloud.KINDS[cloud["kind"]]["band"]
		if float(cloud["base"]) > band.y:
			lifted += 1
		for puff in cloud["puffs"]:
			var c: Vector3 = puff["centre"]
			var ground := mountain(c)
			if float(cloud["base"]) < ground + PuffCloud.CLEARANCE - 0.01:
				buried.append("%s base %.0f over ground %.0f" % [cloud["kind"], cloud["base"], ground])
				break
			if PuffCloud.density_at(cloud, Vector3(c.x, ground, c.z)) > 0.0:
				buried.append("%s has cloud on the ground at %s" % [cloud["kind"], Vector3(c.x, ground, c.z)])
				break
	_check("no_cloud_stands_in_the_ground", buried.is_empty() and lifted > 0,
		"%d clouds lifted off their band over the mountain%s" % [lifted,
			"" if buried.is_empty() else "; %s" % buried.slice(0, 3)])


## "THE EYE IS IN A CLOUD" BEGINS AND ENDS WHERE THE CLOUD DOES: a straight line through the middle of a flat-based cumulus
## is clear air far out on both sides and cloud through its middle, and a line 40 m under its base is clear all the way.
func _a_path_through_a_cloud_is_inside_it_and_a_path_under_its_base_is_not() -> void:
	var cloud := PuffCloud.lay_out("flat_based", Vector3.ZERO, 13)
	var middle := PuffCloud.middle_of(cloud)
	var reach := PuffCloud.reach_of(cloud)
	var inside := 0
	var entered := INF
	var left := -INF
	var steps := 200
	for s in range(steps + 1):
		var along := lerpf(-reach * 1.5, reach * 1.5, float(s) / float(steps))
		var here := middle + Vector3(0.0, 0.0, along)
		if PuffSky.densest_at([cloud], here) > 0.0:
			inside += 1
			entered = minf(entered, along)
			left = maxf(left, along)
	var ends_clear := PuffSky.densest_at([cloud], middle + Vector3(0, 0, -reach * 1.5)) == 0.0 \
		and PuffSky.densest_at([cloud], middle + Vector3(0, 0, reach * 1.5)) == 0.0
	var core := PuffSky.densest_at([cloud], middle)
	var under := 0
	for s in range(steps + 1):
		var along := lerpf(-reach * 1.5, reach * 1.5, float(s) / float(steps))
		if PuffSky.densest_at([cloud], Vector3(middle.x, float(cloud["base"]) - 40.0, middle.z + along)) > 0.0:
			under += 1
	_check("a_path_through_a_cloud_is_inside_it", ends_clear and inside > steps / 4 and core > 0.0,
		"inside %d of %d samples, from %.0f m to %.0f m of the middle, %.4f a metre at the middle" % [inside, steps + 1,
			entered, left, core])
	_check("and_a_path_under_its_base_is_not", under == 0, "%d of %d samples 40 m under the base in cloud" % [under,
		steps + 1])


## THE TOWERS STAND IN WALLS (clouds3, 2026-09-18): the user asked for the towering cumulus "grouped into walls rather than
## standing in a row", off a film still. In the planned sky every tower has another within a wall's step of it, measured
## middle to middle in plan against WALL_STEP of the widest tower's width and a half again for the wall's wander, and the
## sky has as many towers as PER_100_KM2 asks for: grouping them made no more and no fewer.
func _the_towers_stand_in_walls() -> void:
	var half := 12000.0
	var sky := PuffSky.plan(7, half)
	var towers: Array = sky.filter(func(cloud: Dictionary) -> bool: return cloud["kind"] == "towering")
	var widest: float = (PuffCloud.KINDS["towering"]["width"] as Vector2).y
	var near_enough := widest * PuffSky.WALL_STEP * 1.5
	var alone := 0
	var farthest := 0.0
	for tower in towers:
		var m := PuffCloud.middle_of(tower)
		var nearest := INF
		for other in towers:
			if other == tower:
				continue
			var o := PuffCloud.middle_of(other)
			nearest = minf(nearest, Vector2(m.x - o.x, m.z - o.z).length())
		farthest = maxf(farthest, nearest)
		if nearest > near_enough:
			alone += 1
	var asked := maxi(1, roundi(float(PuffSky.PER_100_KM2["towering"]) * pow(half * 2.0 / 10000.0, 2.0)))
	_check("the_towers_stand_in_walls", alone == 0 and towers.size() == asked and towers.size() >= 2,
		"%d towers of %d asked, %d alone; the farthest from its nearest neighbour %.0f m, a wall's step at most %.0f m" % [
			towers.size(), asked, alone, farthest, near_enough])


## AN ALTOCUMULUS DECK IS ROLLS, NOT BUBBLES (clouds3, step 4): a puff to a cell with gaps between read from the flight level
## as bubble wrap. Every puff of the deck overlaps its nearest neighbour in plan -- their middles closer than the smaller of
## their two widths -- so the deck's puffs run into each other as soft rolls.
func _an_altocumulus_deck_is_rolls_not_bubbles() -> void:
	var deck := PuffCloud.lay_out("altocumulus", Vector3.ZERO, 15)
	var puffs: Array = deck["puffs"]
	var apart := 0
	for puff in puffs:
		var c: Vector3 = puff["centre"]
		var r: Vector3 = puff["radii"]
		var touches := false
		for other in puffs:
			if other == puff:
				continue
			var o: Vector3 = other["centre"]
			var q: Vector3 = other["radii"]
			if Vector2(c.x - o.x, c.z - o.z).length() < minf(minf(r.x, r.z), minf(q.x, q.z)) * 2.0 * 0.8:
				touches = true
				break
		if not touches:
			apart += 1
	_check("an_altocumulus_deck_is_rolls_not_bubbles", apart * 20 <= puffs.size(),
		"%d of %d puffs overlap no neighbour by a fifth of a width, at most one in twenty" % [apart, puffs.size()])


## ONE SEED IS ONE SKY: the host hands out a seed and every peer lays the sky out from it, so two plans from one seed are
## the same to the last puff, and another seed is another sky.
func _one_seed_is_one_sky_on_every_machine() -> void:
	var one := PuffSky.plan(7, 12000.0)
	var again := PuffSky.plan(7, 12000.0)
	var other := PuffSky.plan(8, 12000.0)
	_check("one_seed_is_one_sky_on_every_machine", var_to_str(one) == var_to_str(again) and var_to_str(one) != var_to_str(other),
		"%d clouds, %d puffs" % [one.size(), _puffs(one)])


## A WHOLE SKY IS ONE DRAW A KIND: one MultiMesh a kind, holding every puff of it, each carrying its cloud's base.
func _the_sky_is_one_batch_a_kind() -> void:
	var sky := PuffSky.plan(7, 12000.0)
	var drawn := PuffSky.new()
	add_child(drawn)
	drawn.show_clouds(sky)
	await get_tree().process_frame
	var batches := drawn.find_children("*", "MultiMeshInstance3D", false, false)
	var counted := 0
	for batch in batches:
		counted += (batch as MultiMeshInstance3D).multimesh.instance_count
	_check("the_sky_is_one_batch_a_kind", batches.size() == PuffCloud.KINDS.size() and counted == _puffs(sky),
		"%d batches for %d kinds, %d instances for %d puffs" % [batches.size(), PuffCloud.KINDS.size(), counted, _puffs(sky)])
	drawn.queue_free()


## A THERMAL KEEPS ITS CLOUD: one puff cloud a lift zone, known by the zone's own key, its base at the column's top (or
## lifted clear of the ground), a flat-based cumulus over a strong column and a fair-weather one over a weak one.
func _every_thermal_keeps_its_cloud() -> void:
	var zones: Array[Dictionary] = Terrain.lift_zones()
	var clouds := PuffSky.thermal_clouds(zones, PuffSky.ground_under)
	var wrong: PackedStringArray = []
	for z in range(zones.size()):
		var zone: Dictionary = zones[z]
		var cloud: Dictionary = clouds[z]
		var kind := "flat_based" if float(zone["strength"]) >= PuffSky.STRONG_THERMAL else "cumulus"
		if cloud["key"] != LiftYard.cloud_key(zone) or cloud["kind"] != kind \
				or float(cloud["base"]) < float(zone["top"]) - 0.01:
			wrong.append("%s: %s %s base %.0f against top %.0f" % [LiftYard.cloud_key(zone), cloud["kind"], cloud["key"],
				cloud["base"], zone["top"]])
		# AND OVER THE COLUMN: the cloud's middle in plan within the column's spread of the zone.
		var m := PuffCloud.middle_of(cloud)
		var off := Vector2(m.x - (zone["position"] as Vector3).x, m.z - (zone["position"] as Vector3).z).length()
		if off > float(zone["radius"]) * LiftYard.CLOUD_SPREAD:
			wrong.append("%s: the cloud's middle %.0f m off the column" % [LiftYard.cloud_key(zone), off])
	_check("every_thermal_keeps_its_cloud", clouds.size() == zones.size() and zones.size() > 5 and wrong.is_empty(),
		"%d zones, %d clouds%s" % [zones.size(), clouds.size(), "" if wrong.is_empty() else ": %s" % wrong.slice(0, 3)])


## THE FLIGHT LEVEL WEARS THE PUFFS, by default: a cloud over every thermal and the layered sky, none in the ground, LiftYard's
## lumps not drawn beside them, lit by the level's time of day as LiftYard's were, on the level's finish, and gone for
## everybody when the host has no clouds (`Net.clouds_on`, as tests/sky_peers.gd holds across machines).
func _the_flight_level_wears_the_puffs() -> void:
	var finish: Node = get_node_or_null("/root/Finish")
	var was_fine: bool = finish != null and bool(finish.call("is_fine"))
	var level := (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(60):
		await get_tree().physics_frame
	if level.puffs == null:
		_check("the_flight_level_wears_the_puffs", false, "no puffs on the level")
		level.queue_free()
		return
	var keys := {}
	var buried := 0
	for cloud in level.puffs.clouds:
		if cloud.has("key"):
			keys[cloud["key"]] = true
		for puff in cloud["puffs"]:
			if float(cloud["base"]) < PuffSky.ground_under(puff["centre"]) + PuffCloud.CLEARANCE - 0.01:
				buried += 1
				break
	var thermals := 0
	for zone in Terrain.lift_zones():
		if keys.has(LiftYard.cloud_key(zone)):
			thermals += 1
	var kinds := {}
	for cloud in level.puffs.clouds:
		kinds[cloud["kind"]] = true
	_check("the_flight_level_wears_the_puffs", thermals == Terrain.lift_zones().size() and kinds.size() == PuffCloud.KINDS.size()
		and buried == 0 and level.clouds_drawn() and not level.lift.draws_clouds,
		"%d of %d thermals clouded, %d kinds, %d clouds, %d buried, puffs drawn %s, lumps drawn %s" % [thermals,
			Terrain.lift_zones().size(), kinds.size(), level.puffs.clouds.size(), buried, level.clouds_drawn(),
			level.lift.draws_clouds])
	# LIT BY THE TIME OF DAY, through the level's own choice: every kind's material carries LiftYard's evening light.
	level.choose_time(DaylightTuning.When.EVENING)
	await get_tree().process_frame
	var evening: Dictionary = LiftYard.cloud_light(DaylightTuning.look_of(DaylightTuning.When.EVENING))
	var unlit: PackedStringArray = []
	for batch in level.puffs.find_children("*", "MultiMeshInstance3D", false, false):
		var paint := (batch as MultiMeshInstance3D).material_override as ShaderMaterial
		var sun: Color = paint.get_shader_parameter("sun_light")
		var towards: Vector3 = paint.get_shader_parameter("towards_sun")
		if not sun.is_equal_approx(evening["sun_light"]) \
				or not towards.is_equal_approx((evening["towards_sun"] as Vector3).normalized()):
			unlit.append("%s %s %s" % [batch.name, sun, towards])
	_check("and_the_time_of_day_lights_them", unlit.is_empty(), "evening sun %s from %s%s" % [evening["sun_light"],
		evening["towards_sun"], "" if unlit.is_empty() else "; not on %s" % unlit])
	# ON THE LEVEL'S FINISH: PLAIN's one octave, FINE's four, on every kind.
	var finishes: PackedStringArray = []
	var worn_wrong := 0
	for fine in [false, true]:
		if finish != null:
			finish.call("choose", fine)
		await get_tree().process_frame
		for batch in level.puffs.find_children("*", "MultiMeshInstance3D", false, false):
			var worn: bool = ((batch as MultiMeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("fine")
			if worn != fine:
				worn_wrong += 1
		finishes.append("%s asked, %d kinds wrong" % ["fine" if fine else "plain", worn_wrong])
	_check("and_they_wear_the_levels_finish", finish != null and worn_wrong == 0, "; ".join(finishes))
	# NO CLOUDS FROM THE HOST, through the level's own `choose_clouds` (a session of this machine's own decides its sky):
	# nothing drawn.
	level.choose_clouds(false)
	await get_tree().process_frame
	var gone: bool = not level.puffs.visible and not level.clouds_drawn()
	level.choose_clouds(true)
	await get_tree().process_frame
	_check("and_no_clouds_from_the_host_is_no_puffs", gone and level.puffs.visible, "off: %s, back: %s" % [gone,
		level.puffs.visible])
	if finish != null:
		finish.call("choose", was_fine)
	level.queue_free()
	await get_tree().process_frame


func _puffs(sky: Array) -> int:
	var n := 0
	for cloud in sky:
		n += (cloud["puffs"] as Array).size()
	return n


## The highest a cloud's air reaches: its highest puff's top.
func _top_of(cloud: Dictionary) -> float:
	var top := -INF
	for puff in cloud["puffs"]:
		top = maxf(top, (puff["centre"] as Vector3).y + (puff["radii"] as Vector3).y)
	return top
