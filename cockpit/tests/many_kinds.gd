extends Node
## Headless: a craft kind is a number the whole game can grow into, and one this build does not have is refused.
##
##   Godot --headless --path cockpit res://tests/many_kinds.tscn
##
## THE USER, 2026-09-18: "let's make it so we can have more kinds, i'd like to have lots of vehicle kinds", and then
## "Let's make sure we resolve these bugs and allow for growth". The audit behind this suite (lane/kinds) found the kind
## was five bits in two places on the wire, and two bugs in how a number past the table was treated:
##
## - A kind a client named was MASKED to five bits, not refused: `set_pilot_input` did `& 0x1F`, so kind 33 left as 1
##   and the player asking for it was put in a light aeroplane. Red here on main's library.
## - A kind this build does not have was SPAWNED AS A POD: `kind_index` answers the pod for anything it does not know,
##   which is right for drawing and wrong for doing. `spawn_vehicle(300)` made one and said nothing.
##
## Every refusal has a control beside it that proves the same path does work, as tests/nobody_aboard.gd does: a refusal
## on a path that never worked at all would pass with nothing tested. The frames go in through `set_pilot_input`, the
## frame the wire carries, not through the functions underneath.
##
## AND THE WIDTH. A kind is `kKindIdBits` (16) wide now, with "no kind" the top of it, both read by GDScript through
## `CockpitWorld.kind_limits` and held here against `Sim`. It travels in the five-bit field it always had while it is
## below 30, and in twenty-one bits past that, so no frame of today's grew. Kind 300 goes through the real serialisers
## (`kind_wire_probe`, since no craft has that number) and through a JOINER'S real input frame over an in-process link to
## a server that refuses it by name -- 300 arriving as 300, which on the five-bit wire it could not.
##
## MUTANTS, each built and run (lane/kinds, 2026-09-18), each red on three checks here and nothing else:
##   * `kKindIdBits` 5: "5 bits"; kind 300 (and 31, 4096) comes back from every serialiser as 31; the joiner's 300
##     reaches the server as 30.
##   * `kNoKind` typed 31 with the width at 16: "31 for 16 bits"; the same round trips; the joiner's 300 arrives as 30.
##   * `Sim.NO_KIND` typed 31 in sim.gd: "Sim.NO_KIND 31, the library 65535".
##
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
const CLIENT: int = 1
## A KIND NO BUILD HERE HAS YET, far past five bits and inside sixteen.
const FAR_KIND: int = 300

var _failures: PackedStringArray = []
var _sections: int = 0
const SECTIONS: int = 9
## THE KINDS THAT FALL TO `default_bus` ON PURPOSE, each with its reason. A kind with a package that falls to a default
## and is not here is red, and so is one here that no longer falls to it -- the list is kept honest both ways. Reasoned
## with team-lead on 2026-09-18: the master arm gates only the gun on the weapon SELECTOR; a crew-served mount
## (`gun_of`, fired by `fire_round`) never reads it, as the carrier's two gun tubs never had one.
const INTENDED_DEFAULT_BUS: Dictionary = {
	"TRAIN": "throttle, lights, crew button and radio are a train's whole panel, and it has no guns",
	"GUNBOAT": "its two pintle guns are crew-served, which fire_round never arms, and the default no longer hangs a hover hold on it (lane/boats)",
	"PIRATE": "nobody may board it, and its guns are drawn only: gun_of and loadout_of have no case for it",
	"SEGWAY": "a person standing on an invisible sphere, with no panel to put a switch on",
}
## And `default_handling`, which every kind has a case in today.
const INTENDED_DEFAULT_HANDLING: Dictionary = {}
const DT: float = 1.0 / 120.0
const JOINER_PEER: int = 2
const SPECTATOR_PEER: int = 3
var _server: RefCounted = null
var _joiner: RefCounted = null
var _spectator: RefCounted = null
var _tick: int = 0
## [[due_tick, to (0 server, else a peer), from_peer, bytes, bits], ...]
var _in_flight: Array = []
var _up_bytes: int = 0
## What the joiner's hands and buttons say this tick; `kind_wanted` rides here until it is let go.
var _joiner_input: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[many_kinds] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	# EACH SECTION COUNTS ITSELF ON ITS LAST LINE: a GDScript error ends the function and the caller carries on.
	_a_kind_named_past_the_table_is_refused_not_masked()
	_a_kind_this_build_does_not_have_is_not_spawned_as_a_pod()
	_a_kind_this_build_does_not_have_is_not_retuned_or_named_as_the_pod()
	_the_widths_are_one_place()
	_every_kind_the_width_holds_goes_through_the_real_serialisers()
	_a_joiner_asking_for_kind_300_is_refused_by_name_and_boards_the_last_kind()
	_a_kind_has_a_key_up_to_F35_and_none_past_it()
	_Sim_Kind_is_written_from_the_library_s_table()
	_no_kind_falls_to_a_default_without_saying_so()
	_finish()


