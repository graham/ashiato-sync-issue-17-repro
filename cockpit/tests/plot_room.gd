extends Node
## Headless: is the carrier's flag plot a room somebody can work in, with no flight controls in it?
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/plot_room.tscn
##
## The carrier's fourth seat was a second 12.7 mm gun tub on the port quarter. On 2026-09-17 it became the FLAG PLOT: a
## compartment abaft the navigation bridge, on the same deck, where one person sits and watches the whole air picture
## (`world/air_picture.gd`) and tells pilots where to go. `kMaxSeats` is 4 and the carrier had already spent all four, so
## the seat was MOVED rather than added -- raising the limit re-hashes every craft package in the game for a seat nobody
## had asked for. The tub is still built and still drawn; it simply has nobody in it, which is true of most of the mounts
## on a real ship.
##
## WHAT IT HOLDS:
##   - the fourth seat is an `operator` standing on the floor of a `bridge` part -- the flag plot -- and NOT in the gun
##     tub it came from, with its head under the deckhead and clear of anything the physics calls solid;
##   - the flag plot is a SECOND bridge part, abaft the first, and the first is still the helm, because `part_of(s,
##     Part::Bridge)` takes the FIRST one and the whole ship is steered through it;
##   - the port-quarter tub is still a part of the ship, and no seat is in it;
##   - the carrier claims gun mount 0 alone, so nothing describes a gun nobody is behind;
##   - and NO FLIGHT CONTROL survives in the operator's station.
##
## THE LAST ONE IS THE REASON THIS FILE EXISTS. `_fit_the_operator_controls` stripped a list typed into it --
## `["Yoke", "Stick", "Trim", "Rudder"]` -- while `CockpitStation.STICK_NAMES`, the real authority, has held "Wheel" and
## "Brake" for as long as there have been ships. The carrier's seat scene is `seat_wheel.tscn` and its flying control is
## called "Wheel", so the FIRST operator ever seated on a ship sat at a helm. `Station::Operator` means `flies()` is
## false and the server refuses the input, which makes it worse and not better: a wheel that turns in your hands and
## steers nothing is the cockpit lying about what it can do.
##
## SO THIS SUITE ASKS `CockpitStation.STICK_NAMES` AND DOES NOT SPELL THE NAMES AGAIN. Had it typed its own list it
## would have inherited the very bug it is here to catch -- two lists that have to agree, of which one is a copy
## (CLAUDE.md rule 4). The mutant is to put the typed list back in `_fit_the_operator_controls`:
## `the_operators_station_has_no_flight_control` then names "Wheel" as the survivor.
##
## AND THE CONTROLS IT DOES HAVE ARE REACHABLE WITHOUT BEING THE SAME TARGET. The two selectors sat at x +/-0.19, which
## had never been fitted to a seat that owns a throttle: on `seat_wheel` the display knob landed 0.162 m from it, inside
## the 0.32 m (`VehicleControl.REACH * 2`) that `tests/fit.gd` refuses to let two grips share. The knobs moved; the
## tolerance did not, and it is read off `VehicleControl.REACH` here rather than typed.
##
## Read RESULT=, not the exit code.

const CARRIER: int = 12
## The seat the flag plot took over, and the one that still works the bow gun.
const OPERATOR_SEAT: int = 3
const GUNNER_SEAT: int = 2
## A seated head, and a head's width round the eye. The same numbers `boat_seats.gd` uses.
const EYE: float = 1.35
const HEAD: float = 0.25

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[plot_room] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var geometry: Dictionary = Sim.geometry_of(CARRIER)
	var poses: Array = geometry.get("seat_poses", []) as Array
	var parts: Array = geometry.get("parts", []) as Array
	_the_fourth_seat_is_an_operator(poses)
	_the_flag_plot_is_a_room_abaft_the_bridge(poses, parts)
	_each_deckhouse_is_glazed_where_it_can_see(parts)
	_the_tub_is_still_there_and_empty(poses, parts)
	_only_one_mount_is_crewed()
	_the_station_has_no_flight_control()
	_every_station_the_game_has_is_named_on_the_panel()
	_finish()


