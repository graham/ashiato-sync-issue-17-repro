extends Node
## Headless: A CRAFT MAY HAVE AS MANY SEATS AS IT IS BUILT WITH, and joiners fill seats far past the fourth.
##
##   Godot --headless --xr-mode off --fixed-fps 120 --path cockpit res://tests/many_seats.tscn
##
## THE USER, 2026-09-18, asked whether a craft should be able to have more than four seats: "yes, no max." The audit
## behind this suite (lane/seats) found four seats in the C++ (`kMaxSeats`), two bits a seat on the wire, three for "any
## seat" and "nobody's hands", four occupant bytes on every craft and four seats' hands on every crew member's cabin --
## and two places where a seat past the fourth was MASKED rather than refused:
##
## - A JOIN naming seat 5 became "any free seat": `set_pilot_input` turned anything past `kMaxSeats` into `kAnySeat`,
##   so the player was put in the first free seat and told "joined". Red here on bd43f201's library.
## - `seat_pose(kind, 5)` answered seat 0's pose and `valid` true, so the fifth seat of the pod was the pilot's.
##
## WHAT IS REAL HERE. A server and six client CockpitWorlds over the in-process one-tick link `many_devices` uses: five
## joiners and a spectator in a pod of their own. An airliner fitted with twelve seats (`Sim.fit_seats`) and a Chinook
## with seventy-two. The first joiner presses JOIN on the CREW page a ClipboardPage draws from its own world's manifest,
## and its press becomes the input frame the rig would build; the others send that frame for the seats the page folds
## away. What each machine SEES is read back off its own world: the craft's Seats (`vehicle_seats`), each pilot's own
## record (`pilot_states`), the crew's hands (`crew_controls`), and the manifest the spectator's page would draw.
##
## WHAT IT HOLDS, each checked, not printed:
##   * the widths are one place: a seat is at least sixteen bits, a craft holds at least as many people as a session
##     has players, `Sim.ANY_SEAT` is -1 rather than the library's sentinel, and Net will host;
##   * a fit is all or nothing and refused while a world runs;
##   * a join on a seat a craft lacks is refused and counted, never put in another seat, and `seat_pose` past the table
##     is not the pilot's;
##   * the CREW page folds a long cabin's free seats a station to a cell and wraps past four, and its JOIN asks for the
##     seat it says;
##   * joiners sit in seats 7, 9 and 11 of twelve and 40 and 63 of seventy-two, every machine says so, the spectator
##     included, and each pilot's own record carries the wide seat across the wire;
##   * nobody's hands read -1 in a craft whose seat 7 flies it; the copilot in seat 7 is the hands on the controls, and
##     an operator's throttle in seat 9 and a hand in seat 63 reach every other crew member and never the spectator;
##   * a craft holds at most `most_aboard` people, the next is refused, and the wire carries all of them;
##   * and what it costs, printed.
##
## MUTANTS, each built and run: see learnings/2026-09-18-seats.md.
##
## Read RESULT=, not the exit code.

const DT: float = 1.0 / 120.0
const TICK_HZ: float = 120.0
const HOST_CLIENT: int = 1
const JOINER: int = 2
## A SEAT NO CRAFT IN THIS BUILD HAS, and one the old three-bit wire could still name.
const MISSING_SEAT: int = 5
const POD: int = 0
## THE TWO CRAFT: an airliner of twelve seats, the pilot in 0, a copilot in 7 and operators everywhere else; a Chinook of
## seventy-two, a pilot and seventy-one operators: more seats than a craft holds people, so that the one past them is
## refused with a seat still free. Their pilots are players with no machine, as many_devices' are.
const LONG: int = Sim.Kind.AIRLINER
const VERY_LONG: int = Sim.Kind.CHINOOK
const LONG_SEATS: int = 12
const VERY_LONG_SEATS: int = 72
## SEVEN, THE OLD SENTINEL: a copilot there with their hands on the stick must read as seat 7 and not as nobody, which a
## `kNobodyHandsOn` typed as 7 would make it on every machine alike (mutant B, lane/seats).
const LONG_COPILOT: int = 7
const LONG_PILOT_CLIENT: int = 201
const VERY_LONG_PILOT_CLIENT: int = 202
## Peers 2 to 6 are the joiners, 7 the spectator.
const JOINERS: Array[int] = [2, 3, 4, 5, 6]
const SPECTATOR: int = 7
## WHERE EACH JOINER SITS: [craft, seat]. The first gets there through the CREW page.
const WANTED: Array = [[LONG, LONG_COPILOT], [LONG, 9], [LONG, 11], [VERY_LONG, 40], [VERY_LONG, 63]]

var _failures: PackedStringArray = []
var _sections: int = 0
const SECTIONS: int = 7

