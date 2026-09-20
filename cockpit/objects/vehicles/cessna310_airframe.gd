extends Node3D
class_name Cessna310Airframe
## A CESSNA 310R, DRAWN: the long baggage nose the R is named for, a four-to-six seat cabin under a wrapped windscreen
## and four side windows, two nacelles carrying 285 hp Continentals with three-blade propellers, a low tapered wing with
## five degrees of dihedral, the CANTED TIP TANKS everybody recognises a 310 by, a swept fin over a dorsal fillet, a low
## stabiliser on the tailcone, and retractable tricycle gear that folds into the nacelles and the nose.
## Presentation only: native CockpitWorld owns flight, collision, stations and replication.
##
## ORIGINAL GEOMETRY, MEASURED. No third-party mesh, photograph, texture, trademark or livery is incorporated: the
## references were studied and measured and nothing was copied. Every figure names its source, and `craft/plane/sources.md`
## holds the licences. `craft/plane/measure_310l.py` re-derives every MEASURED figure from the drawing alone, reading
## nothing out of the write-up, so the two can disagree and one of them be wrong.
## - [L] the "PRINCIPAL DIMENSIONS" page of the 1967 Cessna Model 310L Owner's Manual (D436-13) on Wikimedia Commons,
##   public domain through a defective US copyright notice. A factory three-view with eight printed dimensions on it.
##   Measured at 80.705 px/m across (front), 81.802 along (side), 80.654 across and 81.743 fore-and-aft (plan).
## - [TCDS] FAA Type Certificate Data Sheet 3A10 Rev 63, US Government, public domain. Section XXII is the 310R:
##   two Continental IO-520-M/MB at 285 hp, a three-blade McCauley of 74.5 to 76.5 in, 5,500 lb takeoff, Vne 223 KIAS,
##   **51 US gal in each tip tank at arm +35 in**, and the R's **350 lb nose baggage at station -31 in** -- an entry the
##   310Q's section does not have at all, which is the lengthened nose in a public-domain document.
## - [RR] and [AOPA] the 310R's published envelope: 9.74 m long, 11.25 m span, 179 sq ft of wing, 3,358 lb empty.
## - [OO-MSN] Ad Meskens, "Antwerp Cessna 310R OO-MSN.jpg" on Commons, CC BY-SA 3.0, STUDIED ONLY: a near broadside of a
##   parked 310R. It settles the stance and shows the tip tank's tail.
## ESTIMATE marks a figure no reference gives.
##
## ----------------------------------------------------------------------------------------------------------------
## WHY AN L DRAWING IS EVIDENCE FOR AN R, and it is not a shortcut
## ----------------------------------------------------------------------------------------------------------------
## [TCDS] lists the tip tanks as **51 US gal at arm +35 in on every model from the 310J through the 310R** -- eleven
## models, one tank, one station. The wing, the tanks, the fin and the tailplane did not change; the R added a 0.748 m
## baggage nose, three-blade propellers and a deeper rear cabin window. So the L sheet is measured for everything aft of
## the firewall and the nose is drawn to the R's published length, which is `lane/liners`' "a stretched variant's drawing
## can scale its parent" run backwards. Where the R and the L differ, this file says so per constant.
##
## ----------------------------------------------------------------------------------------------------------------
## A 310 PARKS NOSE-UP, AND EVERY NUMBER HERE IS IN THE LEVEL FRAME THE DRAWING USES
## ----------------------------------------------------------------------------------------------------------------
## [L] draws the aeroplane LEVEL and rakes the GROUND under it: its wing's lower line is horizontal to the pixel and a
## Hough sweep of its dark ink finds one family of long straight lines at exactly -4.500 degrees, the printed 4 deg
## 30 min. **In the craft's own frame the nose tyre hangs 0.228 m below the mains**, so on flat ground a 310 stands
## 4.5 degrees nose-up. Three readings agree and none saw the others: the side view's two tyre bottoms (0.228 m), the
## front view's ground pads, which put the nose wheel's 19.5 px below the mains' (0.242 m), and [OO-MSN]'s cheat line
## falling aft. Reading the convention the other way buries the nose wheel, which is the P-38's 26 cm
## (`todo/warbirds--p38-lightning.md`).
##
## So geometry is authored as the drawing draws it -- `s` metres aft of the NOSE TIP, `h` metres over the plane the main
## tyres stand on, `x` metres to starboard -- and **`at()` is the only place the rake is applied**. One number, one
## place: change `GEAR_RAKE` and the whole aeroplane leans, the tyres stay on the ground, and `tests/twin310.gd` can
## still find all three of them on one plane, because that is arithmetic rather than a typed height.
##
## ----------------------------------------------------------------------------------------------------------------
## HOW TALL IT IS, AND WHY THAT IS NOT THE PUBLISHED 10 ft 7 in
## ----------------------------------------------------------------------------------------------------------------
## [AOPA] gives the 310R 10 ft 7 in and [RR] 10 ft 8 in. [L] prints **9 ft 11.25 in (3.029 m)** for the normal attitude
## and, in a note beside it, **10 ft 8.75 in (3.270 m) with the nose gear depressed**, plus 3 in for a rotating beacon.
## The R's published height is the DEPRESSED figure to within an inch, and the fin did not grow between the L and the R.
## Measured off [L] the normal height is 3.067 m, +1.25 per cent on its own printed 3.029. This model stands at
## **3.03 m** and `craft/plane/sources.md` says why -- the same call `craft/cessna/sources.md` makes about Textron's
## 2.72 m, which is also a maximum nothing reproduces.
##
## ----------------------------------------------------------------------------------------------------------------
## IT IS FACETED ON PURPOSE. DO NOT SUBDIVIDE IT.
## ----------------------------------------------------------------------------------------------------------------
## "Let's keep a somewhat lower poly look to models, not too many very round edges, this will keep a better 'old school
## feel' to things" (the user, 2026-09-17), with `hawkeye_airframe.gd` as the named reference. The counts are the whole
## of it: THREE points to a quarter of a fuselage section (a fourteen-sided ring) over twenty-five measured rows, SIX
## cuts along a chord, EIGHT sides to a tyre and a spinner, TEN sides to a tip tank, FOUR to a leg or a rod, TWENTY to a
## propeller disc, and NO smooth groups anywhere -- the reference airframe sets none either. What is coarse is the
## TESSELLATION; every measured dimension, station and clearance stays exactly as measured, and `tests/twin310.gd`
## holds the triangle count under a budget that would not survive smoothing it.

## ---- the envelope ---------------------------------------------------------------------------------------------

const LENGTH := 9.74            # [RR][AOPA] 32 ft 0 in, nose tip to the rudder's top trailing corner
const SPAN := 11.25             # [RR], and [L]'s own printed 36 ft 11 in over the tip tanks
const HEIGHT := 3.03            # [L] 9 ft 11.25 in, normal attitude; see the doc block
const PUBLISHED_HEIGHT := 3.25  # [RR] 10 ft 8 in -- the nose-gear-depressed maximum
const L_LENGTH := 8.9916        # [L] 29 ft 6 in
const NOSE_PLUG := 0.7484       # LENGTH - L_LENGTH: what the R's baggage nose adds ahead of the firewall

## THE STANCE [L]. `GEAR_RAKE` is the printed 4 deg 30 min, found again by Hough at -4.500. `NOSE_DROP` is what that
## angle costs the nose tyre over the wheelbase and is DERIVED, never typed beside it: a drop typed next to an angle is
## exactly the pair that goes out of step.
const GEAR_RAKE := 0.0785398    # 4.5 degrees, nose up on flat ground
const WHEELBASE := 2.90         # [L] printed 9 ft 6.75 in (2.915), drawn 2.880
const TRACK := 3.67             # [L] printed 12 ft 0 in (3.658), drawn 3.682
const NOSE_AXLE_S := 1.01       # [L] 0.26 plus the nose plug
const MAIN_AXLE_S := NOSE_AXLE_S + WHEELBASE
const MAIN_TYRE_R := 0.22       # [L] the drawn main tyre, 0.575 m across the strut fairing
const MAIN_TYRE_WIDE := 0.15
const NOSE_TYRE_R := 0.17       # [L] 0.465 m across
const NOSE_TYRE_WIDE := 0.12

## THE PROPELLERS. [TCDS] gives the R a three-blade McCauley of not over 76.5 in and not under 74.5; [L]'s own two-blade
## disc measures 2.085 and 2.036 m against a printed 6 ft 9 in -- those two circles, fitted to 160 arc points at 0.31 px
## rms, are the only true circles on the page and are how the front view was shown to be isotropic to one per cent.
const PROP_DIAMETER := 1.943    # [TCDS] 76.5 in
const ENGINE_X := 1.863         # [L] the two disc centres, 3.726 m apart
const PROP_S := 0.80            # [L] 0.05 plus the nose plug: the disc stands just ahead of the nacelle
const THRUST_H := 1.214         # [L] the disc centres over the mains' contact plane
const SPINNER_LENGTH := 0.34
const SPINNER_RADIUS := 0.155

## THE WING [L], fitted over 43 stations outboard of the nacelle at 51 mm rms -- never through two ends. The chord falls
## 0.1701 m a metre of half span; the leading edge sweeps 2.25 degrees aft and the trailing edge 7.45 forward, so a 310's
## taper is mostly in its trailing edge. Dihedral is the mean of 4.83 and 5.07 degrees fitted over 131 and 136 stations
## at 3 mm rms, which is 5.0 to the nearest tenth and is what a 310's books give.
const WING_CHORD_ROOT := 2.033      # the fit's value on the centreline
const WING_CHORD_FALL := 0.1701     # metres of chord lost per metre of half span
const WING_LE_ROOT := 2.948         # station of the leading edge on the centreline, R frame
const WING_LE_SWEEP := 0.0393       # metres aft per metre out (2.25 degrees)
const WING_ROOT_H := 0.91           # [L] the mid-chord line's height on the centreline
const DIHEDRAL := 0.0875            # metres of rise per metre out (5.0 degrees)
const WING_SIDE_X := 0.60           # where the wing leaves the fuselage side
const WING_TIP_X := 5.09            # where it meets the tip tank's inner face
const ROOT_INCIDENCE := 0.0384      # 2.2 degrees, ESTIMATE
const TIP_INCIDENCE := -0.0175      # -1.0 degrees of washout, ESTIMATE

