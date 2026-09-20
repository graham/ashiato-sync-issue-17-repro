extends Node
## A SHORT, DETERMINISTIC REEL OF ONE REAL CRAFT FLYING OVER A SMALL FILM STAGE.
##
## Do not launch this by hand: `tools/create_video_demo.ps1` supplies MovieWriter, a fixed
## frame rate, the one-craft fly bench and a deadline. The bench starts the game's real AI
## pilot and physics at height; this scene adds only a compact visual landscape, measures
## the drawn craft to choose a lens, and performs the requested shots. It calls `quit()` so MovieWriter writes its
## index and closes a playable file; killing Godot does not finalize the movie.
##
## User arguments after `--`:
##   --kind=cessna --seconds=24 --shots=orbit,flyby
##   --finish=plain|fine --time=day|evening|night|dawn|dusk|HH:MM
##   --sweep-script=1:68,5.5:20   the F-14's wings: at 1 s ask for 68 degrees, at 5.5 s for 20
##   --stick-script=1.5:1:0:0,4:0:0:0   at 1.5 s the stick hard right (roll:pitch:pedals), at 4 s centred
##   --stick-script=0:0:0:0:0.6:0,6:0:0:1:0:1   six fields adds the THROTTLE and the BRAKE (roll:pitch:pedals:throttle:
##                brake): open to 0.6 at the start, then at 6 s full right pedal with the throttle shut and full brake --
##                which is a braked turn, and the manoeuvre a taildragger's and a tricycle's wheels disagree about
##   --parked=1   (read by the bench) the craft stands on the stage's ground instead of flying
##   --head-script=1:60:0,3:-40:-15   the GUNNER's look (yaw to port : pitch up, degrees) from each time on, sent as his
##                input frame's head, in the seat whose mount follows the head (the AH-64's chin gun, lane/apache)
##   --fire=2.2:2.8   the trigger held from 2.2 s to 2.8 s, by the same seated hand
##   --boat=720:-1250   a patrol boat on the stage's river at that x and z, for a missile to be locked on and fired at
##   --lock=2.0 --launch=4.5   LOCK pressed at 2.0 s and LAUNCH at 4.5 s by the seated hand, the master arm thrown half a
##                second before the launch: the AH-64's helmet Hellfire (lane/apache step 4)
##   --afloat=1   (read by the bench) a flying boat taxis on the stage's river instead, a hand on the lever holding 5 m/s
##
## A SCRIPT IS A CREW'S HAND, NOT A POSE. The wings are asked for through `VehicleView.propose`, the call a sweep handle
## makes, and the server slews them at its 12 degrees a second; the stick is this player's input frame (`Sim.set_input`),
## eased at a hand's pace, and the linkage the server hands back is what the view draws. So this player is SEATED: in the
## first seat that does not fly for a sweep alone, which leaves the autopilot flying, and in the pilot's for a stick.

const FOV: float = 50.0
const FILL: float = 0.46
const CLOSEST: float = 8.0
# The MovieWriter starts before the bench does. At the supported 24--30 fps capture rates,
# these frames plus the 0.45 s fade keep the named title under a two-second pre-roll.
const SETTLE_FRAMES: int = 24
const WAIT_FRAMES: int = 6000
const SAMPLES_PER_SURFACE: int = 6000
const ALLOWED_SHOTS: PackedStringArray = ["orbit", "chase", "flyby", "hero", "above", "plan", "quarter", "tail",
	"astern", "chin", "gunner", "missile"]
## HOW FAST A SCRIPTED HEAD TURNS, degrees a second: a real glance is several hundred, far quicker than any gun turret,
## which is the whole point of the lag the chin gun's reel shows.
const HEAD_RATE: float = 400.0
## THE STAGE'S GROUND, 120 m under the height the bench holds its craft at, and asked of the bench rather than typed.
const STAGE_GROUND: float = CockpitBench.STAGE_GROUND
## HOW FAST A SCRIPTED HAND MOVES THE STICK, full travel a second and a half: a step from centre to a stop would draw the
## surfaces snapping over in a frame, which no pilot's hand does.
const STICK_RATE: float = 2.0 / 1.5
## THE MOST A FLYING BOAT ON THE WATER MAY TILT under a held stick, degrees: `tests/ground_stick.gd` holds the Savoia to
## the bank that buries its float, 9.3, plus 4 for the swell.
const AFLOAT_TILT: float = 15.0
## HOW FAR THE CRAFT MAY END FROM WHERE THE REEL STARTED IT, in height. The user watched the light helicopter sink through
## this stage's ground in a 24 s reel (2026-09-17): the bench had not held its height, and the helicopter autopilot flew
## down to its own 220 m. Held, it ends within 1 m; this fails a reel whose craft is not where the stage says it is.
const HEIGHT_KEPT_WITHIN: float = 20.0

var _failures: PackedStringArray = []
var _kind_name: String = "cessna"
var _kind: int = -1
var _seconds: float = 24.0
var _shots: PackedStringArray = ["orbit", "flyby"]
var _fine: bool = true
var _time: int = DaylightTuning.When.DAY
## THE CLOCK THE CLOUDS AND TRAILS ARE LIT AT, minutes: `--time=` as a named point or HH:MM (2026-09-18). The stage's own
## light keeps its three looks, by the preset this clock's look is most like (`_time`).
var _clock: float = DaylightTuning.clock_of(DaylightTuning.When.DAY)

