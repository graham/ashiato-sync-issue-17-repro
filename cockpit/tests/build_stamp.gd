extends Node
## Headless: the build is written in the lower right of the screen and on the clipboard's frame, everywhere, on top,
## taking no clicks, and it is the one line `BuildPlate` gives.
##
##   Godot --headless --path cockpit res://tests/build_stamp.tscn
##
## Asked for on 2026-09-18 (see `autoload/build_stamp.gd`). What is checked, and the mutant that turns each red:
##
##   the stamp's words are `BuildPlate.line()`, and a dev run's line carries the commit `git rev-parse HEAD` gives --
##     asked of git itself, not of the reader under test          RED with a version typed into `BuildStamp._a_stamp`
##   and it ends with the day its commit was made, in UTC, as `git log -1 --format=%ct` says (lane/buildtime)
##                                                                   RED with the date left off `BuildPlate.line`
##   the stamp is up and on the top layer at the desk and in every level a player can fly, walked the way a player
##     walks them: the level's button, "Fly on your own", MAIN MENU's door        RED with the stamp hidden in one level
##   the stamp says which LANE and WORKTREE made the picture, as git says them (lane/stamps)   RED with the lane left off, the
##     path left off, or "main" typed where the path says a lane        (mutants: `BuildPlate.lane_of` / `words_for`)
##   every probe that photographs a SubViewport of its own puts the stamp in it, or is named with a reason
##   it is in the lower right and wholly on screen at 1280x720, 1600x900 and 2880x1620
##   a click on it lands on the button underneath, pushed as the mouse pushes it
##   the clipboard's frame says the same line with the board up, on every tab, in every level
##   the release script still bakes every key `BuildPlate` reads            (`tests/build_export.gd` proves the bake)
##
## Read RESULT=, not the exit code.

const PATIENCE: int = 2400
## Frames flown in each level before it is read: the rig built, the board made, the curtain gone.
const FLY_FRAMES: int = 60
const SETTLE: int = 30
## LEVELS THAT HAVE NO CLIPBOARD, and why. A clipboard belongs to the pilot's rig (`PilotRig`), and a level nobody flies has no rig:
## the trace level is WATCHED (`FlightLevel._nobody_is_playing`), one puppet and its own camera, so there is no hand to hold a board
## and no headset to read one in. The stamp is still up and on top in it -- `the_stamp_is_up_in_trace` -- because that label is the
## window's and not the rig's; what such a level does not have is the board's frame. THE LIST CANNOT GROW QUIETLY: a level named here
## must really have no Clipboard (a level that gains one fails and is taken off the list), and the list's size is asserted, so a new level
## added to it is a change to this line and a reason a reviewer sees. A level a player FLIES is never a candidate.
const WITHOUT_A_CLIPBOARD: Dictionary = {"trace": "watched, not flown: one puppet posed from a file and the level's own camera, so no rig and no board"}
## The three sizes the brief names: the smallest window anybody plays in, the canvas, and a 4K-ish desktop.
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(2880, 1620)]
## How near the corner "in the lower right" is: the stamp's far edges within this share of the screen of it.
const CORNER_SHARE: float = 0.04

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[build_stamp] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if get_tree().current_scene != self:
		_run()
		return
	# THE WALK OUTLIVES THIS SCENE, which the desk replaces: the same arrangement as `tests/level_swap.gd`.
	var watcher := Node.new()
	watcher.name = "StampWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld missing")
		_finish()
		return
	await get_tree().process_frame
	_the_words()
	_the_release_script_bakes_what_the_plate_reads()
	_the_lane_and_the_worktree()
	_a_dirty_tree_says_so()
	_the_scan_reads_code_and_not_comments()
	await _no_probe_photographs_a_stage_without_the_stamp()
	await _the_corner_at_every_size()
	await _a_click_goes_through()
	await _a_stage_of_its_own()
	await _every_level()
	_finish()


## ---- the words ---------------------------------------------------------------------------------------------------

