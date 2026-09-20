@tool
extends JetlinerAirframe
class_name HerculesAirframe
## A LOCKHEED C-130H HERCULES, DRAWN, in two variants on one airframe: the AC-130U SPOOKY gunship (`armed`, kind
## `gunship`), with its 25 mm GAU-12, 40 mm Bofors and 105 mm howitzer run out of the port side, and the C-130H TRANSPORT
## (`armed` false). A high straight wing on top of a round fuselage, four Allison T56s with their propellers' gearboxes
## riding high on tall nacelles, the main wheels in tandem in sponsons either side of the belly, the swept-up tail with
## the cargo RAMP under it, and one tall fin.
##
## WHY THE H. The AC-130U -- the gunship whose three guns the simulation already fires (`gun_of`: 25, 40 and 105 mm) --
## is a converted C-130H, so the H is the airframe both variants share. The C-130J looks the same from outside but for its
## six-bladed propellers and a stretched -30 fuselage; the AC-130J carries two guns, not three.
##
## THIS IS A TABLE AND FOUR FITTINGS; `JetlinerAirframe` draws the table. Every figure names its source:
## - [LM] Lockheed Martin, "C-130J Super Hercules Pocket Guide", page 6, "General Arrangement": plan, side and front of the
##   C-130J-30 drawn as vectors with printed dimensions. Used to MEASURE, not incorporated. `craft/gunship/measure_views.py`
##   redraws it from its filled paths alone and re-derives every MEASURED figure here.
## - [WP] Wikipedia, "Lockheed C-130 Hercules": the C-130H 29.79 m long, 40.41 m span, 11.84 m high; the -30 stretch "a
##   100 in (2.5 m) plug aft of the cockpit and an 80 in (2.0 m) plug at the rear of the fuselage"; the H's four-bladed
##   Hamilton Standard propellers, 13.5 ft (4.11 m) across.
## - [JJ] Jetijones' "Lockheed Martin AC-130U Line Drawing" and "Lockheed C-130H Hercules Line Drawing", Wikimedia Commons,
##   CC BY 3.0: an INDEPENDENT reference for the H's length and the AC-130U's guns, studied, not incorporated.
## - ESTIMATE where nothing gives a figure, and it says what it was reasoned from.
##
## [LM]'S VIEWS ARE NOT AT ONE SCALE, and that decided how it is read. Scaled by the printed 34.37 m length, the plan and
## the side disagree by 8.6 per cent: the side is drawn larger. Each is scaled by the length separately, and each then
## checks: the plan's span 40.15 m against 40.38 printed (-0.6 per cent), the side's height 11.62 against 11.84 (-1.9) and
## its wheelbase 12.34 against 12.30 (+0.3). The FRONT view is at the side's scale -- its fuselage 4.47 m over the
## sponsons, its fin 12.0 m up -- but its wing is drawn 9 per cent short and its gear 18 per cent narrow, so it is read
## for heights and the fuselage's section only. [JJ]'s front view has the same fault; two artists drew the same wrong wing.
##
## THE J-30 IS TURNED INTO THE H by taking the plugs out: stations aft of 7.0 m lose 2.54 m, and aft of the -30's 19.4 m
## lose 4.57 in all. The checks that they came out right are the H's own printed figures: the wheelbase 12.30 - 2.54 =
## 9.76 m against the H's 9.77, and [JJ]'s AC-130U drawing, scaled by the H's 29.79 m, putting the main wheels at 12.45 and
## 13.99 m against the side view's 12.32 and 13.85 less the plug (the printed wheelbase's 12.50 and 14.03 are drawn), and
## the keel starting its climb to the ramp at 17.4 against 17.43.
##
## THE GUNS, [JJ]'s AC-130U plan and side: the 25 mm forward of the wing (station 7.7), the 40 mm over the sponson's aft
## end (15.9) and the 105 mm just behind it (17.1), all out of the PORT side, the 105's barrel the longest. Stations are
## the drawing's scaled by its length; heights and how far each barrel reaches out are ESTIMATE off the same drawing.
## They RUN OUT and STOW (`set_guns`): stowed, each barrel is drawn back inside the skin. WHERE EACH ONE IS -- its mount's
## station and height and its barrel's reach -- is the SIMULATION'S (`gun_mount`, from `Sim.gun_of`), so the round leaves
## the muzzle a player sees: the drawing typed its own copy of the three until the lane's C++ step, when the rounds
## still left from where the first gunship's guns had been.
##
## THE CREW, captain LEFT: the eyes 0.55 m either side, 3.4 m aft of the nose tip and 3.9 m up, under the windscreen.

