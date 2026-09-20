extends Node
## Headless: THE CB90 FAST ASSAULT CRAFT -- its shape against the published figures, its crew, its two guns at the back,
## and its missiles locked and launched through the helm's own controls on the light twin's targeting.
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/cb90.tscn
##
## Asked for by the user on 2026-09-18: "a beefier CB90 or other fast assault craft so that we can have a boat with two
## guns on the back, maybe a missile launcher as well, that has the same targeting as the plane that has missiles."
##
## WHAT IS HELD HERE, AND WHAT IS HELD ELSEWHERE. Its handling -- top speed, the lean into a turn, staying upright -- is
## `handling`'s, which flies every hull through the helm and gates every small boat by its displacement. Its guns are
## fired through a hand on the grip in `gunners` and aimed by mount in `mount_aim`. Its seats fit a player in
## `seat_room` and `boat_seats`, and its model is held to its parts in `ship_models`. This holds the rest:
##
##   1. THE SHAPE is the Wikipedia infobox's: 15.9 m overall, 3.8 m in the beam, 0.8 m of draught, 15.3 t standard.
##   2. THE CREW: a helm and a weapons officer who can both launch, and two gunners.
##   3. THE GUNS ARE AT THE BACK: both fitted, both abaft midships, one each side.
##   4. IT IS FAST ENOUGH TO THROW SPRAY: flat out through the helm, past `WakeTuning.SPRAY_SPEED`, which is the rule the
##      spray obeys (by speed and height, never by kind).
##   5. THE MISSILES, THROUGH THE REAL PATH: a pilot seated at the helm by the server, the master arm and the weapon
##      selector thrown on the bus from the input frame, LOCK and LAUNCH pressed as the frame's buttons -- the bits a
##      headset's wheel and a desk's keys both set. The lock is `work_the_seekers`' and the missile `launch_from`'s, the
##      code the light twin's pilot uses; nothing here calls `launch_missile`. The target is an aircraft 22 degrees over
##      the horizon, which a seeker looking along a boat's bow cannot see (the radar's cone is 20) and the CB90's raised
##      box can; and the missile must leave the box upward and not drop into the sea off the roof.
##   7. IN A HEADSET, THE WHEEL at each launch seat carries LOCK and LAUNCH, and the sight looks along the box.
##   8. AND A SHIP: the radar pair is the "sea radar" row, which sees a hull on the water, and the helm locks a patrol boat
##      under way and launches at it through the same frame (the user: "not ground targets but ships yes").
##   9. AND NEVER A LAND VEHICLE: a car where the ship was, and the seeker stays searching.
##   6. AND THE LIGHT TWIN STILL DROPS ITS OWN MISSILE off the rail: the box's throw is the boat's, not every craft's.
##
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
const CLIENT: int = 61
## THE PUBLISHED FIGURES (Wikipedia, "CB90-class fast assault craft", the infobox) and how close the shape must be.
const LENGTH: float = 15.9
const BEAM: float = 3.8
const DRAUGHT: float = 0.8
const MASS: float = 15300.0
const WITHIN: float = 0.10
## THE TARGET: an aircraft this far ahead and this many degrees over the horizon, flying away level.
const TARGET_OUT: float = 1500.0
const TARGET_DEGREES: float = 22.0
const TARGET_SPEED: float = 60.0
## How long the lock is given, the radar row's 1.5 s and a margin, and how long the missile is watched.
const LOCK_S: float = 3.0
const FLY_S: float = 1.0

var _failures: PackedStringArray = []
var _world: Object = null
var _pilot: int = 0
var _craft: int = 0
var _seq: int = 0
var _input: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[cb90] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_the_shape_is_the_published_one()
	_the_crew_and_the_guns()
	_it_is_fast_enough_to_throw_spray()
	_it_locks_and_launches_on_the_light_twins_targeting()
	_it_locks_a_ship_under_way()
	_it_never_locks_a_land_vehicle()
	_the_light_twin_still_drops_its_missile()
	_the_helms_wheel_locks_and_launches()
	_finish()


## ---- 1. the shape ----------------------------------------------------------------------------------------------------

