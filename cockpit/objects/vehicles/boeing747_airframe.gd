@tool
extends JetlinerAirframe
class_name Boeing747Airframe
## A BOEING 747-400, DRAWN: kind `jumbo` since 2026-09-19 (`lane/liners`), in place of an E-6B blockout that had the
## airliner's slab for a body. Four CF6-80C2s on pylons under a 42-degree swept wing, the raked, canted winglets, the
## UPPER DECK's hump reaching back over the wing with the flight deck at its front, and the sixteen-wheel main gear on four
## bogies -- two on the wing, two under the body -- with doors over every well.
##
## WHY THE -400. It is the 747 with the long upper deck and the winglets, the one most people picture, and the one
## Boeing's own dimensioned drawing shows: section 2.2.1 of the 747-400 airport planning document.
##
## THIS IS A TABLE; `JetlinerAirframe` draws it. Every figure names its source:
## - [ACAPS] Boeing, "747-400 Airplane Characteristics for Airport Planning", D6-58326-1 Rev F, December 2024: section
##   2.2.1 "General Dimensions: Model 747-400, -400 Combi, -400ER" (a vector drawing: plan, side and front, one scale),
##   section 2.3.1's ground clearances and section 7's tyre size. Used to MEASURE, not incorporated.
##   `craft/jumbo/sources.md` says where Boeing publishes it.
## - MEASURED: off [ACAPS] 2.2.1 by `craft/jumbo/measure_views.py`, which reads the page with the 737's
##   `craft/airliner/acaps.py` and re-derives every figure below from it, reading nothing out of this file. ONE PUBLISHED
##   NUMBER SETS THE SCALE: the printed overall length, 231 ft 10.25 in (70.67 m), over the side view's length, 32.135 px a
##   metre at 600 dpi, 31 mm a pixel.
## - ESTIMATE where nothing gives a figure, and it says what it was reasoned from.
##
## THE CROSS-CHECKS, which the scale was NOT set from:
## - the span: 64.94 m in plan and 64.91 in the front view, against the 64.92 Boeing prints for MAXIMUM GROSS WEIGHT
##   (+0.04 and -0.01 per cent). Boeing prints two spans, 64.44 in the jig and 64.92 at maximum gross weight, and the
##   drawing is the second; so is this model, 0.7 per cent over the jig figure Wikipedia quotes;
## - the length in plan 70.58 against 70.67 (-0.13 per cent); the fuselage 6.57 m wide at station 18 against 6.50 (+1.0);
## - the fin tip 19.26 m over the ground against Wikipedia's 19.41 (-0.8) and [ACAPS] 2.3.1's 18.80 to 19.51;
## - the tailplane's span 22.10 against 22.17 (-0.3); the engines' centrelines 11.92 and 21.13 m out against 11.68 and
##   21.0 (+2.0 and +0.6), their inlets 23.2 and 32.1 m aft against 23.01 and 32.16 (+0.8 and -0.2).
##
## AGAINST THE GROUND-CLEARANCE TABLE the body agrees -- the hump's crown 10.05 against the table's mean of 10.02, the aft
## crown 9.21 against 9.29, the fin 19.26 against 19.16 -- so, unlike the 737's drawing, nothing is raised. The WING does
## not: the drawing puts the inboard nacelles' bottoms 1.09 m up against the table's 0.82, the outboard ones' 2.10 against
## 1.56 and the winglet's top 7.5 against 7.0. The table's figures are at loaded attitudes with the wing bent down under
## fuel; the drawing's wing is drawn higher than even its lightest. Left as drawn and written down: a wing bent to the table
## would be a second drawing of the wing, not a measurement of this one.
##
## THE CREW, captain LEFT, on the UPPER DECK: the eyes 0.55 m either side, 6.9 m aft of the nose tip and 8.55 m up,
## level with [ACAPS]'s drawn flight-deck windows (stations 4.6 to 6.3, 8.31 to 8.74 m up). ESTIMATE.

## The published envelope, held by `tests/airliners.gd`: [ACAPS]'s overall length, the jig span, Wikipedia's height.
const LENGTH: float = 70.67
const SPAN: float = 64.44
const HEIGHT: float = 19.41
const WIDTH: float = 6.50

