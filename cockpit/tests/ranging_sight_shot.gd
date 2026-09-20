extends Node
## THE RANGING SIGHT, LOOKED AT FROM THE GUNNER'S SEAT: a battleship broadside five kilometres off measured against the mil
## scale on the rendered picture, a shell laid on it by the drum, and a splash at the gun's longest range, watched as it
## swells and burns out.
##
##   Godot --path cockpit --resolution 1920x1080 res://tests/ranging_sight_shot.tscn -- --out=C:/somewhere
##   ... -- --out=C:/somewhere --bearing=40      # the target this many degrees to port of the bow (default 40)
##   ... -- --out=C:/somewhere --seat=3 --bearing=-90      # the aft turret's gunner, a target on the starboard beam
##
## FORTY DEGREES TO PORT BY DEFAULT: the first runs were from seat 2 on the port wing, where turret 1's barrels lay
## across the horizon at twenty and hid the target's stern. Since plan item 22d the seats are on hoods over their turrets
## and see starboard too: `--seat=3` and a negative `--bearing` take the other seat and the other side.
##
## A PROBE, NOT A SUITE: it renders. What headless holds is in tests/ranging_sight.gd -- that each mark is placed at its
## angle, that the keys lay the gun and the drum follows. What only a picture can hold is here: that a mark subtends ON THE
## SCREEN the mils it says against a real hull at a real range, and whether a splash can be seen from the seat.
##
## EVERYTHING IS MEASURED OFF THE PICTURE'S OWN PIXELS, by difference: the scale is the picture with the sight drawn less
## the same picture without it, the target is the picture with the target drawn less the picture without, and a burst is
## the picture after it went off less the picture before. Nothing is read back from the sight's own arithmetic. The first
## run read the ticks as "green pixels" and missed the ones over bright sky, and placed camera projections on the picture
## without the window's stretch: the viewport is 1600 wide (project.godot, canvas_items) and the picture 1920, so every
## projected point was a fifth of the way toward the corner.
##
## THE GUNNER'S DESK, NOT A PHOTOGRAPHER: the player asks for a battleship, is moved to the forward turret seat, and trains
## and lays with the desk keys; the desk camera turns with the turret on its own (PilotRig._desk_train), which is what put
## the target in these pictures -- the first runs had the view fixed over the bow and set the look angle by hand. The one thing a gunner would not do is change the lens: the mils are also measured through a
## 12 degree one from the same eye, because at the desk's own a mil is under a pixel. Angles do not depend on the lens.
##
## Pictures in `--out`: `seat-<step>.png`, with `-zoom` crops enlarged round what the step is about.