var _server: RefCounted = null
## peer -> its CockpitWorld, joiners and the spectator.
var _clients: Dictionary = {}
## peer -> the input frame it sends every tick.
var _frames: Dictionary = {}
var _tick: int = 0
var _in_flight: Array = []
var _bytes_down: Dictionary = {}
var _server_usec: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[many_seats] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	# EACH SECTION COUNTS ITSELF ON ITS LAST LINE: a GDScript error ends the function and the caller carries on.
	_the_widths_are_one_place()
	_a_join_naming_a_seat_the_craft_lacks_is_refused_not_put_anywhere()
	_a_seat_pose_past_the_table_is_not_the_pilots()
	_a_fit_is_all_or_nothing()
	var long_fit: Dictionary = Sim.fit_seats(LONG, _cabin(LONG_SEATS, LONG_COPILOT))
	var very_long_fit: Dictionary = Sim.fit_seats(VERY_LONG, _cabin(VERY_LONG_SEATS, -1))
	_check("the_two_long_cabins_are_fitted", int(long_fit.get("fitted", 0)) == LONG_SEATS
		and int(very_long_fit.get("fitted", 0)) == VERY_LONG_SEATS
		and (Sim.geometry_of(VERY_LONG).get("seat_poses", []) as Array).size() == VERY_LONG_SEATS,
		"%s, %s" % [long_fit, very_long_fit])
	await _the_crew_page_folds_a_long_cabin()
	_joiners_sit_far_down_the_cabin_and_everybody_sees_who()
	_finish()


func _finish() -> void:
	_teardown()
	Sim.fit_seats(LONG, [])
	Sim.fit_seats(VERY_LONG, [])
	_check("every_section_ran_to_its_end", _sections == SECTIONS, "%d of %d" % [_sections, SECTIONS])
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


## A CABIN OF `count` SEATS: a pilot in 0, a copilot in `copilot` if it is not -1, operators in the rest, two abreast.
static func _cabin(count: int, copilot: int) -> Array:
	var out: Array = []
	for seat in range(count):
		var station: String = "pilot" if seat == 0 else ("copilot" if seat == copilot else "operator")
		out.append({"position": Vector3(-0.6 if seat % 2 == 0 else 0.6, 0.0, -8.0 + 0.9 * float(seat / 2)),
			"yaw": 0.0, "station": station})
	return out


## ---- 1: the widths ------------------------------------------------------------------------

func _the_widths_are_one_place() -> void:
	var limits: Dictionary = Sim.seat_limits()
	var bits: int = int(limits.get("seat_bits", 0))
	_check("a_seat_is_at_least_sixteen_bits_as_no_max_asks", bits >= 16
		and int(limits.get("most_seats", 0)) >= (1 << bits) - 2, "%s" % limits)
	_check("a_craft_holds_at_least_as_many_people_as_a_session_has_players",
		int(limits.get("most_aboard", 0)) >= Net.MAX_PLAYERS and Net.host_refusal() == "",
		"most aboard %d, players %d, Net says '%s'" % [int(limits.get("most_aboard", 0)), Net.MAX_PLAYERS,
			Net.host_refusal()])
	_check("any_seat_is_not_a_seat_number", Sim.ANY_SEAT < 0, "Sim.ANY_SEAT %d" % Sim.ANY_SEAT)
	_sections += 1


## ---- 2 and 3: the two masks -----------------------------------------------------------------

## THE FIRST PILOTABLE KIND WITH THIS MANY SEATS, past the pod the joiner starts in, asked of the simulation's own
## table rather than named here.
static func _seater(world: Object, seats: int) -> int:
	for kind in range(1, int(world.kind_count())):
		var geometry: Dictionary = world.kind_geometry(kind)
		if int(geometry.get("seats", 0)) == seats and bool(geometry.get("pilotable", false)):
			return kind
	return -1


## A server world: the host's player flying a four-seater, the joiner in a pod.
func _world() -> Dictionary:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	var kind: int = _seater(world, 4)
	var host: Dictionary = world.spawn_pilot(HOST_CLIENT, kind, Vector3(0.0, 300.0, 0.0), 0.0, Vector3(0.0, 0.0, -60.0))
	var joiner: Dictionary = world.spawn_pilot(JOINER, POD, Vector3(200.0, 50.0, 0.0), 0.0, Vector3.ZERO)
	for i in range(10):
		world.tick(DT)
	return {"world": world, "kind": kind, "craft": int(host.get("vehicle", 0)), "joiner": int(joiner.get("pilot", 0)),
		"pod": int(joiner.get("vehicle", 0))}


