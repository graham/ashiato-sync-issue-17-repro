extends Node
## THE OIL PLATFORM, PHOTOGRAPHED WHERE `OilField` PUT IT, in the sea of the level it stands in.
##
##   Godot --path cockpit --xr-mode off --resolution 1600x900 res://tests/oil_platform_shot.tscn -- --level=watch
##   ... -- --level=watch --out=C:/somewhere [--world=alpine]
##
## NOT HEADLESS -- it renders. Ten pictures, each the one a person asked to see: the classic silhouette from sea level,
## a helicopter's approach to the helideck, the jacket close at the splash zone, the whole thing from above, and the
## silhouette and the approach again at night with the flare and the deck lights, and the flare at night from 2 km, from
## a helicopter passing it and from a boat close in, and the silhouette at dusk. Four of the night views also MEASURE the
## flare's reflection on the bare sea (PATH_BAND, below).
##
## IT IS NOT FOR THE PICTURE ALONE. As `cooling_shot.gd` does for the towers, it first counts the platforms actually in
## the scene tree by the name `OilField` gives them and asks that each stands on its site, because a model proved by its
## own triangles would go on being proved for ever if nothing ever put it in the world. Then every picture projects the
## platform's own drawn corners and asks that they are in the frame, and asks the viewport which camera it drew with.
## Every picture carries the commit, whether the tree was dirty, the time, the view and the camera's height and range.

const DEFAULT_OUT: String = "user://"
const SETTLE: int = 90
## THE VIEWS: where the eye stands and what it looks at, both in the platform's frame (origin on the sea over the jacket's
## middle), the camera's vertical field of view, and the time of day. `frame` is whether the platform's whole above-water
## box must be in the picture; the close views are of a part of it on purpose.
const VIEWS: Array[Dictionary] = [
	{"id": "01-silhouette-from-sea-level", "eye": Vector3(-60.0, 4.0, 520.0), "at": Vector3(-18.0, 38.0, 0.0), "fov": 26.0,
		"time": DaylightTuning.When.DAY, "frame": true},
	{"id": "02-helicopter-approach-to-the-helideck", "eye": Vector3(230.0, 105.0, 70.0), "at": Vector3(20.0, 55.0, 0.0),
		"fov": 48.0, "time": DaylightTuning.When.DAY, "frame": true},
	{"id": "03-jacket-at-the-splash-zone", "eye": Vector3(62.0, 2.2, 58.0), "at": Vector3(24.0, 4.0, 18.0), "fov": 55.0,
		"time": DaylightTuning.When.DAY, "frame": false},
	{"id": "04-from-above-three-quarters", "eye": Vector3(170.0, 170.0, 190.0), "at": Vector3(-12.0, 30.0, 0.0),
		"fov": 45.0, "time": DaylightTuning.When.DAY, "frame": true},
	{"id": "05-night-silhouette-flare-and-deck-lights", "eye": Vector3(-60.0, 4.0, 520.0), "at": Vector3(-18.0, 38.0, 0.0),
		"fov": 26.0, "time": DaylightTuning.When.NIGHT, "frame": true, "sea": "path"},
	{"id": "06-night-approach-to-the-helideck", "eye": Vector3(230.0, 105.0, 70.0), "at": Vector3(20.0, 55.0, 0.0),
		"fov": 48.0, "time": DaylightTuning.When.NIGHT, "frame": true},
	# THE FLARE AS A LANDMARK, asked for by the user ("might be really cool at night"): from sea level 2 km off, and close
	# from a helicopter passing the flare boom.
	{"id": "07-night-flare-from-2-km-at-sea-level", "eye": Vector3(-700.0, 4.0, 1880.0), "at": Vector3(-30.0, 45.0, 0.0),
		"fov": 22.0, "time": DaylightTuning.When.NIGHT, "frame": true, "sea": "path"},
	{"id": "08-night-helicopter-passing-the-flare", "eye": Vector3(-20.0, 100.0, 95.0), "at": Vector3(-75.0, 70.0, -20.0),
		"fov": 60.0, "time": DaylightTuning.When.NIGHT, "frame": false, "sea": "dark"},
	# THE SAME SEAT LOOKING DOWN, 40 degrees below the horizon: from 100 m up the flame's mirror point is under 08's frame,
	# about 40 degrees below its axis, so 08 cannot show the reflection and this does (lane/flaresea, 2026-09-18).
	{"id": "08b-night-helicopter-looking-down-at-the-reflection", "eye": Vector3(-20.0, 100.0, 95.0),
		"at": Vector3(-60.0, 20.0, 10.0), "fov": 60.0, "time": DaylightTuning.When.NIGHT, "frame": false},
	# THE FLARE'S REFLECTION FROM A BOAT: low on the water and close in, where the glitter path under the flame runs
	# straight at the eye (lane/flaresea, 2026-09-18).
	{"id": "09-night-flare-reflection-from-a-boat", "eye": Vector3(-110.0, 3.0, 300.0), "at": Vector3(-80.0, 25.0, -20.0),
		"fov": 50.0, "time": DaylightTuning.When.NIGHT, "frame": false, "sea": "path"},
	# AND AT DUSK, when the flare is lit and the sky is not yet dark.
	{"id": "10-dusk-silhouette-flare-lit", "eye": Vector3(-60.0, 4.0, 520.0), "at": Vector3(-18.0, 38.0, 0.0),
		"fov": 26.0, "time": DaylightTuning.When.EVENING, "frame": true},
]
## THE FLARE'S REFLECTION, MEASURED ON THE BARE SEA. For a view tagged `"sea"` the platform's meshes (steel, flame, halo,
## lamps) are hidden for a frame, its engine lights left on, and every other pixel below the horizon is read for WARMTH,
## red over blue in 8-bit steps -- the moon's glitter is blue and counts nothing. A BAND is the columns within PATH_BAND of
## the frame's width either side of the flame. `"path"`: the band holds at least PATH_LEAST a pixel and PATH_OVER_SIDES
## times what the rest of the sea's width holds, which is a streak under the flame and not a pool of light round it.
## `"dark"`: from a helicopter over the platform, where the flame's mirror point is under the frame, the whole sea holds
## under DARK_MOST, which is no lit floor under the flame. Until 2026-09-18 the sea under the flare was a 120 m disc of
## noise added on the water: 08 was a warm floor, and 07 and 09 had no reflection at all (lane/flaresea).
const PATH_BAND: float = 0.06
const PATH_LEAST: float = 0.5
const PATH_OVER_SIDES: float = 4.0
const DARK_MOST: float = 1.0

