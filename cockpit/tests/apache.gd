extends Node
## Headless contract for the AH-64D Apache airframe: the published envelope, the features that make it an Apache, THE
## TANDEM -- the gunner in front and low, the pilot behind and high -- the WIDENED cockpit both players fit, what each eye
## can see (ahead, down over the nose, and out to the side), the crew inside the drawn skin, one object, the chin gun
## pointing where it is told, rotors that turn about their drawn hubs, winding and the budget. Read RESULT=.
##
## THE KIND SINCE STEP 2. The airframe is built alone for its geometry and once as the game builds it -- a VehicleView of
## the kind -- so the simulation's box and seats and the view's slot are held to the drawing too. How it FLIES is
## `tests/apache_flight.gd`.
##
## THE ENVELOPE AS CONSTANTS AT THE TOP, TYPED, so the reference is visible in one place and no check asks the builder's
## own constant what the builder did. PUBLISHED figures name their source ([W] Wikipedia's spec box, [FAS] fas.org's
## AH-64 page, [F] flugzeuginfo.net); `craft/apache/sources.md` has the URLs and every disagreement between them.
const ROTOR_DIAMETER := 14.63      # PUBLISHED [W] -- the one figure the drawing was scaled by
const LENGTH_ROTORS := 17.73       # PUBLISHED [W] [FAS] "length"; NOT used to scale anything
const FUSELAGE_LENGTH := 15.06     # PUBLISHED [W] 49 ft 5 in "fuselage length", NO DATUM GIVEN: held to 3 %, the drawing
                                   # reads 2.5 % short (measure_drawing.py); NOT used to scale anything
const HEIGHT_OVER_TAIL_ROTOR := 4.64  # PUBLISHED [FAS] AH-64A height, 15.24 ft; the front view's own top measures 4.64
const WING_SPAN := 5.227           # PUBLISHED [FAS] 17.15 ft
const TAIL_ROTOR := 2.79           # PUBLISHED [F] 9 ft 2 in
const CANOPY_DRAWN := 0.99         # MEASURED, [ARMY]'s front view, 18 px: the real canopy, before the widening
const CANOPY_WIDE := 1.30          # THE WIDENED COCKPIT, the user's "bigger than normal", held here from outside the class
const STEP_UP := 0.25              # the pilot's eye is at least this far over the gunner's: the stepped canopy

## Every part a reader would name when looking at an Apache. A missing one fails by name; a duplicate would have been
## renamed `@MeshInstance3D@N` by Godot and fails `_every_visible_mesh_is_a_named_part`.
const PARTS: Array = ["Fuselage", "CanopyFrame", "Fin", "Stabilator", "Tads", "MastAndRadar", "Nacelles", "StubWings",
	"Stores", "Gear", "GunTurret", "Gun", "Cabin", "MainRotorHub", "MainRotorBlades", "TailRotorHub", "TailRotorBlades"]
## WHAT AN EYE CANNOT SEE THROUGH is every drawn part but the glass and the turning main rotor.
const SEE_THROUGH: Array = ["MainRotorHub", "MainRotorBlades"]
const SIGHT: float = 14.0
## THE VIEW, as fractions of each cone that must be clear from each eye, sampled every five degrees; azimuth degrees off
## dead ahead to either side (the eyes are on the centreline, so both sides are sampled), elevation above level. Floors
## per seat [pilot, gunner], set a little under what the build that passed everything else measured (2026-09-18):
##   AHEAD          az -45..45, el -10..15    pilot 0.87 (the bow between the cockpits), gunner 0.99
##   OVER THE NOSE  az -25..25, el -35..-10   pilot 0.39, gunner 0.36 -- THE NOSE ITSELF: it runs 1.7 m ahead of the
##                                            gunner's eye with the PNVS ball on its top dead ahead and the TADS under it,
##                                            so dead ahead he sees 7 degrees down and 15 to 30 degrees off it 19 to 23.
##                                            The first build, eye at x 326, read 0.27; it is the one number here a real
##                                            Apache also pays, and the reason the gunner looks DOWN AND OUT (below)
##   BESIDE         az 60..110 each side, el -40..10   1.00 for both, 38 to 43 degrees down from 45 off the nose
## The per-azimuth "lowest clear" profile is printed on every run.
const CONES: Dictionary = {
	"ahead": [-45.0, 45.0, -10.0, 15.0, [0.84, 0.96]],
	"over the nose": [-25.0, 25.0, -35.0, -10.0, [0.35, 0.33]],
	"beside": [60.0, 110.0, -40.0, 10.0, [0.97, 0.97]],
}
## NAMED SIGHTLINES that must each be clear, [name, azimuth, elevation, seats (0 pilot, 1 gunner)].
const SIGHTLINES: Array = [["dead ahead", 0.0, 0.0, [0, 1]], ["past the nose", 20.0, -15.0, [1]],
	["forward quarter and down", 30.0, -20.0, [0, 1]], ["abeam", 90.0, 0.0, [0, 1]],
	["abeam and down past the wing", 90.0, -35.0, [0, 1]], ["out and down", 60.0, -35.0, [0, 1]]]

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[apache] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var frame := ApacheAirframe.new()
	add_child(frame)
	frame.dress()
	_probe(frame)
	_the_simulation_seats_the_crew_where_the_airframe_draws_them(frame)
	_the_game_draws_this_airframe_for_the_kind()
	_neither_crewman_s_devices_stand_in_his_view_over_the_nose()
	_the_gunner_keeps_his_flying_controls_and_gets_the_helmet_sight()
	_the_view_draws_the_chin_gun_at_the_simulations_angle()
	_the_helmet_ring_sits_on_the_cross_only_when_the_gun_is_on()
	_the_hellfires_leave_from_the_rails_the_airframe_draws(frame)
	_both_crewmen_lock_by_the_helmet_and_launch_where_their_hands_are()
	_every_visible_mesh_is_a_named_part(frame)
	_it_is_one_object_and_not_a_set_of_parts(frame)
	_the_drawn_helicopter_is_the_published_size(frame)
	_all_three_wheels_stand_on_one_ground(frame)
	_it_has_the_features_that_make_it_an_apache(frame)
	_the_gunner_sits_in_front_and_low_and_the_pilot_behind_and_high(frame)
	_the_cockpit_is_widened_inside_the_cheek_bays(frame)
	_both_players_fit(frame)
	_the_crew_sit_inside_the_drawn_skin(frame)
	_each_eye_sees_ahead_over_the_nose_and_beside(frame)
	_the_chin_gun_points_where_it_is_told_within_its_limits(frame)
	_the_rotors_turn_about_their_drawn_hubs(frame)
	_every_face_is_wound_outwards(frame)
	_the_exterior_meets_the_first_lod_budget(frame)
	frame.queue_free()
	_finish()