## ONE JOIN PRESS, as the clipboard makes it: the menu number moves, and the player and the seat ride beside it.
var _menu_request: int = 0
func _join(world: Object, pilot: int, with_client: int, seat: int) -> void:
	_menu_request = (_menu_request + 1) % Sim.MENU_REQUESTS
	for i in range(4):
		world.set_pilot_input(pilot, {"join_wanted": with_client, "join_seat": seat, "menu_request": _menu_request})
		world.tick(DT)
	for i in range(2):
		world.set_pilot_input(pilot, {"join_wanted": 255, "join_seat": Sim.ANY_SEAT, "menu_request": _menu_request})
		world.tick(DT)


static func _last_why(world: Object) -> String:
	var log: Array = world.join_log()
	return String((log.back() as Dictionary).get("why", "")) if not log.is_empty() else "(nothing decided)"


## SEAT 5 OF A FOUR-SEATER. The joiner stays in their pod and the server says "no_such_seat"; it said "joined" and
## put them in seat 1. The control is the same press naming seat 2.
func _a_join_naming_a_seat_the_craft_lacks_is_refused_not_put_anywhere() -> void:
	var built: Dictionary = _world()
	var world: Object = built["world"]
	var craft: int = int(built["craft"])
	_check("there_is_a_four_seater_to_join", int(built["kind"]) >= 0 and craft != 0,
		"kind %d, craft %d" % [int(built["kind"]), craft])
	_join(world, int(built["joiner"]), HOST_CLIENT, MISSING_SEAT)
	var seats: PackedInt64Array = world.vehicle_seats(craft)
	_check("a_join_on_seat_%d_of_a_four_seater_puts_the_joiner_nowhere" % MISSING_SEAT, not seats.has(JOINER),
		"seats %s" % seats)
	_check("and_the_server_says_no_such_seat", _last_why(world) == "no_such_seat", "'%s'" % _last_why(world))
	var refused: int = int(world.refused_seats()) if world.has_method("refused_seats") else -1
	_join(world, int(built["joiner"]), HOST_CLIENT, 70000)
	_check("a_seat_the_wire_cannot_name_is_refused_and_counted",
		not (world.vehicle_seats(craft) as PackedInt64Array).has(JOINER) and refused >= 0
			and int(world.refused_seats()) > refused and _last_why(world) == "no_such_seat",
		"seats %s, refused %d from %d, '%s'" % [world.vehicle_seats(craft),
			int(world.refused_seats()) if world.has_method("refused_seats") else -1, refused, _last_why(world)])
	_join(world, int(built["joiner"]), HOST_CLIENT, 2)
	seats = world.vehicle_seats(craft)
	_check("and_the_same_press_naming_seat_2_puts_them_in_seat_2", seats.size() > 2 and seats[2] == JOINER,
		"seats %s, '%s'" % [seats, _last_why(world)])
	world.teardown()
	_sections += 1


## seat_pose PAST THE TABLE is not valid and carries no pose; a seat the craft has is valid and carries its own.
func _a_seat_pose_past_the_table_is_not_the_pilots() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	var kind: int = _seater(world, 4)
	var past: Dictionary = world.seat_pose(kind, MISSING_SEAT)
	_check("seat_%d_of_a_four_seater_is_not_valid" % MISSING_SEAT,
		not bool(past.get("valid", true)) and not past.has("position"), "%s" % past)
	var single: int = _seater(world, 1)
	var second: Dictionary = world.seat_pose(single, 1)
	_check("nor_is_a_one_seaters_second_seat", single >= 0 and not bool(second.get("valid", true)),
		"kind %d: %s" % [single, second])
	var pilot: Dictionary = world.seat_pose(kind, 0)
	var last: Dictionary = world.seat_pose(kind, 3)
	_check("and_seats_0_and_3_are_valid_and_apart",
		bool(pilot.get("valid", false)) and bool(last.get("valid", false))
			and (pilot.get("position", Vector3.ZERO) as Vector3) != (last.get("position", Vector3.ZERO) as Vector3),
		"%s / %s" % [pilot, last])
	_sections += 1


## ---- 4: a fit ---------------------------------------------------------------------------------

