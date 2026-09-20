@tool
extends MultiMeshInstance3D
class_name VehicleLights
## THE LIGHTS ON AN AIRCRAFT, AND ON A RUNWAY: points that stay visible at any range.
##
## A hundred machines fly themselves over a fourteen-kilometre island, and a pilot looking for
## one of them is looking for three grey pixels. The spotting boxes answer that on request.
## Lights answer it all the time, the way they do in life: red on the left wingtip, green on
## the right, white at the tail, a red anticollision beacon top and bottom, and white strobes
## on the tips -- and the same thing on the ground for the runway, which from the circuit is
## otherwise a grey stripe on a green field.
##
## THE DECISION: A SPRITE THAT HOLDS AN ANGLE, NOT A LIGHT. See `beacon.gdshaderinc` for the
## shader. An OmniLight per wingtip was a slideshow on the Mobile renderer this was written for
## (untimed on Forward+, the renderer since 2026-09-14), and it would light
## a wing nobody is looking at while staying invisible at four kilometres, which is backwards.
##
## ONE MULTIMESH PER CRAFT, ONE MATERIAL FOR ALL OF THEM. Every light on an aircraft is an
## instance -- position, colour, and a pattern word -- so an aircraft's lights are one draw
## call and flash on the GPU's clock rather than a node each on the processor's. And every
## set of lights in the world shares ONE ShaderMaterial, so changing the finish is one shader
## swap on one material rather than a walk over a hundred aircraft.
##
## PLACED ON THE DRAWN AIRFRAME, never on the collision box. An airframe that says where its lights are is asked
## (the fighter, the Hawkeye, the helicopters, the Cessna); every other light is measured off the triangles the view
## draws, so a rebuilt wing moves its lights with it. See `for_view` for where the box put them until 2026-09-17.

const PLAIN: Shader = preload("res://world/shaders/beacon.gdshader")
const FINE: Shader = preload("res://world/shaders/beacon_fine.gdshader")
## The fine finish's second pass: the halo round the core. See beacon_halo.gdshader.
const HALO: Shader = preload("res://world/shaders/beacon_halo.gdshader")

## What each light does, in the shader's own words. See the INSTANCE_CUSTOM note there.
enum Pattern { STEADY, BEACON, STROBE, RABBIT, PAPI }

const RED := Color(1.0, 0.12, 0.08)
const GREEN := Color(0.20, 1.0, 0.35)
const WHITE := Color(1.0, 0.97, 0.90)

## TWO MATERIALS, ON THE SAME SHADERS: every aircraft's lights share one and the runway's the other. One until
## 2026-09-13, when the user asked for aircraft lights "less visible in day, and dithered a bit more ... smaller again"
## and the runway was to stay as it was -- which is a size, a brightness and a rim per material, and still one shader
## swap per material when the finish changes.
static var _paint: ShaderMaterial = null
## Its halo pass, hung on it as `next_pass` while the finish is fine and taken off while plain.
static var _halo: ShaderMaterial = null
static var _runway_paint: ShaderMaterial = null
static var _runway_halo: ShaderMaterial = null
## The aircraft lights' brightness by time of day, and how they fade and shrink with distance, as last handed over. See
## `show_daylight`. Night's until the level says otherwise, which is the lights as they were.
static var _daylight: float = 1.0
static var _dim_to: float = RUNWAY_DIM_TO
static var _far_bright: float = RUNWAY_FAR_BRIGHT
static var _far_least: float = 1.0
## How many times `show_daylight` has written a material, ever: tests/scenery.gd holds it still for sixty frames.
static var writes: int = 0

