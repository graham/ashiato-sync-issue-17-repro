@tool
extends Node3D
class_name HawkeyeAirframe
## AN E-2D ADVANCED HAWKEYE, DRAWN: a rounded fuselage with the wing on top of it, two deep nacelles with eight-blade
## propellers, the rotodome on its post and struts, and a dihedral tailplane carrying four fins. The outer wing panels fold.
##
## THE SIMULATION GIVES THE SIZE, THIS GIVES THE SHAPE. The fuselage box and the span are `kind_geometry`'s `extents` and
## `span`, as for every aircraft; the span is drawn only. Every other size is a fitting, and names its source:
## - `research-hawkeye.md` (godotgames-drafts/2026-09-15/cockpit-fleet): [J] Jane's, [FI] Forecast International, [U] USNA.
## - `research-hawkeye-measured.md`: [NAVY] an official E-2C three-view with printed dimensions; [Z] a Commons three-view
##   scaled to the sourced length; [P] photographs. MEASURED figures are good to about 0.1 m.
##
## STATIONS are metres aft of the nose tip, so a station `s` is `z = -extents.z + s`. HEIGHTS are metres above the ground
## with the gear down, so `h` is `y = -extents.y - GEAR_CLEARANCE + h`.
##
## WHAT THE FIRST DRAFT GOT WRONG, found by its probe and the measurements:
## - A 2.4 m fuselage put the nacelles 3.7 m out, and the folded aircraft came to 11.22 m across against the sourced 8.94.
##   That 8.94 is the folded WINGS [NAVY]; with the propellers it is 10.80 m.
## - The wing sat inside the fuselage, where it sits on top of it.
## - The fins stood 0.8 m above the rotodome. They reach above and below the tailplane.
##
## TWO THINGS MOVE, both drawn only:
## - `turn_rotodome` is handed this machine's physics clock. CockpitWorld binds no frame or time for GDScript, and
##   `timing()`'s frames are diagnostics nothing may decide from, so each machine turns it steadily and not in phase with the
##   next, like every rotor disc here: a picture, not a fact on the wire.
## - `fold` is handed the bus's wing fold, eased over `FOLD_SECONDS` by VehicleView.
##
## NOT IN VehicleView's `_body`: `_show_body` paints one flat material over every mesh there, and this airframe's colour is
## in its vertices, so a crew that boarded and left would have brought it back plain.

## sRGB approximation of FS 16440 Light Gull Gray, the US Navy E-2C's overall gloss; the E-2D's is not confirmed. ESTIMATE.
const GULL_GRAY := Color(0.70, 0.70, 0.67)
const BOOT := Color(0.06, 0.06, 0.06)
const GLASS := Color(0.08, 0.10, 0.13)
const PROP := Color(0.10, 0.10, 0.10)
const PROP_TIP := Color(0.80, 0.80, 0.78)

## The fuselage's underside over the ground, gear down [NAVY, P], 0.6 to 0.75 m.
const GEAR_CLEARANCE: float = 0.7

