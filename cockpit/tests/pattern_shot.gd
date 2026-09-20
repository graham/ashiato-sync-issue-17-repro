extends Node
## AIRPORT LIFE, LOOKED AT: aeroplanes flying the south shore strip's traffic pattern on the real island, straight down,
## with the pattern's legs drawn on the ground, each aeroplane's track as a coloured line, and its leg and height
## written beside it.
##
##   Godot --path cockpit --resolution 1600x900 --xr-mode off res://tests/pattern_shot.tscn -- --level=watch
##       [--kind=p51 with --scene=trip]
##       --clouds=none --scene=one|two --out=C:/somewhere [--speed=8 with --write-movie x.avi --fixed-fps 4]
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (seeing_the_game.md). Whether an arrival
## flies the pattern and lands is held by tests/traffic_pattern.gd; this is for eyes, and for the user's proof.
## NEVER A CAPTURE OF THE DESKTOP: the picture is the viewport's own image, and the video is MovieWriter's.
##
## `--scene=one`: one Cessna arriving from over the sea on the pattern side, flying the 45-degree entry, the circuit
## and the landing. `--scene=two`: two Cessnas arriving at once, sequenced. `--scene=trip`: one Cessna parked on the
## island air base's apron taxis out, takes off from the island strip, departs, flies over the mountains to the south
## shore strip and lands there -- seen from behind it, a chase camera, not from above. `--kind=` flies another kind:
## `--kind=p51` is the taildragger's take-off, circuit and landing (lane/warbirds2). `--scene=mixed`: the user's
## "large planes use something more similar to a IFR approach" beside a light one's pattern -- the airliner flying the
## instrument approach to runway 09 from 11 NM out, and a Cessna flying 09's right-hand pattern over the sea, seen from
## straight down over twice the ground, both to a stop. `--speed=N` is only what the banner says:
## a timelapse is `--write-movie` at `--fixed-fps` 30 / N, played back at 30 (see `_ready`).
##
## Pictures in `--out`: `pattern-<scene>-final.png` once every aeroplane has stopped, or at `--seconds`.

## How much ground the top-down view shows across its height, metres: the circuit and its entry, with room round it.
const TOP_METRES: float = 7000.0
## The colours of the tracks, in the order the aeroplanes were put in the air.
const TRACK_COLOURS: Array[Color] = [Color(1.0, 0.25, 0.2), Color(0.2, 0.75, 1.0), Color(1.0, 0.85, 0.2)]
## The legs drawn on the ground, and how high over it, metres.
const LEG_COLOUR := Color(1.0, 1.0, 1.0, 0.8)
const DRAWN_UP: float = 3.0
## A track point every this many physics ticks.
const TRACK_EVERY: int = 30
## HOW WIDE A DRAWN LINE IS, in pixels of the picture: a line one pixel wide is lost in a video. Worked out in metres from
## the view's scale, so a wider view keeps the same lines.
const LINE_PIXELS: float = 3.5
const RUNWAY_COLOUR := Color(1.0, 0.9, 0.3)
## The instrument final and its fix.
const IFR_COLOUR := Color(0.55, 1.0, 0.55, 0.9)
## Each aeroplane's marker: a disc this many pixels across, where an 11 m Cessna would be a pixel and a half.
const MARKER_PIXELS: float = 14.0

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://pattern_shot"
var _scene: String = "one"
var _speed: float = 1.0
## The runway end both scenes land on ("" for the one in use), and how much ground the view shows across its height.
var _end: String = ""
## WHO FLIES THE TRIP: the Cessna unless `--kind=` names another (the arrivals are always the Cessna and the airliner).
var _kind: int = Sim.Kind.CESSNA
var _view_metres: float = TOP_METRES
## How far out on the extended centreline BLUE starts its straight-in, metres (`--blue-out=`).
var _blue_out: float = 9500.0
var _seconds: float = 900.0
var _traffic: AirportTraffic = null
var _field: Dictionary = {}
var _planes: Array[int] = []
var _tracks: Array = []
var _lines: Array[ImmediateMesh] = []
var _labels: Array[Label3D] = []
var _markers: Array[MeshInstance3D] = []
var _banner: Label = null
var _tick: int = 0
## The closest any two of them came while both were in the air, metres.
var _closest: float = INF


