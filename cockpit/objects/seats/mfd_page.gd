extends CraftPage
class_name MfdPage
## A MULTI-FUNCTION DISPLAY, on the Hornet's pattern.
##
## An F/A-18 carries three of these: a Digital Display Indicator either side of the
## windscreen and a colour Multi-Purpose Display low on the centre console. Twenty
## pushbuttons round the bezel, five to a side, and the one in the middle of the bottom row
## is MENU -- press it and you get the TACTICAL menu, press it again and you get SUPPORT.
## Everything else is a page selected off one of those two.
##
##   TAC     STORES, ATTK RDR, EW, SA, TGT DATA
##   SUPT    HSI, ADI, ENG, FCS, BIT, CHKLST
##
## WHAT IS ON A PAGE HERE IS WHAT THIS GAME ACTUALLY KNOWS, and nothing else. A real Hornet
## has a fuel page and this aeroplane does not model fuel, so there is no fuel page: an
## instrument showing a plausible number it did not measure is worse than no instrument,
## and it is the kind of lie you only notice in the accident report. The same rule as
## `CraftPage.reading`, applied to whole pages.
##
## FOR THE SEATS THAT DO NOT FLY. A pilot has a windscreen, a stick and a horizon; a gunner
## sitting sideways in the back of a boat has a screen and that is all, so the screen has to
## be worth having. Every page here answers a question somebody in that seat would actually
## ask -- what is around me, where are we going, is the gun armed, what is the aircraft
## doing -- and `CockpitStation` fits two of them, left and right, to any seat whose station
## does not fly.

const AMBER := Color(0.95, 0.72, 0.22)
const GREEN := Color(0.42, 0.92, 0.52)
const DIM := Color(0.38, 0.52, 0.42)
const GLASS := Color(0.02, 0.05, 0.04)


## THE "NOTHING HERE" LINE, which all three worked pages need and none of them needs
## differently. A page whose craft is not fitted with what it shows says so and shows
## nothing; the alternative is a page of dead switches, which reads as a broken screen
## rather than as an aeroplane without flaps.
static func placeholder(words: String) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", DIM)
	label.position = Vector2(6.0, 24.0)
	return label


