extends Node
## Headless: THE LOBBY, as a level. What a level says its arrivals stand in, and the briefing room it stands them in.
##
##   Godot --headless --path cockpit res://tests/lobby.tscn
##
## Asked for on 2026-09-15: "let's make a lobby level ... that has a briefing room where all players load ... there
## should be some joysticks and buttons (that don't do anything) in the lobby so players can prepare before loading
## into the level." The user decided the lobby is a LEVEL and not a room you visit (plan.md, item 2c): a level is what
## the whole session agrees about through `Net.level` and the hello, so segways replicate, the crew page lists them and
## joining a game already in progress is the ordinary join. A bare scene would need a second copy of all of that.
##
## WHAT EACH SECTION CAN FAIL ON, and what it read RED with when it was written:
##   1  `LevelChart` knowing nothing of `arrive` or `apart`: every check on them failed, "'arrive' is not a key a level
##      has".
##   2  `Sim._seat_new_clients` spawning `Kind.POD` whatever the level said: the walkabout fixture seated a pod.
##   3  there being no `room` world and no `levels/lobby`: the chart was refused, "its world 'room' is not one this
##      build stands a level on: island, alpine".
##   4  the briefing room's marks and props: nothing to find.
##
## THE FIXTURES ARE REAL FOLDERS, in `tests/lobby_fixtures/`, read by the same scan the game does.
##
## Read RESULT=, not the exit code.

const FIXTURES: String = "res://tests/lobby_fixtures"
## Frames to wait for a scene and a session: ten seconds at the project's 120 Hz.
const PATIENCE: int = 1200
## The bare host section 5 knocks on: the lane's own range, off every other suite's (lobby_peers 47970-47977,
## two_peers 47980-47989).
## Both are THIS CHECKOUT's (`TestPorts`), asked silently at load whether anything holds them. Held, and the suite says
## PORT BUSY at once rather than timing out.
static var JOIN_PORT: int = TestPorts.first_free(47978, 1)
## Where the desk's own "Host a game" listens when this suite presses it: `Net.usual_port`, set to this, so the button
## under test is the player's button and still does not take 7788 from every other lane's `lobby` (2026-09-18).
static var HOST_PORT: int = TestPorts.first_free(47979, 1)
## How long a segway is walked at a wall in section 4. Six seconds at the 3.2 m/s `ride_segway` walks is 19 m, which is
## half again the room's depth -- so a wall that is not there shows up as a walker in the next county.
const WALK_SECONDS: float = 6.0

var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[lobby] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## IT SURVIVES ITS OWN SCENE CHANGE the way tests/levels.gd does: the scene's root hangs a copy of this script on /root,
## so the suite is still there after `change_scene_to_file` has freed the scene it started in.
func _ready() -> void:
	if JOIN_PORT == 0 or HOST_PORT == 0:
		print("RESULT=FAIL port_busy %s" % TestPorts.busy(47978, 2))
		get_tree().quit(1)
		return
	Net.usual_port = HOST_PORT
	if get_tree().current_scene != self:
		_run()
		return
	var watcher := Node.new()
	watcher.name = "LobbyWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	_a_level_says_what_its_arrivals_stand_in()
	if ClassDB.class_exists("CockpitWorld"):
		await _a_session_seats_an_arrival_in_the_kind_its_level_names()
		await _the_lobby_is_a_level_whose_world_is_a_room()
		await _the_room_s_walls_reach_the_simulation()
		await _a_joiner_lands_in_the_hosts_level_and_not_its_own()
		await _a_session_nobody_chose_a_level_for_starts_where_its_kind_starts()
	else:
		_check("extension_loaded", false, "CockpitWorld missing")
	_check("every_section_of_the_suite_ran", _sections == 6, "%d of 6" % _sections)
	_finish()


## ---- 1: what a level says about its arrivals -----------------------------------------------------------------------

