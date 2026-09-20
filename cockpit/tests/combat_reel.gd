extends Node
## A REEL OF A RAID: two bad attackers make gun runs on a CB90 under way, its gunner fires back, they take hits and
## smoke, and they come down (lane/combat, step 4, 2026-09-19).
##
##   <editor>.console.exe --path cockpit --xr-mode off --resolution 1600x900 --fixed-fps 30 --write-movie <out.avi>
##       res://tests/combat_reel.tscn -- --level=watch
##
## THE REAL LEVEL AND THE REAL RAID: `Attackers.boat_to_attack` and `Attackers.raid`, the calls the clipboard's ATTACK
## section makes, flown by the autopilots through their mixers. The boat's gunner is `tests/attackers.gd`'s: whichever
## after M2 can bear, laid through `Attackers.aim_point` with a modest error, fired through `Sim.fire_gun`. Every frame is
## the game's own viewport -- MovieWriter records the window, never the desktop.
##
## A DIRECTOR CHOOSES THE CAMERA, holding each choice at least `HOLD_S`: behind an attacker on its run, looking past it at
## the boat; on the boat's after deck, looking up at the nearest attacker; and when one is destroyed, a still point off
## the wreck for `KILL_S`, the pieces falling. Between runs, with nothing within `QUIET_M` of the boat, the world runs at
## `FAST` times, so the reel is the fight and not the transit; the caption says so.
##
## A caption burns in the clock and what the host says of each hull, so the picture can be checked against the numbers.
## RESULT= holds that an attacker was destroyed on camera and the boat was struck.

const PLANES: int = 2
const HOLD_S: float = 3.0
const KILL_S: float = 7.0
const QUIET_M: float = 1500.0
const FAST: float = 2.0
const END_S: float = 240.0
## THE REEL'S GUNNER IS WORSE THAN THE SUITE'S 0.008: at 0.008 and at 0.015 both attackers came down on their first
## run, 1.5 s apart, before either had smoked for long (the first cuts, 2026-09-19).
const GUNNER_ERROR: float = 0.02
const GUN_REACH: float = 1100.0

var _level: FlightLevel = null
var _raiders: Attackers = null
var _boat: int = 0
var _raid: Array[int] = []
var _failures: PackedStringArray = []
var _clock: float = 0.0
var _shot: String = ""
var _shot_since: float = -99.0
var _subject: int = 0
var _kill_at := Vector3.ZERO
var _kill_eye := Vector3.ZERO
var _kills_seen: int = 0
var _look := Vector3.ZERO
var _drawn_of: Dictionary = {}
var _caption: Label = null
var _dice := RandomNumberGenerator.new()
var _started: bool = false


func _check(label: String, ok: bool, detail: String) -> void:
	print("[combat_reel] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dice.seed = 99
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(16.0, 800.0)
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 6)
	layer.add_child(_caption)
	for i in range(120):
		await get_tree().process_frame
	_raiders = _level.attackers
	_boat = _raiders.boat_to_attack()
	for i in range(90):
		await get_tree().process_frame
	_raid = _raiders.raid(_boat, PLANES, 0)
	# WHERE THE RAID STARTS IN THE MOVIE, so the level's first seconds can be cut off it.
	print("[combat_reel] the raid starts at frame %d" % Engine.get_frames_drawn())
	Sim.craft_lost.connect(_on_lost)
	_look = _boat_at()
	_started = true


func _physics_process(_delta: float) -> void:
	if not _started:
		return
	_clock += Sim.tick_dt()
	_fire_back()
	var alive: Array[int] = _alive()
	var quiet: bool = _shot != "kill" and alive.all(func(e: int) -> bool:
		return (_at(e) - _boat_at()).length() > QUIET_M)
	Engine.time_scale = FAST if quiet else 1.0
	if (alive.is_empty() and _clock - _shot_since > KILL_S) or _clock > END_S:
		_started = false
		Engine.time_scale = 1.0
		_end()


func _process(_delta: float) -> void:
	if not _started:
		return
	_direct()
	_frame()
	_caption.text = _words()


