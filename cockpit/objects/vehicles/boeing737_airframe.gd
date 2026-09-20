@tool
extends JetlinerAirframe
class_name Boeing737Airframe
## A BOEING 737-800 WITH BLENDED WINGLETS (the -800W), DRAWN: kind `airliner` since 2026-09-19, in place of a blue box with
## a cone on its nose. Twin CFM56-7s under a 25-degree swept wing, the flattened-bottomed nacelles that sit half a metre off
## the runway, the dorsal fillet running into a tall fin, and the main wheels that fold INTO THE BELLY with no doors over
## them, as every 737's do.
##
## WHY THE -800W. It is the 737 there are most of (over 4,900 built), it is the 737 most people have flown in, and it is
## the one Boeing's own dimensioned drawing shows: section 2.2.6 of the 737 airport planning document is "Model 737-800W".
## The published height, span and length the brief names are the -800W's.
##
## THIS IS A TABLE; `JetlinerAirframe` draws it. Every figure names its source:
## - [ACAPS] Boeing, "737 Airplane Characteristics for Airport Planning", D6-58325-7 Rev C, October 2025: section 2.2.6
##   "General Dimensions: Model 737-800W, BBJ2, -800BCF" (a vector drawing: plan, side and front, one scale), section
##   2.3.3's ground-clearance table, and section 7's tyre sizes. Boeing publishes it for airport planners; it is used here
##   to MEASURE and is not incorporated (no line of it is in the game). `craft/airliner/sources.md` says where to get it.
## - MEASURED: off [ACAPS] 2.2.6 by `craft/airliner/measure_views.py`, which redraws the page from its blue vector paths
##   alone and re-derives every figure below from it, reading nothing out of this file. ONE PUBLISHED NUMBER SETS THE
##   SCALE: the printed length, 129 ft 6 in (39.47 m), over the plan's length in pixels, 75.07 px a metre at 600 dpi,
##   13 mm a pixel. The drawing's outline is a stroke 0.12 m thick; the silhouettes are to its OUTER edge, and the
##   fuselage's heights here are that edge less half the stroke.
## - [WP] Wikipedia, "Boeing 737 Next Generation": fuselage 3.76 m wide and 4.01 m tall.
## - ESTIMATE where nothing gives a figure, and it says what it was reasoned from.
##
## THE CROSS-CHECKS, which the scale was NOT set from (measure_views.py prints each):
## - the span: 35.83 m in the plan and 35.79 in the front view, against 35.79 printed (+0.12 and +0.01 per cent);
## - the length in the side view, 39.36 against 39.47 (-0.27 per cent), so the three views share one scale;
## - the height, fin tip over the ground line: 12.60 m in the side view and 12.62 in the front, against 12.55 printed;
## - the wing tip's trailing edge 25.99 m aft of the nose against 26.01 printed (-0.08 per cent);
## - the wheelbase 15.51 m against 15.60 (-0.56 per cent); the nose gear 4.16 m aft against 4.09 (+1.6 per cent); the main
##   gear's track 5.64 m against 5.72 (-1.4 per cent); the engine's centreline 4.87 m out against 4.83 (+0.8 per cent);
## - the tailplane's span 14.48 m against 14.35 (+0.9 per cent).
##
## TWO DISAGREEMENTS, WRITTEN DOWN RATHER THAN HIDDEN:
## 1. THE FUSELAGE'S WIDTH. The plan view's outline is 3.97 m across at its widest and the front view's 3.66: the drawing's
##    two views disagree with each other by 8 per cent, on either side of the printed 3.76 (which the plan's own
##    dimension arrows span). The model is 3.76 wide, [WP] and the printed figure, and the plan's taper is kept in shape by
##    scaling its half-widths by 3.76 / 3.97.
## 2. THE BODY'S HEIGHT OVER THE GROUND. [ACAPS] 2.3.3 gives ground clearances for the -800W between operating empty
##    weight (the higher) and maximum taxi weight. Against their mean, the drawing's own features sit LOW by a nearly
##    constant amount: the forward entry door's sill by 0.245 m (drawn 2.42, table 2.665), the forward cargo door's by
##    0.245 (1.13 against 1.375), the engine's lowest point by 0.24 (0.32 against 0.56) and the stabiliser by 0.265 (5.30
##    against 5.565). Four features agreeing to 25 mm is a datum, not noise. So the body is RAISED 0.25 m (`raise`) and
##    the gear lengthened to match. The fin tip is the one thing that does NOT move with it: the drawing, the printed
##    12.55 m and the table's 12.50 all put it at about 12.55, so the fin is drawn from its raised root to a tip at the
##    published height, which makes it 0.25 m (3 per cent) shorter than the drawing's. Two table figures stay unexplained
##    and are left out of the fit: the aft entry door's sill and the aft cargo door's read 0.63 and 0.49 m over the drawn
##    ones, where a level aeroplane would give 0.25. What would settle both: a true broadside photograph of a parked
##    737-800 with its door sills visible, and a published figure for the belly's height.
##
## THE CREW, captain LEFT: the eyes 0.53 m either side of the centreline, 2.7 m aft of the nose tip and 3.75 m over the
## ground, under the windscreen's panes. ESTIMATE, placed off [ACAPS]'s drawn windscreen, whose panes span stations 1.3 to
## 3.0 and heights 3.13 to 3.86 before the raise.