## THE WING [J]: 3.96 m of chord at the root and 1.32 m at the tip.
## - Root leading edge at station 6.4 [NAVY, Z].
## - Leading edge swept back 8 degrees [NAVY]; with Jane's chords the trailing edge then sweeps forward 4.4 degrees against
##   a measured 4.
## - About 3 degrees of dihedral on the chord plane [Z].
## - Its upper surface 0.5 m above the fuselage's top [NAVY, Z].
const ROOT_CHORD: float = 3.96
const TIP_CHORD: float = 1.32
const ROOT_THICK: float = 0.55
const TIP_THICK: float = 0.22
const WING_ROOT_LE_STATION: float = 6.4
const WING_LE_SWEEP: float = 0.13963  # 8 degrees
const WING_DIHEDRAL: float = 0.05236  # 3 degrees
const WING_OVER_FUSELAGE: float = 0.5
## The fold hinge, about 3.95 m out, just outboard of each nacelle [Z, P].
## Folded [J, P]:
## - each panel lies along the fuselage with its upper surface outboard and its leading edge down, its tip resting at the
##   tailplane's tip, so the folded wings are 8.94 m across [J][AT];
## - the top is canted a little inboard, 10 to 20 degrees by eye: ESTIMATE, 15.
##
## THE HINGE IS ON THE UPPER SURFACE, NEAR THE BACK OF THE CHORD, and the fold lines the panel's own span up with the
## fuselage. So a folded panel HANGS: its leading edge 0.75 of a chord below the hinge, its top under the rotodome. Every
## figure agrees:
## - the bottom edge, 2.66 m below the hinge at the root, is swung out by the cant: 2.66 x sin 11 degrees = 0.51 m, so the
##   folded wings are 2 x (3.95 + 0.51) = 8.92 m against Jane's 8.94;
## - 11 degrees is inside the photographs' 10 to 20;
## - the panels' tops come out about 4.5 m up, under the rotodome's 4.82 m underside.
##
## Two wrong versions came first, and a picture found the second:
## - The first folded about the quarter chord as if the panel had no dihedral or sweep. Its 3 degrees swung each tip
##   0.44 m outboard, and the folded wings came to 9.18 m.
## - With that corrected but the hinge still at the quarter chord, 2.7 m of chord stood ABOVE the hinge. The folded panels
##   were walls reaching 6.3 m, through the rotodome. No check looked there; `and_the_folded_panels_hang_under_the_rotodome`
##   does now.
const HINGE_X: float = 3.95
const HINGE_CHORD: float = 0.75
const FOLD_CANT: float = 0.19199  # 11 degrees
const FOLDED_WIDTH: float = 8.94
## How long the Sto-Wing takes to fold or spread is NOT FOUND: ESTIMATE, twelve seconds. Drawn only.
const FOLD_SECONDS: float = 12.0

## THE ENGINES [NAVY]:
## - centrelines 3.34 m either side (6.68 m apart);
## - NP2000 propellers 4.11 m across [J][MD], each disc 2.0 m ahead of the wing's leading edge there, its hub 2.77 m up;
## - nacelles 5.4 m long, 1.1 m wide and about 2.0 m deep, a deep oval with a chin intake, hung under the wing.
const ENGINE_X: float = 3.34
const PROP_DIAMETER: float = 4.11
const BLADES: int = 8
const DISC_AHEAD_OF_WING: float = 2.0
const HUB_HEIGHT: float = 2.77
const NACELLE_LENGTH: float = 5.4
const NACELLE_WIDE: float = 1.1
const NACELLE_DEEP: float = 2.0

## THE ROTODOME: 7.32 m across [J][U], 0.76 m thick [FI], underside 4.82 m and top 5.58 m up [J], centred at station 10.0
## [NAVY, Z]. Six turns a minute by default [U][A][WAPY], one in ten seconds, which does not strobe as a rotor would.
const ROTODOME_DIAMETER: float = 7.32
const ROTODOME_THICK: float = 0.76
const ROTODOME_TOP: float = 5.58
const ROTODOME_STATION: float = 10.0
const RPM: float = 6.0
## Small fittings stop drawing once the whole 17.6 m aircraft is only a few pixels high. GeometryInstance3D's disabled
## fade mode uses hysteresis and is the fast manual-LOD path; SELF/DEPENDENCIES fades are not supported by Mobile.
## https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html
const DETAIL_RANGE: float = 800.0
const DETAIL_HYSTERESIS: float = 80.0
## Its PYLON [Z; width from an NPS thesis]:
## - a faired post 0.3 m wide off the back of the wing;
## - two struts splayed aft to the fuselage's top at stations 12.3 to 13.1.
const POST_WIDE: float = 0.3
const POST_CHORD: float = 1.2
const STRUT_FOOT_STATION: float = 12.7
const STRUT_THICK: float = 0.16

