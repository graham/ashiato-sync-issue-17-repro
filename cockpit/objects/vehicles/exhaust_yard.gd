extends Node3D
class_name ExhaustYard
## EVERY AIRCRAFT'S THRUST EXHAUST, AND WHAT IT DOES TO THE GROUND UNDER IT.
##
## Asked for on 2026-09-19 with the Harrier: "I'd like you to also try modelling a thrust 'smoke' on this model as
## well. We haven't done that before and it seems important for this model." Both halves of that were right. Nothing
## in this game drew an exhaust, a downwash or a ground wash before this, and it matters most on a Harrier, because in
## the hover four nozzles are blasting the ground.
##
## PURELY A PICTURE, drawn by every machine from what every machine already has. Nothing here is on the wire and
## nothing pushes: the strength comes off the REPLICATED command bus (`craft_controls(entity)`, which every machine
## holds for every entity, not just the one it is flying) and the pose comes off the view `FlightLevel` has just
## placed. So every viewer derives the same plume from the same numbers, there is nothing to send and nothing to
## disagree about -- `ContrailYard`'s decision exactly.
##
## ---------------------------------------------------------------------------------------------------------------
## IT IS AN INTERFACE, NOT AN EFFECT, AND THAT IS THE POINT
##
## A craft declares where it blows by growing ONE METHOD:
##
##     func exhaust_ports() -> Array    # of {"at": Vector3, "axis": Vector3, "radius": float,
##                                      #     "kind": ExhaustTuning.Kind, "heat": float}
##
## in its own frame, asked BY METHOD NAME rather than by type -- `VehicleView.cabin_room()`'s rule
## (`modelling_here.md` section 1), so a new airframe opts in by growing the method and **there is no roster to go out
## of date**. This yard branches on the PORT and never on the craft, which is `WakeTuning`'s "by where a craft is, not
## by what it is called".
##
## What that buys, and it is the difference between an effect and a feature: the F-35B's swivelling nozzle, lift fan
## and roll posts; the Osprey's two proprotors; a helicopter's disc; an A-10's two tailpipes -- each is a few lines in
## its own airframe and none of them is a line here. A ROTOR draws no flame and no haze because a proprotor makes no
## hot gas; what it makes is the thing on the ground, and it gets that for free.
##
## THE AXIS IS READ OFF THE DRAWN PART, not off a constant. The Harrier's four ports hang on its four nozzle hinges,
## so the plume and the drawn nozzle are one number and cannot point two ways -- which is the check
## `tests/lightning.gd` already holds the F-35B's nozzle to.
##
## ---------------------------------------------------------------------------------------------------------------
## THREE LAYERS, AND ONE DRAW CALL EACH
##
## - THE CORE (`exhaust_core.gdshader`), additive: the short pale tongue outside a hot pipe. JET only.
## - THE HAZE (`exhaust_haze.gdshader`), BLENDED and not additive -- `flare.gdshader`'s reason, and it is written into
##   that shader's doc block so the next effect does not relearn it: added to a bright sky a pale plume comes out
##   white, and disturbed air is if anything darker than the sky behind it.
## - THE GROUND BLOOM (`exhaust_bloom.gdshader`): puffs thrown once and flown by the GPU from their age on
##   `MissileYard`'s clock, `SprayYard`'s pattern, so a frozen level freezes the ground wash and the processor's whole
##   cost is the throwing.
##
## Each layer is ONE MultiMesh for the whole sky rather than nodes per aircraft. A flight of four Harriers would
## otherwise be 4 craft x 4 ports x 2 layers = 32 draw calls; it is 3. Everything after this copies it, so it is built
## the way it should be copied.
##
## REJECTED: GPUParticles3D, for `SprayYard`'s reasons -- its particles are placed in world space in float32, which on
## the double build steps a thing 9 km out onto float32's grid (billboard.gdshaderinc), and it is one emitter and one
## process pass per aircraft. And screen-space refraction for true heat shimmer: it needs a screen-texture read paid
## per pixel and twice in a headset, and a `depth_draw_never` blended quad cannot sample what is drawn after it.
##
## WHAT IT DOES NOT KNOW YET: a real Harrier's LIDS strakes and retractable fence exist to trap the fountain under the
## fuselage, and the fence's position is not read here -- the fountain is raised from the ports' own spacing alone. It
## is on this lane's `What's next`.