func _finish() -> void:
	_check("every_section_ran_to_its_end", _sections == SECTIONS, "%d of %d" % [_sections, SECTIONS])
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


## A server world with a pod for the client and a light aeroplane to be moved into.
func _world() -> Dictionary:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	var plane: int = int(world.spawn_vehicle(Sim.Kind.PLANE, Vector3(0.0, 300.0, 0.0), 0.0, Vector3(0.0, 0.0, -60.0)))
	var made: Dictionary = world.spawn_pilot(CLIENT, Sim.Kind.POD, Vector3(0.0, 50.0, 0.0), 0.0, Vector3.ZERO)
	for i in range(10):
		world.tick(TICK)
	return {"world": world, "plane": plane, "pod": int(made.get("vehicle", 0)), "pilot": int(made.get("pilot", 0))}


## A PRESS of the next-kind button naming `wanted`, and the release, so the server's edge detection sees exactly one.
func _press(world: Object, pilot: int, wanted: int) -> void:
	for i in range(3):
		world.set_pilot_input(pilot, {"buttons": Sim.BUTTON_KIND, "kind_wanted": wanted})
		world.tick(TICK)
	for i in range(3):
		world.set_pilot_input(pilot, {"buttons": 0, "kind_wanted": Sim.NO_KIND})
		world.tick(TICK)


static func _aboard(world: Object, vehicle: int) -> bool:
	return (world.vehicle_seats(vehicle) as PackedInt64Array).has(CLIENT)


static func _refused(world: Object) -> int:
	return int(world.refused_kinds()) if world.has_method("refused_kinds") else -1


## KIND 33, AND THE FIRST NUMBER PAST THE TABLE. 33 was masked to 1, the light aeroplane; one past the last kind was read
## as "the next one, whatever it is", which is also the aeroplane here. Both stay in the pod, counted. The control is the
## same press naming the aeroplane.
func _a_kind_named_past_the_table_is_refused_not_masked() -> void:
	var built: Dictionary = _world()
	var world: Object = built["world"]
	var past: int = int(world.kind_count())
	var before: int = _refused(world)
	# THE NUMBER THAT MASKS TO 1 AND IS PAST THE TABLE: 33 until kind 33 existed (the A-10C, lane/warthog, 2026-09-19),
	# then the next one up that five and six bits both read as 1, 65. Typed 33, this check went red the day 33 was real.
	var masked: int = 33
	while masked < past:
		masked += 32
	_press(world, int(built["pilot"]), masked)
	_check("a_press_naming_kind_33_does_not_put_the_player_in_kind_1",
		not _aboard(world, int(built["plane"])) and _aboard(world, int(built["pod"])),
		"in the aeroplane %s, in the pod %s" % [_aboard(world, int(built["plane"])), _aboard(world, int(built["pod"]))])
	_check("and_the_refusal_is_counted", before >= 0 and _refused(world) > before,
		"%d refused, from %d" % [_refused(world), before])
	var then: int = _refused(world)
	_press(world, int(built["pilot"]), past)
	_check("a_press_naming_one_past_the_last_kind_is_refused_not_walked",
		not _aboard(world, int(built["plane"])) and _refused(world) == then + 1,
		"kind %d: in the aeroplane %s, %d refused from %d" % [past, _aboard(world, int(built["plane"])), _refused(world), then])
	_press(world, int(built["pilot"]), Sim.Kind.PLANE)
	_check("and_the_same_press_naming_the_aeroplane_puts_them_in_it", _aboard(world, int(built["plane"])),
		"seats %s" % world.vehicle_seats(int(built["plane"])))
	world.teardown()
	_sections += 1


