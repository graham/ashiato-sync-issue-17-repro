extends Node3D
class_name DioramaBoard
## THE CHESSBOARD: a miniature of the level about a metre across, sculpted ONCE out of the terrain's own heightfield,
## with a little piece standing on it for every contact the radar picture holds. Rebuilt from numbers, never
## photographed.
##
## THE USER, 2026-09-20: *"make a new "diorama" of sorts that shows the state of all the units, almost like a live
## chessboard with the terrain and planes, boats, flying around."*
##
## ---------------------------------------------------------------------------------------------------
## WHY THIS IS CHEAP, WHICH IS THE POINT THE USER MADE
## ---------------------------------------------------------------------------------------------------
##
## `world/level_map.gd` renders the REAL world -- the real mountains, the real trees, the real aircraft, at real scale,
## eight kilometres from the camera -- into a 1024 px texture, and freezes it because doing it per frame would cost a
## second world view every frame. Everything expensive about that is the distance and the scale.
##
## **This board has neither.** It is one static mesh of about 18,000 triangles sitting at the origin, and the only
## thing that happens per update is a transform written to at most a few dozen small pieces. There is no terrain
## geometry in it, no level of detail, no shader that asks where the camera is (`working_with_godot.md`:
## `CAMERA_POSITION_WORLD` is minus the camera on a double build), and nothing in it is ever further from the origin
## than `DioramaScale.BOARD_HALF`. It is looked at by a camera -- there is no drawing 3D without one -- but that camera
## is thirty centimetres from a model of an island, not eight kilometres above a real one.
##
## THE TERRAIN IS BAKED ONCE because terrain does not move. `Terrain.surface_heights(corner, texels, spacing)` is a
## whole-grid sampler that already existed for exactly this shape of job -- it bakes cockpit-mist's 128x128 chart --
## and it costs ONE call into the ground function instead of one a texel. The bake is measured and printed by
## `build`'s report, and `tests/diorama.gd` holds the baked heights against `Terrain.surface_height`.
##
## ---------------------------------------------------------------------------------------------------
## A PIECE IS A TINY MODEL, AT A SIZE CHOSEN TO BE READ
## ---------------------------------------------------------------------------------------------------
##
## **THE USER ASKED FOR MODELS, 2026-09-20: *"can you make sure you use tiny models for the planes?"*** This file used
## to draw a flat silhouette plate per contact and argued for it at length -- at 1:12,000 an F-4 is 1.4 mm, so a plate
## sized to be legible was the honest abstraction and "almost like a live chessboard" was read as arguing for tokens.
## The user wants little aeroplanes, and a diorama is exactly the thing that has them.
##
## **The scale objection was never wrong, and it is answered by breaking size away from position rather than by
## refusing models.** `DioramaMiniature.of` builds the craft at LIFE SIZE out of the simulation's own figures, and a
## piece is then shrunk by `_model_scale` to the readable size `_token_radius` picks. So:
##
##   **POSITION GOES THROUGH `DioramaScale`. SIZE DOES NOT.** That sentence is unchanged and is still the whole rule.
##
## A jumbo is drawn a sensible amount bigger than a Cessna rather than 1:12,000 bigger, which would be 5.9 mm against
## 0.9 mm and unreadable for both.
##
## **THE REAL CRAFT MODELS WERE TRIED AND REFUSED ON A MEASUREMENT.** `VehicleView.setup(0, kind)` builds any kind's
## actual exterior with no simulation running, and `../craft_model_audit.md` counts what that costs: a Cessna is
## about 40,000 triangles, an Osprey 118,000, a Hawkeye 164,000. Seventy-five contacts is a routine board, so real
## models would be **three to twelve million triangles** on the one screen whose whole justification is that it is
## cheap. `world/diorama_miniature.gd` builds forty-odd triangles per kind from `extents` and `span` instead, cached
## per KIND and shared by every contact of it -- see that file for what it makes and how it is proportioned.
##
## NOTHING HERE NAMES A KIND. `VehicleCatalogue.group` sorts kinds into aeroplanes, helicopters, ships and ground by
## the MOVEMENT MODEL the simulation declares, so a kind added in the C++ gets a miniature with no edit to this file.
##
## ### The stalk is the reason a board beats a plot
##
## Every piece stands on a thin vertical stalk from the board's surface up to its true altitude, with a small dot where
## the stalk meets the ground. That is the wargame table's altitude peg and it does three jobs at once:
##
##   1. **It shows height.** The flat plot cannot: `ui/menus/map_canvas.gd` draws a triangle per contact and has
##      nowhere to put an altitude, so a controller reads it off the side panel one contact at a time.
##   2. **It says where the contact actually is on the ground.** A piece floating over a board is ambiguous from every
##      angle except straight down; the dot is not.
##   3. **It shows climb and descent**, because the stalk gets longer or shorter while you watch it.
##
## A ship gets no stalk. It is on the water, and a stalk of zero length drawn anyway is a dot of ink saying nothing.
##
## ### Grey, and `manned` reads in tone
##
## **Every radar contact is anonymous, including a manned one** -- `world/radar_set.gd` is explicit about why: radar
## says whether somebody is aboard, never who, and a machine wearing a player's colour while carrying no player's name
## is the exact lie `world/air_picture.gd` was written to prevent. So a miniature is pewter grey and never a livery.
##
## `manned` reads in TONE: a crewed contact is bright and an empty one darker. It used to be solid-plate against
## outline, and the models took that channel away -- a little aeroplane drawn as a wireframe is a scribble at 20 mm.
## `radar_set.gd` names "solid against an outline, or size" as the options, and size is spoken for by the kind.
##
## ### And the label says the three things the user asked for
##
## *"make sure their direction, speed, altitude is visible with a small text label"* -- two `Label3D` lines per piece,
## the call sign over it and `bearing / metres / metres per second` under it, in the same words the side panel uses.
## See `NAME_POINTS`.
##
## ---------------------------------------------------------------------------------------------------
## IT DRAWS WHAT IT IS HANDED (rule 5)
## ---------------------------------------------------------------------------------------------------
##
## `show_contacts` takes rows and decides nothing. It never reaches for `Sim.current` and never calls `AirPicture`.
## **That is not tidiness -- it is the whole meaning of the station it stands in.** `ControlStation` draws
## `RadarWatch.contacts()`, the sensor-limited picture, and `docs/crew.md` records that hiding behind a ridge genuinely
## keeps you off it. A board that fetched its own contacts from the simulation would hand the controller omniscience
## back and **nobody would notice, because it would look better.**
##
## ---------------------------------------------------------------------------------------------------
## BETWEEN SWEEPS: HOLD, OR DEAD RECKON -- AND THE DIFFERENCE IS NOT COSMETIC
## ---------------------------------------------------------------------------------------------------
##
## Radar is published once a second (`RadarWatch.EVERY_MSEC`) and the station redraws four times a second, so three
## updates in four have nothing new to say. There are exactly two honest things to do with that and `reckoning` picks
## between them.
##
## **HOLD (`reckoning = false`).** Every piece stays where the last sweep put it. Nothing on the board is ever anything
## but a position the sensor actually reported. The cost is that the board steps once a second and is frozen in
## between, which the user may read as a stutter -- their words were "planes, boats, **flying around**".
##
## **DEAD RECKON (`reckoning = true`).** Every piece is advanced along ITS OWN REPORTED COURSE by the age of the
## picture: `speed` and `heading` are columns of the row (`RadarSet.COLUMNS`), so this is arithmetic on what the sensor
## said and not a position invented for the look of it. It is what a real plot extrapolator does and it has a name that
## can be said out loud, which is the test of whether a display is allowed to do something.
##
## **IT SNAPS, IT DOES NOT EASE, and that falls out of doing it by AGE rather than by tweening.** A piece is drawn at
## `reported + course * age`, so when a new page lands the age drops to nothing and the piece is back on a reported
## position in one frame. That matters: easing a piece from where it was guessed to be towards where it turns out to be
## would HIDE the size of the guess's error, which is the one thing the operator should be allowed to see. When the
## reckoning is good the snap is invisible because the guess was nearly right; when a contact turns hard, it jumps, and
## it SHOULD jump.
##
## **IT IS STILL A CLAIM AND THE BOARD SAYS SO.** `ControlStation` writes it on the panel, and it is off by default:
## a board that quietly extrapolated would be a board telling an operator where an aeroplane is on no better authority
## than its own arithmetic.
##
## **IT IS FLAT, AND THAT IS A LIMITATION WITH A REASON.** A row carries `speed` and a horizontal `heading` and no
## vertical rate at all, so a reckoned contact advances across the ground and its stalk keeps the height it reported.
## A climbing aircraft is drawn at the altitude it last said, which is honest -- the alternative is differencing two
## sweeps for a rate, which is a second claim built on top of the first. `speed` is the magnitude of the whole velocity
## (`RadarSet.row_of`), so a climbing contact is reckoned very slightly too far across the ground; at a 10-degree climb
## that is 1.5% of a second's travel, under two metres, which is a tenth of a millimetre on the board.