func _the_shape_is_the_published_one() -> void:
	var g: Dictionary = Sim.geometry_of(Sim.Kind.CB90)
	var half: Vector3 = g.get("extents", Vector3.ZERO)
	_check("it_is_15_9_m_long", absf(half.z * 2.0 - LENGTH) <= WITHIN, "%.2f m, published %.1f" % [half.z * 2.0, LENGTH])
	_check("it_is_3_8_m_in_the_beam", absf(half.x * 2.0 - BEAM) <= WITHIN, "%.2f m, published %.1f" % [half.x * 2.0, BEAM])
	var keel: float = INF
	var hulls: int = 0
	for part in (g.get("parts", []) as Array):
		if String((part as Dictionary).get("part", "")) == "hull":
			hulls += 1
			keel = minf(keel, float(part.get("bottom", 0.0)))
	var draught: float = float(g.get("waterline", 0.0)) - keel
	_check("it_draws_0_8_m", hulls > 0 and absf(draught - DRAUGHT) <= WITHIN, "%.2f m, published %.1f" % [draught, DRAUGHT])
	_check("it_weighs_its_standard_displacement", is_equal_approx(float(g.get("mass", 0.0)), MASS),
		"%.0f kg, published %.0f" % [float(g.get("mass", 0.0)), MASS])


## ---- 2 and 3. the crew and the guns -----------------------------------------------------------------------------------

func _the_crew_and_the_guns() -> void:
	var g: Dictionary = Sim.geometry_of(Sim.Kind.CB90)
	var launch: Array = Sim.missile_schema(Sim.Kind.CB90).get("launch_seats", []) as Array
	_check("the_helm_and_the_weapons_officer_both_launch", launch == [0, 1], "launch seats %s" % str(launch))
	var mounts: Array = []
	for mount in range(4):
		var gun: Dictionary = Sim.gun_of(Sim.Kind.CB90, mount)
		if bool(gun.get("fitted", false)):
			mounts.append(gun)
	_check("two_guns", mounts.size() == 2, "%d fitted" % mounts.size())
	if mounts.size() == 2:
		var a: Vector3 = mounts[0].get("at", Vector3.ZERO)
		var b: Vector3 = mounts[1].get("at", Vector3.ZERO)
		# ABAFT MIDSHIPS is +Z; "at the back" is the after third of the boat.
		var aft: float = float((g.get("extents", Vector3.ONE) as Vector3).z) / 3.0
		_check("both_guns_are_at_the_back", a.z > aft and b.z > aft, "mounts at z %.2f and %.2f, the after third from %.2f" % [a.z, b.z, aft])
		_check("one_each_side", signf(a.x) != signf(b.x) and absf(a.x) > 0.3 and absf(b.x) > 0.3, "x %.2f and %.2f" % [a.x, b.x])


## ---- 4. fast enough to throw spray ----------------------------------------------------------------------------------

func _it_is_fast_enough_to_throw_spray() -> void:
	if not _begin(Vector3.ZERO, 0.0):
		_check("the_helm_is_taken", false, "")
		return
	_input["throttle"] = 1.0
	var fastest: float = 0.0
	for i in range(int(40.0 / (TICK * 4.0))):
		_step(TICK * 4.0)
		var s: Dictionary = _world.vehicle_state(_craft)
		fastest = maxf(fastest, (s.get("velocity", Vector3.ZERO) as Vector3).length())
	_check("flat_out_it_throws_spray", fastest > WakeTuning.SPRAY_SPEED,
		"%.1f m/s (%.0f kt) flat out, spray from %.1f m/s" % [fastest, fastest * 1.944, WakeTuning.SPRAY_SPEED])
	# AND A WALL SIZED BY ITS HULL (team-lead's ruling, 2026-09-18): on the water at that speed the CB90 throws a wall
	# higher than the 5.6 m launch's and lower than the full one, and an aircraft skimming at the same speed keeps the
	# aircraft's curve. The launch's length is asked of its shape, not typed.
	var ours: float = float((Sim.geometry_of(Sim.Kind.CB90).get("extents", Vector3.ONE) as Vector3).z) * 2.0
	var launch: float = float((Sim.geometry_of(Sim.Kind.BOAT).get("extents", Vector3.ONE) as Vector3).z) * 2.0
	var mine: float = WakeTuning.sheet_height(WakeTuning.hull_spray_strength(0.0, fastest, ours))
	var small: float = WakeTuning.sheet_height(WakeTuning.hull_spray_strength(0.0, fastest, launch))
	_check("its_wall_is_sized_by_its_hull", mine > small and mine < WakeTuning.SHEET_HEIGHT and small > 1.0,
		"%.1f m behind the CB90, %.1f behind the launch, %.1f the most" % [mine, small, WakeTuning.SHEET_HEIGHT])
	_check("and_an_aircraft_keeps_its_curve",
		is_equal_approx(WakeTuning.hull_spray_strength(1.0, fastest, ours), WakeTuning.spray_strength(1.0, fastest)),
		"%.3f skimming at 1 m" % WakeTuning.spray_strength(1.0, fastest))
	_end()


