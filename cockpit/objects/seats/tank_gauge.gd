@tool
extends Node3D
class_name TankGauge
## HOW MUCH WATER IS LEFT, on the panel of a water bomber, in front of BOTH pilots.
##
## The user asked for this by name: "make sure there is a gauge of the tank full level in
## the cockpit and visible to the pilot and copilot". A water bomber is flown as a series of
## round trips -- fill, transit, drop, transit -- and the only number that says which leg of
## that trip you are on is this one. It was readable before only as a text row on the flight
## display, `FlightPage`'s `TANK` line, which is one of nineteen rows of small green writing
## and is the wrong instrument for a number a pilot reads at fifty feet with both hands full.
##
## ---------------------------------------------------------------------------------
## A BAR AND NOT A DIAL, AND THAT IS THE WHOLE DESIGN
## ---------------------------------------------------------------------------------
##
## A quantity that runs from empty to full and back is read as a LENGTH. A needle has to be
## found, its sweep learnt and its zero remembered; a bar that shortens is the water going,
## drawn as the thing it is. At a glance, out of the corner of an eye that is flying the
## aeroplane, the bar says "about a third" before it has been looked at, and the numerals
## beside it say 34 when there is a second to spare.
##
## AND IT IS NOT A CONTROL. There is nothing here to press, and that is deliberate rather
## than incidental. `fit.gd` refuses any two controls closer than 0.32 m, and a touchable
## part fitted onto both seats of a two-crew flight deck has to be checked against the
## 0.16 m hand target of its own mirror image -- that measurement moved the map screen from
## x 0.40 to 0.38. A gauge that announces and does nothing has no grip, so it can be put
## where it can be READ rather than where a hand will not collide, which is the right
## constraint for an instrument.
##
## ANNOUNCE, DON'T ACT. It is handed the craft state `VehicleView` publishes and draws it.
## It asks the simulation nothing, holds no tank level of its own and cannot disagree with
## the aeroplane: the authority decides and everyone else displays. See `show_state`.
##
## ---------------------------------------------------------------------------------
## AND A GAUGE WITH NOTHING TO SAY SAYS NOTHING
## ---------------------------------------------------------------------------------
##
## `VehicleView` leaves `tank` out of the state of a craft that has no tank rather than
## publishing zero, for the reason written beside it there: a gauge reading EMPTY on a craft
## that carries no water is a gauge saying something false. This honours that -- no bar and
## a dashed reading -- instead of drawing an empty tank. It should never be seen, because
## the station only fits a gauge to a craft whose bus carries the tank doors, and that is
## exactly why it is here: the day that gate is wrong, the instrument should be obviously
## blank rather than quietly lying.

## WIDE AND SHORT, because the panel space under the flight display is wide and short and
## because the length being read runs across it. 0.24 m at the 0.50 m the panel is read from
## is 27 degrees of arc -- a bar whose ends are both inside one glance.
const WIDTH: float = 0.24
## TALL ENOUGH THAT THE NUMERALS CLEAR THE TICKS, which is a measurement and not a guess:
## at 0.070 the first cockpit picture had the F tick drawn through the L of FILL.
const HEIGHT: float = 0.078
## As thick as the crew board beside it, which is what a panel instrument is here.
const DEPTH: float = 0.012
## The border of dark bezel round the track, in metres. Enough that the lit bar is read as
## sitting IN something rather than as a floating rectangle.
const MARGIN: float = 0.012
## How tall the moving bar is. The rest of the face is the numerals.
const BAR_HEIGHT: float = 0.026

## BELOW THIS THE GAUGE IS AMBER: a tenth of a tank, which is half a second of open doors.
##
## ONE NUMBER, ONE PLACE. `FlightPage` warns on the same figure and reads it from here, so
## the bar and the text row cannot start disagreeing about what "nearly empty" is.
##
## A TENTH AND NOT A FIFTH, and the reason is the round trip rather than the tank: what is
## left below this cannot put a fire out (`kDousePerDrop` against a fire's strength), so it
## is not a reserve to spend, it is the cue to turn for the water.
const LOW: float = 0.10