## `spawn_vehicle` AND `spawn_pilot` FOR KIND 300: nothing made, counted. A pod and an aeroplane are the controls.
func _a_kind_this_build_does_not_have_is_not_spawned_as_a_pod() -> void:
	var built: Dictionary = _world()
	var world: Object = built["world"]
	var before: int = _refused(world)
	var vehicle: int = int(world.spawn_vehicle(FAR_KIND, Vector3(100.0, 300.0, 0.0), 0.0, Vector3.ZERO))
	var pilot: Dictionary = world.spawn_pilot(CLIENT + 1, FAR_KIND, Vector3(-100.0, 50.0, 0.0), 0.0, Vector3.ZERO)
	var ai: int = int(world.spawn_ai_vehicle(FAR_KIND, Vector3(200.0, 300.0, 0.0), 0.0, Vector3.ZERO))
	_check("kind_%d_spawns_nothing_by_any_path" % FAR_KIND, vehicle == 0 and pilot.is_empty() and ai == 0,
		"vehicle %d, pilot %s, ai %d" % [vehicle, pilot.keys(), ai])
	_check("and_each_is_counted", before >= 0 and _refused(world) == before + 3,
		"%d refused, from %d" % [_refused(world), before])
	var plane: int = int(world.spawn_vehicle(Sim.Kind.PLANE, Vector3(100.0, 300.0, 0.0), 0.0, Vector3.ZERO))
	var pod: Dictionary = world.spawn_pilot(CLIENT + 2, Sim.Kind.POD, Vector3(0.0, 80.0, 0.0), 0.0, Vector3.ZERO)
	_check("and_the_same_calls_for_kinds_it_has_make_them", plane != 0 and int(pod.get("pilot", 0)) != 0,
		"aeroplane %d, pod %s" % [plane, pod.keys()])
	world.teardown()
	_sections += 1


## A RETUNE AND A NAME FOR KIND 300 are not the pod's. The pod's thrust is read before and after.
func _a_kind_this_build_does_not_have_is_not_retuned_or_named_as_the_pod() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	var thrust: float = float(world.handling(Sim.Kind.POD)["thrust"])
	world.set_handling(FAR_KIND, {"thrust": thrust + 1234.0})
	_check("a_retune_of_kind_%d_leaves_the_pod_alone" % FAR_KIND,
		is_equal_approx(float(world.handling(Sim.Kind.POD)["thrust"]), thrust),
		"pod thrust %.1f, was %.1f" % [float(world.handling(Sim.Kind.POD)["thrust"]), thrust])
	_check("kind_%d_is_called_what_Sim_calls_it" % FAR_KIND, String(world.kind_name(FAR_KIND)) == Sim.kind_name(FAR_KIND),
		"'%s' in the simulation, '%s' in Sim" % [world.kind_name(FAR_KIND), Sim.kind_name(FAR_KIND)])
	_check("and_a_kind_it_has_is_named", String(world.kind_name(Sim.Kind.PLANE)) == "plane",
		"'%s'" % world.kind_name(Sim.Kind.PLANE))
	_sections += 1


