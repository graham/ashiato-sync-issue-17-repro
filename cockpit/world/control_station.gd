extends Control
class_name ControlStation
## THE CONTROLLER'S STATION: a radar plot, the people in the session, and no aeroplane. Flat, and no headset.
##
##   Godot --path cockpit --xr-mode off -- --host --world=island --level=control
##   Godot --path cockpit --xr-mode off -- --join=192.168.1.20 --level=control
##
## WHY IT EXISTS. The user, 2026-09-19: *"awacs or tower controller (so we support audio and team membership), but
## they focus on dispatching and radar"*.
##
## ---------------------------------------------------------------------------------------------------
## IT DRAWS WHAT IT IS HANDED, AND WHAT IT IS HANDED IS RADAR
## ---------------------------------------------------------------------------------------------------
##
## **This is the first thing in cockpit that plots RADAR rather than omniscience.** Every other map in the game --
## the clipboard's, the cockpit stations' -- draws `AirPicture.contacts(manifest, Sim.current)`, which is every craft
## the client holds, at any range, through any mountain. This station draws `RadarWatch.contacts()`: what the HOST
## decided this machine can see, published to it and to nobody else (`world/radar_set.gd`, rule 10).
##
## So a controller here can be denied a contact, and a pilot down a valley is genuinely off their plot. That is the
## whole point of the role and it is why the station came after the sensor rather than before it.
##
## THE OTHER MAPS ARE DELIBERATELY NOT CHANGED. Whether a PILOT's in-cockpit map should become a radar picture is a
## question about how the game plays, not about how it is built, and it is the user's to answer -- it would take
## sight of other aircraft away from everybody in the game, which is a bigger change than this lane was asked for.
## `../../todo/flatcrew--should-the-pilots-map-be-radar-too.md` puts the question where it will be found.
##
## ---------------------------------------------------------------------------------------------------
## IT IS A LAYER OVER THE LEVEL, NOT A LEVEL OF ITS OWN
## ---------------------------------------------------------------------------------------------------
##
## `--level=control` goes to `world/sky.tscn` like `watch`, `tower` and `server`. `Sky._nobody_is_playing` builds no
## rig, no seat, no hands and no XR; `Sky._the_controller` builds this on its own `CanvasLayer` INSTEAD of the
## observer's camera, so the level has none at all and what fills the screen is the plot.
##
## THAT IS WHY IT NEEDS NO MAP OF ITS OWN. `Sky.level_map` is the level's orthographic `LevelMap`, already built and
## already rebuilt when the level changes, and `Sky.radar` is the `RadarWatch` that sweeps or receives. Both are
## handed in. A station that made its own would be a second map of the same island that could disagree with the one
## every other screen draws.
##
## AND IT IS WHY A CONTROLLER IS NOT A `Seats` SEAT. Seats in this game are seats IN A CRAFT -- `join_seat` names "seat
## 3 of the craft player 2 is in", and the server writes `Seats` on a vehicle. A controller is in no craft, so it has
## no seat to be in, exactly as the marshaller has none ("A POST IS A SEAT", `docs/crew.md`). What makes somebody a
## controller here is the door they came in through, and the session sees them as a player like any other: on the
## roster, on a team, in the chat, on the voice.
##
## ---------------------------------------------------------------------------------------------------
## TEAMS AND VOICE ARE NOT REBUILT HERE
## ---------------------------------------------------------------------------------------------------
##
## `lane/voicelobby` built all of it and this station asks the same authorities: the roster is `Net.roster_cards()`,
## the team is `Net.team_of`, and a team is set with `Net.set_team` under `TeamBoard`'s rules. Nothing here keeps a
## list. The room that already does chat and push-to-talk is `world/flat_lobby.gd`; this station shows who is on
## which team beside the plot, because that is what a controller is reading while they talk -- which of the contacts
## are theirs.

## How often the plot is refreshed, seconds. The sweep itself is once a second (`RadarWatch.EVERY_MSEC`); redrawing
## faster than the data arrives only costs a redraw, and redrawing slower makes the plot older than it has to be.
const EVERY: float = 0.25