## ALL OR NOTHING, because a seat's number is its place in the list: one bad seat in twelve refuses the twelve and the
## kind keeps its own. Seat 0 must be a pilot's. Nothing is fitted while a world runs. A good fit is the control.
func _a_fit_is_all_or_nothing() -> void:
	var own: int = (Sim.geometry_of(LONG).get("seat_poses", []) as Array).size()
	var bad: Array = _cabin(LONG_SEATS, LONG_COPILOT)
	(bad[6] as Dictionary)["station"] = "passenger lounge"
	var answer: Dictionary = Sim.fit_seats(LONG, bad)
	var after: int = (Sim.geometry_of(LONG).get("seat_poses", []) as Array).size()
	_check("one_malformed_seat_refuses_the_whole_fit", int(answer.get("fitted", -1)) == 0
		and String(answer.get("why", "")).contains("seat 6") and after == own,
		"%s; %d seats, its own %d" % [answer, after, own])
	var not_a_pilot: Array = _cabin(LONG_SEATS, LONG_COPILOT)
	(not_a_pilot[0] as Dictionary)["station"] = "operator"
	answer = Sim.fit_seats(LONG, not_a_pilot)
	_check("and_so_does_a_seat_0_that_is_not_a_pilots", int(answer.get("fitted", -1)) == 0, "%s" % answer)
	var running: Object = ClassDB.instantiate("CockpitWorld")
	running.start(0)
	answer = Sim.fit_seats(LONG, _cabin(LONG_SEATS, LONG_COPILOT))
	running.teardown()
	_check("nothing_is_fitted_while_a_world_runs", int(answer.get("fitted", -1)) == 0
		and (Sim.geometry_of(LONG).get("seat_poses", []) as Array).size() == own, "%s" % answer)
	answer = Sim.fit_seats(LONG, _cabin(LONG_SEATS, LONG_COPILOT))
	var fitted: int = (Sim.geometry_of(LONG).get("seat_poses", []) as Array).size()
	Sim.fit_seats(LONG, [])
	_check("and_a_good_one_fits_and_comes_off_again", int(answer.get("fitted", 0)) == LONG_SEATS
		and fitted == LONG_SEATS and (Sim.geometry_of(LONG).get("seat_poses", []) as Array).size() == own,
		"%s, %d fitted, %d after" % [answer, fitted, (Sim.geometry_of(LONG).get("seat_poses", []) as Array).size()])
	_sections += 1


## ---- 5: the page ------------------------------------------------------------------------------

## A LONG CABIN ON THE CREW PAGE: twelve seats, two aboard. The free operators are ONE cell and one JOIN, which asks for
## the first free operator's seat; the free copilot's seat 7 is a cell of its own; everybody aboard is a cell. Sixty-four
## seats with five aboard wrap onto a second line. Pressing the copilot's JOIN says seat 7.
func _the_crew_page_folds_a_long_cabin() -> void:
	var pilots: Array = [{"client": 31, "vehicle": 100, "seat": 0}, {"client": 32, "vehicle": 100, "seat": 9},
		{"client": 41, "vehicle": 200, "seat": 0}, {"client": 142, "vehicle": 200, "seat": 10},
		{"client": 143, "vehicle": 200, "seat": 20}, {"client": 144, "vehicle": 200, "seat": 40},
		{"client": 145, "vehicle": 200, "seat": 63}]
	var current: Dictionary = {100: {"kind": LONG, "position": Vector3.ZERO},
		200: {"kind": VERY_LONG, "position": Vector3(100.0, 0.0, 0.0)}}
	var manifest: Array = CrewManifest.read(pilots, current, 99)
	var long_row: Dictionary = {}
	var very_long_row: Dictionary = {}
	for craft in manifest:
		if int((craft as Dictionary)["kind"]) == LONG:
			long_row = craft
		elif int((craft as Dictionary)["kind"]) == VERY_LONG:
			very_long_row = craft
	_check("the_manifest_lists_every_seat_of_a_long_cabin",
		(long_row.get("seats", []) as Array).size() == LONG_SEATS
			and (very_long_row.get("seats", []) as Array).size() == VERY_LONG_SEATS
			and int(long_row.get("free", 0)) == LONG_SEATS - 2,
		"%d and %d seats, %d free" % [(long_row.get("seats", []) as Array).size(),
			(very_long_row.get("seats", []) as Array).size(), int(long_row.get("free", 0))])
	var cells: Array = CrewManifest.cells(long_row)
	var words: PackedStringArray = []
	for cell in cells:
		words.append("%d:%s×%d" % [int(cell["seat"]), cell["station"], int(cell["free"])])
	_check("its_free_seats_fold_a_station_to_a_cell", words == PackedStringArray(
		["0:pilot×0", "1:operator×9", "7:copilot×1", "9:operator×0"]), "%s" % [words])
	# ON THE CLIPBOARD'S OWN GLASS, at its own size, as `tests/crew_shot.gd` draws it: a page made at any other size
	# measures nothing about the board a player holds.
	var board := TouchPanel.new()
	board.page = preload("res://ui/menus/clipboard_page.tscn")
	board.size = Clipboard.SIZE
	board.pixels = Clipboard.PIXELS
	add_child(board)
	await get_tree().process_frame
	var page := board.shown() as ClipboardPage
	page.show_tab(ClipboardPage.Tab.CREW)
	page.show_crew(manifest, {})
	for i in range(4):
		await get_tree().process_frame
	var pressed: Array = []
	page.chose_join.connect(func(client: int, seat: int): pressed.append([client, seat]))
	var copilot := page.find_child("Join31_%d" % LONG_COPILOT, true, false) as Button
	var operators := page.find_child("Join31_1", true, false) as Button
	var joins: int = page.find_child("Craft31", true, false).find_children("Join*", "Button", true, false).size()
	if copilot != null:
		copilot.pressed.emit()
	_check("the_page_has_one_join_for_the_operators_and_one_for_the_copilot_seat",
		copilot != null and operators != null and joins == 2 and pressed == [[31, LONG_COPILOT]],
		"copilot %s, operators %s, %d joins, pressed %s" % [copilot, operators, joins, pressed])
	var very_long := page.find_child("Craft41", true, false)
	_check("and_a_cabin_of_more_cells_than_a_line_wraps",
		very_long != null and very_long.find_child("Line1", true, false) != null
			and page.find_child("Join41_1", true, false) != null,
		"%s, second line %s" % [very_long, very_long.find_child("Line1", true, false) if very_long != null else null])
	board.queue_free()
	_sections += 1


