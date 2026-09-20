extends Node
## Headless contract for the AV-8B Harrier II airframe: its measured envelope against the published one, the features
## that make it a Harrier II rather than a first-generation aeroplane, and the things that MOVE -- four nozzles
## through 98.5 degrees, a bicycle undercarriage with mid-span outriggers, and the control surfaces -- each read back
## from DRAWN VERTICES, never from a node's transform. Read RESULT=.
##
## THE ENVELOPE AS CONSTANTS AT THE TOP, TYPED, so the reference is visible in one place and no check asks the builder
## its own constant. Every PUBLISHED figure is [SAC] NAVAIR 00-110AV8-4 or [NATOPS] A1-AV8BB-NFM-000; every MEASURED
## one is re-derived from the scan alone by `craft/harrier/measure_sac.py`, which reads nothing out of the airframe.

const PUBLISHED_LENGTH := 14.122      # 46.33 ft [SAC] and [NATOPS]
const PUBLISHED_SPAN := 9.245         # 30.33 ft
const PUBLISHED_HEIGHT := 3.551       # 11.65 ft, top of fin, gear down
const PUBLISHED_TRACK := 5.182        # 17.0 ft "wing gear spread" -- the outriggers
const PUBLISHED_WHEELBASE := 3.481    # 11.42 ft
const PUBLISHED_TAILPLANE := 4.246    # 13.93 ft
const NOZZLE_TRAVEL_DEG := 98.5       # [SAC] "Nozzle rotation angles -- Front 0 to 98.5 -- Rear 0 to 98.5"
const HOVER_STOP_DEG := 82.0          # [NATOPS] p96
const RAKE_DEG := 6.5                 # [SAC] page 2's ground line
## WHERE THE TWO CENTRELINE TYRES ARE ALONG THE AEROPLANE, MEASURED off [SAC] page 2 by
## `craft/harrier/measure_sac.stance`, which fits both drawn tyres sub-pixel (0.89 and 0.98 px rms on 221 and 252
## points) and prints their centres' stations. A CC-licensed hover photograph, which has never seen that drawing,
## independently puts the same two wheels at 4.80 and 8.20 (`craft/harrier/measure_photos.gear_lobes`).
const DRAWN_NOSE_STATION := 4.681
const DRAWN_MAIN_STATION := 8.129
## HOW BIG A NOZZLE IS, MEASURED off a CC-licensed beam-on photograph at 3.2 mm a pixel by
## `craft/harrier/measure_photos.front_nozzle`: the lit drum of the front nozzle is 0.362 m across, 0.372 at its
## widest. It is a LOWER BOUND -- the drum's underside is in its own shadow -- so the tolerance below is generous
## upwards and tight downwards against the 0.800 m this model used to draw.
const DRAWN_NOZZLE_ACROSS := 0.362

## THE SHAPE, MEASURED off the scan by `craft/harrier/measure_front.py` and `propose_sections.py`, which read nothing
## out of the airframe. These are what the second pass at the fuselage is held to and none of them is a figure the
## model was free to choose.
const DRAWN_BODY_HALF := 1.231        # the widest the body ever gets -- the intake bells, off the FRONT view, and
                                      # flat across every ink threshold from 60 to 225
const DRAWN_DEPTH_AT_4_25 := 1.69     # side view, level frame: the last station before the gun pods hide the belly
const DRAWN_DEPTH_AT_9_00 := 1.48     # ...and the first station after them
const DRAWN_DEPTH_AT_9_75 := 1.398    # the rear fuselage, where the old table was 1.92
const PEGASUS_DIAMETER := 1.219       # [WP] Rolls-Royce Pegasus, "diameter 48 in (1.219 m)" -- PUBLISHED, and the
                                      # bell is built to the drawn circle, never to this
## THE FUSELAGE'S OWN HALF-WIDTH at the two stations where the plan view can see it and the wing cannot hide it --
## and where its OUTERMOST ink and its NEAREST-to-centreline ink agree, which is the sign that only one line is
## there and that line is the fuselage side. Forward of the cockpit and aft of the wing; the middle is unmeasurable.
const DRAWN_HALF_AT_1_25 := 0.46
const DRAWN_HALF_AT_8_35 := 0.63

