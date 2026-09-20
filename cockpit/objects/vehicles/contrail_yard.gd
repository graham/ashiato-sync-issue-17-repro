extends Node3D
class_name ContrailYard
## EVERY AIRCRAFT'S CONTRAIL ABOVE 300 METRES, DRAWN BY EVERY MACHINE FROM WHAT EVERY MACHINE ALREADY HAS.
##
## PURELY A PICTURE. Nothing about a contrail is on the wire: each machine lays one behind each aeroplane it is already
## drawing, from the view `FlightLevel` has just placed, so every viewer derives the same trail from the same poses and
## there is nothing to send and nothing to disagree about.
##
## THE DECISION: IT IS A MISSILE'S TRAIL, WORN SHORTER. `MissileYard` draws every missile trail as one MultiMesh of
## segments the GPU ages; this is a second MultiMesh of the same segments, wearing THAT yard's two trail materials and
## stamped on THAT yard's clock. So it adds no shader, no per-frame material write (the one `now` the missile yard
## already writes serves both) and no second idea of how old a segment is. What makes it shorter is one instance
## uniform on this node, `lasting`, set once to `TrailTuning.CONTRAIL_SHARE`.
##
## REJECTED: materials of its own, which is a second `now` written every frame and a second life to keep shorter than
## the first; and a segment growing behind the wingtip every frame the way a missile's grows behind its nozzle, which
## is a transform write per aircraft per frame for a gap nobody can see from a cockpit.
##
## NO SEGMENT GROWS. A segment is laid every `CONTRAIL_SAMPLE_EVERY` and never touched again. Its strength -- height,
## speed, nacelles -- is handed to the drawer at BOTH ENDS, in the instance colour, and the shaders fade a contrail in and
## out from each pixel's own age (`TrailTuning.CONTRAIL_FORMING`), so where one segment meets the next there is nothing
## to step. BEFORE 2026-09-14 a segment carried one strength, the mean of its ends, in the custom alpha, and thickened in
## as a whole by the age of its newer end: neighbours at the head stood 0.4 apart, a trail crossing the band stepped at
## every join, and "it's a little obvious they are chunky".
##
## LIT BY THE TIME OF DAY, as a cloud is: `show_daylight` writes `light_at` onto this node once per change. Unshaded, a
## contrail was as white against the night as against noon.
##
## FROM THE WINGTIPS, where a view's `wingtips()` says its red and green lights stand: neither the catalogue nor the
## simulation's shape table knows where an engine is, and a wingtip is a real place for a trail to leave.
##
## WHAT IT LEAVES OUT: anything without a wing, gliders (`VehicleSound.has_an_engine`), and a tiltrotor once its
## nacelles are half way up.

var _missiles: MissileYard = null
var _trail: MultiMeshInstance3D = null
var _next_segment: int = 0
var _laid: int = 0
## Each aircraft being followed: entity -> {"ends": [Vector3, Vector3], "laid": clock, "due": clock, "strength": 0..1,
## "segments": int}. "laid" is when the ends were taken; "due" when the next segment is.
var _laying: Dictionary = {}
## Wingtips by kind, worked out once: an empty array is a kind that leaves no contrail.
var _tips: Dictionary = {}


## WEAR WHAT THE MISSILE YARD WEARS, and keep its time. Handed by the level before this is added.
func follow(missiles: MissileYard) -> void:
	_missiles = missiles


func _ready() -> void:
	_build_the_trail()
	var fine: bool = false
	var finish: Node = get_node_or_null("/root/Finish")
	if finish != null:
		finish.connect("changed", _wear)
		fine = bool(finish.call("is_fine"))
	_wear(fine)
	# ONCE, FOR GOOD: how much of a missile trail's life this node's trails last, how long a new one takes to come in,
	# and how long nothing is there yet -- one sample, so the segment just laid is nothing at its newer end.
	_trail.set_instance_shader_parameter("lasting", TrailTuning.CONTRAIL_SHARE)
	_trail.set_instance_shader_parameter("forming", TrailTuning.CONTRAIL_FORMING)
	_trail.set_instance_shader_parameter("forming_from", TrailTuning.CONTRAIL_SAMPLE_EVERY)


