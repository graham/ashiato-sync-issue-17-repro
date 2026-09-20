extends Node3D
class_name TraceLevel
## THE TRACE LEVEL: ONE CRAFT POSED FROM A FLIGHT TRACE, ITS PATH DRAWN IN THE AIR, AND ITS INPUTS BESIDE IT.
##
##   Godot --path cockpit -- --world=trace --trace-in=C:/temp/traces/cessna_4294967349.jsonl [--trace-at=12] [--trace-rate=2]
##
## Asked for on 2026-09-19, minutes after the recorder: "we should have a special level that can read this input back in to
## a single craft in a small map and redraw it's flight". `CraftTrace` writes the file; this reads it back. The point of
## the level is to WATCH A STICK AGAINST THE AEROPLANE THAT IT MOVES: the strip along the bottom of the screen is the
## last eight seconds of the recorded inputs and the next two, the marker at four-fifths across is now, and the craft
## in the middle is where the file says it was.
##
## THE CRAFT IS A PUPPET, NOT A SIMULATION. Nothing here flies: each frame the level finds the two samples either side of
## the playback time, interpolates between them (position linearly, attitude by slerp) and hands the pose to the ordinary
## drawing, which draws any craft it is told is there. The flight you see is the flight that was flown, so it cannot
## diverge the way a re-simulation from the same inputs would, and a bug in the flight model cannot hide in it. The
## puppet is drawn through `Sim.current` under an entity number no simulated craft can have (`PUPPET`), written before
## `Sky` draws (`process_priority`), and the banner, and a label over the craft, say so. What is NOT posed from the file: the
## drawn control surfaces, gear and flaps, which the drawing reads off the craft's bus and a puppet has none.
##
## THE PATH is drawn twice, cheaply, both from one decimated list (at most `PATH_POINTS_MOST` points, all of a short
## flight): a line strip through every point, and a vertical curtain from it down to the ground plane, translucent, which is
## what makes a path readable from the side and from a distance where a one-pixel line is not. Every `mark_every` seconds
## (1, 2, 5, 10, 30 or 60: the least that gives no more than 120 marks) a cross stands on the path and a drop-line falls from it
## to the ground, so height and pace can be read off. A mark is a real sample time, not a point picked from the strip.
## The map is small on purpose (the ground's smallest legal world, gently rolling); the flight is RECENTRED on it, its
## middle put over the map's, and one wider than the map is said so in words and drawn anyway, since a puppet never
## touches the ground.
##
## A FILE THAT CANNOT BE READ IS REFUSED IN WORDS, on the screen and on stdout: no file named, missing, not JSON lines, no
## header, a kind nobody knows, fewer than two samples, a sample without a position or a time that goes backward, each with
## its line. The level still comes up with a message and nothing to play; it never crashes. The one exception is a last
## line cut short, which a killed run leaves and which is dropped and said.
##
## KEYS: SPACE play/pause · , and . slower and faster (0.25x to 16x) · LEFT and RIGHT 5 s back and on (SHIFT 30 s) ·
## HOME and END · 0 to 9 jump to that tenth of the flight · a click on the timeline · C chase or free camera · right mouse
## drag orbits (or looks, when free), the wheel zooms, WASD and Q/E fly a free camera (SHIFT faster).
## `--trace-at=<seconds>` starts there, `--trace-rate=<n>` at that speed, `--trace-play=0` paused.

const LEVEL_ID: String = "trace"
## The entity the puppet is drawn as. Real entities carry a generation in their high word (4294967341...), so no
## simulated craft has a number under 2^32.
const PUPPET: int = 0x7E000001
const PATH_POINTS_MOST: int = 6000
const MARKS_MOST: int = 120
const MARK_EVERY: Array[float] = [1.0, 2.0, 5.0, 10.0, 30.0, 60.0]
const RATES: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0]
## The strip's window: seconds shown behind now and ahead of it.
const STRIP_BEHIND: float = 8.0
const STRIP_AHEAD: float = 2.0
const PATH_COLOUR := Color(1.0, 0.72, 0.15)
const CURTAIN_COLOUR := Color(1.0, 0.72, 0.15, 0.10)
const MARK_COLOUR := Color(0.35, 0.95, 1.0)
## The map's own width, from `levels/trace/level.json`: `world_half` 8192 either way. A flight wider than this is said so.
const MAP_WIDE: float = 15000.0

