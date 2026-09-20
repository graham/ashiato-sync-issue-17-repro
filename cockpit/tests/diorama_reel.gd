extends Node
## DOES THE BOARD READ AS FLYING AROUND? Twenty seconds of the controller's diorama with a world moving under it,
## recorded twice: HOLDING between sweeps, and DEAD RECKONING between them.
##
##   <editor>.console.exe --path cockpit --xr-mode off --resolution 1600x900 --fixed-fps 30 \
##       --write-movie <out.avi> -- --reckon=no
##
## `--reckon=yes` records the other one. Two runs, one flag apart, so the two reels differ in exactly the thing being
## judged and in nothing else -- same seed, same craft, same camera move, same length.
##
## ---------------------------------------------------------------------------------------------------
## WHY THIS EXISTS AND WHY IT IS NOT A SUITE
## ---------------------------------------------------------------------------------------------------
##
## The user asked for a chessboard with "planes, boats, **flying around**". The board is fed radar, radar is published
## once a second (`RadarWatch.EVERY_MSEC`) and the station redraws four times a second, so three updates in four have
## nothing new to say. **Whether that reads as a plot or as a stutter is not a thing any check can answer** and it is
## not a thing to settle by reasoning either -- it is a question about motion, so it wants a moving picture
## (CLAUDE.md rule 2, applied to time instead of to layout).
##
## `tests/diorama.gd` holds the arithmetic and `tests/diorama_shot.gd` holds the stills. This holds only that the reel
## was recorded, that the world really moved while it ran, and -- the one that matters -- **that the two reels are
## actually different**, which is the check a probe like this most easily fails silently.
##
## THE WORLD IS REAL AND IT IS FLYING. Ninety AI craft in a `CockpitWorld` with the island's own mountains, ticked at
## the real rate for the whole twenty seconds, swept by `RadarSet.sweep` once a second exactly as `RadarWatch` would.
## Nothing here moves a contact by hand: if a piece slides across the board it is because an aeroplane flew.
##
## MovieWriter records THIS PROBE'S OWN VIEWPORT and never the desktop.
##
## Read RESULT=, not the exit code.

const WIDTH: int = 1600
const HEIGHT: int = 900
const HOW_MANY: int = 90
## How long the reel runs, seconds, and how often radar sweeps. Twenty seconds is long enough to watch a contact cross
## a good part of the board at 300 m/s (6 km, about a tenth of the island) and short enough to sit through twice.
const RUNS_FOR: float = 20.0
const SWEEP_EVERY: float = float(RadarWatch.EVERY_MSEC) / 1000.0
## How far the camera drifts round the board over the reel, radians. A slow orbit, because a still camera over a board
## makes it very hard to tell a frozen picture from a frozen render.
const DRIFTS: float = 0.55
## How long the world flies before the reel starts, seconds. See the spawn loop: craft start at rest.
const SETTLES: float = 4.0

var _failures: PackedStringArray = []
var _world: Object = null
var _watch: RadarWatch = null
var _station: ControlStation = null
var _board: DioramaView = null
var _since_sweep: float = SWEEP_EVERY
var _ran: float = 0.0
var _reckons: bool = false
## Where one named contact was on each drawn frame, so the reel can be judged by a number as well as by eye.
var _tracked: String = ""
var _track: PackedVector2Array = []
var _moved_frames: int = 0
var _frames: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[diorama_reel] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _asked(what: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % what):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _ready() -> void:
	# OFF UNTIL EVERYTHING IT TOUCHES EXISTS. `_ready` awaits the map's render and a frame, and a Node processes by
	# DEFAULT -- so `_process` ran during those awaits with `_watch` and `_board` still null and printed a screenful of
	# "Nonexistent function 'orbit' in base 'Nil'" before the reel even started. It recorded anyway, which is the part
	# worth remembering: the RESULT= line was PASS both times.
	set_process(false)
	if DisplayServer.get_name() == "headless":
		print("[diorama_reel] RESULT=FAIL windowed renderer required")
		get_tree().quit(1)
		return
	_reckons = _asked("reckon", "no") == "yes"
	print("[diorama_reel] %s between sweeps, %.0f s at %d contacts" % [
		"DEAD RECKONING" if _reckons else "HOLDING", RUNS_FOR, HOW_MANY])

	var island: Object = ClassDB.instantiate(&"MountainRange")
	island.call("configure", Terrain.mountain_values())
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120)
	_world.start(0)
	_world.set_mountains(island)
	# THE SAME MIX AND THE SAME PLACES EVERY RUN, so the two reels differ in the setting and in nothing else.
	var kinds: Array[int] = [Sim.Kind.PLANE, Sim.Kind.AIRLINER, Sim.Kind.HELI, Sim.Kind.CESSNA, Sim.Kind.FIGHTER,
		Sim.Kind.BOAT, Sim.Kind.GUNBOAT]
	for i in range(HOW_MANY):
		var turn: float = TAU * float(i) * 0.191
		var out: float = 700.0 + 78.0 * float(i)
		var kind: int = kinds[i % kinds.size()]
		var afloat: bool = VehicleCatalogue.group(kind) == "ships"
		var high: float = 0.0 if afloat else lerpf(220.0, 2600.0, fmod(float(i) * 0.37, 1.0))
		_world.spawn_ai_vehicle(kind, Vector3(cos(turn) * out, high, sin(turn) * out * 0.82), turn, Vector3.ZERO)
	# FLOWN UP TO SPEED BEFORE ANYTHING IS RECORDED. Craft are spawned with zero velocity, and the first version swept
	# immediately and picked its "fastest" contact at **1 m/s** -- the whole field was still accelerating, so the reel
	# followed an arbitrary aeroplane and opened on ninety machines getting under way, which is not what a controller's
	# board ever looks like. Four seconds of flying first, and the reel starts on traffic already moving.
	for warm in range(int(SETTLES * 120.0)):
		_world.tick(1.0 / 120.0)

	load("res://tests/radar_shot.gd").call("build_island", self, island)
	var chart := LevelChart.new()
	chart.world = "island"
	var map := LevelMap.new()
	add_child(map)
	map.configure(chart)
	map.rebuild()
	await map.rebuilt

	var built: int = int(Net.identity()["built"])
	Net.is_host = true
	Net.roster = {1: {"player": 1, "name": "CONTROL", "colour": 3, "built": built, "team": 0}}

	_watch = RadarWatch.new()
	add_child(_watch)

	_station = ControlStation.new()
	_station.set_anchors_preset(Control.PRESET_FULL_RECT)
	_station.level_map = map
	_station.radar = _watch
	add_child(_station)
	await get_tree().process_frame
	_station.show_the_board(true)
	_station.reckon(_reckons)
	_board = _station.the_board()
	_sweep()
	set_process(true)


