extends Node3D
class_name MissileYard
## EVERY MISSILE IN THE AIR, ITS MOTOR AND ITS TRAIL -- AND EVERY MACHINE DRAWS THEM ALL.
##
## A MISSILE IS NOT A SHELL, and that is the one decision behind this file. A shell's whole future is its birth
## record, so `ShotYard` integrates the flight itself. A guided missile's future is decided by a target that moves on
## somebody else's stick, so nobody but the server can know it: its position comes over the wire every tick, the way
## an aircraft's does, and this draws it where the wire says, wound forward by how late this machine is.
##
## FOUR THINGS IT HAS TO GET RIGHT:
##
##   IT STARTS ON THE RAIL. On the launcher's own machine the aeroplane is predicted ahead and the missile is
##   interpolated behind, so the first state of a new missile is about thirty metres behind the pylon it left. Drawn
##   there, every launch would look like the missile falling out of the back of the aeroplane. So for its first
##   `BLEND_S` it is drawn from the pylon -- which moves with the aeroplane -- to where the wire says it is.
##   The pylon comes from the launch cue, or failing that from the pilot list (`find_rail`), for a machine that joined
##   after the launch and has no cue to claim. For a morning sync lost the launch cue on a pilot's own aeroplane and
##   the fallback carried every launch there, until ashiato 5e14119; tests/missile_cues checks the cue carries it now.
##
##   THE MOTOR IS THE SIMULATION'S. `motor` comes from the replicated `age` and the missile table, so the plume goes
##   out on the same tick on every machine. This never decides a motor is burning.
##
##   THE TRAIL COSTS NOTHING ONCE IT IS LAID. All the smoke in the sky is ONE MultiMesh: a segment is written when a
##   missile has flown `SAMPLE_EVERY` seconds further and never touched again, and how far each one has spread and
##   faded is worked out on the GPU from the time its ends were laid. What the processor pays a frame is the one
##   segment still growing behind each burning motor.
##
##   IT ENDS ONCE. A missile's end is on the wire as a state that lingers a few ticks and as a cue; whichever arrives
##   first sets the burst off, and the other finds it already done.
##
## Two finishes, like everything else that draws the sky: see `missile_motor` and `contrail` in `world/shaders/`, and
## `Finish` for who decides.
##
## THE TRAILS ARE ALSO WORN BY `ContrailYard`, shorter: an aircraft's contrail is this yard's two trail materials on a
## MultiMesh of its own, stamped on this yard's clock. How long a trail lasts is `TrailTuning`'s, written onto both
## materials once here.

const MOTOR_PLAIN: Shader = preload("res://world/shaders/missile_motor.gdshader")
const MOTOR_FINE: Shader = preload("res://world/shaders/missile_motor_fine.gdshader")
const TRAIL_PLAIN: Shader = preload("res://world/shaders/contrail.gdshader")
const TRAIL_FINE: Shader = preload("res://world/shaders/contrail_fine.gdshader")

## How many trail segments the whole sky holds. The oldest is taken for the newest when they run out, and at one
## every `SAMPLE_EVERY` that is forty seconds of burning motors between them -- longer than any trail lasts.
const SEGMENTS: int = 512
## How often a burning motor lays a segment, in seconds.
const SAMPLE_EVERY: float = 0.08
## How long a new missile is drawn coming off its rail, in seconds. See the note at the top.
const BLEND_S: float = 0.35
## How far from a launch's pylon a new missile may first appear and still be taken as that launch's, in metres.
const CLAIM_WITHIN: float = 150.0
## How long a launch waits to be claimed by a missile, in seconds.
const CLAIM_S: float = 3.0
## The body: how long, and how thick.
const LENGTH: float = 3.2
const RADIUS: float = 0.09
## The plume behind the nozzle at full burn, in metres, before the shader's floor on its size.
const PLUME: float = 2.6
const PLUME_WIDE: float = 0.6
## A proximity burst in the air, beside the shell's surfaces. See `Ammunition.SURFACE`.
const FUSED: int = 5

## WHERE A LAUNCHER'S PYLON IS, for a missile that arrives with no launch cue to claim -- a machine that joined after
## the launch, or a cue that has not come yet. Set by the level: `(client: int, pylon: int) -> Dictionary` with
## "rail" (the launching vehicle's node) and "pylon" (a point in its frame), or empty.
var find_rail: Callable = Callable()

