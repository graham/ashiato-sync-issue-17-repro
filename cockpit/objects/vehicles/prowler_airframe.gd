@tool
extends Node3D
class_name ProwlerAirframe
## A GRUMMAN EA-6B PROWLER, DRAWN: a deep ovoid forward fuselage carrying FOUR crew under one long two-piece canopy, the
## side intakes of its two buried J52s, a swept wing that folds outboard of the intakes, and the fin-tip antenna fairing
## that is the type's signature at any distance.
##
## THE SIMULATION GIVES THE SIZE, THIS GIVES THE SHAPE, as for every airframe here. The fuselage box and the span are
## `kind_geometry`'s `extents` and `span`; the span is drawn only. Every other size names its source:
## - [NAVY] the NAVAIR Standard Aircraft Characteristics "DESCRIPTIVE ARRANGEMENT" three-view of December 1971, which
##   PRINTS eleven dimensions on the drawing.
## - [M] MEASURED off that drawing. The method, the scale, its cross-checks and what is still unreconciled are in
##   `cockpit/craft/prowler/sources.md`, and `cockpit/craft/prowler/measure_sac.py` re-derives every one of them from the
##   drawing alone, reading nothing out of the write-up.
## - [W] Wikipedia's infobox, used only where the SAC is silent. Where the two disagree the SAC wins and `sources.md`
##   says why -- two of Wikipedia's three headline dimensions are wrong.
##
## THE FRAME. STATIONS are inches aft of the radome tip; `station(s)` turns one into a z. HEIGHTS are WATERLINES, inches
## above an arbitrary datum, and `waterline(w)` turns one into a y. The model is built with the FUSELAGE DATUM LEVEL,
## which is how the drawing draws it and how the game flies it.
##
## WHICH MEANS THE GROUND IS NOT LEVEL IN THIS FRAME, and that is the one thing about this aeroplane that breaks the
## house convention. Every other airframe here is built to "heights above the ground with the gear down" with the tyre
## bottoms sharing one datum (`hawkeye_airframe.gd`'s `height()`). A PROWLER PARKS NOSE-UP 5.83 DEGREES: in this level
## frame its nose tyre hangs 0.53 m BELOW its main tyres. So there is no single ground datum here -- there is
## `ground_at(station)`, a raked plane, and `GEAR_RAKE` is a measured constant rather than an oversight to be tidied
## away. `tests/prowler.gd:_the_gear_is_raked_because_a_prowler_parks_nose_up` fails if anybody levels it.
##
## The rake has THREE agreeing readings, none of which shares a line with the others:
## - the lower common tangent to the two tyres, fitted as circles off the drawing, is 5.83 degrees -- and the fit
##   recovers their PRINTED diameters, 19.7 in against 20 and 36.2 in against 36;
## - the two printed lengths give cos-1(709 / 712.5) = 5.68 degrees;
## - the drawing's own extension lines say which length is which: the 709 in pair is vertical on the page, the 712.5 in
##   pair is raked square to the ground. So 709 in is the length in THIS frame and 712.5 in is what a Prowler occupies
##   parked on a deck. The drawn geometry reproduces 712.5 as 710.7.
##
## TESSELLATION, STATED SO NOBODY SUBDIVIDES IT. The user's direction of 2026-09-17: "let's keep a somewhat lower poly
## look to models, not too many very round edges, this will keep a better 'old school feel' to things", with the E-2D
## Hawkeye named as the reference. Every count here is AT OR BELOW the Hawkeye's for the same kind of part:
## - FUSELAGE_SIDES 16, against the Hawkeye's 20 on its fuselage;
## - INTAKE_SIDES 12, against its 16 on a nacelle;
## - PROBE_SIDES 6.
## There is no 32 anywhere: the Hawkeye's only 32 is its rotodome lens, and a Prowler has no lens.
## TESSELLATION IS NOT SHAPE. Every measured dimension, station and clearance above survives a retessellation unchanged,
## and `tests/prowler.gd` is written so that it would.
##
## NOT IN VehicleView's `_body`: `_show_body` paints one flat material over every mesh there, and this airframe's colour
## is in its vertices, so a crew that boarded and left would bring it back plain grey (`lane/fleet`, Hawkeye).

const IN: float = 0.0254

## OVERALL GULL GREY. The EA-6B wore FS 16440 Light Gull Gray over white early and overall tactical greys later; which
## scheme a given airframe carried is not in the SAC. ESTIMATE, an sRGB approximation of the later overall grey.
const GREY := Color(0.56, 0.57, 0.58)
const DARK := Color(0.30, 0.31, 0.32)
const BOOT := Color(0.07, 0.07, 0.07)
## The Prowler's canopy is gold-filmed against the crew's own radiated power [W], which is the one colour on the
## aeroplane a photograph never disagrees about.
const GLASS := Color(0.54, 0.39, 0.10, 0.24)
const COCKPIT := Color(0.055, 0.065, 0.070)

## THE GROUND, RAKED. 5.83 degrees nose-up [M], which over the printed 206.11 in wheelbase [NAVY] puts the nose tyre's
## bottom 20.9 in below the main tyres' in this level frame.
const GEAR_RAKE: float = 0.10170  # tan 5.8093 degrees
## Where the raked ground crosses station zero, as a waterline [M]: the tyres' common tangent, in the drawing's own frame.
const GROUND_AT_NOSE_WL: float = -53.76

## THE FUSELAGE, station by station [M]. Rows are [station, half width, waterline of the top, waterline of the bottom].
## Read off the plan view's outer silhouette for width and the side view's for depth, each on its own printed scale.
## The forward fuselage is the deep narrow ovoid the type is known for: 1.80 m across and 2.62 m deep at the cockpit.
##
## THE TAILCONE SWEEPS UP HARD and the first draft did not: its belly was typed at waterline 10 to 26 all the way aft,
## which drew a fat cigar with a fin on it. Tracing the drawn outline column by column aft of station 420 gives a belly
## at waterlines 36, 54, 68, 83 and 96 -- it rises 60 inches over the last 290 -- while the spine barely falls. Every
## geometry check was green over the fat version; the overlay on the source drawing is what showed it
## (`screenshots/2026-09-17/cockpit-prowler-05-side-on-nose-tip-over-sac1971-x1.000.png`).
const SECTIONS: Array = [
	[0.0, 7.0, 74.0, 60.0],
	[14.0, 19.0, 82.0, 30.0],
	[30.0, 25.0, 88.0, 13.0],
	# Forward of the windscreen this is the NOSE DECK, not the canopy envelope traced in the side view. The first
	# model carried that envelope's 108--111.5 waterlines into the opaque fuselage and put the nose above the pilots'
	# WL 104 eyes. The deck stays below their level sightline and meets the windscreen at its WL 96 sill.
	[50.0, 30.5, 92.0, 8.0],
	[67.0, 32.3, 94.0, 6.6],
	[89.0, 34.4, 113.8, 6.0],
	[120.0, 35.5, 115.5, 6.0],
	[140.0, 35.5, 116.5, 6.5],
	[148.0, 40.0, 116.9, 7.0],
	[168.0, 44.0, 117.0, 8.0],
	[214.0, 45.0, 115.5, 12.5],
	[300.0, 45.0, 110.1, 16.3],
	[340.0, 44.0, 108.8, 15.0],
	[420.0, 40.0, 108.8, 36.0],
	[500.0, 33.0, 108.8, 54.4],
	[580.0, 24.0, 107.0, 68.0],
	[660.0, 14.0, 104.0, 82.9],
	[709.0, 5.0, 100.0, 95.9],
]
const FUSELAGE_SIDES: int = 16

