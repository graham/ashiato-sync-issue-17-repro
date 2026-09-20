extends Node
## Headless: THE SIGNAL LAMP -- a part off the BUILD tab, at no seat until a player puts one there, arriving in a
## holster, picked up by a fist, snapped into the palm, left where it was let go, and flashed white, red and green by
## the holding hand's fingers, one colour at a time.
##
##   Godot --headless --path cockpit --xr-mode off res://tests/signal_lamp.tscn
##
## Asked for on 2026-09-18: a light gun that behaves like the director's camera -- "while holding it, it should
## move, and after releasing it it just stays whereever you left it (in relation to the player, so they can't lose
## it)" -- with "white, red, and green lights (trigger white), a = red, b = green (or x/y if the other controller).
## only one light at a time."
##
## And on 2026-09-19 (lane/lampopt): *"let's have the light gun (like the director camera) is optional, not always
## present and can be loaded via the ipad."* So no seat has one until "+ SIGNAL LAMP" is pressed on the BUILD tab.
##
## THE CRAFT IS REAL. Every section stands a whole `VehicleView` up from its craft scene, the way `tests/fit.gd`
## does, which mans every seat, and seats the rig in it. Then it PLACES A LAMP through the parts bin's own signal
## (`chose_part`, what a "+ SIGNAL LAMP" press emits); `_the_build_tab_puts_one_in_its_holster` presses the button
## itself, with the beam and the trigger. "Stays with the player" is then measured by flying THE CRAFT: the
## view is moved and turned, and the lamp must go with it.
##
## EVERYTHING GOES THROUGH THE RIG'S SEAMS -- `force_hand`, `force_grip`, `force_input` and the desk's own input
## actions -- which is the path a headset and a keyboard take. Nothing here calls `SignalLamp.ask` or
## `offer_hand_to_place`.
##
## MUTANTS, each applied alone and reverted, with the line that went red:
##   * `VehicleView.man` holstering a lamp at every seat again, as it did before lane/lampopt (2026-09-19)
##       FAIL no_seat_of_any_craft_has_a_lamp_until_one_is_placed (a lamp at 101 of 101 seats: airliner seat 0, ...)
##       FAIL the_seat_starts_with_no_lamp
##   * the newest-press stack replaced by "the first colour held stays lit" (`_asking.front()`)
##       FAIL a_second_finger_takes_over_right (lit white, lens 4.0 (1.0, 0.97, 0.9, 1.0), 1 pips)
##   * `offer_hand_to_place` not snapping the grip into the palm (the camera's carry)
##       FAIL it_sits_in_the_palm (grip 0.0374 m from the palm)
##       FAIL and_it_points_where_the_hand_points (37.96 degrees apart)
##   * the lamp moved to the world's frame when it is let go
##       FAIL it_stays_where_it_was_left_in_the_seat_as_the_craft_flies_and_turns (216.8914 m from where it was left)
##   * `own_seat_only` ignored by the rig
##       FAIL seat_one_cannot_take_seat_zeros_lamp (held_by 1)
##   * `SignalLamp._hides_a_face` no longer refusing a spot that overlaps a face (2026-09-19, after lane/crewboard put the
##     crew board's placard beside the hip, where this holster's search starts):
##       FAIL and_no_holstered_lamp_stands_in_the_crew_boards_placard (in it at carrier seat 2, cb90 seat 2, gunboat
##       seat 1, gunboat seat 2, train seat 3)
##
## Read RESULT=, not the exit code.

const CRAFT: String = "plane"
## The pointing hand, and the one the lamp is carried in unless a section says otherwise.
const HAND: int = 1
const OTHER: int = 0

## HOLSTERS THIS CHECK FOUND THROUGH THEIR CRAFT'S SKIN ON ITS FIRST RUN (2026-09-19), each named with what would fix it
## and printed on every run, as `tests/joined_parts.gd`'s DETACHED list is. The cure is the Duo Discus's: the airframe
## answers `encloses` from its own sections, and `VehicleView.holster_fits` fences the search with it. A craft listed
## here whose lamp comes inside fails the check until it is taken off, so the list cannot go stale.
const OUTSIDE_KNOWN: Dictionary = {
	"falcon/0": "the lamp stands up through the canopy's side at the hip: FalconAirframe answers no `encloses` yet",
	"littlebird/0": "the lamp stands out in the open doorway, under the roof's edge: LittleBirdAirframe answers no `encloses` yet",
	"p51/0": "a Mustang's cockpit is glass at hip height and knees below it, so the search has nowhere inside: every spot outboard of 0.15 m is through the canopy's side, and every spot inboard of it is in the knees. The cure is the seat authoring its own holster, as `seat_warthog.tscn` authors its master arm (todo/warbirds2--p51-lamp-holster.md)",
}
## A RAY FROM A HOLSTERED LAMP MUST MEET THE CRAFT BEFORE `seat_room`'s `FAR` (4 m), where its caster stops and reports
## the distance as FAR. Not `tests/pilot_seat.gd`'s 2.2 m, which is a cockpit's: the carrier's flag plot is a room whose
## starboard wall stands further off than that. And not more than FAR: a first try at 10 m passed every lamp, the glider's
## hanging outside its pod included, because a miss reads 4.0 (2026-09-19). A lamp OUTSIDE a skin has a side open to the
## sky however far the ray goes, so FAR still finds it.

var _failures: PackedStringArray = []
var _sections: int = 0
## Colours the lamp announced, in order, while a section is listening.
var _said: Array[int] = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[signal_lamp] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	CockpitStation.use_saved_layouts = false
	_it_is_a_part_and_no_seat_has_one()
	await _the_build_tab_puts_one_in_its_holster()
	_every_seat_of_every_craft_has_one_in_reach()
	await _a_fist_takes_it_and_it_sits_in_the_palm()
	await _let_go_it_stays_with_the_seat_as_the_craft_flies()
	await _the_holding_hands_fingers_are_the_colours(HAND)
	await _the_holding_hands_fingers_are_the_colours(OTHER)
	await _a_lamp_in_nobodys_hand_is_dark()
	await _the_desk_keys_flash_it_and_zero_puts_it_back()
	await _another_seats_lamp_is_not_yours_to_take()
	_check("every_section_of_the_suite_ran", _sections == 10, "%d of 10" % _sections)
	_finish()