## THE BOARD'S RESOLUTION, samples across. 96 over the island's 14.4 km is a sample every 150 m, which draws the
## island's ridges and its coastline legibly at 1.2 m across; 128 costs 78% more triangles for relief nobody can see at
## this scale. Measured in `build`'s report.
const TEXELS: int = 96

## HOW BIG A PIECE IS, in board metres, at the two ends of the band. A plate is sized from its kind's real span
## squeezed into this, so the order is right and the extremes are still legible.
##
## THE FIRST PICTURE HAD THESE AT 14 AND 32 MM AND THEY WERE TOO SMALL. From the default view the plates read as grey
## scratches -- you could see that something was there and not what it was -- while close in they were fine, which is
## exactly the trap: the shape that works at the distance you happen to be debugging at. 20 and 44 mm read as
## aeroplanes from the whole dolly range without the board turning into a pile of counters.
const TOKEN_SMALL: float = 0.020
const TOKEN_LARGE: float = 0.044
## THE REAL SPANS those two ends correspond to, metres. A Cessna is about 11 m across and a jumbo about 65; anything
## outside is clamped, so a kind of any size lands somewhere on the band.
const SPAN_SMALL: float = 10.0
const SPAN_LARGE: float = 70.0

## THE LABEL OVER A PIECE, IN TWO LINES. `fixed_size` on both, so they stay the same size on screen however far the
## camera is pulled back -- a name that shrank with the board would be the first thing to become unreadable, and the
## name is what an operator SAYS.
##
## TWO `Label3D`s AND NOT ONE, because the two lines are not equally important. The call sign is what you say on the
## radio and it is brighter and larger; the numbers are what you read off, and they are smaller and dimmer so that
## seventy-five of them at once do not turn the board into a wall of text. One label could not do that.
##
## The user asked for both, 2026-09-20: *"make sure their direction, speed, altitude is visible with a small text
## label"*.
const NAME_POINTS: int = 26
const NAME_PIXEL: float = 0.00040
const DATA_POINTS: int = 22
const DATA_PIXEL: float = 0.00034
const NAME_OUTLINE: int = 10
const NAME_INK := Color(0.86, 0.91, 0.96)
const DATA_INK := Color(0.63, 0.72, 0.80)
## How far above a piece the name floats, and how far under it the numbers sit, board metres.
const NAME_OVER: float = 0.013
const DATA_UNDER: float = 0.0092

