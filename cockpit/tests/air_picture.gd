extends Node
## Headless: THE PLOT CANNOT LIE ABOUT WHO IS A PERSON.
##
##   Godot --headless --path cockpit res://tests/air_picture.tscn
##
## WHAT THIS EXISTS TO CATCH. An operator sitting at a plot is being told, at a glance, which machines
## in the air have a human in them. Everything they then say on the radio rests on that, so a picture
## that colours one aeroplane wrong is worse than a picture with nothing on it: it is confidently wrong
## and nothing on the screen says so. `world/air_picture.gd` derives the answer rather than storing it,
## and this suite is the proof that the derivation is the SESSION'S answer and not the plot's own.
##
## ANCHORED OUTSIDE THE THING IT CHECKS (`testing_godot_headless.md`). The truth here is
## `CockpitWorld.vehicle_seats`, the craft's own replicated `Seats` component, which the server alone
## writes -- NOT the manifest the picture was handed, and not `AirPicture`'s own opinion. A check that
## asked the picture whether the picture was right would agree with any mistake in it. So every contact
## on the plot is looked up in the simulation's seats, and the two partitions -- people and machines --
## have to be the same set, both ways round, with nothing left over on either side.
##
## AND IT DRIVES THE REAL PATH. The boarding in section 3 is a client's own input frame played into a
## server world through `set_pilot_input`, the frame the wire carries, exactly as `tests/nobody_aboard.gd`
## does -- not a call to whatever function seats a player. A player joining an aeroplane that was flying
## itself is the moment the plot has to change its mind about, and it is tested by making it happen.
##
## WHAT IT CANNOT SEE: whether the two are TOLD APART BY EYE. That a player is a solid arrow in their own
## colour and a machine is an open grey outline is a claim about pixels, and headless has no rendering
## device; `plot_shot` is where a person looks at it. What IS held here is the thing a drawing branches
## on -- `manned` on every row -- and that the grey stays a stated distance from every colour a player can
## wear, which is a check the first drawn picture is what asked for (see section 2).
##
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
const CLIENT: int = 1
const SECTIONS: int = 5

var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[air_picture] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	# A ROSTER WITH A NAME IN IT, so "no machine wears a player's name" has a name to fail on.
	var was: Dictionary = Net.roster
	Net.roster = {CLIENT: {"player": CLIENT, "name": "MAGIC", "colour": 2}}
	_the_picture_partitions_exactly_as_the_simulations_seats_do()
	_a_machine_can_never_be_mistaken_for_a_person()
	_boarding_and_leaving_move_a_craft_across_the_line()
	_nothing_that_is_not_traffic_is_on_the_plot()
	_the_plot_is_a_display_and_moves_nobody()
	Net.roster = was
	_finish()


func _finish() -> void:
	_check("every_section_ran_to_its_end", _sections == SECTIONS, "%d of %d" % [_sections, SECTIONS])
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


## ---- the world ---------------------------------------------------------------------------------

## A server world with a pod for the client, four aeroplanes and a launch flying and sailing themselves,
## and a tower standing still. Ticked far enough that every one of them is in `vehicle_states`.
func _world() -> Dictionary:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	var traffic: Array[int] = []
	for i in range(4):
		traffic.append(int(world.spawn_ai_vehicle(Sim.Kind.PLANE,
			Vector3(600.0 * float(i + 1), 400.0, -1200.0), 0.0, Vector3(0.0, 0.0, -60.0))))
	traffic.append(int(world.spawn_ai_vehicle(Sim.Kind.BOAT, Vector3(-2000.0, 0.0, 800.0), 0.0, Vector3.ZERO)))
	var tower: int = int(world.spawn_vehicle(Sim.Kind.TOWER, Vector3(0.0, 0.0, 2000.0), 0.0, Vector3.ZERO))
	var made: Dictionary = world.spawn_pilot(CLIENT, Sim.Kind.POD, Vector3(0.0, 300.0, 0.0), 0.0, Vector3.ZERO)
	for i in range(20):
		world.tick(TICK)
	return {"world": world, "traffic": traffic, "tower": tower,
		"pilot": int(made.get("pilot", 0)), "pod": int(made.get("vehicle", 0))}