func _check(label: String, ok: bool, detail: String) -> void:
	print("[pattern_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--scene="):
			_scene = argument.trim_prefix("--scene=")
		elif argument.begins_with("--speed="):
			_speed = argument.trim_prefix("--speed=").to_float()
		elif argument.begins_with("--blue-out="):
			_blue_out = argument.trim_prefix("--blue-out=").to_float()
		elif argument.begins_with("--seconds="):
			_seconds = argument.trim_prefix("--seconds=").to_float()
		elif argument.begins_with("--kind="):
			# THE KIND THAT FLIES IT, for `--scene=trip`: `--kind=p51` chases a Mustang instead of the Cessna
			# (lane/warbirds2). `TuningCard` reads the same flag, and uses it only with `--set=`.
			for k in Sim.Kind.values():
				if Sim.kind_name(k) == argument.trim_prefix("--kind="):
					_kind = k
	# `--no-picture`: the same flights headless, as fast as the machine goes, for setting a scene's timing up.
	var pictures: bool = not OS.get_cmdline_user_args().has("--no-picture")
	if pictures and DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed, or pass --no-picture")
		_finish()
		return
	if _scene == "mixed":
		# RUNWAY 09, NOT 27: an instrument final into 27 would begin 20 km east of the island's middle, past the world's
		# soft edge (17.3 km, WorldEdge); 09's lies along the flat southern band from the west.
		_end = "far_end"
		_view_metres = 14000.0
	DirAccess.make_dir_recursive_absolute(_out)
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	await _frames(60)
	var words := _level.get_node_or_null("Ui") as CanvasLayer
	if words != null:
		words.visible = false
	# AND THE OBSERVER'S OWN BOARD ("WATCHING 90 vehicles"), which is for a person at the keys.
	for board in _level.observer.find_children("*", "CanvasItem", true, false):
		(board as CanvasItem).visible = false
	# `--set=surfaces=0 --kind=cessna` (`TuningCard`): the same circuit on the lumped wing, for a before and after
	# (lane/cessnafm).
	var card := TuningCard.from_command_line()
	if not card.is_empty():
		print("[pattern_shot] %s" % card.clip_on())
	_field = Airfield.named("south_shore")
	_check("the_south_shore_strip_is_on_this_world", not _field.is_empty(), "%d airfields" % Airfield.here().size())
	if _field.is_empty() or Sim.server == null:
		_finish()
		return
	_traffic = AirportTraffic.new()
	_traffic.recording = true
	add_child(_traffic)
	if _scene == "trip":
		_put_up_the_trip()
	else:
		_put_up_the_arrivals()
	_draw_the_pattern()
	if _scene != "trip":
		_look_down()
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 26)
	_banner.add_theme_color_override("font_color", Color.WHITE)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.position = Vector2(24, 18)
	var layer := CanvasLayer.new()
	layer.add_child(_banner)
	add_child(layer)
	# A TIMELAPSE IS MOVIEWRITER AT A LOW FRAME RATE PLAYED BACK AT 30: `--fixed-fps 4` is thirty physics ticks a frame,
	# so the frame loop must be allowed that many. `Engine.time_scale` does not do it: at 8 the world still ran 203
	# simulated seconds in 203 (2026-09-19).
	Engine.max_physics_steps_per_frame = 64
	var started: float = Time.get_ticks_msec()
	while true:
		await get_tree().physics_frame
		_tick += 1
		if _tick % TRACK_EVERY == 0:
			_follow_the_planes()
		if _scene == "trip":
			_chase()
		var all_down := true
		for entity in _planes:
			var me: Dictionary = _traffic.record_of(entity)
			var done: Array[StringName] = [&"stopped"]
			if me.is_empty() or not done.has(me["phase"]) or String(me["field"]) != String(_field["id"]):
				all_down = false
		# AND STOP IF ONE IS LOST: a crash takes the aeroplane out of the traffic, and nothing will ever land.
		var lost: bool = false
		for entity in _planes:
			if _traffic.record_of(entity).is_empty() or bool(Sim.server.hull_state(entity).get("destroyed", false)):
				lost = true
		if all_down or lost or float(_tick) / 120.0 > _seconds:
			break
	_follow_the_planes()
	await _frames(20)
	if pictures:
		_save("pattern-%s-final" % _scene)
	for entity in _planes:
		var me: Dictionary = _traffic.record_of(entity)
		print("[pattern_shot] %d: legs %s, go-arounds %d, turned away %d, extended %.0f m, touched at tick %d, landed %s" % [
			entity, str(me.get("legs", [])), int(me.get("go_arounds", 0)), int(me.get("turned_away", 0)),
			float(me.get("extended", 0.0)), int((me.get("began", {}) as Dictionary).get(&"rollout", -1)),
			str(me.get("landed", {}))])
		for gate in me.get("gates", []):
			print("[pattern_shot] %d: gate at tick %d, %s" % [entity, int(gate["tick"]), str(gate.get("went_around", "on"))])
		var landed: bool = not me.is_empty() and me["phase"] == &"stopped"
		_check("aeroplane_%d_landed" % entity, landed, str(me.get("phase", "")))
	print("[pattern_shot] closest in the air %.0f m" % _closest)
	_write_the_tracks()
	print("[pattern_shot] %.0f simulated seconds in %.0f s" % [float(_tick) / 120.0, (Time.get_ticks_msec() - started) / 1000.0])
	_finish()


