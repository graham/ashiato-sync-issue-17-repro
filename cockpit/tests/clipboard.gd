extends Node
## Headless: is there a menu in the player's hand, and does pressing it reach the server?
##
##   Godot --headless --path cockpit res://tests/clipboard.tscn
##
## Two halves, and the second is the one worth having. A panel that draws is easy to see is
## working; what cannot be seen is whether a button press turns into ONE request on ONE
## input frame, and whether the server answers it by putting the player in the right seat.
## A request that fires every tick would move somebody continuously and look, from inside a
## headset, like a menu that does nothing.
##
## Read RESULT=, not the exit code.

var _failures: PackedStringArray = []
var _rig: PilotRig = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[clipboard] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	await _the_board_in_the_hand()
	await _the_thumb_walks_the_page()
	await _the_board_has_fingers_of_its_own()
	await _the_right_hand_points_at_the_board()
	await _the_board_puts_the_head_back()
	await _the_hud_switch_puts_the_hud_up_and_away()
	await _small_boats_keep_the_horizon_level()
	await _every_tab_is_whole_on_the_glass()
	await _the_right_hand_works_the_audio_tab()
	await _the_board_is_not_behind_the_controller()
	await _one_press_is_one_request()
	await _the_way_back_to_the_desk()
	await _the_board_fills_the_sky()
	await _nothing_runs_off_the_board()
	await _the_join_code_is_on_every_tab()
	await _the_crew_page_fits_full()
	await _an_off_switch_looks_like_a_switch()
	await _the_server_sits_you_with_them()
	await _the_help_page_says_what_every_finger_does()
	await _a_hand_that_takes_hold_puts_the_board_away()
	_finish()


## ---- the legend -----------------------------------------------------------------------

## EVERY BOUND INPUT IS ON THE HELP PAGE, and the page is generated from the tables the
## fingers are actually read through.
##
## A GENUINE DRIFT TEST AND NOT A TAUTOLOGY, because it compares two independently written
## representations of the same thing. On one side: `PilotRig.desk_keys` and
## `PilotRig._bindings_for`, which are what the game reads a key and a finger through. On
## the other: the strings on the page, read back out of the `Control` tree. A key bound and
## not described, or described and not bound, fails.
##
## The bug it exists for is one that had already happened and that nobody could have seen:
## the only legend in this game was a `print` in `_enter_desktop` saying "F1-F10 a type"
## while eighteen keys were bound to eighteen craft. A player never saw either.
func _the_help_page_says_what_every_finger_does() -> void:
	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	rig.clipboard.show_board(true)
	# The legend is pushed from `_process`, once the board is up, and only when the hands
	# change -- so the first frame with the board up is the one that fills it.
	await get_tree().process_frame
	await get_tree().process_frame
	var page: ClipboardPage = rig.clipboard.page()
	var said: String = page.help_text()
	_check("there_is_a_legend_on_the_board", said != "",
		"%d rows" % said.split("\n", false).size())

	# EVERY KEY THAT DOES SOMETHING IN THE CRAFT THIS RIG IS IN. Walked off `desk_keys_here`,
	# which is the same list `legend()` draws from -- so a key added anywhere is a key this asks
	# about, and a key deliberately left off the board for this craft is not reported as missing.
	#
	# It used to walk the static `desk_keys()`, and on 2026-09-17 that made this check disagree
	# with the board it audits: the legend had just learned to leave out a key the craft cannot
	# use (a boat being told about the gear), and this reported those four as unnamed. Two suites
	# asking different questions about one board, where `sense` wants the boat's legend silent
	# and this wants every pressable key named. One list is what makes both true.
	var unnamed: PackedStringArray = []
	for row in rig.desk_keys_here():
		for key in row["keys"]:
			var spelt: String = OS.get_keycode_string(key as Key)
			if not said.contains("|%s|" % spelt) and not said.contains("%s or " % spelt) \
					and not said.contains(" or %s|" % spelt):
				unnamed.append("%s (%s)" % [spelt, row["action"]])
	_check("and_every_key_the_game_binds_is_named_on_it", unnamed.is_empty(),
		"%s" % ["all %d" % PilotRig.desk_keys().size() if unnamed.is_empty()
			else unnamed])

	# AND EVERY KIND OF CRAFT, which is the half the hand-written line got wrong: it said
	# ten and there are eighteen.
	#
	# EVERY KIND THE F-ROW REACHES, and only those: `PilotRig.desk_keys` gives a kind past F35 NO key rather than an
	# invalid one, and such a kind is boarded from the CRAFT page instead. Walked off `keyed_kinds`, which is the list
	# the board itself draws from, so this asks about exactly what is there. It used to walk every pilotable kind, and
	# on 2026-09-19 the P-51D became kind 35 -- one past the row -- and this reported it keyless for a key the game is
	# right not to bind. The kinds past the row get their own check below: they must still be BOARDABLE, because the
	# page is then the only way in (lane/warbirds2; `many_kinds` had the same snapshot and was mended the same day).
	var keyless: PackedStringArray = []
	var unboardable_keyed: PackedStringArray = []
	for kind in range(Sim.Kind.size()):
		var named: bool = said.contains("a %s" % Sim.kind_name(kind))
		if PilotRig.keyed_kinds().has(kind) and not named:
			keyless.append(Sim.kind_name(kind))
		elif not VehicleCatalogue.pilotable(kind) and named:
			unboardable_keyed.append(Sim.kind_name(kind))
	_check("and_every_craft_type_the_f_row_reaches_has_a_key_on_it", keyless.is_empty(),
		"%s" % ["all %d" % PilotRig.keyed_kinds().size() if keyless.is_empty() else keyless])
	# AND THE ONES PAST THE ROW ARE ON THE CRAFT PAGE, which is then the only way into them.
	var off_the_row: PackedStringArray = []
	var missing_from_the_page: PackedStringArray = []
	var on_the_page: PackedStringArray = []
	for row in VehicleCatalogue.craft_rows():
		on_the_page.append(String(row["name"]))
	for kind in VehicleCatalogue.pilotable_kinds():
		if PilotRig.kind_key(kind) == KEY_NONE:
			off_the_row.append(Sim.kind_name(kind))
			if not on_the_page.has(Sim.kind_name(kind)):
				missing_from_the_page.append(Sim.kind_name(kind))
	_check("and_a_craft_past_the_f_row_is_reached_from_the_craft_page", missing_from_the_page.is_empty(),
		"%s past F35, each on the page" % [off_the_row] if missing_from_the_page.is_empty()
			else "off the page: %s" % [missing_from_the_page])
	# AND NONE FOR A CRAFT NOBODY MAY BOARD: a key the host refuses every time it is pressed.
	_check("and_no_key_asks_for_a_craft_nobody_may_board", unboardable_keyed.is_empty()
			and VehicleCatalogue.pilotable_kinds().size() < Sim.Kind.size(),
		"%d of %d kinds may be boarded%s" % [VehicleCatalogue.pilotable_kinds().size(), Sim.Kind.size(),
			"" if unboardable_keyed.is_empty() else ", keyed anyway: %s" % unboardable_keyed])

	# EVERY INPUT THAT IS ACTUALLY BOUND ON EITHER HAND, asked of `_bindings_for`, which is
	# the function the fingers are read through. NOT of `Bind.inputs()`: an empty hand does
	# not bind the joystick click at all, and a legend that listed it anyway would be
	# describing an input that does nothing -- which is the dead-switch-on-a-panel problem
	# this project already has a rule about. What a page must not do is MISS one.
	var fingers: PackedStringArray = []
	for hand in range(2):
		var where: String = "LEFT HAND" if hand == 0 else "RIGHT HAND"
		for input in Bind.inputs():
			if not rig._bindings_for(hand).has(input):
				continue
			if not said.contains("%s|%s|" % [where, Bind.input_name(input)]):
				fingers.append("%s %s" % [where, Bind.input_name(input)])
	_check("and_every_finger_that_is_bound_is_named_on_it", fingers.is_empty(),
		"%s" % ["every bound input on both hands" if fingers.is_empty() else fingers])
	# THE TWO NOTHING MAY REBIND. `Bind` reserves the grip and the menu button, so they are
	# in no table to be read from -- and a legend that only listed the bindable ones would
	# leave out the input every interaction in this game starts with.
	_check("and_the_two_inputs_nothing_may_rebind_are_too",
		said.contains("|grip|") and said.contains("|menu button|"),
		"grip %s, menu %s" % [said.contains("|grip|"), said.contains("|menu button|")])
	rig.queue_free()

	# AND WHAT A FINGER DOES CHANGES WITH WHAT THE HAND IS HOLDING, which is the whole
	# design of the bindings and the one thing a fixed picture of a controller cannot say.
	# An empty left hand BRAKES with its trigger; a hand on a gun grip FIRES with it, and
	# the gun says `Bind.nothing()` about the brake so a gunner does not stop the aeroplane
	# every time they shoot.
	await _and_a_hand_on_a_gun_says_so()


## A HAND ACTUALLY CLOSED ON A GUN, through the rig, at a real station.
##
## The real path and not a flag: `held_by` set by hand is a control that `_claim_controls`
## clears on the next frame, because a rig with no station and no view lets go of
## everything. So this sits the rig at a station the way the hall of cockpits does, puts the
## gun on that station, and closes the hand with `force_grip` -- which is the seam every
## grab test in this project was missing.
func _and_a_hand_on_a_gun_says_so() -> void:
	var plinth := Node3D.new()
	add_child(plinth)
	var station := VehicleCatalogue.seat_scene(Sim.Kind.PLANE).instantiate() as CockpitStation
	plinth.add_child(station)
	station.fit(0, true, Sim.Kind.PLANE, false)
	var gun := GunTrigger.new()
	gun.name = "Gunnery"
	# Well clear of the console furniture: a hand is offered the NEAREST control it could
	# take, so a gun dropped on top of the throttle would be a test of which is closer.
	gun.position = Vector3(-0.62, 0.0, 0.0)
	station.add_child(gun)
	gun.setup(0)

	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	rig.take_station(station)
	rig.clipboard.show_board(true)
	rig.force_grip(1, 0.0)
	rig.force_hand(1, Transform3D(Basis.IDENTITY, Vector3(0.0, -40.0, 0.0)))
	for i in range(3):
		await get_tree().process_frame
	var empty: String = rig.clipboard.page().help_text()

	rig.force_hand(0, gun.global_transform * Transform3D(Basis.IDENTITY, gun._grab_point()))
	rig.force_grip(0, 1.0)
	for i in range(3):
		await get_tree().process_frame
	# TAKING HOLD PUTS THE BOARD AWAY -- see `PilotRig._put_the_board_away_for` -- and a legend
	# is only drawn while the board is up, so reading it now would read the rows from before
	# the grab. This suite found that by failing. Bring it back up, as a player would to see
	# what the gun does, and let the rig redraw it.
	var put_away: bool = not rig.clipboard.is_up()
	rig.clipboard.show_board(true)
	for i in range(3):
		await get_tree().process_frame
	var holding: String = rig.clipboard.page().help_text()
	_check("an_empty_left_hand_brakes_with_its_trigger",
		_row_for(empty, "LEFT HAND", "trigger").ends_with("|brake"),
		_row_for(empty, "LEFT HAND", "trigger"))
	_check("and_taking_hold_of_the_gun_put_the_board_away", put_away,
		"board up after the grab: %s" % (not put_away))
	_check("and_a_hand_on_a_gun_fires_with_it", gun.is_held()
		and _row_for(holding, "LEFT HAND", "trigger").contains("fire"),
		"holding %s: %s" % [gun.is_held(), _row_for(holding, "LEFT HAND", "trigger")])
	rig.queue_free()
	plinth.queue_free()


## One row of the legend, for a failure message: what `where`'s `what` says it does.
func _row_for(legend: String, where: String, what: String) -> String:
	for line in legend.split("\n", false):
		if line.begins_with("%s|%s|" % [where, what]):
			return line
	return "not on the page"


## ---- filling a sky that starts quiet --------------------------------------------------

## THE WORLD IS BUILT QUIET NOW, and this is what fills it.
##
## About fifty-two machines fit in a tick's replication budget -- see Terrain's fleet note
## and the crowd measurements in agents.md -- and the world was building a hundred and sixty.
## Everything got less fresh, which from a cockpit looks like jitter and like aeroplanes
## sinking between updates.
##
## What is checked here is the BUTTON, not the spawn: the page announces and `Sky` decides,
## which is the same split every other control on this board follows, and the spawn needs a
## session and a server that this suite has no business standing up.
func _the_board_fills_the_sky() -> void:
	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	rig.clipboard.show_board(true)
	var page: ClipboardPage = rig.clipboard.page()
	page.show_tab(ClipboardPage.Tab.TRAFFIC)
	await get_tree().process_frame

	var adders: Dictionary = {}
	for node in page.find_children("*", "Button", true, false):
		var text: String = String((node as Button).text)
		if text.begins_with("+ "):
			adders[text.substr(2)] = node
	_check("the_board_can_add_traffic_to_a_quiet_sky",
		adders.has(Sim.kind_name(Sim.Kind.PLANE)) and adders.size() >= 4,
		"%d add buttons: %s" % [adders.size(), adders.keys()])

	# AND IT ASKS FOR THE KIND ON THE BUTTON. One row per kind is worth nothing if they all
	# ask for the same thing, and nothing else would notice: the sky spawns whatever it is
	# handed and every kind flies.
	var asked: Array = []
	page.chose_traffic.connect(func(kind: int): asked.append(kind))
	for kind in [Sim.Kind.PLANE, Sim.Kind.BOAT]:
		var button := adders.get(Sim.kind_name(kind)) as Button
		if button != null:
			button.pressed.emit()
	_check("and_each_button_asks_for_its_own_kind",
		asked == [Sim.Kind.PLANE, Sim.Kind.BOAT],
		"asked for %s" % [asked])

	# AND THE CLIPBOARD PASSES IT ON. The page announces; the board in the hand is what the
	# level listens to, and a signal that stops at the page is a button that does nothing.
	var through: Array = []
	rig.clipboard.chose_traffic.connect(func(kind: int): through.append(kind))
	(adders.get(Sim.kind_name(Sim.Kind.HELI)) as Button).pressed.emit()
	_check("and_the_board_passes_it_to_whoever_is_holding_it",
		through == [Sim.Kind.HELI], "reached the clipboard as %s" % [through])
	rig.queue_free()