const CORE_SHADER: Shader = preload("res://world/shaders/exhaust_core.gdshader")
const HAZE_SHADER: Shader = preload("res://world/shaders/exhaust_haze.gdshader")
const BLOOM_SHADER: Shader = preload("res://world/shaders/exhaust_bloom.gdshader")

## How many plumes may be drawn at once across the whole sky, and how many ground puffs live at once. Both are ring
## buffers: the oldest is overwritten, so a busy sky degrades by shortening the wash rather than by costing more.
const PLUMES: int = 96
const PUFFS: int = 900

## WHERE THE BLOWING COMES FROM, handed in by whoever owns this yard, as `MissileYard.find_rail` is. Left unset it
## reads the replicated command bus, which is what the game does and what every machine holds for every entity. A
## probe running its OWN `CockpitWorld` -- `tests/lightning_reel.gd` does, so that the autopilot cannot fly the
## aeroplane as an aeroplane with the nozzle aft -- hands its own, because there is no `Sim.client` in that world at
## all. Taking `int(entity) -> float`.
var throttle_of: Callable = Callable()

var _missiles: MissileYard = null
var _cores: MultiMeshInstance3D = null
var _hazes: MultiMeshInstance3D = null
var _blooms: MultiMeshInstance3D = null
var _bloom_material: ShaderMaterial = null
## THE CLOCK AT THE LAST `lay`, so the interval comes from the SAME clock the puffs age on.
var _was: float = -1.0
var _next_puff: int = 0
var _puffs_thrown: int = 0
var _dice := RandomNumberGenerator.new()
## entity -> {port index -> how much of a puff it still owes}, so a port throws at a steady RATE rather than once a
## frame. NESTED BY ENTITY, and that is not decoration: it was flat, keyed "<entity>:<port>", and the per-frame sweep
## that drops craft which have gone away compared those composite keys against the views' integer entity ids. Every
## key missed, every key was erased, and the debt never survived a single frame -- so `owed` sat at 0.2996 for ever,
## never reached 1.0, and NOT ONE PUFF WAS EVER THROWN. The first picture of a hovering F-35B had no ground wash at
## all and six green checks had nothing to say about it.
var _owed: Dictionary = {}
## What the last `lay` drew, for the suite to read rather than recompute: entity -> Array of port records.
var _drawn: Dictionary = {}


## KEEP THE MISSILE YARD'S TIME, as every other per-craft yard does. Handed by the level before this is added.
func follow(missiles: MissileYard) -> void:
	_missiles = missiles


func _ready() -> void:
	_dice.seed = 20260919
	_cores = _plume_drawer("Cores", CORE_SHADER, {
		"least_angle": ExhaustTuning.CORE_LEAST_ANGLE, "brightness": ExhaustTuning.CORE_BRIGHTNESS})
	_hazes = _plume_drawer("Hazes", HAZE_SHADER, {
		"tone": ExhaustTuning.HAZE_TONE, "thickness": ExhaustTuning.HAZE_THICKNESS,
		"spread": ExhaustTuning.HAZE_SPREAD})
	add_child(_cores)
	add_child(_hazes)
	_blooms = _bloom_drawer()
	add_child(_blooms)


## ONE PLUME LAYER: a standing quad per port, y running 0 at the nozzle to 1 at the far end.
func _plume_drawer(named: String, shader: Shader, knobs: Dictionary) -> MultiMeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = shader
	for knob in knobs:
		material.set_shader_parameter(knob, knobs[knob])
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	# THE QUAD STANDS ON THE NOZZLE rather than straddling it: the shaders read VERTEX.y as 0 at the port and 1 at the
	# end of the plume, and a centred quad would put half the plume inside the aeroplane.
	quad.center_offset = Vector3(0.0, 0.5, 0.0)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = quad
	many.instance_count = PLUMES
	for i in range(PLUMES):
		many.set_instance_transform(i, MissileYard.NOWHERE)
		many.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, 0.0))
	many.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.name = named
	node.multimesh = many
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = TrailTuning.culling_box()
	return node


