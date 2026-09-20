extends Node
## Headless: IS THE CARRIER A FORD, where a player can find out?
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/carrier_shape.tscn
##
## The carrier was a Nimitz-sized box: 333 m by 76.8, the deck 11 m above its middle, a hull 76.8 m wide all the way to
## the keel and an island drawn somewhere nothing collided with. It is now the Gerald R. Ford (CVN-78) at its real size,
## built from PARTS in the simulation's shape table, and this holds those parts to the fact sheet -- the numbers below are
## its rows, each marked with how sure the sheet is (`agents.md`, "A FORD-CLASS CARRIER").
##
## THE NUMBERS ARE TYPED HERE ON PURPOSE. The ship's shape is one number in one place, `carrier_shape` in the C++; this
## is the independent statement it is checked against, and a test that read its expectations off the thing under test
## would pass whatever the ship was.
##
## AND WHERE IT CAN, IT ASKS THE PHYSICS rather than the table: an aeroplane put down on the bow, on the angled deck's
## sponson, on an elevator and on the island stays at the height the parts say, an aeroplane put down where the old
## rectangle had deck and the Ford has sea goes into the sea, and a carrier steamed for five minutes across the swell
## floats at 11.9 m of draught.
##
## Read RESULT=, not the exit code.

const CARRIER: int = 12
const PLANE: int = 1
const TICK: float = 1.0 / 120.0

## THE FACT SHEET. A sheet point measured "x aft of the bow tip" is at z = x - SHEET_BOW in the ship's frame.
const SHEET_BOW: float = 168.5
const DECK_LONG: float = 332.8          # CONFIRMED (1,092 ft)
const DECK_WIDE: float = 78.0           # CONFIRMED (256 ft)
const WATERLINE_BEAM: float = 40.8      # CONFIRMED (134 ft)
const DRAUGHT: float = 11.9             # CONFIRMED (39 ft)
const DECK_ABOVE_WATER: float = 18.5    # ESTIMATE, from the Nimitz hull the Ford shares
const ISLAND_LONG: float = 18.3         # SINGLE (HII)
const ISLAND_WIDE: float = 9.1          # SINGLE (HII)
const ISLAND_FROM_BOW: float = 230.0    # ESTIMATE, +-10
const ELEVATOR_LONG: float = 25.9       # SINGLE (HII)
const ELEVATOR_WIDE: float = 15.8       # SINGLE (HII)
const STROKE: float = 91.4              # CONFIRMED (300 ft)
const WIRE_SPACING: float = 12.2        # CONFIRMED for Nimitz (40 ft)
const BOW_SHUTTLES_FROM_BOW: float = 101.0   # ESTIMATE
const WAIST_SHUTTLES_FROM_BOW: float = 205.0 # ESTIMATE, the two at 200 and 210

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[carrier] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var geometry: Dictionary = Sim.geometry_of(CARRIER)
	var parts: Array = geometry.get("parts", []) as Array
	_check("the_carrier_is_built_from_parts", not parts.is_empty(), "%d parts" % parts.size())
	if parts.is_empty():
		_finish()
		return
	_the_flight_deck(parts)
	_the_hull(parts)
	_the_island(parts)
	_the_elevators(parts)
	_the_catapults_and_wires()
	_the_seats(geometry, parts)
	_no_head_is_inside_anything_solid(geometry, parts)
	_the_gunners_have_their_arcs(parts)
	await _what_the_physics_stands_on(geometry)
	await _a_touchdown_stops_on_the_deck(geometry)
	await _it_floats_at_its_draught()
	_finish()


## ---- the table ----------------------------------------------------------------------------------------------------