## THE PARTS THAT MAKE IT THIS AEROPLANE, counted by name. A silhouette cue asserted as a count.
const PARTS: Array = ["Fuselage", "Canopy", "WingPort", "WingStarboard", "LerxPort", "LerxStarboard",
	"IntakePort", "IntakeStarboard", "BlowInDoorsPort", "BlowInDoorsStarboard",
	"Fin", "Rudder", "TailplanePort", "TailplaneStarboard",
	"FlapPort", "FlapStarboard", "AileronPort", "AileronStarboard",
	"NozzleFrontPort", "NozzleFrontStarboard", "NozzleRearPort", "NozzleRearStarboard",
	"NoseGear", "MainGear", "OutriggerPort", "OutriggerStarboard",
	"OutriggerPodPort", "OutriggerPodStarboard", "GunPodPort", "GunPodStarboard",
	"LidsFence", "ReactionJets"]
const NOZZLES: Array = ["NozzleFrontPort", "NozzleFrontStarboard", "NozzleRearPort", "NozzleRearStarboard"]

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[harrier] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var frame := HarrierAirframe.new()
	add_child(frame)
	frame.dress()
	_every_named_part_is_drawn(frame)
	_the_drawn_aeroplane_is_the_published_length_and_span(frame)
	_the_outriggers_are_mid_span_not_at_the_tips(frame)
	_it_parks_nose_up(frame)
	_the_four_nozzles_turn_together_through_the_published_travel(frame)
	_the_nozzles_are_the_size_the_photographs_say(frame)
	_every_plume_leaves_its_own_drawn_nozzle(frame)
	_the_wing_falls_outboard(frame)
	_the_surfaces_move_the_right_way_and_come_back(frame)
	_the_body_is_no_wider_than_the_drawing(frame)
	_the_fuselage_is_as_wide_as_the_plan_view_says(frame)
	_the_rear_fuselage_tapers(frame)
	_the_belly_does_not_swallow_its_own_gun_pods(frame)
	_the_intakes_stand_proud_of_the_body(frame)
	_the_intakes_could_feed_the_engine_they_are_drawn_for(frame)
	_every_face_is_wound_outwards(frame)
	_finish()


## ---- the checks ------------------------------------------------------------------------------------------------

func _every_named_part_is_drawn(frame: Node3D) -> void:
	var missing: PackedStringArray = []
	for named in PARTS:
		if frame.find_child(String(named), true, false) == null:
			missing.append(String(named))
	_check("every_named_part_is_drawn", missing.is_empty(),
		"%d of %d parts; missing %s" % [PARTS.size() - missing.size(), PARTS.size(),
			", ".join(missing) if not missing.is_empty() else "none"])


## THE DRAWN BOUNDS against the published envelope. The height is measured over the RAKED GROUND UNDER THE FIN, not
## over the lowest drawn point, because this aeroplane does not sit level and the published 11.65 ft is a vertical
## height from the ground to the fin tip.
func _the_drawn_aeroplane_is_the_published_length_and_span(frame: Node3D) -> void:
	var box: AABB = _drawn_bounds(frame)
	var length: float = box.size.z
	var span: float = box.size.x
	var fin: MeshInstance3D = frame.find_child("Fin", true, false) as MeshInstance3D
	var top: float = -INF
	var at_station: float = 0.0
	for p in _points(frame, fin):
		if p.y > top:
			top = p.y
			at_station = p.z + frame.call("point", 0.0, 0.0, 0.0).distance_to(Vector3.ZERO) * 0.0
	var station: float = top_station(frame, fin)
	var ground: float = -frame._half.y + frame.ground_at(station)
	var height: float = top - ground
	var ok: bool = absf(length / PUBLISHED_LENGTH - 1.0) < 0.02 \
		and absf(span / PUBLISHED_SPAN - 1.0) < 0.02 \
		and absf(height / PUBLISHED_HEIGHT - 1.0) < 0.04
	_check("the_drawn_aeroplane_is_the_published_length_and_span", ok,
		"length %.3f of %.3f, span %.3f of %.3f, fin tip %.3f over the ground under station %.2f against %.3f"
		% [length, PUBLISHED_LENGTH, span, PUBLISHED_SPAN, height, station, PUBLISHED_HEIGHT])


static func top_station(frame: Node3D, mesh: MeshInstance3D) -> float:
	var best := Vector3(0.0, -INF, 0.0)
	for p in _points(frame, mesh):
		if p.y > best.y:
			best = p
	return best.z + frame._half.z


