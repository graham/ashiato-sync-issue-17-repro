extends Node
## Headless contract for the F-4E PHANTOM II airframe. Read RESULT=.
##
## EVERY CHECK BELOW READS THE DRAWN VERTICES, never the constants that produced them, because a check that shares its
## subject's frame of reference cannot catch the frame being wrong (`modelling_here.md` section 6). Measuring from
## `transform * mesh.get_aabb()` is out for the same reason -- a box round a box grows every time it is turned, and it
## read the folded Hawkeye 0.86 m too wide.
##
## WHAT IS NOT CHECKED, AND WHY. **The height.** The sheet offers three mutually inconsistent vertical scales and this
## lane could not reconcile them, so the fin tip is BUILT to the flight manual's published 5.004 m. A bound you fitted
## to is not a check: holding the drawn height to 5.004 would be the model asking itself a question it already knows
## the answer to, and it would pass for ever while everything else was wrong. `craft/phantom/sources.md` has the
## column. The length and the span are not fitted to in the same way -- the length comes off the drawing's own printed
## dimension and the span off the published figure, and both are then measured against what was actually drawn.
##
## THE THREE CHECKS THAT CAN REALLY FAIL, because nothing was fitted to satisfy them:
## - the QUARTER-CHORD SWEEP, computed from the drawn leading and trailing edges, against a published 45 degrees. The
##   article body calls 45 a LEADING-EDGE sweep; it is not, and building to that sentence would have drawn a wing
##   visibly too straight with every dimension check still green.
## - the WING REFERENCE AREA, integrated over the wing's own mesh, against a published 49.2 m2. It combines both axes,
##   which is what `modelling_here.md` names as the structural cross-check.
## - the DOGTOOTH's station, against the fold line the front view draws in a different view entirely.

const LENGTH: float = 19.202
const SPAN: float = 11.709
const WING_AREA: float = 49.2
const QUARTER_CHORD_SWEEP: float = 45.0
const DIHEDRAL: float = 12.0
const ANHEDRAL: float = 23.0
const DOGTOOTH_OUT: float = 4.044
const TRACK: float = 5.461
const NOSE_AXLE: float = 4.182
const MAIN_AXLE: float = 11.272

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[phantom] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var frame := PhantomAirframe.new()
	add_child(frame)
	frame.dress()
	_every_visible_mesh_is_a_named_part(frame)
	_the_drawn_aeroplane_is_the_published_length_and_span(frame)
	_the_outer_panels_carry_the_published_dihedral(frame)
	_the_stabilators_carry_the_published_anhedral(frame)
	_the_wing_has_its_dogtooth_where_the_front_view_folds(frame)
	_the_quarter_chord_sweep_is_the_published_forty_five(frame)
	_the_wing_area_is_the_published_area(frame)
	_the_gear_stands_at_the_measured_stations_and_track(frame)
	_the_spine_stands_at_the_printed_height(frame)
	_the_boundary_layer_gap_is_open(frame)
	_the_gun_fairing_is_under_the_nose_and_ahead_of_the_intakes(frame)
	_the_crew_and_their_room_are_inside_the_canopy(frame)
	_every_feature_is_a_pure_function_of_its_amount(frame)
	_the_stick_moves_the_right_surfaces_the_right_way(frame)
	_the_two_sides_mirror_each_other(frame)
	_the_canopies_and_the_nozzles_open(frame)
	_nothing_floats(frame)
	_every_face_is_wound_outwards(frame)
	_no_two_colours_in_one_mesh_are_indistinguishable(frame)
	_the_exterior_meets_the_first_lod_budget(frame)
	_finish()


## Named parts, so nothing is `@MeshInstance3D@7`, and the silhouette cues are asserted as a count.
func _every_visible_mesh_is_a_named_part(frame: Node3D) -> void:
	var names: Array = []
	for drawn in _meshes(frame):
		names.append(drawn.name)
	var wanted: Array = ["Fuselage", "CanopyFront", "CanopyRear", "Spine", "GunFairing", "Fin", "Rudder",
		"ArresterHook", "IntakePort", "IntakeStarboard", "SplitterPort", "SplitterStarboard",
		"WingPort", "WingStarboard",
		"SlatsPort", "SlatsStarboard", "FlapPort", "FlapStarboard", "AileronPort", "AileronStarboard",
		"StabilatorPort", "StabilatorStarboard",
		"NozzlePort", "NozzleStarboard", "NoseGear", "MainGearPort", "MainGearStarboard"]
	var missing: Array = []
	for w in wanted:
		if not names.has(w):
			missing.append(w)
	var generated: Array = []
	for n in names:
		if String(n).begins_with("@"):
			generated.append(n)
	_check("every_visible_mesh_is_a_named_part", missing.is_empty() and generated.is_empty(),
		"%d meshes; missing %s; generated names %s" % [names.size(), str(missing), str(generated)])