## THE TAIL [J, Z]:
## - The tailplane is 7.99 m across at 11 degrees of dihedral, from station 15.7 to 17.6 at its root, and 3.7 m up at its
##   tips. Its 11.62 m^2 is a mean chord of 1.45 m, so a tip chord of about 1.0.
## - The OUTBOARD fins stand at its tips, 1.39 m above and 1.84 m below it, 1.79 m of chord at the tailplane, 1.48 at the
##   top and 1.16 at the bottom. Their tops are 5.02 m up [J], and they lean out 11 degrees, square to the tailplane.
## - The INBOARD fins stand 1.9 m out, above the tailplane only, with a root chord of about 1.5.
##   - Their height is from Jane's area: 2.38 m^2 over about a 1.45 m mean chord is 1.6 m.
##   - The drawing reading of 1.9 to 2.0 m, stood on a tailplane already 3.28 m up at 1.9 m out, put their tops at 5.21 m.
##     That is above the outboard fins' sourced 5.02 m, which photographs show they are not.
const TAILPLANE_SPAN: float = 7.99
const TAILPLANE_DIHEDRAL: float = 0.19199  # 11 degrees
const TAILPLANE_ROOT_STATION: float = 15.7
const TAILPLANE_ROOT_CHORD: float = 1.9
const TAILPLANE_TIP_CHORD: float = 1.0
const TAILPLANE_TIP_HEIGHT: float = 3.7
const OUTBOARD_ABOVE: float = 1.39
const OUTBOARD_BELOW: float = 1.84
const OUTBOARD_CHORDS: Vector3 = Vector3(1.16, 1.79, 1.48)  # bottom, at the tailplane, top
const INBOARD_X: float = 1.9
const INBOARD_TALL: float = 1.6
const INBOARD_CHORDS: Vector2 = Vector2(1.5, 1.4)  # root, top: the top ESTIMATE, so (1.5 + 1.4) / 2 * 1.6 = 2.32 m^2 ~ Jane's 2.38

var _rotodome: Node3D = null
var _panels: Array[Node3D] = []
var _fold: float = 0.0
var _half := Vector3(1.05, 1.1, 8.8)
var _span: float = 12.28


## BUILT IN PLACE, after `new()`, from the simulation's geometry.
func dress(geometry: Dictionary) -> void:
	name = "Hawkeye"
	_half = geometry.get("extents", _half) as Vector3
	_span = float(geometry.get("span", _span))
	var material: StandardMaterial3D = ShipHull.painted()

	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var details := SurfaceTool.new()
	details.begin(Mesh.PRIMITIVE_TRIANGLES)
	_fuselage(body, details)
	_wing_piece(body, 0.0, HINGE_X, 1.0, Vector3.ZERO)
	_wing_piece(body, 0.0, HINGE_X, -1.0, Vector3.ZERO)
	for side in [1.0, -1.0]:
		_nacelle(body, details, side)
	_pylon(body, details)
	_tail(body)
	_add_mesh("Body", body, material, Vector3.ZERO)
	_landing_gear(details)
	var fittings := _add_mesh("Details", details, material, Vector3.ZERO)
	fittings.visibility_range_end = DETAIL_RANGE
	fittings.visibility_range_end_margin = DETAIL_HYSTERESIS
	fittings.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	# At this range the probe, gear and propeller blades cannot cast a useful shadow. The class reference explicitly names
	# small geometry as the case for disabling shadows.
	fittings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for side in [1.0, -1.0]:
		var pivot := Node3D.new()
		pivot.name = "WingStarboard" if side > 0.0 else "WingPort"
		pivot.position = Vector3(side * HINGE_X, wing_top(HINGE_X), leading_edge(HINGE_X) + chord(HINGE_X) * HINGE_CHORD)
		add_child(pivot)
		var panel := SurfaceTool.new()
		panel.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Built in the hinge's frame: the same wing, less the pivot's position.
		_wing_piece(panel, HINGE_X, _span, side, pivot.position)
		var mesh := MeshInstance3D.new()
		mesh.name = "Panel"
		mesh.mesh = Plating.weld(panel)
		mesh.material_override = material
		pivot.add_child(mesh)
		_panels.append(pivot)

	var dome := SurfaceTool.new()
	dome.begin(Mesh.PRIMITIVE_TRIANGLES)
	_rotodome_lens(dome)
	_rotodome = _add_mesh("Rotodome", dome, material, Vector3(0.0, height(ROTODOME_TOP - ROTODOME_THICK * 0.5),
		station(ROTODOME_STATION)))


## THE ROTODOME'S ANGLE, from a clock in seconds.
func turn_rotodome(seconds: float) -> void:
	if _rotodome != null:
		_rotodome.rotation.y = fposmod(TAU * RPM / 60.0 * seconds, TAU)