var _bench: CockpitBench = null
var _view: VehicleView = null
var _camera: Camera3D = null
var _missiles: MissileYard = null
var _contrails: ContrailYard = null
## EVERY ROUND IN THE AIR, drawn as the sky draws them: the stage has no FlightLevel, so a burst from the chin gun
## (lane/apache) was fired, flew and landed with nothing to show it.
var _rounds: ShotYard = null
var _lift: LiftYard = null
var _focus_local: Vector3 = Vector3.ZERO
var _distance: float = 20.0
var _rise: float = 2.0
var _elapsed: float = 0.0
var _running: bool = false
var _last_shot: int = -1
var _flyby_at: Vector3 = Vector3.ZERO
var _slate: ColorRect = null
var _slate_label: Label = null
var _stills: String = ""
var _stills_saved: Dictionary = {}
var _start_height: float = NAN
var _lowest: float = INF
## The scripts, [[seconds, value], ...] in time order: degrees for the sweep, Vector3(roll, pitch, pedals) for the stick.
var _sweep_script: Array = []
var _stick_script: Array = []
## The throttle and the brake a six-field stick script asks for, or (-1, -1) while the script names only the stick.
var _levers_wanted := Vector2(-1.0, -1.0)
var _stick_wanted := Vector3.ZERO
## THE GUNNER'S LOOK: [[seconds, Vector2(yaw, pitch) degrees]], where it is going and where it is; the trigger windows.
var _head_script: Array = []
var _head_wanted := Vector2.ZERO
var _head_now := Vector2.ZERO
var _fire_script: Array = []
## Whether the gunner's station is fitted, for `_man_for`.
var _manned: bool = false
## THE BOAT (`--boat`), where on the stage and its view once it is on the wire; and the LOCK and LAUNCH presses.
var _boat_at: Vector2 = Vector2.INF
var _boat_view: VehicleView = null
var _lock_at: float = -1.0
var _launch_at: float = -1.0
var _armed: bool = false
var _screens_due: float = 0.0
## Where the missile shot's camera last was, held once the missile has ended so the burst is seen from where it was.
var _missile_camera: Transform3D = Transform3D()
var _missile_seen: bool = false
## Each missile whose end the log has already reported, by entity.
var _ends_told: Dictionary = {}
var _stick_now := Vector3.ZERO
var _seated: int = -1
var _caption: Label = null
var _centre_local: Vector3 = Vector3.ZERO
var _sweeps_seen: Vector2 = Vector2(INF, -INF)
var _asked_low: float = INF
var _asked_high: float = -INF
## The least upright the craft was drawn, as its up axis's height: 1 level, 0 on its side.
var _least_upright: float = 1.0


func _ready() -> void:
	_read_arguments()
	_build_slate()
	if DisplayServer.get_name() == "headless":
		_fail("it_is_rendering", "MovieWriter needs a rendering device; omit --headless")
		_finish()
		return
	if _failures.is_empty():
		await _prepare_stage()
	if not _failures.is_empty():
		_finish()
		return
	RenderingServer.frame_pre_draw.connect(_aim_camera)
	RenderingServer.frame_post_draw.connect(_save_still_after_draw)
	_running = true
	print("[craft_video] RECORDING %.1f seconds of %s: %s" % [
		_seconds, _kind_name, ", ".join(_shots)])


func _process(delta: float) -> void:
	# The real sky advances these yards every frame. The little stage has no FlightLevel,
	# so it makes the same calls explicitly: one shared trail clock, then the visible craft.
	# EVERY MISSILE IN THE AIR, as FlightLevel draws them: none in most reels, the Hellfire in the AH-64's.
	if _missiles != null:
		_missiles.draw_missiles(Sim.missiles, _camera.global_position if _camera != null else Vector3.ZERO, delta,
			Sim.drawing_late(), Engine.get_physics_interpolation_fraction() * Sim.tick_dt())
	if _boat_view != null and is_instance_valid(_boat_view):
		_boat_view.draw()
	# EACH MISSILE'S END, ONCE, in the log: what it struck and where, which is the reel's evidence as much as its picture.
	for m in Sim.missiles:
		var one: Dictionary = m
		if not bool(one.get("flying", true)) and not _ends_told.has(int(one.get("entity", 0))):
			_ends_told[int(one.get("entity", 0))] = true
			print("[craft_video] MISSILE ended at %.2f s on %d (the boat %d) at %s, %.0f m from the craft" % [_elapsed,
				int(one.get("target_hit", 0)), _boat_view.entity if _boat_view != null else 0, one.get("position"),
				(one.get("position", Vector3.ZERO) as Vector3).distance_to(_view.global_position) if is_instance_valid(_view) else -1.0])
	# THE MANNED STATION'S SCREENS AND SIGHTS, five times a second as FlightLevel feeds them: the bench flies an empty
	# craft and feeds nothing, so a lock sight in the reel would say "no missiles" over a locked boat.
	if _manned and is_instance_valid(_view):
		_screens_due -= delta
		if _screens_due <= 0.0:
			_screens_due = 0.2
			var state: Dictionary = _view.craft_state()
			var roster: Array = _view.crew()
			for station in _view.stations():
				(station as CockpitStation).show_state(state, roster)
	if _contrails != null and is_instance_valid(_view):
		_contrails.lay({_view.entity: _view})
	# The same call FlightLevel makes, from the same lists: see ShotYard.draw_shots.
	if _rounds != null:
		_rounds.draw_shots(Sim.shots, _camera.global_position if _camera != null else Vector3.ZERO, delta,
			Sim.drawing_late(), Sim.take_shells_cued(), Sim.local_client_id())
	if not _running:
		return
	_elapsed += delta
	_work_the_scripts(delta)
	if is_instance_valid(_view):
		var y: float = _view.global_position.y
		if is_nan(_start_height):
			_start_height = y
		_lowest = minf(_lowest, y)
		_least_upright = minf(_least_upright, _view.global_basis.y.normalized().y)
	# The recording starts with Godot, so the opaque preparation slate is intentional.
	# Fade it only after the fleet and the camera are genuinely ready.
	_slate.modulate.a = clampf(1.0 - _elapsed / 0.45, 0.0, 1.0)
	if _elapsed >= _seconds:
		_running = false
		_judge_the_height()
		_judge_the_scripts()
		_finish()


