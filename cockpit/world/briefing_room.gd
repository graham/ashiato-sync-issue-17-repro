extends Node3D
class_name BriefingRoom
## THE BRIEFING ROOM: the room the lobby level is, built in code, with a mark on the floor for every player a session
## holds and some desks to stand at that do nothing at all.
##
## Asked for on 2026-09-15: "let's make a lobby level, where players join ... that has a briefing room where all players
## load ... there should be some joysticks and buttons (that don't do anything) in the lobby so players can prepare
## before loading into the level."
##
## THE LOBBY IS A LEVEL AND THIS IS ITS WORLD, which the user decided the same day (plan.md, item 2c). A level is what
## the whole session agrees about -- `Net.level`, the hello, the joiner's refusal -- so a player in this room is an
## ordinary player in an ordinary session: the segway they stand on replicates because a level runs a `Sim` world, the
## CREW page lists them, and joining a game already in progress is the join it has always been. The rejected alternative
## was a bare scene like `hall.tscn`: nothing in a room like that is simulated or replicated, so two players in one
## would not see each other, and every piece of that would have had to be built a second time.
##
## IT IS BUILT IN CODE, not laid out in a `.tscn`, for the reason `CockpitHall._build_the_room` is: the room is sized and
## placed FROM THE LEVEL'S OWN SPAWN DATA, so a level file that moves its arrivals moves the room, the marks under them
## and the desks in front of them together. A hand-placed scene would be a second copy of the level's numbers.
##
## ONE LIST OF BOXES FOR THE COLLISION AND THE PICTURE. `boxes()` is static and is walked twice -- once by `FlightLevel`
## into `Sim.add_static_box`, once here for the meshes -- exactly as `Terrain.boxes()` is, and for the same reason: a
## wall drawn where the simulation has none is a wall you walk through, and a wall the simulation has and nobody drew is
## an invisible one you cannot. Neither looks like a level bug; both look like a networking fault.
##
## THE PROPS DO NOTHING, AND THAT IS ENFORCED BY WHAT THEY ARE. Every joystick and every button here is a
## `MeshInstance3D` with NO SCRIPT on it, so there is nothing for a hand or a pointer to find -- a rig looks for controls
## (`objects/controls/`), and a mesh is not one. `tests/lobby.gd` holds that: it counts the desks, the joysticks and the
## buttons off the tree by name and fails if any of them has a script.

## The room's inside, half-extents in metres: 20 m by 19 m and 2.6 m to the ceiling. Wide and deep enough that a full
## session's arrivals -- sixty-four in eight rows of eight at 1.8 m, 12.6 m a side (`LevelChart.ROW`) -- stand in the
## middle of it with three metres of floor in front of them to walk to the desks. It was 14 m deep for eight players in
## two rows of four; `tests/lobby.gd` holds that every mark is inside the walls.
const INSIDE := Vector3(10.0, 2.6, 9.5)
## How thick a wall, a ceiling and the floor slab are.
const WALL: float = 0.25
## THE FLOOR IS THE LEVEL'S GROUND, and the level's ground is the island's slab, whose top is y = 0 (`Terrain.GROUND_HALF`
## and `Terrain.surface_height` with no field standing). So the room stands at 0 and a spawn's y is its height above it.
const FLOOR: float = 0.0
## The desks: how many, how big, and how high the top of one is.
const DESKS: int = 4
const DESK_HALF := Vector3(0.7, 0.0, 0.35)
const DESK_TOP: float = 0.95
## How far the desks stand off the wall they face, and how many buttons are on each.
const DESK_OFF_THE_WALL: float = 1.4
const BUTTONS_EACH: int = 3
## A mark on the floor: how wide, and how thick the paint is.
const MARK_RADIUS: float = 0.45
const MARK_THICK: float = 0.01
## THE LAUNCH BOARD: the desk's own WHICH LEVEL screen, hung on the wall the briefing faces. Its page lays out on
## 1024 x 760 px, so the glass keeps that shape or the words are stretched.
const BOARD_PAGE := preload("res://ui/menus/chart_menu.tscn")
const ROSTER_PAGE := preload("res://ui/menus/roster_page.tscn")
const BOARD_WIDE: float = 2.2
const BOARD_ASPECT: float = 760.0 / 1024.0
## HOW HIGH THE MIDDLE OF THE BOARD IS, and how far its glass stands off the wall. Measured from the standing eye
## (`tests/lobby_shot.gd`): the desks hide anything on that wall below about 0.77 m, so the glass starts above them.
const BOARD_HIGH: float = 1.6
const BOARD_OFF_THE_WALL: float = 0.06

## A LEVEL WAS PRESSED ON THE LAUNCH BOARD. The room announces; the level decides (building_a_game_here.md, rule 5) --
## `FlightLevel` asks `Net.change_level` and puts the answer back on the glass.
signal chose_level(id: String)

