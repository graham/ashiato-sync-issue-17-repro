extends Node3D
class_name FireYard
## EVERY FIRE ON THE ISLAND, DRAWN -- AND THE SMOKE IS THE HALF THAT MATTERS.
##
## A fire is a small bright thing on a fourteen-kilometre island, and the aeroplane looking
## for it is two thousand feet up doing seventy metres a second. Flames are invisible from
## there. What a pilot actually flies towards is the COLUMN: smoke standing up out of a
## hillside is the only part of a fire that can be seen from far enough away to turn towards,
## which is true of the real thing and is the whole design of this file.
##
## So a fire is drawn twice over. Close up it is flame -- a cluster of cones, flickering,
## sized by how hard it is burning. From a distance it is a column of smoke leaning downwind,
## drawn far taller than the fire is wide and never culled, because a fire you cannot see
## from the circuit is a fire nobody can fight.
##
## POOLED, LIKE THE BURSTS. Fires come and go -- a doused one is retired by the simulation --
## and building a dozen meshes every time one appears is the same mistake `Burst` exists to
## avoid. A column is taken out of the drawer, lit, and put back.
##
## NOTHING HERE IS A LIGHT. Same rule as the explosions: a dozen point lights was a slideshow on
## the Mobile renderer this was written for (untimed on Forward+, the renderer since 2026-09-14),
## and a fire is bright enough to read as bright without lighting
## anything else.
##
## TWO FINISHES. Plain is everything above, exactly as it was. Fine keeps every size, place and
## strength the plain fire has -- those are the fire -- and changes how they are drawn: a flame
## is a tongue of moving noise on an upright quad instead of a stretched cone, the column is
## twenty-two puffs that RISE through it and come back at the bottom instead of fourteen that
## wobble in place, each puff billows, is lit by the sun and is stippled rather than blended,
## and embers climb out of the fire. See `flame_fine`, `smoke_fine` and `ember_fine` in
## `world/shaders/` for how, and `Finish` for who decides.
##
## ONE MATERIAL PER KIND OF THING ON FINE, and the per-flame and per-puff numbers in INSTANCE
## uniforms. The plain fire has a material per mesh -- thirty of them a fire -- because a
## StandardMaterial's colour is the only knob it has; a shader with instance uniforms gets the
## same variety from three materials for the whole island.

const FLAME_FINE: Shader = preload("res://world/shaders/flame_fine.gdshader")
const SMOKE_FINE: Shader = preload("res://world/shaders/smoke_fine.gdshader")
const EMBER_FINE: Shader = preload("res://world/shaders/ember_fine.gdshader")
## PLAIN'S FLAMES AND GLOW, AND ITS SMOKE: a flat tint that mists itself, in place of the StandardMaterial3D they were. The low
## mist is drawn first among the see-through things, and a standard material cannot include the shader that mists what is
## drawn after it (tests/lint.gd). See world/shaders/fire_plain.gdshaderinc.
const FIRE_PLAIN_ADD: Shader = preload("res://world/shaders/fire_plain_add.gdshader")
const FIRE_PLAIN_MIX: Shader = preload("res://world/shaders/fire_plain_mix.gdshader")

## How many fires may be drawn at once. The island carries a dozen; the drawer is deeper
## than that so a busy day does not start recycling columns that are still burning.
const COLUMNS: int = 24
## How many cones make a fire, and how many puffs make its column.
const FLAMES: int = 7
## FOURTEEN, AND THE COUNT IS WHAT MAKES IT A COLUMN. Nine left visible gaps between the
## puffs at the bottom, where they are smallest and furthest apart in angle -- a rising
## string of separate balls rather than smoke. They have to overlap.
const PUFFS: int = 14
## ON FINE THE PUFFS MOVE, so there have to be more of them: a puff climbing away from the one
## below it opens the same gap nine fixed puffs left, and twenty-two keeps it closed.
const PUFFS_FINE: int = 22
## How long a puff takes to climb the whole column on fine, in seconds. About the speed a real
## column rises at over a hillside fire -- slow enough to read as smoke rather than steam.
const RISE_SECONDS: float = 38.0
## Sparks per fire, on fine.
const EMBERS: int = 12
## How wide a fire is at full strength, in metres, and how tall its column stands. The
## column is the number that matters: 260 m of smoke is visible across a valley, which is
## the distance the aeroplane needs to see it from.
const FIRE_ACROSS: float = 26.0
const COLUMN_HEIGHT: float = 260.0
## How fast the flames flicker, and by how much. Enough to be alive, not so much that the
## fire looks like it is being switched on and off.
const FLICKER_HZ: float = 7.0
const FLICKER: float = 0.22