func _read_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--kind="):
			_kind_name = argument.trim_prefix("--kind=").to_lower()
		elif argument.begins_with("--seconds="):
			_seconds = argument.trim_prefix("--seconds=").to_float()
		elif argument.begins_with("--shots="):
			_shots = argument.trim_prefix("--shots=").to_lower().split(",")
		elif argument.begins_with("--stills="):
			_stills = argument.trim_prefix("--stills=")
		elif argument.begins_with("--sweep-script="):
			for step in argument.trim_prefix("--sweep-script=").split(",", false):
				var said: PackedStringArray = step.split(":")
				if said.size() != 2:
					_fail("the_sweep_script_reads", step)
					continue
				var degrees: float = clampf(said[1].to_float(), SweepHandle.SWEEP_LOW, SweepHandle.SWEEP_HIGH)
				_sweep_script.append([said[0].to_float(), degrees])
				_asked_low = minf(_asked_low, degrees)
				_asked_high = maxf(_asked_high, degrees)
		elif argument.begins_with("--head-script="):
			for step in argument.trim_prefix("--head-script=").split(",", false):
				var said: PackedStringArray = step.split(":")
				if said.size() != 3:
					_fail("the_head_script_reads", step)
					continue
				_head_script.append([said[0].to_float(), Vector2(said[1].to_float(), said[2].to_float())])
		elif argument.begins_with("--boat="):
			var said: PackedStringArray = argument.trim_prefix("--boat=").split(":")
			if said.size() != 2:
				_fail("the_boat_reads", argument)
			else:
				_boat_at = Vector2(said[0].to_float(), said[1].to_float())
		elif argument.begins_with("--lock="):
			_lock_at = argument.trim_prefix("--lock=").to_float()
		elif argument.begins_with("--launch="):
			_launch_at = argument.trim_prefix("--launch=").to_float()
		elif argument.begins_with("--fire="):
			for step in argument.trim_prefix("--fire=").split(",", false):
				var said: PackedStringArray = step.split(":")
				if said.size() != 2:
					_fail("the_fire_script_reads", step)
					continue
				_fire_script.append([said[0].to_float(), said[1].to_float()])
		elif argument.begins_with("--stick-script="):
			for step in argument.trim_prefix("--stick-script=").split(",", false):
				var said: PackedStringArray = step.split(":")
				# FOUR FIELDS IS THE STICK ALONE, as it always was. SIX adds the THROTTLE and the BRAKE, which is what a
				# taxiing aeroplane is flown on: a ground-handling reel needs the lever and the pedals, not the stick
				# (lane/flightcore, for the tricycles going onto their wheels).
				if said.size() != 4 and said.size() != 6:
					_fail("the_stick_script_reads", step)
					continue
				_stick_script.append([said[0].to_float(), Vector3(said[1].to_float(), said[2].to_float(),
					said[3].to_float()).clampf(-1.0, 1.0),
					Vector2(said[4].to_float(), said[5].to_float()).clampf(0.0, 1.0) if said.size() == 6
						else Vector2(-1.0, -1.0)])
		elif argument.begins_with("--finish="):
			var asked_finish: String = argument.trim_prefix("--finish=").to_lower()
			if asked_finish not in ["plain", "fine"]:
				_fail("the_finish_is_known", asked_finish)
			_fine = asked_finish == "fine"
		elif argument.begins_with("--time="):
			var asked_time: String = argument.trim_prefix("--time=").to_lower()
			var named: int = Orrery.point_named(asked_time)
			var minutes: float = Orrery.point(named) if named >= 0 else Orrery.minutes_of(asked_time)
			if minutes < 0.0:
				_fail("the_time_is_known", asked_time)
			else:
				_clock = minutes
				_time = Daylight.nearest_preset(minutes)
	_kind = _kind_named(_kind_name)
	if _kind < 0:
		_fail("the_kind_is_known", _kind_name)
	if _seconds < 4.0 or _seconds > 60.0:
		_fail("the_duration_is_between_4_and_60_seconds", "%.1f" % _seconds)
	if _shots.is_empty():
		_fail("there_is_a_shot", "empty --shots")
	for shot in _shots:
		if shot not in ALLOWED_SHOTS:
			_fail("the_shot_is_known", shot)
	if _stills != "":
		DirAccess.make_dir_recursive_absolute(_stills)
	_sweep_script.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	_stick_script.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	_head_script.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	if not _sweep_script.is_empty() and _channel_range(_kind, Sim.Channel.SWEEP) <= 0:
		_fail("the_craft_has_wings_that_sweep", "%s has no sweep channel on its bus" % _kind_name)


func _prepare_stage() -> void:
	_bench = (load("res://tests/bench.tscn") as PackedScene).instantiate() as CockpitBench
	add_child(_bench)
	var entity: int = 0
	for waited in range(WAIT_FRAMES):
		entity = int(_bench.get("_entity"))
		_view = _bench.get("_view") as VehicleView
		if entity != 0 and _view != null:
			break
		await _frames(1)
	if _view == null:
		_fail("the_craft_is_drawn", "%s did not start on the fly bench" % _kind_name)
		return
	# The bench keeps flying and drawing the craft. Its diagnostic board and chase camera
	# are replaced by this reel's clean frame and camera.
	for child in _bench.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	var bench_camera := _bench.get("_chase") as Camera3D
	if bench_camera != null:
		bench_camera.current = false
	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.near = 0.2
	_camera.far = 24000.0
	add_child(_camera)
	_camera.current = true
	_build_scenery()
	_tune_light()
	_build_atmosphere()
	await _frames(SETTLE_FRAMES)
	if not is_instance_valid(_view):
		_fail("the_craft_stayed", "entity %d retired while settling" % entity)
		return

	var bounds: AABB = _drawn_bounds(_view)
	# Put the eye on the cabin, not merely on seat zero. The Cessna's current seat package
	# is known to be a metre aft of its real cockpit; a long tail makes that error dominate
	# an orbit. The front 28% station lands at the actual 172 cabin, centred between its
	# seats. Craft without seats use their drawn centre.
	_focus_local = bounds.get_center()
	if not _view.seats.is_empty():
		var seat: Vector3 = _view.to_local(_view.seat_anchor(0).global_position)
		_focus_local = Vector3(bounds.get_center().x, maxf(bounds.get_center().y, seat.y),
			bounds.position.z + bounds.size.z * 0.28)
	var aspect: float = get_viewport().get_visible_rect().size.aspect()
	var vertical_half: float = deg_to_rad(FOV * 0.5)
	var horizontal_half: float = atan(tan(vertical_half) * aspect)
	var half_wide: float = 0.0
	var half_high: float = 0.0
	for i in range(8):
		var from_focus: Vector3 = bounds.get_endpoint(i) - _focus_local
		half_wide = maxf(half_wide, Vector2(from_focus.x, from_focus.z).length())
		half_high = maxf(half_high, absf(from_focus.y))
	_distance = maxf(maxf(half_wide / tan(horizontal_half), half_high / tan(vertical_half)) / FILL, CLOSEST)
	_rise = minf(_distance * 0.14, maxf(half_high * 0.9, 0.75))
	_centre_local = bounds.get_center()
	if not _sweep_script.is_empty() or not _stick_script.is_empty() or not _head_script.is_empty():
		await _take_a_seat()
		if not _failures.is_empty():
			return
	if _boat_at != Vector2.INF:
		await _put_the_boat_on_the_river()
	_slate_label.text = "%s\n%s" % [_kind_name.to_upper(), " · ".join(_shots)]
	print("[craft_video] READY %s entity %d, drawn %s, camera %.1f m" % [
		_kind_name, entity, bounds.size, _distance])


