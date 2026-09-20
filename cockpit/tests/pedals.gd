extends Node
## Headless: RUDDER PEDALS SHOW WHERE THE RUDDER IS, whatever put it there, at every seat that flies an aircraft with one.
##
##   Godot --headless --path cockpit res://tests/pedals.tscn
##
## Asked for on 2026-09-13: "a floor rudder pedals model and device, that way we can determine where the rudder should be".
## `RudderPedals` draws the rudder and never decides it, so every check here moves the rudder by something a person
## touches -- the desk's Q key as a key event with both codes set, and a wrist turned on the stick through the rig's own
## hand pass (`force_hand`, `force_grip`) -- and reads the pedals back.
##
## A FORCED HAND IS A WORLD POSE AND THE AEROPLANE IS MOVING, so every hand here is placed again on every physics frame
## from the stick's own transform, and a grip is let go of as a squeeze and not as a tap (see tests/shared_controls.gd,
## and cockpit/agents.md "Tap the grip to latch it").
##
## ONE PROCESS, EVERY SEAT. `VehicleView.man` builds a station at every seat of a manned craft, so the airliner's
## copilot's pedals exist here and are drawn by the same line that draws the pilot's pedals on the copilot's own machine:
## the seat that is not this player's, from the linkage.
##
## THE PLAYER'S OWN LAYOUT IS PUT BACK. The save-and-reload section writes the plane's pilot seat file in `user://`, which
## is where a real one lives, so whatever was there is read first and written back after.
##
## Read RESULT=, not the exit code.

const RIGHT: int = 1
## How long anything is given to show, in physics frames: half a second at 120 Hz. A pedal follows the frame it was
## handed on the next render frame, so this is margin and not a rate.
const PATIENCE: int = 60
## "Within a few frames": the brief the pedals were built to.
const FEW: int = 6
## How near a pedal has to be to where it should be, in metres. A tenth of a millimetre over `RudderPedals.EASE`'s gate.
const NEAR: float = 0.0002
## Frames a rudder is left alone to show that nothing is written.
const IDLE_FRAMES: int = 60
## How far the wrist turns on the stick, in radians: 23 degrees clockwise seen from above, the turn smoke.gd uses.
const WRIST: float = -0.4
## HOW MANY CONSECUTIVE QUIET FRAMES COUNT AS A LINKAGE AT REST. Ten at 120 Hz is 83 ms, which is
## comfortably longer than the two frames a stale value takes to be replaced by the real one and far
## shorter than the patience around it. One frame is not enough; see the note where it is used.
const QUIET_FRAMES: int = 10

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _sections: int = 0
const SECTIONS: int = 8


