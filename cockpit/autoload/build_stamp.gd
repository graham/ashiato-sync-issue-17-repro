extends Node
## THE BUILD, IN THE LOWER RIGHT OF THE SCREEN, ON TOP OF EVERYTHING, ALL THE TIME.
##
## Asked for on 2026-09-18: "a ui element in the game that is always visible and visible in every screenshot and video,
## so we know what build a screenshot, video came from ... (or in 2d on the lower right of the screen)". So this puts
## `BuildPlate.line()` in the bottom right-hand corner of the desktop window, from boot to quit: the desk, every level,
## the loading curtain, and every picture a probe takes of the root viewport and every frame MovieWriter writes of it.
##
## AN AUTOLOAD WITH ITS OWN CanvasLayer, as `Transition` and `Fullscreen` are, so no scene has to remember it and none
## can leave it out (CLAUDE.md rule 11). ON THE TOP LAYER: `LAYER` is above the level curtain's 512, so the stamp is
## still there while the screen is black between levels -- a video of a level change still says which build it was.
## `tests/build_stamp.gd` fails if any CanvasLayer in the tree is at or above it.
##
## IT TAKES NO INPUT. Every Control here ignores the mouse, and the stamp sits in the corner no button in the game uses;
## a label in the way of a click would be a bug with a very confusing report attached.
##
## ---------------------------------------------------------------------------------
## NOT IN THE HEADSET
## ---------------------------------------------------------------------------------
##
## While the root viewport has `use_xr` on, everything drawn into it -- every CanvasLayer -- is composited into the EYE
## buffers, and the desktop window is a blit of an eye (see the note at the top of `autoload/monitor.gd`). So a label
## on the desktop mirror would also be a label welded to the corner of the player's vision, at infinity, in both eyes.
## It hides while the root viewport is in XR, and a player in a headset reads the same line on the clipboard's frame
## (`Clipboard`), which is where "look at the ipad" sends them. The director's recording window is not the root's and
## is never in XR, so it carries its own copy of the stamp whenever it is up: see `_on_monitor`.
##
## ---------------------------------------------------------------------------------
## PROBES THAT MEASURE PIXELS ASK IT WHERE IT IS
## ---------------------------------------------------------------------------------
##
## The user wants it in every screenshot, so it is never switched off for a probe. A probe that measures a region of the
## frame asks `covers(pixel)` and leaves out what the stamp is drawn on, so the one number -- where the stamp is -- lives
## here and nowhere else.

## ---------------------------------------------------------------------------------
## HOW TO TAKE A PICTURE OR A FILM HERE (written 2026-09-19, beside the machinery that stamps them)
## ---------------------------------------------------------------------------------
##
## THE STAMP NAMES THE LANE AND THE WORKTREE (`BuildPlate.where`), read off the running project's own path, so a picture
## from any of nine lanes says where it came from: `dev · da673ea5 · 2026-09-20 · lane/stamps · C:\gg-wt\stamps`. A still of
## the ROOT viewport and every MovieWriter frame (the root's too) carry it with no help. A picture of a SubViewport of your own
## does NOT: call `BuildStamp.attach_to(viewport)`, or `tests/build_stamp.gd` fails on your file (seven probes had forgotten).
## Say what a picture is evidence OF, in the caption or the file name: a picture that proves nothing is worse than none,
## because somebody files it as evidence. Sourcing, scale and the look of models: `modelling_here.md`; windows, keys and
## clicks: `seeing_the_game.md`; the shared GPU: `running_a_team_here.md` ("CAPTURE lines share").
##
##   1. IN-GAME VIEWPORT OR MOVIEWRITER ONLY. NEVER THE DESKTOP: a desktop grab caught another application on the user's
##      screen (2026-09-18). No ddagrab, gdigrab, grim or PrintScreen. Films go through `--write-movie` at a fixed fps.
##   2. TAKE A LINE in `C:\gg-wt\GPU_SLOT_HOLD` while shooting: `CAPTURE <lane> <date> <what>`. CAPTURE lines share with each
##      other; wait while any line starts with `MEASUREMENT`. Remove ONLY YOUR OWN LINE, in a `finally`, so a tool that dies
##      still lets go. (Removing "your line" by a filter on the command line matches the thing running the filter: that is
##      how a tool killed its own shell and left a hold line up for eighteen minutes.)
##   3. `--headless --import` FIRST in any worktree that has merged since it last ran, when a tool launches a scene directly:
##      otherwise it prints no RESULT at all and says nothing about why. `run_all.ps1` does it for you.
##   4. COUNT THE UNIQUE FRAMES of a film before believing it is smooth: `ffmpeg -i X.mp4 -vf mpdecimate,showinfo -f null -`.
##      AND KNOW THE TRAP (lane/warbirds2): mpdecimate's defaults judge a frame by the FRACTION of 8x8 blocks that changed, so
##      a film over open water or flat sky reads 20 per cent unique when a strict threshold says 99. Over water, check the
##      threshold before believing the count.
##   5. FRAME THE SUBJECT, not the frame: fit a line-up to the subject's own size (a six-ship line-up burst the frame; a scale
##      figure placed "in front of the longest vehicle" ended up inside the trailer, invisible for a whole render). An
##      orthographic camera frames the same square at any height, so put the eye under the cloud and turn the level's fog off.
##      At 30 degrees of depression a line-up of boats reads as six decks, and a hull's colour is on its side.
##
## HOW THE LANE HALF WAS CHECKED IN A LANE AND IN THE SHARED CHECKOUT: `tests/build_stamp.gd` reads what it expects from git
## (`--show-toplevel`, the branch), so it holds wherever it runs; run in `C:\gg-wt\stamps` it passes, and the rule itself is run
## on a typed lane path and a typed main-checkout path, so the half this checkout is not is proved too. The shared checkout's
## own run is the sweeper's, after the merge.