## How thick a stalk and how wide its dot, in board metres. Thin enough not to be mistaken for a piece, thick enough to
## survive a 1600 px viewport.
const STALK_WIDE: float = 0.0011
const DOT_WIDE: float = 0.0042
## How far a plate is held clear of the stalk's top, board metres: nothing, the plate IS the top of the stalk.
const PLATE_LIFT: float = 0.0

## The colours of the board itself, by what stands at a texel. Not the game's palette: a board is read in a lit room
## beside a dark plot, so these are the muted greens and greys of a printed relief map rather than the level's own
## grass and rock.
const WATER := Color(0.16, 0.28, 0.42)
const SHORE := Color(0.60, 0.57, 0.44)
const GRASS := Color(0.31, 0.42, 0.27)
const ROCK := Color(0.44, 0.42, 0.38)
const SNOW := Color(0.82, 0.83, 0.84)
## WHERE THOSE BANDS CHANGE, AS FRACTIONS OF THE LEVEL'S OWN HIGHEST GROUND rather than as metres.
##
## **THEY WERE ABSOLUTE METRES -- 18, 190 and 430 -- AND THE FIRST PICTURE SHOWED WHY THAT IS WRONG.** The island's
## highest rock is 653 m, so two thirds of every ridge on it came out rock-grey or snow-white and the board looked like
## Iceland. It was not a bad choice of numbers: it was a choice of numbers AT ALL, on a project whose levels range from
## a 14 km island to a 65 km generated world with mountains of quite different heights, where any fixed band is
## flattering to one level and wrong on the rest.
##
## Measured off the bake, a band is the same PROPORTION of the relief whatever the level, so the snow line is near the
## tops because it is defined as being near the tops (rule 4 -- the one measurement is `highest_m`, and the bands are
## computed from it rather than typed beside it).
const SHORE_TO: float = 0.04
const GRASS_TO: float = 0.55
const ROCK_TO: float = 0.93
## And the least relief worth banding, metres. Under this the level is flat enough that proportions of it are noise, so
## everything standing above the water is simply green.
const BANDS_NEED: float = 60.0

## The scale, which is the only thing that knows how big the world is. Built by `build`.
var scale_of: DioramaScale = null
## THE BAKED SURFACE, as `Terrain.surface_heights` returned it: `TEXELS` by `TEXELS`, rows along z, index j * TEXELS + i,
## sample (i, j) at the texel's CENTRE. Kept because a stalk must stand on the board that is DRAWN and not on a second
## opinion about where the ground is (rule 4) -- `surface_board_y` reads this grid, never `Terrain` again.
var heights := PackedFloat32Array()
## The corner those samples start from and how far apart they are, world metres. `surface_board_y` needs both.
var corner := Vector2.ZERO
var spacing: float = 1.0
## What the last `show_contacts` put on the board, so a suite can ask without reading the scene.
var pieces_shown: int = 0
## WHETHER PIECES ARE ADVANCED ALONG THEIR OWN REPORTED COURSE between sweeps. Off by default, and the station says so
## on the panel when it is on. See the doc block -- this is the one setting here that changes what the board CLAIMS.
var reckoning: bool = false
## WHETHER EVERY PIECE WEARS ITS CALL SIGN. On by default: the point of a board is that people talk about it out loud,
## and a token with no name on it can only be pointed at. Off is for a picture of the terrain alone.
var naming: bool = true
## How far the furthest piece was carried by the last reckoning, world metres. Reported so the picture can be captioned
## with the size of the guess rather than the fact of it.
var reckoned_most_m: float = 0.0