func _check(label: String, ok: bool, detail: String) -> void:
	print("[pedals] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_pedals_are_fitted_where_there_is_a_rudder_and_nowhere_else()
	_a_resting_device_yields_and_a_pushed_one_wins()
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(240):
		await get_tree().physics_frame
	var rig: PilotRig = _level.rig
	if not await _the_player_gets_into(rig, Sim.Kind.PLANE):
		_finish()
		return
	await _q_puts_the_left_pedal_forward_and_letting_go_centres_both(rig)
	await _a_wrist_turned_on_the_stick_moves_the_pedals_by_the_same_rule(rig)
	await _a_rudder_nobody_moves_writes_nothing(rig)
	await _saved_and_built_again_they_come_back_where_they_were(rig)
	if await _the_player_gets_into(rig, Sim.Kind.AIRLINER):
		await _the_copilots_pedals_follow_the_pilots_rudder(rig)
	_check("every_section_of_the_suite_ran", _sections == SECTIONS, "%d of %d" % [_sections, SECTIONS])
	_finish()


## ---- where they are fitted -------------------------------------------------------------------

## PEDALS AT A SEAT THAT FLIES SOMETHING WITH A RUDDER, AND NOWHERE ELSE, on the whole craft built as it is flown.
##
## WHICH SEATS FLY is read off the station itself, by what `fit` gave a seat that does NOT: two multi-function displays,
## or -- at a door gunner's seat, which gets no screens -- the gun in place of a column. Those are other fitting decisions
## made from the same seat table, so a pedal rule that forgot the seat would put pedals beside the screens or the gun and
## this would say so. The first run counted screens alone and failed the helicopter's two door gunners. Which craft have a rudder is written out here, by name, on purpose.
func _pedals_are_fitted_where_there_is_a_rudder_and_nowhere_else() -> void:
	var with_rudder: PackedStringArray = ["plane", "cessna", "glider", "airliner", "heli", "osprey"]
	var without: PackedStringArray = ["pod", "car", "boat", "train", "tank"]
	var wrong: PackedStringArray = []
	var fitted: int = 0
	for name in with_rudder + without:
		var view := _craft(name)
		if view == null:
			wrong.append("%s: no scene" % name)
			continue
		for seat in range(view.seats.size()):
			var station: CockpitStation = view.station_for(seat)
			if station == null:
				continue
			var pedals: RudderPedals = _pedals_in(station)
			var screens: bool = station.get_node_or_null("MfdLeft") != null or station._stick() is PintleGun
			var wanted: bool = with_rudder.has(name) and not screens
			if (pedals != null) != wanted:
				wrong.append("%s seat %d: pedals %s, screens or a gun %s" % [name, seat, pedals != null, screens])
			if pedals == null:
				continue
			fitted += 1
			# IN THE FOOTWELL, UNDER THE FLYING CONTROL AND FORWARD OF IT, on the floor -- THE STATION'S OWN FLOOR, which a craft
			# may lift (`CockpitShell.footwell_raise`: the Little Bird's 0.20, the Duo Discus's reclined 0.70). "On the floor"
			# was typed as 0.10 m over the anchor until 2026-09-19, when the pedals moved onto the raised floor their feet are
			# on and this went red on the glider (lane/sailplane).
			var column: VehicleControl = station._stick()
			var shell := station.get_node_or_null("Shell") as CockpitShell
			var floor_top: float = CockpitStation.FLOOR + (shell.footwell_raise if shell != null else 0.0)
			if column != null and (absf(pedals.position.x - column.position.x) > 0.001
					or pedals.position.z >= column.position.z or absf(pedals.position.y - floor_top) > 0.06):
				wrong.append("%s seat %d: pedals at %s, the column at %s" % [name, seat, pedals.position,
					column.position])
			if pedals.scope != VehicleControl.Scope.SEAT:
				wrong.append("%s seat %d: scope %d" % [name, seat, pedals.scope])
		view.queue_free()
	_check("pedals_are_fitted_at_every_flying_seat_with_a_rudder_under_its_column_and_nowhere_else",
		wrong.is_empty() and fitted >= with_rudder.size(),
		"%d fitted" % fitted if wrong.is_empty() else "\n      ".join(wrong))
	_sections += 1


## THE SEAM A USB PEDAL AXIS WILL COME IN AT, in the order it is promised: a device pushed past its dead zone beats a
## twisted stick, a device resting at centre does not zero one, and no device at all leaves the hands and keys as they
## were. The device itself is not here yet -- see agents.md, WHAT IS NOT HERE YET.
func _a_resting_device_yields_and_a_pushed_one_wins() -> void:
	var pushed: float = PilotRig.rudder_demand(-0.7, 0.4, 0.0)
	var resting: float = PilotRig.rudder_demand(0.0, 0.4, 1.0)
	var none: float = PilotRig.rudder_demand(null, null, -1.0)
	_check("a_pushed_pedal_device_beats_a_twisted_stick_and_a_resting_one_yields",
		pushed == -0.7 and resting == 0.4 and none == -1.0,
		"pushed %.2f, resting %.2f, none %.2f" % [pushed, resting, none])
	_sections += 1


## ---- in the plane --------------------------------------------------------------------------------

## Q HELD: THE LEFT PEDAL FORWARD BY THE FULL TRAVEL AND THE RIGHT ONE BACK, within a few frames; Q released: both home.
## Forward is -Z in the station's frame, which is what a pilot's foot pushes towards.
func _q_puts_the_left_pedal_forward_and_letting_go_centres_both(rig: PilotRig) -> void:
	var pedals: RudderPedals = _pedals_in(rig.vehicle_view().station_for(rig.seat_index()))
	if pedals == null:
		_check("the_pilot_has_pedals", false, "none at seat %d" % rig.seat_index())
		_sections += 1
		return
	var code: Key = _key_of("yaw_left")
	_key(code, true)
	var down: int = await _frames_until(func() -> bool:
		return _near(pedals, -RudderPedals.TRAVEL, RudderPedals.TRAVEL))
	_check("holding_q_puts_the_left_pedal_forward_and_the_right_one_back_by_the_full_travel",
		down >= 0 and down <= FEW, "%d frames, left %+.4f m right %+.4f m" % [down, _z(pedals, true), _z(pedals, false)])
	_key(code, false)
	var home: int = await _frames_until(func() -> bool: return _near(pedals, 0.0, 0.0))
	_check("and_letting_go_of_q_brings_both_back_to_centre", home >= 0 and home <= FEW,
		"%d frames, left %+.4f m right %+.4f m" % [home, _z(pedals, true), _z(pedals, false)])
	_sections += 1


## A WRIST TURNED CLOCKWISE ON THE STICK IS RIGHT RUDDER, so the RIGHT pedal goes forward -- and by the rudder the frame
## carried, on the same TRAVEL the key used. The sign is pinned to the wrist and not to the pedals' own arithmetic.
func _a_wrist_turned_on_the_stick_moves_the_pedals_by_the_same_rule(rig: PilotRig) -> void:
	var station: CockpitStation = rig.vehicle_view().station_for(rig.seat_index())
	var stick: VehicleControl = station._stick()
	var pedals: RudderPedals = _pedals_in(station)
	if stick == null or pedals == null:
		_check("the_pilot_has_a_stick_and_pedals", false, "stick %s, pedals %s" % [stick, pedals])
		_sections += 1
		return
	# SETTLE THE LINKAGE FIRST, AND SAY SO. This section measures a wrist turn FROM WHERE THE STICK
	# IS: `_turn` takes its zero from `twist` at the moment of the grab. The section before it holds
	# Q to full left rudder, and the stick's twist now shows the LINKAGE at every seat including
	# this one -- so for a round trip after the key comes up the stick is still hard over, and a
	# wrist turned from there reads 0.73 - 1.00 = -0.27.
	#
	# ON THE LINKAGE AND NOT ON THE STICK, which is the part that cost an hour. Waiting for
	# `stick.rudder()` to read zero passes IMMEDIATELY -- the spring has already pulled the stick
	# back -- while the wire is still carrying -1, and the very next frame the draw puts it there
	# again and the hand closes on it. Measured: `linked_rudder` reads -1.00 for two more frames
	# after the pedals have centred, and is flat at 0.00 for the fifty-eight after that. Ask the
	# thing that is late, not the thing that is quick.
	# QUIET FOR A RUN OF FRAMES, and not quiet ONCE, which is the other half of the same lesson.
	# The moment the key comes up the linkage still carries the value it had BEFORE the key went
	# down -- zero -- and the -1 arrives a round trip later; a wait for "it reads zero" therefore
	# returns on frame 0 and hands the grab a stick that is about to be thrown hard over. Measured:
	# 0.00, then -1.00 for two frames, then 0.00 for the fifty-eight after that.
	var quiet: int = 0
	var waited: int = 0
	while quiet < QUIET_FRAMES and waited < PATIENCE * 4:
		await get_tree().physics_frame
		waited += 1
		var linked: float = absf(float(Sim.client.crew_controls(
			rig.vehicle_view().entity).get("linked_rudder", 9.0)))
		quiet = quiet + 1 if linked < 0.02 else 0
	_check("the_linkage_is_back_at_centre_before_a_wrist_is_measured_from_the_stick",
		quiet >= QUIET_FRAMES, "%d quiet frames out of %d waited, stick twist %+.2f"
			% [quiet, waited, stick.rudder()])
	var grip: Vector3 = stick._grab_point()
	rig.force_grip(RIGHT, 1.0)
	for i in range(6):
		_hold_the_stick(rig, stick, grip, 0.0)
		await get_tree().physics_frame
	var held: bool = stick.held_by == RIGHT
	for i in range(FEW):
		_hold_the_stick(rig, stick, grip, WRIST)
		await get_tree().physics_frame
	var rudder: float = rig.rudder_sent()
	# ONE MORE RENDER FRAME, in which the level draws what that frame carried.
	_hold_the_stick(rig, stick, grip, WRIST)
	await get_tree().process_frame
	_check("a_wrist_turned_clockwise_on_the_stick_puts_the_right_pedal_forward",
		held and stick.rudder() > 0.5 and absf(rudder - stick.rudder()) < 0.01 and _z(pedals, false) < -0.04,
		"held %s, stick %.2f, frame %.2f, right pedal %+.4f m" % [held, stick.rudder(), rudder, _z(pedals, false)])
	_check("and_by_the_rudder_the_frame_carried_times_the_same_travel_as_the_key",
		_near(pedals, rudder * RudderPedals.TRAVEL, -rudder * RudderPedals.TRAVEL),
		"left %+.4f right %+.4f against %+.4f" % [_z(pedals, true), _z(pedals, false), rudder * RudderPedals.TRAVEL])
	await _let_go(rig, stick, grip)
	var home: int = await _frames_until(func() -> bool: return _near(pedals, 0.0, 0.0), PATIENCE * 2)
	_check("and_the_stick_let_go_centres_the_pedals_as_it_centres", home >= 0 and stick.held_by < 0,
		"%d frames, held by %d" % [home, stick.held_by])
	_sections += 1


## A RUDDER NOBODY MOVES COSTS NOTHING: every pair of pedals aboard, sixty frames, no transform written.
func _a_rudder_nobody_moves_writes_nothing(rig: PilotRig) -> void:
	var view: VehicleView = rig.vehicle_view()
	for i in range(PATIENCE):
		await get_tree().physics_frame
	var aboard: Array = []
	for seat in view.manned_seats():
		var pedals: RudderPedals = _pedals_in(view.station_for(int(seat)))
		if pedals != null:
			aboard.append(pedals)
	var before: int = _writes(aboard)
	for i in range(IDLE_FRAMES):
		await get_tree().physics_frame
	var idle: int = _writes(aboard) - before
	_check("pedals_left_alone_for_%d_frames_write_nothing" % IDLE_FRAMES, idle == 0 and not aboard.is_empty(),
		"%d writes across %d pairs" % [idle, aboard.size()])
	_sections += 1


## SAVED, THE STATION THROWN AWAY AND BUILT AGAIN THE WAY THE GAME BUILDS IT, and the pedals come back where they were put
## and still the seat's. Moved first, so a station that ignored the file and fitted them afresh cannot pass.
func _saved_and_built_again_they_come_back_where_they_were(rig: PilotRig) -> void:
	var view: VehicleView = rig.vehicle_view()
	var seat: int = rig.seat_index()
	var station: CockpitStation = view.station_for(seat)
	var pedals: RudderPedals = _pedals_in(station)
	if pedals == null:
		_check("the_pilot_has_pedals_to_save", false, "none")
		_sections += 1
		return
	var path: String = CockpitLayout.path_for(view.kind, seat)
	var theirs: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var moved_to: Vector3 = pedals.position + Vector3(0.03, 0.0, -0.05)
	pedals.position = moved_to
	var name: String = String(pedals.name)
	var written: String = CockpitLayout.write(view.kind, seat, station)
	var entry: Dictionary = {}
	for one in (CockpitLayout.read(view.kind, seat).get("controls", []) as Array):
		if String((one as Dictionary).get("name", "")) == name:
			entry = one
	view.rebuild_station(seat)
	var again: RudderPedals = null
	for i in range(PATIENCE * 4):
		await get_tree().physics_frame
		var rebuilt: CockpitStation = view.station_for(seat)
		if rebuilt != null and rebuilt != station and is_instance_valid(rebuilt):
			again = _pedals_in(rebuilt)
			if again != null:
				break
	_check("saved_the_pedals_are_written_down_as_the_seats",
		not written.is_empty() and String(entry.get("part", "")) == "RudderPedals"
			and String(entry.get("scope", "")) == "seat",
		"%s: %s" % [written, entry])
	_check("and_built_again_they_come_back_where_they_were_put_and_still_the_seats",
		again != null and again.position.distance_to(moved_to) < 0.002 and again.scope == VehicleControl.Scope.SEAT,
		"at %s against %s, scope %s" % [again.position if again != null else "gone", moved_to,
			again.scope if again != null else "-"])
	# THE PLAYER'S OWN FILE BACK, or none if there was none.
	if theirs.is_empty():
		CockpitLayout.forget(view.kind, seat)
	else:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(theirs)
		file.close()
	view.rebuild_station(seat)
	for i in range(PATIENCE):
		await get_tree().physics_frame
	_sections += 1


## ---- in the airliner -----------------------------------------------------------------------------

## THE PILOT HOLDS Q, AND THE COPILOT'S PEDALS GO OVER WITH THE PILOT'S -- through the linkage, which is what a seat that
## is not this player's is drawn from. Waited on rather than counted, because the linkage is the server's and comes back.
func _the_copilots_pedals_follow_the_pilots_rudder(rig: PilotRig) -> void:
	var view: VehicleView = rig.vehicle_view()
	var mine: int = rig.seat_index()
	var theirs: RudderPedals = null
	for seat in view.manned_seats():
		if int(seat) != mine and _pedals_in(view.station_for(int(seat))) != null:
			theirs = _pedals_in(view.station_for(int(seat)))
			break
	if theirs == null:
		_check("the_airliner_has_a_second_seat_with_pedals", false, "seats %s" % [view.manned_seats()])
		_sections += 1
		return
	var code: Key = _key_of("yaw_left")
	_key(code, true)
	var over: int = await _frames_until(func() -> bool:
		return _near(theirs, -RudderPedals.TRAVEL, RudderPedals.TRAVEL, 0.004))
	_check("the_pilot_holding_q_puts_the_copilots_left_pedal_forward_too", over >= 0,
		"seat %d, %d frames, left %+.4f m right %+.4f m" % [theirs.seat, over, _z(theirs, true), _z(theirs, false)])
	_key(code, false)
	var home: int = await _frames_until(func() -> bool: return _near(theirs, 0.0, 0.0, 0.004))
	_check("and_back_to_centre_when_the_pilot_lets_go", home >= 0,
		"%d frames, left %+.4f m" % [home, _z(theirs, true)])
	_sections += 1


## ---- helpers -------------------------------------------------------------------------------------

func _the_player_gets_into(rig: PilotRig, kind: int) -> bool:
	rig.ask_for_kind(kind)
	var view: VehicleView = null
	for i in range(900):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and view.kind == kind and rig.seat_index() == 0:
			break
	var ok: bool = view != null and view.kind == kind and rig.seat_index() == 0
	_check("the_player_gets_into_a_%s_at_its_pilot_seat" % Sim.kind_name(kind), ok,
		"kind %s, seat %d" % [view.kind if view != null else "-", rig.seat_index()])
	for i in range(30):
		await get_tree().physics_frame
	_sections += 1 if kind == Sim.Kind.PLANE else 0
	return ok


func _craft(name: String) -> VehicleView:
	var scene := load("res://objects/vehicles/craft_%s.tscn" % name) as PackedScene
	if scene == null:
		return null
	var view := scene.instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	return view


func _pedals_in(station: CockpitStation) -> RudderPedals:
	if station == null:
		return null
	for child in station.get_children():
		if child is RudderPedals:
			return child
	return null


## Where one pedal is along its rail, in metres, -Z forward.
func _z(pedals: RudderPedals, left: bool) -> float:
	return (pedals._left if left else pedals._right).position.z


func _near(pedals: RudderPedals, left: float, right: float, within: float = NEAR) -> bool:
	return absf(_z(pedals, true) - left) < within and absf(_z(pedals, false) - right) < within


func _writes(aboard: Array) -> int:
	var total: int = 0
	for pedals in aboard:
		total += (pedals as RudderPedals).writes
	return total


## THE HAND ON THE GRIP, turned `wrist` about the stick's own up, placed again from the stick's transform now.
func _hold_the_stick(rig: PilotRig, stick: VehicleControl, grip: Vector3, wrist: float) -> void:
	rig.force_hand(RIGHT, Transform3D(stick.global_basis * Basis(Vector3.UP, wrist), stick.to_global(grip)))


## LET GO AS A SQUEEZE ENDS, and tap once more if it latched. See tests/shared_controls.gd's `_let_go`.
func _let_go(rig: PilotRig, stick: VehicleControl, grip: Vector3) -> void:
	var closed_at: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - closed_at < int((PilotRig.TAP_SECONDS + 0.15) * 1000.0):
		_hold_the_stick(rig, stick, grip, WRIST)
		await get_tree().physics_frame
	rig.force_grip(RIGHT, 0.0)
	for i in range(4):
		_hold_the_stick(rig, stick, grip, WRIST)
		await get_tree().physics_frame
	if stick.held_by == RIGHT:
		rig.force_grip(RIGHT, 1.0)
		for i in range(2):
			_hold_the_stick(rig, stick, grip, WRIST)
			await get_tree().physics_frame
		rig.force_grip(RIGHT, 0.0)
		for i in range(4):
			_hold_the_stick(rig, stick, grip, WRIST)
			await get_tree().physics_frame
	rig.force_hand(RIGHT, null)
	rig.force_grip(RIGHT, -1.0)


func _frames_until(cond: Callable, frames: int = PATIENCE) -> int:
	for i in range(frames):
		if bool(cond.call()):
			return i
		await get_tree().physics_frame
	return -1


func _key_of(action: String) -> Key:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	_check("the_%s_action_is_bound_to_a_key" % action, false, "nothing bound")
	return KEY_NONE


func _key(code: Key, down: bool) -> void:
	if code == KEY_NONE:
		return
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = down
	Input.parse_input_event(press)


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL " + ", ".join(_failures))
	get_tree().quit()