## Update after the VehicleView moved but before rendering. A fast craft otherwise gets a
## camera one frame behind it, which is visible as vibration in a deterministic movie.
func _aim_camera() -> void:
	if not _running or _camera == null or not is_instance_valid(_view):
		return
	var centre: Vector3 = _view.global_transform * _focus_local
	var ahead: Vector3 = -_view.global_basis.z
	var state: Dictionary = Sim.current.get(_view.entity, {})
	var velocity: Vector3 = state.get("velocity", Vector3.ZERO)
	if Vector2(velocity.x, velocity.z).length() > 1.0:
		ahead = Vector3(velocity.x, 0.0, velocity.z).normalized()
	else:
		ahead.y = 0.0
		ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	var right: Vector3 = ahead.cross(Vector3.UP).normalized()
	var timing: Dictionary = _shot_at(_elapsed)
	var shot_index: int = int(timing["index"])
	_man_for(_shots[shot_index])
	var t: float = float(timing["t"])
	var shot_seconds: float = float(timing["seconds"])
	var shot: String = _shots[shot_index]
	if shot_index != _last_shot:
		_last_shot = shot_index
		print("[craft_video] SHOT %d/%d %s" % [shot_index + 1, _shots.size(), shot])
		if shot == "flyby":
			var speed: float = maxf(Vector2(velocity.x, velocity.z).length(), 20.0)
			_flyby_at = centre + ahead * speed * shot_seconds * 0.5 + right * _distance * 0.8 \
				+ Vector3.UP * _rise

	var camera_at: Vector3
	match shot:
		"orbit":
			# One unmistakable full revolution, attached to the moving craft so the compact
			# landscape supplies parallax while the craft stays the subject.
			var angle: float = lerpf(deg_to_rad(-45.0), deg_to_rad(315.0), _smooth(t))
			camera_at = centre + (ahead * cos(angle) + right * sin(angle)) * _distance \
				+ Vector3.UP * _rise
		"chase":
			# Ease from close behind to a wider shoulder without inheriting the craft's bank.
			var side: float = sin(t * PI) * _distance * 0.28
			camera_at = centre - ahead * lerpf(_distance * 0.72, _distance * 1.15, _smooth(t)) \
				+ right * side + Vector3.UP * lerpf(_rise * 0.75, _rise * 1.2, t)
		"flyby":
			# The camera is fixed in the world; only its pan follows. The craft must do the passing.
			camera_at = _flyby_at
		"hero":
			var angle: float = lerpf(deg_to_rad(125.0), deg_to_rad(45.0), _smooth(t))
			camera_at = centre + (ahead * cos(angle) + right * sin(angle)) * _distance * 0.92 \
				+ Vector3.UP * _rise * 0.8
		# THE SHOTS A SWING WING READS IN, all about the drawn middle of the craft rather than its cabin: a wing's sweep is
		# a shape seen from above, and a spoiler lies on top of the wing.
		"above":
			# High and behind, drifting a little across: the whole planform and the tail at once.
			var middle: Vector3 = _view.global_transform * _centre_local
			camera_at = middle - ahead * _distance * 0.46 + right * _distance * lerpf(-0.16, 0.16, _smooth(t)) \
				+ Vector3.UP * _distance * 0.36
			_camera.global_position = camera_at
			_camera.look_at(middle, Vector3.UP)
			return
		"plan":
			# Nearly straight down, the nose at the top of the frame: the sweep as the drawing shows it.
			var middle: Vector3 = _view.global_transform * _centre_local
			_camera.global_position = middle + Vector3.UP * _distance * 0.62 - ahead * _distance * 0.06
			_camera.look_at(middle, ahead)
			return
		"quarter":
			# A close three-quarter from ahead and above, turning slowly towards the beam.
			var middle: Vector3 = _view.global_transform * _centre_local
			var angle: float = lerpf(deg_to_rad(38.0), deg_to_rad(62.0), _smooth(t))
			camera_at = middle + (ahead * cos(angle) + right * sin(angle)) * _distance * 0.50 \
				+ Vector3.UP * _distance * 0.26
			_camera.global_position = camera_at
			_camera.look_at(middle, Vector3.UP)
			return
		"tail":
			# Close, high and behind, swinging from the port quarter to the starboard: both wings' tops, both
			# tailplanes and both rudders in one frame.
			var middle: Vector3 = _view.global_transform * _centre_local
			var angle: float = lerpf(deg_to_rad(215.0), deg_to_rad(145.0), _smooth(t))
			camera_at = middle + (ahead * cos(angle) + right * sin(angle)) * _distance * 0.36 \
				+ Vector3.UP * _distance * 0.19
			_camera.global_position = camera_at
			_camera.look_at(middle - ahead * 1.5, Vector3.UP)
			return
		# THE CHIN GUN'S SHOTS (lane/apache): close under the nose from the port bow, where the turret is seen turning;
		# and from the GUNNER'S OWN EYE, turned by his scripted look, where the helmet sight draws its cross and ring.
		"chin":
			var trunnion: Vector3 = _view.global_transform * (Sim.gun_of(_kind, 0).get("at", Vector3.ZERO) as Vector3)
			_camera.global_position = trunnion + ahead * 5.5 - right * 4.0 + Vector3.UP * 0.9
			_camera.look_at(trunnion + ahead * 0.6 + Vector3.UP * 0.3, Vector3.UP)
			return
		"gunner":
			var poses: Array = Sim.geometry_of(_kind).get("seat_poses", [])
			var seat_at: Vector3 = (poses[_seated] as Dictionary).get("position", Vector3.ZERO) if _seated >= 0 \
				and _seated < poses.size() else Vector3.ZERO
			var eye: Vector3 = _view.global_transform * (seat_at + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0))
			_camera.global_transform = Transform3D(_view.global_basis * Basis(_look_quat()), eye)
			return
		# THE HELLFIRE, from behind and above it, looking along its flight: before the launch, from behind the Apache
		# toward the boat; once it has ended, held where it last was, so the burst is seen from the missile's last place.
		"missile":
			var newest: Dictionary = {}
			for m in Sim.missiles:
				if bool((m as Dictionary).get("flying", false)):
					newest = m
			if not newest.is_empty():
				var at: Vector3 = newest.get("position", Vector3.ZERO)
				var going: Vector3 = (newest.get("velocity", Vector3.FORWARD) as Vector3).normalized()
				var eye: Vector3 = at - going * 9.0 + Vector3.UP * 2.2
				_missile_camera = Transform3D(Basis.looking_at(at + going * 40.0 - eye, Vector3.UP), eye)
				_missile_seen = true
			elif not _missile_seen:
				var boat: Vector3 = _boat_view.global_position if _boat_view != null else centre + ahead * 1000.0
				var from: Vector3 = _view.global_position - (boat - _view.global_position).normalized() * 18.0 \
					+ Vector3.UP * 4.0
				_missile_camera = Transform3D(Basis.looking_at(boat - from, Vector3.UP), from)
			_camera.global_transform = _missile_camera
			return
		"astern":
			# LOW AND DEAD ASTERN, a little over the water: the wings edge on, so a bank reads as a tilted horizon line
			# through the tips and a float in the water is seen going in (lane/floats, the Savoia under a held stick).
			var middle: Vector3 = _view.global_transform * _centre_local
			camera_at = middle - ahead * _distance * 0.50 + Vector3.UP * _distance * 0.05
			_camera.global_position = camera_at
			_camera.look_at(middle + ahead * 2.0, Vector3.UP)
			return
		_:
			return
	_camera.global_position = camera_at
	_camera.look_at(centre, Vector3.UP)


