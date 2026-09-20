@tool
extends WarbirdAirframe
class_name P47Airframe
## A REPUBLIC P-47D-30 THUNDERBOLT, DRAWN: the bubble-top "Jug". Its first-glance features are the great round cowling of
## the R-2800 with the Curtiss paddle-bladed propeller; the deep, heavy fuselage, its belly carrying the turbocharger's
## ducting from the engine back to the turbo behind the cockpit, the intercooler's exits on its flanks and the turbo's
## hood under its tail; the bubble canopy on a cut-down spine; the elliptical wing with its eight .50s; the elliptical
## tail with the dorsal fillet; and the wide-tracked mains, which shorten as they fold INWARD. What MOVES:
## - THE GEAR (`set_gear`), in sequence: the inner doors open, the mains fold inward and shorten 9 in on the way (their
##   lower halves slide up their legs), the tail wheel folds forward into the fuselage, the inner doors shut. Each main
##   leg carries its fairing; the tail wheel's doors open as it comes down and stay open;
## - THE SURFACES: the ailerons, the elevators, the rudder and the flaps;
## - THE PROPELLER (`set_props`), clockwise seen from the cockpit.
##
## PRESENTATION ONLY. There is no P-47 kind yet (lane/warbirds, step 2): the airframe dresses from `draft()`.
##
## ORIGINAL GEOMETRY, MEASURED. No mesh, texture, photograph or livery is incorporated. Every size names its source:
## - [AN] the USAAF's three-view from AN 01-65BC-2 p.3 on Wikimedia Commons, {{PD-USGov-Military}}, with its printed
##   dimensions. It draws the RAZORBACK RP-47B, and it is the authority for what the D-30 shares with it: the WING, the
##   TAIL, the GEAR, the COWLING and the fuselage below the canopy. Its notes give the P-47C-1-and-later fuselage, 8 in
##   longer ahead of the firewall (36 ft 1-3/16 in in all): the model is that fuselage, the 8 in (0.203 m) put in at
##   station 1.80, behind the cowl flaps (ESTIMATE: the note says only "this dimension"). `craft/p47/measure_views.py`
##   re-derives every MEASURED figure here. ITS PLAN'S THREE PRINTED DIMENSIONS AGREE ON ONE SCALE, 116.00 px a metre to
##   0.05 per cent (the length, the tailplane, the root chord); its drawn SPAN is 0.95 per cent short of its own printed
##   40 ft 9-5/16 in, and so is its front view's, so the wing is built to the printed span, its planform stretched
##   spanwise by that 0.95 per cent. Its side view's heights are drawn at 119.65 px a metre against 116.85 along it
##   (+2.4 per cent), read from its two printed heights, as the P-51's sheet's are.
## - [NACA] NACA RM L8A06 (1948), Fig. 1, "Three-view layout of the P-47D-30 airplane", NTRS 20090022749, public domain:
##   the authority for what the D-30 CHANGED -- the bubble canopy, the cut-down spine, the dorsal fillet and the 13 ft
##   propeller. It is a reduced sketch that disagrees with itself (its printed span is 40 ft 0-5/16 in; its drawn
##   propeller is 6 per cent over its printed 13 ft), so its side view is REGISTERED on [AN]'s: its length on the C-1's,
##   its belly and fin top on [AN]'s, and the canopy and spine are read in that frame and laid on [AN]'s deck, which its
##   own deck sits 0.07 m under (the model lays them 0.08 up: a centimetre, a pen's width).
## - [WP] Wikipedia's P-47D specifications: 11.02 m long, 12.43 m span, 4.47 m high, 27.87 m2 of wing; the mains
##   shortening 9 in as they retract (after Friedman, 1942).
## - ESTIMATE where nothing gives a figure, and it says what it was reasoned from.
##
## STATIONS ARE METRES AFT OF THE SPINNER'S TIP ON THE C-1 FUSELAGE; HEIGHTS ARE METRES OVER THE THRUST LINE; OUT is
## metres to starboard. [AN] draws the aeroplane level and rakes the ground under it at the printed 12 degrees; the model
## is built level on its mains, the box's floor the main tyres' bottom, 2.098 m under the thrust line ([AN]'s level
## ground line), and `ground_at` is the three-point ground it PARKS on, tail down (`parked`).
##
## TESSELLATION, STATED SO NOBODY SUBDIVIDES IT: the FUSELAGE 18 facets a ring, the canopy three of them each side; the
## COWLING's front and the spinner 16; a TYRE 10; a blade four panels; a wing section seven points. The fin, rudder,
## tailplane, elevators, doors and hood are flat slabs. Every face carries its own normal; nothing is smoothed.

## [WP] The published envelope, held by `tests/p47.gd`.
const LENGTH: float = 11.02
const SPAN: float = 12.43
const HEIGHT: float = 4.47

## [AN] THE PRINTED DIMENSIONS the model is built to.
const PRINTED_SPAN: float = 12.429        # 40 ft 9-5/16 in
const PRINTED_LENGTH: float = 11.003      # 36 ft 1-3/16 in, the C-1 and later ([AN]'s note)
const PRINTED_TRACK: float = 4.750        # 15 ft 7 in
const PRINTED_TAILPLANE: float = 4.879    # 16 ft 0-3/32 in
const PRINTED_PROP: float = 3.962         # [NACA] 13 ft, the D-30's Curtiss paddle blades
## THE DRAWN SPAN, [AN]'s plan at its own scale: the wing's outs are stretched by the printed over this.
const DRAWN_SPAN: float = 12.311
const WING_STRETCH: float = PRINTED_SPAN / DRAWN_SPAN
## THE C-1'S PLUG: 8 in put in ahead of the firewall, at this station of the B's.
const PLUG_AT: float = 1.80
const PLUG: float = 0.203

## THE GROUND under the main tyres: [AN]'s level ground line, 2.098 m under the thrust line. The main tyre's drawn circle
## reaches 2.119, 2 cm under it, and is 0.965 m across against the 34 in (0.864 m) tyre [NACA] prints and [AN]'s own
## plan draws (its stowed wheels' circles are 0.853 m across): the tyre is the printed one, standing on the ground line.
const GROUND: float = -2.098
## THE FIN'S TOP: 2.073 m over the thrust line ([AN] side, at its heights' scale; printed 6 ft 10-1/32 in, 2.083).
const FIN_TOP: float = 2.073

const TOP := WarbirdAirframe.METAL
const LOWER := WarbirdAirframe.METAL_UNDER

