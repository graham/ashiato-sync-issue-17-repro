extends Node
## HIT CRAFT, PHOTOGRAPHED: a thin grey trail, a thick black one, and a fireball where one is destroyed (lane/combat).
##
##   Godot --path cockpit --fixed-fps 60 --resolution 1600x900 res://tests/combat_shot.tscn -- --level=watch \
##       [--views=smoke,fireball] [--out=C:/somewhere]
##
## NOT HEADLESS -- it renders, and headless pictures are black rectangles. The pictures come from the game's own
## viewport and nothing else: never the desktop.
##
##   smoke     three of the island's light aeroplanes put 600 m up in line abreast, one whole, one at half its points (a
##             thin trail) and one at a fifth (a thick one), flown by their autopilots for `FLY` seconds and photographed
##             from behind and above the middle one, the camera following them.
##   fireball  a fourth, destroyed by the host in front of the camera: the frame a quarter of a second after, and a
##             second after.
##   crash     WITHOUT --level=watch: the player asks for a Savoia and dives it into the sea by holding W, a real key
##             event; photographed from the cockpit on the way down, from the crash overview's stand with its panel, and
##             from the cockpit of the fresh Savoia after the respawn.
##   ipad      WITHOUT --level=watch: the host's clipboard on its TRAFFIC tab, with ATTACK MY CRAFT, saved off the
##             clipboard's own SubViewport.
##   raid      two light aeroplanes and an Apache sent at a CB90 under way (`Attackers.raid`): from behind an aeroplane
##             diving on it and firing, and from the boat looking up at it.
##   trap      a carrier put to sea making 12 m/s, and two Hornets brought onto its deck, steered so the crash rule judges
##             them: one arriving just under the carrier aeroplane's 7.62 m/s, which is a landing, and one just over it,
##             which is not (step 5, `touchdown_rule`). Asked 8.6 and 9.4 m/s, as tests/crashes.gd asks them.
##
## Pictures go to `--out` (default `user://combat_shots`), `combat-<view>[-n].png`.

const OUT := "user://combat_shots"
const WARM: int = 240
const FLY: float = 8.0
const UP: float = 600.0

