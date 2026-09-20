extends Node
## Headless: A BATTLESHIP SHELL IS PREDICTED BY THE GUNNER WHO FIRED IT, and every other claim that makes prediction honest.
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/shell_prediction.tscn
##
## Plan item 22, the user's sentence: "projectiles must be synced and predicted by ashiato." SYNCED is 22a: the shell is a
## server entity with a birth record every machine flies identically (tests/big_guns.gd). PREDICTED is this: the gunner's
## own machine fires the shell the tick the trigger is pulled, through ashiato's predicted cues on the gunner's own
## predicted entity, and the server's answer confirms it or takes it back. Team-lead's four conditions (2026-09-16):
##
##   1. RED FIRST on the two properties that matter -- a rollback across the fire frame neither fires twice nor loses the
##      shot, and a server that disagrees with the fire takes the drawn shell back -- over links of 0, 4 and 16 ticks.
##   2. THE HANDOVER CANNOT BE SEEN: when the server's shell arrives, the drawn one and it differ by less than a stated
##      tolerance, measured, and the difference is blended, not popped.
##   3. The landing agreement at range -- held by tests/big_guns.gd.
##   4. The sea-surface burst -- held by tests/big_guns.gd.
##
## WHAT IS REAL. A server and a client `CockpitWorld` and a link the test carries the packets over, as tests/big_guns.gd
## and addon/tests/cockpit_loopback do. The client sits in a turret seat and uses its own input frame: stick, trigger,
## the seat button. The drawing is the game's own `ShotYard`, handed what `Sim` would hand it each tick.
##
## THE ROLLBACK IS A REAL ONE, NOT A FORCED ONE. There is no call that makes a client resimulate, and there should not be:
## a rollback is what a client does when the server saw a different input than it predicted with. So the link holds the
## client's packets for a handful of ticks while its stick is MOVING, just before the trigger -- the server reaches
## those frames without them and lays the turret on the old stick -- and holds the SERVER'S packets over the same ticks,
## so the client learns it was wrong about those frames only after it has fired, and replays across the fire. Without the
## second hold, a client two frames ahead (the 0-tick link) learned of the misprediction before it pulled the trigger.
##
## AND OVER THE 0-TICK LINK NO ROLLBACK COULD BE PROVOKED AT ALL: twelve ticks of the client's packets held, and the
## server's held twenty-four ticks behind them, gave 0 resimulations (2026-09-16). So at 0 ticks "a rollback replays
## across the fire" is PRINTED as that measurement rather than checked, and the shell is still held to "neither fired
## twice nor lost". A future change that makes a 0-tick rollback possible turns the print back into the check.
##
## Read RESULT=, not the exit code.

const TICK_HZ: float = 120.0
const DT: float = 1.0 / TICK_HZ
const PEER: int = 2
const POD: int = 0
const BATTLESHIP: int = 13
const FORWARD_SEAT: int = 2
## The aft turret seat: its next seat is the pilot's, which has no gun, so the seat button takes a gunner away from any.
const AFT_SEAT: int = 3
## `Sim.BUTTON_SEAT`: the next seat in this craft, which the server acts on and the gunner's machine cannot.
const BUTTON_SEAT: int = 1
## The links, in ticks each way: a machine next door, cockpit_loopback's, and a long one (267 ms round trip).
const LINKS: Array[int] = [0, 4, 16]
## The elevation fired at, radians: an arc long enough to be handed over mid-flight.
const ELEVATION: float = 0.12
## THE HANDOVER BUDGET. The gap between the drawn shell and the server's at the moment it is handed over, metres, and the
## most the drawn shell may move in one tick beyond its own flight while the gap is blended away, metres. A 406 mm shell
## at 400 m/s moves 3.3 m a tick, and a gunner watching it from its own turret sees it at tens to thousands of metres.
const HANDOVER_GAP_M: float = 3.0
const HANDOVER_STEP_M: float = 0.25
## THE LINK WHERE A ROLLBACK CROSSES AN ON-TIME FIRE, which section 3 holds strictly. MEASURED, NOT DERIVED: at this link,
## through the same holds, the server fired on the gunner's own frame (the cue played once, taken back never) and a
## rollback the holds provoked replayed across that frame; at 4 ticks the holds still make the trigger late (played 2,
## taken back 1), so there the claim is the one the server and the gunner can count (section 3's note).
##
## UNTIL lane/starve's fix (2026-09-16, ashiato-sync-send-newest-inputs-first.patch) THIS LINK WAS THE INPUT STARVATION:
## ashiato-sync truncated each input packet at the 1,200-byte MTU and at 31 frames, the server ran every frame five
## behind the input it needed, and the first shell was played 6 times and taken back 5 ("server_mismatch"), with the drawn
## shell pulled 16 m onto the server's. With the fix the same link reads: server shells 1 (matched), cue played 1,
## withdrawn 0; a rollback window 1614..1647 across the fire frame 1619 with played 1, withdrawn 0; and the handover gap
## 0.00 m, 0.004 m worst step. Section 2 is strict at every link again.
const ON_TIME_ROLLBACK_LINK: int = 16
## THE LONGEST A SHELL THE SERVER REFUSED MAY STAY ON SCREEN after the refusal reaches the gunner, seconds, whatever the
## yard's grace is set to: the grace is the yard's number and this is the suite's, so a grace raised past it fails here
## rather than being read back as its own allowance.
const REFUSED_SHOWN_S: float = 0.1
## How long the ship is under way before the shots, so the muzzle is moving as a real one does.
const UNDER_WAY: Vector3 = Vector3(0.0, 0.0, -8.0)

