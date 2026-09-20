extends Node
## Headless: THE THREE HELICOPTERS ARE DRAWN AS HELICOPTERS, AND WHAT MOVES ON THEM MOVES FROM THE BUS. Read RESULT=.
##
##   Godot --headless --path cockpit res://tests/rotorcraft.tscn
##
## WHAT IT HOLDS, 2026-09-17 (`lane/rotors`):
## - every helicopter kind is drawn whole by its own airframe class over a hidden collision box -- the light helicopter
##   was the box itself, painted yellow, until today -- with rotors of real blades, as many as the aircraft has;
## - the Chinook's rotors stand on pylons: each hub is over drawn structure, not open air, which is the fault the user saw
##   and which `joined_parts` says it cannot see ("it finds open air, not missing structure");
## - the rotors turn with the simulation: a crewed craft with its collective up draws its rotors turning on the shared
##   clock, and an empty one parked draws them still;
## - the Chinook's ramp follows each machine's own bus on every tick, as the F/A-18F's gear does (`tests/fighter.gd`):
##   the pilot's machine sends the ramp command through `send_command` as a hand on the lever does, and both the pilot's
##   and a crew member's machine must draw it where their own bus says on every tick after.

const DT: float = 1.0 / 60.0
## HOW MANY BLADES EACH ROTOR HAS: a UH-1's two and its two-blade tail rotor, a UH-60's four and four, a CH-47's three
## and three, an MH-6M's six and four, an AH-64D's four and a four-bladed scissor.
const BLADES: Dictionary = {
	"heli": {"MainRotor": 2, "TailRotor": 2},
	"uh60": {"MainRotor": 4, "TailRotor": 4},
	"chinook": {"ChinookFrontRotor": 3, "ChinookRearRotor": 3},
	"littlebird": {"MainRotor": 6, "TailRotor": 4},
	"apache": {"MainRotor": 4, "TailRotor": 4},
}

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[rotorcraft] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("the_native_library_is_loaded", false, "CockpitWorld missing")
		_finish()
		return
	_every_helicopter_is_drawn_by_its_own_airframe_with_real_blades()
	_the_chinooks_rotors_stand_on_pylons()
	_the_rotors_turn_when_crewed_and_stand_still_when_parked()
	_the_chinooks_ramp_is_drawn_from_each_machines_bus_on_every_tick()
	_finish()


func _view(kind: int) -> VehicleView:
	var view := (load("res://objects/vehicles/craft_%s.tscn" % Sim.kind_name(kind)) as PackedScene).instantiate() \
		as VehicleView
	add_child(view)
	view.preview_kind = kind
	view._show_in_editor()
	return view


func _every_helicopter_is_drawn_by_its_own_airframe_with_real_blades() -> void:
	var wrong: PackedStringArray = []
	for kind in [Sim.Kind.HELI, Sim.Kind.UH60, Sim.Kind.CHINOOK, Sim.Kind.LITTLEBIRD, Sim.Kind.APACHE]:
		var name: String = Sim.kind_name(kind)
		var view := _view(kind)
		var frame: Node3D = view._rotorcraft
		var hull := view.find_child("Hull", true, false) as MeshInstance3D
		if frame == null:
			wrong.append("%s has no airframe of its own" % name)
		elif hull != null and hull.is_visible_in_tree():
			wrong.append("%s still shows its collision box" % name)
		else:
			for rotor_name in BLADES[name]:
				var rotor := frame.find_child(String(rotor_name), true, false) as Node3D
				var blades: int = int(rotor.get_meta(&"blades", 0)) if rotor != null else 0
				var drawn := rotor.get_node_or_null(NodePath(String(rotor_name) + "Blades")) as MeshInstance3D \
					if rotor != null else null
				if blades != int(BLADES[name][rotor_name]) or drawn == null:
					wrong.append("%s %s has %d blades drawn %s" % [name, rotor_name, blades, drawn != null])
		remove_child(view)
		view.free()
	_check("every_helicopter_is_drawn_by_its_own_airframe_over_a_hidden_box_with_as_many_blades_as_it_has",
		wrong.is_empty(), "heli 2+2, uh60 4+4, chinook 3+3, littlebird 6+4" if wrong.is_empty() else "; ".join(wrong))