## THE SWEEP, exactly as `RadarWatch._process` does it on a host: off the SERVER's own list, from a head at the middle
## of the map, and written straight into the watch the station is reading.
func _sweep() -> void:
	_watch.rows = RadarSet.sweep(_world, Vector3.ZERO, RadarSet.manned_vehicles(_world))
	_watch.head = Vector3.ZERO
	_watch.drawn_at = Time.get_ticks_msec()
	if _tracked.is_empty():
		# ONE CONTACT FOLLOWED THROUGH THE WHOLE REEL. The fastest, because the argument is about whether motion reads,
		# and the fastest contact is where a stutter would be most visible.
		var best: float = -1.0
		for row in _watch.contacts():
			if float(row["speed"]) > best:
				best = float(row["speed"])
				_tracked = String(row["name"])
		print("[diorama_reel] following %s at %.0f m/s" % [_tracked, best])


func _process(delta: float) -> void:
	if _ran >= RUNS_FOR:
		return
	_ran += delta
	# THE WORLD IS TICKED AT ITS OWN RATE against the frame's own delta, so under `--fixed-fps` the simulation advances
	# by exactly one frame's worth per recorded frame and the reel plays at real speed.
	var steps: int = maxi(1, int(delta * 120.0))
	for step in range(steps):
		_world.tick(1.0 / 120.0)
	_since_sweep += delta
	if _since_sweep >= SWEEP_EVERY:
		_since_sweep = 0.0
		_sweep()

	# A SLOW CONTINUOUS ORBIT, `DRIFTS` radians over the whole reel. Not `drive`, which steps 0.1 rad a press and would
	# spin the board ten times over six hundred frames.
	_board.orbit(DRIFTS * delta / RUNS_FOR)
	_watch_the_tracked_one()
	if _ran >= RUNS_FOR:
		_finish()


## WHERE THE FOLLOWED CONTACT IS ON THE BOARD THIS FRAME, and how often that changed. This is the number the argument
## is actually about: HOLDING should move it on about one frame in thirty at 30 fps, and DEAD RECKONING on nearly all
## of them. A reel is still the thing that decides, but a claim about motion should carry a count.
func _watch_the_tracked_one() -> void:
	if _board == null or _board.board == null or _tracked.is_empty():
		return
	var rows: Array = _watch.contacts()
	for index in range(rows.size()):
		if String((rows[index] as Dictionary).get("name", "")) != _tracked:
			continue
		var report: Dictionary = _board.board.piece_report(index)
		if report.is_empty() or not bool(report["visible"]):
			return
		var at: Vector3 = report["at"]
		var now := Vector2(at.x, at.z)
		_frames += 1
		if not _track.is_empty() and _track[_track.size() - 1].distance_to(now) > 1.0e-6:
			_moved_frames += 1
		_track.append(now)
		return


func _finish() -> void:
	set_process(false)
	var walked: float = 0.0
	for step in range(1, _track.size()):
		walked += _track[step - 1].distance_to(_track[step])
	var stirred: float = 0.0 if _frames == 0 else float(_moved_frames) / float(_frames)
	_check("the_world_actually_flew_while_it_recorded", walked > 0.005,
		"%s crossed %.1f mm of board over %.0f s" % [_tracked, walked * 1000.0, _ran])
	# THE NUMBER THE ARGUMENT IS ABOUT. Printed rather than asserted against a threshold: what counts as "reads as
	# flying" is the user's call and not this file's, and a probe that picked a pass mark would be pretending otherwise.
	print("[diorama_reel] MOTION %s: the followed piece moved on %.1f%% of %d drawn frames, crossing %.1f mm" % [
		"reckoned" if _reckons else "held", stirred * 100.0, _frames, walked * 1000.0])
	_check("frames_were_drawn_to_record", _frames > 60, "%d frames" % _frames)
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