## WHICH WAY EACH DECKHOUSE LOOKS, asked of `Carrier._glazing_for` with the ship's real parts. The navigation bridge is
## glazed FORE, down the flight deck. The flag plot behind it has the bridge's own back wall against its forward face --
## a window there would look into the wheelhouse -- so it is glazed AFT, and an operator who looks up from the plot table
## sees the landing area, which is the view that makes the room worth sitting in.
##
## DERIVED FROM THE GEOMETRY rather than looked up per room: a deckhouse is glazed forward unless another deckhouse's
## after face is against its forward face. That is the claim, and it had no test of any kind until 2026-09-17 -- the
## glazing was changed and nothing in the suite could have noticed. The mutant returns `["fore", "port", "starboard"]`
## unconditionally and `and_the_flag_plot_is_glazed_aft_over_the_landing_area` goes red.
func _each_deckhouse_is_glazed_where_it_can_see(parts: Array) -> void:
	var bridges: Array = []
	for part in parts:
		if String(part["part"]) == "bridge":
			bridges.append(part)
	if bridges.size() != 2:
		return
	var helm: Array = Carrier._glazing_for(bridges[0], parts)
	var plot: Array = Carrier._glazing_for(bridges[1], parts)
	_check("the_navigation_bridge_is_glazed_forward_down_the_deck",
		"fore" in helm and not ("aft" in helm), "helm glazed %s" % [helm])
	_check("and_the_flag_plot_is_glazed_aft_over_the_landing_area",
		"aft" in plot and not ("fore" in plot), "flag plot glazed %s" % [plot])
	_check("and_both_of_them_keep_their_side_lights",
		"port" in helm and "starboard" in helm and "port" in plot and "starboard" in plot,
		"helm %s, flag plot %s" % [helm, plot])


## EVERY STATION WORD THE SIMULATION CAN PRODUCE HAS A SENTENCE ON THE PANEL, asked of every kind's `seat_poses` rather
## than of a list typed here.
##
## `VehicleHud.STATION` is read with `STATION.get(station, station.to_upper())`, so a word nobody added falls through to
## the bare "OPERATOR" -- which is a job title and tells a player nothing about what the seat may do. That is exactly what
## happened: the Mercury and the fighter had operator stations long before the carrier did, and neither ever said so. A
## roster read with a silent default cannot fail on its own; this is what makes it fail.
##
## IT LIVES IN THIS SUITE because the missing word was this lane's bug, and the suite that would otherwise own it does not
## exist. It is a game-wide check and should move the day there is a panel suite to move it to. Its mutant is to delete
## the "operator" line from `VehicleHud.STATION`.
func _every_station_the_game_has_is_named_on_the_panel() -> void:
	var words: Dictionary = {}
	for kind in range(Sim.Kind.size()):
		for pose in (Sim.geometry_of(kind).get("seat_poses", []) as Array):
			var word := String((pose as Dictionary).get("station", ""))
			if word != "":
				words[word] = true
	var unnamed: PackedStringArray = []
	for word in words:
		if not VehicleHud.STATION.has(word):
			unnamed.append(String(word))
	unnamed.sort()
	_check("every_station_the_simulation_can_seat_has_a_sentence_on_the_panel",
		unnamed.is_empty() and words.size() > 0,
		"%d station words across %d kinds%s" % [words.size(), Sim.Kind.size(),
			"" if unnamed.is_empty() else "; nothing written for %s" % [unnamed]])


## The fourth seat is an operator, and it kept its index and its facing. Both matter: the crew page, the join path and
## every gunner's mount are keyed by seat index, and the yaw is what makes the room worth sitting in -- facing aft, so
## looking up from the plot table is looking out over the landing area.
func _the_fourth_seat_is_an_operator(poses: Array) -> void:
	_check("the_carrier_still_has_four_seats", poses.size() == 4, "%d seats" % poses.size())
	if poses.size() != 4:
		return
	var pose: Dictionary = poses[OPERATOR_SEAT] as Dictionary
	_check("the_fourth_seat_is_an_operator_and_not_a_second_gunner",
		String(pose.get("station", "")) == "operator", "station %s" % [pose.get("station", "")])
	_check("and_an_operator_does_not_fly_the_ship", not bool(pose.get("flies", true)),
		"flies %s" % [pose.get("flies", true)])
	_check("and_it_still_faces_aft", absf(float(pose.get("yaw", 0.0)) - PI) < 0.01,
		"yaw %.4f rad against %.4f" % [float(pose.get("yaw", 0.0)), PI])