## EACH HUB OVER STRUCTURE: straight down from each Chinook rotor head, the first drawn part the mast meets is its pylon,
## within half a metre, and that pylon stands on the fuselage. The first model's rear rotor stood on a 1.15 m post on
## the fuselage's roof with nothing round it -- measured from the drawn vertices, never from `get_aabb()`.
func _the_chinooks_rotors_stand_on_pylons() -> void:
	var view := _view(Sim.Kind.CHINOOK)
	var frame := view._rotorcraft as ChinookAirframe
	var said: PackedStringArray = []
	var ok: bool = frame != null
	if frame != null:
		var into: Transform3D = view.global_transform.affine_inverse()
		var fuselage: AABB = DrawnParts.drawn_box(frame.find_child("ChinookFuselage", true, false) as MeshInstance3D, view)
		for pair in [["ChinookFrontRotor", "ChinookFrontPylon"], ["ChinookRearRotor", "ChinookRearPylon"]]:
			var hub: Vector3 = into * (frame.find_child(String(pair[0]), true, false) as Node3D).global_position
			var pylon: AABB = DrawnParts.drawn_box(frame.find_child(String(pair[1]), true, false) as MeshInstance3D, view)
			var under: bool = hub.x >= pylon.position.x and hub.x <= pylon.end.x and hub.z >= pylon.position.z \
				and hub.z <= pylon.end.z
			var gap: float = hub.y - pylon.end.y
			var stands: bool = pylon.position.y <= fuselage.end.y + 0.01
			ok = ok and under and gap >= 0.0 and gap <= 0.6 and stands
			said.append("%s %.2f m over its pylon%s%s" % [pair[0], gap, "" if under else ", NOT over it",
				"" if stands else ", which floats"])
	_check("the_chinooks_rotors_each_stand_on_a_pylon_that_stands_on_the_fuselage", ok, "; ".join(said))
	remove_child(view)
	view.free()


## TURNING WHEN CREWED, STILL WHEN PARKED, through the same call `draw` makes, handed a bus as the machine holds it.
func _the_rotors_turn_when_crewed_and_stand_still_when_parked() -> void:
	var wrong: PackedStringArray = []
	for kind in [Sim.Kind.HELI, Sim.Kind.UH60, Sim.Kind.CHINOOK, Sim.Kind.LITTLEBIRD, Sim.Kind.APACHE]:
		var view := _view(kind)
		var rotor: Node3D = view._rotorcraft.get("main_rotor") if kind != Sim.Kind.CHINOOK \
			else view._rotorcraft.get("front_rotor")
		var rest: Basis = rotor.get_meta(&"rest", Basis.IDENTITY)
		view.draw_the_rotors_from({"throttle": 0.0}, PackedInt64Array([-1, -1]), Vector3.ZERO, 3.3)
		var parked: bool = rotor.basis.is_equal_approx(rest)
		view.draw_the_rotors_from({"throttle": 0.6}, PackedInt64Array([7, -1]), Vector3.ZERO, 3.3)
		var one: Basis = rotor.basis
		view.draw_the_rotors_from({"throttle": 0.6}, PackedInt64Array([7, -1]), Vector3.ZERO, 3.5)
		var turned: bool = not rotor.basis.is_equal_approx(one) and not one.is_equal_approx(rest)
		var disc := rotor.get_node_or_null(NodePath(String(rotor.name) + "Disc")) as MeshInstance3D
		if not parked or not turned or disc == null or not disc.visible:
			wrong.append("%s parked %s, turning %s, disc %s" % [Sim.kind_name(kind), parked, turned,
				disc != null and disc.visible])
		remove_child(view)
		view.free()
	_check("the_rotors_turn_when_crewed_with_the_collective_up_and_stand_still_when_parked", wrong.is_empty(),
		"all three" if wrong.is_empty() else "; ".join(wrong))