## ---- nothing past the edge ---------------------------------------------------------------

## NOTHING ON THE BOARD RUNS OFF THE GLASS, on any tab -- not past its right-hand edge, and not past its bottom.
##
## The page is sized in pixels scaled by `BoardStyle`, and a row whose least width is wider than the glass does not wrap
## or shrink: it widens the column it sits in, and everything in that column is cut off on the right. That was reported
## from a headset on 2026-09-13 after the writing went to x1.4 (ea707a9). The same day the controls were asked to be
## bigger AND still fit, which is the bottom edge: the tabs, the answer line, the switches and MAIN MENU are furniture
## that does not scroll, and furniture taller than the glass pushes the way out off the bottom. So every visible
## Control is measured against the page's own viewport: none past its width, none outside the scrolling area past its
## height, and the scrolling area itself ends on the glass.
##
## AND A PAGE THAT SCROLLS SAYS SO. `ClipboardPage.MAY_SCROLL` is where that is written down with its reason, and a page
## whose content is taller than the scrolling area without being on it fails here.
##
## ON A RIG SITTING AT A CONSOLE, so FEEL lists a cockpit's controls and HELP a real hand's fingers -- an empty rig has
## pages with nothing on them, and "everything fits" on an empty page is not a measurement.
func _nothing_runs_off_the_board() -> void:
	var built: Dictionary = await _a_rig_at_a_console(1)
	var rig: PilotRig = built["rig"]
	var fits: Dictionary = await measure_the_board(rig, self)
	_check("nothing_on_the_board_runs_past_the_edges_of_the_glass",
		(fits["over"] as PackedStringArray).is_empty() and int(fits["measured"]) > 0,
		"%d visible controls on %d tabs against %.0f x %.0f px%s" % [fits["measured"], ClipboardPage.Tab.size(),
			fits["wide"], fits["tall"], "" if (fits["over"] as PackedStringArray).is_empty()
				else ": " + "; ".join((fits["over"] as PackedStringArray).slice(0, 8))])
	_check("and_only_the_pages_that_say_they_scroll_do", (fits["undeclared"] as PackedStringArray).is_empty(),
		"scrolling: %s; declared in ClipboardPage.MAY_SCROLL: %s" % [fits["scrolling"], fits["declared"]])
	rig.queue_free()
	(built["plinth"] as Node).queue_free()
	await get_tree().process_frame


## ---- the code on the board -----------------------------------------------------------------

## THE CODE A FRIEND TYPES IS ON WHATEVER TAB IS UP, and gone when there is no code.
##
## Asked for on 2026-09-15: "make sure the multiplayer steam code is shown somewhere on the ipad or on the hud." It had
## been at the head of the CREW list since 2026-09-14, and CREW is the sixth of eight tabs -- so this walks all eight
## and fails if any of them hides it. RED with the line back in CREW's body: "on CRAFT, TRAFFIC, FEEL, BUILD, TIME,
## AUDIO, HELP it says nothing".
##
## AND THE COUNT IS THE SESSION'S, NOT A CRAFT'S: one machine on its own, in a session of `Net.MAX_PLAYERS`.
func _the_join_code_is_on_every_tab() -> void:
	var built: Dictionary = await _a_rig_at_a_console(1)
	var rig: PilotRig = built["rig"]
	var board: Clipboard = rig.clipboard
	board.show_board(true)
	var page: ClipboardPage = board.page()
	var was: String = Net.session_code
	Net.session_code = "K7MQ2X"
	var silent: PackedStringArray = []
	var wanted: String = "STEAM CODE %s  ·  1 of %d players connected" % [JoinCode.spell("K7MQ2X"), Net.MAX_PLAYERS]
	for tab in range(ClipboardPage.Tab.size()):
		page.show_tab(tab)
		await _frames(2)
		if page.code_text() != wanted:
			silent.append("%s says '%s'" % [ClipboardPage.Tab.keys()[tab], page.code_text()])
	_check("the_steam_code_and_who_is_aboard_are_on_every_tab_of_the_board", silent.is_empty(),
		"wanted '%s'; %s" % [wanted, "every tab says it" if silent.is_empty() else ", ".join(silent)])
	# AND IT IS NOT SAID TWICE on the tab that used to own it: CREW's own list must not carry a second copy.
	page.show_tab(ClipboardPage.Tab.CREW)
	await _frames(2)
	var copies: int = 0
	for node in page.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and label.text.begins_with("STEAM CODE"):
			copies += 1
	_check("and_said_once_on_crew_rather_than_twice", copies == 1, "%d lines say it" % copies)
	# AND GONE WITH THE SESSION: solo, or over ENet, there is no code and no line where one would be.
	Net.session_code = ""
	await _frames(2)
	_check("and_nothing_where_a_code_would_be_when_the_session_has_none", page.code_text() == "",
		"'%s'" % page.code_text())
	Net.session_code = was
	board.show_board(false)
	rig.queue_free()
	(built["plinth"] as Node).queue_free()
	await get_tree().process_frame


## WHAT RUNS OFF `rig`'s BOARD, on every tab: a control past the glass's right edge, or outside the scrolling area past
## its bottom; a scrolling area that itself runs off; and which tabs have more content than their scrolling area, against
## `ClipboardPage.MAY_SCROLL`. STATIC, so tests/missiles.gd asks the same question of a rig sitting in a whole aeroplane
## -- the board here is at one console, and FEEL lists every control a rig can reach across its craft.
static func measure_the_board(rig: PilotRig, waiter: Node) -> Dictionary:
	rig.clipboard.show_board(true)
	# A TIME OF DAY HANDED IN, as a level does: a rig with no level has no sky, and its TIME tab shows a line saying so
	# instead of its buttons -- which are what has to fit.
	rig.clipboard.show_time(DaylightTuning.clock_of(DaylightTuning.When.DAY))
	var page: ClipboardPage = rig.clipboard.page()
	var screen := rig.clipboard.panel().get("_screen") as SubViewport
	var wide: float = float(screen.size.x)
	var tall: float = float(screen.size.y)
	var scroll := page.get("_scroll") as ScrollContainer
	var over: PackedStringArray = []
	var scrolling: PackedStringArray = []
	var measured: int = 0
	# AND AGAIN WITH THE DEBRIEF AND THE JOIN CODE SHOWING, as a Steam game in a fire has them: two lines of furniture
	# on every tab that take their height from the page, and BUILD scrolling mid-fire is the same bug as BUILD scrolling
	# at a console (2026-09-13). The WORST CASE, both at once, because that is the board a hosting player flies with:
	# measuring them one at a time would pass a board that fits either and neither together.
	# The longest sentence `FireFront.debrief` writes, at the cap, with three-figure counts.
	var fire_line: String = "%d fires alight of %d, %d put out, %d lit by the fire itself." % [FireFront.MAX_FIRES,
		FireFront.MAX_FIRES, 999, 999]
	var was_the_code: String = Net.session_code
	# AND THE SESSION'S NOTICE (plan item 13), a third line of furniture: the longest one this build can write, a level
	# count-down naming the level with the longest name, held on for the whole pass.
	var was_the_notice: Dictionary = Net.notice
	var longest: LevelChart = null
	for chart in ChartDrawer.charts():
		if longest == null or (chart as LevelChart).name.length() > longest.name.length():
			longest = chart
	for debrief in ["", fire_line]:
		rig.clipboard.show_debrief(debrief)
		# The code line reads `Net`, as the CREW page does; set here so the fullest pass carries it.
		Net.session_code = "K7MQ2X" if debrief != "" else ""
		Net.notice = {} if debrief == "" or longest == null else {"kind": "level", "level": longest.id,
			"due": Time.get_ticks_msec() + 60000, "shown_until": Time.get_ticks_msec() + 120000}
		page.tick()
		for tab in range(ClipboardPage.Tab.size()):
			page.show_tab(tab)
			for i in range(4):
				await waiter.get_tree().process_frame
			var tab_name: String = ClipboardPage.Tab.keys()[tab]
			var showing: String = " with the debrief, the code and a notice" if debrief != "" else ""
			for node in page.find_children("*", "Control", true, false):
				var control := node as Control
				if not control.is_visible_in_tree():
					continue
				measured += 1
				var rect: Rect2 = control.get_global_rect()
				var said: Variant = control.get("text")
				var named: String = String(said) if said != null else String(control.name)
				if rect.end.x > wide + 0.5:
					over.append("%s%s %s '%s' right edge at %.0f" % [tab_name, showing, control.get_class(), named, rect.end.x])
				var scrolls_away: bool = scroll != null and scroll.is_ancestor_of(control)
				if not scrolls_away and rect.end.y > tall + 0.5:
					over.append("%s%s %s '%s' bottom edge at %.0f" % [tab_name, showing, control.get_class(), named,
						rect.end.y])
			if scroll != null:
				var area: Rect2 = scroll.get_global_rect()
				if area.end.y > tall + 0.5 or scroll.size.y < 1.0:
					over.append("%s%s the scrolling area runs %.0f to %.0f" % [tab_name, showing, area.position.y, area.end.y])
				var inside := scroll.get_child(0) as Control
				if inside != null and inside.get_combined_minimum_size().y > scroll.size.y + 0.5:
					scrolling.append("%s (%.0f px of content in %.0f%s)" % [tab_name, inside.get_combined_minimum_size().y,
						scroll.size.y, showing])
	rig.clipboard.show_debrief("")
	Net.session_code = was_the_code
	Net.notice = was_the_notice
	page.tick()
	rig.clipboard.show_board(false)
	var declared: PackedStringArray = []
	for tab in ClipboardPage.MAY_SCROLL:
		declared.append(ClipboardPage.Tab.keys()[tab])
	var undeclared: PackedStringArray = []
	for said in scrolling:
		if not said.get_slice(" ", 0) in declared:
			undeclared.append(said)
	return {"over": over, "scrolling": scrolling, "undeclared": undeclared, "declared": declared,
		"measured": measured, "wide": wide, "tall": tall}


## ---- a switch that is off ----------------------------------------------------------------

## AN OFF SWITCH LOOKS LIKE A SWITCH. Asked for on 2026-09-13: "make the off switches easier to see".
##
## A real switch on each board -- LABELS on the clipboard, ROTATION SNAP on the snap board -- resolves its off icon to
## BoardStyle's theme, and not to Godot's own icon with its dot. Then the pixels of that off icon as drawn: a quarter of it
## at least, bright enough against the board's own colour, and its knob on the other side from the on icon's.
func _an_off_switch_looks_like_a_switch() -> void:
	var built: Dictionary = await _a_rig_at_a_console(1)
	var rig: PilotRig = built["rig"]
	rig.clipboard.show_board(true)
	var snaps := SnapBoard.new()
	add_child(snaps)
	snaps.show_grid(PlacingGrid.new())
	await _frames(2)
	var wanted: Texture2D = BoardStyle.theme().get_icon("unchecked", "CheckButton")
	var labels: CheckButton = _switch_reading(rig.clipboard.page(), "LABELS")
	var rotation: CheckButton = _switch_reading(snaps.page(), "ROTATION SNAP")
	var on_board: Texture2D = labels.get_theme_icon("unchecked", "CheckButton") if labels != null else null
	var on_snaps: Texture2D = rotation.get_theme_icon("unchecked", "CheckButton") if rotation != null else null
	_check("a_switch_on_either_board_wears_board_styles_switch",
		wanted != null and on_board == wanted and on_snaps == wanted,
		"LABELS' off icon %s, ROTATION SNAP's %s, the theme's %s" % [on_board, on_snaps, wanted])

	var off: Image = BoardStyle.switch_image("unchecked")
	var on: Image = BoardStyle.switch_image("checked")
	var board: float = _luminance(BoardStyle.BOARD)
	var drawn: int = 0
	var bright: float = 0.0
	var off_x: float = 0.0
	for y in range(off.get_height()):
		for x in range(off.get_width()):
			var px: Color = off.get_pixel(x, y)
			if px.a > 0.5:
				drawn += 1
				bright += _luminance(px)
				off_x += float(x)
	var area: int = off.get_width() * off.get_height()
	var mean: float = bright / maxf(float(drawn), 1.0)
	var contrast: float = (maxf(mean, board) + 0.05) / (minf(mean, board) + 0.05)
	_check("and_an_off_switch_is_a_track_you_can_see_and_not_a_dot",
		float(drawn) >= float(area) * BoardStyle.SWITCH_COVER_LEAST and contrast >= BoardStyle.SWITCH_CONTRAST_LEAST,
		"%d of %d px drawn (least %.0f %%), %.1f:1 against the board (least %.1f), %d x %d" % [drawn, area,
			BoardStyle.SWITCH_COVER_LEAST * 100.0, contrast, BoardStyle.SWITCH_CONTRAST_LEAST, off.get_width(),
			off.get_height()])
	# THE KNOB MOVES. The on icon's knob is the dark pixels on its bright track; the off icon's knob fills its left end,
	# which pulls the mean of everything drawn left of the middle.
	var knob_x: float = 0.0
	var knob: int = 0
	for y in range(on.get_height()):
		for x in range(on.get_width()):
			var px: Color = on.get_pixel(x, y)
			if px.a > 0.5 and _luminance(px) < 0.2:
				knob_x += float(x)
				knob += 1
	_check("and_on_and_off_differ_by_where_the_knob_is",
		knob > 0 and knob_x / float(knob) > float(on.get_width()) * 0.5
			and off_x / maxf(float(drawn), 1.0) < float(off.get_width()) * 0.5,
		"on's knob at x %.1f, off's pixels at x %.1f, of %d" % [knob_x / maxf(float(knob), 1.0),
			off_x / maxf(float(drawn), 1.0), off.get_width()])

	# AND EVERY PILL IS BESIDE ITS OWN WORDS. A switch that fills its share of a row draws its pill at the right-hand end
	# of it, beside the NEXT switch's words: LABELS' pill was 22 px from FINE SCENERY and 150 px from LABELS (2026-09-14).
	# On every tab of a board at a console -- so FEEL has its TURN switches -- and on the snap board.
	var strays: PackedStringArray = []
	var page: ClipboardPage = rig.clipboard.page()
	for tab in range(ClipboardPage.Tab.size()):
		page.show_tab(tab)
		await _frames(3)
		for said in pills_beside_other_words(page):
			strays.append("%s: %s" % [ClipboardPage.Tab.keys()[tab], said])
	for said in pills_beside_other_words(snaps.page()):
		strays.append("SNAP: %s" % said)
	_check("and_every_switchs_pill_is_nearer_its_own_words_than_any_others", strays.is_empty(),
		"every switch on %d tabs and the snap board" % ClipboardPage.Tab.size() if strays.is_empty()
			else "; ".join(strays.slice(0, 6)))
	snaps.queue_free()
	rig.queue_free()
	(built["plinth"] as Node).queue_free()
	await get_tree().process_frame


