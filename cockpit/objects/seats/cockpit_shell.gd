@tool
extends Node3D
class_name CockpitShell
## THE STRUCTURE ROUND ONE CREW POSITION: a floor to stand on and a bar across the front to
## say where the station ends. Two pieces, and that is the whole of it.
##
## IT USED TO BE ELEVEN -- a console slab under the hands, a coaming along the front of it, a
## rail at each elbow, four corner posts and two hoops over the top -- all of it the same size
## on every machine in the game. Asked for on 2026-09-17: "right now it has a table and
## scaffold, let's remove that, it should still have a floor, and perhaps a 'front firewall
## bar' so that the player knows where the limit is, but let's make the stations have less
## scaffolding so that building cockpits is a little more free."
##
## AND THE SCAFFOLD WAS IN THE WRONG AEROPLANE AS WELL AS IN THE WAY. Nothing in this project
## had ever measured a station against the aircraft drawn round it, so nothing had noticed: on
## the F/A-18 the four posts and both hoops stood 0.22 m above the drawn canopy and 0.18 m
## outside it, and on the E-2D, the UH-60 and the Chinook the rails stood out through the
## cabin sides -- 127 pieces of station structure drawn outside their own machine across 35
## crew positions. `tests/shell_room.gd` is the check that had been missing.
##
## `width` AND `depth` ARE THE STATION'S ROOM AND NOT THE FLOOR'S SIZE, and that distinction
## is the whole of this file's design. `BuilderAuthority.validate_layout` builds the box a
## player may put a control in out of these two numbers, so they are how FREE building is, and
## shrinking them to fit the drawn floor is the exact opposite of what was asked for. It was
## tried: `builder_peers` went red on "MapScreen is outside this station's build box", which
## is a player being told they may no longer put a screen where one already was. They are
## unchanged, and the floor got its own size instead.
##
## WHAT IS DRAWN, AND WHY EACH OF THE TWO IS THERE.
##
## THE FLOOR, because it is the one thing that has to be solid. `VehicleView._show_body`
## ghosts the airframe for whoever is sitting inside it, so a station with no floor leaves its
## occupant standing on a see-through single-sided fuselage, looking at the ground through
## their own aircraft. It is a footwell under the feet rather than a raft across the cabin:
## 0.60 x 0.76 m, where it used to be the room's full 1.05 x 1.10, which fits inside the
## aeroplanes and also ends the 0.51 m two side-by-side stations used to overlap at the
## centreline.
##
## THE FIREWALL BAR, because the player needs to see where the limit is -- and the limit is
## not a matter of taste. It stands at the furthest forward a SEATED HAND REACHES, which is
## `CockpitStation.EASY_REACH` and is the bar `tests/fit.gd` holds every control in the game
## to: `front()` works out where that lands at hand height and nothing is typed beside it.
## Move EASY_REACH and the bar moves with it.
##
## THE OTHER CANDIDATE WAS THE BUILD BOX'S OWN FRONT FACE, and measuring it is what ruled it
## out. `BuilderAuthority` refuses a control forward of `-depth`, so a bar there would draw
## the refusal exactly -- but at -0.92 m that face is OUTSIDE THE AEROPLANE on nine of the
## thirty-five enclosed stations (`shell_room`: the Chinook's, the E-2D's and the UH-60's
## cabins, the F/A-18's canopy, and the AC-130's gunners by 2.12 m). That is a finding about
## the build box rather than about the bar -- the builder currently lets a player put a
## control outside the machine -- and it is written down here rather than drawn, because a
## marker you can see through the fuselage is not a marker.
##
## NOTHING ELSE, and that is the point. Everything above the bar is view band, all the way
## round.