## ---- 6 and 7: joiners far down the cabin ------------------------------------------------------

func _joiners_sit_far_down_the_cabin_and_everybody_sees_who() -> void:
	var hulls: Dictionary = _stand_up()
	if hulls.is_empty():
		return
	var long_hull: int = int(hulls[LONG])
	var very_long_hull: int = int(hulls[VERY_LONG])
	_measure_from()
	_advance(120)
	var quiet: Dictionary = _measured(120)

	# THE FIRST JOINER THROUGH ITS OWN CREW PAGE: the manifest its world holds, the page, the copilot's JOIN.
	var first: RefCounted = _clients[JOINERS[0]]
	var page := ClipboardPage.new()
	add_child(page)
	page.show_crew(_manifest_of(first), {})
	page.show_tab(ClipboardPage.Tab.CREW)
	var asked: Array = []
	page.chose_join.connect(func(client: int, seat: int): asked.append([client, seat]))
	var button := page.find_child("Join%d_%d" % [LONG_PILOT_CLIENT, LONG_COPILOT], true, false) as Button
	if button != null:
		button.pressed.emit()
	page.queue_free()
	_check("the_first_joiners_page_offers_seat_7_and_asks_for_it", asked == [[LONG_PILOT_CLIENT, LONG_COPILOT]],
		"button %s, asked %s" % [button, asked])
	if not asked.is_empty():
		_press_join(JOINERS[0], int(asked[0][0]), int(asked[0][1]))
	# THE OTHERS, with the frame the page makes for a seat it has folded away.
	for i in range(1, JOINERS.size()):
		var wanted: Array = WANTED[i]
		_press_join(JOINERS[i], LONG_PILOT_CLIENT if int(wanted[0]) == LONG else VERY_LONG_PILOT_CLIENT, int(wanted[1]))
	_advance(40)
	for i in range(JOINERS.size()):
		_frames[JOINERS[i]].erase("join_wanted")
	_advance(40)

	# WHO IS ABOARD, on every machine.
	var want_long: Dictionary = {0: LONG_PILOT_CLIENT}
	var want_very_long: Dictionary = {0: VERY_LONG_PILOT_CLIENT}
	for i in range(JOINERS.size()):
		var me: int = int((_clients[JOINERS[i]] as RefCounted).local_client_id())
		(want_long if int(WANTED[i][0]) == LONG else want_very_long)[int(WANTED[i][1])] = me
	_check("the_server_seats_every_joiner_where_they_asked",
		_seated(_server.vehicle_seats(long_hull), LONG_SEATS, want_long)
			and _seated(_server.vehicle_seats(very_long_hull), VERY_LONG_SEATS, want_very_long),
		"%s / %s" % [_listed(_server.vehicle_seats(long_hull)), _listed(_server.vehicle_seats(very_long_hull))])
	var said: PackedStringArray = []
	var all_joined: bool = true
	for i in range(JOINERS.size()):
		var answer: Dictionary = (_clients[JOINERS[i]] as RefCounted).join_answer()
		all_joined = all_joined and String(answer.get("why", "")) == "joined" and int(answer.get("seat", -1)) == int(WANTED[i][1])
		said.append("%s %d" % [answer.get("why", "-"), int(answer.get("seat", -1))])
	_check("and_each_is_told_joined_in_the_seat_it_asked_for", all_joined, "%s" % [said])
	for peer in JOINERS + [SPECTATOR]:
		var world: RefCounted = _clients[peer]
		var long_here: int = _local_hull(world, LONG)
		var very_long_here: int = _local_hull(world, VERY_LONG)
		_check("peer_%d_sees_who_is_in_every_seat" % peer,
			_seated(world.vehicle_seats(long_here), LONG_SEATS, want_long)
				and _seated(world.vehicle_seats(very_long_here), VERY_LONG_SEATS, want_very_long),
			"%s / %s" % [_listed(world.vehicle_seats(long_here)), _listed(world.vehicle_seats(very_long_here))])
	var spectator: RefCounted = _clients[SPECTATOR]
	var records: PackedStringArray = []
	var records_right: bool = true
	for state in spectator.pilot_states():
		var row := state as Dictionary
		for i in range(JOINERS.size()):
			if int(row.get("client", -1)) == int((_clients[JOINERS[i]] as RefCounted).local_client_id()):
				records_right = records_right and int(row.get("pilot_seat", -1)) == int(WANTED[i][1]) \
					and int(row.get("seat", -1)) == int(WANTED[i][1])
				records.append("%d:%d/%d" % [int(row["client"]), int(row.get("seat", -1)), int(row.get("pilot_seat", -1))])
	_check("the_spectator_reads_each_pilots_own_record_with_its_wide_seat", records_right and records.size() == JOINERS.size(),
		"%s" % [records])
	var spectator_manifest: Array = _manifest_of(spectator)
	var shown: Dictionary = {}
	for craft in spectator_manifest:
		for seat in (craft as Dictionary)["seats"]:
			if int(seat["client"]) >= 0:
				shown[int(seat["client"])] = int(seat["seat"])
	var shown_right: bool = true
	for i in range(JOINERS.size()):
		shown_right = shown_right and int(shown.get(int((_clients[JOINERS[i]] as RefCounted).local_client_id()), -1)) \
			== int(WANTED[i][1])
	_check("and_the_page_the_spectator_would_draw_lists_them_there", shown_right, "%s" % shown)
	_sections += 1

	# HANDS. Nobody is moving anything yet, in a craft whose seat 7 flies it: nobody must not read as 7.
	var operator_world: RefCounted = _clients[JOINERS[1]]
	var copilot_world: RefCounted = _clients[JOINERS[0]]
	var still: Dictionary = operator_world.crew_controls(_local_hull(operator_world, LONG))
	_check("nobody_flying_reads_minus_1_in_a_craft_whose_seat_7_flies", int(still.get("hands_on", 99)) == -1
		and (still.get("seats", []) as Array).size() == LONG_SEATS, "hands_on %s, %d seats" % [still.get("hands_on"),
			(still.get("seats", []) as Array).size()])
	_frames[JOINERS[0]].merge({"throttle": 0.7, "roll": 0.6, "pitch": -0.4}, true)
	_frames[JOINERS[1]].merge({"throttle": 0.3}, true)
	_frames[JOINERS[4]].merge({"throttle": 0.9, "roll": -0.5}, true)
	_measure_from()
	_advance(60)
	var busy: Dictionary = _measured(60)
	var seen: Dictionary = operator_world.crew_controls(_local_hull(operator_world, LONG))
	var seen_seats: Array = seen.get("seats", [])
	var copilot_hands: Dictionary = seen_seats[LONG_COPILOT] if seen_seats.size() > LONG_COPILOT else {}
	_check("the_copilot_in_seat_7_is_the_hands_on_the_controls", int(seen.get("hands_on", -1)) == LONG_COPILOT
		and absf(float(copilot_hands.get("throttle", 0.0)) - 0.7) < 0.03
		and (copilot_hands.get("stick", Vector2.ZERO) as Vector2).distance_to(Vector2(0.6, -0.4)) < 0.03
		and absf((seen.get("linked_stick", Vector2.ZERO) as Vector2).x - 0.6) < 0.03,
		"hands_on %s, seat 7 %s, linked %s" % [seen.get("hands_on"), copilot_hands, seen.get("linked_stick")])
	var theirs: Dictionary = copilot_world.crew_controls(_local_hull(copilot_world, LONG))
	var theirs_seats: Array = theirs.get("seats", [])
	_check("and_the_operator_in_seat_9_has_their_throttle_seen_by_the_copilot",
		theirs_seats.size() > 9 and absf(float((theirs_seats[9] as Dictionary).get("throttle", 0.0)) - 0.3) < 0.03
			and int(theirs.get("hands_on", -1)) == LONG_COPILOT,
		"seat 9 %s, hands_on %s" % [theirs_seats[9] if theirs_seats.size() > 9 else "-", theirs.get("hands_on")])
	var back_seat: RefCounted = _clients[JOINERS[3]]
	var far: Dictionary = back_seat.crew_controls(_local_hull(back_seat, VERY_LONG))
	var far_seats: Array = far.get("seats", [])
	_check("a_hand_in_seat_63_reaches_seat_40",
		far_seats.size() == VERY_LONG_SEATS
			and absf(float((far_seats[63] as Dictionary).get("throttle", 0.0)) - 0.9) < 0.03,
		"%d seats, seat 63 %s" % [far_seats.size(), far_seats[63] if far_seats.size() > 63 else "-"])
	_check("and_the_spectator_holds_nobodys_hands", spectator.crew_controls(_local_hull(spectator, LONG)).is_empty()
		and spectator.crew_controls(_local_hull(spectator, VERY_LONG)).is_empty(), "the crew's alone")

	# AS MANY PEOPLE AS ONE CRAFT HOLDS, and one more: players with no machine, as the pilots are.
	var most: int = int(Sim.seat_limits().get("most_aboard", 0))
	var aboard: int = _aboard(_server.vehicle_seats(very_long_hull))
	var extra: int = 0
	var refused_at: int = -1
	var next_client: int = 100
	while aboard + extra < most + 1 and next_client < 100 + most + 8:
		var made: Dictionary = _server.spawn_pilot(next_client, POD, Vector3(-200.0 - float(next_client), 4.0, 90.0), 0.0,
			Vector3.ZERO)
		# A FREE SEAT, asked of the craft: a seat somebody is already in is refused for that reason, not this one.
		var seat: int = (_server.vehicle_seats(very_long_hull) as PackedInt64Array).find(-1)
		if not made.is_empty() and seat >= 0:
			if bool(_server.seat_client(next_client, very_long_hull, seat)):
				extra += 1
			else:
				refused_at = aboard + extra
				break
		next_client += 1
	_advance(30)
	_check("a_craft_holds_%d_people_and_the_next_is_refused" % most,
		refused_at == most and _aboard(_server.vehicle_seats(very_long_hull)) == most
			and _aboard(spectator.vehicle_seats(_local_hull(spectator, VERY_LONG))) == most,
		"refused at %d; %d aboard on the server, %d on the spectator" % [refused_at,
			_aboard(_server.vehicle_seats(very_long_hull)),
			_aboard(spectator.vehicle_seats(_local_hull(spectator, VERY_LONG)))])

	# WHAT IT COSTS.
	print("[many_seats] down a tick to a joiner: %.1f B quiet, %.1f B with three crew moving; to the spectator %.1f / %.1f;"
		% [quiet["joiner"], busy["joiner"], quiet["spectator"], busy["spectator"]]
		+ " up from a joiner %.1f / %.1f; server tick %.3f / %.3f ms"
		% [quiet["up"], busy["up"], quiet["server_ms"], busy["server_ms"]])
	_sections += 1