## The CheckButton on `page` that reads `text`, shown or not, or null.
static func _switch_reading(page: Control, text: String) -> CheckButton:
	if page == null:
		return null
	for node in page.find_children("*", "CheckButton", true, false):
		if (node as CheckButton).text == text:
			return node as CheckButton
	return null


## THE SWITCHES ON `page` WHOSE PILL IS AS NEAR SOME OTHER WORDS AS ITS OWN, as sentences, among the switches and labels
## showing. A CheckButton writes its words from its stylebox's left margin and draws its pill against the right one; a
## Label writes from its left edge. Words are measured with the font they are drawn in, and no wider than their control.
static func pills_beside_other_words(page: Control) -> PackedStringArray:
	var words: Array = []
	for node in page.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or not (control is CheckButton or control is Label):
			continue
		var said: String = String(control.get("text")).strip_edges()
		if said.is_empty():
			continue
		# ONLY WHERE THEY CAN BE SEEN. Words in a scrolling page are cut off at its edge, and HELP's legend runs on under the
		# board's switches -- counted whole, lines nobody can see stood 0 px from LABELS' pill (2026-09-14).
		var seen: Rect2 = _where_the_words_are(control, said)
		for above in _scrolling_areas_round(control):
			seen = seen.intersection(above.get_global_rect())
		if seen.size.x <= 0.0 or seen.size.y <= 0.0:
			continue
		words.append([control, seen])
	var out: PackedStringArray = []
	for entry in words:
		var switch := entry[0] as CheckButton
		if switch == null:
			continue
		var icon: Texture2D = switch.get_theme_icon("unchecked", "CheckButton")
		var rect: Rect2 = switch.get_global_rect()
		var pill := Rect2(rect.end.x - switch.get_theme_stylebox("normal").get_margin(SIDE_RIGHT) - icon.get_width(),
			rect.get_center().y - icon.get_height() * 0.5, icon.get_width(), icon.get_height())
		var own: float = _apart(pill, entry[1] as Rect2)
		for other in words:
			if other[0] == switch:
				continue
			var there: float = _apart(pill, other[1] as Rect2)
			if there <= own:
				out.append("'%s' pill %.0f px from its words and %.0f from '%s'" % [switch.text, own, there,
					(other[0] as Control).get("text")])
	return out


static func _where_the_words_are(control: Control, said: String) -> Rect2:
	var font: Font = control.get_theme_font("font")
	var wide: float = minf(font.get_string_size(said, HORIZONTAL_ALIGNMENT_LEFT, -1,
		control.get_theme_font_size("font_size")).x, control.size.x)
	var left: float = (control as Button).get_theme_stylebox("normal").get_margin(SIDE_LEFT) if control is Button else 0.0
	var rect: Rect2 = control.get_global_rect()
	return Rect2(rect.position.x + left, rect.position.y, wide, rect.size.y)


## Every ScrollContainer `control` sits inside, nearest first: the edges its words are cut off at.
static func _scrolling_areas_round(control: Control) -> Array[ScrollContainer]:
	var out: Array[ScrollContainer] = []
	var above: Node = control.get_parent()
	while above != null:
		if above is ScrollContainer:
			out.append(above as ScrollContainer)
		above = above.get_parent()
	return out


## How far apart two rectangles are, 0 where they touch or overlap.
static func _apart(a: Rect2, b: Rect2) -> float:
	var across: float = maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var down: float = maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(across, down).length()


## The relative luminance of a colour stored as sRGB, with the gamma taken off: what a contrast ratio is taken between.
static func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * float(lin.call(c.r)) + 0.7152 * float(lin.call(c.g)) + 0.0722 * float(lin.call(c.b))

## ---- the way out ----------------------------------------------------------------------

## EVERY LEVEL WAS A ONE-WAY DOOR.
##
## You could reach the world, the hall and both marshalling levels from the desk, and once
## you were in one the only way back was to quit the program -- which in a headset means
## taking it off. The clipboard is the one piece of furniture that follows the player into
## every one of them, so the door goes on the clipboard.
##
## AND IT TAKES TWO PRESSES, which is the half worth testing. This throws away the session,
## and the thing pressing it is a fingertip waved at a panel on the end of your own arm --
## a good deal easier to brush against than a mouse is to misclick.
func _the_way_back_to_the_desk() -> void:
	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	rig.clipboard.show_board(true)
	var page: ClipboardPage = rig.clipboard.page()
	await get_tree().process_frame
	# THE DOOR IS UNHOOKED FIRST, and the fact that it has to be is the point: left
	# connected, the second press below does exactly what it promises -- changes the scene
	# to the desk -- and takes this suite with it. That is the wiring working, and it is
	# asserted separately rather than by watching the test disappear.
	_check("and_the_rig_wires_it_to_the_way_out",
		rig.clipboard.chose_menu.is_connected(Doors.to_the_desk),
		"the clipboard's way out reaches Doors.to_the_desk")
	if rig.clipboard.chose_menu.is_connected(Doors.to_the_desk):
		rig.clipboard.chose_menu.disconnect(Doors.to_the_desk)

	var leave: Button = null
	for node in page.find_children("*", "Button", true, false):
		if String((node as Button).text).contains("MAIN MENU"):
			leave = node as Button
	_check("the_clipboard_has_a_way_back_to_the_main_menu", leave != null,
		"%s" % ["found it" if leave != null else "no button says MAIN MENU"])
	if leave == null:
		rig.queue_free()
		return

	# ONE PRESS ARMS IT AND SAYS SO. Nothing leaves the level yet.
	var asked: Array = [0]
	page.chose_menu.connect(func(): asked[0] += 1)
	leave.pressed.emit()
	_check("and_one_press_only_asks_whether_you_meant_it",
		int(asked[0]) == 0 and page.leaving()
			and String(leave.text).contains("AGAIN"),
		"asked %d time(s), the button now reads %s" % [int(asked[0]), leave.text])

	# THE SECOND ONE MEANS IT.
	leave.pressed.emit()
	_check("and_the_second_one_means_it", int(asked[0]) == 1,
		"asked %d time(s)" % int(asked[0]))

	# AND CHANGING YOUR MIND IS FREE: left alone, it puts itself back.
	_arm_and_wait(page, leave)
	await get_tree().create_timer(ClipboardPage.MEANT_IT + 0.3).timeout
	_check("and_it_disarms_itself_if_you_walk_away",
		not page.leaving() and String(leave.text).contains("MAIN MENU"),
		"the button reads %s after %.0f s" % [leave.text, ClipboardPage.MEANT_IT])
	rig.queue_free()


func _arm_and_wait(page: ClipboardPage, leave: Button) -> void:
	if not page.leaving():
		leave.pressed.emit()


## ---- the board ------------------------------------------------------------------------