const BACKING := Color(0.05, 0.07, 0.08)
const PALE := Color(0.86, 0.90, 0.92)
const DIM := Color(0.45, 0.50, 0.55)
const AMBER := Color(0.95, 0.76, 0.28)
const GOOD := Color(0.45, 0.85, 0.55)
const STALE := Color(0.90, 0.45, 0.35)
## How old a picture may be before the age is drawn in the warning colour, seconds. Two sweeps: one missed publish is
## ordinary, two in a row means the host has stopped talking to this machine.
const OLD: float = 2.5
## How wide the side panel is, pixels. The plot takes the rest.
const PANEL_WIDE: float = 300.0

## Handed in by `Sky`, never reached for: the level's own map, and the thing that sweeps or receives. See the doc block.
var sky: Node = null
var level_map: LevelMap = null
var radar: RadarWatch = null

var _since: float = 0.0
var _canvas: MapCanvas = null
var _heading: Label = null
var _age: Label = null
var _tally: Label = null
var _picked_line: Label = null
var _people: VBoxContainer = null
var _picked: int = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backing := ColorRect.new()
	backing.color = BACKING
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)

	# THE PLOT FILLS EVERYTHING LEFT OF THE PANEL. `MapCanvas` already draws the contacts, tells a person apart from a
	# machine in four channels at once, and answers a click with `selected` -- so picking is not written again here.
	_canvas = MapCanvas.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.offset_right = -PANEL_WIDE
	# CLIPPED TO ITS OWN RECT, and the first drawn picture is why. `MapCanvas` scales the map to fill it and then
	# draws every contact at its scaled place, with no regard for its own edges -- which nothing noticed before,
	# because every other canvas in this game fills a SubViewport that has nothing beside it. Here there is a panel
	# beside it, and contacts out past the island were drawn straight over the roster and the selected contact's
	# details, with a call sign half off the left edge as well.
	_canvas.clip_contents = true
	_canvas.selected.connect(_pick)
	add_child(_canvas)

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -PANEL_WIDE + 16.0
	panel.offset_top = 18.0
	panel.offset_right = -16.0
	panel.offset_bottom = -18.0
	panel.add_theme_constant_override("separation", 8)
	add_child(panel)

	_heading = _a_label("CONTROL", AMBER, 24)
	panel.add_child(_heading)
	_age = _a_label("", DIM, 14)
	panel.add_child(_age)
	_tally = _a_label("", PALE, 15)
	panel.add_child(_tally)
	panel.add_child(_a_label("", DIM, 8))
	panel.add_child(_a_label("SELECTED", DIM, 13))
	_picked_line = _a_label("nothing picked", DIM, 15)
	_picked_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_picked_line)
	panel.add_child(_a_label("", DIM, 8))
	panel.add_child(_a_label("PLAYERS", DIM, 13))
	_people = VBoxContainer.new()
	panel.add_child(_people)

	_show()


func _process(delta: float) -> void:
	_since += delta
	if _since < EVERY:
		return
	_since = 0.0
	_show()