func _the_flight_deck(parts: Array) -> void:
	var bounds: Rect2 = _plan_bounds(parts, "deck")
	var top: float = -INF
	for part in parts:
		if String(part["part"]) == "deck":
			top = maxf(top, float(part["top"]))
	_check("the_flight_deck_is_a_fords_length", absf(bounds.size.y - DECK_LONG) < 1.5,
		"%.1f m against %.1f" % [bounds.size.y, DECK_LONG])
	_check("and_its_width", absf(bounds.size.x - DECK_WIDE) < 1.5, "%.1f m against %.1f" % [bounds.size.x, DECK_WIDE])
	_check("and_stands_at_its_height_above_the_waterline", absf(top - DECK_ABOVE_WATER) < 1.0,
		"%.2f m against %.1f" % [top, DECK_ABOVE_WATER])
	# THE ANGLED DECK IS TO PORT: the deck reaches further out to port than to starboard, which is the whole silhouette.
	_check("and_it_reaches_further_to_port_than_to_starboard", -bounds.position.x > bounds.end.x + 2.0,
		"%.1f m to port, %.1f to starboard" % [-bounds.position.x, bounds.end.x])


func _the_hull(parts: Array) -> void:
	var bounds: Rect2 = _plan_bounds(parts, "hull")
	var keel: float = INF
	for part in parts:
		if String(part["part"]) == "hull":
			keel = minf(keel, float(part["bottom"]))
	_check("the_hull_is_a_fords_waterline_beam", absf(bounds.size.x - WATERLINE_BEAM) < 0.6,
		"%.1f m against %.1f" % [bounds.size.x, WATERLINE_BEAM])
	_check("and_goes_down_to_its_draught", absf(-keel - DRAUGHT) < 0.3, "keel at %.2f m against %.1f" % [keel, -DRAUGHT])


func _the_island(parts: Array) -> void:
	var bounds := Rect2()
	var found: bool = false
	var roof: float = 0.0
	for part in parts:
		if not (String(part["part"]) in ["island", "bridge"]):
			continue
		# THE BLOCK, not the mast standing on it.
		var outline: Rect2 = _outline_rect(part["outline"])
		if outline.size.x < 4.0:
			continue
		bounds = outline if not found else bounds.merge(outline)
		found = true
		roof = maxf(roof, float(part["top"]))
	var from_bow: float = bounds.get_center().y + SHEET_BOW
	_check("the_island_is_on_the_starboard_side", found and bounds.position.x > 10.0,
		"from x %.1f to %.1f" % [bounds.position.x, bounds.end.x])
	_check("and_where_the_sheet_puts_it", absf(from_bow - ISLAND_FROM_BOW) < 10.0,
		"its middle %.1f m aft of the bow tip against %.0f" % [from_bow, ISLAND_FROM_BOW])
	# The bridge overhangs the block by a little each side, which is what its windows need; the block is the sheet's.
	_check("and_the_size_of_one", absf(bounds.size.y - ISLAND_LONG) < 1.5 and absf(bounds.size.x - ISLAND_WIDE) < 1.5,
		"%.1f by %.1f m against %.1f by %.1f" % [bounds.size.y, bounds.size.x, ISLAND_LONG, ISLAND_WIDE])
	_check("and_stands_on_the_deck_edge", absf(bounds.end.x - _plan_bounds(parts, "deck", -200.0, 200.0,
		bounds.position.y, bounds.end.y).end.x) < 1.6, "its outboard face at x %.1f" % bounds.end.x)


func _the_elevators(parts: Array) -> void:
	var island: Rect2 = _plan_bounds(parts, "island")
	var starboard: int = 0
	var port: int = 0
	var forward_of_island: int = 0
	for part in parts:
		if String(part["part"]) != "deck":
			continue
		var r: Rect2 = _outline_rect(part["outline"])
		if absf(r.size.y - ELEVATOR_LONG) > 0.3 or absf(r.size.x - ELEVATOR_WIDE) > 0.3:
			continue
		if r.get_center().x > 0.0:
			starboard += 1
			if r.end.y < island.position.y:
				forward_of_island += 1
		else:
			port += 1
	_check("three_elevators_two_starboard_forward_of_the_island_and_one_to_port",
		starboard == 2 and forward_of_island == 2 and port == 1,
		"%d starboard (%d forward of the island), %d port" % [starboard, forward_of_island, port])