func _bloom_drawer() -> MultiMeshInstance3D:
	_bloom_material = ShaderMaterial.new()
	_bloom_material.shader = BLOOM_SHADER
	_bloom_material.set_shader_parameter("life", ExhaustTuning.BLOOM_LIFE)
	_bloom_material.set_shader_parameter("start_size", ExhaustTuning.BLOOM_START_SIZE)
	_bloom_material.set_shader_parameter("grow", ExhaustTuning.BLOOM_GROW)
	_bloom_material.set_shader_parameter("outward", ExhaustTuning.BLOOM_OUTWARD)
	_bloom_material.set_shader_parameter("lift", ExhaustTuning.BLOOM_LIFT)
	_bloom_material.set_shader_parameter("fountain_lift", ExhaustTuning.FOUNTAIN_LIFT)
	_bloom_material.set_shader_parameter("opacity", ExhaustTuning.BLOOM_OPACITY)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.use_colors = true
	many.mesh = quad
	many.instance_count = PUFFS
	for i in range(PUFFS):
		many.set_instance_transform(i, Transform3D.IDENTITY)
		# Thrown a very long time ago, so nothing is drawn until something is really thrown.
		many.set_instance_custom_data(i, Color(-100000.0, 0.0, 0.0, 0.0))
		many.set_instance_color(i, Color(0.0, 0.0, 0.0, 0.0))
	many.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.name = "Blooms"
	node.multimesh = many
	node.material_override = _bloom_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = TrailTuning.culling_box()
	return node


## ONE FRAME. `views` is the level's entity -> VehicleView, every one already placed this frame.
func lay(views: Dictionary) -> void:
	if _missiles == null:
		return
	var now: float = _missiles.clock()
	_bloom_material.set_shader_parameter("now", now)
	_drawn.clear()
	var plume: int = 0
	# THE INTERVAL IS THE CLOCK'S, NOT THE ENGINE'S, and that is a correctness fix rather than a tidy-up.
	# `get_process_delta_time()` returns ZERO on a node that is not processing -- this yard defines no `_process`,
	# because the level calls `lay` for it -- so every puff owed was `rate x strength x 0`, nothing was ever thrown,
	# and the first picture of a hovering F-35B had no ground wash under it. The suite was green through six checks
	# that asked the interface and never ran the yard. Reading the interval off `MissileYard`'s clock also ties the
	# THROWING to the same clock the puffs AGE on, so a frozen level freezes both together instead of one of them.
	var delta: float = 0.0 if _was < 0.0 else maxf(now - _was, 0.0)
	_was = now
	for entity in views:
		# TYPED `Node3D`, NOT `VehicleView`, and that is the contract rather than laziness: what this yard needs is a
		# thing that is placed in the world and answers `exhaust_ports()`. `tests/lightning_reel.gd` hands it a bare
		# `LightningAirframe` because it runs its own `CockpitWorld` with no views in it at all.
		var view: Node3D = views[entity]
		var ports: Array = _ports_of(view)
		if ports.is_empty():
			continue
		var throttle: float = _throttle_of(int(entity))
		var blowing: float = ExhaustTuning.blowing(throttle)
		if blowing <= 0.0:
			continue
		var pose: Transform3D = view.global_transform
		# EVERY PORT IN THE WORLD FIRST, because the fountain needs to know where its neighbours struck before any of
		# them throws. A port cannot answer that from its own frame.
		var struck: Array = []
		for port in ports:
			struck.append(_strike_of(pose, port as Dictionary))
		var record: Array = []
		for i in range(ports.size()):
			var port: Dictionary = ports[i]
			var kind: int = int(port.get("kind", ExhaustTuning.Kind.JET))
			var layers: Array = ExhaustTuning.layers_of(kind)
			var at: Vector3 = pose * (port.get("at", Vector3.ZERO) as Vector3)
			var axis: Vector3 = (pose.basis * (port.get("axis", Vector3.BACK) as Vector3)).normalized()
			var radius: float = maxf(float(port.get("radius", 0.3)), 0.02)
			var seed: float = float((int(entity) * 7 + i) % 97) * 0.0103
			if bool(layers[0]) and blowing >= ExhaustTuning.CORE_FROM_THROTTLE and plume < PLUMES:
				_set_plume(_cores, plume, at, axis, radius,
					radius * ExhaustTuning.CORE_LENGTH_RADII * blowing, blowing, seed, 0.0)
				plume += 1
			if bool(layers[1]) and blowing >= ExhaustTuning.HAZE_FROM_THROTTLE and plume < PLUMES:
				var cold: float = 1.0 - clampf(float(port.get("heat", 1.0)), 0.0, 1.0)
				_set_plume(_hazes, plume, at, axis, radius,
					radius * ExhaustTuning.HAZE_LENGTH_RADII * blowing, blowing, seed, cold)
				plume += 1
			if bool(layers[2]) and blowing >= ExhaustTuning.BLOOM_FROM_THROTTLE:
				_throw_bloom(int(entity), i, struck[i] as Dictionary, struck, radius, blowing, delta, now)
			record.append({"at": at, "axis": axis, "radius": radius, "kind": kind,
				"blowing": blowing, "strike": struck[i]})
		_drawn[entity] = record
	# The two plume layers share one counter, so a sky that runs out of plumes runs out of both together rather than
	# drawing cores with no haze behind them.
	_cores.multimesh.visible_instance_count = PLUMES
	_hazes.multimesh.visible_instance_count = PLUMES
	for i in range(plume, PLUMES):
		_cores.multimesh.set_instance_transform(i, MissileYard.NOWHERE)
		_hazes.multimesh.set_instance_transform(i, MissileYard.NOWHERE)
	_blooms.multimesh.visible_instance_count = mini(_puffs_thrown, PUFFS)
	var gone: Array = []
	for entity in _owed:
		if not views.has(entity):
			gone.append(entity)
	for entity in gone:
		_owed.erase(entity)