var _ground: MeshInstance3D = null
var _pieces: Node3D = null
## The pool, grown and never shrunk: a contact that goes off radar hides its piece rather than freeing it, because the
## picture changes wholesale once a second and freeing ninety nodes a second to build ninety more is work for nothing.
var _pool: Array[Node3D] = []
## One miniature per KIND, built once and shared by every contact of that kind. See `_miniature_of`.
var _models: Dictionary = {}
## Piece materials by colour and solidity, made once each. See `_tinted`.
var _paints: Dictionary = {}
## THE LAST ROWS THIS BOARD WAS HANDED, how old they were when it was handed them, and how long ago that was. Only
## `_process` reads them, and only while reckoning. See `show_contacts`.
var _rows: Array = []
var _aged: float = 0.0
var _since_told: float = 0.0
## HOW HIGH THIS LEVEL'S GROUND GOES above the water, metres, measured off the bake. The colour bands are fractions of
## it (`SHORE_TO`), so it is worked out before the mesh is sculpted.
var _relief: float = 0.0


## BUILD THE BOARD for a level covering `covering` metres each way from `middle`. Both come from `LevelMap` rather than
## from `Terrain`, so the board and the flat plot cover the same ground by construction.
##
## Returns what it cost and what it found, for the probe's caption and the suite's detail line: the bake is the one
## expensive thing this feature does and a number nobody prints is a number nobody checks.
func build(covering: float, middle: Vector2) -> Dictionary:
	var began: int = Time.get_ticks_usec()
	scale_of = DioramaScale.new(covering, middle)
	spacing = 2.0 * covering / float(TEXELS)
	# THE BOARD'S RIM SITS HALF A TEXEL INSIDE THE PLOT'S EXTENT, and that is the sampler's contract rather than an
	# error: `surface_heights` samples texel CENTRES, so the first sample is `spacing * 0.5` in from the corner. Written
	# down because `tests/diorama.gd` asserts against `Terrain.surface_height` at exactly these points and would
	# otherwise look half a cell wrong.
	corner = Vector2(middle.x - covering, middle.y - covering)
	heights = Terrain.surface_heights(corner, TEXELS, spacing)
	var sampled: int = Time.get_ticks_usec()

	# HOW HIGH THIS LEVEL GOES, BEFORE ANYTHING IS DRAWN, because the colour bands are fractions of it. See `SHORE_TO`.
	var lowest: float = INF
	var highest: float = -INF
	for h in heights:
		if h == -INF or h == INF:
			continue
		lowest = minf(lowest, h)
		highest = maxf(highest, h)
	_relief = 0.0 if highest == -INF else maxf(highest - Terrain.SEA_LEVEL, 0.0)

	if _ground != null:
		_ground.queue_free()
	_ground = MeshInstance3D.new()
	_ground.name = "Board"
	_ground.mesh = _sculpt()
	add_child(_ground)

	if _pieces == null:
		_pieces = Node3D.new()
		_pieces.name = "Pieces"
		add_child(_pieces)

	var done: int = Time.get_ticks_usec()
	return {
		"texels": TEXELS, "spacing_m": spacing, "covering_m": covering,
		"one_to": scale_of.world_metres_per_board_metre(),
		"board_across_m": DioramaScale.BOARD_HALF * 2.0,
		"sample_msec": float(sampled - began) / 1000.0,
		"build_msec": float(done - began) / 1000.0,
		"triangles": (TEXELS - 1) * (TEXELS - 1) * 2,
		"lowest_m": lowest, "highest_m": highest,
		"relief_mm": scale_of.length_to_board(highest - lowest) * 1000.0,
	}


## THE SURFACE OF THE DRAWN BOARD under a world point, in BOARD metres of y. Off the baked grid, by the nearest sample,
## because the stalk has to land on the mesh a person can see -- asking `Terrain` again here would be a second answer to
## the same question and the two would part company the moment the board's resolution changed.
##
## **IT IS THE NEAREST SAMPLE AND NOT THE TERRAIN'S OWN ANSWER, and that is worth a number.** On a mountainside the two
## differ by as much as a texel's worth of slope: `tests/diorama.gd` measured **32.5 m** at (1500, -3750), where the
## terrain stands at 480.9 m and the board's grid says 448.4. That is the board's 150 m resolution and not an error --
## a stalk stands on the mesh that is drawn, which is the only place it can stand without appearing to float or to sink.
## A finer grid would narrow it; nothing else would.
func surface_board_y(world_x: float, world_z: float) -> float:
	if heights.is_empty() or scale_of == null:
		return 0.0
	var i: int = clampi(int(floorf((world_x - corner.x) / spacing)), 0, TEXELS - 1)
	var j: int = clampi(int(floorf((world_z - corner.y) / spacing)), 0, TEXELS - 1)
	var h: float = heights[j * TEXELS + i]
	if h == -INF or h == INF:
		h = Terrain.SEA_LEVEL
	return scale_of.to_board(Vector3(0.0, h, 0.0)).y


