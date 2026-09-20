extends Node
## Headless: THE BATTLESHIP'S BIG GUNS, from a gunner's stick to the splash six kilometres off.
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/big_guns.tscn
##
## Plan item 22, asked for on 2026-09-15: "the turret seats on the battleship should be for the big guns and the player
## should be able to shoot them, like large battleship guns they go very far" -- and the four answers that shaped it: SIX
## KILOMETRES; "build a sight for them, they can fire and gauge distance"; "big explosion no fire"; two independent
## turrets, one gunner each.
##
## WHAT IS REAL. A server `CockpitWorld` and a client one, over a link that holds every packet `LINK` ticks each way,
## modelled the way `addon/tests/cockpit_loopback` models it. The client sits in a turret seat and LAYS THE GUN WITH ITS
## STICK -- pitch on its own input frame, which the server's `aim_turret` turns into elevation at the mount's own rate --
## and fires with its TRIGGER. Nothing here calls `fire_gun` or writes an angle.
##
## THE SEA HAS A FLOOR 150 m DOWN, as the island's is getting one (lane/sinking, 2026-09-16): a shell that burst on the
## first solid thing under it would burst on that floor, out of sight, and the splash a gunner corrects by would never
## appear. So every landing here is over that floor, and "on the water" means within a metre of y = 0.
##
## Read RESULT=, not the exit code.

const TICK_HZ: float = 120.0
const DT: float = 1.0 / TICK_HZ
const PEER: int = 2
## A 67 ms round trip: four ticks each way, cockpit_loopback's link.
const LINK: int = 4
const POD: int = 0
const BATTLESHIP: int = 13
## The turret seats: seat 2 works mount 0 (turret 2, forward), seat 3 works mount 1 (turret 3, aft).
const FORWARD_SEAT: int = 2
const AFT_SEAT: int = 3
## The range laid for the end-to-end shot: inside six kilometres and far enough that a degree matters.
const LAID_RANGE: float = 5000.0
## Where the floor under the open sea is, and how close to the surface a burst on the water must be.
const FLOOR_TOP: float = -150.0
const ON_THE_WATER_M: float = 1.0
## THE MOST A SHELL MAY LAND FROM WHERE THE SCALE SAYS, as a share of the range. The ship floats and settles -- a hull
## five hundred metres of wave-free sea still trims a fraction of a degree -- and the scale is for a level ship; this is
## the budget for that, and the measured figure is printed beside it.
const SCALE_AGREES: float = 0.02
## THE MOST THE DRAWN SHELL MAY LAND FROM THE SERVER'S IMPACT, metres, off the birth record the client received and flown
## by the renderer's own `ShotYard.fly_for` at a headset's frame rates. MEASURED 0.00 m at 120, 90 and 72 Hz, at 5 km
## (2026-09-16), once the server flies the birth record as the wire carries it and the renderer flies whole server
## ticks. Before those two it was 5.6, 6.7 and 7.8 m: the muzzle quantum (0.25 m/s) moved the velocity 0.096 m/s, and one
## step of a 90 Hz frame is a coarser integration than the server's. Half a metre is the budget; a fireball is 160 m.
const DRAWN_AGREES_M: float = 0.5

var _failures: PackedStringArray = []
var _server: RefCounted = null
var _client: RefCounted = null
var _tick: int = 0
var _in_flight: Array = []
var _next_spare: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[big_guns] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_the_turret_seats_work_the_big_guns()
	_full_elevation_reaches_six_kilometres()
	_the_range_scale_and_the_elevation_agree()
	var aboard: Dictionary = _a_gunner_aboard()
	if not aboard.is_empty():
		var shell: Dictionary = _the_gunner_lays_and_fires(aboard, FORWARD_SEAT, LAID_RANGE)
		if not shell.is_empty():
			_it_lands_on_the_water_where_the_scale_says(aboard, shell)
			_the_client_draws_it_landing_where_the_server_says(shell)
			_it_starts_no_fire(shell)
		_the_other_turret_is_the_other_seats(aboard)
		for seat in [AFT_SEAT, FORWARD_SEAT]:
			_at_the_elevation_stop_the_shell_lands_six_kilometres_off(aboard, seat)
	_finish()


## ---- the table -------------------------------------------------------------------------------------------------------