## The column a page stacks its rows in, inset under the title. `apart` is the only thing
## any of them wanted to choose.
static func column(apart: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6.0
	box.offset_top = 22.0
	box.offset_right = -6.0
	box.add_theme_constant_override("separation", apart)
	return box

## The two menus, and the pages each reaches. Order is the order they appear round the bezel.
const TAC: Array[String] = ["STORES", "ATTK RDR", "EW", "SA", "TGT DATA"]
const SUPT: Array[String] = ["HSI", "ADI", "ENG", "FCS", "BIT", "CHKLST",
	"SWITCHES", "RADIO", "MODE"]
## The three pages you can WORK rather than read. Each of them is a different Godot idiom --
## a column of check buttons, a slider, a set of exclusive buttons -- and all three share
## their state the same way: they ASK the command bus, and they draw what it says.
const WORKED: Array[String] = ["SWITCHES", "RADIO", "MODE"]

## Which side of the aircraft this one is. Only used to pick the page it wakes up on, the
## way a Hornet's left DDI comes up on HSI and its right on the attack radar.
@export var right_hand_side: bool = false

var _state: Dictionary = {}
var _page: String = "HSI"
var _menu: String = ""
var _face: Control = null
var _title: Label = null
var _rows: VBoxContainer = null
var _plan: MfdPlan = null
var _switches: MfdSwitches = null
var _radio: MfdDial = null
var _modes: MfdModes = null
var _buttons: Array[Button] = []


func _ready() -> void:
	if right_hand_side:
		_page = "ATTK RDR"
	var back := ColorRect.new()
	back.color = Color(0.07, 0.08, 0.08)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	# THE GLASS, inset from the bezel on every side by a button's width. What is left in the
	# middle is the display; the ring round it is the twenty pushbuttons.
	_face = ColorRect.new()
	(_face as ColorRect).color = GLASS
	_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	_face.offset_left = 54.0
	_face.offset_right = -54.0
	_face.offset_top = 30.0
	_face.offset_bottom = -34.0
	add_child(_face)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", AMBER)
	_title.position = Vector2(6.0, 2.0)
	_face.add_child(_title)

	_rows = VBoxContainer.new()
	_rows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rows.offset_left = 6.0
	_rows.offset_top = 22.0
	_rows.offset_right = -6.0
	_rows.add_theme_constant_override("separation", 1)
	_face.add_child(_rows)

	_switches = MfdSwitches.new()
	_switches.set_anchors_preset(Control.PRESET_FULL_RECT)
	_switches.visible = false
	_switches.commanded.connect(func(ch, v): commanded.emit(ch, v))
	_face.add_child(_switches)

	_radio = MfdDial.new()
	_radio.set_anchors_preset(Control.PRESET_FULL_RECT)
	_radio.visible = false
	_radio.commanded.connect(func(ch, v): commanded.emit(ch, v))
	_face.add_child(_radio)

	_modes = MfdModes.new()
	_modes.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modes.visible = false
	_modes.commanded.connect(func(ch, v): commanded.emit(ch, v))
	_face.add_child(_modes)

	_plan = MfdPlan.new()
	_plan.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plan.visible = false
	_face.add_child(_plan)

	_build_the_bezel()
	_relabel()


## TWENTY PUSHBUTTONS, five to a side, and the middle of the bottom row is MENU.
##
## They are ordinary Buttons: `TouchPanel` turns a fingertip into a click, so a bezel that is
## really a row of buttons is a bezel a controller can press with no code of its own.
func _build_the_bezel() -> void:
	for i in range(20):
		var key := Button.new()
		key.add_theme_font_size_override("font_size", 10)
		key.custom_minimum_size = Vector2(46.0, 22.0)
		key.clip_text = true
		var slot: int = i
		key.pressed.connect(func(): _pressed(slot))
		add_child(key)
		_buttons.append(key)
		_place(key, i)


## Where button `i` sits: 0-4 along the top, 5-9 down the right, 10-14 along the bottom
## right to left, 15-19 up the left side. Round the face, the way a bezel goes.
func _place(key: Button, i: int) -> void:
	var span: float = 1.0 / 5.0
	if i < 5:
		key.set_anchors_preset(Control.PRESET_TOP_LEFT)
		key.anchor_left = span * float(i)
		key.anchor_right = span * float(i + 1)
		key.offset_left = 56.0 * (span * float(i))
		key.position = Vector2(54.0 + (float(i) * 46.0), 4.0)
	elif i < 10:
		key.position = Vector2(size.x - 50.0, 34.0 + float(i - 5) * 24.0)
	elif i < 15:
		key.position = Vector2(54.0 + float(14 - i) * 46.0, size.y - 26.0)
	else:
		key.position = Vector2(4.0, 34.0 + float(19 - i) * 24.0)
	key.set_anchors_preset(Control.PRESET_TOP_LEFT, false)


## MENU is the middle of the bottom row -- button 12 -- and everything else selects whatever
## the current menu has put on it.
func _pressed(slot: int) -> void:
	if slot == 12:
		_menu = "TAC" if _menu != "TAC" else "SUPT"
		_relabel()
		return
	var offered: Array[String] = _offered()
	if _menu != "" and slot < offered.size():
		_page = offered[slot]
		_menu = ""
	_relabel()
	render(_state)


func _offered() -> Array[String]:
	if _menu == "TAC":
		return TAC
	if _menu == "SUPT":
		return SUPT
	return [] as Array[String]


func _relabel() -> void:
	var offered: Array[String] = _offered()
	for i in range(_buttons.size()):
		if i == 12:
			_buttons[i].text = "MENU" if _menu == "" else _menu
			continue
		_buttons[i].text = offered[i] if i < offered.size() else ""
		_buttons[i].disabled = i >= offered.size()


## WHAT THE CRAFT IS DOING, drawn as whichever page is up.
func render(state: Dictionary) -> void:
	_state = state
	if _title == null:
		return
	_title.text = _page if _menu == "" else "%s MENU" % _menu
	var plan: bool = _page == "SA" or _page == "EW" or _page == "ATTK RDR"
	_plan.visible = plan and _menu == ""
	_switches.visible = _page == "SWITCHES" and _menu == ""
	_radio.visible = _page == "RADIO" and _menu == ""
	_modes.visible = _page == "MODE" and _menu == ""
	_rows.visible = not (_plan.visible or _switches.visible or _radio.visible
		or _modes.visible)
	if _plan.visible:
		_plan.show_contacts(state.get("contacts", []) as Array,
			_page == "EW", float(state.get("heading", 0.0)))
		return
	if _switches.visible:
		_switches.show_bus(state)
		return
	if _radio.visible:
		_radio.show_bus(state)
		return
	if _modes.visible:
		_modes.show_bus(state)
		return
	_write(_lines_for(_page, state))


## EVERY PAGE, as label rows. A dash wherever the craft has not said, never a zero.
func _lines_for(page: String, state: Dictionary) -> Array:
	match page:
		"ADI":
			return [["PITCH  deg", reading(state, "pitch", 1)],
				["BANK   deg", reading(state, "bank", 1)],
				["HDG    deg", reading(state, "heading", 0)],
				["CLIMB  m/s", reading(state, "climb", 1)],
				["ALT      m", reading(state, "altitude", 0)]]
		"HSI":
			var at: Vector3 = state.get("position", Vector3.ZERO)
			return [["HDG    deg", reading(state, "heading", 0)],
				["NORTH    m", String.num(-at.z, 0)],
				["EAST     m", String.num(at.x, 0)],
				["WP BRG deg", reading(state, "route_bearing", 0)],
				["WP RNG  km", "---" if not state.has("route_range")
					else String.num(float(state["route_range"]) / 1000.0, 1)]]
		"ENG":
			return [["THR      %", reading(state, "throttle", 0)],
				["IAS    m/s", reading(state, "airspeed", 0)],
				["CLIMB  m/s", reading(state, "climb", 1)],
				["FLAPS     ", reading(state, "flaps", 2)],
				["GEAR      ", _flag(state, "gear", "DOWN", "UP")]]
		"FCS":
			var stick: Vector2 = state.get("stick", Vector2.ZERO)
			return [["ROLL      ", String.num(stick.x, 2)],
				["PITCH     ", String.num(stick.y, 2)],
				["RUDDER    ", reading(state, "rudder", 2)],
				["THR      %", reading(state, "throttle", 0)],
				["HANDS ON  ", str(state.get("hands_on", "---"))]]
		"STORES":
			var guns: Array = state.get("turrets", []) as Array
			var rows: Array = [["MASTER ARM", _flag(state, "master", "ARM", "SAFE")],
				["WEAPON    ", reading(state, "weapon", 0)],
				["MOUNTS    ", str(guns.size())]]
			for i in range(guns.size()):
				var aim: Vector2 = guns[i]
				rows.append(["GUN %d  deg" % (i + 1),
					"%s / %s" % [String.num(rad_to_deg(aim.x), 0),
						String.num(rad_to_deg(aim.y), 0)]])
			return rows
		"BIT":
			var rows: Array = []
			for key in ["weapon", "radio", "display", "mode", "master", "crew_light",
					"flaps", "trim", "gear", "spoilers", "tilt"]:
				if state.has(key):
					rows.append([key.to_upper(), str(state[key])])
			if rows.is_empty():
				rows.append(["NO BUS", "---"])
			return rows
		"CHKLST":
			return [["CRAFT     ", String(state.get("name", "---"))],
				["IAS    m/s", reading(state, "airspeed", 0)],
				["ALT      m", reading(state, "altitude", 0)],
				["GEAR      ", _flag(state, "gear", "DOWN", "UP")],
				["MASTER ARM", _flag(state, "master", "ARM", "SAFE")]]
		"TGT DATA":
			var near: Array = state.get("contacts", []) as Array
			if near.is_empty():
				return [["NO TARGET", "---"]]
			var first: Dictionary = near[0]
			return [["BRG    deg", String.num(float(first["bearing"]), 0)],
				["RNG     km", String.num(float(first["range"]) / 1000.0, 1)],
				["REL ALT  m", String.num(float(first["height"]), 0)],
				["TYPE      ", Sim.kind_name(int(first["kind"]))],
				["CONTACTS  ", str(near.size())]]
	return [["NO PAGE", "---"]]


## True/false as the word an instrument would use, or a dash when nobody has said.
func _flag(state: Dictionary, key: String, yes: String, no: String) -> String:
	if not state.has(key):
		return "---"
	return yes if bool(state[key]) else no


func _write(lines: Array) -> void:
	while _rows.get_child_count() > lines.size():
		var spare: Node = _rows.get_child(_rows.get_child_count() - 1)
		_rows.remove_child(spare)
		spare.queue_free()
	while _rows.get_child_count() < lines.size():
		var line := HBoxContainer.new()
		var name_of := Label.new()
		name_of.add_theme_font_size_override("font_size", 12)
		name_of.add_theme_color_override("font_color", DIM)
		name_of.custom_minimum_size = Vector2(84.0, 0.0)
		line.add_child(name_of)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 13)
		value.add_theme_color_override("font_color", GREEN)
		line.add_child(value)
		_rows.add_child(line)
	for i in range(lines.size()):
		var line: HBoxContainer = _rows.get_child(i)
		(line.get_child(0) as Label).text = String(lines[i][0])
		(line.get_child(1) as Label).text = String(lines[i][1])