## PUT THE PICTURE ON THE BOARD. `rows` is `RadarSet.read`'s shape, which is `AirPicture.contacts`' shape -- handed in
## by whatever is drawing, never fetched. See the doc block: this is the rule the station depends on.
##
## `age` is how old the picture is, seconds, as `RadarWatch.age()` answers it. It is used ONLY when `reckoning` is on,
## and then only to advance a contact along the course it itself reported. Passing it always, rather than only when
## reckoning, keeps one call shape and means turning the setting on changes nothing about who knows what.
func show_contacts(rows: Array, age: float = 0.0) -> void:
	# KEPT, SO THE BOARD CAN GO ON RECKONING BETWEEN CALLS. See `_process` -- this is the only thing on the board that
	# is remembered rather than asked for, and it is remembered because the caller speaks four times a second while the
	# screen draws sixty.
	_rows = rows
	_aged = age
	_since_told = 0.0
	_place(rows, age)


## PUT THE ROWS WHERE THE AGE SAYS THEY ARE. Split out of `show_contacts` because `_process` needs it too and neither
## should have its own idea of how a row becomes a piece.
func _place(rows: Array, age: float) -> void:
	if scale_of == null or _pieces == null:
		return
	var shown: int = 0
	reckoned_most_m = 0.0
	for row_any in rows:
		var row := row_any as Dictionary
		if row == null or not (row.get("position") is Vector3):
			continue
		var kind: int = int(row.get("kind", -1))
		if kind < 0:
			continue
		var piece: Node3D = _a_piece(shown)
		_stand(piece, row, kind, age)
		piece.visible = true
		shown += 1
	# THE REST OF THE POOL IS HIDDEN, NOT FREED. See `_pool`.
	for spare in range(shown, _pool.size()):
		_pool[spare].visible = false
	pieces_shown = shown


## WHILE RECKONING, THE BOARD ADVANCES ITS OWN PIECES EVERY FRAME, and the reason is the whole point of the setting.
##
## `ControlStation` redraws four times a second (`ControlStation.EVERY`), which is plenty for a panel of words and is
## **not** plenty for motion: a piece that steps four times a second is still visibly stepping, so reckoning driven off
## the station's beat would buy a quarter of the smoothness and none of the look. The screen draws sixty times a
## second, so the board does the arithmetic sixty times a second.
##
## **WHEN IT IS HOLDING THIS COSTS NOTHING AT ALL** -- it returns on the first line -- which is the right shape: the
## honest default is also the free one, and the expensive path is the one that had to be asked for.
func _process(delta: float) -> void:
	if not reckoning or _rows.is_empty() or scale_of == null:
		return
	_since_told += delta
	_place(_rows, _aged + _since_told)


## WHAT THE Nth PIECE ON THE BOARD IS DOING, for a suite that wants to say where a contact landed without walking the
## scene graph -- and so that "solid against outline" is a thing a check can READ rather than a thing only a photograph
## can see. `{}` past the end of the pool.
##
## `stalk_m` is the piece's height above the drawn ground in WORLD metres, back through the scale, because that is the
## number the board is claiming and it is the one worth holding against the contact's altitude.
func piece_report(index: int) -> Dictionary:
	if index < 0 or index >= _pool.size() or scale_of == null:
		return {}
	var piece: Node3D = _pool[index]
	var plate := piece.get_node("Plate") as MeshInstance3D
	var stalk := piece.get_node("Stalk") as MeshInstance3D
	var mesh: ArrayMesh = plate.mesh as ArrayMesh
	# HOW BIG THE MINIATURE ACTUALLY COMES OUT, board metres, off the mesh's own bounds times the shrink applied to it.
	#
	# **IT USED TO REPORT `plate.scale` AND THAT WAS BACKWARDS ONCE MODELS ARRIVED.** A plate was a unit shape scaled UP
	# to its size, so its scale WAS its size; a miniature is built at life size and scaled DOWN, so a bigger kind has a
	# SMALLER scale. `a_bigger_kind_gets_a_bigger_piece` caught it immediately -- airliner 0.0016 against Cessna 0.0048
	# -- which is the check doing exactly its job, because both numbers look perfectly plausible on their own.
	var drawn: float = 0.0
	if mesh != null and mesh.get_surface_count() > 0:
		var box: AABB = mesh.get_aabb()
		drawn = maxf(box.size.x, box.size.z) * plate.scale.x
	# HOW BRIGHT THE PIECE IS PAINTED, which is the channel `manned` reads in now that the pieces are models and
	# solid-against-outline is gone (see `_pewter`).
	var paint := plate.material_override as StandardMaterial3D
	var tone: float = 0.0 if paint == null else paint.albedo_color.get_luminance()
	return {
		"visible": piece.visible,
		"at": piece.position,
		"world": scale_of.from_board(piece.position),
		"heading": -piece.rotation.y,
		"tone": tone,
		"plate_wide": drawn,
		"stalk": stalk.visible,
		"stalk_m": (stalk.scale.y / scale_of.factor()) if stalk.visible else 0.0,
	}


