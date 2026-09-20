extends Node3D
class_name SprayYard
## WHITEWATER KICKED UP BY ANYTHING SKIMMING THE WATER FAST: a rooster tail of spray behind it and sheets thrown out to
## either side, rising and falling back. Asked for on 2026-09-17 -- "planes that are within 3 meters of the water that
## are moving faster than 80kph [should] have a dramatic kick up of whitewater ... no physics impact but it should look
## cool and be a GPU asset" -- with a Porco Rosso seaplane for the look.
##
## PURELY A PICTURE, drawn by every machine from the poses it already has; nothing on the wire, nothing pushes.
##
## WHO SPRAYS is `WakeTuning.spray_strength`, from how far the craft's LOWEST point is above the water under it -- the
## hull box's bottom corners and the wingtips, after its attitude, so a banked wingtip counts -- and how fast it goes. By
## where it is, never by its name: an aeroplane, the tanker skimming or scooping, a flying boat on its take-off run.
##
## THE DECISION: PUFFS THROWN ONCE AND FLOWN BY THE GPU. Every puff is one instance of one MultiMesh (spray.gdshader),
## written once when it is thrown -- where it left the water, when, and its velocity -- and never again: the shader works
## out where it has risen and fallen to from its age on `MissileYard`'s clock, so a frozen level freezes its spray as it
## freezes its contrails, and the processor's whole cost is the throwing. One draw call for every aircraft's spray.
##
## AND A WALL BEHIND IT (round 2, 2026-09-18, a Porco Rosso still for the look): one solid curtain of spray standing up
## behind the hull, several times its height, with a crisp billowing top -- SHEETS, a strip of pieces laid along the
## track where the craft meets the water and raised by spray_sheet.gdshader from their age on the same clock. The newest
## piece reaches to the hull every frame, which is one instance written per skimmer per frame. The puffs are what is
## thrown out at the hull beside it. Who gets it is the same rule: a slow hull on the water has its wake and nothing here.
##
## REJECTED: GPUParticles3D, one emitter per aircraft, which is the engine's own answer -- but its particles are placed
## in world space in float32, which on the double build steps a thing 9 km out on float32's grid (billboard.gdshaderinc),
## and it is one draw call and one process pass per aircraft; and puffs the processor moves every frame, which is a
## transform write per puff per frame for something the GPU can work out from a start and a clock.

const SHADER: Shader = preload("res://world/shaders/spray.gdshader")
const SHEET_SHADER: Shader = preload("res://world/shaders/spray_sheet.gdshader")
## How many columns across the track each piece of wall is drawn with: the V's curve, and room for its shading.
const SHEET_COLUMNS: int = 12

var _missiles: MissileYard = null
var _puffs: MultiMeshInstance3D = null
var _material: ShaderMaterial = null
var _next: int = 0
var _thrown_count: int = 0
var _was: float = 0.0
var _dice := RandomNumberGenerator.new()
## Each craft being followed: entity -> {"strength", "clearance", "owed" (puffs not yet thrown), "thrown"}.
var _following: Dictionary = {}
## The craft spraying at the last look, which are the only ones looked at between looks; and when the next look is.
var _spraying: Array = []
var _next_look: float = -INF
## Each kind's low points and half-extents, worked out once. Empty for a kind that is not drawn.
var _shapes: Dictionary = {}
## THE WALL: its pieces, the next one to take, and how many have ever been taken (the drawn count until the ring is full).
var _sheets: MultiMeshInstance3D = null
var _sheet_material: ShaderMaterial = null
var _sheet_next: int = 0
var _sheet_count: int = 0


## KEEP THE MISSILE YARD'S TIME. Handed by the level before this is added.
func follow(missiles: MissileYard) -> void:
	_missiles = missiles