## ---- 5. the missiles ------------------------------------------------------------------------------------------------

func _it_locks_and_launches_on_the_light_twins_targeting() -> void:
	# THE LIGHT TWIN'S ROWS, AND ITS RADAR WITH SHIPS: the heat pair is the aeroplane's own row; the radar pair is "sea
	# radar", which must be the aeroplane's radar row number for number but for its name and `ships` (the user: "not
	# ground targets but ships yes"). And the aeroplane's rows see no ship: its missiles are what they were.
	var ours: Array = []
	for entry in (Sim.missile_schema(Sim.Kind.CB90).get("stations", []) as Array):
		ours.append(String((entry as Dictionary).get("name", "")))
	var rows: Dictionary = {}
	for row in _rows():
		rows[String((row as Dictionary).get("name", ""))] = row
	var same: bool = rows.has("radar") and rows.has("sea radar")
	var differs: PackedStringArray = []
	if same:
		for key in (rows["radar"] as Dictionary):
			if key in ["name", "id", "ships"]:
				continue
			if str(rows["radar"][key]) != str(rows["sea radar"].get(key)):
				differs.append(key)
	_check("it_carries_heat_and_the_radar_that_sees_ships", ours == ["heat", "sea radar"], "stations %s" % str(ours))
	_check("sea_radar_is_the_radar_row_with_ships", same and differs.is_empty() and bool(rows["sea radar"].get("ships", false))
		and not bool(rows["sea radar"].get("ground", true)), "differs in %s" % str(differs))
	_check("the_light_twins_rows_see_no_ship", rows.has("radar") and rows.has("heat")
		and not bool(rows["radar"].get("ships", true)) and not bool(rows["heat"].get("ships", true)), "")
	var radar: int = ours.find("sea radar")
	if not _begin(Vector3.ZERO, 0.0):
		_check("the_helm_is_taken", false, "")
		return
	# THE TARGET, dead ahead (-Z) and TARGET_DEGREES up, flying away.
	var up: float = deg_to_rad(TARGET_DEGREES)
	var at := Vector3(0.0, TARGET_OUT * sin(up), -TARGET_OUT * cos(up))
	var target: int = int(_world.spawn_vehicle(Sim.Kind.PLANE, at, 0.0, Vector3(0.0, 0.0, -TARGET_SPEED)))
	_step(0.5)
	# THE MASTER ARM AND THE SELECTOR, as the switches at the seat throw them: bus commands on the input frame.
	_command(Sim.Channel.MASTER, 1)
	_step(0.1)
	_command(Sim.Channel.WEAPON, radar)
	_step(0.1)
	# LOCK: a press, held a few ticks and let go, as a thumb does.
	_input["buttons"] = Sim.BUTTON_LOCK
	_step(TICK * 4.0)
	_input["buttons"] = 0
	var row: Dictionary = {}
	var t: float = 0.0
	while t < LOCK_S:
		_step(TICK * 4.0)
		t += TICK * 4.0
		row = _my_lock()
		if String(row.get("phase_name", "")) == "locked":
			break
	_check("the_helm_locks_an_aircraft_22_degrees_up", String(row.get("phase_name", "")) == "locked"
		and int(row.get("target", 0)) == target,
		"phase %s on %d (target %d) after %.1f s, station %s, why %s" % [row.get("phase_name", "none"),
			int(row.get("target", 0)), target, t, row.get("type_name", "?"), row.get("why_name", "?")])
	_check("and_it_may_launch", bool(row.get("can_launch", false)), "why: %s" % row.get("why_name", "?"))
	# LAUNCH: the press.
	var before: int = (_world.missile_states() as Array).size()
	_input["buttons"] = Sim.BUTTON_LAUNCH
	_step(TICK * 4.0)
	_input["buttons"] = 0
	var launched: Array = _world.missile_states() as Array
	_check("a_missile_leaves", launched.size() == before + 1, "%d missiles, %d before" % [launched.size(), before])
	if launched.size() <= before:
		_end()
		return
	var missile: Dictionary = launched[launched.size() - 1]
	_check("it_is_guided_onto_the_lock", bool(missile.get("guided", false)), "guided %s" % missile.get("guided"))
	var roof: float = (missile.get("position", Vector3.ZERO) as Vector3).y
	# AND IT CLIMBS OUT OF THE BOX rather than dropping off the roof into the sea.
	_step(FLY_S)
	var flown: Array = _world.missile_states() as Array
	var still: Dictionary = {}
	for m in flown:
		if int((m as Dictionary).get("entity", 0)) == int(missile.get("entity", -1)):
			still = m
	var height: float = (still.get("position", Vector3.ZERO) as Vector3).y
	_check("it_climbs_out_of_the_box", not still.is_empty() and bool(still.get("flying", false)) and height > roof + 5.0,
		"%.1f m up after %.1f s, left the rail at %.1f, flying %s" % [height, FLY_S, roof, still.get("flying", false)])
	# AND CLOSES ON IT: the gap shrinks over the next two seconds. Not "nearer than at launch" -- the target is running
	# away at TARGET_SPEED and a missile a second off the rail is still gathering itself.
	var gap_then: float = _gap(int(missile.get("entity", -1)), target)
	_step(2.0)
	var gap_now: float = _gap(int(missile.get("entity", -1)), target)
	_check("it_closes_on_the_target", gap_now < gap_then - 100.0, "%.0f m from it, %.0f two seconds before" % [gap_now, gap_then])
	_end()