## THE OUTRIGGERS ARE MID-SPAN. This is the check the whole undercarriage is about: the drawn tyres are held to the
## PUBLISHED 17.0 ft "wing gear spread", a figure from the flight manual and the SAC sheet and not one measured off
## this model -- and to being well INBOARD of the tip, because a first-generation Harrier carried them AT the tip and
## that is the single most likely way for somebody later to "correct" this aeroplane into being the wrong one.
func _the_outriggers_are_mid_span_not_at_the_tips(frame: Node3D) -> void:
	frame.set_gear(1.0)
	var out: Array = []
	for named in ["OutriggerPort", "OutriggerStarboard"]:
		var mesh: MeshInstance3D = frame.find_child(named, true, false) as MeshInstance3D
		var low := Vector3(0.0, INF, 0.0)
		for p in _points(frame, mesh):
			if p.y < low.y:
				low = p
		out.append(low.x)
	var track: float = absf(float(out[0]) - float(out[1]))
	var share: float = (track * 0.5) / (PUBLISHED_SPAN * 0.5)
	_check("the_outriggers_are_mid_span_not_at_the_tips",
		absf(track / PUBLISHED_TRACK - 1.0) < 0.03 and share < 0.75,
		"tyres %.3f m apart against the published %.3f, at %.1f per cent of semi-span (a first-generation Harrier is 100)"
		% [track, PUBLISHED_TRACK, share * 100.0])


## IT PARKS NOSE-UP. [SAC] draws the aeroplane level and rakes the ground; the check is that the two centreline tyres
## do NOT sit at the same height in the craft's frame, which is exactly what `modelling_here.md` section 5 says a
## Hawkeye-convention "restoration" would destroy.
func _it_parks_nose_up(frame: Node3D) -> void:
	frame.set_gear(1.0)
	var bottoms: Dictionary = {}
	for named in ["NoseGear", "MainGear"]:
		var mesh: MeshInstance3D = frame.find_child(named, true, false) as MeshInstance3D
		var low: float = INF
		var at: float = 0.0
		for p in _points(frame, mesh):
			if p.y < low:
				low = p.y
				at = p.z
		bottoms[named] = [low, at]
	var nose: Array = bottoms["NoseGear"]
	var main: Array = bottoms["MainGear"]
	var drop: float = float(main[0]) - float(nose[0])
	var along: float = float(main[1]) - float(nose[1])
	var rake: float = rad_to_deg(atan2(drop, along))
	var wheelbase: float = absf(along)
	_check("it_parks_nose_up", drop > 0.05 and absf(rake - RAKE_DEG) < 1.0
			and absf(wheelbase / PUBLISHED_WHEELBASE - 1.0) < 0.05,
		"the nose tyre hangs %.3f m below the main one over a %.3f m wheelbase (published %.3f): %.2f deg nose-up against the printed %.1f"
		% [drop, wheelbase, PUBLISHED_WHEELBASE, rake, RAKE_DEG])

	# AND WHERE ALONG THE AEROPLANE THEY ARE, which nothing here asked until 2026-09-20. Every check above is blind
	# to it: the rake is the angle BETWEEN the two tyres and the wheelbase is the distance between them, and both
	# are exactly the same whether the pair sits under the wing or a metre and a half in front of it. So the model
	# carried `NOSE_STATION 3.05  # ESTIMATE` through fifteen green suites with its main wheel ahead of the wing,
	# and the overlay found it rather than the suite. A quantity that no check mentions is not being checked by the
	# checks that surround it, however many of them there are.
	var half_length: float = PUBLISHED_LENGTH / 2.0
	var nose_station: float = float(nose[1]) + half_length
	var main_station: float = float(main[1]) + half_length
	_check("the_wheels_are_where_the_drawing_puts_them",
		absf(nose_station - DRAWN_NOSE_STATION) < 0.10 and absf(main_station - DRAWN_MAIN_STATION) < 0.10,
		"the drawn tyres sit at stations %.3f and %.3f against [SAC]'s measured %.3f and %.3f"
		% [nose_station, main_station, DRAWN_NOSE_STATION, DRAWN_MAIN_STATION])