func _the_drawn_aeroplane_is_the_published_length_and_span(frame: Node3D) -> void:
	var box := _drawn_bounds(frame)
	var length: float = box.size.z
	var span: float = box.size.x
	_check("the_drawn_aeroplane_is_the_published_length_and_span",
		absf(length - LENGTH) / LENGTH < 0.02 and absf(span - SPAN) / SPAN < 0.02,
		"drawn %.3f m long against %.3f (%+.2f%%), %.3f m span against %.3f (%+.2f%%); the HEIGHT is not checked because it was fitted to"
			% [length, LENGTH, 100.0 * (length - LENGTH) / LENGTH, span, SPAN, 100.0 * (span - SPAN) / SPAN])


## THE 12 DEGREES, FROM THE DRAWN WING. Take the wing mesh's own vertices, find the lowest surface at a set of
## spanwise stations outboard of the break, and fit the rise. A wrong DIHEDRAL constant moves every one of them.
##
## AND RETURN THE STATIONS MEASURED AT, dividing by those rather than by a typed span: `lane/twin310` asked for the
## leading edge "at 0.90 and 4.90 m out" and divided by a typed 4.00 while a band wide enough to hold a vertex found
## them 4.42 m apart -- nine per cent, and a five-degree wing read 5.46 with nothing to say it had.
func _the_outer_panels_carry_the_published_dihedral(frame: Node3D) -> void:
	var said: PackedStringArray = []
	var worst: float = 0.0
	for part in ["WingPort", "WingStarboard"]:
		var sign: float = -1.0 if part.ends_with("Port") else 1.0
		var lows: Array = []
		for out in [4.40, 4.90, 5.35, 5.80]:
			var h: Variant = _lowest_near(frame, part, sign * out, 0.40)
			if h != null and (lows.is_empty() or absf(float(h[1]) - float(lows[-1][1])) > 0.05):
				lows.append([float(h[0]), float(h[1])])
		if lows.size() < 3:
			_check("the_outer_panels_carry_the_published_dihedral", false, "%s: only %d stations found" % [part, lows.size()])
			return
		var run: float = float(lows[-1][1]) - float(lows[0][1])
		var rise: float = float(lows[-1][0]) - float(lows[0][0])
		var degrees: float = rad_to_deg(atan2(rise, run))
		worst = maxf(worst, absf(degrees - DIHEDRAL))
		said.append("%s %.2f deg over the %.2f m MEASURED between %.2f and %.2f out"
			% [part, degrees, run, float(lows[0][1]), float(lows[-1][1])])
	_check("the_outer_panels_carry_the_published_dihedral", worst < 2.5,
		"%s; published %.1f, worst %.2f off" % [", ".join(said), DIHEDRAL, worst])


func _the_stabilators_carry_the_published_anhedral(frame: Node3D) -> void:
	var said: PackedStringArray = []
	var worst: float = 0.0
	for part in ["StabilatorPort", "StabilatorStarboard"]:
		var sign: float = -1.0 if part.ends_with("Port") else 1.0
		var lows: Array = []
		for out in [0.30, 0.90, 1.50, 2.10, 2.52]:
			var h: Variant = _lowest_near(frame, part, sign * out, 0.30)
			if h != null and (lows.is_empty() or absf(float(h[1]) - float(lows[-1][1])) > 0.05):
				lows.append([float(h[0]), float(h[1])])
		if lows.size() < 3:
			_check("the_stabilators_carry_the_published_anhedral", false, "%s: only %d stations" % [part, lows.size()])
			return
		var run: float = float(lows[-1][1]) - float(lows[0][1])
		var fall: float = float(lows[0][0]) - float(lows[-1][0])
		var degrees: float = rad_to_deg(atan2(fall, run))
		worst = maxf(worst, absf(degrees - ANHEDRAL))
		said.append("%s %.2f deg down over the %.2f m MEASURED between %.2f and %.2f out"
			% [part, degrees, run, float(lows[0][1]), float(lows[-1][1])])
	_check("the_stabilators_carry_the_published_anhedral", worst < 2.5,
		"%s; published %.1f, worst %.2f off" % [", ".join(said), ANHEDRAL, worst])


## THE DOGTOOTH, from the drawn leading edge: the step in the foremost drawn point as the span is walked outward.
## Its station is held to the FOLD LINE THE FRONT VIEW DRAWS, which is a different view of the drawing and was not
## used to find it -- two references that never saw each other.
func _the_wing_has_its_dogtooth_where_the_front_view_folds(frame: Node3D) -> void:
	# FIT THE INBOARD LEADING EDGE over its own four clean ring stations, then walk OUTWARD and find
	# the first station whose drawn leading edge stands forward of that line. The first version
	# walked in 0.13 m steps with a +/-0.05 band, which finds nothing between rings, so `previous`
	# went stale and it reported a 1,005 mm step at 3.18 m out. A lofted wing has vertices only
	# where its rings are, and a check that samples between them is measuring its own gaps.
	var inboard: Array = []
	for out in [0.78, 1.60, 2.40, 3.20]:
		var a: Variant = _foremost_at(frame, "WingStarboard", out, 0.06)
		if a != null:
			inboard.append([out, float(a)])
	if inboard.size() < 3:
		_check("the_wing_has_its_dogtooth_where_the_front_view_folds", false,
			"only %d inboard stations" % inboard.size())
		return
	var at: float = 0.0
	var step: float = 0.0
	for out in [3.60, 4.04, 4.45, 4.70, 5.30]:
		var a: Variant = _foremost_at(frame, "WingStarboard", out, 0.06)
		if a == null:
			continue
		var predicted: float = _at(inboard, out)
		var forward: float = predicted - float(a)
		if forward > 0.10:
			at = out
			step = forward
			break
	_check("the_wing_has_its_dogtooth_where_the_front_view_folds",
		step > 0.10 and absf(at - DOGTOOTH_OUT) < 0.30,
		"the drawn leading edge steps %.0f mm forward of the inboard panel's own fitted line at %.2f m out, against the FRONT VIEW's fold line at %.3f -- a different view, not used to build it"
			% [1000.0 * step, at, DOGTOOTH_OUT])