## THE FUSELAGE, C-1 stations (the B's plus 0.203 m at and aft of 1.80). DECK is its top without the canopy: [AN]'s
## side view ahead of the windscreen, then [NACA]'s cut-down spine behind the canopy, rising gently into the fin's root.
## BOTTOM is [AN]'s side view without the turbo's hood; HALF_W [AN]'s plan, carried 0.68 m (the printed 26-3/4 in from the
## centreline to the flap's inner end) where the wing hides it.
const DECK_PROFILE: Array = [[0.60, 0.50], [0.75, 0.593], [1.00, 0.660], [1.25, 0.702], [1.50, 0.735], [1.75, 0.769],
	[2.20, 0.769], [2.45, 0.802], [2.70, 0.811], [3.62, 0.811], [5.84, 0.805], [6.07, 0.788], [6.50, 0.785],
	[7.00, 0.79], [7.64, 0.813], [8.32, 0.84], [8.76, 0.856], [9.20, 0.80], [9.70, 0.68], [10.07, 0.52]]
const BOTTOM_PROFILE: Array = [[0.60, -0.84], [0.75, -0.919], [1.00, -0.969], [1.25, -1.003], [1.50, -1.036],
	[1.75, -1.061], [2.20, -1.086], [2.45, -1.103], [2.70, -1.112], [2.95, -1.120], [3.45, -1.120], [3.70, -1.112],
	[3.95, -1.103], [4.20, -1.095], [4.45, -1.086], [4.70, -1.070], [4.95, -1.053], [5.20, -1.036], [5.45, -1.011],
	[5.70, -0.969], [5.95, -0.936], [6.20, -0.903], [6.45, -0.869], [6.70, -0.827], [6.95, -0.794], [7.20, -0.761],
	[7.45, -0.735], [7.70, -0.710], [7.95, -0.618], [8.20, -0.577], [8.45, -0.527], [8.70, -0.485], [8.95, -0.45],
	[9.20, -0.376], [9.45, -0.318], [9.70, -0.267], [9.95, -0.201], [10.07, -0.17]]
const HALF_W_PROFILE: Array = [[0.60, 0.50], [0.75, 0.55], [1.00, 0.595], [1.25, 0.62], [1.50, 0.64], [1.75, 0.65],
	[2.20, 0.66], [2.45, 0.68], [5.20, 0.68], [5.45, 0.66], [5.70, 0.63], [5.95, 0.62], [6.20, 0.61], [6.45, 0.595],
	[6.70, 0.58], [6.95, 0.565], [7.20, 0.543], [7.45, 0.52], [7.70, 0.495], [7.95, 0.465], [8.20, 0.427],
	[8.45, 0.392], [8.70, 0.353], [8.95, 0.323], [9.20, 0.306], [9.45, 0.24], [9.70, 0.207], [9.95, 0.168],
	[10.07, 0.14]]
const SQUARENESS: float = 2.4
const RINGS: Array = [0.60, 0.75, 1.00, 1.25, 1.50, 1.75, 2.20, 2.45, 2.70, 3.00, 3.30, 3.62, 3.70, 3.82, 4.05, 4.27,
	4.49, 4.72, 4.94, 5.17, 5.39, 5.62, 5.84, 6.07, 6.45, 6.95, 7.45, 7.95, 8.45, 8.95, 9.45, 9.95, 10.07]
const FUSELAGE_SIDES: int = 18
const TAIL_END: Vector2 = Vector2(10.12, 0.20)

## THE BUBBLE CANOPY [NACA side and plan, registered]: the windscreen's foot at 3.62 on the deck, its frame at 3.82, the
## hood's top 1.20 at 4.49 (its rise over [NACA]'s own deck, 0.39 m, put on [AN]'s), closing on the spine at 5.84.
## Rows [station, sill height, the glass's half-width at the sill, the glass's top]. The SILL is where the fuselage is as
## wide as the glass, 0.69 m up (ESTIMATE: the glass's 0.37 m half-width, [NACA]'s plan, laid on the section);
## a deck the width of the fuselage's top would put the glass out over the fuselage's shoulders.
const CANOPY: Vector2 = Vector2(3.62, 5.84)
const CANOPY_ROWS: Array = [[3.62, 0.811, 0.30, 0.811], [3.70, 0.76, 0.33, 0.953], [3.82, 0.71, 0.35, 1.02],
	[4.05, 0.69, 0.37, 1.125], [4.27, 0.69, 0.37, 1.193], [4.49, 0.69, 0.37, 1.201], [4.72, 0.69, 0.365, 1.184],
	[4.94, 0.70, 0.35, 1.142], [5.17, 0.71, 0.32, 1.083], [5.39, 0.72, 0.28, 1.007], [5.62, 0.75, 0.20, 0.906],
	[5.84, 0.805, 0.06, 0.805]]

## THE HUB [AN side]: a dome 0.25 m ahead of the blades, 0.20 m across its base (ESTIMATE: the drawn hub, the D-30's
## Curtiss propeller carried no large spinner). The propeller [NACA]: four paddle blades, 13 ft across, in the plane at
## station 0.50 ([AN]'s blades).
const SPINNER: Array = [[0.05, 0.08], [0.18, 0.16], [0.35, 0.20], [0.60, 0.22]]
const PROP_STATION: float = 0.50
const PROP_BLADES: int = 4
const PROP_CHORDS: Vector3 = Vector3(0.24, 0.37, 0.30)
const PROP_PITCH: float = deg_to_rad(40.0)
## THE COWLING'S MOUTH [AN front]: the front ring at 0.60 stands open, its engine a dark face 0.12 m in.

## THE WING [AN plan and front], by `measure_views.py`; B stations moved to the C-1's, outs stretched by WING_STRETCH.
## Rows [out, leading station, trailing station], both wings averaged (the two agree to 1 to 3 cm). Inboard of 0.70 the
## fuselage hides it. The MIDDLE SURFACE is -0.491 + 0.0973 x out over the thrust line, the front view's middles 2.5 to 5.5
## m out (4.9 mm rms), 5.6 degrees against the printed 6. The THICKNESS falls from 13.5 per cent of the chord at the root
## to 7.5 at the tip: the front view's depths, 11.6 per cent at 2.5 m out and 8.2 at 5.0 as drawn, less the pen.
const WING_ROWS: Array = [[0.70, 2.620, 5.393], [1.20, 2.677, 5.393], [1.70, 2.707, 5.350], [2.20, 2.733, 5.298],
	[2.70, 2.738, 5.229], [3.20, 2.768, 5.143], [3.70, 2.819, 5.048], [4.20, 2.841, 4.932], [4.70, 2.871, 4.789],
	[5.00, 2.884, 4.677], [5.20, 2.897, 4.587], [5.40, 2.910, 4.483], [5.60, 2.944, 4.354], [5.80, 3.009, 4.186],
	[5.90, 3.061, 4.091], [6.00, 3.147, 3.953], [6.10, 3.289, 3.768], [6.155, 3.44, 3.62]]