## The chart being played, and the last thing said about the file ("" when it read).
var chart: LevelChart = null
var refusal: String = ""
var header: Dictionary = {}
var kind: int = 0
var path_asked: String = ""

var times: PackedFloat64Array = PackedFloat64Array()
## Position of every sample after the recentring, and the attitude of every sample.
var points: PackedVector3Array = PackedVector3Array()
var quats: Array[Quaternion] = []
var rows: Array = []
## Where the flight's middle was in the file (x, z), which the recentring took off every position.
var centre: Vector2 = Vector2.ZERO
var wider_than_map: bool = false
var mark_every: float = 0.0
var mark_count: int = 0
var path_vertex_count: int = 0

## THE PLAYBACK CLOCK, seconds into the file's own clock (its first sample is 0 whatever the recorder's tick was).
var clock: float = 0.0
var rate: float = 1.0
var playing: bool = true

var camera: Camera3D = null
var panel: TracePanel = null
var _label: Label3D = null
var _sky: Node = null
var _free: bool = false
var _azimuth: float = 0.6
var _elevation: float = 0.4
var _distance: float = 30.0
var _yaw: float = 0.0
var _pitch: float = -0.2
var _path: MeshInstance3D = null


static func claims(level: LevelChart) -> bool:
	return level != null and level.id == LEVEL_ID


## A trace path a suite hands the level instead of the command line's, or "": the level reads `--trace-in=` only then.
static var forced_path: String = ""


## `--trace-in=<file>`, or "".
static func asked(args: PackedStringArray = OS.get_cmdline_user_args()) -> String:
	if not forced_path.is_empty():
		return forced_path
	for argument in args:
		if argument.begins_with("--trace-in="):
			return argument.substr("--trace-in=".length())
	return ""


static func _asked_number(name: String, fallback: float) -> float:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--%s=" % name):
			var text: String = argument.get_slice("=", 1)
			return float(text) if text.is_valid_float() else fallback
	return fallback