## THE TIP TANKS, which is what the aeroplane is recognised by and what this lane was asked for. [L] draws each one
## 3.071 m long against a printed 10 ft 0 in (+0.74 per cent), 0.533 m wide in plan at its widest row and 0.46 m deep
## end on, centred 5.345 m off the axis -- so its outer face carries the 11.25 m span with 0.27 m to spare.
## **IT HAS NO FIN.** The brief that asked for this aeroplane said the tanks carry one; [L]'s plan and front views draw
## none, and a native-resolution crop of [OO-MSN] shows the starboard tank ending in a bare cone with the nav light on
## it. What makes the tank read as a 310's is the CANT: measured in plan it has almost no toe (1.13 degrees at 3 px rms,
## which is nothing), and [OO-MSN] shows its tail standing proud of the wing, so the cant is a DROOP about the wing tip
## -- nose down and a little out. A cylinder bolted on straight is the thing this must not be.
const TANK_X := 5.345
const TANK_LENGTH := 3.071
const TANK_NOSE_S := 2.178          # [L] 1.43 plus the nose plug
const TANK_WIDE := 0.533
const TANK_DEEP := 0.46
const TANK_H := 1.50                # its axis at mid length, over the mains' contact plane
## THE CANT IS SMALL, AND THE FRONT VIEW IS WHAT BOUNDS IT. A tank drooped by an angle shows an
## end-on silhouette taller than its own section by its length times the sine of that angle. [L]'s
## front view draws the tank 0.570 m across by 0.520 m deep against a section measured 0.533 by 0.46
## in plan, so the droop cannot exceed (0.520 - 0.46) / 3.071 -- about ONE DEGREE -- and the toe
## cannot exceed 0.7. A six-degree droop, which is what the reputation suggests and what this model
## was first drawn with, would have made that silhouette 0.78 m tall, and it is not. The plan view
## measures the toe directly at 1.13 degrees over 67 rows at 3.1 px rms.
## So a 310's famously CANTED tanks are canted about a degree and a half in all, and what makes them
## read as a 310's is their SIZE AND PLACE -- 3.07 m of tank reaching 0.97 m ahead of the wing's
## leading edge and 0.93 m behind its trailing edge -- rather than an angle. Drawing the reputation
## instead of the measurement would have put them five degrees out and looked deliberate.
const TANK_DROOP := 0.0262          # 1.5 degrees nose down: at the front view's bound, ESTIMATE
const TANK_TOE := 0.0197            # 1.13 degrees, nose outboard: MEASURED off [L]'s plan view
const TANK_GALLONS := 51.0          # [TCDS], unchanged from the 310J through the 310R

## THE NACELLES [L]: on the propellers' own centreline, from station 1.36 to 5.31 in the R frame, 0.85 m across and
## 0.90 m deep, with the mains folding up into their aft halves.
const NACELLE_FORE := 1.358
const NACELLE_AFT := 5.308
const NACELLE_WIDE := 0.85
const NACELLE_DEEP := 0.90
const NACELLE_H := 1.10

## THE TAIL [L]: the stabiliser's printed 17 ft 0 in span on the tailcone, not on the fin, and a swept fin over a long
## dorsal fillet. Heights are in the level frame, so the fin's top stands at 3.50 there and measures 3.03 over the
## ground once the aeroplane is parked -- which is the whole point of authoring level.
const STAB_SPAN := 5.182            # [L] printed 17 ft 0 in; its drawn tips measure 5.31 (+2.5%)
const STAB_ROOT_LE := 8.23          # [L] 7.48 plus the nose plug
const STAB_ROOT_CHORD := 0.92
const STAB_TIP_CHORD := 0.49
const STAB_LE_SWEEP := 0.031        # metres aft per metre out, so 1.8 degrees
const STAB_H := 2.03
const STAB_DIHEDRAL := 0.0
## THE FIRST READING OF THIS TAILPLANE WAS A 1.9 m ROOT CHORD, which over a 17 ft span is 8.8 m2 of
## horizontal tail -- half the wing's area. A column scan of the plan view had swallowed the 17 ft
## DIMENSION LINE, drawn a centimetre above the stabiliser's own trailing edge, and the distance from
## a dimension line to a leading edge looks exactly like a chord. What caught it was arithmetic the
## drawing cannot argue with: a tail that size does not fly. Ask a measurement for something it
## implies -- an area, a ratio -- before believing the measurement.

const FIN_ROOT_S := 7.86
const FIN_ROOT_H := 1.95
const FIN_TIP_LE_S := 9.10
const FIN_TOP_H := 3.50             # level frame; 3.03 over the ground once parked
const FIN_TIP_TE_S := 9.74
const RUDDER_HINGE := [Vector2(8.86, 2.02), Vector2(9.30, 3.47)]   # (station, height)
const FIN_THICK := 0.09
const DORSAL_FROM := 7.06

## THE CABIN [L], and its glass. The fuselage is 1.32 m across and 1.49 m deep at the widest station, which against
## [AOPA]'s 4 ft cabin leaves the lining a hand's width of skin. Window stations are ESTIMATES off [L]'s side view and
## the [OO-MSN] and G-BGTT photographs; the deep aft window is the R's own.
## AND EVERY WINDOW EDGE IS A SECTION ROW. The skin is glazed by RING PAIR, so a post between two
## windows that is narrower than the spacing of the rows either side of it is not drawn at all --
## and the first build's four windows came out as one continuous ribbon from the windscreen to the
## rear cabin, 3.1 m of unbroken glass, while every dimension check stayed green. The rows below at
## 3.24/3.36, 4.08/4.20 and 4.86/4.98 are the three posts.
const WINDSCREEN := Vector2(2.55, 3.24)
const DOOR_WINDOW := Vector2(3.36, 4.08)
const MID_WINDOW := Vector2(4.20, 4.86)
const AFT_WINDOW := Vector2(4.98, 5.64)
const CABIN_FLOOR := 1.03
const CABIN_ROOF := 2.15
const DOOR := Rect2(3.36, 1.05, 0.86, 1.12)     # (station, height, along, up): the starboard airstair door
const NOSE_DOOR := Rect2(0.62, 1.00, 0.62, 0.46)

## THE ROOM THIS AEROPLANE PROMISES ROUND ITS CREW. Conservative on every face: every point inside it is inside the
## drawn skin, and a point outside it may or may not be. See `cabin_room()`.
const ROOM_HALF := 0.56
const ROOM_FLOOR := 1.12
const ROOM_ROOF := 2.06
const ROOM_FORE := 2.76
const ROOM_AFT := 5.50

## THE TRAVELS [TCDS] section XXII, radians. Flaps down 35 degrees; ailerons 20 up and 20 down; elevator 20 up and
## 20 down; rudder 29.3 degrees either way. The tab travels are the R's own rows in the same table.
const FLAP_TRAVEL := 0.610865       # 35 degrees
const AILERON_UP := 0.349066        # 20 degrees
const AILERON_DOWN := 0.349066
const ELEVATOR_UP := 0.349066       # 20 degrees
const ELEVATOR_DOWN := 0.349066
const TAB_UP := 0.174533            # 10 degrees
const TAB_DOWN := 0.453786          # 26 degrees
const RUDDER_TRAVEL := 0.511382     # 29.3 degrees

const FLAP_X := Vector2(0.66, 2.62)
const AILERON_X := Vector2(2.72, 5.02)
const FLAP_CHORD := 0.42
const AILERON_CHORD := 0.40
const ELEVATOR_CHORD := 0.32
const HINGE_GAP := 0.02

## THE GEAR'S TRAVEL, drawn: the mains swing aft and up into the nacelles and the nose leg forward into the nose, which
## is the way a 310's electric gear folds. ESTIMATE of the sweep; [TCDS] publishes no gear kinematics.
const MAIN_GEAR_SWING := 1.51       # 86.5 degrees
const NOSE_GEAR_SWING := -1.48      # 85 degrees, forward

## THE PROPELLER, DRAWN: turning at a readable fixed rate rather than a true 2,700 rpm, which at any frame rate aliases
## into a stopped propeller. The disc fades in with the throttle and the blades give way to it. ESTIMATE of the look.
const PROP_TURNS := 2.5
const PROP_PARKED := 0.32
const DISC_ALPHA := 0.30
const DISC_FROM := Vector2(0.15, 0.55)

const WHITE := Color(0.92, 0.92, 0.91)
const UNDER := Color(0.85, 0.86, 0.87)
const TRIM := Color(0.13, 0.26, 0.55)   # ESTIMATE: a cheat line, the only livery drawn
const SEAM := Color(0.50, 0.51, 0.52)
const DARK := Color(0.05, 0.05, 0.055)
const METAL := Color(0.38, 0.38, 0.39)
const TYRE := Color(0.06, 0.06, 0.06)
const CABIN := Color(0.46, 0.46, 0.47)
const PANEL := Color(0.09, 0.09, 0.10)
const BLADE := Color(0.10, 0.10, 0.11)
const BLADE_TIP := Color(0.90, 0.90, 0.88)

## THE FUSELAGE, station by station: [s, half-width, top, bottom, squareness]. Half-widths are [L]'s plan view and the
## tops and bottoms its side view, both in the level frame, with the nose redrawn to the R's published length. The
## squareness is the superellipse exponent: 2.0 is an ellipse and higher is a rounded box, which is what a 310's cabin
## section is. TWENTY-FIVE ROWS AND FOURTEEN POINTS TO A RING: see the doc block before adding either.
const SECTIONS: Array = [
	[0.00, 0.055, 1.300, 1.100, 2.0],
	[0.35, 0.225, 1.420, 0.960, 2.1],
	[0.75, 0.360, 1.520, 0.862, 2.2],
	[1.15, 0.462, 1.600, 0.800, 2.3],
	[1.60, 0.548, 1.680, 0.762, 2.4],
	[2.05, 0.602, 1.780, 0.750, 2.5],
	[2.55, 0.636, 1.950, 0.750, 2.6],
	[2.90, 0.651, 2.117, 0.753, 2.6],
	[3.24, 0.659, 2.220, 0.758, 2.6],
	[3.36, 0.659, 2.246, 0.760, 2.6],
	[3.72, 0.660, 2.277, 0.778, 2.6],
	[4.08, 0.657, 2.257, 0.800, 2.6],
	[4.20, 0.655, 2.245, 0.809, 2.6],
	[4.53, 0.648, 2.199, 0.838, 2.5],
	[4.86, 0.634, 2.154, 0.887, 2.5],
	[4.98, 0.628, 2.138, 0.906, 2.5],
	[5.31, 0.603, 2.090, 0.972, 2.4],
	[5.64, 0.565, 2.046, 1.040, 2.3],
	[5.90, 0.529, 2.021, 1.096, 2.3],
	[6.25, 0.470, 1.990, 1.160, 2.2],
	[6.75, 0.392, 1.962, 1.270, 2.1],
	[7.25, 0.312, 1.944, 1.390, 2.0],
	[7.75, 0.238, 1.950, 1.520, 2.0],
	[8.40, 0.160, 1.978, 1.660, 2.0],
	[9.05, 0.092, 2.010, 1.800, 2.0],
]
const QUARTER := 3