## THE STATION'S ROOM, in metres: how wide and how deep a crew position is, which is what
## `BuilderAuthority.validate_layout` allows a control to be placed within. NOT the size of
## anything drawn -- see the doc block.
@export var width: float = 1.05
@export var depth: float = 0.92
@export var tint: Color = Color(0.14, 0.15, 0.17)
## A CRAFT WHOSE CABIN CANNOT HOLD THE STANDARD FOOTWELL, and says so in its `VehicleCatalogue` entry's "footwell"
## ({"raise", "floor_width", "bar_width"}): how far to lift the floor over the anchor's, and how wide to draw the floor
## and the bar. THEY EXIST FOR THE MH-6M LITTLE BIRD (2026-09-18): its egg is 0.28 to 0.35 m wide each side at the
## default footwell's height, so a 0.60 m floor under a pilot sat 0.30 m out stood 0.30 m outside the belly under
## each open door. Lifted to the doors' sills and narrowed, it is inside. Every other craft names none and is drawn
## exactly as before; `CraftPackage.validate_station` refuses values outside the limits below.
@export var footwell_raise: float = 0.0
## A RECLINED CREW, declared by the craft's "footwell" ({"reclined": true}): the occupant LIES BACK in the real aeroplane
## where the game's body sits upright, so the seat anchor -- the play-space floor, `CockpitStation.EYE_HEIGHT` under an
## eye that must be under the glass -- stands below the belly, and the floor the pilot's feet and seat are on is lifted
## to the pod's floor by far more than an upright cockpit ever needs. THE DUO DISCUS (2026-09-19): its crown is 0.90 m
## over the belly at the front seat, so an eye 0.25 m under the glass has its anchor 0.60 m under the belly. What this
## changes: the raise may go to `RECLINED_RAISE_MOST`, and `tests/shell_room.gd` asks that the FLOOR be inside the
## machine rather than the anchor, since the floor is what the occupant sits on.
@export var reclined: bool = false
@export var floor_width: float = FLOOR_WIDTH
@export var bar_width: float = BAR_WIDTH
## THE LIMITS on those three: a floor lifted no more than 0.40 m (past that it is a step, not a floor), and floor and
## bar no narrower than 0.20 m (a hand's width, below which the bar stops marking anything) and no wider than today's.
const FOOTWELL_RAISE_MOST: float = 0.40
## AND FOR A RECLINED CREW, how high the floor may be lifted: the Duo Discus's front seat needs 0.70 (see `reclined`).
const RECLINED_RAISE_MOST: float = 0.75
const FOOTWELL_WIDTH_LEAST: float = 0.20

## THE DRAWN FLOOR, which is a footwell and not the room. Sized to fit inside the aircraft the
## game actually draws: at 1.05 x 1.10 it stood outside the Chinook's, the E-2D's and the
## UH-60's cabins and overlapped its neighbour's by 0.51 m on anything with two seats abreast.
const FLOOR_WIDTH: float = 0.60
const FLOOR_DEPTH: float = 0.76
## How thick the bar is, square in section: a bar you can see over a shoulder, not a wall.
const BAR: float = 0.06
## AND HOW WIDE. Wider than the footwell, so its ends stand clear of the flight display that
## sits 0.19 m behind it; narrower than the station's room, because at the room's full 1.05 m
## the bar stands out through the E-2D's and the UH-60's cabin sides, four corners each
## (`shell_room`). 0.70 m is what the narrowest cabin the game draws round a station allows.
const BAR_WIDTH: float = 0.70
## AND IT IS THE ONE THING IN A STATION THAT IS NOT THE FURNITURE'S GREY. A limit you cannot
## see is not a limit, and at `tint` the bar was invisible against the dark display behind it
## in every aeroplane -- looked at on 2026-09-17 with `tests/station_shot.tscn`, which is the
## only way that class of fault is ever caught. Amber, because that is what a line you are
## not meant to cross looks like everywhere else.
const BAR_TINT := Color(0.46, 0.34, 0.13)


