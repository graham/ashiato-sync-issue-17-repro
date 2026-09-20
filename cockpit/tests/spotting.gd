extends Node
## Headless: SPOTTING SIZE -- far aircraft drawn bigger for one viewer, true size inside a limit, and nothing else moved.
##
##   Godot --headless --path cockpit res://tests/spotting.tscn
##
## ASKED FOR ON 2026-09-18: "a setting that allows me to falsely increase the size to the viewer only, so in the ipad i
## can turn on "spotting size" and planes get progressively bigger as they get far away ... shrinking it back to normal
## size when it's within 0.5km (this should be configurable where the normal limit is)". See `Spectacles`.
##
## THE CURVE, with no world (`Spectacles.scale_for`, swept):
##   * OFF is exactly 1 at every distance and size;
##   * inside the limit it is exactly 1, and past it the scale never falls and never jumps: every strength, every limit,
##     three sizes, sampled every metre from the ground to 25 km, no metre moves it more than `MOST_A_METRE`;
##   * and what the eye is shown -- scale over distance -- never shrinks as a craft comes a metre nearer, which is what
##     makes shrinking it back invisible: it always grows faster by coming closer than it shrinks by being unmagnified;
##   * at 1, 3, 5, 10 and 20 km a fighter is never drawn smaller than the strength's floor angle unless it is at the cap,
##     and never past the cap.
## THE WORLD, the real flight level with the rig in its own aircraft and fighters put out at those distances:
##   * with HIGH on, each far fighter's drawn node is scaled by what the curve says for its distance from the eye, and
##     with it OFF every craft is back to exactly 1 on the next frame;
##   * the craft the rig is in is never scaled, nor the crewmate sat in it -- even handed an eye 8 km off, which would
##     magnify it were it not excluded;
##   * WITH THE SIMULATION HELD STILL, turning it on changes the far fighters' SCALE and nothing else: every transform
##     the simulation hands out is unit scale, and the craft's contacts, the eye, the rig's own craft and every drawn
##     craft stands where it stood -- its middle, or a slow one's wheels -- as it did with it off;
##   * the SPOTTING tab, pressed with the right hand's beam and trigger: a strength and a limit, each changing what the
##     rig wears and what the page says, and a fresh rig made afterwards -- a restart -- wearing the same;
##   * and what the pass costs at 64 fighters, the `vehicles_spectacles` lap, printed and held under `MOST_SHARE` of the
##     `vehicles_draw` lap it follows.
## Nothing on the wire is `tests/spotting_peers.gd`'s.
##
## MUTANTS, each applied alone and reverted (2026-09-18): see the report in learnings/2026-09-18-spotting.md.
##
## Read RESULT=, not the exit code.

const RIGHT: int = 1
## The distances the floor and the world are checked at, metres.
const DISTANCES: Array[float] = [1000.0, 3000.0, 5000.0, 10000.0, 20000.0]
## THE MOST THE SCALE MAY CHANGE IN ONE METRE, anywhere: `Spectacles.RAMP` over the nearest limit, 250 m, which is the
## steepest the ramp out of a limit can climb. A step of any size at the limit is hundreds of times this.
const MOST_A_METRE: float = 0.002
## THE PASS'S BUDGET at 64 fighters, as a share of what drawing every craft costs in the same frames: a tenth. A share
## and not microseconds, because both are read on whatever this machine is doing at the time: the same pass read 174 to
## 177 us a frame (2.9 per cent) on a quiet machine and 366 to 677 us (5 to 7.3 per cent) while other lanes' suites ran,
## with and without the LOD stretching alike (A/B, 2026-09-19). Headless, on the debug editor, where GDScript is at its
## slowest; the pass does nothing at all with spotting size OFF.
const MOST_SHARE: float = 0.10
const PATIENCE: int = 60

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _rig: PilotRig = null
var _fighters: Array[int] = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[spotting] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	if FileAccess.file_exists(Spectacles.path):
		DirAccess.remove_absolute(Spectacles.path)
	_off_is_exactly_one()
	_one_inside_the_limit_and_rising_without_a_step()
	_the_floor_and_the_cap_hold()
	_a_slow_craft_stands_on_its_wheels()
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	for i in range(240):
		await get_tree().physics_frame
	_rig = _level.rig
	_check("a_rig_in_an_aircraft", _rig != null and _rig.vehicle_view() != null,
		"rig %s, view %s" % [_rig, _rig.vehicle_view() if _rig != null else null])
	if _rig == null or _rig.vehicle_view() == null:
		_finish()
		return
	_check("spotting_size_starts_off", not _rig.spectacles.is_on(), Spectacles.STRENGTH_WORDS[_rig.spectacles.strength])
	await _put_out_fighters()
	await _far_fighters_are_drawn_bigger()
	await _the_craft_you_are_in_is_never_scaled()
	await _the_simulation_never_sees_it()
	await _the_board_sets_it_and_it_is_kept()
	await _what_it_costs()
	_finish()