## HOW BIG THE NOZZLES ARE, which nothing here asked until 2026-09-20 and which was wrong by more than a factor of
## two the whole time. The check above holds all four to the published 98.5 degrees of travel and the one below it
## holds every plume to its own drawn metal; between them they ask whether the nozzles MOVE and where they POINT,
## and a nozzle of any size whatever satisfies both. The user looked at the aeroplane and said the nozzles were not
## right, and they were 0.800 m across against a photographed 0.362.
##
## MEASURED ACROSS THE DUCT, not along it. The elbow bends outboard in the X-Z plane, so the drawn nozzle's extent
## in Y is its diameter and is not touched by the bend or by the lever position. This is read off the mesh's own
## vertices, so it fails if the geometry stops agreeing with the constant as much as if the constant is edited.
func _the_nozzles_are_the_size_the_photographs_say(frame: Node3D) -> void:
	frame.set_nozzle(0.0)
	var said: PackedStringArray = []
	var ok: bool = true
	for named in NOZZLES:
		var mesh: MeshInstance3D = frame.find_child(named, true, false) as MeshInstance3D
		var low: float = INF
		var high: float = -INF
		for p in _points(frame, mesh):
			low = minf(low, p.y)
			high = maxf(high, p.y)
		var across: float = high - low
		# The rear pair are an ESTIMATE kept in this file's own front-to-rear ratio, so they are allowed to be
		# smaller than the measured front pair but not larger and not wildly either way.
		ok = ok and across > DRAWN_NOZZLE_ACROSS - 0.08 and across < DRAWN_NOZZLE_ACROSS + 0.10
		said.append("%s %.3f m" % [named, across])
	_check("the_nozzles_are_the_size_the_photographs_say", ok,
		"%s, against the photographed %.3f m across" % [", ".join(said), DRAWN_NOZZLE_ACROSS])


## THE FOUR NOZZLES TURN TOGETHER, through the published travel. Together is not decoration: [PEG] says the real four
## are turned by motorcycle chains off one air motor, so they physically cannot point two ways, and a model whose
## front pair lags its rear is wrong about the aeroplane rather than merely untidy.
func _the_four_nozzles_turn_together_through_the_published_travel(frame: Node3D) -> void:
	var said: PackedStringArray = []
	var ok: bool = true
	for amount in [0.0, 0.5, 1.0]:
		frame.set_nozzle(amount)
		var angles: Array = []
		for named in NOZZLES:
			angles.append(_nozzle_angle_of(frame, named))
		var lowest: float = angles.min()
		var highest: float = angles.max()
		ok = ok and (highest - lowest) < 0.5
		if amount == 1.0:
			ok = ok and absf(highest - NOZZLE_TRAVEL_DEG) < 0.6
		said.append("lever %.1f: %.2f to %.2f deg down" % [amount, lowest, highest])
	frame.set_nozzle(0.0)
	_check("the_four_nozzles_turn_together_through_the_published_travel", ok,
		"%s; published stop %.1f, hover stop %.1f at lever %.3f"
		% [", ".join(said), NOZZLE_TRAVEL_DEG, HOVER_STOP_DEG, frame.stop_at(HOVER_STOP_DEG)])


## ONE NOZZLE'S DRAWN AXIS, degrees below straight aft, from its own transformed vertices: the far end along the
## drum's length against the near end. Read off the METAL, never off the hinge's transform.
static func _nozzle_angle_of(frame: Node3D, named: String) -> float:
	var mesh: MeshInstance3D = frame.find_child(named, true, false) as MeshInstance3D
	var hinge: Node3D = mesh.get_parent() as Node3D
	var root: Vector3 = frame.global_transform.affine_inverse() * hinge.global_position
	# THE EXIT RING, as the mean of the quarter of the drum's vertices furthest from its own hinge. Taking "the point
	# furthest from the CENTROID" instead is ambiguous on a symmetric drum -- it can pick either end, and the first
	# version of this read a 98.5-degree nozzle as 81.5 because it took the far end and then threw the sign away with
	# an absf() on the z component. A nozzle's root is a place this model knows; its centroid is not a landmark.
	var pts: PackedVector3Array = _points(frame, mesh)
	var far: float = 0.0
	for p in pts:
		far = maxf(far, p.distance_to(root))
	var exit := Vector3.ZERO
	var n: int = 0
	for p in pts:
		if p.distance_to(root) > far * 0.75:
			exit += p
			n += 1
	var axis: Vector3 = (exit / maxf(float(n), 1.0)) - root
	return rad_to_deg(atan2(-axis.y, axis.z))