## Above `Transition.LAYER` (512), the curtain, and every other layer in the game.
const LAYER: int = 1024
## THE SIZE, in the project's 1600x900 canvas, which `canvas_items` stretch scales with the window: 13.6 px at
## 1280x720 and 30.6 px at 2880x1620. Small enough to leave the picture alone, big enough to read off a video.
const FONT_SIZE: int = 17
## From the corner, in the same canvas units.
const MARGIN: float = 10.0
## Light writing with a dark rim, so it reads on a white cloud and on a black sea alike.
const INK := Color(0.93, 0.95, 0.97, 0.82)
const RIM := Color(0.0, 0.0, 0.0, 0.7)
const RIM_SIZE: int = 4
## How far round the label's box `covers` reaches, in canvas units, for the rim and the shadow.
const BLEED: float = 4.0

var _layer: CanvasLayer = null
var _label: Label = null
## The copy in the director's recording window while it is up, and that window's own layer.
var _recording_label: Label = null
var _in_xr: bool = false


func _ready() -> void:
	# ABOVE ANYTHING A SCENE PAUSES: a paused game's screenshot still says which build it is.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.name = "BuildStampLayer"
	_layer.layer = LAYER
	add_child(_layer)
	_label = _a_stamp()
	_layer.add_child(_label)
	Monitor.now_watching.connect(_on_monitor)
	# AND IN THE LOG, once, so a log sent in with a bug report says which build wrote it -- and so a suite can launch an
	# exported build and read back what it believes it is (`tests/build_export.gd`). BUILT= is the one number the
	# handshake compares, as the pck carries it.
	print("BUILD=%s" % BuildPlate.line())
	print("BUILT=%d" % BuildPlate.time())
	# OFF UNTIL THERE IS A SERVER TO ASK: see `ask_for_the_latest_build`.
	# ask_for_the_latest_build()


## THE HEADSET, READ EVERY FRAME, because the rig turns `use_xr` on and off as it enters and leaves a world and tells
## nobody -- and asking a bool is cheaper than anybody announcing it.
func _process(_delta: float) -> void:
	var xr: bool = get_tree().root.use_xr
	if xr != _in_xr:
		_in_xr = xr
		_label.visible = not xr


## EVERYTHING THE STAMP SAYS: the build's line, then which lane and worktree made the picture (`BuildPlate.where`, derived
## from the project's own path; nothing in a release). Never anything typed here.
func plate() -> String:
	var where: String = BuildPlate.where()
	return BuildPlate.shown_line() + (BuildPlate.DOT + where if not where.is_empty() else "")


## The words on the stamp.
func text() -> String:
	return _label.text


## Whether the stamp is on the desktop now: false only in a headset.
func is_showing() -> bool:
	return _label.visible and _layer.visible


func layer() -> CanvasLayer:
	return _layer


func label() -> Label:
	return _label


## WHERE THE STAMP IS, IN THE ROOT VIEWPORT'S OWN PIXELS -- the pixels of `get_viewport().get_texture().get_image()` --
## with its rim, or an empty rect when it is not showing. What a probe masks out.
func rect() -> Rect2:
	if not is_showing():
		return Rect2()
	return _drawn_at(_label, get_tree().root)


