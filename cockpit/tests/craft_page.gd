extends Node
## Headless: the CRAFT page offers every kind a player may take, in groups, and still does at sixty-four kinds.
##
##   Godot --headless --xr-mode off --fixed-fps 120 --path cockpit res://tests/craft_page.tscn
##
## THE USER, 2026-09-18: "i'd like to have lots of vehicle kinds". A kind is sixteen bits now (tests/many_kinds.gd), and
## the next limit was the clipboard: twenty-eight buttons in one grid filled most of the board. The page now has a bar of
## groups by how a kind moves -- aeroplanes, helicopters, ships, ground (`VehicleCatalogue.group`) -- and shows one
## group's craft at a time (`ClipboardPage.show_kinds`).
##
## WHAT IS REAL HERE. A `Clipboard`, the board a player holds, built whole with its glass and its page, and every press
## a press of the page's own Button: a group in the bar, then a craft, and what the page ANNOUNCES (`chose_kind`) is
## what is checked -- not the labels, which a button named one thing and wired to another would pass. Sixty-four kinds
## are handed to the page as a level hands it data, since the game has twenty-nine; the extra ones carry numbers no
## build has (100 and up), which the page neither knows nor needs to.
##
## WHAT IT HOLDS, each checked:
##   * every movement model the simulation has goes in a named group, and the bar has exactly the groups there are;
##   * each group's button shows that group's craft and hides the rest, and pressing each craft asks for that kind;
##   * every kind a player may take is in exactly one group;
##   * at sixty-four kinds every group's every craft is reachable -- on the page, or by scrolling a page that says it
##     scrolls -- and pressing the last one of each asks for it; and how many fit before scrolling, printed.
##
## Read RESULT=, not the exit code.

## HOW MANY KINDS THE STRESS HANDS THE PAGE, as the lead asked: "so 60+ kinds fit".
const MANY: int = 64
## Where the invented kinds' numbers start: past anything this build has, inside sixteen bits.
const FIRST_INVENTED: int = 100

var _failures: PackedStringArray = []
var _board: Clipboard = null
var _page: ClipboardPage = null
var _asked: Array[int] = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[craft_page] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_board = Clipboard.new()
	add_child(_board)
	await _frames(2)
	_board.show_board(true)
	await _frames(2)
	_page = _board.page()
	_check("the_board_has_a_page", _page != null, str(_page))
	if _page == null:
		_finish()
		return
	_page.chose_kind.connect(func(kind: int): _asked.append(kind))
	_page.show_tab(ClipboardPage.Tab.CRAFT)
	await _frames(4)
	_every_model_has_a_group()
	await _each_group_shows_its_own_craft_and_each_asks_for_its_kind(VehicleCatalogue.craft_rows(), "the_games")
	await _sixty_four_kinds_are_all_reachable()
	_page.show_kinds(VehicleCatalogue.craft_rows())
	_finish()


## EVERY MOVEMENT MODEL THE SIMULATION NAMES IS IN `GROUP_OF_MODEL`, asked of every kind there is -- a model nobody
## grouped would put its craft in the last group without a word.
func _every_model_has_a_group() -> void:
	var ungrouped: PackedStringArray = []
	for kind in range(Sim.Kind.size()):
		var model: String = String(Sim.geometry_of(kind).get("model_name", ""))
		if not VehicleCatalogue.GROUP_OF_MODEL.has(model):
			ungrouped.append("%s (%s)" % [Sim.kind_name(kind), model])
	_check("every_movement_model_has_a_group", ungrouped.is_empty(),
		"%d kinds" % Sim.Kind.size() if ungrouped.is_empty() else ", ".join(ungrouped))