## A LEVEL SAYS WHAT ITS ARRIVALS STAND OR SIT IN, and how far apart they stand. Both were constants before: `Sim` spawned
## `Kind.POD` and put each one 14 m from the last, which is right for aeroplanes on a runway and absurd for eight people
## in a room. The kind is checked against the SIMULATION'S OWN LIST (`Sim.Kind`) rather than a roster kept here.
func _a_level_says_what_its_arrivals_stand_in() -> void:
	ChartDrawer.open_at(FIXTURES)
	var walkabout: LevelChart = ChartDrawer.chart("walkabout")
	var plain: LevelChart = ChartDrawer.chart("default_pod")
	_check("a_level_may_say_what_its_arrivals_stand_in", walkabout != null
		and walkabout.arrive_kind == Sim.Kind.SEGWAY,
		"walkabout arrives in %s" % [Sim.kind_name(walkabout.arrive_kind) if walkabout != null else "-"])
	_check("and_a_level_that_says_nothing_arrives_in_a_pod", plain != null and plain.arrive_kind == Sim.Kind.POD,
		"default_pod arrives in %s" % [Sim.kind_name(plain.arrive_kind) if plain != null else "-"])
	_check("and_says_how_far_apart_they_stand", walkabout != null and is_equal_approx(walkabout.apart, 1.8)
		and plain != null and is_equal_approx(plain.apart, LevelChart.APART_DEFAULT),
		"walkabout %.2f m, default %.2f m" % [walkabout.apart if walkabout != null else -1.0,
			plain.apart if plain != null else -1.0])
	# EVERY ARRIVAL'S PLACE FROM ONE FUNCTION, which the briefing room draws its floor marks from as well, so a mark can
	# never be somewhere nobody is put (CLAUDE.md, rule 4). Rows of `LevelChart.ROW` -- four as `Sim` laid them out
	# before, eight since the session went to sixty-four (lane/seats, 2026-09-18) -- read from there, not typed here.
	var row: int = LevelChart.ROW
	_check("and_where_each_of_them_goes", walkabout != null
		and walkabout.spot_for(0).is_equal_approx(walkabout.spawn_at)
		and walkabout.spot_for(1).is_equal_approx(walkabout.spawn_at + Vector3(1.8, 0.0, 0.0))
		and walkabout.spot_for(row).is_equal_approx(walkabout.spawn_at + Vector3(0.0, 0.0, 1.8)),
		"%s, %s, %s" % [walkabout.spot_for(0), walkabout.spot_for(1), walkabout.spot_for(row)] if walkabout != null
			else "no chart")
	# AND A LEVEL THAT NAMES SOMETHING THE SIMULATION HAS NOT GOT DISABLES ITSELF WITH A MESSAGE, rather than seating
	# everybody in kind -1. Rule 7: a malformed item takes itself off the desk and says why.
	var refused: Dictionary = {}
	for chart in ChartDrawer.refused():
		refused[chart.id] = chart.refusal
	_check("a_level_that_arrives_in_something_that_is_not_a_kind_is_refused",
		String(refused.get("bad_arrive", "")).contains("unicycle"), "'%s'" % refused.get("bad_arrive", "-"))
	_check("and_one_that_stands_every_arrival_in_the_same_place_is_refused",
		String(refused.get("bad_apart", "")).contains("apart"), "'%s'" % refused.get("bad_apart", "-"))
	_sections += 1


## ---- 2: the level decides, not Sim ---------------------------------------------------------------------------------

## THE REAL SEATING PATH: a solo session on the walkabout fixture, and what this machine's own player is standing in,
## read off the rig that is sitting in it. `Sim._seat_new_clients` is what spawns it, from the level's chart, exactly as
## it does for a joiner arriving at a host -- there is no second path for the local player.
func _a_session_seats_an_arrival_in_the_kind_its_level_names() -> void:
	for named in ["walkabout", "default_pod"]:
		ChartDrawer.open_at(FIXTURES)
		Sim.stop()
		Net.leave("suite")
		for i in range(10):
			await get_tree().physics_frame
		_check("the_suite_may_fly_%s" % named, Net.choose_level(named) == "", Net.choose_level(named))
		get_tree().change_scene_to_file("res://world/sky.tscn")
		var seated: bool = false
		for i in range(PATIENCE):
			var level := get_tree().current_scene as FlightLevel
			if level != null and level.rig != null and level.rig.is_seated() and level.rig.vehicle_view() != null:
				seated = true
				break
			await get_tree().physics_frame
		var level := get_tree().current_scene as FlightLevel
		var kind: int = level.rig.vehicle_view().kind if seated else -1
		var wanted: int = Sim.Kind.SEGWAY if named == "walkabout" else Sim.Kind.POD
		_check("a_player_arriving_on_%s_stands_in_a_%s" % [named, Sim.kind_name(wanted)],
			seated and kind == wanted, "seated %s in a %s, wanted a %s" % [seated, Sim.kind_name(kind),
				Sim.kind_name(wanted)])
	Sim.stop()
	Net.leave("suite over")
	_sections += 1