## WHICH STATE KEY CARRIES A CHANNEL, so a switch can read back what it just asked for.
## The command goes out by channel number and comes back by name; this is the one place that
## knows both, rather than every page knowing half of it.
const CHANNEL_KEY: Dictionary = {
	Sim.Channel.FLAPS: "flaps", Sim.Channel.TRIM: "trim", Sim.Channel.GEAR: "gear", Sim.Channel.HOOK: "hook",
	Sim.Channel.SPOILERS: "spoilers", Sim.Channel.TILT: "tilt",
	Sim.Channel.WEAPON: "weapon", Sim.Channel.RADIO: "radio",
	Sim.Channel.DISPLAY: "display", Sim.Channel.MODE: "mode",
	Sim.Channel.LIGHTS: "lights", Sim.Channel.MASTER: "master",
	Sim.Channel.CREW_TOGGLE: "crew_light",
}


## A COLUMN OF CHECK BUTTONS, one per switch this craft actually has.
##
## The first of the three worked pages, and the plainest Godot idiom there is. What makes it
## interesting is not the widget, it is that PRESSING ONE DOES NOT MOVE IT. The press emits a
## command, the command goes on the bus, the bus comes back as craft state, and the switch is
## set from that -- so the gunner copy and the driver copy move at the same moment and
## neither of them is the one that decides.
##
## `set_pressed_no_signal`, so drawing the state back does not look like somebody pressing it
## and send the command round again for ever.
class MfdSwitches extends Control:
	signal commanded(channel: int, value: int)

	var _switches: Dictionary = {}
	var _column: VBoxContainer = null
	var _empty: Label = null

	func _ready() -> void:
		_column = MfdPage.column(1)
		add_child(_column)
		_empty = MfdPage.placeholder("NO SWITCHES FITTED")
		add_child(_empty)

	func show_bus(state: Dictionary) -> void:
		# ONE SWITCH PER FITTED CHANNEL THAT IS A SWITCH -- range 1, which is what the
		# simulation calls a thing with two positions. A screen offering flaps to a boat is
		# a screen with a dead switch on it.
		for entry in (state.get("fitted", []) as Array):
			var channel: int = int((entry as Dictionary).get("channel", -1))
			if int((entry as Dictionary).get("range", 0)) != 1:
				continue
			if _switches.has(channel):
				continue
			var box := CheckButton.new()
			box.text = String((entry as Dictionary).get("name", "?")).to_upper()
			box.add_theme_font_size_override("font_size", 12)
			var which: int = channel
			box.toggled.connect(func(on: bool): commanded.emit(which, 1 if on else 0))
			_column.add_child(box)
			_switches[channel] = box
		_empty.visible = _switches.is_empty()
		for channel in _switches:
			var key: String = String(MfdPage.CHANNEL_KEY.get(channel, ""))
			if state.has(key):
				(_switches[channel] as CheckButton).set_pressed_no_signal(bool(state[key]))