## One frame from the middle of each shot, read after that exact frame was drawn. These are
## both a contact sheet for choosing a reel and evidence that a successful movie was not
## 300 frames of a loading slate.
func _save_still_after_draw() -> void:
	if not _running or _stills == "" or _shots.is_empty():
		return
	var timing: Dictionary = _shot_at(_elapsed)
	var shot_index: int = int(timing["index"])
	var t: float = float(timing["t"])
	if t < 0.5 or _stills_saved.has(shot_index):
		return
	var shot: String = _shots[shot_index]
	var path: String = _stills.path_join("%02d-%s.png" % [shot_index + 1, shot])
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	if error == OK:
		_stills_saved[shot_index] = true
		print("[craft_video] STILL %s" % path)
		for sight in _view.find_children("HelmetSight", "HelmetSight", true, false):
			print("[craft_video] HELMET drawn %s, gun on %s" % [(sight as HelmetSight).visible, (sight as HelmetSight).on])
	else:
		_fail("the_%s_still_is_saved" % shot, "%s: error %d" % [path, error])


func _drawn_bounds(view: VehicleView) -> AABB:
	var into_craft: Transform3D = view.global_transform.affine_inverse()
	var box := AABB()
	var any: bool = false
	for node in view.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.mesh == null or not drawn.is_visible_in_tree():
			continue
		var into: Transform3D = into_craft * drawn.global_transform
		for surface in range(drawn.mesh.get_surface_count()):
			var arrays: Array = drawn.mesh.surface_get_arrays(surface)
			if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var stride: int = maxi(1, vertices.size() / SAMPLES_PER_SURFACE)
			for i in range(0, vertices.size(), stride):
				var at: Vector3 = into * vertices[i]
				box = box.expand(at) if any else AABB(at, Vector3.ZERO)
				any = true
	if not any:
		var half: Vector3 = Sim.geometry_of(view.kind).get("extents", Vector3.ONE)
		box = AABB(-half, half * 2.0)
	return box


## Unequal cuts: the orbit gets enough screen time to read as a full revolution, while a
## flyby is valuable precisely because it is brief. Returns the selected shot and its
## normalized local clock for any requested ordering or subset.
func _shot_at(at: float) -> Dictionary:
	var total_weight: float = 0.0
	for shot in _shots:
		total_weight += _shot_weight(shot)
	var cursor: float = 0.0
	for i in range(_shots.size()):
		var length: float = _seconds * _shot_weight(_shots[i]) / total_weight
		if at < cursor + length or i == _shots.size() - 1:
			return {"index": i, "t": clampf((at - cursor) / length, 0.0, 1.0), "seconds": length}
		cursor += length
	return {"index": _shots.size() - 1, "t": 1.0, "seconds": 0.0}


static func _shot_weight(shot: String) -> float:
	match shot:
		"orbit": return 5.0
		"flyby": return 1.25
		"tail": return 1.8
		_: return 1.0


## A PATROL BOAT ON THE STAGE'S RIVER, for the Hellfire reel: its sea put at the river's surface as `--afloat` puts a
## flying boat's, spawned on the server, and drawn by a view of its own once it is on the wire -- the bench draws only
## its own craft.
func _put_the_boat_on_the_river() -> void:
	Sim.set_handling(Sim.Kind.GUNBOAT, {"water_level": CockpitBench.STAGE_WATER})
	var waterline: float = float(Sim.geometry_of(Sim.Kind.GUNBOAT).get("waterline", 0.0))
	var made: int = int(Sim.spawn_vehicle(Sim.Kind.GUNBOAT, Vector3(_boat_at.x, CockpitBench.STAGE_WATER - waterline,
		_boat_at.y), 0.0, Vector3.ZERO))
	if made == 0:
		_fail("the_boat_is_on_the_river", "no boat")
		return
	for i in range(240):
		await get_tree().physics_frame
		for entity in Sim.current:
			if int((Sim.current[entity] as Dictionary).get("kind", -1)) == Sim.Kind.GUNBOAT:
				_boat_view = load("res://objects/vehicles/vehicle_view.tscn").instantiate() as VehicleView
				add_child(_boat_view)
				_boat_view.setup(int(entity), Sim.Kind.GUNBOAT)
				print("[craft_video] BOAT on the river at %s" % _boat_at)
				return
	_fail("the_boat_is_on_the_river", "never arrived")


