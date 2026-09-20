extends Node
## Headless contract for the WING SWEEP HANDLE on its own, before any craft is fitted with the channel: a hand takes it
## and pulls it along its slot, and what it asks the bus for comes out; the wire moves a handle nobody holds and cannot
## move one somebody does. Read RESULT=.
##
## DRIVEN BY THE HAND, the last thing a human touches (CLAUDE.md rule 3): `offer_hand` with the fist closed on the grip
## and moved in the handle's own space, exactly the call `PilotRig._work_the_controls` makes. Nothing here sets `value`.
##
## THE NUMBERS ARE TYPED, not read out of the handle: 20 and 75 degrees are the F-14's forward and overswept stops
## (`craft/tomcat/sources.md`), 0.16 m is the slot a hand pulls through, 255 the channel's range.
const FORWARD_DEGREES := 20.0
const OVERSWEPT_DEGREES := 75.0
const FULL_SWEEP_DEGREES := 68.0
const SLOT := 0.16
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[sweep_handle] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_it_is_a_part_the_bin_knows_and_it_is_wired_to_the_sweep()
	_a_hand_pulling_it_aft_sweeps_the_wings_back()
	_the_wire_moves_a_handle_nobody_holds_and_not_one_somebody_does()
	_no_craft_without_the_channel_is_given_one()
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _handle() -> SweepHandle:
	var handle := ControlCatalogue.make(&"SweepHandle") as SweepHandle
	add_child(handle)
	handle.setup(0)
	return handle


## WHAT IT IS: a part in the bin, the craft's and not a seat's, on the sweep channel with the full byte of travel.
func _it_is_a_part_the_bin_knows_and_it_is_wired_to_the_sweep() -> void:
	var handle := _handle()
	var ok: bool = handle != null and handle.scope == VehicleControl.Scope.CRAFT \
		and handle.channel == Sim.Channel.SWEEP and handle.channel_range == 255 \
		and Sim.channel_name(handle.channel) == "sweep"
	_check("it_is_a_part_the_bin_knows_and_it_is_wired_to_the_sweep", ok,
		"%s, scope %d, channel %d (%s), range %d" % [handle != null, handle.scope, handle.channel,
			Sim.channel_name(handle.channel), handle.channel_range])
	handle.free()


## A HAND ON THE GRIP, PULLED AFT THROUGH THE SLOT. Forward of the slot is 20 degrees and 0 on the bus; halfway is
## 47.5 degrees; the back of the slot is 75, overswept, and 255. Pushed past either end it stops there.
func _a_hand_pulling_it_aft_sweeps_the_wings_back() -> void:
	var handle := _handle()
	var grip: Vector3 = handle._grab_point()
	var told: Array[int] = []
	handle.moved.connect(func(_c: VehicleControl) -> void: told.append(handle.command_value()))
	handle.offer_hand(0, grip, 1.0)
	var at_rest: float = handle.sweep()
	var readings: PackedStringArray = []
	var ok := handle.held_by == 0 and is_equal_approx(at_rest, FORWARD_DEGREES)
	for pair in [[SLOT * 0.5, 47.5, 128], [SLOT, OVERSWEPT_DEGREES, 255], [SLOT * 1.5, OVERSWEPT_DEGREES, 255],
			[-SLOT * 0.2, FORWARD_DEGREES, 0]]:
		handle.offer_hand(0, grip + Vector3(0.0, 0.0, float(pair[0])), 1.0)
		ok = ok and absf(handle.sweep() - float(pair[1])) < 0.01 and handle.command_value() == int(pair[2])
		readings.append("%+.2f m aft -> %.2f deg, %d" % [pair[0], handle.sweep(), handle.command_value()])
	# THE LINE ON THE SLOT is where 68 degrees puts the knob.
	var marked: float = SweepHandle.fraction_of(FULL_SWEEP_DEGREES)
	ok = ok and absf(marked - (FULL_SWEEP_DEGREES - FORWARD_DEGREES) / (OVERSWEPT_DEGREES - FORWARD_DEGREES)) < 1e-4
	handle.offer_hand(0, grip, 0.0)
	ok = ok and handle.held_by < 0 and told.size() >= 3
	_check("a_hand_pulling_it_aft_sweeps_the_wings_back", ok,
		"taken at %.1f deg; %s; it told the rig %d times; the 68-degree line is %.3f of the slot"
			% [at_rest, ", ".join(readings), told.size(), marked])
	handle.free()


## THE WIRE MOVES A HANDLE NOBODY HOLDS, and not one somebody does: the other seat's handle slides when this seat's is
## pulled, and a hand on a handle is never fought by a value a round trip old (`VehicleControl.apply`).
func _the_wire_moves_a_handle_nobody_holds_and_not_one_somebody_does() -> void:
	var idle := _handle()
	var held := _handle()
	var wire := Vector2(0.0, SweepHandle.fraction_of(FULL_SWEEP_DEGREES))
	idle.apply(wire)
	held.offer_hand(1, held._grab_point(), 1.0)
	held.apply(wire)
	var ok: bool = absf(idle.sweep() - FULL_SWEEP_DEGREES) < 0.01 and is_equal_approx(held.sweep(), FORWARD_DEGREES)
	_check("the_wire_moves_a_handle_nobody_holds_and_not_one_somebody_does", ok,
		"the idle handle shows %.2f deg from the wire's %.0f; the held one stays at %.2f" % [idle.sweep(),
			FULL_SWEEP_DEGREES, held.sweep()])
	idle.free()
	held.free()


## A CRAFT WHOSE BUS HAS NO SWEEP GETS NO HANDLE, at any seat, flying or operator: the F/A-18F, whose two seats are the
## Tomcat's shape. A dead handle is worse than none.
func _no_craft_without_the_channel_is_given_one() -> void:
	var found: PackedStringArray = []
	var seats: int = 0
	for kind in range(Sim.Kind.size()):
		var fitted := false
		for row in Sim.schema_of(kind).get("channels", []) as Array:
			if int((row as Dictionary).get("channel", -1)) == Sim.Channel.SWEEP:
				fitted = true
		var poses: Array = Sim.geometry_of(kind).get("seat_poses", []) as Array
		for seat in range(poses.size()):
			var scene := VehicleCatalogue.seat_scene(kind) as PackedScene
			if scene == null:
				continue
			var station := scene.instantiate() as CockpitStation
			if station == null:
				continue
			add_child(station)
			station.fit(seat, bool((poses[seat] as Dictionary).get("flies", true)), kind)
			seats += 1
			if (station.get_node_or_null("SweepHandle") != null) != fitted:
				found.append("%s seat %d" % [Sim.kind_name(kind), seat])
			remove_child(station)
			station.free()
	_check("a_handle_is_fitted_exactly_where_the_bus_has_the_sweep", found.is_empty() and seats > 0,
		"%d seats across %d kinds; wrong: %s" % [seats, Sim.Kind.size(), found])