## ---- what it is --------------------------------------------------------------------------------

func _it_is_a_part_and_no_seat_has_one() -> void:
	_check("the_parts_bin_offers_a_lamp", ControlCatalogue.has(&"SignalLamp")
		and ControlCatalogue.label_of(&"SignalLamp") == "SIGNAL LAMP",
		"%d parts, labelled %s" % [ControlCatalogue.PARTS.size(), ControlCatalogue.label_of(&"SignalLamp")])
	var refused: PackedStringArray = []
	for kind in range(Sim.Kind.size()):
		if not VehicleCatalogue.allowed(kind).has(&"SignalLamp"):
			refused.append(Sim.kind_name(kind))
	_check("and_every_craft_allows_one", refused.is_empty(),
		"all %d kinds" % Sim.Kind.size() if refused.is_empty() else "not on %s" % ", ".join(refused))
	# NO SEAT OF ANY CRAFT HAS ONE, fully manned: `_show_in_editor` mans every seat, as `VehicleView.man` does in flight.
	var seats: int = 0
	var lamps: PackedStringArray = []
	for name in _craft_names():
		var view := _craft(name)
		if view == null:
			continue
		for seat in range(view.seats.size()):
			var station: CockpitStation = view.station_for(seat)
			if station == null:
				continue
			seats += 1
			if SignalLamp.in_station(station) != null:
				lamps.append("%s seat %d" % [name, seat])
		view.free()
	_check("no_seat_of_any_craft_has_a_lamp_until_one_is_placed", lamps.is_empty() and seats > 40,
		"none at %d seats" % seats if lamps.is_empty() else "a lamp at %d of %d seats: %s" % [lamps.size(), seats,
			", ".join(lamps.slice(0, 4))])
	# AND NO AUTHORED PACKAGE CARRIES ONE, which is what every station is built from.
	var packaged: PackedStringArray = []
	var read: int = 0
	for kind in range(Sim.Kind.size()):
		for seat in range((Sim.geometry_of(kind).get("seat_poses", []) as Array).size()):
			var loaded: Dictionary = AuthoredCraftPackages.read_station(kind, seat)
			if loaded.has("station"):
				read += 1
			for entry in (loaded.get("station", {}) as Dictionary).get("controls", []) as Array:
				if String((entry as Dictionary).get("part", "")) == "SignalLamp":
					packaged.append("%s seat %d" % [Sim.kind_name(kind), seat])
	_check("and_no_authored_package_has_one", packaged.is_empty() and read > 40,
		"none in %d stations" % read if packaged.is_empty() else ", ".join(packaged))
	var lamp := SignalLamp.new()
	lamp.setup(0)
	_check("a_lamp_is_taken_by_the_fist", lamp.taken_by() == Bind.Take.GRIP, "taken_by %d" % lamp.taken_by())
	_check("and_carried_while_flying", lamp.carried_by_hand(), "carried_by_hand")
	_check("and_only_by_its_own_seat", lamp.own_seat_only(), "own_seat_only")
	_check("and_it_starts_dark", lamp.lit == SignalLamp.DARK and lamp.lens_energy() == 0.0,
		"lit %s, lens %.2f" % [SignalLamp.colour_name(lamp.lit), lamp.lens_energy()])
	_check("and_says_on_the_wire_that_it_is_there", SignalLamp.is_fitted_value(lamp.packed())
		and not SignalLamp.is_fitted_value(0) and not SignalLamp.is_fitted_value(-1), "packed %d" % lamp.packed())
	lamp.free()
	_sections += 1