func _the_turret_seats_work_the_big_guns() -> void:
	var said: PackedStringArray = []
	var ok: bool = true
	for seat in [FORWARD_SEAT, AFT_SEAT]:
		var mount: int = Sim.mount_of_seat(BATTLESHIP, seat)
		var gun: Dictionary = Sim.gun_of(BATTLESHIP, mount)
		var named: String = ""
		for row in (gun.get("rounds", []) as Array):
			if int((row as Dictionary)["ammo"]) == int(gun.get("ammo", -1)):
				named = String((row as Dictionary)["name"])
		ok = ok and mount >= 0 and bool(gun.get("fitted", false)) and not bool(gun.get("pintle", true)) \
			and named == "406mm" and is_equal_approx(float(gun.get("muzzle", 0.0)), 400.0)
		said.append("seat %d: mount %d, %s, %s, %.0f m/s, pintle %s" % [seat, mount, named,
			"fitted" if bool(gun.get("fitted", false)) else "empty", float(gun.get("muzzle", 0.0)), gun.get("pintle")])
	_check("both_turret_seats_work_a_406_mm_gun_laid_with_a_joystick", ok and Sim.mount_of_seat(BATTLESHIP, FORWARD_SEAT)
		!= Sim.mount_of_seat(BATTLESHIP, AFT_SEAT), "; ".join(said))
	# THE DRAWN TURRET AND THE SIMULATION'S MOUNT ARE ONE: the model stands each worked turret on its deck by its own
	# TRUNNION and `raised` and draws its barrels GUNHOUSE.z / 2 + BARREL out, and the simulation fires from the same
	# point along the same length. Two tables, so they are held to each other here.
	var parts: Array = Sim.geometry_of(BATTLESHIP).get("parts", []) as Array
	var apart: PackedStringArray = []
	var worked: int = 0
	for turret in Battleship.TURRETS:
		var mount: int = int(turret.get("mount", -1))
		if mount < 0:
			continue
		worked += 1
		var gun: Dictionary = Sim.gun_of(BATTLESHIP, mount)
		var drawn := Vector3(0.0, Battleship._foot(parts, Vector2(0.0, float(turret["z"]))) + float(turret["raised"])
			+ Battleship.TRUNNION, float(turret["z"]))
		var barrel: float = Battleship.GUNHOUSE.z * 0.5 + Battleship.BARREL
		if (gun.get("at", Vector3.INF) as Vector3).distance_to(drawn) > 0.01 \
				or absf(float(gun.get("barrel", 0.0)) - barrel) > 0.01:
			apart.append("mount %d fires from %s along %.2f m, drawn at %s along %.2f m" % [mount, gun.get("at"),
				float(gun.get("barrel", 0.0)), drawn, barrel])
	_check("the_drawn_turrets_are_the_mounts_the_shells_leave", apart.is_empty() and worked == 2,
		"%d worked turrets%s" % [worked, "" if apart.is_empty() else ": " + "; ".join(apart)])


## THE ELEVATION STOP IS WHERE SIX KILOMETRES RUNS OUT, and the flight takes the watchable fifteen seconds the plan chose.
func _full_elevation_reaches_six_kilometres() -> void:
	var said: PackedStringArray = []
	var ok: bool = true
	for mount in [0, 1]:
		var gun: Dictionary = Sim.gun_of(BATTLESHIP, mount)
		var top: float = (gun.get("pitch_range", Vector2.ZERO) as Vector2).y
		var reach: Dictionary = _world_to_ask().shell_reach(BATTLESHIP, mount, top)
		var metres: float = float(reach.get("range", 0.0))
		var seconds: float = float(reach.get("seconds", 0.0))
		ok = ok and absf(metres - 6000.0) <= 5.0 and seconds > 12.0 and seconds < 18.0
		said.append("mount %d: %.2f deg -> %.0f m in %.1f s" % [mount, rad_to_deg(top), metres, seconds])
	_check("full_elevation_lands_six_kilometres_off_in_about_fifteen_seconds", ok, "; ".join(said))


func _the_range_scale_and_the_elevation_agree() -> void:
	var worst: float = 0.0
	for metres in [1000.0, 2000.0, 3000.0, 4000.0, 5000.0, 5900.0]:
		var elevation: float = float(_world_to_ask().shell_elevation(BATTLESHIP, 0, metres))
		var back: float = float(_world_to_ask().shell_reach(BATTLESHIP, 0, elevation).get("range", 0.0))
		worst = maxf(worst, absf(back - metres))
	_check("the_elevation_for_a_range_lands_at_that_range", worst <= 1.0, "worst %.2f m over 1 to 5.9 km" % worst)