## THE WINGS, 0 spread and 1 folded. Folded, the panel's outward axis points aft, its upper surface outboard and its
## leading edge down, and its top is canted `FOLD_CANT` inboard. The swing between is a slerp, which is not the Sto-Wing's
## own path through the air; nothing but a picture ever sees it mid-fold.
func fold(amount: float) -> void:
	_fold = clampf(amount, 0.0, 1.0)
	for pivot in _panels:
		var side: float = 1.0 if pivot.position.x > 0.0 else -1.0
		# THE PANEL'S OWN SPAN, in its hinge's frame: along the hinge line (upper surface, `HINGE_CHORD` aft) to the tip,
		# which rises with the dihedral and runs aft with the sweep. And its upper surface's normal, square to that.
		var tip := Vector3(side * _span, wing_top(_span), leading_edge(_span) + chord(_span) * HINGE_CHORD)
		var along: Vector3 = (tip - pivot.position).normalized()
		var up: Vector3 = (Vector3.UP - along * along.dot(Vector3.UP)).normalized()
		var own := Basis(along, up, along.cross(up))
		# Laid along the fuselage: the span aft, the upper surface outboard, and so the chord up, leading edge down.
		var laid := Basis(Vector3(0.0, 0.0, 1.0), Vector3(side, 0.0, 0.0), Vector3(0.0, side, 0.0))
		var folded: Basis = Basis(Vector3.BACK, side * FOLD_CANT) * laid * own.transposed()
		pivot.basis = Basis(Quaternion(Basis.IDENTITY).slerp(Quaternion(folded.orthonormalized()), _fold))


## WHERE THE WINGTIPS ARE, left then right, spread, in the airframe's frame: the middle of the tip's chord, halfway through
## its thickness. The nav lights and the contrails stand on them (`VehicleLights.published`), so they are worked out from the
## same wing functions the panels are drawn from, not from the plank's numbers, which put them 0.64 m low and forward.
static func wingtips(geometry: Dictionary) -> Array[Vector3]:
	var half: Vector3 = geometry.get("extents", Vector3(1.05, 1.1, 8.8)) as Vector3
	var span: float = float(geometry.get("span", 12.28))
	var y: float = top_of(half, span) - thickness_of(span, span) * 0.5
	var z: float = leading_edge_of(half, span) + chord_of(span, span) * 0.5
	return [Vector3(-span, y, z), Vector3(span, y, z)]


## THE ROTODOME'S TOP in the airframe's frame, where its beacon stands.
static func rotodome_top(geometry: Dictionary) -> float:
	var half: Vector3 = geometry.get("extents", Vector3(1.05, 1.1, 8.8)) as Vector3
	return -half.y - GEAR_CLEARANCE + ROTODOME_TOP


func station(s: float) -> float:
	return -_half.z + s


func height(h: float) -> float:
	return -_half.y - GEAR_CLEARANCE + h


func chord(x: float) -> float:
	return chord_of(_span, x)


func leading_edge(x: float) -> float:
	return leading_edge_of(_half, x)


func wing_top(x: float) -> float:
	return top_of(_half, x)


func thickness(x: float) -> float:
	return thickness_of(_span, x)


## THE WING, as functions of the geometry, so a builder and a light ask the same arithmetic.
static func chord_of(span: float, x: float) -> float:
	return lerpf(ROOT_CHORD, TIP_CHORD, clampf(absf(x) / span, 0.0, 1.0))


static func leading_edge_of(half: Vector3, x: float) -> float:
	return -half.z + WING_ROOT_LE_STATION + absf(x) * tan(WING_LE_SWEEP)


static func top_of(half: Vector3, x: float) -> float:
	return half.y + WING_OVER_FUSELAGE + absf(x) * tan(WING_DIHEDRAL)


static func thickness_of(span: float, x: float) -> float:
	return lerpf(ROOT_THICK, TIP_THICK, clampf(absf(x) / span, 0.0, 1.0))


