extends Node3D
class_name WakeYard
## EVERY MOVING HULL'S WAKE: white churned water astern, the Kelvin wedge of wave marks either side, and the bow wave --
## drawn by every machine from the poses it already has.
##
## Asked for on 2026-09-17: "boats/ships that are moving should have a noticeable wake, this should be a shader, and should
## make shaded marks for wake (but it doesn't need to actually create a wake), and a visible churned water usually lighter
## and white ... similar to the contrails we have for planes but for boats". So it is built as a contrail is.
##
## PURELY A PICTURE. Nothing is on the wire and nothing pushes on a hull: each machine lays a wake behind each craft it
## is already drawing, from the view `FlightLevel` has just placed.
##
## THE DECISION: A CONTRAIL LAID ON THE SEA. `ContrailYard` lays a segment behind each wingtip every fifth of a second into
## one MultiMesh the GPU ages; this lays a piece of wake behind each stern every `WakeTuning.WAKE_SAMPLE_EVERY` into one
## MultiMesh (wake.gdshader) that widens and fades each piece from its own age, on `MissileYard`'s clock, so a frozen
## level freezes its wakes as it freezes its contrails. The newest piece is rewritten every frame to reach the stern, so
## the churn is always joined to the hull, and a second MultiMesh (wake_bow.gdshader) draws one quad under each moving
## hull for the bow wave and the white water along its sides. Two draw calls for every wake in the sky.
##
## REJECTED -- see research/wakes.md: a foam mask rendered around the eye and read by the ocean shaders, which is the
## better picture close to (the wake is IN the water) but a second camera pass every frame and an edit to both ocean
## shaders, which other lanes own; displacing the sea with real Kelvin waves, which the simulation would not float a hull
## on and so would draw a deck dry in a sea that covered it; and particles for the churn, which cannot lie flat on a swell.
##
## WHO WAKES is `WakeTuning.wake_strength`: a hull whose bottom is in the water and which is moving through it, whatever
## its kind -- ships, the submarine on the surface, and the tanker when it is afloat.

## HOW MANY HULLS CAN HAVE A BOW WAVE AT ONCE: the bow drawer's size.
const BOWS: int = 96

const TRAIL_SHADER: Shader = preload("res://world/shaders/wake.gdshader")
const BOW_SHADER: Shader = preload("res://world/shaders/wake_bow.gdshader")

var _missiles: MissileYard = null
var _trail: MultiMeshInstance3D = null
var _bows: MultiMeshInstance3D = null
var _trail_material: ShaderMaterial = null
var _bow_material: ShaderMaterial = null
var _next_segment: int = 0
var _laid: int = 0
## Each craft being followed: entity -> {"due", "strength", and while it wakes: "from" (the stern on the water when the
## newest piece began), "laid", "odometer", "head" (the growing piece), "was", "speed_was" and "across_was" (the older
## end's strength, speed and across), "velocity", "segments", "bow" (its bow slot)}.
var _following: Dictionary = {}
## The craft with a growing piece at the last look, the only ones touched between looks; and when the next look is.
var _moving: Array = []
var _next_look: float = -INF
## What each kind's hull is, worked out once: {"half", "length", "beam", "corners"}.
var _hulls: Dictionary = {}
var _free_bows: Array[int] = []
var _bows_used: int = 0


## KEEP THE MISSILE YARD'S TIME, as the contrails do. Handed by the level before this is added.
func follow(missiles: MissileYard) -> void:
	_missiles = missiles


func _ready() -> void:
	_trail_material = _dressed(TRAIL_SHADER)
	_bow_material = _dressed(BOW_SHADER)
	_trail = _drawer("Wakes", WakeTuning.WAKE_SEGMENTS, 1, 12, _trail_material)
	_bows = _drawer("BowWaves", BOWS, 8, 8, _bow_material)
	for i in range(BOWS - 1, -1, -1):
		_free_bows.append(i)
	var finish: Node = get_node_or_null("/root/Finish")
	if finish != null:
		finish.connect("changed", _wear)
		_wear(bool(finish.call("is_fine")))