## ---- the curve --------------------------------------------------------------------------------------------------

func _sizes() -> Array[float]:
	# A GLIDER-SIZED CRAFT, THE FIGHTER, AND AN AIRLINER, off the shape table.
	return [Spectacles.size_of(Sim.Kind.CESSNA), Spectacles.size_of(Sim.Kind.FIGHTER),
		Spectacles.size_of(Sim.Kind.AIRLINER)]


func _off_is_exactly_one() -> void:
	var worst: float = 0.0
	for size in _sizes():
		for near in Spectacles.NEAR_STEPS:
			for d in range(0, 30001, 7):
				worst = maxf(worst, absf(Spectacles.scale_for(float(d), size, Spectacles.Strength.OFF, near) - 1.0))
	_check("off_every_scale_is_exactly_one", worst == 0.0, "worst %.9f" % worst)


func _one_inside_the_limit_and_rising_without_a_step() -> void:
	var inside_worst: float = 0.0
	var fell: Array[String] = []
	var steepest: float = 0.0
	var steepest_at: String = ""
	var shrank: Array[String] = []
	for which in [Spectacles.Strength.LOW, Spectacles.Strength.MEDIUM, Spectacles.Strength.HIGH]:
		for near in Spectacles.NEAR_STEPS:
			for size in _sizes():
				var was: float = Spectacles.scale_for(0.0, size, which, near)
				for d in range(1, 25001):
					var now: float = Spectacles.scale_for(float(d), size, which, near)
					if float(d) <= near:
						inside_worst = maxf(inside_worst, absf(now - 1.0))
					if now < was:
						fell.append("%s near %d size %.1f at %d m" % [Spectacles.STRENGTH_WORDS[which], near, size, d])
					# THE LOOK: scale over distance. Coming one metre nearer, it may not get smaller.
					if d > 1 and now / float(d) > was / float(d - 1) * (1.0 + 1e-9):
						shrank.append("%s near %d size %.1f at %d m" % [Spectacles.STRENGTH_WORDS[which], near, size, d])
					if now - was > steepest:
						steepest = now - was
						steepest_at = "%s near %d size %.1f at %d m" % [Spectacles.STRENGTH_WORDS[which], near, size, d]
					was = now
	_check("inside_the_limit_every_scale_is_exactly_one", inside_worst == 0.0, "worst %.9f" % inside_worst)
	_check("past_it_the_scale_never_falls", fell.is_empty(), "fell %s" % [fell.slice(0, 3)])
	_check("and_never_steps_more_than_%s_in_a_metre" % MOST_A_METRE, steepest <= MOST_A_METRE,
		"steepest %.6f a metre, %s" % [steepest, steepest_at])
	_check("and_an_aircraft_coming_closer_never_looks_smaller", shrank.is_empty(),
		"%d metres where it did, first %s" % [shrank.size(), shrank.slice(0, 3)])