## The published envelope of the C-130H [WP], held by `tests/hercules.gd`.
const LENGTH: float = 29.79
const SPAN: float = 40.41
const HEIGHT: float = 11.84
const WIDTH: float = 4.32

## THE BOX THE KIND WILL GET: the fuselage's published width, the ground to the crown (4.68), the published length, half the
## published span; the mass an ESTIMATE of a flying weight between the H's 34,382 kg empty and 70,305 kg maximum.
const GEOMETRY: Dictionary = {"extents": Vector3(2.16, 2.34, 14.895), "span": 20.2, "mass": 55000.0}

## THE PROPELLERS: four blades 4.11 m across [WP], in the plane 9.45 m aft of the nose (MEASURED, [LM]'s plan), turning
## about an axis 3.85 m up, half a metre over the nacelles' middle, where a T56's reduction gearbox holds it (MEASURED:
## [LM]'s front view puts the blades' tips 6.0 m up).
const PROP_RADIUS: float = 2.055
const PROP_PLANE: float = 9.45
const PROP_AXIS_HIGH: float = 3.85
const PROP_BLADES: int = 4

## THE GUNS, in the simulation's mount order (`gun_of`: 0 the 25 mm, 1 the 40 mm, 2 the 105): what only the drawing
## needs -- the barrel's radius, its sides, and its inboard end's distance in from the skin. Where each one is and how far
## its barrel reaches is `gun_mount`'s. See the class note.
const GUNS: Array = [
	{"name": "Gun25", "radius": 0.16, "sides": 5, "inboard": 1.0},
	{"name": "Gun40", "radius": 0.12, "sides": 6, "inboard": 1.2},
	{"name": "Gun105", "radius": 0.19, "sides": 6, "inboard": 1.4},
]
## THE BARRELS ARE DRAWN TO BE SEEN, and real proportions are their floor, not their ceiling: at the first build's reach
## (0.8, 1.05 and 1.55 m) and a 0.14-0.22 m bore, the gallery's port-side picture showed three dark specks under the wing's
## shadow (team-lead, 2026-09-19: "the user asked for 3 guns poking out"). The M102's barrel is 3.3 m long and a Bofors
## L/60's 2.4, so the 105 now reaches 2.4 m out at 0.38 m across and the 40 mm 1.8 m, the 25 mm's five-barrel bundle 1.3.

## Whether this is the AC-130U. Set before `dress`.
var armed: bool = true
## THE J-30 TO LAY OVER LOCKHEED'S DRAWING: true puts the two plugs back (`stretch`), so `tests/liners_shot.gd` can render
## a silhouette the General Arrangement can be held against at x1.000. Never true in the game. Set before `dress`.
var stretched: bool = false


## A STATION ON THE H, as the J-30 has it when `stretched`: the forward plug (2.54 m) is behind the flight deck at 7.0, the
## aft plug (2.03 m) aft of the sponsons at 16.86 (the -30's 19.4).
func stretch(station: float) -> float:
	if not stretched:
		return station
	if station <= 7.0:
		return station
	if station <= 16.86:
		return station + 2.54
	return station + 4.57
var _guns: float = 1.0
var _prop_phase: float = 0.0
var _gun_mounts: Array[Node3D] = []
var _gun_rest: Array[Vector3] = []
var _gun_travel: Array[float] = []
var _props: Array[Node3D] = []


func table() -> Dictionary:
	var t: Dictionary = _h_table()
	return _stretched(t) if stretched else t