## THE BUILD TAB PUTS ONE IN ITS HOLSTER: the beam on "+ SIGNAL LAMP" and a pull of the trigger, the way
## `tests/clipboard.gd` presses a button, once the thumb has walked the bin down to it. Then a second press is
## refused, the layout written down and read back has it where it was, and the builder's bin takes it away.
func _the_build_tab_puts_one_in_its_holster() -> void:
	var kit: Dictionary = await _a_seat(0, HAND, false)
	var rig: PilotRig = kit["rig"]
	var station: CockpitStation = kit["station"]
	var view: VehicleView = kit["view"]
	_check("the_seat_starts_with_no_lamp", SignalLamp.in_station(station) == null, "%s" % SignalLamp.in_station(station))
	var button: Button = await _show_the_lamp_button(rig)
	_check("the_build_tab_offers_plus_signal_lamp", button != null and button.is_visible_in_tree(),
		"on the glass" if button != null else "no such button")
	if button == null:
		_forget(kit)
		_sections += 1
		return
	await _beam_presses(rig, button)
	await _frames(2)
	var lamp: SignalLamp = SignalLamp.in_station(station)
	_check("a_press_with_the_beam_and_the_trigger_puts_one_at_the_seat", lamp != null and lamp.get_parent() == station,
		"%s" % lamp)
	if lamp == null:
		_forget(kit)
		_sections += 1
		return
	# IN THE HOLSTER THE SEARCH FINDS, and not in front of the seat where other parts land.
	var searched: Vector3 = SignalLamp.holster_spot(_grips_but(view, station, lamp), SignalLamp.faces_in(station),
		view.holster_fits(station, 0))
	_check("in_the_holster_the_search_finds", lamp.position.distance_to(searched) < 0.001,
		"%.4f m from the searched spot" % lamp.position.distance_to(searched))
	_check("on_its_own_seats_channel", lamp.channel == SignalLamp.channel_for(0) and lamp.channel >= 0,
		"channel %d, the seat's %d" % [lamp.channel, SignalLamp.channel_for(0)])
	_check("and_within_the_hands_reach", rig._reachable.has(lamp), "%d reachable" % rig._reachable.size())
	# ONE TO A SEAT.
	button = await _show_the_lamp_button(rig)
	await _beam_presses(rig, button)
	await _frames(2)
	var count: int = 0
	for child in station.get_children():
		if child is SignalLamp:
			count += 1
	_check("a_second_press_is_refused_one_to_a_seat", count == 1, "%d lamps" % count)
	# WRITTEN DOWN AND READ BACK, as a saved cockpit is: in the file, and at the same place in a fresh station.
	var saved: Dictionary = CockpitLayout.of_station(Sim.Kind.PLANE, 0, station)
	var listed: bool = false
	for entry in saved.get("controls", []) as Array:
		listed = listed or String((entry as Dictionary).get("part", "")) == "SignalLamp"
	_check("it_is_saved_with_the_layout", listed, "%d controls in the file" % (saved.get("controls", []) as Array).size())
	var built: Dictionary = AuthoredCraftPackages.make_station(Sim.Kind.PLANE, 0)
	var fresh := built.get("station") as CockpitStation
	_check("a_fresh_station_is_built", fresh != null, "%s" % built.get("error", "built"))
	if fresh != null:
		add_child(fresh)
		_check("and_has_no_lamp", SignalLamp.in_station(fresh) == null, "%s" % SignalLamp.in_station(fresh))
		CockpitLayout.apply(JSON.parse_string(JSON.stringify(saved)) as Dictionary, fresh, 0)
		var back: SignalLamp = SignalLamp.in_station(fresh)
		_check("and_reloaded_the_lamp_is_back_where_it_was", back != null
			and back.position.distance_to(lamp.position) < 0.001 and back.channel == SignalLamp.channel_for(0),
			"missing" if back == null else "%.4f m away, channel %d" % [back.position.distance_to(lamp.position),
				back.channel])
		fresh.free()
	# BINNED IN THE BUILDER: a fist on it and the lower thumb, which is how any part is taken out. The board away
	# first: while it is up its thumbs scroll it, whatever the builder says (`PilotRig._bindings_for`).
	rig.clipboard.show_board(false)
	rig.build_the_cockpit(true)
	rig.force_hand(HAND, Transform3D(Basis.IDENTITY, lamp.grip_global()))
	rig.force_grip(HAND, 1.0)
	await _frames(4)
	_check("in_the_builder_a_fist_takes_it", lamp.held_by == HAND, "held_by %d" % lamp.held_by)
	rig.force_input(HAND, Bind.THUMB_LOW, true)
	await _frames(3)
	rig.force_input(HAND, Bind.THUMB_LOW, false)
	await _frames(3)
	rig.force_input(HAND, Bind.THUMB_LOW, null)
	rig.force_grip(HAND, 0.0)
	await _frames(3)
	var left: SignalLamp = SignalLamp.in_station(station)
	_check("and_the_lower_thumb_bins_it", left == null, "%s" % left)
	rig.build_the_cockpit(false)
	_forget(kit)
	_sections += 1


## THE BUILD TAB UP -- its tab pressed with the beam -- AND THE THUMB WALKING THE PAGE DOWN UNTIL "+ SIGNAL LAMP" IS
## INSIDE THE SCROLLING AREA. Null if there is no such button.
func _show_the_lamp_button(rig: PilotRig) -> Button:
	var board: Clipboard = rig.clipboard
	board.show_board(true)
	await _frames(2)
	var page: ClipboardPage = board.page()
	await _beam_presses(rig, (page.get("_tabs") as Array)[ClipboardPage.Tab.BUILD] as Control)
	await _frames(3)
	var button: Button = null
	for node in (page.get("_build") as Control).find_children("*", "Button", true, false):
		if (node as Button).text == "+ SIGNAL LAMP":
			button = node as Button
	if button == null:
		return null
	var area := page.get("_scroll") as ScrollContainer
	var pulls: int = 0
	while button.get_global_rect().end.y > area.get_global_rect().end.y and pulls < 60:
		board.scroll(1)
		await _frames(1)
		pulls += 1
	await _frames(2)
	return button


## ONE PULL OF THE RIGHT TRIGGER with the right hand's beam on `target`: `tests/clipboard.gd._beam_presses`.
func _beam_presses(rig: PilotRig, target: Control) -> void:
	var centre: Vector2 = target.get_global_rect().get_center()
	for trigger in [0.0, 0.0, 1.0, 1.0, 0.0, 0.0]:
		var panel: TouchPanel = rig.clipboard.panel()
		var screen := panel.get("_screen") as SubViewport
		var on_glass := Vector3((centre.x / float(screen.size.x) - 0.5) * panel.size.x,
			(0.5 - centre.y / float(screen.size.y)) * panel.size.y, 0.0)
		var aimed_at: Vector3 = panel.to_global(on_glass)
		var hand_at: Vector3 = aimed_at + panel.global_basis.z.normalized() * 0.30
		rig.force_hand(1, Transform3D(Basis.looking_at(aimed_at - hand_at, panel.global_basis.y.normalized()), hand_at))
		rig.force_input(1, Bind.TRIGGER, trigger)
		await get_tree().process_frame
	rig.force_input(1, Bind.TRIGGER, null)
	rig.force_hand(1, Transform3D(Basis.IDENTITY, Vector3(0.0, -45.0, 0.0)))
	await get_tree().process_frame


## EVERY GRIP IN THE CRAFT BUT `lamp`'s, in `station`'s frame: what the holster search was handed.
func _grips_but(view: VehicleView, station: CockpitStation, lamp: SignalLamp) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var mine := station.global_transform.affine_inverse()
	var every: Array = []
	for seat in range(view.seats.size()):
		var other: CockpitStation = view.station_for(seat)
		if other == null:
			continue
		for control in other.controls().values():
			if not every.has(control):
				every.append(control)
	every.append_array((view.get("_console") as Dictionary).values())
	for control_any in every:
		var control := control_any as VehicleControl
		if control != null and control != lamp and control.is_inside_tree():
			out.append(mine * control.grip_global())
	return out


