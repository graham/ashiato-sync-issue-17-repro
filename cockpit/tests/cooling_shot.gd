extends Node
## THE COOLING TOWERS, PHOTOGRAPHED IN THE WORLD THEY WERE PLACED IN.
##
##   Godot --path cockpit --xr-mode off --fixed-fps 60 res://tests/cooling_shot.tscn -- --level=watch
##   ... -- --level=watch --out=C:/somewhere --time=day|evening|night
##
## NOT HEADLESS -- it renders. Headless has no rendering device, so every picture comes back a black
## rectangle and every check on it passes on nothing.
##
## WHY IT EXISTS, AND IT IS NOT FOR THE PICTURE. `tests/cooling_towers.gd` proves the SHAPE of a tower
## from its own drawn triangles, and it would go on proving it for ever if `PowerStation` never put one in
## the world. That is not hypothetical: on 2026-09-17 `lane/train` found that no railway carriage had ever
## been drawn in this game, on any run since the railway was laid, because `sky.gd` kept the ids
## `spawn_train` returned -- the SERVER's -- and asked the client registry with them. Three suites walked
## the carriage list and none noticed, because all three walked it to HIDE the cars before taking a
## picture. A check whose job is to turn something off cannot tell you the something was never on.
##
## So the first thing this suite does is count the towers that are actually in the scene tree, by the name
## `PowerStation` gives them, and the second is to project their own drawn corners into the frame and
## require them to cover a share of it. A camera pointed at empty ground and a `save_png` that returned OK
## is exactly what the carriage bug looked like.
##
## AND IT LOOKS AT THE WHOLE THING FROM THE AIR, which is the one question a suite cannot ask: whether two
## 99 m towers beside a town read as a power station or as two grey funnels in a field.

const DEFAULT_OUT: String = "user://"
## WHERE EACH VIEW STANDS, as a multiple of the SUBJECT'S own height -- the tower and its steam together
## for the wide view, the tower alone for the close one -- and at half that height, so the camera looks
## along the middle of its subject instead of down at it. Worked out rather than tried: a subject `h` tall
## fits a 75-degree vertical field at `h / (2 tan 37.5)` = 0.65 h, and 1.2 h leaves room either side.
const BACK_WIDE: float = 1.2
const BACK_CLOSE: float = 1.9
## WHAT EACH VIEW IS FOR, AS A BAR. A single share of the frame for both views was the wrong shape of
## check and it took a picture to see why: at 75 degrees of vertical field you cannot have the whole of a
## 278 m plume in frame AND the towers filling a third of it, so one number had to be either loose enough
## for the wide view or impossible for it. So the two views are asked different questions, each the one
## its own picture exists to answer. BOTH must have every tower corner inside the frame and none behind
## the lens -- a camera that missed them, or stood inside one, fails whichever view it is.
##
## `close` is the view that shows the SHAPE, so its towers must stand at least this much of the frame's
## height. `three-quarter` is the view that shows the STATION, so the top of the steam must be in frame
## too; a picture of a power station with the plume cropped off is the picture nobody wanted.
const CLOSE_LEAST_TALL: float = 0.30
## Frames to let the yard build the cell before each picture. The scenery yard builds a few cells a frame
## on purpose, so a picture taken on arrival is a picture of the ground. NOT for the plume, which is whole
## on the frame it is first drawn (`tests/cooling_towers.gd:the_plume_is_whole_on_the_frame_it_is_first_drawn`).
const SETTLE: int = 90

## HOW MUCH NEARER THE CAMERA A FIRE MAY BE THAN THE TOWERS ARE, before it is a thing in the picture that
## can be mistaken for the towers' own steam. See `_say_where_the_fires_are`.
const FIRE_MAY_BE_AS_NEAR_AS: float = 0.8

var failures: PackedStringArray = []
var _out: String = DEFAULT_OUT
var _level: FlightLevel = null