const BATTLESHIP: int = 13
const SEAT: int = 2
const TARGET_M: float = 5000.0
const MEASURING_FOV: float = 12.0
const SETTLE: int = 30
## Seconds after a shell lands that a burst is photographed: the swell (BurstTuning.FIREBALL_GROW_S is 0.45), the burn
## (FIREBALL_BURN_S 2.2) and the smoke after.
const BURST_TIMES: Array[float] = [0.15, 0.45, 1.0, 2.0, 4.0]
## How much a channel must change for a pixel to count as drawn by the thing toggled. The hull is grey on a grey sea by
## the horizon, and less changes where it is.
const DIFFERS: float = 0.06
const HULL_DIFFERS: float = 0.025
const HEADSET_PIXELS_PER_DEGREE: float = 20.0

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://ranging_sight_shot"
var _bearing_deg: float = 40.0
var _seat: int = SEAT
var _fov: float = -1.0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[ranging_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--bearing="):
			_bearing_deg = float(argument.trim_prefix("--bearing="))
		elif argument.begins_with("--seat="):
			_seat = int(argument.trim_prefix("--seat="))
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	print("[ranging_shot] %s, %s precision, %s on %s, window %s" % [Engine.get_version_info()["string"],
		"double" if OS.has_feature("double") else "single", RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(), DisplayServer.window_get_size()])
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(240)
	var words := _level.get_node_or_null("Ui") as CanvasLayer
	if words != null:
		words.visible = false
	var rig: PilotRig = _level.rig
	var sight: RangeSight = await _sit(rig)
	if sight == null:
		_finish()
		return
	await _frames(600)
	var mine: VehicleView = rig.vehicle_view()
	var camera: Camera3D = rig.desktop_camera
	var trunnion: Vector3 = mine.global_transform * (sight.gun.get("at", Vector3.ZERO) as Vector3)
	var ahead: Vector3 = -mine.global_basis.z
	ahead.y = 0.0
	var toward: Vector3 = ahead.normalized().rotated(Vector3.UP, deg_to_rad(_bearing_deg))
	var put: Vector3 = Vector3(trunnion.x, 0.0, trunnion.z) + toward * TARGET_M
	print("[ranging_shot] my battleship at %s, heeled %.2f deg to starboard and trimmed %.2f deg bow up; the target %.0f deg to port, %.0f m off, ground under it %.1f m" % [
		mine.global_position, rad_to_deg(asin(clampf(-mine.global_basis.x.normalized().y, -1.0, 1.0))),
		rad_to_deg(asin(clampf(-mine.global_basis.z.normalized().y, -1.0, 1.0))), _bearing_deg, TARGET_M,
		float(Sim.server.ground_height_at(put.x, put.z))])
	# BROADSIDE ON: turned until its own length lies across the line of sight, whatever `spawn_vehicle`'s yaw convention.
	var target: VehicleView = await _broadside_target(put, toward)
	if target == null:
		_finish()
		return

	# ---- 1. train on the target with the desk keys --------------------------------------------------------------
	await _train_on(rig, camera, sight, target)
	await _frames(SETTLE)
	var stretch: float = float(get_viewport().get_texture().get_image().get_width()) / get_viewport().get_visible_rect().size.x
	await _picture("1-trained-on-target-5km", camera, stretch, target.global_position, Vector2(640.0, 360.0), 3)

	# ---- 2. the scale against a hull of known length, off the picture ------------------------------------------
	var desk_fov: float = camera.fov
	_fov = MEASURING_FOV
	await _frames(SETTLE)
	await _measure_the_hull(camera, sight, target, stretch)
	_fov = desk_fov
	await _frames(SETTLE)

	# ---- 3. laid by the drum on the target, fired, spotted -------------------------------------------------------
	var wanted: float = Vector2(target.global_position.x - trunnion.x, target.global_position.z - trunnion.z).length()
	# A TAP AT A TIME, READ WHEN IT HAS SETTLED: the laid aim carries on a few frames after a key is let go, and read at
	# once a tap ran the drum on to 5,272 m for 5,000.
	for i in range(1200):
		if _read(sight.says(), "RANGE ") >= wanted:
			break
		await _hold("pitch_up", 1 if _read(sight.says(), "RANGE ") > wanted - 400.0 else 6)
		await _frames(6)
	print("[ranging_shot] laid for %.0f m: %s" % [wanted, sight.says().replace("\n", " | ")])
	var first: Dictionary = await _fire_and_watch(camera, sight, stretch, "3-laid-on-target")
	_check("the_splash_laid_by_the_drum_falls_by_the_target", not first.is_empty()
		and (first["impact"] as Vector3).distance_to(target.global_position) < 300.0,
		"impact %.0f m from the target's middle" % (first.get("impact", Vector3.INF) as Vector3).distance_to(target.global_position))

	# ---- 4. the elevation stop: six kilometres -------------------------------------------------------------------
	await _hold("pitch_up", 900)
	await _frames(int(7.0 * 60.0))
	print("[ranging_shot] at the stop: %s" % sight.says().replace("\n", " | "))
	await _fire_and_watch(camera, sight, stretch, "4-splash-6km")
	_finish()


## ---- the target ------------------------------------------------------------------------------------------------

func _broadside_target(put: Vector3, toward: Vector3) -> VehicleView:
	var target: VehicleView = null
	var mine: VehicleView = _level.rig.vehicle_view()
	for attempt in range(2):
		var yaw: float = atan2(-toward.x, -toward.z) + PI * 0.5
		Sim.server.spawn_vehicle(BATTLESHIP, put, yaw, Vector3.ZERO)
		for i in range(900):
			await get_tree().physics_frame
			for node in get_tree().root.find_children("*", "VehicleView", true, false):
				var view := node as VehicleView
				if view != mine and view.kind == BATTLESHIP and view.global_position.distance_to(put) < 200.0:
					target = view
			if target != null:
				break
		if target != null:
			break
	_check("the_target_is_drawn_five_kilometres_off", target != null, "put at %s" % put)
	if target == null:
		return null
	await _frames(600)
	var across: float = absf(target.global_basis.z.normalized().dot(toward))
	_check("the_target_lies_broadside_on", across < 0.05, "its length is %.1f deg off square to the line of sight" %
		rad_to_deg(asin(clampf(across, 0.0, 1.0))))
	return target


## TRAIN WITH THE DESK KEYS until the crosshair is on the target's middle: roll_left and roll_right, a frame at a time as
## it closes, as a gunner taps a key.
func _train_on(rig: PilotRig, camera: Camera3D, sight: RangeSight, target: VehicleView) -> void:
	for i in range(3000):
		var off: float = _bearing_error(camera, sight, target)
		if absf(off) < deg_to_rad(0.03):
			break
		var action: String = "roll_left" if off > 0.0 else "roll_right"
		await _hold(action, 30 if absf(off) > deg_to_rad(2.0) else 1)
		await _frames(2)
	print("[ranging_shot] trained: the crosshair %.3f deg off the target's middle" % rad_to_deg(_bearing_error(camera,
		sight, target)))


## Positive when the target is to the left of the crosshair.
static func _bearing_error(camera: Camera3D, sight: RangeSight, target: VehicleView) -> float:
	var ahead: Vector3 = -sight.global_basis.z
	var to: Vector3 = target.global_position - camera.global_position
	ahead.y = 0.0
	to.y = 0.0
	return ahead.normalized().signed_angle_to(to.normalized(), Vector3.UP)


## ---- the measurement --------------------------------------------------------------------------------------------

func _measure_the_hull(camera: Camera3D, sight: RangeSight, target: VehicleView, stretch: float) -> void:
	var drawn: Image = await _grab()
	_show_sight(sight, false)
	var bare: Image = await _grab()
	target.visible = false
	var empty: Image = await _grab()
	target.visible = true
	_show_sight(sight, true)
	_save(drawn, "2-measured-12deg")
	# THE TICKS: the columns where the sight changes MORE of the picture than its bar alone does, in a band from the bar
	# up past the shortest tick. NOT ONE ROW: the scale is level with the world and the camera rolls with the ship, so on
	# the first run the bar crossed the picture on a slant and a row under the ticks' tops at one end was under the bar's
	# at the other.
	var bar_y: float = camera.unproject_position(sight.scale_centre()).y * stretch
	var px_per_mil_guess: float = float(drawn.get_height()) * 0.5 / tan(deg_to_rad(camera.fov) * 0.5) / 1000.0
	var centre_x: float = camera.unproject_position(sight.scale_centre()).x * stretch
	var runs: Array = _tick_columns(drawn, bare, bar_y, px_per_mil_guess, centre_x)
	var fit: Vector2 = _px_per_mil(runs, centre_x, px_per_mil_guess)
	# THE HULL: every column where the target changes the picture, from its waterline to twenty-five metres up -- the
	# upperworks are all shorter than the hull, so the widest row is the hull's length.
	var half: Vector3 = Sim.geometry_of(BATTLESHIP).get("extents", Vector3.ONE) as Vector3
	var top_y: int = int(camera.unproject_position(target.global_transform * Vector3(0.0, 25.0, 0.0)).y * stretch)
	var water_y: int = int(camera.unproject_position(target.global_transform * Vector3(0.0, -1.0, 0.0)).y * stretch)
	var ends := Vector2(INF, -INF)
	var middle_x: int = int(round(camera.unproject_position(target.global_position).x * stretch))
	for y in range(mini(top_y, water_y) - 1, maxi(top_y, water_y) + 2):
		var hull: Vector2 = _run_through(bare, empty, y, middle_x, HULL_DIFFERS)
		if hull.x >= 0.0:
			ends.x = minf(ends.x, hull.x)
			ends.y = maxf(ends.y, hull.y)
	var eye: Vector3 = camera.global_position
	var bow: Vector3 = target.global_transform * Vector3(0.0, 0.0, -half.z)
	var stern: Vector3 = target.global_transform * Vector3(0.0, 0.0, half.z)
	var true_mils: float = (bow - eye).angle_to(stern - eye) * 1000.0
	var projected: float = absf(camera.unproject_position(bow).x - camera.unproject_position(stern).x) * stretch
	var measured: float = (ends.y - ends.x + 1.0) / fit.x
	var range_m: float = eye.distance_to(target.global_position)
	print("[ranging_shot] the target is heeled %.2f deg and trimmed %.2f deg as it is measured" % [
		rad_to_deg(asin(clampf(-target.global_basis.x.normalized().y, -1.0, 1.0))),
		rad_to_deg(asin(clampf(-target.global_basis.z.normalized().y, -1.0, 1.0)))])
	print("[ranging_shot] ticks: %d found, %.3f px a mil through them (worst %.2f px off the line); the lens alone says %.3f"
		% [runs.size(), fit.x, fit.y, px_per_mil_guess])
	print("[ranging_shot] the hull's pixels span columns %.0f to %.0f (%.0f px); the camera puts its ends %.1f px apart"
		% [ends.x, ends.y, ends.y - ends.x + 1.0, projected])
	_check("forty_ticks_are_found_in_the_picture", runs.size() == RangeSight.TICKS * 2, "%d" % runs.size())
	_check("a_hull_of_known_length_at_known_range_subtends_on_the_picture_the_mils_the_scale_says",
		absf(measured - true_mils) <= 1.0,
		"%.1f m long at %.0f m: truly %.2f mils; on the picture %.2f mils by the scale's own ticks, so km = metres / mils says %.2f km"
		% [half.z * 2.0, range_m, true_mils, measured, half.z * 2.0 / measured])
	var middle := Vector2((ends.x + ends.y) * 0.5, bar_y)
	_save_zoom(drawn, "2-measured-12deg", middle, Vector2(maxf(ends.y - ends.x, 200.0) * 1.3, 180.0), 3)


## THE CENTRES OF THE RUNS OF PIXELS THAT DIFFER between two pictures along one row. With `outer`, only the first and last
## differing columns.
static func _runs_of_difference(a: Image, b: Image, row: int, from: int, to: int, outer: bool, threshold: float) -> Array:
	var runs: Array = []
	if row < 0 or row >= a.get_height():
		return runs
	var start: int = -1
	var first: int = -1
	var last: int = -1
	for x in range(from, to + 1):
		var differs: bool = false
		if x < to:
			var p: Color = a.get_pixel(x, row)
			var q: Color = b.get_pixel(x, row)
			differs = maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))) > threshold
		if differs:
			if first < 0:
				first = x
			last = x
		if differs and start < 0:
			start = x
		elif not differs and start >= 0:
			runs.append((float(start) + float(x - 1)) * 0.5)
			start = -1
	if outer:
		return [float(first), float(last)] if first >= 0 else []
	return runs


