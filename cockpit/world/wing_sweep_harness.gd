extends Node
class_name WingSweepHarness
## FOR A HARNESS: take the Tomcat, move this seat's WING SWEEP HANDLE with a hand at stated times, and write down every
## change in the wings this machine sees. Added by `FlightLevel` only when a flag below is on the command line; a player never
## has one. `tests/sweep_peers.gd` runs two machines with it and reads both logs.
##
##   --take-kind=tomcat          once flying, press the REAL key for that kind (F1 + kind, both key codes set), as a
##                               player at a desk does, until this machine is in one.
##   --sweep=WHEN:DEGREES,...    WHEN is SECONDS after both seats are manned, or @BYTE+SECONDS after this machine sees the
##                               wings settled at that bus value. Then close a hand on THIS
##                               seat's sweep handle and drag it until it asks for DEGREES, then let go. A hand, through
##                               the rig's own hand pass (`force_hand`, `force_grip`), exactly as `tests/shared_controls`
##                               drives a switch: nothing here sends a command.
##   --report=1                  and a `WINGS` line on every physics frame that any Tomcat's commanded sweep, its actual
##                               sweep, or this seat's handle changed: `WINGS tick=... entity=... command=... sweep=...
##                               handle=... drawn=...`, the bytes as the bus carries them and the handle and the drawn
##                               wing in degrees.
##
## THE HAND IS PLACED AGAIN EVERY PHYSICS FRAME, from the handle's own transform: the aeroplane moves, and a hand placed
## once is left behind in the sky within a frame or two still holding what it closed on (`tests/shared_controls.gd`).

const RIGHT: int = 1
## How long a drag takes, in physics frames: half a second at 120 Hz.
const DRAG_FRAMES: int = 60

var _sky: Node = null
var _plan: Array = []
var _crewed_at: int = -1
var _busy: bool = false
var _took: bool = false
var _pressed_at: int = -1
var _last: Dictionary = {}
var _armed_at: int = -1


static func wanted(asked: Callable) -> bool:
	return String(asked.call("sweep")) != "" or String(asked.call("take-kind")) != "" \
		or String(asked.call("report")) == "1"


func _init(sky: Node) -> void:
	_sky = sky
	name = "WingSweepHarness"
	# `SECONDS:DEGREES` counts from both seats being manned; `@BYTE+SECONDS:DEGREES` counts from this machine seeing the
	# wings SETTLED at that bus value (command and sweep both there).
	for step in String(FlightLevel._asked("sweep")).split(",", false):
		var parts: PackedStringArray = step.split(":")
		if parts.size() != 2:
			continue
		var when: String = parts[0]
		if when.begins_with("@"):
			_plan.append([int(when.substr(1).get_slice("+", 0)), float(when.get_slice("+", 1)), float(parts[1])])
		else:
			_plan.append([-1, float(when), float(parts[1])])


func _physics_process(_delta: float) -> void:
	if Sim.client == null or not Sim.is_ready:
		return
	var rig: PilotRig = _sky.get("rig") as PilotRig
	if rig == null:
		return
	_take_the_kind(rig)
	_sweep_when_asked(rig)
	if FlightLevel._asked("report") == "1":
		_write_down_the_wings(rig)


## THE REAL KEY FOR THE KIND ASKED FOR, pressed and released as input events with both codes set, every two seconds until
## this machine is in one. `PilotRig.desk_keys` binds KEY_F1 + kind.
func _take_the_kind(rig: PilotRig) -> void:
	var wanted_kind: int = -1
	for kind in range(Sim.Kind.size()):
		if Sim.kind_name(kind) == FlightLevel._asked("take-kind"):
			wanted_kind = kind
	if wanted_kind < 0 or _took:
		return
	var view: VehicleView = rig.vehicle_view()
	if view != null and view.kind == wanted_kind:
		_took = true
		print("TOOK %s" % Sim.kind_name(wanted_kind))
		return
	if _pressed_at >= 0 and Time.get_ticks_msec() - _pressed_at < 2000:
		return
	_pressed_at = Time.get_ticks_msec()
	_press((KEY_F1 + wanted_kind) as Key)


## A KEY HELD FOR TWO PHYSICS FRAMES, then let go, as `tests/shared_controls.gd` presses one: pressed and released in the
## same frame, a key the rig reads as a level is never seen down at all -- the first run of `sweep_peers` pressed F26
## that way every two seconds for two and a half minutes and the host never left its aeroplane.
func _press(code: Key) -> void:
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = down
		Input.parse_input_event(key)
		if down:
			for i in range(6):
				await get_tree().physics_frame