## One fire's worth of meshes, kept together so the pool can hand out a whole fire.
class Column extends Node3D:
	var flames: Array[MeshInstance3D] = []
	var smoke: Array[MeshInstance3D] = []
	var glow: MeshInstance3D = null
	## Where each flame and each puff sits at full strength, so that scaling the fire down
	## is one multiply rather than a fresh layout.
	var flame_at: Array[Vector3] = []
	var puff_at: Array[Vector3] = []
	## The plain finish's own meshes and materials, kept to be put back.
	var cones: Array[Mesh] = []
	var flame_paint: Array[Material] = []
	var puff_paint: Array[Material] = []
	## The sparks, on fine. Hidden on plain.
	var embers: MultiMeshInstance3D = null


var _live: Dictionary = {}
var _spare: Array[Column] = []
var _age: float = 0.0
## Which way the smoke leans, and how far. Set from the wind so that a column says which way
## the air is moving -- which is the one thing a pilot most wants to know before a drop run.
var _drift := Vector3.ZERO
## Which finish the fires are wearing. Set only by `_wear`.
var _fine: bool = false
## The fine finish's three materials, shared by every fire, and the quad a fine flame stands on.
var _flame_paint: ShaderMaterial = null
var _smoke_paint: ShaderMaterial = null
var _ember_paint: ShaderMaterial = null
var _flame_quad: QuadMesh = null


func _ready() -> void:
	set_process(false)
	_flame_paint = ShaderMaterial.new()
	_flame_paint.shader = FLAME_FINE
	_smoke_paint = ShaderMaterial.new()
	_smoke_paint.shader = SMOKE_FINE
	_ember_paint = ShaderMaterial.new()
	_ember_paint.shader = EMBER_FINE
	_ember_paint.set_shader_parameter("drift", _drift)
	_flame_quad = QuadMesh.new()
	_flame_quad.size = Vector2(1.0, 1.0)
	# STANDING ON THE GROUND, so VERTEX.y runs 0..1 from the root of the flame to its tip.
	_flame_quad.center_offset = Vector3(0.0, 0.5, 0.0)
	var finish: Node = get_node_or_null("/root/Finish")
	if finish != null:
		finish.connect("changed", _wear)
		_fine = bool(finish.call("is_fine"))


## HOW THE SMOKE LEANS. Metres of lean per metre of height, straight off the wind: a column
## bent forty-five degrees is a wind of about the speed a column climbs at.
func set_drift(wind: Vector3) -> void:
	_drift = wind * 0.09
	if _ember_paint != null:
		_ember_paint.set_shader_parameter("drift", _drift)


## EVERY FIRE, ONE FRAME. `fires` is `Sim.fires` -- the replicated list, which is the same
## list on every machine -- and `delta` is what makes the flames move between packets.
##
## THE FLICKER IS LOCAL AND THE STRENGTH IS NOT, which is the split this whole project runs
## on. How hard a fire is burning is a fact everybody has to agree about, so it comes off the
## wire; what the flames are doing this frame is nobody's business but this machine's, so it
## is a sine wave here and never on any wire at all.
func draw_fires(fires: Array, delta: float) -> void:
	_age += delta
	var seen: Dictionary = {}
	for row in fires:
		var fire: Dictionary = row
		var entity: int = int(fire["entity"])
		seen[entity] = true
		var column: Column = _live.get(entity)
		if column == null:
			column = _a_column()
			if column == null:
				continue
			_live[entity] = column
		column.position = fire["position"] as Vector3
		_draw(column, float(fire["strength"]), entity)
	# A FIRE THAT WENT OUT. The simulation retires a doused fire, so it simply stops being
	# in the list -- and the honest thing is to put the column away rather than leave smoke
	# standing over a hillside nobody is fighting any more.
	for entity in _live.keys():
		if not seen.has(entity):
			_put_away(entity)


## How many fires are being drawn, for the tests and the boards.
func burning() -> int:
	return _live.size()