## ONE FRAME. `views` is the level's entity -> VehicleView, every one already placed this frame.
func lay(views: Dictionary) -> void:
	if _missiles == null:
		return
	var now: float = _missiles.clock()
	_trail_material.set_shader_parameter("now", now)
	_bow_material.set_shader_parameter("now", now)
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	var near_squared: float = WakeTuning.WAKE_NEAR * WakeTuning.WAKE_NEAR
	# EVERY CRAFT ONLY EVERY `LOOK_EVERY`, which is when a piece falls due; between, only the hulls whose newest piece
	# grows. A clock that went backwards is a new clock.
	var looking: bool = now >= _next_look or now < _next_look - WakeTuning.LOOK_EVERY
	if looking:
		_next_look = now + WakeTuning.LOOK_EVERY
	var moving: Array = []
	for entity in (views.keys() if looking else _moving):
		var view: VehicleView = views.get(entity, null)
		if view == null:
			continue
		var hull: Dictionary = _hull_of(view.kind)
		if hull.is_empty():
			continue
		var record: Dictionary = _following.get(entity, {})
		if record.is_empty():
			# STAGGERED by the entity, as the contrails are, so a fleet that appeared on one frame does not lay on one.
			record = {"strength": 0.0, "segments": 0, "seed": float(int(entity) % 97) * 0.113,
				"due": now + fmod(float(int(entity)) * 0.041, WakeTuning.WAKE_SAMPLE_EVERY)}
			_following[entity] = record
		var pose: Transform3D = view.global_transform
		if looking and now >= float(record["due"]):
			_sample(int(entity), record, pose, hull, now)
		elif record.has("head") and (camera == null or pose.origin.distance_squared_to(eye) < near_squared):
			_grow(record, pose, hull, now)
		if record.has("head"):
			moving.append(entity)
	_moving = moving
	if looking and _following.size() > views.size():
		for entity in _following.keys():
			if not views.has(entity):
				_let_go(_following[entity])
				_following.erase(entity)


## EVERY HALF SECOND: how strongly this hull wakes now, and the piece that was growing is left where it is.
func _sample(entity: int, record: Dictionary, pose: Transform3D, hull: Dictionary, now: float) -> void:
	record["due"] = now + WakeTuning.WAKE_SAMPLE_EVERY
	var water: float = Terrain.water_height(pose.origin)
	var velocity: Vector3 = ((Sim.current.get(entity, {}) as Dictionary).get("velocity", Vector3.ZERO)) as Vector3
	var speed: float = Vector2(velocity.x, velocity.z).length()
	record["velocity"] = velocity
	var strength: float = 0.0
	if water > -INF:
		var bottom: float = INF
		for corner in hull["corners"]:
			bottom = minf(bottom, (pose * (corner as Vector3)).y)
		var top: float = (pose * Vector3(0.0, (hull["half"] as Vector3).y, 0.0)).y
		strength = WakeTuning.wake_strength(bottom - water, top - water, speed)
		# IN THE WATER, or only skimming it: a streak has a churn and no Kelvin waves. See wake.gdshader.
		record["in_the_water"] = bottom - water <= WakeTuning.WAKE_TOUCH
	var was: float = float(record["strength"])
	record["strength"] = strength
	record["water"] = water
	if record.has("head"):
		# THE GROWING PIECE STAYS WHERE IT IS, ending at this sample's strength; the next begins at the stern.
		_grow(record, pose, hull, now)
		var stern: Vector3 = _stern(pose, hull, float(record["water"]))
		record["odometer"] = fmod(float(record["odometer"]) + Vector2(stern.x - (record["from"] as Vector3).x,
			stern.z - (record["from"] as Vector3).z).length(), WakeTuning.WAKE_TRACK_WRAP)
		record["from"] = stern
		record["laid"] = now
		record["was"] = strength
		record["speed_was"] = speed
		record["across_was"] = _across(pose, velocity)
		if strength > 0.0:
			record["head"] = _take_a_segment()
			record["segments"] = int(record["segments"]) + 1
		else:
			record.erase("head")
			_let_go(record)
	elif strength > 0.0 and was <= 0.0:
		# A HULL GETTING UNDER WAY begins its wake at its stern.
		record["from"] = _stern(pose, hull, water)
		record["laid"] = now
		record["was"] = 0.0
		record["speed_was"] = speed
		record["across_was"] = _across(pose, velocity)
		record["odometer"] = float(record.get("odometer", 0.0))
		record["head"] = _take_a_segment()
		record["segments"] = int(record["segments"]) + 1
	_place_bow(record)


