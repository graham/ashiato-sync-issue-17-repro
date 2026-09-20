extends Node3D
class_name MonitorYard
## EVERY FIREBOAT MONITOR'S STREAM, DRAWN BY EVERY MACHINE FROM WHAT EVERY MACHINE ALREADY HAS.
##
## PURELY A PICTURE, as `ContrailYard` is. Nothing about the water is on the wire: the mount's aim is already
## replicated on `CraftSystems` and whether the pump is open is one bit a mount on the same component, so each machine
## works out the same arc from the same numbers and there is nothing to send and nothing to disagree about.
##
## THROWN ONCE AND FLOWN BY THE GPU, which is `SprayYard`'s decision and is what makes a hundred-metre stream nearly
## free. The processor writes ONE instance per flowing monitor every `SAMPLE_EVERY` -- the two ends' launch points,
## their launch times and the launch velocity -- and never touches it again. `water_jet.gdshader` works out where the
## water has got to from each pixel's own age, in closed form.
##
## AND THAT IS WHY THE STREAM WHIPS WHEN THE MONITOR IS TRAINED. Water already thrown keeps the velocity it left with,
## so swinging the nozzle sweeps a curve through the air instead of snapping the whole arc across like a laser. It is
## the most recognisable thing about a monitor being worked and it falls out of the architecture rather than being
## animated. An arc recomputed each frame from the current aim -- which was the obvious first design -- could not do
## it at all, and would also have cost a transform write per segment per frame.
##
## THE WATER LEAVES AT THE NOZZLE THE MODEL DRAWS, not near it: the muzzle is `Fireboat.muzzle_at` through the mount's
## own aim, which is the same point the barrel ends at. A stream starting at the mount's origin would come out of the
## middle of the swivel, which is the trap `Gun::barrel` exists to stop for a shell.
##
## AND IT IS THROWN FROM A MOVING BOAT, so her own velocity is added to it. A fireboat working alongside at four knots
## lays her water slightly astern of where the nozzle points, which is both true and free.
##
## WHO HAS MONITORS IS ASKED OF THE SIMULATION (`Sim.gun_of(kind, mount)["water"]`), never of a list of kinds here.

const SHADER: Shader = preload("res://world/shaders/water_jet.gdshader")
## How many segments the whole world's streams share. Three monitors at `SAMPLE_EVERY` recycle one after about seven
## seconds, which is longer than `LIFE`, so nothing is overwritten while it is still in the air.
const SEGMENTS: int = 512
## How often a parcel leaves the nozzle. At 49 m/s that puts them 2.0 m apart, which is under a tenth of the stream's
## own width by the time it is breaking up.
const SAMPLE_EVERY: float = 1.0 / 25.0
## How long a parcel is drawn for. A stream thrown to its full reach is in the air about 3.5 s.
const LIFE: float = 5.0
## LINEAR DRAG, per second, and the ONE PLACE it is written: the shader is handed this rather than carrying its own,
## because a stream drawn with one drag and a fire doused at a point worked out with another is two answers about
## where the water went. Solved against the PUBLISHED 320 ft horizontal throw; see `craft/fireboat/sources.md`.
const DRAG: float = 0.3389
const GRAVITY: float = 9.81

var _missiles: MissileYard = null
var _jets: MultiMeshInstance3D = null
var _material: ShaderMaterial = null
var _next: int = 0
var _laid: int = 0
## Each monitor being followed: "entity:mount" -> {"at": Vector3, "when": float}, the last parcel's launch.
var _throwing: Dictionary = {}
## Which kinds have water mounts, worked out once. kind -> Array of mount indices.
var _mounts: Dictionary = {}


## WEAR THE MISSILE YARD'S CLOCK, as `ContrailYard` does: the ends are stamped on the processor, so their ages have to
## be measured on the clock they were stamped with. Handed by the level before this is added.
func follow(missiles: MissileYard) -> void:
	_missiles = missiles


func _ready() -> void:
	_build_the_jets()
	var finish: Node = get_node_or_null("/root/Finish")
	if finish != null:
		finish.connect("changed", _wear)
	_wear(false if finish == null else bool(finish.call("is_fine")))