func check(label: String, ok: bool, detail: String = "") -> void:
	print("[cooling_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures.append(label)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--out="):
			_out = String(arg).substr(6)
	if DisplayServer.get_name() == "headless":
		check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	if _level.observer == null:
		check("there_is_somebody_watching", false, "pass --level=watch after the bare --")
		_finish()
		return
	for hidden in ["Ui"]:
		var node: Node = _level.get_node_or_null(hidden)
		if node != null:
			# `Ui` IS A CanvasLayer, NOT A CanvasItem, so `as CanvasItem` is null and the status line ends
			# up in every picture. `set` works on both (`modelling_here.md` section 7).
			node.set("visible", false)

	var sites: Array[Dictionary] = PowerStation.sites()
	check("the_world_has_a_couple_of_cooling_towers_in_it", sites.size() == PowerStation.TOWERS_EACH,
		"%d sites: %s" % [sites.size(), _said(sites)])
	if sites.is_empty():
		_finish()
		return

	var middle := Vector3.ZERO
	for site in sites:
		middle += site["position"] as Vector3
	middle /= float(sites.size())

	await _look_from(middle, sites, "three-quarter")
	# THE TOWERS ARE FOUND ONLY AFTER THE EYE HAS BEEN NEAR THEM, because the yard builds a cell when it
	# comes within reach of the eye and not before. Asking before the first picture would be asking
	# whether the tower nobody has flown near yet has been drawn, which is a different question.
	var drawn: Array[Node] = _level.find_children("CoolingTower_*", "Node3D", true, false)
	check("both_towers_are_actually_in_the_scene_tree", drawn.size() == sites.size(),
		"%d drawn: %s" % [drawn.size(), _named(drawn)])
	_the_drawn_towers_stand_on_their_sites(drawn, sites)
	_a_tower_is_steaming(drawn)
	await _look_from(middle, sites, "close")
	_finish()