## THE TICKS' COLUMNS: in a band from 1.5 mils under the bar to 4 over it, the columns where the sight changed at least
## 1.3 mils' worth of pixels more than the bar alone could (its 1.5 mils plus the slant). The crosshair's own column is
## left out. The centres of the runs of such columns.
static func _tick_columns(drawn: Image, bare: Image, bar_y: float, px_per_mil: float, centre_x: float) -> Array:
	var low: int = int(bar_y + 1.5 * px_per_mil)
	var high: int = int(bar_y - 4.0 * px_per_mil)
	var enough: int = int(ceil((RangeSight.LINE_MILS + 1.3) * px_per_mil))
	var runs: Array = []
	var start: int = -1
	for x in range(drawn.get_width() + 1):
		var tick: bool = false
		if x < drawn.get_width() and absf(float(x) - centre_x) > RangeSight.LINE_MILS * px_per_mil + 2.0:
			var count: int = 0
			for y in range(maxi(high, 0), mini(low, drawn.get_height() - 1) + 1):
				var p: Color = drawn.get_pixel(x, y)
				var q: Color = bare.get_pixel(x, y)
				if maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))) > DIFFERS:
					count += 1
			tick = count >= enough
		if tick and start < 0:
			start = x
		elif not tick and start >= 0:
			runs.append((float(start) + float(x - 1)) * 0.5)
			start = -1
	return runs


