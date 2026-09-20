@tool
extends Node3D
class_name ApacheAirframe
## A BOEING AH-64D APACHE LONGBOW, DRAWN: THE GUNNER IN FRONT AND LOW, THE PILOT BEHIND AND HIGHER. The stepped tandem
## canopy of flat panes over the wide cheek bays, the TADS/PNVS sensor turrets on the nose, the M230 chain gun in its
## turret under the chin, the two stub wings with a Hellfire launcher outboard and a rocket pod inboard on each, the two
## engine nacelles with their exhausts, the four-bladed main rotor under the Longbow radar's dome, the long tail boom with
## its swept fin, stabilator and four-bladed scissor tail rotor on the PORT side, and the tailwheel gear.
##
## THE D, AND NOT THE A OR THE E. The dome on the mast is the recognition feature and it is the D's (and the E's, which
## looks the same from outside); the D's Longbow Hellfire is fire-and-forget, which is what a helmet lock wants. The A
## drawing it is measured from has no dome, so the dome is the one large part taken from a photograph ([P1]).
##
## THE SCALE IS THE ROTOR, AND NOTHING ELSE WAS FITTED. [ARMY] is a US Army recognition three-view, public domain, 574 x
## 385 px. Its front view draws the main rotor edge-on, 265 px tip to tip, against [W]'s 14.63 m: 0.05521 m a pixel.
## At that one scale, with nothing tuned to them: the plan view's rotor diagonals read 263 px (0.8 per cent short -- the
## plan is a little smaller, and says so); the body, TADS to the stabilator's trailing edge, reads 14.71 m against [W]'s "fuselage length" of 15.06 (-2.3 %;
## [W] names no datum for it);
## the length with the rotors turning 17.61 m against [W]'s 17.73 (-0.7 %); the front view's top, over the tail rotor,
## 4.64 m against [FAS]'s 4.64 for the A; the plan's wing span 5.08 m against [FAS]'s 5.227 (-2.8 %, drawn tips rounded).
## `craft/apache/measure_drawing.py` prints every one of those from the drawing and checks each hand pick lies on a line.
##
## A PIXEL IS 5.5 CENTIMETRES, and that is the resolution of everything MEASURED here: good for proportion, useless for
## a 3 cm frame. Where the drawing is too coarse, or wrong, the number is an ESTIMATE and says what it was reasoned from.
## THE SIDE VIEW IS NOT QUITE ORTHOGRAPHIC: its rotor is drawn tilted in perspective and its tail rotor as a skewed X, so
## the side view gives stations and heights of the BODY only; the rotor comes from the front and plan views.
##
## THE COCKPIT IS WIDENED, AS THE USER ASKED ("we can be bigger than normal to support this"). [ARMY]'s front view draws
## the canopy 18 px, 0.99 m, across; a station shell is 1.05 m and a player's shoulders and turned head want 1.00 m of it
## (`tests/seat_room.gd`). The canopy here is `CANOPY_HALF` * 2 = 1.30 m across its side panes, +0.31 m (+31 %), and it
## still stands inside the cheek bays under it, which [ARMY] draws 1.93 m across -- so from above the Apache is exactly
## the drawing's, and from the front the glass is a hand's width broader each side. THE ROOF OVER THE GUNNER is raised
## 3 to 4 px, 0.17 to 0.22 m, over [ARMY]'s line: the gunner's eye is put where he sees down over the nose past the TADS
## (`GUNNER_EYE`), and a 95th-percentile head there wants 0.25 m over it (`seat_room`). Nothing else moved.
##
## TESSELLATION, STATED SO NOBODY SUBDIVIDES IT (`modelling_here.md` section 4; the Hawkeye's nacelle is 20 round):
## - THE FUSELAGE: 14 facets a ring -- a spine, the canopy's two panes a side, the sill shelf, the cheek wall, a chine and
##   the keel -- through 17 measured rings; the Apache is a box of flat panels and the facets ARE its panels. The canopy is
##   whole facets, because its real panes are flat.
## - TAIL BOOM 8 a ring through 7 rings, NACELLE 8 a ring, TADS drum 8, rocket pod 10, Hellfire 8, wheels 8, mast 8.
## - A BLADE is `RotorcraftKit.blade`: six points round, as every helicopter here.
## Every face carries its own normal; nothing is smoothed.
##
## BUILT ON `RotorcraftKit`: its materials, its triangles (wound away from a point inside), its blades and its main rotor,
## which `set_rotors(turning, collective, seconds)` turns on the shared physics clock, as `LittleBirdAirframe` does. The
## tail rotor is this class's own because the Apache's is a SCISSOR: two pairs of blades 55 degrees apart ([W]), which the
## kit's evenly spaced rotor cannot draw.
##
## THE CHIN GUN IS A PART THAT FOLLOWS AN ANGLE IT IS HANDED: `set_gun(yaw, pitch)`, radians in the craft's frame, 0 and 0
## dead ahead. It knows nothing about who is aiming it or how fast it slews -- that is the simulation's (step 3), and this
## draws whatever angle it is given, so the barrel everybody sees is the barrel the rounds leave. `sockets()` publishes the
## turret's trunnion and the muzzle's distance for the simulation's table to be held to.
##
## NOT IN VehicleView's `_body`: `_show_body` paints one flat material over every mesh there, and this airframe's colour is
## in its vertices (`lane/fleet`, Hawkeye).

## THE SIMULATION OWNS THE SIZE since step 2 (`apache_shape` in `cockpit_world.cpp`), and its box is this one, the drawn
## body's: the TADS to the stabilator's trailing edge, the main wheels' ground to the mast fairing's top, the cheek bays'
## width. `dress(geometry)` takes the kind's own; `tests/apache.gd` holds the two to each other.
const DEFAULT_HALF := Vector3(0.966, 1.615, 7.357)
## THE KIND since step 2 (`apache_shape` in `cockpit_world.cpp`), whose box is DEFAULT_HALF: `dress()` asks the simulation
## when it is handed nothing, and `tests/apache.gd` holds the two to each other.
const KIND: int = Sim.Kind.APACHE

## ---- the reference and the scale ------------------------------------------------------------------------------------
## [W]: Wikipedia, "Boeing AH-64 Apache", Specifications (AH-64A/D), citing Jane's 2000-01 and 2010-11 and Bishop 2005.
const ROTOR_DIAMETER: float = 14.63
## [ARMY], front view: the main rotor's blade tips at x 277 and x 541, inclusive. THE SCALE.
const DRAWN_ROTOR: float = 265.0
const UNIT: float = ROTOR_DIAMETER / DRAWN_ROTOR

## THE DATUMS on [ARMY], in its pixels. The side view: the TADS turret's front at x 287; the ground under the main wheels
## at y 303.5 (the wheel's lowest dark pixel is 303). The plan view's nose is at y 71 and its centreline at x 138.5, so a
## plan y is a side x + 216 (the wing's root chord lands on the side view's wing to 2 px).
const NOSE_X: float = 287.0
const GROUND_Y: float = 303.5
const PLAN_TO_SIDE: float = 216.0

## THE PAINT. US Army olive drab, a green that is nearly black in shade; a lighter olive on top so the facets read.
## ESTIMATE, from [P1] and [P2].
const BODY := Color(0.27, 0.29, 0.22)
const TOP := Color(0.31, 0.33, 0.25)
const TRIM := Color(0.16, 0.17, 0.13)
const DARK := Color(0.05, 0.05, 0.05)
const METAL := Color(0.34, 0.35, 0.33)
const LENS := Color(0.06, 0.08, 0.12)
const BLADE := Color(0.14, 0.15, 0.13)
const TIP := Color(0.78, 0.74, 0.30)
const FLOOR := Color(0.20, 0.21, 0.19)
const MISSILE := Color(0.33, 0.35, 0.28)
const WARHEAD := Color(0.20, 0.21, 0.18)
const GLASS := Color(0.58, 0.66, 0.66, 0.20)