## THE GUNNER'S STATION, FITTED ONLY WHILE HIS OWN EYE IS THE CAMERA. The bench flies an empty craft, so there is no
## station and so no helmet sight; `man` is the same call the level makes when somebody sits down, and it builds the
## station from its package with the HelmetSight in it. Not for the outside shots: the sight follows whichever camera is
## drawing, and would have hung its cross in the middle of a picture of the nose.
func _man_for(shot: String) -> void:
	var wanted: bool = shot == "gunner" and _seated >= 0
	if wanted == _manned:
		return
	_manned = wanted
	_view.man([_seated] if wanted else [], -1)


## THE GUNNER'S LOOK AS HIS HEADSET WOULD REPORT IT, in the seat's frame: yaw to port, then pitch up.
func _look_quat() -> Quaternion:
	return Quaternion(Vector3.UP, deg_to_rad(_head_now.x)) * Quaternion(Vector3.RIGHT, deg_to_rad(_head_now.y))


## ---- the scripted crew ------------------------------------------------------------------------------------------

## SEAT THIS PLAYER where the scripts need a hand: the pilot's seat for a stick, else the first seat that does not fly,
## so the autopilot goes on flying (`drive_vehicle` hands a craft to its autopilot only while no flying seat is taken).
## PARKED, so taking the pilot's seat of a craft on its wheels does not launch it.
func _take_a_seat() -> void:
	var server_id: int = int(_bench.get("on_server"))
	var poses: Array = Sim.geometry_of(_kind).get("seat_poses", [])
	var seat: int = 0 if not _stick_script.is_empty() else -1
	# A SCRIPTED HEAD SITS IN THE SEAT WHOSE GUN FOLLOWS IT: the one the simulation marks `gun`, asked of the seat table.
	if not _head_script.is_empty():
		for i in range(poses.size()):
			if bool((poses[i] as Dictionary).get("gun", false)):
				seat = i
				break
	if seat < 0:
		for i in range(poses.size()):
			if not bool((poses[i] as Dictionary).get("flies", true)):
				seat = i
				break
	if seat < 0 or server_id == 0 or not bool(Sim.server.seat_client_parked(Sim.local_client_id(), server_id, seat)):
		_fail("the_scripted_hand_is_seated", "seat %d of server craft %d" % [seat, server_id])
		return
	_seated = seat
	await _frames(20)
	_build_caption()
	print("[craft_video] SEATED in seat %d of %s, sweep script %s, stick script %s" % [seat, _kind_name, _sweep_script,
		_stick_script])


## EACH STEP OF A SCRIPT AS ITS TIME COMES: the sweep asked for through the handle's own call, the stick eased toward
## where the script puts it and sent as this player's input frame every frame.
func _work_the_scripts(delta: float) -> void:
	if _seated < 0 or not is_instance_valid(_view):
		return
	while not _sweep_script.is_empty() and float(_sweep_script[0][0]) <= _elapsed:
		var degrees: float = _sweep_script.pop_front()[1]
		_view.propose(Sim.Channel.SWEEP, int(round(SweepHandle.fraction_of(degrees) * 255.0)))
		print("[craft_video] SWEEP asked for %.0f degrees at %.2f s" % [degrees, _elapsed])
	while not _stick_script.is_empty() and float(_stick_script[0][0]) <= _elapsed:
		var step: Array = _stick_script.pop_front()
		_stick_wanted = step[1]
		_levers_wanted = step[2]
		print("[craft_video] STICK to %s at %.2f s%s" % [_stick_wanted, _elapsed,
			"" if _levers_wanted.x < 0.0 else ", throttle %.2f brake %.2f" % [_levers_wanted.x, _levers_wanted.y]])
	# THE GUNNER'S HEAD, turned at a head's speed toward where the script looks, and the trigger in its windows: his
	# input frame, which the simulation lays the chin gun from (`slew_to_the_head`) and fires on.
	if not _head_script.is_empty() or _head_wanted != Vector2.ZERO or not _fire_script.is_empty() or _lock_at >= 0.0:
		while not _head_script.is_empty() and float(_head_script[0][0]) <= _elapsed:
			_head_wanted = _head_script.pop_front()[1]
			print("[craft_video] LOOK to %s at %.2f s" % [_head_wanted, _elapsed])
		_head_now = _head_now.move_toward(_head_wanted, HEAD_RATE * delta)
		var firing: bool = false
		for window in _fire_script:
			firing = firing or (_elapsed >= float(window[0]) and _elapsed < float(window[1]))
		# LOCK AND LAUNCH, each a press a tenth of a second long; the master arm thrown half a second before the launch,
		# through the bus as the switch at the seat throws it.
		var buttons: int = Sim.BUTTON_FIRE if firing else 0
		if _lock_at >= 0.0 and _elapsed >= _lock_at and _elapsed < _lock_at + 0.1:
			buttons |= Sim.BUTTON_LOCK
		if _launch_at >= 0.0 and not _armed and _elapsed >= _launch_at - 0.5:
			_armed = true
			_view.propose(Sim.Channel.MASTER, 1)
			print("[craft_video] MASTER ARM at %.2f s" % _elapsed)
		if _launch_at >= 0.0 and _elapsed >= _launch_at and _elapsed < _launch_at + 0.1:
			buttons |= Sim.BUTTON_LAUNCH
		Sim.set_input({"head": Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0), "head_basis": _look_quat(),
			"trigger": 1.0 if firing else 0.0, "buttons": buttons})
	if _seated == 0:
		_stick_now = _stick_now.move_toward(_stick_wanted, STICK_RATE * delta)
		var frame: Dictionary = {"roll": _stick_now.x, "pitch": _stick_now.y, "rudder": _stick_now.z}
		# AND THE LEVER AND THE PEDALS, where the script names them. 0.0 on the throttle means "let go" and leaves it
		# where it was, so a scripted idle is sent as the smallest thing that is not that.
		if _levers_wanted.x >= 0.0:
			frame["throttle"] = maxf(_levers_wanted.x, 0.002)
			frame["brake"] = _levers_wanted.y
		# AFLOAT, A HAND ON THE LEVER TOO, holding the bench's taxiing speed as `tests/ground_stick.gd` does: left
		# alone, the hull's drag stops the boat, and a stick with no water over its surfaces does nothing to show.
		if bool(_bench.get("afloat")):
			var moving: Vector3 = Sim.server.vehicle_state(int(_bench.get("on_server"))).get("velocity", Vector3.ZERO)
			var along: float = moving.dot(-_view.global_basis.z.normalized())
			frame["throttle"] = clampf(0.1 + (CockpitBench.TAXI_AFLOAT - along) * 0.3, 0.002, 1.0)
		Sim.set_input(frame)
	var systems: Dictionary = Sim.client.craft_systems(_view.entity)
	var has_sweep: bool = _channel_range(_kind, Sim.Channel.SWEEP) > 0
	var sweep: float = SweepHandle.sweep_of(float(systems.get("sweep", 0)) / 255.0)
	if has_sweep:
		_sweeps_seen = Vector2(minf(_sweeps_seen.x, sweep), maxf(_sweeps_seen.y, sweep))
	if _caption != null:
		var linkage: Dictionary = Sim.client.crew_controls(_view.entity)
		var stick: Vector2 = linkage.get("linked_stick", Vector2.ZERO)
		var line: String = "F-14D     WING SWEEP %2.0f°" % sweep
		if not has_sweep:
			line = _kind_name.to_upper()
		# AFLOAT, THE BANK, off the drawn craft: what a flying boat's reel under a held stick is about (lane/floats).
		if bool(_bench.get("afloat")):
			var b: Basis = _view.global_basis.orthonormalized()
			line += "     BANK %+4.0f°" % rad_to_deg(atan2(-b.x.y, b.y.y))
		if _seated == 0:
			line += "     STICK  roll %+.1f  pitch %+.1f     PEDALS %+.1f" % [stick.x, stick.y,
				float(linkage.get("linked_rudder", 0.0))]
		# THE LOOK AND THE GUN, the gun off the replicated mount: the lag the chin gun's reel is about, as numbers.
		var turrets: Array = Sim.vehicle_turrets(_view.entity)
		if not _head_script.is_empty() or _head_wanted != Vector2.ZERO:
			var gun: Vector2 = turrets[0] if not turrets.is_empty() else Vector2.ZERO
			line = "AH-64D     LOOK %+4.0f° %+3.0f°     GUN %+4.0f° %+3.0f°" % [_head_now.x, _head_now.y,
				rad_to_deg(gun.x), rad_to_deg(gun.y)]
		# AND THE SEEKER, off the craft's published locks: what the Hellfire reel is about.
		if _lock_at >= 0.0:
			var said: String = "SEARCH"
			for row in (Sim.locks_for(_view.entity) as Array):
				if int((row as Dictionary).get("seat", -1)) == _seated:
					said = ["NONE", "SEARCH", "LOCKING", "LOCKED", "LOST"][clampi(int(row.get("phase", 0)), 0, 4)]
			line = "AH-64D     LOOK %+4.0f° %+3.0f°     HELLFIRE %s     IN THE AIR %d" % [_head_now.x, _head_now.y, said,
				Sim.missiles.size()]
		_caption.text = line


