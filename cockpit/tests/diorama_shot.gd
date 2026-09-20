extends Node
## WHAT THE CONTROLLER'S BOARD LOOKS LIKE, because none of the questions worth asking about it can be answered by a
## headless run (CLAUDE.md rule 2): whether 54 mm of relief reads as an island, whether a token reads as an aeroplane
## at 14 mm, whether a stalk reads as altitude or as a scratch, and whether the board is actually better than the flat
## plot at anything.
##
##   Godot --xr-mode off --path cockpit res://tests/diorama_shot.tscn
##
## `tests/diorama.gd` holds the arithmetic -- the scale, the index, where a piece stands. This holds nothing except
## that the pictures got taken and that the two views really are different pictures; the rest is for eyes.
##
## FOUR PICTURES, and the fourth is the one the lane is for:
##   1. THE EMPTY BOARD. The terrain on its own, which is the thing that had to be built from numbers.
##   2. THE BOARD WITH TRAFFIC, from a real sweep against the island's own rock.
##   3. A LOW ANGLE, close in, where a stalk's length is the contact's height and you can read it without the panel.
##   4. THE TWO VIEWS OF THE SAME SWEEP SIDE BY SIDE -- the flat plot as it is today, and the board -- so the question
##      "is this actually an improvement" can be looked at instead of argued about.
##
## THE CONTACTS ARE A REAL SWEEP, as `tests/control_shot.gd` stages one: `RadarSet.sweep` against a server world with
## the island's own mountains and ninety real aircraft in it, not rows this file wrote. What is staged is only the
## SESSION. **The heights are deliberately spread**, which control_shot's are not: every one of its ninety flies at
## 300 m, and a board whose entire traffic is at one altitude would photograph its own best feature as a flat layer.
##
## IN A SubViewport AND NEVER THE DESKTOP.
##
## Read RESULT=, not the exit code.