## THE LIBRARY SAYS EVERY WIDTH ONCE AND `Sim` READS IT. Sixteen bits at least, as asked; "no kind" the top of the width
## and out of every kind's range; as many kinds in `Sim.Kind` as in the shape table. The mutants at the top go red here.
func _the_widths_are_one_place() -> void:
	var limits: Dictionary = Sim.kind_limits()
	var bits: int = int(limits.get("id_bits", 0))
	var none: int = int(limits.get("no_kind", -1))
	var count: int = int(limits.get("kind_count", -1))
	_check("a_kind_is_at_least_sixteen_bits", bits >= 16, "%d bits, %s" % [bits, str(limits)])
	_check("no_kind_is_the_top_of_the_width", none == (1 << bits) - 1, "%d for %d bits" % [none, bits])
	_check("and_Sim_reads_it_rather_than_typing_it", Sim.NO_KIND == none, "Sim.NO_KIND %d, the library %d" % [Sim.NO_KIND, none])
	_check("and_it_is_out_of_range_of_every_kind", none >= count and count > 0, "%d against %d kinds" % [none, count])
	_check("Sim_Kind_lists_as_many_kinds_as_the_library", Sim.Kind.size() == count,
		"Sim.Kind %d, the library %d" % [Sim.Kind.size(), count])
	# PAST THE SHORT FORM SINCE THE CB90 (kind 30, lane/boats, 2026-09-18): the first real kind the extended form carries.
	# "The short form holds every kind there is today" was true until then and is retired, not loosened: every kind to the
	# top of the width round-trips in `_every_kind_the_width_holds_goes_through_the_real_serialisers`. What is held here
	# is that each real kind past the short form is a whole kind -- a name and a shape of its own, not the pod's.
	var short: int = int(limits.get("short_kinds", 0))
	var hollow: PackedStringArray = []
	var past: PackedStringArray = []
	for kind in range(short, count):
		var name: String = Sim.kind_name(kind)
		past.append(name)
		if name == "?" or name == "pod" or String(Sim.geometry_of(kind).get("name", "")) != name:
			hollow.append("%d '%s'" % [kind, name])
	_check("every_kind_past_the_short_form_is_a_whole_kind", hollow.is_empty(),
		"%d travel in %d bits; past them %s%s" % [short, int(limits.get("short_bits", 0)), str(past),
			"" if hollow.is_empty() else ", hollow: " + ", ".join(hollow)])
	_sections += 1


## KIND 300 AND ITS NEIGHBOURS THROUGH THE SERIALISERS THE WIRE USES: a full input frame, a delta one, and a
## `VehicleKind`. Every one comes back as sent, and costs five bits below `short_kinds` and twenty-one from it.
func _every_kind_the_width_holds_goes_through_the_real_serialisers() -> void:
	var limits: Dictionary = Sim.kind_limits()
	var short: int = int(limits.get("short_kinds", 0))
	var short_bits: int = int(limits.get("short_bits", 0))
	var wide_bits: int = short_bits + int(limits.get("id_bits", 0))
	var none: int = int(limits.get("no_kind", 0))
	var wrong: PackedStringArray = []
	var costs: PackedStringArray = []
	for kind in [0, 1, short - 1, short, short + 1, FAR_KIND, 4096, none - 1]:
		var trip: Dictionary = ClassDB.class_call_static(&"CockpitWorld", &"kind_wire_probe", kind)
		var bits: int = short_bits if kind < short else wide_bits
		if int(trip["full"]) != kind or int(trip["delta"]) != kind or int(trip["vehicle"]) != kind \
				or int(trip["kind_bits"]) != bits:
			wrong.append("%d -> %s" % [kind, str(trip)])
		costs.append("%d: %d" % [kind, int(trip["kind_bits"])])
	_check("every_kind_to_the_top_of_the_width_round_trips", wrong.is_empty(),
		"bits %s" % ", ".join(costs) if wrong.is_empty() else "; ".join(wrong))
	var sentinel: Dictionary = ClassDB.class_call_static(&"CockpitWorld", &"kind_wire_probe", none)
	_check("no_kind_round_trips_on_an_input_frame_and_is_refused_as_a_craft",
		int(sentinel["full"]) == none and int(sentinel["delta"]) == none and int(sentinel["vehicle"]) == -1
			and int(sentinel["kind_bits"]) == short_bits, str(sentinel))
	var today: Dictionary = ClassDB.class_call_static(&"CockpitWorld", &"kind_wire_probe", Sim.Kind.size() - 1)
	print("[many_kinds] a kind costs %d bits to %d and %d from %d; the last kind today (%d) %d; a full input frame %d bits "
		% [short_bits, short - 1, wide_bits, short, Sim.Kind.size() - 1, int(today["kind_bits"]), int(today["full_bits"])]
		+ "with it and %d with kind %d" % [int(ClassDB.class_call_static(&"CockpitWorld", &"kind_wire_probe", FAR_KIND)["full_bits"]),
			FAR_KIND])
	_sections += 1