var _marks: Array[MeshInstance3D] = []
var _props: Array[MeshInstance3D] = []
## THE LAUNCH BOARD, once it is up: the glass the level hands to the rig's pointer. See `_hang_the_board`.
var board: TouchPanel = null
var roster_board: TouchPanel = null


## THE MIDDLE OF THE ROOM: the middle of the block of arrivals the level puts in it, so the room is always round its
## own players. Y is the floor, not the spawn's height.
static func middle_of(chart: LevelChart) -> Vector3:
	var first: Vector3 = chart.spot_for(0)
	var last: Vector3 = chart.spot_for(maxi(0, Net.MAX_PLAYERS - 1))
	return Vector3((first.x + last.x) * 0.5, FLOOR, (first.z + last.z) * 0.5)


## EVERYTHING SOLID IN THE ROOM, as `Terrain.boxes()` gives it: {position, half_extents}, position at the box's centre.
## Four walls, a ceiling and the desks. NOT the floor: the level already stands the room on the island's slab, and a
## second box with its top in the same plane is two surfaces fighting over one contact.
static func boxes(chart: LevelChart) -> Array[Dictionary]:
	var middle: Vector3 = middle_of(chart)
	var half_high: float = INSIDE.y * 0.5
	var out: Array[Dictionary] = [
		# The two walls across z run the full width, so the corners are closed.
		{"position": middle + Vector3(0.0, half_high, -INSIDE.z - WALL),
			"half_extents": Vector3(INSIDE.x + 2.0 * WALL, half_high, WALL)},
		{"position": middle + Vector3(0.0, half_high, INSIDE.z + WALL),
			"half_extents": Vector3(INSIDE.x + 2.0 * WALL, half_high, WALL)},
		{"position": middle + Vector3(-INSIDE.x - WALL, half_high, 0.0),
			"half_extents": Vector3(WALL, half_high, INSIDE.z)},
		{"position": middle + Vector3(INSIDE.x + WALL, half_high, 0.0),
			"half_extents": Vector3(WALL, half_high, INSIDE.z)},
		{"position": middle + Vector3(0.0, INSIDE.y + WALL, 0.0),
			"half_extents": Vector3(INSIDE.x + 2.0 * WALL, WALL, INSIDE.z + 2.0 * WALL)},
	]
	for at in desk_places(chart):
		out.append({"position": Vector3(at.x, FLOOR + DESK_TOP * 0.5, at.z),
			"half_extents": Vector3(DESK_HALF.x, DESK_TOP * 0.5, DESK_HALF.z)})
	return out


## WHERE THE DESKS STAND: a row of them along the wall the arrivals face, spread across the width of it, on the floor.
## The arrivals look down -z with a yaw of 0, so the row is at -z.
static func desk_places(chart: LevelChart) -> Array[Vector3]:
	var middle: Vector3 = middle_of(chart)
	var out: Array[Vector3] = []
	var span: float = INSIDE.x * 1.2
	for i in range(DESKS):
		var across: float = -span * 0.5 + span * (float(i) + 0.5) / float(DESKS)
		out.append(middle + Vector3(across, 0.0, -INSIDE.z + DESK_OFF_THE_WALL))
	return out


## STAND THE ROOM UP round the level's arrivals. Called once per build by `FlightLevel`; the boxes it draws are the same
## list the level has already handed the simulation.
func stand_in(chart: LevelChart) -> void:
	var middle: Vector3 = middle_of(chart)
	_lay_the_floor(middle)
	_raise_the_walls(chart)
	_mark_the_places(chart)
	_put_the_desks_out(chart)
	_light_it(middle)
	await _hang_the_board(middle)
	await _hang_the_roster(middle)


func _hang_the_roster(middle: Vector3) -> void:
	roster_board = TouchPanel.new()
	roster_board.name = "RosterBoard"
	roster_board.page = ROSTER_PAGE
	roster_board.size = Vector2(BOARD_WIDE, BOARD_WIDE * BOARD_ASPECT)
	roster_board.pixels = 1024
	roster_board.position = middle + Vector3(2.55, BOARD_HIGH, -INSIDE.z + BOARD_OFF_THE_WALL)
	add_child(roster_board)
	await get_tree().process_frame
	var page := roster_board.shown() as RosterPage
	if page != null:
		page.chose.connect(func(player_name: String, colour: int) -> void:
			var why: String = Net.set_profile(player_name, colour)
			page.say("SAVED" if why == "" else why)
			roster_board.redraw())
		Net.roster_changed.connect(func() -> void: roster_board.redraw())