## ---- the fuselage -----------------------------------------------------------------------------------------------------
## THE RINGS [ARMY], nose to boom, each [side x, roof y, upper half-width m, sill y, cheek plan half px, belly y]:
## - ROOF, SILL and BELLY are side-view rows: the roof line, the canopy's lower edge (where the glass meets the shelf over
##   the cheek bay), and the keel. Aft of the canopy the "sill" is the line the upper fuselage stands on.
## - UPPER HALF-WIDTH is the canopy's (or, aft of it, the upper fuselage's) half-width in METRES, because this is the one
##   column that is not the drawing's: over the crew it is `CANOPY_HALF`, the widened cockpit. Elsewhere it is [ARMY]'s
##   front view (0.30 m at the nose, 0.45 over the engines' deck), tapering.
## - CHEEK is the plan view's half-width in pixels: the cheek bays' outer wall, 17.5 px (0.97 m) from the canopy's front
##   to the wing's trailing edge.
## THE GUNNER'S WINDSCREEN IS STEEPER THAN DRAWN: [ARMY]'s roof line runs straight from the front bow (x 311, y 268) to
## the pilot's canopy (x 340, y 251.5), and under it a head at the gunner's eye had 0.27 m ahead and 0.23 over. Here it
## rises from the bow at 266.5 to 259.5 in five pixels and then runs flatter, 256.5 at x 320 and 253.5 at x 330 (drawn 262
## and 256.5): the pane in front of his face stands nearer upright, as the real CPG's flat windscreen does ([P1]).
const CANOPY_HALF: float = 0.65
const RINGS: Array = [
	[297.0, 271.0, 0.30, 278.0, 9.5, 289.0],
	[304.0, 270.0, 0.40, 277.0, 12.0, 289.5],
	[311.0, 266.5, 0.62, 276.0, 15.0, 290.0],
	[316.0, 259.5, 0.64, 275.5, 16.5, 290.0],
	[320.0, 256.5, 0.65, 275.0, 17.5, 290.0],
	[330.0, 253.5, 0.65, 272.0, 17.5, 290.0],
	[340.0, 251.5, 0.65, 269.0, 17.5, 290.0],
	[350.0, 249.5, 0.65, 268.0, 17.5, 290.0],
	[359.0, 249.0, 0.64, 268.0, 17.5, 290.0],
	[367.0, 247.0, 0.55, 268.0, 17.5, 290.0],
	[385.0, 245.0, 0.45, 268.0, 17.5, 289.0],
	[394.0, 246.0, 0.43, 268.0, 17.0, 288.5],
	[400.0, 249.0, 0.41, 268.5, 13.5, 288.0],
	[415.0, 252.0, 0.39, 269.0, 13.0, 287.0],
	[430.0, 256.0, 0.37, 269.5, 12.5, 285.5],
	[445.0, 262.0, 0.35, 270.0, 11.0, 283.5],
	[452.0, 262.0, 0.34, 270.0, 10.5, 283.0],
]
## THE CHEEK BAY'S TOP [ARMY]: the long line at y 277 from the nose to the wing, the shelf the canopy stands on.
const CHEEK_TOP_Y: float = 277.0
## THE CANOPY runs from x 311 to x 359 [ARMY]; the frame between the gunner's and the pilot's panes is at x 337.
const CANOPY_X: Vector2 = Vector2(311.0, 359.0)
const CANOPY_BOWS: Array = [311.0, 337.0, 359.0]
## HOW WIDE THE SPINE down the canopy's roof is, as a share of the canopy's half-width: the frame the roof panes hang from.
const SPINE: float = 0.22
const RING_SIDES: int = 14

## THE TAIL BOOM [ARMY]: [side x, top y, bottom y, plan half px], from inside the aft fuselage to the fin's root.
const BOOM: Array = [
	[445.0, 262.0, 283.5, 11.0], [470.0, 262.0, 281.5, 9.5], [500.0, 262.0, 280.0, 8.0], [518.0, 262.0, 279.0, 7.0],
	[530.0, 262.5, 278.5, 6.5], [545.0, 263.0, 278.0, 6.0], [553.0, 264.0, 277.0, 5.0],
]
const BOOM_SIDES: int = 8

## THE FIN [ARMY], side view: its root from x 518 to x 556 at the boom's top, its tip. THE TIP IS NOT THE DRAWING'S:
## the side view's fin rises to y 218 (4.72 m), and with [F]'s 2.79 m tail rotor on a hub at its top the tail rotor would
## stand 5.6 m high against [FAS]'s 4.64 overall and the front view's own 4.64. The front view is orthographic and the
## side view's tail is drawn in perspective, so the TAIL ROTOR's top is held to 4.64 m, its hub is 1.395 m under that
## (3.245 m, y 244.7), and the fin's tip is the hub's height plus the gearbox's 0.3 m.
const FIN_ROOT: Vector2 = Vector2(518.0, 553.5)
const FIN_TIP: Vector2 = Vector2(537.0, 551.0)
const FIN_HALF: float = 0.07
## THE TAIL ROTOR: [F]'s 2.79 m, hub at x 541, 0.36 m to PORT of the fin's middle ([P1], [P2]: it turns on the port side).
const TAIL_ROTOR_DIAMETER: float = 2.79
const TAIL_HUB_X: float = 541.0
const TAIL_OUT: float = 0.36
## THE SCISSOR [W]: "4-bladed tail-rotor with 55 degree non-orthogonal blade offset".
const SCISSOR: float = 55.0 * PI / 180.0
const TAIL_CHORD: float = 0.25
## THE STABILATOR [ARMY]: the plan view's plate at the fin's foot, 64 px across (3.53 m); the side view puts it at y 264
## and its trailing edge at x 553.5, the last dark column in its rows (`measure_drawing.py`).
const STABILATOR: Rect2 = Rect2(536.0, 262.5, 17.5, 3.0)
const STABILATOR_HALF: float = 32.0

## ---- the rotor --------------------------------------------------------------------------------------------------------
## THE HUB [ARMY]: the plan's two blade diagonals cross at plan (137.5, 163), side x 379; the side view's mast stands at x
## 375-377. x 377. The rotor turns in the plane y 236 (3.73 m), the hub's top at the front view's 3.92 m.
const HUB_X: float = 377.0
const ROTOR_Y: float = 236.0
const HUB_RADIUS: float = 0.42
const HUB_HEIGHT: float = 0.34
const BLADES: int = 4
## THE CHORD, ESTIMATE: 0.53 m (21 in) is the figure commonly quoted for the AH-64's main blade; not in [W].
const CHORD: float = 0.53
## THE LONGBOW RADAR'S DOME [P1]: MEASURED as proportions of its own width off the photograph -- 0.44 of it tall, its
## stem 0.42 of it long above the blade plane's hub and 0.28 of it across -- and the width an ESTIMATE, 1.10 m, because
## no source gives it and nothing in the photograph is a known size at the mast.
const DOME_WIDTH: float = 1.10
const DOME_TALL: float = 0.44
const DOME_STEM: float = 0.42
const DOME_STEM_WIDE: float = 0.28

## ---- the nose, the gun and the sensors ---------------------------------------------------------------------------------
## THE TADS turret [ARMY]: side x 287 to 300, y 272 to 290; plan 19 px (1.05 m) across its two sensor housings.
const TADS: Rect2 = Rect2(287.0, 272.0, 13.0, 18.0)
const TADS_HALF: float = 0.52
## THE PNVS [ARMY]: the small turret on the nose's top, x 289 to 297, y 266 to 272.
const PNVS: Vector3 = Vector3(293.0, 268.5, 0.19)  # x, y, radius m
## THE M230's TURRET [ARMY]: its trunnion at x 336, y 294 (0.52 m up, 2.70 m aft of the TADS's front); the barrel drawn
## forward to x 310, so the muzzle is 26 px, 1.44 m, ahead of the trunnion. The turret's yoke hangs from the belly.
const GUN_X: float = 336.0
const GUN_Y: float = 294.0
const MUZZLE: float = 26.0 * UNIT
## [TM] 4.8: "capable of slewing the gun 100 ... left or right of the helicopter centerline and up 11 to 60 down". Drawn
## limits only: `set_gun` clamps to them so a picture cannot show a barrel through the belly; the simulation has its own.
const GUN_YAW_LIMIT: float = 100.0 * PI / 180.0
const GUN_UP: float = 11.0 * PI / 180.0
const GUN_DOWN: float = 60.0 * PI / 180.0