## ---- the gunner, over a link ---------------------------------------------------------------------------------------

## A SERVER AND A CLIENT, a battleship afloat over a sea with a floor 150 m down, and the client sat at the forward turret.
func _a_gunner_aboard() -> Dictionary:
	_server = ClassDB.instantiate("CockpitWorld")
	_client = ClassDB.instantiate("CockpitWorld")
	for world in [_server, _client]:
		world.set_tick_rate(TICK_HZ)
	_server.start(0)
	_client.start(PEER)
	for world in [_server, _client]:
		world.add_static_box(Vector3(0.0, FLOOR_TOP - 10.0, 0.0), Vector3(12000.0, 10.0, 12000.0))
	_advance(90, {})
	var me: int = int(_client.local_client_id())
	_check("the_client_handshook", me > 0, "client id %d" % me)
	if me <= 0:
		return {}
	var hull: int = int(_server.spawn_vehicle(BATTLESHIP, Vector3.ZERO, 0.0, Vector3.ZERO))
	_server.spawn_pilot(me, POD, Vector3(300.0, 4.0, 300.0), 0.0, Vector3.ZERO)
	_advance(20, {})
	var seated: bool = hull != 0 and bool(_server.seat_client(me, hull, FORWARD_SEAT))
	_check("a_client_takes_the_forward_turret_seat", seated, "client %d, hull %d" % [me, hull])
	if not seated:
		return {}
	# SETTLED: a hull put on the water bobs before it floats, and a gun laid on a bobbing ship is laid on nothing.
	_advance(600, _controls({}))
	return {"client": me, "hull": hull}


## LAY THE GUN TO `range` WITH THE STICK AND PULL THE TRIGGER, from `seat`. The shell the server made, with the
## elevation the mount was at when it left, or {}.
func _the_gunner_lays_and_fires(aboard: Dictionary, seat: int, range: float) -> Dictionary:
	var hull: int = int(aboard["hull"])
	var mount: int = Sim.mount_of_seat(BATTLESHIP, seat)
	var wanted: float = float(_server.shell_elevation(BATTLESHIP, mount, range))
	var laid: bool = false
	for i in range(int(8.0 * TICK_HZ)):
		var now: float = _server_aim(hull, mount).y
		if now >= wanted:
			laid = true
			break
		# FULL STICK until close, then a nudge: the mount moves 0.07 rad/s, and a tick of full stick is 0.0006 rad.
		_advance(1, _controls({"pitch": 1.0 if wanted - now > 0.01 else 0.25}))
	_advance(LINK * 2 + 4, _controls({}))
	var aim: Vector2 = _server_aim(hull, mount)
	_check("the_gunner_lays_the_forward_gun_with_the_stick", laid,
		"elevation %.3f deg for %.0f m, wanted %.3f deg" % [rad_to_deg(aim.y), range, rad_to_deg(wanted)])
	var seen: Dictionary = {}
	for row in _server.shot_states():
		seen[int(row["entity"])] = true
	var shell: Dictionary = {}
	for i in range(LINK * 2 + 30):
		_advance(1, _controls({"trigger": 1.0}))
		for row in _server.shot_states():
			if not seen.has(int(row["entity"])) and int(row.get("shooter", -1)) == int(aboard["client"]):
				shell = row
		if not shell.is_empty():
			break
	_advance(1, _controls({}))
	_check("and_its_trigger_fires_a_406_mm_shell", not shell.is_empty() and String(shell.get("ammo_name", "")) == "406mm",
		"%s" % [shell])
	if shell.is_empty():
		return {}
	shell["elevation"] = _server_aim(hull, mount).y
	shell["mount"] = mount
	return shell


