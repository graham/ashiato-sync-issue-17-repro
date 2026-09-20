extends Node
class_name Daylight
## THE SUN, THE MOON, THE SKY AND THE FOG AT THE SESSION'S TIME OF DAY -- and told to the renderer in coarse steps, never
## per frame.
##
## Owned by the level (`FlightLevel.daylight`), handed the level's own DirectionalLight3D and Environment,
## and asked by nothing but the level: the clipboard's TIME tab ANNOUNCES a press, the level
## decides, and this is what the level decides with. Every number is `DaylightTuning`'s and `Orrery`'s.
##
## A CLOCK, NOT THREE PRESETS (2026-09-18). The time is the session's clock (`Net.clock_now`), which runs at the rate the
## host set -- frozen, real time or faster -- and the look is `DaylightTuning.look_at` the clock. The three presets are
## points on it (`show_time`), and look as they did.
##
## IN STEPS, NEVER PER FRAME. Every property set on a light, an environment or a sky material is a call into the
## RenderingServer, and a script re-telling it the same sky every frame was measured on this machine at about half a
## millisecond; a sky material that changes also has its radiance drawn again. So the clock is read every frame -- a few
## sums -- and the world is told only when the sun or the moon has moved `STEP_DEGREES` since it was last told, and never
## twice inside `STEP_GAP` seconds; a clock that is frozen writes nothing at all. A jump -- a new time chosen, or heard from
## the host -- is shown at once. Every write goes through `_write`, which counts: tests/scenery.gd holds `writes` to none
## over sixty frames of a frozen clock and to `steps * writes_per_step()` over a fast one.
##
## THE LIGHT IS THE SUN OR THE MOON (`DaylightTuning.look_at`'s "light_is_moon"), and both skies draw the moon along its
## own direction (`moon_direction`), so a moon over the blue hour stands where it is while the sun is still the light.

## The world was told a new look. See `DaylightTuning.look_at` for what is in it.
signal changed(look: Dictionary)

## `--time=day|evening|night|dawn|dusk|HH:MM` after the bare `--`.
const FLAG: String = "time"
## `--clock-rate=N`: game seconds a real second. 0 is frozen, 1 real time.
const RATE_FLAG: String = "clock-rate"
## THE TWO SKIES: Godot's procedural sky, copied, with the moon; FINE's with cirrus as well. See the shaders' notes.
const FINE_SKY: Shader = preload("res://world/shaders/sky_fine.gdshader")
const PLAIN_SKY: Shader = preload("res://world/shaders/sky_plain.gdshader")

## HOW FAR THE SUN OR THE MOON MOVES BEFORE THE WORLD IS TOLD AGAIN, degrees, and the least time between two tellings,
## seconds. A quarter of a degree is half the sun's own width, and at the fastest rate the board offers (600 times) the sun
## crosses it in a tenth of a second, so the gap is what holds that rate to two steps a second. At real time a step is a
## minute apart.
const STEP_DEGREES: float = 0.25
const STEP_GAP: float = 0.5
## A TIME-LAPSE STEPS EVERY FRAME. At a day in ten seconds (`Net.CLOCK_RATE_LAPSE`) the gap above would allow 20 steps a
## day, 18 degrees of sun apiece: a slideshow. So a clock running at `LAPSE_FROM` or faster -- a day in twenty seconds --
## tells the world every frame, and pays for it (`step_usec`, measured in tests/scenery.gd and written in agents.md).
## Everything slower keeps the step rule, so 3,600 times is still two steps a second.
const LAPSE_FROM: float = 4320.0

## THE LAMPS: floodlights and anything else that is simply on or off comes on as the sun goes under `LAMPS_ON_BELOW`
## degrees and off as it climbs over `LAMPS_OFF_ABOVE`, so a sun hovering at the threshold cannot flicker them. On at
## EVENING (7 up) and off at DAY (34.8), as the presets had them.
const LAMPS_ON_BELOW: float = 10.0
const LAMPS_OFF_ABOVE: float = 12.0