func _the_catapults_and_wires() -> void:
	var wrong: Array[String] = []
	for i in range(CarrierPlan.CATAPULTS.size()):
		var cat: Dictionary = CarrierPlan.CATAPULTS[i]
		var start: Vector2 = cat["start"]
		var end: Vector2 = cat["end"]
		if absf(start.distance_to(end) - STROKE) > 0.5:
			wrong.append("cat %s stroke %.1f" % [cat["name"], start.distance_to(end)])
		for at in [start, end, CarrierPlan.deflector_at(i)]:
			if not CarrierPlan.is_on_deck(at):
				wrong.append("cat %s has %s over the sea" % [cat["name"], at])
		var from_bow: float = start.y + SHEET_BOW
		var wanted: float = BOW_SHUTTLES_FROM_BOW if i < 2 else WAIST_SHUTTLES_FROM_BOW
		if absf(from_bow - wanted) > 10.0:
			wrong.append("cat %s shuttle %.0f m from the bow" % [cat["name"], from_bow])
		if i >= 2 and end.x >= start.x:
			wrong.append("waist cat %s does not splay to port" % cat["name"])
	_check("four_catapults_of_the_real_stroke_on_the_deck_where_the_sheet_puts_them",
		CarrierPlan.CATAPULTS.size() == 4 and wrong.is_empty(), "%s" % ["all four" if wrong.is_empty() else wrong])
	var launch: Dictionary = CarrierPlan.CATAPULTS[CarrierPlan.LAUNCH]
	_check("and_the_one_a_jet_is_marshalled_onto_runs_straight_up_the_deck",
		absf((launch["start"] as Vector2).x - (launch["end"] as Vector2).x) < 0.01, "DeckLaunch squares against a heading of 0")

	var ends: Array = []
	var off: Array[String] = []
	for w in range(CarrierPlan.WIRES_FROM_RAMP.size()):
		var pair: Array[Vector2] = CarrierPlan.wire_ends(w)
		ends.append((pair[0] + pair[1]) * 0.5)
		for at in pair:
			if not CarrierPlan.is_on_deck(at):
				off.append("wire %d end %s" % [w + 1, at])
	var spacing: Array[float] = []
	for w in range(1, ends.size()):
		spacing.append((ends[w] as Vector2).distance_to(ends[w - 1]))
	var even: bool = spacing.all(func(s: float) -> bool: return absf(s - WIRE_SPACING) < 0.3)
	_check("three_wires_twelve_metres_apart_all_on_the_deck", ends.size() == 3 and even and off.is_empty(),
		"spacing %s%s" % [spacing, "" if off.is_empty() else ", %s" % [off]])


func _the_seats(geometry: Dictionary, parts: Array) -> void:
	var wrong: Array[String] = []
	var poses: Array = geometry.get("seat_poses", []) as Array
	for seat in range(poses.size()):
		var at: Vector3 = poses[seat]["position"]
		var station: String = String(poses[seat]["station"])
		var room: String = "station" if station == "turret" else "bridge"
		var inside: bool = false
		for part in parts:
			# ON THE FLOOR of the room, inside its outline -- and, in a bridge, with the eye under its roof. A gun tub is
			# open: a gunner's eye is over its rim, which is the point of standing in one.
			var roofed: bool = room == "bridge"
			if String(part["part"]) == room and Geometry2D.is_point_in_polygon(Vector2(at.x, at.z), part["outline"]) \
					and absf(at.y - float(part["bottom"])) < 0.01 \
					and (not roofed or at.y + CockpitStation.EYE_HEIGHT < float(part["top"])):
				inside = true
		if not inside:
			wrong.append("seat %d (%s) at %s is in no %s" % [seat, station, at, room])
	_check("the_helm_is_on_the_bridge_and_the_gunners_in_their_tubs", wrong.is_empty() and poses.size() == 4,
		"%s" % ["four seats in their rooms" if wrong.is_empty() else wrong])