## ---- 3: the lobby itself -------------------------------------------------------------------------------------------

## THE LOBBY IS A LEVEL WHOSE WORLD IS A ROOM, and what is in it is what a player finds: eight marks on the floor where
## the eight arrivals are put, four desks with a joystick and three buttons each, and NO COUNTRY -- no traffic in the
## sky, no sea, no ground, no mist.
##
## Every question here is asked of the SCENE TREE the level built, by name and by type, rather than of a table the room
## keeps: a mark drawn where nobody is put, or a prop that never got added, is exactly what this has to catch. And the
## marks are compared against `LevelChart.spot_for`, which is what `Sim` puts the arrivals on.
func _the_lobby_is_a_level_whose_world_is_a_room() -> void:
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	var chart: LevelChart = ChartDrawer.chart("lobby")
	_check("the_lobby_is_a_level_this_build_can_stand", chart != null,
		"refusal '%s'" % _refusal_for("lobby"))
	if chart == null:
		_sections += 1
		return
	_check("and_its_world_is_a_room", chart.indoors() and chart.world == "room", "world '%s'" % chart.world)
	_check("and_its_arrivals_stand_on_segways", chart.arrive_kind == Sim.Kind.SEGWAY,
		"arrives in %s" % Sim.kind_name(chart.arrive_kind))
	Sim.stop()
	Net.leave("suite")
	for i in range(10):
		await get_tree().physics_frame
	_check("the_suite_may_fly_the_lobby", Net.choose_level("lobby") == "", Net.choose_level("lobby"))
	get_tree().change_scene_to_file("res://world/sky.tscn")
	var up: bool = false
	for i in range(PATIENCE):
		var flying := get_tree().current_scene as FlightLevel
		if flying != null and flying.level != null and flying.level.id == "lobby" and Sim.is_ready 				and flying.rig != null and flying.rig.is_seated():
			up = true
			break
		await get_tree().physics_frame
	# A FEW MORE FRAMES so the segway has settled onto the floor rather than being read mid-drop.
	for i in range(60):
		await get_tree().physics_frame
	var level := get_tree().current_scene as FlightLevel
	_check("and_a_player_loading_it_stands_in_the_briefing_room", up, "level %s, seated %s" % [
		level.level.id if level != null and level.level != null else "-",
		level.rig.is_seated() if level != null and level.rig != null else false])
	var room: Node3D = level.get_node_or_null("BriefingRoom") as Node3D if level != null else null
	_check("the_level_stands_a_briefing_room_up", room != null, "%s" % [room])
	# THE MARKS ON THE FLOOR, one per player a session holds, each where `Sim` puts that arrival.
	var marks: Array = room.find_children("Mark*", "MeshInstance3D", true, false) if room != null else []
	_check("it_has_a_mark_on_the_floor_for_every_player_a_session_holds", marks.size() == Net.MAX_PLAYERS,
		"%d marks, %d players" % [marks.size(), Net.MAX_PLAYERS])
	var worst: float = 0.0
	for i in range(marks.size()):
		var mark := marks[i] as Node3D
		var wanted: Vector3 = chart.spot_for(i)
		worst = maxf(worst, Vector2(mark.global_position.x - wanted.x, mark.global_position.z - wanted.z).length())
	_check("and_every_mark_is_where_that_arrival_is_put", not marks.is_empty() and worst < 0.01,
		"worst %.3f m from its spot" % worst)
	# AND EVERY MARK INSIDE THE WALLS, with a metre to spare, and the front row three metres short of the desks' wall. At
	# sixty-four players, four abreast ran sixteen rows back through the wall (lane/seats, 2026-09-18).
	var middle: Vector3 = BriefingRoom.middle_of(chart)
	var outside: PackedStringArray = []
	for mark in marks:
		var at: Vector3 = (mark as Node3D).global_position - middle
		if absf(at.x) > BriefingRoom.INSIDE.x - 1.0 or at.z > BriefingRoom.INSIDE.z - 1.0 \
				or at.z < -BriefingRoom.INSIDE.z + 3.0:
			outside.append("%s at (%.1f, %.1f)" % [(mark as Node3D).name, at.x, at.z])
	_check("and_every_mark_is_inside_the_room", not marks.is_empty() and outside.is_empty(),
		"%d marks in %.0f x %.0f m%s" % [marks.size(), 2.0 * BriefingRoom.INSIDE.x, 2.0 * BriefingRoom.INSIDE.z,
			"" if outside.is_empty() else ": " + ", ".join(outside.slice(0, 6))])
	# THE PROPS, WHICH DO NOTHING. Asked for on 2026-09-15: "some joysticks and buttons (that don't do anything)".
	var desks: Array = room.find_children("Desk*", "MeshInstance3D", true, false) if room != null else []
	var sticks: Array = room.find_children("Joystick*", "MeshInstance3D", true, false) if room != null else []
	var buttons: Array = room.find_children("Button*", "MeshInstance3D", true, false) if room != null else []
	_check("and_desks_with_joysticks_and_buttons_to_stand_at", desks.size() >= 4 and sticks.size() >= 4
		and buttons.size() >= 12, "%d desks, %d joysticks, %d buttons" % [desks.size(), sticks.size(), buttons.size()])
	# AND NOT ONE OF THEM IS A CONTROL. A prop with a script on it is a thing a hand can find; these are meshes and
	# nothing else, which is what "they don't do anything" has to mean for it to stay true.
	var scripted: PackedStringArray = []
	for prop in desks + sticks + buttons:
		if prop.get_script() != null:
			scripted.append(prop.name)
	_check("and_none_of_the_props_is_a_control", scripted.is_empty(), "%s" % [scripted])
	# AND NO COUNTRY. One vehicle in the world -- this machine's own segway -- and no ground, sea, swell or mist drawn.
	var drawn: PackedStringArray = []
	for named in ["Ground", "Sea"]:
		var node := level.get_node_or_null(named) as Node3D if level != null else null
		if node != null and node.visible:
			drawn.append(named)
	if level != null and level.swell != null and level.swell.visible:
		drawn.append("Swell")
	if level != null and level.mist != null:
		drawn.append("Mist")
	_check("and_the_room_has_no_country_round_it", drawn.is_empty() and Sim.current.size() == 1,
		"drawn %s, %d vehicles in the world" % [drawn, Sim.current.size()])
	Sim.stop()
	Net.leave("suite over")
	_sections += 1