## HOW BIG AN AIRCRAFT'S LIGHTS ARE, against their real size and their least angle: 0.5 from 2026-09-12 (half size, on
## request), 0.35 from 2026-09-13 ("smaller again"). The least angle keeps a little more than the size, so a light a
## few kilometres off is still a dot. The runway's are RUNWAY_SIZE for both, which is the sum they always had.
const AIRCRAFT_SIZE: float = 0.35
const AIRCRAFT_LEAST: float = 0.42
const RUNWAY_SIZE: float = 0.5
## HOW WIDE THE DITHERED RIM OF AN AIRCRAFT LIGHT IS, as a share of its radius: light on PLAIN, wider on FINE, where the
## multisampling already softens an edge and a wider rim reads as a glow rather than a stipple. None on the runway.
##
## 0.35, NOT THE 0.45 FIRST TRIED: at 0.45 FINE fell short of PLAIN by day on three views (2026-09-13, `--parade
## --no-spotting --time=day`: runway base 0.56 against 0.67 red pixels a light, traffic 0.83 against 0.98, traffic near
## 0.46 against 0.52, and traffic's reddest 0.455 against 0.467). At 0.35 and at 0.25 traffic and traffic near passed
## and runway base read 0.61 at both, so the rim was not what it was short by -- see AIRCRAFT_FINE_CORE.
const AIRCRAFT_RIM_PLAIN: float = 0.2
const AIRCRAFT_RIM_FINE: float = 0.35
## HOW MUCH LARGER THE FINE CORE IS THAN THE PLAIN DOT. 1.35 was measured in for the half-size lights (2026-09-12)
## against FINE's multisampling softening a small dot's edge below the red test; an aircraft's dot is smaller again and
## dimmer by day, and the base-leg view's lights at about 1.5 km stayed short at 1.35 whatever the rim. The runway's is
## the 1.35 it always had.
const AIRCRAFT_FINE_CORE: float = 1.5
const RUNWAY_FINE_CORE: float = 1.35
## WHERE A LIGHT STARTS TO FADE WITH DISTANCE, metres, at every time of day. How far it fades to, how dim and how small is
## the time of day's for an aircraft (`DaylightTuning`'s "aircraft_dim_to", "aircraft_far_bright", "aircraft_far_least")
## and fixed for the runway, whose lights were to stay as they were.
const DIM_FROM: float = 300.0

## THE LIGHTS THIS NODE WAS BUILT WITH, as handed to `build`, in its own frame. Kept because a MultiMesh on the headless
## renderer reads every instance back as zero, so tests/lights_on_skin.gd asks the node what it drew rather than the mesh.
var lamps: Array[Dictionary] = []
const RUNWAY_DIM_TO: float = 5000.0
const RUNWAY_FAR_BRIGHT: float = 0.35


## A set of lights, built. `lights` is a list of `{position, colour, pattern, radius, floor,
## phase, papi}`; `salt` staggers the flashing so two aircraft side by side do not strobe in
## step, which reads as one machine.
static func build(lights: Array[Dictionary], salt: int, on_aircraft: bool = true) -> VehicleLights:
	var node := VehicleLights.new()
	node.lamps = lights.duplicate(true)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	# BEFORE THE COUNT. A MultiMesh refuses to start carrying colours or custom data once it
	# has instances -- see `LiftYard._batch`, which found that out the silent way.
	many.use_colors = true
	many.use_custom_data = true
	var quad := QuadMesh.new()
	# Two metres across, so VERTEX.xy runs -1..1 and the shader's `corner` is a unit disc.
	quad.size = Vector2(2.0, 2.0)
	many.mesh = quad
	many.instance_count = lights.size()
	var stagger: float = fposmod(float(salt & 0xFFFF) * 0.618034, 1.0)
	for i in range(lights.size()):
		var light: Dictionary = lights[i]
		many.set_instance_transform(i, Transform3D(
			Basis.IDENTITY.scaled(Vector3.ONE * float(light.get("radius", 0.2))),
			light["position"] as Vector3))
		many.set_instance_color(i, light.get("colour", WHITE) as Color)
		many.set_instance_custom_data(i, Color(float(light.get("pattern", Pattern.STEADY)),
			fposmod(float(light.get("phase", 0.0)) + stagger, 1.0),
			float(light.get("floor", 1.0)), float(light.get("papi", 0.0))))
	node.multimesh = many
	# THE RUNWAY WEARS THE RUNWAY'S. From fd842f5 until 2026-09-14 this line gave every set of lights the aircraft
	# material whatever `on_aircraft` said, so the runway was shrunk, dimmed by day and dithered while the runway's own
	# material, which the tests read, drew nothing. tests/scenery.gd now asks the level's nodes what they wear.
	node.material_override = paint() if on_aircraft else runway_paint()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# NEVER CULLED BY ITS OWN BOUNDS. A light eight kilometres off is drawn tens of metres
	# across so that it stays a few pixels wide, and the MultiMesh's bounds know nothing of
	# that -- so without a margin the lights of an aircraft at the edge of the frame wink out.
	node.extra_cull_margin = 512.0
	return node


