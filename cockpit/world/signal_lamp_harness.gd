extends Node
class_name SignalLampHarness
## FOR A HARNESS: flash this seat's signal lamp with the desk's REAL keys at stated times, and write down every change in
## every lamp this machine can see. Added by the flight level only when a flag below is on the command line; a player never
## has one. `tests/lamp_peers.gd` runs two machines with it and reads both logs.
##
##   --flash=WHEN:COLOUR:HOLD,...  WHEN is SECONDS after this machine first sees another player flying; COLOUR is white,
##                                 red or green; HOLD is how many seconds the key is held down. The key is pressed as a
##                                 player at a desk presses it: an InputEventKey with both key codes set, through
##                                 `Input.parse_input_event`, which the rig reads as `lamp_white` / `lamp_red` /
##                                 `lamp_green` (`PilotRig.DESK_KEYS`). Nothing here touches the lamp.
##   --place-lamp=WHEN             THIS SEAT'S LAMP PLACED, WHEN seconds on the same clock as --flash: off the parts bin, by the
##                                 signal the BUILD tab's "+ SIGNAL LAMP" button emits (`ClipboardPage.chose_part`). No
##                                 seat has one until then (lane/lampopt, 2026-09-19). Printed as LAMP_PLACED.
##   --bin-lamp=WHEN               and taken out again, by the bin's own step (`PilotRig.bin_the_part`), since a desk has no
##                                 hand to hold it to the bin. Printed as LAMP_BINNED. NOT the BUILD tab's RESET: a child
##                                 started on the game's scene writes the PLAYER's `user://cockpits`, and RESET deletes the
##                                 saved layout there (`CockpitLayout.folder_for`).
##   --lamps=1                     and a line on every physics frame that any lamp's colour or holder changed:
##                                 `LAMP ms=... client=... seat=... mine=... colour=... holder=... at=x,y,z aim=x,y,z`,
##                                 the pose in the lamp's SEAT's frame; and `LAMP_KEY ms=... colour=... down=...` for every
##                                 key this harness pressed or let go; and `LAMP_SEEN ms=... client=... seat=... present=0|1`
##                                 whenever another player's seat gains or loses its lamp on this machine.
##
## MS IS THE WALL CLOCK, which both processes on one machine share, so a press on one and the change on the other are
## comparable. The children are run WITHOUT `--fixed-fps` for that reason: under it each process steps as fast as it can
## and its frames are not the wall's (`WingSweepHarness` has the measurement).
##
## AND FOR PICTURES (`tools/lamp_session.ps1`):
##   --stage=METRES        ON THE HOST, once another player is flying: both into a plane each, 600 m over the runway,
##                         abreast METRES apart (`spawn_pilot`, which has a server bug this works round -- see
##                         `_stage_when_asked`); `--stage-tower=1` moves only the other player, passing over the host on
##                         the airfield. Printed as LAMP_STAGED.
##   --look-at-other=1     every physics frame, the desk's view turned to the other player's craft -- so a desk-held lamp
##                         (`SignalLamp.desk_pose`) is aimed at them, and a watcher is looking at the lamp.
##   --shots=DIR           windowed: a picture whenever the OTHER player's lamp changes, a few frames after, and one of
##                         this machine's own cockpit when staged; `--reel=SECONDS` also writes the window from the
##                         staging for that long, as `reel/<ms>.jpg` named by milliseconds since, for the driver to make a
##                         video of: the middle half of the window, where the other craft is, as a JPEG no more often than
##                         every 33 ms. A 1600x900 PNG every frame held the
##                         game to 4 frames a second, its simulation fell behind the wall and the host's flashes had not
##                         arrived when the reel ended (2026-09-18). NOT RECORDED FROM OUTSIDE: FFmpeg's gdigrab sees a D3D12
##                         window as grey, and a desktop duplication records whatever is on the screen there -- which was
##                         somebody else's window, and is nobody's business.

const KEYS: Dictionary = {"white": KEY_1, "red": KEY_2, "green": KEY_3}
## How high the stage is flown, metres over the runway, and how fast, metres a second.
const STAGE_HIGH: float = 600.0
const STAGE_SPEED: float = 55.0