func _sweep_when_asked(rig: PilotRig) -> void:
	if _plan.is_empty() or _busy:
		return
	var view: VehicleView = rig.vehicle_view()
	# THE CLOCK STARTS WITH THIS SEAT AT A HANDLE AND BOTH SEATS MANNED. Any two manned seats was the first rule, and it
	# started on the host's first aeroplane, before the Tomcat or the joiner, so both timelines ran against nothing.
	if view == null or view.manned_seats().size() < 2 or view.controls_for(rig.seat_index()).get("sweephandle") == null:
		return
	if _crewed_at < 0:
		_crewed_at = int(Time.get_unix_time_from_system() * 1000.0)
		print("CREWED seat %d" % rig.seat_index())
	var step: Array = _plan[0]
	# WHEN A HAND MOVES IS DECIDED BY WHAT THIS MACHINE SEES, not by a clock the other machine does not share. Under
	# --fixed-fps each process steps as fast as it can -- faster than the wall on a quiet machine, slower on a busy one --
	# so a timeline in physics frames put the RIO's first drag before the pilot's second on one run and after it on the
	# next, and one on the wall clock sent the RIO's hand in while the wings were still travelling. So a step can wait for
	# the WINGS: settled at a bus value, as this machine sees them, and then a stated number of seconds.
	var now: int = int(Time.get_unix_time_from_system() * 1000.0)
	if int(step[0]) >= 0:
		var systems: Dictionary = Sim.client.craft_systems(view.entity)
		var settled: bool = absi(int(systems.get("sweep_command", -1)) - int(step[0])) <= 1 and int(systems.get("sweep", -1)) == int(systems.get("sweep_command", -2))
		if _armed_at < 0:
			if not settled:
				return
			_armed_at = now
			print("ARMED seat %d at %d" % [rig.seat_index(), int(step[0])])
		if now - _armed_at < int(float(step[1]) * 1000.0):
			return
	elif now - _crewed_at < int(float(step[1]) * 1000.0):
		return
	_armed_at = -1
	_plan.pop_front()
	_drag(rig, view, float(step[2]))


## CLOSE A HAND ON THIS SEAT'S HANDLE, DRAG IT TO `degrees`, LET GO.
func _drag(rig: PilotRig, view: VehicleView, degrees: float) -> void:
	var handle := view.controls_for(rig.seat_index()).get("sweephandle") as SweepHandle
	if handle == null:
		print("SWEEP no handle at seat %d" % rig.seat_index())
		return
	_busy = true
	print("SWEEP seat %d asks %.1f degrees" % [rig.seat_index(), degrees])
	# TAKE HOLD OF THE KNOB WHERE IT IS NOW, placed again every frame until the handle says it is held. A knob the other
	# seat is sliding through the bus moves between frames, and the first version aimed once, at where it had been:
	# with both crew at their handles at once the RIO's hand closed late and let go at 49.8 degrees having been asked
	# for 60.
	var grip: Vector3 = handle._grab_point()
	rig.force_grip(RIGHT, 1.0)
	for i in range(30):
		grip = handle._grab_point() if handle.held_by != RIGHT else grip
		rig.force_hand(RIGHT, Transform3D(Basis.IDENTITY, handle.to_global(grip)))
		await get_tree().physics_frame
		if handle.held_by == RIGHT and i >= 2:
			break
	# FROM WHERE IT WAS WHEN THE HAND CLOSED, which is what the handle measures a drag from.
	var along: float = (SweepHandle.fraction_of(degrees) - handle.value.y) * SweepHandle.TRAVEL
	for i in range(DRAG_FRAMES + 1):
		var at: Vector3 = grip + Vector3(0.0, 0.0, along * float(i) / float(DRAG_FRAMES))
		rig.force_hand(RIGHT, Transform3D(Basis.IDENTITY, handle.to_global(at)))
		await get_tree().physics_frame
	# LET GO AS A SQUEEZE ENDS, not as a tap: a grip opened within `PilotRig.TAP_SECONDS` latches.
	var closed_at: int = Time.get_ticks_msec()
	var end: Vector3 = grip + Vector3(0.0, 0.0, along)
	while Time.get_ticks_msec() - closed_at < int((PilotRig.TAP_SECONDS + 0.15) * 1000.0):
		rig.force_hand(RIGHT, Transform3D(Basis.IDENTITY, handle.to_global(end)))
		await get_tree().physics_frame
	# WHERE THE HAND LEFT IT, read while it is still held: once let go the handle shows the bus, and the bus may still be
	# on its way. The first version read it after, and wrote down the pilot's 40 degrees as where the RIO had let go.
	var left_at: float = handle.sweep()
	rig.force_grip(RIGHT, 0.0)
	for i in range(4):
		rig.force_hand(RIGHT, Transform3D(Basis.IDENTITY, handle.to_global(end)))
		await get_tree().physics_frame
	rig.force_hand(RIGHT, null)
	rig.force_grip(RIGHT, -1.0)
	print("SWEEP seat %d let go at %.1f degrees" % [rig.seat_index(), left_at])
	_busy = false


## EVERY CHANGE IN EVERY TOMCAT'S WINGS THIS MACHINE CAN SEE, as the bus carries them, and this seat's handle and the drawn
## wing where this machine is aboard one.
func _write_down_the_wings(rig: PilotRig) -> void:
	var mine: VehicleView = rig.vehicle_view()
	for entity in Sim.current:
		if int((Sim.current[entity] as Dictionary).get("kind", -1)) != Sim.Kind.TOMCAT:
			continue
		var id: int = int(entity)
		var systems: Dictionary = Sim.client.craft_systems(id)
		var handle: float = -1.0
		var drawn: float = -1.0
		if mine != null and mine.entity == id:
			var held := mine.controls_for(rig.seat_index()).get("sweephandle") as SweepHandle
			handle = held.sweep() if held != null else -1.0
			drawn = mine._sweep_drawn
		var now: Array = [int(systems.get("sweep_command", -1)), int(systems.get("sweep", -1)), snappedf(handle, 0.1),
			snappedf(drawn, 0.1)]
		if _last.get(id) == now:
			continue
		_last[id] = now
		print("WINGS tick=%d entity=%d command=%d sweep=%d handle=%.1f drawn=%.1f"
			% [Engine.get_physics_frames(), id, now[0], now[1], now[2], now[3]])