## THE AIRCRAFT LIGHTS' MATERIAL, wearing whichever finish is on. Hooked to `Finish.changed` once, the
## first time anything asks, and never again.
static func paint() -> ShaderMaterial:
	_make_the_paints()
	return _paint


## THE RUNWAY'S MATERIAL: the same shaders, at the size, brightness and edge the runway's lights always had.
static func runway_paint() -> ShaderMaterial:
	_make_the_paints()
	return _runway_paint


## EVERY NUMBER A MATERIAL IS DRAWN WITH IS SET HERE, from the constants above and `DaylightTuning` -- never left to a
## uniform's default in the shader, so a number typed there instead is a number tests/scenery.gd finds missing.
static func _make_the_paints() -> void:
	if _paint != null:
		return
	_paint = ShaderMaterial.new()
	_halo = ShaderMaterial.new()
	_halo.shader = HALO
	_runway_paint = ShaderMaterial.new()
	_runway_halo = ShaderMaterial.new()
	_runway_halo.shader = HALO
	for material in [_paint, _halo]:
		material.set_shader_parameter("size_scale", AIRCRAFT_SIZE)
		material.set_shader_parameter("least_scale", AIRCRAFT_LEAST)
		material.set_shader_parameter("daylight", _daylight)
		material.set_shader_parameter("fine_core", AIRCRAFT_FINE_CORE)
		material.set_shader_parameter("dim_from", DIM_FROM)
		material.set_shader_parameter("dim_to", _dim_to)
		material.set_shader_parameter("far_bright", _far_bright)
		material.set_shader_parameter("far_least", _far_least)
	for material in [_runway_paint, _runway_halo]:
		material.set_shader_parameter("size_scale", RUNWAY_SIZE)
		material.set_shader_parameter("least_scale", RUNWAY_SIZE)
		material.set_shader_parameter("fine_core", RUNWAY_FINE_CORE)
		material.set_shader_parameter("daylight", 1.0)
		material.set_shader_parameter("rim_dither", 0.0)
		material.set_shader_parameter("dim_from", DIM_FROM)
		material.set_shader_parameter("dim_to", RUNWAY_DIM_TO)
		material.set_shader_parameter("far_bright", RUNWAY_FAR_BRIGHT)
		material.set_shader_parameter("far_least", 1.0)
	var finish: Node = _the_finish()
	_wear(finish != null and bool(finish.call("is_fine")))
	if finish != null:
		finish.connect("changed", _wear)


## THE CORE SHADER AND, ON FINE, THE HALO PASS BEHIND IT, on both materials, and the aircraft rim for the finish.
static func _wear(fine: bool) -> void:
	for pair in [[_paint, _halo], [_runway_paint, _runway_halo]]:
		(pair[0] as ShaderMaterial).shader = FINE if fine else PLAIN
		(pair[0] as ShaderMaterial).next_pass = pair[1] if fine else null
	_paint.set_shader_parameter("rim_dither", AIRCRAFT_RIM_FINE if fine else AIRCRAFT_RIM_PLAIN)


## HOW BRIGHT AN AIRCRAFT'S LIGHTS ARE FOR THE TIME OF DAY, AND HOW THEY FADE AND SHRINK WITH DISTANCE, handed over by the
## level once per change (see `DaylightTuning`'s "aircraft_lights", "aircraft_dim_to", "aircraft_far_bright" and
## "aircraft_far_least"). Every argument is the preset's, given at the call; core and halo; never per frame.
static func show_daylight(bright: float, dim_to: float, far_bright: float, far_least: float) -> void:
	_daylight = bright
	_dim_to = dim_to
	_far_bright = far_bright
	_far_least = far_least
	if _paint == null:
		return
	for material in [_paint, _halo]:
		material.set_shader_parameter("daylight", bright)
		material.set_shader_parameter("dim_to", dim_to)
		material.set_shader_parameter("far_bright", far_bright)
		material.set_shader_parameter("far_least", far_least)
		writes += 1