## ---- 6. and the aeroplane is as it was ---------------------------------------------------------------------------

## THE LIGHT TWIN STILL DROPS ITS MISSILE OFF THE RAIL, 2 m/s down and nothing ahead, because the box launcher's throw is
## the CB90's loadout and not a change to how every missile leaves: its pilot, its master arm, its heat station (which
## needs no lock) and its launch button, and the missile's velocity against the aeroplane's on the tick it appears.
func _the_light_twin_still_drops_its_missile() -> void:
	_end()
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	var made: Dictionary = _world.spawn_pilot(CLIENT, Sim.Kind.PLANE, Vector3(0.0, 800.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -60.0))
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_seq = 0
	_input = {"throttle": 0.7, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0, "buttons": 0}
	_step(0.2)
	_command(Sim.Channel.MASTER, 1)
	_step(0.1)
	_command(Sim.Channel.WEAPON, 0)
	_step(0.1)
	_input["buttons"] = Sim.BUTTON_LAUNCH
	var missile: Dictionary = {}
	var plane: Dictionary = {}
	for i in range(12):
		_step(TICK)
		var all: Array = _world.missile_states() as Array
		if not all.is_empty():
			missile = all[0]
			plane = _world.vehicle_state(_craft)
			break
	_input["buttons"] = 0
	if missile.is_empty():
		_check("the_light_twin_launches", false, "no missile in 12 ticks")
		_end()
		return
	var b := Basis(plane.get("basis", Quaternion()) as Quaternion)
	var relative: Vector3 = (missile.get("velocity", Vector3.ZERO) as Vector3) - (plane.get("velocity", Vector3.ZERO) as Vector3)
	var down: float = -relative.dot(b * Vector3.UP)
	var ahead: float = relative.dot(b * Vector3.FORWARD)
	# 2 m/s down, and a tick of its motor and gravity on top: a thrown missile would be 15 m/s ahead and 3 up.
	_check("the_light_twin_still_drops_its_missile", down > 1.0 and down < 3.0 and ahead < 3.0,
		"%.2f m/s down and %.2f ahead of the aeroplane as it leaves the rail" % [down, ahead])
	_end()


## ---- 7. the helm's wheel ------------------------------------------------------------------------------------------