## THE SAME, IN WHOLE PIXELS, rounded outwards: what a probe asks once per picture and tests each pixel against --
## `rect()` is a transform and a multiply, and a probe scanning a 1600x900 frame asks 1.4 million times.
func pixels() -> Rect2i:
	return _whole(rect())


## WHETHER THE STAMP IS DRAWN ON THIS PIXEL of the root viewport's image. A probe measuring a region of the frame skips
## the pixels this says yes to.
func covers(pixel: Vector2i) -> bool:
	return rect().has_point(Vector2(pixel) + Vector2(0.5, 0.5))


## ---------------------------------------------------------------------------------
## ANY OTHER PICTURE
## ---------------------------------------------------------------------------------
##
## "In every screenshot" includes the probes that photograph a SubViewport of their own (a stage the size of the
## picture, which the root's CanvasLayer is not drawn into), and the director's recording window. `attach_to` puts a
## stamp in the lower right of any viewport, sized to it as the root's canvas is sized to the window; `pixels_in` says
## where it landed, for a probe that measures that viewport's pixels. One line each, and asking twice adds nothing.

## PUT THE STAMP IN `viewport`'s lower right, and return its label. A second call on the same viewport returns the first.
func attach_to(viewport: Viewport) -> Label:
	if viewport == null:
		return null
	var there: Label = _stamp_in(viewport)
	if there != null:
		return there
	var layer := CanvasLayer.new()
	layer.name = "BuildStampLayer"
	layer.layer = LAYER
	viewport.add_child(layer)
	var stamp: Label = _a_stamp()
	layer.add_child(stamp)
	var fit := func() -> void:
		if is_instance_valid(stamp):
			_fit(stamp, _height_of(viewport))
	fit.call()
	viewport.size_changed.connect(fit)
	return stamp


## WHERE THE STAMP IS IN `viewport`'s OWN PIXELS, in whole pixels with its rim; empty when it has none.
func pixels_in(viewport: Viewport) -> Rect2i:
	if viewport == get_tree().root:
		return pixels()
	var stamp: Label = _stamp_in(viewport)
	return _whole(_drawn_at(stamp, viewport)) if stamp != null else Rect2i()


## The copy in the director's recording window, or null when nothing is being recorded.
func recording_label() -> Label:
	return _recording_label if is_instance_valid(_recording_label) else null


func _stamp_in(viewport: Viewport) -> Label:
	var layer: Node = viewport.get_node_or_null("BuildStampLayer")
	return layer.get_node_or_null("Stamp") as Label if layer != null else null


func _drawn_at(stamp: Label, viewport: Viewport) -> Rect2:
	var scale: float = maxf(stamp.get_theme_font_size("font_size") / float(FONT_SIZE), 0.01)
	var box := Rect2(Vector2.ZERO, stamp.size).grow(BLEED * scale)
	return viewport.get_final_transform() * stamp.get_global_transform_with_canvas() * box


func _whole(at: Rect2) -> Rect2i:
	if not at.has_area():
		return Rect2i()
	var low := Vector2i(floori(at.position.x), floori(at.position.y))
	return Rect2i(low, Vector2i(ceili(at.end.x), ceili(at.end.y)) - low)


func _height_of(viewport: Viewport) -> float:
	if viewport is SubViewport:
		return float((viewport as SubViewport).size.y)
	if viewport is Window:
		return float((viewport as Window).size.y)
	return viewport.get_visible_rect().size.y


## SIZED TO A VIEWPORT WITH NO STRETCH as the root's canvas is stretched to its window: writing and margins in step.
func _fit(stamp: Label, height: float) -> void:
	var scale: float = height / float(ProjectSettings.get_setting("display/window/size/viewport_height", 900))
	stamp.add_theme_font_size_override("font_size", maxi(int(round(FONT_SIZE * scale)), 11))
	stamp.add_theme_constant_override("outline_size", maxi(int(round(RIM_SIZE * scale)), 2))
	stamp.offset_right = -MARGIN * scale
	stamp.offset_left = -MARGIN * scale
	stamp.offset_bottom = -MARGIN * 0.6 * scale
	stamp.offset_top = -MARGIN * 0.6 * scale