## The `Finish` autoload, or null in the editor -- this script is @tool because VehicleView is,
## and an editor has no autoloads running.
static func _the_finish() -> Node:
	if Engine.is_editor_hint():
		return null
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Finish") if tree != null else null


## ---- where the lights go ------------------------------------------------------------

## HOW FAR PROUD OF THE DRAWN SKIN A MEASURED LIGHT STANDS, metres: its centre just outside the surface it is on, as the
## fighter's (0.08) and the helicopters' (0.01-0.09) stand on theirs.
const PROUD: float = 0.06
## HOW CLOSE TO ITS OWN DRAWN SKIN EVERY LIGHT'S CENTRE MUST BE, metres: the number tests/lights_on_skin.gd reads.
const ON_SKIN: float = 0.15
## WHAT A MEASURED LIGHT IS NOT PUT ON: parts that turn, or that stand below or beside the airframe. A wingtip is the
## wing's, not the proprotor blade's that reaches past it, and a belly beacon is the fuselage's, not the nose wheel's.
const NOT_SKIN: PackedStringArray = ["Propeller", "Proprotor", "Rotor", "Blade", "Spinner", "Hub", "Disc", "Wheel",
	"Tyre", "Gear", "Strut", "Lights"]
## How far a strobe sits aft of its nav light on a published tip, so the two do not draw on top of each other.
const STROBE_AFT: float = 0.45

## Measured stations by kind, worked out once: every craft of a kind is drawn the same, and a 46,000-triangle gunship is
## not walked once for every gunship in the sky.
static var _measured: Dictionary = {}


## WHETHER A CRAFT OF THIS KIND CARRIES LIGHTS AT ALL: anything that flies. A car with nav lights would be one more thing in
## the sky that is not an aeroplane, and no ship or ground craft here is drawn with any.
static func carries_lights(kind: int) -> bool:
	return VehicleCatalogue.body(kind) in [VehicleCatalogue.Body.WINGED, VehicleCatalogue.Body.HIGH_WING,
		VehicleCatalogue.Body.HAWKEYE, VehicleCatalogue.Body.TILTROTOR, VehicleCatalogue.Body.ROTOR,
		VehicleCatalogue.Body.UH60, VehicleCatalogue.Body.TANDEM, VehicleCatalogue.Body.LITTLEBIRD,
		VehicleCatalogue.Body.APACHE]


## WHETHER A CRAFT OF THIS KIND HAS A WING, whose tips carry its red and green lights and leave its contrails. A
## helicopter's red and green are on its stabiliser.
static func has_a_wing(kind: int) -> bool:
	return VehicleCatalogue.body(kind) in [VehicleCatalogue.Body.WINGED, VehicleCatalogue.Body.HIGH_WING,
		VehicleCatalogue.Body.HAWKEYE, VehicleCatalogue.Body.TILTROTOR]


