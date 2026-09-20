extends Node
## ONE PICTURE OF EVERY BUILDING THIS GAME DRAWS, so the world's architecture can be looked at during development.
##
##   Godot --xr-mode off --path cockpit --resolution 1600x900 res://tests/buildings_gallery_shot.tscn -- --level=watch --finish=plain
##   cockpit\buildings_gallery.bat --finish=plain     (Windows)     cockpit/buildings_gallery.sh --finish=plain     (Linux)
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device. Listed in `tests/docs.gd`'s PROBES, never in
## `suites.txt`. It is the buildings' answer to `tests/craft_gallery_shot.gd` and is built on that file's pattern: it
## brings up the level the game starts on (or `--world=<level id>`, chosen through `ChartDrawer.asked_in` and
## `Net.choose_level` exactly as boot does, because this builds the level itself and boot never reads the flag), lets the
## world build itself, and photographs each building from ahead and above, three-quarters on, at a distance that fits it
## in the frame.
##
## WHAT A SUBJECT IS, AND WHY IT IS A KIND AND NOT AN INSTANCE. The air base draws three hangars, but two of them are
## the same type I shed; the island draws about 1,600 town buildings, and no two are the same box. So the unit here is
## THE KIND, taken from whichever authority already decides it, never from a roster typed beside it:
##
##   - the AIR BASE: one picture per entry in the base's own `standards.hangar_types` (type I gable, type III arch), one
##     per revetment block, and the control tower -- which is a `Sim.Kind` and so is also in the craft gallery, and is a
##     building, so it is here too;
##   - the TOWNS: one picture per `TownPlan.Roof` -- FLAT, PLANT, PITCHED, SETBACK -- because that enum is what a town
##     building actually varies by (`TownView.building_custom` hands the shader nothing else but its height and a hash).
##     The member photographed is the TALLEST of its kind, which is deterministic and the one worth looking at. REJECTED:
##     a picture of each of the six towns in `TownCatalogue`, which photographs a PLACE and not a building, and which
##     `tests/town_lights_shot.gd` already does better from the air;
##   - the STANDALONE buildings, which are a node of their own: Hangar 03 today, and `lane/cooling`'s cooling tower and
##     its steam plume when they land. ADDING ONE IS ONE LINE IN `STANDALONE`.
##
## THE SIZE IS MEASURED FROM WHAT WAS DRAWN, never typed here and never `transform * get_aabb()`, which grows a box every
## time it is turned: from the batched boxes `AirbaseView.structure_pieces` handed its MultiMesh and the vertices of the
## roof mesh beside them, from the building box the simulation was given and `TownView` drew, and from the vertices of
## every visible mesh under a standalone node or a craft view.
##
## THE LIVE TOWER IS FOUND IN `Sim.current` BY ITS KIND, never by a spawn's returned id, which is the SERVER's
## (`tests/hawkeye_shot.gd` photographed a patrol boat eight times that way, and `lane/train` found the same class of bug
## had silently emptied every train in the game).
##
## TWO THINGS EVERY PICTURE CARRIES, both paid for on 2026-09-17:
##
##   WHEN IT WAS TAKEN, AND OFF WHAT. `lane/audit` found the craft gallery's `tower` photographed at 10:42, fixed at
##   13:01, and still reading as broken in a two-hour-old PNG, because nothing in the picture said how old it was. Every
##   picture here carries the short commit, whether the tree was dirty, and the time.
##
##   WHAT ELSE IS IN THE FRAME. team-lead read a steam plume off a gallery picture of the train; it was a fire 1,139 m
##   behind the locomotive, lined up by the camera. A reader of a picture cannot tell those two apart, so every picture
##   here names its nearest other building and how far off it stands -- the thing most likely to be mistaken for the
##   subject.
##
## `--level=watch` is what gives the level a camera and nobody in a seat. `--finish=plain|fine` (plain), `--time=day|
## evening|night` (day), `--only=<id>[,<id>]` (all), `--out=<dir>` (the repo's `screenshots/<today>/`), and
## `--over=<town>[,<town>]` for one extra picture of a whole town with its roof counts in the caption -- for a change
## that is about many buildings at once rather than one building (see `_town_overviews`).
## Pictures: `cockpit-building-<id>.png`.

## THE BUILDINGS THAT ARE A NODE OF THEIR OWN, built into the level for their picture and freed after it.
##
## A NEW ONE IS ONE LINE HERE. `script` is the file, `id` names the picture, `title` is the caption's first line, and
## `settle` is how many frames it is given before the shutter -- a plume needs frames to develop, and a probe that
## photographs frame one gets an empty sky. `with` is a second script stood at the same place, for a building whose
## effect lives in a file of its own. `front` is which way in the node's own frame its face looks, because a camera
## that assumes -Z photographs Hangar 03's back wall and a reader cannot tell that from its front.
##
## `make` NAMES A STATIC FACTORY ON `script`, for a building that is not simply its own script instantiated. Without
## it the line is `script.new()`, which is Hangar 03. The cooling tower needed it and the reason is worth keeping: the
## thing that draws a cooling tower is `PowerStation.one()`, while `CoolingTower` itself is a `RefCounted` that returns
## a mesh -- so `script.new() as Node3D` gives null, and `TowerPlume.new()` as a `with` gives a plume that was never
## told which lip it stands on and draws nothing. **Two nulls and an empty sky, from a line that looked right.**
##
## THIS TABLE ASKED THE RIGHT QUESTION OF ANOTHER LANE AND GOT THE RIGHT ANSWER. It was written with a guess at the
## cooling tower's line and a note saying to confirm two things against the real files rather than take them on trust:
## whether `PowerStation.one()` is a factory or a plain `new()`, and whether the plume really needs no settling frames.
## It is a factory, so the guessed line would not have built; and the plume really does need none, because `puff_at` is
## a pure function of its clock and all 24 puffs are already spread at t = 0 -- held by
## `tests/cooling_towers.gd:the_plume_is_whole_on_the_frame_it_is_first_drawn`, which asserts the spread AND that the
## plume's total strength varies 1.20 per cent across a whole cycle, so a later change to an emitter cannot slip in.
## **A prepared line with its assumptions written down beside it is why this cost one edit instead of an afternoon.**
const STANDALONE: Array[Dictionary] = [
	# Hangar 03's door is at +z (`SkyfrontHangar.opening`, whose face_z is half the depth).
	{"id": "hangar-03", "title": "Hangar 03, Skyfront modular ground operations", "settle": 60,
		"script": "res://objects/structures/skyfront_hangar.gd", "with": "", "front": Vector3.BACK},
	# THE COOLING TOWER AND ITS STEAM, through `PowerStation.one()` -- see `make` above. `settle` is 0 and that is
	# measured, not hoped: the plume is whole on the frame it is first drawn. `front` is arbitrary and says so, because
	# a hyperboloid of revolution has no face; the camera's `AROUND` swing is what puts the columns and the waist
	# against the sky rather than one flat panel filling the frame.
	{"id": "cooling-tower", "title": "Cooling tower, with its steam", "settle": 0,
		"script": "res://world/power_station.gd", "make": "one", "with": "", "front": Vector3.FORWARD},
	# THE TWO SHORE STRUCTURES (lane/seaport). Both are built on the datum "the water is at -x and the land at +x",
	# so the face that matters -- the quay, the basin, the cranes -- looks towards -x and `front` is LEFT. Photographed
	# from the water, which is the side everything on them is arranged to face.
	{"id": "marina", "title": "Marina: breakwater, pontoons, fuel dock and a helicopter pad", "settle": 0,
		"script": "res://world/marina.gd", "make": "one", "with": "", "front": Vector3.LEFT},
	{"id": "container-terminal", "title": "Container terminal: quay, ship-to-shore gantries, yard and a pad", "settle": 0,
		"script": "res://world/container_terminal.gd", "make": "one", "with": "", "front": Vector3.LEFT},
]

