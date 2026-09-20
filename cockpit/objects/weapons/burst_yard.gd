extends Node3D
class_name BurstYard
## EVERY BIG EXPLOSION IN THE SKY -- a missile's warhead and a heavy shell's -- DRAWN FROM A POOL BUILT WHEN THE LEVEL
## LOADS, and nothing made in the frame one goes off.
##
## "NOT A WEIRD PERF HIT WHEN CREATED", asked for on 2026-09-13, is three things and this file is all three:
##
##   NOTHING IS BUILT AT THE MOMENT OF AN EXPLOSION. The materials, the two shared MultiMeshes, every `HeavyBurst` and
##   both lights exist from `_ready`. Setting one off is a position, a few instance uniforms and a visibility; the
##   suite counts nodes and resources across thirty explosions and fails on one more.
##
##   NOTHING COMPILES AT THE MOMENT OF AN EXPLOSION. A pipeline is compiled the first time a material is DRAWN, and a
##   burst drawn for the first time mid-fight is a hitch exactly when a player is looking. So for the first
##   `WARM_FRAMES` frames after the level loads, one burst wearing each finish's pair and both lights stand just in
##   front of the camera, collapsed to nothing: every vertex on one point, so the pipeline is bound and drawn and not a
##   pixel of it shows. A lit omni light is part of that, because switching the first one on changes what every
##   material it reaches is drawn with.
##
##   NOTHING GROWS PAST ITS CAP. `BurstTuning.AT_ONCE` bursts and `LIGHTS_AT_ONCE` lights, each taken back oldest
##   first -- one that has gone out before one still going, and among those still going the oldest, so what gives
##   way is a barrage's first smoke and lingering fire and never a fireball in its middle, which would pop. A
##   barrage asks for more; it gets the newest.
##
## WHAT THE PROCESSOR PAYS A FRAME while any burst is going: `now` on the two materials being worn, and a look at each
## burst's time. Nothing at all once they have gone.
##
## WHO USES IT: `ShotYard` for a round `BurstTuning.is_heavy` says lands big, and `MissileYard` for every missile that
## goes off. The level makes one and hands it to both, so the cap is the sky's and not each yard's; a yard built on its
## own (a test's) makes its own.

const FIRE_PLAIN: Shader = preload("res://world/shaders/heavy_burst_fire.gdshader")
const FIRE_FINE: Shader = preload("res://world/shaders/heavy_burst_fire_fine.gdshader")
const SMOKE_PLAIN: Shader = preload("res://world/shaders/heavy_burst_smoke.gdshader")
const SMOKE_FINE: Shader = preload("res://world/shaders/heavy_burst_smoke_fine.gdshader")

## HOW LONG THE PIPELINES ARE WARMED FOR, in drawn frames. Two is what a pipeline needs to be asked for and used; the
## rest is room for a first frame that went to loading the level.
const WARM_FRAMES: int = 4
## How far in front of the camera the warm-up stands, in metres: inside every near and far plane anybody has set.
const WARM_AHEAD: float = 20.0

## Quad codes, in `INSTANCE_CUSTOM.r`. See the fire and smoke shaders. `ONLY_FINE` is added to a quad PLAIN collapses.
const FLASH: float = 0.0
const RING: float = 1.0
const PUFF: float = 2.0
const SPARK: float = 3.0
const SMOKE_PUFF: float = 0.0
const DEBRIS: float = 1.0
const ONLY_FINE: float = 10.0

var _clock: float = 0.0
var _fine: bool = false
var _fire_plain: ShaderMaterial = null
var _fire_fine: ShaderMaterial = null
var _smoke_plain: ShaderMaterial = null
var _smoke_fine: ShaderMaterial = null
var _fire_mesh: MultiMesh = null
var _smoke_mesh: MultiMesh = null
var _bursts: Array[HeavyBurst] = []
## How many explosions have taken back a burst that was still going: see `set_off`. For the tests and the probe.
var _stolen: int = 0
var _lights: Array[OmniLight3D] = []
var _light_until: PackedFloat64Array = []
var _next_light: int = 0
## The time of day's, handed over once per change. See `show_daylight`.
var _light_energy: float = 0.0
## The two bursts and the frames left that the warm-up stands for; see the header.
var _warm: Array[HeavyBurst] = []
var _warming: int = WARM_FRAMES
var _newest: HeavyBurst = null