## THE LIGHTS A VIEW'S CRAFT CARRIES, in `body`'s frame (nose towards -Z, right towards +X): each one asked of the thing it
## sits on. An airframe that says where its lights are is taken at its word (`published`, or a visual scene's own
## `lights()`); every station it does not name is MEASURED from what the view draws (`measured`).
##
## UNTIL 2026-09-17 every winged craft but the fighter had its lights worked out from the collision box and the
## aerodynamic span, by formulas written for the plank wing, and when the airframes were rebuilt nobody moved them. The
## gunship's wingtip lights hung 20.2 m out in the air past the drawn C-130's tips, the Mercury's top beacon 6.2 m over
## its fin, the airliner's 5.7 m and the sailplane's 5.2, and the Cessna's lights 1.5 to 2.4 m off its own lamp fairings
## and beacon rod (tests/lights_on_skin.gd measured them).
static func for_view(kind: int, geometry: Dictionary, view: Node3D, body: Node3D, airframe: Node3D) -> Array[Dictionary]:
	if not carries_lights(kind):
		return []
	var stations: Dictionary = published(kind, geometry)
	var to_body: Transform3D = frame_in(body, view).affine_inverse() if body != null else Transform3D.IDENTITY
	if airframe != null and airframe.has_method("lights"):
		var said: Dictionary = airframe.call("lights")
		var frame: Transform3D = to_body * frame_in(airframe, view)
		for station in said:
			var at: Variant = said[station]
			if at is Array:
				stations[station] = (at as Array).map(func(p: Vector3) -> Vector3: return frame * p)
			elif at is Vector3:
				stations[station] = frame * (at as Vector3)
			else:
				stations[station] = null
	var missing: bool = false
	for station in ["port", "starboard", "strobes", "tail", "top", "bottom"]:
		missing = missing or not stations.has(station)
	if not missing:
		return lamps_from(stations)
	# AN AIRFRAME CLASS THAT DRAWS ITSELF AND SAYS NOTHING OF ITS LIGHTS IS MEASURED, AND SAYS SO. The measurement sees
	# the airframe as it was built, and a part that moves -- a swept wing's tip, which is where the nav lights are --
	# would leave its lights behind it. Such an airframe publishes `lights()`; the warning is so the one that has not
	# yet is found by the first suite that draws it (the harness fails on any warning), not by a pilot.
	if airframe != null and not airframe.has_method("lights"):
		push_warning("VehicleLights: %s draws itself and publishes no lights(); its lights are measured off its skin as built"
			% airframe.name)
	# CACHED BY KIND IN THE GAME; worked out afresh in the editor, where the airframe being looked at is being changed.
	var got: Dictionary = _measured.get(kind, {}) if not Engine.is_editor_hint() else {}
	if got.is_empty():
		var skin: PackedVector3Array = skin_of(view)
		for i in range(skin.size()):
			skin[i] = to_body * skin[i]
		got = measured(skin)
		if not Engine.is_editor_hint():
			_measured[kind] = got
	var merged: Dictionary = got.duplicate()
	for station in stations:
		merged[station] = stations[station]
	return lamps_from(merged)


## WHAT AN AIRFRAME CLASS SAYS ABOUT ITS OWN LIGHTS, statically, in the drawn body's frame: {port, starboard, strobes,
## tail, top, bottom}, each missing where it does not say. Empty for a craft whose airframe has no class.
static func published(kind: int, geometry: Dictionary) -> Dictionary:
	if kind == Sim.Kind.FIGHTER:
		# THE F/A-18F'S FROM ITS AIRFRAME: the plank's beacon stood 1 m over a fin that is not on the centreline, and its
		# belly beacon under the wheels.
		var tips: Array[Vector3] = FighterAirframe.wingtips(geometry)
		var beacons: Dictionary = FighterAirframe.beacons(geometry)
		return {"port": tips[0], "starboard": tips[1], "strobes": _aft_of(tips), "tail": beacons["tail"],
			"top": beacons["top"], "bottom": beacons["bottom"]}
	match VehicleCatalogue.body(kind):
		VehicleCatalogue.Body.HAWKEYE:
			# THE TIPS AND THE ROTODOME'S BEACON FROM THE AIRFRAME; the tail light and the belly beacon are measured.
			var tips: Array[Vector3] = HawkeyeAirframe.wingtips(geometry)
			return {"port": tips[0], "starboard": tips[1], "strobes": _aft_of(tips),
				"top": Vector3(0.0, HawkeyeAirframe.rotodome_top(geometry) + PROUD,
					-(geometry.get("extents", Vector3.ONE) as Vector3).z + HawkeyeAirframe.ROTODOME_STATION)}
		# A HELICOPTER'S LIGHTS FROM ITS AIRFRAME, which says where the parts that carry them are. They were placed from the
		# collision box until 2026-09-17 -- the Chinook's beacons 1.4 m over its spine and 1 m under its belly and its tail
		# light 1.5 m behind the tail, the light helicopter's under its tail boom -- and the UH-60 carried none at all.
		VehicleCatalogue.Body.ROTOR, VehicleCatalogue.Body.UH60, VehicleCatalogue.Body.TANDEM, \
				VehicleCatalogue.Body.LITTLEBIRD, VehicleCatalogue.Body.APACHE:
			var at: Dictionary = _rotorcraft_lights(kind)
			return {"port": at["port"], "starboard": at["starboard"], "strobes": [at["strobe"]], "tail": at["tail"],
				"top": at["top"], "bottom": at["bottom"]}
	return {}


