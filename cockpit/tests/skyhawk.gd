extends Node
## Headless: the Cessna 172S is drawn as the aircraft it is, measured from the vertices it draws. Every reference figure is
## typed here from its source and never read from the airframe that draws it (see craft/cessna/sources.md):
## [IM] the 172S information manual's three-view; [MM] the maintenance manual; [NOTES] the information manual's notes;
## [EALT] a scaled Commons photograph. Read RESULT=, not the process exit code.

## THE ENVELOPE: [IM] 27 ft 2 in long and 36 ft 1 in over the strobes; the height is the MEASURED 2.36 m to the beacon
## ([IM] 2.39, [EALT] 2.34), not Textron's 2.72 m maximum, which nothing reproduces.
const LENGTH := 8.28
const SPAN := 11.0
const HEIGHT := 2.36
## [MM] 8 ft 4.5 in; [NOTES] 65 in.
const TRACK := 2.553
const WHEELBASE := 1.651
## [IM plan] the wing: a 1.605 m chord to 2.52 m out, 1.11 m at the tip rib 5.26 m out; [IM front] 1.44 to 1.92 degrees of
## dihedral over and under, 1 degree 44 minutes published.
const ROOT_CHORD := 1.605
const TIP_RIB_OUT := 5.26
const TIP_CHORD := 1.11
const BREAK_OUT := 2.52
const DIHEDRAL := 1.73
## [IM front] the strut meets the wing 2.46 to 2.51 m out; [IM side][EALT] its head 2.08 to 2.22 m aft of the spinner, its
## foot 1.79 to 1.93 m aft and 0.55 to 0.70 m up.
const STRUT_HEAD := Vector2(2.49, 2.15)  # (out, aft)
const STRUT_FOOT := Vector2(0.63, 1.86)  # (up, aft)
## [IM side] the fin's leading edge swept 47 degrees, its cap 2.30 m up.
const FIN_SWEEP := 47.4
const FIN_CAP := 2.30
## [MM] 11 ft 4 in over the stabiliser.
const TAIL_SPAN := 3.454
## [MM] a 76 in propeller; [NOTES] 11.25 in over the ground.
const PROPELLER := 1.930
const PROP_CLEARANCE := 0.286
## [IM plan] 1.10 m over the cabin outside; [MM] 39.5 in (1.003 m) sidewall to sidewall inside.
const CABIN_OUTSIDE := 1.10
const CABIN_INSIDE := 1.003
## [EALT] the reference eyes: 2.33 m aft, 1.45 m up, 0.27 m either side of the centreline.
const EYE := Vector3(0.27, 1.45, 2.33)  # (out, up, aft)
const PARTS: Array[String] = ["Airframe", "Glazing", "Cabin", "Details", "Gear", "StrutPort", "StrutStarboard", "FlapPort", "FlapStarboard",
	"AileronPort", "AileronStarboard", "ElevatorPort", "ElevatorStarboard", "TrimTab", "Rudder", "Spinner", "Propeller", "PropellerDisc"]
## [MM] the travels, degrees: flaps 30; ailerons 20 up and 15 down; elevator 28 up and 23 down; the trim tab 19 down and 22
## up; the rudder 17 degrees 44 minutes perpendicular to its hinge.
const FLAPS_DOWN := 30.0
const AILERON_UP := 20.0
const AILERON_DOWN := 15.0
const ELEVATOR_UP := 28.0
const ELEVATOR_DOWN := 23.0
const TAB_DOWN := 19.0
const TAB_UP := 22.0
const RUDDER := 17.733
## THE ROOM THE AIRFRAME PROMISES ROUND ITS CREW, typed here and never read from the airframe that draws it. Stations
## aft of the spinner tip and heights over the ground, as everything else in this file is.
##
## MEASURED off the drawn sections rather than taken from a manual, because THE MANUALS' CABIN DOES NOT FIT THIS
## FUSELAGE. Scanning outward from the centreline until a ray leaves the skin, at the narrowest station between s 1.95
## and s 3.01: h 0.56 gives 0.35, h 0.62 gives 0.42, h 0.70 gives 0.48, h 0.90 gives 0.52, h 1.30 gives 0.54, h 1.75
## gives 0.52, h 1.80 gives 0.51 and h 1.86 gives 0.38. [MM]'s 1.003 m floor at h 0.56 would need 0.50 there and has
## 0.35: `SECTIONS` gives the cabin's lower superellipse a squareness of 4.0 and a real 172's belly is flatter than
## that. The room is therefore the largest box the DRAWING supports, with the floor published beside it.
const ROOM_HALF := 0.46
const ROOM_FLOOR := 0.72
const ROOM_ROOF := 1.78
const ROOM_FORE := 1.95
const ROOM_AFT := 3.01
## WHERE THE CABIN FLOOR IS, [MM] ch.6: 48 in below the headliner. NOT the room's own bottom -- at h 0.56 the drawn
## fuselage is only 0.70 m across, so the promise starts 0.16 m higher and the floor is published beside it.
const CABIN_FLOOR := 0.56
## A ROOM THAT IS DEFINITELY WRONG, to prove the check can fail: wider than the 1.10 m skin, higher than the 1.91 m
## windscreen head, lower than the 0.45 m belly, and running from ahead of the firewall to behind the baggage bay.
const WRONG_HALF := 0.65
const WRONG_FLOOR := 0.40
const WRONG_ROOF := 2.05
const WRONG_FORE := 1.40
const WRONG_AFT := 4.10
## How far a sample may stand outside the drawn outline before it counts, in metres: a promise flush with the skin is a
## promise kept, and the skin is drawn from flat panels whose chords cut a centimetre inside their own sections.
const SKIN_TOLERANCE := 0.02
## How finely the room's six faces are sampled, in metres.
const SAMPLE_STEP := 0.06
## HOW FAR A SLICING PLANE OR A RAY IS NUDGED OFF THE MODEL'S OWN VERTEX GRID, in metres, and it is not a fudge.
##
## `SECTIONS` puts a ring of vertices at s 1.95 and another at s 3.01, which are exactly the room's fore and aft faces.
## A plane through a ring crosses no edge of it -- every edge has both ends ON the plane -- so the outline comes back as
## the interpolated stubs of the triangles just aft of it, which is garbage, and a sample on the CENTRELINE at h 0.96
## read 0.49 m outside its own aeroplane. Sub-millimetre is enough to leave the ring and the model's closest rows are
## 0.06 m apart, so the shape this slices is the same shape to well inside SKIN_TOLERANCE.
const SLICE_NUDGE := 0.0007
const DT := 1.0 / 120.0
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[skyhawk] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var ready: bool = ClassDB.class_exists("CockpitWorld")
	_check("the_native_library_is_loaded", ready, "CockpitWorld %s" % ready)
	if not ready:
		_finish()
		return
	_the_airframe_is_a_172s_at_its_measured_scale()
	_the_asset_boundary_is_independent_of_simulation()
	_the_exterior_meets_its_budget()
	_the_cockpit_package_loads_every_station()
	_the_moving_parts_are_pure_and_travel_as_the_manual_says()
	_each_machine_draws_the_surfaces_from_what_it_holds()
	_the_room_it_promises_is_inside_the_skin_it_draws()
	_finish()


