extends Node3D
class_name HeavyBurst
## ONE BIG EXPLOSION: A FLASH, A FIREBALL THAT SWELLS AND COOLS, SPARKS, DEBRIS, A RING, AND SMOKE THAT DRIFTS.
##
## POOLED, and set off rather than built: `BurstYard` holds `BurstTuning.AT_ONCE` of these from the moment the level
## loads, and the next explosion takes back the oldest. Nothing here is created after `build`.
##
## THE DECISION: NOTHING HERE MOVES ONCE IT IS SET OFF. A burst is two MultiMeshInstance3Ds -- the fire (additive) and
## the smoke (lit, blended) -- over two MultiMeshes that every burst in the yard SHARES, laid out once with a direction,
## a seed and a role per quad. Setting one off writes where it is and a handful of instance uniforms (when, how big,
## which way the wind blows, whether it is on the ground, how it is turned, how thick and how long its smoke is); how
## far every quad has flown, swelled, cooled and faded is worked out on the GPU from the yard's clock. The processor's
## whole cost after that is the yard writing `now` on the two worn materials while any burst is going, and one
## visibility write when each ends.
##
## WHAT WENT WRONG BEFORE, and why this is not `Burst`: a missile's burst and a 105 mm shell's were `Burst` with bigger
## numbers, whose forty-seven meshes each had a StandardMaterial with its colour written every frame, and whose pool was
## grown on the first hits of a session -- forty-seven nodes and forty-seven materials made in the frame a shell landed.
## `Burst` is still the small gun's, untouched.
##
## NO LIGHT OF ITS OWN. The yard has `BurstTuning.LIGHTS_AT_ONCE` lights and moves them to the newest bursts.

var fire: MultiMeshInstance3D = null
var smoke: MultiMeshInstance3D = null
## On the yard's clock: when this was set off and when it is put away.
var born: float = -100000.0
var until: float = -1.0
## The fireball's radius this burst was drawn with, in metres, for the tests.
var fireball: float = 0.0

## What it was set off with, kept so a change of finish can hand the same numbers to the other pair of materials: an
## instance uniform belongs to the material it was written under.
var _wind: Vector3 = Vector3.ZERO
var _grounded: float = 0.0
var _turn: float = 0.0
var _density: float = 1.0
var _lasts: float = 1.0


## Built once by the yard, over the yard's shared meshes and wearing the yard's materials.
func build(fire_mesh: MultiMesh, smoke_mesh: MultiMesh) -> void:
	# IN THE WORLD'S FRAME whatever it hangs from: the shaders read the node's origin as the centre and its basis as the
	# identity, and a yard that was ever turned or moved would turn every spark with it.
	top_level = true
	fire = _instance_of(fire_mesh, "Fire")
	smoke = _instance_of(smoke_mesh, "Smoke")
	visible = false


## SET IT OFF at `at`, on the yard's clock at `now`, with a fireball of `radius` metres. `wind` is the air at that height,
## `grounded` is a burst that hit something (sparks and debris go up, not down), `density` scales the smoke by what it
## hit, `turn` turns the pattern so two bursts side by side are not the same picture, and `lasts` is how long its smoke
## goes on for.
func set_off(at: Vector3, now: float, radius: float, wind: Vector3, grounded: bool, density: float, turn: float,
		lasts: float) -> void:
	global_position = at
	born = now
	fireball = radius
	_wind = wind
	_grounded = 1.0 if grounded else 0.0
	_turn = turn
	_density = density
	_lasts = lasts
	_write()
	until = now + lasts
	visible = true


## THE YARD'S LOOK AT IT, once a frame: itself away when its time is up. True while it is going.
func keep_going(now: float) -> bool:
	if not visible:
		return false
	if now >= until:
		visible = false
		return false
	return true


## TAKEN BACK before its time, for the next explosion. See `BurstYard.set_off`.
func put_away() -> void:
	visible = false
	until = -1.0


func wear(fire_paint: ShaderMaterial, smoke_paint: ShaderMaterial) -> void:
	fire.material_override = fire_paint
	smoke.material_override = smoke_paint
	_write()


func _write() -> void:
	for node in [fire, smoke]:
		var drawn := node as MultiMeshInstance3D
		drawn.set_instance_shader_parameter("born", born)
		drawn.set_instance_shader_parameter("size", fireball)
		drawn.set_instance_shader_parameter("wind", _wind)
		drawn.set_instance_shader_parameter("grounded", _grounded)
		drawn.set_instance_shader_parameter("turn", _turn)
	smoke.set_instance_shader_parameter("density", _density)
	smoke.set_instance_shader_parameter("life", _lasts)


func _instance_of(mesh: MultiMesh, called: String) -> MultiMeshInstance3D:
	var drawn := MultiMeshInstance3D.new()
	drawn.name = called
	drawn.multimesh = mesh
	drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# EVERYWHERE A SPARK OR THE SMOKE CAN GET TO in a burst's life, because every vertex is placed by the shader and the
	# box Godot would work out from the instances is a point. Three hundred metres covers a radar burst's smoke drifting
	# for fourteen seconds in the wind at a kilometre up.
	drawn.custom_aabb = AABB(Vector3(-300.0, -300.0, -300.0), Vector3(600.0, 600.0, 600.0))
	add_child(drawn)
	return drawn