## HOW FAR FORWARD A SEATED HAND REACHES, in metres, as a negative z in the seat anchor's
## frame. `CockpitStation.EASY_REACH` is measured from the nearer shoulder, so the frontmost
## easily-reachable point at hand height is the one directly ahead of a shoulder, a hand's
## drop below it -- and the bar spans the middle of the station, so that is its nearest point
## to a shoulder. -0.569 m with today's constants.
static func front() -> float:
	var drop: float = (CockpitStation.EYE_HEIGHT - CockpitStation.NECK) - CockpitStation.hands()
	var square: float = CockpitStation.EASY_REACH * CockpitStation.EASY_REACH - drop * drop
	return -sqrt(maxf(square, 0.01))


## WHETHER A FOOTWELL OVERRIDE IS SANE, as `CraftPackage.validate_station` and `fit_footwell` both ask: "" or why not.
static func footwell_refused(raise: float, floor_wide: float, bar_wide: float, lying: bool = false) -> String:
	var most: float = RECLINED_RAISE_MOST if lying else FOOTWELL_RAISE_MOST
	if is_nan(raise) or raise < 0.0 or raise > most:
		return "footwell raise %.3f is outside 0 to %.2f m" % [raise, most]
	if is_nan(floor_wide) or floor_wide < FOOTWELL_WIDTH_LEAST or floor_wide > FLOOR_WIDTH:
		return "footwell floor width %.3f is outside %.2f to %.2f m" % [floor_wide, FOOTWELL_WIDTH_LEAST, FLOOR_WIDTH]
	if is_nan(bar_wide) or bar_wide < FOOTWELL_WIDTH_LEAST or bar_wide > BAR_WIDTH:
		return "footwell bar width %.3f is outside %.2f to %.2f m" % [bar_wide, FOOTWELL_WIDTH_LEAST, BAR_WIDTH]
	return ""


## A CRAFT'S OWN FOOTWELL, from its catalogue entry's "footwell", after the station is fitted: set, and the two pieces
## drawn again if they were already drawn. A refused override leaves the standard footwell and says why.
func fit_footwell(over: Dictionary) -> void:
	if over.is_empty():
		return
	var raise: float = float(over.get("raise", 0.0))
	var floor_wide: float = float(over.get("floor_width", FLOOR_WIDTH))
	var bar_wide: float = float(over.get("bar_width", BAR_WIDTH))
	var lying: bool = bool(over.get("reclined", false))
	var why: String = footwell_refused(raise, floor_wide, bar_wide, lying)
	if not why.is_empty():
		push_warning("CockpitShell: %s; the standard footwell is drawn" % why)
		return
	footwell_raise = raise
	reclined = lying
	floor_width = floor_wide
	bar_width = bar_wide
	for piece in ["Floor", "FirewallBar"]:
		var old := get_node_or_null(piece)
		if old != null:
			remove_child(old)
			old.free()
	if is_inside_tree():
		_draw_the_footwell()


func _ready() -> void:
	_draw_the_footwell()


func _draw_the_footwell() -> void:
	var dull := StandardMaterial3D.new()
	dull.albedo_color = tint
	dull.roughness = 0.85
	# THE FLOOR, from under the seat forward to the bar.
	_slab("Floor", dull, Vector3(floor_width, CockpitStation.FLOOR, FLOOR_DEPTH),
		Vector3(0.0, footwell_raise + CockpitStation.FLOOR * 0.5, front() + FLOOR_DEPTH * 0.5))
	# AND THE BAR ON THE FRONT OF THE FOOTWELL, at hand height, set just aft of the limit so
	# that the bar marking the line does not itself cross it.
	var amber := StandardMaterial3D.new()
	amber.albedo_color = BAR_TINT
	amber.roughness = 0.70
	_slab("FirewallBar", amber, Vector3(bar_width, BAR, BAR),
		Vector3(0.0, CockpitStation.hands() - BAR * 0.5, front() + BAR * 0.5))


## ONE PIECE OF THE STRUCTURE, NAMED. The name is not decoration: `tests/shell_room.gd`
## reports which piece of which station is drawn outside its aircraft, and "Shell/7" told
## nobody anything.
func _slab(label: String, material: StandardMaterial3D, size: Vector3, at: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = box
	node.material_override = material
	node.position = at
	add_child(node)