## THE TABLE WITH THE J-30'S PLUGS PUT BACK: every station through `stretch`, and a row doubled at each plug so the
## fuselage runs straight across it.
func _stretched(t: Dictionary) -> Dictionary:
	var rows: Array = []
	for row in t["fuselage"]:
		var r: Array = (row as Array).duplicate()
		var s: float = float(r[0])
		# The row at the aft plug is both of its ends: the fuselage runs straight across the 2.03 m between them. The forward
		# plug is inside the straight run from 4.5 to 16.86 already.
		if is_equal_approx(s, 16.86):
			var before: Array = r.duplicate()
			before[0] = 16.86 + 2.54
			rows.append(before)
			r[0] = 16.86 + 4.57
		else:
			r[0] = stretch(s)
		rows.append(r)
	t["fuselage"] = rows
	t["tail_tip"] = Vector2(stretch((t["tail_tip"] as Vector2).x), (t["tail_tip"] as Vector2).y)
	var rp: Dictionary = t["ramp"]
	for key in ["hinge", "end", "door_end"]:
		rp[key] = stretch(float(rp[key]))
	var fl: Vector3 = rp["floor"]
	rp["floor"] = Vector3(fl.x, fl.y, fl.z)
	var w: Dictionary = t["wing"]
	for key in ["le", "te"]:
		for row in w[key]:
			row[1] = float(row[1]) + 2.54
	for n in t["nacelles"]:
		for ring in n["rings"]:
			ring[0] = float(ring[0]) + 2.54
		n["nozzle"][0] = float(n["nozzle"][0]) + 2.54
		n["plug"] = float(n["plug"]) + 2.54
	for key in ["tailplane", "fin"]:
		var d: Dictionary = t[key]
		for line in ["le", "te"]:
			d[line] = Vector2((d[line] as Vector2).x + 4.57, (d[line] as Vector2).y)
	for row in t["fin"]["dorsal"]:
		row[1] = float(row[1]) + 4.57
	for leg in t["gear"]:
		for key in ["pivot", "axle", "stowed"]:
			var v: Vector3 = leg[key]
			leg[key] = Vector3(v.x, v.y, stretch(v.z))
	for door in t["gear_doors"]:
		door["fore"] = stretch(float(door["fore"]))
		door["aft"] = stretch(float(door["aft"]))
	return t