## A SLIDER, for a dial on the bus with more than two positions.
##
## The second idiom. A radio frequency is a number between nothing and fifteen, and the
## natural way to set one of those with a fingertip is to drag it -- so an HSlider, with the
## value written beside it, because a slider alone tells you where it is and not what that
## means.
##
## Driven from the state every frame, like the switches, so both screens agree and the one
## you are not touching moves with the one you are.
class MfdDial extends Control:
	signal commanded(channel: int, value: int)

	var _bar: HSlider = null
	var _value: Label = null
	var _empty: Label = null
	var _dragging: bool = false

	func _ready() -> void:
		_value = Label.new()
		_value.add_theme_font_size_override("font_size", 26)
		_value.add_theme_color_override("font_color", MfdPage.GREEN)
		_value.position = Vector2(8.0, 30.0)
		add_child(_value)
		_bar = HSlider.new()
		_bar.min_value = 0.0
		_bar.step = 1.0
		_bar.position = Vector2(8.0, 74.0)
		_bar.size = Vector2(150.0, 20.0)
		_bar.value_changed.connect(_moved)
		_bar.drag_started.connect(func(): _dragging = true)
		_bar.drag_ended.connect(func(_c): _dragging = false)
		add_child(_bar)
		_empty = MfdPage.placeholder("NO RADIO FITTED")
		add_child(_empty)

	func _moved(to: float) -> void:
		commanded.emit(Sim.Channel.RADIO, int(to))

	func show_bus(state: Dictionary) -> void:
		var top: int = -1
		for entry in (state.get("fitted", []) as Array):
			if int((entry as Dictionary).get("channel", -1)) == Sim.Channel.RADIO:
				top = int((entry as Dictionary).get("range", 0))
		_bar.visible = top > 0
		_value.visible = top > 0
		_empty.visible = top <= 0
		if top <= 0:
			return
		_bar.max_value = float(top)
		var now: int = int(state.get("radio", 0))
		_value.text = "CH %02d" % now
		# NOT WHILE A HAND IS ON IT. Setting a slider from the wire under the finger that is
		# dragging it is a slider that fights you -- the same argument as the shared
		# throttle, and the same answer: what you are holding is yours until you let go.
		if not _dragging:
			_bar.set_value_no_signal(float(now))


