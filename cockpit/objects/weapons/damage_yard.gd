extends Node3D
class_name DamageYard
## WHAT A HIT CRAFT LOOKS LIKE: A TRAIL OF SMOKE BEHIND IT, AND A FIREBALL WHERE IT DIED (lane/combat, 2026-09-18).
##
## Asked for on 2026-09-18: "their guns can damage the plane (causing smoke to trail behind it), Finally after taking
## enough damage, it should explode into pieces."
##
## A PICTURE OF A FACT THE WIRE ALREADY CARRIES. What is left of each hull is the server's (`Hull`, `Sim.hulls`), and the
## stage it is drawn at is worked out in C++ from the byte every machine receives, so two machines looking at one
## smoking aeroplane draw the same stage from the same number. Nothing here is sent anywhere.
##
##   stage 1 (60% left or less): THIN GREY smoke, the look of an engine that has been hit.
##   stage 2 (30% or less): THICK BLACK smoke with fire at the craft, which is the one you can see from the boat's gun a
##   mile off.
##   stage 3: destroyed -- the airframe hidden, and on the frame it happened (`Sim.Cue.DESTROYED`) a fireball.
##
## PUFFS LEFT WHERE THE CRAFT WAS, one every `SPACING` metres of its path, each swelling, rising and thinning away on the
## GPU from the moment it was laid (`world/shaders/damage_smoke.gdshader`): laying one is a transform and a colour, and
## nothing is touched again. REJECTED: the missile yard's trail worn dark, the first build -- a strip that widens as it
## ages, and photographed it was a flat beige sheet across the ground behind the aeroplane, not smoke.
##
## ONE MULTIMESH PER STAGE, and so two draws for every smoking craft in the sky together. Unsorted within a stage, as the
## burst smoke is: at these opacities the wrong order reads as a denser patch, not a hole.

const SMOKE: Shader = preload("res://world/shaders/damage_smoke.gdshader")

## Metres of a craft's path between two puffs: close enough that neighbours overlap at their smallest.
const SPACING: float = 2.5
## The most puffs one craft lays in one frame, so a hitch cannot pour a hundred into one place.
const MOST_A_FRAME: int = 6
## How many puffs each stage holds; the oldest is taken for the newest. A craft at 70 m/s lays 28 a second, so the thick
## stage's 12 s is 336 of them: this is a dozen craft smoking hard at once.
const PUFFS: int = 4096
## THE TWO STAGES: how long a puff lasts, how big it starts and grows, how fast it rises, its tone, its opacity, and how
## long the fire lights the newest.
const STAGES: Array[Dictionary] = [
	{"name": "ThinSmoke", "life": 5.0, "start": 0.9, "grow": 4.0, "rise": 0.8, "tone": Color(0.48, 0.48, 0.49),
		"opacity": 0.55, "fire": 0.0},
	{"name": "ThickSmoke", "life": 11.0, "start": 1.0, "grow": 9.0, "rise": 1.5, "tone": Color(0.07, 0.065, 0.06),
		"opacity": 0.85, "fire": 0.1},
]
## How far aft of the craft's middle the smoke leaves, as a share of its half-length: the engine is behind the cockpit.
const AFT_SHARE: float = 0.4

## The level's explosions, for the fireball. Set before this is added; null draws the smoke and no fireball.
var bursts: BurstYard = null
## WHAT IS LEFT OF A DESTROYED CRAFT, falling: see WreckPieces. Made here, smoking through this yard.
var pieces: WreckPieces = null