## THE QUARTER CHORD, FROM THE DRAWN EDGES. Three quarters of the leading edge's sweep plus one quarter of the
## trailing edge's. Nothing here was fitted to 45, and the leading edge alone is 51.5 -- which is the whole point.
func _the_quarter_chord_sweep_is_the_published_forty_five(frame: Node3D) -> void:
	var le: Array = []
	var te: Array = []
	# The inboard panel's OWN ring stations, and ONLY the clean ones. Including 4.04 caught the
	# dogtooth's outboard ring two millimetres away, whose leading edge is 316 mm further forward,
	# and dragged the fitted sweep from 51.47 to 49.70 and the quarter chord to 43.37.
	for out in [0.78, 1.60, 2.40, 3.20]:
		var a: Variant = _foremost_at(frame, "WingStarboard", out, 0.10)
		var b: Variant = _aftmost_at(frame, "WingStarboard", out, 0.10)
		if a != null and b != null:
			le.append([out, float(a)])
			te.append([out, float(b)])
	if le.size() < 4:
		_check("the_quarter_chord_sweep_is_the_published_forty_five", false, "only %d stations" % le.size())
		return
	var sweep_le: float = _slope(le)
	var sweep_te: float = _slope(te)
	var quarter: float = rad_to_deg(atan(0.75 * tan(deg_to_rad(sweep_le)) + 0.25 * tan(deg_to_rad(sweep_te))))
	_check("the_quarter_chord_sweep_is_the_published_forty_five", absf(quarter - QUARTER_CHORD_SWEEP) < 2.0,
		"drawn LE %.2f deg, TE %.2f deg -> quarter chord %.2f against a published %.1f (%+.2f)"
			% [sweep_le, sweep_te, quarter, QUARTER_CHORD_SWEEP, quarter - QUARTER_CHORD_SWEEP])


## THE WING'S AREA, summed over the wing's OWN mesh. `modelling_here.md` section 6: a lifting surface buried in the
## body cannot be measured at all, and sampling chords at stations fails quietly on a lofted slab. The planform is the
## sum of the triangles projected on the plan, HALVED because the upper and lower skins project onto the same ground.
func _the_wing_area_is_the_published_area(frame: Node3D) -> void:
	var area: float = 0.0
	for part in ["WingPort", "WingStarboard"]:
		area += _plan_area(frame, part)
	# The drawn panels start outboard of the fuselage side; the published reference area is the trapezium extended to
	# the centreline, so the carry-through is added from the drawn root chord. Both halves are measured, not typed.
	var root_chord: float = 0.0
	var a: Variant = _foremost_at(frame, "WingStarboard", 0.80, 0.06)
	var b: Variant = _aftmost_at(frame, "WingStarboard", 0.80, 0.06)
	if a != null and b != null:
		root_chord = float(b) - float(a)
	var carry: float = root_chord * 1.60
	var total: float = area + carry
	_check("the_wing_area_is_the_published_area", absf(total - WING_AREA) / WING_AREA < 0.08,
		"drawn panels %.2f m2 + %.2f m2 of carry-through between them = %.2f against a published %.1f (%+.2f%%)"
			% [area, carry, total, WING_AREA, 100.0 * (total - WING_AREA) / WING_AREA])


func _the_gear_stands_at_the_measured_stations_and_track(frame: Node3D) -> void:
	var origin := _drawn_bounds(frame)
	var nose_contact := _contact_of(frame, "NoseGear")
	var port_contact := _contact_of(frame, "MainGearPort")
	var starboard_contact := _contact_of(frame, "MainGearStarboard")
	var nose_station: float = nose_contact.z - origin.position.z
	var main_station: float = port_contact.z - origin.position.z
	# THE TYRE, NOT THE PART. Taking the whole gear mesh's centre included its door plate and
	# pulled the track 0.45 m inboard: a centroid over a set hides every member that is not the
	# one being asked about (`lane/harriershape`, "a check on a maximum is blind").
	var track: float = absf(starboard_contact.x - port_contact.x)
	var wheelbase: float = main_station - nose_station
	_check("the_gear_stands_at_the_measured_stations_and_track",
		absf(track - TRACK) < 0.25 and absf(wheelbase - (MAIN_AXLE - NOSE_AXLE)) < 0.40,
		"nose axle at station %.2f (measured %.2f), main at %.2f (%.2f), wheelbase %.2f against the PRINTED %.2f, track %.2f against %.2f"
			% [nose_station, NOSE_AXLE, main_station, MAIN_AXLE, wheelbase, MAIN_AXLE - NOSE_AXLE, track, TRACK])


