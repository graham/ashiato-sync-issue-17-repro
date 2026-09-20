extends Node3D
class_name Burst
## WHAT IS LEFT WHERE A ROUND STOPPED.
##
## One node, reused. A 25 mm cannon asks for thirty of these a second, and building thirty
## scenes a second -- each with a handful of meshes and materials -- is the one way to make
## a gun cost frames. So a burst is POOLED: it is set going, it runs its life, and it goes
## back in the drawer with its meshes intact. See `ShotYard`, which owns the drawer.
##
## Everything here is unshaded transparent geometry and nothing is a light. A dozen point
## lights was a slideshow on the Mobile renderer this was written for (untimed on Forward+, the
## renderer since 2026-09-14), and an explosion is bright enough to read as
## bright without lighting anything else.

## The pieces, all built once in `_ready` and hidden between bursts.
var _fire: MeshInstance3D = null
var _flash: MeshInstance3D = null
var _dust: MeshInstance3D = null
var _smoke: Array[MeshInstance3D] = []
var _sparks: Array[MeshInstance3D] = []

var _look: Dictionary = {}
var _ground: Dictionary = {}
var _age: float = 0.0
var _life: float = 0.0
var _spark_at: Array[Vector3] = []

const SMOKE_PUFFS: int = 5
const SPARKS: int = 40


func _ready() -> void:
	_fire = _ball(Color(1.0, 0.6, 0.2))
	_flash = _ball(Color(1.0, 1.0, 0.9))
	_dust = _disc()
	for i in range(SMOKE_PUFFS):
		_smoke.append(_ball(Color(0.35, 0.33, 0.31)))
	for i in range(SPARKS):
		_sparks.append(_streak())
	visible = false
	set_process(false)


## SET IT OFF. `look` is the round's row and `ground` is the surface's, and the two multiply
## -- see Ammunition -- so the same shell is a dust ring in a field, a column on water and
## a spray of sparks off armour.
func light(at: Vector3, look: Dictionary, ground: Dictionary) -> void:
	global_position = at
	_look = look
	_ground = ground
	_age = 0.0
	_life = float(look.get("seconds", 1.5))
	_spark_at.clear()
	var count: int = int(round(float(look.get("sparks", 0)) * float(ground.get("sparks", 1.0))))
	for i in range(_sparks.size()):
		var lit: bool = i < count
		_sparks[i].visible = lit
		if not lit:
			continue
		# UP AND OUT, never down: a spark that goes into the ground is a spark nobody sees,
		# and half of them doing it makes the whole thing look thin.
		var away := Vector3(randf_range(-1.0, 1.0), randf_range(0.15, 1.0),
			randf_range(-1.0, 1.0)).normalized()
		_spark_at.append(away * float(look.get("spark_speed", 20.0))
			* randf_range(0.4, 1.0))
	visible = true
	set_process(true)
	_draw(0.0)


## START IT PART-WAY THROUGH, because it already happened.
##
## A burst played from a CUE is being drawn on a machine that heard about the moment a
## fraction of a second after it happened -- so it starts that far in rather than at the
## beginning, exactly as `ShotYard` winds a round's flight forward by the same number. An
## effect that always began at its start would be an effect that lags the wire.
##
## Zero on a solo session, which is most of them, and zero for every burst that is played
## from an impact record rather than a cue: those carry their own timing in the record.
func wind_on(late: float) -> void:
	if late <= 0.0 or _life <= 0.0:
		return
	_age = clampf(late, 0.0, _life)
	if _age >= _life:
		visible = false
		set_process(false)
		return
	_draw(_age / _life)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		visible = false
		set_process(false)
		return
	_draw(_age / _life)