## ONE FRAME. `views` is the level's entity -> VehicleView, every one already placed this frame.
func lay(views: Dictionary) -> void:
	if _missiles == null or _material == null:
		return
	var now: float = _missiles.clock()
	_material.set_shader_parameter("now", now)
	for entity in views:
		var view: VehicleView = views[entity]
		var mounts: Array = _mounts_for(view.kind)
		if mounts.is_empty():
			continue
		var flowing: Array = _flowing(int(entity))
		for mount in mounts:
			var key: String = "%d:%d" % [int(entity), int(mount)]
			if mount >= flowing.size() or not bool(flowing[mount]):
				# THE PUMP IS SHUT. The record goes, so that when it opens again the first segment is not drawn from
				# wherever the nozzle was pointing minutes ago -- a single quad stretched across the harbour.
				_throwing.erase(key)
				continue
			var record: Dictionary = _throwing.get(key, {})
			var nozzle: Dictionary = _nozzle_of(view, int(entity), int(mount))
			if nozzle.is_empty():
				continue
			if record.has("at") and now - float(record["when"]) >= SAMPLE_EVERY:
				_set_segment(_take_a_segment(), record["at"] as Vector3, float(record["when"]),
					nozzle["at"] as Vector3, now, nozzle["velocity"] as Vector3, float(mount))
			elif record.has("at"):
				continue
			_throwing[key] = {"at": nozzle["at"], "when": now}
	# A BOAT THAT WENT AWAY: its water stays in the air and falls, as a contrail stays where it was laid.
	if _throwing.size() > views.size() * 3:
		for key in _throwing.keys():
			if not views.has(int(String(key).split(":")[0])):
				_throwing.erase(key)


## WHERE THE WATER LEAVES THIS MONITOR AND HOW FAST, in the world: `{"at", "velocity"}`, or {} if it cannot be asked.
##
## WORKED OUT FROM THE REPLICATED AIM AND THE SIMULATION'S OWN TABLE, never from the drawn node: the mount's place is
## `gun_of`'s, the nozzle's place along it is the model's `muzzle_at`, and the aim is `CraftSystems`. So every machine
## gets the same answer from the same numbers -- which is the whole reason the water needs no wire of its own.
func _nozzle_of(view: VehicleView, entity: int, mount: int) -> Dictionary:
	if Sim.client == null:
		return {}
	# `craft_systems`, NOT `craft_controls`. They are two different dictionaries and the names do not say so:
	# `craft_controls` is the LEVERS (throttle, flaps, gear) and `craft_systems` is the turrets, the lights and the
	# flags. Asking the wrong one returned a dictionary with no `turrets` and no `monitors_flowing` in it, the yard
	# drew nothing, and the picture came back with a burning rig and a fireboat doing nothing -- with no error
	# anywhere, because a missing key and a shut pump look identical through `get(..., [])`.
	var systems: Dictionary = Sim.client.craft_systems(entity)
	var aims: Array = systems.get("turrets", []) as Array
	if mount >= aims.size():
		return {}
	var aim: Vector2 = aims[mount]
	var gun: Dictionary = Sim.gun_of(view.kind, mount)
	var barrel: float = float(gun.get("barrel", 1.6))
	var turn := Basis(Vector3.UP, aim.x) * Basis(Vector3.RIGHT, aim.y)
	var local: Vector3 = (gun.get("at", Vector3.ZERO) as Vector3) + turn * Fireboat.muzzle_at(barrel)
	var along: Vector3 = view.global_transform.basis * (turn * Vector3(0.0, 0.0, -1.0))
	# HER OWN VELOCITY IS ADDED, so a boat working alongside lays her water slightly astern of where she points.
	var carried: Vector3 = (Sim.current.get(entity, {}) as Dictionary).get("velocity", Vector3.ZERO)
	return {"at": view.global_transform * local,
		"velocity": along.normalized() * float(gun.get("muzzle", 49.0)) + carried}