func _ready() -> void:
	_dice.seed = 20260917
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("size_from", WakeTuning.SPRAY_SIZE_FROM)
	_material.set_shader_parameter("size_to", WakeTuning.SPRAY_SIZE_TO)
	_material.set_shader_parameter("whiteness", WakeTuning.SPRAY_WHITENESS)
	_material.set_shader_parameter("streak", WakeTuning.SPRAY_STREAK)
	_material.set_shader_parameter("drag", WakeTuning.SPRAY_DRAG)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.use_colors = true
	many.mesh = quad
	many.instance_count = WakeTuning.SPRAY_PUFFS
	for i in range(WakeTuning.SPRAY_PUFFS):
		many.set_instance_transform(i, Transform3D.IDENTITY)
		many.set_instance_custom_data(i, Color(-100000.0, 0.0, 0.0, 0.0))
		many.set_instance_color(i, Color(0.0, 0.0, 0.0, 0.0))
	many.visible_instance_count = 0
	_puffs = MultiMeshInstance3D.new()
	_puffs.name = "Spray"
	_puffs.multimesh = many
	_puffs.material_override = _material
	_puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_puffs.custom_aabb = TrailTuning.culling_box()
	add_child(_puffs)
	_sheets = _make_sheets()
	add_child(_sheets)


## THE WALL'S DRAWER: one MultiMesh of strips across the track, every piece collapsed until it is laid.
func _make_sheets() -> MultiMeshInstance3D:
	_sheet_material = ShaderMaterial.new()
	_sheet_material.shader = SHEET_SHADER
	var knobs: Dictionary = {"sheet_height": WakeTuning.SHEET_HEIGHT, "rise": WakeTuning.SHEET_RISE,
		"life": WakeTuning.SHEET_LIFE, "dissolve": WakeTuning.SHEET_DISSOLVE, "width": WakeTuning.SHEET_WIDTH,
		"spread": WakeTuning.SHEET_SPREAD, "lobe": WakeTuning.SHEET_LOBE, "billow": WakeTuning.SHEET_BILLOW,
		"crisp": WakeTuning.SHEET_CRISP, "holes": WakeTuning.SHEET_HOLES, "face_colour": WakeTuning.SHEET_FACE,
		"shadow_colour": WakeTuning.SHEET_SHADOW, "base_share": WakeTuning.SHEET_BASE,
		"lobe_shade": WakeTuning.SHEET_LOBE_SHADE, "contact": WakeTuning.SHEET_CONTACT,
		"contact_height": WakeTuning.SHEET_CONTACT_HEIGHT}
	for knob in knobs:
		_sheet_material.set_shader_parameter(knob, knobs[knob])
	var strip := PlaneMesh.new()
	strip.size = Vector2(2.0, 1.0)
	strip.subdivide_width = SHEET_COLUMNS - 1
	strip.subdivide_depth = 0
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.use_colors = true
	many.mesh = strip
	many.instance_count = WakeTuning.SHEET_PIECES
	for i in range(WakeTuning.SHEET_PIECES):
		many.set_instance_transform(i, Transform3D.IDENTITY)
		many.set_instance_custom_data(i, Color(-100000.0, -100000.0, 0.0, 0.0))
		many.set_instance_color(i, Color(0.0, 0.0, 0.0, 0.0))
	many.visible_instance_count = 0
	var sheets := MultiMeshInstance3D.new()
	sheets.name = "Sheets"
	sheets.multimesh = many
	sheets.material_override = _sheet_material
	sheets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheets.custom_aabb = TrailTuning.culling_box()
	return sheets