## EVERY PLUME LEAVES ITS OWN DRAWN NOZZLE. `exhaust_ports()` is what `ExhaustYard` draws from, and this holds each
## port to the vertices of the nozzle it belongs to -- the check that caught the F-35B's port standing still while
## its nozzle swung, 1.26 m adrift with the lever down. Four ports, four nozzles, each to its own.
func _every_plume_leaves_its_own_drawn_nozzle(frame: Node3D) -> void:
	var said: PackedStringArray = []
	var ok: bool = true
	for amount in [0.0, 0.5, 1.0]:
		frame.set_nozzle(amount)
		var ports: Array = frame.exhaust_ports()
		ok = ok and ports.size() == 4
		var worst: float = 0.0
		for port in ports:
			var at: Vector3 = (port as Dictionary)["at"]
			var nearest: float = INF
			for named in NOZZLES:
				var mesh: MeshInstance3D = frame.find_child(named, true, false) as MeshInstance3D
				for p in _points(frame, mesh):
					nearest = minf(nearest, at.distance_to(p))
			worst = maxf(worst, nearest)
		ok = ok and worst < 0.20
		said.append("lever %.1f: worst port %.3f m from its own metal" % [amount, worst])
	frame.set_nozzle(0.0)
	_check("every_plume_leaves_its_own_drawn_nozzle", ok, ", ".join(said))


## THE WING FALLS OUTBOARD -- eleven degrees of ANHEDRAL, PUBLISHED as "Dihedral -11". It is the Harrier's most
## distinctive head-on feature, and a model drawn with the sign the other way is a different aeroplane.
func _the_wing_falls_outboard(frame: Node3D) -> void:
	var heights: Array = []
	for out in [0.8, 2.0, 3.2, 4.4]:
		heights.append(frame.wing_h(out))
	var falls: bool = true
	for i in range(heights.size() - 1):
		falls = falls and float(heights[i + 1]) < float(heights[i])
	var angle: float = rad_to_deg(atan2(float(heights[0]) - float(heights[-1]), 4.4 - 0.8))
	_check("the_wing_falls_outboard", falls and absf(angle - HarrierAirframe.ANHEDRAL) < 0.3,
		"chord plane %.3f m at 0.8 out down to %.3f at 4.4: %.2f deg of anhedral against the published %.1f"
		% [heights[0], heights[-1], angle, HarrierAirframe.ANHEDRAL])


## EVERY HINGED SURFACE MOVES, MOVES THE RIGHT WAY, AND COMES BACK. Read off drawn vertices: a surface whose hinge
## turns but whose mesh does not is exactly the fault a transform check cannot see.
func _the_surfaces_move_the_right_way_and_come_back(frame: Node3D) -> void:
	var said: PackedStringArray = []
	var ok: bool = true
	# THE AILERONS GO OPPOSITE WAYS. One up and one down is what rolling is; both the same way is a flap.
	var rest_s: Vector3 = _middle(frame, "AileronStarboard")
	var rest_p: Vector3 = _middle(frame, "AileronPort")
	frame.set_ailerons(1.0)
	var up_s: float = _middle(frame, "AileronStarboard").y - rest_s.y
	var up_p: float = _middle(frame, "AileronPort").y - rest_p.y
	ok = ok and up_s * up_p < 0.0 and absf(up_s) > 0.01
	said.append("ailerons %+.3f and %+.3f m" % [up_s, up_p])
	frame.set_ailerons(0.0)
	ok = ok and _middle(frame, "AileronStarboard").distance_to(rest_s) < 1e-4
	# THE FLAPS GO DOWN, both of them.
	var rest_f: Vector3 = _middle(frame, "FlapStarboard")
	frame.set_flaps(1.0)
	var down_f: float = _middle(frame, "FlapStarboard").y - rest_f.y
	ok = ok and down_f < -0.02
	said.append("flap %+.3f m" % down_f)
	frame.set_flaps(0.0)
	# THE RUDDER GOES SIDEWAYS.
	var rest_r: Vector3 = _middle(frame, "Rudder")
	frame.set_rudder(1.0)
	var swung: float = _middle(frame, "Rudder").x - rest_r.x
	ok = ok and absf(swung) > 0.01
	said.append("rudder %+.3f m" % swung)
	frame.set_rudder(0.0)
	ok = ok and _middle(frame, "Rudder").distance_to(rest_r) < 1e-4
	# THE TAILPLANE IS ALL-MOVING.
	var rest_t: Vector3 = _middle(frame, "TailplaneStarboard")
	frame.set_tailplane(1.0)
	var moved_t: float = _middle(frame, "TailplaneStarboard").y - rest_t.y
	ok = ok and absf(moved_t) > 0.01
	said.append("tailplane %+.3f m" % moved_t)
	frame.set_tailplane(0.0)
	ok = ok and _middle(frame, "TailplaneStarboard").distance_to(rest_t) < 1e-4
	_check("the_surfaces_move_the_right_way_and_come_back", ok, ", ".join(said))