## WHERE AN AIRCRAFT'S WINGTIP LIGHTS ARE, left then right, where its airframe class says; empty where it does not. A
## view's `wingtips()` answers for every kind, from what it drew; this is for a check that holds an airframe to its own
## numbers.
static func published_wingtips(kind: int, geometry: Dictionary) -> Array[Vector3]:
	var stations: Dictionary = published(kind, geometry)
	if not stations.has("port"):
		return []
	return [stations["port"] as Vector3, stations["starboard"] as Vector3]


## WHICH HELICOPTER'S AIRFRAME SAYS WHERE ITS LIGHTS ARE, by the catalogue's shape.
static func _rotorcraft_lights(kind: int) -> Dictionary:
	match VehicleCatalogue.body(kind):
		VehicleCatalogue.Body.UH60:
			return Uh60Airframe.lights()
		VehicleCatalogue.Body.TANDEM:
			return ChinookAirframe.lights()
		VehicleCatalogue.Body.LITTLEBIRD:
			return LittleBirdAirframe.lights()
		VehicleCatalogue.Body.APACHE:
			return ApacheAirframe.lights(Sim.geometry_of(kind).get("extents", ApacheAirframe.DEFAULT_HALF) as Vector3)
	return LightHelicopterAirframe.lights()


static func _aft_of(tips: Array[Vector3]) -> Array:
	return [tips[0] + Vector3(0.0, 0.0, STROBE_AFT), tips[1] + Vector3(0.0, 0.0, STROBE_AFT)]