## One line of JSON, or null when it is not. `JSON.parse_string` prints an engine ERROR for a bad line, and a killed run's cut-short
## last line is expected here, so the harness (which fails a run on any engine error) would read a normal file as a fault.
static func _parse(text: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(text) == OK else null


## A TRACE FILE READ AND CHECKED: {"error": "", "header", "rows"} or {"error": <in words>}. Rows are the parsed sample
## lines. A cut-short LAST line (a killed run) is dropped and counted in "dropped"; a bad line anywhere else refuses.
static func read(path: String) -> Dictionary:
	if path.is_empty():
		return {"error": "no trace was named: start with -- --trace-in=<file.jsonl>"}
	if not FileAccess.file_exists(path):
		return {"error": "%s does not exist" % path}
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n", false)
	if lines.is_empty():
		return {"error": "%s is empty" % path}
	var head: Variant = _parse(lines[0])
	if not (head is Dictionary) or int((head as Dictionary).get("trace", 0)) != 1:
		return {"error": "%s line 1 is not a trace header ({\"trace\": 1, ...}): is it a .jsonl from CraftTrace?" % path}
	var kind_name: String = String((head as Dictionary).get("kind", ""))
	if not Sim.Kind.keys().has(kind_name.to_upper()):
		return {"error": "%s names a craft kind '%s' this build does not have" % [path, kind_name]}
	var out_rows: Array = []
	var dropped: int = 0
	var last_time: float = -INF
	for i in range(1, lines.size()):
		var row: Variant = _parse(lines[i])
		if not (row is Dictionary):
			if i == lines.size() - 1:
				dropped += 1
				continue
			return {"error": "%s line %d is not JSON" % [path, i + 1]}
		var sample: Dictionary = row
		var where: Variant = sample.get("pos")
		var attitude: Variant = sample.get("quat")
		if not (where is Array) or (where as Array).size() != 3 or not (attitude is Array) or (attitude as Array).size() != 4 \
				or not sample.has("t"):
			return {"error": "%s line %d has no time, position or attitude" % [path, i + 1]}
		var when: float = float(sample["t"])
		if when <= last_time:
			return {"error": "%s line %d goes back in time (%.3f after %.3f)" % [path, i + 1, when, last_time]}
		last_time = when
		out_rows.append(sample)
	if out_rows.size() < 2:
		return {"error": "%s has %d samples: a flight needs at least two" % [path, out_rows.size()]}
	return {"error": "", "header": head, "rows": out_rows, "dropped": dropped}


## THE LEVEL COMES UP, with a trace or without one. Called by `Sky` once the ground stands.
func stand_in(level: LevelChart, sky: Node) -> void:
	chart = level
	_sky = sky
	process_priority = -100
	path_asked = asked()
	_build_the_camera()
	_build_the_panel()
	var got: Dictionary = read(path_asked)
	refusal = String(got["error"])
	if not refusal.is_empty():
		print("[trace] %s" % refusal)
		if not path_asked.is_empty():
			push_warning("[trace] " + refusal)
		panel.queue_redraw()
		return
	load_flight(got["header"], got["rows"])
	if int(got["dropped"]) > 0:
		print("[trace] the last line was cut short (a killed run) and was dropped")
	clock = clampf(_asked_number("trace-at", 0.0), 0.0, duration())
	rate = _asked_number("trace-rate", 1.0)
	playing = _asked_number("trace-play", 1.0) != 0.0
	print("[trace] %s: %s, %d samples, %.1f s, path %d vertices, a mark every %.0f s%s" % [path_asked.get_file(),
		Sim.kind_name(kind), rows.size(), duration(), path_vertex_count, mark_every,
		"; WIDER THAN THE MAP (%.0f m)" % _extent() if wider_than_map else ""])


## THE FLIGHT, from parsed rows: recentred, drawn, ready to play. Separate from `stand_in` so a suite can hand it rows.
func load_flight(head: Dictionary, sample_rows: Array) -> void:
	header = head
	rows = sample_rows
	kind = Sim.Kind.keys().find(String(head["kind"]).to_upper())
	var first: float = float((rows[0] as Dictionary)["t"])
	times = PackedFloat64Array()
	points = PackedVector3Array()
	quats = []
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for sample in rows:
		var p: Array = sample["pos"]
		low = Vector2(minf(low.x, float(p[0])), minf(low.y, float(p[2])))
		high = Vector2(maxf(high.x, float(p[0])), maxf(high.y, float(p[2])))
	centre = (low + high) * 0.5
	wider_than_map = maxf(high.x - low.x, high.y - low.y) > MAP_WIDE
	for sample in rows:
		var p: Array = sample["pos"]
		var q: Array = sample["quat"]
		times.append(float(sample["t"]) - first)
		points.append(Vector3(float(p[0]) - centre.x, float(p[1]), float(p[2]) - centre.y))
		quats.append(Quaternion(float(q[0]), float(q[1]), float(q[2]), float(q[3])).normalized())
	_distance = maxf(60.0, (Sim.geometry_of(kind).get("extents", Vector3.ONE * 4.0) as Vector3).z * 12.0)
	_draw_the_path()
	if _label != null:
		_label.text = "TRACE PUPPET (posed from %s, not flown)" % path_asked.get_file()
	panel.queue_redraw()


func _extent() -> float:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for p in points:
		low = Vector2(minf(low.x, p.x), minf(low.y, p.z))
		high = Vector2(maxf(high.x, p.x), maxf(high.y, p.z))
	return maxf(high.x - low.x, high.y - low.y)


func has_flight() -> bool:
	return not times.is_empty()


func duration() -> float:
	return times[times.size() - 1] if not times.is_empty() else 0.0


## ---- WHERE THE FILE SAYS IT WAS -------------------------------------------------------------------------------------

## The index of the last sample at or before `t`.
func index_at(t: float) -> int:
	if times.is_empty():
		return -1
	var low: int = 0
	var high: int = times.size() - 1
	while low < high:
		var middle: int = low + ((high - low + 1) >> 1)
		if times[middle] <= t:
			low = middle
		else:
			high = middle - 1
	return low


## THE POSE AT `t`, interpolated between the two samples either side: position linear, attitude by slerp. In map
## coordinates (the flight recentred); `Transform3D.IDENTITY` before a flight is loaded.
func pose_at(t: float) -> Transform3D:
	if times.is_empty():
		return Transform3D.IDENTITY
	t = clampf(t, 0.0, duration())
	var i: int = index_at(t)
	var j: int = mini(i + 1, times.size() - 1)
	var span: float = times[j] - times[i]
	var alpha: float = clampf((t - times[i]) / span, 0.0, 1.0) if span > 0.0 else 0.0
	return Transform3D(Basis(quats[i].slerp(quats[j], alpha)), points[i].lerp(points[j], alpha))


## The sample row at or before `t`.
func row_at(t: float) -> Dictionary:
	var i: int = index_at(clampf(t, 0.0, duration()))
	return rows[i] if i >= 0 else {}


func seek(t: float) -> void:
	clock = clampf(t, 0.0, duration())
	if panel != null:
		panel.queue_redraw()


## Where the puppet is drawn NOW, as the drawing has it (after `Sky` has drawn), or the identity when it is not.
func drawn_pose() -> Transform3D:
	var view: Node3D = _sky.view_of(PUPPET) if _sky != null and _sky.has_method("view_of") else null
	return view.global_transform if view != null else Transform3D.IDENTITY


## ---- THE PATH -------------------------------------------------------------------------------------------------------

func _draw_the_path() -> void:
	if _path != null:
		_path.queue_free()
	var stride: int = maxi(1, int(ceil(float(points.size()) / float(PATH_POINTS_MOST))))
	var line := PackedVector3Array()
	var curtain := PackedVector3Array()
	var last: int = points.size() - 1
	var i: int = 0
	var previous: Vector3 = points[0]
	while i <= last:
		var at: Vector3 = points[i]
		if i > 0:
			line.append(previous)
			line.append(at)
			curtain.append_array(PackedVector3Array([previous, at, Vector3(at.x, 0.0, at.z),
				previous, Vector3(at.x, 0.0, at.z), Vector3(previous.x, 0.0, previous.z)]))
		previous = at
		if i == last:
			break
		i = mini(i + stride, last)
	path_vertex_count = (line.size() >> 1) + 1
	# THE MARKS: the least interval that gives no more than MARKS_MOST of them, drawn at real sample times.
	mark_every = MARK_EVERY[MARK_EVERY.size() - 1]
	for every in MARK_EVERY:
		if duration() / every <= float(MARKS_MOST):
			mark_every = every
			break
	var marks := PackedVector3Array()
	var size: float = clampf(_extent() * 0.0015, 4.0, 25.0)
	mark_count = 0
	var when: float = 0.0
	while when <= duration() + 0.0001:
		var at: Vector3 = pose_at(when).origin
		marks.append_array(PackedVector3Array([at - Vector3(size, 0.0, 0.0), at + Vector3(size, 0.0, 0.0),
			at - Vector3(0.0, size, 0.0), at + Vector3(0.0, size, 0.0),
			at - Vector3(0.0, 0.0, size), at + Vector3(0.0, 0.0, size), at, Vector3(at.x, 0.0, at.z)]))
		mark_count += 1
		when += mark_every
	var mesh := ArrayMesh.new()
	_add_surface(mesh, line, Mesh.PRIMITIVE_LINES, PATH_COLOUR, false)
	_add_surface(mesh, marks, Mesh.PRIMITIVE_LINES, MARK_COLOUR, false)
	_add_surface(mesh, curtain, Mesh.PRIMITIVE_TRIANGLES, CURTAIN_COLOUR, true)
	_path = MeshInstance3D.new()
	_path.name = "Path"
	_path.mesh = mesh
	_path.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_path.extra_cull_margin = 16384.0
	add_child(_path)


func _add_surface(mesh: ArrayMesh, vertices: PackedVector3Array, primitive: int, colour: Color, translucent: bool) -> void:
	if vertices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(primitive, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	material.disable_fog = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if translucent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


## ---- EVERY FRAME ----------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not has_flight():
		_follow_nothing(delta)
		return
	if playing:
		clock += delta * rate
		if clock >= duration():
			clock = duration()
			playing = false
	_pose_the_puppet()
	_move_the_camera(delta)
	_park_the_observer()
	if panel != null:
		panel.queue_redraw()


## THE PUPPET, into the state the drawing reads, the same both ticks so no interpolation moves it off the file.
func _pose_the_puppet() -> void:
	var pose: Transform3D = pose_at(clock)
	var row: Dictionary = row_at(clock)
	var vel: Array = row.get("vel", [0.0, 0.0, 0.0])
	var state: Dictionary = {"entity": PUPPET, "kind": kind, "position": pose.origin, "basis": pose.basis.get_rotation_quaternion(),
		"velocity": Vector3(float(vel[0]), float(vel[1]), float(vel[2])), "spin": Vector3.ZERO, "turret": Vector2.ZERO,
		"turrets": [], "route": Vector3.ZERO, "has_route": false, "predicted": false, "corrected": false}
	Sim.current[PUPPET] = state
	Sim.previous[PUPPET] = state
	if _label != null:
		_label.global_position = pose.origin + Vector3.UP * (_distance * 0.35)


## `Sky` reads the observer's place as the eye when there is no rig, so the level's own camera lends it.
func _park_the_observer() -> void:
	var observer: Node3D = _sky.get("observer") if _sky != null else null
	if observer != null and camera != null:
		observer.global_position = camera.global_position


func _move_the_camera(delta: float) -> void:
	if _free:
		var wish := Vector3.ZERO
		wish.x = (1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0)
		wish.z = (1.0 if Input.is_key_pressed(KEY_S) else 0.0) - (1.0 if Input.is_key_pressed(KEY_W) else 0.0)
		wish.y = (1.0 if Input.is_key_pressed(KEY_E) else 0.0) - (1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
		if wish.length_squared() > 0.0:
			camera.global_position += camera.global_transform.basis * wish.normalized() * _distance * (
				8.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0) * delta
		camera.rotation = Vector3(_pitch, _yaw, 0.0)
		return
	var pose: Transform3D = pose_at(clock)
	var forward: Vector3 = -pose.basis.z
	var heading: float = atan2(-forward.x, -forward.z)
	var a: float = heading + _azimuth
	var offset := Vector3(sin(a) * cos(_elevation), sin(_elevation), cos(a) * cos(_elevation)) * _distance
	camera.global_position = pose.origin + offset
	camera.look_at(pose.origin, Vector3.UP)
	_yaw = camera.rotation.y
	_pitch = camera.rotation.x


func _follow_nothing(_delta: float) -> void:
	_park_the_observer()


func _build_the_camera() -> void:
	camera = Camera3D.new()
	camera.name = "TraceCamera"
	camera.near = 0.5
	camera.far = 30000.0
	camera.position = Vector3(0.0, 300.0, 600.0)
	add_child(camera)
	camera.current = true
	_label = Label3D.new()
	_label.name = "PuppetLabel"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0007
	_label.modulate = Color(1.0, 0.85, 0.3)
	_label.outline_size = 8
	add_child(_label)
	# The observer `Sky` made for a level with nobody in it stops looking and flying: this level's camera is the eye.
	var observer: Camera3D = _sky.get("observer") if _sky != null else null
	if observer != null:
		observer.current = false
		observer.set_process(false)
		observer.set_process_unhandled_input(false)
		for child in observer.get_children():
			if child is CanvasLayer:
				child.visible = false


func _build_the_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TracePanelLayer"
	add_child(layer)
	panel = TracePanel.new()
	panel.name = "TracePanel"
	# `set` and not an assignment: `tests/lint.gd` compiles a script with its class_name struck out, and a typed assignment
	# of `self` to a variable of its own class then fails to compile.
	panel.set(&"level", self)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(panel)


## ---- KEYS ----------------------------------------------------------------------------------------------------------

func faster(by: int) -> void:
	var at: int = RATES.find(rate)
	if at < 0:
		at = RATES.find(1.0)
	rate = RATES[clampi(at + by, 0, RATES.size() - 1)]


func toggle_play() -> void:
	if not playing and clock >= duration():
		clock = 0.0
	playing = not playing


func _unhandled_input(event: InputEvent) -> void:
	if not has_flight():
		return
	var motion := event as InputEventMouseMotion
	if motion != null and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if _free:
			_yaw -= motion.relative.x * 0.0022
			_pitch = clampf(_pitch - motion.relative.y * 0.0022, deg_to_rad(-89.0), deg_to_rad(89.0))
		else:
			_azimuth -= motion.relative.x * 0.005
			_elevation = clampf(_elevation + motion.relative.y * 0.005, deg_to_rad(-80.0), deg_to_rad(85.0))
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(3.0, _distance * 0.88)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(20000.0, _distance / 0.88)
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var step: float = 30.0 if key.shift_pressed else 5.0
	match key.physical_keycode:
		KEY_SPACE: toggle_play()
		KEY_COMMA: faster(-1)
		KEY_PERIOD: faster(1)
		KEY_LEFT: seek(clock - step)
		KEY_RIGHT: seek(clock + step)
		KEY_HOME: seek(0.0)
		KEY_END: seek(duration())
		KEY_C: _free = not _free
		_:
			if key.physical_keycode >= KEY_0 and key.physical_keycode <= KEY_9:
				seek(duration() * float(key.physical_keycode - KEY_0) / 10.0)


## THE TIMELINE'S BAR was clicked at this fraction of its width.
func seek_fraction(fraction: float) -> void:
	seek(duration() * clampf(fraction, 0.0, 1.0))


## What the panel needs to draw the strip: the channels this file has, each {label, key path, low, high}.
func strip_channels() -> Array[Dictionary]:
	if String(header.get("stick", "absent")) == "flight_controls":
		return [
			{"label": "stick pitch", "group": "stick", "key": "pitch", "low": -1.0, "high": 1.0},
			{"label": "stick roll", "group": "stick", "key": "roll", "low": -1.0, "high": 1.0},
			{"label": "rudder", "group": "stick", "key": "rudder", "low": -1.0, "high": 1.0},
			{"label": "throttle", "group": "stick", "key": "throttle", "low": 0.0, "high": 1.0},
		]
	# WITHOUT THE STICK, each lane is scaled to what the whole file did on that channel (at least a degree or a tenth wide), so a
	# small hunt is a visible comb and not a flat line on a lane sized for a loop.
	var lanes: Array[Dictionary] = [
		{"label": "pitch (deg)", "group": "euler", "key": "pitch"},
		{"label": "roll (deg)", "group": "euler", "key": "roll"},
		{"label": "throttle lever", "group": "levers", "key": "throttle"},
	]
	for lane in lanes:
		var low: float = INF
		var high: float = -INF
		for row in rows:
			var group: Dictionary = row.get(String(lane["group"]), {})
			if group.has(lane["key"]):
				low = minf(low, float(group[lane["key"]]))
				high = maxf(high, float(group[lane["key"]]))
		var least: float = 0.1 if lane["group"] == "levers" else 1.0
		if high - low < least:
			var middle: float = (high + low) * 0.5 if high >= low else 0.0
			low = middle - least * 0.5
			high = middle + least * 0.5
		lane["low"] = low
		lane["high"] = high
	return lanes