const WING_ROOT: float = 0.55
const WING_MID: Vector2 = Vector2(-0.491, 0.0973)
const WING_THICK: Vector2 = Vector2(0.135, 0.075)
## THE HINGED SURFACES [AN plan's dashed hinge lines, NACA's printed spans]: the flap from the fuselage's side to 3.35 m out
## (26-3/4 in and 11 ft 0 in), its hinge from station 4.89 at 0.70 m out to 4.53 at 3.29; the aileron from 3.35 to 5.91
## m out (8 ft 4-15/32 in), its hinge from 4.68 at 3.34 to 3.95 at 5.78. Drawn outs, before the stretch.
const FLAP_SPAN: Vector2 = Vector2(0.70, 3.35)
const AILERON_SPAN: Vector2 = Vector2(3.35, 5.85)
const FLAP_HINGE: Array = [[0.70, 4.893], [3.29, 4.533]]
const AILERON_HINGE: Array = [[3.34, 4.683], [5.78, 3.953]]

## THE EIGHT .50s [AN front]: four muzzles in each wing's leading edge, 2.68, 2.84, 2.99 and 3.20 m out, on the middle
## surface; drawn standing 0.10 m proud (ESTIMATE, photographs).
const GUNS: Array = [2.68, 2.84, 2.99, 3.20]
const GUN_PROUD: float = 0.10

## THE TAILPLANE [AN plan; side's printed 12 in]: its middle 0.305 m over the thrust line; rows [out, leading, trailing],
## both sides averaged, to its tip at 2.44 m out; the elevators' hinge straight at 10.34 (the plan's dash-dot line, and the
## printed 18-3/32 in of elevator chord at its root).
const TAIL_H: float = 0.305
const TAIL_ROWS: Array = [[0.30, 9.199, 10.643], [0.60, 9.298, 10.794], [0.90, 9.393, 10.807], [1.20, 9.488, 10.803],
	[1.50, 9.583, 10.746], [1.80, 9.677, 10.690], [2.10, 9.768, 10.604], [2.25, 9.859, 10.531], [2.35, 9.971, 10.458],
	[2.44, 10.143, 10.315]]
const ELEVATOR_HINGE: float = 10.34
const ELEVATOR_ROOT: float = 0.18
## THE FIN AND DORSAL FILLET [AN side, NACA's fillet]: [station, height] from the fillet's start along the spine, up the
## leading edge, over the top to the rudder's hinge at 10.07 ([AN] side's hinge line; its printed fin chord 4 ft
## 5-15/16 in and rudder chord 23-11/16 in), and down into the fuselage.
const FIN: Array = [[7.20, 0.72], [8.30, 0.83], [8.95, 0.92], [9.45, 1.55], [9.75, 1.92], [9.95, 2.05], [10.065, 2.073],
	[10.065, 0.40], [9.20, 0.62], [7.40, 0.70]]
const RUDDER_HINGE: float = 10.07
const RUDDER: Array = [[10.075, 2.07], [10.25, 2.00], [10.45, 1.61], [10.62, 1.10], [10.72, 0.80], [11.00, 0.46],
	[11.00, 0.30], [10.85, 0.10], [10.62, -0.04], [10.40, -0.08], [10.075, -0.09]]
## THE INTERCOOLER'S EXITS on each flank [AN side's rectangle, NACA's label]: stations 6.60 to 7.03, 0.18 m under to
## 0.25 m over the thrust line. THE TURBO'S HOOD under the tail [AN side's bump]: 7.20 to 7.70, 0.05 m deep.
const INTERCOOLER: Vector4 = Vector4(6.60, 7.03, -0.18, 0.25)
## Its shutters' grey: the first pictures drew the exits black, and a black square on a bare-metal flank reads as a hole.
const EXIT_GREY := Color(0.38, 0.39, 0.40)
const HOOD: Vector3 = Vector3(7.20, 7.70, 0.05)

## THE GEAR [AN; NACA's 34 x 9 tyres]:
## - THE MAIN TYRES are 0.864 m across and 0.229 wide, their axles 2.375 m either side (the printed 15 ft 7 in) at
##   station 2.86 ([AN] side's circle, the B's 2.657 plus the plug), standing on the ground line.
## - EACH LEG pivots in the wing at 0.26 m under the thrust line, station 3.40 (ESTIMATE: so that the leg is upright from
##   ahead, raked forward from the side as [AN] draws it, and the wheel lies FLAT in its well), and folds inward,
##   SHORTENING 9 in as it goes ([WP], after Friedman), its wheel coming to lie in its well: [AN]'s plan's dashed circles,
##   0.853 m across at 1.10 and 1.13 m out, station 3.57.
## - THE TAIL WHEEL is 0.34 m across at station 9.04, 0.607 m under the thrust line ([AN]'s circle); it folds forward
##   about a pivot at 8.80, 0.30 under (ESTIMATE).
const MAIN_TYRE: Vector2 = Vector2(0.864, 0.229)
const MAIN_AXLE: Vector3 = Vector3(2.375, -1.666, 2.86)
const MAIN_PIVOT: Vector3 = Vector3(2.375, -0.26, 3.40)
const MAIN_WELL: Vector3 = Vector3(1.116, -0.39, 3.57)
const TELESCOPE: float = 0.229
## THE INNER DOORS, hinged 0.62 m out just inside the fuselage's side, swing down PAST UPRIGHT (105 degrees), so the wheel's
## inner edge, which stows 0.686 m out, passes outboard of them: hinged at 0.70 and opened 85, and at 0.66 and 100, they
## stood in its way (tests/p47.gd, 28 and 32 per cent of the cycle).
const INNER_DOOR: Vector4 = Vector4(3.12, 4.02, 0.62, 1.55)   # fore, aft, inner (the hinge), outer
const INNER_DOOR_OPEN: float = deg_to_rad(105.0)
const TAIL_TYRE: Vector2 = Vector2(0.34, 0.12)
const TAIL_AXLE: Vector2 = Vector2(9.04, -0.607)
const TAIL_PIVOT: Vector2 = Vector2(8.80, -0.28)
const TAIL_STOWED: Vector2 = Vector2(8.42, -0.22)
const TAIL_DOOR: Vector3 = Vector3(8.55, 9.25, 0.14)
const WHEEL_SIDES: int = 10
const DOOR_OPEN: float = deg_to_rad(85.0)


