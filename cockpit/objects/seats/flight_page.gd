extends CraftPage
class_name FlightPage
## THE FIRST PAGE: what the aeroplane is doing, and what it is being TOLD to do.
##
## ---------------------------------------------------------------------------------
## SMALL TEXT AND TWO COLUMNS, WHICH IS WHAT A PANEL IS FOR
## ---------------------------------------------------------------------------------
##
## It was seven rows at eighteen points, which on a 384-pixel screen is a poster. Panel text
## is not read at a glance from across a room -- it is read by somebody whose eyes are forty
## centimetres away and who wants ALL of it at once. Every real MFD in the world is dense
## for exactly that reason: a page you have to scroll is a page you cannot cross-check, and
## cross-checking is the entire job.
##
## So: eleven points, two columns, and the space that buys goes into MORE READINGS rather
## than into margins.
##
## ---------------------------------------------------------------------------------
## AND THE RIGHT COLUMN IS THE INPUTS
## ---------------------------------------------------------------------------------
##
## The left column is what the aeroplane IS DOING -- speed, height, attitude, climb. The
## right is what it has been ASKED to do: where the stick is, where the rudder is, what the
## trim is wound to, which notch of flap, whether the gear is down. The two together are the
## only way to tell a trim problem from a wind problem, or a stuck control from a pilot who
## is holding one.
##
## EVERY ONE OF THEM IS OFF THE WIRE, from `craft_state`, which is what makes the copilot's
## screen agree with the pilot's. A page that reached around the back for its own answer
## would be a page two people could argue with each other about.

const AMBER := Color(0.95, 0.72, 0.22)
const GREEN := Color(0.45, 0.90, 0.55)
const DIM := Color(0.30, 0.62, 0.38)

## ELEVEN AND NINE. Small enough to fit two columns of eight on a 384-pixel panel, and not
## so small that the values -- which are what anybody is actually reading -- go soft.
const VALUE_SIZE: int = 10
const LABEL_SIZE: int = 8

var _rows: Dictionary = {}
var _bars: Dictionary = {}
var _lines: Dictionary = {}
var _labels: Dictionary = {}

const CHANNEL_ROWS: Dictionary = {
	Sim.Channel.THROTTLE: "throttle", Sim.Channel.FLAPS: "flaps", Sim.Channel.TRIM: "trim",
	Sim.Channel.GEAR: "gear", Sim.Channel.HOOK: "hook", Sim.Channel.SPOILERS: "spoilers", Sim.Channel.WEAPON: "weapon",
	Sim.Channel.LIGHTS: "lights", Sim.Channel.MASTER: "master",
}


func _ready() -> void:
	var back := ColorRect.new()
	back.color = Color(0.03, 0.05, 0.04)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 6.0
	page.offset_top = 4.0
	page.offset_right = -6.0
	page.offset_bottom = -4.0
	page.add_theme_constant_override("separation", 1)
	add_child(page)

	var title := Label.new()
	title.text = "FLIGHT"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", AMBER)
	page.add_child(title)

	var both := HBoxContainer.new()
	both.add_theme_constant_override("separation", 10)
	both.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(both)

	# LEFT: WHAT IT IS DOING. Read top to bottom in the order a pilot scans -- what it is,
	# how fast, how high, which way, and then the three that say where it is going.
	var doing := _column(both)
	for row in [["craft", "CRAFT"], ["airspeed", "IAS"], ["altitude", "ALT"],
			["heading", "HDG"], ["vario", "VS"], ["pitch", "PITCH"], ["bank", "BANK"],
			["tank", "TANK"], ["range", "RNG"], ["bearing", "BRG"],
			["contacts", "TFC"], ["lift", "LIFT"]]:
		_add_row(doing, String(row[0]), String(row[1]))

	# RIGHT: WHAT IT HAS BEEN ASKED TO DO. The inputs, and they are what was missing: an
	# aeroplane that will not hold its nose up looks identical to one being held nose-down,
	# and the only thing that tells them apart is seeing where the stick and the trim are.
	var asked := _column(both)
	# EVERY KEY IN `CHANNEL_ROWS` MUST BE BUILT HERE. `render` walks `CHANNEL_ROWS` to decide
	# which rows a craft may show, and `sense` holds every one of them to "present, and visible
	# exactly when the channel is fitted". A channel added to that table and not to this list is
	# a row that is missing for every craft in the game -- which is what the hook did on
	# 2026-09-17, twenty-three craft at once, fitted or not.
	for row in [["throttle", "THR"], ["elevator", "ELEV"], ["aileron", "AIL"],
			["rudder", "RUD"], ["trim", "TRIM"], ["flaps", "FLAP"], ["gear", "GEAR"],
			["hook", "HOOK"],
			["spoilers", "SPOIL"], ["weapon", "WPN"], ["master", "ARM"],
			["lights", "LT"], ["hands", "HANDS"]]:
		_add_row(asked, String(row[0]), String(row[1]))