## The operator stands on the floor of a bridge part that is NOT the helm, with the deckhead over their head, and
## nothing solid where their head is. `carrier_shape` makes an island SOLID and a bridge not, which is the whole reason
## the flag plot was carved out of the island as a second `Part::Bridge` rather than having a seat dropped into it.
func _the_flag_plot_is_a_room_abaft_the_bridge(poses: Array, parts: Array) -> void:
	var bridges: Array = []
	for part in parts:
		if String(part["part"]) == "bridge":
			bridges.append(part)
	_check("the_island_holds_two_bridge_rooms_the_helm_and_the_flag_plot", bridges.size() == 2,
		"%d bridge parts" % bridges.size())
	if bridges.size() != 2 or poses.size() != 4:
		return
	var helm: Dictionary = bridges[0]
	var plot: Dictionary = bridges[1]
	var helm_rect: Rect2 = Wheelhouse.outline_rect(helm["outline"])
	var plot_rect: Rect2 = Wheelhouse.outline_rect(plot["outline"])
	# ABAFT means further aft in +z, and the helm has to stay FIRST because `part_of(s, Part::Bridge)` takes the first
	# bridge part and that is what the ship is steered from.
	_check("the_helm_is_the_first_bridge_part_and_the_plot_is_behind_it",
		plot_rect.position.y >= helm_rect.end.y - 0.01,
		"helm ends at z %.2f, plot starts at z %.2f" % [helm_rect.end.y, plot_rect.position.y])
	var seat: Vector3 = _seat_position(poses[OPERATOR_SEAT])
	var inside: bool = plot_rect.has_point(Vector2(seat.x, seat.z))
	_check("the_operator_is_inside_the_flag_plot", inside,
		"seat at (%.2f, %.2f) in x %.2f..%.2f z %.2f..%.2f" % [seat.x, seat.z,
			plot_rect.position.x, plot_rect.end.x, plot_rect.position.y, plot_rect.end.y])
	_check("and_stands_on_its_floor", absf(seat.y - float(plot["bottom"])) < 0.01,
		"seat y %.2f against a floor at %.2f" % [seat.y, float(plot["bottom"])])
	_check("and_the_deckhead_is_over_their_head", float(plot["top"]) - seat.y > EYE + HEAD * 0.5,
		"%.2f m of headroom against a %.2f m eye" % [float(plot["top"]) - seat.y, EYE])
	# NOTHING SOLID WHERE THE HEAD IS. The same question `carrier_shape._no_head_is_inside_anything_solid` asks of every
	# seat; asked again here because the flag plot was cut out of a part that WAS solid, and getting that wrong is the
	# one mistake this change could have made invisibly.
	var eye := Vector3(seat.x, seat.y + EYE, seat.z)
	var solid: PackedStringArray = []
	for part in parts:
		if not _is_solid(String(part["part"])):
			continue
		var r: Rect2 = Wheelhouse.outline_rect(part["outline"])
		var box := AABB(Vector3(r.position.x, float(part["bottom"]), r.position.y),
			Vector3(r.size.x, float(part["top"]) - float(part["bottom"]), r.size.y))
		if box.grow(HEAD * 0.5).has_point(eye):
			solid.append(String(part["part"]))
	_check("and_no_part_the_physics_calls_solid_is_where_their_head_is", solid.is_empty(),
		"eye at (%.2f, %.2f, %.2f)%s" % [eye.x, eye.y, eye.z,
			"" if solid.is_empty() else "; inside %s" % [solid]])


## What `collides()` in the C++ makes solid. Typed here on purpose: this is the independent statement, and reading it
## off the thing under test would pass whatever the ship was.
func _is_solid(role: String) -> bool:
	return role in ["hull", "deck", "island", "station"]


## The port-quarter tub is STILL BUILT -- a real ship has mounts with nobody in them -- and nobody is in it. Both halves
## matter: deleting the tub would have been the lazy way to make the seat count add up, and it would have taken a piece
## of the ship away to buy a room.
func _the_tub_is_still_there_and_empty(poses: Array, parts: Array) -> void:
	var tubs: Array = []
	for part in parts:
		if String(part["part"]) == "station":
			tubs.append(part)
	_check("both_gun_tubs_are_still_built", tubs.size() == 2, "%d station parts" % tubs.size())
	if tubs.size() != 2:
		return
	# Which tub has a seat standing on it, asked of the seats rather than assumed from their order.
	var manned: Array[int] = []
	for i in range(tubs.size()):
		var r: Rect2 = Wheelhouse.outline_rect(tubs[i]["outline"])
		for seat in range(poses.size()):
			var at: Vector3 = _seat_position(poses[seat])
			if r.has_point(Vector2(at.x, at.z)):
				manned.append(i)
				break
	_check("exactly_one_gun_tub_has_somebody_in_it", manned.size() == 1,
		"tubs with a seat in them: %s" % [manned])