## What a town building's roof is called in its picture, by `TownPlan.Roof`. Names, not numbers: the enum decides how
## many there are and this only says them in English, and `_check` below fails if the two ever disagree in length.
const ROOF_NAMES: Array[String] = ["flat", "plant", "pitched", "setback"]
const ROOF_TITLES: Array[String] = ["Town building, flat roof", "Town building, flat roof with a plant room",
	"Town building, pitched roof", "Town building, set back at the top"]

## Frames the world is given to build itself before anything is looked at, as the craft gallery gives its fleet.
const WARM: int = 240
## HOW FAR APART THE STANDALONE BUILDINGS ARE STOOD, metres, along the line away from the air base. They used to share
## one spot, which was fine while there was one of them. With the cooling tower added, Hangar 03 -- 13 m tall -- stood
## inside a 99 m tower's 88 m footprint, and its picture was a frame of grey concrete with no hangar in it anywhere.
## `hangar-03_is_in_the_frame` PASSED at 0.74, because it projects the subject's own corners into the window and
## asks what share they cover: it cannot tell a subject in view from a subject behind a wall (lane/cooling,
## 2026-09-17; `cockpit-building-hangar-03` at 18:22). What gave it away was the caption, "nearest: Cooling tower,
## with its steam, 1 m". Past the biggest standalone's width plus the furthest any camera here stands (88 m and
## 205 m), so none can be in another's picture.
const STANDALONE_APART: float = 500.0
## Frames a building is held in frame before its picture, so the kilometre it stands in has been built and come in round
## the eye. A `SceneryYard` cell is built on a worker and handed over on a later frame; 90 is the air base probe's wait.
const SETTLE: int = 90
## The camera's vertical field of view, degrees.
const FOV: float = 50.0
## How far above the building's middle the camera looks down from, degrees, and how far round from its face, degrees.
const ELEVATION: float = 14.0
const AROUND: float = 35.0
## And how far above a WHOLE TOWN asked for with `--over`, degrees: its subject is the roofs, and fourteen degrees over
## a kilometre of town is a view of walls.
const OVER_ELEVATION: float = 30.0
## How much of the window, across or up, the building's box is fitted to.
const FILL: float = 0.7
## The nearest the camera stands, metres.
const CLOSEST: float = 12.0
## HOW MUCH OF THE WINDOW A FITTED BUILDING MAY COVER and the picture still be a picture of it. Typed here rather than
## worked out from FILL, so that a change to the fit has to be looked at: under the first the subject is a speck in a
## landscape, over the second it is cropped. It is the LARGER of the two spans that is fitted (`_share_of_the_window`),
## so the other is always shorter and nothing goes off the edge of the picture.
const LEAST_COVER: float = 0.30
const MOST_COVER: float = 0.98
## How far out of a building's footprint its drawn detail may stand and still be counted as part of it, metres: a
## hangar's roof overhangs 0.6 m, a pilaster stands 0.25 m proud and a revetment's seams 0.04 m. Under the 72.4 m
## between two hangars and the metres between two town buildings by a wide margin.
const DETAIL_MARGIN: float = 1.5
## How far apart two of a building's drawn boxes may stand and still count as joined, metres: a millimetre, because a
## seam sits exactly on its wall's face and the earth exactly on its top. See `_nothing_floats`.
const TOUCHING: float = 0.001
## Two centres nearer than this ON THE GROUND are the same building, metres: what keeps a subject out of its own answer.
const SAME_BUILDING: float = 0.5
## Vertices read from one surface when a drawn mesh is measured; a larger surface is read at a stride.
const SAMPLES_PER_SURFACE: int = 6000

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = ""
var _fine: bool = false
## The picture ids asked for, or empty for all of them. A LIST, because the one thing anybody wants a subset for is
## comparing two pictures of two towns (`--over`), and `--only=<one id>` cannot say that.
var _only: PackedStringArray = []
## Towns asked for as a whole, by name, comma separated: see `_town_overviews`.
var _over: String = ""
var _caption: Label = null
## What the pictures are stamped with: the commit they were taken off and the time they were taken.
var _stamp: String = ""
## Every building on this world with a name, as `{name, centre}`: what a subject's nearest neighbour is looked up in.
var _neighbours: Array[Dictionary] = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[buildings_gallery] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--finish="):
			var finish_asked: String = argument.trim_prefix("--finish=")
			_check("the_finish_is_plain_or_fine", finish_asked in ["plain", "fine"], finish_asked)
			_fine = finish_asked == "fine"
		elif argument.begins_with("--only="):
			_only = argument.trim_prefix("--only=").to_lower().split(",", false)
		elif argument.begins_with("--over="):
			_over = argument.trim_prefix("--over=").to_lower()
	if _out == "":
		# THE REPO'S OWN screenshots/<today>/, found from the project, which is `<repo>/cockpit`.
		var repo: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
		_out = repo.path_join("screenshots").path_join(Time.get_date_string_from_system())
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	# WHICH LEVEL, AS BOOT WOULD CHOOSE IT (tests/craft_gallery_shot.gd does the same, and says why).
	var world: Dictionary = ChartDrawer.asked_in(OS.get_cmdline_user_args(), "none")
	if String(world["error"]) != "":
		_check("the_level_asked_for_is_a_level", false, String(world["error"]))
		_finish()
		return
	if String(world["id"]) != "":
		var why: String = Net.choose_level(String(world["id"]))
		if why != "":
			_check("the_level_asked_for_is_chosen", false, why)
			_finish()
			return
	_check("every_roof_kind_has_a_name", ROOF_NAMES.size() == TownPlan.Roof.size()
		and ROOF_TITLES.size() == TownPlan.Roof.size(),
		"%d names, %d titles, %d roofs" % [ROOF_NAMES.size(), ROOF_TITLES.size(), TownPlan.Roof.size()])
	DirAccess.make_dir_recursive_absolute(_out)
	_stamp = _taken_off()
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	# A GENERATED GROUND TAKES SECONDS TO STAND, and the world is built once it has.
	var waited: int = 0
	while Sim.current.is_empty() and waited < 6000:
		await _frames(1)
		waited += 1
	_check("the_world_built_itself", not Sim.current.is_empty(), "after %d frames" % waited)
	await _frames(WARM)
	get_node("/root/Finish").call("choose", _fine)
	if Daylight.asked_on_the_command_line() < 0:
		_level.choose_time(DaylightTuning.When.DAY)
	# THE LEVEL'S WORDS OFF. `Ui` is a CanvasLayer, which is not a CanvasItem: cast to one it is null and every picture
	# carries the status line (tests/craft_gallery_shot.gd).
	var words: Node = _level.get_node_or_null("Ui")
	if words != null:
		words.set("visible", false)
	var board := _level.observer.get("_board") as CanvasItem
	if board != null:
		board.visible = false
	_level.observer.fov = FOV
	_build_the_caption()
	print("[buildings_gallery] level %s, %s finish, %s, into %s" % [Net.level, "fine" if _fine else "plain", _stamp, _out])

	var subjects: Array[Dictionary] = _subjects()
	_check("there_are_buildings_on_this_world", not subjects.is_empty(), "%d found" % subjects.size())
	var pictured: int = 0
	for subject in subjects:
		if not _only.is_empty() and not _only.has(String(subject["id"])):
			continue
		if await _photograph(subject):
			pictured += 1
	print("[buildings_gallery] %d buildings pictured" % pictured)
	_finish()