## THE BOUNDARY-LAYER GAP IS OPEN, which the brief named and which is the point of drawing a splitter at all: there
## must be daylight between the splitter plate and the fuselage side, at the intake's own stations.
## THE SPINE AT THE PRINTED 3.28 m. **THIS ONE IS FITTED TO AND IS A REGRESSION GUARD, NOT EVIDENCE** -- the spine
## was BUILT to that figure, so it cannot fail for the reason a real check can. It is here because it guards the worst
## mistake this lane made, and `modelling_here.md` says encoding a mistake you actually made as a mutant is the best
## use of one there is.
##
## THE MISTAKE: the drawing carries two long level lines over the fuselage, at 3.33 and 3.28 m, and this lane took
## them for the page's own construction lines and MASKED THEM OUT before reading the top of the body. What was left
## was a panel line at about 2.75, so the whole aeroplane was drawn half a metre too flat -- and every dimension check
## stayed green, because length, span, track and wheelbase do not know where the top of a fuselage is. Only the
## orthographic overlay laid on the drawing found it. The mutant restores 2.77 and this check must go red.
func _the_spine_stands_at_the_printed_height(frame: Node3D) -> void:
	var spine := _bounds_of(frame, "Spine")
	var origin := _drawn_bounds(frame)
	var top: float = spine.end.y - origin.position.y
	var printed: float = 3.280
	_check("the_spine_stands_at_the_printed_height", absf(top - printed) < 0.08,
		"the drawn spine tops out %.3f m over the ground against the PRINTED %.3f -- fitted to, so this guards the half metre this lane once lost, and is not evidence"
			% [top, printed])


func _the_boundary_layer_gap_is_open(frame: PhantomAirframe) -> void:
	var said: PackedStringArray = []
	var open := true
	for side in [["SplitterStarboard", 1.0], ["SplitterPort", -1.0]]:
		var part: String = side[0]
		var sign: float = side[1]
		var splitter := _bounds_of(frame, part)
		var inner: float = splitter.position.x if sign > 0.0 else splitter.end.x
		var skin: float = sign * frame.fuselage_half(7.5)
		var gap: float = absf(inner) - absf(skin)
		if gap < 0.04:
			open = false
		said.append("%s stands %.3f m off the skin" % [part, gap])
	_check("the_boundary_layer_gap_is_open", open, ", ".join(said))


func _the_gun_fairing_is_under_the_nose_and_ahead_of_the_intakes(frame: Node3D) -> void:
	var gun := _bounds_of(frame, "GunFairing")
	var intake := _bounds_of(frame, "IntakeStarboard")
	var origin := _drawn_bounds(frame)
	var gun_aft: float = gun.end.z - origin.position.z
	var intake_fwd: float = intake.position.z - origin.position.z
	var body_bottom: float = float((_lowest_near(frame, "Fuselage", 0.0, 0.20) as Array)[0])
	_check("the_gun_fairing_is_under_the_nose_and_ahead_of_the_intakes",
		gun_aft < intake_fwd and gun.get_center().y < body_bottom + 0.30,
		"the fairing ends at station %.2f, the intake begins at %.2f; the fairing's middle sits %.2f m under the belly's %.2f"
			% [gun_aft, intake_fwd, gun.get_center().y, body_bottom])


func _the_crew_and_their_room_are_inside_the_canopy(frame: Node3D) -> void:
	var room: Dictionary = frame.cabin_room()
	var canopy := _bounds_of(frame, "CanopyFront").merge(_bounds_of(frame, "CanopyRear"))
	var eyes: Array = frame.crew_eyes()
	var inside := true
	var said: PackedStringArray = []
	for eye in eyes:
		var e: Vector3 = eye
		var ok: bool = canopy.grow(0.08).has_point(e)
		inside = inside and ok
		said.append("eye at z %.2f %s" % [e.z, "inside" if ok else "OUTSIDE"])
	var box: AABB = room["room"]
	_check("the_crew_and_their_room_are_inside_the_canopy", inside and bool(room["drawn"]),
		"%s; the declared room is %.2f x %.2f x %.2f and the canopy's box %.2f x %.2f x %.2f"
			% [", ".join(said), box.size.x, box.size.y, box.size.z, canopy.size.x, canopy.size.y, canopy.size.z])


## ---- what moves --------------------------------------------------------------------------------------------------

## A PURE FUNCTION OF THE AMOUNT IT IS HANDED: `set_x(a)` then `set_x(b)` must draw exactly what `set_x(b)` draws on
## its own. A setter that accumulated, or that held a timer, would pass every angle check and drift under use --
## `TomcatAirframe` states the same contract for its sweep and its surfaces. Asked of the DRAWN VERTICES, over every
## feature the airframe declares, so a feature added later is covered without touching this.
func _every_feature_is_a_pure_function_of_its_amount(frame: PhantomAirframe) -> void:
	var worst: float = 0.0
	var where := ""
	for feature in frame.features():
		var name: String = feature["name"]
		var low: float = feature["low"]
		var high: float = feature["high"]
		var setter: Callable = feature["set"]
		var a: float = lerpf(low, high, 0.3)
		var b: float = lerpf(low, high, 0.75)
		setter.call(b)
		var alone := _all_points(frame)
		setter.call(a)
		setter.call(b)
		var after := _all_points(frame)
		var apart: float = 0.0
		for i in range(mini(alone.size(), after.size())):
			apart = maxf(apart, (alone[i] - after[i]).length())
		if apart > worst:
			worst = apart
			where = name
		setter.call(lerpf(low, high, 0.0 if low >= 0.0 else 0.5))
	frame.follow_the_stick(Vector2.ZERO, 0.0)
	_check("every_feature_is_a_pure_function_of_its_amount", worst < 1e-5,
		"the worst vertex over %d features is %.8f m from where setting the amount alone puts it (%s)"
			% [frame.features().size(), worst, where if worst > 0.0 else "none moved"])