## NO SEATED HEAD IS INSIDE ANYTHING THE PHYSICS COLLIDES WITH: the eye of every seat, and a head's width round it, is in
## no part the simulation calls solid. A bridge that collided would put the whole crew's heads inside a block.
func _no_head_is_inside_anything_solid(geometry: Dictionary, parts: Array) -> void:
	var wrong: Array[String] = []
	var poses: Array = geometry.get("seat_poses", []) as Array
	for seat in range(poses.size()):
		var eye: Vector3 = (poses[seat]["position"] as Vector3) + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
		for offset in [Vector3.ZERO, Vector3.RIGHT * 0.25, Vector3.LEFT * 0.25, Vector3.UP * 0.25, Vector3.DOWN * 0.25,
				Vector3.FORWARD * 0.25, Vector3.BACK * 0.25]:
			var inside: String = _solid_at(parts, eye + offset)
			if inside != "":
				wrong.append("seat %d's head at %s is in the %s" % [seat, eye + offset, inside])
	_check("no_seated_head_is_inside_anything_solid", wrong.is_empty(),
		"%s" % ["four heads clear" if wrong.is_empty() else wrong])


## EVERY GUNNER HAS A FIELD OF FIRE FROM THEIR TUB: across the mount's whole traverse, a degree at a time, how much of it
## a level round from the pintle travels 150 m without meeting a solid part of the ship.
func _the_gunners_have_their_arcs(parts: Array) -> void:
	var poses: Array = Sim.geometry_of(CARRIER).get("seat_poses", []) as Array
	for seat in range(poses.size()):
		var mount: int = Sim.mount_of_seat(CARRIER, seat)
		if mount < 0:
			continue
		var gun: Dictionary = Sim.gun_of(CARRIER, mount)
		var at: Vector3 = gun.get("at", Vector3.ZERO)
		var rest: float = float((gun.get("rest", Vector2.ZERO) as Vector2).x)
		var span: float = float(gun.get("yaw_span", 0.0))
		var degrees: int = int(round(rad_to_deg(span * 2.0)))
		var clear: int = 0
		for i in range(degrees + 1):
			var yaw: float = rest - span + deg_to_rad(float(i))
			var way := Vector3(-sin(yaw), 0.0, -cos(yaw))
			var open: bool = true
			for step in range(2, 300):
				if _solid_at(parts, at + way * (float(step) * 0.5)) != "":
					open = false
					break
			if open:
				clear += 1
		_check("the_gunner_in_seat_%d_has_a_clear_field_of_fire" % seat, clear >= 150,
			"%d of the mount's %d degrees clear of the ship from %s, pitch %s rad" % [clear, degrees, at,
				gun.get("pitch_range", Vector2.ZERO)])


func _solid_at(parts: Array, p: Vector3) -> String:
	for part in parts:
		if bool(part.get("solid", false)) and p.y > float(part["bottom"]) and p.y < float(part["top"]) \
				and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), part["outline"]):
			return String(part["part"])
	return ""


## ---- the physics ----------------------------------------------------------------------------------------------------