## WHERE IT COMES DOWN: ON THE WATER, within a metre of y = 0 and not on the floor 150 m under it -- and at the range the
## scale gives for the elevation the gun was at, measured from the trunnion in plan.
func _it_lands_on_the_water_where_the_scale_says(aboard: Dictionary, shell: Dictionary) -> void:
	var entity: int = int(shell["entity"])
	var landed: Dictionary = {}
	var client_saw: Dictionary = {}
	var ticks: int = 0
	for i in range(int(25.0 * TICK_HZ)):
		_advance(1, _controls({}))
		ticks += 1
		var row: Dictionary = _row(_server.shot_states(), entity)
		if not row.is_empty() and not bool(row.get("flying", true)):
			landed = row
			break
	for i in range(LINK * 2 + 30):
		_advance(1, _controls({}))
		for row in _client.shot_states():
			if not bool((row as Dictionary).get("flying", true)) and \
					((row as Dictionary)["impact"] as Vector3).distance_to(landed.get("impact", Vector3.INF) as Vector3) < 0.5:
				client_saw = row
	shell["landed"] = landed
	var impact: Vector3 = landed.get("impact", Vector3.INF) as Vector3
	_check("it_bursts_on_the_water_within_a_metre_of_the_surface_not_on_the_floor_under_it",
		not landed.is_empty() and int(landed["surface"]) == Ammunition.WATER and absf(impact.y) <= ON_THE_WATER_M,
		"surface %s at y %.2f after %.1f s; the floor is at %.0f m" % [landed.get("surface", "-"), impact.y,
			float(ticks) / TICK_HZ, FLOOR_TOP])
	var gun: Dictionary = Sim.gun_of(BATTLESHIP, int(shell["mount"]))
	var trunnion: Vector3 = (_server.vehicle_state(int(aboard["hull"]))["position"] as Vector3) \
		+ (gun.get("at", Vector3.ZERO) as Vector3)
	var flat: float = Vector2(impact.x - trunnion.x, impact.z - trunnion.z).length()
	var scale: float = float(_server.shell_reach(BATTLESHIP, int(shell["mount"]), float(shell["elevation"])).get("range", 0.0))
	_check("it_lands_at_the_range_the_scale_gives_for_its_elevation",
		not landed.is_empty() and absf(flat - scale) <= scale * SCALE_AGREES,
		"%.0f m from the trunnion, the scale says %.0f m (%.2f%%, budget %.0f%%)" % [flat, scale,
			100.0 * absf(flat - scale) / maxf(scale, 1.0), SCALE_AGREES * 100.0])
	_check("and_the_client_is_told_the_same_impact", not client_saw.is_empty(),
		"client impact %s" % [client_saw.get("impact", "none")])


## THE CLIENT DRAWS IT LANDING WHERE THE SERVER SAYS IT LANDED: the birth record as the CLIENT received it -- through the
## wire's quantiser -- flown by the renderer's own `ShotYard.fly_for` at 120, 90 and 72 frames a second until it comes down
## through the height of the server's impact.
func _the_client_draws_it_landing_where_the_server_says(shell: Dictionary) -> void:
	var landed: Dictionary = shell.get("landed", {})
	if landed.is_empty():
		_check("the_client_draws_it_landing_where_the_server_says", false, "the shell never landed")
		return
	var record: Dictionary = {}
	for row in _client.shot_states():
		if ((row as Dictionary)["impact"] as Vector3).distance_to(landed["impact"] as Vector3) < 0.5:
			record = row
	if record.is_empty():
		_check("the_client_draws_it_landing_where_the_server_says", false, "the client holds no record of it")
		return
	var impact: Vector3 = landed["impact"] as Vector3
	var said: PackedStringArray = []
	var worst: float = 0.0
	for hz in [120.0, 90.0, 72.0]:
		var drawn: Dictionary = {"at": record["from"], "velocity": record["velocity"], "drag": record["drag"], "age": 0.0}
		var last: Vector3 = drawn["at"]
		while (drawn["at"] as Vector3).y > impact.y and float(drawn["age"]) < 60.0:
			last = drawn["at"]
			ShotYard.fly_for(drawn, 1.0 / hz)
		var now: Vector3 = drawn["at"]
		var t: float = (last.y - impact.y) / maxf(last.y - now.y, 0.0001)
		var down: Vector3 = last.lerp(now, t)
		var miss: float = Vector2(down.x - impact.x, down.z - impact.z).length()
		worst = maxf(worst, miss)
		said.append("%.0f Hz %.2f m" % [hz, miss])
	# WHERE THE DIFFERENCE COMES FROM, printed: the server's own record through the same step, so the part the wire's
	# quantiser adds and the part the renderer's arithmetic adds can be told apart.
	var own: Dictionary = {}
	for row in _server.shot_states():
		if ((row as Dictionary)["impact"] as Vector3).distance_to(impact) < 0.01:
			own = row
	if not own.is_empty():
		var server_drawn: Dictionary = {"at": own["from"], "velocity": own["velocity"], "drag": own["drag"], "age": 0.0}
		var was: Vector3 = server_drawn["at"]
		while (server_drawn["at"] as Vector3).y > impact.y:
			was = server_drawn["at"]
			ShotYard.fly_for(server_drawn, 1.0 / 120.0)
		var t2: float = (was.y - impact.y) / maxf(was.y - (server_drawn["at"] as Vector3).y, 0.0001)
		var d2: Vector3 = was.lerp(server_drawn["at"] as Vector3, t2)
		print(("[big_guns] measure: the server's own record through ShotYard.fly_for at 120 Hz lands %.2f m off; the wire "
			+ "moved the muzzle %.3f m and the velocity %.4f m/s") % [Vector2(d2.x - impact.x, d2.z - impact.z).length(),
			(own["from"] as Vector3).distance_to(record["from"] as Vector3),
			(own["velocity"] as Vector3).distance_to(record["velocity"] as Vector3)])
	var from: Vector3 = record["from"] as Vector3
	var reach: float = Vector2(impact.x - from.x, impact.z - from.z).length()
	_check("the_client_draws_it_landing_where_the_server_says", worst <= DRAWN_AGREES_M,
		"at %.0f m: %s; budget %.1f m" % [reach, ", ".join(said), DRAWN_AGREES_M])


