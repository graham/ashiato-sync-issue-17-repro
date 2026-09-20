extends Node
## Headless: A GUNNER HOLDS THE TRIGGER AND THE GUN FIRES AT ITS OWN RATE UNTIL THEY LET GO -- through the hand, the
## rig, the input frame and the server, at every kind of gunner's station.
##
##   Godot --headless --path cockpit res://tests/gunners.tscn
##
## ASKED FOR ON 2026-09-13: "take another pass at the gunner stations in the helicopters and ships with machine guns,
## they should be mostly automatic not one shot".
##
## THE REAL PATH, START TO FINISH. The player is put in the craft the way the clipboard asks for one and moved to a
## gunner's seat by the server; the right hand is placed on the gun's own grip every frame and closed; the trigger
## is the controller's trigger, pressed through `force_input`; and what is counted is the rounds the SERVER created
## with this client's name on them, as they arrive in `Sim.shots`. Nothing here calls `fire_gun`. The rate is read
## from the gun table, not written here.
##
## WHAT IT CHECKS, PER STATION: holding for `HOLD_S` gives the gun's rate times that, give or take a round; letting go
## stops it within one reload (and the link's latency); one tap still fires; and the hand on the gun feels every round
## that leaves it, not only the pull.
##
## Read RESULT=, not the exit code.

const RIGHT: int = 1
## The hand the JOYSTICK is in at a powered mount. A gunner there has two things to hold -- the
## stick that lays the gun and the grip that fires it -- which is the whole difference between a
## powered mount and a gun swung by hand, and it is the reason this suite needs both hands.
const LEFT: int = 0
const HOLD_S: float = 2.0
## How late the trigger reaches the server on a solo session, and a frame of slack: the release window allows it.
const LATENCY_S: float = 0.10

## HOW FAR THE HAND PUSHES THE JOYSTICK, in metres: a full deflection, `FlightStick.THROW`.
const SHOVE: float = 0.12
## How long it is held over, in seconds, and how far the mount has to have moved by then. A
## gunship's guns train 0.35 rad either side of rest at 1.2 rad/s, so a second is hard against the
## stop and a twentieth of a radian is a twentieth of what a working mount does in that second.
const TRAVERSE_S: float = 1.0
const TRAVERSED: float = 0.05

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _seen: Dictionary = {}
## The SERVER's own number for the craft this player is in, from `_sit_at`. `VehicleView.entity` is
## this machine's, and the two are different numbers for the same aircraft.
var _craft: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[gunners] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	for i in range(240):
		await get_tree().physics_frame
	var rig: PilotRig = _level.rig
	# EVERY KIND OF GUNNER'S STATION: a door gun, a ship's rail gun, and a gunship's powered 25 mm and 40 mm.
	for station in [
		{"kind": Sim.Kind.HELI, "seat": 2, "role": "stick", "called": "helicopter_door"},
		{"kind": Sim.Kind.GUNBOAT, "seat": 1, "role": "stick", "called": "gunboat_bow"},
		# THE CB90'S TWO AT THE BACK, port and starboard (lane/boats, 2026-09-18).
		{"kind": Sim.Kind.CB90, "seat": 2, "role": "stick", "called": "cb90_port_aft"},
		{"kind": Sim.Kind.CB90, "seat": 3, "role": "stick", "called": "cb90_starboard_aft"},
		# THE BATTLESHIP'S AFT TURRET SEAT WORKS TURRET 3 NOW (plan item 22): a powered mount, a trigger on the console and
		# a joystick, where it had a 12.7 mm rail gun. One shell every six seconds, so its rate is one round a hold.
		{"kind": Sim.Kind.BATTLESHIP, "seat": 3, "role": "trigger", "called": "battleship_aft_turret"},
		{"kind": Sim.Kind.GUNSHIP, "seat": 1, "role": "trigger", "called": "gunship_25mm"},
		{"kind": Sim.Kind.GUNSHIP, "seat": 2, "role": "trigger", "called": "gunship_40mm"},
	]:
		await _a_held_trigger_fires_at_the_guns_rate(rig, station)
	_finish()