func _the_board_in_the_hand() -> void:
	_rig = (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(_rig)
	await get_tree().process_frame
	var board: Clipboard = _rig.clipboard
	_check("there_is_a_clipboard", board != null, "%s" % [board])
	if board == null:
		return
	# IN THE LEFT HAND, which is what makes it a clipboard rather than a panel hanging in
	# the world: it goes where the hand goes, and nothing writes a transform for it.
	_check("and_it_is_in_the_left_hand", board.get_parent() == _rig.left_hand,
		"parent is %s" % [board.get_parent().name if board.get_parent() != null else "-"])
	_check("and_it_starts_put_away", not board.is_up(), "up: %s" % board.is_up())
	board.toggle()
	var came_up: bool = board.is_up()
	board.toggle()
	_check("and_one_button_brings_it_up_and_puts_it_away",
		came_up and not board.is_up(), "up then %s" % board.is_up())

	board.show_board(true)
	await get_tree().process_frame
	var page: ClipboardPage = board.page()
	_check("and_there_is_a_page_on_it", page != null, "%s" % [page])
	if page == null:
		return
	# EVERY KIND IS ON IT. The same check the desk's doors get, for the same reason: a craft
	# you cannot reach from inside a headset is a craft that is not in the game.
	var named: Array[String] = []
	for node in page.find_children("*", "Button", true, false):
		named.append(String((node as Button).text).to_lower())
	var missing: Array[String] = []
	for kind in VehicleCatalogue.pilotable_kinds():
		if not named.has(Sim.kind_name(kind)):
			missing.append(Sim.kind_name(kind))
	_check("and_every_craft_in_the_game_is_on_it", missing.is_empty(),
		"%s" % ["all %d" % VehicleCatalogue.pilotable_kinds().size() if missing.is_empty() else missing])
	# AND NOTHING NOBODY MAY BOARD, found by PRESSING every button on the CRAFT page and listening
	# to what the page announces -- not by reading the names, which a button labelled one thing
	# and wired to another would pass. The pirate ship is the case: `pilotable` false in the
	# simulation's table, so the host refuses it, so the page must not offer it.
	var asked: Array[int] = []
	var listen := func(kind: int) -> void: asked.append(kind)
	page.chose_kind.connect(listen)
	page.show_tab(ClipboardPage.Tab.CRAFT)
	var pressed: int = 0
	for node in page.find_children("*", "Button", true, false):
		var button := node as Button
		if Sim.Kind.keys().has(String(button.text).to_upper()):
			button.pressed.emit()
			pressed += 1
	page.chose_kind.disconnect(listen)
	var unboardable: Array[String] = []
	for kind in asked:
		if not VehicleCatalogue.pilotable(kind):
			unboardable.append(Sim.kind_name(kind))
	_check("and_no_press_on_it_asks_for_a_craft_nobody_may_board",
		unboardable.is_empty() and asked.size() == VehicleCatalogue.pilotable_kinds().size()
			and not VehicleCatalogue.pilotable(Sim.Kind.PIRATE),
		"%d craft buttons pressed, %d kinds asked for, the pirate ship %s%s" % [pressed, asked.size(),
			"not boardable" if not VehicleCatalogue.pilotable(Sim.Kind.PIRATE) else "BOARDABLE",
			"" if unboardable.is_empty() else ", asked anyway: %s" % unboardable])
	_check("and_a_tab_for_the_crew", named.has("craft") and named.has("crew"),
		"%s" % [named.slice(0, 2)])


## ---- up and down a page you cannot drag ------------------------------------------------

## THE THUMB SCROLLS THE BOARD, AND ONLY WHILE IT IS UP.
##
## A page on a clipboard is a list longer than the clipboard. There is no bar to drag --
## dragging a two-millimetre strip with a fingertip in a headset is not a thing anybody
## manages -- so the two buttons under the thumb of the hand HOLDING it are the scroll, and
## the other hand stays free to press what they bring into view.
##
## AND THEY GO BACK TO WHAT THEY WERE WHEN IT IS PUT AWAY, which is the half that could
## quietly break. Those buttons walk the machines and change seat in an empty hand; a board
## that kept them after it was dismissed would be a player who could no longer change craft
## and would have no way to find out why.
func _the_thumb_walks_the_page() -> void:
	if _rig == null or _rig.clipboard == null:
		return
	var board: Clipboard = _rig.clipboard
	board.show_board(false)
	var away: Dictionary = _rig._bindings_for(0)
	_check("with_the_board_away_the_thumb_walks_the_machines",
		int((away[Bind.THUMB_HIGH] as Dictionary).get("kind", -1)) == Bind.Kind.FRAME_BIT,
		"%s" % [away[Bind.THUMB_HIGH]])

	board.show_board(true)
	await get_tree().process_frame
	var up: Dictionary = _rig._bindings_for(0)
	_check("and_with_it_up_the_same_thumb_scrolls_it",
		int((up[Bind.THUMB_HIGH] as Dictionary).get("what", -1)) == Bind.Local.SCROLL_UP
			and int((up[Bind.THUMB_LOW] as Dictionary).get("what", -1))
				== Bind.Local.SCROLL_DOWN,
		"high %s, low %s" % [up.get(Bind.THUMB_HIGH), up.get(Bind.THUMB_LOW)])

	# AND IT ACTUALLY MOVES. The binding being right is worth nothing if the page it names
	# has no scroll in it -- which is what it had before: a column pinned to the full rect,
	# with everything past the bottom edge simply not drawn.
	# ON A PAGE LONGER THAN THE BOARD, which is the only kind there is anything to scroll
	# on. A cockpit with thirty controls in it is what FEEL looks like in a big aeroplane,
	# and it is handed over the same way the rig hands over a real one.
	var page: ClipboardPage = board.page()
	var many: Array = []
	for i in range(60):
		many.append("CONTROL %d" % i)
	page.show_controls(many)
	page.show_tab(ClipboardPage.Tab.FEEL)
	for _frame in range(4):
		await get_tree().process_frame
	var top: int = page.scrolled()
	board.scroll(1)
	var down: int = page.scrolled()
	board.scroll(-1)
	_check("and_the_page_moves_under_it", top == 0 and down > top and page.scrolled() == 0,
		"%d then %d then %d" % [top, down, page.scrolled()])

	# AND ALL THE WAY TO THE LAST SWITCH. FEEL may scroll (ClipboardPage.MAY_SCROLL: its length is the craft's control
	# count, which a saved layout changes), and a page allowed to run past the board is only allowed to if the thumb can
	# bring its last row onto the glass. Pulled until the page stops moving, then the last switch has to be inside the
	# scrolling area.
	var feel := page.get("_feel") as Control
	var area := page.get("_scroll") as ScrollContainer
	var last: Control = null
	for node in feel.find_children("*", "BaseButton", true, false):
		if (node as Control).is_visible_in_tree():
			last = node as Control
	var pulls: int = 0
	var was: int = -1
	while page.scrolled() != was and pulls < 60:
		was = page.scrolled()
		board.scroll(1)
		await get_tree().process_frame
		pulls += 1
	var inside: bool = last != null and area != null \
		and last.get_global_rect().end.y <= area.get_global_rect().end.y + 0.5 \
		and last.get_global_rect().position.y >= area.get_global_rect().position.y - 0.5
	_check("and_the_thumb_brings_the_last_switch_on_feel_onto_the_glass", inside and page.scrolled() > 0,
		"%d pulls to %d px; last switch %s at %s in %s" % [pulls, page.scrolled(),
			last.get("text") if last != null else "none", last.get_global_rect() if last != null else "-",
			area.get_global_rect() if area != null else "-"])
	board.scroll(-1000)
	await get_tree().process_frame

	# AND A NEW TAB STARTS AT THE TOP. Landing halfway down a page you have just opened
	# looks exactly like a page missing its first few rows.
	board.scroll(1)
	var moved: int = page.scrolled()
	page.show_tab(ClipboardPage.Tab.CRAFT)
	_check("and_a_fresh_tab_starts_at_the_top", moved > 0 and page.scrolled() == 0,
		"%d, then %d" % [moved, page.scrolled()])
	board.show_board(false)


## ---- one press, one request -------------------------------------------------------------

## A MENU PRESS HAS TO LAND ON EXACTLY ONE INPUT FRAME.
##
## The frame goes out every tick, so a request left standing in it is a request the server
## answers a hundred and twenty times a second -- which for "put me in a helicopter" is a
## player being moved between helicopters for as long as the menu is open.
func _one_press_is_one_request() -> void:
	if _rig == null:
		return
	# A MENU PRESS IS A NUMBER, NOT A BUTTON. `Sim.menu_request` moves on by one per press and is on EVERY frame; a JOIN's
	# player and seat, or a craft's kind, ride beside it until the server shows its answer or the patience runs out. The
	# server acts when the number changes, so a skipped or late frame cannot lose a press (ashiato-gd/LEARNINGS.md). Read
	# with `get`, so an older rig and Sim fail these checks rather than stopping the suite.
	var saved_answer: Dictionary = Sim.join_answer
	var saved_pilots: Array = Sim.pilots
	var me: int = Sim.local_client_id()
	var has_number: bool = Sim.get("menu_request") != null
	if has_number:
		Sim.set("menu_request", 0)
	Sim.join_answer = {}
	Sim.pilots = [{"client": me, "vehicle": 5, "seat": 0}]
	var patience: int = int(_rig.call("join_patience_frames")) if _rig.has_method("join_patience_frames") else -1
	# NOTHING WAITING TO START WITH. The trigger section above asked this rig for a craft, and with no session nothing
	# answers it: read it past its patience, or the first press below is refused as a second press.
	for i in range(maxi(patience, 0) + 2):
		_rig.read_controls()

	_rig.ask_to_join(7)
	var joining: Dictionary = _rig.read_controls()
	_check("a_join_press_moves_the_menu_number_on_and_names_that_player", has_number
		and int(joining.get("menu_request", -1)) == 1 and int(joining["join_wanted"]) == 7
		and int(joining.get("join_seat", -1)) == Sim.ANY_SEAT and (int(joining["buttons"]) & 32) == 0,
		"number %s, client %d, seat %s, buttons %d" % [joining.get("menu_request"), int(joining["join_wanted"]),
			joining.get("join_seat"), int(joining["buttons"])])
	var still: Dictionary = {}
	for i in range(10):
		still = _rig.read_controls()
	_check("and_keeps_the_number_and_the_player_on_every_frame_while_unanswered",
		int(still.get("menu_request", -1)) == 1 and int(still["join_wanted"]) == 7,
		"ten frames later: number %s, client %d" % [still.get("menu_request"), int(still["join_wanted"])])

	# ONE AT A TIME: a craft pressed while the JOIN waits is refused, said on the board, and moves nothing.
	var board_page: ClipboardPage = _rig.clipboard.page()
	# THROUGH `call`: a rig from before this change returns nothing from `ask_for_kind`, and taking the value of a void
	# call is a compile error that hangs the suite rather than failing this check.
	var refused_press: Variant = _rig.call("ask_for_kind", Sim.Kind.HELI)
	var after_refusal: Dictionary = _rig.read_controls()
	var still_waiting: String = String((ClipboardPage as Script).get_script_constant_map().get("STILL_WAITING", ""))
	var said := board_page.get("_said") as Label
	_check("a_second_menu_press_while_one_waits_is_refused_and_said", refused_press == false and still_waiting != ""
		and int(after_refusal.get("menu_request", -1)) == 1 and int(after_refusal["kind_wanted"]) == Sim.NO_KIND
		and int(after_refusal["join_wanted"]) == 7 and said != null and said.text == still_waiting,
		"returned %s; number %s, kind %d, client %d; said '%s'" % [refused_press, after_refusal.get("menu_request"),
			int(after_refusal["kind_wanted"]), int(after_refusal["join_wanted"]), said.text if said != null else "-"])

	Sim.join_answer = {"count": 1, "why": "joined", "seat": 1}
	var answered: Dictionary = _rig.read_controls()
	_check("and_lets_the_player_go_the_frame_after_the_answer_lands_keeping_the_number",
		int(answered["join_wanted"]) == 255 and int(answered.get("menu_request", -1)) == 1,
		"client %d, number %s" % [int(answered["join_wanted"]), answered.get("menu_request")])

	# NO ANSWER AT ALL: the player rides for exactly the patience, the number moves once, and the board says so in amber.
	_rig.ask_to_join(7, 2)
	var carried: int = 0
	var numbers: Dictionary = {}
	for i in range(maxi(patience, 0) + 20):
		var frame: Dictionary = _rig.read_controls()
		numbers[int(frame.get("menu_request", -1))] = true
		if int(frame["join_wanted"]) == 7 and int(frame.get("join_seat", -1)) == 2:
			carried += 1
	var no_answer: String = String((ClipboardPage as Script).get_script_constant_map().get("NO_ANSWER", ""))
	_rig.clipboard.show_board(true)
	board_page.show_tab(ClipboardPage.Tab.CREW)
	board_page.refresh()
	await _frames(2)
	var unanswered := board_page.find_child("Answer", true, false) as Label
	_check("with_no_answer_the_player_rides_for_the_patience_under_one_number_then_the_board_says_so_in_amber",
		carried == patience and numbers.keys() == [2] and no_answer != "" and unanswered != null
			and unanswered.text == no_answer and unanswered.get_theme_color("font_color") == BoardStyle.AMBER,
		"carried %d frames of %d; numbers seen %s; banner '%s'" % [carried, patience, numbers.keys(),
			unanswered.text if unanswered != null else "none"])
	_check("and_its_patience_is_the_time_a_connection_is_given", patience == roundi(float(Net.patience.get("connect",
		0.0)) * float(Engine.physics_ticks_per_second)), "%d frames; connect patience %s s at %d Hz" % [patience,
			Net.patience.get("connect"), Engine.physics_ticks_per_second])
	_rig.clipboard.show_board(false)

	# A CRAFT PRESS: the number moves on, the kind rides with no KIND bit, and it lets go when the craft changes.
	_rig.ask_for_kind(Sim.Kind.HELI)
	var asked: Dictionary = _rig.read_controls()
	_check("a_craft_press_moves_the_number_on_and_asks_for_that_kind_with_no_button",
		int(asked.get("menu_request", -1)) == 3 and int(asked["kind_wanted"]) == Sim.Kind.HELI
			and (int(asked["buttons"]) & Sim.BUTTON_KIND) == 0,
		"number %s, kind %d, buttons %d" % [asked.get("menu_request"), int(asked["kind_wanted"]), int(asked["buttons"])])
	Sim.pilots = [{"client": me, "vehicle": 6, "seat": 0}]
	var moved: Dictionary = _rig.read_controls()
	_check("and_lets_the_kind_go_the_frame_after_the_craft_changes", int(moved["kind_wanted"]) == Sim.NO_KIND
		and int(moved.get("menu_request", -1)) == 3, "kind %d, number %s" % [int(moved["kind_wanted"]),
			moved.get("menu_request")])
	# NO NEW CRAFT: the patience, then the board says so in amber.
	_rig.ask_for_kind(Sim.Kind.PLANE)
	for i in range(maxi(patience, 0) + 2):
		_rig.read_controls()
	var no_move: String = String((ClipboardPage as Script).get_script_constant_map().get("NO_MOVE", ""))
	said = board_page.get("_said") as Label
	_check("and_with_no_new_craft_the_board_says_so_in_amber", no_move != "" and said != null
		and said.text == no_move % "PLANE" and said.get_theme_color("font_color") == BoardStyle.AMBER,
		"said '%s'" % [said.text if said != null else "-"])

	# THE NUMBER WRAPS AT EIGHT, one step a press: nine answered presses read 5, 6, 7, 0, 1, 2, 3, 4, 5.
	var sequence: Array = []
	for press in range(9):
		var count: int = press + 10
		Sim.join_answer = {"count": count, "why": "joined", "seat": 1}
		_rig.read_controls()
		_rig.ask_to_join(7)
		sequence.append(int(_rig.read_controls().get("menu_request", -1)))
		Sim.join_answer = {"count": count + 1, "why": "joined", "seat": 1}
		_rig.read_controls()
	_check("the_number_moves_one_step_a_press_and_wraps_at_eight", sequence == [5, 6, 7, 0, 1, 2, 3, 4, 5],
		"%s" % [sequence])
	Sim.join_answer = saved_answer
	Sim.pilots = saved_pilots
	_rig.queue_free()
	_rig = null
	await get_tree().process_frame


## ---- and the server answers it -----------------------------------------------------------

## THE HALF THAT MATTERS: the press reaches the server and the server puts you in their
## aircraft.
##
## Driven through the real input frame rather than by calling the server directly, because
## the frame is the thing being tested: it is the only channel in this game that survives a
## rollback, and a join that worked when called by hand and not over the wire would be a
## join that works in a test and never in a session.
func _the_server_sits_you_with_them() -> void:
	if Sim.get("menu_request") != null:
		Sim.set("menu_request", 5)
	Net.play_solo()
	if not Sim.start():
		_check("a_session_starts", false, "Sim.start refused")
		return
	_check("a_new_session_starts_the_menu_number_at_0", Sim.get("menu_request") != null
		and int(Sim.get("menu_request")) == 0, "number %s after Sim.start" % [Sim.get("menu_request")])
	# The local client is issued a pilot and a pod on the first tick; the other player is
	# spawned here, in something with room in it.
	for i in range(20):
		await get_tree().physics_frame
	Sim.server.spawn_pilot(9, Sim.Kind.AIRLINER, Vector3(0.0, 400.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -80.0))
	for i in range(10):
		await get_tree().physics_frame
	# WHERE THEY ARE NOW, off the wire, rather than what the spawn returned. A player is
	# wherever the session says they are this tick -- every peer issues a craft to a client
	# it has not seen before, and one that arrives mid-tick can be moved once before
	# anybody looks -- and "sit with that person" has to mean where they ARE.
	var theirs: int = _vehicle_of(9)
	_check("the_other_player_is_flying_something", theirs != 0, "vehicle %d" % theirs)

	var mine: int = Sim.local_client_id()
	var was: int = _vehicle_of(mine)
	_check("and_we_are_not_in_it_yet", was != theirs and was != 0,
		"mine %d, theirs %d" % [was, theirs])

	# THE WHOLE PATH, DRIVEN BY THE BEAM ON THE BUTTON. A rig in the tree feeds its own input
	# frame every physics tick, exactly as it does in a level, so the trigger on the page's JOIN
	# goes hand -> glass -> page -> rig -> input frame -> wire -> server with nothing here standing
	# in for any of it. A test that called the server directly would pass with the menu unplugged.
	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	rig.clipboard.show_board(true)
	var page: ClipboardPage = rig.clipboard.page()
	page.show_tab(ClipboardPage.Tab.CREW)
	await _physics_frames(3)
	await _frames(2)
	var named: bool = false
	# The row has to SAY who it is, or a list of JOIN buttons is a list of guesses.
	for node in page.find_children("*", "Label", true, false):
		named = named or String((node as Label).text).contains("PLAYER 9")
	_check("the_crew_page_names_the_other_player", named, "listed: %s" % named)
	# SEAT 3 OF THEIRS, which is not the first free one: the airliner's seat 2 is free as well, so
	# a server that took "any free seat" would put us there instead.
	var join := page.find_child("Join9_2", true, false) as Button
	var first_free := page.find_child("Join9_1", true, false) as Button
	_check("and_gives_each_free_seat_of_theirs_a_join_button", join != null and first_free != null,
		"seat 3 %s, seat 2 %s" % [join, first_free])
	if join == null:
		rig.queue_free()
		Sim.stop()
		return
	await _beam_presses(rig, join)
	for i in range(30):
		await get_tree().physics_frame
	await _frames(2)
	_check("and_the_beam_on_join_puts_us_in_their_aircraft", _vehicle_of(mine) == theirs,
		"in %d, wanted %d" % [_vehicle_of(mine), theirs])
	_check("and_in_the_seat_we_pressed", _seat_of(mine) == 2 and _seat_of(9) != 2,
		"seat %d, theirs %d" % [_seat_of(mine), _seat_of(9)])
	var said := page.get("_said") as Label
	var told := page.find_child("Answer", true, false) as Label
	_check("and_the_board_says_where_we_are_at_the_head_of_the_list", told != null
		and told.text == ClipboardPage.answer_words({"why": "joined", "seat": 2})
		and said != null and said.text == ClipboardPage.JOIN_HINT,
		"head '%s', under the tabs '%s'" % [told.text if told != null else "none", said.text if said != null else "-"])

	# EVERY SEAT'S ROLE IS THE CRAFT'S OWN, read from the shape table directly and compared with the words on the row:
	# a page that fell back to one word for every seat (the first pictures said COPILOT four times) fails here.
	var row := page.find_child("Craft9", true, false) as Control
	var roles: PackedStringArray = []
	for node in (row.find_children("*", "Label", true, false) if row != null else []):
		var text: String = String((node as Label).text)
		if String((node as Label).name) != "Room" and text.length() > 2 and text[0].is_valid_int() and text[1] == " ":
			roles.append(text)
	var wanted: PackedStringArray = []
	var poses: Array = Sim.geometry_of(Sim.Kind.AIRLINER).get("seat_poses", [])
	for i in range(poses.size()):
		wanted.append("%d %s" % [i + 1, String((poses[i] as Dictionary).get("station", "")).to_upper()])
	_check("and_every_seat_says_the_station_the_craft_has_there", row != null and roles == wanted
		and not wanted.is_empty(), "row says %s, the airliner's shape says %s" % [roles, wanted])
	var whose := row.find_child("Whose", true, false) as Label if row != null else null
	_check("and_a_craft_we_are_in_keeps_yours", whose != null and whose.text == "YOURS",
		"'%s'" % [whose.text if whose != null else "none"])

	# A SEAT TAKEN BETWEEN SEEING IT AND PRESSING IT is refused by the server, and the board says so.
	# The server fills a free seat the instant before the press, so the page still shows its JOIN: this
	# is exactly the race a player on a slow link sees. The craft is OURS now, so its row is named by
	# the lower of our two client ids, and it is first on the page.
	var ours: Node = page.find_child("Craft9", true, false)
	var stale: Button = null
	var stale_seat: int = -1
	for node in (ours.find_children("Join*", "Button", true, false) if ours != null else []):
		stale = node as Button
		stale_seat = int(String(stale.name).get_slice("_", 1))
	# THE SERVER'S OWN ENTITY for the craft: `theirs` is this machine's client world's, and entity ids are per world.
	var on_server: int = 0
	for state in Sim.server.pilot_states():
		if int((state as Dictionary).get("client", -1)) == 9:
			on_server = int((state as Dictionary).get("vehicle", 0))
	var taken: bool = stale != null and bool(Sim.server.seat_client(30, on_server, stale_seat))
	# WHETHER THERE WAS A BUTTON, kept now: the page rebuilds once the seat shows as taken, and a freed button compares
	# equal to null by the time the check reads it.
	var had_button: bool = stale != null
	if had_button:
		stale.pressed.emit()
	# AND THE PILOT TURNS AWAY TO ANOTHER TAB before the answer lands: there it is the line under the tabs that says it.
	page.show_tab(ClipboardPage.Tab.CRAFT)
	for i in range(30):
		await get_tree().physics_frame
	await _frames(2)
	_check("a_seat_taken_first_is_refused_and_we_stay_put", had_button and taken and _seat_of(mine) == 2
		and _vehicle_of(mine) == theirs, "a button %s for seat %d, taken %s; we are in seat %d" % [had_button, stale_seat, taken,
			_seat_of(mine)])
	_check("and_on_another_tab_the_line_under_the_tabs_says_somebody_has_it", said != null
		and said.text == ClipboardPage.answer_words({"why": "seat_taken"}),
		"said '%s', answer %s" % [said.text if said != null else "-", Sim.join_answer])
	page.show_tab(ClipboardPage.Tab.CREW)
	await _frames(2)
	# AND SAYS IT WHERE THE PILOT IS LOOKING: at the head of the list the press was made on, above every craft, larger
	# than any other writing on the page and on the glass.
	var banner := page.find_child("Answer", true, false) as Label
	var first_row := page.find_child("Craft9", true, false) as Control
	var screen := rig.clipboard.panel().get("_screen") as SubViewport
	_check("and_says_it_big_at_the_head_of_the_list", banner != null and first_row != null
		and banner.text == ClipboardPage.answer_words({"why": "seat_taken"})
		and banner.get_theme_font_size("font_size") >= BoardStyle.text(24)
		and banner.get_global_rect().end.y <= first_row.get_global_rect().position.y + 0.5
		and Rect2(Vector2.ZERO, Vector2(screen.size)).encloses(banner.get_global_rect())
		and said != null and said.text == ClipboardPage.JOIN_HINT,
		"banner %s at %s, %s px; first row at %s" % [banner.text if banner != null else "none",
			banner.get_global_rect() if banner != null else "-",
			banner.get_theme_font_size("font_size") if banner != null else 0,
			first_row.get_global_rect() if first_row != null else "-"])

	# AND IT REFUSES RATHER THAN SHUFFLES. A craft with every seat taken is not a craft to be squeezed
	# into: the page offers no JOIN on it at all, and a press that asks anyway -- from a page a tick
	# out of date -- is turned away by the server.
	var full: Dictionary = Sim.server.spawn_pilot(11, Sim.Kind.POD,
		Vector3(200.0, 400.0, 0.0), 0.0, Vector3(0.0, 0.0, -60.0))
	var pod: int = int(full.get("vehicle", 0))
	for seat in range(1, 4):
		Sim.server.seat_client(20 + seat, pod, seat)
	for i in range(10):
		await get_tree().physics_frame
	await _frames(2)
	var offered: int = 0
	for node in page.find_children("Join11_*", "Button", true, false):
		offered += 1
	_check("a_full_craft_is_listed_with_no_join_on_it", page.find_child("Craft11", true, false) != null
		and offered == 0, "row %s, %d JOIN buttons" % [page.find_child("Craft11", true, false), offered])
	var theirs_row := page.find_child("Craft11", true, false) as Control
	var named_for := theirs_row.find_child("Whose", true, false) as Label if theirs_row != null else null
	var room := theirs_row.find_child("Room", true, false) as Label if theirs_row != null else null
	_check("and_somebody_else_s_craft_is_named_for_the_player_flying_it_and_says_how_far",
		named_for != null and named_for.text == "PLAYER 11'S" and room != null and room.text.begins_with("FULL · ")
			and room.text.ends_with(" KM"), "'%s', '%s'" % [named_for.text if named_for != null else "none",
				room.text if room != null else "none"])
	var before: int = _vehicle_of(mine)
	rig.ask_to_join(11)
	for i in range(30):
		await get_tree().physics_frame
	_check("and_a_full_craft_is_refused_rather_than_squeezed_into",
		_vehicle_of(mine) == before and String(Sim.join_answer.get("why", "")) == "full",
		"still in %d, told %s" % [_vehicle_of(mine), Sim.join_answer])
	rig.queue_free()
	Sim.stop()


## ---- the crew page, full -------------------------------------------------------------------

## EIGHT PLAYERS IN FOUR CRAFT FIT ON THE PAGE WITHOUT IT SCROLLING, at the longest words the game has.
##
## `_nothing_runs_off_the_board` measures CREW as a rig with no session shows it, which is one line.
## This hands the page the fullest manifest a session of eight can make -- four craft of the
## longest-named kind, every seat worded with the longest station any kind has, three-figure
## player numbers -- plus the Steam code line and the longest answer, and asks that nothing runs
## past the glass and the page is no taller than its scrolling area. CREW is not in MAY_SCROLL,
## and should not need to be: a list somebody is choosing a seat from wants to be seen whole.
func _the_crew_page_fits_full() -> void:
	var built: Dictionary = await _a_rig_at_a_console(1)
	var rig: PilotRig = built["rig"]
	var page: ClipboardPage = rig.clipboard.page()
	rig.clipboard.show_board(true)
	var manifest: Array = full_manifest()
	page.show_crew(manifest, {})
	page.show_tab(ClipboardPage.Tab.CREW)
	# THE TALLEST THE PAGE GETS: with the refusal showing at the head of the list, pressed and answered as a player's is.
	(page.find_child("Join191_1", true, false) as Button).pressed.emit()
	page.show_crew(manifest, {"count": 1, "why": "seat_taken"})
	await _frames(4)
	var screen := rig.clipboard.panel().get("_screen") as SubViewport
	var scroll := page.get("_scroll") as ScrollContainer
	var over: PackedStringArray = []
	var joins: int = 0
	for node in page.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		joins += 1 if control is Button and (control as Button).text == "JOIN" else 0
		if control.get_global_rect().end.x > float(screen.size.x) + 0.5:
			over.append("%s '%s' at %.0f" % [control.get_class(), control.get("text"), control.get_global_rect().end.x])
	var tall: float = (scroll.get_child(0) as Control).get_combined_minimum_size().y
	_check("the_crew_page_fits_four_full_craft_with_nothing_past_the_glass", over.is_empty() and joins == 8
		and page.find_child("Answer", true, false) != null,
		"%d JOIN on the page, want 8%s" % [joins, "" if over.is_empty() else ": " + "; ".join(over.slice(0, 6))])
	_check("and_does_not_scroll", tall <= scroll.size.y + 0.5, "%.0f px of content in %.0f" % [tall, scroll.size.y])

	# MORE CRAFT THAN FIT: twenty, nearest first after yours, and the thumb brings the farthest onto the glass. It was TEN
	# until the board grew half as big again (2026-09-18), and ten then fitted with 102 px to spare -- so the list had to
	# be longer for there to be anything to scroll to.
	var many: Array = many_manifest(MORE_CRAFT_THAN_FIT)
	page.show_crew(many, {})
	await _frames(4)
	var order: PackedStringArray = []
	for craft in many:
		order.append("%d@%.0f" % [int(craft["names"]), float(craft["distance"])])
	var nearest_first: bool = bool(many[0]["yours"])
	for i in range(2, many.size()):
		nearest_first = nearest_first and float(many[i]["distance"]) >= float(many[i - 1]["distance"])
	_check("more_craft_than_fit_are_listed_yours_first_then_nearest_first", nearest_first
		and many.size() == MORE_CRAFT_THAN_FIT,
		"order %s" % [order])
	var last := page.find_child("Craft%d" % int(many[many.size() - 1]["names"]), true, false) as Control
	var area: Rect2 = scroll.get_global_rect()
	var hidden_at_first: bool = last != null and last.get_global_rect().end.y > area.end.y + 0.5
	var pulls: int = 0
	var was: int = -1
	while page.scrolled() != was and pulls < 60:
		was = page.scrolled()
		rig.clipboard.scroll(1)
		await get_tree().process_frame
		pulls += 1
	var shown_after: bool = last != null and last.get_global_rect().end.y <= area.end.y + 0.5 \
		and last.get_global_rect().position.y >= area.position.y - 0.5
	_check("and_the_thumb_brings_the_farthest_craft_onto_the_glass", hidden_at_first and shown_after,
		"below the glass at first %s; %d pulls to %d px, last row at %s in %s" % [hidden_at_first, pulls,
			page.scrolled(), last.get_global_rect() if last != null else "-", area])
	rig.clipboard.scroll(-1000)
	var join := page.find_child("Join%d_1" % int(many[0]["names"]), true, false) as Button
	var small: int = join.get_theme_font_size("font_size") if join != null else 0
	_check("and_its_join_is_worded_as_big_as_everything_you_press", join != null
		and small == BoardStyle.pressed_text(18) and join.size.y >= BoardStyle.reach(36.0) - 0.5,
		"%s at %d px, %.0f tall" % [join, small, join.size.y if join != null else 0.0])
	rig.queue_free()
	(built["plinth"] as Node).queue_free()
	await get_tree().process_frame


## THE FULLEST CREW PAGE A SESSION OF EIGHT CAN MAKE, IN THE GAME'S OWN WORDS: the four four-seat kinds with the longest
## names, each with its own stations off the shape table, seats 1 and 3 taken by three-figure players, spread from beside
## you to 38 km off. Static, so `tests/crew_shot.gd` photographs the same page this measures. It was one kind and one
## station word for every seat, which made the widest page and a picture that said COPILOT twelve times.
static func full_manifest() -> Array:
	var kinds: Array = []
	for k in range(Sim.Kind.size()):
		if CrewManifest.stations(k).size() == CrewManifest.ROW_SEATS:
			kinds.append(k)
	kinds.sort_custom(func(a: int, b: int) -> bool: return Sim.kind_name(a).length() > Sim.kind_name(b).length())
	var pilots: Array = []
	var current: Dictionary = {}
	var away: Array = [0.0, 1200.0, 9400.0, 38000.0]
	for craft in range(4):
		current[100 + craft] = {"kind": int(kinds[craft]), "position": Vector3(float(away[craft]), 500.0, 0.0)}
		for seat in [0, 2]:
			pilots.append({"client": 191 + craft * 2 + seat / 2, "vehicle": 100 + craft, "seat": seat})
	return CrewManifest.read(pilots, current, 191)


## MORE CREWED CRAFT THAN THE PAGE HOLDS: `count` planes, one player each, yours first, and the rest at distances given
## out of order, so a page that listed them as given would not be nearest first.
static func many_manifest(count: int) -> Array:
	var pilots: Array = []
	var current: Dictionary = {}
	for craft in range(count):
		var metres: float = 0.0 if craft == 0 else float((craft * 7919) % 50000)
		current[300 + craft] = {"kind": Sim.Kind.PLANE, "position": Vector3(metres, 500.0, 0.0)}
		pilots.append({"client": 201 + craft, "vehicle": 300 + craft, "seat": 0})
	return CrewManifest.read(pilots, current, 201)


func _vehicle_of(client: int) -> int:
	for state in Sim.pilots:
		if int((state as Dictionary).get("client", -1)) == client:
			return int((state as Dictionary).get("vehicle", 0))
	return 0


func _seat_of(client: int) -> int:
	for state in Sim.pilots:
		if int((state as Dictionary).get("client", -1)) == client:
			return int((state as Dictionary).get("seat", -1))
	return -1


## ---- the board's own fingers ------------------------------------------------------------

## THE BOARD SPEAKS FOR THE FINGERS WHILE IT IS UP, and only then -- and the hand holding it
## goes on flying.
##
## Pressed through `force_input`, so every step goes through `_work_the_hands` and `_do_action`
## exactly as a headset's does; a test that called `navigate` would pass with the stick unbound.
func _the_board_has_fingers_of_its_own() -> void:
	if _rig == null or _rig.clipboard == null:
		return
	var board: Clipboard = _rig.clipboard
	var page: ClipboardPage = board.page()
	board.show_board(false)
	var away: Dictionary = _rig._bindings_for(1)
	_check("with_the_board_away_the_right_stick_flies",
		_kind_of(away.get(Bind.STICK)) == Bind.Kind.FRAME_AXIS
			and _local_of(away.get(Bind.TRIGGER)) == -1,
		"stick %s, trigger %s" % [away.get(Bind.STICK), away.get(Bind.TRIGGER)])

	board.show_board(true)
	await get_tree().process_frame
	var right: Dictionary = _rig._bindings_for(1)
	var left: Dictionary = _rig._bindings_for(0)
	_check("with_it_up_the_free_hand_works_the_page",
		_local_of(right.get(Bind.STICK)) == Bind.Local.NAVIGATE
			and _local_of(right.get(Bind.TRIGGER)) == Bind.Local.PRESS_HIGHLIGHTED
			and _local_of(right.get(Bind.STICK_CLICK)) == Bind.Local.TAB_NEXT,
		"stick %s, trigger %s, click %s" % [right.get(Bind.STICK), right.get(Bind.TRIGGER),
			right.get(Bind.STICK_CLICK)])
	# AND THE HAND HOLDING IT STILL FLIES AND BRAKES. A menu that stopped the aeroplane
	# answering the moment somebody looked at it would be the worst thing on this board.
	_check("and_the_hand_holding_it_still_flies_and_brakes",
		_kind_of(left.get(Bind.STICK)) == Bind.Kind.FRAME_AXIS
			and _kind_of(left.get(Bind.TRIGGER)) == Bind.Kind.FRAME_AXIS,
		"stick %s, trigger %s" % [left.get(Bind.STICK), left.get(Bind.TRIGGER)])

	# THE HIGHLIGHT, WALKED DOWN ONTO A CRAFT AND PRESSED.
	page.show_tab(ClipboardPage.Tab.CRAFT)
	await get_tree().process_frame
	var kinds: Array[String] = []
	for kind in range(Sim.Kind.size()):
		kinds.append(Sim.kind_name(kind))
	var landed: Control = null
	var flicks: int = 0
	while flicks < 40:
		await _flick(1, Bind.STICK, Vector2(0.0, -1.0))
		flicks += 1
		landed = page.highlighted()
		if landed is Button and kinds.has(String((landed as Button).text)):
			break
	var on_craft: bool = landed is Button and kinds.has(String((landed as Button).text))
	_check("pulling_the_free_stick_back_walks_the_highlight_onto_a_craft", on_craft,
		"after %d flick(s): %s" % [flicks, str(landed)])
	if on_craft:
		var wanted: int = kinds.find(String((landed as Button).text))
		var asked: Array = []
		var listen := func(kind: int): asked.append(kind)
		page.chose_kind.connect(listen)
		await _flick(1, Bind.TRIGGER, 1.0)
		page.chose_kind.disconnect(listen)
		_check("and_the_free_trigger_presses_what_is_highlighted", asked == [wanted],
			"asked for %s, highlighted %s" % [asked, Sim.kind_name(wanted)])
		await _flick(1, Bind.STICK, Vector2(0.0, -1.0))
		_check("and_the_next_flick_moves_it_on", page.highlighted() != landed
			and page.highlighted() != null, "now on %s" % [page.highlighted()])

	# THE TABS, by the click and by flicking sideways.
	var count: int = ClipboardPage.Tab.size()
	var before: int = page.tab()
	await _flick(1, Bind.STICK_CLICK, true)
	_check("and_clicking_the_stick_turns_to_the_next_tab", page.tab() == (before + 1) % count,
		"tab %d then %d" % [before, page.tab()])
	before = page.tab()
	await _flick(1, Bind.STICK, Vector2(1.0, 0.0))
	var right_went: int = page.tab()
	await _flick(1, Bind.STICK, Vector2(-1.0, 0.0))
	_check("and_flicking_it_right_and_left_turns_forward_and_back",
		right_went == (before + 1) % count and page.tab() == before,
		"tab %d, right to %d, left to %d" % [before, right_went, page.tab()])
	# AND ROUND EVERY ONE OF THEM IN ORDER, by the click alone. The tabs are two rows on the glass since AUDIO made eight
	# (2026-09-13), and to the thumb they are still one list that comes back to where it started.
	page.show_tab(ClipboardPage.Tab.CRAFT)
	var visited: PackedStringArray = []
	for i in range(count):
		await _flick(1, Bind.STICK_CLICK, true)
		visited.append(ClipboardPage.Tab.keys()[page.tab()])
	var in_order: PackedStringArray = []
	for i in range(count):
		in_order.append(ClipboardPage.Tab.keys()[(i + 1) % count])
	_check("and_clicking_it_round_visits_every_tab_in_order", visited == in_order,
		"visited %s" % [visited])
	page.show_tab(ClipboardPage.Tab.CRAFT)
	board.show_board(false)


## ---- the right hand's pointer ------------------------------------------------------------

## A POINTER OUT OF THE RIGHT HAND while the board is up: it reaches exactly to the glass, the trigger presses
## exactly what it is on, once, and the highlighted control is NOT pressed with it; off the glass the same pull
## presses the highlighted control, once.
##
## Through `force_hand` and `force_input`, the seams a headset's hand and trigger arrive by, so it is the rig's
## own `_point_a_hand` and `Clipboard.aim` deciding. The highlight is put on a DIFFERENT craft first, so
## a pull that pressed both would ask for two.
func _the_right_hand_points_at_the_board() -> void:
	if _rig == null or _rig.clipboard == null:
		return
	var board: Clipboard = _rig.clipboard
	var page: ClipboardPage = board.page()
	var panel: TouchPanel = board.panel()
	board.show_board(true)
	page.show_tab(ClipboardPage.Tab.CRAFT)
	await _frames(3)
	var kinds: Array[String] = []
	for kind in range(Sim.Kind.size()):
		kinds.append(Sim.kind_name(kind))
	var scroll := page.get("_scroll") as ScrollContainer
	var crafts: Array[Button] = []
	for node in page.find_children("*", "Button", true, false):
		var button := node as Button
		if (button.is_visible_in_tree() and kinds.has(String(button.text))
				and (scroll == null or scroll.get_global_rect().has_point(button.get_global_rect().get_center()))):
			crafts.append(button)
	_check("there_are_craft_buttons_to_point_at", crafts.size() >= 2, "%d on show" % crafts.size())
	if crafts.size() < 2:
		board.show_board(false)
		return
	var target: Button = crafts[0]
	var decoy: Button = crafts[1]
	decoy.grab_focus()
	var screen := panel.get("_screen") as SubViewport
	var centre: Vector2 = target.get_global_rect().get_center()
	var on_glass := Vector3((centre.x / float(screen.size.x) - 0.5) * panel.size.x,
		(0.5 - centre.y / float(screen.size.y)) * panel.size.y, 0.0)
	var aimed_at: Vector3 = panel.to_global(on_glass)
	var normal: Vector3 = panel.global_basis.z.normalized()
	var up: Vector3 = panel.global_basis.y.normalized()
	var hand_at: Vector3 = aimed_at + normal * 0.30
	_rig.force_hand(1, Transform3D(Basis.looking_at(aimed_at - hand_at, up), hand_at))
	await _frames(2)
	var beam := _rig.get("_beam") as MeshInstance3D
	_check("with_the_board_up_the_right_hand_has_a_beam", beam != null and beam.visible, "%s" % [beam])
	_check("and_aimed_at_the_board_it_is_on_the_glass", board.is_aimed(), "aimed %s" % board.is_aimed())
	_check("and_it_reaches_exactly_to_the_glass", beam != null and absf(beam.scale.z - 0.30) < 0.01,
		"length %s" % [beam.scale.z if beam != null else -1.0])
	var asked: Array = []
	var listen := func(kind: int): asked.append(kind)
	page.chose_kind.connect(listen)
	_rig.force_input(1, Bind.TRIGGER, 1.0)
	await _frames(2)
	_rig.force_input(1, Bind.TRIGGER, 0.0)
	await _frames(2)
	_rig.force_input(1, Bind.TRIGGER, null)
	page.chose_kind.disconnect(listen)
	var wanted: int = kinds.find(String(target.text))
	_check("and_the_trigger_presses_what_it_points_at_and_not_the_highlight", asked == [wanted],
		"asked for %s; aimed at %s, highlighted %s" % [asked, target.text, decoy.text])
	# AIMED AWAY FROM THE BOARD: off the glass, and the beam out to its own length.
	_rig.force_hand(1, Transform3D(Basis.looking_at(normal, up), hand_at))
	await _frames(2)
	_check("aimed_away_it_is_off_the_glass_and_the_beam_keeps_its_own_length",
		not board.is_aimed() and beam != null and beam.visible and absf(beam.scale.z - PilotRig.BEAM_REACH) < 0.001,
		"aimed %s, length %s" % [board.is_aimed(), beam.scale.z if beam != null else -1.0])
	# AND OFF THE GLASS THE SAME PULL PRESSES THE HIGHLIGHT, ONCE. Held for two frames like the pull on the glass,
	# so a trigger read as a level rather than an edge would ask twice, and a beam that swallowed the press would
	# ask for nothing.
	decoy.grab_focus()
	asked.clear()
	page.chose_kind.connect(listen)
	_rig.force_input(1, Bind.TRIGGER, 1.0)
	await _frames(2)
	_rig.force_input(1, Bind.TRIGGER, 0.0)
	await _frames(2)
	_rig.force_input(1, Bind.TRIGGER, null)
	page.chose_kind.disconnect(listen)
	var highlighted: int = kinds.find(String(decoy.text))
	_check("and_off_the_glass_one_pull_presses_the_highlight_exactly_once", asked == [highlighted],
		"asked for %s; highlighted %s, beam on the glass %s" % [asked, decoy.text, board.is_aimed()])
	board.show_board(false)
	await _frames(2)
	_check("and_with_the_board_away_there_is_no_beam", beam != null and not beam.visible,
		"visible %s" % [beam.visible if beam != null else null])
	_rig.force_hand(1, null)
	page.show_tab(ClipboardPage.Tab.CRAFT)


## ---- the head, put back ----------------------------------------------------------------------

## RESET HEAD PUTS THE HEAD BACK, pressed on the board with the right hand's beam.
##
## Asked for on 2026-09-13: "a ipad command for resetting the head position like the 'r' key on the keyboard". The
## board announces `chose_recentre` and the rig answers with `recentre`, the call R already makes -- so this presses the
## button through `force_hand` and `force_input`, the seams a headset's hand and trigger arrive by, and asks the rig.
##
## THE LOOK IS TURNED AWAY FIRST by writing what a mouse drag writes (`_look_yaw`, `_look_pitch`): a headless rig has no
## pointer to capture, and the press, not the drag, is what is under test here. Then the press, and a frame for the rig
## to place its head: the look is zero again, and the desk camera -- which `_place_desktop_rig` points from the look on
## every physics tick -- faces straight along the seat.
func _the_board_puts_the_head_back() -> void:
	if _rig == null or _rig.clipboard == null:
		return
	var board: Clipboard = _rig.clipboard
	var page: ClipboardPage = board.page()
	board.show_board(true)
	page.show_tab(ClipboardPage.Tab.CRAFT)
	await _frames(3)
	var reset: Button = null
	for node in page.find_children("*", "Button", true, false):
		if (node as Button).is_visible_in_tree() and (node as Button).text == "RESET HEAD":
			reset = node as Button
	_check("the_board_has_a_reset_head_button", reset != null, "on the CRAFT tab")
	if reset == null:
		board.show_board(false)
		return
	_rig.set("_look_yaw", 0.9)
	_rig.set("_look_pitch", -0.4)
	await _frames(2)
	var camera: Camera3D = _rig.desktop_camera
	var turned: bool = not camera.rotation.is_zero_approx()
	await _beam_presses(_rig, reset)
	await _frames(2)
	var yaw: float = float(_rig.get("_look_yaw"))
	var pitch: float = float(_rig.get("_look_pitch"))
	_check("and_the_beam_on_it_puts_the_head_back_in_the_seat",
		turned and is_zero_approx(yaw) and is_zero_approx(pitch) and camera.rotation.is_zero_approx(),
		"turned away first %s; look now yaw %.3f pitch %.3f, camera %s" % [turned, yaw, pitch, camera.rotation])
	board.show_board(false)
	await _frames(2)


## ---- the HUD, up and away ---------------------------------------------------------------------

## THE HUD STARTS DOWN, AND THE HUD SWITCH ON THE BOARD PUTS IT UP AND AWAY. Asked for on 2026-09-14: "turn off the hud
## that shows up connected to the head (we need a toggle in the ipad to turn it back on)".
##
## Down is hidden AND unwritten, so both are asked: `hud.visible`, and `PilotRig.hud_writes` over physics frames, the clock
## `_update_hud` runs on. Pressed with the right hand's beam and trigger, as a player presses it.
func _the_hud_switch_puts_the_hud_up_and_away() -> void:
	if _rig == null or _rig.clipboard == null:
		return
	var board: Clipboard = _rig.clipboard
	var page: ClipboardPage = board.page()
	board.show_board(true)
	page.show_tab(ClipboardPage.Tab.CRAFT)
	await _frames(3)
	var hud: VehicleHud = _rig.hud
	var switch: CheckButton = _switch_reading(page, "HUD")
	var writes: int = _rig.hud_writes
	await _physics_frames(6)
	_check("the_hud_starts_down_and_unwritten_with_its_switch_off",
		hud != null and not hud.visible and not _rig.hud_is_on() and _rig.hud_writes == writes
			and switch != null and switch.is_visible_in_tree() and not switch.button_pressed,
		"HUD visible %s, written %d times in 6 ticks, switch %s" % [hud.visible if hud != null else null,
			_rig.hud_writes - writes, "missing" if switch == null else ("on" if switch.button_pressed else "off")])
	if hud == null or switch == null:
		board.show_board(false)
		return
	await _beam_presses(_rig, switch)
	writes = _rig.hud_writes
	await _physics_frames(6)
	_check("and_the_beam_on_hud_puts_it_up_and_it_is_written",
		hud.visible and _rig.hud_is_on() and switch.button_pressed and _rig.hud_writes > writes,
		"HUD visible %s, written %d times in 6 ticks, switch on %s" % [hud.visible, _rig.hud_writes - writes,
			switch.button_pressed])
	await _beam_presses(_rig, switch)
	await _physics_frames(1)
	writes = _rig.hud_writes
	await _physics_frames(6)
	_check("and_the_beam_on_it_again_puts_it_away_and_it_is_not_written",
		not hud.visible and not _rig.hud_is_on() and not switch.button_pressed and _rig.hud_writes == writes,
		"HUD visible %s, written %d times in 6 ticks, switch on %s" % [hud.visible, _rig.hud_writes - writes,
			switch.button_pressed])
	board.show_board(false)
	await _frames(2)


## LEVEL HORIZON IN SMALL BOATS, FROM THE BEAM ON ITS SWITCH. The wind-sea (C1, 2026-09-15) rolls a launch and a patrol
## boat, and a seated player may choose not to see it. A rig sits in a launch rolled 9 degrees and pitched 4 on a heading
## of 35: with the switch off, which is how it starts, the rig leans with the boat; the right hand's beam on the switch
## on FEEL levels it and keeps its heading; and in a carrier the same choice leaves the rig on the deck's lean, since
## the big ships lean under two degrees.
func _small_boats_keep_the_horizon_level() -> void:
	var boat := VehicleView.new()
	boat.kind = Sim.Kind.BOAT
	# ITS OWN HULL, which every craft scene authors and `VehicleView` takes on ready: without it the bare view
	# printed an engine error, and run_all fails a suite that prints one.
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	boat.add_child(hull)
	add_child(boat)
	var anchor := Node3D.new()
	anchor.position = Vector3(0.3, 1.1, -0.5)
	boat.add_child(anchor)
	boat.basis = Basis.from_euler(Vector3(deg_to_rad(4.0), deg_to_rad(35.0), deg_to_rad(9.0)))
	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	rig.sit_in(anchor)
	var board: Clipboard = rig.clipboard
	var page: ClipboardPage = board.page() if board != null else null
	if page == null:
		_check("level_horizon_has_a_board", false, "no clipboard page")
		rig.queue_free()
		boat.queue_free()
		return
	board.show_board(true)
	page.show_tab(ClipboardPage.Tab.FEEL)
	await _frames(3)
	var switch: CheckButton = _switch_reading(page, "LEVEL HORIZON IN SMALL BOATS")
	var lean: float = rad_to_deg(rig.global_basis.y.normalized().angle_to(Vector3.UP))
	_check("level_horizon_starts_off_and_the_rig_leans_with_the_launch",
		switch != null and switch.is_visible_in_tree() and not switch.button_pressed and not rig.levels_the_horizon()
			and rig.is_seated() and lean > 8.0,
		"switch %s, rig leans %.2f deg in a launch leaning %.2f" % ["missing" if switch == null else ("on" if switch.button_pressed
			else "off"), lean, rad_to_deg(anchor.global_basis.y.angle_to(Vector3.UP))])
	if switch == null:
		board.show_board(false)
		rig.queue_free()
		boat.queue_free()
		return
	await _beam_presses(rig, switch)
	await _frames(2)
	lean = rad_to_deg(rig.global_basis.y.normalized().angle_to(Vector3.UP))
	var ahead := Vector3(-rig.global_basis.z.x, 0.0, -rig.global_basis.z.z)
	var bow := Vector3(-anchor.global_basis.z.x, 0.0, -anchor.global_basis.z.z)
	var turned: float = rad_to_deg(ahead.angle_to(bow))
	_check("and_the_beam_on_it_levels_the_rig_in_the_launch_on_the_launch_heading",
		switch.button_pressed and rig.levels_the_horizon() and lean < 0.05 and turned < 0.05,
		"switch on %s, rig leans %.3f deg and looks %.3f deg off the bow" % [switch.button_pressed, lean, turned])
	boat.kind = Sim.Kind.CARRIER
	await _frames(2)
	lean = rad_to_deg(rig.global_basis.y.normalized().angle_to(Vector3.UP))
	_check("and_in_a_carrier_the_rig_keeps_the_deck_lean", rig.levels_the_horizon() and lean > 8.0,
		"rig leans %.2f deg" % lean)
	board.show_board(false)
	rig.queue_free()
	boat.queue_free()
	await _frames(2)


func _physics_frames(how_many: int) -> void:
	for i in range(how_many):
		await get_tree().physics_frame


## ---- the tabs, and what the pilot hears ----------------------------------------------------

## EVERY TAB WHOLE ON THE GLASS, AT THE SIZE IT HAD. "Make sure that the top tabs on the iPad are wrapped correctly"
## (2026-09-13): eight tabs since AUDIO, and one row of eight at the size a beam can hit is wider than the page. Each tab's
## rectangle lies inside the page's own viewport, is at least `ClipboardPage.TAB_TALL` tall, is worded at
## `ClipboardPage.TAB_WORDS` and is wider than its word -- so the fit is not bought by shrinking what you press. The two
## were 46 and 22, typed here, until the user asked for the tabs "a little smaller (4 across)" on 2026-09-18; the floor
## they may not go under is the smallest target the board has, 38 (`and_no_tab_is_a_smaller_target`). Then
## the right hand's beam on AUDIO, which is how a player finds the page, turns to it.
func _every_tab_is_whole_on_the_glass() -> void:
	if _rig == null or _rig.clipboard == null:
		return
	var board: Clipboard = _rig.clipboard
	var page: ClipboardPage = board.page()
	board.show_board(true)
	page.show_tab(ClipboardPage.Tab.CRAFT)
	await _frames(3)
	var screen := board.panel().get("_screen") as SubViewport
	var glass := Rect2(Vector2.ZERO, Vector2(screen.size))
	var tabs: Array = page.get("_tabs")
	var wrong: PackedStringArray = []
	for tab in tabs:
		var button := tab as Button
		var rect: Rect2 = button.get_global_rect()
		var size: int = button.get_theme_font_size("font_size")
		var words: float = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			size).x
		if not glass.encloses(rect):
			wrong.append("%s at %s, past the glass %s" % [button.text, rect, glass])
		if rect.size.y < BoardStyle.reach(ClipboardPage.TAB_TALL) - 0.5 or size != BoardStyle.pressed_text(ClipboardPage.TAB_WORDS):
			wrong.append("%s %.0f px tall worded at %d" % [button.text, rect.size.y, size])
		if words > rect.size.x:
			wrong.append("%s's word %.0f px in %.0f" % [button.text, words, rect.size.x])
	_check("every_tab_lies_whole_on_the_glass_at_its_own_size", tabs.size() == ClipboardPage.Tab.size() and wrong.is_empty(),
		"%d tabs, least %.0f x %.0f px%s" % [tabs.size(), _narrowest(tabs), BoardStyle.reach(ClipboardPage.TAB_TALL),
			"" if wrong.is_empty() else ": " + "; ".join(wrong)])
	_check("and_no_tab_is_a_smaller_target_than_anything_else_on_the_board", ClipboardPage.TAB_TALL >= SMALLEST_TARGET,
		"tabs %.0f, the parts bin's buttons %.0f" % [ClipboardPage.TAB_TALL, SMALLEST_TARGET])
	if tabs.size() == ClipboardPage.Tab.size():
		var audio := tabs[ClipboardPage.Tab.AUDIO] as Button
		var shown := page.get("_audio_page") as Control
		# HIDDEN ON CRAFT FIRST, or a page left showing on every tab passes for the beam having turned to it -- which is
		# what this check did before it asked (2026-09-13).
		var hidden_before: bool = shown != null and not shown.is_visible_in_tree()
		await _beam_presses(_rig, audio)
		_check("and_the_beam_on_audio_turns_to_the_audio_page", hidden_before and page.tab() == ClipboardPage.Tab.AUDIO
			and shown.is_visible_in_tree(), "hidden on CRAFT %s; tab %s, page shown %s" % [hidden_before,
				ClipboardPage.Tab.keys()[page.tab()], shown.is_visible_in_tree() if shown != null else null])
	page.show_tab(ClipboardPage.Tab.CRAFT)
	board.show_board(false)
	await _frames(2)