## THE PROMISE THE AIRFRAME MAKES ABOUT THE ROOM ROUND ITS CREW, HELD AGAINST THE TRIANGLES IT DRAWS.
##
## `SkyhawkAirframe.cabin_room` says: every point inside this box is inside the skin I draw. That is a promise another
## part of the game can act on without carrying any geometry of its own -- a floor, a seat or a rail that fits the room
## fits the aeroplane -- and it is worth exactly as much as the check that holds it to the drawing.
##
## THE DATUM IS THE DRAWN VERTEX. The room is five typed numbers; the skin is 2,936 triangles emitted by a different
## piece of code from a different set of constants. They never touch: the figures are compared against the references
## typed at the top of this file, and the box is then compared against the triangles. A mutant that moves `CABIN_ROOF`
## moves the promise and not the drawing, and is caught by the first; a mutant that moves a fuselage section moves the
## drawing and not the promise, and is caught by the second.
##
## HOW "INSIDE" IS DECIDED, because an AABB of the airframe would say the cabin is eleven metres wide: the skin is
## sliced with the plane through the sample, which gives that station's true outline, and the sample is inside if a ray
## fired straight up AND a ray fired straight down each cross that outline an odd number of times. See `_inside` for why
## it is those two rays and not four. A sample within SKIN_TOLERANCE of the outline is on the skin, not through it.
func _the_room_it_promises_is_inside_the_skin_it_draws() -> void:
	var view := (load("res://objects/vehicles/craft_cessna.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.preview_kind = Sim.Kind.CESSNA
	view._show_in_editor()
	var frame := view._visual_scene as SkyhawkAirframe
	if frame == null:
		_check("the_cessna_declares_the_room_round_its_crew", false, "no airframe")
		view.queue_free()
		return
	# ASKED THROUGH `VehicleView`, which is the one call another part of the game has for any craft, so the route the
	# consumer takes is the route under test rather than a shortcut straight to the airframe.
	var promise: Dictionary = view.cabin_room()
	var room: AABB = promise.get("room", AABB())
	_check("the_cessna_declares_the_room_round_its_crew_and_says_where_the_figures_came_from",
		bool(promise.get("drawn", false)) and String(promise.get("why_not", "x")) == ""
			and String(promise.get("source", "")).length() > 20 and room.get_volume() > 0.5,
		"drawn %s, %.3f m3, source %s" % [promise.get("drawn", false), room.get_volume(),
			String(promise.get("source", "")).substr(0, 60)])

	var rest := _parked_rest_height()
	var expected := _room(ROOM_HALF, ROOM_FLOOR, ROOM_ROOF, ROOM_FORE, ROOM_AFT, rest)
	_check("and_the_room_is_the_box_measured_off_the_drawn_sections",
		(room.position - expected.position).length() < 0.001 and (room.size - expected.size).length() < 0.001,
		"declared %.3f..%.3f x, %.3f..%.3f y, %.3f..%.3f z; measured %.3f..%.3f, %.3f..%.3f, %.3f..%.3f" % [
			room.position.x, room.end.x, room.position.y, room.end.y, room.position.z, room.end.z,
			expected.position.x, expected.end.x, expected.position.y, expected.end.y,
			expected.position.z, expected.end.z])

	# AND THE FLOOR IS PUBLISHED BESIDE THE ROOM AND NOT INSIDE IT. They are two facts: where a seat stands, and how much
	# room can be promised. On this aeroplane the second starts above the first, because the drawn belly pinches in
	# below the floor, and a consumer that assumed `room.position.y` was the floor would lay one 0.16 m too high.
	var floor_y: float = float(promise.get("floor", NAN))
	_check("and_the_floor_is_published_beside_the_room_because_the_drawn_belly_pinches_in_under_it",
		is_finite(floor_y) and absf(floor_y - (CABIN_FLOOR - rest)) < 0.001 and floor_y <= room.position.y,
		"floor y %.3f ([MM] h %.2f), the room's own bottom y %.3f (h %.2f), %.2f m above it" % [
			floor_y, CABIN_FLOOR, room.position.y, room.position.y + rest, room.position.y - floor_y])

	var skin := _exterior_triangles(frame)
	var kept := _samples_outside(skin, room)
	_check("and_every_point_of_that_room_is_inside_the_skin_the_airframe_draws",
		int(kept["outside"]) == 0 and int(kept["tested"]) > 1500 and skin.size() > 6000,
		"%d samples over its six faces against %d skin triangles, none outside" % [kept["tested"], skin.size() / 3]
			if int(kept["outside"]) == 0 else
			"%d of %d samples outside; worst %.3f m out at h %.2f s %.2f, %.2f m off the centreline" % [
				kept["outside"], kept["tested"], kept["worst"], kept["where"].y + rest,
				kept["where"].z + LENGTH * 0.5, absf(kept["where"].x)])

	# AND THE CHECK WOULD NOTICE A ROOM THAT WAS NOT. One mutant, built from this file's own typed figures rather than
	# from the airframe's, and definitely wrong on every face: wider than the skin, over the windscreen's head, under
	# the belly, ahead of the firewall and behind the baggage bay.
	var wrong := _samples_outside(skin, _room(WRONG_HALF, WRONG_FLOOR, WRONG_ROOF, WRONG_FORE, WRONG_AFT, rest))
	_check("and_a_room_bigger_than_the_aeroplane_is_caught",
		int(wrong["outside"]) > 100 and float(wrong["worst"]) > 0.10,
		"%d of %d samples outside, worst %.3f m out at h %.2f s %.2f" % [wrong["outside"], wrong["tested"],
			wrong["worst"], wrong["where"].y + rest, wrong["where"].z + LENGTH * 0.5])

	# THE ROOM IS THE RIGHT ROOM, held to a point nothing in it produced: where a real 172S pilot's eye is [EALT].
	#
	# AND THE PACKAGE'S OWN SEATS ARE NOT IN IT, WHICH IS PRINTED HERE AND NOT ASSERTED. The assert belongs beside this
	# check and would read `room.has_point(seat + EYE_HEIGHT)` -- see `todo/skyhawk--cessna-seats-stand-outside-the-drawn-cabin.md`,
	# which says what to assert. It is not in the suite because it would be RED until the native seat move
	# lands, and a suite that is permanently red for a condition blocked on another lane teaches everybody that a red
	# line in the gate is normal. `names_shot` was taken out of `suites.txt` on this same day for exactly that, and two
	# lanes spent part of their merge reports explaining which of their reds were not theirs.
	#
	# WHAT THE TWO ANCHORS ARE FOR, because the assert closes the loop between them without either borrowing the
	# other's datum, and both are needed:
	# - `tests/fighter.gd` asks whether a seat is in the right place on the REAL aeroplane: eye = pose + EYE_HEIGHT + a
	#   settled rest height, against a photograph. Its datum is outside the model entirely, which is the only thing that
	#   catches a model drawn wrong -- a room measured off a wrong model would faithfully describe the wrong model.
	# - The room above asks what the DRAWING can be promised to enclose. Its datum is the drawn triangles, which is the
	#   only thing that catches a correctly sourced eye sitting outside the skin.
	# The Cessna is both at once, and that is the proof one check cannot do the work of two: its eye is at h 1.90
	# against [EALT]'s 1.45, AND 0.12 m above its own drawn cabin roof.
	var reference := Vector3(EYE.x, EYE.y - rest, EYE.z - LENGTH * 0.5)
	var poses: Array = Sim.geometry_of(Sim.Kind.CESSNA).get("seat_poses", []) as Array
	var outside: Array[String] = []
	for seat in range(poses.size()):
		var at: Vector3 = (poses[seat] as Dictionary).get("position", Vector3.ZERO) as Vector3
		var eye := Vector3(at.x, at.y + CockpitStation.EYE_HEIGHT, at.z)
		if room.has_point(eye):
			continue
		outside.append("seat %d h %.2f, %.2f m over its roof and %.2f m outside its wall"
			% [seat, eye.y + rest, eye.y - room.end.y, absf(eye.x) - room.end.x])
	_check("and_it_holds_the_eye_a_172s_pilot_actually_has", room.has_point(reference),
		"[EALT]'s eye, 1.45 m up and 2.33 m aft, 0.27 m off the centreline, sits at (%.2f, %.2f, %.2f) in a room of %.2f..%.2f x, %.2f..%.2f y, %.2f..%.2f z"
			% [reference.x, reference.y, reference.z, room.position.x, room.end.x, room.position.y, room.end.y,
				room.position.z, room.end.z]
			+ ("; every package seat is in it too" if outside.is_empty() else
				". THE PACKAGE'S OWN SEATS ARE NOT, and that is the native seat move and not this model: "
				+ "; ".join(outside)))
	view.queue_free()
	_a_craft_that_encloses_nobody_says_so_rather_than_saying_nothing()


## AND THE OTHER HALF OF THE INTERFACE, which is the half that is easy to leave out.
##
## On nine of this game's craft the pilot's head is inside nothing the craft draws at all -- there is no enclosing solid
## to be outside of (`lane/shell`, 2026-09-17). AN ABSENT ANSWER IS INDISTINGUISHABLE FROM AN OVERSIGHT, so there are no
## absent answers: every craft in the game answers, and a craft that encloses nobody says so in a sentence somebody can
## act on rather than by returning nothing.
##
## ASKED OF EVERY KIND AND NOT OF A CHOSEN FEW, because the interface is only worth anything if a consumer can call it
## blind. A first version asked the plane and the airliner and demanded they give DIFFERENT reasons, on the strength of
## the airliner being "drawn as open plates"; both came back with the same sentence, because `HullSkin` dresses them
## both and the distinction was in the briefing rather than in the game.
func _a_craft_that_encloses_nobody_says_so_rather_than_saying_nothing() -> void:
	var malformed: PackedStringArray = []
	var reasons: Dictionary = {}
	var enclosing: PackedStringArray = []
	for kind in range(Sim.Kind.size()):
		var view := (load("res://objects/vehicles/craft_plane.tscn") as PackedScene).instantiate() as VehicleView
		add_child(view)
		view.preview_kind = kind
		view._show_in_editor()
		var said: Dictionary = view.cabin_room()
		var room: AABB = said.get("room", AABB())
		var why := String(said.get("why_not", ""))
		# KEYED ON, NOT MATCHED IN. `because` is one word a check can branch on and `why_not` the sentence a person
		# reads; a suite that asserted anything about the negative set from the prose would be substring-matching
		# against English and would break the first time somebody improved the wording (`lane/shell`, 2026-09-17).
		var because := StringName(said.get("because", &"?"))
		if not (said.get("drawn", null) is bool):
			malformed.append("%s does not say whether it is drawn" % Sim.kind_name(kind))
		elif bool(said["drawn"]):
			enclosing.append(Sim.kind_name(kind))
			if room.get_volume() <= 0.1 or why != "" or because != &"" or String(said.get("source", "")).length() < 20:
				malformed.append("%s claims a cabin in %.2f m3 with why_not '%s' and because '%s'" % [
					Sim.kind_name(kind), room.get_volume(), why, because])
		else:
			reasons[because] = true
			if why.length() < 30 or room.get_volume() != 0.0 or String(because).is_empty() or because == &"?":
				malformed.append("%s encloses nobody and does not say why ('%s' / '%s')" % [
					Sim.kind_name(kind), because, why])
		view.queue_free()
	_check("and_every_craft_answers_at_all_and_one_that_encloses_nobody_says_so_rather_than_saying_nothing",
		malformed.is_empty() and reasons.size() >= 1 and enclosing.size() >= 1,
		"%d of %d craft declare a cabin (%s); the rest give %d distinct `because` keys, %s" % [enclosing.size(),
			Sim.Kind.size(), ", ".join(enclosing), reasons.size(), reasons.keys()]
			if malformed.is_empty() else "
      ".join(malformed))


## A room from stations aft of the spinner and heights over the ground, in the craft's own frame.
func _room(half: float, floor_h: float, roof_h: float, fore_s: float, aft_s: float, rest: float) -> AABB:
	return AABB(Vector3(-half, floor_h - rest, fore_s - LENGTH * 0.5),
		Vector3(half * 2.0, roof_h - floor_h, aft_s - fore_s))


func _the_airframe_is_a_172s_at_its_measured_scale() -> void:
	var view := (load("res://objects/vehicles/craft_cessna.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.preview_kind = Sim.Kind.CESSNA
	view._show_in_editor()
	var frame := view._visual_scene as SkyhawkAirframe
	if frame == null:
		_check("the_cessna_draws_its_skyhawk_airframe", false, "visual scene %s" % view._visual_scene)
		view.queue_free()
		return
	var missing: Array[String] = []
	for part in PARTS:
		if frame.find_child(part, true, false) == null:
			missing.append(part)
	_check("the_cessna_draws_its_skyhawk_airframe_with_every_part_and_separate_control_surfaces", missing.is_empty(),
		"%d parts; missing %s" % [PARTS.size(), missing])
	if not missing.is_empty():
		view.queue_free()
		return

	var rest := _parked_rest_height()
	var ground: float = -rest
	var bounds := _drawn_bounds(frame)
	_check("and_the_drawn_model_stays_within_two_percent_of_its_measured_envelope",
		absf(bounds.size.z - LENGTH) <= LENGTH * 0.02 and absf(bounds.size.x - SPAN) <= SPAN * 0.02
			and absf(bounds.size.y - HEIGHT) <= HEIGHT * 0.02,
		"drawn %.3f long x %.3f span x %.3f high; reference %.2f x %.2f x %.2f" % [bounds.size.z, bounds.size.x,
			bounds.size.y, LENGTH, SPAN, HEIGHT])

	# THE GEAR, from the tyres' contact patches: every gear vertex within 3 cm of the ground.
	var gear := _vertices_in(frame, _mesh(frame, "Gear"))
	var lowest := _lowest(gear)
	var nose := Vector3.ZERO
	var port := Vector3.ZERO
	var starboard := Vector3.ZERO
	var counts := Vector3.ZERO
	for p in gear:
		if p.y > ground + 0.03:
			continue
		if absf(p.x) < 0.3:
			nose += p; counts.x += 1.0
		elif p.x < 0.0:
			port += p; counts.y += 1.0
		else:
			starboard += p; counts.z += 1.0
	nose /= maxf(counts.x, 1.0); port /= maxf(counts.y, 1.0); starboard /= maxf(counts.z, 1.0)
	var track: float = starboard.x - port.x
	var wheelbase: float = (port.z + starboard.z) * 0.5 - nose.z
	# ALL THREE TYRES, each: the lowest point alone passed with the mains 5 cm in the air, because the nose wheel still touched.
	_check("and_its_wheels_stand_where_a_parked_cessna_rests",
		absf(lowest.y - ground) < 0.01 and absf(bounds.position.y - ground) < 0.01 and counts.x > 0.0 and counts.y > 0.0
			and counts.z > 0.0,
		"lowest tyre %.3f, lowest point %.3f, ground contacts nose %d / port %d / starboard %d; a parked origin rests %.4f m over the ground"
			% [lowest.y, bounds.position.y, counts.x, counts.y, counts.z, rest])
	_check("and_its_track_and_wheelbase_are_the_manuals",
		absf(track - TRACK) <= TRACK * 0.02 and absf(wheelbase - WHEELBASE) <= WHEELBASE * 0.02,
		"track %.3f against %.3f, wheelbase %.3f against %.3f" % [track, TRACK, wheelbase, WHEELBASE])

	# THE WING, starboard, from the fixed wing and its flap and aileron together.
	var wing := _vertices_in(frame, _mesh(frame, "Airframe"))
	wing.append_array(_vertices_in(frame, _mesh(frame, "FlapStarboard")))
	wing.append_array(_vertices_in(frame, _mesh(frame, "AileronStarboard")))
	var high_enough: float = ground + 1.74
	var root_chord := _chord_at(_slice(wing, 0, 1.5), high_enough)
	var break_chord := _chord_at(_slice(wing, 0, 2.45), high_enough)
	var past_break := _chord_at(_slice(wing, 0, 3.2), high_enough)
	var tip_chord := _chord_at(_slice(wing, 0, TIP_RIB_OUT - 0.01), high_enough)
	_check("and_its_wing_keeps_a_constant_chord_to_the_break_and_tapers_outboard",
		absf(root_chord - ROOT_CHORD) <= ROOT_CHORD * 0.02 and absf(break_chord - root_chord) <= 0.01
			and past_break < root_chord * 0.95 and absf(tip_chord - TIP_CHORD) <= TIP_CHORD * 0.03,
		"chord %.3f at 1.5 m, %.3f at 2.45, %.3f at 3.2, %.3f at the tip rib; reference %.3f to %.2f m out, %.2f at the tip"
			% [root_chord, break_chord, past_break, tip_chord, ROOT_CHORD, BREAK_OUT, TIP_CHORD])
	var inboard := _quarter_chord_height(_slice(wing, 0, 1.0), high_enough)
	var outboard := _quarter_chord_height(_slice(wing, 0, 5.0), high_enough)
	var dihedral: float = rad_to_deg(atan2(outboard - inboard, 4.0))
	_check("and_its_wing_has_its_dihedral", absf(dihedral - DIHEDRAL) <= 0.2,
		"quarter chord %.3f m up at 1 m out and %.3f at 5 m: %.2f degrees; reference %.2f" % [inboard - ground,
			outboard - ground, dihedral, DIHEDRAL])

	# THE STRUT, from its own vertices: its outboard and inboard ends.
	var strut_head := Vector3(-INF, 0.0, 0.0)
	var strut_foot := Vector3(INF, 0.0, 0.0)
	for p in _vertices_in(frame, _mesh(frame, "StrutStarboard")):
		if p.x > strut_head.x:
			strut_head = p
		if p.x < strut_foot.x:
			strut_foot = p
	var head_aft: float = strut_head.z + LENGTH * 0.5
	var foot_aft: float = strut_foot.z + LENGTH * 0.5
	_check("and_its_lift_strut_runs_from_the_cabins_side_to_the_wing_at_ws_100",
		absf(strut_head.x - STRUT_HEAD.x) <= 0.08 and absf(head_aft - STRUT_HEAD.y) <= 0.10
			and absf(strut_foot.y - ground - STRUT_FOOT.x) <= 0.08 and absf(foot_aft - STRUT_FOOT.y) <= 0.10,
		"head %.2f m out, %.2f m aft; foot %.2f m up, %.2f m aft; reference head %.2f out %.2f aft, foot %.2f up %.2f aft" % [
			strut_head.x, head_aft, strut_foot.y - ground, foot_aft, STRUT_HEAD.x, STRUT_HEAD.y, STRUT_FOOT.x,
			STRUT_FOOT.y])

	# THE FIN: its leading edge at two heights, its cap and its beacon.
	var body := _vertices_in(frame, _mesh(frame, "Airframe"))
	var fin_low := _foremost_on_centreline(_slice(body, 1, ground + 1.80), SkyhawkAirframe.station(6.0))
	var fin_high := _foremost_on_centreline(_slice(body, 1, ground + 2.20), SkyhawkAirframe.station(6.0))
	var sweep: float = rad_to_deg(atan2(fin_high - fin_low, 0.40))
	var cap := -INF
	for p in body:
		if absf(p.x) < 0.1 and p.z > SkyhawkAirframe.station(7.9):
			cap = maxf(cap, p.y - ground)
	_check("and_its_fin_is_swept_to_its_cap_and_its_beacon_is_the_top_of_the_aircraft",
		absf(sweep - FIN_SWEEP) <= 2.0 and absf(cap - FIN_CAP) <= 0.02 and absf(bounds.end.y - ground - HEIGHT) <= 0.02,
		"leading edge swept %.1f degrees, cap %.3f m, beacon %.3f m; reference %.1f, %.2f, %.2f" % [sweep, cap,
			bounds.end.y - ground, FIN_SWEEP, FIN_CAP, HEIGHT])

	var tail := PackedVector3Array()
	for part in ["Airframe", "ElevatorPort", "ElevatorStarboard"]:
		for p in _vertices_in(frame, _mesh(frame, part)):
			if p.y < ground + 1.0 and p.y > ground + 0.7 and p.z > SkyhawkAirframe.station(6.2):
				tail.append(p)
	var tail_box := _box_of(tail)
	_check("and_its_stabiliser_spans_eleven_feet_four", absf(tail_box.size.x - TAIL_SPAN) <= TAIL_SPAN * 0.02,
		"%.3f m over the tips; reference %.3f" % [tail_box.size.x, TAIL_SPAN])

	# THE PROPELLER'S DISC, whatever angle its blades were parked at: twice its furthest tip from the hub, and the hub's
	# height less that.
	var hub: Vector3 = _mesh(frame, "Propeller").position
	var reach := 0.0
	for p in _vertices_in(frame, _mesh(frame, "Propeller")):
		reach = maxf(reach, Vector2(p.x - hub.x, p.y - hub.y).length())
	_check("and_its_propeller_is_76_inches_and_clears_the_ground_by_11_inches",
		absf(reach * 2.0 - PROPELLER) <= PROPELLER * 0.02 and absf(hub.y - reach - ground - PROP_CLEARANCE) <= 0.03,
		"%.3f m across, %.3f m over the ground; reference %.3f and %.3f" % [reach * 2.0, hub.y - reach - ground,
			PROPELLER, PROP_CLEARANCE])

	# THE CABIN: its skin's width outside and its lining's inside, both at the doors.
	var outside := 0.0
	for p in body:
		if absf(p.z - SkyhawkAirframe.station(2.6)) < 0.45 and p.y > ground + 0.8 and p.y < ground + 1.7:
			outside = maxf(outside, absf(p.x))
	var inside := INF
	for p in _slice(_vertices_in(frame, _mesh(frame, "Cabin")), 2, SkyhawkAirframe.station(2.6)):
		if p.y > ground + 0.9 and p.y < ground + 1.2 and absf(p.x) > 0.3:
			inside = minf(inside, absf(p.x))
	_check("and_its_cabin_is_as_wide_as_the_references_outside_and_in",
		absf(outside * 2.0 - CABIN_OUTSIDE) <= CABIN_OUTSIDE * 0.02 and inside * 2.0 >= CABIN_INSIDE,
		"%.3f m over the skin, %.3f m between the linings; reference %.2f outside, %.3f inside" % [outside * 2.0,
			inside * 2.0, CABIN_OUTSIDE, CABIN_INSIDE])

	# THE WINDOWS ROUND THE REFERENCE EYES: the door's glass beside each, spanning the eye's height, and the windscreen ahead
	# reaching over it.
	var glass := _vertices_in(frame, _mesh(frame, "Glazing"))
	var side_low := INF
	var side_high := -INF
	var screen_high := -INF
	var screen_low := INF
	for p in glass:
		var aft: float = p.z + LENGTH * 0.5
		if absf(absf(p.x) - 0.55) < 0.03 and absf(aft - EYE.z) < 0.2:
			side_low = minf(side_low, p.y - ground)
			side_high = maxf(side_high, p.y - ground)
		if aft < 2.0:
			screen_low = minf(screen_low, p.y - ground)
			screen_high = maxf(screen_high, p.y - ground)
	_check("and_its_windows_surround_the_reference_eyes",
		side_low < EYE.y - 0.10 and side_high > EYE.y + 0.15 and screen_low < EYE.y - 0.02 and screen_high > EYE.y + 0.35,
		"door glass %.2f to %.2f m, windscreen %.2f to %.2f m; eyes %.2f m up, %.2f m aft" % [side_low, side_high,
			screen_low, screen_high, EYE.y, EYE.z])
	view.queue_free()


## WHERE A MESH CROSSES A PLANE: every point at which a triangle's edge crosses `axis` (0 x, 1 y, 2 z) = `value`. The
## triangles are the vertex list in threes, so a measurement does not depend on where the mesh happens to have vertices.
func _slice(points: PackedVector3Array, axis: int, value: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for t in range(0, points.size() - 2, 3):
		for e in range(3):
			var a: Vector3 = points[t + e]
			var b: Vector3 = points[t + (e + 1) % 3]
			if (a[axis] - value) * (b[axis] - value) <= 0.0 and absf(b[axis] - a[axis]) > 1e-9:
				out.append(a.lerp(b, (value - a[axis]) / (b[axis] - a[axis])))
	return out


## THE CHORD of a slice across the wing: the fore-and-aft extent of its points above a height.
func _chord_at(slice: PackedVector3Array, above: float) -> float:
	var front := INF
	var back := -INF
	for p in slice:
		if p.y > above:
			front = minf(front, p.z)
			back = maxf(back, p.z)
	return back - front


## THE QUARTER-CHORD'S HEIGHT in a slice across the wing, on the chord line between its leading and trailing edges, so
## camber, thickness and twist about the quarter chord drop out.
func _quarter_chord_height(slice: PackedVector3Array, above: float) -> float:
	var le := Vector3(0.0, 0.0, INF)
	var te := Vector3(0.0, 0.0, -INF)
	for p in slice:
		if p.y > above:
			if p.z < le.z:
				le = p
			if p.z > te.z:
				te = p
	return le.y + 0.25 * (te.y - le.y)


## The foremost point on the centreline in a slice, aft of `aft_of`.
func _foremost_on_centreline(slice: PackedVector3Array, aft_of: float) -> float:
	var front := INF
	for p in slice:
		if absf(p.x) < 0.1 and p.z > aft_of:
			front = minf(front, p.z)
	return front


## WHERE A PARKED CESSNA'S ORIGIN RESTS over flat ground, asked of the simulation rather than read off its hull.
func _parked_rest_height() -> float:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -5.0, 0.0), Vector3(2000.0, 5.0, 2000.0))
	var e: Vector3 = Sim.geometry_of(Sim.Kind.CESSNA).get("extents", Vector3.ONE)
	var parked: int = int(world.spawn_vehicle(Sim.Kind.CESSNA, Vector3(0.0, e.y + 0.3, 0.0), 0.0, Vector3.ZERO))
	for i in range(600):
		world.tick(DT)
	var rest: float = (world.vehicle_state(parked).get("position", Vector3.ZERO) as Vector3).y
	world.teardown()
	if not (world is RefCounted):
		world.free()
	return rest


func _the_asset_boundary_is_independent_of_simulation() -> void:
	var geometry := Sim.geometry_of(Sim.Kind.CESSNA)
	var before := geometry.duplicate(true)
	var definition := ModelAssetDefinition.definition_for(Sim.Kind.CESSNA)
	var made := ModelAssetDefinition.instantiate_for(Sim.Kind.CESSNA, geometry)
	var node := made.get("node") as SkyhawkAirframe
	var drawn: Dictionary = node.sockets() if node != null else {}
	var declared: Dictionary = definition.get("sockets", {})
	var parted: Array[String] = []
	for socket in drawn:
		var want := ModelAssetDefinition._vector(drawn[socket])
		if not declared.has(socket) or not ModelAssetDefinition._vector(declared[socket]).is_equal_approx(want):
			parted.append("%s: package %s, airframe %s" % [socket, declared.get(socket), want])
	_check("the_packages_sockets_are_the_airframes_own_axles_hub_and_strut_heads",
		not drawn.is_empty() and parted.is_empty() and declared.size() == drawn.size(),
		"; ".join(parted) if not parted.is_empty() else "%d sockets agree" % drawn.size())
	var catalogue: Dictionary = VehicleCatalogue.of(Sim.Kind.CESSNA).get("visual", {})
	_check("and_the_package_declares_what_the_catalogue_does",
		not definition.has("error") and node != null and JSON.stringify(catalogue) == JSON.stringify(definition),
		"package %s, scene %s" % [String(definition.get("error", "valid")), node != null])
	_check("and_loading_the_visual_cannot_change_native_geometry_or_station_poses", before == Sim.geometry_of(Sim.Kind.CESSNA),
		"native contract unchanged")
	if node != null:
		node.free()


func _the_exterior_meets_its_budget() -> void:
	var made := ModelAssetDefinition.instantiate_for(Sim.Kind.CESSNA, Sim.geometry_of(Sim.Kind.CESSNA))
	var root := made.get("node") as Node3D
	var draws := 0
	var triangles := 0
	var materials: Dictionary = {}
	var ranged := 0
	if root != null:
		for child in root.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := child as MeshInstance3D
			draws += mesh_node.mesh.get_surface_count()
			if mesh_node.visibility_range_end > 0.0:
				ranged += 1
			materials[mesh_node.material_override] = true
			for surface in range(mesh_node.mesh.get_surface_count()):
				triangles += (mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		root.free()
	# THE LOW-POLY BUDGET IS THE LOOK, not a performance measure: "let's keep a somewhat lower poly look to models, not too
	# many very round edges" (the user, 2026-09-17), with the E-2D's airframe as the reference. 3,400 triangles is the
	# measured 2,936 with room to detail, and well under what smoothing this model back up would cost: the same model at
	# four points to a quarter section, eleven chord cuts, sixteen-sided wheels and a forty-sided disc was 5,320.
	_check("the_airframe_stays_inside_its_vr_budget", draws <= 20 and triangles <= 3400 and materials.size() <= 12 and ranged >= 1,
		"%d draws, %d triangles, %d materials, %d distance-culled fittings" % [draws, triangles, materials.size(), ranged])


func _the_cockpit_package_loads_every_station() -> void:
	var package: Dictionary = AuthoredCraftPackages.read(Sim.Kind.CESSNA)
	var wrong: Array[String] = []
	for seat in range(2):
		var built: Dictionary = AuthoredCraftPackages.make_station(Sim.Kind.CESSNA, seat)
		if built.has("error"):
			wrong.append("seat %d: %s" % [seat, built["error"]])
			continue
		var station := built["station"] as CockpitStation
		if station == null or station.controls().is_empty():
			wrong.append("seat %d has no devices" % seat)
		if station != null:
			station.free()
	_check("the_saved_package_and_both_stations_load_again_with_the_model_replaced",
		not package.has("error") and wrong.is_empty(),
		String(package.get("error", "two stations")) if wrong.is_empty() else "; ".join(wrong))


## THE MOVING PARTS: pure functions of what they are handed, and the manual's travels measured from the drawn vertices.
func _the_moving_parts_are_pure_and_travel_as_the_manual_says() -> void:
	var made := ModelAssetDefinition.instantiate_for(Sim.Kind.CESSNA, Sim.geometry_of(Sim.Kind.CESSNA))
	var frame := made.get("node") as SkyhawkAirframe
	if frame == null:
		_check("the_moving_parts_can_be_measured", false, "no airframe")
		return
	add_child(frame)
	var moving: Array[String] = ["FlapPort", "FlapStarboard", "AileronPort", "AileronStarboard", "ElevatorPort",
		"ElevatorStarboard", "TrimTab", "Rudder", "Propeller"]
	var neutral := _poses(frame, moving)
	# PURE: a value handed after another draws what that value handed alone does, and zero draws the part as built.
	var remembered: Array[String] = []
	var setters: Array[Callable] = [frame.set_flaps, frame.set_trim, frame.set_ailerons, frame.set_elevator, frame.set_rudder]
	for setter in setters:
		setter.call(0.3)
		setter.call(0.5)
	var twice := _poses(frame, moving)
	for setter in setters:
		setter.call(0.0)
	for setter in setters:
		setter.call(0.5)
	var once := _poses(frame, moving)
	for part in moving:
		if not (twice[part] as Transform3D).is_equal_approx(once[part]):
			remembered.append(part)
	for setter in setters:
		setter.call(0.0)
	var zero := _poses(frame, moving)
	for part in moving:
		if not (zero[part] as Transform3D).is_equal_approx(neutral[part]):
			remembered.append(part + " at zero")
	_check("and_its_moving_parts_are_pure_functions_of_what_they_are_handed", remembered.is_empty(),
		"0.3 then 0.5 draws what 0.5 does, and 0 draws each part as built" if remembered.is_empty() else "%s" % [remembered])

	# THE TRAVELS, as the angle each surface's trailing edge swings through about its node's own hinge.
	var said: Array[String] = []
	var wrong: Array[String] = []
	var cases: Array = [
		["flaps full", "FlapStarboard", frame.set_flaps, 1.0, -FLAPS_DOWN],
		["flaps half, port", "FlapPort", frame.set_flaps, 0.5, -FLAPS_DOWN * 0.5],
		["right roll, starboard aileron", "AileronStarboard", frame.set_ailerons, 1.0, AILERON_UP],
		["right roll, port aileron", "AileronPort", frame.set_ailerons, 1.0, -AILERON_DOWN],
		["left roll, starboard aileron", "AileronStarboard", frame.set_ailerons, -1.0, -AILERON_DOWN],
		["left roll, port aileron", "AileronPort", frame.set_ailerons, -1.0, AILERON_UP],
		["nose up, elevator", "ElevatorStarboard", frame.set_elevator, 1.0, ELEVATOR_UP],
		["nose down, elevator", "ElevatorPort", frame.set_elevator, -1.0, -ELEVATOR_DOWN],
		["nose-up trim, tab", "TrimTab", frame.set_trim, 1.0, -TAB_DOWN],
		["nose-down trim, tab", "TrimTab", frame.set_trim, -1.0, TAB_UP],
		["right rudder", "Rudder", frame.set_rudder, 1.0, RUDDER],
		["left rudder", "Rudder", frame.set_rudder, -1.0, -RUDDER],
	]
	for row in cases:
		var got: float = _swing_of(frame, String(row[1]), row[2] as Callable, float(row[3]))
		said.append("%s %.1f" % [row[0], got])
		if absf(got - float(row[4])) > 0.5:
			wrong.append("%s %.1f against %.1f" % [row[0], got, float(row[4])])
	# The Fowler flap goes aft as well as down.
	frame.set_flaps(0.0)
	var flap_up := _trailing_edge(frame, "FlapStarboard")
	frame.set_flaps(1.0)
	var flap_down := _trailing_edge(frame, "FlapStarboard")
	frame.set_flaps(0.0)
	var aft: float = flap_down[0].z - flap_up[0].z
	if aft < 0.1:
		wrong.append("the flap's hinge moved %.3f m aft" % aft)
	_check("and_its_surfaces_travel_as_the_maintenance_manual_says", wrong.is_empty(),
		("; ".join(said) + "; the flap slides %.2f m aft" % aft) if wrong.is_empty() else "; ".join(wrong))

	# THE PROPELLER: still when parked whatever the clock says; turning on the clock, the same angle for the same moment; its
	# blades giving way to a disc as the throttle opens.
	var blades := frame.find_child("Propeller", true, false) as Node3D
	var disc := frame.find_child("PropellerDisc", true, false) as MeshInstance3D
	frame.set_propeller(false, 0.0, 1.0)
	var parked_a: Basis = blades.basis
	frame.set_propeller(false, 0.0, 7.3)
	var parked_b: Basis = blades.basis
	frame.set_propeller(true, 0.0, 1.10)
	var idle_a: Basis = blades.basis
	var idle_disc: bool = disc.visible
	frame.set_propeller(true, 0.0, 1.15)
	var idle_b: Basis = blades.basis
	frame.set_propeller(true, 0.0, 1.10)
	var idle_again: Basis = blades.basis
	frame.set_propeller(true, 1.0, 1.10)
	var full_blades: bool = blades.visible
	var full_disc: bool = disc.visible
	var full_alpha: float = (disc.material_override as StandardMaterial3D).albedo_color.a
	frame.set_propeller(false, 0.0, 0.0)
	_check("and_its_propeller_stands_still_parked_and_turns_on_the_clock_into_a_disc",
		parked_a.is_equal_approx(parked_b) and not idle_a.is_equal_approx(idle_b) and idle_a.is_equal_approx(idle_again)
			and not idle_disc and not full_blades and full_disc and full_alpha > 0.2 and not disc.visible,
		"parked still %s; turning moves %s and repeats %s; idle disc %s; full throttle blades %s, disc %s at alpha %.2f" % [
			parked_a.is_equal_approx(parked_b), not idle_a.is_equal_approx(idle_b), idle_a.is_equal_approx(idle_again),
			idle_disc, full_blades, full_disc, full_alpha])
	frame.queue_free()


## THE ANGLE A SURFACE SWINGS THROUGH when `setter` is handed `amount`, in degrees: the rotation between its drawn poses,
## signed by which way its trailing edge went -- positive up, or to starboard for the rudder. The first version took the
## angle between hinge-to-trailing-edge vectors, and a flap's furthest-aft vertex lies along its hinge, so 30 degrees
## read as 12.4.
func _swing_of(frame: Node3D, part: String, setter: Callable, amount: float) -> float:
	var node := frame.find_child(part, true, false) as Node3D
	setter.call(0.0)
	var before := _trailing_edge(frame, part)
	var pose_before: Basis = (frame.global_transform.affine_inverse() * node.global_transform).basis
	setter.call(amount)
	var after := _trailing_edge(frame, part)
	var pose_after: Basis = (frame.global_transform.affine_inverse() * node.global_transform).basis
	setter.call(0.0)
	var moved: Vector3 = after[1] - before[1]
	var sign: float = signf(moved.x) if part == "Rudder" else signf(moved.y)
	return sign * rad_to_deg((pose_after * pose_before.inverse()).get_rotation_quaternion().get_angle())


## Each named part's transform in the airframe's frame.
func _poses(frame: Node3D, parts: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	for part in parts:
		var node := frame.find_child(part, true, false) as Node3D
		out[part] = frame.global_transform.affine_inverse() * node.global_transform
	return out


## A SURFACE'S HINGE AND TRAILING EDGE in the airframe's frame: [the node's own origin, the vertex furthest aft of it as
## built]. The vertex is chosen by index, so the same point is followed as the surface swings.
func _trailing_edge(frame: Node3D, part: String) -> Array[Vector3]:
	var node := frame.find_child(part, true, false) as MeshInstance3D
	var into := frame.global_transform.affine_inverse() * node.global_transform
	var vertices: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var furthest := 0
	for i in range(vertices.size()):
		if vertices[i].z > vertices[furthest].z:
			furthest = i
	return [into.origin, into * vertices[furthest]]


## EACH MACHINE DRAWS THE SURFACES FROM WHAT IT HOLDS: a server and two client worlds over a loopback, the first client the
## pilot of a Cessna in the air working the stick, rudder, throttle and flap lever, the second a machine that is not aboard.
## Each tick each machine hands its own bus and linkage to a VehicleView exactly as `draw` does. The pilot's machine must
## draw the linkage's stick and the bus's flaps on every tick; the other must draw the same flaps and a neutral stick,
## because the stick is not on the replicated bus. A parked Cessna nobody is in must not turn its propeller.
func _each_machine_draws_the_surfaces_from_what_it_holds() -> void:
	var server := _world(0)
	var clients: Array = [_world(1), _world(2)]
	for i in range(90):
		_step_all(server, clients, [_controls(), _controls()])
	var made: Dictionary = server.spawn_pilot(1, Sim.Kind.CESSNA, Vector3(0.0, 1500.0, 0.0), 0.0, Vector3(0.0, 0.0, -50.0))
	server.spawn_pilot(2, Sim.Kind.POD, Vector3(3000.0, 600.0, 0.0), 0.0, Vector3.ZERO)
	server.add_static_box(Vector3(-2500.0, -5.0, 0.0), Vector3(200.0, 5.0, 200.0))
	var parked_server: int = int(server.spawn_vehicle(Sim.Kind.CESSNA, Vector3(-2500.0, 1.2, 0.0), 0.0, Vector3.ZERO))
	var flaps_range: int = 0
	for row in (Sim.schema_of(Sim.Kind.CESSNA).get("channels", []) as Array):
		if int((row as Dictionary).get("channel", -1)) == Sim.Channel.FLAPS:
			flaps_range = int((row as Dictionary).get("range", 0))
	var views: Array[VehicleView] = []
	for i in range(2):
		var view := (load("res://objects/vehicles/craft_cessna.tscn") as PackedScene).instantiate() as VehicleView
		add_child(view)
		view.preview_kind = Sim.Kind.CESSNA
		view._show_in_editor()
		views.append(view)
	var disagreed: Array[int] = [0, 0]
	var seen: Array[int] = [0, 0]
	var stick_drawn: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var flaps_drawn: Array[float] = [0.0, 0.0]
	var turning: Array[bool] = [false, false]
	var parked_seen: bool = false
	var parked_turning: bool = false
	# THE FIRST NOTCH, THEN FULL: a drawing that snapped the flaps to up or down passed while the lever only ever went to full.
	var notch_drawn: float = 0.0
	for tick in range(300):
		if tick == 60 and flaps_range > 0:
			clients[0].send_command(Sim.Channel.FLAPS, 1)
		if tick == 160 and flaps_range > 0:
			clients[0].send_command(Sim.Channel.FLAPS, flaps_range)
		_step_all(server, clients, [_controls({"throttle": 0.7, "pitch": 0.6, "roll": -0.4, "rudder": 0.5}), _controls()])
		for i in range(2):
			var craft: int = 0
			var parked: int = 0
			for state in clients[i].vehicle_states():
				if int((state as Dictionary).get("kind", -1)) != Sim.Kind.CESSNA:
					continue
				if ((state as Dictionary).get("position", Vector3.ZERO) as Vector3).y > 500.0:
					craft = int((state as Dictionary).get("entity", 0))
				else:
					parked = int((state as Dictionary).get("entity", 0))
			if craft == 0:
				continue
			var bus: Dictionary = clients[i].craft_controls(craft)
			var linkage: Dictionary = clients[i].crew_controls(craft)
			var velocity: Vector3 = clients[i].vehicle_state(craft).get("velocity", Vector3.ZERO)
			views[i].draw_the_skyhawk_from(bus, linkage, clients[i].vehicle_seats(craft), velocity, tick * DT)
			seen[i] += 1
			var frame: SkyhawkAirframe = views[i]._skyhawk
			var stick: Vector2 = linkage.get("linked_stick", Vector2.ZERO)
			var want := Vector3(stick.x, stick.y, float(linkage.get("linked_rudder", 0.0))).clamp(-Vector3.ONE, Vector3.ONE)
			if frame.flaps_amount() != clampf(float(bus.get("flaps", 0.0)), 0.0, 1.0) or not frame.stick_amounts().is_equal_approx(want):
				disagreed[i] += 1
			stick_drawn[i] = frame.stick_amounts()
			flaps_drawn[i] = frame.flaps_amount()
			if i == 1 and frame.flaps_amount() > 0.05 and frame.flaps_amount() < 0.95:
				notch_drawn = frame.flaps_amount()
			turning[i] = bool(frame.propeller_state().get("turning", false))
			if i == 1 and parked > 0:
				parked_seen = true
				views[1].draw_the_skyhawk_from(clients[1].craft_controls(parked), clients[1].crew_controls(parked),
					clients[1].vehicle_seats(parked), clients[1].vehicle_state(parked).get("velocity", Vector3.ZERO), tick * DT)
				parked_turning = bool(frame.propeller_state().get("turning", false))
	_check("each_machine_draws_the_cessnas_surfaces_from_what_it_holds_on_every_tick",
		int(made.get("vehicle", 0)) > 0 and parked_server > 0 and disagreed[0] == 0 and disagreed[1] == 0
			and seen[0] > 200 and seen[1] > 200 and stick_drawn[0].length() > 0.3 and stick_drawn[1] == Vector3.ZERO
			and flaps_drawn[0] > 0.9 and flaps_drawn[1] > 0.9 and absf(notch_drawn - 1.0 / maxf(flaps_range, 1.0)) < 0.01
			and turning[0] and turning[1] and parked_seen and not parked_turning,
		"flaps range %d; the pilot's machine drew stick %s and flaps %.2f, disagreeing with what it holds on %d of %d ticks; the machine not aboard drew stick %s, the first notch at %.2f and full flaps at %.2f, disagreeing on %d of %d; propellers turning %s; a parked one seen %s, turning %s"
			% [flaps_range, stick_drawn[0], flaps_drawn[0], disagreed[0], seen[0], stick_drawn[1], notch_drawn,
				flaps_drawn[1], disagreed[1], seen[1], turning, parked_seen, parked_turning])
	for view in views:
		view.queue_free()
	_let_go(server)
	for client in clients:
		_let_go(client)


func _world(client_id: int) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(client_id)
	return world


func _step_all(server: Object, clients: Array, inputs: Array) -> void:
	for i in range(clients.size()):
		clients[i].set_input(inputs[i])
	server.tick(DT)
	for client in clients:
		client.tick(DT)
	for packet in server.take_outbound():
		var to: int = int(packet["peer"]) - 1
		if to >= 0 and to < clients.size():
			clients[to].deliver(0, packet["bytes"], packet["bits"])
	for i in range(clients.size()):
		for packet in clients[i].take_outbound():
			server.deliver(i + 1, packet["bytes"], packet["bits"])


func _controls(overrides: Dictionary = {}) -> Dictionary:
	var input := {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0,
		"brake": 0.0, "head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3.ZERO, "left_basis": Quaternion.IDENTITY, "right": Vector3.ZERO,
		"right_basis": Quaternion.IDENTITY, "grip_left": 0.0, "grip_right": 0.0,
		"buttons": 0, "trigger": 0.0, "kind_wanted": Sim.NO_KIND}
	for key in overrides:
		input[key] = overrides[key]
	return input


func _let_go(world: Object) -> void:
	world.teardown()
	if not (world is RefCounted):
		world.free()


func _mesh(root: Node3D, part: String) -> MeshInstance3D:
	return root.find_child(part, true, false) as MeshInstance3D


func _vertices_in(root: Node3D, drawn: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	if drawn == null or drawn.mesh == null:
		return out
	var into := Transform3D.IDENTITY
	var cursor: Node3D = drawn
	while cursor != root and cursor != null:
		into = cursor.transform * into
		cursor = cursor.get_parent() as Node3D
	for surface in range(drawn.mesh.get_surface_count()):
		for point in (drawn.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			out.append(into * point)
	return out


func _lowest(points: PackedVector3Array) -> Vector3:
	var lowest := Vector3(0.0, INF, 0.0)
	for p in points:
		if p.y < lowest.y:
			lowest = p
	return lowest


func _box_of(points: PackedVector3Array) -> AABB:
	var box := AABB()
	var any := false
	for p in points:
		box = box.expand(p) if any else AABB(p, Vector3.ZERO)
		any = true
	return box


func _drawn_bounds(root: Node3D) -> AABB:
	var box := AABB()
	var any := false
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var drawn := child as MeshInstance3D
		if drawn.mesh == null:
			continue
		for p in _vertices_in(root, drawn):
			box = box.expand(p) if any else AABB(p, Vector3.ZERO)
			any = true
	return box


## EVERY TRIANGLE OF THE AIRFRAME'S OUTSIDE, in the model's own frame, three vertices to a triangle.
##
## THE EXTERIOR AND NOT THE INTERIOR. The cabin lining is a second closed surface inside the first, and a point between
## the two crosses an even number of them and reads as outside its own aeroplane.
func _exterior_triangles(frame: SkyhawkAirframe) -> PackedVector3Array:
	var out := PackedVector3Array()
	if frame.exterior == null:
		return out
	for child in frame.exterior.find_children("*", "MeshInstance3D", true, false):
		var drawn := child as MeshInstance3D
		if drawn.mesh == null:
			continue
		var into := Transform3D.IDENTITY
		var cursor: Node3D = drawn
		while cursor != frame and cursor != null:
			into = cursor.transform * into
			cursor = cursor.get_parent() as Node3D
		# `surface_get_primitive_type` IS ArrayMesh'S AND NOT Mesh'S: asked of a BoxMesh it raises "Nonexistent
		# function" and returns null, so a filter on it silently drops every box, cylinder and capsule from the skin.
		var built := drawn.mesh as ArrayMesh
		for surface in range(drawn.mesh.get_surface_count()):
			if built != null and built.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arrays: Array = drawn.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: Variant = arrays[Mesh.ARRAY_INDEX]
			if index != null and (index as PackedInt32Array).size() > 0:
				for at in (index as PackedInt32Array):
					out.append(into * vertices[at])
			else:
				for point in vertices:
					out.append(into * point)
	return out


## HOW MANY POINTS OF A ROOM'S SURFACE LIE OUTSIDE THE SKIN, with the worst of them.
##
## The six faces are sampled on a grid rather than the volume, because a box is convex and its inside cannot leave a
## solid its surface stays in. ONE SECTION PER STATION, NOT ONE PER SAMPLE: the samples share a couple of dozen z
## between them, and slicing 2,936 triangles once each rather than three thousand times is the difference between a
## suite that runs in seconds and one that outstays its deadline.
func _samples_outside(skin: PackedVector3Array, room: AABB) -> Dictionary:
	var sections: Dictionary = {}
	var tested := 0
	var outside := 0
	var worst := 0.0
	var where := Vector3.ZERO
	for point in _room_surface(room):
		tested += 1
		var station := roundi(point.z * 10000.0)
		if not sections.has(station):
			sections[station] = _section(skin, point.z + SLICE_NUDGE)
		var section: PackedVector2Array = sections[station]
		# AND THE RAY IS NUDGED OFF THE VERTEX GRID FOR THE SAME REASON THE PLANE IS. The fuselage carries a vertex on
		# the centreline at the top of every section and another at the bottom, and a ray fired exactly along x = 0
		# counts them once or twice depending on which of the two edges meeting there happens to straddle it.
		if _inside(section, Vector2(point.x + SLICE_NUDGE, point.y + SLICE_NUDGE)):
			continue
		var by := _clearance(section, Vector2(point.x, point.y))
		if by <= SKIN_TOLERANCE:
			continue
		outside += 1
		if by > worst:
			worst = by
			where = point
	return {"tested": tested, "outside": outside, "worst": worst, "where": where}


func _room_surface(room: AABB) -> PackedVector3Array:
	var out := PackedVector3Array()
	var steps := Vector3i(maxi(1, ceili(room.size.x / SAMPLE_STEP)), maxi(1, ceili(room.size.y / SAMPLE_STEP)),
		maxi(1, ceili(room.size.z / SAMPLE_STEP)))
	for i in range(steps.x + 1):
		var x: float = room.position.x + room.size.x * float(i) / float(steps.x)
		for j in range(steps.y + 1):
			var y: float = room.position.y + room.size.y * float(j) / float(steps.y)
			for k in range(steps.z + 1):
				var z: float = room.position.z + room.size.z * float(k) / float(steps.z)
				# The surface only: a box is convex, so nothing inside it can be outside a solid its faces stay in.
				if i > 0 and i < steps.x and j > 0 and j < steps.y and k > 0 and k < steps.z:
					continue
				out.append(Vector3(x, y, z))
	return out


## THE SKIN'S OUTLINE AT ONE STATION, as a soup of segments in the (x, y) plane: every triangle that straddles the plane
## contributes the one segment where it crosses it.
func _section(skin: PackedVector3Array, z: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for base in range(0, skin.size(), 3):
		var hits := PackedVector2Array()
		_edge(skin[base], skin[base + 1], z, hits)
		_edge(skin[base + 1], skin[base + 2], z, hits)
		_edge(skin[base + 2], skin[base], z, hits)
		if hits.size() >= 2:
			out.append(hits[0])
			out.append(hits[1])
	return out


func _edge(a: Vector3, b: Vector3, z: float, out: PackedVector2Array) -> void:
	if (a.z <= z) == (b.z <= z):
		return
	var t: float = (z - a.z) / (b.z - a.z)
	out.append(Vector2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t))


## IS THE POINT INSIDE THE OUTLINE, by firing a ray UP and a ray DOWN and requiring an odd number of crossings on both?
##
## UP AND DOWN AND NOT SIDEWAYS, and that is measured rather than tidy. A horizontal ray through this cabin crosses the
## DOOR AND WINDOW SEAMS, which are drawn as inset strips -- open surfaces, not solids -- so it counts two crossings
## where there is one boundary. Measured at s 2.64, h 0.96, on the centreline: [above, below, outboard, inboard] came
## back [3, 1, 2, 2], so both horizontal rays called a point in the middle of the cabin "outside" and a majority-of-four
## rule rejected the whole room. Straight up and straight down meets only the skin, the wing and the gear, all closed.
##
## BOTH AND NOT EITHER, because requiring both is the conservative way round: an open surface makes a ray say "outside",
## so a point that is really outside cannot be rescued by one lucky direction, and the check fails safe.
func _inside(section: PackedVector2Array, at: Vector2) -> bool:
	var above := 0
	var below := 0
	for base in range(0, section.size(), 2):
		var a: Vector2 = section[base]
		var b: Vector2 = section[base + 1]
		if (a.x <= at.x) == (b.x <= at.x):
			continue
		if a.y + (b.y - a.y) * (at.x - a.x) / (b.x - a.x) > at.y:
			above += 1
		else:
			below += 1
	return (above % 2) == 1 and (below % 2) == 1


## HOW FAR A POINT STANDS FROM THE OUTLINE AT ITS OWN STATION. INF where the aeroplane draws nothing there at all,
## which is a point ahead of the nose or behind the tail and is as far outside as a point can be.
func _clearance(section: PackedVector2Array, at: Vector2) -> float:
	var nearest := INF
	for base in range(0, section.size(), 2):
		var a: Vector2 = section[base]
		var along: Vector2 = section[base + 1] - a
		var length: float = along.length_squared()
		var on: Vector2 = a if length <= 0.0 else a + along * clampf((at - a).dot(along) / length, 0.0, 1.0)
		nearest = minf(nearest, at.distance_to(on))
	return nearest


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