## A FACE WOUND BACKWARDS IS INVISIBLE AND NOTHING ELSE WILL FIND IT (`tests/ship_models.gd:_wound_outwards`).
func _every_face_is_wound_outwards(frame: Node3D) -> void:
	var wrong: int = 0
	var total: int = 0
	for mesh in _meshes(frame):
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if normals.size() != verts.size():
			continue
		for t in range(0, verts.size() - 2, 3):
			total += 1
			var face: Vector3 = (verts[t + 2] - verts[t]).cross(verts[t + 1] - verts[t])
			if face.length_squared() < 1e-10:
				continue
			# THE CONVENTION IS `tests/ship_models.gd:_wound_outwards`'s, copied rather than reasoned about: a face
			# whose winding cross product points AWAY from its own normal is the wrong way round. The first version
			# here had the comparison inverted and reported 1,297 of 1,478 faces wrong on a model that was fine --
			# a check that disagrees with the project's other check about the same property is the one to doubt.
			if face.dot(normals[t]) <= 0.0:
				wrong += 1
	var worst: PackedStringArray = []
	for mesh in _meshes(frame):
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if normals.size() != verts.size():
			continue
		var here: int = 0
		for t in range(0, verts.size() - 2, 3):
			var face: Vector3 = (verts[t + 2] - verts[t]).cross(verts[t + 1] - verts[t])
			if face.length_squared() >= 1e-10 and face.dot(normals[t]) <= 0.0:
				here += 1
		if here > 0:
			worst.append("%s %d" % [mesh.name, here])
	# NAMED, not just counted: "75 of 1478" says a model is wrong and nothing about where, and a backwards face is
	# invisible, so the name is the only thread there is to pull.
	_check("every_face_is_wound_outwards", wrong == 0,
		"%d of %d faces wound against their normal%s" % [wrong, total,
			"" if worst.is_empty() else " -- " + ", ".join(worst)])


## ---- helpers ---------------------------------------------------------------------------------------------------

static func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			out.append(child as MeshInstance3D)
		out.append_array(_meshes(child))
	return out


## ---- the shape, which is what the second pass at this fuselage was for ------------------------------------------

