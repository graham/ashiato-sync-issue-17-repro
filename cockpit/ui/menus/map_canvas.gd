extends Control
class_name MapCanvas
## Shared map presentation for the clipboard, the dedicated cockpit screen and the carrier's plot.
##
## IT DRAWS WHAT IT IS HANDED AND DECIDES NOTHING. Pressing a contact highlights it on this glass and
## nowhere else: no press here moves a craft, opens a seat or reaches the simulation at all
## (`building_a_game_here.md`, "announce, don't act"; `tests/air_picture.gd` holds it).
##
## A PERSON AND A MACHINE ARE TOLD APART FOUR WAYS AT ONCE, because one way is not enough to read in a
## second and a colour alone fails a colour-blind eye and a bad projector both:
##   FILL     a crewed craft is a solid arrow, a craft nobody is in is an open outline;
##   COLOUR   a crewed craft wears its player's own roster colour, every other contact is one steel grey
##            that is deliberately not in `PlayerColours.PALETTE` (`AirPicture.AI`);
##   LABEL    a crewed craft carries its player's name always, an AI contact only when it is picked;
##   SIZE     a crewed craft's arrow is half again as big.
## And a tally in the corner -- "6 PLAYERS / 34 AI" -- because a number is the fastest read on a board.

signal selected(contact: int)

var level_map: LevelMap
var markers: Array[Dictionary] = []
## The contact picked on THIS glass: a client id for a crewed craft, minus an entity for anything else,
## and -1 for none. Local to this surface and sent nowhere -- see `AirPicture`, "an AI contact has no
## call sign".
var selected_contact: int = -1
var marker_centres: Dictionary = {}


## A row's key on this plot. `contact` when the picture put one there; the client id for a hand-built row
## from before the air picture existed, which is what the crewed rows are keyed by anyway.
static func key_of(row: Dictionary) -> int:
	return int(row.get("contact", row.get("client", -1)))


func _ready() -> void:
	if get_parent() is SubViewport:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	queue_redraw()


func show_map(map: LevelMap, rows: Array[Dictionary]) -> void:
	if level_map != null and level_map.rebuilt.is_connected(_map_rebuilt):
		level_map.rebuilt.disconnect(_map_rebuilt)
	level_map = map
	if level_map != null and not level_map.rebuilt.is_connected(_map_rebuilt):
		level_map.rebuilt.connect(_map_rebuilt)
	markers = rows
	_locate_markers()
	queue_redraw()


func background_texture() -> Texture2D:
	return level_map.texture() if level_map != null else null


func _map_rebuilt(_revision: int) -> void:
	queue_redraw()
	# TouchPanel viewports sleep between changes. The new frozen background is a
	# change even when the marker rows have not moved.
	var host := get_parent() as SubViewport
	if host != null:
		host.render_target_update_mode = SubViewport.UPDATE_ONCE


