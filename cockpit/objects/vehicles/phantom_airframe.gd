@tool
extends Node3D
class_name PhantomAirframe
## A McDONNELL DOUGLAS F-4E PHANTOM II, DRAWN: the long slim radome of the E with the M61A1's fairing under it, two
## crew in tandem under a front and a rear canopy with a heavy frame between them, the big raked side intakes with
## their splitter plates standing off the skin and the boundary-layer gap open between, the flat slab-sided fuselage,
## THE 12-DEGREE OUTER WING PANELS with their pronounced dogtooth, THE 23-DEGREE ANHEDRAL ALL-MOVING STABILATORS, the
## fin and rudder, two nozzles close together under the tail with the arrester hook between and below them.
##
## WHICH PHANTOM, AND HOW IT IS KNOWN. The F-4E, late production, SLATTED. The user asked for "a forward facing gun as
## well (later models)", which settles the mark: the internal M61A1 in an extended nose is the E onward, and the B, C,
## D and J had no internal gun. The slats are not inferred from the drawing's date -- the F-4E flight manual's own MAIN
## DIFFERENCES TABLE prints LEADING EDGE SLATS: C no, D no, **E yes**, G yes. The same table prints BOUNDARY LAYER
## CONTROL: C yes, D yes, **E no**, so the E's inboard leading edge is a slat and not a blown flap; and HYDRAULIC WING
## FOLD: C yes, D yes, **E NO**, so THE FOLD JOINT IS A PANEL LINE HERE AND NOT A MOVING PART. It was very nearly built
## as one. And the E's radar is the smaller solid-state AN/APQ-120, which is why this radome is slimmer as well as
## longer than a C's -- the nose shape has a reason and a source.
##
## THE SIMULATION GIVES THE SIZE, THIS GIVES THE SHAPE, as for every airframe here -- except that there is no
## simulation kind yet, as `ProwlerAirframe` and `TomcatAirframe` both did before theirs. The box is a draft kept here
## until step 2. Every size names its source:
## - [FM] the F-4E's OWN FLIGHT MANUAL, T.O. 1F-4E-1 (1979), Section I DIMENSIONS, in its original feet and inches:
##   span 38 ft 5 in, length 63 ft, height 16 ft 5 in, main gear 17 ft 11 in apart, span wings folded 27 ft 7 in.
## - [TO] the USAF general-arrangement three-view, T.O. 1F-4C-2-1-1 Change 7 (1993) p. 1-16, public domain, which
##   prints eleven dimensions in metres. **[TO] AND [FM] ARE ONE AUTHORITY IN TWO UNITS** -- the drawing's metric
##   figures are millimetre conversions of the manual's imperial -- so they cannot cross-check each other, and only a
##   printed figure against the INK is evidence. `craft/phantom/measure_manual.py` re-derives every [M] below from the
##   drawing alone and reads nothing out of this file.
## - [M] MEASURED off [TO] by that script, with the method and the residual printed.
## - [PUB] Wikipedia's *Specifications (F-4E)*, citing Green 2001, NASA SP-468, Knaack and Lake 1992.
## - ESTIMATE where nothing gives it, saying what it was reasoned from.
##
## THE PUBLISHED "45 DEGREE LEADING EDGE SWEEP" IS THE QUARTER CHORD, AND THIS AEROPLANE IS BUILT ON THE MEASUREMENT.
## The article body calls 45 degrees a leading-edge sweep. Tracked by continuity from the tip over 267 rows, the
## inboard panel's LEADING edge fits **51.469 degrees at 0.51 px rms** and its TRAILING edge **13.572 at 0.63**; three
## quarters of the first plus one quarter of the second is the quarter-chord line, and it comes out at **45.06
## degrees against the published 45**, with neither edge fitted to anything. Drawing a 45-degree leading edge would
## have given a visibly too-straight wing WITH EVERY DIMENSION CHECK STILL GREEN, on an aeroplane whose planform is one
## of the two or three things that make it recognisable at a distance.
##
## HEIGHTS CARRY A STATED UNCERTAINTY AND ARE NEVER USED AS A CHECK. The sheet offers THREE mutually inconsistent
## vertical scales for its side view: 98.67 px/m from the two printed heights' own arrows, about 96 if the drawn fin
## tip is the published 5.004 m, and about 92 if the printed 3.33 m is the canopy top. They span four per cent and this
## lane could not reconcile them, so the side view is taken as ISOTROPIC WITH ITS OWN 100.42 px/m -- measured along the
## axis stations live on, from the printed 7.09 m wheelbase -- and the fin tip alone is built to [FM]'s 5.004 m.
## **THE HEIGHT IS THEREFORE FITTED TO AND `tests/phantom.gd` DOES NOT CHECK IT.** A bound you fitted to is not a check.
##
## STATIONS ARE METRES AFT OF THE NOSE TIP and HEIGHTS ARE METRES OVER THE GROUND WITH THE GEAR DOWN, as in
## `SkyhawkAirframe` and `TomcatAirframe`. **AND EVERY STATION HERE IS ITS OWN MEASUREMENT.** `lane/harriershape`
## (2026-09-20) put an AV-8B's intakes round its nose with every check green, because NOT ONE PUBLISHED FIGURE ABOUT AN
## AEROPLANE IS A STATION -- lengths, spans, heights, tracks and angles all survive sliding a component anywhere along
## the body. This sheet is a rare exception: the printed **7.09 m wheelbase is a station difference**, and it is what
## sets the side view's scale. The gear stations below are then measured rather than judged, and everything else along
## the body was read at that scale and says so.
##
## TESSELLATION, STATED SO NOBODY SUBDIVIDES IT. The user's direction of 2026-09-17: a lower-poly look, no very round
## edges, the Hawkeye as the reference. Every count here is at or below the Hawkeye's for the same kind of part:
## - FUSELAGE_SIDES 14 (seven facets a side), against the Hawkeye's 20;
## - INTAKE_SIDES 10 and NOZZLE_PETALS 12, against its 16 on a nacelle;
## - WHEEL_SIDES 8, and a wing section of four facets -- a flat bottom and two top facets meeting at a ridge.
## Every face carries its own normal; nothing is smoothed. FIDELITY IS PROPORTION AND FEATURE, NOT TRIANGLES.
##
## WHAT "SLIGHTLY HIGHER QUALITY THAN NORMAL" WAS SPENT ON, since the user asked for it: more REAL THINGS, taken from
## the flight manual's own Figure FO-1 GENERAL ARRANGEMENT, which names and places every external fitting. Not
## roundness. The splitter plates and their boundary-layer gap, the gun fairing and its muzzle, the hook and its well,
## the gear doors as separate leaves, the slats and flaps as distinct surfaces, the nozzles as PETALS rather than
## cylinders, the refuelling receptacle, the formation-light strips, the aerials.
##
## NOT IN VehicleView's `_body`: `_show_body` paints one flat material over every mesh there, and this airframe's
## colour is in its vertices (`lane/fleet`, Hawkeye).

const LENGTH: float = 19.202          # [FM] 63 ft 0 in
const SPAN: float = 11.709            # [FM] 38 ft 5 in
const HEIGHT: float = 5.004           # [FM] 16 ft 5 in -- FITTED TO; see the doc block
const TRACK: float = 5.461            # [FM] 17 ft 11 in, main gear
const WHEELBASE: float = 7.090        # [TO] printed, and THE ONLY PRINTED STATION FIGURE on the sheet

## THE PAINT. A USAF F-4E in South-East Asia camouflage is three greens and a tan; a late one is the two-tone "Hill"
## greys or plain gunship grey. Drawn in gunship grey, FS 36118 over a lighter underside -- ESTIMATE, sRGB
## approximations. Section 4 of `modelling_here.md`: `SurfaceTool.commit` quantises vertex colour to eight bits a
## channel, so every colour a check must tell apart is kept at least 0.03 from every other in some channel, and the
## suite enumerates them off this file's own constants rather than a typed list.
const GREY := Color(0.36, 0.38, 0.40)
const BELLY := Color(0.47, 0.49, 0.51)
const DARK := Color(0.14, 0.15, 0.16)
const METAL := Color(0.31, 0.30, 0.29)
const BURNT := Color(0.24, 0.22, 0.21)
const TYRE := Color(0.06, 0.06, 0.06)
const GLASS := Color(0.17, 0.22, 0.27)
const RADOME := Color(0.22, 0.23, 0.25)

## ---- the fuselage ---------------------------------------------------------------------------------------------

## THE BODY [M], read off [TO]'s side view at 100.42 px/m and its plan view at 99.40 px/m across. Rows are
## [station, half width, top, bottom]. The two views are scaled SEPARATELY and on their own axes, because the sheet is
## stretched about one per cent ALONG the aeroplane: its two spanwise readings agree to the second decimal (99.40 from
## the span, 99.40 from the stabilator span, which nothing was scaled by) while its two lengthwise readings sit one per
## cent away (100.26 plan, 100.42 side). Noise does not sort itself by axis.
##
## WHOSE NUMBER EACH ROW IS, because `lane/harriershape` followed a gun pod down and drew a body that swallowed it:
## - to station 3.4 the top is the RADOME and the bottom the belly;
## - 3.8 to 4.4 the LOWEST ink is the NOSE GEAR (its axle is a measured station, below) and the belly is read from the
##   run above it;
## - 5.0 to 6.2 the top is the two CANOPIES, with the frame between them at 5.6 -- the dip is real and is drawn;
## - 6.8 to 9.4 the top is the SPINE;
## - 10.4 to 12.4 the lowest ink is the MAIN GEAR and the external tank;
## - **from 10.4 aft the spine could not be separated from the wing in this scan and is INTERPOLATED between the
##   measured 2.73 at station 9.4 and the fin root. It is the one judged stretch in this table and it is named here
##   rather than given a plausible number.**
const SECTIONS: Array = [
	[0.00, 0.020, 1.546, 1.505],
	[0.30, 0.050, 1.600, 1.485],
	[0.60, 0.085, 1.625, 1.503],
	[1.00, 0.262, 1.820, 1.004],
	[1.40, 0.352, 2.000, 0.924],
	[1.80, 0.437, 2.130, 0.922],
	[2.20, 0.478, 2.220, 0.930],
	[2.60, 0.502, 2.300, 0.949],
	[3.00, 0.523, 2.370, 0.968],
	[3.40, 0.545, 2.430, 0.986],
	[3.83, 0.566, 2.470, 0.943],
	[4.40, 0.598, 2.560, 0.938],
	[5.00, 0.644, 2.620, 0.914],
	[5.60, 0.700, 2.660, 0.860],
	[6.20, 0.742, 2.700, 0.827],
	[6.80, 0.762, 2.730, 0.875],
	[7.40, 0.775, 2.760, 1.242],
	[8.00, 0.780, 2.770, 1.180],
	[8.60, 0.780, 2.770, 1.287],
	[9.40, 0.775, 2.760, 1.264],
	[10.40, 0.765, 2.740, 1.192],
	[11.40, 0.750, 2.720, 1.248],
	[12.40, 0.735, 2.700, 1.214],
	[13.40, 0.715, 2.670, 1.171],
	[14.20, 0.700, 2.650, 1.119],
	[15.00, 0.680, 3.060, 1.140],
	[16.00, 0.660, 2.980, 1.190],
	[17.00, 0.640, 2.870, 1.240],
	[18.00, 0.610, 2.700, 1.300],
	[19.20, 0.540, 2.380, 1.430],
]
const FUSELAGE_SIDES: int = 14