## A JOINER, OVER A LINK, ASKS FOR KIND 300 AND THEN FOR THE LAST KIND THERE IS. The server refuses the first by its
## number -- `last_refused_kind` is what arrived -- and the joiner stays in its pod; the second puts it aboard, and a
## spectator sees that craft by its kind.
func _a_joiner_asking_for_kind_300_is_refused_by_name_and_boards_the_last_kind() -> void:
	var last: int = Sim.Kind.size() - 1
	while last > 0 and not VehicleCatalogue.pilotable(last):
		last -= 1
	if not _stand_up():
		_sections += 1
		return
	var me: int = int(_joiner.local_client_id())
	var pod: int = int(_server.spawn_pilot(me, Sim.Kind.POD, Vector3(60.0, 4.0, 60.0), 0.0, Vector3.ZERO).get("vehicle", 0))
	var craft: int = int(_server.spawn_vehicle(last, Vector3(-60.0, 4.0, -60.0), 0.0, Vector3.ZERO))
	_advance(40)
	var before: int = _refused(_server)
	_up_bytes = 0
	_press_on_the_joiner(FAR_KIND)
	var press_up: float = float(_up_bytes) / 12.0
	_check("the_server_hears_kind_%d_as_%d_and_refuses_it" % [FAR_KIND, FAR_KIND],
		_refused(_server) == before + 1 and int(_server.last_refused_kind()) == FAR_KIND,
		"%d refused from %d, the last one kind %d" % [_refused(_server), before, int(_server.last_refused_kind())
			if _server.has_method("last_refused_kind") else -1])
	_check("and_the_joiner_stays_in_its_pod", (_server.vehicle_seats(pod) as PackedInt64Array).has(me),
		"pod seats %s" % _server.vehicle_seats(pod))
	_press_on_the_joiner(last)
	_advance(60)
	var aboard: bool = (_server.vehicle_seats(craft) as PackedInt64Array).has(me)
	var seen: bool = false
	for row in _spectator.vehicle_states():
		seen = seen or int(row.get("kind", -1)) == last
	_check("the_same_press_naming_the_last_kind_%s_puts_the_joiner_in_it" % Sim.kind_name(last), aboard,
		"seats %s" % _server.vehicle_seats(craft))
	_check("and_the_spectator_sees_it_by_its_kind", seen, "kinds %s" % str(_spectator.vehicle_states().map(
		func(row: Dictionary) -> int: return int(row.get("kind", -1)))))
	print("[many_kinds] up from the joiner while pressing for kind %d: %.1f B a tick" % [FAR_KIND, press_up])
	_teardown()
	_sections += 1


## THE F-ROW: F1 plus the kind to F35, and no key past it -- not an invalid one.
func _a_kind_has_a_key_up_to_F35_and_none_past_it() -> void:
	# EVERY KIND THE ROW REACHES HAS ITS KEY. It was "the last kind today has a key" until the P-51 was kind 35, the first
	# past F35 (lane/warbirds2): a kind past the row is boarded by name (the CRAFT page and `kind_wanted`, which the joiner's
	# section above presses for the last kind), and 35 having no key is the check two lines down.
	var keyed: int = mini(Sim.Kind.size() - 1, 34)
	var missing: Array = range(keyed + 1).filter(func(k: int) -> bool: return PilotRig.kind_key(k) == KEY_NONE)
	_check("every_kind_the_f_row_reaches_has_a_key", missing.is_empty(),
		"kinds 0 to %d; with none %s" % [keyed, missing])
	_check("kind_34_is_F35", OS.get_keycode_string(PilotRig.kind_key(34)) == "F35",
		"'%s'" % OS.get_keycode_string(PilotRig.kind_key(34)))
	_check("and_kinds_35_and_300_have_none", PilotRig.kind_key(35) == KEY_NONE and PilotRig.kind_key(FAR_KIND) == KEY_NONE,
		"%d, %d" % [PilotRig.kind_key(35), PilotRig.kind_key(FAR_KIND)])
	var bound: Array = PilotRig.desk_keys().filter(func(row: Dictionary) -> bool:
		return String(row["action"]).begins_with("kind_"))
	var invalid: Array = bound.filter(func(row: Dictionary) -> bool: return (row["keys"] as Array).has(KEY_NONE))
	_check("desk_keys_binds_every_keyed_kind_and_nothing_invalid", invalid.is_empty()
		and bound.size() == PilotRig.keyed_kinds().size(), "%d bound, %d keyed, %d invalid" % [bound.size(),
			PilotRig.keyed_kinds().size(), invalid.size()])
	_sections += 1