## ---- the wings, the engines and the stores ----------------------------------------------------------------------------
## THE STUB WING [ARMY]: the plan's root chord y 157 to 178 (side x 373 to 394), its tip chord x 375 to 391, its tips
## 92 px apart at plan scale -- 5.08 m, [FAS] 5.227 m. THE SPAN IS [FAS]'s: the drawing's tips are rounded off and it is
## 2.8 per cent short. The side view puts the wing at y 279, 1.35 m up; thickness ESTIMATE 0.18 m.
const WING_SPAN: float = 5.227
const WING_ROOT: Vector2 = Vector2(373.0, 394.0)
const WING_TIP: Vector2 = Vector2(375.0, 391.0)
const WING_Y: float = 279.0
const WING_THICK: float = 0.18
## THE PYLONS, ESTIMATE from [ARMY]'s front view (the outboard launcher at 1.5 m) and [P1]: 1.25 m and 2.10 m out.
const PYLONS: Array = [1.25, 2.10]
## THE STORES [W]'s "four pylon stations": a 19-tube rocket pod inboard, a four-rail Hellfire launcher outboard, each side,
## as [P1] carries them. A Hellfire 1.63 m long and 0.178 across; a pod 1.60 m and 0.40.
const HELLFIRE_LONG: float = 1.63
const HELLFIRE_WIDE: float = 0.178
const POD_LONG: float = 1.60
const POD_WIDE: float = 0.40
## THE NACELLES [ARMY]: side x 367 to 430, y 251 to 268; the front view's rectangles 1.10 m out and 1.0 m across. Their
## middle is brought in to 1.02 m, 0.44 m half-width, so the inner wall is bedded 3 cm into the fairing under it.
const NACELLE_X: Vector2 = Vector2(367.0, 430.0)
const NACELLE_Y: Vector2 = Vector2(251.0, 268.0)
const NACELLE_OUT: float = 1.02
const NACELLE_HALF: float = 0.44

## ---- the gear -----------------------------------------------------------------------------------------------------------
## THE MAIN WHEELS [ARMY]: the side view's wheel at x 363, its bottom on the ground; radius 0.33 m (the drawn wheel is 12 px
## across with its tyre's outline). THE TRACK IS AN ESTIMATE, 2.03 m: the front view's wheels are hidden behind the
## stores and cannot be told apart at 5.5 cm a pixel.
const MAIN_WHEEL_X: float = 363.0
const MAIN_WHEEL_R: float = 0.33
const TRACK: float = 2.03
## THE TAILWHEEL [ARMY]: x 551 drawn, placed at 549 -- two pixels, a pick's resolution -- so the eight-sided tyre's corner
## stands inside the box's tail (the stabilator's trailing edge) rather than 5 cm past it; radius 0.19 m. LEVELLED, AND THAT IS A DECISION: the drawing hangs it 0.97 m over the
## main wheels' ground (y 286 against 303.5), which parked would pitch the Apache 5.3 degrees nose-up. The simulation parks
## a craft on its box's floor, so the tail leg reaches the same ground as the mains, and the drawn rake is written down in
## `craft/apache/sources.md` against a broadside photograph that could settle it.
const TAIL_WHEEL_X: float = 549.0
const TAIL_WHEEL_R: float = 0.19

## ---- the crew ---------------------------------------------------------------------------------------------------------
## THE EYES, ESTIMATE from [ARMY]'s canopy, both on the centreline: the GUNNER at x 323, y 261.5 -- 2.33 m over the
## ground, 1.99 m aft of the TADS's front; the PILOT at x 350, y 256.5 -- 2.59 m up, 1.49 m aft of the gunner and 0.28 m
## over him. Each has 0.25 m or more of roof over the eye (`seat_room`), and the gunner's anchor, EYE_HEIGHT (1.35 m)
## under his eye, is 0.23 m over the keel.
## THE GUNNER'S EYE IS WHERE HE SEES DOWN OVER THE NOSE, and that decided it. The first build put it at x 326, y 262.7,
## a seated eye under the drawn roof, and from there the nose's top and the TADS stood 16 degrees under dead ahead: 0.27
## of the over-the-nose cone was clear. The user named the gunner's forward and down view as what matters most, so the eye
## came 3 px forward and 1.2 px up, and the roof over it went up to keep the head room.
const GUNNER_EYE: Vector2 = Vector2(323.0, 261.5)
const PILOT_EYE: Vector2 = Vector2(350.0, 256.5)
## THE ROOM promised inside the drawn skin, per seat [x from, x to, top y, bottom y], half-width ROOM_HALF.
const ROOMS: Array = [[341.0, 357.0, 256.0, 283.0], [320.0, 334.0, 262.5, 286.0]]
const ROOM_HALF: float = 0.45

## Small fittings stop drawing once the whole helicopter is a few pixels high.
const DETAIL_RANGE: float = 600.0
const DETAIL_HYSTERESIS: float = 60.0

var _half: Vector3 = DEFAULT_HALF
var exterior: Node3D
var interior: Node3D
var main_rotor: Node3D
var tail_rotor: Node3D
var gun_yaw_node: Node3D
var gun_pitch_node: Node3D
var _rotors_handed: Dictionary = {"turning": false, "collective": 0.0, "seconds": 0.0}
var _gun: Vector2 = Vector2.ZERO


## BUILT IN PLACE, after `new()`: from the kind's geometry when handed one, else from the drawn body's own box.
## Everything a person sees from outside is under `Exterior`; the cockpit floors under `Interior`.
func dress(geometry: Dictionary = {}) -> void:
	if get_child_count() > 0:
		return
	name = "Apache"
	var given: Dictionary = geometry if geometry.has("extents") else Sim.geometry_of(KIND)
	_half = given.get("extents", DEFAULT_HALF) as Vector3
	exterior = Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	interior = Node3D.new()
	interior.name = "Interior"
	add_child(interior)
	var paint := RotorcraftKit.paint()
	var glass := RotorcraftKit.glass()

	_fuselage(paint, glass)
	var frame := RotorcraftKit.tool()
	_canopy_frame(frame)
	RotorcraftKit.part(exterior, "CanopyFrame", frame, paint)
	var fin := RotorcraftKit.tool()
	_fin(fin)
	RotorcraftKit.part(exterior, "Fin", fin, paint)
	var stab := RotorcraftKit.tool()
	_stabilator(stab)
	RotorcraftKit.part(exterior, "Stabilator", stab, paint)
	var tads := RotorcraftKit.tool()
	_tads(tads)
	_pnvs(tads)
	RotorcraftKit.part(exterior, "Tads", tads, paint)
	var mast := RotorcraftKit.tool()
	_mast(mast)
	_dome(mast)
	RotorcraftKit.part(exterior, "MastAndRadar", mast, paint)
	# THE PAIRS ARE ONE PART EACH, both sides in one mesh: the first build drew 31 surfaces against the first LOD's 20
	# (`modelling_here.md` section 8), and a port and a starboard nacelle are one thing to the renderer.
	var nacelles := RotorcraftKit.tool()
	var wings := RotorcraftKit.tool()
	var stores := RotorcraftKit.tool()
	var gear := RotorcraftKit.tool()
	for side in [1.0, -1.0]:
		_nacelle(nacelles, side)
		_wing(wings, side)
		_rocket_pod(stores, side)
		_hellfires(stores, side)
		_main_gear(gear, side)
	_tail_gear(gear)
	RotorcraftKit.part(exterior, "Nacelles", nacelles, paint)
	RotorcraftKit.part(exterior, "StubWings", wings, paint)
	_detail(RotorcraftKit.part(exterior, "Stores", stores, paint))
	RotorcraftKit.part(exterior, "Gear", gear, paint)
	_gun_turret(paint)
	var cabin := RotorcraftKit.tool()
	_cabin(cabin)
	_detail(RotorcraftKit.part(interior, "Cabin", cabin, paint))
	_rotors(paint)
	set_gun(0.0, 0.0)