static func _aboard(seats: PackedInt64Array) -> int:
	var count: int = 0
	for who in seats:
		count += 1 if who >= 0 else 0
	return count


## EXACTLY these clients in these seats, nobody else, and as many entries as the craft has seats.
static func _seated(seats: PackedInt64Array, count: int, want: Dictionary) -> bool:
	if seats.size() != count:
		return false
	for seat in range(seats.size()):
		if int(seats[seat]) != int(want.get(seat, -1)):
			return false
	return true


static func _listed(seats: PackedInt64Array) -> String:
	var out: PackedStringArray = []
	for seat in range(seats.size()):
		if seats[seat] >= 0:
			out.append("%d:%d" % [seat, seats[seat]])
	return "%d seats {%s}" % [seats.size(), ", ".join(out)]


## THE MANIFEST THIS MACHINE'S CREW PAGE WOULD DRAW, from its own world, as `Clipboard` builds it.
static func _manifest_of(world: RefCounted) -> Array:
	var current: Dictionary = {}
	for row in world.vehicle_states():
		current[int(row["entity"])] = {"kind": int(row["kind"]), "position": row["position"]}
	var stations_of := func(kind: int) -> PackedStringArray:
		var out := PackedStringArray()
		for seat in world.kind_geometry(kind).get("seat_poses", []):
			out.append(String((seat as Dictionary).get("station", "seat")))
		return out
	return CrewManifest.read(world.pilot_states(), current, int(world.local_client_id()), stations_of,
		func(vehicle: int) -> PackedInt64Array: return world.vehicle_seats(vehicle))


