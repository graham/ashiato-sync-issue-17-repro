extends Node
## Headless: IS THE TANK A TANK -- seven road wheels a side, a track that wraps a sprocket and an
## idler, and does it stand on the ground it collides with?
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/tank_shape.tscn
##
## The tank is drawn round the simulation's own hull box, and that box is an Abrams: `tank_shape`
## in `cockpit_world.cpp` is 3.70 m wide, 2.40 m tall and 7.90 m long, against the M1A2's published
## 3.66 m, 2.44 m to the turret roof and 7.93 m. THE PHYSICS RESTS THAT BOX'S BOTTOM ON THE GROUND:
## a tank dropped on a flat field settles at y 1.1999 against an hy of 1.20, so `-extents.y` is the
## ground and everything here is measured up from it.
##
## THE NUMBERS ARE TYPED HERE ON PURPOSE. Every one of them is a statement about an M1 or about
## what a tracked vehicle is, and none is read off the constants the meshes were built from: a
## check that asks the builder what it drew asks nothing. Put `ROAD_WHEELS_A_SIDE` back to 5 in
## `vehicle_view.gd` and the count check goes red naming wheels 6 and 7, and nothing else moves.
##
## AND IT ASKS FOR PARTS BY NAME, AND MEASURES THEM FROM THEIR OWN VERTICES. Every wheel used to be
## called `TankRoadWheel`, so Godot's uniquifier decided what each was really called and no check
## could tell a road wheel from a sprocket; the sailplane's 1.80 m height contract was being met by
## an ANONYMOUS stub gun mount for the same reason (`lane/glider`, 2026-09-17). The sizes come from
## the drawn vertices put into the craft's frame, never `transform * get_aabb()`, which grows a box
## every time the thing it describes is turned.
##
## Read RESULT=, not the exit code.

## SEVEN. An M1, M1A1, M1A2 and M1A2 SEPv3 all have seven road wheels a side; the marks differ in
## armour, sights and weight, not in the number of wheels on the ground.
const ROAD_WHEELS_A_SIDE: int = 7
## A ROAD WHEEL IS 25 INCHES ACROSS on an M1, so it rolls on this radius. Typed, because the whole
## point of the check below is that a faceted wheel must still be this size at the flats.
const ROLLING_RADIUS: float = 0.3175
## THE M1A2'S OWN LENGTHS: 7.93 m of hull and 9.83 m gun forward, so the gun overhangs the bow by
## 1.90 m. A tank's gun adds under two metres to its length -- it does not add half a vehicle.
const REAL_HULL_LONG: float = 7.93
const REAL_GUN_FORWARD: float = 9.83
## How far the drawn overhang may be from 1.90 m before this stops being a tank's gun. Wide on
## purpose: this exists to catch a barrel that overhangs by a vehicle's length, not to argue about
## centimetres of a figure the simulation owns.
const OVERHANG_SLOP: float = 0.60
## How far apart two neighbouring wheel centres may differ from the mean pitch before the running
## gear is not evenly spread. A millimetre, because the spacing is computed rather than typed.
const PITCH_SLOP: float = 0.001
## A millimetre, for everything measured off vertices.
const SLOP: float = 0.001

var _failures: PackedStringArray = []