## THE RUN OF DIFFERING COLUMNS THROUGH `middle` along a row, allowing gaps of two pixels (a mast, a low deck): its first
## and last columns, or (-1, -1) if `middle` is not in one. ONLY THE RUN THROUGH THE TARGET: on the starboard beam an
## island stood behind the target, the ship bobbed a pixel between the two pictures, and every edge of the land differed --
## the whole-row scan measured 992 px for a 278 px hull.
static func _run_through(a: Image, b: Image, row: int, middle: int, threshold: float) -> Vector2:
	if row < 0 or row >= a.get_height() or middle < 0 or middle >= a.get_width():
		return Vector2(-1.0, -1.0)
	var differs := func(x: int) -> bool:
		var p: Color = a.get_pixel(x, row)
		var q: Color = b.get_pixel(x, row)
		return maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))) > threshold
	var found: int = -1
	for dx in range(0, 4):
		for x in [middle - dx, middle + dx]:
			if found < 0 and x >= 0 and x < a.get_width() and differs.call(x):
				found = x
	if found < 0:
		return Vector2(-1.0, -1.0)
	var first: int = found
	var gap: int = 0
	var x: int = found - 1
	while x >= 0 and gap <= 2:
		if differs.call(x):
			first = x
			gap = 0
		else:
			gap += 1
		x -= 1
	var last: int = found
	gap = 0
	x = found + 1
	while x < a.get_width() and gap <= 2:
		if differs.call(x):
			last = x
			gap = 0
		else:
			gap += 1
		x += 1
	return Vector2(float(first), float(last))