## ---- 4: the walls are in the simulation, not only in the picture ---------------------------------------------------

## A ROOM YOU CAN WALK OUT OF IS A PICTURE OF A ROOM. The walls go into `Sim.add_static_box` and into the meshes from one
## list (`BriefingRoom.boxes`), and this is the half of that a headless suite can see: a segway walked at the far wall
## for six seconds stops against it and stays inside.
##
## THE CONTRAST IS KEPT AS A CASE rather than performed by breaking the room, the way tests/segway.gd keeps its POD:
## the same segway, the same stick, the same six seconds on a floor with NO room on it walks clean out through where the
## wall would be. If the boxes ever stop reaching the simulation, the first case fails; if the drive ever stops being a
## drive, the second does.
func _the_room_s_walls_reach_the_simulation() -> void:
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	var chart: LevelChart = ChartDrawer.chart("lobby")
	if chart == null:
		_check("the_lobby_is_there_to_walk_about", false, "no chart")
		_sections += 1
		return
	var middle: Vector3 = BriefingRoom.middle_of(chart)
	var inside_wall: float = middle.z - BriefingRoom.INSIDE.z
	var held: Vector3 = await _walk_into_the_wall(chart, true)
	var loose: Vector3 = await _walk_into_the_wall(chart, false)
	_check("a_segway_walked_at_the_wall_for_%ds_stops_inside_the_room" % int(WALK_SECONDS),
		held.z > inside_wall - 0.1 and held.z < chart.spot_for(0).z - 1.0,
		"stopped at z %.2f m, the wall's inside face at %.2f m, from %.2f m" % [held.z, inside_wall,
			chart.spot_for(0).z])
	_check("and_on_a_floor_with_no_room_on_it_the_same_drive_walks_straight_out",
		loose.z < inside_wall - 5.0, "reached z %.2f m, %.2f m past the wall" % [loose.z, inside_wall - loose.z])
	_sections += 1