## WHETHER THE FIRES ARE DRAWN FINE, read off the columns' own materials -- what a test has to
## ask, rather than what the tier says they ought to be wearing. With no fire drawn there is
## nothing to read, and the answer is the finish the next one will be built in.
func wears_fine() -> bool:
	var every: Array = _every_column()
	if every.is_empty():
		return _fine
	for one in every:
		var column: Column = one
		if column.flames.is_empty() or column.flames[0].material_override != _flame_paint:
			return false
	return true


func _draw(column: Column, strength: float, salt: int) -> void:
	var hard: float = clampf(strength, 0.0, 1.0)
	var across: float = FIRE_ACROSS * (0.35 + hard * 0.65)
	# EVERY FIRE FLICKERS ON ITS OWN CLOCK. One phase for all of them and a hillside with
	# three fires on it pulses like a set of traffic lights.
	var phase: float = float(salt % 97) * 0.31
	for i in range(column.flames.size()):
		var flame: MeshInstance3D = column.flames[i]
		var beat: float = sin((_age + phase) * FLICKER_HZ + float(i) * 1.7)
		var tall: float = across * (0.5 + 0.5 * float(i) / float(FLAMES)) \
			* (1.0 + beat * FLICKER)
		flame.position = column.flame_at[i] * across
		flame.scale = Vector3(across * 0.28, tall, across * 0.28)
		if _fine:
			flame.set_instance_shader_parameter("heat", hard)
			continue
		# Orange at the base, yellow at the tip: a fire is hottest where the fuel is.
		var heat: Color = Color(1.00, 0.42, 0.10).lerp(Color(1.00, 0.86, 0.35),
			float(i) / float(FLAMES))
		_tint(flame, heat, 0.55 + 0.35 * hard)
	# THE GLOW at the base, which is what makes a fire read as a fire from directly above --
	# the one angle from which the flames are edge-on and the column is a dot.
	column.glow.scale = Vector3(across * 1.6, 1.0, across * 1.6)
	_tint(column.glow, Color(1.00, 0.55, 0.18), 0.30 * hard)
	# AND THE COLUMN, leaning downwind and spreading as it climbs. Its HEIGHT is what says
	# how hard the fire is burning, because height is the part you can see from three
	# kilometres away.
	var stands: float = COLUMN_HEIGHT * (0.25 + hard * 0.75)
	if _fine:
		_rise(column, hard, across, stands, phase)
		return
	for i in range(column.smoke.size()):
		var puff: MeshInstance3D = column.smoke[i]
		if i >= PUFFS:
			puff.visible = false
			continue
		var up: float = float(i) / float(PUFFS - 1)
		var wobble: float = sin((_age + phase) * 0.7 + up * 5.0) * across * 0.5
		# THE COLUMN STARTS ABOVE THE FLAMES, not on them. Smoke drawn from ground level up
		# puts its thickest, darkest puff exactly where the fire is, and what you get is a
		# dark ball with a fire hidden inside it -- which from the air is a fire you cannot
		# see and cannot aim at.
		var height: float = (0.12 + up * 0.88) * stands
		puff.position = Vector3(column.puff_at[i].x * across * (0.4 + up * 2.2) + wobble,
			height, column.puff_at[i].z * across * (0.4 + up * 2.2)) \
			+ _drift * height
		# NARROW AT THE BOTTOM AND WIDE AT THE TOP, and wide enough at every height that
		# consecutive puffs overlap: a column of separated balls is a string of beads.
		var fat: float = across * (0.45 + up * 2.6)
		puff.scale = Vector3(fat, fat, fat)
		# Dark and thick at the bottom, pale and thin at the top, which is smoke cooling
		# and spreading into the wind.
		_tint(puff, Color(0.18, 0.16, 0.15).lerp(Color(0.62, 0.60, 0.58), up),
			(0.55 - up * 0.42) * hard)


