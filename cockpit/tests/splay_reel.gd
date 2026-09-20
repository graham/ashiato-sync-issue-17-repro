extends Node
## A REEL OF BULLET SPLAY: two A-10s on a firing tower put a burst each into a gridded wall 800 m off -- one with its
## gun dead true, one with the scatter the game gives it -- so the difference is a picture and not a claim
## (lane/splayreel, 2026-09-20).
##
##   <editor>.console.exe --path cockpit --xr-mode off --resolution 1600x900 --fixed-fps 30 --write-movie <out.avi>
##       res://tests/splay_reel.tscn -- --level=watch
##   ... -- --level=watch --no-picture      (headless: the numbers only, no camera and no captions)
##
## THE SPLAY IS THE GAME'S OWN. `cockpit_world.cpp` gives the Warthog's 30 mm 2 mrad (`scatter`, a cone half-angle in
## radians, the rounds spread evenly over its disc). Both aircraft fire through the pilot's trigger, master arm on, the
## path a player's finger takes. The control is the world's own test knob, `set_gun_scatter_scale(0)`, turned to 0 for the
## first burst and back to 1 for the second: the same airframe, the same tower, the same wall, and the only thing
## different is the number under test.
##
## WHY A WALL AND A TOWER. Shot at the ground from the ground, a gun's rounds land on a grazing angle and a 2 mrad cone
## smears into a hundred metres of ground; only a surface square to the line of fire shows the cone as a disc. And the
## Warthog's bore points 30-odd mrad down, so it needs the height to still be flying when it reaches the wall: a tower
## (`add_static_box`, and the same box drawn) of `TOWER_H` and a wall as wide and as tall as the shot needs.
##
## THE DOTS ARE AN OVERLAY, and the caption says so: the game's own hit puffs last a moment, a picture of a pattern wants
## every round to stay, so each landed round's `impact` (the server's own row) leaves a small disc on the wall.
##
## NEVER A CAPTURE OF THE DESKTOP: MovieWriter records this probe's own viewport. Read RESULT=, not the exit code.

## THE WARTHOG'S SCATTER, radians, typed here on purpose as the thing the table is checked AGAINST (`tests/gun_scatter.gd`
## does the same for the fighter): `gun_schema` does not carry it.
const SCATTER: float = 0.002
const CLIENT_A: int = 77
const CLIENT_B: int = 78
const KIND_NAME: String = "A-10 Warthog, 30 mm GAU-8"
const SITE := Vector3(-1200.0, 0.0, 2200.0)
const RANGE_M: float = 800.0
const TOWER_H: float = 60.0
const WALL_H: float = 90.0
const WALL_HALF_Z: float = 30.0
const SIDE_M: float = 6.0
const BURST_S: float = 2.0
const CAL_S: float = 0.4
const A_AT: float = 2.0
const B_AT: float = 6.0
const PUSH_AT: float = 10.5
const TO_B_AT: float = 15.0
const PUSH_S: float = 2.5
const END_AT: float = 21.0
const WIDE_BACK: float = 27.0
const CLOSE_BACK: float = 6.0