## ONE FRAME. `views` is the level's entity -> VehicleView, every one already placed this frame.
func lay(views: Dictionary) -> void:
	if _missiles == null:
		return
	var now: float = _missiles.clock()
	_material.set_shader_parameter("now", now)
	_sheet_material.set_shader_parameter("now", now)
	# THE CLOCK'S STEP, not the frame's: a frozen level throws nothing.
	var step: float = clampf(now - _was, 0.0, 0.1)
	_was = now
	# EVERY CRAFT ONLY EVERY `LOOK_EVERY`; between, only those spraying. A clock that went backwards is a new clock.
	var looking: bool = now >= _next_look or now < _next_look - WakeTuning.LOOK_EVERY
	if looking:
		_next_look = now + WakeTuning.LOOK_EVERY
	var still: Array = []
	for entity in (views.keys() if looking else _spraying):
		var view: VehicleView = views.get(entity, null)
		if view == null:
			continue
		var shape: Dictionary = _shape_of(view.kind)
		if shape.is_empty():
			continue
		var record: Dictionary = _following.get(entity, {})
		if record.is_empty():
			record = {"strength": 0.0, "clearance": INF, "owed": 0.0, "thrown": 0, "wall_from": Vector3.INF,
				"wall_when": 0.0, "wall_along": 0.0, "wall_strength": 0.0, "wall_head": -1, "walls": 0,
				"wall_seed": _dice.randf()}
			_following[entity] = record
		var velocity: Vector3 = ((Sim.current.get(entity, {}) as Dictionary).get("velocity", Vector3.ZERO)) as Vector3
		# TOO SLOW TO SPRAY, which is nearly everything: nothing more is asked.
		if not WakeTuning.fast_enough_to_spray(velocity.length()):
			record["strength"] = 0.0
			record["clearance"] = INF
			record["owed"] = 0.0
			_end_the_wall(record)
			continue
		var pose: Transform3D = view.global_transform
		var water: float = Terrain.water_height(pose.origin)
		var lowest := Vector3(0.0, INF, 0.0)
		var points: Array[Vector3] = []
		for point in shape["points"]:
			var at: Vector3 = pose * (point as Vector3)
			points.append(at)
			if at.y < lowest.y:
				lowest = at
		var clearance: float = lowest.y - water if water > -INF else INF
		# A HULL ON THE WATER by its length, an aircraft on the aircraft's curve (`WakeTuning.hull_spray_strength`).
		var strength: float = WakeTuning.hull_spray_strength(clearance, velocity.length(), float(shape["length"]))
		record["clearance"] = clearance
		record["strength"] = strength
		if strength <= 0.0:
			record["owed"] = 0.0
			_end_the_wall(record)
			continue
		still.append(entity)
		_raise_the_wall(record, _where_it_meets_the_water(points, lowest.y, water), strength, shape, now)
		record["owed"] = float(record["owed"]) + WakeTuning.SPRAY_PER_SECOND * strength * step
		while float(record["owed"]) >= 1.0:
			record["owed"] = float(record["owed"]) - 1.0
			_throw(pose, velocity, Vector3(lowest.x, water, lowest.z), shape, strength, now)
			record["thrown"] = int(record["thrown"]) + 1
	_spraying = still
	if looking and _following.size() > views.size():
		for entity in _following.keys():
			if not views.has(entity):
				_following.erase(entity)