## THE STICK MOVES THE RIGHT SURFACES THE RIGHT WAY, read off the drawn vertices and never off the setters.
##
## This is the check that cannot be satisfied by a hinge wound backwards, which is the one thing a mirrored pair gets
## wrong: `_hinge` winds each axis from the geometry, and if that reasoning were wrong BOTH sides would still turn by
## the right ANGLE. Only the direction catches it. Stick right rolls right: starboard aileron UP, port DOWN.
func _the_stick_moves_the_right_surfaces_the_right_way(frame: PhantomAirframe) -> void:
	frame.follow_the_stick(Vector2.ZERO, 0.0)
	var rest: Dictionary = _trailing_edges(frame)
	var said: PackedStringArray = []
	var ok := true

	frame.follow_the_stick(Vector2(1.0, 0.0), 0.0)
	var rolled: Dictionary = _trailing_edges(frame)
	var stbd: float = rolled["AileronStarboard"] - rest["AileronStarboard"]
	var port: float = rolled["AileronPort"] - rest["AileronPort"]
	ok = ok and stbd > 0.02 and port < -0.02
	said.append("stick right: starboard aileron %+.3f m, port %+.3f m" % [stbd, port])

	frame.follow_the_stick(Vector2(0.0, 1.0), 0.0)
	var pulled: Dictionary = _trailing_edges(frame)
	var pitch: float = pulled["StabilatorStarboard"] - rest["StabilatorStarboard"]
	ok = ok and pitch > 0.02
	said.append("stick back: stabilator trailing edge %+.3f m" % pitch)

	frame.follow_the_stick(Vector2.ZERO, 1.0)
	var yawed: Dictionary = _trailing_edges(frame)
	var rud: float = yawed["Rudder"] - rest["Rudder"]
	ok = ok and absf(rud) > 0.02
	said.append("right pedal: rudder trailing edge moved %+.3f m across" % rud)

	frame.follow_the_stick(Vector2.ZERO, 0.0)
	_check("the_stick_moves_the_right_surfaces_the_right_way", ok, ", ".join(said))


## THE TWO SIDES MIRROR EACH OTHER at rest and at full deflection. A pair built from one builder with a side sign can
## still come out asymmetric if a hinge's axis is reasoned rather than measured.
func _the_two_sides_mirror_each_other(frame: PhantomAirframe) -> void:
	var worst: float = 0.0
	var where := ""
	# ONLY THE POSES WHERE THE TWO SIDES SHOULD MATCH. Stick RIGHT is not one of them: the ailerons and the
	# stabilators are DIFFERENTIAL, so a mirror test at full roll asks an aeroplane to be symmetric while it is
	# rolling, and the first version of this check failed on a stabilator pair that was behaving correctly. A guard
	# that cannot be satisfied is as useless as one that cannot fail -- the roll case is asked below instead, as
	# ANTI-symmetry, which is the property that actually holds.
	for pose in [[0.0, 0.0], [0.0, 1.0], [0.0, -1.0]]:
		frame.follow_the_stick(Vector2(pose[0], pose[1]), 0.0)
		for pair in [["WingPort", "WingStarboard"], ["StabilatorPort", "StabilatorStarboard"],
				["SlatsPort", "SlatsStarboard"], ["FlapPort", "FlapStarboard"],
				["NozzlePort", "NozzleStarboard"], ["IntakePort", "IntakeStarboard"]]:
			var a := _bounds_of(frame, pair[0])
			var b := _bounds_of(frame, pair[1])
			# the mirror of the port box is the starboard box with x negated
			var apart: float = maxf(absf(a.position.y - b.position.y), absf(a.position.z - b.position.z))
			apart = maxf(apart, absf(a.size.y - b.size.y))
			apart = maxf(apart, absf(absf(a.position.x + a.size.x) - absf(b.position.x)))
			if apart > worst:
				worst = apart
				where = "%s against %s at stick (%.0f, %.0f)" % [pair[0], pair[1], pose[0], pose[1]]
	# AND AT FULL ROLL THE TWO SIDES MUST BE ANTI-SYMMETRIC: whatever the starboard aileron does, the port one does
	# the opposite by the same amount. That is the property a differential pair really has, and it catches a hinge
	# wound the same way on both sides, which the mirror test above cannot see at zero roll.
	frame.follow_the_stick(Vector2.ZERO, 0.0)
	var rest: Dictionary = _trailing_edges(frame)
	frame.follow_the_stick(Vector2(1.0, 0.0), 0.0)
	var rolled: Dictionary = _trailing_edges(frame)
	var a_stbd: float = rolled["AileronStarboard"] - rest["AileronStarboard"]
	var a_port: float = rolled["AileronPort"] - rest["AileronPort"]
	var s_stbd: float = rolled["StabilatorStarboard"] - rest["StabilatorStarboard"]
	var s_port: float = rolled["StabilatorPort"] - rest["StabilatorPort"]
	var anti: float = maxf(absf(a_stbd + a_port), absf(s_stbd + s_port))
	frame.follow_the_stick(Vector2.ZERO, 0.0)
	_check("the_two_sides_mirror_each_other", worst < 0.02 and anti < 0.03,
		"at rest and in pitch the worst mismatch is %.4f m (%s); at full roll the ailerons move %+.3f and %+.3f and the stabilators %+.3f and %+.3f, so the two pairs are anti-symmetric to %.4f m"
			% [worst, where, a_stbd, a_port, s_stbd, s_port, anti])