## A LAMP PLACED AT EVERY SEAT OF EVERY CRAFT SCENE LANDS IN A HOLSTER WITHIN AN EASY SEATED REACH, AND ITS GRIP IS
## CLEAR OF EVERY OTHER GRIP IN THE CRAFT BY TWO HANDS -- `tests/fit.gd`'s rule, which also measures it.
func _every_seat_of_every_craft_has_one_in_reach() -> void:
	var seats: int = 0
	var missing: PackedStringArray = []
	var far: PackedStringArray = []
	var crowded: PackedStringArray = []
	var hiding: PackedStringArray = []
	var on_the_board: PackedStringArray = []
	var boards: int = 0
	var nearest_board: float = INF
	# UNDER THE SKIN, in every station `tests/shell_room.gd` holds as enclosed: every corner of the holstered lamp's body
	# covered above and below by the craft's own drawing before `seat_room`'s FAR, as `tests/pilot_seat.gd`
	# holds a chair. Found on the Duo Discus (2026-09-19): 0.71 m across, and the search's every outboard spot was
	# through its skin, so both lamps hung outside its port side.
	var room: Node = (load("res://tests/seat_room.gd") as GDScript).new()
	var enclosed: PackedStringArray = (load("res://tests/shell_room.gd") as GDScript).get_script_constant_map()["ENCLOSED"]
	var skinned: int = 0
	var outside: PackedStringArray = []
	for name in _craft_names():
		var view := _craft(name)
		if view == null:
			continue
		var into: Transform3D = view.global_transform.affine_inverse()
		var craft: Array = []
		for solid in room.call("_solids", view, into) as Array:
			if String(solid["name"]) != "Chair":
				craft.append(solid)
		# THEN A LAMP AT EVERY SEAT, after the solids were taken (a lamp is not the craft's skin), placed in seat order: the
		# worst case, each holster found clear of the lamps before it.
		for seat in range(view.seats.size()):
			view.holster_a_lamp(seat)
		for seat in range(view.seats.size()):
			var station: CockpitStation = view.station_for(seat)
			if station == null:
				continue
			seats += 1
			var lamp: SignalLamp = SignalLamp.in_station(station)
			if lamp == null:
				missing.append("%s seat %d" % [name, seat])
				continue
			# AND NOT BETWEEN THE SEATED EYE AND ANYTHING READ, measured off the lamp's own drawn meshes -- the check
			# `tests/water.gd` makes of the water bomber's tank gauge, over every face of every station.
			var in_the_way: String = _hides_a_face(station, lamp)
			if in_the_way != "":
				hiding.append("%s seat %d hides %s" % [name, seat, in_the_way])
			# AND CLEAR OF THE CREW BOARD'S PLACARD, which lane/crewboard puts beside the hip on the outboard console --
			# where this holster's search starts. Measured drawn box to drawn box, and the nearest kept for the detail.
			var board := station.get_node_or_null("Crew") as Node3D
			if board == null:
				for child in station.get_children():
					if child is CrewBoard:
						board = child
			if board != null:
				boards += 1
				var gap: float = _gap(_box_in(station, lamp), _box_in(station, board))
				nearest_board = minf(nearest_board, gap)
				if gap <= 0.0:
					on_the_board.append("%s seat %d" % [name, seat])
			if enclosed.has("%s/%d" % [name, seat]):
				skinned += 1
				var body: Transform3D = into * lamp.global_transform
				var open: String = ""
				for corner in range(8):
					var v: Vector3 = body * SignalLamp.HOLSTERED_BODY.get_endpoint(corner)
					# UP AND DOWN ONLY, as `tests/shell_room.gd` learnt: a cabin's doorway is open sideways by design, and
					# a ray out of it found the UH-60's, the light helicopter's and the tower's lamps "outside" (2026-09-19).
					# A lamp through a skin is under open sky or over open air, and the glider's was both.
					for along in [Vector3.UP, Vector3.DOWN]:
						if float((room.call("_cast", craft, v, along) as Array)[0]) >= float(room.get("FAR")):
							open = "corner %s open along %s" % [v, along]
							break
					if open != "":
						break
				var key: String = "%s/%d" % [name, seat]
				if OUTSIDE_KNOWN.has(key):
					if open == "":
						outside.append("%s is inside now: take it off OUTSIDE_KNOWN" % key)
					else:
						print("[signal_lamp] KNOWN %s outside its skin: %s" % [key, OUTSIDE_KNOWN[key]])
				elif open != "":
					outside.append("%s seat %d: %s" % [name, seat, open])
			var at: Vector3 = view.seat_anchor(seat).to_local(lamp.grip_global())
			var reach: float = CockpitStation.from_a_shoulder(at)
			if reach > CockpitStation.EASY_REACH:
				far.append("%s seat %d %.2f m" % [name, seat, reach])
			for other in _every_grip_in(view):
				if other == lamp:
					continue
				var apart: float = (other as VehicleControl).grip_global().distance_to(lamp.grip_global())
				if apart < VehicleControl.REACH * 2.0:
					crowded.append("%s seat %d near %s %.3f m" % [name, seat, (other as Node).name, apart])
		view.free()
	room.free()
	_check("and_every_holster_in_an_enclosed_station_is_under_its_crafts_skin", outside.is_empty() and skinned > 20,
		"%d holsters, every corner covered above and below but the %d known" % [skinned, OUTSIDE_KNOWN.size()]
			if outside.is_empty()
			else "\n      ".join(outside))
	_check("every_seat_takes_a_lamp_in_its_holster", missing.is_empty() and seats > 40,
		"%d seats" % seats if missing.is_empty() else "missing at %s" % ", ".join(missing))
	_check("and_every_holster_is_within_an_easy_reach", far.is_empty(),
		"all within %.2f m" % CockpitStation.EASY_REACH if far.is_empty() else ", ".join(far))
	_check("and_no_lamp_crowds_another_grip", crowded.is_empty(),
		"all clear" if crowded.is_empty() else "\n      ".join(crowded))
	_check("and_no_holstered_lamp_stands_in_the_crew_boards_placard", on_the_board.is_empty() and boards > 40,
		"%d placards, the nearest lamp %.3f m from one" % [boards, nearest_board] if on_the_board.is_empty()
			else "in it at %s" % ", ".join(on_the_board))
	_check("and_no_holstered_lamp_stands_between_the_eye_and_anything_read", hiding.is_empty(),
		"all clear" if hiding.is_empty() else ", ".join(hiding))
	_sections += 1