## A TOUCHDOWN: an aeroplane coming down onto the aft deck of a carrier under way, 22 m/s faster than the ship and sinking
## at 1.5 m/s, with its pilot on the brakes. It has to stop on the deck, at the deck's height, going the ship's speed --
## which is what a landing ends as, and what the parts' deck has to hold as the old rectangle did.
func _a_touchdown_stops_on_the_deck(geometry: Dictionary) -> void:
	var world: Object = _world()
	var made: Dictionary = world.spawn_pilot(91, CARRIER, Vector3.ZERO, 0.0, Vector3.ZERO)
	var ship: int = int(made.get("vehicle", 0))
	var helm: int = int(made.get("pilot", 0))
	for i in range(int(20.0 / TICK)):
		world.set_pilot_input(helm, {"throttle": 1.0})
		world.tick(TICK)
	var deck: float = float((geometry["extents"] as Vector3).y)
	var half: float = float((Sim.geometry_of(PLANE).get("extents", Vector3.ONE) as Vector3).y)
	var state: Dictionary = world.vehicle_state(ship)
	var from_local := Vector3(-8.0, deck + half + 1.2, 110.0)
	var coming: Vector3 = (state["velocity"] as Vector3) + (state["basis"] as Quaternion) * Vector3(0.0, -1.5, -22.0)
	var lander: Dictionary = world.spawn_pilot(92, PLANE, _on_ship(world, ship, from_local), 0.0, coming)
	var plane: int = int(lander.get("vehicle", 0))
	var pilot: int = int(lander.get("pilot", 0))
	for i in range(int(12.0 / TICK)):
		world.set_pilot_input(helm, {"throttle": 1.0})
		world.set_pilot_input(pilot, {"throttle": 0.0, "brake": 1.0})
		world.tick(TICK)
	var local: Vector3 = _in_ship(world, ship, plane)
	var closing: float = ((world.vehicle_state(plane)["velocity"] as Vector3)
		- (world.vehicle_state(ship)["velocity"] as Vector3)).length()
	_check("an_aeroplane_touching_down_on_the_deck_under_way_stops_on_it",
		absf(local.y - half - deck) < 1.5 and closing < 1.0 and CarrierPlan.is_on_deck(Vector2(local.x, local.z)),
		"at %s in the ship's frame, %.2f m/s against the deck, after rolling %.0f m at a ship's %.1f m/s" % [local,
			closing, from_local.z - local.z, (state["velocity"] as Vector3).length()])
	_let_go(world)


## AN AEROPLANE PUT DOWN ON THE DECK stands where the deck is -- and put down where the old rectangle said there was deck
## and the Ford's bow has narrowed, it goes into the sea.
func _what_the_physics_stands_on(geometry: Dictionary) -> void:
	var world: Object = _world()
	var ship: int = int(world.spawn_vehicle(CARRIER, Vector3.ZERO, 0.0, Vector3.ZERO))
	_run(world, 240)
	var deck: float = float((geometry["extents"] as Vector3).y)
	var half: float = float((Sim.geometry_of(PLANE).get("extents", Vector3.ONE) as Vector3).y)
	var places: Dictionary = {
		"the_bow": Vector2(0.0, -150.0),
		"the_angled_decks_sponson": Vector2(-36.0, 0.0),
		"the_port_elevator": Vector2(-33.0, 69.5),
		"the_stern": Vector2(0.0, 150.0),
	}
	var planes: Dictionary = {}
	for name in places:
		var at: Vector2 = places[name]
		planes[name] = int(world.spawn_vehicle(PLANE, _on_ship(world, ship, Vector3(at.x, deck + half + 0.5, at.y)), 0.0,
			Vector3.ZERO))
	var roof: float = 42.5
	planes["the_island_roof"] = int(world.spawn_vehicle(PLANE, _on_ship(world, ship, Vector3(23.55, roof + half + 0.5,
		64.9)), 0.0, Vector3.ZERO))
	var sea: int = int(world.spawn_vehicle(PLANE, _on_ship(world, ship, Vector3(30.0, deck + half + 0.5, -155.0)), 0.0,
		Vector3.ZERO))
	_run(world, 360)
	for name in planes:
		var stands: float = _in_ship(world, ship, int(planes[name])).y - half
		var wanted: float = roof if name == "the_island_roof" else deck
		_check("an_aeroplane_put_down_on_%s_stands_on_it" % name, absf(stands - wanted) < 1.2,
			"its underside %.2f m above the waterline against %.2f" % [stands, wanted])
	var gone: float = _in_ship(world, ship, sea).y
	_check("and_one_put_down_beside_the_bow_where_the_old_deck_was_goes_into_the_sea", gone < deck - 10.0,
		"%.1f m above the waterline three seconds later" % gone)
	_let_go(world)