## THE CANOPIES OPEN UPWARD AND THE NOZZLES OPEN OUTWARD, both read from the drawn vertices.
func _the_canopies_and_the_nozzles_open(frame: PhantomAirframe) -> void:
	frame.set_canopies(0.0)
	frame.set_nozzle(0.0)
	var shut_front := _bounds_of(frame, "CanopyFront")
	var shut_nozzle := _bounds_of(frame, "NozzleStarboard")
	frame.set_canopies(1.0)
	frame.set_nozzle(1.0)
	var open_front := _bounds_of(frame, "CanopyFront")
	var open_nozzle := _bounds_of(frame, "NozzleStarboard")
	var rose: float = open_front.end.y - shut_front.end.y
	var widened: float = open_nozzle.size.x - shut_nozzle.size.x
	frame.set_canopies(0.0)
	frame.set_nozzle(0.0)
	_check("the_canopies_and_the_nozzles_open", rose > 0.20 and widened > 0.05,
		"the front canopy's top rises %+.3f m when it opens; the nozzle's exit widens %+.3f m at full afterburner"
			% [rose, widened])


## EVERY TRAILING EDGE that moves, as one number a check can compare: the aftmost drawn point of each surface, in the
## axis that surface moves in. Height for the wing's and the tailplane's, across for the rudder's.
func _trailing_edges(frame: Node3D) -> Dictionary:
	var out: Dictionary = {}
	for part in ["AileronPort", "AileronStarboard", "StabilatorPort", "StabilatorStarboard", "Rudder"]:
		var points := _points_of(frame, part)
		if points.is_empty():
			continue
		var aftmost: Vector3 = points[0]
		for p in points:
			if p.z > aftmost.z:
				aftmost = p
		out[part] = aftmost.x if part == "Rudder" else aftmost.y
	return out