## WHAT IS TRUE RIGHT NOW. Asked at the moment it is drawn, from the authority that owns it, and kept nowhere
## (rule 4): the contacts from `RadarWatch`, the players from `Net.roster_cards()`, the teams from `Net.team_of`.
func _show() -> void:
	var contacts: Array = radar.contacts() if radar != null and is_instance_valid(radar) else []
	var rows: Array[Dictionary] = []
	for row in contacts:
		rows.append(row as Dictionary)
	if _canvas != null and level_map != null:
		_canvas.show_map(level_map, rows)
		_canvas.selected_contact = _picked
		_canvas.queue_redraw()

	# THE AGE IS ON THE BOARD AND IT IS NOT DECORATION. A radar picture is never NOW, and a plot that does not say
	# how old it is reads as though it were. Two missed sweeps turns it red: one is ordinary, two means the host has
	# stopped talking to this machine and every contact on the glass is a guess.
	var old: float = radar.age() if radar != null and is_instance_valid(radar) else -1.0
	_age.text = "no picture yet" if old < 0.0 else "swept %.1f s ago" % old
	_age.add_theme_color_override("font_color", DIM if old >= 0.0 and old < OLD else STALE)
	var people: int = 0
	for row in rows:
		if bool(row.get("manned", false)):
			people += 1
	# AND HOW MANY ARE OFF THE PLOT ALTOGETHER, which is not a nicety.
	#
	# **RADAR REACHES FURTHER THAN THE MAP DRAWS.** `RadarSet.REACH_M` is 60 km and `LevelMap.half_extent` on the
	# island is `Terrain.GROUND_HALF.x`, so a contact past the map's edge is projected outside the canvas and
	# clipped away. The first drawn picture showed it: the panel named RESCUE 80 at 9.9 km and there was no ring
	# anywhere on the glass, because the contact was off the west edge.
	#
	# A CONTACT SILENTLY DROPPED IS THE ONE FAILURE RADAR MUST NOT HAVE -- it looks exactly like terrain hiding
	# something, which is the thing this whole feature is supposed to mean (`world/radar_set.gd`). So the count is
	# said out loud. Drawing an edge marker for each would be better and is a bigger job; see
	# `../../todo/flatcrew--contacts-past-the-edge-of-the-plot.md`.
	var off: int = _off_the_plot(rows)
	_tally.text = "%d contact%s  ·  %d crewed%s" % [rows.size(), "" if rows.size() == 1 else "s", people,
		"" if off == 0 else "  ·  %d off the plot" % off]
	_tally.add_theme_color_override("font_color", PALE if off == 0 else AMBER)

	_picked_line.text = _what_is_picked(rows)
	for row in _people.get_children():
		row.queue_free()
	var cards: Array = Net.roster_cards()
	if cards.is_empty():
		_people.add_child(_a_label("nobody yet", DIM, 14))
		return
	for card in cards:
		var client: int = int(card["player"])
		var team: int = Net.team_of(client)
		var mine: bool = client == Sim.local_client_id()
		_people.add_child(_a_label("%s%s   %s" % ["> " if mine else "  ", String(card["name"]),
			"-" if team == TeamBoard.NOBODY else TeamBoard.name_of(team)], GOOD if mine else PALE, 14))


## THE CONTACT THE CONTROLLER HAS PICKED, in the words they would say on the radio: its call sign, how far out and on
## what bearing FROM THE RADAR HEAD, and how high and how fast.
##
## THE BEARING IS FROM THE HEAD AND NOT FROM THE MIDDLE OF THE MAP, because a controller says "ten miles north of
## the field", and the field is where the aerial is. `RadarWatch.head` is that point and is asked for it.
func _what_is_picked(rows: Array[Dictionary]) -> String:
	if _picked == -1:
		return "nothing picked"
	for row in rows:
		if int(row.get("contact", 0)) != _picked:
			continue
		var at: Vector3 = row["position"]
		var head: Vector3 = radar.head if radar != null and is_instance_valid(radar) else Vector3.ZERO
		var out: Vector3 = at - head
		var range_km: float = Vector2(out.x, out.z).length() / 1000.0
		var bearing: int = wrapi(roundi(rad_to_deg(atan2(out.x, -out.z))), 0, 360)
		return "%s\n%.1f km on %03d\n%d m, %d m/s\n%s" % [String(row.get("name", "?")), range_km, bearing,
			roundi(at.y), roundi(float(row.get("speed", 0.0))),
			"somebody aboard" if bool(row.get("manned", false)) else "nobody aboard"]
	# PICKED AND THEN GONE is a thing a controller must be able to SEE, not a thing the board quietly forgets: a
	# contact that drops off radar behind a ridge is exactly the event they are watching for.
	return "lost contact"


## HOW MANY CONTACTS FALL OUTSIDE THE MAP'S OWN EXTENT, and so are drawn off the canvas and clipped. Asked of the
## map itself (`LevelMap.to_map`, the projection every marker is placed by) rather than by comparing metres against
## a half-extent here -- the canvas places markers that way, so counting them any other way would be a second
## opinion about where the edge is.
func _off_the_plot(rows: Array[Dictionary]) -> int:
	if level_map == null:
		return 0
	var out: int = 0
	for row in rows:
		var at: Vector2 = level_map.to_map(row["position"] as Vector3)
		if at.x < 0.0 or at.y < 0.0 or at.x > float(LevelMap.PIXELS.x) or at.y > float(LevelMap.PIXELS.y):
			out += 1
	return out


func _pick(contact: int) -> void:
	_picked = contact
	_show()


func _a_label(words: String, colour: Color, size: int) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_color_override("font_color", colour)
	label.add_theme_font_size_override("font_size", size)
	return label