## THE CANOPY [M], from four frames read as ink columns in the side view's glazing band. Frames 2 and 3 are only 28 in
## apart, which is a fixed bow and not a panel division: the canopy is in TWO pieces, and the crew sit in two rows of
## two under them. Glazing runs from the top of the windscreen aft, above this waterline.
const WINDSCREEN_BASE: float = 67.0
const WINDSCREEN_DECK_WL: float = 94.0
const CANOPY_FORWARD: Vector2 = Vector2(89.0, 140.0)
const CANOPY_AFT: Vector2 = Vector2(168.0, 214.0)
const CANOPY_SILL_WL: float = 96.0

## THE WING [M], fitted over 100 stations of the outer panel at 1.85 in of residual, and stated as the drawing states a
## wing: leading and trailing edge stations as straight lines in the distance out from the centreline.
##   LE station = 210.0 + 0.5518 * out    TE station = 389.7 + 0.1692 * out
## which is a root chord of 179.7 in, a tip chord of 58.0 in and a taper ratio of 0.323.
##
## THE QUARTER-CHORD SWEEP THAT FALLS OUT OF IT IS 24.5 DEGREES, against the type's published 25. That was not fitted
## to, and it is the strongest single check that the planform is right.
##
## AND THIS IS WHERE THE DRAWING'S ONE UNRECONCILED DISAGREEMENT IS PARKED, deliberately. The plan view and the side
## view disagree by 3.6 per cent about how long this aeroplane is, each of them self-consistent (`sources.md`, "what is
## not settled"). The CHORDS here are at the plan view's own scale, because that is the scale at which the drawn wing
## reproduces the drawing's PRINTED area and aspect ratio -- 48.8 m2 against 49.14 and 5.35 against 5.31. The ROOT
## LEADING EDGE STATION is the side view's, because the side view is where stations come from and its scale has three
## mutually independent printed sources behind it.
##
## The 3.6 per cent has to come out somewhere, and it comes out in the TRAILING EDGE STATION, which is the only
## quantity involved that the drawing does not print. Putting it there was a choice: the alternative, carrying the
## chords into the side view's frame, made the wing 4.1 per cent too big and missed the printed area by 3 per cent --
## which is how this was found, because `tests/prowler.gd` asks the drawn wing for the printed area and the first build
## failed that check and nothing else.
const WING_LE_ROOT: float = 210.0
const WING_LE_SWEEP: float = 0.5518
const WING_TE_ROOT: float = 389.7
const WING_TE_SWEEP: float = 0.1692
## Thickness as the SAC prints the sections: NACA 64A009 MOD at wing station 33, 64A008.4 at the fold, 64A005.9 at the
## tip -- so 9, 8.4 and 5.9 per cent of the local chord.
const WING_THICK_ROOT: float = 0.090
const WING_THICK_FOLD: float = 0.084
const WING_THICK_TIP: float = 0.059
## The wing's lower surface is FLAT across the whole span: in the front view it moves 2 px over 600, so under 0.2 of a
## degree [M]. The Prowler has no dihedral to speak of and this is drawn with none.
const WING_WL: float = 44.0
## WHERE IT FOLDS [M]: chordwise lines cross the wing at 142.5 in out to port and 151.9 to starboard, averaging
## **147.2 in**, and that measured figure is what is used. A second pair at 129.1 and 138.5 is the outboard end of the
## inboard flap, not the fold.
##
## THE PRINTED FOLDED WIDTH IS 299 IN [NAVY], and the hinge is NOT half of it. Folded, the panel stands up about the
## hinge line, so the widest part of the aeroplane is the hinge PLUS the panel's own thickness there -- 10.4 in at the
## printed NACA 64A008.4 section. Halving 299 would put the hinge at 149.5 and was the first draft's assumption; it
## drew the aeroplane 7.87 m across folded against the printed 7.595, which
## `tests/prowler.gd:_the_folded_wings_are_the_printed_width_across` failed and nothing else did.
##
## THE MEASURED HINGE IS LEFT AS MEASURED rather than solved backwards out of the printed width, which would have made
## that check a tautology -- it would then be asserting arithmetic the builder had just done. At 147.2 in the drawn
## fold comes out 7.75 m against the printed 7.595, **2.1 per cent over, from a hinge read off the plan view and a
## thickness read off the printed section number, with nothing fitted to the answer**. That is worth more than an exact
## figure that proves nothing.
const FOLD_OUT: float = 147.2
const FOLDED_WIDTH: float = 299.0
## How long an EA-6B takes to fold or spread is NOT FOUND: ESTIMATE, twelve seconds, as the Hawkeye's. Drawn only.
const FOLD_SECONDS: float = 12.0

## THE INTAKES [M]. The two J52s are BURIED in the fuselage sides -- there is no nacelle on this aeroplane, which is why
## the fuselage steps from 71 in across to 88 at station 148 and stays there to 204. The SECTIONS table already carries
## that step, so what is drawn here is only what the step does not say.
##
## AND WHAT IT DOES NOT SAY IS THE SHAPE. The first draft drew a 3.9 m slab from station 148 to 300 spanning 1.57 m of
## height and called it an intake; it read as nothing at all, because it was the FAIRING and not the intake. The Fallon
## photograph shows a compact D-shaped mouth about 0.87 m tall standing at the back of the cockpit, with a SPLITTER
## PLATE proud of the fuselage side ahead of it and the duct opening set outboard behind that. The splitter is the thing
## that makes it read: without it a dark patch on a grey side is a panel, and with it there is an air intake.
const INTAKE_LIP: float = 148.0
const INTAKE_BACK: float = 300.0
## The mouth, off the photograph at its 86 px a metre: 0.87 m tall, so 34 in, from waterline 40 up.
const INTAKE_MOUTH_WL: Vector2 = Vector2(40.0, 74.0)
const SPLITTER_PROUD: float = 7.0
const INTAKE_WL: Vector2 = Vector2(30.0, 92.0)  # bottom, top -- the cheek the jet pipe hangs under
const INTAKE_SIDES: int = 12
## The jet pipes leave under the wing root, well forward of the tail, as they do on an A-6.
const EXHAUST_STATION: float = 430.0

## THE FIN [M], and the ANTENNA FAIRING on top of it, which is what tells an EA-6B from an A-6 at any range. Its top is
## the aeroplane's printed overall height.
##   The drawn fin top reads 191.4 in over the ground against the printed 195: the drawing is 1.8 per cent under its own
##   printed height, which is about what a 1971 sheet scanned and restored is worth. THE PRINTED NUMBER WINS, so the
##   model puts the fin top where 195 in comes out right and the suite asserts 195.
## THE LEADING EDGE IS NEARLY UPRIGHT, and the first draft raked it from station 520, which drew a shark fin reaching
## a third of the way up the fuselage. Measured off the side view, the topmost ink stands 17 in over the spine at
## station 572 and 71 in over it by 597, so the leading edge runs from about station 560 at the spine to 606 at the
## tip: about 25 degrees, not the 40 that was typed.
const FIN_ROOT: Vector2 = Vector2(560.0, 709.0)
const FIN_TIP: Vector2 = Vector2(606.0, 709.0)
const FIN_TOP_OVER_GROUND: float = 195.0
const FIN_THICK: float = 14.0
## The fairing sits along the fin tip, a slender pod a little longer than the tip chord and proud of it each side.
const FAIRING_WIDE: float = 26.0
const FAIRING_DEEP: float = 22.0