## THE TRIP: a Cessna on the island air base's apron, sent from the island strip -- taking off southbound from its far
## end, toward the shore -- to the south shore strip.
func _put_up_the_trip() -> void:
	var from: Dictionary = Airfield.named("island_strip")
	var base: Dictionary = AirbasePlan.on_runway(int(from.get("index", 0)))
	var spot: Dictionary = {}
	for id in base.get("spots", {}):
		if String(id).begins_with("apron") and AirbasePlan.fits(base["spots"][id], _kind):
			spot = base["spots"][id]
			break
	_check("there_is_an_apron_spot_it_fits_at_the_island_strip", not spot.is_empty(),
		str((base.get("spots", {}) as Dictionary).keys()))
	if spot.is_empty():
		return
	var extents: Vector3 = Sim.geometry_of(_kind).get("extents", Vector3.ONE)
	var parked_at: Vector3 = AirbasePlan.standing_on_spot(base, spot, _kind) + Vector3.UP * (extents.y + 0.3)
	var entity: int = Sim.spawn_ai_vehicle(_kind, parked_at, float(spot["yaw"]), Vector3.ZERO)
	_check("it_is_parked_on_the_apron", entity != 0, str(parked_at))
	if entity == 0:
		return
	_traffic.depart(entity, from, _kind, String(spot["id"]), "far_end", _field)
	_add_plane(entity, 0)
	var camera: Camera3D = _level.observer
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 62.0
	camera.far = 24000.0
	_chase_at = parked_at + Vector3(0.0, CHASE_UP, 0.0) - Terrain.nose_from_yaw(float(spot["yaw"])) * CHASE_BACK


## THE CHASE CAMERA, behind and above the aeroplane along its track (along its nose while it is too slow to have one),
## eased toward that place so a turn swings the view rather than jerking it.
const CHASE_BACK: float = 70.0
const CHASE_UP: float = 22.0
const CHASE_EASE: float = 0.04
var _chase_at := Vector3.ZERO


func _chase() -> void:
	if _planes.is_empty():
		return
	var state: Dictionary = Sim.server.vehicle_state(_planes[0])
	if state.is_empty():
		return
	var at: Vector3 = state["position"]
	var v: Vector3 = state["velocity"]
	var going := Vector3(v.x, 0.0, v.z)
	if going.length() < 3.0:
		going = (Basis(state["basis"] as Quaternion) * Vector3.FORWARD) * Vector3(1.0, 0.0, 1.0)
	var want: Vector3 = at - going.normalized() * CHASE_BACK + Vector3.UP * CHASE_UP
	_chase_at = _chase_at.lerp(want, CHASE_EASE)
	_level.observer.look_from(_chase_at, at + Vector3.UP * 2.0)