## THE COLUMN ON FINE: every puff somewhere on its way up, and back to the bottom when it gets
## there. The same shape as the plain column -- the same heights, widths, lean and colours for
## the same fraction of the way up -- so a column is recognisably the same column on either
## finish, and only the movement is new.
func _rise(column: Column, hard: float, across: float, stands: float, phase: float) -> void:
	for i in range(column.smoke.size()):
		var puff: MeshInstance3D = column.smoke[i]
		puff.visible = true
		var up: float = fposmod(float(i) / float(PUFFS_FINE) + _age / RISE_SECONDS, 1.0)
		# BORN FAINT AND DYING FAINT, or a puff would blink into existence at the bottom and
		# out of it at the top once every forty seconds, which the eye catches every time.
		var fade: float = smoothstep(0.0, 0.1, up) * (1.0 - smoothstep(0.7, 1.0, up))
		var wobble: float = sin((_age + phase) * 0.7 + up * 5.0 + float(i)) * across * 0.5
		# CROWDED AT THE BASE. Puffs spread evenly up the column are sparse where they are small, and
		# the first render check (2026-09-12) showed the bottom of every column as a string of
		# separate beads on both finishes. Climbing by a power of the fraction puts more of them
		# low down, and a wider base makes consecutive ones overlap.
		var climb: float = pow(up, 1.35)
		var height: float = (0.10 + climb * 0.90) * stands
		puff.position = Vector3(column.puff_at[i].x * across * (0.4 + climb * 2.2) + wobble,
			height, column.puff_at[i].z * across * (0.4 + climb * 2.2)) + _drift * height
		# And wider still at the very bottom: at 0.85 across, render_check_3 still showed a dark bead
		# or two where each column leaves the fire.
		var fat: float = across * (1.2 + climb * 2.0)
		puff.scale = Vector3(fat, fat, fat)
		puff.rotation.y = _age * 0.05 * float(1 + i % 3)
		var tone: Color = Color(0.18, 0.16, 0.15).lerp(Color(0.62, 0.60, 0.58), up)
		tone.a = clampf((0.55 - up * 0.42) * hard * fade * 1.3, 0.0, 1.0)
		puff.set_instance_shader_parameter("tone", tone)
	column.embers.set_instance_shader_parameter("heat", hard)
	column.embers.set_instance_shader_parameter("span", across)


## ---- the finish -----------------------------------------------------------------------

func _wear(fine: bool) -> void:
	_fine = fine
	for one in _every_column():
		_dress(one as Column)


func _every_column() -> Array:
	var every: Array = _live.values()
	every.append_array(_spare)
	return every


## PUT ONE FIRE IN THE FINISH THAT IS ON. Meshes and materials only; where everything is and how
## big is `_draw`'s, on both finishes.
func _dress(column: Column) -> void:
	for i in range(column.flames.size()):
		var flame: MeshInstance3D = column.flames[i]
		flame.mesh = _flame_quad if _fine else column.cones[i]
		flame.material_override = _flame_paint if _fine else column.flame_paint[i]
		# ONLY ON FINE. A StandardMaterial has no instance uniforms, and naming one it lacks is
		# an engine error per mesh -- which the suite's error gate would rightly fail.
		if _fine:
			flame.set_instance_shader_parameter("seed", float(i) * 0.137)
	for i in range(column.smoke.size()):
		var puff: MeshInstance3D = column.smoke[i]
		puff.material_override = _smoke_paint if _fine else column.puff_paint[i]
		if _fine:
			puff.set_instance_shader_parameter("seed", float(i) * 0.37)
		puff.visible = _fine or i < PUFFS
		if not _fine:
			puff.rotation = Vector3.ZERO
	column.embers.visible = _fine


## ---- the drawer --------------------------------------------------------------------

func _a_column() -> Column:
	if not _spare.is_empty():
		var reused: Column = _spare.pop_back()
		reused.visible = true
		return reused
	if _live.size() >= COLUMNS:
		return null
	var made := Column.new()
	add_child(made)
	# THE FLAMES, in a ring with one in the middle. A cone apiece, because a cone with a
	# soft additive skin is what a flame looks like at any distance worth drawing one from.
	for i in range(FLAMES):
		var about: float = TAU * float(i) / float(FLAMES)
		var out: float = 0.0 if i == 0 else 0.30
		made.flame_at.append(Vector3(cos(about) * out, 0.0, sin(about) * out))
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.5
		cone.height = 1.0
		cone.radial_segments = 7
		var flame := MeshInstance3D.new()
		flame.mesh = cone
		# The cone's origin is its middle, and a flame stands ON the ground.
		flame.position = Vector3(0.0, 0.5, 0.0)
		flame.material_override = _glow(Color(1.0, 0.5, 0.15), true)
		made.cones.append(cone)
		made.flame_paint.append(flame.material_override)
		_never_culled(flame)
		made.add_child(flame)
		made.flames.append(flame)
	made.glow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.4
	disc.radial_segments = 16
	made.glow.mesh = disc
	made.glow.material_override = _glow(Color(1.0, 0.55, 0.18), true)
	_never_culled(made.glow)
	made.add_child(made.glow)
	# AND THE SMOKE. Plain alpha rather than additive: smoke is a thing that HIDES what is
	# behind it, and additive smoke over a dark hillside is invisible -- which is the one
	# thing this column must never be. Built to the fine count; plain hides the extra.
	for i in range(PUFFS_FINE):
		var about: float = TAU * float(i) * 0.61
		made.puff_at.append(Vector3(cos(about) * 0.35, 0.0, sin(about) * 0.35))
		var ball := SphereMesh.new()
		ball.radius = 0.5
		ball.height = 1.0
		ball.radial_segments = 9
		ball.rings = 6
		var puff := MeshInstance3D.new()
		puff.mesh = ball
		puff.material_override = _glow(Color(0.3, 0.29, 0.28), false)
		made.puff_paint.append(puff.material_override)
		_never_culled(puff)
		made.add_child(puff)
		made.smoke.append(puff)
	made.embers = _sparks()
	made.add_child(made.embers)
	_dress(made)
	return made