## Which `DaylightTuning.When` the clock is nearest of the three presets, or -1 before the first look. For the reports.
var time: int = -1
## The clock the world was last told, minutes, or -1.
var clock: float = -1.0
## The look the world was last told, `DaylightTuning.look_at`'s, with "n", "lamps" and "time" added.
var look: Dictionary = {}
## How many looks the world has been told, ever.
var steps: int = 0
## How many properties this has written, ever. See the note at the top.
var writes: int = 0
## HOW LONG TELLING THE WORLD HAS TAKEN, microseconds, over every step ever, and the longest one: the look, the writes here
## and every consumer `changed` reaches, which are called inside the step. What a time-lapse costs a frame.
var step_usec: int = 0
var step_usec_worst: int = 0
## WHAT EACH PART OF A STEP COSTS, microseconds: name -> [total, worst, count], over every step. The look and the writes
## here, and every consumer the level calls inside a step (`FlightLevel._on_the_time_changed`). `cost_since` reads it.
var costs: Dictionary = {}


## COUNT `name` as having cost from `began` (a `Time.get_ticks_usec`) to now. See `costs`.
func count(name: String, began: int) -> void:
	var spent: int = Time.get_ticks_usec() - began
	var row: Array = costs.get(name, [0, 0, 0])
	costs[name] = [int(row[0]) + spent, maxi(int(row[1]), spent), int(row[2]) + 1]


## THE COSTS AS A LINE, the dearest first: "name mean/worst us" for each part.
func costs_said() -> String:
	var names: Array = costs.keys()
	names.sort_custom(func(a, b): return int(costs[a][1]) > int(costs[b][1]))
	var out: PackedStringArray = []
	for name in names:
		var row: Array = costs[name]
		out.append("%s %.0f/%d" % [name, float(row[0]) / maxf(float(row[2]), 1.0), int(row[1])])
	return ", ".join(out)
## Whether the lamps are on. See `LAMPS_ON_BELOW`.
var lamps: bool = false

var _sun: DirectionalLight3D = null
var _air: Environment = null
## When the world was last told, seconds of this node's own frames. See `_process`.
var _age: float = 0.0
var _told_at: float = -INF
## THE SKY FINE WEARS: the procedural sky's own code with the moon, and cirrus in its half-resolution pass
## (`world/shaders/sky_fine.gdshader`), painted with the same numbers as `plain_sky` on every change. The level puts one or the
## other on the environment.
var fine_sky: ShaderMaterial = null
## THE SKY PLAIN WEARS: the same procedural sky with the moon and no cirrus (`world/shaders/sky_plain.gdshader`). Until
## 2026-09-15 it was the ProceduralSkyMaterial in world/sky.tscn, which has no moon to wear, and a headset starts on PLAIN.
var plain_sky: ShaderMaterial = null
## How deep in a cloud the eye is, 0 to 1, and the cloud's colour, as the level last said. See `show_in_cloud`.
var in_cloud: float = 0.0
var _cloud_colour: Color = Color.WHITE
## Whether the session's clock is read every frame: off for a probe that puts a time straight on this.
var follows_the_clock: bool = true
## THE SHARE OF THE GAME'S CLEAR AIR THIS LEVEL HOLDS (`LevelChart.haze`), 1 unless the level asks for less.
var haze: float = 1.0


func _init(sun: DirectionalLight3D, air: Environment) -> void:
	name = "Daylight"
	_sun = sun
	_air = air
	plain_sky = sky_material(PLAIN_SKY)
	fine_sky = fine_sky_material()


## READ THE CLOCK, AND STEP when the sky has moved far enough and long enough since it was last told. Sums only, and
## nothing written, on every other frame.
func _process(delta: float) -> void:
	_age += delta
	if not follows_the_clock or look.is_empty():
		return
	var now: float = Net.clock_now()
	if Net.clock_rate >= LAPSE_FROM:
		show_clock(now, false)
		return
	if _age - _told_at < STEP_GAP:
		return
	if moved(clock, now) < STEP_DEGREES:
		return
	show_clock(now, false)


## HOW FAR THE SUN OR THE MOON HAS MOVED between two clocks, degrees: the larger.
static func moved(from: float, to: float) -> float:
	if from < 0.0:
		return INF
	var sun: float = rad_to_deg(Orrery.sun(from).angle_to(Orrery.sun(to)))
	var moon: float = rad_to_deg(Orrery.moon(from).angle_to(Orrery.moon(to)))
	return maxf(sun, moon)


## PUT A PRESET'S POINT ON THE CLOCK ON THE WORLD: `which` a `DaylightTuning.When`.
func show_time(which: int) -> void:
	show_clock(DaylightTuning.clock_of(clampi(which, 0, DaylightTuning.When.size() - 1)))