## THE SMALLEST THING THE BOARD ASKS A FINGER TO HIT, before `BoardStyle.reach`: the parts bin's buttons, "38 px of
## reach is what a fingertip in mid-air needs" (ClipboardPage's note on BUILD).
const SMALLEST_TARGET: float = 38.0
## MORE CRAFT THAN THE CREW PAGE HOLDS, on the board as big as it is. See the thumb check.
const MORE_CRAFT_THAN_FIT: int = 20


static func _narrowest(tabs: Array) -> float:
	var least: float = INF
	for tab in tabs:
		least = minf(least, (tab as Control).size.x)
	return least


## THE AUDIO TAB, WORKED WITH THE BEAM. Both switches start off and the game bus is muted; the trigger on GAME SOUND
## unmutes the game bus and leaves the radio's exactly as it was, and a second pull mutes it again; the trigger on VOICE
## with nothing to load springs the switch back off with the reason under it.
##
## Through `_beam_presses`, the pull RESET HEAD is pressed with, so it is the rig's wiring to `Headphones` deciding what a
## flick means and the headphones deciding what the switch shows -- not a call made on either's behalf. "Nothing to load"
## is `KOKORO_MODELS` pointed at an empty folder, which is where the headphones then look; on a machine with no library
## the reason is that instead, and the check takes either sentence.
func _the_right_hand_works_the_audio_tab() -> void:
	if _rig == null or _rig.clipboard == null:
		return
	var board: Clipboard = _rig.clipboard
	var page: ClipboardPage = board.page()
	board.show_board(true)
	page.show_tab(ClipboardPage.Tab.AUDIO)
	await _frames(3)
	var game_sound := page.get("_game_sound") as CheckButton
	var voice := page.get("_voice") as CheckButton
	var voice_said := page.get("_voice_said") as Label
	var game: int = AudioServer.get_bus_index(PilotHeadphones.GAME_BUS)
	var radio: int = AudioServer.get_bus_index(PilotHeadphones.RADIO_BUS)
	_check("the_audio_tab_starts_with_both_switches_off", game_sound != null and voice != null
		and not game_sound.button_pressed and not voice.button_pressed and game > 0 and AudioServer.is_bus_mute(game),
		"game sound %s, voice %s, game bus %d muted %s" % [game_sound.button_pressed if game_sound != null else null,
			voice.button_pressed if voice != null else null, game, AudioServer.is_bus_mute(game) if game > 0 else null])
	if game_sound == null or voice == null or game <= 0 or radio <= 0:
		board.show_board(false)
		return
	var radio_was: Array = [AudioServer.is_bus_mute(radio), AudioServer.get_bus_volume_db(radio)]

	await _beam_presses(_rig, game_sound)
	_check("the_trigger_on_game_sound_unmutes_the_game_bus", game_sound.button_pressed and Headphones.game_sound
		and not AudioServer.is_bus_mute(game), "switch %s, headphones %s, game bus muted %s"
			% [game_sound.button_pressed, Headphones.game_sound, AudioServer.is_bus_mute(game)])
	_check("and_leaves_the_radio_bus_as_it_was",
		[AudioServer.is_bus_mute(radio), AudioServer.get_bus_volume_db(radio)] == radio_was,
		"radio bus muted %s at %.1f dB" % [AudioServer.is_bus_mute(radio), AudioServer.get_bus_volume_db(radio)])
	await _beam_presses(_rig, game_sound)
	_check("and_a_second_pull_mutes_it_again", not game_sound.button_pressed and not Headphones.game_sound
		and AudioServer.is_bus_mute(game), "switch %s, game bus muted %s" % [game_sound.button_pressed,
			AudioServer.is_bus_mute(game)])

	OS.set_environment(PilotHeadphones.MODELS_VARIABLE, ProjectSettings.globalize_path("user://no_voice_model_here"))
	await _beam_presses(_rig, voice)
	OS.unset_environment(PilotHeadphones.MODELS_VARIABLE)
	var reason: String = voice_said.text if voice_said != null else ""
	_check("the_trigger_on_voice_with_nothing_to_load_springs_back_and_says_why",
		not voice.button_pressed and not Headphones.voice_on() and voice_said != null and voice_said.is_visible_in_tree()
			and (reason.begins_with("No voice model at") or reason.begins_with("No voice library")),
		"switch %s, headphones %s, said '%s'" % [voice.button_pressed, Headphones.voice_on(), reason])

	board.show_board(false)
	await _frames(2)
	page.show_tab(ClipboardPage.Tab.CRAFT)