## ---- what is stamped on every picture --------------------------------------------------------------------------

## THE COMMIT THESE PICTURES WERE TAKEN OFF AND THE TIME THEY WERE TAKEN, as one line for the caption. A gallery goes
## stale and nothing in it says so: `lane/audit` read a two-hour-old picture as today's state on 2026-09-17. `git` not
## being on the path is not a reason to take no pictures, so the commit is left out and the time stands alone.
func _taken_off() -> String:
	var when: String = "%s %s" % [Time.get_date_string_from_system(), Time.get_time_string_from_system().left(5)]
	var project: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var said: Array = []
	if OS.execute("git", ["-C", project, "rev-parse", "--short", "HEAD"], said, false) != 0 or said.is_empty():
		return when
	var commit: String = String(said[0]).strip_edges()
	if commit == "":
		return when
	var dirt: Array = []
	if OS.execute("git", ["-C", project, "status", "--porcelain"], dirt, false) == 0 and not dirt.is_empty() \
			and String(dirt[0]).strip_edges() != "":
		commit += "+dirty"
	return "%s, %s" % [commit, when]


func _build_the_caption() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 8
	add_child(overlay)
	_caption = Label.new()
	_caption.position = Vector2(30.0, 24.0)
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	_caption.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_caption.add_theme_constant_override("shadow_offset_x", 2)
	_caption.add_theme_constant_override("shadow_offset_y", 2)
	overlay.add_child(_caption)


## ---- the subjects ----------------------------------------------------------------------------------------------

## EVERY BUILDING THIS WORLD DRAWS, one a kind, each as
## `{id, title, box, facing, where, settle, node}`: `box` is its drawn box in the world, `facing` the way its front
## points, `where` the place it stands, and `node` a node freed after its picture, or null.
##
## EACH FINDER ALSO FILES EVERY BUILDING OF ITS OWN KIND IN `_neighbours`, not only the one it photographs: what a
## picture's caption names as the nearest other building has to be the nearest building on the world, not the nearest
## SUBJECT. See `_nearest_other`.
func _subjects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(_airbase_buildings())
	out.append_array(_town_buildings())
	out.append_array(_town_overviews())
	out.append_array(_standalone_buildings())
	return out