## EVERY DRAWN VERTEX in the craft's frame, in a stable order, for the purity check.
func _all_points(frame: Node3D) -> PackedVector3Array:
	var out: PackedVector3Array = []
	for drawn in _meshes(frame):
		var to: Transform3D = frame.global_transform.affine_inverse() * drawn.global_transform
		for s in range(drawn.mesh.get_surface_count()):
			for p in (drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				out.append(to * p)
	return out


## NOTHING FLOATS: every drawn part touches another, so the aeroplane is ONE assembly.
##
## `modelling_here.md` section 6: "A PART CAN COME OFF, AND NOTHING WILL SAY SO." The tanker's tail assembly hung in
## mid-air and survived every suite indefinitely, because **a dimension is right whether or not the part is joined on**
## and a bounding box round a detached part still contains it. This lane met it too: the fin was drawn with a flat root
## at 3.16 m while the deck under it falls to 2.70, so aft of about station 15 it floated clear. Fifteen checks green,
## and only the side overlay showed it.
##
## The recipe is `tests/buildings_gallery_shot.gd:_nothing_floats`: union-find over the parts' boxes, two joined when
## their spans meet on all three axes within a tolerance, and **the number of groups held to a count DERIVED from the
## plan** rather than typed. An aeroplane is one body, so the count is ONE -- and the smallest group names the stray.
##
## **AND HERE IS WHAT IT CANNOT DO, MEASURED RATHER THAN ASSUMED.** A BOX is not a surface. The first mutant written
## for this check raised the fin clear of the deck and the check stayed GREEN, because the fin's box still overlapped
## the spine's: boxes touch long after the skins have parted. So this catches a part that is WHOLLY clear of
## everything -- the tanker's tail assembly, which is the case it was written for -- and it does NOT catch the fault
## that prompted it. **The fin's own 0.3 m gap was found by the side overlay and by nothing else**, and its mutant
## detaches a part outright so that the check is at least proved able to fail. Say what a check cannot do beside what
## it can, or the next reader will trust it for the wrong thing.
func _nothing_floats(frame: Node3D) -> void:
	var parts: Array = []
	for drawn in _meshes(frame):
		parts.append([drawn.name, _bounds_of(frame, String(drawn.name))])
	var owner: Array = []
	for i in range(parts.size()):
		owner.append(i)
	var find := func(a: int) -> int:
		var r: int = a
		while owner[r] != r:
			r = owner[r]
		return r
	for i in range(parts.size()):
		for j in range(i + 1, parts.size()):
			var a: AABB = (parts[i][1] as AABB).grow(0.02)
			var b: AABB = parts[j][1] as AABB
			if a.intersects(b) or a.encloses(b) or b.grow(0.02).encloses(parts[i][1]):
				var ra: int = find.call(i)
				var rb: int = find.call(j)
				if ra != rb:
					owner[rb] = ra
	var groups: Dictionary = {}
	for i in range(parts.size()):
		var r: int = find.call(i)
		if not groups.has(r):
			groups[r] = []
		(groups[r] as Array).append(parts[i][0])
	var smallest: Array = []
	for g in groups.values():
		if smallest.is_empty() or (g as Array).size() < smallest.size():
			smallest = g
	_check("nothing_floats", groups.size() == 1,
		"%d part(s) in %d group(s); an aeroplane is ONE assembly. Smallest group: %s"
			% [parts.size(), groups.size(), str(smallest)])


## A face wound backwards is invisible and nothing else will find it (`tests/ship_models.gd:_wound_outwards`).
func _every_face_is_wound_outwards(frame: Node3D) -> void:
	var wrong: int = 0
	var total: int = 0
	for drawn in _meshes(frame):
		for s in range(drawn.mesh.get_surface_count()):
			var arrays: Array = drawn.mesh.surface_get_arrays(s)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			if normals.is_empty():
				continue
			for t in range(0, points.size() - 2, 3):
				var face: Vector3 = (points[t + 2] - points[t]).cross(points[t + 1] - points[t])
				if face.length_squared() < 1e-12:
					continue
				total += 1
				if face.normalized().dot(normals[t]) < 0.0:
					wrong += 1
	_check("every_face_is_wound_outwards", wrong == 0, "%d of %d faces wound against their normal" % [wrong, total])


## SECTION 4's QUANTISATION RULE, asked per MESH rather than fleet-wide. `SurfaceTool.commit` quantises vertex colour
## to eight bits a channel, and every check here that finds a part by its paint depends on two colours staying apart.
## `lane/roadfleet` proved the fleet-wide form is the wrong question: what matters is whether two colours collide IN
## ONE MESH, because a mesh is where a check has to tell two parts apart.
func _no_two_colours_in_one_mesh_are_indistinguishable(frame: Node3D) -> void:
	var worst: float = 1.0
	var where := ""
	for drawn in _meshes(frame):
		var seen: Array = []
		for s in range(drawn.mesh.get_surface_count()):
			var colours: PackedColorArray = drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
			for c in colours:
				var fresh := true
				for k in seen:
					if (k as Color).is_equal_approx(c):
						fresh = false
						break
				if fresh:
					seen.append(c)
		for i in range(seen.size()):
			for j in range(i + 1, seen.size()):
				var a: Color = seen[i]
				var b: Color = seen[j]
				var apart: float = maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))
				if apart < worst:
					worst = apart
					where = "%s: %s and %s" % [drawn.name, str(a), str(b)]
	_check("no_two_colours_in_one_mesh_are_indistinguishable", worst >= 0.03,
		"the closest pair in any one mesh is %.3f apart in its widest channel -- %s" % [worst, where])