## ONE PUFF, of three sorts. JETS, most of them: small, thrown high and fanned back from where the craft meets the water,
## drawn out along their flight, overlapping into the sheet of a rooster tail. SHEETS: small, thrown low and out to the
## sides. MIST: a few large faint ones rising slowly, which the jets break into at the top and the edges. As separate
## large puffs of one sort, the first rooster tails read as cotton balls (team-lead, pictures 05 and 06).
func _throw(pose: Transform3D, velocity: Vector3, under: Vector3, shape: Dictionary, strength: float, now: float) -> void:
	var level := Vector3(velocity.x, 0.0, velocity.z)
	var ahead: Vector3 = level.normalized() if level.length() > 0.1 else -pose.basis.z
	var across: Vector3 = ahead.cross(Vector3.UP).normalized()
	var reach: float = maxf(float(shape["half_width"]), 1.0)
	var lift: float = WakeTuning.SPRAY_RISE * (0.5 + 0.5 * strength)
	var sort: float = _dice.randf()
	var side: float = _dice.randf_range(-1.0, 1.0)
	var from: Vector3 = under - ahead * _dice.randf_range(0.0, 1.5)
	var thrown: Vector3 = level * WakeTuning.SPRAY_CARRY
	var grow: float = 1.0
	var opacity: float = 1.0
	if sort < WakeTuning.SPRAY_JET_SHARE:
		from += across * side * 0.6
		thrown += Vector3.UP * lift * _dice.randf_range(0.55, 1.0)
		thrown -= ahead * lift * _dice.randf_range(0.0, 0.35)
		thrown += across * side * WakeTuning.SPRAY_FLING * 0.25
		grow = _dice.randf_range(0.35, 0.7)
		opacity = 0.55
	elif sort < 1.0 - WakeTuning.SPRAY_MIST_SHARE:
		var out: float = signf(side) if side != 0.0 else 1.0
		from += across * out * reach * _dice.randf_range(0.1, 0.5)
		thrown += Vector3.UP * lift * _dice.randf_range(0.2, 0.45)
		thrown += across * out * WakeTuning.SPRAY_FLING * _dice.randf_range(0.6, 1.0)
		grow = _dice.randf_range(0.3, 0.6)
		opacity = 0.5
	else:
		from += across * side * reach * 0.4 - ahead * _dice.randf_range(0.0, 5.0)
		thrown += Vector3.UP * lift * _dice.randf_range(0.2, 0.45)
		grow = _dice.randf_range(0.9, 1.3)
		opacity = 0.09
	from.y += 0.15
	var life: float = minf(2.0 * thrown.y / 9.81 + 0.6, WakeTuning.SPRAY_LIFE_MOST)
	var index: int = _next
	_next = (_next + 1) % WakeTuning.SPRAY_PUFFS
	if _thrown_count < WakeTuning.SPRAY_PUFFS:
		_thrown_count += 1
		_puffs.multimesh.visible_instance_count = _thrown_count
	_puffs.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, from))
	_puffs.multimesh.set_instance_custom_data(index, Color(now, thrown.x, thrown.y, thrown.z))
	# THE STRENGTH THE SHADER FADES BY carries the sort's opacity: overlapping small puffs build the sheet.
	_puffs.multimesh.set_instance_color(index, Color(strength * opacity, _dice.randf(), life, grow))


## WHERE A CRAFT MEETS THE WATER, for the wall: the middle of every low point within half a metre of the lowest, at the
## water. A level hull's four bottom corners give the middle of its keel; a bank gives the wingtip.
static func _where_it_meets_the_water(points: Array[Vector3], lowest: float, water: float) -> Vector3:
	var sum := Vector3.ZERO
	var count: int = 0
	for at in points:
		if at.y <= lowest + 0.5:
			sum += at
			count += 1
	var middle: Vector3 = sum / float(maxi(count, 1))
	return Vector3(middle.x, water, middle.z)


## THE WALL BEHIND ONE CRAFT, ONE FRAME: the newest piece stretched from where the last was laid to the hull, and laid
## for good every `SHEET_EVERY` seconds. The first frame of a run only marks where the wall starts, at no strength, so
## it rises from nothing there.
func _raise_the_wall(record: Dictionary, here: Vector3, strength: float, shape: Dictionary, now: float) -> void:
	var from: Vector3 = record["wall_from"]
	if from == Vector3.INF:
		record["wall_from"] = here
		record["wall_when"] = now
		record["wall_strength"] = 0.0
		record["wall_head"] = -1
		return
	var chord: Vector3 = from - here
	var level := Vector3(chord.x, 0.0, chord.z)
	if level.length() < 0.05:
		return
	if int(record["wall_head"]) < 0:
		record["wall_head"] = _take_a_piece()
	var across: Vector3 = level.normalized().cross(Vector3.UP)
	var along: float = float(record["wall_along"]) + chord.length()
	# THE STRENGTH THE WALL IS DRAWN AT grows toward the craft's over `SHEET_RAMP`: a run starts as a ramp.
	var since: float = now - float(record["wall_when"])
	strength = move_toward(float(record["wall_strength"]), strength, since / WakeTuning.SHEET_RAMP)
	var index: int = int(record["wall_head"])
	var many: MultiMesh = _sheets.multimesh
	many.set_instance_transform(index, Transform3D(Basis(across, Vector3.UP, chord), here))
	many.set_instance_custom_data(index, Color(now, float(record["wall_when"]), along, strength))
	many.set_instance_color(index, Color(float(record["wall_strength"]), float(record["wall_seed"]),
		float(shape["hull_half"]), 0.0))
	record["wall_height"] = WakeTuning.sheet_height(strength)
	if now - float(record["wall_when"]) >= WakeTuning.SHEET_EVERY:
		record["wall_from"] = here
		record["wall_when"] = now
		record["wall_along"] = fposmod(along, WakeTuning.WAKE_TRACK_WRAP)
		record["wall_strength"] = strength
		record["wall_head"] = -1
		record["walls"] = int(record["walls"]) + 1