## ---- held --------------------------------------------------------------------------------------

## A FIST ON THE GRIP TAKES IT, AND WHILE HELD THE LAMP IS THE HAND: its -Z is the controller's -Z, which is
## what makes where it points the same thing as where the hand points.
func _a_fist_takes_it_and_it_sits_in_the_palm() -> void:
	var kit: Dictionary = await _a_seat(0)
	var rig: PilotRig = kit["rig"]
	var lamp: SignalLamp = kit["lamp"]
	var station: CockpitStation = kit["station"]
	# CLOSED A LITTLE OFF THE GRIP, turned, so a lamp that kept the offset it was grabbed at would be seen.
	var turned := Basis(Vector3.UP, 0.6) * Basis(Vector3.RIGHT, -0.3)
	var hand := Transform3D(turned, lamp.grip_global() + Vector3(0.02, 0.03, -0.01))
	rig.force_hand(HAND, hand)
	rig.force_grip(HAND, 1.0)
	await _frames(4)
	_check("a_fist_on_the_grip_takes_it", lamp.held_by == HAND, "held_by %d" % lamp.held_by)
	# AND THEN WALKED AND TURNED, as a hand aiming at something.
	var aimed := Transform3D(Basis(Vector3.UP, -0.4) * Basis(Vector3.RIGHT, 0.25), hand.origin + Vector3(-0.10, 0.12, -0.15))
	await _walk_the_hand(rig, hand, aimed)
	var palm: Vector3 = lamp.grip_global()
	_check("it_sits_in_the_palm", palm.distance_to(aimed.origin) < 0.002,
		"grip %.4f m from the palm" % palm.distance_to(aimed.origin))
	var beam: Vector3 = -lamp.muzzle().global_basis.z
	var pointing: Vector3 = -aimed.basis.z
	_check("and_it_points_where_the_hand_points", beam.angle_to(pointing) < deg_to_rad(0.5),
		"%.2f degrees apart" % rad_to_deg(beam.angle_to(pointing)))
	_check("and_it_is_still_in_the_station", lamp.get_parent() == station, "parent %s" % lamp.get_parent())
	_forget(kit)
	_sections += 1


## LET GO, IT STAYS WHERE IT WAS PUT -- IN THE SEAT'S FRAME -- WHILE THE CRAFT FLIES AWAY AND TURNS.
##
## RED, with `SignalLamp._on_released` moving the lamp to the scene root and keeping its world pose (the lamp
## "left in world space"): it stays at the runway while the craft goes 200 m.
func _let_go_it_stays_with_the_seat_as_the_craft_flies() -> void:
	var kit: Dictionary = await _a_seat(0)
	var rig: PilotRig = kit["rig"]
	var lamp: SignalLamp = kit["lamp"]
	var view: VehicleView = kit["view"]
	var anchor: Node3D = view.seat_anchor(0)
	var holstered: Transform3D = anchor.global_transform.affine_inverse() * lamp.global_transform
	var hand := Transform3D(Basis.IDENTITY, lamp.grip_global())
	rig.force_hand(HAND, hand)
	rig.force_grip(HAND, 1.0)
	await _frames(4)
	var put := Transform3D(Basis(Vector3.UP, 0.5), hand.origin + Vector3(-0.12, 0.15, -0.10))
	await _walk_the_hand(rig, hand, put)
	await _open_the_fist(rig, lamp)
	_check("it_is_let_go", lamp.held_by < 0, "held_by %d" % lamp.held_by)
	var left_at: Transform3D = anchor.global_transform.affine_inverse() * lamp.global_transform
	_check("where_it_was_put_and_not_back_in_the_holster",
		left_at.origin.distance_to(holstered.origin) > 0.1,
		"%.3f m from the holster" % left_at.origin.distance_to(holstered.origin))
	# THE HAND GOES AWAY, and the craft flies 200 m and turns through a right angle, a step a frame.
	rig.force_hand(HAND, Transform3D(Basis.IDENTITY, Vector3(0.0, -40.0, 0.0)))
	await _frames(2)
	var apart_before: float = lamp.global_position.distance_to(anchor.global_position)
	var start: Transform3D = view.global_transform
	const STEPS: int = 12
	for i in range(STEPS):
		var f: float = float(i + 1) / float(STEPS)
		view.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5 * f) * Basis(Vector3.RIGHT, 0.2 * f),
			start.origin + Vector3(200.0 * f, 30.0 * f, -80.0 * f))
		await _frames(1)
	await _frames(2)
	var now: Transform3D = anchor.global_transform.affine_inverse() * lamp.global_transform
	_check("it_stays_where_it_was_left_in_the_seat_as_the_craft_flies_and_turns",
		now.origin.distance_to(left_at.origin) < 0.001 and now.basis.is_equal_approx(left_at.basis),
		"%.4f m from where it was left, in the seat's frame" % now.origin.distance_to(left_at.origin))
	var from_the_seat: float = lamp.global_position.distance_to(anchor.global_position)
	_check("and_so_it_went_with_the_craft", absf(from_the_seat - apart_before) < 0.001,
		"%.3f m from the seat before the craft flew 200 m, %.3f m after" % [apart_before, from_the_seat])
	_forget(kit)
	_sections += 1