func _ready() -> void:
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.setup(0, Sim.Kind.TANK)
	var extents: Vector3 = Sim.geometry_of(Sim.Kind.TANK).get("extents", Vector3.ONE)
	_it_has_seven_road_wheels_a_side(view)
	_every_part_it_draws_carries_its_own_name(view)
	_the_road_wheels_are_evenly_spread_under_the_hull(view, extents)
	_it_stands_on_the_ground_its_physics_rests_on(view, extents)
	_nothing_is_drawn_outside_the_box_it_collides_with(view, extents)
	_the_track_wraps_a_rear_sprocket_and_a_front_idler(view)
	_a_road_wheel_rests_on_a_flat_at_its_true_radius(view)
	_the_wheels_and_the_track_are_still_touching(view)
	_no_gun_is_drawn_where_the_simulation_fits_none(view, extents)
	_the_gun_overhangs_the_bow_by_what_a_tanks_gun_does(view, extents)
	view.queue_free()
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## THE COUNT, asked for one named wheel at a time so a miss says which one is missing.
func _it_has_seven_road_wheels_a_side(view: VehicleView) -> void:
	for hand in ["Port", "Starboard"]:
		var missing: PackedStringArray = []
		var doubled: PackedStringArray = []
		for number in range(1, ROAD_WHEELS_A_SIDE + 1):
			var wanted := "Tank%sRoadWheel%d" % [hand, number]
			var found: Array = view.find_children(wanted, "MeshInstance3D", true, false)
			if found.is_empty():
				missing.append(wanted)
			elif found.size() > 1:
				doubled.append("%s x%d" % [wanted, found.size()])
		# And nothing beyond the seventh, which would be a count raised without this being read.
		var extra: Array = view.find_children(
			"Tank%sRoadWheel%d" % [hand, ROAD_WHEELS_A_SIDE + 1], "MeshInstance3D", true, false)
		var drawn: int = ROAD_WHEELS_A_SIDE - missing.size()
		_check("the_tank_has_seven_%s_road_wheels_each_a_named_part" % hand.to_lower(),
			missing.is_empty() and doubled.is_empty() and extra.is_empty(),
			"%d of %d present%s%s%s" % [drawn, ROAD_WHEELS_A_SIDE,
				"" if missing.is_empty() else ", missing " + ", ".join(missing),
				"" if doubled.is_empty() else ", duplicated " + ", ".join(doubled),
				"" if extra.is_empty() else ", and an eighth wheel this check has never heard of"])


## NOTHING THE TANK DRAWS IS ANONYMOUS. Godot renames a colliding child by appending a number, and
## a node left with its class name or an `@`-prefixed generated one is a part no check can ask for.
func _every_part_it_draws_carries_its_own_name(view: VehicleView) -> void:
	var seen: Dictionary = {}
	var nameless: PackedStringArray = []
	for part in _drawn(view):
		# THE PATH, NOT THE LEAF, is what a check can ask for: `Turret0/Mount` and `Turret1/Mount`
		# are the mounts of two gunners' guns, and neither of them is anonymous.
		var label := String(view.get_path_to(part))
		if label.contains("@") or label.contains("MeshInstance3D"):
			nameless.append(label)
		elif seen.has(label):
			nameless.append("%s twice" % label)
		seen[label] = true
	_check("every_visible_part_of_the_tank_is_a_named_one",
		nameless.is_empty(),
		"%d named parts drawn" % seen.size() if nameless.is_empty()
			else "%d named parts drawn, and %s" % [seen.size(), ", ".join(nameless)])


## EVENLY SPREAD, AND UNDER THE HULL. Seven wheels bunched at one end are seven wheels, and the
## count check would not notice.
func _the_road_wheels_are_evenly_spread_under_the_hull(view: VehicleView, extents: Vector3) -> void:
	var along: PackedFloat32Array = []
	var height: float = 0.0
	for number in range(1, ROAD_WHEELS_A_SIDE + 1):
		var part := _part(view, "TankPortRoadWheel%d" % number)
		if part == null:
			continue
		along.append(part.position.z)
		height = part.position.y
	if along.size() < 2:
		_check("the_tanks_road_wheels_are_spread_along_the_hull", false,
			"only %d wheels to measure" % along.size())
		return
	var pitch: float = (along[along.size() - 1] - along[0]) / float(along.size() - 1)
	var worst: float = 0.0
	for at in range(1, along.size()):
		worst = maxf(worst, absf((along[at] - along[at - 1]) - pitch))
	var inside: bool = absf(along[0]) <= extents.z and absf(along[along.size() - 1]) <= extents.z
	_check("the_tanks_road_wheels_are_spread_along_the_hull",
		absf(worst) <= PITCH_SLOP and inside and height < 0.0,
		"%.3f m pitch over %.3f m of a %.2f m hull, worst gap error %.4f m, axles %.2f m over the ground" % [
			absf(pitch), absf(along[along.size() - 1] - along[0]), extents.z * 2.0, worst,
			height + extents.y])