## THE RAMP FROM EACH MACHINE'S OWN BUS, ON EVERY TICK: a server and two client worlds over a loopback, the pilot's
## machine sending the ramp up at tick 120 and down again at 240, a crew member's machine seated behind.
func _the_chinooks_ramp_is_drawn_from_each_machines_bus_on_every_tick() -> void:
	var server := _world(0)
	var clients: Array = [_world(1), _world(2)]
	var made: Dictionary = server.spawn_pilot(1, Sim.Kind.CHINOOK, Vector3(0.0, 800.0, 0.0), 0.0, Vector3.ZERO)
	var craft: int = int(made.get("vehicle", 0))
	server.spawn_pilot(2, Sim.Kind.POD, Vector3(3000.0, 600.0, 0.0), 0.0, Vector3.ZERO)
	var crew_seated: bool = bool(server.seat_client(2, craft, 3))
	var views: Array[VehicleView] = []
	for i in range(2):
		views.append(_view(Sim.Kind.CHINOOK))
	var disagreed: Array[int] = [0, 0]
	var seen: Array[int] = [0, 0]
	var went_up: Array[bool] = [false, false]
	var came_down: Array[bool] = [false, false]
	var closed_angle: float = 0.0
	for tick in range(360):
		clients[0].set_input(_controls({"throttle": 0.5}))
		if tick == 120:
			clients[0].send_command(Sim.Channel.GEAR, 0)
		if tick == 240:
			clients[0].send_command(Sim.Channel.GEAR, 1)
		clients[1].set_input(_controls())
		server.tick(DT)
		for client in clients:
			client.tick(DT)
		for packet in server.take_outbound():
			var to: int = int(packet["peer"]) - 1
			if to >= 0 and to < clients.size():
				clients[to].deliver(0, packet["bytes"], packet["bits"])
		for i in range(clients.size()):
			for packet in clients[i].take_outbound():
				server.deliver(i + 1, packet["bytes"], packet["bits"])
		for i in range(clients.size()):
			var entity: int = 0
			for state in clients[i].vehicle_states():
				if int((state as Dictionary).get("kind", -1)) == Sim.Kind.CHINOOK:
					entity = int((state as Dictionary).get("entity", 0))
			if entity == 0:
				continue
			var bus: Dictionary = clients[i].craft_controls(entity)
			if bus.is_empty():
				continue
			seen[i] += 1
			views[i].draw_the_rotors_from(bus, clients[i].vehicle_seats(entity), Vector3.ZERO, float(tick) * DT)
			var frame := views[i]._rotorcraft as ChinookAirframe
			var down: bool = bool(bus.get("gear", true))
			if not down:
				went_up[i] = true
				closed_angle = rad_to_deg(frame.ramp.rotation.x)
			elif went_up[i]:
				came_down[i] = true
			if frame.ramp_amount() != (1.0 if down else 0.0):
				disagreed[i] += 1
	_check("the_chinooks_ramp_is_drawn_from_each_machines_bus_on_every_tick",
		crew_seated and went_up[0] and went_up[1] and came_down[0] and came_down[1] and disagreed[0] == 0
			and disagreed[1] == 0 and seen[0] > 100 and seen[1] > 100 and absf(closed_angle + 90.0) < 0.5,
		"crew seated %s; the pilot's machine: up %s, down again %s, disagreed on %d of %d ticks; the crew's: up %s, down again %s, disagreed on %d of %d; closed at %.0f deg"
			% [crew_seated, went_up[0], came_down[0], disagreed[0], seen[0], went_up[1], came_down[1], disagreed[1],
				seen[1], closed_angle])
	for view in views:
		remove_child(view)
		view.free()
	_let_go(server)
	for client in clients:
		_let_go(client)


func _world(id: int) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(60.0)
	world.start(id)
	return world


func _let_go(world: Object) -> void:
	world.teardown()
	if not (world is RefCounted):
		world.free()


func _controls(overrides: Dictionary = {}) -> Dictionary:
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


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