## Small fittings stop drawing once the whole aircraft is a few pixels high, with hysteresis; Mobile has no fade.
const DETAIL_RANGE := 350.0
const DETAIL_HYSTERESIS := 40.0

var exterior: Node3D
var interior: Node3D
## Every separately-drawn surface's bounds in the model's frame, by name, as its vertices were emitted.
var surfaces: Dictionary = {}
var _rest: float = 0.70
var _flaps: float = 0.0
var _trim: float = 0.0
var _roll: float = 0.0
var _pitch: float = 0.0
var _yaw: float = 0.0
var _gear: float = 1.0
var _prop_handed: Dictionary = {"turning": false, "throttle": 0.0, "seconds": 0.0}
var _hinges: Dictionary = {}


func _ready() -> void:
	if get_child_count() == 0:
		_build()


func show_layers(show_exterior: bool, show_interior: bool) -> void:
	if exterior != null: exterior.visible = show_exterior
	if interior != null: interior.visible = show_interior


## ---- the parked frame -----------------------------------------------------------------------------------------

## THE ONE PLACE THE RAKE IS APPLIED. `x` is metres to starboard, `h` metres over the plane the MAIN tyres stand on and
## `s` metres aft of the nose tip, all as [L] draws them with the aeroplane level. The result is the craft's own frame:
## metres, +Y up, -Z forward, origin at the middle of the native hull.
##
## The aeroplane is turned nose-up about the main gear's contact line, then dropped so that line rests on the ground the
## native hull rests on -- `_rest` under the origin. Do that and the NOSE tyre lands on the same ground without being
## told to, because `NOSE_DROP` is `GEAR_RAKE` times the wheelbase rather than a second number typed beside it.
## `tests/twin310.gd` asserts all three tyre bottoms are on one plane, which is a real check only because of that.
func at(x: float, h: float, s: float) -> Vector3:
	var along: float = s - MAIN_AXLE_S
	var c: float = cos(GEAR_RAKE)
	var t: float = sin(GEAR_RAKE)
	return Vector3(x, h * c - along * t - _rest, h * t + along * c + MAIN_AXLE_S - LENGTH * 0.5)


## How far the nose tyre hangs below the mains in the level frame: DERIVED from the rake and the wheelbase.
static func nose_drop() -> float:
	return WHEELBASE * tan(GEAR_RAKE)


## THE PARKED ATTITUDE, published so a check, a shot or a level can ask instead of guessing.
func parked() -> Dictionary:
	return {
		"rake": GEAR_RAKE,
		"nose_up": true,
		"nose_drop": nose_drop(),
		"wheelbase": WHEELBASE,
		"rest": _rest,
		"source": "[L] printed 4 deg 30 min, found again by Hough at -4.500; craft/plane/measure_310l.py",
	}


## THE GROUND UNDER A STATION in the level frame: zero at the mains, falling forward to the nose tyre.
static func ground_at(s: float) -> float:
	return (s - MAIN_AXLE_S) * tan(GEAR_RAKE)


## ---- the wing's own arithmetic --------------------------------------------------------------------------------

static func wing_chord(x: float) -> float:
	return WING_CHORD_ROOT - WING_CHORD_FALL * absf(x)


static func wing_leading_edge(x: float) -> float:
	return WING_LE_ROOT + WING_LE_SWEEP * absf(x)


static func wing_trailing_edge(x: float) -> float:
	return wing_leading_edge(x) + wing_chord(x)


static func wing_height(x: float) -> float:
	return WING_ROOT_H + DIHEDRAL * absf(x)


static func _incidence(x: float) -> float:
	return lerpf(ROOT_INCIDENCE, TIP_INCIDENCE, clampf(absf(x) / WING_TIP_X, 0.0, 1.0))


## A NACA 23012's thickness and camber, to the two terms a faceted model can show: 12 per cent thick with the crest a
## third of the way back. ESTIMATE of the section; [TCDS] does not name one for the 310.
static func _thickness(c: float) -> float:
	return 0.12 * (1.0 - pow(absf(c * 2.0 - 0.66) / 1.34, 1.6))


static func _camber(c: float) -> float:
	return 0.018 * sin(PI * pow(clampf(c, 0.0, 1.0), 0.72))


## A point on the wing: `x` metres to starboard, `c` the fraction of the chord aft of the leading edge, `face` +1 for the
## upper surface and -1 for the lower.
func _wing_point(side: float, x: float, c: float, face: float) -> Vector3:
	var out: float = absf(x)
	var chord: float = wing_chord(out)
	var s: float = wing_leading_edge(out) + c * chord
	var half: float = _thickness(c) * chord * 0.5
	var mid: float = _camber(c) * chord
	var twist: float = (c - 0.25) * chord * _incidence(out)
	return at(side * out, wing_height(out) + mid + face * half - twist, s)


## ---- building it ----------------------------------------------------------------------------------------------

func _build() -> void:
	var native: Dictionary = Sim.geometry_of(Sim.Kind.PLANE)
	_rest = float((native.get("extents", Vector3(0.75, 0.70, 3.20)) as Vector3).y)
	exterior = Node3D.new(); exterior.name = "Exterior"; add_child(exterior)
	interior = Node3D.new(); interior.name = "Interior"; add_child(interior)
	var paint := _paint(false)
	var glass := StandardMaterial3D.new()
	# LIGHT ENOUGH TO READ AS GLASS. At 0.10, 0.16, 0.20 over a dark lining the cabin came back as a
	# black box in every render -- a pane and a hole look the same when both are nearly black.
	glass.albedo_color = Color(0.42, 0.52, 0.56, 0.42)
	glass.roughness = 0.06
	glass.metallic = 0.35
	glass.emission_enabled = true
	glass.emission = Color(0.30, 0.38, 0.42)
	glass.emission_energy_multiplier = 0.25
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED

	var body := _tool()
	var windows := _tool()
	var lining := _tool()
	_fuselage(body, windows, lining)
	_dorsal(body)
	_fin(body)
	# THE WING AND THE STABILISER ARE THEIR OWN MESHES, not part of the body's. A lifting surface
	# buried in one airframe mesh cannot be measured: the area check below had to sample chords at
	# stations, and a slab cut spanwise every two metres has vertices at six of them, so it
	# integrated 18 of 40 stations and read 7.73 m2 for a 16.26 m2 wing. With the wing in a mesh of
	# its own, the planform is the sum of its triangles projected on the plan, which is the wing
	# itself rather than a sample of it.
	for side in [1.0, -1.0]:
		var end: String = "Starboard" if side > 0.0 else "Port"
		var panel := _tool()
		_wing(panel, side)
		_add(exterior, "Wing" + end, panel, paint, false)
		var tail := _tool()
		_stabiliser(tail, side)
		_add(exterior, "Stabiliser" + end, tail, paint, false)
		_nacelle(body, side)
		_tip_tank(body, side)
	_add(exterior, "Airframe", body, paint, false)
	var glazing := _add(exterior, "Glazing", windows, glass, false)
	glazing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cabin(lining)
	var cabin := _add(interior, "Cabin", lining, paint, false)
	cabin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var details := _tool()
	_details(details)
	var fittings := _add(exterior, "Details", details, paint, true)
	fittings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_legs(paint)
	_moving_surfaces(paint)
	_propellers(paint)
	set_propeller(false, 0.0, 0.0)
	set_gear(1.0)


## ---- the fuselage ---------------------------------------------------------------------------------------------

## One section's starboard half as a superellipse, from the top centre down to the bottom centre.
static func _half(row: Array) -> Array[Vector2]:
	var w: float = row[1]
	var top: float = row[2]
	var bottom: float = row[3]
	var n: float = row[4]
	var mid: float = (top + bottom) * 0.5
	var deep: float = (top - bottom) * 0.5
	var half: Array[Vector2] = []
	for i in range(QUARTER * 2 + 1):
		var a: float = PI * 0.5 - PI * float(i) / float(QUARTER * 2)
		var cs: float = cos(a)
		var sn: float = sin(a)
		half.append(Vector2(w * pow(absf(cs), 2.0 / n) * signf(cs) if cs != 0.0 else 0.0,
			mid + deep * pow(absf(sn), 2.0 / n) * signf(sn)))
	return half


## A section as a closed ring: top centre, down the starboard side, bottom centre, up the port side.
func _ring(row: Array) -> Array[Vector3]:
	var s: float = float(row[0])
	var half := _half(row)
	var ring: Array[Vector3] = []
	for point in half:
		ring.append(at(point.x, point.y, s))
	for index in range(half.size() - 2, 0, -1):
		ring.append(at(-half[index].x, half[index].y, s))
	return ring