## ---- clear of the hand holding it ---------------------------------------------------------

## HOW FAR IN FRONT OF THE GLASS THE EYE IS, looking straight at it, in metres: a board held a forearm out.
const EYE_FROM_GLASS: float = 0.40
## HOW FAR THE CONTROLLER'S OUTLINE MUST STAY OFF THE GLASS, in metres, seen from there. The bezel may be covered.
const GLASS_CLEAR: float = 0.01


## THE CONTROLLER DOES NOT COVER THE GLASS. "The iPad should be raised a couple units. Right now the controller is
## blocking the bottom part of it" (2026-09-13).
##
## Judged as the eye sees it, not as a gap in the hand's frame: a line of sight comes in at an angle, and the button
## labels float above the controller and are drawn over everything, the board included. So BUTTON LABELS is on and the
## board is up, which is when the rig writes them, and `controller_clear_of_the_glass` measures what an eye straight in
## front of the glass would see. RED at the old offset, before the board was moved.
func _the_board_is_not_behind_the_controller() -> void:
	if _rig == null or _rig.clipboard == null:
		return
	var board: Clipboard = _rig.clipboard
	_rig.label_the_buttons(true)
	board.show_board(true)
	await _frames(4)
	var seen: Dictionary = controller_clear_of_the_glass(_rig)
	_check("the_controller_holding_the_board_does_not_cover_its_glass",
		int(seen["labels"]) > 0 and float(seen["clear"]) >= GLASS_CLEAR - 0.0005,
		"nearest is %s, %.1f cm off the glass (at least %.0f wanted; negative is over it), %d parts and %d labels seen, board at %s"
			% [seen["nearest"], float(seen["clear"]) * 100.0, GLASS_CLEAR * 100.0, seen["parts"], seen["labels"], Clipboard.AT])
	board.show_board(false)
	await _frames(2)