var _live: Dictionary = {}
var _claims: Array = []
## THE YARD'S OWN CLOCK, in seconds, which is what a trail segment is stamped with and what the trail shaders measure
## age against. Not TIME: that is the renderer's, and a stamp from one clock measured on another is an age that drifts.
var _clock: float = 0.0
var _fine: bool = false
var _motor_plain: ShaderMaterial = null
var _motor_fine: ShaderMaterial = null
var _trail_plain: ShaderMaterial = null
var _trail_fine: ShaderMaterial = null
var _trail: MultiMeshInstance3D = null
var _next_segment: int = 0
var _laid: int = 0
var _body_mesh: CylinderMesh = null
var _body_paint: StandardMaterial3D = null
var _plume_quad: QuadMesh = null
## WHERE EVERY MISSILE'S EXPLOSION IS DRAWN: the level's yard, handed in before this is added, or one of its own.
var bursts: BurstYard = null
## The missile types already said to have no fuse, so each is said once.
var _said_no_fuse: Dictionary = {}


func _ready() -> void:
	_motor_plain = ShaderMaterial.new()
	_motor_plain.shader = MOTOR_PLAIN
	_motor_fine = ShaderMaterial.new()
	_motor_fine.shader = MOTOR_FINE
	_trail_plain = ShaderMaterial.new()
	_trail_plain.shader = TRAIL_PLAIN
	_trail_fine = ShaderMaterial.new()
	_trail_fine.shader = TRAIL_FINE
	# THE TRAIL'S LIFE, ONCE, from the one place it is written: the shaders keep no default for it. See TrailTuning.
	_trail_plain.set_shader_parameter("life", TrailTuning.missile_life(false))
	_trail_fine.set_shader_parameter("life", TrailTuning.missile_life(true))
	_body_mesh = CylinderMesh.new()
	_body_mesh.top_radius = RADIUS
	_body_mesh.bottom_radius = RADIUS
	_body_mesh.height = LENGTH
	_body_mesh.radial_segments = 8
	_body_mesh.rings = 1
	_body_paint = StandardMaterial3D.new()
	_body_paint.albedo_color = Color(0.82, 0.83, 0.80)
	_body_paint.roughness = 0.6
	# STANDING ON THE NOZZLE, so the quad's Y runs 0..1 from the nozzle to the tip of the plume.
	_plume_quad = QuadMesh.new()
	_plume_quad.size = Vector2(1.0, 1.0)
	_plume_quad.center_offset = Vector3(0.0, 0.5, 0.0)
	_build_the_trail()
	if bursts == null:
		bursts = BurstYard.new()
		bursts.name = "Bursts"
		add_child(bursts)
	var finish: Node = get_node_or_null("/root/Finish")
	if finish != null:
		finish.connect("changed", _wear)
		_fine = bool(finish.call("is_fine"))
	_trail.material_override = _trail_fine if _fine else _trail_plain


## ONE FRAME OF EVERY MISSILE. `missiles` is `Sim.missiles`, `eye` is where the camera is, `late` is how far behind the
## server this machine is drawing, and `since_tick` is how far this frame is past the tick the states were captured
## on -- together, how far to wind each missile forward along its own velocity.
func draw_missiles(missiles: Array, _eye: Vector3, delta: float, late: float = 0.0,
		since_tick: float = 0.0) -> void:
	_clock += delta
	# BOTH, so a finish changed in the middle of a trail finds it the age it is rather than the age it was.
	_trail_plain.set_shader_parameter("now", _clock)
	_trail_fine.set_shader_parameter("now", _clock)
	var seen: Dictionary = {}
	for row in missiles:
		var missile: Dictionary = row
		var entity: int = int(missile.get("entity", 0))
		seen[entity] = true
		if bool(missile.get("flying", false)):
			# THE ROW'S OWN LATENESS when it carries one: the simulation works it out from the link's own timing,
			# so it cannot drift from what the wire is actually costing. `late` is only the fallback.
			var behind: float = float(missile.get("late", late))
			_fly(entity, missile, delta, maxf(behind + since_tick, 0.0))
		else:
			_end(entity, int(missile.get("surface", Ammunition.SPENT)),
				missile.get("position", Vector3.ZERO) as Vector3, int(missile.get("type", -1)))
	# A MISSILE THAT SIMPLY WENT AWAY, retired without this machine seeing it end: taken away, and no burst invented.
	for entity in _live.keys():
		if not seen.has(entity):
			_forget(entity)
	for i in range(_claims.size() - 1, -1, -1):
		if _clock - float((_claims[i] as Dictionary)["at"]) > CLAIM_S:
			_claims.remove_at(i)