## THE TWO CANOPIES [M], AS THEIR OWN PART. Baked into the fuselage ring they drew as dark panels lying flat on the
## deck: the first front-quarter picture showed an aeroplane with no greenhouse at all, and not one dimension check
## could have said so -- CLAUDE.md rule 2 on a canopy. The body's deck is at about 2.7 m and the canopy stands up to
## the printed 3.28-3.33, NARROWER than the body, and that difference in width is what makes a Phantom cockpit read
## from a three-quarter view. They are also separate because on this aeroplane they OPEN, and step 2 will hinge them.
const WINDSCREEN_BASE: float = 3.83
const FRONT_CANOPY: Vector2 = Vector2(4.40, 5.70)
const CANOPY_FRAME: Vector2 = Vector2(5.70, 6.02)
const REAR_CANOPY: Vector2 = Vector2(6.02, 7.62)
const CANOPY_HALF: float = 0.455
## THE CANOPY'S TOP at each end and at its peak [M], over the body's deck.
## HOW FAR THE CANOPY SHELL REACHES BELOW THE DECK. It is not a styling number and nothing outside can see it: it
## is what makes the canopy a CLOSED volume around the whole station instead of a lid resting on one.
const TUB_FLOOR: float = 1.45
const CANOPY_TOP: float = 3.330
const CANOPY_AFT_TOP: float = 3.280
## THE SPINE FAIRING behind the rear canopy, which carries the deck up to the fin [M]. It is what the printed 3.28 m
## dimension is measured to, over stations 7.36 to 14.74 -- the figure this lane first mistook for a construction line
## and masked, drawing the whole aeroplane half a metre too flat until the overlay found it.
##
## THE REAR FUSELAGE TOP AFT OF STATION 15 IS JUDGED, AND IS NAMED AS JUDGED. The drawing cannot give it: aft of the
## fin's leading edge the topmost ink IS THE FIN, so there is no station at which the body's own top can be read. The
## rows above run from the spine's 3.28 down to the boat-tail over the nozzles, chosen so the body MEETS the fin's
## root -- which is what the side overlay is actually holding. The first version let it fall to 2.25 and left a band
## of nothing half a metre deep and four metres long between the body and the fin, invisible to every dimension check
## and obvious in one picture. `lane/harriershape` named its own judged stretch for the same reason.
const SPINE: Vector3 = Vector3(7.20, 14.60, 3.280)   # from, to, top; it runs INTO the fin's root
const SPINE_HALF: float = 0.30

## THE PITOT on the radome tip [FO-1 names it]: the drawn length starts at its point.
const PITOT_HEIGHT: float = 1.53

## ---- the wing -------------------------------------------------------------------------------------------------

## THE WING [M], every figure from `measure_manual.py`, tracked by continuity from the tip and never from "the
## outermost ink at each station" -- which on the Harrier's sheet tracked pylons and gave four plausible numbers wrong
## together, with only the residual dissenting.
##
## THE DOGTOOTH FOUND ITSELF. One straight fit over all 447 tracked rows gives 50.19 degrees at 7.92 px rms; a
## two-segment fit with the split SEARCHED FOR rather than typed gives 0.99 px, eightfold better, and puts the break at
## **4.044 m out** with the two leading edges **316 mm apart** there. And the front view's two dashed lines -- the ones
## the 8.41 m folded span is printed between -- stand **4.059 m** out at that view's own scale. 0.4 per cent apart,
## NEITHER USED TO FIND THE OTHER, and on a real F-4 the dogtooth is at the fold joint.
const ROOT_LE: float = 5.913          # station, at the centreline
const ROOT_TE: float = 13.150
const BREAK_OUT: float = 4.044
const BREAK_LE: float = 10.992        # the INBOARD panel's leading edge at the break
const BREAK_TE: float = 14.126
const DOGTOOTH: float = 0.316         # how far the outer panel's leading edge stands forward of it
const TIP_OUT: float = 5.855          # SPAN * 0.5 = 5.855; the drawn tip agrees
const TIP_LE: float = 13.181
const TIP_TE: float = 14.563
## OUTER PANEL DIHEDRAL: **12 degrees** [PUB], and the model is built to the published figure. The drawn underside
## measures about 13.5, which is what a wing whose section thins outboard does to an underside reading -- the chord
## plane is the datum and the underside is not. `lane/harrier` made the same choice about its parked rake for the same
## reason: this sheet's geometry is demonstrably less reliable than its figures.
const DIHEDRAL: float = 12.0
## The inboard panel is flat [PUB]: 12 degrees outboard averaging to 5 across the span is only true of a flat inner.
const INNER_DIHEDRAL: float = 0.0
## Thickness [PUB]: NACA 0006.4-64 at the root, 0003-64 at the tip -- 6.4 and 3.0 per cent. On a 7.237 m root that is
## 0.46 m. Drawn at 0.30 and 0.06: at the range a wing is seen from, a true 6.4 per cent root reads as a slab.
const ROOT_THICK: float = 0.30
const TIP_THICK: float = 0.06
## THE WING'S PLANE [M]: its underside at the root, off the side view.
const WING_UNDER: float = 1.24

## THE SLATS, FLAPS AND AILERONS as distinct surfaces rather than panel lines, which is where "slightly higher quality"
## is spent. Spans are fractions of the semi-span; chords are fractions of the local chord.
## The E has LEADING EDGE SLATS inboard and outboard [FM's differences table] and NO boundary layer control.
const SLAT_INBOARD: Vector2 = Vector2(0.28, 0.69)     # inboard slat, ends at the dogtooth
const SLAT_OUTBOARD: Vector2 = Vector2(0.71, 0.97)
const SLAT_CHORD: float = 0.13
const FLAP_SPAN: Vector2 = Vector2(0.14, 0.66)
const AILERON_SPAN: Vector2 = Vector2(0.70, 0.96)
const SURFACE_CHORD: float = 0.24

## ---- the tail -------------------------------------------------------------------------------------------------

## THE STABILATOR [M]: all-moving, and its **23 degrees of ANHEDRAL** [PUB] are the second thing that makes a Phantom
## a Phantom. Its span measures 5.05 m against a printed 5.0 -- and nothing was scaled by that figure, so it is the
## plan view's free check.
const STAB_OUT: float = 2.525
const STAB_ROOT_LE: float = 15.10
const STAB_ROOT_TE: float = 18.70
const STAB_TIP_LE: float = 18.30
const STAB_TIP_TE: float = 18.97
const STAB_ROOT_HEIGHT: float = 2.05
const ANHEDRAL: float = 23.0
const STAB_THICK: Vector2 = Vector2(0.16, 0.05)

## THE FIN [M] off the side view, with its tip at [FM]'s published height. The rudder is the aft strip.
const FIN_LE: float = 14.30
const FIN_TE: float = 18.90
const FIN_ROOT_HEIGHT: float = 3.16
## HOW FAR THE FIN AND THE RUDDER ARE BURIED IN THE BODY. **THE FIN WAS DETACHED.** Its root was drawn at
## FIN_ROOT_HEIGHT over its whole chord while the deck under it falls from 3.23 to 2.70, so aft of about station 15 it
## floated clear of the aeroplane -- and `modelling_here.md` has that exact rule: "A PART CAN COME OFF, AND NOTHING
## WILL SAY SO", after the tanker's tail assembly hung in mid-air and survived every suite indefinitely. A dimension is
## right whether or not the part is joined on, and a box round a detached part still contains it. Only the side overlay
## showed it, as a white band between the fin's foot and the body. The root ring is now carried down to FIN_BURIED,
## below the lowest deck under the fin, by EXTRAPOLATING the same leading and trailing edges rather than by moving them
## -- so the drawn sweep is untouched and the body simply swallows the root. `tests/phantom.gd:_nothing_floats` now
## asks it of the drawn boxes.
const FIN_TIP_LE: float = 17.15
const FIN_TIP_TE: float = 18.72
const FIN_THICK: Vector2 = Vector2(0.22, 0.07)
const RUDDER_CHORD: float = 0.26
const FIN_BURIED: float = 2.58

## ---- the intakes and the nozzles -------------------------------------------------------------------------------

## THE INTAKES [M]. The plan view shows three nested edges each side between stations 6.2 and 8: the duct's outer wall
## at 1.40 m out, the fuselage side at about 0.78, and the splitter standing between them. **The gap between the
## splitter and the skin is the boundary-layer diverter and it is drawn open**, because on a Phantom you can see
## daylight through it and it is one of the features the brief named.
const INTAKE_MOUTH: float = 6.20
const INTAKE_AFT: float = 9.60
const INTAKE_OUT: float = 1.40        # the duct's outer wall
const INTAKE_TOP: float = 2.42
const INTAKE_BOTTOM: float = 1.16
const SPLITTER_GAP: float = 0.12      # daylight between the splitter and the fuselage skin
const SPLITTER_LEAD: float = 0.34     # how far the splitter's lip stands ahead of the duct's
const INTAKE_SIDES: int = 10
## THE VARIABLE RAMP, named on FO-1: the wedge inside the mouth that schedules the throat.
const RAMP_AFT: float = 0.90

## THE NOZZLES [M]: two, close together, the "variable area exhaust nozzle" of FO-1, drawn as PETALS rather than as a
## cylinder because that is what a J79's nozzle is and it costs 96 triangles for the pair.
const NOZZLE: Vector2 = Vector2(18.30, 19.20)   # from, to; the nozzle is the aftmost point
const NOZZLE_OUT: float = 0.62
const NOZZLE_HEIGHT: float = 1.72
const NOZZLE_RADIUS: Vector2 = Vector2(0.50, 0.44)
const NOZZLE_PETALS: int = 12

## ---- the gun, the hook and the gear ----------------------------------------------------------------------------

## THE M61A1 AND ITS FAIRING [FO-1 names the gun and the ammunition drum, and the side view draws the fairing]. This is
## the E, and the fairing under the nose is what says so at a glance.
const GUN_FAIRING: Vector3 = Vector3(1.70, 4.30, 0.94)   # from, to, lowest point
const GUN_HALF: float = 0.30
const MUZZLE: float = 1.86

## THE ARRESTER HOOK [FO-1], stowed: between and below the nozzles, which is where a Phantom's is.
const HOOK_ROOT: float = 17.40
const HOOK_TIP: float = 19.05
const HOOK_HEIGHT: Vector2 = Vector2(1.36, 1.08)

## THE GEAR. **THE TWO AXLE STATIONS ARE MEASURED, NOT JUDGED** -- the printed 7.09 m wheelbase is a station
## difference, so its two extension lines land on the two axles and the side view's scale comes from the same figure.
const NOSE_GEAR_STATION: float = 4.182
const MAIN_GEAR_STATION: float = 11.272
const NOSE_TYRE_RADIUS: float = 0.27
const MAIN_TYRE_RADIUS: float = 0.42
const MAIN_TYRE_WIDE: float = 0.30
const WHEEL_SIDES: int = 8