var _failures: PackedStringArray = []
var _server: RefCounted = null
var _client: RefCounted = null
var _tick: int = 0
var _in_flight: Array = []
## Ticks during which the client's packets are held back, and how long they are held.
var _hold_from: int = -1
var _hold_until: int = -1
var _hold_extra: int = 0
## And the server's packets to the client, held over their own ticks for longer: see the note at the top.
var _down_from: int = -1
var _down_until: int = -1
var _down_extra: int = 0
## Every predicted shell cue the client's cue runtime took back, by the reason its trace gave. Printed as a measurement.
var _withdrawal_reasons: Dictionary = {}
## Every shell cue this client has drained, in order.
var _cues: Array = []
## EVERY ROLLBACK WINDOW the client replayed, [first, last] frame, read off `resim_stats` each tick: a check on the last
## window alone missed a rollback that did span the fire when a later, shorter one followed it.
var _windows: Array = []
var _resims_seen: int = 0
## Whether the server was built able to trace what it sends. See `_a_pilot_at_no_predicted_gun_sends_no_gunner_state`.
var _server_traces: bool = false


func _check(label: String, ok: bool, detail: String) -> void:
	print("[shell_prediction] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_the_shell_number_cannot_wrap_while_its_shells_are_in_the_air()
	for link in LINKS:
		var aboard: Dictionary = _aboard(link)
		if aboard.is_empty():
			continue
		var wired: bool = _client.has_method("shell_cues")
		_check("the_library_predicts_shells_over_a_%d_tick_link" % link, wired, "CockpitWorld.shell_cues")
		if wired:
			var shell: Dictionary = _the_gunner_sees_the_shell_leave_at_once(link, aboard)
			if not shell.is_empty():
				_the_server_agrees_and_it_is_one_shell(link, aboard, shell)
			_a_rollback_across_the_fire_frame_neither_doubles_nor_loses_it(link, aboard)
			_a_server_that_disagrees_takes_the_shell_back(link, aboard)
			_aboard_again(link, aboard)
			_the_handover_cannot_be_seen(link, aboard)
			if link == 4:
				_a_pilot_at_no_predicted_gun_sends_no_gunner_state(link, aboard)
			print("[shell_prediction] measure: over a %d tick link every predicted shell cue taken back, by reason: %s"
				% [link, _withdrawal_reasons])
		_teardown()
	_finish()


## ---- 1. predicted at once ------------------------------------------------------------------------------------------

func _the_gunner_sees_the_shell_leave_at_once(link: int, aboard: Dictionary) -> Dictionary:
	_lay(link, ELEVATION)
	var pressed_at: int = _tick
	var played: Dictionary = {}
	for i in range(link * 2 + 30):
		_advance(link, _controls({"trigger": 1.0}))
		for cue in _drain():
			if not bool(cue.get("withdrawn", false)) and played.is_empty():
				played = cue
				played["seen_after"] = _tick - pressed_at
	_advance(link, _controls({}))
	_check("the_gunner_sees_the_shell_leave_within_a_tick_of_the_trigger_over_a_%d_tick_link" % link,
		not played.is_empty() and int(played["seen_after"]) <= 1,
		"%s" % ["no cue" if played.is_empty() else "after %d tick(s), mount %s shell %s, frame %s" % [
			played["seen_after"], played.get("mount"), played.get("shell"), played.get("frame")]])
	return played


## ---- 2. confirmed, once ---------------------------------------------------------------------------------------------

## THE SERVER MAKES THAT ONE SHELL, and its cue is played once and taken back never, at every link. Over 16 ticks this
## was printed rather than checked until the starvation fix: see ON_TIME_ROLLBACK_LINK.
func _the_server_agrees_and_it_is_one_shell(link: int, aboard: Dictionary, shell: Dictionary) -> void:
	_advance_idle(link, link * 2 + 40)
	_drain()
	var mine: Array = _server_shells_by(int(aboard["client"]))
	var withdrawn: int = _count_cues(shell, true)
	var played: int = _count_cues(shell, false)
	var matched: bool = false
	for row in mine:
		matched = matched or int((row as Dictionary).get("shell", -1)) == int(shell.get("shell", -2))
	var said: String = "server shells %d (matched %s), cue played %d, withdrawn %d" % [mine.size(), matched, played, withdrawn]
	_check("the_server_makes_that_one_shell_and_the_cue_stands_over_a_%d_tick_link" % link,
		mine.size() == 1 and matched and played == 1 and withdrawn == 0, said)


## ---- 3. a rollback across the fire frame ---------------------------------------------------------------------------

## THE STICK MOVES WHILE THE CLIENT'S PACKETS ARE LATE, then the trigger: the server lays the turret on the old stick for
## those frames, and the server's packets are held over the same ticks so the client learns it mispredicted only after it
## has fired, and replays across the fire.
##
## BELOW ON_TIME_ROLLBACK_LINK THE HOLD ALSO MAKES THE TRIGGER LATE, and nothing in this harness can avoid it (measured
## 2026-09-16): with the client's packets held the trigger reaches the server late, and with only the server's held, the
## client stops sending new input at all -- the server sat on input frame 1548 for twenty ticks of trigger and fired
## nothing. So there "neither fired twice nor lost" is held as the server and the gunner can count it: the server makes
## exactly ONE shell, and exactly one of the cues the gunner's machine played is still standing (played less taken back).
## AT ON_TIME_ROLLBACK_LINK the trigger is on time through the holds, and the property is held as it was first stated: a
## rollback replays across the fire frame, the server makes one shell, and the cue is played once and taken back never.
func _a_rollback_across_the_fire_frame_neither_doubles_nor_loses_it(link: int, aboard: Dictionary) -> void:
	_wait_for_the_reload(link)
	var before_server: int = _server_shells_by(int(aboard["client"])).size()
	var resims_before: int = int(_client.resim_stats().get("count", 0))
	_hold_from = _tick
	_hold_until = _tick + 12
	_hold_extra = link * 2 + 12
	_down_from = _tick
	_down_until = _tick + 16
	_down_extra = link * 2 + 24
	for i in range(12):
		_advance(link, _controls({"roll": 0.6 if i % 2 == 0 else -0.6}))
	var shell: Dictionary = {}
	for i in range(link * 2 + 60):
		_advance(link, _controls({"trigger": 1.0}))
		for cue in _drain():
			if shell.is_empty() and not bool(cue.get("withdrawn", false)):
				shell = cue
	_hold_from = -1
	_down_from = -1
	_advance_idle(link, link * 2 + 40)
	_drain()
	var stats: Dictionary = _client.resim_stats()
	var fire: int = int(shell.get("frame", -1))
	var spanned: bool = false
	var near: PackedStringArray = []
	for window in _windows:
		# A WINDOW REPLAYS begin+1 .. end: the rollback's own frame is the baseline, not a replayed frame.
		if int(window[0]) < fire and int(window[1]) >= fire:
			spanned = true
		if absi(int(window[0]) - fire) < 60 and near.size() < 8:
			near.append("%d..%d" % [window[0], window[1]])
	var made: int = _server_shells_by(int(aboard["client"])).size() - before_server
	var played: int = _count_cues(shell, false) if not shell.is_empty() else 0
	var withdrawn: int = _count_cues(shell, true) if not shell.is_empty() else 0
	# NOT AT 0 TICKS, and measured rather than assumed: see the note at the top.
	if link == 0 and int(stats.get("count", 0)) == resims_before:
		print("[shell_prediction] measure: no rollback could be provoked over a 0 tick link (%d resims before and after)"
			% resims_before)
	else:
		_check("a_rollback_replays_across_the_fire_frame_over_a_%d_tick_link" % link,
			int(stats.get("count", 0)) > resims_before and spanned,
			"resims %d -> %d, windows near the fire %s, fire frame %s" % [resims_before, stats.get("count"), near,
				shell.get("frame", "-")])
	_check("and_the_shell_is_neither_fired_twice_nor_lost_over_a_%d_tick_link" % link,
		made == 1 and played - withdrawn == 1,
		"server made %d; cue played %d, taken back %d, standing %d" % [made, played, withdrawn, played - withdrawn])
	if link >= ON_TIME_ROLLBACK_LINK:
		_check("and_that_rollback_crossed_an_on_time_fire_played_once_and_never_taken_back_over_a_%d_tick_link" % link,
			spanned and made == 1 and played == 1 and withdrawn == 0,
			"spanned %s; server made %d; cue played %d, taken back %d" % [spanned, made, played, withdrawn])


## ---- 4. a server that disagrees ------------------------------------------------------------------------------------

## THE GUNNER LEAVES THE SEAT ON THE TICK THEY FIRE: the seat button and the trigger on one frame. The server moves them
## before it asks whether the seat fires (`next_seat` is the server's), so it makes no shell; the gunner's machine cannot
## know that and fires. The shell it drew must be taken back -- and, since the yard keeps a withdrawn shell for
## `ShotYard.WITHDRAWN_GRACE_S` in case the same one is fired again, gone from the yard within that grace and one tick.
func _a_server_that_disagrees_takes_the_shell_back(link: int, aboard: Dictionary) -> void:
	# FROM THE AFT TURRET, whose next seat is the pilot's: from the forward one the seat button leads to the aft turret,
	# which is a gun, and the server rightly fires from there.
	_server.seat_client(int(aboard["client"]), int(aboard["hull"]), AFT_SEAT)
	_advance_idle(link, link * 2 + 20)
	_wait_for_the_reload(link)
	var yard := ShotYard.new()
	add_child(yard)
	var me: int = int(aboard["client"])
	var before_server: int = _server_shells_by(me).size()
	var shell: Dictionary = {}
	var withdrawn_at: int = -1
	var gone_at: int = -1
	for i in range(link * 2 + 80):
		_advance(link, _controls({"trigger": 1.0, "buttons": BUTTON_SEAT} if i == 0 else {}))
		var cues: Array = _drain()
		for cue in cues:
			if shell.is_empty() and not bool(cue.get("withdrawn", false)):
				shell = cue
			if bool(cue.get("withdrawn", false)) and not shell.is_empty() \
					and int(cue.get("shell", -1)) == int(shell.get("shell", -2)):
				withdrawn_at = _tick
		yard.callv("draw_shots", [_client.shot_states(), Vector3.ZERO, DT, 0.0, cues, me])
		if withdrawn_at >= 0 and gone_at < 0 and not shell.is_empty() \
				and (yard.call("drawn_shell", me, int(shell["mount"]), int(shell["shell"])) as Dictionary).is_empty():
			gone_at = _tick
	yard.queue_free()
	var made: int = _server_shells_by(me).size() - before_server
	var allowed: int = int(ceil(minf(ShotYard.WITHDRAWN_GRACE_S, REFUSED_SHOWN_S) / DT)) + 1
	_check("a_shell_the_server_refused_is_drawn_and_then_taken_back_over_a_%d_tick_link" % link,
		made == 0 and not shell.is_empty() and withdrawn_at >= 0 and gone_at >= 0 and gone_at - withdrawn_at <= allowed,
		"server made %d; predicted %s; withdrawn %s; gone from the yard %s tick(s) after (grace %.0f ms, at most %.0f, + a tick = %d)" % [
			made, "yes" if not shell.is_empty() else "no", "yes" if withdrawn_at >= 0 else "no",
			str(gone_at - withdrawn_at) if gone_at >= 0 and withdrawn_at >= 0 else "never",
			ShotYard.WITHDRAWN_GRACE_S * 1000.0, REFUSED_SHOWN_S * 1000.0, allowed])


## ---- 5. the handover -----------------------------------------------------------------------------------------------

## THE GAME'S OWN YARD, handed each tick what `Sim` would hand it: the client's shots, how late it draws, the shell cues and
## who this machine is. The shell is followed from the trigger until it lands. What the gunner sees is held: ONE shell,
## drawn on every tick from the trigger to the splash, no tick moving it more than `HANDOVER_STEP_M` beyond its own flight
## (re-anchors after a late trigger included), and when the yard adopts the server's record the handover's own gap.
func _the_handover_cannot_be_seen(link: int, aboard: Dictionary) -> void:
	var yard := ShotYard.new()
	add_child(yard)
	if not yard.has_method("drawn_shell"):
		_check("the_yard_draws_a_predicted_shell_over_a_%d_tick_link" % link, false, "ShotYard.drawn_shell")
		yard.queue_free()
		return
	_wait_for_the_reload(link)
	_lay(link, ELEVATION)
	var me: int = int(aboard["client"])
	var shell: Dictionary = {}
	var gap: float = -1.0
	var carried: float = 0.0
	var worst_step: float = 0.0
	var last: Dictionary = {}
	var handed_at: int = -1
	var drawn_ticks: int = 0
	var ended: String = "still flying"
	for i in range(int(20.0 * TICK_HZ)):
		_advance(link, _controls({"trigger": 1.0 if i < 3 else 0.0}))
		var cues: Array = _drain()
		for cue in cues:
			if shell.is_empty() and not bool(cue.get("withdrawn", false)):
				shell = cue
		# THROUGH `callv`, so a yard from before prediction is a named FAIL above rather than a parse error that hangs.
		yard.callv("draw_shots", [_client.shot_states(), Vector3.ZERO, DT,
			float(_client.timing().get("buffer_frames", 0)) * DT, cues, me])
		if shell.is_empty():
			continue
		var now: Dictionary = yard.call("drawn_shell", me, int(shell["mount"]), int(shell["shell"]))
		if now.is_empty():
			if drawn_ticks > 0:
				ended = "vanished in the air"
				for row in _client.shot_states():
					if int((row as Dictionary).get("shooter", -1)) == me \
							and int((row as Dictionary).get("shell", -1)) == int(shell["shell"]) \
							and not bool((row as Dictionary).get("flying", true)):
						ended = "landed"
				break
			continue
		drawn_ticks += 1
		if not last.is_empty():
			var moved: Vector3 = (now["at"] as Vector3) - (last["at"] as Vector3)
			var flew: Vector3 = (last["velocity"] as Vector3) * DT
			worst_step = maxf(worst_step, (moved - flew).length())
		if bool(now.get("handed_over", false)) and handed_at < 0:
			handed_at = _tick
			gap = float(now.get("gap", -1.0))
			carried = float(now.get("carried", 0.0))
		last = now
	yard.queue_free()
	_check("the_gunner_sees_one_shell_from_the_trigger_to_the_splash_over_a_%d_tick_link" % link,
		drawn_ticks > int(5.0 * TICK_HZ) and ended == "landed",
		"drawn on %d consecutive ticks, then %s" % [drawn_ticks, ended])
	_check("the_yard_hands_the_predicted_shell_to_the_servers_over_a_%d_tick_link" % link,
		handed_at >= 0 and gap >= 0.0 and gap <= HANDOVER_GAP_M,
		"handed over %s, gap %.2f m (budget %.1f m), %.2f m still being blended from before it" % [
			"at tick %d" % handed_at if handed_at >= 0 else "never", gap, HANDOVER_GAP_M, carried])
	_check("and_no_tick_moves_it_more_than_its_flight_and_a_blend_over_a_%d_tick_link" % link,
		drawn_ticks > 0 and worst_step <= HANDOVER_STEP_M,
		"worst step beyond its own flight over its whole drawn life, %.3f m (budget %.2f m)" % [worst_step,
			HANDOVER_STEP_M])


## ---- the wire -------------------------------------------------------------------------------------------------------

## THE SHELL NUMBER IS EIGHT BITS, and the handover matches on it: safe only while fewer than 256 of one mount's shells can
## be in the air at once. The most that can be is the round's whole life over the gun's reload, plus the one just fired --
## a shell ends by its life at the latest, whatever it is aimed at. Worked out for every predicted gun in the table.
func _the_shell_number_cannot_wrap_while_its_shells_are_in_the_air() -> void:
	var worst: Array = [0, ""]
	var predicted: int = 0
	for kind in range(32):
		for mount in range(3):
			var gun: Dictionary = Sim.gun_of(kind, mount)
			if not bool(gun.get("fitted", false)) or not bool(gun.get("predicted", false)):
				continue
			predicted += 1
			var life: float = 0.0
			for row in (gun.get("rounds", []) as Array):
				if int((row as Dictionary)["ammo"]) == int(gun["ammo"]):
					life = float((row as Dictionary)["life"])
			var live: int = int(ceil(life / maxf(float(gun["reload"]), 0.0001))) + 1
			if live > int(worst[0]):
				worst = [live, "kind %d mount %d: life %.0f s, reload %.1f s" % [kind, mount, life, float(gun["reload"])]]
	_check("no_predicted_gun_can_have_256_shells_in_the_air", predicted > 0 and int(worst[0]) < 256,
		"%d predicted guns; the most live at once is %d (%s)" % [predicted, worst[0], worst[1]])


## A PILOT AT NO PREDICTED GUN SENDS NO GunnerState A TICK: the component is on every pilot, and that is only right while
## a pilot who is not a gunner costs nothing for it. Counted off the server's own trace, for this client, over two seconds
## of flying a plane with the stick moving, once the first record has been sent and acknowledged.
func _a_pilot_at_no_predicted_gun_sends_no_gunner_state(link: int, aboard: Dictionary) -> void:
	if not _server_traces:
		_check("the_server_can_trace_what_it_sends", false, "set_tracing")
		return
	var me: int = int(aboard["client"])
	_server.spawn_pilot(me, 1, Vector3(2000.0, 900.0, 0.0), 0.0, Vector3(0.0, 0.0, -60.0))
	_advance_idle(link, 240)
	_server.take_trace_events()
	var bits: int = 0
	var pilot_bits: int = 0
	var all_bits: int = 0
	var ticks: int = 240
	for i in range(ticks):
		_advance(link, _controls({"roll": 0.5 if i % 40 < 20 else -0.5, "throttle": 0.6}))
		for event in _server.take_trace_events():
			if String(event["type"]) != "component_sent" or int(event["client"]) != me:
				continue
			all_bits += int(event["bits"])
			if String(event["component"]) == "GunnerState":
				bits += int(event["bits"])
			if String(event["component"]) in ["PilotState", "PilotOwner", "GunnerState"]:
				pilot_bits += int(event["bits"])
	# AND THE TRACE SAW THIS CLIENT BEING SENT THINGS, or "nothing of GunnerState" would be a trace that saw nothing.
	_check("a_pilot_flying_a_plane_sends_no_gunner_state_over_a_%d_tick_link" % link, bits == 0 and all_bits > 0,
		"%.2f bytes a tick of GunnerState over %d ticks, of %.2f bytes a tick sent to this client" % [
			float(bits) / 8.0 / ticks, ticks, float(all_bits) / 8.0 / ticks])


## ---- the gunner ------------------------------------------------------------------------------------------------------

func _aboard(link: int) -> Dictionary:
	_server = ClassDB.instantiate("CockpitWorld")
	_client = ClassDB.instantiate("CockpitWorld")
	_server_traces = _server.set_tracing(true)
	_client.set_tracing(true)
	_tick = 0
	_in_flight.clear()
	_cues.clear()
	_windows.clear()
	_withdrawal_reasons.clear()
	_resims_seen = 0
	for world in [_server, _client]:
		world.set_tick_rate(TICK_HZ)
	_server.start(0)
	_client.start(PEER)
	for world in [_server, _client]:
		world.add_static_box(Vector3(0.0, -160.0, 0.0), Vector3(12000.0, 10.0, 12000.0))
	_advance_idle(link, 90)
	var me: int = int(_client.local_client_id())
	if me <= 0:
		_check("the_client_handshook_over_a_%d_tick_link" % link, false, "client id %d" % me)
		_teardown()
		return {}
	var hull: int = int(_server.spawn_vehicle(BATTLESHIP, Vector3.ZERO, 0.0, UNDER_WAY))
	_server.spawn_pilot(me, POD, Vector3(300.0, 4.0, 300.0), 0.0, Vector3.ZERO)
	_advance_idle(link, 20)
	var aboard: Dictionary = {"client": me, "hull": hull}
	if not _aboard_again(link, aboard):
		_teardown()
		return {}
	_advance_idle(link, 240)
	return aboard


## Sit (again) at the forward turret, as the disagreement test moves the gunner out of it.
func _aboard_again(link: int, aboard: Dictionary) -> bool:
	var seated: bool = bool(_server.seat_client(int(aboard["client"]), int(aboard["hull"]), FORWARD_SEAT))
	_advance_idle(link, link * 2 + 20)
	if not seated:
		_check("a_client_takes_the_forward_turret_seat_over_a_%d_tick_link" % link, false, "refused")
	return seated


## Lay the forward gun to `elevation` with the stick, as the gunner does.
func _lay(link: int, elevation: float) -> void:
	for i in range(int(6.0 * TICK_HZ)):
		var aimed: Array = _server.vehicle_state(_hull()).get("turrets", []) as Array
		var now: float = (aimed[0] as Vector2).y if not aimed.is_empty() else 0.0
		if absf(now - elevation) < 0.002:
			break
		_advance(link, _controls({"pitch": clampf((elevation - now) * 40.0, -1.0, 1.0)}))
	_advance_idle(link, link * 2 + 4)


func _wait_for_the_reload(link: int) -> void:
	_advance_idle(link, int(6.5 * TICK_HZ))
	_drain()


func _hull() -> int:
	for row in _server.vehicle_states():
		if int((row as Dictionary).get("kind", -1)) == BATTLESHIP:
			return int((row as Dictionary)["entity"])
	return 0


func _server_shells_by(client: int) -> Array:
	var out: Array = []
	for row in _server.shot_states():
		if int((row as Dictionary).get("shooter", -1)) == client and String((row as Dictionary).get("ammo_name", "")) == "406mm":
			out.append(row)
	return out


func _drain() -> Array:
	var got: Array = _client.shell_cues() if _client.has_method("shell_cues") else []
	_cues.append_array(got)
	return got


func _count_cues(shell: Dictionary, withdrawn: bool) -> int:
	var count: int = 0
	for cue in _cues:
		if int((cue as Dictionary).get("mount", -1)) == int(shell.get("mount", -2)) \
				and int((cue as Dictionary).get("shell", -1)) == int(shell.get("shell", -2)) \
				and bool((cue as Dictionary).get("withdrawn", false)) == withdrawn:
			count += 1
	return count


## ---- the wire -------------------------------------------------------------------------------------------------------

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


func _advance_idle(link: int, ticks: int) -> void:
	for i in range(ticks):
		_advance(link, _controls({}))


func _advance(link: int, input: Dictionary) -> void:
	_client.set_input(input)
	_tick += 1
	_server.tick(DT)
	_client.tick(DT)
	_pump(link)
	var stats: Dictionary = _client.resim_stats()
	if int(stats.get("count", 0)) != _resims_seen:
		_resims_seen = int(stats.get("count", 0))
		_windows.append([int(stats.get("last_from", -1)), int(stats.get("last_to", -1))])
	# WHY EACH PREDICTED CUE WAS TAKEN BACK, off the client's own trace, drained every tick so its ring does not overflow.
	for event in _client.take_trace_events():
		if String(event["type"]) == "cue_rolled_back":
			var why: String = String(event["detail"]).get_slice("rollback_reason=", 1)
			_withdrawal_reasons[why] = int(_withdrawal_reasons.get(why, 0)) + 1


## THE LINK IS REALLY `link + 1` TICKS EACH WAY. A packet is delivered in this pump, which runs after BOTH worlds have ticked,
## so the soonest it is read is the next tick: a 16-tick link here is 17 each way (lane/starve, 2026-09-16, which proved it
## off this very pump). Left as it is on purpose -- every figure these suites have recorded was measured through it.
func _pump(link: int) -> void:
	for packet in _server.take_outbound():
		var held: int = _down_extra if _down_from >= 0 and _tick >= _down_from and _tick < _down_until else 0
		_in_flight.append([_tick + link + held, false, int(packet["peer"]), packet["bytes"], packet["bits"]])
	for packet in _client.take_outbound():
		var late: int = _hold_extra if _hold_from >= 0 and _tick >= _hold_from and _tick < _hold_until else 0
		_in_flight.append([_tick + link + late, true, PEER, packet["bytes"], packet["bits"]])
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


func _teardown() -> void:
	for world in [_client, _server]:
		if world != null:
			world.teardown()
	_client = null
	_server = null


func _finish() -> void:
	_teardown()
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