## A MISSILE LEFT A RAIL, from the launch cue. `rail` is the launching vehicle's node, `pylon` the point in its frame
## the missile left from, and `late` how long ago that was on this machine's clock. The next new missile of that
## type near that pylon is drawn coming off it. See `pylon_of` for turning the cue's number into a point.
func launched(rail: Node3D, pylon: Vector3, type: int, late: float = 0.0) -> void:
	_claims.append({"rail": rail, "pylon": pylon, "type": type, "at": _clock - maxf(late, 0.0)})


## A MISSILE ENDED, from the end cue. Its last drawn place is where it went off.
func ended(entity: int, surface: int) -> void:
	var record: Dictionary = _live.get(entity, {})
	if record.is_empty():
		return
	_end(entity, surface, record.get("at", Vector3.ZERO) as Vector3)


## WHERE PYLON NUMBER `pylon` IS, in the launching vehicle's frame: the schema's own top-level `pylons`, indexed by
## the number the cue, `missile_states.pylon` and the bits of `stores` all use. READ, NOT COUNTED: counting through
## the stations gives the right number only while every station's rails are contiguous and in order, which a later
## craft need not keep. Vector3.ZERO for a number the schema does not have.
static func pylon_of(schema: Dictionary, pylon: int) -> Vector3:
	var every: Array = schema.get("pylons", [])
	return every[pylon] as Vector3 if pylon >= 0 and pylon < every.size() else Vector3.ZERO


func _fly(entity: int, missile: Dictionary, delta: float, ahead: float) -> void:
	var truth: Vector3 = (missile.get("position", Vector3.ZERO) as Vector3) \
		+ (missile.get("velocity", Vector3.ZERO) as Vector3) * ahead
	var record: Dictionary = _live.get(entity, {})
	if record.is_empty() or record.get("pivot") == null:
		record = _begin(entity, missile, truth)
	var shown: float = float(record["shown"]) + delta
	record["shown"] = shown
	# A LAUNCH CUE THAT CAME A TICK AFTER THE MISSILE is still worth claiming while the missile is on its way off.
	if record.get("rail") == null and shown < BLEND_S:
		_claim_a_rail(record, missile, truth)
	var at: Vector3 = truth
	var rail: Variant = record.get("rail")
	if rail != null and is_instance_valid(rail) and shown < BLEND_S:
		var from: Vector3 = (rail as Node3D).global_transform * (record["pylon"] as Vector3)
		at = from.lerp(truth, smoothstep(0.0, BLEND_S, shown))
	var forward: Vector3 = missile.get("forward", Vector3.ZERO) as Vector3
	if forward.length_squared() < 0.0001:
		forward = record["forward"] as Vector3
	record["forward"] = forward
	var pivot: Node3D = record["pivot"]
	pivot.global_transform = Transform3D(Basis.looking_at(forward, _up_for(forward)), at)
	var motor: MeshInstance3D = record["motor"]
	var burning: bool = bool(missile.get("motor", false))
	motor.visible = burning
	if burning:
		var left: float = float(missile.get("burn_left", 0.0))
		var age: float = float(missile.get("age", 0.0))
		motor.set_instance_shader_parameter("burn", clampf(left / maxf(left + age, 0.001), 0.0, 1.0))
	_lay_the_trail(record, at + forward * (-LENGTH * 0.5), burning)
	record["at"] = at