## "BIG EXPLOSION NO FIRE", the user's words, taken literally: a shell landing starts nothing burning.
func _it_starts_no_fire(shell: Dictionary) -> void:
	var fires: int = (_server.fire_states() as Array).size()
	_check("the_shell_starts_no_fire", not (shell.get("landed", {}) as Dictionary).is_empty() and fires == 0,
		"%d fire(s) in the world after it landed" % fires)
	_check("and_it_is_a_big_explosion", BurstTuning.is_heavy(int(shell["ammo"]))
		and BurstTuning.fireball_for_round(int(shell["ammo"])) > BurstTuning.fireball_for_round(6) * 3.0,
		"fireball radius %.1f m, the 105 mm's %.1f m" % [BurstTuning.fireball_for_round(int(shell["ammo"])),
			BurstTuning.fireball_for_round(6)])


## TWO INDEPENDENT TURRETS: the same client moved to the aft turret seat lays mount 1, and mount 0 stays where it was.
func _the_other_turret_is_the_other_seats(aboard: Dictionary) -> void:
	var hull: int = int(aboard["hull"])
	var seated: bool = bool(_server.seat_client(int(aboard["client"]), hull, AFT_SEAT))
	_advance(LINK * 2 + 20, _controls({}))
	var fore_before: Vector2 = _server_aim(hull, 0)
	var aft_before: Vector2 = _server_aim(hull, 1)
	_advance(int(1.0 * TICK_HZ), _controls({"pitch": 1.0, "roll": 1.0}))
	_advance(LINK * 2 + 4, _controls({}))
	var fore: Vector2 = _server_aim(hull, 0)
	var aft: Vector2 = _server_aim(hull, 1)
	_check("the_aft_seat_lays_the_aft_turret_and_leaves_the_forward_one",
		seated and fore.distance_to(fore_before) < 0.0001 and aft.distance_to(aft_before) > 0.05,
		"forward moved %.4f rad, aft moved %.4f rad" % [fore.distance_to(fore_before), aft.distance_to(aft_before)])