## WHERE THE LIGHTS GO, in the craft's frame, on the parts that carry them: a nav light at each stub wing's tip (red to
## port), the white tail light at the stabilator's trailing edge -- aft of the nav lights, as `tests/lights_on_skin.gd`
## requires -- a strobe on the fin's top, a beacon on the engine deck aft of the nacelles' exhausts, where nothing stands
## over it (on the mast fairing it had the Longbow dome 1.68 m above it: `tests/lights_on_skin.gd`), and one under the
## belly. Static, from the default
## box until the kind exists.
static func lights(half: Vector3 = DEFAULT_HALF) -> Dictionary:
	var put := func(out: float, x: float, y: float) -> Vector3:
		return Vector3(out, -half.y + (GROUND_Y - y) * UNIT, -half.z + (x - NOSE_X) * UNIT)
	var tip: float = WING_SPAN * 0.5
	return {"port": put.call(-tip, (WING_TIP.x + WING_TIP.y) * 0.5, WING_Y),
		"starboard": put.call(tip, (WING_TIP.x + WING_TIP.y) * 0.5, WING_Y),
		"tail": put.call(0.0, STABILATOR.end.x, STABILATOR.position.y + 1.5),
		"strobe": put.call(0.0, (FIN_TIP.x + FIN_TIP.y) * 0.5, _tail_hub_y() - 0.3 / UNIT),
		"top": put.call(0.0, 425.0, 254.9), "bottom": put.call(0.0, 360.0, 290.0)}


func show_layers(show_exterior: bool, show_interior: bool) -> void:
	if exterior != null:
		exterior.visible = show_exterior
	if interior != null:
		interior.visible = show_interior


## A DRAWING X (pixels, increasing aft) as a z: the TADS's front is at the box's front face.
func station(x: float) -> float:
	return -_half.z + (x - NOSE_X) * UNIT


## A DRAWING Y (pixels, increasing DOWN the page) as a y: the main wheels' ground is the box's bottom face.
func height(y: float) -> float:
	return -_half.y + (GROUND_Y - y) * UNIT


## A point `out` METRES from the centreline (positive to starboard), at drawing x and y.
func at(out: float, x: float, y: float) -> Vector3:
	return Vector3(out, height(y), station(x))


## THE TAIL ROTOR'S HUB as a drawing y: the front view's 4.64 m top less the rotor's radius (see FIN_ROOT).
static func _tail_hub_y() -> float:
	return GROUND_Y - (4.64 - TAIL_ROTOR_DIAMETER * 0.5) / UNIT


## THE CREW'S EYES, craft-local: the PILOT (rear, seat 0) and then the GUNNER (front, seat 1), the order the seats are
## numbered in -- the rear seat is the primary.
func crew_eyes() -> Array[Vector3]:
	return [at(0.0, PILOT_EYE.x, PILOT_EYE.y), at(0.0, GUNNER_EYE.x, GUNNER_EYE.y)]


## THE ROOM A CREW SITS IN, in the shape `VehicleView.cabin_room()` asks for: the largest box PROMISED inside the drawn
## skin round the two seats together, and the floor beside it. `tests/apache.gd` holds each seat's own box to the triangles.
func cabin_room() -> Dictionary:
	var fore: float = station(float(ROOMS[1][0]))
	var aft: float = station(float(ROOMS[0][1]))
	var low: float = height(float(ROOMS[1][3]))
	var high: float = height(float(ROOMS[1][2]))
	return {
		"drawn": true,
		"floor": crew_eyes()[1].y - CockpitStation.EYE_HEIGHT + CockpitStation.FLOOR,
		"room": AABB(Vector3(-ROOM_HALF, low, fore), Vector3(ROOM_HALF * 2.0, high - low, aft - fore)),
		"because": &"",
		"why_not": "",
		"source": "eyes ESTIMATE from the drawn canopy; the cockpit widened to 1.30 m; the room MEASURED against the drawn skin, 2026-09-18",
	}


## EACH SEAT'S OWN ROOM, [pilot, gunner], each promised inside the skin: the two seats stand at different heights, so one
## box round both would be the lower seat's floor under the higher seat's roof.
func seat_rooms() -> Array[AABB]:
	var out: Array[AABB] = []
	for r in ROOMS:
		var low: float = height(float(r[3]))
		out.append(AABB(Vector3(-ROOM_HALF, low, station(float(r[0]))),
			Vector3(ROOM_HALF * 2.0, height(float(r[2])) - low, station(float(r[1])) - station(float(r[0])))))
	return out


## THE ROTORS, from what this machine holds -- `LittleBirdAirframe.set_rotors`, word for word in what it does, so
## `VehicleView` drives every helicopter alike. Seen from above the main rotor turns anticlockwise, as an American one does.
func set_rotors(turning: bool, collective: float, seconds: float) -> void:
	_rotors_handed = {"turning": turning, "collective": clampf(collective, 0.0, 1.0), "seconds": seconds}
	var shown: float = smoothstep(0.05, 0.6, collective) if turning else 0.0
	RotorcraftKit.turn(main_rotor, seconds * RotorcraftKit.MAIN_TURNS if turning else 0.0, shown)
	RotorcraftKit.turn(tail_rotor, seconds * RotorcraftKit.TAIL_TURNS if turning else 0.0, 0.0)


func rotors_state() -> Dictionary:
	return _rotors_handed.duplicate()


## THE CHIN GUN, POINTED WHERE IT IS TOLD: `yaw` radians about the craft's up (positive swings the barrel to PORT, the
## sense `aim_turret` uses), `pitch` radians above level. Clamped to [TM]'s drawn limits only so a picture cannot put the
## barrel through the belly; which angle it is at is the simulation's to say.
func set_gun(yaw: float, pitch: float) -> void:
	_gun = Vector2(clampf(yaw, -GUN_YAW_LIMIT, GUN_YAW_LIMIT), clampf(pitch, -GUN_DOWN, GUN_UP))
	if gun_yaw_node != null:
		gun_yaw_node.basis = Basis(Vector3.UP, _gun.x)
		gun_pitch_node.basis = Basis(Vector3.RIGHT, _gun.y)


func gun_angles() -> Vector2:
	return _gun


## THE NAMED HARD POINTS the simulation's tables are held to, craft-local: the gun's trunnion and how far the muzzle is out
## along the barrel, the four pylons, both eyes.
func sockets() -> Dictionary:
	var pylons: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		for out in PYLONS:
			pylons.append(at(side * float(out), (WING_ROOT.x + WING_ROOT.y) * 0.5, WING_Y + 4.0))
	return {"gun": at(0.0, GUN_X, GUN_Y), "muzzle": MUZZLE, "pylons": pylons, "eyes": crew_eyes()}


static func _detail(mesh: MeshInstance3D) -> void:
	mesh.visibility_range_end = DETAIL_RANGE
	mesh.visibility_range_end_margin = DETAIL_HYSTERESIS
	mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


# ---------------------------------------------------------------------------------------------------------------------
# THE FUSELAGE

