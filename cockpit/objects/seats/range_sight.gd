@tool
extends Node3D
class_name RangeSight
## WHAT A BATTLESHIP'S TURRET GUNNER LOOKS THROUGH: a level crosshair on the turret's bearing, a mil scale to judge a
## target's distance by its size, and a range drum that says where the laid gun's shell comes down -- then when it lands,
## and how far off it landed. Plan item 22, the user's words: "build a sight for them, they can fire and gauge distance".
##
## THE GUNNER GAUGES; THE SIGHT DOES NOT MEASURE. Nothing here knows where a target is. The mil scale lets a gunner read a
## ship's size in milliradians and work its distance out (km = metres / mils); the drum says what range the gun is SET to,
## off `shell_reach` -- the arithmetic every shell is flown by -- so the setting and the shell cannot disagree; and the fall
## of shot, short or over the target, is what brackets it. Fire, watch the splash, correct, fire again.
##
## WHY THE BOARD SAYS HOW FAR THE SPLASH WAS, and why that is not the target's range. SPLASH is the distance of the gunner's
## OWN shell from the trunnion -- a thing the gunner caused and watched land -- never where any target is. Whether it fell
## short of the target or over it is still called by eye against the target, so the distance is still gauged; the number
## only says how far the last correction moved the fall. "Show the target's range" would be a rangefinder, and a different
## feature: if it is ever asked for, it is that feature, not a tweak of this line. The user may overrule keeping SPLASH;
## it is the one `_splash_text` line to drop.
##
## WHY NOT `GunSight`: A RETICLE ON THE BARREL LINE LOSES THE TARGET JUST AS THE GUN IS LAID. Laid for its 6 km the gun
## points 11.6 degrees above the target -- about 9.4 for 5 km -- and the target drops out under the glass at the moment
## it matters. So this sight looks LEVEL along the turret's bearing, and the elevation is set as a range on a drum, as a
## naval sight does: the sight follows the train and ignores the elevation.
##
## WHERE THE GUNNER SITS (plan item 22d): on a hood three metres over its turret's roof, on the training axis, fixed to
## the hull. On the axis, because the bearing the sight looks along then passes through the gun; on a hood, because an eye
## on the roof looked straight along the centre barrel, which rose into the line past 5.97 degrees (3,372 m); fixed to
## the hull, because a headset view turned with the turret is a comfort failure. The seats were the 12.7 mm tubs', where
## the tower hid all of turret 2's starboard arc. tests/turret_seats.gd holds the clearance and the blind arcs.
##
## AT INFINITY, NOT ON A PANE. Glass half a metre from the eye moves against a target six kilometres off as the head moves:
## five centimetres sideways is nearly a hundred mils, and the scale would lie by that much. A real sight is collimated. This
## one is put half a metre in front of wherever the viewing camera is, every drawn frame, facing along the bearing and level
## with the world, so a mark on it is at the same angle from the eye as the far thing behind it -- which is what makes the
## mil scale true, and why it is `top_level`: it is placed in the world, not hung off the seat.

## How far in front of the eye the reticle is drawn. Only a scale: every mark is placed at an ANGLE from the eye.
const AT: float = 0.52
## One milliradian.
const MIL: float = 0.001
## A tick every this many mils, and how many either side of the crosshair: a hundred mils each way, which is a battleship's
## 270 m at 2.7 km and a destroyer's 115 m at 6 km at the ends -- the fights these guns reach.
const TICK_MILS: int = 5
const TICKS: int = 20
## A longer tick every this many ticks, and a number every NUMBER_EVERY. NUMBERED EVERY FIFTY MILS, NOT EVERY TEN: the
## first picture (2026-09-16) numbered every ten, and a two-figure number twenty mils tall is twenty-two mils wide, so
## "10 20 30 40" was drawn as one green smear. At fifty the widest, "100", leaves a clear seventeen mils to the next.
const LONG_EVERY: int = 2
const NUMBER_EVERY: int = 10
## HOW FAR BELOW LEVEL THE SCALE RUNS, mils. The first picture drew it on the level line, and a ship at five kilometres
## sits on the level line -- its waterline three mils under it from a 15 m eye -- so the bar was painted over the hull it
## was there to measure. Ten mils down, with its ticks pointing up at the target, it measures a hull it does not cover.
const SCALE_DROP_MILS: float = 10.0
## HOW THICK A LINE IS DRAWN, as an angle: 1.5 mrad, which is 1.7 headset pixels at twenty a degree -- under two, so a
## headset shows it as a line and not a smudge, and over one, so it does not break up between pixels.
const LINE_MILS: float = 1.5
## HOW TALL THE SMALLEST WRITING IS, as an angle: 20 mrad is 22.9 headset pixels, over the 20 the menus hold themselves to.
const WORD_MILS: float = 20.0
## How tall a line of writing is, as a share of its size, as the default font sets it: measured off a Label3D's box.
const LINE_HEIGHT: float = 1.4
## HOW FAR THE BEARING MAY BE FROM WHERE THE EYE LOOKS before the TRAIN arrow shows, degrees. Plan item 22d: the seat is
## fixed to the hull and the gunner turns their head to the gun, so a gunner looking away needs telling which way it is.
const TRAIN_SHOWN_DEG: float = 30.0
## How far under the middle of the view the arrow is written, mils: below where a target would be looked at.
const TRAIN_BELOW_MILS: float = 80.0
## How long a splash's reading is kept after it lands, seconds.
const SPLASH_KEPT_S: float = 10.0

