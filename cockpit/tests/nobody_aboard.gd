extends Node
## Headless: a craft nobody may board is refused by the server, on every path a player has to it.
##
##   Godot --headless --path cockpit res://tests/nobody_aboard.tscn
##
## THE PIRATE SHIP IS SAILED BY THE WORLD AND BY NOBODY ELSE YET, and the CRAFT page not offering
## it (tests/clipboard.gd) is only half of that. A page is the client's, and a client's input is a
## proposal: a modified client, or a key bound by hand, can put any kind it likes in `kind_wanted`.
## So the SERVER refuses it, by the shape table's `pilotable` flag, and says so. This suite plays
## a client's input frames into a server world through `set_pilot_input` -- the frame the wire
## carries -- and not through the functions underneath.
##
## Every refusal has a control beside it that proves the same path does work: a forged request
## refused on a path that never worked at all would pass with nothing tested.
##
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
const CLIENT: int = 1

var _failures: PackedStringArray = []
var _sections: int = 0
const SECTIONS: int = 4
## THE ONE KIND THE TWO LISTS SPELL DIFFERENTLY: `Sim.Kind.HELI` is the shape table's "helicopter".
const SPELT_OTHERWISE: Dictionary = {"heli": "helicopter"}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[nobody_aboard] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	# EACH SECTION COUNTS ITSELF ON ITS LAST LINE. Counted here after each call, the first draft
	# printed RESULT=PASS with two of its three sections dead on their first line: a GDScript error
	# ends the function and the caller carries on.
	_the_simulation_and_Sim_Kind_list_the_same_kinds_in_the_same_order()
	_the_simulation_says_the_pirate_ship_may_not_be_boarded()
	_a_forged_request_for_the_kind_is_refused_and_counted()
	_the_next_craft_walk_and_a_named_seat_never_land_in_it()
	_finish()


func _finish() -> void:
	_check("every_section_ran_to_its_end", _sections == SECTIONS, "%d of %d" % [_sections, SECTIONS])
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


## A server world with a pod for the client, a light aeroplane and a pirate ship.
func _world() -> Dictionary:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	var plane: int = int(world.spawn_vehicle(Sim.Kind.PLANE, Vector3(0.0, 300.0, 0.0), 0.0, Vector3(0.0, 0.0, -60.0)))
	var pirate: int = int(world.spawn_ai_vehicle(Sim.Kind.PIRATE, Vector3(3000.0, 0.0, 0.0), 0.0, Vector3.ZERO))
	# `spawn_pilot` answers {pilot, vehicle}: the pilot entity and the pod it was put in.
	var made: Dictionary = world.spawn_pilot(CLIENT, Sim.Kind.POD, Vector3(0.0, 50.0, 0.0), 0.0, Vector3.ZERO)
	return {"world": world, "plane": plane, "pirate": pirate, "pilot": int(made.get("pilot", 0))}


## A PRESS on the frame and then the release, as a player's hand makes one: a level for a few
## ticks, then nothing, so the server's edge detection sees exactly one.
func _press(world: Object, pilot: int, buttons: int, wanted: int) -> void:
	for i in range(3):
		world.set_pilot_input(pilot, {"buttons": buttons, "kind_wanted": wanted})
		world.tick(TICK)
	for i in range(3):
		world.set_pilot_input(pilot, {"buttons": 0, "kind_wanted": Sim.NO_KIND})
		world.tick(TICK)


static func _aboard(world: Object, vehicle: int) -> bool:
	return (world.vehicle_seats(vehicle) as PackedInt64Array).has(CLIENT)


## KINDS ARE TYPED IN TWO PLACES, `kKind*` in the C++ and `Sim.Kind` here, and a number is what
## crosses between them: a kind added to one and not the other, or in a different place, is every
## craft after it drawn and named as its neighbour. So the count, and each name in order, are asked
## of the simulation's own table (`kind_count`, `kind_name`) and held against the enum.
func _the_simulation_and_Sim_Kind_list_the_same_kinds_in_the_same_order() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	var count: int = int(world.kind_count())
	var differ: PackedStringArray = []
	for kind in range(maxi(count, Sim.Kind.size())):
		var ours: String = Sim.kind_name(kind)
		var theirs: String = String(world.kind_name(kind)) if kind < count else "(none)"
		if String(SPELT_OTHERWISE.get(ours, ours)) != theirs:
			differ.append("%d: %s against %s" % [kind, ours, theirs])
	_check("the_simulation_and_Sim_Kind_have_the_same_kinds_in_the_same_order",
		count == Sim.Kind.size() and differ.is_empty(),
		"%d in the simulation, %d in Sim.Kind%s" % [count, Sim.Kind.size(), "" if differ.is_empty() else ": %s" % differ])
	_sections += 1