## IT STANDS ON ITS TRACK, ON THE GROUND. The physics rests the collision box's bottom on whatever
## it drives over -- measured, a tank dropped on a flat field settles at y 1.1999 against hy 1.20 --
## so the lowest drawn thing has to be at `-extents.y`, and it has to be TRACK. Until 2026-09-17 it
## was a road-wheel rim at -1.020, which left 0.18 m of daylight under a sixty-two-tonne vehicle.
func _it_stands_on_the_ground_its_physics_rests_on(view: VehicleView, extents: Vector3) -> void:
	var lowest: float = INF
	var standing_on: String = ""
	for part in _drawn(view):
		var box := _vertex_box(view, part)
		if box.position.y < lowest:
			lowest = box.position.y
			standing_on = String(part.name)
	_check("the_tank_stands_on_its_track_on_the_ground_the_physics_rests_it_on",
		absf(lowest + extents.y) <= SLOP and standing_on.contains("TrackGroundRun"),
		"lowest drawn point %.4f m against a ground at %.4f, and it is %s" % [
			lowest, -extents.y, standing_on])


## AND IT IS NO WIDER THAN THE THING THAT STOPS IT. A wheel drawn outside the collision box hangs
## through every wall the tank drives past; the running gear stood at x +-2.146 on a box 1.850 half
## wide until 2026-09-17, which is 4.29 m of vehicle round a 3.70 m hull.
##
## AND THE TRACK IS OUTSIDE THE WHEELS, not the other way round, which is what a track IS.
func _nothing_is_drawn_outside_the_box_it_collides_with(view: VehicleView, extents: Vector3) -> void:
	var widest: float = 0.0
	var widest_part: String = ""
	for part in _drawn(view):
		var box := _vertex_box(view, part)
		var reach: float = maxf(absf(box.position.x), absf(box.end.x))
		if reach > widest:
			widest = reach
			widest_part = String(part.name)
	_check("the_drawn_tank_is_no_wider_than_the_hull_it_collides_with",
		widest <= extents.x + SLOP,
		"widest drawn point %.3f m (%s) against a hull half-width of %.3f: %.2f m of vehicle round a %.2f m box" % [
			widest, widest_part, extents.x, widest * 2.0, extents.x * 2.0])

	var proud: PackedStringArray = []
	for hand in ["Port", "Starboard"]:
		var run := _part(view, "Tank%sTrackGroundRun" % hand)
		if run == null:
			proud.append("no %s ground run" % hand.to_lower())
			continue
		var outer: float = maxf(absf(_vertex_box(view, run).position.x),
			absf(_vertex_box(view, run).end.x))
		for number in range(1, ROAD_WHEELS_A_SIDE + 1):
			var wheel := _part(view, "Tank%sRoadWheel%d" % [hand, number])
			if wheel == null:
				continue
			var box := _vertex_box(view, wheel)
			var reach: float = maxf(absf(box.position.x), absf(box.end.x))
			if reach > outer - SLOP:
				proud.append("%s stands %.3f m out against a track face at %.3f" % [
					wheel.name, reach, outer])
	_check("and_the_track_runs_outside_the_road_wheels_rather_than_under_them",
		proud.is_empty(),
		"every road wheel is inboard of its track" if proud.is_empty() else ", ".join(proud))