## ---- the colours -----------------------------------------------------------------------------

## THE TRIGGER IS WHITE, THE LOWER THUMB RED AND THE UPPER GREEN, ON WHICHEVER HAND HOLDS IT. ONE AT A TIME: the
## newest press wins, letting it go falls back to what is still held, and letting everything go is dark.
##
## RED, with `SignalLamp.ask` keeping the FIRST colour held lit (a second press ignored):
##   FAIL a_second_finger_takes_over (lit white, wanted red)
func _the_holding_hands_fingers_are_the_colours(hand: int) -> void:
	var kit: Dictionary = await _a_seat(0, hand)
	var rig: PilotRig = kit["rig"]
	var lamp: SignalLamp = kit["lamp"]
	var side: String = "left" if hand == 0 else "right"
	rig.force_hand(hand, Transform3D(Basis.IDENTITY, lamp.grip_global()))
	rig.force_grip(hand, 1.0)
	await _frames(4)
	_check("the_%s_fist_takes_it" % side, lamp.held_by == hand, "held_by %d" % lamp.held_by)
	_said.clear()
	lamp.signalled.connect(_on_signalled)

	await _finger(rig, hand, Bind.TRIGGER, true)
	_check("the_%s_trigger_is_white" % side, _shows(lamp, SignalLamp.WHITE), _reading(lamp))
	# THE TRIGGER GOES NOWHERE ELSE. With the lamp in the hand it is not the gun's or the brake's.
	var frame: Dictionary = rig.read_controls()
	_check("and_the_%s_trigger_fires_and_brakes_nothing" % side,
		float(frame.get("trigger", 0.0)) == 0.0 and (int(frame.get("buttons", 0)) & Sim.BUTTON_FIRE) == 0,
		"trigger %.2f, buttons %d" % [float(frame.get("trigger", 0.0)), int(frame.get("buttons", 0))])
	await _finger(rig, hand, Bind.THUMB_LOW, true)
	_check("a_second_finger_takes_over_%s" % side, _shows(lamp, SignalLamp.RED), _reading(lamp))
	_check("and_only_one_colour_is_lit_%s" % side, _pips_lit(lamp) == 1, "%d pips lit" % _pips_lit(lamp))
	await _finger(rig, hand, Bind.THUMB_LOW, false)
	_check("letting_it_go_falls_back_to_the_one_still_held_%s" % side, _shows(lamp, SignalLamp.WHITE),
		_reading(lamp))
	await _finger(rig, hand, Bind.TRIGGER, false)
	_check("and_nothing_held_is_dark_%s" % side, _shows(lamp, SignalLamp.DARK), _reading(lamp))
	await _finger(rig, hand, Bind.THUMB_HIGH, true)
	_check("the_%s_upper_thumb_is_green" % side, _shows(lamp, SignalLamp.GREEN), _reading(lamp))
	await _finger(rig, hand, Bind.THUMB_HIGH, false)
	_check("and_it_said_so_once_a_change_%s" % side,
		_said == [SignalLamp.WHITE, SignalLamp.RED, SignalLamp.WHITE, SignalLamp.DARK,
			SignalLamp.GREEN, SignalLamp.DARK], "said %s" % [_said])
	lamp.signalled.disconnect(_on_signalled)
	_forget(kit)
	_sections += 1


## LETTING GO PUTS IT OUT, AND A HAND THAT IS NOT HOLDING IT CANNOT LIGHT IT.
func _a_lamp_in_nobodys_hand_is_dark() -> void:
	var kit: Dictionary = await _a_seat(0)
	var rig: PilotRig = kit["rig"]
	var lamp: SignalLamp = kit["lamp"]
	rig.force_hand(HAND, Transform3D(Basis.IDENTITY, lamp.grip_global()))
	rig.force_grip(HAND, 1.0)
	await _frames(4)
	await _finger(rig, HAND, Bind.THUMB_LOW, true)
	_check("held_and_red", _shows(lamp, SignalLamp.RED), _reading(lamp))
	await _open_the_fist(rig, lamp)
	_check("let_go_it_goes_dark", lamp.held_by < 0 and _shows(lamp, SignalLamp.DARK), _reading(lamp))
	await _finger(rig, HAND, Bind.THUMB_LOW, false)
	# AN OPEN HAND ON THE GRIP, PULLING THE TRIGGER: the lamp is not in it, so it is not the lamp's trigger.
	rig.force_grip(HAND, 0.0)
	await _finger(rig, HAND, Bind.TRIGGER, true)
	_check("an_open_hand_on_it_does_not_light_it", _shows(lamp, SignalLamp.DARK), _reading(lamp))
	await _finger(rig, HAND, Bind.TRIGGER, false)
	_forget(kit)
	_sections += 1


## ---- the desk ------------------------------------------------------------------------------------

