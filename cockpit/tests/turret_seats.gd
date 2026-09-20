extends Node
## Headless: A BATTLESHIP'S TURRET GUNNERS SIT WHERE THEY CAN SEE WHAT THEIR GUNS REACH.
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/turret_seats.tscn
##
## Plan item 22d. Each turret seat is a tub on a hood over its own turret's training axis, fixed to the hull
## (`kNavalHood` in the simulation, the hood's column in `Battleship._hoods`). They were the 12.7 mm tubs' places, and
## from the port wing of the 02 level the tower hid every starboard bearing of turret 2's arc. What this holds:
##
##   1. THE GUNNER IS OVER THE AXIS AND OVER THE ROOF: each turret seat's eye is on its mount's training axis, above the
##      drawn gunhouse roof, and inside no drawn panel. The first build sat both gunners inside their gunhouses (the
##      shape table read the decks before it had counted them) and every other suite passed.
##   2. THE HOOD CLEARS THE BARREL AT THE STOP, COMPUTED. An eye on the axis looks straight along the centre barrel. At
##      the gun's own elevation stop (`Sim.gun_of` pitch_range), the drawn barrel's top at the muzzle -- trunnion, length
##      and bore from `Battleship` -- must be `BARREL_CLEARANCE_M` under the sight line from the seated eye to the sea at
##      the gun's reach. From the roof, with no hood, the barrel was in that line from 5.97 degrees (3,372 m).
##   3. THE BLIND ARCS ARE HELD, on the ship as drawn: every mesh of the battleship is given a trimesh collider, and from
##      each gunner's eye a ray goes out on every degree of its turret's arc to a point 30 m up at 6 km and to the sea at
##      6 km. Turret 3's gunner is blind on none of its arc, turret 2's on at most `MOUNT_0_MOST_BLIND_DEG` (the tower's two
##      aft quarters). A superstructure edit answers here for what it hides.
##
## And it PRINTS the pilot house's view over the bow -- the nearest sea ahead in sight from each helm eye -- which the hood
## on turret 2 stands in front of: 210 m ahead of the eye before the hoods (2026-09-16).
##
## Read RESULT=, not the exit code.

const BATTLESHIP: int = 13
const TURRET_SEATS: Array[int] = [2, 3]
## How far under the sight line the barrel's top at the muzzle must be at the stop, metres.
const BARREL_CLEARANCE_M: float = 0.25
## How far out the sight line is taken to, metres: the gun's reach, whose sea the gunner watches.
const REACH_M: float = 6000.0
## Where a ray that meets the ship is counted blind, metres from the eye: anything nearer is our own ship.
const OWN_SHIP_M: float = 400.0
## A point this high at REACH_M: a battleship's upperworks.
const UPPERWORKS_M: float = 30.0
## The most of turret 2's arc its gunner may be blind on, degrees: 42 measured from the hood (2026-09-16).
const MOUNT_0_MOST_BLIND_DEG: int = 42
const MOUNT_1_MOST_BLIND_DEG: int = 0

var _failures: PackedStringArray = []
var _level: FlightLevel = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[turret_seats] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	for i in range(240):
		await get_tree().physics_frame
	var geometry: Dictionary = Sim.geometry_of(BATTLESHIP)
	var parts: Array = geometry.get("parts", []) as Array
	var model: Dictionary = Battleship.build(geometry, "")
	var panels: Array = model.get("panels", []) as Array
	for seat in TURRET_SEATS:
		_the_gunner_is_over_the_axis_and_over_the_roof(geometry, parts, panels, seat)
		_the_hood_clears_the_barrel_at_the_stop(geometry, parts, seat)
	var view: VehicleView = await _a_battleship_drawn()
	if view != null:
		await _colliders_on_the_drawn_ship(view)
		for seat in TURRET_SEATS:
			_the_blind_arc_is_held(view, geometry, seat)
		_the_pilot_house_sees_the_sea_ahead(view, geometry)
	_finish()


## ---- 1 and 2: arithmetic on the model ------------------------------------------------------------------------------

func _eye_of(geometry: Dictionary, seat: int) -> Vector3:
	var pose: Dictionary = (geometry.get("seat_poses", []) as Array)[seat]
	return (pose["position"] as Vector3) + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)


## The drawn turret a mount is, from `Battleship.TURRETS`.
static func _turret_of(mount: int) -> Dictionary:
	for turret in Battleship.TURRETS:
		if int(turret.get("mount", -1)) == mount:
			return turret
	return {}