func _ready() -> void:
	_fire_plain = _paint(FIRE_PLAIN)
	_fire_fine = _paint(FIRE_FINE)
	_smoke_plain = _paint(SMOKE_PLAIN)
	_smoke_fine = _paint(SMOKE_FINE)
	for fire in [_fire_plain, _fire_fine]:
		var paint := fire as ShaderMaterial
		paint.set_shader_parameter("flash_across", BurstTuning.FLASH_ACROSS)
		paint.set_shader_parameter("flash_s", BurstTuning.FLASH_S)
		paint.set_shader_parameter("grow_s", BurstTuning.FIREBALL_GROW_S)
		paint.set_shader_parameter("cool_s", BurstTuning.FIREBALL_COOL_S)
		paint.set_shader_parameter("burn_s", BurstTuning.FIREBALL_BURN_S)
		paint.set_shader_parameter("ember_s", BurstTuning.GROUND_FIRE_S)
		paint.set_shader_parameter("rise", BurstTuning.FIREBALL_RISE)
		paint.set_shader_parameter("spark_speed", BurstTuning.SPARK_SPEED_PER_M)
		paint.set_shader_parameter("spark_s", BurstTuning.SPARK_S)
		paint.set_shader_parameter("gravity", _gravity())
	_fire_fine.set_shader_parameter("ring_out", BurstTuning.RING_OUT)
	_fire_fine.set_shader_parameter("ring_s", BurstTuning.RING_S)
	for smoke in [_smoke_plain, _smoke_fine]:
		var paint := smoke as ShaderMaterial
		paint.set_shader_parameter("grow", BurstTuning.SMOKE_GROW)
		paint.set_shader_parameter("rise", BurstTuning.SMOKE_RISE)
		paint.set_shader_parameter("delay_s", BurstTuning.FIREBALL_GROW_S)
		paint.set_shader_parameter("tone", BurstTuning.SMOKE_TONE)
		paint.set_shader_parameter("opacity", BurstTuning.SMOKE_OPACITY)
	_smoke_fine.set_shader_parameter("debris_speed", BurstTuning.DEBRIS_SPEED_PER_M)
	_smoke_fine.set_shader_parameter("debris_s", BurstTuning.DEBRIS_S)
	_smoke_fine.set_shader_parameter("gravity", _gravity())
	_lay_out_the_meshes()
	for i in range(BurstTuning.AT_ONCE):
		var burst := HeavyBurst.new()
		burst.name = "Burst%d" % i
		add_child(burst)
		burst.build(_fire_mesh, _smoke_mesh)
		_bursts.append(burst)
	for i in range(BurstTuning.LIGHTS_AT_ONCE):
		var light := OmniLight3D.new()
		light.name = "Light%d" % i
		light.top_level = true
		light.light_color = BurstTuning.LIGHT_COLOUR
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_lights.append(light)
		_light_until.append(-1.0)
	var finish: Node = get_node_or_null("/root/Finish")
	if finish != null:
		finish.connect("changed", _wear)
		_fine = bool(finish.call("is_fine"))
	_wear(_fine)
	# THE WARM-UP'S OWN TWO, one per finish, beside the pool rather than out of it, so the pool is whole the moment
	# the warm-up ends and nobody's explosion is taken for it.
	for fine in [false, true]:
		var standing := HeavyBurst.new()
		standing.name = "Warm%s" % ("Fine" if fine else "Plain")
		add_child(standing)
		standing.build(_fire_mesh, _smoke_mesh)
		standing.wear(_fire_fine if fine else _fire_plain, _smoke_fine if fine else _smoke_plain)
		_warm.append(standing)