## 1, 2 AND 3 ARE WHITE, RED AND GREEN WHILE HELD, THROUGH THE SAME ONE-AT-A-TIME RULE; 0 PUTS IT BACK.
func _the_desk_keys_flash_it_and_zero_puts_it_back() -> void:
	var kit: Dictionary = await _a_seat(0)
	var rig: PilotRig = kit["rig"]
	var lamp: SignalLamp = kit["lamp"]
	var holster: Transform3D = lamp.transform
	for action in ["lamp_white", "lamp_red", "lamp_green", "lamp_home"]:
		_check("the_desk_binds_%s" % action, InputMap.has_action(action), action)
	Input.action_press("lamp_white")
	await _physics(3)
	_check("one_is_white", _shows(lamp, SignalLamp.WHITE), _reading(lamp))
	Input.action_press("lamp_green")
	await _physics(3)
	_check("three_over_it_is_green", _shows(lamp, SignalLamp.GREEN), _reading(lamp))
	Input.action_release("lamp_green")
	await _physics(3)
	_check("and_back_to_white", _shows(lamp, SignalLamp.WHITE), _reading(lamp))
	Input.action_release("lamp_white")
	Input.action_press("lamp_red")
	await _physics(3)
	_check("two_is_red", _shows(lamp, SignalLamp.RED), _reading(lamp))
	Input.action_release("lamp_red")
	await _physics(3)
	_check("and_let_go_it_is_dark", _shows(lamp, SignalLamp.DARK), _reading(lamp))
	# PUT DOWN SOMEWHERE ELSE, AND CALLED BACK.
	rig.force_hand(HAND, Transform3D(Basis.IDENTITY, lamp.grip_global()))
	rig.force_grip(HAND, 1.0)
	await _frames(4)
	await _walk_the_hand(rig, Transform3D(Basis.IDENTITY, lamp.grip_global()),
		Transform3D(Basis.IDENTITY, lamp.grip_global() + Vector3(-0.1, 0.15, -0.1)))
	await _open_the_fist(rig, lamp)
	var moved: float = lamp.transform.origin.distance_to(holster.origin)
	Input.action_press("lamp_home")
	await _physics(2)
	Input.action_release("lamp_home")
	await _physics(1)
	_check("zero_puts_it_back_in_its_holster", moved > 0.1 and lamp.transform.origin.distance_to(holster.origin) < 0.001,
		"moved %.3f m, now %.4f m from the holster" % [moved, lamp.transform.origin.distance_to(holster.origin)])
	_forget(kit)
	_sections += 1


## ---- whose it is -------------------------------------------------------------------------------

## THE PLAYER IN SEAT 1 CANNOT TAKE SEAT 0'S LAMP, AND CAN TAKE THEIR OWN.
##
## RED, with `PilotRig._gather_reachable` not asking `own_seat_only`:
##   FAIL seat_one_cannot_take_seat_zeros_lamp (held_by 1)
func _another_seats_lamp_is_not_yours_to_take() -> void:
	var kit: Dictionary = await _a_seat(1)
	if kit.is_empty():
		_check("the_%s_has_two_seats" % CRAFT, false, "no seat 1")
		_sections += 1
		return
	var rig: PilotRig = kit["rig"]
	var view: VehicleView = kit["view"]
	# SEAT 0'S LAMP, as this machine draws it when seat 0's channel says it has one (`VehicleView._match_lamps_to_the_wire`).
	var theirs: SignalLamp = view.holster_a_lamp(0)
	var mine: SignalLamp = kit["lamp"]
	rig.force_hand(HAND, Transform3D(Basis.IDENTITY, theirs.grip_global()))
	rig.force_grip(HAND, 1.0)
	await _frames(4)
	_check("seat_one_cannot_take_seat_zeros_lamp", theirs.held_by < 0, "held_by %d" % theirs.held_by)
	rig.force_grip(HAND, 0.0)
	await _frames(3)
	rig.force_hand(HAND, Transform3D(Basis.IDENTITY, mine.grip_global()))
	rig.force_grip(HAND, 1.0)
	await _frames(4)
	_check("and_can_take_its_own", mine.held_by == HAND, "held_by %d" % mine.held_by)
	_forget(kit)
	_sections += 1


## ---- the bench -----------------------------------------------------------------------------------

## A WHOLE CRAFT, EVERY SEAT MANNED, AND A RIG IN `seat`. `hand` is the one the section works with; the other is
## parked open and far away. Empty when the craft has no such seat.
func _a_seat(seat: int, hand: int = HAND, place: bool = true) -> Dictionary:
	var view := _craft(CRAFT)
	if view == null or seat >= view.seats.size():
		if view != null:
			view.free()
		return {}
	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	rig.sit_in(view.seat_anchor(seat))
	var other: int = 1 - hand
	rig.force_grip(other, 0.0)
	rig.force_hand(other, Transform3D(Basis.IDENTITY, Vector3(0.0, -40.0, 0.0)))
	rig.force_grip(hand, 0.0)
	rig.force_hand(hand, Transform3D(Basis.IDENTITY, Vector3(0.0, -45.0, 0.0)))
	await _frames(3)
	var station: CockpitStation = view.station_for(seat)
	# A LAMP OFF THE PARTS BIN, by the signal a "+ SIGNAL LAMP" press emits. See the note at the top.
	if place:
		rig.clipboard.chose_part.emit(&"SignalLamp")
		await _frames(3)
	return {"rig": rig, "view": view, "station": station, "lamp": SignalLamp.in_station(station)}


func _craft(name: String) -> VehicleView:
	var scene := load("res://objects/vehicles/craft_%s.tscn" % name) as PackedScene
	if scene == null:
		return null
	var view := scene.instantiate() as VehicleView
	if view == null:
		return null
	add_child(view)
	view._show_in_editor()
	return view


## EVERY CRAFT SCENE THERE IS, by the name in its filename. Read off the folder rather than listed, so a craft
## added tomorrow is measured tomorrow.
func _craft_names() -> PackedStringArray:
	var out: PackedStringArray = []
	for file in DirAccess.get_files_at("res://objects/vehicles"):
		var name: String = file.trim_suffix(".remap")
		if name.begins_with("craft_") and name.ends_with(".tscn"):
			out.append(name.trim_prefix("craft_").trim_suffix(".tscn"))
	return out