static func _roof_of(parts: Array, turret: Dictionary) -> float:
	return Battleship._foot(parts, Vector2(0.0, float(turret["z"]))) + float(turret["raised"]) + Battleship.GUNHOUSE.y


func _the_gunner_is_over_the_axis_and_over_the_roof(geometry: Dictionary, parts: Array, panels: Array, seat: int) -> void:
	var mount: int = Sim.mount_of_seat(BATTLESHIP, seat)
	var turret: Dictionary = _turret_of(mount)
	var gun: Dictionary = Sim.gun_of(BATTLESHIP, mount)
	var eye: Vector3 = _eye_of(geometry, seat)
	var axis: Vector3 = gun.get("at", Vector3.INF) as Vector3
	var roof: float = _roof_of(parts, turret)
	var inside: Array[String] = []
	for panel in panels:
		if (panel as AABB).grow(0.05).has_point(eye):
			inside.append("%s" % panel)
	var off_axis: float = Vector2(eye.x - axis.x, eye.z - axis.z).length()
	_check("the_seat_%d_gunner_is_over_turret_%d_s_axis_above_its_roof_and_inside_nothing_drawn" % [seat, mount],
		not turret.is_empty() and off_axis < 0.05 and eye.y > roof + CockpitStation.EYE_HEIGHT and inside.is_empty(),
		"eye %s, %.2f m off the axis at %s; %.2f m over the drawn roof at %.2f; inside %s" % [eye, off_axis, axis,
			eye.y - roof, roof, inside])


## THE SIGHT LINE, from the seated eye to the sea at the gun's reach along any bearing, and the centre barrel laid along
## that bearing at the stop. Both are in the vertical plane through the axis, so the question is the height of each at the
## muzzle's distance out.
func _the_hood_clears_the_barrel_at_the_stop(geometry: Dictionary, parts: Array, seat: int) -> void:
	var mount: int = Sim.mount_of_seat(BATTLESHIP, seat)
	var turret: Dictionary = _turret_of(mount)
	var gun: Dictionary = Sim.gun_of(BATTLESHIP, mount)
	var stop: float = (gun.get("pitch_range", Vector2.ZERO) as Vector2).y
	var eye: Vector3 = _eye_of(geometry, seat)
	var trunnion: float = _roof_of(parts, turret) - Battleship.GUNHOUSE.y + Battleship.TRUNNION
	var length: float = Battleship.GUNHOUSE.z * 0.5 + Battleship.BARREL
	var out: float = length * cos(stop)
	var barrel_top: float = trunnion + length * sin(stop) + Battleship.BORE * 0.5 / cos(stop)
	var line: float = eye.y - out * eye.y / REACH_M
	var clearance: float = line - barrel_top
	_check("from_seat_%d_the_sight_line_clears_turret_%d_s_centre_barrel_at_its_stop" % [seat, mount],
		stop > 0.0 and clearance >= BARREL_CLEARANCE_M,
		"stop %.2f deg; muzzle %.1f m out, its top %.2f m up; the sight line there %.2f m up; clearance %.2f m (at least %.2f); the drawn trunnion %.2f m, the gun's %.2f m"
		% [rad_to_deg(stop), out, barrel_top, line, clearance, BARREL_CLEARANCE_M, trunnion, (gun.get("at", Vector3.ZERO) as Vector3).y])


## ---- 3: the drawn ship -------------------------------------------------------------------------------------------

func _a_battleship_drawn() -> VehicleView:
	var rig: PilotRig = _level.rig
	rig.ask_for_kind(BATTLESHIP)
	var view: VehicleView = null
	for i in range(900):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and view.kind == BATTLESHIP:
			break
	_check("a_battleship_is_drawn", view != null and view.kind == BATTLESHIP, "%s" % [view])
	return view if view != null and view.kind == BATTLESHIP else null


## EVERY MESH OF THE SHIP AS SEEN FROM ON IT, as a collider -- not the seats' furniture and not the rig, which are the
## gunner's own, and not the far silhouette (`ShipHull`'s "Far", drawn only past `NEAR_TO`): a gunner on the ship sees
## the near model. The first run counted both, and every blind degree was put down to the silhouette.
func _colliders_on_the_drawn_ship(view: VehicleView) -> void:
	for node in view.find_children("*", "MeshInstance3D", true, false):
		if _under(node, "CockpitStation") or _under(node, "PilotRig") or _under(node, "RangeSight"):
			continue
		var mesh_node := node as MeshInstance3D
		if mesh_node.visibility_range_begin > 0.0:
			continue
		if mesh_node.mesh != null and mesh_node.is_visible_in_tree():
			mesh_node.create_trimesh_collision()
	for i in range(3):
		await get_tree().physics_frame