## THE BOX THE KIND WILL GET, and the frame this is drawn in: the fuselage's published width, the ground to the hump's
## crown (10.05), the printed length; the span is half the drawn 64.92, as every kind's is half; the mass an ESTIMATE of a
## flying weight between [ACAPS]'s 178,755 kg operating empty and 396,893 kg maximum take-off.
const GEOMETRY: Dictionary = {"extents": Vector3(3.25, 5.025, 35.335), "span": 32.46, "mass": 280000.0}


func table() -> Dictionary:
	return {
		"name": "Boeing747",
		"geometry": GEOMETRY,
		"raise": 0.0,
		# THE FUSELAGE, [station, half-width, keel, crown] MEASURED: the plan's half-width less 2 cm of outline, the side's
		# keel and crown (the hump's crown from 11 to 23). From 59 aft the plan is hidden under the tailplane and the
		# half-widths are an ESTIMATE, tapering to the plan's 0.39 at 68 where the tail cone shows again.
		"fuselage": [
			[0.3, 0.70, 4.60, 5.95], [1.0, 1.145, 4.14, 6.44], [2.0, 1.49, 3.67, 7.00], [3.0, 1.75, 3.30, 7.53],
			[4.0, 2.015, 2.99, 8.06], [5.0, 2.235, 2.74, 8.84], [6.0, 2.44, 2.55, 9.40], [7.0, 2.61, 2.40, 9.65],
			[8.0, 2.765, 2.27, 9.80], [9.0, 2.925, 2.18, 9.90], [10.0, 3.045, 2.08, 9.99], [11.0, 3.105, 2.02, 10.05],
			[12.0, 3.17, 1.99, 10.05], [13.0, 3.22, 1.93, 10.05], [14.0, 3.25, 1.90, 10.05], [21.0, 3.265, 1.90, 10.02],
			[23.0, 3.26, 1.90, 9.96], [25.0, 3.26, 1.90, 9.83], [27.0, 3.26, 1.90, 9.62], [28.0, 3.26, 1.90, 9.46],
			[29.0, 3.26, 1.90, 9.27], [30.0, 3.25, 1.90, 9.21], [36.0, 3.25, 1.93, 9.21], [38.0, 3.25, 2.02, 9.21],
			[40.0, 3.25, 2.15, 9.21], [45.0, 3.25, 2.18, 9.18], [47.0, 3.25, 2.37, 9.18], [49.0, 3.22, 2.80, 9.18],
			[51.0, 3.08, 3.21, 9.18], [53.0, 2.90, 3.64, 9.18], [55.0, 2.70, 4.08, 9.18], [57.0, 2.36, 4.51, 9.18],
			[59.0, 2.05, 4.95, 9.18], [61.0, 1.75, 5.38, 9.20], [63.0, 1.45, 5.82, 9.22], [65.0, 1.10, 6.25, 9.28],
			[67.0, 0.70, 6.66, 9.43], [68.0, 0.39, 7.00, 9.27], [69.0, 0.20, 8.46, 8.90],
		],
		# THE UPPER DECK: the front view's hump above the main lobe, a circle of 2.5 m radius (its half-width 2.04 m at 9.0
		# m up, 1.6 at 9.5, 2.54 at 8.0) standing on a main lobe 2.25 half-widths deep (keel 1.90 to crown 9.21 on a 3.25
		# m half-width, aft of the hump); ahead of the flight deck its radius is at most 0.77 of the half-width. At 2.22
		# the aft body carried a false hump 6 to 9 cm high all the way back to station 45, and the ring's change of shape
		# where it stopped was a crease across the fuselage in the first rear-quarter picture.
		"upper_deck": {"radius": 2.5, "share": 0.77, "main_depth": 2.25},
		"nose_tip": Vector2(0.0, 5.29),
		"tail_tip": Vector2(70.55, 8.80),
		# THE FLIGHT-DECK WINDOWS, [ACAPS]'s side view: stations 4.64 to 6.25, 8.31 to 8.74 m up; carried aft to 7.8 over the
		# side windows a 747's crew look out of beside them (ESTIMATE), which the see-out check fires through at 30 degrees.
		"windscreen": [[3.9, 7.8, 8.15, 8.95, 0.15]],
		# THE WINDOWS, MEASURED as the side view's drawn ones: the main deck's centred 5.68 m up, the upper deck's 8.32;
		# 20 inches apart (ESTIMATE, the Boeing pitch), leaving out the doors' stations (holes in the side view at 9.0,
		# 18.3, 30.1, 40.2 and 54.6 on the main deck, 14.8 on the upper).
		"cabin_windows": [
			{"from": 7.0, "to": 58.0, "pitch": 0.508, "centre": 5.68, "tall": 0.34, "wide": 0.24,
				"gaps": [[8.8, 10.3], [18.1, 19.5], [29.9, 31.3], [40.0, 41.4], [54.4, 55.8]]},
			{"from": 11.3, "to": 23.6, "pitch": 0.508, "centre": 8.32, "tall": 0.32, "wide": 0.23, "gaps": [[14.5, 16.0]]},
		],
		"fairing": {"rows": [[22.0, 2.60, 2.60, 3.80], [24.5, 3.50, 1.85, 4.20], [36.5, 3.50, 1.85, 4.20],
			[40.5, 2.50, 2.30, 3.80]]},
		"wing": {
			# MEASURED in plan: the leading edge 18.028 + 0.9121 x out (42.4 degrees, 230 rows, rms 12 mm) to its kink at
			# 21.6 m out, then 19.711 + 0.8341 x out (39.8, 150 rows); the trailing edge 34.872 + 0.3229 x out inboard of
			# its kink at 12.9 and 31.806 + 0.5685 x out (29.6 degrees) outboard. The tip at 31.6 m, where the winglet rises.
			"le": [[3.0, 20.77], [21.6, 37.73], [31.6, 46.07]],
			"te": [[3.0, 35.84], [12.9, 39.03], [31.6, 49.77]],
			# MEASURED in the front view, which draws the wing's upper and lower edges as two lines: the chord plane half
			# way between them, and the depth between them.
			"mid": [[3.0, 3.75], [10.0, 4.42], [14.0, 4.80], [18.0, 5.20], [25.0, 5.84], [31.6, 6.20]],
			"thick": [[3.0, 1.85], [10.0, 1.00], [14.0, 0.75], [18.0, 0.68], [25.0, 0.47], [31.6, 0.35]],
			"root": 3.0,
			"tip": 31.6,
			"stations": [3.0, 3.6, 10.4, 11.0, 12.9, 13.8, 20.8, 21.6, 22.0, 30.2, 31.6],
			# THE TRAILING-EDGE SURFACES, ESTIMATE ([ACAPS] draws no hinge lines): the inboard flap to the inboard engine,
			# the 747's high-speed INBOARD aileron between the flaps behind it, the outboard flap, and the low-speed aileron.
			"trailing": [
				{"name": "FlapInboard", "from": 3.6, "to": 10.4, "chord": 0.28},
				{"name": "AileronInboard", "from": 11.0, "to": 12.9, "chord": 0.24},
				{"name": "FlapOutboard", "from": 13.8, "to": 20.8, "chord": 0.26},
				{"name": "AileronOutboard", "from": 22.0, "to": 30.2, "chord": 0.22},
			],
			# THE SPOILERS, ESTIMATE: two panels inboard and four outboard, ahead of the flaps, each group on one hinge.
			"spoilers": [
				{"name": "SpoilersInboard", "fore": 0.56, "aft": 0.71, "panels": [[4.2, 6.8], [6.8, 9.8]]},
				{"name": "SpoilersOutboard", "fore": 0.58, "aft": 0.73,
					"panels": [[14.2, 15.9], [15.9, 17.6], [17.6, 19.3], [19.3, 20.6]]},
			],
			# THE WINGLET, MEASURED: the plan's 47.83 to 50.29 at 32.0 m out and 50.72 at its tip, the front view's 6.74
			# to 7.33 at 32.0 m out and its top at 7.5 m, 32.41 out: canted out about 30 degrees.
			"winglet": [[31.95, 6.95, 47.9, 50.3, 0.18], [32.22, 7.25, 48.9, 50.55, 0.12], [32.42, 7.50, 49.6, 50.72, 0.07]],
		},
		# THE CF6-80C2 NACELLES, MEASURED: in plan, 10.55 to 13.29 m out (inboard) and 19.76 to 22.50 (outboard), the
		# inlets at 23.2 and 32.1, the cowls ending 27.8 and 37.3; the front view's outboard pod 2.10 to 4.75 m up, the
		# side view's inboard pod's bottom 1.09. The nozzle and plug behind the cowl, hidden by the wing: ESTIMATE.
		# Numbered as Boeing numbers them, 1 to 4 from the port outboard.
		"nacelles": [
			_pod(-21.13, 3.43, 32.1), _pod(-11.92, 2.42, 23.2), _pod(11.92, 2.42, 23.2), _pod(21.13, 3.43, 32.1),
		],
		# THE TAILPLANE, MEASURED in plan: leading edge 56.956 + 0.9228 x out (42.7 degrees), trailing edge 66.862 +
		# 0.2649 x out, the tip 11.05 m out; its chord plane off the front view, 7.25 m up at the root to 8.70 at the tip
		# ([ACAPS] 2.3.1's tip, L, 8.39 to 9.09).
		"tailplane": {"le": Vector2(56.956, 0.9228), "te": Vector2(66.862, 0.2649), "root": 1.0, "tip": 11.05,
			"high": Vector2(7.25, 8.70), "tc": 0.10, "elevator": [2.8, 10.6, 0.28]},
		# THE FIN, MEASURED in the side view: the dorsal fillet from the crown at 53.4, then 43.649 + 1.1879 x height (49.9
		# degrees), the trailing edge 62.723 + 0.4112 x height, the tip 19.26 m up. Thickness off the front view.
		"fin": {"dorsal": [[9.18, 53.40], [9.5, 54.02], [10.0, 55.33], [10.7, 56.36]],
			"le": Vector2(43.649, 1.1879), "te": Vector2(62.723, 0.4112), "root": 9.18, "tip": 19.26,
			"tip_over_ground": 19.26, "thick": Vector2(1.20, 0.35),
			"rudder": [9.4, 18.9, 2.9, 1.2]},
		# THE GEAR. [ACAPS]: the nose gear 7.75 m aft, the body gear 25.60 m behind it and the wing gear 3.07 m ahead of
		# that; the body gear's track 3.84 m and the wing gear's 11.00; every tyre H49 x 19.0-22 (1.245 m). The bogies' two
		# axles 1.47 m apart and each axle's tyres 1.12 m apart, the pivots and the stowed places: ESTIMATE. The nose and
		# body gear fold forward, the wing gear inboard, each into a well its doors close over again.
		"gear": [
			{"name": "NoseGear", "out": 0.0, "pivot": Vector3(0.0, 3.0, 8.2), "axle": Vector3(0.0, 0.0, 7.75),
				"stowed": Vector3(0.0, 3.9, 6.3), "tyre": Vector2(1.245, 0.48), "tyres": [-0.40, 0.40], "strut": 0.13},
			{"name": "WingGear", "out": 5.5, "pivot": Vector3(5.5, 3.9, 30.6), "axle": Vector3(5.5, 0.0, 30.28),
				"stowed": Vector3(2.2, 3.0, 30.6), "tyre": Vector2(1.245, 0.48), "tyres": [-0.56, 0.56],
				"axles": [-0.735, 0.735], "strut": 0.16},
			{"name": "BodyGear", "out": 1.92, "pivot": Vector3(1.92, 3.4, 35.2), "axle": Vector3(1.92, 0.0, 33.35),
				"stowed": Vector3(1.92, 2.9, 32.7), "tyre": Vector2(1.245, 0.48), "tyres": [-0.56, 0.56],
				"axles": [-0.735, 0.735], "strut": 0.16},
		],
		"gear_doors": [
			{"name": "NoseDoor", "fore": 5.9, "aft": 8.6, "inner": 0.01, "outer": 0.60},
			{"name": "WingGearDoor", "fore": 29.1, "aft": 31.8, "inner": 1.2, "outer": 3.0},
			{"name": "BodyGearDoor", "fore": 32.0, "aft": 35.6, "inner": 0.2, "outer": 1.15},
		],
		"eye": Vector3(0.55, 8.55, 6.90),
		"room": AABB(Vector3(-0.75, 7.15, 6.20), Vector3(1.50, 1.95, 2.00)),
		"room_source": "eyes 0.55 m either side on the upper deck, level with [ACAPS]'s drawn flight-deck windows; the room MEASURED against the drawn skin",
		# THE UPPER DECK'S FLOOR, [from, to, drawn height]: the flight deck's room floor (7.15 m), from its front to where the
		# hump's crown begins to fall (22 m). ESTIMATE of its length; the height is the room's.
		"upper_floor": [6.2, 22.0, 7.15],
		# AN ORIGINAL LIVERY: white over light grey, a deep red fin and cheatline. No airline's marks.
		"livery": {
			"top": Color(0.94, 0.94, 0.95), "belly": Color(0.70, 0.72, 0.75), "belly_below": 3.3,
			"stripe": Color(0.62, 0.10, 0.14), "cheatline": Vector2(4.95, 5.30), "cheatline_from": 3.5,
			"cheatline_to": 52.0,
			"fin": Color(0.62, 0.10, 0.14), "tail": Color(0.90, 0.91, 0.92), "tail_cone": Color(0.85, 0.86, 0.88),
			"glass": Color(0.10, 0.15, 0.20), "window": Color(0.07, 0.09, 0.13),
			"wing": Color(0.74, 0.76, 0.79), "wing_under": Color(0.66, 0.68, 0.71),
			"nacelle": Color(0.90, 0.91, 0.92), "lip": Color(0.66, 0.68, 0.70), "inlet": Color(0.07, 0.07, 0.08),
			"metal": Color(0.42, 0.42, 0.44), "gear": Color(0.78, 0.78, 0.78), "tyre": Color(0.06, 0.06, 0.06),
			"floor": Color(0.36, 0.37, 0.40),
		},
	}