## THE ARRIVALS, over the sea on the pattern side so the entry is the 45: one, or two a few kilometres apart and a
## little apart in time, so the second meets the first in the circuit.
func _put_up_the_arrivals() -> void:
	var p: TrafficPattern = Airfield.pattern_for(_field, Sim.Kind.CESSNA, _end, AirportTraffic.turn_expected(Sim.Kind.CESSNA))
	# RED over the sea on the pattern side, making for the 45; with `--scene=two`, BLUE lined up with the runway 9 km out
	# beyond its threshold, flying a straight-in that reaches the runway at about the same time.
	var starts: Array[Vector3] = [p.point(p.length * 0.5 + 3500.0, p.offset + 3000.0)]
	var goings: Array[Vector3] = [p.abeam_midfield() - starts[0]]
	var kinds: Array[int] = [Sim.Kind.CESSNA]
	if _scene == "two":
		starts.append(p.point(-_blue_out, 0.0))
		goings.append(p.along)
		kinds.append(Sim.Kind.CESSNA)
	elif _scene == "mixed":
		# BLUE: THE AIRLINER 11 NM OUT ON THE EXTENDED CENTRELINE, flying in: a straight-in, established far out. Not the
		# Hawkeye: it cannot slow to its final speed on a 3-degree path at idle with nothing lowered, reached the gate at
		# 76 m/s against 64.8 and went around (2026-09-19), before the autopilot's landing configuration.
		starts.append(p.point(-_blue_out, 0.0))
		goings.append(p.along)
		kinds.append(Sim.Kind.AIRLINER)
	for i in range(starts.size()):
		var height: float = p.height if kinds[i] == Sim.Kind.CESSNA else 600.0
		var at: Vector3 = starts[i] + Vector3.UP * (p.field + height)
		var toward: Vector3 = goings[i]
		toward.y = 0.0
		var dir: Vector3 = toward.normalized()
		var speed: float = float(Sim.handling_of(kinds[i]).get("cruise", p.downwind_speed))
		var entity: int = Sim.spawn_ai_vehicle(kinds[i], at, atan2(-dir.x, -dir.z), dir * speed)
		_check("aeroplane_%d_is_in_the_air" % i, entity != 0, str(at))
		if entity == 0:
			continue
		_traffic.arrive(entity, _field, kinds[i], _end)
		_add_plane(entity, i)


## EVERY LOOK AT EVERY AEROPLANE, one line each, into `--out`: `pattern-<scene>-tracks.txt`. What a picture cannot
## say -- the height, the speed and the leg at each moment -- for whoever reads the picture.
func _write_the_tracks() -> void:
	var file := FileAccess.open(_out.path_join("pattern-%s-tracks.txt" % _scene), FileAccess.WRITE)
	if file == null:
		return
	file.store_line("entity tick phase x y z over_ground speed climb")
	for entity in _planes:
		var me: Dictionary = _traffic.record_of(entity)
		for look in me.get("track", []):
			var at: Vector3 = look["at"]
			var v: Vector3 = look["v"]
			file.store_line("%d %d %s %.0f %.1f %.0f %.1f %.1f %.2f" % [entity, int(look["tick"]), look["phase"], at.x, at.y,
				at.z, at.y - maxf(Terrain.surface_height(at), 0.0), v.length(), v.y])


## ONE AEROPLANE TO FOLLOW: its track, its marker and its label.
func _add_plane(entity: int, i: int) -> void:
	_planes.append(entity)
	_tracks.append(PackedVector3Array())
	var mesh := ImmediateMesh.new()
	_lines.append(mesh)
	var drawn := MeshInstance3D.new()
	drawn.mesh = mesh
	drawn.material_override = _flat(TRACK_COLOURS[i % TRACK_COLOURS.size()], draws_on_top(_scene))
	add_child(drawn)
	var marker := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = _metres(MARKER_PIXELS) * 0.5
	disc.bottom_radius = disc.top_radius
	disc.height = 1.0
	marker.mesh = disc
	marker.material_override = _flat(TRACK_COLOURS[i % TRACK_COLOURS.size()], draws_on_top(_scene))
	add_child(marker)
	_markers.append(marker)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0012
	label.font_size = 48
	label.outline_size = 12
	label.modulate = TRACK_COLOURS[i % TRACK_COLOURS.size()]
	label.no_depth_test = true
	add_child(label)
	_labels.append(label)
	# SEEN FROM BEHIND, the track and the marker are drawn a few pixels wide for a view 7 km across, which is a wall at
	# seventy metres: the chase shows the aeroplane itself, and its leg and height over it.
	if _scene == "trip":
		drawn.visible = false
		marker.visible = false