func _h_table() -> Dictionary:
	# THE PLAN'S HALF-WIDTHS are scaled by this to the published 4.32 m (the plan draws 4.18).
	var w: float = 2.16 / 2.08
	var paint: Color = Color(0.30, 0.32, 0.33) if armed else Color(0.56, 0.59, 0.61)
	var under: Color = Color(0.27, 0.29, 0.30) if armed else Color(0.50, 0.53, 0.55)
	return {
		"name": "Hercules",
		"geometry": GEOMETRY if not stretched else {"extents": Vector3(2.16, 2.34, 17.185), "span": 20.2, "mass": 55000.0},
		"raise": 0.0,
		# THE FUSELAGE, [station, half-width, keel, crown], MEASURED off [LM] and turned into the H: the plan's half-widths
		# x w, the side's keel and crown. Rows at the ramp's hinge (17.43), its end (20.3) and the upper door's (24.3), so
		# their skin is whole facets. From 29 aft the tail cone is under the tailplane in plan: ESTIMATE, a taper to 0.40.
		"fuselage": [
			[0.2, 0.30, 1.85, 2.46], [0.5, 0.52 * w, 1.51, 2.75], [1.0, 0.80 * w, 1.30, 2.91], [1.5, 1.06 * w, 1.13, 3.37],
			[2.0, 1.33 * w, 0.96, 3.96], [2.5, 1.55 * w, 0.82, 4.32], [3.0, 1.74 * w, 0.71, 4.52], [3.5, 1.90 * w, 0.65, 4.63],
			[4.0, 2.02 * w, 0.60, 4.68], [4.5, 2.08 * w, 0.60, 4.68], [16.86, 2.08 * w, 0.60, 4.68],
			[17.43, 2.04 * w, 0.62, 4.68], [18.43, 2.04 * w, 0.84, 4.81], [19.43, 2.04 * w, 1.28, 4.99],
			[20.30, 2.03 * w, 1.66, 5.13], [21.43, 2.02 * w, 2.14, 5.32], [22.43, 2.00 * w, 2.57, 5.49],
			[22.93, 2.00 * w, 2.79, 5.63], [23.43, 1.95 * w, 3.01, 5.62], [24.30, 1.87 * w, 3.39, 5.56],
			[25.43, 1.60, 3.82, 5.40], [26.43, 1.30, 3.95, 5.20], [27.43, 0.95, 4.15, 5.00], [28.43, 0.65, 4.37, 4.80],
			[29.43, 0.40, 4.46, 4.69],
		],
		"nose_tip": Vector2(0.0, 2.18),
		"tail_tip": Vector2(29.79, 4.58),
		# THE FLIGHT DECK'S WINDOWS, [JJ]'s side: stations 2.3 to 3.7, 3.67 to 4.1 m up; carried round the nose's
		# shoulders (ESTIMATE) so both pilots see out ahead and to their side.
		"windscreen": [[1.9, 3.95, 3.45, 4.40, 0.12]],
		"cabin_windows": [],
		# THE RAMP turns 31.5 degrees down from the belly's upsweep, which puts its tail on the ground (`tests/hercules.gd`
		# holds it there to 5 cm; the first figure, 34 degrees from the belly's measured 23-degree climb, put it 12 cm
		# under). The upper door swings 22 degrees up into the tail: it is 4 m long, hinged at its aft edge, and its sides
		# reach up to the fuselage's shoulder, so its fore upper corners climb 4.0 x sin(open) m over the hinge. At the first
		# build's 75 degrees the door stood 1.5 m out of the roof in the first ramp picture, and at 42 still 0.44 m (the
		# ramp check now holds its top under the crown). ESTIMATE, both.
		"ramp": {"hinge": 17.43, "end": 20.30, "door_end": 24.30, "open": 31.5, "door_open": 22.0,
			# THE CARGO FLOOR: 1.35 m either side, from the flight deck's bulkhead at 5.2 to the ramp's hinge, 1.04 m up
			# (41 in, ESTIMATE); 40 ft long on the H, the -30's printed 55 ft less its two plugs.
			"floor": Vector3(1.35, 5.2, 1.04)},
		"wing": {
			# MEASURED in [LM]'s plan (H stations): the leading edge straight across at 11.78 to 7.0 m out, then swept back
			# 0.024 a metre; the trailing edge 16.81 to 6.0 m out, then forward 0.137 a metre. The tip at the published
			# 20.2 m ([LM]'s plan: 20.07).
			"le": [[2.1, 11.78], [7.0, 11.78], [20.2, 12.09]],
			"te": [[2.1, 16.81], [6.0, 16.79], [20.2, 14.85]],
			# The chord plane and depth, MEASURED off [LM]'s front view at the side's scale: the lower surface 4.0 m up
			# inboard rising to 4.5 at the tip, the upper 5.1 at the root.
			"mid": [[2.1, 4.55], [7.0, 4.50], [12.0, 4.55], [16.0, 4.62], [20.2, 4.72]],
			"thick": [[2.1, 1.02], [7.0, 0.92], [12.0, 0.72], [16.0, 0.55], [20.2, 0.32]],
			"root": 2.1,
			"tip": 20.2,
			"stations": [2.1, 2.3, 12.4, 12.8, 19.0, 20.2],
			# THE FOWLER FLAPS inboard and the ailerons outboard, [LM]'s plan's hinge lines: ESTIMATE shares of the chord.
			"trailing": [
				{"name": "Flap", "from": 2.3, "to": 12.4, "chord": 0.28},
				{"name": "Aileron", "from": 12.8, "to": 19.0, "chord": 0.26},
			],
			"spoilers": [],
		},
		# THE T56 NACELLES, MEASURED in [LM]'s plan: 4.52 to 5.59 m out (inboard) and 9.77 to 10.82 (outboard), faired into
		# the wing's underside; a tall oval from [LM]'s front view, 2.5 m up at the bottom. Numbered 1 to 4 from the port
		# outboard. The exhaust behind: ESTIMATE.
		"nacelles": [_nacelle_at(-10.37), _nacelle_at(-5.09), _nacelle_at(5.09), _nacelle_at(10.37)],
		# THE TAILPLANE, MEASURED in [LM]'s plan (H stations): leading edge 24.012 + 0.264 x out (14.8 degrees), trailing edge
		# 28.882 - 0.156 x out, the tip 8.0 m out (published 16.05 m span; [LM]'s plan 15.92), flat, 4.85 m up.
		"tailplane": {"le": Vector2(24.012, 0.264), "te": Vector2(28.882, -0.156), "root": 0.5, "tip": 8.0,
			"high": Vector2(4.85, 4.85), "tc": 0.11, "elevator": [1.2, 7.6, 0.32]},
		# THE FIN, MEASURED in [LM]'s side (H stations): leading edge 19.787 + 0.578 x height (30 degrees), trailing edge
		# 29.672 - 0.1655 x height, raked FORWARD as a C-130's is; the tip 11.62 m up, drawn to the published 11.84.
		"fin": {"dorsal": [[4.7, 22.50], [5.75, 23.11]],
			"le": Vector2(19.787, 0.578), "te": Vector2(29.672, -0.1655), "root": 4.7, "tip": 11.62,
			"tip_over_ground": HEIGHT, "thick": Vector2(0.70, 0.22),
			"rudder": [4.9, 11.3, 1.6, 1.0]},
		# THE GEAR. [LM]: the nose gear 3.50 m aft of the nose (its side view measures 3.28) and the mains' middle the H's
		# 9.77 m behind it [WP], in tandem at 12.50 and 14.03 -- the side view's own tandem spacing, 1.53 m, about the
		# printed middle. The side view measures the pair at 12.32 and 13.85 (H stations); [JJ]'s AC-130U drawing, at
		# 12.45 and 13.99, sides with the printed figure. The track the printed 4.34 m. Tyres: ESTIMATE, 0.86 m twin
		# nose wheels and 1.14 m mains. The nose leg folds forward; each main RISES STRAIGHT UP into its sponson, as a
		# C-130's does, behind doors that open and shut again.
		"gear": [
			{"name": "NoseGear", "out": 0.0, "pivot": Vector3(0.0, 1.55, 3.70), "axle": Vector3(0.0, 0.0, 3.50),
				"stowed": Vector3(0.0, 1.55, 2.40), "tyre": Vector2(0.86, 0.30), "tyres": [-0.26, 0.26], "strut": 0.08},
			{"name": "MainGearFore", "out": 2.17, "pivot": Vector3(2.17, 1.20, 12.50), "axle": Vector3(2.17, 0.0, 12.50),
				"stowed": Vector3(2.17, 1.67, 12.50), "slide": true, "tyre": Vector2(1.14, 0.51), "tyres": [0.0],
				"strut": 0.12},
			{"name": "MainGearAft", "out": 2.17, "pivot": Vector3(2.17, 1.20, 14.03), "axle": Vector3(2.17, 0.0, 14.03),
				"stowed": Vector3(2.17, 1.67, 14.03), "slide": true, "tyre": Vector2(1.14, 0.51), "tyres": [0.0],
				"strut": 0.12},
		],
		"gear_doors": [
			{"name": "NoseDoor", "fore": 2.2, "aft": 3.9, "inner": 0.01, "outer": 0.42},
			{"name": "SponsonDoor", "fore": 11.75, "aft": 14.75, "inner": 1.88, "outer": 2.50},
		],
		"eye": Vector3(0.55, 3.90, 3.40),
		"room": AABB(Vector3(-0.70, 2.50, 3.30), Vector3(1.40, 1.80, 1.60)),
		"room_source": "eyes 0.55 m either side under [JJ]'s drawn windscreen, the seats EYE_HEIGHT under them; the room MEASURED against the drawn skin",
		# THE PAINT: the AC-130U in a dark gunship grey all over, the transport lighter; the radome black. ESTIMATE, no unit's
		# marks.
		"livery": {
			"top": paint, "belly": under, "belly_below": 1.2, "stripe": paint, "cheatline": Vector2(-1.0, -1.0),
			"radome": Vector2(1.05, 0.0), "radome_colour": Color(0.08, 0.08, 0.09),
			"fin": paint, "tail": paint, "tail_cone": under, "glass": Color(0.10, 0.14, 0.18), "window": Color(0.07, 0.09, 0.12),
			"wing": paint, "wing_under": under, "nacelle": paint, "lip": under, "inlet": Color(0.06, 0.06, 0.07),
			"metal": Color(0.36, 0.34, 0.32), "gear": Color(0.72, 0.72, 0.70), "tyre": Color(0.06, 0.06, 0.06),
			"hold": Color(0.18, 0.19, 0.19),
		},
	}