## THE CREW [M] off the canopies, ESTIMATE within them: the front seat sits noticeably higher and further forward, the
## rear is stepped down, which is a Phantom recognition feature in its own right.
const PILOT_EYE: Vector2 = Vector2(4.90, 2.92)   # station, height
const WSO_EYE: Vector2 = Vector2(6.35, 2.90)

## THE ROOM the crew sit in. ESTIMATE inside the measured canopies; see `cabin_room`.
const ROOM: AABB = AABB(Vector3(-0.30, 1.62, 4.35), Vector3(0.60, 1.20, 2.70))
const CABIN_FLOOR: float = 1.62

## ---- what moves, and how far -----------------------------------------------------------------------------------

## THE TRAVELS. Each surface is a PURE SETTER of an amount: `set_x(0.3)` then `set_x(0.7)` draws exactly what
## `set_x(0.7)` draws, holding no memory and no timer, as `TomcatAirframe`'s and `SkyhawkAirframe`'s do. Nothing here
## is driven yet -- there is no craft kind until the next commit -- and a probe poses any of them.
##
## THE F-4E ROLLS WITH AILERONS AND SPOILERS and pitches with its ALL-MOVING STABILATORS, which also roll it
## differentially. The spoilers are not drawn: they are small upper-surface panels the drawing does not resolve, and
## `sources.md` says so rather than the model inventing them. The slats and flaps are the E's own -- the differences
## table gives it LEADING EDGE SLATS and NO boundary layer control, so the leading edge is a slat and not a blown flap.
## ESTIMATE on every travel; no public figure for any of them was found, and they are what a Phantom looks like doing
## it rather than what a maintenance manual would rig.
const SLAT_TRAVEL: float = 24.0        # down and forward, the full extension
const FLAP_TRAVEL: float = 40.0        # down, the landing setting
const AILERON_TRAVEL: float = 20.0     # each way
const RUDDER_TRAVEL: float = 28.0      # each way
const STAB_PITCH_TRAVEL: Vector2 = Vector2(14.0, 20.0)   # trailing edge up, down
const STAB_ROLL_TRAVEL: float = 7.0    # differential, on top of the pitch
const CANOPY_TRAVEL: float = 42.0      # both canopies hinge up at the rear, as a Phantom's do
## THE NOZZLE is not hinged: a J79's variable-area nozzle changes its EXIT AREA, so the petals are scaled about the
## nozzle's own axis rather than turned. 1.0 is the drawn (military) position; the afterburner setting opens it.
const NOZZLE_OPEN: float = 1.22
## ROWS IN EACH FEATURE'S VAT TABLE. Between two rows the shader blends a turn linearly, so a plain hinge needs far
## fewer than a swing wing; 65 is what `TomcatAirframe` settled on for its surfaces and is kept for the same reason.
const SURFACE_ROWS: int = 65

const DETAIL_RANGE: float = 800.0
const DETAIL_HYSTERESIS: float = 80.0

var _half: Vector3 = Vector3(2.0, 1.25, 9.60)
var _material: StandardMaterial3D
## THE SHEET OF DIRT, built in `_paint` and kept so a test can ask it about a vertex it reads off the drawn mesh.
var _stains: StainSheet = null
## Set FALSE before `dress` to draw the aeroplane factory-fresh. The pixel check flies the same aeroplane twice,
## once each way, and requires the exhaust to darken and the radome not to move -- which is the only anchor
## outside the sheet's own frame, and a UV check alone passes happily on a blank image.
var wear: bool = true
var _hinges: Dictionary = {}
var _nozzles: Array[Node3D] = []
var _slats: float = 0.0
var _flaps: float = 0.0
var _ailerons: float = 0.0
var _rudder_at: float = 0.0
var _stab_pitch: float = 0.0
var _stab_roll: float = 0.0
var _canopies: float = 0.0
var _nozzle_at: float = 0.0


## THE DRAFT BOX, until there is a `Sim.Kind.PHANTOM` in step 2. `TomcatAirframe` and `ProwlerAirframe` both stood on
## one of these first and it is the same shape: half-extents that rest on the ground.
func dress(geometry: Dictionary = {}) -> void:
	name = "Phantom"
	if not geometry.is_empty():
		_half = geometry.get("extents", _half) as Vector3
	_material = _paint()
	var skin := _tool()
	_fuselage(skin)
	_pitot(skin)
	_add("Fuselage", skin)
	_canopy_parts()
	var spine := _tool()
	_spine(spine)
	_add("Spine", spine)
	var fairing := _tool()
	_gun_fairing(fairing)
	_add("GunFairing", fairing)
	var fin := _tool()
	_fin(fin)
	_add("Fin", fin)
	_rudder_part()
	var hook := _tool()
	_hook(hook)
	_detail(_add("ArresterHook", hook))
	var nose_gear := _tool()
	_nose_gear(nose_gear)
	_detail(_add("NoseGear", nose_gear))
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var intake := _tool()
		_intake(intake, side)
		_add("Intake" + named, intake)
		var splitter := _tool()
		_splitter(splitter, side)
		_detail(_add("Splitter" + named, splitter))
		var wing := _tool()
		_wing(wing, side)
		_add("Wing" + named, wing)
		_wing_surface_parts(side, named)
		_stabilator_part(side, named)
		_nozzle_part(side, named)
		var main := _tool()
		_main_gear(main, side)
		_detail(_add("MainGear" + named, main))
	follow_the_stick(Vector2.ZERO, 0.0)
	set_slats(0.0)
	set_flaps(0.0)
	set_canopies(0.0)
	set_nozzle(0.0)


## ---- the frame ---------------------------------------------------------------------------------------------------

## STATIONS are metres aft of the nose tip.
func station(s: float) -> float:
	return -_half.z + s


## HEIGHTS are metres over the ground with the gear down; the draft box rests on the ground.
func height(h: float) -> float:
	return h - _half.y


## A point at `out` metres from the centreline (+ starboard), `h` over the ground, station `s`.
func point(out: float, h: float, s: float) -> Vector3:
	return Vector3(out, height(h), station(s))


## THE WING'S LEADING EDGE at `out` metres from the centreline, in stations. Two straight segments with the dogtooth's
## step between them, which is the shape `measure_manual.py` fitted and is the reason the residual fell eightfold.
func wing_le(out: float) -> float:
	var o: float = absf(out)
	if o <= BREAK_OUT:
		return lerpf(ROOT_LE, BREAK_LE, o / BREAK_OUT)
	var t: float = (o - BREAK_OUT) / (TIP_OUT - BREAK_OUT)
	return lerpf(BREAK_LE - DOGTOOTH, TIP_LE, t)


## THE WING'S TRAILING EDGE at `out` metres from the centreline. One straight line: the drawing shows no kink.
func wing_te(out: float) -> float:
	var o: float = absf(out)
	if o <= BREAK_OUT:
		return lerpf(ROOT_TE, BREAK_TE, o / BREAK_OUT)
	return lerpf(BREAK_TE, TIP_TE, (o - BREAK_OUT) / (TIP_OUT - BREAK_OUT))


## THE WING'S UNDERSIDE at `out` metres out: flat inboard, then 12 degrees up [PUB] beyond the break.
func wing_under(out: float) -> float:
	var o: float = absf(out)
	if o <= BREAK_OUT:
		return WING_UNDER
	return WING_UNDER + (o - BREAK_OUT) * tan(deg_to_rad(DIHEDRAL))


## THE STABILATOR'S HEIGHT at `out` metres out: 23 degrees DOWN [PUB].
func stab_height(out: float) -> float:
	return STAB_ROOT_HEIGHT - absf(out) * tan(deg_to_rad(ANHEDRAL))


## THE ROOM ROUND THE CREW, as `SkyhawkAirframe.cabin_room` publishes it: the largest box that can be PROMISED inside
## the drawn skin, the floor beside it rather than as its bottom, and a sentence when it is not drawn.
func cabin_room() -> Dictionary:
	var low := point(ROOM.position.x, ROOM.position.y, ROOM.position.z)
	var high := point(ROOM.end.x, ROOM.end.y, ROOM.end.z)
	return {
		"drawn": true,
		"floor": height(CABIN_FLOOR),
		"room": AABB(low, high - low).abs(),
		"because": &"",
		"why_not": "",
		"source": "ESTIMATE inside the canopies measured off [TO]; see PhantomAirframe.ROOM",
	}


## THE TWO CREW EYES, pilot then WSO, in the craft's frame.
func crew_eyes() -> Array[Vector3]:
	return [point(0.0, PILOT_EYE.y, PILOT_EYE.x), point(0.0, WSO_EYE.y, WSO_EYE.x)]


## WHERE THE GAS LEAVES, for `ExhaustYard`. Two J79s, and the J79 is the smokiest engine ever put in a fighter -- the
## Phantom's smoke trail is what it was known for and what got it seen first. Declared in step 2 with the kind, so
## `tests/exhaust.gd`'s ratchet stays where it is rather than rising.
func exhaust_ports() -> Array:
	var ports: Array = []
	for side in [1.0, -1.0]:
		ports.append({
			"at": point(side * NOZZLE_OUT, NOZZLE_HEIGHT, NOZZLE.y),
			"axis": Vector3.BACK,
			"radius": NOZZLE_RADIUS.y,
			"kind": ExhaustTuning.Kind.JET,
			"heat": 1.0,
		})
	return ports


## THE AEROPLANE'S OWN DIRT: eight named marks, placed in metres off the stations this file already uses, so each
## one can be argued with against a photograph and moved by a mutant. Built once and kept, because `_tri` asks for
## the mapping on every vertex.
##
## WHY THESE EIGHT AND NOT A NOISE FIELD. A smudge generator makes an aeroplane that is dirty everywhere and
## interesting nowhere, and no test can say it is wrong. Each of these is a thing that happens to an F-4: the J79
## was a smoky engine and its soot runs back along the fuselage and under the belly; the E is the mark with the
## internal gun, so it alone gets gun gas streaking aft of the muzzle at station 1.86 (a C does not, and drawing
## it on one would be a lie about which aeroplane this is); crews walk the wing root inboard of the fold to reach
## the cockpit, and climb in past the same patch of side every time.
##
## TWO OF THEM ARE LIGHTER THAN THE PAINT, which is the whole reason this is a detail layer and not a multiplied
## `albedo_texture`: `le_erosion` is paint worn off a leading edge down to bright metal and `faded_patches` is sun
## on the upper surfaces. Under a multiply both are impossible -- every mark can only darken.
##
## A MARK'S SECOND RANGE MEANS HEIGHT ON A SIDE BAND AND DISTANCE FROM THE CENTRELINE ON AN UP OR DOWN ONE, so a
## mark spanning both wants numbers that read sensibly as each. `exhaust_soot` at 0.4 to 2.0 is the lower fuselage
## sides aft AND the belly just outboard of the nozzles, which is where an F-4's soot actually is. Where the two
## readings could not be made to agree -- the gun, which is on the centreline but streaks along the side -- the
## mark is given the one band it belongs on rather than fudged onto both.
## THE SHEET THIS AEROPLANE WEARS, so a test can ask it about a vertex it has just read off the drawn mesh rather
## than rebuilding a second sheet and comparing two guesses.
## THE BAKED SHEET, ONCE FOR EVERY PHANTOM EVER BUILT. Every F-4 wears the same dirt, so baking it per airframe was
## 2,951 ms of arithmetic repeated for each one -- against 6.9 ms to dress an aeroplane with the weathering off.
## Nothing failed: no suite times an airframe, and the cost only reached anybody when the kind got its
## `Terrain.spawns` row and the world started building Phantoms, where it surfaced as `no_vr_flight` timing out with
## no error printed. A static holds it for the life of the process.
static var _baked: ImageTexture = null