## THE SIMULATION AND THE DRAWING AGREE: the kind's box is the drawn body's -- the main wheels on its floor, the TADS and
## the stabilator on its ends, the cheek bays its width -- and its TWO seats stand the crew where the airframe draws them:
## seat 0 the PILOT (rear, higher) and seat 1 the COPILOT (the gunner, front, lower), each eye (the seat plus
## `CockpitStation.EYE_HEIGHT`) on `crew_eyes()`, BOTH flying. Asked of the drawn vertices and the native table, so a seat
## moved in C++ goes red here.
func _the_simulation_seats_the_crew_where_the_airframe_draws_them(frame: ApacheAirframe) -> void:
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.APACHE)
	var half: Vector3 = geometry.get("extents", Vector3.ZERO)
	var poses: Array = geometry.get("seat_poses", [])
	var said: PackedStringArray = []
	var ok: bool = poses.size() == 2 and String(geometry.get("model_name", "")) == "helicopter"
	frame.set_rotors(false, 0.0, 0.0)
	var body: Array = []
	for mesh in _meshes(frame):
		if not String(mesh.name).begins_with("MainRotor") and not String(mesh.name).begins_with("TailRotor"):
			body.append(mesh)
	var hull := _box_of(frame, body)
	var fuselage := _box_of(frame, [_part(frame, "Fuselage")])
	var boxed: bool = absf(hull.position.y + half.y) < 0.002 and absf(hull.position.z + half.z) < 0.02 and absf(hull.end.z - half.z) < 0.02 and absf(fuselage.size.x - half.x * 2.0) < half.x * 0.03
	ok = ok and boxed
	said.append("box %.3f x %.3f x %.3f; drawn ground %.3f, nose %.3f, tail %.3f, fuselage %.3f wide" % [half.x * 2.0,
		half.y * 2.0, half.z * 2.0, hull.position.y, hull.position.z, hull.end.z, fuselage.size.x])
	var eyes: Array[Vector3] = frame.crew_eyes()
	for seat in range(poses.size()):
		var pose: Dictionary = poses[seat]
		var eye: Vector3 = (pose.get("position", Vector3.ZERO) as Vector3) + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
		var station: String = String(pose.get("station", ""))
		if seat >= 2:
			ok = false
			said.append("seat %d is one seat too many: the Apache has its pilot and its gunner" % seat)
			continue
		var off: float = eye.distance_to(eyes[seat])
		var right: bool = off < 0.01 and bool(pose.get("flies", false)) and station == ("pilot" if seat == 0 else "copilot") and absf(float(pose.get("yaw", 1.0))) < 0.001
		ok = ok and right
		said.append("seat %d %s%s eye %.3f m from the drawn eye" % [seat, station,
			" (flies)" if bool(pose.get("flies", false)) else " (DOES NOT FLY)", off])
	_check("the_simulation_seats_the_crew_where_the_airframe_draws_them", ok, "; ".join(said))