## The face, and the recess the bar runs in.
const FACE := Color(0.05, 0.06, 0.07)
const TRACK := Color(0.10, 0.11, 0.13)
## WATER, and it is blue because everything else on this panel is green writing. The one
## coloured thing in a cockpit is found without being looked for -- the same argument that
## makes the drop handle the only red thing in it.
const WATER := Color(0.25, 0.62, 0.92)
const AMBER := Color(0.95, 0.72, 0.22)
const GREEN := Color(0.45, 0.90, 0.55)
const WRITING := Color(0.60, 0.85, 0.62)

var _bar: MeshInstance3D = null
var _paint: StandardMaterial3D = null
var _reading: Label3D = null
var _telltale: Label3D = null
## What was last drawn, so a gauge fed at the state rate does not touch a material or a
## label's text sixty times a second for a number that has not moved.
var _drawn: float = -1.0
var _said: String = ""


func _ready() -> void:
	_face()
	_track()
	_ticks()
	_bar = _slab(Vector3(WIDTH - MARGIN * 2.0, BAR_HEIGHT, DEPTH * 0.25), WATER,
		# PROUD OF THE TRACK BY MORE THAN THE TRACK IS THICK. At 0.0015 the bar's front face
		# landed exactly on the track's and the first picture of it was dithered along its
		# whole length, which is z-fighting and reads as a broken instrument.
		Vector3(0.0, _bar_middle(), DEPTH * 0.5 + 0.005))
	_bar.name = "Bar"
	_paint = _bar.material_override as StandardMaterial3D
	# THE BAR GROWS FROM ITS LEFT EDGE, so the mesh is built full width and the NODE is
	# scaled. A mesh rebuilt every time the level moved would allocate a surface per tick of
	# a five-second drop; a scaled node is a transform.
	_reading = _write(HORIZONTAL_ALIGNMENT_LEFT, -WIDTH * 0.5 + MARGIN)
	_reading.name = "Reading"
	_telltale = _write(HORIZONTAL_ALIGNMENT_RIGHT, WIDTH * 0.5 - MARGIN)
	_telltale.name = "Telltale"
	# AND IT STARTS SAYING NOTHING, not saying EMPTY. A gauge that has not been told
	# anything yet and a gauge on an aeroplane with a dry tank are two different facts, and
	# the first cockpit picture of this one read '0%' in warning amber before the craft had
	# spoken to it once -- which is the instrument lying about the only thing it is for.
	_drawn = 0.0
	_nothing_to_say()


## WHAT THE CRAFT SAYS ABOUT ITS TANK. The same dictionary every screen aboard is handed, so
## the pilot's gauge, the copilot's gauge and the flight display cannot disagree: they are
## three drawings of one number. See `VehicleView.craft_state`, which publishes `tank`,
## `scooping` and `dropping` together and leaves all three out of a craft with no tank.
func show_state(state: Dictionary) -> void:
	if not state.has("tank"):
		_nothing_to_say()
		return
	_draw(clampf(float(state["tank"]), 0.0, 1.0), bool(state.get("scooping", false)),
		bool(state.get("dropping", false)))


## How full this gauge is drawing the tank, 0 to 1, or -1 when it has been told there is no
## tank. Read by the suite so a check asks the DRAWING rather than asking the state it was
## handed, which would be a tautology.
func showing() -> float:
	return _drawn


## The word under the pilot's eye: FILL while the scoop is down and filling, DROP while the
## doors are open, and nothing at all the rest of the time.
func word() -> String:
	return _said


## WHAT COLOUR THE READING IS DRAWN IN, off the label rather than off the level, so a check
## asks the drawing whether it is warning rather than asking the arithmetic it was built from.
func reading_colour() -> Color:
	return _reading.modulate if _reading != null else Color.BLACK


## HOW LONG THE BAR IS, in metres, measured off the node that draws it. The one honest
## answer to "is this gauge showing what it was told", because it is read off the scene
## rather than off the number that was passed in.
func bar_length() -> float:
	return (WIDTH - MARGIN * 2.0) * (_bar.scale.x if _bar != null else 0.0)