## FIVE MINUTES UNDER WAY ACROSS THE SWELL, and the hull rides at its draught and stays level.
##
## FROM THE ORIGIN TOWARDS -Z, which is the negative side of `swell_height`'s wrap. On 2026-09-15 that wrap used `fmod`,
## which keeps the sign, while the ocean shaders' `tile()` floors, so on this side the simulated swell was about half a wave
## out of phase with the painted one (found by cockpit-pirate, fixed to floor in its step 2). The tolerances are physical
## -- half a metre of draught, a degree and a half of tilt -- and not tuned to either phase: measured 11.91 m and 0.97
## degrees before the fix.
func _it_floats_at_its_draught() -> void:
	var world: Object = _world()
	var made: Dictionary = world.spawn_pilot(90, CARRIER, Vector3(0.0, 4.0, 0.0), 0.0, Vector3.ZERO)
	var ship: int = int(made.get("vehicle", 0))
	var helm: int = int(made.get("pilot", 0))
	var heights: Array[float] = []
	var worst_tilt: float = 0.0
	var fastest: float = 0.0
	for i in range(int(300.0 / TICK)):
		world.set_pilot_input(helm, {"throttle": 1.0})
		world.tick(TICK)
		if i >= int(30.0 / TICK) and i % 60 == 0:
			var state: Dictionary = world.vehicle_state(ship)
			heights.append(float((state["position"] as Vector3).y))
			worst_tilt = maxf(worst_tilt, rad_to_deg(Basis(state["basis"] as Quaternion).y.angle_to(Vector3.UP)))
			fastest = maxf(fastest, (state["velocity"] as Vector3).length())
	var mean: float = 0.0
	for h in heights:
		mean += h
	mean /= maxf(float(heights.size()), 1.0)
	# THE ORIGIN IS ON THE DESIGN WATERLINE, so the draught is the keel's depth below the sea: 11.9 m less however high
	# the origin rides.
	var draught: float = DRAUGHT - mean
	_check("it_floats_at_its_real_draught_for_five_minutes_under_way", absf(draught - DRAUGHT) < 0.5,
		"%.2f m of draught on average against %.1f, over %d samples at up to %.1f m/s" % [draught, DRAUGHT,
			heights.size(), fastest])
	_check("and_is_very_stable", worst_tilt < 1.5, "%.2f degrees off level at the worst" % worst_tilt)
	_let_go(world)


## ---- helpers ------------------------------------------------------------------------------------------------------

func _world() -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	return world


func _let_go(world: Object) -> void:
	world.teardown()
	if not (world is RefCounted):
		world.free()


func _run(world: Object, ticks: int) -> void:
	for i in range(ticks):
		world.tick(TICK)


## A point in the ship's frame, in the world.
func _on_ship(world: Object, ship: int, local: Vector3) -> Vector3:
	var state: Dictionary = world.vehicle_state(ship)
	return (state["position"] as Vector3) + (state["basis"] as Quaternion) * local


## A vehicle's position in the ship's frame.
func _in_ship(world: Object, ship: int, vehicle: int) -> Vector3:
	var state: Dictionary = world.vehicle_state(ship)
	var at: Vector3 = world.vehicle_state(vehicle).get("position", Vector3.ZERO)
	return (state["basis"] as Quaternion).inverse() * (at - (state["position"] as Vector3))


func _outline_rect(outline: PackedVector2Array) -> Rect2:
	var r := Rect2(outline[0], Vector2.ZERO)
	for p in outline:
		r = r.expand(p)
	return r


## The plan bounds of every part of a kind, optionally only those overlapping a band of z.
func _plan_bounds(parts: Array, role: String, _x0: float = -INF, _x1: float = INF, z0: float = -INF,
		z1: float = INF) -> Rect2:
	var out := Rect2()
	var found: bool = false
	for part in parts:
		if String(part["part"]) != role:
			continue
		var r: Rect2 = _outline_rect(part["outline"])
		if r.end.y < z0 or r.position.y > z1:
			continue
		out = r if not found else out.merge(r)
		found = true
	return out


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