## Every vehicle the world has, entity -> state, as `Sim.current` holds them.
static func _states(world: Object) -> Dictionary:
	var out: Dictionary = {}
	for state in world.vehicle_states():
		out[int((state as Dictionary)["entity"])] = state
	return out


## THE PICTURE THROUGH THE SHIPPED PATH: the same two calls `world/sky.gd` makes every fifth of a second,
## with the craft's own seats standing in for `Sim.client.vehicle_seats`.
static func _picture(world: Object) -> Array[Dictionary]:
	var states: Dictionary = _states(world)
	var seats_of := func(vehicle: int) -> PackedInt64Array: return world.vehicle_seats(vehicle)
	var manifest: Array = CrewManifest.read(world.pilot_states(), states, CLIENT, Callable(), seats_of)
	return AirPicture.contacts(manifest, states)


## THE ANSWER THIS SUITE TRUSTS, and it is not the picture's: who the SIMULATION says is aboard each
## craft. A client id in the craft's own `Seats` is a person in it and nothing else is.
static func _manned_by_the_simulation(world: Object) -> Dictionary:
	var out: Dictionary = {}
	for entity in _states(world):
		var occupants: PackedInt64Array = world.vehicle_seats(int(entity))
		var manned: bool = false
		for who in occupants:
			manned = manned or int(who) >= 0
		out[int(entity)] = manned
	return out


## ---- 1: the partition --------------------------------------------------------------------------

func _the_picture_partitions_exactly_as_the_simulations_seats_do() -> void:
	var built: Dictionary = _world()
	var world: Object = built["world"]
	var rows: Array[Dictionary] = _picture(world)
	var truth: Dictionary = _manned_by_the_simulation(world)

	var lied: PackedStringArray = []
	var people: int = 0
	for row in rows:
		var entity: int = int(row["vehicle"])
		var drawn: bool = bool(row["manned"])
		people += 1 if drawn else 0
		if drawn != bool(truth.get(entity, false)):
			lied.append("%d drawn %s, seats say %s" % [entity, drawn, truth.get(entity, false)])
	_check("every_contact_is_a_player_exactly_when_the_simulations_seats_say_so", lied.is_empty(),
		"%d contacts, %d of them people%s" % [rows.size(), people, "" if lied.is_empty() else ": %s" % lied])
	# AND NOTHING WAS LEFT OFF. A picture that simply dropped every craft it was unsure about would pass
	# the check above with an empty plot.
	var on_the_plot: Dictionary = {}
	for row in rows:
		on_the_plot[int(row["vehicle"])] = true
	var missed: PackedStringArray = []
	for entity in truth:
		var kind: int = int((_states(world)[entity] as Dictionary).get("kind", -1))
		if kind in AirPicture.NOT_TRAFFIC:
			continue
		if not on_the_plot.has(int(entity)):
			missed.append("%d (%s)" % [entity, Sim.kind_name(kind)])
	_check("and_every_craft_in_the_world_that_is_traffic_is_on_the_plot", missed.is_empty(),
		"%d craft, %d contacts%s" % [truth.size(), rows.size(), "" if missed.is_empty() else ": %s" % missed])
	# AND THE PLAYER IS THE PLAYER. One pod with the client in it, and it is the row marked `yours`.
	var mine: PackedStringArray = []
	for row in rows:
		if bool(row.get("yours", false)):
			mine.append("%d" % int(row["vehicle"]))
	_check("and_the_one_craft_the_client_is_in_is_the_one_marked_yours",
		mine.size() == 1 and int(mine[0]) == int(built["pod"]),
		"%s against pod %d" % [mine, int(built["pod"])])
	_check("and_the_tally_counts_what_the_rows_say",
		int(AirPicture.tally(rows)["players"]) == people
			and int(AirPicture.tally(rows)["ai"]) == rows.size() - people,
		"%s of %d rows" % [AirPicture.tally(rows), rows.size()])
	_sections += 1


## ---- 2: a machine is never a person --------------------------------------------------------------