## THE UPPER DECK'S FLOOR, wall to wall a hand's breadth under the skin, in strips between stations so each follows the
## section's width at its height. Drawn since lane/liners' C++ step put the crew up here (2026-09-19): with no floor under
## them, a lamp holstered at a pilot's hip looked straight down 6 m through the main deck to the belly
## (`tests/signal_lamp.gd`), and the interior was a 10 m shaft.
func _extras(paint: Material) -> void:
	var f: Array = _t["upper_floor"]
	var y: float = drawn(float(f[2]))
	var tool := _tool()
	var stations: Array = []
	var s: float = float(f[0])
	while s < float(f[1]):
		stations.append(s)
		s += 2.0
	stations.append(float(f[1]))
	for i in range(stations.size() - 1):
		var a: float = stations[i]
		var b: float = stations[i + 1]
		var wa: float = skin_out(a, float(f[2])) - 0.03
		var wb: float = skin_out(b, float(f[2])) - 0.03
		Plating.facing(tool, [point(-wa, y, a), point(wa, y, a), point(wb, y, b), point(-wb, y, b)], Vector3.UP,
			_t["livery"]["floor"])
	_add(self, "UpperDeckFloor", tool, paint)


## ONE CF6-80C2 POD at `out` metres, its axis `high` metres up and its inlet at `inlet`: 2.74 m across at its widest, the
## front view's 2.56 to 2.65 m ring (Boeing prints 2.84 for the GE installation). The rings MEASURED off the plan's
## inboard pod (10.55 to 13.29 m out), the nozzle and plug ESTIMATE.
static func _pod(out: float, high: float, inlet: float) -> Dictionary:
	var d: float = inlet - 23.2
	return {"out": out, "high": high, "flat": 0.0,
		"rings": [[23.2 + d, 1.16, 1.16], [23.6 + d, 1.32, 1.32], [25.0 + d, 1.37, 1.37], [26.8 + d, 1.30, 1.30],
			[27.8 + d, 1.12, 1.12]],
		"nozzle": [29.2 + d, 0.74], "plug": 30.5 + d, "pylon": [24.6 + d, 31.4 + d, 0.22]}