## WHICH CAMERA: a kill held for `KILL_S`; an attacker on its run from behind; otherwise the deck.
func _direct() -> void:
	if _shot == "kill" and _clock - _shot_since < KILL_S:
		return
	if _clock - _shot_since < HOLD_S and _shot != "kill" and _subject in _alive():
		return
	var alive: Array[int] = _alive()
	if alive.is_empty():
		return
	alive.sort_custom(func(a: int, b: int) -> bool:
		return (_at(a) - _boat_at()).length() < (_at(b) - _boat_at()).length())
	var nearest: int = alive[0]
	var phase: String = String(_raiders.record_of(nearest).get("phase", ""))
	var want: String = "chase" if phase in ["run", "approach"] and (_at(nearest) - _boat_at()).length() > 500.0 else "deck"
	if want != _shot or nearest != _subject:
		_shot = want
		_subject = nearest
		_shot_since = _clock


func _frame() -> void:
	var boat: Vector3 = _drawn_at(_boat)
	match _shot:
		"kill":
			_look = _look.lerp(_kill_at, 0.1)
			_level.observer.look_from(_kill_eye, _look)
		"chase":
			var it: Transform3D = _drawn_transform(_subject)
			var back: Vector3 = it.basis * Vector3(0.0, 0.0, 1.0)
			back.y = 0.0
			back = back.normalized() if back.length() > 0.01 else Vector3.BACK
			# A WINGMAN'S PLACE: off to one side and a little behind, looking at a point past it toward the boat, so the
			# attacker is in profile with the boat beyond it. Anywhere behind it -- 38 m, then 55 m and 16 aside -- its
			# wingtip trails streamed past the lens as white wedges across half the frame (the first two cuts).
			var aside := Vector3(-back.z, 0.0, back.x)
			var eye: Vector3 = it.origin + aside * 28.0 + back * 12.0 + Vector3.UP * 4.0
			_look = _look.lerp(it.origin + (boat - it.origin).normalized() * 20.0, 0.2)
			_level.observer.look_from(eye, _look)
		_:
			# AT THE AFTER GUN, a head's height over it: 4.5 m over the boat's middle stood inside the mast (the first cut).
			var boat_frame: Transform3D = _drawn_transform(_boat)
			var mount: Vector3 = Sim.gun_of(Sim.Kind.CB90, 0).get("at", Vector3.ZERO)
			var eye: Vector3 = boat_frame * (mount + Vector3(0.0, 1.6, 1.2))
			var at: Vector3 = _drawn_at(_subject) if _subject != 0 else boat + Vector3.FORWARD * 100.0
			_look = _look.lerp(at, 0.2)
			_level.observer.look_from(eye, _look)


func _on_lost(kill: Dictionary) -> void:
	var victim: int = int(kill.get("victim", 0))
	if not victim in _raid:
		return
	_kills_seen += 1
	print("[combat_reel] %.1f s: %s" % [_clock, Sim.loss_words(kill)])
	# A SECOND KILL DURING THE FIRST'S SHOT KEEPS THE CAMERA, and only lengthens the shot.
	if _shot == "kill" and _clock - _shot_since < KILL_S:
		_shot_since = _clock
		return
	_shot = "kill"
	_shot_since = _clock
	_kill_at = _drawn_at(victim)
	var from_boat: Vector3 = _kill_at - _drawn_at(_boat)
	from_boat.y = 0.0
	var aside: Vector3 = from_boat.normalized().cross(Vector3.UP) if from_boat.length() > 1.0 else Vector3.RIGHT
	_kill_eye = _kill_at - from_boat.normalized() * 140.0 + aside * 60.0 + Vector3.UP * 15.0
	_look = _kill_at