func _the_words() -> void:
	var line: String = BuildPlate.line()
	_check("the_stamp_says_the_plates_line_and_then_where", BuildStamp.text() == BuildStamp.plate() and BuildStamp.text().begins_with(BuildPlate.shown_line()),
		"stamp '%s', plate '%s'" % [BuildStamp.text(), line])
	var said: Array = []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"], said)
	var head: String = String(said[0]).strip_edges() if not said.is_empty() else ""
	_check("a_dev_run_is_not_a_release", not BuildPlate.is_release() and line.begins_with("dev" + BuildPlate.DOT),
		"'%s'" % line)
	_check("the_dev_line_carries_the_checkouts_commit", head.length() == 40 and BuildPlate.commit() == head
		and line.contains(head.substr(0, BuildPlate.SHORT)), "git %s, plate %s" % [head, BuildPlate.commit()])
	# AND ITS DATE, which is the COMMIT'S (lane/buildtime, 2026-09-19): asked of git itself, in UTC, and read off the
	# stamp a player sees. RED with the date left off the line, and with the dev line dated the day it ran (a commit
	# from before today).
	said.clear()
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "log", "-1", "--format=%ct", "HEAD"], said)
	var committed: int = int(String(said[0]).strip_edges()) if not said.is_empty() else 0
	var day: String = Time.get_date_string_from_unix_time(committed) if committed > 0 else "?"
	_check("the_stamp_says_the_day_its_commit_was_made", committed > 0 and BuildStamp.text().contains(BuildPlate.DOT + day + BuildPlate.DOT)
		and BuildPlate.time() == committed, "stamp '%s', git's commit time %d (%s), plate %d" % [BuildStamp.text(),
			committed, day, BuildPlate.time()])