var _sky: Node = null
var _plan: Array = []
var _met_at: int = -1
var _last: Dictionary = {}
var _staged: bool = false
var _staged_at: int = -1
var _shots: String = ""
## Pictures still to take: [frames from now, file name].
var _due: Array = []
var _fps_next: int = 0
var _look_said: int = 0
## The craft this machine started in: staged is being in another one.
var _first_craft: int = 0
var _first_height: float = 0.0
var _reel_seconds: float = 0.0
var _reel_next: int = 0
## `--place-lamp` and `--bin-lamp`, in seconds on the flash clock; negative once done, or never asked.
var _place_at: float = -1.0
var _bin_at: float = -1.0
## Whether each other player's seat had a lamp here last frame: client -> bool.
var _present: Dictionary = {}


static func wanted(asked: Callable) -> bool:
	return String(asked.call("flash")) != "" or String(asked.call("lamps")) == "1" \
		or String(asked.call("place-lamp")) != "" \
		or String(asked.call("stage")) != "" or String(asked.call("shots")) != ""


func _init(sky: Node) -> void:
	_sky = sky
	name = "SignalLampHarness"
	for step in String(FlightLevel._asked("flash")).split(",", false):
		var parts: PackedStringArray = step.split(":")
		if parts.size() == 3 and KEYS.has(parts[1]):
			_plan.append([float(parts[0]), parts[1], float(parts[2])])
	# THE SHOTS FOLDER, AS GIVEN: `_asked` lower-cases what it reads, and a Windows path keeps its case.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			_shots = argument.trim_prefix("--shots=")
		elif argument.begins_with("--reel="):
			_reel_seconds = float(argument.trim_prefix("--reel="))
	if _shots != "":
		DirAccess.make_dir_recursive_absolute(_shots)
	if String(FlightLevel._asked("place-lamp")) != "":
		_place_at = float(FlightLevel._asked("place-lamp"))
	if String(FlightLevel._asked("bin-lamp")) != "":
		_bin_at = float(FlightLevel._asked("bin-lamp"))


func _physics_process(_delta: float) -> void:
	if Sim.client == null or not Sim.is_ready:
		return
	var rig: PilotRig = _sky.get("rig") as PilotRig
	if rig == null or rig.vehicle_view() == null:
		return
	_stage_when_asked()
	if FlightLevel._asked("look-at-other") == "1":
		_look_at_the_other(rig)
	_meet()
	_place_and_bin_when_asked(rig)
	_flash_when_asked()
	if FlightLevel._asked("lamps") == "1" or _shots != "":
		_write_down_the_lamps(rig)


func _process(_delta: float) -> void:
	if _shots == "":
		return
	# HOW FAST THIS WINDOW IS DRAWING, every two seconds: a watcher that falls under the simulation's rate falls behind it,
	# and a short flash is over before it is drawn.
	if _now() >= _fps_next:
		_fps_next = _now() + 2000
		print("LAMP_FPS ms=%d fps=%.0f" % [_now(), Engine.get_frames_per_second()])
	for one in _due.duplicate():
		one[0] = int(one[0]) - 1
		if int(one[0]) <= 0:
			_due.erase(one)
			_save(String(one[1]))
	if _reel_seconds > 0.0 and _staged_at > 0 and _now() >= _reel_next \
			and _now() - _staged_at < int(_reel_seconds * 1000.0):
		_reel_next = _now() + 33
		# THE MIDDLE HALF OF THE WINDOW, AT FULL SIZE, which is where `--look-at-other` keeps the other craft: at half size
		# the whole window made a lamp 400 m off by day one or two pixels, and the reel showed nothing.
		var whole: Image = get_viewport().get_texture().get_image()
		var frame: Image = whole.get_region(Rect2i(whole.get_width() / 4, whole.get_height() / 4,
			whole.get_width() / 2, whole.get_height() / 2))
		DirAccess.make_dir_recursive_absolute(_shots.path_join("reel"))
		frame.save_jpg(_shots.path_join("reel/%06d.jpg" % (_now() - _staged_at)), 0.9)