## HOW FAR THE CONTROLLER IN THE HAND HOLDING `rig`'s BOARD STAYS OFF THE GLASS, seen from `EYE_FROM_GLASS` straight in front
## of the glass's middle: every mesh of the `ControllerModel` and every label it is showing, each one's box projected
## through that eye onto the glass's plane, and the least distance from any of them to the glass rectangle -- negative
## when one is over it. Worked in the glass's own frame, so the pose of the arm does not enter into it, and read off the
## nodes the rig built, so nothing about the offset or the controller's size is typed here. STATIC, so a probe can move
## the glass about and ask it again.
static func controller_clear_of_the_glass(rig: PilotRig) -> Dictionary:
	var panel: TouchPanel = rig.clipboard.panel()
	var model: ControllerModel = rig.controller_model(ClipboardPage.HOLDING_HAND)
	var half: Vector2 = panel.size * 0.5
	var into_glass: Transform3D = panel.global_transform.affine_inverse()
	var least: float = INF
	var nearest: String = "nothing"
	var parts: int = 0
	var labels: int = 0
	if model == null:
		return {"clear": -INF, "nearest": "no controller", "parts": 0, "labels": 0}
	for node in model.find_children("*", "GeometryInstance3D", true, false):
		var shape := node as GeometryInstance3D
		if not shape.visible:
			continue
		var box: AABB = shape.get_aabb()
		if box.size == Vector3.ZERO:
			continue
		if shape is Label3D:
			labels += 1
		else:
			parts += 1
		var to_glass: Transform3D = into_glass * shape.global_transform
		var seen := Rect2()
		var first: bool = true
		for i in range(8):
			var at: Vector3 = to_glass * box.get_endpoint(i)
			if at.z >= EYE_FROM_GLASS - 0.001:
				continue
			var on_glass := Vector2(at.x, at.y) * (EYE_FROM_GLASS / (EYE_FROM_GLASS - at.z))
			seen = Rect2(on_glass, Vector2.ZERO) if first else seen.expand(on_glass)
			first = false
		if first:
			continue
		var dx: float = maxf(seen.position.x - half.x, -half.x - seen.end.x)
		var dy: float = maxf(seen.position.y - half.y, -half.y - seen.end.y)
		var clear: float = sqrt(dx * dx + dy * dy) if dx > 0.0 and dy > 0.0 else maxf(dx, dy)
		if clear < least:
			least = clear
			nearest = String(shape.name)
	return {"clear": least, "nearest": nearest, "parts": parts, "labels": labels}


