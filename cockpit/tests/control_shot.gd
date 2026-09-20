extends Node
## WHAT THE CONTROLLER'S STATION LOOKS LIKE, because a headless run cannot tell whether a plot is legible, whether
## the panel is readable beside it, or whether a person could pick a contact and know what they were looking at
## (CLAUDE.md rule 2).
##
##   Godot --xr-mode off --path cockpit res://tests/control_shot.tscn
##
## `tests/radar_peers.gd` proves the picture is the host's and is this machine's own. `tests/radar_shot.gd` proves
## the mountains' shadow falls where the rock is. This proves an operator can READ the result: that the plot and the
## side panel are one screen rather than two competing for it, and that a picked contact says the things a person
## would say on the radio.
##
## THE CONTACTS ARE A REAL SWEEP. `RadarSet.sweep` against a server world with the island's own mountains and ninety
## real aircraft in it, exactly as `radar_shot` does -- not rows this file wrote. What is staged is only the SESSION:
## a roster, a team each, and a `RadarWatch` handed the sweep it would have received. Staging the session is right,
## because the question here is about the drawing and the numbers are held by the suites above.
##
## TWO PICTURES, because the two states a controller sees are not alike:
##   1. NOTHING PICKED, which is how the station spends most of its time.
##   2. A CONTACT PICKED, with its range, bearing, height and speed on the panel -- the words a controller says.
##
## IN A SubViewport AND NEVER THE DESKTOP.
##
## Read RESULT=, not the exit code.

const IDLE_SHOT: String = "user://control_station.png"
const PICKED_SHOT: String = "user://control_station_picked.png"
const WIDTH: int = 1600
const HEIGHT: int = 900
const HOW_MANY: int = 90
const FLYING_AT: float = 300.0

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[control_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[control_shot] RESULT=FAIL windowed renderer required")
		get_tree().quit(1)
		return

	var island: Object = ClassDB.instantiate(&"MountainRange")
	island.call("configure", Terrain.mountain_values())
	var world: Object = ClassDB.instantiate(&"CockpitWorld")
	world.set_tick_rate(120)
	world.start(0)
	world.set_mountains(island)
	var kinds: Array[int] = [Sim.Kind.PLANE, Sim.Kind.AIRLINER, Sim.Kind.HELI, Sim.Kind.CESSNA, Sim.Kind.FIGHTER]
	for i in range(HOW_MANY):
		var turn: float = TAU * float(i) * 0.191
		var out: float = 700.0 + 115.0 * float(i)
		world.spawn_ai_vehicle(kinds[i % kinds.size()],
			Vector3(cos(turn) * out, FLYING_AT, sin(turn) * out * 0.82), turn, Vector3.ZERO)
	world.tick(1.0 / 120.0)
	var head := Vector3.ZERO
	var rows: Array = RadarSet.sweep(world, head, RadarSet.manned_vehicles(world))
	_check("the_sweep_found_contacts_to_draw", rows.size() > 8, "%d contact(s)" % rows.size())

	# THE ISLAND UNDER THE PLOT, from `radar_shot`'s own builder so the two pictures cannot draw two islands.
	load("res://tests/radar_shot.gd").call("build_island", self, island)
	var chart := LevelChart.new()
	chart.world = "island"
	var map := LevelMap.new()
	add_child(map)
	map.configure(chart)
	map.rebuild()
	await map.rebuilt

	# A SESSION WITH PEOPLE IN IT. Not in one -- `Net._keep_the_roster` republishes a host's roster every frame and
	# would wipe a staged one (`tests/lobby2d_shot.gd` learned that), and this station only READS the roster.
	var was_roster: Dictionary = Net.roster
	var was_host: bool = Net.is_host
	var built: int = int(Net.identity()["built"])
	Net.is_host = true
	Net.roster = {
		1: {"player": 1, "name": "CONTROL", "colour": 3, "built": built, "team": 0},
		2: {"player": 2, "name": "GRAHAM", "colour": 0, "built": built, "team": 1},
		3: {"player": 3, "name": "kestrel_77", "colour": 2, "built": built, "team": 1},
		4: {"player": 4, "name": "Sam Flies", "colour": 5, "built": built, "team": 2},
	}

	# THE WATCH, HANDED THE SWEEP IT WOULD HAVE RECEIVED. `rows` and `head` are what a real one holds after a publish,
	# so the station is exercised through the same seam and not with its labels written for it.
	var watch := RadarWatch.new()
	add_child(watch)
	watch.rows = rows
	watch.head = head
	watch.drawn_at = Time.get_ticks_msec()

	var glass := SubViewport.new()
	glass.size = Vector2i(WIDTH, HEIGHT)
	glass.transparent_bg = false
	glass.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(glass)
	BuildStamp.attach_to(glass)
	var station := ControlStation.new()
	station.size = Vector2(WIDTH, HEIGHT)
	station.level_map = map
	station.radar = watch
	glass.add_child(station)
	await get_tree().process_frame
	station.size = Vector2(WIDTH, HEIGHT)

	var idle: int = await _save(station, glass, IDLE_SHOT)

	# AND ONE PICKED: the farthest contact THAT IS ACTUALLY ON THE GLASS.
	#
	# THE FIRST VERSION TOOK THE FARTHEST OF ALL AND PHOTOGRAPHED NOTHING. `RadarSet.REACH_M` is 60 km and the
	# island's map covers about +/-8 km, so the farthest contact was 9.9 km out, projected off the west edge and
	# clipped -- the panel read "RESCUE 80, 9.9 km on 307" beside a plot with no ring on it anywhere. That is the
	# fault written up in `../../todo/flatcrew--contacts-past-the-edge-of-the-plot.md`, and the picture found it.
	#
	# A picture meant to show that picking WORKS must pick something visible; the fault has its own note and its own
	# count on the panel.
	var picked_contact: int = 0
	var best: float = -1.0
	for row in rows:
		var at := Vector3(float((row as Array)[1]), float((row as Array)[2]), float((row as Array)[3]))
		var on_map: Vector2 = map.to_map(at)
		var off: bool = on_map.x < 0.0 or on_map.y < 0.0
		off = off or on_map.x > float(LevelMap.PIXELS.x) or on_map.y > float(LevelMap.PIXELS.y)
		if off:
			continue
		if at.distance_to(head) > best:
			best = at.distance_to(head)
			picked_contact = int(RadarSet.read(row as Array)["contact"])
	_check("a_contact_on_the_glass_was_found_to_pick", picked_contact != 0,
		"the farthest inside the map is %.1f km out" % (best / 1000.0))
	station._pick(picked_contact)
	var picked: int = await _save(station, glass, PICKED_SHOT)

	Net.roster = was_roster
	Net.is_host = was_host
	_check("both_pictures_were_saved", idle == OK and picked == OK,
		"%s, %s" % [error_string(idle), error_string(picked)])
	_finish()


func _save(station: ControlStation, glass: SubViewport, path: String) -> int:
	station._show()
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = glass.get_texture().get_image()
	var saved: int = image.save_png(path)
	print("[control_shot] %dx%d, saved %s to %s" % [image.get_width(), image.get_height(),
		error_string(saved), ProjectSettings.globalize_path(path)])
	return saved


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