## THE TAILPLANE [M], all-moving, from the plan view's trailing edge fitted at 2.65 in of residual and its leading edge
## taken outboard of the fin's projection. Span 244 in [NAVY].
##   Root: leading edge at station 572, trailing edge at 670, a chord of 98 in.
##   Tip at 122 in out: leading edge 646, trailing edge 695, a chord of 49 in.
## ITS DIHEDRAL IS NOT MEASURABLE ON THIS DRAWING -- the front view hides the tailplane behind the wing -- so it is drawn
## flat and listed as outstanding in `sources.md`. That is a NOT FOUND, not a zero.
const TAILPLANE_SPAN: float = 244.0
const TAILPLANE_ROOT: Vector2 = Vector2(572.0, 670.0)
const TAILPLANE_TIP: Vector2 = Vector2(646.0, 695.0)
const TAILPLANE_WL: float = 88.0
const TAILPLANE_THICK: float = 9.0

## THE MOVING SURFACES. The 1971 sheet fixes their hinge lines but not their travel, so the angles are ESTIMATES in the
## conservative range of carrier aircraft of the period. They are presentation only: the simulation still owns the
## aeroplane's response. The odd row count gives every VAT table an exact neutral row.
const AILERON_IN: float = 174.0
const AILERON_HINGE: float = 0.70
const RUDDER_HINGE: float = 0.67
const AILERON_TRAVEL: float = 20.0
const STABILATOR_TRAVEL: float = 24.0
const RUDDER_TRAVEL: float = 28.0
## The panel passes vertical and leans fourteen degrees inboard at the stop. A square 90-degree fold left the thick outer
## aileron proud of the SAC's printed folded envelope; this over-centre angle reproduces the envelope and the
## slightly tucked stance in the front-view drawing.
const FOLD_TRAVEL: float = 104.0
const SURFACE_ROWS: int = 65

## THREE AN/ALQ-99 PODS, the load that gives the aeroplane its working silhouette: one centreline and one under each
## wing. The public Navy fact file establishes the ram-air turbine and up-to-five carriage; 4.83 m by 0.71 m is a
## secondary measured envelope and remains tagged as such in `craft/prowler/sources.md`.
const POD_LENGTH: float = 4.83
const POD_DIAMETER: float = 0.71
const POD_SIDES: int = 12

## THE GEAR [NAVY for the tyres and the wheelbase, M for the stations]. Tyre bottoms do NOT share a datum: see GEAR_RAKE.
const NOSE_GEAR_STATION: float = 144.6
const MAIN_GEAR_STATION: float = 348.9
const NOSE_TYRE: float = 20.0
const MAIN_TYRE: float = 36.0
const TRACK: float = 130.5

## THE REFUELLING PROBE over the nose, which on a Prowler is bent to starboard so the pilot can see past it [W]. Its
## length is not published; it is drawn to end inside station zero so the drawn aeroplane keeps the public envelope,
## which is the trap the Hawkeye's probe fell into first.
const PROBE_SIDES: int = 6
const PROBE_ROOT: float = 96.0
const PROBE_TIP: float = 6.0

## Small fittings stop drawing once the whole 18 m aeroplane is a few pixels high. The disabled fade mode uses
## hysteresis and is the fast manual-LOD path; SELF and DEPENDENCIES fades are not supported by Mobile.
const DETAIL_RANGE: float = 800.0
const DETAIL_HYSTERESIS: float = 80.0

var _panels: Array[Node3D] = []
var _fold: float = 0.0
var _half := Vector3(45.0 * IN, 51.65 * IN, 354.5 * IN)
var _span: float = 318.0 * IN
var _hinges: Dictionary = {}
var _ailerons: float = 0.0
var _stabilator: float = 0.0
var _rudder: float = 0.0


## BUILT IN PLACE, after `new()`, from the simulation's geometry.
func dress(geometry: Dictionary = {}) -> void:
	name = "Prowler"
	var native: Dictionary = geometry if not geometry.is_empty() else Sim.geometry_of(Sim.Kind.PROWLER)
	_half = native.get("extents", _half) as Vector3
	_span = float(native.get("span", _span))
	var material: StandardMaterial3D = ShipHull.painted()
	var glass_material := StandardMaterial3D.new()
	# Vertex colours already carry the gold tint and alpha. Multiplying by GLASS here made opacity 0.48² and left the
	# roof reading as an open cockpit in the review render; white preserves the authored 48% glass while staying clear.
	glass_material.albedo_color = Color.WHITE
	glass_material.metallic = 0.18
	glass_material.roughness = 0.13
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_material.vertex_color_use_as_albedo = true
	glass_material.vertex_color_is_srgb = true

	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var details := SurfaceTool.new()
	details.begin(Mesh.PRIMITIVE_TRIANGLES)

	_fuselage(body, glass)
	_windscreen(glass)
	_cockpit(body, details)
	_intakes(body, details)
	for side in [1.0, -1.0]:
		_wing_piece(body, 0.0, FOLD_OUT, side, Vector3.ZERO)
	_fin(body)
	_rudder_surface(material)
	_tailplanes(material)
	_add_mesh("Body", body, material, Vector3.ZERO)
	_add_mesh("CanopyGlass", glass, glass_material, Vector3.ZERO)

	_gear(details)
	_probe(details)
	var fittings := _add_mesh("Details", details, material, Vector3.ZERO)
	fittings.visibility_range_end = DETAIL_RANGE
	fittings.visibility_range_end_margin = DETAIL_HYSTERESIS
	fittings.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	# At this range a leg, a tyre and a probe cannot cast a useful shadow; the class reference names small geometry as
	# exactly the case for turning shadows off.
	fittings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# THE FOLDING OUTER PANELS, each in its own pivot on the hinge line, as the Hawkeye's are. `VehicleView` drives
	# `fold()` from the Prowler's native Fold channel and bakes the same setter as the VAT's outer feature.
	for side in [1.0, -1.0]:
		var pivot := Node3D.new()
		pivot.name = "WingStarboard" if side > 0.0 else "WingPort"
		pivot.position = Vector3(side * FOLD_OUT * IN, waterline(WING_WL + wing_thick(FOLD_OUT) * 0.5),
			station(wing_le(FOLD_OUT) + wing_chord(FOLD_OUT) * 0.70))
		add_child(pivot)
		var panel := SurfaceTool.new()
		panel.begin(Mesh.PRIMITIVE_TRIANGLES)
		_wing_piece(panel, FOLD_OUT, AILERON_IN, side, pivot.position)
		_wing_piece(panel, AILERON_IN, half_span_inches(), side, pivot.position, AILERON_HINGE)
		var mesh := MeshInstance3D.new()
		mesh.name = "Panel"
		mesh.mesh = Plating.weld(panel)
		mesh.material_override = material
		pivot.add_child(mesh)
		_panels.append(pivot)
		_aileron(side, pivot, material)

	_mission_pods(material)
	fold(0.0)
	follow_the_stick(Vector2.ZERO, 0.0)


