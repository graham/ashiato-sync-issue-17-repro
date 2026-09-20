extends Node
## Headless contract for the MH-6M Little Bird airframe: the published envelope, the features that make it a Little Bird,
## THE OPEN COCKPIT -- what each pilot can see -- two players packed in close and still fitting, the crew inside the
## drawn skin, one object, rotors that turn about their drawn hub, winding and the budget. Read RESULT=.
##
## KIND 26 SINCE 2026-09-18. The airframe is built alone for its geometry and once as the game builds it -- a VehicleView
## of the kind -- so the simulation's box and seats and the view's slot are held to the drawing too. How it FLIES is
## `tests/littlebird_flight.gd`.
##
## THE ENVELOPE AS CONSTANTS AT THE TOP, TYPED, so the reference is visible in one place and no check asks the builder's
## own constant what the builder did. PUBLISHED figures are [W]'s (Wikipedia, "MD Helicopters MH-6 Little Bird",
## Specifications); MEASURED ones are off [FOX], and `craft/littlebird/measure_drawing.py` prints each from the drawing.
const ROTOR_DIAMETER := 8.3515     # PUBLISHED, 27 ft 4.8 in -- the one figure the drawing was scaled by
const FUSELAGE_LENGTH := 7.498     # PUBLISHED, 24 ft 7.2 in "fuselage only"; NOT used to scale anything
const LENGTH_ROTORS := 9.936       # PUBLISHED, 32 ft 7.2 in "including rotors"; NOT used to scale anything
const WIDTH := 1.402               # PUBLISHED, 4 ft 7.2 in: the pod
const DRAWN_LENGTH := 7.443        # MEASURED, nose to the T-tail's endplate
const HUB_HEIGHT := 2.979          # MEASURED, skids to the hub's top; [W]'s 2.667 is printed beside it
const PUBLISHED_HEIGHT := 2.667
const SKID_TRACK := 1.874          # MEASURED, the front view's two skid middles
const T_TAIL_SPAN := 1.770         # MEASURED, the front view's endplates, outside to outside
const FEET_GLASS := 0.20           # the chin window reaches within this of the floor the pilots' feet are on
const EYES_APART := 0.70           # ESTIMATE: an MD 500's two front seats; the eyes may be no further apart than this

## Every part a reader would name when looking at a Little Bird. A missing one fails by name; a duplicate would have
## been renamed `@MeshInstance3D@N` by Godot and fails `_every_visible_mesh_is_a_named_part`.
const PARTS: Array = ["Fuselage", "WindscreenPost", "Cowling", "Mast", "TailBoom", "Fin", "Stabiliser",
	"SkidStarboard", "SkidPort", "BenchStarboard", "BenchPort", "Flir", "Cabin", "MainRotorHub", "MainRotorBlades",
	"TailRotorHub", "TailRotorBlades"]
## WHAT A PILOT CANNOT SEE THROUGH is every drawn part but the glass and the turning rotor: a blade going round at 400 rpm
## is a blur a pilot looks through, not a frame. The glass is the pod's SECOND SURFACE (`LittleBirdAirframe._pod_part`),
## found by its material being see-through rather than by a name.
const SEE_THROUGH: Array = ["MainRotorHub", "MainRotorBlades"]
## HOW FAR a sightline is followed. Beyond this it has left the aircraft.
const SIGHT: float = 12.0

## THE VIEW, as fractions of each cone that must be clear from each eye, sampled every five degrees. Azimuth is degrees
## OUTBOARD of dead ahead (negative looks across the cabin at the other pilot's side), elevation degrees above level.
## MEASURED on the first build that passed everything else (2026-09-17), per eye, and the floor set a little under it:
##   AHEAD   az -60..60,  el -10..15   0.84 of 150  the centre post (a diagonal of 12 samples, since it follows the nose's
##                                                  curve) and the windscreen's aft frame 30 degrees outboard; nothing else
##   BESIDE  az 60..120,  el -45..10   0.97 of 156  out of the open door; the pillar behind it at the aft edge
##   DOWN    az -30..90,  el -60..-15  0.74 of 250  through the chin window and the door; the floor and console between
##                                                  the knees, and the nose's side panel under the frame
## THE FIRST BUILD MET 0.73 AHEAD, and 7 of its 78 samples were on a centre post drawn 0.13 m across off the front view.
## A 10-degree grid then landed a whole column on the post; five degrees is the grid that shows a post as the diagonal
## line it is. Floors are what the real frames cost; a bow across the windscreen, a door left on or an eye moved behind
## the pillar costs far more (the mutants in `learnings/2026-09-17-littlebird.md`).
const CONES: Dictionary = {
	"ahead": [-60.0, 60.0, 5.0, -10.0, 15.0, 5.0, 0.80],
	"beside": [60.0, 120.0, 5.0, -45.0, 10.0, 5.0, 0.93],
	"down": [-30.0, 90.0, 5.0, -60.0, -15.0, 5.0, 0.70],
}
## THE DOWN CONE AGAIN, WITH THE STATIONS IN: see `_the_pilots_see_down_past_their_own_stations`, which prints the
## measurement this floor was set from: 0.71 from each seat on 2026-09-18, against 0.75 for the airframe alone.
const STATION_DOWN: float = 0.66
## THE CHIN WINDOW'S CONE from each eye: within this many degrees of dead ahead, from this far down to this far down.
const CHIN_CONE: Vector3 = Vector3(20.0, -45.0, -15.0)
## NAMED SIGHTLINES that must each be clear, from each eye: [name, azimuth, elevation].
const SIGHTLINES: Array = [["dead ahead", 0.0, 0.0], ["ahead through the chin", 0.0, -35.0],
	["forward quarter", 45.0, -10.0], ["abeam", 90.0, 0.0], ["abeam and down", 90.0, -40.0],
	["the ground outboard of the feet", 35.0, -50.0]]

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[littlebird] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var frame := LittleBirdAirframe.new()
	add_child(frame)
	frame.dress()
	_probe(frame)
	_the_simulation_seats_the_crew_where_the_airframe_draws_them(frame)
	_the_game_draws_this_airframe_for_the_kind()
	_the_pilots_see_down_past_their_own_stations()
	_every_visible_mesh_is_a_named_part(frame)
	_it_is_one_object_and_not_a_set_of_parts(frame)
	_the_drawn_helicopter_is_the_published_size(frame)
	_both_skids_stand_on_one_ground_at_the_drawn_track(frame)
	_it_has_the_features_that_make_it_a_little_bird(frame)
	_both_pilots_see_out_ahead_beside_and_down(frame)
	_the_doors_are_off_and_the_glass_reaches_the_pilots_feet(frame)
	_two_players_fit_packed_in_close_without_widening_the_cabin(frame)
	_the_crew_sit_inside_the_drawn_skin(frame)
	_the_rotor_turns_about_its_drawn_mast_by_the_angle_asked(frame)
	_every_face_is_wound_outwards(frame)
	_the_exterior_meets_the_first_lod_budget(frame)
	frame.queue_free()
	_finish()


