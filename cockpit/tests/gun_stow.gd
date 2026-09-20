extends Node
## Headless contract for THE GUNSHIP'S GUNS STOWED: the user asked for the AC-130's "3 guns poking out of it that can be
## toggled off" (2026-09-19). A gunner turns the knob at their station, the simulation draws the guns in, everybody who can
## see the aeroplane sees them go, and none of the three will fire until they are run out again. Read RESULT=.
##
## DRIVEN FROM THE HAND (CLAUDE.md rule 3): the knob is the station's own, fitted by `CockpitStation` from the craft's bus,
## and turned by `offer_hand` with the wrist rolled, the call `PilotRig._work_the_controls` makes. What it commands goes to
## a real server as a gunner's control frame (`command_channel`, `command_value`, `command_seq`), the frame the rig sends.
## The server's outside switches are read on a CLIENT that received them over the wire, and the view draws the guns from
## that client's own copy.

const DT := 1.0 / 120.0
## The gunner at seat 1 works mount 0, the 25 mm (`Sim.mount_of_seat`).
const GUNNER_SEAT := 1
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[gun_stow] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	CockpitStation.use_saved_layouts = false
	var knob := _every_gunner_has_the_knob_and_nobody_else_does()
	if knob == null:
		_finish()
		return
	var asked: int = _the_wrist_turns_it_to_stowed(knob)
	_stowed_the_guns_go_in_for_everybody_and_do_not_fire(asked)
	_finish()


## EVERY GUNNER'S STATION HAS THE KNOB, on the Mode channel with two positions; the pilot's has none, and the transport,
## whose bus has no "stow guns", has none at any seat.
func _every_gunner_has_the_knob_and_nobody_else_does() -> RotaryKnob:
	var said: PackedStringArray = []
	var ok := true
	var first: RotaryKnob = null
	for kind in [Sim.Kind.GUNSHIP, Sim.Kind.TRANSPORT]:
		var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
		add_child(view)
		# MANNED, as a craft in flight is (`_show_in_editor` mans every seat): a station is fitted from its package then.
		view.preview_kind = kind
		view._show_in_editor()
		for seat in range(view.seats.size()):
			var station: CockpitStation = view.station_for(seat)
			var knob := station.get_node_or_null("StowGuns") as RotaryKnob if station != null else null
			var gunner: bool = kind == Sim.Kind.GUNSHIP and Sim.mount_of_seat(kind, seat) >= 0
			ok = ok and (knob != null) == gunner
			if knob != null:
				ok = ok and knob.channel == Sim.Channel.MODE and knob.channel_range == 1
				if first == null and seat == GUNNER_SEAT:
					first = knob
			said.append("%s seat %d %s" % [Sim.kind_name(kind), seat, "knob" if knob != null else "none"])
		if kind != Sim.Kind.GUNSHIP:
			view.queue_free()
	_check("every_gunner_has_a_stow_knob_and_nobody_else_does", ok and first != null, ", ".join(said))
	return first


## TAKE IT BETWEEN TWO FINGERS AND ROLL THE WRIST: it goes to its stop and asks the bus for 1, stowed.
func _the_wrist_turns_it_to_stowed(knob: RotaryKnob) -> int:
	knob.value = Vector2(0.0, 0.0)
	var start: int = knob.command_value()
	knob.offer_hand(0, knob._grab_point(), 1.0, Basis.IDENTITY)
	for step in range(1, 7):
		knob.offer_hand(0, knob._grab_point(), 1.0, Basis(Vector3.UP, -0.4 * float(step)))
	var asked: int = knob.command_value()
	knob.release()
	_check("a_gunners_wrist_turns_it_to_stowed", start == 0 and asked == 1,
		"ran out %d, then %d after 2.4 rad of wrist" % [start, asked])
	return asked