func _a_held_trigger_fires_at_the_guns_rate(rig: PilotRig, station: Dictionary) -> void:
	var kind: int = int(station["kind"])
	var seat: int = int(station["seat"])
	var called: String = String(station["called"])
	var mount: int = Sim.mount_of_seat(kind, seat)
	var gun: Dictionary = Sim.gun_of(kind, maxi(mount, 0))
	_check("the_%s_seat_works_a_gun" % called, mount >= 0 and bool(gun.get("fitted", false)),
		"mount %d, fitted %s" % [mount, gun.get("fitted", false)])
	if mount < 0 or not bool(gun.get("fitted", false)):
		return
	var control: VehicleControl = await _sit_at(rig, kind, seat, String(station["role"]))
	_check("and_the_%s_gunner_has_it_in_front_of_them" % called, control != null,
		"%s" % [control])
	if control == null:
		return
	rig.force_grip(RIGHT, 1.0)
	await _hand_on(rig, control, 8)
	_check("and_the_right_hand_takes_hold_of_the_%s" % called, control.held_by == RIGHT,
		"held by %d" % control.held_by)

	var reload: float = float(gun.get("reload", 1.0))
	var tick: float = Sim.tick_dt()
	await _count(rig, control, int(0.3 / tick))
	# NOTHING WITHOUT A FINGER: a hand holding the gun is not a gun firing.
	_check("and_holding_the_%s_without_the_trigger_fires_nothing" % called, await _count(rig, control,
		int(0.3 / tick)) == 0, "rounds while only held")

	rig.forget_pulses()
	rig.force_input(RIGHT, Bind.TRIGGER, 1.0)
	var held: int = await _count(rig, control, int(HOLD_S / tick))
	rig.force_input(RIGHT, Bind.TRIGGER, 0.0)
	var wanted: float = HOLD_S / reload
	_check("holding_the_%s_trigger_fires_its_rate_for_as_long_as_it_is_held" % called,
		absf(float(held) - wanted) <= 1.5,
		"%d rounds in %.1f s, wanted %.1f (one every %.3f s)" % [held, HOLD_S, wanted, reload])

	# LETTING GO STOPS IT: at most the round already loaded and on its way through the link, and nothing after one
	# reload and the latency.
	var straight_after: int = await _count(rig, control, int((reload + LATENCY_S) / tick))
	var later: int = await _count(rig, control, int(maxf(0.5, reload) / tick))
	_check("and_letting_go_of_the_%s_stops_it_within_one_round" % called, straight_after <= 1 and later == 0,
		"%d in the first reload after, %d after that" % [straight_after, later])
	# EVERY ROUND IS FELT, in the hand that holds the gun. One kick per PULL was the gun that felt like one shot.
	var felt: int = rig.pulses(&"round")
	_check("and_the_hand_on_the_%s_feels_every_round_not_just_the_pull" % called,
		absi(felt - (held + straight_after)) <= 1, "%d kicks for %d rounds" % [felt, held + straight_after])

	# AND ONE TAP STILL FIRES ONE.
	rig.force_input(RIGHT, Bind.TRIGGER, 1.0)
	var tapped: int = await _count(rig, control, 1)
	rig.force_input(RIGHT, Bind.TRIGGER, 0.0)
	tapped += await _count(rig, control, int((reload + LATENCY_S + 0.2) / tick))
	_check("and_a_single_tap_on_the_%s_still_fires" % called, tapped >= 1, "%d rounds from one frame" % tapped)

	rig.force_input(RIGHT, Bind.TRIGGER, null)
	await _let_go(rig, control)
	# AND A POWERED MOUNT IS LAID WITH THE OTHER HAND.
	if String(station["role"]) == "trigger":
		await _a_joystick_lays_the_gun(rig, kind, seat, mount, called)


## THE JOYSTICK IN FRONT OF A POWERED MOUNT TRAVERSES THAT MOUNT, and not one of the others.
##
## ASKED ABOUT ON 2026-09-15: "the cannons in planes that are controlled by joysticks don't seem to
## work." A gunship is the only PLANE in the game with cannons and they are the only ones laid with
## a stick rather than by hand (`tests/_probe`-style walk of `Sim.gun_of`: heli, chinook, gunboat,
## carrier and battleship are all `pintle`, the tank and the gunship are not), so this is what that
## sentence can be about. The firing half is above; this is the laying half, and it had no check at
## all -- `gunners` held the trigger and counted rounds, and nothing anywhere put a hand on the
## stick beside it.
##
## THE REAL PATH: the left hand closes on the stick the station fitted, is pushed a full deflection
## sideways, and what is read is the SERVER's own mount angle.
func _a_joystick_lays_the_gun(rig: PilotRig, kind: int, seat: int, mount: int,
		called: String) -> void:
	var view: VehicleView = rig.vehicle_view()
	var station: CockpitStation = view.station_for(seat) if view != null else null
	var stick := (station.controls().get("stick") if station != null else null) as FlightStick
	_check("the_%s_gunner_has_a_joystick_as_well_as_a_trigger" % called, stick != null,
		"%s" % [stick])
	if stick == null:
		return
	rig.force_grip(LEFT, 1.0)
	for i in range(8):
		rig.force_hand(LEFT, Transform3D(Basis.IDENTITY, stick.grip_global()))
		await get_tree().physics_frame
	_check("and_the_left_hand_takes_hold_of_the_%s_joystick" % called, stick.held_by == LEFT,
		"held by %d" % stick.held_by)
	if stick.held_by != LEFT:
		rig.force_hand(LEFT, null)
		rig.force_grip(LEFT, -1.0)
		return

	# HARD OVER, MEASURED IN THE STICK'S OWN FRAME. A hand handed a world pose once is a hand left
	# behind in the sky -- the aircraft is doing 90 m/s -- so it is placed again every frame from
	# where the stick is now. See `tests/crew_sync.gd`, which paid for that lesson.
	var pushed: Vector3 = stick._grab_point() + Vector3(SHOVE, 0.0, 0.0)
	var before: Array = Sim.server.vehicle_state(_craft).get("turrets", []) as Array
	for i in range(int(TRAVERSE_S / Sim.tick_dt())):
		rig.force_hand(LEFT, Transform3D(Basis.IDENTITY, stick.global_transform * pushed))
		await get_tree().physics_frame
	var after: Array = Sim.server.vehicle_state(_craft).get("turrets", []) as Array
	var moved: Array[int] = []
	for i in range(mini(before.size(), after.size())):
		if absf(angle_difference((before[i] as Vector2).x, (after[i] as Vector2).x)) > TRAVERSED:
			moved.append(i)
	_check("and_pushing_the_%s_joystick_traverses_its_own_gun" % called, moved == [mount],
		"stick at %.2f roll; mounts that moved: %s, wanted [%d]" % [stick.roll(), moved, mount])
	rig.force_grip(LEFT, 0.0)
	for i in range(6):
		rig.force_hand(LEFT, Transform3D(Basis.IDENTITY, stick.grip_global()))
		await get_tree().physics_frame
	rig.force_hand(LEFT, null)
	rig.force_grip(LEFT, -1.0)