func _a_machine_can_never_be_mistaken_for_a_person() -> void:
	# THE GREY IS NOT ONE OF THE EIGHT, AND IS NOT NEXT DOOR TO ONE EITHER. "Not equal" was the first
	# draft of this check and it is not enough: the palette's eighth colour is `b0bec5`, a pale blue-grey,
	# and a machine drawn a few units from it is a machine nobody can tell from a player wearing it. That
	# was found by LOOKING at the first picture the probe drew, which is what a picture is for.
	var apart: float = AirPicture.nearest_player_colour()
	_check("the_colour_every_machine_is_drawn_in_is_a_stated_distance_from_every_colour_a_player_wears",
		apart >= AirPicture.AI_APART,
		"%s is %.3f from the nearest of %d palette colours, floor %.2f" % [AirPicture.AI.to_html(false),
			apart, PlayerColours.PALETTE.size(), AirPicture.AI_APART])

	var built: Dictionary = _world()
	var world: Object = built["world"]
	var rows: Array[Dictionary] = _picture(world)
	var names: Dictionary = {}
	for card in Net.roster_cards():
		names[String((card as Dictionary)["name"]).to_upper()] = true
	var wrong_colour: PackedStringArray = []
	var wrong_name: PackedStringArray = []
	var keys: Dictionary = {}
	var clashes: PackedStringArray = []
	for row in rows:
		var key: int = MapCanvas.key_of(row)
		if keys.has(key):
			clashes.append("%d twice" % key)
		keys[key] = true
		if bool(row["manned"]):
			continue
		if not (row["colour"] as Color).is_equal_approx(AirPicture.AI):
			wrong_colour.append("%d is %s" % [int(row["vehicle"]), (row["colour"] as Color).to_html(false)])
		if names.has(String(row["name"]).to_upper()):
			wrong_name.append("%d is called %s" % [int(row["vehicle"]), row["name"]])
	_check("and_no_machine_on_the_plot_wears_a_players_colour", wrong_colour.is_empty(),
		"%s" % ["none of %d" % rows.size() if wrong_colour.is_empty() else wrong_colour])
	_check("and_no_machine_on_the_plot_wears_a_players_name", wrong_name.is_empty(),
		"%d names in the roster%s" % [names.size(), "" if wrong_name.is_empty() else ": %s" % wrong_name])
	# AND NOT `Net.name_of` EITHER, which is the trap the roster check above does not catch: `name_of`
	# answers "PLAYER 7" for anybody it has never heard of, so a machine handed its client id of -1 comes
	# back called "PLAYER -1" -- a name no roster holds and every reader would take for a person.
	var fallbacks: PackedStringArray = []
	for row in rows:
		if bool(row["manned"]):
			continue
		if String(row["name"]).to_upper().begins_with("PLAYER"):
			fallbacks.append("%d is called %s" % [int(row["vehicle"]), row["name"]])
	_check("and_no_machine_is_labelled_with_net_name_ofs_answer_for_a_stranger", fallbacks.is_empty(),
		"%s would be %s" % [AirPicture.AI.to_html(false) if fallbacks.is_empty() else "",
			Net.name_of(-1)] if fallbacks.is_empty() else "%s" % fallbacks)
	# AND IT IS CALLED WHAT THE RADIO CALLS IT. The operator reads a name off the plot and says it out loud;
	# the aeroplane answers to whatever `RadioPhrases` gives it. Held against that function rather than
	# against a string typed here, because a check that spells the call sign out again would agree with any
	# change to the one the aircraft actually uses.
	var mismatched: PackedStringArray = []
	for row in rows:
		if bool(row["manned"]):
			continue
		var theirs: String = RadioPhrases.callsign(int(row["kind"]), int(row["vehicle"])).to_upper()
		if String(row["name"]) != theirs:
			mismatched.append("plot says %s, the radio says %s" % [row["name"], theirs])
	_check("and_every_machine_is_called_what_the_radio_calls_it", mismatched.is_empty(),
		"%s" % ["e.g. %s" % _first_machine_name(rows) if mismatched.is_empty() else mismatched])
	# AND THE SAME AEROPLANE KEEPS ITS NAME. A call sign that moved under an operator between one glance and
	# the next would be worse than none at all.
	var second: Array[Dictionary] = _picture(world)
	var was: Dictionary = {}
	for row in rows:
		was[int(row["vehicle"])] = String(row["name"])
	var drifted: PackedStringArray = []
	for row in second:
		if was.has(int(row["vehicle"])) and String(row["name"]) != String(was[int(row["vehicle"])]):
			drifted.append("%d was %s, is %s" % [int(row["vehicle"]), was[int(row["vehicle"])], row["name"]])
	_check("and_a_contact_is_still_called_the_same_thing_on_the_next_look", drifted.is_empty(),
		"%d contacts%s" % [second.size(), "" if drifted.is_empty() else ": %s" % drifted])
	# AND EVERY CONTACT HAS ITS OWN KEY. Every machine has client -1, so a plot keyed by the client id
	# draws a hundred and forty aeroplanes at one point and an operator sees one contact where there are
	# a hundred and forty.
	_check("and_every_contact_has_a_key_of_its_own", clashes.is_empty(),
		"%d keys for %d contacts%s" % [keys.size(), rows.size(), "" if clashes.is_empty() else ": %s" % clashes])
	_sections += 1