## THE PATTERN'S LEGS ON THE GROUND: the 45 entry, downwind, base and final, as the traffic will fly them.
func _draw_the_pattern() -> void:
	var p: TrafficPattern = Airfield.pattern_for(_field, Sim.Kind.CESSNA, _end, AirportTraffic.turn_expected(Sim.Kind.CESSNA))
	var up := Vector3.UP * (p.field + DRAWN_UP)
	var corners := PackedVector3Array()
	for corner in [p.entry_start(), p.abeam_midfield(), p.base_turn(), p.point(p.base_ahead(), 0.0), p.aim_point()]:
		corners.append(Vector3(corner.x, 0.0, corner.z) + up)
	_draw_ribbon(corners, LEG_COLOUR, _metres(LINE_PIXELS * 0.6))
	# THE RUNWAY'S OUTLINE, so the strip reads at this scale: its paint is 45 m wide, six pixels.
	var frame: Dictionary = _field["frame"]
	var half_l: Vector3 = (frame["along"] as Vector3) * float(frame["length"]) * 0.5
	var half_w: Vector3 = (frame["across"] as Vector3) * float(frame["width"]) * 0.5
	var c: Vector3 = (frame["centre"] as Vector3) + Vector3.UP * DRAWN_UP
	_draw_ribbon(PackedVector3Array([c - half_l - half_w, c + half_l - half_w, c + half_l + half_w, c - half_l + half_w,
		c - half_l - half_w]), RUNWAY_COLOUR, _metres(LINE_PIXELS * 0.6))
	# AND THE INSTRUMENT FINAL: the final course from where it must be established to the runway, and a bar across it at
	# the final approach fix, where the glideslope is met.
	if _scene == "mixed":
		var ifr := InstrumentApproach.make(Airfield.pattern_for(_field, Sim.Kind.AIRLINER, _end, 0.34),
			Airfield.numbers_of(Sim.Kind.AIRLINER))
		var q: TrafficPattern = ifr.pattern
		var flat_up := Vector3.UP * (q.field + DRAWN_UP)
		var start: Vector3 = q.point(-ifr.established_out(), 0.0)
		_draw_ribbon(PackedVector3Array([Vector3(start.x, 0.0, start.z) + flat_up,
			Vector3(q.threshold.x, 0.0, q.threshold.z) + flat_up]), IFR_COLOUR, _metres(LINE_PIXELS * 0.6))
		var faf: Vector3 = q.threshold - q.along * InstrumentApproach.FAF_OUT
		_draw_ribbon(PackedVector3Array([Vector3(faf.x, 0.0, faf.z) + flat_up + q.across * 600.0,
			Vector3(faf.x, 0.0, faf.z) + flat_up - q.across * 600.0]), IFR_COLOUR, _metres(LINE_PIXELS * 0.6))


func _look_down() -> void:
	var p: TrafficPattern = Airfield.pattern_for(_field, Sim.Kind.CESSNA, _end, AirportTraffic.turn_expected(Sim.Kind.CESSNA))
	var middle: Vector3 = p.point(p.length * 0.5 - 600.0, p.offset * 0.5 + 900.0)
	if _scene == "two":
		middle = p.point(-1800.0, p.offset * 0.5 + 700.0)
	elif _scene == "mixed":
		middle = p.point(-7200.0, 1200.0)
	var camera: Camera3D = _level.observer
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _view_metres
	camera.far = 6000.0
	camera.look_from(middle + Vector3.UP * 3000.0, middle + Vector3(0.0, 0.0, -0.001))