## ONE RING's fourteen points from a RINGS row, the roof's middle first and round the starboard side to the keel's middle,
## then back up the port side: the spine's edge, the canopy's shoulder, the sill, the cheek's top outer corner, the
## cheek's foot, the keel's chine. Where the upper half-width is wider than the cheek (never, as drawn) the cheek wins.
func _ring(row: Array) -> Array:
	var x: float = row[0]
	var roof: float = row[1]
	var upper: float = row[2]
	var sill: float = row[3]
	var cheek: float = maxf(float(row[4]) * UNIT, upper)
	var belly: float = row[5]
	var cheek_top: float = maxf(CHEEK_TOP_Y, sill)
	var starboard: Array = [
		Vector2(upper * SPINE, roof),
		Vector2(upper * 0.93, roof + (sill - roof) * 0.30),
		Vector2(upper, sill),
		Vector2(cheek, cheek_top + 0.5),
		Vector2(cheek * 0.95, belly - (belly - cheek_top) * 0.22),
		Vector2(cheek * 0.55, belly),
	]
	var points: Array = [at(0.0, x, roof)]
	for p in starboard:
		points.append(at(p.x, x, p.y))
	points.append(at(0.0, x, belly))
	for i in range(starboard.size() - 1, -1, -1):
		var p: Vector2 = starboard[i]
		points.append(at(-p.x, x, p.y))
	return points


## WHAT FACET `k` OF A RING IS, from the roof's middle round: 0 spine, 1 roof pane, 2 side pane, 3 shelf, 4 cheek,
## 5 chine, 6 keel; 7 to 13 the same on the port side, mirrored.
static func _facet(k: int) -> int:
	return k if k < 7 else 13 - k


## THE FUSELAGE, ONE PART OF TWO SURFACES, the painted skin and the glass. One part because the cockpit only closes as a
## whole -- the roof over a head is glass and the floor under the feet is skin -- and `tests/shell_room.gd` asks each
## drawn part on its own whether a point is inside it (`LittleBirdAirframe._pod_part`, the same trap).
func _fuselage(paint: Material, glass: Material) -> void:
	var skin := RotorcraftKit.tool()
	var glazing := RotorcraftKit.tool()
	var rings: Array = []
	for row in RINGS:
		rings.append(PackedVector3Array(_ring(row)))
	var style := func(span: int, facet: int) -> Variant:
		if span < 0:
			return TRIM
		if span >= RINGS.size() - 1:
			return BODY
		var x: float = (float(RINGS[span][0]) + float(RINGS[span + 1][0])) * 0.5
		var f: int = _facet(facet)
		if x > CANOPY_X.x and x < CANOPY_X.y and f <= 2:
			return GLASS
		# AHEAD OF THE FRONT BOW THE NOSE IS PAINTED. The first build glazed its roof from x 304 "as the gunner's
		# windscreen", and from his eye that was a window into the nose: the back of the TADS drum filled the lower
		# middle of his view, and every sightline through that roof counted as clear (team-lead, picture 05).
		if f <= 1:
			return TOP
		if f >= 5:
			return TRIM
		return BODY
	RotorcraftKit.loft(skin, glazing, rings, style)
	# THE TAIL BOOM IS THE SAME SKIN: its root is bedded in the aft fuselage and it is painted the same.
	_boom(skin)
	var mesh: ArrayMesh = skin.commit()
	glazing.commit(mesh)
	mesh.surface_set_material(0, paint)
	mesh.surface_set_material(1, glass)
	var node := MeshInstance3D.new()
	node.name = "Fuselage"
	node.mesh = mesh
	exterior.add_child(node)


## THE CANOPY'S FRAME: a rail along each sill, and a bow across at the front, between the two crew, and at the back --
## square bars 4 to 6 cm across on the glass's own lines. NO RAIL ALONG THE SPINE'S EDGES OR THE SHOULDERS: the first
## build had both, and from the gunner's eye the spine rails ran up from the front bow through dead ahead while the
## shoulder rail lay along his side at eye height -- 60 degrees off the nose he could see only 9 degrees down.
func _canopy_frame(tool: SurfaceTool) -> void:
	var rails: Array = []
	for side in [1.0, -1.0]:
		for corner in [3]:
			var line: Array[Vector3] = []
			for row in RINGS:
				if float(row[0]) >= CANOPY_X.x - 0.1 and float(row[0]) <= CANOPY_X.y + 0.1:
					var ring: Array = _ring(row)
					var p: Vector3 = ring[corner] if side > 0.0 else ring[RING_SIDES - corner]
					line.append(p)
			rails.append(line)
	for line in rails:
		RotorcraftKit.bent_rod(tool, line, 0.02, TRIM, 4)
	for x in CANOPY_BOWS:
		var row: Array = _row_at(x)
		var ring: Array = _ring(row)
		var bow: Array[Vector3] = []
		for k in [3, 2, 1, 0, 13, 12, 11]:
			bow.append(ring[k])
		RotorcraftKit.bent_rod(tool, bow, 0.03, TRIM, 4)


## A RINGS row at any x, interpolated between the measured ones.
func _row_at(x: float) -> Array:
	if x <= float(RINGS[0][0]):
		return RINGS[0]
	for i in range(RINGS.size() - 1):
		var a: Array = RINGS[i]
		var b: Array = RINGS[i + 1]
		if x <= float(b[0]):
			var t: float = (x - float(a[0])) / (float(b[0]) - float(a[0]))
			var out: Array = [x]
			for c in range(1, a.size()):
				out.append(lerpf(float(a[c]), float(b[c]), t))
			return out
	return RINGS[-1]


## THE TAIL BOOM: eight facets a ring, flat-topped and flat-bottomed as [P1] shows it, its root inside the aft fuselage
## and its end under the fin.
func _boom(tool: SurfaceTool) -> void:
	var rings: Array = []
	for row in BOOM:
		var x: float = row[0]
		var top: float = row[1]
		var bottom: float = row[2]
		var half: float = float(row[3]) * UNIT
		var mid: float = (top + bottom) * 0.5
		rings.append(PackedVector3Array([at(half * 0.6, x, top), at(half, x, top + (bottom - top) * 0.25),
			at(half, x, mid + (bottom - top) * 0.25), at(half * 0.6, x, bottom), at(-half * 0.6, x, bottom),
			at(-half, x, mid + (bottom - top) * 0.25), at(-half, x, top + (bottom - top) * 0.25), at(-half * 0.6, x, top)]))
	RotorcraftKit.loft(tool, tool, rings, func(_s: int, f: int) -> Variant:
		return TOP if f == 7 else (TRIM if f == 3 else BODY))


## THE FIN: a swept slab from the boom's top at its root to above the tail rotor's hub, 0.14 m thick, its root bedded in the
## boom. The leading edge is [ARMY]'s, the height is held to the front view's (FIN_ROOT's note).
func _fin(tool: SurfaceTool) -> void:
	var top_y: float = _tail_hub_y() - 0.30 / UNIT
	var foot_y: float = 263.0
	var outline: Array[Vector3] = [at(0.0, FIN_ROOT.x, foot_y + 1.0), at(0.0, FIN_TIP.x, top_y),
		at(0.0, FIN_TIP.y, top_y), at(0.0, FIN_ROOT.y, foot_y + 1.0)]
	RotorcraftKit.plate(tool, outline, Vector3.RIGHT, FIN_HALF * 2.0, BODY)
	# THE TAIL ROTOR'S GEARBOX: a block on the fin's port face at the hub, out to the rotor.
	var hub: Vector3 = at(-TAIL_OUT, TAIL_HUB_X, _tail_hub_y())
	RotorcraftKit.box(tool, Vector3((hub.x - FIN_HALF) * 0.5, hub.y, hub.z), Vector3(TAIL_OUT - FIN_HALF + 0.12, 0.22, 0.34),
		METAL)