func _press_join(peer: int, with_client: int, seat: int) -> void:
	var frame: Dictionary = _frames[peer]
	frame["menu_request"] = (int(frame.get("menu_request", 0)) + 1) % Sim.MENU_REQUESTS
	frame["join_wanted"] = with_client
	frame["join_seat"] = seat


## THE CRAFT OF THIS KIND AS THIS MACHINE KNOWS IT: its own entity id, found by kind, since there is one of each.
static func _local_hull(world: RefCounted, kind: int) -> int:
	for row in world.vehicle_states():
		if int(row.get("kind", -1)) == kind:
			return int(row.get("entity", 0))
	return 0


## A SERVER, FIVE JOINERS AND A SPECTATOR, EACH IN A POD, AND THE TWO LONG CABINS WITH THEIR PILOTS. {kind: hull}, or {}.
func _stand_up() -> Dictionary:
	_server = ClassDB.instantiate("CockpitWorld")
	_server.set_tick_rate(TICK_HZ)
	_server.start(0)
	_clients.clear()
	_frames.clear()
	for peer in JOINERS + [SPECTATOR]:
		var world: RefCounted = ClassDB.instantiate("CockpitWorld")
		world.set_tick_rate(TICK_HZ)
		world.start(peer)
		_clients[peer] = world
		_frames[peer] = {}
	for world in [_server] + _clients.values():
		world.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(600.0, 2.0, 600.0))
	_tick = 0
	_in_flight.clear()
	_advance(90)
	var ids: PackedStringArray = []
	for peer in _clients:
		var me: int = int((_clients[peer] as RefCounted).local_client_id())
		ids.append(str(me))
		if me <= 0:
			_check("every_client_handshook", false, "client ids %s" % [ids])
			_teardown()
			return {}
	var long_made: Dictionary = _server.spawn_pilot(LONG_PILOT_CLIENT, LONG, Vector3(0.0, 3000.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -80.0))
	var very_long_made: Dictionary = _server.spawn_pilot(VERY_LONG_PILOT_CLIENT, VERY_LONG, Vector3(300.0, 3000.0, 0.0),
		0.0, Vector3.ZERO)
	var spot: int = 0
	for peer in _clients:
		spot += 1
		_server.spawn_pilot(int((_clients[peer] as RefCounted).local_client_id()), POD,
			Vector3(-60.0 * float(spot), 4.0, 60.0), 0.0, Vector3.ZERO)
	_advance(60)
	var hulls: Dictionary = {LONG: int(long_made.get("vehicle", 0)), VERY_LONG: int(very_long_made.get("vehicle", 0))}
	var everyone_sees: bool = true
	for peer in _clients:
		everyone_sees = everyone_sees and _local_hull(_clients[peer], LONG) != 0 and _local_hull(_clients[peer], VERY_LONG) != 0
	if int(hulls[LONG]) == 0 or int(hulls[VERY_LONG]) == 0 or not everyone_sees:
		_check("both_long_cabins_are_made_and_seen", false, "%s, every client sees them %s" % [hulls, everyone_sees])
		_teardown()
		return {}
	return hulls