## AND IT CARRIES A MIP CHAIN, which is the difference between a weathered aeroplane and a speckled one.
##
## THE SHEET IS HIGH-FREQUENCY ON PURPOSE. `panel_line_dirt` is a 0.22 m band every 1.35 m, so across a
## 512-texel sheet cut for a 19.2 m aeroplane it is about fourteen hard bands roughly four texels wide.
## Sampled with no mip chain, a pixel covering many texels takes ONE of them, near enough at random --
## so at any distance the panel lines stop being panel lines and become a moving speckle over the whole
## airframe, and every one of those samples is a texture-cache miss as well. It is an aliasing artefact
## that reads exactly like dithering, which is what it was reported as.
##
## `Image.create` in `StainSheet.image` asks for no mipmaps and `ImageTexture.create_from_image` adds
## none, so before this line the F-4 -- the only textured aircraft in the project -- was the only thing
## here sampling a texture without one. `world/wind_sea.gd` had already learnt this for the sea.
func _baked_sheet() -> ImageTexture:
	if _baked == null:
		var sheet: Image = _sheet().image()
		sheet.generate_mipmaps()
		_baked = ImageTexture.create_from_image(sheet)
	return _baked


func stain_sheet() -> StainSheet:
	return _sheet()


## THE DRAFT BOX'S HALF-EXTENTS, which is what turns a local z back into a station.
func half_extents() -> Vector3:
	return _half

func _sheet() -> StainSheet:
	if _stains != null:
		return _stains
	_stains = StainSheet.new(LENGTH, HEIGHT, SPAN * 0.5)
	var S := StainSheet.Face.SIDE
	var U := StainSheet.Face.UP
	var D := StainSheet.Face.DOWN
	# Aft of the nozzles and under them. The heaviest mark on the aeroplane, because the J79 earned it.
	# THE HEIGHT RANGE IS THE WHOLE REAR FUSELAGE SIDE, not just the band level with the pipes. Cut at 2.4 m it
	# left the top third of the flank clean and the rendered darkening came out at 4% where the sheet promised
	# far more -- the mark was weaker than its own strength said because it only covered part of what it is drawn
	# on. Measured, not guessed: `tests/phantom_wear_shot.gd` is what said so.
	_stains.mark("exhaust_soot", [S, D], 16.2, LENGTH, 0.3, 2.9, Color(0.11, 0.10, 0.09), 0.76)
	# Hotter, browner, and only on the last metre where the petals are.
	_stains.mark("nozzle_heat", [S, D], 18.1, LENGTH, 0.3, 2.2, Color(0.34, 0.21, 0.14), 0.66)
	# Aft of the M61A1's muzzle at station 1.86. SIDE only: the gun is on the centreline but its gas streaks
	# along the fuselage flank, and a belly band at the same numbers would put it out on the intake ducts.
	_stains.mark("gun_gas", [S], 2.6, 7.5, 0.6, 1.5, Color(0.15, 0.14, 0.13), 0.54)
	# The wing root inboard of the fold line, which is the way to the cockpit.
	_stains.mark("walkway_wear", [U], ROOT_LE + 0.3, ROOT_TE - 1.4, 0.9, 2.6, Color(0.24, 0.25, 0.26), 0.40)
	# The patch of side a crew climbs past, forward of the wing and under the front canopy.
	_stains.mark("boot_marks", [S], 4.0, 6.0, 1.0, 2.4, Color(0.19, 0.19, 0.20), 0.32)
	# GRIME AT THE JOINS, AND CLEAN PAINT BETWEEN THEM: a 0.22 m band every 1.35 m, and not one box over the
	# whole aeroplane. Written that way first it covered 100% of the sheet at a mean alpha of 0.175 -- a flat veil
	# that dirtied the radome exactly as much as the tailpipe. It starts aft of the radome because a dielectric
	# nose cone has no panel lines to gather anything -- and the RADOME IS THE CONTROL SURFACE OF THE PIXEL CHECK,
	# the one place the sheet is deliberately clean, so anything that creeps forward onto it is measured as a
	# failure rather than admired as extra dirt.
	_stains.mark("panel_line_dirt", [S, U, D], 3.5, LENGTH, 0.0, SPAN * 0.5, Color(0.22, 0.23, 0.24), 0.30, 1.35, 0.22)
	# Paint worn off the outer leading edges to bright metal. LIGHTER than the paint, which is the whole reason
	# this is a detail layer. FIRST DRAWN AT 0.32 OF A 0.66 GREY and the wing came back nearly white in the rear
	# quarter -- not a weathered aeroplane, a differently coloured one. A mark that changes what colour the
	# aircraft IS has stopped being weathering, and only the picture says where that line is.
	_stains.mark("le_erosion", [U, D], ROOT_LE, BREAK_LE + 1.5, 4.1, SPAN * 0.5, Color(0.56, 0.57, 0.59), 0.16)
	# Sun on the upper surfaces. Also lighter, and the faintest thing here.
	_stains.mark("faded_patches", [U], 7.5, 15.5, 0.0, 3.2, Color(0.47, 0.48, 0.49), 0.13)
	return _stains

func _paint() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	# Vertex colour is linear unless the material says otherwise: a 0.36 grey draws at about 0.63 without this
	# (`lane/carrier`).
	material.vertex_color_is_srgb = true
	material.roughness = 0.62
	material.metallic = 0.05

	# THE WEATHERING, AS A DETAIL LAYER ON UV2. `detail_albedo`'s own alpha is the mask even though this material
	# is OPAQUE -- where the sheet's alpha is zero the paint underneath is untouched, so a mark can be lighter as
	# well as darker. That behaviour was RENDERED and read back before any of this was written
	# (`tests/detail_probe.gd`); nothing in this workshop had used `detail_*` on a material before, and the class
	# reference is a claim rather than a measurement. UV1 is untouched, there is no second material and no second
	# draw call, and no shader -- so the VAT path, the mist pass and `lint.gd`'s see-through contract all stand.
	if wear:
		material.detail_enabled = true
		material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
		material.detail_albedo = _baked_sheet()
	return material


## ---- the builders ------------------------------------------------------------------------------------------------

## ONE FUSELAGE SECTION's ring, starboard from the top round to the bottom and back up the port side. The F-4's body is
## SLAB-SIDED and flat-bottomed -- that is half of why it reads as a Phantom and not as a fighter -- so the sides run
## nearly straight and the belly is wide and flat, with a single chamfer at each corner rather than a curve.
func _ring(row: Array) -> Array[Vector3]:
	var s: float = row[0]
	var hw: float = row[1]
	var top: float = row[2]
	var bottom: float = row[3]
	var shoulder: float = top - (top - bottom) * 0.22
	var chine: float = bottom + (top - bottom) * 0.20
	var half: Array[Vector2] = [
		Vector2(0.0, top),
		Vector2(hw * 0.66, top - (top - bottom) * 0.06),
		Vector2(hw, shoulder),
		Vector2(hw, chine),
		Vector2(hw * 0.70, bottom),
		Vector2(0.0, bottom),
	]
	var ring: Array[Vector3] = []
	for p in half:
		ring.append(point(p.x, p.y, s))
	for i in range(half.size() - 2, 0, -1):
		ring.append(point(-half[i].x, half[i].y, s))
	return ring


## THE FUSELAGE, and THE TWO CANOPIES cut into it. The glazing is every upper facet between the windscreen base and the
## rear canopy's end, LESS the frame between the cockpits, which is drawn opaque because it is a heavy steel bow on the
## real aeroplane and is one of the type's recognition features.
func _fuselage(tool: SurfaceTool) -> void:
	for r in range(SECTIONS.size() - 1):
		var a := _ring(SECTIONS[r])
		var b := _ring(SECTIONS[r + 1])
		var here: float = (float(SECTIONS[r][0]) + float(SECTIONS[r + 1][0])) * 0.5
		for k in range(a.size()):
			var n: int = (k + 1) % a.size()
			# THE COCKPIT IS A HOLE IN THE DECK, not a lid with glass laid over it. `_ring`'s first and last facets are the
			# two halves of the top, and between the windscreen base and the back of the rear canopy they are LEFT OUT.
			#
			# Drawn closed, the aeroplane looked right from outside and was wrong the moment anybody sat in it: the crew's
			# eyes are 2.92 m up and this deck is 2.62, so every eye sat above a sealed lid with its own instruments
			# underneath, and `screens_face` reported all four screens hidden `by Body/Phantom/Fuselage`. The screens were
			# where they belonged; the aeroplane had no cockpit opening.
			#
			# THIS ONLY WORKS BECAUSE THE CANOPY SHELLS REACH BELOW THE FLOOR (`TUB_FLOOR`). `shell_room` decides
			# containment by RAY PARITY, so cutting a hole in a closed mesh makes a ray up from the cockpit floor leave
			# through it and every part of the station reads as outside at once -- which is exactly what happened when this
			# was tried on its own. Cut the deck WITHOUT closing the canopy downward first and four suites go red together.
			# AND THE FRAME BETWEEN THE TWO CANOPIES IS NOT PART OF THE HOLE. Stations 5.70 to 6.02 carry the bow an F-4
			# really has between its canopies -- neither canopy is drawn there, so cutting the deck as well left a gap
			# over nothing. `pilot_seat` found it: 23 vertices of the front chair uncovered with the ray `open along
			# (0, 1, 0)`, which is the back of the pilot's headbox at about station 5.73 looking straight up at sky.
			var framed: bool = here >= CANOPY_FRAME.x and here <= CANOPY_FRAME.y
			if (k <= 1 or k >= a.size() - 2) and not framed and here > WINDSCREEN_BASE and here < REAR_CANOPY.y:
				continue
			var tint: Color = BELLY if k >= 3 and k <= 6 else GREY
			var quad: Array = [a[k], a[n], b[n], b[k]]
			_facet(tool, quad, _centre_of(quad) - (_centre_of(a) + _centre_of(b)) * 0.5, tint)
	_cap(tool, _ring(SECTIONS[-1]), Vector3.BACK, GREY)


## THE PITOT PROBE and the radome's point: a slender cone from the first section to the drawn nose tip at station zero.
func _pitot(tool: SurfaceTool) -> void:
	var ring := _ring(SECTIONS[0])
	var tip := point(0.0, PITOT_HEIGHT, 0.0)
	for k in range(ring.size()):
		var n: int = (k + 1) % ring.size()
		_tri(tool, tip, ring[k], ring[n], (ring[k] + ring[n]) * 0.5 - _centre_of(ring), RADOME)