## IN A HEADSET THE HANDS ARE ON THE WHEEL, so the wheel at each seat that launches must carry the lock and the launch --
## the light twin's stick bindings -- and the seat its lock sight, looking along the raised box. Built from the craft's
## own scene as `fit` builds every craft, so what is checked is what `CockpitStation._fit_the_missiles` fitted.
func _the_helms_wheel_locks_and_launches() -> void:
	var view := (load("res://objects/vehicles/craft_cb90.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	for seat in (Sim.missile_schema(Sim.Kind.CB90).get("launch_seats", []) as Array):
		var wheel := view.controls_for(int(seat)).get("stick") as SteeringWheel
		var table: Dictionary = wheel.bindings() if wheel != null else {}
		_check("seat_%d_wheel_locks_and_launches" % int(seat),
			str(table.get(Bind.THUMB_HIGH)) == str(Bind.frame(Sim.BUTTON_LOCK))
				and str(table.get(Bind.TRIGGER)) == str(Bind.frame(Sim.BUTTON_LAUNCH)),
			"a wheel %s launching %s, upper thumb '%s', trigger '%s'" % [wheel != null, wheel.launches if wheel != null else false, Bind.says(table.get(Bind.THUMB_HIGH, {})),
				Bind.says(table.get(Bind.TRIGGER, {}))])
		var sight := view.station_for(int(seat)).get_node_or_null("LockSight") as Node3D if view.station_for(int(seat)) != null else null
		var raised: float = float(Sim.missile_schema(Sim.Kind.CB90).get("launcher_pitch", 0.0))
		_check("seat_%d_sight_looks_along_the_box" % int(seat), sight != null and is_equal_approx(sight.rotation.x, raised),
			"sight %s at %.3f rad, the box at %.3f" % [sight != null, sight.rotation.x if sight != null else -1.0, raised])
	view.queue_free()


## EVERY MISSILE ROW, from a world of its own.
func _rows() -> Array:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	var rows: Array = world.missile_types()
	world.teardown()
	return rows


## ---- 8. a ship ------------------------------------------------------------------------------------------------------

## THE HELM LOCKS A SHIP UNDER WAY AND LAUNCHES AT IT, through the same frame as the aircraft: a patrol boat 1.5 km ahead
## on the water, running across the bow at 12 m/s, the sea radar station, LOCK, LAUNCH, and the missile closing on it.
func _it_locks_a_ship_under_way() -> void:
	if not _begin(Vector3.ZERO, 0.0):
		_check("the_helm_is_taken", false, "")
		return
	var stations: Array = Sim.missile_schema(Sim.Kind.CB90).get("stations", []) as Array
	var sea: int = -1
	for entry in stations:
		if String((entry as Dictionary).get("name", "")) == "sea radar":
			sea = int(entry.get("station", -1))
	var target: int = int(_world.spawn_vehicle(Sim.Kind.GUNBOAT, Vector3(0.0, 0.0, -1500.0), PI * 0.5,
		Vector3(-12.0, 0.0, 0.0)))
	_step(0.5)
	_command(Sim.Channel.MASTER, 1)
	_step(0.1)
	_command(Sim.Channel.WEAPON, sea)
	_step(0.1)
	_input["buttons"] = Sim.BUTTON_LOCK
	_step(TICK * 4.0)
	_input["buttons"] = 0
	var row: Dictionary = {}
	var t: float = 0.0
	while t < LOCK_S:
		_step(TICK * 4.0)
		t += TICK * 4.0
		row = _my_lock()
		if String(row.get("phase_name", "")) == "locked":
			break
	var moving: float = ((_world.vehicle_state(target) as Dictionary).get("velocity", Vector3.ZERO) as Vector3).length()
	_check("the_helm_locks_a_ship_under_way", String(row.get("phase_name", "")) == "locked" and int(row.get("target", 0)) == target
		and moving > 1.0, "phase %s on %d (the patrol boat %d, making %.1f m/s) after %.1f s, station %s" % [
			row.get("phase_name", "none"), int(row.get("target", 0)), target, moving, t, row.get("type_name", "?")])
	var before: int = (_world.missile_states() as Array).size()
	_input["buttons"] = Sim.BUTTON_LAUNCH
	_step(TICK * 4.0)
	_input["buttons"] = 0
	var launched: Array = _world.missile_states() as Array
	if launched.size() <= before:
		_check("a_missile_leaves_for_the_ship", false, "no missile")
		_end()
		return
	var missile: int = int((launched[launched.size() - 1] as Dictionary).get("entity", -1))
	_step(1.0)
	var gap_then: float = _gap(missile, target)
	_step(2.0)
	var gap_now: float = _gap(missile, target)
	_check("and_closes_on_the_ship", gap_now < gap_then - 100.0, "%.0f m from it, %.0f two seconds before" % [gap_now, gap_then])
	_end()


## ---- 9. and never a land vehicle ---------------------------------------------------------------------------------

## A CAR WHERE THE SHIP WAS: the same helm, the same frame, the same station, and a car on a slab of ground 1.5 km dead
## ahead, inside the seeker's cone -- "not ground targets but ships yes". LOCK is pressed and the seeker must stay
## SEARCHING, never LOCKING, for longer than the radar row takes to lock a ship.
func _it_never_locks_a_land_vehicle() -> void:
	if not _begin(Vector3.ZERO, 0.0):
		_check("the_helm_is_taken", false, "")
		return
	var sea: int = -1
	for entry in (Sim.missile_schema(Sim.Kind.CB90).get("stations", []) as Array):
		if String((entry as Dictionary).get("name", "")) == "sea radar":
			sea = int(entry.get("station", -1))
	_world.add_static_box(Vector3(0.0, -5.0, -1500.0), Vector3(40.0, 5.0, 40.0))
	var car: int = int(_world.spawn_vehicle(Sim.Kind.CAR, Vector3(0.0, 0.7, -1500.0), 0.0, Vector3.ZERO))
	_step(0.5)
	_command(Sim.Channel.MASTER, 1)
	_step(0.1)
	_command(Sim.Channel.WEAPON, sea)
	_step(0.1)
	_input["buttons"] = Sim.BUTTON_LOCK
	_step(TICK * 4.0)
	_input["buttons"] = 0
	var phases: Dictionary = {}
	var t: float = 0.0
	while t < LOCK_S:
		_step(TICK * 4.0)
		t += TICK * 4.0
		phases[String(_my_lock().get("phase_name", "none"))] = true
	var there: Vector3 = (_world.vehicle_state(car) as Dictionary).get("position", Vector3.ZERO)
	_check("and_never_locks_a_land_vehicle", car != 0 and not phases.has("locking") and not phases.has("locked")
		and there.distance_to(Vector3(0.0, 0.7, -1500.0)) < 5.0,
		"phases %s over %.1f s at a car %.0f m ahead on its slab" % [str(phases.keys()), t, -there.z])
	_end()


## HOW FAR A MISSILE IS FROM A VEHICLE, or INF when either is gone.
func _gap(missile: int, vehicle: int) -> float:
	var at: Vector3 = Vector3.INF
	for m in (_world.missile_states() as Array):
		if int((m as Dictionary).get("entity", 0)) == missile:
			at = (m as Dictionary).get("position", Vector3.ZERO)
	var there: Dictionary = _world.vehicle_state(vehicle)
	if at == Vector3.INF or there.is_empty():
		return INF
	return at.distance_to(there.get("position", Vector3.ZERO) as Vector3)


## THIS PILOT'S SEEKER, off the simulation's own lock states.
func _my_lock() -> Dictionary:
	for row in (_world.lock_states() as Array):
		if int((row as Dictionary).get("client", -1)) == CLIENT:
			return row
	return {}


## ---- the world, the helm and the frame -----------------------------------------------------------------------------

func _begin(at: Vector3, yaw: float) -> bool:
	_end()
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	var made: Dictionary = _world.spawn_pilot(CLIENT, Sim.Kind.CB90, at, yaw, Vector3.ZERO)
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_seq = 0
	_input = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0, "buttons": 0}
	return _craft != 0 and _pilot != 0


func _end() -> void:
	if _world != null:
		_world.teardown()
		_world = null


## A BUS COMMAND on a new sequence number, never 0: see `tests/handling.gd`, `_command`.
func _command(channel: int, value: int) -> void:
	_seq = _seq % 3 + 1
	_input["command_channel"] = channel
	_input["command_value"] = value
	_input["command_seq"] = _seq


func _step(seconds: float) -> void:
	for i in range(maxi(1, int(round(seconds / TICK)))):
		_world.set_pilot_input(_pilot, _input)
		_world.tick(TICK)


func _finish() -> void:
	_end()
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