func dress(geometry: Dictionary = {}) -> void:
	name = "P47"
	_take(geometry)
	# TRAVELS, ESTIMATE but for the elevators: [NACA]'s control graphs read about 12 degrees of aileron and a little over
	# 20 of rudder; the elevators 30 up and 20 down; the flaps 40.
	aileron_travel = deg_to_rad(15.0)
	elevator_up = deg_to_rad(30.0)
	elevator_down = deg_to_rad(20.0)
	rudder_travel = deg_to_rad(25.0)
	flap_travel = deg_to_rad(40.0)
	var paint: StandardMaterial3D = _paint()
	var inside: StandardMaterial3D = _paint()
	inside.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := _tool()
	var canopy := _tool()
	_fuselage(body, canopy)
	var fuselage := _add(self, "Fuselage", body, paint)
	fuselage.material_override = null
	fuselage.mesh = canopy.commit(fuselage.mesh as ArrayMesh)
	fuselage.set_surface_override_material(0, inside)
	fuselage.set_surface_override_material(1, _glass())
	# THE COAMING closes the nose off from the eye (`WarbirdAirframe._coaming`, lane/warbirds2).
	var coaming := _tool()
	_coaming(coaming)
	_add(self, "Coaming", coaming, paint)
	var spinner := _tool()
	_spinner(spinner, point(0.0, 0.0, 0.0), point(0.0, 0.0, float(SPINNER[-1][0])), SPINNER, 16, DARK)
	_add(self, "Spinner", spinner, paint)
	_propeller("Propeller", point(0.0, 0.0, PROP_STATION), PRINTED_PROP * 0.5, PROP_BLADES, PROP_CHORDS, PROP_PITCH,
		1.0, 0.24, paint)
	var flanks := _tool()
	_flanks(flanks)
	_small(_add(self, "Intercooler", flanks, paint))
	var hood := _tool()
	Plating.box(hood, point(0.0, bottom_at((HOOD.x + HOOD.y) * 0.5) - HOOD.z * 0.5 + 0.02, (HOOD.x + HOOD.y) * 0.5),
		Vector3(0.40, HOOD.z + 0.04, HOOD.y - HOOD.x), DARK)
	_add(self, "TurboHood", hood, paint)
	var wells := _tool()
	_wells(wells)
	_add(self, "Wells", wells, paint)
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var wing := _tool()
		_wing(wing, side)
		_add(self, "Wing" + named, wing, paint)
		var guns := _tool()
		_guns(guns, side)
		_small(_add(self, "Guns" + named, guns, paint))
		_surface("Aileron" + named, side, AILERON_SPAN, AILERON_HINGE, false, paint)
		_surface("Flap" + named, side, FLAP_SPAN, FLAP_HINGE, true, paint)
		_elevator(side, named, paint)
	var tail := _tool()
	_tailplane(tail)
	_add(self, "Tailplane", tail, paint)
	var fin := _tool()
	_slab(fin, _outline(FIN), func(p: Vector2) -> Vector3: return point(0.0, p.y, p.x), Vector3.RIGHT, 0.05, TOP)
	_add(self, "Fin", fin, paint)
	_rudder(paint)
	_build_gear(paint)
	set_gear(1.0)


func draft() -> Dictionary:
	return {"extents": Vector3(0.72, (FIN_TOP - GROUND) * 0.5, PRINTED_LENGTH * 0.5), "span": PRINTED_SPAN}


func kind_id() -> int:
	return Sim.Kind.P47


# ---- the cockpit ------------------------------------------------------------------------------------------------------

## THE PILOT'S EYE, ESTIMATE: 0.93 m over the thrust line at station 4.55, just aft of the bubble's crown at 4.49, 0.27 m
## under the hood's top there and 0.24 m over the sill CANOPY_ROWS draws; no station diagram is public. `p47_shape` puts
## the seat `CockpitStation.EYE_HEIGHT` under it.
const EYE: Vector2 = Vector2(4.55, 0.93)
## THE INSTRUMENT PANEL at station 3.82, the ring where the windscreen's frame stands, 0.73 m ahead of the eye; the glare
## shield's deck runs forward from it to the windscreen's foot at 3.62 (ESTIMATE, photographs of a P-47D's cockpit).
const PANEL: float = 3.82
## THE ROOM promised round the pilot, (out, height over the thrust line, station): a Thunderbolt's cockpit was famously
## roomy, and this is 0.56 m across against a Mustang's 0.48. Held inside the drawn skin by `tests/p47.gd`.
const ROOM: AABB = AABB(Vector3(-0.28, -0.60, 4.15), Vector3(0.56, 1.20, 0.90))


func eye_at() -> Vector2:
	return EYE


func room() -> AABB:
	return ROOM


func panel_station() -> float:
	return PANEL


func ring_stations() -> Array:
	return RINGS


func section_at(s: float) -> Array:
	return half_section(s)


func sill_index() -> int:
	return 3


func windscreen_foot() -> float:
	return CANOPY.x


## THE STARBOARD MAIN'S, THE PORT MAIN'S AND THE TAIL WHEEL'S TYRE BOTTOMS, each under its axle.
func wheel_contacts() -> Array:
	return [point(MAIN_AXLE.x, MAIN_AXLE.y - MAIN_TYRE.x * 0.5, MAIN_AXLE.z),
		point(-MAIN_AXLE.x, MAIN_AXLE.y - MAIN_TYRE.x * 0.5, MAIN_AXLE.z),
		point(0.0, TAIL_AXLE.y - TAIL_TYRE.x * 0.5, TAIL_AXLE.x)]


## THE EIGHT MUZZLES, craft-local, starboard and port alternately inboard to outboard: each gun barrel's front end as
## `_guns` draws it, GUN_PROUD ahead of the leading edge, on the wing's middle surface. `loadout_of`'s battery is typed
## from these, and `tests/warbird_guns.gd` holds every round's birth to one of them.
func muzzles() -> Array:
	var out: Array = []
	for g in GUNS:
		var at: float = float(g) * WING_STRETCH
		for side in [1.0, -1.0]:
			out.append(point(side * at, wing_mid(at), wing_le(at) - GUN_PROUD))
	return out


func ground_height() -> float:
	return GROUND


## PARKED TAIL DOWN on the three-point ground (`ground_at`).
func parked() -> Transform3D:
	return _three_point(Vector2(MAIN_AXLE.z, MAIN_AXLE.y), MAIN_TYRE.x * 0.5, TAIL_AXLE, TAIL_TYRE.x * 0.5)