## THE BUDGET for a first exterior LOD (`aircraft_model_fidelity_plan.md`): at most 100,000 triangles and 30 draw
## surfaces. THE LANE ASKED FOR 2,800 against the Tomcat's 1,546 and is held to its own number, not to the roomy one.
func _the_exterior_meets_the_first_lod_budget(frame: Node3D) -> void:
	var triangles: int = 0
	var draws: int = 0
	var culled: int = 0
	for drawn in _meshes(frame):
		draws += drawn.mesh.get_surface_count()
		if drawn.visibility_range_end > 0.0:
			culled += 1
		for s in range(drawn.mesh.get_surface_count()):
			triangles += (drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_check("the_exterior_meets_the_first_lod_budget", triangles <= 2800 and draws <= 30 and culled >= 3,
		"the whole PhantomAirframe subtree: %d triangles against the 2,800 this lane asked for (the Tomcat is 1,546), %d draw surfaces, %d distance-culled"
			% [triangles, draws, culled])


## ---- reading the drawn vertices --------------------------------------------------------------------------------

## Every drawn mesh at or under `root`. **INCLUDING `root` ITSELF**, which the first version did not: asked for one
## named part it returned nothing, because a `MeshInstance3D` leaf has no children, and eight checks went red at once
## reporting an aeroplane with no wings, no gear and no canopy. The whole-aeroplane checks were green throughout,
## because those walk the airframe node, which does have children. A helper that is right for one caller and wrong for
## another is the worst kind, and only asking it for a single part found it.
func _meshes(root: Node) -> Array:
	var out: Array = []
	if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
		out.append(root)
	for child in root.get_children():
		out.append_array(_meshes(child))
	return out


## MEASURE FROM TRANSFORMED VERTICES, NEVER `transform * mesh.get_aabb()`.
func _drawn_bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for drawn in _meshes(root):
		var to: Transform3D = root.global_transform.affine_inverse() * drawn.global_transform
		for s in range(drawn.mesh.get_surface_count()):
			for p in (drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var q: Vector3 = to * p
				if first:
					box = AABB(q, Vector3.ZERO)
					first = false
				else:
					box = box.expand(q)
	return box


## WHERE A LEG MEETS THE GROUND: the mean of the part's LOWEST drawn points, which is the tyre's contact patch
## rather than the part's centroid.
func _contact_of(root: Node3D, part: String) -> Vector3:
	var points := _points_of(root, part)
	if points.is_empty():
		return Vector3.ZERO
	var low: float = points[0].y
	for p in points:
		low = minf(low, p.y)
	var sum := Vector3.ZERO
	var n: int = 0
	for p in points:
		if p.y < low + 0.06:
			sum += p
			n += 1
	return sum / float(maxi(n, 1))


## ONE PART'S BOX, IN THE CRAFT'S FRAME. Asking `_drawn_bounds(the part)` gives the part's OWN local box, which is the
## same thing only while the part hangs straight off the airframe. Once the moving parts went under hinges it stopped
## being the same thing, and the boxes of six surfaces were read in six different frames -- `nothing_floats` reported
## the two nozzles as a separate aeroplane. The points come from `_points_of`, which already puts every vertex through
## `frame.global_transform.affine_inverse() * drawn.global_transform`.
func _bounds_of(root: Node3D, part: String) -> AABB:
	var points := _points_of(root, part)
	if points.is_empty():
		return AABB()
	var box := AABB(points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(p)
	return box


func _points_of(root: Node3D, part: String) -> PackedVector3Array:
	var out: PackedVector3Array = []
	var node: Node = root.find_child(part, true, false)
	if node == null:
		return out
	for drawn in _meshes(node):
		var to: Transform3D = root.global_transform.affine_inverse() * drawn.global_transform
		for s in range(drawn.mesh.get_surface_count()):
			for p in (drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				out.append(to * p)
	return out


## THE LOWEST DRAWN POINT near `out`, AND THE STATION IT WAS ACTUALLY FOUND AT, as [height, out].
##
## Returning the station is the whole point. `lane/twin310` asked for a leading edge "at 0.90 and 4.90 m out"
## and divided the rise by a typed 4.00 m, while a band wide enough to hold a vertex found them 4.42 m apart --
## nine per cent, and a five-degree wing read 5.46 with nothing to say it had. A lofted part has vertices ONLY at
## its own ring stations, so the band must be wide enough to catch one and the answer must say where it landed.
func _lowest_near(root: Node3D, part: String, out: float, band: float) -> Variant:
	var best: Variant = null
	var at: float = absf(out)
	for p in _points_of(root, part):
		if absf(absf(p.x) - absf(out)) <= band and (best == null or p.y < float(best)):
			best = p.y
			at = absf(p.x)
	if best == null:
		return null
	return [float(best), at]


func _foremost_at(root: Node3D, part: String, out: float, band: float) -> Variant:
	var best: Variant = null
	for p in _points_of(root, part):
		if absf(p.x - out) <= band and (best == null or p.z < float(best)):
			best = p.z
	return best


func _aftmost_at(root: Node3D, part: String, out: float, band: float) -> Variant:
	var best: Variant = null
	for p in _points_of(root, part):
		if absf(p.x - out) <= band and (best == null or p.z > float(best)):
			best = p.z
	return best


## THE FITTED LINE'S VALUE at `out`, from a list of [out, station].
func _at(rows: Array, out: float) -> float:
	var n: float = float(rows.size())
	var sx: float = 0.0
	var sy: float = 0.0
	var sxy: float = 0.0
	var sxx: float = 0.0
	for r in rows:
		var x: float = float(r[0])
		var y: float = float(r[1])
		sx += x
		sy += y
		sxy += x * y
		sxx += x * x
	var m: float = (n * sxy - sx * sy) / maxf(n * sxx - sx * sx, 1e-9)
	return (sy - m * sx) / n + m * out


## A SWEEP in degrees from a list of [out, station], fitted over EVERY station and not through two ends.
func _slope(rows: Array) -> float:
	var n: float = float(rows.size())
	var sx: float = 0.0
	var sy: float = 0.0
	var sxy: float = 0.0
	var sxx: float = 0.0
	for r in rows:
		var x: float = float(r[0])
		var y: float = float(r[1])
		sx += x
		sy += y
		sxy += x * y
		sxx += x * x
	var m: float = (n * sxy - sx * sy) / maxf(n * sxx - sx * sx, 1e-9)
	return rad_to_deg(atan(m))


## THE PLANFORM, as the sum of the part's triangles projected on the plan, halved because the two skins project onto
## the same ground.
func _plan_area(root: Node3D, part: String) -> float:
	var points := _points_of(root, part)
	var area: float = 0.0
	for t in range(0, points.size() - 2, 3):
		var a := Vector2(points[t].x, points[t].z)
		var b := Vector2(points[t + 1].x, points[t + 1].z)
		var c := Vector2(points[t + 2].x, points[t + 2].z)
		area += absf((b - a).cross(c - a)) * 0.5
	return area * 0.5


func _finish() -> void:
	print("RESULT=%s %s" % ["PASS" if _failures.is_empty() else "FAIL", ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