## THE STABILATOR: the flat plate across the fin's foot, 3.53 m, its chord [ARMY]'s plan.
func _stabilator(tool: SurfaceTool) -> void:
	var half: float = STABILATOR_HALF * UNIT
	var y: float = STABILATOR.position.y + STABILATOR.size.y * 0.5
	var outline: Array[Vector3] = [at(-half, STABILATOR.position.x + 2.0, y), at(half, STABILATOR.position.x + 2.0, y),
		at(half, STABILATOR.end.x, y), at(-half, STABILATOR.end.x, y)]
	RotorcraftKit.plate(tool, outline, Vector3.UP, 0.08, TOP)


# ---------------------------------------------------------------------------------------------------------------------
# THE NOSE AND THE GUN

## THE TADS: a turret on a vertical axis with a sensor housing either side of it, their faces dark glass forward; bedded
## 3 cm into the nose's front.
func _tads(tool: SurfaceTool) -> void:
	var fore: float = TADS.position.x
	# ITS BACK IS BEDDED 1 PX INTO THE NOSE'S FRONT RING (x 297), and no further: the first build ran it to x 301, inside
	# the nose, where the gunner saw its back end down the open nose until the bulkhead went in (see `_cabin`).
	var aft: float = float(RINGS[0][0]) + 1.0
	var mid_y: float = TADS.position.y + TADS.size.y * 0.5
	var r: float = TADS.size.y * 0.5 * UNIT * 0.62
	var drum: Array = []
	for x in [fore + 3.0, aft]:
		drum.append(RotorcraftKit.ring(at(0.0, x, mid_y), Vector3.BACK, r, r, 8, PI / 8.0))
	RotorcraftKit.loft(tool, tool, drum, func(s: int, _f: int) -> Variant: return LENS if s < 0 else METAL)
	for side in [1.0, -1.0]:
		var out: float = side * (TADS_HALF - 0.11)
		var size := Vector3(0.22, TADS.size.y * UNIT * 0.75, (aft - fore) * UNIT)
		var centre: Vector3 = at(out, (fore + aft) * 0.5, mid_y)
		RotorcraftKit.box(tool, centre, size, BODY)
		# The housing's face: a dark window across its front.
		RotorcraftKit.box(tool, centre + Vector3(0.0, 0.0, -size.z * 0.5 + 0.014), Vector3(0.16, size.y * 0.6, 0.03), LENS)
	# The arm the housings hang from, through the drum.
	RotorcraftKit.box(tool, at(0.0, (fore + aft) * 0.5 + 1.0, mid_y), Vector3(TADS_HALF * 2.0 - 0.1, 0.14, 0.30), METAL)


## THE PNVS: the pilot's night sensor, a ball on a short neck on the nose's top, its window forward.
func _pnvs(tool: SurfaceTool) -> void:
	var centre: Vector3 = at(0.0, PNVS.x, PNVS.y)
	var r: float = PNVS.z
	var loops: Array = []
	for step in [[-0.9, 0.4], [-0.4, 0.92], [0.3, 0.95], [0.85, 0.5]]:
		loops.append(RotorcraftKit.ring(centre + Vector3(0.0, 0.0, float(step[0]) * r), Vector3.BACK, r * float(step[1]),
			r * float(step[1]), 8, PI / 8.0))
	RotorcraftKit.loft(tool, tool, loops, func(s: int, _f: int) -> Variant: return LENS if s < 0 else METAL)
	RotorcraftKit.rod(tool, centre + Vector3(0.0, -r * 0.5, 0.05), at(0.0, PNVS.x + 1.0, 272.0), 0.08, METAL, 6)


## THE M230 AND ITS TURRET: a fixed yoke housing hung from the belly, and under it the gun on two pivots -- `ChinGunYaw`
## about the craft's up, `ChinGunPitch` about its own right at the trunnion -- carrying the cradle and the barrel, which
## `set_gun` turns. The pivots are named `...Yaw`/`...Pitch` and the mesh `Gun`, so `find_child` of a
## mesh never finds a pivot first (`lane/tomcat2`: a hinge named like its part).
func _gun_turret(paint: Material) -> void:
	var trunnion: Vector3 = at(0.0, GUN_X, GUN_Y)
	var belly: float = height(float(_row_at(GUN_X)[5]))
	var housing := RotorcraftKit.tool()
	var housing_top: float = belly + 0.06
	var housing_low: float = trunnion.y + 0.16
	RotorcraftKit.loft(housing, housing, [
		RotorcraftKit.ring(Vector3(0.0, housing_top, trunnion.z), Vector3.UP, 0.30, 0.30, 8, PI / 8.0),
		RotorcraftKit.ring(Vector3(0.0, housing_low, trunnion.z), Vector3.UP, 0.24, 0.24, 8, PI / 8.0)],
		func(_s: int, _f: int) -> Variant: return TRIM)
	RotorcraftKit.part(exterior, "GunTurret", housing, paint)
	gun_yaw_node = Node3D.new()
	gun_yaw_node.name = "ChinGunYaw"
	gun_yaw_node.position = trunnion
	exterior.add_child(gun_yaw_node)
	gun_pitch_node = Node3D.new()
	gun_pitch_node.name = "ChinGunPitch"
	gun_yaw_node.add_child(gun_pitch_node)
	# THE YOKE: two arms from the housing's foot down either side of the trunnion.
	var cradle := RotorcraftKit.tool()
	for side in [1.0, -1.0]:
		RotorcraftKit.box(cradle, Vector3(side * 0.13, 0.08, 0.0), Vector3(0.05, 0.22, 0.20), METAL)
	# THE RECEIVER, a box behind and under the trunnion, and the feed chute's stub.
	RotorcraftKit.box(cradle, Vector3(0.0, -0.02, 0.12), Vector3(0.20, 0.18, 0.60), METAL)
	RotorcraftKit.box(cradle, Vector3(0.0, 0.10, 0.34), Vector3(0.12, 0.10, 0.16), TRIM)
	# THE BARREL out to the muzzle, with its recoil jacket and the muzzle's brake, in the same mesh: `Gun`.
	var barrel := cradle
	RotorcraftKit.rod(barrel, Vector3(0.0, 0.0, -0.18), Vector3(0.0, 0.0, -MUZZLE * 0.45), 0.065, METAL, 8)
	RotorcraftKit.rod(barrel, Vector3(0.0, 0.0, -MUZZLE * 0.45), Vector3(0.0, 0.0, -MUZZLE + 0.12), 0.035, DARK, 8)
	RotorcraftKit.rod(barrel, Vector3(0.0, 0.0, -MUZZLE + 0.12), Vector3(0.0, 0.0, -MUZZLE), 0.05, DARK, 8)
	RotorcraftKit.part(gun_pitch_node, "Gun", barrel, paint)


# ---------------------------------------------------------------------------------------------------------------------
# THE MAST, THE DOME AND THE ROTORS

## THE MAST from inside the fairing up to the hub, eight-sided.
func _mast(tool: SurfaceTool) -> void:
	var foot: Vector3 = at(0.0, HUB_X, 247.0)
	var head: Vector3 = at(0.0, HUB_X, ROTOR_Y)
	RotorcraftKit.rod(tool, foot, head, 0.17, METAL, 8)
	# The swashplate on the fairing's top.
	RotorcraftKit.rod(tool, foot + Vector3(0.0, 0.18, 0.0), foot + Vector3(0.0, 0.30, 0.0), 0.36, METAL, 8)


## THE LONGBOW RADAR: its stem up from the hub's top, and the flattened dome on it -- eight facets round, lofted through
## five rings so it reads as a squashed drum from the side, as [P1] shows it.
func _dome(tool: SurfaceTool) -> void:
	var hub_top: float = height(ROTOR_Y) + HUB_HEIGHT * 0.95
	var stem_top: float = hub_top + DOME_STEM * DOME_WIDTH
	var centre := Vector3(0.0, 0.0, station(HUB_X))
	RotorcraftKit.rod(tool, centre + Vector3(0.0, hub_top - 0.05, 0.0), centre + Vector3(0.0, stem_top + 0.04, 0.0),
		DOME_STEM_WIDE * DOME_WIDTH * 0.5, METAL, 8)
	var r: float = DOME_WIDTH * 0.5
	var tall: float = DOME_TALL * DOME_WIDTH
	var loops: Array = []
	for step in [[0.0, 0.55], [0.18, 0.93], [0.5, 1.0], [0.82, 0.90], [1.0, 0.5]]:
		loops.append(RotorcraftKit.ring(centre + Vector3(0.0, stem_top + tall * float(step[0]), 0.0), Vector3.UP,
			r * float(step[1]), r * float(step[1]), 10, PI / 10.0))
	RotorcraftKit.loft(tool, tool, loops, func(_s: int, _f: int) -> Variant: return BODY)