const EMPTY_SHOT: String = "user://diorama_empty.png"
const TRAFFIC_SHOT: String = "user://diorama_traffic.png"
const LOW_SHOT: String = "user://diorama_low.png"
const BESIDE_SHOT: String = "user://diorama_beside_the_plot.png"
const WIDTH: int = 1600
const HEIGHT: int = 900
const HOW_MANY: int = 90
## The band the staged traffic is spread through, metres. From under the island's 653 m of rock to well over it, so the
## picture shows contacts below a summit, level with one and far above -- which is the distinction the board exists to
## draw and the flat plot cannot.
const LOWEST: float = 120.0
const HIGHEST: float = 4200.0
## How long the world flies before the sweep, seconds. Craft spawn at rest; see the spawn loop.
const SETTLES: float = 4.0

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[diorama_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[diorama_shot] RESULT=FAIL windowed renderer required")
		get_tree().quit(1)
		return

	var island: Object = ClassDB.instantiate(&"MountainRange")
	island.call("configure", Terrain.mountain_values())
	var world: Object = ClassDB.instantiate(&"CockpitWorld")
	world.set_tick_rate(120)
	world.start(0)
	world.set_mountains(island)
	var kinds: Array[int] = [Sim.Kind.PLANE, Sim.Kind.AIRLINER, Sim.Kind.HELI, Sim.Kind.CESSNA, Sim.Kind.FIGHTER,
		Sim.Kind.BOAT, Sim.Kind.GUNBOAT]
	for i in range(HOW_MANY):
		var turn: float = TAU * float(i) * 0.191
		var out: float = 700.0 + 78.0 * float(i)
		var kind: int = kinds[i % kinds.size()]
		# A SHIP IS ON THE WATER AND EVERYTHING ELSE IS SPREAD THROUGH THE BAND. See the doc block: one altitude for
		# everything would photograph the board's own point away.
		var afloat: bool = VehicleCatalogue.group(kind) == "ships"
		var high: float = 0.0 if afloat else lerpf(LOWEST, HIGHEST, fmod(float(i) * 0.37, 1.0))
		world.spawn_ai_vehicle(kind, Vector3(cos(turn) * out, high, sin(turn) * out * 0.82), turn, Vector3.ZERO)
	# FLOWN UP TO SPEED BEFORE THE SWEEP. Craft spawn at rest, and the first version ticked ONCE and photographed a
	# board whose every label read `0 m/s` -- which looked like the speed field was broken rather than like ninety
	# aeroplanes that had not started yet. Four seconds of flying, as `tests/diorama_reel.gd` does and for the same
	# reason.
	for warm in range(int(SETTLES * 120.0)):
		world.tick(1.0 / 120.0)
	var head := Vector3.ZERO
	var rows: Array = RadarSet.sweep(world, head, RadarSet.manned_vehicles(world))
	_check("the_sweep_found_contacts_to_draw", rows.size() > 8, "%d contact(s)" % rows.size())

	# THE ISLAND UNDER THE PLOT, from `radar_shot`'s own builder, exactly as `control_shot` does -- so the plot in
	# picture 4 is the plot every other probe photographs and not a second island.
	load("res://tests/radar_shot.gd").call("build_island", self, island)
	var chart := LevelChart.new()
	chart.world = "island"
	var map := LevelMap.new()
	add_child(map)
	map.configure(chart)
	map.rebuild()
	await map.rebuilt

	var was_roster: Dictionary = Net.roster
	var was_host: bool = Net.is_host
	var built: int = int(Net.identity()["built"])
	Net.is_host = true
	Net.roster = {
		1: {"player": 1, "name": "CONTROL", "colour": 3, "built": built, "team": 0},
		2: {"player": 2, "name": "GRAHAM", "colour": 0, "built": built, "team": 1},
		3: {"player": 3, "name": "kestrel_77", "colour": 2, "built": built, "team": 1},
	}

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
	# THE BUILD STAMP, as in every picture the game takes (`BuildStamp`, 2026-09-18): this stage is a viewport of its
	# own, so the root's stamp is not drawn into it, and these shots go in blog posts where the build has to be
	# traceable. It is safe beside `_differs`, which counts pixels that MOVED between two shots of this same stage:
	# the stamp is baked at build time and identical in both, so it contributes nothing to that count.
	BuildStamp.attach_to(glass)
	var station := ControlStation.new()
	station.size = Vector2(WIDTH, HEIGHT)
	station.level_map = map
	station.radar = watch
	glass.add_child(station)
	await get_tree().process_frame
	station.size = Vector2(WIDTH, HEIGHT)

	# 1. THE EMPTY BOARD. The watch is emptied rather than the station being told to draw nothing, because an empty
	# picture is a state a controller really sees -- before the first sweep arrives, or with everything behind rock.
	station.show_the_board(true)
	watch.rows = []
	var empty_image: Image = await _shot(station, glass, EMPTY_SHOT)

	# 2. THE BOARD WITH THE SWEEP ON IT.
	watch.rows = rows
	var traffic_image: Image = await _shot(station, glass, TRAFFIC_SHOT)
	var board: DioramaView = station.the_board()
	_check("the_board_is_carrying_the_sweep", board.board.pieces_shown == rows.size(),
		"%d piece(s) for %d contact(s)" % [board.board.pieces_shown, rows.size()])

	# AN EMPTY BOARD AND A BUSY ONE ARE DIFFERENT PICTURES. Without this the probe would happily save four photographs
	# of the same thing and call it a day -- which is the failure `fireboat_shot` had, passing with 25,283 bright
	# pixels on a picture containing no water (docs.gd PROBES).
	_check("traffic_changed_the_picture", _differs(empty_image, traffic_image) > 0.004,
		"%.2f%% of pixels moved when ninety contacts were put on the board" % (_differs(empty_image, traffic_image) * 100.0))

	# 3. LOW AND CLOSE, where the stalks are the point.
	for step in range(9):
		board.drive(_a_key(KEY_DOWN))
	for step in range(4):
		board.drive(_a_key(KEY_COMMA))
	for step in range(5):
		board.drive(_a_key(KEY_LEFT))
	var low: Dictionary = board.eye()
	_check("the_keys_moved_the_camera", float(low["pitch"]) < DioramaView.PITCH_AT and float(low["dolly"]) < DioramaView.DOLLY_AT,
		"pitch %.2f from %.2f, dolly %.2f from %.2f" % [float(low["pitch"]), DioramaView.PITCH_AT,
			float(low["dolly"]), DioramaView.DOLLY_AT])
	var low_image: Image = await _shot(station, glass, LOW_SHOT)

	# 4. THE SAME SWEEP, BOTH WAYS, SIDE BY SIDE. The plot on the left as it is today and the board on the right, from
	# one `RadarWatch` that has not been touched between the two -- so this is genuinely one moment drawn twice.
	station.show_the_board(false)
	var plot_image: Image = await _shot(station, glass, "")
	station.show_the_board(true)
	# BACK TO THE OPENING VIEW rather than driven back up from the low one. The first run added nine presses of UP to a
	# camera already lying flat and photographed the comparison from almost straight down, with the board running off
	# both edges -- a picture that answered the question "is the board better than the plot" by throwing away the one
	# thing the board has.
	board.look_from_the_default()
	var board_image: Image = await _shot(station, glass, "")
	_check("the_plot_and_the_board_are_different_pictures", _differs(plot_image, board_image) > 0.2,
		"%.1f%% of pixels differ between the two views of one sweep" % (_differs(plot_image, board_image) * 100.0))

	var beside := Image.create(WIDTH * 2, HEIGHT, false, plot_image.get_format())
	beside.blit_rect(plot_image, Rect2i(Vector2i.ZERO, Vector2i(WIDTH, HEIGHT)), Vector2i.ZERO)
	beside.blit_rect(board_image, Rect2i(Vector2i.ZERO, Vector2i(WIDTH, HEIGHT)), Vector2i(WIDTH, 0))
	var saved: int = beside.save_png(BESIDE_SHOT)
	print("[diorama_shot] %dx%d, saved %s to %s" % [beside.get_width(), beside.get_height(),
		error_string(saved), ProjectSettings.globalize_path(BESIDE_SHOT)])

	Net.roster = was_roster
	Net.is_host = was_host
	_check("every_picture_was_saved", empty_image != null and traffic_image != null and low_image != null and saved == OK,
		"four pictures, last %s" % error_string(saved))
	_finish()


## HOW MUCH TWO PICTURES DIFFER, as a fraction of pixels that moved by more than a hair. Sampled on a grid rather than
## walked whole: 1600 by 900 is 1.4 million pixels and the question is "did anything change", not "what exactly".
func _differs(before: Image, after: Image) -> float:
	if before == null or after == null:
		return 0.0
	var moved: int = 0
	var looked: int = 0
	for y in range(0, HEIGHT, 4):
		for x in range(0, WIDTH, 4):
			looked += 1
			var was: Color = before.get_pixel(x, y)
			var now: Color = after.get_pixel(x, y)
			if absf(was.r - now.r) + absf(was.g - now.g) + absf(was.b - now.b) > 0.06:
				moved += 1
	return float(moved) / float(maxi(looked, 1))


## A REAL KEY EVENT, with BOTH `keycode` and `physical_keycode` set (CLAUDE.md rule 9): the view reads whichever it is
## given, and a probe that set only one would not prove the other works.
func _a_key(which: Key) -> InputEventKey:
	var press := InputEventKey.new()
	press.keycode = which
	press.physical_keycode = which
	press.pressed = true
	return press


func _shot(station: ControlStation, glass: SubViewport, path: String) -> Image:
	station._show()
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = glass.get_texture().get_image()
	if path.is_empty():
		return image
	var saved: int = image.save_png(path)
	print("[diorama_shot] %dx%d, saved %s to %s" % [image.get_width(), image.get_height(),
		error_string(saved), ProjectSettings.globalize_path(path)])
	return image


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