## One frame of it, at `t` from 0 to 1. Everything here is the same shape of curve: out
## fast, fade slow, which is what an explosion does and what a linear one never looks like.
func _draw(t: float) -> void:
	var fast: float = 1.0 - pow(1.0 - t, 3.0)
	var fade: float = 1.0 - t

	# THE FLASH: everything has one, and it is over in the first tenth. It is what makes a
	# sabot round -- which has no fireball at all -- still read as an impact.
	var flash: float = float(_look.get("flash", 2.0))
	var flashing: float = clampf(1.0 - t * 8.0, 0.0, 1.0)
	_flash.visible = flashing > 0.0 and flash > 0.0
	if _flash.visible:
		_size(_flash, flash * (0.4 + fast * 0.6))
		_tint(_flash, _look.get("flash_colour", Color.WHITE), flashing)

	# THE FIREBALL, for the rounds that have one. Sabot and canister do not.
	var fire: float = float(_look.get("fireball", 0.0))
	_fire.visible = fire > 0.0
	if _fire.visible:
		_size(_fire, fire * (0.25 + fast * 0.75))
		# Orange to dark, which is a fireball turning into its own smoke.
		var hot: Color = _look.get("fire_colour", Color(1.0, 0.6, 0.2))
		_tint(_fire, hot.lerp(Color(0.22, 0.16, 0.13), t), fade * 0.9)

	# THE RING OF DUST, kicked out flat along the ground.
	var dust: float = float(_look.get("dust", 0.0)) * float(_ground.get("dust", 1.0))
	_dust.visible = dust > 0.0
	if _dust.visible:
		# WATER GOES UP AND DIRT GOES OUT, which is the difference between a splash and a
		# dust ring: half a tonne arriving at thirty metres a second throws a sheet, and it
		# stands well above what it hit before it falls back.
		var sheet: bool = bool(_look.get("wet", false))
		_dust.scale = Vector3(dust * fast, dust * (0.55 if sheet else 0.16) * (0.3 + t),
			dust * fast)
		# THE ROUND'S OWN COLOUR IF IT HAS ONE, and the surface's otherwise. A shell throws
		# up whatever it landed on; water throws up water, on a field or on a road.
		_tint(_dust, _look.get("dust_colour",
			_ground.get("dust_colour", Color(0.6, 0.54, 0.42))), fade * 0.55)

	# AND THE SMOKE, which is the only part that outlives the noise.
	var smoke: float = float(_look.get("smoke", 0.0)) * float(_ground.get("smoke", 1.0))
	for i in range(_smoke.size()):
		var puff: MeshInstance3D = _smoke[i]
		puff.visible = smoke > 0.0
		if not puff.visible:
			continue
		var lean: float = float(i) / float(_smoke.size())
		puff.position = Vector3(sin(lean * TAU) * smoke * 0.22 * fast,
			smoke * (0.25 + lean) * fast, cos(lean * TAU) * smoke * 0.22 * fast)
		_size(puff, smoke * (0.18 + lean * 0.2) * (0.4 + fast))
		_tint(puff, Color(0.30, 0.28, 0.26), fade * 0.5)

	# SPARKS, thrown out and falling. They are what an inert round has instead of a bang.
	#
	# EVERYTHING HERE IS LOCAL TO THE BURST, and that is the fix for a bug that had been in
	# every explosion in the game: this used `look_at_from_position`, which -- as its own
	# documentation says -- MOVES the node in GLOBAL space. Handed a position meant as an
	# offset from the burst, it teleported every spark to that offset from the WORLD ORIGIN.
	# Nobody saw it because sparks are small and additive and the origin is out at sea; what
	# showed it was a water bomber dropping at forty metres and a handful of white specks
	# appearing on a hillside a kilometre away.
	for i in range(_spark_at.size()):
		var spark: MeshInstance3D = _sparks[i]
		var flew: Vector3 = _spark_at[i] * t
		spark.position = Vector3(flew.x, flew.y - 9.81 * t * t * 0.5, flew.z)
		# Along its own flight, in the burst's frame. A basis rather than look_at for the
		# same reason: the one that takes a target is a GLOBAL operation.
		spark.basis = Basis.looking_at(_spark_at[i].normalized(), Vector3.UP)
		spark.scale = Vector3(1.0, 1.0, 1.0 + _spark_at[i].length() * 0.04)
		_tint(spark, _look.get("tracer", Color(1.0, 0.9, 0.6)), fade)


## ---- the pieces ------------------------------------------------------------------

func _ball(tint: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 10
	ball.rings = 6
	node.mesh = ball
	node.material_override = _glow(tint)
	add_child(node)
	return node


func _disc() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 1.0
	disc.radial_segments = 14
	node.mesh = disc
	node.material_override = _glow(Color(0.6, 0.54, 0.42))
	add_child(node)
	return node


func _streak() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var bit := BoxMesh.new()
	bit.size = Vector3(0.10, 0.10, 0.55)
	node.mesh = bit
	node.material_override = _glow(Color(1.0, 0.9, 0.6))
	add_child(node)
	return node


func _glow(tint: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# ADDITIVE for fire and sparks: two overlapping flames are brighter than one, which is
	# the difference between an explosion and a pile of orange balls.
	paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	paint.albedo_color = tint
	return paint


static func _size(node: MeshInstance3D, across: float) -> void:
	node.scale = Vector3(across, across, across)


static func _tint(node: MeshInstance3D, colour: Color, alpha: float) -> void:
	var paint := node.material_override as StandardMaterial3D
	paint.albedo_color = Color(colour.r, colour.g, colour.b, clampf(alpha, 0.0, 1.0))