## ONE PULL OF THE RIGHT TRIGGER with the right hand's beam on `target`: at rest, down, up again, the hand re-posed on the
## glass every frame. The same pull tests/scenery.gd gives the TIME tab.
func _beam_presses(rig: PilotRig, target: Control) -> void:
	# WHERE THE TARGET IS, TAKEN ONCE: a press can rebuild the page under the beam -- a JOIN does, to say it is asking --
	# and the button it pressed is then freed while the trigger is still coming back up.
	var centre: Vector2 = target.get_global_rect().get_center()
	for trigger in [0.0, 0.0, 1.0, 1.0, 0.0, 0.0]:
		var panel: TouchPanel = rig.clipboard.panel()
		var screen := panel.get("_screen") as SubViewport
		var on_glass := Vector3((centre.x / float(screen.size.x) - 0.5) * panel.size.x,
			(0.5 - centre.y / float(screen.size.y)) * panel.size.y, 0.0)
		var aimed_at: Vector3 = panel.to_global(on_glass)
		var hand_at: Vector3 = aimed_at + panel.global_basis.z.normalized() * 0.30
		rig.force_hand(1, Transform3D(Basis.looking_at(aimed_at - hand_at, panel.global_basis.y.normalized()), hand_at))
		rig.force_input(1, Bind.TRIGGER, trigger)
		await get_tree().process_frame
	rig.force_input(1, Bind.TRIGGER, null)
	rig.force_hand(1, null)
	await get_tree().process_frame


## ---- a hand that takes hold puts the board away -------------------------------------------

## GRAB WITH THE BOARD UP AND THE BOARD GOES, and the hand's fingers belong to what it took.
##
## Through the rig's own grab -- `force_hand` and `force_grip`, the seams `tests/feel.gd` uses
## -- so it is the nearest-control choice, the latch and the one-hand-one-control rule deciding
## that the hand has hold, and not a call made on the control's behalf. Both hands, because the
## one holding the board is a hand that can let go of it.
func _a_hand_that_takes_hold_puts_the_board_away() -> void:
	for hand in range(2):
		var side: String = "left" if hand == 0 else "right"
		var kit: Dictionary = await _a_rig_at_a_console(hand)
		var rig: PilotRig = kit["rig"]
		var dial: DetentDial = kit["dial"]
		rig.clipboard.show_board(true)
		await _frames(2)
		_check("with_the_board_up_the_%s_thumb_scrolls_it" % side,
			_local_of(rig._bindings_for(hand).get(Bind.THUMB_HIGH)) == Bind.Local.SCROLL_UP,
			"%s" % [rig._bindings_for(hand).get(Bind.THUMB_HIGH)])

		rig.force_hand(hand, dial.global_transform
			* Transform3D(Basis.IDENTITY, dial._grab_point()))
		# PINCHED, because a selector is: see `DetentDial.taken_by`. A fist on one has done
		# nothing since 2026-09-15, and the point of the section is a hand that DOES take hold.
		rig.force_input(hand, Bind.TRIGGER, 1.0)
		await _frames(3)
		_check("the_%s_hand_takes_hold_of_the_control" % side,
			dial.is_held() and dial.held_by == hand, "held %s by %d" % [dial.is_held(), dial.held_by])
		_check("and_that_puts_the_board_away", not rig.clipboard.is_up(),
			"up %s" % rig.clipboard.is_up())
		# AND EVERY FINGER NOW READS THE CONTROL'S TABLE OVER THE EMPTY HAND'S -- which is what
		# the hand would work from had the board never been up. Nothing of the board is left.
		var table: Dictionary = rig._bindings_for(hand)
		var own: Dictionary = dial.bindings()
		var empty: Dictionary = rig._global_bindings(hand)
		var strays: Array = []
		for input in Bind.inputs():
			var expected: Variant = own.get(input, empty.get(input))
			# EXCEPT THE FINGER THAT IS HOLDING IT. A pinched control takes its own trigger
			# away while it is in the hand, so the same finger is not also braking -- the rule
			# `Bind` already states about the grip. See `PilotRig._bindings_for`.
			if input == Bind.TRIGGER and dial.taken_by() == Bind.Take.PINCH:
				expected = Bind.nothing()
			if table.get(input) != expected:
				strays.append(Bind.input_name(input))
		_check("and_its_fingers_work_the_control_and_not_the_board", strays.is_empty(),
			"%s" % ["every finger" if strays.is_empty() else "still wrong: %s" % [strays]])
		rig.force_input(hand, Bind.TRIGGER, null)
		(kit["rig"] as Node).queue_free()
		(kit["plinth"] as Node).queue_free()
		await _frames(2)


## A RIG AT A STATION WITH A DIAL ON IT, and the other hand parked well away. The arrangement
## `tests/feel.gd` builds, for the reason it gives: a station on a plinth and `take_station` is
## what the hall of cockpits does, so it is the game's own layout rather than a fixture.
func _a_rig_at_a_console(hand: int) -> Dictionary:
	var plinth := Node3D.new()
	add_child(plinth)
	var station := VehicleCatalogue.seat_scene(Sim.Kind.PLANE).instantiate() as CockpitStation
	plinth.add_child(station)
	station.fit(0, true, Sim.Kind.PLANE, false)
	var dial := DetentDial.new()
	dial.name = "Selector"
	# WELL CLEAR OF THE CONSOLE, so the nearest control to the hand is this one.
	dial.position = Vector3(0.62, 0.0, 0.0)
	station.add_child(dial)
	dial.setup(0)
	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	rig.take_station(station)
	var other: int = 1 - hand
	rig.force_grip(other, 0.0)
	rig.force_hand(other, Transform3D(Basis.IDENTITY, Vector3(0.0, -40.0, 0.0)))
	rig.force_grip(hand, 0.0)
	await _frames(2)
	return {"rig": rig, "station": station, "dial": dial, "plinth": plinth}


## ONE PRESS OF ONE FINGER on the rig under test: down for a frame, back to rest for a frame,
## then the seam let go -- the same down-then-up a real finger makes, so the edge is a real one.
func _flick(hand: int, input: int, down: Variant) -> void:
	_rig.force_input(hand, input, down)
	_rig.read_controls()
	var rest: Variant = Vector2.ZERO if down is Vector2 else (false if down is bool else 0.0)
	_rig.force_input(hand, input, rest)
	_rig.read_controls()
	_rig.force_input(hand, input, null)
	await get_tree().process_frame


func _frames(how_many: int) -> void:
	for i in range(how_many):
		await get_tree().process_frame


## The kind of an action, or of the first of a list of them.
static func _kind_of(action: Variant) -> int:
	if action is Array:
		action = (action as Array)[0] if not (action as Array).is_empty() else null
	return int((action as Dictionary).get("kind", -1)) if action is Dictionary else -1


## Which local thing an action asks for, or -1 for anything that is not local.
static func _local_of(action: Variant) -> int:
	if _kind_of(action) != Bind.Kind.LOCAL:
		return -1
	return int((action as Dictionary).get("what", -1))


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