func _the_floor_and_the_cap_hold() -> void:
	var size: float = Spectacles.size_of(Sim.Kind.FIGHTER)
	var rows: PackedStringArray = []
	var broken: PackedStringArray = []
	for which in [Spectacles.Strength.LOW, Spectacles.Strength.MEDIUM, Spectacles.Strength.HIGH]:
		var floor_rad: float = deg_to_rad(Spectacles.FLOOR_ARCMIN[which] / 60.0)
		var cap: float = Spectacles.CAP[which]
		var row: PackedStringArray = []
		for d in DISTANCES:
			var times: float = Spectacles.scale_for(d, size, which, Spectacles.DEFAULT_NEAR)
			var seen_arcmin: float = rad_to_deg(times * size / d) * 60.0
			row.append("%dkm x%.2f %.1f'" % [int(d / 1000.0), times, seen_arcmin])
			var at_cap: bool = is_equal_approx(times, cap)
			if times > cap + 1e-9 or times < 1.0 or (not at_cap and times * size / d < floor_rad * (1.0 - 1e-6)):
				broken.append("%s at %d m: x%.3f, %.1f arcmin" % [Spectacles.STRENGTH_WORDS[which], d, times, seen_arcmin])
		rows.append("%s %s" % [Spectacles.STRENGTH_WORDS[which], ", ".join(row)])
	print("[spotting] measure: fighter %.1f m, %s" % [size, " | ".join(rows)])
	_check("a_fighter_is_never_under_the_floor_unless_capped_nor_over_the_cap", broken.is_empty(), "%s" % [broken])


## A SLOW CRAFT IS SCALED ABOUT ITS WHEELS AND A FAST ONE ABOUT ITS MIDDLE: a fighter 5 km off on HIGH, parked on a
## slope, keeps the point under it where it was; flying, it keeps its middle.
func _a_slow_craft_stands_on_its_wheels() -> void:
	var glasses := Spectacles.new()
	glasses.strength = Spectacles.Strength.HIGH
	var rests: float = float((Sim.geometry_of(Sim.Kind.FIGHTER).get("extents", Vector3.ZERO) as Vector3).y)
	var pose := Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(4.0)).rotated(Vector3.UP, 0.7), Vector3(5000.0, 3.0, 0.0))
	var wheels: Vector3 = pose * Vector3(0.0, -rests, 0.0)
	var parked := Node3D.new()
	parked.transform = pose
	var times: float = glasses.magnify(parked, Sim.Kind.FIGHTER, Vector3.ZERO, {"velocity": Vector3(2.0, 0.0, 0.0)})
	var flying := Node3D.new()
	flying.transform = pose
	glasses.magnify(flying, Sim.Kind.FIGHTER, Vector3.ZERO, {"velocity": Vector3(180.0, 0.0, 0.0)})
	var parked_off: float = (parked.transform * Vector3(0.0, -rests, 0.0)).distance_to(wheels)
	var flying_off: float = flying.transform.origin.distance_to(pose.origin)
	_check("a_slow_craft_is_scaled_about_its_wheels_and_a_flying_one_about_its_middle",
		times > 2.0 and parked_off < 1e-4 and flying_off < 1e-4,
		"x%.2f, rests %.2f m; parked wheels moved %.6f m, flying middle moved %.6f m" % [times, rests, parked_off,
			flying_off])
	parked.free()
	flying.free()
	Spectacles.put_back_every_part()


## ---- the world ---------------------------------------------------------------------------------------------------

## A FIGHTER AT EACH DISTANCE, level with the rig's aircraft and out towards the middle of the map, flying itself.
func _put_out_fighters() -> void:
	var here: Vector3 = _rig.vehicle_view().global_position
	var inward: Vector3 = Vector3(-here.x, 0.0, -here.z)
	inward = inward.normalized() if inward.length() > 1.0 else Vector3.RIGHT
	var across: Vector3 = inward.cross(Vector3.UP).normalized()
	var before: Dictionary = _fighters_drawn()
	for i in range(DISTANCES.size()):
		var at: Vector3 = here + inward * DISTANCES[i] + across * float(i) * 40.0
		at.y = maxf(here.y, 0.0) + 1500.0
		Sim.spawn_ai_vehicle(Sim.Kind.FIGHTER, at, 0.0, Vector3.ZERO)
	for i in range(PATIENCE):
		await get_tree().physics_frame
	_fighters = _new_fighters(before)
	_check("five_fighters_are_put_out_and_drawn", _fighters.size() == DISTANCES.size(),
		"%d of %d" % [_fighters.size(), DISTANCES.size()])