func _begin(entity: int, missile: Dictionary, truth: Vector3) -> Dictionary:
	var pivot := Node3D.new()
	pivot.name = "Missile%d" % entity
	add_child(pivot)
	var body := MeshInstance3D.new()
	body.mesh = _body_mesh
	body.material_override = _body_paint
	# A CYLINDER STANDS ON Y; a missile lies along its own -Z.
	body.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	pivot.add_child(body)
	var motor := MeshInstance3D.new()
	motor.name = "Motor"
	motor.mesh = _plume_quad
	motor.material_override = _motor_fine if _fine else _motor_plain
	motor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# THE SHADER GROWS THE PLUME PAST THE QUAD at range, so the box the renderer culls by has to allow for it.
	motor.extra_cull_margin = 64.0
	# AT THE TAIL, its Y column back along the missile as long as the plume and its X column across it.
	motor.transform = Transform3D(Basis(Vector3(PLUME_WIDE, 0.0, 0.0), Vector3(0.0, 0.0, PLUME),
		Vector3(0.0, 1.0, 0.0)), Vector3(0.0, 0.0, LENGTH * 0.5))
	pivot.add_child(motor)
	var seed: float = float(entity % 97) * 0.113
	motor.set_instance_shader_parameter("seed", seed)
	motor.visible = false
	var record: Dictionary = {
		"pivot": pivot, "motor": motor, "seed": seed, "shown": 0.0, "ended": false,
		"forward": missile.get("forward", Vector3.FORWARD) as Vector3, "at": truth,
		"rail": null, "pylon": Vector3.ZERO,
		# Which missile it is, so an end cue -- which carries only the surface -- still sizes its burst from the type's fuse.
		"type": int(missile.get("type", -1)),
		# The trail being laid: the segment still growing, and where and when its older end was put down. A negative
		# time is no trail running.
		"head": -1, "tail_at": truth, "tail_laid": -1.0,
	}
	_live[entity] = record
	_claim_a_rail(record, missile, truth)
	# AND IT IS HEARD LEAVING. A rocket motor lighting is a much bigger noise than a gun.
	VehicleSound.report(self, truth, 3.0)
	return record


## WHICH RAIL THIS MISSILE CAME OFF: the nearest unclaimed launch of its type, and failing that whatever the level can
## work out from who launched it and which pylon it names.
func _claim_a_rail(record: Dictionary, missile: Dictionary, at: Vector3) -> void:
	var type: int = int(missile.get("type", -1))
	var best: int = -1
	var nearest: float = CLAIM_WITHIN
	for i in range(_claims.size()):
		var claim: Dictionary = _claims[i]
		var rail: Variant = claim["rail"]
		if rail == null or not is_instance_valid(rail) or int(claim["type"]) != type:
			continue
		var away: float = ((rail as Node3D).global_transform * (claim["pylon"] as Vector3)).distance_to(at)
		if away < nearest:
			nearest = away
			best = i
	if best >= 0:
		record["rail"] = (_claims[best] as Dictionary)["rail"]
		record["pylon"] = (_claims[best] as Dictionary)["pylon"]
		record["rail_from"] = "cue"
		_claims.remove_at(best)
		return
	if find_rail.is_valid() and missile.has("pylon") and missile.has("client"):
		var found: Dictionary = find_rail.call(int(missile["client"]), int(missile["pylon"]))
		var rail: Node3D = found.get("rail") as Node3D
		if rail != null and (rail.global_transform * (found.get("pylon", Vector3.ZERO) as Vector3)) \
				.distance_to(at) < CLAIM_WITHIN:
			record["rail"] = rail
			record["pylon"] = found.get("pylon", Vector3.ZERO)
			record["rail_from"] = "launcher"


## ---- the trail --------------------------------------------------------------------

## LAY THE TRAIL BEHIND A BURNING MOTOR. `nozzle` is where the smoke leaves this frame.
func _lay_the_trail(record: Dictionary, nozzle: Vector3, burning: bool) -> void:
	var laid: float = float(record["tail_laid"])
	if not burning:
		# THE MOTOR WENT OUT: the growing segment stays exactly as it was last drawn, and no more are laid.
		record["tail_laid"] = -1.0
		record["head"] = -1
		return
	if laid < 0.0:
		record["tail_at"] = nozzle
		record["tail_laid"] = _clock
		record["head"] = _take_a_segment()
		return
	var head: int = int(record["head"])
	_set_segment(head, record["tail_at"] as Vector3, laid, nozzle, _clock, float(record["seed"]))
	if _clock - laid >= SAMPLE_EVERY:
		# LEFT WHERE IT IS for good, and a new one starts from its end.
		record["tail_at"] = nozzle
		record["tail_laid"] = _clock
		record["head"] = _take_a_segment()