## THE NEWEST PIECE, from where it began to the stern now, and the bow quad under the hull.
func _grow(record: Dictionary, pose: Transform3D, hull: Dictionary, now: float) -> void:
	var stern: Vector3 = _stern(pose, hull, float(record["water"]))
	var from: Vector3 = record["from"]
	var along := Vector3(stern.x - from.x, 0.0, stern.z - from.z)
	if along.length() < 0.01:
		var ahead: Vector3 = -pose.basis.z
		along = Vector3(ahead.x, 0.0, ahead.z).normalized() * 0.01
	var middle: Vector3 = (from + stern) * 0.5
	var velocity: Vector3 = record.get("velocity", Vector3.ZERO)
	var speed: float = Vector2(velocity.x, velocity.z).length()
	_trail.multimesh.set_instance_transform(int(record["head"]),
		Transform3D(_basis(along, float(hull["length"]), float(hull["beam"])), middle))
	_trail.multimesh.set_instance_custom_data(int(record["head"]),
		Color(float(record["laid"]), now, float(record["across_was"]), _across(pose, velocity)))
	_trail.multimesh.set_instance_color(int(record["head"]),
		Color(packed(float(record["speed_was"]), float(record["was"])), packed(speed, float(record["strength"])),
			float(record["odometer"]), _seed(record) * (1.0 if bool(record.get("in_the_water", true)) else -1.0)))
	if record.has("bow"):
		_bows.multimesh.set_instance_transform(int(record["bow"]),
			Transform3D(_bow_basis(pose, hull), _midships(pose, float(record["water"]))))
		var odometer: float = fmod(float(record["odometer"]) + along.length(), WakeTuning.WAKE_TRACK_WRAP)
		_bows.multimesh.set_instance_custom_data(int(record["bow"]),
			Color(speed, float(record["strength"]), _seed(record), odometer))


## A HULL THAT WAKES takes a bow slot, if one is free; one that has stopped gives its back.
func _place_bow(record: Dictionary) -> void:
	if float(record["strength"]) > 0.0 and not record.has("bow") and not _free_bows.is_empty():
		record["bow"] = _free_bows.pop_back()
		_bows_used = maxi(_bows_used, int(record["bow"]) + 1)
		_bows.multimesh.visible_instance_count = _bows_used
	elif float(record["strength"]) <= 0.0:
		_let_go(record)


## A HULL THAT STOPPED OR WENT AWAY gives its bow slot back. Its wake stays where it was laid and fades on its own.
func _let_go(record: Dictionary) -> void:
	if not record.has("bow"):
		return
	var slot: int = int(record["bow"])
	_bows.multimesh.set_instance_custom_data(slot, Color(0.0, 0.0, 0.0, 0.0))
	_free_bows.append(slot)
	record.erase("bow")


## WHERE THE STERN MEETS THE WATER: the middle of the hull box's after edge, on the still water.
func _stern(pose: Transform3D, hull: Dictionary, water: float) -> Vector3:
	var at: Vector3 = pose * Vector3(0.0, 0.0, (hull["half"] as Vector3).z)
	return Vector3(at.x, water, at.z)


func _midships(pose: Transform3D, water: float) -> Vector3:
	return Vector3(pose.origin.x, water, pose.origin.z)


## A SPEED AND A STRENGTH IN ONE FLOAT, as the wake shader unpacks them: floor(speed x 64) + strength, the strength held
## under 1 so it stays the fraction. A 32-bit float keeps a sixty-fourth of a metre a second and a strength to four figures
## up to 128 m/s, faster than any hull.
static func packed(speed: float, strength: float) -> float:
	return floorf(clampf(speed, 0.0, 127.0) * 64.0) + clampf(strength, 0.0, 0.999)


## WHICH WAY IS ACROSS THE TRACK, as the wake shader reads it: an angle from world +x toward +z, square to the way the hull
## is moving over the water, or to its heading when it is barely moving.
static func _across(pose: Transform3D, velocity: Vector3) -> float:
	var way := Vector3(velocity.x, 0.0, velocity.z)
	if way.length() < 0.5:
		way = -pose.basis.z
		way.y = 0.0
	if way.length() < 0.001:
		way = Vector3.FORWARD
	way = way.normalized()
	return atan2(way.x, -way.z)


