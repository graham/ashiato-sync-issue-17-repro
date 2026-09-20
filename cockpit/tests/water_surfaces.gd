extends Node
## EVERY WATER SURFACE IN THE GAME IS DRAWN WITH THE SEA'S OWN SHADERS -- and every lake is drawn at all.
##
##   Godot --headless --path cockpit res://tests/water_surfaces.tscn
##
## Asked for on 2026-09-17: "let's make sure we always use the good water shader". The audit behind it found the reel's
## river and the Savoia probe's pond flat StandardMaterial3D blue, the carrier deck's sea on the plain shader whatever
## the finish, and the generated ground's lakes not drawn as water anywhere. `WaterSurface` is now the one place water
## is dressed, and this holds everything to it:
##
##   EVERY USABLE LEVEL, flown the way a player flies it -- the level's button at the desk, then "Fly on your own", as
##   tests/level_swap.gd does -- and every surface in it named as water (Sea, Swell, Lake..., River, Water, Ocean, Pond)
##   wearing one of the two ocean shaders; at least one in every level.
##   EVERY LAKE the ground catalogues, on a level that has any, drawn in the lakes' one mesh, and drawn to the millimetre
##   at the water the simulation floats a hull on there (`Terrain.water_height`); and on the widest, a tanker taxiing
##   wakes on the lake's level and an aeroplane 2 m over it at 30 m/s sprays, measured from the lake.
##   THE CARRIER DECK'S SEA and THE REEL'S RIVER, each built as its scene builds it.
##   THE LEVEL'S COLOURS reach every water surface: `WaterSurface.dressed` hands `LevelChart.water` to both
##   shaders, a channel the level does not name stays the shader's default, and a level that says nothing is
##   the sea as it was -- proved by comparing the uniforms to a material that was never given a colour.
##
## Read RESULT=, not the exit code.

## The names a water surface goes by. A new pond named otherwise would slip past; a new pond is expected to be named for
## what it is, as every one before it was.
const WATER_NAMES: PackedStringArray = ["Sea", "Swell", "River", "Water", "Ocean", "Pond"]
## HOW FAR THE GROUND UNDER A LAKE'S OWN VERTEX MAY STAND ABOVE THAT LAKE'S LEVEL before that vertex counts as drawn
## over dry land, metres, AND WHAT SHARE OF A SHEET'S VERTICES MAY BE. Not zero and not none, because the sheet is
## sampled every 16 m and the ground between two samples is free to spike: a shore cut on the straight line between a
## wet sample and a dry one lands wrong wherever the real ground is not straight between them, and on a mountainside it
## is not.
##
## BOTH NUMBERS ARE MEASURED, on the five generated levels, 2026-09-20:
##   the 16 m grid this replaced     6.88, 7.78, 11.02, 7.70 and 7.54 % of vertices, worst overshoot 96 m
##   the waterline solved for        0.26, 0.19,  0.00, 0.11 and 0.17 %, worst overshoot 36 m
## So 1 % sits an order of magnitude under what the grid gave and four times over what the solved edge gives: it fails
## if the edge goes back to a grid, and it does not fail on the tail of steep shores that 16 m sampling cannot resolve.
## Resolving those is `todo/rivers--shoreline-on-steep-ground.md`.
const OVER_THE_LAND: float = 0.35
const OVER_THE_LAND_SHARE: float = 0.01
const PATIENCE: int = 2400
const SETTLE: int = 120

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[water_surfaces] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if get_tree().current_scene != self:
		_run()
		return
	# A WATCHER THAT OUTLIVES THIS SCENE, as level_swap's does: flying a level changes the current scene.
	var watcher := Node.new()
	watcher.name = "WaterWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld missing")
		_finish()
		return
	_the_carrier_decks_sea_is_the_seas()
	_the_reels_river_is_the_seas()
	_the_motion_gate_is_in_one_place()
	_the_level_colours_the_sea()
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	var ids: PackedStringArray = []
	for chart in ChartDrawer.charts():
		ids.append(chart.id)
	_check("there_are_levels_to_fly", not ids.is_empty(), "%s" % [ids])
	for id in ids:
		if not await _fly(id):
			_check("the_level_%s_came_up" % id, false, "the world never came up")
			continue
		await _every_water_surface_wears_the_seas_shader(id, get_tree().current_scene as FlightLevel)
	_finish()