## ONE FRAME. `views` is the level's entity -> VehicleView, every one already placed this frame.
func lay(views: Dictionary) -> void:
	if _missiles == null:
		return
	var now: float = _missiles.clock()
	for entity in views:
		var view: VehicleView = views[entity]
		var tips: Array = _tips_for(view)
		if tips.is_empty():
			continue
		var record: Dictionary = _laying.get(entity, {})
		if record.is_empty():
			# A FIRST SIGHT IS STAGGERED by the entity, so a sky full of aeroplanes that all appeared on one frame does
			# not lay every segment on one frame for ever after.
			record = {"segments": 0, "due": now + fmod(float(int(entity)) * 0.037, TrailTuning.CONTRAIL_SAMPLE_EVERY)}
			_laying[entity] = record
		elif now < float(record["due"]):
			continue
		var strength: float = _strength(int(entity), view)
		var ends: Array = [view.global_transform * (tips[0] as Vector3), view.global_transform * (tips[1] as Vector3)]
		if record.has("ends"):
			var was: float = float(record["strength"])
			# BOTH ENDS OUT OF THE BAND lays nothing; one in is a segment that fades from the one to the other.
			if was > 0.0 or strength > 0.0:
				var seed: float = float(int(entity) % 97) * 0.113
				for i in range(2):
					_set_segment(_take_a_segment(), record["ends"][i] as Vector3, float(record["laid"]),
						ends[i] as Vector3, now, seed + float(i) * 0.5, was, strength)
				record["segments"] = int(record["segments"]) + 2
				var kept: Array = record.get("kept", [])
				kept.append({"from_laid": float(record["laid"]), "to_laid": now, "from_strength": was,
					"to_strength": strength})
				if kept.size() > LAID_KEPT:
					kept.pop_front()
				record["kept"] = kept
		record["ends"] = ends
		record["laid"] = now
		record["due"] = now + TrailTuning.CONTRAIL_SAMPLE_EVERY
		record["strength"] = strength
	# AN AIRCRAFT THAT WENT AWAY: its trail stays where it was laid and fades on its own.
	if _laying.size() > views.size():
		for entity in _laying.keys():
			if not views.has(entity):
				_laying.erase(entity)


## HOW STRONGLY THIS AIRCRAFT LEAVES A TRAIL NOW, 0 to 1: its height, its speed and, on a tiltrotor, its nacelles.
func _strength(entity: int, view: VehicleView) -> float:
	var strength: float = TrailTuning.contrail_at_height(view.global_position.y)
	if strength <= 0.0:
		return 0.0
	var state: Dictionary = Sim.current.get(entity, {})
	var speed: float = (state.get("velocity", Vector3.ZERO) as Vector3).length()
	strength *= smoothstep(TrailTuning.CONTRAIL_SPEED_FROM, TrailTuning.CONTRAIL_SPEED_TO, speed)
	if strength > 0.0 and Sim.client != null \
			and VehicleCatalogue.body(view.kind) == VehicleCatalogue.Body.TILTROTOR:
		var tilt: float = float(Sim.client.craft_controls(entity).get("tilt", 0.0))
		strength *= 1.0 - smoothstep(TrailTuning.CONTRAIL_TILT_FROM, TrailTuning.CONTRAIL_TILT_TO, tilt)
	return strength


func _tips_for(view: VehicleView) -> Array:
	if not _tips.has(view.kind):
		_tips[view.kind] = view.wingtips() if VehicleSound.has_an_engine(view.kind) else []
	return _tips[view.kind]


## ---- the segments -----------------------------------------------------------------

func _take_a_segment() -> int:
	var index: int = _next_segment
	_next_segment = (_next_segment + 1) % TrailTuning.CONTRAIL_SEGMENTS
	if _laid < TrailTuning.CONTRAIL_SEGMENTS:
		_laid += 1
		_trail.multimesh.visible_instance_count = _laid
	return index


## One segment, as `MissileYard._set_segment` lays one -- the custom alpha 1, as behind a missile -- with the strength at
## each end in the instance colour's red and green, which the shaders fade by from one end to the other.
func _set_segment(index: int, from: Vector3, from_laid: float, to: Vector3, to_laid: float, seed: float,
		from_strength: float, to_strength: float) -> void:
	# THE SAME BASIS AS A MISSILE'S TRAIL, from the one place that says why: see `MissileYard.segment_basis`.
	_trail.multimesh.set_instance_transform(index, Transform3D(MissileYard.segment_basis(to - from), (from + to) * 0.5))
	_trail.multimesh.set_instance_custom_data(index, Color(from_laid, to_laid, seed, 1.0))
	_trail.multimesh.set_instance_color(index, Color(from_strength, to_strength, 1.0, 1.0))


func _build_the_trail() -> void:
	var strip := QuadMesh.new()
	strip.size = Vector2(1.0, 1.0)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	# BEFORE THE COUNT: a MultiMesh will not start carrying custom data or colours once it has instances. The colours are
	# this drawer's alone; the missile yard's has none, and a drawer with none reads white in the shaders.
	many.use_custom_data = true
	many.use_colors = true
	many.mesh = strip
	many.instance_count = TrailTuning.CONTRAIL_SEGMENTS
	for i in range(TrailTuning.CONTRAIL_SEGMENTS):
		many.set_instance_transform(i, MissileYard.NOWHERE)
		many.set_instance_custom_data(i, Color(-100000.0, -100000.0, 0.0, 0.0))
	many.visible_instance_count = 0
	_trail = MultiMeshInstance3D.new()
	_trail.name = "Contrails"
	_trail.multimesh = many
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# THE WHOLE WORLD, worked out from the world: see `TrailTuning.culling_box`.
	_trail.custom_aabb = TrailTuning.culling_box()
	add_child(_trail)