const GREEN := Color(0.45, 0.95, 0.55, 0.9)

## Which mount this sight lays, and the gun on it: the simulation's schema, handed in by the station.
var mount: int = 0
var gun: Dictionary = {}

var _paint: StandardMaterial3D = null
var _marks: Node3D = null
var _crosshair: MeshInstance3D = null
var _board: Label3D = null
var _numbers: Array[Label3D] = []
var _train: Label3D = null
## The board's drum lines, written every drawn frame, and its shell line, written on the state pass.
var _drum_lines: PackedStringArray = []
var _shell_line: String = ""
## Shells this gunner fired from this mount that the sight has seen, by entity: {"seen_ms", "flight_s"}.
var _flying: Dictionary = {}
var _splash_text: String = ""
var _splash_until_ms: int = 0


func _ready() -> void:
	top_level = true
	_paint = StandardMaterial3D.new()
	_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_paint.albedo_color = GREEN
	_paint.no_depth_test = true
	_marks = Node3D.new()
	_marks.name = "Marks"
	add_child(_marks)
	var line: float = _across(LINE_MILS)
	var low: float = -_across(SCALE_DROP_MILS)
	# THE SCALE'S BAR, level with the world, the width of the scale and a little more.
	_bar(Vector3(0.0, low, 0.0), Vector3(_across(float(TICKS * TICK_MILS) + 6.0) * 2.0, line, 0.001))
	# THE CROSSHAIR: the bearing the turret is trained on, a vertical line with a gap where the target sits -- above down
	# to four mils over level, below down to the bar.
	var arm: float = _across(12.0)
	_crosshair = _bar(Vector3(0.0, _across(4.0) + arm * 0.5, 0.0), Vector3(line, arm, 0.001))
	var under: float = _across(SCALE_DROP_MILS - 4.0)
	_bar(Vector3(0.0, -_across(4.0) - under * 0.5, 0.0), Vector3(line, under, 0.001))
	# THE MIL SCALE: a tick every TICK_MILS either side of the crosshair, each at its own ANGLE from the eye along the bar
	# -- which is ten mils below the eye's level, so the distance to it is a hair more than AT -- pointing up at the target.
	var along: float = Vector2(AT, low).length()
	for k in range(1, TICKS + 1):
		for side in [-1.0, 1.0]:
			var x: float = side * along * tan(float(k * TICK_MILS) * MIL)
			var tall: float = _across(5.0 if k % NUMBER_EVERY == 0 else (3.5 if k % LONG_EVERY == 0 else 2.0))
			var tick := _bar(Vector3(x, low + tall * 0.5, 0.0), Vector3(line, tall, 0.001))
			tick.name = "Tick%s%d" % ["L" if side < 0.0 else "R", k * TICK_MILS]
			if k % NUMBER_EVERY == 0:
				var number := _words("%d" % (k * TICK_MILS), Vector3(x, low - _across(2.0), 0.0))
				number.vertical_alignment = VERTICAL_ALIGNMENT_TOP
				number.name = "Mils%s%d" % ["L" if side < 0.0 else "R", k * TICK_MILS]
				_numbers.append(number)
	# THE BOARD, under the numbers: the rule for the scale, the drum, and the fall of shot. A line of writing is LINE_HEIGHT
	# of its size tall, not its size -- the font's ascent and descent -- and the first board, put one size under the
	# numbers, was written over them.
	_board = _words("", Vector3(0.0, low - _across(6.0 + WORD_MILS * LINE_HEIGHT), 0.0))
	# THE TRAIN ARROW: its own place in the world, in front of wherever the eye looks, so it is not on this glass -- which
	# is along the bearing, and off the view when the arrow is wanted.
	_train = _words("", Vector3.ZERO)
	_train.name = "Train"
	_train.top_level = true
	_train.visible = false
	_board.name = "Board"
	_board.vertical_alignment = VERTICAL_ALIGNMENT_TOP