## ONE T56 NACELLE at `out`: a tall oval from behind the propeller's spinner to its exhaust under the wing's trailing edge.
## [LM]'s plan shows no nacelle aft of the trailing edge; the first build ran them 1.3 m past it, and the plan overlay
## showed it.
static func _nacelle_at(out: float) -> Dictionary:
	return {"out": out, "high": 3.35, "flat": 0.0,
		"rings": [[9.55, 0.40, 0.50], [9.85, 0.55, 0.80], [11.0, 0.58, 0.88], [14.0, 0.55, 0.85], [15.4, 0.40, 0.62],
			[16.0, 0.24, 0.38]],
		"nozzle": [16.25, 0.12], "plug": 16.35}


# ---- the fittings -------------------------------------------------------------------------------------------------------

func _extras(paint: Material) -> void:
	_build_sponsons(paint)
	_build_propellers(paint)
	if armed:
		_build_guns(paint)
		_build_sensor(paint)
	set_props(0.0)
	set_guns(1.0)


## THE SPONSONS, one a side: the fairings the main gear lives in, MEASURED off [LM]'s plan (2.41 to 2.56 m out, from 9.96 m
## aft) and front (2.56 m out between 0.75 and 2.25 m up), their ends ESTIMATE.
func _build_sponsons(paint: Material) -> void:
	var rows: Array = [[9.9, 2.18, 1.25, 1.95], [10.8, 2.56, 0.66, 2.30], [15.6, 2.56, 0.66, 2.30], [16.9, 2.22, 1.05, 2.00]]
	for side in [1.0, -1.0]:
		var tool := _tool()
		var loops: Array = []
		for row in rows:
			var s: float = stretch(float(row[0]))
			var o: float = float(row[1])
			var lo: float = float(row[2])
			var hi: float = float(row[3])
			loops.append([point(side * 1.90, hi, s), point(side * (o - 0.18), hi, s), point(side * o, hi - 0.25, s),
				point(side * o, lo + 0.25, s), point(side * (o - 0.18), lo, s), point(side * 1.90, lo, s)])
		_loft(tool, loops, [_t["livery"]["top"], _t["livery"]["top"], _t["livery"]["belly"], _t["livery"]["belly"],
			_t["livery"]["belly"], _t["livery"]["belly"]])
		_add(self, "Sponson" + ("Starboard" if side > 0.0 else "Port"), tool, paint)


