extends Node
## WHAT THE RADAR HIDES, drawn: the same island, the same aircraft, plotted twice -- everything that is up there,
## and then only what one radar head can see. The contacts missing from the second picture are the ones behind rock.
##
##   Godot --xr-mode off --path cockpit res://tests/radar_shot.tscn
##
## WHY IT IS A PICTURE AND NOT A NUMBER. `tests/radar_set.gd` proves the sweep misses an aeroplane behind a peak and
## `tests/radar_peers.gd` proves two machines are sent different pictures. Neither can answer the question the user
## will actually ask, which is whether the shadow a mountain casts on a plot LOOKS like a mountain's shadow -- whether
## the hidden contacts fall where a person looking at the terrain would expect them to, or scattered about in a way
## that says the sight line is wired to something else (CLAUDE.md rule 2).
##
## THE CRAFT ARE REAL AND THE SWEEP IS REAL. They are spawned into a server world with the island's own mountains in
## it and read back through `vehicle_states`, and the second picture is `RadarSet.sweep`'s own output -- not a list
## this file filtered. `tests/map_shot.gd` hand-builds its rows because its question is about the DRAWING; this one's
## question is about which rows there are, so they have to come from the simulation.
##
## IN THE GAME'S OWN VIEWPORT, never the desktop: a ddagrab once caught another application on the user's screen.
##
## Read RESULT=, not the exit code.