var _level: FlightLevel = null
var _pictures: bool = true
var _failures: PackedStringArray = []
var _started: bool = false
var _clock: float = 0.0
var _pilots: Array[int] = [0, 0]
var _crafts: Array[int] = [0, 0]
var _inputs: Array[Dictionary] = [{}, {}]
var _last: Dictionary = {}
var _hits: Array[Array] = [[], []]
var _live_of: Dictionary = {}
var _firing: int = -1
var _fire_until: float = 0.0
var _phase: String = "settle"
var _wall_x: float = 0.0
var _centre := Vector3.ZERO
var _from_x: float = 0.0
var _dots: Array[MeshInstance3D] = []
var _dot_mesh: Mesh = null
var _mats: Array[StandardMaterial3D] = []
var _caption: Label = null
var _small: Label = null
var _observer: Node3D = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[splay_reel] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pictures = not ("--no-picture" in OS.get_cmdline_user_args())
	if _pictures and DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; pass --no-picture for the numbers")
		_finish()
		return
	Net.choose_level("island")
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	_observer = _level.observer
	_wall_x = SITE.x + RANGE_M + 1.0
	_build_range()
	if _pictures:
		_build_captions()
	for i in range(240):
		await get_tree().physics_frame
	_park_the_pair()
	for i in range(240):
		_hold()
		await get_tree().physics_frame
	_arm()
	for i in range(30):
		_hold()
		await get_tree().physics_frame
	# THE WALL'S HEIGHT AT THE HIT, MEASURED NOT TYPED: a short burst from the first gun with the scatter off, and where it
	# lands is where the camera looks and where the wall is centred. The dots it leaves are cleared.
	Sim.server.set_gun_scatter_scale(0.0)
	_phase = "calibrate"
	_begin_burst(0, CAL_S)
	while _firing >= 0 or _live_of.size() > 0:
		_step()
		await get_tree().physics_frame
	var cal: Array = _hits[0]
	_check("calibration_landed_on_the_wall", cal.size() >= 3, "%d rounds" % cal.size())
	if cal.size() < 3:
		_finish()
		return
	_centre = _mean(cal)
	_from_x = _muzzle_x()
	_hits = [[], []]
	for d in _dots:
		d.queue_free()
	_dots.clear()
	print("[splay_reel] the recording starts at frame %d; the wall is hit at y %.1f, range %.1f m"
		% [Engine.get_frames_drawn(), _centre.y, _centre.x - _from_x])
	_started = true
	_clock = 0.0
	_phase = "a"


func _physics_process(_delta: float) -> void:
	if not _started:
		return
	_clock += Sim.tick_dt()
	if _clock >= A_AT and _phase == "a":
		_phase = "burst_a"
		Sim.server.set_gun_scatter_scale(0.0)
		_begin_burst(0, BURST_S)
	if _clock >= B_AT and _phase == "burst_a":
		_phase = "burst_b"
		Sim.server.set_gun_scatter_scale(1.0)
		_begin_burst(1, BURST_S)
	_step()
	if _clock >= END_AT:
		_started = false
		_end()


func _process(_delta: float) -> void:
	if not _started or not _pictures:
		return
	_frame()
	_caption.text = _words()
	_small.text = _numbers()


## HOLD BOTH PILOTS STILL, brakes on, and ask the trigger of whichever is firing.
func _step() -> void:
	if _firing >= 0 and _clock_now() >= _fire_until:
		_firing = -1
	for i in range(2):
		_inputs[i]["trigger"] = 1.0 if i == _firing else 0.0
	_hold()
	var alive := {}
	for row in Sim.server.shot_states():
		var entity: int = int((row as Dictionary).get("entity", 0))
		alive[entity] = true
		_last[entity] = row
	for entity in _last.keys():
		if alive.has(entity):
			continue
		var row: Dictionary = _last[entity]
		_last.erase(entity)
		var who: int = int(_live_of.get(entity, -1))
		_live_of.erase(entity)
		if who < 0:
			continue
		var at: Vector3 = row.get("impact", Vector3.ZERO)
		if at != Vector3.ZERO:
			_hits[who].append(at)
			_drop_a_dot(who, at)
	for row in Sim.server.shot_states():
		var entity: int = int((row as Dictionary).get("entity", 0))
		if not _live_of.has(entity) and _firing >= 0:
			_live_of[entity] = _firing


var _now: float = 0.0


func _clock_now() -> float:
	return _now


func _begin_burst(which: int, seconds: float) -> void:
	_firing = which
	_fire_until = _now + seconds


func _hold() -> void:
	_now += Sim.tick_dt()
	for i in range(2):
		if _pilots[i] != 0:
			Sim.server.set_pilot_input(_pilots[i], _inputs[i])


func _park_the_pair() -> void:
	var hy: float = float((Sim.geometry_of(Sim.Kind.WARTHOG).get("extents", Vector3.ONE) as Vector3).y)
	for i in range(2):
		var side: float = -SIDE_M if i == 0 else SIDE_M
		var made: Dictionary = Sim.server.spawn_pilot(CLIENT_A + i, Sim.Kind.WARTHOG,
			Vector3(SITE.x, TOWER_H + hy + 0.05, SITE.z + side), -PI * 0.5, Vector3.ZERO)
		_crafts[i] = int(made.get("vehicle", 0))
		_pilots[i] = int(made.get("pilot", 0))
		_inputs[i] = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 1.0, "trigger": 0.0}