## THE PROPELLERS: a spinner and four blades each, on a node that `set_props` turns about the thrust line.
func _build_propellers(paint: Material) -> void:
	var index: int = 0
	for nacelle in _t["nacelles"]:
		index += 1
		var out: float = float((nacelle as Dictionary)["out"])
		var hub_at: Vector3 = point(out, PROP_AXIS_HIGH, stretch(PROP_PLANE))
		var spin := Node3D.new()
		spin.name = "Propeller%dSpin" % index
		spin.position = hub_at
		add_child(spin)
		_props.append(spin)
		var tool := _tool()
		# THE SPINNER: an eight-sided cone from its tip ahead of the blades back into the nacelle's top.
		var ring: Array = []
		for k in range(8):
			var a: float = TAU * (float(k) + 0.5) / 8.0
			ring.append(Vector3(cos(a) * 0.42, sin(a) * 0.42, 0.25))
		var tip := Vector3(0.0, 0.0, -0.75)
		var back := Vector3(0.0, -0.1, 0.9)
		var metal: Color = _t["livery"]["metal"]
		for k in range(8):
			_fan(tool, tip, ring[k], ring[(k + 1) % 8], Vector3.FORWARD, metal)
			_fan(tool, back, ring[k], ring[(k + 1) % 8], Vector3.BACK, metal)
		# FOUR BLADES, each a flat slab of a blade's plan (0.30 m wide at the root to 0.18 at the tip), turned 25 degrees
		# to the disc, from the spinner to the published radius.
		for b in range(PROP_BLADES):
			var turn := Basis(Vector3.BACK, TAU * float(b) / float(PROP_BLADES))
			var pitch := Basis(Vector3.UP, deg_to_rad(25.0))
			var place := func(p: Vector2) -> Vector3: return turn * (pitch * Vector3(p.x, p.y, 0.0))
			var blade := PackedVector2Array([Vector2(-0.15, 0.40), Vector2(0.15, 0.40), Vector2(0.11, PROP_RADIUS),
				Vector2(-0.07, PROP_RADIUS)])
			_slab(tool, blade, place, turn * (pitch * Vector3.BACK), 0.025, Color(0.10, 0.10, 0.11))
		var mesh := _add(spin, "Propeller%d" % index, tool, paint)
		mesh.position = Vector3.ZERO