## EVERY FIGHTER THIS MACHINE DRAWS, by ITS entity id. Asked of the drawing and not kept from the spawn: the server hands
## back the server's id, and a solo game's client world numbers its entities for itself -- the first run of this suite
## looked up a spawned fighter's id on the client and found a boat.
func _fighters_drawn() -> Dictionary:
	var out: Dictionary = {}
	for entity in _level.get("_views"):
		if (_level.view_of(int(entity)) as VehicleView).kind == Sim.Kind.FIGHTER:
			out[int(entity)] = true
	return out


func _new_fighters(before: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for entity in _fighters_drawn():
		if not before.has(entity):
			out.append(entity)
	return out


func _scale_of(view: Node3D) -> float:
	return view.basis.get_scale().x


func _far_fighters_are_drawn_bigger() -> void:
	# THE FARTHEST FIGHTER'S DISTANCE-LOD PARTS, with their ranges as the LOD set them, before anything is magnified.
	var far_view: VehicleView = _level.view_of(_fighters[-1])
	var lod_before: Dictionary = _lod_ranges(far_view)
	_rig.spectacles.strength = Spectacles.Strength.HIGH
	_rig.spectacles.near_m = Spectacles.DEFAULT_NEAR
	await _frames(3)
	var far_times: float = _scale_of(far_view)
	var lod_on: Dictionary = _lod_ranges(far_view)
	var stretched_wrong: int = 0
	for part in lod_before:
		if absf(float(lod_on[part]) / float(lod_before[part]) - far_times) > far_times * Spectacles.RESTRETCH:
			stretched_wrong += 1
	_check("a_magnified_crafts_lod_parts_are_hidden_as_far_out_as_its_scale", not lod_before.is_empty()
		and stretched_wrong == 0, "%d parts with a range on a craft drawn x%.2f, %d not stretched by it" % [
			lod_before.size(), far_times, stretched_wrong])
	var rows: PackedStringArray = []
	var wrong: PackedStringArray = []
	var size: float = Spectacles.size_of(Sim.Kind.FIGHTER)
	for entity in _fighters:
		var view: VehicleView = _level.view_of(entity)
		if view == null:
			continue
		var away: float = view.global_position.distance_to(_rig.eye_position())
		var wanted: float = Spectacles.scale_for(away, size, Spectacles.Strength.HIGH, Spectacles.DEFAULT_NEAR)
		rows.append("%.0f m x%.3f (curve x%.3f; entity %d kind %d, drawn this frame %s, own %s)" % [away, _scale_of(view),
			wanted, entity, view.kind, Sim.current.has(entity), view == _rig.vehicle_view()])
		if absf(_scale_of(view) - wanted) > 0.01 * wanted:
			wrong.append(rows[-1])
	print("[spotting] measure: HIGH in the world: %s" % ", ".join(rows))
	_check("with_high_on_each_far_fighter_is_drawn_at_the_curves_scale", wrong.is_empty() and rows.size() == 5,
		"%s" % [wrong if not wrong.is_empty() else rows])
	var biggest: float = 1.0
	for entity in _fighters:
		if _level.view_of(entity) != null:
			biggest = maxf(biggest, _scale_of(_level.view_of(entity)))
	_check("and_the_far_ones_really_are_bigger", biggest > 3.0, "biggest x%.3f" % biggest)
	_rig.spectacles.strength = Spectacles.Strength.OFF
	await _frames(2)
	var worst: float = 0.0
	for view in _level.get("_views").values():
		worst = maxf(worst, absf(_scale_of(view as Node3D) - 1.0))
	_check("and_with_it_off_every_craft_is_back_to_one_on_the_next_frame", worst < 1e-5, "worst %.7f" % worst)
	_check("and_every_lod_range_is_put_back", _lod_ranges(far_view) == lod_before and Spectacles.stretched_count() == 0,
		"same %s, %d craft still stretched" % [_lod_ranges(far_view) == lod_before, Spectacles.stretched_count()])


## EVERY PART OF `view` WITH A VISIBILITY RANGE, instance id -> its end. See `AircraftVisualLod`.
static func _lod_ranges(view: Node3D) -> Dictionary:
	var out: Dictionary = {}
	for node in view.find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).visibility_range_end > 0.0:
			out[node.get_instance_id()] = (node as GeometryInstance3D).visibility_range_end
	return out