## THE AIR BASE'S BUILDINGS: one hangar of each type the base's own standards list, one revetment block, and the tower.
func _airbase_buildings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bases: Array[Dictionary] = AirbasePlan.bases()
	_check("there_is_an_air_base_on_this_world", not bases.is_empty(), "%d laid" % bases.size())
	if bases.is_empty():
		return out
	var base: Dictionary = bases[0]
	var frame: Dictionary = base["frame"]
	var across_axis: Vector3 = frame["across"]
	var pieces: Array[Dictionary] = AirbaseView.structure_pieces(base)
	var roof: PackedVector3Array = _roof_vertices(base)
	_nothing_floats(base, pieces)
	# ONE HANGAR OF EACH TYPE, in the order the standards list them: two type I sheds are one picture.
	var types: Dictionary = base["standards"]["hangar_types"]
	var seen: Dictionary = {}
	for hangar in base["hangars"]:
		var type_name: String = hangar["type"]
		if seen.has(type_name):
			continue
		seen[type_name] = true
		var box: AABB = _grown(_walls_of(base, hangar["id"]), pieces, roof)
		out.append({"id": "airbase-hangar-%s" % type_name.to_lower(),
			"title": "Air base hangar, type %s, %s roof" % [type_name, hangar["roof"]],
			"box": box, "facing": across_axis * -float(hangar["inward"]),
			"where": "%s, hangar '%s'" % [base["name"], hangar["id"]], "settle": SETTLE, "node": null})
	_check("every_hangar_type_the_base_lists_is_pictured", seen.size() == types.size(),
		"%d of %d: %s against %s" % [seen.size(), types.size(), seen.keys(), types.keys()])
	# ONE REVETMENT BLOCK, opening onto its taxilane.
	for block in base["revetments"]:
		var box: AABB = _grown(_walls_of(base, block["id"]), pieces, roof)
		out.append({"id": "airbase-revetment", "title": "Air base revetment, %d bays" % int(block["bays"]),
			"box": box, "facing": across_axis * -float(block["out_sign"]),
			"where": "%s, revetment '%s'" % [base["name"], block["id"]], "settle": SETTLE, "node": null})
		break
	# AND THE TOWER, which is a craft kind because the simulation carries it, and a building because it is one.
	# AND EVERY OTHER ONE OF THEM AS A NEIGHBOUR, not only the representative photographed: the tower's first picture
	# named a hangar 286 m off as its nearest building while two revetment blocks stood in the same frame at a third of
	# that, because only the first block of each kind was in the list (2026-09-17).
	for hangar in base["hangars"]:
		_neighbours.append({"name": "air base hangar '%s', type %s" % [hangar["id"], hangar["type"]],
			"centre": _walls_of(base, hangar["id"]).get_center()})
	for block in base["revetments"]:
		_neighbours.append({"name": "air base revetment '%s'" % block["id"],
			"centre": _walls_of(base, block["id"]).get_center()})
	_neighbours.append({"name": "the air base control tower", "centre": base["tower"]["position"] as Vector3})
	var tower: int = _first_of(Sim.Kind.TOWER)
	_check("the_control_tower_is_in_the_simulation", tower != 0,
		"entity %d" % tower if tower != 0 else "no Sim.Kind.TOWER in Sim.current")
	if tower != 0:
		out.append({"id": "airbase-tower", "title": "Air base control tower", "box": AABB(), "facing": Vector3.ZERO,
			"where": "%s, at the apron" % base["name"], "settle": SETTLE, "node": null, "entity": tower})
	return out


## ONE TOWN BUILDING OF EACH `TownPlan.Roof`: the tallest of its kind, which is deterministic and worth looking at.
func _town_buildings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tallest: Dictionary = {}
	var narrowest: float = INF
	var narrowest_where: String = ""
	var built: int = 0
	for building in _town_boxes():
		_neighbours.append({"name": "a town building in %s" % building["town_name"],
			"centre": building["position"] as Vector3})
		built += 1
		var roof: int = int(building["roof"])
		var half_of: Vector3 = building["half_extents"]
		var wide: float = minf(half_of.x, half_of.z) * 2.0
		if wide < narrowest:
			narrowest = wide
			narrowest_where = String(building["town_name"])
		var high: float = half_of.y
		if not tallest.has(roof) or high > float((tallest[roof] as Dictionary)["half_extents"].y):
			tallest[roof] = building
	for roof in range(TownPlan.Roof.size()):
		if not tallest.has(roof):
			continue
		var building: Dictionary = tallest[roof]
		var centre: Vector3 = building["position"]
		var half: Vector3 = building["half_extents"]
		out.append({"id": "town-%s" % ROOF_NAMES[roof], "title": "%s, %d storeys" % [ROOF_TITLES[roof],
				int(round(half.y * 2.0 / TownTuning.STOREY))],
			"box": AABB(centre - half, half * 2.0), "facing": Vector3.BACK,
			"where": "%s, the tallest of its kind there" % building["town_name"], "settle": SETTLE, "node": null})
	# A ROOF KIND NOTHING BUILDS IS A FINDING, NOT A GAP IN THE GALLERY: it says a branch of `TownPlan._roof_for` and of
	# the building shader is dead on this world, which no picture can show because there is nothing to photograph.
	#
	# PRINTED ON EVERY RUN, LOUDLY, AND NOT A FAILURE (team-lead, 2026-09-17, after `lane/skyhawk` settled the same
	# question for ten seats standing outside their cabins): a red line nobody may act on teaches everybody that red is
	# normal, and then a real one goes past too. Nobody in this lane may fix it -- `TownTuning.PITCHED_WIDE` or a
	# narrower village block changes the world every peer builds -- so the fact belongs in the output and the failure
	# does not. If a village block ever narrows, the line goes quiet on its own.
	var unbuilt: PackedStringArray = []
	for roof in range(TownPlan.Roof.size()):
		if not tallest.has(roof):
			unbuilt.append(ROOF_NAMES[roof])
	# THE NARROWEST BUILDING ON THE WORLD, BESIDE THE GATE THAT DECIDES ITS ROOF, ON EVERY RUN. `TownTuning.PITCHED_WIDE`
	# was typed in the same commit as the roof enum and never compared against the lots the generator makes, and the two
	# missed each other by TWO CENTIMETRES -- 14.02 m against a 14.00 m gate -- for as long as the towns have existed.
	# Neither number is derived from the other and neither can be, so the only defence is printing them side by side
	# where a drift is visible (lane/buildings, 2026-09-17).
	print("[buildings_gallery] %d town buildings; the narrowest is %.2f m across, in %s, against TownTuning.PITCHED_WIDE of %.2f m" % [
		built, narrowest, narrowest_where, TownTuning.PITCHED_WIDE])
	if unbuilt.is_empty():
		print("[buildings_gallery] all %d town roof kinds are built somewhere on this world" % TownPlan.Roof.size())
	else:
		print("[buildings_gallery] ---- UNBUILT: no town on this world builds a %s roof ----" % ", ".join(unbuilt))
		print("[buildings_gallery]      so there is nothing to photograph, and that branch of TownPlan._roof_for and of")
		print("[buildings_gallery]      world/shaders/building.gdshader has never drawn anything. A pitched roof needs a")
		print("[buildings_gallery]      footprint no more than TownTuning.PITCHED_WIDE (%.0f m) across; the narrowest lot" % TownTuning.PITCHED_WIDE)
		print("[buildings_gallery]      the generator can make is a village's, and it is 14 to 20 m. See learnings/2026-09-17-buildings.md.")
	return out