func _wear(fine: bool) -> void:
	if _missiles != null:
		_trail.material_override = _missiles.trail_material(fine)


## ---- the time of day ---------------------------------------------------------------

## THE LIGHT A CONTRAIL IS DRAWN IN, handed over by the level once per change of the time of day. On this node, not on
## the trail materials it shares with the missile yard, so a missile's smoke is drawn as it always was.
func show_daylight(look: Dictionary) -> void:
	_trail.set_instance_shader_parameter("light", light_at(look))


## THE LIGHT A CONTRAIL HAS AT A TIME OF DAY, as a share of day's, per channel: the sun and the sky `LiftYard.cloud_light`
## lights a cloud's sunlit side with, taken to linear as the cloud shaders' `source_color` uniforms take them. A contrail
## is cloud, so it can never stand out brighter against the night than the clouds round it. Exactly white by day, which
## is the look it had; (0.013, 0.016, 0.025) at night; warm and dimmer at evening.
##
## REJECTED: a night factor of its own in `DaylightTuning`, which is a number that has to be kept agreeing with the
## sun and the sky beside it; and dimming the shared material, which dims every missile's smoke too.
static func light_at(look: Dictionary) -> Vector3:
	var lit: Vector3 = _cloud_lit(look)
	var day: Vector3 = _day_lit()
	return Vector3(lit.x / maxf(day.x, 0.0001), lit.y / maxf(day.y, 0.0001), lit.z / maxf(day.z, 0.0001))


## DAY's light, what every other is a share of: worked out once, since it never changes. Three yards ask on every step of
## the clock, and a whole look each time was a third of what a time-lapse step cost them (2026-09-18).
static var _day_lit_once := Vector3(-1.0, -1.0, -1.0)


static func _day_lit() -> Vector3:
	if _day_lit_once.x < 0.0:
		_day_lit_once = _cloud_lit(DaylightTuning.look_of(DaylightTuning.When.DAY))
	return _day_lit_once


static func _cloud_lit(look: Dictionary) -> Vector3:
	var light: Dictionary = LiftYard.cloud_light(look)
	var lit: Color = (light["sun_light"] as Color).srgb_to_linear() + (light["sky_light"] as Color).srgb_to_linear()
	return Vector3(lit.r, lit.g, lit.b)


## ---- for the tests and the boards -------------------------------------------------

## How strongly this aircraft was last found to be leaving a trail, 0 to 1; -1 for one not followed or not yet sampled.
func strength_of(entity: int) -> float:
	return float((_laying.get(entity, {}) as Dictionary).get("strength", -1.0))


## How many of the last segments behind each aircraft `laid_behind` remembers.
const LAID_KEPT: int = 16

## THE LAST SEGMENTS HANDED TO THE DRAWER BEHIND THIS AIRCRAFT, oldest first: when each end was laid and how strong.
func laid_behind(entity: int) -> Array:
	return (_laying.get(entity, {}) as Dictionary).get("kept", [])


## The light the contrails are drawn in, read off the drawer; null before the level has lit them.
func light() -> Variant:
	return _trail.get_instance_shader_parameter("light")


## How many segments have been laid behind this aircraft since it was first followed.
func segments_behind(entity: int) -> int:
	return int((_laying.get(entity, {}) as Dictionary).get("segments", 0))


## HOW LONG A CONTRAIL LASTS, in seconds, read off what it is drawn with: the worn material's `life` times this node's
## `lasting`. The same material `MissileYard.trail_lasts` reads, so the two answers cannot come from two numbers.
func lasts() -> float:
	var worn := _trail.material_override as ShaderMaterial
	if worn == null or worn.get_shader_parameter("life") == null:
		return 0.0
	return float(worn.get_shader_parameter("life")) * float(_trail.get_instance_shader_parameter("lasting"))


## How many contrail segments are laid, up to the drawer's size.
func contrail_segments() -> int:
	return _laid


## HOW MANY SEGMENTS ARE STILL DRAWN: laid within a contrail's life of the yard's clock. For the probe that sizes the
## drawer -- `contrail_segments` stops at the drawer's size once it has wrapped, which says nothing about how full it is.
## A walk over every segment, so never on a frame the level draws.
func segments_in_use() -> int:
	if _missiles == null:
		return 0
	var since: float = _missiles.clock() - lasts()
	var alive: int = 0
	for i in range(_laid):
		if _trail.multimesh.get_instance_custom_data(i).g >= since:
			alive += 1
	return alive


## What the contrails are wearing, read off the material rather than off the tier.
func wears_fine() -> bool:
	return _missiles != null and _trail.material_override == _missiles.trail_material(true)