## HOW FAR A SEGWAY GETS WALKING AT THE FAR WALL, from the level's own first spawn spot, in a bare world with a floor --
## the shape tests/segway.gd drives in, because what is being measured is the collision and not the level's frame rate.
## `with_the_room` decides whether the room's boxes are in the world at all.
func _walk_into_the_wall(chart: LevelChart, with_the_room: bool) -> Vector3:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	# The floor the room stands on, as the level lays it: the island's slab, top at y = 0.
	world.add_static_box(Vector3(0.0, -40.0, 0.0), Vector3(400.0, 40.0, 400.0))
	if with_the_room:
		for box in BriefingRoom.boxes(chart):
			world.add_static_box(box["position"], box["half_extents"])
	var at: Vector3 = chart.spot_for(0)
	var pilot: Dictionary = world.spawn_pilot(9100, Sim.Kind.SEGWAY, Vector3(at.x, 0.35, at.z), 0.0, Vector3.ZERO)
	var entity: int = int(pilot.get("pilot", 0))
	# PITCH FORWARD IS AHEAD on a segway, and ahead at a yaw of 0 is -z, which is the wall the desks stand against.
	for i in range(int(WALK_SECONDS * 120.0)):
		world.set_pilot_input(entity, _stick_forward())
		world.tick(1.0 / 120.0)
	var ended: Vector3 = (world.vehicle_state(int(pilot.get("vehicle", 0))) as Dictionary).get("position", Vector3.ZERO)
	world.teardown()
	await get_tree().process_frame
	return ended


## ONE INPUT FRAME with the stick pushed forward and nothing else held, as tests/segway.gd builds one.
func _stick_forward() -> Dictionary:
	return {
		"throttle": 0.0, "pitch": -1.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0,
	}


## ---- 5: putting a room in front of the world breaks nothing ---------------------------------------------------------

## JOINING A GAME ALREADY IN PROGRESS STILL WORKS, which is the part of the lobby most easily broken by putting a room in
## front of the world (plan.md, item 2d). A player who has chosen the lobby for themselves and then joins a host that is
## already flying must land in the HOST'S level, and must not stand in a briefing room while everybody else is in the air.
##
## THE HOST IS A BARE ENET SOCKET on the loopback, speaking through `Net.hear_hello`, which is tests/levels.gd's shape:
## what is being held is what the joiner does with what it is told, and a second process would only make that harder to
## see.
##
## THIS ONE PASSED THE FIRST TIME IT RAN, and that is said rather than dressed up: a joiner has taken its host's level
## since the hello went in, and `--world=` beside a join is already a BOOT_ERROR. It is here because the lobby is the
## first level that is NOT a place to fly, so "the joiner kept its own level" stops being a cosmetic bug and becomes a
## player standing in a room with no session in it. What it would catch is `_told_the_level` not overwriting `Net.level`.
func _a_joiner_lands_in_the_hosts_level_and_not_its_own() -> void:
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	Sim.stop()
	Net.leave("suite")
	for i in range(10):
		await get_tree().physics_frame
	# THIS MACHINE CHOSE THE LOBBY, as a player who has just been in one would have.
	_check("the_joiner_had_chosen_the_lobby_for_itself", Net.choose_level("lobby") == "" and Net.level == "lobby",
		"Net.level '%s'" % Net.level)
	var host := ENetMultiplayerPeer.new()
	var err: int = host.create_server(JOIN_PORT, 4)
	Net.join("127.0.0.1", JOIN_PORT)
	var asking: bool = false
	for i in range(PATIENCE):
		host.poll()
		if String(Net.get("_stage")) == "hello":
			asking = true
			break
		await get_tree().physics_frame
	# AND THE HOST IS ALREADY FLYING THE ISLAND.
	var island: LevelChart = ChartDrawer.chart(ChartDrawer.DEFAULT)
	Net.hear_hello(1, JSON.stringify({"say": "level", "protocol": Net.PROTOCOL, "level": island.id,
		"hash": island.content_hash, "name": island.name}).to_utf8_buffer())
	get_tree().change_scene_to_file("res://world/sky.tscn")
	var flying: bool = false
	for i in range(PATIENCE):
		host.poll()
		var level := get_tree().current_scene as FlightLevel
		if level != null and level.level != null:
			flying = true
			break
		await get_tree().physics_frame
	var level := get_tree().current_scene as FlightLevel
	_check("a_joiner_that_chose_the_lobby_lands_in_the_hosts_level", err == OK and asking and flying
		and level != null and level.level != null and level.level.id == island.id and Net.level == island.id,
		"host %s, asking %s, built '%s', Net.level '%s'" % [error_string(err), asking,
			level.level.id if level != null and level.level != null else "-", Net.level])
	_check("and_is_not_standing_in_a_briefing_room", level != null and level.room == null,
		"room %s" % [level.room if level != null else "-"])
	for i in range(10):
		host.poll()
		await get_tree().physics_frame
	host.close()
	Sim.stop()
	Net.leave("suite over")
	_sections += 1