## THE FIRST FACE IN `station` THAT `lamp` STANDS BETWEEN THE SEATED EYE AND, by name, or "". The lamp is its own drawn
## meshes, in the station's frame; the faces are `SignalLamp.faces_in`, each tried at its middle and four corners.
func _hides_a_face(station: CockpitStation, lamp: SignalLamp) -> String:
	var body := AABB()
	var started: bool = false
	for node in lamp.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var into: Transform3D = station.global_transform.affine_inverse() * mesh.global_transform
		for corner in range(8):
			var at: Vector3 = into * mesh.mesh.get_aabb().get_endpoint(corner)
			body = AABB(at, Vector3.ZERO) if not started else body.expand(at)
			started = true
	var eye := Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
	var names: Dictionary = {}
	for child in station.get_children():
		var part := child as Node3D
		if part != null and not (part is VehicleControl) and not (part is CockpitShell):
			names[part] = String(part.name)
	var faces: Array[AABB] = SignalLamp.faces_in(station)
	for face in faces:
		var middle: Vector3 = face.get_center()
		for point in [middle, middle + Vector3(face.size.x * 0.48, face.size.y * 0.48, face.size.z * 0.5),
				middle + Vector3(-face.size.x * 0.48, face.size.y * 0.48, face.size.z * 0.5),
				middle + Vector3(face.size.x * 0.48, -face.size.y * 0.48, face.size.z * 0.5),
				middle + Vector3(-face.size.x * 0.48, -face.size.y * 0.48, face.size.z * 0.5)]:
			if body.intersects_segment(eye, point):
				return "a face at %s" % face.get_center()
	return ""


## A PART'S DRAWN BOX IN `station`'s FRAME, off its meshes.
func _box_in(station: Node3D, part: Node3D) -> AABB:
	var box := AABB()
	var started: bool = false
	var nodes: Array[Node] = [part]
	nodes.append_array(part.find_children("*", "MeshInstance3D", true, false))
	for node in nodes:
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var into: Transform3D = station.global_transform.affine_inverse() * mesh.global_transform
		for corner in range(8):
			var at: Vector3 = into * mesh.mesh.get_aabb().get_endpoint(corner)
			box = AABB(at, Vector3.ZERO) if not started else box.expand(at)
			started = true
	return box


## HOW FAR APART TWO BOXES ARE, metres; 0 or less when they touch or overlap.
static func _gap(a: AABB, b: AABB) -> float:
	var out := Vector3.ZERO
	for axis in range(3):
		out[axis] = maxf(maxf(b.position[axis] - a.end[axis], a.position[axis] - b.end[axis]), 0.0)
	var apart: float = out.length()
	return apart if apart > 0.0 else -1.0


## Every control a hand could take in the craft, once each: every seat's set and the console.
func _every_grip_in(view: VehicleView) -> Array:
	var out: Array = []
	for seat in range(view.seats.size()):
		for control in view.controls_for(seat).values():
			if control is VehicleControl and not out.has(control):
				out.append(control)
	return out


func _forget(kit: Dictionary) -> void:
	for action in ["lamp_white", "lamp_red", "lamp_green", "lamp_home"]:
		if InputMap.has_action(action):
			Input.action_release(action)
	(kit["rig"] as Node).queue_free()
	(kit["view"] as Node).queue_free()


## ---- driving the hands ---------------------------------------------------------------------------

func _finger(rig: PilotRig, hand: int, input: int, down: bool) -> void:
	rig.force_input(hand, input, (1.0 if down else 0.0) if input == Bind.TRIGGER else down)
	await _frames(3)


## WALK A CLOSED HAND from one pose to another a frame at a time, so the carry is travel and not a teleport.
func _walk_the_hand(rig: PilotRig, from: Transform3D, to: Transform3D) -> void:
	const STEPS: int = 8
	for i in range(STEPS):
		rig.force_hand(HAND, from.interpolate_with(to, float(i + 1) / float(STEPS)))
		await _frames(1)
	await _frames(2)


## OPEN THE FIST, AS A SQUEEZE ENDING AND NOT AS A TAP -- a grip opened inside `PilotRig.TAP_SECONDS` is a
## latch. `tests/director.gd._open_the_fist`, which learnt it from `tests/pinch.gd`.
func _open_the_fist(rig: PilotRig, control: VehicleControl) -> void:
	var hand: int = control.held_by if control.held_by >= 0 else HAND
	var closed_at: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - closed_at < int((PilotRig.TAP_SECONDS + 0.15) * 1000.0):
		await _frames(1)
	rig.force_grip(hand, 0.0)
	await _frames(4)
	if control.held_by == hand:
		rig.force_grip(hand, 1.0)
		await _frames(2)
		rig.force_grip(hand, 0.0)
		await _frames(4)
	await _frames(2)


## ---- reading the lamp ----------------------------------------------------------------------------

## WHAT THE LAMP SHOWS, READ OFF THE LENS as well as off `lit`: a colour the glass is not emitting is a colour
## nobody sees.
func _shows(lamp: SignalLamp, colour: int) -> bool:
	if lamp.lit != colour:
		return false
	if colour == SignalLamp.DARK:
		return lamp.lens_energy() == 0.0
	return lamp.lens_energy() > 1.0 and lamp.lens_colour().is_equal_approx(SignalLamp.colour_of(colour))


func _reading(lamp: SignalLamp) -> String:
	return "lit %s, lens %.1f %s, %d pips" % [SignalLamp.colour_name(lamp.lit), lamp.lens_energy(),
		lamp.lens_colour(), _pips_lit(lamp)]


## HOW MANY OF THE THREE PIPS ARE EMITTING.
func _pips_lit(lamp: SignalLamp) -> int:
	var lit: int = 0
	for child in lamp.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or not (mesh.mesh is BoxMesh):
			continue
		var material := mesh.material_override as StandardMaterial3D
		if material != null and material.emission_enabled and material.emission_energy_multiplier > 0.0:
			lit += 1
	return lit


func _on_signalled(_lamp: SignalLamp, colour: int) -> void:
	_said.append(colour)


func _frames(how_many: int) -> void:
	for i in range(how_many):
		await get_tree().process_frame


func _physics(how_many: int) -> void:
	for i in range(how_many):
		await get_tree().physics_frame
	await get_tree().process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	await _frames(3)
	get_tree().quit(0 if _failures.is_empty() else 1)