## PIXELS PER MIL through the tick columns by least squares, each column taken as the nearest TICK_MILS step by what the
## lens alone says; and the worst column off that line.
static func _px_per_mil(runs: Array, centre_x: float, guess: float) -> Vector2:
	var pairs: Array[Vector2] = []
	for x in runs:
		var steps: int = roundi((float(x) - centre_x) / guess / float(RangeSight.TICK_MILS))
		if steps != 0:
			pairs.append(Vector2(float(steps * RangeSight.TICK_MILS), float(x)))
	if pairs.size() < 2:
		return Vector2(1.0, INF)
	var n: float = float(pairs.size())
	var sx: float = 0.0
	var sy: float = 0.0
	var sxx: float = 0.0
	var sxy: float = 0.0
	for p in pairs:
		sx += p.x
		sy += p.y
		sxx += p.x * p.x
		sxy += p.x * p.y
	var slope: float = (n * sxy - sx * sy) / (n * sxx - sx * sx)
	var offset: float = (sy - slope * sx) / n
	var worst: float = 0.0
	for p in pairs:
		worst = maxf(worst, absf(offset + slope * p.x - p.y))
	return Vector2(slope, worst)


## ---- the fall of shot -------------------------------------------------------------------------------------------

## FIRE, and photograph the burst at each of BURST_TIMES with the sight and without, measuring from the picture without
## how big the burst is drawn: the pixels round the impact that differ from a picture taken, sight hidden, while the shell
## was still in the air. The shell's last row, or {}.
func _fire_and_watch(camera: Camera3D, sight: RangeSight, stretch: float, name: String) -> Dictionary:
	var me: int = Sim.local_client_id()
	var seen: Dictionary = {}
	for row in Sim.shots:
		seen[int((row as Dictionary)["entity"])] = true
	# THE HULL'S TILT AT THE MOMENT OF FIRE, as what it does to the gun's elevation in the world: the drum reads the
	# elevation against the ship, and a ship rolling as it fires on the beam throws the shell long or short of the drum.
	var laid: Vector2 = (Sim.client.gunner_state(Sim.local_client_id()).get("aim", Vector2.ZERO) as Vector2)
	var craft: VehicleView = _level.rig.vehicle_view()
	var barrel: Vector3 = craft.global_basis * Vector3(-sin(laid.x) * cos(laid.y), sin(laid.y), -cos(laid.x) * cos(laid.y))
	print("[ranging_shot] %s: fired laid at %.2f deg against the ship, %.2f deg in the world (the hull's tilt adds %+.2f)"
		% [name, rad_to_deg(laid.y), rad_to_deg(asin(barrel.normalized().y)), rad_to_deg(asin(barrel.normalized().y) - laid.y)])
	await _hold("fire", 6)
	var shell: Dictionary = {}
	var before: Image = null
	var fired_ms: int = Time.get_ticks_msec()
	for i in range(int(40.0 * 120.0)):
		await get_tree().physics_frame
		for row in Sim.shots:
			var shot: Dictionary = row
			if shell.is_empty() and not seen.has(int(shot["entity"])) and int(shot.get("shooter", -1)) == me:
				shell = shot
		if shell.is_empty():
			continue
		var now: Dictionary = {}
		for row in Sim.shots:
			if int((row as Dictionary)["entity"]) == int(shell["entity"]):
				now = row
		# THE PICTURE BEFORE, two seconds after the shot, so the gun's own smoke has gone and the shell has not landed.
		if before == null and Time.get_ticks_msec() - fired_ms > 2000:
			_show_sight(sight, false)
			before = await _grab()
			_show_sight(sight, true)
		if not now.is_empty() and not bool(now.get("flying", true)):
			return await _photograph_the_burst(camera, sight, stretch, name, now, before)
	_check("%s_the_shell_lands" % name, false, "shell %s" % shell.get("entity", 0))
	return {}