## ---- the levels --------------------------------------------------------------------

func _every_water_surface_wears_the_seas_shader(id: String, level: FlightLevel) -> void:
	var found: Array[String] = []
	var wrong: Array[String] = []
	for node in level.find_children("*", "GeometryInstance3D", true, false):
		if not _named_as_water(node.name):
			continue
		found.append(String(node.name))
		if not WaterSurface.is_water((node as GeometryInstance3D).material_override):
			wrong.append("%s (%s)" % [node.name, (node as GeometryInstance3D).material_override])
			continue
		var drifted: String = _off_the_levels_colours((node as GeometryInstance3D).material_override as ShaderMaterial,
			level.level)
		if drifted != "":
			wrong.append("%s %s" % [node.name, drifted])
	_check("every_water_surface_in_%s_wears_the_seas_shader" % id, not found.is_empty() and wrong.is_empty(),
		"%d found: %s; not the sea's: %s" % [found.size(), found.slice(0, 8), wrong])
	# AND THE SEA IS NOT DRESSED INLAND. Without this the inland check below passes on a game that marks EVERYTHING
	# inland, which would take the swell off the sea itself and is the vacuous way to go green (lane/rivers).
	var sea_inland: Array[String] = []
	for node in level.find_children("*", "GeometryInstance3D", true, false):
		if String(node.name) in ["Sea", "Swell", "Ocean"] 				and WaterSurface.is_inland((node as GeometryInstance3D).material_override):
			sea_inland.append(String(node.name))
	_check("the_sea_in_%s_still_moves" % id, sea_inland.is_empty(), "dressed inland: %s" % [sea_inland])
	var field: Object = Terrain.standing_on()
	var catalogued: Array = ((field.call("catalogue") as Dictionary).get("lakes", []) as Array) if field != null else []
	if catalogued.is_empty():
		return
	var drawn: Array[Dictionary] = level.lakes.lakes_drawn() if level.lakes != null else []
	var sheet: MeshInstance3D = level.lakes.sheet() if level.lakes != null else null
	var missing: Array[String] = []
	var off: Array[String] = []
	var widest: Dictionary = {}
	var cells: int = 0
	for lake in drawn:
		cells += int(lake["cells"])
	for entry in catalogued:
		var centre := Vector2(float(int(entry["x"])), float(int(entry["z"])))
		var ticks: int = int(field.call("water_ticks_at", int(centre.x), int(centre.y)))
		if ticks <= ClassDB.class_get_integer_constant("GroundField", "NO_WATER"):
			continue
		# THE WATER THE SIMULATION FLOATS A HULL ON THERE, which the surface must be drawn at, to the millimetre.
		var water: float = Terrain.water_height(Vector3(centre.x, 0.0, centre.y))
		var seen: bool = false
		for lake in drawn:
			seen = seen or (lake["centre"] as Vector2).distance_to(centre) < 1.0
		if not seen:
			missing.append("(%.0f, %.0f) at %.2f m" % [centre.x, centre.y, water])
			continue
		var height: float = level.lakes.drawn_height_near(centre)
		if is_nan(height) or absf(height - water) > 0.001:
			off.append("(%.0f, %.0f): drawn at %.3f, floats at %.3f" % [centre.x, centre.y, height, water])
		if widest.is_empty() or float(entry.get("water_radius", 0)) > float(widest["radius"]):
			widest = {"centre": centre, "water": water, "radius": float(entry.get("water_radius", 0))}
	_check("every_lake_in_%s_is_drawn_as_water" % id,
		missing.is_empty() and sheet != null and WaterSurface.is_water(sheet.material_override)
			and sheet.is_visible_in_tree(),
		"%d lakes catalogued, %d drawn in %s, %d cells, %d vertices; not drawn: %s" % [catalogued.size(), drawn.size(),
			sheet, cells, (sheet.mesh as ArrayMesh).surface_get_array_len(0) if sheet != null else 0, missing.slice(0, 5)])
	_check("and_each_is_drawn_exactly_where_a_hull_floats_on_it", off.is_empty() and not drawn.is_empty(),
		"off: %s" % [off.slice(0, 5)])
	_the_edge_is_the_waterline(id, sheet, field)
	# AND THE SHEET IS DRESSED INLAND, so no lake is given the sea's swell, chop or wind-sea wherever it lies.
	# `tests/rivers_survey.gd` measured 30 of the 54 lakes on the generated levels standing outside the band that used
	# to be the only thing holding the sea off them -- the furthest 19 km out, against a `land_half` of 7,200 m.
	var furthest: float = 0.0
	for lake in drawn:
		furthest = maxf(furthest, maxf(absf((lake["centre"] as Vector2).x), absf((lake["centre"] as Vector2).y)))
	_check("and_no_lake_in_%s_is_given_the_seas_motion" % id,
		sheet != null and WaterSurface.is_inland(sheet.material_override),
		"the sheet is %s; the furthest lake is %.0f m out in the max-norm against land_half %.0f m"
			% ["dressed inland" if sheet != null and WaterSurface.is_inland(sheet.material_override) else "NOT inland",
				furthest, Terrain.WORLD_HALF])
	if not widest.is_empty():
		await _wakes_and_spray_land_on_a_lake(level, widest)