func _process(delta: float) -> void:
	_clock += delta
	if _warming > 0:
		_stand_the_warm_up()
	var any: bool = false
	for burst in _bursts:
		any = burst.keep_going(_clock) or any
	for i in range(_lights.size()):
		if _lights[i].visible and _clock >= _light_until[i] and _warming <= 0:
			_lights[i].visible = false
		any = any or _lights[i].visible
	if any:
		_tell_the_time()
	elif _warming <= 0:
		set_process(false)


## SET OFF A BIG EXPLOSION at `at` with a fireball of `radius` metres. `grounded` is one that hit something; `density`
## is how thick its smoke is by what it hit (`Ammunition.surface`'s "smoke", 1 in the air); `turn` is any number that
## differs between explosions -- an entity does. Returns the burst, or null for a radius of nothing.
func set_off(at: Vector3, radius: float, grounded: bool, density: float, turn: float) -> HeavyBurst:
	if radius <= 0.0:
		return null
	var burst: HeavyBurst = _free_or_oldest()
	if burst.visible:
		_stolen += 1
	burst.put_away()
	burst.set_off(at, _clock, radius, Sim.wind(at.y), grounded, density, turn, BurstTuning.lasts(radius, _fine))
	_newest = burst
	if _light_energy > 0.0:
		var light: OmniLight3D = _lights[_next_light]
		_light_until[_next_light] = _clock + BurstTuning.LIGHT_S
		_next_light = (_next_light + 1) % _lights.size()
		light.global_position = at
		light.omni_range = radius * BurstTuning.LIGHT_REACH
		light.light_energy = _light_energy
		light.visible = true
	# AND THE CLOCK NOW, as part of the event rather than the frame: a burst set off from a cue after this frame's
	# `_process` would otherwise be drawn one frame on a clock that has not caught up with it.
	_tell_the_time()
	set_process(true)
	return burst


## THE BURST TO SET OFF NEXT: one that has gone out if there is one, and otherwise the oldest still going. It was
## round-robin, which takes the next in line whether or not it has finished -- a burst mid-fireball while another
## sat idle, once the bursts' lives differ (a 40 mm's smoke goes sooner than a 105's, and a ground fire outlasts both).
func _free_or_oldest() -> HeavyBurst:
	var oldest: HeavyBurst = _bursts[0]
	for burst in _bursts:
		if not burst.visible:
			return burst
		if burst.born < oldest.born:
			oldest = burst
	return oldest


## HOW BRIGHT A BURST'S LIGHT IS AT THIS TIME OF DAY, handed over once per change by the level. 0 lights nothing.
func show_daylight(light_energy: float) -> void:
	_light_energy = light_energy


func _wear(fine: bool) -> void:
	_fine = fine
	for burst in _bursts:
		burst.wear(_fire_fine if fine else _fire_plain, _smoke_fine if fine else _smoke_plain)
	_tell_the_time()


func _tell_the_time() -> void:
	(_fire_fine if _fine else _fire_plain).set_shader_parameter("now", _clock)
	(_smoke_fine if _fine else _smoke_plain).set_shader_parameter("now", _clock)


## ONE FRAME OF THE WARM-UP: both standing bursts and both lights just ahead of the camera, and away once it is done.
## Born long ago, so every quad has gone out and sits on its centre; the lights at the least energy a light has.
func _stand_the_warm_up() -> void:
	_warming -= 1
	var eye: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var done: bool = _warming <= 0 or eye == null
	var ahead: Vector3 = Vector3.ZERO
	if eye != null:
		ahead = eye.global_position - eye.global_transform.basis.z * WARM_AHEAD
	for standing in _warm:
		standing.global_position = ahead
		standing.visible = not done
	# BOTH PAIRS DRAWN AT ONCE, so a finish changed later has nothing left to compile either.
	_fire_plain.set_shader_parameter("now", _clock)
	_fire_fine.set_shader_parameter("now", _clock)
	_smoke_plain.set_shader_parameter("now", _clock)
	_smoke_fine.set_shader_parameter("now", _clock)
	for light in _lights:
		light.global_position = ahead
		light.omni_range = 1.0
		light.light_energy = 0.001
		light.visible = not done
	if done:
		_warming = 0