## HOW MANY PIECES THE POOL HOLDS, shown or hidden. For the check that a contact going off radar HIDES a piece rather
## than leaving it standing there.
func pool_size() -> int:
	return _pool.size()


## ONE PIECE, STOOD WHERE ITS ROW SAYS. Everything positional goes through `scale_of`; the plate's SIZE does not, which
## is the token rule in one line.
func _stand(piece: Node3D, row: Dictionary, kind: int, age: float) -> void:
	var at: Vector3 = row["position"]
	# DEAD RECKONING, and it is the ONLY line in this file that draws a contact anywhere but where the sensor put it.
	# See the doc block. Flat, because a row carries no vertical rate; by age, so it snaps rather than eases.
	if reckoning and age > 0.0:
		var course: float = float(row.get("heading", 0.0))
		var carried: float = float(row.get("speed", 0.0)) * age
		# THE SAME CONVENTION THE HEADING WAS WRITTEN IN: `RadarSet.row_of` makes it with `atan2(nose.x, -nose.z)`, so
		# the nose points along (sin, -cos) and a contact on 000 travels towards -z. Getting this backwards would sail
		# every contact on the board in reverse, which looks deliberate.
		at += Vector3(sin(course), 0.0, -cos(course)) * carried
		reckoned_most_m = maxf(reckoned_most_m, absf(carried))
	var ground_y: float = surface_board_y(at.x, at.z)
	var board: Vector3 = scale_of.to_board(at)
	# A CONTACT BELOW THE DRAWN GROUND IS DRAWN ON IT rather than inside it. It happens honestly: the board samples
	# every 150 m and a boat in a 40 m inlet is under the nearest sample's hilltop. Sinking the piece into the mesh
	# would read as a lost contact, which is the one thing this board must never be able to fake (`world/radar_set.gd`).
	var top: float = maxf(board.y, ground_y)
	piece.position = Vector3(board.x, top + PLATE_LIFT, board.z)
	piece.rotation = Vector3(0.0, -float(row.get("heading", 0.0)), 0.0)

	var manned: bool = bool(row.get("manned", false))
	var plate := piece.get_node("Plate") as MeshInstance3D
	plate.mesh = _miniature_of(kind)
	# THE MODEL IS BUILT IN THE CRAFT'S OWN METRES AND SCALED TO BE READ. That is the token rule unchanged -- position
	# goes through `DioramaScale`, size does not -- and it is why a jumbo and a Cessna are drawn a sensible amount
	# apart rather than 1:12,000 apart, which would be 5.9 mm against 0.9 mm.
	plate.scale = Vector3.ONE * _model_scale(kind)
	plate.material_override = _pewter(manned)

	# THE CALL SIGN, which is the name the row was published with -- worked out once on the host by `RadioPhrases`
	# (`world/radar_set.gd`), so the board, the plot and the radio cannot say three different things about one
	# aeroplane. Shown or hidden by `naming`; nothing here shortens or reformats it.
	var said := piece.get_node("Name") as Label3D
	var numbers := piece.get_node("Numbers") as Label3D
	said.visible = naming
	numbers.visible = naming
	if naming:
		said.text = String(row.get("name", ""))
		said.position = Vector3(0.0, NAME_OVER, 0.0)
		# DIRECTION, SPEED AND ALTITUDE, asked for by the user. **In the words the side panel already uses** -- bearing
		# as three digits, then metres, then metres per second, exactly as `ControlStation._what_is_picked` writes them
		# -- because a controller reading the board and then the panel must not have to convert anything in their head,
		# and two vocabularies for one set of facts is the same fault as two copies of a number (rule 4).
		#
		# THE ALTITUDE IS THE REPORTED ONE AND NOT THE RECKONED ONE. A row carries no vertical rate, so dead reckoning
		# moves a contact across the ground and never up or down; printing anything but the reported height here would
		# be the label claiming a climb nobody measured.
		var reported: Vector3 = row["position"]
		numbers.text = "%03d  %d m  %d m/s" % [
			wrapi(roundi(rad_to_deg(float(row.get("heading", 0.0)))), 0, 360),
			roundi(reported.y), roundi(float(row.get("speed", 0.0)))]
		numbers.position = Vector3(0.0, -DATA_UNDER, 0.0)

	# THE STALK AND ITS DOT, down to the ground under the contact. A ship on the water gets neither: see the doc block.
	var stalk := piece.get_node("Stalk") as MeshInstance3D
	var dot := piece.get_node("Dot") as MeshInstance3D
	var up: float = top - ground_y
	var tall_enough: bool = up > DOT_WIDE
	stalk.visible = tall_enough
	dot.visible = tall_enough
	if tall_enough:
		stalk.scale = Vector3(STALK_WIDE, up, STALK_WIDE)
		stalk.position = Vector3(0.0, -up * 0.5, 0.0)
		stalk.material_override = _tinted(true, row.get("colour", AirPicture.AI))
		dot.scale = Vector3(DOT_WIDE, DOT_WIDE, DOT_WIDE)
		dot.position = Vector3(0.0, -up, 0.0)
		dot.material_override = _tinted(true, row.get("colour", AirPicture.AI))