## THE GUNNER'S FRAME TO A REAL SERVER: out, a gun fires; stowed, the outside switch reaches a client over the wire, the
## client's view draws every barrel inside the skin, and none of the three fires; run out again, they fire.
func _stowed_the_guns_go_in_for_everybody_and_do_not_fire(asked: int) -> void:
	var server := _world(0)
	var client := _world(1)
	var made: Dictionary = server.spawn_pilot(1, Sim.Kind.GUNSHIP, Vector3(0.0, 1500.0, 0.0), 0.0, Vector3(0.0, 0.0, -90.0))
	var craft: int = int(made.get("vehicle", 0))
	var pilot: int = int(made.get("pilot", 0))
	var gunner: Dictionary = server.spawn_pilot(2, Sim.Kind.POD, Vector3(300.0, 1500.0, 0.0), 0.0, Vector3.ZERO)
	var seated: bool = bool(server.seat_client(2, craft, GUNNER_SEAT))
	for i in range(30):
		_step_pair(server, client)
	var fired_out: int = 0
	for mount in range(3):
		fired_out += 1 if int(server.fire_gun(craft, mount)) != 0 else 0
	# THE KNOB'S COMMAND, as the gunner's control frame.
	var seq: int = 1
	for i in range(6):
		server.set_pilot_input(int(gunner.get("pilot", 0)), _controls({"command_channel": Sim.Channel.MODE,
			"command_value": asked, "command_seq": seq}))
		_step_pair(server, client)
	# THE CLIENT'S OWN ENTITY FOR THE CRAFT, found by kind: a client numbers what it receives itself.
	var seen: int = _on(client, Sim.Kind.GUNSHIP)
	var outside: Dictionary = client.craft_systems(seen) if seen > 0 else {}
	for i in range(1300):
		_step_pair(server, client)
	var fired_stowed: int = 0
	for mount in range(3):
		fired_stowed += 1 if int(server.fire_gun(craft, mount)) != 0 else 0
	# THE CLIENT'S VIEW DRAWS THEM FROM ITS OWN COPY of the outside switches.
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.setup(0, Sim.Kind.GUNSHIP)
	view.draw_the_jetliner_from(client.craft_controls(seen) if seen > 0 else {}, {}, outside)
	var frame := view.find_child("Hercules", true, false) as HerculesAirframe
	var drawn_in: bool = frame != null and frame.guns() == 0.0
	# RUN OUT AGAIN, and they fire.
	seq += 1
	for i in range(6):
		server.set_pilot_input(int(gunner.get("pilot", 0)), _controls({"command_channel": Sim.Channel.MODE,
			"command_value": 0, "command_seq": seq}))
		_step_pair(server, client)
	for i in range(1300):
		_step_pair(server, client)
	var fired_again: int = 0
	for mount in range(3):
		fired_again += 1 if int(server.fire_gun(craft, mount)) != 0 else 0
	var out_again: bool = seen > 0 and not bool(client.craft_systems(seen).get("guns_stowed", true))
	_check("stowed_the_client_sees_them_in_and_none_of_three_fires",
		seated and pilot > 0 and fired_out == 3 and bool(outside.get("guns_stowed", false)) and drawn_in
			and fired_stowed == 0 and fired_again == 3 and out_again,
		"gunner seated %s; out %d of 3 fired; stowed on the client %s, drawn in %s, %d of 3 fired; run out again %s, %d of 3 fired"
			% [seated, fired_out, outside.get("guns_stowed", "missing"), drawn_in, fired_stowed, out_again, fired_again])
	view.queue_free()
	_let_go(server)
	_let_go(client)


## The entity of the first craft of `kind` that `world` holds, or 0.
func _on(world: Object, kind: int) -> int:
	for state in world.vehicle_states():
		if int((state as Dictionary).get("kind", -1)) == kind:
			return int((state as Dictionary).get("entity", 0))
	return 0


func _controls(overrides: Dictionary = {}) -> Dictionary:
	var input := {"throttle": 0.6, "pitch": 0.0, "roll": 0.0, "rudder": 0.0,
		"brake": 0.0, "head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3.ZERO, "left_basis": Quaternion.IDENTITY, "right": Vector3.ZERO,
		"right_basis": Quaternion.IDENTITY, "grip_left": 0.0, "grip_right": 0.0,
		"buttons": 0, "trigger": 0.0, "kind_wanted": Sim.NO_KIND}
	for key in overrides:
		input[key] = overrides[key]
	return input


func _world(client_id: int) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(client_id)
	return world


func _step_pair(server: Object, client: Object) -> void:
	server.tick(DT)
	client.tick(DT)
	for packet in server.take_outbound():
		client.deliver(0, packet["bytes"], packet["bits"])
	for packet in client.take_outbound():
		server.deliver(1, packet["bytes"], packet["bits"])


func _let_go(world: Object) -> void:
	world.teardown()
	if not (world is RefCounted):
		world.free()


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