func _save(name: String) -> void:
	var path: String = _shots.path_join(name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	get_viewport().get_texture().get_image().save_png(path)
	print("LAMP_SHOT %s" % path)


## BOTH PLAYERS INTO A PLANE EACH, ABREAST, IN THE AIR. The host only: the server is the one that seats anybody.
func _stage_when_asked() -> void:
	var apart: float = float(FlightLevel._asked("stage"))
	if apart <= 0.0 or _staged or Sim.server == null:
		# A WATCHER'S CLOCK STARTS WHEN IT SEES ITSELF MOVED: in a craft that is not the one it started in.
		if _staged_at < 0 and FlightLevel._asked("stage") == "" \
				and (_shots != "" or FlightLevel._asked("after-stage") == "1"):
			var rig: PilotRig = _sky.get("rig") as PilotRig
			var view: VehicleView = rig.vehicle_view() if rig != null else null
			if view != null and _first_craft == 0:
				_first_craft = view.entity
				_first_height = view.global_position.y
			# ANOTHER CRAFT, 100 M ABOVE WHERE IT STARTED, OR A PLANE (the level starts everybody in a pod): the re-spawn can
			# land before this harness's first frame, and then the craft it "started" in is already the plane (the night reel of
			# 2026-09-18 was never written).
			if view != null and (view.entity != _first_craft or view.global_position.y > _first_height + 100.0
					or view.kind == Sim.Kind.PLANE):
				_staged_at = _now()
				if _shots != "":
					_due.append([30, "own-cockpit.png"])
				print("LAMP_STAGED ms=%d (seen)" % _staged_at)
				if FlightLevel._asked("throttle") == "1":
					_open_the_throttle()
				if FlightLevel._asked("own-lamp") == "1":
					_show_my_own_lamp(rig)
		return
	# A PICTURE HARNESS, AND IT SAYS SO. Both players into a plane each with `spawn_pilot`, abreast `apart` metres, 600 m up
	# -- or, with `--stage-tower=1`, only the other player, passing over this one where it stands on the airfield, which is
	# a tower signalling an aircraft. Two server faults were found staging this way (learnings/2026-09-18-lightgun.md):
	# S-1, `spawn_pilot` making a second pilot for a player who already had one, is fixed (c7439df4); S-2 is not -- about
	# one session in two the server stops sending a freshly seated craft to the other machine, where it dives and its lamp
	# never lights. The pictures are captioned as staged.
	var mine: int = Sim.local_client_id()
	var other: int = 0
	for state in Sim.pilots:
		if int(state.get("client", 0)) != mine:
			other = int(state.get("client", 0))
	if other == 0:
		return
	var rig: PilotRig = _sky.get("rig") as PilotRig
	var own: VehicleView = rig.vehicle_view() if rig != null else null
	if own == null:
		return
	var runway: Dictionary = Terrain.runways()[0]
	var bearing: float = float(runway["bearing"])
	var ahead := Vector3(-sin(bearing), 0.0, -cos(bearing))
	var right := Vector3(-ahead.z, 0.0, ahead.x)
	if FlightLevel._asked("stage-tower") == "1":
		var over: Vector3 = own.global_position + Vector3(0.0, apart * 0.5, 0.0) + right * apart * 0.6 - ahead * apart
		Sim.server.spawn_pilot(other, Sim.Kind.PLANE, over, bearing, ahead * STAGE_SPEED)
	elif FlightLevel._asked("stage-seat") == "1":
		# `--stage-seat=1`: A PLANE EACH FROM `spawn_vehicle`, AND BOTH SEATED IN ONE TICK -- the S-2 case, kept so it can be
		# asked again of any library.
		var high_seat: Vector3 = (runway["centre"] as Vector3) + Vector3(0.0, STAGE_HIGH, 0.0)
		var one: int = int(Sim.server.spawn_vehicle(Sim.Kind.PLANE, high_seat - right * apart * 0.5, bearing, ahead * STAGE_SPEED))
		var two: int = int(Sim.server.spawn_vehicle(Sim.Kind.PLANE, high_seat + right * apart * 0.5, bearing, ahead * STAGE_SPEED))
		Sim.server.seat_client(mine, one, 0)
		Sim.server.seat_client(other, two, 0)
	else:
		var high: Vector3 = (runway["centre"] as Vector3) + Vector3(0.0, STAGE_HIGH, 0.0)
		Sim.server.spawn_pilot(mine, Sim.Kind.PLANE, high - right * apart * 0.5, bearing, ahead * STAGE_SPEED)
		Sim.server.spawn_pilot(other, Sim.Kind.PLANE, high + right * apart * 0.5, bearing, ahead * STAGE_SPEED)
	_staged = true
	_staged_at = _now()
	print("LAMP_STAGED ms=%d apart=%.0f tower=%s seat=%s" % [_staged_at, apart, FlightLevel._asked("stage-tower"),
		FlightLevel._asked("stage-seat")])
	if FlightLevel._asked("throttle") == "1" and FlightLevel._asked("stage-tower") != "1":
		_open_the_throttle()


## `--throttle=1`: THE THROTTLE OPENED once staged, with the desk's own throttle action held for three seconds, which
## winds the lever and leaves it. Off by default: while S-2 (learnings/2026-09-18-lightgun.md) is in play, the other
## machine can lose a staged plane's updates, and with an opened throttle the two machines' pictures of it part company --
## the host climbed on its own screen and dived on the watcher's, and aimed its lamp at a watcher 500 m above where it
## really was. Gliding, both machines agree on where each plane is. With S-2 fixed, this is how the proof reel is taken.
func _open_the_throttle() -> void:
	Input.action_press("throttle")
	for i in range(360):
		await get_tree().physics_frame
	Input.action_release("throttle")


## `--own-lamp=1`: THIS SEAT'S LAMP, IN ITS HOLSTER AND THEN HELD UP. The view turned down to the holster for a picture;
## then the green key held, the view straight ahead, and a picture of the lamp lit in front of the eye; then back to
## looking at the other player. For "the lamp in a cockpit, held and released" -- a desk's hold, through the real key.
var _own_busy: bool = false

func _show_my_own_lamp(rig: PilotRig) -> void:
	_own_busy = true
	# PLACED FIRST, OFF THE PARTS BIN, if this seat has none: no seat has one until a player puts one there.
	if SignalLamp.in_station(rig.vehicle_view().station_for(rig.seat_index())) == null and rig.clipboard != null:
		rig.clipboard.chose_part.emit(&"SignalLamp")
		for i in range(5):
			await get_tree().physics_frame
	var lamp: SignalLamp = SignalLamp.in_station(rig.vehicle_view().station_for(rig.seat_index()))
	if lamp != null:
		for i in range(40):
			var local: Vector3 = (rig.origin.global_basis.inverse()
				* (lamp.global_position - rig.desktop_camera.global_position)).normalized()
			rig.set("_look_yaw", atan2(-local.x, -local.z) * 0.6)
			rig.set("_look_pitch", asin(clampf(local.y, -1.0, 1.0)) * 0.8)
			await get_tree().physics_frame
		_save("own-lamp-holstered.png")
	rig.set("_look_yaw", 0.35)
	rig.set("_look_pitch", -0.15)
	_hold("green", 1.6)
	for i in range(50):
		await get_tree().physics_frame
	_save("own-lamp-held.png")
	for i in range(120):
		await get_tree().physics_frame
	_own_busy = false


## THE DESK'S VIEW ON THE NEAREST OTHER PLAYER'S CRAFT, in the rig's own frame, as a mouse would turn it. The nearest,
## because a staging host is still sitting in its pod on the ground a kilometre off.
func _look_at_the_other(rig: PilotRig) -> void:
	if _own_busy:
		return
	var views: Dictionary = _sky.get("_views") as Dictionary
	var mine: int = Sim.local_client_id()
	var eye: Vector3 = rig.desktop_camera.global_position
	var best: Vector3 = Vector3.ZERO
	var nearest: float = INF
	var kind: int = -1
	for state in Sim.pilots:
		if int(state.get("client", 0)) == mine:
			continue
		var view := views.get(int(state.get("vehicle", 0))) as VehicleView
		if view == null:
			continue
		var anchor: Node3D = view.seat_anchor(int(state.get("seat", 0)))
		var target: Vector3 = anchor.global_position + anchor.global_basis * Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
		if target.distance_to(eye) < nearest:
			nearest = target.distance_to(eye)
			best = target
			kind = view.kind
	if nearest == INF or nearest < 1.0:
		return
	var local: Vector3 = rig.origin.global_basis.inverse() * (best - eye)
	if _now() >= _look_said:
		_look_said = _now() + 2000
		print("LAMP_LOOK ms=%d other=%s at %.0f m, in my frame %s; their height %.0f, mine %.0f" % [_now(),
			Sim.kind_name(kind), nearest, local.normalized(), best.y, eye.y])
	local = local.normalized()
	rig.set("_look_yaw", atan2(-local.x, -local.z))
	rig.set("_look_pitch", asin(clampf(local.y, -1.0, 1.0)))


static func _now() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


## THE CLOCK STARTS WHEN ANOTHER PLAYER IS FLYING, as this machine sees them: a pilot state that is not this machine's,
## in a craft this machine draws.
func _meet() -> void:
	# `--after-stage=1`: THE CLOCK STARTS WHEN THIS MACHINE SEES ITSELF STAGED, not when it first sees somebody.
	if FlightLevel._asked("after-stage") == "1":
		if _staged_at >= 0:
			_met_at = _staged_at
		return
	if _met_at < 0:
		var mine: int = Sim.local_client_id()
		var views: Dictionary = _sky.get("_views") as Dictionary
		for state in Sim.pilots:
			if int(state.get("client", 0)) != mine and views.has(int(state.get("vehicle", 0))):
				_met_at = _now()
				print("LAMP_MET ms=%d" % _met_at)
				break


## `--place-lamp` and `--bin-lamp`, on the flash clock. See the note at the top.
func _place_and_bin_when_asked(rig: PilotRig) -> void:
	if _met_at < 0:
		return
	var since: float = float(_now() - _met_at) / 1000.0
	var station: CockpitStation = rig.vehicle_view().station_for(rig.seat_index())
	if _place_at >= 0.0 and since >= _place_at:
		_place_at = -1.0
		if rig.clipboard != null:
			rig.clipboard.chose_part.emit(&"SignalLamp")
		print("LAMP_PLACED ms=%d seat=%d present=%d" % [_now(), rig.seat_index(),
			1 if SignalLamp.in_station(station) != null else 0])
	if _bin_at >= 0.0 and since >= _bin_at:
		_bin_at = -1.0
		var lamp: SignalLamp = SignalLamp.in_station(station)
		if lamp != null:
			rig.bin_the_part(lamp)
		print("LAMP_BINNED ms=%d seat=%d present=%d" % [_now(), rig.seat_index(),
			1 if SignalLamp.in_station(station) != null else 0])


func _flash_when_asked() -> void:
	if _plan.is_empty() or _met_at < 0:
		return
	var step: Array = _plan[0]
	if _now() - _met_at < int(float(step[0]) * 1000.0):
		return
	_plan.pop_front()
	_hold(String(step[1]), float(step[2]))


## ONE KEY DOWN FOR `seconds`, then up: both key codes set, as `WingSweepHarness._press` presses one.
func _hold(colour: String, seconds: float) -> void:
	var code: Key = KEYS[colour]
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = down
		Input.parse_input_event(key)
		print("LAMP_KEY ms=%d colour=%s down=%s" % [_now(), colour, down])
		if down:
			var until: int = _now() + int(seconds * 1000.0)
			while _now() < until:
				await get_tree().physics_frame


## EVERY LAMP OF EVERY PILOT THIS MACHINE DRAWS, this machine's own included, on every change.
func _write_down_the_lamps(rig: PilotRig) -> void:
	var views: Dictionary = _sky.get("_views") as Dictionary
	var mine: int = Sim.local_client_id()
	for state in Sim.pilots:
		var view := views.get(int(state.get("vehicle", 0))) as VehicleView
		if view == null:
			continue
		var seat: int = int(state.get("seat", 0))
		var station: CockpitStation = view.station_for(seat)
		var lamp: SignalLamp = SignalLamp.in_station(station)
		var client: int = int(state.get("client", 0))
		# ANOTHER PLAYER'S SEAT GAINING OR LOSING ITS LAMP, as this machine draws it (`VehicleView._match_lamps_to_the_wire`).
		var there: bool = lamp != null and not lamp.is_queued_for_deletion()
		if client != mine and station != null and _present.get(client) != there:
			_present[client] = there
			print("LAMP_SEEN ms=%d client=%d seat=%d present=%d" % [_now(), client, seat, 1 if there else 0])
		if lamp == null:
			continue
		var now: Array = [lamp.lit, lamp.holder]
		if _last.get(client) == now:
			continue
		_last[client] = now
		# A PICTURE OF SOMEBODY ELSE'S LAMP CHANGING, a few frames on so the far machine has drawn it.
		if _shots != "" and client != mine:
			_due.append([6, "far-%s-%d.png" % [SignalLamp.colour_name(lamp.lit), _now()]])
		# IN THE SEAT'S FRAME: the station hangs off the seat anchor.
		var pose: Transform3D = station.transform * lamp.transform
		var aim: Vector3 = -pose.basis.z
		print("LAMP ms=%d client=%d seat=%d mine=%d colour=%s holder=%d at=%.4f,%.4f,%.4f aim=%.4f,%.4f,%.4f" % [
			_now(), client, seat, 1 if client == mine else 0, SignalLamp.colour_name(lamp.lit), lamp.holder,
			pose.origin.x, pose.origin.y, pose.origin.z, aim.x, aim.y, aim.z])