## THIS PLAYER, AT `seat` OF A CRAFT OF `kind`: asked for the way the clipboard asks, then moved by the server, and the
## control in `role` at that seat once the rig has claimed it -- or null.
func _sit_at(rig: PilotRig, kind: int, seat: int, role: String) -> VehicleControl:
	var view: VehicleView = rig.vehicle_view()
	if view == null or view.kind != kind:
		rig.ask_for_kind(kind)
		for i in range(900):
			await get_tree().physics_frame
			view = rig.vehicle_view()
			if view != null and view.kind == kind:
				break
	if view == null or view.kind != kind:
		return null
	# THE SERVER'S NUMBER FOR THE CRAFT, from the server's own pilot list: `view.entity` is this machine's, and the first
	# run of this handed it to `seat_client`, which refused it without a word -- the one seat that passed was the one
	# the player had been issued anyway.
	var craft: int = 0
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", -1)) == Sim.local_client_id():
			craft = int((pilot as Dictionary).get("vehicle", 0))
	_craft = craft
	var moved: bool = rig.seat_index() == seat or bool(Sim.server.seat_client(Sim.local_client_id(), craft, seat))
	if not moved:
		print("[gunners] the server would not seat client %d at seat %d of %d" % [Sim.local_client_id(), seat, craft])
		return null
	for i in range(300):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and rig.seat_index() == seat and view.station_for(seat) != null:
			var control := view.station_for(seat).controls().get(role) as VehicleControl
			if control != null and (control is PintleGun or control is GunTrigger):
				return control
	return null


## How many rounds this client's gun started over `frames` physics frames, with the hand put back on the grip every
## frame: the craft moves under a hand placed once (see agents.md).
func _count(rig: PilotRig, control: VehicleControl, frames: int) -> int:
	var born: int = 0
	for i in range(maxi(frames, 1)):
		rig.force_hand(RIGHT, Transform3D(Basis.IDENTITY, control.grip_global()))
		await get_tree().physics_frame
		for row in Sim.shots:
			var shot: Dictionary = row
			var entity: int = int(shot.get("entity", 0))
			if _seen.has(entity) or int(shot.get("shooter", -1)) != Sim.local_client_id():
				continue
			_seen[entity] = true
			born += 1
	return born


func _hand_on(rig: PilotRig, control: VehicleControl, frames: int) -> void:
	for i in range(frames):
		rig.force_hand(RIGHT, Transform3D(Basis.IDENTITY, control.grip_global()))
		await get_tree().physics_frame


## LET GO, AS A SQUEEZE ENDS AND NOT AS A TAP -- the latch is timed on the wall clock. See `tests/shared_controls.gd`.
func _let_go(rig: PilotRig, control: VehicleControl) -> void:
	var closed_at: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - closed_at < int((PilotRig.TAP_SECONDS + 0.15) * 1000.0):
		await _hand_on(rig, control, 1)
	rig.force_grip(RIGHT, 0.0)
	await _hand_on(rig, control, 4)
	rig.force_hand(RIGHT, null)
	rig.force_grip(RIGHT, -1.0)


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