## THE CRAFT YOU ARE IN, AND WHOEVER SITS IN IT WITH YOU. A crewmate seated by the server, then HIGH with the nearest
## limit; and then the level's own pass handed an eye 8 km off the craft, which would scale it were it not excluded.
func _the_craft_you_are_in_is_never_scaled() -> void:
	var own: VehicleView = await _take(Sim.Kind.PLANE)
	_check("the_rig_takes_a_two_seat_aeroplane", own != null, "%s" % own)
	if own == null:
		return
	var mate: int = await _seat_a_mate(own)
	_check("a_crewmate_is_seated_in_your_aircraft", mate != 0, "client %d" % mate)
	_rig.spectacles.strength = Spectacles.Strength.HIGH
	_rig.spectacles.near_m = Spectacles.NEAR_STEPS[0]
	await _frames(3)
	var pilots: Dictionary = _level.get("_pilots")
	var theirs: Node3D = pilots.get(mate, null) as Node3D
	_check("your_aircraft_is_its_true_size", absf(_scale_of(own) - 1.0) < 1e-6, "x%.7f" % _scale_of(own))
	_check("and_so_is_your_crewmate", theirs != null and absf(theirs.global_basis.get_scale().x - 1.0) < 1e-6,
		"x%s" % [theirs.global_basis.get_scale().x if theirs != null else "no pilot drawn"])
	# THE PASS ITSELF, WITH THE EYE FAR OFF. Every view is put back to its true pose first, since the pass scales what
	# it is handed.
	for view in _level.get("_views").values():
		(view as VehicleView).draw()
	var seen: Dictionary = {}
	for entity in _level.get("_views"):
		seen[entity] = true
	var far_eye: Vector3 = own.global_position + Vector3(8000.0, 0.0, 0.0)
	_level.call("_draw_through_the_spectacles", seen, far_eye)
	var would: float = Spectacles.scale_for(8000.0, Spectacles.drawn_size(own.kind), Spectacles.Strength.HIGH,
		Spectacles.NEAR_STEPS[0])
	_check("even_seen_from_8_km_off_your_aircraft_is_not_scaled", absf(_scale_of(own) - 1.0) < 1e-6,
		"x%.4f, where the curve would give x%.3f" % [_scale_of(own), would])
	_rig.spectacles.strength = Spectacles.Strength.OFF
	_rig.spectacles.near_m = Spectacles.DEFAULT_NEAR
	await _frames(2)