func _take_a_segment() -> int:
	var index: int = _next_segment
	_next_segment = (_next_segment + 1) % SEGMENTS
	_laid = mini(_laid + 1, SEGMENTS)
	_trail.multimesh.visible_instance_count = _laid
	# NOTHING UNTIL IT IS SET: a segment taken from the far end of the drawer may still hold an old trail.
	_trail.multimesh.set_instance_transform(index, NOWHERE)
	return index


## One segment, from its older end to its newer.
func _set_segment(index: int, from: Vector3, from_laid: float, to: Vector3, to_laid: float, seed: float) -> void:
	_trail.multimesh.set_instance_transform(index, Transform3D(segment_basis(to - from), (from + to) * 0.5))
	_trail.multimesh.set_instance_custom_data(index, Color(from_laid, to_laid, seed, 1.0))


## A TRAIL SEGMENT'S BASIS, here and in ContrailYard: X is the segment, and the only column the shaders read; Y and Z are
## small and square to X and to each other, so the basis can be INVERTED -- which contrail.gdshader does, to place a
## segment exactly on the double build (world/shaders/billboard.gdshaderinc). Until 2026-09-14 Y and Z were the world's,
## whatever X was: singular for a trail along Z, harmless while no shader inverted it, and the first time one did every
## contrail drew as shattered triangles. A segment of no length gets a tiny X, so it can be inverted too.
static func segment_basis(along: Vector3) -> Basis:
	var x: Vector3 = along if along.length_squared() > 1e-12 else Vector3(0.001, 0.0, 0.0)
	var unit: Vector3 = x.normalized()
	var square: Vector3 = unit.cross(Vector3.UP if absf(unit.y) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, square * 0.001, unit.cross(square).normalized() * 0.001)


## A collapsed segment laid long ago: no length and no age worth drawing. A millimetre each way rather than a zero column,
## for the reason in `segment_basis`; its custom data ages it past drawing, so what it would draw is never seen.
const NOWHERE := Transform3D(Basis(Vector3(0.001, 0.0, 0.0), Vector3(0.0, 0.001, 0.0), Vector3(0.0, 0.0, 0.001)),
	Vector3.ZERO)


func _build_the_trail() -> void:
	var strip := QuadMesh.new()
	strip.size = Vector2(1.0, 1.0)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = strip
	many.instance_count = SEGMENTS
	for i in range(SEGMENTS):
		many.set_instance_transform(i, NOWHERE)
		many.set_instance_custom_data(i, Color(-100000.0, -100000.0, 0.0, 0.0))
	many.visible_instance_count = 0
	_trail = MultiMeshInstance3D.new()
	_trail.name = "Trails"
	_trail.multimesh = many
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# THE WHOLE WORLD, worked out from the world: see `TrailTuning.culling_box`.
	_trail.custom_aabb = TrailTuning.culling_box()
	# ALL OF A MISSILE'S LIFE, written rather than left to the uniform's default, so `trail_lasts` reads a value.
	_trail.set_instance_shader_parameter("lasting", 1.0)
	add_child(_trail)


## ---- the end ----------------------------------------------------------------------