## A PIECE'S BASIS, which the shader reads: X the piece, level; Y up, the ship's length long; Z level and square, the
## beam long. Invertible, which `BILLBOARD_LOCAL_OF` needs.
static func _basis(along: Vector3, length: float, beam: float) -> Basis:
	var across: Vector3 = along.normalized().cross(Vector3.UP).normalized()
	return Basis(along, Vector3.UP * length, across * beam)


## A BOW QUAD'S BASIS: X the heading, level, the ship's length long; Y up, the beam long; Z level and square, a metre.
static func _bow_basis(pose: Transform3D, hull: Dictionary) -> Basis:
	var ahead: Vector3 = -pose.basis.z
	ahead = Vector3(ahead.x, 0.0, ahead.z)
	if ahead.length() < 0.001:
		ahead = Vector3.FORWARD
	ahead = ahead.normalized()
	var hole: float = 1.0 if bool(hull.get("holed", false)) else 0.01
	return Basis(ahead * float(hull["length"]), Vector3.UP * float(hull["beam"]), ahead.cross(Vector3.UP).normalized() * hole)


## WHICH WAKE, so two wakes side by side do not froth alike: set from the entity when it is first followed.
func _seed(record: Dictionary) -> float:
	return maxf(float(record.get("seed", 0.0)), 0.001)


## WHAT A KIND'S HULL IS, for its wake: the simulation's hull box, its length and beam, and the four bottom corners its depth in the water is measured from. Empty for a kind that is not drawn.
func _hull_of(kind: int) -> Dictionary:
	if not _hulls.has(kind):
		var hull: Dictionary = {}
		if VehicleCatalogue.is_drawn(kind):
			var geometry: Dictionary = Sim.geometry_of(kind)
			var half: Vector3 = geometry.get("extents", Vector3.ONE) as Vector3
			hull = {"half": half, "length": half.z * 2.0, "beam": waterline_beam(geometry), "holed": has_hull_parts(geometry),
				"corners": [Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z),
					Vector3(-half.x, -half.y, half.z), Vector3(half.x, -half.y, half.z)]}
		_hulls[kind] = hull
	return _hulls[kind]


## THE BEAM A WAKE IS AS WIDE AS: the widest of the kind's HULL parts, which is the hull in the water -- a carrier's hull
## box is its 77 m flight deck, and a churn that wide read as a white road twice the ship (first pictures, 2026-09-17) --
## or the hull box's width for a kind drawn as one box.
static func waterline_beam(geometry: Dictionary) -> float:
	var widest: float = 0.0
	for part in (geometry.get("parts", []) as Array):
		if String((part as Dictionary).get("part", "")) != "hull":
			continue
		for corner in ((part as Dictionary).get("outline", PackedVector2Array()) as PackedVector2Array):
			widest = maxf(widest, absf(corner.x))
	if widest <= 0.0:
		widest = ((geometry.get("extents", Vector3.ONE)) as Vector3).x
	return widest * 2.0


## WHETHER A KIND IS DRAWN WITH HULL PARTS -- a waterline outline -- rather than as one box.
static func has_hull_parts(geometry: Dictionary) -> bool:
	for part in (geometry.get("parts", []) as Array):
		if String((part as Dictionary).get("part", "")) == "hull":
			return true
	return false


## ---- the drawers -------------------------------------------------------------------