## THE GUN FAIRING under the nose, with the muzzle in it. THE E'S SIGNATURE: the B, C, D and J have nothing here, and
## this fairing plus the longer slimmer radome is what tells an E from them at any distance.
## WHERE THE GUN PORT IS, in the craft's frame: the middle of the dark muzzle box `_gun_fairing` draws under the
## radome. COMPUTED FROM THE SAME TWO CONSTANTS THE MODEL DRAWS IT FROM, so the port and the port you can see are
## one fact and not two that agree today. `tests/jet_arms.gd` holds every round the simulation fires to this point,
## and deliberately does NOT read the loadout's muzzle -- a gun moved to the wrong place in C++ would otherwise
## agree with itself.
func gun_port() -> Vector3:
	return point(0.0, GUN_FAIRING.z + 0.02, MUZZLE)


func _gun_fairing(tool: SurfaceTool) -> void:
	var rows: Array = [
		[GUN_FAIRING.x, GUN_HALF * 0.55, 1.02, 1.00],
		[MUZZLE, GUN_HALF, 1.06, GUN_FAIRING.z],
		[2.90, GUN_HALF, 1.10, GUN_FAIRING.z + 0.02],
		[GUN_FAIRING.y, GUN_HALF * 0.70, 1.20, 1.06],
	]
	var rings: Array = []
	for row in rows:
		rings.append(_ring(row))
	_loft(tool, rings, func(_k: int) -> Color: return GREY, GREY, GREY)
	# THE MUZZLE, a dark port in the fairing's underside: the one thing a viewer looks for on an E.
	_box(tool, point(0.0, GUN_FAIRING.z + 0.02, MUZZLE), Vector3(0.20, 0.06, 0.34), DARK)


## THE TWO CANOPIES, standing on the body's deck and narrower than it. The heavy frame between the cockpits is drawn
## OPAQUE, because on the real aeroplane it is a steel bow and it is one of the features that says Phantom from the
## side. Glazing goes in its own SurfaceTool so the canopy is one mesh with a see-through second surface.
func _canopy_between(skin: SurfaceTool, glass: SurfaceTool, from: float, to: float) -> void:
	var rows: Array = []
	for i in range(7):
		var at: float = lerpf(from, to, float(i) / 6.0)
		rows.append([at, _canopy_half_at(at), _canopy_top_at(at)])
	for r in range(rows.size() - 1):
		var a: Array = rows[r]
		var b: Array = rows[r + 1]
		var here: float = (float(a[0]) + float(b[0])) * 0.5
		var ra := _canopy_ring(a)
		var rb := _canopy_ring(b)
		var centre: Vector3 = (_centre_of(ra) + _centre_of(rb)) * 0.5
		for k in range(ra.size()):
			var n: int = (k + 1) % ra.size()
			var quad: Array = [ra[k], ra[n], rb[n], rb[k]]
			# THE FACET ALONG THE DECK IS NOT GLASS, and it is 3->4, not the last one. `_canopy_ring` returns six
			# points -- two at the crown, two at the shoulders, two ON THE DECK at indices 3 and 4 -- so the segment
			# lying on the deck is k == 3. `k == ra.size() - 1` is 5->0, which is the PORT UPPER SIDE: the canopy was
			# being drawn with a glazed underside and one opaque grey panel up its left flank. Nothing failed, because
			# no check asks which facet of a canopy is glass; it was found reading the ring while chasing something
			# else (`tests/shell_room.gd`, which counts every surface either way).
			var sits: bool = k >= 3 and k <= 5
			var glazed: bool = not sits and here > WINDSCREEN_BASE
			_facet(glass if glazed else skin, quad, _centre_of(quad) - centre, GLASS if glazed else GREY)
	_cap(skin, _canopy_ring(rows[0]), Vector3.FORWARD, GREY)
	_cap(skin, _canopy_ring(rows[-1]), Vector3.BACK, GREY)


## THE CANOPY'S HALF WIDTH and TOP at a station, so a canopy that is drawn in two pieces still has one profile and
## the two meet. One number, one place.
func _canopy_half_at(s: float) -> float:
	if s <= FRONT_CANOPY.x:
		return lerpf(0.30, CANOPY_HALF * 0.86, (s - WINDSCREEN_BASE) / maxf(FRONT_CANOPY.x - WINDSCREEN_BASE, 1e-6))
	if s >= REAR_CANOPY.y - 0.4:
		return lerpf(CANOPY_HALF * 0.96, CANOPY_HALF * 0.55, (s - (REAR_CANOPY.y - 0.4)) / 0.4)
	return CANOPY_HALF


func _canopy_top_at(s: float) -> float:
	if s <= FRONT_CANOPY.x:
		return lerpf(_section_at(WINDSCREEN_BASE, 2), 3.120, (s - WINDSCREEN_BASE) / maxf(FRONT_CANOPY.x - WINDSCREEN_BASE, 1e-6))
	if s <= FRONT_CANOPY.y:
		return lerpf(3.120, CANOPY_TOP, (s - FRONT_CANOPY.x) / maxf(FRONT_CANOPY.y - FRONT_CANOPY.x, 1e-6))
	return lerpf(CANOPY_TOP - 0.02, CANOPY_AFT_TOP - 0.02, (s - FRONT_CANOPY.y) / maxf(REAR_CANOPY.y - FRONT_CANOPY.y, 1e-6))


## ONE CANOPY SECTION: a flat-topped arch on the deck, four facets a side, faceted like everything else.
func _canopy_ring(row: Array) -> Array[Vector3]:
	var s: float = row[0]
	var hw: float = row[1]
	var top: float = row[2]
	var deck: float = _section_at(s, 2)
	# EIGHT POINTS, NOT SIX: the two at TUB_FLOOR carry the shell down past the cockpit floor, so the canopy is a
	# closed volume containing the crew's eyes AND the floor they sit on AND the screens in front of them. See
	# `_canopy_between` for why that matters and what it cost.
	return [
		point(-hw * 0.52, top, s), point(hw * 0.52, top, s),
		point(hw, lerpf(deck, top, 0.45), s), point(hw * 1.10, deck, s),
		# THE TUB FLARES BELOW THE DECK, wider than the glass above it. Nothing outside can see it -- it is inside
		# the fuselage -- and at the canopy's own 0.92 the starboard corner of the front seat's map screen poked
		# through the wall, which `screens_face` reported as hidden `by CanopyFront`. 1.25 clears it and is still
		# well inside the fuselage's half width there.
		point(hw * 1.25, TUB_FLOOR, s), point(-hw * 1.25, TUB_FLOOR, s),
		point(-hw * 1.10, deck, s), point(-hw, lerpf(deck, top, 0.45), s),
	] as Array[Vector3]


## THE SPINE FAIRING behind the rear canopy, carrying the deck up to the printed 3.28 m and back to the fin.
func _spine(tool: SurfaceTool) -> void:
	var rings: Array = []
	for pair in [[SPINE.x, 0.35], [8.60, 1.0], [11.00, 1.0], [13.00, 0.92], [SPINE.y, 0.70]]:
		var s: float = pair[0]
		var grown: float = pair[1]
		var deck: float = _section_at(s, 2)
		var top: float = lerpf(deck, SPINE.z, grown)
		var hw: float = SPINE_HALF * (0.55 + 0.45 * grown)
		rings.append([
			point(-hw * 0.6, top, s), point(hw * 0.6, top, s),
			point(hw, deck, s), point(-hw, deck, s),
		] as Array[Vector3])
	_loft(tool, rings, func(k: int) -> Color: return GREY, GREY, GREY)


## AN INTAKE DUCT: the raked mouth, the outer wall standing off the fuselage, and the loft aft into the wing root.
func _intake(tool: SurfaceTool, side: float) -> void:
	var rows: Array = [
		[INTAKE_MOUTH, INTAKE_OUT * 0.92, INTAKE_TOP, INTAKE_BOTTOM + 0.06],
		[INTAKE_MOUTH + 0.9, INTAKE_OUT, INTAKE_TOP + 0.04, INTAKE_BOTTOM],
		[INTAKE_MOUTH + 2.0, INTAKE_OUT * 0.98, INTAKE_TOP, INTAKE_BOTTOM + 0.04],
		[INTAKE_AFT, INTAKE_OUT * 0.80, INTAKE_TOP - 0.10, INTAKE_BOTTOM + 0.18],
	]
	var rings: Array = []
	for row in rows:
		var inner: float = _fuselage_half(row[0]) + SPLITTER_GAP
		rings.append(_duct_ring(side, row[0], inner, row[1], row[2], row[3]))
	_loft(tool, rings, func(_k: int) -> Color: return GREY, DARK, GREY)


## ONE DUCT RING: a box section standing off the fuselage side, `inner` to `outer` metres out.
func _duct_ring(side: float, s: float, inner: float, outer: float, top: float, bottom: float) -> Array[Vector3]:
	return [
		point(side * inner, top, s), point(side * outer, top - 0.05, s),
		point(side * outer, bottom + 0.05, s), point(side * inner, bottom, s),
	] as Array[Vector3]


## THE SPLITTER PLATE, standing `SPLITTER_GAP` off the skin with its lip ahead of the duct's, AND THE GAP LEFT OPEN.
## On a Phantom you can see daylight through the boundary-layer diverter, and the brief named it.
func _splitter(tool: SurfaceTool, side: float) -> void:
	var lip: float = INTAKE_MOUTH - SPLITTER_LEAD
	for pair in [[lip, INTAKE_MOUTH], [INTAKE_MOUTH, INTAKE_AFT]]:
		var a: float = pair[0]
		var b: float = pair[1]
		var ia: float = _fuselage_half(a) + SPLITTER_GAP
		var ib: float = _fuselage_half(b) + SPLITTER_GAP
		_block(tool, [
			point(side * ia, INTAKE_BOTTOM + 0.10, a), point(side * (ia + 0.04), INTAKE_BOTTOM + 0.10, a),
			point(side * (ia + 0.04), INTAKE_TOP - 0.06, a), point(side * ia, INTAKE_TOP - 0.06, a),
			point(side * ib, INTAKE_BOTTOM + 0.16, b), point(side * (ib + 0.04), INTAKE_BOTTOM + 0.16, b),
			point(side * (ib + 0.04), INTAKE_TOP - 0.12, b), point(side * ib, INTAKE_TOP - 0.12, b),
		], METAL)
	# THE VARIABLE RAMP, named on FO-1: the wedge inside the mouth.
	_block(tool, [
		point(side * (_fuselage_half(INTAKE_MOUTH) + SPLITTER_GAP + 0.06), INTAKE_BOTTOM + 0.14, INTAKE_MOUTH),
		point(side * (INTAKE_OUT - 0.08), INTAKE_BOTTOM + 0.14, INTAKE_MOUTH),
		point(side * (INTAKE_OUT - 0.08), INTAKE_TOP - 0.10, INTAKE_MOUTH),
		point(side * (_fuselage_half(INTAKE_MOUTH) + SPLITTER_GAP + 0.06), INTAKE_TOP - 0.10, INTAKE_MOUTH),
		point(side * (_fuselage_half(INTAKE_MOUTH + RAMP_AFT) + SPLITTER_GAP + 0.20), INTAKE_BOTTOM + 0.20, INTAKE_MOUTH + RAMP_AFT),
		point(side * (INTAKE_OUT - 0.14), INTAKE_BOTTOM + 0.20, INTAKE_MOUTH + RAMP_AFT),
		point(side * (INTAKE_OUT - 0.14), INTAKE_TOP - 0.16, INTAKE_MOUTH + RAMP_AFT),
		point(side * (_fuselage_half(INTAKE_MOUTH + RAMP_AFT) + SPLITTER_GAP + 0.20), INTAKE_TOP - 0.16, INTAKE_MOUTH + RAMP_AFT),
	], DARK)