var _clock: float = 0.0
var _stages: Array[MultiMeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _next: Array[int] = [0, 0]
var _laid: Array[int] = [0, 0]
## Each craft smoking: entity -> {"at": Vector3, "stage": int, "puffs": int}: where its last puff was laid.
var _laying: Dictionary = {}
## Each craft drawn as a wreck, so it is hidden once.
var _wrecked: Dictionary = {}
## How many fireballs this yard has set off, for the tests.
var fireballs: int = 0


## KEPT FOR THE LEVEL'S WIRING, which hands every trail-drawing yard the missile yard: the smoke has its own clock now.
func follow(_missiles: MissileYard) -> void:
	pass


func _ready() -> void:
	for stage in STAGES:
		_stages.append(_build_a_stage(stage))
	pieces = WreckPieces.new()
	pieces.name = "WreckPieces"
	pieces.smoke = self
	add_child(pieces)


func _process(delta: float) -> void:
	_clock += delta
	var wind: Vector3 = Sim.wind(600.0) if Sim.is_available() else Vector3.ZERO
	for material in _materials:
		material.set_shader_parameter("now", _clock)
		material.set_shader_parameter("wind", wind)


## ONE FRAME. `views` is the level's entity -> VehicleView, every one already placed this frame.
func lay(views: Dictionary) -> void:
	for entity in Sim.hulls:
		var hull: Dictionary = Sim.hulls[entity]
		var view: VehicleView = views.get(entity)
		if view == null:
			continue
		var stage: int = int(hull.get("stage", 0))
		if stage >= 3:
			if not _wrecked.has(entity):
				_wrecked[entity] = true
				view.show_wrecked()
			_laying.erase(entity)
			continue
		if stage <= 0:
			_laying.erase(entity)
			continue
		var from: Vector3 = _source(view)
		var record: Dictionary = _laying.get(entity, {})
		if record.is_empty() or int(record["stage"]) != stage:
			record = {"at": from, "stage": stage, "puffs": int(record.get("puffs", 0))}
			_laying[entity] = record
			_puff(stage - 1, from, entity)
			continue
		var was: Vector3 = record["at"]
		var gone: float = was.distance_to(from)
		if gone < SPACING:
			continue
		# ONE EVERY `SPACING` ALONG THE PATH SINCE THE LAST, stamped a little apart in time so the older ones are older.
		var count: int = mini(int(gone / SPACING), MOST_A_FRAME)
		for i in range(1, count + 1):
			_puff(stage - 1, was.lerp(from, float(i) / float(count)), entity)
		record["at"] = from
		record["puffs"] = int(record["puffs"]) + count
	# A CRAFT THAT WENT AWAY: its smoke stays where it was laid and fades on its own.
	for entity in _laying.keys():
		if not Sim.hulls.has(entity) or not views.has(entity):
			_laying.erase(entity)
	for entity in _wrecked.keys():
		if not views.has(entity):
			_wrecked.erase(entity)


## A CRAFT WAS DESTROYED JUST NOW (the cue): a fireball sized from the craft, at where this machine draws it, and the
## airframe hidden. `cause` is the `Sim.HullCause`: a craft that hit something throws a grounded burst.
func destroyed(view: VehicleView, cause: int) -> void:
	if view == null:
		return
	# THE PIECES FIRST, while the airframe is still drawn to copy them from, thrown with the velocity this machine last
	# drew the craft with: the host froze it on the frame it died, so the newest state says it is standing still.
	if pieces != null and not _wrecked.has(view.entity):
		var going: Vector3 = (Sim.previous.get(view.entity, {}).get("velocity", Vector3.ZERO) as Vector3)
		pieces.break_up(view, going)
	# AND THE BANG, the heaviest crack a gun makes, at the craft: off unless the game's sound is on (`--audio`).
	VehicleSound.report(self, view.global_position, 4.0)
	if bursts != null:
		var extents: Vector3 = Sim.geometry_of(view.kind).get("extents", Vector3.ONE) as Vector3
		var grounded: bool = cause == Sim.HullCause.GROUND or cause == Sim.HullCause.WATER \
			or cause == Sim.HullCause.COLLISION
		bursts.set_off(view.global_position, fireball_for(extents), grounded, 1.0, float(view.entity % 97) * 0.4)
		fireballs += 1
	if not _wrecked.has(view.entity):
		_wrecked[view.entity] = true
		view.show_wrecked()


## A CRAFT'S FIREBALL, in metres: a little more than its longest half-extent, so a light aeroplane's is about seven
## metres and an airliner's twenty-five; never smaller than a heavy shell's, never the size of a town.
static func fireball_for(extents: Vector3) -> float:
	return clampf(maxf(extents.x, maxf(extents.y, extents.z)) * 1.3, 6.0, 28.0)


## Where the smoke leaves: the craft's middle, a little aft along its length. -Z is forward in the craft's frame.
func _source(view: VehicleView) -> Vector3:
	var extents: Vector3 = Sim.geometry_of(view.kind).get("extents", Vector3.ONE) as Vector3
	return view.global_transform * Vector3(0.0, 0.0, extents.z * AFT_SHARE)


## ---- the puffs --------------------------------------------------------------------

## ONE THIN PUFF at `at`, for something else that smokes -- a falling piece of a wreck. `id` seeds its size.
func puff_at(at: Vector3, id: int) -> void:
	_puff(0, at, id)


func _puff(stage: int, at: Vector3, entity: int) -> void:
	var index: int = _next[stage]
	_next[stage] = (_next[stage] + 1) % PUFFS
	var many: MultiMesh = _stages[stage].multimesh
	if _laid[stage] < PUFFS:
		_laid[stage] += 1
		many.visible_instance_count = _laid[stage]
	many.set_instance_transform(index, Transform3D(Basis.IDENTITY, at))
	# ITS OWN NUMBER, from where it was laid and who laid it, so two machines drawing the same smoke draw the same puffs.
	var own: float = fposmod(at.x * 0.37 + at.z * 0.61 + float(entity % 89) * 0.13, 1.0)
	many.set_instance_custom_data(index, Color(_clock, own, 0.0, 0.0))


func _build_a_stage(stage: Dictionary) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = quad
	many.instance_count = PUFFS
	for i in range(PUFFS):
		many.set_instance_custom_data(i, Color(-100000.0, 0.0, 0.0, 0.0))
	many.visible_instance_count = 0
	var material := ShaderMaterial.new()
	material.shader = SMOKE
	material.set_shader_parameter("life", stage["life"])
	material.set_shader_parameter("start_size", stage["start"])
	material.set_shader_parameter("grow", stage["grow"])
	material.set_shader_parameter("rise", stage["rise"])
	material.set_shader_parameter("tone", stage["tone"])
	material.set_shader_parameter("opacity", stage["opacity"])
	material.set_shader_parameter("fire_s", stage["fire"])
	_materials.append(material)
	var drawn := MultiMeshInstance3D.new()
	drawn.name = String(stage["name"])
	drawn.multimesh = many
	drawn.material_override = material
	drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drawn.custom_aabb = TrailTuning.culling_box()
	add_child(drawn)
	return drawn


## ---- for the tests -----------------------------------------------------------------

## The stage a craft's smoke is being laid at, 0 for none.
func smoking(entity: int) -> int:
	return int((_laying.get(entity, {}) as Dictionary).get("stage", 0))


## How many puffs have been laid behind a craft since it started smoking.
func puffs_behind(entity: int) -> int:
	return int((_laying.get(entity, {}) as Dictionary).get("puffs", 0))


func is_wrecked(entity: int) -> bool:
	return _wrecked.has(entity)