## `type` is the missile's row in the simulation's table, or -1 when the caller does not know it (an end cue): then the
## type this machine saw it fly with, and failing that the first row's -- a missile never seen, ending, still bursts.
func _end(entity: int, surface: int, at: Vector3, type: int = -1) -> void:
	var record: Dictionary = _live.get(entity, {})
	if record.is_empty():
		# NEVER SEEN FLYING, and ended: a machine that caught only the last ticks still sees the burst.
		record = {"pivot": null, "motor": null, "ended": false, "at": at, "head": -1, "tail_laid": -1.0, "type": type}
		_live[entity] = record
	if type < 0:
		type = int(record.get("type", -1))
	if bool(record["ended"]):
		return
	record["ended"] = true
	record["tail_laid"] = -1.0
	record["head"] = -1
	var pivot: Node3D = record.get("pivot") as Node3D
	if pivot != null:
		pivot.visible = false
	# A MISSILE THAT RAN OUT OF LIFE does not explode, for the reason `Ammunition.SPENT` gives about shells.
	if surface == Ammunition.FLYING or surface == Ammunition.SPENT:
		return
	# A BIG EXPLOSION, SIZED FROM THE WARHEAD'S FUSE -- the only radius a missile has in the simulation. See BurstTuning.
	# A type with no fuse draws nothing and says so once, rather than drawing a guessed size.
	var fuse: float = float(Sim.missile_type(maxi(type, 0)).get("fuse_m", 0.0))
	if fuse <= 0.0:
		if not _said_no_fuse.has(type):
			_said_no_fuse[type] = true
			print("[missiles] no fuse radius for missile type %d: no burst drawn" % type)
		return
	if bursts != null:
		# IN THE AIR the smoke is as thick as it comes; on something, as thick as that surface makes it.
		bursts.set_off(at, BurstTuning.fireball_for_fuse(fuse), surface != FUSED,
			1.0 if surface == FUSED else float(Ammunition.surface(surface).get("smoke", 1.0)), float(entity % 97) * 0.4)


func _forget(entity: int) -> void:
	var record: Dictionary = _live.get(entity, {})
	var pivot: Node3D = record.get("pivot") as Node3D
	if pivot != null:
		pivot.queue_free()
	_live.erase(entity)


static func _up_for(forward: Vector3) -> Vector3:
	return Vector3.RIGHT if absf(forward.normalized().y) > 0.98 else Vector3.UP


## ---- the finish -------------------------------------------------------------------

func _wear(fine: bool) -> void:
	_fine = fine
	_trail.material_override = _trail_fine if fine else _trail_plain
	for record in _live.values():
		var motor: MeshInstance3D = (record as Dictionary).get("motor") as MeshInstance3D
		if motor == null:
			continue
		motor.material_override = _motor_fine if fine else _motor_plain
		motor.set_instance_shader_parameter("seed", float((record as Dictionary).get("seed", 0.0)))


## ---- for the tests and the boards -------------------------------------------------

## How many missiles are being drawn in flight.
func in_the_air() -> int:
	var flying: int = 0
	for record in _live.values():
		if not bool((record as Dictionary).get("ended", false)):
			flying += 1
	return flying


## Whether this missile's motor is being drawn.
func is_burning(entity: int) -> bool:
	var motor: MeshInstance3D = (_live.get(entity, {}) as Dictionary).get("motor") as MeshInstance3D
	return motor != null and motor.visible


## Whether this missile was taken as coming off a rail -- a launch cue or its launcher's pylon -- for the tests.
func came_off_a_rail(entity: int) -> bool:
	return (_live.get(entity, {}) as Dictionary).get("rail") != null


## HOW its rail was found, for the tests: "cue" from a launch cue the level played, "launcher" from the pilot list when
## no cue had been, or "" for none. The difference is whether the level is playing its cues at all.
func rail_found_by(entity: int) -> String:
	return String((_live.get(entity, {}) as Dictionary).get("rail_from", ""))


## Where this missile is drawn this frame, or Vector3.INF.
func drawn_at(entity: int) -> Vector3:
	var record: Dictionary = _live.get(entity, {})
	return record.get("at", Vector3.INF) as Vector3 if not record.is_empty() else Vector3.INF


## How many trail segments have been laid, up to the drawer's size.
func trail_segments() -> int:
	return _laid


## What the trails and motors are wearing, read off the materials rather than off the tier.
func wears_fine() -> bool:
	return _trail.material_override == _trail_fine


## ---- for the contrails ------------------------------------------------------------

## The trail material for a finish, for `ContrailYard`, which wears the same two.
func trail_material(fine: bool) -> ShaderMaterial:
	return _trail_fine if fine else _trail_plain


## The yard's clock, which every trail segment in the sky is stamped on. See `_clock`.
func clock() -> float:
	return _clock


## HOW LONG A MISSILE'S TRAIL LASTS, in seconds, read off what it is drawn with: the worn material's `life` times the
## node's `lasting`.
func trail_lasts() -> float:
	var worn := _trail.material_override as ShaderMaterial
	if worn == null or worn.get_shader_parameter("life") == null:
		return 0.0
	return float(worn.get_shader_parameter("life")) * float(_trail.get_instance_shader_parameter("lasting"))