## THE FUSELAGE'S HALF WIDTH at a station, interpolated from the measured table rather than typed a second time.
## `modelling_here.md`: one number, one place -- the intake asks the body where its side is, and so does the suite,
## which is why this is public: a check that kept its own copy of the skin's position could not catch the skin moving.
func fuselage_half(s: float) -> float:
	return _section_at(s, 1)


func _fuselage_half(s: float) -> float:
	return fuselage_half(s)


func _section_at(s: float, column: int) -> float:
	for r in range(SECTIONS.size() - 1):
		var a: Array = SECTIONS[r]
		var b: Array = SECTIONS[r + 1]
		if s >= float(a[0]) and s <= float(b[0]):
			var t: float = (s - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-6)
			return lerpf(float(a[column]), float(b[column]), t)
	return float(SECTIONS[-1][column]) if s > float(SECTIONS[-1][0]) else float(SECTIONS[0][column])


## ONE WING PANEL, IN ITS OWN NAMED MESH. `modelling_here.md` section 6: a lifting surface buried in the body's mesh
## cannot be measured, because area, M.A.C., taper and aspect ratio are integrals over a planform and an integral needs
## the surface separable. `lane/twin310` sampled a buried wing at six panel edges and reported 7.73 m2 for a 16.26 m2
## wing. This one is `WingPort` and `WingStarboard`, so the suite can sum its triangles' plan projection.
##
## THE SECTION IS FOUR FACETS: a flat underside, and two upper facets meeting at a ridge at 35 per cent chord. Faceted,
## not smoothed, and the ridge is where a real wing's crest is.
func _wing(tool: SurfaceTool, side: float) -> void:
	var rings: Array = []
	for o in [0.78, 1.60, 2.40, 3.20, BREAK_OUT - 0.001, BREAK_OUT + 0.001, 4.70, 5.30, TIP_OUT]:
		rings.append(_wing_section(side, o))
	_loft(tool, rings, func(k: int) -> Color: return BELLY if k >= 2 else GREY, GREY, GREY)


## ONE WING SECTION at `out` metres from the centreline: leading edge, ridge, trailing edge, and the flat underside.
func _wing_section(side: float, out: float) -> Array[Vector3]:
	var le: float = wing_le(out)
	var te: float = wing_te(out)
	var under: float = wing_under(out)
	var t: float = absf(out) / TIP_OUT
	var thick: float = lerpf(ROOT_THICK, TIP_THICK, t)
	var ridge: float = lerpf(le, te, 0.35)
	return [
		point(side * out, under + thick * 0.16, le),
		point(side * out, under + thick, ridge),
		point(side * out, under + thick * 0.10, te),
		point(side * out, under, lerpf(le, te, 0.45)),
	] as Array[Vector3]


## ONE ALL-MOVING STABILATOR, at 23 degrees of ANHEDRAL [PUB]. Its own named mesh, for the same reason the wing has one.
func _stabilator(tool: SurfaceTool, side: float) -> void:
	var rings: Array = []
	for o in [0.30, 0.90, 1.50, 2.10, STAB_OUT]:
		var t: float = o / STAB_OUT
		var le: float = lerpf(STAB_ROOT_LE, STAB_TIP_LE, t)
		var te: float = lerpf(STAB_ROOT_TE, STAB_TIP_TE, t)
		var h: float = stab_height(o)
		var thick: float = lerpf(STAB_THICK.x, STAB_THICK.y, t)
		rings.append([
			point(side * o, h + thick * 0.15, le),
			point(side * o, h + thick, lerpf(le, te, 0.32)),
			point(side * o, h + thick * 0.08, te),
			point(side * o, h, lerpf(le, te, 0.45)),
		] as Array[Vector3])
	_loft(tool, rings, func(k: int) -> Color: return BELLY if k >= 2 else GREY, GREY, GREY)


## THE FIN, whose tip stands at [FM]'s published 5.004 m -- the one height built to a published figure, because the
## scan clips the fin tip and it cannot be measured here.
func _fin(tool: SurfaceTool) -> void:
	var rings: Array = []
	# The first ring is BELOW the deck, at a negative share of the root-to-tip span, so the planform's own lines are
	# extrapolated rather than bent: the visible sweep is exactly what was measured and the body hides the rest.
	var buried: float = (FIN_BURIED - FIN_ROOT_HEIGHT) / (HEIGHT - FIN_ROOT_HEIGHT)
	for pair in [[FIN_BURIED, buried], [FIN_ROOT_HEIGHT, 0.0], [lerpf(FIN_ROOT_HEIGHT, HEIGHT, 0.45), 0.45], [HEIGHT, 1.0]]:
		var h: float = pair[0]
		var t: float = pair[1]
		var le: float = lerpf(FIN_LE, FIN_TIP_LE, t)
		var back: float = lerpf(FIN_TE, FIN_TIP_TE, t)
		var thick: float = lerpf(FIN_THICK.x, FIN_THICK.y, t)
		rings.append([
			point(0.0, h, le), point(thick * 0.5, h, lerpf(le, back, 0.35)),
			point(0.0, h, back - (back - le) * RUDDER_CHORD), point(-thick * 0.5, h, lerpf(le, back, 0.35)),
		] as Array[Vector3])
	_loft(tool, rings, func(k: int) -> Color: return GREY, GREY, GREY)


## THE RUDDER, the aft strip of the fin. It does not move in step 1.
func _rudder(tool: SurfaceTool) -> void:
	var rings: Array = []
	var buried: float = (FIN_BURIED - FIN_ROOT_HEIGHT) / (HEIGHT - FIN_ROOT_HEIGHT)
	for pair in [[FIN_BURIED, buried], [HEIGHT - 0.08, 1.0]]:
		var h: float = pair[0]
		var t: float = pair[1]
		var le: float = lerpf(FIN_LE, FIN_TIP_LE, t)
		var back: float = lerpf(FIN_TE, FIN_TIP_TE, t)
		var hinge: float = back - (back - le) * RUDDER_CHORD
		var thick: float = lerpf(FIN_THICK.x, FIN_THICK.y, t) * 0.7
		rings.append([
			point(0.0, h, hinge), point(thick * 0.5, h, lerpf(hinge, back, 0.4)),
			point(0.0, h, back), point(-thick * 0.5, h, lerpf(hinge, back, 0.4)),
		] as Array[Vector3])
	_loft(tool, rings, func(k: int) -> Color: return BELLY, GREY, GREY)


## ONE NOZZLE, AS PETALS. A J79's variable-area nozzle is a ring of overlapping flaps and it is what a viewer looks at
## from behind; drawn as a plain cylinder it reads as a pipe. Twelve petals a side, 96 triangles for the pair.
func _nozzle_about(tool: SurfaceTool, side: float) -> void:
	var mid: float = (NOZZLE.x + NOZZLE.y) * 0.5
	var axis := Vector3.ZERO
	for p in range(NOZZLE_PETALS):
		var a0: float = TAU * float(p) / float(NOZZLE_PETALS)
		var a1: float = TAU * float(p + 1) / float(NOZZLE_PETALS)
		var face: Array = [
			Vector3(cos(a0) * NOZZLE_RADIUS.x, sin(a0) * NOZZLE_RADIUS.x, NOZZLE.x - mid),
			Vector3(cos(a1) * NOZZLE_RADIUS.x, sin(a1) * NOZZLE_RADIUS.x, NOZZLE.x - mid),
			Vector3(cos(a1) * NOZZLE_RADIUS.y, sin(a1) * NOZZLE_RADIUS.y, NOZZLE.y - mid),
			Vector3(cos(a0) * NOZZLE_RADIUS.y, sin(a0) * NOZZLE_RADIUS.y, NOZZLE.y - mid),
		]
		_facet(tool, face, _centre_of(face) - axis, BURNT if p % 2 == 0 else METAL)


## THE ARRESTER HOOK, stowed between and below the nozzles. A Phantom carries one whether it is Navy or Air Force, and
## on the E it lies in a shallow well under the tail.
func _hook(tool: SurfaceTool) -> void:
	_bar(tool, point(0.0, HOOK_HEIGHT.x, HOOK_ROOT), point(0.0, HOOK_HEIGHT.y, HOOK_TIP), 0.07, DARK)
	_box(tool, point(0.0, HOOK_HEIGHT.y - 0.02, HOOK_TIP - 0.08), Vector3(0.22, 0.10, 0.24), METAL)


func _nose_gear(tool: SurfaceTool) -> void:
	var top := point(0.0, 1.02, NOSE_GEAR_STATION - 0.10)
	var axle := point(0.0, NOSE_TYRE_RADIUS, NOSE_GEAR_STATION)
	_bar(tool, top, axle, 0.07, METAL)
	for w in [-1.0, 1.0]:
		_wheel(tool, axle + Vector3(w * 0.15, 0.0, 0.0), NOSE_TYRE_RADIUS, 0.11)
	for w in [-1.0, 1.0]:
		_box(tool, point(w * 0.22, 1.00, NOSE_GEAR_STATION), Vector3(0.04, 0.06, 1.30), BELLY)


func _main_gear(tool: SurfaceTool, side: float) -> void:
	var out: float = TRACK * 0.5
	var top := point(side * (out - 0.55), wing_under(out - 0.55) - 0.04, MAIN_GEAR_STATION - 0.20)
	var axle := point(side * out, MAIN_TYRE_RADIUS, MAIN_GEAR_STATION)
	_bar(tool, top, axle, 0.09, METAL)
	_wheel(tool, axle, MAIN_TYRE_RADIUS, MAIN_TYRE_WIDE)
	_box(tool, point(side * (out - 0.50), WING_UNDER - 0.02, MAIN_GEAR_STATION), Vector3(0.05, 0.08, 1.50), BELLY)


## ---- the primitives ----------------------------------------------------------------------------------------------

func _wheel(tool: SurfaceTool, centre: Vector3, radius: float, wide: float) -> void:
	var rings: Array = []
	for w in [-wide * 0.5, wide * 0.5]:
		var ring: Array[Vector3] = []
		for k in range(WHEEL_SIDES):
			var a: float = TAU * float(k) / float(WHEEL_SIDES)
			ring.append(centre + Vector3(w, sin(a) * radius, cos(a) * radius))
		rings.append(ring)
	_loft(tool, rings, func(k: int) -> Color: return TYRE, DARK, DARK)