const EVERYTHING: String = "user://radar_everything.png"
const SEEN: String = "user://radar_seen.png"
## How many aircraft to put up, and the spiral they stand on. Enough to cover the island so the mountains' shadow has
## something to fall across; a fixed spiral so two runs draw the same picture and a change in it is a change in the code.
const HOW_MANY: int = 90
const FIRST_OUT: float = 700.0
const STEP_OUT: float = 115.0
## The height they all fly at, metres. LOW ON PURPOSE -- below most of the island's rock, because a picture in which
## everything is above every summit is a picture with no shadow in it and proves nothing.
const FLYING_AT: float = 300.0
## How wide the drawn island is, metres, and how many samples across. 256 is 65,536 pyramid questions, which is a
## fraction of a second and gives a map a person can read ridges off.
const SPAN: float = 24000.0
const GRID: int = 256

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[radar_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[radar_shot] RESULT=FAIL windowed renderer required")
		get_tree().quit(1)
		return

	var island: Object = ClassDB.instantiate(&"MountainRange")
	island.call("configure", Terrain.mountain_values())
	var world: Object = ClassDB.instantiate(&"CockpitWorld")
	world.set_tick_rate(120)
	# THE SERVER, because `spawn_vehicle` refuses anything else and says nothing about it (`tests/radar_set.gd`).
	world.start(0)
	world.set_mountains(island)

	var kinds: Array[int] = [Sim.Kind.PLANE, Sim.Kind.AIRLINER, Sim.Kind.HELI, Sim.Kind.CESSNA, Sim.Kind.FIGHTER]
	for i in range(HOW_MANY):
		var turn: float = TAU * float(i) * 0.191
		var out: float = FIRST_OUT + STEP_OUT * float(i)
		world.spawn_ai_vehicle(kinds[i % kinds.size()],
			Vector3(cos(turn) * out, FLYING_AT, sin(turn) * out * 0.82), turn, Vector3.ZERO)
	world.tick(1.0 / 120.0)

	# THE HEAD IN THE MIDDLE OF THE MAP, which is where `RadarWatch` puts a controller's until the station exists.
	var head := Vector3.ZERO
	var manned: Dictionary = RadarSet.manned_vehicles(world)
	var seen: Array = RadarSet.sweep(world, head, manned)
	var everything: Array = []
	for state_any in world.vehicle_states():
		var state := state_any as Dictionary
		if int(state.get("kind", -1)) in AirPicture.NOT_TRAFFIC:
			continue
		everything.append(RadarSet.row_of(state, false))

	_check("the_sky_was_filled", everything.size() >= HOW_MANY - 2,
		"%d of %d aircraft stood up" % [everything.size(), HOW_MANY])
	# THE PICTURE HAS TO HAVE A SHADOW IN IT, or it is a picture of nothing: some are hidden and some are not.
	_check("the_rock_hides_some_of_them_and_not_all_of_them",
		seen.size() > 4 and seen.size() < everything.size() - 4,
		"%d of %d on radar, so %d are behind rock" % [seen.size(), everything.size(),
			everything.size() - seen.size()])

	build_island(self, island)
	var chart := LevelChart.new()
	chart.world = "island"
	var map := LevelMap.new()
	add_child(map)
	map.configure(chart)
	map.rebuild()
	await map.rebuilt
	var canvas := MapCanvas.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(canvas)

	var all_ok: int = await _draw(canvas, map, everything, EVERYTHING)
	var seen_ok: int = await _draw(canvas, map, seen, SEEN)

	print("[radar_shot] %d aircraft up, %d on radar from the middle of the map" % [everything.size(), seen.size()])
	_check("both_pictures_were_saved", all_ok == OK and seen_ok == OK,
		"%s, %s" % [error_string(all_ok), error_string(seen_ok)])
	_finish()


## ONE PLOT, SAVED. The rows are read back through `RadarSet.read` -- the same function a joiner's plot uses -- so
## what is photographed is what a machine receiving this picture would actually draw, and not a second rendering path.
func _draw(canvas: MapCanvas, map: LevelMap, rows: Array, path: String) -> int:
	var drawn: Array[Dictionary] = []
	for row in rows:
		var read: Dictionary = RadarSet.read(row as Array)
		if not read.is_empty():
			drawn.append(read)
	canvas.show_map(map, drawn)
	canvas.queue_redraw()
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var saved: int = image.save_png(path)
	print("[radar_shot] %d contact(s), %dx%d, saved %s to %s" % [drawn.size(), image.get_width(),
		image.get_height(), error_string(saved), ProjectSettings.globalize_path(path)])
	return saved


## THE ISLAND'S ROCK AS SOMETHING TO JUDGE THE SHADOW AGAINST, sampled from the mountains' OWN pyramid into a
## texture and laid flat under the plot.
##
## THE FIRST VERSION COPIED `tests/map_shot.gd`'s `_build_island`, which stands `Terrain.boxes()` up as grey blocks,
## and the picture came out as ninety contacts on an EMPTY GREEN FIELD -- because the island's mountains have not
## been boxes since they became a triangle mesh (`massif.hpp`), so there was nothing to draw. Both plots looked
## identical apart from the count, and the one question this shot exists to answer -- does the shadow fall where the
## rock is -- could not be asked of it at all. That is rule 2 catching a rule 2 test.
##
## SAMPLED, NOT GUESSED: `highest_over` is the same pyramid `SightLine` asks, so the rock a reader sees IS the rock
## that did the hiding. A west-lit hillshade on top of the height colour, because a flat height ramp reads as a
## stain and ridges are what a person is trying to match the missing contacts against.
## STATIC AND PUBLIC, so `tests/control_shot.gd` stands the same island under the same map rather than keeping a
## second copy of it (rule 4): two islands drawn from two samplers is two pictures that can come to disagree.
static func build_island(into: Node, island: Object) -> void:
	var sea := MeshInstance3D.new()
	var sea_mesh := BoxMesh.new()
	sea_mesh.size = Vector3(SPAN * 1.2, 4.0, SPAN * 1.2)
	sea.mesh = sea_mesh
	sea.position.y = -6.0
	sea.material_override = _a_material(Color("13405f"))
	into.add_child(sea)

	var picture := Image.create(GRID, GRID, false, Image.FORMAT_RGB8)
	var cell: float = SPAN / float(GRID)
	var heights := PackedFloat32Array()
	heights.resize(GRID * GRID)
	for row in range(GRID):
		for column in range(GRID):
			var x: float = -SPAN * 0.5 + float(column) * cell
			var z: float = -SPAN * 0.5 + float(row) * cell
			heights[row * GRID + column] = float(island.call("highest_over", x, z, x + cell, z + cell))
	for row in range(GRID):
		for column in range(GRID):
			var high: float = heights[row * GRID + column]
			if high <= 0.5:
				picture.set_pixel(column, row, Color("1b4e6e"))
				continue
			var west: float = heights[row * GRID + maxi(column - 1, 0)]
			# A WEST-LIT SLOPE: the rise over one cell, softened, so a face turned to the light is paler.
			var lit: float = clampf(0.5 + (high - west) / 120.0, 0.0, 1.0)
			var band: float = clampf(high / 700.0, 0.0, 1.0)
			var rock: Color = Color("4c6b46").lerp(Color("cfc9bb"), band)
			picture.set_pixel(column, row, rock.lerp(Color.BLACK, 0.35 * (1.0 - lit)))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(SPAN, SPAN)
	ground.mesh = plane
	ground.position.y = -1.0
	var painted := StandardMaterial3D.new()
	painted.albedo_texture = ImageTexture.create_from_image(picture)
	painted.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# THE TEXTURE IS SAMPLED ALONG +Z AS THE ROWS WERE WRITTEN, and a PlaneMesh's V runs the other way.
	painted.uv1_scale = Vector3(1.0, -1.0, 1.0)
	ground.material_override = painted
	into.add_child(ground)


static func _a_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	return material


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