## `Sim.Kind` IS WRITTEN FROM THE LIBRARY'S TABLE, by tools/generate_kind_enum.tscn: the same entries in the same order,
## and the block in sim.gd exactly what the tool would write, so a hand edit is red too. Each disagreement is named.
func _Sim_Kind_is_written_from_the_library_s_table() -> void:
	var table: Array = ClassDB.class_call_static(&"CockpitWorld", &"kind_table")
	var ids: PackedStringArray = []
	for row in table:
		ids.append(String(row["id"]))
	var keys: PackedStringArray = PackedStringArray(Sim.Kind.keys())
	var missing: PackedStringArray = []
	var extra: PackedStringArray = []
	var moved: PackedStringArray = []
	for i in range(ids.size()):
		if not keys.has(ids[i]):
			missing.append("%s (row %d)" % [ids[i], i])
		elif keys.find(ids[i]) != i:
			moved.append("%s is %d in Sim.Kind and row %d in the library" % [ids[i], keys.find(ids[i]), i])
	for key in keys:
		if not ids.has(key):
			extra.append(key)
	_check("Sim_Kind_names_every_row_of_the_library_s_table_in_order", missing.is_empty() and extra.is_empty()
		and moved.is_empty(), "%d rows" % ids.size() if missing.is_empty() and extra.is_empty() and moved.is_empty()
		else "missing %s, extra %s, moved %s: run res://tools/generate_kind_enum.tscn" % [missing, extra, moved])
	var tool: GDScript = load("res://tools/generate_kind_enum.gd")
	var written: String = tool.written_block(FileAccess.get_file_as_string("res://autoload/sim.gd")).replace("\r\n", "\n")
	var wanted: String = tool.enum_text(table)
	_check("and_sim_gd_holds_exactly_what_the_tool_writes", written == wanted,
		"as written" if written == wanted else "sim.gd has '%s', the tool writes '%s'" % [written.c_escape(), wanted.c_escape()])
	_sections += 1


## A DEFAULT IS NEVER SILENT. Per kind: whether it falls to `default_bus` or `default_handling`, and what guns and
## stores it has -- printed, one line each. Red for a kind with a package that falls to a default and is not listed in
## `INTENDED_DEFAULT_*` with its reason, and for a listed one that no longer does.
func _no_kind_falls_to_a_default_without_saying_so() -> void:
	var table: Array = ClassDB.class_call_static(&"CockpitWorld", &"kind_table")
	var silent: PackedStringArray = []
	var stale: PackedStringArray = []
	for row in table:
		var id: String = String(row["id"])
		var packaged: bool = DirAccess.dir_exists_absolute("res://craft/%s" % Sim.kind_name(int(row["kind"])))
		var bus: bool = bool(row["bus_default"])
		var handling: bool = bool(row["handling_default"])
		print("[many_kinds] %2d %-11s %-10s bus %-7s handling %-7s %d mounts%s%s%s" % [int(row["kind"]), row["name"],
			row["model"], "DEFAULT" if bus else "own", "DEFAULT" if handling else "own", int(row["mounts"]),
			", a selector gun" if bool(row["selector_gun"]) else "", ", %d pylons" % int(row["pylons"])
				if int(row["pylons"]) > 0 else "", "" if packaged else ", no package"])
		if packaged and bus and not INTENDED_DEFAULT_BUS.has(id):
			silent.append("%s on the default bus" % id)
		if packaged and handling and not INTENDED_DEFAULT_HANDLING.has(id):
			silent.append("%s on the default handling" % id)
		if INTENDED_DEFAULT_BUS.has(id) and not bus:
			stale.append("%s is listed for the default bus and has its own" % id)
		if INTENDED_DEFAULT_HANDLING.has(id) and not handling:
			stale.append("%s is listed for the default handling and has its own" % id)
	_check("no_kind_with_a_package_falls_to_a_default_unless_it_is_listed_with_its_reason", silent.is_empty(),
		"%d listed: %s" % [INTENDED_DEFAULT_BUS.size() + INTENDED_DEFAULT_HANDLING.size(),
			", ".join(INTENDED_DEFAULT_BUS.keys())] if silent.is_empty() else ", ".join(silent))
	_check("and_every_listed_one_still_does", stale.is_empty(), "none stale" if stale.is_empty() else ", ".join(stale))
	_sections += 1