func _controls(peer: int) -> Dictionary:
	var out: Dictionary = {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0,
		"join_wanted": 255, "join_seat": Sim.ANY_SEAT, "menu_request": 0,
	}
	out.merge(_frames.get(peer, {}), true)
	return out


func _advance(ticks: int) -> void:
	for i in range(ticks):
		for peer in _clients:
			(_clients[peer] as RefCounted).set_input(_controls(peer))
		_tick += 1
		var began: int = Time.get_ticks_usec()
		_server.tick(DT)
		_server_usec += Time.get_ticks_usec() - began
		for peer in _clients:
			(_clients[peer] as RefCounted).tick(DT)
		_pump()


func _measure_from() -> void:
	_bytes_down = {}
	_server_usec = 0


func _measured(ticks: int) -> Dictionary:
	return {"joiner": float(_bytes_down.get(JOINERS[0], 0)) / ticks,
		"spectator": float(_bytes_down.get(SPECTATOR, 0)) / ticks,
		"up": float(_bytes_down.get(0, 0)) / ticks, "server_ms": float(_server_usec) / 1000.0 / ticks}


## A ONE-TICK LINK, as `many_devices`': everything sent this tick is delivered before the next.
func _pump() -> void:
	for packet in _server.take_outbound():
		var peer: int = int(packet["peer"])
		_bytes_down[peer] = int(_bytes_down.get(peer, 0)) + (packet["bytes"] as PackedByteArray).size()
		_in_flight.append([_tick, peer, 0, packet["bytes"], packet["bits"]])
	for from_peer in _clients:
		for packet in (_clients[from_peer] as RefCounted).take_outbound():
			if int(from_peer) == JOINERS[0]:
				_bytes_down[0] = int(_bytes_down.get(0, 0)) + (packet["bytes"] as PackedByteArray).size()
			_in_flight.append([_tick, 0, int(from_peer), packet["bytes"], packet["bits"]])
	var still_flying: Array = []
	for entry in _in_flight:
		if int(entry[0]) > _tick:
			still_flying.append(entry)
			continue
		if int(entry[1]) == 0:
			_server.deliver(int(entry[2]), entry[3], entry[4])
		elif _clients.has(int(entry[1])):
			(_clients[int(entry[1])] as RefCounted).deliver(0, entry[3], entry[4])
	_in_flight = still_flying


func _teardown() -> void:
	for peer in _clients:
		(_clients[peer] as RefCounted).teardown()
	_clients.clear()
	if _server != null:
		_server.teardown()
	_server = null
	_in_flight.clear()