## THE GAME BUILDS THIS AIRFRAME: a craft view of the kind hides its box and draws `ApacheAirframe` in the helicopter slot,
## answers `cabin_room` from it, and `VehicleLights` takes the airframe's own lights -- every one within 5 cm of a drawn
## SURFACE (`lane/littlebird`: measure to the triangles, not their corners).
func _the_game_draws_this_airframe_for_the_kind() -> void:
	var view := (load("res://objects/vehicles/craft_apache.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var drawn: Array = view.find_children("*", "ApacheAirframe", true, false)
	var room: Dictionary = view.cabin_room()
	var lights: Dictionary = VehicleLights.published(Sim.Kind.APACHE, Sim.geometry_of(Sim.Kind.APACHE))
	var airframe: ApacheAirframe = drawn[0] if drawn.size() == 1 else null
	var far: PackedStringArray = []
	if airframe != null:
		var solids: Array = []
		for mesh in _meshes(airframe):
			if not String(mesh.name).begins_with("MainRotor") and not String(mesh.name).begins_with("TailRotor"):
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
	var ok: bool = airframe != null and bool(room.get("drawn", false)) and far.is_empty() and VehicleLights.carries_lights(Sim.Kind.APACHE) and lights.get("port", Vector3.ZERO).x < 0.0
	_check("the_game_draws_this_airframe_for_the_kind", ok,
		"%d ApacheAirframe in the view, cabin_room drawn %s, lights off the airframe: %s" % [drawn.size(),
			room.get("drawn", false), "none" if far.is_empty() else ", ".join(far)])
	view.queue_free()


## NEITHER CREWMAN'S DEVICES STAND IN HIS VIEW OVER THE NOSE: from each seat's eye in a VehicleView of the kind, with its
## stations built -- the display, the crew board, the map, the stick, the collective -- no station part is the FIRST thing
## met anywhere in the over-the-nose cone (CONES) that is HIS OWN, which is `lane/littlebird`'s chin rule for the view the gunner sits in
## front for. The light helicopter's seat scene stood the display and the crew board 0.21 m under the eye, right across it
## (`cockpit-station-apache-seat1`, 2026-09-18). The shell's amber bar is every station's and meant to be seen, so it is
## not counted (`_in_a_station`).
func _neither_crewman_s_devices_stand_in_his_view_over_the_nose() -> void:
	var view := (load("res://objects/vehicles/craft_apache.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var solids: Array = _solids(view, SEE_THROUGH, true)
	var c: Array = CONES["over the nose"]
	var ok: bool = view.seats.size() == 2
	var said: PackedStringArray = []
	for seat in range(view.seats.size()):
		var marker: Node3D = view.seats[seat]
		var eye: Vector3 = view.global_transform.affine_inverse() * (marker.global_transform
			* Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0))
		# HIS OWN STATION'S: from the pilot's seat the view over the nose runs across the gunner's cockpit, whose stick and
		# display are the gunner's and are seen there as the real one's are.
		var own: int = 0
		for found in marker.find_children("*", "CockpitStation", true, false):
			own = found.get_instance_id()
		var in_view: PackedStringArray = []
		var az: float = c[0]
		while az <= float(c[1]) + 0.01:
			var el: float = c[2]
			while el <= float(c[3]) + 0.01:
				var first: Array = _cast_solid(solids, eye, _look(az, el, 1.0), SIGHT)
				if not (first[1] as Dictionary).is_empty() and bool((first[1] as Dictionary).get("station", false)) and int((first[1] as Dictionary).get("owner", 0)) == own:
					in_view.append("%+.0f/%+.0f %s" % [az, el, (first[1] as Dictionary)["name"]])
				el += 5.0
			az += 5.0
		ok = ok and in_view.is_empty() and own != 0
		said.append("%s: station parts first met over the nose %s" % ["pilot" if seat == 0 else "gunner",
			"none" if in_view.is_empty() else "at " + " ".join(in_view)])
	_check("neither_crewman_s_devices_stand_in_his_view_over_the_nose", ok, " | ".join(said))
	view.queue_free()


## THE GUNNER'S SEAT FLIES AND SHOOTS: its station keeps the collective and the flying stick -- a turret seat's fitting
## would have taken the lever away for a trigger (`CockpitStation._fit_the_trigger`) -- and gains the helmet sight, with
## no rangekeeper or gun sight; the pilot's station has none of them.
func _the_gunner_keeps_his_flying_controls_and_gets_the_helmet_sight() -> void:
	var view := (load("res://objects/vehicles/craft_apache.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var gunner: CockpitStation = view.station_for(1)
	var pilot: CockpitStation = view.station_for(0)
	var ok: bool = gunner != null and pilot != null
	var said: String = "no stations"
	if ok:
		var lever: bool = gunner.get_node_or_null("Throttle") is CollectiveLever
		var stick: bool = gunner.get_node_or_null("Stick") is FlightStick
		var helmet: bool = gunner.get_node_or_null("HelmetSight") is HelmetSight
		var other: bool = gunner.get_node_or_null("RangeSight") == null and gunner.get_node_or_null("Sight") == null
		var pilot_clear: bool = pilot.get_node_or_null("HelmetSight") == null
		ok = lever and stick and helmet and other and pilot_clear and gunner.slaves_a_gun()
		said = "gunner: collective %s, flying stick %s, helmet sight %s, no turret sight %s; pilot has no helmet sight %s" % [lever, stick, helmet, other, pilot_clear]
	_check("the_gunner_keeps_his_flying_controls_and_gets_the_helmet_sight", ok, said)
	view.queue_free()


## THE HELLFIRES LEAVE FROM THE MISSILES ON THE WING: the simulation's eight rails (`loadout_of`) are the middles of the
## eight Hellfires `ApacheAirframe` draws, in order, to half a centimetre. A rail moved in C++ goes red here.
func _the_hellfires_leave_from_the_rails_the_airframe_draws(frame: ApacheAirframe) -> void:
	var rails: Array = Sim.missile_schema(Sim.Kind.APACHE).get("pylons", []) as Array
	var drawn: Array[Vector3] = frame.hellfire_rails()
	var worst: float = INF if rails.size() != drawn.size() else 0.0
	for i in range(mini(rails.size(), drawn.size())):
		worst = maxf(worst, (rails[i] as Vector3).distance_to(drawn[i]))
	_check("the_hellfires_leave_from_the_rails_the_airframe_draws", worst < 0.005,
		"%d rails, %d drawn, worst %.4f m apart" % [rails.size(), drawn.size(), worst])


## BOTH CREWMEN LOCK BY THE HELMET, AND LAUNCH WHERE THEIR HANDS ARE: each seat has a lock sight that rides the eye (the
## schema's `helmet`) and a master arm; the PILOT launches on his trigger, which fires nothing else, and the GUNNER's
## trigger stays the chin gun's, so his launch is on the stick's lower thumb (`FlightStick.missile_bindings`).
func _both_crewmen_lock_by_the_helmet_and_launch_where_their_hands_are() -> void:
	var view := (load("res://objects/vehicles/craft_apache.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var said: PackedStringArray = []
	var ok: bool = true
	for seat in [0, 1]:
		var station: CockpitStation = view.station_for(seat)
		var lock: LockSight = station.get_node_or_null("LockSight") as LockSight if station != null else null
		var stick: FlightStick = station.get_node_or_null("Stick") as FlightStick if station != null else null
		var armed: bool = station != null and station.get_node_or_null("MasterArm") != null
		var on_trigger: bool = stick != null and stick.launches and stick.launch_on_trigger
		var wanted: bool = seat == 0
		ok = ok and lock != null and lock.helmet and lock.top_level and armed and stick != null and stick.launches \
			and on_trigger == wanted
		said.append("seat %d: helmet lock %s, master arm %s, launches on the trigger %s" % [seat,
			lock != null and lock.helmet, armed, on_trigger])
	_check("both_crewmen_lock_by_the_helmet_and_launch_where_their_hands_are", ok, "; ".join(said))
	view.queue_free()


## THE BARREL EVERYBODY SEES IS THE SIMULATION'S: handed the mount's angles as `draw_turrets_at` is every frame, the
## view turns `ApacheAirframe`'s chin gun to them -- and draws no generic turret beside it.
func _the_view_draws_the_chin_gun_at_the_simulations_angle() -> void:
	var view := (load("res://objects/vehicles/craft_apache.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var airframe: ApacheAirframe = view.find_children("*", "ApacheAirframe", true, false)[0] as ApacheAirframe
	var asked := Vector2(0.62, -0.27)
	view.draw_turrets_at([asked])
	var drawn: Vector2 = airframe.gun_angles()
	_check("the_view_draws_the_chin_gun_at_the_simulations_angle",
		drawn.distance_to(asked) < 0.0001 and view._turrets.is_empty(),
		"asked %s, drawn %s; generic turrets %d" % [asked, drawn, view._turrets.size()])
	view.queue_free()


## THE RING IS WHERE THE ROUND GOES AND THE CROSS WHERE HE LOOKS: with the barrel laid on the point `helmet_range` down
## his look -- the simulation's own command -- the ring is on the cross and the sight says GUN ON; with the barrel a
## tenth of a radian short, the ring stands that far across the glass and it does not. A sight drawn along the LOOK
## instead of the barrel would say ON in both.
func _the_helmet_ring_sits_on_the_cross_only_when_the_gun_is_on() -> void:
	var sight := HelmetSight.new()
	sight.gun = Sim.gun_of(Sim.Kind.APACHE, 0)
	add_child(sight)
	var poses: Array = Sim.geometry_of(Sim.Kind.APACHE).get("seat_poses", [])
	var craft := Transform3D(Basis(Vector3.UP, 0.4), Vector3(10.0, 50.0, -20.0))
	var seat_at: Vector3 = (poses[1] as Dictionary)["position"]
	var eye: Vector3 = craft * (seat_at + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0))
	var look := craft.basis * Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, -0.2)
	var point: Vector3 = eye - look.z * float(sight.gun.get("helmet_range", 800.0))
	var local: Vector3 = craft.affine_inverse() * point - (sight.gun.get("at", Vector3.ZERO) as Vector3)
	var laid := Vector2(atan2(-local.x, -local.z), atan2(local.y, Vector2(local.x, local.z).length()))
	sight.follow(eye, look, craft, laid)
	var caught: bool = sight.on
	var caught_at: Vector3 = sight.ring_at
	sight.follow(eye, look, craft, laid - Vector2(0.1, 0.0))
	var short: bool = sight.on
	var short_at: Vector3 = sight.ring_at
	_check("the_helmet_ring_sits_on_the_cross_only_when_the_gun_is_on",
		caught and not short and Vector2(caught_at.x, caught_at.y).length() < 0.003
			and absf(Vector2(short_at.x, short_at.y).length() - 0.1) < 0.02,
		"barrel on the look: ring at %s, ON %s; barrel 0.1 rad short: ring at %s, ON %s" % [caught_at, caught, short_at,
			short])
	sight.queue_free()


## A DRAWN PART'S NAME: its own, or inside a station the name of the station's child it belongs to ("Display", "Crew").
static func _station_part(mesh: Node) -> String:
	var walk: Node = mesh
	while walk.get_parent() != null:
		if walk.get_parent() is CockpitStation:
			return String(walk.name)
		walk = walk.get_parent()
	return String(mesh.name)


## THE STATION A DRAWN PART BELONGS TO, by instance id, or 0.
static func _station_of(node: Node) -> int:
	var walk: Node = node.get_parent()
	while walk != null:
		if walk is CockpitStation:
			return walk.get_instance_id()
		walk = walk.get_parent()
	return 0


## WHETHER A DRAWN PART IS A STATION'S FURNITURE OR CONTROLS, and not the shell's floor and amber bar.
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


## THE NEAREST POINT ON A TRIANGLE to `p`: its projection on the plane if that falls inside, else the nearest edge's.
static func _on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return a
	n = n.normalized()
	var q: Vector3 = p - n * n.dot(p - a)
	var inside: bool = (b - a).cross(q - a).dot(n) >= 0.0 and (c - b).cross(q - b).dot(n) >= 0.0 and (a - c).cross(q - c).dot(n) >= 0.0
	if inside:
		return q
	var best: Vector3 = Geometry3D.get_closest_point_to_segment(p, a, b)
	for edge in [[b, c], [c, a]]:
		var e: Vector3 = Geometry3D.get_closest_point_to_segment(p, edge[0], edge[1])
		if p.distance_to(e) < p.distance_to(best):
			best = e
	return best


## A PROBE BEFORE A PICTURE: every visible mesh's drawn box in the craft's frame.
func _probe(frame: Node3D) -> void:
	for mesh in _meshes(frame):
		var box := _box_of(frame, [mesh])
		print("[apache] probe %-16s x %6.2f..%6.2f  y %6.2f..%6.2f  z %6.2f..%6.2f  %5d triangles" % [mesh.name,
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


## ONE OBJECT: every drawn part reaches the fuselage (`tests/drawn_parts.gd`, the algorithm `joined_parts` uses) -- with
## the gun slewed hard over and down, so a barrel that only touches its turret at rest is caught.
func _it_is_one_object_and_not_a_set_of_parts(frame: ApacheAirframe) -> void:
	var said: PackedStringArray = []
	var ok: bool = true
	for pose in [Vector2.ZERO, Vector2(1.7, -1.0)]:
		frame.set_gun(pose.x, pose.y)
		var stray: Array = DrawnParts.adrift(frame)
		for s in stray:
			said.append("gun at %s: %s %.2f m from %s" % [pose, s["name"], s["gap"], s["nearest"]])
		ok = ok and stray.is_empty()
	frame.set_gun(0.0, 0.0)
	_check("it_is_one_object_and_not_a_set_of_parts", ok,
		"%d parts, adrift: %s" % [DrawnParts.count(frame), ", ".join(said) if not said.is_empty() else "none"])


## THE SIZE, from transformed vertices, each figure measured from WHAT IT IS OF (`lane/rotors`): the main rotor by its
## blades' reach from the MAST's drawn axis; the fuselage without its rotors; the length with the rotors parked blade 0
## dead ahead, which is how the published length is taken; the height from the ground to the tail rotor's top; the span
## from the stub wings alone; the tail rotor by its blades' reach from its own hub.
func _the_drawn_helicopter_is_the_published_size(frame: ApacheAirframe) -> void:
	frame.set_rotors(false, 0.0, 0.0)
	var axis: Vector3 = _box_of(frame, [_part(frame, "MastAndRadar")]).get_center()
	var reach: float = 0.0
	for p in _points(frame, _part(frame, "MainRotorBlades")):
		reach = maxf(reach, Vector2(p.x - axis.x, p.z - axis.z).length())
	var body: Array = []
	for mesh in _meshes(frame):
		if not String(mesh.name).begins_with("MainRotor") and not String(mesh.name).begins_with("TailRotor"):
			body.append(mesh)
	var hull := _box_of(frame, body)
	var all := _box_of(frame, _meshes(frame))
	var tail := _box_of(frame, [_part(frame, "TailRotorBlades")])
	var tail_hub: Vector3 = _box_of(frame, [_part(frame, "TailRotorHub")]).get_center()
	var tail_reach: float = 0.0
	for p in _points(frame, _part(frame, "TailRotorBlades")):
		tail_reach = maxf(tail_reach, Vector2(p.y - tail_hub.y, p.z - tail_hub.z).length())
	var wings := _box_of(frame, [_part(frame, "StubWings")])
	# TO THE TOP OF THE TAIL ROTOR'S DISC, which is what an overall height is taken to: a parked scissor has no blade
	# straight up, so its blades' box stops 1.15 m over the hub, not 1.40.
	var tall: float = tail_hub.y + tail_reach - all.position.y
	_check("the_drawn_helicopter_is_the_published_size",
		absf(reach * 2.0 - ROTOR_DIAMETER) <= ROTOR_DIAMETER * 0.005
			and absf(hull.size.z - FUSELAGE_LENGTH) <= FUSELAGE_LENGTH * 0.03
			and absf(all.size.z - LENGTH_ROTORS) <= LENGTH_ROTORS * 0.02
			and absf(tall - HEIGHT_OVER_TAIL_ROTOR) <= HEIGHT_OVER_TAIL_ROTOR * 0.015
			and absf(wings.size.x - WING_SPAN) <= WING_SPAN * 0.005
			and absf(tail_reach * 2.0 - TAIL_ROTOR) <= TAIL_ROTOR * 0.01,
		"main rotor %.3f m across (published %.2f); fuselage %.3f m nose to stabilator (published %.2f); %.3f m with the rotors (published %.2f); %.3f m to the tail rotor's top (published %.2f); stub wings %.3f m (published %.3f); tail rotor %.3f m (published %.2f)"
			% [reach * 2.0, ROTOR_DIAMETER, hull.size.z, FUSELAGE_LENGTH, all.size.z, LENGTH_ROTORS, tall,
				HEIGHT_OVER_TAIL_ROTOR, wings.size.x, WING_SPAN, tail_reach * 2.0, TAIL_ROTOR])


## THE GEAR: both main wheels and the tailwheel have their bottoms on the lowest drawn point, and nothing else of the
## helicopter reaches within 0.3 m of the ground -- the stores and the chin gun at rest stand clear.
func _all_three_wheels_stand_on_one_ground(frame: ApacheAirframe) -> void:
	var all := _box_of(frame, _meshes(frame))
	var pts := _points(frame, _part(frame, "Gear"))
	var low_port: float = INF
	var low_starboard: float = INF
	var low_tail: float = INF
	var tail_z: float = frame.station(ApacheAirframe.TAIL_WHEEL_X)
	for p in pts:
		if absf(p.z - tail_z) < 0.5:
			low_tail = minf(low_tail, p.y)
		elif p.x < -0.5:
			low_port = minf(low_port, p.y)
		elif p.x > 0.5:
			low_starboard = minf(low_starboard, p.y)
	var lowest_else: float = INF
	for mesh in _meshes(frame):
		if String(mesh.name) != "Gear":
			lowest_else = minf(lowest_else, _box_of(frame, [mesh]).position.y)
	var ground: float = all.position.y
	_check("all_three_wheels_stand_on_one_ground",
		absf(low_port - ground) < 0.002 and absf(low_starboard - ground) < 0.002 and absf(low_tail - ground) < 0.002
			and lowest_else > ground + 0.30,
		"wheel bottoms port %.3f, starboard %.3f, tail %.3f against the lowest drawn point %.3f; nothing else within %.2f m of the ground"
			% [low_port, low_starboard, low_tail, ground, lowest_else - ground])


## THE FEATURES, each asked of drawn vertices: FOUR main blades (separate arms round the mast), FOUR tail blades on the PORT
## side as a SCISSOR -- two pairs 55 degrees apart, so the arms' neighbouring gaps are 55 and 125 degrees -- the Longbow
## dome over the hub, the TADS the foremost thing on the aircraft, the gun turret under the chin ahead of the gunner and
## under the belly, the nacelles over the stub wings each side, and the stores hung under the wings.
func _it_has_the_features_that_make_it_an_apache(frame: ApacheAirframe) -> void:
	frame.set_rotors(false, 0.0, 0.0)
	var axis: Vector3 = _box_of(frame, [_part(frame, "MastAndRadar")]).get_center()
	var main_angles: Array = _arm_angles(_points(frame, _part(frame, "MainRotorBlades")), func(p: Vector3) -> Vector2:
		return Vector2(p.x - axis.x, p.z - axis.z), 2.0)
	var tail_centre: Vector3 = _box_of(frame, [_part(frame, "TailRotorHub")]).get_center()
	var tail_angles: Array = _arm_angles(_points(frame, _part(frame, "TailRotorBlades")), func(p: Vector3) -> Vector2:
		return Vector2(p.y - tail_centre.y, p.z - tail_centre.z), 0.6)
	var gaps: Array = []
	for i in range(tail_angles.size()):
		var gap: float = float(tail_angles[(i + 1) % tail_angles.size()]) - float(tail_angles[i])
		if gap <= 0.0:
			gap += TAU
		gaps.append(rad_to_deg(gap))
	gaps.sort()
	var scissor: bool = gaps.size() == 4 and absf(float(gaps[0]) - 55.0) < 3.0 and absf(float(gaps[1]) - 55.0) < 3.0 \
		and absf(float(gaps[2]) - 125.0) < 3.0 and absf(float(gaps[3]) - 125.0) < 3.0
	var tail_box := _box_of(frame, [_part(frame, "TailRotorBlades")])
	var hub := _box_of(frame, [_part(frame, "MainRotorHub")])
	var radar := _box_of(frame, [_part(frame, "MastAndRadar")])
	var dome_on_top: bool = radar.end.y > hub.end.y + 0.6 and radar.size.x > 1.0
	var body: Array = []
	for mesh in _meshes(frame):
		if not String(mesh.name).begins_with("MainRotor"):
			body.append(mesh)
	var tads := _box_of(frame, [_part(frame, "Tads")])
	var foremost: bool = absf(tads.position.z - _box_of(frame, body).position.z) < 0.001
	# UNDER THE FRONT COCKPIT: the turret's middle between the canopy's front and the pilot's eye, on the centreline, and
	# its housing hung under the fuselage's lowest drawn point at that station (bedded 6 cm into it).
	var turret := _box_of(frame, [_part(frame, "GunTurret")])
	var turret_z: float = turret.get_center().z
	var fuselage_low: float = INF
	for p in _points(frame, _part(frame, "Fuselage")):
		if absf(p.z - turret_z) < 0.4:
			fuselage_low = minf(fuselage_low, p.y)
	var glass := _glass_box(frame)
	var gunner_eye: Vector3 = frame.crew_eyes()[1]
	var chin: bool = turret_z > glass.position.z and turret_z < frame.crew_eyes()[0].z \
		and turret.end.y < fuselage_low + 0.07 and turret.position.y < fuselage_low and absf(turret.get_center().x) < 0.01
	var nacelles := _box_of(frame, [_part(frame, "Nacelles")])
	var wings := _box_of(frame, [_part(frame, "StubWings")])
	var stores := _box_of(frame, [_part(frame, "Stores")])
	var engines: bool = nacelles.position.y > wings.end.y and nacelles.size.x > 2.0
	# UNDER THE WING, asked of the wing's own skin past the outboard pylon, where no pylon hangs from it.
	var wing_under: float = INF
	for p in _points(frame, _part(frame, "StubWings")):
		if absf(p.x) > wings.end.x - 0.15:
			wing_under = minf(wing_under, p.y)
	var hung: bool = stores.end.y < wing_under and stores.size.x > 3.5
	_check("it_has_the_features_that_make_it_an_apache",
		main_angles.size() == 4 and scissor and tail_box.end.x < -0.1 and dome_on_top and foremost and chin and engines
			and hung,
		"%d main blades; tail blades' gaps %s degrees, the rotor from x %.2f to %.2f (port is negative); the dome's top %.2f m over the hub's, %.2f m across; TADS foremost %s; gun turret's top at y %.2f under the belly's %.2f, its middle %.2f m aft of the gunner's eye; nacelles from %.2f m over the wings' top, %.2f m across; stores' top %.2f m under the wing, %.2f m across"
			% [main_angles.size(), gaps, tail_box.position.x, tail_box.end.x, radar.end.y - hub.end.y, radar.size.x,
				foremost, turret.end.y, fuselage_low, turret_z - gunner_eye.z,
				nacelles.position.y - wings.end.y, nacelles.size.x, wing_under - stores.end.y, stores.size.x])


## THE TANDEM, the thing the user named first: seat 0, the PILOT, behind and higher; seat 1, the GUNNER, in front and
## lower; both on the centreline. Asked of `crew_eyes()` and held against the drawn canopy: each eye is under glass.
func _the_gunner_sits_in_front_and_low_and_the_pilot_behind_and_high(frame: ApacheAirframe) -> void:
	var eyes: Array[Vector3] = frame.crew_eyes()
	var pilot: Vector3 = eyes[0]
	var gunner: Vector3 = eyes[1]
	var glass := _glass_box(frame)
	var under: bool = true
	for eye in eyes:
		under = under and eye.z > glass.position.z and eye.z < glass.end.z and eye.y < glass.end.y
	# AND NO GLASS AHEAD OF THE CANOPY'S FRONT BOW: the nose is painted. The first build glazed the nose's roof, and the
	# gunner looked through it at the back of the TADS drum inside the nose -- which no view count could see, because the
	# drum stood behind that glass in every sightline anyway (team-lead, from picture 05).
	var bow_front: float = _box_of(frame, [_part(frame, "CanopyFrame")]).position.z
	var nose_clear: bool = glass.position.z >= bow_front - 0.05
	_check("the_gunner_sits_in_front_and_low_and_the_pilot_behind_and_high",
		gunner.z < pilot.z - 1.0 and pilot.y - gunner.y >= STEP_UP and absf(pilot.x) < 0.001 and absf(gunner.x) < 0.001
			and under and nose_clear,
		"gunner's eye %.2f m ahead of the pilot's and %.2f m under it (at least %.2f); both on the centreline; both under the glass %s; the glass begins %.2f m aft of the front bow's front (no glass in the nose)"
			% [pilot.z - gunner.z, pilot.y - gunner.y, STEP_UP, under, glass.position.z - bow_front])


## THE COCKPIT IS WIDENED, AND ONLY THE COCKPIT. Sliced at each eye, the glass is the widened width, not the drawing's
## 0.99 m; and it stands inside the cheek bays under it, so the plan silhouette is the drawing's. A widening undone, or
## one that pushed the canopy past the cheeks, fails here.
func _the_cockpit_is_widened_inside_the_cheek_bays(frame: ApacheAirframe) -> void:
	var said: PackedStringArray = []
	var ok: bool = true
	var fuselage := _part(frame, "Fuselage")
	for eye in frame.crew_eyes():
		var glass: float = _widest_at(frame, fuselage, eye.z + 0.0007, true, -INF, INF) * 2.0
		var cheek: float = _widest_at(frame, fuselage, eye.z + 0.0007, false, -INF, INF) * 2.0
		ok = ok and absf(glass - CANOPY_WIDE) < 0.02 and cheek > glass + 0.3
		said.append("at z %.2f the glass is %.3f m across (widened %.2f, drawn %.2f), the cheek bays %.3f" % [eye.z, glass,
			CANOPY_WIDE, CANOPY_DRAWN, cheek])
	_check("the_cockpit_is_widened_inside_the_cheek_bays", ok, "; ".join(said))


## BOTH PLAYERS FIT. The envelope is `tests/seat_room.gd`'s own constants, read from that file, hung off each eye with the
## anchor `CockpitStation.EYE_HEIGHT` under it. Every clearance is to any drawn triangle, glass included.
func _both_players_fit(frame: ApacheAirframe) -> void:
	var room: Dictionary = (load("res://tests/seat_room.gd") as Script).get_script_constant_map()
	var solids: Array = _solids(frame, SEE_THROUGH)
	var short: PackedStringArray = []
	var said: PackedStringArray = []
	var eyes: Array[Vector3] = frame.crew_eyes()
	for seat in range(eyes.size()):
		var eye: Vector3 = eyes[seat]
		var shoulder: Vector3 = eye - Vector3(0.0, CockpitStation.NECK, 0.0)
		var knee: Vector3 = eye + Vector3(0.0, float(room["KNEE_HEIGHT"]) - CockpitStation.EYE_HEIGHT, 0.0)
		var line: PackedStringArray = []
		for ray in [["head up", eye, Vector3.UP, room["HEAD_UP"]], ["head right", eye, Vector3.RIGHT, room["HEAD_SIDE"]],
				["head left", eye, Vector3.LEFT, room["HEAD_SIDE"]], ["head fore", eye, Vector3.FORWARD, room["HEAD_FORE"]],
				["shoulder right", shoulder, Vector3.RIGHT, room["SHOULDER"]],
				["shoulder left", shoulder, Vector3.LEFT, room["SHOULDER"]],
				["knees", knee, Vector3.FORWARD, room["KNEE_FORE"]]]:
			var gap: float = _clearance(solids, ray[1], ray[2], float(room["FAN"]), float(room["FAR"]))
			line.append("%s %s" % [ray[0], "open" if gap >= float(room["FAR"]) else "%.2f" % gap])
			if gap < float(ray[3]):
				short.append("seat %d %s %.2f of %.2f" % [seat, ray[0], gap, ray[3]])
		said.append("%s: %s" % ["pilot" if seat == 0 else "gunner", ", ".join(line)])
	_check("both_players_fit", short.is_empty(),
		"%s; short: %s" % [" | ".join(said), "none" if short.is_empty() else ", ".join(short)])


## THE CREW ARE INSIDE THE HELICOPTER: both eyes, and every corner of each seat's promised room and of `cabin_room()`'s,
## inside the drawn fuselage by ray parity, fired UP and DOWN and both odd (`modelling_here.md` section 6). The floor
## `cabin_room()` publishes is the gunner's footwell, under his room.
func _the_crew_sit_inside_the_drawn_skin(frame: ApacheAirframe) -> void:
	var skin: Array = _skin(frame)
	var nudge := Vector3(0.0007, 0.0, 0.0007)
	var points: Array = []
	for eye in frame.crew_eyes():
		points.append(eye + nudge)
	var boxes: Array = frame.seat_rooms()
	boxes.append(frame.cabin_room()["room"])
	for box in boxes:
		for i in range(8):
			var corner: Vector3 = (box as AABB).get_endpoint(i)
			points.append(corner + ((box as AABB).get_center() - corner).normalized() * 0.001 + nudge)
	var outside: PackedStringArray = []
	for p in points:
		if not _inside(skin, p):
			outside.append("(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z])
	var room: Dictionary = frame.cabin_room()
	var floor_ok: bool = float(room["floor"]) <= (room["room"] as AABB).position.y + 0.25
	_check("the_crew_sit_inside_the_drawn_skin", outside.is_empty() and floor_ok,
		"%d points asked; outside the skin: %s; floor %.2f" % [points.size(),
			"none" if outside.is_empty() else ", ".join(outside), float(room["floor"])])


## WHAT EACH EYE SEES, which is what the tandem is for. From each eye, the cones in CONES, both sides, and the named
## sightlines; a sightline is clear when it meets nothing opaque within SIGHT metres. Glass and the main rotor are seen
## through. What each eye does meet is printed by part so a reader can see WHICH frame is in the way.
func _each_eye_sees_ahead_over_the_nose_and_beside(frame: ApacheAirframe) -> void:
	var solids: Array = _solids(frame, SEE_THROUGH, true)
	var ok: bool = true
	var said: PackedStringArray = []
	var eyes: Array[Vector3] = frame.crew_eyes()
	for seat in range(eyes.size()):
		var eye: Vector3 = eyes[seat]
		var line: PackedStringArray = []
		for cone in CONES:
			var c: Array = CONES[cone]
			var clear: int = 0
			var total: int = 0
			var met: Dictionary = {}
			for side in [1.0, -1.0]:
				var az: float = c[0]
				while az <= float(c[1]) + 0.01:
					var el: float = c[2]
					while el <= float(c[3]) + 0.01:
						var hit: String = _first_opaque(solids, eye, _look(az, el, side))
						total += 1
						if hit.is_empty():
							clear += 1
						else:
							met[hit] = int(met.get(hit, 0)) + 1
						el += 5.0
					az += 5.0
			var share: float = float(clear) / float(total)
			var floor_share: float = float((c[4] as Array)[seat])
			ok = ok and share >= floor_share
			line.append("%s %.2f of %d (floor %.2f)%s" % [cone, share, total, floor_share,
				"" if met.is_empty() else " met %s" % met])
		# THE PROFILE: at each azimuth, the lowest elevation still clear walking down from level a degree at a time -- the
		# number a crewman would give for "how far down can you see over there". Printed, not held: the cones hold it.
		var profile: PackedStringArray = []
		for az in [0.0, 15.0, 30.0, 45.0, 60.0, 90.0, 120.0]:
			var lowest: float = 1.0
			for step in range(0, 91):
				if not _first_opaque(solids, eye, _look(az, -float(step), 1.0)).is_empty():
					break
				lowest = -float(step)
			profile.append("%.0f:%s" % [az, "blocked at level" if lowest > 0.0 else "%.0f" % lowest])
		line.append("lowest clear by azimuth %s" % " ".join(profile))
		var blocked: PackedStringArray = []
		for s in SIGHTLINES:
			if not seat in (s[3] as Array):
				continue
			for side in [1.0, -1.0]:
				var hit: String = _first_opaque(solids, eye, _look(float(s[1]), float(s[2]), side))
				if not hit.is_empty():
					blocked.append("%s (%s) by %s" % [s[0], "right" if side > 0.0 else "left", hit])
		ok = ok and blocked.is_empty()
		said.append("%s: %s; named lines blocked: %s" % ["pilot" if seat == 0 else "gunner", ", ".join(line),
			"none" if blocked.is_empty() else ", ".join(blocked)])
	_check("each_eye_sees_ahead_over_the_nose_and_beside", ok, " | ".join(said))


## THE CHIN GUN POINTS WHERE IT IS TOLD, asked of the DRAWN BARREL and not of the pivots: the muzzle's end cap is found as
## the barrel's vertices farthest from the trunnion `sockets()` publishes, and the line from the trunnion to their middle
## must be the direction `set_gun` was handed -- yaw positive to PORT, as the simulation's `aim_turret` turns a mount --
## and `MUZZLE` long. Past [TM]'s stops it stays at the stop. A barrel drawn off its trunnion, turning the wrong way, or
## not turning at all, fails.
func _the_chin_gun_points_where_it_is_told_within_its_limits(frame: ApacheAirframe) -> void:
	var trunnion: Vector3 = frame.sockets()["gun"]
	var said: PackedStringArray = []
	var ok: bool = true
	var cases: Array = [[0.0, 0.0, 0.0, 0.0], [0.8, -0.3, 0.8, -0.3], [-1.2, 0.1, -1.2, 0.1],
		[3.0, -2.0, ApacheAirframe.GUN_YAW_LIMIT, -ApacheAirframe.GUN_DOWN], [-3.0, 1.0, -ApacheAirframe.GUN_YAW_LIMIT,
			ApacheAirframe.GUN_UP]]
	for c in cases:
		frame.set_gun(float(c[0]), float(c[1]))
		var pts := _points(frame, _part(frame, "Gun"))
		var far: float = 0.0
		for p in pts:
			far = maxf(far, p.distance_to(trunnion))
		var end := Vector3.ZERO
		var n: int = 0
		for p in pts:
			if p.distance_to(trunnion) > far - 0.02:
				end += p
				n += 1
		end /= float(maxi(n, 1))
		var yaw: float = c[2]
		var pitch: float = c[3]
		var want := Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
		var got: Vector3 = (end - trunnion).normalized()
		var off: float = rad_to_deg(got.angle_to(want))
		var long: float = (end - trunnion).length()
		ok = ok and off < 0.5 and absf(long - ApacheAirframe.MUZZLE) < 0.03
		said.append("asked %.2f/%.2f -> %.2f deg off, muzzle %.3f m out" % [c[0], c[1], off, long])
	frame.set_gun(0.0, 0.0)
	_check("the_chin_gun_points_where_it_is_told_within_its_limits", ok, "; ".join(said))


## BOTH ROTORS TURN ABOUT THEIR DRAWN HUBS by the angle the shared clock asks, and stand still parked -- solved from the
## drawn blades' vertices about the mast's and the tail hub's drawn axes, never by asking a node.
func _the_rotors_turn_about_their_drawn_hubs(frame: ApacheAirframe) -> void:
	var said: PackedStringArray = []
	var ok: bool = true
	for which in [["MainRotorBlades", "MastAndRadar", RotorcraftKit.MAIN_TURNS], ["TailRotorBlades", "TailRotorHub",
			RotorcraftKit.TAIL_TURNS]]:
		var blades := _part(frame, which[0])
		var axis: Vector3 = _box_of(frame, [_part(frame, which[1])]).get_center()
		var main: bool = which[0] == "MainRotorBlades"
		var flat := func(p: Vector3) -> Vector2:
			return Vector2(p.x - axis.x, p.z - axis.z) if main else Vector2(p.y - axis.y, p.z - axis.z)
		frame.set_rotors(false, 0.0, 0.0)
		var before := _points(frame, blades)
		var asked: float = 0.7
		frame.set_rotors(true, 0.0, asked / (TAU * float(which[2])))
		var after := _points(frame, blades)
		frame.set_rotors(false, 0.0, asked / (TAU * float(which[2])))
		var parked := _points(frame, blades)
		var still: float = 0.0
		for i in range(before.size()):
			still = maxf(still, before[i].distance_to(parked[i]))
		var worst_angle: float = 0.0
		var worst_radius: float = 0.0
		for i in range(0, before.size(), 5):
			var a: Vector2 = flat.call(before[i])
			var b: Vector2 = flat.call(after[i])
			if a.length() < (1.0 if main else 0.4):
				continue
			worst_angle = maxf(worst_angle, absf(absf(angle_difference(a.angle(), b.angle())) - asked))
			worst_radius = maxf(worst_radius, absf(a.length() - b.length()))
		ok = ok and worst_angle < 0.003 and worst_radius < 0.003 and still < 0.0005
		said.append("%s: worst angle error %.4f rad, radius %.4f m, parked moved %.5f m" % [which[0], worst_angle,
			worst_radius, still])
	frame.set_rotors(false, 0.0, 0.0)
	_check("the_rotors_turn_about_their_drawn_hubs", ok, "; ".join(said))


func _every_face_is_wound_outwards(frame: Node3D) -> void:
	var wrong: int = 0
	var total: int = 0
	var worst: Dictionary = {}
	for drawn in _meshes(frame):
		for s in range(drawn.mesh.get_surface_count()):
			var arrays: Array = drawn.mesh.surface_get_arrays(s)
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
## that stops drawing at range. The scope, stated: the whole ApacheAirframe subtree, rotors parked.
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
			draws += 1
			triangles += (drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_check("the_exterior_meets_the_first_lod_budget", triangles <= 100000 and draws <= 20 and culled >= 1
		and materials.size() <= 12,
		"the whole ApacheAirframe subtree: %d triangles, %d draw surfaces, %d materials, %d distance-culled"
			% [triangles, draws, materials.size(), culled])


# ---------------------------------------------------------------------------------------------------------------------

func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.mesh != null and drawn.is_visible_in_tree():
			out.append(drawn)
	return out


func _part(frame: Node, named: String) -> MeshInstance3D:
	return frame.find_child(named, true, false) as MeshInstance3D


## THE DRAWN VERTICES of a mesh in the craft's frame, never `transform * mesh.get_aabb()`.
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


## THE ANGLES OF A ROTOR'S SEPARATE ARMS round its axis: the vertices beyond `beyond` metres out, sorted by angle, split
## wherever two neighbours are more than 20 degrees apart; each arm's angle is its vertices' middle.
func _arm_angles(pts: PackedVector3Array, flat: Callable, beyond: float) -> Array:
	var angles: Array = []
	for p in pts:
		var v: Vector2 = flat.call(p)
		if v.length() > beyond:
			angles.append(v.angle())
	if angles.is_empty():
		return []
	angles.sort()
	# Start at a gap, so no arm is split across -PI.
	var start: int = 0
	for i in range(angles.size()):
		var next: float = float(angles[(i + 1) % angles.size()]) + (TAU if i == angles.size() - 1 else 0.0)
		if next - float(angles[i]) > deg_to_rad(20.0):
			start = (i + 1) % angles.size()
			break
	var arms: Array = []
	var group: Array = []
	for k in range(angles.size()):
		var i: int = (start + k) % angles.size()
		var a: float = float(angles[i])
		if not group.is_empty():
			var prev: float = float(group[-1])
			var d: float = wrapf(a - prev, -PI, PI)
			if absf(d) > deg_to_rad(20.0):
				arms.append(_mean_angle(group))
				group = []
		group.append(a)
	if not group.is_empty():
		arms.append(_mean_angle(group))
	arms.sort()
	return arms


static func _mean_angle(group: Array) -> float:
	var v := Vector2.ZERO
	for a in group:
		v += Vector2.from_angle(float(a))
	return v.angle()


## HOW FAR OUT A MESH REACHES where the plane z = `z` cuts it: every triangle edge that crosses the plane, interpolated,
## on its glass surface only or its painted one only, between heights `low` and `high`.
func _widest_at(frame: Node3D, mesh: MeshInstance3D, z: float, glass: bool, low: float, high: float) -> float:
	var into := frame.global_transform.affine_inverse() * mesh.global_transform
	var widest: float = 0.0
	for s in range(mesh.mesh.get_surface_count()):
		if _is_glass(mesh, s) != glass:
			continue
		var pts := PackedVector3Array()
		for p in (mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			pts.append(into * p)
		for i in range(0, pts.size() - 2, 3):
			for e in [[0, 1], [1, 2], [2, 0]]:
				var a: Vector3 = pts[i + e[0]]
				var b: Vector3 = pts[i + e[1]]
				if (a.z - z) * (b.z - z) < 0.0:
					var t: float = (z - a.z) / (b.z - a.z)
					var y: float = lerpf(a.y, b.y, t)
					if y >= low and y <= high:
						widest = maxf(widest, absf(lerpf(a.x, b.x, t)))
	return widest


## A direction from an eye: `az` degrees off dead ahead toward `side` (+1 right), `el` degrees above level.
static func _look(az: float, el: float, side: float) -> Vector3:
	var a: float = deg_to_rad(az)
	var e: float = deg_to_rad(el)
	return Vector3(side * sin(a) * cos(e), sin(e), -cos(a) * cos(e)).normalized()


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
			out.append({"name": _station_part(mesh), "faces": pts, "box": box.grow(0.01), "station": _in_a_station(mesh),
				"owner": _station_of(mesh)})
	return out


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


func _first_opaque(solids: Array, from: Vector3, along: Vector3) -> String:
	return String(_cast(solids, from, along, SIGHT)[1])


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
			var hit = Geometry3D.ray_intersects_triangle(from, along, faces[i], faces[i + 1], faces[i + 2])
			if hit != null:
				var d: float = ((hit as Vector3) - from).length()
				if d < best:
					best = d
					what = String(solid["name"])
	return [best, what]


## The fuselage's skin, glass and panel, as triangles: what "inside the helicopter" is asked of.
func _skin(frame: Node3D) -> Array:
	var skin: Array = []
	var pts := _points(frame, _part(frame, "Fuselage"))
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


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