## PRESS EACH GROUP, THEN EACH CRAFT IT SHOWS. What shows is that group's rows and nothing else, and each press asks
## for its row's kind. Every row is pressed once across the groups, so every kind is in exactly one.
func _each_group_shows_its_own_craft_and_each_asks_for_its_kind(rows: Array[Dictionary], whose: String) -> void:
	var wanted_groups: Array[String] = []
	for group in VehicleCatalogue.GROUPS:
		if rows.any(func(row: Dictionary) -> bool: return row["group"] == group):
			wanted_groups.append(group)
	var bar: Array[Button] = _bar()
	var bar_groups: Array[String] = []
	for tab in bar:
		bar_groups.append(String(tab.get_meta("group")))
	_check("the_bar_has_a_button_for_each_group_of_%s_kinds" % whose, bar_groups == wanted_groups,
		"bar %s, groups %s" % [bar_groups, wanted_groups])
	var wrong: PackedStringArray = []
	var asked_all: Array[int] = []
	for tab in bar:
		var group: String = String(tab.get_meta("group"))
		tab.pressed.emit()
		await _frames(2)
		var showing: Array[Button] = _crafts_on_show()
		var expected: Array = rows.filter(func(row: Dictionary) -> bool: return row["group"] == group).map(
			func(row: Dictionary) -> int: return int(row["kind"]))
		if _page.craft_group() != group or not tab.button_pressed or showing.size() != expected.size():
			wrong.append("%s: page on %s, lit %s, %d showing of %d" % [group, _page.craft_group(), tab.button_pressed,
				showing.size(), expected.size()])
		for pick in showing:
			_asked.clear()
			pick.pressed.emit()
			if _asked.size() != 1 or not expected.has(_asked[0]):
				wrong.append("%s '%s' asked for %s" % [group, pick.text, _asked])
			else:
				asked_all.append(_asked[0])
	_check("each_group_shows_its_own_craft_and_each_press_asks_for_its_kind", wrong.is_empty(),
		"%d groups" % bar.size() if wrong.is_empty() else "; ".join(wrong.slice(0, 6)))
	var every: Array = rows.map(func(row: Dictionary) -> int: return int(row["kind"]))
	asked_all.sort()
	every.sort()
	_check("every_one_of_%s_%d_kinds_is_asked_for_exactly_once" % [whose, rows.size()],
		asked_all == every, "%d asked, %d offered" % [asked_all.size(), every.size()])


## SIXTY-FOUR KINDS: the game's, and invented ones dealt round the groups. Every group's craft all reachable and all
## pressed; the page scrolls only where the page says it may; and what fits before it does, printed.
func _sixty_four_kinds_are_all_reachable() -> void:
	var rows: Array[Dictionary] = VehicleCatalogue.craft_rows()
	var number: int = FIRST_INVENTED
	while rows.size() < MANY:
		var group: String = VehicleCatalogue.GROUPS[rows.size() % VehicleCatalogue.GROUPS.size()]
		rows.append({"kind": number, "name": "%s %d" % [group.trim_suffix("s"), number], "group": group})
		number += 1
	_page.show_kinds(rows)
	await _frames(4)
	await _each_group_shows_its_own_craft_and_each_asks_for_its_kind(rows, "sixty_four")
	var scroll := _page.get("_scroll") as ScrollContainer
	var unreachable: PackedStringArray = []
	var report: PackedStringArray = []
	var scrolled_groups: int = 0
	for tab in _bar():
		tab.pressed.emit()
		await _frames(3)
		var showing: Array[Button] = _crafts_on_show()
		var inside := scroll.get_child(0) as Control
		var content: float = inside.get_combined_minimum_size().y
		var scrolls: bool = content > scroll.size.y + 0.5
		scrolled_groups += 1 if scrolls else 0
		if scrolls and not ClipboardPage.MAY_SCROLL.has(ClipboardPage.Tab.CRAFT):
			unreachable.append("%s is %.0f px in %.0f and CRAFT does not scroll" % [tab.text, content, scroll.size.y])
		# THE LAST CRAFT, scrolled to by the thumb's own half-page steps, is on the glass and asks for its kind.
		var last: Button = showing.back() if not showing.is_empty() else null
		for i in range(40):
			if last == null or scroll.get_global_rect().encloses(last.get_global_rect()):
				break
			_page.scroll(1)
			await _frames(1)
		if last == null or not scroll.get_global_rect().encloses(last.get_global_rect()):
			unreachable.append("%s's last craft '%s' never came onto the page" % [tab.text, last.text if last else "-"])
		report.append("%s %d craft in %.0f px of %.0f%s" % [String(tab.text).to_lower(), showing.size(), content,
			scroll.size.y, ", scrolls" if scrolls else ""])
	print("[craft_page] sixty-four kinds: " + "; ".join(report))
	_check("at_sixty_four_kinds_every_craft_in_every_group_can_be_reached", unreachable.is_empty(),
		"; ".join(report) if unreachable.is_empty() else "; ".join(unreachable))
	_check("and_at_sixty_four_no_group_needs_scrolling", scrolled_groups == 0,
		"%d of %d groups scroll" % [scrolled_groups, _bar().size()])


func _bar() -> Array[Button]:
	var out: Array[Button] = []
	for node in (_page.get("_craft_bar") as Node).get_children():
		if not (node as Node).is_queued_for_deletion():
			out.append(node as Button)
	return out


func _crafts_on_show() -> Array[Button]:
	var out: Array[Button] = []
	for node in (_page.get("_craft_grid") as Node).get_children():
		if (node as Control).is_visible_in_tree() and not (node as Node).is_queued_for_deletion():
			out.append(node as Button)
	return out


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	if _board != null:
		_board.show_board(false)
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