func _arm() -> void:
	for i in range(2):
		_inputs[i]["command_channel"] = Sim.Channel.MASTER
		_inputs[i]["command_value"] = 1
		_inputs[i]["command_seq"] = 1


func _muzzle_x() -> float:
	return float((Sim.server.vehicle_state(_crafts[0]).get("position", Vector3.ZERO) as Vector3).x)


## THE TOWER AND THE WALL, each drawn and each solid: the same numbers to `Sim.add_static_box` and to the mesh.
func _build_range() -> void:
	var tower_half := Vector3(16.0, TOWER_H * 0.5, 16.0)
	var tower_at := Vector3(SITE.x, TOWER_H * 0.5, SITE.z)
	var wall_half := Vector3(1.0, WALL_H * 0.5, WALL_HALF_Z)
	var wall_at := Vector3(_wall_x, WALL_H * 0.5, SITE.z)
	Sim.add_static_box(tower_at, tower_half)
	Sim.add_static_box(wall_at, wall_half)
	if not _pictures:
		return
	_level.add_child(_box(tower_at, tower_half, _plain(Color(0.42, 0.42, 0.45))))
	_level.add_child(_box(wall_at, wall_half, _grid()))
	_dot_mesh = SphereMesh.new()
	(_dot_mesh as SphereMesh).radius = 0.09
	(_dot_mesh as SphereMesh).height = 0.18
	for c in [Color(0.2, 0.9, 1.0), Color(1.0, 0.55, 0.1)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats.append(m)


func _box(at: Vector3, half: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = half * 2.0
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	return node


func _plain(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	return m


## A GRID IN METRES, painted on the wall's own coordinates: a fine line every metre, a heavy one every five.
func _grid() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type spatial;\nrender_mode unshaded;\nvarying vec3 lp;\n" \
		+ "void vertex() { lp = VERTEX; }\n" \
		+ "void fragment() {\n" \
		+ "  vec2 g = vec2(lp.z, lp.y + 45.0);\n" \
		+ "  vec2 f1 = abs(fract(g + 0.5) - 0.5);\n" \
		+ "  vec2 f5 = abs(fract(g / 5.0 + 0.5) - 0.5) * 5.0;\n" \
		+ "  float w = 0.03;\n" \
		+ "  float thin = step(min(f1.x, f1.y), w);\n" \
		+ "  float heavy = step(min(f5.x, f5.y), w * 2.2);\n" \
		+ "  vec3 base = vec3(0.16, 0.18, 0.22);\n" \
		+ "  ALBEDO = mix(mix(base, vec3(0.34, 0.37, 0.42), thin), vec3(0.72, 0.74, 0.78), heavy);\n" \
		+ "}\n"
	var m := ShaderMaterial.new()
	m.shader = shader
	return m


func _drop_a_dot(who: int, at: Vector3) -> void:
	if not _pictures:
		return
	var dot := MeshInstance3D.new()
	dot.mesh = _dot_mesh
	dot.material_override = _mats[who]
	dot.scale = Vector3(0.25, 1.0, 1.0)
	dot.position = Vector3(minf(at.x, _wall_x - 1.0) - 0.03, at.y, at.z)
	_level.add_child(dot)
	_dots.append(dot)


func _mean(points: Array) -> Vector3:
	var sum := Vector3.ZERO
	for p in points:
		sum += p as Vector3
	return sum / maxf(1.0, float(points.size()))


## HOW FAR THE WIDEST ROUND LANDED FROM THE MIDDLE OF ITS OWN PATTERN, in the wall's plane, metres.
func _widest(points: Array) -> float:
	var mid: Vector3 = _mean(points)
	var far: float = 0.0
	for p in points:
		var d: Vector3 = (p as Vector3) - mid
		far = maxf(far, Vector2(d.y, d.z).length())
	return far


## THE CONE'S RADIUS AT THE WALL, from the table's own number: range times the tangent of the half-angle.
func _cone_m() -> float:
	return (_centre.x - _from_x) * tan(SCATTER)


func _words() -> String:
	var live: String = ""
	match _phase:
		"a", "burst_a":
			live = "A  --  gun dead true (scatter 0)"
		"burst_b":
			live = "B  --  the gun as the game fires it (scatter 2 mrad)"
	if _clock > TO_B_AT + PUSH_S * 0.5:
		live = "B  --  close up: the same 130 rounds"
	elif _clock > PUSH_AT + PUSH_S * 0.5:
		live = "A  --  close up: the same 130 rounds, one point"
	return "%s, %.0f m from the wall\n%s" % [KIND_NAME, _centre.x - _from_x, live]


func _numbers() -> String:
	var a: Array = _hits[0]
	var b: Array = _hits[1]
	var lines: PackedStringArray = ["grid 1 m, heavy line every 5 m.  dots are an overlay: one per round landed"]
	lines.append("A: %3d rounds, widest %.2f m from the middle" % [a.size(), _widest(a) if a.size() > 1 else 0.0])
	lines.append("B: %3d rounds, widest %.2f m from the middle  (cone radius at this range: %.2f m)"
		% [b.size(), _widest(b) if b.size() > 1 else 0.0, _cone_m()])
	return "\n".join(lines)


func _frame() -> void:
	var y: float = _centre.y
	var wide_eye := Vector3(_centre.x - WIDE_BACK, y + 0.5, SITE.z + 14.0)
	var wide_look := Vector3(_wall_x, y, SITE.z)
	var close_a_eye := Vector3(_centre.x - CLOSE_BACK, y + 0.3, SITE.z - SIDE_M + 2.5)
	var close_a_look := Vector3(_wall_x, y, SITE.z - SIDE_M)
	var close_b_eye := Vector3(_centre.x - CLOSE_BACK, y + 0.3, SITE.z + SIDE_M + 2.5)
	var close_b_look := Vector3(_wall_x, y, SITE.z + SIDE_M)
	var eye: Vector3 = wide_eye
	var look: Vector3 = wide_look
	if _clock >= TO_B_AT:
		var k: float = _ease((_clock - TO_B_AT) / PUSH_S)
		eye = close_a_eye.lerp(close_b_eye, k)
		look = close_a_look.lerp(close_b_look, k)
	elif _clock >= PUSH_AT:
		var k: float = _ease((_clock - PUSH_AT) / PUSH_S)
		eye = wide_eye.lerp(close_a_eye, k)
		look = wide_look.lerp(close_a_look, k)
	_observer.look_from(eye, look)


func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


func _build_captions() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	for strip in [Rect2(0.0, 0.0, 1600.0, 100.0), Rect2(0.0, 776.0, 1600.0, 102.0)]:
		var back := ColorRect.new()
		back.color = Color(0.0, 0.0, 0.0, 0.93)
		back.position = (strip as Rect2).position
		back.size = (strip as Rect2).size
		layer.add_child(back)
	_caption = Label.new()
	_caption.position = Vector2(16.0, 14.0)
	_caption.add_theme_font_size_override("font_size", 26)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 8)
	layer.add_child(_caption)
	_small = Label.new()
	_small.position = Vector2(16.0, 782.0)
	_small.add_theme_font_size_override("font_size", 20)
	_small.add_theme_color_override("font_outline_color", Color.BLACK)
	_small.add_theme_constant_override("outline_size", 6)
	layer.add_child(_small)


func _end() -> void:
	var a: Array = _hits[0]
	var b: Array = _hits[1]
	var cone: float = _cone_m()
	var wa: float = _widest(a) if a.size() > 1 else 0.0
	var wb: float = _widest(b) if b.size() > 1 else 0.0
	print("[splay_reel] range %.1f m, cone radius %.2f m; A %d rounds widest %.3f m; B %d rounds widest %.3f m"
		% [_centre.x - _from_x, cone, a.size(), wa, b.size(), wb])
	_check("dead_true_gun_lands_on_one_point", a.size() >= 30 and wa < 0.05, "%d rounds, widest %.3f m" % [a.size(), wa])
	_check("scattered_gun_is_spread", b.size() >= 30 and wb > cone * 0.6, "%d rounds, widest %.2f m of %.2f" % [b.size(), wb, cone])
	_check("and_inside_the_cone", wb <= cone * 1.15, "widest %.2f m, cone %.2f m" % [wb, cone])
	_finish()


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