## A TRACK WRAPS SOMETHING. A drive sprocket at the BACK -- -Z is forward and an M1 drives from the
## rear -- an idler at the FRONT, a run on the ground and a run over the road wheels. The three
## kinds of wheel are three different sizes, which is how a person tells them apart at a glance and
## is the reason each has its own name rather than all of them being "wheels".
func _the_track_wraps_a_rear_sprocket_and_a_front_idler(view: VehicleView) -> void:
	for hand in ["Port", "Starboard"]:
		var wanted: PackedStringArray = ["Tank%sDriveSprocket" % hand, "Tank%sIdler" % hand,
			"Tank%sTrackGroundRun" % hand, "Tank%sTrackTopRun" % hand]
		var missing: PackedStringArray = []
		for label in wanted:
			if _part(view, label) == null:
				missing.append(label)
		if not missing.is_empty():
			_check("the_%s_track_wraps_a_rear_drive_sprocket_and_a_front_idler" % hand.to_lower(),
				false, "missing %s" % ", ".join(missing))
			continue
		var sprocket := _vertex_box(view, _part(view, "Tank%sDriveSprocket" % hand))
		var idler := _vertex_box(view, _part(view, "Tank%sIdler" % hand))
		var wheel := _vertex_box(view, _part(view, "Tank%sRoadWheel1" % hand))
		var ground := _vertex_box(view, _part(view, "Tank%sTrackGroundRun" % hand))
		var top := _vertex_box(view, _part(view, "Tank%sTrackTopRun" % hand))
		var sizes: Array = [sprocket.size.y, idler.size.y, wheel.size.y]
		var distinct: bool = absf(sizes[0] - sizes[1]) > 0.01 and absf(sizes[1] - sizes[2]) > 0.01 \
			and absf(sizes[0] - sizes[2]) > 0.01
		_check("the_%s_track_wraps_a_rear_drive_sprocket_and_a_front_idler" % hand.to_lower(),
			sprocket.get_center().z > 0.0 and idler.get_center().z < 0.0
				and sprocket.size.y > wheel.size.y and distinct
				and ground.get_center().y < wheel.get_center().y
				and top.get_center().y > wheel.get_center().y,
			"sprocket %.2f m across at z %+.2f, idler %.2f at z %+.2f, road wheel %.2f; the runs sit at y %+.2f and %+.2f round an axle at %+.2f" % [
				sprocket.size.y, sprocket.get_center().z, idler.size.y, idler.get_center().z,
				wheel.size.y, ground.get_center().y, top.get_center().y, wheel.get_center().y])


## A FACETED WHEEL MUST CIRCUMSCRIBE THE CIRCLE IT STANDS FOR, AND REST ON A FLAT.
##
## Two mistakes, and one measurement catches both. A twelve-sided wheel drawn THROUGH a 0.635 m
## circle is 0.966 of it across the flats, so it stands 11 mm low and its rolling radius is 3.4 per
## cent short. And twelve segments starting at zero put a VERTEX at the bottom, which is a cog: the
## drop from the centre would then be the circumradius, 0.329, rather than the 0.3175 it rolls on.
## The distance from a wheel's centre to its lowest drawn vertex is 0.3175 only when the polygon
## circumscribes the circle AND is turned half a step.
func _a_road_wheel_rests_on_a_flat_at_its_true_radius(view: VehicleView) -> void:
	var wrong: PackedStringArray = []
	var stood: float = 0.0
	for hand in ["Port", "Starboard"]:
		for number in range(1, ROAD_WHEELS_A_SIDE + 1):
			var wheel := _part(view, "Tank%sRoadWheel%d" % [hand, number])
			if wheel == null:
				continue
			stood = wheel.position.y - _vertex_box(view, wheel).position.y
			if absf(stood - ROLLING_RADIUS) > SLOP:
				wrong.append("%s stands on %.4f m" % [wheel.name, stood])
	_check("a_road_wheel_rests_on_a_flat_at_the_radius_it_rolls_on",
		wrong.is_empty() and stood > 0.0,
		"every wheel stands on %.4f m against a true %.4f" % [stood, ROLLING_RADIUS]
			if wrong.is_empty() else ", ".join(wrong))