func _photograph_the_burst(camera: Camera3D, sight: RangeSight, stretch: float, name: String, shot: Dictionary,
		before: Image) -> Dictionary:
	var impact: Vector3 = shot["impact"] as Vector3
	var landed_ms: int = Time.get_ticks_msec()
	var from_eye: float = camera.global_position.distance_to(impact)
	var px_per_rad: float = float(before.get_height()) * 0.5 / tan(deg_to_rad(camera.fov) * 0.5)
	var headset_per_px: float = HEADSET_PIXELS_PER_DEGREE * rad_to_deg(1.0 / px_per_rad)
	print("[ranging_shot] %s: landed %.0f m from the eye; board %s" % [name, from_eye, sight.says().replace("\n", " | ")])
	for at_s in BURST_TIMES:
		while Time.get_ticks_msec() - landed_ms < int(at_s * 1000.0):
			await get_tree().process_frame
		var with_sight: Image = await _grab()
		_show_sight(sight, false)
		var without: Image = await _grab()
		_show_sight(sight, true)
		var at: Vector2 = camera.unproject_position(impact) * stretch
		var box: Rect2i = _burst_box(without, before, at, 120)
		var tag: String = "%s-%.2fs" % [name, at_s]
		print("[ranging_shot] %s: the burst is drawn %d x %d window px round %s, which is %.1f x %.1f mrad and %.0f x %.0f headset px"
			% [tag, box.size.x, box.size.y, at, box.size.x / px_per_rad * 1000.0, box.size.y / px_per_rad * 1000.0,
				box.size.x * headset_per_px, box.size.y * headset_per_px])
		_save(with_sight, tag)
		_save(without, tag + "-no-sight")
		_save_zoom(without, tag + "-no-sight", at, Vector2(240.0, 135.0), 4)
	return shot


## THE BURST AS DRAWN: the box of the pixels, joined to the impact, that differ from the picture before it landed. The
## ship has bobbed between the two, and a horizon one pixel higher differs along its whole length -- the first run's box
## was the whole search square -- so the picture before is first slid up or down by whichever whole pixels match the
## square's far left and right edges best, and then filled outward from within four pixels of the impact.
static func _burst_box(a: Image, b: Image, at: Vector2, reach: int) -> Rect2i:
	if b == null:
		return Rect2i()
	var cx: int = int(at.x)
	var cy: int = int(at.y)
	var best_shift: int = 0
	var best: float = INF
	for shift in range(-6, 7):
		var total: float = 0.0
		for y in range(cy - reach, cy + reach):
			for x in [cx - reach, cx - reach + 1, cx + reach - 2, cx + reach - 1]:
				total += _change(a, b, x, y, y + shift)
		if total < best:
			best = total
			best_shift = shift
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = []
	for y in range(cy - 4, cy + 5):
		for x in range(cx - 4, cx + 5):
			if _change(a, b, x, y, y + best_shift) > DIFFERS * 2.0:
				queue.append(Vector2i(x, y))
				seen[Vector2i(x, y)] = true
	var low := Vector2i(1 << 30, 1 << 30)
	var high := Vector2i(-1, -1)
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		low = Vector2i(mini(low.x, p.x), mini(low.y, p.y))
		high = Vector2i(maxi(high.x, p.x), maxi(high.y, p.y))
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = p + step
			if seen.has(n) or absi(n.x - cx) > reach or absi(n.y - cy) > reach:
				continue
			seen[n] = true
			if _change(a, b, n.x, n.y, n.y + best_shift) > DIFFERS * 2.0:
				queue.append(n)
	print("[ranging_shot]   (the picture before slid %d px to match the bob)" % best_shift)
	return Rect2i(low, high - low + Vector2i.ONE) if high.x >= 0 else Rect2i()