## HOW BIG A PIECE IS, board metres, from the kind's OWN span through `Sim.geometry_of` -- `extents` are half extents
## ("stood on its own half-height", `world/radar_watch.gd`) -- squeezed into the readable band. Derived, not typed, so
## thirty-nine kinds need no roster here (rule 4).
func _token_radius(kind: int) -> float:
	var extents: Vector3 = Sim.geometry_of(kind).get("extents", Vector3.ONE)
	var span: float = maxf(extents.x, extents.z) * 2.0
	if span <= 0.0:
		return TOKEN_SMALL
	var along: float = clampf((span - SPAN_SMALL) / (SPAN_LARGE - SPAN_SMALL), 0.0, 1.0)
	return lerpf(TOKEN_SMALL, TOKEN_LARGE, along)


## HOW MUCH A KIND'S MINIATURE IS SHRUNK to reach the readable size `_token_radius` picks for it. The model is built at
## life size (`DioramaMiniature.of`), so this is the readable half-length divided by the real one.
func _model_scale(kind: int) -> float:
	var extents: Vector3 = Sim.geometry_of(kind).get("extents", Vector3.ONE)
	# THE FULL LENGTH AND NOT THE HALF. `extents` are half extents, so dividing by `extents.z` drew every miniature at
	# TWICE the size `_token_radius` asks for -- the airliner came out 70 mm on a 1,200 mm board and swamped its
	# neighbours. Caught by reading the size the suite now reports off the drawn mesh rather than by eye.
	var real: float = maxf(extents.z * 2.0, 0.001)
	return _token_radius(kind) / real


## THE MINIATURE FOR A KIND, BUILT ONCE AND SHARED by every contact of that kind on the board. Seventy-five contacts
## are typically seven or eight kinds, so this is seven or eight meshes and not seventy-five -- and a mesh built per
## contact per sweep would be the one genuinely expensive thing this feature could do.
func _miniature_of(kind: int) -> ArrayMesh:
	if _models.has(kind):
		return _models[kind]
	var made: ArrayMesh = DioramaMiniature.of(kind, VehicleCatalogue.group(kind))
	_models[kind] = made
	return made


## THE PAINT ON A MINIATURE. Every radar contact is anonymous grey (`world/radar_set.gd`), so `manned` reads in TONE:
## a crewed contact is pewter-bright and an empty one is darker.
##
## **IT USED TO BE SOLID AGAINST OUTLINE and the models took that channel away**, which is worth saying plainly rather
## than quietly changing. A flat plate could be drawn as a filled shape or as a line loop and the two were unmistakable;
## a little three-dimensional aeroplane drawn as a wireframe is a scribble at 20 mm. `radar_set.gd` offers "solid
## against an outline, OR SIZE" as the channels for `manned`, and size is already spoken for by the kind -- so tone it
## is, and the tally on the panel still says how many of the contacts are crewed.
##
## LIT, NOT UNSHADED, and that is the point of having models at all: the facets are what make a 20 mm shape read as an
## aeroplane, and an unshaded model is a flat grey blob in the outline of one.
func _pewter(manned: bool) -> StandardMaterial3D:
	var key: String = "pewter:%s" % manned
	if _paints.has(key):
		return _paints[key]
	var made := StandardMaterial3D.new()
	made.vertex_color_use_as_albedo = true
	made.vertex_color_is_srgb = true
	made.roughness = 0.62
	made.metallic = 0.15
	# BRIGHT ENOUGH TO READ AGAINST A BLACK SKY. The first pictures had the empty contacts at 0.52, which multiplies the
	# miniature's own 0.62 body grey down to about 0.32 -- against the black behind the high contacts they read as
	# silhouettes rather than as models, which is the whole thing the models were added for. 0.78 keeps a clear
	# separation from a crewed contact's 1.0 while leaving both legible.
	made.albedo_color = Color(1.0, 1.0, 1.0) if manned else Color(0.78, 0.80, 0.84)
	made.cull_mode = BaseMaterial3D.CULL_DISABLED
	_paints[key] = made
	return made


## A PIECE'S MATERIAL, KEPT RATHER THAN MADE. Four updates a second over ninety contacts is 360 materials a second if
## this allocates, which is a steady drip of garbage for a screen that is meant to be the cheap one -- and radar rows
## carry one of a handful of colours, so the cache is a handful of entries and never grows with the traffic.
func _tinted(solid: bool, tint: Color) -> StandardMaterial3D:
	var key: String = "%d:%s" % [1 if solid else 0, tint.to_html(false)]
	if _paints.has(key):
		return _paints[key]
	var made := StandardMaterial3D.new()
	made.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	made.albedo_color = tint if solid else tint.lightened(0.15)
	made.cull_mode = BaseMaterial3D.CULL_DISABLED
	made.vertex_color_use_as_albedo = false
	_paints[key] = made
	return made