func _draw(level: float, scooping: bool, dropping: bool) -> void:
	var says: String = "FILL" if scooping else ("DROP" if dropping else "")
	if is_equal_approx(level, _drawn) and says == _said:
		return
	_drawn = level
	_said = says
	var inner: float = WIDTH - MARGIN * 2.0
	# Scaled from the middle, so the node is walked back by half of what it lost: the left
	# edge of the bar stays on the left edge of the track and the right edge is the level.
	_bar.scale.x = maxf(level, 0.0001)
	_bar.position.x = -inner * 0.5 + inner * level * 0.5
	_bar.visible = level > 0.0
	# LOW IS AMBER WHATEVER ELSE IS HAPPENING, because the one thing that must not be
	# hidden by a tell-tale is that there is nothing left to drop.
	_paint.albedo_color = AMBER if level < LOW else WATER
	_paint.emission = _paint.albedo_color
	_reading.text = "%d%%" % int(round(level * 100.0))
	_reading.modulate = AMBER if level < LOW else WRITING
	_telltale.text = says
	_telltale.modulate = GREEN if scooping else AMBER


func _nothing_to_say() -> void:
	if _drawn < 0.0:
		return
	_drawn = -1.0
	_said = ""
	_bar.visible = false
	_reading.text = "---"
	_reading.modulate = WRITING
	_telltale.text = ""


## ---- the face -----------------------------------------------------------------------

func _face() -> void:
	_slab(Vector3(WIDTH, HEIGHT, DEPTH), FACE, Vector3.ZERO).name = "Face"


func _track() -> void:
	_slab(Vector3(WIDTH - MARGIN * 2.0, BAR_HEIGHT, DEPTH * 0.5), TRACK,
		Vector3(0.0, _bar_middle(), DEPTH * 0.5)).name = "Track"


## E, HALF AND F, as three bars standing on the track rather than as writing. Three marks a
## pilot reads by where the water ends, which is the point of a bar; letters that small at
## half a metre are a smudge, and `RangeSight` paid for that lesson on its mil scale.
func _ticks() -> void:
	var inner: float = WIDTH - MARGIN * 2.0
	for share in [0.0, 0.5, 1.0]:
		var tall: float = 0.006 if share == 0.5 else 0.009
		var tick := _slab(Vector3(0.004, tall, DEPTH * 0.25), WRITING,
			Vector3(-inner * 0.5 + inner * share, _bar_middle() + BAR_HEIGHT * 0.5 + tall * 0.5,
				DEPTH * 0.5))
		tick.name = "Tick%d" % int(share * 100.0)


## The middle of the bar's track: the lower half of the face, with the numerals over it.
func _bar_middle() -> float:
	return -HEIGHT * 0.5 + MARGIN * 0.5 + BAR_HEIGHT * 0.5


func _slab(size: Vector3, tint: Color, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	var paint := StandardMaterial3D.new()
	paint.albedo_color = tint
	paint.roughness = 0.85
	# LIT BY ITSELF. A cockpit at dusk over a fire is dark, and a quantity gauge that goes
	# out with the daylight is the instrument you needed most gone when you needed it.
	paint.emission_enabled = true
	paint.emission = tint
	paint.emission_energy_multiplier = 0.55
	node.material_override = paint
	node.position = at
	add_child(node)
	return node


func _write(align: int, at_x: float) -> Label3D:
	var text := Label3D.new()
	# 0.022 m tall, which is 25 headset pixels at twenty a degree from half a metre: over
	# the 20 the menus hold themselves to, and it is read in one glance rather than studied.
	text.font_size = 32
	text.pixel_size = 0.0007
	text.modulate = WRITING
	text.outline_size = 0
	text.horizontal_alignment = align
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	text.position = Vector3(at_x, HEIGHT * 0.5 - MARGIN - 0.006, DEPTH * 0.5 + 0.002)
	add_child(text)
	return text