## PUT THE LOOK AT `minutes` ON THE WORLD, unless it is on already. `said` prints the time to the log, as a jump -- a time
## chosen or heard -- does; a step of a running clock does not, because a line printed to a log file every frame of a
## time-lapse cost about 2.5 ms of a step on its own (the forced-step round of tests/daytime_shot.gd --measure, 2026-09-18:
## 3,367 us a step with the line, the parts of the step adding up to about 800).
func show_clock(minutes: float, said: bool = true) -> void:
	minutes = fposmod(minutes, Orrery.DAY_LONG)
	if is_equal_approx(minutes, clock) and not look.is_empty():
		return
	clock = minutes
	_told_at = _age
	var began: int = Time.get_ticks_usec()
	var p: Dictionary = DaylightTuning.look_at(minutes)
	count("look", began)
	var writing: int = Time.get_ticks_usec()
	var height: float = float(p["sun_height"])
	if height < LAMPS_ON_BELOW:
		lamps = true
	elif height > LAMPS_OFF_ABOVE:
		lamps = false
	steps += 1
	p["n"] = steps
	p["lamps"] = lamps
	time = nearest_preset(minutes)
	p["time"] = time
	look = p
	if _sun != null:
		# THE LIGHT SHINES DOWN ITS OWN -Z, so it looks AWAY from the sun (or the moon). Only the basis: the node's position
		# is nothing a directional light has. Dark, it is hidden, so a moonless night draws no shadow map.
		_write(_sun, &"basis", Basis.looking_at(-(p["towards_light"] as Vector3), Vector3.UP))
		_write(_sun, &"light_color", p["sun_colour"])
		_write(_sun, &"light_energy", p["sun_energy"])
		_write(_sun, &"visible", float(p["sun_energy"]) > 0.0)
	if _air != null:
		_write(_air, &"ambient_light_source", Environment.AMBIENT_SOURCE_SKY)
		_write(_air, &"ambient_light_sky_contribution", p["ambient_sky"])
		_write(_air, &"ambient_light_color", p["ambient_colour"])
		_write(_air, &"ambient_light_energy", p["ambient_energy"])
		_write_the_fog()
	# THE SAME ON BOTH SKIES, whichever is worn, so a change of finish never shows yesterday's sky: the four colours, the moon
	# -- where it is, how bright its face, its light for the halo, and whether it is the light -- where the sun truly is,
	# which the moon takes its phase from, and how much of the star field is out, which is that sun's elevation's.
	for paint in [plain_sky, fine_sky]:
		if paint == null:
			continue
		_write(paint, &"shader_parameter/sky_top_color", p["sky_top"])
		_write(paint, &"shader_parameter/sky_horizon_color", p["sky_horizon"])
		_write(paint, &"shader_parameter/ground_bottom_color", p["ground_bottom"])
		_write(paint, &"shader_parameter/ground_horizon_color", p["ground_horizon"])
		_write(paint, &"shader_parameter/moon_bright", p["moon_bright"])
		_write(paint, &"shader_parameter/moon_direction", p["moon"])
		_write(paint, &"shader_parameter/moon_light", p["moon_light"])
		_write(paint, &"shader_parameter/light_is_moon", 1.0 if bool(p["light_is_moon"]) else 0.0)
		_write(paint, &"shader_parameter/true_sun", p["true_sun"])
		_write(paint, &"shader_parameter/stars", p["stars"])
		_write(paint, &"shader_parameter/dusk_glow", p["dusk_glow"])
		_write(paint, &"shader_parameter/sun_seen", p["sun_seen"])
	count("writes", writing)
	if said:
		print("[daylight] %s %s" % [Orrery.words(minutes), DaylightTuning.name_of(time)])
	changed.emit(p)
	var spent: int = Time.get_ticks_usec() - began
	step_usec += spent
	step_usec_worst = maxi(step_usec_worst, spent)


## HOW MANY PROPERTIES ONE STEP WRITES, in a level with a light, an environment and both skies: what tests/scenery.gd holds a
## running clock to. Counted off the code above, not typed: a light's four, the environment's four and its fog's four,
## and each sky's twelve.
static func writes_per_step() -> int:
	return 4 + 4 + 4 + 2 * 12