## THE WALL ENDS where the craft stopped spraying: the last piece stands as it was, and the next run starts afresh.
static func _end_the_wall(record: Dictionary) -> void:
	record["wall_from"] = Vector3.INF
	record["wall_head"] = -1
	record["wall_height"] = 0.0


func _take_a_piece() -> int:
	var index: int = _sheet_next
	_sheet_next = (_sheet_next + 1) % WakeTuning.SHEET_PIECES
	if _sheet_count < WakeTuning.SHEET_PIECES:
		_sheet_count += 1
		_sheets.multimesh.visible_instance_count = _sheet_count
	return index


func _shape_of(kind: int) -> Dictionary:
	if not _shapes.has(kind):
		var shape: Dictionary = {}
		if VehicleCatalogue.is_drawn(kind):
			var geometry: Dictionary = Sim.geometry_of(kind)
			var half: Vector3 = geometry.get("extents", Vector3.ONE) as Vector3
			shape = {"points": WakeTuning.low_points(kind, geometry),
				"half_width": maxf(half.x, float(geometry.get("span", 0.0))),
				"hull_half": minf(half.x, WakeTuning.SHEET_HULL_HALF), "length": half.z * 2.0}
		_shapes[kind] = shape
	return _shapes[kind]


## ---- the time of day ---------------------------------------------------------------

## THE LIGHT SPRAY IS DRAWN IN: the contrails' (ContrailYard.light_at), since spray is white as a cloud is.
func show_daylight(look: Dictionary) -> void:
	var light: Vector3 = ContrailYard.light_at(look)
	_puffs.set_instance_shader_parameter("light", light)
	_sheets.set_instance_shader_parameter("light", light)


## ---- for the tests and the boards -------------------------------------------------

## How strongly this craft was last found to be spraying, 0 to 1; -1 for one not followed.
func strength_of(entity: int) -> float:
	return float((_following.get(entity, {}) as Dictionary).get("strength", -1.0))


## How far this craft's lowest point was above the water under it when last looked at, metres; INF over dry land.
func clearance_of(entity: int) -> float:
	return float((_following.get(entity, {}) as Dictionary).get("clearance", INF))


## How many puffs this craft has thrown since it was first followed.
func thrown_by(entity: int) -> int:
	return int((_following.get(entity, {}) as Dictionary).get("thrown", 0))


## How many pieces of wall this craft has laid behind it since it was first followed.
func walls_laid_by(entity: int) -> int:
	return int((_following.get(entity, {}) as Dictionary).get("walls", 0))


## HOW HIGH THE WALL BEHIND THIS CRAFT IS RISING TO, metres, from the strength its newest piece was handed to the drawer
## with: 0 for a craft with no wall standing up behind it now. (Not read back off the MultiMesh: headless, its dummy
## renderer hands back nothing that was written.)
func wall_height_of(entity: int) -> float:
	return float((_following.get(entity, {}) as Dictionary).get("wall_height", 0.0))