var _level: FlightLevel = null
var _views: Array[String] = ["smoke", "fireball"]
var _out: String = OUT
var _failures: PackedStringArray = []
## The entity the camera follows on this machine, and where it sits relative to it: behind, up, and across.
var _follow: int = 0
var _offset := Vector3(14.0, 6.0, 30.0)
## The host's craft the camera is to follow once this machine draws it.
var _host: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[combat_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"views":
				_views.assign(Array(parts[1].split(",", false)))
			"out":
				_out = parts[1]
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	if _level.observer == null and not ("crash" in _views or "ipad" in _views):
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	for i in range(WARM):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	if "crash" in _views:
		await _crash()
		_finish()
		return
	if "ipad" in _views:
		await _ipad()
		_finish()
		return
	if "raid" in _views:
		await _raid()
		_finish()
		return
	if "trap" in _views:
		await _traps()
		_finish()
		return
	var flight: Array[int] = _three_abreast()
	for view in _views:
		match view:
			"smoke":
				await _smoke(flight)
			"fireball":
				await _fireball(flight)
			_:
				_check("the_view_%s_exists" % view, false, "no such view")
	_finish()


func _process(_delta: float) -> void:
	if _follow == 0 or _level == null or _level.observer == null or not Sim.current.has(_follow):
		return
	var at: Transform3D = Sim.vehicle_transform(_follow)
	var flat: Basis = Basis(Vector3.UP, at.basis.get_euler().y)
	_level.observer.look_from(at.origin + flat * _offset, at.origin + flat * Vector3(0.0, 0.0, -40.0))


## THREE LIGHT AEROPLANES, 40 m apart, flying north 600 m up on their autopilots: the host's entities.
func _three_abreast() -> Array[int]:
	var out: Array[int] = []
	for i in range(4):
		out.append(Sim.spawn_ai_vehicle(Sim.Kind.PLANE, Vector3(-40.0 + 40.0 * i, UP, 2000.0), 0.0,
			Vector3(0.0, 0.0, -55.0)))
	return out


func _smoke(flight: Array[int]) -> void:
	var whole: float = float(Sim.server.kind_hull(Sim.Kind.PLANE))
	Sim.server.apply_damage(flight[1], whole * 0.5)
	Sim.server.apply_damage(flight[2], whole * 0.8)
	_follow = _drawn(flight[1])
	for i in range(int(FLY * 60.0)):
		await get_tree().process_frame
		if _follow == 0:
			_follow = _drawn(flight[1])
	_check("the_half_and_the_fifth_smoke", _level.damage.smoking(_drawn(flight[1])) == 1
		and _level.damage.smoking(_drawn(flight[2])) == 2, "stages %d and %d" % [
			_level.damage.smoking(_drawn(flight[1])), _level.damage.smoking(_drawn(flight[2]))])
	await _save("smoke-thin")
	_follow = _drawn(flight[2])
	for i in range(20):
		await get_tree().process_frame
	await _save("smoke-thick")
	_offset = Vector3(-45.0, 10.0, -10.0)
	for i in range(20):
		await get_tree().process_frame
	await _save("smoke-thick-abeam")


func _fireball(flight: Array[int]) -> void:
	# CLOSE, abeam and a little above: close enough that the pieces are pieces and not specks.
	_offset = Vector3(22.0, 5.0, 6.0)
	_follow = 0
	# FOLLOWED ONCE THIS MACHINE DRAWS IT, and for a while before, so the camera is on it when it goes.
	for i in range(240):
		await get_tree().process_frame
		if _follow == 0:
			_follow = _drawn(flight[3])
	# THE CAMERA STOPS WHERE IT IS: a wreck is frozen, and a camera following it would be too.
	Sim.server.apply_damage(flight[3], 10000.0)
	for i in range(15):
		await get_tree().process_frame
	await _save("fireball")
	for i in range(33):
		await get_tree().process_frame
	await _save("fireball-2")
	for i in range(72):
		await get_tree().process_frame
	await _save("fireball-3")


## A SAVOIA FLOWN INTO THE SEA, and what the player sees after.
func _crash() -> void:
	var rig: PilotRig = _level.rig
	# STAGED OVER THE SEA: the island issues no Savoia, so the host puts this player in one 2 km off the coast at 350 m,
	# through `spawn_pilot`, which since lightgun's S-1 fix moves the player's own pilot rather than making a second.
	var sea := Vector3(0.0, 350.0, Terrain.WORLD_HALF + 2000.0)
	Sim.server.spawn_pilot(Sim.local_client_id(), Sim.Kind.SAVOIA, sea, PI, Vector3(0.0, 0.0, 45.0))
	var view: VehicleView = null
	for i in range(900):
		await get_tree().process_frame
		view = rig.vehicle_view()
		if view != null and view.kind == Sim.Kind.SAVOIA:
			break
	if view == null or view.kind != Sim.Kind.SAVOIA:
		_check("the_player_is_in_a_savoia", false, "%s" % [view])
		return
	for i in range(120):
		await get_tree().process_frame
	# NOSE DOWN, AND FULL THROTTLE: W and Shift held, as a person at the desk holds them.
	_key(KEY_SHIFT, true)
	_key(KEY_W, true)
	var shot_dive: bool = false
	for i in range(1800):
		await get_tree().process_frame
		if not shot_dive and view != null and is_instance_valid(view) and view.global_position.y < 120.0:
			shot_dive = true
			await _save("crash-dive")
		if _level.overview.is_showing():
			break
	_key(KEY_W, false)
	_key(KEY_SHIFT, false)
	_check("the_savoia_is_destroyed_and_the_overview_shows", _level.overview.is_showing(), _level.overview.words)
	for i in range(20):
		await get_tree().process_frame
	await _save("crash-overview")
	for i in range(90):
		await get_tree().process_frame
	await _save("crash-overview-2")
	for i in range(900):
		await get_tree().process_frame
		if not _level.overview.is_showing() and rig.vehicle_view() != null:
			break
	for i in range(60):
		await get_tree().process_frame
	_check("and_the_player_is_back_in_a_savoia", rig.vehicle_view() != null and rig.vehicle_view().kind == Sim.Kind.SAVOIA
		and not rig.vehicle_view().wrecked, "")
	await _save("crash-respawned")


## THE HOST'S CLIPBOARD ON ITS TRAFFIC TAB, off the clipboard's own screen.
func _ipad() -> void:
	var page: ClipboardPage = _level.rig.clipboard.page()
	page.show_tab(ClipboardPage.Tab.TRAFFIC)
	var glass := _level.rig.clipboard.panel().get("_screen") as SubViewport
	glass.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var file: String = "%s/combat-ipad.png" % _out
	glass.get_texture().get_image().save_png(file)
	print("[combat_shot] saved %s" % ProjectSettings.globalize_path(file))


## A RAID ON A CB90, watched from behind an attacker on its gun run and from the boat.
func _raid() -> void:
	var raiders: Attackers = _level.attackers
	var boat: int = raiders.boat_to_attack()
	for i in range(120):
		await get_tree().process_frame
	var raid: Array[int] = raiders.raid(boat, 2, 1)
	var plane: int = raid[0]
	_follow = 0
	_offset = Vector3(8.0, 4.0, 26.0)
	var shot_run: bool = false
	var shot_boat: bool = false
	for i in range(60 * 150):
		await get_tree().process_frame
		if _follow == 0:
			_follow = _drawn(plane)
		var me: Dictionary = raiders.record_of(plane)
		var gunnery: Dictionary = Sim.server.ai_gunnery(plane)
		var off: float = ((Sim.server.vehicle_state(boat)["position"] as Vector3)
			- (Sim.server.vehicle_state(plane)["position"] as Vector3)).length()
		if not shot_run and String(me.get("phase", "")) == "run" and int(gunnery.get("fired", 0)) > 20 and off < 700.0:
			shot_run = true
			await _save("raid-run")
			# AND FROM THE BOAT: the camera stands on the CB90's after deck looking up at the aeroplane.
			var boat_view: int = _drawn(boat)
			_follow = 0
			if boat_view != 0 and _level.observer != null:
				var deck: Vector3 = Sim.vehicle_transform(boat_view).origin + Vector3(0.0, 4.0, 0.0)
				var up_at: Vector3 = Sim.vehicle_transform(_drawn(plane)).origin if _drawn(plane) != 0 else deck
				_level.observer.look_from(deck, up_at)
				await _save("raid-from-the-boat")
				shot_boat = true
			break
	_check("the_raid_was_photographed", shot_run and shot_boat, "run %s, boat %s" % [shot_run, shot_boat])


## TWO TRAPS ON A CARRIER UNDER WAY, one a landing and one a crash.
func _traps() -> void:
	var sea := Vector3(0.0, 0.0, Terrain.WORLD_HALF + Terrain.OFFSHORE + 3000.0)
	var carrier: int = Sim.spawn_vehicle(Sim.Kind.CARRIER, sea, 0.0, Vector3(0.0, 0.0, -12.0))
	for i in range(120):
		await get_tree().physics_frame
	# WHERE A HORNET'S MIDDLE RESTS OVER THE SHIP'S ORIGIN: one let fall onto the deck forward, nobody in it, so the crash
	# rule leaves it alone; it stays parked there for the picture.
	var ship: Dictionary = Sim.server.vehicle_state(carrier)
	var parked: int = Sim.spawn_vehicle(Sim.Kind.FIGHTER, (ship["position"] as Vector3) + Vector3(0.0, 40.0, -60.0), 0.0,
		ship["velocity"])
	for i in range(int(6.0 / Sim.tick_dt())):
		await get_tree().physics_frame
	var rest: float = ((Sim.server.vehicle_state(parked)["position"] as Vector3)
		- (Sim.server.vehicle_state(carrier)["position"] as Vector3)).y
	_check("the_deck_was_found", rest > 5.0 and rest < 40.0, "a Hornet rests %.2f m over the carrier's origin" % rest)
	var rule: Dictionary = Sim.server.touchdown_rule(Sim.Kind.FIGHTER)
	_offset = Vector3(-30.0, 5.0, 14.0)
	var first: int = await _one_trap(carrier, rest, 8.6)
	await _wait(1.0)
	var whole: bool = not bool(Sim.server.hull_state(first).get("destroyed", true))
	await _save("trap-a-landing")
	_check("a_trap_under_the_line_is_a_landing", whole, "arrived at %.2f m/s against %.2f" % [
		float(Sim.server.touchdown_report(false).get(first, 0.0)), float(rule.get("limit", 0.0))])
	var second: int = await _one_trap(carrier, rest, 9.4)
	for i in range(int(2.0 / Sim.tick_dt())):
		await get_tree().physics_frame
		if _follow == 0:
			_follow = _drawn(second)
		if bool(Sim.server.hull_state(second).get("destroyed", false)):
			break
	await _wait(0.25)
	await _save("trap-too-hard")
	await _wait(1.0)
	await _save("trap-too-hard-after")
	_check("a_trap_over_the_line_is_a_crash", bool(Sim.server.hull_state(second).get("destroyed", false)),
		"arrived at %.2f m/s against %.2f" % [float(Sim.server.touchdown_report(false).get(second, 0.0)),
		float(rule.get("limit", 0.0))])


## ONE HORNET, put just past its legs' reach over the deck 40 m aft, 35 m/s faster than the ship and sinking so it
## arrives at about `asked` less the 1.3 m/s its wing takes off; steered, so it is in the game and judged. Its entity.
func _one_trap(carrier: int, rest: float, asked: float) -> int:
	var ship: Dictionary = Sim.server.vehicle_state(carrier)
	var at: Vector3 = (ship["position"] as Vector3) + Vector3(0.0, rest + 0.85, 40.0)
	var sink: float = sqrt(maxf(asked * asked - 2.0 * 9.81 * 0.25, 0.0))
	var hornet: int = Sim.spawn_ai_vehicle(Sim.Kind.FIGHTER, at, 0.0,
		(ship["velocity"] as Vector3) + Vector3(0.0, -sink, -35.0))
	Sim.server.steer_ai(hornet, {"toward": (ship["position"] as Vector3) + Vector3(0.0, rest, -400.0),
		"altitude": at.y - 1.0, "speed": 0.0, "wheels": "hold"})
	_follow = 0
	_host = hornet
	return hornet


func _wait(seconds: float) -> void:
	for i in range(int(seconds / Sim.tick_dt())):
		await get_tree().physics_frame
		# NOT DRAWN THE TICK IT IS SPAWNED: asked again until it is.
		if _follow == 0 and _host != 0:
			_follow = _drawn(_host)


func _key(code: Key, down: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = down
	Input.parse_input_event(key)


## This machine's entity for a host's craft: the same place, the nearest one of its kind.
func _drawn(host_entity: int) -> int:
	var there: Vector3 = Sim.server.vehicle_state(host_entity).get("position", Vector3.INF)
	var best: int = 0
	var nearest: float = 20.0
	for entity in Sim.current:
		var far: float = ((Sim.current[entity]["position"] as Vector3) - there).length()
		if far < nearest:
			nearest = far
			best = int(entity)
	return best


func _save(called: String) -> void:
	for i in range(6):
		await RenderingServer.frame_post_draw
	var shot: Image = get_viewport().get_texture().get_image()
	var file: String = "%s/combat-%s.png" % [_out, called]
	shot.save_png(file)
	print("[combat_shot] saved %s" % ProjectSettings.globalize_path(file))


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