func _the_blind_arc_is_held(view: VehicleView, geometry: Dictionary, seat: int) -> void:
	var mount: int = Sim.mount_of_seat(BATTLESHIP, seat)
	var gun: Dictionary = Sim.gun_of(BATTLESHIP, mount)
	var rest: float = (gun.get("rest", Vector2.ZERO) as Vector2).x
	var span: float = float(gun.get("yaw_span", 0.0))
	var eye: Vector3 = _eye_of(geometry, seat)
	var space: PhysicsDirectSpaceState3D = view.get_world_3d().direct_space_state
	var ship: Transform3D = view.global_transform
	var blind: Array[int] = []
	var arc: int = 0
	var by: Dictionary = {}
	for degree in range(360):
		var bearing: float = deg_to_rad(float(degree))
		if absf(angle_difference(bearing, rest)) > span:
			continue
		arc += 1
		var along := Vector3(-sin(bearing), 0.0, -cos(bearing))
		for high in [UPPERWORKS_M, 0.0]:
			var far := Vector3(eye.x, high, eye.z) + along * REACH_M
			var from: Vector3 = ship * eye
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from,
				from + (ship * far - from).normalized() * OWN_SHIP_M))
			if not hit.is_empty():
				blind.append(degree)
				var what: String = str((hit["collider"] as Node).get_parent().name)
				by[what] = int(by.get(what, 0)) + 1
				break
	var most: int = MOUNT_0_MOST_BLIND_DEG if mount == 0 else MOUNT_1_MOST_BLIND_DEG
	_check("from_seat_%d_turret_%d_s_gunner_is_blind_on_at_most_%d_degrees_of_its_arc" % [seat, mount, most],
		arc > 250 and blind.size() <= most,
		"blind on %d of %d degrees %s, by %s" % [blind.size(), arc, _spans(blind), by])


## PRINTED, NOT CHECKED: along each helm eye's own fore-and-aft line, the nearest sea point ahead past which the sea is in
## sight to 3 km.
func _the_pilot_house_sees_the_sea_ahead(view: VehicleView, geometry: Dictionary) -> void:
	var space: PhysicsDirectSpaceState3D = view.get_world_3d().direct_space_state
	var ship: Transform3D = view.global_transform
	var stem: float = -(geometry.get("extents", Vector3.ONE) as Vector3).z
	for seat in [0, 1]:
		var eye: Vector3 = _eye_of(geometry, seat)
		var nearest: float = -1.0
		var blocked: String = "nothing"
		for step in range(3000, 0, -1):
			var from: Vector3 = ship * eye
			var to: Vector3 = ship * Vector3(eye.x, 0.0, eye.z - float(step))
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from,
				from + (to - from).normalized() * minf(OWN_SHIP_M, (to - from).length())))
			if not hit.is_empty() and (ship.affine_inverse() * (hit["position"] as Vector3)).y > 0.5:
				blocked = "%s at %s" % [(hit["collider"] as Node).get_parent().name, ship.affine_inverse() * (hit["position"] as Vector3)]
				break
			nearest = float(step)
		print("[turret_seats] measure: from helm seat %d (eye %s) the sea is in sight from %.0f m ahead of the eye (%.0f m past the stem); nearer, %s"
			% [seat, eye, nearest, nearest - (eye.z - stem), blocked])


## ---- reading --------------------------------------------------------------------------------------------------------

static func _spans(degrees: Array[int]) -> String:
	if degrees.is_empty():
		return "[]"
	var out: PackedStringArray = []
	var start: int = degrees[0]
	var last: int = degrees[0]
	for i in range(1, degrees.size() + 1):
		if i < degrees.size() and degrees[i] == last + 1:
			last = degrees[i]
			continue
		out.append("%d..%d" % [start, last] if last != start else "%d" % start)
		if i < degrees.size():
			start = degrees[i]
			last = degrees[i]
	return "[" + ", ".join(out) + "]"


static func _under(node: Node, type_name: String) -> bool:
	var at: Node = node
	while at != null:
		var script: Script = at.get_script() as Script
		if at.get_class() == type_name or (script != null and script.get_global_name() == type_name):
			return true
		at = at.get_parent()
	return false


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