## THE PORTS A CRAFT DECLARES, asked of the AIRFRAME by method name so there is no roster. A craft whose airframe has
## no `exhaust_ports` has none, which for a glider is the truth and not an oversight.
func _ports_of(view: Node3D) -> Array:
	if view == null or not view.has_method("exhaust_ports"):
		return []
	return view.call("exhaust_ports") as Array


## THE THROTTLE OFF THE REPLICATED BUS, which every machine holds for every entity -- not only the one it is flying.
func _throttle_of(entity: int) -> float:
	if throttle_of.is_valid():
		return float(throttle_of.call(entity))
	if Sim.client == null or entity <= 0:
		return 0.0
	return float((Sim.client.craft_controls(entity) as Dictionary).get("throttle", 0.0))


## WHERE THIS PORT'S PLUME MEETS THE GROUND OR THE WATER, and what it would raise there.
## By WHERE IT IS, never by what the craft is called: `Terrain.water_height` finite under the strike means spray,
## otherwise dust. That is the whole of why a helicopter gets this for free.
func _strike_of(pose: Transform3D, port: Dictionary) -> Dictionary:
	var at: Vector3 = pose * (port.get("at", Vector3.ZERO) as Vector3)
	var axis: Vector3 = (pose.basis * (port.get("axis", Vector3.BACK) as Vector3)).normalized()
	var down: float = -axis.y
	if down < ExhaustTuning.BLOOM_LEAST_DOWN:
		return {"hits": false}
	var water: float = Terrain.water_height(at)
	var ground: float = Terrain.surface_height(at)
	var surface: float = maxf(ground, water if water > -INF else -INF)
	var above: float = at.y - surface
	var strength: float = ExhaustTuning.bloom_by_height(above / maxf(down, 0.001))
	if strength <= 0.0:
		return {"hits": false}
	# The plume leans, so it lands short of straight below. Flat ground is assumed over that lean, which is a metre or
	# two: a slope steep enough to matter is steep enough that nothing is hovering over it.
	var reach: float = above / maxf(down, 0.001)
	var atground: Vector3 = at + axis * reach
	var wet: bool = water > -INF and water >= ground - 0.05
	return {"hits": true, "at": Vector3(atground.x, surface, atground.z), "strength": strength,
		"wet": wet, "tone": ExhaustTuning.SPRAY_TONE if wet else ExhaustTuning.DUST_TONE}