## THE LAUNCH BOARD, on the wall the desks face: the desk's own WHICH LEVEL screen (`ChartMenu`), hung where a room full
## of people can read it.
##
## IT IS THE SAME SCREEN, not a second one. The desk already has a page that lists every level `ChartDrawer` found, with
## its name and summary, and announces which was pressed -- so a folder added under `levels/` is a row here too, with no
## code touched. Building a second list would be the shape that lets the two disagree.
##
## AND IT IS NOT A PROP. The joysticks and the buttons on the desks do nothing on purpose; this is the one thing in the
## room that does something, which is why it is glass on a wall and they are shapes on a table.
##
## WORKED WITHOUT A HEADSET, which is item 0 of the plan: `FlightLevel` hands it to `PilotRig.pointer_panels`, the seam
## the desk's own monitors use, so on a desk the MOUSE points at it (a ray from the eye through the cursor,
## `GlassPointer`) and in a headset the pointing hand's beam does. Nothing here is headset-only.
func _hang_the_board(middle: Vector3) -> void:
	board = TouchPanel.new()
	board.name = "LaunchBoard"
	board.page = BOARD_PAGE
	board.size = Vector2(BOARD_WIDE, BOARD_WIDE * BOARD_ASPECT)
	board.pixels = 1024
	board.position = middle + Vector3(0.0, BOARD_HIGH, -INSIDE.z + BOARD_OFF_THE_WALL)
	add_child(board)
	# A FRAME, because a `TouchPanel` builds its page into a viewport as it enters the tree and `shown()` is null until
	# it has. The desk waits the same frame for the same reason.
	await get_tree().process_frame
	var charts := board.shown() as ChartMenu
	if charts == null:
		return
	charts.chose.connect(func(id: String) -> void: chose_level.emit(id))
	show_the_levels()


## WHAT THE BOARD SAYS: every level there is, with the one this session is on marked, and a line telling a player what
## pressing one does. Called when the room goes up and whenever the level answers a press.
func show_the_levels() -> void:
	var charts := board.shown() as ChartMenu if board != null else null
	if charts == null:
		return
	charts.show_levels(ChartDrawer.charts(), Net.level, true)
	charts.say("Press a level to launch it. Everybody goes.")
	board.redraw()


## PUT A LINE ON THE BOARD: what the level answered a press with. See `FlightLevel._launch_the_level`.
func say(text: String) -> void:
	var charts := board.shown() as ChartMenu if board != null else null
	if charts == null:
		return
	charts.say(text)
	board.redraw()


## WHERE EVERY ARRIVAL'S MARK IS, in world space: what the suite compares against `LevelChart.spot_for`.
func marks() -> PackedVector3Array:
	var out := PackedVector3Array()
	for mark in _marks:
		out.append(mark.global_position)
	return out


## EVERY PROP IN THE ROOM: {what, at}, `what` one of "desk", "joystick", "grip", "button". None of them does
## anything, and `props_are_inert` is what says so.
func props() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop in _props:
		out.append({"what": String(prop.name).to_lower().rstrip("0123456789_"), "at": prop.global_position})
	return out


## WHETHER NOT ONE PROP IS A THING A HAND COULD FIND: none of them carries a script, so none of them is a control.
func props_are_inert() -> bool:
	for prop in _props:
		if prop.get_script() != null:
			return false
	return true


func _lay_the_floor(middle: Vector3) -> void:
	add_child(_slab("Floor", Vector3(2.0 * (INSIDE.x + WALL), WALL, 2.0 * (INSIDE.z + WALL)),
		middle + Vector3(0.0, -WALL * 0.5, 0.0), Color(0.16, 0.17, 0.19), 0.9))


## THE WALLS AND THE CEILING, from the same list the simulation was given.
func _raise_the_walls(chart: LevelChart) -> void:
	var named: PackedStringArray = ["WallNorth", "WallSouth", "WallWest", "WallEast", "Ceiling"]
	var solid: Array[Dictionary] = boxes(chart)
	for i in range(mini(named.size(), solid.size())):
		var box: Dictionary = solid[i]
		var paint: Color = Color(0.30, 0.32, 0.36) if i < 4 else Color(0.44, 0.45, 0.48)
		add_child(_slab(named[i], 2.0 * (box["half_extents"] as Vector3), box["position"], paint, 0.85))
	# A WORD ON THE WALL, so a picture of this room says which room it is and a player looking round knows where they are.
	var sign := Label3D.new()
	sign.name = "Sign"
	sign.text = "BRIEFING ROOM"
	sign.font_size = 96
	sign.pixel_size = 0.003
	sign.modulate = Color(0.95, 0.78, 0.30)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	# HIGH ON THE WALL AND OFF TO ONE SIDE, because the launch board has the middle of it. See `_hang_the_board`.
	sign.position = middle_of(chart) + Vector3(-INSIDE.x * 0.55, 2.2, -INSIDE.z + 0.05)
	add_child(sign)