## ---- 3: joining and leaving -----------------------------------------------------------------------

## THE MOMENT THE PLOT HAS TO CHANGE ITS MIND. A player walks into an aeroplane that was flying itself,
## through a real input frame, and the contact must go from a machine to a person with nothing stored and
## nothing told; then they leave it and it must go back.
func _boarding_and_leaving_move_a_craft_across_the_line() -> void:
	var built: Dictionary = _world()
	var world: Object = built["world"]
	var pilot: int = int(built["pilot"])

	var before: Dictionary = {}
	for row in _picture(world):
		before[int(row["vehicle"])] = bool(row["manned"])
	var aeroplanes: Array = built["traffic"]
	var machines: int = 0
	for entity in aeroplanes:
		machines += 1 if not bool(before.get(int(entity), true)) else 0
	_check("every_aeroplane_flying_itself_starts_as_a_machine_on_the_plot", machines == aeroplanes.size(),
		"%d of %d" % [machines, aeroplanes.size()])

	_press(world, pilot, Sim.BUTTON_KIND, Sim.Kind.PLANE)
	var boarded: int = -1
	var truth: Dictionary = _manned_by_the_simulation(world)
	for entity in aeroplanes:
		if bool(truth.get(int(entity), false)):
			boarded = int(entity)
	_check("a_real_input_frame_puts_the_player_into_one_of_them", boarded > 0,
		"seats say %s" % [boarded if boarded > 0 else truth])
	var after: Dictionary = {}
	for row in _picture(world):
		after[int(row["vehicle"])] = bool(row["manned"])
	_check("and_the_plot_calls_that_aeroplane_a_player_now", bool(after.get(boarded, false)),
		"%d was %s, is %s" % [boarded, before.get(boarded, "absent"), after.get(boarded, "absent")])
	var others: PackedStringArray = []
	for entity in aeroplanes:
		if int(entity) != boarded and bool(after.get(int(entity), true)):
			others.append(str(entity))
	_check("and_the_aeroplanes_beside_it_are_still_machines", others.is_empty(),
		"%s" % ["all %d" % (aeroplanes.size() - 1) if others.is_empty() else others])

	# AND OUT AGAIN, onto the next aeroplane, which leaves the one just left with nobody in it.
	_press(world, pilot, Sim.BUTTON_KIND, Sim.Kind.PLANE)
	var left: Dictionary = {}
	for row in _picture(world):
		left[int(row["vehicle"])] = bool(row["manned"])
	var truth_now: Dictionary = _manned_by_the_simulation(world)
	var disagreed: PackedStringArray = []
	for entity in left:
		if bool(left[entity]) != bool(truth_now.get(int(entity), false)):
			disagreed.append("%d drawn %s, seats say %s" % [entity, left[entity], truth_now.get(int(entity), false)])
	_check("and_after_stepping_out_the_plot_still_agrees_with_the_seats_craft_for_craft",
		disagreed.is_empty(), "%d contacts%s" % [left.size(), "" if disagreed.is_empty() else ": %s" % disagreed])
	_check("and_the_craft_the_player_stepped_out_of_is_a_machine_again",
		not bool(left.get(boarded, true)), "%d is %s" % [boarded, left.get(boarded, "absent")])
	_sections += 1