func _locate_markers() -> void:
	marker_centres.clear()
	if level_map == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var scale := Vector2(size.x / LevelMap.PIXELS.x, size.y / LevelMap.PIXELS.y)
	for row in markers:
		marker_centres[key_of(row)] = level_map.to_map(row["position"] as Vector3) * scale


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not (event as InputEventMouseButton).pressed:
		return
	var click := (event as InputEventMouseButton).position
	# NEAREST WITHIN A FINGER, and a contact id may be negative, so "did we find one" is its own flag
	# rather than a sign test on the answer.
	var nearest := -1
	var found := false
	var distance := 30.0
	for contact in marker_centres:
		var apart: float = click.distance_to(marker_centres[contact] as Vector2)
		if apart < distance:
			distance = apart
			nearest = int(contact)
			found = true
	if found:
		selected_contact = nearest
		selected.emit(nearest)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("102033"))
	_locate_markers()
	if level_map == null:
		draw_string(ThemeDB.fallback_font, Vector2(18, 32), "MAP UNAVAILABLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffbd59"))
		return
	var tex := background_texture()
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false, Color(0.72, 0.78, 0.82))
	var mine := Vector2.ZERO
	var has_mine := false
	for row in markers:
		if bool(row.get("yours", false)):
			if not marker_centres.has(key_of(row)):
				continue
			mine = marker_centres[key_of(row)] as Vector2
			has_mine = true
	if marker_centres.has(selected_contact) and has_mine:
		var target := marker_centres[selected_contact] as Vector2
		draw_dashed_line(mine, target, Color("ffe18a"), 3.0, 10.0)
	# THE TRAFFIC FIRST AND THE PEOPLE OVER IT. With a hundred and forty machines in the air a player's
	# arrow drawn in list order disappears under the next contact to cross it, and the one marker an
	# operator is looking for is the one that has to be on top.
	# A ROW WITH NO PLACED CENTRE IS SKIPPED RATHER THAN INDEXED. `_locate_markers` gives up without placing anything
	# when this canvas has no size yet or no map, and `_draw` can still run in that state -- so reading the dictionary
	# straight threw "Out of bounds get index" once a frame, for ever, on a canvas laid out a frame later than its
	# rows arrived (lane/flatcrew, `world/control_station.gd`, the first canvas here not inside a sized SubViewport).
	# The harness fails a run on the first engine error, so a widget that shouts every frame is a widget that fails
	# every suite that draws it.
	for row in markers:
		if not bool(row.get("manned", true)) and marker_centres.has(key_of(row)):
			_draw_marker(row, marker_centres[key_of(row)] as Vector2)
	for row in markers:
		if bool(row.get("manned", true)) and marker_centres.has(key_of(row)):
			_draw_marker(row, marker_centres[key_of(row)] as Vector2)
	_draw_tally()


## THE COUNT, top left: how much of what is on this glass is a person. It is the first thing an operator
## checks and the cheapest thing on the board to read.
func _draw_tally() -> void:
	var tally: Dictionary = AirPicture.tally(markers)
	var font := ThemeDB.fallback_font
	var words := "%d PLAYERS" % int(tally["players"])
	var rest := "  /  %d AI" % int(tally["ai"])
	var wide := font.get_string_size(words + rest, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_rect(Rect2(Vector2(10, 10), Vector2(wide + 22, 32)), Color(0.04, 0.07, 0.11, 0.78))
	draw_string(font, Vector2(21, 33), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e8f1f7"))
	draw_string(font, Vector2(21 + font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, 33),
		rest, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, AirPicture.AI)


func _draw_marker(row: Dictionary, at: Vector2) -> void:
	var manned := bool(row.get("manned", true))
	var colour := row.get("colour", Color.WHITE) as Color
	var picked := key_of(row) == selected_contact
	var radius := (13.0 if bool(row.get("yours", false)) else 9.0) if manned else 6.0
	var heading := float(row.get("heading", 0.0))
	var forward := Vector2(sin(heading), -cos(heading))
	var across := forward.orthogonal()
	var nose := at + forward * radius * 1.5
	var port := at - forward * radius + across * radius
	var starboard := at - forward * radius - across * radius
	if manned:
		# SOLID, and outlined in near-black so a pale roster colour still reads over pale ground.
		draw_colored_polygon(PackedVector2Array([nose, port, starboard]), colour)
		draw_polyline(PackedVector2Array([nose, port, starboard, nose]), Color(0.05, 0.07, 0.09, 0.85), 2.0)
	else:
		# OPEN, and thin. Nothing fills it, which is the difference a person reads before they read a
		# colour at all.
		draw_polyline(PackedVector2Array([nose, port, starboard, nose]), colour, 2.0)
	if picked:
		draw_arc(at, radius * 1.9, 0.0, TAU, 24, Color("ffe18a"), 3.0)
	# A PERSON IS ALWAYS NAMED; a machine is named only when it is picked, or a hundred and forty labels
	# cover the island and the six that matter are lost in them.
	if not manned and not picked:
		return
	var words := String(row.get("name", "PLAYER"))
	if picked and float(row.get("distance", -1.0)) >= 0.0:
		words += "  %.1f km" % (float(row["distance"]) / 1000.0)
	draw_string(ThemeDB.fallback_font, at + Vector2(radius * 1.7, 6.0), words,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18 if manned else 15, colour)