## EVERY TOWN BUILDING THE LEVEL DREW, with the town it belongs to named. Off the level's own `WorldMap`, which is the
## list `Sim.add_static_box` was handed and `TownView` was handed after it -- never a second `Terrain.boxes()`, which
## would build the towns again and warn about the count limit a second time.
func _town_boxes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var map := _level.get("_map") as WorldMap
	if map == null:
		_check("the_level_filed_its_world_by_the_kilometre", false, "no WorldMap on the level")
		return out
	var towns: Array[Dictionary] = TownCatalogue.towns()
	for cell in map.cells():
		for box in map.boxes_in(cell):
			if int(box.get("group", -1)) != Terrain.Group.BUILDING:
				continue
			var t: int = int(box.get("town", -1))
			var named: Dictionary = box.duplicate()
			named["town_name"] = String(towns[t]["name"]) if t >= 0 and t < towns.size() else "a town"
			out.append(named)
	return out


## A WHOLE TOWN, ASKED FOR BY NAME WITH `--over=ford[,hollow]`, and NOT part of the gallery proper.
##
## The gallery's unit is the KIND, and a town is a place rather than a building -- that is written down at the top of
## this file and it still holds. This is for the one thing a per-building picture cannot show: a change that is about
## MANY buildings at once. `TownTuning.PITCHED_WIDE` decides which roof 377 buildings get, and the only honest evidence
## for moving it is the same village before and after.
##
## THE CAPTION CARRIES THE COUNTS, which is the point. A reader asked to compare two pictures of a village is being
## asked to eyeball thirty-seven roofs and will get it wrong; a reader told "ford: 25 pitched, 12 flat" against
## "ford: 37 flat" cannot. The picture and its numbers come off the same list in the same run.
##
## Fitted to the box round the town's own buildings and shot from OVER_ELEVATION rather than ELEVATION, because the
## subject here is the roofs and fourteen degrees is a view of walls.
func _town_overviews() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _over == "":
		return out
	var asked: PackedStringArray = _over.split(",", false)
	var buildings: Array[Dictionary] = _town_boxes()
	for name in asked:
		var box := AABB()
		var any: bool = false
		var counts: Dictionary = {}
		for building in buildings:
			if String(building["town_name"]).to_lower() != name:
				continue
			var centre: Vector3 = building["position"]
			var half: Vector3 = building["half_extents"]
			var one := AABB(centre - half, half * 2.0)
			box = box.merge(one) if any else one
			any = true
			var roof: int = int(building["roof"])
			counts[roof] = int(counts.get(roof, 0)) + 1
		_check("the_town_asked_for_with_over_is_a_town", any, name)
		if not any:
			continue
		var said: PackedStringArray = []
		var total: int = 0
		for roof in range(TownPlan.Roof.size()):
			if counts.has(roof):
				said.append("%d %s" % [int(counts[roof]), ROOF_NAMES[roof]])
				total += int(counts[roof])
		out.append({"id": "town-%s-over" % name, "title": "%s, the whole town: %d buildings, %s" % [name, total,
				", ".join(said)],
			"box": box, "facing": Vector3.BACK, "elevation": OVER_ELEVATION,
			"where": "%.0f x %.0f m of it, at PITCHED_WIDE %.2f m" % [box.size.x, box.size.z, TownTuning.PITCHED_WIDE],
			"settle": SETTLE, "node": null})
	return out


## THE BUILDINGS THAT ARE A NODE OF THEIR OWN, built beside the air base for their picture. Standing them somewhere
## derived rather than typed: clear of the base's own hull, on the ground there.
func _standalone_buildings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var places: Array[Vector3] = []
	for line in STANDALONE:
		var at: Vector3 = _a_clear_place(places.size())
		places.append(at)
		var script := load(String(line["script"])) as Script
		_check("%s_has_a_script" % line["id"], script != null, String(line["script"]))
		if script == null:
			continue
		# `make` NAMES A STATIC FACTORY; without one the script is instantiated. See the note on STANDALONE for why
		# the cooling tower needs the first and Hangar 03 the second.
		var make: String = String(line.get("make", ""))
		var node := (script.call(make) if make != "" else script.new()) as Node3D
		_check("%s_is_a_node" % line["id"], node != null, "%s%s %s a Node3D" % [line["script"],
			"" if make == "" else ".%s()" % make, "is" if node != null else "is NOT"])
		if node == null:
			continue
		node.name = "Gallery_%s" % String(line["id"]).replace("-", "_")
		_level.add_child(node)
		node.global_position = at
		var second: String = String(line.get("with", ""))
		if second != "":
			var beside := (load(second) as Script).new() as Node3D
			if beside != null:
				node.add_child(beside)
		_neighbours.append({"name": String(line["title"]), "centre": at})
		out.append({"id": String(line["id"]), "title": String(line["title"]), "box": AABB(),
			"facing": Vector3.ZERO, "front": line.get("front", Vector3.FORWARD),
			"where": "stood at %.0f, %.0f for the picture; it is not part of this world" % [at.x, at.z],
			"settle": int(line.get("settle", SETTLE)), "node": node})
	# ASKED OF THE PLACES ACTUALLY CHOSEN, not of the constant: a later change to `_a_clear_place` that folds them
	# back onto one spot is the bug, and it looks exactly like a gallery that works.
	var closest: float = INF
	for i in range(places.size()):
		for j in range(i + 1, places.size()):
			closest = minf(closest, Vector2(places[i].x - places[j].x, places[i].z - places[j].z).length())
	_check("no_standalone_building_is_stood_in_another", places.size() < 2 or closest >= STANDALONE_APART - 0.01,
		"%d stood, the closest two %.0f m apart, wanting %.0f" % [places.size(),
			0.0 if closest == INF else closest, STANDALONE_APART])
	return out