## THE TWO MESHES EVERY BURST DRAWS, laid out once with a fixed seed so every machine's explosion is the same picture.
## An instance's X column is its direction (its length how far); the other two are small and square to it only so the
## basis is not singular. Its custom data is (code, and three numbers of its own). See the shaders.
func _lay_out_the_meshes() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 1
	var fire: Array = [[Vector3.RIGHT, FLASH], [Vector3.RIGHT, RING + ONLY_FINE]]
	for i in range(BurstTuning.FIREBALL_PUFFS):
		var code: float = PUFF if i < BurstTuning.FIREBALL_PUFFS_PLAIN else PUFF + ONLY_FINE
		fire.append([_somewhere(dice, 0.2, false), code])
	for i in range(BurstTuning.SPARKS):
		var code: float = SPARK if i < BurstTuning.SPARKS_PLAIN else SPARK + ONLY_FINE
		fire.append([_somewhere(dice, 1.0, true), code])
	var smoke: Array = []
	for i in range(BurstTuning.SMOKE_PUFFS):
		var code: float = SMOKE_PUFF if i < BurstTuning.SMOKE_PUFFS_PLAIN else SMOKE_PUFF + ONLY_FINE
		smoke.append([_somewhere(dice, 0.3, false), code])
	for i in range(BurstTuning.DEBRIS):
		smoke.append([_somewhere(dice, 1.0, true), DEBRIS + ONLY_FINE])
	_fire_mesh = _many(fire, dice)
	_smoke_mesh = _many(smoke, dice)


func _many(quads: Array, dice: RandomNumberGenerator) -> MultiMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = quad
	many.instance_count = quads.size()
	for i in range(quads.size()):
		var along: Vector3 = quads[i][0]
		var square: Vector3 = along.normalized().cross(Vector3.UP if absf(along.normalized().y) < 0.9 else Vector3.RIGHT)
		var third: Vector3 = along.normalized().cross(square)
		many.set_instance_transform(i, Transform3D(Basis(along, square.normalized() * 0.001, third.normalized() * 0.001),
			Vector3.ZERO))
		many.set_instance_custom_data(i, Color(float(quads[i][1]), dice.randf(), dice.randf(), dice.randf()))
	return many


## A direction, at least `least` long and at most 1. `unit` keeps it a unit, a little more often up than down.
static func _somewhere(dice: RandomNumberGenerator, least: float, unit: bool) -> Vector3:
	var way := Vector3(dice.randf_range(-1.0, 1.0), dice.randf_range(-0.6, 1.0) if unit else dice.randf_range(-1.0, 1.0),
		dice.randf_range(-1.0, 1.0))
	if way.length_squared() < 0.0001:
		way = Vector3.UP
	way = way.normalized()
	return way if unit else way * dice.randf_range(least, 1.0)


static func _paint(shader: Shader) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = shader
	return paint


static func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


## ---- for the tests and the boards -------------------------------------------------

## How many big explosions are being drawn.
func going() -> int:
	var count: int = 0
	for burst in _bursts:
		if burst.visible:
			count += 1
	return count


## How many explosions have had to take back a burst that was still going.
func stolen() -> int:
	return _stolen


## The pool's size, which never changes after `_ready`.
func pool() -> int:
	return _bursts.size()


## The fireball radius of the newest explosion, in metres, or 0 before any.
func newest_fireball() -> float:
	return _newest.fireball if _newest != null else 0.0


## How many of the lights are on.
func lights_on() -> int:
	var count: int = 0
	for light in _lights:
		if light.visible:
			count += 1
	return count


## Whether the warm-up is over.
func warmed() -> bool:
	return _warming <= 0


## What the bursts are wearing, read off the materials rather than off the tier.
func wears_fine() -> bool:
	return not _bursts.is_empty() and _bursts[0].fire.material_override == _fire_fine