## A LOWER THIRD THAT READS THE BUS, so what the caption says is what the craft says: the wings off CraftSystems and the
## stick and pedals off the linkage, never the script's own wishes.
func _build_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 24)
	_caption.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	_caption.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05))
	_caption.add_theme_constant_override("outline_size", 6)
	_caption.position = Vector2(28.0, get_viewport().get_visible_rect().size.y - 64.0)
	layer.add_child(_caption)


## THE SCRIPT WAS SEEN ON THE BUS: a sweep script that did not carry the wings to both ends of what it asked for has made
## a film of wings not moving. Judged on the bus the caption reads, to within 2 degrees.
func _judge_the_scripts() -> void:
	# A PARKED CRAFT STAYS ON ITS WHEELS. The first surfaces take rolled an F-14 on to its back with the stick, and
	# every other check passed: its height never changed.
	if bool(_bench.get("parked")) and _least_upright < cos(deg_to_rad(8.0)):
		_fail("the_parked_craft_stays_upright", "tipped %.1f degrees" % rad_to_deg(acos(clampf(_least_upright, -1.0, 1.0))))
	# AND A FLYING BOAT ON THE WATER STAYS ON ITS FLOATS: a held stick may put a wing down on its float, and no further.
	# Before its floats (main 6bb8d96c) a full stick rolled the Savoia over, which is the film this is for.
	if bool(_bench.get("afloat")) and _least_upright < cos(deg_to_rad(AFLOAT_TILT)):
		_fail("the_afloat_craft_stays_on_its_floats", "tipped %.1f degrees" % rad_to_deg(acos(clampf(_least_upright, -1.0,
			1.0))))
	if _seated < 0 or _sweeps_seen.x == INF:
		return
	print("[craft_video] SWEEP seen from %.1f to %.1f degrees" % [_sweeps_seen.x, _sweeps_seen.y])
	if _asked_low <= _asked_high and (_sweeps_seen.x > _asked_low + 2.0 or _sweeps_seen.y < _asked_high - 2.0):
		_fail("the_wings_followed_the_script", "asked %.0f to %.0f, seen %.1f to %.1f" % [_asked_low, _asked_high,
			_sweeps_seen.x, _sweeps_seen.y])


static func _channel_range(kind: int, channel: int) -> int:
	for row in Sim.schema_of(kind).get("channels", []) as Array:
		if int((row as Dictionary).get("channel", -1)) == channel:
			return int((row as Dictionary).get("range", 0))
	return 0


## A deliberately quiet set, not the island: broad ground, a river and low-poly ridges
## 120 m under the height the fly bench holds its craft at. Sixteen kilometres is much larger than a
## reel's flight, so no orbit or flyby can reveal a hard edge and fall into the clear colour.
func _build_scenery() -> void:
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(16000.0, 8.0, 16000.0)
	_add_mesh("Ground", ground_mesh, Vector3(0.0, STAGE_GROUND - 4.0, -4000.0),
		_material(Color(0.16, 0.28, 0.16)))
	# THE RIVER IS WATER, drawn as the sea is (WaterSurface) on the reel's finish: until 2026-09-17 it was a flat blue
	# box, and "let's make sure we always use the good water shader" covers the reel's stage.
	var river_mesh := PlaneMesh.new()
	river_mesh.size = Vector2(180.0, 16000.0)
	var river := _add_mesh("River", river_mesh, Vector3(CockpitBench.RIVER_X, CockpitBench.STAGE_WATER, -4000.0), null)
	# INLAND: a river gets none of the sea's swell, chop or wind-sea, wherever the stage stands (WaterSurface).
	WaterSurface.wear(river, _fine, null, true)

	var earth: StandardMaterial3D = _material(Color(0.32, 0.23, 0.14))
	var hill_count: int = 32 if _fine else 20
	for i in range(hill_count):
		var hill := CylinderMesh.new()
		var height: float = 55.0 + float((i * 29) % 115)
		hill.height = height
		hill.bottom_radius = 75.0 + float((i * 17) % 90)
		hill.top_radius = hill.bottom_radius * (0.18 + float(i % 3) * 0.12)
		hill.radial_segments = 7 + i % 3
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var x: float = side * (320.0 + float((i * 173) % 1500))
		var z: float = 1800.0 - float(i) * (8200.0 / maxf(hill_count - 1, 1))
		_add_mesh("Mesa%02d" % i, hill, Vector3(x, STAGE_GROUND + height * 0.5, z), earth)