## SOMEWHERE CLEAR TO STAND A BUILDING THAT HAS NO PLACE ON THIS WORLD: beside the air base's hull, on the ground there,
## or the origin's ground with no base -- the `index`th such place, `STANDALONE_APART` further out each time.
func _a_clear_place(index: int = 0) -> Vector3:
	var bases: Array[Dictionary] = AirbasePlan.bases()
	var at := Vector3.ZERO
	if not bases.is_empty():
		var hull: AABB = bases[0]["hull"]
		at = hull.get_center() + Vector3(hull.size.x * 0.5 + 200.0, 0.0, 0.0)
	at.x += float(index) * STANDALONE_APART
	# A LINE OF STANDALONES WALKS OFF THE GROUND, and the further one is down the list the further out it stands.
	# The island's slab is finite, so the third and fourth entries land over the SEA, where `ground_height` has no
	# answer and hands back -INF. That went straight into `global_position`, every vertex of the building transformed
	# to NaN, and the coverage check reported "it covers -nan of the window" -- which reads like a broken MODEL and is
	# a broken PLACE. Two buildings were photographed as blank sea before it was found (lane/seaport, 2026-09-19).
	#
	# Sea level is the honest fallback rather than a refusal: a thing with nowhere to stand is still worth a picture,
	# and the two that found this -- a marina and a container terminal -- stand at the water by construction anyway.
	var ground: float = Terrain.ground_height(at)
	at.y = ground if is_finite(ground) else Terrain.SEA_LEVEL
	return at


## THE FIRST CRAFT OF A KIND THE LEVEL PLACED: the lowest id of that kind in `Sim.current`, or 0. NEVER a spawn's
## returned id, which is the server's.
func _first_of(kind: int) -> int:
	var first: int = 0
	for entity in Sim.current:
		if int((Sim.current[entity] as Dictionary).get("kind", -1)) == kind and (first == 0 or int(entity) < first):
			first = int(entity)
	return first


## ---- nothing floats --------------------------------------------------------------------------------------------

## EVERY DRAWN PART OF THE AIR BASE TOUCHES SOMETHING, and there are exactly as many separate groups of them as the plan
## laid buildings.
##
## WHY THIS EXISTS. Nothing in this game had ever checked that a building's drawn parts touch each other. `lane/audit`
## found the tanker's tail assembly hanging in mid-air attached to nothing, and it had survived every suite
## indefinitely, because a suite reads dimensions and a dimension is right whether or not the part is joined on
## (team-lead, 2026-09-17). An air base building is ASSEMBLED -- a hangar is walls, pilasters, a plinth, a fascia and
## eight door leaves, a revetment is walls, earth and seams -- and a picture is the only thing that would otherwise
## notice one of them floating.
##
## THE COUNT IS DERIVED, NEVER TYPED: the pieces should fall into one group per hangar plus one per revetment block,
## because the plan stands them 72.4 m apart and nothing else joins them. A part that floats off makes a group of its
## own and the count goes up; a part that lands on a neighbour makes the count go down. Either way the number moves,
## and the groups are printed smallest first so the stray one is named.
##
## TOUCHING MEANS TOUCHING, not overlapping: a seam sits exactly on its wall's face and the earth exactly on its top, so
## two boxes count as joined when their spans meet on all three axes within TOUCHING. It runs over every piece of the
## whole base rather than per building, because a footprint filter cannot see a part that has left the footprint --
## which is the very thing being looked for.
func _nothing_floats(base: Dictionary, pieces: Array[Dictionary]) -> void:
	var group: PackedInt32Array = PackedInt32Array()
	group.resize(pieces.size())
	for i in range(pieces.size()):
		group[i] = i
	for i in range(pieces.size()):
		for j in range(i + 1, pieces.size()):
			if _root(group, i) != _root(group, j) and _touching(pieces[i], pieces[j]):
				group[_root(group, i)] = _root(group, j)
	var members: Dictionary = {}
	for i in range(pieces.size()):
		var root: int = _root(group, i)
		members[root] = int(members.get(root, 0)) + 1
	var laid: int = (base["hangars"] as Array).size() + (base["revetments"] as Array).size()
	var sizes: Array = members.values()
	sizes.sort()
	_check("every_drawn_part_of_the_base_is_joined_to_a_building", members.size() == laid,
		"%d groups of pieces for %d buildings laid (%d hangars, %d revetments); groups of %s pieces" % [
			members.size(), laid, (base["hangars"] as Array).size(), (base["revetments"] as Array).size(), sizes])
	if members.size() == laid:
		return
	# AND WHICH PIECE IS THE STRAY ONE: the smallest group, where it stands, and how big it is.
	var smallest: int = -1
	for root in members:
		if smallest < 0 or int(members[root]) < int(members[smallest]):
			smallest = int(root)
	for i in range(pieces.size()):
		if _root(group, i) == smallest:
			print("[buildings_gallery] FLOATING: a group of %d piece(s), one of them at %s, half extents %s" % [
				members[smallest], pieces[i]["position"], pieces[i]["half_extents"]])
			return


func _root(group: PackedInt32Array, i: int) -> int:
	var at: int = i
	while group[at] != at:
		at = group[at]
	return at


## TWO DRAWN BOXES MEET, on all three axes, within TOUCHING.
func _touching(a: Dictionary, b: Dictionary) -> bool:
	var low_a: Vector3 = (a["position"] as Vector3) - (a["half_extents"] as Vector3)
	var high_a: Vector3 = (a["position"] as Vector3) + (a["half_extents"] as Vector3)
	var low_b: Vector3 = (b["position"] as Vector3) - (b["half_extents"] as Vector3)
	var high_b: Vector3 = (b["position"] as Vector3) + (b["half_extents"] as Vector3)
	for axis in range(3):
		if low_a[axis] > high_b[axis] + TOUCHING or low_b[axis] > high_a[axis] + TOUCHING:
			return false
	return true


## ---- measuring what was drawn ----------------------------------------------------------------------------------