## THE CONTACTS ARE CLOSED -- WHICH IS A CHECK ABOUT A RELATIONSHIP AND NOT ABOUT A VALUE.
##
## A road wheel rides ON the track: the ground run's inner face and the wheel's contact line are the
## same surface, and the return run's underside and the wheel tops are another. Four numbers that
## must agree, and every one of them right today.
##
## SO WHY CHECK IT AT ALL? Because a range check on each of the four is BLIND to the one way this
## breaks. If the track's thickness or the wheel's diameter moves, both sides of each joint move
## APART TOGETHER -- neither leaves any range anybody would write, the wheels hang in a gap or sink
## into the track, and every value check still passes. The only thing that catches it is asking
## whether the two are still touching.
##
## AND THEY MUST TOUCH EXACTLY, not overlap. Bedding one part into another is the right answer for a
## STRUCTURAL joint -- a fin root in a tailcone -- which opens the first time either end moves. A
## rolling contact is not that joint: a road wheel bedded into its own track is a wheel drawn sunk
## into the thing it rides on. Exact is correct here; what makes it safe is that `_build_tank_body`
## derives all four surfaces from one chain, `ground -> tread -> axle -> wheel_top`, and that this
## asks whether the chain still closes.
func _the_wheels_and_the_track_are_still_touching(view: VehicleView) -> void:
	for hand in ["Port", "Starboard"]:
		var ground_run := _part(view, "Tank%sTrackGroundRun" % hand)
		var top_run := _part(view, "Tank%sTrackTopRun" % hand)
		if ground_run == null or top_run == null:
			_check("the_%s_wheels_and_track_are_still_touching" % hand.to_lower(), false,
				"no track runs to touch")
			continue
		var tread: float = _vertex_box(view, ground_run).end.y
		var carried: float = _vertex_box(view, top_run).position.y
		var apart: PackedStringArray = []
		var worst: float = 0.0
		for number in range(1, ROAD_WHEELS_A_SIDE + 1):
			var wheel := _part(view, "Tank%sRoadWheel%d" % [hand, number])
			if wheel == null:
				continue
			var box := _vertex_box(view, wheel)
			var under: float = box.position.y - tread
			var over: float = carried - box.end.y
			worst = maxf(worst, maxf(absf(under), absf(over)))
			if absf(under) > SLOP or absf(over) > SLOP:
				apart.append("%s stands %+.4f m off the ground run and %+.4f m off the return run" % [
					wheel.name, under, over])
		_check("the_%s_wheels_and_track_are_still_touching" % hand.to_lower(),
			apart.is_empty(),
			"every wheel meets the tread at %.3f and carries the return run at %.3f, worst gap %.4f m" % [
				tread, carried, worst] if apart.is_empty() else ", ".join(apart))


## NO GUN IS DRAWN WHERE THE SIMULATION FITS NONE -- and so the tallest thing on the tank is the tank.
##
## The tank has two turret seats and one gun. `Sim.gun_of(TANK, 1).fitted` is FALSE, and until
## 2026-09-17 `_build_turret` drew a 0.36 m dome and a 1.1 m barrel on that mount anyway, under a
## comment that said so on purpose: "a mount with nothing on it keeps the stub it always had". It sat
## at y 1.480, the HIGHEST POINT OF THE VEHICLE, 2.68 m over the ground against an M1A2's 2.44 m to
## its turret roof. A height contract written for this tank would have been met by a gun the
## simulation says is not there -- which is the sailplane's stub gun exactly (`lane/glider`).
##
## ASKED OF THE GUN TABLE, NOT OF THE BUILDER. Whether a gun exists is `Sim.gun_of`'s to say, and it
## is the authority the builder is meant to follow; this does not ask the builder what it drew and
## then agree with it. The tallest drawn point is printed so its height can be read against 2.44 m.
func _no_gun_is_drawn_where_the_simulation_fits_none(view: VehicleView, extents: Vector3) -> void:
	var phantom: PackedStringArray = []
	for i in range(VehicleView.MAX_TURRETS):
		var mount := view.find_child("Turret%d" % i, true, false) as Node3D
		if mount == null or bool(Sim.gun_of(Sim.Kind.TANK, i).get("fitted", false)):
			continue
		for found in mount.find_children("*", "MeshInstance3D", true, false):
			var part := found as MeshInstance3D
			if part.mesh != null and part.is_visible_in_tree():
				phantom.append("%s at y %.3f" % [view.get_path_to(part), _vertex_box(view, part).end.y])
	var top: float = -INF
	var tallest: String = ""
	for part in _drawn(view):
		var y: float = _vertex_box(view, part).end.y
		if y > top:
			top = y
			tallest = String(view.get_path_to(part))
	_check("no_gun_is_drawn_on_a_mount_the_simulation_says_is_empty",
		phantom.is_empty(),
		"tallest drawn point is %s, %.2f m over the ground against an M1A2's 2.44%s" % [
			tallest, top + extents.y,
			"" if phantom.is_empty() else "; drawn on an EMPTY mount: " + ", ".join(phantom)])