## SIX KILOMETRES, BY THE FLIGHT: the gunner holds the stick back until the mount stops, fires, and the shell the SERVER
## flies lands within the 2% budget of 6,000 m of the trunnion. Asked for by team-lead on 2026-09-16, because the checks
## above measure the scale against itself at 5 km and the user's number is six: the stop is derived from 6,000 m through
## `shell_reach`, and this is the real shell saying whether that derivation holds -- with the drag, off a floating hull.
func _at_the_elevation_stop_the_shell_lands_six_kilometres_off(aboard: Dictionary, seat: int) -> void:
	var me: int = int(aboard["client"])
	var hull: int = int(aboard["hull"])
	var mount: int = Sim.mount_of_seat(BATTLESHIP, seat)
	var called: String = "forward" if seat == FORWARD_SEAT else "aft"
	_server.seat_client(me, hull, seat)
	_advance(LINK * 2 + 20, _controls({}))
	# THE RELOAD, and the stick hard back for long enough to reach the stop from anywhere: 0.2 rad at 0.07 rad/s is 3 s.
	_advance(int(6.5 * TICK_HZ), _controls({}))
	_advance(int(5.0 * TICK_HZ), _controls({"pitch": 1.0}))
	_advance(LINK * 2 + 4, _controls({}))
	var stop: float = (Sim.gun_of(BATTLESHIP, mount).get("pitch_range", Vector2.ZERO) as Vector2).y
	var laid: float = _server_aim(hull, mount).y
	var seen: Dictionary = {}
	for row in _server.shot_states():
		seen[int(row["entity"])] = true
	var trunnion: Vector3 = (_server.vehicle_state(hull)["position"] as Vector3) \
		+ (Sim.gun_of(BATTLESHIP, mount).get("at", Vector3.ZERO) as Vector3)
	var shell: int = 0
	for i in range(LINK * 2 + 30):
		_advance(1, _controls({"trigger": 1.0}))
		for row in _server.shot_states():
			if not seen.has(int(row["entity"])) and int(row.get("shooter", -1)) == me:
				shell = int(row["entity"])
		if shell != 0:
			break
	var landed: Dictionary = {}
	for i in range(int(25.0 * TICK_HZ)):
		_advance(1, _controls({}))
		var row: Dictionary = _row(_server.shot_states(), shell)
		if not row.is_empty() and not bool(row.get("flying", true)):
			landed = row
			break
	var impact: Vector3 = landed.get("impact", Vector3.INF) as Vector3
	var flat: float = Vector2(impact.x - trunnion.x, impact.z - trunnion.z).length() if not landed.is_empty() else -1.0
	_check("at_the_elevation_stop_the_%s_turrets_shell_lands_six_kilometres_off" % called,
		not landed.is_empty() and absf(laid - stop) < 0.001 and absf(flat - 6000.0) <= 6000.0 * SCALE_AGREES,
		"laid %.3f deg against a stop of %.3f deg; landed %.0f m from the trunnion (%.2f%% off 6,000 m, budget %.0f%%)"
			% [rad_to_deg(laid), rad_to_deg(stop), flat, 100.0 * absf(flat - 6000.0) / 6000.0, SCALE_AGREES * 100.0])


## ---- the wire -------------------------------------------------------------------------------------------------------

func _world_to_ask() -> Object:
	if _server == null:
		_server = ClassDB.instantiate("CockpitWorld")
	return _server


func _server_aim(hull: int, mount: int) -> Vector2:
	var aimed: Array = _server.vehicle_state(hull).get("turrets", []) as Array
	return (aimed[mount] as Vector2) if mount < aimed.size() else Vector2.ZERO


func _row(rows: Array, entity: int) -> Dictionary:
	for row in rows:
		if int((row as Dictionary)["entity"]) == entity:
			return row
	return {}


func _controls(overrides: Dictionary) -> Dictionary:
	var input: Dictionary = {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0,
	}
	for key in overrides:
		input[key] = overrides[key]
	return input


func _advance(ticks: int, input: Dictionary) -> void:
	for i in range(ticks):
		if not input.is_empty():
			_client.set_input(input)
		_tick += 1
		_server.tick(DT)
		_client.tick(DT)
		_pump()


## THE LINK IS REALLY `LINK + 1` TICKS EACH WAY. A packet is delivered in this pump, which runs after BOTH worlds have ticked,
## so the soonest it is read is the next tick: a 16-tick link here is 17 each way (lane/starve, 2026-09-16, which proved it
## off this very pump). Left as it is on purpose -- every figure these suites have recorded was measured through it.
func _pump() -> void:
	for packet in _server.take_outbound():
		_in_flight.append([_tick + LINK, false, int(packet["peer"]), packet["bytes"], packet["bits"]])
	for packet in _client.take_outbound():
		_in_flight.append([_tick + LINK, true, PEER, packet["bytes"], packet["bits"]])
	var still: Array = []
	for entry in _in_flight:
		if entry[0] > _tick:
			still.append(entry)
			continue
		if bool(entry[1]):
			_server.deliver(entry[2], entry[3], entry[4])
		else:
			_client.deliver(0, entry[3], entry[4])
	_in_flight = still


func _finish() -> void:
	for world in [_client, _server]:
		if world != null:
			world.teardown()
	_client = null
	_server = null
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