## THE WINGS, 0 spread and 1 folded: the outer panel swings up and over until its span lies along the fuselage, leading
## edge down, which is where the printed 299 in folded width comes from -- folded, the hinge itself is the widest part.
func fold(amount: float) -> void:
	_fold = clampf(amount, 0.0, 1.0)
	for pivot in _panels:
		var side: float = 1.0 if pivot.position.x > 0.0 else -1.0
		pivot.basis = Basis(Vector3.BACK, -side * _fold * deg_to_rad(FOLD_TRAVEL))


func fold_amount() -> float:
	return _fold


## THE LINKAGE AS THE VIEW HOLDS IT. Positive roll lowers the starboard aileron's trailing edge and raises the port;
## positive pitch raises both all-moving tailplanes' trailing edges; positive rudder moves its trailing edge to
## starboard. Each axis is a pure pose so the same setters bake and play the VAT.
func follow_the_stick(stick: Vector2, rudder: float) -> void:
	set_ailerons(stick.x)
	set_stabilator(stick.y)
	set_rudder(rudder)


func set_ailerons(amount: float) -> void:
	_ailerons = clampf(amount, -1.0, 1.0)
	for named in ["Starboard", "Port"]:
		var side: float = 1.0 if named == "Starboard" else -1.0
		_turn("Aileron" + named, -side * _ailerons * AILERON_TRAVEL)


func ailerons() -> float:
	return _ailerons


func set_stabilator(amount: float) -> void:
	_stabilator = clampf(amount, -1.0, 1.0)
	for named in ["Starboard", "Port"]:
		_turn("Stabilator" + named, _stabilator * STABILATOR_TRAVEL)


func stabilator() -> float:
	return _stabilator


func set_rudder(amount: float) -> void:
	_rudder = clampf(amount, -1.0, 1.0)
	_turn("Rudder", _rudder * RUDDER_TRAVEL)


func rudder() -> float:
	return _rudder


## One table per independent amount. Fold stays first because each aileron rides a folding panel: the VAT applies the
## aileron's own hinge first and the fold outside it, exactly as the node tree does.
func features() -> Array:
	return [
		{"name": "fold", "set": fold, "get": fold_amount, "low": 0.0, "high": 1.0, "samples": SURFACE_ROWS},
		{"name": "aileron", "set": set_ailerons, "get": ailerons, "low": -1.0, "high": 1.0,
			"samples": SURFACE_ROWS},
		{"name": "pitch", "set": set_stabilator, "get": stabilator, "low": -1.0, "high": 1.0,
			"samples": SURFACE_ROWS},
		{"name": "rudder", "set": set_rudder, "get": rudder, "low": -1.0, "high": 1.0,
			"samples": SURFACE_ROWS},
	]


func _turn(named: String, degrees: float) -> void:
	var hinge: Node3D = _hinges.get(named) as Node3D
	if hinge != null:
		hinge.basis = Basis(hinge.get_meta("axis") as Vector3, deg_to_rad(degrees))


## THE FOUR EYES, in the drawing's station/waterline frame: pilot port-front, the game's dual-control ECMO-1/copilot
## starboard-front, ECMO-2 starboard-rear and ECMO-3 port-rear. The real aircraft gave flight controls only to the
## pilot; the second flying seat is the requested multi-crew game concession and is documented in `sources.md`.
func crew_eyes() -> Array[Vector3]:
	var eye_y := waterline(104.0)
	return [
		Vector3(-0.40, eye_y, station(115.0)), Vector3(0.40, eye_y, station(115.0)),
		Vector3(0.40, eye_y, station(191.0)), Vector3(-0.40, eye_y, station(191.0)),
	]


## A conservative box wholly inside the drawn forward fuselage. Consumers may furnish inside it without carrying the
## skin's geometry; the floor is stated separately because the belly pinches below it.
func cabin_room() -> Dictionary:
	return {
		"drawn": true,
		"floor": waterline(52.0),
		"room": AABB(Vector3(-0.74, waterline(52.0), station(82.0)),
			Vector3(1.48, waterline(108.0) - waterline(52.0), station(224.0) - station(82.0))),
		"because": &"",
		"why_not": "",
		"source": "craft/prowler/sources.md",
	}


## STATIONS are inches aft of the radome tip.
func station(s: float) -> float:
	return -_half.z + s * IN


## WATERLINES are inches above the drawing's datum; the box centre is halfway up the fuselage.
func waterline(w: float) -> float:
	return (w - _centre_wl()) * IN


## WHERE THE GROUND IS, at a station, in this level frame. NOT a constant, because a Prowler parks nose-up: see
## GEAR_RAKE. Everything that stands on the ground asks this rather than a datum.
func ground_at(s: float) -> float:
	return waterline(GROUND_AT_NOSE_WL + GEAR_RAKE * s)


## HALF THE SPAN in inches, from the geometry rather than from the constant, so a kind that states a different span
## moves the wing rather than disagreeing with it.
func half_span_inches() -> float:
	return _span / IN


func wing_le(out: float) -> float:
	return WING_LE_ROOT + WING_LE_SWEEP * out


func wing_te(out: float) -> float:
	return WING_TE_ROOT + WING_TE_SWEEP * out


func wing_chord(out: float) -> float:
	return wing_te(out) - wing_le(out)


## THICKNESS as a share of the local chord, through the three printed NACA sections: root, fold and tip.
func wing_thick(out: float) -> float:
	var reach: float = half_span_inches()
	var share: float = clampf(out / maxf(reach, 1.0), 0.0, 1.0)
	var fold_share: float = FOLD_OUT / maxf(reach, 1.0)
	var t: float = (lerpf(WING_THICK_ROOT, WING_THICK_FOLD, share / maxf(fold_share, 0.001)) if share <= fold_share
		else lerpf(WING_THICK_FOLD, WING_THICK_TIP, (share - fold_share) / maxf(1.0 - fold_share, 0.001)))
	return wing_chord(out) * t


func _centre_wl() -> float:
	# The box's own middle, from the extents the simulation states rather than from the section table, so a kind that
	# states a different depth moves the whole model with it.
	return float(SECTIONS[7][2]) - _half.y / IN