## The carrier describes ONE gun, because it has one gunner. `ship_pintle_at` fills in a 12.7 mm's muzzle, reload and
## ammunition whatever seat works the mount, so a carrier that still claimed mount 1 would be describing a weapon nobody
## is behind -- and `shots.gd` would then count two armed mounts against one turret seat.
## `gun_of` ALWAYS HANDS BACK A GUN RECORD; what says whether there is a weapon there is its `fitted` flag, which is
## what every reader in the game asks (`cockpit_station.gd`, `vehicle_view.gd`). Asking `is_empty()` instead passed
## nothing and failed everything: a mount that falls through the C++ returns a default-constructed `Gun` with all
## fourteen fields present and `fitted` false, which is exactly the "unfitted gun" the narrowing was written to produce.
func _only_one_mount_is_crewed() -> void:
	var bow: Dictionary = Sim.gun_of(CARRIER, 0)
	var quarter: Dictionary = Sim.gun_of(CARRIER, 1)
	_check("the_bow_tub_is_a_fitted_gun", bool(bow.get("fitted", false)),
		"mount 0 fitted %s" % [bow.get("fitted", false)])
	_check("and_the_vacant_tub_describes_no_gun", not bool(quarter.get("fitted", false)),
		"mount 1 fitted %s" % [quarter.get("fitted", false)])
	_check("the_gunner_seat_still_works_mount_0", Sim.mount_of_seat(CARRIER, GUNNER_SEAT) == 0,
		"seat %d -> mount %d" % [GUNNER_SEAT, Sim.mount_of_seat(CARRIER, GUNNER_SEAT)])
	_check("and_the_operator_works_no_mount_at_all", Sim.mount_of_seat(CARRIER, OPERATOR_SEAT) < 0,
		"seat %d -> mount %d" % [OPERATOR_SEAT, Sim.mount_of_seat(CARRIER, OPERATOR_SEAT)])


## THE ONE THIS FILE EXISTS FOR. Build the operator's station the way the game does -- the craft's own seat scene, run
## through `fit` -- and ask `CockpitStation.STICK_NAMES` whether any of them survived. Asking the authority is the
## point: a list typed here would have had the same hole as the list that was typed in the code.
func _the_station_has_no_flight_control() -> void:
	var scene := VehicleCatalogue.seat_scene(CARRIER) as PackedScene
	if scene == null:
		_check("the_carrier_has_a_seat_scene", false, "none in the catalogue")
		return
	var was := CockpitStation.use_saved_layouts
	CockpitStation.use_saved_layouts = false
	var station := scene.instantiate() as CockpitStation
	add_child(station)
	station.fit(OPERATOR_SEAT, false, CARRIER, false)
	var left: PackedStringArray = []
	for named in CockpitStation.STICK_NAMES:
		if station.get_node_or_null(NodePath(named)) != null:
			left.append(named)
	_check("the_operators_station_has_no_flight_control", left.is_empty(),
		"asked %s of the seat scene%s" % [CockpitStation.STICK_NAMES,
			"" if left.is_empty() else "; still fitted: %s" % [left]])
	# AND IT HAS SOMETHING TO WORK. A station stripped of everything would pass the check above and be a chair.
	var knobs: Array = station.find_children("*", "RotaryKnob", true, false)
	_check("and_it_does_have_the_system_selectors", knobs.size() >= 1,
		"%d rotary knobs" % knobs.size())
	# NO TWO GRIPS INSIDE ONE HAND TARGET. `VehicleControl.REACH * 2` asked of the class, not typed, so the day the
	# reach moves this moves with it -- and it is the check the knobs' old position failed against the wheel's throttle.
	var grips: Array = []
	for node in station.find_children("*", "VehicleControl", true, false):
		var control := node as VehicleControl
		if control != null and control.taken_by() != Bind.Take.NONE:
			grips.append([control.name, control.grip_global()])
	var crowded: PackedStringArray = []
	for i in range(grips.size()):
		for j in range(i + 1, grips.size()):
			var apart: float = (grips[i][1] as Vector3).distance_to(grips[j][1] as Vector3)
			if apart < VehicleControl.REACH * 2.0:
				crowded.append("%s and %s %.3f m apart" % [grips[i][0], grips[j][0], apart])
	_check("and_no_two_of_its_controls_share_one_hand_target", crowded.is_empty(),
		"%d grips, floor %.2f m%s" % [grips.size(), VehicleControl.REACH * 2.0,
			"" if crowded.is_empty() else "; %s" % [crowded]])
	station.free()
	CockpitStation.use_saved_layouts = was


func _seat_position(pose: Variant) -> Vector3:
	return (pose as Dictionary).get("position", Vector3.ZERO) as Vector3


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
