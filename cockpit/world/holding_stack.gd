extends Node3D
class_name HoldingStack
## A LAYERED RING OF NETWORKED AIRCRAFT, owned by the authoritative simulation. The
## clipboard asks for a count; this object converges in bounded batches so 200 native
## bodies and replication records are never made in one frame.

signal said(words: String)

## HOW MANY AEROPLANES THE STACK WILL HOLD. Raised from 200 on 2026-09-17 (lane/stress) because the user's question --
## how many craft this game carries at 80 ms -- cannot be answered from below the answer, and the 200-craft rung was
## already comfortable.
const MOST := 600
## HOW MANY SLOTS THERE ARE ROUND THE RING, and it is NOT `MOST`. It was, and that is the trap: the angle of every
## aeroplane was `TAU * index / MOST`, so raising the cap would have moved all 200 of the existing ones and with them
## every measurement in agents.md taken on them. Keeping the ring at the old cap means indices 0..199 keep their exact
## angle, layer and altitude, and the aeroplanes past 200 go in bands ABOVE them instead (see `_spawn_one`).
const RING := 200
const BATCH := 10
## HOW MANY ALTITUDE LAYERS ONE LAP OF THE RING USES. A lap of `RING` aeroplanes fills these ten; the next lap takes
## the ten above it. So each altitude band still holds `RING / LAYERS` = 20 aeroplanes, 18 degrees apart on the ring,
## and a raised cap adds no horizontal crowding whatever.
const LAYERS := 10
const CLEARANCE := 300.0
const RADIUS := 2800.0
## The altitude-hold gate measured 0.0 m worst error over a minute. Keep the measured
## value explicit: spacing is three errors plus one complete wingspan.
const WORST_ALTITUDE_ERROR := 0.0

var _world: Object = null
var _target := 0
var _entities: Array[int] = []
var _heights: Dictionary = {}
var _base := 800.0
var _spacing := 30.0
var _serial := 0


func setup(world: Object, base_override: float = NAN) -> void:
	_world = world
	var geometry: Dictionary = world.kind_geometry(Sim.Kind.PLANE)
	var half: Vector3 = geometry.get("extents", Vector3(8.0, 2.0, 6.0))
	_spacing = maxf(20.0, 3.0 * WORST_ALTITUDE_ERROR + half.x * 2.0)
	# One measured query over the entire playable island. Every ring layer then clears its
	# highest point, regardless of which horizontal waypoint an autopilot chooses later.
	_base = base_override if not is_nan(base_override) \
		else Terrain.highest_near(Vector3.ZERO, 7200.0) + CLEARANCE
	var wire: Dictionary = world.wire_range()
	var top := _base + _spacing * float(LAYERS - 1)
	if top > float(wire.get("height_max", top)):
		push_warning("[holding stack] top %.0f m exceeds the wire height %.0f m; lowering the base" % [
			top, float(wire.get("height_max", top))])
		_base -= top - float(wire.get("height_max", top))


func set_count(wanted: int) -> void:
	if wanted < 0 or wanted > MOST:
		push_warning("[holding stack] %d planes requested; clamped to 0..%d" % [wanted, MOST])
	_target = clampi(wanted, 0, MOST)


func target_count() -> int:
	return _target


func count() -> int:
	_prune_gone()
	return _entities.size()


func entities() -> Array[int]:
	_prune_gone()
	return _entities.duplicate()


func assigned_altitude(entity: int) -> float:
	return float(_heights.get(entity, NAN))


func layer_spacing() -> float:
	return _spacing


func base_altitude() -> float:
	return _base


func _physics_process(_delta: float) -> void:
	step()


func step() -> void:
	if _world == null:
		return
	_prune_gone()
	var work := BATCH
	while _entities.size() < _target and work > 0:
		_spawn_one()
		work -= 1
	while _entities.size() > _target and work > 0:
		if not _retire_one():
			break
		work -= 1


## WHERE THE NEXT AEROPLANE GOES. Its angle round the ring and its altitude layer, from its serial number alone, so
## that the first `RING` of them are exactly where they have always been and the rest lap upward. Static and pure
## because the suite holds it against the old arithmetic without standing a stack up.
static func slot_of(index: int) -> Dictionary:
	var lap := index / RING
	var place := index % RING
	return {"angle": TAU * float(place) / float(RING), "layer": place % LAYERS + LAYERS * lap}


func _spawn_one() -> void:
	var index := _serial
	_serial += 1
	var slot := slot_of(index)
	var layer: int = int(slot["layer"])
	var angle: float = float(slot["angle"])
	var altitude := _base + float(layer) * _spacing
	# AND NOT THROUGH THE CEILING. `setup` lowers the base so the FIRST lap clears the wire, and is deliberately left
	# alone -- working the ceiling out from `MOST` instead would lower the base for every existing run and move the
	# measured 200-craft rung. A lap that would fly above the wire is refused in words instead, like every other
	# refusal here, because an aeroplane the wire cannot carry is one no client would ever see.
	var ceiling: float = float((_world.wire_range() as Dictionary).get("height_max", altitude))
	if altitude > ceiling:
		_target = _entities.size()
		said.emit("The stack is as tall as the wire allows: %d planes, %.0f m." % [_entities.size(), ceiling])
		return
	var at := Vector3(cos(angle) * RADIUS, altitude, sin(angle) * RADIUS)
	var yaw := angle + PI * 0.5
	var velocity := Terrain.nose_from_yaw(yaw) * Terrain.cruise_for(Sim.Kind.PLANE)
	var entity := int(_world.spawn_ai_vehicle(Sim.Kind.PLANE, at, yaw, velocity))
	if entity == 0:
		_target = _entities.size()
		said.emit("The simulation refused another plane at %d." % _entities.size())
		return
	if not bool(_world.set_ai_altitude(entity, altitude)):
		_world.despawn_vehicle(entity)
		_target = _entities.size()
		said.emit("The simulation refused the plane's altitude layer.")
		return
	_entities.append(entity)
	_heights[entity] = altitude


func _retire_one() -> bool:
	for i in range(_entities.size() - 1, -1, -1):
		var entity := _entities[i]
		if bool(_world.despawn_vehicle(entity)):
			_entities.remove_at(i)
			_heights.erase(entity)
			return true
		if (_world.vehicle_state(entity) as Dictionary).is_empty():
			_entities.remove_at(i)
			_heights.erase(entity)
			return true
	said.emit("Planes with somebody aboard stay in the stack until their seats are empty.")
	_target = _entities.size()
	return false


func _prune_gone() -> void:
	if _world == null:
		return
	for i in range(_entities.size() - 1, -1, -1):
		var entity := _entities[i]
		if (_world.vehicle_state(entity) as Dictionary).is_empty():
			_entities.remove_at(i)
			_heights.erase(entity)