## The first machine's name, for a passing check to print something a reader can recognise.
static func _first_machine_name(rows: Array[Dictionary]) -> String:
	for row in rows:
		if not bool(row["manned"]):
			return String(row["name"])
	return "(no machines)"


## A PRESS as a player's hand makes one: held for a few ticks, then released, so the server's edge
## detection sees exactly one. Copied in shape from tests/nobody_aboard.gd, which is where the wire's
## own frame is documented.
func _press(world: Object, pilot: int, buttons: int, wanted: int) -> void:
	for i in range(3):
		world.set_pilot_input(pilot, {"buttons": buttons, "kind_wanted": wanted})
		world.tick(TICK)
	for i in range(12):
		world.set_pilot_input(pilot, {"buttons": 0, "kind_wanted": Sim.NO_KIND})
		world.tick(TICK)


## ---- 4: what is not traffic -------------------------------------------------------------------------

func _nothing_that_is_not_traffic_is_on_the_plot() -> void:
	var built: Dictionary = _world()
	var world: Object = built["world"]
	var rows: Array[Dictionary] = _picture(world)
	var standing: PackedStringArray = []
	for row in rows:
		if int(row["vehicle"]) == int(built["tower"]):
			standing.append("the tower is contact %d" % MapCanvas.key_of(row))
	_check("a_tower_is_a_building_and_is_not_a_contact", standing.is_empty(),
		"%d contacts%s" % [rows.size(), "" if standing.is_empty() else ": %s" % standing])
	# AND THE LAUNCH IS. A boat in the way of a landing matters to an operator as much as an aeroplane,
	# so "not traffic" has to be the short list it says it is and not "anything that is not an aeroplane".
	var afloat: bool = false
	for row in rows:
		afloat = afloat or int(row["kind"]) == Sim.Kind.BOAT
	_check("and_a_launch_under_way_is", afloat, "%d contacts" % rows.size())
	_sections += 1


## ---- 5: it is a display ------------------------------------------------------------------------------

## PRESSING A CONTACT DOES NOT MOVE IT. The plot reads and shows; the picking is a highlight on this one
## piece of glass and nothing else, and the proof is that the simulation is untouched by it.
func _the_plot_is_a_display_and_moves_nobody() -> void:
	var built: Dictionary = _world()
	var world: Object = built["world"]
	var rows: Array[Dictionary] = _picture(world)

	var map := LevelMap.new()
	add_child(map)
	var chart := LevelChart.new()
	chart.world = "island"
	map.configure(chart)
	var canvas := MapCanvas.new()
	canvas.size = Vector2(900, 900)
	add_child(canvas)
	canvas.show_map(map, rows)
	_check("every_contact_lands_somewhere_of_its_own_on_the_glass",
		canvas.marker_centres.size() == rows.size(),
		"%d places for %d contacts" % [canvas.marker_centres.size(), rows.size()])

	var machine: int = 0
	var at := Vector2.ZERO
	for row in rows:
		if not bool(row["manned"]) and machine == 0:
			machine = MapCanvas.key_of(row)
			at = canvas.marker_centres[machine] as Vector2
	var seats_before: Dictionary = _manned_by_the_simulation(world)
	var places_before: Dictionary = {}
	for entity in _states(world):
		places_before[int(entity)] = (_states(world)[entity] as Dictionary)["position"]

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = at
	canvas._gui_input(click)
	_check("pressing_a_machine_picks_it_out", canvas.selected_contact == machine,
		"picked %d, wanted %d" % [canvas.selected_contact, machine])
	var moved: PackedStringArray = []
	var seats_after: Dictionary = _manned_by_the_simulation(world)
	var states_after: Dictionary = _states(world)
	for entity in places_before:
		if not states_after.has(entity) \
				or (states_after[entity] as Dictionary)["position"] != places_before[entity]:
			moved.append("%d moved" % entity)
		if bool(seats_after.get(int(entity), false)) != bool(seats_before.get(int(entity), false)):
			moved.append("%d changed hands" % entity)
	_check("and_the_press_moves_nothing_and_seats_nobody", moved.is_empty(),
		"%d craft%s" % [places_before.size(), "" if moved.is_empty() else ": %s" % moved])
	_sections += 1