## WHICH OF THE THREE PRESETS THE LOOK AT `minutes` IS MOST LIKE, as a `DaylightTuning.When`: what a report names, the
## dial points at and the map is drawn again on. By the look's own weights, not by the clock -- 05:30 is an hour from DAY
## and five from NIGHT on the clock, and it is dark. A tie goes to the earlier preset.
static func nearest_preset(minutes: float) -> int:
	var like: Vector3 = DaylightTuning.look_at(minutes)["like"]
	if like.x >= like.y and like.x >= like.z:
		return DaylightTuning.When.DAY
	return DaylightTuning.When.EVENING if like.y >= like.z else DaylightTuning.When.NIGHT


## THE EYE IS IN A CLOUD AND THERE IS NO FOG TO FLY INTO -- PLAIN, or FINE with no fog clouds -- so the depth fog whites the
## view out, decided by the level: by `depth` from the time of day's clear air to `CloudTuning.WHITEOUT_DENSITY`, its light to
## `colour` (the cloud's, `LiftYard.cloud_colour`), and the aerial perspective, which would tint it with the sky, to none.
## Written only when either changes, like everything here.
## THE LEVEL'S AIR (`LevelChart.haze`; lane/testfield, 2026-09-19): a share of every time of day's clear air, written now.
## A cloud's whiteout is not thinned: flying into a cloud on a clear level is still flying into a cloud.
func thin_the_air(share: float) -> void:
	haze = share
	_write_the_fog()


func show_in_cloud(depth: float, colour: Color) -> void:
	depth = clampf(depth, 0.0, 1.0)
	if is_equal_approx(depth, in_cloud) and colour.is_equal_approx(_cloud_colour):
		return
	# OUT OF CLOUD BEFORE AND AFTER, THE CLOUD'S COLOUR IS NOTHING THE FOG SHOWS: kept, and nothing written. The level hands
	# the colour on every step of the clock, and the eye is in no cloud nearly always.
	if depth == 0.0 and in_cloud == 0.0:
		_cloud_colour = colour
		return
	in_cloud = depth
	_cloud_colour = colour
	_write_the_fog()


## The depth fog for the time of day -- its clear air -- pulled toward the cloud the eye is in.
##
## THE LOW MIST IS NOT HERE ANY MORE. Until 2026-09-15 this eased the depth fog from a thick `mist_density` near the ground to
## `mist_above` by `mist_top`, by the EYE's height, so the whole view thickened as the eye came down, and a city, a valley and
## open ground wore one wall (godotgames-drafts/2026-09-15/cockpit-mist/survey). The mist lies in the world now, on the ground
## under it (`MistLayer`), and the depth fog is the air between, the same at every height.
func _write_the_fog() -> void:
	if _air == null or look.is_empty():
		return
	_write(_air, &"fog_density", lerpf(float(look["clear_air"]) * haze, CloudTuning.WHITEOUT_DENSITY, in_cloud))
	_write(_air, &"fog_light_color", (look["fog_colour"] as Color).lerp(_cloud_colour, in_cloud))
	_write(_air, &"fog_aerial_perspective", lerpf(float(look["fog_aerial_perspective"]), 0.0, in_cloud))
	# IN A CLOUD THE WHITEOUT COVERS THE SKY TOO, whatever the dusk has made of it.
	_write(_air, &"fog_sky_affect", lerpf(float(look["fog_sky_affect"]), 1.0, in_cloud))


func _write(target: Object, property: StringName, value: Variant) -> void:
	target.set(property, value)
	writes += 1