## WITH THE SIMULATION HELD STILL, ONE FRAME OFF AND ONE ON: the same world drawn twice.
func _the_simulation_never_sees_it() -> void:
	Sim.set_physics_process(false)
	Sim.previous = Sim.current
	await _frames(2)
	var off: Dictionary = _snapshot()
	_rig.spectacles.strength = Spectacles.Strength.HIGH
	await _frames(2)
	var on: Dictionary = _snapshot()
	_rig.spectacles.strength = Spectacles.Strength.OFF
	Sim.set_physics_process(true)
	var unit: bool = true
	for entity in Sim.current:
		if absf(Sim.vehicle_transform(int(entity)).basis.get_scale().x - 1.0) > 1e-5:
			unit = false
	var scaled: int = 0
	for entity in on["scales"]:
		scaled += 1 if float(on["scales"][entity]) > 1.0 + 1e-4 else 0
	_check("held_still_turning_it_on_scales_far_craft", scaled >= 3, "%d craft drawn bigger" % scaled)
	var sim_same: bool = _alike(on["sim"], off["sim"])
	_check("and_every_transform_the_simulation_hands_out_is_unit_scale", unit and sim_same,
		"unit %s, the same %s" % [unit, sim_same])
	_check("and_every_drawn_craft_stands_where_it_stood", _alike(on["places"], off["places"]),
		"%d places" % off["places"].size())
	_check("and_the_eye_and_your_aircraft_are_where_they_were",
		_alike({0: on["eye"], 1: on["own"]}, {0: off["eye"], 1: off["own"]}),
		"eye %s against %s" % [on["eye"], off["eye"]])
	_check("and_your_aircrafts_contacts_read_the_same", on["contacts"] == off["contacts"],
		"%d contacts" % (off["contacts"] as Array).size())