func _add_mesh(title: String, tool: SurfaceTool, material: Material, at: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.mesh = Plating.weld(tool)
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
	return mesh


## A named pivot carrying a unit axis in its own frame. `towards` chooses the axis sign by requiring a positive turn to
## move the named trailing point towards the requested direction; that makes every surface's sign explicit at build.
func _hinge(title: String, parent: Node3D, at: Vector3, axis: Vector3, trailing: Vector3,
		towards: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = title
	pivot.position = at
	var unit := axis.normalized()
	if unit.cross(trailing - at).dot(towards) < 0.0:
		unit = -unit
	pivot.set_meta("axis", unit)
	parent.add_child(pivot)
	_hinges[title] = pivot
	return pivot


## A CONVEX BLOCK from two matching loops of four corners, each face wound to look away from the block's own middle.
static func _block(tool: SurfaceTool, corners: Array, tint: Color) -> void:
	var centre := Vector3.ZERO
	for c in corners:
		centre += c
	centre /= float(corners.size())
	for f in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]:
		var quad: Array = [corners[f[0]], corners[f[1]], corners[f[2]], corners[f[3]]]
		var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
		Plating.facing(tool, quad, mid - centre, tint)


## ONE TRIANGLE of a fan, wound so its face looks along `out`.
static func _fan(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, tint: Color) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 1e-10:
		return
	if normal.dot(out) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	tool.set_color(tint)
	for corner in [a, b, c]:
		tool.set_normal(normal.normalized())
		tool.add_vertex(corner)


## THE FUSELAGE: a deep rounded ovoid through the measured sections. A superellipse of power 4 -- nearly flat sides and
## round corners -- as the Hawkeye's is, because a Prowler's forward fuselage is the same kind of section and a circle
## would lose the flat cheek the intakes sit on. SIDES is 16 against the Hawkeye's 20: this is the lower-poly direction.
func _fuselage(tool: SurfaceTool, glass: SurfaceTool) -> void:
	var ring := func(row: Array, k: int) -> Vector3:
		var t: float = TAU * float(k) / FUSELAGE_SIDES
		var s: float = sin(t)
		var c: float = cos(t)
		var half_w: float = float(row[1]) * IN
		var top: float = float(row[2])
		var bottom: float = float(row[3])
		var mid: float = (top + bottom) * 0.5
		var half_h: float = (top - bottom) * 0.5
		return Vector3(half_w * signf(s) * sqrt(absf(s)),
			waterline(mid + half_h * signf(c) * sqrt(absf(c))), station(float(row[0])))
	for r in range(SECTIONS.size() - 1):
		for k in range(FUSELAGE_SIDES):
			var mid: float = TAU * (float(k) + 0.5) / FUSELAGE_SIDES
			var here: float = (float(SECTIONS[r][0]) + float(SECTIONS[r + 1][0])) * 0.5
			# THE WINDSCREEN IS AN OPENING, not transparent geometry laid over opaque skin. The first assembled-seat
			# render exposed this: `_windscreen` was present, but the untouched 67--89 fuselage band was still a wall
			# immediately behind it. Its sloping glass below closes this opening with the correct rake.
			if cos(mid) > 0.30 and here > WINDSCREEN_BASE and here < CANOPY_FORWARD.x:
				continue
			# THE CANOPY IS GLAZING ON THE FUSELAGE'S OWN UPPER FACETS, not a box sitting on the spine. Drawn as two
			# separate blocks it read as a pair of hatches lying on the back, because a Prowler's canopy is nearly
			# flush -- the drawing puts its top only 2 to 6 in above the spine behind it -- so a box proud of the
			# fuselage is the wrong shape AND a band of the fuselage is fewer faces. `SECTIONS` carries rows at the
			# four measured canopy frames so the glass starts and stops where the drawing says.
			var glazed: bool = cos(mid) > 0.30 and ((here > CANOPY_FORWARD.x and here < CANOPY_FORWARD.y)
				or (here > CANOPY_AFT.x and here < CANOPY_AFT.y))
			Plating.facing(glass if glazed else tool, [ring.call(SECTIONS[r], k), ring.call(SECTIONS[r], k + 1),
				ring.call(SECTIONS[r + 1], k + 1), ring.call(SECTIONS[r + 1], k)],
				Vector3(sin(mid), cos(mid), 0.0), GLASS if glazed else GREY)
	# Both ends closed, each a fan wound to look out along the fuselage, so nothing is open to the camera.
	for end in [[0, -1.0], [SECTIONS.size() - 1, 1.0]]:
		var row: Array = SECTIONS[int(end[0])]
		var centre := Vector3(0.0, waterline((float(row[2]) + float(row[3])) * 0.5), station(float(row[0])))
		for k in range(FUSELAGE_SIDES):
			_fan(tool, centre, ring.call(row, k), ring.call(row, k + 1), Vector3(0.0, 0.0, float(end[1])), GREY)


## THE WINDSCREEN, raked from the nose decking up to the front of the forward canopy over its measured 22 in. The rest
## of the glass is in `_fuselage`, on the fuselage's own facets; this is the one piece that is not a band of the
## fuselage, because a windscreen leans and the sections do not.
func _windscreen(tool: SurfaceTool) -> void:
	# The forward edge stands ON the nose deck. The first pass put it twelve inches below that deck, so most of the
	# glass was buried in opaque nose geometry even after the fuselage band behind it had been opened.
	var base_wl: float = waterline(WINDSCREEN_DECK_WL)
	var top: float = waterline(float(SECTIONS[5][2]) - 1.0)
	# A PANE, NOT A CLOSED BLOCK. `_block` also drew a horizontal bottom face from the nose deck to the canopy bow;
	# after the nose was lowered that glass floor appeared as a broad opaque-looking tan wedge across both pilots' view.
	# Twenty-one inches at the top leaves each 0.40 m seat centre enough room for a 64 mm stereo pair and head motion.
	Plating.facing(tool, [
		Vector3(-24.0 * IN, base_wl, station(WINDSCREEN_BASE)),
		Vector3(24.0 * IN, base_wl, station(WINDSCREEN_BASE)),
		Vector3(21.0 * IN, top, station(CANOPY_FORWARD.x)),
		Vector3(-21.0 * IN, top, station(CANOPY_FORWARD.x)),
	], Vector3(0.0, 0.6, -1.0), GLASS)


## WHAT THE TRANSPARENT CANOPY REVEALS: a dark tub and the canopy's four structural bows. Seats and displays belong
## only to the authored station package. Presentation copies here survived when the real stations were built, leaving
## cyan blocks behind the MFDs and duplicate seat boxes visible to the crew.
func _cockpit(body: SurfaceTool, details: SurfaceTool) -> void:
	var floor: float = waterline(54.0)
	var sill: float = waterline(CANOPY_SILL_WL)
	Plating.box(details, Vector3(0.0, floor, (station(86.0) + station(222.0)) * 0.5),
		Vector3(1.45, 0.08, station(222.0) - station(86.0)), COCKPIT)
	# Four bows and their side rails, deliberately angular in the Hawkeye's low-poly language.
	for s in [CANOPY_FORWARD.x, CANOPY_FORWARD.y, CANOPY_AFT.x, CANOPY_AFT.y]:
		var y: float = waterline(CANOPY_SILL_WL + (14.0 if s == CANOPY_FORWARD.x else 17.0))
		Plating.box(body, Vector3(0.0, y, station(s)), Vector3(1.18, 0.055, 0.055), DARK)
		for side in [-1.0, 1.0]:
			Plating.box(body, Vector3(side * 0.58, (sill + y) * 0.5, station(s)),
				Vector3(0.045, y - sill, 0.055), DARK)
	for side in [-1.0, 1.0]:
		Plating.box(body, Vector3(side * 0.60, sill, (station(89.0) + station(214.0)) * 0.5),
			Vector3(0.055, 0.07, station(214.0) - station(89.0)), DARK)


## A PIECE OF WING from `a` to `b` inches out on one `side`, off the measured leading edge, trailing edge and thickness,
## less `origin` so a folding panel is built in its hinge's frame. A black de-icing boot along the leading edge.
func _wing_piece(tool: SurfaceTool, a: float, b: float, side: float, origin: Vector3, trail_share: float = 1.0) -> void:
	var loops: Array = []
	var boot: Array = []
	for out in [a, b]:
		var x: float = side * out * IN
		var thick: float = wing_thick(out) * IN
		var top: float = waterline(WING_WL) + thick
		var bottom: float = waterline(WING_WL)
		var lead: float = station(wing_le(out))
		var trail: float = station(lerpf(wing_le(out), wing_te(out), trail_share))
		loops.append_array([Vector3(x, bottom, lead) - origin, Vector3(x, bottom, trail) - origin,
			Vector3(x, top, trail) - origin, Vector3(x, top, lead) - origin])
		boot.append_array([Vector3(x, bottom - 0.005, lead - 0.01) - origin, Vector3(x, bottom - 0.005, lead + 0.16) - origin,
			Vector3(x, top + 0.005, lead + 0.16) - origin, Vector3(x, top + 0.005, lead - 0.01) - origin])
	_block(tool, loops, GREY)
	_block(tool, boot, BOOT)


## THE INTAKES: a splitter plate proud of the fuselage side and a dark mouth outboard of it, at the station where the
## measured width steps from 71 in to 88. The cheek itself is in SECTIONS; the jet pipe leaves under the wing root.
func _intakes(tool: SurfaceTool, details: SurfaceTool) -> void:
	for side in [1.0, -1.0]:
		var low: float = waterline(INTAKE_MOUTH_WL.x)
		var high: float = waterline(INTAKE_MOUTH_WL.y)
		var skin: float = side * 36.0 * IN
		var lip: float = side * (36.0 + SPLITTER_PROUD) * IN
		# THE SPLITTER PLATE, standing proud of the fuselage side ahead of the mouth: a thin wedge, sharp at the front.
		_block(tool, [
			Vector3(skin, low, station(INTAKE_LIP - 16.0)), Vector3(skin * 1.02, low, station(INTAKE_LIP - 16.0)),
			Vector3(skin * 1.02, high, station(INTAKE_LIP - 16.0)), Vector3(skin, high, station(INTAKE_LIP - 16.0)),
			Vector3(skin, low, station(INTAKE_LIP + 2.0)), Vector3(lip, low, station(INTAKE_LIP + 2.0)),
			Vector3(lip, high, station(INTAKE_LIP + 2.0)), Vector3(skin, high, station(INTAKE_LIP + 2.0))], GREY)
		# THE MOUTH, a dark recess outboard of the splitter and set back into the cheek, so it reads as a hole rather
		# than as a panel.
		_block(details, [
			Vector3(skin, low, station(INTAKE_LIP + 2.0)), Vector3(lip, low, station(INTAKE_LIP + 2.0)),
			Vector3(lip, high, station(INTAKE_LIP + 2.0)), Vector3(skin, high, station(INTAKE_LIP + 2.0)),
			Vector3(skin, low + 0.04, station(INTAKE_LIP + 26.0)), Vector3(lip * 0.97, low + 0.04, station(INTAKE_LIP + 26.0)),
			Vector3(lip * 0.97, high - 0.04, station(INTAKE_LIP + 26.0)), Vector3(skin, high - 0.04, station(INTAKE_LIP + 26.0))], BOOT)
		# The jet pipe, under the wing root and well forward of the tail, as an A-6's is.
		var ring := func(k: int, s: float, r: float) -> Vector3:
			var t: float = TAU * float(k) / INTAKE_SIDES
			return Vector3(side * 30.0 * IN + r * cos(t), waterline(26.0) + r * sin(t), station(s))
		for k in range(INTAKE_SIDES):
			var mid: float = TAU * (float(k) + 0.5) / INTAKE_SIDES
			Plating.facing(details, [ring.call(k, EXHAUST_STATION - 30.0, 13.0 * IN), ring.call(k + 1, EXHAUST_STATION - 30.0, 13.0 * IN),
				ring.call(k + 1, EXHAUST_STATION, 12.0 * IN), ring.call(k, EXHAUST_STATION, 12.0 * IN)],
				Vector3(cos(mid), sin(mid), 0.0), DARK)
			_fan(details, Vector3(side * 30.0 * IN, waterline(26.0), station(EXHAUST_STATION)),
				ring.call(k, EXHAUST_STATION, 12.0 * IN), ring.call(k + 1, EXHAUST_STATION, 12.0 * IN),
				Vector3(0.0, 0.0, 1.0), BOOT)


## THE FIN, and the ANTENNA FAIRING on its tip, which is the one thing that tells an EA-6B from an A-6 in silhouette.
## The fin top is placed so that the PRINTED 195 in overall height comes out right over the raked ground under it, not
## so that it matches the drawn fin, which is 1.8 per cent short of the drawing's own printed figure.
func _fin(tool: SurfaceTool) -> void:
	var tip_mid: float = (FIN_TIP.x + FIN_TIP.y) * 0.5
	var top: float = ground_at(tip_mid) + FIN_TOP_OVER_GROUND * IN
	var root: float = waterline(float(SECTIONS[12][2]) - 2.0)
	var half_t: float = FIN_THICK * 0.5 * IN
	var root_hinge: float = lerpf(FIN_ROOT.x, FIN_ROOT.y, RUDDER_HINGE)
	var tip_hinge: float = lerpf(FIN_TIP.x, FIN_TIP.y, RUDDER_HINGE)
	_block(tool, [
		Vector3(-half_t, root, station(FIN_ROOT.x)), Vector3(half_t, root, station(FIN_ROOT.x)),
		Vector3(half_t, root, station(root_hinge)), Vector3(-half_t, root, station(root_hinge)),
		Vector3(-half_t * 0.6, top, station(FIN_TIP.x)), Vector3(half_t * 0.6, top, station(FIN_TIP.x)),
		Vector3(half_t * 0.6, top, station(tip_hinge)), Vector3(-half_t * 0.6, top, station(tip_hinge))], GREY)
	# THE FAIRING, a slender pod along the tip, proud of the fin each side and standing a little above it. Its top is
	# the aeroplane's overall height, so the fin below stops just short of it.
	# FLAT-TOPPED AND SQUARED OFF, not a spindle. The first draft tapered it at both ends into two thin blocks and it
	# did not read at all in a three-quarter view; the Fallon photograph shows a broad slab-sided pod with a flat top,
	# a short nose taper and a blunt back, standing clear of the fin each side. It is the one feature that tells an
	# EA-6B from an A-6 in silhouette, so it is drawn to be seen.
	var nose_s: float = FIN_TIP.x - 10.0
	var tail_s: float = FIN_TIP.y + 4.0
	var w: float = FAIRING_WIDE * 0.5 * IN
	var d: float = FAIRING_DEEP * IN
	_block(tool, [
		Vector3(-w * 0.25, top - d * 0.55, station(nose_s)), Vector3(w * 0.25, top - d * 0.55, station(nose_s)),
		Vector3(w * 0.25, top - d * 0.30, station(nose_s)), Vector3(-w * 0.25, top - d * 0.30, station(nose_s)),
		Vector3(-w, top - d, station(nose_s + 30.0)), Vector3(w, top - d, station(nose_s + 30.0)),
		Vector3(w, top, station(nose_s + 30.0)), Vector3(-w, top, station(nose_s + 30.0))], DARK)
	_block(tool, [
		Vector3(-w, top - d, station(nose_s + 30.0)), Vector3(w, top - d, station(nose_s + 30.0)),
		Vector3(w, top, station(nose_s + 30.0)), Vector3(-w, top, station(nose_s + 30.0)),
		Vector3(-w, top - d, station(tail_s)), Vector3(w, top - d, station(tail_s)),
		Vector3(w, top, station(tail_s)), Vector3(-w, top, station(tail_s))], DARK)


## THE SINGLE RUDDER, separated from the fin rather than painted on it, on the measured fin outline. Its diamond-thin
## section keeps the hinge gap legible in the low-poly silhouette.
func _rudder_surface(material: Material) -> void:
	var tip_mid: float = (FIN_TIP.x + FIN_TIP.y) * 0.5
	var top: float = ground_at(tip_mid) + FIN_TOP_OVER_GROUND * IN
	var bottom: float = waterline(float(SECTIONS[12][2]) - 2.0)
	var root_hinge: float = lerpf(FIN_ROOT.x, FIN_ROOT.y, RUDDER_HINGE)
	var tip_hinge: float = lerpf(FIN_TIP.x, FIN_TIP.y, RUDDER_HINGE)
	var low := Vector3(0.0, bottom, station(root_hinge))
	var high := Vector3(0.0, top, station(tip_hinge))
	var hinge := _hinge("Rudder", self, low, high - low,
		Vector3(0.0, bottom, station(FIN_ROOT.y)), Vector3.RIGHT)
	var half_root: float = FIN_THICK * 0.46 * IN
	var half_tip: float = FIN_THICK * 0.25 * IN
	var corners: Array = []
	for p in [
		Vector3(-half_root, bottom, station(root_hinge)), Vector3(half_root, bottom, station(root_hinge)),
		Vector3(half_root * 0.15, bottom, station(FIN_ROOT.y)), Vector3(-half_root * 0.15, bottom, station(FIN_ROOT.y)),
		Vector3(-half_tip, top, station(tip_hinge)), Vector3(half_tip, top, station(tip_hinge)),
		Vector3(half_tip * 0.15, top, station(FIN_TIP.y)), Vector3(-half_tip * 0.15, top, station(FIN_TIP.y))]:
		corners.append((p as Vector3) - low)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_block(tool, corners, GREY)
	_add_mesh("RudderSurface", tool, material, Vector3.ZERO).reparent(hinge, false)


## THE TAILPLANE, all-moving, one half each side off the measured root and tip chords. Drawn flat: its dihedral is not
## measurable on this drawing, and a NOT FOUND is not a zero -- `sources.md` carries it as outstanding.
func _tailplane(tool: SurfaceTool) -> void:
	var reach: float = TAILPLANE_SPAN * 0.5
	var half_t: float = TAILPLANE_THICK * 0.5 * IN
	var y: float = waterline(TAILPLANE_WL)
	for side in [1.0, -1.0]:
		_block(tool, [
			Vector3(0.0, y - half_t, station(TAILPLANE_ROOT.x)), Vector3(0.0, y - half_t, station(TAILPLANE_ROOT.y)),
			Vector3(0.0, y + half_t, station(TAILPLANE_ROOT.y)), Vector3(0.0, y + half_t, station(TAILPLANE_ROOT.x)),
			Vector3(side * reach * IN, y - half_t * 0.5, station(TAILPLANE_TIP.x)),
			Vector3(side * reach * IN, y - half_t * 0.5, station(TAILPLANE_TIP.y)),
			Vector3(side * reach * IN, y + half_t * 0.5, station(TAILPLANE_TIP.y)),
			Vector3(side * reach * IN, y + half_t * 0.5, station(TAILPLANE_TIP.x))], GREY)


## BOTH ALL-MOVING TAILPLANES as named rigid parts, one hinge each. The old `_tailplane` remains as the measurement
## recipe; these are the same eight corners translated into each hinge's frame so VAT can carry them.
func _tailplanes(material: Material) -> void:
	var reach: float = TAILPLANE_SPAN * 0.5 * IN
	var half_t: float = TAILPLANE_THICK * 0.5 * IN
	var y: float = waterline(TAILPLANE_WL)
	for side in [1.0, -1.0]:
		var named := "Starboard" if side > 0.0 else "Port"
		var spindle_s: float = lerpf(TAILPLANE_ROOT.x, TAILPLANE_ROOT.y, 0.28)
		var at := Vector3(0.0, y, station(spindle_s))
		var hinge := _hinge("Stabilator" + named, self, at, Vector3(side, 0.0, 0.0),
			Vector3(side * reach, y, station(TAILPLANE_TIP.y)), Vector3.UP)
		var corners: Array = []
		for p in [
			Vector3(0.0, y - half_t, station(TAILPLANE_ROOT.x)), Vector3(0.0, y - half_t, station(TAILPLANE_ROOT.y)),
			Vector3(0.0, y + half_t, station(TAILPLANE_ROOT.y)), Vector3(0.0, y + half_t, station(TAILPLANE_ROOT.x)),
			Vector3(side * reach, y - half_t * 0.5, station(TAILPLANE_TIP.x)),
			Vector3(side * reach, y - half_t * 0.5, station(TAILPLANE_TIP.y)),
			Vector3(side * reach, y + half_t * 0.5, station(TAILPLANE_TIP.y)),
			Vector3(side * reach, y + half_t * 0.5, station(TAILPLANE_TIP.x))]:
			corners.append((p as Vector3) - at)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_block(tool, corners, GREY)
		var part := MeshInstance3D.new()
		part.name = "StabilatorSurface" + named
		part.mesh = Plating.weld(tool)
		part.material_override = material
		hinge.add_child(part)


## AN OUTER-WING AILERON, child of the fold pivot so VatCasting records aileron inside fold. The hinge uses the exact
## leading/trailing-edge functions the wing uses; no second planform can drift from it.
func _aileron(side: float, panel: Node3D, material: Material) -> void:
	var named := "Starboard" if side > 0.0 else "Port"
	var outer: float = half_span_inches()
	var craft_point := func(out: float, chord: float, high: bool) -> Vector3:
		var thick: float = wing_thick(out) * IN
		return Vector3(side * out * IN, waterline(WING_WL) + (thick if high else 0.0),
			station(lerpf(wing_le(out), wing_te(out), chord)))
	var inner_h: Vector3 = craft_point.call(AILERON_IN, AILERON_HINGE, true) - panel.position
	var outer_h: Vector3 = craft_point.call(outer, AILERON_HINGE, true) - panel.position
	var inner_te: Vector3 = craft_point.call(AILERON_IN, 1.0, true) - panel.position
	var hinge := _hinge("Aileron" + named, panel, inner_h, outer_h - inner_h, inner_te, Vector3.UP)
	var corners: Array = []
	for out in [AILERON_IN, outer]:
		for high in [false, true]:
			corners.append(craft_point.call(out, AILERON_HINGE, high) - panel.position - inner_h)
			corners.append(craft_point.call(out, 1.0, high) - panel.position - inner_h)
	# Reorder the generated hinge/trailing pairs into two matching loops expected by `_block`.
	var ordered := [corners[0], corners[1], corners[3], corners[2], corners[4], corners[5], corners[7], corners[6]]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_block(tool, ordered, GREY)
	var part := MeshInstance3D.new()
	part.name = "AileronSurface" + named
	part.mesh = Plating.weld(tool)
	part.material_override = material
	part.position = Vector3.ZERO
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	part.visibility_range_end = 1200.0
	part.visibility_range_end_margin = DETAIL_HYSTERESIS
	part.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	hinge.add_child(part)


## THREE WORKING-SILHOUETTE JAMMING PODS. They are semantic meshes rather than one Details surface so the suite can
## count the load a reader sees. Each includes its pylon, faceted body, tapered tail and dark RAT nose.
func _mission_pods(material: Material) -> void:
	for spec in [
		["Alq99Centre", 0.0, 330.0, waterline(WING_WL) - 0.86],
		["Alq99Starboard", 2.18, 338.0, waterline(WING_WL) - 0.82],
		["Alq99Port", -2.18, 338.0, waterline(WING_WL) - 0.82],
	]:
		var title: String = spec[0]
		var x: float = spec[1]
		var centre_z: float = station(spec[2])
		var centre_y: float = spec[3]
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		# The pylon reaches the wing rather than leaving the pod hanging in air.
		Plating.box(tool, Vector3(x, (centre_y + waterline(WING_WL)) * 0.5, centre_z),
			Vector3(0.18, waterline(WING_WL) - centre_y, 0.72), DARK)
		_pod_body(tool, Vector3(x, centre_y, centre_z))
		var pod := _add_mesh(title, tool, material, Vector3.ZERO)
		pod.visibility_range_end = 1800.0
		pod.visibility_range_end_margin = DETAIL_HYSTERESIS
		pod.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


func _pod_body(tool: SurfaceTool, centre: Vector3) -> void:
	var half: float = POD_LENGTH * 0.5
	var radius: float = POD_DIAMETER * 0.5
	var rings: Array = [
		[centre.z - half, radius * 0.52], [centre.z - half + 0.32, radius],
		[centre.z + half - 0.42, radius], [centre.z + half, radius * 0.35],
	]
	var point := func(row: Array, k: int) -> Vector3:
		var angle: float = TAU * float(k) / POD_SIDES
		return Vector3(centre.x + float(row[1]) * cos(angle), centre.y + float(row[1]) * sin(angle), float(row[0]))
	for r in range(rings.size() - 1):
		for k in range(POD_SIDES):
			var angle: float = TAU * (float(k) + 0.5) / POD_SIDES
			Plating.facing(tool, [point.call(rings[r], k), point.call(rings[r], k + 1),
				point.call(rings[r + 1], k + 1), point.call(rings[r + 1], k)],
				Vector3(cos(angle), sin(angle), 0.0), GREY)
	# A dark RAT disc and six coarse blades at the forward nose: the functional cue the Navy fact sheet names.
	var nose := Vector3(centre.x, centre.y, centre.z - half - 0.03)
	for k in range(6):
		var a: float = TAU * float(k) / 6.0
		var b: float = TAU * (float(k) + 0.36) / 6.0
		_fan(tool, nose, nose + Vector3(radius * 0.48 * cos(a), radius * 0.48 * sin(a), 0.0),
			nose + Vector3(radius * 0.48 * cos(b), radius * 0.48 * sin(b), 0.0), Vector3.FORWARD, BOOT)


## THE GEAR, DOWN, ON A RAKED GROUND. Each tyre's bottom sits on `ground_at` ITS OWN station, which is the whole point:
## the nose tyre ends up 20.9 in lower than the mains in this level frame and that is not a bug.
func _gear(tool: SurfaceTool) -> void:
	# THE NOSE GEAR IS A TWIN WHEEL. The SAC prints ONE tyre size and no count, and the first draft drew one wheel;
	# the Fallon photograph shows two side by side, which is what a nose-tow catapult gear carries.
	for side in [1.0, -1.0]:
		_leg(tool, side * NOSE_TYRE * 0.19 * IN, NOSE_GEAR_STATION, NOSE_TYRE, waterline(float(SECTIONS[6][3]) + 4.0))
	for side in [1.0, -1.0]:
		_leg(tool, side * TRACK * 0.5 * IN, MAIN_GEAR_STATION, MAIN_TYRE, waterline(INTAKE_WL.x + 6.0))


## ONE LEG AND ITS TYRE. The tyre is a box of the printed diameter rather than a cylinder: at the range a wheel is
## visible at all it is a few pixels, and the low-poly direction says a bevel before a round.
func _leg(tool: SurfaceTool, x: float, s: float, tyre_in: float, attach_y: float) -> void:
	var radius: float = tyre_in * 0.5 * IN
	var contact: float = ground_at(s)
	var axle: float = contact + radius
	Plating.box(tool, Vector3(x, (attach_y + axle) * 0.5, station(s)),
		Vector3(5.0 * IN, absf(attach_y - axle), 5.0 * IN), DARK)
	Plating.box(tool, Vector3(x, axle, station(s)), Vector3(tyre_in * 0.3 * IN, tyre_in * IN, tyre_in * IN), BOOT)


## THE REFUELLING PROBE, bent to starboard so the pilot can see past it, which is the change from the A-6's straight one
## and is visible from the front quarter. It ends INSIDE station zero: the published length is the whole aeroplane, so a
## probe projecting beyond the radome would put the drawn model outside its own envelope.
func _probe(tool: SurfaceTool) -> void:
	# PROUD OF THE NOSE, not lying along it. The first draft ran the probe from waterline 96 down to 84 and it was
	# invisible at any range; on the Fallon photograph it stands about 0.6 m clear of the nose decking and curves up
	# and forward, and it is the second thing that names the type after the fin pod.
	var root := Vector3(3.0 * IN, waterline(PROBE_ROOT + 6.0), station(WINDSCREEN_BASE - 2.0))
	var tip := Vector3(9.0 * IN, waterline(PROBE_ROOT + 30.0), station(4.0))
	var run: float = (tip - root).length()
	var along: Vector3 = (tip - root).normalized()
	var across: Vector3 = along.cross(Vector3.UP).normalized()
	var turn := Basis(across, along, across.cross(along).normalized())
	for k in range(PROBE_SIDES):
		var t0: float = TAU * float(k) / PROBE_SIDES
		var t1: float = TAU * float(k + 1) / PROBE_SIDES
		var r0: float = 4.5 * IN
		var r1: float = 2.4 * IN
		var a := root + turn * Vector3(r0 * cos(t0), 0.0, r0 * sin(t0))
		var b := root + turn * Vector3(r0 * cos(t1), 0.0, r0 * sin(t1))
		var c := tip + turn * Vector3(r1 * cos(t1), 0.0, r1 * sin(t1))
		var d := tip + turn * Vector3(r1 * cos(t0), 0.0, r1 * sin(t0))
		var mid: float = (t0 + t1) * 0.5
		Plating.facing(tool, [a, b, c, d], turn * Vector3(cos(mid), 0.0, sin(mid)), DARK)
		_fan(tool, tip, c, d, along, DARK)
		_fan(tool, root, a, b, -along, DARK)
	# `run` is not otherwise used; it is asserted so a probe pulled inside the nose cannot silently become a point.
	assert(run > 0.1)