func _add_mesh(title: String, tool: SurfaceTool, material: Material, at: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.mesh = Plating.weld(tool)
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
	return mesh


## A CONVEX BLOCK from two matching loops of four corners: the loops are two faces and the four sides run between them.
static func _block(tool: SurfaceTool, corners: Array, tint: Color) -> void:
	var centre := Vector3.ZERO
	for c in corners:
		centre += c
	centre /= float(corners.size())
	for f in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]:
		var quad: Array = [corners[f[0]], corners[f[1]], corners[f[2]], corners[f[3]]]
		var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
		Plating.facing(tool, quad, mid - centre, tint)


## A STRUT from `a` to `b`, `thick` square.
static func _strut(tool: SurfaceTool, a: Vector3, b: Vector3, thick: float, tint: Color) -> void:
	var run: Vector3 = b - a
	if run.length() < 0.01:
		return
	var up: Vector3 = run.normalized()
	var across: Vector3 = up.cross(Vector3.BACK if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var turn := Basis(across, up, across.cross(up).normalized())
	Plating.box(tool, (a + b) * 0.5, Vector3(thick, run.length(), thick), tint, turn)


## A PIECE OF WING from `a` to `b` metres out on one `side`, taken off the whole wing's taper, sweep and dihedral, less
## `origin` (a folding panel is built in its hinge's frame). A black de-icing boot along its leading edge [MM1][MM3].
func _wing_piece(tool: SurfaceTool, a: float, b: float, side: float, origin: Vector3) -> void:
	var loops: Array = []
	var boot: Array = []
	for out in [a, b]:
		var x: float = side * out
		var top: float = wing_top(out)
		var thick: float = lerpf(ROOT_THICK, TIP_THICK, clampf(out / _span, 0.0, 1.0))
		var lead: float = leading_edge(out)
		var trail: float = lead + chord(out)
		loops.append_array([Vector3(x, top - thick, lead) - origin, Vector3(x, top - thick, trail) - origin,
			Vector3(x, top, trail) - origin, Vector3(x, top, lead) - origin])
		boot.append_array([Vector3(x, top - thick - 0.01, lead - 0.02) - origin, Vector3(x, top - thick - 0.01, lead + 0.25) - origin,
			Vector3(x, top + 0.01, lead + 0.25) - origin, Vector3(x, top + 0.01, lead - 0.02) - origin])
	_block(tool, loops, GULL_GRAY)
	_block(tool, boot, BOOT)


## THE FUSELAGE: rounded-rectangle sections [NAVY, P] -- near-vertical sides, a rounded top, a fuller underside -- over the
## collision box, the cabin roof a little higher at station 3.0, glazing round the flight deck and a tail rising into the
## tailplane. Rows are [station, width, height, centre lift], as fractions of the half-extents.
func _fuselage(tool: SurfaceTool, details: SurfaceTool) -> void:
	var rows: Array = [
		[0.0, 0.05, 0.05, -0.1], [0.6, 0.45, 0.45, -0.1], [1.8, 0.8, 0.85, -0.05], [3.0, 0.97, 1.045, 0.05],
		[4.0, 1.0, 1.0, 0.0], [11.0, 1.0, 1.0, 0.0], [14.5, 0.6, 0.55, 0.25], [2.0 * _half.z, 0.22, 0.25, 0.45]]
	const SIDES := 20
	var squircle := func(t: float, row: Array) -> Vector3:
		# A superellipse of power 4: sides nearly flat, corners round.
		var s: float = sin(t)
		var c: float = cos(t)
		return Vector3(_half.x * float(row[1]) * signf(s) * sqrt(absf(s)),
			_half.y * (float(row[3]) + float(row[2]) * signf(c) * sqrt(absf(c))), station(float(row[0])))
	for r in range(rows.size() - 1):
		for k in range(SIDES):
			var t0: float = TAU * float(k) / SIDES
			var t1: float = TAU * float(k + 1) / SIDES
			var corners: Array = [squircle.call(t0, rows[r]), squircle.call(t1, rows[r]),
				squircle.call(t1, rows[r + 1]), squircle.call(t0, rows[r + 1])]
			var mid: float = (t0 + t1) * 0.5
			var glazed: bool = r == 2 and cos(mid) > 0.25
			Plating.facing(tool, corners, Vector3(sin(mid), cos(mid), 0.0), GLASS if glazed else GULL_GRAY)
	# THE REFUELLING PROBE over the cockpit roof, where the pilots can see its tip [DMN]. Its length is not published. The
	# published 17.60 m is the aircraft's OVERALL length, so the old 1.5 m projection beyond its nose was physically
	# impossible: the tip now ends just inside station zero and the drawn airframe keeps the public envelope.
	_strut(details, Vector3(0.3, _half.y * 1.0, station(4.0)), Vector3(0.3, _half.y * 0.9, station(0.08)), 0.12, GULL_GRAY)


## A NACELLE under the wing, and its propeller: a spinner and eight blades with white tips [HSK], static, as every rotor
## here. One blade is drawn level, which is where the aircraft is widest: 10.80 m across [NAVY].
func _nacelle(tool: SurfaceTool, details: SurfaceTool, side: float) -> void:
	var x: float = side * ENGINE_X
	var disc: float = leading_edge(ENGINE_X) - DISC_AHEAD_OF_WING
	var hub: float = height(HUB_HEIGHT)
	var roof: float = wing_top(ENGINE_X) - thickness(ENGINE_X) + 0.05
	var middle: float = roof - NACELLE_DEEP * 0.5
	# THE NACELLE AS A DEEP ROUNDED OVAL [NAVY, P], not the box the first pictures showed as a flat slab from the front
	# quarter. The size is the measured 5.4 x 1.1 x 2.0 m. The nose is centred on the propeller's hub, high in the section;
	# the section is full from a quarter of the way back; the tail tapers up under the wing. Rows are
	# [share of the length, width, depth, centre], the centre as metres above the section's middle.
	var rows: Array = [
		[0.0, 0.40, 0.30, hub - middle], [0.08, 0.80, 0.62, (hub - middle) * 0.6], [0.25, 1.0, 1.0, 0.0],
		[0.72, 1.0, 1.0, 0.0], [1.0, 0.45, 0.40, NACELLE_DEEP * 0.30]]
	const SIDES := 16
	var ring := func(row: Array, k: int) -> Vector3:
		var t: float = TAU * float(k) / SIDES
		var s: float = sin(t)
		var c: float = cos(t)
		return Vector3(x + NACELLE_WIDE * 0.5 * float(row[1]) * signf(s) * sqrt(absf(s)),
			middle + float(row[3]) + NACELLE_DEEP * 0.5 * float(row[2]) * signf(c) * sqrt(absf(c)),
			disc + 0.3 + NACELLE_LENGTH * float(row[0]))
	for r in range(rows.size() - 1):
		for k in range(SIDES):
			var mid: float = TAU * (float(k) + 0.5) / SIDES
			Plating.facing(tool, [ring.call(rows[r], k), ring.call(rows[r], k + 1), ring.call(rows[r + 1], k + 1),
				ring.call(rows[r + 1], k)], Vector3(sin(mid), cos(mid), 0.0), GULL_GRAY)
	# The two ends closed, each a fan wound to face along the nacelle, out of it.
	for end in [[0, -1.0], [rows.size() - 1, 1.0]]:
		var row: Array = rows[int(end[0])]
		var centre := Vector3(x, middle + float(row[3]), disc + 0.3 + NACELLE_LENGTH * float(row[0]))
		for k in range(SIDES):
			_fan(tool, centre, ring.call(row, k), ring.call(row, k + 1), Vector3(0.0, 0.0, float(end[1])), GULL_GRAY)
	# THE CHIN INTAKE under the front of the nacelle, dark.
	Plating.box(details, Vector3(x, middle - NACELLE_DEEP * 0.42, disc + 0.3 + NACELLE_LENGTH * 0.16),
		Vector3(NACELLE_WIDE * 0.55, 0.22, NACELLE_LENGTH * 0.12), BOOT)
	Plating.box(details, Vector3(x, hub, disc + 0.1), Vector3(0.55, 0.55, 0.6), PROP)
	var radius: float = PROP_DIAMETER * 0.5
	for i in range(BLADES):
		var turn := Basis(Vector3.BACK, TAU * float(i) / BLADES)
		Plating.box(details, Vector3(x, hub, disc) + turn * Vector3(0.0, (radius - 0.3) * 0.5 + 0.15, 0.0),
			Vector3(0.24, radius - 0.3, 0.05), PROP, turn)
		Plating.box(details, Vector3(x, hub, disc) + turn * Vector3(0.0, radius - 0.15, 0.0), Vector3(0.24, 0.3, 0.05),
			PROP_TIP, turn)


## THE PYLON: the faired post off the back of the wing, and two struts splayed aft to the fuselage.
func _pylon(tool: SurfaceTool, details: SurfaceTool) -> void:
	var underside: float = height(ROTODOME_TOP - ROTODOME_THICK)
	var root_top: float = wing_top(0.0)
	var post_z: float = leading_edge(0.0) + chord(0.0) - POST_CHORD * 0.5
	Plating.box(tool, Vector3(0.0, (root_top + underside) * 0.5, post_z),
		Vector3(POST_WIDE, underside - root_top + 0.1, POST_CHORD), GULL_GRAY)
	for side in [1.0, -1.0]:
		_strut(details, Vector3(side * 0.45, _half.y * 0.9, station(STRUT_FOOT_STATION)),
			Vector3(side * 0.25, underside + 0.05, station(ROTODOME_STATION + 1.2)), STRUT_THICK, GULL_GRAY)


## THE LANDING GEAR, DOWN: the main legs descend from the nacelles and the nose leg from the forward fuselage [P]. Exact
## wheel dimensions and stations are not published in the cited sheets, so these are conservative visual estimates. Their
## tyre bottoms share the height(0) ground datum; this makes the sourced 5.58 m overall height true in the drawn model.
func _landing_gear(details: SurfaceTool) -> void:
	var ground: float = height(0.0)
	var nose_z: float = station(3.2)
	_strut(details, Vector3(0.0, -_half.y * 0.78, nose_z + 0.25), Vector3(0.0, ground + 0.26, nose_z), 0.10, GULL_GRAY)
	Plating.box(details, Vector3(0.0, ground + 0.13, nose_z), Vector3(0.16, 0.26, 0.36), PROP)
	for side in [1.0, -1.0]:
		var x: float = side * ENGINE_X
		var main_z: float = station(9.1)
		_strut(details, Vector3(x, height(1.45), main_z - 0.35), Vector3(x, ground + 0.34, main_z), 0.13, GULL_GRAY)
		Plating.box(details, Vector3(x, ground + 0.17, main_z), Vector3(0.38, 0.34, 0.48), PROP)


## THE ROTODOME: a lens, thickest in the middle, with a black rim band. Its markings are NOT FOUND; with none, the turning
## shows only in its facets.
##
## THE LENS IS CONVEX AND CENTRED ON ITS OWN ORIGIN, so a face's outside is the way from the origin to its middle. The first
## draft guessed each band's outward direction and built the middle from quads with two corners at the centre: 16 of 448
## faces came out wound inwards. The middle is a fan of triangles now.
static func _rotodome_lens(tool: SurfaceTool) -> void:
	const SIDES := 32
	var radius: float = ROTODOME_DIAMETER * 0.5
	var rings: Array = [[0.55, 0.92], [0.85, 0.65], [1.0, 0.18]]
	var point := func(ring: Array, t: float, side: float) -> Vector3:
		return Vector3(radius * float(ring[0]) * cos(t), side * ROTODOME_THICK * 0.5 * float(ring[1]),
			radius * float(ring[0]) * sin(t))
	for side in [1.0, -1.0]:
		var apex := Vector3(0.0, side * ROTODOME_THICK * 0.5, 0.0)
		for k in range(SIDES):
			var t0: float = TAU * float(k) / SIDES
			var t1: float = TAU * float(k + 1) / SIDES
			_triangle(tool, apex, point.call(rings[0], t0, side), point.call(rings[0], t1, side), GULL_GRAY)
			for r in range(rings.size() - 1):
				var corners: Array = [point.call(rings[r], t0, side), point.call(rings[r], t1, side),
					point.call(rings[r + 1], t1, side), point.call(rings[r + 1], t0, side)]
				var mid: Vector3 = ((corners[0] as Vector3) + corners[1] + corners[2] + corners[3]) * 0.25
				Plating.facing(tool, corners, mid, BOOT if r == rings.size() - 2 else GULL_GRAY)
	for k in range(SIDES):
		var t0: float = TAU * float(k) / SIDES
		var t1: float = TAU * float(k + 1) / SIDES
		var corners: Array = [point.call(rings[-1], t0, 1.0), point.call(rings[-1], t1, 1.0),
			point.call(rings[-1], t1, -1.0), point.call(rings[-1], t0, -1.0)]
		var mid: Vector3 = ((corners[0] as Vector3) + corners[1] + corners[2] + corners[3]) * 0.25
		Plating.facing(tool, corners, mid, BOOT)


## ONE TRIANGLE OF A FAN, wound so its face looks along `out`: an end cap anywhere, not only round the origin.
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


## ONE TRIANGLE of a convex solid centred on the origin, wound so it faces away from the origin.
static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 1e-10:
		return
	if normal.dot((a + b + c) / 3.0) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	tool.set_color(tint)
	for corner in [a, b, c]:
		tool.set_normal(normal.normalized())
		tool.add_vertex(corner)


## THE TAIL: the tailplane rolled up 11 degrees each side about the fuselage's end, and four fins square to it.
func _tail(tool: SurfaceTool) -> void:
	var reach: float = TAILPLANE_SPAN * 0.5
	var root := Vector3(0.0, height(TAILPLANE_TIP_HEIGHT) - reach * tan(TAILPLANE_DIHEDRAL), station(TAILPLANE_ROOT_STATION))
	for side in [1.0, -1.0]:
		var roll := Basis(Vector3.BACK, side * TAILPLANE_DIHEDRAL)
		# The tailplane half, in its rolled frame: x out along it, y square to it. Its tip is swept back by half the taper.
		var sweep: float = (TAILPLANE_ROOT_CHORD - TAILPLANE_TIP_CHORD) * 0.5
		var loops: Array = []
		for end in [[0.0, 0.0, TAILPLANE_ROOT_CHORD], [reach, sweep, TAILPLANE_TIP_CHORD]]:
			var out: float = side * float(end[0])
			var lead: float = float(end[1])
			var c: float = float(end[2])
			for p in [Vector3(out, -0.08, lead), Vector3(out, -0.08, lead + c), Vector3(out, 0.08, lead + c), Vector3(out, 0.08, lead)]:
				loops.append(root + roll * p)
		_block(tool, loops, GULL_GRAY)
		# The outboard fin, at the tip, square to the tailplane: 1.39 m above it and 1.84 m below.
		var tip_mid: float = sweep + TAILPLANE_TIP_CHORD * 0.5
		_fin(tool, root, roll, side * reach, tip_mid, [[-OUTBOARD_BELOW, OUTBOARD_CHORDS.x], [0.0, OUTBOARD_CHORDS.y],
			[OUTBOARD_ABOVE, OUTBOARD_CHORDS.z]])
		# The inboard fin, above only.
		var inboard_mid: float = sweep * INBOARD_X / reach + lerpf(TAILPLANE_ROOT_CHORD, TAILPLANE_TIP_CHORD, INBOARD_X / reach) * 0.5
		_fin(tool, root, roll, side * INBOARD_X, inboard_mid, [[0.0, INBOARD_CHORDS.x], [INBOARD_TALL, INBOARD_CHORDS.y]])


## A FIN in the tailplane's rolled frame at `out` along it, centred on `mid` of chord, through `levels` of [height, chord].
func _fin(tool: SurfaceTool, root: Vector3, roll: Basis, out: float, mid: float, levels: Array) -> void:
	for i in range(levels.size() - 1):
		var loops: Array = []
		for level in [levels[i], levels[i + 1]]:
			var up: float = float(level[0])
			var c: float = float(level[1])
			for p in [Vector3(out - 0.07, up, mid - c * 0.5), Vector3(out + 0.07, up, mid - c * 0.5),
					Vector3(out + 0.07, up, mid + c * 0.5), Vector3(out - 0.07, up, mid + c * 0.5)]:
				loops.append(root + roll * p)
		_block(tool, loops, GULL_GRAY)