## WHICH OF THIS CRAFT'S MONITORS ARE PUMPING, a bool a mount. One bit each on `CraftSystems::flags`, which is the
## only thing about a stream that travels.
func _flowing(entity: int) -> Array:
	if Sim.client == null:
		return []
	return Sim.client.craft_systems(entity).get("monitors_flowing", []) as Array


## WHICH MOUNTS ON THIS KIND THROW WATER, asked of the simulation once. A kind with none is never looked at again.
func _mounts_for(kind: int) -> Array:
	if not _mounts.has(kind):
		var found: Array = []
		for mount in range(VehicleView.MAX_TURRETS):
			var gun: Dictionary = Sim.gun_of(kind, mount)
			if bool(gun.get("fitted", false)) and bool(gun.get("water", false)):
				found.append(mount)
		_mounts[kind] = found
	return _mounts[kind]


## ---- the segments -----------------------------------------------------------------

func _take_a_segment() -> int:
	var index: int = _next
	_next = (_next + 1) % SEGMENTS
	if _laid < SEGMENTS:
		_laid += 1
		_jets.multimesh.visible_instance_count = _laid
	return index


## ONE SEGMENT, written once and never touched again.
##
## THE LAUNCH VELOCITY IS SHARED BY THE TWO ENDS, and that is the one approximation in the whole stream. It is exact
## while the monitor is still; while it trains at its 30 deg/s the two ends differ by 1.2 degrees over a sample. It
## buys an ORTHONORMAL basis, which `billboard.gdshaderinc` requires -- packing a second velocity into the basis
## columns would make them non-invertible and `BILLBOARD_LOCAL_OF` would return rubbish.
func _set_segment(index: int, from: Vector3, from_when: float, to: Vector3, to_when: float,
		velocity: Vector3, mount: float) -> void:
	_jets.multimesh.set_instance_transform(index,
		Transform3D(MissileYard.segment_basis(to - from), (from + to) * 0.5))
	_jets.multimesh.set_instance_custom_data(index, Color(from_when, to_when, mount * 0.37, 1.0))
	# THE LAUNCH VELOCITY RIDES IN THE INSTANCE COLOUR, which is the only three floats left once the transform is
	# spent on the two launch points. It is metres a second, not a colour, and nothing else reads it.
	_jets.multimesh.set_instance_color(index, Color(velocity.x, velocity.y, velocity.z, 1.0))


func _build_the_jets() -> void:
	var strip := QuadMesh.new()
	strip.size = Vector2(1.0, 1.0)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	# BEFORE THE COUNT: a MultiMesh will not start carrying custom data or colours once it has instances.
	many.use_custom_data = true
	many.use_colors = true
	many.mesh = strip
	many.instance_count = SEGMENTS
	for i in range(SEGMENTS):
		many.set_instance_transform(i, MissileYard.NOWHERE)
		many.set_instance_custom_data(i, Color(-100000.0, -100000.0, 0.0, 0.0))
	many.visible_instance_count = 0
	_jets = MultiMeshInstance3D.new()
	_jets.name = "Monitors"
	_jets.multimesh = many
	_jets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# THE WHOLE WORLD: an instance's transform is its LAUNCH point and the water flies a hundred metres from it, so a
	# box round the launch points would cull a stream the moment the nozzle left the frame.
	_jets.custom_aabb = TrailTuning.culling_box()
	add_child(_jets)


func _wear(_fine: bool) -> void:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_jets.material_override = _material
	# ONE PLACE FOR THE DRAG AND THE GRAVITY: the yard's, handed to the shader. See `DRAG`.
	_material.set_shader_parameter("drag", DRAG)
	_material.set_shader_parameter("gravity", GRAVITY)
	_material.set_shader_parameter("life", LIFE)
	_material.set_shader_parameter("sea_level", Terrain.SEA_LEVEL)


## THE LIGHT THE WATER IS DRAWN IN, as a cloud is lit: the contrails' answer, because spray is white as a cloud is
## (`WakeYard` and `SprayYard` both take it from there).
func show_daylight(look: Dictionary) -> void:
	if _jets == null:
		return
	var light: Vector3 = ContrailYard.light_at(look)
	_jets.set_instance_shader_parameter("light", light)