func _the_simulation_says_the_pirate_ship_may_not_be_boarded() -> void:
	var shape: Dictionary = Sim.geometry_of(Sim.Kind.PIRATE)
	_check("the_pirate_ship_is_not_pilotable_in_the_simulations_own_table",
		shape.has("pilotable") and not bool(shape["pilotable"]), "%s" % shape.get("pilotable", "no key"))
	_check("and_an_aeroplane_is", bool(Sim.geometry_of(Sim.Kind.PLANE).get("pilotable", false)),
		"%s" % Sim.geometry_of(Sim.Kind.PLANE).get("pilotable", "no key"))
	_sections += 1


## A CLIENT'S FRAME NAMING THE PIRATE KIND. Refused, counted and said; the same frame naming an
## aeroplane is the control, and it moves them.
func _a_forged_request_for_the_kind_is_refused_and_counted() -> void:
	var built: Dictionary = _world()
	var world: Object = built["world"]
	for i in range(10):
		world.tick(TICK)
	var before: int = int(world.refused_boardings())
	_press(world, int(built["pilot"]), Sim.BUTTON_KIND, Sim.Kind.PIRATE)
	_check("a_frame_asking_for_the_pirate_kind_does_not_put_the_player_aboard",
		not _aboard(world, int(built["pirate"])), "seats %s" % world.vehicle_seats(int(built["pirate"])))
	_check("and_the_server_counts_the_refusal",
		int(world.refused_boardings()) == before + 1, "%d refused, from %d" % [world.refused_boardings(), before])
	_press(world, int(built["pilot"]), Sim.BUTTON_KIND, Sim.Kind.PLANE)
	_check("and_the_same_press_naming_an_aeroplane_does_put_them_in_one",
		_aboard(world, int(built["plane"])), "seats %s" % world.vehicle_seats(int(built["plane"])))
	world.teardown()
	_sections += 1


## THE NEXT-CRAFT BUTTON WALKS EVERY CRAFT WITH A FREE SEAT, and the pirate ship has none; a seat
## named outright is refused.
func _the_next_craft_walk_and_a_named_seat_never_land_in_it() -> void:
	var built: Dictionary = _world()
	var world: Object = built["world"]
	var landed: int = 0
	var visited: Dictionary = {}
	for i in range(8):
		_press(world, int(built["pilot"]), Sim.BUTTON_USE, Sim.NO_KIND)
		if _aboard(world, int(built["pirate"])):
			landed += 1
		if _aboard(world, int(built["plane"])):
			visited["plane"] = true
	_check("walking_every_craft_never_lands_in_the_pirate_ship",
		landed == 0 and visited.has("plane"), "%d of 8 presses in the pirate ship, the aeroplane visited %s" % [landed,
			visited.has("plane")])
	var before: int = int(world.refused_boardings())
	var seated: bool = bool(world.seat_client(CLIENT, int(built["pirate"]), 0))
	_check("and_a_seat_in_it_named_outright_is_refused_and_counted",
		not seated and not _aboard(world, int(built["pirate"])) and int(world.refused_boardings()) == before + 1,
		"seated %s, %d refused from %d" % [seated, world.refused_boardings(), before])
	# AND A PILOT STARTED IN ONE, the level's own path: no pilot, counted. A pod is the control.
	var refused_before: int = int(world.refused_boardings())
	var started: Dictionary = world.spawn_pilot(CLIENT + 1, Sim.Kind.PIRATE, Vector3(-3000.0, 0.0, 0.0), 0.0, Vector3.ZERO)
	var pod: Dictionary = world.spawn_pilot(CLIENT + 2, Sim.Kind.POD, Vector3(0.0, 80.0, 0.0), 0.0, Vector3.ZERO)
	_check("and_a_pilot_started_in_one_is_not_made_but_one_started_in_a_pod_is",
		started.is_empty() and int(pod.get("pilot", 0)) != 0 and int(world.refused_boardings()) == refused_before + 1,
		"pirate start %s, pod start %s, %d refused from %d" % [started, pod.keys(), world.refused_boardings(), refused_before])
	world.teardown()
	_sections += 1