## WHETHER TWO SNAPSHOTS' TRANSFORMS OR PLACES AGREE to a hundredth of a millimetre. Not exactly: the level draws at
## Godot's physics fraction, which moves between frames, and slerping two equal quaternions at two fractions differs in
## the last bit.
static func _alike(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a:
		if not b.has(key):
			return false
		var one: Variant = a[key]
		var two: Variant = b[key]
		if one is Transform3D:
			if not ((one as Transform3D).origin.distance_to((two as Transform3D).origin) < 1e-5
					and ((one as Transform3D).basis.x - (two as Transform3D).basis.x).length() < 1e-6
					and ((one as Transform3D).basis.y - (two as Transform3D).basis.y).length() < 1e-6):
				return false
		elif (one as Vector3).distance_to(two as Vector3) > 1e-5:
			return false
	return true


func _snapshot() -> Dictionary:
	var sim: Dictionary = {}
	for entity in Sim.current:
		sim[entity] = Sim.vehicle_transform(int(entity))
	var places: Dictionary = {}
	var scales: Dictionary = {}
	for entity in _level.get("_views"):
		var view: VehicleView = _level.view_of(int(entity))
		# WHERE IT STANDS: its middle, or for a slow craft the bottom of its hull, which a magnified slow craft is scaled
		# about (`Spectacles.SLOW`) -- so a parked aeroplane lifted by the scale is still standing where it stood.
		var slow: bool = ((Sim.current.get(entity, {}) as Dictionary).get("velocity", Vector3.ZERO) as Vector3).length() 			< Spectacles.SLOW
		var rests: float = float((Sim.geometry_of(view.kind).get("extents", Vector3.ZERO) as Vector3).y)
		places[entity] = view.transform * (Vector3(0.0, -rests, 0.0) if slow and Spectacles.magnifies(view.kind) 			else Vector3.ZERO)
		scales[entity] = _scale_of(view)
	var own: VehicleView = _rig.vehicle_view()
	return {"sim": sim, "places": places, "scales": scales, "eye": _rig.eye_position(), "own": own.global_transform,
		"contacts": own.craft_state().get("contacts", [])}


## THE SPOTTING TAB, WORKED WITH THE RIGHT HAND'S BEAM AND TRIGGER, and a fresh rig reading what it left.
func _the_board_sets_it_and_it_is_kept() -> void:
	var board: Clipboard = _rig.clipboard
	var page: ClipboardPage = board.page()
	board.show_board(true)
	page.show_tab(ClipboardPage.Tab.CRAFT)
	await _frames(3)
	var tabs: Array = page.get("_tabs")
	await _beam_presses(_rig, tabs[ClipboardPage.Tab.SPOTTING] as Control)
	_check("the_beam_on_the_spotting_tab_turns_to_it", page.tab() == ClipboardPage.Tab.SPOTTING
		and page.spotting_page().is_visible_in_tree(), "on tab %d" % page.tab())
	var spotting: SpottingPage = page.spotting_page()
	_check("it_shows_off_to_start", int(spotting.shown()["strength"]) == Spectacles.Strength.OFF
		and spotting.strength_button(Spectacles.Strength.OFF).button_pressed,
		"%s" % [spotting.shown()])
	await _beam_presses(_rig, spotting.strength_button(Spectacles.Strength.MEDIUM))
	_check("the_beam_on_medium_puts_medium_on", _rig.spectacles.strength == Spectacles.Strength.MEDIUM
		and spotting.strength_button(Spectacles.Strength.MEDIUM).button_pressed
		and not spotting.strength_button(Spectacles.Strength.OFF).button_pressed,
		"rig %s, page %s" % [Spectacles.STRENGTH_WORDS[_rig.spectacles.strength], spotting.shown()])
	_check("and_the_page_says_what_medium_does", String(spotting.shown()["says"]).begins_with("MEDIUM: a fighter 10 km"),
		"'%s'" % spotting.shown()["says"])
	await _beam_presses(_rig, spotting.near_button(1000.0))
	_check("the_beam_on_1_km_sets_the_limit", is_equal_approx(_rig.spectacles.near_m, 1000.0)
		and spotting.near_button(1000.0).button_pressed and not spotting.near_button(500.0).button_pressed,
		"rig %.0f m, page %s" % [_rig.spectacles.near_m, spotting.shown()])
	board.show_board(false)
	await _frames(2)
	# A RESTART: a new rig, as the next session makes one, reads the file the board left.
	var fresh := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(fresh)
	await _frames(2)
	var fresh_shows: Dictionary = fresh.clipboard.page().spotting_page().shown()
	_check("and_both_are_kept_for_the_next_session",
		fresh.spectacles.strength == Spectacles.Strength.MEDIUM and is_equal_approx(fresh.spectacles.near_m, 1000.0)
			and int(fresh_shows["strength"]) == Spectacles.Strength.MEDIUM,
		"a fresh rig wears %s within %.0f m and its board shows %s" % [Spectacles.STRENGTH_WORDS[fresh.spectacles.strength],
			fresh.spectacles.near_m, fresh_shows])
	fresh.queue_free()
	_rig.choose_spotting(Spectacles.Strength.OFF)
	_rig.choose_spotting_near(Spectacles.DEFAULT_NEAR)
	await _frames(2)


## WHAT THE PASS COSTS, AT 64 FIGHTERS: 59 more put out between 2 and 15 km, HIGH on, the lap timed over 240 frames.
func _what_it_costs() -> void:
	var here: Vector3 = _rig.vehicle_view().global_position
	var before: Dictionary = _fighters_drawn()
	for i in range(59):
		var angle: float = TAU * float(i) / 59.0
		var d: float = 2000.0 + 13000.0 * float(i % 7) / 6.0
		var at: Vector3 = here + Vector3(cos(angle), 0.0, sin(angle)) * d
		at.y = maxf(here.y, 0.0) + 1200.0 + float(i % 5) * 150.0
		Sim.spawn_ai_vehicle(Sim.Kind.FIGHTER, at, angle, Vector3.ZERO)
	await _frames(PATIENCE)
	var fighters_drawn: int = _fighters.size() + _new_fighters(before).size()
	_rig.spectacles.strength = Spectacles.Strength.HIGH
	var watch: Script = load("res://world/stopwatch.gd") as Script
	watch.call("run", true)
	await _frames(10)
	watch.call("take")
	var writes_before: int = Spectacles.writes
	var frames: int = 240
	var spent: int = 0
	var drawing: int = 0
	for i in range(frames):
		await get_tree().process_frame
		var laps: Dictionary = watch.call("take")
		spent += int(laps.get(&"vehicles_spectacles", 0))
		drawing += int(laps.get(&"vehicles_draw", 0))
	watch.call("run", false)
	var rewrites: int = Spectacles.writes - writes_before
	_rig.spectacles.strength = Spectacles.Strength.OFF
	var each: float = float(spent) / float(frames)
	print("[spotting] measure: %d fighters drawn of %d views, spectacles %.1f us a frame against drawing them %.1f us, %d craft's LOD ranges rewritten in %d frames" % [
		fighters_drawn, (_level.get("_views") as Dictionary).size(), each, float(drawing) / float(frames), rewrites, frames])
	_check("sixty_four_fighters_are_drawn", fighters_drawn >= 64, "%d" % fighters_drawn)
	var share: float = float(spent) / float(maxi(drawing, 1))
	_check("and_the_pass_costs_under_a_tenth_of_drawing_them", share < MOST_SHARE,
		"%.1f us a frame, %.1f per cent of drawing them" % [each, share * 100.0])


## ---- getting about ------------------------------------------------------------------------------------------------

## INTO A CRAFT OF `kind`, by the rig's own request, as tests/crew_sync.gd takes one.
func _take(kind: int) -> VehicleView:
	var view: VehicleView = _rig.vehicle_view()
	if view != null and view.kind == kind:
		return view
	_rig.ask_for_kind(kind)
	for i in range(600):
		await get_tree().physics_frame
		view = _rig.vehicle_view()
		if view != null and view.kind == kind and view.station_for(_rig.seat_index()) != null:
			return view
	return null


## A SECOND CREW MEMBER IN A FREE SEAT OF `view`'s craft, seated by the server. Their client id, or 0.
func _seat_a_mate(view: VehicleView) -> int:
	# THE SERVER'S ID FOR THE CRAFT, off the server's own pilot list: `view.entity` is this machine's (see _fighters_drawn).
	var craft: int = 0
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", -1)) == Sim.local_client_id():
			craft = int((pilot as Dictionary).get("vehicle", 0))
	var poses: Array = Sim.geometry_of(view.kind).get("seat_poses", []) as Array
	var free: int = -1
	for seat in range(poses.size()):
		if seat != _rig.seat_index():
			free = seat
			break
	if free < 0:
		return 0
	var who: int = 250
	Sim.server.spawn_pilot(who, Sim.Kind.POD, view.global_position + Vector3(0.0, -200.0, 3000.0), 0.0, Vector3.ZERO)
	if not Sim.server.seat_client(who, craft, free):
		return 0
	for i in range(PATIENCE):
		await get_tree().physics_frame
		if (_level.get("_pilots") as Dictionary).has(who):
			return who
	return 0


func _beam_presses(rig: PilotRig, target: Control) -> void:
	# AS tests/clipboard.gd PRESSES: the right hand aimed at the control's middle on the glass, the trigger down for two
	# frames and up again.
	var centre: Vector2 = target.get_global_rect().get_center()
	for trigger in [0.0, 0.0, 1.0, 1.0, 0.0, 0.0]:
		var panel: TouchPanel = rig.clipboard.panel()
		var screen := panel.get("_screen") as SubViewport
		var on_glass := Vector3((centre.x / float(screen.size.x) - 0.5) * panel.size.x,
			(0.5 - centre.y / float(screen.size.y)) * panel.size.y, 0.0)
		var aimed_at: Vector3 = panel.to_global(on_glass)
		var hand_at: Vector3 = aimed_at + panel.global_basis.z.normalized() * 0.30
		rig.force_hand(RIGHT, Transform3D(Basis.looking_at(aimed_at - hand_at, panel.global_basis.y.normalized()), hand_at))
		rig.force_input(RIGHT, Bind.TRIGGER, trigger)
		await get_tree().process_frame
	rig.force_input(RIGHT, Bind.TRIGGER, null)
	rig.force_hand(RIGHT, null)
	await get_tree().process_frame


func _frames(how_many: int) -> void:
	for i in range(how_many):
		await get_tree().process_frame


func _finish() -> void:
	if FileAccess.file_exists(Spectacles.path):
		DirAccess.remove_absolute(Spectacles.path)
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