## ONE VIEW: the observer moved, the camera confirmed, the towers' own corners projected, the picture saved.
func _look_from(middle: Vector3, sites: Array[Dictionary], which: String) -> void:
	var tall: float = CoolingTower.overall_height()
	var subject: float = tall + CoolingTower.overall_height() * TowerPlume.CLIMBS 		if which == "three-quarter" else tall
	var back: float = subject * (BACK_WIDE if which == "three-quarter" else BACK_CLOSE)
	# ACROSS THE ROW, NOT ALONG IT. The first three-quarter picture stood on the station's own bearing and
	# the near tower hid the far one completely -- a picture of a couple of towers with one tower in it,
	# and every check green. The picture is
	# screenshots/2026-09-17/cockpit-cooling-02-plume-a-rope-and-one-tower-hiding-the-other.png. The camera
	# stands on the perpendicular to the line the towers are set out along, which `PowerStation` owns, and
	# is asked for rather than typed, so moving the station moves the camera with it.
	var bearing: float = float((PowerStation.STATIONS[0] as Dictionary)["bearing"]) + 90.0
	var across: Vector3 = Terrain.nose_from_yaw(deg_to_rad(bearing))
	var at: Vector3 = middle + across * back + Vector3.UP * (subject * 0.5)
	_level.observer.look_from(at, middle + Vector3.UP * (subject * 0.5))
	for i in range(SETTLE):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	# ASK THE VIEWPORT WHICH CAMERA IT ACTUALLY DREW WITH. `camera.is_current()` asks the thing under test;
	# a level that arrives a player takes the view back during the settle frames (`modelling_here.md`).
	var eye: Camera3D = get_viewport().get_camera_3d()
	check("the_%s_picture_was_drawn_with_the_watching_camera" % which, eye == _level.observer,
		"drew with %s" % [eye.name if eye != null else "nothing"])
	if eye == null:
		return
	var frame: Vector2 = get_viewport().get_visible_rect().size
	var seen := Rect2()
	var started: bool = false
	var behind: int = 0
	for site in sites:
		var stands: Vector3 = site["position"]
		for corner in [Vector3(-1.0, 0.0, -1.0), Vector3(1.0, 0.0, -1.0), Vector3(-1.0, 0.0, 1.0),
				Vector3(1.0, 0.0, 1.0)]:
			for high in [0.0, 1.0]:
				var point: Vector3 = stands + Vector3(corner.x * CoolingTower.ring_beam_radius(),
					high * tall, corner.z * CoolingTower.ring_beam_radius())
				if eye.is_position_behind(point):
					behind += 1
					continue
				var on_screen: Vector2 = eye.unproject_position(point)
				if not started:
					seen = Rect2(on_screen, Vector2.ZERO)
					started = true
				else:
					seen = seen.expand(on_screen)
	var whole := Rect2(Vector2.ZERO, frame)
	var inside: bool = started and behind == 0 and whole.encloses(seen)
	var tall_share: float = seen.size.y / frame.y if started else 0.0
	check("the_%s_picture_has_the_towers_whole_and_in_the_frame" % which, inside,
		"their corners span %s in a frame of %s, %d behind the lens" % [seen, frame, behind])
	if which == "close":
		check("the_close_picture_shows_the_towers_big_enough_to_judge",
			tall_share > CLOSE_LEAST_TALL,
			"they stand %.3f of the frame's height, at least %.3f" % [tall_share, CLOSE_LEAST_TALL])
	else:
		# THE TOP OF THE STEAM, which is the thing this view exists to show. Asked of the plume rather than
		# typed: `TowerPlume.CLIMBS` tower heights above the lip.
		var top: float = tall + CoolingTower.overall_height() * TowerPlume.CLIMBS
		var over: Vector3 = middle + Vector3.UP * top
		var plume_in: bool = not eye.is_position_behind(over) and whole.has_point(eye.unproject_position(over))
		check("the_three-quarter_picture_has_the_whole_plume_in_it", plume_in,
			"the top of the steam is %.0f m up, at %s in a frame of %s"
				% [top, eye.unproject_position(over) if not eye.is_position_behind(over) else "behind", frame])
	_say_where_the_fires_are(which, eye, middle, whole)
	var shot: String = "%s/cockpit-cooling-%s.png" % [_out, which]
	var saved: int = get_viewport().get_texture().get_image().save_png(shot)
	check("the_%s_picture_was_written" % which, saved == OK,
		"%s -> %s" % [error_string(saved), ProjectSettings.globalize_path(shot)])


## THE DRAWN TOWER IS WHERE THE CATALOGUE SAID, which is the other half of the carriage bug: a tower built
## at the origin while the site list says otherwise looks exactly like a tower built correctly to anything
## that only counts them.
func _the_drawn_towers_stand_on_their_sites(drawn: Array[Node], sites: Array[Dictionary]) -> void:
	var worst: float = 0.0
	for node in drawn:
		var nearest: float = INF
		for site in sites:
			nearest = minf(nearest, ((node as Node3D).global_position - (site["position"] as Vector3)).length())
		worst = maxf(worst, nearest)
	check("every_drawn_tower_stands_on_a_site", not drawn.is_empty() and worst < 0.01,
		"the furthest is %.4f m from its site" % worst)