## THE LIGHTS, FROM WHERE THEY STAND: red and green on the tips, the strobes, white at the tail, and a red beacon top and
## bottom flashing half a cycle apart. A station that is missing or null is a light the type does not carry.
static func lamps_from(stations: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if stations.get("port") != null:
		out.append(_lamp(stations["port"], RED, Pattern.STEADY, 0.2, 1.0))
	if stations.get("starboard") != null:
		out.append(_lamp(stations["starboard"], GREEN, Pattern.STEADY, 0.2, 1.0))
	var strobes: Variant = stations.get("strobes")
	if strobes is Array:
		for strobe in (strobes as Array):
			out.append(_lamp(strobe, WHITE, Pattern.STROBE, 0.22, 1.8))
	if stations.get("tail") != null:
		out.append(_lamp(stations["tail"], WHITE, Pattern.STEADY, 0.18, 0.8))
	if stations.get("top") != null:
		out.append(_lamp(stations["top"], RED, Pattern.BEACON, 0.25, 1.5))
	if stations.get("bottom") != null:
		out.append(_lamp(stations["bottom"], RED, Pattern.BEACON, 0.25, 1.5, 0.5))
	return out


## ---- measured from the drawn skin ------------------------------------------------------

## EVERY DRAWN TRIANGLE OF A VIEW that a light could stand on, in the view's frame: shown meshes only, less `NOT_SKIN`,
## castings and the crew stations inside.
static func skin_of(view: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for node in view.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null or not _shown_skin(part, view):
			continue
		var frame: Transform3D = frame_in(part, view)
		for vertex in part.mesh.get_faces():
			out.append(frame * vertex)
	return out


## Whether `part` is drawn and is skin: every node from it up to `root` visible, none of them a crew station, and none
## named as a part that turns or stands off the airframe. Read from the `visible` flags rather than `is_visible_in_tree`,
## because a view is not always in a tree when it is built.
static func _shown_skin(part: Node, root: Node) -> bool:
	var at: Node = part
	while at != null and at != root:
		# A CASTING overlaps every part it was poured from, and moves with them by its bones: the parts are measured, the
		# casting never (`Casting.CAST_FROM`).
		if (at is Node3D and not (at as Node3D).visible) or at is CockpitStation or at.has_meta(Casting.CAST_FROM):
			return false
		for word in NOT_SKIN:
			if String(at.name).contains(word):
				return false
		at = at.get_parent()
	return at == root


## `node`'s transform in `root`'s frame, through the parents between, so it holds before either is in a tree.
static func frame_in(node: Node3D, root: Node3D) -> Transform3D:
	var frame := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != root:
		if at is Node3D:
			frame = (at as Node3D).transform * frame
		at = at.get_parent()
	return frame


## WHERE THE LIGHTS GO ON A DRAWN SKIN, from its triangles alone:
##
## - the NAV LIGHTS on the drawn tips, the outermost points either side, with a strobe further aft on the same tip face;
## - the TAIL LIGHT on the aftmost point of the centreline;
## - the BEACONS on the top and the bottom of the skin where the centreline crosses the wingtips' station, which is where
##   an airliner or a transport carries them, over and under the wing box.
static func measured(skin: PackedVector3Array) -> Dictionary:
	if skin.size() < 3:
		return {}
	var least: float = INF
	var most: float = -INF
	for p in skin:
		least = minf(least, p.x)
		most = maxf(most, p.x)
	var port: Array = _tip(skin, least, -1.0)
	var starboard: Array = _tip(skin, most, 1.0)
	# THE TAIL: the aftmost drawn point near the centreline, itself. Not the middle of the points there: a loft that ends
	# in an open ring has no skin at its middle, and the Osprey's tail light stood 0.19 m inside its tail cone that way.
	var tail := Vector3(0.0, 0.0, -INF)
	for p in skin:
		if absf(p.x) < 0.3 and (p.z > tail.z + 0.001 or (absf(p.z - tail.z) <= 0.001 and absf(p.x) < absf(tail.x))):
			tail = p
	var out: Dictionary = {"port": port[0], "starboard": starboard[0], "strobes": [port[1], starboard[1]],
		"tail": Vector3(tail.x, tail.y, tail.z + PROUD)}
	# THE BEACONS where the centreline crosses the tips' station, stepping along a quarter-metre at a time where a gap in
	# the skin leaves that line open.
	var station: float = ((port[0] as Vector3).z + (starboard[0] as Vector3).z) * 0.5
	for step in [0.0, 0.25, -0.25, 0.5, -0.5, 0.75, -0.75, 1.0, -1.0, 1.5, -1.5, 2.0, -2.0]:
		var span: Vector2 = _crossing(skin, station + step)
		if span.x <= span.y:
			out["top"] = Vector3(0.0, span.y + PROUD, station + step)
			out["bottom"] = Vector3(0.0, span.x - PROUD, station + step)
			break
	return out


## A TIP: the nav light a quarter of the way aft along the tip's drawn points and the strobe three quarters, both just
## outboard of the outermost point, at the tip's middle height. [nav, strobe].
static func _tip(skin: PackedVector3Array, edge: float, side: float) -> Array:
	var fore: float = INF
	var aft: float = -INF
	var height := 0.0
	var n := 0
	for p in skin:
		if absf(p.x - edge) <= 0.05:
			fore = minf(fore, p.z)
			aft = maxf(aft, p.z)
			height += p.y
			n += 1
	var x: float = edge + side * PROUD
	var y: float = height / maxf(n, 1)
	return [Vector3(x, y, lerpf(fore, aft, 0.25)), Vector3(x, y, lerpf(fore, aft, 0.75))]


## Where the vertical line through (0, z) meets the skin: (lowest, highest), or (INF, -INF) where it meets nothing.
static func _crossing(skin: PackedVector3Array, z: float) -> Vector2:
	var low: float = INF
	var high: float = -INF
	var at := Vector2(0.0, z)
	for i in range(0, skin.size() - 2, 3):
		var a := Vector2(skin[i].x, skin[i].z)
		var b := Vector2(skin[i + 1].x, skin[i + 1].z)
		var c := Vector2(skin[i + 2].x, skin[i + 2].z)
		var area: float = (b - a).cross(c - a)
		if absf(area) < 1e-9:
			continue
		var u: float = (b - at).cross(c - at) / area
		var v: float = (c - at).cross(a - at) / area
		var w: float = 1.0 - u - v
		if u < -1e-5 or v < -1e-5 or w < -1e-5:
			continue
		var y: float = u * skin[i].y + v * skin[i + 1].y + w * skin[i + 2].y
		low = minf(low, y)
		high = maxf(high, y)
	return Vector2(low, high)


static func _lamp(at: Vector3, colour: Color, pattern: int, radius: float, floor_scale: float,
		phase: float = 0.0) -> Dictionary:
	return {"position": at, "colour": colour, "pattern": pattern, "radius": radius,
		"floor": floor_scale, "phase": phase}