static func _change(a: Image, b: Image, x: int, y: int, y_in_b: int) -> float:
	if x < 0 or y < 0 or x >= a.get_width() or y >= a.get_height() or y_in_b < 0 or y_in_b >= b.get_height():
		return 0.0
	var p: Color = a.get_pixel(x, y)
	var q: Color = b.get_pixel(x, y_in_b)
	return maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b)))


## ---- driving --------------------------------------------------------------------------------------------------

func _sit(rig: PilotRig) -> RangeSight:
	rig.ask_for_kind(BATTLESHIP)
	var view: VehicleView = null
	for i in range(900):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and view.kind == BATTLESHIP:
			break
	var craft: int = 0
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", -1)) == Sim.local_client_id():
			craft = int((pilot as Dictionary).get("vehicle", 0))
	Sim.server.seat_client(Sim.local_client_id(), craft, _seat)
	for i in range(300):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and rig.seat_index() == _seat and view.station_for(_seat) != null:
			var sight := view.station_for(_seat).get_node_or_null("RangeSight") as RangeSight
			if sight != null:
				return sight
	_check("the_gunner_is_seated_at_a_ranging_sight", false, "seat %d" % rig.seat_index())
	return null


func _process(_delta: float) -> void:
	if _fov > 0.0 and _level != null and _level.rig != null:
		_level.rig.desktop_camera.fov = _fov


func _picture(name: String, camera: Camera3D, stretch: float, about: Vector3, size: Vector2, scale: int) -> void:
	var image: Image = await _grab()
	_save(image, name)
	_save_zoom(image, name, camera.unproject_position(about) * stretch, size, scale)


## THE SIGHT DRAWN OR NOT, for a picture with and without it: by its pieces, because the station sets the sight itself
## visible every frame for whoever sits at it (plan item 22e), and a probe that hid the sight was undone on the next frame.
static func _show_sight(sight: RangeSight, on: bool) -> void:
	for child in sight.get_children():
		if child is Node3D:
			(child as Node3D).visible = on if child.name != "Train" else (on and sight.train_says() != "")


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


static func _read(said: String, label: String) -> float:
	var at: int = said.find(label)
	if at < 0:
		return -1.0
	var digits: String = ""
	for c in said.substr(at + label.length()):
		if c == ",":
			continue
		if c < "0" or c > "9":
			break
		digits += c
	return float(digits) if digits != "" else -1.0


func _hold(action: String, frames: int) -> void:
	var code: Key = KEY_NONE
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			code = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			break
	for pressed in [true, false]:
		var press := InputEventKey.new()
		press.keycode = code
		press.physical_keycode = code
		press.pressed = pressed
		Input.parse_input_event(press)
		if pressed:
			for i in range(frames):
				await get_tree().physics_frame
	await get_tree().physics_frame


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _save(image: Image, name: String) -> void:
	var path: String = "%s/seat-%s.png" % [_out, name]
	image.save_png(path)
	print("[ranging_shot] saved %s" % path)


func _save_zoom(image: Image, name: String, centre: Vector2, size: Vector2, scale: int) -> void:
	var rect := Rect2i(Vector2i(centre - size * 0.5), Vector2i(size)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var crop: Image = image.get_region(rect)
	crop.resize(rect.size.x * scale, rect.size.y * scale, Image.INTERPOLATE_NEAREST)
	crop.save_png("%s/seat-%s-zoom.png" % [_out, name])


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