## The same presentation pieces the island uses, without the island: LiftYard's lit cloud
## shaders and ContrailYard's GPU-aged wingtip ribbons, sharing MissileYard's clock exactly
## as FlightLevel wires them. This is why a demo retains the game's atmosphere instead of
## looking like a model viewer with spheres in it.
func _build_atmosphere() -> void:
	_missiles = MissileYard.new()
	_missiles.name = "TrailClock"
	add_child(_missiles)
	_contrails = ContrailYard.new()
	_contrails.name = "Contrails"
	_contrails.follow(_missiles)
	add_child(_contrails)
	_contrails.show_daylight(DaylightTuning.look_at(_clock))
	var bursts := BurstYard.new()
	bursts.name = "Bursts"
	add_child(bursts)
	_rounds = ShotYard.new()
	_rounds.name = "Shots"
	_rounds.bursts = bursts
	add_child(_rounds)

	_lift = LiftYard.new()
	_lift.name = "Clouds"
	add_child(_lift)
	var zones: Array[Dictionary] = []
	var cloud_count: int = 11 if _fine else 7
	for i in range(cloud_count):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		zones.append({
			"position": Vector3(side * (460.0 + float((i * 137) % 900)), STAGE_GROUND,
				1200.0 - float(i) * (6800.0 / maxf(cloud_count - 1, 1))),
			"radius": 85.0 + float((i * 31) % 80),
			"strength": 3.0 + float(i % 4) * 0.35,
			"top": 650.0 + float((i * 47) % 170),
		})
	_lift.show_lift(zones, Vector3(3.0, 0.0, -1.0))
	_lift.show_daylight(DaylightTuning.look_at(_clock))


func _tune_light() -> void:
	var background := Color(0.38, 0.58, 0.78)
	var ambient := Color(0.58, 0.66, 0.76)
	var sun_colour := Color(1.0, 0.93, 0.78)
	if _time == DaylightTuning.When.EVENING:
		background = Color(0.34, 0.25, 0.42)
		ambient = Color(0.44, 0.32, 0.5)
		sun_colour = Color(1.0, 0.55, 0.3)
	elif _time == DaylightTuning.When.NIGHT:
		background = Color(0.015, 0.025, 0.075)
		ambient = Color(0.12, 0.17, 0.3)
		sun_colour = Color(0.34, 0.45, 0.72)
	for child in _bench.get_children():
		if child is WorldEnvironment:
			var environment: Environment = (child as WorldEnvironment).environment
			var sky_material := ProceduralSkyMaterial.new()
			sky_material.sky_top_color = background.darkened(0.12)
			sky_material.sky_horizon_color = background.lightened(0.24)
			sky_material.ground_horizon_color = background.lightened(0.18)
			sky_material.ground_bottom_color = Color(0.09, 0.12, 0.08)
			sky_material.sun_angle_max = 4.0
			var sky := Sky.new()
			sky.sky_material = sky_material
			environment.sky = sky
			environment.background_mode = Environment.BG_SKY
			environment.ambient_light_color = ambient
			environment.ambient_light_energy = 1.0 if _time != DaylightTuning.When.NIGHT else 0.55
		elif child is DirectionalLight3D:
			(child as DirectionalLight3D).light_color = sun_colour
			(child as DirectionalLight3D).light_energy = 1.15 if _time != DaylightTuning.When.NIGHT else 0.35


func _add_mesh(label: String, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)
	return node


static func _material(colour: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = metallic
	material.roughness = 0.82
	return material


func _build_slate() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_slate = ColorRect.new()
	_slate.color = Color(0.012, 0.018, 0.027, 1.0)
	_slate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_slate)
	_slate_label = Label.new()
	_slate_label.text = "%s\ncinematic flight demo" % _kind_name.to_upper()
	_slate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_slate_label.add_theme_font_size_override("font_size", 30)
	_slate_label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.96))
	_slate_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slate.add_child(_slate_label)


func _first_of(kind: int) -> int:
	var first: int = 0
	for entity in Sim.current:
		if int((Sim.current[entity] as Dictionary).get("kind", -1)) == kind \
				and (first == 0 or int(entity) < first):
			first = int(entity)
	return first


static func _kind_named(wanted: String) -> int:
	for kind in range(Sim.Kind.size()):
		if Sim.kind_name(kind) == wanted:
			return kind
	return -1


static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


## THE CRAFT STAYED UP, and above the stage: it ends within HEIGHT_KEPT_WITHIN of where it started and is never drawn
## below the stage's ground.
func _judge_the_height() -> void:
	if not is_instance_valid(_view) or is_nan(_start_height):
		return
	var end: float = _view.global_position.y
	print("[craft_video] HEIGHT started %.1f m, ended %.1f m, lowest %.1f m, stage ground %.0f m" % [_start_height, end,
		_lowest, STAGE_GROUND])
	if absf(end - _start_height) > HEIGHT_KEPT_WITHIN or _lowest <= STAGE_GROUND:
		_fail("the_craft_keeps_its_height_over_the_stage", "started %.1f, ended %.1f, lowest %.1f over ground %.0f"
			% [_start_height, end, _lowest, STAGE_GROUND])


func _fail(label: String, detail: String) -> void:
	print("[craft_video] FAIL %s (%s)" % [label, detail])
	_failures.append(label)


func _finish() -> void:
	if _contrails != null and is_instance_valid(_view):
		print("[craft_video] CONTRAIL strength %.2f, %d segments" % [
			_contrails.strength_of(_view.entity), _contrails.segments_behind(_view.entity)])
	_view = null
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