## A SKY'S MATERIAL, with `NightSkyTuning`'s moon -- its face, its size, its tint, its terminator, its earthshine and halo -- and
## its stars, none of which a time of day changes. Its colours, the moon, the true sun and how much of the star field is out
## are the shader's defaults until the first look.
static func sky_material(shader: Shader) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = shader
	paint.set_shader_parameter("moon_face", load(NightSkyTuning.MOON_FACE_PATH))
	paint.set_shader_parameter("moon_radius", NightSkyTuning.moon_radius())
	paint.set_shader_parameter("moon_tint", NightSkyTuning.MOON_TINT)
	paint.set_shader_parameter("moon_terminator", NightSkyTuning.MOON_TERMINATOR)
	paint.set_shader_parameter("moon_earthshine", NightSkyTuning.EARTHSHINE)
	paint.set_shader_parameter("moon_halo", NightSkyTuning.MOON_HALO)
	paint.set_shader_parameter("moon_halo_width", deg_to_rad(NightSkyTuning.MOON_HALO_DEGREES))
	paint.set_shader_parameter("star_cells", NightSkyTuning.STAR_CELLS)
	paint.set_shader_parameter("star_share", NightSkyTuning.STAR_SHARE)
	paint.set_shader_parameter("star_power", NightSkyTuning.STAR_POWER)
	paint.set_shader_parameter("star_bright", NightSkyTuning.STAR_BRIGHT)
	paint.set_shader_parameter("star_pixels", NightSkyTuning.STAR_PIXELS)
	paint.set_shader_parameter("star_margin", NightSkyTuning.STAR_MARGIN)
	paint.set_shader_parameter("star_horizon", NightSkyTuning.STAR_HORIZON)
	paint.set_shader_parameter("star_moon_near", deg_to_rad(NightSkyTuning.STAR_MOON_NEAR_DEGREES))
	paint.set_shader_parameter("star_moon_wash", NightSkyTuning.STAR_MOON_WASH)
	paint.set_shader_parameter("star_blue", NightSkyTuning.STAR_BLUE)
	paint.set_shader_parameter("star_orange", NightSkyTuning.STAR_ORANGE)
	return paint


## THE FINE SKY'S MATERIAL: a sky's, with `CloudTuning`'s cirrus.
static func fine_sky_material() -> ShaderMaterial:
	var paint := sky_material(FINE_SKY)
	paint.set_shader_parameter("cirrus_height", CloudTuning.CIRRUS_HEIGHT)
	paint.set_shader_parameter("cirrus_cover", CloudTuning.CIRRUS_COVER)
	paint.set_shader_parameter("cirrus_opacity", CloudTuning.CIRRUS_OPACITY)
	paint.set_shader_parameter("cirrus_scale", CloudTuning.CIRRUS_SCALE)
	paint.set_shader_parameter("cirrus_stretch", CloudTuning.CIRRUS_STRETCH)
	paint.set_shader_parameter("cirrus_heading", CloudTuning.CIRRUS_HEADING)
	paint.set_shader_parameter("cirrus_reach", CloudTuning.CIRRUS_REACH)
	paint.set_shader_parameter("cirrus_sun_share", CloudTuning.CIRRUS_SUN_SHARE)
	paint.set_shader_parameter("cirrus_sky_share", CloudTuning.CIRRUS_SKY_SHARE)
	return paint


## Whether `--cirrus=off` was asked for after the bare `--`: FINE then keeps PLAIN's sky, to time the cirrus against.
static func cirrus_asked_off() -> bool:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() == 2 and parts[0].to_lower() == "cirrus":
			return parts[1].to_lower() == "off"
	return false


## THE CLOCK `--time=` ASKS FOR, minutes: a named point (day, evening, night, dawn, dusk) or HH:MM. -1 when the command line
## says nothing, or says something that is not a time -- reported, not guessed at.
static func asked_on_the_command_line() -> float:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2 or parts[0].to_lower() != FLAG:
			continue
		var named: int = Orrery.point_named(parts[1])
		if named >= 0:
			return Orrery.point(named)
		var minutes: float = Orrery.minutes_of(parts[1])
		if minutes >= 0.0:
			return minutes
		push_warning("[daylight] --time=%s is not a time of day; it is dawn, day, evening, dusk, night or HH:MM" % parts[1])
	return -1.0


## THE RATE `--clock-rate=` ASKS FOR, game seconds a real second, or -1 when it says nothing a rate can be. Clamped to
## `Net.CLOCK_RATE_MOST`, and the clamp said.
static func rate_asked_on_the_command_line() -> float:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2 or parts[0].to_lower() != RATE_FLAG:
			continue
		if not parts[1].is_valid_float() or parts[1].to_float() < 0.0:
			push_warning("[daylight] --clock-rate=%s is not a rate; it is 0 (frozen) or more" % parts[1])
			return -1.0
		if parts[1].to_float() > Net.CLOCK_RATE_MOST:
			push_warning("[daylight] --clock-rate=%s is faster than %d; clamped" % [parts[1], int(Net.CLOCK_RATE_MOST)])
		return minf(parts[1].to_float(), Net.CLOCK_RATE_MOST)
	return -1.0