## ONE BUILDING'S SOLID WALLS in the world, as the plan laid them: the boxes whose `of` is this hangar's or block's id.
func _walls_of(base: Dictionary, id: String) -> AABB:
	var box := AABB()
	var any: bool = false
	for wall in base["walls"]:
		if String(wall.get("of", "")) != id:
			continue
		var centre: Vector3 = wall["position"]
		var half: Vector3 = wall["half_extents"]
		var one := AABB(centre - half, half * 2.0)
		box = box.merge(one) if any else one
		any = true
	return box


## AND EVERYTHING ELSE THE VIEW DREW ON THEM: every batched piece and every roof vertex standing over this building's
## own footprint. Its detail is found by WHERE IT STANDS rather than by working its size out a second time -- a pilaster's
## proudness, a seam's, the earth on a revetment and a roof's overhang and pitch are `AirbaseView`'s numbers and are read
## from what it handed its batch, not copied here.
func _grown(walls: AABB, pieces: Array[Dictionary], roof: PackedVector3Array) -> AABB:
	if walls.size == Vector3.ZERO:
		return walls
	var footprint := Rect2(Vector2(walls.position.x, walls.position.z) - Vector2.ONE * DETAIL_MARGIN,
		Vector2(walls.size.x, walls.size.z) + Vector2.ONE * DETAIL_MARGIN * 2.0)
	var box: AABB = walls
	for piece in pieces:
		var centre: Vector3 = piece["position"]
		if not footprint.has_point(Vector2(centre.x, centre.z)):
			continue
		var half: Vector3 = piece["half_extents"]
		box = box.merge(AABB(centre - half, half * 2.0))
	for i in range(roof.size()):
		var at: Vector3 = roof[i]
		if footprint.has_point(Vector2(at.x, at.z)):
			box = box.expand(at)
	return box