## THE SHEET'S EDGE IS THE WATERLINE, NOT A GRID. Every vertex of the lakes' mesh stands at its own lake's level -- the
## sheet is flat, so the vertex's own y IS that level -- and the ground under it may not stand ABOVE that, because water
## drawn over ground higher than itself is water drawn over dry land.
##
## THIS IS THE CHECK THE STAIRCASE FAILED. Until 2026-09-20 a 16 m cell was drawn whole if any one of its four corners
## was wet, so up to three of its vertices sat on land -- and the ground function raises a rim round every lake, holding
## the land above the water, so those vertices stood metres over dry ground. Seven to eleven per cent of every sheet's
## vertices were over land, the worst by 96 m. The edge is solved for the depth's zero crossing now, and the same
## reading is 0.00 to 0.26 %. Both numbers were taken by running this check against each version of `LakeSheets._lay`.
func _the_edge_is_the_waterline(id: String, sheet: MeshInstance3D, field: Object) -> void:
	if sheet == null or field == null:
		return
	var vertices: PackedVector3Array = (sheet.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return
	var points := PackedInt32Array()
	points.resize(vertices.size() * 2)
	for k in range(vertices.size()):
		points[k * 2] = roundi(vertices[k].x + sheet.global_position.x)
		points[k * 2 + 1] = roundi(vertices[k].z + sheet.global_position.z)
	var heights: PackedInt32Array = field.call("heights_at", points)
	var worst: float = -INF
	var over: int = 0
	for k in range(vertices.size()):
		var ground: float = float(heights[k]) / 32.0
		var above: float = ground - (vertices[k].y + sheet.global_position.y)
		worst = maxf(worst, above)
		if above > OVER_THE_LAND:
			over += 1
	var share: float = float(over) / float(vertices.size())
	_check("the_lakes_edge_in_%s_is_the_waterline_not_a_grid" % id, share <= OVER_THE_LAND_SHARE,
		"%d of %d vertices (%.2f %%, allowed %.2f %%) stand over ground above their own water by more than %.2f m; the worst is %.3f m"
			% [over, vertices.size(), share * 100.0, OVER_THE_LAND_SHARE * 100.0, OVER_THE_LAND, worst])


## A TANKER TAXIING ON A LAKE WAKES ON THE LAKE'S LEVEL, AND AN AEROPLANE 2 M OVER IT AT 30 M/S SPRAYS, MEASURED FROM IT.
func _wakes_and_spray_land_on_a_lake(level: FlightLevel, lake: Dictionary) -> void:
	var centre: Vector2 = lake["centre"]
	var water: float = float(lake["water"])
	var along := Vector3(1.0, 0.0, 0.0)
	var yaw: float = atan2(-along.x, -along.z)
	var afloat := Vector3(centre.x, water + 0.5, centre.y) - along * 100.0
	var tanker: int = Sim.spawn_vehicle(Sim.Kind.TANKER, afloat, yaw, along * 9.0)
	var plane_low: float = ((Sim.geometry_of(Sim.Kind.PLANE).get("extents", Vector3.ONE)) as Vector3).y
	var over := Vector3(centre.x, water + 2.0 + plane_low, centre.y + 150.0) - along * 100.0
	var plane: int = Sim.spawn_vehicle(Sim.Kind.PLANE, over, yaw, along * 30.0)
	var gone: float = 0.0
	var tanker_drawn: int = 0
	var plane_drawn: int = 0
	var plane_clearance: float = INF
	var plane_strength: float = 0.0
	while gone < 2.0:
		await get_tree().process_frame
		gone += get_process_delta_time()
		if gone < 0.3:
			plane_drawn = _nearest(over + along * 30.0 * gone, 30.0)
			if plane_drawn != 0 and level.spray.strength_of(plane_drawn) > plane_strength:
				plane_strength = level.spray.strength_of(plane_drawn)
				plane_clearance = level.spray.clearance_of(plane_drawn)
	tanker_drawn = _nearest(afloat + along * 9.0 * gone, 60.0)
	_check("a_tanker_taxiing_on_a_lake_wakes_on_the_lakes_level",
		tanker_drawn != 0 and level.wakes.strength_of(tanker_drawn) > 0.3
			and absf(level.wakes.water_under(tanker_drawn) - water) < 0.001,
		"waking %.2f on water at %.3f, the lake at %.3f" % [level.wakes.strength_of(tanker_drawn),
			level.wakes.water_under(tanker_drawn), water])
	_check("and_an_aeroplane_2_m_over_it_at_30_m_s_sprays_measured_from_it",
		plane_strength > 0.0 and plane_clearance > 1.0 and plane_clearance < 2.6,
		"spraying %.2f, lowest point %.2f m over the lake" % [plane_strength, plane_clearance])
	Sim.server.despawn_vehicle(tanker)
	Sim.server.despawn_vehicle(plane)


func _nearest(near: Vector3, within: float) -> int:
	var best: int = 0
	var nearest: float = within
	for entity in Sim.current:
		var away: float = ((Sim.current[entity] as Dictionary).get("position", Vector3.ZERO) as Vector3).distance_to(near)
		if away < nearest:
			nearest = away
			best = int(entity)
	return best


static func _named_as_water(called: String) -> bool:
	if called.begins_with("Lake"):
		return true
	return called in WATER_NAMES


## ---- the level's colours --------------------------------------------------------------

## A LEVEL THAT NAMES THE SEA'S COLOURS HANDS THEM TO BOTH SHADERS, A LEVEL THAT NAMES NONE LEAVES THE
## SHADER'S DEFAULTS, AND THOSE DEFAULTS ARE NOT COPIED INTO GDSCRIPT.
func _the_level_colours_the_sea() -> void:
	var none := LevelChart.new()
	none._take(_sheet({}))
	for fine in [false, true]:
		var wet: ShaderMaterial = WaterSurface.dressed(fine, none)
		var raw := ShaderMaterial.new()
		raw.shader = WaterSurface.FINE if fine else WaterSurface.PLAIN
		var off: PackedStringArray = _colour_drift(wet, raw)
		_check("a_level_that_says_nothing_leaves_%s_on_the_shaders_defaults" % ("fine" if fine else "plain"),
			WaterSurface.is_water(wet) and off.is_empty(), "%s" % [off])
	var named := LevelChart.new()
	named._take(_sheet({"water": {"deep": [0.012, 0.078, 0.102], "crest": [0.035, 0.155, 0.140],
		"foam": [0.88, 0.93, 0.92]}}))
	for fine in [false, true]:
		var wet: ShaderMaterial = WaterSurface.dressed(fine, named)
		var off: PackedStringArray = []
		for field in LevelChart.WATER_KEYS:
			var got: Vector3 = _rgb(wet.get_shader_parameter("%s_colour" % field))
			var wanted: Vector3 = named.water[field]
			if not got.is_equal_approx(wanted):
				off.append("%s %s against %s" % [field, got, wanted])
		_check("a_level_that_names_them_colours_%s" % ("fine" if fine else "plain"),
			WaterSurface.is_water(wet) and off.is_empty(), "%s" % [off])
	var partial := LevelChart.new()
	partial._take(_sheet({"water": {"deep": [0.2, 0.3, 0.4]}}))
	for fine in [false, true]:
		var wet: ShaderMaterial = WaterSurface.dressed(fine, partial)
		var raw := ShaderMaterial.new()
		raw.shader = WaterSurface.FINE if fine else WaterSurface.PLAIN
		var deep: Vector3 = _rgb(wet.get_shader_parameter("deep_colour"))
		var crest_off: PackedStringArray = PackedStringArray()
		for field in ["crest", "foam"]:
			if not _rgb(wet.get_shader_parameter("%s_colour" % field)).is_equal_approx(
					_rgb(raw.get_shader_parameter("%s_colour" % field))):
				crest_off.append(field)
		_check("a_missing_channel_on_%s_stays_the_shaders" % ("fine" if fine else "plain"),
			deep.is_equal_approx(Vector3(0.2, 0.3, 0.4)) and crest_off.is_empty(),
			"deep %s, drifted %s" % [deep, crest_off])
	var source: String = FileAccess.get_file_as_string("res://world/water_surface.gd") \
		+ FileAccess.get_file_as_string("res://world/level_chart.gd")
	_check("the_shaders_defaults_are_not_copied_into_gdscript",
		not source.contains("0.016, 0.055, 0.094") and not source.contains("0.028, 0.113, 0.106")
		and not source.contains("0.82, 0.88, 0.90"),
		"a default triple from the shader files is typed in GDScript")
	# AND THE SESSION'S LEVEL, the path every caller already takes: `dressed(fine)` with no chart.
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	var was: String = Net.level
	Net.level = ChartDrawer.DEFAULT
	var from_the_session: ShaderMaterial = WaterSurface.dressed(false)
	var island: LevelChart = ChartDrawer.chart(ChartDrawer.DEFAULT)
	var session_off: String = _off_the_levels_colours(from_the_session, island)
	_check("the_session_level_reaches_dressed_without_a_chart_passed", session_off == "" and island != null
		and island.water.is_empty(), "%s" % [session_off if session_off != "" else "island water %s" % [
			island.water if island != null else "-"]])
	Net.level = was


## WHETHER A WORN MATERIAL MATCHES THE LEVEL'S COLOURS, or the shader's defaults for every channel the level did
## not name. "" when it does.
func _off_the_levels_colours(wet: ShaderMaterial, chart: LevelChart) -> String:
	if wet == null or chart == null:
		return "no material or no chart"
	var raw := ShaderMaterial.new()
	raw.shader = wet.shader
	var off: PackedStringArray = []
	for field in LevelChart.WATER_KEYS:
		var got: Vector3 = _rgb(wet.get_shader_parameter("%s_colour" % field))
		var wanted: Vector3 = chart.water[field] if chart.water.has(field) else _rgb(
			raw.get_shader_parameter("%s_colour" % field))
		if not got.is_equal_approx(wanted):
			off.append("%s %s against %s" % [field, got, wanted])
	return ", ".join(off)


func _colour_drift(wet: ShaderMaterial, raw: ShaderMaterial) -> PackedStringArray:
	var off: PackedStringArray = []
	for field in ["deep_colour", "crest_colour", "foam_colour"]:
		if not _rgb(wet.get_shader_parameter(field)).is_equal_approx(_rgb(raw.get_shader_parameter(field))):
			off.append("%s %s against %s" % [field, _rgb(wet.get_shader_parameter(field)),
				_rgb(raw.get_shader_parameter(field))])
	return off


static func _rgb(value: Variant) -> Vector3:
	if value is Color:
		return Vector3((value as Color).r, (value as Color).g, (value as Color).b)
	if value is Vector3:
		return value
	return Vector3.INF


static func _sheet(extra: Dictionary = {}) -> Dictionary:
	var data := {"name": "A level", "summary": "A level for a test.", "world": "island",
		"spawn": {"at": [0, 30, 0], "yaw_degrees": 0}}
	for key in extra:
		data[key] = extra[key]
	return data


## ---- the scenes that draw their own water --------------------------------------------

## THE DECK'S SEA, as `CarrierDeck` lays it.
func _the_carrier_decks_sea_is_the_seas() -> void:
	var deck := CarrierDeck.new()
	deck.call("_sea", 0.0)
	var sea := deck.get_node_or_null("Sea") as GeometryInstance3D
	_check("the_carrier_decks_sea_wears_the_seas_shader", sea != null and WaterSurface.is_water(sea.material_override),
		"%s" % [sea.material_override if sea != null else "no Sea"])
	deck.free()


## THE REEL'S RIVER, as the reel builds its stage.
## THE SEA'S MOTION GATE IS IN ONE PLACE, AND ALL THREE FILES READ IT FROM THERE (house rule 4). `ocean.gdshader`,
## `ocean_fine.gdshader` and `sea_surface.gdshaderinc` each typed `max(|x|,|z|) - land_half` and the same
## `smoothstep(40, 260, ...)` for themselves, and a wake has to agree with the sea it lies on to the centimetre. They
## include `still_water.gdshaderinc` now; this fails if one of them types its own again.
func _the_motion_gate_is_in_one_place() -> void:
	const GATE: String = "res://world/shaders/still_water.gdshaderinc"
	var typed_their_own: Array[String] = []
	var missing_the_include: Array[String] = []
	for path in ["res://world/shaders/ocean.gdshader", "res://world/shaders/ocean_fine.gdshader",
			"res://world/shaders/sea_surface.gdshaderinc"]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			missing_the_include.append("%s is not there at all" % path)
			continue
		var code: String = file.get_as_text()
		var body: String = ""
		for line in code.replace("\r\n", "\n").split("\n"):
			if not line.strip_edges().begins_with("//"):
				body += line + "\n"
		if not body.contains(GATE):
			missing_the_include.append(path)
		if body.contains("uniform float land_half") or body.contains("smoothstep(40.0, 260.0"):
			typed_their_own.append(path)
	_check("the_seas_motion_gate_is_in_one_place", typed_their_own.is_empty() and missing_the_include.is_empty(),
		"typed their own: %s; not reading %s: %s" % [typed_their_own, GATE, missing_the_include])


func _the_reels_river_is_the_seas() -> void:
	var reel: Node = (load("res://tests/craft_video_demo.gd") as GDScript).new()
	reel.call("_build_scenery")
	var river := reel.get_node_or_null("River") as GeometryInstance3D
	_check("the_reels_river_wears_the_seas_shader", river != null and WaterSurface.is_water(river.material_override),
		"%s" % [river.material_override if river != null else "no River"])
	reel.free()


## ---- flying a level, as a player does -------------------------------------------------

func _fly(id: String) -> bool:
	if not get_tree().current_scene is DeskRoom:
		await _back_to_the_desk()
	var desk := get_tree().current_scene as DeskRoom
	var panel := desk.get("_panel") as TouchPanel if desk != null else null
	var menu := panel.shown() as SessionMenu if panel != null else null
	var shelf := desk.get("_charts") as TouchPanel if desk != null else null
	var charts := shelf.shown() as ChartMenu if shelf != null else null
	if menu == null or charts == null or not charts.level_buttons.has(id):
		return false
	(charts.level_buttons[id] as Button).pressed.emit()
	for node in menu.find_children("*", "Button", true, false):
		if (node as Button).text == "Fly on your own":
			(node as Button).pressed.emit()
			break
	var up: bool = await _wait_for(func() -> bool:
		var level := get_tree().current_scene as FlightLevel
		return level != null and level.level != null and level.level.id == id and Sim.is_ready)
	for i in range(SETTLE):
		await get_tree().physics_frame
	return up


func _back_to_the_desk() -> void:
	Doors.to_the_desk()
	await _wait_for(func() -> bool:
		var desk := get_tree().current_scene as DeskRoom
		return desk != null and desk.get("_menu") != null)
	for i in range(SETTLE):
		await get_tree().process_frame


func _wait_for(until: Callable) -> bool:
	for i in range(PATIENCE):
		if until.call():
			return true
		await get_tree().physics_frame
	return until.call()


func _finish() -> void:
	Sim.stop()
	Net.leave("suite over")
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