## ONE LINE OF THE LABEL. Billboarded so it faces you from wherever you have walked round the table, `no_depth_test` so
## a name is never swallowed by the rock its contact is over, and outlined so it survives against both the pale board
## and the black sky behind the high contacts.
func _a_caption(called: String, points: int, pixels: float, ink: Color) -> Label3D:
	var said := Label3D.new()
	said.name = called
	said.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	said.no_depth_test = true
	said.fixed_size = true
	said.font_size = points
	said.pixel_size = pixels
	said.outline_size = NAME_OUTLINE
	said.modulate = ink
	said.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	return said


func _a_piece(index: int) -> Node3D:
	while _pool.size() <= index:
		var piece := Node3D.new()
		piece.name = "Piece%d" % _pool.size()
		var plate := MeshInstance3D.new()
		plate.name = "Plate"
		piece.add_child(plate)
		var stalk := MeshInstance3D.new()
		stalk.name = "Stalk"
		stalk.mesh = BoxMesh.new()
		piece.add_child(stalk)
		var dot := MeshInstance3D.new()
		dot.name = "Dot"
		var pip := BoxMesh.new()
		pip.size = Vector3(1.0, 0.12, 1.0)
		dot.mesh = pip
		piece.add_child(dot)
		# THE CALL SIGN, BILLBOARDED so it faces you from wherever you have walked round the table. `Label3D` and not a
		# 2D overlay: an overlay would have to unproject every contact every frame and would be a second opinion about
		# where a piece is, where a child node simply IS at the piece.
		piece.add_child(_a_caption("Name", NAME_POINTS, NAME_PIXEL, NAME_INK))
		piece.add_child(_a_caption("Numbers", DATA_POINTS, DATA_PIXEL, DATA_INK))
		_pieces.add_child(piece)
		_pool.append(piece)
	return _pool[index]


## THE BOARD'S MESH, faceted on purpose: flat normals across each triangle, which is the workshop's look
## (`modelling_here.md`) and which makes 50 mm of relief read on a 1.2 m board where smooth shading would wash it out.
func _sculpt() -> ArrayMesh:
	var build := SurfaceTool.new()
	build.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(TEXELS - 1):
		for i in range(TEXELS - 1):
			var a := _corner_at(i, j)
			var b := _corner_at(i + 1, j)
			var c := _corner_at(i + 1, j + 1)
			var d := _corner_at(i, j + 1)
			_triangle(build, a, b, c)
			_triangle(build, a, c, d)
	build.generate_normals()
	var made: ArrayMesh = build.commit()
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.roughness = 0.95
	paint.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	made.surface_set_material(0, paint)
	return made


## ONE GRID SAMPLE AS A PLACE ON THE BOARD AND A COLOUR: `{"at": Vector3, "tint": Color}`. The sample is at the texel's
## CENTRE, as `Terrain.surface_heights` documents.
func _corner_at(i: int, j: int) -> Dictionary:
	var h: float = heights[j * TEXELS + i]
	var x: float = corner.x + (float(i) + 0.5) * spacing
	var z: float = corner.y + (float(j) + 0.5) * spacing
	# PAST THE WORLD'S EDGE the island's sea has no floor and the sampler answers -INF. The board is flat sea there,
	# which is what is actually out there, rather than a wall falling away for ever.
	var flat: bool = h == -INF or h == INF
	var metres: float = Terrain.SEA_LEVEL if flat else h
	var tint: Color = WATER
	if not flat and metres > Terrain.SEA_LEVEL:
		# WATER STANDS HERE when the surface IS the water -- `surface_height` is the max of ground and water, so the two
		# are equal exactly where water is on top. One query a texel, at bake time only, and it gets the lakes right on
		# the generated ground as well as the sea round the island.
		var water: float = Terrain.water_height(Vector3(x, 0.0, z))
		if water != -INF and water >= metres - 0.01:
			tint = WATER
		elif _relief < BANDS_NEED:
			tint = GRASS
		else:
			# THE BANDS AS FRACTIONS OF THIS LEVEL'S OWN RELIEF. See `SHORE_TO`.
			var up: float = (metres - Terrain.SEA_LEVEL) / _relief
			if up < SHORE_TO:
				tint = SHORE
			elif up < GRASS_TO:
				tint = GRASS
			elif up < ROCK_TO:
				tint = ROCK
			else:
				tint = SNOW
	return {"at": scale_of.to_board(Vector3(x, metres, z)), "tint": tint}


func _triangle(build: SurfaceTool, a: Dictionary, b: Dictionary, c: Dictionary) -> void:
	for point in [a, b, c]:
		build.set_color(point["tint"])
		build.add_vertex(point["at"])