## THE THREE-POINT GROUND, as a height over the thrust line at `station`, through both tyres' bottoms.
static func ground_at(station: float) -> float:
	var main_bottom := Vector2(MAIN_AXLE.z, MAIN_AXLE.y - MAIN_TYRE.x * 0.5)
	var tail_bottom := Vector2(TAIL_AXLE.x, TAIL_AXLE.y - TAIL_TYRE.x * 0.5)
	return lerpf(main_bottom.y, tail_bottom.y, (station - main_bottom.x) / (tail_bottom.x - main_bottom.x))


# ---- the shapes, read off the tables ----------------------------------------------------------------------------------

static func deck_at(s: float) -> float:
	return _profile(DECK_PROFILE, s)


static func bottom_at(s: float) -> float:
	return _profile(BOTTOM_PROFILE, s)


static func half_width_at(s: float) -> float:
	return _profile(HALF_W_PROFILE, s)


static func canopy_at(s: float) -> Vector3:
	for i in range(CANOPY_ROWS.size() - 1):
		var a: Array = CANOPY_ROWS[i]
		var b: Array = CANOPY_ROWS[i + 1]
		if s <= float(b[0]):
			var t: float = clampf((s - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
			return Vector3(lerpf(float(a[1]), float(b[1]), t), lerpf(float(a[2]), float(b[2]), t),
				lerpf(float(a[3]), float(b[3]), t))
	var last: Array = CANOPY_ROWS[-1]
	return Vector3(float(last[1]), float(last[2]), float(last[3]))


static func glazed(s: float) -> bool:
	return s >= CANOPY.x - 0.001 and s <= CANOPY.y + 0.001


static func _oval(s: float, theta: float) -> Vector2:
	var top: float = deck_at(s)
	var bottom: float = bottom_at(s)
	var w: float = half_width_at(s)
	var c: float = (top + bottom) * 0.5
	var b: float = (top - bottom) * 0.5
	var e: float = 2.0 / SQUARENESS
	return Vector2(w * pow(absf(sin(theta)), e), c + b * signf(cos(theta)) * pow(absf(cos(theta)), e))


## ONE RING's half-section: ten points, nine facets, the canopy's four over the glass (`P51Airframe.half_section`'s).
static func half_section(s: float) -> Array:
	var half: Array = []
	for k in range(10):
		half.append(_oval(s, PI * float(k) / 9.0))
	if glazed(s):
		var c: Vector3 = canopy_at(s)
		var sill: float = c.x
		var gw: float = c.y
		var top: float = c.z
		half[0] = Vector2(0.0, top)
		half[1] = Vector2(0.50 * gw, top - 0.14 * (top - sill))
		half[2] = Vector2(0.82 * gw, sill + 0.45 * (top - sill))
		half[3] = Vector2(gw, sill)
		var shoulder: Vector2 = half[4]
		half[4] = Vector2(maxf(shoulder.x, gw + 0.015), minf(shoulder.y, sill - 0.015))
	return half


func _fuselage_ring(s: float) -> Array:
	var half: Array = half_section(s)
	var points: Array = []
	for i in range(half.size() - 1):
		points.append(point((half[i] as Vector2).x, (half[i] as Vector2).y, s))
	for i in range(half.size() - 1, 0, -1):
		points.append(point(-(half[i] as Vector2).x, (half[i] as Vector2).y, s))
	return points


## THE FUSELAGE: 18 facets a ring; the canopy's three a side into `canopy`; an olive anti-glare panel ahead of the glass.
## The cowling's front ring is left open and the engine is a dark face 0.12 m inside it.
func _fuselage(tool: SurfaceTool, canopy: SurfaceTool) -> void:
	var rings: Array = []
	for s in RINGS:
		rings.append(_fuselage_ring(float(s)))
	var n: int = FUSELAGE_SIDES
	for r in range(rings.size() - 1):
		var here: float = (float(RINGS[r]) + float(RINGS[r + 1])) * 0.5
		var glass: bool = here > CANOPY.x and here < CANOPY.y
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		var centre: Vector3 = point(0.0, (deck_at(here) + bottom_at(here)) * 0.5, here)
		for k in range(n):
			var quad: Array = [a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]]
			var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
			var out: Vector3 = Vector3(mid.x - centre.x, mid.y - centre.y, 0.0)
			if glass and (k <= 2 or k >= n - 3):
				_quad(canopy, quad, out, GLASS)
				continue
			var normal: Vector3 = ((quad[2] as Vector3) - (quad[0] as Vector3)).cross(
				(quad[1] as Vector3) - (quad[0] as Vector3)).normalized()
			if normal.dot(out) < 0.0:
				normal = -normal
			var tint: Color = TOP if normal.y > 0.2 else LOWER
			if here > 1.8 and here < CANOPY.x and normal.y > 0.6:
				tint = OLIVE
			_quad(tool, quad, out, tint)
	# THE COWLING'S MOUTH: the first ring's inner lip 0.10 m inside it, and the engine's dark face behind that.
	var first: Array = rings[0]
	var lip: Array = []
	var face_centre: Vector3 = point(0.0, (deck_at(0.60) + bottom_at(0.60)) * 0.5, 0.72)
	for p in first:
		lip.append(face_centre + ((p as Vector3) - point(0.0, (deck_at(0.60) + bottom_at(0.60)) * 0.5, 0.60)) * 0.88)
	for k in range(n):
		var k2: int = (k + 1) % n
		var wall: Array = [first[k], first[k2], lip[k2], lip[k]]
		var mid: Vector3 = ((wall[0] as Vector3) + wall[1] + wall[2] + wall[3]) * 0.25
		_quad(tool, wall, face_centre - mid, METAL_UNDER)
		_fan(tool, face_centre, lip[k], lip[k2], Vector3.FORWARD, BLACK)
	var last: Array = rings[rings.size() - 1]
	var end: Vector3 = point(0.0, TAIL_END.y, TAIL_END.x)
	for k in range(n):
		_fan(tool, end, last[k], last[(k + 1) % n], Vector3.BACK, LOWER)


## THE INTERCOOLER'S EXITS: a grey panel 1 cm proud of each flank.
func _flanks(tool: SurfaceTool) -> void:
	for side in [1.0, -1.0]:
		var s: float = (INTERCOOLER.x + INTERCOOLER.y) * 0.5
		var h: float = (INTERCOOLER.z + INTERCOOLER.w) * 0.5
		var w: float = _width_at_height(s, h)
		Plating.box(tool, point(side * (w + 0.005), h, s), Vector3(0.03, INTERCOOLER.w - INTERCOOLER.z,
			INTERCOOLER.y - INTERCOOLER.x), EXIT_GREY)


## The fuselage's half-width at station `s` and `h` over the thrust line, off its section.
static func _width_at_height(s: float, h: float) -> float:
	var top: float = deck_at(s)
	var bottom: float = bottom_at(s)
	var c: float = (top + bottom) * 0.5
	var b: float = (top - bottom) * 0.5
	var y: float = clampf(absf(h - c) / b, 0.0, 1.0)
	return half_width_at(s) * pow(1.0 - pow(y, SQUARENESS), 1.0 / SQUARENESS)


## THE WELLS: a green patch 2 cm inside the wing's lower skin over each main well, and one over the tail wheel's.
func _wells(tool: SurfaceTool) -> void:
	for side in [1.0, -1.0]:
		var corners: Array = []
		for c in [[INNER_DOOR.z, INNER_DOOR.x], [INNER_DOOR.w, INNER_DOOR.x], [INNER_DOOR.w, INNER_DOOR.y],
				[INNER_DOOR.z, INNER_DOOR.y]]:
			corners.append(point(side * float(c[0]), _underside(float(c[0])) + 0.02, float(c[1])))
		_quad(tool, corners, Vector3.DOWN, WELL)
	var tail: Array = []
	for c in [[TAIL_DOOR.z, TAIL_DOOR.x], [-TAIL_DOOR.z, TAIL_DOOR.x], [-TAIL_DOOR.z, TAIL_DOOR.y], [TAIL_DOOR.z, TAIL_DOOR.y]]:
		tail.append(point(float(c[0]), bottom_at(float(c[1])) + 0.02, float(c[1])))
	_quad(tool, tail, Vector3.DOWN, WELL)


## THE WING'S LOWER SKIN at `out`, at its thickest (the door and the well lie there).
static func _underside(out: float) -> float:
	return wing_mid(out) - wing_thick_at(out) * 0.5


# ---- the wing -------------------------------------------------------------------------------------------------------

## THE WING'S ROWS at `out` (a model's out, stretched): (leading station, trailing station).
static func _wing_row(out: float) -> Vector2:
	var drawn: float = clampf(absf(out) / WING_STRETCH, float(WING_ROWS[0][0]), float(WING_ROWS[-1][0]))
	for i in range(WING_ROWS.size() - 1):
		var a: Array = WING_ROWS[i]
		var b: Array = WING_ROWS[i + 1]
		if drawn <= float(b[0]):
			var t: float = (drawn - float(a[0])) / (float(b[0]) - float(a[0]))
			return Vector2(lerpf(float(a[1]), float(b[1]), t), lerpf(float(a[2]), float(b[2]), t))
	return Vector2(float(WING_ROWS[-1][1]), float(WING_ROWS[-1][2]))


static func wing_le(out: float) -> float:
	return _wing_row(out).x


static func wing_te(out: float) -> float:
	return _wing_row(out).y


static func wing_tip() -> float:
	return float(WING_ROWS[-1][0]) * WING_STRETCH


static func wing_mid(out: float) -> float:
	return WING_MID.x + WING_MID.y * absf(out)


static func wing_thick_at(out: float) -> float:
	var a: float = absf(out)
	return lerpf(WING_THICK.x, WING_THICK.y, clampf((a - 0.7) / (wing_tip() - 0.7), 0.0, 1.0)) * (wing_te(a) - wing_le(a))


## A HINGE LINE's station at a model's `out`, off a two-row table in drawn outs.
static func _hinge_on(rows: Array, out: float) -> float:
	var drawn: float = absf(out) / WING_STRETCH
	var a: Array = rows[0]
	var b: Array = rows[1]
	return lerpf(float(a[1]), float(b[1]), (drawn - float(a[0])) / (float(b[0]) - float(a[0])))


## THE HINGE behind the wing at a model's `out`, or the trailing edge where nothing is hinged.
static func hinge_at(out: float) -> float:
	var drawn: float = absf(out) / WING_STRETCH
	if drawn >= FLAP_SPAN.x - 0.001 and drawn <= FLAP_SPAN.y + 0.001:
		return _hinge_on(FLAP_HINGE, out)
	if drawn >= AILERON_SPAN.x - 0.001 and drawn <= AILERON_SPAN.y + 0.001:
		return _hinge_on(AILERON_HINGE, out)
	return wing_te(out)


static func _depth_at(out: float, at: float) -> float:
	var le: float = wing_le(out)
	var te: float = wing_te(out)
	var f: float = clampf((at - le) / (te - le), 0.35, 1.0)
	return maxf(wing_thick_at(out) * 0.5 * (1.0 - f) / 0.65, 0.005)


## A SEVEN-POINT SECTION at `out` from the leading edge to `end`: thickest at 35 per cent (the S-3's).
func _section(out: float, end: float, side: float) -> Array:
	var le: float = wing_le(out)
	var te: float = wing_te(out)
	var c: float = te - le
	var mid: float = wing_mid(out)
	var t: float = wing_thick_at(out)
	var at_end: float = _depth_at(out, end)
	return [point(side * out, mid, le), point(side * out, mid + 0.42 * t, le + 0.12 * c),
		point(side * out, mid + 0.5 * t, le + 0.35 * c), point(side * out, mid + at_end, end),
		point(side * out, mid - at_end, end), point(side * out, mid - 0.5 * t, le + 0.35 * c),
		point(side * out, mid - 0.42 * t, le + 0.12 * c)]


const _SURFACE_TINTS: Array = [TOP, TOP, TOP, LOWER, LOWER, LOWER, LOWER]


## THE WING, one side: a closed loft between each pair of sections -- at the root, at every row of the table and at each
## surface's ends -- cut at the hinge where a surface is hinged behind it.
func _wing(tool: SurfaceTool, side: float) -> void:
	var outs: Array = [WING_ROOT]
	for row in WING_ROWS:
		outs.append(float(row[0]) * WING_STRETCH)
	for x in [FLAP_SPAN.x, FLAP_SPAN.y, AILERON_SPAN.x, AILERON_SPAN.y]:
		outs.append(float(x) * WING_STRETCH)
	outs.sort()
	var clean: Array = []
	for o in outs:
		if clean.is_empty() or float(o) - float(clean[-1]) > 0.005:
			clean.append(o)
	for i in range(clean.size() - 1):
		var a: float = float(clean[i])
		var b: float = float(clean[i + 1])
		var drawn_mid: float = (a + b) * 0.5 / WING_STRETCH
		# EACH BAY CUT AT THE HINGE OF THE SURFACE BEHIND IT, at both its ends: the flap's and the aileron's hinges meet
		# 0.15 m apart at the flap's end, and a section shared by both bays, cut at the flap's, left a white wedge ahead of
		# the aileron's root in the first plan overlay.
		var rows: Array = []
		if drawn_mid > FLAP_SPAN.x and drawn_mid < FLAP_SPAN.y:
			rows = FLAP_HINGE
		elif drawn_mid > AILERON_SPAN.x and drawn_mid < AILERON_SPAN.y:
			rows = AILERON_HINGE
		var loops: Array = []
		for out in [a, b]:
			loops.append(_section(float(out), _hinge_on(rows, float(out)) if not rows.is_empty() else wing_te(float(out)), side))
		_loft(tool, loops, _SURFACE_TINTS)


## A HINGED SURFACE, one side, from `span.x` to `span.y` drawn outs: hinged on the middle surface (an aileron) or under
## the wing on its lower skin (a flap, `under`), turning trailing edge down.
func _surface(named: String, side: float, span: Vector2, hinge_rows: Array, under: bool, paint: Material) -> void:
	var o0: float = span.x * WING_STRETCH + 0.02
	var o1: float = span.y * WING_STRETCH - 0.02
	var at := func(o: float) -> Vector3:
		var h: float = _hinge_on(hinge_rows, o)
		return point(side * o, wing_mid(o) - (_depth_at(o, h) if under else 0.0), h)
	var inner: Vector3 = at.call(o0)
	var outer: Vector3 = at.call(o1)
	var mid: Vector3 = (inner + outer) * 0.5
	var hinge := _hinge(named, self, mid, outer - inner, mid + Vector3.BACK, Vector3.DOWN)
	var tool := _tool()
	var loops: Array = []
	# A SECTION AT EACH OF THE WING'S ROWS the surface spans, so its trailing edge follows the elliptical wing's: two
	# sections, one at each end, drew the aileron's trailing edge straight across a curve (0.6 m inside it at 4.7 m out).
	var outs: Array = [o0]
	for row in WING_ROWS:
		var o: float = float(row[0]) * WING_STRETCH
		if o > o0 + 0.01 and o < o1 - 0.01:
			outs.append(o)
	outs.append(o1)
	for o in outs:
		var h: float = _hinge_on(hinge_rows, float(o))
		var te: float = wing_te(float(o))
		var m: float = wing_mid(float(o))
		var d: float = _depth_at(float(o), h + 0.01)
		loops.append([point(side * float(o), m + d, h + 0.01) - mid, point(side * float(o), m + 0.005, te) - mid,
			point(side * float(o), m - 0.005, te) - mid, point(side * float(o), m - d, h + 0.01) - mid])
	_loft(tool, loops, [TOP, TOP, LOWER, LOWER])
	_add(hinge, named, tool, paint)


## THE EIGHT .50s, four each side, standing `GUN_PROUD` ahead of the leading edge on the middle surface.
func _guns(tool: SurfaceTool, side: float) -> void:
	for drawn in GUNS:
		var out: float = float(drawn) * WING_STRETCH
		var le: float = wing_le(out)
		var loops: Array = []
		for s in [le - GUN_PROUD, le + 0.25]:
			loops.append(_ring(point(side * out, wing_mid(out), float(s)), Vector3.BACK, 0.022, 0.022, 6))
		_loft(tool, loops, [GUNMETAL])


# ---- the tail -------------------------------------------------------------------------------------------------------

static func tail_row(out: float) -> Vector2:
	var a0: float = absf(out)
	if a0 <= float(TAIL_ROWS[0][0]):
		return Vector2(float(TAIL_ROWS[0][1]), float(TAIL_ROWS[0][2]))
	for i in range(TAIL_ROWS.size() - 1):
		var a: Array = TAIL_ROWS[i]
		var b: Array = TAIL_ROWS[i + 1]
		if a0 <= float(b[0]):
			var t: float = (a0 - float(a[0])) / (float(b[0]) - float(a[0]))
			return Vector2(lerpf(float(a[1]), float(b[1]), t), lerpf(float(a[2]), float(b[2]), t))
	return Vector2(float(TAIL_ROWS[-1][1]), float(TAIL_ROWS[-1][2]))


## THE TAILPLANE, both sides in one slab through the fuselage, its leading edge to the elevators' hinge; past the hinge's
## reach at the tips, to its own trailing edge.
func _tailplane(tool: SurfaceTool) -> void:
	var starboard: Array = [[0.0, float(TAIL_ROWS[0][1])]]
	for row in TAIL_ROWS:
		starboard.append([float(row[0]), float(row[1])])
	# From the tip in: along the tip's own trailing edge while it is ahead of the hinge, then along the hinge.
	for i in range(TAIL_ROWS.size() - 1, -1, -1):
		var row: Array = TAIL_ROWS[i]
		if float(row[2]) < ELEVATOR_HINGE:
			starboard.append([float(row[0]), float(row[2])])
	starboard.append([_elevator_tip(), ELEVATOR_HINGE])
	starboard.append([ELEVATOR_ROOT - 0.01, ELEVATOR_HINGE])
	starboard.append([ELEVATOR_ROOT - 0.01, tail_row(ELEVATOR_ROOT).y])
	starboard.append([0.0, float(TAIL_ROWS[0][2])])
	var outline: Array = starboard.duplicate()
	for i in range(starboard.size() - 2, 0, -1):
		outline.append([-float(starboard[i][0]), float(starboard[i][1])])
	var place := func(p: Vector2) -> Vector3: return point(p.x, TAIL_H, p.y)
	_slab(tool, _outline(outline), place, Vector3.UP, 0.05, TOP, LOWER)


## HOW FAR OUT THE ELEVATOR REACHES: where the tailplane's trailing edge comes forward to the hinge.
static func _elevator_tip() -> float:
	for i in range(TAIL_ROWS.size() - 1):
		var a: Array = TAIL_ROWS[i]
		var b: Array = TAIL_ROWS[i + 1]
		if float(a[2]) >= ELEVATOR_HINGE and float(b[2]) < ELEVATOR_HINGE:
			return lerpf(float(a[0]), float(b[0]), (float(a[2]) - ELEVATOR_HINGE) / (float(a[2]) - float(b[2])))
	return float(TAIL_ROWS[-1][0])


func _elevator(side: float, named: String, paint: Material) -> void:
	var reach: float = _elevator_tip()
	var inner: Vector3 = point(side * ELEVATOR_ROOT, TAIL_H, ELEVATOR_HINGE)
	var outer: Vector3 = point(side * reach, TAIL_H, ELEVATOR_HINGE)
	var mid: Vector3 = (inner + outer) * 0.5
	var hinge := _hinge("Elevator" + named, self, mid, outer - inner, mid + Vector3.BACK, Vector3.DOWN)
	var tool := _tool()
	var outline: Array = [[ELEVATOR_ROOT, ELEVATOR_HINGE + 0.01], [reach - 0.01, ELEVATOR_HINGE + 0.01]]
	for i in range(TAIL_ROWS.size() - 1, -1, -1):
		var row: Array = TAIL_ROWS[i]
		if float(row[0]) >= ELEVATOR_ROOT and float(row[0]) < reach and float(row[2]) > ELEVATOR_HINGE + 0.02:
			outline.append([float(row[0]), float(row[2])])
	outline.append([ELEVATOR_ROOT, tail_row(ELEVATOR_ROOT).y])
	var place := func(p: Vector2) -> Vector3: return point(side * p.x, TAIL_H, p.y) - mid
	_slab(tool, _outline(outline), place, Vector3.UP, 0.035, TOP, LOWER)
	_add(hinge, "Elevator" + named, tool, paint)


func _rudder(paint: Material) -> void:
	var foot: Vector3 = point(0.0, float(RUDDER[-1][1]), RUDDER_HINGE)
	var head: Vector3 = point(0.0, float(RUDDER[0][1]), RUDDER_HINGE)
	var hinge := _hinge("Rudder", self, foot, head - foot, foot + Vector3.BACK, Vector3.RIGHT)
	var tool := _tool()
	var local := func(p: Vector2) -> Vector3: return point(0.0, p.y, p.x) - foot
	_slab(tool, _outline(RUDDER), local, Vector3.RIGHT, 0.035, TOP)
	_add(hinge, "Rudder", tool, paint)


# ---- the gear -------------------------------------------------------------------------------------------------------

func _build_gear(paint: Material) -> void:
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var pivot: Vector3 = point(side * MAIN_PIVOT.x, MAIN_PIVOT.y, MAIN_PIVOT.z)
		var axle: Vector3 = point(side * MAIN_AXLE.x, MAIN_AXLE.y, MAIN_AXLE.z)
		var well: Vector3 = point(side * MAIN_WELL.x, MAIN_WELL.y, MAIN_WELL.z)
		_telescoping_leg("MainGear" + named, pivot, axle, well, TELESCOPE, _main_upper.bind(side), _main_lower.bind(side),
			paint, Vector3(0.0, -side, 0.0))
		# THE INNER DOOR, hinged at the fuselage's side, its outer edge dropping.
		var at := func(o: float, s: float) -> Vector3: return point(side * o, _underside(o) - DOOR_DROP, s)
		_door("InnerDoor" + named, [at.call(INNER_DOOR.z, INNER_DOOR.x), at.call(INNER_DOOR.w, INNER_DOOR.x),
			at.call(INNER_DOOR.w, INNER_DOOR.y), at.call(INNER_DOOR.z, INNER_DOOR.y)], at.call(INNER_DOOR.z, INNER_DOOR.x),
			at.call(INNER_DOOR.z, INNER_DOOR.y), Vector3.DOWN, Vector3.DOWN, INNER_DOOR_OPEN, &"transit", LOWER, paint)
	var tail_pivot: Vector3 = point(0.0, TAIL_PIVOT.y, TAIL_PIVOT.x)
	var tail_axle: Vector3 = point(0.0, TAIL_AXLE.y, TAIL_AXLE.x)
	var tail_stowed: Vector3 = point(0.0, TAIL_STOWED.y, TAIL_STOWED.x)
	tail_stowed = tail_pivot + (tail_stowed - tail_pivot).normalized() * (tail_axle - tail_pivot).length()
	_leg("TailGear", tail_pivot, tail_axle, tail_stowed, _tail_leg, paint)
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var at := func(o: float, s: float) -> Vector3: return point(o, bottom_at(s) - DOOR_DROP, s)
		var edge: float = side * TAIL_DOOR.z
		var inner: float = side * 0.004
		_door("TailDoor" + named, [at.call(inner, TAIL_DOOR.x), at.call(edge, TAIL_DOOR.x), at.call(edge, TAIL_DOOR.y),
			at.call(inner, TAIL_DOOR.y)], at.call(edge, TAIL_DOOR.x), at.call(edge, TAIL_DOOR.y), Vector3.DOWN,
			Vector3.DOWN, deg_to_rad(80.0), &"down", LOWER, paint)


## A MAIN LEG'S UPPER HALF in its pivot's frame: the outer cylinder from the pivot down to where the oleo leaves it, and
## the fairing door on its outboard face.
func _main_upper(tool: SurfaceTool, axle: Vector3, side: float) -> void:
	var down: Vector3 = axle.normalized()
	var reach: float = axle.length()
	_strut(tool, Vector3.ZERO, down * (reach * 0.62), 0.07, GEAR_METAL)
	var top: Vector3 = Vector3(side * 0.08, 0.0, 0.0)
	var bottom: Vector3 = down * (reach - MAIN_TYRE.x * 0.55) + Vector3(side * 0.08, 0.0, 0.0)
	var plate: Array = [top + Vector3(0, 0, -0.24), top + Vector3(0, 0, 0.20), bottom + Vector3(0, 0, 0.20),
		bottom + Vector3(0, 0, -0.24)]
	var thick := Vector3(side * 0.008, 0.0, 0.0)
	var face: Array = []
	var back: Array = []
	for p in plate:
		face.append((p as Vector3) + thick)
		back.append((p as Vector3) - thick)
	_quad(tool, face, Vector3(side, 0.0, 0.0), LOWER)
	_quad(tool, back, Vector3(-side, 0.0, 0.0), WELL)
	var centre: Vector3 = ((plate[0] as Vector3) + plate[2]) * 0.5
	for k in range(4):
		var k2: int = (k + 1) % 4
		_quad(tool, [face[k], face[k2], back[k2], back[k]], ((face[k] as Vector3) + face[k2]) * 0.5 - centre, LOWER)


## A MAIN LEG'S LOWER HALF, the part that slides: the oleo from inside the cylinder to the axle, and the tyre.
func _main_lower(tool: SurfaceTool, axle: Vector3, side: float) -> void:
	var down: Vector3 = axle.normalized()
	_strut(tool, down * (axle.length() * 0.45), axle + Vector3(-side * 0.12, 0.0, 0.0), 0.05, GEAR_METAL)
	_tyre(tool, axle, Vector3.RIGHT, MAIN_TYRE.x, MAIN_TYRE.y, WHEEL_SIDES)


func _tail_leg(tool: SurfaceTool, axle: Vector3) -> void:
	for w in [-0.08, 0.08]:
		_strut(tool, Vector3(w, 0.0, 0.0), axle + Vector3(w, 0.0, 0.0), 0.022, GEAR_METAL)
	_tyre(tool, axle, Vector3.RIGHT, TAIL_TYRE.x, TAIL_TYRE.y, WHEEL_SIDES)