## THE BOAT'S GUNNER, as tests/attackers.gd lays it: the nearest attacker in reach, whichever after M2 can bear.
func _fire_back() -> void:
	var alive: Array[int] = _alive()
	if alive.is_empty():
		return
	var boat_state: Dictionary = Sim.server.vehicle_state(_boat)
	var basis := Basis(boat_state["basis"] as Quaternion)
	var nearest: int = 0
	var best: float = INF
	for e in alive:
		var far: float = (_at(e) - (boat_state["position"] as Vector3)).length()
		if far < best:
			best = far
			nearest = e
	if best > GUN_REACH:
		return
	var there: Dictionary = Sim.server.vehicle_state(nearest)
	for mount in [0, 1]:
		var gun: Dictionary = Sim.gun_of(Sim.Kind.CB90, mount)
		var muzzle: Vector3 = (boat_state["position"] as Vector3) + basis * (gun.get("at", Vector3.ZERO) as Vector3)
		var lead: Vector3 = Attackers.aim_point(muzzle, boat_state["velocity"], there["position"], there["velocity"],
			int(gun.get("ammo", 9)), float(gun.get("muzzle", 890.0)), 1.0)
		var local: Vector3 = basis.inverse() * (lead - muzzle)
		var yaw: float = atan2(-local.x, -local.z)
		var rest: float = float((gun.get("rest", Vector2.ZERO) as Vector2).x)
		if absf(angle_difference(rest, yaw)) > float(gun.get("yaw_span", 0.0)):
			continue
		Sim.server.lay_ai_turret(_boat, mount, yaw + _dice.randfn(0.0, GUNNER_ERROR),
			atan2(local.y, Vector2(local.x, local.z).length()) + _dice.randfn(0.0, GUNNER_ERROR))
		Sim.fire_gun(_boat, mount)


func _words() -> String:
	var parts: PackedStringArray = ["%3.0f s" % _clock]
	for i in range(_raid.size()):
		parts.append("attacker %d %s" % [i + 1, _hull_words(_raid[i])])
	parts.append("CB90 %s" % _hull_words(_boat))
	var struck: int = 0
	for e in _raid:
		struck += int(Sim.server.ai_gunnery(e).get("struck", 0))
	parts.append("rounds on the boat %d" % struck)
	if Engine.time_scale > 1.0:
		parts.append(">> %.0fx" % Engine.time_scale)
	return "   ".join(parts)


func _hull_words(entity: int) -> String:
	var hull: Dictionary = Sim.server.hull_state(entity)
	if bool(hull.get("destroyed", false)):
		return "DOWN"
	var left: float = float(hull.get("left", -1.0))
	return "%3.0f%%" % (100.0 if left < 0.0 else left * 100.0)


func _alive() -> Array[int]:
	return _raid.filter(func(e: int) -> bool: return not bool(Sim.server.hull_state(e).get("destroyed", false)))


func _at(host_entity: int) -> Vector3:
	return Sim.server.vehicle_state(host_entity).get("position", Vector3.ZERO)


func _boat_at() -> Vector3:
	return _at(_boat)


## Where this machine draws a host's craft: its own entity for it, found once by place and kind, else the host's place.
func _drawn_transform(host_entity: int) -> Transform3D:
	var mine: int = int(_drawn_of.get(host_entity, 0))
	if mine == 0 or not Sim.current.has(mine):
		var there: Vector3 = _at(host_entity)
		var nearest: float = 20.0
		for entity in Sim.current:
			var far: float = ((Sim.current[entity]["position"] as Vector3) - there).length()
			if far < nearest:
				nearest = far
				mine = int(entity)
		_drawn_of[host_entity] = mine
	if mine != 0 and Sim.current.has(mine):
		return Sim.vehicle_transform(mine)
	return Transform3D(Basis(Sim.server.vehicle_state(host_entity).get("basis", Quaternion.IDENTITY) as Quaternion),
		_at(host_entity))


func _drawn_at(host_entity: int) -> Vector3:
	return _drawn_transform(host_entity).origin


func _end() -> void:
	var struck: int = 0
	for e in _raid:
		struck += int(Sim.server.ai_gunnery(e).get("struck", 0))
	_check("an_attacker_came_down_on_camera", _kills_seen >= 1, "%d of %d" % [_kills_seen, _raid.size()])
	_check("the_boat_was_struck", struck >= 1, "%d rounds" % struck)
	_finish()


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