## ---- 6: hosting starts in the lobby, playing alone starts on the island ---------------------------------------------

## THE USER, 2026-09-15: "let's make the lobby default when hosting a session. and island if they are playing alone."
##
## So the default is not one level any more, it is a rule about the kind of session -- and the half of it that would rot
## is the other half: **an explicit choice must still win.** `Net.level` is kept between sessions so the desk remembers
## what a player picked, and a player who picks the island on the chart monitor and then presses HOST must get the
## island. That is `Finish.suit_the_display`'s shape exactly: move an UNCHOSEN setting to the default, leave a chosen one
## where the player put it.
##
## PRESSED ON THE REAL SCREEN. Each of the three buttons is the `Button` the session screen built, pressed as a press
## emits, so what is being read is what the desk does with it and not what this suite thinks it does. The one thing that
## cannot be pressed is "nothing has been chosen yet": a fresh process starts there and this is one process, so the flag
## is put back by hand between cases, and that is the only part of the state this section sets itself.
func _a_session_nobody_chose_a_level_for_starts_where_its_kind_starts() -> void:
	for case in [{"press": "Fly on your own", "level": ChartDrawer.DEFAULT, "what": "playing alone", "paper": false},
			{"press": "Host a game", "level": ChartDrawer.HOSTING, "what": "hosting", "paper": false},
			{"press": "Host over Steam", "level": ChartDrawer.HOSTING, "what": "hosting over steam", "paper": true}]:
		var menu: SessionMenu = await _at_the_desk_with_nothing_chosen()
		# STEAM STANDS AS PAPER, the way every other Steam suite here stands it (`PaperLobbyDirectory`). Not to make the
		# press easier -- `Net.host_steam` runs either way -- but because asking the REAL directory whether it can be used
		# starts the Steam client (`SteamLobbyDirectory.unavailable` calls `steamInitEx`), and GodotSteam's matching
		# `steamShutdown` in a headless process then errors on a RenderingServer connection it never made:
		# "Attempt to disconnect a nonexistent connection ... Signal: 'frame_post_draw'". The runner fails a suite that
		# prints an engine error, and that error has nothing whatever to do with which level a session starts on.
		if bool(case["paper"]):
			Net.lobbies = PaperLobbyDirectory.new()
		if menu == null:
			_check("the_desk_came_up_for_%s" % String(case["what"]).replace(" ", "_"), false, "no session screen")
			continue
		_press(menu, String(case["press"]))
		_check("%s_starts_on_%s_when_nobody_chose" % [String(case["what"]).replace(" ", "_"), case["level"]],
			Net.level == String(case["level"]), "'%s' left Net.level '%s'" % [case["press"], Net.level])
		Sim.stop()
		Net.leave("suite")
		if bool(case["paper"]):
			# A FRESH ONE, which has not started Steam, so `Net._exit_tree` closes something with nothing open.
			Net.lobbies = SteamLobbyDirectory.new()
	# AND THE MONITOR SAYS SO. With nothing chosen there is no chosen level to mark, and marking one anyway would tell a
	# player they had picked the island when pressing HOST was about to fly the lobby. So: no row amber, the two
	# defaults named on their own rows, and the foot saying what each button will do.
	await _at_the_desk_with_nothing_chosen()
	var showing := get_tree().current_scene as DeskRoom
	var sheet := (showing.get("_charts") as TouchPanel).shown() as ChartMenu if showing != null else null
	var marked: PackedStringArray = []
	var labelled: Dictionary = {}
	if sheet != null:
		for id in sheet.level_buttons:
			var press := sheet.level_buttons[id] as Button
			if press.has_theme_color_override("font_color"):
				marked.append(String(id))
			labelled[id] = press.text
	_check("with_nothing_chosen_the_monitor_marks_no_level_as_chosen", sheet != null and marked.is_empty(),
		"marked %s" % [marked])
	_check("and_names_the_default_on_each_kind_of_row", String(labelled.get(ChartDrawer.HOSTING, "")).contains("hosting")
		and String(labelled.get(ChartDrawer.DEFAULT, "")).contains("on your own"),
		"%s" % [labelled])
	var foot: String = String(sheet.get("_said").text) if sheet != null and sheet.get("_said") != null else ""
	_check("and_the_foot_says_what_each_button_will_fly", foot.contains("hosting") and foot.contains("on your own"),
		"'%s'" % foot)
	# AND A CHOICE IS NOT OVERRULED. This is the check that would rot: the rule above is easy to write as an assignment
	# in `host()` and then a player can never host the island.
	var menu: SessionMenu = await _at_the_desk_with_nothing_chosen()
	var desk := get_tree().current_scene as DeskRoom
	var charts := (desk.get("_charts") as TouchPanel).shown() as ChartMenu if desk != null else null
	if charts != null and charts.level_buttons.has(ChartDrawer.DEFAULT):
		(charts.level_buttons[ChartDrawer.DEFAULT] as Button).pressed.emit()
	if menu != null:
		_press(menu, "Host a game")
	_check("but_a_level_chosen_on_the_monitor_is_still_flown_when_hosting", Net.level == ChartDrawer.DEFAULT
		and Net.level_chosen, "Net.level '%s', chosen %s" % [Net.level, Net.level_chosen])
	_check("and_the_monitor_marks_it_once_it_is_chosen", charts != null
		and charts.level_buttons.has(ChartDrawer.DEFAULT)
		and (charts.level_buttons[ChartDrawer.DEFAULT] as Button).text.contains("chosen")
		and (charts.level_buttons[ChartDrawer.DEFAULT] as Button).has_theme_color_override("font_color"),
		"'%s'" % [(charts.level_buttons[ChartDrawer.DEFAULT] as Button).text if charts != null
			and charts.level_buttons.has(ChartDrawer.DEFAULT) else "-"])
	Sim.stop()
	Net.leave("suite over")
	_sections += 1