## A MARK ON THE FLOOR FOR EVERY PLAYER A SESSION HOLDS, each ASKED OF THE LEVEL (`LevelChart.spot_for`) rather than laid
## out again here: the marks and the arrivals cannot disagree, because they are the same numbers (CLAUDE.md, rule 4).
func _mark_the_places(chart: LevelChart) -> void:
	for i in range(Net.MAX_PLAYERS):
		var at: Vector3 = chart.spot_for(i)
		var ring := MeshInstance3D.new()
		ring.name = "Mark%d" % i
		var disc := CylinderMesh.new()
		disc.top_radius = MARK_RADIUS
		disc.bottom_radius = MARK_RADIUS
		disc.height = MARK_THICK
		ring.mesh = disc
		ring.position = Vector3(at.x, FLOOR + MARK_THICK * 0.5, at.z)
		ring.material_override = _paint(Color(0.22, 0.42, 0.58), 0.6)
		add_child(ring)
		_marks.append(ring)


## THE DESKS, AND THE JOYSTICK AND BUTTONS ON EACH. Every one of them is a mesh and nothing else: see the header.
func _put_the_desks_out(chart: LevelChart) -> void:
	var places: Array[Vector3] = desk_places(chart)
	var lamps: Array[Color] = [Color(0.72, 0.16, 0.14), Color(0.86, 0.66, 0.14), Color(0.20, 0.62, 0.28)]
	for i in range(places.size()):
		var at: Vector3 = places[i]
		var desk := _slab("Desk%d" % i, Vector3(2.0 * DESK_HALF.x, DESK_TOP, 2.0 * DESK_HALF.z),
			Vector3(at.x, FLOOR + DESK_TOP * 0.5, at.z), Color(0.21, 0.22, 0.25), 0.7)
		add_child(desk)
		_props.append(desk)
		# THE JOYSTICK: a column with a ball on top, standing on the desk at the near edge where a hand would fall.
		var stick := MeshInstance3D.new()
		stick.name = "Joystick%d" % i
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.022
		shaft.bottom_radius = 0.035
		shaft.height = 0.24
		stick.mesh = shaft
		stick.position = Vector3(at.x, FLOOR + DESK_TOP + 0.12, at.z + DESK_HALF.z * 0.4)
		stick.material_override = _paint(Color(0.08, 0.08, 0.09), 0.5)
		add_child(stick)
		_props.append(stick)
		var grip := MeshInstance3D.new()
		grip.name = "Grip%d" % i
		var ball := SphereMesh.new()
		ball.radius = 0.05
		ball.height = 0.1
		grip.mesh = ball
		grip.position = stick.position + Vector3(0.0, 0.14, 0.0)
		grip.material_override = _paint(Color(0.10, 0.11, 0.13), 0.4)
		add_child(grip)
		_props.append(grip)
		# AND THE BUTTONS, in a row across the far half of the desk top.
		for b in range(BUTTONS_EACH):
			var button := MeshInstance3D.new()
			button.name = "Button%d_%d" % [i, b]
			var cap := CylinderMesh.new()
			cap.top_radius = 0.028
			cap.bottom_radius = 0.028
			cap.height = 0.02
			button.mesh = cap
			var across: float = (float(b) - float(BUTTONS_EACH - 1) * 0.5) * 0.14
			button.position = Vector3(at.x + across, FLOOR + DESK_TOP + 0.01, at.z - DESK_HALF.z * 0.45)
			button.material_override = _paint(lamps[b % lamps.size()], 0.35)
			add_child(button)
			_props.append(button)


## THE ROOM'S OWN LIGHT. A room under a ceiling gets nothing from the level's sun, and `tests/lobby.gd` cannot see light
## at all -- so this is the half only the picture proves, which `tests/lobby_shot.gd` is for.
func _light_it(middle: Vector3) -> void:
	for x in [-0.55, 0.55]:
		for z in [-0.5, 0.5]:
			var lamp := OmniLight3D.new()
			lamp.name = "Lamp"
			lamp.position = middle + Vector3(INSIDE.x * float(x), INSIDE.y - 0.35, INSIDE.z * float(z))
			lamp.omni_range = 18.0
			lamp.light_energy = 3.0
			# NO SHADOWS: four shadow-casting omnis in a closed box is four shadow maps a frame for a room nobody is
			# fighting in, and Mobile is the renderer the game draws on.
			lamp.shadow_enabled = false
			add_child(lamp)


func _slab(named: String, size: Vector3, at: Vector3, paint: Color, rough: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = named
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.position = at
	node.material_override = _paint(paint, rough)
	return node


func _paint(colour: Color, rough: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = rough
	return material