## A PICTURE TAKEN FROM A MODIFIED TREE SAYS "+dirty" (lane/dirtystamp, 2026-09-20). The truth is asked of a repo this test makes, so
## it is proved in a clean lane and a dirty one alike: clean reads clean, an untracked file reads dirty, and the stamp's words change with
## it. The stamp under test is headless, where `BuildPlate.dirty` never shells out, so its cache is set by hand and put back.
## RED with `dirty_in` always false (a dirty tree still reads clean), with `shown_line` ignoring it, or with `plate` reading `line()`.
func _a_dirty_tree_says_so() -> void:
	var repo: String = OS.get_cache_dir().path_join("dirtystamp_" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(repo)
	var said: Array = []
	var made: bool = OS.execute("git", ["-C", repo, "init", "-q"], said) == 0
	FileAccess.open(repo.path_join("a.txt"), FileAccess.WRITE).store_string("one")
	OS.execute("git", ["-C", repo, "add", "a.txt"], said)
	OS.execute("git", ["-C", repo, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "one"], said)
	var clean: bool = not BuildPlate.dirty_in(repo)
	FileAccess.open(repo.path_join("a.txt"), FileAccess.WRITE).store_string("two")
	var edited: bool = BuildPlate.dirty_in(repo)
	OS.execute("git", ["-C", repo, "checkout", "-q", "a.txt"], said)
	FileAccess.open(repo.path_join("b.txt"), FileAccess.WRITE).store_string("new")
	var untracked: bool = BuildPlate.dirty_in(repo)
	_check("a_repo_reads_clean_then_dirty_as_git_says", made and clean and edited and untracked,
		"made %s, clean %s, edited %s, untracked %s" % [made, clean, edited, untracked])
	_check("no_git_is_not_dirty", not BuildPlate.dirty_in(OS.get_cache_dir().path_join("no_such_folder")), "")
	var was: int = BuildPlate._dirty
	BuildPlate._dirty = 0
	var tidy: String = BuildStamp.plate()
	BuildPlate._dirty = 1
	var dirtied: String = BuildStamp.plate()
	BuildPlate._dirty = was
	_check("the_stamp_says_dirty_only_when_dirty", not tidy.contains("+dirty") and dirtied.contains(BuildPlate.commit().substr(0, BuildPlate.SHORT) + "+dirty".insert(0, " "))
		and BuildPlate.line() == BuildPlate.line().replace(" +dirty", ""), "clean '%s', dirty '%s'" % [tidy, dirtied])
	OS.move_to_trash(repo)


## WHICH LANE AND WHICH WORKTREE (lane/stamps, 2026-09-19). The expected words are asked of GIT (`--show-toplevel`, the branch), not of
## the reader under test, and the reader's rule is then run on paths the test types, so a lane's folder and the shared checkout are both
## proved in whichever one this is run from. HOW BOTH WERE CHECKED: run in the lane `C:\gg-wt\stamps` it passes; the shared checkout's run is
## the sweeper's after the merge, and the fixed paths below prove the half of the rule that this checkout is not.
func _the_lane_and_the_worktree() -> void:
	var here: String = ProjectSettings.globalize_path("res://")
	var said: Array = []
	OS.execute("git", ["-C", here, "rev-parse", "--show-toplevel"], said)
	var top: String = String(said[0]).strip_edges() if not said.is_empty() else ""
	said.clear()
	OS.execute("git", ["-C", here, "branch", "--show-current"], said)
	var branch: String = String(said[0]).strip_edges() if not said.is_empty() else ""
	var stamp: String = BuildStamp.text()
	var top_shown: String = top.replace("/", char(92)) if OS.get_name() == "Windows" else top
	_check("the_stamp_names_the_worktree_git_says_this_is", not top.is_empty() and stamp.ends_with(BuildPlate.DOT + top_shown),
		"stamp '%s', git toplevel '%s'" % [stamp, top_shown])
	# THE LANE: "main" on the shared checkout's branch; a lane's own branch name in a lane (folders and branches are named alike).
	var lane: String = stamp.substr(BuildPlate.shown_line().length() + BuildPlate.DOT.length()).get_slice(BuildPlate.DOT, 0)
	_check("the_stamp_names_the_lane_git_says_this_is", (branch == "main" and lane == "main") or (branch.begins_with("lane/") and lane == branch),
		"stamp lane '%s', git branch '%s'" % [lane, branch])
	# THE RULE ON PATHS OF THE TEST'S OWN, so each half is proved wherever the suite runs.
	var lane_words: String = BuildPlate.words_for("C:/gg-wt/harrier")
	_check("a_lane_folder_is_a_lane_and_its_path_is_shown", lane_words.begins_with("lane/harrier" + BuildPlate.DOT)
		and lane_words.ends_with("gg-wt" + (char(92) if OS.get_name() == "Windows" else "/") + "harrier"), lane_words)
	var main_words: String = BuildPlate.words_for("C:/Users/Graham/Desktop/godotgames")
	_check("any_other_folder_is_main_and_its_path_is_shown", main_words.begins_with("main" + BuildPlate.DOT) and main_words.contains("godotgames"),
		main_words)
	_check("the_worktree_is_the_folder_above_the_project", BuildPlate.worktree_of("C:/gg-wt/harrier/cockpit/") == "C:/gg-wt/harrier"
		and BuildPlate.worktree_of("C:" + char(92) + "gg-wt" + char(92) + "harrier" + char(92) + "cockpit") == "C:/gg-wt/harrier",
		BuildPlate.worktree_of("C:/gg-wt/harrier/cockpit/"))


## EVERY PROBE THAT SAVES A PICTURE OF A SUBVIEWPORT OF ITS OWN puts the stamp in it (`attach_to`): the root's stamp is not drawn into a stage,
## and a probe that forgot it made pictures nobody could place -- seven did on 2026-09-19. A file that makes a SubViewport, reads its image and
## does not attach the stamp fails here unless it is named in `STAGES_WITHOUT_THE_STAMP` with its reason. THE ROOT'S OWN pictures and every
## MovieWriter frame (which is the root's) carry the autoload's stamp with no help: the stamp's layer is the root's own, asserted in `_every_level`.
const STAGES_WITHOUT_THE_STAMP: Dictionary = {
	"daytime_shot.gd": "its two halves are SubViewports laid side by side in the ROOT's own canvas, and the picture saved is the root's, stamped",
	"director_cost.gd": "a cost probe: its second view is timed, and the picture saved of the root beside it is the root's, stamped",
	"mist_multiview.gd": "a pixel measurement of the mist through a second view; a stamp in it would be measured as mist",
	"ocean_height_shot.gd": "reads displaced heights back out of the picture as numbers; a stamp in the picture would be a wrong height",
	"detail_probe.gd": "reads three pixels of a 400x200 stage back against named colours; a stamp in the picture could land in a sample and be read as the detail layer",
	"phantom_wear_shot.gd": "brightness at two projected places on the airframe, wear on against wear off; a stamp in either picture would be measured as paint",
}

## A SCRIPT'S SOURCE WITH EVERY COMMENT TAKEN OUT: from a `#` that is not inside a quoted string to the end of its line.
## Quotes are tracked with their backslash escapes; a triple-quoted string reads as an empty string and then a string,
## which puts a `#` on the right side of it anyway.
static func code_of(source: String) -> String:
	var out: PackedStringArray = []
	for line in source.replace("\r", "").split("\n"):
		var quote: String = ""
		var keep: int = line.length()
		var i: int = 0
		while i < line.length():
			var c: String = line[i]
			if quote != "":
				if c == "\\":
					i += 1
				elif c == quote:
					quote = ""
			elif c == "\"" or c == "'":
				quote = c
			elif c == "#":
				keep = i
				break
			i += 1
		out.append(line.substr(0, keep))
	return "\n".join(out)


## THE SCAN'S OWN FIXTURES: a commented-out call is no call, a `#` inside a string is no comment, a real call stays.
func _the_scan_reads_code_and_not_comments() -> void:
	var commented: String = code_of("\t# BuildStamp.attach_to(glass)\n\t## BuildStamp.attach_to(glass)")
	var real: String = code_of("\tBuildStamp.attach_to(glass) # stamped")
	var quoted: String = code_of("\tprint(\"# not a comment\"); BuildStamp.attach_to(glass)")
	_check("a_commented_out_attach_to_is_not_a_call", not commented.contains("attach_to(") and real.contains("BuildStamp.attach_to(")
		and quoted.contains("BuildStamp.attach_to("), "commented '%s', real '%s', after a quoted #: '%s'" % [commented, real, quoted])


func _no_probe_photographs_a_stage_without_the_stamp() -> void:
	var missing: PackedStringArray = []
	for name in DirAccess.get_files_at("res://tests"):
		if not name.ends_with(".gd") or name == "build_stamp.gd":
			continue
		# THE CODE, NOT THE COMMENTS (lane/shiplegs, 2026-09-20): a commented-out `BuildStamp.attach_to(` -- what somebody does
		# while debugging and forgets to put back -- satisfied a plain substring scan and left the pictures unstamped. The line
		# is drawn at comments: a call under `if false:` or in a function nothing calls still counts, as it would for any
		# text scan, and parsing GDScript to catch those would be a second copy of the language.
		var source: String = code_of(FileAccess.get_file_as_string("res://tests/" + name))
		if source.contains("SubViewport.new()") and source.contains(".get_texture().get_image()") and not source.contains("BuildStamp.attach_to(") \
				and not STAGES_WITHOUT_THE_STAMP.has(name):
			missing.append(name)
	_check("every_probe_that_photographs_a_stage_puts_the_stamp_in_it", missing.is_empty(), "without it: %s" % [missing])


## `release_beta.ps1` writes the keys into an [application] section, so each is named there as `build/name=` and so on.
func _the_release_script_bakes_what_the_plate_reads() -> void:
	var script: String = FileAccess.get_file_as_string("res://tools/release_beta.ps1")
	var missing: PackedStringArray = []
	for key in [BuildPlate.NAME_SETTING, BuildPlate.COMMIT_SETTING, BuildPlate.BRANCH_SETTING, BuildPlate.TIME_SETTING]:
		if not key.begins_with("application/") or not script.contains(key.trim_prefix("application/") + "="):
			missing.append(key)
	_check("the_release_script_bakes_every_key_the_plate_reads", missing.is_empty() and script.contains("[application]"),
		"missing %s" % [missing])


## ---- where it is ------------------------------------------------------------------------------------------------

func _the_corner_at_every_size() -> void:
	var root: Window = get_tree().root
	var was: Vector2i = root.size
	for size in SIZES:
		root.size = size
		for i in range(3):
			await get_tree().process_frame
		var at: Rect2 = BuildStamp.rect()
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		var near_x: float = float(size.x) * CORNER_SHARE
		var near_y: float = float(size.y) * CORNER_SHARE
		_check("in_the_lower_right_and_on_screen_at_%dx%d" % [size.x, size.y],
			at.has_area() and screen.encloses(at) and at.get_center().x > size.x * 0.5 and at.get_center().y > size.y * 0.5
				and float(size.x) - at.end.x < near_x and float(size.y) - at.end.y < near_y,
			"stamp %s on %s" % [at, size])
	root.size = was
	await get_tree().process_frame


## A BUTTON UNDER THE STAMP, and a real click pushed where the stamp is drawn: the button hears it.
func _a_click_goes_through() -> void:
	# AT THE CANVAS'S OWN SIZE: a headless root is a few dozen pixels across, where the button would be under everything.
	var root: Window = get_tree().root
	var was: Vector2i = root.size
	root.size = Vector2i(1600, 900)
	var under := CanvasLayer.new()
	under.layer = 10
	add_child(under)
	var button := Button.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	under.add_child(button)
	var pressed: Array[bool] = [false]
	button.pressed.connect(func(): pressed[0] = true)
	await get_tree().process_frame
	var at: Vector2 = BuildStamp.rect().get_center()
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = at
		click.global_position = at
		get_viewport().push_input(click)
		await get_tree().process_frame
	var ignoring: bool = true
	for node in BuildStamp.find_children("*", "Control", true, false):
		ignoring = ignoring and (node as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE
	_check("a_click_on_the_stamp_reaches_what_is_under_it", pressed[0] and ignoring,
		"clicked %s: button %s, every stamp control ignores the mouse %s" % [at, pressed[0], ignoring])
	under.queue_free()
	root.size = was
	await get_tree().process_frame


## A PROBE'S OWN STAGE, a SubViewport the root's stamp is not drawn into: `attach_to` puts one in its lower right, sized
## to it, once however often it is asked.
func _a_stage_of_its_own() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(960, 540)
	stage.disable_3d = true
	add_child(stage)
	var first: Label = BuildStamp.attach_to(stage)
	var again: Label = BuildStamp.attach_to(stage)
	for i in range(3):
		await get_tree().process_frame
	var at: Rect2i = BuildStamp.pixels_in(stage)
	_check("a_stage_of_its_own_carries_the_stamp_in_its_lower_right",
		first != null and first == again and first.text == BuildStamp.plate() and first.text.contains(BuildPlate.where()) and at.has_area()
			and Rect2i(Vector2i.ZERO, stage.size).encloses(at) and at.end.x > 960 - 960 * CORNER_SHARE
			and at.end.y > 540 - 540 * CORNER_SHARE and first.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"stamp %s on 960x540, '%s', once %s" % [at, first.text if first != null else "", first == again])
	stage.queue_free()
	await get_tree().process_frame


## ---- everywhere ----------------------------------------------------------------------------------------------------

func _every_level() -> void:
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	await _back_to_the_desk()
	_the_stamp_is_up_and_on_top("the desk")
	var flown: PackedStringArray = []
	for chart in ChartDrawer.charts():
		var id: String = chart.id
		if not await _fly(id):
			_check("flew_%s" % id, false, "the world never came up")
			continue
		flown.append(id)
		_the_stamp_is_up_and_on_top(id)
		if WITHOUT_A_CLIPBOARD.has(id):
			var boards: Array = get_tree().current_scene.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n is Clipboard)
			_check("%s_really_has_no_clipboard_so_its_exemption_stands" % id, boards.is_empty(), "%d clipboards: %s" % [boards.size(), WITHOUT_A_CLIPBOARD[id]])
		else:
			await _the_board_says_it_on_every_tab(id)
		await _back_to_the_desk()
	_check("the_levels_without_a_clipboard_are_the_one_named", WITHOUT_A_CLIPBOARD.keys() == ["trace"], "%s" % [WITHOUT_A_CLIPBOARD.keys()])
	_check("every_usable_level_was_visited", not flown.is_empty() and flown.size() == ChartDrawer.charts().size(),
		"%s" % [flown])


func _the_stamp_is_up_and_on_top(where: String) -> void:
	var higher: PackedStringArray = []
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var layer := node as CanvasLayer
		# Only layers drawn into the same picture: a board's page is a SubViewport of its own.
		if layer != BuildStamp.layer() and layer.layer >= BuildStamp.layer().layer and layer.get_viewport() == get_tree().root:
			higher.append("%s at %d" % [layer.get_path(), layer.layer])
	_check("the_stamp_is_up_in_%s" % where.replace(" ", "_"),
		BuildStamp.is_showing() and BuildStamp.label().is_visible_in_tree() and BuildStamp.text() == BuildStamp.plate()
			and BuildStamp.text().contains(BuildPlate.where()) and BuildStamp.text().contains("lane/") \
				== BuildPlate.lane_of(BuildPlate.worktree_of(ProjectSettings.globalize_path("res://"))).begins_with("lane/")
			and BuildStamp.layer().get_viewport() == get_tree().root and BuildStamp.rect().has_area(), "showing %s, '%s'" % [BuildStamp.is_showing(), BuildStamp.text()])
	_check("the_stamp_is_on_top_in_%s" % where.replace(" ", "_"), higher.is_empty(),
		"layer %d; at or above it: %s" % [BuildStamp.layer().layer, higher])


## THE CLIPBOARD, up, walked across every tab: its frame says the line on each.
func _the_board_says_it_on_every_tab(where: String) -> void:
	var board: Clipboard = null
	for node in get_tree().current_scene.find_children("*", "Node3D", true, false):
		if node is Clipboard:
			board = node
			break
	if board == null:
		_check("a_clipboard_in_%s" % where, false, "no Clipboard in the level")
		return
	board.show_board(true)
	await get_tree().process_frame
	var words: Label3D = board.build_line()
	var wrong: PackedStringArray = []
	for tab in ClipboardPage.Tab.values():
		board.page().show_tab(tab)
		await get_tree().process_frame
		if words == null or not words.is_visible_in_tree() or words.text != BuildPlate.line():
			wrong.append(ClipboardPage.Tab.keys()[tab])
	# ON THE FRAME: under the glass's lower edge, not over it, and no wider than the board.
	var fits: bool = false
	var detail: String = "no build line"
	if words != null:
		var box: AABB = words.get_aabb()
		var glass_bottom: float = -Clipboard.SIZE.y * 0.5
		fits = words.position.y < glass_bottom and words.position.y > glass_bottom - TouchPanel.BEZEL \
			and box.size.x > 0.0 and absf(box.size.x) < Clipboard.SIZE.x
		detail = "at y %.4f (glass edge %.4f), %.3f m wide on a %.2f m board" % [words.position.y, glass_bottom,
			box.size.x, Clipboard.SIZE.x]
	_check("the_clipboard_says_it_on_every_tab_in_%s" % where, wrong.is_empty() and fits,
		"tabs without it: %s; %s" % [wrong, detail])
	board.show_board(false)


## ---- the walk, as `tests/level_swap.gd` walks it ---------------------------------------------------------------

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
	for i in range(FLY_FRAMES):
		await get_tree().physics_frame
	return up


func _back_to_the_desk() -> void:
	if not get_tree().current_scene is DeskRoom:
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
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