func _bar(tool: SurfaceTool, a: Vector3, b: Vector3, wide: float, tint: Color) -> void:
	var along: Vector3 = (b - a).normalized()
	var side: Vector3 = along.cross(Vector3.UP)
	if side.length_squared() < 1e-6:
		side = Vector3.RIGHT
	side = side.normalized() * wide * 0.5
	var up: Vector3 = along.cross(side).normalized() * wide * 0.5
	_block(tool, [
		a - side - up, a + side - up, a + side + up, a - side + up,
		b - side - up, b + side - up, b + side + up, b - side + up,
	], tint)


func _box(tool: SurfaceTool, at: Vector3, size: Vector3, tint: Color) -> void:
	var h: Vector3 = size * 0.5
	_block(tool, [
		at + Vector3(-h.x, -h.y, -h.z), at + Vector3(h.x, -h.y, -h.z),
		at + Vector3(h.x, h.y, -h.z), at + Vector3(-h.x, h.y, -h.z),
		at + Vector3(-h.x, -h.y, h.z), at + Vector3(h.x, -h.y, h.z),
		at + Vector3(h.x, h.y, h.z), at + Vector3(-h.x, h.y, h.z),
	], tint)


## A CONVEX BLOCK from two matching loops of four corners, each face wound to look away from the block's middle.
func _block(tool: SurfaceTool, corners: Array, tint: Color) -> void:
	var centre: Vector3 = _centre_of(corners)
	for f in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]:
		var quad: Array = [corners[f[0]], corners[f[1]], corners[f[2]], corners[f[3]]]
		_facet(tool, quad, _centre_of(quad) - centre, tint)


## A LOFT through matching rings, closed at both ends.
func _loft(tool: SurfaceTool, rings: Array, tint: Callable, front: Variant = null, back: Variant = null) -> void:
	for r in range(rings.size() - 1):
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		var centre: Vector3 = (_centre_of(a) + _centre_of(b)) * 0.5
		for k in range(a.size()):
			var n: int = (k + 1) % a.size()
			var quad: Array = [a[k], a[n], b[n], b[k]]
			_facet(tool, quad, _centre_of(quad) - centre, tint.call(k))
	var first: Array = rings[0]
	var last: Array = rings[-1]
	_cap(tool, first, _centre_of(first) - _centre_of(rings[1]), front if front is Color else tint.call(0))
	_cap(tool, last, _centre_of(last) - _centre_of(rings[-2]), back if back is Color else tint.call(0))


## A FAN closing a ring, wound to look along `out`.
func _cap(tool: SurfaceTool, ring: Array, out: Vector3, tint: Color) -> void:
	var mid: Vector3 = _centre_of(ring)
	for k in range(ring.size()):
		_tri(tool, mid, ring[k], ring[(k + 1) % ring.size()], out, tint)


## ONE QUAD FACET, both its triangles wound to look along `out`.
func _facet(tool: SurfaceTool, quad: Array, out: Vector3, tint: Color) -> void:
	_tri(tool, quad[0], quad[1], quad[2], out, tint)
	_tri(tool, quad[0], quad[2], quad[3], out, tint)


## ONE TRIANGLE, wound clockwise as seen from `out` -- Godot's front face -- with its own flat normal, or skipped if it
## has no area. NOTHING HERE CALLS `generate_normals`, which smooths across every welded corner and would give exactly
## the rounded look the user asked not to have.
func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, tint: Color) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 1e-12:
		return
	if normal.dot(out) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	var n: Vector3 = normal.normalized()
	# UV2 IS WRITTEN HERE AND NOWHERE ELSE, because this is the one function in the file that emits a vertex and
	# it has already worked out the face normal that chooses the band. Twenty builders writing their own would be
	# twenty chances to disagree; `StainSheet.uv2_for` is the single mapping and the sheet rasterises through the
	# same one, so the picture and the geometry cannot drift apart.
	var band: StainSheet.Face = StainSheet.face_for(n)
	for corner in [a, b, c]:
		tool.set_color(tint)
		tool.set_normal(n)
		tool.set_uv2(_sheet().uv2_for(band, corner.z + _half.z, corner.y + _half.y, corner.x))
		tool.add_vertex(corner)


static func _centre_of(points: Array) -> Vector3:
	var sum := Vector3.ZERO
	for p in points:
		sum += p
	return sum / float(maxi(points.size(), 1))


func _tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