## EXCLUSIVE BUTTONS, for a selector channel -- one of several, never two.
##
## The third idiom, and the one a master mode actually is: an aircraft is in air-to-air OR
## air-to-ground OR navigation, and a column of check buttons would let it be in two at
## once. A `ButtonGroup` says only one at a time, and the group is what makes it read as a
## mode switch rather than as three unrelated toggles.
class MfdModes extends Control:
	signal commanded(channel: int, value: int)

	const NAMES: Array[String] = ["OFF", "ONE", "TWO", "THREE", "FOUR", "FIVE"]

	var _rows: VBoxContainer = null
	var _built: int = -1
	var _channel: int = -1
	var _buttons: Array[Button] = []
	var _empty: Label = null

	func _ready() -> void:
		_rows = MfdPage.column(2)
		add_child(_rows)
		_empty = MfdPage.placeholder("NO MODE SELECTOR")
		add_child(_empty)

	func show_bus(state: Dictionary) -> void:
		# THE FIRST SELECTOR THIS CRAFT HAS. A gunboat calls it hover hold and an aeroplane
		# calls it a display page; what it is called comes off the bus, so this is the same
		# page on every craft and it says the craft own word for it.
		var found: int = -1
		var top: int = 0
		var called: String = ""
		for entry in (state.get("fitted", []) as Array):
			var channel: int = int((entry as Dictionary).get("channel", -1))
			var span: int = int((entry as Dictionary).get("range", 0))
			if span >= 2 and span <= 5 and channel != Sim.Channel.RADIO and found < 0:
				found = channel
				top = span
				called = String((entry as Dictionary).get("name", "?")).to_upper()
		_rows.visible = found >= 0
		_empty.visible = found < 0
		if found < 0:
			return
		if _built != found:
			_built = found
			_channel = found
			for spare in _rows.get_children():
				_rows.remove_child(spare)
				spare.queue_free()
			_buttons.clear()
			var heading := Label.new()
			heading.text = called
			heading.add_theme_font_size_override("font_size", 12)
			heading.add_theme_color_override("font_color", MfdPage.DIM)
			_rows.add_child(heading)
			var only_one := ButtonGroup.new()
			for step in range(top + 1):
				var pick := Button.new()
				pick.text = NAMES[step] if step < NAMES.size() else str(step)
				pick.toggle_mode = true
				pick.button_group = only_one
				pick.add_theme_font_size_override("font_size", 12)
				pick.custom_minimum_size = Vector2(0.0, 22.0)
				var value: int = step
				pick.pressed.connect(func(): commanded.emit(_channel, value))
				_rows.add_child(pick)
				_buttons.append(pick)
		var now: int = int(state.get(String(MfdPage.CHANNEL_KEY.get(found, "")), 0))
		for i in range(_buttons.size()):
			_buttons[i].set_pressed_no_signal(i == now)