func _dressed(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("kelvin_tan", tan(deg_to_rad(WakeTuning.WAKE_KELVIN_DEGREES)))
	material.set_shader_parameter("whiteness", WakeTuning.WAKE_WHITENESS)
	material.set_shader_parameter("arm_strength", WakeTuning.WAKE_ARM_STRENGTH)
	material.set_shader_parameter("arm_width", WakeTuning.WAKE_ARM_WIDTH)
	material.set_shader_parameter("lift", WakeTuning.WAKE_LIFT)
	material.set_shader_parameter("pull", WakeTuning.WAKE_PULL)
	material.set_shader_parameter("track_wrap", WakeTuning.WAKE_TRACK_WRAP)
	material.set_shader_parameter("churn_spread", WakeTuning.WAKE_CHURN_SPREAD)
	material.set_shader_parameter("churn_share", WakeTuning.WAKE_CHURN_SHARE)
	material.set_shader_parameter("transverse_strength", WakeTuning.WAKE_TRANSVERSE_STRENGTH)
	material.set_shader_parameter("bow_strength", WakeTuning.WAKE_BOW_STRENGTH)
	material.set_shader_parameter("life_per_metre", WakeTuning.WAKE_LIFE_PER_METRE)
	material.set_shader_parameter("life_least", WakeTuning.WAKE_LIFE_LEAST)
	material.set_shader_parameter("life_most", WakeTuning.WAKE_LIFE_MOST)
	material.set_shader_parameter("streak_life", WakeTuning.WAKE_SKIM_LIFE)
	material.set_shader_parameter("streak_width", WakeTuning.WAKE_SKIM_WIDTH)
	# THE SEA IT LIES ON, handed as the seas are handed theirs: see sea_surface.gdshaderinc.
	material.set_shader_parameter("land_half", Terrain.WORLD_HALF)
	material.set_shader_parameter("wind", Terrain.SWELL_HEADING)
	SeaSwell.hand_the_swell(material)
	return material


func _drawer(called: String, count: int, along: int, across: int, material: ShaderMaterial) -> MultiMeshInstance3D:
	var strip := QuadMesh.new()
	strip.size = Vector2(1.0, 1.0)
	strip.subdivide_width = along
	strip.subdivide_depth = across
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.use_colors = true
	many.mesh = strip
	many.instance_count = count
	for i in range(count):
		many.set_instance_transform(i, MissileYard.NOWHERE)
		many.set_instance_custom_data(i, Color(-100000.0, -100000.0, 0.0, 0.0))
	many.visible_instance_count = 0
	var drawer := MultiMeshInstance3D.new()
	drawer.name = called
	drawer.multimesh = many
	drawer.material_override = material
	drawer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drawer.custom_aabb = TrailTuning.culling_box()
	add_child(drawer)
	return drawer


func _take_a_segment() -> int:
	var index: int = _next_segment
	_next_segment = (_next_segment + 1) % WakeTuning.WAKE_SEGMENTS
	if _laid < WakeTuning.WAKE_SEGMENTS:
		_laid += 1
		_trail.multimesh.visible_instance_count = _laid
	return index


## THE FINE SEA'S CHOP, so a wake rides it: its `swell_steepness`, read off the shader that has it, on FINE; none on PLAIN.
func _wear(fine: bool) -> void:
	var chop: float = 0.0
	if fine:
		var steep: Variant = RenderingServer.shader_get_parameter_default(SeaSwell.SHADER.get_rid(), "swell_steepness")
		chop = float(steep) if steep != null else 0.0
	for material in [_trail_material, _bow_material]:
		(material as ShaderMaterial).set_shader_parameter("chop_steepness", chop)


## ---- the time of day ---------------------------------------------------------------

## THE LIGHT A WAKE IS DRAWN IN, handed over by the level once per change of the time of day: the contrails' (foam is
## lit by the same sun and sky as cloud), so a wake at night is as dim as the sea round it.
func show_daylight(look: Dictionary) -> void:
	var light: Vector3 = ContrailYard.light_at(look)
	_trail.set_instance_shader_parameter("light", light)
	_bows.set_instance_shader_parameter("light", light)


## ---- for the tests and the boards -------------------------------------------------

## How strongly this craft was last found to be waking, 0 to 1; -1 for one not followed or not yet sampled.
func strength_of(entity: int) -> float:
	var record: Dictionary = _following.get(entity, {})
	return float(record.get("strength", -1.0)) if record.has("water") else -1.0


## THE STILL WATER THIS CRAFT'S WAKE WAS LAST LAID ON, metres: the sea's level, a lake's, or -INF over dry land; NAN for one
## not yet sampled.
func water_under(entity: int) -> float:
	return float((_following.get(entity, {}) as Dictionary).get("water", NAN))


## How many pieces of wake have been laid behind this craft since it was first followed.
func pieces_behind(entity: int) -> int:
	return int((_following.get(entity, {}) as Dictionary).get("segments", 0))


## Whether this craft has a bow wave drawn under it now.
func has_a_bow_wave(entity: int) -> bool:
	return (_following.get(entity, {}) as Dictionary).has("bow")


## How many pieces of wake have been laid, up to the drawer's size.
func pieces_laid() -> int:
	return _laid


## THE SEA A WAKE IS DRAWN ON, for the test that holds it to the seas': the material's parameter by name.
func material_parameter(called: String) -> Variant:
	return _trail_material.get_shader_parameter(called)