## THE SIMULATION AND THE DRAWING AGREE: kind 28's box is the drawn helicopter's -- skids on its floor, nose and T-tail
## on its ends, the pod its width -- and its TWO seats stand the crew where the airframe draws them: each pilot's eye
## (the seat plus `CockpitStation.EYE_HEIGHT`) on `crew_eyes()`, both flying, the pilot to starboard. The bench riders
## were seats until 2026-09-18 and are not: their stations hung screens in the air (see `littlebird_shape` in C++).
## Asked of the drawn vertices and the native table, so a seat moved in C++ goes red here.
func _the_simulation_seats_the_crew_where_the_airframe_draws_them(frame: LittleBirdAirframe) -> void:
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.LITTLEBIRD)
	var half: Vector3 = geometry.get("extents", Vector3.ZERO)
	var poses: Array = geometry.get("seat_poses", [])
	var said: PackedStringArray = []
	var ok: bool = poses.size() == 2 and String(geometry.get("model_name", "")) == "helicopter"
	frame.set_rotors(false, 0.0, 0.0)
	var body: Array = []
	for mesh in _meshes(frame):
		if not String(mesh.name) in ["MainRotorHub", "MainRotorBlades", "TailRotorHub", "TailRotorBlades", "SkidPort",
				"SkidStarboard"]:
			body.append(mesh)
	var hull := _box_of(frame, body)
	var all := _box_of(frame, _meshes(frame))
	var pod := _box_of(frame, [_part(frame, "Fuselage")])
	var boxed: bool = absf(all.position.y + half.y) < 0.002 and absf(hull.position.z + half.z) < 0.02 \
		and absf(hull.end.z - half.z) < 0.02 and absf(pod.size.x - half.x * 2.0) < half.x * 0.03
	ok = ok and boxed
	said.append("box %.3f x %.3f x %.3f; drawn ground %.3f, nose %.3f, tail %.3f, pod %.3f wide" % [half.x * 2.0,
		half.y * 2.0, half.z * 2.0, all.position.y, hull.position.z, hull.end.z, pod.size.x])
	var eyes: Array[Vector3] = frame.crew_eyes()
	for seat in range(poses.size()):
		var pose: Dictionary = poses[seat]
		var eye: Vector3 = (pose.get("position", Vector3.ZERO) as Vector3) + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
		var station: String = String(pose.get("station", ""))
		if seat < 2:
			var off: float = eye.distance_to(eyes[seat])
			var right: bool = off < 0.01 and bool(pose.get("flies", false)) \
				and station == ("pilot" if seat == 0 else "copilot") and absf(float(pose.get("yaw", 1.0))) < 0.001
			ok = ok and right
			said.append("seat %d %s eye %.3f m from the drawn eye" % [seat, station, off])
			continue
		ok = false
		said.append("seat %d is one seat too many: the kind has its two pilots only" % seat)
	_check("the_simulation_seats_the_crew_where_the_airframe_draws_them", ok, "; ".join(said))