func _follow_the_planes() -> void:
	var words := PackedStringArray()
	var aloft: Array[Vector3] = []
	for entity in _planes:
		var me: Dictionary = _traffic.record_of(entity)
		var state: Dictionary = Sim.server.vehicle_state(entity)
		if not me.is_empty() and not state.is_empty() and not (me["phase"] in [&"rollout", &"clearing", &"stopped"]):
			aloft.append(state["position"])
	for i in range(aloft.size()):
		for j in range(i + 1, aloft.size()):
			_closest = minf(_closest, aloft[i].distance_to(aloft[j]))
	for i in range(_planes.size()):
		var state: Dictionary = Sim.server.vehicle_state(_planes[i])
		var me: Dictionary = _traffic.record_of(_planes[i])
		if state.is_empty() or me.is_empty():
			continue
		var at: Vector3 = state["position"]
		# A PACKED ARRAY IS A VALUE: appended through a cast, the point went into a copy and no track was ever drawn.
		var points: PackedVector3Array = _tracks[i]
		points.append(at)
		_tracks[i] = points
		var mesh: ImmediateMesh = _lines[i]
		mesh.clear_surfaces()
		_ribbon_into(mesh, points, _metres(LINE_PIXELS))
		_markers[i].global_position = at
		var p: TrafficPattern = me["pattern"]
		var leg: String = String(me["phase"]).to_upper().replace("_", " ")
		_labels[i].text = "%s %d m" % [leg, roundi(at.y - p.field)]
		# BESIDE IT, not on it: north of the aeroplane by a label's height, so it never sits over the runway it lands on;
		# over it in the chase.
		_labels[i].global_position = at + (Vector3(0.0, 9.0, 0.0) if _scene == "trip" else Vector3(0.0, 20.0, -_metres(34.0)))
		var kind_name: String = Sim.Kind.keys()[int(me.get("kind", 0))].capitalize()
		words.append("%s %s: %s, %d m" % ["RED" if i == 0 else "BLUE", kind_name, leg, roundi(at.y - p.field)])
		if _scene == "trip":
			var ground: float = maxf(Terrain.surface_height(at), 0.0)
			words[words.size() - 1] = "%s  |  %d m over the ground  |  %d kt" % [leg, roundi(at.y - ground),
				roundi((state["velocity"] as Vector3).length() * 1.944)]
	if _banner != null and _scene == "trip":
		var going: String = "the island strip" if String(_traffic.record_of(_planes[0]).get("field", "")) == "island_strip" \
			else "to the south shore strip"
		_banner.text = "Airport life: the island strip to the south shore strip  |  %s  |  %s  |  x%s" % [going,
			"   ".join(words), str(_speed)]
	elif _banner != null:
		var p0: TrafficPattern = _traffic.record_of(_planes[0]).get("pattern") if not _planes.is_empty() else null
		var runway: String = "%02d" % (posmod(roundi(rad_to_deg(p0.heading()) / 10.0), 36) if p0 != null else 0)
		var side: String = "right" if p0 != null and p0.side > 0.0 else "left"
		if runway == "00":
			runway = "36"
		_banner.text = "South shore strip, runway %s, %s traffic  |  %s  |  x%s" % [runway, side, "   ".join(words),
			str(_speed)]


## Pixels of the picture, in metres of the top-down view.
func _metres(pixels: float) -> float:
	return pixels * _view_metres / maxf(float(get_viewport().get_visible_rect().size.y), 1.0)


## A FLAT RIBBON through `points`, `width` metres wide, facing up: a line that stays a few pixels wide from 3 km up.
func _draw_ribbon(points: PackedVector3Array, colour: Color, width: float) -> void:
	var mesh := ImmediateMesh.new()
	_ribbon_into(mesh, points, width)
	var drawn := MeshInstance3D.new()
	drawn.mesh = mesh
	drawn.material_override = _flat(colour, draws_on_top(_scene))
	add_child(drawn)


static func _ribbon_into(mesh: ImmediateMesh, points: PackedVector3Array, width: float) -> void:
	if points.size() < 2:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var along := Vector3(b.x - a.x, 0.0, b.z - a.z)
		if along.length() < 0.01:
			continue
		var side: Vector3 = Vector3(-along.z, 0.0, along.x).normalized() * width * 0.5
		# Each segment a quad, overlapping the next by half a width so the corners close.
		var reach: Vector3 = along.normalized() * width * 0.5
		var a0: Vector3 = a - reach - side
		var a1: Vector3 = a - reach + side
		var b0: Vector3 = b + reach - side
		var b1: Vector3 = b + reach + side
		for v in [a0, b0, a1, a1, b0, b1]:
			mesh.surface_add_vertex(v)
	mesh.surface_end()


## WHETHER THE SCENE'S DRAWN LINES (the legs, the runway's outline, the tracks) SHOW THROUGH THE GROUND. Straight down they
## are a map laid over the island, and a track flown at 400 m has to show over a 1,000 m peak, so they do. From the chase
## camera they are things standing in the world, and a strip drawn through a ridge reads as a rendering fault: the user
## saw exactly that on the P-51 trip (2026-09-19, lane/seethrough) -- the south shore strip's outline drawn over the
## mountains the aeroplane was crossing. `tests/seethrough.gd` holds it.
static func draws_on_top(scene: String) -> bool:
	return scene != "trip"


static func _flat(colour: Color, on_top: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	material.no_depth_test = on_top
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 10
	return material


func _save(name: String) -> void:
	var path: String = _out.path_join(name + ".png")
	_check("saved_%s" % name, get_viewport().get_texture().get_image().save_png(path) == OK, path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