## THE PROPELLERS TURNING: `phase` 0 to 1 is one blade's pitch, a quarter of a turn, which is the whole of a turn as far as
## four identical blades can show, so a VAT bakes it in a quarter turn's rows and the view hands it the phase.
func set_props(phase: float) -> void:
	_prop_phase = fposmod(phase, 1.0)
	for spin in _props:
		spin.basis = Basis(Vector3.BACK, _prop_phase * TAU / float(PROP_BLADES))


func props() -> float:
	return _prop_phase


## THE GUNS, out of the port side, each on a mount that slides it in and out along its own barrel.
func _build_guns(paint: Material) -> void:
	var dark := Color(0.08, 0.08, 0.09)
	for gun in GUNS:
		var g: Dictionary = gun
		var mount_at: Dictionary = gun_mount(GUNS.find(gun))
		var s: float = stretch(float(mount_at["at"]))
		var h: float = float(mount_at["high"])
		var skin: float = skin_out(s, h)
		var r: float = float(g["radius"])
		var reach: float = float(mount_at["reach"])
		# THE PORT: a dark square in the skin, 5 mm proud of it, the barrel's width and a hand either side.
		var port := _tool()
		var half: float = r + 0.12
		Plating.facing(port, [point(-(skin + 0.005), h + half, s - half), point(-(skin + 0.005), h + half, s + half),
			point(-(skin + 0.005), h - half, s + half), point(-(skin + 0.005), h - half, s - half)], Vector3.LEFT, dark)
		_add(self, String(g["name"]) + "Port", port, paint)
		var mount := Node3D.new()
		mount.name = String(g["name"]) + "Mount"
		mount.position = point(-skin, h, s)
		add_child(mount)
		_gun_mounts.append(mount)
		_gun_rest.append(mount.position)
		_gun_travel.append(reach + 0.05)
		var tool := _tool()
		var sides: int = int(g["sides"])
		var inboard: float = float(g["inboard"])
		var loops: Array = []
		for x in [inboard, -reach]:
			var loop: Array = []
			for k in range(sides):
				var a: float = TAU * (float(k) + 0.5) / float(sides)
				loop.append(Vector3(x, cos(a) * r, sin(a) * r))
			loops.append(loop)
		_loft(tool, loops, [dark])
		# A MUZZLE BRAKE on the 105 and a flash hider on the 40: a fatter collar at the muzzle.
		if String(g["name"]) != "Gun25":
			var collar: Array = []
			for x in [-reach + 0.30, -reach - 0.02]:
				var loop: Array = []
				for k in range(sides):
					var a: float = TAU * (float(k) + 0.5) / float(sides)
					loop.append(Vector3(x, cos(a) * r * 1.6, sin(a) * r * 1.6))
				collar.append(loop)
			_loft(tool, collar, [dark])
		var mesh := _add(mount, String(g["name"]), tool, paint)
		mesh.position = Vector3.ZERO