## THE GAME BUILDS THIS AIRFRAME: a craft view of kind 28 hides its box and draws `LittleBirdAirframe` in the helicopter
## slot, answers `cabin_room` from it, and `VehicleLights` takes the airframe's own lights -- every one of them within
## 5 cm of a drawn SURFACE of the airframe. Measured to the triangles, not their corners: the first version measured to
## vertices and put the nav lights 0.13 m off the endplates they are painted on, whose only vertices are their corners. A check that builds the airframe alone cannot see the view drawing a
## plank or a box instead (`lane/tomcat`: "a 19.5 m plank through the middle ... with every check green").
func _the_game_draws_this_airframe_for_the_kind() -> void:
	var view := (load("res://objects/vehicles/craft_littlebird.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var drawn: Array = view.find_children("*", "LittleBirdAirframe", true, false)
	var room: Dictionary = view.cabin_room()
	var lights: Dictionary = VehicleLights.published(Sim.Kind.LITTLEBIRD, Sim.geometry_of(Sim.Kind.LITTLEBIRD))
	var solids: Array = []
	var airframe: LittleBirdAirframe = drawn[0] if drawn.size() == 1 else null
	var far: PackedStringArray = []
	if airframe != null:
		for mesh in _meshes(airframe):
			if not String(mesh.name).begins_with("MainRotor"):
				solids.append(_points(airframe, mesh))
		for station in ["port", "starboard", "tail", "top", "bottom"]:
			var at: Vector3 = lights.get(station, Vector3(99, 99, 99))
			var nearest: float = INF
			for pts in solids:
				var faces: PackedVector3Array = pts
				for i in range(0, faces.size() - 2, 3):
					nearest = minf(nearest, at.distance_to(_on_triangle(at, faces[i], faces[i + 1], faces[i + 2])))
			if nearest > 0.05:
				far.append("%s %.2f m" % [station, nearest])
	var ok: bool = airframe != null and bool(room.get("drawn", false)) and far.is_empty() \
		and VehicleLights.carries_lights(Sim.Kind.LITTLEBIRD) and lights.get("port", Vector3.ZERO).x < 0.0
	_check("the_game_draws_this_airframe_for_the_kind", ok,
		"%d LittleBirdAirframe in the view, cabin_room drawn %s, lights off the airframe: %s" % [drawn.size(),
			room.get("drawn", false), "none" if far.is_empty() else ", ".join(far)])
	view.queue_free()


## A PROBE BEFORE A PICTURE: every visible mesh's drawn box in the craft's frame.
func _probe(frame: Node3D) -> void:
	for mesh in _meshes(frame):
		var box := _box_of(frame, [mesh])
		print("[littlebird] probe %-16s x %6.2f..%6.2f  y %6.2f..%6.2f  z %6.2f..%6.2f  %5d triangles" % [mesh.name,
			box.position.x, box.end.x, box.position.y, box.end.y, box.position.z, box.end.z, _points(frame, mesh).size() / 3])


func _every_visible_mesh_is_a_named_part(frame: Node3D) -> void:
	var anonymous: PackedStringArray = []
	var names: Dictionary = {}
	for mesh in _meshes(frame):
		if String(mesh.name).begins_with("@"):
			anonymous.append(String(mesh.name))
		names[String(mesh.name)] = true
	var missing: PackedStringArray = []
	for part in PARTS:
		if not names.has(part):
			missing.append(part)
	_check("every_visible_mesh_is_a_named_part", anonymous.is_empty() and missing.is_empty()
		and names.size() == PARTS.size(),
		"%d meshes, anonymous %s, missing %s" % [names.size(), anonymous, missing])


## ONE OBJECT: every drawn part reaches the pod (`tests/drawn_parts.gd`, the algorithm `joined_parts` uses).
func _it_is_one_object_and_not_a_set_of_parts(frame: Node3D) -> void:
	var stray: Array = DrawnParts.adrift(frame)
	var said: PackedStringArray = []
	for s in stray:
		said.append("%s %.2f m from %s" % [s["name"], s["gap"], s["nearest"]])
	_check("it_is_one_object_and_not_a_set_of_parts", stray.is_empty(),
		"%d parts, adrift: %s" % [DrawnParts.count(frame), ", ".join(said) if not said.is_empty() else "none"])


## THE SIZE, from transformed vertices, against the PUBLISHED figures -- the user asked for the small size to be right.
## The pod's width is the widest DRAWN skin, 1 per cent under the published figure because the widest ring stands in the
## front door's opening and is cut away. The rotor's diameter is measured from the MAST's drawn axis, not from the rotor head's node, so a rotor built off
## centre reads off centre. The fuselage length leaves out the rotors; the length with rotors has blade 0 dead ahead.
func _the_drawn_helicopter_is_the_published_size(frame: LittleBirdAirframe) -> void:
	frame.set_rotors(false, 0.0, 0.0)
	var axis: Vector3 = _box_of(frame, [_part(frame, "Mast")]).get_center()
	var reach: float = 0.0
	for p in _points(frame, _part(frame, "MainRotorBlades")):
		reach = maxf(reach, Vector2(p.x - axis.x, p.z - axis.z).length())
	var body: Array = []
	for mesh in _meshes(frame):
		# The skids' up-turned tips stand 3.5 cm ahead of the nose on the drawing too; a fuselage length is the body's.
		if not String(mesh.name) in ["MainRotorHub", "MainRotorBlades", "TailRotorHub", "TailRotorBlades", "SkidPort",
				"SkidStarboard"]:
			body.append(mesh)
	var hull := _box_of(frame, body)
	var all := _box_of(frame, _meshes(frame))
	var pod := _box_of(frame, [_part(frame, "Fuselage")])
	var hub_top: float = _box_of(frame, [_part(frame, "MainRotorHub")]).end.y - all.position.y
	_check("the_drawn_helicopter_is_the_published_size",
		absf(reach * 2.0 - ROTOR_DIAMETER) <= ROTOR_DIAMETER * 0.005
			and absf(hull.size.z - FUSELAGE_LENGTH) <= FUSELAGE_LENGTH * 0.012
			and absf(hull.size.z - DRAWN_LENGTH) <= DRAWN_LENGTH * 0.005
			and absf(all.size.z - LENGTH_ROTORS) <= LENGTH_ROTORS * 0.01
			and absf(pod.size.x - WIDTH) <= WIDTH * 0.015
			and absf(hub_top - HUB_HEIGHT) <= HUB_HEIGHT * 0.01,
		"rotor %.3f m across (published %.3f); fuselage %.3f m nose to tail (published %.3f, drawn %.3f); %.3f m with the rotors (published %.3f); pod %.3f m wide (published %.3f); hub's top %.3f m over the skids (drawn %.3f -- [W] says %.3f)"
			% [reach * 2.0, ROTOR_DIAMETER, hull.size.z, FUSELAGE_LENGTH, DRAWN_LENGTH, all.size.z, LENGTH_ROTORS,
				pod.size.x, WIDTH, hub_top, HUB_HEIGHT, PUBLISHED_HEIGHT])


## THE SKIDS: both bottoms on the lowest drawn point -- nothing else of the helicopter reaches the ground -- and their
## middles the drawn track apart.
func _both_skids_stand_on_one_ground_at_the_drawn_track(frame: Node3D) -> void:
	var all := _box_of(frame, _meshes(frame))
	var port := _tube(frame, _part(frame, "SkidPort"))
	var starboard := _tube(frame, _part(frame, "SkidStarboard"))
	var level: bool = absf(port.position.y - all.position.y) < 0.002 and absf(starboard.position.y - all.position.y) < 0.002
	var track: float = starboard.get_center().x - port.get_center().x
	var lowest_else: float = INF
	for mesh in _meshes(frame):
		if not String(mesh.name).begins_with("Skid"):
			lowest_else = minf(lowest_else, _box_of(frame, [mesh]).position.y)
	_check("both_skids_stand_on_one_ground_at_the_drawn_track",
		level and absf(track - SKID_TRACK) < SKID_TRACK * 0.02 and lowest_else > all.position.y + 0.25,
		"skid bottoms %.3f and %.3f against the lowest drawn point %.3f; track %.3f m (drawn %.3f); nothing else within %.2f m of the ground"
			% [port.position.y, starboard.position.y, all.position.y, track, SKID_TRACK, lowest_else - all.position.y])


## THE FEATURES, each asked of drawn vertices: SIX main blades (counted as separate arms round the mast, not as a
## number the builder stored), FOUR tail blades all on the PORT side, a T-TAIL -- the stabiliser above the boom on the
## fin's top with an endplate past each tip -- a BENCH outboard of the pod each side reaching past its skid, and the
## FLIR ball under the chin ahead of the pilots.
func _it_has_the_features_that_make_it_a_little_bird(frame: LittleBirdAirframe) -> void:
	frame.set_rotors(false, 0.0, 0.0)
	var axis: Vector3 = _box_of(frame, [_part(frame, "Mast")]).get_center()
	var main: int = _arms(_points(frame, _part(frame, "MainRotorBlades")), func(p: Vector3) -> Vector2:
		return Vector2(p.x - axis.x, p.z - axis.z), 1.0)
	var tail_mesh := _part(frame, "TailRotorBlades")
	var tail_box := _box_of(frame, [tail_mesh, _part(frame, "TailRotorHub")])
	var tail_centre: Vector3 = _box_of(frame, [_part(frame, "TailRotorHub")]).get_center()
	var tail: int = _arms(_points(frame, tail_mesh), func(p: Vector3) -> Vector2:
		return Vector2(p.y - tail_centre.y, p.z - tail_centre.z), 0.3)
	var stab := _box_of(frame, [_part(frame, "Stabiliser")])
	var fin := _box_of(frame, [_part(frame, "Fin")])
	var pod := _box_of(frame, [_part(frame, "Fuselage")])
	# THE T: the stabiliser and its endplates stand wholly above the tail rotor's disc, with the fin's top inside them.
	var t_tail: bool = stab.position.y > tail_box.end.y and stab.position.y < fin.end.y and fin.end.y < stab.end.y \
		and absf(stab.size.x - T_TAIL_SPAN) < T_TAIL_SPAN * 0.02
	var benches: bool = true
	var bench_said: PackedStringArray = []
	var skin: Array = _skin(frame)
	for side in ["Port", "Starboard"]:
		var bench_mesh := _part(frame, "Bench" + side)
		var bench := _box_of(frame, [bench_mesh])
		var skid := _tube(frame, _part(frame, "Skid" + side))
		var outer: float = maxf(absf(bench.position.x), absf(bench.end.x))
		var skid_out: float = absf(skid.get_center().x)
		# CARRIED BY THE POD, asked of drawn vertices: some of the bench is buried in the pod's skin. `DrawnParts.adrift`
		# joins by BOXES, and a plank with its brackets deleted still sits 4 cm over the aft leg's box and reads as joined
		# -- the mutant that proved it stayed green until this was asked.
		var buried: int = 0
		for p in _points(frame, bench_mesh):
			if _inside(skin, p + Vector3(0.0007, 0.0, 0.0007)):
				buried += 1
		benches = benches and outer > skid_out and outer > pod.end.x + 0.25 and bench.size.z > 1.2 and buried > 0
		bench_said.append("%s to %.2f m out (skid %.2f), %.2f m long, %d vertices buried in the pod"
			% [side, outer, skid_out, bench.size.z, buried])
	var flir := _box_of(frame, [_part(frame, "Flir")])
	var eye_z: float = frame.crew_eyes()[0].z
	var chin: bool = flir.end.z < eye_z and absf(flir.get_center().x) < 0.01 \
		and flir.get_center().y < _box_of(frame, [_part(frame, "Fuselage")]).position.y + 0.35
	_check("it_has_the_features_that_make_it_a_little_bird",
		main == 6 and tail == 4 and tail_box.end.x < -0.2 and t_tail and benches and chin,
		"%d main blades, %d tail blades, tail rotor from x %.2f to %.2f (port is negative); stabiliser from %.2f to %.2f m over the tail rotor's top, the fin's top %.2f into it, %.3f m across (drawn %.3f); benches %s; FLIR at y %.2f, %.2f m ahead of the eyes"
			% [main, tail, tail_box.position.x, tail_box.end.x, stab.position.y - tail_box.end.y,
				stab.end.y - tail_box.end.y, fin.end.y - stab.position.y, stab.size.x, T_TAIL_SPAN,
				", ".join(bench_said), flir.get_center().y, eye_z - flir.end.z])


## THE OPEN COCKPIT, WHICH IS THE POINT. From each eye, three cones of sightlines -- ahead through the windscreen, beside
## out of the open door, down through the chin and the door to the ground -- and six named ones. A sightline is clear
## when it meets nothing opaque within SIGHT metres; glass and the turning rotor are seen through. The fraction clear in
## each cone must meet CONES' floor, every named line must be clear, and what each eye does meet is printed by part so a
## reader can see WHICH frame is in the way. The eyes are the airframe's own; `_the_crew_sit_inside_the_drawn_skin`
## holds them inside the cabin, so an eye moved out into the air to see better goes red there.
func _both_pilots_see_out_ahead_beside_and_down(frame: LittleBirdAirframe) -> void:
	var solids: Array = _solids(frame, SEE_THROUGH, true)
	var ok: bool = true
	var said: PackedStringArray = []
	var eyes: Array[Vector3] = frame.crew_eyes()
	for seat in range(eyes.size()):
		var eye: Vector3 = eyes[seat]
		var outboard: float = signf(eye.x)
		var line: PackedStringArray = []
		for cone in CONES:
			var c: Array = CONES[cone]
			var clear: int = 0
			var total: int = 0
			var met: Dictionary = {}
			var where: PackedStringArray = []
			var az: float = c[0]
			while az <= float(c[1]) + 0.01:
				var el: float = c[3]
				while el <= float(c[4]) + 0.01:
					var hit: String = _first_opaque(solids, eye, _look(az, el, outboard))
					total += 1
					if hit.is_empty():
						clear += 1
					else:
						met[hit] = int(met.get(hit, 0)) + 1
						where.append("%+.0f/%+.0f" % [az, el])
					el += float(c[5])
				az += float(c[2])
			var share: float = float(clear) / float(total)
			ok = ok and share >= float(c[6])
			line.append("%s %.2f of %d (floor %.2f)%s" % [cone, share, total, c[6], "" if met.is_empty() else " met %s" % met])
			# WHERE, az/el, only when short: the reader then knows which frame to look for in the pictures.
			if share < float(c[6]):
				line.append("%s blocked at %s" % [cone, " ".join(where)])
		var blocked: PackedStringArray = []
		for s in SIGHTLINES:
			var hit: String = _first_opaque(solids, eye, _look(float(s[1]), float(s[2]), outboard))
			if not hit.is_empty():
				blocked.append("%s by %s" % [s[0], hit])
		ok = ok and blocked.is_empty()
		said.append("%s: %s; named lines blocked: %s" % ["pilot (starboard)" if seat == 0 else "copilot (port)",
			", ".join(line), "none" if blocked.is_empty() else ", ".join(blocked)])
	_check("both_pilots_see_out_ahead_beside_and_down", ok, " | ".join(said))


## THE PILOTS SEE DOWN PAST THEIR OWN STATIONS: the same DOWN cone and the chin sightline as
## `_both_pilots_see_out_ahead_beside_and_down`, fired from each seat's eye in a VehicleView of the kind with its stations
## built -- the crew board, the displays, the stick, the collective, the footwell -- because the airframe alone cannot see
## what a station puts in front of the glass. The light helicopter's seat scene stood a crew board and a display 0.21 m
## under each eye right across the chin window (2026-09-18, `littlebird_seat_shot`); `seat_littlebird.tscn` lays them
## on the console instead. STATION_DOWN is measured with them there, and every part met is printed by name.
func _the_pilots_see_down_past_their_own_stations() -> void:
	var view := (load("res://objects/vehicles/craft_littlebird.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var solids: Array = _solids(view, SEE_THROUGH, true)
	var c: Array = CONES["down"]
	var ok: bool = view.seats.size() == 2
	var said: PackedStringArray = []
	for seat in range(view.seats.size()):
		var marker: Node3D = view.seats[seat]
		var eye: Vector3 = view.global_transform.affine_inverse() * (marker.global_transform
			* Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0))
		var outboard: float = signf(eye.x)
		var clear: int = 0
		var total: int = 0
		var met: Dictionary = {}
		var az: float = c[0]
		while az <= float(c[1]) + 0.01:
			var el: float = c[3]
			while el <= float(c[4]) + 0.01:
				var hit: String = _first_opaque(solids, eye, _look(az, el, outboard))
				total += 1
				if hit.is_empty():
					clear += 1
				else:
					met[hit] = int(met.get(hit, 0)) + 1
				el += float(c[5])
			az += float(c[2])
		var chin: String = _first_opaque(solids, eye, _look(0.0, -35.0, outboard))
		# THE CHIN WINDOW ITSELF, where the light helicopter's seat scene stood its crew board and display: nothing a
		# station's furniture or controls draw may be the first thing met anywhere in it. The wide cone above cannot say this -- the display
		# moved back across the windscreen cost it 4 samples of 250 and it stayed green.
		var in_chin: PackedStringArray = []
		var caz: float = -CHIN_CONE.x
		while caz <= CHIN_CONE.x + 0.01:
			var cel: float = CHIN_CONE.y
			while cel <= CHIN_CONE.z + 0.01:
				var first: Array = _cast_solid(solids, eye, _look(caz, cel, outboard), SIGHT)
				if not (first[1] as Dictionary).is_empty() and bool((first[1] as Dictionary).get("station", false)):
					in_chin.append("%+.0f/%+.0f %s" % [caz, cel, (first[1] as Dictionary)["name"]])
				cel += 5.0
			caz += 5.0
		var share: float = float(clear) / float(total)
		ok = ok and share >= STATION_DOWN and chin.is_empty() and in_chin.is_empty()
		said.append("seat %d: down %.2f of %d (floor %.2f), ahead through the chin %s, station parts in the chin window %s, met %s"
			% [seat, share, total, STATION_DOWN, "clear" if chin.is_empty() else "BLOCKED by " + chin,
				"none" if in_chin.is_empty() else "at " + " ".join(in_chin), met])
	_check("the_pilots_see_down_past_their_own_stations", ok, " | ".join(said))
	view.queue_free()


## THE DOORS ARE OFF AND THE GLASS COMES DOWN TO THE FEET. No drawn skin -- glass or panel -- stands in either door's
## outline on either side, asked of the triangles' middles in the side view; and the chin window's lowest point is within
## FEET_GLASS of the floor the pilots' feet are on, so a pilot looks down past his own boots. It was BELOW the floor when
## the floor was at the sills; the floor came down 0.22 m to the seats' footwell (`LittleBirdAirframe.FLOOR_Y`) and the
## chin window, as drawn, stops 0.15 m over it. A door painted on as a panel, or a chin window cut short, fails.
func _the_doors_are_off_and_the_glass_reaches_the_pilots_feet(frame: LittleBirdAirframe) -> void:
	var doors: Array = []
	for outline in [LittleBirdAirframe.FRONT_DOOR, LittleBirdAirframe.REAR_DOOR]:
		var poly := PackedVector2Array()
		for p in outline:
			poly.append(Vector2(frame.station(float(p[0])), frame.height(float(p[1]))))
		doors.append(poly)
	var in_doors: Dictionary = {}
	for part in ["Fuselage"]:
		var pts := _points(frame, _part(frame, part))
		for i in range(0, pts.size() - 2, 3):
			var middle: Vector3 = (pts[i] + pts[i + 1] + pts[i + 2]) / 3.0
			var normal: Vector3 = (pts[i + 2] - pts[i]).cross(pts[i + 1] - pts[i]).normalized()
			if absf(normal.x) < 0.5:
				continue
			for d in range(doors.size()):
				# Pulled 2 cm in from the outline, so a face along the door's own edge is not counted as in it.
				if Geometry2D.is_point_in_polygon(Vector2(middle.z, middle.y), doors[d]) \
						and _inset(Vector2(middle.z, middle.y), doors[d]) > 0.02:
					var key: String = "%s in the %s door" % [part, "front" if d == 0 else "rear"]
					in_doors[key] = int(in_doors.get(key, 0)) + 1
	var glass := _glass_box(frame)
	var floor_y: float = float(frame.cabin_room()["floor"])
	_check("the_doors_are_off_and_the_glass_reaches_the_pilots_feet",
		in_doors.is_empty() and glass.position.y < floor_y + FEET_GLASS,
		"faces standing in a door: %s; the glass's lowest point %.3f m, %.2f m over the floor the feet are on (at most %.2f)"
			% ["none" if in_doors.is_empty() else str(in_doors), glass.position.y, glass.position.y - floor_y, FEET_GLASS])


## TWO PLAYERS, PACKED IN CLOSE, AND STILL FITTING. The envelope is `tests/seat_room.gd`'s own constants, read from that
## file rather than retyped -- one number, one place -- hung off each of the airframe's eyes, with the seat's anchor
## `CockpitStation.EYE_HEIGHT` under the eye as the game will put it. Every clearance is to any drawn triangle, glass
## included. And the cabin is NOT widened to make them fit: the pod, sliced at the eyes, is [W]'s published width, and the
## two eyes are no further apart than an MD 500's seats.
func _two_players_fit_packed_in_close_without_widening_the_cabin(frame: LittleBirdAirframe) -> void:
	var room: Dictionary = (load("res://tests/seat_room.gd") as Script).get_script_constant_map()
	var solids: Array = _solids(frame, ["MainRotorHub", "MainRotorBlades"])
	var eyes: Array[Vector3] = frame.crew_eyes()
	var short: PackedStringArray = []
	var said: PackedStringArray = []
	var shoulders: Array = []
	for seat in range(eyes.size()):
		var eye: Vector3 = eyes[seat]
		var out := Vector3(signf(eye.x), 0.0, 0.0)
		var shoulder: Vector3 = eye - Vector3(0.0, CockpitStation.NECK, 0.0)
		var knee: Vector3 = eye + Vector3(0.0, float(room["KNEE_HEIGHT"]) - CockpitStation.EYE_HEIGHT, 0.0)
		shoulders.append(shoulder)
		var line: PackedStringArray = []
		for ray in [["head up", eye, Vector3.UP, room["HEAD_UP"]], ["head out", eye, out, room["HEAD_SIDE"]],
				["head in", eye, -out, room["HEAD_SIDE"]], ["head fore", eye, Vector3.FORWARD, room["HEAD_FORE"]],
				["shoulder out", shoulder, out, room["SHOULDER"]], ["shoulder in", shoulder, -out, room["SHOULDER"]],
				["knees", knee, Vector3.FORWARD, room["KNEE_FORE"]]]:
			var gap: float = _clearance(solids, ray[1], ray[2], float(room["FAN"]), float(room["FAR"]))
			line.append("%s %s" % [ray[0], "open" if gap >= float(room["FAR"]) else "%.2f" % gap])
			if gap < float(ray[3]):
				short.append("seat %d %s %.2f of %.2f" % [seat, ray[0], gap, ray[3]])
		said.append("seat %d: %s" % [seat, ", ".join(line)])
	var apart: float = (shoulders[0] as Vector3).distance_to(shoulders[1])
	if apart < float(room["NEIGHBOUR"]):
		short.append("shoulders %.2f apart of %.2f" % [apart, room["NEIGHBOUR"]])
	var eye_z: float = eyes[0].z
	var widest: float = _widest_at(frame, _part(frame, "Fuselage"), eye_z + 0.0007) * 2.0
	_check("two_players_fit_packed_in_close_without_widening_the_cabin",
		short.is_empty() and apart <= EYES_APART + 0.001 and widest <= WIDTH * 1.005,
		"%s; shoulders %.2f m apart (at most %.2f, at least %.2f); the cabin sliced at the eyes is %.3f m across against the published %.3f; short: %s"
			% [" | ".join(said), apart, EYES_APART, room["NEIGHBOUR"], widest, WIDTH,
				"none" if short.is_empty() else ", ".join(short)])


## THE CREW ARE INSIDE THE HELICOPTER. `cabin_room()` promises a box; its corners and both eyes must be inside the drawn
## pod by ray parity, fired UP and DOWN only and both odd (`modelling_here.md` section 6). The doors are open, which is
## exactly why only vertical rays are asked: a horizontal one through a door would call the middle of the cabin outside.
func _the_crew_sit_inside_the_drawn_skin(frame: LittleBirdAirframe) -> void:
	var room: Dictionary = frame.cabin_room()
	var box: AABB = room["room"]
	var skin: Array = _skin(frame)
	var nudge := Vector3(0.0007, 0.0, 0.0007)
	var points: Array = []
	for eye in frame.crew_eyes():
		points.append(eye + nudge)
	for i in range(8):
		var corner: Vector3 = box.get_endpoint(i)
		points.append(corner + (box.get_center() - corner).normalized() * 0.001 + nudge)
	var outside: PackedStringArray = []
	for p in points:
		if not _inside(skin, p):
			outside.append("(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z])
	# THE FLOOR IS UNDER THE ROOM AND UNDER THE FEET: at or below the room's bottom, and within 2 cm of the footwell a
	# seat draws -- its anchor, EYE_HEIGHT under the eye, plus the floor's thickness, plus the lift the kind's catalogue
	# entry names. Read from there, so the drawn floor and the station's cannot part.
	var lift: float = float((VehicleCatalogue.of(Sim.Kind.LITTLEBIRD).get("footwell", {}) as Dictionary).get("raise", 0.0))
	var footwell: float = frame.crew_eyes()[0].y - CockpitStation.EYE_HEIGHT + CockpitStation.FLOOR + lift
	var floor_ok: bool = float(room["floor"]) <= box.position.y + 0.001 and absf(float(room["floor"]) - footwell) < 0.02
	_check("the_crew_sit_inside_the_drawn_skin", outside.is_empty() and floor_ok and box.size.x >= 0.9,
		"room %.2f wide x %.2f tall x %.2f long, eyes %.2f m over the floor, which is %.3f m off the seats' footwell; outside the skin: %s"
			% [box.size.x, box.size.y, box.size.z, frame.crew_eyes()[0].y - float(room["floor"]), float(room["floor"]) - footwell,
				"none" if outside.is_empty() else ", ".join(outside)])


## THE ROTOR TURNS ABOUT ITS DRAWN MAST, by the angle the shared clock asks, and stands still parked. Driven through
## `set_rotors(turning, collective, seconds)`, the one call `VehicleView` makes on every helicopter, and solved from the
## drawn blades' vertices about the MAST's drawn axis -- never by asking the rotor's node, which a rotor built about the
## wrong point would still report as right. The seconds are chosen so the kit's clock turns it 0.7 radians.
func _the_rotor_turns_about_its_drawn_mast_by_the_angle_asked(frame: LittleBirdAirframe) -> void:
	var blades := _part(frame, "MainRotorBlades")
	var axis: Vector3 = _box_of(frame, [_part(frame, "Mast")]).get_center()
	frame.set_rotors(false, 0.0, 0.0)
	var before := _points(frame, blades)
	var asked: float = 0.7
	frame.set_rotors(true, 0.0, asked / (TAU * RotorcraftKit.MAIN_TURNS))
	var after := _points(frame, blades)
	# PARKED, THE SAME CLOCK TURNS NOTHING: a rotor that turns with nobody aboard is a rotor wired to the wrong input.
	frame.set_rotors(false, 0.0, asked / (TAU * RotorcraftKit.MAIN_TURNS))
	var parked := _points(frame, blades)
	var still: float = 0.0
	for i in range(before.size()):
		still = maxf(still, before[i].distance_to(parked[i]))
	var worst_angle: float = 0.0
	var worst_radius: float = 0.0
	for i in range(0, before.size(), 7):
		var a := Vector2(before[i].x - axis.x, before[i].z - axis.z)
		var b := Vector2(after[i].x - axis.x, after[i].z - axis.z)
		if a.length() < 0.5:
			continue
		# Seen from above with -z ahead and +x to starboard, an anticlockwise turn by `asked` is a turn of the (x, z)
		# vector by -asked.
		worst_angle = maxf(worst_angle, absf(angle_difference(a.angle_to(b), -asked)))
		worst_radius = maxf(worst_radius, absf(a.length() - b.length()))
	frame.set_rotors(false, 0.0, 0.0)
	var back := _points(frame, blades)
	var home: float = 0.0
	for i in range(before.size()):
		home = maxf(home, before[i].distance_to(back[i]))
	_check("the_rotor_turns_about_its_drawn_mast_by_the_angle_asked",
		worst_angle < 0.002 and worst_radius < 0.002 and home < 0.0005 and still < 0.0005,
		"turned %.2f rad: worst angle error %.4f rad, worst change of radius about the mast %.4f m; parked it moved %.5f m; back at zero within %.5f m"
			% [asked, worst_angle, worst_radius, still, home])


func _every_face_is_wound_outwards(frame: Node3D) -> void:
	var wrong: int = 0
	var total: int = 0
	var worst: Dictionary = {}
	for drawn in _meshes(frame):
		var arrays: Array = drawn.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in range(0, points.size() - 2, 3):
			var face: Vector3 = (points[i + 2] - points[i]).cross(points[i + 1] - points[i])
			if face.length_squared() < 1e-14:
				continue
			total += 1
			if face.dot(normals[i]) <= 0.0:
				wrong += 1
				worst[String(drawn.name)] = int(worst.get(String(drawn.name), 0)) + 1
	_check("every_face_is_wound_outwards", wrong == 0 and total > 0,
		"%d of %d faces wound against their normal %s" % [wrong, total, worst])


## THE BUDGET for a first exterior LOD: at most 100,000 triangles, 12 materials, 20 draw calls, and at least one fitting
## that stops drawing at range. The scope, stated: the whole LittleBirdAirframe subtree.
func _the_exterior_meets_the_first_lod_budget(frame: Node3D) -> void:
	var triangles: int = 0
	var draws: int = 0
	var culled: int = 0
	var materials: Dictionary = {}
	for drawn in _meshes(frame):
		if drawn.visibility_range_end > 0.0:
			culled += 1
		for s in range(drawn.mesh.get_surface_count()):
			materials[drawn.material_override if drawn.material_override != null else drawn.mesh.surface_get_material(s)] = true
		for s in range(drawn.mesh.get_surface_count()):
			draws += 1
			triangles += (drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_check("the_exterior_meets_the_first_lod_budget", triangles <= 100000 and draws <= 20 and culled >= 1
		and materials.size() <= 12,
		"the whole LittleBirdAirframe subtree: %d triangles, %d draw surfaces, %d materials, %d distance-culled"
			% [triangles, draws, materials.size(), culled])


# ---------------------------------------------------------------------------------------------------------------------

func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.mesh != null and drawn.visible:
			out.append(drawn)
	return out


func _part(frame: Node, named: String) -> MeshInstance3D:
	return frame.find_child(named, true, false) as MeshInstance3D


## THE DRAWN VERTICES of a mesh in the craft's frame, never `transform * get_aabb()`.
func _points(frame: Node3D, mesh: MeshInstance3D) -> PackedVector3Array:
	var into := frame.global_transform.affine_inverse() * mesh.global_transform
	var out := PackedVector3Array()
	for s in range(mesh.mesh.get_surface_count()):
		for p in (mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			out.append(into * p)
	return out


func _box_of(frame: Node3D, meshes: Array) -> AABB:
	var box := AABB()
	var any := false
	for mesh in meshes:
		for p in _points(frame, mesh):
			box = box.expand(p) if any else AABB(p, Vector3.ZERO)
			any = true
	return box


## A skid's TUBE: its drawn vertices within 0.2 m of the ground, so the legs rising from it are left out.
func _tube(frame: Node3D, skid: MeshInstance3D) -> AABB:
	var pts := _points(frame, skid)
	var low: float = INF
	for p in pts:
		low = minf(low, p.y)
	var box := AABB()
	var any := false
	for p in pts:
		if p.y < low + 0.2:
			box = box.expand(p) if any else AABB(p, Vector3.ZERO)
			any = true
	return box


## HOW MANY SEPARATE ARMS a rotor's vertices make round its axis: the vertices beyond `beyond` metres out, sorted by
## angle, split wherever two neighbours are more than 20 degrees apart.
func _arms(pts: PackedVector3Array, flat: Callable, beyond: float) -> int:
	var angles: Array = []
	for p in pts:
		var v: Vector2 = flat.call(p)
		if v.length() > beyond:
			angles.append(v.angle())
	if angles.is_empty():
		return 0
	angles.sort()
	var arms: int = 0
	for i in range(angles.size()):
		var next: float = float(angles[(i + 1) % angles.size()])
		var gap: float = next - float(angles[i])
		if i == angles.size() - 1:
			gap += TAU
		if gap > deg_to_rad(20.0):
			arms += 1
	return arms


## HOW FAR OUT A MESH REACHES where the plane z = `z` cuts it: every triangle edge that crosses the plane, interpolated.
func _widest_at(frame: Node3D, mesh: MeshInstance3D, z: float) -> float:
	var pts := _points(frame, mesh)
	var widest: float = 0.0
	for i in range(0, pts.size() - 2, 3):
		for e in [[0, 1], [1, 2], [2, 0]]:
			var a: Vector3 = pts[i + e[0]]
			var b: Vector3 = pts[i + e[1]]
			if (a.z - z) * (b.z - z) < 0.0:
				widest = maxf(widest, absf(lerpf(a.x, b.x, (z - a.z) / (b.z - a.z))))
	return widest


## A direction from an eye: `az` degrees outboard of dead ahead (toward `outboard`'s side), `el` degrees above level.
static func _look(az: float, el: float, outboard: float) -> Vector3:
	var a: float = deg_to_rad(az)
	var e: float = deg_to_rad(el)
	return Vector3(outboard * sin(a) * cos(e), sin(e), -cos(a) * cos(e)).normalized()


## Every drawn triangle but those of the parts named in `skip`, grouped by part with a box to reject a ray early.
func _solids(frame: Node3D, skip: Array, glass_too: bool = false) -> Array:
	var out: Array = []
	for mesh in _meshes(frame):
		if String(mesh.name) in skip:
			continue
		var into := frame.global_transform.affine_inverse() * mesh.global_transform
		for s in range(mesh.mesh.get_surface_count()):
			if glass_too and _is_glass(mesh, s):
				continue
			var pts := PackedVector3Array()
			for p in (mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				pts.append(into * p)
			if pts.is_empty():
				continue
			var box := AABB(pts[0], Vector3.ZERO)
			for p in pts:
				box = box.expand(p)
			out.append({"name": _station_part(mesh), "faces": pts, "box": box.grow(0.01), "station": _in_a_station(mesh)})
	return out


## A DRAWN PART'S NAME: its own, or inside a station the name of the station's child it belongs to -- "MapScreen", "Crew"
## -- since a station's meshes are anonymous and "@MeshInstance3D@434" tells a reader nothing.
static func _station_part(mesh: Node) -> String:
	var walk: Node = mesh
	while walk.get_parent() != null:
		if walk.get_parent() is CockpitStation:
			return String(walk.name)
		walk = walk.get_parent()
	return String(mesh.name)


## WHETHER A DRAWN PART IS A STATION'S FURNITURE OR CONTROLS rather than the aircraft's. NOT the shell's floor and amber
## bar: every station draws those, the bar is the reach limit a player is meant to see, and at 40 degrees down it spans
## the whole chin cone from every eye -- a check that counted it could never pass and would say nothing about layout.
static func _in_a_station(node: Node) -> bool:
	var walk: Node = node.get_parent()
	while walk != null:
		if walk is CockpitShell:
			return false
		if walk is CockpitStation:
			return true
		walk = walk.get_parent()
	return false


## THE NEAREST SOLID ALONG A RAY: [distance, the solid's record], or [far, {}].
func _cast_solid(solids: Array, at: Vector3, along: Vector3, far: float) -> Array:
	var from := at + Vector3(0.0007, 0.00035, 0.0007)
	var to: Vector3 = from + along * far
	var best: float = far
	var what: Dictionary = {}
	for solid in solids:
		if (solid["box"] as AABB).intersects_segment(from, to) == null and not (solid["box"] as AABB).has_point(from):
			continue
		var faces: PackedVector3Array = solid["faces"]
		for i in range(0, faces.size() - 2, 3):
			var hit = Geometry3D.ray_intersects_triangle(from, along, faces[i], faces[i + 1], faces[i + 2])
			if hit != null and ((hit as Vector3) - from).length() < best:
				best = ((hit as Vector3) - from).length()
				what = solid
	return [best, what]


## WHETHER A SURFACE IS GLASS: its material, or the part's, draws see-through.
static func _is_glass(mesh: MeshInstance3D, surface: int) -> bool:
	var material := mesh.material_override if mesh.material_override != null else mesh.mesh.surface_get_material(surface)
	return material is BaseMaterial3D and (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED


## THE GLASS'S DRAWN BOX, over every see-through surface of every part.
func _glass_box(frame: Node3D) -> AABB:
	var box := AABB()
	var any := false
	for mesh in _meshes(frame):
		var into := frame.global_transform.affine_inverse() * mesh.global_transform
		for s in range(mesh.mesh.get_surface_count()):
			if not _is_glass(mesh, s):
				continue
			for p in (mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				box = box.expand(into * p) if any else AABB(into * p, Vector3.ZERO)
				any = true
	return box


## The part a sightline meets first within SIGHT metres, or "" when it meets nothing.
func _first_opaque(solids: Array, from: Vector3, along: Vector3) -> String:
	var hit: Array = _cast(solids, from, along, SIGHT)
	return String(hit[1])


## The least of five parallel rays, as `tests/seat_room.gd` measures a body part: the point and four offset by `fan`.
func _clearance(solids: Array, from: Vector3, along: Vector3, fan: float, far: float) -> float:
	var across: Vector3 = Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT
	var other: Vector3 = along.cross(across).normalized()
	var best: float = float(_cast(solids, from, along, far)[0])
	for offset in [across * fan, -across * fan, other * fan, -other * fan]:
		best = minf(best, float(_cast(solids, from + offset, along, far)[0]))
	return best


## THE NEAREST DRAWN TRIANGLE ALONG A RAY: [distance, part], or [far, ""]. Both faces count.
func _cast(solids: Array, at: Vector3, along: Vector3, far: float) -> Array:
	var from := at + Vector3(0.0007, 0.00035, 0.0007)
	var to: Vector3 = from + along * far
	var best: float = far
	var what: String = ""
	for solid in solids:
		if (solid["box"] as AABB).intersects_segment(from, to) == null and not (solid["box"] as AABB).has_point(from):
			continue
		var faces: PackedVector3Array = solid["faces"]
		for i in range(0, faces.size() - 2, 3):
			# Geometry3D's test is two-sided (it rejects only a zero determinant), so a lining and a skin both stop it.
			var hit = Geometry3D.ray_intersects_triangle(from, along, faces[i], faces[i + 1], faces[i + 2])
			if hit != null:
				var d: float = ((hit as Vector3) - from).length()
				if d < best:
					best = d
					what = String(solid["name"])
	return [best, what]


## The pod's outer skin, glass and panel, as triangles: what "inside the helicopter" is asked of.
func _skin(frame: Node3D) -> Array:
	var skin: Array = []
	for part in ["Fuselage"]:
		var pts := _points(frame, _part(frame, part))
		for i in range(0, pts.size() - 2, 3):
			skin.append([pts[i], pts[i + 1], pts[i + 2]])
	return skin


func _inside(skin: Array, p: Vector3) -> bool:
	var up: int = 0
	var down: int = 0
	for t in skin:
		if Geometry3D.ray_intersects_triangle(p, Vector3.UP, t[0], t[1], t[2]) != null \
				or Geometry3D.ray_intersects_triangle(p, Vector3.UP, t[0], t[2], t[1]) != null:
			up += 1
		if Geometry3D.ray_intersects_triangle(p, Vector3.DOWN, t[0], t[1], t[2]) != null \
				or Geometry3D.ray_intersects_triangle(p, Vector3.DOWN, t[0], t[2], t[1]) != null:
			down += 1
	return up % 2 == 1 and down % 2 == 1


## THE NEAREST POINT ON A TRIANGLE to `p`: its projection on the plane if that falls inside, else the nearest edge's.
static func _on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return a
	n = n.normalized()
	var q: Vector3 = p - n * n.dot(p - a)
	var inside: bool = (b - a).cross(q - a).dot(n) >= 0.0 and (c - b).cross(q - b).dot(n) >= 0.0 \
		and (a - c).cross(q - c).dot(n) >= 0.0
	if inside:
		return q
	var best: Vector3 = Geometry3D.get_closest_point_to_segment(p, a, b)
	for edge in [[b, c], [c, a]]:
		var e: Vector3 = Geometry3D.get_closest_point_to_segment(p, edge[0], edge[1])
		if p.distance_to(e) < p.distance_to(best):
			best = e
	return best


## How far a point is inside a polygon: its distance to the nearest edge.
static func _inset(p: Vector2, polygon: PackedVector2Array) -> float:
	var best: float = INF
	for i in range(polygon.size()):
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, polygon[i], polygon[(i + 1) % polygon.size()])
		best = minf(best, p.distance_to(q))
	return best


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