## AND IT IS STEAMING. `TowerPlume.puff_at` is static and pure, so this asks where the puffs ARE rather
## than reading the MultiMesh back -- a MultiMesh read headless answers a default for every instance, and
## a check that reads one is asking the dummy driver (`world/lift_yard.gd` says so first).
func _a_tower_is_steaming(drawn: Array[Node]) -> void:
	var plumes: int = 0
	for node in drawn:
		plumes += node.find_children("*", "TowerPlume", true, false).size()
	var lip: float = CoolingTower.overall_height()
	var low: Dictionary = TowerPlume.puff_at(0, 0.0, lip, CoolingTower.top_radius(), 300.0, Vector3.ZERO)
	var high: Dictionary = TowerPlume.puff_at(0, TowerPlume.RISE_SECONDS * 0.5, lip,
		CoolingTower.top_radius(), 300.0, Vector3.ZERO)
	var leant: Dictionary = TowerPlume.puff_at(0, TowerPlume.RISE_SECONDS * 0.5, lip,
		CoolingTower.top_radius(), 300.0, Vector3(0.09, 0.0, 0.0))
	var rose: bool = (high["transform"] as Transform3D).origin.y > (low["transform"] as Transform3D).origin.y
	var leaned: bool = (leant["transform"] as Transform3D).origin.x \
		> (high["transform"] as Transform3D).origin.x + 1.0
	var starts_at_the_lip: bool = (low["transform"] as Transform3D).origin.y >= lip - 0.01
	check("every_tower_is_steaming", plumes == drawn.size() and not drawn.is_empty(),
		"%d plumes on %d towers" % [plumes, drawn.size()])
	check("the_steam_climbs_out_of_the_lip_and_leans_downwind", rose and leaned and starts_at_the_lip,
		"a puff starts at %.1f m (lip %.1f), is at %.1f m half a cycle later, and %.1f m downwind"
			% [(low["transform"] as Transform3D).origin.y, lip,
				(high["transform"] as Transform3D).origin.y,
				(leant["transform"] as Transform3D).origin.x - (high["transform"] as Transform3D).origin.x])


## SAY WHERE THE FIRES ARE, BESIDE THE PICTURE, BECAUSE A READER CANNOT TELL THEM APART.
##
## This island carries about a dozen hillside fires and `FireYard` draws each as a 260 m column of smoke
## that is never culled -- so a fire behind the towers is a pale column standing over them in frame, and
## nothing in the picture says which column belongs to what. `lane/train` met the same thing this morning
## from the other side: it read a smoke column behind its locomotive as the locomotive's own exhaust, and
## the column turned out to be one of these fires 1,139 m away. Reading a three-quarter view as though it
## were an elevation is how that happens, and the fix is not to take a better picture -- it is to PRINT THE
## DISTANCE, so the next person to ask the question has the answer beside the thing that prompted it.
##
## AND IT IS A CHECK, NOT JUST A PRINT. A fire NEARER the camera than the towers is not a caption problem,
## it is a fire that will be read as the towers' own steam by anyone who does not have this log.
func _say_where_the_fires_are(which: String, eye: Camera3D, middle: Vector3, whole: Rect2) -> void:
	var to_towers: float = eye.global_position.distance_to(middle)
	var in_frame: PackedStringArray = []
	var nearest: float = INF
	var too_near: int = 0
	for row in Sim.fires:
		var fire: Dictionary = row
		var at: Vector3 = fire["position"]
		var away: float = eye.global_position.distance_to(at)
		nearest = minf(nearest, away)
		if eye.is_position_behind(at):
			continue
		# The column, not the flame: what stands in the frame is 260 m of smoke over the fire.
		var top: Vector3 = at + Vector3.UP * FireYard.COLUMN_HEIGHT
		if not (whole.has_point(eye.unproject_position(at)) or whole.has_point(eye.unproject_position(top))):
			continue
		in_frame.append("%.0f m away at %v" % [away, at])
		if away < to_towers * FIRE_MAY_BE_AS_NEAR_AS:
			too_near += 1
	check("no_fire_in_the_%s_picture_can_be_mistaken_for_the_towers_steam" % which, too_near == 0,
		("the camera is %.0f m from the towers; %d of the island's %d fires are in frame (%s) and the "
			+ "nearest fire of any is %.0f m away") % [to_towers, in_frame.size(), Sim.fires.size(),
			", ".join(in_frame) if in_frame.size() > 0 else "none", nearest])


func _said(sites: Array[Dictionary]) -> String:
	var out: PackedStringArray = []
	for site in sites:
		out.append("%s#%d at %v" % [site["station"], int(site["index"]), site["position"]])
	return ", ".join(out)


func _named(nodes: Array[Node]) -> String:
	var out: PackedStringArray = []
	for node in nodes:
		out.append(node.name)
	return ", ".join(out)


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL " + ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