var failures: PackedStringArray = []
var _out: String = DEFAULT_OUT
var _only: String = ""
var _level: FlightLevel = null
var _stamp: Label = null
var _commit: String = ""


func check(label: String, ok: bool, detail: String = "") -> void:
	print("[oil_platform_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures.append(label)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--out="):
			_out = String(arg).substr(6)
		if String(arg).begins_with("--only="):
			_only = String(arg).substr(7)
	if DisplayServer.get_name() == "headless":
		check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	_commit = _commit_stamp()
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	if _level.observer == null:
		check("there_is_somebody_watching", false, "pass --level=watch after the bare --")
		_finish()
		return
	var ui: Node = _level.get_node_or_null("Ui")
	if ui != null:
		ui.set("visible", false)
	# AND THE OBSERVER'S OWN BOARD ("WATCHING 85 vehicles"), which is drawn by the watching camera itself.
	for label in _level.observer.find_children("*", "Label", true, false):
		(label as Label).visible = false
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_stamp = Label.new()
	_stamp.position = Vector2(12.0, 8.0)
	_stamp.add_theme_font_size_override("font_size", 18)
	_stamp.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_stamp.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	_stamp.add_theme_constant_override("outline_size", 5)
	layer.add_child(_stamp)

	var sites: Array[Dictionary] = OilField.sites()
	check("the_world_has_an_oil_platform", sites.size() == OilField.PLATFORMS.size(), "%s" % [sites])
	if sites.is_empty():
		_finish()
		return
	var site: Dictionary = sites[0]
	var first: bool = true
	for view in VIEWS:
		if _only != "" and not String(view["id"]).contains(_only):
			continue
		await _look(site, view)
		if first:
			first = false
			var drawn: Array[Node] = _level.find_children("OilPlatform_*", "Node3D", true, false)
			check("the_platform_is_actually_in_the_scene_tree", drawn.size() == sites.size(),
				"%d drawn" % drawn.size())
			for node in drawn:
				var off: float = ((node as Node3D).global_position - (site["position"] as Vector3)).length()
				check("the_drawn_platform_stands_on_its_site", off < 0.01, "%.4f m from its site" % off)
	_finish()