## WHERE GUN `index` IS, asked of the simulation: `Sim.gun_of(GUNSHIP, index)`'s mount, a point on the drawn skin, as the
## station aft of the nose (`at`) and the height over the ground (`high`), and its barrel's length as how far the muzzle
## reaches past that skin (`reach`). The mount's `x` is the skin's half-width there, which `tests/hercules.gd` holds to
## `skin_out` within 5 cm.
static func gun_mount(index: int) -> Dictionary:
	var gun: Dictionary = Sim.gun_of(Sim.Kind.GUNSHIP, index)
	var at: Vector3 = gun.get("at", Vector3.ZERO)
	var half: Vector3 = GEOMETRY["extents"]
	return {"at": at.z + half.z, "high": at.y + half.y, "out": at.x, "reach": float(gun.get("barrel", 0.0))}


## THE GUNS, 0 stowed to 1 run out: stowed, each barrel is drawn back along itself until its muzzle is inside the skin.
func set_guns(amount: float) -> void:
	_guns = clampf(amount, 0.0, 1.0)
	for i in range(_gun_mounts.size()):
		_gun_mounts[i].position = _gun_rest[i] + Vector3(_gun_travel[i] * (1.0 - _guns), 0.0, 0.0)


func guns() -> float:
	return _guns


## THE GUNS AIMED, from the wire's aims for mounts 0, 1 and 2 (`VehicleView.draw_turrets_at`): each (yaw, pitch) as the
## simulation's `gun_of` has them, a yaw of a quarter turn being straight out to PORT and a negative pitch down. Each
## barrel turns about its own mount, whether run out or stowed.
func aim_guns(aimed: Array) -> void:
	for i in range(mini(aimed.size(), _gun_mounts.size())):
		var aim: Vector2 = aimed[i]
		_gun_mounts[i].basis = Basis(Vector3.UP, aim.x - PI * 0.5) * Basis(Vector3.BACK, -aim.y)


## THE SENSOR TURRET under the port side of the nose: an eight-sided ball, ESTIMATE off [JJ]'s side view.
func _build_sensor(paint: Material) -> void:
	var tool := _tool()
	var c: Vector3 = point(-0.85, 0.42, stretch(3.2))
	var r: float = 0.30
	var rings: Array = []
	for lat in [-0.8, -0.35, 0.35, 0.8]:
		var loop: Array = []
		for k in range(8):
			var a: float = TAU * (float(k) + 0.5) / 8.0
			loop.append(c + Vector3(cos(a) * r * cos(lat), r * sin(lat), sin(a) * r * cos(lat)))
		rings.append(loop)
	_loft(tool, rings, [Color(0.12, 0.12, 0.13)])
	_add(self, "SensorTurret", tool, paint)


## THE FEATURES A VAT BAKES: the common ones, the propellers' quarter turn, the ramp, and the gunship's guns.
func features() -> Array:
	var out: Array = super.features()
	out.erase(out.filter(func(f: Dictionary) -> bool: return f["name"] == "spoilers")[0])
	out.append({"name": "props", "set": set_props, "get": props, "low": 0.0, "high": 1.0, "samples": 17})
	out.append({"name": "ramp", "set": set_ramp, "get": ramp, "low": 0.0, "high": 1.0, "samples": 33})
	if armed:
		out.append({"name": "guns", "set": set_guns, "get": guns, "low": 0.0, "high": 1.0, "samples": 17})
	return out


## A FLAT SLAB from a 2D outline: `place` turns an outline point into its middle-surface position, `across` is the slab's
## normal and `half` its half-thickness. The engine's ear clipper triangulates both faces.
static func _slab(tool: SurfaceTool, outline: PackedVector2Array, place: Callable, across: Vector3, half: float,
		tint: Color) -> void:
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	var top: Array = []
	var under: Array = []
	for p in outline:
		top.append((place.call(p) as Vector3) + across * half)
		under.append((place.call(p) as Vector3) - across * half)
	for t in range(0, tris.size(), 3):
		_fan(tool, top[tris[t]], top[tris[t + 1]], top[tris[t + 2]], across, tint)
		_fan(tool, under[tris[t]], under[tris[t + 1]], under[tris[t + 2]], -across, tint)
	var n: int = outline.size()
	var centre := Vector3.ZERO
	for p in top:
		centre += p
	for p in under:
		centre += p
	centre /= float(n * 2)
	for i in range(n):
		var quad: Array = [top[i], top[(i + 1) % n], under[(i + 1) % n], under[i]]
		var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
		Plating.facing(tool, quad, mid - centre, tint)