## A length on the reticle that subtends `mils` from the eye.
static func _across(mils: float) -> float:
	return AT * tan(mils * MIL)


func _bar(at: Vector3, size: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.position = at
	node.material_override = _paint
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marks.add_child(node)
	return node


func _words(text: String, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	# SIZED AS AN ANGLE: a font_size-tall line subtends WORD_MILS from the eye.
	label.pixel_size = _across(WORD_MILS) / 48.0
	label.modulate = GREEN
	label.outline_size = 0
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.position = at
	add_child(label)
	return label


## ONE DRAWN FRAME: put the reticle half a metre in front of `eye`, level, along where the turret on `craft` is trained.
## `aim` is the mount's two angles as the wire carries them, in the craft's frame.
## `looking` is where the viewing camera faces, for the TRAIN arrow; ZERO leaves the arrow hidden.
func follow(eye: Vector3, craft: Transform3D, aim: Vector2, looking: Vector3 = Vector3.ZERO) -> void:
	var bearing: Vector3 = bearing_of(craft, aim)
	if bearing == Vector3.ZERO:
		return
	global_transform = Transform3D(Basis.looking_at(bearing, Vector3.UP), eye + bearing * AT)
	_point_the_train(eye, bearing, looking)


## TRAIN < OR TRAIN >, the shorter way from where the eye looks to the bearing, when that is more than TRAIN_SHOWN_DEG.
func _point_the_train(eye: Vector3, bearing: Vector3, looking: Vector3) -> void:
	if _train == null:
		return
	var level := Vector3(looking.x, 0.0, looking.z)
	if level.length_squared() < 0.000001:
		_train.visible = false
		_train.text = ""
		return
	level = level.normalized()
	# POSITIVE WHEN THE BEARING IS TO THE LEFT of the view: a turn about UP from the view to the bearing, counter-clockwise
	# seen from above.
	var off: float = level.signed_angle_to(bearing, Vector3.UP)
	var shown: bool = absf(off) > deg_to_rad(TRAIN_SHOWN_DEG)
	_train.visible = shown
	_train.text = ("TRAIN <" if off > 0.0 else "TRAIN >") if shown else ""
	if shown:
		var ahead: Vector3 = level * AT
		_train.global_transform = Transform3D(Basis.looking_at(level, Vector3.UP),
			eye + ahead + Vector3.DOWN * _across(TRAIN_BELOW_MILS))


## What the TRAIN arrow says, "" while it is hidden, and where it is, for the tests.
func train_says() -> String:
	return _train.text if _train != null and _train.visible else ""


func train_at() -> Vector3:
	return _train.global_position if _train != null else Vector3.INF


## HOW FAR ABOVE THE WORLD'S HORIZONTAL a mount laid at `aim` on `craft` points, radians: the elevation a shell leaves at.
static func world_elevation(craft: Transform3D, aim: Vector2) -> float:
	var barrel: Vector3 = craft.basis * Vector3(-sin(aim.x) * cos(aim.y), sin(aim.y), -cos(aim.x) * cos(aim.y))
	return asin(clampf(barrel.normalized().y, -1.0, 1.0)) if barrel.length_squared() > 0.000001 else aim.y


## WHERE A MOUNT LAID AT `aim` ON `craft` IS TRAINED, as a level unit direction in the world; ZERO for a craft on its end.
static func bearing_of(craft: Transform3D, aim: Vector2) -> Vector3:
	var bearing: Vector3 = craft.basis * Vector3(-sin(aim.x), 0.0, -cos(aim.x))
	bearing.y = 0.0
	if bearing.length_squared() < 0.000001:
		return Vector3.ZERO
	return bearing.normalized()


## THE STATE PASS: what the drum reads for the laid elevation, and this gunner's shells from this mount -- a countdown while
## one flies, and where it landed once it has. `shots` is `Sim.shots`, `me` this machine's client, `trunnion` where the
## mount is in the world now, `kind` the craft's kind.
## THE DRUM, EVERY DRAWN FRAME: the range and time of flight for the mount laid at `aim` on `craft`, a craft of `kind`.
##
## THE BARREL AS IT POINTS IN THE WORLD (plan item 22e): the shell is flown from there, and the hull under the gun rolls.
## Read at the elevation against the ship, the drum said 2,181 m on either beam while the shell landed 2,361 m off on the
## starboard beam and 2,093 m on the port, with the hull tilting the barrel +0.375 and -0.183 degrees. The gun is not
## stabilised -- whether it should be is the user's question -- so the drum moves as the ship rolls, because that is where
## the gun is pointing.
##
## EVERY DRAWN FRAME, NOT ON THE STATE PASS: the state pass is five a second, and the drum it wrote was up to 200 ms behind
## a barrel the hull rolls at up to 0.3 degrees a second. Measured on 2026-09-16: a drum worked out 59 ms before it was
## read stood at 3.7833 degrees against the barrel's 3.7606 -- 11 m at 2.3 km, up to 70 m at 6 km. The writing is only
## rebuilt when what it says changes.
func show_drum(aim: Vector2, kind: int, craft: Transform3D) -> void:
	var reach: Dictionary = Sim.shell_reach(kind, mount, world_elevation(craft, aim))
	_drum_lines = PackedStringArray([
		"RANGE %s m   %.1f s" % [_thousands(int(round(float(reach.get("range", 0.0))))), float(reach.get("seconds", 0.0))],
		"ELEV %.2f deg" % rad_to_deg(aim.y)])
	_write_board()


func _write_board() -> void:
	if _board == null:
		return
	var lines: PackedStringArray = ["km = metres / mils"]
	lines.append_array(_drum_lines)
	if _shell_line != "":
		lines.append(_shell_line)
	var text: String = "\n".join(lines)
	if _board.text != text:
		_board.text = text


## THE STATE PASS, five a second: this gunner's shells from this mount -- a countdown while one flies, and where it landed
## once it has. `shots` is `Sim.shots`, `me` this machine's client, `trunnion` where the mount is in the world now.
func show_laying(shots: Array, me: int, trunnion: Vector3) -> void:
	if _board == null:
		return
	var now: int = Time.get_ticks_msec()
	var soonest: float = INF
	var still: Dictionary = {}
	for row in shots:
		var shot: Dictionary = row
		if int(shot.get("shooter", -1)) != me or int(shot.get("mount", -1)) != mount:
			continue
		var entity: int = int(shot["entity"])
		if bool(shot.get("flying", false)):
			if not _flying.has(entity):
				_flying[entity] = {"seen_ms": now, "flight_s": _flight_seconds(shot)}
			still[entity] = _flying[entity]
			var left: float = float(_flying[entity]["flight_s"]) - float(now - int(_flying[entity]["seen_ms"])) / 1000.0
			soonest = minf(soonest, maxf(left, 0.0))
		elif _flying.has(entity):
			var impact: Vector3 = shot["impact"] as Vector3
			_splash_text = "SPLASH %s m" % _thousands(int(round(Vector2(impact.x - trunnion.x, impact.z - trunnion.z).length())))
			_splash_until_ms = now + int(SPLASH_KEPT_S * 1000.0)
	_flying = still
	if soonest < INF:
		_shell_line = "SHELL  LANDS IN %d s" % int(ceil(soonest))
	elif now < _splash_until_ms:
		_shell_line = _splash_text
	else:
		_shell_line = ""
	_write_board()


## How long a shell takes to come down through the height it was fired from, flown by the renderer's own steps from its
## birth record: once per shell, when it is first seen.
static func _flight_seconds(shot: Dictionary) -> float:
	var round_now: Dictionary = {"at": shot["from"], "velocity": shot["velocity"], "drag": float(shot.get("drag", 0.0)),
		"age": 0.0, "clock": 0.0}
	var start: float = (shot["from"] as Vector3).y
	var ticks: int = 0
	while ((round_now["at"] as Vector3).y > 0.0 or ticks < 10) and ticks < 120 * 60:
		ShotYard._step(round_now, 1.0 / 120.0)
		ticks += 1
	return float(ticks) / 120.0 if start > 0.0 else 0.0


static func _thousands(value: int) -> String:
	var text: String = str(absi(value))
	var out: String = ""
	while text.length() > 3:
		out = "," + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)
	return ("-" if value < 0 else "") + text + out


## What the board says, for the tests.
func says() -> String:
	return _board.text if _board != null else ""


## Where tick `mils` meets the bar in the world (`mils` negative for the left), for the tests. INF for a tick that is not
## drawn. Its angle from `scale_centre` at the eye is what the scale says.
func tick_at(mils: int) -> Vector3:
	var node := _marks.get_node_or_null("Tick%s%d" % ["L" if mils < 0 else "R", absi(mils)]) as Node3D if _marks else null
	return node.global_position - global_basis.y * (node.mesh as BoxMesh).size.y * 0.5 if node != null else Vector3.INF


## The crosshair's centre in the world -- level with the eye, along the bearing -- for the tests.
func centre() -> Vector3:
	return global_position


## Where the crosshair's line meets the scale's bar in the world, for the tests: every tick is measured from here.
func scale_centre() -> Vector3:
	return global_transform * Vector3(0.0, -_across(SCALE_DROP_MILS), 0.0)