func _look(site: Dictionary, view: Dictionary) -> void:
	var at: Vector3 = site["position"]
	_level.choose_time(int(view["time"]))
	var eye_at: Vector3 = at + (view["eye"] as Vector3)
	_level.observer.look_from(eye_at, at + (view["at"] as Vector3))
	for i in range(SETTLE):
		await get_tree().process_frame
		_level.observer.look_from(eye_at, at + (view["at"] as Vector3))
		(_level.observer as Camera3D).fov = float(view["fov"])
	var eye: Camera3D = get_viewport().get_camera_3d()
	check("%s_was_drawn_with_the_watching_camera" % view["id"], eye == _level.observer,
		"drew with %s" % [eye.name if eye != null else "nothing"])
	if eye == null:
		return
	# THE PLATFORM'S OWN ABOVE-WATER BOX, projected: its drawn extremes, flare tip to helideck edge.
	var frame: Vector2 = get_viewport().get_visible_rect().size
	var low := Vector3(OilPlatform.flare_tip().x, -2.0, -46.0)
	var high := Vector3(OilPlatform.HELIDECK_AT.x + OilPlatform.HELIDECK_ACROSS * 0.5, OilPlatform.derrick_crown().y, 36.0)
	var seen := Rect2()
	var started: bool = false
	var behind: int = 0
	for cx in [low.x, high.x]:
		for cy in [low.y, high.y]:
			for cz in [low.z, high.z]:
				var p: Vector3 = at + Vector3(cx, cy, cz)
				if eye.is_position_behind(p):
					behind += 1
					continue
				var s: Vector2 = eye.unproject_position(p)
				seen = Rect2(s, Vector2.ZERO) if not started else seen.expand(s)
				started = true
	var whole := Rect2(Vector2.ZERO, frame)
	if bool(view["frame"]):
		check("%s_has_the_platform_whole_in_the_frame" % view["id"], started and behind == 0 and whole.encloses(seen),
			"its corners span %s in %s, %d behind" % [seen, frame, behind])
	else:
		var middle: Vector2 = eye.unproject_position(at + (view["at"] as Vector3))
		check("%s_looks_at_its_subject" % view["id"], whole.has_point(middle), "the aim point is at %s" % middle)
	if view.has("sea"):
		await _measure_the_sea(eye, site, view)
	var range_m: float = eye.global_position.distance_to(at + (view["at"] as Vector3))
	_stamp.text = "%s  |  %s  |  %s  |  eye %.0f m over the sea, %.0f m off, %s, fov %.0f  |  %.0f m of water" % [
		_commit, Time.get_datetime_string_from_system(false, true), view["id"], eye.global_position.y - at.y, range_m,
		String(DaylightTuning.When.keys()[int(view["time"])]).to_lower(), float(view["fov"]), float(site["depth"])]
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var shot: String = "%s/cockpit-oilrig-%s.png" % [_out, view["id"]]
	var saved: int = get_viewport().get_texture().get_image().save_png(shot)
	check("%s_was_written" % view["id"], saved == OK, "%s -> %s" % [error_string(saved), ProjectSettings.globalize_path(shot)])


## THE WARM LIGHT ON THE BARE SEA, in the band under the flame and across the rest of the sea's width. See PATH_BAND.
func _measure_the_sea(eye: Camera3D, site: Dictionary, view: Dictionary) -> void:
	var drawn: Array[Node] = _level.find_children("OilPlatform_*", "Node3D", true, false)
	if drawn.is_empty():
		check("%s_has_a_platform_to_measure" % view["id"], false, "none drawn")
		return
	var hidden: Array[Node3D] = []
	for part in ["Structure", "Flare", "Lights", "Floods"]:
		var node := drawn[0].get_node_or_null(part) as Node3D
		if node != null and node.visible:
			node.visible = false
			hidden.append(node)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	for node in hidden:
		node.visible = true
	var at: Vector3 = site["position"]
	var flat: Vector3 = -eye.global_basis.z
	flat.y = 0.0
	var horizon: float = eye.unproject_position(eye.global_position + flat.normalized() * 20000.0
		+ Vector3.UP * (at.y - eye.global_position.y)).y
	var flame_x: float = eye.unproject_position(at + OilField.flame_middle()).x
	var band: float = PATH_BAND * float(image.get_width())
	var in_band := Vector2.ZERO
	var sides := Vector2.ZERO
	# NOT UNDER THE BUILD STAMP in the lower right (`BuildStamp`, 2026-09-18): it is in every picture on purpose, and its
	# letters are drawn over whatever is behind them, so they would count as sea either side of the flame's path, pale and cold.
	var stamp: Rect2i = BuildStamp.pixels()
	for y in range(maxi(int(horizon) + 3, 0), image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			if stamp.has_point(Vector2i(x, y)):
				continue
			var c: Color = image.get_pixel(x, y)
			var warmth: float = maxf(c.r - c.b, 0.0) * 255.0
			if absf(float(x) - flame_x) <= band:
				in_band += Vector2(warmth, 1.0)
			else:
				sides += Vector2(warmth, 1.0)
	var inside: float = in_band.x / maxf(in_band.y, 1.0)
	var outside: float = sides.x / maxf(sides.y, 1.0)
	var whole: float = (in_band.x + sides.x) / maxf(in_band.y + sides.y, 1.0)
	var numbers: String = "warmth a pixel %.2f under the flame, %.2f either side, %.2f over the sea; horizon row %.0f" % [
		inside, outside, whole, horizon]
	if view["sea"] == "path":
		check("%s_the_sea_reflects_the_flare_as_a_path" % view["id"],
			inside >= PATH_LEAST and inside >= PATH_OVER_SIDES * outside, numbers)
	else:
		check("%s_the_sea_under_the_flare_is_not_a_lit_floor" % view["id"], whole <= DARK_MOST, numbers)


## `<short commit>[+dirty]`, read from git beside the project, so a stale picture says so.
func _commit_stamp() -> String:
	var project: String = ProjectSettings.globalize_path("res://")
	var out: Array = []
	OS.execute("git", ["-C", project, "rev-parse", "--short", "HEAD"], out)
	var hash: String = String(out[0]).strip_edges() if not out.is_empty() else "?"
	var status: Array = []
	OS.execute("git", ["-C", project, "status", "--porcelain"], status)
	var dirty: bool = not status.is_empty() and String(status[0]).strip_edges() != ""
	return hash + ("+dirty" if dirty else "")


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL " + ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