## ONE NAMED PART. Every visible mesh goes through this, with its side in its name, so Godot never renames a duplicate
## to a generated path (`tests/named_parts.gd`).
##
## **AND A PART HUNG ON A HINGE CANCELS THE HINGE'S OFFSET.** Every builder here works in CRAFT coordinates, because
## that is what makes a station a station and lets a wing ask the body where its skin is. A hinge node also sits at a
## craft coordinate, so parenting craft-frame geometry to it counts the offset TWICE: the first build with hinges put
## the aeroplane 27.4 m long and 21.0 m across, against 19.2 and 11.7. The mesh is therefore placed at MINUS the
## hinge's position, so the geometry lands exactly where it was built and the hinge still turns it about the right
## line. The alternative -- rebuilding every surface in its hinge's own frame, as `TomcatAirframe._local` does for the
## swing wing -- is right when the part's shape depends on the pivot, and needless when it does not.
func _add(title: String, tool: SurfaceTool, parent: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.mesh = Plating.weld(tool)
	mesh.material_override = _material
	if parent != null:
		mesh.position = -parent.position
		parent.add_child(mesh)
	else:
		add_child(mesh)
	return mesh


func _detail(mesh: MeshInstance3D) -> void:
	mesh.visibility_range_end = DETAIL_RANGE
	mesh.visibility_range_end_margin = DETAIL_HYSTERESIS
	mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## THE FUSELAGE, IN TWO SURFACES OF ONE MESH: the painted skin and the canopies, both DOUBLE-SIDED. From inside a
## closed solid with back faces culled the crew see none of it -- the F/A-18's tub and the Tomcat's canopy are
## double-sided for the same reason, and the Tomcat's first seat pictures were open sky with a panel floating in it
## while every check was green.
func _add_canopy(title: String, skin: SurfaceTool, glass: SurfaceTool, parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	var mesh: ArrayMesh = Plating.weld(skin)
	glass.commit(mesh)
	var inside := _paint()
	inside.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, inside)
	var pane := StandardMaterial3D.new()
	pane.vertex_color_use_as_albedo = true
	pane.vertex_color_is_srgb = true
	pane.albedo_color = Color(1.0, 1.0, 1.0, 0.40)
	pane.roughness = 0.08
	pane.metallic = 0.3
	pane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(1, pane)
	node.mesh = mesh
	node.position = -parent.position
	parent.add_child(node)
	return node


## ---- what moves ---------------------------------------------------------------------------------------------------

## THE STICK AND THE PEDALS, in the shape `TomcatAirframe.follow_the_stick` uses: one call that poses every surface the
## pilot commands, so a probe and the simulation drive the same path. `stick.x` rolls, `stick.y` pitches, `rudder` yaws.
## The flaps, slats, canopies and nozzle are NOT on the stick and keep their own setters.
func follow_the_stick(stick: Vector2, yaw: float) -> void:
	set_ailerons(clampf(stick.x, -1.0, 1.0))
	set_stabilators(clampf(stick.y, -1.0, 1.0), clampf(stick.x, -1.0, 1.0))
	set_rudder(clampf(yaw, -1.0, 1.0))


## THE SLATS, both panels each side together, as the real aeroplane extends them. 0 shut, 1 fully out.
func set_slats(amount: float) -> void:
	_slats = clampf(amount, 0.0, 1.0)
	for side in ["Port", "Starboard"]:
		_turn("Slats" + side, _slats * SLAT_TRAVEL)


func slats() -> float:
	return _slats


## THE FLAPS, together. 0 up, 1 at the landing setting.
func set_flaps(amount: float) -> void:
	_flaps = clampf(amount, 0.0, 1.0)
	for side in ["Port", "Starboard"]:
		_turn("Flap" + side, _flaps * FLAP_TRAVEL)


func flaps() -> float:
	return _flaps


## THE AILERONS, DIFFERENTIALLY: +1 is stick right, so the STARBOARD aileron goes up and the port one down. Each hinge
## was wound from the geometry when it was built, so a positive turn always carries the trailing edge DOWN on either
## side, and the sign here is the only thing that says which way a roll goes.
func set_ailerons(roll: float) -> void:
	_ailerons = clampf(roll, -1.0, 1.0)
	_turn("AileronStarboard", -_ailerons * AILERON_TRAVEL)
	_turn("AileronPort", _ailerons * AILERON_TRAVEL)


func ailerons() -> float:
	return _ailerons


func set_rudder(yaw: float) -> void:
	_rudder_at = clampf(yaw, -1.0, 1.0)
	_turn("Rudder", _rudder_at * RUDDER_TRAVEL)


func rudder() -> float:
	return _rudder_at


## THE ALL-MOVING STABILATORS: `pitch` turns both together and `roll` adds a differential on top, which is how an F-4
## rolls. The travels are not symmetric -- trailing edge up is the smaller of the two -- so the amount is mapped
## through whichever half it is in.
func set_stabilators(pitch: float, roll: float) -> void:
	_stab_pitch = clampf(pitch, -1.0, 1.0)
	_stab_roll = clampf(roll, -1.0, 1.0)
	# EVERY HINGE HERE IS WOUND SO A POSITIVE TURN CARRIES THE TRAILING EDGE DOWN, which is what `_hinge` asks of the
	# geometry. Pulling the stick back raises it, so the pitch term is NEGATED -- and that sign is the whole of the
	# difference between an aeroplane that pitches up and one that pitches down. The first build had it the other way
	# and every angle was right; only reading the drawn trailing edge caught it.
	var together: float = -_stab_pitch * (STAB_PITCH_TRAVEL.x if _stab_pitch >= 0.0 else STAB_PITCH_TRAVEL.y)
	_turn("StabilatorStarboard", together - _stab_roll * STAB_ROLL_TRAVEL)
	_turn("StabilatorPort", together + _stab_roll * STAB_ROLL_TRAVEL)


func stabilator_pitch() -> float:
	return _stab_pitch


func stabilator_roll() -> float:
	return _stab_roll


## BOTH CANOPIES, hinged at their rear as a Phantom's open. 0 shut, 1 fully open.
func set_canopies(amount: float) -> void:
	_canopies = clampf(amount, 0.0, 1.0)
	_turn("CanopyFront", _canopies * CANOPY_TRAVEL)
	_turn("CanopyRear", _canopies * CANOPY_TRAVEL)


func canopies() -> float:
	return _canopies


## THE NOZZLES' EXIT AREA. Not a hinge: a J79's variable-area nozzle changes its exit diameter, so the petals are
## SCALED about the nozzle's own axis. 0 is the drawn military position, 1 the afterburner setting.
func set_nozzle(amount: float) -> void:
	_nozzle_at = clampf(amount, 0.0, 1.0)
	var open: float = lerpf(1.0, NOZZLE_OPEN, _nozzle_at)
	for node in _nozzles:
		node.scale = Vector3(open, open, 1.0)


func nozzle() -> float:
	return _nozzle_at


## THE FEATURES A VAT BAKES (`VatCasting`, `research/vertex_animation.md`), each this airframe's own setter and getter,
## kept beside the setters they name. Pitch and roll are separate features because the two stabilators combine them,
## exactly as `TomcatAirframe` does it.
func features() -> Array:
	return [
		{"name": "slats", "set": set_slats, "get": slats, "low": 0.0, "high": 1.0, "samples": SURFACE_ROWS},
		{"name": "flaps", "set": set_flaps, "get": flaps, "low": 0.0, "high": 1.0, "samples": SURFACE_ROWS},
		{"name": "ailerons", "set": set_ailerons, "get": ailerons, "low": -1.0, "high": 1.0, "samples": SURFACE_ROWS},
		{"name": "pitch", "set": func(amount: float) -> void: set_stabilators(amount, _stab_roll),
			"get": stabilator_pitch, "low": -1.0, "high": 1.0, "samples": SURFACE_ROWS},
		{"name": "roll", "set": func(amount: float) -> void: set_stabilators(_stab_pitch, amount),
			"get": stabilator_roll, "low": -1.0, "high": 1.0, "samples": SURFACE_ROWS},
		{"name": "rudder", "set": set_rudder, "get": rudder, "low": -1.0, "high": 1.0, "samples": SURFACE_ROWS},
		{"name": "canopies", "set": set_canopies, "get": canopies, "low": 0.0, "high": 1.0, "samples": SURFACE_ROWS},
	]


## A HINGE turned `degrees` from where it was built, about the axis stored on it when it was built.
func _turn(named: String, degrees: float) -> void:
	var hinge: Node3D = _hinges.get(named) as Node3D
	if hinge != null:
		hinge.basis = Basis(hinge.get_meta("axis") as Vector3, deg_to_rad(degrees))


## A HINGE: a node at `at`, turning about `along`, its axis WOUND SO A POSITIVE TURN CARRIES `probe` TOWARDS `wanted`.
## Asked of the geometry rather than reasoned per side, so a mirrored hinge cannot come out turning the wrong way --
## `TomcatAirframe._hinge`'s trick, and `tests/phantom.gd` reads every surface's direction back off its vertices.
##
## "HINGE" ON THE END of the name, so a hinge is never found in place of the part it carries: on the Tomcat
## `find_child("RudderPort")` went to the hinge first, being its parent, and the first checks read a rudder that never
## moved.
func _hinge(named: String, at: Vector3, along: Vector3, probe: Vector3, wanted: Vector3) -> Node3D:
	var hinge := Node3D.new()
	hinge.name = named + "Hinge"
	hinge.position = at
	var axis: Vector3 = along.normalized()
	if axis.cross(probe - at).dot(wanted) < 0.0:
		axis = -axis
	hinge.set_meta("axis", axis)
	add_child(hinge)
	_hinges[named] = hinge
	return hinge


## ---- the moving parts, each in its own mesh under its own hinge ----------------------------------------------------

## THE SLATS, FLAPS AND AILERONS, three parts a side rather than one. In step 1 all four surfaces were one mesh, which
## is right for drawing and useless for moving: they hinge about three different lines. The slats stay one part each
## side because the real aeroplane extends both panels together.
func _wing_surface_parts(side: float, named: String) -> void:
	var slat_tool := _tool()
	for span in [SLAT_INBOARD, SLAT_OUTBOARD]:
		_surface_plate(slat_tool, side, span, true)
	# A SURFACE TURNS ABOUT ITS OWN HINGE LINE, NOT ABOUT THE SPAN. A slat's hinge is the LEADING EDGE, swept 51.5
	# degrees; the first build turned both slats about a spanwise axis at one station and the outboard end swung
	# metres forward, drawing a long dark bar diagonally across the wing. Every angle was right and the check for the
	# travel would have passed. Only the picture showed it. The axis is now the vector from the surface's INBOARD
	# hinge point to its OUTBOARD one, which is the line the real hinge is on.
	var slat_in: float = SLAT_INBOARD.x * TIP_OUT
	var slat_out: float = SLAT_OUTBOARD.y * TIP_OUT
	var slat_hinge := point(side * slat_in, wing_under(slat_in) + 0.10, wing_le(slat_in))
	var slat_line: Vector3 = point(side * slat_out, wing_under(slat_out) + 0.10, wing_le(slat_out)) - slat_hinge
	_hinge("Slats" + named, slat_hinge, slat_line,
		point(side * slat_in, wing_under(slat_in) + 0.10, wing_le(slat_in) + 0.5), Vector3.DOWN)
	_add("Slats" + named, slat_tool, _hinges["Slats" + named] as Node3D)

	for pair in [[FLAP_SPAN, "Flap"], [AILERON_SPAN, "Aileron"]]:
		var span: Vector2 = pair[0]
		var what: String = pair[1]
		var tool := _tool()
		_surface_plate(tool, side, span, false)
		var o_in: float = span.x * TIP_OUT
		var o_out: float = span.y * TIP_OUT
		var at := point(side * o_in, wing_under(o_in) + 0.08, _surface_hinge_at(o_in))
		var line: Vector3 = point(side * o_out, wing_under(o_out) + 0.08, _surface_hinge_at(o_out)) - at
		# along the surface's OWN hinge line, and wound so a POSITIVE turn carries the trailing edge DOWN either side
		_hinge(what + named, at, line,
			point(side * o_in, wing_under(o_in) + 0.08, wing_te(o_in)), Vector3.DOWN)
		_add(what + named, tool, _hinges[what + named] as Node3D)


## THE HINGE LINE of a trailing-edge surface at `out` metres from the centreline: forward of the trailing edge by the
## surface's own chord share, so the flaps and the ailerons share one line and one number.
func _surface_hinge_at(out: float) -> float:
	return wing_te(out) - (wing_te(out) - wing_le(out)) * SURFACE_CHORD


## ONE CONTROL-SURFACE PLATE over a span, built in the craft's frame -- its hinge node carries it afterwards, so the
## geometry is the same whether or not it moves.
func _surface_plate(tool: SurfaceTool, side: float, span: Vector2, leading: bool) -> void:
	var a: float = span.x * TIP_OUT
	var b: float = span.y * TIP_OUT
	for step in range(3):
		var o0: float = lerpf(a, b, float(step) / 3.0)
		var o1: float = lerpf(a, b, float(step + 1) / 3.0)
		var corners: Array = []
		for o in [o0, o1]:
			var le: float = wing_le(o)
			var te: float = wing_te(o)
			var chord: float = te - le
			var from: float = le if leading else te - chord * SURFACE_CHORD
			var to: float = (le + chord * SLAT_CHORD) if leading else te
			var under: float = wing_under(o)
			var thick: float = lerpf(ROOT_THICK, TIP_THICK, absf(o) / TIP_OUT) * 0.30
			corners.append([
				point(side * o, under + thick, from), point(side * o, under + thick, to),
				point(side * o, under + thick + 0.03, to), point(side * o, under + thick + 0.03, from),
			])
		_block(tool, [
			corners[0][0], corners[0][1], corners[0][2], corners[0][3],
			corners[1][0], corners[1][1], corners[1][2], corners[1][3],
		], METAL if leading else BELLY)


## A POINT ON THE STABILATOR'S QUARTER-CHORD LINE at `out` metres from the centreline -- its spindle.
func _stab_quarter(side: float, out: float) -> Vector3:
	var t: float = out / STAB_OUT
	var le: float = lerpf(STAB_ROOT_LE, STAB_TIP_LE, t)
	var te: float = lerpf(STAB_ROOT_TE, STAB_TIP_TE, t)
	return point(side * out, stab_height(out), lerpf(le, te, 0.25))


## ONE ALL-MOVING STABILATOR under its own spindle. The whole surface turns, which is what "all-moving" means and is
## why the F-4 has no separate elevator.
func _stabilator_part(side: float, named: String) -> void:
	var tool := _tool()
	_stabilator(tool, side)
	# THE SPINDLE runs along the stabilator's own quarter-chord line, which is swept and drooped: a spanwise axis
	# would swing its tip forward and out of the aeroplane, exactly as the slats' did.
	var at := _stab_quarter(side, 0.20)
	var line: Vector3 = _stab_quarter(side, STAB_OUT) - at
	_hinge("Stabilator" + named, at, line,
		point(side * 0.20, stab_height(0.20), lerpf(STAB_ROOT_TE, STAB_TIP_TE, 0.20 / STAB_OUT)), Vector3.DOWN)
	_add("Stabilator" + named, tool, _hinges["Stabilator" + named] as Node3D)


## THE RUDDER on the fin's hinge line, turning about the fin's own nearly-vertical axis.
func _rudder_part() -> void:
	var tool := _tool()
	_rudder(tool)
	var high: float = lerpf(FIN_ROOT_HEIGHT, HEIGHT, 0.5)
	var le: float = lerpf(FIN_LE, FIN_TIP_LE, 0.5)
	var back: float = lerpf(FIN_TE, FIN_TIP_TE, 0.5)
	var hinge_at: float = back - (back - le) * RUDDER_CHORD
	var at := point(0.0, high, hinge_at)
	# the axis leans with the fin's own hinge line, and is wound so a POSITIVE turn takes the trailing edge to PORT
	var along: Vector3 = point(0.0, HEIGHT, FIN_TIP_LE) - point(0.0, FIN_ROOT_HEIGHT, FIN_LE)
	_hinge("Rudder", at, along, point(0.0, high, back), Vector3.LEFT)
	_add("Rudder", tool, _hinges["Rudder"] as Node3D)


## THE TWO CANOPIES, each its own part under its own hinge at its rear, as a Phantom's open.
func _canopy_parts() -> void:
	for pair in [["CanopyFront", WINDSCREEN_BASE, CANOPY_FRAME.x], ["CanopyRear", CANOPY_FRAME.y, REAR_CANOPY.y]]:
		var named: String = pair[0]
		var from: float = pair[1]
		var to: float = pair[2]
		var skin := _tool()
		var glass := _tool()
		_canopy_between(skin, glass, from, to)
		var at := point(0.0, _section_at(to, 2), to)
		_hinge(named, at, Vector3.RIGHT, point(0.0, CANOPY_TOP, from), Vector3.UP)
		_add_canopy(named, skin, glass, _hinges[named] as Node3D)


## THE NOZZLE hangs on a node at its OWN axis and is built in that node's frame, because it is the one part that is
## SCALED rather than turned. Everything else here is built in craft coordinates and has the hinge's offset cancelled
## in `_add`; that cannot work for a node that scales, because the scale would be applied to the cancelling offset too
## and walk the part away from the aeroplane.
func _nozzle_part(side: float, named: String) -> void:
	var node := Node3D.new()
	node.name = "Nozzle" + named + "Axis"
	node.position = point(side * NOZZLE_OUT, NOZZLE_HEIGHT, (NOZZLE.x + NOZZLE.y) * 0.5)
	add_child(node)
	var tool := _tool()
	_nozzle_about(tool, side)
	var mesh := MeshInstance3D.new()
	mesh.name = "Nozzle" + named
	mesh.mesh = Plating.weld(tool)
	mesh.material_override = _material
	node.add_child(mesh)
	_nozzles.append(node)