## THE PLAN VIEW: what is around you, drawn rather than listed.
##
## Own ship at the middle, nose up, and every contact at its bearing and range. The same
## picture answers the attack radar, the situation display and the electronic warfare page,
## because all three of them are "what is out there and where" and only the dressing differs.
class MfdPlan extends Control:
	var _near: Array = []
	var _threat: bool = false

	func show_contacts(near: Array, threat: bool, _heading: float) -> void:
		_near = near
		_threat = threat
		queue_redraw()

	func _draw() -> void:
		var middle: Vector2 = size * 0.5
		var reach: float = minf(size.x, size.y) * 0.44
		var ink: Color = MfdPage.DIM
		for ring in [0.33, 0.66, 1.0]:
			draw_arc(middle, reach * ring, 0.0, TAU, 48, ink, 1.0)
		draw_line(middle - Vector2(0.0, reach), middle + Vector2(0.0, reach), ink, 1.0)
		draw_line(middle - Vector2(reach, 0.0), middle + Vector2(reach, 0.0), ink, 1.0)
		# OWN SHIP, nose up. The whole picture is relative to where you are already facing,
		# because a bearing on a screen in a cockpit is an instruction about where to look.
		draw_circle(middle, 3.0, MfdPage.AMBER)
		if _near.is_empty():
			return
		# Scaled to the FURTHEST thing shown, so the picture is always full of what there
		# is rather than empty at whatever range somebody chose.
		var furthest: float = 1.0
		for one in _near:
			furthest = maxf(furthest, float(one["range"]))
		for one in _near:
			var about: float = deg_to_rad(float(one["bearing"]))
			var out: float = reach * float(one["range"]) / furthest
			var at: Vector2 = middle + Vector2(sin(about), -cos(about)) * out
			var mark: Color = MfdPage.GREEN
			if _threat and float(one["range"]) < furthest * 0.34:
				mark = Color(0.95, 0.35, 0.28)
			draw_rect(Rect2(at - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), mark, false, 1.5)
			if float(one["height"]) > 60.0:
				draw_line(at + Vector2(0.0, -5.0), at + Vector2(0.0, -9.0), mark, 1.5)
			elif float(one["height"]) < -60.0:
				draw_line(at + Vector2(0.0, 5.0), at + Vector2(0.0, 9.0), mark, 1.5)