## A section's value at any station, linearly between rows: 1 half-width, 2 top, 3 bottom, 4 squareness.
static func section_at(s: float, column: int) -> float:
	for i in range(SECTIONS.size() - 1):
		var a: Array = SECTIONS[i]
		var b: Array = SECTIONS[i + 1]
		if s <= float(b[0]) or i == SECTIONS.size() - 2:
			var t: float = clampf((s - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0)
			return lerpf(float(a[column]), float(b[column]), t)
	return 0.0


func _fuselage(skin: SurfaceTool, windows: SurfaceTool, lining: SurfaceTool) -> void:
	var rings: Array = []
	for row in SECTIONS:
		rings.append(_ring(row))
	var count: int = (rings[0] as Array).size()
	for i in range(rings.size() - 1):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		var s0: float = float((SECTIONS[i] as Array)[0])
		var s1: float = float((SECTIONS[i + 1] as Array)[0])
		for k in range(count):
			var k2: int = (k + 1) % count
			# THE CHEAT LINE IS A SEAM AT THE WAIST, not a band of the loft. Tinting ring quads by
			# index put it on the KEEL, because on a twelve-point ring the panels either side of
			# `QUARTER + 3` are the bottom ones -- a blue stripe down the underside that looked
			# deliberate in every render until the plan view showed where it was.
			var tint: Color = WHITE if k < count / 2 else UNDER
			var into: SurfaceTool = windows if _pane(k, count, s0, s1) else skin
			_quad(into, a[k], a[k2], b[k2], b[k], _out(a[k], a[k2], b[k2]), tint)
	# The nose cone and the tail cone close the loft, so the aeroplane is one solid and a ray fired
	# up or down through it crosses an odd number of surfaces.
	var nose: Array = rings[0]
	var tip: Vector3 = at(0.0, (float((SECTIONS[0] as Array)[2]) + float((SECTIONS[0] as Array)[3])) * 0.5, -0.02)
	for k in range(count):
		_tri(skin, tip, nose[k], nose[(k + 1) % count], Vector3.FORWARD, WHITE)
	var tail: Array = rings[rings.size() - 1]
	var last: Array = SECTIONS[SECTIONS.size() - 1]
	var cone: Vector3 = at(0.0, (float(last[2]) + float(last[3])) * 0.5, float(last[0]) + 0.10)
	for k in range(count):
		_tri(skin, cone, tail[k], tail[(k + 1) % count], Vector3.BACK, UNDER)
	_record("Fuselage", rings)


## WHICH RING QUADS ARE A WINDOW, and this is the one thing the first build got badly wrong to look
## at. A 310's cabin is glazed from the shoulder to just under the roof line -- TWO of the six
## panels down each side -- and the first draft glazed three of six plus the crown, so half the
## fuselage's circumference was glass. In a picture that is not a cabin with windows in it; it is a
## black box where the aeroplane should be, and every dimension check stayed green through it.
##
## A ring of 2 * QUARTER + 1 half-points closes to `count` = 4 * QUARTER points. With QUARTER at 3
## that is twelve: 0 is the crown, 1 to 5 run down the starboard side (60, 30, 0, -30, -60 degrees),
## 6 is the keel, and 7 to 11 come back up the port side. Quad `k` spans point `k` to `k + 1`.
## - the SIDE WINDOWS are quads 1 and 2 to starboard (60 to 30 and 30 to 0 degrees) and their port
##   mirrors, 9 and 10;
## - the WINDSCREEN takes those and the crown quads 0 and 11, because a 310's screen wraps over the
##   coaming. Sitting glass ON a roof instead leaves a pilot looking over a sill at chin height
##   (`modelling_here.md` section 9).
static func _pane(k: int, count: int, s0: float, s1: float) -> bool:
	var mid: float = (s0 + s1) * 0.5
	var side: bool = k == 2 or k == count - 3
	var crown: bool = k == 0 or k == 1 or k == count - 1 or k == count - 2
	if mid >= WINDSCREEN.x and mid <= WINDSCREEN.y:
		return side or crown
	for pane in [DOOR_WINDOW, MID_WINDOW, AFT_WINDOW]:
		if mid >= pane.x and mid <= pane.y:
			return side
	return false


static func _out(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return (b - a).cross(c - a).normalized()


## THE DORSAL FILLET, which on a 310 runs most of the tailcone's length and is a silhouette cue in its own right.
func _dorsal(tool: SurfaceTool) -> void:
	var rows: Array[Vector2] = [Vector2(DORSAL_FROM, 0.0), Vector2(7.40, 0.04), Vector2(FIN_ROOT_S, 0.0)]
	var last: Vector2 = Vector2(DORSAL_FROM, section_at(DORSAL_FROM, 2))
	for i in range(1, 9):
		var s: float = lerpf(DORSAL_FROM, FIN_ROOT_S, float(i) / 8.0)
		var crown: float = section_at(s, 2)
		var rise: float = FIN_ROOT_H * pow(clampf((s - DORSAL_FROM) / (FIN_ROOT_S - DORSAL_FROM), 0.0, 1.0), 2.2)
		var high: float = maxf(crown, lerpf(crown, FIN_ROOT_H, pow((s - DORSAL_FROM) / (FIN_ROOT_S - DORSAL_FROM), 2.0)))
		var prev_high: float = maxf(section_at(last.x, 2),
			lerpf(section_at(last.x, 2), FIN_ROOT_H,
				pow((last.x - DORSAL_FROM) / (FIN_ROOT_S - DORSAL_FROM), 2.0)))
		for face in [1.0, -1.0]:
			_quad(tool, at(0.0, last.y, last.x), at(0.0, prev_high, last.x), at(face * FIN_THICK * 0.5, high, s),
				at(face * FIN_THICK * 0.5, section_at(s, 2), s), Vector3(face, 0.3, 0.0), WHITE)
		last = Vector2(s, section_at(s, 2))
	surfaces["Dorsal"] = AABB(at(-FIN_THICK, section_at(DORSAL_FROM, 3), DORSAL_FROM),
		at(FIN_THICK, FIN_ROOT_H, FIN_ROOT_S) - at(-FIN_THICK, section_at(DORSAL_FROM, 3), DORSAL_FROM))


## THE FIN AND ITS RUDDER, swept, with the top edge running aft and up as [L] draws it. The height contract lives here:
## FIN_TOP_H is in the LEVEL frame and `at()` turns it into the parked 3.03 m without a second number.
func _fin(tool: SurfaceTool) -> void:
	var le := func(h: float) -> float:
		return lerpf(FIN_ROOT_S, FIN_TIP_LE_S, clampf((h - FIN_ROOT_H) / (FIN_TOP_H - FIN_ROOT_H), 0.0, 1.0))
	var hinge := func(h: float) -> float:
		var a: Vector2 = RUDDER_HINGE[0]
		var b: Vector2 = RUDDER_HINGE[1]
		return lerpf(a.x, b.x, clampf((h - a.y) / (b.y - a.y), 0.0, 1.0))
	var rows: Array[float] = []
	for i in range(7):
		rows.append(lerpf(FIN_ROOT_H, FIN_TOP_H, float(i) / 6.0))
	var box := AABB(at(0.0, FIN_ROOT_H, FIN_ROOT_S), Vector3.ZERO)
	for i in range(rows.size() - 1):
		var h0: float = rows[i]
		var h1: float = rows[i + 1]
		var thick0: float = FIN_THICK * (1.0 - 0.45 * float(i) / 6.0)
		var thick1: float = FIN_THICK * (1.0 - 0.45 * float(i + 1) / 6.0)
		for face in [1.0, -1.0]:
			var a: Vector3 = at(face * thick0 * 0.5, h0, le.call(h0))
			var b: Vector3 = at(face * thick1 * 0.5, h1, le.call(h1))
			var c: Vector3 = at(face * thick1 * 0.5, h1, hinge.call(h1))
			var d: Vector3 = at(face * thick0 * 0.5, h0, hinge.call(h0))
			_quad(tool, a, b, c, d, Vector3(face, 0.0, 0.0), WHITE)
			box = box.expand(a).expand(b).expand(c).expand(d)
		# The leading edge itself, as one facet, which is what keeps it a crease.
		_quad(tool, at(-thick0 * 0.5, h0, le.call(h0)), at(thick0 * 0.5, h0, le.call(h0)),
			at(thick1 * 0.5, h1, le.call(h1)), at(-thick1 * 0.5, h1, le.call(h1)), Vector3.FORWARD, WHITE)
	# The cap, from the leading corner aft to the top trailing corner, which is the aeroplane's aft-most point.
	_quad(tool, at(-0.03, FIN_TOP_H, FIN_TIP_LE_S), at(0.03, FIN_TOP_H, FIN_TIP_LE_S),
		at(0.03, FIN_TOP_H, FIN_TIP_TE_S), at(-0.03, FIN_TOP_H, FIN_TIP_TE_S), Vector3.UP, WHITE)
	surfaces["Fin"] = box.expand(at(0.0, FIN_TOP_H, FIN_TIP_TE_S))


## ---- the wing, the tanks and the nacelles ---------------------------------------------------------------------

func _wing(tool: SurfaceTool, side: float) -> void:
	var point := func(x: float, c: float, face: float) -> Vector3:
		return _wing_point(side, x, c, face)
	var label: String = "Wing" + ("Starboard" if side > 0.0 else "Port")
	# The flap and the aileron are drawn separately so they can move, so the fixed wing stops at their hinge line.
	_slab(tool, point, WING_SIDE_X, WING_TIP_X, 0.0, 1.0, label, side, FLAP_X, AILERON_X)
	# The root fairing, from the fuselage side in to the centreline, which is what makes a low wing read as one.
	_slab(tool, point, 0.0, WING_SIDE_X, 0.0, 1.0, label + "Root", side, Vector2.ZERO, Vector2.ZERO)


## THE TIP TANK. It is a body of revolution on its own axis, and the axis is what makes it a 310's: drooped nose-down
## about the wing tip and toed a little outboard, so the tank's tail stands proud of the wing and its nose reaches down
## and forward. A cylinder bolted on straight is what this replaced.
func _tip_tank(tool: SurfaceTool, side: float) -> void:
	const SIDES := 10
	var mid_s: float = TANK_NOSE_S + TANK_LENGTH * 0.5
	var axis := func(t: float) -> Vector3:
		# `t` runs 0 at the nose to 1 at the tail, along the canted axis through the tank's middle.
		var along: float = (t - 0.5) * TANK_LENGTH
		return at(side * (TANK_X - along * TANK_TOE), TANK_H + along * TANK_DROOP, mid_s + along)
	# A slender ogive: pointed at both ends, fullest a little forward of the middle, which is how [L] draws it.
	var radius := func(t: float) -> float:
		var u: float = clampf(t, 0.0, 1.0)
		return pow(sin(PI * pow(u, 0.86)), 0.62)
	var rows: Array[float] = []
	for i in range(13):
		rows.append(float(i) / 12.0)
	var box := AABB(axis.call(0.0), Vector3.ZERO)
	for i in range(rows.size() - 1):
		var t0: float = rows[i]
		var t1: float = rows[i + 1]
		var c0: Vector3 = axis.call(t0)
		var c1: Vector3 = axis.call(t1)
		var r0: float = radius.call(t0)
		var r1: float = radius.call(t1)
		for k in range(SIDES):
			var a0: float = TAU * float(k) / SIDES
			var a1: float = TAU * float(k + 1) / SIDES
			var p := func(c: Vector3, r: float, a: float) -> Vector3:
				return c + Vector3(cos(a) * r * TANK_WIDE * 0.5, sin(a) * r * TANK_DEEP * 0.5, 0.0)
			var q0: Vector3 = p.call(c0, r0, a0)
			var q1: Vector3 = p.call(c0, r0, a1)
			var q2: Vector3 = p.call(c1, r1, a1)
			var q3: Vector3 = p.call(c1, r1, a0)
			_quad(tool, q0, q1, q2, q3, (q0 - c0) + (q1 - c0), WHITE if sin((a0 + a1) * 0.5) > -0.2 else UNDER)
			box = box.expand(q0).expand(q2)
	surfaces["TipTank" + ("Starboard" if side > 0.0 else "Port")] = box


## THE NACELLE: a rounded box round the engine, running well aft of the wing as a 310's does, with the main wheel well
## in its underside. Its own section is a superellipse so it reads as a nacelle rather than as a crate.
func _nacelle(tool: SurfaceTool, side: float) -> void:
	const SIDES := 12
	var rows: Array[Vector2] = [
		Vector2(NACELLE_FORE, 0.46), Vector2(1.70, 0.86), Vector2(2.30, 1.00), Vector2(3.10, 1.00),
		Vector2(3.90, 0.94), Vector2(4.60, 0.76), Vector2(5.05, 0.52), Vector2(NACELLE_AFT, 0.10)]
	var ring := func(row: Vector2) -> Array[Vector3]:
		var out: Array[Vector3] = []
		for k in range(SIDES):
			var a: float = TAU * float(k) / SIDES
			var cs: float = cos(a)
			var sn: float = sin(a)
			var n: float = 2.6
			out.append(at(side * ENGINE_X + pow(absf(cs), 2.0 / n) * signf(cs) * NACELLE_WIDE * 0.5 * row.y,
				NACELLE_H + pow(absf(sn), 2.0 / n) * signf(sn) * NACELLE_DEEP * 0.5 * row.y, row.x))
		return out
	var rings: Array = []
	for row in rows:
		rings.append(ring.call(row))
	for i in range(rings.size() - 1):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for k in range(SIDES):
			var k2: int = (k + 1) % SIDES
			_quad(tool, a[k], a[k2], b[k2], b[k], _out(a[k], a[k2], b[k2]),
				WHITE if k < SIDES / 2 else UNDER)
	# The cowl face, and the tail cone, so the nacelle is a closed solid.
	var first: Array = rings[0]
	var hub: Vector3 = at(side * ENGINE_X, THRUST_H, NACELLE_FORE)
	for k in range(SIDES):
		_tri(tool, hub, first[k], first[(k + 1) % SIDES], Vector3.FORWARD, METAL)
	var last: Array = rings[rings.size() - 1]
	var back: Vector3 = at(side * ENGINE_X, NACELLE_H, NACELLE_AFT + 0.06)
	for k in range(SIDES):
		_tri(tool, back, last[k], last[(k + 1) % SIDES], Vector3.BACK, UNDER)
	_record("Nacelle" + ("Starboard" if side > 0.0 else "Port"), rings)


## ---- the tail -------------------------------------------------------------------------------------------------

static func stab_leading_edge(x: float) -> float:
	return STAB_ROOT_LE + STAB_LE_SWEEP * absf(x)


static func stab_chord(x: float) -> float:
	var t: float = clampf(absf(x) / (STAB_SPAN * 0.5), 0.0, 1.0)
	return lerpf(STAB_ROOT_CHORD, STAB_TIP_CHORD, t)


func _stab_point(side: float, x: float, c: float, face: float) -> Vector3:
	var out: float = absf(x)
	var chord: float = stab_chord(out)
	var s: float = stab_leading_edge(out) + c * chord
	var half: float = _thickness(c) * chord * 0.42
	return at(side * out, STAB_H + STAB_DIHEDRAL * out + face * half, s)


func _stabiliser(tool: SurfaceTool, side: float) -> void:
	var point := func(x: float, c: float, face: float) -> Vector3:
		return _stab_point(side, x, c, face)
	var label: String = "Stabiliser" + ("Starboard" if side > 0.0 else "Port")
	_slab(tool, point, 0.0, STAB_SPAN * 0.5, 0.0, 1.0 - ELEVATOR_CHORD / STAB_ROOT_CHORD, label, side,
		Vector2.ZERO, Vector2.ZERO)


## ---- the cabin, the gear and the fittings ---------------------------------------------------------------------

## THE LINING, a second closed surface inside the skin so the cabin reads as a room from a seat rather than as the
## inside of a shell. It is INTERIOR: `show_layers` hides it for an exterior shot, and `aircraft_fidelity`'s
## ray-parity work must gather the exterior only (`modelling_here.md` section 6).
func _cabin(tool: SurfaceTool) -> void:
	var fore: float = ROOM_FORE - 0.20
	var aft: float = ROOM_AFT + 0.20
	var half: float = ROOM_HALF + 0.03
	for s in [fore, aft]:
		_quad(tool, at(-half, CABIN_FLOOR, s), at(half, CABIN_FLOOR, s), at(half, CABIN_ROOF, s),
			at(-half, CABIN_ROOF, s), Vector3.BACK if s > 4.0 else Vector3.FORWARD, CABIN)
	_quad(tool, at(-half, CABIN_FLOOR, fore), at(half, CABIN_FLOOR, fore), at(half, CABIN_FLOOR, aft),
		at(-half, CABIN_FLOOR, aft), Vector3.UP, PANEL)
	_quad(tool, at(-half, CABIN_ROOF, fore), at(half, CABIN_ROOF, fore), at(half, CABIN_ROOF, aft),
		at(-half, CABIN_ROOF, aft), Vector3.DOWN, CABIN)
	for side in [1.0, -1.0]:
		_quad(tool, at(side * half, CABIN_FLOOR, fore), at(side * half, CABIN_ROOF, fore),
			at(side * half, CABIN_ROOF, aft), at(side * half, CABIN_FLOOR, aft), Vector3(-side, 0.0, 0.0), CABIN)
	surfaces["Cabin"] = AABB(at(-half, CABIN_FLOOR, fore), at(half, CABIN_ROOF, aft) - at(-half, CABIN_FLOOR, fore))


## THE GEAR, as three legs that swing. Each leg is its own node so `set_gear` can turn it, and each one's rest pose and
## hinge are recorded where `_swing` can find them.
func _legs(paint: Material) -> void:
	# EVERY LEG IS BUILT ABOUT ITS OWN TRUNNION and the node is then stood at it. A leg built in
	# craft coordinates with its node left at the origin swings about a point four metres away when
	# `set_gear` turns it -- and in the first build it did exactly that, and the tyres did not rise
	# by a millimetre while `set_gear` reported itself done.
	for side in [1.0, -1.0]:
		var tool := _tool()
		var axle: Vector3 = at(side * TRACK * 0.5, MAIN_TYRE_R, MAIN_AXLE_S)
		var root: Vector3 = at(side * ENGINE_X, NACELLE_H - 0.10, MAIN_AXLE_S - 0.30)
		_rod(tool, Vector3.ZERO, axle + Vector3(0.0, 0.10, 0.0) - root, 0.045, METAL)
		_wheel(tool, axle - root, MAIN_TYRE_R, MAIN_TYRE_WIDE)
		var label: String = "MainGear" + ("Starboard" if side > 0.0 else "Port")
		var node := _add(exterior, label, tool, paint, false, root)
		_hinges[node] = [root, root, Vector3.RIGHT]
		surfaces[label] = AABB(axle - Vector3.ONE * MAIN_TYRE_R, Vector3.ONE * MAIN_TYRE_R * 2.0)
	var nose := _tool()
	var nose_axle: Vector3 = at(0.0, NOSE_TYRE_R - nose_drop(), NOSE_AXLE_S)
	var nose_root: Vector3 = at(0.0, section_at(NOSE_AXLE_S, 3) + 0.06, NOSE_AXLE_S + 0.10)
	_rod(nose, Vector3.ZERO, nose_axle + Vector3(0.0, 0.08, 0.0) - nose_root, 0.04, METAL)
	_wheel(nose, nose_axle - nose_root, NOSE_TYRE_R, NOSE_TYRE_WIDE)
	var node := _add(exterior, "NoseGear", nose, paint, false, nose_root)
	_hinges[node] = [nose_root, nose_root, Vector3.RIGHT]
	surfaces["NoseGear"] = AABB(nose_axle - Vector3.ONE * NOSE_TYRE_R, Vector3.ONE * NOSE_TYRE_R * 2.0)


func _details(tool: SurfaceTool) -> void:
	# THE CHEAT LINE, drawn on the skin at the widest point of each side, from the nose back into
	# the fin's fillet, which is the only livery this aeroplane carries.
	for side in [1.0, -1.0]:
		var last: float = 0.9
		for i in range(1, 15):
			var s: float = lerpf(0.9, 7.6, float(i) / 14.0)
			var h0: float = lerpf(1.44, 1.86, pow((last - 0.9) / 6.7, 1.5))
			var h1: float = lerpf(1.44, 1.86, pow((s - 0.9) / 6.7, 1.5))
			var x0: float = side * (section_at(last, 1) + 0.006)
			var x1: float = side * (section_at(s, 1) + 0.006)
			_quad(tool, at(x0, h0 - 0.045, last), at(x0, h0 + 0.045, last), at(x1, h1 + 0.045, s),
				at(x1, h1 - 0.045, s), Vector3(side, 0.0, 0.0), TRIM)
			last = s
	# The cabin door on the starboard side, as a seam, and the nose baggage door the R is named for.
	_seam_rect(tool, 1.0, DOOR, 0.02)
	_seam_rect(tool, 1.0, NOSE_DOOR, 0.018)
	_seam_rect(tool, -1.0, NOSE_DOOR, 0.018)
	# The beacon on the fin, the nav lights in the tank noses, and the aerial over the cabin.
	# THE BEACON IS THE TOP OF THE AEROPLANE. [L] prints 9 ft 11.25 in to the fin cap and says in a
	# note beside it that a rotating beacon adds three inches, so the drawn height is the cap plus
	# 0.076 m and `craft/plane/sources.md` holds the model to that -- not to the published 10 ft 8 in,
	# which is the nose-gear-depressed maximum.
	_box(tool, at(0.0, FIN_TOP_H + 0.036, FIN_TIP_LE_S + 0.18), Vector3(0.07, 0.08, 0.14), Color(0.55, 0.08, 0.08))
	for side in [1.0, -1.0]:
		_box(tool, at(side * (TANK_X - TANK_LENGTH * 0.5 * TANK_TOE), TANK_H - TANK_LENGTH * 0.5 * TANK_DROOP + 0.02,
			TANK_NOSE_S + 0.05), Vector3(0.10, 0.07, 0.10), Color(0.10, 0.45, 0.14) if side > 0.0
			else Color(0.55, 0.10, 0.10))
	_box(tool, at(0.0, section_at(4.20, 2) + 0.06, 4.20), Vector3(0.02, 0.12, 0.42), DARK)
	# The pitot under the port wing, and the step under the starboard door.
	_rod(tool, at(-1.30, wing_height(1.30) - 0.10, wing_leading_edge(1.30)),
		at(-1.30, wing_height(1.30) - 0.10, wing_leading_edge(1.30) - 0.26), 0.014, METAL)
	_box(tool, at(0.70, 0.86, DOOR.position.x + DOOR.size.x * 0.5), Vector3(0.22, 0.03, 0.16), METAL)


func _seam_rect(tool: SurfaceTool, side: float, rect: Rect2, wide: float) -> void:
	var s0: float = rect.position.x
	var s1: float = rect.position.x + rect.size.x
	var h0: float = rect.position.y
	var h1: float = rect.position.y + rect.size.y
	_seam(tool, side, Vector2(s0, h0), Vector2(s1, h0), wide)
	_seam(tool, side, Vector2(s0, h1), Vector2(s1, h1), wide)
	_seam(tool, side, Vector2(s0, h0), Vector2(s0, h1), wide)
	_seam(tool, side, Vector2(s1, h0), Vector2(s1, h1), wide)


## A seam drawn ON the skin, a centimetre proud so the two faces do not fight, at the fuselage's own half-width there.
func _seam(tool: SurfaceTool, side: float, a: Vector2, b: Vector2, wide: float) -> void:
	var steps: int = 4
	for i in range(steps):
		var t0: float = float(i) / steps
		var t1: float = float(i + 1) / steps
		var p0: Vector2 = a.lerp(b, t0)
		var p1: Vector2 = a.lerp(b, t1)
		var x0: float = side * (section_at(p0.x, 1) + 0.006)
		var x1: float = side * (section_at(p1.x, 1) + 0.006)
		_quad(tool, at(x0, p0.y - wide * 0.5, p0.x), at(x0, p0.y + wide * 0.5, p0.x),
			at(x1, p1.y + wide * 0.5, p1.x), at(x1, p1.y - wide * 0.5, p1.x), Vector3(side, 0.0, 0.0), SEAM)


## ---- what moves -----------------------------------------------------------------------------------------------

func _moving_surfaces(paint: Material) -> void:
	for side in [1.0, -1.0]:
		var name_end: String = "Starboard" if side > 0.0 else "Port"
		var point := func(x: float, c: float, face: float) -> Vector3:
			return _wing_point(side, x, c, face)
		_offset_surface("Flap" + name_end, paint, point, FLAP_X, FLAP_CHORD, side)
		_offset_surface("Aileron" + name_end, paint, point, AILERON_X, AILERON_CHORD, side)
		var stab := func(x: float, c: float, face: float) -> Vector3:
			return _stab_point(side, x, c, face)
		_offset_surface("Elevator" + name_end, paint, stab, Vector2(0.06, STAB_SPAN * 0.5),
			ELEVATOR_CHORD / STAB_ROOT_CHORD, side, true)
	_rudder(paint)


## A hinged trailing-edge surface, built about its own hinge line so a rotation turns it rather than shearing it.
func _offset_surface(label: String, paint: Material, point: Callable, span: Vector2, chord_fraction: float,
		side: float, tail: bool = false) -> void:
	var tool := _tool()
	var c0: float = 1.0 - chord_fraction
	var x0: float = span.x
	var x1: float = span.y
	var hinge: Vector3 = point.call((x0 + x1) * 0.5, c0, 0.0)
	var shifted := func(x: float, c: float, face: float) -> Vector3:
		return point.call(x, c, face) - hinge
	_slab(tool, shifted, x0, x1, c0 + HINGE_GAP, 1.0, label, side, Vector2.ZERO, Vector2.ZERO)
	var node := _add(exterior, label, tool, paint, false, hinge)
	_hinges[node] = [hinge, hinge, Vector3.RIGHT]


func _rudder(paint: Material) -> void:
	var tool := _tool()
	var a: Vector2 = RUDDER_HINGE[0]
	var b: Vector2 = RUDDER_HINGE[1]
	var hinge: Vector3 = at(0.0, (a.y + b.y) * 0.5, lerpf(a.x, b.x, 0.5))
	var rows: int = 5
	for i in range(rows):
		var h0: float = lerpf(a.y, b.y, float(i) / rows)
		var h1: float = lerpf(a.y, b.y, float(i + 1) / rows)
		var hinge0: float = lerpf(a.x, b.x, float(i) / rows)
		var hinge1: float = lerpf(a.x, b.x, float(i + 1) / rows)
		var te0: float = lerpf(FIN_TIP_TE_S - 0.86, FIN_TIP_TE_S, float(i) / rows)
		var te1: float = lerpf(FIN_TIP_TE_S - 0.86, FIN_TIP_TE_S, float(i + 1) / rows)
		var thick: float = FIN_THICK * 0.8
		for face in [1.0, -1.0]:
			_quad(tool, at(face * thick * 0.5, h0, hinge0 + HINGE_GAP) - hinge,
				at(face * thick * 0.5, h1, hinge1 + HINGE_GAP) - hinge,
				at(face * thick * 0.5, h1, te1) - hinge, at(face * thick * 0.5, h0, te0) - hinge,
				Vector3(face, 0.0, 0.0), WHITE)
		_quad(tool, at(-thick * 0.5, h0, te0) - hinge, at(thick * 0.5, h0, te0) - hinge,
			at(thick * 0.5, h1, te1) - hinge, at(-thick * 0.5, h1, te1) - hinge, Vector3.BACK, WHITE)
	var node := _add(exterior, "Rudder", tool, paint, false, hinge)
	# THE RUDDER TURNS ABOUT ITS OWN HINGE LINE, which is raked, not about the craft's vertical.
	var along: Vector3 = (at(0.0, b.y, b.x) - at(0.0, a.y, a.x)).normalized()
	_hinges[node] = [hinge, hinge, along]
	surfaces["Rudder"] = AABB(at(-thick_half(), a.y, a.x), at(thick_half(), b.y, FIN_TIP_TE_S)
		- at(-thick_half(), a.y, a.x))


static func thick_half() -> float:
	return FIN_THICK * 0.4


func _part(named: String) -> Node3D:
	return exterior.find_child(named, false, false) as Node3D if exterior != null else null


func _swing(node: Node3D, angle: float, about: Vector3, pivot: Vector3) -> void:
	if node == null:
		return
	node.transform = Transform3D(Basis(about.normalized(), angle), pivot - Basis(about.normalized(), angle) * pivot) \
		* Transform3D(Basis.IDENTITY, Vector3.ZERO)
	node.position = pivot


func set_flaps(amount: float) -> void:
	_flaps = clampf(amount, 0.0, 1.0)
	for end in ["Port", "Starboard"]:
		var node := _part("Flap" + end)
		if node != null:
			node.basis = Basis(Vector3.RIGHT, _flaps * FLAP_TRAVEL)


func set_trim(amount: float) -> void:
	_trim = clampf(amount, -1.0, 1.0)


func set_ailerons(amount: float) -> void:
	_roll = clampf(amount, -1.0, 1.0)
	for end in ["Port", "Starboard"]:
		var side: float = 1.0 if end == "Starboard" else -1.0
		var node := _part("Aileron" + end)
		if node != null:
			var want: float = -_roll * side
			node.basis = Basis(Vector3.RIGHT, want * (AILERON_DOWN if want > 0.0 else AILERON_UP))


func set_elevator(amount: float) -> void:
	_pitch = clampf(amount, -1.0, 1.0)
	for end in ["Port", "Starboard"]:
		var node := _part("Elevator" + end)
		if node != null:
			node.basis = Basis(Vector3.RIGHT, -_pitch * (ELEVATOR_UP if _pitch > 0.0 else ELEVATOR_DOWN))


func set_rudder(amount: float) -> void:
	_yaw = clampf(amount, -1.0, 1.0)
	var node := _part("Rudder")
	if node != null:
		var hinge: Array = _hinges.get(node, [Vector3.ZERO, Vector3.ZERO, Vector3.UP])
		node.basis = Basis((hinge[2] as Vector3).normalized(), -_yaw * RUDDER_TRAVEL)


## THE GEAR: 1.0 down and 0.0 up. The mains swing aft into the nacelles and the nose leg forward into the nose.
func set_gear(amount: float) -> void:
	_gear = clampf(amount, 0.0, 1.0)
	for end in ["Port", "Starboard"]:
		var node := _part("MainGear" + end)
		if node != null:
			node.basis = Basis(Vector3.RIGHT, (1.0 - _gear) * MAIN_GEAR_SWING)
	var nose := _part("NoseGear")
	if nose != null:
		nose.basis = Basis(Vector3.RIGHT, (1.0 - _gear) * NOSE_GEAR_SWING)


func gear_amount() -> float:
	return _gear


func flaps_amount() -> float:
	return _flaps


func trim_amount() -> float:
	return _trim


func stick_amounts() -> Vector3:
	return Vector3(_roll, _pitch, _yaw)


func propeller_state() -> Dictionary:
	return _prop_handed.duplicate()


## ---- the propellers -------------------------------------------------------------------------------------------

func _propellers(paint: Material) -> void:
	for side in [1.0, -1.0]:
		var end: String = "Starboard" if side > 0.0 else "Port"
		var hub: Vector3 = at(side * ENGINE_X, THRUST_H, PROP_S)
		var tool := _tool()
		# The spinner, eight-sided and pointed, then three blades off it.
		const SIDES := 8
		for k in range(SIDES):
			var a0: float = TAU * float(k) / SIDES
			var a1: float = TAU * float(k + 1) / SIDES
			var r0 := Vector3(cos(a0), sin(a0), 0.0) * SPINNER_RADIUS
			var r1 := Vector3(cos(a1), sin(a1), 0.0) * SPINNER_RADIUS
			var back := Vector3(0.0, 0.0, SPINNER_LENGTH)
			_tri(tool, Vector3.ZERO, r0 - back * 0.0, r1, Vector3.FORWARD, WHITE)
			_quad(tool, r0, r1, r1 + back, r0 + back, r0 + r1, WHITE)
		for blade in range(3):
			_blade(tool, TAU * float(blade) / 3.0)
		var node := _add(exterior, "Propeller" + end, tool, paint, false, hub)
		surfaces["Propeller" + end] = AABB(hub - Vector3.ONE * PROP_DIAMETER * 0.5,
			Vector3.ONE * PROP_DIAMETER)
		var disc := MeshInstance3D.new()
		disc.name = "PropellerDisc" + end
		var mesh := CylinderMesh.new()
		mesh.top_radius = PROP_DIAMETER * 0.5
		mesh.bottom_radius = PROP_DIAMETER * 0.5
		mesh.height = 0.02
		mesh.radial_segments = 20
		mesh.rings = 1
		disc.mesh = mesh
		disc.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		disc.position = hub
		var film := StandardMaterial3D.new()
		film.albedo_color = Color(0.72, 0.72, 0.74, DISC_ALPHA)
		film.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		film.cull_mode = BaseMaterial3D.CULL_DISABLED
		disc.material_override = film
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		exterior.add_child(disc)


## One blade, root to tip, twisted as a propeller is and tipped in the paint the real ones carry.
func _blade(tool: SurfaceTool, about: float) -> void:
	var turn := Basis(Vector3.FORWARD, about)
	var rows: int = 5
	for i in range(rows):
		var r0: float = lerpf(SPINNER_RADIUS * 0.8, PROP_DIAMETER * 0.5, float(i) / rows)
		var r1: float = lerpf(SPINNER_RADIUS * 0.8, PROP_DIAMETER * 0.5, float(i + 1) / rows)
		var c0: float = lerpf(0.20, 0.09, float(i) / rows)
		var c1: float = lerpf(0.20, 0.09, float(i + 1) / rows)
		var t0: float = lerpf(0.60, 0.16, float(i) / rows)
		var t1: float = lerpf(0.60, 0.16, float(i + 1) / rows)
		var tint: Color = BLADE_TIP if i == rows - 1 else BLADE
		for face in [1.0, -1.0]:
			var a := turn * Vector3(0.0, r0, 0.0)
			var b := turn * Vector3(0.0, r1, 0.0)
			var fore0 := turn * Vector3(cos(t0) * c0 * 0.5, 0.0, -sin(t0) * c0 * 0.5)
			var fore1 := turn * Vector3(cos(t1) * c1 * 0.5, 0.0, -sin(t1) * c1 * 0.5)
			var thick := turn * Vector3(0.0, 0.0, 0.0) + Vector3(0.0, 0.0, face * 0.008)
			_quad(tool, a - fore0 + thick, a + fore0 + thick, b + fore1 + thick, b - fore1 + thick,
				Vector3(0.0, 0.0, face), tint)


func set_propeller(turning: bool, throttle: float, seconds: float) -> void:
	_prop_handed = {"turning": turning, "throttle": throttle, "seconds": seconds}
	var angle: float = (seconds * PROP_TURNS * TAU) if turning else PROP_PARKED
	var whole: float = clampf((throttle - DISC_FROM.x) / maxf(DISC_FROM.y - DISC_FROM.x, 0.001), 0.0, 1.0)
	for end in ["Port", "Starboard"]:
		var blades := _part("Propeller" + end)
		if blades != null:
			blades.basis = Basis(Vector3.FORWARD, angle)
			blades.visible = not (turning and whole >= 1.0)
		var disc := exterior.find_child("PropellerDisc" + end, false, false) as MeshInstance3D
		if disc != null:
			disc.visible = turning and whole > 0.0
			var film := disc.material_override as StandardMaterial3D
			if film != null:
				film.albedo_color = Color(0.72, 0.72, 0.74, DISC_ALPHA * whole)


## ---- what it publishes ----------------------------------------------------------------------------------------

## THE ROOM THIS AEROPLANE PROMISES ROUND ITS CREW, in the craft's own frame. Every point inside `room` is inside the
## drawn skin; a point outside it may or may not be, and that asymmetry is what makes the promise checkable against the
## drawn triangles. `floor` is published BESIDE the room and is not its bottom: the belly pinches in below the cabin
## floor, so a consumer that took the room's bottom for the floor would lay one too high.
##
## THE SEATS THIS KIND CARRIES ARE NOT THIS AEROPLANE'S. `plane_shape()` puts four seat anchors within +/-0.70 m of the
## hull's middle and 0.15 m below it, which on a true-scale 310R is 0.48 m BELOW the cabin floor -- the anchor is a play
## space's floor rather than a seat pan, so a crew's EYES land at 1.90 m over the ground, 0.87 m over this cabin's floor
## and a comfortable 0.25 m under its roof. The eyes are right and the anchors are low, and moving them is a native
## shape-table change. Reported here rather than papered over.
func cabin_room() -> Dictionary:
	var fore: Vector3 = at(-ROOM_HALF, ROOM_FLOOR, ROOM_FORE)
	var aft: Vector3 = at(ROOM_HALF, ROOM_ROOF, ROOM_AFT)
	var low: float = minf(fore.y, at(-ROOM_HALF, ROOM_FLOOR, ROOM_AFT).y)
	var high: float = maxf(aft.y, at(ROOM_HALF, ROOM_ROOF, ROOM_FORE).y)
	var front: float = minf(fore.z, at(-ROOM_HALF, ROOM_ROOF, ROOM_FORE).z)
	var back: float = maxf(aft.z, at(ROOM_HALF, ROOM_FLOOR, ROOM_AFT).z)
	return {
		"drawn": true,
		"floor": at(0.0, CABIN_FLOOR, (ROOM_FORE + ROOM_AFT) * 0.5).y,
		"room": AABB(Vector3(-ROOM_HALF, low, front),
			Vector3(ROOM_HALF * 2.0, high - low, back - front)),
		"because": &"",
		"why_not": "",
		"source": "[L]'s plan half-widths and side profile, measured 2026-09-19; the floor an ESTIMATE",
	}


## THE NAMED SOCKETS, from the same constants the drawing uses: the package's copy is checked against these.
func sockets() -> Dictionary:
	var nose: Vector3 = at(0.0, NOSE_TYRE_R - nose_drop(), NOSE_AXLE_S)
	var port: Vector3 = at(-TRACK * 0.5, MAIN_TYRE_R, MAIN_AXLE_S)
	var starboard: Vector3 = at(TRACK * 0.5, MAIN_TYRE_R, MAIN_AXLE_S)
	var prop_port: Vector3 = at(-ENGINE_X, THRUST_H, PROP_S)
	var prop_starboard: Vector3 = at(ENGINE_X, THRUST_H, PROP_S)
	var tank_port: Vector3 = at(-TANK_X, TANK_H, TANK_NOSE_S + TANK_LENGTH * 0.5)
	var tank_starboard: Vector3 = at(TANK_X, TANK_H, TANK_NOSE_S + TANK_LENGTH * 0.5)
	return {
		"nose_gear": _triple(nose),
		"main_gear_port": _triple(port),
		"main_gear_starboard": _triple(starboard),
		"propeller_port": _triple(prop_port),
		"propeller_starboard": _triple(prop_starboard),
		"tip_tank_port": _triple(tank_port),
		"tip_tank_starboard": _triple(tank_starboard),
	}


static func _triple(point: Vector3) -> Array:
	return [snappedf(point.x, 0.01), snappedf(point.y, 0.01), snappedf(point.z, 0.01)]


## The nav, strobe and beacon positions, so a level lights the aeroplane from the aeroplane.
func lights() -> Dictionary:
	return {
		"nav_port": at(-TANK_X, TANK_H - TANK_LENGTH * 0.5 * TANK_DROOP, TANK_NOSE_S + 0.04),
		"nav_starboard": at(TANK_X, TANK_H - TANK_LENGTH * 0.5 * TANK_DROOP, TANK_NOSE_S + 0.04),
		"beacon": at(0.0, FIN_TOP_H + 0.09, FIN_TIP_LE_S + 0.18),
	}


## THE PLANFORM THIS AEROPLANE IS GOING TO BE FLOWN OFF, published rather than left to be guessed
## at from the triangles. `lane/flightcore` has this kind on its list for the real-wing treatment and
## will read its wing from here, so every figure below is DERIVED from the chord law the drawing
## fits -- `2.033 - 0.1701 y` over 43 stations at 51 mm rms -- and none is typed beside it.
##
## **WHERE THE WING ENDS IS A CHOICE, AND IT MOVES THE AREA BY EIGHT PER CENT.** A 310's wing
## structure stops at the tip tank's inner face, 5.078 m out; the aeroplane's half span, 5.626 m, is
## over the TANKS. To the tank this planform is **16.26 m2**; to the half span it is **17.49**.
##
## THE FIRST IS THE EARLY 310's PUBLISHED 175 sq ft (16.258 m2) TO 0.04 PER CENT, measured
## independently off the drawing by `craft/plane/measure_310l.py` -- which is the structural
## cross-check `modelling_here.md` section 3 asks for, because a printed AREA combines the plan
## view's two axes and no view's length goes into it. The 310R's published **179 sq ft (16.63)** is
## neither figure; solved for, it is this same chord law carried to 5.236 m out, 158 mm past where
## the structure ends. The wing did not change between those models ([TCDS] gives both the same
## 51-gallon tanks at the same station), so one of the two published areas is a different convention
## rather than a different wing, and the likeliest reading is that the R's counts part of the tank's
## own plan. That is a guess and `craft/plane/sources.md` marks it as one.
##
## `area` below is the WING's own -- to the tank -- because that is the lifting surface a real-wing
## model integrates. `area_over_tanks` is the other, for whoever needs it.
##
## AND THE ASPECT RATIO HAS THE SAME CHOICE IN IT: **6.34** on the wing's own 10.16 m of structure,
## **7.24** on the 11.25 m the tanks carry. Tip tanks end-plate a wing and its effective aspect ratio
## is somewhere between the two; saying which one a lift slope used is the difference between a wing
## that stalls where the book says and one that does not.
func planform() -> Dictionary:
	var tip: float = TANK_X - TANK_WIDE * 0.5
	var root: float = WING_CHORD_ROOT
	var fall: float = WING_CHORD_FALL
	var area: float = 2.0 * (root * tip - fall * tip * tip * 0.5)
	var over: float = 2.0 * (root * (SPAN * 0.5) - fall * SPAN * SPAN * 0.125)
	var mac: float = 0.0
	var steps: int = 400
	for i in range(steps):
		var x: float = tip * (float(i) + 0.5) / float(steps)
		mac += pow(root - fall * x, 2.0) * (tip / float(steps))
	mac = 2.0 * mac / area
	return {
		"span": SPAN,
		"wing_span": tip * 2.0,
		"area": area,
		"area_over_tanks": over,
		"root_chord": root,
		"tip_chord": root - fall * tip,
		"taper": (root - fall * tip) / root,
		"mac": mac,
		"aspect_ratio": (tip * 2.0) * (tip * 2.0) / area,
		"aspect_ratio_over_tanks": SPAN * SPAN / over,
		"dihedral": atan(DIHEDRAL),
		"le_sweep": atan(WING_LE_SWEEP),
		"incidence": Vector2(ROOT_INCIDENCE, TIP_INCIDENCE),
		"stabiliser_span": STAB_SPAN,
		"stabiliser_area": (STAB_ROOT_CHORD + STAB_TIP_CHORD) * 0.5 * STAB_SPAN,
		"source": "[L]'s plan view, 43 stations at 51 mm rms; craft/plane/sources.md, 'the wing'",
	}


## What the tip tanks hold, DERIVED from the drawn body rather than typed: [TCDS]'s 51 US gal a side is the figure
## `tests/twin310.gd` holds this against, and a tank drawn too small or too fat says so in litres.
func tank_volume() -> float:
	var total: float = 0.0
	var steps: int = 48
	for i in range(steps):
		var t: float = (float(i) + 0.5) / steps
		var r: float = pow(sin(PI * pow(t, 0.86)), 0.62)
		total += PI * (r * TANK_WIDE * 0.5) * (r * TANK_DEEP * 0.5) * (TANK_LENGTH / steps)
	return total


## ---- mesh plumbing --------------------------------------------------------------------------------------------

## THE CHORDWISE CUTS every slab is split at: six panels along a chord, closest round the leading edge where an aerofoil
## turns fastest. More cuts drew a smoother wing and cost half again as many triangles for a look nobody asked for.
const _CUTS: Array[float] = [0.0, 0.05, 0.18, 0.45, 0.73, 0.78, 1.0]


## A lifting surface between two spanwise stations and two chord fractions. `skip_a` and `skip_b` are spanwise ranges
## whose trailing edge belongs to a moving surface, so the fixed wing stops at the hinge line there.
func _slab(tool: SurfaceTool, point: Callable, x0: float, x1: float, c0: float, c1: float, label: String, side: float,
		skip_a: Vector2, skip_b: Vector2) -> void:
	if x1 <= x0 or c1 <= c0:
		return
	var cuts: Array[float] = [c0]
	for cut in _CUTS:
		if cut > c0 + 0.005 and cut < c1 - 0.005:
			cuts.append(cut)
	cuts.append(c1)
	var spans: Array[float] = [x0]
	for edge in [skip_a.x, skip_a.y, skip_b.x, skip_b.y]:
		if edge > x0 + 0.01 and edge < x1 - 0.01:
			spans.append(edge)
	spans.sort()
	var pieces: int = maxi(1, ceili((x1 - x0) / 2.0))
	for i in range(1, pieces):
		spans.append(lerpf(x0, x1, float(i) / pieces))
	spans.append(x1)
	spans.sort()
	var box := AABB()
	var found := false
	for n in range(spans.size() - 1):
		var xa: float = spans[n]
		var xb: float = spans[n + 1]
		if xb - xa < 0.005:
			continue
		var mid: float = (xa + xb) * 0.5
		var moving: bool = (mid > skip_a.x and mid < skip_a.y) or (mid > skip_b.x and mid < skip_b.y)
		var back: float = c1
		if moving:
			back = 1.0 - (FLAP_CHORD if mid < skip_a.y and mid > skip_a.x else AILERON_CHORD)
		for i in range(cuts.size() - 1):
			var a: float = cuts[i]
			var b: float = minf(cuts[i + 1], back)
			if b <= a + 0.002:
				continue
			for face in [1.0, -1.0]:
				var p: Array[Vector3] = [point.call(xa, a, face), point.call(xb, a, face),
					point.call(xb, b, face), point.call(xa, b, face)]
				_quad(tool, p[0], p[1], p[2], p[3],
					Vector3.UP * face + Vector3.FORWARD * (0.3 if a < 0.1 else 0.0),
					WHITE if face > 0.0 else UNDER)
				for corner in p:
					box = box.expand(corner) if found else AABB(corner, Vector3.ZERO)
					found = true
			# The cut face where a moving surface begins, so the wing is closed there.
			if b < cuts[i + 1] - 0.002:
				_quad(tool, point.call(xa, b, 1.0), point.call(xb, b, 1.0), point.call(xb, b, -1.0),
					point.call(xa, b, -1.0), Vector3.BACK, UNDER)
	# The two ends, and the leading and trailing edges.
	for i in range(cuts.size() - 1):
		var a: float = cuts[i]
		var b: float = cuts[i + 1]
		for edge in [x0, x1]:
			_quad(tool, point.call(edge, a, 1.0), point.call(edge, b, 1.0), point.call(edge, b, -1.0),
				point.call(edge, a, -1.0), Vector3(side * (1.0 if edge == x1 else -1.0), 0.0, 0.0), UNDER)
	if found:
		surfaces[label] = box


func _rod(tool: SurfaceTool, a: Vector3, b: Vector3, radius: float, tint: Color, sides: int = 4) -> void:
	var along: Vector3 = (b - a).normalized()
	if along.length_squared() < 0.5:
		return
	var across: Vector3 = along.cross(Vector3.FORWARD if absf(along.z) < 0.9 else Vector3.UP).normalized()
	var other: Vector3 = along.cross(across)
	for k in range(sides):
		var t0: float = TAU * float(k) / sides
		var t1: float = TAU * float(k + 1) / sides
		var r0: Vector3 = (across * cos(t0) + other * sin(t0)) * radius
		var r1: Vector3 = (across * cos(t1) + other * sin(t1)) * radius
		_quad(tool, a + r0, a + r1, b + r1, b + r0, r0 + r1, tint)
		_tri(tool, b, b + r0, b + r1, along, tint)
		_tri(tool, a, a + r0, a + r1, -along, tint)


## A WHEEL on an axle along x: an eight-sided tyre band and two hubs, flat-shaded, which is what an old-school wheel is.
func _wheel(tool: SurfaceTool, centre: Vector3, radius: float, wide: float) -> void:
	const SIDES := 8
	for k in range(SIDES):
		var t0: float = TAU * float(k) / SIDES
		var t1: float = TAU * float(k + 1) / SIDES
		var r0 := Vector3(0.0, cos(t0), sin(t0)) * radius
		var r1 := Vector3(0.0, cos(t1), sin(t1)) * radius
		var h := Vector3(wide * 0.5, 0.0, 0.0)
		_quad(tool, centre - h + r0, centre - h + r1, centre + h + r1, centre + h + r0, r0 + r1, TYRE)
		for face in [1.0, -1.0]:
			var hub: Vector3 = centre + h * face
			_tri(tool, hub, hub + r0, hub + r1, Vector3(face, 0.0, 0.0), METAL)


func _box(tool: SurfaceTool, at_point: Vector3, size: Vector3, tint: Color) -> void:
	var half: Vector3 = size * 0.5
	for axis in range(3):
		for sign in [1.0, -1.0]:
			var n := Vector3.ZERO
			n[axis] = sign
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 1.0
			var c: Vector3 = n * half[axis]
			var du: Vector3 = u * half[(axis + 1) % 3]
			var dv: Vector3 = v * half[(axis + 2) % 3]
			_quad(tool, at_point + c - du - dv, at_point + c + du - dv, at_point + c + du + dv,
				at_point + c - du + dv, n, tint)


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, tint: Color) -> void:
	_tri(tool, a, b, c, out, tint)
	_tri(tool, a, c, d, out, tint)


## ONE TRIANGLE, wound clockwise as seen from `out` -- Godot's front face -- or skipped if it has no area.
func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, tint: Color) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 1e-12:
		return
	if normal.dot(out) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
	tool.set_color(tint)
	tool.add_vertex(a)
	tool.set_color(tint)
	tool.add_vertex(b)
	tool.set_color(tint)
	tool.add_vertex(c)


func _record(label: String, rings: Array) -> void:
	var box := AABB()
	var found := false
	for ring in rings:
		for corner in ring:
			box = box.expand(corner) if found else AABB(corner, Vector3.ZERO)
			found = true
	surfaces[label] = box


func _tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	return tool


func _add(parent: Node3D, label: String, tool: SurfaceTool, material: Material, detail: bool,
		at_point: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = tool.commit()
	node.material_override = material
	node.position = at_point
	if detail:
		node.visibility_range_end = DETAIL_RANGE
		node.visibility_range_end_margin = DETAIL_HYSTERESIS
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	parent.add_child(node)
	return node


func _paint(double_sided: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.45
	material.metallic = 0.05
	if double_sided:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