## ---- a server, a joiner and a spectator over a one-tick link, as tests/many_devices.gd has them ----

func _stand_up() -> bool:
	_server = ClassDB.instantiate("CockpitWorld")
	_joiner = ClassDB.instantiate("CockpitWorld")
	_spectator = ClassDB.instantiate("CockpitWorld")
	_tick = 0
	_in_flight.clear()
	_joiner_input = _controls()
	for world in [_server, _joiner, _spectator]:
		world.set_tick_rate(120.0)
	_server.start(0)
	_joiner.start(JOINER_PEER)
	_spectator.start(SPECTATOR_PEER)
	for world in [_server, _joiner, _spectator]:
		world.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(400.0, 2.0, 400.0))
	_advance(90)
	var me: int = int(_joiner.local_client_id())
	var them: int = int(_spectator.local_client_id())
	_check("both_clients_handshook", me > 0 and them > 0, "client ids %d and %d" % [me, them])
	if me <= 0 or them <= 0:
		_teardown()
		return false
	_server.spawn_pilot(them, Sim.Kind.POD, Vector3(-60.0, 4.0, 60.0), 0.0, Vector3.ZERO)
	return true


## A PRESS OF THE NEXT-KIND BUTTON NAMING `kind`, from the joiner's own input, then let go: six ticks each, so the frame
## rides the link and the server's edge detection sees exactly one.
func _press_on_the_joiner(kind: int) -> void:
	_joiner_input["buttons"] = Sim.BUTTON_KIND
	_joiner_input["kind_wanted"] = kind
	_advance(6)
	_joiner_input["buttons"] = 0
	_joiner_input["kind_wanted"] = Sim.NO_KIND
	_advance(6)


func _controls() -> Dictionary:
	return {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0, "kind_wanted": Sim.NO_KIND,
	}


func _advance(ticks: int) -> void:
	for i in range(ticks):
		_joiner.set_input(_joiner_input)
		_spectator.set_input(_controls())
		_tick += 1
		_server.tick(DT)
		_joiner.tick(DT)
		_spectator.tick(DT)
		_pump()


## A ONE-TICK LINK: everything sent this tick is delivered before the next.
func _pump() -> void:
	for packet in _server.take_outbound():
		_in_flight.append([_tick, int(packet["peer"]), 0, packet["bytes"], packet["bits"]])
	for packet in _joiner.take_outbound():
		_up_bytes += (packet["bytes"] as PackedByteArray).size()
		_in_flight.append([_tick, 0, JOINER_PEER, packet["bytes"], packet["bits"]])
	for packet in _spectator.take_outbound():
		_in_flight.append([_tick, 0, SPECTATOR_PEER, packet["bytes"], packet["bits"]])
	var still_flying: Array = []
	for entry in _in_flight:
		if int(entry[0]) > _tick:
			still_flying.append(entry)
			continue
		match int(entry[1]):
			0:
				_server.deliver(int(entry[2]), entry[3], entry[4])
			JOINER_PEER:
				_joiner.deliver(0, entry[3], entry[4])
			SPECTATOR_PEER:
				_spectator.deliver(0, entry[3], entry[4])
	_in_flight = still_flying


func _teardown() -> void:
	for world in [_joiner, _spectator, _server]:
		if world != null:
			world.teardown()
	_joiner = null
	_spectator = null
	_server = null
	_in_flight.clear()