## THE DESK, WITH NOTHING CHOSEN, as a player sees it the first time they sit down. Returns its session screen.
func _at_the_desk_with_nothing_chosen() -> SessionMenu:
	Sim.stop()
	Net.leave("suite")
	# WHAT A FRESH PROCESS STARTS AS. `Net` is an autoload and outlives a scene, so this is the one way back to it inside
	# one run; nothing else in this section sets any state of its own.
	Net.level = ChartDrawer.DEFAULT
	Net.level_chosen = false
	get_tree().change_scene_to_file(Doors.DESK)
	# WAITED FOR `_menu`, NOT FOR THE PANEL: `DeskRoom._ready` connects `_menu.chose` a frame after it builds the screen,
	# so a press on a screen that merely exists announces to nobody. See tests/no_vr_flight.gd.
	for i in range(PATIENCE):
		var desk := get_tree().current_scene as DeskRoom
		if desk != null and desk.get("_menu") != null:
			var menu := desk.get("_menu") as SessionMenu
			if menu != null:
				# THE DESK ENDS ANY SESSION AS IT COMES UP (`DeskRoom._ready`), so the flags are put back AFTER it, not
				# before: leaving a session is what `Net.leave` does and it does not touch a level choice.
				Net.level = ChartDrawer.DEFAULT
				Net.level_chosen = false
				desk.call("_show_the_levels")
				await get_tree().process_frame
				return menu
		await get_tree().physics_frame
	return null


## Press the button on a screen by the words on it, as a finger's press emits.
func _press(menu: SessionMenu, words: String) -> void:
	for node in menu.find_children("*", "Button", true, false):
		if (node as Button).text == words:
			(node as Button).pressed.emit()
			return


func _refusal_for(id: String) -> String:
	for chart in ChartDrawer.refused():
		if chart.id == id:
			return chart.refusal
	return "no such folder"


func _finish() -> void:
	Sim.stop()
	Net.leave("suite over")
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