func _column(into: HBoxContainer) -> VBoxContainer:
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 0)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	into.add_child(side)
	return side


## ONE READING: a dim label, the number, and -- where the number is a lever between two
## stops -- a bar behind it.
##
## THE BAR IS THE POINT OF THE RIGHT-HAND COLUMN. "+0.42" is a number you have to think
## about; a bar half out to the right is a stick half over, and you know it without reading
## anything. The number is still there because you cannot cross-check a picture.
func _add_row(into: VBoxContainer, key: String, label: String) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	var name := Label.new()
	name.text = label
	name.custom_minimum_size = Vector2(34.0, 0.0)
	name.add_theme_font_size_override("font_size", LABEL_SIZE)
	name.add_theme_color_override("font_color", DIM)
	line.add_child(name)
	var value := Label.new()
	value.text = "---"
	value.custom_minimum_size = Vector2(44.0, 0.0)
	value.add_theme_font_size_override("font_size", VALUE_SIZE)
	value.add_theme_color_override("font_color", GREEN)
	line.add_child(value)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = -1.0
	bar.max_value = 1.0
	bar.value = 0.0
	bar.custom_minimum_size = Vector2(38.0, 6.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.visible = false
	line.add_child(bar)
	into.add_child(line)
	_rows[key] = value
	_bars[key] = bar
	_lines[key] = line
	_labels[key] = name


## EVERY NUMBER FROM THE STATE IT WAS HANDED, and none of them from anywhere else.
func render(state: Dictionary) -> void:
	if _rows.is_empty():
		return
	_show_fitted_rows(state)
	_say("craft", String(state.get("name", "---")).to_upper())
	_say("airspeed", reading(state, "airspeed"))
	_say("altitude", reading(state, "altitude"))
	_say("heading", reading(state, "heading"))
	_say("pitch", "%+.0f" % float(state["pitch"]) if state.has("pitch") else "---")
	_say("bank", "%+.0f" % float(state["bank"]) if state.has("bank") else "---")

	# THE VARIOMETER, which is the one instrument a glider is flown by. Signed, to a tenth:
	# a glider sinks at about one and a half and a good thermal is three or four, so the
	# difference between working lift and wasting height is a number this small.
	var climb: float = float(state.get("climb", 0.0))
	_say("vario", "%+.1f" % climb if state.has("climb") else "---")
	_tint("vario", AMBER if climb < -2.0 else GREEN)

	# ---- what it has been asked to do -------------------------------------------------
	#
	# THE STICK COMES OFF THE LINKAGE and not off this seat's own input, which matters on a
	# two-crew aeroplane: what is drawn is where the elevator actually IS, the merged demand
	# the aircraft is flying, so a copilot pulling against you shows up as a stick that does
	# not match your hand.
	var stick: Vector2 = state.get("stick", Vector2.ZERO)
	_lever("elevator", stick.y, "%+.2f" % stick.y)
	_lever("aileron", stick.x, "%+.2f" % stick.x)
	_lever("rudder", float(state.get("rudder", 0.0)),
		"%+.2f" % float(state.get("rudder", 0.0)))
	_say("throttle", reading(state, "throttle"))
	if state.has("throttle"):
		_lever("throttle", float(state["throttle"]) / 50.0 - 1.0, reading(state, "throttle"))

	# TRIM, WHICH UNTIL RECENTLY DID NOTHING. It is on the elevator now -- see
	# `kTrimAuthority` -- so where it is wound to is a reading worth having: an aeroplane
	# that will not hold its nose up and a trim wound fully forward are the same picture.
	if state.has("trim"):
		_lever("trim", float(state["trim"]), "%+.2f" % float(state["trim"]))
	else:
		_say("trim", "---")

	_say("flaps", "%d" % int(round(float(state["flaps"]) * 3.0)) if state.has("flaps")
		else "---")
	if state.has("gear"):
		_say("gear", "DOWN" if bool(state["gear"]) else "UP")
		_tint("gear", GREEN if bool(state["gear"]) else DIM)
	else:
		_say("gear", "---")
	# THE HOOK READS LIKE THE GEAR, because it is the same question: is the thing out or in.
	# A craft without one says nothing rather than "UP", which would be a claim about a hook
	# it does not have.
	if state.has("hook"):
		_say("hook", "DOWN" if bool(state["hook"]) else "UP")
		_tint("hook", GREEN if bool(state["hook"]) else DIM)
	else:
		_say("hook", "---")

	# WHERE IT IS BEING TAKEN, when something is taking it. An autopilot publishes a route
	# and a hand-flown craft does not, so these read dashes rather than zero.
	_say("range", "%.0f" % float(state["route_range"]) if state.has("route_range")
		else "---")
	_say("bearing", "%.0f" % float(state["route_bearing"]) if state.has("route_bearing")
		else "---")
	# AND WHAT ELSE IS IN THE AIR NEARBY, which is the number a pilot in a busy circuit
	# wants before they want anything else.
	_say("contacts", "%d" % (state.get("contacts", []) as Array).size())
	# THE AIR ITSELF. A glider is flown by this and nothing else; everybody else wants to
	# know why the aeroplane is climbing when they did not ask it to.
	_say("lift", "%+.1f" % float(state["lift"]) if state.has("lift") else "---")

	for pair in [["spoilers", "spoilers"], ["master", "master"], ["lights", "lights"]]:
		var key: String = String(pair[0])
		if state.has(pair[1]):
			_say(key, "ON" if bool(state[pair[1]]) else "OFF")
			_tint(key, GREEN if bool(state[pair[1]]) else DIM)
		else:
			_say(key, "---")
	_say("weapon", "%d" % int(state["weapon"]) if state.has("weapon") else "---")

	# HOW MANY PAIRS OF HANDS ARE ON IT. Two people flying one aeroplane is the whole point
	# of the thing, and this is the line that says whether you are alone on it.
	_say("hands", "%d" % int(state.get("hands_on", 0)))

	# AND WHAT IS IN THE TANK, with the one word a pilot flying a scooping run needs: the
	# sea and a lake look identical at fifty feet and the only difference that matters is
	# whether the gauge is moving.
	if not state.has("tank"):
		_say("tank", "---")
	elif bool(state.get("scooping", false)):
		_say("tank", "%d FILL" % int(round(float(state["tank"]) * 100.0)))
	else:
		_say("tank", "%d%s" % [int(round(float(state["tank"]) * 100.0)),
			" DROP" if bool(state.get("dropping", false)) else ""])
	# NEARLY EMPTY IS ONE FIGURE FOR THE WHOLE AEROPLANE, off the gauge on the panel beside
	# this screen. Two instruments drawing one tank must not disagree about when it is low.
	_tint("tank", AMBER if float(state.get("tank", 1.0)) < TankGauge.LOW else GREEN)


## ONLY CONTROLS THE CRAFT IS FITTED WITH, named in the craft's own words. The state comes
## from VehicleView once for every screen aboard, so pilot and copilot cannot disagree.
func _show_fitted_rows(state: Dictionary) -> void:
	if not state.has("fitted"):
		return
	var fitted: Dictionary = {}
	for entry in (state.get("fitted", []) as Array):
		var row := entry as Dictionary
		fitted[int(row.get("channel", -1))] = String(row.get("name", ""))
	for channel in CHANNEL_ROWS:
		var key: String = CHANNEL_ROWS[channel]
		var line := _lines.get(key) as Control
		var label := _labels.get(key) as Label
		if line != null:
			line.visible = fitted.has(channel)
		if label != null and fitted.has(channel):
			label.text = String(fitted[channel]).to_upper()


func _say(key: String, what: String) -> void:
	var row := _rows.get(key) as Label
	if row != null:
		row.text = what


func _tint(key: String, colour: Color) -> void:
	var row := _rows.get(key) as Label
	if row != null:
		row.add_theme_color_override("font_color", colour)


## A reading WITH a bar behind it, for anything that is a lever between two stops.
func _lever(key: String, at: float, what: String) -> void:
	_say(key, what)
	var bar := _bars.get(key) as ProgressBar
	if bar != null:
		bar.visible = true
		bar.value = clampf(at, -1.0, 1.0)