## A FIRE'S SPARKS: one MultiMesh of small quads, each with its own seed. Everything else about
## them is the shader's.
func _sparks() -> MultiMeshInstance3D:
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	# Before the count -- see `LiftYard._batch`.
	many.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	many.mesh = quad
	many.instance_count = EMBERS
	for i in range(EMBERS):
		many.set_instance_transform(i, Transform3D.IDENTITY)
		many.set_instance_custom_data(i, Color(fposmod(float(i) * 0.618034, 1.0), 0.0, 0.0, 0.0))
	var node := MultiMeshInstance3D.new()
	node.multimesh = many
	node.material_override = _ember_paint
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 512.0
	return node


func _put_away(entity: int) -> void:
	var column: Column = _live.get(entity)
	if column == null:
		return
	column.visible = false
	_live.erase(entity)
	_spare.append(column)


## A SKIN THAT IS NEVER CULLED AND NEVER SHADOWED.
##
## The cull margin is the same trick the spotting boxes use: a column of smoke is drawn from
## nine puffs whose own bounds are metres across while the thing they make is hundreds of
## metres tall, so Godot culls the lot the moment the fire's origin leaves the frustum --
## which is exactly when a pilot is turning towards it.
func _glow(tint: Color, additive: bool) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = FIRE_PLAIN_ADD if additive else FIRE_PLAIN_MIX
	paint.set_shader_parameter("tint", tint)
	return paint


## THE TWO SETTINGS EVERY FLAME, PUFF AND GLOW NEEDS, applied once, when it is built. `_tint` used to
## apply them again to every one of them on every frame; see there.
static func _never_culled(node: MeshInstance3D) -> void:
	node.extra_cull_margin = 4096.0
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A COLOUR, AND ONLY IF IT CHANGED.
##
## PLAIN tints every flame, puff and glow of every fire on every frame, and a colour here depends only
## on which piece it is and how hard the fire is burning -- so from one frame to the next it is nearly
## always the colour already set. Setting it anyway is not free: the material passes every assignment
## on to the renderer whether or not the value changed, and this used to re-send the cull margin and
## the shadow setting to every mesh as well, every frame, for every fire on the island whether it was
## in frame or not. Stage 1 (2026-09-12) measured PLAIN's renderer time rising with the fire yard's
## script time as the fire front spread (r = 0.86; FINE, which sends neither, r = 0.28). So the colour
## goes only when it is different, and the other two go once, in `_never_culled`. Kept in Stage 2d, about
## half a millisecond a PLAIN frame quicker (agents.md, "What it costs").
static func _tint(node: MeshInstance3D, colour: Color, alpha: float) -> void:
	# PLAIN'S OWN MATERIALS ONLY: FINE wears one shared ShaderMaterial a kind, which has no tint.
	var paint := node.material_override as ShaderMaterial
	if paint == null or (paint.shader != FIRE_PLAIN_ADD and paint.shader != FIRE_PLAIN_MIX):
		return
	var wanted := Color(colour.r, colour.g, colour.b, clampf(alpha, 0.0, 1.0))
	if paint.get_shader_parameter("tint") != wanted:
		paint.set_shader_parameter("tint", wanted)