## [ACAPS] The published envelope of the 737-800W, held by `tests/airliners.gd`.
const LENGTH: float = 39.47
const SPAN: float = 35.79
const HEIGHT: float = 12.55
## [WP] The fuselage.
const WIDTH: float = 3.76

## THE BOX THE KIND WILL GET, and the frame this is drawn in: the fuselage's published width, the ground to the crown
## (4.905 drawn, raised 0.25), the published length; the span is half, as every kind's; the mass is an ESTIMATE of a
## flying weight, the [ACAPS] 41,413 kg operating empty plus about 21 t of fuel and passengers (max take-off 79,016).
const GEOMETRY: Dictionary = {"extents": Vector3(1.88, 2.578, 19.735), "span": 17.895, "mass": 62000.0}

## The plan's half-widths are scaled by this to the published width (see disagreement 1).
const _W: float = 1.88 / 1.985


func table() -> Dictionary:
	return {
		"name": "Boeing737",
		"geometry": GEOMETRY,
		"raise": 0.25,
		# THE FUSELAGE, [station, half-width, keel, crown] MEASURED: half-widths off the plan's outline x _W, keel and
		# crown off the side's outline less half the stroke. The tail cone from 34.5 is hidden under the tailplane in the
		# plan, so its half-widths there are an ESTIMATE: about half its measured depth, narrowing to the plan's 0.30 at
		# 37.5, where it shows behind the tailplane, and the APU exhaust's 0.08 at 38.0. The first build tapered it
		# straight from 33.5 and drew a blade.
		"fuselage": [
			[0.2, 0.33, 2.05, 2.83], [0.5, 0.546 * _W, 1.795, 3.040], [1.0, 0.733 * _W, 1.529, 3.307],
			[1.5, 0.919 * _W, 1.329, 3.680], [2.0, 1.086 * _W, 1.169, 4.000], [2.5, 1.233 * _W, 1.036, 4.239],
			[3.0, 1.366 * _W, 0.969, 4.413], [3.5, 1.499 * _W, 0.929, 4.519], [4.0, 1.599 * _W, 0.929, 4.572],
			[5.0, 1.765 * _W, 0.929, 4.692], [6.0, 1.859 * _W, 0.929, 4.786], [7.0, 1.919 * _W, 0.929, 4.852],
			[8.0, 1.959 * _W, 0.929, 4.892], [9.5, 1.985 * _W, 0.929, 4.905], [22.5, 1.985 * _W, 0.929, 4.905],
			[25.0, 1.975 * _W, 0.943, 4.905], [27.0, 1.965 * _W, 1.036, 4.905], [29.0, 1.952 * _W, 1.249, 4.905],
			[30.0, 1.912 * _W, 1.395, 4.905], [31.0, 1.812 * _W, 1.569, 4.905], [32.0, 1.678 * _W, 1.768, 4.905],
			[33.0, 1.479 * _W, 2.008, 4.905], [34.5, 1.15, 2.394, 4.905], [35.5, 0.95, 2.701, 4.905],
			[36.5, 0.70, 3.021, 4.905], [37.5, 0.30, 3.380, 5.000], [38.0, 0.12, 4.050, 5.050],
		],
		# The nose tip [station, drawn height] off the side view, and the tail cone's tip, where the APU exhausts.
		"nose_tip": Vector2(0.0, 2.44),
		"tail_tip": Vector2(38.4, 4.75),
		# THE FLIGHT-DECK PANES, [fore, aft, low, high, least out] in drawn heights: [ACAPS]'s side view draws them from
		# station 1.3 to 3.0 between 3.13 and 3.86 m up.
		"windscreen": [[1.3, 3.05, 3.10, 3.95, 0.10]],
		# THE CABIN WINDOWS. ESTIMATE: [ACAPS] draws the doors and not the windows. The 737's are 20 inches apart; the row's
		# middle is a metre over the cabin floor, which is the drawn door sill (2.42).
		"cabin_windows": {"from": 6.3, "to": 30.8, "pitch": 0.508, "centre": 3.40, "tall": 0.34, "wide": 0.24, "gaps": []},
		# THE WING-TO-BODY FAIRING, [station, half-width, drawn bottom, drawn top]: ESTIMATE round the measured wing root
		# (14.6 to 21.5) and the main wheels at 19.67; its bottom is the side view's belly line, 0.88.
		"fairing": {"rows": [[14.0, 1.30, 1.25, 1.95], [15.5, 1.80, 0.90, 2.10], [22.5, 1.80, 0.90, 2.10],
			[24.5, 1.20, 1.05, 1.90]]},
		"wing": {
			# MEASURED in plan: the leading edge 14.583 + 0.5152 x out (27.3 degrees, 475 rows a side, rms 4.4 mm) outboard of
			# its kink at 5.67 m out, and 0.70 a metre (35 degrees) inboard of it, through 14.93 at 2.0 m out; the trailing
			# edge square across at 21.47 to 5.5 m out and 19.889 + 0.2881 x out (16.1 degrees, rms 4.0 mm) beyond.
			"le": [[1.5, 14.59], [5.67, 17.504], [17.0, 23.341]],
			"te": [[1.5, 21.473], [5.5, 21.473], [17.0, 24.787]],
			# MEASURED in the front view: the lower surface 1.263 + 0.1092 x out, fitted from 7 to 16.5 m out: 6.2 degrees of
			# dihedral, against the 6 Boeing gives.
			"lower": Vector2(1.263, 0.1092),
			# Thickness to chord, root and tip: ESTIMATE, a transport's 15 and 11 per cent.
			"tc": Vector2(0.15, 0.11),
			"root": 1.5,
			"tip": 17.0,
			"stations": [1.5, 1.95, 5.5, 5.67, 6.1, 12.2, 12.4, 16.0, 17.0],
			# THE TRAILING-EDGE SURFACES, ESTIMATE: [ACAPS] draws no panel lines. The 737's inboard and outboard flaps either
			# side of the thrust gate over the nacelle, and the aileron outboard, each a round share of the local chord.
			"trailing": [
				{"name": "FlapInboard", "from": 1.95, "to": 5.5, "chord": 0.30},
				{"name": "FlapOutboard", "from": 6.1, "to": 12.2, "chord": 0.28},
				{"name": "Aileron", "from": 12.4, "to": 16.0, "chord": 0.24},
			],
			# THE SPOILERS, ESTIMATE: two panels inboard and four outboard, ahead of the flaps, as the 737's; each group's
			# panels [from, to] metres out between the same shares of the chord, on one hinge.
			"spoilers": [
				{"name": "SpoilersInboard", "fore": 0.55, "aft": 0.69, "panels": [[2.2, 3.7], [3.7, 5.2]]},
				{"name": "SpoilersOutboard", "fore": 0.56, "aft": 0.71,
					"panels": [[6.3, 7.7], [7.7, 9.1], [9.1, 10.5], [10.5, 11.9]]},
			],
			# THE BLENDED WINGLET, [out, drawn height, leading edge, trailing edge, thickness]: its outs and heights MEASURED
			# off the front view (16.98 to 17.34 m out at 4.4 m up, 17.64 to 17.88 at 6.1; the top row's 17.84 is the plan's
			# outermost 17.91 less half the outline's stroke), its trailing edge at the top the printed 26.01. Its chords are
			# an ESTIMATE: the plan sees the whole winglet from above at once, base to tip, so its 24.72-to-25.99 at the
			# outermost rows is the winglet's swept projection and not a chord; the first build took it for one and drew a
			# 1.2 m tip on a winglet whose tip is about 0.65.
			"winglet": [[17.15, 4.4, 23.75, 25.05, 0.10], [17.5, 5.3, 24.55, 25.55, 0.08], [17.84, 6.15, 25.35, 26.0, 0.05]],
		},
		# THE CFM56-7 NACELLES, MEASURED: the plan's centreline 4.87 m out (3.68 to 6.05 at its widest, 15.0 to 15.5), the
		# inlet lip at 13.28 (printed 13.36), the side view's pod from 0.32 to 2.22 m up, the cowl ending at 16.3, the nozzle
		# to 17.1 and the plug to 18.1. The flattened lower lip is the 737's: `flat` squeezes the bottom half.
		"nacelles": [
			{"out": 4.87, "high": 1.27, "flat": 0.05,
				"rings": [[13.30, 0.92, 0.84], [13.60, 1.05, 0.93], [14.50, 1.17, 0.97], [15.30, 1.185, 0.97],
					[16.00, 1.14, 0.93], [16.30, 1.00, 0.84]],
				"nozzle": [17.1, 0.56], "plug": 18.1, "pylon": [14.4, 18.8, 0.14]},
			{"out": -4.87, "high": 1.27, "flat": 0.05,
				"rings": [[13.30, 0.92, 0.84], [13.60, 1.05, 0.93], [14.50, 1.17, 0.97], [15.30, 1.185, 0.97],
					[16.00, 1.14, 0.93], [16.30, 1.00, 0.84]],
				"nozzle": [17.1, 0.56], "plug": 18.1, "pylon": [14.4, 18.8, 0.14]},
		],
		# THE TAILPLANE, MEASURED in plan: leading edge 32.649 + 0.7193 x out (35.7 degrees), trailing edge 37.146 + 0.3190 x
		# out, the tip 7.24 m out (14.48 m span against 14.35 printed). Its chord plane MEASURED off the front view: the
		# middle of the tailplane's silhouette at each out, 4.37 m up at 1.8 m out to 5.13 at 7.0, a straight line (8.3
		# degrees; Boeing gives 7) carried to 4.15 at the root and 5.17 at the tip. The silhouette is 0.87 m deep at the
		# root and 0.50 at the tip, more than any section is thick: the drawing draws the stabiliser trimmed at some
		# incidence, which is not modelled; the section is 12 per cent (ESTIMATE). The first two builds read the chord
		# plane off the lower surface and stood the tips 0.5 m high; the front overlay showed it both times.
		"tailplane": {"le": Vector2(32.649, 0.7193), "te": Vector2(37.146, 0.3190), "root": 0.3, "tip": 7.24,
			"high": Vector2(4.15, 5.17), "tc": 0.12,
			# THE ELEVATOR, [from, to, share of chord]: ESTIMATE.
			"elevator": [1.8, 6.9, 0.30]},
		# THE FIN, MEASURED in the side view: the dorsal fillet's leading edge 28.60 at the crown (4.9) to 32.90 at 6.7 m,
		# then the fin's, 28.016 + 0.7302 x height (36.1 degrees), and the trailing edge 36.011 + 0.2012 x height, to the
		# tip at 12.55 drawn. Thickness 0.75 m at the root to 0.30 at the tip, the front view's outline less its stroke.
		"fin": {"dorsal": [[4.9, 28.60], [5.5, 30.20], [6.1, 31.74], [6.7, 32.90]],
			"le": Vector2(28.016, 0.7302), "te": Vector2(36.011, 0.2012), "root": 4.9, "tip": 12.55,
			"tip_over_ground": HEIGHT, "thick": Vector2(0.75, 0.30),
			# THE RUDDER, [foot, head, chord at the root, chord at the tip]: ESTIMATE, 30 per cent of the fin's chord.
			"rudder": [5.0, 12.3, 1.40, 0.55]},
		# THE GEAR. The axles MEASURED: the nose at 4.156 aft, the mains at 19.668 (wheelbase 15.51), their legs 2.835 m out
		# with a tyre either side 0.385 m off (the front view's tyres, 2.23 to 2.68 and 3.00 to 3.44). The tyres [ACAPS]
		# section 7: 27 x 7.75-15 on the nose and H44.5 x 16.5-21 on the mains, 0.686 and 1.13 m across. The pivots and the
		# stowed places ESTIMATE: the nose leg folds FORWARD into a well closed by two doors; the mains fold INBOARD into the
		# belly with NO well doors -- a 737's main wheels are seen in its belly in flight, and drawing doors over them would
		# be drawing a different aeroplane. So the 737's gear sequence is the nose doors' alone.
		"gear": [
			{"name": "NoseGear", "out": 0.0, "pivot": Vector3(0.0, 1.35, 4.05), "axle": Vector3(0.0, 0.0, 4.156),
				"stowed": Vector3(0.0, 1.45, 3.1), "tyre": Vector2(0.686, 0.197), "tyres": [-0.20, 0.20], "strut": 0.07},
			{"name": "MainGear", "out": 2.835, "pivot": Vector3(2.835, 1.72, 19.8), "axle": Vector3(2.835, 0.0, 19.668),
				"stowed": Vector3(1.0, 1.55, 19.8), "tyre": Vector2(1.13, 0.42), "tyres": [-0.385, 0.385], "strut": 0.11,
				"leg_door": Vector2(0.24, 0.8)},
		],
		"gear_doors": [{"name": "NoseDoor", "fore": 2.7, "aft": 3.9, "inner": 0.01, "outer": 0.32}],
		# THE CREW, captain LEFT: see the class note. `room` is [out, drawn height, station] corners of the flight deck,
		# which the suite holds inside the drawn skin.
		"eye": Vector3(0.53, 3.50, 2.70),
		"room": AABB(Vector3(-0.70, 2.15, 2.60), Vector3(1.40, 1.75, 1.80)),
		"room_source": "eyes 0.53 m either side under [ACAPS]'s drawn windscreen, the seats EYE_HEIGHT under them; the room MEASURED against the drawn skin",
		# AN ORIGINAL LIVERY: white over a light-grey belly, the game's airliner blue on the fin and in a cheatline under the
		# windows. No airline's marks.
		"livery": {
			"top": Color(0.93, 0.94, 0.95), "belly": Color(0.70, 0.72, 0.75), "belly_below": 1.9,
			"stripe": Color(0.16, 0.40, 0.86), "cheatline": Vector2(2.62, 2.86), "cheatline_from": 3.0,
			"fin": Color(0.16, 0.40, 0.86), "tail": Color(0.90, 0.91, 0.92), "tail_cone": Color(0.85, 0.86, 0.88),
			"glass": Color(0.10, 0.15, 0.20), "window": Color(0.07, 0.09, 0.13),
			"wing": Color(0.74, 0.76, 0.79), "wing_under": Color(0.66, 0.68, 0.71),
			"nacelle": Color(0.90, 0.91, 0.92), "lip": Color(0.66, 0.68, 0.70), "inlet": Color(0.07, 0.07, 0.08),
			"metal": Color(0.42, 0.42, 0.44), "gear": Color(0.78, 0.78, 0.78), "tyre": Color(0.06, 0.06, 0.06),
		},
	}