## THE GUN'S OVERHANG, STATED AS A NUMBER RATHER THAN LOOKED AT.
##
## A photograph of this tank on 2026-09-17 was read as a barrel overhanging the bow by half the
## vehicle again. It does not: the muzzle stands at z -5.600 and the collision bow at -3.950, so
## the overhang is 1.65 m against the M1A2's own 1.90 m, and the drawn vehicle gun-forward is
## 9.32 m against a published 9.83. The drawn gun is if anything a little SHORT. This check is what
## that claim should have been made against, and it is wide enough that it is about the claim --
## half a vehicle -- rather than about centimetres of a barrel length the simulation owns.
func _the_gun_overhangs_the_bow_by_what_a_tanks_gun_does(view: VehicleView, extents: Vector3) -> void:
	var muzzle := _part(view, "Barrel")
	if muzzle == null:
		_check("the_tanks_gun_overhangs_its_bow_by_what_a_tanks_gun_does", false, "no named barrel")
		return
	var forward: float = INF
	var backward: float = -INF
	for part in _drawn(view):
		var box := _vertex_box(view, part)
		forward = minf(forward, box.position.z)
		backward = maxf(backward, box.end.z)
	var overhang: float = -extents.z - forward
	var gun_forward: float = backward - forward
	_check("the_tanks_gun_overhangs_its_bow_by_what_a_tanks_gun_does",
		absf(overhang - (REAL_GUN_FORWARD - REAL_HULL_LONG)) <= OVERHANG_SLOP
			and absf(gun_forward - REAL_GUN_FORWARD) <= REAL_GUN_FORWARD * 0.1,
		"muzzle %.3f m ahead of a bow at %.3f, so %.2f m of overhang against the M1A2's %.2f; %.2f m gun forward against %.2f" % [
			forward, -extents.z, overhang, REAL_GUN_FORWARD - REAL_HULL_LONG,
			gun_forward, REAL_GUN_FORWARD])


## ---- reading the drawn thing ------------------------------------------------------------------

## Every mesh that is actually on screen. A hidden one is not part of the model: `_hull` stays in
## the tree for craft that draw a body over it, and counting it would measure a box nobody sees.
func _drawn(view: VehicleView) -> Array:
	var out: Array = []
	for found in view.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if part.mesh != null and part.is_visible_in_tree():
			out.append(part)
	return out


func _part(view: VehicleView, label: String) -> MeshInstance3D:
	var found: Array = view.find_children(label, "MeshInstance3D", true, false)
	return found[0] as MeshInstance3D if not found.is_empty() else null


## A PART'S BOX FROM ITS OWN DRAWN VERTICES, in the craft's frame. Never `transform * get_aabb()`,
## which grows a box every time the thing it describes is turned -- and every wheel here is turned
## twice, once to lay its axle across the craft and once more to put a flat at the bottom.
func _vertex_box(view: VehicleView, part: MeshInstance3D) -> AABB:
	var into := view.global_transform.affine_inverse() * part.global_transform
	var box := AABB()
	var first := true
	for surface in range(part.mesh.get_surface_count()):
		var arrays: Array = part.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] \
			if arrays[Mesh.ARRAY_VERTEX] != null else PackedVector3Array()
		for vertex in vertices:
			var point := into * vertex
			box = AABB(point, Vector3.ZERO) if first else box.expand(point)
			first = false
	return box


func _check(label: String, okay: bool, detail: String) -> void:
	print("[tank_shape] %s %s (%s)" % ["PASS" if okay else "FAIL", label, detail])
	if not okay:
		_failures.append(label)