## EVERY VERTEX OF EVERY HANGAR ROOF ON THIS BASE, in the world.
func _roof_vertices(base: Dictionary) -> PackedVector3Array:
	var out := PackedVector3Array()
	var mesh: ArrayMesh = AirbaseView.roof_mesh(base, Vector3.ZERO)
	if mesh == null:
		return out
	for surface in range(mesh.get_surface_count()):
		out.append_array(mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	return out


## THE DRAWN BOX OF A NODE, IN THE WORLD, from the vertices of every visible mesh under it put through each mesh's own
## transform -- never `transform * get_aabb()`, which grows a box every time it is turned.
func _drawn_bounds(root: Node3D) -> AABB:
	var box := AABB()
	var any: bool = false
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.mesh == null or not drawn.is_visible_in_tree():
			continue
		var into: Transform3D = drawn.global_transform
		for surface in range(drawn.mesh.get_surface_count()):
			var vertices: PackedVector3Array = drawn.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var stride: int = maxi(1, vertices.size() / SAMPLES_PER_SURFACE)
			for i in range(0, vertices.size(), stride):
				var at: Vector3 = into * vertices[i]
				if any:
					box = box.expand(at)
				else:
					box = AABB(at, Vector3.ZERO)
					any = true
	return box


## ---- the picture -----------------------------------------------------------------------------------------------

## GO TO ONE BUILDING, FIT IT IN THE FRAME AND SAVE IT: false, with the reason, when it could not be.
func _photograph(subject: Dictionary) -> bool:
	var id: String = subject["id"]
	var box: AABB = subject["box"]
	var facing: Vector3 = subject["facing"]
	# A TOWER IS A CRAFT VIEW, which may not be built until the camera has been near it.
	if subject.has("entity"):
		var view: VehicleView = null
		for i in range(240):
			view = _level.view_of(int(subject["entity"]))
			if view != null:
				break
			if Sim.current.has(int(subject["entity"])):
				var at: Vector3 = (Sim.current[int(subject["entity"])] as Dictionary).get("position", Vector3.ZERO)
				_level.observer.look_from(at + Vector3(0.0, 80.0, 160.0), at)
			await _frames(1)
		_check("%s_is_drawn" % id, view != null, "entity %d, %s" % [int(subject["entity"]),
			"drawn" if view != null else "no view after 240 frames"])
		if view == null:
			return false
		box = _drawn_bounds(view)
		facing = -view.global_transform.basis.z
	elif subject["node"] != null:
		var node := subject["node"] as Node3D
		await _frames(2)
		box = _drawn_bounds(node)
		facing = node.global_transform.basis * (subject.get("front", Vector3.FORWARD) as Vector3)
	if box.size == Vector3.ZERO:
		_check("%s_was_measured" % id, false, "nothing drawn under it")
		return false
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.BACK
	var centre: Vector3 = box.get_center()
	var radius: float = box.size.length() * 0.5
	var distance: float = maxf(radius / sin(deg_to_rad(FOV * 0.5)), CLOSEST)
	# FITTED BY WHAT THE BOX COVERS ON SCREEN, not by a sphere round it: a sphere round a long shed is mostly sky. The
	# box's eight corners are projected and the distance scaled until the wider of the two spans is FILL of the window,
	# twice, because a changed distance changes the perspective a little. (tests/craft_gallery_shot.gd, which paid for it.)
	var elevation: float = float(subject.get("elevation", ELEVATION))
	var covers: float = 0.0
	for pass_number in range(3):
		_stand(centre, facing, distance, box, elevation)
		await _frames(2)
		covers = _share_of_the_window(box)
		if covers > 0.0:
			distance = maxf(distance * covers / FILL, CLOSEST)
	_stand(centre, facing, distance, box, elevation)
	await _frames(int(subject["settle"]))
	covers = _share_of_the_window(box)
	_check("%s_is_in_the_frame" % id, covers >= LEAST_COVER and covers <= MOST_COVER,
		"it covers %.2f of the window, wanted %.2f to %.2f" % [covers, LEAST_COVER, MOST_COVER])
	var near: Dictionary = _nearest_other(subject, centre)
	var smoke: String = _fire_in_frame(centre)
	_caption.text = "%s\n%.1f x %.1f m, %.1f m tall -- %s\nnearest: %s, %.0f m -- %s%s" % [subject["title"],
		box.size.x, box.size.z, box.size.y, subject["where"], near["name"], near["metres"], _stamp,
		"" if smoke == "" else "\n" + smoke]
	await _frames(2)
	var path: String = _out.path_join("cockpit-building-%s.png" % id)
	var saved: bool = get_viewport().get_texture().get_image().save_png(path) == OK
	_check("%s_is_saved" % id, saved, path)
	print("[buildings_gallery] %s: %.1f x %.1f m and %.1f m tall, camera %.0f m off, covers %.2f, nearest %s at %.0f m, %s%s" % [
		id, box.size.x, box.size.z, box.size.y, distance, covers, near["name"], near["metres"], path,
		"" if smoke == "" else "; " + smoke])
	if subject["node"] != null:
		(subject["node"] as Node3D).queue_free()
		await _frames(1)
	return saved


## THE CAMERA, PUT ROUND FROM THE BUILDING'S FACE AND ELEVATION DEGREES ABOVE ITS MIDDLE.
##
## NOTHING CAPS THE RISE, and that is the one place this parts company with `tests/craft_gallery_shot.gd`, whose camera
## never rises over the craft's own top because a parked helicopter photographed from above is a rotor disc and nothing
## under it. A building has nothing on its roof that hides its walls, and a low wide one MUST be looked down on: the
## revetment's first picture was taken with the rise capped at 0.45 of its 4 m height, from 1.8 m off the ground, and 132
## metres of six open bays read as a plain fence seen edge-on (2026-09-17). At ELEVATION the camera is still under the top
## of anything with a normal aspect -- the 212 m tower is photographed from 192 m.
func _stand(centre: Vector3, facing: Vector3, distance: float, box: AABB, elevation: float) -> void:
	var right: Vector3 = facing.cross(Vector3.UP)
	var round_from: Vector3 = facing * cos(deg_to_rad(AROUND)) + right * sin(deg_to_rad(AROUND))
	var rise: float = distance * sin(deg_to_rad(elevation))
	_level.observer.look_from(centre + round_from * distance * cos(deg_to_rad(elevation)) + Vector3.UP * rise, centre)


## HOW MUCH OF THE WINDOW THE BUILDING'S BOX COVERS from where the camera stands now: the LARGER of its share across and
## its share up, so fitting that to FILL leaves the other span shorter and nothing is ever cropped; 0 when a corner is
## behind the camera.
func _share_of_the_window(box: AABB) -> float:
	var camera: Camera3D = _level.observer
	var window: Vector2 = get_viewport().get_visible_rect().size
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for i in range(8):
		var corner: Vector3 = box.get_endpoint(i)
		if camera.is_position_behind(corner):
			return 0.0
		var at: Vector2 = camera.unproject_position(corner)
		low = low.min(at)
		high = high.max(at)
	return maxf((high.x - low.x) / window.x, (high.y - low.y) / window.y)


## THE NEAREST OTHER BUILDING TO THIS ONE, and how far off it stands: what a reader of the picture is most likely to
## mistake for the subject. See the doc block, "What else is in the frame".
##
## ON THE GROUND, NOT THROUGH THE AIR, and that is what keeps a subject out of its own answer: the subject is filed at
## the middle of its drawn box and the tower at the foot of its mast, ten metres apart in a straight line and nowhere
## apart on the ground. Two different buildings never stand within SAME_BUILDING of each other horizontally, and "133 m
## away" is how far a reader would walk anyway.
func _nearest_other(subject: Dictionary, centre: Vector3) -> Dictionary:
	var best: String = "nothing else on this world"
	var metres: float = INF
	var here := Vector2(centre.x, centre.z)
	for other in _neighbours:
		var there: Vector3 = other["centre"]
		var away: float = here.distance_to(Vector2(there.x, there.z))
		if String(other["name"]) == String(subject["title"]) or away < SAME_BUILDING:
			continue
		if away < metres:
			metres = away
			best = String(other["name"])
	return {"name": best, "metres": 0.0 if metres == INF else metres}


## A FIRE THAT IS IN THE PICTURE, NAMED, BECAUSE THE GUARD ABOVE WAS BORN FROM ONE AND DID NOT LOOK FOR THEM.
##
## `_nearest_other` names the nearest BUILDING, and this file's own doc block says why it exists: team-lead read a
## steam plume off a picture of the train, and it was a fire 1,139 m behind the locomotive. So the guard was made for
## exactly one kind of confusion -- a fire's column read as something the subject is doing -- and then searched only
## buildings. `lane/cooling` found it on the first picture of the cooling tower: a fire's grey column stood in frame
## over the mountain behind the steam, and the caption named a hangar 225 m away (2026-09-17). For the one subject
## in the gallery whose whole point is a white column rising, that is the worst neighbour to leave unnamed.
##
## ONLY A FIRE THAT IS ACTUALLY IN THE FRAME, with its column: `FireYard` draws each fire's smoke 260 m tall and never
## culls it, so a fire whose base is off the bottom of the picture can still stand across the middle of it. A fire
## that is nowhere in the picture is not a thing a reader can confuse with anything, and naming it would teach a reader
## to skip the line. Asked of `Sim.fires` -- what the level is actually drawing -- not of `Terrain.fires()`, which is
## where fires STARTED and not where they are.
func _fire_in_frame(centre: Vector3) -> String:
	var eye: Camera3D = get_viewport().get_camera_3d()
	if eye == null:
		return ""
	var frame := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var nearest: float = INF
	var seen: int = 0
	for row in Sim.fires:
		var at: Vector3 = (row as Dictionary)["position"]
		var top: Vector3 = at + Vector3.UP * FireYard.COLUMN_HEIGHT
		var shown: bool = false
		for point in [at, top, (at + top) * 0.5]:
			if not eye.is_position_behind(point) and frame.has_point(eye.unproject_position(point)):
				shown = true
		if not shown:
			continue
		seen += 1
		nearest = minf(nearest, Vector2(at.x - centre.x, at.z - centre.z).length())
	if seen == 0:
		return ""
	return "smoke in frame: %d fire%s, the nearest %.0f m off -- not this building's" % [
		seen, "" if seen == 1 else "s", nearest]


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