## EVERY DRAWN POINT OF ONE OR MORE NAMED PARTS, in the craft's frame.
static func _part_points(frame: Node3D, names: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for named in names:
		out.append_array(_points(frame, frame.find_child(String(named), true, false) as MeshInstance3D))
	return out


## THE DRAWN DEPTH AT ONE STATION: the tallest and the shortest point of a part within half a ring spacing of it.
static func _depth_at(frame: Node3D, names: Array, station: float, window: float = 0.06) -> float:
	var z: float = (frame.call("point", 0.0, 0.0, station) as Vector3).z
	var low: float = INF
	var high: float = -INF
	for p in _part_points(frame, names):
		if absf(p.z - z) <= window:
			low = minf(low, p.y)
			high = maxf(high, p.y)
	return high - low if high > low else 0.0


## THE WIDEST DRAWN POINT OF A PART AT ONE STATION.
static func _widest_at(frame: Node3D, names: Array, station: float, window: float = 0.06) -> float:
	var z: float = (frame.call("point", 0.0, 0.0, station) as Vector3).z
	var out: float = 0.0
	for p in _part_points(frame, names):
		if absf(p.z - z) <= window:
			out = maxf(out, absf(p.x))
	return out


static func _widest(frame: Node3D, names: Array) -> float:
	var out: float = 0.0
	for p in _part_points(frame, names):
		out = maxf(out, absf(p.x))
	return out


## THE BODY IS NO WIDER THAN THE DRAWING SAYS. This is the check the whole second pass exists for: the first table
## made the fuselage 1.44 m of half-width amidships, and the FRONT view -- which nobody had measured -- says the
## widest the whole body ever gets is 1.231, and says it identically at every ink threshold from 60 to 225.
##
## It is held to the BODY AND THE BELLS TOGETHER, because that is what the front view measures: the outermost ink at
## the widest row is the bell's lip, and asking the fuselage alone would be asking a different question than the one
## the drawing answers.
##
## AND IT ASKS WHERE THE WIDEST POINT IS, not only how wide it is, because the first version of this check could not
## fail. Widening every fuselage ring by 30 per cent left the total untouched -- the BELLS were still the outermost
## thing, so the number this check reads never moved, and a mutant that restored the original bug passed it. A
## check on a maximum is blind to everything that is not the maximum. On a Harrier the widest point of the body is
## an intake, so that is asserted too, and now the fuselage cannot grow without this going red.
func _the_body_is_no_wider_than_the_drawing(frame: Node3D) -> void:
	var half: float = _widest(frame, ["Fuselage", "IntakePort", "IntakeStarboard"])
	var body: float = _widest(frame, ["Fuselage"])
	var bells: float = _widest(frame, ["IntakePort", "IntakeStarboard"])
	var off: float = half / DRAWN_BODY_HALF - 1.0
	_check("the_body_is_no_wider_than_the_drawing", absf(off) < 0.08 and bells > body,
		"widest drawn half-width %.3f m against the front view's measured %.3f, %+.1f per cent; the widest point is"
		% [half, DRAWN_BODY_HALF, 100.0 * off] + " %s (bells %.3f, fuselage %.3f)"
		% ["an intake" if bells > body else "THE FUSELAGE", bells, body])


## THE FUSELAGE ITSELF IS AS WIDE AS THE PLAN VIEW SAYS, at the two stations where the plan view can see it.
##
## THIS CHECK EXISTS BECAUSE THE ONE ABOVE COULD NOT DO ITS JOB. Widening every fuselage ring by 30 per cent --
## most of the way back to the chined wedge this lane was sent to remove -- left `the_body_is_no_wider_than_the
## _drawing` green, because the bells are wider than the fuselage and a check on a MAXIMUM cannot see anything that
## is not the maximum. The mutant found that, not the review.
##
## So the fuselage is asked about itself, at a station forward of the cockpit and one aft of the wing, against the
## plan view's own clean column. The stretch between them is genuinely unmeasurable and is not asserted.
func _the_fuselage_is_as_wide_as_the_plan_view_says(frame: Node3D) -> void:
	var fwd: float = _widest_at(frame, ["Fuselage"], 1.25)
	var aft: float = _widest_at(frame, ["Fuselage"], 8.35)
	var a: float = fwd / DRAWN_HALF_AT_1_25 - 1.0
	var b: float = aft / DRAWN_HALF_AT_8_35 - 1.0
	_check("the_fuselage_is_as_wide_as_the_plan_view_says", absf(a) < 0.15 and absf(b) < 0.15,
		"half-width %.3f m at station 1.25 against the drawn %.3f (%+.1f per cent) and %.3f at 8.35 against %.3f (%+.1f)"
		% [fwd, DRAWN_HALF_AT_1_25, 100.0 * a, aft, DRAWN_HALF_AT_8_35, 100.0 * b])


## THE REAR FUSELAGE TAPERS. A Harrier has no engine behind the wing -- all four nozzles are amidships -- so its rear
## fuselage is an empty boom and is genuinely slim, which is the single most Harrier-ish thing about the profile and
## the thing the first table missed. Held to the drawn depth at station 9.75, where the old table was 1.92 m.
func _the_rear_fuselage_tapers(frame: Node3D) -> void:
	var rear: float = _depth_at(frame, ["Fuselage"], 9.75)
	var mid: float = _depth_at(frame, ["Fuselage"], 6.00)
	var off: float = rear / DRAWN_DEPTH_AT_9_75 - 1.0
	_check("the_rear_fuselage_tapers", absf(off) < 0.10 and rear < mid,
		"depth %.3f m at station 9.75 against the drawing's %.3f (%+.1f per cent), and %.3f amidships"
		% [rear, DRAWN_DEPTH_AT_9_75, 100.0 * off, mid])


## THE BELLY DOES NOT SWALLOW ITS OWN GUN PODS, and this is the bug the lane that built this aeroplane reported
## against itself as "too deep amidships". Between stations 4.5 and 8.35 the lowest ink on [SAC]'s side view is THE
## GUN POD, not the fuselage, and the first table ran the belly down to it -- so the body grew to 2.14 m deep at
## station 6.00 and absorbed the parts hanging off it.
##
## TWO CLAIMS, because either alone can be satisfied by a wrong aeroplane. The depth amidships must lie between the
## two MEASURED depths that bracket the hidden stretch, and the pods must hang BELOW the keel rather than inside it.
func _the_belly_does_not_swallow_its_own_gun_pods(frame: Node3D) -> void:
	var mid: float = _depth_at(frame, ["Fuselage"], 6.00)
	var bracketed: bool = mid < DRAWN_DEPTH_AT_4_25 + 0.10 and mid > DRAWN_DEPTH_AT_9_00 - 0.10
	var keel: float = INF
	for p in _part_points(frame, ["Fuselage"]):
		var z: float = (frame.call("point", 0.0, 0.0, 6.00) as Vector3).z
		if absf(p.z - z) <= 0.06:
			keel = minf(keel, p.y)
	var pod: float = INF
	for p in _part_points(frame, ["GunPodPort", "GunPodStarboard"]):
		pod = minf(pod, p.y)
	_check("the_belly_does_not_swallow_its_own_gun_pods", bracketed and pod < keel,
		"depth %.3f m amidships, between the measured %.3f at station 4.25 and %.3f at 9.00; the pods hang %.3f m"
		% [mid, DRAWN_DEPTH_AT_4_25, DRAWN_DEPTH_AT_9_00, keel - pod] + " below the keel")


## THE INTAKES STAND PROUD OF THE BODY. This is why they now read from the front and did not before, and it is a
## structural claim rather than a measurement: the old body was 1.44 m of half-width and the old intakes reached
## 1.34, so THE INTAKES WERE INSIDE THEIR OWN FUSELAGE and no amount of detailing them could have helped. A model
## that passes every published figure can still hide its most recognisable feature inside itself.
func _the_intakes_stand_proud_of_the_body(frame: Node3D) -> void:
	var bells: float = _widest(frame, ["IntakePort", "IntakeStarboard"])
	var body: float = _widest(frame, ["Fuselage"])
	_check("the_intakes_stand_proud_of_the_body", bells > body + 0.30,
		"the bells reach %.3f m against the fuselage's own %.3f -- %.3f m proud" % [bells, body, bells - body])


## THE INTAKES COULD FEED THE ENGINE THEY ARE DRAWN FOR. Two ducts feed one Pegasus, whose PUBLISHED diameter is
## 1.219 m, so the drawn throats must between them offer at least the fan's own area or the aeroplane is drawn with
## inlets it could not breathe through.
##
## A ONE-SIDED CHECK ON A PUBLISHED FIGURE, and deliberately not a fit: the bell is built to the circle MEASURED off
## the front view (1.222 m across, which happens to agree with the Pegasus to 0.2 per cent and was not taken from
## it), and this only asks whether that drawn bell clears the floor. Nothing here is fitted to a bound this then
## checks against, which is this lane's own rule and has been paid for twice.
func _the_intakes_could_feed_the_engine_they_are_drawn_for(frame: Node3D) -> void:
	var throat: float = 0.0
	var z: float = (frame.call("point", 0.0, 0.0, HarrierAirframe.INTAKE_LIP + 0.20) as Vector3).z
	var centre: float = (frame.call("point", HarrierAirframe.INTAKE_OUT, 0.0, 0.0) as Vector3).x
	for p in _part_points(frame, ["IntakeStarboard"]):
		if absf(p.z - z) <= 0.04:
			throat = maxf(throat, absf(p.x - centre))
	var ducts: float = 2.0 * PI * throat * throat
	var fan: float = PI * PEGASUS_DIAMETER * PEGASUS_DIAMETER * 0.25
	_check("the_intakes_could_feed_the_engine_they_are_drawn_for", ducts > fan,
		"two drawn throats of %.3f m radius give %.3f m2 against the published fan's %.3f m2 (%.2fx)"
		% [throat, ducts, fan, ducts / fan])


## EVERY VERTEX OF A MESH IN THE CRAFT'S FRAME. Measured from TRANSFORMED VERTICES, never `transform * get_aabb()`,
## which grows a box every time it is turned (`modelling_here.md` section 6).
static func _points(frame: Node3D, mesh: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	if mesh == null or mesh.mesh == null:
		return out
	var into: Transform3D = frame.global_transform.affine_inverse() * mesh.global_transform
	for p in (mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		out.append(into * p)
	return out


static func _middle(frame: Node3D, named: String) -> Vector3:
	var mesh: MeshInstance3D = frame.find_child(named, true, false) as MeshInstance3D
	var pts: PackedVector3Array = _points(frame, mesh)
	var at := Vector3.ZERO
	for p in pts:
		at += p
	return at / maxf(float(pts.size()), 1.0)


static func _drawn_bounds(frame: Node3D) -> AABB:
	var box := AABB()
	var first: bool = true
	for mesh in _meshes(frame):
		for p in _points(frame, mesh):
			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)
	return box


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