func _a_stamp() -> Label:
	var stamp := Label.new()
	stamp.name = "Stamp"
	stamp.text = plate()
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.focus_mode = Control.FOCUS_NONE
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamp.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	stamp.add_theme_font_size_override("font_size", FONT_SIZE)
	stamp.add_theme_color_override("font_color", INK)
	stamp.add_theme_color_override("font_outline_color", RIM)
	stamp.add_theme_constant_override("outline_size", RIM_SIZE)
	stamp.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.35))
	stamp.add_theme_constant_override("shadow_offset_x", 1)
	stamp.add_theme_constant_override("shadow_offset_y", 1)
	# BOTTOM RIGHT, GROWING UP AND LEFT from the corner, so a longer line never runs off the screen.
	stamp.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	stamp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	stamp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stamp.offset_right = -MARGIN
	stamp.offset_bottom = -MARGIN * 0.6
	stamp.offset_left = -MARGIN
	stamp.offset_top = -MARGIN * 0.6
	return stamp


## ---------------------------------------------------------------------------------
## "WHAT IS THE LATEST BUILD": PLANNED, AND OFF
## ---------------------------------------------------------------------------------
##
## The user, 2026-09-19: "We should also plan to have some sort of 'what is the latest build' http request (commented
## out for now)." What it will do: at boot, one GET to `LATEST_BUILD_URL`, and if the build it names is newer than this
## one, the stamp says so -- "0.2.1 leaping-llama · 3631368a · 2026-09-19 · 0.2.2 is out, 3 days newer" -- and
## `latest_build_heard` tells anybody else who wants to show it (the desk, say). Nothing is downloaded or installed.
##
## THE ANSWER IT EXPECTS, one JSON object, the same fields BUILD_INFO.txt writes for a person:
##
##   {"line": "0.2.2 hungry-heron · 1a2b3c4d · 2026-09-22", "built": 1758560000, "commit": "<40 hex>", "url": "<page>"}
##
## `built` is epoch seconds UTC, `BuildPlate.time()`'s unit, and is the only field compared. The rest are shown.
##
## WHY IT IS OFF: there is no server yet to answer it, and the release script has nowhere to publish one. The URL is empty,
## the call in `_ready` is commented out, and this returns before it makes anything when the URL is empty, so even a
## caller who forgets cannot make a request. No suite may touch the network: `tests/build_time.gd` fails if the URL is
## ever filled in without that check being rewritten, and if a call adds a request to the tree.
##
## TO SWITCH IT ON: put the endpoint in `LATEST_BUILD_URL`, have `tools/release_beta.ps1` publish the JSON above with
## each release, uncomment the call in `_ready`, and give the suite a local server to ask instead.

## Where the latest build is described. EMPTY: nothing is asked. See the note above.
const LATEST_BUILD_URL: String = ""
## How long the one request may take before it is given up, seconds: the stamp must never wait on the network.
const LATEST_BUILD_PATIENCE: float = 5.0

## The newest build the server named, once it has answered: its line and its build time.
signal latest_build_heard(line: String, built: int)


## ASK ONCE WHICH BUILD IS THE LATEST. Returns whether a request was made: never while `LATEST_BUILD_URL` is empty.
func ask_for_the_latest_build() -> bool:
	if LATEST_BUILD_URL.is_empty():
		return false
	var asking := HTTPRequest.new()
	asking.name = "LatestBuild"
	asking.timeout = LATEST_BUILD_PATIENCE
	add_child(asking)
	asking.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		asking.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			_heard_the_latest_build(body))
	return asking.request(LATEST_BUILD_URL) == OK


## THE SERVER'S ANSWER, checked (rule 8: it is a stranger's): a JSON object with a `line` and a whole `built`, or nothing
## is done. Newer than this build by a minute or more, and the stamp says so.
func _heard_the_latest_build(body: PackedByteArray) -> void:
	var said: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not said is Dictionary or not (said as Dictionary).get("line") is String \
			or not ((said as Dictionary).get("built") is float or (said as Dictionary).get("built") is int):
		push_warning("[build] the latest-build answer was not {line, built}; ignored")
		return
	var line: String = Logbook.clean(String(said["line"]), 64)
	var built: int = int(said["built"])
	latest_build_heard.emit(line, built)
	var age: String = BuildPlate.age_words(built, BuildPlate.time())
	if age.ends_with("newer"):
		_label.text = "%s%s%s is out, %s" % [plate(), BuildPlate.DOT, line.get_slice(" ", 0), age]


## THE DIRECTOR'S WINDOW WENT UP, OR DOWN. `Monitor` announces what it is watching and knows nothing of this; a
## recording is a video, so the stamp goes in it too, through `attach_to` like any other picture.
func _on_monitor(_at: Node3D) -> void:
	var window: Window = Monitor.window()
	_recording_label = attach_to(window) if window != null else null