## BOTH ROTORS. THE MAIN ROTOR from `RotorcraftKit.rotor` on the mast's axis in the drawn rotor plane: four blades of
## CHORD to [W]'s radius exactly, blade 0 dead ahead so a parked rotor reaches forward. THE TAIL ROTOR is `_scissor`'s.
func _rotors(paint: Material) -> void:
	main_rotor = RotorcraftKit.rotor(exterior, "MainRotor", at(0.0, HUB_X, ROTOR_Y), Basis.IDENTITY,
		ROTOR_DIAMETER * 0.5, BLADES, CHORD, HUB_RADIUS, HUB_HEIGHT, BLADE, TIP, METAL, paint, 1.0, PI * 0.5)
	tail_rotor = _scissor(paint)


## THE SCISSOR TAIL ROTOR: a pivot on the port side of the fin whose local +Y points to port, a hub, and four blades as
## two pairs 55 degrees apart ([W]) -- blade 0 straight aft so the parked rotor reaches aft. Named as the kit names a
## rotor's parts, and turned by `RotorcraftKit.turn`, so everything that spins a rotor spins this one.
func _scissor(paint: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "TailRotor"
	pivot.position = at(-TAIL_OUT, TAIL_HUB_X, _tail_hub_y())
	var to_port := Basis(Vector3(0.0, 1.0, 0.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))
	pivot.basis = to_port
	pivot.set_meta(&"rest", to_port)
	pivot.set_meta(&"spin", 1.0)
	pivot.set_meta(&"blades", 4)
	exterior.add_child(pivot)
	var head := RotorcraftKit.tool()
	RotorcraftKit.rod(head, Vector3(0.0, -0.10, 0.0), Vector3(0.0, 0.12, 0.0), 0.10, METAL, 6)
	RotorcraftKit.part(pivot, "TailRotorHub", head, paint)
	var sweep := RotorcraftKit.tool()
	var radius: float = TAIL_ROTOR_DIAMETER * 0.5
	for phase in [-PI * 0.5, -PI * 0.5 + SCISSOR, PI * 0.5, PI * 0.5 + SCISSOR]:
		var out := Vector3(cos(phase), 0.0, -sin(phase))
		RotorcraftKit.blade(sweep, out * 0.12, out * radius, Vector3.UP, 1.0, TAIL_CHORD, TAIL_CHORD * 0.9, 0.12,
			BLADE, TIP)
	RotorcraftKit.part(pivot, "TailRotorBlades", sweep, paint)
	return pivot


# ---------------------------------------------------------------------------------------------------------------------
# THE ENGINES, THE WINGS AND THE STORES

## ONE NACELLE: eight flat facets a ring from the intake to the exhaust, the intake's face dark, and under it the fairing
## that carries it on the fuselage's shoulder; the "black hole" exhaust box turned out and down at its back.
func _nacelle(tool: SurfaceTool, side: float) -> void:
	var out: float = side * NACELLE_OUT
	var mid_y: float = (NACELLE_Y.x + NACELLE_Y.y) * 0.5
	var half_h: float = (NACELLE_Y.y - NACELLE_Y.x) * 0.5 * UNIT
	var rings: Array = []
	for step in [[NACELLE_X.x, 0.80], [NACELLE_X.x + 4.0, 1.0], [NACELLE_X.y - 12.0, 1.0], [NACELLE_X.y - 3.0, 0.85]]:
		var c: Vector3 = at(out, float(step[0]), mid_y)
		rings.append(RotorcraftKit.ring(c, Vector3.BACK, NACELLE_HALF * float(step[1]), half_h * float(step[1]), 8,
			PI / 8.0))
	RotorcraftKit.loft(tool, tool, rings, func(s: int, f: int) -> Variant:
		if s < 0:
			return DARK
		return TOP if f in [1, 2] else BODY)
	# THE FAIRING between the nacelle and the fuselage: from the upper fuselage's side into the nacelle's inner wall.
	var inner: float = side * 0.30
	var wall: float = side * (NACELLE_OUT - NACELLE_HALF * 0.6)
	var fore: float = station(NACELLE_X.x + 5.0)
	var aft: float = station(NACELLE_X.y - 8.0)
	var low: float = height(NACELLE_Y.y - 1.0)
	var high: float = height(mid_y)
	RotorcraftKit.box(tool, Vector3((inner + wall) * 0.5, (low + high) * 0.5, (fore + aft) * 0.5),
		Vector3(absf(wall - inner), high - low, aft - fore), BODY)
	# THE EXHAUST: a dark box on the nacelle's aft outboard corner, turned out.
	var exhaust: Vector3 = at(out + side * NACELLE_HALF * 0.55, NACELLE_X.y - 5.0, mid_y + 1.5)
	RotorcraftKit.box(tool, exhaust, Vector3(0.36, 0.40, 0.55), DARK, Basis(Vector3.UP, side * 0.35))


## ONE STUB WING: a slab from inside the fuselage out to [FAS]'s tip, its chord tapering from the root to the tip.
func _wing(tool: SurfaceTool, side: float) -> void:
	var tip: float = side * WING_SPAN * 0.5
	var root: float = side * 0.35
	var outline: Array[Vector3] = [at(root, WING_ROOT.x, WING_Y), at(tip, WING_TIP.x, WING_Y), at(tip, WING_TIP.y, WING_Y),
		at(root, WING_ROOT.y, WING_Y)]
	RotorcraftKit.plate(tool, outline, Vector3.UP, WING_THICK, TOP)
	# THE PYLONS under the wing, each a short fairing down to its store.
	for out in PYLONS:
		var x: float = side * float(out)
		var z: float = station((WING_ROOT.x + WING_ROOT.y) * 0.5)
		RotorcraftKit.box(tool, Vector3(x, height(WING_Y) - WING_THICK * 0.5 - 0.10, z), Vector3(0.10, 0.24, 0.9), TRIM)


## THE INBOARD PYLON'S ROCKET POD: a ten-sided tube of nineteen, its front face dark with the tubes' mouths.
func _rocket_pod(tool: SurfaceTool, side: float) -> void:
	var x: float = side * float(PYLONS[0])
	var z: float = station((WING_ROOT.x + WING_ROOT.y) * 0.5) - 0.15
	var y: float = height(WING_Y) - WING_THICK * 0.5 - 0.22 - POD_WIDE * 0.5
	var r: float = POD_WIDE * 0.5
	RotorcraftKit.loft(tool, tool, [
		RotorcraftKit.ring(Vector3(x, y, z - POD_LONG * 0.5), Vector3.BACK, r, r, 10, PI / 10.0),
		RotorcraftKit.ring(Vector3(x, y, z + POD_LONG * 0.5), Vector3.BACK, r, r, 10, PI / 10.0)],
		func(s: int, _f: int) -> Variant: return DARK if s < 0 else MISSILE)


## THE EIGHT HELLFIRES' MIDDLES, craft-local, port launcher first, top row before bottom, inboard before outboard: the
## rails the simulation launches from (`loadout_of`, lane/apache step 4) are these points, and `tests/apache.gd` holds the
## two together, so a missile leaves from the one drawn on the wing.
func hellfire_rails() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		out.append_array(_hellfire_centres(side))
	return out


func _hellfire_centres(side: float) -> Array[Vector3]:
	var x: float = side * float(PYLONS[1])
	var z: float = station((WING_ROOT.x + WING_ROOT.y) * 0.5)
	var top: float = height(WING_Y) - WING_THICK * 0.5 - 0.22
	var r: float = HELLFIRE_WIDE * 0.5
	var out: Array[Vector3] = []
	for row in [0, 1]:
		for col in [-side, side]:
			out.append(Vector3(x + col * (r + 0.09), top - 0.08 - float(row) * (HELLFIRE_WIDE + 0.08), z))
	return out


## THE OUTBOARD PYLON'S HELLFIRES: the four-rail launcher's frame and four missiles, two over two, each an eight-sided body
## with a blunt dark seeker nose and four fins.
func _hellfires(tool: SurfaceTool, side: float) -> void:
	var x: float = side * float(PYLONS[1])
	var z: float = station((WING_ROOT.x + WING_ROOT.y) * 0.5)
	var top: float = height(WING_Y) - WING_THICK * 0.5 - 0.22
	RotorcraftKit.box(tool, Vector3(x, top - 0.10, z + 0.05), Vector3(0.14, 0.24, HELLFIRE_LONG * 0.85), TRIM)
	var r: float = HELLFIRE_WIDE * 0.5
	for c in _hellfire_centres(side):
		var nose: Vector3 = c + Vector3(0.0, 0.0, -HELLFIRE_LONG * 0.5)
		RotorcraftKit.loft(tool, tool, [
			RotorcraftKit.ring(nose + Vector3(0.0, 0.0, 0.10), Vector3.BACK, r * 0.75, r * 0.75, 8, PI / 8.0),
			RotorcraftKit.ring(nose + Vector3(0.0, 0.0, 0.26), Vector3.BACK, r, r, 8, PI / 8.0),
			RotorcraftKit.ring(c + Vector3(0.0, 0.0, HELLFIRE_LONG * 0.5), Vector3.BACK, r, r, 8, PI / 8.0)],
			func(s: int, _f: int) -> Variant: return WARHEAD if s <= 0 else MISSILE)
		for fin in range(4):
			var t: float = PI * 0.25 + PI * 0.5 * float(fin)
			var dir := Vector3(cos(t), sin(t), 0.0)
			RotorcraftKit.box(tool, c + dir * (r + 0.03) + Vector3(0.0, 0.0, HELLFIRE_LONG * 0.40),
				Vector3(0.012, 0.012, 0.18) + dir.abs() * 0.07, WARHEAD)


# ---------------------------------------------------------------------------------------------------------------------
# THE GEAR AND THE CABIN

## ONE MAIN GEAR LEG: a trailing arm from under the wing's root down to the axle, and the wheel, its bottom on the ground.
func _main_gear(tool: SurfaceTool, side: float) -> void:
	var axle := Vector3(side * TRACK * 0.5, -_half.y + MAIN_WHEEL_R, station(MAIN_WHEEL_X))
	var root: Vector3 = at(side * 0.72, MAIN_WHEEL_X - 9.0, 287.0)
	RotorcraftKit.rod(tool, root, axle - Vector3(side * 0.08, 0.0, 0.0), 0.07, METAL, 6)
	# THE DRAG STRUT, from the wing's underside back down to the axle.
	RotorcraftKit.rod(tool, at(side * 0.95, WING_ROOT.y - 4.0, WING_Y + 2.0), axle - Vector3(side * 0.08, 0.0, 0.0), 0.05,
		METAL, 6)
	RotorcraftKit.rod(tool, axle - Vector3(side * 0.14, 0.0, 0.0), axle + Vector3(side * 0.02, 0.0, 0.0), 0.06, METAL, 6)
	_wheel(tool, axle, MAIN_WHEEL_R, 0.22)


## THE TAILWHEEL under the boom's end: a fork on a leg from the boom's belly, the wheel's bottom on the main wheels'
## ground -- levelled, see TAIL_WHEEL_X.
func _tail_gear(tool: SurfaceTool) -> void:
	var axle := Vector3(0.0, -_half.y + TAIL_WHEEL_R, station(TAIL_WHEEL_X))
	var boom_bottom: float = height(float(BOOM[-2][2]))
	var top := Vector3(0.0, boom_bottom + 0.05, station(TAIL_WHEEL_X - 4.0))
	RotorcraftKit.rod(tool, top, axle + Vector3(0.0, TAIL_WHEEL_R + 0.02, 0.0), 0.07, METAL, 6)
	for s in [1.0, -1.0]:
		RotorcraftKit.box(tool, axle + Vector3(s * 0.10, TAIL_WHEEL_R * 0.6, 0.0), Vector3(0.03, TAIL_WHEEL_R * 1.3, 0.10),
			METAL)
	_wheel(tool, axle, TAIL_WHEEL_R, 0.14)


## AN EIGHT-SIDED WHEEL ON A FLAT: an axle along x at `axle`, its lowest flat exactly `r` under it, so it stands on the
## ground rather than on a vertex (`lane/rotors`: a vertex floats 3 cm).
func _wheel(tool: SurfaceTool, axle: Vector3, r: float, wide: float) -> void:
	var corner: float = r / cos(PI / 8.0)
	var rings: Array = []
	for s in [-0.5, 0.5]:
		var ring := PackedVector3Array()
		for k in range(8):
			var t: float = TAU * (float(k) + 0.5) / 8.0
			ring.append(axle + Vector3(wide * s, sin(t) * corner, cos(t) * corner))
		rings.append(ring)
	RotorcraftKit.loft(tool, tool, rings, func(_s: int, _f: int) -> Variant: return DARK)


## THE COCKPIT FLOORS, one per seat at its footwell (the seat's anchor plus `CockpitStation.FLOOR`), from the cheek bay's
## wall to wall, and the step between them -- the drawing's two tubs, the gunner's low and the pilot's high.
func _cabin(tool: SurfaceTool) -> void:
	var eyes: Array[Vector3] = crew_eyes()
	for seat in range(2):
		var floor_y: float = eyes[seat].y - CockpitStation.EYE_HEIGHT + CockpitStation.FLOOR
		var r: Array = ROOMS[seat]
		var fore: float = station(float(r[0]) - 3.0)
		var aft: float = station(float(r[1]) + 1.0)
		RotorcraftKit.box(tool, Vector3(0.0, floor_y - 0.03, (fore + aft) * 0.5), Vector3(ROOM_HALF * 2.0 + 0.1, 0.06,
			aft - fore), FLOOR)
	# THE GUNNER'S FRONT BULKHEAD AND GLARESHIELD, where the real CPG's instrument panel stands: wall to wall across the
	# cockpit at the canopy's front bow, from his floor up to the nose's top line, with a shelf over it. WITHOUT IT THE
	# COCKPIT WAS OPEN DOWN THE NOSE, and from his eye the back of the TADS drum filled the lower middle of the view
	# (team-lead, picture 05). It stops at the nose's top, which he looks over, so it takes nothing from any sightline.
	# FIVE PX AHEAD OF THE BOW, under the nose's roof: at the bow its shelf stood 0.34 m ahead of a seated knee, against
	# `seat_room`'s 0.55, and the knees are the one clearance a panel in front of a seat takes.
	var at_x: float = CANOPY_X.x - 5.0
	var bow: float = station(at_x)
	var floor_g: float = eyes[1].y - CockpitStation.EYE_HEIGHT + CockpitStation.FLOOR
	var top: float = height(float(_row_at(at_x)[3]) - 0.5)
	var wide: float = float(_row_at(at_x)[2]) * 2.0 - 0.04
	RotorcraftKit.box(tool, Vector3(0.0, (floor_g + top) * 0.5, bow + 0.03), Vector3(wide, top - floor_g, 0.06), TRIM)
	RotorcraftKit.box(tool, Vector3(0.0, top - 0.02, bow + 0.10), Vector3(wide, 0.04, 0.20), FLOOR)