## ONE PORT'S SHARE OF THE GROUND WASH THIS FRAME. Puffs are owed at a rate and thrown when a whole one is due, so the
## ring fills evenly instead of in bursts on whichever frames happened to be long.
func _throw_bloom(entity: int, index: int, strike: Dictionary, all: Array, radius: float,
		blowing: float, delta: float, now: float) -> void:
	if not bool(strike.get("hits", false)):
		return
	var strength: float = float(strike["strength"]) * blowing
	var mine: Dictionary = _owed.get(entity, {})
	var owed: float = float(mine.get(index, 0.0)) + ExhaustTuning.BLOOM_PUFFS_A_SECOND * strength * delta
	var here: Vector3 = strike["at"]
	while owed >= 1.0:
		owed -= 1.0
		var bearing: float = _dice.randf()
		var ring: float = radius * ExhaustTuning.BLOOM_RING_RADII
		var start := here + Vector3(cos(bearing * TAU) * ring, 0.0, sin(bearing * TAU) * ring)
		# THE FOUNTAIN RISES WHERE TWO FLOWS MEET, which is BETWEEN a pair of strikes and not merely near one of them.
		#
		# It was written as "near any other port's strike" and that was wrong in a way only a picture showed. The
		# F-35B's four ports all sit within six metres of each other on a fifteen-metre aeroplane, so EVERY puff was
		# within the fountain radius of a neighbour, every puff traded its outward run for a climb, and the ring
		# became a column -- a white wall that swallowed the whole aircraft (before-after/bloom-BEFORE-engulfed.png).
		# The collision point of two spreading flows is their MIDPOINT, so that is what is measured against.
		var fountain: float = 0.0
		for other in all:
			var o: Dictionary = other
			if not bool(o.get("hits", false)):
				continue
			var between: Vector3 = ((o["at"] as Vector3) + here) * 0.5
			if between.distance_to(here) < 0.01:
				continue
			var away: float = between.distance_to(start)
			if away < ExhaustTuning.FOUNTAIN_WITHIN:
				fountain = maxf(fountain, 1.0 - away / ExhaustTuning.FOUNTAIN_WITHIN)
		var i: int = _next_puff
		_next_puff = (_next_puff + 1) % PUFFS
		_puffs_thrown += 1
		_blooms.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, start))
		_blooms.multimesh.set_instance_custom_data(i, Color(now, _dice.randf(), bearing, fountain))
		var tone: Color = strike["tone"]
		_blooms.multimesh.set_instance_color(i, Color(tone.r, tone.g, tone.b, 1.0))
	mine[index] = owed
	_owed[entity] = mine


## ONE PLUME: the quad's X column across it (as wide as the nozzle), its Y column down the plume (as long as it is),
## and its Z small and square to both so the basis can be INVERTED -- which `BILLBOARD_LOCAL_OF` does on every
## MultiMesh. `MissileYard.segment_basis`'s lesson: a singular basis is harmless until the first shader inverts it,
## and then every instance draws as shattered triangles.
func _set_plume(drawer: MultiMeshInstance3D, index: int, at: Vector3, axis: Vector3, radius: float,
		length: float, blowing: float, seed: float, cold: float) -> void:
	var along: Vector3 = axis * maxf(length, 0.01)
	var unit: Vector3 = along.normalized()
	var across: Vector3 = unit.cross(Vector3.UP if absf(unit.y) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(across * radius, along, unit.cross(across).normalized() * 0.001)
	drawer.multimesh.set_instance_transform(index, Transform3D(basis, at))
	drawer.multimesh.set_instance_custom_data(index, Color(blowing, seed, cold, 1.0))


## WHAT THE LAST FRAME DREW, for the suite: entity -> array of {"at", "axis", "radius", "kind", "blowing", "strike"}.
## Read off what was actually handed to the drawers, never recomputed -- a check that works it out again is checking
## its own arithmetic.
func drawn() -> Dictionary:
	return _drawn


## How many ground puffs have ever been thrown. The drawn count until the ring is full.
func puffs_thrown() -> int:
	return _puffs_thrown
